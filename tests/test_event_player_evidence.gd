extends "res://tests/test_case.gd"

## TD-11 unit 2: synthetic coverage for `KakyuEventPlayerEvidence` (its
## generic evidence helpers), including `catalog_setup_definition_resume`
## (the fragment-catalog capability moved in from the retired
## `KakyuEventPlayerEventD14` module; EP-10 unit 5bc part 3 retired the
## other ten per-event modules with the hand-authored catalog rows they
## served, and part 3b retired the last one).
## No original data: the event_catalog document is the repository's own
## tracked catalog config (`config/event_catalog/original_events_v1.json`,
## no dialogue/payload/bytecode field, enforced by
## `KakyuEventCatalog.validate()`'s own forbidden-content check), read the
## same way `tests/test_event_catalog.gd` reads it, and every expectation is
## derived from that document's own fields at runtime rather than a copied
## constant. Everything else here (the MES document, the library index, the
## startup context) is a hand-built dictionary.

const EventCatalogScript := preload("res://content_core/event_catalog.gd")
const CATALOG_PATH := "res://config/event_catalog/original_events_v1.json"


func _ready() -> void:
	_test_catalog_source_entry()
	_test_confirmed_address_catalog()
	_test_indexed_routine_boundary()
	_test_audited_startup_registered_definitions()
	_test_catalog_setup_definition_resume()
	get_tree().quit(1 if _failed else 0)


func _read_catalog_document() -> Dictionary:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _loaded_catalog() -> KakyuEventCatalog:
	var catalog := EventCatalogScript.new()
	var loaded := catalog.validate(_read_catalog_document())
	_check(loaded.get("ok", false), "the tracked event_catalog config validates as this test's fixture")
	return catalog


func _find_event(document: Dictionary, callee_entry: String) -> Dictionary:
	for event in document.events:
		if str(event.source.callee.entry).to_upper() == callee_entry.to_upper():
			return event
	return {}


func _test_catalog_source_entry() -> void:
	var document := _read_catalog_document()
	var catalog := _loaded_catalog()
	var event := _find_event(document, "EVENTB01.MES")
	var required: Dictionary = {}
	for untyped_required in event.source.required_entries:
		if str(untyped_required.entry).to_upper() == "LIBLARY.LIB":
			required = untyped_required
			break
	_check(not required.is_empty(), "the tracked catalog's EVENTB01 route names LIBLARY.LIB as a required entry")

	var evidence := KakyuEventPlayerEvidence.new()
	evidence.event_catalog = catalog

	var expected := str(required.entry_sha256)
	_check(evidence.catalog_source_entry_sha256("LIBLARY.LIB") == expected, "catalog_source_entry_sha256 projects the tracked catalog's own required-entry hash")
	_check(evidence.is_catalog_source_entry(expected, "LIBLARY.LIB"), "is_catalog_source_entry accepts the exact tracked hash")
	_check(not evidence.is_catalog_source_entry("deadbeef", "LIBLARY.LIB"), "is_catalog_source_entry rejects a mismatched hash")
	_check(not evidence.is_catalog_source_entry(expected, "MISSING.LIB"), "is_catalog_source_entry rejects an uncataloged entry name")


func _test_confirmed_address_catalog() -> void:
	var document := _read_catalog_document()
	var catalog := _loaded_catalog()
	var event := _find_event(document, "EVENTD14.MES")
	_check(not event.is_empty(), "the tracked catalog names an EVENTD14 callee source")
	var callee: Dictionary = event.source.callee
	var caller: Dictionary = event.source.caller

	var evidence := KakyuEventPlayerEvidence.new()
	evidence.event_catalog = catalog

	var resolved := evidence.confirmed_address_catalog("EVENTD14.MES", str(callee.entry_sha256))
	_check(
		not resolved.is_empty()
		and str(resolved.get("label", "")) == str(KakyuEventPlayerEvidence.CONFIRMED_ADDRESS_CATALOGS["EVENTD14.MES"].label)
		and str(resolved.get("entry_sha256", "")) == str(callee.entry_sha256)
		and str(resolved.get("caller_entry", "")) == str(caller.entry).to_upper()
		and str(resolved.get("caller_sha256", "")) == str(caller.entry_sha256)
		and int(resolved.get("caller_offset", -1)) == int(caller.dispatch_offset)
		and int(resolved.get("caller_resume", -1)) == int(caller.resume_offset),
		"confirmed_address_catalog resolves EVENTD14's catalog-sourced caller envelope from the tracked catalog"
	)
	_check(evidence.confirmed_address_catalog("EVENTD14.MES", "deadbeef").is_empty(), "confirmed_address_catalog fails closed on a mismatched entry hash")
	_check(evidence.confirmed_address_catalog("MISSING.MES", "deadbeef").is_empty(), "confirmed_address_catalog answers empty for an uncataloged entry")


func _test_indexed_routine_boundary() -> void:
	var evidence := KakyuEventPlayerEvidence.new()
	evidence.library_index = {
		"by_id": {5: {"body_offset": 0x100, "end_offset": 0x200}},
		"source": "resolved content",
	}
	var found := evidence.indexed_routine_boundary(5, "test_role")
	_check(
		found.get("routine_id", -1) == 5
		and int(found.get("body_offset", -1)) == 0x100
		and int(found.get("end_offset", -1)) == 0x200
		and str(found.get("source", "")) == "resolved content"
		and str(found.get("panel_role", "")) == "test_role",
		"indexed_routine_boundary projects a hand-built library index entry"
	)
	_check(evidence.indexed_routine_boundary(6, "test_role").is_empty(), "indexed_routine_boundary answers empty for an uncataloged routine ID")
	_check(evidence.indexed_routine_boundary(-1, "test_role").is_empty(), "indexed_routine_boundary rejects a negative routine ID")
	var empty_evidence := KakyuEventPlayerEvidence.new()
	_check(empty_evidence.indexed_routine_boundary(5, "test_role").is_empty(), "indexed_routine_boundary answers empty when the library index is empty")


func _test_audited_startup_registered_definitions() -> void:
	# The player never holds a null reader (only an unopened one), so this
	# evidence context mirrors that: a real, unopened KakyuArcReader.
	var evidence := KakyuEventPlayerEvidence.new()
	evidence.reader = KakyuArcReader.new()
	evidence.startup_context = {}
	_check(evidence.audited_startup_registered_definitions() == {}, "audited_startup_registered_definitions answers empty for an empty startup context")
	_check(not evidence.has_authoritative_def26_registry_audit(), "has_authoritative_def26_registry_audit fails closed with no reader open and no startup context")


func _test_catalog_setup_definition_resume() -> void:
	# `catalog_setup_definition_resume` (moved in from the retired EventD14
	# module, fragment catalogs only): an obvious false branch on an
	# evidence context that names no in-progress catalog-setup session, and
	# on a result whose status is not `definition_invoke_boundary`.
	var evidence := KakyuEventPlayerEvidence.new()
	evidence.event_catalog = EventCatalogScript.new()
	_check(evidence.catalog_setup_definition_resume({}).is_empty(), "catalog_setup_definition_resume rejects an evidence context outside its catalog-setup session")
	evidence.preview_event_session = "catalog_setup"
	_check(evidence.catalog_setup_definition_resume({"status": "dialogue_boundary"}).is_empty(), "catalog_setup_definition_resume rejects a result whose status is not definition_invoke_boundary")
