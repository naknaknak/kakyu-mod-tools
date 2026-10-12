extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const ChoiceContractScript := preload("res://content_core/mes_routine40_choice_contract.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const ENTRY := "DENSHA.MES"
const ENTRY_SHA256 := "d307dc55339981b0f31f84635e1e4b72408eaeca40ee11ae0c9ae066e85678c1"
const ROUTE_START := 0x7A52
const ROUTINE40_BOUNDARY := 0x7B02
const ROUTINE40_RESUME := 0x7B07


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
		_fail("Configured archive does not match the audited DENSHA source.")
		return
	var document := MesContainerScript.new().parse(
		reader.read_entry(ENTRY),
		{"archive": "mes.arc", "entry": ENTRY, "resolved_source": "original_arc"}
	)
	if not document.get("ok", false):
		reader.close()
		_fail("DENSHA.MES failed to parse.")
		return
	var runner := EventRunnerScript.new()
	var boundary_state := SandboxStateScript.new(1)
	var boundary: Dictionary = runner.run(
		document.bytecode, ROUTE_START, boundary_state, int(document.header.code_size)
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
		or int(contract.get("definition_count", 0)) != 3
		or str(contract.get("consumer_kind", "")) != "gated_one_based_state_u16_21_branch_matrix"
		or contract.get("gate", {}) != {
			"storage": "global_u8", "index": 2461, "values": [0, 1]
		}
		or (contract.get("variants", []) as Array).size() != 6
		or int(contract.get("fallback_offset", -1)) != 0x9EE9
	):
		reader.close()
		_fail("DENSHA routine-40 gated contract does not match the audited matrix.")
		return
	for untyped_variant in contract.variants:
		var variant: Dictionary = untyped_variant
		var state := SandboxStateScript.new(1)
		state.write_value("state_u16", 21, int(variant.result))
		state.write_value("global_u8", 2461, int(variant.gate_value))
		var selected: Dictionary = runner.run(
			document.bytecode,
			ROUTINE40_RESUME,
			state,
			int(document.header.code_size),
			32
		)
		var matched_branch := false
		var option_reached := false
		for untyped_trace in selected.get("trace", []):
			var trace: Dictionary = untyped_trace
			if int(trace.get("source_offset", -1)) == int(variant.source_offset):
				matched_branch = str(trace.get("effect", "")) == "fallthrough"
			if int(trace.get("source_offset", -1)) == int(variant.option_entry_offset):
				option_reached = true
		if not matched_branch or not option_reached:
			reader.close()
			_fail("Stored DENSHA matrix did not select result %d/gate %d (trace=%s)." % [
				int(variant.result), int(variant.gate_value), JSON.stringify(selected.get("trace", []))
			])
			return
	if reader.get_archive_fingerprint() != before_archive:
		reader.close()
		_fail("Source archive changed during gated contract validation.")
		return
	reader.close()
	print(
		"PASS: DENSHA routine40 schema=%s boundary=0x%X resume=0x%X definitions=3 gate=global_u8[2461]:0/1 variants=6 source_unchanged=true"
		% [str(contract.schema), ROUTINE40_BOUNDARY, ROUTINE40_RESUME]
	)
	quit(0)
