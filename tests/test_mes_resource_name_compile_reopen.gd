extends "res://tests/test_case.gd"

const ReopenScript := preload("res://content_core/mes_resource_name_compile_reopen.gd")


func _ready() -> void:
	var reopener := ReopenScript.new()
	var fixture := _fixture("mmo")
	var result := reopener.audit(fixture.output, fixture.audit)
	_check(
		result.ok
		and result.edited_resource.op == "mmo_resource_marker"
		and result.edited_resource.resource_kind == "mmo"
		and result.edited_resource.source_name == "w.mmo"
		and result.edited_resource.replacement_name == "x.mmo"
		and result.edited_resource.reference_boundary == "strict_indexed"
		and result.coverage.node_count == 1,
		"same-length MMO resource edit reopens through Phase 1-4"
	)
	var transported = JSON.parse_string(JSON.stringify(fixture.audit))
	_check(
		transported is Dictionary and reopener.audit(fixture.output, transported).ok,
		"resource name compile audit survives JSON number transport"
	)
	var ax_fixture := _fixture("ax")
	var ax_result := reopener.audit(ax_fixture.output, ax_fixture.audit)
	_check(
		ax_result.ok
		and ax_result.edited_resource.op == "ax_resource_marker"
		and ax_result.edited_resource.normalized_name == "Q.AX"
		and ax_result.coverage.node_count == 1,
		"same-length AX resource edit reopens through Phase 1-4"
	)
	var changed_payload: PackedByteArray = fixture.output.duplicate()
	changed_payload[12] = 0x79
	_check(
		not reopener.audit(changed_payload, fixture.audit).ok,
		"resource name reopen rejects output bytes that differ from the audit"
	)
	var changed_name: Dictionary = fixture.audit.duplicate(true)
	changed_name.operation.replacement_name = "y.mmo"
	_rehash(changed_name)
	_check(
		not reopener.audit(fixture.output, changed_name).ok,
		"resource name reopen rejects a name that differs from the decoded operand"
	)
	var changed_kind: Dictionary = fixture.audit.duplicate(true)
	changed_kind.operation.resource_kind = "ax"
	_rehash(changed_kind)
	_check(
		not reopener.audit(fixture.output, changed_kind).ok,
		"resource name reopen rejects a resource kind that differs from the marker"
	)
	var fractional: Dictionary = fixture.audit.duplicate(true)
	fractional.target.name_start = 4.5
	_rehash(fractional)
	_check(
		not reopener.audit(fixture.output, fractional).ok,
		"resource name compile audit rejects fractional JSON coordinates"
	)
	var unknown: Dictionary = fixture.audit.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not reopener.audit(fixture.output, unknown).ok,
		"resource name compile audit rejects unknown fields"
	)
	var stale: Dictionary = fixture.audit.duplicate(true)
	stale.output.entry_sha256 = "0".repeat(64)
	_check(
		not reopener.audit(fixture.output, stale).ok,
		"resource name compile audit rejects a stale fingerprint"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _fixture(resource_kind: String) -> Dictionary:
	var source_name := "w.mmo"
	var replacement_name := "x.mmo"
	var op := "mmo_resource_marker"
	# The MMO marker is the whole system call 0D 09 FF 01 <name> 00 00 - one
	# record, not a separator followed by a 0x09 record.
	var marker_prefix := "0d09ff01".hex_decode()
	var marker_suffix := "0000".hex_decode()
	var leading := PackedByteArray()
	var instruction_start := 0
	var typed_nodes := 1
	if resource_kind == "ax":
		source_name = "w.ax"
		replacement_name = "q.ax"
		op = "ax_resource_marker"
		marker_prefix = "0d08ff0200ff01".hex_decode()
		marker_suffix = "000202f900ff00".hex_decode()
		leading = PackedByteArray()
		instruction_start = 0
		typed_nodes = 1
	var source_instruction := _join(
		marker_prefix, source_name.to_ascii_buffer(), marker_suffix
	)
	var output_instruction := _join(
		marker_prefix, replacement_name.to_ascii_buffer(), marker_suffix
	)
	var source_code := leading + source_instruction
	var output_code := leading + output_instruction
	var instruction_end := instruction_start + source_instruction.size()
	var name_start := instruction_start + marker_prefix.size()
	var name_end := name_start + source_name.length()
	var preamble := PackedByteArray()
	preamble.resize(8)
	preamble.encode_u32(0, 1)
	preamble.encode_u32(4, 0)
	var source := preamble + source_code
	var output := preamble + output_code
	var source_summary := _summary(source, preamble.size())
	var output_summary := _summary(output, preamble.size())
	var audit := {
		"ok": true,
		"schema": "kakyu_mes_resource_name_compile_audit/v1",
		"producer": {
			"implementation": "python_phase6_resource_name_compiler",
			"contract": "kakyu_mes_resource_name_compile_audit/v1",
		},
		"compatibility": ReopenScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "RESOURCE.MES",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"resource_name_plan_sha256": "3".repeat(64),
		},
		"source": source_summary,
		"output": output_summary,
		"operation": {
			"kind": "replace_resource_name",
			"source_offset": instruction_start,
			"reference_id": "resource_00000000",
			"resource_kind": resource_kind,
			"source_name": source_name,
			"replacement_name": replacement_name,
		},
		"target": {
			"node_id": "linear_%08x" % instruction_start,
			"region_id": "entry_0000",
			"op": op,
			"instruction_start": instruction_start,
			"instruction_end": instruction_end,
			"name_start": name_start,
			"name_end": name_end,
			"name_bytes": source_name.length(),
			"prefix_bytes": marker_prefix.size(),
			"suffix_bytes": marker_suffix.size(),
			"source_instruction_sha256": _sha256(source_instruction),
			"replacement_instruction_sha256": _sha256(output_instruction),
			"source_name_sha256": _sha256(source_name.to_ascii_buffer()),
			"replacement_name_sha256": _sha256(replacement_name.to_ascii_buffer()),
			"prefix_sha256": _sha256(marker_prefix),
			"suffix_sha256": _sha256(marker_suffix),
			"reference_boundary": "strict_indexed",
		},
		"coverage": {
			"region_count": 2,
			"node_count": typed_nodes,
			"typed_node_count": typed_nodes,
			"opaque_node_count": 0,
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
			"replacement_instruction_exact": true,
			"code_suffix_preserved": true,
			"marker_prefix_preserved": true,
			"marker_suffix_preserved": true,
			"only_name_range_changed": true,
			"source_container_not_modified": true,
		},
	}
	_rehash(audit)
	return {"source": source, "output": output, "audit": audit}


func _summary(payload: PackedByteArray, code_offset: int) -> Dictionary:
	var preamble := payload.slice(0, code_offset)
	return {
		"size": payload.size(),
		"entry_count": 1,
		"code_offset": code_offset,
		"code_size": payload.size() - code_offset,
		"entry_sha256": _sha256(payload),
		"bytecode_sha256": _sha256(payload.slice(code_offset)),
		"preamble_sha256": _sha256(preamble),
		"address_table_sha256": _sha256(preamble),
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
