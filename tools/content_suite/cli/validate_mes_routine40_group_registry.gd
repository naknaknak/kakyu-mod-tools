extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const ChoiceContractScript := preload("res://content_core/mes_routine40_choice_contract.gd")
const GroupPreviewContractScript := preload("res://content_core/mes_routine40_group_preview_contract.gd")
const ReachabilityScript := preload("res://content_core/mes_routine40_reachability.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const ENTRY := "43C.MES"
const ENTRY_SHA256 := "446259e1c34b15de0dbab97c815d83b654fbeb7cca5cd29d4e2498a86706391b"
const ROUTE_START := 0x479A
const ROUTINE40_BOUNDARY := 0x4EC1
const GROUP_ORDER := [0, 1, 2, 3, 4, 5, 6]
const DEFAULT_GROUP_COUNTS := [6, 0, 0, 0, 2, 0, 7]
const ELIGIBLE_GROUP_COUNTS := [6, 15, 0, 14, 2, 0, 7]
const FALLBACK_DESTINATION := 0x399F
const FALLBACK_OWNER_ENTRY := 127
const FALLBACK_OWNER_START := 0x3917
const FALLBACK_OWNER_END := 0x39BC
const FALLBACK_FIRST_END := 0x39A6
const FALLBACK_FIRST_SHA256 := "eb16177a57ac463137ed15af94aedd1a46466386acf64a6bdc0df68d4886a8e4"
const HOST_ENVELOPE_SHA256 := "8f72c61dcaf28f5e48961806dcf5c0f9ac20db6cbe0fb937bbce29db7ac4d339"
const HOST_ACTIVATIONS := [
	{
		"entry": "43C_ASA.MES",
		"sha256": "b69408b4e4fb9cdfd1ef5a60b1af29dee77ba0c0922acd135aa8dd17220799a2",
		"spans": [[0x8608, 0x8613, 275], [0x8636, 0x8641, 275]],
	},
	{
		"entry": "44C.MES",
		"sha256": "49b5ae569923d6b0e58bf6bf64786f2e96fe9de00c9bad56cd450cb4a487d0ce",
		"spans": [[0xB167, 0xB172, 334], [0xB2A6, 0xB2B1, 337], [0xB4F3, 0xB4FE, 340]],
	},
	{
		"entry": "L_HOTEL2.MES",
		"sha256": "5ed3ba5238949f180a8da82961df9d9fe6b8bf818dbc7cf464c84ac38de85e49",
		"spans": [[0x3345, 0x3350, 106]],
	},
]


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <mes.arc>")
		return
	var reader := ArcReaderScript.new()
	if not reader.open(ProjectSettings.globalize_path(str(arguments[0]))):
		_fail(reader.last_error)
		return
	var before_archive := reader.get_archive_fingerprint()
	if before_archive != ARCHIVE_SHA256 or reader.get_entry_fingerprint(ENTRY) != ENTRY_SHA256:
		reader.close()
		_fail("Configured archive does not match the audited 43C source.")
		return
	var document := MesContainerScript.new().parse(
		reader.read_entry(ENTRY),
		{"archive": "mes.arc", "entry": ENTRY, "resolved_source": "original_arc"}
	)
	if not document.get("ok", false):
		reader.close()
		_fail("43C.MES failed to parse.")
		return
	var fallback_owner: Dictionary = document.entries[FALLBACK_OWNER_ENTRY]
	if (
		int(fallback_owner.offset) != FALLBACK_OWNER_START
		or int(fallback_owner.end_offset) != FALLBACK_OWNER_END
		or ContractValues.sha256(document.bytecode.slice(FALLBACK_DESTINATION, FALLBACK_FIRST_END))
		!= FALLBACK_FIRST_SHA256
	):
		reader.close()
		_fail("43C fallback no longer re-enters the audited address-entry-127 dispatcher.")
		return
	var activation_count := 0
	for untyped_source in HOST_ACTIVATIONS:
		var source: Dictionary = untyped_source
		var caller_entry := str(source.entry)
		if reader.get_entry_fingerprint(caller_entry) != str(source.sha256):
			reader.close()
			_fail("43C host activation caller %s changed." % caller_entry)
			return
		var caller_document := MesContainerScript.new().parse(
			reader.read_entry(caller_entry),
			{"archive": "mes.arc", "entry": caller_entry, "resolved_source": "original_arc"}
		)
		if not caller_document.get("ok", false):
			reader.close()
			_fail("43C host activation caller %s failed to parse." % caller_entry)
			return
		for untyped_span in source.spans:
			var span: Array = untyped_span
			var source_offset := int(span[0])
			var end_offset := int(span[1])
			var owner_index := int(span[2])
			var owner: Dictionary = caller_document.entries[owner_index]
			if (
				source_offset < int(owner.offset)
				or source_offset >= int(owner.end_offset)
				or ContractValues.sha256(caller_document.bytecode.slice(source_offset, end_offset))
				!= HOST_ENVELOPE_SHA256
			):
				reader.close()
				_fail("43C command-0x0E host activation envelope changed in %s." % caller_entry)
				return
			activation_count += 1
	if activation_count != 6:
		reader.close()
		_fail("43C host activation envelope count changed.")
		return
	var boundary: Dictionary = EventRunnerScript.new().run(
		document.bytecode,
		ROUTE_START,
		SandboxStateScript.new(1),
		int(document.header.code_size)
	)
	var groups: Dictionary = boundary.get("definition_groups", {})
	var counts: Array[int] = []
	for selector in GROUP_ORDER:
		counts.append((groups.get(selector, []) as Array).size())
	var first_rows: Array = boundary.get("definitions", [])
	var first_ids: Array[int] = []
	for untyped_definition in first_rows:
		first_ids.append(int((untyped_definition as Dictionary).get("definition_id", -1)))
	var contract: Dictionary = ChoiceContractScript.new().build(
		document.bytecode,
		int(document.header.code_size),
		boundary,
		{
			"archive": "mes.arc",
			"entry": ENTRY,
			"entry_sha256": ENTRY_SHA256,
			"resolved_source": "original_arc",
		}
	)
	var source_identity := {
		"archive": "mes.arc",
		"entry": ENTRY,
		"entry_sha256": ENTRY_SHA256,
		"resolved_source": "original_arc",
	}
	var grouped_contract: Dictionary = GroupPreviewContractScript.new().build(
		document.bytecode,
		int(document.header.code_size),
		boundary,
		source_identity
	)
	var default_consumer_groups: Array = grouped_contract.get("consumer_groups", [])
	var default_reachability: Dictionary = ReachabilityScript.new().build(
		document.bytecode,
		int(document.header.code_size),
		grouped_contract
	)
	var default_group_four_result_two: Dictionary = _find_reachability_route(
		default_reachability, 4, 2
	)
	var default_consumer_counts: Array[int] = []
	for untyped_group in default_consumer_groups:
		default_consumer_counts.append(
			((untyped_group as Dictionary).get("second_branches", []) as Array).size()
		)
	var default_group_four_consumer: Dictionary = (
		default_consumer_groups[3] if default_consumer_groups.size() == 6 else {}
	)
	var default_fallback: Dictionary = grouped_contract.get("default_continuation", {})
	if (
		str(boundary.get("schema", "")) != ContentCoreVersionScript.MES_EVENT_TRACE_SCHEMA
		or str(boundary.get("status", "")) != "def_selection_boundary"
		or int(boundary.get("offset", -1)) != ROUTINE40_BOUNDARY
		or boundary.get("definition_group_order", []) != GROUP_ORDER
		or counts != DEFAULT_GROUP_COUNTS
		or int(boundary.get("selection_definition_group", -1)) != 0
		or first_rows.size() != 6
		or first_ids != [0, 1, 2, 3, 4, 5]
		or int(boundary.get("registered_definition_count", -1)) != 15
		or int(boundary.get("observed_definition_count", -1)) != 15
		or contract.get("ok", false)
		or not grouped_contract.get("ok", false)
		or str(grouped_contract.get("schema", "")) != ContentCoreVersionScript.MES_ROUTINE40_GROUP_PREVIEW_SCHEMA
		or grouped_contract.get("first_result_values", []) != [1, 2, 3, 4, 5, 6]
		or int(grouped_contract.get("resume_offset", -1)) != 0x4EC6
		or str(grouped_contract.get("consumer_kind", "")) != "one_based_state_u16_21_then_state_u16_13_dispatch"
		or default_consumer_counts != [15, 0, 14, 1, 0, 7]
		or bool(grouped_contract.get("complete_available_mapping", true))
		or default_group_four_consumer.get("unmatched_available_second_results", []) != [2]
		or int(default_fallback.get("source_offset", -1)) != 0xA304
		or int(default_fallback.get("destination_offset", -1)) != FALLBACK_DESTINATION
		or not default_reachability.get("ok", false)
		or str(default_reachability.get("schema", "")) != ContentCoreVersionScript.MES_ROUTINE40_REACHABILITY_SCHEMA
		or int(default_reachability.get("route_count", -1)) != 13
		or int(default_reachability.get("stored_consumer_count", -1)) != 8
		or int(default_reachability.get("fallback_count", -1)) != 1
		or int(default_reachability.get("empty_boundary_count", -1)) != 4
		or int(default_reachability.get("inactive_stored_result_count", -1)) != 29
		or not bool(default_reachability.get("complete_live_numeric_mapping", false))
		or str(default_group_four_result_two.get("resolution", "")) != "stored_default_continuation"
		or int(default_group_four_result_two.get("definition_source_offset", -1)) != 0x4D85
		or int(default_group_four_result_two.get("source_offset", -1)) != 0xA304
		or int(default_group_four_result_two.get("destination_offset", -1)) != FALLBACK_DESTINATION
		or str(grouped_contract.get("consumer_execution_policy", "")) != "structural_coordinates_only"
		or str(grouped_contract.get("caller_resume_policy", "")) != "forbidden"
	):
		reader.close()
		_fail("43C grouped routine-40 boundary differs from the audited default-state registry.")
		return
	var group_trace_counts := {}
	for untyped_trace in boundary.get("trace", []):
		var trace: Dictionary = untyped_trace
		if str(trace.get("effect", "")) != "def_register_skip" or not trace.has("definition_group_selector"):
			continue
		var selector := int(trace.definition_group_selector)
		group_trace_counts[selector] = int(group_trace_counts.get(selector, 0)) + 1
	if (
		int(group_trace_counts.get(0, 0)) != 6
		or int(group_trace_counts.get(4, 0)) != 2
		or int(group_trace_counts.get(6, 0)) != 7
		or group_trace_counts.size() != 3
	):
		reader.close()
		_fail("43C trace did not retain the default-state group ownership of each reached definition.")
		return
	var eligible_state := SandboxStateScript.new(1)
	for flag_index in range(376, 404):
		eligible_state.write_value("global_u8", flag_index, 1)
	eligible_state.write_value("global_u8", 2575, 1)
	var eligible_boundary: Dictionary = EventRunnerScript.new().run(
		document.bytecode,
		ROUTE_START,
		eligible_state,
		int(document.header.code_size)
	)
	var eligible_grouped_contract: Dictionary = GroupPreviewContractScript.new().build(
		document.bytecode,
		int(document.header.code_size),
		eligible_boundary,
		source_identity
	)
	var eligible_groups: Dictionary = eligible_boundary.get("definition_groups", {})
	var eligible_counts: Array[int] = []
	for selector in GROUP_ORDER:
		eligible_counts.append((eligible_groups.get(selector, []) as Array).size())
	var eligible_consumer_groups: Array = eligible_grouped_contract.get("consumer_groups", [])
	var eligible_reachability: Dictionary = ReachabilityScript.new().build(
		document.bytecode,
		int(document.header.code_size),
		eligible_grouped_contract
	)
	var eligible_group_four_result_two: Dictionary = _find_reachability_route(
		eligible_reachability, 4, 2
	)
	var eligible_available_counts: Array[int] = []
	for untyped_group in eligible_consumer_groups:
		eligible_available_counts.append(int((untyped_group as Dictionary).available_definition_count))
	var eligible_group_four_consumer: Dictionary = (
		eligible_consumer_groups[3] if eligible_consumer_groups.size() == 6 else {}
	)
	if (
		str(eligible_boundary.get("status", "")) != "def_selection_boundary"
		or int(eligible_boundary.get("offset", -1)) != ROUTINE40_BOUNDARY
		or eligible_counts != ELIGIBLE_GROUP_COUNTS
		or (eligible_boundary.get("definitions", []) as Array).size() != 6
		or int(eligible_boundary.get("registered_definition_count", -1)) != 44
		or int(eligible_boundary.get("observed_definition_count", -1)) != 44
		or not eligible_grouped_contract.get("ok", false)
		or eligible_available_counts != [15, 0, 14, 2, 0, 7]
		or bool(eligible_grouped_contract.get("complete_available_mapping", true))
		or eligible_group_four_consumer.get("unmatched_available_second_results", []) != [2]
		or int((eligible_grouped_contract.get("default_continuation", {}) as Dictionary).get("destination_offset", -1)) != FALLBACK_DESTINATION
		or not eligible_reachability.get("ok", false)
		or int(eligible_reachability.get("route_count", -1)) != 40
		or int(eligible_reachability.get("stored_consumer_count", -1)) != 37
		or int(eligible_reachability.get("fallback_count", -1)) != 1
		or int(eligible_reachability.get("empty_boundary_count", -1)) != 2
		or int(eligible_reachability.get("inactive_stored_result_count", -1)) != 0
		or not bool(eligible_reachability.get("complete_live_numeric_mapping", false))
		or str(eligible_group_four_result_two.get("resolution", "")) != "stored_default_continuation"
		or int(eligible_group_four_result_two.get("destination_offset", -1)) != FALLBACK_DESTINATION
		or not GroupPreviewContractScript.new().validate(
			document.bytecode,
			int(document.header.code_size),
			eligible_grouped_contract
		).get("ok", false)
	):
		reader.close()
		_fail("43C eligible-state group registry differs from the audited complete topology.")
		return
	if reader.get_archive_fingerprint() != before_archive:
		reader.close()
		_fail("Source archive changed during grouped routine-40 validation.")
		return
	reader.close()
	print(
		"PASS: 43C routine40 trace=%s boundary=0x%X default_groups=6/0/0/0/2/0/7 eligible_groups=6/15/0/14/2/0/7 first_group=0 first_rows=6 registered=15/44 group_analysis=%s reachability=%s routes=13/40 consumer=8/37 fallback=1/1 empty=4/2 inactive=29/0 group4_result2=0xA304->0x399F/caller_forbidden fallback_entry=127 host_command0e=6 host_start=unresolved choice_bridge=fail_closed source_unchanged=true"
		% [
			str(boundary.schema),
			ROUTINE40_BOUNDARY,
			str(grouped_contract.schema),
			str(default_reachability.schema),
		]
	)
	quit(0)


func _find_reachability_route(
	report: Dictionary, first_result: int, second_result: int
) -> Dictionary:
	for untyped_route in report.get("routes", []):
		if not untyped_route is Dictionary:
			continue
		var route: Dictionary = untyped_route
		if (
			int(route.get("first_result", -1)) == first_result
			and int(route.get("second_result", -1)) == second_result
		):
			return route
	return {}
