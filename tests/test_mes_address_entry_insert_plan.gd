extends Node

const PlanScript := preload("res://content_core/mes_address_entry_insert_plan.gd")

var _failures := 0


func _ready() -> void:
	var validator := PlanScript.new()
	var source := _fixture()
	var result := validator.validate(source)
	_check(
		result.ok
		and result.source_entry_count == 2
		and result.output_entry_count == 3
		and result.insertion_index == 1
		and result.target_offset == 1
		and result.mes_bytes == false,
		"exact typed address-entry insertion plan validates"
	)
	var transported = JSON.parse_string(JSON.stringify(source))
	_check(
		transported is Dictionary and validator.validate(transported).ok,
		"address-entry insertion plan survives JSON number transport"
	)
	var changed_raw := source.duplicate(true)
	changed_raw.table_change.inserted_raw_hex = "02000000"
	_rehash(changed_raw)
	_check(
		not validator.validate(changed_raw).ok,
		"address-entry insertion plan rejects a changed little-endian cell"
	)
	var boundary := source.duplicate(true)
	boundary.operation.target_offset = 0
	boundary.target.instruction_start = 0
	boundary.table_change.inserted_offset = 0
	boundary.table_change.inserted_raw_hex = "00000000"
	_rehash(boundary)
	_check(
		not validator.validate(boundary).ok,
		"address-entry insertion target must stay strictly inside its source entry"
	)
	var structural := source.duplicate(true)
	structural.target.evidence_status = "structural_boundary_only"
	_rehash(structural)
	_check(
		not validator.validate(structural).ok,
		"address-entry insertion rejects non-strict target evidence"
	)
	var fractional := source.duplicate(true)
	fractional.operation.target_offset = 1.5
	_rehash(fractional)
	_check(
		not validator.validate(fractional).ok,
		"address-entry insertion rejects fractional JSON coordinates"
	)
	var unknown := source.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not validator.validate(unknown).ok,
		"address-entry insertion plan rejects unknown fields"
	)
	var stale := source.duplicate(true)
	stale.payload_sha256 = "0".repeat(64)
	_check(
		not validator.validate(stale).ok,
		"address-entry insertion plan rejects a stale fingerprint"
	)
	if _failures == 0:
		get_tree().quit(0)
	else:
		push_error("%d MES address-entry insertion plan checks failed." % _failures)
		get_tree().quit(1)


func _fixture() -> Dictionary:
	var document := {
		"ok": true,
		"schema": "kakyu_mes_address_entry_insert_plan/v1",
		"producer": {
			"implementation": "python_phase6_address_entry_insert_planner",
			"contract": "kakyu_mes_address_entry_insert_plan/v1",
		},
		"compatibility": PlanScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "ENTRY_INSERT.MES",
			"source_kind": "original_arc",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "b".repeat(64),
			"decompiler_ir_sha256": "c".repeat(64),
		},
		"operation": {
			"kind": "insert_address_entry",
			"owner_entry_index": 0,
			"target_offset": 1,
			"instruction_raw_sha256": "d".repeat(64),
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
			"instruction_raw_sha256": "d".repeat(64),
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
			"source_preamble_sha256": "e".repeat(64),
			"output_preamble_sha256": "f".repeat(64),
			"source_address_table_sha256": "1".repeat(64),
			"output_address_table_sha256": "2".repeat(64),
		},
		"coverage": {
			"source_code_size": 3,
			"output_code_size": 3,
			"source_node_count": 3,
			"moved_node_count": 1,
			"moved_reference_count": 0,
		},
		"assembly_ready": true,
		"invariants": PlanScript.INVARIANTS.duplicate(true),
	}
	_rehash(document)
	return document


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = PlanScript.FingerprintScript.new().fingerprint(document)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: %s" % label)
