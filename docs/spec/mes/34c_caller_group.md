# 34C caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`34C.MES` is a floor script with one unresolved EVENT intro site,
`EVENTL20`: a root handoff (command `0x0E`) behind a typed guard, whose
callee plays one body and leaves by one door to `FLOOR5.MES`.

## The caller and the intro

| Property | `34C.MES` |
|---|---|
| framing-opaque bytes | **0 of 27,256** |
| instructions / branches / address entries | 3,662 / 166 / 150 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTL20` | `2412..2428` | root handoff | `793..876` | `2443` | 12 | 1,536 B / 209 records / 0 branches / 1 dispatch (`L_PIC`) | 4,115 | 14 | 45 |

The date is `state_u16[7]` as MMDD, the clock `state_u16[19]` as HHMM,
`banked_u16[209]` the L family's affection word; flags are `global_u8`.
The guard wants any day from `11/16` to `15/10` between `12:30` and
`16:00`, the L word above `70`, and `[190]`, `[194]`, `[197]`, `[2042]`,
`[2076]`, `[1966]`, `[1925]` clear - no weekday and no prerequisite
flag, the L family's clear set with `[2076]` as this event's own done
flag.

## EVENTL20: the L family's late-year afternoon, one door to FLOOR5

Nineteen witnesses pin every edge and flip every flag, every rejection
walking on to the `11/16..` block at `2443`. The prefix clears `[196]`,
calls `L_PIC.MES` and runs its message blocks to the handoff at
`2412..2428`. `EVENTL20.MES` counts `[244]` at `118` before its gate,
selects `[3294]` by the clock, sets its own gate `[2076]` at `666` before
a word is spoken, writes `[5290]` and `[3670]`, calls `L_PIC.MES` again,
and at its door writes `[2042]` - a conjunct of the guard - the stamp
`banked_u16[242] = 34` and `[286]`, leaving by `4095..4109 -> FLOOR5.MES`
after 63 messages; it never touches the L word. The guard rejects on the
post-replacement state by both closed conjuncts, and a direct reentry
returns through the done-gate at `234` to `4114..4115` with **0
messages** - after counting `[244]` once more. Segmented and unbroken
runs agree. `state_u16[8]` is rewritten at `374` and `3558` before each
ladder and `global_u8[4000]` reads `0` at the callee's entry whatever is
seeded; `[2847]` flips presentation arms; a clock at exactly `16:00`
takes the ladder's `< 18:00` arm.

Declared as `34c_l20_v6.json` with no contract, `L_PIC` and `FLOOR5`
among the members, one root-replacement route `34c-l20` with 12
variants, `post_guard_expected` 0, the reentry the return record with
the counter's second step (the seeded-counter row overriding it). Audit
accepted; `original event analysis 34C L20` passes 325 checks; a wrong
callee message count and the door shifted one byte are rejected.

## Not measured here

What hands the root to `34C.MES`; what moves the L word; `L_PIC.MES`
native presentation; and `FLOOR5.MES` past the door.
