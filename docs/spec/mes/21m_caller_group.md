# 21M caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`21M.MES` is a map script with one unresolved EVENT intro site, `EVENTM08`:
a nested call (command `0x0F`) behind a typed guard and the map's own
two-answer question, whose callee returns and whose caller then hands the
root to the town. Qualified with the route toolchain on its
caller-continuation form.

## The caller and the intro

| Property | `21M.MES` |
|---|---|
| framing-opaque bytes | **0 of 41,933** |
| instructions / branches / address entries | 5,340 / 416 / 137 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTM08` | `12211..12227` | nested call | `10252..10314` | `14907` | 9 | 1,897 B / 1 dispatch / the question at `11618` | 3,834 | 9 | 37 |

Weekday is `state_u16[4]` (`0` a weekday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM; flags are `global_u8`. The guard
wants a weekday from `7/21` to `8/31` between `10:00` and `13:00` with
`[2420]` set and `[150]`, `[2439]`, `[2440]` clear - `[2440]` and `[2439]`
are the two flags the caller closes after the call. In the gap the caller
clears `[156]` and calls `M_PIC.MES` at `10335`, passes a constant-true
head at `11487`, asks its own two-answer question at `11618` (20 messages
before it), and answer `1` - `state_u16[21] == 1` at `11633`, false
`13349` - dispatches; answer `2` is not measured.

## EVENTM08: a summer late morning, one body, the map hands the root on

Thirteen witnesses pin every edge and flip every flag: the date edges walk
on to the map's `MACHI` handoff at `25288..25301`, the `9:59` clock to its
handoff at `40146..40159`, every other rejection stops at the map's own
question at `40722`. The prefix runs 31 messages to the dispatch at
`12211..12227`. `EVENTM08.MES` clears `[156]` and calls `M_PIC.MES` itself
at `445` behind its gate at `234` on `[2441]` (false `3833`), writes
`[5160]` and `[3559]`, closes its own `[2441]` at `3816` and returns at
`3827..3828` after 50 messages. The caller resumes at `12227` for 15
messages: it closes `[2440]` at `13279` and `[2439]` at `13290` - two
conjuncts of its own guard - stamps `banked_u16[242] = 21`, writes `[286]`
and hands the root to `MACHI.MES` at `13326..13339`, the natural handoff.
The guard rejects the resumed state by those two flags, and a reentry on
it returns through the callee's gate to `3833..3834` with **0 messages**
and no change. Segmented and unbroken runs agree. `state_u16[8]` is
rewritten at `1308` before it is read and `global_u8[4000]` reads `0` at
the callee's entry whatever is seeded; `[2847]` flips arms at `327` and
`3523`, `[3006]` at `2190`.

Declared as `21m_m08_v5.json` with the caller's contract (`11618`, results
`1..2`, answer `1` selected), `M_PIC` and `MACHI` among the members, one
caller-continuation route `21m-m08` on the `natural_handoff` policy with
9 variants, `post_guard_expected` 0, the reentry the return record.
Audit accepted; `original event analysis 21M M08` passes 264 checks; a
wrong callee message count, the return record shifted one byte and the
resume handoff shifted one byte are rejected.

## Not measured here

What hands the root to `21M.MES`; the question's answer `2`; what the
question offers as native input; `M_PIC.MES` native presentation; and
`MACHI.MES` past the handoff.
