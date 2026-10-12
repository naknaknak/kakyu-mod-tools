extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesLibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const MesLibraryAuditScript := preload("res://content_core/mes_library_audit.gd")

const SOURCE_ENTRY := "LIBLARY.LIB"


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2:
		_fail("Usage: <mes.arc> [--summary] [--output <report.json>] <routine-id> [routine-id ...]")
		return
	var routine_ids: Array[int] = []
	var summary_only := false
	var output_path := ""
	var index := 1
	while index < arguments.size():
		var value := str(arguments[index])
		if value == "--summary":
			summary_only = true
			index += 1
			continue
		if value == "--output":
			if not output_path.is_empty() or index + 1 >= arguments.size():
				_fail("--output requires exactly one report path.")
				return
			output_path = ProjectSettings.globalize_path(str(arguments[index + 1]))
			index += 2
			continue
		if not value.is_valid_int() or value.to_int() < 0:
			_fail("Routine IDs must be non-negative decimal integers; options are --summary and --output <report.json>.")
			return
		routine_ids.append(value.to_int())
		index += 1
	if routine_ids.is_empty():
		_fail("At least one routine ID is required.")
		return
	var archive_path := ProjectSettings.globalize_path(str(arguments[0]))
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		_fail("mes.arc rejected: %s" % reader.last_error)
		return
	var archive_sha := reader.get_archive_fingerprint()
	var library_sha := reader.get_entry_fingerprint(SOURCE_ENTRY)
	if library_sha.is_empty():
		reader.close()
		_fail("LIBLARY.LIB is missing from the selected archive.")
		return
	var document := MesContainerScript.new().parse(
		reader.read_entry(SOURCE_ENTRY),
		{"archive": "mes.arc", "entry": SOURCE_ENTRY}
	)
	if not document.ok or int(document.header.entry_count) != 0:
		reader.close()
		_fail("LIBLARY.LIB is not a valid zero-entry-table MES container.")
		return
	var library_index := MesLibraryIndexScript.new().build(document.bytecode, int(document.header.code_size))
	if not library_index.ok:
		reader.close()
		_fail("LIBLARY.LIB index failed: %s" % str(library_index.error))
		return
	var audit := MesLibraryAuditScript.new().audit(document.bytecode, library_index, routine_ids)
	if not audit.ok:
		reader.close()
		_fail(str(audit.error))
		return
	var source_unchanged := reader.get_archive_fingerprint() == archive_sha
	reader.close()
	if not source_unchanged:
		_fail("Source mes.arc changed during the read-only audit.")
		return
	var report := {
		"ok": true,
		"schema": audit.schema,
		"archive_name": archive_path.get_file(),
		"archive_sha256": archive_sha,
		"entry": SOURCE_ENTRY,
		"entry_sha256": library_sha,
		"source_archive_unchanged": true,
		"routines": audit.routines,
	}
	if not output_path.is_empty():
		if output_path.simplify_path().to_lower() == archive_path.simplify_path().to_lower():
			_fail("The audit report must not replace the source mes.arc.")
			return
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		if output == null:
			_fail("Could not open audit report output: %s" % error_string(FileAccess.get_open_error()))
			return
		output.store_string(JSON.stringify(report, "\t", false) + "\n")
		output.close()
	if summary_only:
		_print_summary(report)
		quit(0)
		return
	print(JSON.stringify(report, "\t", false))
	quit(0)


func _print_summary(report: Dictionary) -> void:
	print(
		"PASS: %s %s archive=%s entry=%s source_unchanged=%s"
		% [
			str(report.schema),
			str(report.archive_name),
			str(report.archive_sha256),
			str(report.entry_sha256),
			str(report.source_archive_unchanged),
		]
	)
	for untyped_routine in report.routines:
		var routine: Dictionary = untyped_routine
		var strict: Dictionary = routine.strict
		var structural: Dictionary = routine.structural
		var effect: Dictionary = routine.linear_stack_effect
		var native_flow: Dictionary = routine.native_dispatch_flow
		var flow_commands := {}
		var flow_structural_only := 0
		var flow_calls := {}
		var flow_write_ranges := {}
		var shadowed_commands := {}
		var unreached_reasons := {}
		for untyped_row in native_flow.instructions:
			var row: Dictionary = untyped_row
			var command_id := int(row.command_id)
			flow_commands[command_id] = int(flow_commands.get(command_id, 0)) + 1
			if bool(row.structural_only):
				flow_structural_only += 1
			if row.has("routine_id"):
				var called_routine := int(row.routine_id)
				flow_calls[called_routine] = int(flow_calls.get(called_routine, 0)) + 1
			if row.has("write_storage") and row.has("write_start"):
				var write_signature := "%s[0x%X]x%d" % [
					str(row.write_storage),
					int(row.write_start),
					int(row.write_count),
				]
				flow_write_ranges[write_signature] = int(flow_write_ranges.get(write_signature, 0)) + 1
		for untyped_row in native_flow.get("shadowed_structural_instructions", []):
			var shadowed_row: Dictionary = untyped_row
			var shadowed_command_id := int(shadowed_row.get("command_id", -1))
			shadowed_commands[shadowed_command_id] = int(shadowed_commands.get(shadowed_command_id, 0)) + 1
		for untyped_row in native_flow.get("unreached_structural_instructions", []):
			var unreached_row: Dictionary = untyped_row
			var reason := str(unreached_row.get("reason", "unknown"))
			unreached_reasons[reason] = int(unreached_reasons.get(reason, 0)) + 1
		var native_boundaries: Array = routine.get("native_stream_boundaries", [])
		var first_native_boundary := -1
		if not native_boundaries.is_empty():
			first_native_boundary = int((native_boundaries[0] as Dictionary).source_offset)
		print(
			"routine=%d body=0x%X..0x%X strict=%d@0x%X complete=%s structural=%d@0x%X complete=%s stack_min=%d delta=%+d scope=%s return_segments=%d native_stream=%d@%s native_flow=%d edges=%d returns=%d boundaries=%d failures=%d complete=%s"
			% [
				int(routine.routine_id),
				int(routine.body_offset),
				int(routine.end_offset),
				int(strict.instruction_count),
				int(strict.decoded_end_offset),
				str(strict.complete),
				int(structural.instruction_count),
				int(structural.decoded_end_offset),
				str(structural.complete),
				int(effect.minimum_incoming),
				int(effect.net_delta),
				str(routine.linear_stack_effect_scope),
				(routine.return_delimited_segments as Array).size(),
				native_boundaries.size(),
				"0x%X" % first_native_boundary if first_native_boundary >= 0 else "none",
				int(native_flow.instruction_count),
				int(native_flow.edge_count),
				(native_flow.return_offsets as Array).size(),
				(native_flow.boundaries as Array).size(),
				(native_flow.failures as Array).size(),
				str(native_flow.complete),
			]
		)
		print(
			"routine=%d native_flow_commands=%s structural_only=%d native_spans=%d shadowed_stored_rows=%s unreached_reasons=%s calls=%s writes=%s"
			% [
				int(routine.routine_id),
				_format_command_counts(flow_commands),
				flow_structural_only,
				(native_flow.native_spans as Array).size(),
				_format_command_counts(shadowed_commands),
				_format_string_counts(unreached_reasons),
				_format_int_counts(flow_calls),
				_format_string_counts(flow_write_ranges),
			]
		)
		print(
			"routine=%d def_registrations=%s def_invocations=%s link_scope=%s"
			% [
				int(routine.routine_id),
				_format_definitions(native_flow.get("definition_registrations", []), false),
				_format_definitions(native_flow.get("definition_invocations", []), true),
				str(native_flow.get("definition_link_scope", "unavailable")),
			]
		)


func _format_command_counts(counts: Dictionary) -> String:
	if counts.is_empty():
		return "none"
	var keys: Array = counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("0x%02X:%d" % [int(key), int(counts[key])])
	return ",".join(parts)


func _format_definitions(records: Array, include_matches: bool) -> String:
	if records.is_empty():
		return "none"
	var parts: Array[String] = []
	var sorted_records := records.duplicate(true)
	sorted_records.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return int(left.get("source_offset", -1)) < int(right.get("source_offset", -1))
	)
	for untyped_record in sorted_records:
		var record: Dictionary = untyped_record
		var value := "%d@0x%X" % [int(record.get("definition_id", -1)), int(record.get("source_offset", -1))]
		if record.has("target_offset"):
			value += "->0x%X" % int(record.target_offset)
		if include_matches:
			var matches: Array = record.get("matching_registration_offsets", [])
			value += " matches=" + (",".join(matches.map(func(offset: int) -> String: return "0x%X" % offset)) if not matches.is_empty() else "none")
		parts.append(value)
	return ";".join(parts)


func _format_int_counts(counts: Dictionary) -> String:
	if counts.is_empty():
		return "none"
	var keys: Array = counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%d:%d" % [int(key), int(counts[key])])
	return ",".join(parts)


func _format_string_counts(counts: Dictionary) -> String:
	if counts.is_empty():
		return "none"
	var keys: Array = counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s:%d" % [str(key), int(counts[key])])
	return ",".join(parts)
