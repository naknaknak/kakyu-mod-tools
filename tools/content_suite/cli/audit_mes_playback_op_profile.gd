extends SceneTree

# Read-only command-frequency profile used to derive the playback package
# schema.
#
# The playback format must encode what the event runner actually consumes, not
# everything the analyzer can represent. This tool measures which decoded
# commands occur, how often, and in how many entries, separately for the whole
# archive and for the EVENT-named subset identified by the event corpus
# inventory.
#
# It reports frequency only. It assigns no playback semantics and promotes no
# command meaning.

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"

# Command IDs the current event runner dispatches, read from
# content_core/mes_event_runner.gd. Anything outside this set that occurs in
# the corpus is a gap the playback schema must account for.
const RUNNER_DISPATCHED := [
	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
	0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13,
	0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1D, 0x1F,
]


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty() or arguments.size() > 2:
		push_error("Usage: audit_mes_playback_op_profile.gd <ELFIMAGE-directory> [out.json]")
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
	if reader.get_archive_fingerprint() != ARCHIVE_SHA256:
		reader.close()
		push_error("Authoritative mes.arc fingerprint changed.")
		quit(1)
		return

	var parser := MesContainerScript.new()
	var analysis_builder := MesAnalysisScript.new()
	var all_counts := {}
	var event_counts := {}
	var all_entry_presence := {}
	var op_names := {}
	var total_instructions := 0
	var event_instructions := 0
	var total_messages := 0
	var event_messages := 0
	var entry_count := 0
	var event_entry_count := 0
	var failures: Array[String] = []

	for untyped_entry in reader.get_entries():
		var entry: Dictionary = untyped_entry
		var name := str(entry.name)
		if name.get_extension().to_lower() not in ["mes", "lib"]:
			continue
		entry_count += 1
		var is_event := name.to_upper().begins_with("EVENT")
		if is_event:
			event_entry_count += 1
		var document := parser.parse(reader.read_entry(name), {"entry": name})
		if not document.get("ok", false):
			failures.append("%s container: %s" % [name, document.get("error", "failed")])
			continue
		var analysis := analysis_builder.build(document)
		if not analysis.get("ok", false):
			failures.append("%s analysis: %s" % [name, analysis.get("error", "failed")])
			continue
		var message_count := int(analysis.get("message_count", 0))
		total_messages += message_count
		if is_event:
			event_messages += message_count
		var seen_here := {}
		for untyped_instruction in analysis.get("instructions", []):
			var instruction: Dictionary = untyped_instruction
			var command_id := int(instruction.get("command_id", -1))
			total_instructions += 1
			all_counts[command_id] = int(all_counts.get(command_id, 0)) + 1
			seen_here[command_id] = true
			if not op_names.has(command_id):
				op_names[command_id] = str(instruction.get("op", ""))
			if is_event:
				event_instructions += 1
				event_counts[command_id] = int(event_counts.get(command_id, 0)) + 1
		for command_id in seen_here.keys():
			all_entry_presence[command_id] = int(all_entry_presence.get(command_id, 0)) + 1
	reader.close()

	var dispatched := {}
	for command_id in RUNNER_DISPATCHED:
		dispatched[command_id] = true

	var ids := all_counts.keys()
	ids.sort()
	var undispatched_present: Array[String] = []
	var dispatched_absent: Array[String] = []
	for command_id in ids:
		if not dispatched.has(command_id):
			undispatched_present.append("0x%02X" % int(command_id))
	for command_id in RUNNER_DISPATCHED:
		if not all_counts.has(command_id):
			dispatched_absent.append("0x%02X" % int(command_id))

	print("entries=%d event_named_entries=%d" % [entry_count, event_entry_count])
	print("instructions total=%d event_named=%d" % [total_instructions, event_instructions])
	print("messages total=%d event_named=%d" % [total_messages, event_messages])
	print("distinct_commands=%d" % ids.size())
	print("commands_present_but_not_dispatched=%s" % JSON.stringify(undispatched_present))
	print("commands_dispatched_but_absent=%s" % JSON.stringify(dispatched_absent))
	print("")
	print("cmd   op                              all_count  entries  event_count  runner")
	for command_id in ids:
		var all_n := int(all_counts.get(command_id, 0))
		var event_n := int(event_counts.get(command_id, 0))
		print("0x%02X  %-30s %9d %8d %12d  %s" % [
			int(command_id),
			str(op_names.get(command_id, "")).substr(0, 30),
			all_n,
			int(all_entry_presence.get(command_id, 0)),
			event_n,
			"yes" if dispatched.has(command_id) else "NO",
		])
	for failure in failures:
		print("FAILURE %s" % failure)

	if arguments.size() >= 2:
		var report := {
			"schema": "kakyu_mes_playback_op_profile/v1",
			"content_core_version": ContentCoreVersionScript.CORE_VERSION,
			"archive_sha256": ARCHIVE_SHA256,
			"entry_count": entry_count,
			"event_named_entry_count": event_entry_count,
			"instruction_count": total_instructions,
			"event_named_instruction_count": event_instructions,
			"message_count": total_messages,
			"event_named_message_count": event_messages,
			"op_names": op_names,
			"all_counts": all_counts,
			"event_counts": event_counts,
			"entry_presence": all_entry_presence,
			"commands_present_but_not_dispatched": undispatched_present,
			"commands_dispatched_but_absent": dispatched_absent,
		}
		var file := FileAccess.open(str(arguments[1]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  ", false, true))
			file.close()
			print("wrote=%s" % arguments[1])
	quit(0 if failures.is_empty() else 1)
