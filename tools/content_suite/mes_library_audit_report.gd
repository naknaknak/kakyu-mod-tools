class_name KakyuMesLibraryAuditReport
extends RefCounted

## Shared Godot builder of the archive's LIBLARY.LIB library audit
## (`kakyu_mes_library_audit/v17`, wrapped with its archive identity). Moved
## out of `tools/content_suite/cli/export_mes_decompiler_handoff_spool.gd`
## (MW-11) so the Authoring session and delta importer can build the same
## report the spool exporter publishes, without duplicating the archive-open
## and container-parse steps.

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesLibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const MesLibraryAuditScript := preload("res://content_core/mes_library_audit.gd")

const LIBRARY_ENTRY := "LIBLARY.LIB"


## Opens `archive_path` itself, parses its LIBLARY.LIB entry and audits every
## registered routine. Returns `{ok: false, error}` on any failure, or the
## same wrapped dictionary the spool exporter used to build inline:
## `{ok, schema, archive_name, archive_sha256, entry, entry_sha256,
## source_archive_unchanged, routines}`.
func build(archive_path: String) -> Dictionary:
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		return {"ok": false, "error": reader.last_error}
	var archive_sha := reader.get_archive_fingerprint()
	var archive_name := archive_path.get_file()
	var result := _build(reader, archive_sha, archive_name)
	if reader.get_archive_fingerprint() != archive_sha:
		reader.close()
		return {"ok": false, "error": "Source archive changed during library audit."}
	reader.close()
	return result


## Builds the report and stores it at `output_path` (which must not already
## exist) using the exact serialization the spool exporter uses, so callers
## that only need the file can skip holding the dictionary.
func write(archive_path: String, output_path: String) -> Dictionary:
	var report := build(archive_path)
	if not report.get("ok", false):
		return report
	if FileAccess.file_exists(output_path):
		return {"ok": false, "error": "Library audit output already exists."}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write the library audit output."}
	file.store_string(JSON.stringify(report, "", true, true) + "\n")
	file.close()
	return report


func _build(reader: KakyuArcReader, archive_sha: String, archive_name: String) -> Dictionary:
	var entry: Dictionary = reader.get_entry(LIBRARY_ENTRY)
	if entry.is_empty():
		return {"ok": false, "error": "LIBLARY.LIB is missing."}
	var parser := MesContainerScript.new()
	var document: Dictionary = parser.parse(reader.read_entry(LIBRARY_ENTRY), {
		"archive": archive_name,
		"entry": LIBRARY_ENTRY,
		"archive_sha256": archive_sha,
	})
	if not document.get("ok", false) or int(document.header.entry_count) != 0:
		return {"ok": false, "error": "LIBLARY.LIB container is invalid."}
	var library_index := MesLibraryIndexScript.new().build(
		document.bytecode, int(document.header.code_size)
	)
	if not library_index.get("ok", false):
		return {"ok": false, "error": str(library_index.get("error", "Library index failed."))}
	var routine_ids: Array[int] = []
	for untyped_routine in library_index.routines:
		routine_ids.append(int((untyped_routine as Dictionary).routine_id))
	var audit := MesLibraryAuditScript.new().audit(
		document.bytecode, library_index, routine_ids
	)
	if not audit.get("ok", false):
		return {"ok": false, "error": str(audit.get("error", "Library audit failed."))}
	return {
		"ok": true,
		"schema": audit.schema,
		"archive_name": archive_name,
		"archive_sha256": archive_sha,
		"entry": LIBRARY_ENTRY,
		"entry_sha256": reader.get_entry_fingerprint(LIBRARY_ENTRY),
		"source_archive_unchanged": true,
		"routines": audit.routines,
	}
