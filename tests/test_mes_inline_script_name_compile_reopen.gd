extends "res://tests/test_case.gd"

const ReopenScript := preload("res://content_core/mes_inline_script_name_compile_reopen.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")


func _ready() -> void:
	var reopener := ReopenScript.new()
	var fixture := _fixture(false, 2)
	var result := reopener.audit(fixture.output, fixture.audit)
	_check(
		result.ok
		and result.edited_call.op == "inline_script_execution"
		and result.edited_call.owner_kind == "opaque"
		and result.edited_call.reference_boundary == "bounded_envelope_scan"
		and result.edited_call.execution_selector == 2
		and result.edited_call.replacement_name == "libtest.lib",
		"bounded inline library target reopens through Phase 1-4"
	)
	var transported = JSON.parse_string(JSON.stringify(fixture.audit))
	_check(
		transported is Dictionary and reopener.audit(fixture.output, transported).ok,
		"inline script compile audit survives JSON number transport"
	)
	var typed_fixture := _fixture(true, 3)
	var typed_result := reopener.audit(typed_fixture.output, typed_fixture.audit)
	_check(
		typed_result.ok
		and typed_result.edited_call.owner_kind == "statement"
		and typed_result.edited_call.reference_boundary == "strict_indexed"
		and typed_result.edited_call.execution_role == "definition_bootstrap",
		"strict typed definition target reopens through Phase 1-4"
	)
	var changed_payload: PackedByteArray = fixture.output.duplicate()
	changed_payload[fixture.audit.output.code_offset + fixture.audit.target.name_start] = 0x78
	_check(not reopener.audit(changed_payload, fixture.audit).ok, "changed output bytes are rejected")
	var changed_boundary: Dictionary = fixture.audit.duplicate(true)
	changed_boundary.target.reference_boundary = "strict_indexed"
	_rehash(changed_boundary)
	_check(not reopener.audit(fixture.output, changed_boundary).ok, "changed owner boundary is rejected")
	var fractional: Dictionary = fixture.audit.duplicate(true)
	fractional.target.name_start = 9.5
	_rehash(fractional)
	_check(not reopener.audit(fixture.output, fractional).ok, "fractional coordinates are rejected")
	var unknown: Dictionary = fixture.audit.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(not reopener.audit(fixture.output, unknown).ok, "unknown fields are rejected")
	var stale: Dictionary = fixture.audit.duplicate(true)
	stale.output.entry_sha256 = "0".repeat(64)
	_check(not reopener.audit(fixture.output, stale).ok, "stale fingerprint is rejected")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _fixture(typed: bool, selector: int) -> Dictionary:
	var source_name := "def_main.mes" if selector == 3 else "liblary.lib"
	var replacement_name := "def_test.mes" if selector == 3 else "libtest.lib"
	var role := "definition_bootstrap" if selector == 3 else "library_bootstrap"
	var envelope_prefix := ("0d08ff02%02xff01" % selector).hex_decode()
	var envelope_suffix := "0000".hex_decode()
	var source_envelope := _join(envelope_prefix, source_name.to_ascii_buffer(), envelope_suffix)
	var output_envelope := _join(envelope_prefix, replacement_name.to_ascii_buffer(), envelope_suffix)
	var leading := PackedByteArray() if typed else "0be0".hex_decode()
	var trailing := PackedByteArray() if typed else "1900".hex_decode()
	var source_code := leading + source_envelope + trailing
	var output_code := leading + output_envelope + trailing
	var envelope_start := leading.size()
	var envelope_end := envelope_start + source_envelope.size()
	var name_start := envelope_start + envelope_prefix.size()
	var name_end := name_start + source_name.length()
	var preamble := PackedByteArray()
	preamble.resize(8)
	preamble.encode_u32(0, 1)
	preamble.encode_u32(4, 0)
	var source := preamble + source_code
	var output := preamble + output_code
	var source_identity := {
		"archive": "mes.arc", "entry": "START.MES", "archive_sha256": "a".repeat(64),
	}
	var output_document := MesContainerScript.new().parse(output, source_identity)
	var analysis := MesAnalysisScript.new().build(output_document)
	var owner_start := envelope_start
	var owner_end := envelope_end
	var owner_kind := "statement"
	var reference_boundary := "strict_indexed"
	if not typed:
		var owners: Array[Dictionary] = []
		for untyped_owner in analysis.get("opaque_boundaries", []):
			var owner: Dictionary = untyped_owner
			if int(owner.source_offset) <= envelope_start and int(owner.end_offset) >= envelope_end:
				owners.append(owner)
		if owners.size() == 1:
			owner_start = int(owners[0].source_offset)
			owner_end = int(owners[0].end_offset)
		owner_kind = "opaque"
		reference_boundary = "bounded_envelope_scan"
	var source_summary := _summary(source, preamble.size())
	var output_summary := _summary(output, preamble.size())
	var typed_count := int((analysis.instructions as Array).size())
	var opaque_count := int((analysis.get("opaque_boundaries", []) as Array).size())
	var audit := {
		"ok": true,
		"schema": "kakyu_mes_inline_script_name_compile_audit/v1",
		"producer": {
			"implementation": "python_phase6_inline_script_name_compiler",
			"contract": "kakyu_mes_inline_script_name_compile_audit/v1",
		},
		"compatibility": ReopenScript.COMPATIBILITY.duplicate(true),
		"source_identity": source_identity,
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"inline_script_name_plan_sha256": "3".repeat(64),
		},
		"source": source_summary,
		"output": output_summary,
		"operation": {
			"kind": "replace_inline_script_name",
			"source_offset": envelope_start,
			"reference_id": "resource_00000000",
			"source_name": source_name,
			"replacement_name": replacement_name,
			"execution_selector": selector,
			"execution_role": role,
		},
		"target": {
			"node_id": "linear_%08x" % owner_start,
			"region_id": "entry_0000",
			"owner_kind": owner_kind,
			"owner_start": owner_start,
			"owner_end": owner_end,
			"owner_bytes": owner_end - owner_start,
			"envelope_start": envelope_start,
			"envelope_end": envelope_end,
			"name_start": name_start,
			"name_end": name_end,
			"name_bytes": source_name.length(),
			"prefix_bytes": envelope_prefix.size(),
			"suffix_bytes": envelope_suffix.size(),
			"source_owner_sha256": _sha256(source_code.slice(owner_start, owner_end)),
			"replacement_owner_sha256": _sha256(output_code.slice(owner_start, owner_end)),
			"source_envelope_sha256": _sha256(source_envelope),
			"replacement_envelope_sha256": _sha256(output_envelope),
			"source_name_sha256": _sha256(source_name.to_ascii_buffer()),
			"replacement_name_sha256": _sha256(replacement_name.to_ascii_buffer()),
			"prefix_sha256": _sha256(envelope_prefix),
			"suffix_sha256": _sha256(envelope_suffix),
			"reference_boundary": reference_boundary,
		},
		"coverage": {
			"region_count": 2,
			"node_count": typed_count + opaque_count,
			"typed_node_count": typed_count,
			"opaque_node_count": opaque_count,
			"code_bytes": output_code.size(),
		},
		"invariants": {
			"plan_ready": true,
			"output_reopened": true,
			"container_size_preserved": true,
			"entry_count_preserved": true,
			"code_offset_preserved": true,
			"code_size_preserved": true,
			"address_table_preserved": true,
			"preamble_preserved": true,
			"code_prefix_preserved": true,
			"code_suffix_preserved": true,
			"replacement_envelope_exact": true,
			"owner_prefix_preserved": true,
			"owner_suffix_preserved": true,
			"selector_prefix_preserved": true,
			"double_nul_suffix_preserved": true,
			"only_name_range_changed": true,
			"opaque_owner_boundary_preserved": true,
			"source_container_not_modified": true,
		},
	}
	_rehash(audit)
	return {"source": source, "output": output, "audit": audit}


func _summary(payload: PackedByteArray, code_offset: int) -> Dictionary:
	return {
		"size": payload.size(),
		"entry_count": 1,
		"code_offset": code_offset,
		"code_size": payload.size() - code_offset,
		"entry_sha256": _sha256(payload),
		"bytecode_sha256": _sha256(payload.slice(code_offset)),
		"preamble_sha256": _sha256(payload.slice(0, code_offset)),
		"address_table_sha256": _sha256(payload.slice(4, code_offset)),
	}


func _join(prefix: PackedByteArray, middle: PackedByteArray, suffix: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.append_array(prefix)
	result.append_array(middle)
	result.append_array(suffix)
	return result


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = ReopenScript.new().fingerprint(document)


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
