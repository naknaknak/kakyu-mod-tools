extends "res://tests/test_case.gd"

const PlanScript := preload("res://content_core/mes_utf8_overlay_plan.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")


func _ready() -> void:
	var validator := PlanScript.new()
	var source := _fixture()
	var valid := validator.validate(source)
	_check(
		valid.ok
		and valid.projection_document.edits[0].text == "리메이크 전용 😀",
		"remake-only UTF-8 overlay plan validates"
	)
	var transported = JSON.parse_string(JSON.stringify(source))
	_check(
		transported is Dictionary and validator.validate(transported).ok,
		"UTF-8 overlay plan survives JSON number transport"
	)
	var changed_policy := source.duplicate(true)
	changed_policy.operation.container_policy = "assemble_mes"
	_rehash(changed_policy)
	_check(
		not validator.validate(changed_policy).ok,
		"UTF-8 overlay plan cannot request MES assembly"
	)
	var changed_compatibility := source.duplicate(true)
	changed_compatibility.operation.compatibility = "original_engine_compatible"
	_rehash(changed_compatibility)
	_check(
		not validator.validate(changed_compatibility).ok,
		"UTF-8 overlay plan cannot claim original-engine compatibility"
	)
	var changed_projection := source.duplicate(true)
	changed_projection.projection_document.target_entry = "OTHER.MES"
	_rehash(changed_projection)
	_check(
		not validator.validate(changed_projection).ok,
		"UTF-8 overlay projection must retain its source target"
	)
	var unknown := source.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not validator.validate(unknown).ok,
		"UTF-8 overlay plan rejects unknown fields"
	)
	var fractional := source.duplicate(true)
	fractional.operation.source_offset = 0.5
	_rehash(fractional)
	_check(
		not validator.validate(fractional).ok,
		"UTF-8 overlay plan rejects fractional JSON coordinates"
	)
	var stale := source.duplicate(true)
	stale.operation.text = "changed without rehash"
	_check(
		not validator.validate(stale).ok,
		"UTF-8 overlay plan rejects a stale fingerprint"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _fixture() -> Dictionary:
	var operation := {
		"kind": "replace_message_utf8_overlay",
		"source_offset": 0,
		"raw_sha256": "b".repeat(64),
		"text": "리메이크 전용 😀",
		"encoding": "utf8",
		"compatibility": "remake_only",
		"container_policy": "do_not_assemble_mes",
	}
	var document := {
		"ok": true,
		"schema": "kakyu_mes_utf8_overlay_plan/v1",
		"producer": {
			"implementation": "python_phase6_utf8_overlay_planner",
			"contract": "kakyu_mes_utf8_overlay_plan/v1",
		},
		"compatibility": PlanScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "TEST.MES",
			"source_kind": "original_arc",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"entry_sha256": "3".repeat(64),
		},
		"operation": operation,
		"target": {
			"reference_id": "message_00000000",
			"node_id": "node_00000000",
			"region_id": "entry_0000",
			"instruction_start": 0,
			"instruction_end": 4,
			"payload_start": 1,
			"payload_end": 3,
			"source_byte_length": 2,
			"source_raw_sha256": "b".repeat(64),
		},
		"projection_document": {
			"schema": "kakyu_mes_text_overlay_entry/v1",
			"base_archive_sha256": "a".repeat(64),
			"entry_sha256": "3".repeat(64),
			"target_archive": "mes.arc",
			"target_entry": "TEST.MES",
			"edits": [{
				"source_offset": 0,
				"raw_sha256": "b".repeat(64),
				"text": "리메이크 전용 😀",
			}],
		},
		"invariants": {
			"source_editable_ir_validated": true,
			"target_message_unique_and_typed": true,
			"source_message_hash_matched": true,
			"source_message_strict_cp932": true,
			"replacement_utf8_valid": true,
			"projection_document_ready": true,
			"mes_container_bytes_not_emitted": true,
			"source_container_not_modified": true,
		},
	}
	_rehash(document)
	return document


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = FingerprintScript.new().fingerprint(document)
