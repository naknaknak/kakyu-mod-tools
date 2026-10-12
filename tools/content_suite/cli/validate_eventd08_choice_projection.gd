extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SOURCE_ENTRY := "EVENTD08.MES"
const ENTRY_SHA256 := "add5a481c407c863b646799d961033c5ce62da1b1874c227fd41d5685e7fd31c"
const RESUME_OFFSET := 0x073A


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
		_fail("EVENTD08.MES hash does not match the audited original entry.")
		return
	var source := reader.read_entry(SOURCE_ENTRY)
	var document := MesContainerScript.new().parse(source, {"archive": "mes.arc", "entry": SOURCE_ENTRY})
	if not document.ok:
		reader.close()
		_fail("EVENTD08.MES parse failed: %s" % document.error)
		return

	var boundary_offsets: Array[int] = []
	var message_counts: Array[int] = []
	for selection in range(1, 4):
		var sandbox := SandboxStateScript.new(1)
		sandbox.write_value("state_u16", 21, selection)
		var before := sandbox.snapshot()
		var result := MesEventRunnerScript.new().run(
			document.bytecode,
			RESUME_OFFSET,
			sandbox,
			int(document.header.code_size)
		)
		if not result.ok or str(result.status) != "dialogue_boundary":
			reader.close()
			_fail("Choice %d did not reach a supported dialogue boundary: %s at 0x%X" % [selection, str(result.status), int(result.offset)])
			return
		if result.messages.is_empty():
			reader.close()
			_fail("Choice %d reached a dialogue boundary without original messages." % selection)
			return
		if sandbox.diff(before).size() != 0:
			reader.close()
			_fail("Choice %d mutated sandbox state before its first dialogue boundary." % selection)
			return
		boundary_offsets.append(int(result.offset))
		message_counts.append(result.messages.size())

	if reader.get_archive_fingerprint() != archive_sha:
		reader.close()
		_fail("Source mes.arc changed during EVENTD08 choice projection validation.")
		return
	reader.close()
	print(
		"PASS: EVENTD08 isolated choice projection resume=0x73A boundaries=%s messages=%s source_archive_unchanged"
		% [str(boundary_offsets), str(message_counts)]
	)
	quit(0)
