extends "res://tests/test_case.gd"

## The tool-layer binding (`tools/content_suite/mod_definition_binding.gd`)
## that runs the Python `kakyu_mod_event_definition/v1` validator on one
## document's bytes (mod event definition unit B, section C).

const BindingScript := preload("res://tools/content_suite/mod_definition_binding.gd")

const FIXTURES := "res://config/contracts/mod_event_definition_v1"


func _ready() -> void:
	var valid_bytes := FileAccess.get_file_as_bytes(FIXTURES + "/valid/new_event_plain.json")
	var valid_result := BindingScript.validate(valid_bytes)
	_check(valid_result.get("ok", false), "binding accepts a valid fixture against the tracked contract")

	var bad_placeholder_bytes := FileAccess.get_file_as_bytes(FIXTURES + "/invalid/bad_placeholder.json")
	var bad_placeholder_result := BindingScript.validate(bad_placeholder_bytes)
	_check(
		not bad_placeholder_result.get("ok", true) and str(bad_placeholder_result.get("reason", "")) == "bad_placeholder",
		"binding reports the bad_placeholder reason for an invalid fixture"
	)

	# The fixture's override targets the fixture set's own invented base
	# document; against the tracked v4 directory the same registry id
	# exists with different bytes, so the default directory reports a
	# changed base, never a missing one.
	var override_bytes := FileAccess.get_file_as_bytes(FIXTURES + "/valid/override_results.json")
	var override_result := BindingScript.validate(override_bytes)
	_check(
		not override_result.get("ok", true) and str(override_result.get("reason", "")) == "target_changed",
		"binding checks an override against the tracked v4 documents by default and reports a changed base"
	)
	var override_against_base := BindingScript.validate(override_bytes, BindingScript.DEFAULT_NAMES_DIR, FIXTURES + "/base")
	_check(override_against_base.get("ok", false), "binding accepts the same override against the directory it was written for")

	var not_json := "not json at all".to_utf8_buffer()
	var not_json_result := BindingScript.validate(not_json)
	_check(
		not_json_result is Dictionary and not bool(not_json_result.get("ok", true)),
		"binding never crashes on non-JSON bytes and returns a failing verdict"
	)
	_check(
		str(not_json_result.get("reason", "")) == "schema" or not not_json_result.get("error", "").is_empty(),
		"binding's non-JSON verdict carries a schema reason or an infrastructure error"
	)

	var validator := BindingScript.validator()
	_check(validator.is_valid(), "validator() returns a bound Callable")
	var via_validator: Dictionary = validator.call(valid_bytes)
	_check(via_validator.get("ok", false), "validator() callable reproduces the same verdict as a direct call")

	get_tree().quit(1 if _failed else 0)
