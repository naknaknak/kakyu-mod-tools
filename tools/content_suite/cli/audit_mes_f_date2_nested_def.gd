extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const MesStartupContextScript := preload("res://content_core/mes_startup_context.gd")
const RegisteredDefinitionRunnerScript := preload("res://content_core/mes_registered_definition_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const ENTRY_NAME := "F_DATE2.MES"
const ENTRY_SHA256 := "fe7dcb7d58b0974f19cdda918e3158860c1b230172640bec1a31cd933c0de07e"
const STARTUP_ENTRY := "DEF_MAIN.MES"
const STARTUP_SHA256 := "f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0"
const ANCHOR_INDEX := 187
const ANCHOR_OFFSET := 0x6768
const OUTER_DEFINITION_ID := 1
const BODY_OFFSET := 0x67BB
const TARGET_OFFSET := 0x67F1
const NESTED_DEFINITION_ID := 99
# Core 0.316.0 (2026-09-13): the two "omitted native presentations" this
# audit once recorded were the protagonist-name insert and a line marker
# skipped as bounded streams under the separator framing; the insert's
# projection is the third message.
const EXPECTED_EFFECT_COUNTS := {
	"definition_invoke_boundary": 1,
	"message": 2,
	"protagonist_name_insert": 1,
	"script_return": 2,
	"source_line_marker": 2,
}


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_f_date2_nested_def.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader.last_error)
		return
	var archive_before := reader.get_archive_fingerprint()
	if (
		archive_before != ARCHIVE_SHA256
		or reader.get_entry_fingerprint(ENTRY_NAME) != ENTRY_SHA256
		or reader.get_entry_fingerprint(STARTUP_ENTRY) != STARTUP_SHA256
	):
		_fail("F_DATE2/DEF_MAIN source hashes do not match the audited original set.")
		return
	var parser := MesContainerScript.new()
	var document := parser.parse(reader.read_entry(ENTRY_NAME), {"archive": "mes.arc", "entry": ENTRY_NAME})
	var startup_document := parser.parse(reader.read_entry(STARTUP_ENTRY), {"archive": "mes.arc", "entry": STARTUP_ENTRY})
	if not document.get("ok", false) or not startup_document.get("ok", false):
		_fail("F_DATE2 or DEF_MAIN container parsing failed.")
		return
	var entries: Array = document.get("entries", [])
	if entries.size() <= ANCHOR_INDEX or int(entries[ANCHOR_INDEX].offset) != ANCHOR_OFFSET:
		_fail("F_DATE2 address-table anchor changed.")
		return
	var startup_context := MesStartupContextScript.new().build(startup_document)
	var registered_definitions: Dictionary = startup_context.get("registered_definitions", {})
	if not startup_context.get("ok", false) or not registered_definitions.has(NESTED_DEFINITION_ID):
		_fail("DEF_MAIN did not expose the audited registered DEF 99 body.")
		return
	var state := SandboxStateScript.new(1)
	var selection := MesEventRunnerScript.new().run(
		document.bytecode,
		ANCHOR_OFFSET,
		state,
		int(document.header.code_size),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{"address_table_offsets": document.header.entry_offsets}
	)
	var outer_definition: Dictionary = {}
	for untyped_definition in selection.get("definitions", []):
		var definition: Dictionary = untyped_definition
		if int(definition.get("definition_id", -1)) == OUTER_DEFINITION_ID:
			outer_definition = definition
			break
	if (
		str(selection.get("status", "")) != "def_selection_boundary"
		or outer_definition.is_empty()
		or int(outer_definition.get("body_offset", -1)) != BODY_OFFSET
		or int(outer_definition.get("target_offset", -1)) != TARGET_OFFSET
	):
		_fail("F_DATE2 did not reproduce the audited outer DEF body.")
		return
	var before := state.snapshot()
	var result := RegisteredDefinitionRunnerScript.new().run(
		document.bytecode,
		BODY_OFFSET,
		state,
		TARGET_OFFSET,
		{
			"registered_definitions": registered_definitions,
			"native_stream_policy": "skip_bounded",
			"native_record_policy": "omit_bounded",
			"registered_definition_native_stream_policy": "skip_bounded",
			"registered_definition_native_record_policy": "omit_bounded",
			"address_table_offsets": document.header.entry_offsets,
		},
		10000,
		16,
		8
	)
	var effect_counts := {}
	for record in result.get("trace", []):
		var effect := str(record.get("effect", "unknown"))
		effect_counts[effect] = int(effect_counts.get(effect, 0)) + 1
	var storage_counts := {}
	for difference in result.get("state_diff", []):
		var storage := str(difference.get("storage", "unknown"))
		storage_counts[storage] = int(storage_counts.get(storage, 0)) + 1
	var archive_after := reader.get_archive_fingerprint()
	var calls: Array = result.get("registered_definition_calls", [])
	var external_source_rows := 0
	for record in result.get("trace", []):
		if (
			record.has("external_definition_id")
			and str(record.get("source_entry", "")) == "DEF_MAIN.MES"
		):
			external_source_rows += 1
	if (
		str(result.get("schema", "")) != "kakyu_mes_registered_definition_trace/v7"
		or not result.get("ok", false)
		or str(result.get("status", "")) != "script_return"
		or int(result.get("offset", -1)) != 0x67F0
		or (result.get("messages", []) as Array).size() != 3
		or calls.size() != 1
		or int(calls[0].get("definition_id", -1)) != NESTED_DEFINITION_ID
		or int(calls[0].get("caller_definition_id", -2)) != -1
		or int(calls[0].get("call_offset", -1)) != 0x67CD
		or int(calls[0].get("resume_offset", -1)) != 0x67D2
		or str(calls[0].get("source", "")) != "DEF_MAIN.MES:0x1518"
		or str(calls[0].get("source_entry", "")) != "DEF_MAIN.MES"
		or external_source_rows != 4
		or (result.get("trace", []) as Array).size() != 8
		or effect_counts != EXPECTED_EFFECT_COUNTS
		or not (result.get("state_diff", []) as Array).is_empty()
		or int(result.get("omitted_native_presentation_count", -1)) != 0
		or int(result.get("omitted_native_record_count", -1)) != 0
		or state.snapshot() != before
		or archive_after != archive_before
	):
		print("MES_F_DATE2_NESTED_DEF_DIAGNOSTIC status=%s stop=0x%X messages=%d calls=%d external_rows=%d trace=%d effects=%s omitted=%d records=%d diff=%d" % [
			str(result.get("status", "")), int(result.get("offset", -1)), (result.get("messages", []) as Array).size(), calls.size(),
			external_source_rows, (result.get("trace", []) as Array).size(), JSON.stringify(effect_counts),
			int(result.get("omitted_native_presentation_count", -1)), int(result.get("omitted_native_record_count", -1)),
			(result.get("state_diff", []) as Array).size(),
		])
		_fail("F_DATE2 nested DEF 99 composition changed from its audited bounded contract.")
		return
	print("MES_F_DATE2_NESTED_DEF schema=kakyu_mes_f_date2_nested_def_audit/v1 archive=%s entry=%s anchor=%d@0x%X outer_def=%d body=0x%X..0x%X status=%s stop=0x%X messages=%d calls=%d trace=%d effects=%s state_diff=%s archive_unchanged=%s sandbox_unchanged=%s" % [
		archive_before,
		ENTRY_NAME,
		ANCHOR_INDEX,
		ANCHOR_OFFSET,
		OUTER_DEFINITION_ID,
		BODY_OFFSET,
		TARGET_OFFSET,
		str(result.get("status", "unknown")),
		int(result.get("offset", -1)),
		(result.get("messages", []) as Array).size(),
		(result.get("registered_definition_calls", []) as Array).size(),
		(result.get("trace", []) as Array).size(),
		_format_counts(effect_counts),
		_format_counts(storage_counts),
		str(archive_before == archive_after),
		str(state.snapshot() == before),
	])
	quit(0)


func _format_counts(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var labels: Array[String] = []
	for key in keys:
		labels.append("%s:%d" % [str(key), int(counts[key])])
	return ",".join(labels) if not labels.is_empty() else "none"
