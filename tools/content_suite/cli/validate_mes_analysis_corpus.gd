extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")
const ContractValues := preload("res://content_core/contract_values.gd")


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: validate_mes_analysis_corpus.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		push_error(reader.last_error)
		quit(1)
		return
	var source_archive_sha := reader.get_archive_fingerprint()
	var parser := MesContainerScript.new()
	var builder := MesAnalysisScript.new()
	var cp932 := Cp932CodecScript.new()
	var entry_count := 0
	var instruction_count := 0
	var message_count := 0
	var code_reference_count := 0
	var state_reference_count := 0
	var resource_reference_count := 0
	var resource_reference_kinds := {}
	var resource_reference_boundaries := {}
	var failures: Array[String] = []
	var incomplete_entries := 0
	var diagnostic_count := 0
	var diagnostic_samples: Array[String] = []
	var cp932_failures := 0
	var cp932_failure_samples: Array[String] = []
	var native_text_byte_failures := 0
	var native_text_byte_samples: Array[String] = []
	var native_text_byte_leads := {}
	var native_stream_tokens := 0
	var native_single_stream_tokens := 0
	var native_double_stream_tokens := 0
	var native_double_projection_matches := 0
	var native_double_projection_mismatches := 0
	var native_stream_stop_reasons := {}
	var native_double_ops := {}
	var native_double_mismatch_ops := {}
	var native_double_deferred_bytes := {}
	var native_double_mismatch_characters := {}
	var native_stream_mismatch_samples: Array[String] = []
	var aligned_native_payloads := 0
	var aligned_native_payload_bytes := 0
	var aligned_native_payload_samples: Array[String] = []
	var opaque_boundaries := 0
	var opaque_boundary_bytes := 0
	var message_ownership_failures := 0
	var native_payload_message_failures := 0
	var expression_message_failures := 0
	var opaque_message_failures := 0
	var negative_space_samples: Array[String] = []
	for entry in reader.get_entries():
		var extension := str(entry.name).get_extension().to_lower()
		if extension not in ["mes", "lib"]:
			continue
		entry_count += 1
		var document := parser.parse(reader.read_entry(str(entry.name)), {
			"archive": reader.archive_path.replace("\\", "/").get_file(),
			"entry": str(entry.name),
		})
		if not document.ok:
			failures.append("%s container: %s" % [entry.name, document.error])
			continue
		var analysis := builder.build(document)
		if not analysis.ok:
			failures.append("%s analysis: %s" % [entry.name, analysis.error])
			continue
		instruction_count += int(analysis.instruction_count)
		message_count += int(analysis.message_count)
		var instructions_by_offset := {}
		var native_payload_spans: Array[Dictionary] = []
		var expression_spans: Array[Dictionary] = []
		for untyped_instruction in analysis.instructions:
			var instruction: Dictionary = untyped_instruction
			instructions_by_offset[int(instruction.source_offset)] = instruction
			_collect_expression_spans(instruction.get("operands", []), expression_spans)
			if instruction.has("native_payload_boundary"):
				aligned_native_payloads += 1
				aligned_native_payload_bytes += int(instruction.native_payload_byte_length)
				if aligned_native_payload_samples.size() < 12:
					aligned_native_payload_samples.append("%s 0x%X..0x%X payload=0x%X..0x%X" % [
						entry.name,
						int(instruction.source_offset),
						int(instruction.end_offset),
						int(instruction.native_payload_start_offset),
						int(instruction.native_payload_end_offset),
					])
				native_payload_spans.append({
					"source_offset": int(instruction.native_payload_start_offset),
					"end_offset": int(instruction.native_payload_end_offset),
				})
			if not instruction.has("native_stream_probe"):
				continue
			native_stream_tokens += 1
			var family := str(instruction.get("native_handler_family", ""))
			var probe: Dictionary = instruction.native_stream_probe
			var stop_reason := str(probe.get("stop_reason", "unknown"))
			native_stream_stop_reasons[stop_reason] = int(native_stream_stop_reasons.get(stop_reason, 0)) + 1
			if family == "double_byte_character_stream_presentation":
				native_double_stream_tokens += 1
				var op := str(instruction.op)
				native_double_ops[op] = int(native_double_ops.get(op, 0)) + 1
				if bool(instruction.get("native_stream_projection_match", false)):
					native_double_projection_matches += 1
				else:
					native_double_projection_mismatches += 1
					native_double_mismatch_ops[op] = int(native_double_mismatch_ops.get(op, 0)) + 1
					var character_count := int(probe.get("character_count", -1))
					native_double_mismatch_characters[character_count] = int(
						native_double_mismatch_characters.get(character_count, 0)
					) + 1
					var stop_offset := int(probe.get("stop_offset", -1))
					var bytecode: PackedByteArray = document.bytecode
					if stop_offset >= 0 and stop_offset < bytecode.size():
						var deferred_byte := int(bytecode[stop_offset])
						native_double_deferred_bytes[deferred_byte] = int(
							native_double_deferred_bytes.get(deferred_byte, 0)
						) + 1
					if native_stream_mismatch_samples.size() < 12:
						native_stream_mismatch_samples.append("%s 0x%X %s stop=0x%X %s" % [
							entry.name,
							int(instruction.source_offset),
							str(instruction.op),
							int(probe.get("stop_offset", -1)),
							stop_reason,
						])
			else:
				native_single_stream_tokens += 1
		var opaque_spans: Array[Dictionary] = []
		for untyped_boundary in analysis.get("opaque_boundaries", []):
			var boundary: Dictionary = untyped_boundary
			var opaque_start := int(boundary.get("source_offset", -1))
			var opaque_end := int(boundary.get("end_offset", -1))
			var opaque_bytes: PackedByteArray = document.bytecode.slice(opaque_start, opaque_end)
			opaque_boundaries += 1
			opaque_boundary_bytes += opaque_bytes.size()
			opaque_spans.append({"source_offset": opaque_start, "end_offset": opaque_end})
			if (
				opaque_start < 0
				or opaque_end <= opaque_start
				or opaque_end > document.bytecode.size()
				or str(boundary.get("raw_hex", "")) != opaque_bytes.hex_encode()
				or str(boundary.get("raw_sha256", "")) != ContractValues.sha256(opaque_bytes)
				or str(boundary.get("boundary", "")) != "byte_preserving_fail_closed"
			):
				failures.append("%s opaque boundary 0x%X..0x%X is not byte preserving" % [
					entry.name, opaque_start, opaque_end,
				])
		for untyped_message in analysis.messages:
			var message: Dictionary = untyped_message
			var message_offset := int(message.source_offset)
			var owner: Dictionary = instructions_by_offset.get(message_offset, {})
			if (
				owner.is_empty()
				or str(owner.get("op", "")) not in ["text", "dispatcher_character_text"]
				or int(owner.get("end_offset", -1)) != int(message.end_offset)
			):
				message_ownership_failures += 1
				_append_negative_sample(negative_space_samples, "%s 0x%X missing_text_owner" % [entry.name, message_offset])
			if _offset_in_spans(message_offset, native_payload_spans):
				native_payload_message_failures += 1
				_append_negative_sample(negative_space_samples, "%s 0x%X native_payload" % [entry.name, message_offset])
			if _offset_in_spans(message_offset, expression_spans):
				expression_message_failures += 1
				_append_negative_sample(negative_space_samples, "%s 0x%X expression_payload" % [entry.name, message_offset])
			if _offset_in_spans(message_offset, opaque_spans):
				opaque_message_failures += 1
				_append_negative_sample(negative_space_samples, "%s 0x%X opaque_payload" % [entry.name, message_offset])
			var decoded := cp932.decode(message.raw_bytes)
			if not decoded.ok:
				cp932_failures += 1
				if cp932_failure_samples.size() < 12:
					cp932_failure_samples.append("%s 0x%X byte+0x%X %s" % [
						entry.name,
						int(message.source_offset),
						int(decoded.offset),
						str(decoded.error),
					])
			else:
				var native_failure_offset := _native_text_failure_offset(message.raw_bytes)
				if native_failure_offset >= 0:
					native_text_byte_failures += 1
					var native_lead := int(message.raw_bytes[native_failure_offset])
					native_text_byte_leads[native_lead] = int(native_text_byte_leads.get(native_lead, 0)) + 1
					if native_text_byte_samples.size() < 12:
						native_text_byte_samples.append("%s 0x%X byte+0x%X lead=0x%02X" % [
							entry.name,
							int(message.source_offset),
							native_failure_offset,
							int(message.raw_bytes[native_failure_offset]),
						])
		code_reference_count += int(analysis.code_reference_count)
		state_reference_count += int(analysis.state_reference_count)
		resource_reference_count += int(analysis.resource_reference_count)
		for untyped_reference in analysis.resource_references:
			var reference: Dictionary = untyped_reference
			var resource_kind := str(reference.resource_kind)
			resource_reference_kinds[resource_kind] = int(resource_reference_kinds.get(resource_kind, 0)) + 1
			var boundary := str(reference.boundary)
			resource_reference_boundaries[boundary] = int(resource_reference_boundaries.get(boundary, 0)) + 1
		if not analysis.complete:
			incomplete_entries += 1
			diagnostic_count += int(analysis.diagnostic_count)
			if diagnostic_samples.size() < 12:
				var diagnostic: Dictionary = analysis.diagnostics[0]
				diagnostic_samples.append("%s %s:0x%X %s" % [entry.name, diagnostic.region, diagnostic.source_offset, diagnostic.error])
	if (
		message_ownership_failures > 0
		or native_payload_message_failures > 0
		or expression_message_failures > 0
		or opaque_message_failures > 0
	):
		failures.append("message negative-space invariants failed")
	if reader.get_archive_fingerprint() != source_archive_sha:
		failures.append("source mes.arc changed during read-only native stream audit")
	reader.close()
	print("MES_ANALYSIS_CORPUS entries=%d instructions=%d messages=%d cp932_valid=%d cp932_diagnostics=%d native_text_byte_valid=%d native_text_byte_diagnostics=%d code_refs=%d state_refs=%d resource_refs=%d incomplete_entries=%d diagnostics=%d fatal_failures=%d" % [
		entry_count,
		instruction_count,
		message_count,
		message_count - cp932_failures,
		cp932_failures,
		message_count - cp932_failures - native_text_byte_failures,
		native_text_byte_failures,
		code_reference_count,
		state_reference_count,
		resource_reference_count,
		incomplete_entries,
		diagnostic_count,
		failures.size(),
	])
	print("MES_RESOURCE_REFERENCES kinds=%s boundaries=%s" % [
		_format_string_counts(resource_reference_kinds),
		_format_string_counts(resource_reference_boundaries),
	])
	print("MES_NATIVE_STREAM_PROBES tokens=%d single=%d double=%d double_projection_match=%d double_projection_mismatch=%d source_unchanged=%s" % [
		native_stream_tokens,
		native_single_stream_tokens,
		native_double_stream_tokens,
		native_double_projection_matches,
		native_double_projection_mismatches,
		str(failures.find("source mes.arc changed during read-only native stream audit") < 0),
	])
	print("MES_RECORD_ALIGNMENT native_payloads=%d native_payload_bytes=%d opaque_boundaries=%d opaque_bytes=%d byte_preserving=true" % [
		aligned_native_payloads,
		aligned_native_payload_bytes,
		opaque_boundaries,
		opaque_boundary_bytes,
	])
	for sample in aligned_native_payload_samples:
		print("MES_RECORD_ALIGNMENT_SAMPLE ", sample)
	print("MES_STRING_NEGATIVE_SPACE messages=%d owned=%d native_payload_conflicts=%d expression_payload_conflicts=%d opaque_payload_conflicts=%d" % [
		message_count,
		message_count - message_ownership_failures,
		native_payload_message_failures,
		expression_message_failures,
		opaque_message_failures,
	])
	for sample in negative_space_samples:
		push_warning("MES_STRING_NEGATIVE_SPACE_DIAGNOSTIC " + sample)
	for sample in diagnostic_samples:
		print("MES_ANALYSIS_BOUNDARY ", sample)
	for sample in cp932_failure_samples:
		push_warning("MES_CP932_DIAGNOSTIC " + sample)
	for sample in native_text_byte_samples:
		push_warning("MES_NATIVE_TEXT_BYTE_DIAGNOSTIC " + sample)
	var native_lead_labels: Array[String] = []
	var sorted_native_leads: Array = native_text_byte_leads.keys()
	sorted_native_leads.sort()
	for native_lead in sorted_native_leads:
		native_lead_labels.append("%02X:%d" % [int(native_lead), int(native_text_byte_leads[native_lead])])
	print("MES_NATIVE_TEXT_BYTE_LEADS ", ",".join(native_lead_labels) if not native_lead_labels.is_empty() else "none")
	var native_stop_labels: Array[String] = []
	var sorted_stop_reasons: Array = native_stream_stop_reasons.keys()
	sorted_stop_reasons.sort()
	for stop_reason in sorted_stop_reasons:
		native_stop_labels.append("%s:%d" % [str(stop_reason), int(native_stream_stop_reasons[stop_reason])])
	print("MES_NATIVE_STREAM_STOPS ", ",".join(native_stop_labels) if not native_stop_labels.is_empty() else "none")
	print("MES_NATIVE_DOUBLE_OPS all=%s mismatch=%s" % [
		_format_string_counts(native_double_ops),
		_format_string_counts(native_double_mismatch_ops),
	])
	print("MES_NATIVE_DOUBLE_DEFERRED_BYTES ", _format_byte_counts(native_double_deferred_bytes))
	print("MES_NATIVE_DOUBLE_MISMATCH_CHARACTERS ", _format_int_counts(native_double_mismatch_characters))
	for sample in native_stream_mismatch_samples:
		print("MES_NATIVE_STREAM_PROJECTION_BOUNDARY ", sample)
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)


func _format_string_counts(counts: Dictionary) -> String:
	var labels: Array[String] = []
	var keys: Array = counts.keys()
	keys.sort()
	for key in keys:
		labels.append("%s:%d" % [str(key), int(counts[key])])
	return ",".join(labels) if not labels.is_empty() else "none"


func _format_byte_counts(counts: Dictionary) -> String:
	var labels: Array[String] = []
	var keys: Array = counts.keys()
	keys.sort()
	for key in keys:
		labels.append("%02X:%d" % [int(key), int(counts[key])])
	return ",".join(labels) if not labels.is_empty() else "none"


func _format_int_counts(counts: Dictionary) -> String:
	var labels: Array[String] = []
	var keys: Array = counts.keys()
	keys.sort()
	for key in keys:
		labels.append("%d:%d" % [int(key), int(counts[key])])
	return ",".join(labels) if not labels.is_empty() else "none"


func _native_text_failure_offset(data: PackedByteArray) -> int:
	var offset := 0
	while offset < data.size():
		var value := int(data[offset])
		if value >= 0xF0 and value <= 0xF9:
			return offset
		if (value >= 0x81 and value <= 0x9F) or (value >= 0xE0 and value <= 0xFC):
			offset += 2
		else:
			offset += 1
	return -1


func _collect_expression_spans(value: Variant, output: Array[Dictionary]) -> void:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.has("ast") and dictionary.has("offset") and dictionary.has("end_offset"):
			output.append({
				"source_offset": int(dictionary.offset),
				"end_offset": int(dictionary.end_offset),
			})
			return
		for child in dictionary.values():
			_collect_expression_spans(child, output)
	elif value is Array:
		for child in value:
			_collect_expression_spans(child, output)


func _offset_in_spans(offset: int, spans: Array[Dictionary]) -> bool:
	for span in spans:
		if offset >= int(span.source_offset) and offset < int(span.end_offset):
			return true
	return false


func _append_negative_sample(samples: Array[String], value: String) -> void:
	if samples.size() < 12:
		samples.append(value)
