extends RefCounted

## Headless importer for a `kakyu_mod_definition_set/v1` file (mod event
## definition unit C, section C): validates the set through the Python
## tool, extracts each document's canonical bytes, then stages them into
## an already-open workspace's `definitions/` under the workspace's own
## locks and contract check. Locks, staging, no partial publication - the
## same pattern `tools/content_suite/authored_delta_import.gd` uses. The
## validate-and-extract step is the helper both importers share
## (`python_validated_extract.gd`).

const WorkspaceScript := preload("res://content_core/content_workspace.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ModDefinitionBindingScript := preload("res://tools/content_suite/mod_definition_binding.gd")
const PythonValidatedExtractScript := preload("res://tools/content_suite/python_validated_extract.gd")


## Builds a `kakyu_mod_definition_set/v1` file from a workspace's staged
## definitions through `tools/mod_definition_set.py build` (mod event
## definition unit D, section A "Export set..."): runs the tool with the
## tracked names registry and v4 definitions directory, and returns its one
## JSON line - `{ok, schema, mod_id, mod_revision, definition_count,
## payload_sha256}` on success, `{ok: false, error}` otherwise (the tool
## itself refuses an existing output path by its atomic hard-link rule).
static func build_set(workspace_root: String, out_path: String) -> Dictionary:
	var runtime := preload("res://tools/content_suite/python_runtime.gd").resolve("tools/mod_definition_set.py")
	if not runtime.get("ok", false):
		return {"ok": false, "error": str(runtime.get("error", "The Python runtime is unavailable."))}
	var output: Array = []
	var exit_code := OS.execute(str(runtime.python), PackedStringArray([
		"-B", str(runtime.script), "build",
		ProjectSettings.globalize_path(workspace_root), ProjectSettings.globalize_path(out_path),
	]), output, true, false)
	var verdict := PythonValidatedExtractScript.last_json_line(output)
	if verdict.is_empty():
		return {"ok": false, "error": "Definition set build produced no verdict (exit code %d)." % exit_code}
	if exit_code != 0 or not bool(verdict.get("ok", false)):
		return {"ok": false, "error": str(verdict.get("error", "Definition set build failed (exit code %d)." % exit_code))}
	return verdict


func import_set(source_root: String, workspace_root: String, set_path: String, replace: bool) -> Dictionary:
	var arguments := PackedStringArray([
		"--names", ProjectSettings.globalize_path(ModDefinitionBindingScript.DEFAULT_NAMES_DIR),
		"--definitions-dir", ProjectSettings.globalize_path(ModDefinitionBindingScript.DEFAULT_DEFINITIONS_DIR),
	])
	return PythonValidatedExtractScript.run(
		"tools/mod_definition_set.py", "Mod definition set", set_path, arguments, "moddef-set-extract-",
		func(extracted: Dictionary) -> Dictionary:
			return _stage_extracted(source_root, workspace_root, set_path, replace, extracted)
	)


func _stage_extracted(source_root: String, workspace_root: String, set_path: String, replace: bool, extracted: Dictionary) -> Dictionary:
	var set_absolute := ProjectSettings.globalize_path(set_path)
	var extract_root := str(extracted.extract_root)
	var set_sha_before := str(extracted.file_sha256)
	var set_bytes := FileAccess.get_file_as_bytes(set_absolute)
	var json := JSON.new()
	if json.parse(set_bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return _error("Mod definition set file is not a valid JSON object.")
	var set_document: Dictionary = json.data
	var set_mod: Dictionary = set_document.get("mod", {})
	var mod_id := str(set_mod.get("id", ""))
	var mod_revision := int(set_mod.get("revision", 0))
	var rows: Array = set_document.get("definitions", [])

	var workspace := WorkspaceScript.new()
	var opened := workspace.open(workspace_root, source_root)
	if not opened.get("ok", false):
		return opened

	var snapshot := workspace.get_snapshot()
	var existing_mod_id := str(snapshot.get("mod_id", ""))
	if not existing_mod_id.is_empty() and existing_mod_id != mod_id:
		workspace.close()
		return _error("Mod definition set mod id %s does not match the open workspace's mod id %s." % [mod_id, existing_mod_id])

	# A workspace stores the exact bytes it was given (pretty-printed by the
	# editor, canonical from an earlier import), while a set row carries the
	# document's canonical bytes; the two hashes therefore differ after any
	# round trip. "Unchanged" is judged on the parsed documents instead.
	var existing_documents: Dictionary = {}
	var manifest: Dictionary = snapshot.get("manifest", {})
	var overlay_package := OverlayPackageScript.new()
	for untyped_record in manifest.get("definitions", []):
		var record: Dictionary = untyped_record
		var existing_id := str(record.get("definition_id", ""))
		var stored := overlay_package.load_mod_definition(workspace_root, existing_id)
		if not stored.get("ok", false) or not stored.get("found", false):
			workspace.close()
			return _error("Existing mod definition could not be read: %s" % existing_id)
		existing_documents[existing_id] = stored.document

	var staged_bytes: Array[PackedByteArray] = []
	var added := 0
	var replaced := 0
	var unchanged := 0

	for untyped_row in rows:
		var row: Dictionary = untyped_row
		var definition_id := str(row.get("definition_id", ""))
		var expected_sha := str(row.get("definition_sha256", ""))
		var extracted_path := extract_root.path_join(definition_id + ".json")
		var extracted_bytes := FileAccess.get_file_as_bytes(extracted_path)
		if extracted_bytes.is_empty() or OverlayPackageScript.sha256_bytes(extracted_bytes) != expected_sha:
			workspace.close()
			return _error("Extracted mod definition bytes do not match the set: %s" % definition_id)
		if existing_documents.has(definition_id):
			var current_document: Dictionary = existing_documents[definition_id]
			if current_document == row.get("document", {}):
				unchanged += 1
				continue
			if not replace:
				workspace.close()
				return _error("Mod definition %s changed and --replace was not given." % definition_id)
			replaced += 1
		else:
			added += 1
		staged_bytes.append(extracted_bytes)

	var staged: Dictionary = {"ok": true}
	if not staged_bytes.is_empty():
		staged = workspace.stage_mod_definitions(staged_bytes, ModDefinitionBindingScript.validator())
	if not staged.get("ok", false):
		workspace.close()
		return staged

	var refreshed := workspace.refresh()
	workspace.close()
	if not refreshed.get("ok", false):
		return refreshed

	return {
		"ok": true,
		"schema": str(set_document.get("schema", "")),
		"set_file_sha256": set_sha_before,
		"mod_id": mod_id,
		"mod_revision": mod_revision,
		"added": added,
		"replaced": replaced,
		"unchanged": unchanged,
	}


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
