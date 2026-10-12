extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const AlignmentAuditScript := preload("res://content_core/mes_record_alignment_audit.gd")

const SCHEMA := "kakyu_mes_record_alignment_corpus/v1"
const SAMPLE_LIMIT := 24


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_record_alignment_corpus.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		push_error(reader.last_error)
		quit(1)
		return
	var source_sha := reader.get_archive_fingerprint()
	var parser := MesContainerScript.new()
	var auditor := AlignmentAuditScript.new()
	var entry_count := 0
	var region_count := 0
	var code_bytes := 0
	var framed_bytes := 0
	var instruction_count := 0
	var instruction_bytes := 0
	var compound_record_count := 0
	var compound_record_bytes := 0
	var compound_families := {}
	var compound_family_bytes := {}
	var compound_family_entries := {}
	var opaque_boundary_count := 0
	var opaque_bytes := 0
	var samples: Array[String] = []
	var opaque_samples: Array[String] = []
	var failures: Array[String] = []
	for entry in reader.get_entries():
		if str(entry.name).get_extension().to_lower() not in ["mes", "lib"]:
			continue
		var document := parser.parse(reader.read_entry(str(entry.name)), {
			"archive": reader.archive_path.replace("\\", "/").get_file(),
			"entry": str(entry.name),
		})
		if not document.get("ok", false):
			failures.append("%s container: %s" % [entry.name, document.get("error", "unknown")])
			continue
		var report := auditor.audit(document)
		if not report.get("ok", false):
			failures.append("%s alignment: %s" % [
				entry.name,
				"; ".join(report.get("failures", [report.get("error", "unknown")])),
			])
			continue
		entry_count += 1
		region_count += int(report.region_count)
		code_bytes += int(report.code_bytes)
		framed_bytes += int(report.framed_bytes)
		instruction_count += int(report.instruction_count)
		instruction_bytes += int(report.instruction_bytes)
		compound_record_count += int(report.compound_record_count)
		compound_record_bytes += int(report.compound_record_bytes)
		opaque_boundary_count += int(report.opaque_boundary_count)
		opaque_bytes += int(report.opaque_bytes)
		for family in report.compound_families:
			compound_families[family] = int(compound_families.get(family, 0)) + int(report.compound_families[family])
			compound_family_bytes[family] = int(compound_family_bytes.get(family, 0)) + int(report.compound_family_bytes[family])
			var entry_set: Dictionary = compound_family_entries.get(family, {})
			entry_set[str(entry.name)] = true
			compound_family_entries[family] = entry_set
		for untyped_sample in report.samples:
			if samples.size() >= SAMPLE_LIMIT:
				break
			var sample: Dictionary = untyped_sample
			samples.append("%s %s 0x%X..0x%X family=%s" % [
				entry.name,
				str(sample.region),
				int(sample.source_offset),
				int(sample.end_offset),
				str(sample.family),
			])
		for untyped_boundary in report.opaque_boundaries:
			if opaque_samples.size() >= 12:
				break
			var boundary: Dictionary = untyped_boundary
			opaque_samples.append("%s %s 0x%X..0x%X bytes=%d reason=%s" % [
				entry.name,
				str(boundary.region),
				int(boundary.source_offset),
				int(boundary.end_offset),
				int(boundary.byte_length),
				_normalize_reason(str(boundary.reason)),
			])
	if reader.get_archive_fingerprint() != source_sha:
		failures.append("source mes.arc changed during read-only record alignment audit")
	reader.close()
	var family_entry_counts := {}
	for family in compound_family_entries:
		family_entry_counts[family] = (compound_family_entries[family] as Dictionary).size()
	print("MES_RECORD_ALIGNMENT_CORPUS schema=%s entries=%d regions=%d code_bytes=%d framed_bytes=%d instructions=%d instruction_bytes=%d compound_records=%d compound_bytes=%d opaque_boundaries=%d opaque_bytes=%d failures=%d source_unchanged=%s" % [
		SCHEMA,
		entry_count,
		region_count,
		code_bytes,
		framed_bytes,
		instruction_count,
		instruction_bytes,
		compound_record_count,
		compound_record_bytes,
		opaque_boundary_count,
		opaque_bytes,
		failures.size(),
		str(failures.find("source mes.arc changed during read-only record alignment audit") < 0),
	])
	print("MES_RECORD_ALIGNMENT_FAMILIES counts=%s bytes=%s entries=%s" % [
		_format_counts(compound_families),
		_format_counts(compound_family_bytes),
		_format_counts(family_entry_counts),
	])
	for sample in samples:
		print("MES_RECORD_ALIGNMENT_COMPOUND_SAMPLE ", sample)
	for sample in opaque_samples:
		print("MES_RECORD_ALIGNMENT_OPAQUE_SAMPLE ", sample)
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)


func _format_counts(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var labels: Array[String] = []
	for key in keys:
		labels.append("%s:%d" % [str(key), int(counts[key])])
	return ",".join(labels) if not labels.is_empty() else "none"


func _normalize_reason(reason: String) -> String:
	return reason.replace("\r", " ").replace("\n", " ").replace(",", ";").left(160)
