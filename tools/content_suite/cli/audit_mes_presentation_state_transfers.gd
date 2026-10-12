extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesInstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")

const SCHEMA := "kakyu_mes_presentation_state_transfer_audit/v1"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const EXPECTED_SCRIPT_COUNT := 1016
const EXPECTED_TRANSFERS := {
	"43C.MES:0x3B4C": "HTE",
	"43C.MES:0x4232": "HTE",
	"43C.MES:0x9EB2": "HTE",
	"43C.MES:0xA06E": "HTE",
	"OPEN.MES:0x250": "HTE",
}


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_presentation_state_transfers.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader, reader.last_error)
		return
	var archive_before := reader.get_archive_fingerprint()
	if archive_before != ARCHIVE_SHA256:
		_fail(reader, "Presentation state-transfer archive hash does not match the audited original set.")
		return
	var parser := MesContainerScript.new()
	var decoder := MesInstructionDecoderScript.new()
	var script_count := 0
	var transfers := {}
	var failures: Array[String] = []
	for entry in reader.get_entries():
		var entry_name := str(entry.name)
		if entry_name.get_extension().to_lower() not in ["mes", "lib"]:
			continue
		script_count += 1
		var document := parser.parse(
			reader.read_entry(entry_name),
			{"archive": "mes.arc", "entry": entry_name}
		)
		if not document.get("ok", false):
			failures.append("%s container parse failed" % entry_name)
			continue
		var code: PackedByteArray = document.get("bytecode", PackedByteArray())
		var limit := int(document.get("header", {}).get("code_size", 0))
		for offset in range(limit):
			if int(code[offset]) != 0x0D:
				continue
			var instruction: Dictionary = decoder.decode_at_structural(code, offset, limit)
			if not instruction.get("ok", false) or str(instruction.get("op", "")) != "named_state_transfer":
				continue
			var operand: Dictionary = instruction.get("operands", [{}])[0]
			var snapshot_ast: Dictionary = operand.get("snapshot_selector", {}).get("ast", {})
			var snapshot_index: Dictionary = snapshot_ast.get("index", {})
			var key := "%s:0x%X" % [entry_name, offset]
			if transfers.has(key):
				failures.append("duplicate state transfer at %s" % key)
				continue
			if (
				int(operand.get("presentation_subcommand", -1)) != 4
				or int(operand.get("transfer_selector", -1)) != 13
				or str(operand.get("native_copy_scope", "")) != "relative_offsets_only"
				or str(snapshot_ast.get("type", "")) != "state_ref"
				or str(snapshot_ast.get("storage", "")) != "state_u16"
				or str(snapshot_index.get("type", "")) != "literal"
				or int(snapshot_index.get("value", -1)) != 25
			):
				failures.append("state-transfer contract changed at %s" % key)
			transfers[key] = str(operand.get("mapping_string", ""))
	var archive_after := reader.get_archive_fingerprint()
	reader.close()
	if script_count != EXPECTED_SCRIPT_COUNT:
		failures.append("script count changed: %d" % script_count)
	if transfers != EXPECTED_TRANSFERS:
		failures.append("state-transfer coordinates changed: %s" % _format_transfers(transfers))
	if archive_after != archive_before:
		failures.append("Original mes.arc changed during presentation state-transfer audit.")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print(
		"MES_PRESENTATION_STATE_TRANSFERS schema=%s scripts=%d transfers=%d mappings=%s snapshot=state_u16[25] source_unchanged=true"
		% [SCHEMA, script_count, transfers.size(), _format_transfers(transfers)]
	)
	quit(0)


func _format_transfers(transfers: Dictionary) -> String:
	var keys: Array = transfers.keys()
	keys.sort()
	var values: Array[String] = []
	for key in keys:
		values.append("%s=%s" % [str(key), str(transfers[key])])
	return ",".join(values) if not values.is_empty() else "none"


func _fail(reader, message: String) -> void:
	reader.close()
	push_error(message)
	quit(1)
