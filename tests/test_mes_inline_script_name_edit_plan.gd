extends "res://tests/test_case.gd"

const PlanScript := preload("res://content_core/mes_inline_script_name_edit_plan.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")


func _ready() -> void:
	var validator := PlanScript.new()
	var source := _fixture(false, 2)
	var valid := validator.validate(source)
	_check(
		valid.ok
		and valid.envelope_start == 0x014C
		and valid.name_start == 0x0153
		and valid.owner_kind == "opaque"
		and valid.reference_boundary == "bounded_envelope_scan"
		and valid.execution_selector == 2
		and valid.source_name == "liblary.lib"
		and valid.replacement_name == "libtest.lib"
		and not valid.mes_bytes,
		"bounded inline library target plan validates"
	)
	var transported = JSON.parse_string(JSON.stringify(source))
	_check(
		transported is Dictionary and validator.validate(transported).ok,
		"inline script plan survives JSON number transport"
	)
	_check(
		validator.validate(_fixture(true, 3)).ok,
		"strict typed definition target plan validates"
	)
	var changed_selector := source.duplicate(true)
	changed_selector.target.execution_selector = 3
	changed_selector.target.execution_role = "definition_bootstrap"
	changed_selector.target.extension = "mes"
	_rehash(changed_selector)
	_check(not validator.validate(changed_selector).ok, "selector bytes remain fixed")
	var changed_boundary := source.duplicate(true)
	changed_boundary.target.reference_boundary = "strict_indexed"
	_rehash(changed_boundary)
	_check(not validator.validate(changed_boundary).ok, "owner and reference boundary remain paired")
	var changed_suffix := source.duplicate(true)
	changed_suffix.target.suffix_raw_hex = "0001"
	changed_suffix.target.suffix_raw_sha256 = _sha256("0001".hex_decode())
	_rebuild_envelopes(changed_suffix)
	_rehash(changed_suffix)
	_check(not validator.validate(changed_suffix).ok, "double-NUL suffix remains fixed")
	var changed_extension := source.duplicate(true)
	_set_replacement(changed_extension, "libtest.mes")
	_rehash(changed_extension)
	_check(not validator.validate(changed_extension).ok, "selector extension remains fixed")
	var fractional := source.duplicate(true)
	fractional.target.name_start = 339.5
	_rehash(fractional)
	_check(not validator.validate(fractional).ok, "fractional coordinates are rejected")
	var unknown := source.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(not validator.validate(unknown).ok, "unknown fields are rejected")
	var stale := source.duplicate(true)
	stale.replacement.source_name = "libxary.lib"
	_check(not validator.validate(stale).ok, "stale plan fingerprint is rejected")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _fixture(typed: bool, selector: int) -> Dictionary:
	var form: Dictionary = PlanScript.SUPPORTED_SELECTORS[str(selector)]
	var source_name := "def_main.mes" if selector == 3 else "liblary.lib"
	var replacement_name := "def_test.mes" if selector == 3 else "libtest.lib"
	var prefix := ("0d08ff02%02xff01" % selector).hex_decode()
	var suffix := "0000".hex_decode()
	var source_raw := source_name.to_ascii_buffer()
	var replacement_raw := replacement_name.to_ascii_buffer()
	var source_envelope := _join(prefix, source_raw, suffix)
	var output_envelope := _join(prefix, replacement_raw, suffix)
	var envelope_start := 0x014C
	var owner_start := envelope_start if typed else 0x00BE
	var owner_end := envelope_start + source_envelope.size() if typed else 0x0BEB
	var owner_kind := "statement" if typed else "opaque"
	var document := {
		"ok": true,
		"schema": "kakyu_mes_inline_script_name_edit_plan/v1",
		"producer": {
			"implementation": "python_phase6_inline_script_name_edit_planner",
			"contract": "kakyu_mes_inline_script_name_edit_plan/v1",
		},
		"compatibility": PlanScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc", "entry": "START.MES",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
		},
		"operation": {
			"kind": "replace_inline_script_name",
			"source_offset": envelope_start,
			"owner_raw_sha256": "3".repeat(64),
			"reference_id": "resource_00000000",
			"name": replacement_name,
		},
		"target": {
			"node_id": "linear_%08x" % owner_start,
			"region_id": "entry_0000",
			"owner_kind": owner_kind,
			"owner_start": owner_start,
			"owner_end": owner_end,
			"owner_raw_sha256": "3".repeat(64),
			"op": "inline_script_execution",
			"command_id": 13,
			"envelope_start": envelope_start,
			"envelope_end": envelope_start + source_envelope.size(),
			"envelope_raw_hex": source_envelope.hex_encode(),
			"envelope_raw_sha256": _sha256(source_envelope),
			"reference_id": "resource_00000000",
			"reference_boundary": "strict_indexed" if typed else "bounded_envelope_scan",
			"resource_kind": "mes_script",
			"archive_candidates": ["mes.arc"],
			"source_name": source_name,
			"normalized_name": source_name.to_upper(),
			"extension": str(form.extension),
			"execution_selector": selector,
			"execution_role": str(form.role),
			"native_context_restore": "confirmed",
			"tool_execution_semantics": "not_executed",
			"name_start": envelope_start + prefix.size(),
			"name_end": envelope_start + prefix.size() + source_raw.size(),
			"name_raw_hex": source_raw.hex_encode(),
			"name_raw_sha256": _sha256(source_raw),
			"prefix_raw_hex": prefix.hex_encode(),
			"prefix_raw_sha256": _sha256(prefix),
			"suffix_raw_hex": suffix.hex_encode(),
			"suffix_raw_sha256": _sha256(suffix),
		},
		"replacement": {
			"source_name": replacement_name,
			"normalized_name": replacement_name.to_upper(),
			"extension": str(form.extension),
			"name_raw_hex": replacement_raw.hex_encode(),
			"name_raw_sha256": _sha256(replacement_raw),
			"envelope_raw_hex": output_envelope.hex_encode(),
			"envelope_raw_sha256": _sha256(output_envelope),
		},
		"assembly_ready": true,
		"invariants": PlanScript.INVARIANTS.duplicate(true),
	}
	_rehash(document)
	return document


func _set_replacement(document: Dictionary, value: String) -> void:
	var raw := value.to_ascii_buffer()
	document.operation.name = value
	document.replacement.source_name = value
	document.replacement.normalized_name = value.to_upper()
	document.replacement.extension = value.get_extension().to_lower()
	document.replacement.name_raw_hex = raw.hex_encode()
	document.replacement.name_raw_sha256 = _sha256(raw)
	_rebuild_envelopes(document)


func _rebuild_envelopes(document: Dictionary) -> void:
	var source := _join(
		str(document.target.prefix_raw_hex).hex_decode(),
		str(document.target.name_raw_hex).hex_decode(),
		str(document.target.suffix_raw_hex).hex_decode()
	)
	var output := _join(
		str(document.target.prefix_raw_hex).hex_decode(),
		str(document.replacement.name_raw_hex).hex_decode(),
		str(document.target.suffix_raw_hex).hex_decode()
	)
	document.target.envelope_raw_hex = source.hex_encode()
	document.target.envelope_raw_sha256 = _sha256(source)
	document.replacement.envelope_raw_hex = output.hex_encode()
	document.replacement.envelope_raw_sha256 = _sha256(output)


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
