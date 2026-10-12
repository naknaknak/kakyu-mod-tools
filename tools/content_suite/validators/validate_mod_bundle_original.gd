extends "res://tools/content_suite/cli_script.gd"

## WD-10 original integration: the mod bundle round trip over the original
## `mes.arc`, read-only. It runs `tests/test_mod_bundle_import.gd` in its original
## mode (`original_source_root` set, as `cli/validate_mes_contextual_authoring.gd`
## sets it on the authoring workflow test): a state edit on `EVENTB01.MES`, a
## state edit and a translation on `EVENTB03.MES`, a translation on
## `EVENTB02.MES` and one `new_event` definition are built into a
## `kakyu_mod_bundle/v1`, imported into one fresh workspace and reopened, and
## every effective identity is checked. Everything is written under `user://`
## (the batch gives each worker its own) and removed on every exit; the output
## is one PASS line and carries no original text.

const RoundTripScript := preload("res://tests/test_mod_bundle_import.gd")


func _initialize() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or not FileAccess.file_exists(str(arguments[0]).path_join("mes.arc")):
		_fail("Usage: <ELFIMAGE-directory> (the read-only original content set)")
		return
	var round_trip := RoundTripScript.new()
	round_trip.original_source_root = str(arguments[0])
	root.add_child(round_trip)
