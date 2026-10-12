# MACHI caller group

Inventoried on 2026-09-12 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`MACHI.MES` is the town map, the `root_handoff_only` hub 147 callers hand
the root to and the root every map script hands it back to. It has four
unresolved EVENT intro sites for four targets: two root handoffs
(`EVENTG04`, `EVENTE18`) and two nested calls (`EVENTE04`, `EVENTE10`).
Three of the four stand behind the map's destination choice: `MACHI.MES`
itself asks no routine-40 question - it dispatches `MACHI.INC.MES` at
`20808` and reads the result back from `state_u16[21]`, branching on `0`
(E18, else the `44M.MES` handoff at `21230`), `9` (E04, then the `13C.MES`
handoff at `30797`), `26` (E10, then the `MIZUHO26.MES` handoff at `57269`)
and every other destination number down the script. G04 stands apart,
behind one flag. The instrument is the one that opened the earlier groups;
run first on `01M.MES`, it reproduces the 44C-era control exactly before it
is run here.

## The caller

| Property | `MACHI.MES` |
|---|---|
| framing-opaque bytes | **0 of 60,475** |
| instructions / branches / calls | 8,148 / 346 / 778 |
| address-table entries | 260 |
| EVENT intro sites | 4 unresolved, for four targets |
| intros with a typed guard candidate | **all 4** |
| dispatch form | 2 root handoffs, 2 nested calls |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTG04.MES` asks
its own routine-40 question at `9037` and hands the root back to `MACHI`
at `13664..13677`; `EVENTE18.MES` asks its own at `4095` and hands the root
to `44C.MES` (`4230..4241`) or `MACHI` (`4390..4403`) by the answer;
`EVENTE04.MES` and `EVENTE10.MES` return. `G_PIC` and `E_PIC` are the
picture scripts; no callee dispatches `TRAIN.MES`.

## The four intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---:|---:|---:|
| `EVENTG04` | `5927..5943` | root handoff | `4170..4181` | 13,693 | 11 | 162 |
| `EVENTE18` | `21184..21200` | root handoff | `20965..21038` | 4,527 | 20 | 50 |
| `EVENTE04` | `30260..30276` | nested call | `30035..30108` | 3,095 | 19 | 19 |
| `EVENTE10` | `57113..57129` | nested call | `56884..56945` | 2,941 | 8 | 20 |

## Four guards, four gaps

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---:|---:|:-:|---:|---:|---:|---:|---:|
| `EVENTG04` | `4170..4181` | `5948` | 1 | - | 1,746 | 227 | 7 | **0** | 0 |
| `EVENTE18` | `20965..21038` | `21215` | 11 | - | 146 | 30 | **0** | **0** | 0 |
| `EVENTE04` | `30035..30108` | `30782` | 11 | - | 152 | 30 | **0** | **0** | 0 |
| `EVENTE10` | `56884..56945` | `57254` | 9 | - | 168 | 30 | **0** | **0** | 0 |

G04's guard is one flag, `global_u8[1470] == 1`, reached after a
`global_u8[356] == 2` test at `4111`; its gap runs seven branches -
`state_u16[2] < 16` twice, the Christmas-date ladder (`12/24`, `13/01`,
neither), and a `global_u8[1389]` ladder (`0`, `1`) - before the handoff at
`5927`, and its false edge falls to the next flag guard at `5948`. The
three E intros each have a clean gap behind a typed guard whose first
conjunct is the destination number: E18's guard sits after the
constant-true record `20736` and the `MACHI.INC.MES` call, and its false
edge lands on `21215`, where `state_u16[21] == 0` alone hands the root to
`44M.MES`; E04's false edge lands on `30782`, where `== 9` alone hands off
to `13C.MES`; E10's on `57254`, where `== 26` alone hands off to
`MIZUHO26.MES`. So each E intro is the event that may play before the map
hands the root to the chosen destination, and its caller-side resume, for
the nested calls, is that handoff. The routes will take each intro's own
typed guard as origin with `state_u16[21]` seeded to the destination
number, the 44C convention, and G04's flag guard as origin with the gap's
branches swept.

## The guards, read as scene conditions

Weekday is `state_u16[4]`, the date `state_u16[7]` as MMDD, the clock
`state_u16[19]` as HHMM, `state_u16[21]` the destination number, and
`banked_u16[202]` the E family's affection word. Flags are `global_u8`.

| Intro | Destination | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|---|
| `EVENTG04` | - | - | - | `[1470]` | - |
| `EVENTE18` | `0` | weekday `0`, `date > 12/24`, `clock > 18:00` | `[202] > 90` | - | `[120]`, `[124]`, `[127]`, `[1792]`, `[1833]`, `[1918]` |
| `EVENTE04` | `9` | weekday `0`, `4/00 < date < 6/16`, `9:00 < clock < 20:01` | - | `[393]` | `[120]`, `[124]`, `[1833]`, `[1893]` |
| `EVENTE10` | `26` | `8/00 < date < 9/00`, `clock > 20:00` | - | - | `[120]`, `[124]`, `[127]`, `[1833]`, `[1904]` |

Read, not yet measured. The three E guards read the E family's cells -
`[393]` (23M's E01 and E03 prerequisite), `[120]`, `[124]`, `[127]`,
`[1833]`, `[1792]` (the clear flags of 17M's A08 and 21C's joint event) -
and each adds one flag of its own, `[1918]`, `[1893]`, `[1904]`, which their
callees' done-gates test at `234`, `234` and `225`. E18 is a winter night
after Christmas Eve with the E word above `90`, E04 a spring weekday-0
daytime, E10 an August night; E10's callee also gates on `banked_u16[204]`
in `41..100` at `118` before its own done-gate. G04's callee is the
largest on the map, 13,693 bytes with 162 message records, with `G_PIC`
twice and a three-answer question whose first two answers read
`banked_u16[204]` above `2`.

## EVENTE18: the winter night before the dormitory, and where `[372]` comes from

Measured 2026-09-12. `MACHI.MES:20965..21038` (false `21215`) wants
destination `0` read back from `MACHI.INC.MES`, weekday `0`, a date after
`12/24`, a clock after `18:00`, the E word `banked_u16[202]` above `90`,
and `[120]`, `[124]`, `[127]`, `[1792]`, `[1833]`, `[1918]` clear; sixteen
witnesses pin every edge, including destination `1`, and flip every flag.
The prefix is 6 messages through 30 records with no branch, and the
dispatch at `21184..21200` is a root handoff. `EVENTE18.MES` asks its own
routine-40 question at `4095` (two definitions, consumer the
`state_u16[21]` chain at `4110`), in the stored form the contract builder
supports, so both results are supplied, and its two answers leave by
different doors after the same 62 messages through `E_PIC.MES`: answered
`1` it hands the root to `44C.MES` at `4230..4241` - the dormitory - and
writes `global_u8[372] = 1`, the prerequisite 44C's `EVENTI24` and
`EVENTL25` guards require, along with `[126]`, `[244]`, `[3005] = 2`,
`[3475]`, `[4090]`, `[4091]`, `[5074]` and its done flag `[1918] = 1` at
`563`; answered `2` it hands the root back to `MACHI.MES` at `4390..4403`,
writing the same cells but `[286]` and the map word `banked_u16[242] = 44`
in place of `[372]`. Completion is callee-owned through `[1918]`; the guard
rejects on either post-replacement state, and a direct reentry passes the
done-gate to the constant-true record at `3971`, asks the question again,
and leaves by the same door after 3 messages. Segmented and unbroken runs
agree under both results (68 messages). With `global_u8[532] = 1` the
second answer takes a third arm at `4413` that loops back to the question
and reaches no terminal - measured, not declared. `state_u16[8]` and
`global_u8[4000]` are dead inputs; the Christmas ladder splits `13/01`;
`[3006]` and `[2847]` flip two arms each.

Declared as `machi_e18_v6.json` with the callee's contract, `E_PIC.MES`
and `44C.MES` among the members, two root-replacement routes over the one
guard by terminal - `machi-e18-result1` to `44C.MES` with 8 variants
and `machi-e18-result2` to `MACHI.MES` with 4 - `post_guard_expected`
0, the reentry each route's own handoff after 3 messages. Audit accepted;
`original event analysis MACHI E18` passes 343 checks; a wrong reentry
message count and the second door shifted one byte are rejected.

## EVENTG04: one flag, a seven-branch gap, and a question with three answers

Measured 2026-09-12. `MACHI.MES:4170..4181` (false `5948`, the next flag
guard) wants only `global_u8[1470] == 1`; two witnesses. The gap is the
map's longest - 227 records with seven branches, `state_u16[2] < 16`
twice, the Christmas ladder and a `global_u8[1389]` ladder - and every
arm reaches the root handoff at `5927..5943`, the ladder arms only
changing the prefix's length (12 messages at baseline, 16 with `[1389] =
1`, 8 with `2`); on the way the caller writes a run of `banked_u16` cells
and, at `5916..5922`, clears `[1470]` itself, so the guard is closed before
the callee runs - 18M I09's shape. `EVENTG04.MES`, the largest callee on
the map, runs through `G_PIC.MES` twice to its question at `9037` (three
definitions, consumer the `state_u16[21]` chain at `9047`), in the stored
form the contract builder supports, so all three results are supplied,
and every answer hands the root back to `MACHI.MES` at `13664..13677`
writing the same cells - `global_u8[108]`, `[244]`, `[286]`, `[2632]`,
`[3002]`, `[3528]`, `[5124]`, `[5125]`, `[5126]`, the map word
`banked_u16[242] = 36` - and differing in length and in the G word
`banked_u16[204]`: results `1` and `2` run 156 and 160 messages and take 2
behind a `> 2` gate, result `3` runs 144 and adds 2. The callee has no
done-gate of its own, so a direct reentry replays the whole event to the
same handoff; the guard rejects on the post-replacement state only because
the caller cleared its flag. Segmented and unbroken runs agree under every
result (168 / 172 / 156 messages). `state_u16[8]` is a dead input;
`[3006]` and `[2847]` flip two arms each.

Declared as `machi_g04_v6.json` with the callee's contract and `G_PIC.MES`
among the members, three root-replacement routes over the one guard -
`machi-g04-result1` with 9 variants, `-result2` with 3, `-result3`
with 2 - `post_guard_expected` 0, the reentry the handoff after the
whole event again. Audit accepted; `original event analysis MACHI G04`
passes 355 checks; a wrong callee message count on result 2 and result
3's handoff shifted one byte are rejected.

## EVENTE04 and EVENTE10: two nested calls the map follows by asking for a destination again

Measured 2026-09-12. `MACHI.MES:30035..30108` (false `30782`) wants
destination `9`, weekday `0`, `4/01..6/15`, `9:01..20:00`, `global_u8[393]`
set and `[120]`, `[124]`, `[1833]`, `[1893]` clear; sixteen witnesses pin
every edge, including destination `0`, and flip every flag. The prefix is 6
messages through 30 records with no branch and the dispatch at
`30260..30276` is a nested call. `EVENTE04.MES` runs 25 messages from `0`
and returns at `3063..3064`, writing `banked_u16[1] = 7`, `global_u8[244]`,
`[3000] = 2`, `[3005] = 15`, `[3239]`, `[3462]`, `[5061]`, `state_u16[8]` and
its done flag `[1893] = 1` at `756..762`. `MACHI.MES:56884..56945` (false
`57254`) wants destination `26`, an August night after `20:00`, and
`[120]`, `[124]`, `[127]`, `[1833]`, `[1904]` clear; fourteen witnesses.
Its prefix is 6 messages, the dispatch at `57113..57129` a nested call, and
`EVENTE10.MES` - which first tests the G word `banked_u16[204]` in
`41..100` at `118` to choose a prelude - runs 22 messages and returns at
`2909..2910`, writing `[121]`, `[148]`, `[3000] = 4`, `[3005] = 15`,
`[3467]`, `[5066]`, `state_u16[8]` and its done flag `[1904] = 1` at
`570..576`. Both callees close their own guard, and both reentries return
at once with **0 messages**.

Neither caller resumes into the handoff that lexically follows its
guard. After the event - E10's resume first runs `MONGEN.MES` at `57225` -
the map jumps through a shared tail at `60449` back to its own top. There
the destination menu `MACHI.INC.MES` is called at `20808` only when a menu
request is pending (`state_u16[17]`, copied from `[18]`, equal to the
sentinel `65534`); on every measured seed it is not, so the map skips the
call, resets `state_u16[21]` to `0` at `20852` and hands the root to
`44M.MES` at `21230..21241` - destination `0`'s target - after 12
messages for E04 and 0 for E10, having written a run of
`banked_u16` cells in the shared tail, among them the map word `[242]`
with the chosen destination's number, `13` after E04 and `26` after E10. That is the resume the routes
declare: the map going where destination `0` goes when nothing asks it to
show the menu. Whether the game shows the menu here instead, and the
`13C.MES` and `MIZUHO26.MES` handoffs behind `30782` and `57254` that a
repeated choice would reach, are not measured; with the sentinel forced,
the routine-18 call at `20803` exceeds the library step limit. Segmented
and unbroken runs agree on both. `state_u16[8]` and `global_u8[4000]` are
dead inputs; E04's clock ladders choose the later epilogue from `16:00`;
`[3006]` flips one arm in each.

Declared as `machi_e04_v5.json` and `machi_e10_v5.json` (with `44M.MES`
among the members and `MONGEN.MES` among E10's), one caller-continuation
route each with a `natural_handoff` resume to `44M.MES`, no post-guard
declaration since the callee closes the guard, 10 and 12
variants. Audits accepted; `original event analysis MACHI E04` passes
582 checks and `MACHI E10` 711; a wrong resume message count and the
handoff shifted one byte are rejected.

Every MACHI intro is measured and declared: four sites, four targets, four
groups, seven routes, no contract change. Read together, three of the
four are what the town map plays before it goes where the player chose -
and one of them, E18 answered `1`, is where the dormitory's own evenings
get their prerequisite - while G04 is the map's own event behind a flag it
clears itself.


## Arrival: the map's own poll, declared (2026-09-14, Core 0.319.0)

E04 and E10 were declared from their guards with `state_u16[21]` seeded and
the map cells `[17]` and `[18]` left at zero. Under Core 0.319.0 both start
at the map's entry `0` and supply the player's destination at the map's own
`Util(6,13)` poll, whose loop at `20736..20895` has the floors' shape: the
map runs `Util(6,8)`, copies `[17] = [18]`, calls `MACHI.INC.MES` and polls
at `20825` on a menu request (`[17] == 65534`), otherwise polls at `20844`,
copies `[21] = [18]`, waits and leaves the loop unless both cells are
`0xFFFF`; the destination cascade begins at `20965`.

That changes the resume. The 2026-09-12 reading - the shared tail at
`60449` returns to the top, the menu is skipped, `[21]` is reset and the
root goes to `44M.MES` at `21230`, destination `0`'s target - was the walk
with `[18]` at its unseeded `0`: when the map polled again after the event
the poll was omitted, `[21]` took `[18]`'s zero, and the map went where
destination `0` goes. With the arrival declared, the second poll is a
declared location too - the player still standing on the destination - so
the map plays the destination's own scene: `13C.MES` at `30797` after E04
(12 messages, as before) and `MIZUHO26.MES` at `57269` after E10 (0
messages, as before). Declared as `{MACHI.MES, 20844, [9, 9]}` and
`[26, 26]`, the first spent by the prefix and the second by the resume;
`machi_e04_v12.json` (402 checks) and `machi_e10_v12.json`
(470) replace the v5 profiles (`MONGEN.MES`, which E10's tail calls,
stays a member; `44M.MES` no longer is). Supplying the next destination
instead is rejected. Where the player walks to instead after the event, and
the menu path, are not declared; `MONGEN.MES` can hand the root to `44M.MES`
on its own branches, none of which these routes take.

E18 followed: its guard is destination `0`'s first branch, so the arrival
supplies `0` at the poll (`{MACHI.MES, 20844, [0]}`, spent by the prefix)
and the callee's own doors - `44C.MES` answered `1`, `MACHI.MES` answered
`2` - are unchanged; `machi_e18_v11.json` (480 checks) replaces the v6
profile with the 2026-09-12 declaration's variants carried over, and
destination `1` instead is rejected. G04 stays on its guard: its site at
`4170` lies on the map's entry path before the walk loop, so an arrival
origin would add no poll to it.

## Not measured here

What `MACHI.INC.MES` offers and how the destination numbers are chosen -
the menu path is not declared; what sets `[1470]`, `[393]`, `[532]` and
`[356]`; the flag guard at `5948` and the rest of the map below each intro;
G04 and E18, still declared from their guards; and the destinations past
every handoff. Which destination the player walked to is answered above:
the location supplied at the poll.
