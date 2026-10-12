class_name KakyuMesRoutine40ChoiceContract
extends RefCounted

const ResultDispatchParserScript := preload("res://content_core/mes_result_dispatch_parser.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const RESULT_STORAGE := "state_u16"
const RESULT_INDEX := 21
const MAX_OPTIONS := 17


var _dispatch_parser := ResultDispatchParserScript.new()


func build(
	code,
	end_offset: int,
	boundary_result: Dictionary,
	source_identity: Dictionary = {}
) -> Dictionary:
	var source := _as_source(code)
	var limit := mini(end_offset, source.size())
	if limit <= 0 or end_offset != limit:
		return _error("Routine-40 choice code range is invalid.")
	if str(boundary_result.get("status", "")) != "def_selection_boundary":
		return _error("Execution did not stop at a DEF selection boundary.")
	var trace: Array = boundary_result.get("trace", [])
	if trace.is_empty():
		return _error("Routine-40 boundary has no terminal trace row.")
	var terminal: Dictionary = trace[-1]
	if (
		int(terminal.get("command_id", -1)) != 0x1D
		or int(terminal.get("routine_id", -1)) != 40
		or int(terminal.get("source_offset", -1)) != int(boundary_result.get("offset", -2))
	):
		return _error("DEF selection terminal is not the exact routine-40 call.")
	var resume_offset := int(terminal.get("end_offset", -1))
	if resume_offset <= int(terminal.get("source_offset", -1)) or resume_offset >= limit:
		return _error("Routine-40 resume coordinate is outside the MES bytecode.")

	var definitions: Array = boundary_result.get("definitions", [])
	if definitions.is_empty() or definitions.size() > MAX_OPTIONS:
		return _error("Routine-40 result bridge requires 1..17 definitions.")
	var definition_rows: Array[Dictionary] = []
	var previous_source := -1
	var previous_definition_id := -1
	for index in range(definitions.size()):
		var definition: Dictionary = definitions[index]
		var source_offset := int(definition.get("source_offset", -1))
		var body_offset := int(definition.get("body_offset", -1))
		var target_offset := int(definition.get("target_offset", -1))
		var definition_id := int(definition.get("definition_id", -1))
		if (
			(
				definitions.size() > 1
				and (definition_id <= previous_definition_id or definition_id > MAX_OPTIONS - 1)
			)
			or (definitions.size() == 1 and (definition_id < 0 or definition_id > 255))
		):
			return _error("Routine-40 definition identifiers do not match the supported stored form.")
		previous_definition_id = definition_id
		if source_offset <= previous_source or body_offset <= source_offset or target_offset <= body_offset or target_offset > limit:
			return _error("Routine-40 definition bounds are invalid or out of order.")
		if int(definition.get("body_size", -1)) != target_offset - body_offset:
			return _error("Routine-40 definition body size changed.")
		var body_sha256 := source.sha256_range(body_offset, target_offset)
		if body_sha256 == KakyuMesCodeSource.RANGE_UNAVAILABLE:
			return _error("Routine-40 definition body cannot be fingerprinted by this code source.")
		if body_sha256 != str(definition.get("body_sha256", "")):
			return _error("Routine-40 definition body fingerprint changed.")
		definition_rows.append({
			"definition_id": definition_id,
			"source_offset": source_offset,
			"body_offset": body_offset,
			"target_offset": target_offset,
			"body_size": target_offset - body_offset,
			"body_sha256": body_sha256,
		})
		previous_source = source_offset

	var consumer := _build_result_consumer(source, resume_offset, limit, definitions.size())
	if not consumer.get("ok", false):
		return consumer

	# A gate may hide some places under the declared seed (A_PROMIS.MES:2221:
	# fifteen individually-gated places, 13 registered under the location-0
	# baseline). The catalog is still strictly increasing 0..max_id, just with
	# gaps; `hidden_ids` records exactly which ids in that range never
	# registered, so a re-audit can prove the same options stayed hidden.
	var max_definition_id := -1
	if not definition_rows.is_empty():
		max_definition_id = int(definition_rows[-1].definition_id)
	var offered_ids := {}
	for row in definition_rows:
		offered_ids[int(row.definition_id)] = true
	var hidden_ids: Array[int] = []
	if definition_rows.size() > 1:
		for candidate_id in range(0, max_definition_id + 1):
			if not offered_ids.has(candidate_id):
				hidden_ids.append(candidate_id)
	var catalog_form := "sparse" if not hidden_ids.is_empty() else "contiguous"

	# Bind each hidden id to the exact gate branch a fresh static walk of the
	# bytecode finds in its place, so a re-audit (and this contract's own
	# validate(), which never replays the original run) can rehash that
	# branch's byte range and prove the same option stayed hidden rather than
	# trusting a bare id list. The walk is purely byte-structural, from the
	# lower offered DEF's own registered continuation towards the upper
	# offered DEF's own opcode: each candidate in between is its own
	# `branch_if_not_true` whose true-edge falls straight through to its own
	# `0x10` DEF (A_PROMIS.MES:2221's shape, one candidate immediately after
	# another) - so the walk reads that DEF's own literal selector to tell a
	# hidden candidate's gate from the upper offered id's own gate, rather
	# than assuming position, and follows a hidden gate's own encoded false
	# target to the next candidate. It reproduces identically whether called
	# from a live trace or from validate()'s from-scratch rebuild. Only an
	# interior gap (bounded on both sides by an offered id's own DEF) has
	# this landmark; a leading gap (an unoffered id below the first offered
	# one) has none, and is refused rather than guessed.
	var hidden_gates: Array[Dictionary] = []
	if not hidden_ids.is_empty():
		if int(definition_rows[0].definition_id) != 0:
			return _error("Routine-40 sparse catalog's leading gap has no supporting gate-branch landmark.")
		for pair_index in range(definition_rows.size() - 1):
			var lower_id := int(definition_rows[pair_index].definition_id)
			var upper_id := int(definition_rows[pair_index + 1].definition_id)
			if upper_id - lower_id <= 1:
				continue
			var cursor := int(definition_rows[pair_index].target_offset)
			var upper_offset := int(definition_rows[pair_index + 1].source_offset)
			var branch_rows: Array[Dictionary] = []
			var steps := 0
			var reached_upper := false
			while not reached_upper:
				steps += 1
				if steps > MAX_OPTIONS * 4:
					return _error("Routine-40 sparse catalog gap walk did not converge on the next offered id.")
				var marker_result := _dispatch_parser.skip_source_markers(source, cursor, limit)
				if not marker_result.get("ok", false):
					return _error("Routine-40 sparse catalog gap cannot be walked to the next offered id.")
				var resolved := int(marker_result.offset)
				if resolved == upper_offset:
					break
				if resolved > upper_offset:
					return _error("Routine-40 sparse catalog gap overran the next offered id.")
				var instruction := source.decode_at_structural(resolved, limit)
				if not instruction.get("ok", false) or int(instruction.command_id) != 0x0B:
					return _error("Routine-40 sparse catalog gap is not an individually gated place.")
				var fallthrough_result := _dispatch_parser.skip_source_markers(
					source, int(instruction.end_offset), limit
				)
				if not fallthrough_result.get("ok", false):
					return _error("Routine-40 hidden-option gate has no resolvable fallthrough.")
				var fallthrough_offset := int(fallthrough_result.offset)
				var fallthrough_instruction := source.decode_at_structural(fallthrough_offset, limit)
				var fallthrough_definition_id := (
					_def_definition_id(fallthrough_instruction)
					if fallthrough_instruction.get("ok", false)
					else -1
				)
				if fallthrough_definition_id < 0:
					return _error("Routine-40 hidden-option gate does not fall through to a DEF registration.")
				if fallthrough_definition_id == upper_id:
					if fallthrough_offset != upper_offset:
						return _error("Routine-40 sparse catalog gap's own gate does not resolve to the next offered id.")
					reached_upper = true
					break
				if fallthrough_definition_id != lower_id + 1 + branch_rows.size():
					return _error("Routine-40 sparse catalog gap ids are out of order.")
				var branch_target := _branch_target_offset(instruction)
				if branch_target < 0:
					return _error("Routine-40 hidden-option gate has no resolvable branch target.")
				branch_rows.append({
					"definition_id": fallthrough_definition_id,
					"source_offset": int(instruction.source_offset),
					"end_offset": int(instruction.end_offset),
				})
				cursor = branch_target
			if branch_rows.size() != upper_id - lower_id - 1:
				return _error("Routine-40 sparse catalog gap cannot be bound to an exact gate-branch run.")
			for branch_row in branch_rows:
				var gate_offset := int(branch_row.source_offset)
				var gate_end := int(branch_row.end_offset)
				if gate_end <= gate_offset or gate_end > limit:
					return _error("Routine-40 hidden-option gate branch has an invalid span.")
				# EP-12 PROMIS checkpoint C: the gate hash is an audit aid (a
				# re-audit rehashes it against the archive to confirm the same
				# option stayed hidden, `tools/audit_event_analysis_group.py`,
				# always archive-backed) - execution itself needs only the
				# structural fields above, already decoded from
				# provenance-checked records. A package-backed source has no
				# raw bytes to hash outside a definition body's own recorded
				# range, so `RANGE_UNAVAILABLE` here is honestly reported, the
				# same as `hex_range`'s own refusal, rather than refusing the
				# whole contract and stopping a package-only replay that an
				# archive-backed run completes cleanly.
				var gate_sha256 := source.sha256_range(gate_offset, gate_end)
				hidden_gates.append({
					"definition_id": int(branch_row.definition_id),
					"gate_offset": gate_offset,
					"gate_end": gate_end,
					"gate_condition_sha256": gate_sha256,
				})

	var contract := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_ROUTINE40_CHOICE_CONTRACT_SCHEMA,
		"bytecode_sha256": source.sha256_range(0, limit),
		"code_size": limit,
		"source_identity": source_identity.duplicate(true),
		"boundary_offset": int(terminal.source_offset),
		"resume_offset": resume_offset,
		"definition_count": definitions.size(),
		"definitions": definition_rows,
		"result_storage": RESULT_STORAGE,
		"result_index": RESULT_INDEX,
		"result_values": range(1, definitions.size() + 1),
		"consumer_kind": str(consumer.consumer_kind),
		"comparisons": (consumer.get("comparisons", []) as Array).duplicate(true),
		"option_entry_offsets": (consumer.get("option_entry_offsets", []) as Array).duplicate(),
		"gate": (consumer.get("gate", {}) as Dictionary).duplicate(true),
		"variants": (consumer.get("variants", []) as Array).duplicate(true),
		"fallback_offset": int(consumer.get("fallback_offset", -1)),
		"gate_policy": str(consumer.get("gate_policy", "not_applicable")),
		"redirect_offset": int(consumer.get("redirect_offset", -1)),
		"redirect_target_offset": int(consumer.get("redirect_target_offset", -1)),
		"catalog_form": catalog_form,
		"hidden_ids": hidden_ids,
		"hidden_gates": hidden_gates,
		"input_policy": "explicit_remake_choice",
		"native_input_semantics": "unresolved",
		"omitted_native_effects": ["state_u16_18_result", "state_u16_13_output", "routine20", "native_vector_clear"],
	}
	# EP-12 TALK (2026-10-04, Core 0.371.0; schema v6 since Core 0.372.0): the
	# scratch-split chain alone carries `position_gates`; every other consumer
	# form's contract keeps exactly the keys it always had (an installed
	# profile's stored contract is rebuilt byte for byte, schema string aside).
	if consumer.has("position_gates"):
		contract["position_gates"] = (consumer.position_gates as Array).duplicate(true)
	return contract


## Schemas before the sparse-catalog form (2026-09-25, Core 0.366.0). v4
## (2026-09-24, Core 0.363.0) added `redirect_offset` / `redirect_target_offset`
## over v3; v5 adds `catalog_form` / `hidden_ids` over v4. A stored v3 or v4
## contract stays valid as long as it carries none of the fields its own
## schema predates: a v3 contract is compared as if both redirect fields were
## -1 and neither catalog field existed; a v4 contract is compared with its
## own redirect fields but neither catalog field. Each prior schema's own
## `schema` string is not held against the rebuilt current one. A v3 contract
## carrying a redirect field, or a v3/v4 contract carrying a catalog field, is
## refused (TD-35's rule: an older-schema stored contract validates, the 182
## embedded v3 contracts stay green).
##
## v6 (2026-10-05, Core 0.372.0, EP-12 TALK, advisor ruling) adds `position_gates`
## over v5, the key the scratch-split consumer form carries (it had been added
## inside v5 at Core 0.371.0, before any contract of the form was installed for
## good). A stored v5 contract stays valid as long as it carries no
## `position_gates` (the 431 installed v5 contracts of the plain, gated, redirected
## and sparse forms: the builder tries the scratch-split form only where those
## rejected, so a rebuild of their bytes is the same contract); a v5 contract
## that carries it is refused, and its schema string is not held against the
## rebuilt v6.
const PRIOR_SCHEMA_V5 := "kakyu_mes_routine40_choice_contract/v5"
const PRIOR_SCHEMA_V4 := "kakyu_mes_routine40_choice_contract/v4"
const PRIOR_SCHEMA_V3 := "kakyu_mes_routine40_choice_contract/v3"


func validate(code, end_offset: int, contract: Dictionary) -> Dictionary:
	var schema := str(contract.get("schema", ""))
	var is_v3 := schema == PRIOR_SCHEMA_V3
	var is_v4 := schema == PRIOR_SCHEMA_V4
	var is_v5 := schema == PRIOR_SCHEMA_V5
	var prior_schema := is_v3 or is_v4
	if schema != ContentCoreVersionScript.MES_ROUTINE40_CHOICE_CONTRACT_SCHEMA and not (prior_schema or is_v5):
		return _error("Routine-40 choice contract schema is unsupported.")
	if is_v3 and (contract.has("redirect_offset") or contract.has("redirect_target_offset")):
		return _error("A v3 routine-40 choice contract cannot carry redirect fields.")
	if prior_schema and (
		contract.has("catalog_form") or contract.has("hidden_ids") or contract.has("hidden_gates")
	):
		return _error("A v3 or v4 routine-40 choice contract cannot carry sparse-catalog fields.")
	if (prior_schema or is_v5) and contract.has("position_gates"):
		return _error("A v3, v4 or v5 routine-40 choice contract cannot carry per-position gates.")
	var pseudo_result := {
		"status": "def_selection_boundary",
		"offset": int(contract.get("boundary_offset", -1)),
		"trace": [{
			"command_id": 0x1D,
			"routine_id": 40,
			"source_offset": int(contract.get("boundary_offset", -1)),
			"end_offset": int(contract.get("resume_offset", -1)),
		}],
		"definitions": (contract.get("definitions", []) as Array).duplicate(true),
	}
	var rebuilt := build(code, end_offset, pseudo_result, contract.get("source_identity", {}))
	if not rebuilt.get("ok", false):
		return rebuilt
	if (prior_schema or is_v5) and rebuilt.has("position_gates"):
		# The scratch-split form belongs to v6: an older contract is never of it, with or without the key.
		return _error("A v3, v4 or v5 routine-40 choice contract cannot be of the per-position-gate form.")
	var canonical := FingerprintScript.new()
	for key in [
		"schema", "bytecode_sha256", "code_size", "source_identity", "boundary_offset",
		"resume_offset", "definition_count", "definitions", "result_storage", "result_index",
		"result_values", "consumer_kind", "comparisons", "option_entry_offsets", "gate",
		"variants", "fallback_offset", "gate_policy", "redirect_offset", "redirect_target_offset",
		"catalog_form", "hidden_ids", "hidden_gates", "position_gates",
		"input_policy", "native_input_semantics", "omitted_native_effects",
	]:
		# JSON transport turns integers into whole floats, including nested DEF
		# rows. Compare the shared canonical numeric representation; fractional
		# changes and changed coordinates still fail closed.
		if (prior_schema or is_v5) and key == "schema":
			continue
		if prior_schema and key in ["catalog_form", "hidden_ids", "hidden_gates", "position_gates"]:
			continue
		# A v5 contract carries no `position_gates` (refused above): its rebuild is a
		# plain, gated, redirected or sparse form, which has none either.
		if is_v5 and key == "position_gates":
			continue
		var stored = contract.get(key)
		if is_v3 and key in ["redirect_offset", "redirect_target_offset"] and stored == null:
			stored = -1
		if canonical.canonical_document_json({"value":rebuilt.get(key)}) != canonical.canonical_document_json({"value":stored}):
			return _error("Routine-40 choice contract field changed: %s." % key)
	return rebuilt


func _build_result_consumer(
	source: KakyuMesCodeSource, resume_offset: int, limit: int, definition_count: int
) -> Dictionary:
	var direct := _build_direct_consumer(source, resume_offset, limit, definition_count)
	if direct.get("ok", false):
		return direct
	var redirect := _resolve_unconditional_redirect(source, resume_offset, limit)
	if redirect.get("ok", false):
		var redirected := _build_direct_consumer(
			source, int(redirect.target_offset), limit, definition_count
		)
		if redirected.get("ok", false):
			redirected["consumer_kind"] = "%s_via_unconditional_redirect" % str(redirected.consumer_kind)
			redirected["redirect_offset"] = int(redirect.source_offset)
			redirected["redirect_target_offset"] = int(redirect.target_offset)
			return redirected
	if definition_count == 1:
		return _error(
			"Single-row routine-40 consumer is not the exact result-1 branch shape, "
			+ "directly or through one unconditional redirect."
		)
	return _error(
		"Routine-40 result consumer is neither an exact one-based chain nor a complete "
		+ "gated matrix nor a per-position scratch-split chain, directly or through one "
		+ "unconditional redirect."
	)


# Tries the accepted shapes at exactly the given offset, with no redirect
# resolution, the two original shapes first and in their original order so a
# site they accept is built exactly as before; the scratch-split chain (EP-12
# TALK, Core 0.371.0) is tried only where both rejected.
func _build_direct_consumer(
	source: KakyuMesCodeSource, offset: int, limit: int, definition_count: int
) -> Dictionary:
	var canonical := _build_canonical_consumer(source, offset, limit, definition_count)
	if canonical.get("ok", false):
		return canonical
	if definition_count == 1:
		return {"ok": false}
	var gated := _build_gated_consumer(source, offset, limit, definition_count)
	if gated.get("ok", false):
		return gated
	return _build_scratch_split_consumer(source, offset, limit, definition_count)


# A third accepted shape: the routine-40's own resume coordinate lands on a
# single unconditional intra-script jump (command 0x0C) rather than directly
# on the result-branch chain, and that jump's destination is where the exact
# one-based chain or gated matrix actually begins. Confirmed for all 12
# `?_HOTEL.MES` menus (docs/spec/mes/format_and_method.md, "routine-40").
func _resolve_unconditional_redirect(
	source: KakyuMesCodeSource, offset: int, limit: int
) -> Dictionary:
	var cursor_result := _dispatch_parser.skip_source_markers(source, offset, limit)
	if not cursor_result.get("ok", false):
		return {"ok": false}
	var cursor := int(cursor_result.offset)
	var instruction := source.decode_at_structural(cursor, limit)
	if not instruction.get("ok", false):
		return {"ok": false}
	var transfer := _dispatch_parser.code_coordinate_transfer(instruction)
	if not transfer.get("ok", false):
		return {"ok": false}
	var target_result := _dispatch_parser.skip_source_markers(
		source, int(transfer.destination_offset), limit
	)
	if not target_result.get("ok", false):
		return {"ok": false}
	var target := int(target_result.offset)
	if target <= cursor or not source.decode_at_structural(target, limit).get("ok", false):
		return {"ok": false}
	return {"ok": true, "source_offset": cursor, "target_offset": target}


func _build_canonical_consumer(
	source: KakyuMesCodeSource, resume_offset: int, limit: int, definition_count: int
) -> Dictionary:
	var cursor_result := _dispatch_parser.skip_source_markers(source, resume_offset, limit)
	if not cursor_result.get("ok", false):
		return {"ok": false}
	var cursor := int(cursor_result.offset)
	var comparisons: Array[Dictionary] = []
	var option_entry_offsets: Array[int] = []
	if definition_count == 1:
		var instruction := source.decode_at_structural(cursor, limit)
		if not instruction.get("ok", false):
			return {"ok": false}
		var branch := _dispatch_parser.state_u16_equal_literal_branch(instruction)
		if (
			not branch.get("ok", false)
			or int(branch.state_index) != RESULT_INDEX
			or int(branch.literal) != 1
		):
			return {"ok": false}
		var targets := _dispatch_parser.validated_branch_targets(source, instruction, int(branch.target), limit)
		if (
			not targets.get("ok", false)
			or int(targets.fallthrough_offset) == int(targets.false_target_offset)
		):
			return {"ok": false}
		comparisons.append({
			"source_offset": int(instruction.source_offset),
			"result": 1,
			"fallthrough_offset": int(targets.fallthrough_offset),
			"false_target_offset": int(targets.false_target_offset),
		})
		return {
			"ok": true,
			"consumer_kind": "one_based_state_u16_21_branch_chain",
			"comparisons": comparisons,
			"option_entry_offsets": [int(targets.fallthrough_offset)],
			"gate": {},
			"variants": [],
			"fallback_offset": int(targets.false_target_offset),
			"gate_policy": "not_applicable",
		}
	for expected_result in range(1, definition_count):
		var instruction := source.decode_at_structural(cursor, limit)
		if not instruction.get("ok", false):
			return {"ok": false}
		var branch := _dispatch_parser.state_u16_equal_literal_branch(instruction)
		if (
			not branch.get("ok", false)
			or int(branch.state_index) != RESULT_INDEX
			or int(branch.literal) != expected_result
		):
			return {"ok": false}
		var targets := _dispatch_parser.validated_branch_targets(source, instruction, int(branch.target), limit)
		if not targets.get("ok", false):
			return {"ok": false}
		comparisons.append({
			"source_offset": int(instruction.source_offset),
			"result": expected_result,
			"fallthrough_offset": int(targets.fallthrough_offset),
			"false_target_offset": int(targets.false_target_offset),
		})
		option_entry_offsets.append(int(targets.fallthrough_offset))
		cursor = int(targets.false_target_offset)
	option_entry_offsets.append(cursor)
	return {
		"ok": true,
		"consumer_kind": "one_based_state_u16_21_branch_chain",
		"comparisons": comparisons,
		"option_entry_offsets": option_entry_offsets,
		"gate": {},
		"variants": [],
		"fallback_offset": -1,
		"gate_policy": "not_applicable",
	}


func _build_gated_consumer(
	source: KakyuMesCodeSource, resume_offset: int, limit: int, definition_count: int
) -> Dictionary:
	var cursor_result := _dispatch_parser.skip_source_markers(source, resume_offset, limit)
	if not cursor_result.get("ok", false):
		return {"ok": false}
	var cursor := int(cursor_result.offset)
	var rows: Array[Dictionary] = []
	var seen := {}
	while not seen.has(cursor) and rows.size() <= MAX_OPTIONS * MAX_OPTIONS:
		seen[cursor] = true
		var instruction := source.decode_at_structural(cursor, limit)
		if not instruction.get("ok", false):
			return {"ok": false}
		var branch := _dispatch_parser.compound_state_result_gate_branch(
			instruction, RESULT_STORAGE, RESULT_INDEX
		)
		if not branch.get("ok", false):
			break
		var targets := _dispatch_parser.validated_branch_targets(source, instruction, int(branch.target), limit)
		if not targets.get("ok", false):
			return {"ok": false}
		rows.append({
			"result": int(branch.result),
			"gate": (branch.gate as Dictionary).duplicate(true),
			"source_offset": int(instruction.source_offset),
			"option_entry_offset": int(targets.fallthrough_offset),
			"false_target_offset": int(targets.false_target_offset),
		})
		cursor = int(targets.false_target_offset)
	if rows.is_empty() or rows.size() > MAX_OPTIONS * MAX_OPTIONS:
		return {"ok": false}
	var gate_identity: Dictionary = (rows[0].gate as Dictionary).duplicate(true)
	gate_identity.erase("literal")
	if str(gate_identity.get("storage", "")) != "global_u8":
		return {"ok": false}
	var gate_values: Array[int] = []
	var row_index := 0
	for expected_result in range(1, definition_count + 1):
		var current_values: Array[int] = []
		while row_index < rows.size() and int(rows[row_index].result) == expected_result:
			var row_gate: Dictionary = rows[row_index].gate
			var row_identity := row_gate.duplicate(true)
			row_identity.erase("literal")
			if row_identity != gate_identity:
				return {"ok": false}
			var gate_value := int(row_gate.literal)
			if gate_value < 0 or gate_value > 0xFF or current_values.has(gate_value):
				return {"ok": false}
			current_values.append(gate_value)
			row_index += 1
		if expected_result == 1:
			gate_values = current_values
		elif current_values != gate_values:
			return {"ok": false}
	if row_index != rows.size() or gate_values.size() < 2 or gate_values.size() > MAX_OPTIONS:
		return {"ok": false}
	var variants: Array[Dictionary] = []
	for row in rows:
		variants.append({
			"result": int(row.result),
			"gate_value": int(row.gate.literal),
			"source_offset": int(row.source_offset),
			"option_entry_offset": int(row.option_entry_offset),
			"false_target_offset": int(row.false_target_offset),
		})
	gate_identity["values"] = gate_values
	return {
		"ok": true,
		"consumer_kind": "gated_one_based_state_u16_21_branch_matrix",
		"comparisons": [],
		"option_entry_offsets": [],
		"gate": gate_identity,
		"variants": variants,
		"fallback_offset": cursor,
		"gate_policy": "preserve_existing_validated_value",
	}


# EP-12 TALK (2026-10-04, owner ruling, Core 0.371.0): the third accepted
# shape, measured at the first question of 64 `?_TALK*.MES` rung scripts in the
# state a place calls them in (the heroine's presence flag set registers the
# ids 0, 2, 3, 4 and 5; docs/spec/mes/talk_family.md). The consumer is still a
# one-based chain on state_u16[21], but a position is one of
#   - a pure `state_u16[21] == k` row, exactly the original chain's row, or
#   - one or more `state_u16[21] == k and global_u8[c] == v` rows, every row of
#     the position testing the same cell `c` against a different value `v` (a
#     position that splits on a per-position scratch cell; one row means the
#     option is entered only while `c == v`).
# Positions 1..n-1 are read as rows and position n is the remaining chain, as
# in the original chain (its entry is where the last row's false edge lands).
# Every row's false edge leads to the next row. The rows are recorded in
# `comparisons` (a compound row also carries its `gate`), the cell of each
# position in `position_gates`. At least one position must split, else the
# original chain would have matched. The gate is the exact `global_u8` cell and
# literal the bytecode compares; nothing is inferred about what writes the cell.
func _build_scratch_split_consumer(
	source: KakyuMesCodeSource, resume_offset: int, limit: int, definition_count: int
) -> Dictionary:
	if definition_count < 2:
		return {"ok": false}
	var cursor_result := _dispatch_parser.skip_source_markers(source, resume_offset, limit)
	if not cursor_result.get("ok", false):
		return {"ok": false}
	var cursor := int(cursor_result.offset)
	var comparisons: Array[Dictionary] = []
	var option_entry_offsets: Array[int] = []
	var position_gates: Array[Dictionary] = []
	var seen := {}
	var any_split := false
	for expected_result in range(1, definition_count):
		var position_rows := 0
		var position_cell := -1
		var position_values: Array[int] = []
		var position_pure := false
		while true:
			if seen.has(cursor):
				return {"ok": false}
			var instruction := source.decode_at_structural(cursor, limit)
			if not instruction.get("ok", false):
				return {"ok": false}
			var row_gate := {}
			var row_target := -1
			var pure := _dispatch_parser.state_u16_equal_literal_branch(instruction)
			if (
				pure.get("ok", false)
				and int(pure.state_index) == RESULT_INDEX
				and int(pure.literal) == expected_result
			):
				row_target = int(pure.target)
			else:
				var compound := _dispatch_parser.compound_state_result_gate_branch(
					instruction, RESULT_STORAGE, RESULT_INDEX
				)
				if (
					compound.get("ok", false)
					and int(compound.result) == expected_result
					and str(compound.gate.storage) == "global_u8"
					and int(compound.gate.literal) >= 0
					and int(compound.gate.literal) <= 0xFF
				):
					row_gate = (compound.gate as Dictionary).duplicate(true)
					row_target = int(compound.target)
			if row_target < 0:
				# The position's rows ended, or the chain is not this shape.
				if position_rows == 0:
					return {"ok": false}
				break
			var is_pure := row_gate.is_empty()
			if position_rows > 0 and (
				position_pure
				or is_pure
				or int(row_gate.index) != position_cell
				or position_values.has(int(row_gate.literal))
			):
				return {"ok": false}
			var targets := _dispatch_parser.validated_branch_targets(source, instruction, row_target, limit)
			if not targets.get("ok", false):
				return {"ok": false}
			seen[cursor] = true
			var row := {
				"source_offset": int(instruction.source_offset),
				"result": expected_result,
				"fallthrough_offset": int(targets.fallthrough_offset),
				"false_target_offset": int(targets.false_target_offset),
			}
			if not is_pure:
				row["gate"] = row_gate
				position_cell = int(row_gate.index)
				position_values.append(int(row_gate.literal))
				any_split = true
			else:
				position_pure = true
			comparisons.append(row)
			if position_rows == 0:
				option_entry_offsets.append(int(targets.fallthrough_offset))
			position_rows += 1
			cursor = int(targets.false_target_offset)
			if position_pure:
				break
		if position_pure:
			position_gates.append({"result": expected_result, "gate": {}})
		else:
			position_gates.append({
				"result": expected_result,
				"gate": {"storage": "global_u8", "index": position_cell, "values": position_values},
			})
	if not any_split:
		return {"ok": false}
	option_entry_offsets.append(cursor)
	return {
		"ok": true,
		"consumer_kind": "one_based_state_u16_21_scratch_split_branch_chain",
		"comparisons": comparisons,
		"option_entry_offsets": option_entry_offsets,
		"position_gates": position_gates,
		"gate": {},
		"variants": [],
		"fallback_offset": -1,
		"gate_policy": "not_applicable",
	}



# A generic, condition-shape-independent read of a `0x10` DEF instruction's
# own literal selector (its declared definition id), used by the sparse
# catalog's static gap walk to identify which candidate a gate falls through
# to without assuming position. -1 for anything else or a malformed operand.
func _def_definition_id(instruction: Dictionary) -> int:
	if int(instruction.get("command_id", -1)) != 0x10:
		return -1
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 2:
		return -1
	var records: Array = (operands[0] as Dictionary).get("records", [])
	if records.size() != 1 or str((records[0] as Dictionary).get("type", "")) != "expression_record":
		return -1
	var ast: Dictionary = ((records[0] as Dictionary).get("value", {}) as Dictionary).get("ast", {})
	if str(ast.get("type", "")) != "literal":
		return -1
	return int(ast.get("value", -1))


# A generic, condition-shape-independent read of a `0x0B` branch's own
# encoded jump target (its false-edge coordinate), used the same way.
func _branch_target_offset(instruction: Dictionary) -> int:
	if int(instruction.get("command_id", -1)) != 0x0B:
		return -1
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 2 or str((operands[1] as Dictionary).get("type", "")) != "code_offset":
		return -1
	return int((operands[1] as Dictionary).get("value", -1))


# Callers pass either the bytecode itself or a code source supplied by a
# playback package. Both answer the same questions. See mes_code_source.gd.
func _as_source(code) -> KakyuMesCodeSource:
	if code is KakyuMesCodeSource:
		return code
	return KakyuMesCodeSource.for_bytecode(code if code is PackedByteArray else PackedByteArray())


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
