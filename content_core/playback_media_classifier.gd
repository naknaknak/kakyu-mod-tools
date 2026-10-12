class_name KakyuPlaybackMediaClassifier
extends RefCounted

## Classifies the records of one playback-package member into media and script
## dependencies (WD-21 U1). The package producer and the package reader both use
## this one class, so the manifest's `media_inventory` and `script_references`
## blocks can be recomputed from the package's own records and compared.
##
## Evidence basis: only the projected records and the member's text strings. No
## archive is opened here and no bytecode is read.
##
## Kinds, each with its rule, evidence and status:
##
## - `mmo`, `ax`, `voice`: the records `mmo_resource_marker`, `ax_resource_marker`
##   and `voice_marker`, with the name in their first `resource_name` operand.
##   Confirmed marker envelopes (MES analysis documents).
## - `se`: an `effect_request` record whose operand names `resource_kind effect`,
##   `resource_archive se.arc` and a `name`.
## - `a6`: a `system_call` of function 8 whose record list is exactly
##   `[literal 0, string "<name>.a6", banked_i32[bank 0][index 3]]`. The shape is
##   the observed `album.a6` load; it is a tool decision that this shape (and no
##   other string) is called an A6 reference.
## - `bgm`: an `argument_slot_write_run` writing one literal to argument slot 1
##   (`u16_index` operand 1, one expression pair, continuation 0), then a
##   `script_transfer` to literal routine 23, with `end == next.at` on the
##   records sorted by `at`, both offsets inside one row of the document's
##   `regions` (a library routine is its own region). The selector names its
##   entry through `KakyuMesBgmCatalog`. The same adjacency rule as
##   `KakyuMesAudioReferenceIndex`, applied to the package's records. A selector
##   that is not a literal, or that the catalog does not map, is listed as
##   `unclassified` with evidence and no name. The catalog is part of the rule:
##   a change to its table or to this rule is a new inventory schema id.
## - `unclassified`: the other loader strings, looked up by extension without a
##   claim of what they are: a `system_call` whose function and string extension
##   are in `LOADER_EXTENSIONS` (a function-8 string that is `.a6` but not the A6
##   shape is one of these), and the first string of a `native_record_dispatch`
##   (command 0x12) record list whose extension is in `EXTENSION_ARCHIVES` (the
##   observed shapes carry `.dat`, `.pal` and `.mmo` names; the native meaning of
##   the dispatch stays unresolved, the inventory needs only the string). Tool
##   decision: they are inventoried and gated like the other kinds, because the
##   goal is that every absence is known. The two tables are tool decisions over
##   measured observations; a change of either is a new inventory schema id.
##
## One normalization is shared by everything that compares names: `to_upper()` of
## the name, the way `KakyuArcReader` matches entries.

const BgmCatalogScript := preload("res://content_core/mes_bgm_catalog.gd")

const KINDS := ["mmo", "ax", "voice", "se", "a6", "bgm", "unclassified"]

const MARKER_KINDS := {
	"mmo_resource_marker": "mmo",
	"ax_resource_marker": "ax",
	"voice_marker": "voice",
}

## The archives a kind's names are looked up in. `unclassified` takes its
## archives from `EXTENSION_ARCHIVES`.
const KIND_ARCHIVES := {
	"mmo": ["mmo.arc"],
	"ax": ["data.arc"],
	"voice": ["voice.arc", "tina1.arc", "tina2.arc"],
	"se": ["se.arc"],
	"a6": ["data.arc"],
	"bgm": ["bgm.arc"],
}

## The plausible archives of an `unclassified` loader string, by extension. The
## data bank holds the `.a6/.ccd/.dat/.eve/.mpc/.pal` families (measured);
## `.gp8` has no member in any archive and is searched in the data bank; both
## sound banks hold `.wav` entries.
const EXTENSION_ARCHIVES := {
	".a6": ["data.arc"],
	".ccd": ["data.arc"],
	".dat": ["data.arc"],
	".eve": ["data.arc"],
	".gp8": ["data.arc"],
	".mmo": ["mmo.arc"],
	".mpc": ["data.arc"],
	".pal": ["data.arc"],
	".wav": ["bgm.arc", "se.arc"],
}

## `system_call` function -> the extensions that make its string a loader
## string, as measured in the packaged records: function 8 loads `.a6`, `.ccd`,
## `.eve` and `.mpc` (an `.a6` of the exact A6 shape is kind `a6`), 9 `.gp8`, 24
## `.mmo` and 5 `.wav`. The `.dat` and `.pal` names arrive through
## `native_record_dispatch` instead.
const LOADER_EXTENSIONS := {
	5: [".wav"],
	8: [".a6", ".ccd", ".eve", ".mpc"],
	9: [".gp8"],
	24: [".mmo"],
}

## The evidence label of an `unclassified` row found in a `native_record_dispatch`.
const DISPATCH_EVIDENCE := "native_record_dispatch_string"

## Archives of one declared bank set are alternatives the original chooses
## between by a setting (`[Voice] TINA=1|2`); a name may be in several of them
## and none is preferred. Names of one kind may not span a bank set and another
## archive.
const BANK_SETS := {
	"voice": [["tina1.arc", "tina2.arc"]],
}

const BGM_SLOT := 1
const BGM_ROUTINE := 23
const BGM_ASSIGN_COMMAND := 0x09
const BGM_TRANSFER_COMMAND := 0x1D


static func normalize_name(name: Variant) -> String:
	return str(name).to_upper()


## The archives `name` of `kind` is searched in. Empty for an unknown kind or an
## `unclassified` extension no archive is plausible for.
static func archives_for(kind: String, name: String) -> Array:
	if kind == "unclassified":
		return (EXTENSION_ARCHIVES.get(_extension(name), []) as Array).duplicate()
	return (KIND_ARCHIVES.get(kind, []) as Array).duplicate()


## The co-presence group of `archive` for `kind`: every archive of a declared
## bank set shares one group, any other archive is its own.
static func group_of(kind: String, archive: String) -> String:
	for untyped_bank in BANK_SETS.get(kind, []):
		var bank: Array = untyped_bank
		if archive in bank:
			return "bank:" + "+".join(PackedStringArray(bank))
	return archive


static func _extension(name: String) -> String:
	var extension := name.get_extension().to_lower()
	return "" if extension.is_empty() else "." + extension


## Every media occurrence of one member document, sorted by `at`, kind, name.
## `strings` is the member's text document. A row is `{at, kind, name}`; an
## `unclassified` row also carries `evidence`.
func occurrences(document: Dictionary, strings: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for group in _groups(document):
		_classify_group(group.records, group.spans, strings, rows)
	rows.sort_custom(_row_less)
	return rows


## Every script reference of one member document: the `script_target` of any
## record (via the record's op) and the `.MES`/`.LIB` name an
## `inline_script_execution` record names. Sorted by name, `at`, via.
func script_references(document: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for group in _groups(document):
		for untyped_record in group.records:
			if not untyped_record is Dictionary:
				continue
			var record: Dictionary = untyped_record
			var at := _int(record.get("at"))
			var target: Variant = record.get("script_target")
			if target is String and not (target as String).is_empty():
				rows.append({"name": normalize_name(target), "at": at, "via": str(record.get("op", ""))})
			if record.get("op") == "inline_script_execution":
				var operand := _first_operand(record)
				var name: Variant = operand.get("name")
				if operand.get("t") == "resource_name" and name is String and not (name as String).is_empty():
					rows.append({"name": normalize_name(name), "at": at, "via": "inline_script_execution"})
	rows.sort_custom(func(a, b):
		if a.name != b.name:
			return a.name < b.name
		if a.at != b.at:
			return a.at < b.at
		return a.via < b.via)
	return rows


func _groups(document: Dictionary) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	if document.get("kind", "event") == "library":
		var routines: Variant = document.get("routines")
		if routines is Array:
			for untyped_routine in routines:
				if untyped_routine is Dictionary and (untyped_routine as Dictionary).get("records") is Array:
					var routine: Dictionary = untyped_routine
					groups.append({"records": routine.records, "spans": [[_int(routine.get("at")), _int(routine.get("end"))]]})
	elif document.get("records") is Array:
		var spans: Array = []
		var regions: Variant = document.get("regions", [])
		if regions is Array:
			for untyped_region in regions:
				if untyped_region is Dictionary:
					spans.append([_int((untyped_region as Dictionary).get("at")), _int((untyped_region as Dictionary).get("end"))])
		groups.append({"records": document.records, "spans": spans})
	return groups


func _classify_group(records: Array, spans: Array, strings: Array, rows: Array[Dictionary]) -> void:
	var ordered := records
	if not _ascending(records):
		ordered = records.duplicate()
		ordered.sort_custom(func(a, b): return _at_of(a) < _at_of(b))
	var count := ordered.size()
	for index in range(count):
		if not ordered[index] is Dictionary:
			continue
		var record: Dictionary = ordered[index]
		var op: Variant = record.get("op")
		if MARKER_KINDS.has(op):
			var operand := _first_operand(record)
			var name: Variant = operand.get("name")
			if operand.get("t") == "resource_name" and name is String and not (name as String).is_empty():
				rows.append({"at": _int(record.get("at")), "kind": MARKER_KINDS[op], "name": normalize_name(name)})
		elif op == "effect_request":
			var effect := _first_operand(record)
			var effect_name: Variant = effect.get("name")
			if (
				effect.get("t") == "effect_request" and effect.get("resource_kind") == "effect"
				and effect.get("resource_archive") == "se.arc"
				and effect_name is String and not (effect_name as String).is_empty()
			):
				rows.append({"at": _int(record.get("at")), "kind": "se", "name": normalize_name(effect_name)})
		elif op == "system_call":
			_classify_loader(record, strings, rows)
		elif op == "native_record_dispatch":
			_classify_dispatch(record, strings, rows)
		elif op == "argument_slot_write_run" and index + 1 < count and ordered[index + 1] is Dictionary:
			_classify_bgm(record, ordered[index + 1], spans, rows)


func _classify_loader(record: Dictionary, strings: Array, rows: Array[Dictionary]) -> void:
	var function := _int(record.get("system_function"))
	if not LOADER_EXTENSIONS.has(function):
		return
	var loader := _loader_records(record)
	if loader.is_empty():
		return
	var string_position := -1
	var name := ""
	for position in range(loader.size()):
		var untyped_item: Variant = loader[position]
		if untyped_item is Dictionary and (untyped_item as Dictionary).get("kind") == "string_record":
			var string_index := _int((untyped_item as Dictionary).get("s"))
			if string_index >= 0 and string_index < strings.size() and strings[string_index] is String:
				string_position = position
				name = strings[string_index]
			break
	if string_position < 0 or name.is_empty():
		return
	var extension := _extension(name)
	if not extension in (LOADER_EXTENSIONS[function] as Array):
		return
	var at := _int(record.get("at"))
	if function == 8 and extension == ".a6" and _is_a6_shape(loader, string_position):
		rows.append({"at": at, "kind": "a6", "name": normalize_name(name)})
		return
	rows.append({
		"at": at, "kind": "unclassified", "name": normalize_name(name),
		"evidence": "system_function_%d_loader_string" % function,
	})


## A `native_record_dispatch` record carries its media string as the first string
## record of its record list whose extension `EXTENSION_ARCHIVES` knows
## (`[6, 25, "x.dat", N]`, `[6, 24, "x.pal", N]`, `[1, 12, "x.mmo"]`).
func _classify_dispatch(record: Dictionary, strings: Array, rows: Array[Dictionary]) -> void:
	for untyped_item in _loader_records(record):
		if not untyped_item is Dictionary or (untyped_item as Dictionary).get("kind") != "string_record":
			continue
		var string_index := _int((untyped_item as Dictionary).get("s"))
		if string_index < 0 or string_index >= strings.size() or not strings[string_index] is String:
			continue
		var name: String = strings[string_index]
		if name.is_empty() or not EXTENSION_ARCHIVES.has(_extension(name)):
			continue
		rows.append({"at": _int(record.get("at")), "kind": "unclassified", "name": normalize_name(name), "evidence": DISPATCH_EVIDENCE})
		return


## The observed `album.a6` load: three records, a literal 0, the string, and
## `banked_i32[0][3]`.
func _is_a6_shape(loader: Array, string_position: int) -> bool:
	if loader.size() != 3 or string_position != 1:
		return false
	var first: Variant = loader[0]
	var last: Variant = loader[2]
	if not first is Dictionary or not last is Dictionary:
		return false
	if (first as Dictionary).get("kind") != "expression_record" or (last as Dictionary).get("kind") != "expression_record":
		return false
	if not _is_literal((first as Dictionary).get("ast"), 0):
		return false
	var state: Variant = (last as Dictionary).get("ast")
	if not state is Dictionary:
		return false
	var state_ref: Dictionary = state
	return (
		state_ref.get("type") == "state_ref" and state_ref.get("storage") == "banked_i32"
		and _int(state_ref.get("bank")) == 0 and _is_literal(state_ref.get("index"), 3)
	)


func _classify_bgm(assignment: Dictionary, call: Dictionary, spans: Array, rows: Array[Dictionary]) -> void:
	if (
		_int(assignment.get("id")) != BGM_ASSIGN_COMMAND or call.get("op") != "script_transfer"
		or _int(call.get("id")) != BGM_TRANSFER_COMMAND
	):
		return
	var at := _int(assignment.get("at"))
	var call_at := _int(call.get("at"))
	if at < 0 or _int(assignment.get("end")) != call_at:
		return
	var region := _span_index(at, spans)
	if region < 0 or region != _span_index(call_at, spans):
		return
	var pair := _single_slot_pair(assignment)
	if pair.is_empty() or not _is_literal(_transfer_routine(call), BGM_ROUTINE):
		return
	var selector: Variant = _literal_value(pair.get("ast"))
	if selector == null:
		rows.append({"at": at, "kind": "unclassified", "name": "", "evidence": "bgm_selector_not_literal"})
		return
	var entry := BgmCatalogScript.resolve_entry(int(selector)) if int(selector) >= 0 else ""
	if entry.is_empty():
		rows.append({"at": at, "kind": "unclassified", "name": "", "evidence": "bgm_selector_unmapped"})
		return
	rows.append({"at": at, "kind": "bgm", "name": normalize_name(entry)})


## The single `{ast, continuation: 0}` pair of an argument-slot write to slot 1,
## or `{}` when the record is another shape.
func _single_slot_pair(assignment: Dictionary) -> Dictionary:
	var operands: Variant = assignment.get("operands")
	if not operands is Array or (operands as Array).size() != 2:
		return {}
	var slot: Variant = (operands as Array)[0]
	var pairs: Variant = (operands as Array)[1]
	if not slot is Dictionary or not pairs is Dictionary:
		return {}
	if (slot as Dictionary).get("t") != "u16_index" or _int((slot as Dictionary).get("v")) != BGM_SLOT:
		return {}
	if (pairs as Dictionary).get("t") != "expression_byte_pairs":
		return {}
	var list: Variant = (pairs as Dictionary).get("pairs")
	if not list is Array or (list as Array).size() != 1 or not (list as Array)[0] is Dictionary:
		return {}
	var pair: Dictionary = (list as Array)[0]
	if _int(pair.get("continuation")) != 0:
		return {}
	return pair


## The expression of the one record a routine transfer carries, as its `ast`.
func _transfer_routine(call: Dictionary) -> Variant:
	var operands: Variant = call.get("operands")
	if not operands is Array or (operands as Array).size() != 1 or not (operands as Array)[0] is Dictionary:
		return null
	var operand: Dictionary = (operands as Array)[0]
	var records: Variant = operand.get("records")
	if operand.get("t") != "record_list" or not records is Array or (records as Array).size() != 1:
		return null
	var record: Variant = (records as Array)[0]
	if not record is Dictionary or (record as Dictionary).get("kind") != "expression_record":
		return null
	return (record as Dictionary).get("ast")


func _loader_records(record: Dictionary) -> Array:
	var operands: Variant = record.get("operands")
	if not operands is Array:
		return []
	for untyped_operand in operands:
		if untyped_operand is Dictionary and (untyped_operand as Dictionary).get("t") == "record_list":
			var list: Variant = (untyped_operand as Dictionary).get("records")
			return list if list is Array else []
	return []


func _first_operand(record: Dictionary) -> Dictionary:
	var operands: Variant = record.get("operands")
	if operands is Array and not (operands as Array).is_empty() and (operands as Array)[0] is Dictionary:
		return (operands as Array)[0]
	return {}


static func _is_literal(ast: Variant, value: int) -> bool:
	return _literal_value(ast) == value


## The whole-number value of a `literal` expression node, or null when `ast` is
## anything else (an unresolved boundary, a state reference, a fraction).
static func _literal_value(ast: Variant) -> Variant:
	if ast is Dictionary and (ast as Dictionary).get("type") == "literal":
		var value: Variant = (ast as Dictionary).get("value")
		if typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value)):
			return int(value)
	return null


static func _span_index(offset: int, spans: Array) -> int:
	for index in range(spans.size()):
		var span: Array = spans[index]
		if offset >= int(span[0]) and offset < int(span[1]):
			return index
	return -1


static func _ascending(records: Array) -> bool:
	var previous := -1
	for untyped_record in records:
		var at := _at_of(untyped_record)
		if at < previous:
			return false
		previous = at
	return true


static func _at_of(record: Variant) -> int:
	return _int((record as Dictionary).get("at")) if record is Dictionary else -1


static func _row_less(a: Dictionary, b: Dictionary) -> bool:
	if a.at != b.at:
		return a.at < b.at
	if a.kind != b.kind:
		return a.kind < b.kind
	return a.name < b.name


## `value` as an integer when it is a whole JSON number, else -1.
static func _int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	return -1
