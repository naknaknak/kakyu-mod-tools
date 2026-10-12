class_name KakyuMesEditorRunRequest
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const TOP_LEVEL_KEYS := [
	"ok", "schema", "producer", "workspace", "content", "launch", "interface",
	"payload_sha256",
]
const WORKSPACE_KEYS := [
	"project_id", "project_revision", "generation_sha256", "project_sha256",
	"manifest_sha256", "source_content_set_sha256",
]
const CONTENT_KEYS := [
	"archive", "entry", "source", "source_archive_sha256", "source_entry_sha256",
	"effective_entry_sha256", "effective_byte_count",
]
const LAUNCH_KEYS := [
	"mode", "start_kind", "start_value", "catalog_id", "event_id", "preset_id",
	"preset_source",
]
const INTERFACE_KEYS := [
	"kind", "contract_schema", "proof_sha256", "source_entry_sha256",
	"output_entry_sha256", "compatibility", "control_flow_compatible",
]
const CONTENT_SOURCES := ["original_arc"]


func build(
	workspace_snapshot: Dictionary,
	content_binding: Dictionary,
	launch: Dictionary,
	interface_contract: Dictionary
) -> Dictionary:
	var document := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_EDITOR_RUN_REQUEST_SCHEMA,
		"producer": {
			"implementation": "content_core_mes_editor_run_request",
			"contract": ContentCoreVersionScript.MES_EDITOR_RUN_REQUEST_SCHEMA,
		},
		"workspace": ContractValues.workspace_binding(workspace_snapshot),
		"content": content_binding.duplicate(true),
		"launch": launch.duplicate(true),
		"interface": interface_contract.duplicate(true),
	}
	document["payload_sha256"] = fingerprint(document)
	var checked := validate_for_workspace(document, workspace_snapshot)
	if not checked.ok:
		return checked
	return document


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_EDITOR_RUN_REQUEST_SCHEMA
		or not ContractValues.has_exact_keys(document, TOP_LEVEL_KEYS)
		or document.get("producer") != {
			"implementation": "content_core_mes_editor_run_request",
			"contract": ContentCoreVersionScript.MES_EDITOR_RUN_REQUEST_SCHEMA,
		}
	):
		return _error("MES Editor Run request schema or producer changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES Editor Run request fingerprint changed.")
	var workspace = document.get("workspace")
	var content = document.get("content")
	var launch = document.get("launch")
	var interface_contract = document.get("interface")
	if not _validate_workspace(workspace):
		return _error("MES Editor Run workspace binding is invalid.")
	if not _validate_content(content):
		return _error("MES Editor Run request must carry the original entry unchanged.")
	if not _validate_launch(launch):
		return _error("MES Editor Run launch selection is invalid.")
	if not _validate_interface(interface_contract, content):
		return _error("MES Editor Run request interface must be exact_original.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_EDITOR_RUN_REQUEST_SCHEMA,
		"payload_sha256": retained_hash,
		"mode": str(launch.mode),
		"entry": str(content.entry),
		"effective_entry_sha256": str(content.effective_entry_sha256),
	}


func validate_for_workspace(document: Dictionary, workspace_snapshot: Dictionary) -> Dictionary:
	var checked := validate(document)
	if not checked.ok:
		return checked
	var expected := ContractValues.workspace_binding(workspace_snapshot)
	if expected.is_empty() or document.workspace != expected:
		return _error("MES Editor Run workspace generation changed.")
	if not _workspace_content_matches(document.content, workspace_snapshot):
		return _error("MES Editor Run workspace content binding changed.")
	var launch: Dictionary = document.launch
	if str(launch.mode) == "catalog_event":
		var project: Dictionary = workspace_snapshot.get("project", {})
		var event_player: Dictionary = project.get("event_player", {})
		if str(launch.catalog_id) != str(event_player.get("catalog_id", "")):
			return _error("MES Editor Run Event Catalog binding changed.")
		if str(launch.preset_source) == "project" and not _has_project_preset(
			event_player.get("presets", []), str(launch.event_id), str(launch.preset_id)
		):
			return _error("MES Editor Run workspace preset changed.")
	return checked


func validate_effective(document: Dictionary, effective_sha256: String, effective_byte_count: Variant) -> Dictionary:
	var checked := validate(document)
	if not checked.ok:
		return checked
	if (
		not ContractValues.is_sha256(effective_sha256)
		or not _json_integer(effective_byte_count)
		or int(effective_byte_count) <= 0
		or str(document.content.effective_entry_sha256) != effective_sha256
		or int(document.content.effective_byte_count) != int(effective_byte_count)
	):
		return _error("MES Editor Run effective MES changed after request creation.")
	return checked


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _validate_workspace(value: Variant) -> bool:
	return (
		value is Dictionary and ContractValues.has_exact_keys(value, WORKSPACE_KEYS)
		and ContractValues.is_identifier(str(value.project_id))
		and _json_integer(value.project_revision) and int(value.project_revision) > 0
		and ContractValues.hash_values(value, [
			"generation_sha256", "project_sha256", "manifest_sha256",
			"source_content_set_sha256",
		])
	)


func _validate_content(value: Variant) -> bool:
	return (
		value is Dictionary and ContractValues.has_exact_keys(value, CONTENT_KEYS)
		and str(value.archive).to_lower() == "mes.arc"
		and ArcReaderScript.is_safe_entry_name(str(value.entry))
		and str(value.source) in CONTENT_SOURCES
		and ContractValues.hash_values(value, [
			"source_archive_sha256", "source_entry_sha256", "effective_entry_sha256",
		])
		and _json_integer(value.effective_byte_count) and int(value.effective_byte_count) > 0
		and str(value.effective_entry_sha256) == str(value.source_entry_sha256)
	)


func _validate_launch(value: Variant) -> bool:
	if not value is Dictionary or not ContractValues.has_exact_keys(value, LAUNCH_KEYS):
		return false
	if not _json_integer(value.start_value) or int(value.start_value) < 0:
		return false
	match str(value.mode):
		"analysis_entry":
			return (
				str(value.start_kind) in ["code_offset", "address_entry"]
				and str(value.catalog_id).is_empty() and str(value.event_id).is_empty()
				and str(value.preset_id).is_empty() and str(value.preset_source) == "none"
			)
		"catalog_event":
			return (
				str(value.start_kind) == "catalog_preset" and int(value.start_value) == 0
				and ContractValues.is_identifier(str(value.catalog_id)) and _is_event_id(str(value.event_id))
				and ContractValues.is_identifier(str(value.preset_id))
				and str(value.preset_source) in ["catalog", "project"]
			)
	return false


func _validate_interface(value: Variant, content: Dictionary) -> bool:
	if (
		not value is Dictionary or not ContractValues.has_exact_keys(value, INTERFACE_KEYS)
		or not ContractValues.hash_values(value, [
			"proof_sha256", "source_entry_sha256", "output_entry_sha256",
		])
		or value.control_flow_compatible != true
		or str(value.source_entry_sha256) != str(content.source_entry_sha256)
		or str(value.output_entry_sha256) != str(content.effective_entry_sha256)
	):
		return false
	match str(value.kind):
		"exact_original":
			return (
				str(content.source) == "original_arc"
				and str(content.source_entry_sha256) == str(content.effective_entry_sha256)
				and str(value.contract_schema) == ContentCoreVersionScript.MES_EXACT_ORIGINAL_INTERFACE_SCHEMA
				and str(value.proof_sha256) == str(content.source_entry_sha256)
				and str(value.compatibility) == "original_engine_compatible"
			)
	return false


func _has_project_preset(presets: Variant, event_id: String, preset_id: String) -> bool:
	if not presets is Array:
		return false
	for value in presets:
		if (
			value is Dictionary and str(value.get("event_id", "")) == event_id
			and str(value.get("preset_id", "")) == preset_id
		):
			return true
	return false


func _workspace_content_matches(content: Dictionary, snapshot: Dictionary) -> bool:
	var source_set: Dictionary = snapshot.get("source_content_set", {})
	var archive_matched := false
	for value in source_set.get("archives", []):
		if (
			value is Dictionary and str(value.get("archive", "")).to_lower() == "mes.arc"
			and str(value.get("sha256", "")) == str(content.source_archive_sha256)
		):
			archive_matched = true
			break
	if not archive_matched:
		return false
	var replacement: Dictionary = {}
	for value in snapshot.get("manifest", {}).get("replacements", []):
		if (
			value is Dictionary
			and str(value.get("target_archive", "")).to_lower() == "mes.arc"
			and str(value.get("target_entry", "")).to_upper() == str(content.entry).to_upper()
		):
			replacement = value
			break
	if str(content.source) == "original_arc":
		return replacement.is_empty()
	return false


func _json_integer(value: Variant) -> bool:
	return (
		(value is int or value is float) and is_finite(float(value))
		and float(value) == floor(float(value)) and abs(float(value)) <= 4294967295.0
	)


func _is_event_id(value: String) -> bool:
	if (
		value.is_empty() or value.length() > 128 or value != value.to_lower()
		or value.begins_with("/") or value.ends_with("/")
		or value.contains("//") or value.contains("..")
	):
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789-_/":
			return false
	return true


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"schema": ContentCoreVersionScript.MES_EDITOR_RUN_REQUEST_SCHEMA,
		"error": message,
	}
