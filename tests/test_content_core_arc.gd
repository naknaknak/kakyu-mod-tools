extends "res://tests/test_case.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcWriterScript := preload("res://content_core/arc_writer.gd")
const AudioValidatorScript := preload("res://content_core/audio_entry_validator.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const ENTRY_SIZE := 264
const SIZE_KEY := 0xF97FD0EC
const OFFSET_KEY := 0xA2C947FC
const TEST_ROOT := "user://content_core_arc_test"

var _streamed := PackedByteArray()


## Counts the whole-file hashes a reader performs (TD-57): the identity memo
## is observable through `get_archive_fingerprint()`, which is the only
## method that reads the file, so a subclass counts calls without a hook in
## the production reader.
class CountingReader extends KakyuArcReader:
	var full_hashes := 0

	func get_archive_fingerprint() -> String:
		full_hashes += 1
		return super()


func _ready() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	var source_path := TEST_ROOT + "/synthetic.arc"
	var extracted_path := TEST_ROOT + "/extracted-voice.ogg"
	var existing_extract_path := TEST_ROOT + "/existing-extract.ogg"
	var late_output_path := TEST_ROOT + "/late-output.arc"
	var late_temp_path := TEST_ROOT + "/late-output.arc.tmp-test"
	var noop_path := TEST_ROOT + "/noop.arc"
	var bound_noop_path := TEST_ROOT + "/bound-noop.arc"
	var wrong_bound_path := TEST_ROOT + "/wrong-bound.arc"
	var changed_bound_path := TEST_ROOT + "/changed-bound.arc"
	var patched_path := TEST_ROOT + "/patched.arc"
	var resized_path := TEST_ROOT + "/resized.arc"
	var streamed_path := TEST_ROOT + "/streamed.arc"
	var replacement_file_path := TEST_ROOT + "/replacement.ogg"
	var bound_streamed_path := TEST_ROOT + "/bound-streamed.arc"
	var wrong_bound_replacement_path := TEST_ROOT + "/wrong-bound-replacement.arc"
	var changed_bound_replacement_path := TEST_ROOT + "/changed-bound-replacement.arc"
	var equal_replacement_file_path := TEST_ROOT + "/equal-replacement.ogg"
	var equal_streamed_path := TEST_ROOT + "/equal-streamed.arc"
	var large_replacement_path := TEST_ROOT + "/large-replacement.bin"
	var large_streamed_path := TEST_ROOT + "/large-streamed.arc"
	var malformed_path := TEST_ROOT + "/malformed.arc"
	var unsafe_path := TEST_ROOT + "/unsafe.arc"
	var gapped_path := TEST_ROOT + "/gapped.arc"
	var voice_data := _build_vorbis_identification_page(1)
	var wave_data := _build_empty_pcm_wave()
	SyntheticArc.write_arc(source_path, [
		{"name": "VOICE01.OGG", "data": voice_data},
		{"name": "TONE.WAV", "data": wave_data},
	])

	var reader := ArcReaderScript.new()
	_check(reader.open(source_path), "synthetic ARC opens")
	_check(reader.get_entries().size() == 2, "ARC entry order is indexed")
	_check(reader.get_entries()[0].name == "VOICE01.OGG", "first ARC name decodes")
	_check(reader.read_entry("tone.wav") == wave_data, "entry lookup is case-insensitive")
	_check(reader.read_entry_range(0, 2, 4) == voice_data.slice(2, 6), "bounded range read works")
	_check(AudioValidatorScript.validate("VOICE01.OGG", voice_data).ok, "Ogg header validates")
	var ogg_validation := AudioValidatorScript.validate("VOICE01.OGG", voice_data)
	_check(ogg_validation.codec == "vorbis" and ogg_validation.channels == 1, "Vorbis metadata decodes")
	_check(not AudioValidatorScript.validate("VOICE01.OGG", PackedByteArray([1, 2, 3])).ok, "truncated Ogg is rejected")
	var wave_validation := AudioValidatorScript.validate("TONE.WAV", wave_data)
	_check(wave_validation.ok, "PCM WAV header validates")
	_check(wave_validation.channels == 2 and wave_validation.sample_rate == 44100, "WAV metadata decodes")
	_streamed.clear()
	_check(reader.stream_entry("VOICE01.OGG", _capture_chunk, 3), "entry streams in bounded chunks")
	_check(_streamed == voice_data, "streamed chunks reproduce entry bytes")
	var voice_sha := reader.get_entry_fingerprint("VOICE01.OGG")
	var extracted := reader.extract_entry("VOICE01.OGG", extracted_path)
	_check(
		extracted.ok
		and int(extracted.bytes) == voice_data.size()
		and str(extracted.sha256) == voice_sha
		and FileAccess.get_file_as_bytes(extracted_path) == voice_data,
		"entry extraction atomically publishes reopened hash-verified bytes"
	)
	_check(_sibling_temp_files(extracted_path).is_empty(), "successful entry extraction leaves no sibling temporary file")
	var existing_bytes := "keep existing output".to_ascii_buffer()
	_write_bytes(existing_extract_path, existing_bytes)
	var refused_extract := reader.extract_entry("VOICE01.OGG", existing_extract_path)
	_check(
		not refused_extract.ok and FileAccess.get_file_as_bytes(existing_extract_path) == existing_bytes,
		"entry extraction refuses and preserves an existing output"
	)
	_check(_sibling_temp_files(existing_extract_path).is_empty(), "refused entry extraction leaves no sibling temporary file")
	var source_sha := reader.get_archive_fingerprint()
	reader.close()

	var writer := ArcWriterScript.new()
	var competing_bytes := "preserve competing output".to_ascii_buffer()
	_write_bytes(late_temp_path, "verified temporary ARC".to_ascii_buffer())
	_write_bytes(late_output_path, competing_bytes)
	var late_publish := writer._publish_verified_temp(
		ProjectSettings.globalize_path(late_temp_path).simplify_path(),
		ProjectSettings.globalize_path(late_output_path).simplify_path()
	)
	_check(
		not late_publish.ok
		and str(late_publish.error).contains("appeared before ARC publication")
		and FileAccess.get_file_as_bytes(late_output_path) == competing_bytes,
		"ARC publication refuses and preserves an output that appears after verification"
	)
	_check(not FileAccess.file_exists(late_temp_path), "late publication refusal removes the verified temporary ARC")
	var noop_result := writer.write_copy(source_path, noop_path)
	_check(noop_result.ok, "no-op ARC copy succeeds")
	_check(FileAccess.get_sha256(noop_path) == source_sha, "no-op ARC copy is byte-identical")
	_check(FileAccess.get_sha256(source_path) == source_sha, "source ARC remains unchanged")
	var bound_noop := writer.write_copy_if_source_matches(
		source_path,
		bound_noop_path,
		source_sha
	)
	_check(
		bound_noop.ok
		and str(bound_noop.source_sha256) == source_sha
		and FileAccess.get_sha256(bound_noop_path) == source_sha,
		"source-bound ARC copy publishes only from the expected opened-source fingerprint"
	)
	var wrong_bound := writer.write_copy_if_source_matches(
		source_path,
		wrong_bound_path,
		"00".repeat(32)
	)
	_check(
		not wrong_bound.ok
		and str(wrong_bound.error).contains("changed after it was opened")
		and not FileAccess.file_exists(wrong_bound_path)
		and _sibling_temp_files(wrong_bound_path).is_empty(),
		"source-bound ARC copy rejects a mismatched expected fingerprint without output residue"
	)
	var source_snapshot := FileAccess.get_file_as_bytes(source_path)
	var changed_source := source_snapshot.duplicate()
	changed_source[changed_source.size() - 1] ^= 0x01
	_write_bytes(source_path, changed_source)
	var changed_bound := writer.write_copy_if_source_matches(
		source_path,
		changed_bound_path,
		source_sha
	)
	_check(
		not changed_bound.ok
		and str(changed_bound.error).contains("changed after it was opened")
		and not FileAccess.file_exists(changed_bound_path)
		and _sibling_temp_files(changed_bound_path).is_empty(),
		"source-bound ARC copy rejects a same-size source mutation made after the UI fingerprint was captured"
	)
	_write_bytes(source_path, source_snapshot)
	_check(FileAccess.get_sha256(source_path) == source_sha, "source-bound mutation fixture restores the source ARC bytes")

	var replacement := voice_data.duplicate()
	replacement[5] = 9
	replacement[6] = 8
	replacement[7] = 7
	var patch_result := writer.write_copy(source_path, patched_path, {"VOICE01.OGG": replacement})
	_check(patch_result.ok, "equal-size replacement ARC copy succeeds")
	var patched_reader := ArcReaderScript.new()
	_check(patched_reader.open(patched_path), "patched ARC reopens")
	_check(patched_reader.read_entry("VOICE01.OGG") == replacement, "patched entry is verified")
	_check(patched_reader.read_entry("TONE.WAV") == wave_data, "unchanged entry bytes are retained")
	var voice_entry := patched_reader.get_entry("VOICE01.OGG")
	patched_reader.close()
	_check(_diff_is_inside_entry(source_path, patched_path, voice_entry), "only replacement payload bytes differ")
	_check(FileAccess.get_sha256(source_path) == source_sha, "patch does not mutate source ARC")

	var resize_result := writer.write_copy(source_path, resized_path, {
		"VOICE01.OGG": PackedByteArray([1, 2, 3]),
	})
	_check(not resize_result.ok, "size-changing rebuild is rejected")
	var larger_voice := voice_data.duplicate()
	larger_voice.append_array(PackedByteArray([1, 2, 3, 4, 5]))
	var repack_result := writer.write_repacked_copy(source_path, resized_path, {
		"voice01.ogg": larger_voice,
	})
	_check(repack_result.ok and repack_result.resized_count == 1, "explicit resize-capable ARC rebuild succeeds")
	var resized_reader := ArcReaderScript.new()
	_check(resized_reader.open(resized_path), "resized ARC reopens")
	_check(resized_reader.get_entries()[0].name == "VOICE01.OGG" and resized_reader.get_entries()[1].name == "TONE.WAV", "resized ARC preserves index order")
	_check(resized_reader.read_entry("VOICE01.OGG") == larger_voice, "resized replacement bytes verify")
	_check(resized_reader.read_entry("TONE.WAV") == wave_data, "resized rebuild streams unchanged payload bytes losslessly")
	_check(int(resized_reader.get_entry("TONE.WAV").offset) == int(resized_reader.get_entry("VOICE01.OGG").offset) + larger_voice.size(), "resized ARC recomputes contiguous offsets")
	resized_reader.close()
	_check(_raw_name_bytes_equal(source_path, resized_path, 2), "resized ARC preserves opaque name fields byte-for-byte")
	_check(FileAccess.get_sha256(source_path) == source_sha, "resize rebuild does not mutate source ARC")
	_check(not writer.write_repacked_copy(source_path, resized_path, {"VOICE01.OGG": larger_voice}).ok, "resize rebuild refuses an existing output")
	_write_bytes(equal_replacement_file_path, replacement)
	var equal_streamed := writer.write_copy_from_files(source_path, equal_streamed_path, {"VOICE01.OGG": equal_replacement_file_path})
	_check(equal_streamed.ok and equal_streamed.resized_count == 0, "file-backed equal-size patch streams through the conservative API")
	var equal_streamed_reader := ArcReaderScript.new()
	_check(equal_streamed_reader.open(equal_streamed_path) and equal_streamed_reader.read_entry("VOICE01.OGG") == replacement, "file-backed equal-size patch verifies")
	equal_streamed_reader.close()
	_write_bytes(replacement_file_path, larger_voice)
	var streamed_result := writer.write_repacked_copy_from_files(source_path, streamed_path, {
		"voice01.ogg": replacement_file_path,
	})
	_check(streamed_result.ok and streamed_result.resized_count == 1, "file-backed resize rebuild succeeds through the streaming API")
	var streamed_reader := ArcReaderScript.new()
	_check(streamed_reader.open(streamed_path), "file-backed rebuilt ARC reopens")
	_check(streamed_reader.read_entry("VOICE01.OGG") == larger_voice, "file-backed replacement bytes verify")
	_check(streamed_reader.read_entry("TONE.WAV") == wave_data, "file-backed rebuild preserves unchanged payload")
	streamed_reader.close()
	var replacement_sha := FileAccess.get_sha256(replacement_file_path)
	var bound_streamed := writer.write_repacked_copy_from_bound_files(
		source_path,
		bound_streamed_path,
		source_sha,
		{"VOICE01.OGG": {"path": replacement_file_path, "sha256": replacement_sha}}
	)
	var bound_streamed_reader := ArcReaderScript.new()
	_check(
		bound_streamed.ok
		and str(bound_streamed.source_sha256) == source_sha
		and bound_streamed_reader.open(bound_streamed_path)
		and bound_streamed_reader.read_entry("VOICE01.OGG") == larger_voice,
		"bound file-backed rebuild verifies both the opened source ARC and manifest-selected replacement SHA"
	)
	bound_streamed_reader.close()
	var wrong_bound_replacement := writer.write_repacked_copy_from_bound_files(
		source_path,
		wrong_bound_replacement_path,
		source_sha,
		{"VOICE01.OGG": {"path": replacement_file_path, "sha256": "00".repeat(32)}}
	)
	_check(
		not wrong_bound_replacement.ok
		and str(wrong_bound_replacement.error).contains("bound SHA-256")
		and not FileAccess.file_exists(wrong_bound_replacement_path)
		and _sibling_temp_files(wrong_bound_replacement_path).is_empty(),
		"bound file-backed rebuild rejects a replacement that differs from its manifest fingerprint"
	)
	var replacement_snapshot := FileAccess.get_file_as_bytes(replacement_file_path)
	var changed_replacement := replacement_snapshot.duplicate()
	changed_replacement[changed_replacement.size() - 1] ^= 0x01
	_write_bytes(replacement_file_path, changed_replacement)
	var changed_bound_replacement := writer.write_repacked_copy_from_bound_files(
		source_path,
		changed_bound_replacement_path,
		source_sha,
		{"VOICE01.OGG": {"path": replacement_file_path, "sha256": replacement_sha}}
	)
	_check(
		not changed_bound_replacement.ok
		and str(changed_bound_replacement.error).contains("bound SHA-256")
		and not FileAccess.file_exists(changed_bound_replacement_path)
		and _sibling_temp_files(changed_bound_replacement_path).is_empty(),
		"bound file-backed rebuild rejects a same-size payload mutation without output residue"
	)
	_write_bytes(replacement_file_path, replacement_snapshot)
	_check(FileAccess.get_sha256(replacement_file_path) == replacement_sha, "bound replacement mutation fixture restores its payload")
	_check(not writer.write_repacked_copy_from_files(source_path, TEST_ROOT + "/missing-file.arc", {"VOICE01.OGG": TEST_ROOT + "/missing.ogg"}).ok, "file-backed writer rejects a missing replacement")
	_check(not writer.write_repacked_copy_from_files(source_path, TEST_ROOT + "/source-as-replacement.arc", {"VOICE01.OGG": source_path}).ok, "file-backed writer rejects the source ARC as replacement data")
	var large_size := 2 * 1024 * 1024 + 17
	_write_repeated_file(large_replacement_path, large_size, 0x5A)
	var large_streamed := writer.write_repacked_copy_from_files(source_path, large_streamed_path, {"VOICE01.OGG": large_replacement_path})
	_check(large_streamed.ok, "file-backed writer streams a replacement across multiple chunks")
	var large_reader := ArcReaderScript.new()
	_check(large_reader.open(large_streamed_path) and int(large_reader.get_entry("VOICE01.OGG").size) == large_size, "multi-chunk replacement size verifies without a full payload read")
	_check(_entry_sha256(large_reader, "VOICE01.OGG") == FileAccess.get_sha256(large_replacement_path), "multi-chunk rebuilt entry hash matches its source file")
	large_reader.close()
	var duplicate_target := writer.write_repacked_copy(source_path, TEST_ROOT + "/duplicate.arc", {
		"VOICE01.OGG": larger_voice,
		"voice01.ogg": larger_voice,
	})
	_check(not duplicate_target.ok, "rebuild rejects duplicate case-insensitive replacement targets")

	_create_gapped_arc(gapped_path, voice_data)
	var ambiguous_layout := writer.write_repacked_copy(gapped_path, TEST_ROOT + "/gapped-output.arc", {
		"VOICE01.OGG": larger_voice,
	})
	_check(not ambiguous_layout.ok and str(ambiguous_layout.error).contains("canonical contiguous"), "resize rebuild rejects ambiguous source gaps")
	var overwrite_result := writer.write_copy(source_path, source_path)
	_check(not overwrite_result.ok, "source overwrite is rejected")

	_create_malformed_arc(malformed_path)
	var malformed_reader := ArcReaderScript.new()
	_check(not malformed_reader.open(malformed_path), "out-of-bounds ARC entry is rejected")
	SyntheticArc.write_arc(unsafe_path, [{"name": "../ESCAPE.OGG", "data": voice_data}])
	var unsafe_reader := ArcReaderScript.new()
	_check(not unsafe_reader.open(unsafe_path), "path-traversal ARC name is rejected")

	await _check_identity_memo()

	_cleanup()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


## TD-57: the per-reader archive identity memo. The same-second cases depend
## on the clock, so `_same_second_rewrite` retries until the rewrite lands in
## the second of the reader's last full hash; the shared fixtures never rely
## on it.
func _check_identity_memo() -> void:
	var path := TEST_ROOT + "/identity-memo.arc"
	var missing_path := TEST_ROOT + "/identity-memo-missing.arc"
	var base := PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8])
	SyntheticArc.write_arc(path, [{"name": "MEMO.BIN", "data": base}])
	var counting := CountingReader.new()
	_check(counting.open(path), "identity memo fixture opens")
	_check(counting.get_archive_identity_fingerprint() == FileAccess.get_sha256(path), "the first identity lookup returns the digest of the whole file")
	var first := counting.get_archive_identity_fingerprint()
	_check(counting.full_hashes == 1, "the first identity lookup hashes the file once")
	for _repeat in range(3):
		counting.get_archive_identity_fingerprint()
	_check(counting.full_hashes == 1 and counting.get_archive_identity_fingerprint() == first, "repeated identity lookups on an unchanged open reader do not re-read the file")
	_check(counting.get_archive_fingerprint() == first and counting.full_hashes == 2, "get_archive_fingerprint() hashes in full on every call")
	_check(counting.get_archive_identity_fingerprint() == first and counting.full_hashes == 2, "get_archive_fingerprint() leaves the memo valid for the next identity lookup")
	# The memo belongs to one reader. A second reader on the same path, opened
	# while the first one's memo is warm, hashes the file itself; and a reader
	# on another archive neither reads nor disturbs the first one's memo (a
	# process-wide memo would be cleared by `open()` and refilled for the other
	# file, so the first reader would have to hash again).
	var second := CountingReader.new()
	_check(second.open(path), "a second reader opens the same archive")
	_check(second.get_archive_identity_fingerprint() == first and second.full_hashes == 1, "a second reader hashes the file itself: the identity memo is per reader")
	_check(second.get_archive_identity_fingerprint() == first and second.full_hashes == 1 and counting.full_hashes == 2, "each reader keeps its own memo")
	second.close()
	var other_path := TEST_ROOT + "/identity-memo-other.arc"
	SyntheticArc.write_arc(other_path, [{"name": "OTHER.BIN", "data": PackedByteArray([9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9])}])
	var third := CountingReader.new()
	_check(third.open(other_path), "a reader opens another archive")
	var other_digest := third.get_archive_identity_fingerprint()
	_check(other_digest == FileAccess.get_sha256(other_path) and other_digest != first and third.full_hashes == 1, "a reader on another archive hashes that archive")
	_check(counting.get_archive_identity_fingerprint() == first and counting.full_hashes == 2, "another reader's open and lookup leave this reader's memo warm")
	third.close()

	var longer := base.duplicate()
	longer.append(9)
	SyntheticArc.write_arc(path, [{"name": "MEMO.BIN", "data": longer}])
	var after_size := counting.get_archive_identity_fingerprint()
	_check(after_size == FileAccess.get_sha256(path) and after_size != first and counting.full_hashes == 3, "a size change makes the identity lookup hash the file again")

	var memo_time := FileAccess.get_modified_time(path)
	await get_tree().create_timer(1.2).timeout
	var touched := longer.duplicate()
	touched[0] = 0x55
	SyntheticArc.write_arc(path, [{"name": "MEMO.BIN", "data": touched}])
	_check(FileAccess.get_size(path) == counting._identity_size and FileAccess.get_modified_time(path) > memo_time, "the modified-time fixture rewrites at the same size more than one second later")
	var after_time := counting.get_archive_identity_fingerprint()
	_check(after_time == FileAccess.get_sha256(path) and after_time != after_size and counting.full_hashes == 4, "a modified-time change at the same size makes the identity lookup hash the file again")

	var state := {"serial": 0x20}
	var stale_digest := _same_second_rewrite(counting, path, state)
	_check(not stale_digest.is_empty(), "the same-second same-size rewrite fixture is produced")
	if not stale_digest.is_empty():
		var rewritten := FileAccess.get_sha256(path)
		_check(rewritten != stale_digest, "the same-second rewrite changed the file's digest")
		# The documented residual (TD-57, D4): size and whole-second modified
		# time cannot see this rewrite. It is asserted so it stays visible.
		_check(counting.get_archive_identity_fingerprint() == stale_digest, "residual: an identity lookup does not see a same-second same-size rewrite")
		_check(counting.get_archive_fingerprint() == rewritten, "get_archive_fingerprint() sees the same-second same-size rewrite")
		_check(counting.get_archive_identity_fingerprint() == rewritten, "get_archive_fingerprint() refreshes the memo so the next identity lookup returns the new digest")

	stale_digest = _same_second_rewrite(counting, path, state)
	_check(not stale_digest.is_empty(), "the reopen fixture rewrites the file within the memo's second")
	if not stale_digest.is_empty():
		var rewritten := FileAccess.get_sha256(path)
		var hashes_before := counting.full_hashes
		_check(counting.open(path), "an open reader reopens the rewritten file")
		_check(counting._identity_sha256.is_empty() and counting._identity_size == -1 and counting._identity_modified_time == -1, "open() clears the identity memo")
		_check(counting.get_archive_identity_fingerprint() == rewritten and rewritten != stale_digest and counting.full_hashes == hashes_before + 1, "a reopen after a same-second same-size rewrite returns the new digest")

	stale_digest = _same_second_rewrite(counting, path, state)
	_check(not stale_digest.is_empty(), "the close fixture rewrites the file within the memo's second")
	if not stale_digest.is_empty():
		var rewritten := FileAccess.get_sha256(path)
		counting.close()
		_check(counting._identity_sha256.is_empty() and counting._identity_size == -1 and counting._identity_modified_time == -1, "close() clears the identity memo")
		_check(counting.get_archive_identity_fingerprint() == "", "a closed reader has no identity")
		_check(counting.open(path) and counting.get_archive_identity_fingerprint() == rewritten and rewritten != stale_digest, "close() then open() after a same-second same-size rewrite returns the new digest")

	_check(KakyuArcReader.new().get_archive_identity_fingerprint() == "", "a reader that was never opened has no identity")
	_check(counting.get_archive_identity_fingerprint() == FileAccess.get_sha256(path) and not counting._identity_sha256.is_empty(), "the memo holds a digest before the file goes missing")
	counting.archive_path = missing_path
	_check(not FileAccess.file_exists(missing_path) and counting.get_archive_identity_fingerprint() == "", "a missing file returns an empty identity")
	_check(counting._identity_sha256.is_empty(), "a missing file clears the identity memo")
	counting.archive_path = path
	counting.close()


## Rewrites `path` at the same size inside the second of `reader`'s last full
## hash and returns the digest from before the rewrite, or "" when no attempt
## landed in the same second. Every attempt writes a payload no earlier state
## had, so a retry never restores an old digest. `state.serial` carries the
## next distinct first byte.
func _same_second_rewrite(reader: KakyuArcReader, path: String, state: Dictionary) -> String:
	for _attempt in range(10):
		var before_digest := reader.get_archive_fingerprint()
		var before_time := FileAccess.get_modified_time(path)
		state.serial = int(state.serial) + 1
		var payload := PackedByteArray([int(state.serial), 2, 3, 4, 5, 6, 7, 8, 9])
		SyntheticArc.write_arc(path, [{"name": "MEMO.BIN", "data": payload}])
		if FileAccess.get_modified_time(path) == before_time:
			return before_digest
	return ""


func _capture_chunk(chunk: PackedByteArray, _offset: int) -> bool:
	_streamed.append_array(chunk)
	return true


func _write_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


func _write_repeated_file(path: String, size: int, value: int) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	var chunk := PackedByteArray()
	chunk.resize(64 * 1024)
	chunk.fill(value)
	var remaining := size
	while remaining > 0:
		file.store_buffer(chunk.slice(0, mini(chunk.size(), remaining)))
		remaining -= mini(chunk.size(), remaining)
	file.close()


func _entry_sha256(reader: KakyuArcReader, entry_name: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var streamed := reader.stream_entry(entry_name, func(chunk: PackedByteArray, _offset: int) -> bool:
		return context.update(chunk) == OK
	)
	return context.finish().hex_encode() if streamed else ""


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


func _create_malformed_arc(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_32(1)
	file.store_buffer(SyntheticArc.encode_name("BROKEN.WAV"))
	file.store_32(100 ^ SIZE_KEY)
	file.store_32((4 + ENTRY_SIZE) ^ OFFSET_KEY)
	file.close()


func _create_gapped_arc(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_32(1)
	file.store_buffer(SyntheticArc.encode_name("VOICE01.OGG"))
	file.store_32(data.size() ^ SIZE_KEY)
	file.store_32((4 + ENTRY_SIZE + 3) ^ OFFSET_KEY)
	file.store_buffer(PackedByteArray([0xAA, 0xBB, 0xCC]))
	file.store_buffer(data)
	file.close()


func _build_empty_pcm_wave() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(44)
	data.fill(0)
	SyntheticArc.write_ascii(data, 0, "RIFF")
	data.encode_u32(4, 36)
	SyntheticArc.write_ascii(data, 8, "WAVE")
	SyntheticArc.write_ascii(data, 12, "fmt ")
	data.encode_u32(16, 16)
	data.encode_u16(20, 1)
	data.encode_u16(22, 2)
	data.encode_u32(24, 44100)
	data.encode_u32(28, 176400)
	data.encode_u16(32, 4)
	data.encode_u16(34, 16)
	SyntheticArc.write_ascii(data, 36, "data")
	data.encode_u32(40, 0)
	return data


func _build_vorbis_identification_page(marker: int) -> PackedByteArray:
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


func _diff_is_inside_entry(source_path: String, output_path: String, entry: Dictionary) -> bool:
	var source := FileAccess.get_file_as_bytes(source_path)
	var output := FileAccess.get_file_as_bytes(output_path)
	if source.size() != output.size():
		return false
	var changed := false
	for index in range(source.size()):
		if source[index] == output[index]:
			continue
		changed = true
		if index < int(entry.offset) or index >= int(entry.offset) + int(entry.size):
			return false
	return changed


func _raw_name_bytes_equal(source_path: String, output_path: String, entry_count: int) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	var output := FileAccess.open(output_path, FileAccess.READ)
	for index in range(entry_count):
		var offset := 4 + index * ENTRY_SIZE
		source.seek(offset)
		output.seek(offset)
		if source.get_buffer(256) != output.get_buffer(256):
			source.close()
			output.close()
			return false
	source.close()
	output.close()
	return true


func _cleanup() -> void:
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return
	var directory := DirAccess.open(absolute_root)
	if directory != null:
		for filename in directory.get_files():
			DirAccess.remove_absolute(absolute_root.path_join(filename))
	DirAccess.remove_absolute(absolute_root)
