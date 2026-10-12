# 16M caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`16M.MES` is a map script with one unresolved EVENT intro site,
`EVENTQ01`: a root handoff (command `0x0E`) selected by the map's own
two-answer question, whose callee is staged over six visits and leaves by
one door to the town. Qualified with the route toolchain.

## The caller and the intro

| Property | `16M.MES` |
|---|---|
| framing-opaque bytes | **0 of 42,408** |
| instructions / branches / address entries | 5,624 / 373 / 198 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTQ01` | `42226..42242` | root handoff | `40886..40896` | `42257` | 1 | 1,330 B / 60 records / 5 branches / 0 dispatches / 2 handoffs | 26,799 | 112 | 321 |

The map's tail is a loop: a constant-true head at `40743..40750` (false
`42407`), two definitions at `40770` and `40803`, the question at `40871`,
and a jump back from `42402`. Answer `1` is `state_u16[21] == 1` at `40886`
and is the origin - the MACHI E04 / E10 shape, the answer register seeded
past the question; answer `2` stamps 16 and hands the root to `MACHI.MES`
at `42384..42397`, and any other value returns to the question. Under
answer `1` the gap reads `global_u8[2062]` and `[2063]` (`40901`, `41013`,
`41126`) and, past `17:59`, hands the root to `MACHI` at `41911` or
`42208` instead, closing `[2061]` at `41875`; with the clock at `12:00`
and both flags clear it reaches the handoff.

## EVENTQ01: the first visit of a staged callee, one door to the town

The seeds hold the answer register, clear `[2061]`, `[2062]`, `[2063]`,
`[2065]`, and the two witnesses are the other answers. The prefix runs 3
messages to the handoff at `42226..42242`. `EVENTQ01.MES` selects its
body on `[2062]` and `[2063]` at `224`: the first-visit body (both clear)
advances `[2062]` to `1` at `4672`, walks its presentation arms and at
its door writes `[2063] = 1` at `26689`, stamps `banked_u16[242] = 16` at
`26700` and writes `[286]`, leaving by `26725..26738 -> MACHI.MES` after
85 messages. The guard still accepts the post-replacement state - the
answer register is untouched - so `post_guard_expected` is `1`; a direct
reentry takes the `[2063] == 1` arm at `25437` to the same door with **16
messages**, moving only the clock. Segmented and unbroken runs agree.
`state_u16[8]` is rewritten at `421` before it is read and
`global_u8[4000]` reads `0` at the callee's entry whatever is seeded;
`[3006]` flips one arm at `1842` and leaves `[3005]` at `15`; Christmas
Eve changes `state_u16[8]`.

Declared as `16m_q01_v6.json` with no contract, `MACHI` among the
members, one root-replacement route `16m-q01` on the answer branch with
7 variants - `[3005]` and `state_u16[8]` varying per row -
`post_guard_expected` 1, the reentry the door with its 16-message
replay. Audit accepted; `original event analysis 16M Q01` passes 156
checks; a wrong callee message count and the door shifted one byte are
rejected.

## Not measured here

What hands the root to `16M.MES` and what the question offers as native
input; the later stages of `EVENTQ01.MES` - `[2062]` from `1` to `5` at
`4688`, `6820`, `12573`, `16917`, `22195`, the `[2065]` arms at
`7750..9558`, and the L word's move at `22148` in the fifth - which the
same guard reaches once `[2063]` is cleared elsewhere; the evening
handoffs at `41911` and `42208`; and `MACHI.MES` past the door.
