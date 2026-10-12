# Heroine B's Promise Date: the A Template Applied

EP-12 B date template unit (2026-09-25). Measured against the authoritative
`mes.arc` (`archive_sha256`
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`) by the
new pair `tools/draft_date_flow_specs.py` (static discovery, `tools/mes_route_decode.py`
facts/conjuncts) and `tools/content_suite/cli/measure_date_flow.gd` (the
runtime measurement, one fresh top-level `probe.run_route` call per hop,
`content_core/mes_route_probe.gd`). This page follows `docs/spec/mes/a_date_flow.md`'s
own structure but states only B's own numbers and where B's own bytecode
departs from A's; read that page for the shared mechanism (the guard shape,
the nested-call chain, the `poll_supplies`/`map_locations` tool decisions,
the `state_context: original_calendar` seam). No original dialogue is
quoted.

## The guard

`01M.MES`'s own B guard sits at code-relative offset **24255** (end 24344,
false target 25912) - the same shape as A's, on B's own cells:

```
(state_u16[7] equal banked_u16[233])
  and (global_u8[200] equal 1)
  and (global_u8[207] equal 2)
  and (state_u16[19] equal banked_u16[234] OR state_u16[19] greater_than banked_u16[234])
  and (global_u8[209] greater_than 8)
  and (global_u8[209] not_equal 14)
```

`banked_u16[233]`/`[234]` are B's own promise date/time cells and
`global_u8[209]` B's own location cell, per
`validate_event_player_promise_dates.gd`'s `CASES` table (`B_PROMIS.MES`:
intro `0x253A`/9530, writer `0x259B`, field 233, choice_boundary `0x2F88`/12168,
location_field 209, accepted_return `0x5036`/20534). `global_u8[200]`/`[207]`
are B's own two guard flags (A's equivalent: `[110]`/`[117]`); their own
natural writer is unresolved here, the same as A's - see "Not established".

## Shared prefix (19 hops, all three routes)

The same nested-call sequence as A's, on B's own files, entered by the same
guard: `B_PIC.MES` (0 msgs) -> `B_DATE1.MES` (13 msgs) -> `DENSHA.MES`+`TRAIN.MES`
(one hop, `map_locations` attached, 29 msgs) -> `B_TIME.MES` (6 msgs) ->
`YABAI.MES` (0 msgs) -> `B_DATE2.MES` (0 msgs) -> `B_PIC.MES` (0 msgs) ->
`B_DATE7.MES` (17 msgs) -> `B_PIC.MES` (0 msgs) -> `B_DATE3.MES` (route-specific
from here). `DENSHA.MES`'s own routine-40 (2652) and `TRAIN.MES`'s own
`Map.get_location` poll (886) are the identical shared-file offsets A's page
already measured - byte-identical, not merely structurally similar, since
both files are heroine-independent. `B_TIME.MES`'s own routine-40 sits at
919 (A's: 1497), answered value 1. `B_DATE7.MES` needed no answer (17
messages this run, vs A's 22 - a per-heroine content difference, not a
structural one).

## `B_DATE3.MES`: the first question and its three cases

Routine-40 at **8921** (A's: 13402), 3-case elif chain on `state_u16[21]`:
case 1 at 8956 (false target 12465), case 2 at 12465 (false target 18405),
case 3 at 18405 (false target 27730) - the same case order as A's (1 town,
2 date5, 3 hotel).

## Route: b-date-town

Case 1's body is short: a jump to the shared plain `script_return` at
**27735** (end 27736) - **7 messages**, identical to A's own case-1 message
count. Resuming `01M.MES` at the case-1 dispatch's own end reaches its own
dispatch into `B_DATE4.MES` at 25839 (end 25854, 0 messages);
`B_DATE4.MES` runs **6 messages** to its own return (2148, end 2149); resuming
`01M.MES` reaches the flow's own terminal, `script_handoff_boundary` to
`MACHI.MES` at 25889 (end 25902). **23 hops total**, matching A's own
`a-date-town` hop count exactly.

## Route: b-date-date5

Case 2's own body holds an affection ladder on `banked_u16[210]` (B's own
affection cell, per `ep12_hotel_report.md`'s table) with band edges at
11/21/31/41/51/61/71/81/91 and an inner `global_u8[539]` check per band (a
cell not present in A's own date5 ladder - a structural difference: A's
bands were single-threshold, B's carry an extra flag check per band); every
band at or above the `> 90` edge (with `global_u8[539] = 0`) hands off to
`B_DATE5.MES`. This measurement seeded `banked_u16[210] = 111`,
`global_u8[539] = 0`, reaching the handoff at **18375** (end 18390) with
**22 messages** (A's equivalent case-2 hop: 11 messages - the size
difference tracks the extra content this measurement's own top band plays,
not a tool artifact). `B_DATE5.MES`, entered at offset 0 with
`poll_supplies` for definition 17 (the shared `DEF_MAIN.MES:4222` poll, byte
identical to A's), runs **13 messages** to its own `script_handoff_boundary`
to `MACHI.MES` at **2528** (end 2541) - B's own special-date gate here is a
plain clock check (`state_u16[19] < 1800`), not A's short list of specific
dates, and is true under the canonical `1530` clock, so B's own run passes
through its own affection-banded `?_TALKnn.MES` dispatch inline (still one
hop, since the dispatch is nested inside `B_DATE5.MES`'s own run). **21 hops
total**, matching A's own `a-date-date5` hop count.

## Route: b-date-hotel

Case 3's own body holds its own affection ladder on `banked_u16[210]`, with
thresholds 51/61/71/81/91: **five bands, not A's six** (A's own top band
needed affection 111; B's own top band is reached at affection **91**,
one fewer threshold) - a real per-heroine departure in the gate's own shape,
not a tool choice. The lateness checks (`state_u16[19] > 2130 and
state_u16[7] != 1224`; `state_u16[19] > 1830 and state_u16[7] == 1224`) and
the return-visit shortcut (`state_u16[12] < 150 and global_u8[664] == 1`)
are the same shape as A's, on B's own hotel flag (`global_u8[664]`, per
`ep12_hotel_report.md`'s table). The first-visit gate (`global_u8[664] == 0`)
sits at **22529** (A's: 27066, on `global_u8[992]`). The place menu (`command_1b`
reset, three `command_10` option adds gated on `global_u8[11]`/`[12]`/`[15]`)
precedes the second routine-40 at **23462** (A's: 28100), whose own 3-case
chain answers case 3 (`state_u16[21] = 3`, matching `ep12_hotel_report.md`'s
own table for B) at 24366 (false target 26979). That case's own body needs
`state_u16[12] >= 150` (money, same threshold as A's) and the same two
lateness checks, then invokes definition 17 at **26349** and definition 11 at
**26388** (A's: 31031/31070), before the handoff to `B_HOTEL.MES` at **26959**
(end 26974) - **49 messages** for this whole `B_DATE3.MES` hop (banked_u16[210]
tool-seeded to 111, state_u16[12] to 150, `poll_supplies` for definition 17).

`B_HOTEL.MES`'s own routine-40 sits at 5797 (the site reached when
`global_u8[3004] == 0`, the same default A's own measurement used; B's other
site, 5817, is not exercised here), a 6-case elif chain on `state_u16[21]`
identical in shape to A's (case 5's fallthrough handoff to `B_HOTEL1.MES`);
answering case 5 (its own contract accepted values 1..5, the same
"unconditional-redirect shape" A's page named) ran **22 messages** to the
handoff at **10278** (end 10294). `B_HOTEL1.MES`, entered fresh with the
`written_by:o21_hotel` gate on `state_u16[21] == 5` holding, ran **70
messages** to its own unconditional handoff to `B_HOTEL2.MES` at **28219**
(end 28235) - no routine-40, the same shape as A's. `B_HOTEL2.MES`, the
chain's own terminal, ran **18 messages** to `script_handoff_boundary`
`MACHI.MES` at **4501** (end 4514) - matching `ep12_hotel_report.md`'s own
earlier, differently-seeded measurement of B's HOTEL2 message count (18)
exactly. **23 hops total**, matching A's own `a-date-hotel` hop count.

## Departures from A

- The date5 gate's own affection ladder carries an extra `global_u8[539]`
  check per band that A's own ladder does not (A's own bands used a single
  affection threshold each).
- The hotel gate's own affection ladder has five bands (thresholds
  51/61/71/81/91) where A's has six (51/61/71/81/91/111); B's own top band
  is reached at affection 91, not 111.
- `B_DATE5.MES`'s own special-date gate is a plain clock check
  (`state_u16[19] < 1800`), not A's own short list of specific dates; under
  the canonical clock (1530) it is true, so B's own affection-banded
  `?_TALKnn.MES` dispatch runs inline inside the `B_DATE5.MES` hop (not a
  separate hop; A's own canonical run left this gate false and never
  exercised that dispatch).
- Every per-heroine message count and file offset differs from A's own
  numbers as expected (`B_HOTEL1.MES`: 70 messages vs A's 94; `B_TIME.MES`'s
  own routine-40 at 919 vs A's 1497; `B_DATE7.MES`: 17 messages vs A's 22),
  since B_TIME/B_DATE1/B_DATE2/B_DATE7/B_HOTEL/B_HOTEL1/B_HOTEL2/B_DATE3/B_DATE5
  are B's own distinct files, not shared ones; none of these are structural
  departures.
- Every other measured shape (the guard's six conjuncts, the 19-hop shared
  prefix, `B_DATE3.MES`'s two routine-40s and 3-case chains, the money gate,
  the two lateness checks, the definition-17/11 invocation order, the HOTEL
  chain's own three files and terminal) matches A's own shape exactly, with
  only the literal offsets and cell indices differing.

## Tool-seeded gates (this measurement)

- `global_u8[200] = 1`, `global_u8[207] = 2` at the shared guard (origin
  baseline) - natural writer not traced here, the same class of gap as A's
  `[110]`/`[117]`.
- `banked_u16[210] = 111` (B's own affection) before answering
  `B_DATE3.MES`'s first question case 2, for `b-date-date5` (a value
  satisfying the top band, `> 90`), with `global_u8[539] = 0`.
- `banked_u16[210] = 111` and `state_u16[12] = 150` before answering
  `B_DATE3.MES`'s first question case 3, for `b-date-hotel` (the affection
  ladder's top band and the money gate).
- `global_u8[209] = 15` (the promise's own place cell) rather than 9, the
  same tool decision A's page recorded (avoiding the location 9..13
  presentation-flavor branch, not a claim about what the promise mechanism
  itself would choose).

## Tool usage

```
py tools/draft_date_flow_specs.py --arc "<mes.arc>" --letter B --out analysis/_undoc/ep12_b_flow_recipe.json
godot --headless --path . --script res://tools/content_suite/cli/measure_date_flow.gd \
    -- "<ELFIMAGE dir>" analysis/_undoc/ep12_b_flow_recipe.json analysis/_undoc/ep12b_specs analysis/_undoc/ep12_b_flow_measure_report.json
py tools/build_event_flow_profile.py --arc "<mes.arc>" \
    --spec analysis/_undoc/ep12b_specs/01m_b_date_town_v14_spec.json \
           analysis/_undoc/ep12b_specs/01m_b_date_date5_v14_spec.json \
           analysis/_undoc/ep12b_specs/01m_b_date_hotel_v14_spec.json \
    --out config/event_catalog/analysis_groups/01m_b_date_v14.json
```

`tools/draft_date_flow_specs.py`'s `HEROINE_TABLE` carries B's own cited
cells (promise field 233/234, location field 209 from
`validate_event_player_promise_dates.gd`; affection cell 210, hotel
`state_u16[21]` value 3, hotel flag 664 from `ep12_hotel_report.md`'s
per-heroine table) alongside A's, for cross-check; C..L are this family's
own later batch unit, adding their own rows to the same table.

## Not established

- `state_u16[18]`'s own natural clearing for definition 17's own host-wait
  poll (the tool-supplied `poll_supplies` stands in for it, the same gap
  A's page names).
- `state_u16[12]`'s natural supply (read as money; who credits it and its
  natural range are not measured, the same gap A's page names).
- `global_u8[200]`/`[207]`'s own natural writer (not traced to a specific
  caller, the same class of gap as A's `[110]`/`[117]`).
- B's own `global_u8[539]` cell's meaning (it gates the date5 ladder's own
  bands; not traced further here).

## Declared

`config/event_catalog/analysis_groups/01m_b_date_v14.json`, group
`01m-b-date`, three routes (`b-date-town` 23 hops, `b-date-date5` 21 hops,
`b-date-hotel` 23 hops), `state_context.kind == "original_calendar"` on all
three, built by `tools/build_event_flow_profile.py` from the three spec
files `tools/content_suite/cli/measure_date_flow.gd` wrote. The Python audit
(`tools/audit_event_analysis_group.py`) accepts all three routes; the Godot
runtime flow validator (`validate_event_analysis_group.gd`) reports 184
checks, 0 failures, `ok: true` against the real archive.
`config/validation/checks_v1.json` now registers "original event analysis
01M B date" (`analysis_group` family, tier `full`), taking "original event
analysis groups" from 150 to 151 members.

**Mutation results** (`analysis/44m_b_date_v14_mutations.py`, untracked;
the same seven mutations A's part used): a shifted hop record (`h4_b_date1`'s
own `entered_by.offset += 1`) is rejected by the Python audit ("Hop
h4_b_date1 entered_by is not hop h3_dispatch_b_date1's own outcome record");
a wrong message count (`h4_b_date1` set to 999) passes the Python audit and
is rejected by the Godot runtime ("hop h4_b_date1 message count"); a wrong
answer (`t20_hotel_date3`'s second answer set to 99) is rejected by the
Python audit ("Hop t20_hotel_date3 answer is outside its own choice
contract"); a wrong write (`o22_hotel1`'s own `state_u16[21]` gate value
changed from 5 to 6) passes the Python audit and is rejected by the Godot
runtime ("hop o22_hotel1 gate holds on entry"); a wrong poll value
(definition 17's own supplied value changed from 0 to 1) is rejected by the
Python audit ("Hop t20_hotel_date3 poll supply does not match its own
branch condition"); a wrong gate basis (`o22_hotel1`'s own gate renamed to
`written_by:o23_hotel2`, a later hop) is rejected by the Python audit ("Hop
o22_hotel1 gate basis names an unknown or later hop"); and a `fresh` state
context on all three real routes passes the Python audit and is rejected by
the Godot runtime, failing first at `h6_densha` - the same shared
`DENSHA.MES`+`TRAIN.MES` hop A's own equivalent mutation failed at first,
for the same reason (the calendar table definition-12 branch).

## Catalog, names and definitions (2026-09-25)

Three rows joined the catalog (revision 30, 148 rows) and the registry (132
profile pairs, 148 catalog events):

| route | registry id | catalog `event_id` | terminal owner:offset |
|---|---|---|---|
| `b-date-town` | `mahoko.town.station.date-town.1` | `original/b-date-town/01m-00005ebf` | `01M.MES:25889` |
| `b-date-date5` | `mahoko.town.station.date-date5.1` | `original/b-date-date5/01m-00005ebf` | `B_DATE5.MES:2528` |
| `b-date-hotel` | `mahoko.town.station.date-hotel.1` | `original/b-date-hotel/01m-00005ebf` | `B_HOTEL2.MES:4501` |

Each route's `event_id` anchors the flow's own origin guard (`01M.MES:24255`,
hex8 `00005ebf`), the same convention A's rows use. Each of the three now
has a `kakyu_event_definition/v6` document
(`config/event_definitions/v6/mahoko.town.station.date-{town,date5,hotel}.1.json`),
projected by `tools/project_event_definition_v6.py` after `FLOW_SITES` and
the flow-document builder were generalized from a single hardcoded profile
stem/group id (`01m_a_date_v14`/`01m-a-date`) to a per-site table (this
unit's own change, reusable for C..L without further edits to the builder
itself) and after the v2 flow replay was written
(`analysis/replays_v2/01m_b_date_v14.json`, untracked). Hop counts match the
v14 profile's own route lengths one for one (23/21/23). All three documents
validate (`tools/validate_event_definition.py`).
