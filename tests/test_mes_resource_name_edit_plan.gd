extends "res://tests/test_case.gd"

const PlanScript := preload("res://content_core/mes_resource_name_edit_plan.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")


func _ready() -> void:
	var validator := PlanScript.new()
	var source := _fixture("mmo_resource_marker")
	var valid := validator.validate(source)
	_check(
		valid.ok
		and valid.instruction_start == 0x018D
		and valid.name_start == 0x0191
		and valid.resource_kind == "mmo"
		and valid.source_name == "w.mmo"
		and valid.replacement_name == "x.mmo"
		and not valid.mes_bytes,
		"exact MMO resource name edit plan validates"
	)
	var transported = JSON.parse_string(JSON.stringify(source))
	_check(
		transported is Dictionary and validator.validate(transported).ok,
		"resource name edit plan survives JSON number transport"
	)
	_check(
		validator.validate(_fixture("ax_resource_marker")).ok,
		"AX resource name plan preserves its selector envelope"
	)
	_check(
		validator.validate(_fixture("voice_marker")).ok,
		"voice resource name plan preserves its selector envelope"
	)
	var changed_prefix := _fixture("ax_resource_marker")
	changed_prefix.target.prefix_raw_hex = "0d08ff0201ff01"
	changed_prefix.target.prefix_raw_sha256 = _sha256(
		str(changed_prefix.target.prefix_raw_hex).hex_decode()
	)
	_rebuild_instruction(changed_prefix)
	_rehash(changed_prefix)
	_check(
		not validator.validate(changed_prefix).ok,
		"numeric selector bytes remain fixed"
	)
	var changed_suffix := source.duplicate(true)
	changed_suffix.target.suffix_raw_hex = "0001"
	changed_suffix.target.suffix_raw_sha256 = _sha256("0001".hex_decode())
	_rebuild_instruction(changed_suffix)
	_rehash(changed_suffix)
	_check(
		not validator.validate(changed_suffix).ok,
		"resource terminator bytes remain fixed"
	)
	var changed_extension := source.duplicate(true)
	_set_replacement_name(changed_extension, "x.ogg")
	_rehash(changed_extension)
	_check(
		not validator.validate(changed_extension).ok,
		"resource extension remains fixed"
	)
	var fractional := source.duplicate(true)
	fractional.target.name_start = 400.5
	_rehash(fractional)
	_check(
		not validator.validate(fractional).ok,
		"resource name edit rejects fractional JSON coordinates"
	)
	var scan_only := source.duplicate(true)
	scan_only.target.reference_boundary = "bounded_envelope_scan"
	_rehash(scan_only)
	_check(
		not validator.validate(scan_only).ok,
		"scan-only resource references remain rejected"
	)
	var unknown := source.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not validator.validate(unknown).ok,
		"resource name edit rejects unknown fields"
	)
	var stale := source.duplicate(true)
	stale.replacement.source_name = "z.mmo"
	_check(
		not validator.validate(stale).ok,
		"resource name edit rejects a stale fingerprint"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _fixture(op: String) -> Dictionary:
	var form: Dictionary = PlanScript.SUPPORTED_RESOURCES[op]
	var source_name := "w.mmo"
	var replacement_name := "x.mmo"
	var source_normalized := "w.mmo"
	var replacement_normalized := "x.mmo"
	var archives := ["mmo.arc"]
	if op == "ax_resource_marker":
		source_name = "w.ax"
		replacement_name = "q.ax"
		source_normalized = "W.AX"
		replacement_normalized = "Q.AX"
		archives = ["data.arc"]
	elif op == "voice_marker":
		source_name = "j0009.ogg"
		replacement_name = "k0009.ogg"
		source_normalized = "J0009.OGG"
		replacement_normalized = "K0009.OGG"
		archives = ["voice.arc", "tina1.arc", "tina2.arc"]
	var prefix := str(form.prefix_hex).hex_decode()
	var suffix := str(form.suffix_hex).hex_decode()
	var source_raw := source_name.to_ascii_buffer()
	var replacement_raw := replacement_name.to_ascii_buffer()
	var source_instruction := _join(prefix, source_raw, suffix)
	var output_instruction := _join(prefix, replacement_raw, suffix)
	var instruction_start := 0x018D
	var name_start := instruction_start + prefix.size()
	var document := {
		"ok": true,
		"schema": "kakyu_mes_resource_name_edit_plan/v1",
		"producer": {
			"implementation": "python_phase6_resource_name_edit_planner",
			"contract": "kakyu_mes_resource_name_edit_plan/v1",
		},
		"compatibility": PlanScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "03C.MES",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
		},
		"operation": {
			"kind": "replace_resource_name",
			"source_offset": instruction_start,
			"instruction_raw_sha256": _sha256(source_instruction),
			"reference_id": "resource_00000000",
			"name": replacement_name,
		},
		"target": {
			"node_id": "linear_0000018d",
			"region_id": "entry_0000",
			"op": op,
			"command_id": form.command_id,
			"instruction_start": instruction_start,
			"instruction_end": instruction_start + source_instruction.size(),
			"instruction_raw_hex": source_instruction.hex_encode(),
			"instruction_raw_sha256": _sha256(source_instruction),
			"reference_id": "resource_00000000",
			"reference_boundary": "strict_indexed",
			"resource_kind": form.resource_kind,
			"archive_candidates": archives,
			"operand_resource_kind": form.operand_resource_kind,
			"source_name": source_name,
			"normalized_name": source_normalized,
			"extension": source_name.get_extension().to_lower(),
			"name_start": name_start,
			"name_end": name_start + source_raw.size(),
			"name_raw_hex": source_raw.hex_encode(),
			"name_raw_sha256": _sha256(source_raw),
			"prefix_raw_hex": prefix.hex_encode(),
			"prefix_raw_sha256": _sha256(prefix),
			"suffix_raw_hex": suffix.hex_encode(),
			"suffix_raw_sha256": _sha256(suffix),
		},
		"replacement": {
			"source_name": replacement_name,
			"normalized_name": replacement_normalized,
			"extension": replacement_name.get_extension().to_lower(),
			"name_raw_hex": replacement_raw.hex_encode(),
			"name_raw_sha256": _sha256(replacement_raw),
			"instruction_raw_hex": output_instruction.hex_encode(),
			"instruction_raw_sha256": _sha256(output_instruction),
		},
		"assembly_ready": true,
		"invariants": PlanScript.INVARIANTS.duplicate(true),
	}
	_rehash(document)
	return document


func _set_replacement_name(document: Dictionary, value: String) -> void:
	var raw := value.to_ascii_buffer()
	document.operation.name = value
	document.replacement.source_name = value
	document.replacement.normalized_name = value
	document.replacement.extension = value.get_extension().to_lower()
	document.replacement.name_raw_hex = raw.hex_encode()
	document.replacement.name_raw_sha256 = _sha256(raw)
	_rebuild_instruction(document)


func _rebuild_instruction(document: Dictionary) -> void:
	var source_instruction := _join(
		str(document.target.prefix_raw_hex).hex_decode(),
		str(document.target.name_raw_hex).hex_decode(),
		str(document.target.suffix_raw_hex).hex_decode()
	)
	var output_instruction := _join(
		str(document.target.prefix_raw_hex).hex_decode(),
		str(document.replacement.name_raw_hex).hex_decode(),
		str(document.target.suffix_raw_hex).hex_decode()
	)
	document.target.instruction_raw_hex = source_instruction.hex_encode()
	document.target.instruction_raw_sha256 = _sha256(source_instruction)
	document.operation.instruction_raw_sha256 = _sha256(source_instruction)
	document.replacement.instruction_raw_hex = output_instruction.hex_encode()
	document.replacement.instruction_raw_sha256 = _sha256(output_instruction)


func _join(prefix: PackedByteArray, middle: PackedByteArray, suffix: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.append_array(prefix)
	result.append_array(middle)
	result.append_array(suffix)
	return result


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = FingerprintScript.new().fingerprint(document)


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
