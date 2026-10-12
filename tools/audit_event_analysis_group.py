"""Bind declarative event-analysis witnesses to original Python handoff records.

This certifies source coordinates, not witness truth or route completion. The
headless group validator executes the supplied states and checks those claims.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from build_event_analysis_inventory import fingerprint, _selector
from extract_kakyu_arc import read_entries
from mes_analyzer_handoff import build_handoff, build_container
from mes_instruction_ir import decode_instruction_ir

SCHEMA = "kakyu_event_analysis_group/v1"
V2_SCHEMA = "kakyu_event_analysis_group/v2"
V3_SCHEMA = "kakyu_event_analysis_group/v3"
V4_SCHEMA = "kakyu_event_analysis_group/v4"
V5_SCHEMA = "kakyu_event_analysis_group/v5"
V6_SCHEMA = "kakyu_event_analysis_group/v6"
V7_SCHEMA = "kakyu_event_analysis_group/v7"
# v8 is v5's returning callee with one addition: a caller whose resume ends at a
# routine-40 registered-definition selection rather than at a dispatch or a root
# handoff. The policy is v8-only so no existing profile can widen its contract.
V8_SCHEMA = "kakyu_event_analysis_group/v8"
# v9 is v8's caller-continuation contract (returning callee, all three resume
# boundary policies, reentry, choice contracts) with v7's unguarded declaration
# in place of a local guard: no guard, no guard_cases, no post_guard_expected,
# and an unconditional_dispatch window in their place. It is v7's proof applied
# to a caller that resumes rather than one that replaces the root.
V9_SCHEMA = "kakyu_event_analysis_group/v9"
# v10 (0.317.0) is v8's returning callee with a fourth caller-resume boundary
# policy: a caller whose post-event sequence runs into its own loop - the
# floor's interactive menu, which only native input leaves. The probe proves
# the loop by a repeated continuation and stops at its head; the profile
# declares that head as the resume outcome plus `loop` (period, cycle rows,
# messages per period), every row an exact typed record of the caller. The
# policy is v10-only so no existing profile can widen its contract.
V10_SCHEMA = "kakyu_event_analysis_group/v10"
# v11 / v12 (0.318.0) add map-location contracts: a route that enters a
# member's map input loop declares the Map.get_location poll record
# (command 0x12, Util(6,13)) and the ordered locations the player reaches
# there, which the runtime supplies into the cell the native map module
# writes (state_u16[18], 0xFFFF for none - ai5-sdl2's Kakyuusei module).
# v11 is v6's root replacement with contracts, v12 is v10's caller
# continuation with contracts; the field is refused under every other schema.
V11_SCHEMA = "kakyu_event_analysis_group/v11"
V12_SCHEMA = "kakyu_event_analysis_group/v12"
# v13 (0.361.0, EP-11 part 1a) is v8's returning callee with one addition: an
# optional route field `visits`, an ordered list that extends the one
# committed reentry pass with further replays of the same callee for a
# callee whose own visit counter keeps changing what it does past the first
# reentry. Each visit names an `after` pass ("route" - the state the
# dispatch and caller resume left, the same state reentry itself starts
# from - "reentry", or an earlier visit's own visit_id), `seed_writes` (with
# a required `seed_basis`), an exact returning outcome, a message count and
# the nested dispatches it makes (each bound to its own exact record and
# return in the dispatched member). `visits` is refused under every other
# schema so no existing profile can widen its contract by a schema field
# alone.
V13_SCHEMA = "kakyu_event_analysis_group/v13"
# v14 (EP-12, 2026-09-24, tool decision) declares a flow: a chain of hops from
# an origin guard through every nested call and root handoff to the flow's
# end, no single caller/callee pair. Each hop names its own `entry`, an
# `entered_by` record found in the hop before it (a nested-call or
# root-handoff hop's record is the previous hop's own dispatch/handoff
# outcome; a resume hop's is the previous hop's own return, since the
# archive has no separate "resume" record), `answers`, `gates` and its own
# `expected` outcome/message_count/expected_state. `terminal` is the last
# hop's own outcome, named again at route level. This first part proves the
# shape only on synthetic archives; see docs/spec/tech/content_tools.md.
V14_SCHEMA = "kakyu_event_analysis_group/v14"
ANCHORED_SCHEMAS = (V4_SCHEMA, V5_SCHEMA, V6_SCHEMA, V7_SCHEMA, V8_SCHEMA, V9_SCHEMA, V10_SCHEMA, V11_SCHEMA, V12_SCHEMA, V13_SCHEMA)
VISIT_SCHEMAS = (V13_SCHEMA,)
VISIT_AFTER_KEYWORDS = ("route", "reentry")
MAP_LOCATION_SCHEMAS = (V11_SCHEMA, V12_SCHEMA)
MAP_LOCATION_CONTRACT_SCHEMA = "kakyu_mes_map_location_contract/v1"
# EP-12 part 3 (2026-09-24): Content Core 0.363.0 bumped the routine-40 choice
# contract schema to v4 for the unconditional-redirect consumer shape
# (docs/spec/mes/format_and_method.md's "Two selector sites, re-read"); every
# already-shipped profile still carries the frozen v3 string on a contract
# that predates the bump (v4 added only two redirect fields), but this audit
# had never accepted a fresh v4 contract at all, only the literal v3 string -
# a real gap, not yet exercised because no profile had used the redirect
# shape until this one. Both schemas are accepted the same way the shared
# GDScript validate() does; the two redirect fields are not otherwise
# interpreted here (only the runtime seam that consumes them cares).
# v5 (2026-09-25, Core 0.366.0, EP-12 routine-40 sparse catalog) accepts a
# definitions list whose ids are strictly increasing but not necessarily
# `0..n-1` (A_PROMIS.MES:2221's 15-place picker, gated per place, offers only
# the ids whose own gate held) and adds `catalog_form`/`hidden_ids`/
# `hidden_gates`; both are re-verified below alongside every existing check.
# v6 (2026-10-05, Core 0.372.0, EP-12 TALK) adds `position_gates`, the key of the
# scratch-split consumer form, over v5; the sparse-catalog re-derivation below
# applies to a v5 and a v6 contract alike (the GDScript `validate()` owns the
# per-position gates and refuses a v3/v4/v5 contract that carries them).
ROUTINE40_CHOICE_CONTRACT_SCHEMAS = (
    "kakyu_mes_routine40_choice_contract/v3",
    "kakyu_mes_routine40_choice_contract/v4",
    "kakyu_mes_routine40_choice_contract/v5",
    "kakyu_mes_routine40_choice_contract/v6",
)
ROUTINE40_SPARSE_CATALOG_SCHEMAS = (
    "kakyu_mes_routine40_choice_contract/v5",
    "kakyu_mes_routine40_choice_contract/v6",
)
ROUTINE40_MAX_OPTIONS = 17
MAP_LOCATION_POLL = (6, 13)
LOOP_ROW_COMMANDS = {"dialogue_boundary": 13, "shared_routine_boundary": 29}
REPLACEMENT_SCHEMAS = (V6_SCHEMA, V7_SCHEMA, V11_SCHEMA)
# A root replacement's caller record is the command-0E handoff itself, or -
# since 2026-09-13 - a command-0F nested call whose callee hands the root on
# without ever returning; the caller outcome names which.
ROOT_REPLACEMENT_OUTCOMES = ({"kind": "root_handoff"}, {"kind": "nested_root_handoff"})
ROOT_REPLACEMENT_COMMANDS = {"root_handoff": 14, "nested_root_handoff": 15}
OBSERVATION_SCHEMAS = (V3_SCHEMA, *ANCHORED_SCHEMAS)
AUDIT_SCHEMA = "kakyu_event_analysis_group_source_audit/v1"
DEFAULT_PROFILE = Path("config/event_catalog/analysis_groups/ground_h17_k09_v2.json")


def _return_record(records: dict, outcome: dict) -> None:
    row = records[outcome["offset"]]
    if (outcome["status"] != "script_return" or row["command_id"] != 0
            or row["end_offset"] != outcome["end"] or row["op"] != outcome["op"]):
        raise ValueError("Completed reentry is not an exact return record")


def _reentry_record(records: dict, outcome: dict, schema: str) -> None:
    if schema in OBSERVATION_SCHEMAS:
        if any(type(outcome[key]) is not int or outcome[key] < 0 for key in ("offset", "end")):
            raise ValueError("Reentry observation coordinates must be nonnegative integers")
        if outcome["status"] == "def_selection_boundary":
            row = records[outcome["offset"]]
            if (row["command_id"] != 29 or _selector(row) != 40
                    or row["end_offset"] != outcome["end"] or row["op"] != outcome["op"]):
                raise ValueError("Reentry observation is not an exact routine-40 selection record")
            return
    _return_record(records, outcome)


def _bound_record(entry: str, observation: dict, documents: dict, records: dict,
                  payloads: dict, *, allow_typed: bool,
                  mismatch_message: str = "Runtime observation record bytes differ") -> dict:
    """Check one declared record without promoting bytes in an opaque tail."""
    code = build_container(payloads[entry])["_bytecode"]
    binding = observation["source_binding"]
    if allow_typed and binding["kind"] == "typed_record":
        row = records[entry].get(observation["offset"], {})
    elif binding["kind"] == "runtime_observation_in_opaque_tail" and any(
            tail["source_offset"] == binding["offset"] and tail["end_offset"] == binding["end"]
            and tail["raw_sha256"] == binding["sha256"]
            and tail["source_offset"] <= observation["offset"] < observation["end"] <= tail["end_offset"]
            for tail in documents[entry]["typed_ir"]["opaque_boundaries"]):
        row = decode_instruction_ir(code, observation["offset"], observation["end"], structural=True)
    else:
        raise ValueError("Runtime observation is not bound to the declared opaque tail")
    if (not row.get("ok") or row["end_offset"] != observation["end"]
            or hashlib.sha256(code[observation["offset"]:observation["end"]]).hexdigest()
            != observation["record_sha256"]):
        raise ValueError(mismatch_message)
    return row


def _dispatch_window(document: dict, records: dict, origin: int, caller: dict) -> dict:
    """Measure the caller window a v7 route claims cannot skip its dispatch.

    This is a source-bound structural statement about one interval, not a
    reachability claim: it says nothing about how execution arrives at the
    origin, and a terminal record inside the window is reported rather than
    ruled inert. The runtime witnesses cover the states actually executed.
    """
    def targets(node, found: list) -> None:
        if isinstance(node, dict):
            if node.get("type") == "code_offset":
                found.append(node.get("value"))
            for value in node.values():
                targets(value, found)
        elif isinstance(node, list):
            for value in node:
                targets(value, found)

    window = [row for row in records.values() if origin <= row["source_offset"] < caller["offset"]]
    edges, returns, dispatches = [], [], []
    for row in window:
        found: list = []
        targets(row.get("operands", []), found)
        edges.extend(found)
        if row["command_id"] == 0:
            returns.append(row["source_offset"])
        # Command 0x0E partitions into exactly two decoded ops with no
        # residue (docs/spec/mes/event_corpus_inventory.md): a real handoff,
        # script_handoff_marker, and protagonist_name_insert, which carries no
        # script target and is not a dispatch. Command 0x0F is fully literal,
        # always script_dispatch. Classify by the decoded op, not the shared
        # raw command_id, so a name-insert record does not read as a dispatch.
        if row.get("op") in ("script_dispatch", "script_handoff_marker"):
            dispatches.append(row["source_offset"])
    # A target equal to the dispatch offset still executes it; anything past
    # that offset - the dispatch's own end included - skips it.
    return {"record_count": len(window), "edge_count": len(edges),
            "escaping_edges": sorted({t for t in edges if not origin <= t <= caller["offset"]}),
            "interior_dispatch_offsets": sorted(dispatches),
            "return_candidate_offsets": sorted(returns),
            "opaque_overlaps": [tail["source_offset"] for tail in document["typed_ir"]["opaque_boundaries"]
                                if tail["source_offset"] < caller["offset"] and tail["end_offset"] > origin]}


def _audit_unconditional_dispatch(route: dict, document: dict, records: dict, code: bytes) -> dict:
    """Prove no edge inside the declared window transfers past the dispatch."""
    declared, caller = route["unconditional_dispatch"], route["caller"]
    origin = route["origin_offset"]
    measured = _dispatch_window(document, records, origin, caller)
    if measured["escaping_edges"] or measured["interior_dispatch_offsets"] or measured["opaque_overlaps"]:
        raise ValueError("Declared window can skip, divert or hide the dispatch")
    if (type(declared["record_count"]) is not int or declared["record_count"] < 1
            or type(declared["edge_count"]) is not int or declared["edge_count"] < 0
            or declared["record_count"] != measured["record_count"]
            or declared["edge_count"] != measured["edge_count"]
            or declared["return_candidate_offsets"] != measured["return_candidate_offsets"]
            or hashlib.sha256(code[origin:caller["end"]]).hexdigest() != declared["prefix_sha256"]):
        raise ValueError("Unconditional dispatch declaration differs from the original window")
    return measured


def _audit_selections(variant: dict, contracts: dict, schema: str) -> None:
    selections = variant["selections"]
    keys = [(s["owner_entry"], s["boundary_offset"]) if schema in ANCHORED_SCHEMAS
            else s["boundary_offset"] for s in selections]
    if (len(selections) != len(contracts) or set(keys) != set(contracts)
            or any(type(s["result_value"]) is not int
                   or s["result_value"] not in contracts[key]["result_values"]
                   for s, key in zip(selections, keys))):
        raise ValueError("Variant must select each declared choice exactly once")


def _audit_context(context: dict, documents: dict) -> None:
    if context["kind"] == "original_calendar":
        if (context["entry"] != "START.MES" or context["entry"] not in documents
                or len(context["table_sha256"]) != 64
                or any(c not in "0123456789abcdef" for c in context["table_sha256"])):
            raise ValueError("Calendar context needs a source member and table fingerprint")
    elif context != {"kind": "fresh"}:
        raise ValueError("Unsupported runtime state context")


def _audit_counts(counts: list) -> None:
    if any(type(count) is not int or count < 0 for count in counts):
        raise ValueError("Message observation count is invalid")


def _audit_write_groups(writes: list) -> None:
    """Shared range/duplicate check for every declared list of state writes,
    one group at a time (a duplicate key is only rejected within its own
    group - a route and a hop may each legitimately write the same cell)."""
    for group in writes:
        keys = set()
        for value in group:
            storage = value["storage"]
            key = (storage, value["bank"], value["index"])
            maximum = {"global_u8": 255, "state_u16": 65535, "banked_u16": 65535}.get(storage)
            if (maximum is None or any(type(value[k]) is not int for k in ("bank", "index", "value"))
                    or value["bank"] != 0 or not 0 <= value["index"] <= 65535
                    or not 0 <= value["value"] <= maximum or key in keys):
                raise ValueError("Analysis state write is unsupported, duplicate or out of range")
            keys.add(key)


def _bound_terminal(entry: str, outcome: dict, documents: dict, records: dict, payloads: dict) -> None:
    """Validate an observed terminal without inferring reachability or completion."""
    if any(type(outcome[key]) is not int or outcome[key] < 0 for key in ("offset", "end")):
        raise ValueError("Terminal observation coordinates must be nonnegative integers")
    row = _bound_record(entry, outcome, documents, records, payloads, allow_typed=True)
    status = outcome["status"]
    valid = ((status == "script_return" and row["command_id"] == 0)
             or (status == "def_selection_boundary" and row["command_id"] == 29 and _selector(row) == 40)
             or (status == "script_handoff_boundary" and row["command_id"] == 14
                 and isinstance(outcome.get("target"), str) and bool(outcome["target"])
                 and row.get("script_target", "").upper() == outcome["target"]))
    if not valid or row["op"] != outcome["op"]:
        raise ValueError("Terminal outcome is not the declared exact return, selection or handoff")


def _audit_contracts(route: dict, documents: dict, records: dict, payloads: dict, schema: str) -> dict:
    # `route["callee"]` is read lazily (only for a non-anchored schema, where
    # the callee is the sole possible owner) so a v14 flow - which has no
    # single route-wide callee, only per-hop entries - can reuse this
    # anchored-owner binding by passing V6_SCHEMA without needing one.
    contracts = {}
    for contract in route["choice_contracts"]:
        at = contract["boundary_offset"]
        owner = contract["source_identity"]["entry"] if schema in ANCHORED_SCHEMAS else route["callee"]["entry"]
        if owner not in documents:
            raise ValueError("Choice owner must be a declared source member")
        owner_code = build_container(payloads[owner])["_bytecode"]
        contract_key = (owner, at) if schema in ANCHORED_SCHEMAS else at
        call = records[owner][at]
        definitions = contract["definitions"]
        if (contract_key in contracts or contract["schema"] not in ROUTINE40_CHOICE_CONTRACT_SCHEMAS
                or contract["source_identity"] != {"archive":"mes.arc", "entry":owner}
                or call["command_id"] != 29 or _selector(call) != 40
                or call["end_offset"] != contract["resume_offset"]
                or not 1 <= len(definitions) <= 17
                or contract["definition_count"] != len(definitions)
                or contract["result_values"] != list(range(1, len(definitions) + 1))
                or contract["bytecode_sha256"] != hashlib.sha256(owner_code).hexdigest()
                or contract["code_size"] != len(owner_code)):
            raise ValueError("Choice contract is not the declared original routine-40 boundary")
        definition_ids = [definition["definition_id"] for definition in definitions]
        if len(definitions) > 1:
            if any(definition_ids[i] >= definition_ids[i + 1] for i in range(len(definition_ids) - 1)):
                raise ValueError("Choice definition identifiers are not strictly increasing")
            if any(not 0 <= identifier <= ROUTINE40_MAX_OPTIONS - 1 for identifier in definition_ids):
                raise ValueError("Choice definition identifier is outside the supported catalog range")
        elif not 0 <= definition_ids[0] <= 255:
            raise ValueError("Choice definition identifier is outside the supported single-row range")
        for definition in definitions:
            declaration = records[owner][definition["source_offset"]]
            body, end = definition["body_offset"], definition["target_offset"]
            if (declaration["command_id"] != 16 or _selector(declaration) != definition["definition_id"]
                    or declaration["end_offset"] != body
                    or int.from_bytes(bytes(declaration["operands"][1]["value"]), "little") != end
                    or not body < end <= at or definition["body_size"] != end - body
                    or hashlib.sha256(owner_code[body:end]).hexdigest() != definition["body_sha256"]):
                raise ValueError("Choice definition bounds or fingerprint differ")
        if contract["schema"] in ROUTINE40_SPARSE_CATALOG_SCHEMAS:
            _audit_sparse_catalog(contract, definitions, definition_ids, owner_code, records[owner])
        elif any(contract.get(key) is not None for key in ("catalog_form", "hidden_ids", "hidden_gates")):
            raise ValueError("A prior-schema routine-40 choice contract cannot carry sparse-catalog fields")
        contracts[contract_key] = contract
    return contracts


def _audit_sparse_catalog(
    contract: dict, definitions: list, definition_ids: list, owner_code: bytes, owner_records: dict
) -> None:
    """Independently re-derive the sparse catalog's own hidden ids and gate
    evidence from the archive, matching mes_routine40_choice_contract.gd's own
    build()/validate() so a stored v5 contract cannot claim a hidden option
    that the fresh archive bytes do not support."""
    max_id = definition_ids[-1] if definition_ids else -1
    offered = set(definition_ids)
    hidden_ids = [i for i in range(max_id + 1) if i not in offered] if len(definition_ids) > 1 else []
    catalog_form = "sparse" if hidden_ids else "contiguous"
    if contract.get("catalog_form") != catalog_form or contract.get("hidden_ids") != hidden_ids:
        raise ValueError("Choice contract catalog form or hidden ids differ from the archive")
    hidden_gates = contract.get("hidden_gates", [])
    if [gate["definition_id"] for gate in hidden_gates] != hidden_ids:
        raise ValueError("Choice contract hidden gates do not name exactly the hidden ids in order")
    offset_by_id = {definition["definition_id"]: definition["source_offset"] for definition in definitions}
    for gate in hidden_gates:
        identifier = gate["definition_id"]
        # The nearest offered ids below/above this one, not `identifier +/- 1`:
        # a run of several consecutive hidden ids shares the same bounding
        # pair of offered definitions.
        below = [i for i in definition_ids if i < identifier]
        above = [i for i in definition_ids if i > identifier]
        lower_bound = offset_by_id.get(max(below)) if below else None
        upper_bound = offset_by_id.get(min(above)) if above else None
        gate_offset, gate_end = gate["gate_offset"], gate["gate_end"]
        declaration = owner_records.get(gate_offset)
        if (lower_bound is None or upper_bound is None
                or declaration is None or declaration["command_id"] != 11
                or declaration["end_offset"] != gate_end
                or not lower_bound < gate_offset < gate_end <= upper_bound
                or hashlib.sha256(owner_code[gate_offset:gate_end]).hexdigest() != gate["gate_condition_sha256"]):
            raise ValueError("Hidden-option gate record differs from the archive")


def _audit_bypasses(route: dict, contracts: dict, documents: dict, records: dict, payloads: dict, schema: str) -> list:
    caller, writes = route["caller"], []
    bypasses = route.get("bypass_variants", []) if schema in ANCHORED_SCHEMAS else []
    variant_ids = [variant["variant_id"] for variant in route["variants"] + bypasses]
    if len(set(variant_ids)) != len(variant_ids):
        raise ValueError("Duplicate normal or bypass variant ID")
    for bypass in bypasses:
        _audit_selections(bypass, contracts, schema)
        out = bypass["outcome"]
        if (any(type(out[key]) is not int or out[key] < 0 for key in ("offset", "end"))
                or not isinstance(out["target"], str) or not out["target"]):
            raise ValueError("Bypass handoff needs exact coordinates and a nonempty target")
        row = _bound_record(caller["entry"], out, documents, records, payloads, allow_typed=True)
        if (row["command_id"] != 14 or row["op"] != out["op"]
                or out["status"] != "script_handoff_boundary"
                or row.get("script_target", "").upper() != out["target"]):
            raise ValueError("Bypass outcome is not an exact handoff observation")
        writes.extend([bypass["writes"], bypass["expected_state"]])
    _audit_counts([b["message_count"] for b in bypasses])
    return writes


def _audit_continuation(route: dict, documents: dict, records: dict, payloads: dict,
                        schema: str = V2_SCHEMA) -> list:
    """Bind explicit runtime state, choices, caller resume and reentry evidence.

    An observation in an existing opaque tail stays opaque in the handoff.
    Decoding its declared span checks bytes only; the runtime must independently
    reach that exact record from the confirmed caller and preserve its trace.
    """
    caller, callee = route["caller"], route["callee"]
    if route["caller_outcome"] != {"kind": "dispatch"} or route["outcome"]["status"] != "script_return":
        raise ValueError("Continuation requires a dispatched returning callee")
    unconditional = schema == V9_SCHEMA
    # 0.315.0: a caller-continuation route (V5, V8) may declare its post-guard
    # truth at route level, optionally overridden per variant, exactly as V6
    # root-replacement routes do (_audit_root_replacement below). V9 stays
    # unguarded - it has no local guard at all - and continues to fail closed
    # via the unconditional check on both route and variant.
    # A handful of already-shipped V8 profiles carry a route-level
    # post_guard_expected: null placeholder from before this field had any
    # meaning for a continuation route; null is absent, not a declared 0/1.
    if schema in (V5_SCHEMA, V8_SCHEMA, V10_SCHEMA, V12_SCHEMA, V13_SCHEMA) and route.get("post_guard_expected") is not None:
        if type(route["post_guard_expected"]) is not int or route["post_guard_expected"] not in (0, 1):
            raise ValueError("Post-guard expectation must be integer zero or one")
    _audit_context(route["state_context"], documents)
    resume, reentry = route["resume"], route["reentry"]
    typed_resume = resume["start"] in records[caller["entry"]]
    opaque_resume = (schema in ANCHORED_SCHEMAS
                     and caller["source_binding"]["kind"] == "runtime_observation_in_opaque_tail"
                     and caller["source_binding"]["offset"] <= resume["start"] < caller["source_binding"]["end"])
    if resume["start"] != caller["end"] or not (typed_resume or opaque_resume):
        raise ValueError("Caller resume is not the exact dispatch end")
    out = resume["outcome"]
    command, status = 14, "script_handoff_boundary"
    if schema in OBSERVATION_SCHEMAS:
        expected_qualification = ("unconditional_caller_continuation_observation" if unconditional
                                  else "caller_continuation_observation")
        if route["qualification"] != expected_qualification:
            version = schema.rsplit("/", 1)[1].upper()
            raise ValueError(f"{version} requires an explicit caller-continuation observation qualification")
        policies = {"stop_before_unprovided_dependency": (15, "script_dispatch_boundary"),
                    "natural_handoff": (14, "script_handoff_boundary")}
        if schema in (V8_SCHEMA, V9_SCHEMA, V10_SCHEMA, V12_SCHEMA, V13_SCHEMA):
            policies["def_selection_boundary"] = (29, "def_selection_boundary")
        if schema in (V10_SCHEMA, V12_SCHEMA):
            # The loop head is whichever boundary record the continuation
            # first repeats at; its command is checked through the cycle.
            policies["caller_menu_loop"] = (None, "loop_boundary")
        if resume["boundary_policy"] not in policies:
            raise ValueError("Unsupported caller-continuation boundary policy")
        command, status = policies[resume["boundary_policy"]]
        if command == 15 and out["target"] in documents:
            raise ValueError("A dependency-stop target must be absent from source members")
        if command == 29 and out["target"] != "":
            raise ValueError("A definition-selection stop names no script target")
        if command is None and out["target"] != "":
            raise ValueError("A loop stop names no script target")
        if any(type(out[key]) is not int or out[key] < 0 for key in ("offset", "end")):
            raise ValueError("Caller-continuation coordinates must be nonnegative integers")
    # 0.316.0: a record the decoder types is bound as a typed record under
    # every schema. The historical V2 groups observed their resume inside
    # opaque tails that the system-call grammar has since typed; their bytes
    # and hashes are unchanged, only the binding kind moved with the decoder.
    row = _bound_record(caller["entry"], out, documents, records, payloads,
                        allow_typed=True,
                        mismatch_message="Runtime handoff observation bytes differ")
    if ((command is not None and row["command_id"] != command)
            or row["op"] != out["op"] or out["status"] != status
            or row.get("script_target", "").upper() != out["target"]):
        raise ValueError("Runtime handoff observation bytes differ")
    if command == 29 and _selector(row) != 40:
        raise ValueError("A definition-selection stop must be an exact routine-40 record")
    if command is None:
        _audit_loop(resume, out, records[caller["entry"]], caller["entry"])
    _reentry_record(records[callee["entry"]], reentry["outcome"], schema)
    visit_writes, visit_counts = _audit_visits(route, documents, records, payloads, schema)
    contracts = _audit_contracts(route, documents, records, payloads, schema)
    _audit_map_location_contracts(route, documents, records, payloads, schema)
    writes = [resume["expected_state"], reentry["expected_state"], *visit_writes]
    reentries = [reentry]
    for variant in route["variants"]:
        if unconditional and "post_guard_expected" in variant:
            raise ValueError("An unguarded route cannot claim a post-guard truth")
        if schema in (V5_SCHEMA, V8_SCHEMA, V13_SCHEMA) and variant.get("post_guard_expected") is not None:
            if type(variant["post_guard_expected"]) is not int or variant["post_guard_expected"] not in (0, 1):
                raise ValueError("Post-guard expectation must be integer zero or one")
        _audit_selections(variant, contracts, schema)
        writes.extend([variant["expected_state"], variant["expected_resume_state"]])
        if schema in OBSERVATION_SCHEMAS and "reentry" in variant:
            observed_reentry = variant["reentry"]
            _reentry_record(records[callee["entry"]], observed_reentry["outcome"], schema)
            writes.append(observed_reentry["expected_state"])
            reentries.append(observed_reentry)
    writes.extend(_audit_bypasses(route, contracts, documents, records, payloads, schema))
    _audit_counts([resume["message_count"], *(item["message_count"] for item in reentries),
                   *(v["message_count"] for v in route["variants"]), *visit_counts])
    return writes


def _audit_entry_state(visit_id: str, entry_state) -> None:
    """Bind EP-11 part 1b's `entry_state`: the cells whose values a visit is
    entered with, distinguishing it from the route's own start - measured
    from the state its `after` pass left. Structural shape only; the
    runtime validator checks the values against the actual `after` pass
    state before the visit's own `seed_writes` apply."""
    if not isinstance(entry_state, list):
        raise ValueError(f"Visit {visit_id} entry_state must be a list of state cells")
    for cell in entry_state:
        if (not isinstance(cell, dict) or set(cell) != {"storage", "bank", "index", "value"}
                or not isinstance(cell["storage"], str) or not cell["storage"]
                or type(cell["bank"]) is not int or cell["bank"] < 0
                or type(cell["index"]) is not int or cell["index"] < 0
                or type(cell["value"]) is not int):
            raise ValueError(f"Visit {visit_id} entry_state cell is malformed")


def _audit_visits(route: dict, documents: dict, records: dict, payloads: dict, schema: str) -> tuple:
    """Bind v13's optional `visits`: further replays of the returning callee
    past the one committed `reentry`, each an exact return record with its
    own seed, nested dispatches and message count.

    Each visit's `after` must name a known pass - the fixed keywords `route`
    (the state the dispatch and caller resume left, what `reentry` itself
    starts from) and `reentry`, or an earlier visit's own `visit_id` - so no
    cycle and no forward reference is possible: a visit's own ID only
    becomes a valid `after` target for the visits declared after it. Every
    dispatch is bound to its exact `script_dispatch` record in the callee,
    naming a source member, and its nested outcome to an exact return record
    in that member. `visits` is refused under every other schema so no
    existing profile can widen its contract by a field alone.

    EP-11 part 1b: every visit also carries `entry_state` (a list of
    `{storage, bank, index, value}` cells), required on every v13 visit
    regardless of schema (visits are already V13-only).
    """
    visits = route.get("visits", [])
    if visits and schema not in VISIT_SCHEMAS:
        raise ValueError("Visits need a V13 route")
    callee_records = records[route["callee"]["entry"]]
    known = set(VISIT_AFTER_KEYWORDS)
    seen_ids = set()
    writes, counts = [], []
    for visit in visits:
        visit_id = visit["visit_id"]
        if visit_id in seen_ids or visit_id in VISIT_AFTER_KEYWORDS:
            raise ValueError(f"Duplicate or reserved visit ID: {visit_id}")
        if visit["after"] not in known:
            raise ValueError(f"Visit {visit_id} names an unknown or forward-referenced after pass")
        _audit_entry_state(visit_id, visit["entry_state"])
        seed_writes = visit["seed_writes"]
        seed_basis = visit["seed_basis"]
        if (seed_basis not in ("none", "tool_seeded")
                or (bool(seed_writes) and seed_basis != "tool_seeded")
                or (not seed_writes and seed_basis != "none")):
            raise ValueError(f"Visit {visit_id} needs a seed_basis consistent with its seed_writes")
        _reentry_record(callee_records, visit["outcome"], schema)
        for dispatch in visit["dispatches"]:
            entry = dispatch["entry"]
            if entry not in documents:
                raise ValueError(f"Visit {visit_id} dispatches to a non-member entry")
            row = callee_records.get(dispatch["offset"])
            if (row is None or row["command_id"] != 15 or row["end_offset"] != dispatch["end"]
                    or row.get("script_target", "").upper() != entry):
                raise ValueError(f"Visit {visit_id} dispatch is not the exact original script_dispatch record")
            _reentry_record(records[entry], dispatch["outcome"], schema)
            counts.append(dispatch["message_count"])
        writes.append(visit["expected_state"])
        if seed_writes:
            writes.append(seed_writes)
        counts.append(visit["message_count"])
        known.add(visit_id)
        seen_ids.add(visit_id)
    return writes, counts


def _audit_loop(resume: dict, out: dict, records: dict, entry: str) -> None:
    """Bind a caller's declared loop: the head is the resume stop, every cycle
    row is an exact typed message wait or shared-routine call of the caller,
    and the period and per-period message count are declared counts. Whether
    the caller actually repeats there is the runtime's claim to check."""
    loop = resume["loop"]
    cycle = loop["cycle"]
    if (type(loop["period"]) is not int or loop["period"] < 1 or loop["period"] != len(cycle)
            or type(loop["period_message_count"]) is not int or loop["period_message_count"] < 0):
        raise ValueError("Loop evidence needs a positive period matching its cycle and a message count")
    head = cycle[0]
    if (head["entry"], head["offset"], head["end"]) != (entry, out["offset"], out["end"]):
        raise ValueError("Loop head is not the declared resume stop")
    for row in cycle:
        if row["entry"] != entry or type(row["offset"]) is not int or row["offset"] not in records:
            raise ValueError("Loop cycle row is not a typed caller record")
        record = records[row["offset"]]
        expected_command = LOOP_ROW_COMMANDS.get(row["status"])
        if (expected_command is None or record["command_id"] != expected_command or record["end_offset"] != row["end"]
                or (row["status"] == "dialogue_boundary" and record.get("system_function") != 19)):
            raise ValueError("Loop cycle row is not an exact message wait or shared-routine call")


def _audit_map_location_contract_identity(contract: dict, documents: dict, records: dict, payloads: dict, label: str) -> None:
    """The part of a map-location contract every caller shares: a source
    member, the exact typed Map.get_location record (command 0x12, literals
    6 and 13), the native module's own result cell and an ordered, in-range
    location list. `label` names the contract's own owner in a failure
    (a route or a v14 hop) without duplicating this body per caller."""
    entry = contract["source_identity"]["entry"] if isinstance(contract.get("source_identity"), dict) else None
    if (contract.get("schema") != MAP_LOCATION_CONTRACT_SCHEMA or entry not in documents
            or contract["source_identity"] != {"archive": "mes.arc", "entry": entry}):
        raise ValueError(f"{label} map-location contract must name a source member under its own schema")
    offset, end = contract["poll_offset"], contract["poll_end"]
    if type(offset) is not int or type(end) is not int or offset not in records[entry]:
        raise ValueError(f"{label} map-location poll is not a typed member record")
    record = records[entry][offset]
    literals = [r["value"]["ast"].get("value") for r in record["operands"][0].get("records", [])
                if r.get("type") == "expression_record"] if record["command_id"] == 0x12 else []
    code = build_container(payloads[entry])["_bytecode"]
    if (record["command_id"] != 0x12 or record["end_offset"] != end or tuple(literals) != MAP_LOCATION_POLL
            or contract["poll_function"] != list(MAP_LOCATION_POLL)
            or hashlib.sha256(code[offset:end]).hexdigest() != contract["record_sha256"]):
        raise ValueError(f"{label} map-location poll is not the exact Map.get_location record")
    if (contract["result_storage"], contract["result_index"], contract["none_value"]) != ("state_u16", 18, 0xFFFF):
        raise ValueError(f"{label} map-location contract must write the native map module's result cell")
    locations = contract["locations"]
    if (not isinstance(locations, list) or not locations
            or any(type(v) is not int or v < 0 or v > 0xFFFE for v in locations)):
        raise ValueError(f"{label} map-location contract needs locations in 0..65534")


def _audit_map_location_contracts(route: dict, documents: dict, records: dict, payloads: dict, schema: str) -> None:
    """Bind a route's map-location contracts: each names a source member, an
    exact typed command-0x12 record whose two literal records are 6 and 13
    (Map.get_location), the cell the native module writes and the ordered
    locations to supply. Whether the walk spends them is the runtime's claim."""
    contracts = route.get("map_location_contracts", [])
    if contracts and schema not in MAP_LOCATION_SCHEMAS:
        raise ValueError("Map-location contracts need a V11 or V12 route")
    if schema in MAP_LOCATION_SCHEMAS and not contracts:
        raise ValueError("A V11 or V12 route declares at least one map-location contract")
    for contract in contracts:
        _audit_map_location_contract_identity(contract, documents, records, payloads, "Route")
        # 0.319.0: the contract names the segmented run that spends it (the
        # prefix for the caller's own arrival, the callee for a map the
        # callee walks into, the resume for a map the caller walks back into)
        # beside the unbroken run; absent, the 0.318.0 reading - the callee.
        spent_by = contract.get("spent_by", ["callee", "whole"])
        allowed = {"prefix", "callee", "whole"} | (set() if schema in REPLACEMENT_SCHEMAS else {"resume"})
        if (not isinstance(spent_by, list) or not spent_by or len(set(spent_by)) != len(spent_by)
                or any(name not in allowed for name in spent_by) or "whole" not in spent_by
                or not ({"prefix", "callee", "resume"} & set(spent_by))):
            raise ValueError("Map-location contract must name the segmented run that spends it and the unbroken run")


def _audit_root_replacement(route: dict, documents: dict, records: dict, payloads: dict,
                            route_schema: str = V6_SCHEMA) -> list:
    """A root handoff has no suspended caller and cannot claim caller resume."""
    guarded = "guard" in route
    expected_qualification = ("root_replacement_observation" if guarded
                              else "unconditional_root_replacement_observation")
    if (route["qualification"] != expected_qualification
            or route["caller_outcome"] not in ROOT_REPLACEMENT_OUTCOMES
            or type(route["callee"]["offset"]) is not int or route["callee"]["offset"] != 0):
        raise ValueError("A root replacement must start at callee offset zero and name its own qualification")
    if "resume" in route or "expected_resume_state" in route:
        raise ValueError("Root replacement cannot claim caller resume")
    if guarded and (type(route["post_guard_expected"]) is not int
                    or route["post_guard_expected"] not in (0, 1)):
        raise ValueError("Post-guard expectation must be integer zero or one")
    if not guarded and "post_guard_expected" in route:
        raise ValueError("An unguarded dispatch cannot claim a post-guard truth")
    _audit_context(route["state_context"], documents)
    contracts = _audit_contracts(route, documents, records, payloads, V6_SCHEMA)
    _audit_map_location_contracts(route, documents, records, payloads, route_schema)
    reentries, writes = [route["reentry"]], []
    for variant in route["variants"]:
        if "expected_resume_state" in variant or "resume" in variant:
            raise ValueError("Root replacement variant cannot claim caller resume")
        if guarded:
            expected = variant.get("post_guard_expected", route["post_guard_expected"])
            if type(expected) is not int or expected not in (0, 1):
                raise ValueError("Post-guard expectation must be integer zero or one")
        elif "post_guard_expected" in variant:
            raise ValueError("An unguarded dispatch cannot claim a post-guard truth")
        _audit_selections(variant, contracts, V6_SCHEMA)
        writes.append(variant["expected_state"])
        if "reentry" in variant:
            reentries.append(variant["reentry"])
    for reentry in reentries:
        _bound_terminal(route["callee"]["entry"], reentry["outcome"], documents, records, payloads)
        writes.append(reentry["expected_state"])
    writes.extend(_audit_bypasses(route, contracts, documents, records, payloads, V6_SCHEMA))
    _audit_counts([*(item["message_count"] for item in reentries),
                   *(variant["message_count"] for variant in route["variants"])])
    return writes


GATE_OPS = {"equal", "not_equal", "greater_than", "less_than", "greater_or_equal", "less_or_equal"}
FLOW_OUTCOME_COMMANDS = {"script_return": 0, "def_selection_boundary": 29,
                         "script_handoff_boundary": 14, "script_dispatch_boundary": 15}


def _bound_flow_outcome(entry: str, outcome: dict, documents: dict, records: dict, payloads: dict) -> None:
    """A v14 hop's own outcome: v6's three terminal statuses (return, routine-40
    selection, handoff) plus a fourth, `script_dispatch_boundary` (command 15,
    the same record the existing schemas call `script_dispatch`), for a hop
    that ends by dispatching the flow's next hop rather than returning,
    selecting or handing off."""
    if any(type(outcome[key]) is not int or outcome[key] < 0 for key in ("offset", "end")):
        raise ValueError("Hop outcome coordinates must be nonnegative integers")
    row = _bound_record(entry, outcome, documents, records, payloads, allow_typed=True)
    status = outcome["status"]
    command = FLOW_OUTCOME_COMMANDS.get(status)
    valid = (command is not None and row["command_id"] == command
             and (status not in ("script_handoff_boundary", "script_dispatch_boundary")
                  or (isinstance(outcome.get("target"), str) and bool(outcome["target"])
                      and row.get("script_target", "").upper() == outcome["target"]))
             and (status != "def_selection_boundary" or _selector(row) == 40))
    if not valid or row["op"] != outcome["op"]:
        raise ValueError("Hop outcome is not the declared exact return, selection, handoff or dispatch")


def _audit_flow_hop_transition(hop: dict, prev: dict, hops: list, prev_index: int, records: dict) -> None:
    """Bind hop n's `entered_by`: always the exact record naming this hop,
    found in the hop before it. A nested-call or root-handoff hop's record is
    hop n-1's own dispatch/handoff outcome; a resume hop's record is hop n-1's
    own return outcome - the archive has no separate "resume" record, so v14
    names the return record as the resume's own identity - and the resuming
    hop's own entry must be the script that made the nested call hop n-1
    answered (hop n-2's entry): a resume can only follow the hop it resumes
    into."""
    entered_by, outcome = hop["entered_by"], prev["expected"]["outcome"]
    kind = entered_by.get("kind")
    if kind in ("nested_call", "root_handoff"):
        expected_status = "script_dispatch_boundary" if kind == "nested_call" else "script_handoff_boundary"
        if outcome["status"] != expected_status or outcome.get("target", "").upper() != hop["entry"]:
            raise ValueError(f"Hop {hop['hop_id']} entered_by does not match hop {prev['hop_id']}'s own dispatch")
    elif kind == "resume":
        if prev_index < 1 or prev["entered_by"].get("kind") != "nested_call":
            raise ValueError(f"Hop {hop['hop_id']} can only resume immediately after a nested call")
        if hops[prev_index - 1]["entry"] != hop["entry"]:
            raise ValueError(f"Hop {hop['hop_id']} must resume in the script that made the nested call")
        if outcome["status"] != "script_return":
            raise ValueError(f"Hop {hop['hop_id']} can only resume from a hop that returned")
    else:
        raise ValueError(f"Hop {hop['hop_id']} names an unsupported entered_by kind")
    if any(entered_by.get(key) != outcome.get(key) for key in ("offset", "end", "op", "record_sha256", "source_binding")):
        raise ValueError(f"Hop {hop['hop_id']} entered_by is not hop {prev['hop_id']}'s own outcome record")
    row = records[prev["entry"]][entered_by["offset"]]
    if row["command_id"] != FLOW_OUTCOME_COMMANDS[outcome["status"]] or row["end_offset"] != entered_by["end"]:
        raise ValueError(f"Hop {hop['hop_id']} entered_by is not the exact original record")


def _audit_flow_answer(label: str, entry: str, answer: dict, contracts: dict, seen: set) -> None:
    """One routine-40 answer of a flow (a hop's own, or a variant's override of
    a hop's), bound against the route's shared choice_contracts under the hop's
    own entry. `label` names the failing hop or variant; an answer naming a
    boundary the contracts do not have, a repeat of one already seen, or a
    value outside the contract cannot be built."""
    key = (entry, answer["boundary_offset"])
    if key in seen or key not in contracts:
        raise ValueError(f"{label} answers an undeclared or duplicate choice")
    if type(answer["result_value"]) is not int or answer["result_value"] not in contracts[key]["result_values"]:
        raise ValueError(f"{label} answer is outside its own choice contract")
    seen.add(key)


def _audit_flow_answers(hop: dict, contracts: dict) -> None:
    """A hop's own routine-40 answers: `{boundary_offset, result_value}`, the
    hop's own entry standing in for the owner v6/v13 name explicitly, bound
    against the route's shared choice_contracts. An answer naming a boundary
    the contracts do not have, or a value outside it, cannot be built."""
    seen: set = set()
    for answer in hop.get("answers", []):
        _audit_flow_answer(f"Hop {hop['hop_id']}", hop["entry"], answer, contracts, seen)


def _audit_flow_variant(variant: dict, hops_by_id: dict, contracts: dict) -> None:
    """A variant's optional `answers` and `message_counts` (EP-12, 2026-10-04,
    tool decision, additive to v14): `answers` is a list of `{hop_id,
    boundary_offset, result_value}`, each replacing the named hop's own answer
    at that boundary for this variant (or supplying it when the hop declares
    none), bound to the route's `choice_contracts` exactly as a hop's own
    answers are, under the named hop's entry; `message_counts` maps a declared
    hop id to the message count this variant plays there instead of the hop's
    own `expected.message_count`. Absent fields change nothing."""
    variant_id = variant["variant_id"]
    answers = variant.get("answers", [])
    if not isinstance(answers, list):
        raise ValueError(f"Variant {variant_id} answers must be a list")
    seen: set = set()
    for answer in answers:
        if (not isinstance(answer, dict) or not isinstance(answer.get("hop_id"), str)
                or type(answer.get("boundary_offset")) is not int or type(answer.get("result_value")) is not int):
            raise ValueError(f"Variant {variant_id} answer is malformed")
        hop = hops_by_id.get(answer["hop_id"])
        if hop is None:
            raise ValueError(f"Variant {variant_id} answers an undeclared hop")
        _audit_flow_answer(f"Variant {variant_id}", hop["entry"], answer, contracts, seen)
    counts = variant.get("message_counts", {})
    if not isinstance(counts, dict):
        raise ValueError(f"Variant {variant_id} message counts must be an object")
    if any(hop_id not in hops_by_id for hop_id in counts):
        raise ValueError(f"Variant {variant_id} counts messages of an undeclared hop")
    _audit_counts(list(counts.values()))


DEFAULT_SEGMENT_BUDGET = 512
MAX_SEGMENT_BUDGET = 4096


def _audit_flow_segment_budget(hop_id: str, hop: dict) -> None:
    """A hop's optional `segment_budget` (EP-12 H, 2026-10-04, tool decision,
    additive to v14): the number of segments the route probe may spend in one
    script frame while running this hop, instead of its default 512. It is a
    limit the tool needs (a recollection ladder plays up to 911 messages, one
    segment each), not a measurement - `expected.message_count` records what
    the hop plays. Absent changes nothing; present it must be an integer (not a
    bool, not a string) above the default and no larger than 4096."""
    if "segment_budget" not in hop:
        return
    budget = hop["segment_budget"]
    if type(budget) is not int or not DEFAULT_SEGMENT_BUDGET < budget <= MAX_SEGMENT_BUDGET:
        raise ValueError(
            f"Hop {hop_id} segment_budget must be an integer above {DEFAULT_SEGMENT_BUDGET} and at most {MAX_SEGMENT_BUDGET}")


def _audit_flow_gates(hop_id: str, gates: list, earlier_hop_ids: set) -> None:
    """A hop's own plain-state gates: shape and `basis` only - the audit does
    not re-derive whether the condition holds, which is the validator's own
    claim against the live carried state."""
    for gate in gates:
        if (gate.get("op") not in GATE_OPS or gate.get("storage") not in ("global_u8", "state_u16", "banked_u16")
                or type(gate.get("bank")) is not int or gate["bank"] != 0
                or type(gate.get("index")) is not int or not 0 <= gate["index"] <= 65535
                or type(gate.get("value")) is not int):
            raise ValueError(f"Hop {hop_id} gate is malformed")
        basis = gate.get("basis")
        if basis in ("baseline", "tool_seeded"):
            continue
        if not isinstance(basis, str) or not basis.startswith("written_by:") \
                or basis[len("written_by:"):] not in earlier_hop_ids:
            raise ValueError(f"Hop {hop_id} gate basis names an unknown or later hop")


POLL_SUPPLY_STORAGES = ("global_u8", "state_u16", "banked_u16")


def _audit_flow_poll_supplies(hop_id: str, supplies: list, documents: dict, records: dict) -> None:
    """A hop's own `poll_supplies` (EP-12, 2026-09-24, tool decision,
    additive to v14): before running a named registered definition for this
    hop, the probe writes `value` into `result_storage[result_index]` -
    the same seam `map_locations` uses for a command-0x12 `Util(6,13)` poll,
    generalised only as far as a registered definition's own wait loop needs
    (definition 17's `state_u16[18]` poll into `A_DATE5.MES`,
    docs/spec/mes/a_date_flow.md). The audit binds the poll record exactly -
    a `branch_if_not_true` in `entry` whose own condition reads
    `result_storage[result_index] == value` - and the named definition's own
    registration (a `bootstrap_transfer` selector equal to `definition` whose
    own body covers `poll_offset`); it does not claim the definition ever
    reaches that poll in a real pass, which is the validator's own claim."""
    for supply in supplies:
        entry = supply.get("entry")
        if entry not in documents:
            raise ValueError(f"Hop {hop_id} poll supply must name a declared source member")
        if supply.get("result_storage") not in POLL_SUPPLY_STORAGES:
            raise ValueError(f"Hop {hop_id} poll supply names an unsupported storage")
        offset = supply.get("poll_offset")
        if type(offset) is not int or offset < 0 or offset not in records[entry]:
            raise ValueError(f"Hop {hop_id} poll supply is not a typed member record")
        row = records[entry][offset]
        if row["op"] != "branch_if_not_true" or row["command_id"] != 0x0B:
            raise ValueError(f"Hop {hop_id} poll supply is not a branch_if_not_true record")
        condition = row["operands"][0]["value"]["ast"]
        lhs = condition.get("lhs", {}) if condition.get("type") == "binary" else {}
        rhs = condition.get("rhs", {}) if condition.get("type") == "binary" else {}
        if (condition.get("op") != "equal" or lhs.get("type") != "state_ref"
                or lhs.get("storage") != supply.get("result_storage") or int(lhs.get("bank", -1)) != 0
                or int(lhs.get("index", {}).get("value", -1)) != int(supply.get("result_index", -1))
                or rhs.get("type") != "literal" or int(rhs.get("value", -1)) != int(supply.get("value", -1))):
            raise ValueError(f"Hop {hop_id} poll supply does not match its own branch condition")
        definition_id = supply.get("definition")
        bound = False
        for candidate in records[entry].values():
            if candidate["op"] != "bootstrap_transfer" or candidate["command_id"] != 0x14:
                continue
            selector_ast = candidate["operands"][0]["value"]["ast"]
            if selector_ast.get("type") != "literal" or int(selector_ast.get("value", -1)) != int(definition_id):
                continue
            body_offset, skip_target = int(candidate["end_offset"]), int(candidate["operands"][1]["value"])
            if body_offset <= offset < skip_target:
                bound = True
                break
        if not bound:
            raise ValueError(f"Hop {hop_id} poll supply's definition is not registered over its own poll offset")


def _audit_flow_route(route: dict, documents: dict, records: dict, payloads: dict) -> None:
    """Bind a v14 flow: an origin guard, an ordered hop chain (each hop's
    entered_by the exact dispatch or return record naming it, in the hop
    before it), per-hop answers and gates, and a terminal equal to the last
    hop's own outcome. See docs/spec/tech/content_tools.md's v14 entry.

    `state_context` (EP-12 part 3, 2026-09-24, additive to v14) is the same
    object v8/v6 routes carry, audited by the shared `_audit_context`: it is
    applied by the runtime validator to the guard witness and every variant's
    run state before `baseline` and the variant's own writes. Unlike v8/v6,
    where it is mandatory, a v14 route may omit it entirely (a profile that
    predates this field, such as the synthetic GDScript fixture
    `tests/test_event_analysis_group_flow.gd` carries, defaults to
    `{"kind": "fresh"}` exactly as the runtime validator's own default does).

    A variant may also carry `answers` and `message_counts` (EP-12,
    2026-10-04, additive to v14; `_audit_flow_variant`): its own routine-40
    answers and per-hop message counts, so a question's other options and a
    recap scene's second path can be variants of one route. A variant whose
    run ends at a different record than `terminal` is not expressible: each
    hop's declared outcome is still asserted for every variant.
    """
    _audit_context(route.get("state_context", {"kind": "fresh"}), documents)
    origin = route["origin"]
    entry = origin["entry"]
    if entry not in documents:
        raise ValueError("Flow origin must name a declared source member")
    guard = origin["guard"]
    if (type(origin["offset"]) is not int or origin["offset"] < 0 or origin["offset"] not in records[entry]
            or any(type(guard[k]) is not int or guard[k] < 0 for k in ("offset", "end"))
            or not origin["offset"] <= guard["offset"]):
        raise ValueError("Flow origin must precede its own guard")
    hops = route["hops"]
    if not hops:
        raise ValueError("A flow needs at least one hop")
    if hops[0]["entry"] != entry or hops[0]["entered_by"] != {"kind": "origin"}:
        raise ValueError("The flow's first hop must run in the origin's own script, entered by its own origin")
    branch = _bound_record(entry, guard, documents, records, payloads, allow_typed=True)
    first_outcome = hops[0]["expected"]["outcome"]
    code = build_container(payloads[entry])["_bytecode"]
    if (branch["op"] != "branch_if_not_true" or branch["end_offset"] != guard["end"]
            or branch["operands"][1]["value"] != guard["false_target"]
            or not guard["offset"] < first_outcome["offset"]
            or hashlib.sha256(code[origin["offset"]:first_outcome["end"]]).hexdigest() != guard["prefix_sha256"]):
        raise ValueError("Exact flow guard or origin prefix differs")
    cases = origin["guard_cases"]
    if (not cases or len({c["case_id"] for c in cases}) != len(cases)
            or {c["expected"] for c in cases} != {0, 1}
            or any(type(c["expected"]) is not int for c in cases)):
        raise ValueError("Flow guard needs both acceptance and rejection witnesses")
    contracts = _audit_contracts(route, documents, records, payloads, V6_SCHEMA)
    seen_ids: set = set()
    writes = [route["baseline"], *(case["writes"] for case in cases)]
    for index, hop in enumerate(hops):
        hop_id = hop["hop_id"]
        if hop_id in seen_ids:
            raise ValueError("Duplicate hop ID")
        if hop["entry"] not in documents:
            raise ValueError(f"Hop {hop_id} must run in a declared source member")
        if index > 0:
            _audit_flow_hop_transition(hop, hops[index - 1], hops, index - 1, records)
        _audit_flow_answers(hop, contracts)
        _audit_flow_gates(hop_id, hop.get("gates", []), set(seen_ids))
        seen_ids.add(hop_id)
        for contract in hop.get("map_locations", []):
            _audit_map_location_contract_identity(contract, documents, records, payloads, f"Hop {hop_id}")
        _audit_flow_poll_supplies(hop_id, hop.get("poll_supplies", []), documents, records)
        _audit_flow_segment_budget(hop_id, hop)
        expected = hop["expected"]
        if type(expected["message_count"]) is not int or expected["message_count"] < 0:
            raise ValueError(f"Hop {hop_id} needs a nonnegative message count")
        _bound_flow_outcome(hop["entry"], expected["outcome"], documents, records, payloads)
        writes.append(expected["expected_state"])
    last_outcome = hops[-1]["expected"]["outcome"]
    if route["terminal"] != {"entry": hops[-1]["entry"], **last_outcome}:
        raise ValueError("Flow terminal must be exactly the last hop's own outcome")
    variant_ids = [variant["variant_id"] for variant in route["variants"]]
    if not route["variants"] or len(set(variant_ids)) != len(variant_ids):
        raise ValueError("Missing or duplicate flow variants")
    hops_by_id = {hop["hop_id"]: hop for hop in hops}
    for variant in route["variants"]:
        _audit_flow_variant(variant, hops_by_id, contracts)
        writes.extend([variant["writes"], variant["expected_state"]])
    _audit_write_groups(writes)


def audit(arc: Path, profile: dict, *, handoff_cache: dict | None = None,
          archive_cache: dict | None = None) -> dict:
    """Audit one profile against the original archive.

    `handoff_cache` (keyed by `(archive_sha, entry name)`) and `archive_cache`
    (keyed by arc path) let a caller amortize `read_entries`/`build_handoff`
    across many profiles that share source members within one process
    (TD-32 part 2b); each member's `entry_sha256` is still checked against
    the payload for every profile regardless of caching. Keying the handoff
    cache by archive fingerprint as well as entry name means two archives
    that happen to share an entry name never share a cached handoff (TD-32
    part 2c). Neither cache changes the returned report, which stays
    byte-identical to the uncached call.
    """
    if profile.get("schema") not in (SCHEMA, V2_SCHEMA, *OBSERVATION_SCHEMAS, V14_SCHEMA) or fingerprint(profile) != profile.get("payload_sha256"):
        raise ValueError("Unsupported or tampered analysis group")
    cache = archive_cache if archive_cache is not None else {}
    cache_key = str(arc)
    cached = cache.get(cache_key)
    if cached is None:
        archive = arc.read_bytes()
        archive_sha = hashlib.sha256(archive).hexdigest()
        payloads = {name: archive[offset:offset + size] for name, offset, size in read_entries(arc)}
        cached = cache[cache_key] = (archive, archive_sha, payloads)
    archive, archive_sha, payloads = cached
    if archive_sha != profile["archive_sha256"]:
        raise ValueError("Original archive identity differs")
    documents, records = {}, {}
    for member in profile["source_members"]:
        name = member["entry"]
        if name in documents or hashlib.sha256(payloads[name]).hexdigest() != member["entry_sha256"]:
            raise ValueError("Duplicate or changed source member")
        handoff_key = (archive_sha, name)
        if handoff_cache is not None and handoff_key in handoff_cache:
            documents[name] = handoff_cache[handoff_key]
        else:
            documents[name] = build_handoff(payloads[name], {"archive": "mes.arc", "entry": name,
                "source_kind": "original_arc", "archive_sha256": archive_sha})
            if handoff_cache is not None:
                handoff_cache[handoff_key] = documents[name]
        records[name] = {r["source_offset"]: r for r in documents[name]["typed_ir"]["instructions"]}
    if not profile["routes"]:
        raise ValueError("Analysis group has no routes")
    seen, windows = set(), {}
    for route in profile["routes"]:
        if route["route_id"] in seen:
            raise ValueError("Duplicate route ID")
        seen.add(route["route_id"])
        if profile["schema"] == V14_SCHEMA:
            _audit_flow_route(route, documents, records, payloads)
            continue
        unguarded = profile["schema"] in (V7_SCHEMA, V9_SCHEMA)
        caller, callee, outcome = (route[k] for k in ("caller", "callee", "outcome"))
        guard = route["guard"] if not unguarded else {}
        if unguarded and ("guard" in route or "post_guard_expected" in route):
            raise ValueError("An unguarded route must not declare a local guard or post-guard truth")
        prefix_start = guard["offset"] if not unguarded else route.get("origin_offset")
        if profile["schema"] in ANCHORED_SCHEMAS:
            prefix_start = route["origin_offset"]
            if (type(prefix_start) is not int or prefix_start < 0
                    or prefix_start not in records[caller["entry"]]
                    or any(type(caller[key]) is not int or caller[key] < 0 for key in ("offset", "end"))
                    or not (prefix_start < caller["offset"] if unguarded
                            else prefix_start <= guard["offset"] < caller["offset"])):
                raise ValueError("Caller origin must be a typed record preceding the guard and dispatch")
            intro = _bound_record(caller["entry"], caller, documents, records, payloads, allow_typed=True)
        else:
            intro = records[caller["entry"]][caller["offset"]]
        branch = {}
        if profile["schema"] in (V5_SCHEMA, V6_SCHEMA, V8_SCHEMA, V10_SCHEMA, V11_SCHEMA, V12_SCHEMA, V13_SCHEMA):
            if any(type(guard[key]) is not int or guard[key] < 0 for key in ("offset", "end")):
                raise ValueError("Guard observation coordinates must be nonnegative integers")
            branch = _bound_record(caller["entry"], guard, documents, records, payloads, allow_typed=True)
        elif not unguarded:
            branch = records[caller["entry"]][guard["offset"]]
        root_replacement = profile["schema"] in REPLACEMENT_SCHEMAS
        if root_replacement:
            _bound_terminal(callee["entry"], outcome, documents, records, payloads)
        else:
            terminal = records[callee["entry"]][outcome["offset"]]
        code = build_container(payloads[caller["entry"]])["_bytecode"]
        expected_command = (ROOT_REPLACEMENT_COMMANDS.get(route["caller_outcome"].get("kind"), 14)
                            if root_replacement else 15)
        if (intro["command_id"] != caller["command"] or caller["command"] != expected_command
                or intro["end_offset"] != caller["end"] or intro.get("script_target", "").upper() != callee["entry"]):
            raise ValueError("Exact intro record differs")
        if unguarded:
            windows[route["route_id"]] = _audit_unconditional_dispatch(
                route, documents[caller["entry"]], records[caller["entry"]], code)
        elif (branch["op"] != "branch_if_not_true" or branch["end_offset"] != guard["end"]
                or branch["operands"][1]["value"] != guard["false_target"]
                or not guard["offset"] < caller["offset"]
                or hashlib.sha256(code[prefix_start:caller["end"]]).hexdigest() != guard["prefix_sha256"]):
            raise ValueError("Exact guard or caller prefix differs")
        if not root_replacement and (callee["offset"] not in records[callee["entry"]] or terminal["op"] != outcome["op"]
                or terminal["end_offset"] != outcome["end"]):
            raise ValueError("Callee start or outcome is not the declared exact record")
        if not root_replacement and not ((outcome["status"] == "script_return" and terminal["command_id"] == 0)
                or (outcome["status"] == "def_selection_boundary" and terminal["command_id"] == 29 and _selector(terminal) == 40)):
            raise ValueError("Unsupported outcome claim for this instruction")
        caller_outcome = route["caller_outcome"]
        if root_replacement:
            if callee["offset"] not in records[callee["entry"]]:
                raise ValueError("Callee start is not an exact typed record")
        elif caller_outcome["kind"] == "blocked_definition":
            if (caller_outcome["offset"] not in records[caller_outcome["entry"]]
                    or caller_outcome["status"] != "definition_step_limit"
                    or type(caller_outcome["definition_id"]) is not int):
                raise ValueError("Unqualified definition boundary")
        elif caller_outcome["kind"] != "dispatch":
            raise ValueError("Unsupported caller outcome")
        case_key = "selection_cases" if unguarded else "guard_cases"
        for key, id_key in ((case_key, "case_id"), ("variants", "variant_id")):
            rows = route[key]
            if not rows or len({row[id_key] for row in rows}) != len(rows):
                raise ValueError("Missing or duplicate analysis cases")
        if unguarded:
            # There is no local condition to accept or reject. Each case is a
            # selector witness that must still reach the same dispatch.
            if any("expected" in case for case in route[case_key]):
                raise ValueError("An unguarded route cannot claim guard truth witnesses")
        elif ({case["expected"] for case in route["guard_cases"]} != {0, 1}
                or any(type(case["expected"]) is not int for case in route["guard_cases"])):
            raise ValueError("Guard needs both acceptance and rejection witnesses")
        writes = [route["baseline"], route["expected_state"],
                  *(case["writes"] for case in route[case_key]), *(case["writes"] for case in route["variants"])]
        if root_replacement:
            writes.extend(_audit_root_replacement(route, documents, records, payloads, profile["schema"]))
        elif profile["schema"] in (V2_SCHEMA, *OBSERVATION_SCHEMAS):
            writes.extend(_audit_continuation(route, documents, records, payloads, profile["schema"]))
        _audit_write_groups(writes)
    if hashlib.sha256(arc.read_bytes()).hexdigest() != archive_sha:
        raise ValueError("Original archive changed during audit")
    report = {"ok": True, "schema": AUDIT_SCHEMA, "profile": profile,
        "qualification": "exact_source_records_only_runtime_witnesses_pending",
        "handoffs": {name: {"producer": doc["producer"]["implementation"], "payload_sha256": doc["payload_sha256"],
            "branches": [{"offset": r["source_offset"], "end": r["end_offset"], "false_target": r["operands"][1]["value"]}
                         for r in doc["typed_ir"]["instructions"] if r["op"] == "branch_if_not_true"]}
                     for name, doc in documents.items()}}
    if profile["schema"] == V2_SCHEMA:
        report["schema"] = "kakyu_event_analysis_group_source_audit/v2"
        report["qualification"] = "typed_source_records_and_opaque_observation_bytes_runtime_witnesses_pending"
    elif profile["schema"] in OBSERVATION_SCHEMAS:
        report["schema"] = "kakyu_event_analysis_group_source_audit/" + profile["schema"].rsplit("/", 1)[1]
        report["qualification"] = "typed_source_records_or_opaque_observation_bytes_runtime_witnesses_pending_no_completion_claim"
    elif profile["schema"] == V14_SCHEMA:
        report["schema"] = "kakyu_event_analysis_group_source_audit/v14"
        report["qualification"] = "typed_source_flow_records_only_runtime_witnesses_pending_no_completion_claim"
    if windows:
        report["unconditional_dispatch_windows"] = windows
    report["payload_sha256"] = fingerprint(report)
    return report


def _audit_multi(elfimage: Path, raw_paths: list) -> int:
    """Audit each named profile in this one process with shared caches.

    Prints one JSON line per profile, `{"profile": <path as given>, "report":
    <report or {"ok": false, "error": ...}>}`, in order; a profile that
    cannot be read or parsed is a failure line, not a crash.
    """
    handoff_cache: dict = {}
    archive_cache: dict = {}
    arc = elfimage / "mes.arc"
    ok = True
    for raw in raw_paths:
        try:
            profile = json.loads(Path(raw).read_text(encoding="utf-8"))
            report = audit(arc, profile, handoff_cache=handoff_cache, archive_cache=archive_cache)
        except (ValueError, KeyError, TypeError, OSError) as error:
            report = {"ok": False, "error": str(error)}
        ok = ok and bool(report.get("ok", False))
        print(json.dumps({"profile": raw, "report": report}, ensure_ascii=False, separators=(",", ":")))
    return 0 if ok else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elfimage", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--profile", type=Path, default=None)
    mode.add_argument("--profiles", nargs="+")
    mode.add_argument("--profiles-file", type=Path)
    args = parser.parse_args()

    if args.profiles is not None:
        return _audit_multi(args.elfimage, args.profiles)
    if args.profiles_file is not None:
        raw_paths = [line.strip() for line in
                     args.profiles_file.read_text(encoding="utf-8").splitlines() if line.strip()]
        return _audit_multi(args.elfimage, raw_paths)

    profile_path = args.profile if args.profile is not None else DEFAULT_PROFILE
    try:
        report = audit(args.elfimage / "mes.arc", json.loads(profile_path.read_text(encoding="utf-8")))
        print(json.dumps(report, ensure_ascii=False, separators=(",", ":")))
        return 0
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
