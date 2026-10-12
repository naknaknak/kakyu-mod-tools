class_name KakyuSelectionHandoff
extends RefCounted

## Hands a validated `KakyuContentSelection` document to another Content
## Suite app: writes it into the active workspace's `.handoff/` directory and
## builds the target app's independent launch (WD-09).

const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const ApplicationProcessScript := preload("res://tools/content_suite/application_process.gd")

const SPECIALIST_ARCHIVES := {
	"mes.arc": {
		"app": "mes_editor", "scene": "res://tools/content_suite/apps/mes_editor.tscn",
		"label": "MES Editor",
	},
	"mmo.arc": {
		"app": "image_arc_editor", "scene": "res://tools/content_suite/apps/image_arc_editor.tscn",
		"label": "Image and Animation ARC Editor",
	},
	"data.arc": {
		"app": "image_arc_editor", "scene": "res://tools/content_suite/apps/image_arc_editor.tscn",
		"label": "Image and Animation ARC Editor",
	},
}
const SPECIALIST_AUDIO_ARCHIVES := {
	"voice.arc": true, "bgm.arc": true, "se.arc": true, "tina1.arc": true, "tina2.arc": true,
}
const SPECIALIST_AUDIO_EXTENSIONS := {"wav": true, "ogg": true}


## The specialist editor that owns `entry_name`'s format in `archive_name` (WD-05),
## the same table the Launcher's `_tool_accepts_archive` uses. `app` here is the
## RECEIVING app id for messages only; a selection document's `producer.app` stays
## whichever app produced it.
static func specialist_for(archive_name: String, entry_name: String) -> Dictionary:
	var normalized_archive := archive_name.to_lower()
	if SPECIALIST_ARCHIVES.has(normalized_archive):
		var specialist: Dictionary = SPECIALIST_ARCHIVES[normalized_archive]
		return {"ok": true, "app": str(specialist.app), "scene": str(specialist.scene), "label": str(specialist.label)}
	if (
		SPECIALIST_AUDIO_ARCHIVES.has(normalized_archive)
		and SPECIALIST_AUDIO_EXTENSIONS.has(entry_name.get_extension().to_lower())
	):
		return {
			"ok": true, "app": "audio_arc_editor",
			"scene": "res://tools/content_suite/apps/audio_arc_editor.tscn",
			"label": "Audio ARC Editor",
		}
	return {"ok": false, "error": "No specialist editor handles %s in %s." % [entry_name, archive_name]}


static func launch(scene: String, launch_context, document: Dictionary) -> Dictionary:
	if launch_context == null or not launch_context.is_active():
		return {"ok": false, "error": "A named workspace is required to hand off a selection."}
	var selection := ContentSelectionScript.new()
	var validated := selection.validate_for_workspace(document, launch_context.get_snapshot())
	if not validated.get("ok", false):
		return validated
	var workspace_root: String = launch_context.get_workspace_root()
	var handoff_directory := workspace_root.path_join(".handoff")
	if DirAccess.make_dir_recursive_absolute(handoff_directory) != OK:
		return {"ok": false, "error": "Selection handoff directory could not be created."}
	var handoff_path := handoff_directory.path_join("%s.selection.json" % _unique_id())
	var written := selection.write(document, handoff_path)
	if not written.get("ok", false):
		return written
	var process := ApplicationProcessScript.for_scene(scene)
	if not process.get("ok", false):
		return process
	var arguments: PackedStringArray = process.arguments
	arguments.append_array([
		"--", "--content-set", launch_context.get_content_set_root(),
		"--workspace", workspace_root, "--selection", str(written.path),
	])
	return {"ok": true, "executable": process.executable, "arguments": arguments, "path": str(written.path)}


static func start(launch: Dictionary) -> Dictionary:
	if not launch.get("ok", false):
		return launch
	var pid := OS.create_process(str(launch.executable), launch.arguments)
	if pid <= 0:
		return {"ok": false, "error": "Selection handoff could not start the target application."}
	return {"ok": true, "pid": pid}


static func _unique_id() -> String:
	return "%08x-%08x-%08x" % [OS.get_process_id(), int(Time.get_ticks_usec()) & 0xFFFFFFFF, randi()]
