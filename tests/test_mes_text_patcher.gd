extends "res://tests/test_case.gd"

const MesTextPatcherScript := preload("res://content_core/mes_text_patcher.gd")


func _ready() -> void:
	var source := _synthetic_mes()
	var source_copy := source.duplicate()
	var patcher := MesTextPatcherScript.new()
	var eligible := patcher.validate_replacement_text(String.chr(0x3044), 2)
	_check(eligible.ok and eligible.byte_length == 2, "standalone replacement validation exposes exact CP932 eligibility")
	var live_length := patcher.validate_replacement_text("ABC", 2)
	_check(not live_length.ok and live_length.error_code == "byte_length" and live_length.byte_length == 3, "standalone replacement validation reports live byte length")
	var native_pair := patcher.validate_native_double_byte_replacement(String.chr(0x3044), 2)
	var native_ascii := patcher.validate_native_double_byte_replacement("AB", 2)
	_check(native_pair.ok and not native_ascii.ok and native_ascii.error_code == "native_projection", "native-boundary validation requires complete double-byte pairs")
	var first_hash := _sha256(PackedByteArray([0x82, 0xA0]))
	var second_hash := _sha256(PackedByteArray([0x82, 0xA2]))
	var patched := patcher.patch_equal_length(source, [
		{"source_offset": 0, "raw_sha256": first_hash, "text": String.chr(0x3044)},
		{"source_offset": 4, "raw_sha256": second_hash, "text": String.chr(0x3046)},
	])
	_check(patched.ok and patched.edit_count == 2, "equal-length CP932 edits produce one verified MES payload")
	if patched.ok:
		var data: PackedByteArray = patched.data
		_check(data.size() == source.size() and data.decode_u32(4) == source.decode_u32(4), "equal-length patch preserves MES size and address table")
		_check(data.slice(8, 12) == PackedByteArray([0x01, 0x82, 0xA2, 0x00]), "command-01 text bytes change without moving its terminator")
		_check(data.slice(12, 15) == PackedByteArray([0x82, 0xA4, 0x00]), "dispatcher text bytes change without moving its terminator")
		_check(patched.compatibility == "original_engine_unverified" and patched.relocation == "not_required_equal_length", "patch contract remains explicitly unverified for the original engine")
	_check(source == source_copy, "patching does not mutate the source MES buffer")
	var native_patched := patcher.patch_equal_length(source, [{
		"source_offset": 0,
		"raw_sha256": first_hash,
		"text": String.chr(0x3044),
	}], true)
	_check(native_patched.ok, "strict binary output preserves the EXE-matched native text boundary")
	var ff_bounded_source := _synthetic_ff_bounded_mes()
	var ff_bounded_patch := patcher.patch_equal_length(ff_bounded_source, [{
		"source_offset": 0,
		"raw_sha256": first_hash,
		"text": String.chr(0x3044),
	}], true)
	_check(
		ff_bounded_patch.ok and ff_bounded_patch.data.slice(8, 11) == PackedByteArray([0x82, 0xA2, 0xFF]),
		"strict binary output preserves a deferred FF boundary"
	)
	var mismatched_source := _synthetic_mismatched_mes()
	_check_rejected(patcher.patch_equal_length(mismatched_source, [{
		"source_offset": 0,
		"raw_sha256": _sha256("AB".to_ascii_buffer()),
		"text": "CD",
	}], true), "crosses the original native", "strict binary output rejects an original projection boundary mismatch")

	_check_rejected(patcher.patch_equal_length(source, [{"source_offset": 0, "raw_sha256": first_hash, "text": String.chr(0x65E5) + String.chr(0x672C)}]), "requires exactly", "different CP932 byte length is rejected")
	_check_rejected(patcher.patch_equal_length(source, [{"source_offset": 0, "raw_sha256": first_hash, "text": String.chr(0x1F600)}]), "cannot encode", "non-CP932 authored text is rejected")
	_check_rejected(patcher.patch_equal_length(source, [{"source_offset": 0, "raw_sha256": first_hash, "text": String.chr(0xE000)}]), "native AI5", "CP932 user-defined lead bytes excluded by the native dispatcher are rejected")
	_check_rejected(patcher.patch_equal_length(source, [{"source_offset": 0, "raw_sha256": "00", "text": String.chr(0x3044)}]), "stale", "stale original-message hash is rejected")
	_check_rejected(patcher.patch_equal_length(source, [{"source_offset": 1, "raw_sha256": first_hash, "text": String.chr(0x3044)}]), "strict-indexed", "non-instruction message offset is rejected")
	_check_rejected(patcher.patch_equal_length(source, [
		{"source_offset": 0, "raw_sha256": first_hash, "text": String.chr(0x3044)},
		{"source_offset": 0, "raw_sha256": first_hash, "text": String.chr(0x3044)},
	]), "more than once", "duplicate edit offsets are rejected")
	get_tree().quit(1 if _failed else 0)


func _synthetic_mes() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(8)
	data.encode_u32(0, 1)
	data.encode_u32(4, 0)
	data.append_array(PackedByteArray([
		0x01, 0x82, 0xA0, 0x00,
		0x82, 0xA2, 0x00,
	]))
	return data


func _synthetic_mismatched_mes() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(8)
	data.encode_u32(0, 1)
	data.encode_u32(4, 0)
	data.append_array(PackedByteArray([0x01, 0x41, 0x42, 0x00]))
	return data


func _synthetic_ff_bounded_mes() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(8)
	data.encode_u32(0, 1)
	data.encode_u32(4, 0)
	data.append_array(PackedByteArray([0x82, 0xA0, 0xFF, 0x00]))
	return data


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


func _check_rejected(result: Dictionary, expected: String, label: String) -> void:
	_check(not result.ok and str(result.error).contains(expected), label)
