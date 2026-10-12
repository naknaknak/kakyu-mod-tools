extends "res://tools/content_suite/cli_script.gd"

## Headless `kakyu_mod_bundle/v1` import into one new workspace:
## `-- SOURCE_ROOT TEMPLATE_WORKSPACE BUNDLE_JSON NEW_WORKSPACE`. Prints the
## importer's result as one JSON line and exits 0 or 1.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4:
		_fail("Usage: SOURCE_ROOT TEMPLATE_WORKSPACE BUNDLE_JSON NEW_WORKSPACE")
		return
	var result := preload("res://tools/content_suite/mod_bundle_import.gd").new().import_bundle(
		str(args[0]), str(args[1]), str(args[2]), str(args[3])
	)
	print(JSON.stringify(result))
	quit(0 if result.get("ok", false) else 1)
