extends RefCounted

## Test-only helpers shared across scenes that are not about the ARC
## container format (TD-05 unit 5); see tests/synthetic_arc.gd for that.
## Tests preload this as `const TestHelpers := preload("res://tests/test_helpers.gd")`.

const ContractValues := preload("res://content_core/contract_values.gd")


## True when `left` and `right` are the same color within a tolerance a
## touch above one 8-bit step, to absorb Compatibility renderer rounding.
static func color_close(left: Color, right: Color) -> bool:
	var tolerance := 1.0 / 255.0 + 0.00001
	return (
		absf(left.r - right.r) <= tolerance
		and absf(left.g - right.g) <= tolerance
		and absf(left.b - right.b) <= tolerance
	)


## Recursively converts whole-valued floats to int, the shape JSON round-tripping
## produces from an int-valued source (`JSON.parse_string` always yields float).
## Delegates to `ContractValues.intify` (TD-05 unit 5b) so the converted tests'
## `TestHelpers.intify(...)` call sites stay unchanged.
static func intify(value: Variant) -> Variant:
	return ContractValues.intify(value)


## The `new_event_plain` contract fixture as a definition document of mod
## `mod_id` carrying the real contract and cells fingerprints and `line_text` as
## its one dialogue line (WD-10: extracted from the set importer's test so the
## mod bundle test shares it). `JSON.parse_string` returns every JSON number as
## a float; the contract's strict integer fields (weekday, rank, cell indexes,
## ...) need the whole-number floats folded back to int before this round-trips
## through the Python validator, which never sees the fixture's original bytes.
static func new_event_definition_document(contract_fp: String, cells_fp: String, line_text: String, mod_id := "moddefimport") -> Dictionary:
	var document: Dictionary = intify(JSON.parse_string(FileAccess.get_file_as_string("res://config/contracts/mod_event_definition_v1/valid/new_event_plain.json")))
	document.contract_fingerprint = contract_fp
	document.cells_fingerprint = cells_fp
	document.mod = {"id": mod_id, "revision": 1}
	document.id = "mod.%s.new_event_plain" % mod_id
	document.dialogue[0].text = line_text
	return document


## The bytes a workspace stages for a definition document: pretty-printed JSON
## with one trailing line feed, as the definition editor writes it.
static func definition_document_bytes(document: Dictionary) -> PackedByteArray:
	return (JSON.stringify(document, "  ") + "\n").to_utf8_buffer()
