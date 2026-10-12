# Heroines C..L's Promise Dates: the Batch Unit

EP-12 C..L date batch (2026-09-25). Measured against the authoritative
`mes.arc` (`archive_sha256`
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`) by the
same `tools/draft_date_flow_specs.py`/`tools/content_suite/cli/measure_date_flow.gd`
pair `docs/spec/mes/b_date_flow.md` built, extended to all twelve heroines
and generalized for three structural departures this batch found beyond
A/B's own shape (see "Tool departures" below). This page states only C..L's
own numbers, in one table, plus a short "Departures" note per heroine; read
`docs/spec/mes/a_date_flow.md` and `docs/spec/mes/b_date_flow.md` for the
shared mechanism (the guard shape, the 19-hop shared prefix, the
`poll_supplies`/`map_locations` tool decisions, the
`state_context: original_calendar` seam). No original dialogue is quoted.

EP-12 leftovers unit (2026-09-26, Core 0.368.0): D's hotel route and L's
date5 route, left out of the original C..L batch by a route-toolchain
limitation, are now measured and declared (see their own entries below); J's
hotel mechanism is measured directly by replay but stays undeclared as a
formal route for a schema reason, also explained in its own entry.

## Per-heroine table

| Letter | Heroine | Guard offset (`01M.MES`) | First question offset | DATE5 gate (affection `<N`) | Hotel top band (affection `<N`) | Money gate (`state_u16[12]<N`) | Hotel selector (`state_u16[21]`) | Hotel flag (`global_u8[N]`) | Routes declared | Hop counts | Message counts | Terminal |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|
| C | Nana | 17627 | 9190 | 91 | 101 | 150 | 3 | 1651 | town, date5, hotel | 23, 21, 23 | 79, 116, 250 | MACHI.MES, MACHI.MES, MACHI.MES |
| D | Maki | 27569 | 9288 | 91 | 91 | 150 | 3 | 676 | town, date5, hotel | 23, 21, 23 | 78, 99, 239 | MACHI.MES, MACHI.MES, MACHI.MES |
| E | Mizuho | 12656 | 9195 | 91 | 111 | none | 2 | 1790 | town, date5, hotel | 23, 21, 23 | 77, 103, 260 | MACHI.MES, MACHI.MES, 44C.MES |
| F | Reiko | 9342 | 15509 | 101 | 111 | 150 | 3 | 1502 | town, date5, hotel | 23, 21, 23 | 92, 120, 391 | MACHI.MES, MACHI.MES, MACHI.MES |
| G | Ryoko | 15970 | 9190 | 101 | 101 | none | 1 | 1362 | town, date5, hotel | 23, 21, 23 | 83, 99, 280 | MACHI.MES, MACHI.MES, MACHI.MES |
| H | Miyuki | 19284 | 9043 | 91 | 101 | 150 | 3 | 2081 | town, date5, hotel | 23, 21, 23 | 75, 115, 256 | MACHI.MES, MACHI.MES, MACHI.MES |
| I | Mayumi | 14313 | 10224 | 91 | 61 | none | 2 | 1217 | town, date5, hotel | 23, 21, 23 | 83, 111, 227 | MACHI.MES, MACHI.MES, 44C.MES |
| J | Minatu | 25912 | 10667 | 91 | 101 | none | 1 | 782 | town, date5 | 23, 21 | 78, 126 | MACHI.MES, MACHI.MES |
| K | Ai | 20941 | 9392 | 91 | 121 | 150 | 3 | 2182 | town, date5, hotel | 23, 21, 23 | 79, 124, 250 | MACHI.MES, MACHI.MES, MACHI.MES |
| L | Sizuka | 22598 | 12514 | 121 | 121 | none | 1 | 1923 | town, date5, hotel | 23, 21, 23 | 81, 129, 275 | MACHI.MES, 44C.MES, 44C.MES |

"DATE5 gate" and "Hotel top band" name the last (topmost) affection-ladder
threshold in each case's own body, the same reading `docs/spec/mes/b_date_flow.md`
used for B; the tool seeds `banked_u16[affection_cell]` to `threshold + 20`
to clear it. "Money gate" is `none` where the heroine's own hotel case body
carries no `state_u16[12]` check at all (E, G, I, J, L) - a genuine
structural absence, confirmed by a full branch dump of each, not a search
miss. Every guard's own six-conjunct shape, the 19-hop shared prefix, and
`?_DATE3.MES`'s two routine-40s and 3-case elif chains match A/B's shape
exactly for all ten heroines; only the literal offsets, cell indices and
per-file message counts differ, plus the three tool departures below.

## Tool departures (beyond B's three)

`docs/spec/mes/b_date_flow.md`'s own departures section already recorded
three ways B's bytecode differs from A's (an extra date5 flag conjunct, a
five- vs six-band hotel ladder, a plain-clock special-date gate). This batch
found three more, each affecting more than one heroine, so
`tools/draft_date_flow_specs.py` and `tools/content_suite/cli/measure_date_flow.gd`
were extended to measure them generically rather than by heroine-specific
code:

- **A jump-chased town terminal that lands short of the return record.**
  D, E, F and K's own case-1 body ends in a jump whose target is a plain
  `write`/`routine` pair, not the `script_return` record itself - the
  return sits a few bytes further on, reached by fallthrough. The static
  discovery now follows the jump and takes the nearest `script_return` at
  or after its target (within 64 bytes) instead of requiring an exact
  match.
- **An optional money gate.** E, G, I, J and L's own hotel case bodies
  carry no `state_u16[12]` check at all (the money gate A/B/C/D/F/H/K all
  have); `_second_question`'s own money-threshold field is now `null` for
  these five, and the runtime tool skips seeding `state_u16[12]` and the
  matching gate record when it is.
- **The HOTEL site-selector routine-40 sharing its file with a later,
  unrelated question.** E and I's own `?_HOTEL.MES` carries a third
  routine-40 (a side question reached from a case other than case 5, per
  `analysis/_undoc/ep12_hotel_report.md`'s Q2) in addition to the two
  mutually-exclusive site-selector sites `global_u8[3004]` chooses between.
  The static scan now finds the selector site by its own position inside
  the `global_u8[3004]` gate's true branch, not by requiring exactly two
  routine-40 sites in the whole file.

Two further, one-off site shapes needed a generic *policy* rather than a
code change - the "Questions with no route policy" the task itself named:

- **E and I's own `?_HOTEL2.MES` ending.** A routine-40 (2 options, `state_u16[21]`
  1 or 2) gates the file's own first handoff; answered value 1 (the first
  option), landing at `44C.MES` rather than `MACHI.MES`.
- **L's own `?_DATE5.MES` ending.** The lateness check's own false branch
  falls straight into an unanswered routine-40 of the identical
  `44C.MES`/`MACHI.MES` shape (offset 5945); the tool now retries once with
  that boundary answered value 1 whenever a route's own poll-supplied walk
  stops on an unresolved choice instead of its terminal, parsing the
  boundary out of the route probe's own `"no catalog choice at 0x.."`
  message rather than needing the site named in advance.

## Per-heroine departures and left-out routes

- **C**: no departure beyond the three above; all three routes measure and
  are declared.
- **D**: the town terminal is jump-chased (see above). The hotel route's
  own `?_HOTEL.MES` site-selector routine-40 contract could not be rebuilt
  by the shared single-resume-point technique `_build_contract` used
  through Core 0.367.0 (the raw re-run from the last known dialogue resume
  point diverged into an unrelated `shared_routine_boundary` before
  reaching the selector's own boundary, because the bare re-run did not
  carry the argument-slot/library context the original walk had already
  resolved). **Resolved in Core 0.368.0**: `content_core/mes_route_probe.gd`'s
  `_select_choice` now carries the live `def_selection_boundary` result
  forward in `stop_detail` (`kind: "unanswered_choice"`, `entry`,
  `boundary_offset`, `result`, `code_size`, `source_identity`) instead of
  discarding it on failure, and `_build_contract`/`_contract` build the
  contract directly from that live result - the correct fix is to use the
  boundary the walk already reached, not to re-run for a second one. All
  three routes (town, date5, hotel) now measure and are declared; the
  hotel route's own terminal is `MACHI.MES` (23 hops, 239 messages), the
  same terminal class C/F/G/H/K's own hotel routes reach.
- **E**: the hotel selector is 2 (not 3); the hotel gate carries no money
  check; `?_HOTEL.MES` carries the third, unrelated routine-40; `?_HOTEL2.MES`
  ends in the two-option own choice. All three routes measure and are
  declared.
- **F**: the town terminal is jump-chased. No other departure; all three
  routes measure and are declared.
- **G**: the hotel selector is 1; the hotel gate carries no money check. No
  other departure; all three routes measure and are declared.
- **H**: no departure beyond the three shared ones; all three routes
  measure and are declared.
- **I**: the hotel selector is 2; the hotel gate carries no money check
  (and instead an extra `banked_u16[203]` affection recheck inside the
  accepted hotel case, already satisfied by the same seed the outer ladder
  uses); `?_HOTEL.MES` carries the third, unrelated routine-40;
  `?_HOTEL2.MES` ends in the two-option own choice. All three routes
  measure and are declared.
- **J**: the hotel selector is 1; the hotel gate carries no money check.
  J's own hotel mechanism is a **two-visit affair**, confirmed by direct
  replay (re-runnable as the archive-tier check "original EP-12 re-entry probes", `tools/content_suite/validators/validate_ep12_reentry_probes.gd`, part 1; EP-12 item 3, 2026-09-26): under
  baseline state, `J_DATE3.MES`'s own hotel case (`state_u16[21] == 1` from
  `34568`) writes `global_u8[867] = 0`, `[868] = 1`, `[866] = 1`, `[286] = 1`
  and hands off to `MACHI.MES` at offset 43769 (`script_handoff_boundary`,
  command `0x0E`) - replayed directly, this is `j-date-hotel-first`
  (measured, not declared as a route - see below). The command-`0x0C`
  `continuation_transfer` record immediately after that handoff (offset
  43787, operand `44083`) is **not reachable within that same run**: command
  `0x0E`'s own runner semantics (`content_core/mes_event_runner.gd`) return
  `script_handoff_boundary` and halt at 43769 before the runner ever reaches
  43787, confirmed by execution. Offset 43797 (address-table entry 360,
  right after that continuation record) is therefore a **re-entry
  coordinate for a separate, later invocation** of this same file, not a
  branch target any in-file code reaches - matching the task's own finding
  that no branch in the file targets 43787/43797/44083. The four in-file
  reads of `global_u8[868]` (40177, 42470, 46784, 49075, all inside two
  other address-table entries - 329 and 381 - deep in the Q1 "town" case's
  own day-by-day narrative) were checked directly: neither read's own branch
  targets 43787/43797/44083 in either direction; both entries' own
  `[868]==1` path instead falls through to the same shared "caller resume"
  boilerplate `format_and_method.md`'s own PROMIS-caller-resume paragraph
  describes, not to entry 360. **Replayed directly**
  (`global_u8[868] = 1` seeded, `tool_seeded`, basis: written by
  `J_DATE3.MES`'s own earlier pass; `J_DATE3.MES` entered directly at offset
  43797, not offset 0): the run plays entries 360/361/362 in sequence (7
  messages) and hands off to `J_HOTEL.MES` at offset 44083
  (`script_handoff_boundary`) - exactly the coordinate `format_and_method.md`'s
  own static decode already named. Continuing through the same generic
  chain every other heroine uses (`J_HOTEL.MES`'s site-selector answered
  value 5, 39 messages, hands to `J_HOTEL1.MES`; `J_HOTEL1.MES`, 57
  messages, hands to `J_HOTEL2.MES`; `J_HOTEL2.MES`, 22 messages, hands to
  `MACHI.MES`) completes the chain: 7 + 39 + 57 + 22 = 125 messages across 4
  hops from the re-entry coordinate to the terminal. This is a complete,
  execution-confirmed measurement of `j-date-hotel`, but it is **not
  declared as a formal route** in `01m_j_date_v14.json`: every existing hop
  in that schema is `nested_call`/`root_handoff`/`resume`/`dispatch`, each
  derived from the hop before it (`build_event_flow_profile.py`'s own
  "never hand-supplied" invariant), and a positional re-entry into a
  mid-file address-table label on a separate, later invocation has no
  governing caller record for that derivation to use. Declaring it would
  mean hand-authoring a hop the schema cannot derive, which this batch
  declined rather than risk an inconsistent record. The hotel route stays
  measured-but-undeclared; town and date5 are declared.
- **K**: the town terminal is jump-chased. No other departure; all three
  routes measure and are declared.
- **L**: the hotel selector is 1; the hotel gate carries no money check;
  `?_DATE5.MES` falls into its own open choice (see above). L's own hotel
  ending is a plain, unconditional handoff to `44C.MES` under baseline
  state (not an own-choice site the way E/I's is) - a route whose terminal
  is not a map handoff is still a route; the outcome vocabulary classifies
  it `chain`. The date5 route's own open-choice contract (offset 5945)
  could not be rebuilt by the same single-resume-point technique the
  D/hotel case above hit through Core 0.367.0. **Resolved in Core 0.368.0**,
  and by a second, independent fix this same measurement found: the
  Core-0.368.0 stop-detail fix alone still left this specific site failing
  - not with the argument-slot/library divergence the D case showed, but
  with `awaiting_stop`: `"definition 17 stopped at definition_step_limit"`,
  because `_build_contract`'s own independent re-walk of `L_DATE5.MES` (run
  to discover the contract, separately from the route's own walk) omitted
  the `poll_supplies` descriptor the route's own walk already supplies for
  the file's definition-17 wait. `_build_contract` (and its `measure_date_flow.gd`
  sibling `_contract`) gained a `poll_supplies` parameter, threaded from the
  date5 route's own call site the same way `map_locations` already threads
  DENSHA.MES's train poll; with it, the walk reaches the open-choice
  boundary at offset 5945 (`0x1739`) exactly as named, and both techniques
  (old bare re-run and the new stop-detail build) now agree on it -
  confirming this site's own blocker was the missing argument, not an
  argument-slot/library divergence like D's. All three routes (town, date5,
  hotel) now measure and are declared; the date5 route's own terminal is
  `44C.MES` (21 hops, 129 messages), the same terminal class its own hotel
  route already reaches.

## Not established

- The same four gaps `docs/spec/mes/a_date_flow.md`'s and `docs/spec/mes/b_date_flow.md`'s
  own "Not established" sections record (`state_u16[18]`'s natural
  clearing, `state_u16[12]`'s natural supply where a money gate exists,
  `global_u8[200]`/`[207]`-class guard flags' own natural writer, and each
  heroine's own two-flag guard cells' equivalent) apply identically to
  C..L; not repeated per heroine here.
- D's own `?_HOTEL.MES` and L's own `?_DATE5.MES` open-choice contracts (see
  "Per-heroine departures" above) - resolved in Core 0.368.0 (EP-12
  leftovers unit, 2026-09-26); no longer a gap.
- J's own hotel route: execution-confirmed as a positional re-entry into
  address-table entry 360 on a later invocation of `J_DATE3.MES` (see
  "Per-heroine departures" above), not declared as a formal route because
  the hop-chain schema has no shape for a re-entry with no governing caller
  record. What natively selects which calendar day's own address-table
  entry a fresh call into `J_DATE3.MES` enters at (i.e., what makes the
  *next* call land at entry 360 specifically rather than the file's usual
  start) remains unresolved; only that entry 360 itself, once entered,
  reaches `J_HOTEL.MES` is confirmed.
- I's own extra `banked_u16[203]` affection recheck and E/I's own second
  `?_HOTEL.MES` question (reached from a case other than case 5): read from
  static facts only, not driven by execution, matching the class of gap
  `analysis/_undoc/ep12_hotel_report.md` already recorded for A's own
  equivalent side content.
