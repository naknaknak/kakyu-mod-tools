extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const LibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SOURCE_ENTRY := "LIBLARY.LIB"
const ROUTINE_ID := 28


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
	var entry_sha := reader.get_entry_fingerprint(SOURCE_ENTRY)
	var document := MesContainerScript.new().parse(reader.read_entry(SOURCE_ENTRY), {"archive": "mes.arc", "entry": SOURCE_ENTRY})
	if not document.ok or int(document.header.entry_count) != 0:
		reader.close()
		_fail("LIBLARY.LIB container is invalid.")
		return
	var index := LibraryIndexScript.new().build(document.bytecode, int(document.header.code_size))
	if not index.ok:
		reader.close()
		_fail(str(index.error))
		return
	var reports: Array[String] = []
	for initial_stack in [[], [2]]:
		var state := SandboxStateScript.new(1)
		var result := LibraryRunnerScript.new().run(
			document.bytecode,
			index,
			ROUTINE_ID,
			state,
			{"persistent_expression_stack": initial_stack}
		)
		if not result.ok or str(result.status) != "library_return":
			reader.close()
			_fail("Routine 28 stack %s stopped: %s %s" % [str(initial_stack), str(result.status), str(result.get("error", ""))])
			return
		if (
			str(result.schema) != "kakyu_mes_library_trace/v10"
			or (result.trace as Array).size() != 8
			or not (result.calls as Array).is_empty()
			or int(result.omitted_native_presentation_count) != 1
			or not (result.state_diff as Array).is_empty()
			or result.persistent_expression_stack != initial_stack
		):
			reader.close()
			_fail("Routine 28 all-zero baseline changed for stack %s." % str(initial_stack))
			return
		reports.append(
			"stack=%s steps=%d calls=%s omitted=%d diff=%s final_stack=%s"
			% [
				str(initial_stack),
				(result.trace as Array).size(),
				_call_signature(result.calls),
				int(result.omitted_native_presentation_count),
				_diff_signature(result.state_diff),
				str(result.persistent_expression_stack),
			]
		)
	var source_unchanged := reader.get_archive_fingerprint() == archive_sha
	reader.close()
	if not source_unchanged:
		_fail("Source mes.arc changed during read-only validation.")
		return
	print("PASS: routine28 library runner schema=kakyu_mes_library_trace/v10 archive=%s entry=%s %s source_unchanged=true" % [archive_sha, entry_sha, " | ".join(reports)])
	quit(0)


func _call_signature(calls: Array) -> String:
	var counts := {}
	for untyped_call in calls:
		var call: Dictionary = untyped_call
		var routine_id := int(call.callee_routine_id)
		counts[routine_id] = int(counts.get(routine_id, 0)) + 1
	var keys: Array = counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%d:%d" % [int(key), int(counts[key])])
	return ",".join(parts) if not parts.is_empty() else "none"


func _diff_signature(diff: Array) -> String:
	var parts: Array[String] = []
	for untyped_change in diff:
		var change: Dictionary = untyped_change
		parts.append("%s[%d:%d]=%d" % [str(change.storage), int(change.bank), int(change.index), int(change.after)])
	return ",".join(parts) if not parts.is_empty() else "none"
