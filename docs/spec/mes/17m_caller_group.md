# 17M caller group

Inventoried on 2026-09-11 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`17M.MES` is a map root the town map hands off to (`MACHI.MES:25259`, command
`0x0E`, its only literal caller), and the caller with the most unresolved
EVENT intro sites left after the 44C group: five sites for four targets. Four
of the five are root handoffs, the first group since 44M's `EVENTL10` where
the caller does not resume - the callee replaces the root and its own
terminal is the route's end. The instrument is the one that opened the
GROUND, 44M, 01M, FLOOR5, 18M and 44C groups; run first on `01M.MES`, it
reproduces the `EVENTI16` row of the 44C-era control exactly before it is
run here.

## The caller

| Property | `17M.MES` |
|---|---|
| framing-opaque bytes | **0 of 52,760** |
| instructions / branches / calls | 6,792 / 399 / 812 |
| address-table entries | 234 |
| EVENT intro sites | 5, for four targets (`EVENTA20` twice) |
| intros with a typed guard candidate | **all 5** |
| dispatch form | 4 root handoffs, 1 nested call |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTC10.MES`, the
nested call, dispatches nothing and returns. The three handoff targets all
end by handing the root back to `MACHI.MES`: `EVENTA10.MES` at `3976..3989`,
`EVENTA02.MES` at `5248..5261`, and `EVENTA20.MES` at seven sites (`3451`,
`6924`, `7811`, `10408`, `13728`, `14536`, `17937`), with `A_INTRO.MES` as
its one other static dependency. No callee dispatches `TRAIN.MES`.

## The five intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---:|---:|---:|
| `EVENTC10` | `13441..13457` | nested call | `13051..13142` | 2,175 | 7 | 13 |
| `EVENTA10` | `21977..21993` | root handoff | `21618..21669` | 4,020 | 9 | 36 |
| `EVENTA02` | `23091..23107` | root handoff | `22684..22794` | 5,317 | 15 | 59 |
| `EVENTA20` (site A) | `43537..43553` | root handoff | `42677..42687` + 3 | 17,981 | 45 | 216 |
| `EVENTA20` (site B) | `43891..43907` | root handoff | `42677..42687` + 2 | 17,981 | 45 | 216 |

## Three clean guards and one tree

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---:|---:|:-:|---:|---:|---:|---:|---:|
| `EVENTC10` | `13051..13142` | `13865` | 14 | - | 299 | 49 | **0** | **0** | 0 |
| `EVENTA10` | `21618..21669` | `22003` | 7 | - | 308 | 48 | **0** | **0** | 0 |
| `EVENTA02` | `22684..22794` | `23122` | 16 | - | 297 | 49 | **0** | **0** | 0 |
| `EVENTA20` A | `42677..42687` | `44222` | 1 | - | 850 | 105 | 16 | 0 | 0 |
| | `42692..42718` | `43917` | 3 | - | 819 | 103 | 15 | 0 | 0 |
| | `42723..42734` | `43689` | 1 | - | 803 | 101 | 14 | 0 | 0 |
| | `43394..43435` | `43563` | 6 | - | 102 | 15 | **0** | **0** | 0 |
| `EVENTA20` B | `42677..42687` | `44222` | 1 | - | 1,204 | 156 | 17 | 1 (site A) | 0 |
| | `42692..42718` | `43917` | 3 | - | 1,173 | 154 | 16 | 1 (site A) | 0 |
| | `43689..43700` | `43912` | 1 | - | 191 | 29 | **0** | **0** | 0 |

`EVENTC10`, `EVENTA10` and `EVENTA02` each have one guard and nothing between
it and the dispatch: no branch, no dispatch, no edge entering the gap from
outside. Their guards are independent of each other - C10's false edge
lands at `13865`, A10's at `22003` and A02's at `23122`, none of them another
intro's guard.

`EVENTA20` is one tree with two leaves. `42677..42687` tests the caller's
own routine-40 result, `state_u16[21] == 1`, and `42692..42718` the calendar;
then `42723..42734` splits on `global_u8[1127]`: clear, and the code runs a
thirteen-arm ladder on `global_u8[1035]` (`== 0`, `== 1`, `== 3` .. `== 13`,
branches `42739..43146`, each selecting a prelude) before a six-flag guard
`43394..43435` and site A's dispatch at `43537`; set, and the false edge
lands on `43689..43700`, which tests `[1127] == 1` again and dispatches site
B at `43891`. Site B's gap, measured from the shared root at `42677`,
contains site A's dispatch record, which is why the table shows one
dispatch in it; from its own last guard at `43700` the gap is clean. The
routes will take each leaf's own last guard as origin with the shared
conjuncts seeded, as the 44C ladder was measured, and treat the `[1035]`
ladder as prelude selection to be swept, not as eligibility.

## The guards, read as scene conditions

Weekday is `state_u16[4]`, the date `state_u16[7]` as MMDD, the clock
`state_u16[19]` as HHMM, `banked_u16[201]` an affection word, and
`state_u16[21]` the last routine-40 result. Flags are `global_u8`.

| Intro | Calendar window | Other | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTC10` | weekday `0`, `8/25`, `18:00 < clock < 20:01` | - | `[396]`, `[1728]` | `[160]`, `[164]`, `[167]`, `[230]`, `[1694]`, `[1729]`, `[1755]`, `[1768]` |
| `EVENTA10` | weekday `0`, `8/25`, `18:00 < clock < 22:00` | `banked_u16[242] != 17` | `[1187]` | `[1186]` |
| `EVENTA02` | weekday `0`, `4/00 < date < 6/16`, `8:00 < clock < 11:01` | `banked_u16[242] != 17`, `30 < banked_u16[201] < 61` | - | `[110]`, `[112]`, `[114]`, `[117]`, `[994]`, `[1034]`, `[1059]`, `[1111]` |
| `EVENTA20` A | `13/01`, `8:00 < clock < 17:01` | `state_u16[21] == 1` | - | `[1127]`, `[112]`, `[114]`, `[117]`, `[994]`, `[1034]`, `[1059]` |
| `EVENTA20` B | `13/01`, `8:00 < clock < 17:01` | `state_u16[21] == 1` | `[1127]` | - |

Read, not yet measured. `EVENTC10` and `EVENTA10` share one evening - weekday
`0`, `8/25`, from `18:01` - and since C10 is a nested call whose caller
resumes, the same visit can in principle reach A10's guard after C10
returns; whether it does is a question for the C10 route's resume. C10's
clear flags `[160]`, `[164]`, `[167]` and `[1694]` are four of 44M
`EVENTC18`'s, so C10 sits in the C family before or beside C18. `EVENTA02`'s
eight clear flags contain the six `EVENTA20` site A requires clear, so A02
precedes A20's first entrance in the A family, with the affection word
`banked_u16[201]` between `30` and `61` as A02's bar. `EVENTA20`'s two
entrances are told apart by `global_u8[1127]` - the first-visit / later-visit
idiom FLOOR5's E15 and 44C's M10 also use - on the month-13 date `13/01`
under the owner's reading, behind the caller's own selection answered `1`.
`banked_u16[242]` is the word 44M's and 18M's resumes write their own map
numbers into; A10 and A02 require it not to read `17`, and what that means
for a visit is not established.

## EVENTC10: an August evening the caller closes with two flags

Measured 2026-09-11. `17M.MES:13051..13142` (false `13865`) requires
weekday `0`, `8/25`, `18:00 < clock < 20:01`, `global_u8[396]` and
`[1728]` set and `[160]`, `[164]`, `[167]`, `[230]`, `[1694]`, `[1729]`,
`[1755]`, `[1768]` clear; eighteen witnesses pin `824/825/826`,
`1800/1801` and `2000/2001` and flip every flag once. The prefix is 9
messages through 49 records with no branch. `EVENTC10.MES` runs 15
messages from `0` and returns at `2143..2144`, writing `banked_u16[1] = 7`,
`global_u8[234] = 1` - a run counter, `2` on a direct second pass -
`[3576]` and `[5189]`, and none of the guard's cells. Two of its inputs are
dead: `global_u8[4000]` is cleared by routine 28 at `251` before the branch
at `495` reads it, and `state_u16[8]` is overwritten at `261..266` before
the ladder at `266` reads it - M17's shape again. `global_u8[3006] = 1`
flips `646` (`[3005]` to 15) and `global_u8[2847] = 1` flips `2000`.

The caller resumes at `13457`, emits 12 messages across four dialogue
boundaries, writes `global_u8[1768] = 1` at `13838..13844` and
`global_u8[1755] = 1` at `13849..13855` - conjuncts 14 and 13 of its own
guard - and reaches the caller's routine-40 selection `42662` (resume
`42667`), two definitions whose consumer is the `state_u16[21]` chain at
`42677`: result `1` falls to `42692`, the calendar guard of the A20 tree,
result `2` to `44222`. Unlike the dormitory's selection the definitions
are in the stored form the contract builder supports, so both results are
supplied and followed, as 18M's M16 was. Answered `1`, the caller writes
`banked_u16[242] = 17`, `banked_u16[201] = 1`, `global_u8[116]`, `[264]`,
`[286]`, `[1043]`, `[1157]` and `[3005]`, dispatches `A_PIC.MES`,
`A_INTRO.MES` and `A_OUTRO.MES` in turn and hands the root to `MACHI.MES`
at `52741..52754` - 19 messages of its own, 30 with the three scripts' -
having entered the A20 tree at `42677` and left it at `42692`, because
the date is `8/25`, not `13/01`. Answered `2`, it writes
`banked_u16[242] = 17` and `[286]` alone and hands off to `MACHI.MES` at
`44351..44364` after 15 messages. Completion is caller-owned through both
flags, C18's shape doubled; the callee's own gate at `224` on `[1768]`
sends the completed reentry to `2174..2175` with **0 messages** under
either result, while a direct second pass replays all 15. Segmented and
unbroken runs agree under both results.

Two readings follow. `banked_u16[242]` is the map word: 44M's resumes
write `44`, 18M's `18`, and this one `17`, so A10's and A02's
`banked_u16[242] != 17` asks that the visit not already be on this map.
And the A10 question is answered no: A10's guard `21618` is never
executed by this resume - at baseline, with `global_u8[1187]` armed, or
under either result - so the shared `8/25` evening does not chain C10
into A10 inside one visit.

Declared as `17m_c10_v5.json` with the caller's contract and the three A
scripts and `MACHI.MES` among the members, two routes over the one guard:
`17m-c10-result1` with six variants and `17m-c10-result2` with three, each
variant naming its result, no post-guard declaration since both resumes
close the guard. Audit accepted; `original event analysis 17M C10` passes
447 checks; a wrong resume message count on the first route and the
second route's handoff shifted one byte are rejected.

## EVENTA10: the same evening as a root handoff, closed by the callee

Measured 2026-09-11. `17M.MES:21618..21669` (false `22003`) requires
weekday `0`, `8/25`, `18:00 < clock < 22:00`, `global_u8[1187]` set,
`[1186]` clear and `banked_u16[242] != 17`; twelve witnesses pin
`824/825/826`, `1800/1801` and `2159/2200`, reject the map word at `17`
and accept it at `44`. The prefix is 9 messages through 48 records with
no branch, and the dispatch at `21977..21993` is a root handoff: the
caller's walk ends there and `EVENTA10.MES` replaces it. The callee runs
41 messages from `0` to its own handoff `3976..3989 -> MACHI.MES`,
writing `banked_u16[1] = 7`, `global_u8[286]`, `[3437]`, `[5037]` and, at
`3931..3937`, `global_u8[1186] = 1` - conjunct 7 of the guard that
admitted it. Completion is callee-owned, I24's shape: the guard rejects
on the post-replacement state, and the callee's own gate at `231` on
`[1186]` sends a direct reentry to the return `4019..4020` with **0
messages**. Segmented and unbroken runs agree (50 messages). Two inputs
are dead as in C10 and M17 - `state_u16[8]` is overwritten at `247..252`
and `global_u8[4000]` cleared by a library routine before `502` -
and four arms move: `global_u8[3006]` at `653` (`[3005]` to 15), `[2847]`
at `3316`, `[1185]` at `3642` (three more messages, 44) and
`banked_u16[203] > 30` at `3942` (`[138]` set), the last two just before
the handoff; all eleven dispatch-reaching variants end at the same record. Neither the prefix nor
the callee writes `banked_u16[242]`.

Declared as `17m_a10_v6.json`, one root-replacement route with no
contract, `post_guard_expected` 0, eleven variants. Audit accepted;
`original event analysis 17M A10` passes 234 checks; a wrong reentry
message count and the handoff shifted one byte are rejected.

## EVENTA02: a spring morning with three answers that only move the affection word

Measured 2026-09-12. `17M.MES:22684..22794` (false `23122`) requires
weekday `0`, `4/01 <= date <= 6/15`, `8:01 <= clock <= 11:00`, the
affection word `banked_u16[201]` in `31..60`, the map word `banked_u16[242]`
not `17`, and `global_u8[110]`, `[112]`, `[114]`, `[117]`, `[994]`,
`[1034]`, `[1059]`, `[1111]` clear; twenty-three witnesses pin every
edge and flip every flag. The prefix is 9 messages through 49 records with
no branch, and the dispatch at `23091..23107` is a root handoff.
`EVENTA02.MES` asks its own routine-40 question at `2117` (resume `2122`,
three definitions, consumer the `state_u16[21]` chain at `2127`), in the
stored form the contract builder supports, so all three results are
supplied. Every answer runs to the same handoff `5248..5261 -> MACHI.MES`
through the same clock ladder (`801..859` and `900..1100` take different
arms at `5117`) and writes the same cells - `banked_u16[1] = 7`,
`global_u8[244]`, `[286]`, `[3201]`, `[3431]`, `[5030]`, its own done flag
`[1111] = 1` at `5083..5089` and the map word `banked_u16[242] = 17` at
`5212..5221` - and they differ only in length and in what they do to the
affection word: result `1` runs 48 messages and adds 2 (`45 -> 47` at
`3110..3125`), result `2` 44 messages and takes 1 (`3989..4004`), result
`3` 42 messages and takes 2 (`4582..4597`). The callee's `> 1` and `> 2`
gates on the word inside results 2 and 3 cannot fail under the guard's
window. Completion is callee-owned twice over - the done flag and the map
word both close the guard - and the done-gate at `219` sends a direct
reentry to `5197` and out through the same handoff with **0 messages**.
Segmented and unbroken runs agree under every result (57 / 53 / 51
messages). `state_u16[8]` and `global_u8[4000]` are dead inputs as in the
other three callees; `global_u8[3006]` flips `641`.

Declared as `17m_a02_v6.json` with the callee's contract, three
root-replacement routes over the one guard - `17m-a02-result1` with 12
variants, `-result2` and `-result3` with 5 and 5 - each variant
naming its result, `post_guard_expected` 0, the reentry outcome the handoff
record itself. Audit accepted; `original event analysis 17M A02` passes
602 checks; a wrong callee message count on result 2 and result 3's
handoff shifted one byte are rejected.

## EVENTA20: one event, two visits, two questions, and a tree above both

Measured 2026-09-12. The tree above the two sites is swept from its root
`42677` and seeded below it. With the caller's selection answered `1`
(`state_u16[21] = 1` - the result the C10 routes follow at `42662`), the
date `13/01` and the clock in `8:01..17:00`, `global_u8[1127]` clear
leads through the thirteen-arm `[1035]` ladder to the six-flag guard
`43394..43435` and site A's handoff at `43537` (12 to 14 caller
messages; every value `0..13` reaches it, `2` by falling through all
thirteen arms), and `[1127]` set leads to `43689..43700` and site B's
handoff at `43891` (6 messages, the six flags ignored). The caller writes
neither `[1127]` nor `[1035]` on the way; result `2` at the root falls to
`44222` and out through the `44351` handoff the C10 routes end at, and a
rejected site-A flag falls to `43563` and on into the rest of the script.
Each site's route takes its own last guard as origin with the tree's
conjuncts seeded, the 44C ladder's convention.

`EVENTA20.MES` is two bodies behind its own `[1127]` test at `247`. The
first visit (site A) dispatches `A_INTRO.MES` at `755` (4 messages), asks
its question at `2001` (resume `2006`, two results, consumer the
`state_u16[21]` chain at `2016`), and hands the root to `MACHI.MES`:
result `1` after 33 messages at `3451..3464`, result `2` after 22 at
`7811..7824`, both writing `banked_u16[1] = 7`, `global_u8[264]`,
`[286]`, `[998]`, `[1157]`, `[3206]`, `[3443]`, `[5044]` and, at `3326`
or `7686`, `global_u8[1127] = 1` - the tree's own split flag, so the next
visit arrives at site B. The second visit (site B) asks at `9087` and
hands off after 30 messages at `10408..10421` (result `1`) or 19 at
`14536..14549` (result `2`), writing `banked_u16[1]`, `[286]`, `[3443]`,
`[5044]` and rewriting `[1127] = 1`. Neither site's own guard closes: the
six flags and `[1127] == 1` still hold after the callee, so both declare
`post_guard_expected` 1; site A's completion is the tree's `[1127]`, site
B has none measured - the second visit repeats. Two arms are measured and
not declared: `state_u16[12] = 1` sends result `1` through the `[350]`
ladder and the `banked_u16[201] > 100` test to `6924..6937` (site A) or
`13728..13741` (site B), and `global_u8[1130] = 1` sends the second visit
to `17937..17950` through the `[1131]` ladder; `[350]` is rewritten to
`0` at `118` on both visits, so seeding it is dead, as are `state_u16[8]`
and `global_u8[4000]`. The clock ladders at `3348`, `6821`, `7708`
select an epilogue by `600/900/1600/1800` without changing the terminal,
and from `16:00` the first visit leaves `global_u8[3206]` at `2` instead of
`1`; `global_u8[3006]` flips `669` / `8261`. A direct reentry after site A
enters the second body and needs the `9087` question too - answered `1`
it lands at `10408..10421` after 30 messages from every site-A seed -
and after site B repeats the same body. Segmented and unbroken runs agree
at both sites under both results.

Declared as two groups: `17m_a20a_v6.json` with `A_INTRO.MES` among the
members, both contracts and routes `17m-a20a-result1` (14 variants)
and `-result2` (14), the reentry the second visit's result-1 body;
`17m_a20b_v6.json` with the `9087` contract and routes `17m-a20b-result1`
(16) and `-result2` (17), the reentry the same body again. Audits
accepted; `original event analysis 17M A20A` passes 579 checks and
`A20B` 515; a wrong reentry message count on A and B's second handoff
shifted one byte are rejected.

Every 17M intro is measured and declared: five sites, four targets, five
groups, nine routes, no contract change. The classification binds
`EVENTA20`, 67 entries at 49/47/73.

## Not measured here

What schedules `MACHI.MES:25259` into `17M.MES`; what the caller's routine-40
selection at `42662` offers as native input (its two results are supplied
explicitly by the C10 routes); what the thirteen `[1035]` arms select
beyond a prelude of one or two messages; the A20 arms behind
`state_u16[12]` and `global_u8[1130]`; and `MACHI.MES` past every handoff.

## EVENTA20's `global_u8[1131]` chain is an address-table entry (measured 2026-09-23, EP-11)

The visit-ladder census found three equality tests on `global_u8[1131]` from
`14564` in `EVENTA20.MES`. They are not reached from the callee's start:
the menu at `0x237F` has two answers and each runs straight to a declared
`MACHI.MES` handoff (answer 1 at `10408`, answer 2 at `14536`, the
`17m-a20b` results), and neither writes or tests `[1131]`. The chain lies
after `14364`, an entry of `EVENTA20.MES`'s own address table, so it is
reached only by a caller that enters at that coordinate. That is the
address-entry family the owner closed without exposure on 2026-09-17, so the
chain is recorded and not declared. Not established: which caller, if any,
enters `EVENTA20.MES` at `14364`.
