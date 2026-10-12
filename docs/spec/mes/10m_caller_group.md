# 10M caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`10M.MES` is a map script with one unresolved EVENT intro site, `EVENTM04`:
a nested call (command `0x0F`) behind a typed guard and the map's own
two-answer question, whose callee returns and whose caller then hands the
root to the town. Qualified with the route toolchain on its
caller-continuation form.

## The caller and the intro

| Property | `10M.MES` |
|---|---|
| framing-opaque bytes | **0 of 40,640** |
| instructions / branches / address entries | 5,146 / 394 / 134 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTM04` | `19916..19932` | nested call | `17248..17289` | `22280` | 6 | 2,627 B / 1 dispatch / the question at `19649` | 2,186 | 7 | 15 |

Weekday is `state_u16[4]` (`0` a weekday), the clock `state_u16[19]` as
HHMM; flags are `global_u8`. The guard wants a weekday before `16:00` with
`[2420]` set and `[150]`, `[2439]`, `[2423]` clear - `[2423]` and `[2439]`
are the two flags the caller closes after the call. In the gap the caller
clears `[156]` and calls `M_PIC.MES` at `17310`, passes a constant-true head
at `19518`, asks its own two-answer question at `19649` (40 messages before
it), and answer `1` - `state_u16[21] == 1` at `19664`, false `21167` -
dispatches; answer `2` is not measured.

## EVENTM04: a weekday afternoon, one body, the map hands the root on

Seven witnesses pin the clock edge and flip every flag, every rejection
stopping at the map's own question at `38375`. The prefix runs 44 messages
to the dispatch at `19916..19932`. `EVENTM04.MES` counts `[244]` at `118` -
before its gate at `244` on `[2424]` (false `2160`), so a reentry counts
again - writes `[5156]` and `[3556]`, closes its own `[2424]` at `2143` and
returns at `2154..2155` after 19 messages. The caller resumes at `19932`
for 20 messages: it counts `[244]` once more, closes `[2423]` at `21097`
and `[2439]` at `21108` - two conjuncts of its own guard - stamps
`banked_u16[242] = 10`, writes `[286]` and hands the root to `MACHI.MES`
at `21144..21157`, the natural handoff. The guard rejects the resumed state
by those two flags, and a reentry on it returns through the callee's gate
to `2185..2186` with **0 messages** after counting `[244]` a third time
(the seeded-count row overrides it). Segmented and unbroken runs agree.
`state_u16[8]` is rewritten at `291` before it is read and `global_u8[4000]`
reads `0` at the callee's entry whatever is seeded; `[2847]` flips one arm
at `2020`.

Declared as `10m_m04_v5.json` with the caller's contract (`19649`, results
`1..2`, answer `1` selected), `M_PIC` and `MACHI` among the members, one
caller-continuation route `10m-m04` on the `natural_handoff` policy with
8 variants - the count varying per row - `post_guard_expected` 0, the
reentry the return record with the count's next step. Audit accepted;
`original event analysis 10M M04` passes 251 checks; a wrong callee
message count, the return record shifted one byte and the resume handoff
shifted one byte are rejected.

## Not measured here

What hands the root to `10M.MES`; the question's answer `2`; what the
question offers as native input; `M_PIC.MES` native presentation; and
`MACHI.MES` past the handoff.
