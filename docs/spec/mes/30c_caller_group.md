# 30C caller group

Inventoried on 2026-09-12 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`30C.MES` is named by no literal dispatch record: its only naming is a
command-`0x0E` record in `FLOOR2.MES`'s opaque tail (`FLOOR2.MES:3567..3578`),
so the classification carries it as a tail-named root. It is a caller
with three unresolved EVENT intro sites for one target, `EVENTG01`, every
one a root handoff into a callee that hands the root to `FLOOR2.MES` - the
G family's art room on the second floor. The three sites are one ladder
on the G flags: the first visit, the return visit, and the visit after
the callee has marked itself. The instrument is the one that opened the
earlier groups; run first on `01M.MES`, it reproduces the 44C-era
control exactly before it is run here.

## The caller

| Property | `30C.MES` |
|---|---|
| framing-opaque bytes | **0 of 24,989** |
| instructions / branches / calls | 3,345 / 159 / 370 |
| address-table entries | 144 |
| EVENT intro sites | 3, for one target |
| intros with a typed guard candidate | **all 3** |
| dispatch form | **all three root handoffs** |
| framing-opaque bytes in the callee | 0 |

`EVENTG01.MES` has no caller but `30C.MES`. It is one body with one door
(`8042..8056 -> FLOOR2.MES`) and no gate of its own at the top: it opens
on a two-window date test, dispatches `G_PIC.MES`, splits on `[1467]`,
`[1469]`, `[1468]` and then on `[1462]` (first visit against later ones),
walks the G word `banked_u16[204]` through five bands twice over (`[1464]`
clear and set), dispatches one of `G_TALK30..90.MES` or `G_TALK00.MES` by
the same bands, `G_PROMIS.MES` when `[1381]` is set, walks the bands a
third time, and at its door writes `[1463] = 0`, `[1462] = 1`, `[1464] =
1`, the stamp `banked_u16[242] = 30` and `[286]`. Ten scripts are its
static dependencies. No callee dispatches `TRAIN.MES`.

## The three intros

| Intro | Site | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---:|---:|
| `EVENTG01` (site A) | `3666..3682` | `2963..2992` | 8,072 | 34 | 84 |
| `EVENTG01` (site B) | `5149..5165` | `4950..4991` | 8,072 | 34 | 84 |
| `EVENTG01` (site C) | `5404..5420` | `5175..5216` | 8,072 | 34 | 84 |

## Three flag guards, one ladder

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---|---:|:-:|---:|---:|---:|---:|
| site A | `2963..2992` | `3692` | 4 | - | 674 | 108 | **0** | **0** | 0 |
| site B | `4950..4991` | `5175` | 6 | - | 158 | 31 | **0** | **0** | 0 |
| site C | `5175..5216` | `5430` | 6 | - | 188 | 31 | **0** | **0** | 0 |

Site A's gap writes `[1463] = 1` and `[1459] = 1` - the flag its own guard
wants clear and the flag sites B and C want set - before the handoff;
sites B's and C's gaps write `[1463] = 1` only. Site A's false edge lands
on a Saturday-after-`15:00` block at `3692` that writes `[1461]` (the flag
B and C want clear), and B's false edge is C's guard. After every site a
`continuation_transfer` leads to the caller's epilogue at `24934`.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`6` Saturday), the clock `state_u16[19]` as
HHMM, and `banked_u16[204]` the G family's affection word. Flags are
`global_u8`.

| Intro | Calendar window | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|
| site A | Saturday, before `15:01` | `[1391]` | `[1459]` |
| site B | Saturday, before `15:01` | `[1391]`, `[1459]` | `[1461]`, `[1464]` |
| site C | Saturday, before `15:01` | `[1391]`, `[1459]`, `[1464]` | `[1461]` |

Read, not yet measured. All three are Saturday visits before three
o'clock with `[1391]` set. Site A is the first: its guard wants `[1459]`
clear and the caller sets `[1459]` in the gap, so A admits once. Site B
wants `[1459]` set, `[1464]` clear and `[1461]` clear; site C the same
with `[1464]` set - and `[1464]` is what the callee writes at its door,
so B is the first return and C every return after, unless the
Saturday-afternoon block sets `[1461]`. Inside, the callee reads no
calendar cell but the date windows (`4/01..6/15` or `9/16..15/10`) at its
opening, and everything else follows the G word's bands and the flags
`[1462]`, `[1464]`, `[1467]`, `[1469]`, `[1468]`, `[1381]`.

## EVENTG01: three Saturday visits, a talk script by band, and the questions inside it

Measured 2026-09-12 and 2026-09-13. The three guards are pinned by
eight, ten and ten witnesses: all want a Saturday before `15:01` with
`[1391]` set; site A (`2963..2992`, false `3692`) wants `[1459]` clear and
the caller writes `[1459] = 1` and `[1463] = 1` in its gap before the
handoff at `3666..3682`, so the guard closes by the caller's own hand;
site B (`4950..4991`, false `5175`) wants `[1459]` set and `[1461]`,
`[1464]` clear; site C (`5175..5216`, false `5430`) the same with `[1464]`
set. Every rejection walks to the caller's own handoff at `24959..24973
-> FLOOR2.MES`, except that a state which one site refuses often lands
on the next site's guard, which admits it. `EVENTG01.MES` has no gate of
its own. On a date inside its two windows it runs one opening, outside
them another through `G_PIC.MES`; it then takes the first-visit arm
(`[1462]` clear, setting it) or walks the G word `banked_u16[204]`
through five bands - once with `[1464]` clear, once with it set - and
dispatches a talk script by the same bands: `G_TALK30.MES` below `31`,
`G_TALK40` to `40`, `G_TALK50` to `50`, `G_TALK60` to `60`, `G_TALK70` to
`70`, `G_TALK80` to `80`, `G_TALK90` to `90`, `G_TALK00` above. Each talk
script asks its own two-answer question - at `1370` in the first four,
at `1358` in the last four - and the first answer, the one the
normal-conversation spec calls the exit, returns to the callee, while
the second loops in the conversation menu past the probe's segment cap.
With that answer supplied the callee reaches its one door `8042..8056 ->
FLOOR2.MES` after 12 messages from the first-visit arm and 9 from the
band ladders (up to 32 when the higher bands' talk scripts speak),
writing at its door `[1463] = 0`, `[1462] = 1`, `[1464] = 1`, `[2660]`, the
stamp `banked_u16[242] = 30` and `[286]`; the higher bands' scripts write
cells of their own (`banked_u16[244]`, `[245]`, `[246]`, `global_u8[534]`,
`[1375]`, `[1377]`). Site A's guard rejects afterwards by the caller's
`[1459]`; site B's by the callee's `[1464]`; site C's stays open - the
first measured guard that does - and every direct reentry reaches the
door again, sometimes through the next band's talk script, since the
higher bands' scripts move the G word themselves; every row therefore
carries all eight talk answers. Segmented and unbroken
runs agree at every site. `G_PROMIS.MES`, dispatched when `[1381]` is set,
asks a question whose stored definitions skip identifier `8`, which the
contract tool rejects, so that row is measured to its boundary and not
declared. `state_u16[8]` is rewritten at `305` before it is read and
`global_u8[4000]`, which the callee writes itself at `584`, reads `0` after
the shared routine that follows.

Declared as `30c_g01a_v6.json`, `30c_g01b_v6.json` and `30c_g01c_v6.json`,
each with the eight talk scripts' contracts and all ten dependencies
among the members, one root-replacement route per site with 19,
20 and 19 variants each naming all eight talk questions with
the exit answer - the audit wants every declared contract selected once
- of which only the one its band selects is met, `post_guard_expected`
0, 0 and 1, the reentry the door again.
Audits accepted; `original event analysis 30C G01A` passes 672
checks, `30C G01B` 689 and `30C G01C` 619; a wrong callee message
count and the call record shifted one byte are rejected.

Every 30C intro is measured and declared: three sites, one target, three
groups, three routes, no contract change. Read together, the art room is
one thread: 35M's G02 sets `[1391]` on its first visit, site A admits once
and the caller marks `[1459]`, site B admits until the callee marks
`[1464]`, and site C admits every Saturday after.

## Not measured here

What schedules `FLOOR2.MES:3567` into `30C.MES`; what sets `[1391]` and
the opening flags and what moves the G word outside this callee; the
`G_TALK*.MES` bodies past their exit answer and `G_PROMIS.MES` past its
question, whose stored definitions the contract tool does not read; and
`FLOOR2.MES` past the door.

## EVENTG01's two passes (measured 2026-09-23, EP-11)

`EVENTG01.MES` tests `global_u8[1462]` at `1618` (`== 0`, body `1629..2072`,
6 messages, writes the cell `1` at `2056`, then jumps past the next test) and
at `2072` (`== 1`, body `2083..5766`, 4 messages, no write, no dispatch). It
is an if/else-if on the value the callee is entered with, not a ladder one
call climbs. The committed routes already cover both passes: `30c-g01a`'s
baseline enters with the cell `0`, `30c-g01b` and `30c-g01c` with `1`.
Evidence: Python handoff and replays through the shared call frame from each
route's own baseline (`analysis/_undoc/ep11_g01_g02_a20_report.md`,
untracked).
