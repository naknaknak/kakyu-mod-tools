extends RefCounted

## Gate 3 of the media gates (WD-21 U2 C5, decision D9; extended for library media by EP-14,
## Core 0.378.0): the instrument against the declaration.
##
## A catalog row's `resources` list the media its measured route reaches (the v7
## `presentation.resources` of its event definition, promoted by
## `tools/promote_analysis_groups.py`). The group-routes Playback pass plays the
## row's default preset and builds the shared presentation timeline; this file holds the
## pure compares of that timeline against the row's declaration:
##
## - gate 1 (`known_absent_media.gd`, `compare_export`): the package's absent set is
##   the register;
## - gate 2 (`known_absent_media.gd`, `classify_playback_miss`): a medium the
##   timeline names but the archives lack is a registered absence;
## - gate 3 (this file, `compare`): a medium the timeline names is a medium the row
##   declares;
## - gate 3, library coordinates (this file, `compare_library`): a medium a shared
##   `LIBLARY.LIB` routine presented is declared at the exact coordinate the library
##   executed it at.
##
## `compare` is name-level: the names are upper-cased (`ClassifierScript.normalize_name`,
## the way the archives are searched and the package inventory is keyed) and compared as a
## set. Since Core 0.378.0 the timeline presents the media a shared library routine
## executes (routine 27's pictures and routine 9's sound effects, EP-14), so `compare`
## covers them by name too and proves the declared list covers the default playback; the
## converse (everything declared was reached by some measured run) holds by construction of
## the list.
##
## A name-level match cannot see a wrong `(entry, offset)`, the labelling TD-55 repaired. So
## `compare_library` checks each played medium that carries a `library_call` (a timeline
## entry built from a `library_media` row) at its own coordinate: the catalog item
## `(request_entry, request_offset, entry)` must equal the medium's `(source entry, source
## offset, name)`, both names through the one `ClassifierScript.normalize_name`. The entry
## is read from the timeline entry's own `source_entry` (pictures, animations and effects all
## carry it); a medium whose entry has none has no entry here either and so matches no item:
## the compare fails closed and reports it undeclared, never assumes a member.
##
## `library_coverage` is the non-failing report beside it: how many of the row's
## `LIBLARY.LIB` items the Playback pass presented. It never fails, because a row's
## declaration is the union over every measured variant while the Playback pass plays one
## preset per row; the loader and dispatch strings (the `unclassified` kinds) have no
## presented form and are never counted as presented.
##
## All of it reads no archive and writes nothing, lives here and not in `content_core`, and
## reads only what the Playback pass has already loaded: the catalog row and the played
## steps.

const ClassifierScript := preload("res://content_core/playback_media_classifier.gd")

## The Playback pass's categories (the ones gate 2 reads), in the order a step lists
## them, with the step field each is read from. `ANIMATION_SOURCE` covers both
## resource kinds (`mmo` atlases and `ax` files); `EFFECT` is the sound-effect
## request.
const CATEGORIES := ["PICTURE", "ANIMATION_SOURCE", "VOICE", "BGM", "EFFECT"]

## The member whose routines the library compare and the coverage report read.
const LIBRARY_ENTRY := "LIBLARY.LIB"


## The declared names of a row: `{NORMALIZED_NAME: true}` over each item's `entry`
## (the catalog item's `entry` is the medium's name). A malformed item or an empty
## name declares nothing.
static func declared_names(resources: Array) -> Dictionary:
	var declared := {}
	for item_value in resources:
		if not item_value is Dictionary:
			continue
		var name := str((item_value as Dictionary).get("entry", ""))
		if not name.is_empty():
			declared[ClassifierScript.normalize_name(name)] = true
	return declared


## Every medium name the played `steps` use, in timeline order, as `{category, step,
## resource_name (as played), name (normalized)}`. A step's `voice` is one string;
## its `pictures`, `animations`, `bgm` and `effects` are lists of `{resource_name,
## ...}`. An empty name is not a medium name and is not listed.
##
## A medium whose step entry carries `source_entry`, `source_offset` or `library_call`
## (pictures, animations and effects; EP-14) also gets `entry` (the entry's own
## `source_entry`, `""` when it has none), `at` (the source offset) and, for a medium a
## shared library routine presented, `library_call` (`{routine, caller_entry,
## caller_offset, caller_definition_id}`).
static func played_media(steps: Array) -> Array[Dictionary]:
	var played: Array[Dictionary] = []
	for step_value in steps:
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		var index := int(step.get("index", -1))
		for picture in step.get("pictures", []):
			_add(played, "PICTURE", index, str((picture as Dictionary).get("resource_name", "")), picture)
		for animation in step.get("animations", []):
			_add(played, "ANIMATION_SOURCE", index, str((animation as Dictionary).get("resource_name", "")), animation)
		_add(played, "VOICE", index, str(step.get("voice", "")))
		for bgm in step.get("bgm", []):
			_add(played, "BGM", index, str((bgm as Dictionary).get("resource_name", "")))
		for effect in step.get("effects", []):
			_add(played, "EFFECT", index, str((effect as Dictionary).get("resource_name", "")), effect)
	return played


## The played media a shared library routine presented (those with a `library_call`), in
## timeline order: what the library compare and the coverage report read.
static func played_library_media(steps: Array) -> Array[Dictionary]:
	var library: Array[Dictionary] = []
	for medium in played_media(steps):
		if medium.has("library_call"):
			library.append(medium)
	return library


## The gate. `resources` is the catalog row's `resources`, `steps` the played
## timeline's steps. Returns `{compared, undeclared}`: how many played names were
## compared and the played names no resource declares, each `{category, step,
## resource_name, name}` in timeline order.
static func compare(resources: Array, steps: Array) -> Dictionary:
	var declared := declared_names(resources)
	var played := played_media(steps)
	var undeclared: Array[Dictionary] = []
	for medium in played:
		if not declared.has(medium.name):
			undeclared.append(medium)
	return {"compared": played.size(), "undeclared": undeclared}


## The library-coordinate gate (EP-14). Each played medium that carries a `library_call` must
## match a declared item at `(request_entry, request_offset, normalize(entry)) == (source
## entry, source offset, name)`. Returns `{compared, undeclared}` like `compare`: how many
## library media were compared and those no item declares at their coordinate, each the
## played medium (`category, step, resource_name, name, entry, at, library_call`) in timeline
## order. Route-own media (no `library_call`) are not in this compare.
static func compare_library(resources: Array, steps: Array) -> Dictionary:
	var keys := _item_keys(resources)
	var library := played_library_media(steps)
	var undeclared: Array[Dictionary] = []
	for medium in library:
		if not keys.has(_library_key(str(medium.entry), int(medium.at), str(medium.name))):
			undeclared.append(medium)
	return {"compared": library.size(), "undeclared": undeclared}


## The coverage report (EP-14), never a failure: `{declared, presented, presented_by_category}`
## for one row. `declared` counts the items whose `request_entry` is `LIBLARY.LIB`;
## `presented` those of them some played library medium matches at its coordinate (each item
## once); `presented_by_category` splits `presented` by the category of the first medium that
## matched. The `unclassified` loader and dispatch items sit at offsets no played medium has,
## so they are declared and never presented.
static func library_coverage(resources: Array, steps: Array) -> Dictionary:
	var keys := _item_keys(resources)
	var declared := 0
	for item_value in resources:
		if item_value is Dictionary and str((item_value as Dictionary).get("request_entry", "")) == LIBRARY_ENTRY:
			declared += 1
	var counted := {}
	var by_category := {}
	for medium in played_library_media(steps):
		var key := _library_key(str(medium.entry), int(medium.at), str(medium.name))
		if not keys.has(key):
			continue
		for item_index in keys[key]:
			var item: Dictionary = resources[item_index]
			if str(item.get("request_entry", "")) != LIBRARY_ENTRY or counted.has(item_index):
				continue
			counted[item_index] = true
			by_category[medium.category] = int(by_category.get(medium.category, 0)) + 1
	return {"declared": declared, "presented": counted.size(), "presented_by_category": by_category}


## One comparable key for a library coordinate: the entry, the record offset and the
## normalized medium name.
static func _library_key(entry: String, offset: int, name: String) -> String:
	return "%s|%d|%s" % [entry, offset, ClassifierScript.normalize_name(name)]


## `{coordinate key: [item index, ...]}` over a row's well-formed items (a Dictionary with a
## non-empty `entry`), keyed by `(request_entry, request_offset, entry)`.
static func _item_keys(resources: Array) -> Dictionary:
	var keys := {}
	for index in range(resources.size()):
		if not resources[index] is Dictionary:
			continue
		var item: Dictionary = resources[index]
		var name := str(item.get("entry", ""))
		if name.is_empty():
			continue
		var key := _library_key(str(item.get("request_entry", "")), int(item.get("request_offset", -1)), name)
		if not keys.has(key):
			keys[key] = []
		(keys[key] as Array).append(index)
	return keys


static func _add(played: Array[Dictionary], category: String, step: int, resource_name: String, step_entry = null) -> void:
	if resource_name.is_empty():
		return
	var medium := {
		"category": category, "step": step, "resource_name": resource_name,
		"name": ClassifierScript.normalize_name(resource_name),
	}
	if step_entry is Dictionary:
		var entry: Dictionary = step_entry
		if entry.has("source_entry") or entry.has("source_offset") or entry.has("library_call"):
			medium["entry"] = str(entry.get("source_entry", ""))
			medium["at"] = int(entry.get("source_offset", -1))
		if entry.has("library_call"):
			medium["library_call"] = (entry.library_call as Dictionary).duplicate(true)
	played.append(medium)
