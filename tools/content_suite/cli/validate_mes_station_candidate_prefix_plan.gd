extends SceneTree

# Authoritative-source, metadata-only validation. The prefix, its external
# boundaries, and the station host are never executed by this script.
const Reader := preload("res://content_core/arc_reader.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Decoder := preload("res://content_core/mes_instruction_decoder.gd")
const Plan := preload("res://content_core/mes_station_candidate_prefix_plan.gd")
const Version := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const ArchiveIdentity := preload("res://content_core/original_archive_identity.gd")

const ARCHIVE_SHA256 := ArchiveIdentity.SIX_ARCHIVE_SHA256
const STATION_SHA256 := "a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5"
const STATION_BYTECODE_SHA256 := "f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b"
const STATION_PREFIX_SHA256 := "4a669e767c925e7a988c0b7c169be9a250095a3091d4d20bb1d4e7b0cde24289"
const STATION_BOOTSTRAP_SHA256 := "1d5fcfa66928c2bd712394fcd5e001e48b41b60f943039c72d06687224953e5c"
const MACHI_SHA256 := "56b0f4243f3c0944624ea0ef11b369391761ff394816775264c144bb76391488"
const MACHI_BYTECODE_SHA256 := "34aea9b95996997a4657c89e848b59c0d04c1ba1fdeb26794252017b1d1a84cf"
const MACHI_EVE_SHA256 := "9f56d74f8c53fc3ee2ad17918519f677e3ebf9070097921190e3ea6de2833d62"
const MACHI_EVENT16_GUARD_SHA256 := "e388389b8096d854a52c12203969a7b73cfc2369bb5f6267b3d1b4d1266893fd"
const MACHI_01M_HANDOFF_SHA256 := "7d254587b79c85522f184d95301f986a3f72510128d8920dc163d7868c81c612"
const MACHI_POST_HANDOFF_MARKER_SHA256 := "df6bcfedc4d229399c926e15ae84f4f67237f2122c06ce9c4f73385bf445adb6"
const MACHI_CALLER_CONTINUATION_SHA256 := "6d6a16f278741ca272be6d6092ce6e28c54f9b0b7fbf61e4043a7acbe23f0c19"
const MACHI_EVENT16_WINDOW_SHA256 := "f51d62ca684a53369857e2d7105a9a8d6209fd69533674c07b83a69ebecbfb84"
const MACHI_EVE16_SHA256 := "538fe2444347fb43fb1c0c93bfb7297b589835cc2b1ef1e99a875d4b035edb0a"

const PREFIX_OFFSET := 0x0008
const PREFIX_END := 0x026D
const RECORD_COUNT := 103
const EXPECTED_OP_COUNTS := {
	"argument_slot_write_run": 1,
	"ax_presentation_control": 3,
	"banked_u16_write_run": 3,
	"branch_if_not_true": 2,
	"command_1b": 17,
	"continuation_transfer": 2,
	"definition_invoke": 1,
	"entry_label": 1,
	"global_u8_write_run": 18,
	"native_record_dispatch": 3,
	"script_transfer": 5,
	"source_line_marker": 42,
	"state_u16_write_run": 4,
	"surface_operation": 1,
}

var _checks := 0
var _failures: Array[String] = []
var _decoder := Decoder.new()
var _plans := Plan.new()


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: validate_mes_station_candidate_prefix_plan.gd -- <ELFIMAGE-directory>")
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
		push_error("Station candidate prefix source validation failed: %s" % "; ".join(_failures))
		quit(1)
		return
	print("PASS: station candidate prefix source plan: %d checks / exact [0x0008,0x026D) / 103 typed records / 0 opaque / 16-copy local loop / g2847 two-arm join / 13 ordered non-executing external boundaries / MACHI event-16 host metadata kept separate / deterministic JSON replay. Host zero-start and native address-row selection remain unresolved; natural eligibility remains unqualified. Six archives unchanged. %s / %s" % [_checks, Version.CORE_VERSION, Version.MES_STATION_CANDIDATE_PREFIX_PLAN_SCHEMA])
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
	_validate_separate_host_metadata(station, machi, eve_payload)
	var partition := _decode_prefix_partition(station.bytecode)
	_validate_typed_semantics(station.bytecode)
	if not _failures.is_empty():
		return
	_validate_plan(station_payload, partition)
	_validate_rejections(station_payload)
	_check(source_hashes == [ContractValues.sha256(station_payload), ContractValues.sha256(machi_payload), ContractValues.sha256(eve_payload)], "validation changed an in-memory original source")


func _validate_separate_host_metadata(station: Dictionary, machi: Dictionary, eve: PackedByteArray) -> void:
	var station_code: PackedByteArray = station.bytecode
	_check(station.entries.size() == 426, "01M.MES address-table count changed")
	if station.entries.size() > 0:
		_check(int(station.entries[0].offset) == PREFIX_OFFSET and int(station.entries[0].end_offset) == 0x03AF, "01M.MES entry-zero bounds changed")
	_check(ContractValues.sha256(station_code.slice(0, 8)) == STATION_BOOTSTRAP_SHA256 and station_code.slice(0, 8) == PackedByteArray([0x14, 0x12, 0xFF, 0x08, 0, 0, 0, 0]), "01M.MES coordinate-zero bootstrap bytes changed")
	var bootstrap := _record(station_code, 0x0000, 0x0007, "bootstrap_transfer")
	if not bootstrap.is_empty():
		_check(_signature(bootstrap.operands[0].value.ast) == 18 and int(bootstrap.operands[1].value) == PREFIX_OFFSET, "01M.MES bootstrap selector or target changed")
	_record(station_code, 0x0007, 0x0008, "command_00")

	var machi_code: PackedByteArray = machi.bytecode
	_check(machi.entries.size() > 189 and int(machi.entries[189].offset) == 0xABC0 and int(machi.entries[189].end_offset) == 0xAD66, "MACHI event-dispatch address row 189 bounds changed")
	_check(ContractValues.sha256(machi_code.slice(0xACA2, 0xACC6)) == MACHI_EVENT16_WINDOW_SHA256, "MACHI event-16 guard/handoff/continuation window changed")
	_check(ContractValues.sha256(machi_code.slice(0xACA2, 0xACAC)) == MACHI_EVENT16_GUARD_SHA256, "MACHI event-16 guard bytes changed")
	var guard := _record(machi_code, 0xACA2, 0xACAC, "branch_if_not_true")
	if not guard.is_empty():
		_check(_signature(guard.operands[0].value.ast) == ["equal", _state_ref("state_u16", 21), 16] and int(guard.operands[1].value) == 0xACC6, "MACHI event-16 predicate or false edge changed")
	_check(ContractValues.sha256(machi_code.slice(0xACB1, 0xACBC)) == MACHI_01M_HANDOFF_SHA256, "MACHI 01M handoff bytes changed")
	var handoff := _record(machi_code, 0xACB1, 0xACBC, "script_handoff_marker")
	if not handoff.is_empty():
		_check(str(handoff.get("script_target", "")).to_upper() == "01M.MES", "MACHI event-16 handoff target changed")
	_check(ContractValues.sha256(machi_code.slice(0xACBC, 0xACC1)) == MACHI_POST_HANDOFF_MARKER_SHA256, "MACHI post-handoff source marker bytes changed")
	_record(machi_code, 0xACBC, 0xACC1, "source_line_marker")
	_check(ContractValues.sha256(machi_code.slice(0xACC1, 0xACC6)) == MACHI_CALLER_CONTINUATION_SHA256, "MACHI caller-local continuation bytes changed")
	var continuation := _record(machi_code, 0xACC1, 0xACC6, "continuation_transfer")
	if not continuation.is_empty():
		_check(int(continuation.operands[0].value) == 0xEC21, "MACHI caller-local continuation target changed")

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

	# The v317 host slice resolves the receiver filename but not these three
	# questions. Keep them explicitly negative rather than promoting adjacency
	# or the coordinate-zero bootstrap into an observed native start contract.
	var evidence_boundary := {
		"host_activation_slice_schema": "kakyu_mes_host_activation_slice_audit/v46",
		"receiver_target": "01M.MES",
		"host_zero_start": "unresolved",
		"native_address_row_selection": "unresolved",
		"natural_scheduler_eligibility": "unqualified",
	}
	_check(evidence_boundary.host_zero_start == "unresolved" and evidence_boundary.native_address_row_selection == "unresolved" and evidence_boundary.natural_scheduler_eligibility == "unqualified", "static host evidence was promoted beyond v317")


func _decode_prefix_partition(code: PackedByteArray) -> Array[Dictionary]:
	_check(code.size() >= PREFIX_END, "01M.MES bytecode is shorter than the prefix")
	_check(ContractValues.sha256(code.slice(PREFIX_OFFSET, PREFIX_END)) == STATION_PREFIX_SHA256, "station candidate prefix exact source hash changed")
	var records: Array[Dictionary] = []
	var op_counts := {}
	var cursor := PREFIX_OFFSET
	while cursor < PREFIX_END:
		var record: Dictionary = _decoder.decode_at_structural(code, cursor, PREFIX_END)
		var end_offset := int(record.get("end_offset", -1))
		if not record.get("ok", false) or end_offset <= cursor or end_offset > PREFIX_END:
			_check(false, "prefix structural decode failed at 0x%X" % cursor)
			break
		var operation := str(record.get("op", ""))
		_check(not operation.is_empty() and "opaque" not in operation, "prefix record at 0x%X was not typed" % cursor)
		records.append({
			"order": records.size(),
			"offset": cursor,
			"end_offset": end_offset,
			"op": operation,
			"sha256": ContractValues.sha256(code.slice(cursor, end_offset)),
		})
		op_counts[operation] = int(op_counts.get(operation, 0)) + 1
		cursor = end_offset
	_check(cursor == PREFIX_END, "prefix partition did not end exactly at 0x026D")
	_check(records.size() == RECORD_COUNT, "prefix typed record count changed")
	_check(op_counts == EXPECTED_OP_COUNTS, "prefix typed opcode census changed")
	return records


func _validate_typed_semantics(code: PackedByteArray) -> void:
	var entry := _record(code, 0x0008, 0x000D, "entry_label")
	_check(not entry.is_empty() and int(entry.operands[0].value) == 0, "prefix entry label changed")
	for selector in range(1, 18):
		var manager := _record(code, 0x000D + (selector - 1) * 5, 0x0012 + (selector - 1) * 5, "command_1b")
		_check(not manager.is_empty() and _literal_record(manager, selector), "manager-vector selector %d changed" % selector)
	for index in range(10, 21):
		var write := _record(code, 0x00D0 + (index - 10) * 6, 0x00D6 + (index - 10) * 6, "global_u8_write_run")
		_check(not write.is_empty() and _simple_write(write, index, 0), "global_u8[%d] prefix clear changed" % index)
	_check(_simple_write(_record(code, 0x0117, 0x011E, "global_u8_write_run"), 350, ["call", "random_below", [3]]), "global_u8[350] random write changed")
	_check(_simple_write(_record(code, 0x0123, 0x012A, "global_u8_write_run"), 351, ["call", "random_below", [13]]), "global_u8[351] random write changed")
	_check(_simple_write(_record(code, 0x013E, 0x0143, "state_u16_write_run"), 2, 15), "state_u16[2] pre-DEF write changed")
	_check(_literal_record(_record(code, 0x0143, 0x0148, "definition_invoke"), 11), "DEF 11 boundary changed")
	_check(_simple_write(_record(code, 0x014D, 0x0152, "state_u16_write_run"), 2, 1), "state_u16[2] pre-routine write changed")
	_check(_literal_record(_record(code, 0x0152, 0x0157, "script_transfer"), 32), "routine 32 boundary changed")
	_check(_ax_selector(_record(code, 0x015C, 0x0163, "ax_presentation_control"), 7), "AX selector 7 boundary changed")
	_check(_simple_write(_record(code, 0x0163, 0x0169, "global_u8_write_run"), 3005, 15), "global_u8[3005] write changed")
	_check(_simple_write(_record(code, 0x0169, 0x016E, "state_u16_write_run"), 2, 0), "copy-loop initialization changed")
	var loop_guard := _record(code, 0x016E, 0x0178, "branch_if_not_true")
	_check(_branch(loop_guard, ["less_than", _state_ref("state_u16", 2), 16], 0x0196), "copy-loop guard changed")
	_check(_loop_copy(_record(code, 0x0178, 0x0189, "banked_u16_write_run")), "copy-loop source or destination changed")
	_check(_simple_write(_record(code, 0x0189, 0x0191, "state_u16_write_run"), 2, ["add", _state_ref("state_u16", 2), 1]), "copy-loop increment changed")
	_check(_continuation(_record(code, 0x0191, 0x0196, "continuation_transfer"), 0x016E), "copy-loop back edge changed")
	_check(_simple_write(_record(code, 0x0196, 0x019C, "global_u8_write_run"), 3000, 0), "global_u8[3000] pre-routine write changed")
	_check(_literal_record(_record(code, 0x019C, 0x01A1, "script_transfer"), 25), "first routine 25 boundary changed")
	for specification in [[0x01A1, 0x01A9, [6, 2]], [0x01A9, 0x01B1, [6, 6]], [0x01B1, 0x01B9, [6, 10]]]:
		_check(_native_records(_record(code, specification[0], specification[1], "native_record_dispatch"), specification[2]), "native dispatch at 0x%X changed" % specification[0])
	_check(_ax_selector(_record(code, 0x01C3, 0x01CA, "ax_presentation_control"), 6), "AX selector 6 boundary changed")
	_check(_ax_selector(_record(code, 0x01CA, 0x01D1, "ax_presentation_control"), 8), "AX selector 8 boundary changed")
	_check(_banked_write(_record(code, 0x01D1, 0x01D8, "banked_u16_write_run"), 1, 0, 1), "banked_u16[1] = 1 changed")
	_check(_simple_write(_record(code, 0x01D8, 0x01DE, "argument_slot_write_run"), 1, 11), "argument slot 1 write changed")
	_check(_literal_record(_record(code, 0x01DE, 0x01E3, "script_transfer"), 27), "routine 27 boundary changed")
	_check(_banked_write(_record(code, 0x01E3, 0x01EA, "banked_u16_write_run"), 1, 0, 7), "banked_u16[1] = 7 changed")
	_check(_literal_record(_record(code, 0x01EA, 0x01EF, "script_transfer"), 25), "second routine 25 boundary changed")
	var surface_guard := _record(code, 0x01EF, 0x01FA, "branch_if_not_true")
	_check(_branch(surface_guard, ["equal", _state_ref("global_u8", 2847), 1], 0x0224), "global_u8[2847] surface branch changed")
	_check(_surface_operation(_record(code, 0x01FA, 0x021F, "surface_operation")), "surface-operation envelope changed")
	_check(_continuation(_record(code, 0x021F, 0x0224, "continuation_transfer"), 0x0229), "surface true-arm join changed")
	_check(_literal_record(_record(code, 0x0224, 0x0229, "script_transfer"), 21), "surface false-arm routine 21 changed")
	for specification in [[0x0229, 0x022F, 2836], [0x022F, 0x0235, 3000], [0x0235, 0x023B, 2841]]:
		_check(_simple_write(_record(code, specification[0], specification[1], "global_u8_write_run"), specification[2], 0), "post-branch write at 0x%X changed" % specification[0])


func _validate_plan(payload: PackedByteArray, partition: Array[Dictionary]) -> void:
	var source_before := ContractValues.sha256(payload)
	var plan: Dictionary = _plans.build(payload)
	_check(plan.get("ok", false), "prefix plan failed: %s" % plan.get("error", ""))
	if not plan.get("ok", false):
		return
	_check(_has_exact_keys(plan, ["ok", "schema", "producer", "source", "record_partition", "local_flow", "symbolic_effects", "external_boundaries", "execution"]), "prefix plan root key set changed")
	_check(plan.schema == Version.MES_STATION_CANDIDATE_PREFIX_PLAN_SCHEMA, "prefix plan schema changed")
	_check(plan.producer == {"core_version": Version.CORE_VERSION, "instruction_schema": Version.MES_INSTRUCTION_SCHEMA}, "prefix plan producer changed")
	_check(plan.source == {
		"archive": "mes.arc", "entry": "01M.MES", "entry_sha256": STATION_SHA256,
		"bytecode_sha256": STATION_BYTECODE_SHA256, "offset_basis": "code_start",
		"address_entry_index": 0, "address_entry_offset": PREFIX_OFFSET,
		"address_entry_end_offset": 0x03AF, "prefix_offset": PREFIX_OFFSET,
		"prefix_end_offset": PREFIX_END, "prefix_sha256": STATION_PREFIX_SHA256,
	}, "prefix plan source qualification changed")
	_check(plan.record_partition == {
		"offset": PREFIX_OFFSET, "end_offset": PREFIX_END, "record_count": RECORD_COUNT,
		"typed_record_count": RECORD_COUNT, "opaque_record_count": 0, "records": partition,
	}, "prefix plan partition no longer matches independent structural decoding")
	var by_offset := _records_by_offset(partition)
	_check(plan.local_flow == _expected_local_flow(by_offset), "prefix local CFG changed")
	_check(plan.symbolic_effects == _expected_symbolic_effects(), "prefix symbolic effects changed")
	_check(plan.external_boundaries == _expected_external_boundaries(by_offset), "prefix ordered external-boundary ledger changed")
	_check(plan.execution == {
		"kind": "read_only_symbolic_projection",
		"mes_instruction_execution": false,
		"local_effect_application": false,
		"external_call_execution": false,
		"native_effect_execution": false,
		"state_mutation": false,
		"post_prefix_state": "not_computed",
		"external_completion": "unresolved",
		"prefix_join_reachability": "conditional",
		"entry_zero_reachability": "unqualified",
		"host_zero_start": "unresolved",
		"native_address_row_selection": "unresolved",
		"natural_scheduler_eligibility": "unqualified",
		"native_cadence": "unresolved",
	}, "prefix plan promoted execution, completion, or host eligibility")
	_check(_plans.validate(payload, plan).get("ok", false), "prefix plan failed source replay validation")
	var reloaded: Variant = JSON.parse_string(JSON.stringify(plan))
	_check(reloaded is Dictionary and _plans.validate(payload, reloaded).get("ok", false), "prefix plan failed JSON round-trip validation")
	_check(_plans.build(payload) == plan, "prefix plan rebuild is nondeterministic")
	_check(ContractValues.sha256(payload) == source_before, "prefix plan build or validation changed source bytes")


func _validate_rejections(payload: PackedByteArray) -> void:
	var payload_before := ContractValues.sha256(payload)
	var plan: Dictionary = _plans.build(payload)
	if not plan.get("ok", false):
		return
	var mutations := [
		[["schema"], "unqualified"],
		[["source", "prefix_end_offset"], 0x026E],
		[["record_partition", "typed_record_count"], 102],
		[["record_partition", "opaque_record_count"], 1],
		[["record_partition", "records", 67, "end_offset"], 0x016F],
		[["record_partition", "records", 68, "sha256"], "unqualified"],
		[["local_flow", "loop", "local_iteration_count"], 15],
		[["local_flow", "surface_branch", "guard", "false_offset"], 0x0229],
		[["symbolic_effects", 7, "count"], 15],
		[["external_boundaries", 0, "tool_execution"], true],
		[["external_boundaries", 3, "completion"], "returns"],
		[["external_boundaries", 11, "condition"], "always"],
		[["execution", "post_prefix_state"], "computed"],
		[["execution", "prefix_join_reachability"], "unconditional"],
		[["execution", "host_zero_start"], 0],
		[["execution", "native_address_row_selection"], "entry_0"],
		[["execution", "natural_scheduler_eligibility"], "qualified"],
	]
	for mutation in mutations:
		var changed: Dictionary = plan.duplicate(true)
		var target: Variant = changed
		var path: Array = mutation[0]
		for index in range(path.size() - 1):
			target = target[path[index]]
		target[path[-1]] = mutation[1]
		var before := JSON.stringify(changed)
		_check(not _plans.validate(payload, changed).get("ok", true) and JSON.stringify(changed) == before, "mutated plan accepted or rewritten: %s" % str(path))
	var extra: Dictionary = plan.duplicate(true)
	extra["host_start_offset"] = 0
	_check(not _plans.validate(payload, extra).get("ok", true), "plan accepted an invented host start field")
	var missing: Dictionary = plan.duplicate(true)
	missing.erase("execution")
	_check(not _plans.validate(payload, missing).get("ok", true), "plan accepted a missing execution boundary")
	var changed_prefix := payload.duplicate()
	var document: Dictionary = ContainerScript.new().parse(payload)
	var prefix_file_offset := int(document.get("header", {}).get("code_offset", -PREFIX_OFFSET)) + PREFIX_OFFSET
	changed_prefix[prefix_file_offset] ^= 1
	_check(not _plans.build(changed_prefix).get("ok", true) and not _plans.validate(changed_prefix, plan).get("ok", true), "changed 01M.MES payload accepted")
	var changed_header := payload.duplicate()
	changed_header[0] ^= 1
	_check(not _plans.build(changed_header).get("ok", true), "changed 01M.MES address-table source accepted")
	_check(not _plans.build(payload.slice(0, payload.size() - 1)).get("ok", true), "truncated 01M.MES payload accepted")
	_check(_plans.validate(payload, plan).get("ok", false), "negative probes contaminated the original plan")
	_check(ContractValues.sha256(payload) == payload_before, "negative probes changed source bytes")


func _expected_local_flow(records: Dictionary) -> Dictionary:
	return {
		"kind": "symbolic_local_cfg",
		"entry_offset": PREFIX_OFFSET,
		"loop": {
			"counter": {"storage": "state_u16", "index": 2},
			"initialization": {"offset": 0x0169, "end_offset": 0x016E, "value": 0, "sha256": _record_hash(records, 0x0169)},
			"guard": {
				"offset": 0x016E, "end_offset": 0x0178,
				"predicate_signature": ["less_than", _state_ref("state_u16", 2), 16],
				"true_offset": 0x0178, "false_offset": 0x0196,
				"sha256": _record_hash(records, 0x016E),
			},
			"body": {
				"copy_offset": 0x0178, "copy_end_offset": 0x0189,
				"destination_signature": ["add", 31, _state_ref("state_u16", 2)],
				"source_signature": _state_ref("banked_u16", ["add", 168, _state_ref("state_u16", 2)]),
				"copy_sha256": _record_hash(records, 0x0178),
				"increment_offset": 0x0189, "increment_end_offset": 0x0191,
				"increment_signature": ["add", _state_ref("state_u16", 2), 1],
				"increment_sha256": _record_hash(records, 0x0189),
			},
			"back_edge": {"offset": 0x0191, "end_offset": 0x0196, "target_offset": 0x016E, "sha256": _record_hash(records, 0x0191)},
			"local_iteration_count": 16,
			"exit_offset": 0x0196,
		},
		"surface_branch": {
			"guard": {
				"offset": 0x01EF, "end_offset": 0x01FA,
				"predicate_signature": ["equal", _state_ref("global_u8", 2847), 1],
				"true_offset": 0x01FA, "false_offset": 0x0224,
				"sha256": _record_hash(records, 0x01EF),
			},
			"true_path": {
				"surface_offset": 0x01FA, "surface_end_offset": 0x021F,
				"continuation_offset": 0x021F, "continuation_end_offset": 0x0224,
				"continuation_target": 0x0229,
			},
			"false_path": {
				"shared_routine_offset": 0x0224, "shared_routine_end_offset": 0x0229,
				"routine_id": 21, "physical_resume": 0x0229,
			},
			"join_offset": 0x0229,
		},
		"conditional_join": {
			"kind": "candidate_cascade_prefix_join", "offset": PREFIX_END,
			"end_offset": PREFIX_END, "requires_external_completion": true,
			"reached_by_tool": false, "next_plan_schema": Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA,
			"delegated": false,
		},
	}


func _expected_symbolic_effects() -> Array[Dictionary]:
	return [
		{"kind": "manager_vector_clear", "offset": 0x000D, "end_offset": 0x0062, "selectors": range(1, 18), "mapped_gameplay_state": false},
		{"kind": "literal_write_range", "offset": 0x00D0, "end_offset": 0x0112, "storage": "global_u8", "start_index": 10, "count": 11, "value": 0},
		{"kind": "expression_write", "offset": 0x0117, "end_offset": 0x011E, "storage": "global_u8", "index": 350, "value_signature": ["call", "random_below", [3]], "evaluated": false},
		{"kind": "expression_write", "offset": 0x0123, "end_offset": 0x012A, "storage": "global_u8", "index": 351, "value_signature": ["call", "random_below", [13]], "evaluated": false},
		{"kind": "literal_write", "offset": 0x013E, "end_offset": 0x0143, "storage": "state_u16", "index": 2, "value": 15},
		{"kind": "literal_write", "offset": 0x014D, "end_offset": 0x0152, "storage": "state_u16", "index": 2, "value": 1},
		{"kind": "literal_write", "offset": 0x0163, "end_offset": 0x0169, "storage": "global_u8", "index": 3005, "value": 15},
		{"kind": "bounded_copy_loop", "offset": 0x0169, "end_offset": 0x0196, "source_storage": "banked_u16", "source_bank": 0, "source_start": 168, "destination_storage": "banked_u16", "destination_bank": 0, "destination_start": 31, "count": 16, "counter_storage": "state_u16", "counter_index": 2, "counter_final": 16},
		{"kind": "literal_write", "offset": 0x0196, "end_offset": 0x019C, "storage": "global_u8", "index": 3000, "value": 0},
		{"kind": "literal_write", "offset": 0x01D1, "end_offset": 0x01D8, "storage": "banked_u16", "bank": 0, "index": 1, "value": 1},
		{"kind": "literal_write", "offset": 0x01D8, "end_offset": 0x01DE, "storage": "argument_slot", "index": 1, "value": 11},
		{"kind": "literal_write", "offset": 0x01E3, "end_offset": 0x01EA, "storage": "banked_u16", "bank": 0, "index": 1, "value": 7},
		{"kind": "literal_write", "offset": 0x0229, "end_offset": 0x022F, "storage": "global_u8", "index": 2836, "value": 0},
		{"kind": "literal_write", "offset": 0x022F, "end_offset": 0x0235, "storage": "global_u8", "index": 3000, "value": 0},
		{"kind": "literal_write", "offset": 0x0235, "end_offset": 0x023B, "storage": "global_u8", "index": 2841, "value": 0},
	]


func _expected_external_boundaries(records: Dictionary) -> Array[Dictionary]:
	var rows := [
		["registered_definition", 0x0143, 0x0148, 11, "always"],
		["shared_routine", 0x0152, 0x0157, 32, "always"],
		["ax_presentation_control", 0x015C, 0x0163, 7, "always"],
		["shared_routine", 0x019C, 0x01A1, 25, "always"],
		["native_record_dispatch", 0x01A1, 0x01A9, 0, "always"],
		["native_record_dispatch", 0x01A9, 0x01B1, 0, "always"],
		["native_record_dispatch", 0x01B1, 0x01B9, 0, "always"],
		["ax_presentation_control", 0x01C3, 0x01CA, 6, "always"],
		["ax_presentation_control", 0x01CA, 0x01D1, 8, "always"],
		["shared_routine", 0x01DE, 0x01E3, 27, "always"],
		["shared_routine", 0x01EA, 0x01EF, 25, "always"],
		["surface_operation", 0x01FA, 0x021F, 11, "global_u8[2847] == 1"],
		["shared_routine", 0x0224, 0x0229, 21, "global_u8[2847] != 1"],
	]
	var result: Array[Dictionary] = []
	for order in range(rows.size()):
		var row: Array = rows[order]
		var item := {
			"order": order, "kind": row[0], "offset": row[1], "end_offset": row[2],
			"physical_resume": row[2], "condition": row[4], "sha256": _record_hash(records, row[1]),
			"tool_execution": false, "completion": "unresolved",
		}
		match str(row[0]):
			"registered_definition": item["selector"] = row[3]
			"shared_routine": item["routine_id"] = row[3]
			"ax_presentation_control":
				item["presentation_subcommand"] = 3
				item["execution_selector"] = row[3]
			"native_record_dispatch": item["record_values"] = _native_record_values(row[1])
			"surface_operation": item["presentation_subcommand"] = row[3]
		result.append(item)
	return result


func _records_by_offset(partition: Array[Dictionary]) -> Dictionary:
	var result := {}
	for record in partition:
		result[int(record.offset)] = record
	return result


func _record_hash(records: Dictionary, offset: int) -> String:
	return str(records.get(offset, {}).get("sha256", ""))


func _literal_record(record: Dictionary, value: int) -> bool:
	var operands: Array = record.get("operands", [])
	if operands.size() != 1:
		return false
	var rows: Array = operands[0].get("records", [])
	return rows.size() == 1 and str(rows[0].get("type", "")) == "expression_record" and _signature(rows[0].get("value", {}).get("ast", {})) == value


func _simple_write(record: Dictionary, index: int, value_signature: Variant) -> bool:
	if record.is_empty():
		return false
	var operands: Array = record.get("operands", [])
	return operands.size() == 2 and int(operands[0].get("value", -1)) == index and _pairs_match(operands[1], value_signature)


func _banked_write(record: Dictionary, index_signature: Variant, bank: int, value_signature: Variant) -> bool:
	if record.is_empty():
		return false
	var operands: Array = record.get("operands", [])
	return operands.size() == 3 and _signature(operands[0].get("value", {}).get("ast", {})) == index_signature and int(operands[1].get("value", -1)) == bank and _pairs_match(operands[2], value_signature)


func _pairs_match(operand: Dictionary, value_signature: Variant) -> bool:
	var pairs: Array = operand.get("pairs", [])
	return pairs.size() == 1 and int(pairs[0].get("continuation", -1)) == 0 and _signature(pairs[0].get("expression", {}).get("ast", {})) == value_signature


func _branch(record: Dictionary, predicate: Variant, false_offset: int) -> bool:
	if record.is_empty():
		return false
	var operands: Array = record.get("operands", [])
	return operands.size() == 2 and _signature(operands[0].get("value", {}).get("ast", {})) == predicate and int(operands[1].get("value", -1)) == false_offset


func _continuation(record: Dictionary, target: int) -> bool:
	if record.is_empty():
		return false
	var operands: Array = record.get("operands", [])
	return operands.size() == 1 and int(operands[0].get("value", -1)) == target


func _loop_copy(record: Dictionary) -> bool:
	return _banked_write(record, ["add", 31, _state_ref("state_u16", 2)], 0, _state_ref("banked_u16", ["add", 168, _state_ref("state_u16", 2)]))


func _ax_selector(record: Dictionary, selector: int) -> bool:
	if record.is_empty():
		return false
	var operands: Array = record.get("operands", [])
	return operands.size() == 1 and int(operands[0].get("presentation_subcommand", -1)) == 3 and int(operands[0].get("execution_selector", -1)) == selector


func _native_records(record: Dictionary, values: Array) -> bool:
	if record.is_empty():
		return false
	var operands: Array = record.get("operands", [])
	if operands.size() != 1:
		return false
	var rows: Array = operands[0].get("records", [])
	if rows.size() != values.size():
		return false
	for index in range(rows.size()):
		if str(rows[index].get("type", "")) != "expression_record" or _signature(rows[index].get("value", {}).get("ast", {})) != values[index]:
			return false
	return true


func _native_record_values(offset: int) -> Array:
	match offset:
		0x01A1: return [6, 2]
		0x01A9: return [6, 6]
		0x01B1: return [6, 10]
	return []


func _surface_operation(record: Dictionary) -> bool:
	if record.is_empty():
		return false
	var operands: Array = record.get("operands", [])
	if operands.size() != 1 or int(operands[0].get("presentation_subcommand", -1)) != 11 or int(operands[0].get("mode", -1)) != 0:
		return false
	var signatures := []
	for expression in operands[0].get("expressions", []):
		signatures.append(_signature(expression.get("ast", {})))
	return signatures == [0, 0, 0, 639, 399, 1, 0, 0, _state_ref("banked_u16", 23)]


func _state_ref(storage: String, index: Variant) -> Array:
	return ["state_ref", storage, 0, index]


func _signature(ast: Dictionary, depth := 0) -> Variant:
	if depth > 32:
		return null
	match str(ast.get("type", "")):
		"literal": return ast.get("value")
		"state_ref": return ["state_ref", str(ast.get("storage", "")), int(ast.get("bank", -1)), _signature(ast.get("index", {}), depth + 1)]
		"binary": return [str(ast.get("op", "")), _signature(ast.get("lhs", {}), depth + 1), _signature(ast.get("rhs", {}), depth + 1)]
		"call":
			var arguments := []
			for argument in ast.get("args", []):
				arguments.append(_signature(argument, depth + 1))
			return ["call", str(ast.get("name", "")), arguments]
	return null


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
