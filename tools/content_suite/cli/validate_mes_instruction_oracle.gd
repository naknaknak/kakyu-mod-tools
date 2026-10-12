extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2:
		push_error("Usage: godot --headless --path . --script res://tools/content_suite/cli/validate_mes_instruction_oracle.gd -- <mes.arc> <oracle.json>")
		quit(2)
		return
	var archive_path := arguments[0].replace("\\", "/")
	var oracle_path := arguments[1].replace("\\", "/")
	var oracle_result := _load_oracle(oracle_path)
	if not oracle_result.ok:
		push_error("MES_ORACLE_FAIL %s" % oracle_result.error)
		quit(2)
		return
	var oracle: Dictionary = oracle_result.value
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		push_error("MES_ORACLE_FAIL reader: %s" % reader.last_error)
		quit(2)
		return
	if str(oracle.get("archive_sha256", "")) != reader.get_archive_fingerprint():
		push_error("MES_ORACLE_FAIL archive SHA-256 does not match the oracle")
		reader.close()
		quit(2)
		return

	var parser := MesContainerScript.new()
	var decoder := DecoderScript.new()
	var checked := 0
	var failures := 0
	for untyped_entry in oracle.get("entries", []):
		if not untyped_entry is Dictionary:
			failures += 1
			continue
		var entry: Dictionary = untyped_entry
		var entry_name := str(entry.get("entry", ""))
		var data := reader.read_entry(entry_name)
		if data.is_empty() and int(reader.get_entry(entry_name).get("size", -1)) != 0:
			failures += 1
			push_error("MES_ORACLE_FAIL %s: %s" % [entry_name, reader.last_error])
			continue
		if reader.get_entry_fingerprint(entry_name) != str(entry.get("entry_sha256", "")):
			failures += 1
			push_error("MES_ORACLE_FAIL %s entry SHA-256 mismatch" % entry_name)
			continue
		var parsed := parser.parse(data, {"archive": archive_path.get_file(), "entry": entry_name})
		if not parsed.ok:
			failures += 1
			push_error("MES_ORACLE_FAIL %s: %s" % [entry_name, parsed.error])
			continue
		for untyped_expected in entry.get("instructions", []):
			var expected: Dictionary = untyped_expected
			var offset := int(expected.get("source_offset", -1))
			var actual := decoder.decode_at(parsed.bytecode, offset, int(parsed.header.code_size))
			checked += 1
			if not actual.ok:
				failures += 1
				push_error("MES_ORACLE_FAIL %s:0x%X decode: %s" % [entry_name, offset, actual.error])
				continue
			if (
				int(actual.end_offset) != int(expected.get("end_offset", -1))
				or int(actual.command_id) != int(expected.get("command_id", -1))
				or str(actual.raw_hex) != str(expected.get("raw_hex", ""))
			):
				failures += 1
				push_error(
					"MES_ORACLE_FAIL %s:0x%X expected end=0x%X op=0x%02X raw=%s got end=0x%X op=0x%02X raw=%s" % [
						entry_name,
						offset,
						int(expected.get("end_offset", -1)),
						int(expected.get("command_id", -1)),
						str(expected.get("raw_hex", "")),
						int(actual.end_offset),
						int(actual.command_id),
						str(actual.raw_hex),
					]
				)
				continue
			if int(actual.command_id) == 0x03:
				var actual_pairs: Array = actual.operands[1].pairs
				var continuations: Array[int] = []
				for pair in actual_pairs:
					continuations.append(int(pair.continuation))
				if (
					str(actual.op) != str(expected.get("op", ""))
					or int(actual.operands[0].value) != int(expected.get("write_start", -1))
					or actual_pairs.size() != int(expected.get("write_count", -1))
					or continuations != Array(expected.get("continuations", []), TYPE_INT, "", null)
				):
					failures += 1
					push_error("MES_ORACLE_FAIL %s:0x%X command 0x03 write-run operands differ" % [entry_name, offset])
			elif int(actual.command_id) in [0x07, 0x08]:
				var actual_pairs: Array = actual.operands[2].pairs
				var continuations: Array[int] = []
				for pair in actual_pairs:
					continuations.append(int(pair.continuation))
				if (
					str(actual.op) != str(expected.get("op", ""))
					or str(actual.operands[0].value.raw_hex) != str(expected.get("destination_raw_hex", ""))
					or int(actual.operands[1].value) != int(expected.get("write_bank", -1))
					or actual_pairs.size() != int(expected.get("write_count", -1))
					or continuations != Array(expected.get("continuations", []), TYPE_INT, "", null)
				):
					failures += 1
					push_error("MES_ORACLE_FAIL %s:0x%X command 0x%02X write-run operands differ" % [entry_name, offset, int(actual.command_id)])
	print("MES_ORACLE_SUMMARY entries=%d checked=%d failures=%d" % [oracle.get("entries", []).size(), checked, failures])
	reader.close()
	quit(1 if failures > 0 else 0)


func _load_oracle(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Oracle file does not exist: %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Could not open oracle file."}
	var value = JSON.parse_string(file.get_as_text())
	if not value is Dictionary:
		return {"ok": false, "error": "Oracle JSON root is not an object."}
	if value.get("schema", "") != "kakyu_mes_instruction_oracle/v1":
		return {"ok": false, "error": "Unsupported oracle schema."}
	return {"ok": true, "value": value}
