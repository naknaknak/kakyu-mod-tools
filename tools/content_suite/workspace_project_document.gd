extends RefCounted

## The `kakyu_content_project/v1` document of a workspace built straight from a
## source content set - the project every archive-backed headless check used to
## assemble inline (WD-10: extracted from the selection-handoff original
## validator's fixture so the mod bundle checks share it). Every archive of the
## set is bound by its fingerprint, only `mes.arc` is required, and every archive
## is a target. The Launcher keeps its own copy until WD-24 migrates it.

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentSetScript := preload("res://content_core/content_set.gd")


## `{ok: true, project, source_hashes}` - `source_hashes` maps each archive name
## to its fingerprint - or `{ok: false, error}`.
static func from_content_set(source_root: String, project_id: String, display_name: String,
		profile_id: String, catalog_id: String) -> Dictionary:
	var content_set := ContentSetScript.new()
	if not content_set.open(source_root):
		return {"ok": false, "error": content_set.last_error}
	var archive_names: Array[String] = []
	for archive_name in content_set.get_archive_names():
		archive_names.append(str(archive_name))
	archive_names.sort()
	var archives: Array[Dictionary] = []
	var source_hashes := {}
	for archive_name in archive_names:
		var source_reader: KakyuArcReader = content_set.get_reader(archive_name)
		var archive_sha := source_reader.get_archive_fingerprint()
		archives.append({"archive": archive_name, "sha256": archive_sha, "required": archive_name == "mes.arc"})
		source_hashes[archive_name] = archive_sha
	content_set.close()
	var project := {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"project_id": project_id,
		"project_version": "0.1.0", "display_name": display_name,
		"project_revision": 1,
		"content_core": {
			"minimum_version": ContentCoreVersionScript.CORE_VERSION,
			"maximum_exclusive": "1.0.0",
		},
		"source_content_set": {
			"profile_id": profile_id,
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": archive_names, "compatibility_objective": "mixed",
		"dependencies": [],
		"event_player": {"catalog_id": catalog_id, "presets": []},
		"overlay_manifest": "manifest.json",
	}
	return {"ok": true, "project": project, "source_hashes": source_hashes}
