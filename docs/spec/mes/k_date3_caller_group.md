# K_DATE3 caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`K_DATE3.MES` is a date script with one unresolved EVENT intro site,
`EVENTK15`: a nested call (command `0x0F`) behind a typed guard, whose
callee counts a visit and returns, and whose caller then hands the root to
`K_DATE5.MES`. Qualified with the route toolchain on its
caller-continuation form.

## The caller and the intro

| Property | `K_DATE3.MES` |
|---|---|
| framing-opaque bytes | **0 of 32,432** |
| instructions / branches / address entries | 4,369 / 145 / 253 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTK15` | `17370..17386` | nested call | `17321..17360` | `17407` | 5 | 10 B / 0 records | 1,975 | 6 | 15 |

The date is `state_u16[7]` as MMDD with the new year's months written
`13..15`, the clock `state_u16[19]` as HHMM, `banked_u16[200]` an
affection word the callee reads; flags are `global_u8`. The guard wants a
date from `11/16` to `3/10` that is not New Year's Day, the clock past
`18:00` and `[2341]` clear - the callee's gate cell, which the caller
closes after the call. Three candidates precede it outside the origin: a
constant-true head at `9153`, the script's own selection `state_u16[21] ==
2` at `13300`, and `banked_u16[208] < 91` at `15961` (false `17443`).

## EVENTK15: a winter evening, a counted visit, the script hands the root on

Eight witnesses pin both date edges, New Year's Day, the clock edge and
the flag, every rejection walking on to the script's `K_DATE5` handoff at
`17418..17433`. The prefix runs 0 messages to the dispatch at
`17370..17386`. `EVENTK15.MES` counts `[108]` at `164` when the word
`[200]` is in `31..80` (the branch at `143`; the word at `30` skips the
count) - before its gate at `255` on `[2341]` (false `1949`), so a reentry
counts again - writes `[5262]` and `[3640]` and returns at `1943..1944`
after 20 messages, never writing `[2341]` itself. The caller resumes at
`17386` with **0 messages**: it writes `[2268]` and closes `[2341]` at
`17396` and hands the root to `K_DATE5.MES` at `17418..17433` - the same
handoff a rejected guard reaches - the natural handoff. The guard rejects
the resumed state by `[2341]`, and a reentry on it returns through the
callee's gate to `1974..1975` with **0 messages** after counting `[108]`
again (the seeded-count and out-of-band word rows override it). Segmented
and unbroken runs agree. `state_u16[8]` is rewritten at `292` before it is
read and `global_u8[4000]` reads `0` at the callee's entry whatever is
seeded.

Declared as `k_date3_k15_v5.json` with no contract, one
caller-continuation route `k-date3-k15` on the `natural_handoff` policy
with 12 variants - the count varying per row - `post_guard_expected`
0, the reentry the return record with the count's next step. Audit
accepted; `original event analysis K_DATE3 K15` passes 314 checks; a
wrong callee message count, the return record shifted one byte and the
resume handoff shifted one byte are rejected.

## Not measured here

What hands the root to `K_DATE3.MES` and how its selection reaches
`13300`; what moves `[200]` and `[208]`; and `K_DATE5.MES` past the
handoff.
