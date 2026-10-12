extends SceneTree

# Metadata-only original-source proof. It does not execute the station host,
# native presentation, EVENTB03, or any original archive payload.
const Reader := preload("res://content_core/arc_reader.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Decoder := preload("res://content_core/mes_instruction_decoder.gd")
const ExpressionScript := preload("res://content_core/mes_expression.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const Plan := preload("res://content_core/mes_eventb03_candidate_plan.gd")
const Version := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const ARCHIVES := ["mes.arc", "mmo.arc", "data.arc", "bgm.arc", "se.arc", "voice.arc"]
const MES_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const STATION_SHA256 := "a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5"
const STATION_BYTECODE_SHA256 := "f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b"
const EVENT_SHA256 := "558532a9b034522db857d009132b6a89aa488e577277857cc90ce337c95ee230"
const GUARD_SHA256 := "7f8da510f2f3b0e7d3714812605da35f9f249321044f60e7dcb321b9c4c3c9d4"
const TRUE_SUFFIX_SHA256 := "da17019f9f71d69723776c60f867741fef82be605149a995cd22da5a7d95cfc0"
const ENTRY69_SUFFIX_SHA256 := "ca226e1542dc983b40ab32fbb298f2224ec1aa3d11d64089e0104f21d200e6d6"
const HANDOFF_SHA256 := "31be24c8ca3ec0e0613e2bced44ff4d9edcf70e7f4c4bfc821e2c4a407b6fde4"
const CANDIDATE_CHAIN_SHA256 := "f537624206b90bb337372f390f9731ed0b23b0e6d45a6e26a9d7246ea99d0fd1"

const BASE_INPUT := {
	"state_u16_7": 413,
	"state_u16_19": 1825,
	"banked_u16_210": 76,
	"global_u8_207": 0,
	"global_u8_333": 0,
	"global_u8_200": 0,
	"global_u8_400": 1,
	"global_u8_205": 0,
	"global_u8_631": 0,
	"state_u16_12": 100,
	"global_u8_628": 0,
}
const FALSE_CASES := [
	["date_lower", "state_u16_7", 400],
	["date_upper", "state_u16_7", 616],
	["time_lower", "state_u16_19", 1800],
	["time_upper", "state_u16_19", 2001],
	["affection_lower", "banked_u16_210", 40],
	["affection_upper", "banked_u16_210", 80],
	["global207_equal_two", "global_u8_207", 2],
	["global333_nonzero", "global_u8_333", 1],
	["global200_nonzero", "global_u8_200", 1],
	["global400_not_one", "global_u8_400", 0],
	["global205_nonzero", "global_u8_205", 1],
	["global631_nonzero", "global_u8_631", 1],
	["state12_zero", "state_u16_12", 0],
	["global628_nonzero", "global_u8_628", 1],
]
const PRIOR_FALSE_CHAIN := [
	[0x026D, 0x02A3, 0x247E],
	[0x247E, 0x24D7, 0x2AF7],
	[0x2AF7, 0x2B50, 0x3170],
	[0x3170, 0x31C9, 0x37E9],
	[0x37E9, 0x3842, 0x3E62],
	[0x3E62, 0x3EBB, 0x44DB],
	[0x44DB, 0x4534, 0x4B54],
	[0x4B54, 0x4BAD, 0x51CD],
	[0x51CD, 0x5226, 0x5846],
	[0x5846, 0x589F, 0x5EBF],
	[0x5EBF, 0x5F18, 0x6538],
	[0x6538, 0x6591, 0x6BB1],
	[0x6BB1, 0x6C0A, 0x722A],
	[0x722A, 0x725D, 0x73F5],
	[0x73F5, 0x7425, 0x7691],
]

var _checks := 0
var _failures: Array[String] = []
var _decoder := Decoder.new()
var _plans := Plan.new()


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: validate_mes_eventb03_candidate_plan.gd -- <ELFIMAGE-directory>")
		quit(2)
		return
	var source_root := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var before := {}
	for archive in ARCHIVES:
		var path := source_root.path_join(archive)
		if not FileAccess.file_exists(path):
			push_error("Required original archive unavailable: %s" % archive)
			quit(2)
			return
		before[archive] = FileAccess.get_sha256(path)
	_check(before["mes.arc"] == MES_SHA256, "original mes.arc identity changed")
	var mes := Reader.new()
	_check(mes.open(source_root.path_join("mes.arc")), "original mes.arc unavailable")
	if _failures.is_empty():
		_audit(mes)
	mes.close()
	for archive in ARCHIVES:
		_check(FileAccess.get_sha256(source_root.path_join(archive)) == before[archive], "%s changed during audit" % archive)
	if not _failures.is_empty():
		push_error("EVENTB03 candidate source audit failed: %s" % "; ".join(_failures))
		quit(1)
		return
	print("PASS: EVENTB03 source candidate plan: %d checks / one qualifying candidate / 14 independent false boundaries / 15 upstream false-chain guards; deterministic rebuild and JSON validation; six archives unchanged. %s / %s. Upstream preemption, native address-row selection, event eligibility and native cadence remain unresolved." % [_checks, Version.CORE_VERSION, Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA])
	quit(0)


func _audit(mes: RefCounted) -> void:
	_check(mes.get_archive_fingerprint() == MES_SHA256, "opened archive identity changed")
	_check(mes.get_entry_fingerprint("01M.MES") == STATION_SHA256, "01M.MES identity changed")
	_check(mes.get_entry_fingerprint("EVENTB03.MES") == EVENT_SHA256, "EVENTB03.MES identity changed")
	var payload: PackedByteArray = mes.read_entry("01M.MES")
	var payload_hash := ContractValues.sha256_lenient(payload)
	var document: Dictionary = ContainerScript.new().parse(payload, {
		"archive": "mes.arc", "entry": "01M.MES", "resolved_source": "original_arc",
	})
	_check(document.get("ok", false), "01M.MES container could not be parsed")
	if not document.get("ok", false):
		return
	_check(document.entry_sha256 == STATION_SHA256, "parsed 01M.MES identity changed")
	_check(document.bytecode_sha256 == STATION_BYTECODE_SHA256, "01M.MES bytecode identity changed")
	_validate_source(document)
	_validate_upstream_chain(document.bytecode)
	_validate_plans(payload, document)
	_check(ContractValues.sha256_lenient(payload) == payload_hash and payload_hash == STATION_SHA256, "audit changed its in-memory source payload")


func _validate_source(document: Dictionary) -> void:
	var code: PackedByteArray = document.bytecode
	_check(document.entries.size() == 426, "01M.MES address-table count changed")
	if document.entries.size() > 70:
		_check(document.entries[69] == {
			"id": "entry_0069", "index": 69, "offset": 0x7834,
			"file_offset": int(document.header.code_offset) + 0x7834,
			"end_offset": 0x7940, "size": 0x10C,
		}, "01M.MES entry 69 bounds changed")
	_check(ContractValues.sha256_lenient(code.slice(0x026D, 0x78A9)) == CANDIDATE_CHAIN_SHA256, "candidate-chain source bytes changed")
	_check(ContractValues.sha256_lenient(code.slice(0x7691, 0x76F1)) == GUARD_SHA256, "EVENTB03 candidate guard bytes changed")
	_check(ContractValues.sha256_lenient(code.slice(0x76F1, 0x789F)) == TRUE_SUFFIX_SHA256, "EVENTB03 candidate true suffix changed")
	_check(ContractValues.sha256_lenient(code.slice(0x7834, 0x789F)) == ENTRY69_SUFFIX_SHA256, "entry 69 suffix changed")
	_check(ContractValues.sha256_lenient(code.slice(0x788F, 0x789F)) == HANDOFF_SHA256, "EVENTB03 handoff envelope changed")

	var guard := _record(code, 0x7691, 0x76F1, "branch_if_not_true")
	if not guard.is_empty():
		var expected := [
			["greater_than", ["state_u16", 0, 7], 400],
			["less_than", ["state_u16", 0, 7], 616],
			["greater_than", ["state_u16", 0, 19], 1800],
			["less_than", ["state_u16", 0, 19], 2001],
			["greater_than", ["banked_u16", 0, 210], 40],
			["less_than", ["banked_u16", 0, 210], 80],
			["not_equal", ["global_u8", 0, 207], 2],
			["equal", ["global_u8", 0, 333], 0],
			["equal", ["global_u8", 0, 200], 0],
			["equal", ["global_u8", 0, 400], 1],
			["equal", ["global_u8", 0, 205], 0],
			["equal", ["global_u8", 0, 631], 0],
			["not_equal", ["state_u16", 0, 12], 0],
			["equal", ["global_u8", 0, 628], 0],
		]
		_check(_flatten_and(guard.operands[0].value.ast) == expected, "EVENTB03 candidate guard AST changed")
		_check(guard.operands[1].value == 0x78A9, "EVENTB03 candidate false target changed")

	_check(_argument_write(code, 0x76FB, 0x7703, 133), "routine23 argument changed")
	_check(_routine_call(code, 0x7703, 0x7708, 23), "routine23 call changed")
	for row in [
		[66, 0x7712, 0x7717, 0x775A, 0x7760, 0x7760, 0x7765],
		[67, 0x779E, 0x77A3, 0x77D6, 0x77DC, 0x77DC, 0x77E1],
		[68, 0x77E6, 0x77EB, 0x7824, 0x782A, 0x782A, 0x782F],
		[69, 0x7834, 0x7839, 0x787F, 0x7885, 0x7885, 0x788A],
	]:
		var label := _record(code, row[1], row[2], "entry_label")
		if not label.is_empty():
			_check(label.operands[0].value == row[0], "entry label changed at 0x%X" % row[1])
		_check(_argument_write(code, row[3], row[4], row[0]), "routine0 argument changed at 0x%X" % row[3])
		_check(_routine_call(code, row[5], row[6], 0), "routine0 call changed at 0x%X" % row[5])
	var enable := _record(code, 0x776A, 0x7777, "banked_u16_write_run")
	if not enable.is_empty():
		_check(_banked_write(enable, 2, ["bit_or", ["banked_u16", 0, 2], 128]), "voice-enable bit write changed")
	var voice := _record(code, 0x7777, 0x778C, "voice_marker")
	if not voice.is_empty():
		_check(str(voice.operands[0].name).to_upper() == "B0001.OGG", "candidate voice marker changed")
	var disable := _record(code, 0x778C, 0x7799, "banked_u16_write_run")
	if not disable.is_empty():
		_check(_banked_write(disable, 2, ["bit_and", ["banked_u16", 0, 2], 65407]), "voice-disable bit write changed")
	var handoff := _record(code, 0x788F, 0x789F, "script_handoff_marker")
	if not handoff.is_empty():
		_check(str(handoff.get("script_target", "")).to_upper() == "EVENTB03.MES", "EVENTB03 handoff target changed")


func _validate_upstream_chain(code: PackedByteArray) -> void:
	var state: KakyuMesSandboxState = _state_from(BASE_INPUT)
	var before: Dictionary = state.snapshot()
	var cursor := 0x026D
	for row in PRIOR_FALSE_CHAIN:
		_check(cursor == row[0], "upstream false-chain cursor changed")
		var guard := _record(code, row[0], row[1], "branch_if_not_true")
		if guard.is_empty():
			return
		var evaluated: Dictionary = ExpressionScript.new().evaluate(guard.operands[0].value.ast, state)
		_check(evaluated.get("ok", false) and evaluated.get("value", -1) == 0, "representative state no longer rejects upstream candidate at 0x%X" % row[0])
		_check(guard.operands[1].value == row[2], "upstream candidate false target changed at 0x%X" % row[0])
		cursor = int(guard.operands[1].value)
	_check(cursor == 0x7691, "upstream false-chain no longer joins the EVENTB03 candidate")
	var candidate := _record(code, 0x7691, 0x76F1, "branch_if_not_true")
	if not candidate.is_empty():
		var evaluated: Dictionary = ExpressionScript.new().evaluate(candidate.operands[0].value.ast, state)
		_check(evaluated.get("ok", false) and evaluated.get("value", -1) == 1, "representative EVENTB03 candidate is not true")
	_check(state.snapshot() == before, "source-condition evaluation changed the representative state")


func _validate_plans(payload: PackedByteArray, document: Dictionary) -> void:
	var input := BASE_INPUT.duplicate(true)
	var input_before := JSON.stringify(input)
	var source_before := ContractValues.sha256_lenient(payload)
	var source_guard := _record(document.bytecode, 0x7691, 0x76F1, "branch_if_not_true")
	if source_guard.is_empty():
		return
	var plan: Dictionary = _plans.build(payload, input)
	_check(plan.get("ok", false), "qualifying candidate plan failed: %s" % plan.get("error", ""))
	if plan.get("ok", false):
		_check(plan.get("schema", "") == Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA, "candidate plan schema changed")
		_check(plan.keys() == ["ok", "guard", "true_path", "excluded_tail", "schema", "producer", "source", "input", "candidate", "selected_boundary", "execution"], "candidate plan root shape changed")
		_check(plan.producer == {"core_version": Version.CORE_VERSION, "instruction_schema": Version.MES_INSTRUCTION_SCHEMA}, "candidate plan producer changed")
		_check(plan.get("input", {}) == input, "candidate plan input changed")
		_check(_plans.validate(payload, plan).get("ok", false), "candidate plan failed source replay validation")
		var reloaded: Variant = JSON.parse_string(JSON.stringify(plan))
		_check(reloaded is Dictionary and _plans.validate(payload, reloaded).get("ok", false), "candidate plan failed JSON round-trip validation")
		_check(_plans.build(payload, input) == plan, "candidate plan rebuild is nondeterministic")
		_check(plan.source == {
			"archive": "mes.arc", "entry": "01M.MES", "entry_sha256": STATION_SHA256,
			"bytecode_sha256": STATION_BYTECODE_SHA256, "offset_basis": "code_start",
			"guard_offset": 0x7691, "guard_end_offset": 0x76F1,
			"candidate_true_offset": 0x76F1, "candidate_false_offset": 0x78A9,
			"handoff_offset": 0x788F, "handoff_end_offset": 0x789F,
			"entry_69_end_offset": 0x7940,
		}, "candidate plan source qualification changed")
		_check(plan.guard == {
			"offset": 0x7691,
			"end_offset": 0x76F1,
			"false_offset": 0x78A9,
			"sha256": GUARD_SHA256,
			"unique_state_reference_count": 11,
			"predicate_signature": _expected_predicate_signature(),
		}, "candidate guard proof changed")
		_check(
			plan.true_path.offset == 0x76F1
			and plan.true_path.end_offset == 0x789F
			and plan.true_path.sha256 == TRUE_SUFFIX_SHA256
			and plan.true_path.routine23_request == {
				"argument_offset": 0x76FB,
				"call_offset": 0x7703,
				"routine_id": 23,
				"selector": 133,
			},
			"candidate true-path proof changed"
		)
		var handoff_boundary := {
			"kind": "script_handoff_boundary", "offset": 0x788F, "end_offset": 0x789F,
			"command": 0x0E, "target_entry": "EVENTB03.MES",
			"target_start_coordinate": "not_encoded", "caller_frame": "not_encoded",
			"sha256": HANDOFF_SHA256,
		}
		_check(plan.true_path.handoff == handoff_boundary and plan.selected_boundary == handoff_boundary, "qualifying plan script-handoff boundary changed")
		_check(plan.excluded_tail == {
			"kind": "excluded_after_script_handoff",
			"offset": 0x789F,
			"end_offset": 0x7940,
			"sha256": ContractValues.sha256_lenient(document.bytecode.slice(0x789F, 0x7940)),
			"tool_executed": false,
			"native_post_handoff": "unresolved",
		}, "post-handoff tail boundary changed")
		_check(plan.execution == {"kind": "read_only_projection", "state_mutation": false, "compatibility": "remake_only", "natural_scheduler_eligibility": "unqualified", "upstream_preemption": "unresolved", "native_cadence": "unresolved", "post_handoff_tool_execution": false}, "candidate plan promoted unresolved upstream eligibility")
		_check(plan.candidate == {"matched": true, "value": 1, "next_offset": 0x76F1}, "qualifying plan did not retain a true candidate result")
	for specification in FALSE_CASES:
		var changed := BASE_INPUT.duplicate(true)
		changed[specification[1]] = specification[2]
		var saved := JSON.stringify(changed)
		var source_state: KakyuMesSandboxState = _state_from(changed)
		var state_before: Dictionary = source_state.snapshot()
		var source_value: Dictionary = ExpressionScript.new().evaluate(source_guard.operands[0].value.ast, source_state)
		_check(source_value.get("ok", false) and source_value.get("value", -1) == 0 and source_state.snapshot() == state_before, "%s is not an independent source-level false boundary" % specification[0])
		var false_plan: Dictionary = _plans.build(payload, changed)
		_check(false_plan.get("ok", false), "%s false-boundary plan failed: %s" % [specification[0], false_plan.get("error", "")])
		if false_plan.get("ok", false):
			_check(false_plan.candidate == {"matched": false, "value": 0, "next_offset": 0x78A9}, "%s did not produce candidate false" % specification[0])
			_check(false_plan.selected_boundary == {"kind": "candidate_false_boundary", "offset": 0x78A9, "end_offset": 0x78A9}, "%s false boundary changed" % specification[0])
			_check(false_plan.execution.upstream_preemption == "unresolved" and false_plan.execution.natural_scheduler_eligibility == "unqualified", "%s promoted scheduler eligibility" % specification[0])
			_check(_plans.validate(payload, false_plan).get("ok", false), "%s plan failed source replay validation" % specification[0])
			var reloaded: Variant = JSON.parse_string(JSON.stringify(false_plan))
			_check(reloaded is Dictionary and _plans.validate(payload, reloaded).get("ok", false), "%s plan failed JSON round-trip validation" % specification[0])
			_check(_plans.build(payload, changed) == false_plan, "%s plan rebuild is nondeterministic" % specification[0])
		_check(JSON.stringify(changed) == saved, "%s plan construction changed its input" % specification[0])
	if plan.get("ok", false):
		var fabricated_start: Dictionary = plan.duplicate(true)
		fabricated_start.true_path.handoff.target_start_coordinate = 0
		fabricated_start.selected_boundary.target_start_coordinate = 0
		_check(not _plans.validate(payload, fabricated_start).get("ok", true), "source-local handoff accepted an invented target start coordinate")
		var promoted: Dictionary = plan.duplicate(true)
		promoted.execution.natural_scheduler_eligibility = "qualified"
		_check(not _plans.validate(payload, promoted).get("ok", true), "candidate plan accepted promoted natural-scheduler eligibility")
	_check(JSON.stringify(input) == input_before and ContractValues.sha256_lenient(payload) == source_before, "plan probes changed their input or source bytes")


func _state_from(input: Dictionary) -> KakyuMesSandboxState:
	var state := State.new(1)
	state.write_value("state_u16", 7, input.state_u16_7)
	state.write_value("state_u16", 19, input.state_u16_19)
	state.write_value("banked_u16", 210, input.banked_u16_210, 0)
	state.write_value("global_u8", 207, input.global_u8_207)
	state.write_value("global_u8", 333, input.global_u8_333)
	state.write_value("global_u8", 200, input.global_u8_200)
	state.write_value("global_u8", 400, input.global_u8_400)
	state.write_value("global_u8", 205, input.global_u8_205)
	state.write_value("global_u8", 631, input.global_u8_631)
	state.write_value("state_u16", 12, input.state_u16_12)
	state.write_value("global_u8", 628, input.global_u8_628)
	return state


func _record(code: PackedByteArray, offset: int, end: int, operation: String) -> Dictionary:
	var record: Dictionary = _decoder.decode_at_structural(code, offset, end)
	var valid: bool = record.get("ok", false) and record.get("op", "") == operation and record.get("end_offset", -1) == end
	_check(valid, "%s record boundary changed at 0x%X" % [operation, offset])
	return record if valid else {}


func _argument_write(code: PackedByteArray, offset: int, end: int, value: int) -> bool:
	var record := _record(code, offset, end, "argument_slot_write_run")
	if record.is_empty():
		return false
	var pairs: Array = record.operands[1].get("pairs", [])
	return record.operands[0].value == 1 and pairs.size() == 1 and pairs[0].continuation == 0 and _ast(pairs[0].expression.ast) == value


func _routine_call(code: PackedByteArray, offset: int, end: int, routine_id: int) -> bool:
	var record := _record(code, offset, end, "script_transfer")
	if record.is_empty():
		return false
	var records: Array = record.operands[0].get("records", [])
	return records.size() == 1 and _ast(records[0].value.ast) == routine_id


func _banked_write(record: Dictionary, index: int, expression: Variant) -> bool:
	var pairs: Array = record.operands[2].get("pairs", [])
	return _ast(record.operands[0].value.ast) == index and record.operands[1].value == 0 and pairs.size() == 1 and pairs[0].continuation == 0 and _ast(pairs[0].expression.ast) == expression


func _flatten_and(ast: Dictionary) -> Array:
	if ast.get("type", "") == "binary" and ast.get("op", "") == "logical_and":
		var result := _flatten_and(ast.get("lhs", {}))
		result.append_array(_flatten_and(ast.get("rhs", {})))
		return result
	return [_ast(ast)]


func _expected_predicate_signature() -> Variant:
	var conditions: Array = [
		["greater_than", ["state_ref", "state_u16", 0, 7], 400],
		["less_than", ["state_ref", "state_u16", 0, 7], 616],
		["greater_than", ["state_ref", "state_u16", 0, 19], 1800],
		["less_than", ["state_ref", "state_u16", 0, 19], 2001],
		["greater_than", ["state_ref", "banked_u16", 0, 210], 40],
		["less_than", ["state_ref", "banked_u16", 0, 210], 80],
		["not_equal", ["state_ref", "global_u8", 0, 207], 2],
		["equal", ["state_ref", "global_u8", 0, 333], 0],
		["equal", ["state_ref", "global_u8", 0, 200], 0],
		["equal", ["state_ref", "global_u8", 0, 400], 1],
		["equal", ["state_ref", "global_u8", 0, 205], 0],
		["equal", ["state_ref", "global_u8", 0, 631], 0],
		["not_equal", ["state_ref", "state_u16", 0, 12], 0],
		["equal", ["state_ref", "global_u8", 0, 628], 0],
	]
	var result: Variant = conditions[0]
	for index in range(1, conditions.size()):
		result = ["logical_and", result, conditions[index]]
	return result


func _ast(ast: Dictionary) -> Variant:
	match str(ast.get("type", "")):
		"literal":
			return ast.get("value")
		"state_ref":
			return [ast.get("storage"), ast.get("bank"), _ast(ast.get("index", {}))]
		"binary":
			return [ast.get("op"), _ast(ast.get("lhs", {})), _ast(ast.get("rhs", {}))]
	return {"unsupported": ast.get("type", "missing")}


func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures.append(message)
