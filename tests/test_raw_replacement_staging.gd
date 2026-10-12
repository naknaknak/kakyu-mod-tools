extends "res://tests/test_case.gd"

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const RawReplacementStagingScript := preload("res://tools/content_suite/raw_replacement_staging.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://raw_replacement_staging_test"


func _ready() -> void:
	_run_check_table()
	_run_stage_tests()
	get_tree().quit(1 if _failed else 0)


func _run_check_table() -> void:
	var original := "original content".to_ascii_buffer()

	var empty_check := RawReplacementStagingScript.check("mes.arc", "X.BIN", original, PackedByteArray())
	_check(
		not empty_check.get("ok", false) and str(empty_check.error) == "Raw replacement is empty.",
		"check rejects an empty replacement"
	)

	var oversize := PackedByteArray()
	oversize.resize(RawReplacementStagingScript.MAX_BYTES + 1)
	oversize.fill(0)
	var oversize_check := RawReplacementStagingScript.check("mes.arc", "X.BIN", original, oversize)
	_check(
		not oversize_check.get("ok", false)
		and str(oversize_check.error) == "Raw replacement exceeds the 64 MiB raw staging limit; use the specialist editor.",
		"check rejects a replacement over the 64 MiB raw staging limit"
	)

	var identical_check := RawReplacementStagingScript.check("mes.arc", "X.BIN", original, original.duplicate())
	_check(
		not identical_check.get("ok", false)
		and str(identical_check.error) == "Replacement is identical to the original entry; nothing to stage.",
		"check rejects a replacement identical to the original entry"
	)

	var valid_mes := PackedByteArray([0, 0, 0, 0, 0xAA])
	var valid_mes_check := RawReplacementStagingScript.check("mes.arc", "X.MES", original, valid_mes)
	_check(
		valid_mes_check.get("ok", false) and str(valid_mes_check.format) == "mes" and bool(valid_mes_check.validated),
		"check accepts a valid MES container for X.MES"
	)

	var invalid_mes := PackedByteArray([1, 2])
	var invalid_mes_check := RawReplacementStagingScript.check("mes.arc", "X.MES", original, invalid_mes)
	_check(
		not invalid_mes_check.get("ok", false)
		and str(invalid_mes_check.error).begins_with("Replacement is not a valid MES entry:"),
		"check rejects an invalid MES container for X.MES"
	)

	var valid_wav := _pcm_wave(9, 8)
	var valid_wav_check := RawReplacementStagingScript.check("se.arc", "X.WAV", original, valid_wav)
	_check(
		valid_wav_check.get("ok", false) and str(valid_wav_check.format) == "audio" and bool(valid_wav_check.validated),
		"check accepts a valid WAV for X.WAV"
	)

	var truncated_wav := valid_wav.slice(0, 10)
	var truncated_wav_check := RawReplacementStagingScript.check("se.arc", "X.WAV", original, truncated_wav)
	_check(
		not truncated_wav_check.get("ok", false)
		and str(truncated_wav_check.error).begins_with("Replacement is not a valid WAV entry:"),
		"check rejects a truncated WAV for X.WAV"
	)

	var valid_ax := _animation_fixture()
	var valid_ax_check := RawReplacementStagingScript.check("data.arc", "X.AX", original, valid_ax)
	_check(
		valid_ax_check.get("ok", false) and str(valid_ax_check.format) == "ax" and bool(valid_ax_check.validated),
		"check accepts a valid AX for X.AX"
	)

	var garbage_ax := PackedByteArray([0xDE, 0xAD, 0xBE, 0xEF, 1, 2, 3, 4, 5, 6, 7, 8])
	var garbage_ax_check := RawReplacementStagingScript.check("data.arc", "X.AX", original, garbage_ax)
	_check(
		not garbage_ax_check.get("ok", false)
		and str(garbage_ax_check.error).begins_with("Replacement is not a valid AX entry:"),
		"check rejects garbage bytes for X.AX"
	)

	var opaque_replacement := "opaque bytes".to_ascii_buffer()
	var opaque_check := RawReplacementStagingScript.check("data.arc", "X.BIN", original, opaque_replacement)
	_check(
		opaque_check.get("ok", false)
		and str(opaque_check.format) == "opaque"
		and not bool(opaque_check.validated)
		and str(opaque_check.note) == "No validator exists for this entry type; the bytes are staged as they are.",
		"check stages an opaque X.BIN unvalidated with its note"
	)


func _run_stage_tests() -> void:
	_cleanup()
	var source_root := TEST_ROOT + "/ELFIMAGE"
	var workspace_root := TEST_ROOT + "/my_mod"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_root))
	SyntheticArc.write_arc(source_root + "/mes.arc", [
		{"name": "TEST.MES", "data": PackedByteArray([1, 2, 3])},
	])
	SyntheticArc.write_arc(source_root + "/mmo.arc", [
		{"name": "ONE.MMO", "data": PackedByteArray([4, 5, 6])},
	])
	var mes_sha := FileAccess.get_sha256(source_root + "/mes.arc")
	var mmo_sha := FileAccess.get_sha256(source_root + "/mmo.arc")
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(workspace_root, source_root, _project_document(mes_sha, mmo_sha))
	_check(created.get("ok", false), "raw staging fixture creates a named workspace targeting mes.arc")
	var first_snapshot := workspace.get_snapshot()
	workspace.close()

	var valid_mes := PackedByteArray([0, 0, 0, 0, 0xAA])
	var replacement_path := ProjectSettings.globalize_path(TEST_ROOT + "/replacement.mes")
	_write_bytes(replacement_path, valid_mes)
	var staged := RawReplacementStagingScript.stage(workspace_root, source_root, "mes.arc", "TEST.MES", replacement_path)
	_check(
		staged.get("ok", false)
		and str(staged.format) == "mes"
		and bool(staged.validated)
		and int(staged.replacement_size) == valid_mes.size()
		and str(staged.replacement_sha256) == OverlayPackageScript.sha256_bytes(valid_mes),
		"stage publishes a valid raw MES replacement"
	)
	var manifest_after_first := OverlayPackageScript.new().load_manifest(workspace_root)
	_check(
		manifest_after_first.get("ok", false)
		and manifest_after_first.manifest.replacements.size() == 1
		and str(manifest_after_first.manifest.replacements[0].compatibility) == "remake_only"
		and str(manifest_after_first.manifest.replacements[0].text_encoding) == "not_applicable"
		and str(manifest_after_first.manifest.replacements[0].replacement_sha256) == OverlayPackageScript.sha256_bytes(valid_mes),
		"stage records one remake_only/not_applicable replacement with the file's hash"
	)
	var reopened_after_first := ContentWorkspaceScript.new()
	reopened_after_first.open(workspace_root, source_root)
	var snapshot_after_first := reopened_after_first.get_snapshot()
	reopened_after_first.close()
	_check(
		snapshot_after_first.generation_sha256 != first_snapshot.generation_sha256
		and str(staged.generation_sha256) == str(snapshot_after_first.generation_sha256),
		"stage changes and returns the workspace snapshot generation"
	)

	var non_target_replacement_path := ProjectSettings.globalize_path(TEST_ROOT + "/non_target.mmo")
	_write_bytes(non_target_replacement_path, PackedByteArray([7, 8, 9]))
	var non_target_staged := RawReplacementStagingScript.stage(workspace_root, source_root, "mmo.arc", "ONE.MMO", non_target_replacement_path)
	var manifest_after_non_target := OverlayPackageScript.new().load_manifest(workspace_root)
	_check(
		not non_target_staged.get("ok", false)
		and manifest_after_non_target.get("ok", false)
		and manifest_after_non_target.manifest.replacements.size() == 1,
		"stage refuses a non-target archive and stages nothing"
	)

	var invalid_mes_path := ProjectSettings.globalize_path(TEST_ROOT + "/invalid.mes")
	_write_bytes(invalid_mes_path, PackedByteArray([1, 2]))
	var invalid_staged := RawReplacementStagingScript.stage(workspace_root, source_root, "mes.arc", "TEST.MES", invalid_mes_path)
	var manifest_after_invalid := OverlayPackageScript.new().load_manifest(workspace_root)
	_check(
		not invalid_staged.get("ok", false)
		and manifest_after_invalid.get("ok", false)
		and manifest_after_invalid.manifest.replacements.size() == 1
		and str(manifest_after_invalid.manifest.replacements[0].replacement_sha256) == OverlayPackageScript.sha256_bytes(valid_mes),
		"stage refuses an invalid MES replacement and stages nothing"
	)

	var second_valid_mes := PackedByteArray([0, 0, 0, 0, 1])
	var second_replacement_path := ProjectSettings.globalize_path(TEST_ROOT + "/replacement2.mes")
	_write_bytes(second_replacement_path, second_valid_mes)
	var second_staged := RawReplacementStagingScript.stage(workspace_root, source_root, "mes.arc", "TEST.MES", second_replacement_path)
	var manifest_after_second := OverlayPackageScript.new().load_manifest(workspace_root)
	_check(
		second_staged.get("ok", false)
		and manifest_after_second.get("ok", false)
		and manifest_after_second.manifest.replacements.size() == 1
		and str(manifest_after_second.manifest.replacements[0].replacement_sha256) == OverlayPackageScript.sha256_bytes(second_valid_mes),
		"staging twice replaces the record and keeps exactly one replacement"
	)
	_cleanup()


func _project_document(mes_sha: String, mmo_sha: String) -> Dictionary:
	var archives: Array = [
		{"archive": "mes.arc", "sha256": mes_sha, "required": true},
		{"archive": "mmo.arc", "sha256": mmo_sha, "required": false},
	]
	return {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"project_id": "raw-replacement-staging.test",
		"project_version": "0.1.0",
		"display_name": "Raw Replacement Staging Test",
		"project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc"],
		"compatibility_objective": "mixed",
		"dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []},
		"overlay_manifest": "manifest.json",
	}


func _pcm_wave(marker: int, sample_bytes: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(44 + sample_bytes)
	data.fill(0)
	SyntheticArc.write_ascii(data, 0, "RIFF")
	data.encode_u32(4, 36 + sample_bytes)
	SyntheticArc.write_ascii(data, 8, "WAVE")
	SyntheticArc.write_ascii(data, 12, "fmt ")
	data.encode_u32(16, 16)
	data.encode_u16(20, 1)
	data.encode_u16(22, 1)
	data.encode_u32(24, 22050)
	data.encode_u32(28, 44100)
	data.encode_u16(32, 2)
	data.encode_u16(34, 16)
	SyntheticArc.write_ascii(data, 36, "data")
	data.encode_u32(40, sample_bytes)
	for index in range(sample_bytes):
		data[44 + index] = marker
	return data


func _animation_fixture() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(0x538)
	data.fill(0)
	_write_record(data, 0x500, 0, 0, 0, 32, 24, 10, 20)
	_write_record(data, 0x51C, 1, 32, 0, 40, 30, 100, 120)
	for index in range(320):
		data.encode_u32(index * 4, data.size())
		if index == 0:
			data.append_array(PackedByteArray([1, 3, 0, 0, 0, 9, 1, 0, 0, 0, 0xFF]))
		elif index == 1:
			data.append_array(PackedByteArray([5, 2, 0, 0, 0, 9, 0, 0, 0, 0, 6, 0xFF]))
		else:
			data.append(0xFF)
	return data


func _write_record(data: PackedByteArray, offset: int, dispatch_type: int, source_x: int, source_y: int, width: int, height: int, destination_x: int, destination_y: int) -> void:
	var values := [dispatch_type, source_x, source_y, width, height, destination_x, destination_y]
	for index in range(values.size()):
		data.encode_u32(offset + index * 4, int(values[index]))


func _write_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
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
