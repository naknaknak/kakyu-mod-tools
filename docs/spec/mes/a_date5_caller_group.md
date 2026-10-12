# A_DATE5 caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`A_DATE5.MES` is a date script with one unresolved EVENT intro site,
`EVENTA17`: a nested call (command `0x0F`) behind a typed guard and the
script's own two-answer question, whose callee asks its own three-answer
question, returns, and whose caller then hands the root to the town.
Qualified with the route toolchain on its caller-continuation form with
both contracts.

## The caller and the intro

| Property | `A_DATE5.MES` |
|---|---|
| framing-opaque bytes | **0 of 17,010** |
| instructions / branches / address entries | 2,313 / 104 / 84 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTA17` | `3087..3103` | nested call | `2145..2183` | `3938` | 5 | 904 B / 3 branches / 0 dispatches / the question at `2835` | 4,120 | 21 | 40 |

A single-conjunct candidate precedes it (the clock before `18:00` at
`1097..1109`, false `3972`); the origin is the five-conjunct guard at
`2145`. Weekday is `state_u16[4]` (`0` a weekday), the date `state_u16[7]`
as MMDD with the new year's months written `13..15`, `banked_u16[201]`
the A family's affection word; flags are `global_u8`. The guard wants a
weekday from `11/16` to `3/10`, the A word above `90` and `[1125]` clear -
the callee's own done flag. In the gap the script reads `[116]` and
`[3006]` at `2488` and `2509`, writes `[3005] = 2` at `2558`, asks its own
two-answer question at `2835` (9 messages before it), and answer `1` -
`state_u16[21] == 1` at `2850`, false `3113` - moves the A word up two at
`3067` and dispatches; answer `2` is not measured.

## EVENTA17: the A family's winter date, three answers to one body, the script hands the root on

Eight witnesses pin the weekday, both date edges, the word and the flag,
every rejection walking on to the script's `MACHI` handoff at `3949..3962`.
The prefix runs 13 messages to the dispatch at `3087..3103`.
`EVENTA17.MES` walks its clock ladders at `435..559` and `684..900` behind
its gate at `219` on `[1125]` (false `4094`), writes `[5048]` and `[3447]`,
resets `[3005]`, and asks its question at `2576` (three definitions `2400`,
`2457`, `2514`; 23 messages before it): the three answers' `state_u16[21]`
chain at `2586..2626` jumps to the one body at `2626`, so every answer
plays 49 messages, closes `[1125]` at `3974`, writes its `[3205]` clock
ladder and returns at `4088..4089`. The caller resumes at `3103` with **0
messages**: it writes `[286]` and hands the root to `MACHI.MES` at
`3949..3962` - the same handoff a rejected guard reaches - the natural
handoff. The guard rejects the resumed state by `[1125]`, and a reentry on
it returns through the callee's gate to `4119..4120` with **0 messages**
and no change. Segmented and unbroken runs agree under every answer.
`state_u16[8]` is rewritten at `235` before it is read and
`global_u8[4000]` reads `0` at the callee's entry whatever is seeded;
`[3006]` flips one arm at `949`.

Declared as `a_date5_a17_v5.json` with both contracts (the caller's
`2835`, results `1..2`, answer `1` selected; the callee's `2576`, results
`1..3`), `MACHI` among the members, three caller-continuation routes by
answer on the `natural_handoff` policy with 11 variants in all, each
naming its answers, `post_guard_expected` 0, the reentry the return
record. Audit accepted; `original event analysis A_DATE5 A17` passes 333
checks; a wrong callee message count, the return record shifted one byte
and the resume handoff shifted one byte are rejected.

## Not measured here

What hands the root to `A_DATE5.MES`; what moves the A word outside this
route; the script's answer `2`; what either question offers as native
input (their results are supplied explicitly); and `MACHI.MES` past the
handoff.
