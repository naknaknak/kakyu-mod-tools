# 26M caller group

Inventoried on 2026-09-12 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`26M.MES` is, like `23M.MES`, a map root no strictly decoded dispatch names:
the one record naming it is a root handoff inside `GROUND.MES`'s opaque
tail (`66610..66621`, command `0x0E`), so the entry has no row of its own in
the route classification. It has four unresolved EVENT intro sites for four
targets, every one a root handoff, every callee handing the root back to
`GROUND.MES`. The instrument is the one that opened the earlier groups; run
first on `01M.MES`, it reproduces the 44C-era control exactly before it is
run here.

## The caller

| Property | `26M.MES` |
|---|---|
| framing-opaque bytes | **0 of 26,171** |
| instructions / branches / calls | 3,501 / 170 / 404 |
| address-table entries | 138 |
| EVENT intro sites | 4, for four targets |
| intros with a typed guard candidate | **all 4** |
| dispatch form | **all four root handoffs** |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. All four callees end
by handing the root to `GROUND.MES` - `EVENTC01.MES` at `4283..4297`,
`EVENTC04.MES` at `4254..4268`, `EVENTH06.MES` at `3961..3975`,
`EVENTC21.MES` at `4722..4736` - and C01 and C21 carry `C_PIC.MES` as a
second static dependency. `EVENTC01.MES` asks its own routine-40 question
at `1608`; the other three ask none. No callee dispatches `TRAIN.MES`.

## The four intros

| Intro | Site | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---:|---:|---:|
| `EVENTC01` | `843..859` | `561..655` | 4,303 | 19 | 39 |
| `EVENTC04` | `1872..1888` | `869..977` | 4,299 | 15 | 39 |
| `EVENTH06` | `3335..3351` | `1898..1990` | 4,006 | 24 | 34 |
| `EVENTC21` | `9788..9804` | `8122..8222` | 4,742 | 17 | 46 |

## A ladder of three and one more rung further down

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---:|---:|:-:|---:|---:|---:|---:|---:|
| `EVENTC01` | `561..655` | `869` | 14 | - | 188 | 35 | 1 | **0** | 0 |
| `EVENTC04` | `869..977` | `1898` | 13 | **yes** | 895 | 131 | 2 | 1 (`C_PIC`) | 0 |
| `EVENTH06` | `1898..1990` | `3366` | 14 | - | 1,345 | 186 | 1 | 1 (`H_PIC`) | 0 |
| `EVENTC21` | `8122..8222` | `9814` | 15 | - | 1,566 | 228 | **0** | 1 (`C_PIC`) | 0 |

C01's false edge is C04's guard and C04's is H06's; H06's falls to `3366`,
where seven more guards for the map's non-EVENT talk scripts (`M_TALK`,
`Q_TALK`, with their picture scripts) stand between it and C21's guard at
`8122`, whose false edge leaves the group at `9814`. The gaps carry no
second guard: C01's one branch tests `state_u16[5]` (a "seen this"
check), C04's two are a clock arm (`14:00..14:30`) that picks a prelude
and a `[2847]` presentation arm around a `C_PIC` call, H06's one is a
`[2847]` arm after `H_PIC`, and C21's gap holds only a `C_PIC` call.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`6` is Saturday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM, and `banked_u16[206]` the C
family's affection word. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTC01` | Saturday, `4/00 < date < 6/16`, `14:29 < clock < 16:30` | `[206] < 71` | `[396]` | `[160]`, `[164]`, `[167]`, `[1653]`, `[1694]`, `[1754]`, `[1755]` |
| `EVENTC04` | Saturday, `4/00 < date < 6/16`, `13:59 < clock < 14:31` **or** `17:29 < clock < 18:00` | `[206] < 71` | `[396]` | `[160]`, `[164]`, `[167]`, `[1653]`, `[1694]`, `[1755]`, `[1759]` |
| `EVENTH06` | Saturday, `4/00 < date < 6/16`, `15:30 < clock < 16:30` | - | `[2292]` | `[170]`, `[174]`, `[177]`, `[2083]`, `[2124]`, `[2167]`, `[2278]`, `[2299]` |
| `EVENTC21` | Saturday, `11/15 < date < 15/11`, `14:30 < clock < 16:30` | `[206] > 100` | `[396]`, `[1651]` | `[160]`, `[164]`, `[167]`, `[1653]`, `[1694]`, `[1755]`, `[1789]` |

Read, not yet measured. Three of the four are the C family's Saturdays
again, on 23M's pattern: C01 and C04 are spring afternoons below the
affection bar `71` - C01 at the same `14:30..16:29` as 23M's C02 and C05,
C04 in two slots on either side of it - and C21 the November afternoon
above `100`, one bar higher than 23M's C17 at `70`, with `[1651]` set in
place of C17's `[1778]`; all three share C10's prerequisite `[396]`, the
clear flags every C guard reads (`[1755]` among them, which every C event
sets), 44M C18's `[1653]`, and each adds its own flag - `[1754]`, `[1759]`,
`[1789]`. C01's guard falls straight into C04's, so a spring Saturday at
`14:30` tries C01 first and C04's slots never overlap it. `EVENTH06` is a
fourth family: a spring Saturday at `15:31..16:29`, `[2292]` set and eight
H flags clear, its callee reading `state_u16[5]` like the caller's own gap.

## EVENTC01: the spring ladder's first rung, with three answers that move the word

Measured 2026-09-12. `26M.MES:561..655` (false `869`, C04's guard) needs
Saturday, `4/01..6/15`, `14:30..16:29`, the affection word `banked_u16[206]`
below `71`, `global_u8[396]` set and `[160]`, `[164]`, `[167]`, `[1653]`,
`[1694]`, `[1754]`, `[1755]` clear; twenty witnesses pin every edge and
flip every flag. The prefix is 4 messages through 35 records with one
branch, `state_u16[5]` at `706`, which selects presentation only, and the
dispatch at `843..859` is a root handoff. `EVENTC01.MES` asks its own
routine-40 question at `1608` (three definitions, consumer the
`state_u16[21]` chain at `1618`), in the stored form the contract builder
supports, so all three results are supplied. Every answer runs through a
silent `C_PIC.MES` to the same handoff `4283..4297 -> GROUND.MES`, writes
the same cells - `banked_u16[1] = 7`, the map word `banked_u16[242] = 26`,
`global_u8[166] = 6`, `[286]`, `[3214]`, `[3568]`, `[5180]`, `state_u16[8]`,
its done flag `[1754] = 1` at `4236` and the C family's `[1755] = 1` - and
differs in length and in what it does to the word: result `1` runs 30
messages and adds 1 (`1907`), result `2` 34 and adds 2 (`2413`), result
`3` 37 and takes 2 (`2961`), the last behind a `> 2` gate at `2940` whose
both arms are witnessed since the guard admits `0..70`. Completion is
callee-owned twice over, and the done-gate at `224` sends a direct reentry
to the final return `4302..4303` with **0 messages**. Segmented and
unbroken runs agree under every result (34 / 38 / 41 messages). `state_u16[8]` and
`global_u8[4000]` are dead inputs; the clock ladders choose the later
epilogue from `16:00`; `[2847]` flips two arms.

Declared as `26m_c01_v6.json` with the callee's contract and `C_PIC.MES`
among the members, three root-replacement routes over the one guard -
`26m-c01-result1` with 12 variants, `-result2` with 4, `-result3`
with 6 - each variant naming its result, `post_guard_expected` 0. Audit
accepted; `original event analysis 26M C01` passes 581 checks; a wrong
callee message count on result 2 and result 3's handoff shifted one byte
are rejected.

## EVENTC21: the November rung, one bar higher than 23M's

Measured 2026-09-12. `26M.MES:8122..8222` (false `9814`) needs Saturday,
`11/16..15/10` under the owner's month-13 reading, `14:31..16:29`, the
affection word `banked_u16[206]` above `100` - 23M's C17 wanted above `70` -
`global_u8[396]` and `[1651]` set and `[160]`, `[164]`, `[167]`, `[1653]`,
`[1694]`, `[1755]`, `[1789]` clear; twenty-one witnesses pin every edge and
flip every flag. The prefix is 29 messages through 228 records with no
branch - a silent `C_PIC.MES` call among them - and the dispatch at
`9788..9804` is a root handoff, the last EVENT intro on the map, below
seven guards for the map's talk scripts. `EVENTC21.MES` runs 62 messages
from `0` through `C_PIC.MES` again to its handoff `4722..4736 -> GROUND.MES`,
writing `global_u8[286]`, `[3227]`, `[3583]`, `[5197]`, `[5198]`,
`state_u16[8]`, its done flag `[1789] = 1` at `4675`, the C family's
`[1755] = 1` at `4686` and the map word `banked_u16[242] = 26` at `4697`;
the word above `100` is read and not moved. Completion is callee-owned
twice over, and the done-gate at `224` sends a direct reentry to the final
return `4741..4742` with **0 messages**. Segmented and unbroken runs agree
(91 messages). `global_u8[4000]` is a dead input and `state_u16[8]` is
cleared before its own ladder and left at `46`, or `11` from `15:59`; the
clock ladder chooses the later epilogue from `16:00`, leaving `[3227]` at
`2`; `[3006]` and `[2847]` flip presentation arms.

Declared as `26m_c21_v6.json` with `C_PIC.MES` among the members, one
root-replacement route, `post_guard_expected` 0, thirteen variants. Audit
accepted; `original event analysis 26M C21` passes 313 checks; a wrong
reentry message count and the handoff shifted one byte are rejected.

## EVENTC04: the second rung, admitted in two slots

Measured 2026-09-12. `26M.MES:869..977` (false `1898`, H06's guard) is the
spring ladder's second rung, reached when C01's refused: Saturday,
`4/01..6/15`, the word `banked_u16[206]` below `71`, `global_u8[396]` set,
`[160]`, `[164]`, `[167]`, `[1653]`, `[1694]`, `[1755]`, `[1759]` clear, and a
clock in one of two slots, `14:00..14:30` **or** `17:30..17:59`;
twenty-five witnesses pin both slots' four edges and every flag. The
prefix runs a silent `C_PIC.MES`, picks a prelude by the slot at `982`,
and reaches the root handoff at `1872..1888` after 17 messages in either
slot. `EVENTC04.MES` runs 49 messages from `0` to its handoff `4254..4268
-> GROUND.MES`, writing `global_u8[128]`, `[286]`, `[3216]`, `[3571]`,
`[5183]`, `state_u16[8]`, the map word `banked_u16[242] = 26`, its done
flag `[1759] = 1` at `4176..4182` and the C family's `[1755] = 1`; the E
word `banked_u16[202]` in `31..100` at `4198` selects presentation only.
Completion is callee-owned twice over, and the done-gate at `224` sends a
direct reentry to the final return with **0 messages**. Segmented and
unbroken runs agree (66 messages) in both slots. `state_u16[8]` and
`global_u8[4000]` are dead inputs; the evening slot leaves `[3216]` at `2`;
`[3006]` flips `1396`.

Declared as `26m_c04_v6.json` with `C_PIC.MES` among the members, one
root-replacement route on the `14:00` slot with the `17:30` slot among its
fourteen variants, `post_guard_expected` 0. Audit accepted; `original
event analysis 26M C04` passes 341 checks; a wrong reentry message count
is rejected.

## EVENTH06: a fourth family's spring afternoon

Measured 2026-09-12. `26M.MES:1898..1990` (false `3366`) is the third rung:
Saturday, `4/01..6/15`, `15:31..16:29`, `global_u8[2292]` set and `[170]`,
`[174]`, `[177]`, `[2083]`, `[2124]`, `[2167]`, `[2278]`, `[2299]` clear;
nineteen witnesses pin every edge and flip every flag. The prefix runs
`H_PIC.MES`, branches on `[2847]` at `2693`, and reaches the root handoff
at `3335..3351` after 27 messages. `EVENTH06.MES` runs 48 messages from `0`
to its handoff `3961..3975 -> GROUND.MES`, writing `global_u8[286]`,
`[3265] = 2`, `[3601]`, `[5215]`, `state_u16[8]`, the map word
`banked_u16[242] = 26` and three of its own guard's flags - `[2167]`,
`[2278]` and its done flag `[2299] = 1` at `3925..3931`. Completion is
callee-owned three times over; the done-gate at `224` sends a direct
reentry to the final return with **0 messages**. Segmented and unbroken
runs agree (75 messages). `state_u16[8]` and `global_u8[4000]` are dead
inputs, and so is `state_u16[5]`: the callee recomputes it from
`banked_u16[2]` at `3315` before its own test at `3356`, so the true arm
needs bit 7 of that word, not measured here. Routine `9`, called at
`3351`, writes nothing measured; `[3006]` flips `2299`, `[2847]` flips the
caller's `2693` and the callee's `3583`.

Declared as `26m_h06_v6.json` with `H_PIC.MES` among the members, one
root-replacement route, `post_guard_expected` 0, eleven variants. Audit
accepted; `original event analysis 26M H06` passes 291 checks; the
handoff shifted one byte is rejected.

Every 26M intro is measured and declared: four sites, four targets, four
groups, six routes, no contract change. Read together, the map is the C
family's Saturday afternoons on 23M's pattern - every C callee sets
`[1755]` and writes the map word `26`, C01's three answers move the word
by `+1`, `+2`, `-2` - with one H-family afternoon beside them that closes
three of its own flags at once.


## Not measured here

What schedules `GROUND.MES:66610` into `26M.MES` and any of these guards;
what the question inside `EVENTC01` at `1608` offers as native input (its
three results are supplied explicitly); what sets `[396]`, `[1651]` and
`[2292]` and what clears `[1755]` between Saturdays; bit 7 of
`banked_u16[2]`, which H06's own test reads; and `GROUND.MES` past every
handoff.
