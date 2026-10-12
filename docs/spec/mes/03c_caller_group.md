# 03C caller group

Inventoried on 2026-09-12 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`03C.MES` is a root `03M.MES` hands off to (`03M.MES:19455`, command `0x0E`,
its only literal caller), the first of the callers with three unresolved
EVENT intro sites: `EVENTJ14` twice and `EVENTJ15` once, every one a root
handoff into a callee that hands the root to `MACHI.MES`. Both callees are
the J family's - the largest pair measured so far, 11,389 and 15,418 bytes
- and both ask their own routine-40 questions. The instrument is the one
that opened the earlier groups; run first on `01M.MES`, it reproduces the
44C-era control exactly before it is run here.

## The caller

| Property | `03C.MES` |
|---|---|
| framing-opaque bytes | **0 of 16,337** |
| instructions / branches / calls | 2,514 / 54 / 232 |
| address-table entries | 152 |
| EVENT intro sites | 3, for two targets (`EVENTJ14` twice) |
| intros with a typed guard candidate | **all 3** |
| dispatch form | **all three root handoffs** |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTJ14.MES` is two
bodies behind its own `global_u8[918]` test, each with a question and a
`MACHI.MES` handoff (`5042..5055`, `11365..11378`); `EVENTJ15.MES` is two
bodies behind `[824]`, the first with a three-answer question whose answers
leave by three doors (`6786..6799`, `9761..9774`, `11880..11893`) and the
second by a fourth (`15394..15407`). `J_PIC.MES` is the picture script; no
callee dispatches `TRAIN.MES`.

## The three intros

| Intro | Site | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---:|---:|---:|
| `EVENTJ14` (site A) | `10965..10981` | `10653..10670` | 11,389 | 31 | 130 |
| `EVENTJ14` (site B) | `11280..11296` | `10991..11008` | 11,389 | 31 | 130 |
| `EVENTJ15` | `14619..14635` | `13056..13141` | 15,418 | 27 | 177 |

## Two flag guards and one long one

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---:|---:|:-:|---:|---:|---:|---:|---:|
| `EVENTJ14` A | `10653..10670` | `10991` | 2 | - | 295 | 39 | **0** | **0** | 0 |
| `EVENTJ14` B | `10991..11008` | `11301` | 2 | - | 272 | 37 | **0** | **0** | 0 |
| `EVENTJ15` | `13056..13141` | `14640` | 8 | **yes** | 1,478 | 229 | 2 | 1 (`J_PIC`) | 0 |

J14's two sites are one flag and one counter: both want `global_u8[823]`
set, site A `global_u8[919]` below `3` and site B above `2`, and A's false
edge is B's guard. Between B's false edge at `11301` and J15's guard the
caller runs a `global_u8[350]` ladder (`0..7`) and a `[486]` test that
guard nothing of this group's; J15's gap holds a `state_u16[5]` arm, a
`[2847]` arm and a `J_PIC` call, and its false edge leaves the group at
`14640`.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`6` is Saturday), the date `state_u16[7]` as
MMDD, and `banked_u16[211]` the J family's affection word. Flags are
`global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTJ14` A | - | - | `[823]`, `[919] < 3` | - |
| `EVENTJ14` B | - | - | `[823]`, `[919] > 2` | - |
| `EVENTJ15` | Saturday, `date > 9/15` | `[211] > 50` | `[484]`, and one of `[905]`, `[907]`, `[910]`, `[875]`, `[912]`, `[922]` | `[212]`, `[214]`, `[823]` |

Read, not yet measured. The order is J15 first: its guard needs `[823]`
clear and both J14 sites need it set, so J15 - a Saturday from `9/16`
with the J word above `50`, `[484]` set and any one of six J flags set,
the first `or` over flags in a guard on this corpus - is what opens J14,
and `[919]` then counts J14's visits, site A for the first three and site
B after. Inside the callees the same cells recur: J14 gates on
`banked_u16[209]` in `41..100` at `118` before its done flag `[918]`, tests
`[916]` and `[919]` in its second body, and asks a question in each body;
J15's done-gate is `[823]` itself, its first body asks a question whose
three answers leave by three doors, with `banked_u16[211]` above `10` and
`[782]` read inside two of them, and its second body, behind `[824]`,
leaves by a fourth.

## EVENTJ14: two sites by the visit count, two bodies with a question each

Measured 2026-09-12. Site A's guard `03C.MES:10653..10670` (false `10991`,
site B's guard) wants `global_u8[823]` set and the visit count `[919]`
below `3`; site B's `10991..11008` (false `11301`) wants `[823]` set and
`[919]` above `2`; nine witnesses between them, including the count at
`2` and `3` crossing from one site to the other. Each prefix is 5
messages with no branch and each dispatch a root handoff. `EVENTJ14.MES`
first reads the L word `banked_u16[209]` in `41..100` at `118` to choose a
prelude (`[198]`), then splits on its own `[918]`: the first body asks a
question at `3256` (two definitions, consumer the `state_u16[21]` chain at
`3271`), and both answers run through `J_PIC.MES` to the same handoff
`5042..5055 -> MACHI.MES` after 62 or 58 messages, writing `banked_u16[1]
= 7`, `global_u8[198]`, `[216] = 4`, `[286]`, `[3722]`, `[5345]`, `[5347]`,
`[916]` and, at `4119`, its done flag `[918] = 1`. The callee writes
neither `[823]` nor `[919]`, so either site's guard still accepts on the
post-replacement state - `post_guard_expected` 1, as on 17M's A20 - and
what advances the visit count between visits lies outside the route. A
direct reentry enters the second body, which asks its own question at
`9561`; answered `1` it runs through `J_PIC` again to the second handoff
`11365..11378 -> MACHI.MES` after 48 messages from site A's state and 69
from site B's, since the second body reads `[916]` and `[919]` on the way.
Segmented and unbroken runs agree at both sites under both answers.
`state_u16[8]` and `global_u8[4000]` are dead inputs; `[212] = 1`, which
the callee never writes, skips a block in both bodies (51 messages on the
first visit, 37 and 58 on the second, declared as that variant's own
reentry); `[3006]` and `[2847]` flip one arm each; the L word below `41`
skips the prelude.

Declared as two groups on the A20 convention, `03c_j14a_v6.json` and
`03c_j14b_v6.json`, each with both contracts, `J_PIC` and `MACHI` among
the members, two root-replacement routes by the first body's answer -
`result1` and `result2`, 11 and 12 variants - each variant naming
both answers, `post_guard_expected` 1, the reentry the second body's
handoff under its own answer `1`. Audits accepted; `original event
analysis 03C J14A` passes 503 checks and `03C J14B` 565; a wrong
reentry message count and a shifted call record are rejected.

## EVENTJ15: the Saturday that opens J14, three answers by three doors

Measured 2026-09-12. `03C.MES:13056..13141` (false `14640`) wants Saturday,
a date from `9/16`, `global_u8[484]` set, any one of `[905]`, `[907]`,
`[910]`, `[875]`, `[912]`, `[922]` set - the first `or` over flags in a
guard on this corpus, each arm witnessed alone - the J word
`banked_u16[211]` above `50`, and `[212]`, `[214]`, `[823]` clear; nineteen
witnesses. The prefix runs a `state_u16[5]` arm, a `[2847]` arm and
`J_PIC.MES` to the root handoff at `14619..14635`. `EVENTJ15.MES`, the
largest callee measured, splits on its own `[824]`: the first body runs 57
messages to its question at `4660` (three definitions, consumer the
`state_u16[21]` chain at `4670`), and the three answers leave by three
doors to `MACHI.MES` - `6786..6799`, `9761..9774` through `J_PIC` again,
`11880..11893` - each writing `[823] = 1` on its way (`5837`, `8721`,
`10931`), the done flag that is also the flag both J14 sites require: J15
is what opens J14. The guard rejects on every post-replacement state and
a direct reentry returns at `15417..15418` with **0 messages**. With
`[824]` set the second body asks no question and leaves by a fourth door,
`15394..15407`, after 119 messages. Segmented and unbroken runs agree
under every answer. `state_u16[8]` and `global_u8[4000]` are dead inputs;
`[851]` at `2887`, `[782]` and `[2847]` select presentation; the
`banked_u16[211] > 10` gates inside answers `1` and `3` cannot fail under
the guard's `> 50` and are witnessed only by direct probes of the callee.

Declared as `03c_j15_v6.json` with the callee's contract, four
root-replacement routes over the one guard - `03c-j15-result1`,
`-result2`, `-result3` by door with 36 variants in all, and
`03c-j15-second` for the `[824]` body - `post_guard_expected` 0. Audit
accepted; `original event analysis 03C J15` passes 1000 checks; a wrong
callee message count and the third door shifted one byte are rejected.

Every 03C intro is measured and declared: three sites, two targets, three
groups, eight routes, no contract change. Read together, the map's two
events are one thread: J15's Saturday sets `[823]`, J14 needs it and
counts its visits in `[919]`, and both callees keep a second body for the
return visit.


## Not measured here

What schedules `03M.MES:19455` into `03C.MES`; what sets `[484]`, `[824]`
and the six J flags, and what advances the visit count `[919]` between J14's
visits; what the two callees' questions offer as native input (their
results are supplied explicitly); and `MACHI.MES` past every door.
