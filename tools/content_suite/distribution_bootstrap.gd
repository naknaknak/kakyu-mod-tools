extends Node

# Enabled only in the source-only export copy. Release templates deliberately
# disable engine --script/--scene overrides, so use an explicit application
# diagnostic instead of depending on editor-only command-line behaviour.
func _ready() -> void:
	if "--distribution-audit" in OS.get_cmdline_user_args():
		call_deferred("_audit")


func _audit() -> void:
	if DisplayServer.get_name() != "headless":
		get_tree().quit(2)
		return
	var args := OS.get_cmdline_user_args()
	args.remove_at(args.find("--distribution-audit"))
	var result := await preload("res://tools/content_suite/windows_distribution_audit.gd").new().run(get_tree(), args)
	print(JSON.stringify(result))
	get_tree().quit(0 if result.get("ok", false) else 1)
