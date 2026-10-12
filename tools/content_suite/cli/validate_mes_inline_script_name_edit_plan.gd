extends "res://tools/content_suite/cli_script.gd"

const PlanScript := preload("res://content_core/mes_inline_script_name_edit_plan.gd")
const MAX_PLAN_BYTES := 32 * 1024 * 1024


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: validate_mes_inline_script_name_edit_plan.gd <plan.json>", 2)
		return
	var path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	if not FileAccess.file_exists(path):
		_fail("MES inline script name edit plan does not exist.", 2)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_PLAN_BYTES:
		if file != null:
			file.close()
		_fail("MES inline script name edit plan cannot be read within its size limit.", 2)
		return
	var bytes := file.get_buffer(file.get_length())
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		_fail("MES inline script name edit plan changed while reading.", 2)
		return
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("MES inline script name edit plan is not a JSON object.", 2)
		return
	var result := PlanScript.new().validate(parsed)
	if not result.ok:
		_fail(str(result.error), 1)
		return
	print(
		"MES_INLINE_SCRIPT_NAME_EDIT_PLAN_GODOT_PASS ",
		"schema=", result.schema,
		" entry=", result.source_identity.entry,
		" offset=", result.envelope_start,
		" name_offset=", result.name_start,
		" selector=", result.execution_selector,
		" boundary=", result.reference_boundary,
		" source=", result.source_name,
		" replacement=", result.replacement_name,
		" mes_bytes=false payload_sha256=", result.payload_sha256
	)
	quit(0)
