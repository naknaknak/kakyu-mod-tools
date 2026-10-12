extends Node

const SemanticDiffScript := preload("res://content_core/mes_semantic_diff.gd")

var _failures := 0


func _ready() -> void:
	var validator := SemanticDiffScript.new()
	var document := _fixture(validator)
	var result := validator.validate(document)
	_check(
		result.ok
		and result.inserted_node_count == 1
		and result.removed_node_count == 0
		and result.patched_node_count == 0
		and result.exact_opaque_node_count == 1,
		"semantic diff validates exact inserted and preserved-node accounting"
	)
	var changed_preservation := document.duplicate(true)
	changed_preservation.preservation.exact_opaque_node_count = 0
	_rehash(changed_preservation, validator)
	_check(
		not validator.validate(changed_preservation).ok,
		"semantic diff rejects rehashed opaque-preservation drift"
	)
	var changed_node_count := document.duplicate(true)
	changed_node_count.node_diff.output_node_count = 4
	_rehash(changed_node_count, validator)
	_check(
		not validator.validate(changed_node_count).ok,
		"semantic diff rejects rehashed node-accounting drift"
	)
	var unknown := document.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown, validator)
	_check(not validator.validate(unknown).ok, "semantic diff rejects unknown fields")
	var stale := document.duplicate(true)
	stale.payload_sha256 = "0".repeat(64)
	_check(not validator.validate(stale).ok, "semantic diff rejects a stale fingerprint")
	var v2 := _fixture_v2(validator)
	var v2_result := validator.validate(v2)
	_check(
		v2_result.ok and v2_result.patched_node_count == 1
		and v2.preservation.patched_opaque_node_count == 1,
		"semantic diff v2 distinguishes one intended opaque patch"
	)
	var changed_v2 := v2.duplicate(true)
	changed_v2.preservation.exact_opaque_node_count = 1
	_rehash(changed_v2, validator)
	_check(
		not validator.validate(changed_v2).ok,
		"semantic diff v2 rejects rehashed opaque accounting drift"
	)
	var control_v2 := _fixture_v2_control_target(validator)
	_check(
		validator.validate(control_v2).ok,
		"semantic diff v2 validates an explicit control-target semantic assertion"
	)
	var mismatched_family := control_v2.duplicate(true)
	mismatched_family.semantic_changes.assertion.kind = "literal_value"
	_rehash(mismatched_family, validator)
	_check(
		not validator.validate(mismatched_family).ok,
		"semantic diff v2 rejects a family/assertion mismatch"
	)
	var choice_v2 := _fixture_v2_choice(validator)
	_check(
		validator.validate(choice_v2).ok,
		"semantic diff v2 validates a typed choice-option payload assertion"
	)
	var choice_v2_source_kind := _fixture_v2_choice_source_kind(validator)
	_check(
		validator.validate(choice_v2_source_kind).ok,
		"semantic diff v2 validates a choice diff whose editable identity carries source_kind"
	)
	var address_v3 := _fixture_v3_address_entry(validator)
	_check(
		validator.validate(address_v3).ok,
		"semantic diff v3 validates an address-entry insertion"
	)
	var changed_address_v3 := address_v3.duplicate(true)
	changed_address_v3.node_diff.region_changed_node_count += 1
	_rehash(changed_address_v3, validator)
	_check(
		not validator.validate(changed_address_v3).ok,
		"semantic diff v3 rejects rehashed region accounting drift"
	)
	var message_v4 := _fixture_v4_message(validator)
	_check(
		validator.validate(message_v4).ok,
		"semantic diff v4 validates a variable-length message relocation"
	)
	var changed_message_v4 := message_v4.duplicate(true)
	changed_message_v4.node_diff.exact_unrelated_node_count += 1
	_rehash(changed_message_v4, validator)
	_check(
		not validator.validate(changed_message_v4).ok,
		"semantic diff v4 rejects rehashed node accounting drift"
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture(validator: RefCounted) -> Dictionary:
	var source_hash := _sha256("1f01000000".hex_decode())
	var inserted := {
		"source_node_id": "linear_00000000", "source_start": 0, "source_end": 1,
		"output_node_id": "linear_00000001", "output_start": 1, "output_end": 2,
		"source_raw_sha256": source_hash, "output_raw_sha256": source_hash,
	}
	var document := {
		"ok": true,
		"schema": "kakyu_mes_semantic_diff/v1",
		"producer": {
			"implementation": "python_phase6_mes_semantic_diff",
			"contract": "kakyu_mes_semantic_diff/v1",
		},
		"compatibility": SemanticDiffScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc", "entry": "TEST.MES", "source_kind": "original_arc",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "b".repeat(64),
			"source_decompiler_ir_sha256": "c".repeat(64),
			"compile_audit_sha256": "d".repeat(64),
			"output_analyzer_handoff_sha256": "e".repeat(64),
		},
		"operation": {"family": "control_body_edit", "kind": "insert_typed_body_copy"},
		"container_diff": {
			"source_size": 10, "output_size": 11, "byte_delta": 1,
			"source_code_size": 2, "output_code_size": 3, "code_delta": 1,
			"entry_count": 1, "code_offset": 8,
		},
		"semantic_changes": {
			"body": {
				"kind": "insert_typed_body_copy", "source_start": 0, "source_end": 1,
				"output_start": 1, "output_end": 2, "byte_length": 1,
				"raw_sha256": source_hash, "source_node_count": 1,
			},
			"address_changes": [],
			"target_changes": [],
		},
		"node_diff": {
			"source_node_count": 2, "output_node_count": 3, "retained_node_count": 2,
			"inserted_node_count": 1, "removed_node_count": 0, "patched_node_count": 0,
			"mapping_sha256": "f".repeat(64), "inserted_nodes": [inserted],
			"removed_nodes": [], "patched_nodes": [],
		},
		"preservation": {
			"source_opaque_node_count": 1, "output_opaque_node_count": 1,
			"exact_opaque_node_count": 1, "retained_raw_exact_node_count": 2,
			"patched_retained_node_count": 0, "unrelated_typed_exact_node_count": 1,
		},
		"output_binding": {
			"analyzer_handoff_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"entry_sha256": "3".repeat(64), "bytecode_sha256": "4".repeat(64),
		},
		"invariants": {},
	}
	for key in SemanticDiffScript.INVARIANT_KEYS:
		document.invariants[key] = true
	_rehash(document, validator)
	return document


func _fixture_v2(validator: RefCounted) -> Dictionary:
	var source_hash := _sha256("61".hex_decode())
	var output_hash := _sha256("62".hex_decode())
	var document := {
		"ok": true, "schema": "kakyu_mes_semantic_diff/v2",
		"producer": {"implementation": "python_phase6_byte_patch_semantic_diff", "contract": "kakyu_mes_semantic_diff/v2"},
		"compatibility": SemanticDiffScript.V2_COMPATIBILITY.duplicate(true),
		"source_identity": {"archive": "mes.arc", "entry": "TEST.MES", "archive_sha256": "a".repeat(64)},
		"inputs": {"editable_ir_sha256": "b".repeat(64), "source_decompiler_ir_sha256": "c".repeat(64),
			"compile_audit_sha256": "d".repeat(64), "output_analyzer_handoff_sha256": "e".repeat(64)},
		"operation": {"family": "inline_script_name_edit", "kind": "replace_inline_script_name"},
		"container_diff": {"source_size": 10, "output_size": 10, "byte_delta": 0,
			"source_code_size": 2, "output_code_size": 2, "code_delta": 0,
			"entry_count": 1, "code_offset": 8},
		"semantic_changes": {
			"patch": {"role": "inline_script_name", "source_start": 0, "source_end": 1,
				"output_start": 0, "output_end": 1, "byte_length": 1,
				"source_raw_sha256": source_hash, "output_raw_sha256": output_hash,
				"owner_kind": "opaque", "source_owner_node_id": "linear_00000000",
				"output_owner_node_id": "linear_00000000", "source_owner_start": 0,
				"source_owner_end": 2, "output_owner_start": 0, "output_owner_end": 2,
				"source_owner_sha256": "1".repeat(64), "output_owner_sha256": "2".repeat(64)},
			"assertion": {"kind": "resource_reference", "source_value": "a.lib",
				"output_value": "b.lib", "reference_id": "resource_00000000",
				"reference_boundary": "bounded_envelope_scan", "verified": true}},
		"node_diff": {"source_node_count": 1, "output_node_count": 1,
			"exact_node_count": 0, "patched_node_count": 1, "mapping_sha256": "3".repeat(64),
			"patched_nodes": [{"source_node_id": "linear_00000000", "output_node_id": "linear_00000000",
				"source_start": 0, "source_end": 2, "output_start": 0, "output_end": 2,
				"source_raw_sha256": "1".repeat(64), "output_raw_sha256": "2".repeat(64),
				"source_kind": "opaque", "output_kind": "opaque"}]},
		"preservation": {"source_typed_node_count": 0, "output_typed_node_count": 0,
			"exact_typed_node_count": 0, "patched_typed_node_count": 0,
			"source_opaque_node_count": 1, "output_opaque_node_count": 1,
			"exact_opaque_node_count": 0, "patched_opaque_node_count": 1,
			"unrelated_exact_node_count": 0},
		"output_binding": {"analyzer_handoff_sha256": "4".repeat(64),
			"decompiler_ir_sha256": "5".repeat(64), "entry_sha256": "6".repeat(64),
			"bytecode_sha256": "7".repeat(64)},
		"invariants": {},
	}
	for key in SemanticDiffScript.V2_INVARIANT_KEYS:
		document.invariants[key] = true
	_rehash(document, validator)
	return document


func _fixture_v2_control_target(validator: RefCounted) -> Dictionary:
	var document := _fixture_v2(validator)
	document.operation = {"family": "control_target_edit", "kind": "retarget_control_flow"}
	document.semantic_changes.patch.role = "control_target_operand"
	document.semantic_changes.patch.owner_kind = "statement"
	document.semantic_changes.assertion = {
		"kind": "code_reference_target", "source_value": 5, "output_value": 6,
		"reference_id": "code_00000000", "reference_boundary": "continuation_target",
		"verified": true,
	}
	document.node_diff.patched_nodes[0].source_kind = "statement"
	document.node_diff.patched_nodes[0].output_kind = "statement"
	document.preservation = {
		"source_typed_node_count": 1, "output_typed_node_count": 1,
		"exact_typed_node_count": 0, "patched_typed_node_count": 1,
		"source_opaque_node_count": 0, "output_opaque_node_count": 0,
		"exact_opaque_node_count": 0, "patched_opaque_node_count": 0,
		"unrelated_exact_node_count": 0,
	}
	_rehash(document, validator)
	return document


func _fixture_v2_choice(validator: RefCounted) -> Dictionary:
	var document := _fixture_v2_control_target(validator)
	document.operation = {
		"family": "choice_option_edit", "kind": "replace_choice_option_cp932_same_length",
	}
	document.semantic_changes.patch.role = "choice_option_cp932_payload"
	document.semantic_changes.assertion = {
		"kind": "choice_option_cp932_payload", "source_value": "a".repeat(64),
		"output_value": "b".repeat(64), "reference_id": "",
		"reference_boundary": "typed_cp932_message_payload", "verified": true,
	}
	_rehash(document, validator)
	return document


func _fixture_v2_choice_source_kind(validator: RefCounted) -> Dictionary:
	# The real mes_authoring_workflow editable model's source_identity always
	# carries source_kind (mes_authoring_workflow._source()); the choice
	# proof's own identity never does. The diff document's source_identity is
	# copied straight from the editable model, so a real choice diff document
	# carries a 4-key identity with source_kind, not the 3-key fixture above.
	var document := _fixture_v2_choice(validator)
	document.source_identity = {
		"archive": "mes.arc", "entry": "TEST.MES", "source_kind": "original_arc",
		"archive_sha256": "a".repeat(64),
	}
	_rehash(document, validator)
	return document


func _fixture_v3_address_entry(validator: RefCounted) -> Dictionary:
	var document := {
		"ok": true,
		"schema": "kakyu_mes_semantic_diff/v3",
		"producer": {
			"implementation": "python_phase6_address_entry_semantic_diff",
			"contract": "kakyu_mes_semantic_diff/v3",
		},
		"compatibility": {
			"policy": "address_entry_insert_with_byte_identical_code_and_exact_node_mapping",
			"input_editable_schema": "kakyu_mes_editable_ir/v1",
			"input_compile_audit_schemas": ["kakyu_mes_address_entry_insert_compile_audit/v1"],
			"input_handoff_schema": "kakyu_mes_analyzer_handoff/v1",
			"output_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
			"supported_families": ["address_entry_insert"],
			"unknown_diff_schema": "reject", "unknown_v3_field": "reject",
		},
		"source_identity": {
			"archive": "mes.arc", "entry": "ENTRY.MES", "source_kind": "original_arc",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "b".repeat(64), "source_decompiler_ir_sha256": "c".repeat(64),
			"compile_audit_sha256": "d".repeat(64), "output_analyzer_handoff_sha256": "e".repeat(64),
		},
		"operation": {"family": "address_entry_insert", "kind": "insert_address_entry"},
		"container_diff": {
			"source_size": 15, "output_size": 19, "byte_delta": 4,
			"source_entry_count": 2, "output_entry_count": 3, "entry_delta": 1,
			"source_code_offset": 12, "output_code_offset": 16, "code_offset_delta": 4,
			"source_code_size": 3, "output_code_size": 3, "code_delta": 0,
		},
		"semantic_changes": {
			"address_entry": {
				"insertion_index": 1, "inserted_offset": 1,
				"inserted_raw_sha256": "f".repeat(64), "source_owner_region": "entry_0000",
				"output_new_region": "entry_0001", "target_node_id": "linear_00000001",
				"target_instruction_sha256": "1".repeat(64), "target_verified": true,
			},
			"region_changes_sha256": "2".repeat(64),
			"reference_region_changes_sha256": "8".repeat(64),
		},
		"node_diff": {
			"source_node_count": 3, "output_node_count": 3, "exact_raw_node_count": 3,
			"region_changed_node_count": 2, "region_unchanged_node_count": 1,
			"mapping_sha256": "3".repeat(64),
		},
		"preservation": {
			"source_typed_node_count": 3, "output_typed_node_count": 3,
			"source_opaque_node_count": 0, "output_opaque_node_count": 0,
			"source_bytecode_sha256": "4".repeat(64),
			"output_bytecode_sha256": "4".repeat(64),
			"bytecode_exact": true, "reference_coordinates_exact": true,
			"statements_exact": true,
		},
		"output_binding": {
			"analyzer_handoff_sha256": "5".repeat(64), "decompiler_ir_sha256": "6".repeat(64),
			"entry_sha256": "7".repeat(64), "bytecode_sha256": "4".repeat(64),
		},
		"invariants": {
			"source_editable_ir_validated": true, "compile_audit_validated": true,
			"output_handoff_validated": true, "output_decompiler_ir_validated": true,
			"expected_output_bytes_exact": true, "address_entry_insert_exact": true,
			"bytecode_preserved_exactly": true, "all_nodes_mapped_once": true,
			"all_node_bytes_preserved": true, "all_node_statements_preserved": true,
			"all_references_preserved": true, "region_partition_change_exact": true,
		},
	}
	_rehash(document, validator)
	return document


func _fixture_v4_message(validator: RefCounted) -> Dictionary:
	var document := {
		"ok": true,
		"schema": "kakyu_mes_semantic_diff/v4",
		"producer": {
			"implementation": "python_phase6_message_relocation_semantic_diff",
			"contract": "kakyu_mes_semantic_diff/v4",
		},
		"compatibility": {
			"policy": "variable_length_message_with_exact_relocation_mapping",
			"input_editable_schema": "kakyu_mes_editable_ir/v1",
			"input_compile_audit_schemas": [
				"kakyu_mes_message_compile_audit/v1",
				"kakyu_mes_control_target_compile_audit/v1",
			],
			"input_handoff_schema": "kakyu_mes_analyzer_handoff/v1",
			"output_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
			"supported_families": ["message_relocation"],
			"unknown_diff_schema": "reject", "unknown_v4_field": "reject",
		},
		"source_identity": {
			"archive": "mes.arc", "entry": "ENTRY.MES", "source_kind": "original_arc",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "b".repeat(64), "source_decompiler_ir_sha256": "c".repeat(64),
			"compile_audit_sha256": "d".repeat(64), "output_analyzer_handoff_sha256": "e".repeat(64),
		},
		"operation": {
			"family": "message_relocation", "kind": "replace_message",
			"compile_family": "message_with_control_targets",
		},
		"container_diff": {
			"source_size": 20, "output_size": 22, "byte_delta": 2,
			"source_code_size": 12, "output_code_size": 14, "code_delta": 2,
			"entry_count": 2, "code_offset": 8,
		},
		"semantic_changes": {
			"message": {
				"source_offset": 0, "source_instruction_start": 0,
				"source_instruction_end": 4, "output_instruction_end": 6,
				"source_payload_sha256": "f".repeat(64),
				"output_payload_sha256": "1".repeat(64),
				"source_payload_length": 2, "output_payload_length": 4,
				"source_owner_sha256": "2".repeat(64),
				"output_owner_sha256": "3".repeat(64), "owner_op": "text",
				"target_verified": true,
			},
			"address_changes_sha256": "4".repeat(64),
			"target_changes_sha256": "5".repeat(64),
			"reference_mapping_sha256": "6".repeat(64),
		},
		"node_diff": {
			"source_node_count": 3, "output_node_count": 3, "mapped_node_count": 3,
			"message_replaced_node_count": 1, "target_patched_node_count": 1,
			"exact_unrelated_node_count": 1, "mapping_sha256": "7".repeat(64),
		},
		"preservation": {
			"source_opaque_node_count": 0, "output_opaque_node_count": 0,
			"exact_opaque_node_count": 0, "all_reference_count": 2,
			"address_change_count": 1, "target_change_count": 1,
			"unrelated_node_bytes_exact": true,
			"reference_coordinates_relocated_exactly": true,
		},
		"output_binding": {
			"analyzer_handoff_sha256": "8".repeat(64), "decompiler_ir_sha256": "9".repeat(64),
			"entry_sha256": "0".repeat(64), "bytecode_sha256": "a".repeat(64),
		},
		"invariants": {
			"source_editable_ir_validated": true, "compile_audit_validated": true,
			"output_handoff_validated": true, "output_decompiler_ir_validated": true,
			"expected_output_bytes_exact": true, "message_payload_change_exact": true,
			"address_relocation_exact": true, "target_relocation_exact": true,
			"all_nodes_mapped_once": true, "all_references_mapped_once": true,
			"unrelated_node_bytes_preserved": true, "opaque_nodes_preserved_exactly": true,
		},
	}
	_rehash(document, validator)
	return document


func _rehash(document: Dictionary, validator: RefCounted) -> void:
	document["payload_sha256"] = validator.call("fingerprint", document)


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
