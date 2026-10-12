extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4:
		push_error("Usage: SOURCE_ROOT SOURCE_WORKSPACE DELTA_JSON NEW_WORKSPACE")
		quit(1)
		return
	var result := preload("res://tools/content_suite/authored_delta_import.gd").new().import_delta(args[0], args[1], args[2], args[3])
	print(JSON.stringify(result))
	quit(0 if result.get("ok", false) else 1)
