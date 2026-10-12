extends RefCounted

## Headless importer for a `kakyu_mod_bundle/v1` file (WD-10): the second front
## door of the staged-import engine in `authored_delta_import.gd`. The bundle
## is validated against the matching original `mes.arc` by
## `tools/mod_bundle.py validate --arc ... --extract` through the shared
## `python_validated_extract.gd`, every extracted member is checked against its
## row hash, and the engine then reconstructs every delta, stages the
## translation-only entries and imports the definition set into **one** fresh
## workspace, reopens it and checks every effective identity before it is
## published. It never merges into an existing workspace (WD-12).
##
## The bundle's declared mod identity is persisted only through its definition
## set: a workspace derives `mod_id` from its definitions, so a bundle without
## one is verified against its header but leaves the imported workspace's
## `mod_id` empty (`mod_persisted` false).

const MAX_BYTES := 64 * 1024 * 1024

const EngineScript := preload("res://tools/content_suite/authored_delta_import.gd")
const ExtractScript := preload("res://tools/content_suite/python_validated_extract.gd")
const ModDefinitionBindingScript := preload("res://tools/content_suite/mod_definition_binding.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ContractValuesScript := preload("res://content_core/contract_values.gd")


## `{ok, schema, bundle_file_sha256, mod_id, mod_revision, mod_persisted,
## delta_count, text_projection_count, definition_count, members: [{entry,
## output_entry_sha256, authored_text_count}], workspace}` or `{ok: false,
## error}`. A translation-only member has an empty `output_entry_sha256`.
func import_bundle(source_root: String, template_workspace: String, bundle_path: String, output_root: String) -> Dictionary:
	var bundle_absolute := ProjectSettings.globalize_path(bundle_path)
	# The size comes first: nothing is read or parsed past the bound.
	var length := _file_length(bundle_absolute)
	if length < 0:
		return _error("Mod bundle file is unavailable.")
	if length > MAX_BYTES:
		return _error("Mod bundle exceeds the bounded import size.")
	var refused := EngineScript.destination_error("Bundle", source_root, output_root)
	if not refused.is_empty():
		return refused
	var source := ProjectSettings.globalize_path(source_root).replace("\\", "/").simplify_path()
	var arguments := PackedStringArray([
		"--arc", source.path_join("mes.arc"),
		"--names", ProjectSettings.globalize_path(ModDefinitionBindingScript.DEFAULT_NAMES_DIR),
		"--definitions-dir", ProjectSettings.globalize_path(ModDefinitionBindingScript.DEFAULT_DEFINITIONS_DIR),
	])
	return ExtractScript.run(
		"tools/mod_bundle.py", "Mod bundle", bundle_path, arguments, "modbundle-extract-",
		func(extracted: Dictionary) -> Dictionary:
			return _import_extracted(source_root, template_workspace, bundle_absolute, output_root, extracted)
	)


func _import_extracted(source_root: String, template_workspace: String, bundle_absolute: String,
		output_root: String, extracted: Dictionary) -> Dictionary:
	var extract_root := str(extracted.extract_root)
	# The bytes parsed are the bytes Python validated.
	var file := FileAccess.open(bundle_absolute, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return _error("Mod bundle file changed during validation.")
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if OverlayPackageScript.sha256_bytes(bytes) != str(extracted.file_sha256):
		return _error("Mod bundle file changed during validation.")
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return _error("Mod bundle file is not a valid JSON object.")
	var document: Dictionary = parsed
	var mod: Dictionary = document.mod
	var mod_id := str(mod.id)
	var mod_revision := int(mod.revision)

	var delta_plans: Array = []
	for untyped_row in document.deltas:
		var row: Dictionary = untyped_row
		var entry := str(row.entry)
		if entry != entry.get_file():
			return _error("Mod bundle delta names an unsafe entry.")
		var extracted_path := extract_root.path_join("deltas").path_join(entry + ".json")
		var delta_bytes := FileAccess.get_file_as_bytes(extracted_path)
		if delta_bytes.is_empty() or OverlayPackageScript.sha256_bytes(delta_bytes) != str(row.delta_sha256):
			return _error("Extracted mod bundle delta bytes do not match the bundle: %s" % entry)
		delta_plans.append({"file": extracted_path, "bundle_dir": "authoring/delta-" + entry})
	var text_rows: Array = []
	for untyped_row in document.text_projections:
		var row: Dictionary = untyped_row
		text_rows.append({"entry": str(row.entry), "source_entry_sha256": str(row.source_entry_sha256),
			"edits": ContractValuesScript.intify(row.text_edits)})

	var expect := {"archive_sha256": str(document.source.archive_sha256)}
	var set_file := ""
	var definition_count := 0
	if document.definition_set is Dictionary:
		var set_row: Dictionary = document.definition_set
		set_file = extract_root.path_join("definition_set.json")
		var set_bytes := FileAccess.get_file_as_bytes(set_file)
		if set_bytes.is_empty() or OverlayPackageScript.sha256_bytes(set_bytes) != str(set_row.set_sha256):
			return _error("Extracted mod bundle definition set bytes do not match the bundle.")
		definition_count = int(set_row.definition_count)
		var definition_hashes := {}
		for untyped_definition in set_row.document.definitions:
			var definition: Dictionary = untyped_definition
			definition_hashes[str(definition.definition_id)] = str(definition.definition_sha256)
		expect["mod_id"] = mod_id
		expect["definition_count"] = definition_count
		expect["definition_hashes"] = definition_hashes

	var plan := {
		"kind": "Bundle", "suffix": ".bundle", "name_members": true,
		"deltas": delta_plans, "text_rows": text_rows, "set_file": set_file, "expect": expect,
	}
	var imported := EngineScript.new().import_members(source_root, template_workspace, plan, output_root)
	if not imported.get("ok", false):
		return imported
	var members: Array = []
	for untyped_member in imported.deltas:
		var member: Dictionary = untyped_member
		members.append({"entry": str(member.entry), "output_entry_sha256": str(member.output_entry_sha256),
			"authored_text_count": int(member.authored_text_count)})
	for untyped_member in imported.text_rows:
		var member: Dictionary = untyped_member
		members.append({"entry": str(member.entry), "output_entry_sha256": "",
			"authored_text_count": int(member.authored_text_count)})
	members.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.entry) < str(right.entry))
	return {
		"ok": true, "schema": str(document.schema), "bundle_file_sha256": str(extracted.file_sha256),
		"mod_id": mod_id, "mod_revision": mod_revision, "mod_persisted": not set_file.is_empty(),
		"delta_count": delta_plans.size(), "text_projection_count": text_rows.size(),
		"definition_count": definition_count, "members": members, "workspace": str(imported.workspace),
	}


## The file's length without reading it, or -1 when it cannot be opened.
static func _file_length(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var length := file.get_length()
	file.close()
	return length


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
