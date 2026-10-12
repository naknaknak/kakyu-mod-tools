extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcWriterScript := preload("res://content_core/arc_writer.gd")
const AudioValidatorScript := preload("res://content_core/audio_entry_validator.gd")
const ContractValues := preload("res://content_core/contract_values.gd")


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 4:
		push_error(
			"Usage: godot --headless --path . --script "
			+ "res://tools/content_suite/cli/prepare_audio_swap_smoke_copy.gd -- "
			+ "<source-audio.arc> <target.OGG|WAV> <donor.OGG|WAV> <new-audio.arc>"
		)
		quit(2)
		return
	var source_path := str(arguments[0])
	var target_name := str(arguments[1]).to_upper()
	var donor_name := str(arguments[2]).to_upper()
	var output_path := str(arguments[3])
	if not _is_safe_audio_name(target_name) or not _is_safe_audio_name(donor_name):
		_fail("unsafe audio entry name", 2)
		return
	if target_name == donor_name:
		_fail("target and donor entries must differ", 2)
		return
	if target_name.get_extension() != donor_name.get_extension():
		_fail("target and donor containers must match", 2)
		return

	var reader := ArcReaderScript.new()
	if not reader.open(source_path):
		_fail("reader: %s" % reader.last_error)
		return
	var source_archive_sha := reader.get_archive_fingerprint()
	var target_entry := reader.get_entry(target_name)
	var donor_entry := reader.get_entry(donor_name)
	if target_entry.is_empty() or donor_entry.is_empty():
		reader.close()
		_fail("target or donor entry is missing")
		return
	var target_data := reader.read_entry(target_name)
	var donor_data := reader.read_entry(donor_name)
	if (
		(target_data.is_empty() or donor_data.is_empty())
		and not reader.last_error.is_empty()
	):
		var read_error := reader.last_error
		reader.close()
		_fail("entry read: %s" % read_error)
		return
	var target_validation := AudioValidatorScript.validate(target_name, target_data, target_data.size())
	var donor_validation := AudioValidatorScript.validate(donor_name, donor_data, donor_data.size())
	if not target_validation.ok or not donor_validation.ok:
		reader.close()
		_fail(
			"audio validation: target=%s donor=%s"
			% [str(target_validation.get("error", "ok")), str(donor_validation.get("error", "ok"))]
		)
		return
	if not _formats_match(target_validation, donor_validation):
		reader.close()
		_fail("target and donor codec/channel/sample-rate formats differ")
		return
	if target_data == donor_data:
		reader.close()
		_fail("target and donor payloads are byte-identical")
		return
	var target_sha := ContractValues.sha256(target_data)
	var donor_sha := ContractValues.sha256(donor_data)
	reader.close()

	var write_result := ArcWriterScript.new().write_repacked_copy(
		source_path,
		output_path,
		{target_name: donor_data}
	)
	if not write_result.ok:
		_fail("writer: %s" % write_result.error)
		return
	var rebuilt := ArcReaderScript.new()
	if not rebuilt.open(output_path):
		_fail("output reopen: %s" % rebuilt.last_error)
		return
	var rebuilt_target := rebuilt.read_entry(target_name)
	var rebuilt_donor := rebuilt.read_entry(donor_name)
	rebuilt.close()
	if rebuilt_target != donor_data or rebuilt_donor != donor_data:
		_fail("rebuilt target/donor payload verification failed")
		return
	if FileAccess.get_sha256(source_path) != source_archive_sha:
		_fail("source archive hash changed")
		return
	print(
		(
			"AUDIO_SWAP_PREPARE_PASS target=%s donor=%s codec=%s channels=%d rate=%d "
			+ "target_bytes=%d donor_bytes=%d target_sha256=%s donor_sha256=%s output_sha256=%s"
		) % [
			target_name,
			donor_name,
			str(donor_validation.codec),
			int(donor_validation.channels),
			int(donor_validation.sample_rate),
			target_data.size(),
			donor_data.size(),
			target_sha,
			donor_sha,
			str(write_result.sha256),
		]
	)
	quit(0)


func _formats_match(left: Dictionary, right: Dictionary) -> bool:
	if (
		str(left.get("container", "")) != str(right.get("container", ""))
		or str(left.get("codec", "")) != str(right.get("codec", ""))
		or int(left.get("channels", -1)) != int(right.get("channels", -1))
		or int(left.get("sample_rate", -1)) != int(right.get("sample_rate", -1))
	):
		return false
	if str(left.get("container", "")) == "wav":
		return int(left.get("bit_depth", -1)) == int(right.get("bit_depth", -1))
	return true


func _is_safe_audio_name(entry_name: String) -> bool:
	if entry_name.is_empty() or entry_name.contains("/") or entry_name.contains("\\"):
		return false
	if entry_name.get_extension().to_lower() not in ["ogg", "wav"]:
		return false
	for character in entry_name:
		if character not in "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_.":
			return false
	return true


func _fail(message: String, exit_code := 1) -> void:
	push_error("AUDIO_SWAP_PREPARE_FAIL %s" % message)
	quit(exit_code)
