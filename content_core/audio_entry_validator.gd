class_name KakyuAudioEntryValidator
extends RefCounted


static func validate(entry_name: String, data: PackedByteArray, total_size := -1) -> Dictionary:
	var extension := entry_name.get_extension().to_lower()
	if extension == "ogg":
		return _validate_ogg(data, total_size)
	if extension == "wav":
		return _validate_wav(data, total_size)
	return {"ok": false, "error": "Only OGG and WAV entries are supported."}


static func _validate_ogg(data: PackedByteArray, total_size: int) -> Dictionary:
	if data.size() < 27 or data.slice(0, 4).get_string_from_ascii() != "OggS":
		return {"ok": false, "error": "Invalid or truncated Ogg container."}
	if data[4] != 0:
		return {"ok": false, "error": "Unsupported Ogg bitstream version."}
	if (data[5] & 0x02) == 0:
		return {"ok": false, "error": "Ogg entry does not begin with a BOS page."}
	var segment_count := int(data[26])
	if segment_count == 0 or data.size() < 27 + segment_count:
		return {"ok": false, "error": "Ogg segment table is truncated."}
	var packet_size := 0
	var packet_complete := false
	for index in range(segment_count):
		var lacing_value := int(data[27 + index])
		packet_size += lacing_value
		if lacing_value < 255:
			packet_complete = true
			break
	if not packet_complete:
		return {"ok": false, "error": "Ogg identification packet does not end on the first page."}
	var packet_offset := 27 + segment_count
	if packet_size < 30 or packet_offset + packet_size > data.size():
		return {"ok": false, "error": "Ogg identification packet is truncated."}
	if data[packet_offset] != 1 or data.slice(packet_offset + 1, packet_offset + 7).get_string_from_ascii() != "vorbis":
		return {"ok": false, "error": "Only Ogg Vorbis audio is currently supported."}
	if data.decode_u32(packet_offset + 7) != 0:
		return {"ok": false, "error": "Unsupported Vorbis identification version."}
	var channels := int(data[packet_offset + 11])
	var sample_rate := int(data.decode_u32(packet_offset + 12))
	if channels < 1 or channels > 2:
		return {"ok": false, "error": "Vorbis channel count must be 1 or 2."}
	if sample_rate < 8000 or sample_rate > 192000:
		return {"ok": false, "error": "Vorbis sample rate is outside the supported range."}
	if (data[packet_offset + 29] & 0x01) == 0:
		return {"ok": false, "error": "Vorbis identification framing bit is missing."}
	return {
		"ok": true,
		"container": "ogg",
		"codec": "vorbis",
		"channels": channels,
		"sample_rate": sample_rate,
		"bytes": total_size if total_size >= 0 else data.size(),
	}


static func _validate_wav(data: PackedByteArray, total_size: int) -> Dictionary:
	if data.size() < 44:
		return {"ok": false, "error": "Truncated WAV container."}
	if data.slice(0, 4).get_string_from_ascii() != "RIFF" or data.slice(8, 12).get_string_from_ascii() != "WAVE":
		return {"ok": false, "error": "Invalid RIFF/WAVE signature."}
	var entry_size := total_size if total_size >= 0 else data.size()
	var declared_size := data.decode_u32(4) + 8
	if declared_size > entry_size:
		return {"ok": false, "error": "WAV RIFF size exceeds the entry."}
	var format_code := -1
	var channels := 0
	var sample_rate := 0
	var bit_depth := 0
	var byte_rate := 0
	var block_align := 0
	var data_offset := -1
	var data_bytes := 0
	var found_data := false
	var offset := 12
	while offset + 8 <= data.size():
		var chunk_id := data.slice(offset, offset + 4).get_string_from_ascii()
		var chunk_size := int(data.decode_u32(offset + 4))
		var chunk_data_offset := offset + 8
		if chunk_size > entry_size - chunk_data_offset:
			return {"ok": false, "error": "WAV chunk exceeds the entry."}
		if chunk_id == "fmt ":
			if chunk_size < 16 or chunk_data_offset + 16 > data.size():
				return {"ok": false, "error": "WAV fmt chunk is truncated."}
			format_code = int(data.decode_u16(chunk_data_offset))
			channels = int(data.decode_u16(chunk_data_offset + 2))
			sample_rate = int(data.decode_u32(chunk_data_offset + 4))
			byte_rate = int(data.decode_u32(chunk_data_offset + 8))
			block_align = int(data.decode_u16(chunk_data_offset + 12))
			bit_depth = int(data.decode_u16(chunk_data_offset + 14))
		elif chunk_id == "data":
			found_data = true
			data_offset = chunk_data_offset
			data_bytes = chunk_size
		if format_code >= 0 and found_data:
			break
		var next_offset := chunk_data_offset + chunk_size + (chunk_size & 1)
		if next_offset > data.size():
			break
		offset = next_offset
	if format_code < 0:
		return {"ok": false, "error": "WAV fmt chunk was not found in the validation window."}
	if not found_data:
		return {"ok": false, "error": "WAV data chunk was not found in the validation window."}
	if format_code != 1:
		return {"ok": false, "error": "Only PCM WAV audio is currently supported."}
	if channels < 1 or channels > 2:
		return {"ok": false, "error": "WAV channel count must be 1 or 2."}
	if sample_rate < 8000 or sample_rate > 192000:
		return {"ok": false, "error": "WAV sample rate is outside the supported range."}
	if bit_depth not in [8, 16, 24, 32]:
		return {"ok": false, "error": "Unsupported PCM WAV bit depth."}
	var expected_block_align := channels * int(bit_depth / 8)
	if block_align != expected_block_align:
		return {"ok": false, "error": "PCM WAV block alignment is inconsistent with its channels and bit depth."}
	if byte_rate != sample_rate * block_align:
		return {"ok": false, "error": "PCM WAV byte rate is inconsistent with its format."}
	if data_bytes % block_align != 0:
		return {"ok": false, "error": "PCM WAV data size does not contain whole sample frames."}
	var sample_frames := int(data_bytes / block_align)
	var duration_ms := int(round(float(sample_frames) * 1000.0 / float(sample_rate)))
	return {
		"ok": true,
		"container": "wav",
		"codec": "pcm",
		"channels": channels,
		"sample_rate": sample_rate,
		"bit_depth": bit_depth,
		"byte_rate": byte_rate,
		"block_align": block_align,
		"data_offset": data_offset,
		"data_bytes": data_bytes,
		"sample_frames": sample_frames,
		"duration_ms": duration_ms,
		"bytes": entry_size,
	}
