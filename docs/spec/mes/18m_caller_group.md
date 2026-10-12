# 18M caller group: every intro measured, all six qualified

Measured on 2026-09-11 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`18M.MES` is the caller with six unresolved EVENT intros - the next after
FLOOR5 by that count, with the smaller callees of the two candidates. The
instrument is the one that opened the GROUND, 44M, 01M and FLOOR5 groups;
run first on `01M.MES`, it reproduces the `EVENTI16` row exactly before it is
run here. All six intros are qualified below on the existing v5 and v6
contracts.

## The caller

| Property | `18M.MES` |
|---|---|
| framing-opaque bytes | **0 of 68,049** |
| instructions / branches / calls | 8,858 / 541 / 1,100 |
| address-table entries | 301 |
| EVENT intro sites | 6, for six targets |
| intros with a typed guard candidate | **all 6** |
| dispatch form | three root handoffs, three nested calls |
| framing-opaque bytes in the callees | 0 |

## The six intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages | Root handoff in callee |
|---|---|---|---|---:|---:|---:|---|
| `EVENTI05` | `10992..11008` | root handoff | `10386..10418` | 6,489 | 15 | 80 | `6445..6458 -> MACHI` |
| `EVENTI09` | `13757..13773` | root handoff | `11018..11114` | 8,263 | 29 | 87 | three, all `-> MACHI` |
| `EVENTM16` | `17472..17488` | nested call | `14745..14794` | 3,555 | 8 | 36 | none |
| `EVENTK13` | `27626..27642` | nested call | `27322..27454` | 4,343 | 20 | 29 | none |
| `EVENTL04` | `34268..34284` | nested call | `34021..34122` | 5,850 | 24 | 51 | none |
| `EVENTC11` | `40527..40543` | root handoff | `40231..40341` | 3,282 | 22 | 23 | `3238..3251 -> MACHI` |

## Which intros are cleanly guarded

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---:|---:|:-:|---:|---:|---:|---:|---:|
| `EVENTI05` | `10386..10418` | `11018` | 4 | - | 574 | 88 | **0** | **0** | 0 |
| `EVENTI09` | `11018..11114` | `14745` | 14 | - | 2,643 | 333 | 7 | 1 | 1 |
| `EVENTM16` | `14745..14794` | `21180` | 7 | - | 2,678 | 356 | 2 | 1 | 1 |
| `EVENTK13` | `27322..27454` | `28494` | 20 | - | 172 | 30 | **0** | **0** | 0 |
| `EVENTL04` | `34021..34122` | `34686` | 14 | **yes** | 146 | 30 | **0** | **0** | 0 |
| `EVENTC11` | `40231..40341` | `40558` | 17 | - | 186 | 30 | **0** | **0** | 0 |

Four intros have nothing conditional between guard and dispatch.
`EVENTI05`'s false edge is `EVENTI09`'s guard and `EVENTI09`'s false edge is
`EVENTM16`'s, so those three chain; `EVENTK13`, `EVENTL04` and `EVENTC11`
stand alone. `EVENTI09`'s predicate lists `global_u8[1219] == 0` twice, as
its twelfth and fourteenth conjunct, the second such repeat after FLOOR5's
G21.

### Two intros stand behind the caller's own selection

`EVENTI09` and `EVENTM16` have three guard candidates each, the shape the
station's H07, M06 and M09 had:

| Intro | Eligibility guard | Constant-true record | Result gate | In the gap | Edge entering |
|---|---|---|---|---|---|
| `EVENTI09` | `11018..11114` | `13249..13256` (false `14729`) | `13395..13405`: `state_u16[21] == 1` (false `13783`) | `I_PIC.MES` at `11146`; five branches, all landing before the dispatch | `14724 -> 13249` |
| `EVENTM16` | `14745..14794` | `17056..17063` (false `21110`) | `17202..17212`: `state_u16[21] == 1` (false `19857`) | `M_PIC.MES` at `14957` | `21105 -> 17056` |

The constant-true record is measured as the literal `1` and is not a guard;
the gate requires the caller's routine-40 selection to have been answered
`1`; the entering edge is, as at the station, the path that re-asks the
selection when the answer is neither of the consumed results. The routes
measure that below.

## The guards, read as scene conditions

Weekday is `state_u16[4]`, the date `state_u16[7]` as MMDD, the clock
`state_u16[19]` as HHMM, and `banked_u16[203]`, `[207]`, `[208]`, `[209]`
affection words. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTI05` | date `== banked_u16[261]` | - | `[130]`, `[1324]` | `[1325]` |
| `EVENTI09` | weekday `0`, `6/15 < date < 9/16`, `10:00 < clock < 16:01` | `50 < banked_u16[203] < 81` | - | `[130]`, `[134]`, `[137]`, `[1219]`, `[1259]`, `[1331]` |
| `EVENTM16` | weekday `0`, `9/15 < date < 11/16`, `clock < 16:00` | - | - | `[150]`, `[2439]`, `[2502]` |
| `EVENTK13` | weekday `0`, `11/15 < date < 15/11`, `10:59 < clock < 17:01` | `banked_u16[207] > 80`, `[208] > 80` | `[2284]` | `[170]`, `[174]`, `[177]`, `[180]`, `[184]`, `[187]`, `[2083]`, `[2124]`, `[2184]`, `[2225]`, `[2279]`, `[2338]` |
| `EVENTL04` | weekday `0` **or** date `12/24`; `4/00 < date < 6/16`, `10:00 < clock < 16:01` | `banked_u16[209] > 35` | `[399]` | `[190]`, `[194]`, `[197]`, `[1925]`, `[1966]`, `[2042]`, `[2044]` |
| `EVENTC11` | weekday `0`, `6/15 < date < 9/16`, `10:00 < clock < 16:01` | - | `[396]`, `[1728]`, `[1764]` | `[160]`, `[164]`, `[167]`, `[230]`, `[1653]`, `[1694]`, `[1729]`, `[1755]`, `[1769]` |

Several of these predicates are earlier groups' predicates moved along their
arcs, and that is measured rather than read. `EVENTI05` is the fourth guard
to compare the date with a stored word (`banked_u16[261]`, after G11's
`[277]`, H07's `[268] + 1` and E15's `[265]`), and it requires
`global_u8[130]` **set** where 01M's `EVENTI16` and this caller's `EVENTI09`
require it clear. `EVENTK13`'s twenty conjuncts are FLOOR5's `EVENTH16`
predicate - the same `[2284]` prerequisite and eleven of the same clear
flags - with both affection words raised from `> 70` to `> 80` and a wider
clock: the K-series event is guarded by the H-series flags, the pairing the
replay gallery showed when the H and K galleries shared six scenes.
`EVENTL04` is 01M's `EVENTL03` guard - the same dead disjunction, the same
window, the same word and prerequisite - with `[2044]` in place of `[2043]`,
the flag L03's own callee sets. `EVENTC11` clears the five flags 44M's
`EVENTC18` clears (`[160]`, `[164]`, `[167]`, `[1653]`, `[1694]`) and adds
three prerequisites, in summer rather than on Christmas Eve. `EVENTM16`
shares `[150]` and `[2439]` with the station's M06 and M09. Date values
above `1231` follow the owner's month-13 reading.

## EVENTC11: seventeen conjuncts, a summer weekday

Measured 2026-09-11. `18M.MES:40231..40341` (false `40558`) requires weekday
`0`, `6/15 < date < 9/16`, `10:00 < clock < 16:01`, `global_u8[396]`,
`[1728]` and `[1764]` set, and nine flags clear. Twenty-two witnesses - five
accepting, seventeen rejecting - pin `615/616`, `915/916`, `1000/1001` and
`1600/1601`, and reject weekday `6`, each prerequisite cleared and each flag
set; every accepting witness gives the same 6-message prefix through 30
records.

`EVENTC11.MES` runs 27 messages from `0` to its one root-handoff terminal,
`3238..3251 -> MACHI.MES`, writing `global_u8[1755] = 1` at `3073..3079` and
`global_u8[1769] = 1` at `3084..3090` - two of the guard's own clear flags -
plus `banked_u16[1] = 7`, `banked_u16[242] = 18`, `global_u8[264]`, `[286]`,
`[3220]`, `[3577]`, `[5190]` and `state_u16[8] = 46`. Segmented and unbroken
runs agree. At `16:00` six clock branches change arm with no effect on
messages or state; `global_u8[3006] = 1` flips `954` and leaves
`global_u8[3005]` at `15`; `global_u8[2847] = 1` flips `2516`. `state_u16[8]`
is overwritten by the callee at `256..266` before its test and again by
shared routine 25 from `2511`, and `global_u8[4000]` is cleared by routine
28 from `251`. Seventeen of 22 branches are exercised; the other arms of the
`state_u16[8]` cascade are unreachable.

Completion is callee-owned through two conjuncts, and the completed reentry
returns at `3281..3282` with **0 messages**, writing only `state_u16[2] = 1`.
Declared as `18m_c11_v6.json`: audit accepted, `original event analysis 18M
C11` passes 351 checks, a terminal shifted by one byte rejected. The 16:00
band skips the routine that writes `state_u16[8]`, so that cell is declared
per variant.

## EVENTI05: the day stored in `banked_u16[261]`

Measured 2026-09-11. `18M.MES:10386..10418` (false `11018`) has four
conjuncts: the date equal to `banked_u16[261]`, `global_u8[130]` and
`[1324]` set, `[1325]` clear. No weekday, no clock. Six witnesses - one
accepting, five rejecting - reject the stored word one below and one above
the date, `[130]` or `[1324]` cleared, and `[1325]` set; the prefix is 14
messages through 88 records.

`EVENTI05.MES` runs to a routine-40 selection at `3078` (resume `3083`)
with three results whose definitions start at `3103`, `3955` and `5136`,
and every result reaches the same terminal, `6445..6458 -> MACHI.MES`, with
69, 76 and 65 callee messages. The callee clears `global_u8[130]` at
`6398..6404` and sets `[1325]` at `6409..6415` - the two guard cells it
owns - and writes `banked_u16[1] = 7`, `banked_u16[242] = 18`,
`global_u8[286]`, `[3496]`, `[5093]` and `state_u16[8] = 46`; result 2 also
moves `banked_u16[203]` by `+2` and sets `global_u8[244]` and `[2557]`.
Segmented and unbroken runs agree for every result. The guard's silence on
the clock is not the callee's: `06:00` and `17:00` seeds are measured and
change no arm at the baseline, while `global_u8[3006] = 1` flips `641`,
`global_u8[2847] = 1` flips `5857`, and `banked_u16[203] = 5` flips `3880`.
`state_u16[8]` is overwritten at `256..261` and `global_u8[4000]` cleared by
routine 28 from `246`. All fifteen branches but the two dead
`state_u16[8]` arms are exercised across the three results.

Completion is callee-owned - `[130]` cleared and `[1325]` set - and the
completed reentry returns at `6488..6489` with **0 messages**. Reading the
two I-series guards together: `EVENTI09` in this caller and 01M's
`EVENTI16` both require `global_u8[130]` **clear**, I05 requires it **set**
and clears it, so I05 stands after whatever sets `[130]` and closes that
window behind itself. Declared as `18m_i05_v6.json` with the callee's
three-result contract and thirteen variants: audit accepted, `original event
analysis 18M I05` passes 465 checks, a variant declared under the wrong
result rejected; every row's reentry matches the route's.

## EVENTK13: the H-series predicate, raised

Measured 2026-09-11. `18M.MES:27322..27454` (false `28494`) requires weekday
`0`, `11/15 < date < 15/11`, `10:59 < clock < 17:01`, `banked_u16[207] > 80`,
`[208] > 80`, `global_u8[2284]` set and twelve flags clear. Twenty-seven
witnesses - seven accepting, twenty rejecting - pin `1115/1116`,
`1510/1511`, `1059/1060`, `1700/1701`, and both words at `80/81`, and reject
weekday `6`, the prerequisite cleared and each flag set; every accepting
witness gives the same 6-message prefix through 30 records.

`EVENTK13.MES` runs 33 message observations from `0` and returns at
`4336..4337`, writing `banked_u16[1] = 7`, `global_u8[176]`, `[186]`,
`[3281]`, `[3609]`, `[3636]`, `[5226]`, `[5257]`, `global_u8[3005] = 2` and
`state_u16[8] = 46` - none of them a guard cell. The caller resumes at
`27642`, emits 18 messages across six dialogue boundaries, writes
`global_u8[2338] = 1` at `28424..28430` and `global_u8[2279] = 1` at
`28435..28441` - two of its own clear flags - plus `banked_u16[242] = 18`
and `global_u8[286]`, and stops at the root handoff
`18M.MES:28471..28484 -> MACHI.MES`. Segmented and unbroken runs agree. At
`17:00` six clock branches change arm with no effect; `global_u8[3006] = 1`
flips `1062` and `global_u8[2847] = 1` flips `3213` and `3696`;
`state_u16[8]` is overwritten at `608..613` before its test and
`global_u8[4000]` cleared by routine 28 from `359`. Eighteen of twenty
branches are exercised.

Completion is caller-owned through two conjuncts written in the resume,
C18's shape: the guard still accepts after the callee and rejects after the
resume, the completed reentry returns at `4342..4343` with **0 messages**,
and the direct reentry replays all 33. Declared as `18m_k13_v5.json` with
`H_PIC.MES` and `K_PIC.MES` among its members - the callee calls both
without dialogue, and the validator refuses a member list that omits a
silent dispatch: audit accepted, `original event analysis 18M K13` passes
319 checks, a shifted resume handoff rejected.

## EVENTL04: L03 again, one flag later, with a question inside

Measured 2026-09-11. `18M.MES:34021..34122` (false `34686`) is 01M's
`EVENTL03` predicate with `global_u8[2044]` in place of `[2043]`: weekday
`0` or `12/24`, `4/00 < date < 6/16`, `10:00 < clock < 16:01`,
`banked_u16[209] > 35`, `[399]` set, seven flags clear. Twenty-one
witnesses pin `400/401`, `615/616`, `1000/1001`, `1600/1601` and `35/36`,
and the disjunction is measured on all four combinations: only weekday `0`
with a date inside the window accepts, so the `12/24` arm is dead here as
it was in L03.

`EVENTL04.MES` runs to a routine-40 selection at `2431` (resume `2436`)
whose three results consume `state_u16[21]` through definitions at
`2214`, `2283` and `2360`; every result returns at the same record,
`5818..5819`, with 32 messages, and the results differ in what they do to
the affection word - `banked_u16[209]` moves `+1` for result 1 and `-2`
for results 2 and 3. Before the question, at `741..747`, the callee writes
`global_u8[2044] = 1`, its own guard's flag; it also writes
`banked_u16[1] = 7`, `global_u8[3286]`, `[3656]`, `[5275]` and
`state_u16[8] = 46`. The caller resumes at `34284`, emits 9 messages,
writes `global_u8[2042] = 1` at `34659..34665` (another of the guard's
flags, and one of 44M L10's), `banked_u16[242] = 18`, `global_u8[286]` and
`[350]`, and stops at the root handoff `18M.MES:67529..67542 -> MACHI.MES`
- a different exit from K13's. Segmented and unbroken runs agree for every
result. At `16:00` six clock branches change arm with no effect;
`global_u8[3006] = 1` flips `1058` and `global_u8[2847] = 1` flips `5695`;
`state_u16[8]` is overwritten at `359..364` and `global_u8[4000]` cleared by
routine 28 from `349`. Twenty-one of 24 branches are exercised.

Completion is owned twice, as for L03: the callee closes conjunct 12 by
itself before it even asks its question, and the resume closes conjunct 11.
Every reentry - completed, direct, and under each result - returns at
`5849..5850` with **0 messages**, because the callee's first test reads the
flag it wrote. Declared as `18m_l04_v5.json` with the callee contract and
twelve variants across the three results: audit accepted, `original event
analysis 18M L04` passes 451 checks, a variant declared under the wrong
result rejected by the validator - the audit accepts it, because a legal
result value is a runtime claim, not a source one.

## EVENTI09: two questions, three endings, and a narrower window than its guard

Measured 2026-09-11. `18M.MES:11018..11114` (false `14745`) requires
weekday `0`, `6/15 < date < 9/16`, `10:00 < clock < 16:01`,
`50 < banked_u16[203] < 81` and six flags clear (one listed twice). Twenty
witnesses pin `615/616`, `915/916`, `1000/1001`, `1600/1601`, `50/51` and
`80/81`.

The guard is not the whole condition. Its true edge runs into the first
candidate body, where the branch at `11832` tests the same affection word
again: `banked_u16[203] <= 60` takes the true arm into a different
narrative that ends at the root handoff `18M.MES:67529..67542 -> MACHI.MES`
- L04's exit - and never reaches the selection; `>= 61` takes the false arm
to `12402` and on to the selection. Swept over twelve values, the route's
accepting range is therefore `61..80`, not the guard's `51..80`; the
measurements below seed `61`, and the witness table keeps the literal `60`
so the divergence stays visible. Immediately after the guard, at
`11124..11130`, the caller writes `global_u8[1331] = 1` - the guard's last
conjunct - so the guard is closed before anything else happens, H07's shape.

The station-style selection sits at `13380` (resume `13385`) with two
results consumed at `13395` (result `1`, false to `13783`) and `13783`
(result `2`, false to `14724`, a transfer back to the constant-true record
`13249`: the re-ask loop). Result `1` reaches the handoff `13757..13773`
after 31 caller messages, `I_PIC.MES` having returned without dialogue.

`EVENTI09.MES` then asks a question of its own at `1811` (resume `1816`),
three results consumed at `1821` and `3130`, and each result ends at a
different root handoff:

| Callee result | Callee messages | Terminal |
|---:|---:|---|
| 1 | 30 | `3107..3120 -> MACHI.MES` |
| 2 | 60 | `5857..5870 -> MACHI.MES` |
| 3 | 49 | `8244..8257 -> MACHI.MES` |

Segmented and unbroken runs agree for each. Clock and date boundaries
change nothing; `global_u8[1332] = 1` - the callee's own seen flag, which
it sets on every ending - short-circuits the callee to a bare return at
`8262..8263`; `state_u16[8]` and `global_u8[4000]` are the usual dead
inputs. Re-entering the callee after any of the three endings returns at
`8262..8263` with **0 messages** whichever result is supplied.

Declared as `18m_i09_v6.json`: three routes, one per callee ending,
sharing the guard, the caller record, both choice contracts and twenty
guard cases, with `I_PIC.MES` among the members; the seed the routes use
is `banked_u16[203] = 61`, and the narrower `61..80` window is recorded as
the group's own limit. Audit accepted; `original event analysis 18M I09`
passes 829 checks; the result-2 terminal shifted by one byte rejected. The
seen-flag variant is measured and not declared, because it changes the
outcome.

## EVENTM16: the station's shape as a returning callee

Measured 2026-09-11. `18M.MES:14745..14794` (false `21180`) requires
weekday `0`, `9/15 < date < 11/16`, `clock < 16:00` and `global_u8[150]`,
`[2439]`, `[2502]` clear; eleven witnesses pin `915/916`, `1115/1116` and
`1599/1600`. The selection sits at `17187` (resume `17192`), two results,
the gate `17202..17212` for result `1`, a second gate at `19857` for
result `2` whose false path transfers from `21105` back to the
constant-true record `17056`. Answered `1`, the caller emits 46 messages,
`M_PIC.MES` returns without dialogue, and the nested call `17472..17488`
is reached.

`EVENTM16.MES` runs 48 messages from `0` and returns at `3523..3524`,
setting `global_u8[2503]` - its own seen flag, not a guard cell - and
writing `banked_u16[1] = 7`, `global_u8[3563]` and the rest of its
effects; its branch `118` tests `banked_u16[204]` in `41..80`, a threshold
local to the callee. The caller resumes at `17488`, emits 36 messages
across sixteen dialogue boundaries, writes `global_u8[2439] = 1` and
`global_u8[2502] = 1` - two of the guard's three flags - plus
`banked_u16[242] = 18`, and stops at the root handoff
`18M.MES:19834..19847 -> MACHI.MES`. Segmented and unbroken runs agree
(130 messages in all). Unlike H07 and I09, nothing writes a guard cell
before the dispatch: the guard still accepts after the callee and rejects
only after the resume, C18's caller-owned shape. Re-entering the callee
from `0` with either state returns immediately with **0 messages**,
because `[2503]` is already set. No run of either intro meets the
`TRAIN.MES:861` boundary the station's M06 and M09 met (since Core
0.316.0 that boundary is the train's location poll past `861`, declared
through a map-location contract on 2026-09-14; see the 01M group doc).

Declared as `18m_m16_v5.json` with the caller's contract in the prefix and
`M_PIC.MES` among the members, nine variants including both sides of the
callee's `41..80` threshold: audit accepted, `original event analysis 18M
M16` passes 358 checks, a wrong resume message count rejected once per
variant. The seen-flag variant is measured and not declared, as for I09.

## Reproduction

The measurement scripts are local under the gitignored `analysis/`:
`build_floor5_group_measure.py 18M.MES` with the `probe_floor5_*.py`
probes, `measure_18m_c11.gd`, `measure_18m_i05.gd`, `measure_18m_i09.gd`,
`measure_18m_k13.gd`, `measure_18m_l04.gd`, `measure_18m_m16.gd`, their
`18m_*_diag.gd` / `18m_*_probe_*.gd` diagnostics and the
`build_18m_*_profile.py` generators. The caller graph comes from
`tools/build_event_analysis_inventory.py`; the profiles are checked by
`tools/audit_event_analysis_group.py` and
`tools/content_suite/validators/validate_event_analysis_group.gd`.
