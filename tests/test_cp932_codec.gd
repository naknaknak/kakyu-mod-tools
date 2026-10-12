extends "res://tests/test_case.gd"

const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")


func _ready() -> void:
	var codec := Cp932CodecScript.new()
	_check_decode(codec, "ASCII".to_ascii_buffer(), "ASCII", "ASCII bytes decode unchanged")
	_check_encode(codec, "ASCII", "ASCII".to_ascii_buffer(), "ASCII text encodes unchanged")
	_check_encode(codec, String.chr(0xFF66), PackedByteArray([0xA6]), "half-width katakana encodes")
	_check_encode(codec, String.chr(0x3042), PackedByteArray([0x82, 0xA0]), "standard hiragana encodes")
	_check_encode(
		codec,
		String.chr(0x65E5) + String.chr(0x672C) + String.chr(0x8A9E),
		PackedByteArray([0x93, 0xFA, 0x96, 0x7B, 0x8C, 0xEA]),
		"multi-character Japanese encodes"
	)
	_check_encode(codec, String.chr(0x2460), PackedByteArray([0x87, 0x40]), "Windows CP932 extension encodes deterministically")
	var unencodable := codec.encode(String.chr(0x1F600))
	_check(not unencodable.ok and unencodable.offset == 0 and str(unencodable.error).contains("not representable"), "non-CP932 Unicode fails with its character offset")
	_check_decode(codec, PackedByteArray([0xA6]), "ｦ", "half-width katakana decodes")
	_check_decode(codec, PackedByteArray([0x82, 0xA0]), "あ", "standard double-byte hiragana decodes")
	_check_decode(codec, PackedByteArray([0x93, 0xFA, 0x96, 0x7B, 0x8C, 0xEA]), "日本語", "multi-character Japanese CP932 decodes")
	_check_decode(codec, PackedByteArray([0x87, 0x40]), "①", "Windows CP932 extension decodes")
	var truncated := codec.decode(PackedByteArray([0x82]))
	_check(not truncated.ok and truncated.offset == 0 and str(truncated.error).contains("Truncated"), "truncated lead byte fails with its exact offset")
	var invalid_trail := codec.decode(PackedByteArray([0x82, 0x7F]))
	_check(not invalid_trail.ok and invalid_trail.offset == 1 and str(invalid_trail.error).contains("trail"), "invalid trail byte fails with its exact offset")
	var undefined_pair := codec.decode(PackedByteArray([0x81, 0xAD]))
	_check(not undefined_pair.ok and undefined_pair.offset == 0 and str(undefined_pair.error).contains("Undefined"), "undefined CP932 pair fails closed")
	get_tree().quit(1 if _failed else 0)


func _check_decode(codec: RefCounted, data: PackedByteArray, expected: String, label: String) -> void:
	var result: Dictionary = codec.call("decode", data)
	_check(result.ok and result.text == expected, label)


func _check_encode(codec: RefCounted, value: String, expected: PackedByteArray, label: String) -> void:
	var result: Dictionary = codec.call("encode", value)
	var decoded: Dictionary = codec.call("decode", result.get("data", PackedByteArray())) if result.ok else {}
	_check(result.ok and result.data == expected and decoded.get("ok", false) and decoded.text == value, label)
