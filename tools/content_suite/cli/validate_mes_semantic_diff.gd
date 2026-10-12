extends "res://tools/content_suite/cli_script.gd"

const SemanticDiffScript := preload("res://content_core/mes_semantic_diff.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		_fail("Usage: validate_mes_semantic_diff.gd <semantic-diff.json>", 2)
		return
	var text := FileAccess.get_file_as_string(args[0])
	if text.is_empty() and FileAccess.get_open_error() != OK:
		_fail("Could not read MES semantic diff JSON.", 3)
		return
	var document = JSON.parse_string(text)
	if not document is Dictionary:
		_fail("MES semantic diff input is not a JSON object.", 4)
		return
	var validation := SemanticDiffScript.new().validate(document)
	if not validation.ok:
		_fail(str(validation.error), 5)
		return
	print(
		"MES_SEMANTIC_DIFF_VALIDATE_PASS schema=", validation.schema,
		" inserted=", validation.inserted_node_count,
		" removed=", validation.removed_node_count,
		" patched=", validation.patched_node_count,
		" opaque=", validation.exact_opaque_node_count,
		" payload_sha256=", validation.payload_sha256
	)
	quit(0)
