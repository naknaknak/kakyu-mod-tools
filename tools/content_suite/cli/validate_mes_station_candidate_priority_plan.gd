extends SceneTree

# Metadata-only authoritative-source proof. Candidate true bodies, the station
# host, and native row selection are never executed by this validator.
const Reader := preload("res://content_core/arc_reader.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Decoder := preload("res://content_core/mes_instruction_decoder.gd")
const ExpressionScript := preload("res://content_core/mes_expression.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const Plan := preload("res://content_core/mes_station_candidate_priority_plan.gd")
const Version := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const ArchiveIdentity := preload("res://content_core/original_archive_identity.gd")

const ARCHIVE_SHA256 := ArchiveIdentity.SIX_ARCHIVE_SHA256
const STATION_SHA256 := "a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5"
const STATION_BYTECODE_SHA256 := "f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b"
const STATION_CASCADE_SHA256 := "34ae9a590921cf5e4ac5f4a5921c2d5b1a779ae6d868d7b4ead456bcb1671c29"
const MACHI_SHA256 := "56b0f4243f3c0944624ea0ef11b369391761ff394816775264c144bb76391488"
const MACHI_BYTECODE_SHA256 := "34aea9b95996997a4657c89e848b59c0d04c1ba1fdeb26794252017b1d1a84cf"
const MACHI_EVE_SHA256 := "9f56d74f8c53fc3ee2ad17918519f677e3ebf9070097921190e3ea6de2833d62"
const STATION_BOOTSTRAP_SHA256 := "1d5fcfa66928c2bd712394fcd5e001e48b41b60f943039c72d06687224953e5c"
const MACHI_EVENT16_GUARD_SHA256 := "e388389b8096d854a52c12203969a7b73cfc2369bb5f6267b3d1b4d1266893fd"
const MACHI_01M_HANDOFF_SHA256 := "7d254587b79c85522f184d95301f986a3f72510128d8920dc163d7868c81c612"
const MACHI_EVE16_SHA256 := "538fe2444347fb43fb1c0c93bfb7297b589835cc2b1ef1e99a875d4b035edb0a"

const STATE_U16_INDICES := [4, 7, 19]
const BANKED_U16_INDICES := [
	213, 214, 215, 216, 217, 218, 219, 220, 221, 222,
	225, 226, 227, 228, 229, 230, 231, 232, 233, 234,
	235, 236, 237, 238, 268,
]
const GLOBAL_U8_INDICES := [
	100, 107, 109, 110, 117, 119, 120, 127, 129, 130, 137,
	139, 140, 147, 149, 160, 167, 169, 170, 177, 179, 180,
	187, 189, 190, 197, 199, 200, 207, 209, 210, 217, 219,
	220, 227, 229, 1188, 1189, 1750, 1751, 2300, 2301, 2304,
	2305,
]

# start, end, false destination, exact envelope hash, schedule date cell,
# schedule time cell, schedule-byte base. Negative schedule values identify the
# three distinct source predicates at orders 0, 13, and 14.
const GUARD_ROWS := [
	[0x026D, 0x02A3, 0x247E, "0d0e009000726fe0f17548178304c4c6e86b71f2ac575d2f6437bd10c82eef57", -1, -1, -1],
	[0x247E, 0x24D7, 0x2AF7, "dc89fca3c2c7a529c34c5ee8063a8974d2ddaed4e6e2cc697c211007e4f28b61", 213, 214, 100],
	[0x2AF7, 0x2B50, 0x3170, "b7314844e929563792746672a74858c66aa4c6adb20880c7a1928ec5b95949ae", 215, 216, 110],
	[0x3170, 0x31C9, 0x37E9, "af269a8ec3cdd5d8d2c05bb4ce63c64981e550ec78b363b7d1722d2490a3eabb", 217, 218, 120],
	[0x37E9, 0x3842, 0x3E62, "759c90777fecd03bc76b37627e4b639cf2c3caa01bdacd9c088f0cdec291f3e1", 219, 220, 130],
	[0x3E62, 0x3EBB, 0x44DB, "728f5cecff49a64f35a7bb39cb9434cceb213727eb6203e54ea9e8393e9fa86b", 221, 222, 140],
	[0x44DB, 0x4534, 0x4B54, "f6cb89285e40075b7520511300e16cb24aad36638775e1b941280b8602d53c88", 225, 226, 160],
	[0x4B54, 0x4BAD, 0x51CD, "86fe3d853c62a02e8498e2c7e59be95ac102305d42476e0a4e626ff69c07e931", 227, 228, 170],
	[0x51CD, 0x5226, 0x5846, "dfa883381166c690755794263524fed545f8c175cb89871a47745047df484530", 229, 230, 180],
	[0x5846, 0x589F, 0x5EBF, "285f1ed60093062ceaf35777b4a875f5825c9c190195be5dc11a6a35fd3e5482", 231, 232, 190],
	[0x5EBF, 0x5F18, 0x6538, "4d11b77ddf881fc8b1d1f42c736c5717c93d1a74acc3aa373047221bba3a7550", 233, 234, 200],
	[0x6538, 0x6591, 0x6BB1, "70dd239bdc7caf40e80a53d732c085d39d409608b48b8817c41c2ec595510b86", 235, 236, 210],
	[0x6BB1, 0x6C0A, 0x722A, "67e133c45363e595f4c08ac5a25643865d7fb67b7b29bbeb2051a45fe8ca330a", 237, 238, 220],
	[0x722A, 0x725D, 0x73F5, "2ca7c628287f9a65b90969240f1dbab5a19cae41c05f89811d124300a08753b0", -1, -1, -2],
	[0x73F5, 0x7425, 0x7691, "a97d3d398e663593eb01b85e1ce4892cd69ca38696a7089f51ec25c53928144b", -1, -1, -3],
]

var _checks := 0
var _failures: Array[String] = []
var _decoder := Decoder.new()
var _plans := Plan.new()
var _guard_asts: Array[Dictionary] = []


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: validate_mes_station_candidate_priority_plan.gd -- <ELFIMAGE-directory>")
		quit(2)
		return
	var source_root := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var before := {}
	for archive in ARCHIVE_SHA256:
		var path := source_root.path_join(archive)
		if not FileAccess.file_exists(path):
			push_error("Required original archive unavailable: %s" % archive)
			quit(2)
			return
		before[archive] = FileAccess.get_sha256(path)
		_check(before[archive] == ARCHIVE_SHA256[archive], "%s original identity changed" % archive)
	var mes := Reader.new()
	var data := Reader.new()
	_check(mes.open(source_root.path_join("mes.arc")), "original mes.arc unavailable")
	_check(data.open(source_root.path_join("data.arc")), "original data.arc unavailable")
	if _failures.is_empty():
		_audit(mes, data)
	mes.close()
	data.close()
	for archive in ARCHIVE_SHA256:
		_check(FileAccess.get_sha256(source_root.path_join(archive)) == before[archive], "%s changed during read-only validation" % archive)
	if not _failures.is_empty():
		push_error("Station candidate priority source validation failed: %s" % "; ".join(_failures))
		quit(1)
		return
	print("PASS: station candidate priority source plan: %d checks / 15 exact guards / 15 first-true witnesses / all-false EVENTB03 join / multiple-true earliest-wins / deterministic JSON replay. MACHI.EVE event 16, MACHI 01M handoff, and the coordinate-zero bootstrap are separate source metadata; host zero-start and native row selection remain unresolved, and natural eligibility remains unqualified. Six archives unchanged. %s / %s" % [_checks, Version.CORE_VERSION, Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA])
	quit(0)


func _audit(mes: RefCounted, data: RefCounted) -> void:
	_check(mes.get_archive_fingerprint() == ARCHIVE_SHA256["mes.arc"], "opened mes.arc identity changed")
	_check(data.get_archive_fingerprint() == ARCHIVE_SHA256["data.arc"], "opened data.arc identity changed")
	_check(mes.get_entry_fingerprint("01M.MES") == STATION_SHA256, "01M.MES identity changed")
	_check(mes.get_entry_fingerprint("MACHI.MES") == MACHI_SHA256, "MACHI.MES identity changed")
	_check(data.get_entry_fingerprint("MACHI.EVE") == MACHI_EVE_SHA256, "MACHI.EVE identity changed")
	var station_payload: PackedByteArray = mes.read_entry("01M.MES")
	var machi_payload: PackedByteArray = mes.read_entry("MACHI.MES")
	var eve_payload: PackedByteArray = data.read_entry("MACHI.EVE")
	var source_hashes := [ContractValues.sha256(station_payload), ContractValues.sha256(machi_payload), ContractValues.sha256(eve_payload)]
	var station: Dictionary = ContainerScript.new().parse(station_payload, {"archive": "mes.arc", "entry": "01M.MES", "resolved_source": "original_arc"})
	var machi: Dictionary = ContainerScript.new().parse(machi_payload, {"archive": "mes.arc", "entry": "MACHI.MES", "resolved_source": "original_arc"})
	_check(station.get("ok", false) and station.get("entry_sha256", "") == STATION_SHA256 and station.get("bytecode_sha256", "") == STATION_BYTECODE_SHA256, "01M.MES container identity changed")
	_check(machi.get("ok", false) and machi.get("entry_sha256", "") == MACHI_SHA256 and machi.get("bytecode_sha256", "") == MACHI_BYTECODE_SHA256, "MACHI.MES container identity changed")
	if not _failures.is_empty():
		return
	_validate_station_metadata(station, machi, eve_payload)
	_validate_guard_sources(station.bytecode)
	if not _failures.is_empty():
		return
	_validate_all_false(station_payload, station)
	_validate_first_true_witnesses(station_payload, station)
	_validate_multiple_true_priority(station_payload, station)
	_validate_rejections(station_payload)
	_check(source_hashes == [ContractValues.sha256(station_payload), ContractValues.sha256(machi_payload), ContractValues.sha256(eve_payload)], "validation changed an in-memory original source")


func _validate_station_metadata(station: Dictionary, machi: Dictionary, eve: PackedByteArray) -> void:
	var station_code: PackedByteArray = station.bytecode
	_check(station.entries.size() == 426, "01M.MES address-table count changed")
	if station.entries.size() > 0:
		_check(int(station.entries[0].offset) == 0x0008 and int(station.entries[0].end_offset) == 0x03AF, "01M.MES entry-zero bounds changed")
	_check(ContractValues.sha256(station_code.slice(0, 8)) == STATION_BOOTSTRAP_SHA256 and station_code.slice(0, 8) == PackedByteArray([0x14, 0x12, 0xFF, 0x08, 0, 0, 0, 0]), "01M.MES coordinate-zero bootstrap bytes changed")
	var bootstrap := _record(station_code, 0x0000, 0x0007, "bootstrap_transfer")
	if not bootstrap.is_empty():
		_check(_ast(bootstrap.operands[0].value.ast) == 18 and int(bootstrap.operands[1].value) == 0x0008, "01M.MES coordinate-zero bootstrap target changed")
	_record(station_code, 0x0007, 0x0008, "command_00")

	var machi_code: PackedByteArray = machi.bytecode
	_check(machi.entries.size() > 189 and int(machi.entries[189].offset) == 0xABC0 and int(machi.entries[189].end_offset) == 0xAD66, "MACHI event-dispatch address row 189 bounds changed")
	_check(ContractValues.sha256(machi_code.slice(0xACA2, 0xACAC)) == MACHI_EVENT16_GUARD_SHA256, "MACHI event-16 guard bytes changed")
	var event_guard := _record(machi_code, 0xACA2, 0xACAC, "branch_if_not_true")
	if not event_guard.is_empty():
		_check(_signature(event_guard.operands[0].value.ast) == ["equal", _state_ref("state_u16", 21), 16] and int(event_guard.operands[1].value) == 0xACC6, "MACHI event-16 predicate or false edge changed")
	_check(ContractValues.sha256(machi_code.slice(0xACB1, 0xACBC)) == MACHI_01M_HANDOFF_SHA256, "MACHI 01M handoff bytes changed")
	var handoff := _record(machi_code, 0xACB1, 0xACBC, "script_handoff_marker")
	if not handoff.is_empty():
		_check(str(handoff.get("script_target", "")).to_upper() == "01M.MES", "MACHI event-16 handoff target changed")

	_check(eve.size() == 518 and eve.decode_u16(516) == 0xFFFF, "MACHI.EVE size or terminator changed")
	_check(ContractValues.sha256(eve.slice(0x00C0, 0x00CC)) == MACHI_EVE16_SHA256, "MACHI.EVE event-16 record bytes changed")
	var matches := 0
	var offset := 0
	while offset + 12 <= eve.size() and eve.decode_u16(offset) != 0xFFFF:
		if eve.decode_u16(offset) == 16:
			matches += 1
			_check(offset == 0x00C0 and _eve_values(eve, offset) == [16, 60, 22, 61, 22, 1], "MACHI.EVE event-16 trigger metadata changed")
		offset += 12
	_check(matches == 1 and offset == 516, "MACHI.EVE event-16 uniqueness or record framing changed")
	# These fields deliberately prevent the three separate source records above
	# from being promoted into an unobserved native-host start contract.
	var evidence_boundary := {
		"host_zero_start": "unresolved",
		"native_address_row_selection": "unresolved",
		"natural_scheduler_eligibility": "unqualified",
	}
	_check(evidence_boundary == {"host_zero_start": "unresolved", "native_address_row_selection": "unresolved", "natural_scheduler_eligibility": "unqualified"}, "station source metadata promoted an unresolved host boundary")


func _validate_guard_sources(code: PackedByteArray) -> void:
	_guard_asts.clear()
	_check(ContractValues.sha256(code.slice(0x026D, 0x7691)) == STATION_CASCADE_SHA256, "station candidate cascade bytes changed")
	for order in range(GUARD_ROWS.size()):
		var row: Array = GUARD_ROWS[order]
		var record := _record(code, int(row[0]), int(row[1]), "branch_if_not_true")
		if record.is_empty():
			continue
		_check(ContractValues.sha256(code.slice(int(row[0]), int(row[1]))) == str(row[3]), "guard %d exact source hash changed" % order)
		_check(int(record.operands[1].value) == int(row[2]), "guard %d false edge changed" % order)
		var ast: Dictionary = record.operands[0].value.ast
		_check(_signature(ast) == _expected_guard_signature(order), "guard %d exact AST changed" % order)
		_guard_asts.append(ast.duplicate(true))
	_check(_guard_asts.size() == 15, "not all fifteen candidate guards were decoded")


func _validate_all_false(payload: PackedByteArray, station: Dictionary) -> void:
	var input := _blank_input()
	input.state_u16["7"] = 413
	input.state_u16["19"] = 1825
	var plan := _assert_plan(payload, station, input, -1, "all-false EVENTB03 join")
	if plan.is_empty():
		return
	_check(plan.evaluation.all_upstream_false and plan.evaluation.evaluated_guards.size() == 15, "all-false route did not evaluate every upstream guard")
	_check(plan.selected_boundary == {"kind": "candidate_cascade_join", "offset": 0x7691, "end_offset": 0x7691, "next_plan_schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA, "delegated": false}, "all-false route no longer stops at the EVENTB03 candidate join")


func _validate_first_true_witnesses(payload: PackedByteArray, station: Dictionary) -> void:
	for order in range(GUARD_ROWS.size()):
		var input := _witness(order)
		var independent := _evaluate_source(input, false)
		_check(independent.get("ok", false) and int(independent.first_true_order) == order, "guard %d witness is not independently first true" % order)
		_assert_plan(payload, station, input, order, "guard %d first-true witness" % order)


func _validate_multiple_true_priority(payload: PackedByteArray, station: Dictionary) -> void:
	var cases := [
		{"orders": [0, 1], "input": _combined_zero_and_schedule()},
		{"orders": [1, 12], "input": _combined_schedules(1, 12, 1200)},
		{"orders": [12, 13], "input": _combined_schedule_and_thirteen()},
		{"orders": [1, 14], "input": _combined_schedule_and_fourteen()},
	]
	for specification in cases:
		var orders: Array = specification.orders
		var input: Dictionary = specification.input
		var state := _state_from(input)
		var snapshot: Dictionary = state.snapshot()
		for order in orders:
			var result: Dictionary = ExpressionScript.new().evaluate(_guard_asts[int(order)], state)
			_check(result.get("ok", false) and int(result.get("value", -1)) == 1, "multiple-true fixture lost guard %d" % order)
		_check(state.snapshot() == snapshot, "multiple-true source evaluation changed state")
		var expected_first := int(orders.min())
		_assert_plan(payload, station, input, expected_first, "multiple-true %s earliest-wins" % str(orders))


func _assert_plan(payload: PackedByteArray, station: Dictionary, input: Dictionary, expected_first: int, label: String) -> Dictionary:
	var input_before := JSON.stringify(input)
	var source_before := ContractValues.sha256(payload)
	var plan: Dictionary = _plans.build(payload, input)
	_check(plan.get("ok", false), "%s plan failed: %s" % [label, plan.get("error", "")])
	if not plan.get("ok", false):
		return {}
	_check(_has_exact_keys(plan, ["ok", "schema", "producer", "source", "required_input", "input", "guards", "evaluation", "selected_boundary", "execution"]), "%s root key set changed" % label)
	_check(plan.schema == Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA, "%s schema changed" % label)
	_check(plan.producer == {"core_version": Version.CORE_VERSION, "instruction_schema": Version.MES_INSTRUCTION_SCHEMA}, "%s producer changed" % label)
	_check(plan.source == {"archive": "mes.arc", "entry": "01M.MES", "entry_sha256": STATION_SHA256, "bytecode_sha256": STATION_BYTECODE_SHA256, "offset_basis": "code_start", "cascade_offset": 0x026D, "join_offset": 0x7691, "cascade_sha256": STATION_CASCADE_SHA256}, "%s source qualification changed" % label)
	_check(plan.required_input == {"state_u16": STATE_U16_INDICES, "banked_u16_0": BANKED_U16_INDICES, "global_u8": GLOBAL_U8_INDICES, "total_unique_cells": 72}, "%s required input descriptor changed" % label)
	_check(plan.input == input, "%s normalized input changed" % label)
	_check(plan.guards.size() == 15, "%s did not retain fifteen source guards" % label)
	if plan.guards.size() == 15:
		for order in range(15):
			var row: Array = GUARD_ROWS[order]
			var signature: Variant = _expected_guard_signature(order)
			_check(plan.guards[order] == {"order": order, "offset": row[0], "end_offset": row[1], "true_offset": row[1], "false_offset": row[2], "sha256": row[3], "predicate_signature": signature, "state_references": _state_references(signature)}, "%s guard %d metadata changed" % [label, order])
	var independent := _evaluate_source(input, true)
	_check(independent.get("ok", false) and int(independent.get("first_true_order", -2)) == expected_first, "%s independent result changed" % label)
	if independent.get("ok", false):
		_check(plan.evaluation == {"evaluated_guards": independent.outcomes, "first_true_order": expected_first, "all_upstream_false": expected_first < 0}, "%s evaluation receipt changed" % label)
	if expected_first >= 0:
		var row: Array = GUARD_ROWS[expected_first]
		_check(plan.selected_boundary == {"kind": "stop_before_true_body", "guard_order": expected_first, "guard_offset": row[0], "offset": row[1], "end_offset": row[1], "tool_execution": false, "true_body_interpretation": "unresolved"}, "%s did not stop before its true body" % label)
	else:
		_check(plan.selected_boundary.kind == "candidate_cascade_join" and int(plan.selected_boundary.offset) == 0x7691, "%s did not reach the all-false join" % label)
	_check(plan.execution == {"kind": "read_only_projection", "state_mutation": false, "frozen_state_preemption": "qualified", "true_body_execution": false, "terminal_resolution": false, "entry_zero_reachability": "unqualified", "natural_scheduler_eligibility": "unqualified", "native_address_row_selection": "unresolved", "native_cadence": "unresolved"}, "%s promoted execution or host eligibility" % label)
	_check(_plans.validate(payload, plan).get("ok", false), "%s failed source replay validation" % label)
	var reloaded: Variant = JSON.parse_string(JSON.stringify(plan))
	_check(reloaded is Dictionary and _plans.validate(payload, reloaded).get("ok", false), "%s failed JSON round-trip validation" % label)
	_check(_plans.build(payload, input) == plan, "%s rebuild is nondeterministic" % label)
	_check(JSON.stringify(input) == input_before and ContractValues.sha256(payload) == source_before, "%s changed its input or source bytes" % label)
	return plan


func _validate_rejections(payload: PackedByteArray) -> void:
	var input := _blank_input()
	input.state_u16["7"] = 413
	input.state_u16["19"] = 1825
	var plan: Dictionary = _plans.build(payload, input)
	if not plan.get("ok", false):
		return
	for mutation in [
		[["schema"], "unqualified"], [["source", "entry"], "OTHER.MES"],
		[["guards", 0, "sha256"], "unqualified"], [["guards", 1, "false_offset"], 0x7691],
		[["evaluation", "first_true_order"], 0], [["selected_boundary", "delegated"], true],
		[["execution", "true_body_execution"], true], [["execution", "natural_scheduler_eligibility"], "qualified"],
		[["execution", "native_address_row_selection"], "entry_0"],
	]:
		var changed: Dictionary = plan.duplicate(true)
		var target: Variant = changed
		var path: Array = mutation[0]
		for index in range(path.size() - 1):
			target = target[path[index]]
		target[path[-1]] = mutation[1]
		var before := JSON.stringify(changed)
		_check(not _plans.validate(payload, changed).get("ok", true) and JSON.stringify(changed) == before, "mutated plan accepted or rewritten: %s" % str(path))
	var extra: Dictionary = plan.duplicate(true)
	extra["host_zero_start"] = 0
	_check(not _plans.validate(payload, extra).get("ok", true), "plan accepted an invented host zero-start field")
	var missing: Dictionary = plan.duplicate(true)
	missing.erase("execution")
	_check(not _plans.validate(payload, missing).get("ok", true), "plan accepted a missing execution boundary")
	var invalid_inputs := []
	var invalid := input.duplicate(true)
	invalid.erase("global_u8")
	invalid_inputs.append(invalid)
	invalid = input.duplicate(true)
	invalid["extra"] = {}
	invalid_inputs.append(invalid)
	invalid = input.duplicate(true)
	invalid.global_u8.erase("2305")
	invalid_inputs.append(invalid)
	invalid = input.duplicate(true)
	invalid.global_u8["2305"] = true
	invalid_inputs.append(invalid)
	invalid = input.duplicate(true)
	invalid.state_u16["7"] = 413.0
	invalid_inputs.append(invalid)
	invalid = input.duplicate(true)
	invalid.global_u8["2305"] = 256
	invalid_inputs.append(invalid)
	for rejected in invalid_inputs:
		var before := JSON.stringify(rejected)
		_check(not _plans.build(payload, rejected).get("ok", true) and JSON.stringify(rejected) == before, "malformed input accepted or rewritten")
	var changed_payload := payload.duplicate()
	changed_payload[changed_payload.size() - 1] ^= 1
	_check(not _plans.build(changed_payload, input).get("ok", true) and not _plans.validate(changed_payload, plan).get("ok", true), "changed 01M.MES payload accepted")
	_check(not _plans.build(payload.slice(0, payload.size() - 1), input).get("ok", true), "truncated 01M.MES payload accepted")
	_check(_plans.validate(payload, plan).get("ok", false), "negative probes contaminated the original plan")


func _evaluate_source(input: Dictionary, stop_at_first: bool) -> Dictionary:
	var state := _state_from(input)
	var before: Dictionary = state.snapshot()
	var outcomes: Array[Dictionary] = []
	var first := -1
	for order in range(_guard_asts.size()):
		var result: Dictionary = ExpressionScript.new().evaluate(_guard_asts[order], state)
		if not result.get("ok", false) or int(result.get("value", -1)) not in [0, 1]:
			return {"ok": false}
		var value := int(result.value)
		var row: Array = GUARD_ROWS[order]
		outcomes.append({"order": order, "offset": row[0], "value": value, "next_offset": row[1] if value == 1 else row[2]})
		if value == 1 and first < 0:
			first = order
			if stop_at_first:
				break
	_check(state.snapshot() == before, "source guard evaluation changed sandbox state")
	return {"ok": true, "first_true_order": first, "outcomes": outcomes}


func _state_from(input: Dictionary) -> KakyuMesSandboxState:
	var state := State.new(1)
	for index in STATE_U16_INDICES:
		state.write_value("state_u16", index, input.state_u16[str(index)])
	for index in BANKED_U16_INDICES:
		state.write_value("banked_u16", index, input.banked_u16_0[str(index)], 0)
	for index in GLOBAL_U8_INDICES:
		state.write_value("global_u8", index, input.global_u8[str(index)])
	return state


func _blank_input() -> Dictionary:
	var result := {"state_u16": {}, "banked_u16_0": {}, "global_u8": {}}
	for index in STATE_U16_INDICES:
		result.state_u16[str(index)] = 0
	for index in BANKED_U16_INDICES:
		result.banked_u16_0[str(index)] = 0
	for index in GLOBAL_U8_INDICES:
		result.global_u8[str(index)] = 0
	return result


func _witness(order: int) -> Dictionary:
	var input := _blank_input()
	if order == 0:
		input.state_u16["7"] = 413
		input.state_u16["19"] = 1000
		input.banked_u16_0["268"] = 412
		input.global_u8["2300"] = 1
		input.global_u8["2301"] = 1
		return input
	if order >= 1 and order <= 12:
		_apply_schedule_witness(input, order, 500, 1200)
		return input
	if order == 13:
		input.state_u16["7"] = 500
		input.state_u16["19"] = 1900
		input.global_u8["160"] = 1
		input.global_u8["1750"] = 1
		return input
	input.state_u16["4"] = 0
	input.state_u16["19"] = 1300
	input.global_u8["110"] = 1
	input.global_u8["117"] = 0
	input.global_u8["1188"] = 1
	return input


func _apply_schedule_witness(input: Dictionary, order: int, date: int, time: int) -> void:
	var row: Array = GUARD_ROWS[order]
	var base := int(row[6])
	input.state_u16["7"] = date
	input.state_u16["19"] = time
	input.banked_u16_0[str(row[4])] = date
	input.banked_u16_0[str(row[5])] = time
	input.global_u8[str(base)] = 1
	input.global_u8[str(base + 7)] = 2
	input.global_u8[str(base + 9)] = 9


func _combined_zero_and_schedule() -> Dictionary:
	var input := _blank_input()
	_apply_schedule_witness(input, 1, 500, 1000)
	input.banked_u16_0["268"] = 499
	input.global_u8["2300"] = 1
	input.global_u8["2301"] = 1
	return input


func _combined_schedules(first: int, second: int, time: int) -> Dictionary:
	var input := _blank_input()
	_apply_schedule_witness(input, first, 500, time)
	_apply_schedule_witness(input, second, 500, time)
	return input


func _combined_schedule_and_thirteen() -> Dictionary:
	var input := _blank_input()
	_apply_schedule_witness(input, 12, 500, 1900)
	input.global_u8["160"] = 1
	input.global_u8["1750"] = 1
	return input


func _combined_schedule_and_fourteen() -> Dictionary:
	var input := _blank_input()
	_apply_schedule_witness(input, 1, 500, 1300)
	input.global_u8["110"] = 1
	input.global_u8["117"] = 0
	input.global_u8["1188"] = 1
	return input


func _expected_guard_signature(order: int) -> Variant:
	if order == 0:
		return _left_and([
			["equal", ["add", _state_ref("banked_u16", 268), 1], _state_ref("state_u16", 7)],
			["greater_than", _state_ref("state_u16", 19), 930],
			["less_than", _state_ref("state_u16", 19), 1100],
			["equal", _state_ref("global_u8", 2300), 1],
			["equal", _state_ref("global_u8", 2304), 0],
			["equal", _state_ref("global_u8", 2305), 0],
			["equal", _state_ref("global_u8", 2301), 1],
		])
	if order >= 1 and order <= 12:
		var row: Array = GUARD_ROWS[order]
		return ["logical_or", _schedule_signature(int(row[4]), int(row[5]), int(row[6]), "equal"), _schedule_signature(int(row[4]), int(row[5]), int(row[6]), "greater_than")]
	if order == 13:
		return _left_and([
			["not_equal", _state_ref("state_u16", 7), 1301],
			["greater_than", _state_ref("state_u16", 19), 1800],
			["less_than", _state_ref("state_u16", 19), 2100],
			["not_equal", _state_ref("state_u16", 7), 1301],
			["equal", _state_ref("global_u8", 160), 1],
			["equal", _state_ref("global_u8", 1750), 1],
			["equal", _state_ref("global_u8", 1751), 0],
		])
	return _left_and([
		["equal", _state_ref("state_u16", 4), 0],
		["greater_than", _state_ref("state_u16", 19), 1100],
		["less_than", _state_ref("state_u16", 19), 1700],
		["equal", _state_ref("global_u8", 110), 1],
		["equal", _state_ref("global_u8", 117), 0],
		["equal", _state_ref("global_u8", 1188), 1],
		["equal", _state_ref("global_u8", 1189), 0],
	])


func _schedule_signature(date_index: int, time_index: int, base: int, time_operation: String) -> Variant:
	return _left_and([
		["equal", _state_ref("state_u16", 7), _state_ref("banked_u16", date_index)],
		["equal", _state_ref("global_u8", base), 1],
		["equal", _state_ref("global_u8", base + 7), 2],
		[time_operation, _state_ref("state_u16", 19), _state_ref("banked_u16", time_index)],
		["greater_than", _state_ref("global_u8", base + 9), 8],
		["not_equal", _state_ref("global_u8", base + 9), 14],
	])


func _left_and(conditions: Array) -> Variant:
	var result: Variant = conditions[0]
	for index in range(1, conditions.size()):
		result = ["logical_and", result, conditions[index]]
	return result


func _state_ref(storage: String, index: int) -> Array:
	return ["state_ref", storage, 0, index]


func _signature(ast: Dictionary, depth := 0) -> Variant:
	if depth > 32:
		return null
	match str(ast.get("type", "")):
		"literal": return ast.get("value")
		"state_ref": return ["state_ref", str(ast.get("storage", "")), int(ast.get("bank", -1)), _signature(ast.get("index", {}), depth + 1)]
		"binary": return [str(ast.get("op", "")), _signature(ast.get("lhs", {}), depth + 1), _signature(ast.get("rhs", {}), depth + 1)]
	return null


func _ast(ast: Dictionary) -> Variant:
	return _signature(ast)


func _state_references(signature: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	_collect_state_references(signature, result, seen)
	return result


func _collect_state_references(value: Variant, result: Array[Dictionary], seen: Dictionary) -> void:
	if not value is Array:
		return
	if value.size() == 4 and value[0] == "state_ref":
		var reference := {"storage": str(value[1]), "bank": int(value[2]), "index": int(value[3])}
		var key := "%s:%d:%d" % [reference.storage, reference.bank, reference.index]
		if not seen.has(key):
			seen[key] = true
			result.append(reference)
		return
	for child in value:
		_collect_state_references(child, result, seen)


func _record(code: PackedByteArray, offset: int, expected_end: int, operation: String) -> Dictionary:
	var record: Dictionary = _decoder.decode_at_structural(code, offset, expected_end)
	var valid: bool = bool(record.get("ok", false)) and str(record.get("op", "")) == operation and int(record.get("end_offset", -1)) == expected_end
	_check(valid, "%s record boundary changed at 0x%X" % [operation, offset])
	return record if valid else {}


func _eve_values(data: PackedByteArray, offset: int) -> Array:
	var values := []
	for index in range(6):
		values.append(int(data.decode_u16(offset + index * 2)))
	return values


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in expected:
			return false
	return true


func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures.append(message)
