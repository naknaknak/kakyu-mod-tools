# 21C caller group

Inventoried on 2026-09-12 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`21C.MES` is a root `21M.MES` hands off to (`21M.MES:41761`, command `0x0E`,
its only literal caller), and one of three callers left with four unresolved
EVENT intro sites, for three targets: `EVENTA08` twice, `EVENTC08` and
`EVENTL07`. The instrument is the one that opened the earlier groups; run
first on `01M.MES`, it reproduces the 44C-era control exactly before it is
run here.

## The caller

| Property | `21C.MES` |
|---|---|
| framing-opaque bytes | **0 of 38,678** |
| instructions / branches / calls | 4,963 / 264 / 484 |
| address-table entries | 225 |
| EVENT intro sites | 4, for three targets (`EVENTA08` twice) |
| intros with a typed guard candidate | **all 4** |
| dispatch form | 3 root handoffs, 1 nested call |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTA08.MES` and
`EVENTC08.MES` end by handing the root to `MACHI.MES` (`8631..8644` and
`7037..7050`) and carry picture scripts as static dependencies - `A_PIC`
and `E_PIC` for A08, `O_PIC` for C08; `EVENTL07.MES`, the nested call,
dispatches `L_PIC` and returns. No callee dispatches `TRAIN.MES`.

## The four intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---:|---:|---:|
| `EVENTA08` (site A) | `4793..4809` | root handoff | `769..921` + `3833..3843` | 8,660 | 18 | 89 |
| `EVENTA08` (site B) | `7414..7430` | root handoff | `769..921` + `6598..6608` | 8,660 | 18 | 89 |
| `EVENTC08` | `8070..8086` | root handoff | `7473..7570` | 7,056 | 14 | 71 |
| `EVENTL07` | `8581..8597` | nested call | `8101..8202` | 2,215 | 6 | 18 |

## One ladder with a question at the top

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---:|---:|:-:|---:|---:|---:|---:|---:|
| `EVENTA08` A | `769..921` | `7473` | 23 | - | 3,872 | 524 | 6 | 2 (`E_PIC`, `A_PIC`) | 0 |
| | `3833..3843` | `4819` | 1 | - | 950 | 135 | 2 | 0 | 0 |
| `EVENTA08` B | `769..921` | `7473` | 23 | - | 6,493 | 884 | 14 | 3 (`E_PIC`, `A_PIC`, site A) | 0 |
| | `6598..6608` | `7435` | 1 | - | 806 | 107 | 0 | 0 | 0 |
| `EVENTC08` | `7473..7570` | `8101` | 15 | - | 500 | 67 | **0** | **0** | 0 |
| `EVENTL07` | `8101..8202` | `9169` | 14 | **yes** | 379 | 61 | **0** | **0** | 0 |

The three guards chain by their false edges: A08's twenty-three-conjunct
guard falls to C08's, C08's to L07's, L07's to `9169`. Between A08's guard
and its two sites the caller dispatches `E_PIC.MES` at `1229` and
`A_PIC.MES` at `2228`, branches on `global_u8[1837]`, `[2847]` and
`[1052]`, and asks its own routine-40 question at `3823..3828`, whose
consumer is the `state_u16[21]` chain: result `1` (`3833..3843`) passes two
affection gates - `banked_u16[201] > 3` at `4683`, `banked_u16[202] > 3` at
`4738`, both true under the guard - and hands off to site A at `4793`;
result `2` (`4819..4829`) runs a Christmas-date ladder (`12/24`, `13/01`,
neither) and its own two gates at `6483` / `6538` and reaches no event,
falling through `7435` to C08's guard; result `3` (`6598..6608`) hands off
to site B at `7414`. The A08 routes will take the guard `769..921` as origin
with the question answered `1` or `3`, the 18M I09 / M16 convention, and
measure result `2` as the arm that reaches no event. C08's and L07's gaps
are clean.

## The guards, read as scene conditions

Weekday is `state_u16[4]`, the date `state_u16[7]` as MMDD, the clock
`state_u16[19]` as HHMM, and `banked_u16[201]`, `[202]`, `[209]` affection
words - A's, E's and L's, by the families whose flags sit beside them.
Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTA08` | weekday `0`, `9:59 < clock < 13:00` | `40 < [201] < 80`, `40 < [202] < 80` | `[392]` | `[110]`, `[112]`, `[114]`, `[117]`, `[120]`, `[122]`, `[124]`, `[125]`, `[127]`, `[994]`, `[1034]`, `[1119]`, `[1120]`, `[1792]`, `[1833]` |
| `EVENTC08` | weekday `0`, `6/15 < date < 9/16`, `clock < 14:16` | - | `[396]`, `[1728]` | `[160]`, `[164]`, `[167]`, `[230]`, `[1653]`, `[1694]`, `[1729]`, `[1755]`, `[1766]` |
| `EVENTL07` | weekday `0` **or** `12/24`; `6/15 < date < 9/16`, `10:00 < clock < 14:46` | `[209] > 35` | `[399]` | `[190]`, `[194]`, `[197]`, `[1925]`, `[1966]`, `[2042]`, `[2048]` |

Read, not yet measured. `EVENTA08` is a joint event: both the A word and
the E word must sit in `41..79`, `[392]` must be set, and its clear list is
the union of the A family's (`[110]`, `[112]`, `[114]`, `[117]`, `[994]`,
`[1034]`, `[1119]`, `[1120]`) and the E family's (`[120]`, `[122]`, `[124]`,
`[125]`, `[127]`, `[1792]`, `[1833]`) - 17M's A02 and A20 and 23M's E01
and E03 read the same cells - with no date at all, only a weekday-0 late
morning. `EVENTC08` is the C family's summer morning: 17M C10's
prerequisites `[396]` and `[1728]`, the clear flags 23M's C rungs share
(`[1755]` among them, which every C event sets) and its own `[1766]`.
`EVENTL07` is the L family's summer late morning with a Christmas Eve
exception in place of the weekday: 44C `EVENTL25`'s `[399]`, `[190]`,
`[194]`, `[197]`, `[1925]`, `[1966]`, `[2042]` and its own `[2048]`, the L
word above `35` after L25's `45`.

## EVENTA08: a joint A-and-E event behind the caller's own question

Measured 2026-09-12. `21C.MES:769..921` (false `7473`, C08's guard) is
twenty-three conjuncts: a weekday-`0` late morning (`10:00..12:59`), the A
word `banked_u16[201]` and the E word `[202]` both in `41..79`,
`global_u8[392]` set, and fifteen flags clear - the A family's `[110]`,
`[112]`, `[114]`, `[117]`, `[994]`, `[1034]`, `[1119]`, `[1120]` and the
E family's `[120]`, `[122]`, `[124]`, `[125]`, `[127]`, `[1792]`, `[1833]`;
thirty witnesses pin every edge and flip every flag. Between the guard and
the sites the caller runs `E_PIC.MES` and `A_PIC.MES`, branches on
`[1837]`, `[2847]` and `[1052]`, and asks its own routine-40 question at
`3823` (resume `3828`, three definitions, consumer the `state_u16[21]`
chain at `3833`): result `1` passes two affection gates that the guard
already satisfies and hands off to site A at `4793` after 59 caller
messages, having moved both words from `60` to `57`; result `3` hands off
to site B at `7414` after 55, moving both to `61`; result `2` runs a
Christmas-date ladder, reaches no event, and falls through `7435` and
C08's guard to the caller's later selection at `35369` after 84 messages.
Both sites hand `EVENTA08.MES` the root, and from either the callee runs
the same 115 messages - through `E_PIC` and `A_PIC` again - to its handoff
`8631..8644 -> MACHI.MES`, writing `global_u8[286]`, `[3436]`, `[5035]`,
`[5036]` and, at `8575..8592`, its done flag `[1120]` and `[1119]`, both
conjuncts of the guard that admitted it; the callee touches no affection
word. Completion is callee-owned and the done-gate at `219` sends a direct
reentry to the `banked_u16[200] > 30` test at `8597` and out through the
same handoff with **0 messages**. Segmented and unbroken runs agree at both
sites (174 and 170 messages). `global_u8[4000]` is reset by a routine at
`394` and `state_u16[8]` rewritten at `235` before either is read;
`[3006]` flips `4559`, `[2847]` flips three arms, the callee's date ladder
splits `12/24` and `13/01` from the rest, and `[200]` above `30` sets
`[108]` just before the handoff.

Declared as `21c_a08_v6.json` with the caller's contract, `A_PIC`, `E_PIC`
and `MACHI` among the members, two root-replacement routes over the one
guard - `21c-a08-result1` to site A and `21c-a08-result3` to site B, 15
variants each naming its result - `post_guard_expected` 0, the reentry the
handoff record itself. Audit accepted; `original event analysis 21C A08`
passes 676 checks; site B's call record shifted one byte and a wrong
reentry message count are rejected.

## EVENTC08: the C family's summer morning

Measured 2026-09-12. `21C.MES:7473..7570` (false `8101`, L07's guard) needs
weekday `0`, `6/16..9/15`, `clock < 14:16`, C10's prerequisites
`global_u8[396]` and `[1728]` set and `[160]`, `[164]`, `[167]`, `[230]`,
`[1653]`, `[1694]`, `[1729]`, `[1755]`, `[1766]` clear; twenty witnesses
pin every edge and flip every flag, and a clock of `0:00` is admitted -
the window has no lower bound. The prefix is 9 messages through 67 records
with no branch, and the dispatch at `8070..8086` is a root handoff.
`EVENTC08.MES` runs 91 messages from `0` through `O_PIC.MES` to its handoff
`7037..7050 -> MACHI.MES`, writing `banked_u16[1] = 7`, `global_u8[235] =
4`, `[286]`, `[3575]`, `[5187]`, `[5188]`, its done flag `[1766] = 1` at
`6973..6979` and `[1755] = 1` at `6984..6990` - the C family's flag again,
which this guard and every other C guard require clear - and no map word.
Completion is callee-owned twice over; the guard rejects after the
replacement and the gate at `224` sends a direct reentry to the final
return `7055..7056` with **0 messages**. Segmented and unbroken runs agree
(100 messages). The L word `banked_u16[209]` in `41..100` at `6995`
selects presentation only; `[3006]` and `[2847]` flip two arms each; the
date ladder splits Christmas; `state_u16[8]` and `global_u8[4000]` are
dead inputs. When this guard rejects the walk falls through L07's guard to
the caller's selection at `35369` after 31 messages.

Declared as `21c_c08_v6.json` with `O_PIC.MES` among the members, one
root-replacement route, `post_guard_expected` 0, thirteen variants. Audit
accepted; `original event analysis 21C C08` passes 350 checks; a wrong
reentry message count and the handoff shifted one byte are rejected.

## EVENTL07: the L family's summer late morning, a nested call the caller finishes at its own question

Measured 2026-09-12. `21C.MES:8101..8202` (false `9169`), the ladder's
last rung, needs `6/16..9/15`, `10:01..14:45`, the L word `banked_u16[209]`
above `35`, `global_u8[399]` set and `[190]`, `[194]`, `[197]`, `[1925]`,
`[1966]`, `[2042]`, `[2048]` clear, on weekday `0` **or** `12/24` - an arm
that cannot meet the summer window and is witnessed dead; twenty-one
witnesses pin every edge and flip every flag. The prefix is 10 messages
through 61 records with no branch, and the dispatch at `8581..8597` is a
nested call. `EVENTL07.MES` runs 24 messages from `0` through `L_PIC.MES`
and returns at `2208..2209`, writing `banked_u16[1] = 7`, `global_u8[196] =
4`, `[1970]`, `[3659]`, `[5278]`, `state_u16[8] = 46` and, at `400..406`,
its done flag `[2048] = 1`; the L word is not touched. The caller resumes
at `8597`, emits 17 messages across five dialogue boundaries, writes
`global_u8[350] = 5`, `[733]` and `[2042] = 1` - another of its own guard's
flags, at `9131..9137` - and reaches its routine-40 question at `35369`
(resume `35374`, two definitions, consumer the `state_u16[21]` chain at
`35379`), in the stored form the contract builder supports. Answered `1`
or `2`, the caller writes `[286]` and hands the root to `MACHI.MES` at
`38644..38657` after 42 or 35 messages; at `14:45` either answer hands off
earlier, at `37337` or `38077`, a day-part tail measured and not declared.
Completion is doubly owned, L03's shape: the callee's `[2048]` and the
resume's `[2042]`; both reentries return at `2214..2215` with **0
messages**. Segmented and unbroken runs agree under both results (76 and
69 messages). `state_u16[8]` and `global_u8[4000]` are dead inputs;
`[2847]` flips `1007`.

Declared as `21c_l07_v5.json` with the caller's contract, `L_PIC` and
`MACHI` among the members, two caller-continuation routes over the one
guard - `21c-l07-result1` and `-result2`, 8 variants each naming its
result. Audit accepted; `original event analysis 21C L07` passes 721
checks; a wrong resume message count on the first route and the second
route's handoff shifted one byte are rejected.

Every 21C intro is measured and declared: four sites, three targets, three
groups, five routes, no contract change. Read together, the ladder's
three events belong to three families and never share a day: A08's
weekday-0 late morning with both A and E words in range, C08's summer
morning, L07's summer late morning; each callee closes its own guard, and
A08's and L07's callers move an affection word or close a second flag on
the way.

## Not measured here

What schedules `21M.MES:41761` into `21C.MES`; what the questions at `3823`
and `35369` offer as native input (their results are supplied explicitly);
what sets `[392]`, `[396]`, `[1728]` and `[399]` and moves the affection
words; the caller's `14:45` tails after L07; and `MACHI.MES` past every
handoff.
