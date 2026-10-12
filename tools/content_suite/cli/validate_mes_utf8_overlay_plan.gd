extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const PlanScript := preload("res://content_core/mes_utf8_overlay_plan.gd")
const MAX_PLAN_BYTES := 32 * 1024 * 1024


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 1 or arguments.size() > 2:
		_fail("Usage: validate_mes_utf8_overlay_plan.gd <plan.json> [mes.arc]", 2)
		return
	var plan_path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	if not FileAccess.file_exists(plan_path):
		_fail("MES UTF-8 overlay plan does not exist.", 2)
		return
	var file := FileAccess.open(plan_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_PLAN_BYTES:
		if file != null:
			file.close()
		_fail("MES UTF-8 overlay plan cannot be read within its size limit.", 2)
		return
	var bytes := file.get_buffer(file.get_length())
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		_fail("MES UTF-8 overlay plan changed while reading.", 2)
		return
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("MES UTF-8 overlay plan is not a JSON object.", 2)
		return
	var validation := PlanScript.new().validate(parsed)
	if not validation.ok:
		_fail(str(validation.error), 1)
		return
	var projection: Dictionary = validation.projection_document
	if arguments.size() == 2:
		var archive_path := ProjectSettings.globalize_path(str(arguments[1])).simplify_path()
		var reader := ArcReaderScript.new()
		if not reader.open(archive_path):
			_fail("MES UTF-8 overlay source ARC could not be opened.", 2)
			return
		if (
			archive_path.get_file().to_lower() != str(projection.target_archive).to_lower()
			or reader.get_archive_fingerprint() != str(projection.base_archive_sha256)
			or reader.get_entry_fingerprint(str(projection.target_entry)) != str(projection.entry_sha256)
		):
			reader.close()
			_fail("MES UTF-8 overlay plan source binding does not match the ARC.", 1)
			return
		reader.close()
	print(
		"MES_UTF8_OVERLAY_PLAN_GODOT_PASS ",
		"schema=", validation.schema,
		" entry=", projection.target_entry,
		" offset=0x", "%X" % int(projection.edits[0].source_offset),
		" compatibility=remake_only mes_bytes=false",
		" payload_sha256=", validation.payload_sha256
	)
	quit(0)
