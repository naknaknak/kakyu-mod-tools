extends "res://tools/content_suite/cli_script.gd"

const ReopenAuditScript := preload("res://content_core/mes_noop_compile_reopen.gd")


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("Usage: validate_mes_noop_compile.gd <compiled.mes> <compile-audit.json>", 2)
		return
	var mes_file := FileAccess.open(arguments[0], FileAccess.READ)
	if mes_file == null:
		_fail("Could not open compiled MES: %s" % FileAccess.get_open_error())
		return
	var payload := mes_file.get_buffer(mes_file.get_length())
	mes_file.close()
	var audit_file := FileAccess.open(arguments[1], FileAccess.READ)
	if audit_file == null:
		_fail("Could not open compile audit: %s" % FileAccess.get_open_error())
		return
	var parsed = JSON.parse_string(audit_file.get_as_text())
	audit_file.close()
	if not parsed is Dictionary:
		_fail("MES no-op compile audit is not a JSON object.")
		return
	var report: Dictionary = ReopenAuditScript.new().audit(payload, parsed)
	if not report.get("ok", false):
		_fail(str(report.get("error", "MES no-op reopen audit failed.")))
		return
	print(
		"MES_NOOP_REOPEN_PASS schema=%s entry=%s bytes=%d entries=%d nodes=%d opaque=%d handoff_sha256=%s payload_sha256=%s"
		% [
			str(report.schema),
			str(report.source_identity.entry),
			int(report.output.size),
			int(report.output.entry_count),
			int(report.coverage.node_count),
			int(report.coverage.opaque_node_count),
			str(report.phase1_4.handoff_sha256),
			str(report.payload_sha256),
		]
	)
	quit(0)
