extends "res://tests/test_case.gd"

const ChoiceContractScript := preload("res://content_core/mes_routine40_choice_contract.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")


func _ready() -> void:
	var code := PackedByteArray()
	_append_definition(code, 0, "A", 1)
	_append_definition(code, 1, "B", 2)
	_append_definition(code, 2, "C", 3)
	var boundary_offset := code.size()
	code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	code.append_array(PackedByteArray([0x1F, 0x04, 0x00, 0x00, 0x00]))
	var first_branch := _append_state21_branch(code, 1)
	var first_option := code.size()
	code.append(0x00)
	var second_branch := code.size()
	code.encode_u32(first_branch + 6, second_branch)
	_append_state21_branch(code, 2)
	var second_option := code.size()
	code.append(0x00)
	var third_option := code.size()
	code.append(0x00)
	code.encode_u32(second_branch + 6, third_option)

	var state := SandboxStateScript.new(1)
	var runner := EventRunnerScript.new()
	var boundary: Dictionary = runner.run(code, 0, state, code.size())
	_check(
		boundary.get("ok", false)
		and str(boundary.get("status", "")) == "def_selection_boundary"
		and int(boundary.get("offset", -1)) == boundary_offset
		and (boundary.get("persistent_expression_stack", []) as Array).is_empty(),
		"Event Runner retains the routine-40 resume context at a bounded DEF selection"
	)

	var source_identity := {
		"entry": "TEST.MES",
		"entry_sha256": "a".repeat(64),
		"resolved_source": "synthetic",
	}
	var choice_contract := ChoiceContractScript.new()
	var contract: Dictionary = choice_contract.build(code, code.size(), boundary, source_identity)
	_check(
		contract.get("ok", false)
		and str(contract.get("schema", "")) == ContentCoreVersionScript.MES_ROUTINE40_CHOICE_CONTRACT_SCHEMA
		and int(contract.get("boundary_offset", -1)) == boundary_offset
		and int(contract.get("resume_offset", -1)) == boundary_offset + 5
		and contract.get("result_values", []) == [1, 2, 3]
		and contract.get("option_entry_offsets", []) == [first_option, second_option, third_option]
		and str(contract.get("input_policy", "")) == "explicit_remake_choice"
		and str(contract.get("native_input_semantics", "")) == "unresolved",
		"routine-40 contract binds sequential definitions to the exact one-based slot-21 consumer"
	)
	_check(
		choice_contract.validate(code, code.size(), contract).get("ok", false),
		"routine-40 contract revalidates its source-bound bytecode and branch coordinates"
	)
	_check(
		str(contract.get("catalog_form", "")) == "contiguous"
		and contract.get("hidden_ids", null) == []
		and contract.get("hidden_gates", null) == [],
		"a contiguous 0..n-1 catalog carries no hidden ids or gates"
	)
	var transported: Dictionary = JSON.parse_string(JSON.stringify(contract))
	_check(choice_contract.validate(code, code.size(), transported).get("ok", false),
		"source-bound choice contract survives JSON transport of nested numeric fields")
	# A stored v3 contract (the shape every committed profile carried before
	# the redirect form, 2026-09-24) stays valid without redirect fields and
	# is refused with them.
	var prior: Dictionary = JSON.parse_string(JSON.stringify(contract))
	prior["schema"] = "kakyu_mes_routine40_choice_contract/v3"
	prior.erase("redirect_offset")
	prior.erase("redirect_target_offset")
	prior.erase("catalog_form")
	prior.erase("hidden_ids")
	prior.erase("hidden_gates")
	_check(choice_contract.validate(code, code.size(), prior).get("ok", false),
		"a stored v3 routine-40 contract without redirect fields still validates against the same bytecode")
	var prior_with_redirect: Dictionary = JSON.parse_string(JSON.stringify(prior))
	prior_with_redirect["redirect_offset"] = -1
	_check(not choice_contract.validate(code, code.size(), prior_with_redirect).get("ok", false),
		"a v3 routine-40 contract carrying a redirect field is refused")
	transported.definitions[0].source_offset = float(transported.definitions[0].source_offset) + 0.5
	_check(not choice_contract.validate(code, code.size(), transported).get("ok", false),
		"JSON normalization never accepts a fractional source coordinate")
	source_identity.entry = "MUTATED.MES"
	_check(
		str(contract.get("source_identity", {}).get("entry", "")) == "TEST.MES",
		"routine-40 contract retains a deep-copied logical source identity"
	)

	var before_choice := state.snapshot()
	state.write_value("state_u16", 21, 2)
	var selected: Dictionary = runner.run(code, int(contract.resume_offset), state, code.size())
	_check(
		selected.get("ok", false)
		and str(selected.get("status", "")) == "script_return"
		and int((selected.trace as Array)[1].get("source_offset", -1)) == first_branch
		and int((selected.trace as Array)[2].get("source_offset", -1)) == second_branch
		and int((selected.trace as Array)[3].get("source_offset", -1)) == second_option
		and state.read_value("state_u16", 21) == 2
		and state.diff(before_choice).size() == 1,
		"explicit remake choice writes caller-visible slot 21 and lets original branches select option 2"
	)

	var changed_body := code.duplicate()
	var first_definition: Dictionary = (contract.definitions as Array)[0]
	changed_body[int(first_definition.body_offset) + 1] ^= 0x01
	_check(
		not choice_contract.validate(changed_body, changed_body.size(), contract).get("ok", false),
		"routine-40 contract rejects a changed DEF body before resuming"
	)
	var changed_literal := code.duplicate()
	changed_literal[first_branch + 3] = 2
	_check(
		not choice_contract.validate(changed_literal, changed_literal.size(), contract).get("ok", false),
		"routine-40 contract rejects a nonsequential caller-visible result literal"
	)
	var changed_definition_result: Dictionary = boundary.duplicate(true)
	changed_definition_result.definitions[0].definition_id = 1
	_check(
		not choice_contract.build(code, code.size(), changed_definition_result).get("ok", false),
		"routine-40 contract rejects non-zero-based DEF identifiers"
	)
	var truncated := code.slice(0, third_option)
	_check(
		not choice_contract.validate(truncated, truncated.size(), contract).get("ok", false),
		"routine-40 contract rejects a missing final option target"
	)

	var single_code := PackedByteArray()
	_append_definition(single_code, 2, "ONLY", 7)
	var single_boundary_offset := single_code.size()
	single_code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	var single_branch := _append_state21_branch(single_code, 1)
	var single_option := single_code.size()
	single_code.append(0x00)
	var single_fallback := single_code.size()
	single_code.append(0x00)
	single_code.encode_u32(single_branch + 6, single_fallback)
	var single_boundary: Dictionary = runner.run(single_code, 0, state, single_code.size())
	var single_contract: Dictionary = choice_contract.build(
		single_code, single_code.size(), single_boundary, {"entry": "SINGLE.MES"}
	)
	_check(
		single_contract.get("ok", false)
		and int(single_contract.get("boundary_offset", -1)) == single_boundary_offset
		and int(single_contract.get("definition_count", 0)) == 1
		and int((single_contract.definitions as Array)[0].definition_id) == 2
		and single_contract.get("result_values", []) == [1]
		and single_contract.get("option_entry_offsets", []) == [single_option]
		and int(single_contract.get("fallback_offset", -1)) == single_fallback
		and int((single_contract.comparisons as Array)[0].source_offset) == single_branch,
		"routine-40 contract binds a stored single definition to its exact result-1 branch and separate fallback"
	)
	state.write_value("state_u16", 21, 1)
	var single_selected: Dictionary = runner.run(
		single_code, int(single_contract.resume_offset), state, single_code.size()
	)
	_check(
		str(single_selected.get("status", "")) == "script_return"
		and int((single_selected.trace as Array)[0].get("source_offset", -1)) == single_branch
		and int((single_selected.trace as Array)[1].get("source_offset", -1)) == single_option,
		"explicit single-row remake choice writes result 1 and follows the original true branch"
	)
	var changed_single_literal := single_code.duplicate()
	changed_single_literal[single_branch + 3] = 2
	_check(
		not choice_contract.validate(
			changed_single_literal, changed_single_literal.size(), single_contract
		).get("ok", false),
		"single-row routine-40 contract rejects a changed result literal"
	)
	var changed_single_target := single_code.duplicate()
	changed_single_target.encode_u32(single_branch + 6, single_option)
	_check(
		not choice_contract.validate(
			changed_single_target, changed_single_target.size(), single_contract
		).get("ok", false),
		"single-row routine-40 contract rejects a changed fallback coordinate"
	)

	var gated_code := PackedByteArray()
	_append_definition(gated_code, 0, "D", 4)
	_append_definition(gated_code, 1, "E", 5)
	_append_definition(gated_code, 2, "F", 6)
	gated_code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	var gated_branches: Array[int] = []
	var gated_options: Array[int] = []
	for result_value in range(1, 4):
		for gate_value in [0, 1]:
			gated_branches.append(_append_gated_state21_branch(gated_code, result_value, 7, gate_value))
			gated_options.append(gated_code.size())
			gated_code.append(0x00)
	var gated_fallback := gated_code.size()
	gated_code.append(0x00)
	for index in range(gated_branches.size()):
		gated_code.encode_u32(
			gated_branches[index] + 12,
			gated_branches[index + 1] if index + 1 < gated_branches.size() else gated_fallback
		)
	var gated_boundary: Dictionary = runner.run(gated_code, 0, state, gated_code.size())
	var gated_contract: Dictionary = choice_contract.build(
		gated_code, gated_code.size(), gated_boundary, {"entry": "GATED.MES"}
	)
	_check(
		gated_contract.get("ok", false)
		and str(gated_contract.get("consumer_kind", "")) == "gated_one_based_state_u16_21_branch_matrix"
		and gated_contract.get("gate", {}) == {
			"storage": "global_u8", "index": 7, "values": [0, 1]
		}
		and (gated_contract.get("variants", []) as Array).size() == 6
		and int(gated_contract.get("fallback_offset", -1)) == gated_fallback
		and str(gated_contract.get("gate_policy", "")) == "preserve_existing_validated_value",
		"routine-40 contract binds a complete result-by-existing-global gate matrix"
	)
	_check(
		choice_contract.validate(gated_code, gated_code.size(), gated_contract).get("ok", false),
		"gated routine-40 contract revalidates every matrix branch and fallback"
	)
	state.write_value("global_u8", 7, 1)
	state.write_value("state_u16", 21, 2)
	var gated_before := state.snapshot()
	var gated_selected: Dictionary = runner.run(
		gated_code, int(gated_contract.resume_offset), state, gated_code.size(), 4
	)
	_check(
		int(gated_selected.get("offset", -1)) == gated_options[3]
		and state.snapshot() == gated_before,
		"stored gated consumer selects result 2/gate 1 without mutating the preserved gate"
	)
	var changed_gate := gated_code.duplicate()
	changed_gate[gated_branches[0] + 8] = 2
	_check(
		not choice_contract.validate(changed_gate, changed_gate.size(), gated_contract).get("ok", false),
		"gated routine-40 contract rejects a changed gate literal before playback"
	)

	# Third accepted shape: the routine-40's own resume offset lands on a
	# single unconditional intra-script jump (command 0x0C) rather than
	# directly on the one-based chain, exactly as measured for all 12
	# `?_HOTEL.MES` menus (docs/spec/mes/format_and_method.md, "routine-40").
	var jump_code := PackedByteArray()
	_append_definition(jump_code, 0, "G", 8)
	_append_definition(jump_code, 1, "H", 9)
	var jump_boundary_offset := jump_code.size()
	jump_code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	var jump_source := jump_code.size()
	jump_code.append(0x0C)
	jump_code.resize(jump_code.size() + 4)
	var jump_branch := _append_state21_branch(jump_code, 1)
	var jump_first_option := jump_code.size()
	jump_code.append(0x00)
	var jump_second_option := jump_code.size()
	jump_code.append(0x00)
	jump_code.encode_u32(jump_branch + 6, jump_second_option)
	jump_code.encode_u32(jump_source + 1, jump_branch)

	var jump_state := SandboxStateScript.new(1)
	var jump_boundary: Dictionary = runner.run(jump_code, 0, jump_state, jump_code.size())
	_check(
		jump_boundary.get("ok", false)
		and str(jump_boundary.get("status", "")) == "def_selection_boundary"
		and int(jump_boundary.get("offset", -1)) == jump_boundary_offset,
		"Event Runner reaches the DEF selection boundary ahead of the redirecting jump"
	)
	var jump_contract: Dictionary = choice_contract.build(
		jump_code, jump_code.size(), jump_boundary, {"entry": "JUMP.MES"}
	)
	_check(
		jump_contract.get("ok", false)
		and str(jump_contract.get("consumer_kind", "")) == "one_based_state_u16_21_branch_chain_via_unconditional_redirect"
		and int(jump_contract.get("redirect_offset", -1)) == jump_source
		and int(jump_contract.get("redirect_target_offset", -1)) == jump_branch
		and jump_contract.get("result_values", []) == [1, 2]
		and jump_contract.get("option_entry_offsets", []) == [jump_first_option, jump_second_option],
		"routine-40 contract accepts a one-based chain reached through exactly one unconditional redirect"
	)
	_check(
		choice_contract.validate(jump_code, jump_code.size(), jump_contract).get("ok", false),
		"jump-redirected routine-40 contract revalidates its redirect coordinates and downstream chain"
	)
	jump_state.write_value("state_u16", 21, 2)
	var jump_selected: Dictionary = runner.run(
		jump_code, int(jump_contract.resume_offset), jump_state, jump_code.size()
	)
	_check(
		jump_selected.get("ok", false)
		and str(jump_selected.get("status", "")) == "script_return"
		and int((jump_selected.trace as Array)[0].get("source_offset", -1)) == jump_source
		and int((jump_selected.trace as Array)[1].get("source_offset", -1)) == jump_branch
		and int((jump_selected.trace as Array)[2].get("source_offset", -1)) == jump_second_option
		and jump_state.read_value("state_u16", 21) == 2,
		"explicit remake choice resumes through the original unconditional jump into the correct option"
	)
	var changed_redirect := jump_code.duplicate()
	changed_redirect.encode_u32(jump_source + 1, jump_first_option)
	_check(
		not choice_contract.validate(changed_redirect, changed_redirect.size(), jump_contract).get("ok", false),
		"jump-redirected routine-40 contract rejects a changed redirect destination"
	)

	# Near-miss: the redirect is found, but the branch it lands on is not the
	# exact result-1 literal the one-based chain requires, and it is not the
	# compound-AND shape the gated matrix requires either, so neither existing
	# shape matches even after following the one permitted redirect.
	var mismatch_code := PackedByteArray()
	_append_definition(mismatch_code, 0, "M", 10)
	_append_definition(mismatch_code, 1, "N", 11)
	mismatch_code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	var mismatch_jump_source := mismatch_code.size()
	mismatch_code.append(0x0C)
	mismatch_code.resize(mismatch_code.size() + 4)
	var mismatch_branch := _append_state21_branch(mismatch_code, 2)
	mismatch_code.append(0x00)
	var mismatch_second_option := mismatch_code.size()
	mismatch_code.append(0x00)
	mismatch_code.encode_u32(mismatch_branch + 6, mismatch_second_option)
	mismatch_code.encode_u32(mismatch_jump_source + 1, mismatch_branch)
	var mismatch_state := SandboxStateScript.new(1)
	var mismatch_boundary: Dictionary = runner.run(mismatch_code, 0, mismatch_state, mismatch_code.size())
	var mismatch_contract: Dictionary = choice_contract.build(
		mismatch_code, mismatch_code.size(), mismatch_boundary, {"entry": "MISMATCH.MES"}
	)
	_check(
		not mismatch_contract.get("ok", false)
		and str(mismatch_contract.get("error", "")) == (
			"Routine-40 result consumer is neither an exact one-based chain nor a complete "
			+ "gated matrix nor a per-position scratch-split chain, directly or through one "
			+ "unconditional redirect."
		),
		"routine-40 contract rejects a redirect target whose branch is not the exact result-1 literal"
	)

	# EP-12 (2026-09-25, Core 0.366.0): a sparse catalog - the shape measured
	# at the real A_PROMIS.MES:2221 location picker, where one of fifteen
	# individually-gated places never registers under the location-0
	# baseline. Ids 0 and 2 are declared by `_append_definition`; id 1 is
	# also physically declared (the archive's own picker keeps every
	# candidate's DEF in the file whether or not its own gate is ever taken),
	# but its own `0x0B` gate branch (state_u16[30] == 1, false by the
	# sandbox default of 0) always jumps around it, landing directly on id
	# 2's own DEF record - the same "individually gated, one candidate
	# immediately after another" shape the real picker's 15 places use.
	var sparse_code := PackedByteArray()
	_append_definition(sparse_code, 0, "P", 20)
	var hidden_gate_offset := sparse_code.size()
	sparse_code.append_array(PackedByteArray([0x0B, 0x80, 30, 1, 0xEF, 0xFF]))
	sparse_code.resize(sparse_code.size() + 4)
	var hidden_gate_end := sparse_code.size()
	_append_definition(sparse_code, 1, "X", 30)
	var after_hidden_definition := sparse_code.size()
	sparse_code.encode_u32(hidden_gate_offset + 6, after_hidden_definition)
	_append_definition(sparse_code, 2, "Q", 21)
	_append_definition(sparse_code, 3, "R", 22)
	var sparse_boundary_offset := sparse_code.size()
	sparse_code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	var sparse_branch_1 := _append_state21_branch(sparse_code, 1)
	var sparse_option_1 := sparse_code.size()
	sparse_code.append(0x00)
	var sparse_branch_2 := sparse_code.size()
	sparse_code.encode_u32(sparse_branch_1 + 6, sparse_branch_2)
	_append_state21_branch(sparse_code, 2)
	var sparse_option_2 := sparse_code.size()
	sparse_code.append(0x00)
	var sparse_option_3 := sparse_code.size()
	sparse_code.append(0x00)
	sparse_code.encode_u32(sparse_branch_2 + 6, sparse_option_3)

	var sparse_state := SandboxStateScript.new(1)
	var sparse_boundary: Dictionary = runner.run(sparse_code, 0, sparse_state, sparse_code.size())
	_check(
		sparse_boundary.get("ok", false)
		and str(sparse_boundary.get("status", "")) == "def_selection_boundary"
		and int(sparse_boundary.get("offset", -1)) == sparse_boundary_offset,
		"Event Runner skips the ungated id and registers ids 0, 2 and 3 in order"
	)
	var sparse_contract: Dictionary = choice_contract.build(
		sparse_code, sparse_code.size(), sparse_boundary, {"entry": "SPARSE.MES"}
	)
	_check(
		sparse_contract.get("ok", false)
		and str(sparse_contract.get("schema", "")) == ContentCoreVersionScript.MES_ROUTINE40_CHOICE_CONTRACT_SCHEMA
		and str(sparse_contract.get("catalog_form", "")) == "sparse"
		and sparse_contract.get("hidden_ids", []) == [1]
		and sparse_contract.get("result_values", []) == [1, 2, 3]
		and sparse_contract.get("option_entry_offsets", []) == [sparse_option_1, sparse_option_2, sparse_option_3]
		and (sparse_contract.definitions as Array).map(func(d): return int(d.definition_id)) == [0, 2, 3],
		"routine-40 contract accepts a sparse catalog and keeps sequential result values"
	)
	var hidden_gate_hash_context := HashingContext.new()
	hidden_gate_hash_context.start(HashingContext.HASH_SHA256)
	hidden_gate_hash_context.update(sparse_code.slice(hidden_gate_offset, hidden_gate_end))
	var expected_hidden_gate_sha256 := hidden_gate_hash_context.finish().hex_encode()
	var sparse_gates: Array = sparse_contract.get("hidden_gates", [])
	_check(
		sparse_gates.size() == 1
		and int(sparse_gates[0].definition_id) == 1
		and int(sparse_gates[0].gate_offset) == hidden_gate_offset
		and int(sparse_gates[0].gate_end) == hidden_gate_end
		and str(sparse_gates[0].gate_condition_sha256) == expected_hidden_gate_sha256,
		"routine-40 contract binds the hidden id to the exact gate branch this run's trace skipped"
	)
	_check(
		choice_contract.validate(sparse_code, sparse_code.size(), sparse_contract).get("ok", false),
		"sparse routine-40 contract revalidates its hidden-gate evidence against the same bytecode"
	)
	var sparse_transported: Dictionary = JSON.parse_string(JSON.stringify(sparse_contract))
	_check(
		choice_contract.validate(sparse_code, sparse_code.size(), sparse_transported).get("ok", false),
		"sparse routine-40 contract survives JSON transport of its hidden-gate evidence"
	)
	var changed_gate_hash: Dictionary = JSON.parse_string(JSON.stringify(sparse_contract))
	changed_gate_hash.hidden_gates[0].gate_condition_sha256 = "0".repeat(64)
	_check(
		not choice_contract.validate(sparse_code, sparse_code.size(), changed_gate_hash).get("ok", false),
		"sparse routine-40 contract rejects a changed hidden-gate condition hash"
	)

	# A non-increasing id list (a duplicate, here) is refused even though
	# each individual id is in range.
	var non_increasing_result: Dictionary = sparse_boundary.duplicate(true)
	non_increasing_result.definitions[2].definition_id = 2
	_check(
		not choice_contract.build(sparse_code, sparse_code.size(), non_increasing_result).get("ok", false),
		"routine-40 contract rejects a non-increasing (duplicate) definition id list"
	)
	var decreasing_result: Dictionary = sparse_boundary.duplicate(true)
	decreasing_result.definitions[2].definition_id = 1
	_check(
		not choice_contract.build(sparse_code, sparse_code.size(), decreasing_result).get("ok", false),
		"routine-40 contract rejects a decreasing definition id list"
	)

	# The schema before the sparse-catalog form (v4, 2026-09-24) stays valid
	# without the two new fields, exactly as a v3 contract stays valid
	# without the redirect fields; carrying either new field is refused.
	var v4_contract: Dictionary = JSON.parse_string(JSON.stringify(contract))
	v4_contract["schema"] = "kakyu_mes_routine40_choice_contract/v4"
	v4_contract.erase("catalog_form")
	v4_contract.erase("hidden_ids")
	v4_contract.erase("hidden_gates")
	_check(
		choice_contract.validate(code, code.size(), v4_contract).get("ok", false),
		"a stored v4 routine-40 contract without sparse-catalog fields still validates"
	)
	var v4_with_catalog_form: Dictionary = JSON.parse_string(JSON.stringify(v4_contract))
	v4_with_catalog_form["catalog_form"] = "contiguous"
	_check(
		not choice_contract.validate(code, code.size(), v4_with_catalog_form).get("ok", false),
		"a v4 routine-40 contract carrying catalog_form is refused"
	)
	var v4_with_hidden_ids: Dictionary = JSON.parse_string(JSON.stringify(v4_contract))
	v4_with_hidden_ids["hidden_ids"] = []
	_check(
		not choice_contract.validate(code, code.size(), v4_with_hidden_ids).get("ok", false),
		"a v4 routine-40 contract carrying hidden_ids is refused"
	)

	# EP-12 TALK (2026-10-04, Core 0.371.0): the third shape, a one-based chain
	# whose positions are a pure `== k` row or one or more `== k and
	# global_u8[c] == v` rows on one per-position cell - the shape of the first
	# question of the `?_TALK*.MES` rung scripts in the state a place calls them
	# (docs/spec/mes/talk_family.md). Five definitions: positions 1 and 2 pure,
	# 3 splits on cell 10 (values 0 and 1), 4 on cell 11 (0 and 1), and the chain
	# goes on at position 5 with a single-valued row of cell 12 and a pure row 6.
	var split_plan := [[1, -1, -1], [2, -1, -1], [3, 10, 0], [3, 10, 1], [4, 11, 0], [4, 11, 1], [5, 12, 0], [6, -1, -1]]
	var split_build := _build_scratch_split_code(split_plan)
	var split_code: PackedByteArray = split_build.code
	var split_rows: Array = split_build.rows
	var split_bodies: Array = split_build.bodies
	var split_state := SandboxStateScript.new(1)
	var split_boundary: Dictionary = runner.run(split_code, 0, split_state, split_code.size())
	_check(
		split_boundary.get("ok", false)
		and str(split_boundary.get("status", "")) == "def_selection_boundary"
		and int(split_boundary.get("offset", -1)) == int(split_build.boundary_offset),
		"Event Runner reaches the routine-40 boundary ahead of the scratch-split chain"
	)
	var split_contract: Dictionary = choice_contract.build(
		split_code, split_code.size(), split_boundary, {"entry": "SPLIT.MES"}
	)
	_check(
		split_contract.get("ok", false)
		and str(split_contract.get("schema", "")) == ContentCoreVersionScript.MES_ROUTINE40_CHOICE_CONTRACT_SCHEMA
		and str(split_contract.get("consumer_kind", "")) == "one_based_state_u16_21_scratch_split_branch_chain"
		and split_contract.get("result_values", []) == [1, 2, 3, 4, 5]
		and (split_contract.get("comparisons", []) as Array).size() == 6
		and split_contract.get("option_entry_offsets", []) == [
			split_bodies[0], split_bodies[1], split_bodies[2], split_bodies[4], split_rows[6]
		]
		and split_contract.get("gate", null) == {}
		and split_contract.get("variants", null) == []
		and int(split_contract.get("fallback_offset", 0)) == -1
		and str(split_contract.get("gate_policy", "")) == "not_applicable"
		and str(split_contract.get("catalog_form", "")) == "contiguous",
		"routine-40 contract accepts a one-based chain whose positions split on scratch cells"
	)
	var split_comparisons: Array = split_contract.get("comparisons", [])
	_check(
		split_comparisons.size() == 6
		and not (split_comparisons[0] as Dictionary).has("gate")
		and not (split_comparisons[1] as Dictionary).has("gate")
		and (split_comparisons[2] as Dictionary).get("gate", {}) == {"storage": "global_u8", "index": 10, "literal": 0}
		and (split_comparisons[3] as Dictionary).get("gate", {}) == {"storage": "global_u8", "index": 10, "literal": 1}
		and (split_comparisons[5] as Dictionary).get("gate", {}) == {"storage": "global_u8", "index": 11, "literal": 1}
		and int((split_comparisons[3] as Dictionary).source_offset) == int(split_rows[3])
		and int((split_comparisons[3] as Dictionary).fallthrough_offset) == int(split_bodies[3])
		and int((split_comparisons[3] as Dictionary).false_target_offset) == int(split_rows[4]),
		"scratch-split contract records each row, its exact cell and literal, and the chain's own false edges"
	)
	_check(
		split_contract.get("position_gates", []) == [
			{"result": 1, "gate": {}},
			{"result": 2, "gate": {}},
			{"result": 3, "gate": {"storage": "global_u8", "index": 10, "values": [0, 1]}},
			{"result": 4, "gate": {"storage": "global_u8", "index": 11, "values": [0, 1]}},
		],
		"scratch-split contract records the cell of each position it reads"
	)
	_check(
		choice_contract.validate(split_code, split_code.size(), split_contract).get("ok", false),
		"scratch-split routine-40 contract revalidates every row, cell and literal"
	)
	var split_transported: Dictionary = JSON.parse_string(JSON.stringify(split_contract))
	_check(
		choice_contract.validate(split_code, split_code.size(), split_transported).get("ok", false),
		"scratch-split routine-40 contract survives JSON transport"
	)
	var split_prior: Dictionary = JSON.parse_string(JSON.stringify(split_contract))
	split_prior["schema"] = "kakyu_mes_routine40_choice_contract/v4"
	split_prior.erase("catalog_form")
	split_prior.erase("hidden_ids")
	split_prior.erase("hidden_gates")
	_check(
		not choice_contract.validate(split_code, split_code.size(), split_prior).get("ok", false),
		"a v4 routine-40 contract cannot carry per-position gates"
	)
	# EP-12 TALK (2026-10-05, Core 0.372.0): the schema is v6 and the key
	# `position_gates` belongs to it. A stored v5 contract (every installed contract of
	# the plain, gated, redirected and sparse forms) stays valid without the key, its
	# schema string not held against the rebuilt v6; a v5 contract that carries the key
	# is refused; a v6 contract of the split form revalidates (above).
	_check(
		str(split_contract.get("schema", "")) == "kakyu_mes_routine40_choice_contract/v6",
		"the routine-40 choice contract schema is v6"
	)
	var v5_plain: Dictionary = JSON.parse_string(JSON.stringify(contract))
	v5_plain["schema"] = "kakyu_mes_routine40_choice_contract/v5"
	_check(
		choice_contract.validate(code, code.size(), v5_plain).get("ok", false),
		"a stored v5 routine-40 contract of the plain chain, without per-position gates, still validates"
	)
	var v5_sparse: Dictionary = JSON.parse_string(JSON.stringify(sparse_contract))
	v5_sparse["schema"] = "kakyu_mes_routine40_choice_contract/v5"
	_check(
		choice_contract.validate(sparse_code, sparse_code.size(), v5_sparse).get("ok", false),
		"a stored v5 routine-40 contract of the sparse catalog still validates"
	)
	var v5_split: Dictionary = JSON.parse_string(JSON.stringify(split_contract))
	v5_split["schema"] = "kakyu_mes_routine40_choice_contract/v5"
	_check(
		not choice_contract.validate(split_code, split_code.size(), v5_split).get("ok", false),
		"a v5 routine-40 contract cannot carry per-position gates"
	)
	var v5_split_without_gates: Dictionary = JSON.parse_string(JSON.stringify(v5_split))
	v5_split_without_gates.erase("position_gates")
	_check(
		not choice_contract.validate(split_code, split_code.size(), v5_split_without_gates).get("ok", false),
		"a v5 routine-40 contract whose rebuild is the split form is refused even without the key"
	)
	var v6_split_without_gates: Dictionary = JSON.parse_string(JSON.stringify(split_contract))
	v6_split_without_gates.erase("position_gates")
	_check(
		not choice_contract.validate(split_code, split_code.size(), v6_split_without_gates).get("ok", false),
		"a v6 routine-40 contract of the split form cannot drop its per-position gates"
	)
	# The original chain stays what it was: the contract of a plain chain and of
	# a gated matrix carry no `position_gates` key at all.
	_check(
		not contract.has("position_gates") and not gated_contract.has("position_gates")
		and not jump_contract.has("position_gates") and not sparse_contract.has("position_gates"),
		"the plain, gated, redirected and sparse contracts keep their keys (no per-position gates)"
	)
	# The explicit choice follows the original branches: option 3 with cell 10
	# set takes the second row of position 3, with cell 10 clear the first.
	split_state.write_value("state_u16", 21, 3)
	split_state.write_value("global_u8", 10, 1)
	var split_selected: Dictionary = runner.run(
		split_code, int(split_contract.resume_offset), split_state, split_code.size()
	)
	var split_trace: Array = split_selected.get("trace", [])
	_check(
		split_selected.get("ok", false)
		and str(split_selected.get("status", "")) == "script_return"
		and not split_trace.is_empty()
		and int((split_trace[-1] as Dictionary).get("source_offset", -1)) == int(split_bodies[3]),
		"explicit choice 3 with the position's cell set enters the second row's option"
	)
	split_state.write_value("global_u8", 10, 0)
	var split_first: Dictionary = runner.run(
		split_code, int(split_contract.resume_offset), split_state, split_code.size()
	)
	var split_first_trace: Array = split_first.get("trace", [])
	_check(
		split_first.get("ok", false)
		and not split_first_trace.is_empty()
		and int((split_first_trace[-1] as Dictionary).get("source_offset", -1)) == int(split_bodies[2]),
		"explicit choice 3 with the position's cell clear enters the first row's option"
	)
	var changed_split_literal := split_code.duplicate()
	changed_split_literal[int(split_rows[3]) + 8] = 2
	_check(
		not choice_contract.validate(changed_split_literal, changed_split_literal.size(), split_contract).get("ok", false),
		"scratch-split contract rejects a changed row literal before playback"
	)
	var changed_split_cell := split_code.duplicate()
	changed_split_cell[int(split_rows[5]) + 6] = 21
	_check(
		not choice_contract.validate(changed_split_cell, changed_split_cell.size(), split_contract).get("ok", false),
		"scratch-split contract rejects a changed row cell before playback"
	)
	# Near misses stay rejected: two cells in one position, a repeated value, a
	# pure row mixed into a split position, a gate that is not a global_u8 cell,
	# a first row that is not result 1, and a chain with no split at all is the
	# original chain's own shape (so this form never claims it).
	var near_misses := {
		"two cells in one position": [[1, -1, -1], [2, -1, -1], [3, 10, 0], [3, 11, 1], [4, -1, -1], [5, -1, -1]],
		"a repeated value in one position": [[1, -1, -1], [2, -1, -1], [3, 10, 0], [3, 10, 0], [4, -1, -1], [5, -1, -1]],
		"a pure row after a split row": [[1, -1, -1], [2, -1, -1], [3, 10, 0], [3, -1, -1], [4, -1, -1], [5, -1, -1]],
		"a split row after a pure row": [[1, -1, -1], [2, -1, -1], [3, -1, -1], [3, 10, 0], [4, -1, -1], [5, -1, -1]],
		"a chain that skips a result": [[1, -1, -1], [2, -1, -1], [4, 10, 0], [5, 10, 1], [5, -1, -1]],
		"a chain that starts at result 2": [[2, -1, -1], [3, 10, 0], [4, -1, -1], [5, -1, -1]],
	}
	for label in near_misses.keys():
		var near := _build_scratch_split_code(near_misses[label])
		var near_state := SandboxStateScript.new(1)
		var near_boundary: Dictionary = runner.run(near.code, 0, near_state, (near.code as PackedByteArray).size())
		var near_contract: Dictionary = choice_contract.build(
			near.code, (near.code as PackedByteArray).size(), near_boundary, {"entry": "NEAR.MES"}
		)
		_check(not near_contract.get("ok", false), "scratch-split form rejects %s" % label)
	var state_gate_plan := [[1, -1, -1], [2, -1, -1], [3, 10, 0], [3, 10, 1], [4, -1, -1], [5, -1, -1]]
	var state_gate_build := _build_scratch_split_code(state_gate_plan, 3)
	var state_gate_state := SandboxStateScript.new(1)
	var state_gate_code: PackedByteArray = state_gate_build.code
	var state_gate_boundary: Dictionary = runner.run(state_gate_code, 0, state_gate_state, state_gate_code.size())
	var state_gate_contract: Dictionary = choice_contract.build(
		state_gate_code, state_gate_code.size(), state_gate_boundary, {"entry": "STATEGATE.MES"}
	)
	_check(
		not state_gate_contract.get("ok", false),
		"scratch-split form rejects a gate that is not a global_u8 cell"
	)
	# The same plan with a global_u8 gate throughout is accepted, so the refusal
	# above is the gate's storage and nothing else.
	var global_gate_build := _build_scratch_split_code(state_gate_plan)
	var global_gate_code: PackedByteArray = global_gate_build.code
	var global_gate_boundary: Dictionary = runner.run(
		global_gate_code, 0, SandboxStateScript.new(1), global_gate_code.size()
	)
	var global_gate_contract: Dictionary = choice_contract.build(
		global_gate_code, global_gate_code.size(), global_gate_boundary, {"entry": "GLOBALGATE.MES"}
	)
	_check(
		global_gate_contract.get("ok", false)
		and str(global_gate_contract.get("consumer_kind", "")) == "one_based_state_u16_21_scratch_split_branch_chain",
		"the same chain over global_u8 cells only is accepted"
	)

	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


## A routine-40 question over five definitions followed by the chain `plan`
## describes: `[result, cell, value]` rows, a negative cell for a pure `== k`
## row. Each row is followed by a one-byte body (a return) and every row's
## false edge leads to the next row, the last to a final return. With
## `state_gate_row` >= 0 that row's gate tests `state_u16[30]` instead of a
## `global_u8` cell (a shape the form must refuse).
func _build_scratch_split_code(plan: Array, state_gate_row: int = -1) -> Dictionary:
	var code := PackedByteArray()
	for definition_id in range(5):
		_append_definition(code, definition_id, "S%d" % definition_id, 40 + definition_id)
	var boundary_offset := code.size()
	code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	var rows: Array = []
	var bodies: Array = []
	var target_fields: Array = []
	for index in range(plan.size()):
		var row: Array = plan[index]
		var row_offset := code.size()
		if int(row[1]) < 0:
			_append_state21_branch(code, int(row[0]))
			target_fields.append(row_offset + 6)
		elif index == state_gate_row:
			code.append_array(PackedByteArray([0x0B, 0x80, 21, int(row[0]), 0xEF, 0x80, 30, int(row[2]), 0xEF, 0xE6, 0xFF]))
			code.resize(code.size() + 4)
			target_fields.append(row_offset + 11)
		else:
			_append_gated_state21_branch(code, int(row[0]), int(row[1]), int(row[2]))
			target_fields.append(row_offset + 12)
		rows.append(row_offset)
		bodies.append(code.size())
		code.append(0x00)
	var end_offset := code.size()
	code.append(0x00)
	for index in range(plan.size()):
		code.encode_u32(int(target_fields[index]), int(rows[index + 1]) if index + 1 < plan.size() else end_offset)
	return {"code": code, "rows": rows, "bodies": bodies, "boundary_offset": boundary_offset}


func _append_definition(code: PackedByteArray, definition_id: int, text: String, marker: int) -> void:
	var source_offset := code.size()
	code.append_array(PackedByteArray([0x10, 0x02, definition_id, 0xFF, 0x00]))
	code.resize(code.size() + 4)
	code.append(0x01)
	code.append_array(text.to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x00]))
	var target := code.size()
	code.encode_u32(source_offset + 5, target)
	code.append(0x1F)
	code.resize(code.size() + 4)
	code.encode_u32(code.size() - 4, marker)


func _append_state21_branch(code: PackedByteArray, result_value: int) -> int:
	var source_offset := code.size()
	code.append_array(PackedByteArray([0x0B, 0x80, 21, result_value, 0xEF, 0xFF]))
	code.resize(code.size() + 4)
	return source_offset


func _append_gated_state21_branch(
	code: PackedByteArray, result_value: int, gate_index: int, gate_value: int
) -> int:
	var source_offset := code.size()
	code.append_array(PackedByteArray([
		0x0B, 0x80, 21, result_value, 0xEF,
		0xF3, gate_index & 0xFF, (gate_index >> 8) & 0xFF, gate_value,
		0xEF, 0xE6, 0xFF,
	]))
	code.resize(code.size() + 4)
	return source_offset
