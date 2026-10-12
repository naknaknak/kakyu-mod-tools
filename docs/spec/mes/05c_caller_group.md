# 05C caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`05C.MES` is a floor script with one unresolved EVENT intro site,
`EVENTI21`: a root handoff (command `0x0E`) behind a typed guard and the
caller's own three-answer question, whose callee plays one body and leaves
by one door to the town. It is the first group qualified with the
spec-driven route toolchain (`tools/draft_event_route_spec.py`,
`tools/qualify_event_route.py`) rather than a hand-written probe.

## The caller and the intro

| Property | `05C.MES` |
|---|---|
| framing-opaque bytes | **0 of 19,898** |
| instructions / branches / address entries | 2,702 / 75 / 142 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTI21` | `2560..2576` | root handoff | `394..510` | `5396` | 14 | 2,050 B / 97 records / 1 branch / 1 dispatch / the question at `2121` | 3,759 | 22 | 31 |

Weekday is `state_u16[4]` (`0` a weekday), the date `state_u16[7]` as
MMDD with the new year's months written `13..15`, the clock `state_u16[19]`
as HHMM, `banked_u16[203]` the I family's affection word; flags are
`global_u8`. The guard wants a weekday from `11/16` to `12/14` or from
`1/08` to `3/10`, the clock from `10:01` to `16:29`, the I word from `51`
to `80`, `[477]` set, and `[130]`, `[137]`, `[135]`, `[134]`, `[1259]`,
`[1346]`, `[1219]` clear; `[130]` is this event's own done flag. In the
gap the caller writes `[136] = 1` at `520`, calls `I_PIC.MES` at `531`,
asks its own three-answer question at `2121` (three definitions), and
answer `1` - `state_u16[21] == 1` at `2131`, false `2586` - closes
`[1346]` at `2549`, a clear conjunct of its own guard, and hands the root
over; answers `2` and `3` skip past the handoff and are not measured.

## EVENTI21: the I family's winter weekday behind the caller's own question, one door to the town

Twenty-five witnesses pin every edge of the weekday, both date windows,
the clock, the word and every flag; every rejection walks on past `5396`
into the floor's later blocks without a terminal inside the segment
budget. The prefix runs 33 messages - 25 before the question - to the
handoff at `2560..2576`. `EVENTI21.MES` writes its `[3277]` presentation
ladder at `416..502` and `[5107]` at `1143`, walks a clock ladder at
`450..949` (the `16:29` witness flips six arms), copies a banked block
under `state_u16[2]` at `3275..3292`, then at its door stores the I word
into `banked_u16[262]` at `3646` and **sets** the word to `25` at `3664`
(the guard's `51..80` window is left behind, not moved through), writes
`[3510]` and `[1301]`, closes `[130]` at `3678`, counts `[138]` at
`3689`, stamps `banked_u16[242] = 15` at `3704` and writes `[286]`,
leaving by `3740..3753 -> MACHI.MES` after 42 messages. The guard rejects
every post-replacement state by the callee's `[130]` and the word, and by
the caller's `[1346]`; a direct reentry returns through the done-gate to
`3758..3759` with **0 messages** and no change. Segmented and unbroken
runs agree. `state_u16[8]` is rewritten at `256` before it is read and
`global_u8[4000]` reads `0` at the callee's entry whatever is seeded;
`[3006]` flips one presentation arm at `1052`.

Declared as `05c_i21_v6.json` with the caller's contract (`2121`, results
`1..3`, answer `1` selected), `I_PIC` and `MACHI` among the members, one
root-replacement route `05c-i21` with 14 variants - `[3005]`
and `state_u16[8]` varying per row - `post_guard_expected` 0, the reentry
the return record. Audit accepted; `original event analysis 05C I21`
passes 414 checks; a wrong callee message count and the door shifted one
byte are rejected.

## Not measured here

What hands the root to `05C.MES`; what moves the I word; the question's
answers `2` and `3`; `I_PIC.MES` native presentation; and `MACHI.MES`
past the door.
