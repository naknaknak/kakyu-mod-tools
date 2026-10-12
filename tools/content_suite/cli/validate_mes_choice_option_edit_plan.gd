extends "res://tools/content_suite/cli_script.gd"

const PlanScript := preload("res://content_core/mes_choice_option_edit_plan.gd")
const MAX_PLAN_BYTES := 32 * 1024 * 1024


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: validate_mes_choice_option_edit_plan.gd <plan.json>", 2)
		return
	var path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var bytes := _read_bounded(path, MAX_PLAN_BYTES)
	if bytes.is_empty():
		_fail("MES choice-option edit plan cannot be read within its size limit.", 2)
		return
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("MES choice-option edit plan is not a JSON object.", 2)
		return
	var result := PlanScript.new().validate(parsed)
	if not result.ok:
		_fail(str(result.error), 1)
		return
	print(
		"MES_CHOICE_OPTION_EDIT_PLAN_GODOT_PASS ",
		"schema=", result.schema,
		" entry=", result.source_identity.entry,
		" group=", result.group_selector,
		" definition=", result.definition_id,
		" payload=", result.payload_start, "..", result.payload_end,
		" size=", result.payload_size,
		" routine40=", result.routine40_terminal,
		" resume=", result.physical_resume,
		" output_entry_sha256=", result.output_entry_sha256,
		" byte_delta=0 mes_bytes=false payload_sha256=", result.payload_sha256
	)
	quit(0)
