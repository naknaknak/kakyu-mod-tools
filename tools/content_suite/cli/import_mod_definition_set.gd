extends "res://tools/content_suite/cli_script.gd"


func _initialize() -> void:
	var raw_args := OS.get_cmdline_user_args()
	var replace := false
	var positional: Array = []
	for argument in raw_args:
		if str(argument) == "--replace":
			replace = true
		else:
			positional.append(argument)
	if positional.size() != 3:
		_fail("Usage: SOURCE_ROOT WORKSPACE SET_JSON [--replace]")
		return
	var result := preload("res://tools/content_suite/mod_definition_set_import.gd").new().import_set(
		str(positional[0]), str(positional[1]), str(positional[2]), replace
	)
	print(JSON.stringify(result))
	quit(0 if result.get("ok", false) else 1)
