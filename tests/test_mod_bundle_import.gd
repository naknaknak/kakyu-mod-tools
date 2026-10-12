extends "res://tests/test_case.gd"

## WD-10 synthetic mode: a `kakyu_mod_bundle/v1` built by `tools/mod_bundle.py`
## from an authored workspace over a three-entry synthetic `mes.arc` is imported
## into one fresh workspace by `tools/content_suite/mod_bundle_import.gd`, the
## second front door of the staged-import engine. The authoring is headless
## (`tools/mes_authoring_workflow.py inspect` / `compile`, then the workspace
## staging calls); every translation string is synthetic.
##
## Entry A takes a state edit, entry B a state edit and a translation, entry C a
## translation only, and the workspace has one `new_event` definition. A
## deltas-only bundle shows that the declared mod identity is verified and not
## persisted; the refusals each leave no destination.
##
## Original mode (`original_source_root` set by
## `tools/content_suite/validators/validate_mod_bundle_original.gd`, the archive
## check "original mod bundle round trip"): the same round trip over the original
## `mes.arc` read-only - `EVENTB01.MES` with a state edit at 0x8F, `EVENTB03.MES`
## with a state edit at 0x76 and a translation, `EVENTB02.MES` with a
## translation only, and one `new_event` definition. Everything is written under
## `user://` (the batch gives each worker its own), removed on every exit; the
## translations are synthetic strings, never original text. Only the happy path
## runs (the refusals are the synthetic mode's), and it prints one PASS line with
## entries, offsets, counts and the bundle's payload hash and no text.

const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ResolverScript := preload("res://content_core/content_resolver.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ModDefinitionBindingScript := preload("res://tools/content_suite/mod_definition_binding.gd")
const ImporterScript := preload("res://tools/content_suite/mod_bundle_import.gd")
const EngineScript := preload("res://tools/content_suite/authored_delta_import.gd")
const ExtractScript := preload("res://tools/content_suite/python_validated_extract.gd")
const ProjectDocumentScript := preload("res://tools/content_suite/workspace_project_document.gd")
const ProvenanceReportScript := preload("res://tools/content_suite/provenance_report.gd")
const PythonRuntimeScript := preload("res://tools/content_suite/python_runtime.gd")
const SessionScript := preload("res://tools/content_suite/mes_authoring_session.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")
const TestHelpers := preload("res://tests/test_helpers.gd")

const TEST_ROOT := "user://mod_bundle_import_test"

const ENTRY_A := "EVENT_A.MES"
const ENTRY_B := "EVENT_B.MES"
const ENTRY_C := "EVENT_C.MES"
# One state write and one message each (code-relative message offset 6); the
# three differ in the message only.
const SOURCE_HEX := {
	ENTRY_A: "0100000000000000031e0101ff000182a00000",
	ENTRY_B: "0100000000000000031e0101ff000182a20000",
	ENTRY_C: "0100000000000000031e0101ff000182a40000",
}
const MESSAGE_HEX := {ENTRY_A: "82a0", ENTRY_B: "82a2", ENTRY_C: "82a4"}
const MESSAGE_OFFSET := 6
const TEXT_B := "번들 확인 2"
const TEXT_C := "번들 확인 3"
const MOD_ID := "modbundleimport"

# Original mode: the state write each authored entry edits (source offsets) and
# the value written. The translated message is the entry's first one.
const ORIGINAL_A := "EVENTB01.MES"
const ORIGINAL_B := "EVENTB03.MES"
const ORIGINAL_C := "EVENTB02.MES"
const ORIGINAL_STATE_OFFSET := {ORIGINAL_A: 0x8F, ORIGINAL_B: 0x76}
const ORIGINAL_STATE_VALUE := 2

## Re-signs a copy of a built bundle after a forger's change, the way
## `tests/test_mod_bundle.py` does (the delta, the row and the bundle hashes),
## so that the payload hash is never the reason for a refusal.
const FORGE_SCRIPT := """import copy, json, sys
tools, source, target, mutation = sys.argv[1:5]
sys.path.insert(0, tools)
import authored_mod_delta as delta
import mes_authoring_workflow as workflow
import mod_bundle
document = json.loads(open(source, encoding='utf-8').read())
def resign_delta(row):
    row['document']['payload_sha256'] = delta.fingerprint(row['document'])
    row['delta_sha256'] = workflow._sha(workflow._json(row['document']))
if mutation == 'duplicate_delta':
    document['deltas'].append(copy.deepcopy(document['deltas'][0]))
elif mutation == 'other_archive':
    row = document['deltas'][0]
    row['document']['source']['archive_sha256'] = '1' * 64
    resign_delta(row)
elif mutation == 'other_mod':
    document['mod']['id'] = 'someothermod'
elif mutation == 'tampered_member':
    row = document['deltas'][0]
    row['document']['operations'][0]['value'] += 1
    resign_delta(row)
elif mutation != 'stale_payload':
    raise SystemExit('unknown mutation')
document['payload_sha256'] = '0' * 64 if mutation == 'stale_payload' else mod_bundle.fingerprint(document)
open(target, 'wb').write(workflow._json(document))
print(json.dumps({'ok': True}))
"""

## Non-empty selects original mode: the read-only original content set.
var original_source_root := ""

var _counter := 0
var _root := ""
var _scratch := ""
var _assertions := 0
var _messages := {}


## Original mode reports failures only (and its one PASS line at the end), so the
## archive check's output stays a single line; every assertion is still counted.
func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if condition and not original_source_root.is_empty():
		return
	super._check(condition, label)


func _ready() -> void:
	_cleanup()
	var original := not original_source_root.is_empty()
	_root = ProjectSettings.globalize_path(TEST_ROOT)
	_scratch = _root.path_join("scratch")
	var bundles := _root.path_join("bundles")
	var entry_a := ORIGINAL_A if original else ENTRY_A
	var entry_b := ORIGINAL_B if original else ENTRY_B
	var entry_c := ORIGINAL_C if original else ENTRY_C
	var source_root := ProjectSettings.globalize_path(original_source_root).replace("\\", "/").simplify_path() if original else _root.path_join("ELFIMAGE")
	var other_root := _root.path_join("ELFIMAGE_OTHER")
	var media_root := _root.path_join("ELFIMAGE_MEDIA")
	DirAccess.make_dir_recursive_absolute(_scratch)
	DirAccess.make_dir_recursive_absolute(bundles)
	if original:
		if not FileAccess.file_exists(source_root.path_join("mes.arc")):
			_check(false, "the original content set holds mes.arc")
			_finish()
			return
	else:
		for path in [source_root, other_root, media_root]:
			DirAccess.make_dir_recursive_absolute(path)
		_write_arc(source_root, "")
		_write_arc(other_root, "other")
		_write_arc(media_root, "")
		SyntheticArc.write_arc(media_root.path_join("mmo.arc"), [{"name": "X.BIN", "data": PackedByteArray([1, 2, 3, 4])}])
	var arc_path := source_root.path_join("mes.arc")
	var arc_sha_before := FileAccess.get_sha256(arc_path)
	var source_stamp_before := _directory_stamp(source_root)

	var template_root := _root.path_join("template")
	var template := _new_workspace(template_root, source_root, "bundle.import.template")
	_check(template != null, "the template workspace is created on the %s archive" % ("original" if original else "synthetic"))
	if template == null:
		_finish()
		return
	template.close()
	var template_manifest_before := FileAccess.get_sha256(template_root.path_join("manifest.json"))
	var other_template_root := _root.path_join("template_other")
	if not original:
		var other_template := _new_workspace(other_template_root, other_root, "bundle.import.other")
		_check(other_template != null, "a template workspace on another archive is created")
		other_template.close()

	# ---- The authored workspaces, built through the real staging calls.
	var contract_fp := FileAccess.get_file_as_string("res://config/contracts/mod_event_definition_v1/contract_fingerprint").strip_edges()
	var cells_fp := FileAccess.get_file_as_string("res://config/contracts/state_cells_v1/cells_fingerprint").strip_edges()
	var document := TestHelpers.new_event_definition_document(contract_fp, cells_fp, "번들 확인 대사", MOD_ID)

	var full_root := _root.path_join("authoring_full")
	var full := _new_workspace(full_root, source_root, "bundle.import.full")
	if full == null:
		_check(false, "the authoring workspace is created")
		_finish()
		return
	var output_a := _author(source_root, full_root, entry_a, "state", ORIGINAL_STATE_VALUE if original else 2)
	var output_b := _author(source_root, full_root, entry_b, "state", ORIGINAL_STATE_VALUE if original else 3)
	_check(not output_a.is_empty() and not output_b.is_empty(), "entries A and B are authored headlessly through inspect and compile")
	_check(full.stage_replacements("mes.arc", {entry_a: output_a, entry_b: output_b}, "remake_only", "cp932").get("ok", false), "both authored replacements are staged in one call")
	var message_b := _message_of(source_root, entry_b)
	var message_c := _message_of(source_root, entry_c)
	_check(not message_b.is_empty() and not message_c.is_empty(), "B and C each have a message a translation binds to")
	if not original:
		_check(int(message_b.source_offset) == MESSAGE_OFFSET and str(message_b.raw_sha256) == _sha(String(MESSAGE_HEX[ENTRY_B]).hex_decode()), "the discovered message of B is the synthetic one")
	var edit_b := _edit(message_b, TEXT_B)
	var edit_c := _edit(message_c, TEXT_C)
	_check(full.stage_mes_text_projections("mes.arc", {entry_b: [edit_b], entry_c: [edit_c]}).get("ok", false), "the translation on B and the translation-only entry C are staged in one call")
	_check(full.stage_mod_definitions([TestHelpers.definition_document_bytes(document)], ModDefinitionBindingScript.validator()).get("ok", false), "the one new_event definition is staged through the real validator")
	full.close()

	var full_bundle := bundles.path_join("full.json")
	var built := _build_bundle(arc_path, full_root, full_bundle, [])
	_check(built.get("ok", false) and int(built.delta_count) == 2 and int(built.text_projection_count) == 1 and int(built.definition_count) == 1, "mod_bundle.py builds two deltas, one translation-only entry and one definition")
	if not built.get("ok", false):
		print("BUNDLE_BUILD_FAILURE ", built)
		_finish()
		return

	# ---- The full import.
	var importer := ImporterScript.new()
	var destination := _root.path_join("imported_full")
	var imported := importer.import_bundle(source_root, template_root, full_bundle, destination)
	_check(imported.get("ok", false), "the full bundle imports into one fresh workspace")
	if not imported.get("ok", false):
		print("BUNDLE_IMPORT_FAILURE ", imported)
		_finish()
		return
	_check(str(imported.schema) == "kakyu_mod_bundle/v1" and str(imported.mod_id) == MOD_ID and int(imported.mod_revision) == 1, "the result names the schema and the mod identity")
	_check(bool(imported.mod_persisted), "a bundle with a definition set persists its mod identity")
	_check(int(imported.delta_count) == 2 and int(imported.text_projection_count) == 1 and int(imported.definition_count) == 1, "the result counts the deltas, the translation-only entries and the definitions")
	_check(str(imported.bundle_file_sha256) == FileAccess.get_sha256(full_bundle), "the result carries the bundle file's SHA-256")
	_check(str(imported.workspace) == destination, "the result names the published workspace")
	# The members come sorted by entry name, whatever role each entry plays.
	var members: Array = imported.members
	var expected_order := [entry_a, entry_b, entry_c]
	expected_order.sort()
	var by_entry := {}
	for untyped_member in members:
		by_entry[str(untyped_member.entry)] = untyped_member
	var member_order: Array = []
	for untyped_member in members:
		member_order.append(str(untyped_member.entry))
	_check(members.size() == 3 and member_order == expected_order and by_entry.size() == 3, "the members are listed by entry")
	_check(by_entry.has(entry_a) and by_entry.has(entry_b) and by_entry.has(entry_c)
		and int(by_entry[entry_a].authored_text_count) == 0 and int(by_entry[entry_b].authored_text_count) == 1 and int(by_entry[entry_c].authored_text_count) == 1, "each member counts its authored translations")
	_check(by_entry.has(entry_a) and by_entry.has(entry_b) and by_entry.has(entry_c)
		and str(by_entry[entry_a].output_entry_sha256) == _sha(output_a) and str(by_entry[entry_b].output_entry_sha256) == _sha(output_b) and str(by_entry[entry_c].output_entry_sha256) == "", "the replaced members carry their output hash and the translation-only member none")

	var reopened := ContentWorkspaceScript.new()
	_check(reopened.open(destination, source_root).get("ok", false), "the imported workspace reopens with matching originals")
	var snapshot := reopened.get_snapshot()
	reopened.close()
	_check(int(snapshot.replacement_count) == 2 and int(snapshot.projection_count) == 2 and int(snapshot.definition_count) == 1, "the reopened workspace holds two replacements, two projections and one definition")
	_check(str(snapshot.mod_id) == MOD_ID, "the mod identity persisted through the definition")
	_check(_effective_sha(destination, source_root, entry_a) == _sha(output_a) and _effective_sha(destination, source_root, entry_b) == _sha(output_b), "A and B resolve to the authored MES hashes")
	_check(_effective_sha(destination, source_root, entry_c) == _entry_sha(arc_path, entry_c), "the translation-only entry C still resolves to the original MES")
	_check(_projection_edits(destination, arc_path, entry_b) == [edit_b] and _projection_edits(destination, arc_path, entry_c) == [edit_c], "B and C carry exactly the bundle's translations")
	_check(_projection_edits(destination, arc_path, entry_a).is_empty(), "A carries no translation")
	var stored := OverlayPackageScript.new().load_mod_definition(destination, str(document.id))
	_check(stored.get("ok", false) and stored.get("found", false) and TestHelpers.intify(stored.document) == document, "the imported definition is the authored document")
	var report := ProvenanceReportScript.build(destination, source_root)
	var linked := 0
	for untyped_row in report.report.replacements if report.get("ok", false) else []:
		var row: Dictionary = untyped_row
		var bundle := SessionScript.read_bundle(destination.path_join("authoring/delta-" + str(row.target_entry)))
		if row.authoring != null and bundle.get("ok", false) and str(bundle.manifest.summary.output_entry_sha256) == str(row.replacement_sha256):
			linked += 1
	_check(linked == 2, "the provenance report links each replacement to its authoring/delta-<ENTRY> bundle")
	_check(FileAccess.get_sha256(arc_path) == arc_sha_before and FileAccess.get_sha256(template_root.path_join("manifest.json")) == template_manifest_before, "the original archive and the template workspace are byte-unchanged")

	var manifest_after := FileAccess.get_sha256(destination.path_join("manifest.json"))
	var again := importer.import_bundle(source_root, template_root, full_bundle, destination)
	_check(not again.get("ok", false) and str(again.error).contains("requires a new workspace destination"), "a second import to the same destination is refused")
	_check(FileAccess.get_sha256(destination.path_join("manifest.json")) == manifest_after, "the refused import leaves the published workspace unchanged")

	if original:
		# The original check ends here: the refusals, the deltas-only bundle and the
		# CLI are the synthetic mode's. The one PASS line carries offsets, counts and
		# the bundle's payload hash, never a message or its text.
		var sources_unchanged := FileAccess.get_sha256(arc_path) == arc_sha_before and _directory_stamp(source_root) == source_stamp_before \
			and FileAccess.get_sha256(template_root.path_join("manifest.json")) == template_manifest_before
		_check(sources_unchanged, "the original content set's files and the template workspace are unchanged")
		if not _failed:
			print("PASS: original mod bundle round trip deltas=%d text_projections=%d definitions=%d entries=%s@0x%X,%s@0x%X,%s@0x%X bundle_sha256=%s effective_identities=verified sources_unchanged=true assertions=%d" % [
				int(imported.delta_count), int(imported.text_projection_count), int(imported.definition_count),
				entry_a, ORIGINAL_STATE_OFFSET[entry_a], entry_b, ORIGINAL_STATE_OFFSET[entry_b], entry_c, int(message_c.source_offset),
				str(built.payload_sha256), _assertions])
		_finish()
		return

	# ---- A deltas-only bundle: the declared mod is verified, not persisted.
	var deltas_root := _root.path_join("authoring_deltas")
	var deltas_workspace := _new_workspace(deltas_root, source_root, "bundle.import.deltas")
	var deltas_output := _author(source_root, deltas_root, ENTRY_A, "state", 2)
	_check(deltas_workspace.stage_replacements("mes.arc", {ENTRY_A: deltas_output}, "remake_only", "cp932").get("ok", false), "the deltas-only workspace stages entry A")
	deltas_workspace.close()
	var deltas_bundle := bundles.path_join("deltas_only.json")
	var deltas_built := _build_bundle(arc_path, deltas_root, deltas_bundle, ["--mod-id", "deltaonly"])
	_check(deltas_built.get("ok", false) and int(deltas_built.delta_count) == 1 and int(deltas_built.definition_count) == 0, "a deltas-only bundle builds with the mod identity from the command line")
	var deltas_destination := _root.path_join("imported_deltas")
	var deltas_imported := importer.import_bundle(source_root, template_root, deltas_bundle, deltas_destination)
	_check(deltas_imported.get("ok", false) and not bool(deltas_imported.mod_persisted) and str(deltas_imported.mod_id) == "deltaonly", "a deltas-only import reports the declared mod and mod_persisted false")
	var deltas_reopened := ContentWorkspaceScript.new()
	_check(deltas_reopened.open(deltas_destination, source_root).get("ok", false), "the deltas-only workspace reopens")
	var deltas_snapshot := deltas_reopened.get_snapshot()
	deltas_reopened.close()
	_check(str(deltas_snapshot.mod_id).is_empty() and int(deltas_snapshot.definition_count) == 0 and int(deltas_snapshot.replacement_count) == 1, "the reopened deltas-only workspace has an empty mod_id: the mod identity is not persisted")
	_check(_effective_sha(deltas_destination, source_root, ENTRY_A) == _sha(deltas_output), "the deltas-only import resolves to the authored MES hash")

	# ---- The headless CLI entry point: one result line, exit 0 or 1.
	var cli_destination := _root.path_join("imported_cli")
	var cli := _run_cli(source_root, template_root, deltas_bundle, cli_destination)
	_check(int(cli.code) == 0 and cli.verdict.get("ok", false) and not bool(cli.verdict.get("mod_persisted", true)) and str(cli.verdict.get("workspace", "")) == cli_destination, "the CLI imports the deltas-only bundle and prints one result line")
	_check(_effective_sha(cli_destination, source_root, ENTRY_A) == _sha(deltas_output), "the CLI-imported workspace resolves to the authored MES hash")
	var cli_again := _run_cli(source_root, template_root, deltas_bundle, cli_destination)
	_check(int(cli_again.code) == 1 and not cli_again.verdict.get("ok", true), "the CLI exits 1 with an error line for an existing destination")

	# ---- A bundle with no delta: a translation-only entry and the definitions.
	var text_root := _root.path_join("authoring_text")
	var text_workspace := _new_workspace(text_root, source_root, "bundle.import.text")
	_check(text_workspace.stage_mes_text_projections("mes.arc", {ENTRY_C: [edit_c]}).get("ok", false), "the translation-only workspace stages entry C")
	_check(text_workspace.stage_mod_definitions([TestHelpers.definition_document_bytes(document)], ModDefinitionBindingScript.validator()).get("ok", false), "the translation-only workspace stages its definition")
	text_workspace.close()
	var text_bundle := bundles.path_join("text_and_definitions.json")
	var text_built := _build_bundle(arc_path, text_root, text_bundle, [])
	_check(text_built.get("ok", false) and int(text_built.delta_count) == 0 and int(text_built.text_projection_count) == 1, "a bundle with no delta builds")
	var text_destination := _root.path_join("imported_text")
	var text_imported := importer.import_bundle(source_root, template_root, text_bundle, text_destination)
	_check(text_imported.get("ok", false) and bool(text_imported.mod_persisted) and int(text_imported.delta_count) == 0, "a bundle with no delta imports its translation and definition")
	_check(_projection_edits(text_destination, arc_path, ENTRY_C) == [edit_c] and _effective_sha(text_destination, source_root, ENTRY_C) == _entry_sha(arc_path, ENTRY_C), "the translation-only entry carries its edits and no replacement")

	# ---- Refusals: each leaves no destination.
	var forge_path := _scratch.path_join("forge.py")
	var forge_file := FileAccess.open(forge_path, FileAccess.WRITE)
	forge_file.store_string(FORGE_SCRIPT)
	forge_file.close()
	var refusals := [
		["duplicate_delta", "no duplicate", "a rehashed bundle with two deltas for one entry"],
		["other_archive", "another archive", "a rehashed delta row whose archive differs"],
		["other_mod", "another mod", "a rehashed bundle whose set is for a different mod than the header"],
		["stale_payload", "payload changed", "a bundle whose payload hash is stale"],
	]
	for refusal in refusals:
		var forged := bundles.path_join("forged_%s.json" % refusal[0])
		_check(_forge(forge_path, full_bundle, forged, str(refusal[0])), "the forger writes %s" % refusal[0])
		var forged_destination := _root.path_join("refused_%s" % refusal[0])
		var forged_result := importer.import_bundle(source_root, template_root, forged, forged_destination)
		_check(not forged_result.get("ok", false) and str(forged_result.error).contains(str(refusal[1])), "%s is refused (%s)" % [refusal[2], refusal[0]])
		_check(not DirAccess.dir_exists_absolute(forged_destination), "%s leaves no destination" % refusal[0])

	var tampered := bundles.path_join("forged_tampered_member.json")
	_check(_forge(forge_path, full_bundle, tampered, "tampered_member"), "the forger writes a re-signed delta with a changed operation")
	var tampered_destination := _root.path_join("refused_tampered_member")
	var tampered_result := importer.import_bundle(source_root, template_root, tampered, tampered_destination)
	_check(not tampered_result.get("ok", false) and str(tampered_result.error).begins_with(ENTRY_A + ": ") and str(tampered_result.error).contains("reconstruction"), "a tampered member (bundle re-signed, member changed) fails its reconstruction, naming the entry")
	_check(not DirAccess.dir_exists_absolute(tampered_destination), "the tampered member leaves no destination")

	var oversize := bundles.path_join("oversize.json")
	var oversize_file := FileAccess.open(oversize, FileAccess.WRITE)
	oversize_file.resize(ImporterScript.MAX_BYTES + 1)
	oversize_file.close()
	var oversize_destination := _root.path_join("refused_oversize")
	var oversize_result := importer.import_bundle(source_root, template_root, oversize, oversize_destination)
	_check(not oversize_result.get("ok", false) and str(oversize_result.error).contains("bounded import size"), "an oversize file is refused on its length before any parse")
	_check(not DirAccess.dir_exists_absolute(oversize_destination), "the oversize file leaves no destination")

	var missing_result := importer.import_bundle(source_root, template_root, bundles.path_join("missing.json"), _root.path_join("refused_missing"))
	_check(not missing_result.get("ok", false) and str(missing_result.error).contains("unavailable"), "a missing bundle file is refused")

	var other_source_destination := _root.path_join("refused_other_source")
	var other_source_result := importer.import_bundle(other_root, other_template_root, full_bundle, other_source_destination)
	_check(not other_source_result.get("ok", false) and str(other_source_result.error).contains("another archive"), "a bundle for another archive is refused against the other source")
	_check(not DirAccess.dir_exists_absolute(other_source_destination), "the other-source refusal leaves no destination")
	var other_template_destination := _root.path_join("refused_other_template")
	var other_template_result := importer.import_bundle(source_root, other_template_root, full_bundle, other_template_destination)
	_check(not other_template_result.get("ok", false), "a template workspace on another archive is refused")
	_check(not DirAccess.dir_exists_absolute(other_template_destination), "the other-template refusal leaves no destination")
	var binding_plan := {"kind": "Bundle", "suffix": ".bundle", "name_members": true, "deltas": [], "text_rows": [], "set_file": "", "expect": {"archive_sha256": "0".repeat(64)}}
	var binding_result := EngineScript.new().import_members(source_root, template_root, binding_plan, _root.path_join("refused_binding"))
	_check(not binding_result.get("ok", false) and str(binding_result.error) == "Bundle template workspace binds another mes.arc than the bundle's.", "the engine refuses a template that binds another mes.arc than the bundle's")
	var inside_result := importer.import_bundle(source_root, template_root, full_bundle, source_root.path_join("mod"))
	_check(not inside_result.get("ok", false) and str(inside_result.error).contains("outside the original content set"), "a destination inside the content set is refused")
	_check(not DirAccess.dir_exists_absolute(source_root.path_join("mod")), "the inside refusal creates nothing in the content set")

	# ---- Refusals at build: the workspace carries payload or an overlap.
	var raw_root := _root.path_join("authoring_raw")
	var raw := _new_workspace(raw_root, source_root, "bundle.import.raw")
	var raw_bytes := String(SOURCE_HEX[ENTRY_A]).hex_decode()
	raw_bytes[raw_bytes.size() - 3] = 0xa1
	_check(raw.stage_replacements("mes.arc", {ENTRY_A: raw_bytes}, "remake_only", "cp932").get("ok", false), "a raw (unauthored) MES replacement is staged")
	raw.close()
	var raw_built := _build_bundle(arc_path, raw_root, bundles.path_join("raw.json"), ["--mod-id", "rawmod"])
	_check(not raw_built.get("ok", false) and str(raw_built.error).contains("no linked authoring bundle"), "a raw MES replacement is refused at build")
	_check(not FileAccess.file_exists(bundles.path_join("raw.json")), "the raw-MES refusal publishes no bundle")

	var media_workspace_root := _root.path_join("authoring_media")
	var media := _new_workspace(media_workspace_root, media_root, "bundle.import.media")
	_check(media.stage_replacements("mmo.arc", {"X.BIN": PackedByteArray([9, 9, 9, 9])}, "remake_only", "not_applicable").get("ok", false), "a raw replacement in another archive is staged")
	media.close()
	var media_built := _build_bundle(media_root.path_join("mes.arc"), media_workspace_root, bundles.path_join("media.json"), ["--mod-id", "mediamod"])
	_check(not media_built.get("ok", false) and str(media_built.error).contains("outside mes.arc"), "a raw replacement in another archive is refused at build")

	var overlap_root := _root.path_join("authoring_overlap")
	var overlap := _new_workspace(overlap_root, source_root, "bundle.import.overlap")
	var relocated := _author(source_root, overlap_root, ENTRY_C, "message", "変更確認")
	_check(not relocated.is_empty(), "entry C is authored with a relocated message")
	_check(overlap.stage_replacements("mes.arc", {ENTRY_C: relocated}, "remake_only", "cp932").get("ok", false), "the relocation is staged")
	_check(overlap.stage_mes_text_projections("mes.arc", {ENTRY_C: [edit_c]}).get("ok", false), "a translation of the relocated message is staged beside it")
	overlap.close()
	var overlap_built := _build_bundle(arc_path, overlap_root, bundles.path_join("overlap.json"), ["--mod-id", "overlapmod"])
	_check(not overlap_built.get("ok", false) and str(overlap_built.error).contains(ENTRY_C) and str(overlap_built.error).contains("0x%X" % MESSAGE_OFFSET) and str(overlap_built.error).contains("relocates"), "a projection overlapping a relocated message is refused at build, naming the entry and offset")

	_check(FileAccess.get_sha256(arc_path) == arc_sha_before and FileAccess.get_sha256(template_root.path_join("manifest.json")) == template_manifest_before, "the original archive and the template stay byte-unchanged after every refusal")
	_finish()


func _finish() -> void:
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _write_arc(directory: String, variant: String) -> void:
	var entries: Array[Dictionary] = []
	for entry in [ENTRY_A, ENTRY_B, ENTRY_C]:
		var data: PackedByteArray = String(SOURCE_HEX[entry]).hex_decode()
		if variant == "other":
			data[data.size() - 3] = 0xa6
		entries.append({"name": entry, "data": data})
	SyntheticArc.write_arc(directory.path_join("mes.arc"), entries)


## An open workspace of the content set's archives, or null.
func _new_workspace(root: String, source_root: String, project_id: String) -> ContentWorkspaceScript:
	var built := ProjectDocumentScript.from_content_set(source_root, project_id, "Mod Bundle Import Test", "synthetic-test", "kakyu-original-events")
	if not built.get("ok", false):
		return null
	var workspace := ContentWorkspaceScript.new()
	return workspace if workspace.create(root, source_root, built.project).get("ok", false) else null


func _edit(message: Dictionary, text: String) -> Dictionary:
	return {"source_offset": int(message.source_offset), "raw_sha256": str(message.raw_sha256), "text": text}


## Runs `inspect` on `entry` into a fresh scratch directory: `{ok, directory}`.
func _inspect(source_root: String, entry: String) -> Dictionary:
	_counter += 1
	var arc := source_root.path_join("mes.arc")
	var directory := _scratch.path_join("inspect-%d" % _counter)
	var inspected := _run_tool("tools/mes_authoring_workflow.py", PackedStringArray(["inspect", arc, entry, _entry_sha(arc, entry), directory]))
	if not inspected.get("ok", false):
		print("INSPECT_FAILURE ", inspected)
		return {"ok": false}
	return {"ok": true, "directory": directory}


## The first message of `entry` that a translation can bind to - the first
## statement of one `cp932_bytes` operand, the nodes `_check_text` of
## `tools/authored_mod_delta.py` accepts - as `{source_offset, raw_sha256}`
## (empty when there is none). Only the offset and the hash of its raw bytes
## are kept, never the bytes.
func _message_of(source_root: String, entry: String) -> Dictionary:
	if _messages.has(entry):
		return _messages[entry]
	var inspected := _inspect(source_root, entry)
	if not inspected.get("ok", false):
		return {}
	var editable: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(inspected.directory).path_join("editable.json")))
	for untyped_node in editable.source_ir.nodes:
		var node: Dictionary = untyped_node
		var operands: Array = node.get("statement", {}).get("operands", [])
		if operands.size() == 1 and operands[0] is Dictionary and str(operands[0].get("type", "")) == "cp932_bytes":
			_messages[entry] = {"source_offset": int(node.source.start), "raw_sha256": _sha(String(operands[0].raw_hex).hex_decode())}
			return _messages[entry]
	return {}


## Each file of the directory as `name:length:modified`, sorted: a cheap
## identity that changes when a file is rewritten.
static func _directory_stamp(directory_path: String) -> PackedStringArray:
	var stamp := PackedStringArray()
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return stamp
	for filename in directory.get_files():
		var file := FileAccess.open(directory_path.path_join(filename), FileAccess.READ)
		stamp.append("%s:%d:%d" % [filename, file.get_length() if file != null else -1, FileAccess.get_modified_time(directory_path.path_join(filename))])
	stamp.sort()
	return stamp


## Authors one operation on `entry` headlessly, publishing the compiled bundle
## under the workspace's `authoring/`, and returns its output MES (empty on
## failure). `kind` is "state" (a literal state-write value) or "message" (a
## relocated message with the given text).
func _author(source_root: String, workspace_root: String, entry: String, kind: String, argument: Variant) -> PackedByteArray:
	var inspected := _inspect(source_root, entry)
	if not inspected.get("ok", false):
		return PackedByteArray()
	var inspect_directory := str(inspected.directory)
	var operation: Dictionary
	if kind == "state":
		var editable: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(inspect_directory.path_join("editable.json")))
		operation = _state_operation(editable, int(ORIGINAL_STATE_OFFSET.get(entry, 0)), int(argument))
	else:
		operation = {"kind": "replace_message", "source_offset": MESSAGE_OFFSET, "raw_sha256": _sha(String(MESSAGE_HEX[entry]).hex_decode()),
			"text": str(argument), "encoding": "cp932", "native_projection": "require_match"}
	var operation_path := _scratch.path_join("operation-%d.json" % _counter)
	var operation_file := FileAccess.open(operation_path, FileAccess.WRITE)
	operation_file.store_string(JSON.stringify(operation))
	operation_file.close()
	var compiled_directory := workspace_root.path_join("authoring/preview-%d" % _counter)
	var compiled := _run_tool("tools/mes_authoring_workflow.py", PackedStringArray(["compile", inspect_directory, operation_path, compiled_directory]))
	if not compiled.get("ok", false):
		print("COMPILE_FAILURE ", compiled)
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(compiled_directory.path_join("output.mes"))


## The `replace_state_write_literal` operation for the first literal pair of
## the state write at `source_offset`, or an empty Dictionary.
static func _state_operation(editable: Dictionary, source_offset: int, value: int) -> Dictionary:
	for untyped_node in editable.source_ir.nodes:
		var node: Dictionary = untyped_node
		if int(node.source.start) != source_offset:
			continue
		for operand in node.statement.get("operands", []):
			var pairs: Array = operand.get("pairs", []) if operand is Dictionary else []
			for index in range(pairs.size()):
				if str(pairs[index].get("expression", {}).get("ast", {}).get("type", "")) == "literal":
					return {"kind": "replace_state_write_literal", "source_offset": source_offset,
						"instruction_raw_sha256": str(node.source.raw_sha256), "pair_index": index, "value": value}
	return {}


func _build_bundle(arc_path: String, workspace_root: String, out_path: String, extra: Array) -> Dictionary:
	var arguments := PackedStringArray(["build", arc_path, workspace_root, out_path,
		"--names", ProjectSettings.globalize_path(ModDefinitionBindingScript.DEFAULT_NAMES_DIR),
		"--definitions-dir", ProjectSettings.globalize_path(ModDefinitionBindingScript.DEFAULT_DEFINITIONS_DIR)])
	for argument in extra:
		arguments.append(str(argument))
	return _run_tool("tools/mod_bundle.py", arguments)


## Runs `cli/import_mod_bundle.gd` in a child Godot process: `{code, verdict}`.
func _run_cli(source_root: String, template_root: String, bundle_path: String, destination: String) -> Dictionary:
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/content_suite/cli/import_mod_bundle.gd", "--",
		source_root, template_root, bundle_path, destination]), output, true, false)
	return {"code": code, "verdict": ExtractScript.last_json_line(output)}


func _forge(forge_path: String, source: String, target: String, mutation: String) -> bool:
	var runtime := PythonRuntimeScript.resolve("tools/mod_bundle.py")
	if not runtime.get("ok", false):
		return false
	var output: Array = []
	var code := OS.execute(str(runtime.python), PackedStringArray(["-B", forge_path,
		ProjectSettings.globalize_path("res://tools"), source, target, mutation]), output, true, false)
	return code == 0 and FileAccess.file_exists(target)


## Runs a Python tool and returns its last JSON line, `ok` false on a non-zero
## exit or no verdict.
func _run_tool(tool: String, arguments: PackedStringArray) -> Dictionary:
	var runtime := PythonRuntimeScript.resolve(tool)
	if not runtime.get("ok", false):
		return {"ok": false, "error": str(runtime.get("error", "The Python runtime is unavailable."))}
	var command := PackedStringArray(["-B", str(runtime.script)])
	command.append_array(arguments)
	var output: Array = []
	var code := OS.execute(str(runtime.python), command, output, true, false)
	var verdict := ExtractScript.last_json_line(output)
	if code != 0 or verdict.is_empty():
		return {"ok": false, "error": str(verdict.get("error", "%s produced no verdict (exit code %d): %s" % [tool, code, str(output)]))}
	return verdict


func _effective_sha(workspace_root: String, source_root: String, entry: String) -> String:
	var resolver := ResolverScript.new()
	var sha := ""
	if resolver.register_original_archive("mes.arc", source_root.path_join("mes.arc")) and resolver.configure_overlay(workspace_root):
		sha = _sha(resolver.read_resolved(resolver.resolve("mes.arc", entry)))
	resolver.close()
	return sha


func _projection_edits(workspace_root: String, arc_path: String, entry: String) -> Array:
	var projection := OverlayPackageScript.new().load_mes_text_projection(
		workspace_root, "mes.arc", entry, FileAccess.get_sha256(arc_path), _entry_sha(arc_path, entry))
	return projection.get("edits", []) if projection.get("ok", false) else [{"error": str(projection.get("error", ""))}]


func _entry_sha(arc_path: String, entry: String) -> String:
	var reader := ArcReaderScript.new()
	var sha := ""
	if reader.open(arc_path):
		sha = reader.get_entry_fingerprint(entry)
	reader.close()
	return sha


func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
