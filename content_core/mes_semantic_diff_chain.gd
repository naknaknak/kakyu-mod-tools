class_name KakyuMesSemanticDiffChain
extends RefCounted

## Independent Godot validator for the MW-11 operation-sequence chain proof
## (`kakyu_mes_semantic_diff_chain/v1`): shape, hashes, step chaining and the
## relocation-last-or-absent rule, mirroring
## `tools/diff_mes_sequence_semantics.py`'s `validate` shape checks without
## rebuilding from source. `content_core/mes_semantic_diff.gd` deliberately
## stays untouched: its rejection of this schema (falling through to its own
## top-level schema check) is the fail-closed behaviour every existing
## consumer of a single-step proof relies on.

const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const SCHEMA := "kakyu_mes_semantic_diff_chain/v1"
const STEP_PROOF_SCHEMA_BYTE_PATCH := "kakyu_mes_semantic_diff/v2"
const STEP_PROOF_SCHEMA_RELOCATION := "kakyu_mes_semantic_diff/v4"
const STEP_PROOF_SCHEMAS := [STEP_PROOF_SCHEMA_BYTE_PATCH, STEP_PROOF_SCHEMA_RELOCATION]
const TOP_LEVEL_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity",
	"source_binding", "output_binding", "steps", "composition",
	"invariants", "payload_sha256",
]
const COMPATIBILITY := {
	"policy": "ordered_same_size_steps_then_at_most_one_relocation",
	"step_proof_schemas": STEP_PROOF_SCHEMAS,
	"unknown_diff_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"steps_chained": true,
	"relocation_last_or_absent": true,
	"every_step_proof_validated": true,
	"every_step_audit_validated": true,
}
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const SOURCE_BINDING_KEYS := ["entry_sha256", "analyzer_handoff_sha256"]
const OUTPUT_BINDING_KEYS := ["entry_sha256", "analyzer_handoff_sha256", "bytecode_sha256"]
const COMPOSITION_KEYS := ["step_count", "same_size_step_count", "relocation_step_index", "original_coordinate_patches"]
const STEP_KEYS := [
	"index", "kind", "family", "proof_schema", "proof_sha256",
	"audit_schema", "audit_sha256", "source_entry_sha256",
	"output_entry_sha256", "byte_delta",
]
const PATCH_KEYS := [
	"step", "family", "source_start", "source_end", "output_start",
	"output_end", "source_raw_sha256", "output_raw_sha256",
]


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true or str(document.get("schema", "")) != SCHEMA
		or not ContractValues.has_exact_keys(document, TOP_LEVEL_KEYS)
	):
		return _error("MES sequence semantic diff schema or fields changed.")
	if (
		document.get("producer") != {"implementation": "python_phase6_sequence_semantic_diff", "contract": SCHEMA}
		or document.get("compatibility") != COMPATIBILITY
	):
		return _error("MES sequence semantic diff producer or compatibility changed.")
	var retained := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained) or FingerprintScript.new().fingerprint(document) != retained:
		return _error("MES sequence semantic diff fingerprint changed.")
	var identity = document.get("source_identity")
	if (
		not identity is Dictionary or identity.size() not in [3, 4]
		or not ContractValues.has_only_keys(identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("entry", "")))
		or not ContractValues.is_sha256(str(identity.get("archive_sha256", "")))
	):
		return _error("MES sequence semantic diff source identity changed.")
	var source_binding = document.get("source_binding")
	var output_binding = document.get("output_binding")
	if (
		not source_binding is Dictionary or not ContractValues.has_exact_keys(source_binding, SOURCE_BINDING_KEYS)
		or not ContractValues.hash_values(source_binding, SOURCE_BINDING_KEYS)
		or not output_binding is Dictionary or not ContractValues.has_exact_keys(output_binding, OUTPUT_BINDING_KEYS)
		or not ContractValues.hash_values(output_binding, OUTPUT_BINDING_KEYS)
	):
		return _error("MES sequence semantic diff source or output binding changed.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES sequence semantic diff invariants changed.")
	var composition = document.get("composition")
	var steps = document.get("steps")
	if not composition is Dictionary or not ContractValues.has_exact_keys(composition, COMPOSITION_KEYS) or not steps is Array:
		return _error("MES sequence semantic diff composition or steps changed.")
	if not _nonnegative_json_integer(composition.get("step_count")):
		return _error("MES sequence semantic diff composition accounting changed.")
	var step_count := int(composition.step_count)
	if step_count != steps.size() or step_count < 2:
		return _error("MES sequence semantic diff composition accounting changed.")
	var relocation_raw = composition.get("relocation_step_index")
	if (
		not (relocation_raw is int or relocation_raw is float)
		or not is_finite(float(relocation_raw)) or float(relocation_raw) != floor(float(relocation_raw))
	):
		return _error("MES sequence semantic diff composition accounting changed.")
	var relocation_index := int(relocation_raw)
	if relocation_index != -1 and (relocation_index < 1 or relocation_index > step_count):
		return _error("MES sequence semantic diff composition accounting changed.")
	if not _nonnegative_json_integer(composition.get("same_size_step_count")) or not composition.get("original_coordinate_patches") is Array:
		return _error("MES sequence semantic diff composition accounting changed.")
	var patches: Array = composition.original_coordinate_patches
	var expected_same_size := step_count - (1 if relocation_index != -1 else 0)
	if int(composition.same_size_step_count) != expected_same_size or patches.size() != expected_same_size:
		return _error("MES sequence semantic diff composition accounting changed.")
	var previous_output := str(source_binding.entry_sha256)
	var same_size_positions: Array = []
	for position in range(steps.size()):
		var row = steps[position]
		var index := position + 1
		if not row is Dictionary or not ContractValues.has_exact_keys(row, STEP_KEYS):
			return _error("MES sequence semantic diff step fields changed.")
		if (
			not _nonnegative_json_integer(row.get("index")) or int(row.index) != index
			or str(row.get("proof_schema", "")) not in STEP_PROOF_SCHEMAS
			or str(row.get("kind", "")).is_empty() or str(row.get("family", "")).is_empty()
			or not ContractValues.hash_values(row, ["proof_sha256", "audit_sha256", "source_entry_sha256", "output_entry_sha256"])
			or not (row.get("byte_delta") is int or row.get("byte_delta") is float)
			or str(row.get("source_entry_sha256", "")) != previous_output
		):
			return _error("MES sequence semantic diff step accounting changed.")
		var is_relocation := index == relocation_index
		if is_relocation != (str(row.proof_schema) == STEP_PROOF_SCHEMA_RELOCATION):
			return _error("MES sequence semantic diff relocation placement changed.")
		if is_relocation != (int(row.byte_delta) != 0):
			return _error("MES sequence semantic diff byte delta accounting changed.")
		if str(row.proof_schema) == STEP_PROOF_SCHEMA_BYTE_PATCH:
			same_size_positions.append(index)
		previous_output = str(row.output_entry_sha256)
	if previous_output != str(output_binding.entry_sha256):
		return _error("MES sequence semantic diff output binding does not match the last step.")
	for position in range(patches.size()):
		var patch = patches[position]
		if (
			not patch is Dictionary or not ContractValues.has_exact_keys(patch, PATCH_KEYS)
			or not _nonnegative_json_integer(patch.get("step")) or int(patch.step) != int(same_size_positions[position])
			or not _nonnegative_json_integer(patch.get("source_start")) or not _nonnegative_json_integer(patch.get("source_end"))
			or not _nonnegative_json_integer(patch.get("output_start")) or not _nonnegative_json_integer(patch.get("output_end"))
			or int(patch.source_end) <= int(patch.source_start) or int(patch.output_end) <= int(patch.output_start)
			or not ContractValues.is_sha256(str(patch.get("source_raw_sha256", ""))) or not ContractValues.is_sha256(str(patch.get("output_raw_sha256", "")))
		):
			return _error("MES sequence semantic diff original-coordinate patch changed.")
	return {"ok": true, "schema": SCHEMA, "payload_sha256": retained}


func _nonnegative_json_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0.0 and float(value) <= 4294967295.0


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
