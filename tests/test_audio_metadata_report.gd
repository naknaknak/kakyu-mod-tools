extends "res://tests/test_case.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAudioReferenceIndexScript := preload("res://content_core/mes_audio_reference_index.gd")
const AudioMetadataReportScript := preload("res://tools/content_suite/audio_metadata_report.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://audio_metadata_report_test"


func _ready() -> void:
	_cleanup()
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var archive_path := TEST_ROOT + "/se.arc"
	var mes_archive_path := TEST_ROOT + "/mes.arc"
	var overlay_root := TEST_ROOT + "/overlay"
	var pending_path := TEST_ROOT + "/pending-kse0002.wav"
	var report_path := TEST_ROOT + "/report.json"

	var original_a := _pcm_wave(1, 4)
	var original_b := _pcm_wave(2, 4)
	var original_maki := _pcm_wave(3, 4)
	var overlay_a := _pcm_wave(9, 8)
	var pending_b := _pcm_wave(5, 6)
	var truncated := PackedByteArray([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41])

	SyntheticArc.write_arc(archive_path, [
		{"name": "KSE0001.WAV", "data": original_a},
		{"name": "KSE0002.WAV", "data": original_b},
		{"name": "MAKI.WAV", "data": original_maki},
		{"name": "META.BIN", "data": PackedByteArray([1, 2, 3, 4])},
		{"name": "TRUNCATED.WAV", "data": truncated},
	])
	SyntheticArc.write_arc(mes_archive_path, [
		{"name": "EVENTD01.MES", "data": _mes_with_bgm_reference(33)},
		{"name": "NOT_AUDIO.MES", "data": _mes_without_bgm_reference()},
	])

	var staging_reader := ArcReaderScript.new()
	_check(staging_reader.open(archive_path), "audio metadata report fixture opens its source ARC for staging")
	var original_entry_sha256 := staging_reader.get_entry_fingerprint("KSE0001.WAV")
	var overlay_package := OverlayPackageScript.new()
	var staged := overlay_package.stage_replacement(overlay_root, staging_reader, "se.arc", "KSE0001.WAV", overlay_a, "remake_only", "not_applicable")
	_check(staged.ok, "audio metadata report fixture publishes one hash-bound overlay replacement")
	staging_reader.close()

	_write_bytes(pending_path, pending_b)
	var pending_absolute := ProjectSettings.globalize_path(pending_path).simplify_path()
	var pending_sha256 := FileAccess.get_sha256(pending_absolute)
	var session := {
		"KSE0002.WAV": {
			"path": pending_absolute,
			"sha256": pending_sha256,
			"size": pending_b.size(),
			"original_size": original_b.size(),
			"delta": pending_b.size() - original_b.size(),
			"container": "wav",
			"codec": "pcm",
		},
	}

	var reader := ArcReaderScript.new()
	_check(reader.open(archive_path), "audio metadata report fixture opens the audio ARC for reporting")
	var resolver := ContentResolverScript.new()
	_check(resolver.register_original_archive("se.arc", archive_path), "audio metadata report resolver registers the original ARC")
	_check(resolver.configure_overlay(overlay_root), "audio metadata report resolver configures the overlay")

	var reference_index := _build_reference_index(mes_archive_path)
	var mes_source_sha256 := FileAccess.get_sha256(mes_archive_path)
	_check(
		reference_index.get("ok", false) and int(reference_index.source_count) == 2 and int(reference_index.reference_count) == 1,
		"audio metadata report fixture indexes one confirmed BGM reference from two MES sources"
	)

	var entry_names: Array = ["KSE0001.WAV", "KSE0002.WAV", "MAKI.WAV"]
	var built := AudioMetadataReportScript.build(
		reader, resolver, "se.arc", entry_names, session, reference_index, mes_archive_path, mes_source_sha256
	)
	_check(built.get("ok", false), "audio metadata report builds for three audio entries with the index loaded")
	var report: Dictionary = built.get("report", {})

	_check(str(report.get("schema", "")) == ContentCoreVersionScript.AUDIO_METADATA_REPORT_SCHEMA, "audio metadata report carries its versioned schema")
	_check(
		str(report.archive.name) == "se.arc"
		and str(report.archive.sha256) == reader.get_archive_fingerprint()
		and int(report.archive.bytes) == reader.archive_size
		and int(report.archive.entries) == 5
		and int(report.archive.audio_entries) == 4,
		"audio metadata report archive block reports counts over the open ARC"
	)
	_check(
		bool(report.overlay.loaded) and int(report.overlay.replacements_for_archive) == 1,
		"audio metadata report overlay block reports the active overlay's replacement count"
	)
	_check(
		bool(report.mes_references.indexed)
		and str(report.mes_references.source) == "mes.arc"
		and str(report.mes_references.source_sha256) == mes_source_sha256
		and int(report.mes_references.source_count) == 2
		and int(report.mes_references.reference_count) == 1
		and int(report.mes_references.bgm_count) == 1
		and int(report.mes_references.voice_count) == 0,
		"audio metadata report reduces its reference source to a file name and carries the index totals"
	)

	_check(report.entries.size() == 3, "audio metadata report contains exactly the three requested rows")
	var overlay_row: Dictionary = report.entries[0]
	var pending_row: Dictionary = report.entries[1]
	var original_row: Dictionary = report.entries[2]
	_check(
		str(overlay_row.name) == "KSE0001.WAV" and str(overlay_row.source) == "overlay"
		and str(pending_row.name) == "KSE0002.WAV" and str(pending_row.source) == "pending"
		and str(original_row.name) == "MAKI.WAV" and str(original_row.source) == "original_arc",
		"audio metadata report rows keep the given order and carry the right resolved source"
	)
	_check(
		bool(overlay_row.valid) and bool(pending_row.valid) and bool(original_row.valid),
		"audio metadata report rows for well-formed audio entries validate"
	)
	_check(
		str(overlay_row.container) == "wav" and str(overlay_row.codec) == "pcm"
		and str(pending_row.container) == "wav" and str(pending_row.codec) == "pcm"
		and str(original_row.container) == "wav" and str(original_row.codec) == "pcm",
		"audio metadata report rows carry the validated container and codec"
	)
	_check(
		int(overlay_row.size) == overlay_a.size() and str(overlay_row.sha256) == OverlayPackageScript.sha256_bytes(overlay_a),
		"audio metadata report overlay row reports the effective overlay size and hash"
	)
	_check(int(pending_row.size) == pending_b.size() and str(pending_row.sha256) == pending_sha256, "audio metadata report pending row reports the re-hashed staged size and hash")
	_check(int(original_row.size) == original_maki.size() and str(original_row.sha256) == reader.get_entry_fingerprint("MAKI.WAV"), "audio metadata report original row reports the ARC entry size and hash")

	_check(
		overlay_row.overlay != null
		and str(overlay_row.overlay.original_entry_sha256) == original_entry_sha256
		and str(overlay_row.overlay.replacement_sha256) == str(overlay_row.sha256)
		and str(overlay_row.overlay.compatibility) == "remake_only"
		and str(overlay_row.overlay.text_encoding) == "not_applicable",
		"audio metadata report overlay block appears only on the overlay row"
	)
	_check(pending_row.overlay == null and original_row.overlay == null, "audio metadata report leaves the overlay block null off the overlay row")

	_check(int(original_row.mes_reference_count) == 1, "audio metadata report finds the confirmed BGM reference for MAKI.WAV")
	_check(int(overlay_row.mes_reference_count) == 0 and int(pending_row.mes_reference_count) == 0, "audio metadata report reports zero references for unreferenced entries")

	var summary: Dictionary = report.summary
	var expected_bytes := int(overlay_row.size) + int(pending_row.size) + int(original_row.size)
	var expected_duration := int(overlay_row.duration_ms) + int(pending_row.duration_ms) + int(original_row.duration_ms)
	_check(
		int(summary.entry_count) == 3
		and int(summary.original_count) == 1
		and int(summary.overlay_count) == 1
		and int(summary.pending_count) == 1
		and int(summary.wav_count) == 3
		and int(summary.ogg_count) == 0
		and int(summary.invalid_count) == 0
		and int(summary.total_bytes) == expected_bytes
		and int(summary.known_duration_ms) == expected_duration
		and int(summary.referenced_count) == 1,
		"audio metadata report summary aggregates source, validity, size, duration, and reference counts"
	)

	var canonical := FingerprintScript.new().canonical_document_json(report)
	var root_absolute := ProjectSettings.globalize_path(TEST_ROOT).simplify_path()
	_check(
		not canonical.contains(root_absolute) and not canonical.contains("user://") and not canonical.contains(pending_absolute),
		"audio metadata report canonical JSON excludes every machine-specific path"
	)

	var written := AudioMetadataReportScript.write(report, report_path)
	_check(written.get("ok", false) and str(written.sha256) == FileAccess.get_sha256(ProjectSettings.globalize_path(report_path)), "audio metadata report write publishes and rehashes its exact bytes")
	var refused := AudioMetadataReportScript.write(report, report_path)
	_check(not refused.get("ok", false), "audio metadata report write refuses an existing output")

	var reopened := AudioMetadataReportScript.read_path(report_path)
	_check(reopened.get("ok", false), "audio metadata report read_path accepts the published file")

	var tampered_fingerprint: Dictionary = report.duplicate(true)
	var fingerprint_prefix := str(tampered_fingerprint.payload_sha256).substr(0, 1)
	tampered_fingerprint.payload_sha256 = ("1" if fingerprint_prefix == "0" else "0") + str(report.payload_sha256).substr(1)
	_write_json(TEST_ROOT + "/tampered_fingerprint.json", tampered_fingerprint)
	_check(not AudioMetadataReportScript.read_path(TEST_ROOT + "/tampered_fingerprint.json").get("ok", false), "audio metadata report read_path rejects a tampered fingerprint")

	var extra_key: Dictionary = report.duplicate(true)
	extra_key["extra_field"] = true
	_write_json(TEST_ROOT + "/extra_key.json", extra_key)
	_check(not AudioMetadataReportScript.read_path(TEST_ROOT + "/extra_key.json").get("ok", false), "audio metadata report read_path rejects an extra top-level key")

	var bad_source: Dictionary = report.duplicate(true)
	bad_source.entries = (bad_source.entries as Array).duplicate(true)
	var bad_row: Dictionary = (bad_source.entries[0] as Dictionary).duplicate(true)
	bad_row.source = "bogus"
	bad_source.entries[0] = bad_row
	_write_json(TEST_ROOT + "/bad_source.json", bad_source)
	_check(not AudioMetadataReportScript.read_path(TEST_ROOT + "/bad_source.json").get("ok", false), "audio metadata report read_path rejects a bad source value")

	var non_audio_result := AudioMetadataReportScript.build(reader, resolver, "se.arc", ["META.BIN"], session, reference_index, mes_archive_path, mes_source_sha256)
	_check(not non_audio_result.get("ok", false), "audio metadata report refuses a non-audio entry name")

	var invalid_result := AudioMetadataReportScript.build(reader, resolver, "se.arc", ["TRUNCATED.WAV"], session, reference_index, mes_archive_path, mes_source_sha256)
	_check(invalid_result.get("ok", false), "audio metadata report build succeeds with an invalid audio entry, not fails")
	var invalid_report: Dictionary = invalid_result.report
	_check(
		invalid_report.entries.size() == 1
		and bool(invalid_report.entries[0].valid) == false
		and not str(invalid_report.entries[0].error).is_empty()
		and invalid_report.entries[0].container == null
		and int(invalid_report.summary.invalid_count) == 1,
		"audio metadata report marks a truncated WAV invalid without failing the build"
	)

	var unindexed_result := AudioMetadataReportScript.build(reader, resolver, "se.arc", entry_names, session, {}, mes_archive_path, mes_source_sha256)
	_check(unindexed_result.get("ok", false), "audio metadata report builds without a loaded MES reference index")
	var unindexed_report: Dictionary = unindexed_result.report
	_check(
		bool(unindexed_report.mes_references.indexed) == false
		and str(unindexed_report.mes_references.source).is_empty()
		and str(unindexed_report.mes_references.source_sha256).is_empty()
		and unindexed_report.entries[0].mes_reference_count == null
		and unindexed_report.entries[1].mes_reference_count == null
		and unindexed_report.entries[2].mes_reference_count == null,
		"audio metadata report without an index reports unindexed and null reference counts"
	)

	var mutated_pending := pending_b.duplicate()
	mutated_pending[mutated_pending.size() - 1] ^= 0x01
	_write_bytes(pending_path, mutated_pending)
	var mutated_result := AudioMetadataReportScript.build(reader, resolver, "se.arc", entry_names, session, reference_index, mes_archive_path, mes_source_sha256)
	_check(
		not mutated_result.get("ok", false) and str(mutated_result.get("error", "")).contains("changed after it was staged"),
		"audio metadata report build fails closed when a pending replacement file changes"
	)
	_write_bytes(pending_path, pending_b)
	_check(FileAccess.get_sha256(archive_path).length() == 64, "audio metadata report fixture ARC remains readable after the pending-file mutation test")

	reader.close()
	resolver.close()
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _build_reference_index(mes_archive_path: String) -> Dictionary:
	var mes_reader := ArcReaderScript.new()
	if not mes_reader.open(mes_archive_path):
		return {"ok": false, "error": mes_reader.last_error}
	var indexer := MesAudioReferenceIndexScript.new()
	var indexed_documents: Array = []
	for entry in mes_reader.get_entries():
		var data := mes_reader.read_entry(str(entry.name))
		var document := MesContainerScript.new().parse(data)
		indexed_documents.append(indexer.index_document(str(entry.name), document))
	mes_reader.close()
	return indexer.build_indexed(indexed_documents)


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


func _mes_with_bgm_reference(selector: int) -> PackedByteArray:
	var code := PackedByteArray([0x09, 0x01, 0x00])
	if selector < 0x80:
		code.append(selector)
	else:
		code.append(0xF1)
		var literal_offset := code.size()
		code.resize(literal_offset + 2)
		code.encode_u16(literal_offset, selector)
	code.append_array(PackedByteArray([0xFF, 0x00, 0x1D, 0x02, 0x17, 0xFF, 0x00, 0x00]))
	return _mes_payload(code)


func _mes_without_bgm_reference() -> PackedByteArray:
	return _mes_payload(PackedByteArray([0x09, 0x01, 0x00, 0x2A, 0xFF, 0x00, 0x1D, 0x02, 0x27, 0xFF, 0x00, 0x00]))


func _mes_payload(code: PackedByteArray) -> PackedByteArray:
	var payload := PackedByteArray()
	SyntheticArc.append_u32(payload, 1)
	SyntheticArc.append_u32(payload, 0)
	payload.append_array(code)
	return payload


func _write_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


func _write_json(path: String, document: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
