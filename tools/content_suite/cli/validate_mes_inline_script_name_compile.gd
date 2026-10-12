extends "res://tools/content_suite/cli_script.gd"

const ReopenScript := preload("res://content_core/mes_inline_script_name_compile_reopen.gd")
const MAX_AUDIT_BYTES := 32 * 1024 * 1024


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("Usage: validate_mes_inline_script_name_compile.gd <compiled.mes> <audit.json>", 2)
		return
	var mes_path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var audit_path := ProjectSettings.globalize_path(str(arguments[1])).simplify_path()
	var payload := _read_bounded(mes_path, 512 * 1024 * 1024)
	if payload.is_empty():
		_fail("Compiled inline script name MES cannot be read within its size limit.", 2)
		return
	var audit_bytes := _read_bounded(audit_path, MAX_AUDIT_BYTES)
	if audit_bytes.is_empty():
		_fail("MES inline script name compile audit cannot be read within its size limit.", 2)
		return
	var parsed = JSON.parse_string(audit_bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("MES inline script name compile audit is not a JSON object.", 2)
		return
	var result := ReopenScript.new().audit(payload, parsed)
	if not result.ok:
		_fail(str(result.error), 1)
		return
	print(
		"MES_INLINE_SCRIPT_NAME_COMPILE_GODOT_PASS ",
		"schema=", result.schema,
		" entry=", result.source_identity.entry,
		" offset=", result.edited_call.envelope_start,
		" name_offset=", result.edited_call.name_start,
		" selector=", result.edited_call.execution_selector,
		" boundary=", result.edited_call.reference_boundary,
		" source=", result.edited_call.source_name,
		" replacement=", result.edited_call.replacement_name,
		" nodes=", result.coverage.node_count,
		" payload_sha256=", result.payload_sha256
	)
	quit(0)
