# 01M caller group: every intro measured, six qualified

Measured on 2026-09-10 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`01M.MES` is the station script. Two of its nine EVENT intros were qualified
before this group opened - `EVENTB03` through the
[station candidate documents](station_candidate_priority.md) and `EVENTJ04`
through its [route document](eventj04_route.md) - and those two are the
controls for the measurements below: every coordinate and conjunct recorded for
J04 reproduces exactly. This document inventories the group and qualifies its
remaining routes as they land. **`EVENTD05`**, **`EVENTG11`**, **`EVENTI16`** and
**`EVENTL03`** are qualified below; **`EVENTH07`**, **`EVENTM06`** and
**`EVENTM09`** are measured to one native boundary, `TRAIN.MES:861`, and not
qualified. Every intro in the caller is measured. (Since 2026-09-14 the
three are qualified through the train's map-location contract - Core
0.318.0 - and every intro in the caller is declared.)

## Why this group is the next terrain

| Property | `44M.MES` | `01M.MES` | `FLOOR5.MES` |
|---|---|---|---|
| framing-opaque bytes in the caller | 0 of 66,047 | **0 of 89,510** | 0 of 10,126 (three preserved opaque boundary records, 2,261 bytes) |
| EVENT intro sites | 11 | 9 (2 already qualified) | 7 |
| intros with a typed guard candidate | all 11 | **all 9** | 5 of 7 |
| framing-opaque bytes in the callees | 0 | **0** | 0 |

`01M.MES` has 11,536 instructions, 560 branches, 1,375 calls and a 426-entry
address table. Two callees, `EVENTH07.MES` and `EVENTM06.MES`, each carry one
preserved opaque boundary record (`8361..8792`, 431 bytes, and `645..933`, 288
bytes); those are byte-preserving boundaries inside a fully framed entry, not
framing failures, and the guards below do not depend on them.

## Two cascades

The station script is one ordered cascade of guards whose false edges chain
into one another. The first fifteen, `0x026D..0x7691`, are the
[candidate priority cascade](station_candidate_priority.md); `EVENTH07`'s
dispatch sits inside the body of its first candidate. The B03 guard at `30353`
(`0x7691`) begins a second cascade of eight event guards, and each guard's
false target is the next guard:

| Order | Guard | False target | Intro |
|---:|---|---:|---|
| 1 | `30353..30449` | `30889` | `EVENTB03` (already qualified) |
| 2 | `30889..30944` | `35012` | `EVENTM06` |
| 3 | `35012..35060` | `39564` | `EVENTM09` |
| 4 | `39564..39618` | `39839` | `EVENTJ04` (already qualified) |
| 5 | `39839..39941` | `40556` | `EVENTD05` |
| 6 | `40556..40606` | `40825` | `EVENTI16` |
| 7 | `40825..40919` | `43507` | `EVENTG11` |
| 8 | `44573..44674` | `47031` | `EVENTL03` |

Six of the eight intros are command-`0x0E` root handoffs, so the first true
guard whose body reaches its dispatch takes control away from the station.
`EVENTM06`, `EVENTM09` and `EVENTL03` are command-`0x0F` nested calls and the
caller resumes after them. What runs between `43507` and the L03 guard at
`44573` is not part of any intro's gap and is not measured here.

## The nine intros

| Intro | Site | Form | Callee size | Callee branches | Callee messages | Root handoff in callee |
|---|---|---|---:|---:|---:|---|
| `EVENTH07` | `6076..6092` | root handoff | 15,923 | 33 | 172 | `15904..15917 -> MACHI` |
| `EVENTB03` | `30863..30879` | root handoff | 15,710 | 32 | 174 | three, all `-> MACHI` |
| `EVENTM06` | `32882..32898` | nested call | 8,910 | 32 | 78 | none |
| `EVENTM09` | `37066..37082` | nested call | 6,211 | 17 | 64 | none |
| `EVENTJ04` | `39813..39829` | root handoff | 1,842 | 9 | 20 | `1823..1836 -> MACHI` |
| `EVENTD05` | `40530..40546` | root handoff | 5,976 | 26 | 62 | `5947..5960 -> MACHI` |
| **`EVENTI16`** | **`40799..40815`** | **root handoff** | **2,863** | **19** | **16** | **`2819..2832 -> MACHI`** |
| `EVENTG11` | `43481..43497` | root handoff | 3,358 | 5 | 37 | `3289..3302 -> MACHI` |
| `EVENTL03` | `45057..45073` | nested call | 2,338 | 20 | 12 | none |

## Which intros are cleanly guarded

Measured over all nine intros with the same instrument as the 44M group: the
conjunct count of the eligibility guard, whether it contains a disjunction,
and what stands between the guard's true edge and the dispatch.

| Intro | Guard | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---:|:---:|---:|---:|---:|---:|---:|
| `EVENTH07` | `621..675` | 7 | - | 5,401 | 697 | 13 | 4 | 1 |
| `EVENTB03` | `30353..30449` | 14 | - | 414 | 57 | **0** | **0** | 0 |
| `EVENTM06` | `30889..30944` | 8 | - | 1,938 | 268 | 2 | 1 | 1 |
| `EVENTM09` | `35012..35060` | 7 | - | 2,006 | 251 | 2 | 1 | 1 |
| `EVENTJ04` | `39564..39618` | 8 | - | 195 | 34 | **0** | **0** | 0 |
| `EVENTD05` | `39839..39941` | 15 | - | 589 | 75 | **0** | **0** | 0 |
| **`EVENTI16`** | **`40556..40606`** | **7** | - | **193** | **34** | **0** | **0** | **0** |
| `EVENTG11` | `40825..40919` | 14 | - | 2,562 | 334 | 4 | 1 | 0 |
| `EVENTL03` | `44573..44674` | 14 | **yes** | 383 | 64 | **0** | **0** | 0 |

Five intros have nothing conditional between guard and dispatch. `EVENTG11`'s
four in-gap branches all have false edges landing **before** its dispatch and
its one in-gap dispatch is a `G_PIC.MES` nested call, so by the reading the 44M
group settled on it is cleanly guarded too. `EVENTL03` has the first
disjunction in this caller: its first conjunct is `weekday == 0 or date ==
1224`.

### Three intros stand behind the caller's own selection

`EVENTH07`, `EVENTM06` and `EVENTM09` have three guard candidates each, and
they are the shape the 44M group met at `EVENTL10`:

| Intro | Eligibility guard | Constant-true record | Result gate |
|---|---|---|---|
| `EVENTH07` | `621..675` | `3800..3807` (false `9326`) | `3942..3952`: `state_u16[21] == 1` (false `6102`) |
| `EVENTM06` | `30889..30944` | `32494..32501` (false `34985`) | `32640..32650`: `state_u16[21] == 1` (false `33837`) |
| `EVENTM09` | `35012..35060` | `36312..36319` (false `39537`) | `36458..36468`: `state_u16[21] == 1` (false `38091`) |

The constant-true record is the trap already recorded for GROUND's `5860` and
44M's `65342`: it is measured as the literal `1` and must not be declared as
a guard. The result gate requires the caller's own routine-40 selection to
have been answered **1**, so these three events are reached through a player
choice at the station, and each gap also holds a `?_PIC.MES` nested call
before the selection. The one edge entering each of those gaps from outside
lands on the constant-true record, from `9321`, `34980` and `39532`
respectively: measured below for M06 and M09, it is the gate's false path
re-asking the selection when the result is neither `1` nor `2`.
`EVENTH07`'s thirteen in-gap branches all land before its dispatch.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`6` is Saturday), the date is `state_u16[7]` as
MMDD, the clock is `state_u16[19]` as HHMM, and `banked_u16[200..211]` are the
per-heroine affection words. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTH07` | date `== banked_u16[268] + 1`, `09:30 < clock < 11:00` | - | `global_u8[2300]`, `[2301]` | `[2304]`, `[2305]` |
| `EVENTB03` | `4/00 < date < 6/16`, `18:00 < clock < 20:01`, `state_u16[12] != 0` | `40 < banked_u16[210] < 80` | `[400]` | `[333]`, `[200]`, `[205]`, `[631]`, `[628]`; `[207] != 2` |
| `EVENTM06` | weekday `0`, `6/15 < date < 9/16`, `clock < 16:00` | - | `[2420]` | `[150]`, `[2439]`, `[2437]` |
| `EVENTM09` | weekday `0`, `date > 7/15`, `clock < 16:00` | - | `[2420]` | `[150]`, `[2439]`, `[2442]` |
| `EVENTJ04` | weekday `0`, `18:00 < clock < 22:00` | - | `[401]` | `[210]`, `[212]`, `[905]`, `[955]` |
| `EVENTD05` | weekday `0`, `4/00 < date < 6/16`, `08:00 < clock < 16:01` | `50 < banked_u16[212] < 80` | `[402]` | `[220]`, `[224]`, `[225]`, `[227]`, `[753]`, `[778]`, `[678]` |
| **`EVENTI16`** | **Saturday, `9/15 < date < 15/11`, `13:59 < clock < 16:31`** | - | - | **`[130]`, `[1342]`** |
| `EVENTG11` | weekday `0`, `10/00 < date < 11/16`, `09:00 < clock < 16:00` | `banked_u16[204] > 70` | - | `[140]`, `[144]`, `[145]`, `[1406]`, `[147]`, `[1372]`, `[1481]`, `[1364]` |
| `EVENTL03` | weekday `0` **or** date `12/24`; `4/00 < date < 6/16`, `10:00 < clock < 16:01` | `banked_u16[209] > 35` | `[399]` | `[190]`, `[194]`, `[197]`, `[2042]`, `[2043]`, `[1966]`, `[1925]` |

Two things in that table are measured rather than read. `EVENTH07` is the only
intro whose date test is relative: the date must equal a stored word plus one,
so the event opens the day after whatever wrote `banked_u16[268]`. `EVENTI16`
is the only intro that requires Saturday; every other weekday test in the
caller requires `0`. Date values above `1231` occur in the archive and are not
explained by any measurement; `EVENTI16`'s upper bound `1511` is recorded as
measured. The owner's reading, recorded 2026-09-10 as a **presumption**, is
that the game's calendar continues past December into a thirteenth month and
beyond, so `1511` would be the eleventh day of month 15 and the 44M I14
window `1307..1510` would be a second season after the first; nothing here
measures that.

`EVENTM06` and `EVENTM09` share the prerequisite `global_u8[2420]` and the
clear flags `[150]` and `[2439]`, and their date windows overlap from `7/16`
to `9/15`; which one a weekday-`0` afternoon in that overlap reaches is decided
by cascade order, M06 first. Only `6` has a documented weekday name here. `EVENTL03` shares `global_u8[399]`, `[190]`, `[194]`,
`[197]`, `[1966]`, `[2042]` and `banked_u16[209]` with 44M's `EVENTL10` guard;
the two are different windows on the same prerequisite set.

## EVENTI16: the Saturday intro

Measured 2026-09-10. This is the first route qualified from the group: the
smallest cleanly guarded root handoff, and the only intro in the caller that
opens on a Saturday.

### The guard is seven typed conjuncts

`01M.MES:40556..40606` is a `branch_if_not_true` whose false edge is `40825`,
the G11 guard. Its predicate:

| # | Conjunct | Read as |
|---:|---|---|
| 1 | `state_u16[4] == 6` | Saturday |
| 2 | `state_u16[7] > 915` | after 9/15 |
| 3 | `state_u16[7] < 1511` | before the unexplained `1511` |
| 4 | `state_u16[19] > 1359` | after 13:59 |
| 5 | `state_u16[19] < 1631` | before 16:31 |
| 6 | `global_u8[130] == 0` | flag clear |
| 7 | `global_u8[1342] == 0` | the event's own completion flag clear |

Between the guard's true fallthrough at `40606` and the handoff at `40799`
there are 34 records and no conditional structure, so the guard is the only
local eligibility condition. Thirteen witnesses pin every boundary:

| Case | Value | Guard |
|---|---|---|
| baseline (Saturday, `10/01`, `15:00`, both flags clear) | - | **accept** (falls through to `40606`) |
| `state_u16[4]` | 0 / 5 | reject -> `40825` |
| `state_u16[7]` | 915 | reject |
| `state_u16[7]` | **916** / **1510** | **accept** |
| `state_u16[7]` | 1511 | reject |
| `state_u16[19]` | 1359 | reject |
| `state_u16[19]` | **1360** / **1630** | **accept** |
| `state_u16[19]` | 1631 | reject |
| `global_u8[130]` | 1 | reject |
| `global_u8[1342]` | 1 | reject |

Five accepting and eight rejecting witnesses; every accepting run has the same
prefix hash and the same 6 caller messages.

### The route

With the guard accepted the caller emits 6 messages and reaches the
command-`0x0E` handoff `40799..40815`. This is a root replacement, so there is
no caller resume. `EVENTI16.MES` runs 20 messages from `0` and ends at its
one root-handoff terminal, `2819..2832 -> MACHI.MES`; it contains no
routine-40 selection, so this is one route. Running the caller prefix to the
handoff and then the callee from `0` with the carried state reaches the same
record with the same state and the same message bytes as the unbroken chain.

The callee's measured effects are `global_u8[1342] = 1`, `global_u8[244] = 1`,
`global_u8[286] = 1`, `global_u8[3503] = 1`, `global_u8[5100] = 1`,
`banked_u16[1] = 7` and `banked_u16[242] = 1`, plus two cells that depend on
the clock, below.

### The window straddles the callee's 16:00 band

The callee tests the clock in three identical four-step ladders at `600`,
`900`, `1600` and `1800` (branches `450..555`, `699..873` and `2680..2761`),
selecting a time-of-day band for its presentation. The guard admits `14:00`
to `16:30`, which crosses the `1600` step. Before `16:00` the `< 1600` arm
holds in all three ladders and the callee writes `global_u8[3274] = 1` and
`state_u16[8] = 46`; at `16:30` branches `512`, `807` and `2726` fall to the
`< 1800` arm, `global_u8[3274]` ends at `2` and `state_u16[8]` stays `0`.
Messages, terminal and every other effect are unchanged. That is one route
with a time-band split inside its own window, and the group declares both
bands.

### Two callee inputs are dead, and two are live

Of the cells the callee's branches test, `state_u16[8]` is overwritten to `0`
at `271..276` immediately before the `276` test - the entry-overwritten
pattern already recorded for EVENTB03's slot 8 and EVENTC18 - so branches
`331` and `386` are unreachable from any seeded value. `global_u8[4000]` is
cleared as a side effect of `LIBLARY.LIB` routine 28, called at `261` (resume
`266`) before the `595` test and again at `664`, `2109` and `2287`; a seeded
`1` survives the caller prefix and reads `0` the moment that routine returns.
`global_u8[3006] = 1` flips `964` and leaves `global_u8[3005]` at `15` instead
of `0`; `global_u8[2847] = 1` flips `2179` and changes nothing else. Across the
nine variants 17 of the callee's 19 branches are exercised; only `331` and
`386` are not, for the reason above.

### The completion predicate is callee-owned

Evaluated against the state the callee leaves, the guard is **false**: only
conjunct 7 fails, and `global_u8[1342]` is the one guard cell the callee
writes, at `2783..2789`. The event closes itself, the L10 shape rather than
C18's caller-owned one. Re-entering `EVENTI16.MES` from `0` with that state
emits **0 messages**: its first branch `234` tests the same flag, jumps to
`2837`, increments `global_u8[244]` to `2`, writes `state_u16[2] = 1` and
returns at `2862..2863` instead of reaching the MACHI handoff.

### What this does not establish

- No catalog entry, preset or playback support is added.
- Natural scheduling into `40556` is not established: it is the sixth guard of
  the station's second cascade and is reached only when the B03, M06, M09,
  J04 and D05 guards before it are all false.
- What sets `global_u8[130]`, and what the date values above `1231` admitted
  by the `1511` bound mean, are not established.
- The `MACHI.MES` continuation past the handoff is not measured, and native
  presentation is omitted under the bounded runtime policy.

### Evidence boundary

Confidence is **Confirmed** for the seven-conjunct predicate and its
coordinates, the thirteen witnesses and every boundary they pin, the 6 + 20
message route to the exact `2819..2832` handoff, the segmented/unbroken
agreement, the seven constant effects and the two clock-dependent ones, the
two dead inputs and their causes, the callee-owned completion write and the
zero-message reentry.

## Runtime group: `01m_i16_v6.json`

The route is declared as a `kakyu_event_analysis_group/v6` root replacement,
`config/event_catalog/analysis_groups/01m_i16_v6.json`, with one route, the
thirteen guard cases, nine variants and the completed reentry. The Python
source audit binds every coordinate and record hash to the archive, and the
Godot validator executes the declaration as the batch check `original event
analysis 01M I16`: 306 checks, no failures, in about 8 seconds. The audit
rejects a terminal offset shifted by one byte, and the validator rejects a
wrong reentry message count once per variant. Landing the profile promotes
`EVENTI16.MES` to analysis-group measured in the route classification and
binds `MACHI.MES`, `DEF_MAIN.MES` and `LIBLARY.LIB` a further time.

## EVENTD05: three answers, one terminal

Measured 2026-09-10. The first route here whose callee asks the player a
question, and the first whose callee runs a `?_PIC.MES` presentation script
of its own.

### Fifteen conjuncts, twenty-two witnesses

`01M.MES:39839..39941` is a `branch_if_not_true` whose false edge is `40556`,
the I16 guard. It requires weekday `0`, `4/00 < date < 6/16`,
`08:00 < clock < 16:01`, `50 < banked_u16[212] < 80`, `global_u8[402] == 1`,
and `global_u8[220]`, `[224]`, `[225]`, `[227]`, `[678]`, `[753]` and `[778]`
all clear. Twenty-two witnesses - seven accepting, fifteen rejecting - pin
every boundary: `state_u16[7]` rejects `400` and accepts `401`, accepts `615`
and rejects `616`; `state_u16[19]` rejects `800` and accepts `801`, accepts
`1600` and rejects `1601`; `banked_u16[212]` rejects `50` and accepts `51`,
accepts `79` and rejects `80`; weekday `6`, `global_u8[402] = 0` and each
clear flag set reject. Between the guard's true edge and the handoff
`40530..40546` there are 75 records and nothing conditional; every accepting
witness produces the same 9-message prefix.

### The callee runs `D_PIC.MES` and then asks

`EVENTD05.MES` calls `D_PIC.MES` at `2082..2095`, a nested presentation
callee that returns without dialogue and writes `banked_u16[1]`,
`global_u8[4000]` and `global_u8[3005]` - the Event Player's hash-locked
omission of that same dispatch is a playback-side decision, and this group
executes it. At `2839` (resume `2844`) the callee reaches a routine-40
selection over three registered definitions (`2641`, `2708`, `2765`, the
offsets the Event Player's D05 validator already binds), and every answer
reaches the same root-handoff terminal, `5947..5960 -> MACHI.MES`:

| Result | Callee messages | `banked_u16[212]` | `state_u16[21]` |
|---:|---:|---|---:|
| 1 | 48 | `-5` | 1 |
| 2 | 48 | `+2` | 2 |
| 3 | 49 | unchanged | 3 |

The word the guard windows is the word the answer moves. The effects constant
across all twenty-one declared rows are `banked_u16[1] = 7`, `global_u8[753]
= 1`, `[221] = 1`, `[226] = 1`, `[244] = 1`, `[286] = 1`, `[3739] = 1`,
`[4090] = 1`, `[4091] = 1`, `[5364] = 1` and `global_u8[4000] = 0`. Segmented
and unbroken runs agree in state, rows and message bytes.

### Inputs

Clock `801` and `1600` change the callee's time-band arms (`460..840`,
`5834..5880`); at `16:00` shared routine 25 leaves `state_u16[8]` at `1`
instead of `46` and `global_u8[3231]` at `2` instead of `1`. `global_u8[3006]
= 1` flips `943` and makes `D_PIC.MES` write `global_u8[3005] = 15` - an
effect of the picture script, invisible while the dispatch was skipped.
`global_u8[2847] = 1` flips `1948` and `5384` with no effect change. The date
and the affection word are guard-only: no callee branch reads `state_u16[7]`,
and the one branch reading `banked_u16[212]` (`3513`, `> 5`) is true
throughout the guard's window. `state_u16[8]` is dead - `EVENTD05.MES:250..255`
writes it to `0` before the `255` test, and routine 25 writes `46` later - so
`310`, `365` and `5307` are unreachable; `global_u8[4000]` is dead twice,
cleared by routine 28 from `240` and again by `D_PIC.MES:684`. Twenty-three
of the callee's 26 branches are exercised.

### Completion is callee-owned and the reentry replays with a moving word

Against the state the callee leaves, only conjunct 13 fails: `global_u8[753]`,
written by the callee. Re-entering `EVENTD05.MES` from `0` with that state
replays the whole body - 48 messages to the same handoff - and moves
`banked_u16[212]` again by the same result's delta, so the profile carries a
reentry expectation per variant. On the second pass with the word at `81`,
`D_PIC.MES` writes `global_u8[3005] = 2` where the first pass wrote `0`: a
threshold inside the picture script, measured and left unexplained.

### Evidence boundary

Confidence is **Confirmed** for the fifteen-conjunct predicate and twenty-two
witnesses, the 9-message prefix, the `D_PIC.MES` call and its writes, the
three-result contract at `2839` and each result's messages, effects and
shared terminal, the segmented/unbroken agreement, the dead and live inputs
and the per-result reentry.

**Unresolved**: natural scheduling into `39839` (the fifth guard of the
cascade); what sets `global_u8[402]` and what the `51..79` window selects;
the `MACHI.MES` continuation; the `global_u8[3005]` threshold in `D_PIC.MES`;
native input and presentation.

### Runtime group: `01m_d05_v6.json`

Declared as a `kakyu_event_analysis_group/v6` root replacement with one
callee choice contract, `D_PIC.MES` among its source members, twenty-two
guard cases, twenty-one variants (five per result plus the six guard-only
and dead inputs at result 1) and per-variant reentry. The audit accepts it
and rejects a terminal offset shifted by one byte; the batch check `original
event analysis 01M D05` passes 896 checks in about 9 seconds and rejects a
variant whose declared result is not the one its effects were measured
under. Landing it promotes `EVENTD05.MES` to analysis-group measured and
binds `D_PIC.MES` from this caller.

## EVENTG11: a prefix with a presentation call inside it

Measured 2026-09-10. The second route qualified from the group, and the first
here whose prefix is not a straight line: between the guard and the handoff
stand four branches and a `G_PIC.MES` nested call.

### Fourteen conjuncts, twenty witnesses

`01M.MES:40825..40919` is a `branch_if_not_true` whose false edge is `43507`.
It requires weekday `0`, `10/00 < date < 11/16`, `09:00 < clock < 16:00`,
`banked_u16[204] > 70`, and `global_u8[140]`, `[144]`, `[145]`, `[147]`,
`[1364]`, `[1372]`, `[1406]` and `[1481]` all clear. Twenty witnesses - six
accepting, fourteen rejecting - pin every boundary: `state_u16[7]` rejects
`1000` and accepts `1001`, accepts `1115` and rejects `1116`; `state_u16[19]`
rejects `900` and accepts `901`, accepts `1599` and rejects `1600`;
`banked_u16[204]` rejects `70` and accepts `71`; weekday `6` and each flag set
to `1` reject.

### The prefix runs through `G_PIC.MES` and four branches

With the guard accepted the caller emits 38 messages before the handoff
`43481..43497`. On the way it calls `G_PIC.MES` at `41065..41078`, which
returns, and passes four branches whose false edges all land before the
handoff: `40973` and `42833` test `global_u8[2847] == 1`, `41896` tests
`global_u8[2632] == 1`, and `43150` tests `state_u16[5] != 0`. All four are
false at baseline, every accepting witness produces the same prefix hash, and
neither flag flips anything the route reports: `global_u8[2847] = 1` changes
the arms of `40973`, `42833` and the callee's `2616`, `global_u8[2632] = 1`
changes `41896`, and the messages, terminal and effects are identical. The
fourth branch cannot be flipped from its own cell: `01M.MES:43109..43120`
writes `state_u16[5] <- banked_u16[2] & 128` immediately before it, so its
true arm is reachable only through `banked_u16[2]`, which this group does not
seed.

### The route

`EVENTG11.MES` runs 50 messages from `0` and ends at its one root-handoff
terminal, `3289..3302 -> MACHI.MES`; it has no routine-40 selection. Segmented
and unbroken runs agree in state, rows and message bytes.

The callee writes `global_u8[140] = 1` at `3238` and `global_u8[1481] = 1` at
`3227` - two of the guard's own conjuncts - increments `banked_u16[204]` at
`3161..3176`, and copies the date into `banked_u16[277]`: the same idiom
`EVENTH07`'s guard reads from the other side, `banked_u16[268] + 1 == date`.
Its other effects are `banked_u16[1] = 7`, `banked_u16[242] = 1`,
`global_u8[146] = 6`, `[244] = 1`, `[286] = 1`, `[3005] = 2`, `[3533] = 1`,
`[5132] = 1`, `[5133] = 1` and `state_u16[8] = 46`. Only one callee input is
live: `banked_u16[202]` between `31` and `100` flips `3196` and adds
`global_u8[128] = 1`. `state_u16[8]` is dead - `EVENTG11.MES:250..255` writes
it to `0` immediately before the `255` test, after shared routine 25 in the
caller's gap had already written `46` - so `310` and `365` are unreachable.
Four of the five callee branches and three of the four gap branches are
exercised across the twelve variants.

### Completion is callee-owned and the reentry replays everything

Against the state the callee leaves, the guard is false through two conjuncts,
`global_u8[140]` and `[1481]`, both written by the callee. But nothing in the
callee tests either flag, so re-entering `EVENTG11.MES` from `0` replays all
50 messages to the same handoff and applies its increments again:
`banked_u16[204]` to `82`, `global_u8[244]` to `2`. That is G08's reentry
shape with a completion predicate that G08 lacked: the flag closes the caller's
guard, not the callee's body.

### Evidence boundary

Confidence is **Confirmed** for the fourteen-conjunct predicate, the twenty
witnesses, the prefix through `G_PIC.MES` with its four branch arms, the
38 + 50 message route to the exact handoff, the segmented/unbroken agreement,
every measured effect including the date copy, the dead and live inputs, the
two-conjunct callee-owned completion and the replaying reentry.

**Unresolved**: natural scheduling into `40825` (the seventh guard of the
cascade); what sets the eight clear flags; `43150`'s true arm through
`banked_u16[2]`; the `MACHI.MES` continuation; native presentation.

### Runtime group: `01m_g11_v6.json`

Declared as a `kakyu_event_analysis_group/v6` root replacement with
`G_PIC.MES` among its source members, twenty guard cases, twelve variants and
the replaying reentry; the two affection variants carry their own reentry
values because the increment lands on the seeded word. The audit accepts it
and rejects a terminal offset shifted by one byte; the batch check `original
event analysis 01M G11` passes 555 checks in about 8 seconds and rejects a
wrong reentry message count once per variant. Landing it promotes
`EVENTG11.MES` to analysis-group measured and binds `G_PIC.MES` for the first
time from this caller.

## EVENTH07: measured to a native boundary, and deliberately not qualified

(Corrected 2026-09-14: the boundary is the train map's click loop past
`861`, not a stream - see "H07, M06 and M09 re-measured under Core
0.316.0" below.)

Measured 2026-09-10. This is the third intro alphabetically and the first of
the three that stand behind the station's own selection.

### The eligibility guard and the selection

`01M.MES:621..675`, the first candidate's guard, requires
`banked_u16[268] + 1 == date`, `09:30 < clock < 11:00`, `global_u8[2300]` and
`[2301]` set, `[2304]` and `[2305]` clear. Eleven witnesses - three accepting,
eight rejecting - pin the clock at `930/931` and `1099/1100`, reject a stored
word one below or one above `date - 1`, and reject each flag inverted.

The candidate's body reaches a routine-40 selection at `01M.MES:3927`
(resume `3932`) with two results, and the record `3942..3952` is the
one-based `state_u16[21]` consumer: result `1` falls through toward the H07
handoff, anything else takes the false edge to `6102`. Answered `1`, the
prefix emits 67 caller messages, calls `H_PIC.MES` and `K_PIC.MES` twice each
(`1832`, `2174`, `4273`, `4787`, all returning with no dialogue), takes
`1156` true and the other in-gap branches false, and stops at the handoff
`6076..6092`. Answered `2`, the caller emits 91 more messages and reaches a
**different** root handoff, `01M.MES:89476..89489 -> MACHI.MES`, never
touching H07.

### The caller closes the guard before the callee starts

Immediately before the handoff the caller writes `global_u8[2301] = 0` at
`6010..6016` and `global_u8[2304] = 1` at `6021..6027`. Those are conjuncts 4
and 6 of the guard, so the guard is already false when `EVENTH07.MES` begins:
a completion predicate that is caller-owned **and written before the
dispatch**, a shape none of the twenty-four earlier groups had. The callee
never writes any of the seven guard cells.

### Where the measurement stops

`EVENTH07.MES`'s first branch, `274`, tests `global_u8[2304] == 1` - the flag
the caller just set - and its true arm calls `TRAIN.MES` at `290`. Inside
`TRAIN.MES`, through shared routine 9, routine 28, registered definition 15
and routine 28 again, execution reaches `TRAIN.MES:861`: a command-`0x0D`
native single-byte presentation stream whose first payload byte resembles a
branch command. The export could not bound that stream, the probe's resume
lands on the same record, and the run spends its whole 512-segment budget
there without a new offset ever appearing - confirmed identical to 4,000
segments. The callee emits **0 messages**; none of its other 32 branches, its
preserved opaque boundary `8361..8792` or its terminal `15904..15917 ->
MACHI.MES` is reached, and the ten variants (clock, date/word pairs, the
caller's `banked_u16[207]`/`[208]` and `global_u8[2847]`, the callee's
`state_u16[8]`, `global_u8[4000]` and `[3006]`) all stop at the same record.
Segmented and unbroken runs agree.

`TRAIN.MES:861` is therefore an **exact bounded unresolved boundary** of this
route, and the route is measured and not qualified: no declared shape can
carry a terminal the run never reaches. The same sub-map is where
`EVENTM06.MES` and `EVENTM09.MES` dispatch from their entry zero at `0x00FF`
([format and method](format_and_method.md)), so those two intros are expected
to meet the same record. What the stream at `861` is, and whether the bounded
runtime can be given its extent, is the question that reopens all three.

### Evidence boundary

Confidence is **Confirmed** for the seven-conjunct guard and its eleven
witnesses, the selection at `3927` and its two-result contract, the result-1
prefix to `6076` and the result-2 path to `89476`, the caller's two guard
writes before the handoff, the callee's `274 -> 290 -> TRAIN.MES` entry, and
the `TRAIN.MES:861` stop with its repeat to 4,000 segments.

**Unresolved**: everything in `EVENTH07.MES` past `290`; the meaning of the
`861` stream; the station's second selection result; natural scheduling into
`621`.

## EVENTM06 and EVENTM09: the same boundary, twice more

Measured 2026-09-10. Both are nested calls behind the station's selection,
and both callees dispatch `TRAIN.MES` from their entry zero at `0x00FF`
(255), so both meet the record H07 met.

### Guards and witnesses

`EVENTM06`'s guard `30889..30944` (false `35012`) requires weekday `0`,
`6/15 < date < 9/16`, `clock < 16:00`, `global_u8[2420] == 1`, and
`global_u8[150]`, `[2437]` and `[2439]` clear; twelve witnesses pin
`615/616`, `915/916` and `1599/1600` and reject weekday `6`, the prerequisite
cleared and each flag set. `EVENTM09`'s guard `35012..35060` (false `39564`)
requires weekday `0`, `date > 7/15`, `clock < 16:00`, the same prerequisite,
and `[150]`, `[2439]` and `[2442]` clear; ten witnesses pin `715/716` and
`1599/1600`. The two windows overlap from `7/16` to `9/15`, and M06's guard
stands first in the cascade, so M09's origin is reached on such a day only if
M06's guard is false through one of its own flags.

### The selection and its loop

Each candidate body reaches a routine-40 selection - `01M.MES:32625` for M06,
`36443` for M09 - with two results. Result `1` passes the gate
(`32640..32650` / `36458..36468`) and reaches the nested call after 32 and 31
caller messages respectively, `M_PIC.MES` having returned without dialogue.
Result `2` runs 50 and 48 caller messages to the station exit
`01M.MES:89476..89489 -> MACHI.MES`. The one edge entering each gap from
outside is now measured: the gate's false path tests `state_u16[21] == 2` at
`33837` / `38091`, and if that also fails a `continuation_transfer` at
`34980` / `39532` jumps back to the constant-true record. A result that is
neither `1` nor `2` re-asks the selection.

### Where they stop

With result `1`, `EVENTM06.MES` and `EVENTM09.MES` take their first branch
(`234`) and dispatch `TRAIN.MES` at `255`. The same chain as H07 - routine 9,
routine 28, definition 15, routine 28 - reaches `TRAIN.MES:861`, and the run
repeats that record until the segment budget is gone; raised to 8,000
segments, five distinct `(offset, status)` pairs appear in `TRAIN.MES` and
the first repeat is at step 7. Neither callee emits a message. Neither the
caller nor the callee writes a guard cell before the stop, so both guards are
still true at it - unlike H07, whose caller closes its guard before the
handoff. Clock and date variants inside each window stop at the same record.
Segmented and unbroken runs agree.

Both routes are therefore **measured and not qualified** at the exact bounded
boundary `TRAIN.MES:861`. Three of the caller's nine intros end there, and
the same question reopens all three.

### Evidence boundary

Confidence is **Confirmed** for both guards and their witnesses, both
selections and their two-result contracts, the result-1 prefixes and the
result-2 exits, the re-ask loops, the `255 -> TRAIN.MES` dispatches and the
`861` stop with its repeat to 8,000 segments.

**Unresolved**: everything in either callee past `255`; the `861` stream;
natural scheduling into either origin.

## H07, M06 and M09 re-measured under Core 0.316.0: the train's click loop

(Superseded the same day: the loop is the map module's location poll, and
the three intros are declared - see the subsection at the end of this
section.)

Corrected 2026-09-14. The record the three routes stopped at,
`TRAIN.MES:861`, was never a stream: under Core 0.316.0 it is
`System.function[12](5)`, one omitted system call, and the walk
continues past it. What follows is the train map's own input loop -
`Util(6,8)` at `873`, `Util(6,13)` at `886`, `state_u16[21] =
state_u16[18]` at `894`, `jz state_u16[21] == 0xFFFF` at `905` back to
the loop head `849` - a click poll the native host leaves only when the
player picks a destination. The runner omits the `Util` records, so
`state_u16[18]` never changes and the run spends its step budget inside
one segment (`step_limit at 0x371 in TRAIN.MES`); with no boundary
record in the loop, the probe's loop detection of Core 0.317.0 (which
works at segment boundaries) does not see it either. Re-measured with
the route toolchain (`analysis/01m_h07_spec.json`, `01m_m06_spec.json`,
`01m_m09_spec.json`): M06 and M09 reach their nested calls after 32 and
31 caller messages as before and stop there; H07's guard needs the
stored date `banked_u16[268]` seeded one day before the visit (its first
conjunct is `banked_u16[268] + 1 == date`, which the 2026-09-11 reading
described as "the day after"), and with that seed the prefix reaches the
handoff after 67 messages and the callee stops at the same loop
through its `290 -> TRAIN.MES` call. All three stay **measured and not
qualified**: no schema names a callee that halts in a nested script's
input loop, and modelling the train's click would be a runtime
contract of its own. The station's three train intros are therefore one
owner question - a callee-side input-loop outcome, a model of the train
map's input, or leaving them - not the decoder question the section
above recorded. The sections above are the 2026-09-10/11 reading.

### Declared through the train's map-location contract (Core 0.318.0)

The owner ruled on 2026-09-14 for a general map-input contract with the
train as its first case. Read against ai5-sdl2's Kakyuusei map module
([format and method](format_and_method.md), "The map module behind
`Util(6,n)`"), the loop past `861` is not a click poll but the map
module's location poll: `Util(6,8)` runs the sprites, `Util(6,13)` writes
the location the player sprite stands on into `state_u16[18]` (`0xFFFF`
for none), and the loop leaves when the player has reached location `0`
and then location `1`. A `map_location_contract` on `TRAIN.MES` (poll
`886..894`, locations `0, 1`) supplies exactly that, the runner writes
the cell at the poll and omits every other map effect, and the three
callees ride to Hazuki town and back to their doors. Measured again with
the toolchain (`analysis/01m_h07_spec.json`, `01m_m06_spec.json`,
`01m_m09_spec.json`, each with the contract).

**EVENTH07** - `01m_h07_v11.json`, one root-replacement route `01m-h07`
with 8 variants, 306 checks, `H_PIC`, `K_PIC`, `P_PIC`, `MACHI` and
`TRAIN` among the members, the station's selection at `3927` answered `1`
in the prefix. The guard's first conjunct is `banked_u16[268] + 1 ==
date`, so the seed stores the day before the visit; the prefix runs 67
messages to the handoff, the callee adds `3` to the H and K words at
`224` and `244`, rides, plays the zoo date and the ride back - 240
messages - and leaves by `15904..15917 -> MACHI.MES`; the guard, closed
by the caller before the dispatch, rejects afterwards (`post_guard_expected`
0) and a direct reentry, the callee carrying no gate of its own, replays
the whole ride and date to the same door (240 messages), the G11 shape.

**EVENTM06** - `01m_m06_v12.json`, one caller-continuation route `01m-m06`
with 9 variants, 333 checks, the station's selection at `32625`
answered `1`. The callee rides, plays the amusement-park date - 105
messages - closes its gate `[2438]` at `8892` and returns at `8903..8904`;
the caller resumes on the returned state and hands the root to `MACHI.MES` at `33814..33827` after 17 messages (`natural_handoff`). The guard
rejects afterwards and a direct reentry returns through the done-gate
with 0 messages.

**EVENTM09** - `01m_m09_v12.json`, one caller-continuation route `01m-m09`
with 12 variants, 404 checks, the station's selection at `36443`
answered `1`. The callee rides, plays the aquarium date - 87
messages - closes `[2443]` at `6162`, counts `[198]` when the L word is in
`41..100`, and returns at `6204..6205`; the caller resumes and
hands the root to `MACHI.MES` at `38068..38081` after 17 messages (`natural_handoff`). The guard rejects afterwards and a direct reentry returns
through the done-gate with 0 messages.

Audit accepted for all three; `original event analysis 01M H07`, `01M M06`
and `01M M09` pass; a wrong callee message count and the door or return
record shifted one byte are rejected, and so is a contract whose poll is
not the exact `Util(6,13)` record. Every one of the station's nine
intros is now measured and declared.

## EVENTL03: a returning callee, and a disjunction that cannot fire

Measured 2026-09-10. The only nested call among the cleanly guarded intros,
so the caller resumes after it, and the intro with the caller's only
disjunction.

### Fourteen conjuncts, one of them dead

`01M.MES:44573..44674` is a `branch_if_not_true` whose false edge is `47031`.
Its first conjunct is `weekday == 0 or date == 1224`; the rest require
`4/00 < date < 6/16`, `10:00 < clock < 16:01`, `banked_u16[209] > 35`,
`global_u8[399] == 1`, and `global_u8[190]`, `[194]`, `[197]`, `[1925]`,
`[1966]`, `[2042]` and `[2043]` all clear. Twenty-one witnesses - six
accepting, fifteen rejecting - pin `400/401`, `615/616`, `1000/1001`,
`1600/1601` and `35/36`, and reject weekday `6`, `global_u8[399] = 0` and each
clear flag set. The disjunction is measured on all four combinations:

| Weekday | Date | Guard |
|:-:|:-:|---|
| 0 | 501 | **accept** |
| 0 | 1224 | reject |
| 6 | 501 | reject |
| 6 | 1224 | reject |

`date == 1224` can never hold together with `400 < date < 616`, so the
second arm of the disjunction is dead against the guard's own second and
third conjuncts: weekday `0` is the only way in. That is recorded as
measured, not as a reachable Christmas Eve path.

### The route: callee returns, caller walks to the station exit

With the guard accepted the caller emits 10 messages through 64 records and
reaches the nested call `45057..45073`. `EVENTL03.MES` runs 15 messages from
`0` and returns at `2306..2307`, writing `banked_u16[1] = 7`,
`global_u8[2043] = 1` (conjunct 12, at `599..605`), `[3285] = 1`,
`[3655] = 1`, `[5274] = 1` and `state_u16[8] = 46`. The caller then resumes
at `45073`, calls `L_PIC.MES`, passes sixteen dialogue boundaries and 38
messages, writes `banked_u16[242] = 1`, `global_u8[196] = 1`, `[286] = 1`,
`[350] = 1` and `global_u8[2042] = 1` (conjunct 11, at `47004..47010`), and
stops at the root handoff `01M.MES:89476..89489 -> MACHI.MES` - the same
station exit that H07's second selection result reaches. No routine-40
selection stands in the way. Segmented and unbroken runs agree in state, rows
and message bytes.

### Inputs

Clock `1600` flips the callee's time-band branches (`287`, `310`, `458`,
`489`, `907`, `961`); `global_u8[3006] = 1` flips `1064` and
`global_u8[2847] = 1` flips `2183`; the callee's `118` tests
`40 < banked_u16[203] < 81`, both ends strict, measured across twelve values.
None of them changes the return record, the resume or the exit. `state_u16[8]`
is dead - the callee writes it at `610..615` immediately before the `615`
test, so `670` and `725` are unreachable - and so is `global_u8[4000]`: the
callee calls shared routine 28 at `355`, and that routine writes the cell to
`0` at `LIBLARY.LIB:756..762`, the same clearing I16 and D05 met.
`global_u8[2043] = 1` cannot be an input because it is a guard conjunct.
Eighteen of the callee's twenty branches are exercised.

### The completion predicate is owned twice

Against the state the callee leaves, conjunct 12 (`global_u8[2043]`) is false
by the callee's own write. Against the state after the caller's resume,
conjunct 11 (`global_u8[2042]`) is false as well, by the caller's write just
before the guard's own false target. Either write alone closes the guard, so
this is neither C18's caller-owned shape nor I16's callee-owned one: both
sides close it independently. Re-entering `EVENTL03.MES` from `0` with either
state emits **0 messages** and returns at `2337..2338` writing
`state_u16[2] = 1`; the callee's own flag already suppresses its replay before
the caller has written anything.

`global_u8[2042]` is also a clear-flag conjunct of 44M's `EVENTL10` guard, so
the station exit after L03 closes L10's window as well as L03's own.

### Evidence boundary

Confidence is **Confirmed** for the fourteen-conjunct predicate, the
twenty-one witnesses and the four-combination disjunction table, the 10 + 15
message route to the exact return, the 38-message resume to the exact exit
handoff, the segmented/unbroken agreement, the two guard writes and their
owners, the dead and live inputs and the zero-message reentries.

**Unresolved**: natural scheduling into `44573` (the last guard of the
cascade, behind seven others and an unmeasured stretch from `43507`); what
sets `global_u8[399]`; the `MACHI.MES` continuation past `89476`; native
presentation including `L_PIC.MES`'s.

### Runtime group: `01m_l03_v5.json`

Declared on the `kakyu_event_analysis_group/v5` caller-continuation contract
with the `natural_handoff` resume policy - the caller's resume ends at a root
handoff, which v5 already expresses, so no v8 policy is needed - with
`L_PIC.MES` among its source members, twenty-two guard cases including the
dead disjunction arm, eleven variants with callee and resume expectations,
and the zero-message reentry. The audit accepts it and rejects the resume
handoff shifted by one byte; the batch check `original event analysis 01M
L03` passes 324 checks in about 7 seconds and rejects a wrong resume message
count once per variant. Landing it promotes `EVENTL03.MES` to analysis-group
measured and binds `L_PIC.MES` from this caller.

## Reproduction

The measurement scripts are local under the gitignored `analysis/`:
`probe_01m_group.py`, `probe_01m_guards.py`, `probe_01m_gaps.py`,
`probe_01m_gap_detail.py`, `probe_01m_predicates.py`,
`build_01m_group_measure.py`, `measure_i16.gd`, `probe_i16.py`,
`probe_i16_diag.gd`, `measure_g11.gd`, `g11_diag.gd`, `measure_h07.gd`,
`h07_probe_selection.gd`, `h07_diag_train.gd`, `measure_d05.gd`,
`d05_probe.py`, `d05_probe_diag.gd`, `measure_l03.gd`, `measure_m06.gd`,
`measure_m09.gd` and the `build_*_profile.py` generators. The caller graph
comes from `tools/build_event_analysis_inventory.py`; the profile is checked by
`tools/audit_event_analysis_group.py` and
`tools/content_suite/validators/validate_event_analysis_group.gd`.

## EVENTB03 and EVENTJ04 measured as groups, 2026-09-21

EP-10 unit 5a measured the station's two remaining hand-qualified sites
with the route toolchain, so that every 01M site rests on a group. Both
are root handoffs (command `0x0E`) whose callee hands the root to
`MACHI.MES` itself.

| Route | Guard | Dispatch | Callee handoff | Variants | Messages |
|---|---|---|---|---|---|
| `01m-b03-result1/2/3` (`01m_b03_v6.json`) | `30353..30449`, false `30889` | `30863..30879` -> `EVENTB03.MES` | `7094` / `9972` / `15686` -> `MACHI.MES` | 15 / 1 / 1 | 83 / 84 / 116 (reentry 85 / 86 / 118) |
| `01m-j04` (`01m_j04_v6.json`) | `39564..39618`, false `39839` | `39813..39829` -> `EVENTJ04.MES` | `1823` -> `MACHI.MES` | 10 | 21 (reentry 0) |

B03's members add `B_PIC.MES` and `MACHI.MES`; its callee asks the player
a question (one routine-40 contract, three answers, one route per answer -
the results the hand-authored row and `station_candidate_priority.md`
recorded). Manual variants: the four free branches on `global_u8[626]` and
`global_u8[627] == 1/2/3` that no guard pins, plus the `state_u16[12] > 99`
and `banked_u16[210]` (Mahoko's affection) arms the numeric presets of the
hand row exercised. J04's variants cover the four `global_u8[854]` /
`global_u8[823]` combinations the hand row carried as presets. Every ending
is a map return whose postlude is the event's. The v4 documents
`mahoko.town.station.03.1` and `minatu.town.station.04.1` are projected from
these groups since the same day; batch checks `original event analysis 01M
B03` and `01M J04`.
