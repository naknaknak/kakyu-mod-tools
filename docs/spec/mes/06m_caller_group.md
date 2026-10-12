# 06M caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`06M.MES` is a map script with one unresolved EVENT intro site,
`EVENTK06`: a root handoff (command `0x0E`) behind a typed guard and the
caller's own two-answer question, whose callee asks its own three-answer
question and leaves by one door to the town. Qualified with the route
toolchain; the first group declaring both the caller's and the callee's
contracts.

## The caller and the intro

| Property | `06M.MES` |
|---|---|
| framing-opaque bytes | **0 of 58,224** |
| instructions / branches / address entries | 7,458 / 474 / 237 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTK06` | `6012..6028` | root handoff | `546..601` | `9411` | 7 | 5,411 B / 276 records / 13 branches / 4 dispatches / the question at `3905` | 21,814 | 36 | 243 |

The date is `state_u16[7]` as MMDD, the clock `state_u16[19]` as HHMM,
`banked_u16[268]` a stored date word, `banked_u16[207]`, `[208]` and
`[209]` affection words (`[209]` the L family's); flags are `global_u8`.
The guard wants the date to be the day after the stored word `[268]`, past
`9/15`, the clock from `9:31` to `10:59`, and `[2300]`, `[2313]`, `[2314]`
clear. What writes `[268]` is not established; the seed stores the
previous day and a same-day witness rejects. The gap is long: a clock
ladder (`772` past `10:00`, `1086` at `10:00`, `1363` before it) moves
`[207]` and `[208]` down two behind `> 2` gates at `976` and `1031`, up
one, or up two; `H_PIC.MES` and `K_PIC.MES` are called twice each (`1770`,
`2116`, `4255`, `4775`) around `[176]` and `[186]` writes and `[4000] = 1`
at `751`, `2606`, `5494`; the caller asks its own two-answer question at
`3905`, and answer `1` - `state_u16[21] == 1` at `3920`, false `6038` -
clears `[170]`, `[180]`, `[2310]`, `[2289]`, `[2290]`, closes `[2313]` at
`5957` - a clear conjunct of its own guard, the 05M J07 shape - and writes
`[2284]` and `[2288]` before the handoff. Answer `2` is not measured.

## EVENTK06: the day after a stored date, two questions and one door

Ten witnesses pin the stored-date relation, both clock edges, the date
floor and every flag; a `[2300]` rejection stops at the map's own question
at `11889` and every other at its question at `57534`. The prefix runs 67
messages - 40 before the question - to the handoff at `6012..6028`.
`EVENTK06.MES` counts `[198]` at `139` when the L word is in `41..100`,
moves `[207]` and `[208]` up three at `225` and `245` at its head, writes
`[5251]`, `[5222]`, `[5223]`, `[5252]`, `[5253]`, `[3606]`, `[3633]` on the
way, and asks its question at `11420` (three definitions `11184`, `11269`,
`11344`; 145 messages before it): answer `1` moves `[208]` down two behind
a `> 2` gate at `11988` (false `12029`, which zeroes it), answer `2` up two
at `13326`, answer `3` writes `[2323]` at `15115` and `[5254]`; every
answer then resets `[2836]`, `[3000]`, `[2841]`, `[4000]` at `16318..17811`,
calls `K_PIC.MES` at `18583`, stamps `banked_u16[242] = 6` at `21770` and
writes `[286]`, leaving by `21795..21808 -> MACHI.MES` after 242, 256 or
283 messages. The guard rejects every post-replacement state by the
caller's `[2313]`; the callee has no done-gate of its own, so a direct
reentry replays the whole body to the same door with the same count,
counting `[198]` and `[244]` again and moving `[207]` and `[208]` once
more (the clock-before-ten, seeded-count and word rows override it).
Segmented and unbroken runs agree under every answer. `state_u16[8]` is
rewritten at `312` and `21117` before each ladder and `global_u8[4000]`
reads `0` at the callee's entry whatever is seeded; `[2847]` and `[3006]`
flip presentation arms.

Declared as `06m_k06_v6.json` with both contracts (the caller's `3905`,
results `1..2`, answer `1` selected; the callee's `11420`, results `1..3`),
`H_PIC`, `K_PIC` and `MACHI` among the members, three root-replacement
routes by answer sharing the one door with 16 variants in all, each
naming its answers, `post_guard_expected` 0, the reentry the door with
the replay's count. Audit accepted; `original event analysis 06M K06`
passes 643 checks; a wrong callee message count and the door shifted one
byte are rejected.

## Not measured here

What hands the root to `06M.MES` and what writes the stored date `[268]`;
what moves the three words outside this route; the caller's answer `2`;
what either question offers as native input (their results are supplied
explicitly); `H_PIC.MES` and `K_PIC.MES` native presentation; and
`MACHI.MES` past the door.
