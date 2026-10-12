extends SceneTree

# Read-only archive-wide literal script-dispatch inventory.
#
# Walks every authoritative MES/LIB entry, decodes it through the verified
# Content Core record framing, and collects every literal script dispatch:
# command-0x0F nested calls and command-0x0E root-replacement handoffs. The
# result is the caller graph that bounds Event Player catalog completeness.
#
# The inventory is structural only. It reports which entries are dispatch
# targets and which are never dispatched by a literal record. It does not
# classify a callee as a playable event, a system script, a duplicate route or
# an unreachable route; those require per-entry evidence. Entries reached only
# through shared routines, registered definitions or the native host are
# expected in the never-dispatched set and are not unreachable.

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"

const EXPECTED_ENTRY_COUNT := 1016
const EXPECTED_DISPATCH_COUNT := 11124
const EXPECTED_NESTED_CALL_COUNT := 9875
const EXPECTED_ROOT_HANDOFF_COUNT := 1249
const EXPECTED_NAME_INSERT_COUNT := 80272
const EXPECTED_COMMAND_0E_TOTAL := 1249
const EXPECTED_CALLER_COUNT := 360
const EXPECTED_TARGET_COUNT := 1005
const EXPECTED_UNDISPATCHED_COUNT := 11
const EXPECTED_EVENT_NAMED_TARGETS := 130
const EXPECTED_EVENT_NAMED_UNDISPATCHED := 1

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty() or arguments.size() > 2:
		push_error("Usage: audit_mes_event_corpus_inventory.gd <ELFIMAGE-directory> [out.json]")
		quit(2)
		return
	var source_root := str(arguments[0]).replace("\\", "/")
	while source_root.ends_with("/"):
		source_root = source_root.substr(0, source_root.length() - 1)
	var reader := ArcReaderScript.new()
	if not reader.open(source_root + "/mes.arc"):
		push_error(reader.last_error)
		quit(1)
		return
	_check("authoritative mes.arc fingerprint", reader.get_archive_fingerprint() == ARCHIVE_SHA256)

	var parser := MesContainerScript.new()
	var analysis_builder := MesAnalysisScript.new()
	var archive_entries := {}
	var dispatches: Array[Dictionary] = []
	var entry_count := 0
	var command_0e_ops := {}
	var command_0f_total := 0
	var command_0f_nonliteral := 0
	var name_insert_total := 0

	for untyped_entry in reader.get_entries():
		var listed: Dictionary = untyped_entry
		var listed_name := str(listed.name)
		if listed_name.get_extension().to_lower() in ["mes", "lib"]:
			archive_entries[listed_name.to_upper()] = true

	for untyped_entry in reader.get_entries():
		var entry: Dictionary = untyped_entry
		var name := str(entry.name)
		if name.get_extension().to_lower() not in ["mes", "lib"]:
			continue
		entry_count += 1
		var document := parser.parse(reader.read_entry(name), {"entry": name})
		if not document.get("ok", false):
			_failures.append("%s container: %s" % [name, document.get("error", "failed")])
			continue
		var analysis := analysis_builder.build(document)
		if not analysis.get("ok", false):
			_failures.append("%s analysis: %s" % [name, analysis.get("error", "failed")])
			continue
		for untyped_instruction in analysis.get("instructions", []):
			var instruction: Dictionary = untyped_instruction
			var command_id := int(instruction.get("command_id", -1))
			var target := str(instruction.get("script_target", ""))
			if str(instruction.get("op", "")) == "protagonist_name_insert":
				name_insert_total += 1
			if command_id == 0x0E:
				var op_name := str(instruction.get("op", ""))
				command_0e_ops[op_name] = int(command_0e_ops.get(op_name, 0)) + 1
			elif command_id == 0x0F:
				command_0f_total += 1
				if target.is_empty():
					command_0f_nonliteral += 1
			if target.is_empty():
				continue
			dispatches.append({
				"caller_entry": name.to_upper(),
				"source_offset": int(instruction.get("source_offset", -1)),
				"end_offset": int(instruction.get("end_offset", -1)),
				"command_id": command_id,
				"op": str(instruction.get("op", "")),
				"target_entry": target.to_upper(),
			})
	reader.close()

	dispatches.sort_custom(_compare_dispatch)

	var callers := {}
	var targets := {}
	var by_op := {}
	for untyped_row in dispatches:
		var row: Dictionary = untyped_row
		by_op[str(row.op)] = int(by_op.get(str(row.op), 0)) + 1
		callers[str(row.caller_entry)] = int(callers.get(str(row.caller_entry), 0)) + 1
		targets[str(row.target_entry)] = int(targets.get(str(row.target_entry), 0)) + 1

	var missing_targets: Array[String] = []
	for target in targets.keys():
		if not archive_entries.has(str(target)):
			missing_targets.append(str(target))
	missing_targets.sort()

	var undispatched: Array[String] = []
	for stored_name in archive_entries.keys():
		if not targets.has(str(stored_name)):
			undispatched.append(str(stored_name))
	undispatched.sort()

	var event_named_targets := 0
	for target in targets.keys():
		if str(target).begins_with("EVENT"):
			event_named_targets += 1
	var event_named_undispatched: Array[String] = []
	for undispatched_name in undispatched:
		if undispatched_name.begins_with("EVENT"):
			event_named_undispatched.append(undispatched_name)

	_check("no decode failure", _failures.is_empty())
	_check("MES/LIB entry count", entry_count == EXPECTED_ENTRY_COUNT)
	_check("literal dispatch count", dispatches.size() == EXPECTED_DISPATCH_COUNT)
	_check("nested-call count", int(by_op.get("script_dispatch", 0)) == EXPECTED_NESTED_CALL_COUNT)
	_check("root-handoff count", int(by_op.get("script_handoff_marker", 0)) == EXPECTED_ROOT_HANDOFF_COUNT)
	_check("every command-0x0F record has a literal target", command_0f_nonliteral == 0)
	_check("command-0x0F total", command_0f_total == EXPECTED_NESTED_CALL_COUNT)
	_check("command-0x0E total", _sum(command_0e_ops) == EXPECTED_COMMAND_0E_TOTAL)
	# Core 0.316.0: the name insert is System.function[14] under command 0x0D,
	# so command 0x0E is the root handoff alone (docs/spec/mes/format_and_method.md,
	# "Command 0x0D is one system call").
	_check("command-0x0E is the root handoff alone", command_0e_ops.size() == 1)
	_check("name-insert count (command 0x0D, function 14)", name_insert_total == EXPECTED_NAME_INSERT_COUNT)
	_check("command-0x0E handoff count", int(command_0e_ops.get("script_handoff_marker", 0)) == EXPECTED_ROOT_HANDOFF_COUNT)
	_check("distinct caller count", callers.size() == EXPECTED_CALLER_COUNT)
	_check("distinct target count", targets.size() == EXPECTED_TARGET_COUNT)
	_check("every dispatch target exists in the archive", missing_targets.is_empty())
	_check("never-dispatched count", undispatched.size() == EXPECTED_UNDISPATCHED_COUNT)
	_check("target and never-dispatched sets partition the archive", targets.size() + undispatched.size() == entry_count)
	_check("EVENT-named dispatch targets", event_named_targets == EXPECTED_EVENT_NAMED_TARGETS)
	_check("EVENT-named never-dispatched", event_named_undispatched.size() == EXPECTED_EVENT_NAMED_UNDISPATCHED)

	var report := {
		"schema": "kakyu_mes_event_corpus_inventory/v1",
		"content_core_version": ContentCoreVersionScript.CORE_VERSION,
		"archive_sha256": ARCHIVE_SHA256,
		"entry_count": entry_count,
		"dispatch_count": dispatches.size(),
		"by_op": by_op,
		"command_0e_ops": command_0e_ops,
		"name_insert_count": name_insert_total,
		"caller_count": callers.size(),
		"target_count": targets.size(),
		"never_dispatched_count": undispatched.size(),
		"event_named_targets": event_named_targets,
		"event_named_never_dispatched": event_named_undispatched,
		"callers": callers,
		"targets": targets,
		"never_dispatched": undispatched,
		"dispatches": dispatches,
	}
	var fingerprint := JSON.stringify(report, "", false, true).sha256_text()
	if _failures.is_empty():
		_verify_classification(source_root, report)

	print("checks=%d failures=%d" % [_checks, _failures.size()])
	print("entries=%d dispatches=%d callers=%d targets=%d never_dispatched=%d" % [
		entry_count, dispatches.size(), callers.size(), targets.size(), undispatched.size()])
	print("by_op=%s" % JSON.stringify(by_op))
	print("command_0e_ops=%s" % JSON.stringify(command_0e_ops))
	print("event_named_targets=%d event_named_never_dispatched=%s" % [
		event_named_targets, JSON.stringify(event_named_undispatched)])
	print("report_sha256=%s" % fingerprint)
	for failure in _failures:
		print("FAILURE %s" % failure)

	if arguments.size() >= 2:
		report["report_sha256"] = fingerprint
		var file := FileAccess.open(str(arguments[1]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  ", false, true))
			file.close()
			print("wrote=%s" % arguments[1])
	quit(0 if _failures.is_empty() else 1)


func _verify_classification(source_root: String, report: Dictionary) -> void:
	var python := preload("res://tools/content_suite/validation_session.gd").find_python()
	var temporary := ProjectSettings.globalize_path("user://event-corpus-%d.json" % OS.get_process_id())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if python.is_empty() or file == null:
		_check("Python route classification is available", false)
		return
	file.store_string(JSON.stringify(report))
	file.close()
	var output: Array = []
	var exit_code := OS.execute(python, PackedStringArray([
		ProjectSettings.globalize_path("res://tools/classify_event_routes.py"),
		source_root.path_join("mes.arc"), temporary, "--catalog",
		ProjectSettings.globalize_path("res://config/event_catalog/original_events_v1.json"),
		"--naming",
		ProjectSettings.globalize_path("res://config/event_catalog/dispatch_naming_v1.json"),
		"--check", ProjectSettings.globalize_path("res://config/event_catalog/route_classification_v1.json")]), output, true, false)
	DirAccess.remove_absolute(temporary)
	_check("all route classifications reproduce against Python-audited originals", exit_code == 0)
	for line in output:
		print(str(line).strip_edges())


func _compare_dispatch(a: Dictionary, b: Dictionary) -> bool:
	if str(a.caller_entry) == str(b.caller_entry):
		return int(a.source_offset) < int(b.source_offset)
	return str(a.caller_entry) < str(b.caller_entry)


func _sum(counts: Dictionary) -> int:
	var total := 0
	for key in counts.keys():
		total += int(counts[key])
	return total


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append("check failed: %s" % label)
