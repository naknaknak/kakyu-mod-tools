# `kakyu_event_definition/v6` conformance fixture set

This directory is the conformance fixture set for the
`kakyu_event_definition/v6` document shape described in
`docs/spec/data/event_definition_v6.md` (the contract; v6 is v5 plus an
optional top-level `flow` block - see the base shape in
`docs/spec/data/event_definition_v4_design.md` and the `visits` addition in
`docs/spec/data/event_definition_v5.md`). It is built the same way
`config/contracts/event_definition_v5/` was: a fixture set with a
`contract_fingerprint`, a validator that accepts every valid fixture and
rejects every invalid one for the recorded reason, computed by
`tools/contract_fingerprint.py`. It does not replace v5: `event_definition_v5/`
stays byte-identical, unedited by this unit. This unit lands the contract
only (design document, fixture set, validator, tests); the producer and the
145 tracked v6 documents are unit 2, a later spec.

- `valid/` holds v5's own seven fixtures re-versioned (schema and
  `contract_fingerprint` only; `plain_event.json`, `choice_event.json`,
  `caller_question_skip.json`, `map_arrival_train.json`, `catalog_event.json`,
  `package_resolved.json`, `visit_chain_event.json` - none of them carry
  `flow`, exercising "a document without flow") plus `flow_event.json`: a
  document-level `flow` block with three hops -
  - `h1_origin` - `entered_by.kind: "origin"`, runs in `CALLER`, no lines.
  - `h2_callee` - `entered_by.kind: "nested_call"`, runs in `CALLEE`, two
    package-bound lines reusing `package/`'s existing `CALLEE` records at
    offsets 10 and 20 (the same records `package_resolved.json` and
    `visit_chain_event.json` already bind), one `add_legacy_value` effect
    row on a `global_u8` counter cell, `message_count: 2`.
  - `h3_resume` - `entered_by.kind: "resume"`, back in `CALLER`, one answer,
    one `tool_seeded` gate, one `written_by` gate naming `h2_callee`, one
    `map_locations` row, one `poll_supplies` row.

  `flow.state_context` is `{"kind": "original_calendar", "entry":
  "START.MES", "table_sha256": <synthetic 64-hex>}`; `flow.terminal` names
  the document's own `natural_handoff` terminal, which
  `results.result_default.terminal` also names. The top-level `dialogue` is
  exactly the three hop markers (`{"kind": "hop", "hop_id": ...}`) in order,
  each followed by that hop's own dialogue entries verbatim, then one
  trailing `{"kind": "scene_end"}`. The top-level `after` names the same
  `global_u8` cell `h2_callee`'s own `after` does (the net effect over the
  whole run equals that hop's own contribution here, since no other hop
  touches the cell) - exercising "a hop's `after` rows and the top-level
  rows may both name a cell" without the two lists' own one-row-per-cell
  rules ever colliding across levels. It is package-bound like
  `package_resolved.json` and `visit_chain_event.json` (reuses the same
  `CALLER`/`CALLEE` package records and hashes) so a hop's own dialogue
  resolves against `package/` too.
- `invalid/` holds every v5 invalid fixture re-versioned to v6 (same reason
  codes, `event_definition_v5/README.md`'s own list) plus one new fixture
  per v6-only failure, each a mutation of `flow_event.json`:
  - `flow_flow_with_visits.json` - carries a non-empty `visits` alongside
    `flow` (`flow_with_visits`).
  - `flow_flow_without_hops.json` - `flow.hops` is `[]` (`flow_without_hops`).
  - `flow_duplicate_hop_id.json` - `h3_resume`'s own `hop_id` is rewritten to
    `h1_origin`, already used (`duplicate_hop_id`).
  - `flow_bad_hop_entered_by.json` - the first hop's `entered_by.kind` is
    `"resume"` instead of `"origin"` (`bad_hop_entered_by`).
  - `flow_bad_hop_answer.json` - `h3_resume`'s own answer carries a string
    `result_value` (`bad_hop_answer`).
  - `flow_bad_gate_basis.json` - the `written_by` gate on `h3_resume` names
    `h3_resume` itself (a later/unknown hop from its own perspective, since
    only a strictly earlier hop_id is accepted) instead of `h2_callee`
    (`bad_gate_basis`).
  - `flow_bad_map_location.json` - the `map_locations` row on `h3_resume`
    drops `poll_offset` (`bad_map_location`).
  - `flow_bad_poll_supply.json` - the `poll_supplies` row on `h3_resume`
    drops `definition` (`bad_poll_supply`).
  - `flow_hop_scene_end.json` - `h2_callee`'s own dialogue carries a trailing
    `{"kind": "scene_end"}` (`hop_scene_end`).
  - `flow_hop_choice_point.json` - `h2_callee`'s own dialogue carries a
    trailing `{"kind": "choice_point", "choice": "top"}` (`hop_choice_point`).
  - `flow_hop_message_count.json` - `h2_callee`'s own `message_count` is `5`
    against its own two `text` entries (`hop_message_count`).
  - `flow_hop_marker_mismatch.json` - the top-level `dialogue`'s own
    `h2_callee` marker is removed, so the interleaved entries no longer
    match the hop list (`hop_marker_mismatch`; this reason also covers what
    the design draft called out as a `bad_scene_end`-shaped case - a missing
    or misplaced trailing `scene_end` - since v4/v5 name no such reason and
    the underlying rule, the top-level list's own exact interleaving shape,
    is the same check either way).
  - `flow_hop_marker_outside_flow.json` - `flow` is removed entirely and the
    top-level `dialogue` still carries a `{"kind": "hop", ...}` marker
    (`hop_marker_outside_flow`).
  - `flow_bad_flow_terminal.json` - `flow.terminal` names `"term_missing"`,
    absent from the document's own `terminals` (`bad_flow_terminal`).
  - `flow_bad_flow_evidence.json` - `flow.evidence` drops `route`
    (`bad_flow_evidence`).
  - `flow_bad_state_context.json` - `flow.state_context.kind` is `"bogus"`
    (`bad_state_context`).

  `expected.json` maps every relative path under `valid/` and `invalid/` to
  `{"ok": bool, "reason": code}`.
- `package/` is v5's own minimal, invented `kakyu_playback_package/v7`
  package, copied unchanged; `flow_event.json` is the only v6-only fixture
  that binds it, reusing `CALLEE`'s existing offsets 10/20 already present
  in v5's copy - no new record was needed.

Fixtures here are hand-written and carry no original dialogue text, no
machine paths and no original data beyond synthetic coordinates and
synthetic 64-hex-character hashes, exactly as in v5's own set.

## Fingerprint

`contract_fingerprint` is the SHA-256 over the concatenation of
`"<relative path>\t<sha256 of the file bytes>\n"` for every file under this
directory except `contract_fingerprint` itself, paths relative to this
directory with `/` separators, sorted, LF line endings - computed by
`tools/contract_fingerprint.py`. A later revision is a new directory beside
this one, never an edit of `v6` in place, following the same rule v4/v5
follow for a revision beyond them.

## The `"self"` convention

As in v3/v4/v5: every hand-written fixture's own `contract_fingerprint` and
`names_fingerprint` are the literal string `"self"`, accepted by
`tools/validate_event_definition.py` as equal to the value passed with
`--fingerprint`/`--names`. The `invalid/` fixtures that exercise the
fingerprint and names rules do not use `"self"`.

## See also

`docs/spec/data/event_definition_v6.md` is the contract this set implements;
it is not edited by this unit beyond its own authoring.
