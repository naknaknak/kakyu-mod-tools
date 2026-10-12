extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const CalendarStateScript := preload("res://content_core/mes_calendar_state.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_calendar_state_audit/v1"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const START_ENTRY_SHA256 := "ba57bf666fbd9db9b3110f2bf1c70e80e11a35de00e82256aaaf35921c77038f"
const TABLE_SHA256 := "f21ee0fcb09e960046878e35ad0410aed88680f849ace471b713ef7a12525b4a"
const ROW_LENGTHS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: audit_mes_calendar_state.gd <mes.arc>")
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader.last_error)
		return
	var archive_before := reader.get_archive_fingerprint()
	var start_before := reader.get_entry_fingerprint("START.MES")
	if archive_before != ARCHIVE_SHA256 or start_before != START_ENTRY_SHA256:
		reader.close()
		_fail("Calendar state source hashes do not match the audited original set.")
		return
	var document := MesContainerScript.new().parse(
		reader.read_entry("START.MES"),
		{"archive": "mes.arc", "entry": "START.MES"}
	)
	var projection := CalendarStateScript.new().build(document)
	var state := SandboxStateScript.new(1)
	var applied := CalendarStateScript.new().apply_to_state(projection, state)
	var scanned_lengths: Array[int] = []
	if applied.get("ok", false):
		for month_index in range(12):
			state.write_value("state_u16", 25, 0x24A0 + month_index * 32)
			var cursor := 0
			while cursor < 32 and state.read_value("banked_u8", cursor, 25) != 15:
				cursor += 1
			scanned_lengths.append(cursor)
	var archive_after := reader.get_archive_fingerprint()
	var start_after := reader.get_entry_fingerprint("START.MES")
	reader.close()
	if (
		not document.get("ok", false)
		or not projection.get("ok", false)
		or str(projection.get("schema", "")) != "kakyu_mes_calendar_state/v1"
		or str(projection.get("table_sha256", "")) != TABLE_SHA256
		or int(projection.get("native_relative_base", -1)) != 0x24A0
		or projection.get("row_lengths", []) != ROW_LENGTHS
		or not applied.get("ok", false)
		or scanned_lengths != ROW_LENGTHS
		or archive_after != archive_before
		or start_after != start_before
	):
		_fail(
			"Original calendar state contract changed: projection=%s applied=%s scanned=%s archive_unchanged=%s entry_unchanged=%s"
			% [str(projection), str(applied), str(scanned_lengths), str(archive_after == archive_before), str(start_after == start_before)]
		)
		return
	print(
		"MES_CALENDAR_STATE schema=%s projection=%s base=0x%X rows=%s sentinel=15 table_sha256=%s source_unchanged=true"
		% [SCHEMA, str(projection.schema), int(projection.native_relative_base), str(scanned_lengths), str(projection.table_sha256)]
	)
	quit(0)
