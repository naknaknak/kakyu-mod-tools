extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SOURCE_ENTRY := "EVENTD08.MES"
const ENTRY_SHA256 := "add5a481c407c863b646799d961033c5ce62da1b1874c227fd41d5685e7fd31c"
const INTRO_OFFSET := 0x0687
const ROUTINE_40_OFFSET := 0x0735
const DEFINITION_IDS := [0, 1, 2]
const DEFINITION_OFFSETS := [0x0687, 0x06C2, 0x06EB]
const DEFINITION_TARGETS := [0x06BD, 0x06E6, 0x072B]


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
	var sandbox := SandboxStateScript.new(1)
	var before := sandbox.snapshot()
	var result := MesEventRunnerScript.new().run(
		document.bytecode,
		INTRO_OFFSET,
		sandbox,
		int(document.header.code_size)
	)
	if not result.ok or str(result.status) != "def_selection_boundary" or int(result.offset) != ROUTINE_40_OFFSET:
		reader.close()
		_fail("EVENTD08 bounded DEF route did not stop at routine 40.")
		return
	var ids: Array[int] = []
	var offsets: Array[int] = []
	var targets: Array[int] = []
	for untyped_definition in result.get("definitions", []):
		var definition: Dictionary = untyped_definition
		ids.append(int(definition.definition_id))
		offsets.append(int(definition.source_offset))
		targets.append(int(definition.target_offset))
		if definition.messages.size() != 1 or (definition.messages[0].raw_bytes as PackedByteArray).is_empty():
			reader.close()
			_fail("EVENTD08 DEF body is not one non-empty lossless CP932 record.")
			return
	if ids != DEFINITION_IDS or offsets != DEFINITION_OFFSETS or targets != DEFINITION_TARGETS:
		reader.close()
		_fail("EVENTD08 DEF IDs, offsets, or targets differ from the audited route.")
		return
	if sandbox.diff(before).size() != 0 or result.has("resume_offset"):
		reader.close()
		_fail("Read-only DEF boundary mutated sandbox state or exposed a synthetic resume.")
		return
	if reader.get_archive_fingerprint() != archive_sha:
		reader.close()
		_fail("Source mes.arc changed during DEF route validation.")
		return
	reader.close()
	print(
		"PASS: EVENTD08 bounded DEF route definitions=3 routine40=0x735 selection=unresolved state_diff=0 source_archive_unchanged"
	)
	quit(0)
