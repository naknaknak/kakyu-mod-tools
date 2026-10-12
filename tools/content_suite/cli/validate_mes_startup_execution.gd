extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const AnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const RunnerScript := preload("res://content_core/mes_event_runner.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const ENTRY_NAME := "START.MES"
const ENTRY_SHA256 := "ba57bf666fbd9db9b3110f2bf1c70e80e11a35de00e82256aaaf35921c77038f"
const RECORDS := [
	{
		"offset": 0x014C,
		"end_offset": 0x0160,
		"selector": 2,
		"role": "library_bootstrap",
		"target": "LIBLARY.LIB",
	},
	{
		"offset": 0x0165,
		"end_offset": 0x017A,
		"selector": 3,
		"role": "definition_bootstrap",
		"target": "DEF_MAIN.MES",
	},
]


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: validate_mes_startup_execution.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		push_error(reader.last_error)
		quit(1)
		return
	var archive_before := reader.get_archive_fingerprint()
	var entry_before := reader.get_entry_fingerprint(ENTRY_NAME)
	if entry_before != ENTRY_SHA256:
		_fail(reader, "START.MES hash does not match the audited original entry.")
		return
	var document := MesContainerScript.new().parse(reader.read_entry(ENTRY_NAME), {"entry": ENTRY_NAME})
	if not document.ok:
		_fail(reader, str(document.error))
		return
	var decoder := DecoderScript.new()
	var runner := RunnerScript.new()
	for expected in RECORDS:
		var instruction := decoder.decode_at(
			document.bytecode,
			int(expected.offset),
			int(document.header.code_size)
		)
		if (
			not instruction.ok
			or str(instruction.schema) != ContentCoreVersionScript.MES_INSTRUCTION_SCHEMA
			or str(instruction.op) != "inline_script_execution"
			or int(instruction.end_offset) != int(expected.end_offset)
			or str(instruction.operands[0].name) != str(expected.target)
			or int(instruction.operands[0].execution_selector) != int(expected.selector)
			or str(instruction.operands[0].execution_role) != str(expected.role)
			or str(instruction.operands[0].native_context_restore) != "confirmed"
		):
			_fail(reader, "START.MES execution record changed at 0x%04X." % int(expected.offset))
			return
		var state := SandboxStateScript.new(1)
		var run := runner.run(
			document.bytecode,
			int(expected.offset),
			state,
			int(document.header.code_size),
			256
		)
		if (
			str(run.status) != "native_script_execution_boundary"
			or str(run.schema) != ContentCoreVersionScript.MES_EVENT_TRACE_SCHEMA
			or run.trace.size() != 1
			or str(run.trace[0].resource_name) != str(expected.target)
			or int(run.trace[0].next_offset) != int(expected.end_offset)
			or not run.state_diff.is_empty()
		):
			_fail(reader, "START.MES runner boundary changed at 0x%04X." % int(expected.offset))
			return
	var analysis := AnalysisScript.new().build(document)
	if str(analysis.get("schema", "")) != ContentCoreVersionScript.MES_ANALYSIS_SCHEMA:
		_fail(reader, "START.MES analysis schema changed.")
		return
	for expected in RECORDS:
		if not _has_reference(analysis.get("resource_references", []), expected):
			_fail(reader, "START.MES resource reference is missing at 0x%04X." % int(expected.offset))
			return
	var archive_after := reader.get_archive_fingerprint()
	var entry_after := reader.get_entry_fingerprint(ENTRY_NAME)
	reader.close()
	if archive_after != archive_before or entry_after != entry_before:
		push_error("Original mes.arc changed during START.MES validation.")
		quit(1)
		return
	print(
		"PASS: START.MES subcommand8 inline execution records "
		+ "LIBLARY.LIB@0x014C/selector2 -> DEF_MAIN.MES@0x0165/selector3; "
		+ "runner=fail_closed context_restore=confirmed source_unchanged=true"
	)
	quit(0)


func _has_reference(references: Array, expected: Dictionary) -> bool:
	for reference in references:
		if (
			int(reference.get("source_offset", -1)) == int(expected.offset)
			and str(reference.get("resource_kind", "")) == "mes_script"
			and str(reference.get("name", "")) == str(expected.target)
			and reference.get("archive_candidates", []) == ["mes.arc"]
			and int(reference.get("presentation_subcommand", -1)) == 8
			and int(reference.get("execution_selector", -1)) == int(expected.selector)
			and str(reference.get("execution_role", "")) == str(expected.role)
			and str(reference.get("native_context_restore", "")) == "confirmed"
			and str(reference.get("tool_execution_semantics", "")) == "not_executed"
		):
			return true
	return false


func _fail(reader: RefCounted, message: String) -> void:
	reader.call("close")
	push_error(message)
	quit(1)
