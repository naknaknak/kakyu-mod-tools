# Mod Event Definition (`kakyu_mod_event_definition/v1`)

Status: **frozen 2026-09-18** in this repository, by the owner's rulings of
the same day recorded in [the design document](mod_event_definition_design.md).
The contract is the fixture set `config/contracts/mod_event_definition_v1/`
(`contract_fingerprint`
`bd5d706db50b12ba5ddc7f0c442fd660b5c4fccbc640fdad758f1772e6e35a7a`, six
valid and 46 invalid documents plus one invented v4 base document), the
cell-class table `config/contracts/state_cells_v1/` (`cells_fingerprint`
`de21246988e7cb517ed04eda8a6c92625ba286a89f5f5e7db7441184d086cc73`) and the
event name registry `config/contracts/event_names_v1/` (`names_fingerprint`
`149ccc398689f2b02598af5919411290fac4c96ea42b0cfd49328571633727bb` since 2026-09-24, EP-12 catalog part - three ids joined, for the promoted `01m-a-date` flow routes; `4a04c35a1897b968cd7d9357b316be282516acf3eea9a8cadf461fcc8c1cc66a` from 2026-09-21, EP-10 unit 5b/c part 2; `dbad4b00f9e9725b29a5f84e6b7de576d30a5ae373f007801aad27cd09d9df63` from the same day, EP-10 unit 5a; `7721269a1613e1b37220a4879de387f65bf6d12969c4a5b220e3b2919d828b75` from 2026-09-19), the first two
unchanged. The sharing rule of 2026-09-16 stands: these directories change
here only, a revision is a `mod_event_definition_v2/` directory beside this
one, and the remake reads them from this repository and tests its own copy
with its own validator. The validator here is
`tools/validate_mod_event_definition.py`; the shared authored-text rules
are `tools/text_rules.py`.

## What it is for

A [projected v4 document](event_definition_v4.md) is evidence: bound to the
archive, a profile or catalog revision and the playback package, carrying
no text of its own. A mod's document has no original evidence, carries its
own text inline, and is written and edited by hand. The two share
vocabulary - conditions, effects, results, terminals, the cell-class table,
the name registry, the [text encoding](text_encoding.md) rules - and
nothing else, so they do not share a schema. A mod document is one of:

- **`new_event`**: an event the mod adds at a place the registry knows,
  scheduled by a definitions-only player beside the projected sites of
  that place;
- **`override`**: an edit to one projected v4 document - its conditions,
  its effects, one of its results, its order hint, or its presence -
  bound to the exact document it was written against.

An override never rewrites a projected line: an original line changes only
through the workspace's `remake_only` UTF-8 text projection. A mod's own
lines (a new event, a replaced or appended result) are inline.

## The document

### Header, both kinds

| Field | Rule |
|---|---|
| `schema_version` | `"kakyu_mod_event_definition/v1"` |
| `contract_fingerprint`, `cells_fingerprint` | the two fingerprints above, or `"self"` (the fixture convention) or `"unrecorded"` (accepted only with `--allow-unrecorded`) |
| `kind` | `new_event` or `override` |
| `mod` | `{id, revision}`: `id` matches `^[a-z][a-z0-9_]{1,31}$`, `revision` an integer >= 1 |
| `id` | `mod.<mod id>.<name>`, `name` matching `^[a-z][a-z0-9_]{0,63}$`; the middle segment equals `mod.id` |
| `display` | `{title_ko, title_en, heroine?, category, place}`: titles under the text rules with no line break, at least one non-empty; `heroine` one of the thirteen names the cell-class table carries; `category` one of `school`, `town`, `date`, `special`; `place` matching `^[a-z0-9_]+$`. Required for a `new_event`, optional for an `override` |

No other top-level key than the header and the kind's own fields
(`unknown_field`); no `text_ref` or `raw_sha256` anywhere in the document
(`text_ref_in_mod_document`).

### `new_event`

| Field | Rule |
|---|---|
| `trigger` | `{type: "place", category, place, order_hint?: {rank}}`; `category`/`place` equal `display`'s and, with the registry, occur on at least one registry row; `rank` an integer >= 1 |
| `conditions` | rows of the condition table below; may be empty |
| `presentation` (optional) | the remake's documented v2 block, shape only: `mode` a non-empty string; `background`, `bgm`, `hud`, `message_window` non-empty strings when present; `characters` a list of non-empty strings when present; nothing else |
| `dialogue` | entries of the dialogue table below |
| `after` | rows of the effect table below |
| `choice` (optional) | `{prompt?, options: [{value, label, result}]}`: `prompt` and each `label` under the text rules with no line break, `label` non-empty; `value` distinct integers >= 0; `result` a key of `results` whose `selected_by` is `{kind: "choice", value}` of that value |
| `results` | non-empty map, ids matching `^[a-z][a-z0-9_]{0,63}$`, each `{selected_by, event_played, dialogue, after, terminal, choice?, results?}`; `selected_by` is `{kind: "choice", value}` (an option value of the owning choice), `{kind: "condition", conditions: [non-empty]}` or `{kind: "default"}` (one per map); `terminal` a key of `terminals`; a nested pair follows the same rules at any depth |
| `terminals` | non-empty map of `{kind}`: `return_to_map` (the place reopens after the event) or `continue_caller` (the place's remaining flow continues) |
| `done` (optional) | `{cell: {storage, bank, index, value}}`: a cell whose class is `flag`, `counter` or `unnamed` - the mod's own seen mark, written at `scene_end`; absent, the player keeps the seen state under the document's id |

The v4 flow rules hold: a `choice_point` names `"top"` or a result that
carries a `choice`; a flow from the body through one result holds at most
one `scene_end`; a skipped result (`event_played: false`) reaches none.

### `override`

| Field | Rule |
|---|---|
| `target` | `{id, contract: "kakyu_event_definition/v4", document_sha256}`: `id` a registry id (in the registry, with `--names`); `document_sha256` the SHA-256 of the tracked v4 document's bytes with CRLF normalized to LF. With `--definitions-dir`, the file `<dir>/<id>.json` must exist (`target_missing`) and hash to that value (`target_changed`): a changed base fails closed until the author re-bases |
| `operations` | ordered, non-empty: `replace_conditions {conditions}`; `replace_after {scope: "body" or a top-level result id, after}`; `replace_result {result, result_document}`; `append_result {result, result_document}` (a new id; `selected_by` of kind `choice` or `condition`); `replace_order_hint {rank}`; `disable {}` (alone, `disable_not_alone`). One `replace_conditions`, one `replace_after` per scope, one replace or append per result id, one `replace_order_hint` (`duplicate_operation`) |

A `result_document` is a `new_event` result whose `terminal` is written
directly as `return_to_map` or `continue_caller`, with inline dialogue,
checked by the flow rules on its own. With the base document loaded, a
scope or replaced result must be one of its top-level results
(`unknown_result`), an appended result must not (`result_exists`), and a
`choice`-selected result must name an option value of the base's
top-level choice.

### Conditions

Each row is `{type, ...fields, failure_reason?}` with no other key.

| Type | Fields |
|---|---|
| `always` | - |
| `event_not_completed` | `event_id?` (default: the document's own id, or the override's target); a mod id or a registry id |
| `event_completed` | `event_id` (required, the same forms) |
| `flag_equals` | `name` (a mod flag, `mod.<mod id>.<flag>`), `value` (bool) |
| `weekday_equals` | `weekday` (0..6, the value `state_u16[4]` holds) |
| `date_equals` | `date_code` (MMDD as `state_u16[7]` holds it) |
| `date_in_range` | `from_date_code`, `to_date_code` (MMDD, from <= to) |
| `time_at_or_after`, `time_before` | `time_code` (HHMM as `state_u16[19]` holds it) |
| `legacy_cell` | `storage`, `bank`, `index`, `operator` (`equal`, `not_equal`, `less_than`, `greater_than`), `value`, `cell_class` (the class the table gives the cell) |
| `mes_expression` | `ast` (a non-empty object, the v4 guard AST form) |

The v2 kinds whose inputs only the remake's removed runtime defined
(`date_in_period`, `calendar_role`, the `character_*` family,
`protagonist_name_set`, `opening_sequence_completed`,
`mes_expression_file`) are not in v1; `legacy_cell` gates on the affection,
weekday, date and clock cells the table names.

### Effects

| Type | Fields |
|---|---|
| `write_legacy_value` | `storage`, `bank`, `index`, `value`, `cell_class` |
| `add_legacy_value` | `storage`, `bank`, `index`, `delta` (non-zero), `cell_class`, `min?`, `max?` (`min <= max`) |
| `consume_time` | `minutes` (> 0), `cell_class: "clock"`, at most one per list |
| `set_flag` | `name` (a flag of this mod: `foreign_flag_write` otherwise), `value` (bool) |

v4's rules hold: one row per cell per list, no write or add on a clock
cell, `cell_class` the class the table gives (a `global_u8` observed only
as 0 to 1 in the document's own rows is a `flag`).

### Dialogue and text

| Entry | Rule |
|---|---|
| `{kind: "line", text, speaker?, voice?}` | `text` non-empty (`text_empty`); `speaker` non-empty with no line break; `voice` matching `^[A-Za-z0-9_.-]+$` |
| `{kind: "choice_point", choice}` | as v4 |
| `{kind: "scene_end"}` | as v4 |

Authored text follows [Text Encoding](text_encoding.md): NFC-stable
(`text_not_nfc`); no control character but U+000A inside a line, no
U+FEFF, U+FFFD, noncharacter, surrogate or private-use character
(`text_control_character`); `{name}` is the only placeholder and stands
for the protagonist's name - any other brace sequence fails
(`bad_placeholder`). Titles, prompts, labels and speakers hold no line
break (`text_line_break`). There is no `name_insert` entry: the name is
written as `{name}`.

## Validation

```
py tools/validate_mod_event_definition.py <document.json> [--names config/contracts/event_names_v1]
    [--definitions-dir config/event_definitions/v4] [--fingerprint <fp>] [--cells-fingerprint <fp>]
    [--allow-unrecorded]
```

One JSON line `{"ok", "reason", "detail"}`, exit 0 or 1, the same
convention as the v4 validator; without the two fingerprint options the
tracked values are read. `tests/test_mod_event_definition_contract.py`
runs the fixture set, the registry gates and one override against a real
tracked v4 document; `tests/test_text_rules.py` the shared text rules,
which the v4 validator now calls through the same module with every v3
and v4 fixture result and fingerprint unchanged.

## Where a document lives, and what stays open

A mod's documents belong to the mod: they live in its workspace and
travel with it, never under `config/` here. The workspace directory
(`definitions/`, listed in the overlay manifest with each file's SHA-256
under the same publication lock as the overlay), the transport between
workspaces and the MES Editor's definitions panel followed this unit. The
transport ruling of 2026-09-18 was revised on 2026-09-19 because the
authored delta is one document per MES entry (see the design document): the
documents travel as a definition set file
([Mod Definition Set](mod_definition_set.md), landed 2026-09-19), and a whole
mod - its authored deltas, its translation-only entries and the set - as one
file, the [Mod Bundle](mod_bundle.md) (WD-10, 2026-10-11).
The remake's consumer - scheduling a `new_event` beside the projected
sites by category, place and rank, applying overrides to its copy of the
v4 documents at load - is its own backlog and reads everything from here.
