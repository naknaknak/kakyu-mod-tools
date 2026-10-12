# 29C caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`29C.MES` is a floor script with one unresolved EVENT intro site,
`EVENTA05`: a root handoff (command `0x0E`) behind a typed guard, whose
callee plays one body and leaves by one door to `FLOOR4.MES`.

## The caller and the intro

| Property | `29C.MES` |
|---|---|
| framing-opaque bytes | **0 of 23,543** |
| instructions / branches / address entries | 3,180 / 163 / 122 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTA05` | `12555..12571` | root handoff | `12223..12363` | `12581` | 21 | 192 B / 26 records / 0 branches / 0 dispatches | 4,086 | 9 | 32 |

Weekday is `state_u16[4]` (`6` Saturday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM, `banked_u16[201]` the A family's
affection word and `banked_u16[242]` the map stamp; flags are
`global_u8`. The guard wants the stamp not `29`, a Saturday from `4/01`
to `6/15` between `12:30` and `14:30`, the A word in `31..70`, `[1113]`
set, and `[110]`, `[1034]`, `[112]`, `[114]`, `[117]`, `[1059]`, `[1115]`,
`[994]`, `[124]`, `[127]`, `[120]`, `[1792]` clear - the A family's clear
set 27C3B's A01 and 33C's A04 read, with `[1115]` as this event's own
done flag and `[1113]` its prerequisite.

## EVENTA05: the A family's spring Saturday early afternoon, one door to FLOOR4

Twenty-nine witnesses pin every edge - the stamp's own exclusion among
them - and flip every flag, every rejection walking on to the Saturday
block at `12581`. The prefix runs 4 messages to the handoff at
`12555..12571` writing nothing. `EVENTA05.MES` writes `[5032]` and
`[3433]`, calls `E_PIC.MES` and `A_PIC.MES`, runs 39 messages, and at its
door sets its own gate `[1115]` - a conjunct of the guard - and `[1112]`,
stamps `banked_u16[242] = 29` and writes `[286]`, leaving by `4056..4070
-> FLOOR4.MES`; it never touches the A word. The guard rejects on the
post-replacement state by the stamp and the gate both, and a direct
reentry takes the done-gate's false arm at `219` straight to the stamp
and the same door with **0 messages** - a closed gate still re-stamps
and leaves. Segmented and unbroken runs agree. `state_u16[8]` is
rewritten at `235` before it is read and `global_u8[4000]` reads `0` at
the callee's entry whatever is seeded; `[3006]` and `[2847]` flip
presentation arms.

Declared as `29c_a05_v6.json` with no contract, `E_PIC`, `A_PIC` and
`FLOOR4` among the members, one root-replacement route `29c-a05` with
12 variants, `post_guard_expected` 0, the reentry the door again
with 0 messages. Audit accepted; `original event analysis 29C A05`
passes 322 checks; a wrong callee message count and the door shifted
one byte are rejected.

## Not measured here

What hands the root to `29C.MES`; what sets `[1113]` and moves the A
word; the picture scripts' native presentation; and `FLOOR4.MES` past
the door.
