# 27C_EV caller group

Inventoried on 2026-09-13 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`27C_EV.MES` is the event script of the 27C dormitory floor, named by
`43C_ASA.MES` twice, by typed command-`0x0E` handoffs at
`15592..15606` and `38063..38077`. The earlier `16842` and `39313`
were entry-file offsets of the target name, not code-relative command starts:
subtract the 1,248-byte container header and the two bytes before the name.
Both complete records are framed by Python instruction-v45; the earlier
claim of missing decoder coverage is withdrawn. Its two unresolved EVENT intro sites are both
nested calls (command `0x0F`) into callees that return and ask nothing:
`EVENTM01`, behind a two-flag guard on any day, and `EVENTM14`, behind a
guard that wants `4/22` and M01's own done flag. After either return the
caller closes the callee's gate itself - `[2405]` after M01, `[2406]`
after M14 - and walks on into the floor's day: a chain of date-specific
blocks, a wait loop until `12:30`, picture and talk scripts, and an
epilogue at `48649` that rewrites the clock and hands the root off by
date.

## The caller

| Property | `27C_EV.MES` |
|---|---|
| framing-opaque bytes | **0 of 83,180** (the epilogue's last 160 bytes, `83020..83180`, are an opaque tail where the typed decode fails closed) |
| instructions / branches / calls | 12,728 / 344 / 1,105 |
| address-table entries | 742 |
| EVENT intro sites | 2, for two targets |
| intros with a typed guard candidate | **both** |
| dispatch form | both nested calls whose callees return |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTM01.MES` is
one body behind its own `global_u8[2405]` gate at `244`, writing
`[5151]`, `[5152]`, `[3552]`, `[403]` and `[404]` on the way to its
return, and never writes `[2405]`. `EVENTM14.MES` is one body behind
`[2406]` at `244`, calling six picture scripts and writing `[5153]`,
and never writes `[2406]`. Neither asks a question.

## The two intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|
| `EVENTM01` | `5902..5918` | nested call | `2090..2107` | 5,728 | 8 | 49 |
| `EVENTM14` | `12855..12871` | nested call | `12821..12845` | 13,464 | 20 | 148 |

## Two guards, both closed by the caller after the return

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---|---|---:|:-:|---:|---:|---:|
| `EVENTM01` | `2090..2107` | `5939` | 2 | - | 3,795 | 563 | 1 | 4 (`N_PIC`, `P_PIC`, `F_PIC`, `E_PIC`) | 0 |
| `EVENTM14` | `12821..12845` | `12919` | 3 | - | 10 | 2 | **0** | **0** | 1 |

M01's gap calls four picture scripts and branches once on the
`state_u16[5]` arm the caller recomputes from `banked_u16[2]`; after the
return the caller writes `[2405] = 1` at `5928` and falls into the
floor's guard chain at `5939`. M14's guard is reached only from the
false target of the `4/17` block's branch at `11910` - the record before
it transfers away - and its ten-byte gap holds nothing; after the return
the caller writes `[150] = 0`, `[230] = 0` and `[2406] = 1` at
`12881..12903` and transfers to the epilogue at `48649`.

## The guards, read as scene conditions

The date is `state_u16[7]` as MMDD. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTM01` | any | - | `[2404]` | `[2405]` |
| `EVENTM14` | `4/22` | - | `[2405]` | `[2406]` |

Read, not yet measured. M01 is the M family's floor event that runs once
after `[2404]` is set, its done flag `[2405]` closed by the caller; M14
is the April 22 follow-up that needs M01 done, its `[2406]` closed the
same way. Neither reads an affection word or the clock.

## EVENTM01: the floor's first M-family event on any day, four pictures on the way in and the whole day on the way out

Measured 2026-09-13. `27C_EV.MES:2090..2107` (false `5939`) wants
`[2404]` set and `[2405]` clear - no calendar, no affection word; five
witnesses flip both flags, every rejection walking the floor's day to
the same `FLOOR5.MES` handoff the accepted route ends at. The prefix
calls `N_PIC`, `P_PIC`, `F_PIC` and `E_PIC` and runs 78 messages to the
nested call at `5902..5918`; its one branch, the `state_u16[5]` arm at
`5850`, cannot be witnessed from a seed because the caller clears bit
128 of `banked_u16[2]` at `5421` before recomputing it. `EVENTM01.MES`
asks nothing: it counts `[244]` at `118`, writes `[5151]`, `[5152]`,
`[3552]`, `[403]` and `[404]`, and returns at `5721..5722` after 61
messages, never touching its own gate. The caller closes `[2405]` at
`5928` and walks on: the date blocks at `5939`, `9721`, `10087` and
`10598` all closed on this date, the 12:30 wait at `11051`, the 4/22,
4/10 and 4/17 blocks, `N_PIC` / `N_TALK` / `27C_SUB` behind the `[244]`
guard at `37645` that the callee's own count opened, the epilogue at
`48649` rewriting the clock - five passes of the day loop advancing the
calendar - and after 22 messages hands the root to `FLOOR5.MES` at
`83150..83164`, a record inside the caller's opaque tail from `83020`
where the typed decode fails closed, bound as a runtime observation the
way FLOOR5's v5 profiles bind theirs - a `natural_handoff` resume. The guard rejects on the
resumed state by `[2405]`, and a completed reentry returns through the
done-gate at `244` to `5727..5728` with **0 messages** - after counting
`[244]` once more at `118`. Segmented and unbroken runs agree. With the
date at 4/10 the resume also runs the I-family block (57 messages), and
at 4/22 or 4/17 it reaches M14's guard and stops before its call; those
three dates are measured and not declared. `state_u16[8]` is
rewritten at `430` before it is read and `global_u8[4000]` reads `0` at
the callee's entry whatever is seeded; `[3006]` and `[2847]` flip
presentation arms.

Declared as `27c_ev_m01_v5.json` with no contract, the four picture
scripts, `N_TALK`, `27C_SUB`, `I_PIC` and `I_TALK` among the members
(`FLOOR5` only as the handoff's target), one caller-continuation route `27c-ev-m01` with 7
variants on the `natural_handoff` resume to `FLOOR5`,
`post_guard_expected` 0, the reentry the done-gate return with the
counter's second step; the wait loop's random `[2347]` is not declared. Audit accepted; `original event
analysis 27C_EV M01` passes 371 checks; a wrong resume message count
and the call record shifted one byte are rejected.

## EVENTM14: April 22 after M01, six pictures inside, the day on the way out

Measured 2026-09-13. `27C_EV.MES:12821..12845` (false `12919`) wants
`4/22` with `[2405]` - M01's done flag - set and `[2406]` clear; six
witnesses pin the date and flip both flags, the rejections walking to
`FLOOR5.MES` or, on 4/23, to `43C_ASA.MES` by the epilogue's date table.
The guard is entered only from the false target of the 4/17 block's
branch at `11910`; its ten-byte gap runs 0 messages to the nested call
at `12855..12871`. `EVENTM14.MES` asks nothing: it counts `[244]` at
`118`, calls `M_PIC`, `O_PIC`, `N_PIC`, `E_PIC`, `P_PIC` and `L_PIC`,
writes `[5153]` and `[3553]`, and returns at `13457..13458` after 194
messages, never touching its own gate. The caller closes `[2406]` at
`12903` together with `[150]` and `[230]`, transfers to the epilogue at
`48649`, and walks the floor's day - the clock rewritten to 15:30 and
08:00, the 12:30 wait, the character blocks, `N_PIC` / `N_TALK` /
`27C_SUB` behind the `[244]` guard at `72247` that the callee's own
count opened and that clears the count again - six passes advancing the
calendar to the next Saturday, and after 22 messages hands the root to
`FLOOR5.MES` at `83150..83164` inside the caller's opaque tail, the same
`natural_handoff` M01's resume ends at. The guard rejects on the resumed state by the date and by
`[2406]`, and a completed reentry returns through the done-gate at
`244` to `13463..13464` with **0 messages** - after counting `[244]` once
more at `118`. Segmented and unbroken runs agree. `state_u16[8]` is rewritten at `460` and `13020` before it is
read and `global_u8[4000]` reads `0` at the callee's entry whatever is
seeded; the callee clears `[10..20]` on entry; `[3006]` and `[2847]`
flip presentation arms.

Declared as `27c_ev_m14_v5.json` with no contract, the six picture
scripts, every talk script the day can reach, `N_TALK` and `27C_SUB`
among the members (`FLOOR5` only as the handoff's target), one
caller-continuation route `27c-ev-m14` with 7 variants on the
`natural_handoff` resume to `FLOOR5`, `post_guard_expected` 0, the
reentry the done-gate return with the counter's second step; the wait
loop's random `[2347]` is not declared. Audit accepted; `original event analysis 27C_EV M14` passes
414 checks; a wrong resume message count and the call record shifted
one byte are rejected.

Every 27C_EV intro is measured and declared: two sites, two targets,
two groups, two routes, no contract change. Read together, the
dormitory floor's two M-family events are bookends of the same day: the
caller opens M01 on any day `[2404]` allows and M14 on April 22 once M01
is done, closes each gate itself, and in both cases the floor's day
carries the player on to the fifth floor - the callee's own visit count
`[244]` being the one thing that changes what the day shows.

## Not measured here

What schedules `43C_ASA.MES:15592` or `38063` into `27C_EV.MES`;
what sets `[2404]`; the wait loop's random
`[2347]`; and the picture and talk scripts' native presentation and
`FLOOR5.MES` past the handoff.
