extends "res://tools/content_suite/cli_script.gd"

const PlanScript := preload("res://content_core/mes_control_target_relocation_plan.gd")
const MAX_PLAN_BYTES := 32 * 1024 * 1024


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: validate_mes_control_target_relocation_plan.gd <plan.json>", 2)
		return
	var plan_path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	if not FileAccess.file_exists(plan_path):
		_fail("MES control-target relocation plan does not exist.", 2)
		return
	var file := FileAccess.open(plan_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_PLAN_BYTES:
		if file != null:
			file.close()
		_fail("MES control-target relocation plan cannot be read within its size limit.", 2)
		return
	var bytes := file.get_buffer(file.get_length())
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		_fail("MES control-target relocation plan changed while reading.", 2)
		return
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("MES control-target relocation plan is not a JSON object.", 2)
		return
	var validation := PlanScript.new().validate(parsed)
	if not validation.ok:
		_fail(str(validation.error), 1)
		return
	print(
		"MES_CONTROL_TARGET_RELOCATION_PLAN_GODOT_PASS ",
		"schema=", validation.schema,
		" entry=", validation.source_identity.entry,
		" patches=", validation.patch_count,
		" remaining_blockers=", validation.remaining_blocker_count,
		" assembly_ready=", str(validation.assembly_ready).to_lower(),
		" mes_bytes=false payload_sha256=", validation.payload_sha256
	)
	quit(0)
