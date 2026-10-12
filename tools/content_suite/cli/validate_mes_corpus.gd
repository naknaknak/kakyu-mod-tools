extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Usage: godot --headless --path . --script res://tools/content_suite/cli/validate_mes_corpus.gd -- <mes.arc>")
		quit(2)
		return
	var archive_path := arguments[0].replace("\\", "/")
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		push_error("MES_CORPUS_FAIL reader: %s" % reader.last_error)
		quit(2)
		return
	var parser := MesContainerScript.new()
	var parsed_count := 0
	var table_entries := 0
	var code_bytes := 0
	var failures := 0
	for entry in reader.get_entries():
		var extension := str(entry.name).get_extension().to_lower()
		if extension != "mes" and extension != "lib":
			continue
		var data := reader.read_entry(str(entry.name))
		var result := parser.parse(data, {
			"archive": archive_path.get_file(),
			"entry": entry.name,
			"archive_offset": entry.offset,
			"size": entry.size,
		})
		if not result.ok:
			failures += 1
			push_error("MES_CORPUS_FAIL %s: %s" % [entry.name, result.error])
			continue
		parsed_count += 1
		table_entries += int(result.header.entry_count)
		code_bytes += int(result.header.code_size)
	print(
		"MES_CORPUS_SUMMARY entries=%d table_entries=%d code_bytes=%d failures=%d" %
		[parsed_count, table_entries, code_bytes, failures]
	)
	reader.close()
	quit(1 if failures > 0 else 0)
