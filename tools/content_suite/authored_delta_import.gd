extends RefCounted

## The staged-import engine of the authored-content importers (WD-10): one
## fresh workspace is built in a `.staging-<hex>` sibling from a template
## workspace's project, every member is reconstructed or staged into it with one
## staging transaction per kind, the stage is reopened and its effective
## identities are checked, and only then does the existing lock-and-rename
## publication move it to its new destination. A failure leaves the stage as
## local evidence and never publishes it.
##
## There are two front doors. `import_delta` takes one
## `kakyu_authored_mod_delta` file and keeps its original contract and
## messages. `tools/content_suite/mod_bundle_import.gd` takes a
## `kakyu_mod_bundle/v1` and builds a plan of many members for
## `import_members`.
##
## A `plan` is a Dictionary:
##   kind          "Delta" or "Bundle" - the noun of the refusals and the lock
##   suffix        the project-id suffix of the new workspace
##   name_members  true to prefix a member's refusal with its entry
##   deltas        [{file, bundle_dir}] - an extracted delta file and the
##                 stage-relative directory its authoring bundle reconstructs into
##   text_rows     [{entry, source_entry_sha256, edits}] - translation-only
##                 entries
##   set_file      a definition-set file to import into the stage, or ""
##   expect        {archive_sha256?, mod_id?, definition_count?,
##                 definition_hashes?} - identities the stage must reopen with

const WorkspaceScript := preload("res://content_core/content_workspace.gd")
const ReaderScript := preload("res://content_core/arc_reader.gd")
const SessionScript := preload("res://tools/content_suite/mes_authoring_session.gd")
const LockScript := preload("res://content_core/publication_lock.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ResolverScript := preload("res://content_core/content_resolver.gd")
const ContractValuesScript := preload("res://content_core/contract_values.gd")
const SetImportScript := preload("res://tools/content_suite/mod_definition_set_import.gd")


# Headless import only: reconstruct and validate a fresh workspace in staging.
func import_delta(source_root: String, source_workspace: String, delta_path: String, output_root: String) -> Dictionary:
	var plan := {
		"kind": "Delta", "suffix": ".delta", "name_members": false,
		"deltas": [{"file": delta_path, "bundle_dir": ".authoring/delta"}],
		"text_rows": [], "set_file": "", "expect": {},
	}
	var imported := import_members(source_root, source_workspace, plan, output_root)
	if not imported.get("ok", false):
		return imported
	var member: Dictionary = imported.deltas[0]
	return {"ok": true, "schema": str(member.schema), "delta_file_sha256": str(member.delta_file_sha256),
		"output_entry_sha256": str(member.output_entry_sha256), "authored_text_count": int(member.authored_text_count),
		"workspace": str(imported.workspace)}


## Builds the plan's members into one new workspace at `output_root`:
## `{ok, deltas: [{entry, schema, delta_file_sha256, output_entry_sha256,
## authored_text_count}], text_rows: [{entry, authored_text_count}],
## set: <the set importer's result or {}>, workspace}`, or `{ok: false, error}`.
func import_members(source_root: String, template_workspace: String, plan: Dictionary, output_root: String) -> Dictionary:
	var noun := str(plan.kind)
	var refused := destination_error(noun, source_root, output_root)
	if not refused.is_empty():
		return refused
	var destination := ProjectSettings.globalize_path(output_root).replace("\\", "/").simplify_path()
	var source := ProjectSettings.globalize_path(source_root).replace("\\", "/").simplify_path()
	var original := WorkspaceScript.new()
	var opened := original.open(template_workspace, source)
	if not opened.get("ok", false):
		return opened
	var project: Dictionary = original.get_snapshot().project.duplicate(true)
	original.close()
	var expected_archive := str(plan.expect.get("archive_sha256", ""))
	if not expected_archive.is_empty() and _archive_binding(project) != expected_archive:
		return _error("%s template workspace binds another mes.arc than the %s's." % [noun, noun.to_lower()])
	project.project_id = str(project.project_id).left(48) + str(plan.suffix)
	project.project_revision = 1
	var lock := LockScript.new().acquire(destination.get_base_dir(), ".%s.%s.lock" % [destination.get_file(), noun.to_lower()])
	if not lock.get("ok", false):
		return lock
	var stage := destination + ".staging-" + Crypto.new().generate_random_bytes(12).hex_encode()
	var imported := _import_staged(source, project, plan, stage)
	if imported.get("ok", false):
		if DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination) or DirAccess.rename_absolute(stage, destination) != OK:
			imported = _error("%s staging passed but its new destination could not be published." % noun)
		else:
			imported["workspace"] = destination
	var released := LockScript.new().release(lock)
	if not released.get("ok", false):
		return released
	return imported


## `{}` when `output_root` is a new location outside the original content set,
## the refusal otherwise.
static func destination_error(noun: String, source_root: String, output_root: String) -> Dictionary:
	var destination := ProjectSettings.globalize_path(output_root).replace("\\", "/").simplify_path()
	var source := ProjectSettings.globalize_path(source_root).replace("\\", "/").simplify_path()
	if destination.to_lower() == source.to_lower() or destination.to_lower().begins_with(source.to_lower().trim_suffix("/") + "/"):
		return _error("%s output must be outside the original content set." % noun)
	if DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination):
		return _error("%s import requires a new workspace destination." % noun)
	return {}


func _import_staged(source: String, project: Dictionary, plan: Dictionary, stage: String) -> Dictionary:
	var delta_rows: Array = plan.deltas
	var python := ""
	var tool_script := ""
	if not delta_rows.is_empty():
		var runtime := preload("res://tools/content_suite/python_runtime.gd").resolve("tools/authored_mod_delta.py")
		if not runtime.get("ok", false):
			return runtime
		python = str(runtime.python)
		tool_script = str(runtime.script)
	var workspace := WorkspaceScript.new()
	var created := workspace.create(stage, source, project)
	if not created.get("ok", false):
		return created
	var archive_path := source.path_join("mes.arc")
	var library_audit_path := ""
	if not delta_rows.is_empty():
		var library_reader := ReaderScript.new()
		var has_library := library_reader.open(archive_path) and not library_reader.get_entry("LIBLARY.LIB").is_empty()
		library_reader.close()
		if has_library:
			DirAccess.make_dir_recursive_absolute(stage.path_join(".authoring"))
			library_audit_path = stage.path_join(".authoring/library-audit.json")
			var written := preload("res://tools/content_suite/mes_library_audit_report.gd").new().write(archive_path, library_audit_path)
			if not written.get("ok", false):
				workspace.close()
				return _error(str(written.get("error", "The Godot library audit could not be built.")))

	var replacements := {}
	var edits_by_entry := {}
	var claimed := {}
	var delta_members: Array = []
	for untyped_row in delta_rows:
		var row: Dictionary = untyped_row
		var delta_path := str(row.file)
		var bundle_root := stage.path_join(str(row.bundle_dir))
		var delta_bytes := FileAccess.get_file_as_bytes(delta_path)
		var delta_sha := OverlayPackageScript.sha256_bytes(delta_bytes)
		var arguments := PackedStringArray([
			"-B", tool_script, "reconstruct",
			archive_path, ProjectSettings.globalize_path(delta_path), bundle_root])
		if not library_audit_path.is_empty():
			arguments.append("--library-audit")
			arguments.append(library_audit_path)
		var output: Array = []
		var code := OS.execute(python, arguments, output, true, false)
		var bundle := SessionScript.read_bundle(bundle_root) if code == 0 else _error("Python delta reconstruction failed.")
		var parsed = JSON.parse_string(delta_bytes.get_string_from_utf8())
		var entry := str(parsed.source.entry) if parsed is Dictionary and parsed.get("source") is Dictionary else ""
		if not bundle.get("ok", false) or FileAccess.get_sha256(delta_path) != delta_sha or not parsed is Dictionary:
			workspace.close()
			return _member_error(plan, entry, "Delta reconstruction or immutable input verification failed; staging was not published.")
		# JSON.parse_string yields every number as a float; the integer fields
		# (source offsets) fold back through the Core's one helper.
		var delta: Dictionary = ContractValuesScript.intify(parsed)
		if str(bundle.proof.output_binding.entry_sha256) != str(delta.output_entry_sha256) or str(bundle.proof.payload_sha256) != str(delta.semantic_diff_sha256):
			workspace.close()
			return _member_error(plan, entry, "Reconstructed proof differs from the imported delta.")
		if claimed.has(entry.to_upper()):
			workspace.close()
			return _member_error(plan, entry, "Two members change one entry.")
		claimed[entry.to_upper()] = true
		var reader := ReaderScript.new()
		if not reader.open(archive_path):
			workspace.close()
			return _error(reader.last_error)
		var verified := SessionScript.validate_source(bundle, reader.read_entry(entry))
		reader.close()
		if not verified.get("ok", false):
			workspace.close()
			return verified if not bool(plan.name_members) else _member_error(plan, entry, str(verified.get("error", "")))
		replacements[entry] = bundle.files["output.mes"]
		if not delta.text_edits.is_empty():
			edits_by_entry[entry] = delta.text_edits
		delta_members.append({"entry": entry, "schema": str(delta.schema), "delta_file_sha256": delta_sha,
			"output_entry_sha256": str(delta.output_entry_sha256), "authored_text_count": delta.text_edits.size(),
			"source_entry_sha256": str(delta.get("source_entry_sha256", ""))})

	var text_members: Array = []
	for untyped_text_row in plan.text_rows:
		var text_row: Dictionary = untyped_text_row
		var text_entry := str(text_row.entry)
		if claimed.has(text_entry.to_upper()):
			workspace.close()
			return _member_error(plan, text_entry, "Two members change one entry.")
		claimed[text_entry.to_upper()] = true
		edits_by_entry[text_entry] = ContractValuesScript.intify(text_row.edits)
		text_members.append({"entry": text_entry, "authored_text_count": (text_row.edits as Array).size(),
			"source_entry_sha256": str(text_row.source_entry_sha256)})

	# One staging transaction per kind: every replacement, then every projection.
	var staged := {"ok": true}
	if not replacements.is_empty():
		staged = workspace.stage_replacements("mes.arc", replacements, "remake_only", "cp932")
	if staged.get("ok", false) and not edits_by_entry.is_empty():
		staged = workspace.stage_mes_text_projections("mes.arc", edits_by_entry)
	if staged.get("ok", false):
		staged = workspace.refresh()
	workspace.close()
	if not staged.get("ok", false):
		return staged

	var set_result := {}
	var set_file := str(plan.set_file)
	if not set_file.is_empty():
		set_result = SetImportScript.new().import_set(source, stage, set_file, false)
		if not set_result.get("ok", false):
			return set_result
		var expected_count := int(plan.expect.get("definition_count", -1))
		if int(set_result.added) != expected_count or int(set_result.replaced) != 0 or int(set_result.unchanged) != 0:
			return _error("The fresh workspace did not receive every definition of the %s." % str(plan.kind).to_lower())

	var verified_stage := _verify_stage(source, stage, plan, delta_members, text_members, edits_by_entry)
	if not verified_stage.get("ok", false):
		return verified_stage
	for member in delta_members:
		(member as Dictionary).erase("source_entry_sha256")
	for member in text_members:
		(member as Dictionary).erase("source_entry_sha256")
	return {"ok": true, "deltas": delta_members, "text_rows": text_members, "set": set_result}


## Reopens the stage and checks what it resolves to against the plan: every
## delta entry to its output hash, every projection to exactly the planned
## edits, the counts, and the definitions' identity. Without a set the
## workspace's `mod_id` is empty: it is derived from definitions and has no
## standalone field, so a deltas-only bundle's declared mod is not persisted.
func _verify_stage(source: String, stage: String, plan: Dictionary, delta_members: Array,
		text_members: Array, edits_by_entry: Dictionary) -> Dictionary:
	var workspace := WorkspaceScript.new()
	var opened := workspace.open(stage, source)
	if not opened.get("ok", false):
		return opened
	var snapshot := workspace.get_snapshot()
	workspace.close()
	var failure := "The reopened %s workspace differs from what was imported: " % str(plan.kind).to_lower()
	if int(snapshot.replacement_count) != delta_members.size() or int(snapshot.projection_count) != edits_by_entry.size():
		return _error(failure + "its replacement or projection count.")
	var archive_sha := _archive_binding(snapshot.project)
	var resolver := ResolverScript.new()
	if not resolver.register_original_archive("mes.arc", source.path_join("mes.arc")) or not resolver.configure_overlay(stage):
		var resolver_error := resolver.last_error
		resolver.close()
		return _error(resolver_error)
	for untyped_member in delta_members:
		var member: Dictionary = untyped_member
		var descriptor := resolver.resolve("mes.arc", str(member.entry))
		if str(descriptor.get("source", "")) != "overlay" or OverlayPackageScript.sha256_bytes(resolver.read_resolved(descriptor)) != str(member.output_entry_sha256):
			resolver.close()
			return _error(failure + "the effective %s." % str(member.entry))
	resolver.close()
	var source_hashes := {}
	for untyped_member in delta_members + text_members:
		source_hashes[str((untyped_member as Dictionary).entry)] = str((untyped_member as Dictionary).source_entry_sha256)
	for entry in edits_by_entry:
		var projection := OverlayPackageScript.new().load_mes_text_projection(stage, "mes.arc", str(entry), archive_sha, str(source_hashes[entry]))
		var planned: Array = edits_by_entry[entry]
		var loaded: Array = projection.get("edits", [])
		var same: bool = bool(projection.get("ok", false)) and bool(projection.get("found", false)) and loaded.size() == planned.size()
		for index in range(planned.size() if same else 0):
			var left: Dictionary = loaded[index]
			var right: Dictionary = planned[index]
			same = same and left.source_offset == int(right.source_offset) and left.raw_sha256 == str(right.raw_sha256) and left.text == str(right.text)
		if not same:
			return _error(failure + "the translations of %s." % str(entry))
	var expected: Dictionary = plan.expect
	var definitions: Array = snapshot.manifest.get("definitions", [])
	if str(snapshot.mod_id) != str(expected.get("mod_id", "")) or int(snapshot.definition_count) != int(expected.get("definition_count", 0)):
		return _error(failure + "its mod identity or definition count.")
	var expected_hashes: Dictionary = expected.get("definition_hashes", {})
	if definitions.size() != expected_hashes.size():
		return _error(failure + "its definitions.")
	for untyped_record in definitions:
		var record: Dictionary = untyped_record
		if str(expected_hashes.get(str(record.definition_id), "")) != str(record.definition_sha256):
			return _error(failure + "the definition %s." % str(record.definition_id))
	return {"ok": true}


static func _archive_binding(project: Dictionary) -> String:
	for untyped_row in project.get("source_content_set", {}).get("archives", []):
		var row: Dictionary = untyped_row
		if str(row.get("archive", "")) == "mes.arc":
			return str(row.get("sha256", ""))
	return ""


func _member_error(plan: Dictionary, entry: String, message: String) -> Dictionary:
	return _error("%s: %s" % [entry, message] if bool(plan.name_members) and not entry.is_empty() else message)


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
