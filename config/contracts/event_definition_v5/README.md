# `kakyu_event_definition/v5` conformance fixture set

This directory is the WD-23 conformance fixture set for the
`kakyu_event_definition/v5` document shape described in
`docs/spec/data/event_definition_v5.md` (the contract; v5 is v4 plus one
optional top-level `visits` field - see the base shape in
`docs/spec/data/event_definition_v4_design.md`). It is built the same way
`config/contracts/event_definition_v4/` was: a fixture set with a
`contract_fingerprint`, a validator that accepts every valid fixture and
rejects every invalid one for the recorded reason, computed by
`tools/contract_fingerprint.py`. It does not replace v4: `event_definition_v4/`
stays byte-identical, unedited by this unit.

- `valid/` holds v4's own six re-versioned fixtures (`plain_event.json`,
  `choice_event.json`, `caller_question_skip.json`, `map_arrival_train.json`,
  `catalog_event.json`, `package_resolved.json` - none of them carry
  `visits`, exercising "a document without visits") plus
  `visit_chain_event.json`: a document-level `visits` chain of two visits
  (`v1` `follows: "first"`, `v2` `follows: "v1"`), `v1`'s `select` a plain
  counter-cell equality row, `v2`'s `select` the same plus a compound
  `mes_expression` gate condition (`or` of one `cell` leaf, the seed_writes
  cell's own branch condition), one `add_legacy_value` effect, and `v2`
  carrying `repeats: true` (the fixed point). It is package-bound like
  `package_resolved.json` (reuses its `CALLEE` package records at offsets
  10/20) so a visit's own dialogue resolves against `package/` too.
- `invalid/` holds every v4 invalid fixture re-versioned to v5 (same reason
  codes, `event_definition_v4/README.md`'s own list) plus one new fixture
  per v5-only failure, each a mutation of `visit_chain_event.json`:
  - `visit_unknown_follows.json` - `v2.follows` names neither `"reentry"`,
    `"first"`, nor an earlier `visit_id` (`bad_visit_follows`).
  - `visit_forward_reference.json` - `v1.follows` names `v2`, declared later
    in the same list; the same rule that rejects an unknown `follows`
    rejects a forward reference or a cycle, since every `follows` must name
    an already-declared earlier visit (`bad_visit_follows`).
  - `visit_duplicate_id.json` - both visits carry `visit_id: "v1"`
    (`duplicate_visit_id`).
  - `visit_empty_select.json` - `v1.select` is `[]` (`empty_visit_select`).
  - `visit_bad_select.json` - `v1.select` carries `{"foo": "bar"}`, neither
    the plain equality shape nor `mes_expression` (`bad_visit_select`).
  - `visit_duplicate_repeats.json` - both visits carry `repeats: true`
    (`duplicate_visit_repeats`).
  - `visit_second_scene_end.json` - `v1.dialogue` carries two `scene_end`
    entries, not exactly one (`bad_visit_scene_end`).
  - `visit_clock_effect.json` - `v1.after` carries an `add_legacy_value` row
    on `state_u16[19]` (a clock cell): every v4 dialogue/effect rule applies
    inside a visit unchanged, so this reuses v4's own `clock_cell_effect`
    reason, not a new one.
  `expected.json` maps every relative path under `valid/` and `invalid/` to
  `{"ok": bool, "reason": code}`.
- `package/` is v4's own minimal, invented `kakyu_playback_package/v7`
  package, copied unchanged; `visit_chain_event.json` is the only v5-only
  fixture that binds it (reusing `CALLEE`'s existing offsets 10/20, already
  present in v4's copy - no new record was needed).

Fixtures here are hand-written and carry no original dialogue text, no
machine paths and no original data beyond synthetic coordinates and
synthetic 64-hex-character hashes, exactly as in v4's own set.

## Fingerprint

`contract_fingerprint` is the SHA-256 over the concatenation of
`"<relative path>\t<sha256 of the file bytes>\n"` for every file under this
directory except `contract_fingerprint` itself, paths relative to this
directory with `/` separators, sorted, LF line endings - computed by
`tools/contract_fingerprint.py`. A later revision is a new directory beside
this one, never an edit of `v5` in place, following the same rule v4
follows for a revision beyond it.

## The `"self"` convention

As in v3/v4: every hand-written fixture's own `contract_fingerprint` and
`names_fingerprint` are the literal string `"self"`, accepted by
`tools/validate_event_definition.py` as equal to the value passed with
`--fingerprint`/`--names`. The `invalid/` fixtures that exercise the
fingerprint and names rules do not use `"self"`.

## See also

`docs/spec/data/event_definition_v5.md` is the contract this set implements
(status frozen 2026-09-23 by the owner's rulings of the day); it is not
edited by this unit beyond its own authoring.
