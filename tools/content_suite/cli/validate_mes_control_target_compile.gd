extends "res://tools/content_suite/cli_script.gd"

const ReopenScript := preload("res://content_core/mes_control_target_compile_reopen.gd")


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("Usage: validate_mes_control_target_compile.gd <compiled.mes> <compile-audit.json>", 2)
		return
	var mes_file := FileAccess.open(arguments[0], FileAccess.READ)
	if mes_file == null:
		_fail("Could not open compiled control-target MES: %s" % FileAccess.get_open_error(), 2)
		return
	var payload := mes_file.get_buffer(mes_file.get_length())
	mes_file.close()
	var audit_file := FileAccess.open(arguments[1], FileAccess.READ)
	if audit_file == null:
		_fail("Could not open control-target compile audit: %s" % FileAccess.get_open_error(), 2)
		return
	var parsed = JSON.parse_string(audit_file.get_as_text())
	audit_file.close()
	if not parsed is Dictionary:
		_fail("MES control-target compile audit is not a JSON object.", 2)
		return
	var report: Dictionary = ReopenScript.new().audit(payload, parsed)
	if not report.ok:
		_fail(str(report.get("error", "MES control-target compile reopen failed.")), 1)
		return
	print(
		"MES_CONTROL_TARGET_REOPEN_PASS schema=", report.schema,
		" entry=", report.source_identity.entry,
		" bytes=", report.output.size,
		" entries=", report.output.entry_count,
		" nodes=", report.coverage.node_count,
		" patches=", report.target_relocation.patch_count,
		" branch=", report.target_relocation.branch_patch_count,
		" continuation=", report.target_relocation.continuation_patch_count,
		" definition_skip=", report.target_relocation.definition_skip_patch_count,
		" handoff_sha256=", report.phase1_4.handoff_sha256,
		" payload_sha256=", report.payload_sha256
	)
	quit(0)
