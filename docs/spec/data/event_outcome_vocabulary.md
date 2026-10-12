# Event Outcome Vocabulary

Recorded 2026-09-20 (Core 0.351.0, EP-09) by owner ruling: the ending of an
event is named the way the player experiences it. Only the vocabulary
changed. The code-level markers of the analysis-group profiles, the catalog
rows and the v4 event definitions are unchanged, and nothing was
re-measured; a game outcome is derived from those markers by
`tools/event_outcome_vocabulary.py` and its GDScript port
`content_core/event_outcome_vocabulary.gd` (`KakyuEventOutcomeVocabulary`).

## The five outcomes

| Outcome | What the player sees | Extra fields |
|---|---|---|
| `map_return` | the event ends on a world map: the town (`MACHI.MES`), the campus (`GROUND.MES`), the train (`TRAIN.MES`) or a school floor (`FLOOR1.MES`..`FLOOR5.MES`) | `map` (the map's label); `postlude`: `event` when the event script hands the root to the map itself, `place` when the callee returned and the place script played its own lines or BGM before handing the root |
| `place_menu` | the place script shows its own menu again - the registered-definition choice a routine-40 record presents | - |
| `chain` | the flow continues straight into another script - another place or a date script - with no map in between | `next_target` |
| `not_triggered` | the event does not happen: the done gate returns at once, the guard is false, or the route rejects | `reason`: `done_gate` or `rejection_return` |
| `unresolved` | the measurement stops before an ending is known | `reason`: `dependency_stop`, `continuation_undeclared`, `reentry_undeclared`, `blocked_definition`, or the analysis boundary's status |

The record is `{outcome, postlude, next_target, map, reason}`; unused fields
are empty strings. The English phrase (`phrase`) is what the Event Player
shows at the end of catalog playback: "Back to the town map", "Back to
school floor 4 after the place's own lines", "Back to the place menu",
"Continues into K_DATE5.MES", "Not triggered", "Unresolved: dependency_stop".

## Derivation

### From a v4 event definition (`terminals[...]`, `results[...].terminal`, `results[...].reentry`)

| `kind` | `next_target` a map | otherwise |
|---|---|---|
| `root_handoff` | `map_return`, postlude `event` | `chain` |
| `natural_handoff` | `map_return`, postlude `place` | `chain` |
| `def_selection_boundary`, `caller_menu_loop` | `place_menu` | `place_menu` |
| `dependency_stop` at another event's intro dispatch (since 2026-09-23) | `chain`, `next_target` that event's callee entry | same |
| any other `dependency_stop` | `unresolved` (`dependency_stop`) | same |
| `callee_return` as a result's terminal | `unresolved` (`continuation_undeclared`) | same |

"Another event's intro dispatch" means the stop's own coordinate - its
`owner_entry` and `offset` - is exactly the `trigger.caller` entry and offset
of another v4 document (`event_intro_index`), so the flow the measurement
stopped in front of is that event starting (owner ruling of 2026-09-23, EP-03
step 2; the rule is a tool decision: it names what the run reaches, it does not
execute the next event).

A result's reentry with `message_count` 0 is `not_triggered` (`done_gate`);
with messages it repeats the route's own outcome (`repeat: true`); a
missing reentry block is `unresolved` (`reentry_undeclared`).

### From a catalog row (`terminals`, ordered by `sequence`, the last one decides)

| `kind` | outcome |
|---|---|
| `caller_handoff` to a map | `map_return`, postlude `place` |
| `root_replacement`, `normal_completion` to a map | `map_return`, postlude `event` |
| any of the three to a non-map target | `chain` |
| `analysis_boundary` with runtime status `def_selection_boundary` | `place_menu` |
| `analysis_boundary` with runtime status `loop_boundary` (since 2026-09-23) | `place_menu`: the catalog form of a `caller_menu_loop` resume, the place script's own input loop, which the v4 and profile rules already read as `place_menu` |
| `analysis_boundary` with runtime status `script_dispatch_boundary` and a `next_target` (since 2026-09-23) | `chain` into `next_target`; the promotion tool writes that `next_target` only when the stop is another row's intro dispatch, and the catalog loader rejects one that is not (`_validate_intro_chain_targets`) |
| `analysis_boundary` with another runtime status | `unresolved` with that status as the reason |
| `rejection_return` | `not_triggered` (`rejection_return`) |
| `early_return` | by its target like a completion; no map is `unresolved` (`early_end`) |
| `callee_return_only`, `caller_postlude` as the last terminal | `unresolved` (`continuation_undeclared`) |
| `prefix_end`, `unresolved_host_handoff` | `unresolved` (the kind) |

The Event Player applies the same rules to the one terminal it matched at
the end of catalog playback (`catalog_terminal_outcome`), with one exception
(EP-12 gallery, 2026-10-04, Core 0.369.0, tool decision;
`matched_terminal_outcome`): a matched `callee_return_only` terminal is the
callee's own return, and when the row also declares where its flow goes next
(its later terminals - an album scene's menu loop, the caller's handoff) the
row's route outcome above is decided, so that is the phrase - an album scene
reads "Back to the place menu" instead of "Unresolved: continuation_undeclared".
A row whose route outcome is itself `unresolved` (the callee return is its last
terminal) keeps the terminal's own reading, `continuation_undeclared`. Every
other kind reads as before. The tracked catalog has 365 album scenes and the
other callee-return-first rows (map handoff, chain or place menu after the
return) in this case; the GDScript port is checked against the Python snapshot
of route outcomes over every row.

### From an analysis-group profile route

`caller_outcome.kind` `root_handoff` / `nested_root_handoff`: by
`outcome.target` (map -> `map_return`/`event`, else `chain`).
`dispatch` with a `resume`: policy `natural_handoff` by the resume's target
(map -> `map_return`/`place`, else `chain`); `def_selection_boundary` and
`caller_menu_loop` -> `place_menu`; `stop_before_unprovided_dependency` ->
`chain` when the resume's stop (`caller.entry`, `resume.outcome.offset`) is
another event's intro dispatch (since 2026-09-23), otherwise `unresolved`.
`dispatch` without a resume -> `unresolved`
(`continuation_undeclared`); `blocked_definition` -> `unresolved`. A reentry
that returns with zero messages is `not_triggered` (`done_gate`).

A `kakyu_event_analysis_group/v14` flow route (an `origin`, `hops` and one
`terminal`; since 2026-09-24, EP-12) is classified by its `terminal`: a
`script_handoff_boundary` to a map -> `map_return`/`event` (the flow is the
event), to another script -> `chain`; a `script_return` -> `unresolved`
(`flow_return`) until a flow declares what its origin does next - except
(EP-12 gallery, 2026-10-04, tool decision) a two-hop flow whose first hop ends in
`script_dispatch_boundary` and whose second is a `nested_call` hop ending in
`script_return` (an album scene returning to its menu, and - EP-12 H, 2026-10-04 -
a recollection ladder returning to the protagonist's room, whose return chain
reaches the room-action menu again: `docs/spec/mes/43c_caller_group.md`; and - EP-12
TALK, 2026-10-04 and 2026-10-05 - a band-less conversation script at its caller when that caller resumes into
a day loop or a place menu with no natural end: the plain `<L>_TALK` scripts and the characters' `N_TALK`,
`N_TALK2`, `N_TALK3`, `O_TALK`, `P_TALK` and `Q_TALK1`, `docs/spec/mes/talk_family.md`):
`place_menu`, the origin resuming into its own input loop. A TALK rung is the other shape, and so are Tina's
`M_TALK`, `Q_TALK` and (measured 2026-10-05) `N_TALK1`: a three-hop flow (the caller to the call, the script to its
return, the caller resuming) whose `terminal` is a map handoff - `MACHI.MES` for the rungs, `M_TALK` and `Q_TALK`,
`FLOOR5.MES` ("school floor 5") for `N_TALK1` - so the handoff rule above reads it as
`map_return`/`event` (`tests/test_event_outcome_vocabulary.py` pins it); no vocabulary rule changed. A flow has
no reentry block - its origin guard decides each run - so its reentry is
`unresolved` (`flow_reentry_undeclared`). The 2026-09-20 census below
predates flows; with `01m-a-date`'s three routes the profile-route census
is map_return 185 / place_menu 34 / chain 13 / unresolved 2 and the reentry
census map_return 52 / chain 2 / not_triggered 143 / unresolved 37
(`tests/test_event_outcome_vocabulary.py`).

### The mod event definition contract (`kakyu_mod_event_definition/v1`)

Its two terminals already speak this vocabulary: `return_to_map` is
`map_return`, `continue_caller` is `place_menu` or `chain` depending on what
the place's remaining flow does. The contract is unchanged.

## Census over the tracked data (2026-09-20)

Measured by the CLI
(`py tools/event_outcome_vocabulary.py --v4-dir config/event_definitions/v4 --profiles-dir config/event_catalog/analysis_groups --catalog config/event_catalog/original_events_v1.json`)
and pinned by `tests/test_event_outcome_vocabulary.py`:

| Outcome | v4 results (231) | v4 reentries (231) | profile routes (231) | profile reentries (231) | catalog rows (142) |
|---|---:|---:|---:|---:|---:|
| `map_return` | 177 | 63 | 182 | 52 | 113 |
| `place_menu` | 39 | 9 | 34 | 0 | 20 |
| `chain` | 12 | 4 | 10 | 2 | 4 |
| `not_triggered` | 0 | 154 | 0 | 143 | 0 |
| `unresolved` | 3 | 1 | 5 | 34 | 5 |

Re-measured on 2026-09-21 after EP-10 unit 5: every one of the 142 catalog rows
is generated from its group (no hand-authored rows remain, so that column is
gone), and the v4 and profile columns follow the ten groups measured by unit
5a. The 2026-09-20 table read v4 results 162/39/12/0/17, profile routes
164/34/10/0/5, catalog rows 110/20/6/0/6 and hand-authored rows 11/1/0/0/1.
The censuses are pinned by the Python test.

The 17 unresolved v4 results are 14 callee returns with no declared
continuation and 3 dependency stops; the two counts of a route and its
document differ where a document folds a group's variants into fewer
results.

Re-measured on 2026-09-23 after the intro-dispatch rule (EP-03 step 2,
catalog revision 26). The census CLI now builds the intro index from
`--v4-dir` and applies it to the v4 and profile columns:

| Outcome | v4 results (231) | v4 reentries (231) | profile routes (231) | profile reentries (231) | catalog rows (142) |
|---|---:|---:|---:|---:|---:|
| `map_return` | 177 | 63 | 182 | 52 | 113 |
| `place_menu` | 39 | 9 | 34 | 0 | 20 |
| `chain` | 15 | 5 | 13 | 2 | 7 |
| `not_triggered` | 0 | 154 | 0 | 143 | 0 |
| `unresolved` | 0 | 0 | 2 | 34 | 2 |

The three moved routes are GROUND's H01 first (stop 6308, the intro of
`original/eventk01/ground-000018a4`), H01 repeat (16859,
`original/eventk01/ground-000041db`) and H02 first (7227,
`original/k_pic/ground-00001c3b`). The two unresolved profile routes are
the early `ground-h17-k09` v1 routes (a definition step limit and an
undeclared continuation); neither is its row's default route, which the
later arrival groups supply. The two unresolved catalog rows are EVENTC06
and EVENTE11 at `15C.MES`, whose last terminal is the caller's menu loop
(`analysis_boundary` / `loop_boundary`): the v4 and profile rules already
read that loop as `place_menu`. Later the same day the catalog-side rule
was aligned, so the catalog rows column reads map_return 113 / place_menu
22 / chain 7 / not_triggered 0 / unresolved 0 - every catalog row now ends
in a named game outcome.

Re-measured 2026-09-24 (EP-12 catalog part): `promote_analysis_groups.py`
promotes the `01m-a-date` flow's three routes to their own catalog rows
(145 rows total, catalog revision 29); each ends `script_handoff_boundary`
to `MACHI.MES`, so only the catalog rows column moves, +3 `map_return` -
map_return 116 / place_menu 22 / chain 7 / not_triggered 0 / unresolved 0.
The v4 results/reentries and profile routes/reentries columns are
unchanged from the previous measurement (the profile-side census already
counted these three routes, per the note above).

The code-level terms stay the evidence: "completion", "callee return",
"caller postlude", "handoff", "prefix end", "rejection" and "analysis
boundary" are what the validators check; the game outcome is what the
catalog, the Event Player and the trackers say about a route.
