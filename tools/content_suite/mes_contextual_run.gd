class_name KakyuMesContextualRun
extends RefCounted

const CatalogScript := preload("res://content_core/event_catalog.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const AnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const ProofScript := preload("res://content_core/mes_semantic_diff.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ProbeScript := preload("res://content_core/mes_route_probe.gd")
const BindingScript := preload("res://tools/content_suite/mes_authoring_binding.gd")
const SessionScript := preload("res://tools/content_suite/mes_authoring_session.gd")
const ChainScript := preload("res://content_core/mes_semantic_diff_chain.gd")

const SAME_SIZE_FAMILIES := [
	"state_literal_edit", "condition_literal_edit", "resource_name_edit",
	"choice_option_edit", "registered_definition_call_edit",
	"shared_routine_call_edit", "control_target_edit",
]


func run(reader: KakyuArcReader, resolver: KakyuContentResolver, catalog: KakyuEventCatalog,
	play_request: Dictionary, proof: Dictionary, bundle: Dictionary = {}) -> Dictionary:
	var event := catalog.get_event(str(play_request.get("event_id", "")))
	if event.is_empty() or str(play_request.get("source_profile", {}).get("mes_archive", {}).get("sha256", "")) != reader.get_archive_fingerprint():
		return _error("The contextual event or original archive binding changed.")
	var entry := str(event.source.callee.entry)
	var caller: Dictionary = event.source.caller
	var caller_data := reader.read_entry(str(caller.entry))
	var caller_effective := resolver.read_resolved(resolver.resolve("mes.arc", str(caller.entry)))
	if _sha(caller_data) != str(caller.entry_sha256) or caller_effective != caller_data:
		return _error("The contextual caller intro no longer matches its original evidence.")
	var caller_document := ContainerScript.new().parse(caller_data)
	if not caller_document.get("ok", false):
		return _error("The contextual caller could not be parsed.")
	var dispatch := DecoderScript.new().decode_at_structural(caller_document.bytecode, int(caller.dispatch_offset))
	if not dispatch.get("ok", false) or int(dispatch.get("command_id", -1)) != int(caller.command) or int(dispatch.get("end_offset", -1)) != int(caller.resume_offset) or str(dispatch.get("script_target", "")).to_upper() != entry.to_upper():
		return _error("The contextual caller dispatch coordinate changed.")
	if str(proof.get("source_identity", {}).get("entry", "")).to_upper() != entry.to_upper() or str(proof.get("source_identity", {}).get("archive_sha256", "")) != reader.get_archive_fingerprint():
		return _error("The contextual semantic proof belongs to another source.")
	var is_chain := str(proof.get("schema", "")) == ChainScript.SCHEMA
	if is_chain and (bundle.is_empty() or bundle.get("proof") != proof):
		return _error("Contextual Run needs the stepped authoring bundle of its chain proof")
	var events: Array[Dictionary] = [event]
	var documents := {}
	for member in CatalogScript.source_members_for_events(events):
		var name := str(member.entry)
		if reader.get_entry_fingerprint(name) != str(member.entry_sha256):
			return _error("A catalog source dependency changed: %s" % name)
		var descriptor := resolver.resolve("mes.arc", name)
		if not descriptor.get("ok", false):
			return _error(str(descriptor.get("error", "A contextual dependency is unavailable.")))
		var payload := resolver.read_resolved(descriptor)
		var expected := str(proof.get("output_binding", {}).get("entry_sha256", "")) if name == entry else str(member.entry_sha256)
		if _sha(payload) != expected:
			return _error("A contextual dependency requires its own exact semantic proof: %s" % name)
		var document := ContainerScript.new().parse(payload, {"entry": name})
		if not document.get("ok", false):
			return _error("A contextual dependency could not be parsed: %s" % name)
		documents[name] = document
	var source := reader.read_entry(entry)
	var target: Dictionary = documents.get(entry, {})
	if target.is_empty():
		return _error("The contextual callee is missing.")
	var effective := resolver.read_resolved(resolver.resolve("mes.arc", entry))
	var relocated: bool
	var bound: Dictionary
	var mapping_binding: Dictionary = {}
	if is_chain:
		bound = bind_chain(source, effective, bundle)
		if not bound.get("ok", false):
			return bound
		relocated = bound.relocated
		mapping_binding = bound.binding if relocated else {}
	else:
		relocated = str(proof.get("schema", "")) == "kakyu_mes_semantic_diff/v4"
		bound = BindingScript.bind(source, effective, proof) if relocated else bind_same_size_edit(source, effective, proof)
		if not bound.get("ok", false):
			return bound
		mapping_binding = bound if relocated else {}
	var route := {
		"event_id": str(event.event_id), "entry": entry, "caller_entry": str(caller.entry),
		"start_coordinate": int(event.source.callee.start_coordinate),
		"presets": [play_request.preset], "choices": event.choices, "terminals": event.terminals,
	}
	var points := _control_points(route, target, mapping_binding)
	if not points.get("ok", false):
		return points
	var resume_points: Array = []
	if relocated:
		var mapped := BindingScript.map_route(route, mapping_binding)
		if not mapped.get("ok", false):
			return mapped
		route = mapped.route
		resume_points = mapped.resume_points
	var probe := ProbeScript.new()
	var provider := probe.context_from_documents(documents)
	if not provider.get("ok", false):
		return provider
	var result := probe.run_route(provider, route, play_request.preset)
	if not result.get("ok", false):
		return result
	var observation := {
		"owner_entry": str(result.terminal.get("entry", "")),
		"runtime_status": str(result.terminal.get("status", "")),
		"offset": int(result.terminal.get("offset", -1)),
		"next_target": str(result.terminal.get("target", "")), "state_values": result.state,
	}
	var original_observation := observation.duplicate(true)
	if relocated and str(observation.owner_entry).to_upper() == entry.to_upper():
		original_observation.offset = -1
		for point in mapping_binding.points:
			if int(point.output) == int(observation.offset):
				original_observation.offset = int(point.source)
				break
	var terminal := catalog.match_terminal(str(event.event_id), original_observation)
	var binding := {
		"schema": "kakyu_mes_contextual_run_binding/v1", "event_id": str(event.event_id),
		"source_entry_sha256": _sha(source), "effective_entry_sha256": _sha(effective),
		"semantic_diff_sha256": str(proof.payload_sha256),
		"preset_sha256": FingerprintScript.new().fingerprint({"preset": play_request.preset}),
		"coordinate_policy": ("identity_preserved_state_literal" if str(proof.get("operation", {}).get("family", "")) == "state_literal_edit" else "identity_preserved_same_size_patch"),
		"points": points.points,
		"caller_intro": caller.duplicate(true), "caller_executed": false,
		"scope": "bounded_callee_and_declared_dependencies", "native_presentation": "omitted",
	}
	if is_chain:
		binding.schema = "kakyu_mes_contextual_run_binding/v3"
		binding.coordinate_policy = "chained_same_size_then_relocation" if relocated else "chained_same_size_patches"
		binding["chain_proof_sha256"] = str(bound.chain_proof_sha256)
		binding["step_count"] = int(bound.step_count)
		if relocated:
			binding["coordinate_binding_sha256"] = str(mapping_binding.payload_sha256)
			binding["resume_points"] = resume_points
			binding["terminal_observation"] = {"source": original_observation, "output": observation}
	elif relocated:
		binding.schema = "kakyu_mes_contextual_run_binding/v2"
		binding.coordinate_policy = "reconstructed_message_relocation"
		binding["coordinate_binding_sha256"] = str(mapping_binding.payload_sha256)
		binding["resume_points"] = resume_points
		binding["terminal_observation"] = {"source": original_observation, "output": observation}
	binding["payload_sha256"] = FingerprintScript.new().fingerprint(binding)
	return {"ok": true, "probe": result, "binding": binding, "terminal_match": terminal,
		"complete": str(result.stop).is_empty() and terminal.get("ok", false) and terminal.get("route_ended", false),
		"document": target, "coordinate_binding": mapping_binding if relocated else {}, "route": route}


func bind_same_size_edit(source: PackedByteArray, output: PackedByteArray, proof: Dictionary) -> Dictionary:
	var checked := ProofScript.new().validate(proof)
	if not checked.get("ok", false) or str(proof.get("operation", {}).get("family", "")) not in SAME_SIZE_FAMILIES or str(proof.get("schema", "")) != "kakyu_mes_semantic_diff/v2":
		return _error("Contextual Run currently requires a verified same-width semantic proof.")
	if _sha(output) != str(proof.output_binding.entry_sha256) or source.size() != output.size():
		return _error("Contextual Run output identity or container size changed.")
	var source_document := ContainerScript.new().parse(source)
	var output_document := ContainerScript.new().parse(output)
	if not source_document.get("ok", false) or not output_document.get("ok", false) or source_document.header != output_document.header:
		return _error("Contextual Run requires preserved container and address coordinates.")
	var patch: Dictionary = proof.semantic_changes.patch
	var start := int(source_document.header.code_offset) + int(patch.source_start)
	var end := int(source_document.header.code_offset) + int(patch.source_end)
	if start < 0 or end <= start or end > source.size() or patch.source_start != patch.output_start or patch.source_end != patch.output_end:
		return _error("Contextual Run expression coordinates changed.")
	if _sha(source.slice(start, end)) != str(patch.source_raw_sha256) or _sha(output.slice(start, end)) != str(patch.output_raw_sha256):
		return _error("Contextual Run patched bytes do not match the semantic proof.")
	var expected := source.slice(0, start)
	expected.append_array(output.slice(start, end))
	expected.append_array(source.slice(end))
	if expected != output:
		return _error("Contextual Run output changed unrelated source bytes.")
	var decoder := DecoderScript.new()
	var original := decoder.decode_at_structural(source_document.bytecode, int(patch.source_owner_start))
	var edited := decoder.decode_at_structural(output_document.bytecode, int(patch.output_owner_start))
	if not original.get("ok", false) or not edited.get("ok", false) or str(original.op) != str(edited.op) or original.end_offset != edited.end_offset:
		return _error("Contextual Run instruction boundaries changed.")
	if str(proof.operation.family) == "state_literal_edit":
		var assertion: Dictionary = proof.semantic_changes.assertion
		if not _has_literal(original, int(patch.source_start), int(patch.source_end), assertion.source_value) or not _has_literal(edited, int(patch.output_start), int(patch.output_end), assertion.output_value):
			return _error("Contextual Run state values differ from the decoded source or output.")
	return {"ok": true}


func bind_state_edit(source: PackedByteArray, output: PackedByteArray, proof: Dictionary) -> Dictionary:
	if str(proof.get("operation", {}).get("family", "")) != "state_literal_edit":
		return _error("Contextual Run currently requires a verified same-width state-literal proof.")
	return bind_same_size_edit(source, output, proof)


func bind_chain(source: PackedByteArray, output: PackedByteArray, bundle: Dictionary) -> Dictionary:
	if not bundle.get("ok", false) or str(bundle.get("proof", {}).get("schema", "")) != ChainScript.SCHEMA:
		return _error("Contextual Run needs a verified stepped authoring bundle.")
	if bundle.get("files", {}).get("output.mes", PackedByteArray()) != output:
		return _error("Contextual Run output identity does not match the stepped bundle.")
	var validated := SessionScript.validate_source(bundle, source)
	if not validated.get("ok", false):
		return validated
	var relocated := validated.has("points")
	return {"ok": true, "relocated": relocated, "binding": (validated if relocated else {}),
		"chain_proof_sha256": str(bundle.proof.payload_sha256), "step_count": int(bundle.steps.size())}


func _has_literal(instruction: Dictionary, start: int, end: int, value: Variant) -> bool:
	if str(instruction.get("op", "")) not in ["global_u8_write_run", "state_u16_write_run", "banked_u8_write_run", "banked_u16_write_run", "banked_i32_write_run", "global_i32_write_run"]:
		return false
	for operand in instruction.get("operands", []):
		if str(operand.get("type", "")) != "expression_byte_pairs":
			continue
		for pair in operand.get("pairs", []):
			var expression: Dictionary = pair.get("expression", {})
			if int(expression.get("offset", -1)) == start and int(expression.get("end_offset", -1)) == end:
				return expression.get("ast", {}).get("type") == "literal" and expression.ast.get("value") == value
	return false


func _control_points(route: Dictionary, document: Dictionary, binding: Dictionary = {}) -> Dictionary:
	var points: Array[Dictionary] = [{"role": "start", "owner": route.entry, "source": route.start_coordinate, "output": route.start_coordinate}]
	for choice in route.choices:
		points.append({"role": "choice", "owner": str(choice.owner_entry), "source": int(choice.boundary_offset), "output": int(choice.boundary_offset)})
	for terminal in route.terminals:
		points.append({"role": "terminal", "owner": str(terminal.owner_entry), "source": int(terminal.offset), "output": int(terminal.offset)})
	var analysis := AnalysisScript.new().build_structural(document)
	if not analysis.get("ok", false):
		return _error("Contextual Run could not establish record boundaries.")
	var starts := {}
	for instruction in analysis.instructions:
		starts[int(instruction.source_offset)] = true
	for point in points:
		if str(point.owner).to_upper() == str(route.entry).to_upper():
			if not binding.is_empty():
				point.output = BindingScript.mapped_offset(binding, int(point.source))
			if not starts.has(int(point.output)):
				return _error("A contextual catalog control point is not a proven record boundary.")
	return {"ok": true, "points": points}


static func _sha(payload: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish().hex_encode()


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
