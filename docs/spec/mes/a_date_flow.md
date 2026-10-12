# Heroine A's Promise Date: Shared Guard, Multi-Hop Flow, Three Endings

EP-12 (2026-09-24). Measured against the authoritative `mes.arc`
(`archive_sha256` `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`)
by static reads (`tools/mes_route_decode.py`) and Godot runtime probes through
the shared call frame (`content_core/mes_route_probe.gd`), one nested-call
hop at a time (a fresh top-level `probe.run_route` call per hop, the same
technique `docs/spec/tech/content_tools.md`'s v14 flow shape's own runtime
validator uses). No original dialogue is quoted. This document records what
the probes established; it is evidence for a future `kakyu_event_analysis_group/v14`
declaration, not that declaration itself - see "Not established" below for
why the declaration is deferred.

## The promise

`A_PROMIS.MES`'s productive entry is the label at code-relative `0x2036`
(8246), not offset 0 (offset 0 is a bank of special-day early-return
guards). Entering there with a canonical seed (clock `1530`, `state_u16[7]=501`),
the script writes `state_u16[10] = state_u16[7]`, calls a shared-library
routine that advances the date by one day (`501 -> 502`), then answers its
own 10-option `promise_time` routine-40 at `0x2C6B` (11371). Option 1 writes
`banked_u16[216] = 900` and `global_u8[610] = 1`; the location cell
`global_u8[119]` is not written by `A_PROMIS.MES` itself (preset separately,
by whatever applies the promise's chosen place).

## The shared date guard and the seven-part pass

All 11 weekday/place callers (`01M`, `02M`, `04M`, `06M`, `09M`, `10M`, `17M`,
`18M`, `19M`, `20M`, `21M.MES`) share one guard shape, shown here for
`01M.MES` at code-relative offset 10999 (end 11088, false target 12656):

```
(state_u16[7] equal banked_u16[215])
  and (global_u8[110] equal 1)
  and (global_u8[117] equal 2)
  and (state_u16[19] equal banked_u16[216] OR state_u16[19] greater_than banked_u16[216])
  and (global_u8[119] greater_than 8)
  and (global_u8[119] not_equal 14)
```

`banked_u16[215]`/`[216]` are the promise's own written date/time (field
215/216 for heroine A, per `validate_event_player_promise_dates.gd`'s
`CASES` table). `global_u8[110]`/`[117]` are a separate two-flag pair
(`analysis/_undoc/ep12_date_prereq_report.md` Part B): flag `110`
("today is on/after the promised date") and flag `117` (a three-stage
0/1/2 cell a reminder conversation raises to 2, consumed back to 0 by the
accepting caller) are written by `LIBLARY.LIB`'s own per-heroine block and
the heroine's numbered `?_TALKnn.MES` conversations, not by the promise or
the caller itself - their own natural trigger (routine ID, caller) is not
traced here; both are seeded directly (`tool_seeded`) for this measurement.

Once the guard accepts, the *same caller* runs, unconditionally, in this
order (all nested calls, each returning to the caller before the next):
`A_PIC.MES` -> `A_DATE1.MES` -> `DENSHA.MES` (only if
`global_u8[119] greater_than 8 and not_equal 14`, guaranteed once the outer
guard passed) -> `A_TIME.MES` -> a location-flavor block -> `A_DATE2.MES` ->
a second location branch -> `A_DATE3.MES`, whose own internal branching
supplies the flow's three endings.

## DENSHA.MES and TRAIN.MES: a route-probe technique, not a code change

`DENSHA.MES`'s own entry-zero path is an unconditional nested call into
`TRAIN.MES` (a MAP-family hub, `docs/spec/mes/format_and_method.md`'s
address-table entry `DENSHA.MES:0x00AA`/170), then, after `TRAIN.MES`
returns, five of its own routine-40 sites (`0xA5C`/2652, `0x1E91`/7825,
`0x32FB`/13051, `0x54C5`/21701, `0x7B02`/31490), each already confirmed
buildable as a one-based chain or gated matrix by
`content_core/mes_routine40_choice_contract.gd` (`analysis/_undoc/ep12_hotel_menu/ep12_hotel_menu_report.md`).

Driving the whole thing (`DENSHA.MES` entry through `TRAIN.MES` and back)
as **one** `probe.run_route` call - supplying `TRAIN.MES`'s own
`map_locations` contract (`{"entry": "TRAIN.MES", "poll_offset": 886,
"result_storage": "state_u16", "result_index": 18, "values": [0, 1]}`) and
letting the walk continue past `TRAIN.MES`'s return - reproduces the
"resume carries no registered definitions" gap `ep12_hotel_menu_report.md`
already diagnosed: `DENSHA.MES`'s own first routine-40 at 2652 reports "no
catalog choice", even though the contract itself builds cleanly. Splitting
the leg into **three** separate top-level hops instead - `DENSHA.MES` (0)
to its own dispatch into `TRAIN.MES` (a `script_dispatch_boundary`,
offset 170, end 183), `TRAIN.MES` (0) to its own return (with the
`map_locations` contract), and `DENSHA.MES` resumed fresh at coordinate 183
- lets `DENSHA.MES`'s own routine-40 at 2652 resolve normally (one-based
chain, values `[1, 2, 3]`), because each hop's own run starts fresh and
registers its own local `DEFINITION` records before reaching its own
boundary. This is a tool/probe-usage finding, not a code change: no tracked
file was edited to produce it.

## Two selector sites, re-read (corrected 2026-09-24)

The first version of this page attributed two stops to a cross-file
`script_transfer` selector family (`ROUTINE27`/`25`/`21` after an
`argument_slot[1]` write). A full `definition_invoke` scan and direct replays
(`analysis/_undoc/ep12_a_date_blockers_report.md`, untracked) corrected both:

- **`A_DATE5.MES` stops at `DEF_MAIN.MES`'s registered definition 17**,
  invoked by a plain literal `definition_invoke` at `A_DATE5.MES:488` (the
  file's only two invocations are selector 17 at `488` and selector 11 at
  `527`, both before the `ROUTINE27` call at `601`; `ROUTINE27`'s body holds
  no invocation and `ROUTINE25`'s two are selector 26). Definition 17
  (registered at `DEF_MAIN.MES:3954`, body `3961..4285`) is a host wait: a
  loop `4118..4250` gated at `4222` by `state_u16[18] == 0` that re-issues
  native record dispatches and a system call until the host clears
  `state_u16[18]` - the same cell the train's map-location poll writes.
  With `state_u16[18] = 0` it returns at once; with 1 or 2 it never
  returns, so the route probe's step limit is the loop, not a large body.
  The v10 caller-menu-loop treatment cannot see it (the loop runs inside one
  definition run with no segment boundary); a supplied poll result, the
  way the station rides supply `Util(6,13)`, is the tool treatment this
  needs.
- **`01M.MES`'s location branch** (locations 9..13, `argument_slot[1]` =
  361/371/381/391/401 then `ROUTINE27`/`25`/`21`) is presentation flavour
  only - no invocation and no cross-file dispatch in any of the five arms -
  and every location, 9..13 or 15 and above, converges on the same shared
  tail into `A_PIC`, `A_DATE7` and `A_DATE3`. The earlier claim that
  location 9 "resolves into a registered definition inside `A_DATE3.MES` at
  13402" was a misattribution of that shared tail's own dispatch. Location
  15 (used by this measurement) is a tool convenience: only 9..13 carry
  flavour content, 14 is excluded by the guard, and `A_PROMIS.MES` neither
  presents nor writes the location - it is applied outside it.

established" rather than seeded around, per this task's own instruction.

## The three endings, as measured

Baseline for all three: the promise's own writes
(`banked_u16[215]=502`, `[216]=900`, `global_u8[610]=1`, `global_u8[119]=15`
- see above for why 15, not 9), the calendar/clock the guard needs
(`state_u16[7]=502`, `state_u16[19]=1530`), the two guard flags
(`global_u8[110]=1`, `[117]=2`, `tool_seeded`), and `global_u8[3004]=0` (the
`?_HOTEL.MES` routine-40 selector `ep12_hotel_menu_report.md` names).

**Shared prefix (all three routes), one hop per nested call/resume, message
counts from this measurement**: `01M.MES` origin to `A_PIC.MES` dispatch (0
msgs) -> `A_PIC.MES` (0 msgs, return) -> resume to `A_DATE1.MES` dispatch (0
msgs) -> `A_DATE1.MES` (13 msgs, return) -> resume to `DENSHA.MES` dispatch
(0 msgs) -> `DENSHA.MES` to its own `TRAIN.MES` dispatch (0 msgs) ->
`TRAIN.MES` (0 msgs, return, both queued map-location values consumed) ->
`DENSHA.MES` resumed at 183, answering its own routine-40 at 2652 with
value 1 (29 msgs, return) -> resume to `A_TIME.MES` dispatch (0 msgs) ->
`A_TIME.MES`, answering its own routine-40 at 1497 with value 1 (6 msgs,
return) -> resume to `YABAI.MES` dispatch (0 msgs) -> `YABAI.MES` (0 msgs,
return) -> resume to `A_DATE2.MES` dispatch (0 msgs) -> `A_DATE2.MES` (0
msgs, return) -> resume to `A_PIC.MES` dispatch (0 msgs) -> `A_PIC.MES` (0
msgs, return) -> resume to `A_DATE7.MES` dispatch (0 msgs) -> `A_DATE7.MES`
(18 msgs, return) -> resume to `A_PIC.MES` dispatch (0 msgs) -> `A_PIC.MES`
(0 msgs, return) -> resume to `A_DATE3.MES` dispatch (0 msgs) ->
`A_DATE3.MES` (nested from offset 0), where the three endings diverge.

**a-date-town** (`A_DATE3.MES`'s first routine-40 at 13402, answered case
1): 7 messages, `script_return` at 32377 (end 32378). Resuming `01M.MES`
there (its own dispatch-end coordinate, 12388, not any offset inside
`A_DATE3.MES`) runs 4 messages to its own dispatch into `A_DATE4.MES`
(12583); `A_DATE4.MES` runs 6 messages to its own return (2336); resuming
`01M.MES` reaches the flow's own terminal, an unconditional
`script_handoff_boundary` to `MACHI.MES` at 12633 (end 12646). Fully
measured, clean, and reproducible end to end.

**a-date-date5** (`A_DATE3.MES`'s first routine-40 answered case 2, with
`banked_u16[201]` - A's own affection cell - `tool_seeded` to 65, a gate
whose own natural writer is not traced here): 11 messages, a
`script_handoff_boundary` to `A_DATE5.MES` at 18414 (end 18429). Entering
`A_DATE5.MES` at offset 0 with the carried state stops at
`definition_step_limit` for definition 17 before reaching its own
`0x4D8`/1240 special-date gate or its own eventual handoff to `MACHI.MES` -
see "cross-file selector" above. **Not established past this point.**

**a-date-hotel** (`A_DATE3.MES`'s second routine-40, needed for case 3) -
**established 2026-09-24, correcting this page's two earlier readings**
(`analysis/ep12_date3_gate_decode.py`, `analysis/ep12c_hotel_natural_probe.gd`,
`analysis/_undoc/ep12c_hotel_natural.json`, untracked). The first question's
option 3 is offered while `global_u8[15] == 0` (`13317`); its case
(`20108`) then runs, in order:

- `20123`: a return-visit shortcut, `state_u16[12] < 150 AND global_u8[992]
  == 1` - a short scene, `global_u8[15] = 1`, back to the first question
  (`13147`), which now lacks option 3.
- `20442` / `20693`: too late - clock above `2130` (above `1830` on date
  `1224`): a short scene, `[15] = 1`, back to the first question.
- `21370`, `22504`, `23363`, `24318`, `25446`, `26229`: an **affection
  ladder** on `banked_u16[201]` at 51 / 61 / 71 / 81 / 91 / 111. Every band
  below 111 plays its own scene (a `ROUTINE 23` music call, `global_u8[99]`,
  `[994]`, `[1014]` set, an affection deduction fork such as `22434`) and
  **ends the date** at the plain return `32377`. Only affection **111 and
  above** reaches `27066`.
- `27066`: `global_u8[992] == 0` (first visit) falls into the scene
  `27082..27888` (a `state_u16[19] < 1700` variation at `27082`) and then
  the **place menu**: `27905` resets the option catalog (`command_1b`),
  `27915` / `27980` / `28039` add options 0 / 1 / 2 (`command_10` records)
  **while** `global_u8[11]` / `[12]` / `[15]` are still `0`, and `28100` is
  the second routine-40. Cases 1 and 2 (`28110`, `28474`) play their place,
  set `[11]` / `[12]` (`28426`, `29018`) and return to `27888` for the
  smaller menu (to the first question via `31490` once all three are set).
  Case 3 (`29066`) needs `state_u16[12] >= 150` (`29081`; below it a scene,
  `[15] = 1`, back to the menu) and the same two lateness checks (`29418`,
  `29705`), then writes, `ROUTINE 33/25/23`, **definition 17 at `31031`
  and definition 11 at `31070`**, `ROUTINE 32/20`, and the handoff to
  `A_HOTEL.MES` at `31465` (end `31480`).
- `27066` with `[992] == 1` (a return visit) jumps to `31495` and the
  second hotel entry, `31511..32352`: no menu, handoff to `A_HOTEL.MES` at
  `32352` (end `32367`).

`global_u8[992]` is written once in the archive, `A_HOTEL.MES:6616` (`= 1`),
and read by `43C_ASA.MES`, `A_DATE2`, `A_DATE3`, `A_DATE5`, `A_INTRO` and
`A_TEL` (`analysis/_undoc/ep12_992_scan.log`) - it records that the hotel
has happened. Replays from `A_DATE3.MES` offset 0 at clock `1530`, date
`0502`, answers 3 then 3, with the calendar projection applied (bank 25;
definition 12's month scan at `DEF_MAIN.MES:1244` never ends on a blank
bank): affection 111 and `state_u16[12] = 150` -> **68 messages, handoff
at `31465`** (the clock advances to `1545` through definition 11);
affection 111, `[12] = 0` -> the money refusal and the menu again; affection
110 -> the band scene and the return at `32377` after 45 messages; clock
`2131` -> the lateness scene and the first question again; affection 111,
`[12] = 150`, `[992] = 1` -> **35 messages, handoff at `32352`**.
`state_u16[12]` is the cell `date_scene.md` reads as money (heroine D's
`D_DATE3.MES` has the same structure: retry guards `[11]`/`[12]`/`[15]`,
`state_u16[12] >= 150`, the same two lateness bounds).

Why the earlier readings were wrong: the `command_10` + text + `command_00`
blocks between the three gates were read as "one line and return", which
inverted the gate (they are the menu options, present while the flag is
`0`), and no replay had tried affection at or above 111 (0, 10, 65, 100
were tried, all inside bands that end the date).

## Tool-seeded gates (this measurement)

- `global_u8[110]=1`, `global_u8[117]=2` at the shared guard (origin
  baseline) - natural writer traced to `LIBLARY.LIB`/`?_TALKnn.MES` in
  `ep12_date_prereq_report.md`, but not to a specific caller here.
- `banked_u16[201]=65` (A's own affection) before answering `A_DATE3.MES`'s
  first question case 2, for the a-date-date5 route.
- `banked_u16[201]=111` and `state_u16[12]=150` before answering
  `A_DATE3.MES`'s first question case 3, for the a-date-hotel route (the
  affection ladder's top band and the money gate; see above).
- `global_u8[119]=15` (the promise's own place cell) rather than 9 - a tool
  decision to avoid the cross-file selector site, not a claim that 15 is
  what the promise mechanism itself would choose.

## Pictures

`A_PIC.MES`'s own nested calls (three per pass, before `A_DATE1`, before
the location-flavor tail, and again before `A_DATE3`) and `DENSHA.MES`'s
own `TRAIN.MES` leg load the same paired-surface pictures
`ep12_date_entry_report.md`/`ep12_date_prereq_report.md` already named
(`a2.mmo`/`aan.mmo`, `native_active_surface_value` 2/8; `t.mmo`/`tan.mmo`
for the train leg); this measurement did not re-collect the full picture
trace for the shared prefix in detail beyond confirming the same nested
calls occur.

## Poll supply for definition 17, DATE5's measured ending, and the DENSHA stop (2026-09-24)

EP-12 part 2. A hop field `poll_supplies` (tool decision, additive to v14,
`docs/spec/tech/content_tools.md`'s v14 entry) supplies `state_u16[18] = 0`
into definition 17's own wait (the same seam `map_locations` uses for
`Util(6,13)`, generalised to a plain equality branch inside a registered
definition's body): `mes_event_runner.gd`'s own command-0x0B handler writes
the supplied value into the named cell immediately before that exact
branch's condition evaluates, threaded through `mes_route_probe.gd`'s
`_run_definition` and `mes_registered_definition_call.gd`. Proven both ways:
a GDScript runtime test (`tests/test_mes_route_probe_definitions.gd`,
`_check_poll_supplies`) and the Python audit
(`audit_event_analysis_group.py`'s `_audit_flow_poll_supplies`) against the
real archive, rejecting a wrong index, value, offset, definition or entry.

**DATE5's measured ending, past the poll**: with the supply applied,
`A_DATE5.MES` (entered at offset 0 from `A_DATE3.MES`'s own handoff) runs 11
messages, reaches its own special-date gate at `0x4D8`/1240 (a `branch`
effect, not a stop), continues through further content, and ends at a
`script_handoff_boundary` to `MACHI.MES` at offset `3949` (end `3962`) -
the same terminal shape (a handoff to `MACHI.MES`) every route in this flow
reaches, just from inside `A_DATE5.MES` itself rather than from `01M.MES`.
No further blocker sits past the poll for this baseline.

**A correction to the DENSHA/TRAIN finding above**: driving `DENSHA.MES`
from offset 0 as **one** hop - `TRAIN.MES`'s own `map_locations` contract
attached, iteratively discovering and answering every routine-40 it stops
at - reaches `DENSHA.MES`'s own real return (`42522`/`42523`) cleanly and
deterministically when replayed through the real shared-prefix chain
(`01M.MES` guard -> `A_PIC.MES` -> `A_DATE1.MES` -> `DENSHA.MES`), answering
the same routine-40 (`2652`) with the same value (1) and the same message
count (29) the three-hop split found. The three-hop split is not needed for
this baseline; a fresh direct retest of the one-call technique (not run
through the real chain, only through `A_PROMIS.MES` directly) landed on a
*different* internal flavor branch (`0x7B02`/31490) purely because skipping
`A_PIC.MES`/`A_DATE1.MES` changes how many random picks precede DENSHA's own
one - a sandbox-RNG artifact, not a native fact, described further below.
Separately, the v14 hop-chain audit cannot express a "resume" hop
immediately after another "resume" hop (`_audit_flow_hop_transition` only
accepts a `resume` whose own predecessor is `nested_call`), which is what
the three-hop split would have needed at its own third hop; the one-hop
technique sidesteps this without needing it resolved.

**The declaration attempt stopped in `DENSHA.MES` - a validator gap, read
the same day.** A v14 route's runtime replay starts every variant from
`State.new(1)` plus the route's `baseline` records. `DENSHA.MES` opens with
an unconditional `random_below(7)` flavor pick (`global_u8[350]`); on the
sandbox's fixed-seed RNG (`seed = 1`, a stand-in for the native algorithm by
construction) the pick reached from the real shared prefix selects a branch
that invokes `DEF_MAIN.MES`'s registered definition 12, whose month scan at
`1244..1264` (`banked_u8[25][state_u16[1]] != 15`, `state_u16[1] += 1`)
reads the calendar table `START.MES` fills. On a blank bank 25 the scan
never finds `15` and spends the definition step budget (`definition 12
stopped at definition_step_limit`). The v8 shape already covers this: a
route declaring `state_context.kind == "original_calendar"` has
`mes_calendar_state.gd`'s projection of `START.MES` applied before its
seed (`event_analysis_group_validation.gd`, `catalog_analysis_run.gd`), and
this page's own measurement probe applied it too. The v14 flow validator
loaded only the baseline, so the same DENSHA branch that the hotel replay
passes with the projection applied hit the limit here. The declaration
therefore waits on the v14 shape carrying a `state_context` like v8's and
the flow validator applying it - not on definition 12's table. Definition
11 (the clock advance definition 12 follows) and its callers are
unaffected. `analysis/_undoc/ep12_a_date_declare2_report.md` carries the
attempt's evidence.

## Not established

- Who clears `state_u16[18]` for definition 17's wait in natural play (the
  host; the same cell the map poll writes), and definition 17's meaning
  (the poll can now be supplied by a v14 profile through `poll_supplies`;
  its natural clearing mechanism remains unresolved).
- `state_u16[12]`'s meaning is taken from `date_scene.md`'s reading (money);
  who supplies it and its natural range are not measured here. Definition
  11 advances the clock by `state_u16[2]` minutes (15 at the hotel's
  handoff); definition 12's month scan (`DEF_MAIN.MES:1244`,
  `banked_u8[25][state_u16[1]] != 15`) reads the calendar table that
  `START.MES` fills and `mes_calendar_state.gd` projects - a blank bank 25
  makes it loop to the step limit. The v8 validator applies that projection
  when a route declares `state_context.kind == "original_calendar"`; the
  v14 flow validator did not yet, which is why the declaration attempt of
  2026-09-24 stopped in `DENSHA.MES`'s definition-12 branch. That is a
  validator gap, not a data dependency the flow cannot meet.
- `global_u8[110]`/`[117]`'s own natural writer/caller (traced only to
  `LIBLARY.LIB`/`?_TALKnn.MES` as a class, not to a specific trigger).
- B..L's own equivalent flow content beyond the caller-guard cell mapping
  `ep12_date_entry_report.md` already confirmed.
- A real `kakyu_event_analysis_group/v14` declaration for this group needed
  the flow validator to apply the calendar projection and the definition-17
  poll supply; both landed and the group is declared - see "Declared"
  below. `state_u16[18]`'s natural clearing, `state_u16[12]`'s natural
  supply and `global_u8[110]`/`[117]`'s own natural writer remain
  unresolved, carried in the declared profile's own `unresolved` list.

## Declared (2026-09-24, EP-12 part 3)

`config/event_catalog/analysis_groups/01m_a_date_v14.json`, group
`01m-a-date`, three routes, all measured end to end through the real
19-hop shared prefix (`01M.MES`'s guard through `A_PIC`/`A_DATE1`/
`DENSHA.MES`+`TRAIN.MES` (one hop, `map_locations` attached)/`A_TIME`/
`YABAI`/`A_DATE2`/`A_PIC`/`A_DATE7`/`A_PIC`/`A_DATE3`), then route-specific,
by a fresh replay (`analysis/44m_a_date_v14_probe.gd`, untracked) against
the authoritative archive with `state_context.kind == "original_calendar"`
applied. Every number below is what that replay measured, not what an
earlier partial-context probe recorded (several of this page's own earlier
message counts - `A_DATE7.MES`'s 18, the post-`A_DATE3` resume's 4, the
hotel-question-3 case's 68 - do not reproduce under the real chained
baseline this declaration uses instead of a standalone entry into
`A_DATE3.MES`; the real, chained numbers are the ones in the declared
profile).

**The state-context mechanism**: `state_context` (additive to v14, the same
object v8/v6 routes carry) is applied by
`tools/content_suite/event_analysis_group_flow_validation.gd`'s own new
`_seed_flow_state` to the guard witness and every variant's run state before
`baseline` and the variant's own writes, exactly as
`event_analysis_group_validation.gd`'s `_seed_route` does for v8 -
`Calendar.build` on `documents["START.MES"]`, `apply_to_state`. All three
routes declare `{"kind": "original_calendar", "entry": "START.MES",
"table_sha256": "f21ee0fcb09e960046878e35ad0410aed88680f849ace471b713ef7a12525b4a"}`
(the same fingerprint `build_event_route_profile.py`'s `CALENDAR_TABLE`
already computes for this archive - imported into
`build_event_flow_profile.py`, not recomputed). This is what lets
`DENSHA.MES`'s own hop reach its real return past definition 12's month
scan instead of stopping at `definition_step_limit`.

**Routes, hops, messages** (all against `archive_sha256`
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`):

- **a-date-town** (23 hops): the 19 shared hops (message counts 0 except
  `A_DATE1.MES` 13, `DENSHA.MES`+`TRAIN.MES` 29, `A_TIME.MES` 6,
  `A_DATE7.MES` 22), then `A_DATE3.MES` case 1 (7 messages, `script_return`
  at 32377), the resume's own dispatch to `A_DATE4.MES` at 12583 (0
  messages), `A_DATE4.MES` (6 messages, return at 2336), and the terminal
  `script_handoff_boundary` to `MACHI.MES` at 12633 (end 12646, 0 messages).
- **a-date-date5** (21 hops): the same 19 shared hops, then `A_DATE3.MES`
  case 2 with `banked_u16[201]` (A's own affection) `tool_seeded` to 65 - a
  gate stated as `banked_u16[201] >= 61` (measured with the full baseline,
  `analysis/44m_date5_gate_probe.gd`: 0..60 end the date at `script_return`
  32377; 61..70 reach `A_DATE5.MES` at 18414 (11 messages, the value this
  route uses); 71 reaches it at 18672 (10 messages); 90 at 19345 (15
  messages); 91 and above converge on 20078 (15 messages) - a band
  structure inside case 2's own body, not a single threshold, but every
  band at or above 61 hands off to `A_DATE5.MES`) - 11 messages, handoff
  to `A_DATE5.MES` at 18414 (end 18429); then `A_DATE5.MES` entered by that
  root handoff, `poll_supplies` supplying `state_u16[18] = 0` into
  definition 17's own wait, 11 messages, terminal `script_handoff_boundary`
  to `MACHI.MES` at 3949 (end 3962).
- **a-date-hotel** (23 hops): the same 19 shared hops, then `A_DATE3.MES`
  case 3 with `banked_u16[201]` tool_seeded to 111 and `state_u16[12]`
  tool_seeded to 150 (`greater_or_equal`), answering the place menu's own
  second routine-40 at 28100 with case 3, `poll_supplies` for definition 17
  at 31031 (`A_DATE3.MES` invokes it too, not only `A_DATE5.MES`) - 45
  messages, handoff to `A_HOTEL.MES` at 31465 (end 31480); `A_HOTEL.MES`
  entered by that root handoff, answering its own routine-40 at 7131
  (the unconditional-redirect shape, `option_entry_offsets`
  `[..., 12666]`, case 5) - 37 messages, writes `state_u16[21] = 5`, handoff
  to `A_HOTEL1.MES` at 13271 (end 13287); `A_HOTEL1.MES` entered by that
  root handoff with a `written_by:o21_a_hotel` gate on `state_u16[21] == 5`
  - 94 messages, handoff to `A_HOTEL2.MES` at 31492 (end 31508); and
  **`A_HOTEL2.MES`, the hotel chain's own terminal** - entered by that root
  handoff, 26 messages, `script_handoff_boundary` to `MACHI.MES` at 11625
  (end 11638). The chain reaches `A_HOTEL2.MES`'s own end; no truncation
  was needed.

**The return-visit variant** (`global_u8[992] = 1`, handoff at 32352,
measured on 2026-09-24 in `ep12c_hotel_natural_probe.gd`) is not built: it
needs a different outcome (32352, not 31465) at the same hop
(`o20_a_date3`) for a different variant, and v14's variant shape runs every
variant through the identical hop list and outcomes - only `writes`/
`expected_state` differ. Expressing it needs either a per-variant outcome
override on a hop or a fourth route with its own hop chain; reported here,
not built, per this task's own instruction.

**Mutation results** (`analysis/44m_a_date_v14_mutations.py`, untracked;
seven throwaway copies of the real profile, each re-signed): a shifted hop
record (`h4_a_date1`'s own `entered_by.offset += 1`) is rejected by the
Python audit ("Hop h4_a_date1 entered_by is not hop h3_dispatch_a_date1's
own outcome record"); a wrong message count (`h4_a_date1` set to 999) passes
the Python audit (shape only) and is rejected by the Godot runtime
("hop h4_a_date1 message count"); a wrong answer (`o20_a_date3`'s own
routine-40 result set to 99) is rejected by the Python audit ("Hop
o20_a_date3 answer is outside its own choice contract"); a wrong write
(`o21_a_hotel`'s own `state_u16[21]` expectation changed from 5 to 6) passes
the Python audit and is rejected by the Godot runtime ("hop o21_a_hotel
writes"); a wrong poll value (definition 17's own supplied value changed
from 0 to 1) is rejected by the Python audit ("Hop o20_a_date3 poll supply
does not match its own branch condition"); a wrong gate basis
(`o22_a_hotel1`'s own gate renamed to `written_by:o23_a_hotel2`, a later
hop) is rejected by the Python audit ("Hop o22_a_hotel1 gate basis names an
unknown or later hop"); and a `fresh` state context on all three real
routes passes the Python audit (a bare `{"kind": "fresh"}` is a valid shape)
and is rejected by the Godot runtime - failing first, as this page's own
earlier diagnosis predicted, at hop `h6_densha_train` ("reaches its declared
outcome" and "message count"), the shared `DENSHA.MES`+`TRAIN.MES` hop whose
own definition-12 branch needs the calendar table.

**Validation**: the Python audit accepts all three routes
(`ok: true`); the Godot runtime flow validator
(`validate_event_analysis_group.gd`) reports 185 checks, 0 failures,
`ok: true` against the real archive. `checks_v1.json` now registers
"original event analysis 01M A date" (`analysis_group` family, tier
`full`), taking the "original event analysis groups" check from 149 to 150
members, still green.

**What the catalog part needs** (out of this unit's own scope, per its own
instruction: "Not in this part: catalog rows for flows, the classifier,
event definitions, B..L"): `tools/build_event_names.py`'s own
`collect_sites` (and `tests/test_event_names_registry.py`,
`tests/test_event_outcome_vocabulary.py`'s pinned census) assume every
analysis-group profile carries a single route-level `route["caller"]`/
`route["callee"]` pair; a v14 flow's per-hop `entry` has no such pair, so
`collect_sites` now raises `KeyError: 'caller'` on this profile and three
`test_event_names_registry.py` tests error, while
`test_event_outcome_vocabulary.py`'s pinned route/reentry census (and one
`unknown_kind` check) shift by the count this profile's own hops add. The
catalog part needs its own classification for a v14 flow's hops (what a
"site", a "route" and a "reentry" mean for a chain with no single
caller/callee) before those tests are re-pinned; not attempted here.

## Catalog (2026-09-24, EP-12 catalog part)

The gap the previous section named is closed: `tools/build_event_names.py`'s
`collect_sites` now reads a v14 route by its own shape (`route["origin"]`,
`route["hops"][0]["expected"]["outcome"]`) instead of a caller/callee pair,
and `tools/promote_analysis_groups.py` promotes each route directly
(`build_flow_row`). Three rows joined the catalog (revision 29, 145 rows)
and the registry (131 profile pairs, 145 catalog events):

| route | registry id | catalog `event_id` | terminal owner:offset | choices (hop : boundary) |
|---|---|---|---|---|
| `a-date-town` | `miko.town.station.date-town.1` | `original/a-date-town/01m-00002af7` | `01M.MES:12633` | `DENSHA.MES:2652`, `A_TIME.MES:1497`, `A_DATE3.MES:13402` |
| `a-date-date5` | `miko.town.station.date-date5.1` | `original/a-date-date5/01m-00002af7` | `A_DATE5.MES:3949` | `DENSHA.MES:2652`, `A_TIME.MES:1497`, `A_DATE3.MES:13402` |
| `a-date-hotel` | `miko.town.station.date-hotel.1` | `original/a-date-hotel/01m-00002af7` | `A_HOTEL2.MES:11625` | `DENSHA.MES:2652`, `A_TIME.MES:1497`, `A_DATE3.MES:13402`, `A_DATE3.MES:28100`, `A_HOTEL.MES:7131` |

Every route's `event_id` anchors the flow's own origin guard
(`01M.MES:10999`, hex8 `00002af7`), not the registry site's own dispatch
coordinate (`01M.MES:11148`, the flow's shared first dispatch to
`A_PIC.MES`, command 15) - the two coordinates name different things (the
run's own start, and the site this group's three routes share). Each row's
one preset composes `baseline` + the `default` variant's writes (empty for
all three) + every hop's own `tool_seeded` gate writes (`banked_u16[201]`
and `state_u16[12]` for `a-date-hotel`'s own `o20_a_date3` hop,
`banked_u16[201]` for `a-date-date5`'s own `d20_a_date3` hop), so the one
promoted run is self-contained. `choices` names one entry per hop `answers`
item with its own single measured option (a flow has no alternative to
pick, only the chain's own recorded answer); `terminals` carries the
route's own `terminal` mapped as a v4 `root_handoff` would be
(`root_replacement`/`normal_completion`/`script_handoff_boundary`).

`catalog_analysis_run.gd`'s `run_group_route` now runs a v14 row's whole hop
chain through the shared `KakyuEventFlowRunner` (`tools/content_suite/event_flow_runner.gd`)
instead of `build_group_route_descriptor` (which needs a `caller`/`callee`
pair no flow route has), and `_selections_contain` reads a flow route's
measured answers from its own hops instead of the variant. A throwaway,
untracked measurement (`analysis/ep12_a_date_town_tailprobe.gd`) proved the
wiring before the real rows existed: a hand-built tail route over
`a-date-town`'s own `h19_dispatch_a_date3`..`t23_handoff_machi` hops, seeded
from the real chain's own measured carried state at that point (not a
fabricated seed), ran through `readiness_group` + `run_group_route` to the
`MACHI.MES` terminal with combined message count 13 (`t20_a_date3`'s 7 +
`t22_a_date4`'s 6) and a non-empty 6-step timeline.

Not built in this part: a v4/v5 event definition document for a flow route
(the flow definition shape is a separate, later owner decision) - a test or
the batch that demands one per catalog row excludes a v14-backed row by its
group's own profile schema instead.

## Definitions (2026-09-25, EP-12 / WD unit 2)

The separate decision the previous section named landed: each of the three
rows above now has a `kakyu_event_definition/v6` document
(`config/event_definitions/v6/miko.town.station.date-{town,date5,hotel}.1.json`)
carrying a real `flow` block. Hop counts, measured directly from each
document's own `flow.hops`, not assumed: `date-town` 23, `date-date5` 21,
`date-hotel` 23 - matching the v14 profile's own route lengths one for one.
Every hop's `gates`/`poll_supplies`/`map_locations` are the profile's own,
projected verbatim (`d20_a_date3`'s and `o20_a_date3`'s own `tool_seeded`
gates on `banked_u16[201]`/`state_u16[12]`; `o22_a_hotel1`'s own
`written_by: o21_a_hotel` gate on `state_u16[21]`; `d21_a_date5`'s and
`o20_a_date3`'s own definition-17 `poll_supplies` on `state_u16[18]`).

What stays unresolved, unchanged from what this document already flagged
for the one declared group and now carried into each document's own
`unresolved` list: `state_u16[18]`'s natural clearing for definition 17's
own host-wait poll (the tool-supplied `poll_supplies` stand in for it, not
a measured natural clearer), `state_u16[12]`'s natural supply (read as
money; who credits it and its natural range are not measured), and
`global_u8[110]`/`[117]`'s own natural writer (traced only to a
`LIBLARY.LIB`/`?_TALKnn.MES` class of caller, not a specific one). The
origin guard's own conjuncts (today equals the promise day
`banked_u16[215]`, clock at or after `[216]`, `global_u8[110]==1`,
`[117]==2`, place `[119]` in 9..13) are the document's own top-level
`guard`, decoded through the same `guard_ast`/`map_conjunct` machinery v4
already uses - no new decoder, no extended cell-class table.
`config/event_definitions/v6/README.md` records the exact projection
(hop/gate/poll counts, fingerprints, and the measured divergence from v5's
frozen documents for the other 142 registry sites - not this group, which
has no v4/v5 document to diverge from).
