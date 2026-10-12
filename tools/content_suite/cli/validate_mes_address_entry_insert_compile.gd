extends "res://tools/content_suite/cli_script.gd"

const ReopenScript := preload("res://content_core/mes_address_entry_insert_compile_reopen.gd")


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("Usage: validate_mes_address_entry_insert_compile.gd <compiled.mes> <compile-audit.json>", 2)
		return
	var mes_file := FileAccess.open(arguments[0], FileAccess.READ)
	if mes_file == null:
		_fail("Could not open compiled address-entry MES: %s" % FileAccess.get_open_error(), 2)
		return
	var payload := mes_file.get_buffer(mes_file.get_length())
	mes_file.close()
	var audit_file := FileAccess.open(arguments[1], FileAccess.READ)
	if audit_file == null:
		_fail("Could not open address-entry compile audit: %s" % FileAccess.get_open_error(), 2)
		return
	var parsed = JSON.parse_string(audit_file.get_as_text())
	audit_file.close()
	if not parsed is Dictionary:
		_fail("MES address-entry compile audit is not a JSON object.", 2)
		return
	var report: Dictionary = ReopenScript.new().audit(payload, parsed)
	if not report.ok:
		_fail(str(report.get("error", "MES address-entry compile reopen failed.")), 1)
		return
	print(
		"MES_ADDRESS_ENTRY_INSERT_REOPEN_PASS schema=", report.schema,
		" entry=", report.source_identity.entry,
		" bytes=", report.output.size,
		" entries=", report.output.entry_count,
		" insert_index=", report.table_change.insertion_index,
		" target=0x%X" % report.table_change.inserted_offset,
		" target_region=", report.target.region,
		" nodes=", report.phase1_4.typed_node_count + report.phase1_4.opaque_node_count,
		" handoff_sha256=", report.phase1_4.handoff_sha256,
		" payload_sha256=", report.payload_sha256
	)
	quit(0)
