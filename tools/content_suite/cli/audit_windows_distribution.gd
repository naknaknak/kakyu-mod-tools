extends SceneTree

func _init() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var result := await preload("res://tools/content_suite/windows_distribution_audit.gd").new().run(self, OS.get_cmdline_user_args())
	print(JSON.stringify(result))
	quit(0 if result.get("ok", false) else 1)
