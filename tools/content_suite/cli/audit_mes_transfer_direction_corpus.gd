extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const TransferAuditScript := preload("res://content_core/mes_transfer_direction_audit.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 1 or arguments.size() > 2:
		_fail("Usage: audit_mes_transfer_direction_corpus.gd <mes.arc> [output.json]", 2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader.last_error)
		return
	var source_archive_sha := reader.get_archive_fingerprint()
	if source_archive_sha != ARCHIVE_SHA256:
		reader.close()
		_fail("Authoritative mes.arc fingerprint changed.")
		return
	var parser := MesContainerScript.new()
	var analysis_builder := MesAnalysisScript.new()
	var handoff_builder := AnalyzerHandoffScript.new()
	var audit_builder := TransferAuditScript.new()
	var failures: Array[String] = []
	var counts := {}
	var candidates: Array[Dictionary] = []
	var invalid_targets: Array[Dictionary] = []
	var entry_count := 0
	var transfer_count := 0
	var opaque_boundary_count := 0
	var opaque_bytes := 0
	for untyped_entry in reader.get_entries():
		var entry: Dictionary = untyped_entry
		if str(entry.name).get_extension().to_lower() not in ["mes", "lib"]:
			continue
		entry_count += 1
		var document := parser.parse(reader.read_entry(str(entry.name)), {
			"archive": reader.archive_path.replace("\\", "/").get_file(),
			"entry": str(entry.name),
			"archive_sha256": source_archive_sha,
		})
		if not document.get("ok", false):
			failures.append("%s container: %s" % [entry.name, document.get("error", "failed")])
			continue
		var analysis := analysis_builder.build(document)
		var handoff := handoff_builder.build(document, analysis)
		var verified := handoff_builder.verify(handoff)
		if not verified.get("ok", false):
			failures.append("%s handoff: %s" % [entry.name, verified.get("error", "failed")])
			continue
		var audit := audit_builder.audit(document, analysis)
		if not audit.get("ok", false):
			failures.append("%s audit: %s" % [entry.name, audit.get("error", "failed")])
			continue
		transfer_count += int(audit.transfer_count)
		opaque_boundary_count += int(audit.opaque_boundary_count)
		opaque_bytes += int(audit.opaque_bytes)
		_merge_counts(counts, audit.counts)
		for untyped_candidate in audit.same_region_backward_candidates:
			var candidate: Dictionary = untyped_candidate.duplicate(true)
			candidate["entry"] = str(entry.name)
			candidates.append(candidate)
		for untyped_target in audit.invalid_targets:
			var target: Dictionary = untyped_target.duplicate(true)
			target["entry"] = str(entry.name)
			invalid_targets.append(target)
		if entry_count % 100 == 0:
			print("MES_TRANSFER_DIRECTION_PROGRESS entries=%d" % entry_count)
	candidates.sort_custom(_sort_entry_candidate)
	invalid_targets.sort_custom(_sort_entry_candidate)
	if reader.get_archive_fingerprint() != source_archive_sha:
		failures.append("Source mes.arc changed during transfer-direction audit.")
	var report := {
		"schema": ContentCoreVersionScript.MES_TRANSFER_DIRECTION_AUDIT_SCHEMA,
		"source_archive_sha256": source_archive_sha,
		"entry_count": entry_count,
		"transfer_count": transfer_count,
		"counts": counts,
		"same_region_backward_candidates": candidates,
		"invalid_targets": invalid_targets,
		"opaque_boundary_count": opaque_boundary_count,
		"opaque_bytes": opaque_bytes,
		"scope": "confirmed_typed_branch_and_continuation_targets",
		"opaque_policy": "unresolved_not_scanned_as_transfer",
		"source_mutation": "forbidden",
	}
	report["payload_sha256"] = ContractValues.sha256_lenient(
		JSON.stringify(report, "", true, true).to_utf8_buffer()
	)
	if arguments.size() == 2 and failures.is_empty():
		var output_path := ProjectSettings.globalize_path(arguments[1]).simplify_path()
		var source_path := ProjectSettings.globalize_path(arguments[0]).simplify_path()
		if output_path.get_base_dir().to_lower() == source_path.get_base_dir().to_lower():
			failures.append("Transfer audit output must be outside the source archive directory.")
		else:
			var output := FileAccess.open(output_path, FileAccess.WRITE)
			if output == null:
				failures.append("Could not open transfer audit output: %s" % FileAccess.get_open_error())
			else:
				output.store_string(JSON.stringify(report, "", true, true) + "\n")
				output.close()
	reader.close()
	print(
		"MES_TRANSFER_DIRECTION_CORPUS schema=%s entries=%d transfers=%d same_backward=%d invalid=%d opaque=%d/%d payload_sha256=%s source_unchanged=%s failures=%d"
		% [
			str(report.schema),
			entry_count,
			transfer_count,
			candidates.size(),
			invalid_targets.size(),
			opaque_boundary_count,
			opaque_bytes,
			str(report.payload_sha256),
			str(failures.find("Source mes.arc changed during transfer-direction audit.") < 0),
			failures.size(),
		]
	)
	print("MES_TRANSFER_DIRECTION_COUNTS ", _format_counts(counts))
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)


func _merge_counts(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		target[str(key)] = int(target.get(str(key), 0)) + int(source[key])


func _format_counts(counts: Dictionary) -> String:
	var keys := counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s=%d" % [str(key), int(counts[key])])
	return " ".join(parts)


func _sort_entry_candidate(left: Dictionary, right: Dictionary) -> bool:
	var left_entry := str(left.get("entry", ""))
	var right_entry := str(right.get("entry", ""))
	if left_entry != right_entry:
		return left_entry < right_entry
	return int(left.get("source_offset", -1)) < int(right.get("source_offset", -1))
