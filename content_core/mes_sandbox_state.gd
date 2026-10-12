class_name KakyuMesSandboxState
extends RefCounted

const STORAGE_MASKS := {
	"state_u16": 0xFFFF,
	"state_i32": 0xFFFFFFFF,
	"global_u8": 0xFF,
	"global_i32": 0xFFFFFFFF,
	"banked_u16": 0xFFFF,
	"banked_u8": 0xFF,
	"banked_i32": 0xFFFFFFFF,
	"relative_u8": 0xFF,
}
const MAX_RELATIVE_U8_ADDRESS := 0xFFFF

var _values: Dictionary = {}
var _relative_u8_baseline: Dictionary = {}
var _random := RandomNumberGenerator.new()
var _native_relative_u8_aliases_enabled := false
var _native_banked_u16_zero_baseline := -1


func _init(random_seed := 1) -> void:
	_random.seed = random_seed


func read_value(storage: String, index: int, bank := 0) -> int:
	if not STORAGE_MASKS.has(storage) or index < 0 or bank < 0:
		return 0
	if storage == "banked_u8" and _native_relative_u8_aliases_enabled:
		var address := native_relative_u8_address(bank, index)
		if address < 0:
			return 0
		return _read_relative_u8(address)
	if storage == "relative_u8":
		return _read_relative_u8(index)
	if storage == "banked_u16" and bank == 0 and index == 0 and _native_banked_u16_zero_baseline >= 0:
		var override_key := _key(storage, index, bank)
		if not _values.has(override_key):
			return _native_banked_u16_zero_baseline
	return int(_values.get(_key(storage, index, bank), 0))


func write_value(storage: String, index: int, value: int, bank := 0) -> bool:
	if not STORAGE_MASKS.has(storage) or index < 0 or bank < 0:
		return false
	if storage == "banked_u8" and _native_relative_u8_aliases_enabled:
		var address := native_relative_u8_address(bank, index)
		if address < 0:
			return false
		_values[_key("relative_u8", address, 0)] = value & 0xFF
		return true
	var mask := int(STORAGE_MASKS[storage])
	_values[_key(storage, index, bank)] = value & mask
	return true


func set_native_relative_u8_aliases_enabled(enabled: bool) -> void:
	_native_relative_u8_aliases_enabled = enabled


func set_native_banked_u16_zero_baseline(value: int) -> bool:
	if value < 0 or value > 0xFFFF:
		return false
	_values.erase(_key("banked_u16", 0, 0))
	_native_banked_u16_zero_baseline = value
	return true


func native_relative_u8_aliases_enabled() -> bool:
	return _native_relative_u8_aliases_enabled


func native_relative_u8_address(bank: int, index: int) -> int:
	if not _native_relative_u8_aliases_enabled or bank < 0 or index < 0:
		return -1
	var base := int(_values.get(_key("state_u16", bank, 0), 0))
	var address := base + index
	if address < 0 or address > MAX_RELATIVE_U8_ADDRESS:
		return -1
	return address


func write_relative_u8_block(start_address: int, values: PackedByteArray) -> bool:
	if start_address < 0 or start_address > MAX_RELATIVE_U8_ADDRESS:
		return false
	if values.size() > MAX_RELATIVE_U8_ADDRESS - start_address + 1:
		return false
	for index in range(values.size()):
		_relative_u8_baseline[start_address + index] = int(values[index])
	return true


func clear_native_relative_u8_layout() -> void:
	_native_relative_u8_aliases_enabled = false
	_native_banked_u16_zero_baseline = -1
	_relative_u8_baseline.clear()
	var stale_keys: Array = []
	for key in _values:
		if str(key).begins_with("relative_u8:"):
			stale_keys.append(key)
	for key in stale_keys:
		_values.erase(key)


func _read_relative_u8(address: int) -> int:
	var override_key := _key("relative_u8", address, 0)
	if _values.has(override_key):
		return int(_values[override_key])
	return int(_relative_u8_baseline.get(address, 0))


func random_below(bound: int) -> int:
	if bound <= 0:
		return 0
	return _random.randi_range(0, bound - 1)


func snapshot() -> Dictionary:
	return _values.duplicate(true)


func random_state() -> int:
	# The RNG position is part of a continuation's future; a route that proves
	# it repeats must compare it along with the stored values.
	return _random.state


func duplicate_state() -> KakyuMesSandboxState:
	var copy := KakyuMesSandboxState.new(1)
	copy._values = _values.duplicate(true)
	copy._relative_u8_baseline = _relative_u8_baseline.duplicate(true)
	copy._native_relative_u8_aliases_enabled = _native_relative_u8_aliases_enabled
	copy._native_banked_u16_zero_baseline = _native_banked_u16_zero_baseline
	copy._random.state = _random.state
	return copy


func restore(snapshot_value: Dictionary) -> void:
	_values = snapshot_value.duplicate(true)


func diff(before: Dictionary) -> Array[Dictionary]:
	var all_keys: Dictionary = {}
	for key in before:
		all_keys[key] = true
	for key in _values:
		all_keys[key] = true
	var keys: Array = all_keys.keys()
	keys.sort()
	var result: Array[Dictionary] = []
	for key in keys:
		var old_value := int(before.get(key, 0))
		var new_value := int(_values.get(key, 0))
		if old_value == new_value:
			continue
		var parsed := _parse_key(str(key))
		result.append({
			"storage": parsed.storage,
			"bank": parsed.bank,
			"index": parsed.index,
			"before": old_value,
			"after": new_value,
		})
	return result


func load_values(records: Array) -> Dictionary:
	var accepted := 0
	for untyped_record in records:
		if not untyped_record is Dictionary:
			continue
		var record: Dictionary = untyped_record
		if write_value(
			str(record.get("storage", "")),
			int(record.get("index", -1)),
			int(record.get("value", 0)),
			int(record.get("bank", 0))
		):
			accepted += 1
	return {"ok": accepted == records.size(), "accepted": accepted, "total": records.size()}


func to_records() -> Array[Dictionary]:
	var keys: Array = _values.keys()
	keys.sort()
	var records: Array[Dictionary] = []
	for key in keys:
		var parsed := _parse_key(str(key))
		records.append({
			"storage": parsed.storage,
			"bank": parsed.bank,
			"index": parsed.index,
			"value": int(_values[key]),
		})
	return records


func _key(storage: String, index: int, bank: int) -> String:
	return "%s:%d:%d" % [storage, bank, index]


func _parse_key(key: String) -> Dictionary:
	var parts := key.split(":")
	return {
		"storage": parts[0],
		"bank": int(parts[1]),
		"index": int(parts[2]),
	}
