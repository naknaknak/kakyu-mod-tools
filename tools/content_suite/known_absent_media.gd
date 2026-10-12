extends RefCounted

## The two batch gates over the known-absent media register (WD-21 U1 C3, D7/D8).
##
## `config/event_catalog/known_absent_media_v1.json` (`kakyu_known_absent_media/v1`,
## written by `tools/build_known_absent_media.py`) lists every `(kind, normalized
## name)` the full original package's `media_inventory` records as absent from
## every original archive of its kind. This file is the register's reader and the
## two pure compares against it:
##
## - gate 1, `compare_export`: the export CLI's check that the package's static
##   absent set is the register (exactly, for the default full build; "no
##   unregistered absence" for any other build) and that the package's archive
##   header is the register's;
## - gate 2, `classify_playback_miss`: the group-routes Playback pass's check that
##   a presentation resource the shared timeline names but the archives lack is a
##   registered absence.
##
## The gates are a **tool decision over an original-data fact**: the register says
## what the original archives ship, not what the original engine does about a
## missing file. Both compares are name-level and pure (they open no archive and
## write nothing), so they live here and not in `content_core`: Core's version, and
## with it the package hash, does not move with them. The register is read through
## the one `res://` literal below so the TD-32 input closure of every check that
## uses a gate lists the register.

const ClassifierScript := preload("res://content_core/playback_media_classifier.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const InventoryScript := preload("res://content_core/playback_package_inventory.gd")

const REGISTER_PATH := "res://config/event_catalog/known_absent_media_v1.json"
const SCHEMA := "kakyu_known_absent_media/v1"
## The `media_inventory` block schema the register was derived from and the only
## one a gate compares against; a classifier change is a new id and a new register.
const INVENTORY_SCHEMA := "kakyu_media_inventory/v1"
const NORMALIZATION := "upper_case"
const REGISTER_KEYS := ["schema", "inventory_schema", "normalization", "archives", "rows", "evidence_boundary", "payload_sha256"]
const ROW_KEYS := ["kind", "name", "searched"]

## The group-routes Playback pass's categories, the resource kind each one's
## names are classified as in the package inventory.
const PLAYBACK_KINDS := {
	"PICTURE": "mmo",
	"VOICE": "voice",
	"BGM": "bgm",
	"EFFECT": "se",
}


## Reads and checks the register at `path`. Returns `{ok, error, register}`, where
## `register` is `{archives (name -> SHA-256), rows (key -> sorted searched
## archives), row_count}`. A missing file, malformed JSON, another schema, a wrong
## fingerprint or any malformed row is not ok: a gate never runs against a register
## it cannot trust.
static func load_register(path: String = REGISTER_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _refused("the known-absent register %s does not exist" % path)
	# `JSON.new().parse()` reports a syntax error as a code; `parse_string` would also
	# print an engine error line into a log that is otherwise a clean pass.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return _refused("the known-absent register %s is not valid JSON" % path)
	return parse_register(json.data)


## The pure half of `load_register`: validates an already parsed document.
static func parse_register(document: Variant) -> Dictionary:
	if not document is Dictionary:
		return _refused("the known-absent register is not a JSON object")
	var register: Dictionary = document
	if not ContractValues.has_exact_keys(register, REGISTER_KEYS):
		return _refused("the known-absent register does not have exactly the keys %s" % ", ".join(PackedStringArray(REGISTER_KEYS)))
	if register.schema != SCHEMA:
		return _refused("the known-absent register schema %s is not %s" % [str(register.schema), SCHEMA])
	if register.inventory_schema != INVENTORY_SCHEMA:
		return _refused("the known-absent register was derived from %s, not %s" % [str(register.inventory_schema), INVENTORY_SCHEMA])
	if register.normalization != NORMALIZATION:
		return _refused("the known-absent register normalization %s is not %s" % [str(register.normalization), NORMALIZATION])
	if not register.evidence_boundary is String or (register.evidence_boundary as String).is_empty():
		return _refused("the known-absent register has no evidence_boundary text")
	var declared: Variant = register.payload_sha256
	if not declared is String or not ContractValues.is_sha256(declared) or FingerprintScript.new().fingerprint(register) != declared:
		return _refused("the known-absent register's payload_sha256 does not match its content")
	var archives := {}
	if not register.archives is Dictionary or (register.archives as Dictionary).is_empty():
		return _refused("the known-absent register has no archives header")
	for archive in (register.archives as Dictionary):
		var archive_sha: Variant = (register.archives as Dictionary)[archive]
		if not archive is String or (archive as String).is_empty() or not archive_sha is String or not ContractValues.is_sha256(archive_sha):
			return _refused("the known-absent register's header for %s is not a SHA-256" % str(archive))
		archives[archive] = archive_sha
	if not register.rows is Array:
		return _refused("the known-absent register rows are not an array")
	var rows := {}
	for untyped_row in (register.rows as Array):
		if not untyped_row is Dictionary or not ContractValues.has_exact_keys(untyped_row, ROW_KEYS):
			return _refused("a known-absent register row does not have exactly the keys kind, name, searched")
		var row: Dictionary = untyped_row
		if not row.kind is String or not row.kind in ClassifierScript.KINDS:
			return _refused("a known-absent register row has the unknown kind %s" % str(row.kind))
		if not row.name is String or (row.name as String).is_empty() or ClassifierScript.normalize_name(row.name) != row.name:
			return _refused("a known-absent register row name %s is not a non-empty normalized name" % str(row.name))
		var searched := _searched_archives(row.searched, archives)
		if searched.is_empty():
			return _refused("known-absent register row %s %s has no valid, header-covered searched archives" % [row.kind, row.name])
		var key := InventoryScript.name_key(row.kind, row.name)
		if rows.has(key):
			return _refused("known-absent register row %s %s appears twice" % [row.kind, row.name])
		rows[key] = searched
	return {"ok": true, "error": "", "register": {"archives": archives, "rows": rows, "row_count": rows.size()}}


## The static absent set of a package: the `shipped: false` rows of its
## `media_inventory` block, keyed `(kind, normalized name)`. Returns `{ok, error,
## rows, archives}`; an undecided (`shipped: null`) row, another block schema or a
## malformed row is not ok.
static func absent_rows(media_inventory: Variant) -> Dictionary:
	if not media_inventory is Dictionary:
		return _refused("the package has no media_inventory block")
	var inventory: Dictionary = media_inventory
	if inventory.get("schema") != INVENTORY_SCHEMA:
		return _refused("the package media_inventory schema %s is not %s" % [str(inventory.get("schema")), INVENTORY_SCHEMA])
	var archives_value: Variant = inventory.get("archives")
	if not archives_value is Dictionary:
		return _refused("the package media_inventory has no archives header")
	var names: Variant = inventory.get("names")
	if not names is Array:
		return _refused("the package media_inventory names are not an array")
	var rows := {}
	for untyped_row in (names as Array):
		if not untyped_row is Dictionary:
			return _refused("a package media_inventory name row is not an object")
		var row: Dictionary = untyped_row
		var shipped: Variant = row.get("shipped", "missing")
		if shipped == null:
			return _refused("the package row %s %s is undecided (shipped: null)" % [str(row.get("kind")), str(row.get("name"))])
		if shipped is bool and shipped:
			continue
		if not shipped is bool:
			return _refused("the package row %s %s has a shipped state that is not true, false or null" % [str(row.get("kind")), str(row.get("name"))])
		if not row.get("kind") is String or not row.get("name") is String or not row.get("kind") in ClassifierScript.KINDS or (row.name as String).is_empty():
			return _refused("an absent package row has a malformed kind or name")
		var searched := _searched_archives(row.get("searched"), archives_value)
		if searched.is_empty():
			return _refused("the absent package row %s %s has no valid, header-covered searched archives" % [str(row.kind), str(row.name)])
		var name := ClassifierScript.normalize_name(row.name)
		var key := InventoryScript.name_key(row.kind, name)
		if rows.has(key):
			return _refused("the package has two absent rows for %s %s" % [str(row.kind), name])
		rows[key] = searched
	return {"ok": true, "error": "", "rows": rows, "archives": archives_value}


## Gate 1. Compares a package's `media_inventory` block with the register.
##
## `exact` is the **default full build**: the export CLI with no `--event`, the
## analysis groups on, no `--include-unbound-groups` and no workspace binding. Its
## static absent set must equal the register's rows - a new absence is
## `unregistered`, a register row the package no longer shows absent is `stale`.
## Any other build (`--event`, `--no-analysis-groups`, `--include-unbound-groups`)
## holds a subset or a superset of the default build's names, so with `exact` false
## only "no unregistered absence" is checked and a register row the build does not
## show is not an error.
##
## In every mode the package's `archives` header (the SHA-256 of every media
## archive the producer opened) must equal the register's, the block schema must be
## the register's, and a registered name must have been searched in the same
## archives. Returns `{ok, failures, unregistered, stale, changed, header,
## absent, registered}`; every list is sorted and `failures` is the printable form.
static func compare_export(register: Dictionary, media_inventory: Variant, exact: bool) -> Dictionary:
	var result := {
		"ok": false, "failures": [], "unregistered": [], "stale": [], "changed": [], "header": [],
		"absent": 0, "registered": int(register.get("row_count", 0)),
	}
	var absent := absent_rows(media_inventory)
	if not absent.ok:
		(result.failures as Array).append(str(absent.error))
		return result
	var rows: Dictionary = absent.rows
	result.absent = rows.size()
	for archive in _union_keys(register.archives, absent.archives):
		var package_sha: Variant = (absent.archives as Dictionary).get(archive)
		var register_sha: Variant = (register.archives as Dictionary).get(archive)
		if package_sha != register_sha:
			(result.header as Array).append("%s: package %s, register %s" % [archive, _short(package_sha), _short(register_sha)])
	for key in rows:
		if not (register.rows as Dictionary).has(key):
			(result.unregistered as Array).append(_describe(key, rows[key]))
		elif rows[key] != (register.rows as Dictionary)[key]:
			(result.changed as Array).append("%s searched %s, register %s" % [_describe(key, []), ",".join(PackedStringArray(rows[key])), ",".join(PackedStringArray((register.rows as Dictionary)[key]))])
	if exact:
		for key in register.rows:
			if not rows.has(key):
				(result.stale as Array).append(_describe(key, (register.rows as Dictionary)[key]))
	for list_name in ["header", "unregistered", "stale", "changed"]:
		(result[list_name] as Array).sort()
	var failures: Array = result.failures
	for line in result.header:
		failures.append("archive header differs from the register: %s" % line)
	for line in result.unregistered:
		failures.append("unregistered absence: %s" % line)
	for line in result.stale:
		failures.append("stale register row (no longer absent in the default full build): %s" % line)
	for line in result.changed:
		failures.append("absence searched differently from the register: %s" % line)
	result.ok = failures.is_empty()
	return result


## The register kind a Playback-pass category's name is looked up as: PICTURE ->
## `mmo`, ANIMATION_SOURCE -> its own resource kind (`mmo` or `ax`; by extension
## when the row carries neither), VOICE -> `voice`, BGM -> `bgm`, EFFECT -> `se`.
## Empty for an unknown category.
static func playback_kind(category: String, resource_kind: String, name: String) -> String:
	if category == "ANIMATION_SOURCE":
		if resource_kind == "mmo" or resource_kind == "ax":
			return resource_kind
		return "ax" if name.get_extension().to_lower() == "ax" else "mmo"
	return str(PLAYBACK_KINDS.get(category, ""))


## Gate 2, one miss. `register` is a `load_register` result's register. Returns
## `{kind, name (normalized), registered}`: a miss is registered when the register
## holds `(kind, normalized name)`. An unknown category is never registered.
static func classify_playback_miss(register: Dictionary, category: String, resource_kind: String, name: String) -> Dictionary:
	var kind := playback_kind(category, resource_kind, name)
	var normalized := ClassifierScript.normalize_name(name)
	var registered := false
	if not kind.is_empty() and register.has("rows"):
		registered = (register.rows as Dictionary).has(InventoryScript.name_key(kind, normalized))
	return {"kind": kind, "name": normalized, "registered": registered}


## `searched` as a sorted array of unique, non-empty archive names the header
## covers, or an empty array when it is none of that.
static func _searched_archives(searched: Variant, archives: Variant) -> Array:
	if not searched is Array or (searched as Array).is_empty() or not archives is Dictionary:
		return []
	var result: Array = []
	for archive in (searched as Array):
		if not archive is String or (archive as String).is_empty() or not (archives as Dictionary).has(archive) or archive in result:
			return []
		result.append(archive)
	result.sort()
	return result


static func _refused(error: String) -> Dictionary:
	return {"ok": false, "error": error}


static func _describe(key: String, searched: Array) -> String:
	var parts := key.split(InventoryScript.SEPARATOR)
	var text := "%s %s" % [parts[0], parts[1]]
	if not searched.is_empty():
		text += " (searched %s)" % ",".join(PackedStringArray(searched))
	return text


static func _union_keys(first: Variant, second: Variant) -> Array:
	var keys := {}
	for key in (first as Dictionary):
		keys[key] = true
	for key in (second as Dictionary):
		keys[key] = true
	var result := keys.keys()
	result.sort()
	return result


static func _short(sha: Variant) -> String:
	return "absent" if sha == null else str(sha).substr(0, 12)
