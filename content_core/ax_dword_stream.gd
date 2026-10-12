class_name KakyuAxDwordStream
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const TOKEN_BYTES := 4
const TERMINATOR := 0xFFFFFFFF


func inspect(data: PackedByteArray) -> Dictionary:
	if data.size() < TOKEN_BYTES:
		return _error("AX data is shorter than one dword terminator.")
	var terminator_offset := -1
	for offset in range(0, data.size() - TOKEN_BYTES + 1, TOKEN_BYTES):
		if data.decode_u32(offset) == TERMINATOR:
			terminator_offset = offset
			break
	if terminator_offset < 0:
		return _error("AX data has no aligned 0xFFFFFFFF terminator.")
	for offset in range(terminator_offset, data.size()):
		if data[offset] != 0xFF:
			return _error("AX data contains non-0xFF bytes after its terminator.")

	var tokens: Array[Dictionary] = []
	for offset in range(0, terminator_offset, TOKEN_BYTES):
		tokens.append({
			"index": floori(float(offset) / float(TOKEN_BYTES)),
			"offset": offset,
			"value": int(data.decode_u32(offset)),
		})
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AX_DWORD_STREAM_SCHEMA,
		"token_bytes": TOKEN_BYTES,
		"token_count": tokens.size(),
		"terminator_offset": terminator_offset,
		"padding_bytes": data.size() - terminator_offset,
		"tokens": tokens,
	}


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
