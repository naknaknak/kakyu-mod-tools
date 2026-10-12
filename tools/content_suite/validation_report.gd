class_name KakyuValidationReport
extends RefCounted

const SCHEMA := "kakyu_content_tools_validation/v6"
const SCHEMA_V5 := "kakyu_content_tools_validation/v5"
const SCHEMA_V4 := "kakyu_content_tools_validation/v4"
const SCHEMA_V3 := "kakyu_content_tools_validation/v3"
const ACCEPTED_SCHEMAS := ["kakyu_content_tools_validation/v6", "kakyu_content_tools_validation/v5", "kakyu_content_tools_validation/v4", "kakyu_content_tools_validation/v3"]
const LEGACY_SCHEMA := "kakyu_content_tools_validation/v2"
const MAX_BYTES := 16 * 1024 * 1024
const BASE_FIELDS := ["schema", "status", "check_count", "passed", "failed", "duration_seconds", "original_corpus", "native_executable_audit", "checks"]
const EXTRA_FIELDS := ["run_id", "coverage", "context", "configuration_error"]
const COVERAGE_IDS := ["synthetic", "original_corpus", "event_corpus", "native_executable", "native_corpus", "voice_payload"]
const TIERS := ["local", "archive_quick", "full"]
const CACHE_STATES := ["consulted", "not_consulted"]
const CACHE_CHECK_FIELDS := ["cached", "cached_at", "cached_run_id"]


static func read_path(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("Validation report could not be opened.")
	if file.get_length() > MAX_BYTES:
		return _error("Validation report exceeds the 16 MiB limit.")
	return parse_text(file.get_as_text())


static func parse_text(document: String) -> Dictionary:
	if document.to_utf8_buffer().size() > MAX_BYTES:
		return _error("Validation report exceeds the 16 MiB limit.")
	var parser := JSON.new()
	if parser.parse(document) != OK or not parser.data is Dictionary:
		return _error("Validation report is not a JSON object.")
	var outer: Dictionary = parser.data
	if outer.get("schema") == LEGACY_SCHEMA:
		var issue := _validate_payload(outer, true, LEGACY_SCHEMA)
		if not issue.is_empty():
			return _error(issue)
		var payload := outer.duplicate(true)
		payload.merge({
			"schema": SCHEMA, "run_id": "", "configuration_error": "", "cached": 0,
			"coverage": [{"id": "legacy_unknown", "title": "Legacy coverage", "status": "not_run", "reason": "The unsigned v2 report does not establish complete coverage or omitted checks.", "check_count": 0}],
			"context": {"kind": "repository_suite", "elfimage": "", "executable": "", "workspace_validation": "not_performed", "tier": "full", "cache": "not_consulted", "cache_dir": "", "jobs": 1},
		}, true)
		return {"ok": true, "payload": payload, "legacy": true, "integrity": "unsigned_legacy"}
	var report_schema: String = outer.get("schema") if outer.get("schema") is String else ""
	if not ACCEPTED_SCHEMAS.has(report_schema):
		return _error("Unsupported validation report schema.")
	if not _exact_fields(outer, ["schema", "payload_json", "payload_sha256"]):
		return _error("Validation report envelope fields do not match v3/v4/v5.")
	if not outer.payload_json is String or not outer.payload_sha256 is String:
		return _error("Validation report envelope has invalid field types.")
	if not _matches(outer.payload_sha256, "^[0-9a-f]{64}$") or outer.payload_json.sha256_text() != outer.payload_sha256:
		return _error("Validation report payload fingerprint does not match.")
	if parser.parse(outer.payload_json) != OK or not parser.data is Dictionary:
		return _error("Validation report payload is not a JSON object.")
	var payload: Dictionary = parser.data
	var issue := _validate_payload(payload, false, report_schema)
	if not issue.is_empty():
		return _error(issue)
	# TD-32 part 3b: a `v4`/`v3` payload predates the cache; synthesize the
	# same "not consulted, nothing cached" reading `normalize_report()` gives
	# in Python, so every reader here sees the current shape. `v3` also
	# predates the tier concept (kept from before). TD-33: a `v5` payload
	# predates `--jobs`, so it reports `jobs: 1` here too.
	if report_schema != SCHEMA:
		payload = payload.duplicate(true)
		payload.context = payload.context.duplicate(true)
		if report_schema == SCHEMA_V3:
			payload.context.tier = "full"
		if report_schema in [SCHEMA_V3, SCHEMA_V4]:
			payload.context.cache = "not_consulted"
			payload.context.cache_dir = ""
			payload.cached = 0
		payload.context.jobs = 1
	return {"ok": true, "payload": payload, "legacy": false, "integrity": "verified"}


static func _validate_payload(payload: Dictionary, legacy: bool, schema: String) -> String:
	var fields := BASE_FIELDS.duplicate()
	if not legacy:
		fields.append_array(EXTRA_FIELDS)
		if schema == SCHEMA or schema == SCHEMA_V5:
			fields.append("cached")
	if not _exact_fields(payload, fields) or payload.get("schema") != schema:
		return "Validation payload fields or schema do not match."
	if not payload.status is String or payload.status not in ["passed", "failed", "configuration_error"] or (legacy and payload.status == "configuration_error"):
		return "Validation payload status is invalid."
	for key in ["check_count", "passed", "failed"]:
		if not _count(payload[key]):
			return "Validation counters must be nonnegative integers."
	if not _duration(payload.duration_seconds) or not payload.original_corpus is bool or not payload.native_executable_audit is bool or not payload.checks is Array:
		return "Validation summary field types are invalid."
	var passed := 0
	var cached_rows := 0
	var names := {}
	for value in payload.checks:
		if not value is Dictionary:
			return "Validation check must be an object."
		var check: Dictionary = value
		var check_fields := ["name", "status", "return_code", "duration_seconds"]
		if check.has("output_tail"):
			check_fields.append("output_tail")
		if not legacy and (schema == SCHEMA or schema == SCHEMA_V5):
			for cache_field in CACHE_CHECK_FIELDS:
				if check.has(cache_field):
					check_fields.append(cache_field)
		if not _exact_fields(check, check_fields) or not check.name is String or check.name.is_empty() or names.has(check.name):
			return "Validation check names or fields are invalid."
		names[check.name] = true
		if not check.status is String or check.status not in ["passed", "failed", "timeout", "error"] or not _duration(check.duration_seconds):
			return "Validation check status or duration is invalid."
		if check.return_code != null and not _integer(check.return_code):
			return "Validation check return code is invalid."
		if check.status == "passed":
			if check.return_code == null or check.return_code != 0:
				return "A passed check must have exit code zero."
			passed += 1
		elif check.status == "failed" and (check.return_code == null or check.return_code == 0):
			return "A failed check must have a nonzero exit code."
		elif check.status in ["timeout", "error"] and check.return_code != null:
			return "A timed-out or unavailable check must have no exit code."
		if check.has("output_tail") and (not check.output_tail is String or check.output_tail.length() > 4096):
			return "Validation check output tail is invalid."
		var present_cache_fields := check_fields.filter(func(f): return f in CACHE_CHECK_FIELDS)
		if not present_cache_fields.is_empty() and present_cache_fields.size() != CACHE_CHECK_FIELDS.size():
			return "A cached check result must carry cached, cached_at and cached_run_id together."
		if check.has("cached"):
			# TD-32 part 3c, section 3: `check.cached != true` compares an
			# `int`/`float`/etc. value against a `bool` literal, which is a
			# runtime type-mismatch SCRIPT ERROR in GDScript 4 (not simply
			# "not equal") - a malformed report (`cached: 1`) crashed the
			# reader instead of failing closed. `is bool` first, matching
			# the Python reader's own `is not True` check.
			if not (check.cached is bool and check.cached) or check.status != "passed" or check.return_code != 0 or check.duration_seconds != 0 or not check.cached_at is String or check.cached_at.is_empty() or not check.cached_run_id is String or check.cached_run_id.is_empty():
				return "Validation check carries an invalid cached result."
			cached_rows += 1
	var failed: int = payload.checks.size() - passed
	if payload.check_count != payload.checks.size() or payload.passed != passed or payload.failed != failed:
		return "Validation summary counters disagree with its checks."
	if schema == SCHEMA or schema == SCHEMA_V5:
		if not _count(payload.cached) or payload.cached != cached_rows:
			return "Validation cached count disagrees with its checks."
	if payload.status == "passed" and (failed != 0 or passed == 0):
		return "A passing validation summary requires executed passing checks."
	if payload.status == "failed" and failed == 0:
		return "A failed validation summary requires a failed check."
	if legacy:
		return ""
	if not payload.run_id is String or not _matches(payload.run_id, "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"):
		return "Validation run identifier is invalid."
	if not payload.configuration_error is String or not payload.context is Dictionary or not payload.coverage is Array:
		return "Validation context or coverage types are invalid."
	if payload.status == "configuration_error":
		if payload.configuration_error.is_empty() or payload.check_count != 0:
			return "Configuration failure must have a reason and no executed checks."
	elif not payload.configuration_error.is_empty():
		return "Executed validation must not contain a configuration error."
	var context: Dictionary = payload.context
	if schema == SCHEMA or schema == SCHEMA_V5 or schema == SCHEMA_V4:
		var context_fields := ["kind", "elfimage", "executable", "workspace_validation", "tier"]
		if schema == SCHEMA or schema == SCHEMA_V5:
			context_fields.append_array(["cache", "cache_dir"])
		if schema == SCHEMA:
			context_fields.append("jobs")
		if not _exact_fields(context, context_fields) or context.kind != "repository_suite" or context.workspace_validation != "not_performed" or not context.elfimage is String or not context.executable is String or not context.tier is String or context.tier not in TIERS:
			return "Validation context does not describe a repository suite."
		if (schema == SCHEMA or schema == SCHEMA_V5) and (not context.cache is String or context.cache not in CACHE_STATES or not context.cache_dir is String):
			return "Validation context cache fields are invalid."
		if (schema == SCHEMA or schema == SCHEMA_V5) and context.cache == "not_consulted" and payload.cached != 0:
			return "Validation cache not_consulted cannot report cached checks."
		if schema == SCHEMA and not (_integer(context.jobs) and context.jobs > 0):
			return "Validation context jobs field is invalid."
		var tier_is_local: bool = context.tier == "local"
		if payload.original_corpus != (not context.elfimage.is_empty() and not tier_is_local) or payload.native_executable_audit != (not context.executable.is_empty() and not tier_is_local):
			return "Validation source flags disagree with its context."
	else:
		if not _exact_fields(context, ["kind", "elfimage", "executable", "workspace_validation"]) or context.kind != "repository_suite" or context.workspace_validation != "not_performed" or not context.elfimage is String or not context.executable is String:
			return "Validation context does not describe a repository suite."
		if payload.original_corpus != not context.elfimage.is_empty() or payload.native_executable_audit != not context.executable.is_empty():
			return "Validation source flags disagree with its context."
	var coverage_ids := {}
	if payload.coverage.size() != COVERAGE_IDS.size():
		return "Validation coverage must contain all six v3 groups."
	for value in payload.coverage:
		if not value is Dictionary or not _exact_fields(value, ["id", "title", "status", "reason", "check_count"]):
			return "Validation coverage fields are invalid."
		var item: Dictionary = value
		if not item.id is String or item.id.is_empty() or coverage_ids.has(item.id) or not item.title is String or item.title.is_empty() or not item.reason is String or item.reason.is_empty() or not item.status is String or item.status not in ["included", "not_run"] or not _count(item.check_count):
			return "Validation coverage values are invalid."
		coverage_ids[item.id] = true
		if item.id not in COVERAGE_IDS:
			return "Validation coverage contains an unknown v3 group."
		if item.status == "not_run" and (item.check_count != 0 or item.reason.is_empty()):
			return "Unrun coverage must carry a reason and zero executed checks."
		if item.status == "included" and (item.check_count == 0 or item.check_count > payload.check_count):
			return "Included coverage counts disagree with the executed suite."
	return ""


static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


static func _count(value: Variant) -> bool:
	return _integer(value) and value >= 0


static func _duration(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0


static func _matches(value: String, pattern: String) -> bool:
	var expression := RegEx.new()
	expression.compile(pattern)
	return expression.search(value) != null


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
