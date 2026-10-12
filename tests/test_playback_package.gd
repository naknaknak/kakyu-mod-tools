extends "res://tests/test_case.gd"

const Exporter := preload("res://tools/content_suite/playback_package_export.gd")
const EventCatalogScript := preload("res://content_core/event_catalog.gd")
const CATALOG_PATH := "res://config/event_catalog/original_events_v1.json"
const Package := preload("res://content_core/playback_package.gd")
const Integrity := preload("res://content_core/playback_package_integrity.gd")
const Version := preload("res://content_core/content_core_version.gd")
const PublicationLock := preload("res://content_core/publication_lock.gd")
const Inventory := preload("res://content_core/playback_package_inventory.gd")
const PackageSourceScript := preload("res://content_core/playback_package_code_source.gd")
const LazySourceScript := preload("res://content_core/playback_package_lazy_code_source.gd")
const CodecScript := preload("res://content_core/cp932_codec.gd")

# The binding every synthetic `built` carries: `build()` takes it from the
# catalog load result, and `serialize()` refuses a package without one.
const FIXTURE_CATALOG := {"catalog_id": "fixture-catalog", "catalog_revision": 7}

class FailedWriter:
	extends "res://tools/content_suite/playback_package_export.gd"
	func _write_payload(path: String, payload: PackedByteArray) -> String:
		if path.ends_with("/text/A.json"):
			return "Injected write failure after the event file."
		return super._write_payload(path, payload)

class CorruptWriter:
	extends "res://tools/content_suite/playback_package_export.gd"
	func _write_payload(path: String, payload: PackedByteArray) -> String:
		if path.ends_with("/text/A.json"):
			return super._write_payload(path, "{}".to_utf8_buffer())
		return super._write_payload(path, payload)

var _root := ""


func _ready() -> void:
	_root = ProjectSettings.globalize_path("user://package-integrity-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()])
	_manifest_and_document_integrity()
	_reload_commits_one_verified_snapshot()
	_publication_preserves_existing_output_and_cleans_failed_staging()
	_membership_blocks()
	_catalog_binding()
	_referenced_resource_names()
	_analysis_group_member_merge()
	_full_build_selects_every_row()
	_safe_entry_names()
	_text_codec_is_shared_per_package()
	_lazy_sources_parse_on_first_use()
	_lazy_cache_evicts_and_redecodes_identically()
	_lazy_reader_ignores_files_rewritten_after_load()
	_lazy_reader_matches_the_eager_source()
	_lazy_shell_declares_every_source_method()
	_lazy_reload_swaps_the_snapshot()
	_lazy_load_fails_closed_on_a_member_file()
	_inventory_accumulator_matches_the_whole_set_form()
	_streamed_members_serialize_in_member_order()
	_serialize_fails_closed_on_streamed_members()
	_remove_fixture(_root)
	get_tree().quit(1 if _failed else 0)


func fixture(entry: String) -> Dictionary:
	return Exporter.new().serialize(fixture_built(entry))


func fixture_document(entry: String) -> Dictionary:
	var identity := "a".repeat(64)
	return {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": entry,
		"entry_sha256": identity, "code_size": 2, "code_sha256": identity,
		"address_table": [0], "regions": [{"at": 0, "end": 2}], "provenance_records": [],
		"records": [{"at": 0, "end": 1, "op": "script_return", "id": 0, "operands": []},
			{"at": 1, "end": 2, "op": "script_return", "id": 0, "operands": []}]}


func fixture_text(entry: String) -> Dictionary:
	return {"schema": Version.PLAYBACK_PACKAGE_SCHEMA,
		"entry": entry, "encoding": "utf-8", "strings": ["Authored fixture"]}


# A build result the way `build()` hands it over: the members are streamed
# payloads and the inventory evidence, made by the exporter's own per-entry
# function (`payloads_for`), never documents.
func fixture_built(entry: String) -> Dictionary:
	var identity := "a".repeat(64)
	var built := {"ok": true,
		"events": [{"event_id": entry, "source": {"callee": {"entry": entry, "start_coordinate": 0}},
			"terminals": [{"offset": 0}], "presets": [], "choices": []}],
		"entry_reports": [{"entry": entry, "entry_sha256": identity, "role": "event_entry"}],
		"catalog": FIXTURE_CATALOG.duplicate(), "resource_names": [], "media": [],
		"media_identity": Inventory.empty_identity(), "media_scan": Inventory.empty_scan(),
		"dropped_instruction_fields": {}, "dropped_operand_fields": {},
		"undecodable_text_payloads": 0, "unresolved_expression_boundaries": 0, "text_round_trip_failures": 0}
	built.merge(Exporter.new().payloads_for({entry: fixture_document(entry)}, {entry: fixture_text(entry)}))
	return built


func _manifest_and_document_integrity() -> void:
	var original := fixture("A.MES")
	_check(original.ok, "fixture serializes")
	if not original.ok:
		return
	var directory := _root.path_join("integrity")
	_check(Exporter.new().write(directory, original).ok, "fixture publishes")
	_check(Package.new().load_directory(directory).ok, "current package reopens with normalized JSON numbers")
	_check(
		original.manifest.has("media_inventory") and original.manifest.has("script_references")
		and original.manifest.media_inventory.members.is_empty() and original.manifest.script_references.targets.is_empty(),
		"a package with no media or script references carries empty inventory blocks"
	)
	var changed: Dictionary = original.manifest.duplicate(true)
	changed.events[0].start_coordinate = 1
	_write_manifest(directory, changed)
	_check(not Package.new().load_directory(directory).ok, "changed valid start coordinate fails unchanged hash")
	changed = original.manifest.duplicate(true)
	changed.events[0].terminals[0].offset = 1
	_write_manifest(directory, changed)
	_check(not Package.new().load_directory(directory).ok, "changed valid terminal fails unchanged hash")
	changed = original.manifest.duplicate(true)
	changed.events[0].presets = [{"writes": [{"index": 1, "value": 2}]}]
	_write_manifest(directory, changed)
	_check(not Package.new().load_directory(directory).ok, "changed preset fails unchanged hash")
	changed = original.manifest.duplicate(true)
	changed.source.catalog_revision = 999
	_write_manifest(directory, changed)
	_check(not Package.new().load_directory(directory).ok, "changed source identity fails unchanged hash")
	changed = original.manifest.duplicate(true)
	changed.events[0].start_coordinate = 99999
	changed.package_sha256 = Integrity.new().fingerprint(changed)
	_write_manifest(directory, changed)
	_check(not Package.new().load_directory(directory).ok, "rehashed out-of-range start is rejected")
	for mutation in ["schema", "v4", "entry", "files", "event"]:
		changed = original.manifest.duplicate(true)
		match mutation:
			"schema": changed.schema = "kakyu_playback_package/v3"
			"v4": changed.schema = "kakyu_playback_package/v4"
			"entry": changed.entries[0].entry = "../A.MES"
			"files": changed.files.append(changed.files[0].duplicate())
			"event": changed.events = ["not an object"]
		changed.package_sha256 = Integrity.new().fingerprint(changed)
		_write_manifest(directory, changed)
		_check(not Package.new().load_directory(directory).ok, "malformed %s fails closed" % mutation)
	_write_manifest(directory, original.manifest)
	var handle := FileAccess.open(directory.path_join("text/A.json"), FileAccess.WRITE)
	handle.store_string('{"strings":["Changed fixture"]}')
	handle.close()
	_check(not Package.new().load_directory(directory).ok, "changed document fails inventory fingerprint")


func _reload_commits_one_verified_snapshot() -> void:
	var a := fixture("A.MES")
	var b := fixture("B.MES")
	var path_a := _root.path_join("a")
	var path_b := _root.path_join("b")
	_check(Exporter.new().write(path_a, a).ok and Exporter.new().write(path_b, b).ok, "reload fixtures publish")
	var package := Package.new()
	_check(package.load_directory(path_a).ok, "A loads")
	_check(package.load_directory(path_b).ok, "B replaces A")
	_check(package.entry_names() == ["B.MES"] and not package.has_entry("A.MES"), "old entry and source do not survive successful reload")
	var old_source = package.code_source("B.MES")
	var changed: Dictionary = a.manifest.duplicate(true)
	changed.schema = "invalid"
	_write_manifest(path_a, changed)
	_check(not package.load_directory(path_a).ok, "bad reload fails")
	_check(package.event_ids() == ["B.MES"] and package.entry_names() == ["B.MES"], "failed reload preserves matching manifest and entry list")
	_check(package.code_source("B.MES") == old_source and package.manifest().package_sha256 == b.manifest.package_sha256, "failed reload preserves the verified source and hash")
	var strings := package.text_strings("B.MES")
	strings[0] = "Mutated caller copy"
	_check(package.text_strings("B.MES")[0] == "Authored fixture", "text accessor cannot mutate the verified snapshot")
	var empty := Package.new()
	_check(not empty.load_directory(path_a).ok and empty.event_ids().is_empty() and empty.entry_names().is_empty(), "first failed load leaves an empty reader")


func _write_manifest(directory: String, manifest: Dictionary) -> void:
	var handle := FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	handle.store_string(JSON.stringify(manifest))
	handle.close()


func _publication_preserves_existing_output_and_cleans_failed_staging() -> void:
	var original := fixture("A.MES")
	var directory := _root.path_join("published")
	_check(Exporter.new().write(directory, original).ok, "fresh package publishes after reopen")
	var old_manifest := FileAccess.get_sha256(directory.path_join("manifest.json"))
	_check(not Exporter.new().write(directory, fixture("B.MES")).ok, "existing package destination is refused")
	_check(FileAccess.get_sha256(directory.path_join("manifest.json")) == old_manifest and Package.new().load_directory(directory).ok, "refused overwrite preserves the previous package")
	var changed: Dictionary = original.duplicate(true)
	changed.files[0].name = "../outside.json"
	_check(not Exporter.new().write(_root.path_join("unsafe"), changed).ok, "unlisted serialized file cannot escape staging")
	changed = original.duplicate(true)
	changed.files[0].payload = "changed".to_utf8_buffer()
	_check(not Exporter.new().write(_root.path_join("changed"), changed).ok, "changed serialized payload is refused before staging")
	for writer in [FailedWriter.new(), CorruptWriter.new()]:
		var target := _root.path_join("failed")
		_check(not writer.write(target, original).ok, "write or reopen failure aborts publication")
		_check(not DirAccess.dir_exists_absolute(target), "failed package is never published")
		_check(Array(DirAccess.get_directories_at(_root)).filter(func(name): return str(name).begins_with("failed.stage-")).is_empty(), "owned failed staging is removed")
	var locks := PublicationLock.new()
	var lock := locks.acquire(_root, ".locked.playback.lock")
	_check(lock.ok, "fixture owns publication lock")
	if lock.ok:
		_check(not Exporter.new().write(_root.path_join("locked"), original).ok, "concurrent publication respects the shared lock")
		_check(locks.release(lock).ok, "fixture releases publication lock")


func _membership_blocks() -> void:
	var identity_a := "a".repeat(64)
	var identity_c := "c".repeat(64)
	var document_a := {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": "A.MES",
		"entry_sha256": identity_a, "code_size": 2, "code_sha256": identity_a,
		"address_table": [0], "regions": [{"at": 0, "end": 2}], "provenance_records": [],
		"records": [{"at": 0, "end": 1, "op": "script_return", "id": 0, "operands": []},
			{"at": 1, "end": 2, "op": "script_return", "id": 0, "operands": []}]}
	var document_c := {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": "C.MES",
		"entry_sha256": identity_c, "code_size": 2, "code_sha256": identity_c,
		"address_table": [0], "regions": [{"at": 0, "end": 2}], "provenance_records": [],
		"records": [{"at": 0, "end": 1, "op": "script_return", "id": 0, "operands": []},
			{"at": 1, "end": 2, "op": "script_return", "id": 0, "operands": []}]}
	var documents := {"A.MES": document_a, "C.MES": document_c}
	var texts := {
		"A.MES": {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": "A.MES", "encoding": "utf-8", "strings": ["Authored fixture"]},
		"C.MES": {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": "C.MES", "encoding": "utf-8", "strings": ["Authored fixture"]},
	}
	var built := {
		"ok": true,
		"events": [{"event_id": "A.MES", "source": {"callee": {"entry": "A.MES", "start_coordinate": 0}},
			"terminals": [{"offset": 0, "owner_entry": "A.MES", "terminal_id": "t1"},
				{"offset": 0, "owner_entry": "Z.MES", "terminal_id": "t2"}], "presets": [], "choices": []}],
		"entry_reports": [
			{"entry": "A.MES", "entry_sha256": identity_a, "role": "event_entry", "bound_by": ["g1"]},
			{"entry": "C.MES", "entry_sha256": identity_c, "role": "analysis_group_member", "bound_by": ["g1", "g2"]},
		],
		"catalog": FIXTURE_CATALOG.duplicate(), "resource_names": [], "media": [],
		"media_identity": Inventory.empty_identity(), "media_scan": Inventory.empty_scan(),
		"dropped_instruction_fields": {}, "dropped_operand_fields": {},
		"undecodable_text_payloads": 0, "unresolved_expression_boundaries": 0, "text_round_trip_failures": 0,
		"membership": {
			"rule": "catalog_events_and_analysis_group_members",
			"catalog_events": 1,
			"catalog_members": 1,
			"analysis_group_members": 1,
			"analysis_groups": [
				{"profile": "g1", "group_id": "g1", "schema": "kakyu_playback_analysis_group/v6", "payload_sha256": "1".repeat(64)},
				{"profile": "g2", "group_id": "g2", "schema": "kakyu_playback_analysis_group/v6", "payload_sha256": "2".repeat(64)},
			],
		},
	}
	built.merge(Exporter.new().payloads_for(documents, texts))
	var serialized := Exporter.new().serialize(built)
	_check(serialized.get("ok", false), "membership fixture serializes")
	if not serialized.get("ok", false):
		return
	var expected_external := [{"event_id": "A.MES", "terminal_id": "t2", "owner_entry": "Z.MES", "offset": 0}]
	_check(
		JSON.stringify(serialized.manifest.incompleteness.external_terminals) == JSON.stringify(expected_external),
		"external terminals list matches the one unpackaged terminal owner"
	)
	_check(int(serialized.manifest.membership.analysis_group_members) == 1, "membership analysis group member count is recorded")
	var directory := _root.path_join("membership")
	_check(Exporter.new().write(directory, serialized).ok, "membership fixture publishes")
	_check(Package.new().load_directory(directory).ok, "membership package reopens")

	var changed: Dictionary = serialized.manifest.duplicate(true)
	changed.membership.analysis_group_members = 2
	_rehash_and_check_fail(directory, changed, "membership.analysis_group_members mismatch fails closed")

	changed = serialized.manifest.duplicate(true)
	changed.entries[1].bound_by = ["g9"]
	_rehash_and_check_fail(directory, changed, "bound_by naming an unlisted group fails closed")

	changed = serialized.manifest.duplicate(true)
	changed.membership.rule = "anything"
	_rehash_and_check_fail(directory, changed, "unrecognized membership rule fails closed")

	changed = serialized.manifest.duplicate(true)
	changed.incompleteness.external_terminals = []
	_rehash_and_check_fail(directory, changed, "wrong external terminals list fails closed")

	changed = serialized.manifest.duplicate(true)
	changed.incompleteness.standalone_complete = true
	_rehash_and_check_fail(directory, changed, "standalone_complete true fails closed")

	changed = serialized.manifest.duplicate(true)
	changed.entries[1].bound_by = []
	_rehash_and_check_fail(directory, changed, "analysis group member without bound_by fails closed")

	changed = serialized.manifest.duplicate(true)
	var groups: Array = changed.membership.analysis_groups
	changed.membership.analysis_groups = [groups[1], groups[0]]
	_rehash_and_check_fail(directory, changed, "analysis_groups unsorted by profile fails closed")

	changed = serialized.manifest.duplicate(true)
	changed.membership.analysis_groups[1].payload_sha256 = changed.membership.analysis_groups[0].payload_sha256
	_rehash_and_check_fail(directory, changed, "duplicate payload_sha256 across analysis groups fails closed")

	changed = serialized.manifest.duplicate(true)
	changed.erase("membership")
	changed.erase("incompleteness")
	changed.package_sha256 = Integrity.new().fingerprint(changed)
	_write_manifest(directory, changed)
	_check(Package.new().load_directory(directory).ok, "manifest without membership or incompleteness still loads")


func _rehash_and_check_fail(directory: String, changed: Dictionary, label: String) -> void:
	changed.package_sha256 = Integrity.new().fingerprint(changed)
	_write_manifest(directory, changed)
	_check(not Package.new().load_directory(directory).ok, label)


func _catalog_binding() -> void:
	var original := fixture("A.MES")
	_check(original.get("ok", false), "binding fixture serializes")
	if not original.get("ok", false):
		return
	_check(
		str(original.manifest.source.catalog_id) == "fixture-catalog" and int(original.manifest.source.catalog_revision) == 7,
		"manifest source carries the catalog id and revision from the build result"
	)

	# The tracked catalog's own load result is an accepted binding and reaches
	# the manifest, which is the shape build() hands to serialize().
	var catalog := EventCatalogScript.new()
	var loaded: Dictionary = catalog.load_file(CATALOG_PATH)
	_check(loaded.get("ok", false), "tracked catalog loads for the binding check")
	if loaded.get("ok", false):
		var tracked_built := fixture_built("A.MES")
		tracked_built.catalog = {"catalog_id": loaded.catalog_id, "catalog_revision": loaded.catalog_revision}
		var tracked := Exporter.new().serialize(tracked_built)
		_check(
			tracked.get("ok", false)
			and str(tracked.manifest.source.catalog_id) == str(loaded.catalog_id)
			and int(tracked.manifest.source.catalog_revision) == int(loaded.catalog_revision),
			"the tracked catalog's load result is an accepted binding"
		)

	# serialize() refuses every shape that would write an unbound package.
	var unbound := {
		"nothing in it": {},
		"an id only": {"catalog_id": "fixture-catalog"},
		"a revision only": {"catalog_revision": 7},
		"an empty id": {"catalog_id": "", "catalog_revision": 7},
		"an upper-case id": {"catalog_id": "Fixture-Catalog", "catalog_revision": 7},
		"a path-like id": {"catalog_id": "a/b", "catalog_revision": 7},
		"an id with a trailing newline": {"catalog_id": "fixture-catalog\n", "catalog_revision": 7},
		"a numeric id": {"catalog_id": 5, "catalog_revision": 7},
		"revision zero": {"catalog_id": "fixture-catalog", "catalog_revision": 0},
		"a negative revision": {"catalog_id": "fixture-catalog", "catalog_revision": -1},
		"a fractional revision": {"catalog_id": "fixture-catalog", "catalog_revision": 1.5},
		"a text revision": {"catalog_id": "fixture-catalog", "catalog_revision": "7"},
	}
	for label in unbound:
		var unbound_built := fixture_built("A.MES")
		unbound_built.catalog = unbound[label]
		var refused := Exporter.new().serialize(unbound_built)
		_check(
			not refused.get("ok", true) and not (refused.get("failures", []) as Array).is_empty(),
			"serialize refuses a catalog binding with %s" % label
		)
	var without_catalog := fixture_built("A.MES")
	without_catalog.erase("catalog")
	_check(not Exporter.new().serialize(without_catalog).get("ok", true), "serialize refuses a build result without a catalog binding")
	var not_a_dictionary := fixture_built("A.MES")
	not_a_dictionary.catalog = "fixture-catalog"
	_check(not Exporter.new().serialize(not_a_dictionary).get("ok", true), "serialize refuses a catalog binding that is not an object")

	# The reader stays tolerant: a manifest from before the binding was filled
	# in (or one that never carried it) still loads once it is rehashed.
	var directory := _root.path_join("binding")
	_check(Exporter.new().write(directory, original).ok, "bound fixture publishes")
	_check(Package.new().load_directory(directory).ok, "bound package reopens")
	var erased: Dictionary = original.manifest.duplicate(true)
	erased.source.erase("catalog_id")
	erased.source.erase("catalog_revision")
	erased.package_sha256 = Integrity.new().fingerprint(erased)
	_write_manifest(directory, erased)
	_check(Package.new().load_directory(directory).ok, "a rehashed manifest without source.catalog_* still loads")
	var blanked: Dictionary = original.manifest.duplicate(true)
	blanked.source.catalog_id = ""
	blanked.source.catalog_revision = 0
	blanked.package_sha256 = Integrity.new().fingerprint(blanked)
	_write_manifest(directory, blanked)
	_check(Package.new().load_directory(directory).ok, "a rehashed manifest with the empty historical binding still loads")


func _referenced_resource_names() -> void:
	var built := fixture_built("A.MES")
	built.resource_names = ["Z9.MMO", "A1.AX", "M5.OGG"]
	# The instance variable the exporter fills while building must not matter:
	# the names travel in the build result.
	var exporter := Exporter.new()
	exporter._resource_names["STALE.MMO"] = true
	var serialized := exporter.serialize(built)
	_check(serialized.get("ok", false), "resource name fixture serializes")
	if not serialized.get("ok", false):
		return
	_check(
		JSON.stringify(serialized.manifest.media.referenced_resource_names) == JSON.stringify(["A1.AX", "M5.OGG", "Z9.MMO"]),
		"media.referenced_resource_names is the build result's names, sorted, whatever the exporter instance holds"
	)
	_check(built.resource_names == ["Z9.MMO", "A1.AX", "M5.OGG"], "serialize leaves the build result's names as given")
	var none := Exporter.new().serialize(fixture_built("A.MES"))
	_check(none.get("ok", false) and (none.manifest.media.referenced_resource_names as Array).is_empty(), "a build result with no names records none")
	var without_names := fixture_built("A.MES")
	without_names.erase("resource_names")
	_check(not Exporter.new().serialize(without_names).get("ok", true), "serialize refuses a build result without resource_names")


func _analysis_group_member_merge() -> void:
	var directory := _root.path_join("groups")
	DirAccess.make_dir_recursive_absolute(directory)
	_write_group(directory, "a_v1.json", "a_v1", "1".repeat(64), [
		{"entry": "X.MES", "entry_sha256": "1".repeat(64)},
		{"entry": "Y.MES", "entry_sha256": "2".repeat(64)},
	])
	_write_group(directory, "b_v1.json", "b_v1", "2".repeat(64), [
		{"entry": "Y.MES", "entry_sha256": "2".repeat(64)},
		{"entry": "Z.MES", "entry_sha256": "3".repeat(64)},
	])
	var catalog_members: Array[Dictionary] = [{"entry": "X.MES", "entry_sha256": "1".repeat(64), "role": "event_entry"}]
	var merged := Exporter.new().analysis_group_members(directory, catalog_members)
	_check(merged.get("ok", false), "analysis group merge succeeds")
	_check(merged.members.size() == 3, "merge yields three members")
	var by_entry := {}
	for member in merged.members:
		by_entry[member.entry] = member
	_check(
		by_entry.get("X.MES", {}).get("role") == "event_entry" and by_entry.get("X.MES", {}).get("bound_by") == ["a_v1"],
		"X.MES keeps its catalog role and binds a_v1"
	)
	_check(
		by_entry.get("Y.MES", {}).get("role") == "analysis_group_member" and by_entry.get("Y.MES", {}).get("bound_by") == ["a_v1", "b_v1"],
		"Y.MES becomes an analysis group member bound to both groups"
	)
	var profiles: Array = []
	for group in merged.groups:
		profiles.append(group.profile)
	_check(profiles == ["a_v1", "b_v1"], "groups are returned sorted by profile")

	_write_group(directory, "c_v1.json", "c_v1", "9".repeat(64), [{"entry": "Y.MES", "entry_sha256": "9".repeat(64)}])
	var conflicted := Exporter.new().analysis_group_members(directory, catalog_members)
	var mentions_conflict := false
	for failure in conflicted.get("failures", []):
		if str(failure).contains("Y.MES") and str(failure).contains("c_v1"):
			mentions_conflict = true
	_check(not conflicted.get("ok", true) and mentions_conflict, "conflicting fingerprint across groups fails and names the entry and group")

	var handle := FileAccess.open(directory.path_join("c_v1.json"), FileAccess.WRITE)
	handle.store_string(JSON.stringify({
		"schema": "kakyu_playback_analysis_group/v6",
		"group_id": "c_v1",
		"archive_sha256": "a".repeat(64),
		"source_members": [{"entry": "Y.MES", "entry_sha256": "9".repeat(64)}],
		"routes": [],
	}))
	handle.close()
	var missing_payload := Exporter.new().analysis_group_members(directory, catalog_members)
	_check(not missing_payload.get("ok", true), "profile missing payload_sha256 fails")

	# Two files sharing one group_id but distinct payload hashes are two
	# legitimate versions of the same group; both merge successfully.
	_write_group(directory, "c_v1.json", "a_v1", "4".repeat(64), [{"entry": "W.MES", "entry_sha256": "4".repeat(64)}])
	var shared_group_id := Exporter.new().analysis_group_members(directory, catalog_members)
	_check(shared_group_id.get("ok", false), "two files sharing a group_id with distinct payload hashes both merge")

	# Two files sharing one payload_sha256 would record the same measurement
	# twice and must fail.
	_write_group(directory, "d_v1.json", "d_v1", "4".repeat(64), [{"entry": "V.MES", "entry_sha256": "5".repeat(64)}])
	var duplicate_payload := Exporter.new().analysis_group_members(directory, catalog_members)
	var mentions_payload_duplicate := false
	for failure in duplicate_payload.get("failures", []):
		if str(failure).contains("payload_sha256"):
			mentions_payload_duplicate = true
	_check(not duplicate_payload.get("ok", true) and mentions_payload_duplicate, "duplicate payload_sha256 across profile files fails")

	_remove_fixture(directory)


func _write_group(directory: String, file_name: String, group_id: String, payload_sha256: String, members: Array) -> void:
	var handle := FileAccess.open(directory.path_join(file_name), FileAccess.WRITE)
	handle.store_string(JSON.stringify({
		"schema": "kakyu_playback_analysis_group/v6",
		"group_id": group_id,
		"archive_sha256": "a".repeat(64),
		"source_members": members,
		"routes": [],
		"payload_sha256": payload_sha256,
	}))
	handle.close()


func _full_build_selects_every_row() -> void:
	# EP-10 unit 5b/c: every catalog row is EP-10 generated now, so a full
	# build (an empty id list) selects all 189 of them (EP-12 catalog part,
	# 2026-09-24: +3 promoted a-date flow rows; EP-12 B date template unit,
	# 2026-09-25: +3 more promoted b-date flow rows; EP-12 C..L date batch,
	# 2026-09-25: +27 more promoted c..l-date flow rows; EP-12 PROMIS
	# checkpoint C, 2026-09-25: +12 promoted 01m-<letter>-promis rows;
	# EP-12 leftovers unit, 2026-09-26: +2 more promoted flow rows,
	# d-date-hotel and l-date-date5).
	var catalog := EventCatalogScript.new()
	var loaded: Dictionary = catalog.load_file(CATALOG_PATH)
	_check(loaded.get("ok", false), "seeded catalog loads for the full-build selection check")
	if not loaded.get("ok", false):
		return
	var selected := Exporter.new().select_event_ids(catalog, [])
	var all_ids := {}
	for untyped_event in catalog.get_events():
		var event: Dictionary = untyped_event
		all_ids[str(event.event_id)] = true
	_check(selected.size() == 681 and selected.size() == all_ids.size(), "a full build selects all 681 generated rows")
	var only_cataloged := true
	for event_id in selected:
		if not all_ids.has(event_id):
			only_cataloged = false
	_check(only_cataloged, "a full build selects only cataloged event ids")


## TD-64: one package gives all of its code sources one CP932 codec, so the
## 0.88 MB encode map is built once per package rather than once per entry.
## The codec is not process-wide: another package gets its own.
func _text_codec_is_shared_per_package() -> void:
	var built := fixture_built("A.MES")
	var second := fixture_built("B.MES")
	built.merge(Exporter.new().payloads_for(
		{"A.MES": fixture_document("A.MES"), "B.MES": fixture_document("B.MES")},
		{"A.MES": fixture_text("A.MES"), "B.MES": fixture_text("B.MES")}
	), true)
	built.events.append(second.events[0])
	built.entry_reports.append(second.entry_reports[0])
	var serialized := Exporter.new().serialize(built)
	_check(serialized.get("ok", false), "two-entry codec fixture serializes")
	if not serialized.get("ok", false):
		return
	var directory := _root.path_join("codec")
	_check(Exporter.new().write(directory, serialized).ok, "two-entry codec fixture publishes")
	var package_one := Package.new()
	var package_two := Package.new()
	_check(package_one.load_directory(directory).ok and package_two.load_directory(directory).ok, "two-entry codec fixture loads twice")
	_check(package_one.entry_names() == ["A.MES", "B.MES"], "the codec fixture package carries both entries")
	var one_a: KakyuPlaybackPackageCodeSource = package_one.code_source("A.MES")
	var one_b: KakyuPlaybackPackageCodeSource = package_one.code_source("B.MES")
	var two_a: KakyuPlaybackPackageCodeSource = package_two.code_source("A.MES")
	var two_b: KakyuPlaybackPackageCodeSource = package_two.code_source("B.MES")
	_check(one_a._cp932 != null and one_a._cp932 == one_b._cp932, "one package's code sources share one codec")
	_check(two_a._cp932 != null and two_a._cp932 == two_b._cp932, "the second package's code sources share one codec too")
	_check(one_a._cp932 != two_a._cp932, "two packages do not share a codec")
	# Reloading commits a fresh snapshot with its own codec.
	var before_reload = one_a._cp932
	_check(package_one.load_directory(directory).ok, "the codec fixture package reloads")
	_check(package_one.code_source("A.MES")._cp932 != before_reload, "a reload builds a new codec rather than keeping the old one")


## TD-64 part 2: the reader keeps verified bytes and parses a code source on
## first need, under a bounded cache. The fixture package has three event
## entries and a library, each with a text record, so every decode re-encodes
## message text through the package's shared codec.
const LAZY_STRINGS := ["日本語ｱAB", "ひらがな、"]
const LAZY_LIBRARY := "LIBLARY.LIB"


func _lazy_identity(entry: String) -> String:
	return "abcdef0123456789"[entry.unicode_at(0) % 16].repeat(64)


func _lazy_text_record(at: int, string_index: int) -> Dictionary:
	return {"at": at, "end": at + 10, "op": "text", "id": 1, "payload_lead": 65 + at,
		"dialogue_boundary_pattern": at == 0, "operands": [{"t": "text", "s": string_index}]}


func _lazy_return_record(at: int) -> Dictionary:
	return {"at": at, "end": at + 10, "op": "script_return", "id": 0, "operands": []}


func _lazy_event_document(entry: String) -> Dictionary:
	var identity := _lazy_identity(entry)
	return {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": entry, "entry_sha256": identity,
		"code_size": 20, "code_sha256": identity, "address_table": [0, 10],
		"regions": [{"at": 0, "end": 20}], "provenance_records": [],
		"records": [_lazy_text_record(0, 0), _lazy_return_record(10)]}


func _lazy_library_document() -> Dictionary:
	var identity := _lazy_identity(LAZY_LIBRARY)
	return {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": LAZY_LIBRARY, "entry_sha256": identity,
		"kind": "library", "code_size": 40, "code_sha256": identity, "address_table": [],
		"routines": [
			{"routine_id": 5, "at": 0, "end": 20, "provenance_records": [],
				"records": [_lazy_text_record(0, 0), _lazy_return_record(10)]},
			{"routine_id": 2, "at": 20, "end": 40, "provenance_records": [],
				"records": [_lazy_text_record(20, 1), _lazy_return_record(30)]},
		]}


## A built result with the event entries A, B and C and the library.
func _lazy_built() -> Dictionary:
	var built := fixture_built("A.MES")
	var documents := {}
	var texts := {}
	built.events = []
	built.entry_reports = []
	for entry in ["A.MES", "B.MES", "C.MES", LAZY_LIBRARY]:
		documents[entry] = _lazy_library_document() if entry == LAZY_LIBRARY else _lazy_event_document(entry)
		texts[entry] = {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": entry,
			"encoding": "utf-8", "strings": LAZY_STRINGS.duplicate()}
		built.entry_reports.append({"entry": entry, "entry_sha256": _lazy_identity(entry), "role": "event_entry"})
		if entry != LAZY_LIBRARY:
			built.events.append({"event_id": entry, "source": {"callee": {"entry": entry, "start_coordinate": 0}},
				"terminals": [{"offset": 0}], "presets": [], "choices": []})
	built.merge(Exporter.new().payloads_for(documents, texts), true)
	return built


## Publishes a fresh copy of the lazy fixture package and returns its directory.
func _publish_lazy(name: String) -> String:
	var serialized := Exporter.new().serialize(_lazy_built())
	var directory := _root.path_join(name)
	var written := Exporter.new().write(directory, serialized)
	_check(serialized.get("ok", false) and written.get("ok", false), "the lazy fixture '%s' serializes and publishes" % name)
	return directory


func _lazy_package(directory: String, cache_limit: int) -> Package:
	var package := Package.new()
	package.source_cache_limit = cache_limit
	var loaded := package.load_directory(directory)
	_check(loaded.get("ok", false), "the lazy fixture loads with a cache of %d" % cache_limit)
	return package


## Every answer a code source gives about its entry, in a form two sources can
## be compared by.
func _source_answers(source: KakyuPlaybackPackageCodeSource) -> Array:
	var answers := []
	var size := source.size()
	for offset in range(-1, size + 2):
		answers.append(var_to_str(source.decode_at(offset)))
		answers.append(var_to_str(source.decode_at_structural(offset, 15)))
		answers.append(source.is_dialogue_boundary_pattern(offset, size))
		answers.append(source.dialogue_boundary_end(offset, size))
		answers.append(source.byte_at(offset, size))
	answers.append(source.sha256_range(0, size))
	answers.append(source.sha256_range(3, 5))
	answers.append(source.hex_range(0, 4))
	answers.append(source.record_count())
	answers.append(var_to_str(source.routines()))
	answers.append(source.entry())
	answers.append(size)
	answers.append(var_to_str(source.address_table()))
	answers.append(source.last_error)
	return answers


func _lazy_sources_parse_on_first_use() -> void:
	var package := _lazy_package(_publish_lazy("lazy_first_use"), 32)
	var stats := package.source_cache_stats()
	_check(int(stats.parses) == 0 and int(stats.resident) == 0, "a load leaves no source parsed")
	_check(int(stats.limit) == 32 and int(stats.bytes) > 0, "the cache limit is the one set and the verified bytes are kept")
	var source := package.code_source("A.MES")
	_check(
		source.entry() == "A.MES" and source.size() == 20 and source.address_table() == ([0, 10] as Array[int])
		and package.code_size("A.MES") == 20 and package.address_table("A.MES") == ([0, 10] as Array[int]),
		"entry, size and address table answer from the load's metadata"
	)
	_check(
		source.hex_range(0, 4) == KakyuMesCodeSource.RANGE_UNAVAILABLE and package.container_document("A.MES").ok
		and str(package.container_document("A.MES").entry_sha256) == _lazy_identity("A.MES")
		and package.library_index("A.MES").routines.is_empty() and package.routines("A.MES").is_empty(),
		"the metadata accessors, the container document and an event's routines parse nothing"
	)
	_check(int(package.source_cache_stats().parses) == 0, "none of those parsed a source")
	var first := source.decode_at(0)
	_check(first.ok and first.operands[0].raw_bytes == CodecScript.new().encode(LAZY_STRINGS[0]).data, "the first decode re-encodes the packaged text")
	_check(int(package.source_cache_stats().parses) == 1 and int(package.source_cache_stats().resident) == 1, "the first use parses the source once")
	source.decode_at(10)
	source.decode_at_structural(0, 20)
	source.byte_at(1, 20)
	source.sha256_range(0, 20)
	_check(int(package.source_cache_stats().parses) == 1, "later calls on the same source do not parse again")
	_check(not package.code_source("B.MES").decode_at(99).ok and int(package.source_cache_stats().parses) == 2, "a second source parses on its own first use")
	_check(package.library_index(LAZY_LIBRARY).by_id.size() == 2 and int(package.source_cache_stats().parses) == 3, "a library index parses the library")
	_check(package.text_strings("A.MES") == LAZY_STRINGS and int(package.source_cache_stats().parses) == 3, "text strings come from the kept bytes without parsing a source")
	_check(package.text_strings("MISSING.MES").is_empty() and package.code_source("MISSING.MES") == null, "an entry that is not in the package has no strings and no source")


func _lazy_cache_evicts_and_redecodes_identically() -> void:
	var package := _lazy_package(_publish_lazy("lazy_evict"), 2)
	var source_a := package.code_source("A.MES")
	var source_b := package.code_source("B.MES")
	var source_c := package.code_source("C.MES")
	var before_a := _source_answers(source_a)
	var before_b := _source_answers(source_b)
	var stats := package.source_cache_stats()
	_check(int(stats.parses) == 2 and int(stats.evictions) == 0 and int(stats.resident) == 2, "a cache of 2 holds two sources")
	var before_c := _source_answers(source_c)
	stats = package.source_cache_stats()
	_check(int(stats.parses) == 3 and int(stats.evictions) == 1 and int(stats.resident) == 2, "a third source evicts the oldest")
	source_b.decode_at(0)
	_check(int(package.source_cache_stats().parses) == 3, "the source used after the eviction is still resident")
	var after_a := _source_answers(source_a)
	_check(int(package.source_cache_stats().parses) == 4, "the evicted source parses again on its next use")
	_check(after_a == before_a, "the evicted source decodes byte-identical results after re-parsing")
	_check(
		package.code_source("A.MES") == source_a and package.code_source("B.MES") == source_b and package.code_source("C.MES") == source_c,
		"code_source() returns the same shell for the life of the snapshot, across evictions"
	)
	_check(_source_answers(source_b) == before_b and _source_answers(source_c) == before_c, "the other sources re-decode identically too")
	# Recency, not arrival: the source used again is the one kept.
	var recent := _lazy_package(_publish_lazy("lazy_recency"), 2)
	recent.code_source("A.MES").decode_at(0)
	recent.code_source("B.MES").decode_at(0)
	recent.code_source("A.MES").decode_at(0)
	recent.code_source("C.MES").decode_at(0)
	var parses := int(recent.source_cache_stats().parses)
	recent.code_source("A.MES").decode_at(0)
	_check(parses == 3 and int(recent.source_cache_stats().parses) == 3, "a source used again is promoted and the least recently used one is evicted")
	recent.code_source("B.MES").decode_at(0)
	_check(int(recent.source_cache_stats().parses) == 4, "the evicted one is B")
	# A cache of 1 is the floor; a smaller request means 1, and a change applies at once.
	var small := _lazy_package(_publish_lazy("lazy_floor"), 0)
	_check(int(small.source_cache_stats().limit) == 1, "a cache limit below 1 is 1")
	var eager_codec := CodecScript.new()
	var expected_a := _source_answers(PackageSourceScript.new(_lazy_event_document("A.MES"), LAZY_STRINGS, eager_codec))
	var expected_b := _source_answers(PackageSourceScript.new(_lazy_event_document("B.MES"), LAZY_STRINGS, eager_codec))
	var interleaved_a := small.code_source("A.MES")
	var interleaved_b := small.code_source("B.MES")
	var matches := true
	for pass_index in range(3):
		matches = matches and _source_answers(interleaved_a) == expected_a and _source_answers(interleaved_b) == expected_b
	_check(matches and int(small.source_cache_stats().resident) == 1, "with a cache of 1, two sources used alternately still answer as a fresh source does")
	var interleaved_ok := true
	for offset in range(0, 20):
		interleaved_ok = interleaved_ok and var_to_str(interleaved_a.decode_at(offset)) == var_to_str(PackageSourceScript.new(_lazy_event_document("A.MES"), LAZY_STRINGS, eager_codec).decode_at(offset))
		interleaved_ok = interleaved_ok and var_to_str(interleaved_b.decode_at(offset)) == var_to_str(PackageSourceScript.new(_lazy_event_document("B.MES"), LAZY_STRINGS, eager_codec).decode_at(offset))
	_check(interleaved_ok, "a cache of 1 evicts on every call and every decode is still right")
	var shrinking := _lazy_package(_publish_lazy("lazy_shrink"), 8)
	for entry in ["A.MES", "B.MES", "C.MES"]:
		shrinking.code_source(entry).decode_at(0)
	shrinking.source_cache_limit = 1
	_check(int(shrinking.source_cache_stats().resident) == 1 and int(shrinking.source_cache_stats().limit) == 1, "lowering the limit evicts down to it at once")


func _lazy_reader_ignores_files_rewritten_after_load() -> void:
	var directory := _publish_lazy("lazy_rewritten")
	var package := _lazy_package(directory, 2)
	var source_a := package.code_source("A.MES")
	var source_b := package.code_source("B.MES")
	var source_library := package.code_source(LAZY_LIBRARY)
	var before_a := _source_answers(source_a)
	var before_b := _source_answers(source_b)
	var before_library := _source_answers(source_library)
	var index_before := var_to_str(package.library_index(LAZY_LIBRARY))
	var strings_before := package.text_strings("A.MES")
	# Rewrite every package file after the load, and make the parsed sources go.
	for group in ["events", "text"]:
		for stem in ["A", "B", "C", "LIBLARY"]:
			var handle := FileAccess.open(directory.path_join("%s/%s.json" % [group, stem]), FileAccess.WRITE)
			handle.store_string('{"entry": "REWRITTEN", "strings": ["rewritten"], "records": [], "code_size": 1}')
			handle.close()
	var handle_manifest := FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	handle_manifest.store_string("{}")
	handle_manifest.close()
	package.code_source("C.MES").decode_at(0)
	_check(int(package.source_cache_stats().evictions) >= 2, "the rewritten files' sources were evicted")
	_check(_source_answers(source_a) == before_a, "a file rewritten on disk after the load changes no decode (A)")
	_check(_source_answers(source_b) == before_b, "a file rewritten on disk after the load changes no decode (B)")
	_check(_source_answers(source_library) == before_library, "a file rewritten on disk after the load changes no decode (library)")
	_check(var_to_str(package.library_index(LAZY_LIBRARY)) == index_before, "nor the library index")
	_check(package.text_strings("A.MES") == strings_before and package.text_strings("A.MES") == LAZY_STRINGS, "nor the text strings")
	_check(package.manifest().entries.size() == 4 and package.entry_names().size() == 4, "nor the manifest the load verified")


func _read_fixture_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _lazy_reader_matches_the_eager_source() -> void:
	var directory := _publish_lazy("lazy_parity")
	var package := _lazy_package(directory, 2)
	var codec := CodecScript.new()
	var all_match := true
	var metadata_match := true
	for entry in package.entry_names():
		var stem: String = entry.get_basename()
		var document := _read_fixture_json(directory.path_join("events/%s.json" % stem))
		var text := _read_fixture_json(directory.path_join("text/%s.json" % stem))
		var eager := PackageSourceScript.new(document, text.strings, codec)
		var lazy := package.code_source(entry)
		all_match = all_match and _source_answers(lazy) == _source_answers(eager)
		metadata_match = metadata_match and package.code_size(entry) == eager.size() and package.code_size(entry) == int(document.code_size)
		metadata_match = metadata_match and package.address_table(entry) == eager.address_table()
		metadata_match = metadata_match and package.text_strings(entry) == text.strings
		metadata_match = metadata_match and str(package.container_document(entry).entry_sha256) == str(document.entry_sha256)
		metadata_match = metadata_match and package.container_document(entry).code_source == lazy
		metadata_match = metadata_match and var_to_str(package.container_document(entry).header) == var_to_str({"code_size": eager.size(), "entry_offsets": eager.address_table()})
	_check(all_match, "every answer of every lazy source matches a source built from the same documents")
	_check(metadata_match, "code_size, address_table, text strings and the container document match the eager values")
	var library_document := _read_fixture_json(directory.path_join("events/LIBLARY.json"))
	var eager_library := PackageSourceScript.new(library_document, LAZY_STRINGS, codec)
	var by_id := eager_library.routines()
	var ids := by_id.keys()
	ids.sort()
	var routines: Array[Dictionary] = []
	for routine_id in ids:
		routines.append((by_id[routine_id] as Dictionary).duplicate(true))
	var expected_index := {"ok": true, "schema": Version.MES_LIBRARY_INDEX_SCHEMA, "registration_count": routines.size(),
		"terminal_offset": -1, "routines": routines, "by_id": by_id}
	_check(var_to_str(package.library_index(LAZY_LIBRARY)) == var_to_str(expected_index) and routines.size() == 2, "library_index matches the eager source's routines")
	_check(package.routines(LAZY_LIBRARY).keys() == [5, 2] and package.routines("A.MES").is_empty(), "routines() is the library's, and an event has none")
	_check(not package.library_index("MISSING.LIB").ok and not package.container_document("MISSING.MES").ok, "an unknown entry has no index and no container document")
	_check(package.code_size("MISSING.MES") == 0 and package.address_table("MISSING.MES").is_empty(), "an unknown entry has no size and no table")
	# Refusals set the shell's own last_error, which outlives the parsed source.
	var shell := package.code_source("A.MES")
	var refused := shell.decode_at(500)
	_check(not refused.ok and shell.last_error == str(refused.error) and not shell.last_error.is_empty(), "a refusal sets the shell's last_error as a source's own is set")


## The set of public methods a code source declares, pinned. Each is either
## forwarded by the shell (and answered by `_source_answers`, which the parity
## test compares with an eager source) or inherited on purpose: `entry`,
## `address_table` and `size` answer from the metadata the load recorded and
## `hex_range` refuses every range. A method added to the source therefore fails
## here until someone decides which it is, instead of the shell answering it
## from an empty state.
func _lazy_shell_declares_every_source_method() -> void:
	var forwarded := ["routines", "record_count", "decode_at", "decode_at_structural",
		"is_dialogue_boundary_pattern", "dialogue_boundary_end", "byte_at", "sha256_range"]
	var inherited_on_purpose := ["entry", "address_table", "size", "hex_range"]
	var base_only := ["for_bytecode"]
	var source_script: Script = PackageSourceScript
	# An overridden method is listed once per class that declares it.
	var declared := {}
	for method in source_script.get_script_method_list():
		var method_name := str(method.name)
		if not method_name.begins_with("_"):
			declared[method_name] = true
	var pinned := forwarded + inherited_on_purpose + base_only
	var names := declared.keys()
	names.sort()
	pinned.sort()
	_check(names == pinned, "the code source declares exactly the public methods the shell was written against %s" % str(names))
	# The forwarded ones really are the shell's own: a shell over an empty store
	# does not answer them as the source's empty state would.
	var shell: KakyuPlaybackPackageCodeSource = LazySourceScript.new(null, "A.MES", 20, [0, 10] as Array[int], false, CodecScript.new())
	_check(shell.entry() == "A.MES" and shell.size() == 20 and shell.address_table() == ([0, 10] as Array[int]), "a shell answers entry, size and address table by itself")
	_check(shell.routines().is_empty() and shell.hex_range(0, 1) == KakyuMesCodeSource.RANGE_UNAVAILABLE, "an event shell has no routines and refuses a hex range without a store")


func _lazy_reload_swaps_the_snapshot() -> void:
	var good := _publish_lazy("lazy_reload_good")
	var other := _publish_lazy("lazy_reload_other")
	var package := _lazy_package(good, 2)
	var source_a := package.code_source("A.MES")
	var before := _source_answers(source_a)
	var stats := package.source_cache_stats()
	var manifest_hash := str(package.manifest().package_sha256)
	# A failure at the manifest, and one in the middle of the streaming pass.
	var bad_manifest := _publish_lazy("lazy_reload_bad_manifest")
	var changed: Dictionary = _read_fixture_json(bad_manifest.path_join("manifest.json"))
	changed.schema = "invalid"
	_write_manifest(bad_manifest, changed)
	var bad_text := _publish_lazy("lazy_reload_bad_text")
	var handle := FileAccess.open(bad_text.path_join("text/C.json"), FileAccess.WRITE)
	handle.store_string('{"strings": []}')
	handle.close()
	for failing in [bad_manifest, bad_text]:
		var failed := package.load_directory(failing)
		_check(not failed.ok and package.last_error == str(failed.error), "the reload of %s fails" % failing.get_file())
		_check(package.source_cache_stats() == stats, "a failed reload leaves the cache and its bytes as they were (%s)" % failing.get_file())
		_check(package.code_source("A.MES") == source_a and str(package.manifest().package_sha256) == manifest_hash, "a failed reload leaves the shells and the manifest (%s)" % failing.get_file())
		_check(_source_answers(source_a) == before and int(package.source_cache_stats().parses) == int(stats.parses), "the old shell answers from the old snapshot without parsing again (%s)" % failing.get_file())
	var loaded := package.load_directory(other)
	_check(loaded.ok, "a good reload commits")
	var fresh := package.source_cache_stats()
	_check(int(fresh.parses) == 0 and int(fresh.resident) == 0 and int(fresh.limit) == 2, "a reload swaps the cache and keeps the limit")
	_check(package.code_source("A.MES") != source_a, "a reload hands out new shells")
	_check(_source_answers(source_a) == before, "a shell from the replaced snapshot still answers from its own bytes")
	_check(_source_answers(package.code_source("A.MES")) == before, "the new snapshot's shell answers the same")


func _lazy_load_fails_closed_on_a_member_file() -> void:
	# The pass reads each entry's two files and checks them as the whole-package
	# read did: existence, JSON, then size and hash against the manifest.
	var cases := {
		"a missing events file": ["events/B.json", ""],
		"an events file that is not JSON": ["events/B.json", "not json"],
		"an events file that is not an object": ["events/B.json", "[]"],
		"an empty text file": ["text/C.json", null],
		"a changed library document": ["events/LIBLARY.json", "{}"],
	}
	for label in cases:
		var directory := _publish_lazy("lazy_member")
		var target: String = cases[label][0]
		var content: Variant = cases[label][1]
		if label == "a missing events file":
			DirAccess.remove_absolute(directory.path_join(target))
		else:
			var handle := FileAccess.open(directory.path_join(target), FileAccess.WRITE)
			handle.store_string("" if content == null else str(content))
			handle.close()
		var package := Package.new()
		_check(not package.load_directory(directory).ok and package.entry_names().is_empty(), "%s fails the load" % label)
		_check(int(package.source_cache_stats().parses) == 0 and int(package.source_cache_stats().bytes) == 0, "and leaves nothing behind (%s)" % label)
		_remove_fixture(directory)
	# A file of the right JSON whose bytes differ from the manifest's fingerprint.
	var changed_directory := _publish_lazy("lazy_member_hash")
	var text := FileAccess.get_file_as_string(changed_directory.path_join("text/A.json"))
	var handle_changed := FileAccess.open(changed_directory.path_join("text/A.json"), FileAccess.WRITE)
	handle_changed.store_string(text + " ")
	handle_changed.close()
	var changed_package := Package.new()
	var refused := changed_package.load_directory(changed_directory)
	_check(not refused.ok and str(refused.error).contains("does not match the manifest fingerprint"), "a file whose bytes differ only in whitespace fails the fingerprint")


## The per-entry accumulator gives the whole-set form's result for any feed order.
func _inventory_accumulator_matches_the_whole_set_form() -> void:
	var region := {"id": "entry_0000", "index": 0, "at": 0, "end": 400}
	var documents := {}
	var strings := {}
	var targets := {"A.MES": "B.MES", "B.MES": "a.mes", "C.MES": "X.MES"}
	var names := {"A.MES": "r.mmo", "B.MES": "q.mmo", "C.MES": ""}
	for entry in ["A.MES", "B.MES", "C.MES"]:
		var records := [{"op": "script_transfer", "id": 15, "at": 30, "end": 38, "script_target": targets[entry], "operands": []}]
		if not str(names[entry]).is_empty():
			records.append({"op": "mmo_resource_marker", "id": 13, "at": 10, "end": 20, "operands": [
				{"t": "resource_name", "kind": "mmo_resource_marker", "name": names[entry], "resource_kind": "mmo_resource_marker"}]})
		documents[entry] = {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": entry, "code_size": 400,
			"address_table": [0], "regions": [region], "provenance_records": [], "records": records}
		strings[entry] = []
	var entries := ["C.MES", "A.MES", "B.MES"]
	var inventory := Inventory.new()
	var whole := inventory._expected(documents, strings, entries)
	_check(not whole.has("error") and whole.members.size() == 2 and whole.targets.size() == 3, "the fixture documents carry occurrences and references")
	var forward := inventory.begin(entries)
	for entry in ["A.MES", "B.MES", "C.MES"]:
		forward.add(entry, documents[entry], strings[entry])
	var backward := inventory.begin(entries)
	for entry in ["C.MES", "B.MES", "A.MES"]:
		backward.add(entry, documents[entry], strings[entry])
	var expected_json := JSON.stringify(whole, "", true, true)
	_check(JSON.stringify(forward.finish(), "", true, true) == expected_json, "feeding the entries in sorted order gives the whole-set result")
	_check(JSON.stringify(backward.finish(), "", true, true) == expected_json, "feeding them in reverse order gives the same result")
	var members: Array = backward.finish().members
	_check(members.size() == 2 and members[0].entry == "A.MES" and members[1].entry == "B.MES", "the members come out sorted by entry")
	var short := inventory.begin(entries)
	short.add("A.MES", documents["A.MES"], strings["A.MES"])
	short.add("C.MES", null, [])
	var incomplete := short.finish()
	_check(incomplete.has("error") and str(incomplete.error).contains("B.MES"), "a declared member that was not fed is refused, the first in sorted order")
	var manifest := {"entries": [{"entry": "C.MES"}, {"entry": "A.MES"}, 5, {"entry": "B.MES"}]}
	_check(inventory.manifest_entries(manifest) == ["C.MES", "A.MES", "B.MES"], "the declared members come from the manifest's entries in its order")
	_check(not inventory.carries_blocks(manifest) and inventory.carries_blocks({"script_references": {}}), "a manifest without either block has nothing to accumulate")
	_check(inventory.accumulated_error({"script_references": {}}, {"error": "x"}) == "x", "an accumulation error is reported as the error")
	_check(inventory.inventory_error(manifest, {}, {}).is_empty(), "the whole-set check makes no claim for a manifest without blocks")
	var claiming := {"entries": manifest.entries, "script_references": {}}
	_check(inventory.inventory_error(claiming, {"A.MES": documents["A.MES"]}, {}).contains("has no document"), "the whole-set check refuses a member without a document")


func _sha256_of(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


## TD-64 part 2: the exporter serializes each member as it is built. A member's
## payloads are its two package files, byte for byte what the whole-document
## serialization wrote, and `serialize()` lists them in the order the build
## made them (events then text per member), the manifest last.
func _streamed_members_serialize_in_member_order() -> void:
	var exporter := Exporter.new()
	var documents := {"B.MES": fixture_document("B.MES"), "A.MES": fixture_document("A.MES")}
	var texts := {"B.MES": fixture_text("B.MES"), "A.MES": fixture_text("A.MES")}
	var streamed := exporter.payloads_for(documents, texts)
	_check(streamed.keys().size() == 2 and streamed.has("payloads") and streamed.has("inventory_evidence"), "the streamed members are the payloads and the inventory evidence")
	_check((streamed.payloads as Dictionary).keys() == ["B.MES", "A.MES"], "the payloads keep the members in the order the build made them")
	_check(not (streamed.inventory_evidence as Dictionary).has("error") and (streamed.inventory_evidence.member_set as Dictionary).size() == 2, "the inventory evidence covers both members")
	var all_bytes_match := true
	for entry in ["A.MES", "B.MES"]:
		var stem: String = entry.get_basename()
		var pair: Dictionary = streamed.payloads[entry]
		var events_bytes := JSON.stringify(documents[entry], "", false, true).to_utf8_buffer()
		var text_bytes := JSON.stringify(texts[entry], "", false, true).to_utf8_buffer()
		all_bytes_match = (
			all_bytes_match
			and pair.events.name == "events/%s.json" % stem and pair.events.payload == events_bytes
			and int(pair.events.size) == events_bytes.size() and pair.events.sha256 == _sha256_of(events_bytes)
			and pair.text.name == "text/%s.json" % stem and pair.text.payload == text_bytes
			and int(pair.text.size) == text_bytes.size() and pair.text.sha256 == _sha256_of(text_bytes)
		)
	_check(all_bytes_match, "a member's payloads are its documents' JSON, with their size and SHA-256")

	var built := fixture_built("A.MES")
	built.entry_reports.append({"entry": "B.MES", "entry_sha256": "a".repeat(64), "role": "event_entry"})
	built.events.append({"event_id": "B.MES", "source": {"callee": {"entry": "B.MES", "start_coordinate": 0}},
		"terminals": [{"offset": 0}], "presets": [], "choices": []})
	built.merge(streamed, true)
	var serialized := exporter.serialize(built)
	_check(serialized.get("ok", false), "streamed members serialize: %s" % str(serialized.get("failures", [])))
	if not serialized.get("ok", false):
		return
	var names: Array = []
	for file in serialized.files:
		names.append(file.name)
	_check(names == ["events/B.json", "text/B.json", "events/A.json", "text/A.json", "manifest.json"], "the files are listed in member order with the manifest last")
	var listed: Array = []
	for file in serialized.manifest.files:
		listed.append(file.name)
	_check(listed == ["events/A.json", "events/B.json", "text/A.json", "text/B.json"], "the manifest lists its files sorted")
	var original: PackedByteArray = streamed.payloads["B.MES"].events.payload
	serialized.files[0].payload = PackedByteArray([1])
	_check(streamed.payloads["B.MES"].events.payload == original and built.payloads["B.MES"].events.payload == original, "a serialized file is a copy, so changing it leaves the build result alone")
	var directory := _root.path_join("streamed")
	_check(Exporter.new().write(directory, exporter.serialize(built)).ok, "the streamed package publishes and reopens")
	_check(Package.new().load_directory(directory).ok, "the streamed package loads")


func _serialize_fails_closed_on_streamed_members() -> void:
	var without_payloads := fixture_built("A.MES")
	without_payloads.erase("payloads")
	_check(not Exporter.new().serialize(without_payloads).get("ok", true), "serialize refuses a build result without member payloads")
	var documents_only := fixture_built("A.MES")
	documents_only.erase("payloads")
	documents_only["documents"] = {"A.MES": fixture_document("A.MES")}
	documents_only["texts"] = {"A.MES": fixture_text("A.MES")}
	_check(not Exporter.new().serialize(documents_only).get("ok", true), "serialize no longer takes documents in place of payloads")
	var malformed := fixture_built("A.MES")
	malformed.payloads["A.MES"] = {"events": malformed.payloads["A.MES"].events}
	_check(not Exporter.new().serialize(malformed).get("ok", true), "serialize refuses a member with one payload missing")
	var not_an_object := fixture_built("A.MES")
	not_an_object.payloads["A.MES"] = "events/A.json"
	_check(not Exporter.new().serialize(not_an_object).get("ok", true), "serialize refuses a member that is not a pair of payloads")
	var unserializable := fixture_built("A.MES")
	unserializable.payloads["A.MES"].text.ok = false
	var refused := Exporter.new().serialize(unserializable)
	_check(not refused.get("ok", true) and str(refused.failures).contains("text/A.json could not be serialized"), "serialize refuses a payload that did not survive its reparse")
	var without_evidence := fixture_built("A.MES")
	without_evidence.erase("inventory_evidence")
	_check(not Exporter.new().serialize(without_evidence).get("ok", true), "serialize refuses a build result without the inventory evidence")
	var other_members := fixture_built("A.MES")
	other_members.merge(Exporter.new().payloads_for({"A.MES": fixture_document("A.MES"), "B.MES": fixture_document("B.MES")},
		{"A.MES": fixture_text("A.MES"), "B.MES": fixture_text("B.MES")}), true)
	_check(not Exporter.new().serialize(other_members).get("ok", true), "serialize refuses inventory evidence for more members than the build reports")
	var wrong_member := fixture_built("A.MES")
	wrong_member.merge(Exporter.new().payloads_for({"C.MES": fixture_document("C.MES")}, {"C.MES": fixture_text("C.MES")}), true)
	_check(not Exporter.new().serialize(wrong_member).get("ok", true), "serialize refuses inventory evidence for other members than the build reports")
	var failed_evidence := fixture_built("A.MES")
	failed_evidence.inventory_evidence = {"error": "Package member A.MES has no document for its media inventory."}
	_check(not Exporter.new().serialize(failed_evidence).get("ok", true), "serialize refuses inventory evidence that is an error")


func _safe_entry_names() -> void:
	var integrity := Integrity.new()
	for accepted in ["GROUND.INC.MES", "A.MES", "LIBLARY.LIB"]:
		_check(integrity.safe_entry(accepted), "safe_entry accepts %s" % accepted)
	for rejected in ["../A.MES", "A..MES", "A/B.MES", ".MES", "a.mes", "A.TXT"]:
		_check(not integrity.safe_entry(rejected), "safe_entry rejects %s" % rejected)


func _remove_fixture(path: String) -> void:
	assert(path == _root or path.begins_with(_root + "/"))
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child in directory.get_directories():
		_remove_fixture(path.path_join(child))
	for child in directory.get_files():
		DirAccess.remove_absolute(path.path_join(child))
	DirAccess.remove_absolute(path)
