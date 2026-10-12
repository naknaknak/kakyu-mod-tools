extends "res://tools/content_suite/cli_script.gd"

const ReopenScript := preload("res://content_core/mes_choice_option_compile_reopen.gd")
const MAX_AUDIT_BYTES := 32 * 1024 * 1024


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("Usage: validate_mes_choice_option_compile.gd <compiled.mes> <audit.json>", 2)
		return
	var mes_path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var audit_path := ProjectSettings.globalize_path(str(arguments[1])).simplify_path()
	var payload := _read_bounded(mes_path, 512 * 1024 * 1024)
	if payload.is_empty():
		_fail("Compiled choice-option MES cannot be read within its size limit.", 2)
		return
	var audit_bytes := _read_bounded(audit_path, MAX_AUDIT_BYTES)
	if audit_bytes.is_empty():
		_fail("MES choice-option compile audit cannot be read within its size limit.", 2)
		return
	var parsed = JSON.parse_string(audit_bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("MES choice-option compile audit is not a JSON object.", 2)
		return
	var result := ReopenScript.new().audit(payload, parsed)
	if not result.ok:
		_fail(str(result.error), 1)
		return
	print(
		"MES_CHOICE_OPTION_COMPILE_GODOT_PASS ",
		"schema=", result.schema,
		" entry=", result.source_identity.entry,
		" group=", result.edited_option.group_selector,
		" definition=", result.edited_option.definition_id,
		" payload=", result.edited_option.payload_start, "..", result.edited_option.payload_end,
		" routine40=", result.retained_contract.terminal_start,
		" resume=", result.retained_contract.physical_resume_start,
		" nodes=", result.coverage.node_count,
		" payload_sha256=", result.payload_sha256
	)
	quit(0)
