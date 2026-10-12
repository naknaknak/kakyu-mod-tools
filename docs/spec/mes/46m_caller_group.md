# 46M caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`46M.MES` is a map script with one unresolved EVENT intro site, `EVENTJ09`:
a nested call (command `0x0F`) behind a 14-conjunct typed guard, whose
callee returns and whose caller then hands the root to the town. The
first group qualified with the route toolchain on its caller-continuation
form.

## The caller and the intro

| Property | `46M.MES` |
|---|---|
| framing-opaque bytes | **0 of 42,627** |
| instructions / branches / address entries | 5,825 / 377 / 223 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTJ09` | `1642..1658` | nested call | `1248..1341` | `2648` | 14 | 301 B / 0 branches / 0 dispatches / 0 writes | 2,017 | 6 | 13 |

Weekday is `state_u16[4]` (`0` a weekday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM, `banked_u16[211]` the J family's
affection word; flags are `global_u8`. The guard wants a weekday before
`9/16` between `18:01` and `21:59`, the J word above `50`, `[401]` set,
and `[210]`, `[212]`, `[215]`, `[217]`, `[214]`, `[910]`, `[812]`, `[784]`
clear - `[910]` is the callee's own done flag and `[210]` the flag the
caller closes after the call.

## EVENTJ09: the J family's late summer evening, one body, the map hands the root on

Nineteen witnesses pin every edge and flip every flag, every rejection
walking on to the map's `MACHI` handoff at `23766..23779`. The prefix runs
5 messages to the dispatch at `1642..1658`. `EVENTJ09.MES` sets `[5334]`
at `600`, writes `[4000] = 1` at `1048`, `[3715]` at `1936`, closes its
own `[910]` at `1952` behind its gate at `219` (false `1991`), writes
`[858]` and `[854]` and returns at `1985..1986` after 15 messages. The
caller resumes at `1658` for 13 messages: it closes `[210]` at `1875` - a
conjunct of its own guard - writes `[362]`, `[915]`, `[927]`, stamps
`banked_u16[242] = 46`, writes `[286]`, clears `[4001]` and hands the root
to `MACHI.MES` at `2625..2638`, the natural handoff. The guard rejects the
resumed state by `[910]` and `[210]`, and a reentry on it returns through
the callee's gate to `2016..2017` with **0 messages** and no change.
Segmented and unbroken runs agree. `state_u16[8]` is rewritten at `256`
before it is read and `global_u8[4000]` reads `0` at the callee's entry
whatever is seeded; `[3006]` flips one arm at `1138`.

Declared as `46m_j09_v5.json` with no contract, `MACHI` among the members,
one caller-continuation route `46m-j09` on the `natural_handoff` policy
with 11 variants - `[3005]` varying per row - `post_guard_expected` 0,
the reentry the return record. Audit accepted; `original event analysis
46M J09` passes 443 checks; a wrong callee message count, the return
record shifted one byte and the resume handoff shifted one byte are
rejected.

## Not measured here

What hands the root to `46M.MES`; what moves the J word; and `MACHI.MES`
past the handoff.
