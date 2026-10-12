extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcWriterScript := preload("res://content_core/arc_writer.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const MesTextPatcherScript := preload("res://content_core/mes_text_patcher.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const MARKER_CHARACTER := "検"


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 4:
		push_error(
			"Usage: godot --headless --path . --script "
			+ "res://tools/content_suite/cli/prepare_mes_smoke_copy.gd -- "
			+ "<source-mes.arc> <entry.MES> <code-relative-offset> <new-mes.arc>"
		)
		quit(2)
		return
	var source_path := str(arguments[0])
	var entry_name := str(arguments[1]).to_upper()
	var offset_result := _parse_offset(str(arguments[2]))
	var output_path := str(arguments[3])
	if not _is_safe_mes_name(entry_name):
		_fail("unsafe MES entry name", 2)
		return
	if not offset_result.ok:
		_fail(str(offset_result.error), 2)
		return
	var source_offset := int(offset_result.value)

	var reader := ArcReaderScript.new()
	if not reader.open(source_path):
		_fail("reader: %s" % reader.last_error)
		return
	var source_archive_sha := reader.get_archive_fingerprint()
	var source_entry := reader.read_entry(entry_name)
	if source_entry.is_empty() and not reader.last_error.is_empty():
		var read_error := reader.last_error
		reader.close()
		_fail("entry read: %s" % read_error)
		return
	var source_entry_sha := ContractValues.sha256(source_entry)
	var document := MesContainerScript.new().parse(source_entry, {
		"archive": source_path.get_file(),
		"entry": entry_name,
	})
	if not document.ok:
		reader.close()
		_fail("MES parse: %s" % document.error)
		return
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.ok:
		reader.close()
		_fail("MES analysis: %s" % analysis.error)
		return
	var target := _find_message(analysis.messages, source_offset)
	if target.is_empty():
		reader.close()
		_fail("0x%X is not a strict-indexed message" % source_offset)
		return
	if not bool(target.get("native_stream_projection_match", false)):
		reader.close()
		_fail("0x%X does not match the EXE-confirmed native text boundary" % source_offset)
		return
	var raw_bytes: PackedByteArray = target.raw_bytes
	var marker_bytes := Cp932CodecScript.new().encode(MARKER_CHARACTER)
	if not marker_bytes.ok or marker_bytes.data.size() != 2 or raw_bytes.is_empty() or raw_bytes.size() % 2 != 0:
		reader.close()
		_fail("target must contain a nonempty even number of native double-byte CP932 bytes")
		return
	var marker_text := MARKER_CHARACTER.repeat(raw_bytes.size() / 2)
	var patch := MesTextPatcherScript.new().patch_equal_length(source_entry, [{
		"source_offset": source_offset,
		"raw_sha256": str(target.raw_sha256),
		"text": marker_text,
	}], true)
	if not patch.ok:
		reader.close()
		_fail("patch: %s" % patch.error)
		return
	var patched_entry: PackedByteArray = patch.data
	if patched_entry == source_entry or patched_entry.size() != source_entry.size():
		reader.close()
		_fail("verified patch did not produce one changed, equal-size entry")
		return
	reader.close()

	var write_result := ArcWriterScript.new().write_copy(
		source_path,
		output_path,
		{entry_name: patched_entry}
	)
	if not write_result.ok:
		_fail("writer: %s" % write_result.error)
		return
	var rebuilt := ArcReaderScript.new()
	if not rebuilt.open(output_path):
		_fail("output reopen: %s" % rebuilt.last_error)
		return
	var rebuilt_entry := rebuilt.read_entry(entry_name)
	rebuilt.close()
	if rebuilt_entry != patched_entry:
		_fail("rebuilt MES entry differs from the verified patch")
		return
	if FileAccess.get_sha256(source_path) != source_archive_sha:
		_fail("source archive hash changed")
		return
	print(
		(
			"MES_SMOKE_PREPARE_PASS entry=%s offset=0x%X bytes=%d "
			+ "source_entry_sha256=%s replacement_entry_sha256=%s output_sha256=%s"
		) % [
			entry_name,
			source_offset,
			raw_bytes.size(),
			source_entry_sha,
			ContractValues.sha256(patched_entry),
			str(write_result.sha256),
		]
	)
	quit(0)


func _parse_offset(text: String) -> Dictionary:
	var normalized := text.strip_edges().to_lower()
	if normalized.is_empty():
		return {"ok": false, "error": "MES offset is empty"}
	if normalized.begins_with("0x"):
		var digits := normalized.substr(2)
		if digits.is_empty() or not digits.is_valid_hex_number():
			return {"ok": false, "error": "MES offset is not hexadecimal: %s" % text}
		return {"ok": true, "value": digits.hex_to_int()}
	if not normalized.is_valid_int():
		return {"ok": false, "error": "MES offset is not an integer: %s" % text}
	var value := normalized.to_int()
	if value < 0:
		return {"ok": false, "error": "MES offset must be nonnegative"}
	return {"ok": true, "value": value}


func _is_safe_mes_name(entry_name: String) -> bool:
	if entry_name.is_empty() or entry_name.contains("/") or entry_name.contains("\\"):
		return false
	if entry_name.get_extension().to_lower() != "mes":
		return false
	for character in entry_name:
		if character not in "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_.":
			return false
	return true


func _find_message(messages: Array, source_offset: int) -> Dictionary:
	for untyped_message in messages:
		var message: Dictionary = untyped_message
		if int(message.source_offset) == source_offset:
			return message
	return {}


func _fail(message: String, exit_code := 1) -> void:
	push_error("MES_SMOKE_PREPARE_FAIL %s" % message)
	quit(exit_code)
