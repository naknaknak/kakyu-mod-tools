# FLOOR5 caller group: every intro measured, all seven qualified

Measured on 2026-09-11 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`FLOOR5.MES` is the school-floor map on which the term Saturday begins
([Saturday start](saturday_start.md): `state_u16[16] = 5`, `12:30`), and the
caller with the most unresolved EVENT intros after `44M.MES` and `01M.MES`
were measured. The instrument is the one that opened those two groups; run
first on `01M.MES`, it reproduces the `EVENTI16` row exactly - guard, false
target, seven conjuncts and a 193-byte gap - before it is run here.

## Why this group, and what is new in it

| Property | `01M.MES` | `FLOOR5.MES` |
|---|---|---|
| framing-opaque bytes in the caller | 0 of 89,510 | **0 of 10,126** (three preserved opaque boundary records, 2,261 bytes) |
| EVENT intro sites | 9 | 7, for six targets |
| intros with a typed guard candidate | all 9 | **5 of 7** |
| dispatch form | six root handoffs, three nested calls | **all seven nested calls** |
| framing-opaque bytes in the callees | 0 | 0 |

`FLOOR5.MES` has 1,080 instructions, 40 branches, 91 calls and a 35-entry
address table (`8, 1746, 1809, 2936, 2978, 3281, 3344, 3619, 3686, 3747,
3823, 4139, 4202, 4317, 4380, 5066, 5133, 5232, 5299, 6012, 6079, 6974, 7059,
7122, 7390, 7457, 7983, 8050, 8599, 8662, 9017, 9291, 9566, 9629, 9901`). The
Saturday entrance test recorded in [Saturday start](saturday_start.md)
reproduces: `483..493` tests `state_u16[16] == 5`, true to `493`, false to
`510`.

Two things are new. Every intro is a command-`0x0F` nested call, so the map
resumes after each event and every route has a caller continuation to
measure. And two of the seven sites have **no eligibility guard at all** -
the first such sites since GROUND's `EVENTG08`, and the first that are nested
calls rather than root handoffs. All seven sites are qualified below; the two
unguarded ones needed a contract addition, Core 0.314.0's v9.

## The seven intros

| Intro | Site | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---:|---:|---:|
| `EVENTF01` | `3052..3068` | **none** | 4,252 | 23 | 37 |
| `EVENTG21` | `3915..3931` | `3540..3614` | 2,296 | 10 | 18 |
| `EVENTE15` (site A) | `5405..5421` | **none** | 4,267 | 11 | 26 |
| `EVENTE15` (site B) | `5677..5693` | `5543..5627` | 4,267 | 11 | 26 |
| `EVENTM18` | `6187..6203` | `5911..5967` | 2,605 | 7 | 21 |
| `EVENTH10` | `7569..7585` | `7249..7345` | 3,447 | 7 | 55 |
| `EVENTH16` | `8162..8178` | `7800..7938` | 3,141 | 7 | 21 |

No callee carries a root-handoff terminal candidate or an opaque boundary;
all six return. `EVENTE15` is the one target with two sites in this caller,
which places it in the route classification's multi-intro
`duplicate_route` candidate pool.

## Five guards, all clean, three of them a chain

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---:|---:|:---:|---:|---:|---:|---:|---:|
| `EVENTG21` | `3540..3614` | `4486` | 11 | - | 301 | 55 | **0** | **0** | 0 |
| `EVENTE15` B | `5543..5627` | `5815` | 12 | - | 50 | 10 | **0** | **0** | 0 |
| `EVENTM18` | `5911..5967` | `7249` | 8 | - | 220 | 38 | **0** | **0** | 0 |
| `EVENTH10` | `7249..7345` | `7800` | 14 | - | 224 | 38 | **0** | **0** | 0 |
| `EVENTH16` | `7800..7938` | `8836` | 21 | - | 224 | 38 | **0** | **0** | 0 |

Nothing conditional stands between any of the five guards and its dispatch.
`EVENTM18`'s false edge is `EVENTH10`'s guard and `EVENTH10`'s false edge is
`EVENTH16`'s: the three form one fall-through chain, and all three begin with
the same conjunct, `state_u16[21] == 4` - the one-based routine-40 result. The
map's own selection has to have been answered `4` before the chain is
reached, so these three events stand behind one choice on this floor, the
way H07, M06 and M09 stand behind the station's. `EVENTG21`'s predicate
lists `global_u8[1364] == 0` twice, as its ninth and eleventh conjunct; that
is recorded as measured.

## Two sites with no guard

`EVENTF01`'s site `3052..3068` and `EVENTE15`'s site A `5405..5421` have no
`branch_if_not_true` whose false edge skips them. Measured the way GROUND's
G08 was:

| Site | Address-table entry | Window | Records | Branches in window | Edges that could skip the dispatch | Edges entering from outside |
|---|---:|---|---:|---:|---:|---:|
| `EVENTF01` | `2978` | `2978..3052` | 15 | **0** | **0** | **0** |
| `EVENTE15` A | `5299` | `5299..5405` | 15 | **0** | **0** | **0** |

Both windows have the same shape: the entry label, three message records
that form one dialogue line (two text chunks around a protagonist-name
insert), one argument-slot write and one command-`0x1D` script-transfer
record with selector `0`, which the runtime does not enter the library for,
then the nested call. Neither window writes any state cell. No branch
anywhere in the 10,126-byte entry originates before either dispatch and lands
beyond it, and no edge lands inside either window from outside it. Whatever
selects address-table entry `2978` or `5299` selects the event; the
eligibility, if any, lives in what makes that entry selectable, which this
group does not measure.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`6` is Saturday), the date `state_u16[7]` as MMDD,
the clock `state_u16[19]` as HHMM, the routine-40 result `state_u16[21]`,
and `banked_u16[204]`, `[207]`, `[208]` affection words. Flags are `global_u8`.

| Intro | Calendar window | Result | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|:-:|---|---|---|
| `EVENTG21` | Saturday, `9/15 < date < 15/11` | - | `banked_u16[204] > 120` | - | `[140]`, `[144]`, `[147]`, `[1364]`, `[1406]`, `[1492]` |
| `EVENTE15` B | `9/15 < date < 11/16`, `12:29 < clock < 14:30`, date `== banked_u16[265]` | - | - | `[1914]` | `[120]`, `[124]`, `[150]`, `[154]`, `[1833]`, `[1915]` |
| `EVENTM18` | `11/15 < date < 15/11`, `12:29 < clock < 15:01` | `4` | - | `global_u8[2509] > 10` | `[150]`, `[2515]` |
| `EVENTH10` | `9/15 < date < 11/16`, `12:29 < clock < 15:30` | `4` | `55 < banked_u16[207] < 81` | `[2284]` | `[170]`, `[174]`, `[177]`, `[2083]`, `[2124]`, `[2318]` |
| `EVENTH16` | `11/15 < date < 15/11`, `12:29 < clock < 15:01` | `4` | `banked_u16[207] > 70`, `[208] > 70` | `[2284]` | `[170]`, `[174]`, `[177]`, `[180]`, `[184]`, `[187]`, `[2083]`, `[2124]`, `[2184]`, `[2225]`, `[2279]`, `[2331]`, `[2333]` |

Three readings follow from the table and are measurements, not guesses.
`EVENTG21` is the only guard here that tests the weekday, and it asks for
Saturday - the day this map is entered on - with the same flag family as
01M's `EVENTG11` (`[140]`, `[144]`, `[147]`, `[1364]`, `[1406]`) and a higher
threshold on the same word (`> 120` after G11's `> 70`). `EVENTE15` B is the
third guard in the archive so far to compare the date with a stored word -
G11 writes `banked_u16[277]`, H07 reads `[268] + 1`, and E15 asks for the same
day as `[265]`. `EVENTH10` and `EVENTH16` share the prerequisite
`global_u8[2284]` and the flags `[170]`, `[174]`, `[177]`, `[2083]` and
`[2124]`, and their date windows are adjacent: H10 through `11/15`, H16 from
`11/16`, with the higher affection bar. Date values above `1231` follow the
owner's month-13 reading recorded for 01M.

## EVENTF01: no guard, and a question inside the event

Measured 2026-09-11. The first unguarded nested call measured in the
archive, and the first FLOOR5 callee that asks the player a question.

From the address-table entry at `2978` the floor emits its one dialogue line
(3 message records) and calls `EVENTF01.MES` at `3052..3068` with nothing
written and nothing tested. The callee runs to a routine-40 selection at
`2331` (resume `2336`) whose three results are consumed by the one-based
`state_u16[21]` chain at `2341`, `2877` and `3499`; every result reaches the
same return, `4220..4221`, with 25, 25 and 29 messages. The floor then
resumes at `3068`, emits 6 messages, and stops at the root handoff
`FLOOR5.MES:4846..4860 -> FLOOR4.MES`, the exit every route on this floor
shares. Segmented and unbroken runs agree.

The callee's inputs: the clock, tested at `411`, `574` and `846` (a
`06:00` seed changes all three arms); `global_u8[3006]`, flipping `1057`;
and `global_u8[1619]`, tested by the callee's first branch at `224` - the
cell the floor's resume writes at `3513` (with `[1620]` at `3524`) after the
event. `state_u16[8]` is overwritten by the callee at `240..245` before its
test, `global_u8[4000]` is cleared by routine 28 (`LIBLARY.LIB:756..762`)
from `502` and `757`, and a seeded `banked_u16[200]` is rewritten inside the
arm the `2817` branch takes. Fifteen of the callee's 23 branches are reached
at baseline.

There is no guard to close, so the completion is measured on the callee
itself: re-entering `EVENTF01.MES` from `0` after the resume returns at
`4251..4252` with **0 messages**, because `224` now reads the flag the floor
wrote. The event carries its own "seen" test even though nothing on the
floor guards its dispatch. One effect belongs to an answer rather than a
seed: result 2's own body sets `banked_u16[200]`, which results 1 and 3
leave at `0`.

### Runtime group: `floor5_f01_v9.json`

Declared on the new `kakyu_event_analysis_group/v9` contract: the window
`2978..3052` re-derived by the audit as fifteen records with no escaping
edge and one return candidate at `3028` (reported, not ruled inert), five
selection witnesses that each reach the call after 3 caller messages, the
callee's three-result contract at `2331`, twelve variants across the three
results, the `natural_handoff` resume bound inside the floor's opaque tail,
and the zero-message completed reentry. The audit accepts it and rejects a
`guard` block added to an unguarded route and a window record count off by
one; `original event analysis FLOOR5 F01` passes 359 checks. The variant
that seeds the callee's own seen flag is measured (it takes the `4251..4252`
return) and not declared, because it is the completed reentry by another
name.

Correction, 2026-09-13 (Core 0.316.0): with command `0x0D` framed as one
system call the window `2978..3052` holds nine typed records and no return
candidate - the `00` at `3028` is the terminator of a message wait's record
list, not a command-`0x00` record - and the `natural_handoff` resume is a
typed record rather than an observation inside an opaque tail (the floor has
none left). The profile's declaration was re-measured to those values with
the edge count and prefix hash unchanged.

## EVENTG21: Saturday, on the floor

Measured 2026-09-11. `FLOOR5.MES:3540..3614` (false `4486`) requires
Saturday, `9/15 < date < 15/11`, `banked_u16[204] > 120`, and `global_u8[140]`,
`[144]`, `[147]`, `[1364]`, `[1406]`, `[1492]` clear, with `[1364]` listed
twice. Fourteen witnesses - four accepting, ten rejecting - pin `915/916`,
`1510/1511` and `120/121`, and reject weekday `0` and each flag set.

The floor emits 10 messages through 55 records to the call `3915..3931`;
`EVENTG21.MES` runs 24 messages from `0` and returns at `2264..2265`; the
floor resumes at `3931`, emits 12 messages and stops at
`4846..4860 -> FLOOR4.MES`. Segmented and unbroken agree. The callee tests
the clock at `263` although its guard has no clock window (`06:00` changes
the arm), `global_u8[3006]` flips `749`, `state_u16[8]` is overwritten at
`374..379` before `379`, and `global_u8[4000]` is cleared by routine 28 from
`354` and `667`. Seven of ten branches are reached at baseline.

Against the state the callee leaves, all eleven conjuncts hold; the callee
writes no guard cell. Against the state after the resume, conjunct 10 fails:
the floor writes `global_u8[1492] = 1` at `4475..4481`, immediately before
the guard's own false target. The callee's first branch `224` tests that
same cell, so the completed reentry returns at `2295..2296` with **0
messages** while the direct reentry replays all 24. Caller-owned completion,
C18's shape, as for the M18/H10/H16 chain below.

Declared as `floor5_g21_v5.json` on the v5 contract with `natural_handoff`,
the resume bound inside the floor's opaque tail as for the chain: audit
accepted, `original event analysis FLOOR5 G21` passes 264 checks, a shifted
guard false target and a wrong reentry message count rejected.

## EVENTE15: one event, two entrances, one flag

Measured 2026-09-11. `EVENTE15.MES` is dispatched twice from this floor: from
site B behind a twelve-conjunct guard, and from site A with no guard at all.

### Site B's guard and its eighteen witnesses

`FLOOR5.MES:5543..5627` (false `5815`) requires `9/15 < date < 11/16`,
`12:29 < clock < 14:30`, the date equal to the stored word
`banked_u16[265]`, `global_u8[1914]` set, and `[120]`, `[124]`, `[150]`,
`[154]`, `[1833]`, `[1915]` clear. Eighteen witnesses - five accepting,
thirteen rejecting - pin `915/916` and `1115/1116` with the word matched,
`1229/1230` and `1429/1430`, reject the word one below and one above the
date, and reject the prerequisite cleared and each flag set. Ten records and
no message stand between the guard and the call; every accepting witness
shares one prefix hash.

### The same callee from either site

From site B the callee runs 11 messages from `0` and returns at
`4235..4236`, writing `banked_u16[1] = 7`, `global_u8[3000] = 2`,
`global_u8[3005] = 15`, `state_u16[2] = 16` and `state_u16[8] = 46`. From
site A - whose prefix is the address-table entry's one dialogue line and
writes nothing - the callee run has the same return record, the same
messages and the same final state; only the entry state differs, because
site B's ten-record gap writes `state_u16[1]`, `[2]`, `[8]`, `[10]`, `[25]`
and advances the clock by ten minutes (`1300 -> 1310`) before the call, and
the callee overwrites `[2]` and `[8]` regardless. Both resumes converge into
the same floor code from `10105`, call `TIME_C.MES`, and stop at the root
handoff `FLOOR5.MES:4846..4860 -> FLOOR4.MES` with no message and no
selection. Segmented and unbroken runs agree at both sites.

The callee's first branch, `219`, tests `global_u8[1914] == 0`. Site B's
guard requires that flag **set**, so from site B the whole block
`230..2853` - the `state_u16[8]` cascade at `261`, `316`, `371`, the first
`global_u8[4000]` test at `490`, the first `global_u8[3006]` test at `647` -
is unreachable; the run lands at `2853` and continues through `2976`,
`3133` and the loop at `4134`, which is visited eighteen times in one run.
`global_u8[3006] = 1` flips `3133`; `global_u8[4000]` is cleared by shared
routine 28 at `LIBLARY.LIB:756..762`, called at `2880`; `state_u16[8]` is
written to `46` by shared routine 25 (`LIBLARY.LIB:7892`, `7922..7930`) from
`4180`; `state_u16[2]` is written by the callee's own loop eighteen times and
converges on `16`. Five of the callee's eleven branches are reachable from
site B. Site A can enter the other half.

### Site A's first visit is a different route

Seeded with `global_u8[1914] = 0` from site A, the callee takes the `230..2853`
half and never reaches the tail: it runs **20 messages**, visits `261`, `490`,
`647` and the loop at `2721`, writes `global_u8[1914] = 1` itself at
`548..554`, and returns at an earlier record, `2842..2843`. The floor still
resumes to the same `FLOOR4.MES` handoff and still writes `global_u8[1915]`
at `2732..2738`. Re-entering the callee after that run takes the 11-message
`4235..4236` path, because the flag the first visit set is now `1`: the event
has a first-visit body and a seen body, chosen by a flag the event writes on
its own first pass. Site B, whose guard requires the flag set, can only ever
run the seen body; site A runs whichever the flag selects. On the first-visit
path `state_u16[8]` is overwritten by the callee at `256..261` before the
`261` cascade, `global_u8[3006] = 1` flips `647`, and `global_u8[4000]` is
cleared before `490` by a write not traced to its routine on this path.

Site A's window is re-verified statically for this declaration: fifteen
records from the entry at `5299`, no branch, no edge originating before
`5405` that lands past `5421`, and no edge from outside `5299..5405` landing
inside it.

### Runtime groups: site B on v5, site A on v9

Site B is declared as `floor5_e15b_v5.json` on the v5 contract with
`natural_handoff`, `TIME_C.MES` among its members because E15's resume
dispatches it, eighteen guard cases, eight variants and a reentry that
replays the eleven-message body: audit accepted, `original event analysis
FLOOR5 E15B` passes 371 checks, a shifted guard false target rejected.

Site A needs a contract no earlier group had - an unguarded dispatch whose
callee returns - and Core 0.314.0 adds it as `kakyu_event_analysis_group/v9`:
v8's caller continuation with v7's `unconditional_dispatch` window and
selection witnesses in place of the guard. Declaring it exposed a defect in
the window audit itself: the first dialogue line of both unguarded windows
opens with a protagonist-name insert, which shares the command byte `0x0E`
with a root handoff, and the v7 window measurement counted dispatches by
command number rather than by decoded op. Command `0x0E` partitions into
exactly those two ops with no residue, so the audit now counts by op, a unit
test holds a name-insert window accepted and a real handoff rejected, and
G08's window is unchanged by the correction.

Site A is then `floor5_e15a_v9.json`: two routes over one window
(`5299..5405`, fifteen records, no escaping edge, one return candidate at
`5381`), `floor5-e15a-first` with the flag clear - the 20-message body to
`2842..2843`, four variants, and the seen path as its reentry - and
`floor5-e15a-seen` with the flag set - the 11-message body to `4235..4236`,
four variants, and a reentry that replays it, measured to match site B's own
completed reentry exactly. Both share the selection witnesses and the
resume. The audit accepts it and rejects the first route's return shifted by
one byte; `original event analysis FLOOR5 E15A` passes 388 checks. With the
three landings every FLOOR5 intro is declared, and the corrected window
audit still accepts every earlier profile: all 33 committed groups pass
together.

Correction, 2026-09-13 (Core 0.316.0): the shared window `5299..5405` holds
nine typed records and no return candidate under the system-call framing -
the `00` at `5381` is a message wait's record-list terminator - and both
routes' declarations were re-measured to those values, edge count and prefix
hash unchanged.

### One flag closes the guarded entrance, and either entrance writes it

Against the state the callee leaves, all twelve conjuncts still hold: the
callee's only write to a guard cell is `global_u8[1914]` at `3034..3040`,
and it rewrites `1` to `1`. Against the state after the resume, conjunct 12
fails: the floor writes `global_u8[1915] = 1` at `2732..2738`, in the shared
code both resumes reach, so running the event from **either** site closes
site B's guard. That is a caller-owned completion written after the callee,
C18's shape, with the addition that the unguarded entrance consumes the
guarded one's flag. The callee never tests `[1915]`, so re-entering it from
`0` after the resume replays all 11 messages, and re-entering it directly
from its own post-run state is exactly idempotent.

## EVENTM18, EVENTH10 and EVENTH16: the chain behind result 4

Measured 2026-09-11. The three guards chain by their false edges and every
one begins with `state_u16[21] == 4`; that result is seeded at each guard,
and the selection that produces it is before the chain and not measured.

### Witnesses

Fifteen, twenty-one and twenty-eight witnesses pin every boundary. M18:
`1115/1116`, `1510/1511`, `1229/1230`, `1500/1501`, `global_u8[2509]` at
`10/11`, results `3` and `5` rejected. H10: `915/916`, `1115/1116`,
`1229/1230`, `1529/1530`, `banked_u16[207]` at `55/56` and `80/81`. H16:
`1115/1116`, `1510/1511`, `1229/1230`, `1500/1501`, `banked_u16[207]` and
`[208]` at `70/71`. In every case the prerequisite cleared, result `3`, and
each clear flag set reject; every accepting witness yields the same 6-message
prefix.

### One route each, all three ending on FLOOR4

| Intro | Callee messages | Return | Resume messages | Resume stop |
|---|---:|---|---:|---|
| `EVENTM18` | 28 | `2598..2599` | 9 | `4846..4860 -> FLOOR4.MES` |
| `EVENTH10` | 87 | `3440..3441` | 0 | `4846..4860 -> FLOOR4.MES` |
| `EVENTH16` | 22 | `3134..3135` | 6 | `4846..4860 -> FLOOR4.MES` |

Each callee returns, and the floor resumes into the same code: it calls
`TIME_C.MES`, resets `state_u16[21]` at `2449..2455`, and reaches the
root handoff `FLOOR5.MES:4846..4860 -> FLOOR4.MES` - after an event on this
floor the map hands the player down to `FLOOR4`. No routine-40 selection
stands in the way. Segmented and unbroken runs agree for all three.

The callees share one template: an early test of the route's own "seen"
flag at `229`, a `global_u8[4000]` test, a three-way `state_u16[8]` cascade,
a `global_u8[3006]` test and one route-specific test. `global_u8[3006] = 1`
flips `651` in all three and `global_u8[2847] = 1` flips H10's `1955`;
`global_u8[4000]` is cleared by shared routine 28 at `LIBLARY.LIB:756..762`,
called at `256`, before it is read. Two cells are written by the **caller's
own prefix** before the callee starts - `state_u16[8]` (to `11`, `9` and
`11`) and `state_u16[2]` (to `1`) - so the callee's tests of them are not
inputs of these routes; the callee then rewrites `state_u16[8]` again at
`415..420` / `266..271`. M18's and H16's last branch (`2497`, `3019`) is a
loop visited with both truth values in one run.

### Completion is caller-owned, written in the resume

None of the three callees writes any cell of any of the three guards. The
floor's resume does: after the callee returns it sets the route's own flag -
`global_u8[2515]` at `6244..6250` for M18, `global_u8[2318]` at `7698..7704`
for H10, and both `global_u8[2279]` at `8317..8323` and `[2331]` at
`8328..8334` for H16 - and resets `state_u16[21]`, so each guard is false
after its resume and still true after its callee. That is C18's caller-owned
shape. The callee's first branch tests that same flag, so re-entering it
after the resume emits **0 messages** and returns at `2604..2605`,
`3446..3447` and `3140..3141`, while re-entering it directly, before the
floor has written anything, replays the whole body. No route writes another
route's guard cell, and nothing measured writes `global_u8[2284]`,
`global_u8[2509]` or `global_u8[150]`.

### Evidence boundary

Confidence is **Confirmed** for the three predicates and their sixty-four
witnesses, the three routes to their exact returns and the shared `FLOOR4`
handoff, the segmented/unbroken agreement, the caller-prefix writes, the
dead and live inputs, the caller-owned completion writes and both reentries
of each.

**Unresolved**: the floor's selection that answers `4`; what sets
`global_u8[2284]`, `[2509]` and `[150]`; the `FLOOR4.MES` continuation past
`4846`; native presentation.

### Runtime groups: `floor5_m18_v5.json`, `floor5_h10_v5.json`, `floor5_h16_v5.json`

Each is declared on the `kakyu_event_analysis_group/v5` caller-continuation
contract with the `natural_handoff` resume policy, `TIME_C.MES` among its
source members, its guard cases, its dispatch-reaching variants with callee
and resume expectations, and the zero-message completed reentry. The shared
resume terminal `4846..4860` lies inside one of the floor's three preserved
opaque boundary records, `4730..5066`, so it is bound as a runtime
observation in an opaque tail with that tail's hash - the binding GROUND's
C12 group already uses - and a structural decode of the span confirms the
command-`0x0E` handoff to `FLOOR4.MES`. The audits accept all three and
reject a resume handoff shifted by one byte and a reentry return shifted
by one; the batch checks `original event analysis FLOOR5 M18`, `H10` and
`H16` pass 381, 498 and 541 checks, and the validator rejects a wrong resume
message count once per variant. Landing them promotes the three events to
analysis-group measured and binds `FLOOR5.MES` and `FLOOR4.MES` for the
first time.

## Arrival: the floor's own poll, declared (2026-09-14, Core 0.319.0)

The chain behind result 4 and G21 were declared from their guards with
`state_u16[21]` seeded. Under Core 0.319.0 they start at the floor's entry
`0` and supply the player's locations at the floor's own `Util(6,13)` poll.
The walk loop at `2316..2706` has the shape of the other floors': with
`global_u8[3001] == 0` it runs `Util(6,8)`, copies `[17] = [18]`, calls
`FLOOR5.INC.MES` and polls at `2422` on a menu request (`[17] == 65534`),
otherwise polls at `2441`, copies `[21] = [18]`, waits and leaves the loop
unless both cells are `0xFFFF`; mode 2 polls at `2615`; the arm switch at
`2706` follows.

M18, H10 and H16 need two locations: `4` at the arrival, spent by the
prefix, and - once the callee returns and the floor polls again - `0`,
spent by the resume: the stairs, whose arm flows on to the `FLOOR4` handoff
at `4846` that the 2026-09-11 declaration had reached from the unseeded
`state_u16[18] = 0`. G21 needs one: it sits in arm `0` itself, and the walk
past its site reaches the same handoff without polling again.
`floor5_m18_v12.json` (482 checks), `floor5_h10_v12.json` (525),
`floor5_h16_v12.json` (668) and `floor5_g21_v12.json` (389)
replace the v5 profiles with the same resume terminals and message counts
and with every variant of the 2026-09-11 declaration carried over (the
drafter had not derived four of them);
the resumes' effects gain the map cells as the walk leaves them
(`state_u16[17] = 4`, `[18] = 0` for the chain). The next location instead
is rejected in each. The calendar is the 2026-09-11 declaration's: Saturday,
13:00, the dates per group.

E15's site B followed, hand-set in the spec because the drafter picks the
unguarded site A: locations `2` (the corridor's arm) at the arrival and `0`
once the callee returns, `floor5_e15b_v12.json` (386 checks) replacing
the v5 profile with its 18 guard witnesses and every variant carried over,
the same `FLOOR4` handoff after 0 messages. Measured on the way: with the
second poll left undeclared the walk stays on location `2`, and arm 2's
body replays E15 through its unguarded site A (88 messages) before the
`34C.MES` handoff at `5837` - which is what a player who stays in the
corridor after the scene would get, and is not what the group declares.

F01 and E15's site A, the two v9 window groups, followed on 2026-09-15 as
arrival groups declared beside them, and the arrival corrects the reading
that they have no guard: that was the origin's doing. Read from the floor's
entry, F01's site sits in arm `0` behind the typed guard at `2778..2852` -
Saturday, `4/01..6/15`, `12:31..16:00`, `global_u8[100]`, `[104]`, `[107]`,
`[1620]`, `[1545]` and `[1619]` clear - whose false edge is G21's guard at
`3540`; the v9 group's `10/01` baseline lies outside that window, which is
why its origin had to be the address-table entry at `2978` (the first-visit
flag `[1915]` at `2721` gates nothing: its branch skips only the write).
E15's site A sits in arm `2` behind the typed guard at `4938..5021` -
`9/16..11/15`, `12:30..14:29`, the E word `banked_u16[202]` above `70`,
`global_u8[2509]` below `12`, and `[120]`, `[1833]`, `[124]`, `[150]`,
`[154]` and the seen flag `[1914]` clear - whose false edge is site B's
guard at `5543`; the v9 group's "seen" route (`[1914] = 1`) is therefore
not a site-A route from the arrival at all.

`floor5_f01_arrival_v12.json` (504 checks) takes location `0` at the poll
`2441` on Saturday `5/01` `13:00`, one route per answer of F01's own
question, and reaches the same `FLOOR4` handoff without polling again;
`floor5_e15a_arrival_v12.json` (543) takes `2` then `0` once the callee
returns, on `10/01` `13:00` with the E word at `71`. Both carry the v9
groups' variants (those outside the guards' windows are recorded as measured
and not declared). The v9 groups keep their window proofs - no edge between
the typed origin and the dispatch skips it - and the arrival groups the way
in. The next location instead is rejected in both.

Not declared from the arrival: the menu path and the mode-2 arrival; which
mode each of the callers leaves in `[3001]`; staying on location `2` after
E15.

## Reproduction

The measurement scripts are local under the gitignored `analysis/`:
`probe_floor5_group.py`, `probe_floor5_guards.py`, `probe_floor5_gaps.py`,
`probe_floor5_gap_detail.py`, `probe_floor5_predicates.py`,
`probe_floor5_window.py`, `build_floor5_group_measure.py` (run first on
`01M.MES` as the control), `measure_f5f01.gd`, `measure_f5g21.gd`,
`measure_f5e15.gd` with its `f5e15_probe_*.gd` diagnostics,
`measure_f5m18.gd`, `measure_f5h10.gd`, `measure_f5h16.gd` and the
`build_f5*_profile.py` generators. The caller graph comes from
`tools/build_event_analysis_inventory.py`; the profiles are checked by
`tools/audit_event_analysis_group.py` and
`tools/content_suite/validators/validate_event_analysis_group.gd`.
