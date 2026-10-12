extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const LibraryAuditReportScript := preload("res://tools/content_suite/mes_library_audit_report.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const CONFIRMED_FLOW_KINDS := [
	"condition_false_target",
	"condition_true_fallthrough",
	"continuation_target",
]


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2 or arguments.size() > 3:
		_fail("Usage: export_mes_decompiler_handoff_spool.gd <mes.arc> <output-dir> [max-entries|0]", 2)
		return
	var source_path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var output_directory := ProjectSettings.globalize_path(str(arguments[1])).simplify_path()
	var max_entries := 0
	if arguments.size() == 3:
		if not str(arguments[2]).is_valid_int() or int(arguments[2]) < 0:
			_fail("max-entries must be a non-negative integer.", 2)
			return
		max_entries = int(arguments[2])
	if output_directory.to_lower() == source_path.get_base_dir().to_lower():
		_fail("Handoff spool output must not be the source archive directory.")
		return
	var project_root := ProjectSettings.globalize_path("res://").simplify_path()
	if _path_is_within(output_directory, project_root):
		_fail("Handoff spool output must stay outside the Git project.")
		return
	if DirAccess.dir_exists_absolute(output_directory) or FileAccess.file_exists(output_directory):
		_fail("Handoff spool output must not already exist.")
		return
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		_fail("Could not create the handoff spool output directory.")
		return

	var reader := ArcReaderScript.new()
	if not reader.open(source_path):
		_fail(reader.last_error)
		return
	var archive_sha := reader.get_archive_fingerprint()
	var source_entries: Array = reader.get_entries()
	var eligible: Array[Dictionary] = []
	for archive_index in range(source_entries.size()):
		var entry: Dictionary = source_entries[archive_index]
		if str(entry.name).get_extension().to_lower() in ["mes", "lib"]:
			eligible.append({"archive_index": archive_index, "entry": entry})
	var selected_count := eligible.size()
	if max_entries > 0:
		selected_count = mini(selected_count, max_entries)
	var parser := MesContainerScript.new()
	var analysis_builder := MesAnalysisScript.new()
	var handoff_builder := AnalyzerHandoffScript.new()
	var manifest_entries: Array[Dictionary] = []
	for position in range(selected_count):
		var selected: Dictionary = eligible[position]
		var entry: Dictionary = selected.entry
		var document := parser.parse(reader.read_entry(str(entry.name)), {
			"archive": source_path.get_file(),
			"entry": str(entry.name),
			"archive_sha256": archive_sha,
		})
		if not document.get("ok", false):
			reader.close()
			_fail("MES container failed for %s: %s" % [entry.name, document.get("error", "failed")])
			return
		var analysis := analysis_builder.build(document)
		if not analysis.get("ok", false):
			reader.close()
			_fail("MES analysis failed for %s." % entry.name)
			return
		var graph := _build_complete_flow_graph(analysis, int(document.header.code_size))
		var handoff := handoff_builder.build(document, analysis, [graph])
		var verified := handoff_builder.verify(handoff)
		if not verified.get("ok", false):
			reader.close()
			_fail("MES handoff failed for %s: %s" % [entry.name, verified.get("error", "failed")])
			return
		var encoded := handoff_builder.to_json(handoff)
		if encoded.is_empty():
			reader.close()
			_fail("MES handoff JSON failed for %s." % entry.name)
			return
		var file_name := "%04d-%s-%s.json" % [
			int(selected.archive_index),
			_safe_name(str(entry.name)),
			str(handoff.payload_sha256).substr(0, 12),
		]
		if not _write_new_text(output_directory.path_join(file_name), encoded + "\n"):
			reader.close()
			_fail("Could not write MES handoff spool file for %s." % entry.name)
			return
		manifest_entries.append({
			"position": position,
			"archive_index": int(selected.archive_index),
			"entry": str(entry.name),
			"file": file_name,
			"handoff_sha256": str(handoff.payload_sha256),
		})
		if (position + 1) % 25 == 0 or position + 1 == selected_count:
			print("MES_DECOMPILER_SPOOL_PROGRESS entries=%d/%d last=%s" % [position + 1, selected_count, entry.name])

	var library_report := LibraryAuditReportScript.new().build(source_path)
	if not library_report.get("ok", false):
		reader.close()
		_fail(str(library_report.get("error", "MES library audit failed.")))
		return
	var library_encoded := JSON.stringify(library_report, "", true, true)
	if not _write_new_text(output_directory.path_join("library-audit.json"), library_encoded + "\n"):
		reader.close()
		_fail("Could not write MES library audit spool file.")
		return
	if reader.get_archive_fingerprint() != archive_sha:
		reader.close()
		_fail("Source mes.arc changed during handoff spool export.")
		return
	reader.close()
	var manifest := {
		"schema": ContentCoreVersionScript.MES_DECOMPILER_HANDOFF_SPOOL_SCHEMA,
		"handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		"source_identity": {
			"archive": source_path.get_file(),
			"archive_sha256": archive_sha,
		},
		"source_entry_count": eligible.size(),
		"entry_count": manifest_entries.size(),
		"complete_archive": manifest_entries.size() == eligible.size(),
		"library_audit": {
			"schema": ContentCoreVersionScript.MES_LIBRARY_AUDIT_SCHEMA,
			"input_sha256": ContractValues.sha256(library_encoded.to_utf8_buffer()),
		},
		"entries": manifest_entries,
	}
	manifest["payload_sha256"] = _json_fingerprint(manifest)
	if not _write_new_text(
		output_directory.path_join("handoff-spool-manifest.json"),
		JSON.stringify(manifest, "", true, true) + "\n"
	):
		_fail("Could not publish the MES handoff spool manifest.")
		return
	print(
		"MES_DECOMPILER_HANDOFF_SPOOL_PASS schema=%s entries=%d/%d complete=%s archive_sha256=%s payload_sha256=%s source_unchanged=true"
		% [
			str(manifest.schema),
			manifest_entries.size(),
			eligible.size(),
			str(manifest.complete_archive),
			archive_sha,
			str(manifest.payload_sha256),
		]
	)
	quit(0)


func _build_complete_flow_graph(analysis: Dictionary, code_size: int) -> Dictionary:
	var instructions_by_offset := {}
	for untyped_instruction in analysis.get("instructions", []):
		var instruction: Dictionary = untyped_instruction
		instructions_by_offset[int(instruction.source_offset)] = instruction
	var nodes_by_id := {}
	var edges: Array[Dictionary] = []
	var considered_references := 0
	var skipped_references := 0
	for untyped_reference in analysis.get("code_references", []):
		var reference: Dictionary = untyped_reference
		if str(reference.get("kind", "")) not in CONFIRMED_FLOW_KINDS:
			continue
		considered_references += 1
		var source_offset := int(reference.get("source_offset", -1))
		var source_instruction: Dictionary = instructions_by_offset.get(source_offset, {})
		if source_instruction.is_empty():
			skipped_references += 1
			continue
		var source_id := _graph_node_id(source_offset, "instruction")
		_add_graph_node(nodes_by_id, source_id, source_offset, source_instruction, "indexed")
		var target_offset := int(reference.get("target_offset", -1))
		var target_instruction: Dictionary = instructions_by_offset.get(target_offset, {})
		if not bool(reference.get("in_code", false)) or not bool(reference.get("aligned", false)) or target_instruction.is_empty():
			skipped_references += 1
			continue
		var target_id := _graph_node_id(target_offset, "instruction")
		_add_graph_node(nodes_by_id, target_id, target_offset, target_instruction, "indexed")
		edges.append({
			"from_id": source_id,
			"to_id": target_id,
			"kind": str(reference.kind),
			"confirmed_flow": true,
			"source_depth": 0,
		})
	var stop_count := 0
	for untyped_diagnostic in analysis.get("diagnostics", []):
		var diagnostic: Dictionary = untyped_diagnostic
		var stop_offset := int(diagnostic.get("source_offset", -1))
		if stop_offset < 0 or stop_offset >= code_size:
			continue
		stop_count += 1
		var stop_id := _graph_node_id(stop_offset, "stop")
		if nodes_by_id.has(stop_id):
			continue
		nodes_by_id[stop_id] = {
			"id": stop_id,
			"offset": stop_offset,
			"op": "decode_stop",
			"status": "stop",
			"region": str(diagnostic.get("region", "unassigned")),
			"error": str(diagnostic.get("error", "decode_stop")),
			"graph_depth": 0,
		}
	var nodes: Array = nodes_by_id.values()
	nodes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.offset) == int(right.offset):
			return str(left.id) < str(right.id)
		return int(left.offset) < int(right.offset)
	)
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_REFERENCE_GRAPH_SCHEMA,
		"range_start": 0,
		"range_end": code_size,
		"nodes": nodes,
		"edges": edges,
		"node_count": nodes.size(),
		"edge_count": edges.size(),
		"reference_count": considered_references,
		"stop_count": stop_count,
		"expansion_depth": 0,
		"expanded_regions": [],
		"expanded_region_count": 0,
		"max_expanded_regions": 0,
		"skipped_expansion_regions": [],
		"truncated": skipped_references > 0,
		"skipped_references": skipped_references,
		"skipped_stops": 0,
	}


func _add_graph_node(
	nodes: Dictionary,
	node_id: String,
	offset: int,
	instruction: Dictionary,
	status: String
) -> void:
	if nodes.has(node_id):
		return
	nodes[node_id] = {
		"id": node_id,
		"offset": offset,
		"op": str(instruction.get("op", "unresolved_target")),
		"status": status,
		"region": str(instruction.get("region", "unassigned")),
		"graph_depth": 0,
	}


func _json_fingerprint(document: Dictionary) -> String:
	var payload := document.duplicate(true)
	payload.erase("payload_sha256")
	return ContractValues.sha256(JSON.stringify(payload, "", true, true).to_utf8_buffer())


func _write_new_text(path: String, value: String) -> bool:
	if FileAccess.file_exists(path):
		return false
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		return false
	output.store_string(value)
	output.close()
	return true


func _safe_name(value: String) -> String:
	var output := ""
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			output += String.chr(code).to_lower()
		else:
			output += "_"
	return output


func _graph_node_id(offset: int, kind: String) -> String:
	return "%s_%08x" % [kind, offset & 0xFFFFFFFF]


func _path_is_within(path: String, parent: String) -> bool:
	var normalized_path := path.replace("\\", "/").trim_suffix("/").to_lower()
	var normalized_parent := parent.replace("\\", "/").trim_suffix("/").to_lower()
	return normalized_path == normalized_parent or normalized_path.begins_with(normalized_parent + "/")
