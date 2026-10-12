# Event Definition v5 (`kakyu_event_definition/v5`)

Status: **frozen 2026-09-23** by the owner's rulings of the same day: EP-11
(both units) and the WD-23 v5 shape - a document-level `visits` list, each
visit selected by state conditions (the counter value, gate flags), v4's
`reentry` kept unchanged and the visits continuing after it. The contract is
the fixture set `config/contracts/event_definition_v5/` (README there for
the exact fingerprint and fixture list), the same cell-class table
`config/contracts/state_cells_v1/` and event name registry
`config/contracts/event_names_v1/` v4 uses (unchanged), and the two v13
analysis-group profiles the two visit-carrying documents project from:
`config/event_catalog/analysis_groups/44c_m10b_v13.json` (EVENTM10 site B)
and `44c_m03_v13.json` (EVENTM03). The sharing rule of 2026-09-16 stands:
`config/contracts/event_definition_v5/` and `config/event_definitions/v5/`
change here only, a revision is a new directory beside them, and the
remake reads them from this repository. `event_definition_v4/` and
`config/event_definitions/v4/` are frozen: untouched by this contract.

## Why v5 exists

v4 said what a definitions-only player needs for one pass through a site:
the flow, the effects, the done state. It could not say what a *revisited*
site does across a session for the handful of sites whose callee keeps its
own visit counter and changes what it plays each time - EVENTM10 site B (a
gated ladder that dispatches `EVENTM11.MES` from its second visit on, EP-11
part 1a/1c) and EVENTM03 (a sixteen-rung day-change ladder, EP-11 part 1b/1c
- see `docs/spec/mes/44c_caller_group.md`). v4's `reentry` names only the
callee's own *next* pass after the first, not the whole chain; a consumer
with no further structure would either replay the first visit forever or
invent its own guess at what a revisit does. v5 carries that chain as data,
the same way v4 carries `after` as data instead of leaving effects for a
consumer to infer.

## The document

A v5 document is a v4 document (`docs/spec/data/event_definition_v4_design.md`,
`config/contracts/event_definition_v4/`) with these changes; every v4 rule
not listed here holds unchanged:

| Field | v5 |
|---|---|
| `schema_version` | `"kakyu_event_definition/v5"` |
| `contract_fingerprint` | the v5 fixture set's own fingerprint |
| `visits` (optional, top-level) | absent or empty for a site without a declared visit ladder; a list of visit objects (below) for the two sites that have one |

Each visit:

| Field | Meaning |
|---|---|
| `visit_id` | the profile's own `visit_id` (from the v13 analysis-group profile), unique in the document |
| `follows` | `"reentry"` or an earlier `visit_id` in the same list (the pass whose state this visit continues); the profile's own `after` field, with `"route"` (the route's own first dispatch) written as `"first"` |
| `select` | the conditions that hold when this visit plays, in v4's own condition-expression vocabulary, never a new one: one plain equality row (`{storage, bank, index, operator: "equals", value}`, the shape `results[].selected_by.conditions` already uses) per counter cell the callee tests by equality on this visit's run, the value taken from the visit's own `entry_state`; and, for each `seed_writes` cell, the callee's own branch condition that reads it on this visit's run, taken whole from the audited bytecode as a `{"type": "mes_expression", "ast": {...}}` row (the same `and`/`or`-of-`cell`-leaves tree the guard's own `conjuncts` use, just nested instead of flat) - never simplified to the one seeded cell alone. A visit whose run takes the gate's false edge carries the same tree negated (De Morgan's: `or` of `not_equal 0` becomes `and` of `equal 0`) |
| `dialogue` | the visit's own flow, in v4's dialogue-entry form (`text`/`name_insert` referencing the package through `text_ref`, never embedding it), a nested dispatch's own lines appearing as entries of the dispatched entry, exactly one `scene_end` |
| `after` | the visit's own effect rows, in v4's three types, decided the way v4 decides a result's effects (rule 2) over every net-changed cell the visit's own replay shows - not only the profile's curated `expected_state` - else a line in the document's own `unresolved` |
| `repeats` | `true` on the one visit whose rung the ladder no longer advances past (the fixed point: EVENTM10 site B's `visit5-gate`, EVENTM03's `ladder-15`); `false` on every other visit |
| `evidence` | `{group, profile_sha256, route, seed_basis}` - `group`/`route` name the analysis-group profile and route the visit came from, `profile_sha256` is that profile's own `payload_sha256`, `seed_basis` is copied from the profile's own visit (`"tool_seeded"` for every gated M10 visit and every M03 day-change visit, `"none"` for the two visits whose state needs no seed beyond the pass they continue) |

A consumer fails closed on everything v4 fails on (applied inside a visit's
own `dialogue`/`after` unchanged - the validator reuses
`_check_dialogue_entries_v4`/`_check_effect_rows_v4` directly, so a clock
cell in a visit's `after` fails with v4's own `clock_cell_effect` reason,
not a new one) and on: an unknown `follows` (`bad_visit_follows`), a cycle
or a forward reference - both ruled out by the single rule that `follows`
must name `"reentry"`, `"first"`, or a `visit_id` already declared earlier
in the same list (`bad_visit_follows`), a duplicate `visit_id`
(`duplicate_visit_id`), an empty `select` (`empty_visit_select`), a `select`
row outside the vocabulary above (`bad_visit_select`), more than one
`repeats: true` in one chain (`duplicate_visit_repeats`), and a visit whose
dialogue does not carry exactly one `scene_end` (`bad_visit_scene_end`).

## How the producer decides

`tools/project_event_definition_v5.py` shares `project_event_definition_v4.py`'s
whole pipeline for the v4 body (it monkeypatches the v4 module's
`SCHEMA_VERSION` for the run and points `--contract-fingerprint` at this
contract's own directory, rather than copying the candidate/effect/dialogue
machinery) and adds `visits` only for the two sites a table names
(`tina.town.44c.10.2`, `tina.town.44c.03.1`):

- **Replay.** The analysis-group validator's `--replay` mode now also
  writes, per declared visit, the visit's own message rows and its own full
  `state_diff` (WD-23; `tools/content_suite/event_analysis_group_validation.gd`
  computed this already for its own per-visit checks but never carried it
  into the written file - a defect this task's own replay step found and
  fixed). Every route's variants reproduce byte-identical visit dialogue
  and effects (measured over all 5 of EVENTM10 site B's variants and all 17
  of EVENTM03's own `44c-m03` variants - neither ladder reads a calendar
  cell), so the producer reads the first variant's own visits as canonical.
- **Select.** The counter cell (`global_u8[2456]` for EVENTM10 site B,
  `global_u8[2421]` for EVENTM03) is read from the visit's own declared
  `entry_state` and asserted by equality; a defensive check compares
  EVENTM10's own counter value against the documented rung table
  (`docs/spec/mes/44c_caller_group.md`) and raises rather than silently
  drifts if the profile ever disagrees. EVENTM10's gate condition is the
  audited 23-cell test (`global_u8[287..302]`, `[316..318]`, `[320..323]`)
  for the second and third rungs and the 24-cell test (the same 23 plus
  `[319]`) for the fourth-and-later rung, positive for a visit whose
  `seed_writes` opens it and negated for the sibling visit at the same
  counter value that does not (`visit3` against `visit3-gate`, both at
  counter `2`). EVENTM03's join condition is the audited `[2420] == 1 and
  [2417] == 0` test at `13328`, taken whole for every one of its sixteen
  visits (none of them takes its false edge).
- **Effects.** Every visit of one route is treated as one group, exactly
  as v4 treats a result's own variants (rule 2,
  `project_event_definition_v4.decide_effects_for_group`): a `global_u8`
  cell observed 0 to 1 on every visit's own run is `write 1`
  (`flag_pattern`, no witness needed - EVENTM03's own `[2417]`, set on all
  sixteen visits); a cell whose entry value varies across sibling visits
  with one consistent delta is `add` (the ladder counter itself, `+1` on
  every visit that advances it, none on the one that does not); every other
  net-changed cell a visit's own run reaches - including a nested
  dispatch's own writes, and including cells that read as native
  presentation scratch - has only one sample at its own entry value with no
  witness to arbitrate it, so it is left `unresolved` by name rather than
  guessed. The one decided row for a cell is assigned to every visit whose
  own run actually changed it, not to a single shared body (a visit has no
  such shared body to hold it in).
- **Dialogue.** Built from the canonical variant's own per-visit message
  rows through `project_event_definition.build_dialogue_entry` (v3's own
  function; a nested dispatch's messages carry that dispatch's own entry
  name already, so they read as its own entries with no extra marker), one
  `{kind: "scene_end"}` appended.
- **Every other site.** `tools/project_event_definitions_batch.py --contract v5`
  projects it exactly as `--contract v4` does; only `schema_version` and
  `contract_fingerprint` change.

## The projection of every registry site

`config/event_definitions/v5/README.md` records the batch command and the
projection result over all 142 registry sites.

## What stays open

Every v4 open item stays open (`docs/spec/data/event_definition_v4.md`,
"What stays open") since v5 changes nothing about how the other 140
documents are decided. For the two visit-carrying documents themselves: the
per-cell `unresolved` lines the effect-deciding rule above produces (a
gated EVENTM10 visit's own nested-dispatch writes and several session
counters `docs/spec/mes/44c_caller_group.md` already flags as
"genuine effects of running a gated rung itself, not of the visit-counter
ladder alone"); presentation, deferred exactly as in v4. The remake's own
consumer for `visits` is its own backlog, as v4's own consumer is.
