# 33C caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`33C.MES` is a floor script with one unresolved EVENT intro site,
`EVENTA04`: a root handoff (command `0x0E`) behind a typed guard, whose
callee plays one body and leaves by one door to `FLOOR5.MES`.

## The caller and the intro

| Property | `33C.MES` |
|---|---|
| framing-opaque bytes | **0 of 18,365** |
| instructions / branches / address entries | 2,505 / 145 / 93 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTA04` | `726..742` | root handoff | `450..550` | `752` | 15 | 176 B / 28 records / 0 branches / 0 dispatches | 7,062 | 13 | 70 |

The date is `state_u16[7]` as MMDD, the clock `state_u16[19]` as HHMM,
`banked_u16[201]` and `[202]` the A family's two affection words; flags
are `global_u8`. The guard wants any day from `6/16` to `9/15` before
`16:30`, the first A word above `40`, `[1148]` set, and `[1112]`,
`[110]`, `[112]`, `[114]`, `[117]`, `[1034]`, `[1059]`, `[263]`, `[1149]`,
`[994]` clear - no weekday; the A family's clear set 29C's A05 reads,
with `[1149]` as this event's own done flag and `[1148]` its
prerequisite.

## EVENTA04: the A family's summer day, one door to FLOOR5

Twenty-two witnesses pin every edge and flip every flag, every rejection
walking on to the `[140]` block at `752`. The prefix runs its message
blocks to the handoff at `726..742` writing nothing. `EVENTA04.MES`
writes `[5033]`, calls `P_PIC.MES` and `A_PIC.MES`, reads the first A
word against `70` three times - moving it up two below `70` and up three
at or above it - and at its door writes `[3434]`, `[263]` and `[1112]` -
two conjuncts of the guard - its own gate `[1149]`, `[1150]` and `[2462]`,
counts `[128]` when the second A word is above `30`, stamps
`banked_u16[242] = 33` and writes `[286]`, leaving by `7032..7046 ->
FLOOR5.MES` after 70 messages (80 when the word starts at or above 70).
The guard rejects on the post-replacement state by three conjuncts at
once, and a direct reentry takes the done-gate's false arm at `219`
straight to the `[128]` count, the stamp and the same door with **0
messages** - a closed gate still counts, re-stamps and leaves. Segmented
and unbroken runs agree. `state_u16[8]` is rewritten at `235` before it
is read and `global_u8[4000]` reads `0` at the callee's entry whatever is
seeded; `[3006]` and `[2847]` flip presentation arms.

Declared as `33c_a04_v6.json` with no contract, `P_PIC`, `A_PIC` and
`FLOOR5` among the members, one root-replacement route `33c-a04` with
14 variants - the A word and the `[128]` count varying per row -
`post_guard_expected` 0, the reentry the door again with the count's
second step (the row whose second word is at `30` overriding it). Audit
accepted; `original event analysis 33C A04` passes 434 checks; a wrong
callee message count and the door shifted one byte are rejected.

## Not measured here

What hands the root to `33C.MES`; what sets `[1148]` and moves the A
words; the picture scripts' native presentation; and `FLOOR5.MES` past
the door.
