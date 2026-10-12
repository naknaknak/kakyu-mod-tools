extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 3 or arguments.size() > 5:
		_fail("Usage: validate_mes_analyzer_handoff.gd <mes.arc> <entry> <address-index|bootstrap|offset:HEX> [output.json] [strict|structural]", 2)
		return
	var analysis_mode := "strict"
	if arguments.size() == 5:
		analysis_mode = str(arguments[4]).to_lower()
		if analysis_mode not in ["strict", "structural"]:
			_fail("MES handoff analysis mode must be strict or structural.", 2)
			return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader.last_error)
		return
	var source_archive_sha := reader.get_archive_fingerprint()
	var entry := reader.get_entry(arguments[1])
	if entry.is_empty():
		reader.close()
		_fail("MES entry does not exist: %s" % arguments[1])
		return
	var raw_entry := reader.read_entry(str(entry.name))
	var document := MesContainerScript.new().parse(raw_entry, {
		"archive": reader.archive_path.replace("\\", "/").get_file(),
		"entry": str(entry.name),
		"archive_sha256": source_archive_sha,
	})
	if not document.get("ok", false):
		reader.close()
		_fail(str(document.get("error", "MES container parse failed.")))
		return
	var range_data := _resolve_range(document, arguments[2])
	if range_data.is_empty():
		reader.close()
		_fail("Requested MES handoff range is invalid.")
		return
	var analysis_builder := MesAnalysisScript.new()
	var analysis := (
		analysis_builder.build_structural(document)
		if analysis_mode == "structural"
		else analysis_builder.build(document)
	)
	var graph := analysis_builder.build_reference_graph(
		analysis,
		int(range_data.offset),
		int(range_data.end_offset),
		500,
		2,
		8
	)
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis, [graph])
	var repeated := handoff_builder.build(document, analysis, [graph])
	if (
		not handoff.get("ok", false)
		or str(handoff.get("schema", "")) != ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA
		or not handoff_builder.verify(handoff).get("ok", false)
		or str(handoff.get("payload_sha256", "")) != str(repeated.get("payload_sha256", ""))
	):
		reader.close()
		_fail("MES analyzer handoff did not build deterministically.")
		return
	var encoded := handoff_builder.to_json(handoff)
	if encoded.is_empty() or encoded != handoff_builder.to_json(repeated):
		reader.close()
		_fail("MES analyzer handoff JSON changed between identical builds.")
		return
	if arguments.size() >= 4:
		var output_path := ProjectSettings.globalize_path(arguments[3]).simplify_path()
		var source_path := ProjectSettings.globalize_path(arguments[0]).simplify_path()
		if output_path.get_base_dir().to_lower() == source_path.get_base_dir().to_lower():
			reader.close()
			_fail("Handoff output must be outside the source archive directory.")
			return
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		if output == null:
			reader.close()
			_fail("Could not open handoff output: %s" % FileAccess.get_open_error())
			return
		output.store_string(encoded + "\n")
		output.close()
	if reader.get_archive_fingerprint() != source_archive_sha:
		reader.close()
		_fail("Source mes.arc changed during handoff validation.")
		return
	reader.close()
	print(
		"MES_ANALYZER_HANDOFF_PASS schema=%s entry=%s mode=%s range=0x%X..0x%X instructions=%d opaque=%d cfg_nodes=%d cfg_edges=%d payload_sha256=%s source_unchanged=true"
		% [
			str(handoff.schema),
			str(entry.name),
			analysis_mode,
			int(range_data.offset),
			int(range_data.end_offset),
			int((handoff.typed_ir.instructions as Array).size()),
			int((handoff.typed_ir.opaque_boundaries as Array).size()),
			int(graph.node_count),
			int(graph.edge_count),
			str(handoff.payload_sha256),
		]
	)
	quit(0)


func _resolve_range(document: Dictionary, selector: String) -> Dictionary:
	if selector.to_lower() == "bootstrap":
		return document.bootstrap if int(document.bootstrap.size) > 0 else {}
	if selector.to_lower().begins_with("offset:"):
		var text := selector.substr(7)
		var wanted := text.hex_to_int() if text.to_lower().begins_with("0x") else int(text)
		for untyped_entry in document.entries:
			var entry: Dictionary = untyped_entry
			if wanted >= int(entry.offset) and wanted < int(entry.end_offset):
				return entry
		return {}
	var index := int(selector)
	if index < 0 or index >= document.entries.size():
		return {}
	return document.entries[index]
