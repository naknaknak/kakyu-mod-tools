class_name KakyuPlaybackMediaIdentity
extends RefCounted

## The producer's half of the package media inventory (WD-21 U1): which original
## archive ships each media name a package references, and how the analysis
## scan's resource references compare with the package's own records.
##
## This opens original archives, read-only, so it lives with the exporter and
## never in `content_core`: the package reader recomputes the occurrence set from
## the records and checks the shape of what this produces, but never opens an
## archive (`KakyuPlaybackPackageInventory`).
##
## Every searched archive's live SHA-256 is checked against the pinned table
## (`KakyuOriginalArchiveIdentity`) and a mismatch fails the build. An archive
## that is not in the source root is simply unavailable: a synthetic or workspace
## build can still export, and a name that only an unavailable archive could
## settle is recorded as `shipped: null` instead of being claimed absent.

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ClassifierScript := preload("res://content_core/playback_media_classifier.gd")
const IdentityScript := preload("res://content_core/original_archive_identity.gd")
const InventoryScript := preload("res://content_core/playback_package_inventory.gd")

## The pinned SHA-256 table the opened archives must match; a test substitutes
## the hashes of its synthetic archives.
var expected_archive_sha256: Dictionary = IdentityScript.ARCHIVE_SHA256


## Classifies every member's records, cross-checks them against the analysis
## scan, and looks every referenced name up in the original archives.
## `documents` and `texts` map each member entry to its document and its text
## document; `scan_by_entry` maps it to the scan's compact references
## `{at, kind, name, boundary}`. Returns `{ok, failures, media_identity,
## media_scan}`; the scan-only rows are in discovery order, and the manifest
## writer (`build_blocks`) sorts them.
func collect(source_root: String, documents: Dictionary, texts: Dictionary, scan_by_entry: Dictionary) -> Dictionary:
	var accumulator := begin(source_root)
	var entries: Array = documents.keys()
	entries.sort()
	for entry in entries:
		var document: Dictionary = documents[entry]
		var strings: Array = (texts.get(entry, {}) as Dictionary).get("strings", [])
		accumulator.add(entry, document, strings, scan_by_entry.get(entry, []))
	return accumulator.finish()


## The per-entry form of `collect` (TD-64 part 2): `add` takes one member's
## document, strings and scan references and keeps only the identity keys and the
## cross-check rows, so a producer that streams its members holds no document.
## `finish` opens the archives once and returns what `collect` returns. The feed
## order never changes the result: the scan-only rows and the failures are kept
## per entry and joined in entry order, the order `collect` has always found them
## in.
func begin(source_root: String) -> Accumulator:
	return Accumulator.new(self, source_root)


class Accumulator:
	extends RefCounted

	var _owner: KakyuPlaybackMediaIdentity
	var _source_root := ""
	var _classifier := ClassifierScript.new()
	var _scan := InventoryScript.empty_scan()
	var _keys := {}
	var _scan_only_by_entry := {}
	var _failures_by_entry := {}


	func _init(owner: KakyuPlaybackMediaIdentity, source_root: String) -> void:
		_owner = owner
		_source_root = source_root


	func add(entry: Variant, document: Dictionary, strings: Array, scan_references: Array) -> void:
		var rows := _classifier.occurrences(document, strings)
		for row in rows:
			if not str(row.name).is_empty():
				_keys[InventoryScript.name_key(row.kind, row.name)] = {"kind": row.kind, "name": row.name}
		var entry_scan := {"scan_only": [], "cross_check": _scan.cross_check}
		var entry_failures: Array[String] = []
		_owner._cross_check(str(entry), rows, _classifier.script_references(document), scan_references, entry_scan, entry_failures)
		if not (entry_scan.scan_only as Array).is_empty():
			_scan_only_by_entry[entry] = entry_scan.scan_only
		if not entry_failures.is_empty():
			_failures_by_entry[entry] = entry_failures


	func finish() -> Dictionary:
		var failures: Array[String] = []
		var failed: Array = _failures_by_entry.keys()
		failed.sort()
		for entry in failed:
			failures.append_array(_failures_by_entry[entry])
		if not failures.is_empty():
			return {"ok": false, "failures": failures}
		var scan_entries: Array = _scan_only_by_entry.keys()
		scan_entries.sort()
		for entry in scan_entries:
			for untyped_row in _scan_only_by_entry[entry]:
				var row: Dictionary = untyped_row
				_scan.scan_only.append(row)
				_keys[InventoryScript.name_key(row.kind, row.name)] = {"kind": row.kind, "name": row.name}
		var identity := InventoryScript.empty_identity()
		if not _keys.is_empty():
			var opened := _owner._open_archives(_source_root)
			if not (opened.failures as Array).is_empty():
				return {"ok": false, "failures": opened.failures}
			var looked_up := _owner._lookup(_keys, opened.readers, opened.archives)
			for reader in (opened.readers as Dictionary).values():
				(reader as KakyuArcReader).close()
			if not (looked_up.failures as Array).is_empty():
				return {"ok": false, "failures": looked_up.failures}
			identity = {"archives": opened.archives, "names": looked_up.names}
		return {"ok": true, "failures": failures, "media_identity": identity, "media_scan": _scan}


## One `kind name (archives)` text per identity row that is undecided
## (`shipped: null`) because an archive of its kind was not in the source root.
## The original full-export CLI fails on any of them; a synthetic or workspace
## build tolerates them.
static func unavailable_rows(identity: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	for untyped_entry in identity.get("names", []):
		var entry: Dictionary = untyped_entry
		if entry.get("shipped", false) == null:
			rows.append("%s %s (%s)" % [str(entry.kind), str(entry.name), ", ".join(PackedStringArray(entry.unavailable))])
	return rows


## The per-kind counts the export prints: how many occurrences are record-backed
## (the package's own records), how many scan hits are `scan_only` (in no record),
## and the identity states of the kind's names. `media_inventory` is the
## manifest's block. Then each scan kind's cross-check counts.
static func summary_lines(media_inventory: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var states := {}
	for kind in ClassifierScript.KINDS:
		states[kind] = {"shipped": 0, "absent": 0, "unavailable": 0}
	for untyped_entry in media_inventory.names:
		var entry: Dictionary = untyped_entry
		var shipped: Variant = entry.shipped
		var state := "unavailable" if shipped == null else ("shipped" if shipped == true else "absent")
		states[entry.kind][state] = int(states[entry.kind][state]) + 1
	var scan_only := {}
	for untyped_row in media_inventory.scan_only:
		var row: Dictionary = untyped_row
		scan_only[row.kind] = int(scan_only.get(row.kind, 0)) + 1
	var counts: Dictionary = media_inventory.counts
	for kind in ClassifierScript.KINDS:
		lines.append("media kind=%s record_backed=%d scan_only=%d names=%d shipped=%d absent=%d unavailable=%d" % [
			kind, int(counts.occurrences[kind]), int(scan_only.get(kind, 0)), int(counts.names[kind]),
			int(states[kind].shipped), int(states[kind].absent), int(states[kind].unavailable),
		])
	for kind in InventoryScript.SCAN_KINDS:
		var cross: Dictionary = media_inventory.cross_check[kind]
		lines.append("media_scan kind=%s record_backed_strict=%d record_backed_bounded=%d scan_only=%d" % [
			kind, int(cross.record_backed_strict), int(cross.record_backed_bounded), int(cross.scan_only),
		])
	return lines


## The identity table needs every name once, in kind then name order.
func _lookup(keys: Dictionary, readers: Dictionary, archives: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	var key_names: Array = keys.keys()
	key_names.sort()
	var fingerprints := {}
	var names: Array[Dictionary] = []
	for key in key_names:
		var kind: String = keys[key].kind
		var name: String = keys[key].name
		var candidates := ClassifierScript.archives_for(kind, name)
		var rows: Array[Dictionary] = []
		var unavailable: Array = []
		var groups := {}
		for archive in candidates:
			if not readers.has(archive):
				unavailable.append(archive)
				continue
			var reader: KakyuArcReader = readers[archive]
			var found := reader.get_entry(name)
			if found.is_empty():
				continue
			var cache_key := "%s|%s" % [archive, str(found.name).to_upper()]
			if not fingerprints.has(cache_key):
				fingerprints[cache_key] = reader.get_entry_fingerprint(str(found.name))
			var sha: String = fingerprints[cache_key]
			if sha.is_empty():
				failures.append("%s: %s could not be fingerprinted in %s." % [kind, name, archive])
				continue
			rows.append({"archive": archive, "entry": str(found.name), "size": int(found.size), "entry_sha256": sha})
			groups[ClassifierScript.group_of(kind, archive)] = true
		rows.sort_custom(func(a, b): return a.archive < b.archive)
		if groups.size() > 1:
			var held: Array[String] = []
			for row in rows:
				held.append(str(row.archive))
			failures.append("%s %s is in archives that are not one declared bank set: %s." % [kind, name, ", ".join(PackedStringArray(held))])
			continue
		if not rows.is_empty():
			names.append({"kind": kind, "name": name, "shipped": true, "rows": rows})
			continue
		if not unavailable.is_empty():
			names.append({"kind": kind, "name": name, "shipped": null, "unavailable": unavailable})
			continue
		# Every archive of the kind was searched. A name that another media
		# archive holds is not a known absence but a rule that is wrong, so it
		# stops the build instead of being recorded.
		var elsewhere := ""
		for other in IdentityScript.MEDIA_ARCHIVES:
			if other in candidates or not readers.has(other):
				continue
			if not (readers[other] as KakyuArcReader).get_entry(name).is_empty():
				elsewhere = str(other)
				break
		if not elsewhere.is_empty():
			failures.append("%s %s is absent from %s but present in %s." % [kind, name, ", ".join(PackedStringArray(candidates)), elsewhere])
			continue
		names.append({"kind": kind, "name": name, "shipped": false, "searched": candidates})
	return {"names": names, "failures": failures}


## Opens every media archive the source root holds, after checking its pinned
## SHA-256. Returns `{readers, archives (archive -> sha256), failures}`.
func _open_archives(source_root: String) -> Dictionary:
	var readers := {}
	var archives := {}
	var failures: Array[String] = []
	for archive in IdentityScript.MEDIA_ARCHIVES:
		var path := source_root.path_join(archive)
		if not FileAccess.file_exists(path):
			continue
		var checked := IdentityScript.verify_file(path, archive, expected_archive_sha256)
		if not checked.ok:
			failures.append(str(checked.error))
			continue
		var reader := ArcReaderScript.new()
		if not reader.open(path):
			failures.append(str(reader.last_error))
			continue
		readers[archive] = reader
		archives[archive] = checked.sha256
	if not failures.is_empty():
		for reader in readers.values():
			(reader as KakyuArcReader).close()
		readers = {}
	return {"readers": readers, "archives": archives, "failures": failures}


## Compares one member's scan references with its record occurrences. A hit that
## is a record is counted (strict or bounded, by the scan's own label); a hit
## that is in no record is `scan_only` when the scan only bounded it, and an
## error when the scan placed it on an instruction start: that is a record the
## package should have kept.
func _cross_check(entry: String, rows: Array[Dictionary], references: Array[Dictionary], scan_references: Array, scan: Dictionary, failures: Array[String]) -> void:
	var record_index := {}
	for row in rows:
		if row.kind in InventoryScript.SCAN_ROW_KINDS:
			record_index["%s|%d" % [row.kind, row.at]] = row.name
	for reference in references:
		if reference.via == "inline_script_execution":
			record_index["mes_script|%d" % reference.at] = reference.name
	for untyped_hit in scan_references:
		var hit: Dictionary = untyped_hit
		var kind := str(hit.kind)
		if not scan.cross_check.has(kind):
			continue
		var counts: Dictionary = scan.cross_check[kind]
		var at := int(hit.at)
		var strict := str(hit.boundary) == "strict_indexed"
		if record_index.get("%s|%d" % [kind, at], null) == str(hit.name):
			var field := "record_backed_strict" if strict else "record_backed_bounded"
			counts[field] = int(counts[field]) + 1
		elif strict:
			failures.append("%s: strict_indexed %s reference at %d is not a record occurrence." % [entry, kind, at])
		else:
			counts["scan_only"] = int(counts["scan_only"]) + 1
			if kind in InventoryScript.SCAN_ROW_KINDS:
				scan.scan_only.append({
					"entry": entry, "at": at, "kind": kind, "name": str(hit.name),
					"boundary": InventoryScript.SCAN_ONLY_BOUNDARY,
				})
