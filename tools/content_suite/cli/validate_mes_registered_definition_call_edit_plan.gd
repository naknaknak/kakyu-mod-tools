extends "res://tools/content_suite/cli_script.gd"

const PlanScript := preload("res://content_core/mes_registered_definition_call_edit_plan.gd")
const MAX_PLAN_BYTES := 32 * 1024 * 1024


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: validate_mes_registered_definition_call_edit_plan.gd <plan.json>", 2)
		return
	var path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var bytes := _read_bounded(path, MAX_PLAN_BYTES)
	if bytes.is_empty():
		_fail("MES registered-definition call edit plan cannot be read within its size limit.", 2)
		return
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("MES registered-definition call edit plan is not a JSON object.", 2)
		return
	var result := PlanScript.new().validate(parsed)
	if not result.ok:
		_fail(str(result.error), 1)
		return
	print(
		"MES_REGISTERED_DEFINITION_CALL_EDIT_PLAN_GODOT_PASS ",
		"schema=", result.schema,
		" entry=", result.source_identity.entry,
		" offset=", result.instruction_start,
		" literal_offset=", result.literal_start,
		" source_selector=", result.source_selector,
		" replacement_selector=", result.replacement_selector,
		" resume=", result.physical_resume_offset,
		" source_body=", result.source_body_start, "..", result.source_body_end,
		" replacement_body=", result.replacement_body_start, "..", result.replacement_body_end,
		" mes_bytes=false payload_sha256=", result.payload_sha256
	)
	quit(0)
