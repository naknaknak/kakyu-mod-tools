extends "res://tests/test_case.gd"

const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const ArcWriterScript := preload("res://content_core/arc_writer.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://arc_provenance_test"


func _ready() -> void:
	_cleanup()
	var root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(root)
	var source_path := root.path_join("voice.arc")
	var wrong_source_path := root.path_join("wrong.arc")
	var replacement_path := root.path_join("replacement.bin")
	SyntheticArc.write_arc(source_path, [
		{"name": "B.WAV", "data": PackedByteArray([1, 2, 3, 4])},
		{"name": "A.WAV", "data": PackedByteArray([5, 6, 7])},
	])
	SyntheticArc.write_arc(wrong_source_path, [
		{"name": "B.WAV", "data": PackedByteArray([9, 9, 9, 9])},
		{"name": "A.WAV", "data": PackedByteArray([8, 8, 8])},
	])
	_write_bytes(replacement_path, PackedByteArray([10, 11, 12, 13, 14]))
	var source_sha := FileAccess.get_sha256(source_path)
	var source_bytes := FileAccess.get_file_as_bytes(source_path)
	var replacement_sha := FileAccess.get_sha256(replacement_path)
	var output_path := root.path_join("voice-derived.arc")
	var service := ArcProvenanceScript.new()
	var materialized := service.materialize_repacked_copy_from_bound_files(
		source_path,
		output_path,
		source_sha,
		{"A.WAV": {"path": replacement_path, "sha256": replacement_sha}},
		"original_engine_unverified"
	)
	_check(materialized.get("ok", false), "provenance service materializes a source-bound and payload-bound ARC copy")
	_check(FileAccess.file_exists(output_path) and FileAccess.file_exists(service.sidecar_path(output_path)), "materialized ARC and provenance sidecar publish together")
	_check(materialized.replacement_count == 1 and materialized.classification == "verified_original_derived", "materialization reopens and verifies its derived classification")
	_check(FileAccess.get_sha256(source_path) == source_sha, "materialization leaves the source ARC byte-identical")

	var loaded := service.load_sidecar(output_path)
	_check(loaded.get("ok", false) and loaded.provenance.schema == "kakyu_materialized_arc_provenance/v1", "provenance sidecar reopens through its strict versioned loader")
	_check(loaded.provenance.source.sha256 == source_sha and loaded.provenance.materialized.sha256 == FileAccess.get_sha256(output_path), "sidecar binds source and materialized ARC snapshots")
	_check(loaded.provenance.replacements.size() == 1 and loaded.provenance.replacements[0].entry == "A.WAV" and loaded.provenance.replacements[0].replacement_sha256 == replacement_sha, "sidecar binds every replacement payload and original entry")
	_check(not _contains_machine_path(loaded.provenance), "portable provenance contains no source, output, or replacement absolute path")

	var source_reader := ArcReaderScript.new()
	var wrong_reader := ArcReaderScript.new()
	_check(source_reader.open(source_path) and wrong_reader.open(wrong_source_path), "classification fixtures open original ARC readers")
	var verified := service.classify(output_path, source_reader, "voice.arc")
	_check(verified.get("ok", false) and verified.classification == "verified_original_derived" and verified.verified and verified.replacement_count == 1, "another app verifies original-derived lineage against the selected original ARC")
	var declared := service.classify(output_path, null, "voice.arc")
	_check(declared.get("ok", false) and declared.classification == "declared_original_derived" and not declared.verified, "sidecar without the original ARC remains declared rather than falsely verified")
	var wrong_original := service.classify(output_path, wrong_reader, "voice.arc")
	_check(wrong_original.get("ok", false) and wrong_original.classification == "unknown_raw" and not wrong_original.verified, "a different original ARC cannot inherit derived lineage")
	var exact := service.classify(source_path, source_reader, "voice.arc")
	_check(exact.get("ok", false) and exact.classification == "exact_original" and exact.verified, "classifier distinguishes the exact selected original ARC")

	var raw_path := root.path_join("unknown.arc")
	_write_bytes(raw_path, FileAccess.get_file_as_bytes(output_path))
	var unknown := service.classify(raw_path, source_reader, "voice.arc")
	_check(unknown.get("ok", false) and unknown.classification == "unknown_raw" and not unknown.verified, "an ARC copy without provenance remains unknown raw input")
	var pristine_output := FileAccess.get_file_as_bytes(output_path)
	var tampered_output := pristine_output.duplicate()
	tampered_output[tampered_output.size() - 1] ^= 0x01
	_write_bytes(output_path, tampered_output)
	var output_tamper := service.classify(output_path, source_reader, "voice.arc")
	_check(output_tamper.get("ok", false) and output_tamper.classification == "unknown_raw", "materialized ARC tampering invalidates its sidecar classification")
	_write_bytes(output_path, pristine_output)
	var sidecar_path := service.sidecar_path(output_path)
	var pristine_sidecar := FileAccess.get_file_as_bytes(sidecar_path)
	var sidecar_document = JSON.parse_string(pristine_sidecar.get_string_from_utf8())
	sidecar_document["unknown_field"] = true
	_write_text(sidecar_path, JSON.stringify(sidecar_document, "  ") + "\n")
	var sidecar_tamper := service.classify(output_path, source_reader, "voice.arc")
	_check(sidecar_tamper.get("ok", false) and sidecar_tamper.classification == "unknown_raw", "unknown or changed provenance metadata fails closed")
	_write_bytes(sidecar_path, pristine_sidecar)
	_check(service.classify(output_path, source_reader, "voice.arc").classification == "verified_original_derived", "restoring exact ARC and sidecar bytes restores verified derived classification")

	var resolver := ContentResolverScript.new()
	_check(
		not resolver.register_materialized_archive("voice.arc", output_path)
		and resolver.last_error.contains("registered original"),
		"resolver refuses a materialized ARC before its authoritative original is registered"
	)
	_check(resolver.register_original_archive("voice.arc", source_path), "resolver registers the authoritative original before a derived layer")
	_check(resolver.register_materialized_archive("voice.arc", output_path), "resolver accepts a fully verified original-derived ARC layer")
	var materialized_snapshot := resolver.get_materialized_snapshot("VOICE.ARC")
	_check(
		materialized_snapshot.classification == "verified_original_derived"
		and materialized_snapshot.source_archive_sha256 == source_sha
		and materialized_snapshot.materialized_archive_sha256 == FileAccess.get_sha256(output_path)
		and materialized_snapshot.replacement_count == 1
		and materialized_snapshot.entries.size() == 2,
		"resolver retains a path-free materialized lineage snapshot for every indexed entry"
	)
	materialized_snapshot.entries.clear()
	_check(resolver.get_materialized_snapshot("voice.arc").entries.size() == 2, "returned materialized snapshots cannot mutate resolver state")
	var derived_changed := resolver.resolve("voice.arc", "A.WAV")
	var derived_unchanged := resolver.resolve("voice.arc", "B.WAV")
	_check(
		derived_changed.ok
		and derived_changed.source == "materialized_arc"
		and derived_changed.sha256 == replacement_sha
		and derived_changed.original_entry_sha256 == source_reader.get_entry_fingerprint("A.WAV")
		and derived_changed.compatibility == "original_engine_unverified",
		"changed materialized entry resolves with exact source, payload, and compatibility bindings"
	)
	_check(
		derived_unchanged.ok
		and derived_unchanged.source == "materialized_arc"
		and derived_unchanged.sha256 == source_reader.get_entry_fingerprint("B.WAV")
		and derived_unchanged.compatibility == "original_engine_compatible",
		"unchanged materialized entry retains exact-original compatibility inside the derived layer"
	)
	_check(resolver.read_resolved(derived_changed) == FileAccess.get_file_as_bytes(replacement_path), "resolver reads changed bytes from the materialized ARC")
	var materialized_extract_path := root.path_join("resolved-materialized.wav")
	var materialized_extract := resolver.extract_resolved(derived_changed, materialized_extract_path)
	_check(
		materialized_extract.ok
		and materialized_extract.sha256 == replacement_sha
		and FileAccess.get_file_as_bytes(materialized_extract_path) == FileAccess.get_file_as_bytes(replacement_path),
		"resolver atomically extracts the hash-bound materialized entry"
	)
	var resolver_overlay_root := root.path_join("resolver_overlay")
	var overlay_bytes := PackedByteArray([21, 22, 23, 24])
	var resolver_overlay := OverlayPackageScript.new().stage_replacement(
		resolver_overlay_root, source_reader, "voice.arc", "A.WAV", overlay_bytes
	)
	_check(resolver_overlay.ok and resolver.configure_overlay(resolver_overlay_root), "resolver configures an overlay above the materialized layer")
	var overlay_resolution := resolver.resolve("voice.arc", "A.WAV")
	_check(overlay_resolution.ok and overlay_resolution.source == "overlay" and resolver.read_resolved(overlay_resolution) == overlay_bytes, "overlay remains higher priority than materialized ARC")
	resolver.clear_overlay()
	_check(resolver.resolve("voice.arc", "A.WAV").source == "materialized_arc", "clearing overlay reveals the verified materialized layer")
	var active_snapshot_before_rejection := resolver.get_materialized_snapshot("voice.arc")
	_check(
		not resolver.register_materialized_archive("voice.arc", wrong_source_path)
		and resolver.get_materialized_snapshot("voice.arc") == active_snapshot_before_rejection
		and resolver.resolve("voice.arc", "A.WAV").source == "materialized_arc",
		"rejected materialized activation preserves the last valid derived layer"
	)
	var resolver_tampered_output := pristine_output.duplicate()
	resolver_tampered_output[resolver_tampered_output.size() - 1] ^= 0x01
	_write_bytes(output_path, resolver_tampered_output)
	var tampered_materialized_extract := root.path_join("tampered-materialized.wav")
	_check(
		not resolver.resolve("voice.arc", "A.WAV").ok
		and resolver.last_error.contains("changed after provenance validation")
		and resolver.read_resolved(derived_changed).is_empty()
		and not resolver.extract_resolved(derived_changed, tampered_materialized_extract).ok
		and not FileAccess.file_exists(tampered_materialized_extract),
		"materialized archive and entry bytes are rechecked after activation"
	)
	_write_bytes(output_path, pristine_output)
	_check(resolver.register_materialized_archive("voice.arc", output_path), "restored materialized bytes must be reopened and revalidated")
	resolver.clear_materialized_archive("voice.arc")
	var original_resolution := resolver.resolve("voice.arc", "A.WAV")
	_check(original_resolution.ok and original_resolution.source == "original_arc", "clearing the materialized layer restores original ARC resolution")
	_check(resolver.register_materialized_archive("voice.arc", output_path), "materialized layer can be reactivated after an explicit clear")
	_check(resolver.register_original_archive("voice.arc", source_path), "re-registering an original ARC succeeds")
	_check(
		resolver.get_materialized_snapshot("voice.arc").is_empty()
		and resolver.resolve("voice.arc", "A.WAV").source == "original_arc",
		"re-registering original evidence invalidates the previous materialized lineage"
	)
	resolver.close()

	var workspace_output := root.path_join("voice-workspace.arc")
	var workspace_snapshot := _workspace_snapshot(source_sha)
	var workspace_materialized := service.materialize_repacked_copy_from_bound_files(
		source_path,
		workspace_output,
		source_sha,
		{"A.WAV": {"path": replacement_path, "sha256": replacement_sha}},
		"mixed",
		workspace_snapshot
	)
	_check(workspace_materialized.get("ok", false) and workspace_materialized.provenance.workspace.project_id == "sample.mod", "materialized provenance carries the portable workspace generation identity")
	var wrong_workspace := workspace_snapshot.duplicate(true)
	wrong_workspace.source_content_set.archives[0].sha256 = _sha("f")
	var rejected_workspace_path := root.path_join("rejected-workspace.arc")
	var rejected_workspace := service.materialize_repacked_copy_from_bound_files(
		source_path,
		rejected_workspace_path,
		source_sha,
		{"A.WAV": {"path": replacement_path, "sha256": replacement_sha}},
		"mixed",
		wrong_workspace
	)
	_check(not rejected_workspace.get("ok", false) and not FileAccess.file_exists(rejected_workspace_path) and not FileAccess.file_exists(service.sidecar_path(rejected_workspace_path)), "workspace lineage mismatch publishes neither ARC nor sidecar")

	var direct_writer_path := root.path_join("direct-writer.arc")
	var direct_writer := ArcWriterScript.new().write_copy_if_source_matches(
		source_path, direct_writer_path, source_sha, {"B.WAV": PackedByteArray([20, 21, 22, 23])}
	)
	_check(direct_writer.get("ok", false) and direct_writer.replacement_bindings.size() == 1 and direct_writer.replacement_bindings[0].replacement_sha256 == OverlayPackageScript.sha256_bytes(PackedByteArray([20, 21, 22, 23])), "ArcWriter reports exact byte-backed replacement bindings for provenance publishers")
	var conflict := service.materialize_repacked_copy_from_bound_files(
		source_path,
		output_path,
		source_sha,
		{"A.WAV": {"path": replacement_path, "sha256": replacement_sha}}
	)
	_check(not conflict.get("ok", false) and FileAccess.get_file_as_bytes(output_path) == pristine_output and FileAccess.get_file_as_bytes(sidecar_path) == pristine_sidecar, "materialization refuses to replace an existing ARC or sidecar")
	_check(_temporary_files(root).is_empty() and _materialize_locks(root).is_empty(), "materialization leaves no ARC, sidecar, or lock temporaries")

	source_reader.close()
	wrong_reader.close()
	_check(FileAccess.get_file_as_bytes(source_path) == source_bytes, "all classification and materialization checks keep source bytes unchanged")
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _workspace_snapshot(source_sha: String) -> Dictionary:
	return {
		"schema": "kakyu_content_workspace_snapshot/v1",
		"generation_sha256": _sha("1"),
		"project_sha256": _sha("2"),
		"manifest_sha256": _sha("3"),
		"project": {
			"project_id": "sample.mod",
			"project_version": "1.0.0",
			"project_revision": 2,
			"compatibility_objective": "mixed",
		},
		"source_content_set": {
			"fingerprint_sha256": _sha("4"),
			"archives": [{"archive": "voice.arc", "sha256": source_sha}],
		},
	}


func _sha(character: String) -> String:
	return character.repeat(64)


func _contains_machine_path(value) -> bool:
	if value is Dictionary:
		for nested in value.values():
			if _contains_machine_path(nested):
				return true
	elif value is Array:
		for nested in value:
			if _contains_machine_path(nested):
				return true
	elif value is String:
		var text: String = value
		return text.contains("user://") or text.contains("AppData") or (text.length() >= 3 and text[1] == ":" and (text[2] == "/" or text[2] == "\\"))
	return false


func _temporary_files(root: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir() and (name.contains(".materialize-") or name.contains(".kakyu-provenance.json.tmp-")):
			result.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	return result


func _materialize_locks(root: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if directory.current_is_dir() and name.ends_with(".materialize.lock"):
			result.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	return result


func _write_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
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
