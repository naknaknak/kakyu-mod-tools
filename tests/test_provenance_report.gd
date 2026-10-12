extends "res://tests/test_case.gd"

const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ProvenanceReportScript := preload("res://tools/content_suite/provenance_report.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://provenance_report_test"


func _ready() -> void:
	_cleanup()
	var source_root := TEST_ROOT + "/ELFIMAGE"
	var workspace_root := TEST_ROOT + "/my_mod"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_root))
	var synthetic_mes := _synthetic_mes()
	SyntheticArc.write_arc(source_root + "/mes.arc", [{"name": "TEST.MES", "data": synthetic_mes}])
	SyntheticArc.write_arc(source_root + "/mmo.arc", [{"name": "ONE.MMO", "data": PackedByteArray([4, 5, 6])}])
	var mes_sha := FileAccess.get_sha256(source_root + "/mes.arc")
	var mmo_sha := FileAccess.get_sha256(source_root + "/mmo.arc")
	var project_document := _project_document(mes_sha, mmo_sha, "mixed")
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(workspace_root, source_root, project_document)
	_check(created.get("ok", false), "provenance report fixture creates a named workspace")

	var replacement_bytes := PackedByteArray([9, 9, 9])
	var staged_replacement := workspace.stage_replacements("mmo.arc", {"ONE.MMO": replacement_bytes}, "remake_only", "not_applicable")
	_check(staged_replacement.get("ok", false), "provenance report fixture stages one replacement")

	var hello_sha := OverlayPackageScript.sha256_bytes("HELLO".to_ascii_buffer())
	var staged_projection := workspace.stage_mes_text_projections(
		"mes.arc", {"TEST.MES": [{"source_offset": 0, "raw_sha256": hello_sha, "text": "번역문"}]}
	)
	_check(staged_projection.get("ok", false), "provenance report fixture stages one MES text projection")

	var snapshot := workspace.get_snapshot()
	var replacement_record := OverlayPackageScript.new().find_replacement(snapshot.manifest, "mmo.arc", "ONE.MMO")
	workspace.close()

	var built := ProvenanceReportScript.build(workspace_root, source_root)
	_check(built.get("ok", false), "provenance report builds from a valid workspace")
	var report: Dictionary = built.get("report", {})

	var expected_top_keys: Array = [
		"schema", "core_version", "project", "workspace", "source_content_set",
		"replacements", "projections", "compatibility", "verification", "payload_sha256",
	]
	var actual_keys := report.keys()
	actual_keys.sort()
	expected_top_keys.sort()
	_check(actual_keys == expected_top_keys, "provenance report top-level keys match the exact contract")
	_check(str(report.get("schema", "")) == ContentCoreVersionScript.CONTENT_PROVENANCE_REPORT_SCHEMA, "provenance report carries its versioned schema")

	_check(
		report.project.project_id == snapshot.project.project_id
		and report.project.project_version == snapshot.project.project_version
		and report.project.display_name == snapshot.project.display_name
		and report.project.project_revision == snapshot.project.project_revision
		and report.project.compatibility_objective == snapshot.project.compatibility_objective
		and report.project.content_core.minimum_version == snapshot.project.content_core.minimum_version
		and report.project.content_core.maximum_exclusive == snapshot.project.content_core.maximum_exclusive
		and report.project.target_archives == snapshot.project.target_archives
		and report.project.dependencies == snapshot.project.dependencies
		and report.project.event_player.catalog_id == snapshot.project.event_player.catalog_id
		and report.project.event_player.preset_count == snapshot.project.event_player.presets.size(),
		"provenance report project block equals the workspace snapshot project"
	)
	_check(
		report.workspace.generation_sha256 == snapshot.generation_sha256
		and report.workspace.project_sha256 == snapshot.project_sha256
		and report.workspace.manifest_sha256 == snapshot.manifest_sha256
		and report.workspace.manifest_editor_version == snapshot.manifest.editor_version,
		"provenance report workspace block equals the workspace snapshot generation"
	)
	_check(
		report.source_content_set.profile_id == snapshot.project.source_content_set.profile_id
		and report.source_content_set.fingerprint_sha256 == snapshot.source_content_set.fingerprint_sha256
		and report.source_content_set.archives.size() == snapshot.source_content_set.archives.size(),
		"provenance report source content set block equals the workspace snapshot source binding"
	)

	_check(report.replacements.size() == 1, "provenance report contains exactly one replacement row")
	var replacement_row: Dictionary = report.replacements[0]
	_check(
		replacement_row.target_archive == "mmo.arc" and replacement_row.target_entry == "ONE.MMO"
		and replacement_row.original_size == 3 and replacement_row.replacement_size == replacement_bytes.size()
		and replacement_row.replacement_sha256 == OverlayPackageScript.sha256_bytes(replacement_bytes)
		and replacement_row.authoring == null,
		"provenance report replacement row carries both sizes, both hashes, and no authoring link"
	)

	_check(report.projections.size() == 1, "provenance report contains exactly one projection row")
	var projection_row: Dictionary = report.projections[0]
	_check(
		projection_row.target_archive == "mes.arc" and projection_row.target_entry == "TEST.MES" and projection_row.edit_count == 1,
		"provenance report projection row carries its edit count"
	)

	_check(report.compatibility.declared == "remake_only", "provenance report declares the single shared compatibility value")
	_check(report.compatibility.consistent_with_objective == true, "provenance report is consistent with a mixed objective")
	_check(report.verification.replacement_blobs == 1 and report.verification.projection_files == 1, "provenance report verification counts every payload")

	var canonical := FingerprintScript.new().canonical_document_json(report)
	var workspace_absolute := ProjectSettings.globalize_path(workspace_root).simplify_path()
	var source_absolute := ProjectSettings.globalize_path(source_root).simplify_path()
	_check(
		not canonical.contains(workspace_absolute) and not canonical.contains(source_absolute) and not canonical.contains("user://"),
		"provenance report canonical JSON excludes every machine-specific path"
	)
	_check(not canonical.contains(synthetic_mes.hex_encode()), "provenance report canonical JSON excludes the original payload bytes' hex")

	var output_path := TEST_ROOT + "/report.json"
	var written := ProvenanceReportScript.write(report, output_path)
	_check(
		written.get("ok", false) and written.sha256 == FileAccess.get_sha256(ProjectSettings.globalize_path(output_path)),
		"provenance report write publishes and rehashes its exact bytes"
	)
	var refused := ProvenanceReportScript.write(report, output_path)
	_check(not refused.get("ok", false), "provenance report write refuses an existing output")

	var reopened := ProvenanceReportScript.read_path(output_path)
	_check(reopened.get("ok", false), "provenance report read_path accepts the published file")

	var tampered_declared: Dictionary = report.duplicate(true)
	tampered_declared.compatibility = tampered_declared.compatibility.duplicate(true)
	tampered_declared.compatibility.declared = "mixed" if str(tampered_declared.compatibility.declared) != "mixed" else "not_applicable"
	_write_json(TEST_ROOT + "/tampered_declared.json", tampered_declared)
	_check(
		not ProvenanceReportScript.read_path(TEST_ROOT + "/tampered_declared.json").get("ok", false),
		"provenance report read_path rejects a tampered declared value"
	)

	var tampered_fingerprint: Dictionary = report.duplicate(true)
	var fingerprint_prefix := str(tampered_fingerprint.payload_sha256).substr(0, 1)
	tampered_fingerprint.payload_sha256 = ("1" if fingerprint_prefix == "0" else "0") + str(report.payload_sha256).substr(1)
	_write_json(TEST_ROOT + "/tampered_fingerprint.json", tampered_fingerprint)
	_check(
		not ProvenanceReportScript.read_path(TEST_ROOT + "/tampered_fingerprint.json").get("ok", false),
		"provenance report read_path rejects a tampered fingerprint"
	)

	var extra_key: Dictionary = report.duplicate(true)
	extra_key["extra_field"] = true
	_write_json(TEST_ROOT + "/extra_key.json", extra_key)
	_check(
		not ProvenanceReportScript.read_path(TEST_ROOT + "/extra_key.json").get("ok", false),
		"provenance report read_path rejects an extra top-level key"
	)

	var wrong_schema: Dictionary = report.duplicate(true)
	wrong_schema.schema = "kakyu_content_provenance_report/v0"
	_write_json(TEST_ROOT + "/wrong_schema.json", wrong_schema)
	_check(
		not ProvenanceReportScript.read_path(TEST_ROOT + "/wrong_schema.json").get("ok", false),
		"provenance report read_path rejects a wrong schema"
	)

	var replacement_blob_path := ProjectSettings.globalize_path(workspace_root).path_join(str(replacement_record.replacement_path))
	var original_blob_bytes := FileAccess.get_file_as_bytes(replacement_blob_path)
	var mutated_blob_bytes := original_blob_bytes.duplicate()
	mutated_blob_bytes[mutated_blob_bytes.size() - 1] ^= 0x01
	_write_bytes(replacement_blob_path, mutated_blob_bytes)
	var mutated_build := ProvenanceReportScript.build(workspace_root, source_root)
	# The mutation is already caught by KakyuContentWorkspace.open()'s own
	# manifest/blob validation (content_core/overlay_package.gd's
	# `_validate_manifest`), which build() forwards verbatim per its step-1
	# open contract; it never reaches this module's own independent
	# replacement-blob re-verification in `_replacement_row()`.
	_check(
		not mutated_build.get("ok", false)
		and str(mutated_build.get("error", "")).contains("replacement")
		and str(mutated_build.get("error", "")).contains("hash mismatch"),
		"provenance report build fails closed when a replacement blob is mutated"
	)
	_write_bytes(replacement_blob_path, original_blob_bytes)
	_check(ProvenanceReportScript.build(workspace_root, source_root).get("ok", false), "provenance report build succeeds again once the replacement blob is restored")

	# A separate workspace whose objective is remake_only carries an
	# original_engine_compatible replacement: declared follows the record,
	# not the objective, and the two must disagree.
	var mismatch_source_root := TEST_ROOT + "/mismatch_source"
	var mismatch_workspace_root := TEST_ROOT + "/mismatch_mod"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(mismatch_source_root))
	SyntheticArc.write_arc(mismatch_source_root + "/mes.arc", [{"name": "TEST.MES", "data": synthetic_mes}])
	var mismatch_mes_sha := FileAccess.get_sha256(mismatch_source_root + "/mes.arc")
	var mismatch_project := _project_document_single(mismatch_mes_sha, "remake_only")
	var mismatch_workspace := ContentWorkspaceScript.new()
	var mismatch_created := mismatch_workspace.create(mismatch_workspace_root, mismatch_source_root, mismatch_project)
	_check(mismatch_created.get("ok", false), "objective-mismatch fixture creates a named workspace")
	var mismatch_staged := mismatch_workspace.stage_replacements(
		"mes.arc", {"TEST.MES": synthetic_mes}, "original_engine_compatible", "cp932"
	)
	_check(mismatch_staged.get("ok", false), "objective-mismatch fixture stages an original-engine-compatible replacement under a remake-only objective")
	mismatch_workspace.close()
	var mismatch_built := ProvenanceReportScript.build(mismatch_workspace_root, mismatch_source_root)
	_check(mismatch_built.get("ok", false), "objective-mismatch provenance report builds")
	_check(
		mismatch_built.report.compatibility.declared == "original_engine_compatible"
		and mismatch_built.report.compatibility.consistent_with_objective == false,
		"provenance report reports the record's compatibility against a disagreeing objective"
	)

	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _project_document(mes_sha: String, mmo_sha: String, objective: String) -> Dictionary:
	var archives: Array = [
		{"archive": "mes.arc", "sha256": mes_sha, "required": true},
		{"archive": "mmo.arc", "sha256": mmo_sha, "required": false},
	]
	return {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"project_id": "provenance.report.test",
		"project_version": "0.1.0",
		"display_name": "Provenance Report Test",
		"project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc", "mmo.arc"],
		"compatibility_objective": objective,
		"dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []},
		"overlay_manifest": "manifest.json",
	}


func _project_document_single(mes_sha: String, objective: String) -> Dictionary:
	var archives: Array = [{"archive": "mes.arc", "sha256": mes_sha, "required": true}]
	return {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"project_id": "provenance.report.mismatch.test",
		"project_version": "0.1.0",
		"display_name": "Provenance Report Mismatch Test",
		"project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc"],
		"compatibility_objective": objective,
		"dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []},
		"overlay_manifest": "manifest.json",
	}


func _synthetic_mes() -> PackedByteArray:
	var code := PackedByteArray()
	code.append(0x01)
	code.append_array("HELLO".to_ascii_buffer())
	code.append(0)
	code.append_array(PackedByteArray([0x0B, 0xF3, 0x34, 0x12, 0xFF]))
	SyntheticArc.append_u32(code, 0)
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(code)
	return mes


func _write_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


func _write_json(path: String, document: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	if DirAccess.dir_exists_absolute(absolute):
		_remove_tree(absolute)


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
