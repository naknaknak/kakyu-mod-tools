extends SceneTree

const WorkflowScript := preload("res://tests/test_mes_authoring_workflow.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var relocated := arguments.has("--message-relocation")
	var resource_name := arguments.has("--resource-name")
	var sequence := arguments.has("--sequence")
	if int(relocated) + int(resource_name) + int(sequence) > 1:
		push_error("--message-relocation, --resource-name and --sequence are mutually exclusive.")
		quit(1)
		return
	for flag in ["--message-relocation", "--resource-name", "--sequence"]:
		var flag_index := arguments.find(flag)
		if flag_index >= 0:
			arguments.remove_at(flag_index)
	if arguments.size() not in [1, 2] or not FileAccess.file_exists(str(arguments[0]).path_join("mes.arc")):
		push_error("Supply the read-only original content-set directory.")
		quit(1)
		return
	var workflow := WorkflowScript.new()
	workflow.message_relocation = relocated
	workflow.resource_name = resource_name
	workflow.sequence = sequence
	workflow.original_source_root = str(arguments[0])
	if arguments.size() == 2:
		var retained := ProjectSettings.globalize_path(str(arguments[1])).replace("\\", "/").simplify_path()
		if not retained.is_absolute_path():
			retained = ProjectSettings.globalize_path("res://").path_join(retained).simplify_path()
		var original := ProjectSettings.globalize_path(str(arguments[0])).replace("\\", "/").simplify_path()
		if DirAccess.dir_exists_absolute(retained) or retained.to_lower() == original.to_lower() or retained.to_lower().begins_with(original.to_lower().trim_suffix("/") + "/"):
			push_error("Retained authoring evidence requires a new directory outside the originals.")
			quit(1)
			return
		workflow.retained_output_root = retained
	root.add_child(workflow)
