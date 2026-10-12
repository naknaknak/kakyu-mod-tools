extends "res://tests/test_case.gd"

const PlanScript := preload("res://content_core/mes_control_target_relocation_plan.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")


func _ready() -> void:
	var validator := PlanScript.new()
	var source := _fixture()
	var valid := validator.validate(source)
	_check(
		valid.ok and valid.patch_count == 1 and valid.assembly_ready,
		"exact continuation target relocation plan validates"
	)
	var transported = JSON.parse_string(JSON.stringify(source))
	_check(
		transported is Dictionary and validator.validate(transported).ok,
		"control-target relocation plan survives JSON number transport"
	)
	var branch := source.duplicate(true)
	var branch_patch: Dictionary = branch.target_patches[0]
	branch_patch.reference_kind = "condition_false_target"
	branch_patch.owner_op = "branch_if_not_true"
	branch_patch.command_id = 0x0B
	branch_patch.source_instruction_end = 11
	branch_patch.output_instruction_end = 13
	branch_patch.source_operand_start = 7
	branch_patch.source_operand_end = 11
	branch_patch.output_operand_start = 9
	branch_patch.output_operand_end = 13
	_rehash(branch)
	_check(
		validator.validate(branch).ok,
		"variable-condition branch retains a trailing four-byte target"
	)
	var definition := source.duplicate(true)
	var definition_patch: Dictionary = definition.target_patches[0]
	definition_patch.reference_id = "definition_skip_00000004"
	definition_patch.reference_kind = "definition_skip_target"
	definition_patch.owner_op = "command_10"
	definition_patch.command_id = 0x10
	definition.resolved_blocker_reference_ids[0] = definition_patch.reference_id
	_rehash(definition)
	_check(
		validator.validate(definition).ok,
		"command-10 definition skip retains a trailing four-byte target"
	)
	var moved_operand := source.duplicate(true)
	moved_operand.target_patches[0].source_operand_start = 4
	_rehash(moved_operand)
	_check(
		not validator.validate(moved_operand).ok,
		"continuation target must begin one byte after its command"
	)
	var changed_target := source.duplicate(true)
	changed_target.target_patches[0].output_raw_hex = "07000000"
	_rehash(changed_target)
	_check(
		not validator.validate(changed_target).ok,
		"encoded target bytes must equal the relocated coordinate"
	)
	var remaining := source.duplicate(true)
	remaining.remaining_blockers = [{"code": "opaque_boundary_would_shift"}]
	remaining.assembly_ready = false
	_rehash(remaining)
	_check(
		validator.validate(remaining).ok,
		"unresolved non-control blocker remains explicit and fail-closed"
	)
	var false_ready := remaining.duplicate(true)
	false_ready.assembly_ready = true
	_rehash(false_ready)
	_check(
		not validator.validate(false_ready).ok,
		"remaining blocker prevents assembly readiness"
	)
	var unknown := source.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not validator.validate(unknown).ok,
		"control-target relocation plan rejects unknown fields"
	)
	var stale := source.duplicate(true)
	stale.target_patches[0].output_target_offset = 7
	_check(
		not validator.validate(stale).ok,
		"control-target relocation plan rejects a stale fingerprint"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _fixture() -> Dictionary:
	var document := {
		"ok": true,
		"schema": "kakyu_mes_control_target_relocation_plan/v2",
		"producer": {
			"implementation": "python_phase6_control_target_relocation_planner",
			"contract": "kakyu_mes_control_target_relocation_plan/v2",
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
			"message_relocation_plan_sha256": "3".repeat(64),
		},
		"relocation": {
			"delta": 2,
			"pivot_source_end": 4,
			"source_code_size": 9,
			"output_code_size": 11,
		},
		"target_patches": [{
			"reference_id": "code_00000000",
			"reference_kind": "continuation_target",
			"owner_node_id": "linear_00000004",
			"owner_op": "continuation_transfer",
			"command_id": 0x0C,
			"source_instruction_start": 4,
			"source_instruction_end": 9,
			"output_instruction_start": 6,
			"output_instruction_end": 11,
			"source_operand_start": 5,
			"source_operand_end": 9,
			"output_operand_start": 7,
			"output_operand_end": 11,
			"source_target_offset": 4,
			"output_target_offset": 6,
			"source_target_node_id": "linear_00000004",
			"source_raw_hex": "04000000",
			"output_raw_hex": "06000000",
			"encoding": "u32_le_absolute_code_offset",
		}],
		"resolved_blocker_reference_ids": ["code_00000000"],
		"remaining_blockers": [],
		"assembly_ready": true,
		"invariants": PlanScript.INVARIANTS.duplicate(true),
	}
	_rehash(document)
	return document


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = FingerprintScript.new().fingerprint(document)
