class_name KakyuMesCodeSource
extends RefCounted

# The instruction supply the MES runners read from.
#
# Every runner used to hold a PackedByteArray and a decoder directly. That is
# still what happens, in KakyuMesBytecodeCodeSource; the indirection exists so a
# playback package can supply the same instructions without any bytecode, which
# is what docs/spec/tech/playback_package_schema.md requires of the remake side.
#
# Byte-level questions a record stream cannot answer from records alone are
# named here rather than left as raw array indexing: the dialogue-boundary
# pattern, a separator's first payload byte, a trace hex range, and the SHA-256
# of a byte range. This base answers none of them, so a source that does not
# implement one refuses rather than guessing.
#
# Refusing has to be visible in the answer itself. These methods return String
# and int, so there is no result dictionary to carry {ok: false}; an unanswerable
# range therefore returns RANGE_UNAVAILABLE rather than "". An empty string is
# not a refusal, because a guard that compares one recorded fingerprint against
# another accepts two empty strings as a match, which is how an unanswerable
# range used to pass a fingerprint check instead of failing it.
#
# for_bytecode resolves its implementation at runtime on purpose. A repository
# that keeps only the playback side has no decoder and no bytecode source, and a
# static preload here would drag both back in.

const BYTECODE_SOURCE_PATH := "res://content_core/mes_bytecode_code_source.gd"

# Deliberately not a valid SHA-256 and not valid hex, so it can never equal a
# recorded fingerprint or a real payload.
const RANGE_UNAVAILABLE := "range_unavailable"


static func for_bytecode(code: PackedByteArray) -> KakyuMesCodeSource:
	if not ResourceLoader.exists(BYTECODE_SOURCE_PATH):
		return null
	var script = load(BYTECODE_SOURCE_PATH)
	return null if script == null else script.new(code)


func size() -> int:
	return 0


func decode_at(offset: int, _limit := -1) -> Dictionary:
	return _unsupported("decode at 0x%X" % offset)


func decode_at_structural(offset: int, _limit := -1) -> Dictionary:
	return _unsupported("decode at 0x%X" % offset)


func is_dialogue_boundary_pattern(_offset: int, _limit: int) -> bool:
	return false


func dialogue_boundary_end(_offset: int, _limit: int) -> int:
	return -1


func byte_at(_offset: int, _limit: int) -> int:
	return -1


func hex_range(_start: int, _end: int) -> String:
	return RANGE_UNAVAILABLE


func sha256_range(_start: int, _end: int) -> String:
	return RANGE_UNAVAILABLE


func _unsupported(what: String) -> Dictionary:
	return {"ok": false, "error": "This code source cannot %s." % what}
