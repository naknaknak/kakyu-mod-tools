extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContextIndexScript := preload("res://content_core/mes_context_index.gd")
const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SOURCE_ENTRY := "DEF_MAIN.MES"
const SOURCE_ENTRY_SHA256 := "f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0"
const SELECTOR := 26
const REGISTRATION_OFFSET := 0x01FC
const BODY_OFFSET := 0x0203
const SKIP_TARGET := 0x042D


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
		_fail("DEF_MAIN.MES hash does not match the audited original entry.")
		return
	var document := MesContainerScript.new().parse(
		reader.read_entry(SOURCE_ENTRY),
		{"archive": "mes.arc", "entry": SOURCE_ENTRY}
	)
	if not document.ok:
		reader.close()
		_fail("DEF_MAIN.MES container is invalid.")
		return
	var index := ContextIndexScript.new().build(document, [REGISTRATION_OFFSET])
	var matches: Array = index.get("by_id", {}).get(SELECTOR, [])
	if (
		not index.ok
		or str(index.schema) != "kakyu_mes_context_index/v1"
		or matches.size() != 1
		or int(matches[0].registration_offset) != REGISTRATION_OFFSET
		or int(matches[0].body_offset) != BODY_OFFSET
		or int(matches[0].skip_target) != SKIP_TARGET
	):
		reader.close()
		_fail(
			"DEF 26 context registration coordinates differ: ok=%s schema=%s registrations=%s matches=%s rejected=%s."
			% [
				str(index.get("ok", false)),
				str(index.get("schema", "")),
				str(index.get("registrations", [])),
				str(matches),
				str(index.get("rejected", [])),
			]
		)
		return
	var state := SandboxStateScript.new(1)
	var result := EventRunnerScript.new().run(
		document.bytecode,
		BODY_OFFSET,
		state,
		SKIP_TARGET
	)
	if (
		result.ok
		or str(result.status) != "native_record_boundary"
		or int(result.offset) != 0x0208
		or (result.trace as Array).size() != 2
		or int(result.trace[-1].command_id) != 0x12
		or int(result.trace[-1].end_offset) != 0x0216
		or int(result.trace[-1].native_record_count) != 4
		or not bool(result.trace[-1].native_record_terminator_consumed)
		or not (result.messages as Array).is_empty()
		or not (result.state_diff as Array).is_empty()
	):
		reader.close()
		_fail("DEF 26 body no longer stops at its first typed-record boundary.")
		return
	var omitted_result := EventRunnerScript.new().run(
		document.bytecode,
		BODY_OFFSET,
		SandboxStateScript.new(1),
		SKIP_TARGET,
		EventRunnerScript.DEFAULT_MAX_STEPS,
		{"native_record_policy": "omit_bounded"}
	)
	var omitted_presentations := 0
	var omitted_records := 0
	var source_line_markers := 0
	for record in omitted_result.get("trace", []):
		match str(record.get("effect", "")):
			"native_presentation_omitted":
				omitted_presentations += 1
			"native_record_effects_omitted":
				omitted_records += 1
			"source_line_marker":
				source_line_markers += 1
	if (
		not omitted_result.ok
		or str(omitted_result.status) != "script_return"
		or int(omitted_result.offset) != 0x042C
		or (omitted_result.trace as Array).size() != 54
		or int(omitted_result.trace[-1].command_id) != 0x00
		or omitted_presentations != 0
		or omitted_records != 32
		or source_line_markers != 21
		or not (omitted_result.messages as Array).is_empty()
		or not (omitted_result.state_diff as Array).is_empty()
	):
		reader.close()
		_fail("DEF 26 record-effects-omitted body audit differs from the bounded original route.")
		return
	var source_unchanged := reader.get_archive_fingerprint() == archive_sha
	reader.close()
	if not source_unchanged:
		_fail("Source mes.arc changed during read-only validation.")
		return
	print(
		"PASS: DEF26 context=DEF_MAIN.MES registration=0x1FC body=0x203..0x42D first_stop=0x208:command12/4_records omitted_route=21_markers+32_record_dispatches+return@0x42C trace=54 messages=0 diff=none source_unchanged=true"
	)
	quit(0)
