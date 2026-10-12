# H_DATE3 caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`H_DATE3.MES` is a date script with one unresolved EVENT intro site,
`EVENTH19`: a nested call (command `0x0F`) behind two nested typed guards,
whose callee asks its own three-answer question, moves the H word and
returns, and whose caller then hands the root to `H_DATE5.MES`. Qualified
with the route toolchain on its caller-continuation form.

## The caller and the intro

| Property | `H_DATE3.MES` |
|---|---|
| framing-opaque bytes | **0 of 31,474** |
| instructions / branches / address entries | 4,075 / 145 / 232 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Outer guard | Inner guard | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|
| `EVENTH19` | `18535..18551` | nested call | `17523..17542` (false `18732`, 2 conjuncts) | `18493..18525` (false `18696`, 4 conjuncts) | 993 B / 2 branches / 2 writes | 4,672 | 13 | 53 |

The date is `state_u16[7]` as MMDD with the new year's months written
`13..15`, the clock `state_u16[19]` as HHMM, `banked_u16[207]` the H
family's affection word; flags are `global_u8`. The outer guard wants the
H word above `90` and `[2081]` clear; the inner guard, ten bytes before
the dispatch, wants a date from `11/16` to `3/10`, the clock past `18:00`
and `[2335]` clear - the callee's gate cell, which the caller closes after
the call. Between them the script reads `[2108]` at `17933` and writes
`[2108]` and `[2172]` at `18471` and `18482`. The origin is the outer
guard with the inner in its gap, the 28C L13 shape; the script's own
selection `state_u16[21] == 2` at `13397` precedes both.

## EVENTH19: the H family's winter evening, three answers to one return

Ten witnesses cover both guards: the `[2081]` rejection walks on to the
script's `H_DATE5` handoff at `20139..20154`, the word at `90` to the
script's return at `31473`, and the inner guard's edges - `11/15`, `3/11`,
`18:00`, `[2335]` set - are accepted by the outer guard yet stop the prefix
short of the dispatch. The prefix runs 16 messages to the dispatch at
`18535..18551`. `EVENTH19.MES` writes `[5232]` and `[3615]` behind its gate
at `229` on `[2335]` (false `4646`) and asks its question at `1465` (three
definitions `1275`, `1332`, `1393`; 12 messages before it): answer `1`
moves the H word up two at `2498`, answer `2` down three at `3441` behind
a `> 3` gate at `3420` (false `3461`, which zeroes it), answer `3` down
five at `4395` behind a `> 5` gate at `4374` (false `4415`); every answer
returns at `4640..4641` after 32, 28 or 31 messages. The caller resumes at
`18551` with **0 messages**: it closes `[2335]`, writes `[3000] = 4` and
`[3005] = 15`, clears `[4090]` and `[4091]` and hands the root to
`H_DATE5.MES` at `18707..18722`, the natural handoff. The outer guard
still accepts the resumed state - it reads neither `[2335]` nor the word's
new value out of range - so `post_guard_expected` is `1`, while the inner
guard rejects it; a reentry on the resumed state returns through the
callee's gate to `4671..4672` with **0 messages** and no change. Segmented
and unbroken runs agree under every answer. `state_u16[8]` is rewritten at
`266` and `4445` before it is read and `global_u8[4000]` reads `0` at the
callee's entry whatever is seeded.

Declared as `h_date3_h19_v5.json` with the callee's contract, one
caller-continuation route per answer on the `natural_handoff` policy with
12 variants in all, each naming its answer, `post_guard_expected` 1,
the reentry the return record; four direct probes with the word at `3..6`
are measured and not declared. Audit accepted; `original event analysis
H_DATE3 H19` passes 426 checks; a wrong callee message count, the return
record shifted one byte and the resume handoff shifted one byte are
rejected.

## Not measured here

What hands the root to `H_DATE3.MES` and how its selection reaches
`13397`; what moves the H word outside this callee; what the question
offers as native input (its results are supplied explicitly); and
`H_DATE5.MES` past the handoff.
