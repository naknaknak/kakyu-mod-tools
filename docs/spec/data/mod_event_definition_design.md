# Mod Event Definition (design draft)

Status: **implemented and frozen on 2026-09-18** - the contract statement is
[Mod Event Definition](mod_event_definition.md); this document keeps the
design and the rulings behind it. The
owner ruled on 2026-09-18 that definitions a mod writes itself (new events, and
edits to the conditions and effects of original events) are a **separate
contract** from the projected [Event Definition v4](event_definition_v4.md),
designed after v4's numbers were in. This document is that design; the
rulings and one corrected premise are recorded at the end. Working name
`kakyu_mod_event_definition/v1`; the contract statement follows with the
fixture set.

## Why a separate contract

A projected document is evidence: bound to the archive, a profile or catalog
revision and the playback package, and it may not carry text. A mod's own
document has no original evidence, carries its own text, and is edited by
hand. The two share vocabulary (conditions, effects, results, terminals,
the cell-class table, the name registry, the text encoding rules) and
nothing else, so they do not share a schema and a validator never has to
guess which rules apply.

## Two document kinds

### `new_event`

```
schema_version        "kakyu_mod_event_definition/v1"
kind                  "new_event"
mod                   {id: <mod id>, revision: <int>}
id                    "mod.<mod id>.<name>"           the mod's own namespace, never a registry id
display               {title_ko, title_en, heroine?, category, place}
trigger               {type: "scene", scene_kind, place, order_hint?: {rank}}   the same scene vocabulary as v4's
                       `scenes[].kind` and the registry's `place`; the remake schedules it beside the projected sites
conditions            v4 vocabulary (typed rows and `mes_expression`) plus the remake's v2 kinds
                       (`event_not_completed`, `flag_equals`, `date_in_range`, `time_before`, ...)
presentation          the remake's v2 `scene` and `presentation` fields (background, mode), remake-owned
dialogue              [{kind: "line", text, speaker?, voice?}, {kind: "name_insert"}, {kind: "choice_point", choice}, {kind: "scene_end"}]
after                 v4 effect rows (`write_legacy_value`, `add_legacy_value` with optional `min`/`max`,
                       `consume_time`) with `cell_class`, plus the remake's v2 kinds (`set_flag`,
                       `learn_character_info`, `mark_character_talked_today`)
choice, results       v4 shapes: `selected_by` choice or condition, `event_played`, per-result dialogue and after
terminals             {<id>: {kind: "return_to_map" | "complete_event"}}   the two the remake derives today
done                  {cell?: {storage, bank, index, value}}   optional: a legacy flag the mod owns, else the remake's own seen state
```

Text is inline and UTF-8 under [Text Encoding](text_encoding.md): the
authored rules there (NFC, no control character but U+000A as a line
break, no private-use character; `{name}` reserved for the protagonist's
name inside a line as a shorthand for a `name_insert` entry). No
`text_ref`, no `raw_sha256`, no package binding.

### `override`

```
schema_version        "kakyu_mod_event_definition/v1"
kind                  "override"
mod                   {id, revision}
target                {id: <registry id>, contract: "kakyu_event_definition/v4",
                       document_sha256: <the LF-normalized SHA-256 of the projected document the override was written against>}
operations            ordered list of:
                       {op: "replace_conditions", conditions: [...]}
                       {op: "replace_after", scope: "body" | <result id>, after: [...]}
                       {op: "replace_result", result: <id>, result_document: {...}}   (a v4 result shape with inline lines)
                       {op: "append_result", result: <new id>, selected_by, result_document: {...}}
                       {op: "replace_order_hint", rank}
                       {op: "disable"}
```

An override never carries a `text_ref` and never rewrites a projected
line: an original line is changed through the existing UTF-8 text
projection of the workspace (offset- and hash-bound, `remake_only`), and a
mod's new lines inside a replaced or appended result are inline text like a
`new_event`'s. A changed base document (a different `document_sha256`) fails
closed: the override must be re-based by its author.

## Where the documents live and travel

- **In the mod workspace**, under `definitions/` beside the overlay, one
  file per document, listed in the workspace manifest with each file's
  SHA-256 (the same publication lock and atomic manifest as the overlay).
- **In the distributable delta**: a new delta revision (v10) carries the
  documents inline in a `definitions` list - they are the mod's own data,
  small, and need no original bytes - so one artifact still describes one
  mod; the importer stages them into the destination workspace's
  `definitions/` and validates them. Older deltas stay readable.
- **The remake** reads a mod's definitions from its imported workspace or
  package the way it reads the projected documents, applies overrides to
  its copy of the v4 documents at load, and schedules `new_event` triggers
  beside the projected sites by scene kind, place and rank.

## Validation here

`tools/validate_mod_event_definition.py`: shape, the vocabularies above,
the text rules, the cell classes, `target.document_sha256` against the
tracked v4 document, every referenced result and terminal, the mod
namespace, no `text_ref`, no registry id as a `new_event` id. A fixture set
`config/contracts/mod_event_definition_v1/` with its own fingerprint, mirrored
to the remake by the owner as the others were. The editor is a later unit:
a definitions panel in the MES Editor's workspace (it already owns the
workspace, the overlay and the authoring session) that lists the workspace's
definitions, opens one in a structured form, validates on save and shows a
projected v4 document read-only beside an override.

## Rulings, 2026-09-18

The owner took every recommendation as given:

1. **Text of original lines** changes only through the `remake_only` UTF-8
   text projection of the workspace; an override never rewrites a projected
   line. A mod's own lines (a new event, a replaced or appended result) are
   inline.
2. **Presentation of a new event** reuses the remake's documented v2
   `presentation` block (`mode`, `background`, `bgm`, `characters`, `hud`,
   `message_window`), validated here as a shape only and owned by the
   remake. **Corrected premise:** the recommendation said the remake
   executes these fields today. Measured on 2026-09-18: the remake's tracked
   tree holds no v2 runtime any more (its game prototype and bytecode path
   were removed; `data/events/` there is ignored leftovers; its 33 scripts
   name `flag_equals` only in the v3 validator). The block is therefore the
   remake's *documented* vocabulary, which its own consumer backlog will
   implement together with v4; nothing executes it yet on either side. The
   `scene` field (a `res://` path) is left out as not portable.
3. **Transport:** definitions travel inline in the delta as v10, one
   artifact per mod. **Under review since 2026-09-18, after the ruling:** the
   premise "one artifact per mod" is wrong. `kakyu_authored_mod_delta/v9`
   is one document per MES entry (its identity is the source entry and
   its output hash; a mod that edits two entries already ships two
   deltas), and a definitions-only mod - a new event that touches no MES
   entry - has no source entry to bind a delta to. The transport was
   put back to the owner with three options. **Ruled 2026-09-19: option 1,
   a definition set file** (`kakyu_mod_definition_set/v1`): one JSON
   document carrying the mod identity, the contract fingerprints and
   every definition inline, published beside the mod's deltas and
   imported into a workspace's `definitions/` by a bounded importer; the
   delta format is not touched. A mod bundle (one artifact holding
   deltas and definitions) stays a later topic, to be taken up when the
   multi-entry delta is. Landed the same day:
   [Mod Definition Set](mod_definition_set.md). The bundle landed on
   2026-10-11 (WD-10): [Mod Bundle](mod_bundle.md) carries the deltas, the
   translation-only entries and a set in one file.
4. **The editor** is a panel in the MES Editor: the Definitions tab,
   landed 2026-09-19 (JSON text with templates, inline validation, save through
   the workspace's validated staging, set import and export; a structured
   form is a later increment).

Two scoping choices made with the rulings, for the same reason as the
corrected premise: the v2 condition kinds whose inputs only the removed
runtime defined (`date_in_period`, `calendar_role`, the `character_*`
family, `protagonist_name_set`, `opening_sequence_completed`,
`mes_expression_file`) and the effects `learn_character_info`,
`mark_character_talked_today`, `set_opening_sequence_completed` are not in
v1 of this contract; a `legacy_cell` comparison (the typed form of v4's
guard conjuncts) stands in for gates on affection, weekday, date and clock
cells. The unit that freezes the contract is the fixture set and validator
(`config/contracts/mod_event_definition_v1/`,
`tools/validate_mod_event_definition.py`); the workspace `definitions/`
directory and delta v10 follow; the editor panel last.
