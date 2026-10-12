class_name KakyuMesSemanticDiff
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const TOP_LEVEL_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"operation", "container_diff", "semantic_changes", "node_diff", "preservation",
	"output_binding", "invariants", "payload_sha256",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const INPUT_KEYS := [
	"editable_ir_sha256", "source_decompiler_ir_sha256", "compile_audit_sha256",
	"output_analyzer_handoff_sha256",
]
const OPERATION_KEYS := ["family", "kind"]
const CONTAINER_DIFF_KEYS := [
	"source_size", "output_size", "byte_delta", "source_code_size",
	"output_code_size", "code_delta", "entry_count", "code_offset",
]
const SEMANTIC_CHANGES_KEYS := ["body", "address_changes", "target_changes"]
const BODY_KEYS := [
	"kind", "source_start", "source_end", "output_start", "output_end",
	"byte_length", "raw_sha256", "source_node_count",
]
const ADDRESS_KEYS := ["index", "source_offset", "output_offset"]
const TARGET_KEYS := [
	"reference_id", "reference_kind", "source_owner_offset", "output_owner_offset",
	"source_target_offset", "output_target_offset", "source_operand_sha256",
	"output_operand_sha256", "output_reference_verified",
]
const NODE_DIFF_KEYS := [
	"source_node_count", "output_node_count", "retained_node_count",
	"inserted_node_count", "removed_node_count", "patched_node_count",
	"mapping_sha256", "inserted_nodes", "removed_nodes", "patched_nodes",
]
const NODE_CHANGE_KEYS := [
	"source_node_id", "source_start", "source_end", "output_node_id",
	"output_start", "output_end", "source_raw_sha256", "output_raw_sha256",
]
const PRESERVATION_KEYS := [
	"source_opaque_node_count", "output_opaque_node_count", "exact_opaque_node_count",
	"retained_raw_exact_node_count", "patched_retained_node_count",
	"unrelated_typed_exact_node_count",
]
const OUTPUT_BINDING_KEYS := [
	"analyzer_handoff_sha256", "decompiler_ir_sha256", "entry_sha256",
	"bytecode_sha256",
]
const INVARIANT_KEYS := [
	"source_editable_ir_validated", "compile_audit_validated", "output_handoff_validated",
	"output_decompiler_ir_validated", "expected_output_bytes_exact",
	"address_changes_exact", "all_source_nodes_accounted_once",
	"all_output_nodes_accounted_once", "intended_body_change_exact",
	"intended_target_changes_exact", "unrelated_typed_nodes_preserved",
	"opaque_nodes_preserved_exactly",
]
const COMPATIBILITY := {
	"policy": "source_output_semantic_diff_with_exact_node_mapping",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_compile_audit_schemas": ["kakyu_mes_control_body_edit_compile_audit/v1"],
	"input_handoff_schema": "kakyu_mes_analyzer_handoff/v1",
	"output_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_families": ["control_body_edit"],
	"opaque_policy": "every_source_opaque_node_maps_once_with_identical_raw_bytes",
	"unrelated_node_policy": "every_retained_unpatched_node_maps_once_with_identical_raw_bytes",
	"unknown_diff_schema": "reject",
	"unknown_v1_field": "reject",
}
const V2_PATCH_KEYS := [
	"role", "source_start", "source_end", "output_start", "output_end",
	"byte_length", "source_raw_sha256", "output_raw_sha256", "owner_kind",
	"source_owner_node_id", "output_owner_node_id", "source_owner_start",
	"source_owner_end", "output_owner_start", "output_owner_end",
	"source_owner_sha256", "output_owner_sha256",
]
const V2_ASSERTION_KEYS := [
	"kind", "source_value", "output_value", "reference_id",
	"reference_boundary", "verified",
]
const V2_NODE_DIFF_KEYS := [
	"source_node_count", "output_node_count", "exact_node_count",
	"patched_node_count", "mapping_sha256", "patched_nodes",
]
const V2_NODE_CHANGE_KEYS := [
	"source_node_id", "output_node_id", "source_start", "source_end",
	"output_start", "output_end", "source_raw_sha256", "output_raw_sha256",
	"source_kind", "output_kind",
]
const V2_PRESERVATION_KEYS := [
	"source_typed_node_count", "output_typed_node_count", "exact_typed_node_count",
	"patched_typed_node_count", "source_opaque_node_count", "output_opaque_node_count",
	"exact_opaque_node_count", "patched_opaque_node_count", "unrelated_exact_node_count",
]
const V2_COMPATIBILITY := {
	"policy": "same_layout_exact_patch_and_complete_node_preservation",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_compile_audit_schemas": [
		"kakyu_mes_choice_option_compile_audit/v1",
		"kakyu_mes_condition_literal_compile_audit/v1",
		"kakyu_mes_control_target_edit_compile_audit/v1",
		"kakyu_mes_inline_script_name_compile_audit/v1",
		"kakyu_mes_registered_definition_call_compile_audit/v1",
		"kakyu_mes_resource_name_compile_audit/v1",
		"kakyu_mes_shared_routine_call_compile_audit/v1",
		"kakyu_mes_state_literal_compile_audit/v1",
	],
	"input_handoff_schema": "kakyu_mes_analyzer_handoff/v1",
	"output_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_families": [
		"choice_option_edit", "condition_literal_edit", "control_target_edit",
		"inline_script_name_edit", "registered_definition_call_edit", "resource_name_edit",
		"shared_routine_call_edit", "state_literal_edit",
	],
	"opaque_policy": "unrelated_opaque_exact_and_intended_bounded_opaque_patch_explicit",
	"unrelated_node_policy": "every_unpatched_node_maps_once_with_identical_raw_bytes",
	"unknown_diff_schema": "reject",
	"unknown_v2_field": "reject",
}
const V2_FAMILY_RULES := {
	"condition_literal_edit": {
		"role": "condition_literal", "assertion": "literal_value", "owner_kinds": ["statement"],
	},
	"control_target_edit": {
		"role": "control_target_operand", "assertion": "code_reference_target", "owner_kinds": ["statement"],
	},
	"choice_option_edit": {
		"role": "choice_option_cp932_payload", "assertion": "choice_option_cp932_payload",
		"owner_kinds": ["statement"],
	},
	"inline_script_name_edit": {
		"role": "inline_script_name", "assertion": "resource_reference", "owner_kinds": ["statement", "opaque"],
	},
	"registered_definition_call_edit": {
		"role": "registered_definition_literal", "assertion": "literal_value", "owner_kinds": ["statement"],
	},
	"resource_name_edit": {
		"role": "resource_name", "assertion": "resource_reference", "owner_kinds": ["statement"],
	},
	"shared_routine_call_edit": {
		"role": "shared_routine_literal", "assertion": "literal_value", "owner_kinds": ["statement"],
	},
	"state_literal_edit": {
		"role": "state_expression", "assertion": "literal_value", "owner_kinds": ["statement"],
	},
}
const V2_INVARIANT_KEYS := [
	"source_editable_ir_validated", "compile_audit_validated", "output_handoff_validated",
	"output_decompiler_ir_validated", "container_layout_preserved",
	"expected_output_bytes_exact", "all_source_nodes_accounted_once",
	"all_output_nodes_accounted_once", "intended_patch_exact",
	"semantic_assertion_verified", "unrelated_typed_nodes_preserved",
	"unrelated_opaque_nodes_preserved",
]
const V3_CONTAINER_DIFF_KEYS := [
	"source_size", "output_size", "byte_delta", "source_entry_count",
	"output_entry_count", "entry_delta", "source_code_offset", "output_code_offset",
	"code_offset_delta", "source_code_size", "output_code_size", "code_delta",
]
const V3_ADDRESS_ENTRY_KEYS := [
	"insertion_index", "inserted_offset", "inserted_raw_sha256",
	"source_owner_region", "output_new_region", "target_node_id",
	"target_instruction_sha256", "target_verified",
]
const V3_NODE_DIFF_KEYS := [
	"source_node_count", "output_node_count", "exact_raw_node_count",
	"region_changed_node_count", "region_unchanged_node_count", "mapping_sha256",
]
const V3_PRESERVATION_KEYS := [
	"source_typed_node_count", "output_typed_node_count", "source_opaque_node_count",
	"output_opaque_node_count", "source_bytecode_sha256", "output_bytecode_sha256",
	"bytecode_exact", "reference_coordinates_exact", "statements_exact",
]
const V3_COMPATIBILITY := {
	"policy": "address_entry_insert_with_byte_identical_code_and_exact_node_mapping",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_compile_audit_schemas": ["kakyu_mes_address_entry_insert_compile_audit/v1"],
	"input_handoff_schema": "kakyu_mes_analyzer_handoff/v1",
	"output_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_families": ["address_entry_insert"],
	"unknown_diff_schema": "reject",
	"unknown_v3_field": "reject",
}
const V3_INVARIANT_KEYS := [
	"source_editable_ir_validated", "compile_audit_validated", "output_handoff_validated",
	"output_decompiler_ir_validated", "expected_output_bytes_exact",
	"address_entry_insert_exact", "bytecode_preserved_exactly", "all_nodes_mapped_once",
	"all_node_bytes_preserved", "all_node_statements_preserved",
	"all_references_preserved", "region_partition_change_exact",
]
const V4_OPERATION_KEYS := ["family", "kind", "compile_family"]
const V4_CONTAINER_DIFF_KEYS := [
	"source_size", "output_size", "byte_delta", "source_code_size",
	"output_code_size", "code_delta", "entry_count", "code_offset",
]
const V4_MESSAGE_KEYS := [
	"source_offset", "source_instruction_start", "source_instruction_end",
	"output_instruction_end", "source_payload_sha256", "output_payload_sha256",
	"source_payload_length", "output_payload_length", "source_owner_sha256",
	"output_owner_sha256", "owner_op", "target_verified",
]
const V4_NODE_DIFF_KEYS := [
	"source_node_count", "output_node_count", "mapped_node_count",
	"message_replaced_node_count", "target_patched_node_count",
	"exact_unrelated_node_count", "mapping_sha256",
]
const V4_PRESERVATION_KEYS := [
	"source_opaque_node_count", "output_opaque_node_count",
	"exact_opaque_node_count", "all_reference_count", "address_change_count",
	"target_change_count", "unrelated_node_bytes_exact",
	"reference_coordinates_relocated_exactly",
]
const V4_COMPATIBILITY := {
	"policy": "variable_length_message_with_exact_relocation_mapping",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_compile_audit_schemas": [
		"kakyu_mes_message_compile_audit/v1",
		"kakyu_mes_control_target_compile_audit/v1",
	],
	"input_handoff_schema": "kakyu_mes_analyzer_handoff/v1",
	"output_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_families": ["message_relocation"],
	"unknown_diff_schema": "reject",
	"unknown_v4_field": "reject",
}
const V4_INVARIANT_KEYS := [
	"source_editable_ir_validated", "compile_audit_validated",
	"output_handoff_validated", "output_decompiler_ir_validated",
	"expected_output_bytes_exact", "message_payload_change_exact",
	"address_relocation_exact", "target_relocation_exact", "all_nodes_mapped_once",
	"all_references_mapped_once", "unrelated_node_bytes_preserved",
	"opaque_nodes_preserved_exactly",
]


func validate(document: Dictionary) -> Dictionary:
	if str(document.get("schema", "")) == ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA_V4:
		return _validate_v4(document)
	if str(document.get("schema", "")) == ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA_V3:
		return _validate_v3(document)
	if str(document.get("schema", "")) == ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA_V2:
		return _validate_v2(document)
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA
		or not ContractValues.has_exact_keys(document, TOP_LEVEL_KEYS)
	):
		return _error("MES semantic diff schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_mes_semantic_diff",
		"contract": ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA,
	} or document.get("compatibility") != COMPATIBILITY:
		return _error("MES semantic diff producer or compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES semantic diff fingerprint changed.")
	var identity = document.get("source_identity")
	var inputs = document.get("inputs")
	if (
		not identity is Dictionary or identity.size() not in [3, 4]
		or not ContractValues.has_only_keys(identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("entry", "")))
		or not ContractValues.is_sha256(str(identity.get("archive_sha256", "")))
		or (identity.has("source_kind") and str(identity.source_kind).is_empty())
		or not inputs is Dictionary or not ContractValues.has_exact_keys(inputs, INPUT_KEYS)
		or not ContractValues.hash_values(inputs, INPUT_KEYS)
	):
		return _error("MES semantic diff identity or input hashes changed.")
	var operation = document.get("operation")
	var container = document.get("container_diff")
	if (
		not operation is Dictionary or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("family", "")) != "control_body_edit"
		or str(operation.get("kind", "")) not in ["insert_typed_body_copy", "remove_typed_body"]
		or not container is Dictionary or not ContractValues.has_exact_keys(container, CONTAINER_DIFF_KEYS)
		or not _nonnegative_integer_values(container, [
			"source_size", "output_size", "source_code_size", "output_code_size",
			"entry_count", "code_offset",
		])
		or not _json_integer(container.get("byte_delta"))
		or not _json_integer(container.get("code_delta"))
		or int(container.output_size) - int(container.source_size) != int(container.byte_delta)
		or int(container.output_code_size) - int(container.source_code_size) != int(container.code_delta)
		or int(container.byte_delta) != int(container.code_delta)
	):
		return _error("MES semantic diff operation or container arithmetic changed.")
	var changes = document.get("semantic_changes")
	if not changes is Dictionary or not ContractValues.has_exact_keys(changes, SEMANTIC_CHANGES_KEYS):
		return _error("MES semantic diff semantic-change fields changed.")
	var body_result := _validate_body(operation, container, changes.get("body"))
	if not body_result.ok:
		return body_result
	var address_result := _validate_addresses(changes.get("address_changes"), int(container.code_delta))
	if not address_result.ok:
		return address_result
	var target_result := _validate_targets(changes.get("target_changes"))
	if not target_result.ok:
		return target_result
	var node_result := _validate_nodes(document.get("node_diff"))
	if not node_result.ok:
		return node_result
	var preservation_result := _validate_preservation(document.get("preservation"), document.node_diff)
	if not preservation_result.ok:
		return preservation_result
	var binding = document.get("output_binding")
	var invariants = document.get("invariants")
	if (
		not binding is Dictionary or not ContractValues.has_exact_keys(binding, OUTPUT_BINDING_KEYS)
		or not ContractValues.hash_values(binding, OUTPUT_BINDING_KEYS)
		or not invariants is Dictionary or not ContractValues.has_exact_keys(invariants, INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES semantic diff output binding or invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA,
		"payload_sha256": retained_hash,
		"inserted_node_count": int(document.node_diff.inserted_node_count),
		"removed_node_count": int(document.node_diff.removed_node_count),
		"patched_node_count": int(document.node_diff.patched_node_count),
		"exact_opaque_node_count": int(document.preservation.exact_opaque_node_count),
	}


func _validate_v4(document: Dictionary) -> Dictionary:
	if document.get("ok") != true or not ContractValues.has_exact_keys(document, TOP_LEVEL_KEYS):
		return _error("MES message relocation semantic diff schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_message_relocation_semantic_diff",
		"contract": ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA_V4,
	} or document.get("compatibility") != V4_COMPATIBILITY:
		return _error("MES message relocation semantic diff producer changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES message relocation semantic diff fingerprint changed.")
	var identity = document.get("source_identity")
	var inputs = document.get("inputs")
	if (
		not identity is Dictionary or identity.size() not in [3, 4]
		or not ContractValues.has_only_keys(identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("entry", "")))
		or not ContractValues.is_sha256(str(identity.get("archive_sha256", "")))
		or not inputs is Dictionary or not ContractValues.has_exact_keys(inputs, INPUT_KEYS)
		or not ContractValues.hash_values(inputs, INPUT_KEYS)
	):
		return _error("MES message relocation semantic diff identity or inputs changed.")
	var operation = document.get("operation")
	var container = document.get("container_diff")
	if (
		not operation is Dictionary or not ContractValues.has_exact_keys(operation, V4_OPERATION_KEYS)
		or str(operation.family) != "message_relocation"
		or str(operation.kind) != "replace_message"
		or str(operation.compile_family) not in ["message_only", "message_with_control_targets"]
		or not container is Dictionary or not ContractValues.has_exact_keys(container, V4_CONTAINER_DIFF_KEYS)
		or not _nonnegative_integer_values(container, [
			"source_size", "output_size", "source_code_size", "output_code_size",
			"entry_count", "code_offset",
		])
		or not _json_integer(container.byte_delta) or not _json_integer(container.code_delta)
		or int(container.output_size) - int(container.source_size) != int(container.byte_delta)
		or int(container.output_code_size) - int(container.source_code_size) != int(container.code_delta)
		or int(container.byte_delta) != int(container.code_delta) or int(container.code_delta) == 0
	):
		return _error("MES message relocation semantic diff container changed.")
	var changes = document.get("semantic_changes")
	if not changes is Dictionary or not ContractValues.has_exact_keys(changes, [
		"message", "address_changes_sha256", "target_changes_sha256",
		"reference_mapping_sha256",
	]):
		return _error("MES message relocation semantic changes changed.")
	var message = changes.get("message")
	if (
		not message is Dictionary or not ContractValues.has_exact_keys(message, V4_MESSAGE_KEYS)
		or not _nonnegative_integer_values(message, [
			"source_offset", "source_instruction_start", "source_instruction_end",
			"output_instruction_end", "source_payload_length", "output_payload_length",
		])
		or not ContractValues.hash_values(message, [
			"source_payload_sha256", "output_payload_sha256", "source_owner_sha256",
			"output_owner_sha256",
		])
		or str(message.owner_op).is_empty() or message.target_verified != true
		or int(message.source_instruction_end) <= int(message.source_instruction_start)
		or int(message.output_instruction_end) <= int(message.source_instruction_start)
		or int(message.output_payload_length) - int(message.source_payload_length) != int(container.code_delta)
		or int(message.output_instruction_end) - int(message.source_instruction_end) != int(container.code_delta)
		or not ContractValues.hash_values(changes, [
			"address_changes_sha256", "target_changes_sha256", "reference_mapping_sha256",
		])
	):
		return _error("MES message relocation semantic assertion changed.")
	var nodes = document.get("node_diff")
	if (
		not nodes is Dictionary or not ContractValues.has_exact_keys(nodes, V4_NODE_DIFF_KEYS)
		or not _nonnegative_integer_values(nodes, [
			"source_node_count", "output_node_count", "mapped_node_count",
			"message_replaced_node_count", "target_patched_node_count",
			"exact_unrelated_node_count",
		])
		or not ContractValues.is_sha256(str(nodes.mapping_sha256))
		or int(nodes.source_node_count) != int(nodes.output_node_count)
		or int(nodes.mapped_node_count) != int(nodes.source_node_count)
		or int(nodes.message_replaced_node_count) != 1
		or int(nodes.message_replaced_node_count) + int(nodes.target_patched_node_count)
		+ int(nodes.exact_unrelated_node_count) != int(nodes.source_node_count)
	):
		return _error("MES message relocation semantic node accounting changed.")
	var preservation = document.get("preservation")
	if (
		not preservation is Dictionary or not ContractValues.has_exact_keys(preservation, V4_PRESERVATION_KEYS)
		or not _nonnegative_integer_values(preservation, [
			"source_opaque_node_count", "output_opaque_node_count",
			"exact_opaque_node_count", "all_reference_count", "address_change_count",
			"target_change_count",
		])
		or int(preservation.source_opaque_node_count) != int(preservation.output_opaque_node_count)
		or int(preservation.source_opaque_node_count) != int(preservation.exact_opaque_node_count)
		or preservation.unrelated_node_bytes_exact != true
		or preservation.reference_coordinates_relocated_exactly != true
	):
		return _error("MES message relocation semantic preservation changed.")
	var binding = document.get("output_binding")
	var invariants = document.get("invariants")
	if (
		not binding is Dictionary or not ContractValues.has_exact_keys(binding, OUTPUT_BINDING_KEYS)
		or not ContractValues.hash_values(binding, OUTPUT_BINDING_KEYS)
		or not invariants is Dictionary or not ContractValues.has_exact_keys(invariants, V4_INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES message relocation semantic binding or invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA_V4,
		"payload_sha256": retained_hash,
		"inserted_node_count": 0,
		"removed_node_count": 0,
		"patched_node_count": int(nodes.target_patched_node_count) + 1,
		"exact_opaque_node_count": int(preservation.exact_opaque_node_count),
	}


func _validate_v3(document: Dictionary) -> Dictionary:
	if document.get("ok") != true or not ContractValues.has_exact_keys(document, TOP_LEVEL_KEYS):
		return _error("MES address-entry semantic diff schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_address_entry_semantic_diff",
		"contract": ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA_V3,
	} or document.get("compatibility") != V3_COMPATIBILITY:
		return _error("MES address-entry semantic diff producer or compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES address-entry semantic diff fingerprint changed.")
	var identity = document.get("source_identity")
	var inputs = document.get("inputs")
	if (
		not identity is Dictionary or identity.size() not in [3, 4]
		or not ContractValues.has_only_keys(identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("entry", "")))
		or not ContractValues.is_sha256(str(identity.get("archive_sha256", "")))
		or not inputs is Dictionary or not ContractValues.has_exact_keys(inputs, INPUT_KEYS)
		or not ContractValues.hash_values(inputs, INPUT_KEYS)
	):
		return _error("MES address-entry semantic diff identity or inputs changed.")
	var operation = document.get("operation")
	var container = document.get("container_diff")
	if (
		not operation is Dictionary or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or operation != {"family": "address_entry_insert", "kind": "insert_address_entry"}
		or not container is Dictionary or not ContractValues.has_exact_keys(container, V3_CONTAINER_DIFF_KEYS)
		or not _nonnegative_integer_values(container, V3_CONTAINER_DIFF_KEYS)
		or int(container.output_size) - int(container.source_size) != int(container.byte_delta)
		or int(container.output_entry_count) - int(container.source_entry_count) != int(container.entry_delta)
		or int(container.output_code_offset) - int(container.source_code_offset) != int(container.code_offset_delta)
		or int(container.output_code_size) - int(container.source_code_size) != int(container.code_delta)
		or int(container.byte_delta) != 4 or int(container.entry_delta) != 1
		or int(container.code_offset_delta) != 4 or int(container.code_delta) != 0
	):
		return _error("MES address-entry semantic diff container arithmetic changed.")
	var changes = document.get("semantic_changes")
	if not changes is Dictionary or not ContractValues.has_exact_keys(changes, [
		"address_entry", "region_changes_sha256", "reference_region_changes_sha256",
	]):
		return _error("MES address-entry semantic changes changed.")
	var address = changes.get("address_entry")
	if (
		not address is Dictionary or not ContractValues.has_exact_keys(address, V3_ADDRESS_ENTRY_KEYS)
		or not _nonnegative_integer_values(address, ["insertion_index", "inserted_offset"])
		or not ContractValues.hash_values(address, ["inserted_raw_sha256", "target_instruction_sha256"])
		or str(address.source_owner_region).is_empty() or str(address.output_new_region).is_empty()
		or str(address.target_node_id).is_empty() or address.target_verified != true
		or not ContractValues.is_sha256(str(changes.region_changes_sha256))
		or not ContractValues.is_sha256(str(changes.reference_region_changes_sha256))
	):
		return _error("MES address-entry semantic assertion changed.")
	var nodes = document.get("node_diff")
	if (
		not nodes is Dictionary or not ContractValues.has_exact_keys(nodes, V3_NODE_DIFF_KEYS)
		or not _nonnegative_integer_values(nodes, [
			"source_node_count", "output_node_count", "exact_raw_node_count",
			"region_changed_node_count", "region_unchanged_node_count",
		])
		or not ContractValues.is_sha256(str(nodes.mapping_sha256))
		or int(nodes.source_node_count) != int(nodes.output_node_count)
		or int(nodes.exact_raw_node_count) != int(nodes.source_node_count)
		or int(nodes.region_changed_node_count) + int(nodes.region_unchanged_node_count)
		!= int(nodes.source_node_count)
	):
		return _error("MES address-entry semantic node accounting changed.")
	var preservation = document.get("preservation")
	if (
		not preservation is Dictionary or not ContractValues.has_exact_keys(preservation, V3_PRESERVATION_KEYS)
		or not _nonnegative_integer_values(preservation, [
			"source_typed_node_count", "output_typed_node_count",
			"source_opaque_node_count", "output_opaque_node_count",
		])
		or not ContractValues.hash_values(preservation, ["source_bytecode_sha256", "output_bytecode_sha256"])
		or int(preservation.source_typed_node_count) != int(preservation.output_typed_node_count)
		or int(preservation.source_opaque_node_count) != int(preservation.output_opaque_node_count)
		or str(preservation.source_bytecode_sha256) != str(preservation.output_bytecode_sha256)
		or preservation.bytecode_exact != true or preservation.reference_coordinates_exact != true
		or preservation.statements_exact != true
	):
		return _error("MES address-entry semantic preservation changed.")
	var binding = document.get("output_binding")
	var invariants = document.get("invariants")
	if (
		not binding is Dictionary or not ContractValues.has_exact_keys(binding, OUTPUT_BINDING_KEYS)
		or not ContractValues.hash_values(binding, OUTPUT_BINDING_KEYS)
		or not invariants is Dictionary or not ContractValues.has_exact_keys(invariants, V3_INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES address-entry semantic binding or invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA_V3,
		"payload_sha256": retained_hash,
		"inserted_node_count": 0,
		"removed_node_count": 0,
		"patched_node_count": 0,
		"exact_opaque_node_count": int(preservation.source_opaque_node_count),
	}


func _validate_v2(document: Dictionary) -> Dictionary:
	if document.get("ok") != true or not ContractValues.has_exact_keys(document, TOP_LEVEL_KEYS):
		return _error("MES byte-patch semantic diff schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_byte_patch_semantic_diff",
		"contract": ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA_V2,
	} or document.get("compatibility") != V2_COMPATIBILITY:
		return _error("MES byte-patch semantic diff producer or compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES byte-patch semantic diff fingerprint changed.")
	var identity = document.get("source_identity")
	var inputs = document.get("inputs")
	if (
		not identity is Dictionary or identity.size() not in [3, 4]
		or not ContractValues.has_only_keys(identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("entry", "")))
		or not ContractValues.is_sha256(str(identity.get("archive_sha256", "")))
		or not inputs is Dictionary or not ContractValues.has_exact_keys(inputs, INPUT_KEYS)
		or not ContractValues.hash_values(inputs, INPUT_KEYS)
	):
		return _error("MES byte-patch semantic diff identity or inputs changed.")
	var operation = document.get("operation")
	var container = document.get("container_diff")
	if (
		not operation is Dictionary or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("family", "")) not in V2_COMPATIBILITY.supported_families
		or str(operation.get("kind", "")).is_empty()
		or not container is Dictionary or not ContractValues.has_exact_keys(container, CONTAINER_DIFF_KEYS)
		or not _nonnegative_integer_values(container, [
			"source_size", "output_size", "source_code_size", "output_code_size",
			"entry_count", "code_offset",
		])
		or int(container.get("byte_delta", -1)) != 0 or int(container.get("code_delta", -1)) != 0
		or int(container.source_size) != int(container.output_size)
		or int(container.source_code_size) != int(container.output_code_size)
	):
		return _error("MES byte-patch semantic diff layout changed.")
	var changes = document.get("semantic_changes")
	if not changes is Dictionary or not ContractValues.has_exact_keys(changes, ["patch", "assertion"]):
		return _error("MES byte-patch semantic-change fields changed.")
	var patch = changes.get("patch")
	var assertion = changes.get("assertion")
	if (
		not patch is Dictionary or not ContractValues.has_exact_keys(patch, V2_PATCH_KEYS)
		or not _nonnegative_integer_values(patch, [
			"source_start", "source_end", "output_start", "output_end", "byte_length",
			"source_owner_start", "source_owner_end", "output_owner_start", "output_owner_end",
		])
		or int(patch.source_start) != int(patch.output_start)
		or int(patch.source_end) != int(patch.output_end)
		or int(patch.source_end) - int(patch.source_start) != int(patch.byte_length)
		or int(patch.byte_length) <= 0
		or str(patch.owner_kind) not in ["statement", "opaque"]
		or str(patch.source_owner_node_id).is_empty() or str(patch.output_owner_node_id).is_empty()
		or int(patch.source_owner_start) != int(patch.output_owner_start)
		or int(patch.source_owner_end) != int(patch.output_owner_end)
		or not ContractValues.hash_values(patch, [
			"source_raw_sha256", "output_raw_sha256", "source_owner_sha256",
			"output_owner_sha256",
		])
		or str(patch.source_raw_sha256) == str(patch.output_raw_sha256)
		or not assertion is Dictionary or not ContractValues.has_exact_keys(assertion, V2_ASSERTION_KEYS)
		or str(assertion.get("kind", "")) not in [
			"literal_value", "resource_reference", "code_reference_target",
			"choice_option_cp932_payload",
		]
		or assertion.get("verified") != true
	):
		return _error("MES byte-patch intended change changed.")
	var family_rule = V2_FAMILY_RULES.get(str(operation.family))
	if (
		not family_rule is Dictionary
		or str(patch.role) != str(family_rule.role)
		or str(patch.owner_kind) not in family_rule.owner_kinds
		or str(assertion.kind) != str(family_rule.assertion)
	):
		return _error("MES byte-patch family semantic rule changed.")
	var nodes = document.get("node_diff")
	if (
		not nodes is Dictionary or not ContractValues.has_exact_keys(nodes, V2_NODE_DIFF_KEYS)
		or not _nonnegative_integer_values(nodes, [
			"source_node_count", "output_node_count", "exact_node_count", "patched_node_count",
		])
		or int(nodes.source_node_count) != int(nodes.output_node_count)
		or int(nodes.patched_node_count) != 1
		or int(nodes.exact_node_count) + 1 != int(nodes.source_node_count)
		or not ContractValues.is_sha256(str(nodes.mapping_sha256))
		or not nodes.patched_nodes is Array or nodes.patched_nodes.size() != 1
		or not nodes.patched_nodes[0] is Dictionary
		or not ContractValues.has_exact_keys(nodes.patched_nodes[0], V2_NODE_CHANGE_KEYS)
	):
		return _error("MES byte-patch semantic diff node accounting changed.")
	var preservation = document.get("preservation")
	if (
		not preservation is Dictionary or not ContractValues.has_exact_keys(preservation, V2_PRESERVATION_KEYS)
		or not _nonnegative_integer_values(preservation, V2_PRESERVATION_KEYS)
		or int(preservation.source_typed_node_count) != int(preservation.output_typed_node_count)
		or int(preservation.source_opaque_node_count) != int(preservation.output_opaque_node_count)
		or int(preservation.exact_typed_node_count) + int(preservation.patched_typed_node_count)
		!= int(preservation.source_typed_node_count)
		or int(preservation.exact_opaque_node_count) + int(preservation.patched_opaque_node_count)
		!= int(preservation.source_opaque_node_count)
		or int(preservation.patched_typed_node_count) + int(preservation.patched_opaque_node_count) != 1
		or int(preservation.unrelated_exact_node_count) != int(nodes.exact_node_count)
	):
		return _error("MES byte-patch semantic diff preservation accounting changed.")
	var binding = document.get("output_binding")
	var invariants = document.get("invariants")
	if (
		not binding is Dictionary or not ContractValues.has_exact_keys(binding, OUTPUT_BINDING_KEYS)
		or not ContractValues.hash_values(binding, OUTPUT_BINDING_KEYS)
		or not invariants is Dictionary or not ContractValues.has_exact_keys(invariants, V2_INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES byte-patch semantic diff binding or invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_SEMANTIC_DIFF_SCHEMA_V2,
		"payload_sha256": retained_hash,
		"inserted_node_count": 0,
		"removed_node_count": 0,
		"patched_node_count": 1,
		"exact_opaque_node_count": int(preservation.exact_opaque_node_count),
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _validate_body(operation: Dictionary, container: Dictionary, value: Variant) -> Dictionary:
	if not value is Dictionary or not ContractValues.has_exact_keys(value, BODY_KEYS):
		return _error("MES semantic diff body fields changed.")
	var body: Dictionary = value
	if (
		str(body.kind) != str(operation.kind)
		or not _nonnegative_integer_values(body, [
			"source_start", "source_end", "output_start", "output_end",
			"byte_length", "source_node_count",
		])
		or not ContractValues.is_sha256(str(body.raw_sha256))
		or int(body.source_end) - int(body.source_start) != int(body.byte_length)
		or int(body.source_node_count) <= 0
		or abs(int(container.code_delta)) != int(body.byte_length)
	):
		return _error("MES semantic diff body summary changed.")
	if str(operation.kind) == "insert_typed_body_copy" and (
		int(container.code_delta) <= 0
		or int(body.output_end) - int(body.output_start) != int(body.byte_length)
	):
		return _error("MES semantic diff insertion body changed.")
	if str(operation.kind) == "remove_typed_body" and (
		int(container.code_delta) >= 0 or int(body.output_start) != int(body.output_end)
	):
		return _error("MES semantic diff removal body changed.")
	return {"ok": true}


func _validate_addresses(value: Variant, delta: int) -> Dictionary:
	if not value is Array:
		return _error("MES semantic diff address changes changed.")
	var previous_index := -1
	for row_value in value:
		if not row_value is Dictionary or not ContractValues.has_exact_keys(row_value, ADDRESS_KEYS):
			return _error("MES semantic diff address change fields changed.")
		var row: Dictionary = row_value
		if (
			not _nonnegative_integer_values(row, ADDRESS_KEYS)
			or int(row.index) <= previous_index
			or int(row.output_offset) - int(row.source_offset) != delta
		):
			return _error("MES semantic diff address change changed.")
		previous_index = int(row.index)
	return {"ok": true}


func _validate_targets(value: Variant) -> Dictionary:
	if not value is Array:
		return _error("MES semantic diff target changes changed.")
	for row_value in value:
		if not row_value is Dictionary or not ContractValues.has_exact_keys(row_value, TARGET_KEYS):
			return _error("MES semantic diff target change fields changed.")
		var row: Dictionary = row_value
		if (
			str(row.reference_id).is_empty() or str(row.reference_kind).is_empty()
			or not _nonnegative_integer_values(row, [
				"source_owner_offset", "output_owner_offset", "source_target_offset",
				"output_target_offset",
			])
			or not ContractValues.is_sha256(str(row.source_operand_sha256))
			or not ContractValues.is_sha256(str(row.output_operand_sha256))
			or row.output_reference_verified != true
		):
			return _error("MES semantic diff target change changed.")
	return {"ok": true}


func _validate_nodes(value: Variant) -> Dictionary:
	if not value is Dictionary or not ContractValues.has_exact_keys(value, NODE_DIFF_KEYS):
		return _error("MES semantic diff node-diff fields changed.")
	var nodes: Dictionary = value
	if (
		not _nonnegative_integer_values(nodes, [
			"source_node_count", "output_node_count", "retained_node_count",
			"inserted_node_count", "removed_node_count", "patched_node_count",
		])
		or not ContractValues.is_sha256(str(nodes.mapping_sha256))
		or int(nodes.retained_node_count) + int(nodes.removed_node_count) != int(nodes.source_node_count)
		or int(nodes.retained_node_count) + int(nodes.inserted_node_count) != int(nodes.output_node_count)
	):
		return _error("MES semantic diff node accounting changed.")
	for spec in [
		["inserted_nodes", int(nodes.inserted_node_count), false],
		["removed_nodes", int(nodes.removed_node_count), true],
		["patched_nodes", int(nodes.patched_node_count), false],
	]:
		var rows = nodes.get(spec[0])
		if not rows is Array or rows.size() != spec[1]:
			return _error("MES semantic diff node-change count changed.")
		for row in rows:
			var row_result := _validate_node_change(row, spec[2])
			if not row_result.ok:
				return row_result
	return {"ok": true}


func _validate_node_change(value: Variant, removed: bool) -> Dictionary:
	if not value is Dictionary or not ContractValues.has_exact_keys(value, NODE_CHANGE_KEYS):
		return _error("MES semantic diff node-change fields changed.")
	var row: Dictionary = value
	if (
		str(row.source_node_id).is_empty()
		or not _nonnegative_integer_values(row, ["source_start", "source_end"])
		or int(row.source_end) <= int(row.source_start)
		or not ContractValues.is_sha256(str(row.source_raw_sha256))
	):
		return _error("MES semantic diff source-node change changed.")
	if removed:
		if (
			not str(row.output_node_id).is_empty() or int(row.output_start) != -1
			or int(row.output_end) != -1 or not str(row.output_raw_sha256).is_empty()
		):
			return _error("MES semantic diff removed-node sentinel changed.")
	elif (
		str(row.output_node_id).is_empty()
		or not _nonnegative_integer_values(row, ["output_start", "output_end"])
		or int(row.output_end) <= int(row.output_start)
		or not ContractValues.is_sha256(str(row.output_raw_sha256))
	):
		return _error("MES semantic diff output-node change changed.")
	return {"ok": true}


func _validate_preservation(value: Variant, nodes: Dictionary) -> Dictionary:
	if (
		not value is Dictionary or not ContractValues.has_exact_keys(value, PRESERVATION_KEYS)
		or not _nonnegative_integer_values(value, PRESERVATION_KEYS)
	):
		return _error("MES semantic diff preservation fields changed.")
	var preservation: Dictionary = value
	if (
		int(preservation.source_opaque_node_count) != int(preservation.output_opaque_node_count)
		or int(preservation.source_opaque_node_count) != int(preservation.exact_opaque_node_count)
		or int(preservation.retained_raw_exact_node_count)
		!= int(preservation.exact_opaque_node_count) + int(preservation.unrelated_typed_exact_node_count)
		or int(preservation.patched_retained_node_count) != int(nodes.patched_node_count)
		or int(preservation.retained_raw_exact_node_count) + int(preservation.patched_retained_node_count)
		!= int(nodes.retained_node_count)
	):
		return _error("MES semantic diff preservation accounting changed.")
	return {"ok": true}


func _nonnegative_integer_values(document: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not _json_integer(document.get(key)) or int(document.get(key)) < 0:
			return false
	return true


func _json_integer(value: Variant) -> bool:
	return (
		(value is int or value is float) and is_finite(float(value))
		and float(value) == floor(float(value)) and abs(float(value)) <= 4294967295.0
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
