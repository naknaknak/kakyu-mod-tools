extends "res://tools/content_suite/cli_script.gd"

const ReopenScript := preload("res://content_core/mes_control_target_edit_compile_reopen.gd")
const MAX_MES_BYTES := 128 * 1024 * 1024
const MAX_AUDIT_BYTES := 32 * 1024 * 1024


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("Usage: validate_mes_control_target_edit_compile.gd <compiled.mes> <audit.json>", 2)
		return
	var payload := _read_bounded(ProjectSettings.globalize_path(str(arguments[0])), MAX_MES_BYTES)
	var audit_bytes := _read_bounded(ProjectSettings.globalize_path(str(arguments[1])), MAX_AUDIT_BYTES)
	if payload.is_empty() or audit_bytes.is_empty():
		_fail("MES control-target edit compile inputs cannot be read within their size limits.", 2)
		return
	var parsed = JSON.parse_string(audit_bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("MES control-target edit compile audit is not a JSON object.", 2)
		return
	var result := ReopenScript.new().audit(payload, parsed)
	if not result.ok:
		_fail(str(result.error), 1)
		return
	print(
		"MES_CONTROL_TARGET_EDIT_REOPEN_PASS ",
		"schema=", result.schema,
		" entry=", result.source_identity.entry,
		" kind=", result.edited_edge.reference_kind,
		" source=0x%X" % result.edited_edge.source_offset,
		" old_target=0x%X" % result.edited_edge.current_target_offset,
		" new_target=0x%X" % result.edited_edge.replacement_target_offset,
		" nodes=", result.coverage.node_count,
		" handoff_sha256=", result.phase1_4.handoff_sha256,
		" payload_sha256=", result.payload_sha256
	)
	quit(0)
