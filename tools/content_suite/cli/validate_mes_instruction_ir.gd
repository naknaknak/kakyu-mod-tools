extends SceneTree

# Independent GDScript oracle for small, authored Python parity fixtures.
# Input is a JSON array of {name, hex, start?, end?, mode?, max_instructions?}.
# Modes: instruction (decode_at), resource_marker (decode_resource_marker_at),
# region (decode_region_aligned),
# structural_instruction (decode_at_structural), structural_region
# (decode_region_structural_aligned), typed_ir, record_alignment, references and
# capability_report (the last four use a complete synthetic MES container).
# capability_report_aggregate calls only the private aggregation helper with
# supplied component dictionaries; it does not validate evidence or containers.
# full_handoff returns the complete signed build result, including rejections.
# transport decodes explicit typed descriptors before checking canonical bytes.
# Decoder rejection is a result to compare, not an oracle execution failure.

const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const AnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const HandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const AlignmentScript := preload("res://content_core/mes_record_alignment_audit.gd")
const SCHEMA := "kakyu_mes_instruction_ir_oracle/v1"
const OUTPUT_PREFIX := "MES_INSTRUCTION_IR_ORACLE "


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: validate_mes_instruction_ir.gd <synthetic-fixtures.json>")
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(arguments[0])) != OK:
		_fail("Could not parse synthetic fixture JSON: %s" % parser.get_error_message())
		return
	if not parser.data is Array:
		_fail("Synthetic fixtures must be a JSON array.")
		return
	var hexadecimal := RegEx.new()
	hexadecimal.compile("^(?:[0-9a-fA-F]{2})*$")
	var decoder := DecoderScript.new()
	var container_parser := ContainerScript.new()
	var analysis_builder := AnalysisScript.new()
	var handoff_builder := HandoffScript.new()
	var alignment_auditor := AlignmentScript.new()
	var results: Array[Dictionary] = []
	var names := {}
	for untyped_fixture in parser.data:
		if not untyped_fixture is Dictionary:
			_fail("Every synthetic fixture must be an object.")
			return
		var fixture: Dictionary = untyped_fixture
		var fixture_name := str(fixture.get("name", ""))
		if fixture_name.is_empty() or names.has(fixture_name):
			_fail("Synthetic fixture names must be nonempty and unique.")
			return
		names[fixture_name] = true
		if not fixture.get("hex") is String or hexadecimal.search(str(fixture.hex)) == null:
			_fail("Fixture %s requires complete hexadecimal bytes." % fixture_name)
			return
		var code: PackedByteArray = str(fixture.hex).hex_decode()
		var start := int(fixture.get("start", 0))
		var end := int(fixture.get("end", code.size()))
		var result: Dictionary
		match str(fixture.get("mode", "instruction")):
			"transport":
				var value: Variant = _oracle_value(fixture.get("value"))
				var validation: Dictionary = handoff_builder._validate_transport(value, "handoff")
				result = {"validation": validation, "json_utf8_hex": ""}
				if validation.get("ok", false):
					result.json_utf8_hex = JSON.stringify(
						handoff_builder._normalize(value), "", true, true
					).to_utf8_buffer().hex_encode()
			"full_handoff":
				var document := container_parser.parse(code, _oracle_value(fixture.get("source", {})))
				if not document.get("ok", false):
					result = document
				else:
					result = handoff_builder.build(
						document, analysis_builder.build(document),
						_oracle_value(fixture.get("graphs", [])),
						_oracle_value(fixture.get("call_evidence", [])),
						_oracle_value(fixture.get("trace_evidence", []))
					)
			"instruction":
				result = decoder.decode_at(code, start, end)
			"resource_marker":
				result = decoder.decode_resource_marker_at(code, start, end)
			"structural_instruction":
				result = decoder.decode_at_structural(code, start, end)
			"region":
				result = decoder.decode_region_aligned(
					code, start, end, int(fixture.get("max_instructions", 100000))
				)
			"structural_region":
				result = decoder.decode_region_structural_aligned(
					code, start, end, int(fixture.get("max_instructions", 100000))
				)
			"capability_report_aggregate":
				var typed_ir: Dictionary = fixture.get("typed_ir", {})
				var references: Dictionary = fixture.get("references", {})
				var analysis := {
					"instructions": typed_ir.get("instructions", []),
					"opaque_boundaries": typed_ir.get("opaque_boundaries", []),
					"code_references": references.get("code", []),
					"resource_references": references.get("resources", []),
				}
				result = handoff_builder._capability_report(
					analysis, fixture.get("alignment", {}), fixture.get("graphs", []),
					fixture.get("call_evidence", []), fixture.get("trace_evidence", [])
				)
			"typed_ir", "record_alignment", "references", "capability_report":
				var document := container_parser.parse(code)
				if not document.get("ok", false):
					_fail("Fixture %s has an invalid synthetic MES container." % fixture_name)
					return
				if fixture.mode == "record_alignment":
					result = alignment_auditor.audit(document)
				else:
					var handoff := handoff_builder.build(
						document, analysis_builder.build(document), fixture.get("graphs", []),
						fixture.get("call_evidence", []), fixture.get("trace_evidence", [])
					)
					if not handoff.get("ok", false):
						_fail("Fixture %s could not produce a handoff: %s" % [fixture_name, handoff.get("error", "")])
						return
					match fixture.mode:
						"references":
							result = handoff.references
						"capability_report":
							result = handoff.capability_report
						_:
							result = handoff.typed_ir
			_:
				_fail("Fixture %s has an unsupported mode." % fixture_name)
				return
		# Use the producer's normalization itself; a copied serializer could hide
		# the packed-byte representation difference this oracle needs to detect.
		results.append({"name": fixture_name, "result": handoff_builder._normalize(result)})
	print(OUTPUT_PREFIX + JSON.stringify({"schema": SCHEMA, "results": results}, "", true, true))
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(2)


func _oracle_value(value: Variant) -> Variant:
	# JSON numbers pass through floating-point parsing. Test-only descriptors
	# recover the exact authored Godot type before exercising the real producer.
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.has("$oracle_type"):
			match str(dictionary["$oracle_type"]):
				"int64":
					return int(str(dictionary.value))
				"float64_bits":
					return str(dictionary.value).hex_decode().decode_double(0)
				"packed_bytes":
					return str(dictionary.value).hex_decode()
				"vector2":
					return Vector2(float(dictionary.value[0]), float(dictionary.value[1]))
				"dictionary":
					var mapped := {}
					for pair in dictionary.value:
						mapped[_oracle_value(pair[0])] = _oracle_value(pair[1])
					return mapped
				_:
					_fail("Unsupported authored oracle value descriptor.")
					return null
		var mapped := {}
		for key in dictionary:
			mapped[key] = _oracle_value(dictionary[key])
		return mapped
	if value is Array:
		var mapped: Array = []
		for child in value:
			mapped.append(_oracle_value(child))
		return mapped
	return value
