extends "res://tools/content_suite/cli_script.gd"

# EP-12: the third accepted routine-40 choice-consumer shape. The routine-40's
# own resume coordinate lands on a single unconditional intra-script jump
# (command 0x0C) rather than directly on the result-branch chain; that jump's
# destination is where the exact one-based chain begins. Confirmed by
# execution for all 12 `?_HOTEL.MES` menus (their own case-5 answer, which
# leads to the `?_HOTEL1.MES` handoff) - see
# docs/spec/mes/format_and_method.md, "routine-40", and
# analysis/_undoc/ep12_hotel_menu_report.md (untracked).

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const ChoiceContractScript := preload("res://content_core/mes_routine40_choice_contract.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const EXPECTED_CONSUMER_KIND := "one_based_state_u16_21_branch_chain_via_unconditional_redirect"

# `start` is the earliest of the menu's own 5 flag-gated DEF-availability
# branches (the same chain shape for all 12; the game's own special-day 6th
# option is excluded under this baseline seed because its own gate needs a
# specific `state_u16[7]`). Starting there instead of at the entry's own
# offset 0 skips only the unrelated shared-library calls earlier in the file
# (a fresh sandbox already holds every flag this chain reads at its default
# 0), the same technique already audited in
# `validate_mes_routine40_single_contract.gd`. `boundary`/`resume` are the
# entry's own first (always-taken under this seed) routine-40 call;
# `redirect_offset`/`redirect_target_offset` are the unconditional jump and
# where it lands, both confirmed by execution.
const ENTRIES := {
	"A_HOTEL.MES": {
		"entry_sha256": "793e03ba8cb388ace5269302fbde9bdd90134936a706b40dca577b07143883ed",
		"start": 0x1A31, "boundary": 0x1BDB, "resume": 0x1BE0,
		"redirect_offset": 0x1BE5, "redirect_target_offset": 0x1BF9,
		"option_entry_offsets": [7176, 7920, 8731, 10834, 12666],
	},
	"B_HOTEL.MES": {
		"entry_sha256": "2a6ea003eb2393ea7924473cedb4f5cc9e07c106e65f9ce5b44c741a92a2a22d",
		"start": 0x14F1, "boundary": 0x16A5, "resume": 0x16AA,
		"redirect_offset": 0x16AF, "redirect_target_offset": 0x16C3,
		"option_entry_offsets": [5842, 6538, 7343, 8692, 10242],
	},
	"C_HOTEL.MES": {
		"entry_sha256": "0331a8e86225c1a5e09424bd4e7de37e68beecb8211c6f09dcda57fdee4250ff",
		"start": 0x1EF4, "boundary": 0x209E, "resume": 0x20A3,
		"redirect_offset": 0x20A8, "redirect_target_offset": 0x20BC,
		"option_entry_offsets": [8395, 9217, 10233, 12416, 14656],
	},
	"D_HOTEL.MES": {
		"entry_sha256": "56de85445234f39d2e363943f25138d736ea882c42d86ddbaecbae77cbabcbed",
		"start": 0x20EE, "boundary": 0x2298, "resume": 0x229D,
		"redirect_offset": 0x22A2, "redirect_target_offset": 0x22B6,
		"option_entry_offsets": [8906, 9596, 10387, 12291, 14126],
	},
	"E_HOTEL.MES": {
		"entry_sha256": "251cb4309e6c28459178d2893a0c383d6e52cc8d317aa17ac5a688c4f9208281",
		"start": 0x26D5, "boundary": 0x2886, "resume": 0x288B,
		"redirect_offset": 0x2890, "redirect_target_offset": 0x28A4,
		"option_entry_offsets": [10424, 11242, 12230, 14316, 16557],
	},
	"F_HOTEL.MES": {
		"entry_sha256": "709f549dcf189d39bb3c03d64db8478c6f9c463a0b09da4b2f28abc5e7c1cc57",
		"start": 0x30F8, "boundary": 0x32A9, "resume": 0x32AE,
		"redirect_offset": 0x32B3, "redirect_target_offset": 0x32C7,
		"option_entry_offsets": [13019, 13830, 14785, 16990, 19082],
	},
	"G_HOTEL.MES": {
		"entry_sha256": "77d303c3fef82416fe8768b0443ff7f6e70be490ba6ea075caac821c9ec0c3ce",
		"start": 0x1C56, "boundary": 0x1E00, "resume": 0x1E05,
		"redirect_offset": 0x1E0A, "redirect_target_offset": 0x1E1E,
		"option_entry_offsets": [7730, 8509, 9253, 11039, 13074],
	},
	"H_HOTEL.MES": {
		"entry_sha256": "cacc016a2671c4af6f9f6092cbbc818a7b9911beb86f1e6ea89834a032f11625",
		"start": 0x3327, "boundary": 0x34D8, "resume": 0x34DD,
		"redirect_offset": 0x34E2, "redirect_target_offset": 0x34F6,
		"option_entry_offsets": [13578, 14394, 15400, 17633, 19719],
	},
	"I_HOTEL.MES": {
		"entry_sha256": "632d94c6740265714fac95fbf78ca5374846486f7423c43d590e1b3925aa2c08",
		"start": 0x1802, "boundary": 0x19B6, "resume": 0x19BB,
		"redirect_offset": 0x19C0, "redirect_target_offset": 0x19D4,
		"option_entry_offsets": [6632, 7371, 8208, 10157, 12020],
	},
	"J_HOTEL.MES": {
		"entry_sha256": "97f341dbb31a4da18d5dca4bafa13f2f1ef85981a5cc3865a11a10f6ad364153",
		"start": 0x2AC6, "boundary": 0x2C70, "resume": 0x2C75,
		"redirect_offset": 0x2C7A, "redirect_target_offset": 0x2C8E,
		"option_entry_offsets": [11426, 12157, 12988, 14531, 16059],
	},
	"K_HOTEL.MES": {
		"entry_sha256": "8bd55eb3177a08c6444025f45d86227ca0a90fc83435943c2ef3f4a2e4318a7c",
		"start": 0x3674, "boundary": 0x3814, "resume": 0x3819,
		"redirect_offset": 0x381E, "redirect_target_offset": 0x3832,
		"option_entry_offsets": [14406, 15218, 16240, 18486, 20544],
	},
	"L_HOTEL.MES": {
		"entry_sha256": "51e38c74e3ef131518e6f7a767bd9187328c193ed84352ac8304fb3d7e65e3e7",
		"start": 0x2D8E, "boundary": 0x2F53, "resume": 0x2F58,
		"redirect_offset": 0x2F5D, "redirect_target_offset": 0x2F71,
		"option_entry_offsets": [12165, 13332, 14592, 16812, 19235],
	},
}


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
	if before_archive != ARCHIVE_SHA256:
		reader.close()
		_fail("Configured archive does not match the audited HOTEL-menu source.")
		return
	var confirmed: Array[String] = []
	for untyped_entry in ENTRIES.keys():
		var entry := str(untyped_entry)
		var expected: Dictionary = ENTRIES[entry]
		if reader.get_entry_fingerprint(entry) != str(expected.entry_sha256):
			reader.close()
			_fail("%s does not match its audited fingerprint." % entry)
			return
		var document := MesContainerScript.new().parse(
			reader.read_entry(entry),
			{"archive": "mes.arc", "entry": entry, "resolved_source": "original_arc"}
		)
		if not document.get("ok", false):
			reader.close()
			_fail("%s failed to parse." % entry)
			return
		var runner := EventRunnerScript.new()
		var state := SandboxStateScript.new(1)
		var boundary: Dictionary = runner.run(
			document.bytecode, int(expected.start), state, int(document.header.code_size)
		)
		var contract: Dictionary = ChoiceContractScript.new().build(
			document.bytecode,
			int(document.header.code_size),
			boundary,
			{
				"archive": "mes.arc", "entry": entry,
				"entry_sha256": str(expected.entry_sha256), "resolved_source": "original_arc",
			}
		)
		var expected_options: Array = expected.option_entry_offsets
		if (
			str(boundary.get("status", "")) != "def_selection_boundary"
			or int(boundary.get("offset", -1)) != int(expected.boundary)
			or not contract.get("ok", false)
			or str(contract.get("schema", "")) != ContentCoreVersionScript.MES_ROUTINE40_CHOICE_CONTRACT_SCHEMA
			or int(contract.get("resume_offset", -1)) != int(expected.resume)
			or int(contract.get("definition_count", 0)) != 5
			or str(contract.get("consumer_kind", "")) != EXPECTED_CONSUMER_KIND
			or int(contract.get("redirect_offset", -1)) != int(expected.redirect_offset)
			or int(contract.get("redirect_target_offset", -1)) != int(expected.redirect_target_offset)
			or contract.get("result_values", []) != [1, 2, 3, 4, 5]
			or contract.get("option_entry_offsets", []) != expected_options
		):
			reader.close()
			_fail(
				"%s routine-40 menu contract does not match the audited redirect chain (error=%s)." % [
					entry, str(contract.get("error", "")),
				]
			)
			return
		if not ChoiceContractScript.new().validate(
			document.bytecode, int(document.header.code_size), contract
		).get("ok", false):
			reader.close()
			_fail("%s routine-40 menu contract failed to revalidate." % entry)
			return
		for result_value in range(1, 6):
			var choice_state := SandboxStateScript.new(1)
			choice_state.write_value("state_u16", 21, result_value)
			var selected: Dictionary = runner.run(
				document.bytecode, int(contract.resume_offset), choice_state,
				int(document.header.code_size), 24
			)
			var option_offset := int(expected_options[result_value - 1])
			var option_reached := false
			for untyped_trace in selected.get("trace", []):
				var trace: Dictionary = untyped_trace
				if int(trace.get("source_offset", -1)) == option_offset:
					option_reached = true
			if not option_reached:
				reader.close()
				_fail(
					"%s result %d did not reach its audited option entry 0x%X." % [
						entry, result_value, option_offset,
					]
				)
				return
		confirmed.append(entry)
	if reader.get_archive_fingerprint() != before_archive:
		reader.close()
		_fail("Source archive changed during HOTEL-menu redirect contract validation.")
		return
	reader.close()
	print(
		"PASS: %d ?_HOTEL.MES routine-40 menus (their own case-5 answer) build via the "
		% confirmed.size()
		+ "unconditional-redirect consumer shape, all 5 registered results confirmed by "
		+ "execution: %s" % ", ".join(confirmed)
	)
	quit(0)
