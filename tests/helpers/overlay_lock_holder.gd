extends SceneTree

const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 4:
		quit(2)
		return
	var package_root := str(arguments[0])
	var ready_path := str(arguments[1])
	var archive_path := str(arguments[2])
	var target_entry := str(arguments[3])
	var package := OverlayPackageScript.new()
	var lock: Dictionary = package._acquire_manifest_lock(package_root)
	if not lock.get("ok", false):
		quit(3)
		return
	var ready := FileAccess.open(ready_path, FileAccess.WRITE)
	if ready == null:
		package._release_manifest_lock(lock)
		quit(4)
		return
	ready.store_string(str(OS.get_process_id()))
	ready.close()
	await create_timer(1.0).timeout
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		package._release_manifest_lock(lock)
		quit(5)
		return
	var published: Dictionary = package._stage_replacements(
		package_root,
		reader,
		"voice.arc",
		{target_entry: PackedByteArray([9, 9, 9, 9])},
		"remake_only",
		"not_applicable",
		false
	)
	reader.close()
	var released: Dictionary = package._release_manifest_lock(lock)
	quit(0 if published.get("ok", false) and released.get("ok", false) else 6)
