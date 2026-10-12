extends "res://tools/content_suite/cli_script.gd"

const ReopenScript := preload("res://content_core/mes_message_compile_reopen.gd")


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("Usage: validate_mes_message_compile.gd <compiled.mes> <compile-audit.json>", 2)
		return
	var mes_file := FileAccess.open(arguments[0], FileAccess.READ)
	if mes_file == null:
		_fail("Could not open compiled MES: %s" % FileAccess.get_open_error())
		return
	var payload := mes_file.get_buffer(mes_file.get_length())
	mes_file.close()
	var audit_file := FileAccess.open(arguments[1], FileAccess.READ)
	if audit_file == null:
		_fail("Could not open message compile audit: %s" % FileAccess.get_open_error())
		return
	var parsed = JSON.parse_string(audit_file.get_as_text())
	audit_file.close()
	if not parsed is Dictionary:
		_fail("MES message compile audit is not a JSON object.")
		return
	var report: Dictionary = ReopenScript.new().audit(payload, parsed)
	if not report.get("ok", false):
		_fail(str(report.get("error", "MES message compile reopen failed.")))
		return
	print(
		"MES_MESSAGE_REOPEN_PASS schema=%s entry=%s bytes=%d entries=%d nodes=%d offset=0x%X handoff_sha256=%s payload_sha256=%s"
		% [
			str(report.schema),
			str(report.source_identity.entry),
			int(report.output.size),
			int(report.output.entry_count),
			int(report.coverage.node_count),
			int(report.edited_message.source_offset),
			str(report.phase1_4.handoff_sha256),
			str(report.payload_sha256),
		]
	)
	quit(0)
