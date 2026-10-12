# 10C caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`10C.MES` is a floor script with one unresolved EVENT intro site,
`EVENTD06`: a root handoff (command `0x0E`) behind a typed guard, whose
callee plays one body with no done-gate of its own and leaves by one
door to the town.

## The caller and the intro

| Property | `10C.MES` |
|---|---|
| framing-opaque bytes | **0 of 27,295** |
| instructions / branches / address entries | 3,437 / 251 / 128 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTD06` | `24439..24455` | root handoff | `22548..22650` | `24465` | 15 | 1,789 B / 270 records / 2 branches / 1 dispatch (`D_PIC`) | 9,892 | 30 | 103 |

Weekday is `state_u16[4]` (`0` a weekday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM, `banked_u16[212]` the D family's
affection word; flags are `global_u8`. The guard wants a weekday from
`4/01` to `6/15` between `10:01` and `17:00`, the D word in `51..89`,
`[402]` set, and `[220]`, `[224]`, `[225]`, `[227]`, `[754]`, `[778]`,
`[678]` clear - `[754]` being the flag this callee sets at its door, the
only gate the event has.

## EVENTD06: the D family's spring weekday, one door to the town, no gate of its own

Twenty-two witnesses pin every edge and flip every flag, every rejection
walking on to the `[466]` block at `24465`. The prefix sets `[226]`,
calls `D_PIC.MES`, takes two `[2847]` arms and runs its message blocks to
the handoff at `24439..24455`. `EVENTD06.MES` selects `[3232]` by the
clock, writes `[5365]`, `[5366]` and `[3740]`, calls `D_PIC.MES` twice,
reads `[676]` and `[691]` the guard does not fix, recomputes
`state_u16[5]` from `banked_u16[2]` itself, adds `50` to `state_u16[12]`,
and at its door moves the D word up three at `9811`, writes `[221]` and
the guard's `[754]`, sets `state_u16[16] = 5` and leaves by `9863..9876
-> MACHI.MES` after 127 messages; it writes no stamp. The guard rejects
on the post-replacement state by `[754]`, but the callee has no gate: a
direct reentry replays the whole body to the same door with 127
messages, moving the D word up three more and adding 50 again.
Segmented and unbroken runs agree. `state_u16[8]` is rewritten at `240`
before it is read (`46`, or `4` from 16:00) and `global_u8[4000]` reads
`0` at both of the callee's reads whatever is seeded; the callee's own
message routines toggle bit 128 of `banked_u16[2]` before the `[5]`
recompute, so that arm cannot be witnessed from a seed; `[3006]` and
`[2847]` flip presentation arms.

Declared as `10c_d06_v6.json` with no contract, `D_PIC` and `MACHI`
among the members, one root-replacement route `10c-d06` with 16
variants - the D word and the clock arm varying per row -
`post_guard_expected` 0, the reentry the door again with the word's
second move and the D-word rows overriding it. Audit accepted;
`original event analysis 10C D06` passes 423 checks; a wrong callee
message count and the door shifted one byte are rejected.

## Not measured here

What hands the root to `10C.MES`; what sets `[402]` and moves the D
word outside this callee; what `[676]` and `[691]` mean; `D_PIC.MES`
native presentation; and `MACHI.MES` past the door.
