# `kakyu_mod_event_definition/v1` conformance fixture set

This directory is the mod event definition unit A conformance fixture set
for the `kakyu_mod_event_definition/v1` document shape described in
`docs/spec/data/mod_event_definition_design.md` (the design and the
owner's rulings at its end) and `docs/spec/data/text_encoding.md` (section
"Authored text"). It is built the same way
`config/contracts/event_definition_v4/` was: a fixture set with a
`contract_fingerprint`, a validator (`tools/validate_mod_event_definition.py`)
that accepts every valid fixture and rejects every invalid one for the
recorded reason, computed by `tools/contract_fingerprint.py`. This contract
is not a projection: a mod document carries no `text_ref`, no
`raw_sha256`, no `package_binding` and no `evidence` - it is a document a
mod writes itself, either a new event (`kind: "new_event"`) or an edit to a
projected `kakyu_event_definition/v4` document (`kind: "override"`).
Nothing here changes `config/contracts/event_definition_v3/`,
`event_definition_v4/`, `state_cells_v1/` or `event_names_v1/`: their
directories, fingerprints and validator behaviour stay byte-identical.

- `valid/` holds six documents: `new_event_plain.json` (one default
  result, a `return_to_map` terminal, a `done` cell observed only as 1 so
  it classifies `flag`, every optional `presentation` key, an
  `order_hint`, `event_not_completed`/`weekday_equals`/`time_at_or_after`
  conditions, a `write_legacy_value` and a `consume_time` effect, one
  `line` entry with `speaker`/`voice`, one `line` entry holding `{name}`
  and a U+000A line break, one `scene_end`); `new_event_choice.json` (a
  top-level `choice` with two options, one result playing with its own
  nested `choice`/`results` two levels deep including a
  `continue_caller` terminal, one result skipped
  (`event_played: false`), a `choice_point` naming `"top"` in the body and
  one naming the played result inside its own dialogue, a `set_flag` and
  an `add_legacy_value` with `min`/`max` on ryoko's affection cell
  (`banked_u16[204]`), `flag_equals` and `date_in_range` conditions);
  `new_event_conditional_results.json` (no choice; two `condition`-selected
  results - a `legacy_cell` row on ryoko's affection cell and a
  `mes_expression` row - plus one `default` result; `date_equals`,
  `time_before` and an `event_completed` condition naming a real registry
  id); `override_conditions.json` (`replace_conditions` with an
  `event_not_completed` carrying no `event_id` plus `replace_order_hint`,
  a synthetic `document_sha256`, no `--definitions-dir` binding);
  `override_results.json` (`replace_after` for `body` and for a base
  result, `replace_result` of that same result with inline lines, a
  `choice_point` naming `"top"` and a `scene_end`, `append_result` of a
  new `condition`-selected result; targets `ai.school.gate.pic.1` with the
  real SHA-256 of `base/ai.school.gate.pic.1.json`, validated with
  `--definitions-dir base/`); `override_disable.json` (a single `disable`
  operation).
- `invalid/` holds one document per fail-closed rule of
  `docs/spec/data/mod_event_definition.md`, each a minimal
  mutation of a valid fixture (so every check before the one under test
  still passes and the intended reason is the first one raised). Five of
  them need `--definitions-dir base/` to reach their check
  (`target_missing.json`, `target_changed.json`, `unknown_result.json`,
  `result_exists.json`, `override_results_choice_mismatch.json` - the
  `base_bound` set below); every other fixture is validated without a
  definitions directory. `expected.json` maps every relative path under
  `valid/` and `invalid/` to `{"ok": bool, "reason": code}`; the reason
  codes are the ones `tools/validate_mod_event_definition.py` prints (see
  that module and `docs/spec/data/mod_event_definition.md` for the exact
  rule each code enforces).

## `base/`

`base/ai.school.gate.pic.1.json` is a copy of
`config/contracts/event_definition_v4/valid/choice_event.json` with its
`id` changed to `ai.school.gate.pic.1` (a real row of
`config/contracts/event_names_v1/`); it is otherwise the same invented v4
document that fixture set already carries and holds no original text. It
exists only so the `override` fixtures that carry `--definitions-dir`
checks (`target_missing`, `target_changed`, `unknown_result`,
`result_exists`, the base-choice-value mismatch in
`override_results_choice_mismatch.json`, and the valid
`override_results.json`) have a base document to load and hash against.

The `base_bound` set - fixtures validated with `--definitions-dir base/`
(everything else is validated without one):

```
valid/override_results.json
invalid/target_missing.json
invalid/target_changed.json
invalid/unknown_result.json
invalid/result_exists.json
invalid/override_results_choice_mismatch.json
```

Fixtures here are hand-written and carry no original dialogue text, no
machine paths and no original data beyond synthetic coordinates and
synthetic 64-hex-character hashes (`document_sha256`), except
`override_results.json`'s and `target_changed.json`'s `document_sha256`
against `ai.school.gate.pic.1`: one is the real LF-normalized SHA-256 of
`base/ai.school.gate.pic.1.json` (`tools/validate_mod_event_definition.py`'s
`document_sha256`), the other a deliberately wrong 64-hex value.

## Fingerprint

`contract_fingerprint` is the SHA-256 over the concatenation of
`"<relative path>\t<sha256 of the file bytes>\n"` for every file under this
directory except `contract_fingerprint` itself, paths relative to this
directory with `/` separators, sorted, LF line endings - computed by
`tools/contract_fingerprint.py`. A later revision is a new directory beside
this one, never an edit of `v1` in place, the same rule v3/v4 follow.

## The `"self"` / `"unrecorded"` convention

As in v3/v4: a hand-written fixture's own `contract_fingerprint` and
`cells_fingerprint` are the literal string `"self"`, accepted by
`tools/validate_mod_event_definition.py` as equal to the value passed with
`--fingerprint`/`--cells-fingerprint`. `"unrecorded"` is accepted only with
`--allow-unrecorded` (no fixture here uses it). The `invalid/` fixtures
that exercise the fingerprint and cells rules
(`missing_contract_fingerprint.json`, `foreign_cells_fingerprint.json`) do
not use `"self"`.

## See also

`docs/spec/data/mod_event_definition_design.md` is the design this set
implements; `docs/spec/data/mod_event_definition.md` is the contract statement that
fixes the exact document shape and check order. The workspace
`definitions/` directory, the transport between workspaces and the MES Editor's definitions panel
are later units.
