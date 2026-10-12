# 25C caller group

Inventoried on 2026-09-12 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`25C.MES` is named by no literal dispatch record in the archive: its only
naming is a command-`0x0E` record in `GROUND.MES`'s opaque tail
(`GROUND.MES:66574..66585`), so the classification carries it as a
tail-named root. It is a caller with three unresolved EVENT intro sites
for three targets: `EVENTF20` and `EVENTA03` as root handoffs into callees
that hand the root to `GROUND.MES` - the first group here whose doors lead
to the school ground rather than the town map - and `EVENTE05` as a
nested call the caller resumes after. `25C.MES` asks no routine-40
question of its own. The instrument is the one that opened the earlier
groups; run first on `01M.MES`, it reproduces the 44C-era control exactly
before it is run here.

## The caller

| Property | `25C.MES` |
|---|---|
| framing-opaque bytes | **0 of 23,962** |
| instructions / branches / calls | 3,237 / 157 / 372 |
| address-table entries | 135 |
| EVENT intro sites | 3, for three targets |
| intros with a typed guard candidate | **all 3** |
| dispatch form | F20 and A03 root handoffs, E05 a nested call |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTF20.MES` is
one body behind its own `global_u8[1648]` gate with one door
(`2957..2971 -> GROUND.MES`); `EVENTA03.MES` is one body behind `[1113]`
with a three-answer question at `1549` whose answers all converge on one
door (`9918..9932 -> GROUND.MES`), dispatching `E_PIC.MES` and `N_PIC.MES`
on every answer; `EVENTE05.MES` is one body behind `[1894]` with no
question and returns. No callee dispatches `TRAIN.MES`.

## The three intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---:|---:|---:|
| `EVENTF20` | `5771..5787` | root handoff | `4807..4889` | 3,002 | 29 | 21 |
| `EVENTA03` | `11207..11223` | root handoff | `10459..10587` | 9,948 | 25 | 120 |
| `EVENTE05` | `12669..12685` | nested call | `11233..11319` | 2,047 | 7 | 18 |

## Three guards, one reading the event stamp

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---|---:|:-:|---:|---:|---:|---:|
| `EVENTF20` | `4807..4889` | `5802` | 12 | - | 882 | 150 | **0** | 1 (`N_PIC`) | 0 |
| `EVENTA03` | `10459..10587` | `11233` | 18 | **yes** | 620 | 96 | **0** | 1 (`N_PIC`) | 0 |
| `EVENTE05` | `11233..11319` | `13100` | 13 | - | 1,350 | 195 | **0** | 1 (`N_PIC`) | 0 |

Every gap writes `[245] = 0` and dispatches `N_PIC.MES`; the `[350] = 1`
writes (and A03's `[2033] = 1`) sit just before each guard, outside the
origins. A03's false edge is E05's guard. After
E05 returns the caller writes `[1894] = 1` at `13062` (the flag the
callee itself sets at `548`), `[350] = 1` at `13073` and `[1112] = 1` at
`13084` - a clear conjunct of A03's guard, so E05 closes A03 - and
reaches a guard at `13100` (`date > 9/00`, `[260]`, `[263]`, `[1148]`,
`[1151]`) and a `P_PIC.MES` dispatch at `13181` in the file - but, as the
measurement below shows, the resume transfers past them to the shared
epilogue and a handoff.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`6` Saturday), the date `state_u16[7]` as MMDD,
the clock `state_u16[19]` as HHMM, `banked_u16[200]` and `[201]` the F
and A families' affection words, and `banked_u16[242]` the stamp every
measured callee writes at its door. Flags are `global_u8`.

| Intro | Calendar window | Affection / stamp | Must be clear (`== 0`) |
|---|---|---|---|
| `EVENTF20` | Saturday, `11/16..15/10`, `12:31..16:00` | `[200] > 80` | `[100]`, `[104]`, `[1545]`, `[107]`, `[1648]`, `[1504]` |
| `EVENTA03` | Saturday, `date < 6/16` **or** `> 9/15`, `12:30..14:30` | `[201]` in `31..60`, `[242] != 25` | `[110]`, `[112]`, `[1034]`, `[114]`, `[117]`, `[1059]`, `[1112]`, `[1113]`, `[240]`, `[243]`, `[994]` |
| `EVENTE05` | Saturday, `4/01..6/15`, `12:30..14:29` | - | `[240]`, `[243]`, `[120]`, `[124]`, `[1112]`, `[1833]`, `[1894]`, `[1792]` |

Read, not yet measured. None of the three needs a prerequisite flag set.
F20 is the F family's winter Saturday afternoon with the F word above
`80`; its callee reads the E word `[202]` in `31..100` at `123` to count
`[128]`, closes its own `[1648]` and stamps `[242] = 25`. A03 is the A
family's Saturday lunchtime outside the summer with the A word in
`31..60` and the stamp not `25` - the first guard here that reads the
stamp, so A03 cannot follow itself or F20 directly - and its callee moves
the E word down ten on answers `1` and `3` and up three (with the A word
up one) on answer `2`, closes its own `[1113]`, sets `[1112]` and stamps
`[242] = 25`. E05 is the E family's spring Saturday lunchtime with eight
flags clear; its callee sets its own `[1894]` at `548`, before any
message, and the caller sets it again after the return.

## EVENTF20: the F family's winter Saturday, one door to the ground

Measured 2026-09-12. `25C.MES:4807..4889` (false `5802`) wants a
Saturday afternoon (`12:31..16:00`) from `11/16` to `15/10`, the F word
`banked_u16[200]` above `80`, and `[100]`, `[104]`, `[1545]`, `[107]`,
`[1648]`, `[1504]` clear; eighteen witnesses pin every edge and flip
every flag, every rejection walking to the caller's own handoff at
`23932..23946 -> GROUND.MES`. The caller's `[350]` write at `4791` lies
before the origin; the prefix runs 25 messages through `N_PIC.MES`,
writing `[245] = 0`, to the root handoff at `5771..5787`. `EVENTF20.MES`
first reads the E word `[202]` in `31..100` at `123` to count `[128]`,
then runs 29 messages to its one door `2957..2971 -> GROUND.MES`, writing
`[5015]`, `[3414]`, `[286]`, at `2818` its done flag `[1648]` - a conjunct
of the guard - and the stamp `banked_u16[242] = 25`; it touches neither
affection word. The guard rejects on the post-replacement state, and a
direct reentry counts `[128]` once more before the done-gate at `235`
returns it at `3001..3002` with **0 messages** - declared as the
reentry with that count, and without it on the rows where the E word
lies outside the gate. Segmented and unbroken runs agree. `state_u16[8]`
is rewritten at `272` before it is read and `global_u8[4000]` reads `0`
at the callee's entry whatever is seeded; the clock ladders select
`[3253]` (`16:00` flips ten arms); `[3006]` flips two arms and `[2847]`
none.

Declared as `25c_f20_v6.json` with no contract, `N_PIC` and `GROUND`
among the members, one root-replacement route `25c-f20` with 16
variants, `post_guard_expected` 0, the reentry the return record with its
counter. Audit accepted; `original event analysis 25C F20` passes 383
checks; a wrong reentry message count and the door shifted one byte are
rejected.

## EVENTA03: the A family's Saturday lunchtime, three answers to one door, a guard on the stamp

Measured 2026-09-12. `25C.MES:10459..10587` (false `11233`, E05's guard)
is eighteen conjuncts with an `or`: a Saturday lunchtime (`12:30..14:30`)
on a date before `6/16` or after `9/15`, the A word `banked_u16[201]` in
`31..60`, the stamp `banked_u16[242]` not `25`, and eleven flags clear;
twenty-eight witnesses pin every edge, both date windows and the stamp
at `24` and `25`. The caller's `[350]` and `[2033]` writes at `10432` and
`10443` lie before the origin; the prefix runs `N_PIC.MES` and writes
`[245] = 0` to the root handoff at `11207..11223`. `EVENTA03.MES` runs 15
messages to its question at `1549` (three definitions, consumer the
`state_u16[21]` chain at `1559`), and all three answers run through
`E_PIC.MES` and `N_PIC.MES` to the one door `9918..9932 -> GROUND.MES`:
answers `1` and `3` move the E word `[202]` down ten behind `> 10` gates
the guard does not constrain (witnessed at `10` and `11`), answer `2`
moves it up three, the A word up one and sets `[1114]`; every answer
then writes `[1113]` (its own gate) and `[1112]`, two conjuncts of the
guard, `[3432]`, the stamp `[242] = 25` - the value the guard refuses -
and `[286]`. The guard rejects on every post-replacement state, and
because the done-gate at `219` lands past the flag writes, a direct
reentry hands off again at `9918` with **0 messages** and no change.
Segmented and unbroken runs agree under every answer. `state_u16[8]` is
rewritten before it is read and `global_u8[4000]` reads `0` at the
callee's entry whatever is seeded (answer `2` writes it at `4704`); the
callee has no date ladder; `[2847]` and `[3006]` flip presentation arms.

Declared as `25c_a03_v6.json` with the callee's contract, `N_PIC`,
`E_PIC` and `GROUND` among the members, three root-replacement routes by
answer sharing the one door with 45 variants in all, each naming its
answer, `post_guard_expected` 0, the reentry the door again. Audit
accepted; `original event analysis 25C A03` passes 1053 checks; a wrong
callee message count and the door shifted one byte are rejected.

## EVENTE05: the E family's spring Saturday, a callee that closes itself at once, a resume to the ground

Measured 2026-09-12. `25C.MES:11233..11319` (false `13100`) wants a
Saturday lunchtime (`12:30..14:29`) from `4/01` to `6/15` and `[240]`,
`[243]`, `[120]`, `[124]`, `[1112]`, `[1833]`, `[1894]`, `[1792]` clear;
eighteen witnesses pin every edge and flip every flag, every rejection
walking to the caller's handoff at `23932..23946 -> GROUND.MES`. The
prefix runs `N_PIC.MES`, writing `[245] = 0`, to the nested call at
`12669..12685`. `EVENTE05.MES` sets its own gate `[1894]` at `548` before
its first message, runs 24 messages writing `[5062]` and `[3463]`, and
returns at `2040..2041`; it reads no affection word. The caller's resume
from `12685` sets `[1894]` again, `[350]` and `[1112]` - a conjunct of
A03's guard, so E05 closes A03 - and then transfers from `13095` to the
shared epilogue at `23907`, which stamps `banked_u16[242] = 25`, writes
`[286]` and hands the root to `GROUND.MES` at `23932..23946` after 12
messages: a natural handoff. The guard at `13100` and the `P_PIC.MES`
dispatch at `13181` that follow the call in the file are not on this
path, and dropping `P_PIC` from the package changes nothing. The guard
rejects on the resumed state, and both reentries return through the
done-gate at `2046..2047` with **0 messages**. Segmented and unbroken
runs agree. `state_u16[8]` is rewritten at `256` before it is read and
`global_u8[4000]` reads `0` at the callee's entry whatever is seeded;
`[2847]` and `[3006]` flip one arm each; the E word at `0` and `100`
changes nothing.

Declared as `25c_e05_v5.json` with no contract, `N_PIC` and `GROUND`
among the members, one continuation route `25c-e05` with 10 variants,
the resume on the `natural_handoff` policy ending at the caller's
`23932` handoff with the caller's writes and the stamp in its expected
state, the reentry the done-gate return. Audit accepted; `original event
analysis 25C E05` passes 337 checks; a wrong resume message count and
the call record shifted one byte are rejected.

Every 25C intro is measured and declared: three sites, three targets,
three groups, five routes, no contract change. Read together, the floor
is one thread on the stamp: F20 and A03 both leave `[242] = 25` at their
doors and E05's resume leaves it too, and A03's guard refuses exactly
that value, so A03 can follow none of them directly.

## Not measured here

What schedules `GROUND.MES:66574` into `25C.MES`; what moves the F, A and
E words outside these callees and what clears the flags; what A03's
question offers as native input (its results are supplied explicitly);
and `GROUND.MES` past the two doors and the resume's handoff.
