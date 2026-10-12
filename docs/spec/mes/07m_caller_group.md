# 07M caller group

Inventoried on 2026-09-12 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`07M.MES` is a root the town map hands off to (`MACHI.MES:55512`, command
`0x0E`, its only literal caller), a caller with three unresolved EVENT intro
sites for three targets: `EVENTA19`, `EVENTG14` and `EVENTJ19`, every one a
root handoff into a callee that hands the root back to `MACHI.MES`. Two of
the callees are large - 12,374 and 11,193 bytes - and the third is the
smallest measured on this tier; one of them asks its own question, and one
of the sites sits behind the caller's. The instrument is the one that
opened the earlier groups; run first on `01M.MES`, it reproduces the
44C-era control exactly before it is run here.

## The caller

| Property | `07M.MES` |
|---|---|
| framing-opaque bytes | **0 of 38,396** |
| instructions / branches / calls | 5,043 / 323 / 581 |
| address-table entries | 196 |
| EVENT intro sites | 3, for three targets |
| intros with a typed guard candidate | **all 3** |
| dispatch form | **all three root handoffs** |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTA19.MES` is
one body with one door (`12330..12343 -> MACHI.MES`) behind its own
`global_u8[1207]` gate, dispatching `P_PIC.MES` and `N_PIC.MES` on the
way; `EVENTG14.MES` is one body with one door (`3875..3888`) and no gate of
its own; `EVENTJ19.MES` is one body behind `[923]` with a three-answer
question at `6402` whose answers leave by three doors (`7677..7690`,
`9805..9818`, `11174..11187`). No callee dispatches `TRAIN.MES`.

## The three intros

| Intro | Site | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---:|---:|---:|
| `EVENTA19` | `606..622` | `531..601` | 12,374 | 19 | 148 |
| `EVENTG14` | `13920..13936` | `12152..12187` | 3,904 | 13 | 45 |
| `EVENTJ19` | `16784..16800` | `13946..14062` | 11,193 | 40 | 117 |

## One tight guard, one flag guard and one behind the caller's question

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---:|---:|:-:|---:|---:|---:|---:|
| `EVENTA19` | `531..601` | `627` | 10 | - | 5 | 1 | **0** | **0** | 0 |
| `EVENTG14` | `12152..12187` | `13946` | 5 | - | 1,733 | 254 | 4 | **0** | 0 |
| `EVENTJ19` | `13946..14062` | `18028` | 18 | - | 2,722 | 358 | 7 | **0** | 0 |

A19's dispatch follows its guard by five bytes. G14's gap holds two
`state_u16[5]` arms (the caller recomputes `[5]` from `banked_u16[2]`'s bit
`128` before each), a `[2847]` arm and a `[3006]` arm, and its false edge
is J19's guard. J19's gap holds a `[5]` arm, a `[3006]` arm and then the
caller's own routine-40 question at `15413` (consumer the `state_u16[21]`
chain at `15423`): answer `1` runs a `[2847]` arm and a `banked_u16[211] >
30` gate and reaches no event, answer `2` runs one more `[5]` arm and
hands off to `EVENTJ19` at `16784`, answer `3` runs its own `[211]` gate
at `17968` and reaches no event either. The instrument lists the chain's
`state_u16[21] == 2` test at `16355..16365` as a second guard candidate;
the origin is the outer guard, and the answer is the route's selection,
as on 21C's A08.

## The guards, read as scene conditions

Weekday is `state_u16[4]`, the date `state_u16[7]` as MMDD (months past
`12` are the following year's, as the callees' `13/01` ladders show), the
clock `state_u16[19]` as HHMM, and `banked_u16[211]` the J family's
affection word. Flags are `global_u8`.

| Intro | Calendar window | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|
| `EVENTA19` | `date == banked_u16[259]`, `18:01..21:59` | `[1205]`, `[260]` | `[1195]`, `[1207]`, `[1206]`, `[114]`, `[1034]` |
| `EVENTG14` | - | `[1484]`, `[1481]`, `[140]` | `[1482]`, `[1488]` |
| `EVENTJ19` | weekday `0`, `11/16 <= date <= 15/10`, `20:00..21:59` | `[926]`, `[823]`, `[802]`, `[401]` | `[210]`, `[212]`, `[215]`, `[217]`, `[214]`, `[812]`, `[957]`, `[923]`, `[784]` |

Read, not yet measured. A19 is the first guard on this corpus that
compares the date to a stored word rather than a literal: the evening
comes on whatever day `banked_u16[259]` holds, and its callee writes two of
the guard's clear flags, `[1207]` (its own gate) and `[1195]`, before the
door. G14 wants three flags and two clear ones, and its callee writes
`[1488]`, one of the two. J19 is a weekday-`0` evening from `11/16` that
needs `[823]` set - the flag `03C`'s J15 sets - and nine flags clear
including its own `[923]`; inside the callee each of the three answers
sets `[923]` and either `[812]` and `[214]` (answers `1` and `3`, behind a
`[211] > 10` gate that the guard does not constrain) or `[915]` and
`[210]` (answer `2`), and moves the J word.

## EVENTA19: an evening on a stored date, one door, two flags closed

Measured 2026-09-12. `07M.MES:531..601` (false `627`) wants the date
equal to the stored word `banked_u16[259]`, the clock `18:01..21:59`,
`global_u8[1205]` and `[260]` set, and `[1195]`, `[1207]`, `[1206]`,
`[114]`, `[1034]` clear; fourteen witnesses, the date equality pinned by
moving the word alone (reject) and the word with the date (accept), and
every rejection walking the rest of the floor to the caller's own handoff
at `38362..38375 -> MACHI.MES` after 18 messages. The dispatch follows
the guard by five bytes with no message. `EVENTA19.MES` runs 195 messages
through `P_PIC.MES` and `N_PIC.MES` to its one door `12330..12343 ->
MACHI.MES`, writing `banked_u16[1] = 7`, `global_u8[245]`, `[265]`,
`[286]`, `[3444]`, `[5045]`, the counters `[264]` and `[138]` by one, the A
word `banked_u16[201]` from `60` to `63` at `12299`, and at `12231` and
`12242` two conjuncts of the guard that admitted it: its own gate `[1207]`
and `[1195]`. The guard rejects on the post-replacement state and a direct
reentry returns at `12373..12374` with **0 messages**, the done-gate at
`219` skipping the whole body. Segmented and unbroken runs agree.
`state_u16[8]` and `global_u8[4000]` are rewritten before they are read;
`[2847]` flips three arms and `[3006]` two; the date ladders split `12/24`
and `13/01` from the rest; the `banked_u16[203]` gate at `12268` selects a
line only, the `[201]` write landing the same under `40`, `41`, `80` and
`81`.

Declared as `07m_a19_v6.json` with no contract, `P_PIC`, `N_PIC` and
`MACHI` among the members, one root-replacement route `07m-a19` with
13 variants, `post_guard_expected` 0, the reentry the return record.
Audit accepted; `original event analysis 07M A19` passes 365 checks; a
wrong callee message count and the door shifted one byte are rejected.

## EVENTG14: five flags, a callee with no gate of its own

Measured 2026-09-12. `07M.MES:12152..12187` (false `13946`, J19's guard)
wants `global_u8[1484]`, `[1481]` and `[140]` set and `[1482]`, `[1488]`
clear; nine witnesses, every rejection falling through J19's guard at
`13946` to the caller's own handoff at `38362..38375 -> MACHI.MES` after
18 messages. The prefix runs 29 messages of presentation arms - two
`state_u16[5]` arms the caller recomputes from `banked_u16[2]`'s bit
`128` just before each, a `[2847]` arm and a `[3006]` arm - to the root
handoff at `13920..13936`. `EVENTG14.MES` runs 59 messages to its one door
`3875..3888 -> MACHI.MES`, writing `banked_u16[242] = 7`, `global_u8[286]`,
the counter `[254]` by one, the clock word `banked_u16[293]` at `3809` with
the clock the run reached (`1215` from a noon start), and at `3824` its
done flag `[1488]`, a conjunct of the guard. The guard rejects on the
post-replacement state, but the callee has no gate of its own: a direct
reentry replays the whole body to the same door after 59 messages,
counting `[254]` to `2` and restamping `[293]` fifteen minutes on -
declared as the reentry with those values, per variant where the clock
differs. Segmented and unbroken runs agree. `state_u16[8]` is rewritten
before it is read and follows the date (`9`, `11` on `12/24`, `12` on
`13/01`); the clock ladder selects `[3258]` (`4`, `1`, `1`, `2`, `4` by
arm); `[2847]` flips two arms and `[3006]` one; `banked_u16[2]`'s bit
changes no callee arm; the caller's `[4000] = 1` at `12914` reads `0` at
the callee's entry, reset inside a shared routine the trace does not
record.

Declared as `07m_g14_v6.json` with no contract and `MACHI` among the
members, one root-replacement route `07m-g14` with 12 variants,
`post_guard_expected` 0, the reentry the door again with its own message
count and state. Audit accepted; `original event analysis 07M G14` passes
269 checks; a wrong reentry message count and the call record shifted
one byte are rejected.

## EVENTJ19: a winter evening behind the caller's question, three answers by three doors

Measured 2026-09-12. `07M.MES:13946..14062` (false `18028`) is eighteen
conjuncts: a weekday-`0` evening (`20:00..21:59`) from `11/16` to `15/10`,
`global_u8[926]`, `[823]` - the flag 03C's J15 sets - `[802]` and `[401]`
set, and `[210]`, `[212]`, `[215]`, `[217]`, `[214]`, `[812]`, `[957]`,
`[923]`, `[784]` clear; twenty-three witnesses, every rejection walking to
the caller's own handoff at `38362..38375 -> MACHI.MES`. Between the guard
and the site the caller runs a `[5]` arm and a `[3006]` arm, 20 messages,
and asks its own routine-40 question at `15413` (resume `15418`, three
definitions, consumer the `state_u16[21]` chain at `15423`): answers `1`
and `3` run their `banked_u16[211] > 30` gates, move the J word to `30`
and set `[210]` and `[812]`, and reach no event, ending at the same
`38362` handoff after 33 and 38 messages; answer `2` hands off to
`EVENTJ19.MES` at `16784..16800` with no guard cell written. The callee
runs 69 messages to its own question at `6402` (three definitions,
consumer the chain at `6412`), and the three answers leave by three doors
to `MACHI.MES` - `7677..7690`, `9805..9818`, `11174..11187` after 91, 109
and 91 callee messages - each writing at its door the done flag `[923]`
the guard requires clear, answers `1` and `3` also `[812]` and `[214]`
behind a `[211] > 10` gate and the J word down ten, answer `2` `[915]` and
`[210]` and the word up ten. The guard rejects on every post-replacement
state and a direct reentry returns at `11192..11193` with **0 messages**.
Segmented and unbroken runs agree under every answer. The `[211] > 10`
gates are real arms the guard does not constrain (`0`, `10`, `11`
witnessed); `state_u16[8]` and `global_u8[4000]` are rewritten before
they are read, the caller's `[4000] = 1` at `14274` reset inside a shared
routine; the seeded `banked_u16[2]` is overwritten by later caller writes
before the `[5]` recompute at `16701`; the callee rewrites `state_u16[2]`
before its own `< 16` loops; `[2847]` and `[3006]` flip two arms each and
the date ladders split `12/24` and `13/01`.

Declared as `07m_j19_v6.json` with both contracts - the caller's at
`15413` and the callee's at `6402` - and `MACHI` among the members, three
root-replacement routes over the one guard by the callee's answer with
51 variants in all, each variant naming both answers,
`post_guard_expected` 0, the reentry the return record. Audit accepted;
`original event analysis 07M J19` passes 1999 checks; a wrong callee
message count and the third door shifted one byte are rejected.

Every 07M intro is measured and declared: three sites, three targets,
three groups, five routes, no contract change. Read together, the map's
three events are three families' evenings on one floor: A19's stored
date, G14's five flags, and J19's winter weekday that 03C's J15 opens.


## Not measured here

What schedules `MACHI.MES:55512` into `07M.MES`; what stores the date in
`banked_u16[259]` and sets `[1205]`, `[260]`, the G flags `[1484]`,
`[1481]`, `[140]`, or J19's `[926]`, `[802]`, `[401]`; what the caller's
question at `15413` and the callee's at `6402` offer as native input
(their results are supplied explicitly); and `MACHI.MES` past every door.
