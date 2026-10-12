# 19M caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`19M.MES` is a map script with one unresolved EVENT intro site, `EVENTM15`:
a nested call (command `0x0F`) behind a typed guard and the map's own
two-answer question, whose callee counts a visit and returns, and whose
caller then hands the root to the town. Qualified with the route toolchain
on its caller-continuation form.

## The caller and the intro

| Property | `19M.MES` |
|---|---|
| framing-opaque bytes | **0 of 41,890** |
| instructions / branches / address entries | 5,292 / 403 / 136 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTM15` | `13243..13259` | nested call | `10242..10291` | `15859` | 7 | 2,952 B / 1 dispatch / the question at `12968` | 2,421 | 7 | 23 |

Weekday is `state_u16[4]` (`0` a weekday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM, `banked_u16[204]` an affection
word the callee reads; flags are `global_u8`. The guard wants a weekday
from `9/16` to `11/15` before `15:30` with `[150]`, `[2439]`, `[2500]`
clear - `[2500]` and `[2439]` are the two flags the caller closes after the
call. In the gap the caller clears `[156]` and calls `M_PIC.MES` at
`10312`, passes a constant-true head at `12837`, asks its own two-answer
question at `12968` (48 messages before it), and answer `1` -
`state_u16[21] == 1` at `12983`, false `14506` - dispatches; answer `2` is
not measured.

## EVENTM15: an autumn weekday, a counted visit, the map hands the root on

Ten witnesses pin both date edges, the clock edge and every flag, every
rejection stopping at the map's own question at `41324`. The prefix runs
52 messages to the dispatch at `13243..13259`. `EVENTM15.MES` counts
`[148]` at `139` when the word `[204]` is in `41..80` (the branch at
`118`; the word at `40` skips the count) - before its gate at `230` on
`[2501]` (false `2395`) - writes `[5165]` and `[3562]`, closes its own
`[2501]` at `2378` and returns at `2389..2390` after 31 messages. The
caller resumes at `13259` for 20 messages: it closes `[2500]` at `14436`
and `[2439]` at `14447` - two conjuncts of its own guard - stamps
`banked_u16[242] = 19`, writes `[286]` and hands the root to `MACHI.MES`
at `14483..14496`, the natural handoff. The guard rejects the resumed
state by those two flags, and a reentry on it returns through the
callee's gate to `2420..2421` with **0 messages** after counting `[148]`
again (the seeded-count and out-of-band word rows override it).
Segmented and unbroken runs agree. `state_u16[8]` is rewritten at `416`
before it is read and `global_u8[4000]` reads `0` at the callee's entry
whatever is seeded; `[2847]` flips one arm at `2255`.

Declared as `19m_m15_v5.json` with the caller's contract (`12968`, results
`1..2`, answer `1` selected), `M_PIC` and `MACHI` among the members, one
caller-continuation route `19m-m15` on the `natural_handoff` policy with
12 variants - the count varying per row - `post_guard_expected` 0, the
reentry the return record with the count's next step. Audit accepted;
`original event analysis 19M M15` passes 368 checks; a wrong callee
message count, the return record shifted one byte and the resume handoff
shifted one byte are rejected.

## Not measured here

What hands the root to `19M.MES`; what moves `[204]`; the question's
answer `2`; what the question offers as native input; `M_PIC.MES` native
presentation; and `MACHI.MES` past the handoff.
