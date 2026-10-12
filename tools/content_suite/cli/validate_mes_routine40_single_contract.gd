extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const ChoiceContractScript := preload("res://content_core/mes_routine40_choice_contract.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const ENTRY := "A_DATE3.MES"
const ENTRY_SHA256 := "18454745f1dc6646aa5ed43d4221fdb4af3914951a14a3c79c7ee9aef171e086"
const ROUTE_START := 0x3410
const ROUTINE40_BOUNDARY := 0x345A
const ROUTINE40_RESUME := 0x345F
const RESULT_BRANCH := 0x347D
const OPTION_ENTRY := 0x348C
const FALLBACK_ENTRY := 0x4195


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <mes.arc>")
		return
	var reader := ArcReaderScript.new()
	if not reader.open(ProjectSettings.globalize_path(str(arguments[0]))):
		_fail(reader.last_error)
		return
	var before_archive := reader.get_archive_fingerprint()
	if before_archive != ARCHIVE_SHA256 or reader.get_entry_fingerprint(ENTRY) != ENTRY_SHA256:
		reader.close()
		_fail("Configured archive does not match the audited A_DATE3 source.")
		return
	var document := MesContainerScript.new().parse(
		reader.read_entry(ENTRY),
		{"archive": "mes.arc", "entry": ENTRY, "resolved_source": "original_arc"}
	)
	if not document.get("ok", false):
		reader.close()
		_fail("A_DATE3.MES failed to parse.")
		return
	var runner := EventRunnerScript.new()
	var state := SandboxStateScript.new(1)
	var boundary: Dictionary = runner.run(
		document.bytecode, ROUTE_START, state, int(document.header.code_size)
	)
	var contract: Dictionary = ChoiceContractScript.new().build(
		document.bytecode,
		int(document.header.code_size),
		boundary,
		{
			"archive": "mes.arc",
			"entry": ENTRY,
			"entry_sha256": ENTRY_SHA256,
			"resolved_source": "original_arc",
		}
	)
	if (
		str(boundary.get("status", "")) != "def_selection_boundary"
		or int(boundary.get("offset", -1)) != ROUTINE40_BOUNDARY
		or not contract.get("ok", false)
		or str(contract.get("schema", "")) != ContentCoreVersionScript.MES_ROUTINE40_CHOICE_CONTRACT_SCHEMA
		or int(contract.get("resume_offset", -1)) != ROUTINE40_RESUME
		or int(contract.get("definition_count", 0)) != 1
		or int((contract.get("definitions", []) as Array)[0].get("definition_id", -1)) != 2
		or contract.get("result_values", []) != [1]
		or contract.get("option_entry_offsets", []) != [OPTION_ENTRY]
		or int(contract.get("fallback_offset", -1)) != FALLBACK_ENTRY
		or int((contract.get("comparisons", []) as Array)[0].get("source_offset", -1)) != RESULT_BRANCH
	):
		reader.close()
		_fail("A_DATE3 single-row routine-40 contract does not match the audited branch.")
		return
	state.write_value("state_u16", 21, 1)
	var selected: Dictionary = runner.run(
		document.bytecode, ROUTINE40_RESUME, state, int(document.header.code_size), 16
	)
	var branch_fell_through := false
	var option_reached := false
	for untyped_trace in selected.get("trace", []):
		var trace: Dictionary = untyped_trace
		if int(trace.get("source_offset", -1)) == RESULT_BRANCH:
			branch_fell_through = str(trace.get("effect", "")) == "fallthrough"
		if int(trace.get("source_offset", -1)) == OPTION_ENTRY:
			option_reached = true
	if not branch_fell_through or not option_reached:
		reader.close()
		_fail("Stored A_DATE3 result-1 branch did not reach its sole option.")
		return
	if reader.get_archive_fingerprint() != before_archive:
		reader.close()
		_fail("Source archive changed during single-row contract validation.")
		return
	reader.close()
	print(
		"PASS: A_DATE3 routine40 schema=%s boundary=0x%X resume=0x%X definition_id=2 result=1 option=0x%X fallback=0x%X source_unchanged=true"
		% [str(contract.schema), ROUTINE40_BOUNDARY, ROUTINE40_RESUME, OPTION_ENTRY, FALLBACK_ENTRY]
	)
	quit(0)
