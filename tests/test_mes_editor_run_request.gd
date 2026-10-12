extends "res://tests/test_case.gd"

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const RequestScript := preload("res://content_core/mes_editor_run_request.gd")


func _ready() -> void:
	var request_builder := RequestScript.new()
	var snapshot := _snapshot()
	var original := request_builder.build(
		snapshot, _content("original_arc", "b", "b"), _analysis_launch(),
		_interface("exact_original", ContentCoreVersionScript.MES_EXACT_ORIGINAL_INTERFACE_SCHEMA, "b", "b", "b", "original_engine_compatible")
	)
	_check(original.ok, "MES Editor Run request binds an exact-original analysis entry")
	_check(request_builder.validate(original).ok, "MES Editor Run request validates its deterministic payload fingerprint")
	_check(request_builder.validate_effective(original, "b".repeat(64), 40).ok, "MES Editor Run request rechecks effective MES identity")

	var derived_snapshot := snapshot.duplicate(true)
	var derived := request_builder.build(
		derived_snapshot, _content("original_arc", "b", "b"), _catalog_launch("project"),
		_interface("exact_original", ContentCoreVersionScript.MES_EXACT_ORIGINAL_INTERFACE_SCHEMA, "b", "b", "b", "original_engine_compatible")
	)
	_check(derived.ok and str(derived.launch.mode) == "catalog_event", "MES Editor Run request binds a project preset to an exact-original entry")
	_check(request_builder.validate_for_workspace(derived, derived_snapshot).ok, "MES Editor Run request rechecks the active workspace content and preset")

	var changed_snapshot := derived_snapshot.duplicate(true)
	changed_snapshot.manifest_sha256 = "e".repeat(64)
	_check(not request_builder.validate_for_workspace(derived, changed_snapshot).ok, "MES Editor Run request rejects a changed workspace generation")
	_check(not request_builder.validate_effective(derived, "f".repeat(64), 40).ok, "MES Editor Run request rejects changed effective MES bytes")

	_check(
		not request_builder.build(
			snapshot, _content("overlay", "b", "b"), _analysis_launch(),
			_interface("exact_original", ContentCoreVersionScript.MES_EXACT_ORIGINAL_INTERFACE_SCHEMA, "b", "b", "b", "original_engine_compatible")
		).ok,
		"MES Editor Run request rejects an overlay content source"
	)
	_check(
		not request_builder.build(
			snapshot, _content("original_arc", "b", "b"), _analysis_launch(),
			_interface("semantic_diff", ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA_V4, "d", "b", "b", "remake_only")
		).ok,
		"MES Editor Run request rejects a semantic-diff interface kind"
	)
	var stale_exact := request_builder.build(
		snapshot, _content("original_arc", "b", "c"), _analysis_launch(),
		_interface("exact_original", ContentCoreVersionScript.MES_EXACT_ORIGINAL_INTERFACE_SCHEMA, "b", "b", "c", "original_engine_compatible")
	)
	_check(not stale_exact.ok, "exact-original Run requires identical source and effective entry hashes")

	var unknown := original.duplicate(true)
	unknown["future"] = true
	unknown.payload_sha256 = request_builder.fingerprint(unknown)
	_check(not request_builder.validate(unknown).ok, "MES Editor Run request rejects unknown fields")
	var fractional := original.duplicate(true)
	fractional.content.effective_byte_count = 40.5
	fractional.payload_sha256 = request_builder.fingerprint(fractional)
	_check(not request_builder.validate(fractional).ok, "MES Editor Run request rejects fractional byte counts")
	_check(not JSON.stringify(derived).contains("C:\\"), "MES Editor Run request contains no machine-local path")
	get_tree().quit(1 if _failed else 0)


func _snapshot() -> Dictionary:
	return {
		"schema": ContentCoreVersionScript.CONTENT_WORKSPACE_SNAPSHOT_SCHEMA,
		"generation_sha256": "1".repeat(64), "project_sha256": "2".repeat(64),
		"manifest_sha256": "3".repeat(64),
		"project": {
			"project_id": "run.test", "project_revision": 2,
			"event_player": {
				"catalog_id": "kakyu-original-events",
				"presets": [{"preset_id": "night.route", "event_id": "original/eventb03/01m-0000788f"}],
			},
		},
		"manifest": {"replacements": []},
		"source_content_set": {
			"fingerprint_sha256": "4".repeat(64),
			"archives": [{"archive": "mes.arc", "sha256": "a".repeat(64)}],
		},
	}


func _content(source: String, source_entry_digit: String, effective_digit: String) -> Dictionary:
	return {
		"archive": "mes.arc", "entry": "EVENTB03.MES", "source": source,
		"source_archive_sha256": "a".repeat(64),
		"source_entry_sha256": source_entry_digit.repeat(64),
		"effective_entry_sha256": effective_digit.repeat(64), "effective_byte_count": 40,
	}


func _analysis_launch() -> Dictionary:
	return {
		"mode": "analysis_entry", "start_kind": "code_offset", "start_value": 0,
		"catalog_id": "", "event_id": "", "preset_id": "", "preset_source": "none",
	}


func _catalog_launch(preset_source: String) -> Dictionary:
	return {
		"mode": "catalog_event", "start_kind": "catalog_preset", "start_value": 0,
		"catalog_id": "kakyu-original-events", "event_id": "original/eventb03/01m-0000788f",
		"preset_id": "night.route", "preset_source": preset_source,
	}


func _interface(
	kind: String, contract_schema: String, proof_digit: String,
	source_digit: String, output_digit: String, compatibility: String
) -> Dictionary:
	return {
		"kind": kind, "contract_schema": contract_schema,
		"proof_sha256": proof_digit.repeat(64),
		"source_entry_sha256": source_digit.repeat(64),
		"output_entry_sha256": output_digit.repeat(64),
		"compatibility": compatibility, "control_flow_compatible": true,
	}
