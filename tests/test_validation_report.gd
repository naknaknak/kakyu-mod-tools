extends "res://tests/test_case.gd"

const ReportScript := preload("res://tools/content_suite/validation_report.gd")
const SessionScript := preload("res://tools/content_suite/validation_session.gd")
const LauncherScene := preload("res://tools/content_suite/apps/content_suite_launcher.tscn")
const TEST_ROOT := "user://validation_report_test"
const RUN_ID := "d17356f0-1f6b-4bb8-8d10-6088b16f6ac0"

var _spawn_arguments := PackedStringArray()
var _spawn_console := true


func _ready() -> void:
	_test_reports()
	_test_sessions()
	await _test_panel()
	var root := ProjectSettings.globalize_path(TEST_ROOT)
	var directory := DirAccess.open(root)
	if directory != null:
		for filename in directory.get_files():
			DirAccess.remove_absolute(root.path_join(filename))
		DirAccess.remove_absolute(root)
	get_tree().quit(1 if _failed else 0)


func _test_reports() -> void:
	var payload := _payload()
	var parsed := ReportScript.parse_text(_envelope(payload))
	_check(parsed.ok and not parsed.legacy and parsed.payload.check_count == 1, "v3 verifies the original payload string fingerprint")
	var envelope: Dictionary = JSON.parse_string(_envelope(payload))
	envelope.payload_json += " "
	_check(not ReportScript.parse_text(JSON.stringify(envelope)).ok, "changed raw payload is rejected before parsing")
	envelope.payload_sha256 = envelope.payload_json.sha256_text()
	_check(ReportScript.parse_text(JSON.stringify(envelope)).ok, "payload whitespace is valid when its exact UTF-8 fingerprint agrees")
	envelope.extra = true
	_check(not ReportScript.parse_text(JSON.stringify(envelope)).ok, "unknown envelope fields fail closed")
	for mutation in [{"check_count": 2}, {"passed": true}, {"duration_seconds": -1}, {"schema": "unknown"}, {"status": "failed"}, {"original_corpus": true}]:
		var changed := payload.duplicate(true)
		changed.merge(mutation, true)
		_check(not ReportScript.parse_text(_envelope(changed)).ok, "invalid summary fields reject: %s" % str(mutation))
	var changed := payload.duplicate(true)
	changed.checks[0].return_code = 1
	_check(not ReportScript.parse_text(_envelope(changed)).ok, "passing check cannot carry a failed exit code")
	changed = payload.duplicate(true)
	changed.coverage.append(changed.coverage[0].duplicate(true))
	_check(not ReportScript.parse_text(_envelope(changed)).ok, "duplicate coverage identities fail closed")
	changed = payload.duplicate(true)
	changed.coverage.pop_back()
	_check(not ReportScript.parse_text(_envelope(changed)).ok, "partial coverage cannot hide an omitted v3 group")
	changed = payload.duplicate(true)
	changed.coverage[0].id = "unknown_group"
	_check(not ReportScript.parse_text(_envelope(changed)).ok, "arbitrary coverage identities cannot replace a required v3 group")
	changed = payload.duplicate(true)
	changed.coverage[0].reason = ""
	_check(not ReportScript.parse_text(_envelope(changed)).ok, "included coverage also requires an explicit reason")
	changed = payload.duplicate(true)
	changed.coverage[0].status = "not_run"
	_check(not ReportScript.parse_text(_envelope(changed)).ok, "unrun coverage cannot claim executed checks")
	changed = payload.duplicate(true)
	changed.context.workspace_validation = "passed"
	_check(not ReportScript.parse_text(_envelope(changed)).ok, "repository suite cannot impersonate workspace validation")
	changed = payload.duplicate(true)
	changed.status = "configuration_error"
	changed.configuration_error = "Missing configured executable."
	changed.checks = []
	changed.check_count = 0
	changed.passed = 0
	for group in changed.coverage:
		group.status = "not_run"
		group.reason = "Configuration failed."
		group.check_count = 0
	_check(ReportScript.parse_text(_envelope(changed)).ok, "configuration failure preserves zero execution and its reason")
	var legacy := _legacy_payload()
	var migrated := ReportScript.parse_text(JSON.stringify(legacy))
	_check(migrated.ok and migrated.legacy and migrated.integrity == "unsigned_legacy", "v2 migrates only as unsigned legacy evidence")
	_check(migrated.payload.coverage[0].id == "legacy_unknown" and migrated.payload.run_id.is_empty(), "v2 migration does not invent coverage or a current run identity")
	_check(migrated.payload.context.tier == "full", "v2 migration also reports tier: full so the Launcher reads one shape")
	var v3_parsed := ReportScript.parse_text(_envelope(_v3_payload()))
	_check(v3_parsed.ok and not v3_parsed.legacy and v3_parsed.integrity == "verified", "a v3 report is a complete earlier form, not unsigned legacy evidence")
	_check(v3_parsed.payload.context.tier == "full", "a loaded v3 report reports tier: full to its consumers")
	_check(v3_parsed.payload.cached == 0 and v3_parsed.payload.context.cache == "not_consulted" and v3_parsed.payload.context.cache_dir == "", "a loaded v3 report also reports cache: not_consulted, cached: 0 to its consumers")
	var v4_parsed := ReportScript.parse_text(_envelope(_v4_payload()))
	_check(v4_parsed.ok and not v4_parsed.legacy and v4_parsed.integrity == "verified", "a v4 report is a complete earlier form, not unsigned legacy evidence")
	_check(v4_parsed.payload.cached == 0 and v4_parsed.payload.context.cache == "not_consulted" and v4_parsed.payload.context.cache_dir == "", "a loaded v4 report reports cache: not_consulted, cached: 0 to its consumers")
	_check(v4_parsed.payload.context.jobs == 1, "a loaded v4 report also reports jobs: 1 to its consumers")
	var v5_parsed := ReportScript.parse_text(_envelope(_v5_payload()))
	_check(v5_parsed.ok and not v5_parsed.legacy and v5_parsed.integrity == "verified", "a v5 report is a complete earlier form, not unsigned legacy evidence")
	_check(v5_parsed.payload.context.jobs == 1, "a loaded v5 report reports jobs: 1 to its consumers")
	var cached_payload := _payload("full", "consulted", "analysis/validation_cache")
	cached_payload.checks.append({
		"name": "cached fixture", "status": "passed", "return_code": 0, "duration_seconds": 0,
		"cached": true, "cached_at": "2026-09-21T00:00:00+00:00", "cached_run_id": RUN_ID,
	})
	cached_payload.check_count = 2
	cached_payload.passed = 2
	cached_payload.cached = 1
	cached_payload.coverage[0].check_count = 2
	var cached_parsed := ReportScript.parse_text(_envelope(cached_payload))
	_check(cached_parsed.ok and cached_parsed.payload.cached == 1, "a v5 report with one cached row counts it")
	var wrong_cached_count := cached_payload.duplicate(true)
	wrong_cached_count.cached = 0
	_check(not ReportScript.parse_text(_envelope(wrong_cached_count)).ok, "a v5 report's cached count must match its cached rows")
	# TD-32 part 3c, section 3: an int `cached` field (`cached: 1`, not the
	# bool `true`) must fail closed, not raise a GDScript type-mismatch
	# SCRIPT ERROR out of the reader (`check.cached != true` did, for any
	# non-bool value).
	var int_cached_flag := cached_payload.duplicate(true)
	int_cached_flag.checks[1].cached = 1
	_check(not ReportScript.parse_text(_envelope(int_cached_flag)).ok, "an int cached field is rejected, not crashed on")
	var partial_cache_fields := _payload()
	partial_cache_fields.checks[0].cached = true
	_check(not ReportScript.parse_text(_envelope(partial_cache_fields)).ok, "a cached check result must carry cached, cached_at and cached_run_id together")
	var not_consulted_but_cached := _payload()
	not_consulted_but_cached.checks[0].merge({"cached": true, "cached_at": "2026-09-21T00:00:00+00:00", "cached_run_id": RUN_ID, "duration_seconds": 0}, true)
	not_consulted_but_cached.cached = 1
	_check(not ReportScript.parse_text(_envelope(not_consulted_but_cached)).ok, "a not_consulted cache cannot report a cached check")
	var v4_wrong_tier := payload.duplicate(true)
	v4_wrong_tier.context = v4_wrong_tier.context.duplicate(true)
	v4_wrong_tier.context.tier = "archive_slow"
	_check(not ReportScript.parse_text(_envelope(v4_wrong_tier)).ok, "an unknown tier is rejected")
	var v4_tier_disagreement := payload.duplicate(true)
	v4_tier_disagreement.context = v4_tier_disagreement.context.duplicate(true)
	v4_tier_disagreement.context.tier = "local"
	v4_tier_disagreement.context.elfimage = "fixture-source"
	v4_tier_disagreement.original_corpus = true
	_check(not ReportScript.parse_text(_envelope(v4_tier_disagreement)).ok, "a local-tier report cannot claim original-corpus coverage")
	_check(not ReportScript.parse_text("{broken").ok, "malformed JSON fails closed")
	_check(not ReportScript.parse_text(" ".repeat(ReportScript.MAX_BYTES + 1)).ok, "oversized reports are bounded before JSON parsing")


func _test_sessions() -> void:
	var session := _session()
	var started := session.start("", "")
	_check(started.ok and session.is_running(), "session starts a nonblocking child process")
	_check(not _spawn_console and "--report" in _spawn_arguments and "--run-id" in _spawn_arguments and "--godot" in _spawn_arguments, "spawn uses direct argv with unique report identity and no console")
	_check(not session.start("", "").ok, "duplicate start is rejected")
	var request := session.active_request()
	request.elfimage = "mutated by caller"
	_check(session.active_request().elfimage.is_empty(), "active source selection cannot be changed through a returned request")
	var payload := _payload()
	payload.run_id = started.request.run_id
	_write_report(started.request.report_path, payload)
	var completed := session.poll()
	_check(completed.finished and completed.result.ok and not session.is_running(), "session consumes only its completed report after process exit")
	var next := session.start("", "")
	_check(next.ok and session.last_result.is_empty(), "a new run immediately discards the previous successful result")
	_write_report(next.request.report_path, payload)
	_check(not session.poll().result.ok, "a report from the previous run cannot satisfy a new run")
	next = session.start("", "")
	_check(next.ok and not session.poll().result.ok, "missing current report fails instead of showing an old success")
	next = session.start("", "")
	payload.run_id = next.request.run_id
	_write_report(next.request.report_path, payload)
	session.process_exit_code = func(_pid: int) -> int: return 1
	_check(not session.poll().result.ok, "process failure cannot be overridden by a passing report")
	var absent := SessionScript.new(ProjectSettings.globalize_path(TEST_ROOT), OS.get_executable_path(), OS.get_executable_path())
	_check(not absent.availability().ok, "an exported installation without the development runner reports execution unavailable")
	_check(SessionScript._same_path("C:/source/ELFIMAGE", "C:\\source\\ELFIMAGE"), "Python Windows separators and Godot paths identify the same selected source")
	_check(not SessionScript._same_path("C:/source/ELFIMAGE", "C:/other/ELFIMAGE"), "normalizing source paths does not accept another directory")


func _test_panel() -> void:
	var launcher: Control = LauncherScene.instantiate()
	add_child(launcher)
	await get_tree().process_frame
	var panel: KakyuValidationPanel = launcher.get("validation_panel")
	panel.session = _session()
	panel.show_for_source("C:/example/ELFIMAGE")
	_check(panel.visible and not panel.run_button.disabled, "launcher validation panel opens without starting a process")
	panel.display_result(ReportScript.parse_text(_envelope(_payload())), "Completed run")
	_check(panel.report_origin == "Completed run" and panel.status_label.text.begins_with("Completed run:"), "completed results are labeled as this run")
	_check(panel.context_label.text.contains("tier: full"), "the report viewer shows the run's tier beside the source context")
	panel.display_result(ReportScript.parse_text(_envelope(_payload("local"))), "Completed run")
	_check(panel.context_label.text.contains("tier: local"), "a local-tier report's tier is not hidden behind the always-full default")
	var cache_payload := _payload("full", "consulted", "analysis/validation_cache")
	cache_payload.checks.append({
		"name": "cached fixture", "status": "passed", "return_code": 0, "duration_seconds": 0,
		"cached": true, "cached_at": "2026-09-21T00:00:00+00:00", "cached_run_id": RUN_ID,
	})
	cache_payload.check_count = 2
	cache_payload.passed = 2
	cache_payload.cached = 1
	cache_payload.coverage[0].check_count = 2
	panel.display_result(ReportScript.parse_text(_envelope(cache_payload)), "Completed run")
	_check(panel.context_label.text.contains("cache: consulted, 1 cached"), "the report viewer shows the cache state and cached count beside the tier")
	var cached_row := panel.checks_tree.get_root().get_child(1)
	_check(cached_row.get_text(0).contains("(cached)"), "a cached check row is marked in the checks tree")
	var failed_payload := _payload()
	failed_payload.status = "failed"
	failed_payload.passed = 0
	failed_payload.failed = 1
	failed_payload.checks[0].status = "failed"
	failed_payload.checks[0].return_code = 1
	failed_payload.checks[0].output_tail = "Synthetic mismatch evidence"
	panel.display_result(ReportScript.parse_text(_envelope(failed_payload)), "Completed run")
	_check(panel.output_edit.text == "Synthetic mismatch evidence" and panel.status_label.text.contains("1 failed"), "failed check output and aggregate failure remain visible")
	panel.display_result(ReportScript.parse_text(JSON.stringify(_legacy_payload())), "Saved report")
	_check(panel.report_origin == "Saved report" and panel.context_label.text.contains("unsigned"), "opened legacy report remains saved unsigned evidence")
	_check(panel.context_label.text.contains("workspace modifications were not validated"), "viewer labels the repository-only validation boundary")
	for window_size in [Vector2i(1024, 640), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		get_window().size = window_size
		await get_tree().process_frame
		await get_tree().process_frame
		_check(panel.size == Vector2(window_size), "validation panel fills %s" % str(window_size))
		var fits := panel.layout.get_combined_minimum_size().x <= panel.size.x - 28 and panel.layout.get_combined_minimum_size().y <= panel.size.y - 28
		if not fits:
			print("Validation layout: viewport=", panel.size, " minimum=", panel.layout.get_combined_minimum_size())
		_check(fits, "validation controls fit %s without changing original logical coordinates" % str(window_size))
	panel.session.process_running = func(_pid: int) -> bool: return true
	panel.call("_run_validation")
	_check(panel.session.is_running() and panel.run_button.disabled and panel.open_button.disabled, "active run prevents duplicate starts and report replacement")
	panel.show_for_source("C:/different/ELFIMAGE")
	_check(panel.source_label.text == "C:/example/ELFIMAGE", "reopening the panel does not replace an active run's source selection")
	panel.hide()
	_check(panel.session.is_running(), "closing the panel leaves the background validation session intact")
	launcher.queue_free()
	await get_tree().process_frame


func _session() -> KakyuValidationSession:
	var session := SessionScript.new(ProjectSettings.globalize_path("res://"), OS.get_executable_path(), OS.get_executable_path(), ProjectSettings.globalize_path(TEST_ROOT))
	session.spawn_process = func(_path: String, arguments: PackedStringArray, open_console: bool) -> int:
		_spawn_arguments = arguments
		_spawn_console = open_console
		return 321
	session.process_running = func(_pid: int) -> bool: return false
	session.process_exit_code = func(_pid: int) -> int: return 0
	return session


static func _payload(tier: String = "full", cache: String = "not_consulted", cache_dir: String = "") -> Dictionary:
	return {
		"schema": ReportScript.SCHEMA, "run_id": RUN_ID,
		"status": "passed", "check_count": 1, "passed": 1, "failed": 0,
		"duration_seconds": 1.25, "original_corpus": false, "native_executable_audit": false,
		"checks": [{"name": "Synthetic example", "status": "passed", "return_code": 0, "duration_seconds": 1.25}],
		"coverage": [
			{"id": "synthetic", "title": "Local synthetic", "status": "included", "reason": "Selected", "check_count": 1},
			{"id": "original_corpus", "title": "Original archive checks", "status": "not_run", "reason": "No original source selected.", "check_count": 0},
			{"id": "event_corpus", "title": "Exhaustive MES entry audit", "status": "not_run", "reason": "No original source selected.", "check_count": 0},
			{"id": "native_executable", "title": "Native executable checks", "status": "not_run", "reason": "No executable selected.", "check_count": 0},
			{"id": "native_corpus", "title": "Native checks with archives", "status": "not_run", "reason": "No original source or executable selected.", "check_count": 0},
			{"id": "voice_payload", "title": "Native voice payload check", "status": "not_run", "reason": "No original source or executable selected.", "check_count": 0},
		],
		"context": {"kind": "repository_suite", "elfimage": "", "executable": "", "workspace_validation": "not_performed", "tier": tier, "cache": cache, "cache_dir": cache_dir, "jobs": 1},
		"configuration_error": "",
		"cached": 0,
	}


static func _v5_payload() -> Dictionary:
	# The schema TD-33 superseded: cached, but no --jobs concept.
	var v5 := _payload()
	v5.schema = ReportScript.SCHEMA_V5
	v5.context = v5.context.duplicate(true)
	v5.context.erase("jobs")
	return v5


static func _v4_payload() -> Dictionary:
	# The schema TD-32 part 3b superseded: tiered, but no cache concept.
	var v4 := _v5_payload()
	v4.schema = ReportScript.SCHEMA_V4
	v4.context = v4.context.duplicate(true)
	v4.context.erase("cache")
	v4.context.erase("cache_dir")
	v4.erase("cached")
	return v4


static func _v3_payload() -> Dictionary:
	# The prior schema, exactly as it shipped: no `context.tier`, always the
	# (then-only) full batch.
	var v3 := _v4_payload()
	v3.schema = ReportScript.SCHEMA_V3
	v3.context = v3.context.duplicate(true)
	v3.context.erase("tier")
	return v3


static func _legacy_payload() -> Dictionary:
	var legacy := _v4_payload()
	legacy.schema = ReportScript.LEGACY_SCHEMA
	for field in ["run_id", "coverage", "context", "configuration_error"]:
		legacy.erase(field)
	return legacy


static func _envelope(payload: Dictionary) -> String:
	var payload_json := JSON.stringify(payload)
	return JSON.stringify({"schema": payload.schema, "payload_json": payload_json, "payload_sha256": payload_json.sha256_text()})


static func _write_report(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(_envelope(payload))
	file.close()
