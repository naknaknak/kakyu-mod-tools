# `kakyu_event_definition/v4` conformance fixture set

This directory is the event definition v4 unit 2a conformance fixture set
for the `kakyu_event_definition/v4` document shape described in
`docs/spec/data/event_definition_v4_design.md` (the design; v4 is v3 plus
its changes - see the base shape in
`docs/spec/data/event_definition_projection.md`). It is built the same way
`config/contracts/event_definition_v3/` was: a fixture set with a
`contract_fingerprint`, a validator that accepts every valid fixture and
rejects every invalid one for the recorded reason, computed by
`tools/contract_fingerprint.py`. It does not replace v3: v3's own directory,
fingerprint and validator behaviour stay byte-identical, unedited by this
unit. `valid/minatu.town.station.04.1.json`, the real EVENTJ04 projection,
is **not** part of this set - projecting the real sites into
`config/event_definitions/v4/` is unit 2b's work, not this unit's.

- `valid/` holds the five v3 hand-written shapes re-versioned to v4
  (`plain_event.json`, `choice_event.json`, `caller_question_skip.json`,
  `map_arrival_train.json`, `catalog_event.json`) plus
  `package_resolved.json`, a minimal document that resolves every
  `text_ref` against `package/`. Together they exercise every v4 addition:
  `add_legacy_value` and `consume_time` effect rows with `cell_class`,
  `evidence.effect_witnesses` of every `basis`, a `choice_point` and a
  `scene_end` in every shape that has a choice or a played result, one
  `location_line` entry (`plain_event.json`), one `order_hint`
  (`plain_event.json`), and a `done_cell` of each `source`
  (`plain_event.json`: `guard_flag`; `catalog_event.json`:
  `reentry_probe`).
- `invalid/` holds one document per fail-closed rule: every v3 invalid
  fixture, re-versioned to v4, under the same reason code, plus one new
  fixture per v4-only reason (`zero_delta`, `duplicate_effect_cell`,
  `bad_cell_class`, `clock_cell_effect`, `bad_consume_time`,
  `witness_contradicts_effect`, `choice_point_without_choice`,
  `second_scene_end`, `scene_end_in_skipped_result`,
  `location_line_on_marker`, `bad_done_cell_source`, `bad_order_hint`,
  `text_control_character`, `text_not_nfc`, `text_line_break` - the last
  three need `package/`). Two v3 reasons could not be re-versioned with
  their original mutation: v3's `delta_effect.json` and
  `consume_time_effect.json` fixtures tested that an `add_legacy_value` or
  `consume_time` row was rejected outright, and v4 makes both legal types,
  so those two fixtures now trigger the still-applicable `effects` reason a
  different way (`delta_effect.json`: an unrecognized effect `type`;
  `consume_time_effect.json`: two `consume_time` rows in one `after` list,
  which the design's "at most one per list" rule still forbids).
  `expected.json` maps every relative path under `valid/` and `invalid/` to
  `{"ok": bool, "reason": code}`.
- `package/` is a minimal, invented `kakyu_playback_package/v7`-shaped
  package built only for this fixture set's own `package_resolved.json` and
  the three text-encoding invalid fixtures; see `package/README.md`.

Fixtures here are hand-written and carry no original dialogue text, no
machine paths and no original data beyond synthetic coordinates and
synthetic 64-hex-character hashes (`raw_sha256`, `entry_sha256`,
`package_sha256`, `profile_sha256`, `archive_sha256`, `record_sha256`), none
of which are the hash of any real original byte range.

## Fingerprint

`contract_fingerprint` is the SHA-256 over the concatenation of
`"<relative path>\t<sha256 of the file bytes>\n"` for every file under this
directory except `contract_fingerprint` itself, paths relative to this
directory with `/` separators, sorted, LF line endings - computed by
`tools/contract_fingerprint.py`. A later revision is a new directory beside
this one, never an edit of `v4` in place, following the same rule v3
follows for a revision beyond it.

## The `"self"` convention

As in v3: every hand-written fixture's own `contract_fingerprint` and
`names_fingerprint` are the literal string `"self"`, accepted by
`tools/validate_event_definition.py` as equal to the value passed with
`--fingerprint`/`--names` (see `config/contracts/event_definition_v3/README.md`
for the full explanation, which applies unchanged here). The `invalid/`
fixtures that exercise the fingerprint and names rules do not use `"self"`.

## See also

`docs/spec/data/event_definition_v4_design.md` is the design this set
implements; it is not edited by this unit (unit 2b writes the contract
document and the producer).
