extends "res://tests/test_case.gd"

const ContractValues := preload("res://content_core/contract_values.gd")

const ABC_SHA256 := "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
const EMPTY_SHA256 := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"


func _ready() -> void:
	var abc := "abc".to_utf8_buffer()
	_check(ContractValues.sha256(abc) == ABC_SHA256, "checked hash matches the known digest")
	_check(ContractValues.sha256_lenient(abc) == ABC_SHA256, "lenient hash matches the known digest")
	_check(ContractValues.sha256(PackedByteArray()) == "", "checked hash refuses empty input")

	_check(ContractValues.sha256_or_empty_digest(abc) == ABC_SHA256, "the empty-tolerant hash matches the known digest")
	_check(
		ContractValues.sha256_or_empty_digest(PackedByteArray()) == EMPTY_SHA256,
		"the empty-tolerant hash yields the empty-message digest",
	)
	_check(ContractValues.EMPTY_SHA256 == EMPTY_SHA256, "the shared empty digest is the standard one")

	_check(ContractValues.is_sha256(ABC_SHA256), "lower-case 64 hex is a hash")
	_check(not ContractValues.is_sha256(ABC_SHA256.to_upper()), "upper-case hex is refused")
	_check(not ContractValues.is_sha256(ABC_SHA256.substr(1)), "63 characters are refused")
	_check(not ContractValues.is_sha256(ABC_SHA256.substr(1) + "g"), "a non-hex character is refused")

	var hashes := {"a": ABC_SHA256, "b": EMPTY_SHA256}
	_check(ContractValues.hash_values(hashes, ["a", "b"]), "listed hash values pass")
	_check(not ContractValues.hash_values(hashes, ["a", "missing"]), "a missing listed key fails")
	_check(ContractValues.all_hash_values(hashes), "every value is a hash")
	_check(not ContractValues.all_hash_values({"a": ABC_SHA256, "b": 7}), "a non-hash value fails")
	_check(ContractValues.all_hash_values({}), "an empty document has no failing value")

	_check(ContractValues.has_only_keys({"a": 1}, ["a", "b"]), "a subset of the allowed keys passes")
	_check(not ContractValues.has_only_keys({"c": 1}, ["a", "b"]), "an unknown key fails")
	_check(ContractValues.has_exact_keys({"a": 1, "b": 2}, ["a", "b"]), "the exact keys pass")
	_check(not ContractValues.has_exact_keys({"a": 1}, ["a", "b"]), "a missing key fails the exact check")
	_check(not ContractValues.has_exact_keys({"a": 1, "c": 2}, ["a", "b"]), "a swapped key fails the exact check")
	var allowed := {"a": true, "b": true}
	_check(ContractValues.has_only_key_set({"b": 1}, allowed), "a subset of the key set passes")
	_check(not ContractValues.has_only_key_set({"c": 1}, allowed), "an unknown key fails the key set")
	_check(ContractValues.has_exact_key_set({"a": 1, "b": 2}, allowed), "the exact key set passes")
	_check(not ContractValues.has_exact_key_set({"a": 1}, allowed), "a missing key fails the exact key set")

	_check(ContractValues.json_integer(3), "an int is a JSON integer")
	_check(ContractValues.json_integer(3.0), "an integral float is a JSON integer")
	_check(ContractValues.json_integer(-2.0), "a negative integral float is a JSON integer")
	_check(not ContractValues.json_integer(3.5), "a fractional float is not")
	_check(not ContractValues.json_integer("3"), "a string is not")
	_check(not ContractValues.json_integer(true), "a bool is not")

	_check(ContractValues.nonnegative_json_integer(0), "zero is a non-negative JSON integer")
	_check(ContractValues.nonnegative_json_integer(7.0), "an integral float is a non-negative JSON integer")
	_check(not ContractValues.nonnegative_json_integer(-1), "a negative int is refused")
	_check(not ContractValues.nonnegative_json_integer(1.5), "a fractional float is refused")
	_check(not ContractValues.nonnegative_json_integer("1"), "a string is refused")
	_check(
		ContractValues.nonnegative_integer_values({"a": 1, "b": 2.0}, ["a", "b"]),
		"listed non-negative integers pass",
	)
	_check(
		not ContractValues.nonnegative_integer_values({"a": 1}, ["a", "missing"]),
		"a missing listed integer fails",
	)
	_check(
		not ContractValues.nonnegative_integer_values({"a": -3}, ["a"]),
		"a negative listed integer fails",
	)

	_check(ContractValues.all_true({"a": true, "b": true}), "all true values pass")
	_check(not ContractValues.all_true({"a": true, "b": 1}), "a truthy non-bool fails")
	_check(not ContractValues.all_true({"a": false}), "a false value fails")

	var intified: Dictionary = ContractValues.intify({"a": 3.0, "b": 3.5, "list": [1.0, 2.5]})
	_check(intified["a"] == 3 and typeof(intified["a"]) == TYPE_INT, "a whole-valued float folds to int")
	_check(intified["b"] == 3.5, "a fractional float is unchanged")
	_check(intified["list"][0] == 1 and typeof(intified["list"][0]) == TYPE_INT, "a whole-valued float inside an array folds to int")
	_check(intified["list"][1] == 2.5, "a fractional float inside an array is unchanged")

	_check(ContractValues.decode_hex("00ff10") == PackedByteArray([0, 255, 16]), "lower-case hex decodes")
	_check(ContractValues.decode_hex("").is_empty(), "empty hex yields no bytes")
	_check(ContractValues.decode_hex("abc").is_empty(), "odd-length hex yields no bytes")
	_check(ContractValues.decode_hex("FF").is_empty(), "upper-case hex yields no bytes")
	_check(ContractValues.decode_hex("zz").is_empty(), "non-hex yields no bytes")

	var state_cells_fingerprint := ContractValues.directory_fingerprint(
		"res://config/contracts/state_cells_v1", "cells_fingerprint"
	)
	var stored_state_cells_fingerprint := FileAccess.get_file_as_string(
		"res://config/contracts/state_cells_v1/cells_fingerprint"
	).strip_edges()
	_check(
		state_cells_fingerprint == stored_state_cells_fingerprint,
		"directory_fingerprint of the state cells table matches the tracked cells_fingerprint",
	)
	_check(
		ContractValues.directory_fingerprint("res://config/contracts/state_cells_v1", "cells_fingerprint")
		== ContractValues.directory_fingerprint("res://config/contracts/state_cells_v1", "cells_fingerprint"),
		"directory_fingerprint is deterministic across two calls",
	)

	get_tree().quit(1 if _failed else 0)
