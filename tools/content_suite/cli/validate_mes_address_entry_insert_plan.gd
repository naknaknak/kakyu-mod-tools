extends "res://tools/content_suite/cli_script.gd"

const PlanScript := preload("res://content_core/mes_address_entry_insert_plan.gd")
const MAX_PLAN_BYTES := 32 * 1024 * 1024


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: validate_mes_address_entry_insert_plan.gd <plan.json>", 2)
		return
	var path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var bytes := _read_bounded(path, MAX_PLAN_BYTES)
	if bytes.is_empty():
		_fail("MES address-entry insertion plan cannot be read within its size limit.", 2)
		return
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("MES address-entry insertion plan is not a JSON object.", 2)
		return
	var result := PlanScript.new().validate(parsed)
	if not result.ok:
		_fail(str(result.error), 1)
		return
	print(
		"MES_ADDRESS_ENTRY_INSERT_PLAN_GODOT_PASS ",
		"schema=", result.schema,
		" entry=", result.source_identity.entry,
		" source_entries=", result.source_entry_count,
		" output_entries=", result.output_entry_count,
		" insert_index=", result.insertion_index,
		" target=0x%X" % result.target_offset,
		" source_code_offset=", result.source_code_offset,
		" output_code_offset=", result.output_code_offset,
		" mes_bytes=false payload_sha256=", result.payload_sha256
	)
	quit(0)
