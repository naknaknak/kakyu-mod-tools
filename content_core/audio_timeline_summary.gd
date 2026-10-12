class_name KakyuAudioTimelineSummary
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const AudioValidatorScript := preload("res://content_core/audio_entry_validator.gd")

const DEFAULT_BUCKET_COUNT := 64
const MAX_BUCKET_COUNT := 256
const MAX_ANALYZED_FRAMES := 262144
const HEADER_READ_SIZE := 64 * 1024
const OGG_TAIL_READ_SIZE := 128 * 1024


static func summarize(entry_name: String, data: PackedByteArray, requested_buckets := DEFAULT_BUCKET_COUNT) -> Dictionary:
	return summarize_ranges(
		entry_name,
		data.size(),
		func(offset: int, length: int) -> PackedByteArray:
			if offset < 0 or length < 0 or offset > data.size() or length > data.size() - offset:
				return PackedByteArray()
			return data.slice(offset, offset + length),
		requested_buckets
	)


static func summarize_ranges(entry_name: String, total_size: int, read_range: Callable, requested_buckets := DEFAULT_BUCKET_COUNT) -> Dictionary:
	if requested_buckets < 1 or requested_buckets > MAX_BUCKET_COUNT:
		return _error("Audio waveform bucket count must be between 1 and %d." % MAX_BUCKET_COUNT)
	if total_size < 0 or not read_range.is_valid():
		return _error("Audio range source is invalid.")
	var header_size := mini(total_size, HEADER_READ_SIZE)
	var header: PackedByteArray = read_range.call(0, header_size)
	if header.size() != header_size:
		return _error("Audio header range could not be read completely.")
	var validation := AudioValidatorScript.validate(entry_name, header, total_size)
	if not validation.get("ok", false):
		return _error(str(validation.get("error", "Audio validation failed.")))
	if str(validation.get("container", "")) == "wav":
		return _summarize_wav_ranges(total_size, read_range, validation, requested_buckets)
	return _summarize_ogg_ranges(total_size, read_range, validation, header)


static func _summarize_wav_ranges(total_size: int, read_range: Callable, validation: Dictionary, requested_buckets: int) -> Dictionary:
	var data_offset := int(validation.get("data_offset", -1))
	var data_bytes := int(validation.get("data_bytes", -1))
	var sample_frames := int(validation.get("sample_frames", -1))
	var block_align := int(validation.get("block_align", 0))
	if data_offset < 0 or data_bytes < 0 or sample_frames < 0 or block_align <= 0:
		return _error("Validated PCM WAV layout metadata is incomplete.")
	if data_offset > total_size or data_bytes > total_size - data_offset:
		return _error("PCM WAV sample data is truncated.")
	var summary := _base_summary(validation)
	summary["sample_frames"] = sample_frames
	summary["duration_ms"] = int(validation.get("duration_ms", 0))
	summary["waveform_available"] = true
	summary["waveform_basis"] = "bounded_pcm_frame_sampling"
	if sample_frames == 0:
		summary["analyzed_frames"] = 0
		summary["complete"] = true
		summary["buckets"] = []
		return summary
	var bucket_count := mini(requested_buckets, sample_frames)
	var sample_budget := mini(sample_frames, MAX_ANALYZED_FRAMES)
	var bucket_budget_base := int(sample_budget / bucket_count)
	var bucket_budget_remainder := sample_budget % bucket_count
	var analyzed_frames := 0
	var buckets: Array[Dictionary] = []
	for bucket_index in range(bucket_count):
		var frame_start := int((int(bucket_index) * sample_frames) / bucket_count)
		var frame_end := int((int(bucket_index + 1) * sample_frames) / bucket_count)
		var available_frames := maxi(1, frame_end - frame_start)
		var bucket_budget := bucket_budget_base + (1 if bucket_index < bucket_budget_remainder else 0)
		bucket_budget = mini(maxi(1, bucket_budget), available_frames)
		var sampled_frame_start := frame_start + int((available_frames - bucket_budget) / 2)
		var sampled_bytes: PackedByteArray = read_range.call(
			data_offset + sampled_frame_start * block_align,
			bucket_budget * block_align
		)
		if sampled_bytes.size() != bucket_budget * block_align:
			return _error("PCM WAV waveform range could not be read completely.")
		var minimum := 1.0
		var maximum := -1.0
		var square_sum := 0.0
		var sample_count := 0
		for sample_index in range(bucket_budget):
			var frame_offset := sample_index * block_align
			for channel in range(int(validation.channels)):
				var amplitude := _pcm_amplitude(sampled_bytes, frame_offset, channel, validation)
				minimum = minf(minimum, amplitude)
				maximum = maxf(maximum, amplitude)
				square_sum += amplitude * amplitude
				sample_count += 1
		analyzed_frames += bucket_budget
		buckets.append({
			"frame_start": frame_start,
			"frame_end": frame_end,
			"sampled_frame_start": sampled_frame_start,
			"sampled_frame_end": sampled_frame_start + bucket_budget,
			"minimum": minimum,
			"maximum": maximum,
			"rms": sqrt(square_sum / float(sample_count)),
		})
	summary["analyzed_frames"] = analyzed_frames
	summary["complete"] = analyzed_frames == sample_frames
	summary["buckets"] = buckets
	return summary


static func _summarize_ogg_ranges(total_size: int, read_range: Callable, validation: Dictionary, header: PackedByteArray) -> Dictionary:
	var serial := int(header.decode_u32(14))
	var tail_size := mini(total_size, OGG_TAIL_READ_SIZE)
	var tail_offset := total_size - tail_size
	var data: PackedByteArray = read_range.call(tail_offset, tail_size)
	if data.size() != tail_size:
		return _error("Ogg tail range could not be read completely.")
	var offset := 0
	var final_granule := -1
	var final_page_end := -1
	var pages_scanned := 0
	while offset + 27 <= data.size():
		if data.slice(offset, offset + 4).get_string_from_ascii() != "OggS":
			offset += 1
			continue
		if data[offset + 4] != 0:
			offset += 1
			continue
		var page_serial := int(data.decode_u32(offset + 14))
		var segment_count := int(data[offset + 26])
		var table_end := offset + 27 + segment_count
		if table_end > data.size():
			offset += 1
			continue
		var body_size := 0
		for segment_index in range(segment_count):
			body_size += int(data[offset + 27 + segment_index])
		var page_end := table_end + body_size
		if page_end > data.size():
			offset += 1
			continue
		if page_serial != serial:
			offset = page_end
			continue
		var granule := int(data.decode_u64(offset + 6))
		if granule >= 0:
			final_granule = granule
			final_page_end = page_end
		pages_scanned += 1
		offset = page_end
	if final_granule < 0 or final_page_end != data.size():
		return _error("Ogg duration is unavailable because no complete final granule page was found in the bounded tail.")
	var sample_rate := int(validation.sample_rate)
	var summary := _base_summary(validation)
	summary["sample_frames"] = final_granule
	summary["duration_ms"] = int(round(float(final_granule) * 1000.0 / float(sample_rate)))
	summary["pages_scanned"] = pages_scanned
	summary["tail_bytes_read"] = tail_size
	summary["waveform_available"] = false
	summary["waveform_basis"] = "vorbis_decode_required"
	summary["analyzed_frames"] = 0
	summary["complete"] = true
	summary["buckets"] = []
	return summary


static func _pcm_amplitude(data: PackedByteArray, frame_offset: int, channel: int, validation: Dictionary) -> float:
	var bytes_per_sample := int(int(validation.bit_depth) / 8)
	var offset := frame_offset + channel * bytes_per_sample
	match int(validation.bit_depth):
		8:
			return clampf((float(data[offset]) - 128.0) / 128.0, -1.0, 1.0)
		16:
			return clampf(float(data.decode_s16(offset)) / 32768.0, -1.0, 1.0)
		24:
			var value := int(data[offset]) | (int(data[offset + 1]) << 8) | (int(data[offset + 2]) << 16)
			if (value & 0x800000) != 0:
				value -= 0x1000000
			return clampf(float(value) / 8388608.0, -1.0, 1.0)
		32:
			return clampf(float(data.decode_s32(offset)) / 2147483648.0, -1.0, 1.0)
	return 0.0


static func _base_summary(validation: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AUDIO_TIMELINE_SUMMARY_SCHEMA,
		"container": str(validation.container),
		"codec": str(validation.codec),
		"channels": int(validation.channels),
		"sample_rate": int(validation.sample_rate),
		"bytes": int(validation.bytes),
	}


static func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"schema": ContentCoreVersionScript.AUDIO_TIMELINE_SUMMARY_SCHEMA,
		"error": message,
	}
