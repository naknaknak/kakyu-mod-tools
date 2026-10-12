extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesLibraryIndexScript := preload("res://content_core/mes_library_index.gd")

const SOURCE_ENTRY := "LIBLARY.LIB"
const ENTRY_SHA256 := "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d"
const EXPECTED_ROUTINE_IDS := [
	0, 1, 20, 2, 3, 4, 5, 6, 7, 31, 32, 8, 28, 21, 22, 10, 15, 17,
	23, 41, 9, 11, 12, 13, 14, 29, 30, 18, 19, 40, 24, 25, 26, 27, 33,
	34, 36, 35, 39, 37, 38, 42, 43,
]


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <mes.arc>")
		return
	var archive_path := ProjectSettings.globalize_path(str(arguments[0]))
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		_fail("mes.arc rejected: %s" % reader.last_error)
		return
	var archive_sha := reader.get_archive_fingerprint()
	if reader.get_entry_fingerprint(SOURCE_ENTRY) != ENTRY_SHA256:
		reader.close()
		_fail("LIBLARY.LIB hash does not match the audited original entry.")
		return
	var document := MesContainerScript.new().parse(
		reader.read_entry(SOURCE_ENTRY),
		{"archive": "mes.arc", "entry": SOURCE_ENTRY}
	)
	if not document.ok or int(document.header.entry_count) != 0:
		reader.close()
		_fail("LIBLARY.LIB did not retain its zero-entry-table container.")
		return
	var index := MesLibraryIndexScript.new().build(document.bytecode, int(document.header.code_size))
	if not index.ok:
		reader.close()
		_fail("LIBLARY.LIB index failed: %s" % index.error)
		return
	var routine_ids: Array[int] = []
	for routine in index.routines:
		routine_ids.append(int(routine.routine_id))
	if routine_ids != EXPECTED_ROUTINE_IDS:
		reader.close()
		_fail("LIBLARY.LIB routine registration order differs from the audited original.")
		return
	var routine_23: Dictionary = index.by_id[23]
	var routine_28: Dictionary = index.by_id[28]
	var routine_40: Dictionary = index.by_id[40]
	if (
		int(routine_23.registration_offset) != 0x05A1
		or int(routine_23.body_offset) != 0x05A8
		or int(routine_23.end_offset) != 0x0E18
		or int(routine_28.registration_offset) != 0x02C9
		or int(routine_28.body_offset) != 0x02D0
		or int(routine_28.end_offset) != 0x03EB
		or int(routine_40.registration_offset) != 0x1C87
		or int(routine_40.body_offset) != 0x1C8E
		or int(routine_40.end_offset) != 0x1D67
	):
		reader.close()
		_fail("LIBLARY.LIB routine 23/28/40 bounds differ from the audited original.")
		return
	if reader.get_archive_fingerprint() != archive_sha:
		reader.close()
		_fail("Source mes.arc changed during library-index validation.")
		return
	reader.close()
	print(
		"PASS: LIBLARY.LIB index registrations=43 routine23=0x5A8-0xE18 routine28=0x2D0-0x3EB routine40=0x1C8E-0x1D67 source_archive_unchanged"
	)
	quit(0)
