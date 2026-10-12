extends "res://tests/test_case.gd"

## EP-12 (2026-09-24): the v14 flow shape's own validator proof on a
## synthetic archive - a caller guard, two nested calls (the second with a
## routine-40 answer, both with a `resume` hop back in the caller), a root
## handoff into a second script that hands to a third, with gates and
## writes, run through `event_analysis_group_flow_validation.gd` end to end
## (the real `py tools/audit_event_analysis_group.py` subprocess plus the
## hop-by-hop runtime walk). Mirrors the fixture
## `tests/test_event_analysis_group.py`'s `EventAnalysisFlowGroupTests`
## proves against the audit alone; here the true profile must also pass at
## runtime, and a representative set of runtime-only mutations (a value the
## audit cannot re-derive, only the validator's own execution can) must fail
## with the hop named. The audit-catchable mutation family (shifted records,
## wrong outcomes, hop order, unbuildable answers, bad gate bases, malformed
## writes) is exhaustively covered on the Python side already; this scene
## does not repeat it.

const SyntheticArc := preload("res://tests/synthetic_arc.gd")
const FlowValidation := preload("res://tools/content_suite/event_analysis_group_flow_validation.gd")
const Fingerprint := preload("res://content_core/mes_payload_fingerprint.gd")

const TEST_ROOT := "user://event_analysis_group_flow_test"


func _dispatch_bytes(command: int, name: String) -> PackedByteArray:
	var bytes := PackedByteArray([command, 0x01])
	bytes.append_array(name.to_ascii_buffer())
	bytes.append_array(PackedByteArray([0, 0]))
	return bytes


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _outcome(payloads: Dictionary, entry: String, offset: int, end: int, op: String, status: String, target: String = "") -> Dictionary:
	var payload: PackedByteArray = payloads[entry]
	var out := {"offset": offset, "end": end, "op": op, "status": status,
		"source_binding": {"kind": "typed_record"},
		"record_sha256": _sha256(payload.slice(4 + offset, 4 + end))}
	if target != "":
		out["target"] = target
	return out


func _entered_by_from(kind: String, record: Dictionary) -> Dictionary:
	return {"kind": kind, "offset": record.offset, "end": record.end, "op": record.op,
		"record_sha256": record.record_sha256, "source_binding": record.source_binding}


## The exact registered-definition byte shape `tests/test_mes_routine40_choice_contract.gd`
## proves (`_append_definition` there): a command-0x10 declaration (5 bytes),
## a 4-byte target reserved and backpatched, a one-message body, then a
## trailing provenance marker outside the body.
func _append_definition(code: PackedByteArray, definition_id: int, text: String, marker: int) -> Dictionary:
	var source_offset := code.size()
	code.append_array(PackedByteArray([0x10, 0x02, definition_id, 0xFF, 0x00]))
	code.resize(code.size() + 4)
	var body_offset := code.size()
	code.append(0x01)
	code.append_array(text.to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x00]))
	var target := code.size()
	code.encode_u32(source_offset + 5, target)
	code.append(0x1F)
	code.resize(code.size() + 4)
	code.encode_u32(code.size() - 4, marker)
	return {"source_offset": source_offset, "body_offset": body_offset, "target_offset": target}


## The exact `state_u16[21] equal <result_value>` single-option consumer
## branch the same test proves - the shape `_build_canonical_consumer`
## requires after a one-definition routine-40's own resume offset.
func _append_state21_branch(code: PackedByteArray, result_value: int) -> int:
	var source_offset := code.size()
	code.append_array(PackedByteArray([0x0B, 0x80, 21, result_value, 0xEF, 0xFF]))
	code.resize(code.size() + 4)
	return source_offset


## Builds the fixture archive (written to `archive_path`) and the matching
## true v14 profile Dictionary, byte-identical in shape to the Python suite's
## own `EventAnalysisFlowGroupTests.build_flow`. `two_options` (EP-12,
## 2026-10-04, variant `answers`/`message_counts`) gives QC.MES a second
## registered definition and the two-option `state_u16[21]` branch chain: option
## 1 jumps straight to QC's return, option 2 plays one message first and
## reaches the same return record, so a variant answering option 2 plays one
## message at h4 where the hop's own answer (option 1) plays none.
func _build_flow(archive_path: String, two_options: bool = false) -> Dictionary:
	var qb_code := PackedByteArray([0x00])

	# QC.MES: one registered definition, a routine-40 selection, then the
	# exact `state_u16[21] equal 1` single-option consumer branch
	# `content_core/mes_routine40_choice_contract.gd`'s `_build_canonical_consumer`
	# requires to answer it by execution (the same shape
	# `tests/test_mes_routine40_choice_contract.gd`'s own "single" case proves) -
	# a return-only body, as the Python audit-only suite uses, has no such
	# consumer and cannot be answered at runtime.
	var qc_code := PackedByteArray()
	var definition_info := _append_definition(qc_code, 0, "OK", 1)
	var second_definition_info := {}
	if two_options:
		second_definition_info = _append_definition(qc_code, 1, "NO", 2)
	var boundary := qc_code.size()
	qc_code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	var branch_offset := _append_state21_branch(qc_code, 1)
	var qc_return_offset := 0
	if two_options:
		var jump_offset := qc_code.size()
		qc_code.append_array(PackedByteArray([0x0C, 0, 0, 0, 0]))
		var second_option_offset := qc_code.size()
		qc_code.append_array(PackedByteArray([0x01, 0x42, 0x00]))  # one message, "B"
		qc_return_offset = qc_code.size()
		qc_code.append(0x00)
		qc_code.encode_u32(jump_offset + 1, qc_return_offset)
		qc_code.encode_u32(branch_offset + 6, second_option_offset)
	else:
		qc_return_offset = qc_code.size()
		qc_code.append(0x00)
		var qc_fallback_offset := qc_code.size()
		qc_code.append(0x00)
		qc_code.encode_u32(branch_offset + 6, qc_fallback_offset)

	var qe_code := PackedByteArray([0x00])
	var qd_handoff := _dispatch_bytes(0x0E, "QE.MES")
	var qd_code := qd_handoff.duplicate()

	var origin_marker := PackedByteArray([0x1F, 0, 0, 0, 0])
	var condition := PackedByteArray([0xF3, 1, 0, 0, 0xEF, 0xFF])  # global_u8[1] == 0
	var guard_offset := origin_marker.size()
	var guard_head := PackedByteArray([0x0B])
	guard_head.append_array(condition)
	var guard_end := guard_offset + guard_head.size() + 4
	var dispatch_b := _dispatch_bytes(0x0F, "QB.MES")
	var dispatch1_offset := guard_end
	var dispatch1_end := dispatch1_offset + dispatch_b.size()
	var dispatch_c := _dispatch_bytes(0x0F, "QC.MES")
	var dispatch2_offset := dispatch1_end
	var dispatch2_end := dispatch2_offset + dispatch_c.size()
	var handoff_d := _dispatch_bytes(0x0E, "QD.MES")
	var handoff1_offset := dispatch2_end
	var handoff1_end := handoff1_offset + handoff_d.size()
	var reject_offset := handoff1_end
	var false_target := reject_offset

	var caller_code := origin_marker.duplicate()
	caller_code.append_array(guard_head)
	SyntheticArc.append_u32(caller_code, false_target)
	caller_code.append_array(dispatch_b)
	caller_code.append_array(dispatch_c)
	caller_code.append_array(handoff_d)
	caller_code.append(0x00)
	_check(caller_code.size() == reject_offset + 1, "flow fixture caller layout is self-consistent")

	var names := ["CALLER.MES", "QB.MES", "QC.MES", "QD.MES", "QE.MES"]
	var codes := {"CALLER.MES": caller_code, "QB.MES": qb_code, "QC.MES": qc_code,
		"QD.MES": qd_code, "QE.MES": qe_code}
	var payloads := {}
	for name in names:
		var payload := PackedByteArray([0, 0, 0, 0])
		payload.append_array(codes[name])
		payloads[name] = payload

	var entries := []
	for name in names:
		entries.append({"name": name, "data": payloads[name]})
	SyntheticArc.write_arc(archive_path, entries)

	var hop1_outcome := _outcome(payloads, "CALLER.MES", dispatch1_offset, dispatch1_end, "script_dispatch", "script_dispatch_boundary", "QB.MES")
	var hop2_outcome := _outcome(payloads, "QB.MES", 0, 1, "command_00", "script_return")
	var hop3_outcome := _outcome(payloads, "CALLER.MES", dispatch2_offset, dispatch2_end, "script_dispatch", "script_dispatch_boundary", "QC.MES")
	var hop4_outcome := _outcome(payloads, "QC.MES", qc_return_offset, qc_return_offset + 1, "command_00", "script_return")
	var hop5_outcome := _outcome(payloads, "CALLER.MES", handoff1_offset, handoff1_end, "script_handoff_marker", "script_handoff_boundary", "QD.MES")
	var hop6_outcome := _outcome(payloads, "QD.MES", 0, qd_handoff.size(), "script_handoff_marker", "script_handoff_boundary", "QE.MES")
	var hop7_outcome := _outcome(payloads, "QE.MES", 0, 1, "command_00", "script_return")

	var hops := [
		{"hop_id": "h1", "entry": "CALLER.MES", "entered_by": {"kind": "origin"}, "answers": [], "gates": [], "map_locations": [],
			"expected": {"message_count": 0, "outcome": hop1_outcome, "expected_state": []}},
		{"hop_id": "h2", "entry": "QB.MES", "entered_by": _entered_by_from("nested_call", hop1_outcome), "answers": [],
			"gates": [{"storage": "global_u8", "bank": 0, "index": 5, "value": 0, "op": "equal", "basis": "baseline"}], "map_locations": [],
			"expected": {"message_count": 0, "outcome": hop2_outcome, "expected_state": []}},
		{"hop_id": "h3", "entry": "CALLER.MES", "entered_by": _entered_by_from("resume", hop2_outcome), "answers": [], "gates": [], "map_locations": [],
			"expected": {"message_count": 0, "outcome": hop3_outcome, "expected_state": []}},
		{"hop_id": "h4", "entry": "QC.MES", "entered_by": _entered_by_from("nested_call", hop3_outcome),
			"answers": [{"boundary_offset": boundary, "result_value": 1}],
			"gates": [{"storage": "global_u8", "bank": 0, "index": 6, "value": 1, "op": "equal", "basis": "tool_seeded"}], "map_locations": [],
			"expected": {"message_count": 0, "outcome": hop4_outcome, "expected_state": []}},
		{"hop_id": "h5", "entry": "CALLER.MES", "entered_by": _entered_by_from("resume", hop4_outcome), "answers": [],
			"gates": [{"storage": "global_u8", "bank": 0, "index": 6, "value": 1, "op": "equal", "basis": "written_by:h4"}], "map_locations": [],
			"expected": {"message_count": 0, "outcome": hop5_outcome, "expected_state": []}},
		{"hop_id": "h6", "entry": "QD.MES", "entered_by": _entered_by_from("root_handoff", hop5_outcome), "answers": [], "gates": [], "map_locations": [],
			"expected": {"message_count": 0, "outcome": hop6_outcome, "expected_state": []}},
		{"hop_id": "h7", "entry": "QE.MES", "entered_by": _entered_by_from("root_handoff", hop6_outcome), "answers": [], "gates": [], "map_locations": [],
			"expected": {"message_count": 0, "outcome": hop7_outcome, "expected_state": []}},
	]

	var contract_definitions := []
	for info in ([definition_info, second_definition_info] if two_options else [definition_info]):
		var definition_body := qc_code.slice(info.body_offset, info.target_offset)
		contract_definitions.append({"source_offset": info.source_offset,
			"body_offset": info.body_offset, "target_offset": info.target_offset,
			"definition_id": contract_definitions.size(), "body_size": definition_body.size(),
			"body_sha256": _sha256(definition_body)})
	var contract := {"schema": "kakyu_mes_routine40_choice_contract/v3",
		"boundary_offset": boundary, "resume_offset": boundary + 5, "definition_count": contract_definitions.size(),
		"result_values": [1, 2] if two_options else [1], "definitions": contract_definitions,
		"source_identity": {"archive": "mes.arc", "entry": "QC.MES"},
		"bytecode_sha256": _sha256(qc_code), "code_size": qc_code.size()}

	var terminal := hop7_outcome.duplicate(true)
	terminal["entry"] = "QE.MES"

	var profile := {"schema": "kakyu_event_analysis_group/v14", "group_id": "synthetic_flow_gd",
		"archive_sha256": FileAccess.get_sha256(archive_path),
		"source_members": [],
		"routes": [{
			"route_id": "flow",
			"origin": {"entry": "CALLER.MES", "offset": 0,
				"guard": {"offset": guard_offset, "end": guard_end, "false_target": false_target,
					"prefix_sha256": _sha256(caller_code.slice(0, dispatch1_end)),
					"record_sha256": _sha256(caller_code.slice(guard_offset, guard_end)),
					"source_binding": {"kind": "typed_record"}},
				"guard_cases": [
					{"case_id": "yes", "writes": [], "expected": 1},
					{"case_id": "no", "writes": [{"storage": "global_u8", "bank": 0, "index": 1, "value": 1}], "expected": 0}]},
			"baseline": [],
			"choice_contracts": [contract],
			"hops": hops,
			"terminal": terminal,
			"variants": [{"variant_id": "default", "writes": [], "expected_state": []}],
			"unresolved": ["QB.MES gate index 5's own natural origin is not established"],
		}],
	}
	for name in names:
		profile.source_members.append({"entry": name, "entry_sha256": _sha256(payloads[name])})
	return profile


func _sign(profile: Dictionary) -> void:
	profile["payload_sha256"] = Fingerprint.new().fingerprint(profile)


func _write_profile(profile: Dictionary, path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(profile))
	file.close()


func _ready() -> void:
	_cleanup()
	var root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(root)
	var archive_path := root.path_join("mes.arc")
	var profile := _build_flow(archive_path)
	_sign(profile)
	var profile_path := root.path_join("flow_v14.json")
	_write_profile(profile, profile_path)

	var validator := FlowValidation.new()
	var result := validator.validate(root, profile_path)
	_check(result.get("ok", false), "true flow profile validates end to end: %s" % str(result.get("failures", [])))
	_check(result.get("checks", 0) > 0, "flow validator records at least one check")
	_check_replay_v3(root, profile, profile_path, result)

	# Runtime-only mutations: a value the Python audit does not re-derive
	# (a message count, a gate's own value, a declared write), so only the
	# validator's own execution catches it - the audit-catchable family
	# (shifted records, wrong outcomes, hop order, unbuildable answers, bad
	# gate bases, malformed writes) is covered exhaustively in
	# tests/test_event_analysis_group.py's EventAnalysisFlowGroupTests.
	var mutations := {
		"h5 gate value": func(p: Dictionary):
			p.routes[0].hops[4].gates[0].value = 2,
		"h2 message count": func(p: Dictionary):
			p.routes[0].hops[1].expected.message_count = 1,
		"h7 expected write value": func(p: Dictionary):
			p.routes[0].hops[6].expected.expected_state.append(
				{"storage": "global_u8", "bank": 0, "index": 1, "value": 1}),
	}
	for label in mutations:
		var mutated: Dictionary = _build_flow(archive_path)
		mutations[label].call(mutated)
		_sign(mutated)
		var mutated_path := root.path_join("flow_v14_%s.json" % label.replace(" ", "_"))
		_write_profile(mutated, mutated_path)
		var mutated_validator := FlowValidation.new()
		var mutated_result := mutated_validator.validate(root, mutated_path)
		_check(not mutated_result.get("ok", true), "mutation '%s' is rejected by the flow validator" % label)
		var named := false
		for failure in mutated_result.get("failures", []):
			if str(failure).contains(_hop_id_for(label)):
				named = true
		_check(named, "mutation '%s' failure names its own hop" % label)

	_check_variant_answers_and_counts(root)

	_cleanup()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


## EP-12 (2026-10-04, additive to v14): a variant's `answers` override a hop's
## own answer and its `message_counts` replace that hop's count for the
## variant only. The two-option fixture's h4 plays no message for option 1
## (the default variant, the hop's own answer and count) and one for option 2
## (the `second` variant). A profile that carries neither field is the one the
## rest of this scene already validates.
func _check_variant_answers_and_counts(root: String) -> void:
	var two_root := root.path_join("two_options")
	DirAccess.make_dir_recursive_absolute(two_root)
	var archive_path := two_root.path_join("mes.arc")
	var base := _build_flow(archive_path, true)
	var boundary := int(base.routes[0].hops[3].answers[0].boundary_offset)
	_sign(base)
	var base_path := two_root.path_join("flow_v14_two_options.json")
	_write_profile(base, base_path)
	var base_result := FlowValidation.new().validate(two_root, base_path)
	_check(base_result.get("ok", false), "two-option flow without variant fields validates: %s" % str(base_result.get("failures", [])))

	var variant := {"variant_id": "second", "writes": [], "expected_state": [],
		"answers": [{"hop_id": "h4", "boundary_offset": boundary, "result_value": 2}],
		"message_counts": {"h4": 1}}
	var with_variant := _build_flow(archive_path, true)
	with_variant.routes[0].variants.append(variant.duplicate(true))
	_sign(with_variant)
	var variant_path := two_root.path_join("flow_v14_variant.json")
	_write_profile(with_variant, variant_path)
	var variant_result := FlowValidation.new().validate(two_root, variant_path)
	_check(variant_result.get("ok", false), "a variant answering option 2 with its own count validates: %s" % str(variant_result.get("failures", [])))
	_check(int(variant_result.get("checks", 0)) > int(base_result.get("checks", 0)), "the second variant adds its own checks")

	var mutations := {
		"variant count without its answer": func(v: Dictionary):
			v.erase("answers"),
		"variant answer without its count": func(v: Dictionary):
			v.erase("message_counts"),
		"variant count wrong": func(v: Dictionary):
			v.message_counts = {"h4": 2},
	}
	for label in mutations:
		var mutated := _build_flow(archive_path, true)
		var mutated_variant := variant.duplicate(true)
		mutations[label].call(mutated_variant)
		mutated.routes[0].variants.append(mutated_variant)
		_sign(mutated)
		var mutated_path := two_root.path_join("flow_v14_%s.json" % label.replace(" ", "_"))
		_write_profile(mutated, mutated_path)
		var mutated_result := FlowValidation.new().validate(two_root, mutated_path)
		_check(not mutated_result.get("ok", true), "mutation '%s' is rejected by the flow validator" % label)
		var named := false
		for failure in mutated_result.get("failures", []):
			if str(failure).contains("second") and str(failure).contains("hop h4 message count"):
				named = true
		_check(named, "mutation '%s' failure names its variant and hop" % label)


## WD-21 U2 C2 (2026-10-08): the replay file the flow validator writes is
## `kakyu_event_analysis_group_replay/v3` - each hop carries `executed` (the
## sorted offsets its probe result executed, keyed by package member) and
## `resource_rows` (the media effects its own entries requested; the synthetic
## archive has none). Writing a replay adds no check and no failure.
func _check_replay_v3(root: String, profile: Dictionary, profile_path: String, plain_result: Dictionary) -> void:
	var replay_path := root.path_join("flow_replay_v3.json")
	var replay_result := FlowValidation.new().validate(root, profile_path, replay_path)
	_check(replay_result.get("ok", false), "the flow validates with --replay: %s" % str(replay_result.get("failures", [])))
	_check(int(replay_result.get("checks", -1)) == int(plain_result.get("checks", -2)), "writing a replay adds no check")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(replay_path))
	_check(parsed is Dictionary, "the replay file parses")
	if not parsed is Dictionary:
		return
	var doc: Dictionary = parsed
	_check(str(doc.get("schema", "")) == "kakyu_event_analysis_group_replay/v3", "the replay schema is v3")
	var routes: Array = doc.get("routes", [])
	_check(routes.size() == 1 and (routes[0].variants as Array).size() == 1, "one route with one variant")
	var variant: Dictionary = routes[0].variants[0]
	_check(not variant.has("executed") and not variant.has("resource_rows"), "a flow variant carries the fields per hop, not at its top level")
	var hops: Array = variant.get("hops", [])
	var profile_hops: Array = profile.routes[0].hops
	_check(hops.size() == profile_hops.size() and hops.size() == 7, "seven hops are replayed")
	for index in range(mini(hops.size(), profile_hops.size())):
		var hop: Dictionary = hops[index]
		var profile_hop: Dictionary = profile_hops[index]
		var label := str(profile_hop.hop_id)
		_check(hop.get("executed") is Dictionary and hop.get("resource_rows") is Array, "hop %s carries executed and resource_rows" % label)
		if not hop.get("executed") is Dictionary:
			continue
		var executed: Dictionary = hop.executed
		_check(executed.has(str(profile_hop.entry)), "hop %s executed is keyed by its entry" % label)
		var offsets: Array = executed.get(str(profile_hop.entry), [])
		var sorted_unique := true
		var holds_final_row := false
		for offset_index in range(offsets.size()):
			if offset_index > 0 and int(offsets[offset_index]) <= int(offsets[offset_index - 1]):
				sorted_unique = false
			if int(offsets[offset_index]) == int(profile_hop.expected.outcome.offset):
				holds_final_row = true
		_check(sorted_unique and not offsets.is_empty(), "hop %s executed offsets are sorted and unique" % label)
		_check(holds_final_row, "hop %s executed holds the row of its declared outcome" % label)
		_check((hop.resource_rows as Array).is_empty(), "hop %s requests no media in the synthetic archive" % label)
		_check(hop.has("messages") and hop.has("terminal") and hop.has("state_changes"), "hop %s keeps its v2 fields" % label)


func _hop_id_for(label: String) -> String:
	if label.begins_with("h5"): return "h5"
	if label.begins_with("h2"): return "h2"
	if label.begins_with("h7"): return "h7"
	return ""


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
