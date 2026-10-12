extends Node

const AudioConversionScript := preload("res://content_core/audio_conversion_presets.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

var _failed := false
const TEST_ROOT := "user://audio_conversion_preset_test"


func _ready() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	_test_preset_routing()
	_test_byte_identical_no_op()
	_test_channel_conversion()
	_test_deterministic_resampling()
	_test_preserve_only_vorbis()
	_test_invalid_contracts()
	_test_atomic_publication()
	_cleanup()
	if _failed:
		push_error("Audio conversion preset test failed")
		get_tree().quit(1)
	else:
		print("PASS: deterministic audio conversion presets")
		get_tree().quit(0)


func _test_preset_routing() -> void:
	var se := AudioConversionScript.preset_for_target("SE.ARC", "KSE0031.WAV")
	_check(se.ok and str(se.id) == AudioConversionScript.PRESET_SE_PCM16_MONO_22050, "SE WAV selects the verified mono 22050 PCM16 preset")
	_check(str(se.compatibility) == "original_engine_compatible" and bool(se.can_encode), "SE preset exposes its verified compatibility and encoder")
	var bgm := AudioConversionScript.preset_for_target("bgm.arc", "MAKI.WAV")
	_check(bgm.ok and int(bgm.channels) == 2 and int(bgm.sample_rate) == 44100, "BGM WAV selects the stereo 44100 PCM16 corpus profile")
	_check(str(bgm.compatibility) == "original_engine_unverified", "BGM replacement compatibility is not overstated")
	var voice := AudioConversionScript.preset_for_target("tina1.arc", "B0796.OGG")
	_check(voice.ok and not bool(voice.can_encode), "voice Ogg selects the preserve-only profile")
	_check(not AudioConversionScript.preset_for_target("mes.arc", "B0796.OGG").ok, "unsupported archive targets have no inferred preset")


func _test_byte_identical_no_op() -> void:
	var source := _build_pcm16_wave(PackedInt32Array([-32768, -1, 0, 32767]), 1, 22050)
	source.append_array(PackedByteArray([0x4A, 0x55, 0x4E, 0x4B]))
	var converted: Dictionary = AudioConversionScript.convert(AudioConversionScript.PRESET_SE_PCM16_MONO_22050, "source.wav", source)
	_check(converted.ok and not bool(converted.converted), "matching WAV uses the no-op path")
	_check(str(converted.reason) == "already_matches_target_profile", "matching WAV reports why it was preserved")
	_check(converted.data == source, "matching valid WAV remains byte-identical, including opaque trailing bytes")
	_check(str(converted.input_sha256) == _sha256(source) and str(converted.output_sha256) == _sha256(source), "no-op conversion reports identical input and output fingerprints")
	_check(str(converted.schema) == ContentCoreVersionScript.AUDIO_CONVERSION_SCHEMA, "audio conversion result uses the versioned schema")


func _test_channel_conversion() -> void:
	var stereo := _build_pcm16_wave(PackedInt32Array([-1000, 1000, -32768, 32767, 2000, 6000]), 2, 22050)
	var mono: Dictionary = AudioConversionScript.convert(AudioConversionScript.PRESET_SE_PCM16_MONO_22050, "stereo.wav", stereo)
	_check(mono.ok and bool(mono.converted), "explicit SE conversion mixes stereo PCM to mono")
	_check(int(mono.output.channels) == 1 and int(mono.output.bit_depth) == 16, "SE conversion emits the exact target channel/depth contract")
	_check(_pcm16_samples(mono.data) == PackedInt32Array([0, -1, 4000]), "stereo-to-mono uses deterministic nearest signed averaging")

	var one_channel := _build_pcm16_wave(PackedInt32Array([-3000, 7000]), 1, 44100)
	var stereo_bgm: Dictionary = AudioConversionScript.convert(AudioConversionScript.PRESET_BGM_PCM16_STEREO_44100, "mono.wav", one_channel)
	_check(stereo_bgm.ok and int(stereo_bgm.output.channels) == 2, "explicit BGM conversion expands mono PCM to stereo")
	_check(_pcm16_samples(stereo_bgm.data) == PackedInt32Array([-3000, -3000, 7000, 7000]), "mono-to-stereo duplicates each channel deterministically")


func _test_deterministic_resampling() -> void:
	var source := _build_pcm16_wave(PackedInt32Array([0, 1000]), 1, 11025)
	var first: Dictionary = AudioConversionScript.convert(AudioConversionScript.PRESET_SE_PCM16_MONO_22050, "source.wav", source)
	var second: Dictionary = AudioConversionScript.convert(AudioConversionScript.PRESET_SE_PCM16_MONO_22050, "source.wav", source)
	_check(first.ok and int(first.output.sample_frames) == 4, "resampling derives a bounded deterministic output frame count")
	_check(_pcm16_samples(first.data) == PackedInt32Array([0, 500, 1000, 1000]), "integer linear resampling has the documented endpoint behavior")
	_check(first.data == second.data and str(first.output_sha256) == str(second.output_sha256), "repeated explicit conversion produces byte-identical WAV output")
	_check(str(first.input_sha256) == _sha256(source), "converted output retains the source fingerprint")


func _test_preserve_only_vorbis() -> void:
	var voice := _build_vorbis_identification(1, 44100)
	var preserved: Dictionary = AudioConversionScript.convert(
		AudioConversionScript.PRESET_VOICE_VORBIS_MONO_44100_PRESERVE,
		"voice.ogg",
		voice
	)
	_check(preserved.ok and not bool(preserved.converted) and preserved.data == voice, "matching voice Vorbis is preserved byte-identically")
	var stereo := _build_vorbis_identification(2, 44100)
	var rejected: Dictionary = AudioConversionScript.convert(
		AudioConversionScript.PRESET_VOICE_VORBIS_MONO_44100_PRESERVE,
		"voice.ogg",
		stereo
	)
	_check(not rejected.ok and str(rejected.error).contains("encoding is unavailable"), "nonmatching Vorbis fails with an explicit encoder boundary")


func _test_invalid_contracts() -> void:
	var wave := _build_pcm16_wave(PackedInt32Array([0]), 1, 22050)
	_check(not AudioConversionScript.convert("missing", "source.wav", wave).ok, "unknown presets fail closed")
	_check(not AudioConversionScript.convert(AudioConversionScript.PRESET_SE_PCM16_MONO_22050, "source.ogg", wave).ok, "container mismatch fails validation instead of guessing")
	_check(not AudioConversionScript.convert(AudioConversionScript.PRESET_SE_PCM16_MONO_22050, "source.wav", PackedByteArray([1, 2, 3])).ok, "truncated input fails before conversion")


func _test_atomic_publication() -> void:
	var output_path := TEST_ROOT.path_join("converted.wav")
	var output := _build_pcm16_wave(PackedInt32Array([-100, 100]), 1, 22050)
	var published: Dictionary = AudioConversionScript.publish_new_file(output_path, output)
	_check(published.ok and FileAccess.get_file_as_bytes(output_path) == output, "converted audio publishes through a verified new file")
	_check(str(published.sha256) == _sha256(output), "published audio reports its verified fingerprint")
	var refused: Dictionary = AudioConversionScript.publish_new_file(output_path, PackedByteArray([1, 2, 3]))
	_check(not refused.ok and FileAccess.get_file_as_bytes(output_path) == output, "atomic publication refuses to overwrite an existing output")
	var invalid_path := TEST_ROOT.path_join("invalid.wav")
	var invalid: Dictionary = AudioConversionScript.publish_new_file(invalid_path, PackedByteArray([1, 2, 3]))
	_check(not invalid.ok and not FileAccess.file_exists(invalid_path), "atomic publication rejects invalid audio before creating a temporary output")
	var parent := ProjectSettings.globalize_path(TEST_ROOT)
	var residue := false
	var directory := DirAccess.open(parent)
	if directory != null:
		for filename in directory.get_files():
			if filename.contains(".tmp-"):
				residue = true
	_check(not residue, "audio conversion publication leaves no sibling temporary residue")


func _build_pcm16_wave(samples: PackedInt32Array, channels: int, sample_rate: int) -> PackedByteArray:
	var data_bytes := samples.size() * 2
	var wave := PackedByteArray()
	wave.resize(44 + data_bytes)
	SyntheticArc.write_ascii(wave, 0, "RIFF")
	wave.encode_u32(4, 36 + data_bytes)
	SyntheticArc.write_ascii(wave, 8, "WAVE")
	SyntheticArc.write_ascii(wave, 12, "fmt ")
	wave.encode_u32(16, 16)
	wave.encode_u16(20, 1)
	wave.encode_u16(22, channels)
	wave.encode_u32(24, sample_rate)
	wave.encode_u32(28, sample_rate * channels * 2)
	wave.encode_u16(32, channels * 2)
	wave.encode_u16(34, 16)
	SyntheticArc.write_ascii(wave, 36, "data")
	wave.encode_u32(40, data_bytes)
	for index in range(samples.size()):
		wave.encode_s16(44 + index * 2, samples[index])
	return wave


func _pcm16_samples(wave: PackedByteArray) -> PackedInt32Array:
	var samples := PackedInt32Array()
	for offset in range(44, wave.size(), 2):
		samples.append(wave.decode_s16(offset))
	return samples


func _build_vorbis_identification(channels: int, sample_rate: int) -> PackedByteArray:
	var packet := PackedByteArray()
	packet.resize(30)
	packet[0] = 1
	SyntheticArc.write_ascii(packet, 1, "vorbis")
	packet.encode_u32(7, 0)
	packet[11] = channels
	packet.encode_u32(12, sample_rate)
	packet[28] = 0xB8
	packet[29] = 1
	var page := PackedByteArray()
	page.resize(58)
	SyntheticArc.write_ascii(page, 0, "OggS")
	page[4] = 0
	page[5] = 0x02
	page.encode_u32(14, 7)
	page[26] = 1
	page[27] = 30
	for index in range(packet.size()):
		page[28 + index] = packet[index]
	return page


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


func _cleanup() -> void:
	var root := ProjectSettings.globalize_path(TEST_ROOT)
	if not DirAccess.dir_exists_absolute(root):
		return
	var directory := DirAccess.open(root)
	if directory != null:
		for filename in directory.get_files():
			DirAccess.remove_absolute(root.path_join(filename))
	DirAccess.remove_absolute(root)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: %s" % label)
	else:
		_failed = true
		push_error("  FAIL: %s" % label)
