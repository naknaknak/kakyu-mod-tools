extends "res://tests/test_case.gd"

## G0 (MW-11): the shared Godot builder of the archive's LIBLARY.LIB library
## audit, extracted from the handoff spool exporter so the Authoring session
## and delta importer can build the same report on demand.

const ReportScript := preload("res://tools/content_suite/mes_library_audit_report.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://mes_library_audit_report_test"


func _ready() -> void:
	_cleanup()
	var root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(root)
	var archive_path := root.path_join("mes.arc")

	# Two return-only routines (3 and 4), the same minimal shape
	# tests/test_mes_library_index.gd registers: `1C <id> FF <skip u32>` then
	# a one-byte `00` (command 0x00, return) body.
	var code := PackedByteArray()
	SyntheticArc.append_registration(code, 3, PackedByteArray([0x00]))
	SyntheticArc.append_registration(code, 4, PackedByteArray([0x00]))
	code.append(0x00)
	var library := PackedByteArray([0, 0, 0, 0])
	library.append_array(code)
	SyntheticArc.write_arc(archive_path, [{"name": "LIBLARY.LIB", "data": library}])

	var report := ReportScript.new().build(archive_path)
	_check(report.get("ok", false), "library audit report builds on a synthetic archive: %s" % str(report.get("error", "ok")))
	if report.get("ok", false):
		_check(report.schema == "kakyu_mes_library_audit/v17", "library audit report uses the versioned library audit schema")
		_check(report.entry == "LIBLARY.LIB", "library audit report names its LIBLARY.LIB entry")
		_check(report.archive_sha256 == FileAccess.get_sha256(archive_path), "library audit report retains the archive fingerprint")
		_check(report.source_archive_unchanged == true, "library audit report declares its source archive unchanged")
		var routine_ids: Array = []
		for routine in report.routines:
			routine_ids.append(int(routine.routine_id))
		routine_ids.sort()
		_check(routine_ids == [3, 4], "library audit report audits both registered routines")

	var output_path := root.path_join("library-audit.json")
	var written := ReportScript.new().write(archive_path, output_path)
	_check(written.get("ok", false) and written == report, "library audit report writer returns the same report")
	_check(FileAccess.file_exists(output_path), "library audit report writer stores its output file")
	if FileAccess.file_exists(output_path):
		var reopened = JSON.parse_string(FileAccess.get_file_as_string(output_path))
		_check(reopened is Dictionary and reopened.get("schema", "") == "kakyu_mes_library_audit/v17", "library audit report file reopens as valid JSON")
	_check(not ReportScript.new().write(archive_path, output_path).get("ok", false), "library audit report writer refuses an existing output")

	var missing := ReportScript.new().build(root.path_join("does-not-exist.arc"))
	_check(not missing.get("ok", false), "library audit report refuses a missing archive")

	var no_library_arc := root.path_join("no-library.arc")
	SyntheticArc.write_arc(no_library_arc, [{"name": "OTHER.MES", "data": PackedByteArray([0, 0, 0, 0, 0x00])}])
	var absent := ReportScript.new().build(no_library_arc)
	_check(not absent.get("ok", false), "library audit report refuses an archive without LIBLARY.LIB")

	_cleanup()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
