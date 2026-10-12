extends "res://tests/test_case.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const MesUtf8OverlayPlanScript := preload("res://content_core/mes_utf8_overlay_plan.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://content_overlay_test"


func _ready() -> void:
	_cleanup()
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var archive_path := TEST_ROOT + "/voice.arc"
	var mutable_archive_path := TEST_ROOT + "/mutable_voice.arc"
	var other_archive_path := TEST_ROOT + "/other_voice.arc"
	var mes_archive_path := TEST_ROOT + "/mes.arc"
	var overlay_root := TEST_ROOT + "/my_mod"
	var unverified_overlay_root := TEST_ROOT + "/unverified_mes_mod"
	var fallback_path := TEST_ROOT + "/fallback.bin"
	var fallback_data := "fallback".to_ascii_buffer()
	var original_voice := _ogg_bytes(1)
	var original_other := "original-other".to_ascii_buffer()
	SyntheticArc.write_arc(archive_path, [
		{"name": "D0044.OGG", "data": original_voice},
		{"name": "D0045.OGG", "data": _ogg_bytes(5)},
		{"name": "OTHER.BIN", "data": original_other},
	])
	SyntheticArc.write_arc(other_archive_path, [
		{"name": "D0044.OGG", "data": _ogg_bytes(2)},
	])
	var synthetic_mes := _synthetic_mes()
	SyntheticArc.write_arc(mes_archive_path, [
		{"name": "TEST.MES", "data": synthetic_mes},
		{"name": "OTHER.MES", "data": synthetic_mes},
		{"name": "INVALID.MES", "data": _synthetic_invalid_cp932_mes()},
	])
	_write_bytes(fallback_path, fallback_data)

	var reader := ArcReaderScript.new()
	_check(reader.open(archive_path), "source ARC opens for overlay staging")
	var overlay_package := OverlayPackageScript.new()
	var first_replacement := _ogg_bytes(7)
	var staged := overlay_package.stage_replacement(
		overlay_root, reader, "voice.arc", "D0044.OGG", first_replacement
	)
	_check(staged.ok, "overlay replacement and manifest are staged")
	_check(FileAccess.file_exists(staged.manifest_path), "overlay manifest is published")
	_check(FileAccess.file_exists(staged.replacement_path), "content-addressed replacement is published")

	var second_replacement := _ogg_bytes(9)
	var updated := overlay_package.stage_replacement(
		overlay_root, reader, "voice.arc", "D0044.OGG", second_replacement
	)
	_check(updated.ok, "existing overlay target updates atomically")
	var loaded := overlay_package.load_manifest(overlay_root)
	_check(loaded.ok and str(loaded.sha256).length() == 64, "published overlay validates and exposes its exact manifest revision")
	_check(loaded.manifest.replacements.size() == 1, "overlay update keeps one target record")
	_check(loaded.manifest.replacements[0].replacement_sha256 == OverlayPackageScript.sha256_bytes(second_replacement), "manifest selects updated replacement hash")
	var stale_manifest: Dictionary = loaded.manifest.duplicate(true)
	var stale_manifest_sha := str(loaded.sha256)
	var manifest_sha_before_rejected_batch := FileAccess.get_sha256(updated.manifest_path)
	var rejected_batch := overlay_package.stage_replacements(
		overlay_root,
		reader,
		"voice.arc",
		{"D0044.OGG": _ogg_bytes(10), "MISSING.OGG": _ogg_bytes(10)}
	)
	_check(not rejected_batch.ok, "invalid overlay batch is rejected before publication")
	_check(FileAccess.get_sha256(updated.manifest_path) == manifest_sha_before_rejected_batch, "rejected overlay batch leaves manifest byte-identical")

	var batch_first := _ogg_bytes(11)
	var batch_second := _ogg_bytes(12)
	var batch := overlay_package.stage_replacements(
		overlay_root,
		reader,
		"voice.arc",
		{"D0044.OGG": batch_first, "D0045.OGG": batch_second}
	)
	_check(batch.ok, "two-entry overlay batch publishes with one manifest update")
	_check(batch.records.size() == 2 and batch.replacement_paths.size() == 2, "overlay batch reports every published payload")
	loaded = overlay_package.load_manifest(overlay_root)
	_check(loaded.ok and loaded.manifest.replacements.size() == 2, "overlay batch manifest contains both unique targets")
	var current_manifest_sha := str(loaded.sha256)
	var active_manifest_path := ProjectSettings.globalize_path(overlay_root).simplify_path().path_join("manifest.json")
	var stale_publish := overlay_package._write_manifest_atomic(active_manifest_path, stale_manifest, true, stale_manifest_sha)
	_check(
		not stale_publish.ok
		and str(stale_publish.error).contains("changed before publication")
		and FileAccess.get_sha256(active_manifest_path) == current_manifest_sha,
		"overlay manifest compare-and-swap rejects a stale loaded revision without replacing the current manifest"
	)
	_check(_sibling_temp_files(active_manifest_path).is_empty(), "stale overlay manifest publication removes its sibling temporary file")
	var late_root := absolute_root.path_join("late_manifest")
	DirAccess.make_dir_recursive_absolute(late_root)
	var late_manifest_path := late_root.path_join("manifest.json")
	var competing_manifest_bytes := "competing publisher".to_utf8_buffer()
	_write_bytes(late_manifest_path, competing_manifest_bytes)
	var late_publish := overlay_package._write_manifest_atomic(late_manifest_path, stale_manifest, false, "")
	_check(
		not late_publish.ok
		and str(late_publish.error).contains("changed before publication")
		and FileAccess.get_file_as_bytes(late_manifest_path) == competing_manifest_bytes,
		"overlay manifest publication preserves a destination that appears after an absent snapshot"
	)
	_check(_sibling_temp_files(late_manifest_path).is_empty(), "late overlay manifest conflict removes its sibling temporary file")

	var payload_publish_root := absolute_root.path_join("payload_publish")
	DirAccess.make_dir_recursive_absolute(payload_publish_root)
	var payload_bytes := "content-addressed payload".to_utf8_buffer()
	var payload_sha := OverlayPackageScript.sha256_bytes(payload_bytes)
	var new_payload_path := payload_publish_root.path_join("new.bin")
	var new_payload_temp := new_payload_path + ".tmp-manual"
	_write_bytes(new_payload_temp, payload_bytes)
	var new_payload_publish := overlay_package._publish_content_addressed_temp(new_payload_temp, new_payload_path, payload_sha)
	_check(
		new_payload_publish.ok
		and not bool(new_payload_publish.reused)
		and FileAccess.get_file_as_bytes(new_payload_path) == payload_bytes
		and not FileAccess.file_exists(new_payload_temp),
		"content-addressed payload publication atomically publishes and reopens a new destination"
	)
	var reused_payload_path := payload_publish_root.path_join("reused.bin")
	var reused_payload_temp := reused_payload_path + ".tmp-manual"
	_write_bytes(reused_payload_path, payload_bytes)
	_write_bytes(reused_payload_temp, payload_bytes)
	var reused_payload_publish := overlay_package._publish_content_addressed_temp(reused_payload_temp, reused_payload_path, payload_sha)
	_check(
		reused_payload_publish.ok
		and bool(reused_payload_publish.reused)
		and FileAccess.get_file_as_bytes(reused_payload_path) == payload_bytes
		and not FileAccess.file_exists(reused_payload_temp),
		"content-addressed payload publication reuses an identical destination created by another publisher"
	)
	var conflicting_payload_path := payload_publish_root.path_join("conflict.bin")
	var conflicting_payload_temp := conflicting_payload_path + ".tmp-manual"
	var competing_payload_bytes := "different publisher".to_utf8_buffer()
	_write_bytes(conflicting_payload_path, competing_payload_bytes)
	_write_bytes(conflicting_payload_temp, payload_bytes)
	var conflicting_payload_publish := overlay_package._publish_content_addressed_temp(
		conflicting_payload_temp, conflicting_payload_path, payload_sha
	)
	_check(
		not conflicting_payload_publish.ok
		and str(conflicting_payload_publish.error).contains("different bytes")
		and FileAccess.get_file_as_bytes(conflicting_payload_path) == competing_payload_bytes
		and not FileAccess.file_exists(conflicting_payload_temp),
		"content-addressed payload publication rejects and preserves a conflicting destination"
	)
	_check(_sibling_temp_files(new_payload_path).is_empty(), "payload publication tests leave no sibling temporary files")

	var mes_reader := ArcReaderScript.new()
	_check(mes_reader.open(mes_archive_path), "MES source ARC opens for text projection staging")
	var unverified_replacement := overlay_package.stage_replacement(
		unverified_overlay_root,
		mes_reader,
		"mes.arc",
		"TEST.MES",
		synthetic_mes,
		"original_engine_unverified",
		"cp932"
	)
	var unverified_manifest := overlay_package.load_manifest(unverified_overlay_root)
	_check(
		unverified_replacement.ok
		and unverified_manifest.ok
		and unverified_manifest.manifest.replacements[0].compatibility == "original_engine_unverified",
		"overlay manifest retains a structurally valid but original-engine-unverified MES candidate"
	)
	var hello_sha := OverlayPackageScript.sha256_bytes("HELLO".to_ascii_buffer())
	var text_projection := overlay_package.stage_mes_text_projection(
		overlay_root,
		mes_reader,
		"mes.arc",
		"TEST.MES",
		[{"source_offset": 0, "raw_sha256": hello_sha, "text": "편집된 대사"}]
	)
	_check(text_projection.ok, "hash-bound UTF-8 MES text projection is staged")
	loaded = overlay_package.load_manifest(overlay_root)
	_check(loaded.ok and loaded.manifest.replacements.size() == 2 and loaded.manifest.projections.size() == 1, "MES projection coexists with binary replacements")
	var projection_record := overlay_package.find_mes_text_projection(loaded.manifest, "MES.ARC", "test.mes")
	_check(not projection_record.is_empty() and projection_record.compatibility == "remake_only" and projection_record.text_encoding == "utf8", "MES projection lookup retains explicit compatibility")
	var projection_document = JSON.parse_string(FileAccess.get_file_as_string(text_projection.projection_path))
	_check(projection_document is Dictionary and projection_document.schema == ContentCoreVersionScript.MES_TEXT_OVERLAY_ENTRY_SCHEMA, "MES projection payload uses its versioned schema")
	_check(projection_document.edits[0].text == "편집된 대사" and projection_document.edits[0].raw_sha256 == hello_sha, "MES projection payload retains UTF-8 text and original message binding")
	var loaded_projection := overlay_package.load_mes_text_projection(
		overlay_root,
		"mes.arc",
		"TEST.MES",
		mes_reader.get_archive_fingerprint(),
		mes_reader.get_entry_fingerprint("TEST.MES")
	)
	_check(loaded_projection.ok and loaded_projection.found and loaded_projection.messages[0].text == "편집된 대사", "MES projection loader returns offset-indexed UTF-8 edits")
	var utf8_plan := _utf8_overlay_plan(
		mes_reader.get_archive_fingerprint(),
		mes_reader.get_entry_fingerprint("TEST.MES"),
		hello_sha
	)
	var planned_projection := overlay_package.stage_mes_utf8_overlay_plan(
		overlay_root, mes_reader, utf8_plan
	)
	_check(planned_projection.ok, "Phase 6 UTF-8 overlay plan stages through the remake-only projection writer")
	var planned_loaded := overlay_package.load_mes_text_projection(
		overlay_root,
		"mes.arc",
		"TEST.MES",
		mes_reader.get_archive_fingerprint(),
		mes_reader.get_entry_fingerprint("TEST.MES")
	)
	_check(
		planned_loaded.ok
		and planned_loaded.messages[0].text == "계획된 UTF-8 😀",
		"planned UTF-8 overlay reopens without assembling MES bytes"
	)
	var missing_projection := overlay_package.load_mes_text_projection(
		overlay_root,
		"mes.arc",
		"MISSING.MES",
		mes_reader.get_archive_fingerprint(),
		mes_reader.get_entry_fingerprint("TEST.MES")
	)
	_check(missing_projection.ok and not missing_projection.found and missing_projection.messages.is_empty(), "MES projection loader reports an absent target without inventing content")
	var stale_projection := overlay_package.load_mes_text_projection(
		overlay_root,
		"mes.arc",
		"TEST.MES",
		"0".repeat(64),
		mes_reader.get_entry_fingerprint("TEST.MES")
	)
	_check(not stale_projection.ok and str(stale_projection.error).contains("base ARC"), "MES projection loader rejects a different base ARC binding")
	var projection_manifest_sha := FileAccess.get_sha256(text_projection.manifest_path)
	var rejected_projection := overlay_package.stage_mes_text_projection(
		overlay_root,
		mes_reader,
		"mes.arc",
		"TEST.MES",
		[{"source_offset": 0, "raw_sha256": "0".repeat(64), "text": "stale"}]
	)
	_check(not rejected_projection.ok and str(rejected_projection.error).contains("does not match"), "MES projection rejects a stale raw message hash")
	_check(FileAccess.get_sha256(text_projection.manifest_path) == projection_manifest_sha, "rejected MES projection leaves the manifest byte-identical")
	var invalid_pair_sha := OverlayPackageScript.sha256_bytes(PackedByteArray([0x8F, 0x01]))
	var rejected_native_pair := overlay_package.stage_mes_text_projection(
		overlay_root,
		mes_reader,
		"mes.arc",
		"INVALID.MES",
		[{"source_offset": 0, "raw_sha256": invalid_pair_sha, "text": "invented dialogue"}]
	)
	_check(not rejected_native_pair.ok and str(rejected_native_pair.error).contains("not valid CP932 dialogue"), "MES projection writer rejects native presentation bytes as authored dialogue")
	_check(FileAccess.get_sha256(text_projection.manifest_path) == projection_manifest_sha, "invalid native-pair projection leaves the manifest byte-identical")
	var projection_directory := ProjectSettings.globalize_path(overlay_root).path_join("projections/mes")
	var projection_file_count := DirAccess.get_files_at(projection_directory).size()
	var rejected_projection_batch := overlay_package.stage_mes_text_projections(
		overlay_root,
		mes_reader,
		"mes.arc",
		{
			"TEST.MES": [{"source_offset": 0, "raw_sha256": hello_sha, "text": "batch one"}],
			"OTHER.MES": [{"source_offset": 0, "raw_sha256": "0".repeat(64), "text": "stale batch"}],
		}
	)
	_check(not rejected_projection_batch.ok, "MES projection batch rejects every target when one entry is stale")
	_check(FileAccess.get_sha256(text_projection.manifest_path) == projection_manifest_sha, "rejected MES projection batch leaves the manifest byte-identical")
	_check(DirAccess.get_files_at(projection_directory).size() == projection_file_count, "rejected MES projection batch creates no payload files")
	var projection_batch := overlay_package.stage_mes_text_projections(
		overlay_root,
		mes_reader,
		"mes.arc",
		{
			"TEST.MES": [{"source_offset": 0, "raw_sha256": hello_sha, "text": "batch one"}],
			"OTHER.MES": [{"source_offset": 0, "raw_sha256": hello_sha, "text": "batch two"}],
		}
	)
	_check(projection_batch.ok and projection_batch.records.size() == 2 and projection_batch.projection_paths.size() == 2, "two-entry MES projection batch publishes every payload")
	loaded = overlay_package.load_manifest(overlay_root)
	_check(loaded.ok and loaded.manifest.projections.size() == 2, "MES projection batch publishes one manifest containing both targets")
	var loaded_other_projection := overlay_package.load_mes_text_projection(
		overlay_root,
		"mes.arc",
		"OTHER.MES",
		mes_reader.get_archive_fingerprint(),
		mes_reader.get_entry_fingerprint("OTHER.MES")
	)
	_check(loaded_other_projection.ok and loaded_other_projection.messages[0].text == "batch two", "second batched MES projection reopens with its bound text")
	var removed_projection := overlay_package.remove_mes_text_projection(overlay_root, "mes.arc", "OTHER.MES")
	_check(removed_projection.ok and removed_projection.removed, "MES text projection target is removed from the overlay manifest")
	_check(FileAccess.file_exists(removed_projection.unreferenced_projection_path), "projection removal preserves the unreferenced content-addressed payload")
	loaded = overlay_package.load_manifest(overlay_root)
	_check(loaded.ok and loaded.manifest.projections.size() == 1 and overlay_package.find_mes_text_projection(loaded.manifest, "mes.arc", "OTHER.MES").is_empty(), "projection removal keeps other manifest targets valid")
	var manifest_sha_after_removal := FileAccess.get_sha256(removed_projection.manifest_path)
	var missing_removal := overlay_package.remove_mes_text_projection(overlay_root, "mes.arc", "OTHER.MES")
	_check(missing_removal.ok and not missing_removal.removed, "removing an absent MES text projection is idempotent")
	_check(FileAccess.get_sha256(removed_projection.manifest_path) == manifest_sha_after_removal, "idempotent projection removal leaves the manifest byte-identical")
	var other_archive_replacement := overlay_package.stage_replacement(
		overlay_root,
		mes_reader,
		"mes.arc",
		"OTHER.MES",
		synthetic_mes,
		"remake_only",
		"cp932"
	)
	_check(other_archive_replacement.ok, "batch-binding fixture publishes an unrelated archive replacement")
	mes_reader.close()

	var resolver := ContentResolverScript.new()
	_check(resolver.register_original_archive("voice.arc", archive_path), "resolver registers original ARC")
	_check(resolver.register_original_archive("other_voice.arc", other_archive_path), "resolver registers an archive with no overlay targets")
	_check(resolver.configure_overlay(overlay_root), "resolver accepts validated overlay")
	var resolver_snapshot := resolver.get_overlay_snapshot()
	_check(
		not resolver_snapshot.is_empty()
		and str(resolver_snapshot.root) == ProjectSettings.globalize_path(overlay_root).simplify_path()
		and resolver_snapshot.manifest.replacements.size() == 3,
		"resolver exposes its single validated overlay snapshot for bound tool metadata"
	)
	resolver_snapshot.manifest.replacements.clear()
	_check(
		resolver.get_overlay_snapshot().manifest.replacements.size() == 3,
		"resolver overlay snapshots are deep copies that cannot mutate active resolution"
	)
	var batch_bindings: Dictionary = resolver.validate_overlay_archive_bindings("voice.arc")
	var batch_descriptor: Dictionary = batch_bindings.get("descriptors", {}).get("D0044.OGG", {})
	_check(
		batch_bindings.ok
		and str(batch_bindings.root) == ProjectSettings.globalize_path(overlay_root).simplify_path()
		and str(batch_bindings.archive).to_upper() == "VOICE.ARC"
		and str(batch_bindings.archive_sha256) == reader.get_archive_fingerprint()
		and batch_bindings.records.size() == 2
		and batch_bindings.descriptors.size() == 2
		and not batch_bindings.descriptors.has("OTHER.MES"),
		"resolver batch-validates only the requested archive against one retained overlay snapshot"
	)
	_check(
		batch_descriptor.ok
		and str(batch_descriptor.source) == "overlay"
		and str(batch_descriptor.path).simplify_path() == ProjectSettings.globalize_path(str(batch.replacement_paths["D0044.OGG"])).simplify_path()
		and str(batch_descriptor.sha256) == OverlayPackageScript.sha256_bytes(batch_first)
		and str(batch_descriptor.archive).to_upper() == "VOICE.ARC"
		and str(batch_descriptor.entry).to_upper() == "D0044.OGG",
		"batch descriptor matches the canonical overlay resolution contract"
	)
	_check(
		str(batch_descriptor.compatibility) == "remake_only"
		and str(batch_descriptor.base_archive_sha256) == reader.get_archive_fingerprint()
		and str(batch_descriptor.original_entry_sha256) == reader.get_entry_fingerprint("D0044.OGG"),
		"resolved overlay descriptors retain compatibility and original evidence bindings"
	)
	var empty_archive_bindings: Dictionary = resolver.validate_overlay_archive_bindings("other_voice.arc")
	_check(
		empty_archive_bindings.ok
		and str(empty_archive_bindings.archive).to_upper() == "OTHER_VOICE.ARC"
		and str(empty_archive_bindings.archive_sha256) == FileAccess.get_sha256(other_archive_path)
		and empty_archive_bindings.records.is_empty()
		and empty_archive_bindings.descriptors.is_empty(),
		"batch binding succeeds with an explicit empty result for a registered archive with no targets"
	)
	batch_bindings.records[0]["target_entry"] = "MUTATED.OGG"
	batch_bindings.descriptors.clear()
	var resolved_after_return_mutation: Dictionary = resolver.resolve("voice.arc", "D0044.OGG")
	_check(
		resolved_after_return_mutation.ok
		and str(resolved_after_return_mutation.entry).to_upper() == "D0044.OGG"
		and str(resolved_after_return_mutation.sha256) == OverlayPackageScript.sha256_bytes(batch_first)
		and resolver.get_overlay_snapshot().manifest.replacements.size() == 3,
		"mutating a returned batch cannot alter normal resolution or the retained manifest"
	)
	var repeated_bindings: Dictionary = resolver.validate_overlay_archive_bindings("VOICE.ARC")
	_check(
		repeated_bindings.ok
		and repeated_bindings.records.size() == 2
		and repeated_bindings.descriptors.size() == 2
		and not repeated_bindings.descriptors.has("MUTATED.OGG")
		and str(repeated_bindings.records[0].target_entry).to_upper() != "MUTATED.OGG"
		and resolver.get_overlay_snapshot().manifest.replacements.size() == 3,
		"batch-binding results are deep copies that cannot mutate resolver state"
	)
	var batch_resolved: Dictionary = resolver.resolve("voice.arc", "D0044.OGG")
	var repeated_descriptor: Dictionary = repeated_bindings.descriptors["D0044.OGG"]
	_check(
		batch_resolved.ok
		and str(batch_resolved.source) == str(repeated_descriptor.source)
		and str(batch_resolved.path).simplify_path() == str(repeated_descriptor.path).simplify_path()
		and str(batch_resolved.sha256) == str(repeated_descriptor.sha256)
		and str(batch_resolved.archive).to_upper() == str(repeated_descriptor.archive).to_upper()
		and str(batch_resolved.entry).to_upper() == str(repeated_descriptor.entry).to_upper(),
		"normal resolve matches the independently validated batch descriptor"
	)
	var overlay_result := resolver.resolve("voice.arc", "D0044.OGG")
	_check(overlay_result.ok and overlay_result.source == "overlay", "overlay wins resolution priority")
	_check(resolver.read_resolved(overlay_result) == batch_first, "first batch overlay bytes resolve")
	var overlay_extract_path := TEST_ROOT + "/resolved-overlay.ogg"
	var overlay_extract := resolver.extract_resolved(overlay_result, overlay_extract_path, 3)
	_check(
		overlay_extract.ok
		and str(overlay_extract.sha256) == OverlayPackageScript.sha256_bytes(batch_first)
		and FileAccess.get_file_as_bytes(overlay_extract_path) == batch_first,
		"resolver atomically publishes reopened hash-verified overlay bytes"
	)
	_check(_sibling_temp_files(overlay_extract_path).is_empty(), "successful overlay extraction leaves no sibling temporary file")
	var preserved_overlay_extract := FileAccess.get_file_as_bytes(overlay_extract_path)
	_check(
		not resolver.extract_resolved(overlay_result, overlay_extract_path).ok
		and FileAccess.get_file_as_bytes(overlay_extract_path) == preserved_overlay_extract,
		"resolver refuses and preserves an existing extracted output"
	)
	_check(_sibling_temp_files(overlay_extract_path).is_empty(), "refused overlay extraction leaves no sibling temporary file")
	var second_overlay_result := resolver.resolve("voice.arc", "D0045.OGG")
	_check(second_overlay_result.ok and resolver.read_resolved(second_overlay_result) == batch_second, "second batch overlay bytes resolve")
	var original_result := resolver.resolve("voice.arc", "OTHER.BIN")
	_check(original_result.ok and original_result.source == "original_arc", "original ARC is second priority")
	_check(resolver.read_resolved(original_result) == original_other, "original ARC bytes resolve")
	var original_extract_path := TEST_ROOT + "/resolved-original.bin"
	var original_extract := resolver.extract_resolved(original_result, original_extract_path)
	_check(
		original_extract.ok
		and str(original_extract.sha256) == OverlayPackageScript.sha256_bytes(original_other)
		and FileAccess.get_file_as_bytes(original_extract_path) == original_other,
		"resolver delegates atomic hash-verified original ARC extraction to its streaming reader"
	)
	_check(_sibling_temp_files(original_extract_path).is_empty(), "successful original ARC extraction leaves no sibling temporary file")
	var fallback_result := resolver.resolve("voice.arc", "MISSING.BIN", fallback_path)
	var fallback_sha := OverlayPackageScript.sha256_bytes(fallback_data)
	_check(
		fallback_result.ok
		and fallback_result.source == "fallback"
		and int(fallback_result.size) == fallback_data.size()
		and str(fallback_result.sha256) == fallback_sha,
		"fallback is third priority and binds its resolved size and hash"
	)
	_check(resolver.read_resolved(fallback_result) == fallback_data, "hash-bound fallback bytes resolve")
	var fallback_extract_path := TEST_ROOT + "/resolved-fallback.bin"
	var fallback_extract := resolver.extract_resolved(fallback_result, fallback_extract_path)
	_check(
		fallback_extract.ok
		and str(fallback_extract.sha256) == fallback_sha
		and FileAccess.get_file_as_bytes(fallback_extract_path) == fallback_data,
		"resolver atomically publishes reopened hash-verified fallback bytes"
	)
	_check(_sibling_temp_files(fallback_extract_path).is_empty(), "successful fallback extraction leaves no sibling temporary file")
	var invalid_chunk_path := TEST_ROOT + "/invalid-chunk.bin"
	_check(not resolver.extract_resolved(fallback_result, invalid_chunk_path, 0).ok and not FileAccess.file_exists(invalid_chunk_path), "resolver rejects an unsafe extraction chunk size before creating output")
	_check(_sibling_temp_files(invalid_chunk_path).is_empty(), "invalid chunk rejection leaves no sibling temporary file")
	_write_bytes(fallback_path, "changed fallback".to_ascii_buffer())
	var tampered_fallback_path := TEST_ROOT + "/tampered-fallback.bin"
	_check(
		not resolver.extract_resolved(fallback_result, tampered_fallback_path, 3).ok
		and not FileAccess.file_exists(tampered_fallback_path),
		"resolver rejects a fallback changed after resolution without publishing output"
	)
	_check(_sibling_temp_files(tampered_fallback_path).is_empty(), "tampered fallback rejection removes its sibling temporary file")
	var batch_first_path := str(batch.replacement_paths["D0044.OGG"])
	_write_bytes(batch_first_path, _ogg_bytes(3))
	_check(resolver.read_resolved(overlay_result).is_empty(), "overlay hash is rechecked when bytes are read")
	_check(resolver.last_error.contains("hash changed"), "post-validation overlay tampering fails closed")
	var tampered_extract_path := TEST_ROOT + "/tampered-overlay.ogg"
	_check(not resolver.extract_resolved(overlay_result, tampered_extract_path).ok and not FileAccess.file_exists(tampered_extract_path), "resolver rejects tampered overlay extraction before creating output")
	_check(_sibling_temp_files(tampered_extract_path).is_empty(), "tampered overlay rejection leaves no sibling temporary file")
	_write_bytes(batch_first_path, batch_first)
	resolver.close()

	var pristine_mutable_archive := FileAccess.get_file_as_bytes(archive_path)
	_write_bytes(mutable_archive_path, pristine_mutable_archive)
	var source_change_resolver := ContentResolverScript.new()
	_check(source_change_resolver.register_original_archive("voice.arc", mutable_archive_path), "source-change fixture registers a byte-identical ARC copy")
	_check(source_change_resolver.configure_overlay(overlay_root), "source-change fixture configures the valid overlay")
	var source_change_bindings: Dictionary = source_change_resolver.validate_overlay_archive_bindings("voice.arc")
	_check(source_change_bindings.ok and source_change_bindings.descriptors.size() == 2, "source-change fixture batch-validates before external mutation")
	var changed_source_bytes := pristine_mutable_archive.duplicate()
	var first_payload_offset := int(reader.get_entry("D0044.OGG").offset)
	changed_source_bytes[first_payload_offset] = changed_source_bytes[first_payload_offset] ^ 0x01
	_write_bytes(mutable_archive_path, changed_source_bytes)
	var changed_source_resolution: Dictionary = source_change_resolver.resolve("voice.arc", "D0044.OGG")
	_check(
		not changed_source_resolution.ok
		and str(changed_source_resolution.get("error", "")).contains("base ARC hash"),
		"normal resolve rechecks and rejects an original ARC changed after successful batch validation"
	)
	_write_bytes(mutable_archive_path, pristine_mutable_archive)
	_check(FileAccess.get_sha256(mutable_archive_path) == FileAccess.get_sha256(archive_path), "source-change fixture restores its byte-identical ARC copy")
	_check(
		source_change_resolver.register_original_archive("voice.arc", mutable_archive_path),
		"source-change fixture reopens its reader after restoring the ARC copy"
	)
	var restored_source_resolution: Dictionary = source_change_resolver.resolve("voice.arc", "D0044.OGG")
	_check(
		restored_source_resolution.ok
		and str(restored_source_resolution.source) == "overlay"
		and str(restored_source_resolution.sha256) == OverlayPackageScript.sha256_bytes(batch_first),
		"normal resolve succeeds again only after restored source bytes are reopened and revalidated"
	)
	source_change_resolver.close()

	var unconfigured_resolver := ContentResolverScript.new()
	_check(unconfigured_resolver.register_original_archive("voice.arc", archive_path), "unconfigured batch fixture registers its original ARC")
	var unconfigured_batch: Dictionary = unconfigured_resolver.validate_overlay_archive_bindings("voice.arc")
	_check(
		not unconfigured_batch.ok
		and unconfigured_batch.get("records", []).is_empty()
		and unconfigured_batch.get("descriptors", {}).is_empty(),
		"batch binding rejects an unconfigured overlay without partial results"
	)
	unconfigured_resolver.close()

	var unregistered_resolver := ContentResolverScript.new()
	_check(unregistered_resolver.configure_overlay(overlay_root), "unregistered batch fixture configures a structural overlay")
	var unregistered_batch: Dictionary = unregistered_resolver.validate_overlay_archive_bindings("voice.arc")
	_check(
		not unregistered_batch.ok
		and unregistered_batch.get("records", []).is_empty()
		and unregistered_batch.get("descriptors", {}).is_empty(),
		"batch binding rejects an unregistered original archive without partial results"
	)
	unregistered_resolver.close()

	var manifest_path := ProjectSettings.globalize_path(overlay_root).simplify_path().path_join("manifest.json")
	var valid_batch_manifest_text := FileAccess.get_file_as_string(manifest_path)
	var invalid_binding_cases := [
		{
			"label": "wrong-base",
			"error_fragment": "base ARC hash",
			"field": "base_archive_sha256",
			"value": "0".repeat(64),
		},
		{
			"label": "stale-entry",
			"error_fragment": "original entry hash",
			"field": "original_entry_sha256",
			"value": "0".repeat(64),
		},
		{
			"label": "missing-entry",
			"error_fragment": "missing from the original ARC",
			"field": "target_entry",
			"value": "MISSING.OGG",
		},
	]
	for invalid_case in invalid_binding_cases:
		var invalid_manifest: Dictionary = JSON.parse_string(valid_batch_manifest_text)
		for untyped_record in invalid_manifest.replacements:
			var record: Dictionary = untyped_record
			if str(record.target_archive).to_upper() == "VOICE.ARC" and str(record.target_entry).to_upper() == "D0045.OGG":
				record[str(invalid_case.field)] = invalid_case.value
		_write_text(manifest_path, JSON.stringify(invalid_manifest, "\t") + "\n")
		_check(overlay_package.load_manifest(overlay_root).ok, "%s batch fixture remains structurally valid" % str(invalid_case.label))
		var invalid_resolver := ContentResolverScript.new()
		_check(invalid_resolver.register_original_archive("voice.arc", archive_path), "%s batch fixture registers the original ARC" % str(invalid_case.label))
		_check(invalid_resolver.configure_overlay(overlay_root), "%s batch fixture configures the overlay snapshot" % str(invalid_case.label))
		var rejected_bindings: Dictionary = invalid_resolver.validate_overlay_archive_bindings("voice.arc")
		_check(
			not rejected_bindings.ok
			and str(rejected_bindings.error).contains(str(invalid_case.error_fragment))
			and rejected_bindings.get("records", []).is_empty()
			and rejected_bindings.get("descriptors", {}).is_empty(),
			"%s batch binding fails atomically without partial records or descriptors" % str(invalid_case.label)
		)
		invalid_resolver.close()
	_write_text(manifest_path, valid_batch_manifest_text)
	_check(overlay_package.load_manifest(overlay_root).ok, "batch-binding fixtures restore the valid overlay manifest")

	var mismatch_resolver := ContentResolverScript.new()
	_check(mismatch_resolver.register_original_archive("voice.arc", other_archive_path), "alternate base ARC registers")
	_check(mismatch_resolver.configure_overlay(overlay_root), "overlay structure validates before base binding")
	var mismatch := mismatch_resolver.resolve("voice.arc", "D0044.OGG")
	_check(not mismatch.ok and str(mismatch.error).contains("base ARC hash"), "base ARC hash mismatch fails closed")
	mismatch_resolver.close()

	_write_bytes(batch_first_path, _ogg_bytes(4))
	var tampered := overlay_package.load_manifest(overlay_root)
	_check(not tampered.ok and str(tampered.error).contains("hash mismatch"), "tampered overlay payload is rejected")
	_write_bytes(batch_first_path, batch_first)
	var file_first_path := TEST_ROOT + "/file-first.ogg"
	var file_second_path := TEST_ROOT + "/file-second.ogg"
	var file_first := _ogg_bytes(21)
	var file_second := _ogg_bytes(22)
	_write_bytes(file_first_path, file_first)
	_write_bytes(file_second_path, file_second)
	var manifest_sha_before_missing_file := FileAccess.get_sha256(updated.manifest_path)
	var missing_file_batch := overlay_package.stage_replacements_from_files(
		overlay_root, reader, "voice.arc", {"D0044.OGG": TEST_ROOT + "/missing.ogg"}
	)
	_check(not missing_file_batch.ok, "file-backed overlay batch rejects a missing source file")
	_check(FileAccess.get_sha256(updated.manifest_path) == manifest_sha_before_missing_file, "rejected file-backed batch leaves manifest byte-identical")
	var file_batch := overlay_package.stage_replacements_from_files(
		overlay_root,
		reader,
		"voice.arc",
		{"D0044.OGG": file_first_path, "D0045.OGG": file_second_path}
	)
	_check(file_batch.ok and file_batch.records.size() == 2, "file-backed overlay batch streams both payloads")
	loaded = overlay_package.load_manifest(overlay_root)
	_check(loaded.ok and loaded.manifest.projections.size() == 1, "later binary replacement updates preserve remaining MES projections")
	_check(FileAccess.get_file_as_bytes(file_batch.replacement_paths["D0044.OGG"]) == file_first, "first streamed overlay payload verifies")
	_check(FileAccess.get_file_as_bytes(file_batch.replacement_paths["D0045.OGG"]) == file_second, "second streamed overlay payload verifies")
	reader.close()

	_run_mod_definition_tests(overlay_package, overlay_root)

	_cleanup()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _run_mod_definition_tests(overlay_package: OverlayPackageScript, overlay_root: String) -> void:
	var contract_fp := FileAccess.get_file_as_string("res://config/contracts/mod_event_definition_v1/contract_fingerprint").strip_edges()
	var cells_fp := FileAccess.get_file_as_string("res://config/contracts/state_cells_v1/cells_fingerprint").strip_edges()

	var new_event_document := _load_json_dictionary("res://config/contracts/mod_event_definition_v1/valid/new_event_plain.json")
	new_event_document.contract_fingerprint = contract_fp
	new_event_document.cells_fingerprint = cells_fp
	var new_event_bytes := (JSON.stringify(new_event_document, "  ") + "\n").to_utf8_buffer()
	var new_event_id := str(new_event_document.id)

	var override_document := _load_json_dictionary("res://config/contracts/mod_event_definition_v1/valid/override_conditions.json")
	override_document.contract_fingerprint = contract_fp
	override_document.cells_fingerprint = cells_fp
	override_document.target.id = "ai.school.gate.pic.1"
	var override_bytes := (JSON.stringify(override_document, "  ") + "\n").to_utf8_buffer()
	var override_id := str(override_document.id)

	var before_manifest := overlay_package.load_manifest(overlay_root)
	var before_replacement_count := int(before_manifest.manifest.replacements.size())
	var before_projection_count := int(before_manifest.manifest.get("projections", []).size())

	var batch := overlay_package.stage_mod_definitions(overlay_root, [new_event_bytes, override_bytes])
	_check(batch.ok, "mod definition batch of one new_event and one override stages")
	if not batch.ok:
		return
	_check(batch.records.size() == 2 and batch.definition_paths.size() == 2, "mod definition batch reports every published document")
	var loaded := overlay_package.load_manifest(overlay_root)
	_check(loaded.ok and loaded.manifest.definitions.size() == 2, "overlay manifest carries both staged mod definitions")
	var new_event_record := overlay_package.find_mod_definition(loaded.manifest, new_event_id)
	_check(
		not new_event_record.is_empty()
		and str(new_event_record.kind) == "mod_event_definition"
		and str(new_event_record.schema) == "kakyu_mod_event_definition/v1"
		and str(new_event_record.definition_kind) == "new_event"
		and str(new_event_record.mod_id) == "samplemod"
		and int(new_event_record.mod_revision) == 1
		and str(new_event_record.target_id) == ""
		and str(new_event_record.compatibility) == "remake_only"
		and str(new_event_record.text_encoding) == "utf8"
		and str(new_event_record.definition_path) == "definitions/%s-%s.json" % [new_event_record.definition_sha256, new_event_id],
		"staged new_event record carries the A.1 field shape"
	)
	var override_record := overlay_package.find_mod_definition(loaded.manifest, override_id)
	_check(
		not override_record.is_empty()
		and str(override_record.definition_kind) == "override"
		and str(override_record.target_id) == "ai.school.gate.pic.1",
		"staged override record carries its target id"
	)
	_check(
		FileAccess.file_exists(str(batch.definition_paths[new_event_id]))
		and FileAccess.file_exists(str(batch.definition_paths[override_id])),
		"both staged mod definition payloads are published at their content-addressed paths"
	)

	var definitions_directory := ProjectSettings.globalize_path(overlay_root).path_join("definitions")

	var old_blob_path := str(batch.definition_paths[new_event_id])
	var updated_new_event_document: Dictionary = new_event_document.duplicate(true)
	updated_new_event_document.display.title_en = "A new event, updated"
	var updated_new_event_bytes := (JSON.stringify(updated_new_event_document, "  ") + "\n").to_utf8_buffer()
	var updated_batch := overlay_package.stage_mod_definitions(overlay_root, [updated_new_event_bytes])
	_check(updated_batch.ok, "re-staging the same definition id with different bytes is accepted")
	loaded = overlay_package.load_manifest(overlay_root)
	_check(loaded.ok and loaded.manifest.definitions.size() == 2, "updating a definition in place does not grow the manifest")
	var refreshed_record := overlay_package.find_mod_definition(loaded.manifest, new_event_id)
	_check(
		not refreshed_record.is_empty() and str(refreshed_record.definition_sha256) == OverlayPackageScript.sha256_bytes(updated_new_event_bytes),
		"re-staged definition record points at the updated content-addressed payload"
	)
	_check(FileAccess.file_exists(old_blob_path), "re-staging a definition id keeps the old content-addressed blob")
	var manifest_text_after_update := FileAccess.get_file_as_string(overlay_root.path_join("manifest.json"))
	_check(
		manifest_text_after_update.count("\"mod_revision\": 1\n") + manifest_text_after_update.count("\"mod_revision\": 1,\n") == 2
		and not manifest_text_after_update.contains("\"mod_revision\": 1.0"),
		"a record carried over from the loaded manifest is written back with an integer mod_revision"
	)

	var manifest_sha_before_rejections := FileAccess.get_sha256(overlay_root.path_join("manifest.json"))
	var payload_count_before_rejections := DirAccess.get_files_at(definitions_directory).size()

	var duplicate_document: Dictionary = new_event_document.duplicate(true)
	duplicate_document.id = "mod.samplemod.duplicate_target"
	var duplicate_bytes := (JSON.stringify(duplicate_document, "  ") + "\n").to_utf8_buffer()
	var duplicate_batch := overlay_package.stage_mod_definitions(overlay_root, [duplicate_bytes, duplicate_bytes])
	_check(not duplicate_batch.ok, "a duplicate definition id within one batch is refused")

	var foreign_mod_document: Dictionary = new_event_document.duplicate(true)
	foreign_mod_document.mod = {"id": "othermod", "revision": 1}
	foreign_mod_document.id = "mod.othermod.new_event_plain"
	var foreign_mod_bytes := (JSON.stringify(foreign_mod_document, "  ") + "\n").to_utf8_buffer()
	var foreign_mod_batch := overlay_package.stage_mod_definitions(overlay_root, [foreign_mod_bytes])
	_check(not foreign_mod_batch.ok, "a second mod_id is refused")

	var text_ref_document: Dictionary = new_event_document.duplicate(true)
	text_ref_document.id = "mod.samplemod.text_ref_holder"
	text_ref_document["text_ref"] = {"offset": 0}
	var text_ref_bytes := (JSON.stringify(text_ref_document, "  ") + "\n").to_utf8_buffer()
	var text_ref_batch := overlay_package.stage_mod_definitions(overlay_root, [text_ref_bytes])
	_check(not text_ref_batch.ok, "a document holding a text_ref key is refused")

	var oversize_bytes := PackedByteArray()
	oversize_bytes.resize(OverlayPackageScript.MAX_DEFINITION_BYTES + 1)
	oversize_bytes.fill(0x20)
	var oversize_batch := overlay_package.stage_mod_definitions(overlay_root, [oversize_bytes])
	_check(not oversize_batch.ok, "an oversize document is refused")

	var invalid_json_bytes := "{ this is not JSON".to_utf8_buffer()
	var invalid_json_batch := overlay_package.stage_mod_definitions(overlay_root, [invalid_json_bytes])
	_check(not invalid_json_batch.ok, "invalid JSON is refused")

	var invalid_utf8_bytes := PackedByteArray([0x7B, 0x22, 0x61, 0x22, 0x3A, 0x22, 0xFF, 0xFE, 0x22, 0x7D])
	var invalid_utf8_batch := overlay_package.stage_mod_definitions(overlay_root, [invalid_utf8_bytes])
	_check(not invalid_utf8_batch.ok, "invalid UTF-8 is refused")

	_check(
		FileAccess.get_sha256(overlay_root.path_join("manifest.json")) == manifest_sha_before_rejections,
		"every refused mod definition batch leaves the manifest byte-identical"
	)
	_check(
		DirAccess.get_files_at(definitions_directory).size() == payload_count_before_rejections,
		"every refused mod definition batch creates no new payload file"
	)

	var round_trip := overlay_package.load_mod_definition(overlay_root, override_id)
	_check(
		round_trip.ok and round_trip.found
		and round_trip.document.id == override_id
		and PackedByteArray(round_trip.bytes) == override_bytes,
		"load_mod_definition round-trips the exact bytes and parsed document"
	)

	var valid_manifest_text := FileAccess.get_file_as_string(overlay_root.path_join("manifest.json"))
	var tamper_labels: Array[String] = ["hash mismatch", "wrong path", "foreign mod_id", "new_event with target_id"]
	for tamper_label in tamper_labels:
		var tampered_manifest: Dictionary = JSON.parse_string(valid_manifest_text)
		var tampered_record: Dictionary = tampered_manifest.definitions[0]
		match tamper_label:
			"hash mismatch":
				tampered_record.definition_sha256 = "0".repeat(64)
			"wrong path":
				tampered_record.definition_path = "definitions/%s-mod.samplemod.wrong_path.json" % tampered_record.definition_sha256
			"foreign mod_id":
				tampered_record.mod_id = "othermod"
			"new_event with target_id":
				if tampered_record.definition_kind == "new_event":
					tampered_record.target_id = "ai.school.gate.pic.1"
		_write_text(overlay_root.path_join("manifest.json"), JSON.stringify(tampered_manifest, "  ") + "\n")
		var tampered_load := overlay_package.load_manifest(overlay_root)
		_check(not tampered_load.ok, "tampered manifest (%s) fails load_manifest" % tamper_label)
	var duplicate_id_manifest: Dictionary = JSON.parse_string(valid_manifest_text)
	duplicate_id_manifest.definitions.append(duplicate_id_manifest.definitions[0].duplicate(true))
	_write_text(overlay_root.path_join("manifest.json"), JSON.stringify(duplicate_id_manifest, "  ") + "\n")
	var duplicate_id_load := overlay_package.load_manifest(overlay_root)
	_check(not duplicate_id_load.ok, "a tampered manifest with a duplicate definition id fails load_manifest")
	_write_text(overlay_root.path_join("manifest.json"), valid_manifest_text)
	_check(overlay_package.load_manifest(overlay_root).ok, "mod definition tamper fixtures restore the valid overlay manifest")

	var without_definitions_key: Dictionary = JSON.parse_string(valid_manifest_text)
	without_definitions_key.erase("definitions")
	_write_text(overlay_root.path_join("manifest.json"), JSON.stringify(without_definitions_key, "  ") + "\n")
	var without_key_load := overlay_package.load_manifest(overlay_root)
	_check(without_key_load.ok and without_key_load.manifest.get("definitions", []).is_empty(), "a manifest without the definitions key still loads as empty")
	_write_text(overlay_root.path_join("manifest.json"), valid_manifest_text)
	_check(overlay_package.load_manifest(overlay_root).ok, "restoring the valid manifest after the missing-key fixture reopens")

	var removed := overlay_package.remove_mod_definition(overlay_root, new_event_id)
	_check(removed.ok and removed.removed, "remove_mod_definition removes the record")
	_check(FileAccess.file_exists(str(removed.unreferenced_definition_path)), "remove_mod_definition keeps the unreferenced payload")
	loaded = overlay_package.load_manifest(overlay_root)
	_check(loaded.ok and loaded.manifest.definitions.size() == 1 and overlay_package.find_mod_definition(loaded.manifest, new_event_id).is_empty(), "removed mod definition is gone from the manifest")
	var manifest_sha_after_removal := FileAccess.get_sha256(overlay_root.path_join("manifest.json"))
	var idempotent_removal := overlay_package.remove_mod_definition(overlay_root, new_event_id)
	_check(idempotent_removal.ok and not idempotent_removal.removed, "removing an absent mod definition is idempotent")
	_check(FileAccess.get_sha256(overlay_root.path_join("manifest.json")) == manifest_sha_after_removal, "idempotent mod definition removal leaves the manifest byte-identical")

	loaded = overlay_package.load_manifest(overlay_root)
	_check(
		int(loaded.manifest.replacements.size()) == before_replacement_count
		and int(loaded.manifest.get("projections", []).size()) == before_projection_count,
		"the rejected and accepted mod definition batches never disturb existing replacement and projection records"
	)


func _load_json_dictionary(path: String) -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value


func _ogg_bytes(marker: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(58)
	data.fill(0)
	SyntheticArc.write_ascii(data, 0, "OggS")
	data[5] = 0x02
	data[14] = marker
	data[26] = 1
	data[27] = 30
	data[28] = 1
	SyntheticArc.write_ascii(data, 29, "vorbis")
	data[39] = 1
	data.encode_u32(40, 44100)
	data[56] = 0xB8
	data[57] = 1
	return data


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


func _synthetic_invalid_cp932_mes() -> PackedByteArray:
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(PackedByteArray([0x8F, 0x01, 0x00, 0xFF]))
	return mes


func _utf8_overlay_plan(archive_sha: String, entry_sha: String, message_sha: String) -> Dictionary:
	var operation := {
		"kind": "replace_message_utf8_overlay",
		"source_offset": 0,
		"raw_sha256": message_sha,
		"text": "계획된 UTF-8 😀",
		"encoding": "utf8",
		"compatibility": "remake_only",
		"container_policy": "do_not_assemble_mes",
	}
	var plan := {
		"ok": true,
		"schema": "kakyu_mes_utf8_overlay_plan/v1",
		"producer": {
			"implementation": "python_phase6_utf8_overlay_planner",
			"contract": "kakyu_mes_utf8_overlay_plan/v1",
		},
		"compatibility": MesUtf8OverlayPlanScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "TEST.MES",
			"source_kind": "original_arc",
			"archive_sha256": archive_sha,
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"entry_sha256": entry_sha,
		},
		"operation": operation,
		"target": {
			"reference_id": "message_00000000",
			"node_id": "node_00000000",
			"region_id": "entry_0000",
			"instruction_start": 0,
			"instruction_end": 7,
			"payload_start": 1,
			"payload_end": 6,
			"source_byte_length": 5,
			"source_raw_sha256": message_sha,
		},
		"projection_document": {
			"schema": "kakyu_mes_text_overlay_entry/v1",
			"base_archive_sha256": archive_sha,
			"entry_sha256": entry_sha,
			"target_archive": "mes.arc",
			"target_entry": "TEST.MES",
			"edits": [{
				"source_offset": 0,
				"raw_sha256": message_sha,
				"text": "계획된 UTF-8 😀",
			}],
		},
		"invariants": {
			"source_editable_ir_validated": true,
			"target_message_unique_and_typed": true,
			"source_message_hash_matched": true,
			"source_message_strict_cp932": true,
			"replacement_utf8_valid": true,
			"projection_document_ready": true,
			"mes_container_bytes_not_emitted": true,
			"source_container_not_modified": true,
		},
	}
	plan["payload_sha256"] = FingerprintScript.new().fingerprint(plan)
	return plan


func _write_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _sibling_temp_files(output_path: String) -> Array[String]:
	var found: Array[String] = []
	var absolute := ProjectSettings.globalize_path(output_path).simplify_path()
	var parent := absolute.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		return found
	var prefix := absolute.get_file() + ".tmp-"
	for file_name in DirAccess.get_files_at(parent):
		if str(file_name).begins_with(prefix):
			found.append(str(file_name))
	return found


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
