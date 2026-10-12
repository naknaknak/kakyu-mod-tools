# 35M caller group

Inventoried on 2026-09-12 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`35M.MES` is named by no literal dispatch record: its only naming is a
command-`0x0E` record in `FLOOR5.MES`'s opaque tail (`FLOOR5.MES:4902..4913`),
so the classification carries it as a tail-named root. It is a caller
with three unresolved EVENT intro sites for three targets, `EVENTG02`,
`EVENTL02` and `EVENTI13`, every one a root handoff into a callee that
hands the root to `FLOOR5.MES`, and the last of the callers with three
unresolved intros. The three guards are one ladder: G02's false edge is
L02's guard and L02's is I13's. The instrument is the one that opened
the earlier groups; run first on `01M.MES`, it reproduces the 44C-era
control exactly before it is run here.

## The caller

| Property | `35M.MES` |
|---|---|
| framing-opaque bytes | **0 of 27,618** |
| instructions / branches / calls | 3,684 / 182 / 443 |
| address-table entries | 134 |
| EVENT intro sites | 3, for three targets |
| intros with a typed guard candidate | **all 3** |
| dispatch form | **all three root handoffs** |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTG02.MES` is
one body with a three-answer question at `2624` whose answers converge
on one door (`7238..7252 -> FLOOR5.MES`), and a first-visit arm at `1147`
that sets `[1391]` - the flag 30C's G01 sites require - and `[1377]`;
`EVENTL02.MES` is one body behind its own `[2041]` gate, which it sets at
`608` before its question at `4042`, again with three answers converging
on one door (`7671..7685`); `EVENTI13.MES` is one body behind `[1339]`
with no question and one door (`2889..2903`). All three stamp
`banked_u16[242] = 35` and set `state_u16[16] = 1` at their doors. No
callee dispatches a picture script or `TRAIN.MES`.

## The three intros

| Intro | Site | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---:|---:|
| `EVENTG02` | `3515..3531` | `3234..3334` | 7,308 | 27 | 78 |
| `EVENTL02` | `3769..3785` | `3546..3626` | 7,716 | 23 | 77 |
| `EVENTI13` | `4069..4085` | `3795..3897` | 2,909 | 7 | 26 |

## Three Saturday guards in one ladder

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---|---:|:-:|---:|---:|---:|---:|
| `EVENTG02` | `3234..3334` | `3546` | 15 | - | 181 | 31 | **0** | **0** | 0 |
| `EVENTL02` | `3546..3626` | `3795` | 12 | - | 143 | 29 | **0** | **0** | 0 |
| `EVENTI13` | `3795..3897` | `4095` | 15 | - | 172 | 30 | **0** | **0** | 0 |

The caller writes `[1751] = 1` and `[350] = 1` just before G02's guard,
outside the origins; every gap is presentation only, and after every
site a `continuation_transfer` leads to the caller's epilogue at
`27558`. G02's guard lists `[1467] == 0` twice.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`6` Saturday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM, and `banked_u16[204]`, `[209]`,
`[203]` the G, L and I families' affection words. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTG02` | Saturday, `4/01..6/15`, `15:01..17:29` | `[204] < 60` | - | `[140]`, `[144]`, `[1406]`, `[147]`, `[1467]`, `[1466]`, `[1468]`, `[1364]` |
| `EVENTL02` | Saturday, `4/01..6/15`, `12:30..16:00` | - | `[399]` | `[190]`, `[194]`, `[1966]`, `[197]`, `[2041]`, `[1925]` |
| `EVENTI13` | Saturday, `9/16..15/10`, `12:31..15:00` | `[203]` in `51..80` | - | `[130]`, `[137]`, `[134]`, `[1259]`, `[1301]`, `[1339]`, `[2624]`, `[2083]` |

Read, not yet measured. G02 is the G family's spring Saturday afternoon
with the G word below `60` and eight flags clear; its callee sets
`[1466]`, a conjunct of the guard, at its door and, on the first visit,
`[1391]` - which opens 30C's G01 - and moves the G word down two on
answers `1` and `2` and up one on answer `3`. L02 is the L family's
spring Saturday with `[399]` set; its callee sets its own gate `[2041]`
early and again at the door and moves the L word down two on answer `1`
and up one on answer `2`. I13 is the I family's autumn-to-winter
Saturday with the I word in `51..80`; its callee sets its own `[1339]`
and `[2624]`, both conjuncts of the guard.

## EVENTG02: the G family's spring Saturday afternoon, three answers to one door, the first visit opening G01

Measured 2026-09-13. `35M.MES:3234..3334` (false `3546`, L02's guard)
wants a Saturday late afternoon (`15:01..17:29`) from `4/01` to `6/15`,
the G word `banked_u16[204]` below `60`, and `[140]`, `[144]`, `[1406]`,
`[147]`, `[1467]`, `[1466]`, `[1468]`, `[1364]` clear; twenty-two witnesses
pin every edge and flip every flag, every rejection walking through
`N_PIC.MES` to the caller's own handoff. The caller's `[1751]` and `[350]`
writes lie before the origin; the prefix runs to the root handoff at
`3515..3531`. `EVENTG02.MES` has no gate of its own: on the first visit,
with `[1391]` clear, it sets `[1391]` - the flag 30C's G01 guards require -
and `[1377]` at `1650` and `1661`, runs 20 messages to its question at
`2624` (three definitions, consumer the `state_u16[21]` chain at `2634`),
and all three answers converge on the one door `7238..7252 ->
FLOOR5.MES` after 48, 48 and 41 messages: answers `1` and `2` move the G
word down two behind `> 2` gates the guard does not constrain (witnessed
at `2` and `3`), answer `3` moves it up one, and every answer writes
`[1466]` - a conjunct of the guard - the stamp `banked_u16[242] = 35`,
`state_u16[16] = 1`, `[3527]`, `[5123]` and `[286]`. The guard rejects on
every post-replacement state, and a direct reentry takes the return-visit
arm at `1677` to the door again after 44, 44 or 37 messages, moving the
word once more. Segmented and unbroken runs agree under every answer.
`state_u16[8]` is rewritten before it is read and `global_u8[4000]` reads
`0` at the callee's entry whatever is seeded; the clock ladder selects
`[3255]`; `[3006]` and `[2847]` flip presentation arms.

Declared as `35m_g02_v6.json` with the callee's contract, `N_PIC` and
`FLOOR5` among the members, three root-replacement routes by answer
sharing the one door with 42 variants in all, each naming its answer,
`post_guard_expected` 0, the reentry the door again with the word's
second move per route and per row. Audit accepted; `original event
analysis 35M G02` passes 1177 checks; a wrong callee message count and
the door shifted one byte are rejected.

## EVENTL02: the L family's spring Saturday, a gate set early, three answers to one door

Measured 2026-09-13. `35M.MES:3546..3626` (false `3795`, I13's guard)
wants a Saturday afternoon (`12:30..16:00`) from `4/01` to `6/15`,
`global_u8[399]` set, and `[190]`, `[194]`, `[1966]`, `[197]`, `[2041]`,
`[1925]` clear; seventeen witnesses pin every edge and flip every flag,
every rejection walking through `N_PIC.MES` to the caller's own handoff
at `27588..27602 -> FLOOR5.MES`. The prefix runs to the root handoff at
`3769..3785`. `EVENTL02.MES` counts `[244]` at its entry, sets its own
gate `[2041]` at `608` before a word is spoken, runs 44 messages to its
question at `4042` (three definitions, consumer the `state_u16[21]` chain
at `4052`), and all three answers converge on the one door `7671..7685
-> FLOOR5.MES`: answer `1` moves the L word `banked_u16[209]` down two
behind a `> 2` gate the guard does not constrain (witnessed at `2` and
`3`), answer `2` moves it up one, answer `3` leaves it; every answer then
writes `[2041]` again at `7630`, the stamp `banked_u16[242] = 35`,
`state_u16[16] = 1`, `[3654]`, `[5273]` and `[286]`. The guard rejects on
every post-replacement state, and a direct reentry counts `[244]` once
more before the done-gate at `234` returns it at `7715..7716` with **0
messages**. Segmented and unbroken runs agree under every answer.
`state_u16[8]` is rewritten before it is read and `global_u8[4000]` reads
`0` at the callee's entry whatever is seeded; the clock ladder selects
`[3284]`; `[3006]` and `[2847]` flip presentation arms.

Declared as `35m_l02_v6.json` with the callee's contract, `N_PIC` and
`FLOOR5` among the members, three root-replacement routes by answer
sharing the one door with 39 variants in all, each naming its answer,
`post_guard_expected` 0, the reentry the done-gate return with its
counter. Audit accepted; `original event analysis 35M L02` passes 1079
checks; a wrong callee message count and the door shifted one byte are
rejected.

## EVENTI13: the I family's autumn-to-winter Saturday, one door

Measured 2026-09-12. `35M.MES:3795..3897` (false `4095`) wants a
Saturday early afternoon (`12:31..15:00`) from `9/16` to `15/10`, the I
word `banked_u16[203]` in `51..80`, and `[130]`, `[137]`, `[134]`,
`[1259]`, `[1301]`, `[1339]`, `[2624]`, `[2083]` clear; twenty-two
witnesses pin every edge and flip every flag, every rejection walking
through `N_PIC.MES` to the caller's own handoff at `27588..27602 ->
FLOOR5.MES`. The prefix is 6 messages to the root handoff at
`4069..4085`. `EVENTI13.MES` runs to its one door `2889..2903 ->
FLOOR5.MES`, writing `[5101]`, `[3504]`, `[286]`, `state_u16[16] = 1`, the
stamp `banked_u16[242] = 35` and, at `2837` and `2848`, `[1339]` - its own
gate - and `[2624]`, both conjuncts of the guard; it never touches the I
word. The guard rejects on the post-replacement state and a direct
reentry returns through the done-gate at `2908..2909` with **0
messages**. Segmented and unbroken runs agree. `state_u16[8]` is
rewritten at `256` before it is read and `global_u8[4000]` reads `0` at
the callee's entry whatever is seeded; `[3006]` and `[2847]` flip one arm
each; the callee has no date or clock ladder of its own.

Declared as `35m_i13_v6.json` with no contract, `N_PIC` (reached only by
rejecting walks) and `FLOOR5` among the members, one root-replacement
route `35m-i13` with 12 variants, `post_guard_expected` 0, the
reentry the return record. Audit accepted; `original event analysis 35M
I13` passes 319 checks; a wrong callee message count and the door
shifted one byte are rejected.

Every 35M intro is measured and declared: three sites, three targets,
three groups, seven routes, no contract change - and with it every
caller that had three unresolved intros is closed. Read together, the
fifth floor's Saturdays are three families' first steps: G02's first
visit sets `[1391]` and opens 30C's art room, L02 closes itself before
speaking, and I13 closes two of its own conjuncts at its door; all three
leave the stamp `35`.

## Not measured here

What schedules `FLOOR5.MES:4902` into `35M.MES`; what sets `[399]` and
clears the twenty-two flags, and what moves the three affection words
outside these callees; what G02's and L02's questions offer as native
input (their results are supplied explicitly); and `FLOOR5.MES` past the
three doors.

## EVENTG02's revisit pass (measured 2026-09-23, EP-11)

`EVENTG02.MES` tests `global_u8[1391]` at `1147` (`== 0`, body `1158..1677`,
8 messages, writes the cell `1` at `1650`, then jumps past the next test) and
at `1677` (`== 1`, body `1678..`, 5 messages, no write, no dispatch) - an
if/else-if on the value the callee is entered with. Every committed route
enters with the cell `0`, so the second pass is declared by none; replayed
from a route's baseline with `[1391] = 1` it runs as stated. The caller's
guard at `35M.MES:3234` does not reject a visit carrying `[1391] = 1` (its
declared case `global_u8-1391-1` expects acceptance). Not established: that
`35M.MES` dispatches `EVENTG02.MES` again in natural play once the first
pass has set the cell.
