extends "res://tests/test_case.gd"

## `tools/content_suite/mod_definition_set_import.gd` and its headless CLI
## wrapper (mod event definition unit C, section C): a set file built by
## the Python tool from one synthetic workspace, imported into a second
## synthetic workspace of the same source content set.

const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ModDefinitionBindingScript := preload("res://tools/content_suite/mod_definition_binding.gd")
const ImporterScript := preload("res://tools/content_suite/mod_definition_set_import.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")
const TestHelpers := preload("res://tests/test_helpers.gd")

const TEST_ROOT := "user://mod_definition_set_import_test"


func _ready() -> void:
	_cleanup()
	var source_root := TEST_ROOT + "/ELFIMAGE"
	var destination_root := TEST_ROOT + "/destination_mod"
	var authoring_root := TEST_ROOT + "/authoring_mod"
	var other_mod_root := TEST_ROOT + "/other_mod"

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_root))
	SyntheticArc.write_arc(source_root + "/mes.arc", [{"name": "TEST.MES", "data": PackedByteArray([1, 2, 3])}])
	var source_mes_sha := FileAccess.get_sha256(source_root + "/mes.arc")

	var destination := ContentWorkspaceScript.new()
	_check(destination.create(destination_root, source_root, _project_document("destination.workspace", source_mes_sha)).get("ok", false), "destination workspace is created empty")
	destination.close()

	var authoring := ContentWorkspaceScript.new()
	_check(authoring.create(authoring_root, source_root, _project_document("authoring.workspace", source_mes_sha)).get("ok", false), "authoring workspace is created empty")
	var contract_fp := FileAccess.get_file_as_string("res://config/contracts/mod_event_definition_v1/contract_fingerprint").strip_edges()
	var cells_fp := FileAccess.get_file_as_string("res://config/contracts/state_cells_v1/cells_fingerprint").strip_edges()

	var document_v1 := _load_definition_document(contract_fp, cells_fp, "Hello there.")
	var staged_v1 := authoring.stage_mod_definitions([_document_bytes(document_v1)], ModDefinitionBindingScript.validator())
	_check(staged_v1.get("ok", false) and int(staged_v1.snapshot.definition_count) == 1, "authoring workspace stages the one new_event definition through the real binding validator")

	var set_path_v1 := ProjectSettings.globalize_path(TEST_ROOT + "/set_v1.json")
	var built_v1 := _run_python_build(authoring_root, set_path_v1)
	_check(built_v1.get("ok", false) and FileAccess.file_exists(set_path_v1), "the Python tool builds a definition set from the authoring workspace")

	var first_import := ImporterScript.new().import_set(source_root, destination_root, set_path_v1, false)
	_check(
		first_import.get("ok", false) and int(first_import.added) == 1 and int(first_import.replaced) == 0 and int(first_import.unchanged) == 0,
		"first import stages one added definition"
	)
	var reopened_after_first := ContentWorkspaceScript.new()
	_check(reopened_after_first.open(destination_root, source_root).get("ok", false), "destination workspace reopens after the first import")
	var snapshot_after_first := reopened_after_first.get_snapshot()
	_check(int(snapshot_after_first.definition_count) == 1 and str(snapshot_after_first.mod_id) == "moddefimport", "destination snapshot reflects definition_count 1 and the imported mod_id")
	var manifest_sha_after_first := str(snapshot_after_first.manifest_sha256)
	reopened_after_first.close()

	var second_import := ImporterScript.new().import_set(source_root, destination_root, set_path_v1, false)
	_check(second_import.get("ok", false) and int(second_import.unchanged) == 1 and int(second_import.added) == 0, "a second identical import reports unchanged")

	var document_v2 := _load_definition_document(contract_fp, cells_fp, "Hello there, changed.")
	var staged_v2 := authoring.stage_mod_definitions([_document_bytes(document_v2)], ModDefinitionBindingScript.validator())
	_check(staged_v2.get("ok", false) and int(staged_v2.snapshot.definition_count) == 1, "authoring workspace replaces the one definition with changed content")
	authoring.close()

	var set_path_v2 := ProjectSettings.globalize_path(TEST_ROOT + "/set_v2.json")
	var built_v2 := _run_python_build(authoring_root, set_path_v2)
	_check(built_v2.get("ok", false) and str(built_v2.payload_sha256) != str(built_v1.payload_sha256), "the Python tool builds a second, different set from the changed authoring workspace")

	var refused_replace := ImporterScript.new().import_set(source_root, destination_root, set_path_v2, false)
	_check(not refused_replace.get("ok", false), "importing a changed definition without --replace is refused")
	var reopened_after_refusal := ContentWorkspaceScript.new()
	_check(reopened_after_refusal.open(destination_root, source_root).get("ok", false), "destination workspace reopens after the refused import")
	_check(str(reopened_after_refusal.get_snapshot().manifest_sha256) == manifest_sha_after_first, "the refused import leaves the destination manifest sha unchanged")
	reopened_after_refusal.close()

	var accepted_replace := ImporterScript.new().import_set(source_root, destination_root, set_path_v2, true)
	_check(accepted_replace.get("ok", false) and int(accepted_replace.replaced) == 1 and int(accepted_replace.added) == 0 and int(accepted_replace.unchanged) == 0, "importing the changed definition with --replace reports one replacement")

	var other_mod := ContentWorkspaceScript.new()
	_check(other_mod.create(other_mod_root, source_root, _project_document("other.workspace", source_mes_sha)).get("ok", false), "a second, differently-modded workspace is created empty")
	var other_document := _load_definition_document(contract_fp, cells_fp, "Hello from another mod.", "othermoddef")
	var staged_other := other_mod.stage_mod_definitions([_document_bytes(other_document)], ModDefinitionBindingScript.validator())
	_check(staged_other.get("ok", false), "the other mod's workspace stages its own definition")
	other_mod.close()
	var set_path_other := ProjectSettings.globalize_path(TEST_ROOT + "/set_other.json")
	var built_other := _run_python_build(other_mod_root, set_path_other)
	_check(built_other.get("ok", false), "the Python tool builds a valid set for the other mod")

	var mismatched_mod_import := ImporterScript.new().import_set(source_root, destination_root, set_path_other, true)
	_check(not mismatched_mod_import.get("ok", false), "a set whose mod id differs from the open workspace's is refused")

	var tampered_path := ProjectSettings.globalize_path(TEST_ROOT + "/set_tampered.json")
	var tampered_bytes := FileAccess.get_file_as_bytes(set_path_v1)
	var tampered_json := JSON.new()
	tampered_json.parse(tampered_bytes.get_string_from_utf8())
	var tampered_document: Dictionary = tampered_json.data
	tampered_document.payload_sha256 = "0".repeat(64)
	var tampered_file := FileAccess.open(tampered_path, FileAccess.WRITE)
	tampered_file.store_string(JSON.stringify(tampered_document))
	tampered_file.close()
	var manifest_sha_before_tampered := manifest_sha_after_first
	var tampered_import := ImporterScript.new().import_set(source_root, destination_root, tampered_path, true)
	_check(not tampered_import.get("ok", false), "a tampered set with a changed payload hash is refused")
	var reopened_after_tampered := ContentWorkspaceScript.new()
	_check(reopened_after_tampered.open(destination_root, source_root).get("ok", false), "destination workspace reopens after the refused tampered import")
	_check(str(reopened_after_tampered.get_snapshot().manifest_sha256) != manifest_sha_before_tampered, "the destination manifest advanced only from the earlier accepted replacement, not the tampered attempt")
	reopened_after_tampered.close()

	destination.close()
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _project_document(project_id: String, mes_sha: String) -> Dictionary:
	var archives: Array = [{"archive": "mes.arc", "sha256": mes_sha, "required": true}]
	return {
		"schema": "kakyu_content_project/v1",
		"project_id": project_id,
		"project_version": "0.1.0",
		"display_name": "Mod Definition Set Import Test",
		"project_revision": 1,
		"content_core": {"minimum_version": "0.147.0", "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": preload("res://content_core/content_project.gd").compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc"],
		"compatibility_objective": "mixed",
		"dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []},
		"overlay_manifest": "manifest.json",
	}


func _load_definition_document(contract_fp: String, cells_fp: String, line_text: String, mod_id := "moddefimport") -> Dictionary:
	return TestHelpers.new_event_definition_document(contract_fp, cells_fp, line_text, mod_id)


func _document_bytes(document: Dictionary) -> PackedByteArray:
	return TestHelpers.definition_document_bytes(document)


func _run_python_build(workspace_root: String, out_path: String) -> Dictionary:
	var runtime := preload("res://tools/content_suite/python_runtime.gd").resolve("tools/mod_definition_set.py")
	if not runtime.get("ok", false):
		return {"ok": false, "error": runtime.get("error", "python runtime unavailable")}
	var output: Array = []
	var exit_code := OS.execute(str(runtime.python), PackedStringArray([
		"-B", str(runtime.script), "build",
		ProjectSettings.globalize_path(workspace_root), out_path,
		"--names", ProjectSettings.globalize_path(ModDefinitionBindingScript.DEFAULT_NAMES_DIR),
		"--definitions-dir", ProjectSettings.globalize_path(ModDefinitionBindingScript.DEFAULT_DEFINITIONS_DIR),

	]), output, true, false)
	var joined := ""
	for chunk in output:
		joined += str(chunk)
	var last_line := ""
	for line in joined.split("\n"):
		if not str(line).strip_edges().is_empty():
			last_line = str(line).strip_edges()
	var json := JSON.new()
	if exit_code != 0 or json.parse(last_line) != OK or not json.data is Dictionary:
		return {"ok": false, "error": "python build failed: %s" % joined}
	return json.data


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	if DirAccess.dir_exists_absolute(absolute):
		_remove_tree(absolute)
