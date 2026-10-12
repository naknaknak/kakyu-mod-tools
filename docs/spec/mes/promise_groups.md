# The Twelve Promises (`?_PROMIS.MES`) at the Station Site

EP-12 PROMIS unit (2026-09-25). Measured against the authoritative `mes.arc`
(`archive_sha256` `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`)
and the original executable (`AI5WIN.original.exe`) via
`tools/audit_mes_promise_callers.py` (`kakyu_mes_promise_callers_audit/v2`,
re-run for this unit), an archive-wide guard-flag writer scan
(`analysis/ep12_promis_guard_scan.py`, the pattern of `analysis/ep12_992_scan.py`),
and `tools/mes_route_decode.py`/`tools/draft_event_route_spec.py` static
decode of each `?_PROMIS.MES` entry. The per-heroine date/time-field,
location-field and ten-option accept/reject matrix cited below were already
**Confirmed** by prior audits recorded in
[Format and Method](format_and_method.md) ("Twelve authoritative PROMIS
entries...", `kakyu_mes_promise_location_routes_audit/v4`); this unit adds
the `01M.MES` station-site coordinate, the guard-flag writer class, the
callee's own two-question shape, the route-toolchain extensions
(`docs/spec/tech/content_tools.md`) needed to express and answer it, all
twelve `01m-<letter>-promis` groups registered and passing, and (Checkpoint
C) the full catalog/registry/v6/package regeneration - catalog revision 32,
187 rows - plus a playback-package-only replay gap the checkpoint found and
closed. No original dialogue is quoted.

## The station site (all twelve, one caller block)

All twelve `?_PROMIS.MES` dispatches sit as consecutive command-`0x0F`
literal calls inside the **same** `01M.MES` address-table entry (index 407,
intro offset 77660), one immediately after another, each guarded by its own
single-flag `global_u8[...] == 1` branch immediately before the call
(`tools/audit_mes_promise_callers.py`'s command-`0x0B` gate scan; exact
literal envelope `0F 01 <lowercase *_promis.mes> 00 00`):

| Heroine | Guard offset | Guard flag | Call offset | Resume offset |
|---|---:|---:|---:|---:|
| F | 78466 | `global_u8[1520]` | 78482 | 78503 |
| A | 79202 | `global_u8[1010]` | 79218 | 79239 |
| E | 79958 | `global_u8[1808]` | 79974 | 79995 |
| I | 80820 | `global_u8[1235]` | 80836 | 80857 |
| G | 81558 | `global_u8[1381]` | 81574 | 81595 |
| C | 82320 | `global_u8[1669]` | 82336 | 82357 |
| H | 83058 | `global_u8[2099]` | 83074 | 83095 |
| K | 83851 | `global_u8[2200]` | 83867 | 83888 |
| L | 84644 | `global_u8[1941]` | 84660 | 84681 |
| B | 85358 | `global_u8[598]`  | 85374 | 85395 |
| J | 86227 | `global_u8[803]`  | 86243 | 86264 |
| D | 87125 | `global_u8[721]`  | 87141 | 87162 |

These match `tools/audit_mes_promise_callers.py`'s `EXPECTED_GATE_BY_TARGET`
table exactly; A's site (79218, guard 79202, flag 1010) matches this unit's
own starting premise byte for byte.

### Guard-flag writers

Archive-wide scan of all twelve flags (`analysis/ep12_promis_guard_scan.py`,
1,016 entries, 620 hits, no decode failures): every flag is **cleared** (`=0`)
only by its own `?_PROMIS.MES` entry (the callee's own gate-cell write) and
**set** (`=1`) only by that heroine's own `?_TALKnn.MES` conversation
scripts - no other entry writes any of the twelve flags:

| Heroine | Flag | Setting `?_TALKnn.MES` scripts |
|---|---:|---|
| A | 1010 | TALK00, TALK40, TALK50, TALK60, TALK70, TALK80, TALK90 |
| B | 598  | TALK00, TALK60, TALK70, TALK80, TALK90 |
| C | 1669 | TALK00, TALK70, TALK80, TALK90 |
| D | 721  | TALK00, TALK60, TALK70, TALK80, TALK90 |
| E | 1808 | TALK00, TALK60, TALK70, TALK80, TALK90 |
| F | 1520 | TALK00, TALK60, TALK70, TALK80, TALK90 |
| G | 1381 | TALK00, TALK60, TALK70, TALK80, TALK90 |
| H | 2099 | TALK00, TALK70, TALK80, TALK90 |
| I | 1235 | TALK00, TALK50, TALK60, TALK70, TALK80, TALK90 |
| J | 803  | TALK00, TALK70, TALK80, TALK90 |
| K | 2200 | TALK00, TALK70, TALK80, TALK90 |
| L | 1941 | TALK00, TALK90 |

All twelve flags are also *read* (not written) by the forty place callers
(`01M`..`47C`) that dispatch the matching `?_PROMIS.MES`, per the same scan.
The writer class is therefore the heroine's own affection-banded
conversation ladder (the `TALK` family), consistent with the caller block
sitting directly after each heroine's own `?_TALKnn` dispatch ladder in
`01M.MES` (A's: 79031..79181, per this unit's starting premise). The exact
in-conversation condition that flips each flag (which affection band, which
dialogue choice) is not re-derived here; **unresolved**.

### The caller's resume (shared shape, all twelve)

Immediately after every call, `01M.MES` runs the identical boilerplate
(offsets differ per heroine, the instructions do not): `ROUTINE 27`,
`ROUTINE 25`, a `global_u8[2847] == 1` branch running `ROUTINE 21` on its
false edge, clears `global_u8[2836]`/`[3000]`/`[2841]`, a `global_u8[99] == 0`
branch running `ROUTINE 23` on its true edge, clears `global_u8[99]`, one
further `script_dispatch`, then `continuation_transfer -> 87590` - the same
target offset for all twelve. Traced by hand this continues through a long
shared, heroine-independent dispatcher keyed on `banked_u16[242]`/
`state_u16[7]` date bands. **Resolved by the route probe** (see "Checkpoint
A result"): under the declared seed, every heroine's resume is
`natural_handoff` to `MACHI.MES` after 6 messages, writing
`banked_u16[1]=7`, `banked_u16[242]=1`, `global_u8[286]=1` (constant across
every route of every heroine) - a `kakyu_event_analysis_group/v5` policy.
This is the resume for the *declared seed* specifically; the other date
bands the hand trace found (89451 onward) are not this unit's route and
remain unexplored.

## The callee: two cascaded questions, not one

Every `?_PROMIS.MES` entry (decoded via `tools/mes_route_decode.py
--summary`) has **exactly two** `routine-40` sites, confirmed for all twelve:

| Heroine | Location question (offset) | Time question (offset, hex) | Callee return |
|---|---:|---:|---:|
| A | 2221 | 11371 (`0x2C6B`) | `0x5BF7` |
| B | 2119 | 12168 (`0x2F88`) | `0x5036` |
| C | 1914 | 9813 (`0x2655`)  | `0x463E` |
| D | 2208 | 10022 (`0x2726`) | `0x4768` |
| E | 2093 | 10263 (`0x2817`) | `0x4866` |
| F | 1921 | 10395 (`0x289B`) | `0x48C8` |
| G | 2324 | 12564 (`0x3114`) | `0x51D5` |
| H | 2102 | 10325 (`0x2855`) | `0x4960` |
| I | 2016 | 12345 (`0x3039`) | `0x5168` |
| J | 2224 | 10269 (`0x281D`) | `0x48C2` |
| K | 2405 | 11419 (`0x2C9B`) | `0x4E1E` |
| L | 1916 | 9973 (`0x26F5`)  | `0x4838` |

The **location question** (first) always executes (after the guard-flag
check, an entry gate on `global_u8[15]`/other flags this unit did not fully
enumerate, and one affection-banded (`banked_u16[<affection_cell>]`)
presentation ladder); it presents up to 15 place options, each individually
gated by its own `global_u8[10+n] == 0` "not yet used" flag and, for some
options, a compound "some time slot still open" check, and writes the chosen
index into `global_u8[<location_field>]`. This is the "the place cell"
this unit's starting premise named at offset 470 (`global_u8[119] == 15`
for A).

The **time question** (second, "the place question" in this unit's starting
premise, matching its offsets 11301-11401 for A) is the already-Confirmed
ten-option selector documented in [Format and Method](format_and_method.md):
each of the ten `command_10` option labels (HHMM 0900..1800) is itself
conditional on its own success flag `global_u8[610+n] == 0` (an option
already promised once is not relabelled), and each option's acceptance of
the *already-chosen* location is fixed by the shared 15-writer/10-option
matrix. Selecting an accepted option writes the paired day/time fields,
sets its success flag, and returns to the caller; selecting a rejected one
plays a rejection dialogue and loops back to the same selector.

### The location question is a real answered menu, not a bypassable default

Earlier drafts of this document assumed a route could seed `global_u8[<location_field>]`
directly and skip the location question. Sandbox replay disproves that: the
location question's own code (993-2261 for A) runs on *every* visit
regardless of the field's initial value, so its `routine-40` boundary must
actually be answered for the walk to continue past it at all. The
`kakyu_mes_routine40_choice_contract/v5` consumer is a **one-based
registration-position chain** (`consumer_kind: one_based_state_u16_21_branch_chain`,
comparisons `state_u16[21] == 1, 2, ..., N-1` with the last position as the
implicit fallback), not a comparison against the definitions' own ids - and
the catalog can be **sparse** (some ids hidden under the seed), so position
and id diverge exactly where a hidden id sits below them.

**Measured by replay** (`tools/content_suite/cli/measure_event_route.gd`,
the `callee_prefix_choices` mechanism this unit added - see "Toolchain
fixes"): under the declared seed (guard flag `= 1`, date `0401`, all
place-used and time-success flags fresh), `A_PROMIS.MES:2221` registers ids
`0..7,9..13` (id `8` hidden - needs date `0720..0829`, per
`format_and_method.md`'s sparse-catalog measurement). Position `K` (1-based,
registration order) therefore selects the `K`-th **smallest offered id**:
positions `1..8` -> ids `0..7` (contiguous, no gap yet), position `9` -> id
`9` (id `8`'s gap skipped), positions `10..13` -> ids `10..13`. Two
positions were replayed directly to confirm this rather than assumed:
- **Position 1 (id 0)**: plays that place's own dialogue, then **loops back**
  to the same `2221` boundary with id `0` now hidden (its own
  `global_u8[10]` "already shown" flag set) rather than continuing to the
  time question. A second such loop (from whatever position is now lowest)
  would need its own reply, and nothing in this unit's evidence says how
  many times this can repeat or what, if anything, terminates it natively;
  **unresolved**.

  **Re-ask confirmed (EP-12 leftovers unit, 2026-09-26, Core 0.368.0)**:
  replayed once more with the fixed tool (re-runnable as part 2 of the archive-tier check "original EP-12 re-entry probes", `tools/content_suite/validators/validate_ep12_reentry_probes.gd`),
  answering position 1 names exactly where the loop returns - the first
  stop (no answer given) is an unanswered choice at boundary `0x8AD` (2221,
  decimal) after 6 messages, and with position 1 answered the walk reaches a
  second occurrence whose own routine-40 error names the identical offset
  `0x8AD`, not a different site - confirming this is a rejection-and-re-ask of **the same
  question** (the shape `format_and_method.md`'s own v10 `caller_menu_loop`
  already names for a caller's own routine-40, here inside a callee instead),
  not a second, distinct route. 21 messages accumulate by the second
  occurrence (the check reports 6 at the first stop and 21 at the second;
  the first place's own dialogue plus the boilerplate around it). A further
  declared answer at this second occurrence cannot be measured past the stop
  itself: `KakyuMesRoutine40ChoiceContract.build()` fails validating it
  (`"Routine-40 sparse catalog's leading gap has no supporting gate-branch
  landmark"`) - an unrelated, pre-existing sparse-catalog edge case (hiding
  the catalog's own *first* id specifically, rather than a middle one like
  id `8`'s own gap, which the same builder already handles) this unit did
  not fix; named here as an out-of-scope defect, not worked around. No
  declaration follows from this finding, per the task's own instruction -
  it names the shape, not a route.
- **Position 3 (id 2)**: plays its own dialogue, continues straight through
  the shared date-owner intro (`ROUTINE 24` at the entry-specific
  coordinate) to the declared time question with **no loop** - and id `2`
  is exactly the archive's own already-Confirmed "location 2" value the
  controller-integration audit used because all ten time options accept it.

Every declared `01m-<letter>-promis` route therefore answers the location
question at **position 3** (`callee_prefix_choices: [{"boundary": <site>,
"result_value": 3}]`, `tools/draft_event_route_spec.py`'s new default),
which the sandbox confirms writes `global_u8[<location_field>] = 2` for
every heroine and reaches the time question in one pass. Position 1 (id 0)
is named here as a genuine, replay-confirmed departure from a simple
"answer once" model, not declared as a route of its own.

### The time question: baseline and what it offers

Per heroine: guard flag = 1 (own flag from the site table), location
question answered at position 3 (id 2, above), affection cell unconstrained
(the location question's own affection ladder gates presentation text only;
this unit's decode and replay both show the time question's accept/reject
driven solely by the location field).

Under location = 2, the shared matrix (already Confirmed archive-wide in
[Format and Method](format_and_method.md)'s controller-integration audit)
accepts **all ten** options for every heroine - location 2 is in every
option's accepted set - so no option is hidden by the location/time matrix
itself. Each accepted route writes `banked_u16[<day_field>] = state_u16[10]`
(the composed date), `banked_u16[<time_field>] = ` its HHMM, sets
`global_u8[610+n] = 1`, and returns at the heroine's own callee-return
coordinate above.

**A only** has a further gate on options 8-10 (HHMM 1600/1700/1800):
`global_u8[1060] == 0` guards a `state_u16[7]==0824 && location==14`/
affection(`banked_u16[201]`)-threshold-100 decision before the shared
location predicates. Replayed under this unit's own seed (location 2, date
`0401` - neither matches the special date/location pair), the callee did
not reach a terminal within the measurer's own segment budget for options 8,
9 and 10 (`"segment limit reached in A_PROMIS.MES"` after 1,025 messages) -
measured and named `unresolved` in `01m_a_promis_v5.json`'s own per-route
field rather than declared, exactly as the toolchain's existing "measured
and not declared" rule handles any answer whose run does not reach a
terminal. No other heroine's decode or replay shows this extra gate; B..L
each declare all ten options.

**Resolved (EP-12 leftovers unit, 2026-09-26, Core 0.368.0)**: reaching
options 8-10 needs the archive's own confirmed methodology - explicitly
setting the latch `global_u8[1060] = 1` before the callee runs, per
[Format and Method](format_and_method.md)'s own controller-integration audit
("For A-entry options 8..10 it explicitly sets the separately audited latch
1060 rather than inferring it from location"). Declared with that latch
write added to the route's own baseline (`tool_seeded`, basis: the
Confirmed first-pass writer - the low/date/high gate probe that sets
`global_u8[1060] = 1` on its own eight-dialogue-boundary high branch), all
three options now succeed in one pass, exactly like B..L's own ten: each
writes its own paired time (`banked_u16[0][216]` = 1600/1700/1800), sets its
own success flag (`global_u8[617]`/`[618]`/`[619]`), and returns at the same
callee-return coordinate `0x5BF7` every other A option uses. The scan behind
this unit's own guard-flag-writer paragraph above also found `[1060]` written
by `A_TIME.MES` (one site) in addition to `A_PROMIS.MES`'s own three latch
sites - the date's own time hop (the shared-prefix dispatch every route
measurement already passes through) sets the same latch - and read by
`A_DATE3`, `A_DATE7`, `A_TIME`, `A_PROMIS` and the seven `A_TALK` scripts.
The latch therefore has a natural writer *inside the date itself*, not only
inside `A_PROMIS.MES`'s own two-pick retry: a promise made after a date needs
no double pick to reach options 8-10, since the date's own time hop already
sets `[1060] = 1` along the way. The natural path this unit's own baseline
seed and the archive's own controller-integration audit both use - two picks
of the same option, from `[1060] = 0` - is the path that needs the retry;
the `A_TIME.MES`-primed path does not. A's own check count moved from 829 to
1,006 with the three new routes (`checks` field, `validate_event_analysis_group.gd`).

## Checkpoint A result: all twelve routes registered and passing

All twelve `01m-<letter>-promis` groups are drafted, measured, built,
audited, validated and registered
(`config/event_catalog/analysis_groups/01m_<letter>_promis_v5.json`, checks
`original event analysis 01M <LETTER> promise`). A: 7 routes as of this
unit's own Checkpoint A/C landing (options 8-10 unresolved, above), 829
checks; B: 906; C: 862; D: 970; E: 934; F: 862; G:
934; H: 862; I: 1,006; J: 862; K: 1,078; L: 718 (B..L: 10 routes each). **The
EP-12 leftovers unit (2026-09-26) closed A's own gap**: A now declares all
ten routes (829 -> 1,006 checks) - see "A only has a further gate" above.
Every route's caller resume is `natural_handoff` to `MACHI.MES` (6
messages, `banked_u16[1]=7`, `banked_u16[242]=1`, `global_u8[286]=1`
constant across every route of every heroine); every reentry is 0 messages
(the callee's own `script_return` record replayed directly). All three
mutations (message-count+1, outcome-offset+1, resume-outcome-offset+1) fail
as required. `--check "original event analysis groups"`: 173/173 passed
(the twelve new ones among them); `--check "original catalog group routes"`:
4/4 shards passed; `--check "original playback package export"` and
`"...playback"`: passed, 175 rows (unchanged - see "Checkpoint B", below);
`--check "original Event Player fragment catalogs"`, `"original Event
Player PROMIS scheduling routes"` and `"original Event Player nested PROMIS
callers"`: passed. Local-tier suite: 134/135 (the one exception is the
registry premise below, by design).

## Toolchain fixes (both now resolved; history below)

`tools/draft_event_route_spec.py` drafted all twelve routes cleanly from
static decode alone (`--question-offset`, added by this unit, selects the
*time* question and scopes its own `definitions` to the span after the
*location* question, since the existing single-`routine40` `callee_question`
field and the generic `definitions` scan both assume one selector per
callee). Every drafted `analysis/01m_<letter>_promis_spec.json` and its
review sheet exist as measured, decode-only evidence.

`tools/qualify_event_route.py` / `tools/content_suite/cli/measure_event_route.gd`
could not run a route past that point, for two separate reasons found in
sequence:

1. The probe's `_select_choice` requires a declared
   `{owner_entry, boundary_offset, option}` for **every** `def_selection_boundary`
   it walks through, and the spec schema had no field for an earlier,
   undeclared routine-40 before the one named `callee_question`. Run
   unmodified against heroine A's spec (`py tools/qualify_event_route.py
   --elfimage "<ELFIMAGE>" --spec
   analysis/01m_a_promis_spec.json`), the probe subprocess did not fail fast:
   it stopped consuming CPU after about two minutes forty seconds and did not
   exit until `qualify_event_route.py`'s own 900-second `subprocess.run`
   timeout fired and cleaned it up (`TimeoutExpired`, no orphaned process -
   confirmed by `tasklist` immediately after). This unit added a generic,
   minimal fix, since all twelve heroines share the exact same two-question
   shape: a new spec field `callee_prefix_choices` (`tools/draft_event_route_spec.py`
   auto-populates it from any routine-40 earlier than `--question-offset`,
   defaulting to `result_value: 0` - the archive's own already-Confirmed
   "untouched location 0" baseline) and, in `measure_event_route.gd`, folding
   those fixed answers into the same `caller_choices` list every run already
   consults, plus filling in one previously dead `if entry == callee and not
   caller_choices.is_empty(): pass` branch in `_contract()` that had never
   actually forwarded the choice list into the callee's own contract-discovery
   walk (a no-op for every existing caller-choice-only group, since a
   caller-owned selection's `owner_entry` never matches while walking the
   callee).
2. With that fix, the probe now resolves the location question's boundary
   (offset 2221 for A) as intended and reports it in `segments`, but the
   contract build at that boundary itself then fails:
   `content_core/mes_routine40_choice_contract.gd` reports "Routine-40
   definition identifiers do not match the supported stored form" at 2221.
   The location question's own 15 options are each declared by their own
   individually-gated `branch_if_not_true` + `definition_invoke` (own writer
   for `global_u8[10+n]`), not the uniform run of `command_1b`/`command_10`
   pairs immediately before the `routine-40` that the time question (and
   every existing precedent group's own question) uses; the contract parser
   does not recognize this second shape. Extending
   `mes_routine40_choice_contract.gd` to parse it is a materially larger,
   riskier change to a shared runtime primitive than this unit's scope
   supports safely without its own dedicated verification; **unresolved**,
   named here as a route-toolchain defect for `todo/code_health.md`.

   **Resolved 2026-09-25** (EP-12 routine-40 sparse catalog, Core 0.366.0):
   the diagnosis above overestimated the needed fix. `build()` never
   inspected *how* a place was declared, only *which* `definitions` the
   interpreter's own execution trace already reported; the individually-gated
   declaration shape needed no new parsing at all. The actual and sole
   blocker was the equality check `definition_id != index`, which assumed a
   contiguous `0..n-1` catalog. `kakyu_mes_routine40_choice_contract/v5`
   instead accepts a strictly-increasing, possibly-sparse id list (every id
   inside `0..16`) and records `catalog_form`, `hidden_ids`, and per-hidden-id
   `hidden_gates` (the exact gate-branch record a static byte walk finds,
   keyed by each candidate's own DEF selector rather than position). Measured
   live under the location-0 baseline above, `A_PROMIS.MES:2221`'s picker
   registers ids `0..7,9..13` (`hidden_ids: [8]`, gate `1587..1636`); its
   consumer at `2236` is the unmodified plain one-based chain -
   `consumer_kind: one_based_state_u16_21_branch_chain` - so no consumer
   extension was needed either. This closes the route-toolchain defect named
   here. It does not itself register a `01M <letter> promise` analysis group
   or catalog entry - producing the group profile, the check, the catalog
   row, and Checkpoint B's regeneration below remains separate, unstarted
   work. See `docs/spec/mes/format_and_method.md` (the v5 schema paragraph).

Both fixes (kept) plus one more this unit added get every route all the way
through: `tools/build_event_route_profile.py` binds the callee-owned prefix
choice into `choice_contracts`/`selections` (`_contract()`'s new
`callee_prefix_contracts` output, mirrored the same way `caller_choice`
already is), and `tools/draft_event_route_spec.py`'s default
`callee_prefix_choices` answer moved from position 1 (id 0 - measured to
loop, above) to position 3 (id 2, the archive's own "location 2" baseline).
All twelve heroines' probe/build/audit/validate/mutation-test/register steps
now pass end to end - see "Checkpoint A result" above. `tools/register_analysis_group.py`
itself needed a fix along the way: it still edited
`tools/content_suite/run_headless_validation.py`'s (pre-TD-32) tuple table,
which no longer exists (checks became data, `config/validation/checks_v1.json`,
2026-09-21); it now inserts an `analysis_group`-family entry into that
registry directly, verified against the fixed test
`tests/test_event_route_tools.py::RegisterTests`.

## Checkpoint B: registry regenerated, then reverted; catalog blocked

`tools/build_event_names.py --profiles config/event_catalog/analysis_groups
--catalog config/event_catalog/original_events_v1.json --out
config/contracts/event_names_v1` (`EXPECTED_PAIR_COUNT` moved 142 -> 154)
regenerates cleanly: twelve new ids join
(`<heroine>.town.station.promis.1`, e.g. `miko.town.station.promis.1` "Miko
at the station (A_PROMIS)"), each carrying `aliases.groups` naming its own
`01m-<letter>-promis` group and route ids; the 175 existing rows are
otherwise unchanged. This was measured and then **reverted** rather than
committed, for two compounding reasons:

1. **Catalog promotion needs a v4 document that must not exist.**
   `tools/promote_analysis_groups.py`'s ordinary (non-flow) path builds a
   catalog row from `config/event_definitions/v4/<id>.json`
   (`load_v4_documents`/`build_row`); a flow route bypasses this via its own
   `generate_flow_rows` branch, but PROMIS is the ordinary path by this
   unit's own instructions, and `config/event_definitions/v4/` stays frozen
   "beyond the names_fingerprint carry" - a genuinely new site's v4 document
   is new content, not a fingerprint carry. Without a promoted catalog row,
   `tools/content_suite/playback_package_export.gd`'s analysis-group member
   binding (`analysis_group_members`, restricted to profiles a catalog event
   references by `payload_sha256`) never includes the twelve `?_PROMIS.MES`/
   `?_OUTRO.MES` members, so neither the package export nor
   `tools/project_event_definition_v6.py --site` (which reads the member's
   exported event JSON) can proceed for these twelve ids.
2. **The "names_fingerprint carry" itself could not be safely reproduced.**
   Regenerating the registry moves `names_fingerprint`, which every tracked
   v4/v5/v6 document (and each version's `index.json`) also records and is
   checked against live (`tests/test_event_definitions_tracked.py`); the
   sanctioned fix is to re-run the v4/v5/v6 batch projector for the
   *existing* ids so only that one field changes. Attempted for v4
   (`tools/project_event_definitions_batch.py --contract v4`, 142/142
   existing ordinary sites re-projected successfully against a freshly
   exported package plus copied reference witnesses/replays), the result was
   **not** fingerprint-only: the fresh package's own `package_sha256`
   differed from the one recorded in the tracked documents, and every
   `shift_witness`-based effect that depended on matching it came back
   `"no matching shift witness"` instead of its recorded value - real content
   loss, not a safe carry. This unit could not identify what produces the
   tracked documents' exact reference `package_sha256` (no cached raw package
   export directory exists to diff against), so it declined to install a
   regeneration that silently drops measured effect data.

Both changes were reverted (`git checkout --
config/contracts/event_names_v1/ tools/build_event_names.py`) rather than
committed in a state that either breaks the frozen-fingerprint contract or
corrupts tracked witness data. The local suite's own
`test_event_names_registry.EventNamesRegistryTests.test_regeneration_is_byte_identical`
now fails loudly and precisely as a result - `BuildError: premise mismatch:
expected 142 distinct (callee, caller) pairs, measured 154` - naming exactly
this unfinished step for whoever completes it, rather than silently drifting.
Checkpoint B's catalog rows, `EXPECTED_CATALOG_COUNT` move, classification
(measured: `tools/refresh_route_classification.py` reports no bound/moved
change from the twelve PROMIS groups - they are command-`0x0F` sites, not
the classifier's own root-handoff EVENT dispatches), v6 documents, package
export and `names_fingerprint` carry therefore did not happen. See
`analysis/_undoc/ep12_promis_report.md` for the full accounting.

## Checkpoint C: the regeneration completed

Both blockers named above had answers this unit had not found. **(1)**
`tools/promote_analysis_groups.py`'s document source is the *live* v6
definition set, not the frozen v4: `--definitions-dir` (alias `--v4-dir`)
now defaults to `config/event_definitions/v6`, proved byte-identical for
the 175 pre-checkpoint rows before any new one was added (`--check`, 175
generated, byte-for-byte; a v6 document's own `flow` block is skipped in
`load_v4_documents` - `generate_flow_rows` already promotes those rows
separately). *Note, 2026-10-08 (WD-21 U2 C5):* the promoter's default definitions directory is now
`config/event_definitions/v7` and it refuses a set that is not v7 (a v6 set would regress every
row's `resources` to `[]`); the v6 set is frozen at the WD-21 U1 package. **(2)** The names_fingerprint carry into v4/v5 is a field
patch of that one line in every document and index, exactly as the
2026-09-24 and C..L-batch revisions already did - the Checkpoint B
`--contract v4` re-projection attempt was the wrong operation.

What Checkpoint B had not anticipated: a genuinely new *ordinary* site's own
document still has no v4/v5 document to promote from, so it exists only as
v6 - but producing it needs its own callee (`?_PROMIS.MES`) and
`?_OUTRO.MES` exported into a package, which needs a catalog row, which
needs the document itself. A flow route never hits this (its row and
document both come straight from its profile). Resolved with a new, scratch,
explicitly opt-in package-export option, `--include-unbound-groups`
(`tools/content_suite/playback_package_export.gd`): the catalog-reference
restriction on analysis-group membership already lifts when its own
`events` argument is empty (an existing, documented code path); the option
threads that emptiness through for group membership alone while
`catalog_members` keeps reflecting the real selected events, so a plain
export is unaffected (`tests/test_playback_package.gd`, 72/72 unchanged
before/after).

Sequence run: registry regenerated (154 pairs, twelve new
`<heroine>.town.station.promis.1` ids) -> a bootstrap package exported with
`--include-unbound-groups` (175 events, 371 member entries, 173 analysis
groups bound, the twelve PROMIS/OUTRO members present for the first time)
-> the twelve v6 documents projected against it
(`project_event_definition_v6.py --site <id> --contract v6`, ordinary path,
all twelve `ok`) -> `promote_analysis_groups.py` promoted the real catalog
rows from them (187 rows, `CATALOG_REVISION` 32,
`original/<letter>_promis/01m-<hex8>`) -> the *standard* package
re-exported, no bootstrap flag needed once the catalog referenced the
twelve groups (187 events, 371 member entries, 173 analysis groups bound)
-> all 187 v6 documents plus `index.json` regenerated against it
(`projected=187 valid=187 invalid=0`; every one of the 175 pre-existing
documents differs from its prior committed version only in
`names_fingerprint` and `package_binding.package_sha256`, confirmed on a
sample) -> names_fingerprint carried into v4/v5 as a field patch (142
documents each, plus each version's `index.json`).

**A second, independent gap then surfaced**, in the playback-package-only
replay path rather than this checkpoint's own (archive-backed) toolchain:
`original playback package playback` reported 187 rows, 12 stopped - all
twelve PROMIS rows - because `KakyuPlaybackPackageCodeSource` cannot
fingerprint an arbitrary gate-branch byte range the way the sparse-catalog
`hidden_gates` computation asks for (only a definition's own recorded body
range and the whole-code range are available from a package). Since that
hash is an audit aid (`tools/audit_event_analysis_group.py` always
re-verifies it against the archive, never the package) and no downstream
execution reads it, `mes_routine40_choice_contract.gd`'s `build()` now
records `RANGE_UNAVAILABLE` there instead of refusing the whole contract
when the code source cannot supply a real hash - inert for every
archive-backed caller (`tests/test_mes_routine40_choice_contract.gd`, 39/39
unchanged). No playback-package schema field changed, so no
`kakyu_playback_package` version move was needed. Full details:
`docs/spec/mes/format_and_method.md`'s own checkpoint-C addendum to the v5
schema section.

Every pin moved (before -> after): `tools/build_event_names.py`
`EXPECTED_PAIR_COUNT` 142 -> 154, `EXPECTED_CATALOG_COUNT` 175 -> 187;
`tools/promote_analysis_groups.py` `CATALOG_REVISION` 31 -> 32;
`tests/test_promote_analysis_groups.py` row count 175 -> 187;
`tests/test_event_outcome_vocabulary.py`'s `test_catalog_rows_census`
map_return 143 -> 155 and its GDScript sibling's `PYTHON_CATALOG_ROUTE_OUTCOMES`
snapshot (175 -> 187 rows, all twelve `map_return`/`place`);
`tests/test_event_catalog.gd` (`catalog_revision` 31 -> 32, four counts 175
-> 187); `tests/test_event_player.gd` (two counts 175 -> 187, the mahoko
character filter 8 -> 9); `tests/test_playback_package.gd` (two counts 175
-> 187); `config/contracts/event_names_v1/README.md`,
`config/event_definitions/v4|v5|v6/README.md` (new revision entries; v6's
own `contract_fingerprint`/`cells_fingerprint` unchanged,
`names_fingerprint` and `package_sha256` moved). `names_fingerprint` moved
twice more in this checkpoint (once for the registry's own twelve rows,
once more after promotion attached their `catalog_event_id`, and once more
again after this document's own final revision text was written, since this
directory's own fingerprint covers its README too - only the truly final
value, computed last, is recorded in the committed `names_fingerprint`
file and not restated in prose here, the same reason the C..L-batch and
this checkpoint's own registry README entries do not quote a "final" value
either).

Validation (counts re-read from saved report JSONs): local tier 135/135;
with the archive, `original event analysis groups` 173/173 (unchanged from
Checkpoint A), `original catalog group routes` 4/4 shards, `original Event
Catalog source bindings`, `original Event Player fragment catalogs`,
`original playback package export`, `original playback package playback`
(187 rows: 164 reached a terminal, 20 ended at a declared place menu, 3
continued into the next event, 0 stopped).

## Equivalent sites

Each heroine's `01M.MES` station site is one of 500 command-`0x0F` PROMIS
dispatches from 146 address-table owners across 66 caller entries archive-wide
(`tools/audit_mes_promise_callers.py`, `kakyu_mes_promise_callers_audit/v2`);
this unit measures only the `01M.MES` (station) site per heroine, per the
owner ruling. The other ~40 per-heroine sites are recorded there as
equivalent sites, not rows here.
