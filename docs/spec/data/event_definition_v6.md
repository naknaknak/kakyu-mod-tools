# Event Definition v6 (`kakyu_event_definition/v6`)

Status: **contract and producer both landed 2026-09-25** (EP-12 / WD, the
owner's ruling of the same day). Unit 1 landed the design document, the
conformance fixture set (`config/contracts/event_definition_v6/`), the
validator (`tools/validate_event_definition.py`) and its tests. Unit 2
landed the producer (`tools/project_event_definition_v6.py`) and the 145
tracked v6 documents (`config/event_definitions/v6/`): a real `flow` block
for each of the three flow routes the catalog carries, and the other 142
sites re-projected through the same code path v5 uses (see
`config/event_definitions/v6/README.md` for the measured result, which
turned out not to be "unchanged but for schema and fingerprint" for most of
them - "How the producer decided" below). The sharing rule of 2026-09-16
stands: `config/contracts/event_definition_v6/` and
`config/event_definitions/v6/` change here only, a revision is a new
directory beside them, and the remake reads them from this repository.
`event_definition_v5/` and `config/event_definitions/v5/` are frozen:
untouched by this contract.

*Note, 2026-10-08 (WD-21 U2):* v6 is itself frozen now. `kakyu_event_definition/v7`
(`event_definition_v7.md`: v6 plus the measured `presentation.resources`) is the live contract, its 681
documents are the live set (the promoter and the catalog read them), and `config/event_definitions/v6/` stays
bound to the WD-21 U1 package `b638bd7d...`; "the live set" below and in the dated history means the
state on the date written.

## Why v6 exists

v5 said what a definitions-only player needs for one pass through a site, or
a chain of same-callee revisits (`visits`). Neither shape can say what a
**flow** route needs: the `kakyu_event_analysis_group/v14` shape
(`config/event_catalog/analysis_groups/01m_a_date_v14.json`, the promise
date group `docs/spec/mes/a_date_flow.md` measured and declared) carries a
date as an ordered chain of hops across several scripts - the shared
prefix's own scene, a place-specific tail, sometimes a root handoff into a
whole separate script (`A_DATE5.MES`, the hotel chain). A v5 document has no
way to say which script each part of the date runs in, what a routine-40
the flow answered, what the tool seeded into a gate the flow's own state
depends on, or where the host's own poll a hop's own wait loop needs was
supplied. The remake needs exactly that to play a date from the playback
package alone (the load-bearing invariant this repository's output always
has to satisfy: the remake never reads an original ARC or MES entry) and to
know, itself, what stands in for an unresolved native mechanism (a host
poll, a natural clearing) the flow's own evidence already names as such. v6
carries the hop chain as data, the same way v4 carries `after` and v5
carries `visits` as data instead of leaving either for a consumer to infer.

## The document

A v6 document is a v5 document (`docs/spec/data/event_definition_v5.md`,
`docs/spec/data/event_definition_v4_design.md`,
`config/contracts/event_definition_v5/`) with these changes; every v5 rule
not listed here holds unchanged:

| Field | v6 |
|---|---|
| `schema_version` | `"kakyu_event_definition/v6"` |
| `contract_fingerprint` | the v6 fixture set's own fingerprint |
| `flow` (optional, top-level) | absent for a site that is not a flow route; the flow block (below) for a document projected from a `kakyu_event_analysis_group/v14` route. A document never carries both `flow` and a non-empty `visits` (`flow_with_visits`) |

The flow block:

| Field | Meaning |
|---|---|
| `evidence` | `{group, profile_sha256, route}` - the v14 profile (its `group_id`, `payload_sha256`) and `route_id` the document projects from |
| `origin` | `{entry, entry_sha256, offset, guard: {offset, end, false_target, record_sha256}}` - the flow's own origin guard record (the profile's own `origin`); its conjuncts are the document's own top-level `guard`, as for any site, so they are not repeated here |
| `state_context` | `{"kind": "fresh"}` or `{"kind": "original_calendar", "entry": "START.MES", "table_sha256": <64 hex>}` - the v14 route's own |
| `hops` | a non-empty list of hop objects (below), in run order |
| `terminal` | the id of one entry of the document's own `terminals`; `results.result_default.terminal` names the same id (`bad_flow_terminal` otherwise) |

Each hop:

| Field | Meaning |
|---|---|
| `hop_id` | the profile's own, unique in the list (`duplicate_hop_id`) |
| `entry`, `entry_sha256` | the script this hop runs in |
| `entered_by` | `{kind, offset, end}`; `kind` is `origin` (the first hop only, and the first hop must be `origin`), `nested_call`, `root_handoff` or `resume` (`bad_hop_entered_by`); for `origin` the offset is the origin guard's, otherwise the dispatch/handoff/return record the profile's `entered_by` names |
| `answers` | rows `{boundary_offset, result_value}`, `result_value` an integer (`bad_hop_answer`) |
| `gates` | rows `{storage, bank, index, value, basis}`; `basis` is `"tool_seeded"` or `{"written_by": <an earlier hop_id>}` (`bad_gate_basis` for anything else, including a later or unknown hop); `storage` one of v4's legacy storages |
| `map_locations` | rows `{entry, poll_offset, values: [ints]}` (`bad_map_location`) |
| `poll_supplies` | rows `{definition, entry, poll_offset, result_storage, result_index, value}` (`bad_poll_supply`) |
| `dialogue` | this hop's own lines in v4's entry form (`text`/`name_insert` through `text_ref`, `location_line` allowed); no `scene_end` and no `choice_point` inside a hop (`hop_scene_end`, `hop_choice_point`); may be empty |
| `after` | this hop's own decided effect rows in v4's three types (the v4 rules apply unchanged inside a hop - a clock cell here fails with v4's own `clock_cell_effect`); may be empty |
| `message_count` | the hop's measured line count; must equal the number of `text`/`name_insert` entries of the hop's `dialogue` - checked on entry count alone, whether or not `--package` is given (`hop_message_count`) |

Top-level rules for a document that carries `flow`:

- `trigger` is the flow's first dispatch as `caller_dispatch` (the same site
  the catalog row and the registry row use) - no new trigger type.
- `dialogue` is exactly: for each hop in order, one marker `{"kind": "hop",
  "hop_id": <id>}` followed by that hop's own `dialogue` entries verbatim;
  then exactly one `{"kind": "scene_end"}`. Both a mismatched marker/entry
  and a missing or misplaced trailing `scene_end` fail with
  `hop_marker_mismatch` (see "What changed" below for why this contract
  does not add a second reason for the trailing marker). The `hop` marker is
  a new dialogue entry kind allowed only in a flow document's top-level list
  (`hop_marker_outside_flow` when it appears in a document that carries no
  `flow`).
- `results` holds exactly `result_default` with `selected_by.kind ==
  "default"`, `event_played: true`, `dialogue: []` (the flow's lines live in
  the top-level list), and `terminal == flow.terminal`.
- `after` (top-level) is the flow's own decided effects over the whole run
  (v4's three types); a hop's `after` rows and the top-level rows may both
  name a cell (the top-level row is the net effect) - no duplicate rule
  across the two levels, the v4 one-row-per-cell rule holds within each
  list.
- `visits` absent or empty.
- The v4 `conditions`, `presets`, `guard`, `terminals`, `dependencies`,
  `presentation`, `unresolved`, `package_binding` rules hold unchanged.

## Fail-closed reasons added by v6

Each with an invalid fixture in `config/contracts/event_definition_v6/invalid/`
(a mutation of `flow_event.json`, one field changed per fixture):
`flow_with_visits`, `flow_without_hops`, `duplicate_hop_id`,
`bad_hop_entered_by`, `bad_hop_answer`, `bad_gate_basis`,
`bad_map_location`, `bad_poll_supply`, `hop_scene_end`,
`hop_choice_point`, `hop_message_count`, `hop_marker_mismatch`,
`hop_marker_outside_flow`, `bad_flow_terminal`, `bad_flow_evidence`
(missing/invalid `group`/`route`/`profile_sha256`), `bad_state_context`.
Every v4/v5 reason applies unchanged where the rule is the same: a clock
cell in a hop's `after` still fails `clock_cell_effect`; a malformed `flow`
sub-object with no reason of its own above (a hop that is not an object, a
missing `hop_id`, a malformed `origin`) reuses the generic `flow` reason,
the same way `_check_visits_v5` reuses the generic `visits` reason for a
malformed visit shape v5 names no dedicated code for.

## What changed from the design draft on contact with the v4/v5 rules

The design draft (`analysis/_docs/ep12_definition_v6_contract_spec.md`)
listed `bad_scene_end` as a candidate reason for "the single trailing
`scene_end` is missing or misplaced," alongside "or a v6 reason of your
naming." Neither v4 nor v5 names a `bad_scene_end` reason anywhere, and
inventing a seventeenth reason for one sub-case of the same interleaving
check the marker/entry mismatch already uses would only fragment one rule
(the top-level `dialogue` list's own exact shape) across two reason codes
for no consumer-visible benefit - a consumer fails closed either way and
does not need to distinguish "the wrong hop's lines are here" from "the
scene never ends" to react correctly (both mean: do not trust this
document's own flow shape). This contract therefore folds the trailing
`scene_end`'s own missing/misplaced case into `hop_marker_mismatch`,
documented in the fixture set's own README and exercised by
`flow_hop_marker_mismatch.json` (which removes a hop marker, the same
interleaving check that would also catch a missing or misplaced
`scene_end`).

## How the producer decided (unit 2, 2026-09-25)

`tools/project_event_definition_v6.py` shared `project_event_definition_v5.py`'s
pipeline for the v5 body exactly as v5 shares v4's (wrapping `run_site_v5`
with `SCHEMA_VERSION`/`--contract-fingerprint` patched to v6's own, one
`build_flow_document` function of its own for `flow`), and added `flow`
only for the three sites the `01m-a-date` `kakyu_event_analysis_group/v14`
route declares:

- **Replay per hop.** Each hop's own `entered_by`/`answers`/`gates`/
  `map_locations`/`poll_supplies` were read straight from the declared v14
  profile (already audited by `tools/audit_event_analysis_group.py`'s own
  `_audit_flow_route` family) and its own v2 flow replay (a new mode of
  `validate_event_analysis_group.gd --replay`, wired through the shared
  `_shared` per-message/per-terminal helpers the v6/v13 replay path already
  used - the CLI's flow branch now takes `--replay` too); the producer's own
  job was projecting that shape into the event-definition vocabulary above,
  never re-deriving it.
- **Effects by v4 rule 2.** Over the one variant each flow route declared
  (`consume_time` folded in from the clock advance the way v4 already
  projects it elsewhere), each hop's own net-changed cells became that
  hop's own `after` rows, and the flow's own net effect over the whole run
  became the top-level `after` - the same "group by what a run does"
  decision v4's `decide_effects_for_group` already makes for a plain
  result, applied per hop and once more for the whole flow.
- **The other 142 registry sites** were re-projected through the same code
  path v5's own batch mode uses under `--contract v5` (`resolve_site_v4`,
  the same frozen analysis-group profiles, the same effect-decision rule),
  patched to v6's schema/fingerprint only - but this turned out **not** to
  mean "byte-identical to their v5 sibling," measured: only 3 of the 142
  matched that shape exactly. The other 139 also carried more resolved
  `after`/`evidence.effect_witnesses` rows and fewer `unresolved` lines
  (1,997 fewer, net, across the 142, in the first projection `97382f2`; the
  committed set lost every such row at `f9a2454` and TD-37 restored them -
  "Witness evidence is required" below, `config/event_definitions/v6/README.md`
  for the counts), because the `analysis/witnesses/`
  shift-witness corpus this producer reads from disk - the same one v4/v5
  always read from, never a copy pinned to their own build - had grown
  since v5 froze on 2026-09-21 (later units answered more witness requests
  for their own sites, against the same unchanged, frozen profiles). Every
  added row was checked against v5's own value for the same cell and result
  label: none disagreed - the growth was strictly additional resolution,
  not a correction of anything v5 already decided. `config/event_definitions/v6/README.md`
  records the exact measurement; this section's original prediction (this
  paragraph, before it was reworded past tense by this unit) had assumed
  the evidence pool would not have moved since v5's own freeze.

## Album-scene flows (EP-12 SCENE, 2026-10-04)

The producer also projects the album-scene flows of
`docs/spec/mes/gallery_families.md` ("Declared: heroine J's album", "Declared:
all albums"): 365 documents (the 13 menus' scenes) whose `flow` has two hops (the menu, entered by its origin guard, with
no lines; then the scene, entered by the menu's nested call) and ends at the
scene's own `script_return`. No contract change - the shapes below are already
v6's: the flow's one terminal is `kind` `callee_return` (an existing v4 terminal
kind, with an empty `next_target`) instead of `natural_handoff`; `dependencies`
lists only entries the route's own hops run (an album group declares every scene
of its menu as a member, and a scene depends on none of the others); the first
`unresolved` line says the guard is the scene's unlock test, set by ordinary play
and never cleared by a literal write, instead of the date guard's own text. A
`SCENE_` row is told by its registry row (`special` category, `SCENE_` callee).
The presets are the baseline only (the seeded menu selection): a scene's other
question options and a recap scene's second path are variants of the route
(`answers`, `message_counts`) and presets of its catalog row, not part of the
document (the projector projects `variants[0]` only, as for every flow).

## Room recollection flows (EP-12 H, 2026-10-04)

The producer also projects the 13 recollection ladders of the protagonist's room
(`docs/spec/mes/43c_caller_group.md`, "Declared: the 13 recollection ladders"):
`<name>.town.43c.h.1`, 13 documents whose `flow` has two hops (`43C.MES` from the clock
save through the heroine's id test to the ladder's nested call, no lines; then the
ladder, entered by that call) and ends at the ladder's own `script_return`. No contract
change: the terminal is `callee_return` as for an album scene; the row is **not** a
gallery row (`is_gallery_registry_row` is false - its callee is not a `SCENE_`
entry), so `dependencies` are the members the route does not run itself (empty, but
`O_PIC.MES` for `NANA_H`) and its first `unresolved` line is the date flows' sentence,
now spelled from the flow's own guard conjuncts (`state_u16[13] equal <id>`). The
presets are the baseline only (the seeded selection, the room's ambient cells and every
gate flag of the ladder set - the full recollection); the `no-recollection` variant is a
variant of the route and a preset of its catalog row, not part of the document
(the projector projects `variants[0]` only, as for every flow). A document plays up to
911 lines: the largest in the set.

**TD-43 (closed 2026-10-04).** Until this unit every non-album flow document - the 35
date documents - carried one fixed first `unresolved` line naming heroine A's town-date
guard cells. `flow_done_flag_line` in `tools/project_event_definition_v6.py` now writes
the line from the guard conjuncts the producer already reads, so each document names its
own guard; the 35 documents' first `unresolved` line is the one expected change of the
regeneration that landed it.

## TALK flows (EP-12 TALK K, 2026-10-04)

The producer also projects heroine K's conversation scripts
(`docs/spec/mes/talk_family.md`, "Declared: heroine K"): `ai.town.station.talk-30.1` ..
`talk-90.1`, `talk-00.1` - eight documents whose `flow` has three hops (`01M.MES` from the
block guard through the picture and intro scripts, the gate and the rung's test to the script's
nested call; the script from its start to its return; the caller resuming through the outro to
the `MACHI.MES` handoff) and a `natural_handoff` terminal - and `ai.town.27c_ev.talk-plain.1`, a
two-hop flow ending at the script's own `script_return` (`callee_return`, as an album scene). No
contract change (the `resume` hop kind and the terminals are v6's own). Two producer rules, both
**tool decisions** and both limited to a TALK row (`is_talk_registry_row` in
`tools/payload_values.py`, the one predicate the promoter and the registry builder share), the
second the album branch's counterpart:

- **Involved entries include the inline nested scripts.** A hop runs the scripts it dispatches
  inline: hop 1 of a rung plays the lines of `K_INTRO.MES`, hop 3 those of `K_OUTRO.MES`, while
  the hop's own entry is `01M.MES`. The package documents that resolve a flow's replayed lines are
  therefore those of the hop entries **and of every entry that played a replayed line**
  (`flow_involved_entries`); before this unit a replayed line whose entry was not a hop entry
  stopped the projection (`KeyError`). Every earlier flow's lines come from its hop entries, so
  no earlier document moves.
- **Dependencies are the route's own entries.** A TALK group declares every rung script of a
  heroine as a member, and a rung depends on none of the others. A TALK row's `dependencies`
  are the group members its own route runs (`talk_route_entries`): the entries that played a line
  in any of its replayed variants (the follow-on `K_TALKXX.MES` for the rungs that call it) and
  the silent nested scripts its hops dispatch (`K_PIC.MES`: a dispatch inside the span a hop runs
  whose target is a member), minus the callee scripts of the profile's other routes (the ladder's
  other rungs sit statically inside the caller's span, behind branches this route does not
  take). Rung 30 depends on `K_PIC`, `K_INTRO` and `K_OUTRO`; rungs 50..00 also on `K_TALKXX`;
  the plain script on `K_PIC` alone. Album and date documents are unchanged (`flow_dependencies`
  keeps their rules).

The presets are the baseline only (the seeded block state with the natural presence state); a
rung's other variant (`flag-2194`, the follow-on's flag set) is a variant of the route and a
preset of its catalog row, not part of the document (the projector projects `variants[0]` only,
as for every flow). The re-asking answers are named in each route's `unresolved`.

**The other conversation scripts (EP-12 TALK rest unit, 2026-10-05).** The same two rules project the other
eleven heroines' 88 rung documents (`<name>.town.station.talk-<band>.1`, three hops), their eight plain scripts
(`<name>.town.27c_ev.talk-plain.1`, two hops), Tina's `tina.town.station.talk-plain.1` (three hops: the caller
reaches the `MACHI.MES` handoff) and the characters' eight (`common.town.<place>.talk-<letter><digit>.1`: `Q_TALK`
three hops, the other seven two), 114 TALK documents in all with heroine K's nine; no contract change, no producer
change. A rung's dependencies are its `?_PIC`, `?_INTRO` and `?_OUTRO` and, where a variant reaches one, the
follow-on its route runs (`K_TALKXX`, `H_TALKXX`, `A_TALK51`, ...); a band-less script's are the picture
script its block dispatches (`A_PIC`; `O_PIC` for `M_TALK`; `N_PIC` for `N_TALK2`, whose block also plays lines of its own)
and the nested scripts its own route runs (`E_TALK` nests `N_PIC`). The `common` documents carry no heroine of their own. Heroine K's eight
rung documents differ from the K unit's in the group profile hash alone (her contracts moved from `v5` to `v6`).

**`N_TALK1`'s third hop (EP-12 TALK follow-ups, 2026-10-05).** Re-measuring the 13 `27C_EV.MES` anchors that had inherited heroine K's
two-hop result found one whose caller reaches a handoff: `common.town.27c_ev.talk-n1.1` is a three-hop flow ending at `FLOOR5.MES`
(`27C_EV.MES:83150`, 6 more messages, route outcome `map_return`), where it had been two hops and `place_menu`; its `N_TALK` group-mate
(`common.town.27c_ev.talk-n.1`) differs only in the group profile hash and one `unresolved` line. The other 679 documents differ in
`package_binding.package_sha256` alone; the contract, the producer and the registry are unchanged (`docs/spec/mes/talk_family.md`, "Hop 3 of
the 14 `27C_EV.MES` anchors, measured").

## Witness evidence is required (TD-37, 2026-10-03)

The producer's `shift_witness`-basis effect rows and `reentry_probe` done
cells exist only when the witness corpus is on disk when it runs: for every
non-flow (non-v14) profile a site matches, `analysis/witness_requests/<stem>.json`
(`tools/plan_event_effect_witnesses.py`, one file per replay, flow replays
skipped) and `analysis/witnesses/<stem>.json`
(`validate_event_analysis_group.gd --witness`), both carrying the profile's
current `payload_sha256`. The corpus is untracked (it is derived from the
archive, the tracked profiles and the replays) and the schema is unchanged:
the documents and `index.json` carry no field that says whether witnesses
were read. v4/v5 (frozen) read it silently - an absent or stale file meant
fewer rows and no warning, and the committed v6 set lost its witness-derived
rows that way between `f9a2454` and TD-37. The v6 producer therefore fails
closed: a site is refused (exit 1) when any profile it matches has no request
file, requests without a witness file, or a `payload_sha256` other than the
profile's, and the batch refuses before its first site when the corpus
directories are absent. `--allow-missing-witnesses` is the explicit opt-out
for absent evidence (a `WARNING` per site and a count at the end of the
batch); stale evidence is refused either way. The restored committed set
carries 1,718 `shift_witness` evidence rows and 46 `reentry_probe` done cells
(all 1,251 and 34 of `97382f2`'s among them), and
`tests/test_event_definitions_tracked.py` asserts the set carries at least
those 1,251 and 34 (and that the index agrees), so a regeneration that drops
them fails the test instead of passing silently.

## What stays open

Every v5 open item stays open (`docs/spec/data/event_definition_v5.md`,
"What stays open") since v6 changes nothing about how a non-flow document is
decided. For a flow document itself, unit 2 inherits what
`docs/spec/mes/a_date_flow.md` already flags as unresolved for the one
declared group (`01m-a-date`): `state_u16[18]`'s natural clearing for
definition 17's wait, `state_u16[12]`'s natural supply, and
`global_u8[110]`/`[117]`'s own natural writer. Two shapes this contract does
not attempt: **the return-visit variant** (a different outcome at the same
hop for a different variant, which the v14 profile shape itself cannot
express without a per-variant outcome override or a fourth route - see
`docs/spec/mes/a_date_flow.md`'s own "The return-visit variant"), and
**in-document choices between sibling routes** (today, three sibling v14
routes of one group project as three separate v6 documents, each its own
`flow`; a consumer picking between them is the remake's own backlog, as v4's
own consumer is). The remake's own consumer for `flow` is likewise its own
backlog.
