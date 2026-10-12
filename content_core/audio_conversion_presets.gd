class_name KakyuAudioConversionPresets
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const AudioValidatorScript := preload("res://content_core/audio_entry_validator.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const PRESET_SE_PCM16_MONO_22050 := "original_se_pcm16_mono_22050"
const PRESET_BGM_PCM16_STEREO_44100 := "original_bgm_pcm16_stereo_44100"
const PRESET_VOICE_VORBIS_MONO_44100_PRESERVE := "original_voice_vorbis_mono_44100_preserve"

const MAX_INPUT_BYTES := 512 * 1024 * 1024
const MAX_OUTPUT_BYTES := 512 * 1024 * 1024


static func preset_for_target(archive_name: String, entry_name: String) -> Dictionary:
	var archive_key := archive_name.get_file().to_upper()
	var extension := entry_name.get_extension().to_lower()
	if archive_key == "SE.ARC" and extension == "wav":
		return describe(PRESET_SE_PCM16_MONO_22050)
	if archive_key == "BGM.ARC" and extension == "wav":
		return describe(PRESET_BGM_PCM16_STEREO_44100)
	if archive_key in ["VOICE.ARC", "TINA1.ARC", "TINA2.ARC"] and extension == "ogg":
		return describe(PRESET_VOICE_VORBIS_MONO_44100_PRESERVE)
	return _error("No deterministic audio conversion preset is defined for this target.")


static func describe(preset_id: String) -> Dictionary:
	match preset_id:
		PRESET_SE_PCM16_MONO_22050:
			return _preset(
				preset_id,
				"Original SE PCM16 mono 22050 Hz",
				"wav",
				"pcm",
				1,
				22050,
				16,
				true,
				"original_engine_compatible",
				"Original-engine replacement playback was verified for this PCM profile."
			)
		PRESET_BGM_PCM16_STEREO_44100:
			return _preset(
				preset_id,
				"Original BGM PCM16 stereo 44100 Hz",
				"wav",
				"pcm",
				2,
				44100,
				16,
				true,
				"original_engine_unverified",
				"This matches the original BGM corpus profile; replacement playback remains unverified."
			)
		PRESET_VOICE_VORBIS_MONO_44100_PRESERVE:
			return _preset(
				preset_id,
				"Original voice Vorbis mono 44100 Hz (preserve only)",
				"ogg",
				"vorbis",
				1,
				44100,
				0,
				false,
				"original_engine_unverified",
				"Matching Ogg Vorbis is retained byte-identically; no Vorbis encoder is bundled."
			)
	return _error("Unknown audio conversion preset: %s" % preset_id)


static func convert(preset_id: String, input_entry_name: String, input_data: PackedByteArray) -> Dictionary:
	var preset := describe(preset_id)
	if not preset.get("ok", false):
		return preset
	if input_data.size() > MAX_INPUT_BYTES:
		return _error("Audio conversion input exceeds the %d-byte safety limit." % MAX_INPUT_BYTES, preset_id)
	var validation := AudioValidatorScript.validate(input_entry_name, input_data, input_data.size())
	if not validation.get("ok", false):
		return _error(str(validation.get("error", "Audio input validation failed.")), preset_id)
	if str(validation.get("container", "")) != str(preset.container):
		return _error("Preset %s requires a %s input container." % [preset_id, str(preset.container).to_upper()], preset_id)
	if str(preset.container) == "ogg":
		return _preserve_vorbis(preset, validation, input_data)
	return _convert_pcm_wav(preset, validation, input_data)


static func publish_new_file(output_path: String, data: PackedByteArray) -> Dictionary:
	var output_absolute := ProjectSettings.globalize_path(output_path).simplify_path()
	if output_absolute.is_empty() or output_absolute.get_file().is_empty():
		return _error("Audio conversion output path is invalid.")
	if FileAccess.file_exists(output_absolute) or DirAccess.dir_exists_absolute(output_absolute):
		return _error("Audio conversion output already exists; choose a new file.")
	if data.size() > MAX_OUTPUT_BYTES:
		return _error("Audio conversion output exceeds the %d-byte safety limit." % MAX_OUTPUT_BYTES)
	var validation := AudioValidatorScript.validate(output_absolute.get_file(), data, data.size())
	if not validation.get("ok", false):
		return _error("Audio conversion output is invalid: %s" % str(validation.get("error", "validation failed")))
	var parent := output_absolute.get_base_dir()
	if parent.is_empty() or not DirAccess.dir_exists_absolute(parent):
		return _error("Audio conversion output directory does not exist.")
	var expected_sha := ContractValues.sha256(data)
	if expected_sha.is_empty():
		return _error("Converted audio could not be fingerprinted before publication.")
	var temporary := "%s.tmp-%s-%s" % [output_absolute, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _error("Could not create the temporary audio conversion output.")
	file.store_buffer(data)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return _error("Could not write the complete temporary audio conversion output.")
	if FileAccess.get_size(temporary) != data.size() or FileAccess.get_sha256(temporary) != expected_sha:
		DirAccess.remove_absolute(temporary)
		return _error("Temporary audio conversion output failed reopen verification.")
	if FileAccess.file_exists(output_absolute) or DirAccess.dir_exists_absolute(output_absolute):
		DirAccess.remove_absolute(temporary)
		return _error("Audio conversion output appeared before publication; existing data was preserved.")
	var rename_error := DirAccess.rename_absolute(temporary, output_absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary)
		return _error("Could not atomically publish converted audio (error %s)." % rename_error)
	if FileAccess.get_size(output_absolute) != data.size() or FileAccess.get_sha256(output_absolute) != expected_sha:
		DirAccess.remove_absolute(output_absolute)
		return _error("Published audio conversion output failed final verification and was removed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AUDIO_CONVERSION_SCHEMA,
		"path": output_absolute,
		"size": data.size(),
		"sha256": expected_sha,
	}


static func _preserve_vorbis(preset: Dictionary, validation: Dictionary, input_data: PackedByteArray) -> Dictionary:
	if int(validation.channels) != int(preset.channels) or int(validation.sample_rate) != int(preset.sample_rate):
		return _error(
			"Vorbis encoding is unavailable; input must already be %d channel(s) at %d Hz." % [
				int(preset.channels),
				int(preset.sample_rate),
			],
			str(preset.id)
		)
	return _success(preset, validation, validation, input_data, input_data, false, "already_matches_preserve_only_profile")


static func _convert_pcm_wav(preset: Dictionary, validation: Dictionary, input_data: PackedByteArray) -> Dictionary:
	if (
		int(validation.channels) == int(preset.channels)
		and int(validation.sample_rate) == int(preset.sample_rate)
		and int(validation.bit_depth) == int(preset.bit_depth)
	):
		return _success(preset, validation, validation, input_data, input_data, false, "already_matches_target_profile")
	var source_frames := int(validation.sample_frames)
	var source_rate := int(validation.sample_rate)
	var target_rate := int(preset.sample_rate)
	var target_channels := int(preset.channels)
	var target_frames := 0
	if source_frames > 0:
		target_frames = maxi(1, int((source_frames * target_rate + int(source_rate / 2)) / source_rate))
	var output_data_bytes := target_frames * target_channels * 2
	if output_data_bytes > MAX_OUTPUT_BYTES - 44:
		return _error("Converted PCM WAV would exceed the %d-byte safety limit." % MAX_OUTPUT_BYTES, str(preset.id))
	var output := _new_pcm16_wave(target_channels, target_rate, target_frames)
	var data_offset := int(validation.data_offset)
	for target_frame in range(target_frames):
		var source_position_numerator := target_frame * source_rate
		var source_frame := int(source_position_numerator / target_rate)
		var remainder := source_position_numerator % target_rate
		if source_frame >= source_frames - 1:
			source_frame = source_frames - 1
			remainder = 0
		var next_source_frame := mini(source_frame + 1, source_frames - 1)
		for target_channel in range(target_channels):
			var first := _mixed_source_sample(input_data, data_offset, source_frame, target_channel, target_channels, validation)
			var second := _mixed_source_sample(input_data, data_offset, next_source_frame, target_channel, target_channels, validation)
			var interpolated := first
			if remainder != 0:
				interpolated += _divide_round_nearest((second - first) * remainder, target_rate)
			var sample16 := clampi(_divide_round_nearest(interpolated, 65536), -32768, 32767)
			output.encode_s16(44 + (target_frame * target_channels + target_channel) * 2, sample16)
	var output_validation := AudioValidatorScript.validate("converted.wav", output, output.size())
	if not output_validation.get("ok", false):
		return _error("Converted PCM WAV failed reopen validation: %s" % str(output_validation.get("error", "unknown error")), str(preset.id))
	return _success(preset, validation, output_validation, input_data, output, true, "explicit_pcm_conversion")


static func _mixed_source_sample(
	data: PackedByteArray,
	data_offset: int,
	frame: int,
	target_channel: int,
	target_channels: int,
	validation: Dictionary
) -> int:
	var source_channels := int(validation.channels)
	if source_channels == target_channels:
		return _source_sample(data, data_offset, frame, target_channel, validation)
	if source_channels == 1:
		return _source_sample(data, data_offset, frame, 0, validation)
	var left := _source_sample(data, data_offset, frame, 0, validation)
	var right := _source_sample(data, data_offset, frame, 1, validation)
	return _divide_round_nearest(left + right, 2)


static func _source_sample(data: PackedByteArray, data_offset: int, frame: int, channel: int, validation: Dictionary) -> int:
	var bytes_per_sample := int(int(validation.bit_depth) / 8)
	var offset := data_offset + frame * int(validation.block_align) + channel * bytes_per_sample
	match int(validation.bit_depth):
		8:
			return (int(data[offset]) - 128) * 16777216
		16:
			return int(data.decode_s16(offset)) * 65536
		24:
			var value := int(data[offset]) | (int(data[offset + 1]) << 8) | (int(data[offset + 2]) << 16)
			if (value & 0x800000) != 0:
				value -= 0x1000000
			return value * 256
		32:
			return int(data.decode_s32(offset))
	return 0


static func _divide_round_nearest(numerator: int, denominator: int) -> int:
	if numerator >= 0:
		return int((numerator + int(denominator / 2)) / denominator)
	return -int((-numerator + int(denominator / 2)) / denominator)


static func _new_pcm16_wave(channels: int, sample_rate: int, frames: int) -> PackedByteArray:
	var data_bytes := frames * channels * 2
	var output := PackedByteArray()
	output.resize(44 + data_bytes)
	_write_ascii(output, 0, "RIFF")
	output.encode_u32(4, 36 + data_bytes)
	_write_ascii(output, 8, "WAVE")
	_write_ascii(output, 12, "fmt ")
	output.encode_u32(16, 16)
	output.encode_u16(20, 1)
	output.encode_u16(22, channels)
	output.encode_u32(24, sample_rate)
	output.encode_u32(28, sample_rate * channels * 2)
	output.encode_u16(32, channels * 2)
	output.encode_u16(34, 16)
	_write_ascii(output, 36, "data")
	output.encode_u32(40, data_bytes)
	return output


static func _success(
	preset: Dictionary,
	input_validation: Dictionary,
	output_validation: Dictionary,
	input_data: PackedByteArray,
	data: PackedByteArray,
	converted: bool,
	reason: String
) -> Dictionary:
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AUDIO_CONVERSION_SCHEMA,
		"preset": preset.duplicate(true),
		"preset_id": str(preset.id),
		"converted": converted,
		"reason": reason,
		"compatibility": str(preset.compatibility),
		"input": input_validation.duplicate(true),
		"output": output_validation.duplicate(true),
		"input_sha256": ContractValues.sha256(input_data),
		"output_sha256": ContractValues.sha256(data),
		"data": data,
	}


static func _preset(
	id: String,
	label: String,
	container: String,
	codec: String,
	channels: int,
	sample_rate: int,
	bit_depth: int,
	can_encode: bool,
	compatibility: String,
	evidence: String
) -> Dictionary:
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AUDIO_CONVERSION_SCHEMA,
		"id": id,
		"label": label,
		"container": container,
		"codec": codec,
		"channels": channels,
		"sample_rate": sample_rate,
		"bit_depth": bit_depth,
		"can_encode": can_encode,
		"compatibility": compatibility,
		"evidence": evidence,
	}


static func _write_ascii(target: PackedByteArray, offset: int, value: String) -> void:
	var bytes := value.to_ascii_buffer()
	for index in range(bytes.size()):
		target[offset + index] = bytes[index]


static func _error(message: String, preset_id := "") -> Dictionary:
	return {
		"ok": false,
		"schema": ContentCoreVersionScript.AUDIO_CONVERSION_SCHEMA,
		"preset_id": preset_id,
		"error": message,
	}
