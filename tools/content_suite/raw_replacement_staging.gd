class_name KakyuRawReplacementStaging
extends RefCounted

## Conservative raw replacement staging for the ARC Browser: stage one raw
## file as the replacement of one existing entry into a named workspace's
## overlay. No add, delete, rename or reorder, no directory import, and
## never silently past a format the repository can check.

const ContentSetScript := preload("res://content_core/content_set.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const AudioEntryValidatorScript := preload("res://content_core/audio_entry_validator.gd")
const AxWriterScript := preload("res://content_core/ax_writer.gd")
const A6LayoutScript := preload("res://content_core/a6_layout.gd")
const MmoCodecScript := preload("res://content_core/mmo_codec.gd")

const MAX_BYTES := 64 * 1024 * 1024
const AUDIO_HEADER_WINDOW := 64 * 1024


static func check(archive_name: String, entry_name: String, original: PackedByteArray, replacement: PackedByteArray) -> Dictionary:
	if replacement.is_empty():
		return {"ok": false, "error": "Raw replacement is empty."}
	if replacement.size() > MAX_BYTES:
		return {"ok": false, "error": "Raw replacement exceeds the 64 MiB raw staging limit; use the specialist editor."}
	if replacement == original:
		return {"ok": false, "error": "Replacement is identical to the original entry; nothing to stage."}

	var extension := entry_name.get_extension().to_lower()
	match extension:
		"mes", "lib":
			var parsed := MesContainerScript.new().parse(replacement)
			if not parsed.get("ok", false):
				return _invalid(entry_name, parsed)
			return {"ok": true, "format": "mes", "validated": true, "note": ""}
		"wav", "ogg":
			var header := replacement.slice(0, mini(AUDIO_HEADER_WINDOW, replacement.size()))
			var validated := AudioEntryValidatorScript.validate(entry_name, header, replacement.size())
			if not validated.get("ok", false):
				return _invalid(entry_name, validated)
			return {"ok": true, "format": "audio", "validated": true, "note": ""}
		"ax":
			var reopened := AxWriterScript.new().reopen(replacement)
			if not reopened.get("ok", false):
				return _invalid(entry_name, reopened)
			return {"ok": true, "format": "ax", "validated": true, "note": ""}
		"a6":
			var inspected_a6 := A6LayoutScript.new().inspect(replacement)
			if not inspected_a6.get("ok", false):
				return _invalid(entry_name, inspected_a6)
			return {"ok": true, "format": "a6", "validated": true, "note": ""}
		"mmo":
			var inspected_mmo := MmoCodecScript.new().inspect(replacement)
			if not inspected_mmo.get("ok", false):
				return _invalid(entry_name, inspected_mmo)
			return {"ok": true, "format": "mmo", "validated": true, "note": ""}
		_:
			return {
				"ok": true,
				"format": "opaque",
				"validated": false,
				"note": "No validator exists for this entry type; the bytes are staged as they are.",
			}


static func stage(workspace_root: String, content_set_root: String, archive_name: String, entry_name: String, replacement_path: String) -> Dictionary:
	var workspace := ContentWorkspaceScript.new()
	var opened := workspace.open(workspace_root, content_set_root)
	if not opened.get("ok", false):
		workspace.close()
		return {"ok": false, "error": str(opened.get("error", ""))}

	var content_set := ContentSetScript.new()
	if not content_set.open(content_set_root):
		workspace.close()
		return {"ok": false, "error": content_set.last_error}

	var reader = content_set.get_reader(archive_name)
	if reader == null:
		content_set.close()
		workspace.close()
		return {"ok": false, "error": "Source archive is unavailable in the content set: %s" % archive_name}

	var entry: Dictionary = reader.get_entry(entry_name)
	if entry.is_empty():
		content_set.close()
		workspace.close()
		return {"ok": false, "error": "Target entry does not exist in the source archive: %s" % entry_name}

	var canonical_entry_name := str(entry.name)
	var original: PackedByteArray = reader.read_entry(canonical_entry_name)
	if not reader.last_error.is_empty():
		content_set.close()
		workspace.close()
		return {"ok": false, "error": "Could not read the original entry: %s" % reader.last_error}

	var file := FileAccess.open(replacement_path, FileAccess.READ)
	if file == null:
		content_set.close()
		workspace.close()
		return {"ok": false, "error": "Could not open the raw replacement file (error %s)." % FileAccess.get_open_error()}
	var length := file.get_length()
	if length > MAX_BYTES:
		file.close()
		content_set.close()
		workspace.close()
		return {"ok": false, "error": "Raw replacement exceeds the 64 MiB raw staging limit; use the specialist editor."}
	var replacement := file.get_buffer(length)
	var read_error := file.get_error()
	file.close()
	if replacement.size() != length or read_error != OK:
		content_set.close()
		workspace.close()
		return {"ok": false, "error": "Raw replacement file changed or was truncated while reading."}

	var checked := check(archive_name, canonical_entry_name, original, replacement)
	if not checked.get("ok", false):
		content_set.close()
		workspace.close()
		return checked

	var staged := workspace.stage_replacements(
		archive_name, {canonical_entry_name: replacement}, "remake_only", "not_applicable"
	)
	content_set.close()
	if not staged.get("ok", false):
		var stage_error := str(staged.get("error", ""))
		workspace.close()
		return {"ok": false, "error": stage_error}

	var snapshot: Dictionary = staged.snapshot
	var result := {
		"ok": true,
		"format": str(checked.format),
		"validated": bool(checked.validated),
		"note": str(checked.note),
		"replacement_sha256": OverlayPackageScript.sha256_bytes(replacement),
		"replacement_size": replacement.size(),
		"generation_sha256": str(snapshot.generation_sha256),
	}
	workspace.close()
	return result


static func _invalid(entry_name: String, validation: Dictionary) -> Dictionary:
	var label := entry_name.get_extension().to_upper()
	return {
		"ok": false,
		"error": "Replacement is not a valid %s entry: %s" % [label, str(validation.get("error", ""))],
	}
