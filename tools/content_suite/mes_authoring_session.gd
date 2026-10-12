class_name KakyuMesAuthoringSession
extends RefCounted

const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const VersionScript := preload("res://content_core/content_core_version.gd")
const ReopenScript := preload("res://content_core/mes_state_literal_compile_reopen.gd")
const ConditionReopenScript := preload("res://content_core/mes_condition_literal_compile_reopen.gd")
const ResourceReopenScript := preload("res://content_core/mes_resource_name_compile_reopen.gd")
const ChoiceReopenScript := preload("res://content_core/mes_choice_option_compile_reopen.gd")
const CallReopenScript := preload("res://content_core/mes_registered_definition_call_compile_reopen.gd")
const SharedCallReopenScript := preload("res://content_core/mes_shared_routine_call_compile_reopen.gd")
const LibraryAuditReportScript := preload("res://tools/content_suite/mes_library_audit_report.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const SemanticDiffScript := preload("res://content_core/mes_semantic_diff.gd")
const SCHEMA := "kakyu_mes_authoring_bundle/v9"
const LEGACY_SCHEMA := "kakyu_mes_authoring_bundle/v1"
const LEGACY_SCHEMAS := ["kakyu_mes_authoring_bundle/v1", "kakyu_mes_authoring_bundle/v2", "kakyu_mes_authoring_bundle/v3", "kakyu_mes_authoring_bundle/v4", "kakyu_mes_authoring_bundle/v5", "kakyu_mes_authoring_bundle/v6", "kakyu_mes_authoring_bundle/v7", "kakyu_mes_authoring_bundle/v8"]
const MessageReopenScript := preload("res://content_core/mes_control_target_compile_reopen.gd")
const ControlTargetEditReopenScript := preload("res://content_core/mes_control_target_edit_compile_reopen.gd")
const BindingScript := preload("res://tools/content_suite/mes_authoring_binding.gd")
const SemanticDiffChainScript := preload("res://content_core/mes_semantic_diff_chain.gd")
const STATE_AUDIT_SCHEMA := "kakyu_mes_state_literal_compile_audit/v1"
const CONDITION_AUDIT_SCHEMA := "kakyu_mes_condition_literal_compile_audit/v1"
const RESOURCE_AUDIT_SCHEMA := "kakyu_mes_resource_name_compile_audit/v1"
const CHOICE_AUDIT_SCHEMA := "kakyu_mes_choice_option_compile_audit/v1"
const CALL_AUDIT_SCHEMA := "kakyu_mes_registered_definition_call_compile_audit/v1"
const SHARED_CALL_AUDIT_SCHEMA := "kakyu_mes_shared_routine_call_compile_audit/v1"
const CONTROL_TARGET_AUDIT_SCHEMA := "kakyu_mes_control_target_edit_compile_audit/v1"
const REGISTRY_MEMBER := "registry.proof.json"
const LIBRARY_MEMBER := "library.audit.json"
const SOURCE_FIELDS := {
	"kakyu_mes_state_literal_compile_audit/v1": {"section": "target", "start": "expression_start", "end": "expression_end", "hash": "source_expression_sha256"},
	"kakyu_mes_condition_literal_compile_audit/v1": {"section": "target", "start": "literal_start", "end": "literal_end", "hash": "source_literal_sha256"},
	"kakyu_mes_resource_name_compile_audit/v1": {"section": "target", "start": "name_start", "end": "name_end", "hash": "source_name_sha256"},
	"kakyu_mes_choice_option_compile_audit/v1": {"section": "patch", "start": "code_start", "end": "code_end", "hash": "source_payload_sha256"},
	"kakyu_mes_registered_definition_call_compile_audit/v1": {"section": "target", "start": "literal_start", "end": "literal_end", "hash": "source_literal_sha256"},
	"kakyu_mes_shared_routine_call_compile_audit/v1": {"section": "target", "start": "literal_start", "end": "literal_end", "hash": "source_literal_sha256"},
	"kakyu_mes_control_target_edit_compile_audit/v1": {"section": "source_control", "start": "instruction_start", "end": "instruction_end", "hash": "source_instruction_sha256"},
}
const FILES := ["handoff.json", "handoff.payload.json", "editable.json", "plan.json", "output.mes",
	"output.handoff.json", "compile.audit.json", "semantic.diff.json", "control.plan.json", "registry.proof.json",
	"library.audit.json", "sequence.json"]
const STEP_SUFFIXES := ["plan.json", "compile.audit.json", "semantic.diff.json", "output.mes", "output.handoff.json"]
const SEQUENCE_MEMBER := "sequence.json"

var spawn_process: Callable = OS.create_process
var process_running: Callable = OS.is_process_running
var process_exit_code: Callable = OS.get_process_exit_code
var _pid := -1
var _request: Dictionary = {}


func is_running() -> bool:
	return _pid > 0


func inspect(archive: String, entry: String, source_sha: String, workspace: String) -> Dictionary:
	if is_running():
		return _error("An authoring job is already running.")
	var destination := _new_path(workspace)
	if destination.is_empty():
		return _error("An active writable workspace is required for authoring.")
	var extra_arguments: Array = []
	var reader := ArcReaderScript.new()
	var has_library := reader.open(archive) and not reader.get_entry("LIBLARY.LIB").is_empty()
	reader.close()
	if has_library:
		var library_audit_path := destination + ".library-audit.json"
		var written := LibraryAuditReportScript.new().write(archive, library_audit_path)
		if not written.get("ok", false):
			return _error(str(written.get("error", "The Godot library audit could not be built.")))
		extra_arguments = ["--library-audit", library_audit_path]
	return _start("inspect", [archive, entry, source_sha], workspace, extra_arguments, destination)


func compile_state(bundle: String, operation: Dictionary, workspace: String) -> Dictionary:
	return compile_edit(bundle, operation, workspace)


func compile_edit(bundle: String, operation: Dictionary, workspace: String) -> Dictionary:
	if is_running():
		return _error("An authoring job is already running.")
	var allocated := _new_path(workspace)
	if allocated.is_empty():
		return _error("An active writable workspace is required for authoring.")
	var request_path := allocated + ".operation.json"
	if FileAccess.file_exists(request_path):
		return _error("The authoring operation could not be allocated.")
	var file := FileAccess.open(request_path, FileAccess.WRITE)
	if file == null:
		return _error("The authoring operation could not be written.")
	file.store_string(FingerprintScript.new().canonical_payload_json(operation) + "\n")
	file.close()
	return _start("compile", [bundle, request_path], workspace)


func compile_sequence(bundle: String, operations: Array, workspace: String) -> Dictionary:
	if is_running():
		return _error("An authoring job is already running.")
	if operations.is_empty():
		return _error("An operation sequence must be a non-empty list.")
	var allocated := _new_path(workspace)
	if allocated.is_empty():
		return _error("An active writable workspace is required for authoring.")
	var request_path := allocated + ".operation.json"
	if FileAccess.file_exists(request_path):
		return _error("The authoring operation could not be allocated.")
	var file := FileAccess.open(request_path, FileAccess.WRITE)
	if file == null:
		return _error("The authoring operation could not be written.")
	var fingerprinter := FingerprintScript.new()
	var rows: Array[String] = []
	for operation in operations:
		rows.append(fingerprinter.canonical_payload_json(operation))
	file.store_string("[" + ",".join(rows) + "]\n")
	file.close()
	return _start("compile", [bundle, request_path], workspace)


func _start(command: String, parameters: Array, workspace: String, extra_arguments: Array = [], preallocated_destination: String = "") -> Dictionary:
	if is_running():
		return _error("An authoring job is already running.")
	var runtime := preload("res://tools/content_suite/python_runtime.gd").resolve("tools/mes_authoring_workflow.py")
	if not runtime.get("ok", false):
		return runtime
	var python := str(runtime.python)
	var script := str(runtime.script)
	var destination := preallocated_destination
	if destination.is_empty():
		destination = _new_path(workspace)
	if destination.is_empty():
		return _error("An active writable workspace is required for authoring.")
	var report := destination + ".result.json"
	var arguments := PackedStringArray(["-B", script, command])
	for value in parameters:
		arguments.append(str(value))
	arguments.append(destination)
	for value in extra_arguments:
		arguments.append(str(value))
	arguments.append_array(["--report", report])
	_pid = int(spawn_process.call(python, arguments, false))
	if _pid <= 0:
		return _error("The Python authoring process could not be started.")
	_request = {"command": command, "directory": destination, "report": report}
	return {"ok": true, "request": _request.duplicate(true)}


func poll() -> Dictionary:
	if not is_running() or bool(process_running.call(_pid)):
		return {"finished": false}
	var exit_code := int(process_exit_code.call(_pid))
	_pid = -1
	var report = JSON.parse_string(FileAccess.get_file_as_string(str(_request.report)))
	var result: Dictionary
	if not report is Dictionary or str(report.get("schema", "")) != SCHEMA:
		result = _error("The authoring process did not publish a valid report.")
	elif exit_code != 0 or report.get("ok") != true:
		result = _error(str(report.get("error", "The authoring process failed.")))
	else:
		result = read_bundle(str(_request.directory))
		if result.get("ok", false) and str(result.manifest.payload_sha256) != str(report.get("payload_sha256", "")):
			result = _error("The authoring result belongs to a different process output.")
	return {"finished": true, "request": _request.duplicate(true), "result": result}


static func step_member(index: int, suffix: String) -> String:
	return "step-%02d.%s" % [index, suffix]


static func _is_step_member(name: String) -> bool:
	if not name.begins_with("step-") or name.length() < 9 or name[7] != ".":
		return false
	if not name[5] in "0123456789" or not name[6] in "0123456789":
		return false
	var suffix := name.substr(8)
	return suffix in STEP_SUFFIXES or suffix == "control.plan.json"


static func _is_known_member(name: String) -> bool:
	return name in FILES or name in [REGISTRY_MEMBER, LIBRARY_MEMBER] or _is_step_member(name)


static func _reopen_step(output_bytes: PackedByteArray, audit: Dictionary, has_control_plan: bool) -> Dictionary:
	var reopened: Dictionary
	if has_control_plan:
		reopened = MessageReopenScript.new().audit(output_bytes, audit)
	elif str(audit.get("schema", "")) == STATE_AUDIT_SCHEMA:
		reopened = ReopenScript.new().audit(output_bytes, audit)
	elif str(audit.get("schema", "")) == CONDITION_AUDIT_SCHEMA:
		reopened = ConditionReopenScript.new().audit(output_bytes, audit)
	elif str(audit.get("schema", "")) == RESOURCE_AUDIT_SCHEMA:
		reopened = ResourceReopenScript.new().audit(output_bytes, audit)
	elif str(audit.get("schema", "")) == CHOICE_AUDIT_SCHEMA:
		reopened = ChoiceReopenScript.new().audit(output_bytes, audit)
	elif str(audit.get("schema", "")) == CALL_AUDIT_SCHEMA:
		reopened = CallReopenScript.new().audit(output_bytes, audit)
	elif str(audit.get("schema", "")) == SHARED_CALL_AUDIT_SCHEMA:
		reopened = SharedCallReopenScript.new().audit(output_bytes, audit)
	elif str(audit.get("schema", "")) == CONTROL_TARGET_AUDIT_SCHEMA:
		reopened = ControlTargetEditReopenScript.new().audit(output_bytes, audit)
	else:
		return _error("Authoring compile audit schema is not supported by the editor.")
	if not reopened.get("ok", false):
		return _error("Authoring compile reopening failed: %s" % str(reopened.get("error", "validation failed")))
	return reopened


static func read_bundle(directory: String) -> Dictionary:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("manifest.json")))
	if not manifest is Dictionary or manifest.size() != 5 or manifest.get("ok") != true or (str(manifest.get("schema", "")) != SCHEMA and str(manifest.get("schema", "")) not in LEGACY_SCHEMAS):
		return _error("Authoring bundle schema changed.")
	if FingerprintScript.new().fingerprint(manifest) != str(manifest.get("payload_sha256", "")):
		return _error("Authoring bundle fingerprint changed.")
	if not manifest.get("files") is Array or not manifest.get("summary") is Dictionary:
		return _error("Authoring bundle inventory is missing.")
	var files := {}
	var step_names: Array[String] = []
	for row in manifest.files:
		if not row is Dictionary or row.size() != 3 or not _is_known_member(str(row.get("name", ""))) or files.has(row.name):
			return _error("Authoring bundle filename changed.")
		var payload := FileAccess.get_file_as_bytes(directory.path_join(str(row.name)))
		if not _integer(row.get("size")) or payload.size() != int(row.size) or _sha(payload) != str(row.get("sha256", "")):
			return _error("Authoring bundle file changed: %s" % str(row.name))
		files[row.name] = payload
		if str(row.name).begins_with("step-"):
			step_names.append(str(row.name))
	var compiled: bool = manifest.summary.get("compiled") == true
	var stepped := not step_names.is_empty()
	var is_legacy := str(manifest.schema) in LEGACY_SCHEMAS
	if files.has(SEQUENCE_MEMBER) and is_legacy:
		return _error("Legacy authoring bundle cannot carry a sequence.")
	if stepped and not files.has(SEQUENCE_MEMBER):
		return _error("Authoring bundle members changed.")
	var sequence: Dictionary = {}
	if files.has(SEQUENCE_MEMBER):
		sequence = JSON.parse_string((files[SEQUENCE_MEMBER] as PackedByteArray).get_string_from_utf8())
		if not sequence is Dictionary or not sequence.get("steps") is Array or sequence.steps.is_empty():
			return _error("Authoring bundle sequence changed.")
	var expected: int
	if not compiled:
		expected = 3
	elif stepped:
		expected = 3 + 4 + 5 * int(sequence.steps.size())
		for row in sequence.steps:
			if not str(row.get("control_plan_sha256", "")).is_empty():
				expected += 1
	else:
		expected = (9 if files.has("control.plan.json") else 8)
		if files.has(SEQUENCE_MEMBER):
			expected += 1
	if files.has(REGISTRY_MEMBER):
		expected += 1
	if files.has(LIBRARY_MEMBER):
		expected += 1
	if str(manifest.schema) == LEGACY_SCHEMA and files.has("control.plan.json"):
		return _error("Legacy authoring bundles do not support message relocation.")
	if files.size() != expected or not files.has("handoff.json") or not files.has("handoff.payload.json") or not files.has("editable.json"):
		return _error("Authoring bundle members changed.")
	var handoff = JSON.parse_string((files["handoff.json"] as PackedByteArray).get_string_from_utf8())
	if not handoff is Dictionary or str(handoff.get("producer", {}).get("implementation", "")) != "python_phase1_4":
		return _error("Authoring source is not the verified Python handoff.")
	# JSON.parse_string turns integer tokens into floats. Preserve the analyzer's
	# distinct integer/float canonical bytes instead of reserializing parsed data.
	var witness = JSON.parse_string((files["handoff.payload.json"] as PackedByteArray).get_string_from_utf8())
	var source_payload: Dictionary = handoff.duplicate(true)
	source_payload.erase("payload_sha256")
	if str(handoff.get("schema", "")) != VersionScript.MES_ANALYZER_HANDOFF_SCHEMA or witness != source_payload or _sha(files["handoff.payload.json"]) != str(handoff.get("payload_sha256", "")):
		return _error("Authoring source handoff canonical byte witness changed.")
	if str(handoff.payload_sha256) != str(manifest.summary.get("handoff_sha256", "")) or handoff.source_identity != manifest.summary.get("source_identity"):
		return _error("Authoring source summary changed.")
	var result := {"ok": true, "directory": directory, "manifest": manifest, "files": files}
	if compiled and not stepped:
		var audit = JSON.parse_string((files["compile.audit.json"] as PackedByteArray).get_string_from_utf8())
		var proof = JSON.parse_string((files["semantic.diff.json"] as PackedByteArray).get_string_from_utf8())
		if not audit is Dictionary or not proof is Dictionary:
			return _error("Authoring output proof is missing.")
		var reopened := _reopen_step(files["output.mes"], audit, files.has("control.plan.json"))
		if not reopened.get("ok", false):
			return reopened
		var proof_check := SemanticDiffScript.new().validate(proof)
		if not proof_check.get("ok", false):
			return _error("Authoring semantic proof was rejected: %s" % str(proof_check.get("error", "validation failed")))
		if str(audit.source.entry_sha256) != str(manifest.summary.get("source_entry_sha256", "")) or str(audit.output.entry_sha256) != str(manifest.summary.get("output_entry_sha256", "")) or proof.source_identity != handoff.source_identity or str(proof.inputs.compile_audit_sha256) != str(audit.payload_sha256) or str(proof.output_binding.entry_sha256) != str(audit.output.entry_sha256):
			return _error("Authoring proof and source/output bindings disagree.")
		result["proof"] = proof
		result["audit"] = audit
	elif compiled and stepped:
		var chain_proof = JSON.parse_string((files["semantic.diff.json"] as PackedByteArray).get_string_from_utf8())
		if not chain_proof is Dictionary:
			return _error("Authoring output proof is missing.")
		var chain_check := SemanticDiffChainScript.new().validate(chain_proof)
		if not chain_check.get("ok", false):
			return _error("Authoring sequence proof was rejected: %s" % str(chain_check.get("error", "validation failed")))
		var steps: Array[Dictionary] = []
		var previous_output_hash := str(manifest.summary.get("source_entry_sha256", ""))
		var last_audit: Dictionary = {}
		for row in sequence.steps:
			var index := int(row.get("index", 0))
			var step_audit = JSON.parse_string((files[step_member(index, "compile.audit.json")] as PackedByteArray).get_string_from_utf8())
			var step_proof = JSON.parse_string((files[step_member(index, "semantic.diff.json")] as PackedByteArray).get_string_from_utf8())
			var step_output: PackedByteArray = files[step_member(index, "output.mes")]
			if not step_audit is Dictionary or not step_proof is Dictionary:
				return _error("Authoring step proof is missing.")
			var has_control_plan := files.has(step_member(index, "control.plan.json"))
			var step_reopened := _reopen_step(step_output, step_audit, has_control_plan)
			if not step_reopened.get("ok", false):
				return step_reopened
			var step_proof_check := SemanticDiffScript.new().validate(step_proof)
			if not step_proof_check.get("ok", false):
				return _error("Authoring step semantic proof was rejected: %s" % str(step_proof_check.get("error", "validation failed")))
			if (
				str(step_audit.source.entry_sha256) != previous_output_hash
				or str(step_audit.output.entry_sha256) != str(row.get("output_entry_sha256", ""))
				or step_proof.source_identity != handoff.source_identity
				or str(step_proof.inputs.compile_audit_sha256) != str(step_audit.payload_sha256)
				or str(step_proof.output_binding.entry_sha256) != str(step_audit.output.entry_sha256)
			):
				return _error("Authoring step proof and source/output bindings disagree.")
			steps.append({
				"index": index, "operation": row.get("operation", {}), "audit": step_audit,
				"proof": step_proof, "output": step_output, "control_plan": has_control_plan,
			})
			previous_output_hash = str(step_audit.output.entry_sha256)
			last_audit = step_audit
		if previous_output_hash != str(manifest.summary.get("output_entry_sha256", "")) or str(chain_proof.output_binding.entry_sha256) != previous_output_hash:
			return _error("Authoring sequence chain does not match the published output.")
		result["proof"] = chain_proof
		result["audit"] = last_audit
		result["steps"] = steps
	return result


static func _new_path(workspace: String) -> String:
	if workspace.is_empty():
		return ""
	var root := ProjectSettings.globalize_path(workspace).simplify_path().path_join("authoring")
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		return ""
	return root.path_join(Crypto.new().generate_random_bytes(16).hex_encode())


static func _validate_step_source(step_source: PackedByteArray, step_output: PackedByteArray, audit: Dictionary, proof: Dictionary) -> Dictionary:
	if _sha(step_source) != str(audit.source.entry_sha256):
		return _error("The original source no longer matches the authoring audit.")
	if str(proof.get("schema", "")) == "kakyu_mes_semantic_diff/v4":
		return BindingScript.bind(step_source, step_output, proof)
	var fields = SOURCE_FIELDS.get(str(audit.get("schema", "")))
	if fields == null:
		return _error("Authoring compile audit schema is not supported by the editor.")
	var section: Dictionary = audit.get(str(fields.section), {})
	var start := int(audit.source.code_offset) + int(section[fields.start])
	var end := int(audit.source.code_offset) + int(section[fields.end])
	if start < 0 or end <= start or end > step_source.size() or step_output.size() != step_source.size():
		return _error("The authoring expression boundary changed.")
	if _sha(step_source.slice(start, end)) != str(section[fields.hash]):
		return _error("The original patched bytes differ from the compile audit.")
	var expected := step_source.slice(0, start)
	expected.append_array(step_output.slice(start, end))
	expected.append_array(step_source.slice(end))
	if expected != step_output:
		return _error("The compiled output changes bytes outside the selected patch.")
	return {"ok": true}


static func validate_source(bundle: Dictionary, source: PackedByteArray) -> Dictionary:
	if not bundle.get("ok", false) or not bundle.has("audit"):
		return _error("A verified compiled authoring bundle is required.")
	if not bundle.has("steps"):
		return _validate_step_source(source, bundle.files["output.mes"], bundle.audit, bundle.proof)
	var step_source := source
	var last_result := {"ok": true}
	for step in bundle.steps:
		last_result = _validate_step_source(step_source, step.output, step.audit, step.proof)
		if not last_result.get("ok", false):
			return last_result
		step_source = step.output
	return last_result


static func _sha(payload: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish().hex_encode()


static func _integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
