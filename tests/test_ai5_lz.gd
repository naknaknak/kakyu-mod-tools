extends "res://tests/test_case.gd"

const Ai5LzScript := preload("res://content_core/ai5_lz.gd")


func _ready() -> void:
	_round_trip(PackedByteArray(), "empty stream round trip")
	_round_trip("short literal".to_utf8_buffer(), "short literal round trip")

	var repeated := PackedByteArray()
	for index in range(1024):
		repeated.append(0x41 if index % 2 == 0 else 0x42)
	var repeated_result := _round_trip(repeated, "repeated stream round trip")
	_check(repeated_result.reference_tokens > 0, "repeated stream emits references")
	_check(repeated_result.compressed_bytes < repeated.size(), "repeated stream becomes smaller")

	var wrapped := PackedByteArray()
	for index in range(9216):
		wrapped.append((index * 29 + (index >> 3)) & 0xFF)
	_round_trip(wrapped, "window-wrap stream round trip")

	var mixed := PackedByteArray()
	for index in range(2048):
		mixed.append((index * 73 + 19) & 0xFF)
	mixed.append_array(mixed.slice(700, 1500))
	var first := Ai5LzScript.compress(mixed)
	var second := Ai5LzScript.compress(mixed)
	_check(first.ok and second.ok and first.data == second.data, "compressor output is deterministic")
	_round_trip(mixed, "mixed stream round trip")

	_check(not Ai5LzScript.decompress(PackedByteArray(), -1).ok, "negative output limit is rejected")

	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _round_trip(source: PackedByteArray, label: String) -> Dictionary:
	var compressed := Ai5LzScript.compress(source)
	var decompressed := Ai5LzScript.decompress(compressed.data, source.size())
	_check(compressed.ok and decompressed.ok and decompressed.complete and decompressed.data == source, label)
	return compressed
