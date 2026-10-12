extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const CorpusReopenScript := preload("res://content_core/mes_noop_corpus_reopen.gd")

const MANIFEST_NAME := "noop-compile-spool-manifest.json"


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("Usage: audit_mes_noop_reopen_corpus.gd <compile-spool-directory> <mes.arc>", 2)
		return
	var spool_directory := ProjectSettings.globalize_path(arguments[0]).simplify_path()
	var manifest_path := spool_directory.path_join(MANIFEST_NAME)
	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	if manifest_file == null:
		_fail("MES no-op compile-spool manifest is missing.")
		return
	var manifest = JSON.parse_string(manifest_file.get_as_text())
	manifest_file.close()
	if not manifest is Dictionary:
		_fail("MES no-op compile-spool manifest is not a JSON object.")
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[1]):
		_fail(reader.last_error)
		return
	var validator := CorpusReopenScript.new()
	var report: Dictionary = validator.audit(
		manifest,
		func(row: Dictionary) -> Dictionary:
			return _load_entry(spool_directory, row),
		func() -> String:
			return reader.get_archive_fingerprint(),
		func(completed: int, total: int, entry: String) -> void:
			if completed % 100 == 0 or completed == total:
				print("MES_NOOP_REOPEN_CORPUS_PROGRESS %d/%d entry=%s" % [
					completed, total, entry,
				])
	)
	reader.close()
	if not report.get("ok", false):
		_fail(str(report.get("error", "MES no-op corpus reopen failed.")))
		return
	print(
		"MES_NOOP_REOPEN_CORPUS_PASS schema=%s entries=%d/%d complete=%s bytes=%d nodes=%d opaque=%d stream_sha256=%s payload_sha256=%s source_unchanged=true"
		% [
			str(report.schema),
			int(report.entry_count),
			int(report.source_entry_count),
			str(report.complete_archive),
			int(report.coverage.container_bytes),
			int(report.coverage.node_count),
			int(report.coverage.opaque_node_count),
			str(report.reopen_stream_sha256),
			str(report.payload_sha256),
		]
	)
	quit(0)


func _load_entry(directory: String, row: Dictionary) -> Dictionary:
	var mes_path := directory.path_join(str(row.mes_file))
	var audit_path := directory.path_join(str(row.audit_file))
	var mes_file := FileAccess.open(mes_path, FileAccess.READ)
	if mes_file == null:
		return {"ok": false}
	var payload := mes_file.get_buffer(mes_file.get_length())
	mes_file.close()
	var audit_file := FileAccess.open(audit_path, FileAccess.READ)
	if audit_file == null:
		return {"ok": false}
	var compile_audit = JSON.parse_string(audit_file.get_as_text())
	audit_file.close()
	if not compile_audit is Dictionary:
		return {"ok": false}
	return {
		"ok": true,
		"payload": payload,
		"compile_audit": compile_audit,
	}
