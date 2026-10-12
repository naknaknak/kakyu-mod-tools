# 11M caller group

Inventoried on 2026-09-12 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`11M.MES` is a root the town map hands off to (`MACHI.MES:25223`, command
`0x0E`, its only literal caller), the largest caller opened so far, with
five EVENT intro sites of which three are unresolved: `EVENTJ01` and
`EVENTK14` as nested calls the caller resumes after, and `EVENTH04` as a
root handoff into a callee that hands the root back to `MACHI.MES`. The
other two sites dispatch `EVENTB15`, already qualified in the catalog. The
instrument is the one that opened the earlier groups; run first on
`01M.MES`, it reproduces the 44C-era control exactly before it is run here.

## The caller

| Property | `11M.MES` |
|---|---|
| framing-opaque bytes | **0 of 53,586** |
| instructions / branches / calls | 7,064 / 387 / 780 |
| address-table entries | 321 |
| EVENT intro sites | 5, for four targets (`EVENTB15` twice, qualified) |
| unresolved intros with a typed guard candidate | **all 3** |
| dispatch form | J01 and K14 nested calls, H04 a root handoff |
| framing-opaque bytes in the callees | 0 |

No unresolved target has another caller anywhere in the archive.
`EVENTJ01.MES` is one body behind its own `global_u8[903]` gate with a
three-answer question at `3025` and returns to the caller; `EVENTH04.MES`
is one body behind `[2294]` with one door (`7249..7262 -> MACHI.MES`),
dispatching `H_PIC.MES` on the way; `EVENTK14.MES` is one body behind
`[2339]` that dispatches `K_PIC.MES` and `H_PIC.MES` and returns. No callee
dispatches `TRAIN.MES`.

## The three intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---:|---:|---:|
| `EVENTJ01` | `12994..13010` | nested call | `12736..12836` | 5,535 | 12 | 56 |
| `EVENTH04` | `15392..15408` | root handoff | `13962..14064` | 7,268 | 32 | 77 |
| `EVENTK14` | `27152..27168` | nested call | `26856..27000` | 4,017 | 20 | 36 |

## Three long guards

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---:|---:|:-:|---:|---:|---:|---:|
| `EVENTJ01` | `12736..12836` | `13315` | 15 | - | 158 | 30 | **0** | **0** | 0 |
| `EVENTH04` | `13962..14064` | `15423` | 15 | - | 1,328 | 175 | **0** | 1 (`H_PIC`) | 0 |
| `EVENTK14` | `26856..27000` | `27968` | 22 | - | 152 | 30 | **0** | **0** | 0 |

J01's false edge is the first B15 site's guard, and the two B15 guards
fall in turn to `13736`, past which the caller writes `[656]` and reaches
H04's guard; H04's gap writes `[176]` and dispatches `H_PIC.MES` at
`14670` before the handoff; K14's guard stands alone at `26856`. What the
caller does after the two nested calls matters here: after J01 returns it
runs a date ladder and writes `[903] = 1` at `13288` and `[350] = 1` at
`13299` - J01's clear conjunct, closed by the caller as on 21C's L07 -
and after K14 returns it runs a `[2847]` arm, a `state_u16[8]` ladder and
a date ladder and writes `[2339] = 1` at `27927`, `[2279] = 1` at `27938`
and `banked_u16[242]` at `27949`, two of K14's clear conjuncts. Neither
callee writes its own guard cell; H04's does.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`0` a weekday, `6` Saturday), the date
`state_u16[7]` as MMDD (months past `12` are the following year's), the
clock `state_u16[19]` as HHMM, and `banked_u16[207]`, `[208]`, `[211]`
the H, K and J families' affection words. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTJ01` | weekday `0`, `4/28..6/31`, `9:01..15:59` | `[211] > 40` | `[401]` | `[210]`, `[212]`, `[214]`, `[812]`, `[215]`, `[217]`, `[903]`, `[784]` |
| `EVENTH04` | weekday `0`, `6/16..9/15`, `9:01..15:59` | `[207]` in `36..79` | `[397]`, `[2292]` | `[170]`, `[174]`, `[177]`, `[2294]`, `[2124]`, `[2083]` |
| `EVENTK14` | weekday `0`, `11/16..15/10`, `11:00..17:00` | `[207] > 80`, `[208] > 80` | `[2284]`, `[2098]`, `[2199]` | `[170]`, `[174]`, `[180]`, `[184]`, `[2279]`, `[2339]`, `[2225]`, `[2124]`, `[177]`, `[187]`, `[2083]`, `[2184]` |

Read, not yet measured. J01 is the J family's spring weekday daytime with
the word above `40` and `[401]` set - the same `[401]` and the same clear
set (`[210]`, `[212]`, `[214]`, `[812]`, `[215]`, `[217]`, `[784]`) that
07M's J19 reads, so the two are one thread's first and last steps; the
callee's own `[903]` gate is closed by the caller, not the callee. H04 is
the H family's summer weekday daytime with the H word in the middle band,
its callee counting `[244]` and closing its own `[2294]`. K14 is the
winter weekday that wants both the H and the K words above `80` - the
first guard here on two affection words at once - and twelve flags clear,
two of which (`[2339]`, `[2279]`) the caller closes after the call.

## EVENTJ01: the J family's spring weekday, the callee's question, the caller closing the gate

Measured 2026-09-12. `11M.MES:12736..12836` (false `13315`, the first
B15 site's guard) wants a weekday-`0` daytime (`9:01..15:59`) from `4/28`
to `6/31`, the J word `banked_u16[211]` above `40`, `global_u8[401]` set,
and `[210]`, `[212]`, `[214]`, `[812]`, `[215]`, `[217]`, `[903]`, `[784]`
clear - the same `[401]` and the same clear set that 07M's J19 reads;
twenty-two witnesses pin every edge and flip every flag. The prefix is 6
messages to the nested call at `12994..13010`. `EVENTJ01.MES` counts
`[234]` at its entry, runs 33 messages to its own question at `3025`
(three definitions, consumer the `state_u16[21]` chain at `3035`), and
every answer returns at `5503..5504` after 49 messages in all, moving the
J word by one - up on answer `1` at `3676`, down on answers `2` and `3`
at `4288` and `4914` behind `> 1` gates the guard's `> 40` cannot fail
(witnessed at `1` and `2` by direct probes) - and writing `[3712]` and
`[5330]`; it never writes `[903]`. The caller's resume from `13010` runs
a date ladder, 6 messages, and closes the guard itself: `[903] = 1` at
`13288` - the callee's own gate - and `[350] = 1` at `13299`, then falls
through the two B15 guards and stops before the caller's own two-answer
question at `53145`, the same boundary K14's resume reaches. The guard
rejects on the resumed state (`post_guard_expected` 0); a completed
reentry of the callee on that state counts `[234]` once more and returns
through the done-gate at `5534..5535` with **0 messages**, while a direct
reentry on the callee's own final state, where `[903]` is still clear,
replays the body. Segmented and unbroken runs agree under every answer.
`state_u16[8]` is rewritten at `420` before it is read and
`global_u8[4000]` reads `0` at the callee's entry whatever is seeded;
`[3006]` and `[2847]` flip one arm each; the caller's date ladder after
the return lies outside the guard's window.

Declared as `11m_j01_v8.json` with the callee's contract, `P_PIC` and
`MACHI` among the members (only rejecting walks reach them), three
continuation routes
by the callee's answer with 33 variants in all, each variant naming
its answer, the resume on the `def_selection_boundary` policy stopping at
the caller's routine-40 record at `53145` with `[903]` and `[350]` in its
expected state, `post_guard_expected` 0, the reentry the done-gate return
with its counter. Audit accepted; `original event analysis 11M J01`
passes 1154 checks; a wrong resume message count and the call record
shifted one byte are rejected.

## EVENTH04: the H family's summer weekday, one door

Measured 2026-09-12. `11M.MES:13962..14064` (false `15423`) wants a
weekday-`0` daytime (`9:01..15:59`) from `6/16` to `9/15`, the H word
`banked_u16[207]` in `36..79`, `global_u8[397]` and `[2292]` set, and
`[170]`, `[174]`, `[177]`, `[2294]`, `[2124]`, `[2083]` clear; twenty-two
witnesses pin every edge and flip every flag. The prefix runs 22 messages
through `H_PIC.MES`, writing `[176]`, to the root handoff at
`15392..15408`. `EVENTH04.MES` counts `[244]` at its entry, runs 106
messages through `H_PIC` again to its one door `7249..7262 -> MACHI.MES`,
and writes on the way `banked_u16[242] = 11`, `global_u8[286]`, `[3602]`,
`[5216]`, the counter `[234]`, `[2278] = 0` and, at `7187`, its done flag
`[2294]`, a conjunct of the guard; it never touches the H word. The guard
rejects on the post-replacement state, and a direct reentry counts
`[244]` once more before the done-gate at `244` returns it at
`7267..7268` with **0 messages** - declared as the reentry with that
count. Segmented and unbroken runs agree. `state_u16[8]` and
`state_u16[2]` are rewritten by the callee before they are read and
`global_u8[4000]` reads `0` at its entry whatever is seeded; the clock
ladders select `[3264]` (`15:59` changes two arms), `[2847]` flips three
arms and `[3006]` one; the callee's date ladders lie outside the guard's
window and are not reached from the origin.

Declared as `11m_h04_v6.json` with no contract, `H_PIC` and `MACHI`
among the members, one root-replacement route `11m-h04` with 13
variants, `post_guard_expected` 0, the reentry the return record with its
counter. Audit accepted; `original event analysis 11M H04` passes 328
checks; a wrong callee message count and the door shifted one byte are
rejected.

## EVENTK14: the winter weekday on two affection words, closed by the caller

Measured 2026-09-12. `11M.MES:26856..27000` (false `27968`) is
twenty-two conjuncts: a weekday-`0` late morning to afternoon
(`11:00..17:00`) from `11/16` to `15/10`, the H word `banked_u16[207]`
and the K word `[208]` both above `80` - the first guard here on two
affection words at once - `global_u8[2284]`, `[2098]`, `[2199]` set, and
twelve flags clear; thirty witnesses pin every edge and flip every flag.
The prefix is 6 messages to the nested call at `27152..27168`.
`EVENTK14.MES` runs 49 messages through `K_PIC.MES` and `H_PIC.MES` to
its return at `4010..4011`, writing `[186]`, `[176]`, `[3610]`, `[3637]`,
`[5227]`, `[5258]` and the clock-ladder cell `[3282]`, and no guard cell
at all. The caller's resume from `27168` runs a `[2847]` arm, its own
`state_u16[8]` ladder and a date ladder, 9 messages, and then closes the
guard itself: `[2339] = 1` at `27927` - the callee's own gate - `[2279] =
1` at `27938` and `banked_u16[242] = 11` at `27949`, after which an
unconditional transfer at `27963` jumps past the next block to `52915`
and the resume stops before the caller's own two-answer question at
`53145`. The guard rejects on the resumed state (`post_guard_expected`
0); a completed reentry of the callee on that state returns at
`4016..4017` with **0 messages**, and a direct reentry on the callee's
own final state, where `[2339]` is still clear, replays the same 49
messages without changing a cell. Segmented and unbroken runs agree.
`state_u16[8]` is rewritten by the callee at `369` and by the caller at
`27303` before either reads it and `global_u8[4000]` reads `0` at the
callee's entry whatever is seeded; the clock ladders select `[3282]`
(`16:00` and `17:00` flip six arms to the `< 18:00` band, `5:59` reached
only by a direct probe); `[2847]` flips two callee arms and `[3006]` one.

Declared as `11m_k14_v8.json` with no contract, `K_PIC` and `H_PIC`
among the members, one continuation route `11m-k14` with 15
variants, the resume on the `def_selection_boundary` policy stopping at
the caller's routine-40 record at `53145` with the caller's three
writes in its expected state, `post_guard_expected` 0, the reentry the
done-gate return. Audit accepted; `original event analysis 11M K14`
passes 511 checks; a wrong resume message count and the call record
shifted one byte are rejected.

Every unresolved 11M intro is measured and declared: three sites, three
targets, three groups, five routes, no contract change. Two of the three
guards are closed by the caller after the return rather than by the
callee, and both nested resumes converge on the caller's own question at
`53145`; the third closes itself at its one door.


## Not measured here

What schedules `MACHI.MES:25223` into `11M.MES`; what sets `[401]`,
`[397]`, `[2292]`, `[2284]`, `[2098]`, `[2199]` and what moves the three
affection words outside these callees; what J01's question at `3025` and
the caller's at `53145` offer as native input (J01's results are supplied
explicitly, the caller's is not declared); and `MACHI.MES` past H04's door.

## EVENTB15 measured as a group, 2026-09-21

EP-10 unit 5a measured the one 11M site a hand-authored catalog row had
qualified (Mahoko event B15) with the route toolchain: `11m-b15`
(`11m_b15_v5.json`), a nested call (`0x0F`) at `13435..13451` behind the
guard `13315..13356` (false `13509`); the callee returns at `1912` and the
caller resumes at `13451` and hands the root to `MACHI.MES` at `13486`
(`natural_handoff`). Eight variants, 27 messages on the baseline, a
reentry of 9 messages. One free flag, `global_u8[655]`, that neither the
guard nor an earlier callee pins was added as a variant by hand. The
ending is a map return whose postlude is the place's. Members: `11M.MES`,
`EVENTB15.MES`, `START.MES`, `DEF_MAIN.MES`, `LIBLARY.LIB`. Batch check
`original event analysis 11M B15`; the v4 document `mahoko.town.11m.15.1`
is projected from the group since the same day.
