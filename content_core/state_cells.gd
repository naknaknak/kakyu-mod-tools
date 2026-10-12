class_name KakyuStateCells
extends RefCounted

## A Godot port of `tools/state_cells.py` over the same tracked table
## (`res://config/contracts/state_cells_v1/state_cells.json`), the cell-class
## classifier the mod event definition contract and the Definitions form
## share (MW-13, unit A). The table is loaded once and cached; its hash is
## checked against `config/contracts/state_cells_v1/cells_fingerprint`
## (`content_core/contract_values.gd`'s `directory_fingerprint`, the same
## rule `tools/contract_fingerprint.py` and the remake's
## `KakyuEventDefinitionValidator.fingerprint_directory` use) the first time
## the table is loaded.

const ContractValues := preload("res://content_core/contract_values.gd")

const DEFAULT_TABLE_PATH := "res://config/contracts/state_cells_v1/state_cells.json"
const DEFAULT_TABLE_DIR := "res://config/contracts/state_cells_v1"
const DEFAULT_FINGERPRINT_NAME := "cells_fingerprint"

static var _cache: Dictionary = {}
static var _fingerprint_checked := false
static var _fingerprint_ok := true
static var _fingerprint_computed := ""
static var _fingerprint_stored := ""


## Loads and caches the table at `DEFAULT_TABLE_PATH`. Returns the parsed
## document: `{"schema", "classes", "cells", "rules"}`.
static func load_table() -> Dictionary:
	if _cache.has(DEFAULT_TABLE_PATH):
		return _cache[DEFAULT_TABLE_PATH]
	var text := FileAccess.get_file_as_string(DEFAULT_TABLE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	var table: Dictionary = parsed if parsed is Dictionary else {}
	_cache[DEFAULT_TABLE_PATH] = table
	if not _fingerprint_checked:
		_fingerprint_checked = true
		_fingerprint_computed = ContractValues.directory_fingerprint(DEFAULT_TABLE_DIR, DEFAULT_FINGERPRINT_NAME)
		_fingerprint_stored = FileAccess.get_file_as_string(
			DEFAULT_TABLE_DIR.path_join(DEFAULT_FINGERPRINT_NAME)
		).strip_edges()
		_fingerprint_ok = _fingerprint_computed == _fingerprint_stored
	return table


## Whether the table's fingerprint, checked the first time `load_table` ran,
## matched the tracked `cells_fingerprint`.
static func fingerprint_ok() -> bool:
	load_table()
	return _fingerprint_ok


static func computed_fingerprint() -> String:
	load_table()
	return _fingerprint_computed


static func stored_fingerprint() -> String:
	load_table()
	return _fingerprint_stored


static func _table_row(table: Dictionary, storage: String, bank: int, index: int) -> Dictionary:
	for untyped_row in table.get("cells", []):
		var row: Dictionary = untyped_row
		if str(row.get("storage", "")) == storage and int(row.get("bank", -1)) == bank and int(row.get("index", -1)) == index:
			return row
	return {}


## The cell class of `(storage, bank, index)`: the table's row when one names
## the cell; else the storage-wide rule (`global_u8` -> `flag` when
## `observed_values` is non-empty and every value is 0 or 1, else `counter`;
## `state_u16`/`banked_u16`/`banked_u8`/`global_i32` -> `unnamed`); else "".
static func classify(
	storage: String, bank: int, index: int, observed_values: Array = [], table := {}
) -> String:
	var active_table := table if not table.is_empty() else load_table()
	var row := _table_row(active_table, storage, bank, index)
	if not row.is_empty():
		return str(row.get("cell_class", ""))
	if storage == "global_u8":
		if not observed_values.is_empty():
			var all_flag_like := true
			for value in observed_values:
				if int(value) != 0 and int(value) != 1:
					all_flag_like = false
					break
			if all_flag_like:
				return "flag"
		return "counter"
	if storage in ["state_u16", "banked_u16", "banked_u8", "global_i32"]:
		return "unnamed"
	return ""


## The heroine name of an affection cell, or "" when the cell is not one
## (including `banked_u16[213]`, which the table keeps `unnamed`).
static func heroine(storage: String, bank: int, index: int, table := {}) -> String:
	var active_table := table if not table.is_empty() else load_table()
	var row := _table_row(active_table, storage, bank, index)
	if not row.is_empty() and str(row.get("cell_class", "")) == "affection":
		return str(row.get("heroine", ""))
	return ""


## The thirteen heroine names, in the table's row order.
static func heroines(table := {}) -> PackedStringArray:
	var active_table := table if not table.is_empty() else load_table()
	var names := PackedStringArray()
	for untyped_row in active_table.get("cells", []):
		var row: Dictionary = untyped_row
		if str(row.get("cell_class", "")) == "affection":
			names.append(str(row.get("heroine", "")))
	return names
