extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")

const SCHEMA := "kakyu_mes_surface_operation_core_audit/v4"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const EXPECTED_ENTRY_COUNT := 1016
const EXPECTED_RAW_MARKERS := 11317
const EXPECTED_DISPATCH_CANDIDATES := 11317
const EXPECTED_OPERATIONS := 11315
const EXPECTED_DISPLAY_REFRESHES := 1
const EXPECTED_UNRESOLVED_CANDIDATES := 1
const EXPECTED_OPERATION_ENTRIES := 740
const EXPECTED_MODE_COUNTS := {0: 7273, 1: 3676, 2: 366}
const EXPECTED_RECORD_COUNTS := {5: 366, 8: 145, 9: 10804}
const EXPECTED_UNRESOLVED := [
	"10M.MES code+0x4AC7 records=0 mode=-1",
]
const EXPECTED_DISPLAY_REFRESH := "LIBLARY.LIB code+0xFD records=6 mode=13"


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_surface_operations.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(str(arguments[0])):
		push_error(reader.last_error)
		quit(1)
		return
	var source_sha := reader.get_archive_fingerprint()
	if source_sha != ARCHIVE_SHA256:
		push_error("Unexpected original mes.arc SHA-256: %s" % source_sha)
		reader.close()
		quit(1)
		return

	var parser := MesContainerScript.new()
	var decoder := DecoderScript.new()
	var entry_count := 0
	var raw_markers := 0
	var dispatch_candidates := 0
	var operations := 0
	var display_refreshes := 0
	var unresolved_candidates := 0
	var operation_entries := {}
	var mode_counts := {}
	var record_counts := {}
	var unresolved_samples: Array[String] = []
	var display_refresh_samples: Array[String] = []
	var unmatched_samples: Array[String] = []
	var failures: Array[String] = []
	for entry in reader.get_entries():
		if str(entry.name).get_extension().to_lower() not in ["mes", "lib"]:
			continue
		entry_count += 1
		var document := parser.parse(reader.read_entry(str(entry.name)), {
			"archive": "mes.arc",
			"entry": str(entry.name),
		})
		if not document.get("ok", false):
			failures.append("%s container: %s" % [str(entry.name), str(document.get("error", "invalid"))])
			continue
		var code: PackedByteArray = document.bytecode
		for offset in range(maxi(0, code.size() - 2)):
			if int(code[offset]) != 0x0D or int(code[offset + 1]) != 0x0B or int(code[offset + 2]) != 0xFF:
				continue
			raw_markers += 1
			var instruction: Dictionary = decoder.decode_at_structural(code, offset)
			if not instruction.get("ok", false):
				if unmatched_samples.size() < 12:
					unmatched_samples.append("%s code+0x%X" % [str(entry.name), offset])
				continue
			var operation := str(instruction.get("op", ""))
			if operation not in ["surface_operation", "surface_display_refresh", "surface_dispatch_unresolved"]:
				if unmatched_samples.size() < 12:
					unmatched_samples.append("%s code+0x%X" % [str(entry.name), offset])
				continue
			dispatch_candidates += 1
			if operation == "surface_dispatch_unresolved":
				unresolved_candidates += 1
				var unresolved_operand: Dictionary = instruction.get("operands", [{}])[0]
				unresolved_samples.append("%s code+0x%X records=%d mode=%d" % [
					str(entry.name),
					offset,
					int(unresolved_operand.get("record_count", -1)),
					int(unresolved_operand.get("mode", -1)),
				])
				continue
			if operation == "surface_display_refresh":
				display_refreshes += 1
				var refresh_operand: Dictionary = instruction.get("operands", [{}])[0]
				display_refresh_samples.append("%s code+0x%X records=%d mode=%d" % [
					str(entry.name),
					offset,
					int(refresh_operand.get("record_count", -1)),
					int(refresh_operand.get("mode", -1)),
				])
				continue
			var operand: Dictionary = instruction.get("operands", [{}])[0]
			var mode := int(operand.get("mode", -1))
			var record_count := int(operand.get("record_count", -1))
			operations += 1
			operation_entries[str(entry.name)] = true
			mode_counts[mode] = int(mode_counts.get(mode, 0)) + 1
			record_counts[record_count] = int(record_counts.get(record_count, 0)) + 1

	if entry_count != EXPECTED_ENTRY_COUNT:
		failures.append("MES/LIB entry count changed: %d" % entry_count)
	if raw_markers != EXPECTED_RAW_MARKERS:
		failures.append("raw surface marker count changed: %d" % raw_markers)
	if dispatch_candidates != EXPECTED_DISPATCH_CANDIDATES:
		failures.append("surface dispatch-candidate count changed: %d" % dispatch_candidates)
	if operations != EXPECTED_OPERATIONS:
		failures.append("decoded surface operation count changed: %d" % operations)
	if display_refreshes != EXPECTED_DISPLAY_REFRESHES:
		failures.append("decoded display refresh count changed: %d" % display_refreshes)
	if unresolved_candidates != EXPECTED_UNRESOLVED_CANDIDATES:
		failures.append("unresolved surface dispatch-candidate count changed: %d" % unresolved_candidates)
	if operation_entries.size() != EXPECTED_OPERATION_ENTRIES:
		failures.append("surface operation entry count changed: %d" % operation_entries.size())
	if mode_counts != EXPECTED_MODE_COUNTS:
		failures.append("surface mode counts changed: %s" % str(mode_counts))
	if record_counts != EXPECTED_RECORD_COUNTS:
		failures.append("surface record counts changed: %s" % str(record_counts))
	if unresolved_samples != EXPECTED_UNRESOLVED:
		failures.append("unresolved surface-dispatch coordinates changed: %s" % str(unresolved_samples))
	if display_refresh_samples != [EXPECTED_DISPLAY_REFRESH]:
		failures.append("display-refresh coordinates changed: %s" % str(display_refresh_samples))
	if not unmatched_samples.is_empty():
		failures.append("unmatched surface-prefix coordinates remain: %s" % str(unmatched_samples))
	if reader.get_archive_fingerprint() != source_sha:
		failures.append("source mes.arc changed during surface-operation audit")
	reader.close()

	print(
		"MES_SURFACE_OPERATION_CORE schema=%s entries=%d raw_markers=%d dispatch_candidates=%d operations=%d display_refreshes=%d unresolved_candidates=%d operation_entries=%d modes=%s records=%s unmatched=%d source_unchanged=%s"
		% [
			SCHEMA,
			entry_count,
			raw_markers,
			dispatch_candidates,
			operations,
			display_refreshes,
			unresolved_candidates,
			operation_entries.size(),
			_format_counts(mode_counts),
			_format_counts(record_counts),
			unmatched_samples.size(),
			str(failures.find("source mes.arc changed during surface-operation audit") < 0),
		]
	)
	for sample in unresolved_samples:
		print("MES_SURFACE_DISPATCH_UNRESOLVED ", sample)
	for sample in display_refresh_samples:
		print("MES_SURFACE_DISPLAY_REFRESH ", sample)
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)


func _format_counts(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var labels: Array[String] = []
	for key in keys:
		labels.append("%d:%d" % [int(key), int(counts[key])])
	return ",".join(labels)
