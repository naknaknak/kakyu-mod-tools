extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const ContextIndexScript := preload("res://content_core/mes_context_index.gd")
const LibraryAuditScript := preload("res://content_core/mes_library_audit.gd")
const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const LibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SOURCE_ENTRY := "LIBLARY.LIB"
const SOURCE_ENTRY_SHA256 := "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d"
const ROUTINE_ID := 25
const EXPECTED_INVOKE_OFFSETS := [0x1E22, 0x1F2E]
const EXPECTED_SELECTOR := 26
const DEF_ENTRY := "DEF_MAIN.MES"
const DEF_ENTRY_SHA256 := "f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0"
const DEF_REGISTRATION_OFFSET := 0x01FC


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <mes.arc>")
		return
	var reader := ArcReaderScript.new()
	if not reader.open(ProjectSettings.globalize_path(str(arguments[0]))):
		_fail(reader.last_error)
		return
	var archive_sha := reader.get_archive_fingerprint()
	if reader.get_entry_fingerprint(SOURCE_ENTRY) != SOURCE_ENTRY_SHA256:
		reader.close()
		_fail("LIBLARY.LIB hash does not match the audited original entry.")
		return
	var document := MesContainerScript.new().parse(
		reader.read_entry(SOURCE_ENTRY),
		{"archive": "mes.arc", "entry": SOURCE_ENTRY}
	)
	if not document.ok or int(document.header.entry_count) != 0:
		reader.close()
		_fail("LIBLARY.LIB container is invalid.")
		return
	if reader.get_entry_fingerprint(DEF_ENTRY) != DEF_ENTRY_SHA256:
		reader.close()
		_fail("DEF_MAIN.MES hash does not match the audited original entry.")
		return
	var def_document := MesContainerScript.new().parse(
		reader.read_entry(DEF_ENTRY),
		{"archive": "mes.arc", "entry": DEF_ENTRY}
	)
	var context_index := ContextIndexScript.new().build(def_document, [DEF_REGISTRATION_OFFSET])
	var def_matches: Array = context_index.get("by_id", {}).get(EXPECTED_SELECTOR, [])
	if not def_document.ok or def_matches.size() != 1:
		reader.close()
		_fail("DEF26 external body coordinates are unavailable.")
		return
	var index := LibraryIndexScript.new().build(document.bytecode, int(document.header.code_size))
	var audit := LibraryAuditScript.new().audit(document.bytecode, index, [ROUTINE_ID])
	if not index.ok or not audit.ok:
		reader.close()
		_fail("Routine-25 audit failed.")
		return
	var flow: Dictionary = audit.routines[0].native_dispatch_flow
	var invocation_offsets: Array[int] = []
	var selectors: Array[int] = []
	var matches_are_empty := true
	for untyped_invocation in flow.definition_invocations:
		var invocation: Dictionary = untyped_invocation
		invocation_offsets.append(int(invocation.source_offset))
		selectors.append(int(invocation.definition_id))
		matches_are_empty = matches_are_empty and (invocation.matching_registration_offsets as Array).is_empty()
	invocation_offsets.sort()
	selectors.sort()
	if (
		str(audit.schema) != "kakyu_mes_library_audit/v17"
		or str(flow.definition_link_scope) != "command14_context_map_coordinates_without_registration_dominance_or_lifetime"
		or not (flow.definition_registrations as Array).is_empty()
		or invocation_offsets != EXPECTED_INVOKE_OFFSETS
		or selectors != [EXPECTED_SELECTOR, EXPECTED_SELECTOR]
		or not matches_are_empty
	):
		reader.close()
		_fail("Routine-25 DEF graph coordinates differ from the audited original.")
		return
	var state := SandboxStateScript.new(1)
	var result := LibraryRunnerScript.new().run(
		document.bytecode,
		index,
		ROUTINE_ID,
		state,
		{"argument_slots": {1: 120}, "persistent_expression_stack": []}
	)
	if (
		result.ok
		or str(result.status) != "library_definition_invoke_boundary"
		or (result.trace as Array).size() != 3
		or int(result.trace[-1].source_offset) != EXPECTED_INVOKE_OFFSETS[0]
		or int(result.trace[-1].definition_id) != EXPECTED_SELECTOR
		or not (result.state_diff as Array).is_empty()
	):
		reader.close()
		_fail("Routine-25 bounded execution no longer stops at the first external DEF call.")
		return
	var registration: Dictionary = def_matches[0]
	var composed_state := SandboxStateScript.new(1)
	var composed := LibraryRunnerScript.new().run(
		document.bytecode,
		index,
		ROUTINE_ID,
		composed_state,
		{
			"argument_slots": {1: 120},
			"persistent_expression_stack": [],
			"registered_definitions": {EXPECTED_SELECTOR: {
				"code": def_document.bytecode,
				"body_offset": int(registration.body_offset),
				"end_offset": int(registration.skip_target),
				"source": "DEF_MAIN.MES:0x1FC",
			}},
		}
	)
	var external_rows := 0
	for record in composed.get("trace", []):
		if int(record.get("external_definition_id", -1)) == EXPECTED_SELECTOR:
			external_rows += 1
	var composed_diff: Array = composed.get("state_diff", [])
	if (
		not composed.ok
		or str(composed.status) != "library_return"
		or (composed.trace as Array).size() != 69
		or int(composed.trace[-1].source_offset) != 0x2018
		or external_rows != 54
		or int(composed.omitted_native_presentation_count) != 0
		or int(composed.get("omitted_native_record_count", -1)) != 36
		or composed_diff.size() != 1
		or str(composed_diff[0].storage) != "global_u8"
		or int(composed_diff[0].index) != 3000
		or int(composed_diff[0].before) != 0
		or int(composed_diff[0].after) != 4
	):
		reader.close()
		_fail(
			"Routine-25 explicit external DEF26 composition differs: status=%s rows=%d last=0x%X external=%d omitted_presentation=%d omitted_records=%d diff=%s"
			% [
				str(composed.get("status", "")),
				(composed.get("trace", []) as Array).size(),
				int((composed.get("trace", []) as Array)[-1].get("source_offset", -1)) if not (composed.get("trace", []) as Array).is_empty() else -1,
				external_rows,
				int(composed.get("omitted_native_presentation_count", -1)),
				int(composed.get("omitted_native_record_count", -1)),
				str(composed_diff),
			]
		)
		return
	var source_unchanged := reader.get_archive_fingerprint() == archive_sha
	reader.close()
	if not source_unchanged:
		_fail("Source mes.arc changed during read-only validation.")
		return
	print(
		"PASS: routine25 DEF selector=26 invoke_offsets=0x1E22/0x1F2E local_command14_registrations=none first_stop=0x1E22 steps=3 explicit_DEF26_composition=69_rows/54_external/0_presentation+36_record_effects_omitted return=0x2018 diff=global_u8[3000]:0->4 audit=v15 source_unchanged=true"
	)
	quit(0)
