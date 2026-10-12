class_name KakyuModDefinitionBinding
extends RefCounted

## Tool-layer binding that runs the Python `kakyu_mod_event_definition/v1`
## contract validator (`tools/validate_mod_event_definition.py`) on one
## document's bytes, the same pattern `mes_authoring_binding.gd` uses to call
## a Python tool (mod event definition unit B, section C).

const ContractValues := preload("res://content_core/contract_values.gd")
const ExtractScript := preload("res://tools/content_suite/python_validated_extract.gd")

const DEFAULT_NAMES_DIR := "config/contracts/event_names_v1"
const DEFAULT_DEFINITIONS_DIR := "config/event_definitions/v4"

static var _cache: Dictionary = {}


static func validate(
	document: PackedByteArray,
	names_dir := DEFAULT_NAMES_DIR,
	definitions_dir := DEFAULT_DEFINITIONS_DIR
) -> Dictionary:
	var key := "%s|%s|%s" % [ContractValues.sha256(document), names_dir, definitions_dir]
	if _cache.has(key):
		return (_cache[key] as Dictionary).duplicate(true)
	var runtime := preload("res://tools/content_suite/python_runtime.gd").resolve("tools/validate_mod_event_definition.py")
	if not runtime.get("ok", false):
		return _error(str(runtime.get("error", "The Python runtime is unavailable.")))
	var python := str(runtime.python)
	var root := ProjectSettings.globalize_path("user://moddef-validate-" + Crypto.new().generate_random_bytes(16).hex_encode())
	if DirAccess.make_dir_absolute(root) != OK:
		return _error("A local mod definition validation directory could not be created.")
	var document_path := root.path_join("document.json")
	var file := FileAccess.open(document_path, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(root)
		return _error("Could not write the mod definition document for validation.")
	file.store_buffer(document)
	file.close()
	var names_absolute := ProjectSettings.globalize_path(names_dir)
	var definitions_absolute := ProjectSettings.globalize_path(definitions_dir)
	var output: Array = []
	var exit_code := OS.execute(python, PackedStringArray([
		"-B", str(runtime.script), document_path,
		"--names", names_absolute,
		"--definitions-dir", definitions_absolute,
	]), output, true, false)
	if FileAccess.file_exists(document_path):
		DirAccess.remove_absolute(document_path)
	if DirAccess.dir_exists_absolute(root):
		DirAccess.remove_absolute(root)
	var verdict := ExtractScript.last_json_line(output)
	if verdict.is_empty():
		return _error("Mod definition validation produced no verdict (exit code %d)." % exit_code)
	var result := {
		"ok": bool(verdict.get("ok", false)),
		"reason": str(verdict.get("reason", "")),
		"detail": str(verdict.get("detail", "")),
	}
	if _cache.size() >= 8:
		_cache.clear()
	_cache[key] = result.duplicate(true)
	return result


static func validator() -> Callable:
	return validate


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
