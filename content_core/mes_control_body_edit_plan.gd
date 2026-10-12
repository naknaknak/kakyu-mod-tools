class_name KakyuMesControlBodyEditPlan
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const PLAN_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"operation", "body", "relocation", "address_table_updates", "region_updates",
	"node_map", "reference_map", "target_patches", "cfg_relocation",
	"evidence_inventory", "blockers", "assembly_ready", "invariants", "payload_sha256",
]
const INSERT_OPERATION_KEYS := [
	"kind", "anchor_offset", "anchor_instruction_raw_sha256", "donor_start",
	"donor_end", "donor_span_raw_sha256",
]
const REMOVE_OPERATION_KEYS := ["kind", "body_start", "body_end", "body_span_raw_sha256"]
const BODY_KEYS := [
	"policy", "source_region_id", "source_start", "source_end", "byte_length",
	"source_raw_hex", "source_raw_sha256", "source_node_ids", "source_node_hashes",
	"output_start", "output_end", "output_raw_sha256", "inserted_node_map",
]
const INSERTED_NODE_KEYS := [
	"source_node_id", "source_start", "source_end", "output_node_id",
	"output_start", "output_end", "raw_sha256",
]
const RELOCATION_KEYS := [
	"delta", "pivot", "source_code_size", "output_code_size", "entry_count",
	"affected_address_count", "affected_region_count", "affected_node_count",
	"affected_reference_count", "target_patch_count", "cfg_node_count", "cfg_edge_count",
]
const ADDRESS_KEYS := ["index", "source_offset", "output_offset"]
const REGION_KEYS := [
	"region_id", "kind", "index", "source_start", "source_end", "output_start",
	"output_end", "source_raw_sha256", "output_raw_sha256",
]
const NODE_MAP_KEYS := [
	"source_node_id", "source_region_id", "source_start", "source_end", "status",
	"output_node_id", "output_start", "output_end", "raw_sha256",
]
const REFERENCE_MAP_KEYS := [
	"reference_id", "kind", "status", "source_offset", "output_source_offset",
	"source_target_offset", "output_target_offset",
]
const PATCH_KEYS := [
	"reference_id", "reference_kind", "owner_node_id", "owner_op", "command_id",
	"source_instruction_start", "source_instruction_end", "output_instruction_start",
	"output_instruction_end", "source_operand_start", "source_operand_end",
	"output_operand_start", "output_operand_end", "source_target_offset",
	"output_target_offset", "source_target_node_id", "source_raw_hex", "output_raw_hex",
	"encoding",
]
const CFG_RELOCATION_KEYS := [
	"source_control_flow_sha256", "graph_count", "source_node_count",
	"source_edge_count", "node_rows", "edge_rows",
]
const CFG_NODE_KEYS := [
	"graph_index", "source_id", "source_offset", "status", "output_id", "output_offset",
]
const CFG_EDGE_KEYS := [
	"graph_index", "source_from_id", "source_to_id", "kind", "status",
	"output_from_id", "output_to_id",
]
const EVIDENCE_KEYS := [
	"source_reference_count", "source_cfg_graph_count", "source_cfg_node_count",
	"source_cfg_edge_count", "source_call_count", "source_trace_count",
	"source_opaque_node_count", "moved_opaque_node_count", "calls_sha256",
	"traces_sha256", "control_flow_sha256",
]
const BLOCKER_KEYS := ["code", "source_id", "source_offset", "target_offset", "detail"]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const EMPTY_SHA256 := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

const COMPATIBILITY := {
	"policy": "planning_only_exact_typed_control_body_edit",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_operations": ["insert_typed_body_copy", "remove_typed_body"],
	"body_policy": "one_contiguous_strict_typed_span_inside_one_entry",
	"insert_policy": "copy_source_span_preceding_exact_typed_anchor",
	"remove_policy": "delete_span_strictly_inside_one_entry",
	"reference_policy": "all_affected_coordinates_and_encoded_targets_planned",
	"call_resume_policy": "v1_requires_empty_call_and_trace_evidence",
	"opaque_policy": "v1_rejects_any_shifted_opaque_boundary",
	"cfg_policy": "all_affected_graph_node_and_edge_ids_planned",
	"binary_publication": "forbidden",
	"native_engine_compatibility": "unverified",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"source_editable_ir_validated": true,
	"body_contiguous_strict_typed_and_hash_bound": true,
	"body_region_and_entry_boundary_exact": true,
	"address_table_exhaustively_planned": true,
	"source_map_exhaustively_planned": true,
	"reference_coordinates_exhaustively_planned": true,
	"encoded_control_targets_exhaustively_planned": true,
	"cfg_coordinates_exhaustively_planned": true,
	"call_resume_and_trace_evidence_inventoried": true,
	"opaque_boundaries_inventoried": true,
	"binary_not_published": true,
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_CONTROL_BODY_EDIT_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES control-body edit plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_control_body_edit_planner",
		"contract": ContentCoreVersionScript.MES_CONTROL_BODY_EDIT_PLAN_SCHEMA,
	}:
		return _error("MES control-body edit producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES control-body edit compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES control-body edit fingerprint changed.")
	var identity = document.get("source_identity")
	if (
		not identity is Dictionary
		or not ContractValues.has_only_keys(identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("entry", "")))
		or not ContractValues.is_sha256(str(identity.get("archive_sha256", "")))
	):
		return _error("MES control-body edit source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, ["editable_ir_sha256", "decompiler_ir_sha256"])
		or not ContractValues.is_sha256(str(inputs.get("editable_ir_sha256", "")))
		or not ContractValues.is_sha256(str(inputs.get("decompiler_ir_sha256", "")))
	):
		return _error("MES control-body edit input identity changed.")
	var operation = document.get("operation")
	var body = document.get("body")
	var relocation = document.get("relocation")
	var cfg = document.get("cfg_relocation")
	var evidence = document.get("evidence_inventory")
	if not operation is Dictionary or str(operation.get("kind", "")) not in COMPATIBILITY.supported_operations:
		return _error("MES control-body edit operation changed.")
	var operation_keys: Array = INSERT_OPERATION_KEYS if str(operation.kind) == "insert_typed_body_copy" else REMOVE_OPERATION_KEYS
	if not ContractValues.has_exact_keys(operation, operation_keys):
		return _error("MES control-body edit operation fields changed.")
	if not body is Dictionary or not ContractValues.has_exact_keys(body, BODY_KEYS):
		return _error("MES control-body edit body fields changed.")
	if not relocation is Dictionary or not ContractValues.has_exact_keys(relocation, RELOCATION_KEYS):
		return _error("MES control-body edit relocation fields changed.")
	if not cfg is Dictionary or not ContractValues.has_exact_keys(cfg, CFG_RELOCATION_KEYS):
		return _error("MES control-body edit CFG fields changed.")
	if not evidence is Dictionary or not ContractValues.has_exact_keys(evidence, EVIDENCE_KEYS):
		return _error("MES control-body edit evidence fields changed.")
	var rows_result := _validate_rows(document, body, cfg)
	if not rows_result.ok:
		return rows_result
	var integer_result := _validate_integers(operation, body, relocation, evidence)
	if not integer_result.ok:
		return integer_result
	var body_bytes := str(body.source_raw_hex).hex_decode()
	if (
		int(body.source_end) <= int(body.source_start)
		or int(body.byte_length) != int(body.source_end) - int(body.source_start)
		or body_bytes.size() != int(body.byte_length)
		or ContractValues.sha256_or_empty_digest(body_bytes) != str(body.source_raw_sha256)
		or not ContractValues.is_sha256(str(body.output_raw_sha256))
		or not body.source_node_ids is Array
		or not body.source_node_hashes is Array
		or body.source_node_ids.size() == 0
		or body.source_node_ids.size() != body.source_node_hashes.size()
	):
		return _error("MES control-body edit body boundary changed.")
	for value in body.source_node_hashes:
		if not ContractValues.is_sha256(str(value)):
			return _error("MES control-body edit source-node hash changed.")
	var delta := int(relocation.delta)
	if int(relocation.output_code_size) != int(relocation.source_code_size) + delta:
		return _error("MES control-body edit output size changed.")
	if str(operation.kind) == "insert_typed_body_copy":
		if (
			str(body.policy) != "copied_before_anchor"
			or int(operation.anchor_offset) != int(relocation.pivot)
			or int(operation.donor_start) != int(body.source_start)
			or int(operation.donor_end) != int(body.source_end)
			or str(operation.donor_span_raw_sha256) != str(body.source_raw_sha256)
			or not ContractValues.is_sha256(str(operation.anchor_instruction_raw_sha256))
			or int(operation.donor_end) > int(operation.anchor_offset)
			or delta != int(body.byte_length)
			or int(body.output_start) != int(operation.anchor_offset)
			or int(body.output_end) - int(body.output_start) != int(body.byte_length)
			or str(body.output_raw_sha256) != str(body.source_raw_sha256)
			or body.inserted_node_map.size() != body.source_node_ids.size()
		):
			return _error("MES control-body insert contract changed.")
	else:
		if (
			str(body.policy) != "removed_from_source"
			or int(operation.body_start) != int(body.source_start)
			or int(operation.body_end) != int(body.source_end)
			or str(operation.body_span_raw_sha256) != str(body.source_raw_sha256)
			or delta != -int(body.byte_length)
			or int(relocation.pivot) != int(body.source_end)
			or int(body.output_start) != int(body.source_start)
			or int(body.output_end) != int(body.output_start)
			or str(body.output_raw_sha256) != EMPTY_SHA256
			or not body.inserted_node_map.is_empty()
		):
			return _error("MES control-body removal contract changed.")
	if (
		int(relocation.affected_address_count) != document.address_table_updates.size()
		or int(relocation.affected_region_count) != document.region_updates.size()
		or int(relocation.affected_node_count) != document.node_map.size()
		or int(relocation.affected_reference_count) != document.reference_map.size()
		or int(relocation.target_patch_count) != document.target_patches.size()
		or int(relocation.cfg_node_count) != cfg.node_rows.size()
		or int(relocation.cfg_edge_count) != cfg.edge_rows.size()
		or int(cfg.graph_count) != int(evidence.source_cfg_graph_count)
		or int(cfg.source_node_count) != int(evidence.source_cfg_node_count)
		or int(cfg.source_edge_count) != int(evidence.source_cfg_edge_count)
		or str(cfg.source_control_flow_sha256) != str(evidence.control_flow_sha256)
	):
		return _error("MES control-body edit coverage changed.")
	if (
		document.get("assembly_ready") == true
		and (
			int(evidence.source_call_count) != 0
			or int(evidence.source_trace_count) != 0
			or int(evidence.moved_opaque_node_count) != 0
		)
	):
		return _error("MES control-body edit unsupported evidence was marked ready.")
	if document.get("assembly_ready") != document.blockers.is_empty():
		return _error("MES control-body edit readiness changed.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES control-body edit invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONTROL_BODY_EDIT_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": identity.duplicate(true),
		"operation_kind": str(operation.kind),
		"delta": delta,
		"target_patch_count": document.target_patches.size(),
		"blocker_count": document.blockers.size(),
		"assembly_ready": bool(document.assembly_ready),
		"mes_bytes": false,
	}


func _validate_rows(document: Dictionary, body: Dictionary, cfg: Dictionary) -> Dictionary:
	for pair in [
		[document.address_table_updates, ADDRESS_KEYS], [document.region_updates, REGION_KEYS],
		[document.node_map, NODE_MAP_KEYS], [document.reference_map, REFERENCE_MAP_KEYS],
		[document.target_patches, PATCH_KEYS], [body.inserted_node_map, INSERTED_NODE_KEYS],
		[cfg.node_rows, CFG_NODE_KEYS], [cfg.edge_rows, CFG_EDGE_KEYS],
		[document.blockers, BLOCKER_KEYS],
	]:
		if not pair[0] is Array:
			return _error("MES control-body edit row collection changed.")
		for row in pair[0]:
			if not row is Dictionary or not ContractValues.has_exact_keys(row, pair[1]):
				return _error("MES control-body edit row fields changed.")
	for row in document.address_table_updates:
		if not _nonnegative_json_integer(row.index) or not _nonnegative_json_integer(row.source_offset) or not _nonnegative_json_integer(row.output_offset):
			return _error("MES control-body address coordinate changed.")
	for row in document.region_updates:
		if (
			str(row.region_id).is_empty()
			or str(row.kind).is_empty()
			or not _signed_json_integer(row.index)
			or not _nonnegative_json_integer(row.source_start)
			or not _nonnegative_json_integer(row.source_end)
			or not _nonnegative_json_integer(row.output_start)
			or not _nonnegative_json_integer(row.output_end)
			or int(row.source_end) < int(row.source_start)
			or int(row.output_end) < int(row.output_start)
			or not ContractValues.is_sha256(str(row.source_raw_sha256))
			or not ContractValues.is_sha256(str(row.output_raw_sha256))
		):
			return _error("MES control-body region map changed.")
	for row in document.node_map:
		if (
			str(row.source_node_id).is_empty()
			or str(row.source_region_id).is_empty()
			or not _nonnegative_json_integer(row.source_start)
			or not _nonnegative_json_integer(row.source_end)
			or int(row.source_end) <= int(row.source_start)
			or not ContractValues.is_sha256(str(row.raw_sha256))
			or str(row.status) not in ["retained", "removed"]
			or not _signed_json_integer(row.output_start)
			or not _signed_json_integer(row.output_end)
		):
			return _error("MES control-body node map changed.")
		if str(row.status) == "retained" and (
			str(row.output_node_id).is_empty()
			or int(row.output_start) < 0
			or int(row.output_end) - int(row.output_start) != int(row.source_end) - int(row.source_start)
		):
			return _error("MES control-body retained node map changed.")
		if str(row.status) == "removed" and (
			not str(row.output_node_id).is_empty()
			or int(row.output_start) != -1
			or int(row.output_end) != -1
		):
			return _error("MES control-body removed node map changed.")
	for row in document.reference_map:
		if (
			str(row.reference_id).is_empty()
			or str(row.kind).is_empty()
			or not _nonnegative_json_integer(row.source_offset)
			or str(row.status) not in ["retained", "removed"]
			or not _signed_json_integer(row.output_source_offset)
			or not _signed_json_integer(row.source_target_offset)
			or not _signed_json_integer(row.output_target_offset)
		):
			return _error("MES control-body reference map changed.")
		if str(row.status) == "retained" and int(row.output_source_offset) < 0:
			return _error("MES control-body retained reference changed.")
		if str(row.status) == "removed" and int(row.output_source_offset) != -1:
			return _error("MES control-body removed reference changed.")
	for row in document.target_patches:
		if (
			str(row.encoding) != "u32_le_absolute_code_offset"
			or str(row.reference_id).is_empty()
			or str(row.owner_node_id).is_empty()
			or str(row.source_target_node_id).is_empty()
			or not _nonnegative_json_integer(row.command_id)
			or not _nonnegative_json_integer(row.source_instruction_start)
			or not _nonnegative_json_integer(row.source_instruction_end)
			or not _nonnegative_json_integer(row.output_instruction_start)
			or not _nonnegative_json_integer(row.output_instruction_end)
			or not _nonnegative_json_integer(row.source_operand_start)
			or not _nonnegative_json_integer(row.source_operand_end)
			or not _nonnegative_json_integer(row.output_operand_start)
			or not _nonnegative_json_integer(row.output_operand_end)
			or not _nonnegative_json_integer(row.source_target_offset)
			or not _nonnegative_json_integer(row.output_target_offset)
			or str(row.source_raw_hex).hex_decode().size() != 4
			or str(row.output_raw_hex).hex_decode().size() != 4
			or str(row.source_raw_hex) != ContractValues.u32_hex(int(row.source_target_offset))
			or str(row.output_raw_hex) != ContractValues.u32_hex(int(row.output_target_offset))
			or int(row.source_operand_end) - int(row.source_operand_start) != 4
			or int(row.output_operand_end) - int(row.output_operand_start) != 4
			or int(row.source_operand_start) < int(row.source_instruction_start)
			or int(row.source_operand_end) > int(row.source_instruction_end)
			or int(row.output_operand_start) < int(row.output_instruction_start)
			or int(row.output_operand_end) > int(row.output_instruction_end)
		):
			return _error("MES control-body encoded target patch changed.")
	for row in body.inserted_node_map:
		if (
			str(row.source_node_id).is_empty()
			or str(row.output_node_id).is_empty()
			or not _nonnegative_json_integer(row.source_start)
			or not _nonnegative_json_integer(row.source_end)
			or not _nonnegative_json_integer(row.output_start)
			or not _nonnegative_json_integer(row.output_end)
			or int(row.source_end) - int(row.source_start) != int(row.output_end) - int(row.output_start)
			or not ContractValues.is_sha256(str(row.raw_sha256))
		):
			return _error("MES control-body inserted-node map changed.")
	for row in cfg.node_rows:
		if (
			not _nonnegative_json_integer(row.graph_index)
			or str(row.source_id).is_empty()
			or not _nonnegative_json_integer(row.source_offset)
			or str(row.status) not in ["retained", "removed"]
			or not _signed_json_integer(row.output_offset)
		):
			return _error("MES control-body CFG node map changed.")
	for row in cfg.edge_rows:
		if (
			not _nonnegative_json_integer(row.graph_index)
			or str(row.source_from_id).is_empty()
			or str(row.source_to_id).is_empty()
			or str(row.kind).is_empty()
			or str(row.status) not in ["retained", "removed"]
		):
			return _error("MES control-body CFG edge map changed.")
	for row in document.blockers:
		if str(row.code).is_empty() or not _signed_json_integer(row.source_offset) or not _signed_json_integer(row.target_offset):
			return _error("MES control-body blocker changed.")
	return {"ok": true}


func _validate_integers(
	operation: Dictionary, body: Dictionary, relocation: Dictionary, evidence: Dictionary
) -> Dictionary:
	var operation_numeric := ["anchor_offset", "donor_start", "donor_end"] if str(operation.kind) == "insert_typed_body_copy" else ["body_start", "body_end"]
	for key in operation_numeric:
		if not _nonnegative_json_integer(operation.get(key, -1)):
			return _error("MES control-body operation coordinate changed.")
	for key in ["source_start", "source_end", "byte_length", "output_start", "output_end"]:
		if not _nonnegative_json_integer(body.get(key, -1)):
			return _error("MES control-body boundary changed.")
	if not _signed_json_integer(relocation.get("delta", 0)):
		return _error("MES control-body delta changed.")
	for key in RELOCATION_KEYS:
		if key != "delta" and not _nonnegative_json_integer(relocation.get(key, -1)):
			return _error("MES control-body relocation count changed.")
	for key in EVIDENCE_KEYS:
		if key.ends_with("sha256"):
			if not ContractValues.is_sha256(str(evidence.get(key, ""))):
				return _error("MES control-body evidence fingerprint changed.")
		elif not _nonnegative_json_integer(evidence.get(key, -1)):
			return _error("MES control-body evidence count changed.")
	return {"ok": true}


func _nonnegative_json_integer(value: Variant) -> bool:
	return _signed_json_integer(value) and float(value) >= 0.0


func _signed_json_integer(value: Variant) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and float(value) == floor(float(value))
		and abs(float(value)) <= 4294967295.0
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
