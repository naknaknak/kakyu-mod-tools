extends RefCounted

## The shared "validate with a Python tool, then use the bytes it extracted"
## step of the two headless importers (`mod_definition_set_import.gd` and
## `mod_bundle_import.gd`, WD-10): hash the file, run the tool's
## `validate <file> ... --extract <fresh user:// tree>`, read its last JSON
## line as the verdict, hash the file again, hand the extracted tree to the
## caller, and remove the tree on every exit.

const PythonRuntimeScript := preload("res://tools/content_suite/python_runtime.gd")


## `tool` is the Python tool under `tools/`, `noun` names the file in the
## refusals ("Mod definition set", "Mod bundle"), `arguments` are the tool's
## own options after the file (never `--extract`), and `extract_prefix` is the
## `user://` directory prefix of the extract tree. `consume` receives
## `{extract_root, file_sha256, verdict}` once the verdict is `ok` and the file
## is unchanged, and returns the caller's result; the tree it reads is removed
## when it returns. Any refusal is `{ok: false, error}`.
static func run(tool: String, noun: String, file_path: String, arguments: PackedStringArray,
		extract_prefix: String, consume: Callable) -> Dictionary:
	var runtime := PythonRuntimeScript.resolve(tool)
	if not runtime.get("ok", false):
		return _error(str(runtime.get("error", "The Python runtime is unavailable.")))
	var file_absolute := ProjectSettings.globalize_path(file_path)
	var sha_before := FileAccess.get_sha256(file_absolute)
	if sha_before.is_empty():
		return _error("%s file is unavailable." % noun)
	var extract_root := ProjectSettings.globalize_path("user://" + extract_prefix + Crypto.new().generate_random_bytes(16).hex_encode())
	var command := PackedStringArray(["-B", str(runtime.script), "validate", file_absolute])
	command.append_array(arguments)
	command.append("--extract")
	command.append(extract_root)
	var output: Array = []
	var exit_code := OS.execute(str(runtime.python), command, output, true, false)
	var verdict := last_json_line(output)
	var result: Dictionary
	if exit_code != 0 or not bool(verdict.get("ok", false)):
		result = _error(str(verdict.get("error", "%s validation failed (exit code %d)." % [noun, exit_code])))
	elif FileAccess.get_sha256(file_absolute) != sha_before:
		result = _error("%s file changed during validation." % noun)
	else:
		result = consume.call({"extract_root": extract_root, "file_sha256": sha_before, "verdict": verdict})
	remove_tree(extract_root)
	return result


## The last non-empty line of a tool's output as a JSON object; `{}` when
## there is none or it is not an object.
static func last_json_line(output: Array) -> Dictionary:
	var joined := ""
	for chunk in output:
		joined += str(chunk)
	var lines := joined.split("\n")
	for index in range(lines.size() - 1, -1, -1):
		var trimmed := str(lines[index]).strip_edges()
		if trimmed.is_empty():
			continue
		var json := JSON.new()
		if json.parse(trimmed) == OK and json.data is Dictionary:
			return json.data
		return {}
	return {}


static func remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for subdirectory in directory.get_directories():
		remove_tree(path.path_join(subdirectory))
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	DirAccess.remove_absolute(path)


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
