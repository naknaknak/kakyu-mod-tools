class_name KakyuContentSelection
extends RefCounted

## A light, app-agnostic selection document: a named workspace binding plus an
## original archive/entry and an optional catalog event/preset. WD-09.
##
## Any Content Suite app can produce one for another; Event Player only ever
## consumes an original mes.arc selection (it is original-reference only).

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const TOP_LEVEL_KEYS := ["ok", "schema", "producer", "workspace", "selection", "purpose", "payload_sha256"]
const PRODUCER_KEYS := ["app", "contract"]
const PRODUCER_APPS := {
	"audio_arc_editor": true, "mes_editor": true, "arc_browser": true,
	"image_arc_editor": true, "event_player": true, "launcher": true,
}
const WORKSPACE_KEYS := [
	"project_id", "project_revision", "generation_sha256", "project_sha256",
	"manifest_sha256", "source_content_set_sha256",
]
const SELECTION_KEYS := ["archive", "entry", "source_entry_sha256", "catalog_id", "event_id", "preset_id"]
const PURPOSES := {"reference_inspection": true}
const MAX_INPUT_BYTES := 65536


func build(workspace_snapshot: Dictionary, selection: Dictionary, producer_app: String) -> Dictionary:
	var document := {
		"ok": true,
		"schema": ContentCoreVersionScript.CONTENT_SELECTION_SCHEMA,
		"producer": {
			"app": producer_app,
			"contract": ContentCoreVersionScript.CONTENT_SELECTION_SCHEMA,
		},
		"workspace": ContractValues.workspace_binding(workspace_snapshot),
		"selection": selection.duplicate(true),
		"purpose": "reference_inspection",
	}
	document["payload_sha256"] = fingerprint(document)
	var checked := validate_for_workspace(document, workspace_snapshot)
	if not checked.ok:
		return checked
	return document


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.CONTENT_SELECTION_SCHEMA
		or not ContractValues.has_exact_keys(document, TOP_LEVEL_KEYS)
	):
		return _error("Content selection schema changed.")
	var producer = document.get("producer")
	if (
		not producer is Dictionary or not ContractValues.has_exact_keys(producer, PRODUCER_KEYS)
		or not PRODUCER_APPS.has(str(producer.get("app", "")))
		or str(producer.get("contract", "")) != ContentCoreVersionScript.CONTENT_SELECTION_SCHEMA
	):
		return _error("Content selection producer is invalid.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("Content selection fingerprint changed.")
	if not _validate_workspace(document.get("workspace")):
		return _error("Content selection workspace binding is invalid.")
	if not _validate_selection(document.get("selection")):
		return _error("Content selection entry binding is invalid.")
	if not PURPOSES.has(str(document.get("purpose", ""))):
		return _error("Content selection purpose is unsupported.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.CONTENT_SELECTION_SCHEMA,
		"payload_sha256": retained_hash,
		"producer_app": str(producer.app),
		"archive": str(document.selection.archive),
		"entry": str(document.selection.entry),
		"event_id": str(document.selection.event_id),
		"preset_id": str(document.selection.preset_id),
	}


func validate_for_workspace(document: Dictionary, workspace_snapshot: Dictionary) -> Dictionary:
	var checked := validate(document)
	if not checked.ok:
		return checked
	var expected := ContractValues.workspace_binding(workspace_snapshot)
	if expected.is_empty() or document.workspace != expected:
		return _error("Content selection workspace generation changed.")
	if not _archive_is_bound(str(document.selection.archive), workspace_snapshot):
		return _error("Content selection names an archive the workspace does not bind.")
	return checked


func write(document: Dictionary, path: String) -> Dictionary:
	var checked := validate(document)
	if not checked.get("ok", false):
		return checked
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	if FileAccess.file_exists(absolute):
		return _error("Content selection output already exists.")
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return _error("Content selection output could not be opened.")
	file.store_string(FingerprintScript.new().canonical_document_json(document) + "\n")
	file.close()
	var reread := read_path(absolute)
	if not reread.get("ok", false) or reread.document != document:
		return _error("Content selection output failed its publication reopen.")
	return {"ok": true, "path": absolute}


func read_path(path: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	if absolute.get_extension().to_lower() != "json" or not FileAccess.file_exists(absolute):
		return _error("Content selection input is not a readable JSON file.")
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return _error("Content selection input could not be opened.")
	if file.get_length() > MAX_INPUT_BYTES:
		file.close()
		return _error("Content selection input exceeds the bounded size.")
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return _error("Content selection input is not a JSON object.")
	var checked := validate(parsed)
	if not checked.get("ok", false):
		return checked
	return {"ok": true, "document": parsed}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _archive_is_bound(archive_name: String, snapshot: Dictionary) -> bool:
	var source_set: Dictionary = snapshot.get("source_content_set", {})
	for value in source_set.get("archives", []):
		if value is Dictionary and str(value.get("archive", "")).to_lower() == archive_name.to_lower():
			return true
	return false


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


func _validate_selection(value: Variant) -> bool:
	if not value is Dictionary or not ContractValues.has_exact_keys(value, SELECTION_KEYS):
		return false
	if not _is_archive_name(str(value.archive)):
		return false
	if not ArcReaderScript.is_safe_entry_name(str(value.entry)):
		return false
	if not ContractValues.is_sha256(str(value.source_entry_sha256)):
		return false
	var catalog_id := str(value.catalog_id)
	var event_id := str(value.event_id)
	var preset_id := str(value.preset_id)
	if event_id.is_empty():
		return catalog_id.is_empty() and preset_id.is_empty()
	if not ContractValues.is_identifier(catalog_id) or not _is_event_id(event_id):
		return false
	return preset_id.is_empty() or ContractValues.is_identifier(preset_id)


func _is_archive_name(value: String) -> bool:
	return not value.is_empty() and value == value.to_lower() and value.ends_with(".arc") and ContractValues.is_identifier(value)


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
		"schema": ContentCoreVersionScript.CONTENT_SELECTION_SCHEMA,
		"error": message,
	}
