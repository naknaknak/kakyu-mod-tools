extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const MesInstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const MesLibraryAuditScript := preload("res://content_core/mes_library_audit.gd")
const MesLibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const MesLibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_surface_dispatch_reachability_audit/v3"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const TEN_M_ENTRY := "10M.MES"
const TEN_M_SHA256 := "a4bbf9051afb2f8b06803c7f159164e389e64931720257c69f295cc40e23ea01"
const TEN_M_OWNER_INDEX := 59
const TEN_M_OWNER_START := 0x4A96
const TEN_M_OWNER_END := 0x4B09
const TEN_M_DISPATCH := 0x4AC7
# Core 0.316.0 (2026-09-13): the candidate at 0x4AC7 is the interior of the
# literal 2829 (0D 0B, little-endian) in the argument-slot write run
# at 0x4AC3..0x4ACB (slot 1 assigned a 16-bit literal) - a raw prefix, not an
# instruction - and the "return at 0x4AA6" the audit once recorded was the
# seventh byte of the name-insert call at 0x4A9F, read as command 0x00 under
# the separator framing. The all-zero run from entry 59 now proceeds through
# the following line labels to a DEF selection boundary.
const TEN_M_SHADOW_START := 0x4AC3
const TEN_M_SHADOW_END := 0x4ACB
const TEN_M_SHADOW_OP := "argument_slot_write_run"
const TEN_M_ISOLATED_STOP := 0x4CC1
const TEN_M_ISOLATED_STEPS := 57
# Core 0.377.0 (TD-56): command 0x09 writes `global_i32`, the storage token 0xF6
# reads, so the argument assignments on this path are sandbox writes. The route,
# stop offset and step count are unchanged; the isolated run's only change is the
# `global_i32[1]` argument its last command 0x09 assigned (`09 01 00 ...`,
# 2833 here), which the run leaves in the storage.
const TEN_M_ISOLATED_DIFF: Array = [
	{"storage": "global_i32", "bank": 0, "index": 1, "before": 0, "after": 2833},
]
const LIBRARY_ENTRY := "LIBLARY.LIB"
const LIBRARY_SHA256 := "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d"
const LIBRARY_ROUTINE := 20
const LIBRARY_BODY_START := 0x68
const LIBRARY_BODY_END := 0x11E
const LIBRARY_DISPATCH := 0xFD
const LIBRARY_PREDECESSOR := 0xE0
const LIBRARY_RETURN := 0x11D
const LIBRARY_MODE := 13
const LIBRARY_RECORD_HEX: Array[String] = [
	"0dff", "22ff", "f13c01ff", "f1420201e1ff", "f1780101e1ff", "00ff",
]
const LIBRARY_EVALUATED_ARGUMENTS: Array[int] = [13, 34, 316, 577, 375, 0]
const LIBRARY_REFRESH_ORIGIN: Array[int] = [0, 0]
const LIBRARY_REFRESH_EXTENT: Array[int] = [544, 60]


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_surface_dispatch_reachability.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(str(arguments[0])):
		push_error(reader.last_error)
		quit(1)
		return
	var failures: Array[String] = []
	var source_sha := reader.get_archive_fingerprint()
	if source_sha != ARCHIVE_SHA256:
		failures.append("Unexpected original mes.arc SHA-256: %s" % source_sha)
	if reader.get_entry_fingerprint(TEN_M_ENTRY) != TEN_M_SHA256:
		failures.append("10M.MES hash differs from the audited original.")
	if reader.get_entry_fingerprint(LIBRARY_ENTRY) != LIBRARY_SHA256:
		failures.append("LIBLARY.LIB hash differs from the audited original.")

	var parser := MesContainerScript.new()
	var ten_m := parser.parse(reader.read_entry(TEN_M_ENTRY), {"archive": "mes.arc", "entry": TEN_M_ENTRY})
	var library := parser.parse(reader.read_entry(LIBRARY_ENTRY), {"archive": "mes.arc", "entry": LIBRARY_ENTRY})
	if not ten_m.get("ok", false):
		failures.append("10M.MES container parse failed: %s" % str(ten_m.get("error", "invalid")))
	if not library.get("ok", false):
		failures.append("LIBLARY.LIB container parse failed: %s" % str(library.get("error", "invalid")))
	if not failures.is_empty():
		_finish(reader, source_sha, failures, {}, {})
		return

	var ten_m_report := _audit_ten_m(ten_m, failures)
	var library_report := _audit_library(library, failures)
	_finish(reader, source_sha, failures, ten_m_report, library_report)


func _audit_ten_m(document: Dictionary, failures: Array[String]) -> Dictionary:
	var offsets: Array = document.header.entry_offsets
	if (
		offsets.size() <= TEN_M_OWNER_INDEX + 1
		or int(offsets[TEN_M_OWNER_INDEX]) != TEN_M_OWNER_START
		or int(offsets[TEN_M_OWNER_INDEX + 1]) != TEN_M_OWNER_END
	):
		failures.append("10M.MES address-table ownership around 0x%X changed." % TEN_M_DISPATCH)
		return {}
	var code: PackedByteArray = document.bytecode
	var instruction := MesInstructionDecoderScript.new().decode_at_structural(
		code,
		TEN_M_DISPATCH,
		TEN_M_OWNER_END
	)
	if not instruction.get("ok", false) or str(instruction.get("op", "")) != "surface_dispatch_unresolved":
		failures.append("10M.MES unresolved dispatch no longer decodes at 0x%X." % TEN_M_DISPATCH)
	var route := _find_structural_route(code, offsets, TEN_M_DISPATCH, int(document.header.code_size))
	if route.get("reached", false) and not route.get("shadowed", false):
		failures.append("10M.MES 0x%X unexpectedly became reachable from an address-table intro." % TEN_M_DISPATCH)
	if (
		not route.get("shadowed", false)
		or int(route.get("shadowed_by_offset", -1)) != TEN_M_SHADOW_START
		or int(route.get("shadowed_by_end_offset", -1)) != TEN_M_SHADOW_END
		or str(route.get("shadowed_by_op", "")) != TEN_M_SHADOW_OP
	):
		failures.append("10M.MES 0x%X is no longer the interior of the argument-slot write at 0x%X." % [TEN_M_DISPATCH, TEN_M_SHADOW_START])

	var state := SandboxStateScript.new(1)
	var result := MesEventRunnerScript.new().run(
		code,
		TEN_M_OWNER_START,
		state,
		int(document.header.code_size),
		2000,
		{
			"address_table_offsets": offsets,
			"native_stream_policy": "skip_bounded",
			"native_record_policy": "omit_bounded",
		}
	)
	var execution_hits := _count_trace_hits(result.get("trace", []), TEN_M_DISPATCH, "surface_dispatch_omitted")
	if (
		str(result.get("status", "")) != "def_selection_boundary"
		or int(result.get("offset", -1)) != TEN_M_ISOLATED_STOP
		or result.get("trace", []).size() != TEN_M_ISOLATED_STEPS
		or execution_hits != 0
		or result.get("state_diff", []) != TEN_M_ISOLATED_DIFF
	):
		failures.append("10M.MES entry 59 isolated execution boundary changed (state diff %s)." % JSON.stringify(result.get("state_diff", [])))
	return {
		"owner_index": TEN_M_OWNER_INDEX,
		"owner_start": TEN_M_OWNER_START,
		"owner_end": TEN_M_OWNER_END,
		"dispatch_offset": TEN_M_DISPATCH,
		"structural_route": route.get("offsets", []),
		"structural_edge_kinds": route.get("edge_kinds", []),
		"shadowed_by_offset": int(route.get("shadowed_by_offset", -1)),
		"shadowed_by_end_offset": int(route.get("shadowed_by_end_offset", -1)),
		"shadowed_by_op": str(route.get("shadowed_by_op", "")),
		"shadowed_by_family": str(route.get("shadowed_by_family", "")),
		"all_zero_omit_status": str(result.get("status", "unknown")),
		"all_zero_stop_offset": int(result.get("offset", -1)),
		"all_zero_omit_hits": execution_hits,
		"all_zero_state_diff_count": result.get("state_diff", []).size(),
	}


func _audit_library(document: Dictionary, failures: Array[String]) -> Dictionary:
	var code: PackedByteArray = document.bytecode
	var index := MesLibraryIndexScript.new().build(code, int(document.header.code_size))
	if not index.get("ok", false):
		failures.append("LIBLARY.LIB index failed: %s" % str(index.get("error", "invalid")))
		return {}
	var routine: Dictionary = index.get("by_id", {}).get(LIBRARY_ROUTINE, {})
	if (
		int(routine.get("body_offset", -1)) != LIBRARY_BODY_START
		or int(routine.get("end_offset", -1)) != LIBRARY_BODY_END
	):
		failures.append("LIBLARY.LIB routine 20 bounds changed.")
		return {}
	var audit := MesLibraryAuditScript.new().audit(code, index, [LIBRARY_ROUTINE])
	if not audit.get("ok", false):
		failures.append("LIBLARY.LIB routine 20 structural audit failed: %s" % str(audit.get("error", "invalid")))
		return {}
	var dispatch_instruction := MesInstructionDecoderScript.new().decode_at_structural(
		code,
		LIBRARY_DISPATCH,
		LIBRARY_BODY_END
	)
	if (
		not dispatch_instruction.get("ok", false)
		or str(dispatch_instruction.get("op", "")) != "surface_display_refresh"
	):
		failures.append("LIBLARY.LIB routine 20 mode-13 dispatch no longer decodes at 0xFD.")
		return {}
	var dispatch_operand: Dictionary = dispatch_instruction.get("operands", [{}])[0]
	var dispatch_record_hex: Array[String] = []
	if (
		int(dispatch_operand.get("mode", -1)) != LIBRARY_MODE
		or int(dispatch_operand.get("record_count", -1)) != LIBRARY_RECORD_HEX.size()
	):
		failures.append("LIBLARY.LIB routine 20 mode/record count changed.")
	for expression in dispatch_operand.get("expressions", []):
		dispatch_record_hex.append(str((expression as Dictionary).get("raw_hex", "")))
	if dispatch_record_hex != LIBRARY_RECORD_HEX:
		failures.append("LIBLARY.LIB routine 20 typed-record expressions changed.")
	var flow: Dictionary = audit.routines[0].native_dispatch_flow
	var target_present := false
	for row in flow.get("instructions", []):
		if (
			int(row.get("source_offset", -1)) == LIBRARY_DISPATCH
			and str(row.get("op", "")) == "surface_display_refresh"
		):
			target_present = true
			break
	var predecessor_present := false
	var return_edge_present := false
	for edge in flow.get("edges", []):
		if int(edge.get("from_offset", -1)) == LIBRARY_PREDECESSOR and int(edge.get("to_offset", -1)) == LIBRARY_DISPATCH:
			predecessor_present = true
		if int(edge.get("from_offset", -1)) == LIBRARY_DISPATCH and int(edge.get("to_offset", -1)) == LIBRARY_RETURN:
			return_edge_present = true
	if not target_present or not predecessor_present or not return_edge_present:
		failures.append("LIBLARY.LIB routine 20 route 0xE0 -> 0xFD -> 0x11D changed.")

	var state := SandboxStateScript.new(1)
	var result := MesLibraryRunnerScript.new().run(code, index, LIBRARY_ROUTINE, state)
	var execution_hits := _count_trace_hits(result.get("trace", []), LIBRARY_DISPATCH, "surface_display_refresh_omitted")
	var evaluated_arguments: Array[int] = []
	for record in result.get("trace", []):
		if (
			int(record.get("source_offset", -1)) == LIBRARY_DISPATCH
			and str(record.get("effect", "")) == "surface_display_refresh_omitted"
		):
			for value in record.get("surface_arguments", []):
				evaluated_arguments.append(int(value))
			break
	if (
		str(result.get("status", "")) != "library_return"
		or execution_hits != 1
		or evaluated_arguments != LIBRARY_EVALUATED_ARGUMENTS
		or result.get("state_diff", []).size() != 12
	):
		failures.append("LIBLARY.LIB routine 20 all-zero execution evidence changed.")
	return {
		"routine_id": LIBRARY_ROUTINE,
		"body_start": LIBRARY_BODY_START,
		"body_end": LIBRARY_BODY_END,
		"dispatch_offset": LIBRARY_DISPATCH,
		"predecessor_offset": LIBRARY_PREDECESSOR,
		"return_offset": LIBRARY_RETURN,
		"structural_target_present": target_present,
		"mode": LIBRARY_MODE,
		"record_hex": dispatch_record_hex,
		"evaluated_arguments": evaluated_arguments,
		"refresh_origin": LIBRARY_REFRESH_ORIGIN,
		"refresh_extent": LIBRARY_REFRESH_EXTENT,
		"all_zero_status": str(result.get("status", "unknown")),
		"all_zero_hits": execution_hits,
		"all_zero_state_diff_count": result.get("state_diff", []).size(),
	}


func _find_structural_route(code: PackedByteArray, starts: Array, target: int, limit: int) -> Dictionary:
	var decoder := MesInstructionDecoderScript.new()
	var pending: Array[int] = []
	var roots := {}
	for untyped_start in starts:
		var start := int(untyped_start)
		if start < 0 or start >= limit or roots.has(start):
			continue
		roots[start] = true
		pending.append(start)
	var visited := {}
	var parents := {}
	while not pending.is_empty():
		var cursor: int = pending.pop_front()
		if cursor == target:
			return _reconstruct_route_from_any(target, parents, roots)
		if cursor < 0 or cursor >= limit or visited.has(cursor):
			continue
		visited[cursor] = true
		var instruction := decoder.decode_at_structural(code, cursor, limit)
		if not instruction.get("ok", false):
			continue
		var command_id := int(instruction.command_id)
		var dispatch_end := int(instruction.end_offset)
		if instruction.has("native_stream_probe"):
			var probe: Dictionary = instruction.native_stream_probe
			if int(probe.get("consumed_byte_count", 0)) > 0:
				dispatch_end = int(probe.get("probe_end_offset", dispatch_end))
		if cursor < target and dispatch_end > target:
			var shadow_route := _reconstruct_route_from_any(cursor, parents, roots)
			shadow_route["shadowed"] = true
			shadow_route["shadowed_by_offset"] = cursor
			shadow_route["shadowed_by_end_offset"] = dispatch_end
			shadow_route["shadowed_by_op"] = str(instruction.get("op", ""))
			shadow_route["shadowed_by_family"] = str(instruction.get("native_handler_family", ""))
			return shadow_route
		var successors: Array[Dictionary] = []
		match command_id:
			0x00:
				pass
			0x0B:
				successors.append({"offset": dispatch_end, "kind": "condition_true"})
				successors.append({"offset": int(instruction.operands[1].value), "kind": "condition_false"})
			0x0C:
				successors.append({"offset": int(instruction.operands[0].value), "kind": "continuation"})
			0x10:
				var target_bytes: Array = instruction.operands[1].value
				if target_bytes.size() == 4:
					successors.append({
						"offset": int(target_bytes[0]) | (int(target_bytes[1]) << 8) | (int(target_bytes[2]) << 16) | (int(target_bytes[3]) << 24),
						"kind": "definition_skip",
					})
			0x14:
				successors.append({"offset": int(instruction.operands[1].value), "kind": "bootstrap_transfer"})
			0x18:
				pass
			_:
				successors.append({"offset": dispatch_end, "kind": "fallthrough"})
		for successor in successors:
			var successor_offset := int(successor.offset)
			if successor_offset < 0 or successor_offset >= limit or visited.has(successor_offset):
				continue
			if not parents.has(successor_offset):
				parents[successor_offset] = {"offset": cursor, "kind": str(successor.kind)}
			pending.append(successor_offset)
	return {"reached": false, "offsets": [], "edge_kinds": []}


func _reconstruct_route_from_any(target: int, parents: Dictionary, roots: Dictionary) -> Dictionary:
	var cursor := target
	while parents.has(cursor):
		cursor = int((parents[cursor] as Dictionary).offset)
	if not roots.has(cursor):
		return {"reached": false, "offsets": [], "edge_kinds": []}
	return _reconstruct_route(cursor, target, parents)


func _reconstruct_route(start: int, target: int, parents: Dictionary) -> Dictionary:
	var offsets: Array[int] = [target]
	var edge_kinds: Array[String] = []
	var cursor := target
	while cursor != start:
		if not parents.has(cursor):
			return {"reached": false, "offsets": [], "edge_kinds": []}
		var parent: Dictionary = parents[cursor]
		edge_kinds.append(str(parent.kind))
		cursor = int(parent.offset)
		offsets.append(cursor)
	offsets.reverse()
	edge_kinds.reverse()
	return {"reached": true, "offsets": offsets, "edge_kinds": edge_kinds}


func _count_trace_hits(trace: Array, source_offset: int, effect: String) -> int:
	var count := 0
	for record in trace:
		if int(record.get("source_offset", -1)) == source_offset and str(record.get("effect", "")) == effect:
			count += 1
	return count


func _finish(
	reader,
	source_sha: String,
	failures: Array[String],
	ten_m_report: Dictionary,
	library_report: Dictionary
) -> void:
	if reader.get_archive_fingerprint() != source_sha:
		failures.append("Source mes.arc changed during surface-dispatch reachability audit.")
	reader.close()
	print("MES_SURFACE_DISPATCH_REACHABILITY schema=%s failures=%d source_unchanged=%s" % [
		SCHEMA,
		failures.size(),
		str(failures.find("Source mes.arc changed during surface-dispatch reachability audit.") < 0),
	])
	if not ten_m_report.is_empty():
		print("MES_SURFACE_DISPATCH_10M owner=%d:0x%X..0x%X target=0x%X indexed_route=%s edges=%s shadow=%s all_zero_status=%s stop=0x%X hits=%d state_diff=%d" % [
			int(ten_m_report.owner_index), int(ten_m_report.owner_start), int(ten_m_report.owner_end),
			int(ten_m_report.dispatch_offset), _format_hex_offsets(ten_m_report.structural_route),
			",".join(ten_m_report.structural_edge_kinds), _format_shadow(ten_m_report),
			str(ten_m_report.all_zero_omit_status), int(ten_m_report.all_zero_stop_offset),
			int(ten_m_report.all_zero_omit_hits), int(ten_m_report.all_zero_state_diff_count),
		])
	if not library_report.is_empty():
		print("MES_SURFACE_DISPATCH_LIBRARY routine=%d body=0x%X..0x%X route=0x%X->0x%X->0x%X mode=%d args=%s refresh=(%d,%d %dx%d) all_zero_status=%s hits=%d state_diff=%d" % [
			int(library_report.routine_id), int(library_report.body_start), int(library_report.body_end),
			int(library_report.predecessor_offset), int(library_report.dispatch_offset), int(library_report.return_offset),
			int(library_report.mode), str(library_report.evaluated_arguments),
			int(library_report.refresh_origin[0]), int(library_report.refresh_origin[1]),
			int(library_report.refresh_extent[0]), int(library_report.refresh_extent[1]),
			str(library_report.all_zero_status), int(library_report.all_zero_hits), int(library_report.all_zero_state_diff_count),
		])
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)


func _format_hex_offsets(offsets: Array) -> String:
	var labels: Array[String] = []
	for offset in offsets:
		labels.append("0x%X" % int(offset))
	return "->".join(labels)


func _format_shadow(report: Dictionary) -> String:
	var start := int(report.get("shadowed_by_offset", -1))
	if start < 0:
		return "none"
	return "0x%X..0x%X:%s:%s" % [
		start,
		int(report.get("shadowed_by_end_offset", -1)),
		str(report.get("shadowed_by_op", "")),
		str(report.get("shadowed_by_family", "")),
	]
