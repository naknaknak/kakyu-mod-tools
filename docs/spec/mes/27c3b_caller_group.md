# 27C3B caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`27C3B.MES` is a floor script with one unresolved EVENT intro site,
`EVENTA01`: a root handoff (command `0x0E`) behind a typed guard, whose
callee asks its own three-answer question and leaves by one door to
`FLOOR4.MES`. Qualified with the route toolchain.

## The caller and the intro

| Property | `27C3B.MES` |
|---|---|
| framing-opaque bytes | **0 of 12,802** |
| instructions / branches / address entries | 1,815 / 67 / 99 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTA01` | `1687..1703` | root handoff | `1354..1492` | `1718` | 17 | 195 B / 9 records / 0 branches / 0 dispatches, one write | 7,043 | 15 | 82 |

Weekday is `state_u16[4]` (`6` Saturday), the date `state_u16[7]` as
MMDD with the new year's months written `13..15`, the clock `state_u16[19]`
as HHMM, `banked_u16[201]` the A family's affection word, `banked_u16[242]`
the last event stamp; flags are `global_u8`. The guard wants the stamp
not `271`, a Saturday from `4/01` to `6/15` or from `9/16` to `3/10`,
the clock from `12:30` to `16:30`, the A word from `31` to `60`, and
`[110]`, `[112]`, `[114]`, `[115]`, `[117]`, `[1059]`, `[1112]`,
`[1034]`, `[1110]`, `[994]` clear - `[1110]`, `[1112]` and the stamp are
the three cells the callee closes. The caller writes `[263] = 1` at
`1671` in the gap before the handoff.

## EVENTA01: the A family's Saturday afternoon, three answers to one door

Twenty-eight witnesses pin every edge and flip every flag, every rejection
walking on to the caller's own `FLOOR4` handoff at `12772..12786`. The
prefix runs 6 messages to the handoff at `1687..1703`. `EVENTA01.MES`
writes `[5029]` at `732`, `[3430]` at `2636`, clears `[116]` and calls
`A_PIC.MES` at `2869`, and asks its question at `3269` (three definitions
`3105`, `3158`, `3211`; 40 messages before it): answer `1` moves the A
word up one at `4577`, answer `2` up one at `5663`, answer `3` down one at
`6909` behind a `> 1` gate at `6888` (false `6929`, which zeroes the word);
every answer then reads `[395]` at `6965` around a `[148]` count the
baseline does not take, writes `[1110]` and `[1112]` at `6943` and `6954`,
stamps `banked_u16[242] = 271` at `6986` and writes `[286]`, leaving by
`7013..7027 -> FLOOR4.MES` after 66, 58 or 62 messages. The guard rejects
every post-replacement state by the stamp, `[1110]` and `[1112]`, and a
direct reentry jumps through its gate to the same door with **0
messages** and no change. Segmented and unbroken runs agree under every
answer. `state_u16[8]` is rewritten at `235` before it is read and
`global_u8[4000]` reads `0` at the callee's entry whatever is seeded;
`[2847]` flips arms at `2735` and `4297`, `[3006]` at `641`.

Declared as `27c3b_a01_v6.json` with the callee's contract, `A_PIC` and
`FLOOR4` among the members, three root-replacement routes by answer
sharing the one door with 16 variants in all, each naming its
answer, `post_guard_expected` 0, the reentry the door itself; two direct
probes with the word at `1` and `2` are measured and not declared. Audit
accepted; `original event analysis 27C3B A01` passes 540 checks; a wrong
callee message count and the door shifted one byte are rejected.

## Not measured here

What hands the root to `27C3B.MES`; what moves the A word outside this
callee; what the question offers as native input (its results are
supplied explicitly); `A_PIC.MES` native presentation; and `FLOOR4.MES`
past the door.
