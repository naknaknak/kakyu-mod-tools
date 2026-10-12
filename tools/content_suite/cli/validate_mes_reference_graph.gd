extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 3 or arguments.size() > 5:
		push_error("Usage: validate_mes_reference_graph.gd <mes.arc> <entry> <address-index|bootstrap|offset:HEX> [expansion-depth] [max-expanded-regions]")
		quit(2)
		return
	var expansion_depth := int(arguments[3]) if arguments.size() >= 4 else 0
	var max_expanded_regions := int(arguments[4]) if arguments.size() >= 5 else 8
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		push_error(reader.last_error)
		quit(1)
		return
	var entry_name := arguments[1]
	var entry := reader.get_entry(entry_name)
	if entry.is_empty():
		push_error("MES entry does not exist: %s" % entry_name)
		reader.close()
		quit(1)
		return
	var document := MesContainerScript.new().parse(reader.read_entry(entry_name), {"entry": str(entry.name)})
	reader.close()
	if not document.ok:
		push_error(document.error)
		quit(1)
		return
	var range_data: Dictionary
	if arguments[2].to_lower() == "bootstrap":
		range_data = document.bootstrap
	elif arguments[2].to_lower().begins_with("offset:"):
		var offset_text := arguments[2].substr(7)
		var wanted_offset := offset_text.hex_to_int() if offset_text.to_lower().begins_with("0x") else int(offset_text)
		for candidate in document.entries:
			if wanted_offset >= int(candidate.offset) and wanted_offset < int(candidate.end_offset):
				range_data = candidate
				break
		if range_data.is_empty():
			push_error("Code-relative offset is outside all address ranges.")
			quit(1)
			return
	else:
		var address_index := int(arguments[2])
		if address_index < 0 or address_index >= document.entries.size():
			push_error("Address index is out of range.")
			quit(1)
			return
		range_data = document.entries[address_index]
	var builder := MesAnalysisScript.new()
	var analysis := builder.build(document)
	var graph := builder.build_reference_graph(
		analysis,
		int(range_data.offset),
		int(range_data.end_offset),
		120,
		expansion_depth,
		max_expanded_regions
	)
	if not graph.ok:
		push_error(graph.error)
		quit(1)
		return
	if str(graph.get("schema", "")) != ContentCoreVersionScript.MES_REFERENCE_GRAPH_SCHEMA:
		push_error("Reference graph schema is not the stable analyzer contract.")
		quit(1)
		return
	var node_ids: Dictionary = {}
	for node in graph.nodes:
		node_ids[str(node.id)] = true
	for edge in graph.edges:
		if not node_ids.has(str(edge.from_id)) or not node_ids.has(str(edge.to_id)):
			push_error("Reference graph contains a dangling edge.")
			quit(1)
			return
	print("MES_REFERENCE_GRAPH_PASS schema=%s entry=%s range=%s start=0x%X end=0x%X nodes=%d edges=%d stops=%d expanded_regions=%d depth=%d truncated=%s" % [
		str(graph.schema),
		str(entry.name),
		arguments[2],
		int(range_data.offset),
		int(range_data.end_offset),
		int(graph.node_count),
		int(graph.edge_count),
		int(graph.stop_count),
		int(graph.expanded_region_count),
		int(graph.expansion_depth),
		str(graph.truncated),
	])
	quit(0)
