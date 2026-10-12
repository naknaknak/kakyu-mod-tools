extends Node

const ReopenScript := preload("res://content_core/mes_address_entry_insert_compile_reopen.gd")

var _failures := 0


func _ready() -> void:
	var fixture := _fixture()
	var payload: PackedByteArray = fixture.payload
	var audit: Dictionary = fixture.audit
	var reopened := ReopenScript.new().audit(payload, audit)
	_check(
		reopened.ok
		and reopened.output.entry_count == 3
		and reopened.output.code_offset == 16
		and reopened.table_change.insertion_index == 1
		and reopened.table_change.inserted_offset == 1
		and reopened.target.region == "entry_0001"
		and reopened.phase1_4.typed_node_count == 3
		and reopened.phase1_4.opaque_node_count == 0,
		"GDScript reopens one inserted address entry with unchanged bytecode"
	)
	var transported = JSON.parse_string(JSON.stringify(audit))
	_check(
		transported is Dictionary and ReopenScript.new().audit(payload, transported).ok,
		"address-entry compile audit survives JSON number transport"
	)
	var changed_payload := payload.duplicate()
	changed_payload[changed_payload.size() - 1] = 1
	_check(
		not ReopenScript.new().audit(changed_payload, audit).ok,
		"address-entry reopen rejects changed bytecode"
	)
	var changed_cell := payload.duplicate()
	changed_cell.encode_u32(8, 2)
	_check(
		not ReopenScript.new().audit(changed_cell, audit).ok,
		"address-entry reopen rejects a changed inserted cell"
	)
	var changed_region := audit.duplicate(true)
	changed_region.target.source_region_id = "entry_0001"
	_rehash(changed_region)
	_check(
		not ReopenScript.new().audit(payload, changed_region).ok,
		"address-entry compile audit rejects changed source-region ownership"
	)
	var fractional := audit.duplicate(true)
	fractional.table_change.insertion_index = 1.5
	_rehash(fractional)
	_check(
		not ReopenScript.new().audit(payload, fractional).ok,
		"address-entry compile audit rejects fractional JSON coordinates"
	)
	var unknown := audit.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not ReopenScript.new().audit(payload, unknown).ok,
		"address-entry compile audit rejects unknown fields"
	)
	var stale := audit.duplicate(true)
	stale.payload_sha256 = "0".repeat(64)
	_check(
		not ReopenScript.new().audit(payload, stale).ok,
		"address-entry compile audit rejects a stale fingerprint"
	)
	if _failures == 0:
		get_tree().quit(0)
	else:
		push_error("%d MES address-entry compile reopen checks failed." % _failures)
		get_tree().quit(1)


func _fixture() -> Dictionary:
	var source_preamble := PackedByteArray([
		2, 0, 0, 0,
		0, 0, 0, 0,
		2, 0, 0, 0,
	])
	var output_preamble := PackedByteArray([
		3, 0, 0, 0,
		0, 0, 0, 0,
		1, 0, 0, 0,
		2, 0, 0, 0,
	])
	var code := PackedByteArray([0, 0, 0])
	var source_payload := source_preamble + code
	var output_payload := output_preamble + code
	var instruction_hash := _sha256(PackedByteArray([0]))
	var audit := {
		"ok": true,
		"schema": "kakyu_mes_address_entry_insert_compile_audit/v1",
		"producer": {
			"implementation": "python_phase6_address_entry_insert_compiler",
			"contract": "kakyu_mes_address_entry_insert_compile_audit/v1",
		},
		"compatibility": ReopenScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "ENTRY_INSERT.MES",
			"source_kind": "original_arc",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "b".repeat(64),
			"decompiler_ir_sha256": "c".repeat(64),
			"address_entry_insert_plan_sha256": "d".repeat(64),
		},
		"operation": {
			"kind": "insert_address_entry",
			"owner_entry_index": 0,
			"target_offset": 1,
			"instruction_raw_sha256": instruction_hash,
		},
		"target": {
			"node_id": "linear_00000001",
			"evidence_status": "typed_phase1_4",
			"source_region_id": "entry_0000",
			"source_region_index": 0,
			"source_region_start": 0,
			"source_region_end": 2,
			"instruction_start": 1,
			"instruction_end": 2,
			"instruction_raw_sha256": instruction_hash,
			"op": "command_00",
			"command_id": 0,
		},
		"table_change": {
			"source_entry_count": 2,
			"output_entry_count": 3,
			"insertion_index": 1,
			"inserted_offset": 1,
			"inserted_raw_hex": "01000000",
			"previous_entry_offset": 0,
			"next_entry_offset": 2,
			"source_code_offset": 12,
			"output_code_offset": 16,
			"source_preamble_sha256": _sha256(source_preamble),
			"output_preamble_sha256": _sha256(output_preamble),
			"source_address_table_sha256": _sha256(source_preamble.slice(4)),
			"output_address_table_sha256": _sha256(output_preamble.slice(4)),
		},
		"source": _container_summary(source_payload, source_preamble.size()),
		"output": _container_summary(output_payload, output_preamble.size()),
		"coverage": {
			"source_code_size": 3,
			"output_code_size": 3,
			"source_node_count": 3,
			"moved_node_count": 1,
			"moved_reference_count": 0,
		},
		"invariants": ReopenScript.INVARIANTS.duplicate(true),
	}
	_rehash(audit)
	return {"payload": output_payload, "audit": audit}


func _container_summary(payload: PackedByteArray, code_offset: int) -> Dictionary:
	return {
		"size": payload.size(),
		"entry_count": (code_offset - 4) / 4,
		"code_offset": code_offset,
		"code_size": payload.size() - code_offset,
		"entry_sha256": _sha256(payload),
		"bytecode_sha256": _sha256(payload.slice(code_offset)),
		"preamble_sha256": _sha256(payload.slice(0, code_offset)),
		"address_table_sha256": _sha256(payload.slice(4, code_offset)),
	}


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = ReopenScript.new().fingerprint(document)


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: %s" % label)
