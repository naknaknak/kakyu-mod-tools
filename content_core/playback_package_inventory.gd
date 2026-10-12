class_name KakyuPlaybackPackageInventory
extends RefCounted

## The package manifest's `media_inventory` and `script_references` blocks
## (WD-21 U1), written by the producer and recomputed by the reader.
##
## Both blocks are additive optional blocks of the v7 manifest, each with its own
## schema id so that a change of the classifier rules is an explicit
## incompatibility rather than a silent drift. A reader recomputes the ids it
## knows, fails closed on an id it does not, and ignores an absent block; a v7
## manifest without them still loads and makes no inventory claim. This
## repository's reader only.
##
## The evidence for every occurrence is the package's own records (the
## classifier's rules), so the reader recomputes the occurrence set from the
## loaded member documents. The identity table (which original archive ships a
## name, with its size and SHA-256, or that every archive of its kind was
## searched and none does) and the producer's scan cross-check are claims about
## the original archives; the reader checks their shape and their consistency
## with the recomputed occurrences, never the archives. It never opens one. The
## `archives` header's hashes are checked for shape only: the pin against the
## live archive is the producer's (`build()` refuses an archive that is not the
## pinned original), so a later correction of a pin cannot make a package that
## was exported before it unreadable.
##
## Identity states of a (kind, name):
## - `shipped: true` with `rows`, one per archive that holds the name (a
##   declared bank set may contribute several, no other archive combination);
## - `shipped: false` with `searched`, only when every archive of the kind was
##   opened and searched - an absence is a known fact, never a reader error;
## - `shipped: null` with `unavailable`, when an archive of the kind was not
##   available, so nothing is claimed.

const Version := preload("res://content_core/content_core_version.gd")
const ClassifierScript := preload("res://content_core/playback_media_classifier.gd")
const IdentityScript := preload("res://content_core/original_archive_identity.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const NORMALIZATION := "upper_case"
const SEPARATOR := "\u001f"
## The scan's own kinds. `mes_script` hits are `inline_script_execution` names,
## which are script references and not media.
const SCAN_KINDS := ["mmo", "ax", "voice", "mes_script"]
## The scan kinds that are media, and so carry rows when a hit is in no record.
const SCAN_ROW_KINDS := ["mmo", "ax", "voice"]
const CROSS_CHECK_FIELDS := ["record_backed_strict", "record_backed_bounded", "scan_only"]
const SCAN_ONLY_BOUNDARY := "bounded_envelope_scan"
const MEDIA_KEYS := [
	"schema", "normalization", "kind_archives", "extension_archives", "bank_sets", "archives",
	"members", "names", "scan_only", "cross_check", "counts",
]


## An identity table that claims nothing (a package with no media references).
static func empty_identity() -> Dictionary:
	return {"archives": {}, "names": []}


## A scan cross-check with no hits.
static func empty_scan() -> Dictionary:
	var cross_check := {}
	for kind in SCAN_KINDS:
		cross_check[kind] = {"record_backed_strict": 0, "record_backed_bounded": 0, "scan_only": 0}
	return {"scan_only": [], "cross_check": cross_check}


static func name_key(kind: String, name: String) -> String:
	return kind + SEPARATOR + name


## The two blocks for a package, computed from its member documents and the
## producer's identity table and scan cross-check. `entries` are the member
## entry names, `strings_by_entry` each member's text strings. Returns
## `{ok, media_inventory, script_references}` or `{ok: false, error}`. The
## blocks are validated by the reader's own rules before they are returned, so
## a producer can never write what a reader refuses.
func build_blocks(documents: Dictionary, strings_by_entry: Dictionary, entries: Array, identity: Variant, scan: Variant) -> Dictionary:
	return build_blocks_from(_expected(documents, strings_by_entry, entries), identity, scan)


## `build_blocks` over `expected`, an accumulator's `finish()` (TD-64 part 2): a
## producer that fed the accumulator one member at a time, and holds no document
## any more, builds the blocks from what it kept. The identity table and the scan
## are checked before the accumulation, as `build_blocks` always did.
func build_blocks_from(expected: Dictionary, identity: Variant, scan: Variant) -> Dictionary:
	if not identity is Dictionary or not (identity as Dictionary).get("names") is Array or not (identity as Dictionary).get("archives") is Dictionary:
		return _failure("Build result does not carry the media identity table.")
	if not scan is Dictionary or not (scan as Dictionary).get("scan_only") is Array or not (scan as Dictionary).get("cross_check") is Dictionary:
		return _failure("Build result does not carry the media scan cross-check.")
	for untyped_row in (scan as Dictionary).scan_only:
		if not untyped_row is Dictionary:
			return _failure("Build result's media scan-only rows are malformed.")
	if expected.has("error"):
		return _failure(str(expected.error))
	var archives := {}
	var archive_names: Array = (identity.archives as Dictionary).keys()
	archive_names.sort()
	for archive in archive_names:
		archives[str(archive)] = (identity.archives as Dictionary)[archive]
	var names: Array = ContractValues.intify(identity.names)
	names.sort_custom(func(a, b): return _entry_key(a) < _entry_key(b))
	var scan_only: Array = ContractValues.intify(scan.scan_only)
	scan_only.sort_custom(_scan_less)
	var block := {
		"schema": Version.PLAYBACK_MEDIA_INVENTORY_SCHEMA,
		"normalization": NORMALIZATION,
		"kind_archives": ClassifierScript.KIND_ARCHIVES.duplicate(true),
		"extension_archives": ClassifierScript.EXTENSION_ARCHIVES.duplicate(true),
		"bank_sets": ClassifierScript.BANK_SETS.duplicate(true),
		"archives": archives,
		"members": expected.members,
		"names": names,
		"scan_only": scan_only,
		"cross_check": ContractValues.intify(scan.cross_check),
	}
	block["counts"] = _media_counts(expected, names, scan_only)
	var problem := _media_error(block, expected)
	if not problem.is_empty():
		return _failure(problem)
	var references := {
		"schema": Version.PLAYBACK_SCRIPT_REFERENCES_SCHEMA,
		"targets": expected.targets,
		"counts": expected.script_counts,
	}
	return {"ok": true, "media_inventory": block, "script_references": references}


## The reader's recompute: "" when the manifest carries neither block, or when
## every block it carries matches the loaded member documents and is internally
## consistent. `strings_by_entry` maps each member entry to its text strings.
## A thin wrapper over the per-entry accumulator (`begin`): a caller that cannot
## hold every document at once feeds the accumulator one entry at a time and
## calls `accumulated_error` with its result instead.
func inventory_error(manifest: Dictionary, documents: Dictionary, strings_by_entry: Dictionary) -> String:
	if not carries_blocks(manifest):
		return ""
	return accumulated_error(manifest, _expected(documents, strings_by_entry, manifest_entries(manifest)))


## Whether the manifest carries either inventory block. A reader that finds
## neither makes no inventory claim and has nothing to accumulate.
func carries_blocks(manifest: Dictionary) -> bool:
	return manifest.has("media_inventory") or manifest.has("script_references")


## The member entry names the manifest's `entries` list declares, in its order.
func manifest_entries(manifest: Dictionary) -> Array:
	var entries: Array = []
	var reports: Variant = manifest.get("entries", [])
	if reports is Array:
		for report in reports:
			if report is Dictionary:
				entries.append(str((report as Dictionary).get("entry", "")))
	return entries


## The accumulator for `entries`, the member entry names (TD-64 part 2). Feed it
## each member's document and strings with `add`, in any order, then `finish`.
## What it keeps references no document.
func begin(entries: Array) -> Accumulator:
	return Accumulator.new(entries)


## The checks of `inventory_error` over `expected`, an accumulator's `finish()`:
## "" when the manifest's blocks match it and are internally consistent.
func accumulated_error(manifest: Dictionary, expected: Dictionary) -> String:
	if expected.has("error"):
		return str(expected.error)
	if manifest.has("media_inventory"):
		var media_problem := _media_error(manifest.media_inventory, expected)
		if not media_problem.is_empty():
			return media_problem
	if manifest.has("script_references"):
		return _script_error(manifest.script_references, expected)
	return ""


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}


## The occurrence set, the identity keys it needs and the script references,
## recomputed from the member documents alone. It feeds an accumulator in sorted
## entry order, so the result is the one the per-entry path produces.
func _expected(documents: Dictionary, strings_by_entry: Dictionary, entries: Array) -> Dictionary:
	var accumulator := begin(entries)
	for entry in accumulator.entry_names():
		accumulator.add(entry, documents.get(entry), strings_by_entry.get(entry, []))
	return accumulator.finish()


## The per-entry form of `_expected` (TD-64 part 2). `add` takes one member's
## document and strings and keeps only what the aggregates need: the occurrence
## rows of the entry, the identity keys and the script references. `finish`
## sorts the members by entry, so the feed order never changes the result, and
## refuses a result in which a declared member was never fed.
class Accumulator:
	extends RefCounted

	var _classifier := ClassifierScript.new()
	var _entry_names: Array = []
	var _member_set := {}
	var _fed := {}
	var _members: Array[Dictionary] = []
	var _keys := {}
	var _occurrence_index := {}
	var _occurrence_counts := {}
	var _inline_count := 0
	var _references_by_name := {}
	var _via_counts := {}
	var _reference_count := 0


	func _init(entries: Array) -> void:
		_entry_names = entries.duplicate()
		_entry_names.sort()
		for entry in _entry_names:
			_member_set[entry] = true
		for kind in ClassifierScript.KINDS:
			_occurrence_counts[kind] = 0


	## The declared member names, sorted.
	func entry_names() -> Array:
		return _entry_names.duplicate()


	## One member. A document that is not an object counts as not fed, so
	## `finish` reports the member as missing its document.
	func add(entry: Variant, document: Variant, strings_value: Variant) -> void:
		if not document is Dictionary:
			return
		_fed[entry] = true
		var strings: Array = strings_value if strings_value is Array else []
		var rows := _classifier.occurrences(document, strings)
		if not rows.is_empty():
			_members.append({"entry": entry, "occurrences": rows})
		for row in rows:
			_occurrence_counts[row.kind] = int(_occurrence_counts[row.kind]) + 1
			_occurrence_index["%s%s%d%s%s%s%s" % [entry, SEPARATOR, row.at, SEPARATOR, row.kind, SEPARATOR, row.name]] = true
			if not str(row.name).is_empty():
				_keys[KakyuPlaybackPackageInventory.name_key(row.kind, row.name)] = {"kind": row.kind, "name": row.name}
		for reference in _classifier.script_references(document):
			if not _references_by_name.has(reference.name):
				_references_by_name[reference.name] = []
			(_references_by_name[reference.name] as Array).append({"entry": entry, "at": reference.at, "via": reference.via})
			_via_counts[reference.via] = int(_via_counts.get(reference.via, 0)) + 1
			_reference_count += 1
			if reference.via == "inline_script_execution":
				_inline_count += 1


	## The expected sets, or `{error}` when a declared member was never fed.
	func finish() -> Dictionary:
		for entry in _entry_names:
			if not _fed.has(entry):
				return {"error": "Package member %s has no document for its media inventory." % entry}
		var members: Array[Dictionary] = _members.duplicate()
		members.sort_custom(func(a, b): return a.entry < b.entry)
		var target_names: Array = _references_by_name.keys()
		target_names.sort()
		var targets: Array[Dictionary] = []
		var member_targets := 0
		for name in target_names:
			var is_member := _member_set.has(name)
			if is_member:
				member_targets += 1
			var references: Array = _references_by_name[name]
			references.sort_custom(func(a, b):
				if a.entry != b.entry:
					return a.entry < b.entry
				if a.at != b.at:
					return a.at < b.at
				return a.via < b.via)
			targets.append({"name": name, "member": is_member, "references": references})
		var by_via := {}
		var via_names: Array = _via_counts.keys()
		via_names.sort()
		for via in via_names:
			by_via[via] = _via_counts[via]
		return {
			"members": members,
			"member_set": _member_set,
			"keys": _keys,
			"occurrence_index": _occurrence_index,
			"occurrence_counts": _occurrence_counts,
			"inline_count": _inline_count,
			"targets": targets,
			"script_counts": {
				"targets": targets.size(),
				"references": _reference_count,
				"member_targets": member_targets,
				"non_member_targets": targets.size() - member_targets,
				"by_via": by_via,
			},
		}


func _media_counts(expected: Dictionary, names: Array, scan_only: Array) -> Dictionary:
	var name_counts := {}
	for kind in ClassifierScript.KINDS:
		name_counts[kind] = 0
	var states := {"shipped": 0, "absent": 0, "unavailable": 0}
	for untyped_entry in names:
		if not untyped_entry is Dictionary:
			continue
		var entry: Dictionary = untyped_entry
		var kind := str(entry.get("kind", ""))
		if name_counts.has(kind):
			name_counts[kind] = int(name_counts[kind]) + 1
		var shipped: Variant = entry.get("shipped")
		if shipped == null:
			states["unavailable"] = int(states["unavailable"]) + 1
		elif shipped == true:
			states["shipped"] = int(states["shipped"]) + 1
		else:
			states["absent"] = int(states["absent"]) + 1
	return {
		"occurrences": (expected.occurrence_counts as Dictionary).duplicate(),
		"names": name_counts,
		"states": states,
		"scan_only": scan_only.size(),
	}


func _media_error(block: Variant, expected: Dictionary) -> String:
	if not block is Dictionary:
		return "Package media inventory is not an object."
	var inventory: Dictionary = block
	if inventory.get("schema") != Version.PLAYBACK_MEDIA_INVENTORY_SCHEMA:
		return "Package media inventory schema is not supported; it must be %s." % Version.PLAYBACK_MEDIA_INVENTORY_SCHEMA
	if not ContractValues.has_exact_keys(inventory, MEDIA_KEYS):
		return "Package media inventory has unexpected or missing fields."
	if (
		inventory.normalization != NORMALIZATION
		or not _same(inventory.kind_archives, ClassifierScript.KIND_ARCHIVES)
		or not _same(inventory.extension_archives, ClassifierScript.EXTENSION_ARCHIVES)
		or not _same(inventory.bank_sets, ClassifierScript.BANK_SETS)
	):
		return "Package media inventory rules differ from this reader's rules."
	var archives_problem := _archives_error(inventory.archives)
	if not archives_problem.is_empty():
		return archives_problem
	var scan_keys := {}
	var scan_problem := _scan_error(inventory.scan_only, inventory.cross_check, expected, scan_keys)
	if not scan_problem.is_empty():
		return scan_problem
	if not _same(inventory.members, expected.members):
		return "Package media inventory occurrences do not match the package records."
	var keys: Dictionary = (expected.keys as Dictionary).duplicate()
	keys.merge(scan_keys)
	var names_problem := _names_error(inventory.names, keys, inventory.archives)
	if not names_problem.is_empty():
		return names_problem
	if not _same(inventory.counts, _media_counts(expected, inventory.names, inventory.scan_only)):
		return "Package media inventory counts do not match its rows."
	return ""


func _archives_error(archives: Variant) -> String:
	if not archives is Dictionary:
		return "Package media inventory archive identities must be an object."
	for archive in archives:
		if not archive is String or not archive in IdentityScript.MEDIA_ARCHIVES:
			return "Package media inventory names an unknown archive."
		if not _is_sha256((archives as Dictionary)[archive]):
			return "Package media inventory archive identity is not a SHA-256."
	return ""


func _scan_error(scan_only: Variant, cross_check: Variant, expected: Dictionary, scan_keys: Dictionary) -> String:
	if not scan_only is Array or not cross_check is Dictionary:
		return "Package media inventory scan evidence is malformed."
	var previous := ""
	var per_kind := {}
	for kind in SCAN_ROW_KINDS:
		per_kind[kind] = 0
	for untyped_row in scan_only:
		if not untyped_row is Dictionary or not ContractValues.has_exact_keys(untyped_row, ["entry", "at", "kind", "name", "boundary"]):
			return "Package media scan-only row is malformed."
		var row: Dictionary = untyped_row
		var entry: Variant = row.entry
		var kind: Variant = row.kind
		var name: Variant = row.name
		if not entry is String or not (expected.member_set as Dictionary).has(entry):
			return "Package media scan-only row names an entry that is not a member."
		if not kind is String or not kind in SCAN_ROW_KINDS or not name is String or (name as String).is_empty() or name != ClassifierScript.normalize_name(name):
			return "Package media scan-only row has an invalid kind or name."
		if not ContractValues.nonnegative_json_integer(row.at) or row.boundary != SCAN_ONLY_BOUNDARY:
			return "Package media scan-only row has an invalid offset or boundary."
		var key := "%s%s%d%s%s%s%s" % [entry, SEPARATOR, int(row.at), SEPARATOR, kind, SEPARATOR, name]
		if (expected.occurrence_index as Dictionary).has(key):
			return "Package media scan-only row is a record occurrence."
		var order := "%s%s%020d%s%s%s%s" % [entry, SEPARATOR, int(row.at), SEPARATOR, kind, SEPARATOR, name]
		if not previous.is_empty() and order <= previous:
			return "Package media scan-only rows are unsorted or duplicated."
		previous = order
		per_kind[kind] = int(per_kind[kind]) + 1
		scan_keys[name_key(kind, name)] = {"kind": kind, "name": name}
	if not ContractValues.has_exact_keys(cross_check, SCAN_KINDS):
		return "Package media scan cross-check has unexpected or missing kinds."
	for kind in SCAN_KINDS:
		var counts: Variant = cross_check[kind]
		if not counts is Dictionary or not ContractValues.has_exact_keys(counts, CROSS_CHECK_FIELDS):
			return "Package media scan cross-check counts are malformed."
		for field in CROSS_CHECK_FIELDS:
			if not ContractValues.nonnegative_json_integer(counts[field]):
				return "Package media scan cross-check counts are malformed."
		if kind in SCAN_ROW_KINDS and int(counts.scan_only) != int(per_kind[kind]):
			return "Package media scan cross-check disagrees with its scan-only rows."
		var record_count := int(expected.inline_count) if kind == "mes_script" else int(expected.occurrence_counts[kind])
		if int(counts.record_backed_strict) + int(counts.record_backed_bounded) > record_count:
			return "Package media scan cross-check counts more record-backed hits than the package has records."
	return ""


func _names_error(names: Variant, keys: Dictionary, header: Dictionary) -> String:
	if not names is Array:
		return "Package media identity must be an array."
	var seen := {}
	var previous := ""
	for untyped_entry in names:
		if not untyped_entry is Dictionary:
			return "Package media identity entry is malformed."
		var entry: Dictionary = untyped_entry
		var kind: Variant = entry.get("kind")
		var name: Variant = entry.get("name")
		if not kind is String or not kind in ClassifierScript.KINDS or not name is String or (name as String).is_empty() or name != ClassifierScript.normalize_name(name):
			return "Package media identity entry has an invalid kind or name."
		var key := name_key(kind, name)
		if not previous.is_empty() and key <= previous:
			return "Package media identity is unsorted or duplicated."
		previous = key
		if not keys.has(key):
			return "Package media identity names a name no occurrence uses."
		seen[key] = true
		var problem := _identity_error(entry, kind, name, header)
		if not problem.is_empty():
			return problem
	if seen.size() != keys.size():
		return "Package media identity is missing a referenced name."
	return ""


func _identity_error(entry: Dictionary, kind: String, name: String, header: Dictionary) -> String:
	var candidates := ClassifierScript.archives_for(kind, name)
	if candidates.is_empty() or not entry.has("shipped"):
		return "Package media identity entry has no archive to search or no state."
	var shipped: Variant = entry.shipped
	if shipped == null:
		if not ContractValues.has_exact_keys(entry, ["kind", "name", "shipped", "unavailable"]):
			return "Package media identity entry has unexpected fields."
		var unavailable: Variant = entry.unavailable
		if not unavailable is Array or (unavailable as Array).is_empty():
			return "Package media identity unavailable archives are malformed."
		var expected_unavailable: Array = []
		for archive in candidates:
			if not header.has(archive):
				expected_unavailable.append(archive)
		if not _same(unavailable, expected_unavailable):
			return "Package media identity unavailable archives differ from the archives of its kind."
		return ""
	if typeof(shipped) != TYPE_BOOL:
		return "Package media identity state is invalid."
	if not shipped:
		if not ContractValues.has_exact_keys(entry, ["kind", "name", "shipped", "searched"]):
			return "Package media identity entry has unexpected fields."
		if not _same(entry.searched, candidates):
			return "Package media identity searched archives differ from the archives of its kind."
		for archive in candidates:
			if not header.has(archive):
				return "Package media identity claims an absence without having searched every archive of its kind."
		return ""
	if not ContractValues.has_exact_keys(entry, ["kind", "name", "shipped", "rows"]):
		return "Package media identity entry has unexpected fields."
	var rows: Variant = entry.rows
	if not rows is Array or (rows as Array).is_empty():
		return "Package media identity of a shipped name has no rows."
	var previous_archive := ""
	var groups := {}
	for untyped_row in rows:
		if not untyped_row is Dictionary or not ContractValues.has_exact_keys(untyped_row, ["archive", "entry", "size", "entry_sha256"]):
			return "Package media identity row is malformed."
		var row: Dictionary = untyped_row
		var archive: Variant = row.archive
		if not archive is String or not archive in candidates or not header.has(archive):
			return "Package media identity row names an archive that is not one of its kind's searched archives."
		if not previous_archive.is_empty() and (archive as String) <= previous_archive:
			return "Package media identity rows are unsorted or duplicated."
		previous_archive = archive
		if not row.entry is String or ClassifierScript.normalize_name(row.entry) != name:
			return "Package media identity row names a different entry."
		if not ContractValues.nonnegative_json_integer(row.size) or not _is_sha256(row.entry_sha256):
			return "Package media identity row size or fingerprint is invalid."
		groups[ClassifierScript.group_of(kind, archive)] = true
	if groups.size() > 1:
		return "Package media identity row set spans archives that are not one declared bank set."
	return ""


func _script_error(block: Variant, expected: Dictionary) -> String:
	if not block is Dictionary:
		return "Package script references are not an object."
	var references: Dictionary = block
	if references.get("schema") != Version.PLAYBACK_SCRIPT_REFERENCES_SCHEMA:
		return "Package script references schema is not supported; it must be %s." % Version.PLAYBACK_SCRIPT_REFERENCES_SCHEMA
	if not ContractValues.has_exact_keys(references, ["schema", "targets", "counts"]):
		return "Package script references have unexpected or missing fields."
	if not _same(references.targets, expected.targets):
		return "Package script references do not match the package records or its members."
	if not _same(references.counts, expected.script_counts):
		return "Package script reference counts do not match its targets."
	return ""


## Whole-number-normalized, key-sorted JSON equality.
func _same(left: Variant, right: Variant) -> bool:
	return JSON.stringify(ContractValues.intify(left), "", true, true) == JSON.stringify(ContractValues.intify(right), "", true, true)


func _entry_key(entry: Variant) -> String:
	if not entry is Dictionary:
		return ""
	return name_key(str((entry as Dictionary).get("kind", "")), str((entry as Dictionary).get("name", "")))


func _scan_less(a: Dictionary, b: Dictionary) -> bool:
	if str(a.get("entry")) != str(b.get("entry")):
		return str(a.get("entry")) < str(b.get("entry"))
	if int(a.get("at", 0)) != int(b.get("at", 0)):
		return int(a.get("at", 0)) < int(b.get("at", 0))
	if str(a.get("kind")) != str(b.get("kind")):
		return str(a.get("kind")) < str(b.get("kind"))
	return str(a.get("name")) < str(b.get("name"))


func _is_sha256(value: Variant) -> bool:
	return value is String and ContractValues.is_sha256(value)
