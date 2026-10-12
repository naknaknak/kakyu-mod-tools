extends SceneTree

const ContentSetScript := preload("res://content_core/content_set.gd")


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: --script res://tools/content_suite/cli/validate_content_set.gd -- <ELFIMAGE-directory>")
		quit(2)
		return
	var content_set := ContentSetScript.new()
	if not content_set.open(arguments[0]):
		push_error(content_set.last_error)
		quit(1)
		return
	var summary: Dictionary = content_set.get_summary()
	print("CONTENT_SET schema=%s archives=%d" % [str(summary.schema), int(summary.archive_count)])
	for archive in summary.archives:
		print("ARC name=%s entries=%d bytes=%d" % [str(archive.name), int(archive.entries), int(archive.bytes)])
	for warning in summary.warnings:
		print("WARNING: ", warning)
	content_set.close()
	print("CONTENT_SET_VALIDATION_PASS")
	quit(0)
