class_name KakyuMesBytecodeCodeSource
extends KakyuMesCodeSource

# The bytecode-backed instruction supply: a PackedByteArray and the decoder,
# which is exactly what every MES runner used to hold inline.
#
# This is the analysis side of the boundary. A remake that only ever plays a
# playback package never constructs one, and the runners reach it through
# KakyuMesCodeSource.for_bytecode so that no static dependency on the decoder
# survives into the playback side. See
# docs/spec/tech/playback_package_schema.md.

const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")

var _code: PackedByteArray
var _decoder := DecoderScript.new()



func _init(code := PackedByteArray()) -> void:
	_code = code


func size() -> int:
	return _code.size()


func decode_at(offset: int, limit := -1) -> Dictionary:
	return _decoder.decode_at(_code, offset, limit)


func decode_at_structural(offset: int, limit := -1) -> Dictionary:
	return _decoder.decode_at_structural(_code, offset, limit)


func is_dialogue_boundary_pattern(offset: int, limit: int) -> bool:
	if offset < 0 or offset + 4 > limit or offset + 4 > _code.size():
		return false
	return _code.slice(offset, offset + 4) == PackedByteArray([0x02, 0x02, 0xFF, 0x00])


func dialogue_boundary_end(offset: int, limit: int) -> int:
	# Where a dialogue boundary resumes. The archive's form is the message wait
	# System.function[19](2) as one system call (Core 0.316.0); the four-byte
	# 02 02 FF 00 trailer is what a command 0x02 standing on its own still marks.
	if offset >= 0 and offset + 7 <= limit and offset + 7 <= _code.size():
		if _code.slice(offset, offset + 7) == PackedByteArray([0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00]):
			return offset + 7
	if is_dialogue_boundary_pattern(offset, limit):
		return offset + 4
	return -1


func byte_at(offset: int, limit: int) -> int:
	if offset < 0 or offset >= limit or offset >= _code.size():
		return -1
	return int(_code[offset])


func hex_range(start: int, end: int) -> String:
	if start < 0 or end > _code.size() or end < start:
		return ""
	return _code.slice(start, end).hex_encode()


func sha256_range(start: int, end: int) -> String:
	if start < 0 or end > _code.size() or end < start:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(_code.slice(start, end))
	return context.finish().hex_encode()
