extends "res://tools/content_suite/cli_script.gd"

const ReopenScript := preload("res://content_core/mes_control_body_edit_compile_reopen.gd")
const MAX_MES_BYTES := 64 * 1024 * 1024
const MAX_AUDIT_BYTES := 32 * 1024 * 1024


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("Usage: validate_mes_control_body_edit_compile.gd <output.mes> <audit.json>", 2)
		return
	var payload := _read_bounded(ProjectSettings.globalize_path(str(arguments[0])).simplify_path(), MAX_MES_BYTES)
	var audit_bytes := _read_bounded(ProjectSettings.globalize_path(str(arguments[1])).simplify_path(), MAX_AUDIT_BYTES)
	if payload.is_empty() or audit_bytes.is_empty():
		_fail("MES control-body compile inputs cannot be read within their size limits.", 2)
		return
	var parsed = JSON.parse_string(audit_bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("MES control-body compile audit is not a JSON object.", 2)
		return
	var result := ReopenScript.new().audit(payload, parsed)
	if not result.ok:
		_fail(str(result.error), 1)
		return
	print(
		"MES_CONTROL_BODY_EDIT_COMPILE_GODOT_PASS ",
		"schema=", result.schema,
		" entry=", result.source_identity.entry,
		" kind=", result.operation.kind,
		" nodes=", result.coverage.node_count,
		" typed=", result.coverage.typed_node_count,
		" opaque=", result.coverage.opaque_node_count,
		" patches=", result.target_patch_verification.patch_count,
		" handoff_sha256=", result.phase1_4.handoff_sha256,
		" payload_sha256=", result.payload_sha256
	)
	quit(0)
