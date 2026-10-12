extends Node

const AudioTimelineSummaryScript := preload("res://content_core/audio_timeline_summary.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

var _failed := false
var _range_source := PackedByteArray()
var _range_bytes_read := 0
var _range_call_count := 0
var _range_max_read := 0


func _ready() -> void:
	var samples := PackedInt32Array([-32768, -16384, 0, 16384, 32767, 0, -8192, 8192])
	var wave := _build_pcm16_wave(samples, 8000)
	var summary: Dictionary = AudioTimelineSummaryScript.summarize("TONE.WAV", wave, 2)
	_check(summary.ok, "PCM WAV timeline summary succeeds")
	_check(str(summary.schema) == ContentCoreVersionScript.AUDIO_TIMELINE_SUMMARY_SCHEMA, "audio timeline summary is versioned")
	_check(int(summary.sample_frames) == 8 and int(summary.duration_ms) == 1, "PCM WAV duration derives from exact sample frames")
	_check(int(summary.analyzed_frames) == 8 and bool(summary.complete), "short PCM WAV analyzes every frame")
	_check(summary.buckets.size() == 2, "requested bounded waveform bucket count is retained")
	var first: Dictionary = summary.buckets[0]
	var second: Dictionary = summary.buckets[1]
	_check(is_equal_approx(float(first.minimum), -1.0) and is_equal_approx(float(first.maximum), 0.5), "first waveform bucket preserves normalized extrema")
	_check(float(first.rms) > 0.61 and float(first.rms) < 0.62, "first waveform bucket computes normalized RMS")
	_check(float(second.minimum) < -0.24 and float(second.maximum) > 0.99, "second waveform bucket preserves normalized extrema")

	var long_samples := PackedInt32Array()
	long_samples.resize(AudioTimelineSummaryScript.MAX_ANALYZED_FRAMES + 4096)
	for index in range(long_samples.size()):
		long_samples[index] = -32768 if index % 2 == 0 else 32767
	_range_source = _build_pcm16_wave(long_samples, 8000)
	_range_bytes_read = 0
	_range_call_count = 0
	_range_max_read = 0
	var long_summary: Dictionary = AudioTimelineSummaryScript.summarize_ranges("LONG.WAV", _range_source.size(), _read_range, 64)
	_check(long_summary.ok and int(long_summary.analyzed_frames) == AudioTimelineSummaryScript.MAX_ANALYZED_FRAMES, "long PCM waveform work is capped at the shared frame budget")
	_check(not bool(long_summary.complete) and long_summary.buckets.size() == 64, "bounded long waveform reports sampling instead of claiming a complete scan")
	_check(
		_range_call_count == 65
		and _range_max_read <= AudioTimelineSummaryScript.HEADER_READ_SIZE
		and _range_bytes_read <= AudioTimelineSummaryScript.HEADER_READ_SIZE + AudioTimelineSummaryScript.MAX_ANALYZED_FRAMES * 2,
		"range analyzer reads one bounded header and one budgeted window per waveform bucket"
	)
	_check(not AudioTimelineSummaryScript.summarize("TONE.WAV", wave, 0).ok, "zero waveform buckets are rejected")
	_check(not AudioTimelineSummaryScript.summarize("TONE.WAV", wave, 257).ok, "oversized waveform bucket requests are rejected")

	var ogg := _build_vorbis_with_eos(2, 48000, 96000)
	var ogg_summary: Dictionary = AudioTimelineSummaryScript.summarize("VOICE.OGG", ogg, 32)
	_check(ogg_summary.ok, "Ogg Vorbis timeline summary succeeds")
	_check(int(ogg_summary.sample_frames) == 96000 and int(ogg_summary.duration_ms) == 2000, "Ogg duration derives from the final granule position")
	_check(int(ogg_summary.pages_scanned) == 2 and int(ogg_summary.tail_bytes_read) == ogg.size(), "Ogg duration walk accounts for the bounded tail pages")
	_check(not bool(ogg_summary.waveform_available) and ogg_summary.buckets.is_empty(), "compressed Vorbis bytes are not misrepresented as a waveform")
	_check(str(ogg_summary.waveform_basis) == "vorbis_decode_required", "Ogg waveform limitation is explicit")
	var chained := ogg.duplicate()
	chained.encode_u32(chained.size() - 13, 99)
	_check(not AudioTimelineSummaryScript.summarize("VOICE.OGG", chained).ok, "chained Ogg serials fail closed")
	_check(not AudioTimelineSummaryScript.summarize("VOICE.OGG", ogg.slice(0, ogg.size() - 1)).ok, "truncated final Ogg page fails closed")

	if _failed:
		push_error("Audio timeline summary test failed")
		get_tree().quit(1)
	else:
		print("PASS: audio timeline summary")
		get_tree().quit(0)


func _build_pcm16_wave(samples: PackedInt32Array, sample_rate: int) -> PackedByteArray:
	var data_bytes := samples.size() * 2
	var wave := PackedByteArray()
	wave.resize(44 + data_bytes)
	SyntheticArc.write_ascii(wave, 0, "RIFF")
	wave.encode_u32(4, 36 + data_bytes)
	SyntheticArc.write_ascii(wave, 8, "WAVE")
	SyntheticArc.write_ascii(wave, 12, "fmt ")
	wave.encode_u32(16, 16)
	wave.encode_u16(20, 1)
	wave.encode_u16(22, 1)
	wave.encode_u32(24, sample_rate)
	wave.encode_u32(28, sample_rate * 2)
	wave.encode_u16(32, 2)
	wave.encode_u16(34, 16)
	SyntheticArc.write_ascii(wave, 36, "data")
	wave.encode_u32(40, data_bytes)
	for index in range(samples.size()):
		wave.encode_s16(44 + index * 2, samples[index])
	return wave


func _build_vorbis_with_eos(channels: int, sample_rate: int, final_granule: int) -> PackedByteArray:
	var packet := PackedByteArray()
	packet.resize(30)
	packet[0] = 1
	SyntheticArc.write_ascii(packet, 1, "vorbis")
	packet.encode_u32(7, 0)
	packet[11] = channels
	packet.encode_u32(12, sample_rate)
	packet[28] = 0xB8
	packet[29] = 1
	var first := _build_ogg_page(0x02, 0, 7, 0, packet)
	var eos := _build_ogg_page(0x04, final_granule, 7, 1, PackedByteArray())
	first.append_array(eos)
	return first


func _build_ogg_page(header_type: int, granule: int, serial: int, sequence: int, body: PackedByteArray) -> PackedByteArray:
	var segment_count := 0 if body.is_empty() else 1
	var page := PackedByteArray()
	page.resize(27 + segment_count + body.size())
	SyntheticArc.write_ascii(page, 0, "OggS")
	page[4] = 0
	page[5] = header_type
	page.encode_u64(6, granule)
	page.encode_u32(14, serial)
	page.encode_u32(18, sequence)
	page.encode_u32(22, 0)
	page[26] = segment_count
	if segment_count == 1:
		page[27] = body.size()
		for index in range(body.size()):
			page[28 + index] = body[index]
	return page


func _read_range(offset: int, length: int) -> PackedByteArray:
	_range_call_count += 1
	_range_bytes_read += length
	_range_max_read = maxi(_range_max_read, length)
	if offset < 0 or length < 0 or offset > _range_source.size() or length > _range_source.size() - offset:
		return PackedByteArray()
	return _range_source.slice(offset, offset + length)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: %s" % label)
	else:
		_failed = true
		push_error("  FAIL: %s" % label)
