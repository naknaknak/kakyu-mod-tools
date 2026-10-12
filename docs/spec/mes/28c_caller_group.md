# 28C caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`28C.MES` is a floor script with one unresolved EVENT intro site,
`EVENTL13`: a root handoff (command `0x0E`) behind two nested typed
guards, whose callee plays one body and leaves by one door to
`FLOOR1.MES`.

## The caller and the intro

| Property | `28C.MES` |
|---|---|
| framing-opaque bytes | **0 of 29,437** |
| instructions / branches / address entries | 3,976 / 194 / 156 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Outer guard | Inner guard | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|
| `EVENTL13` | `687..703` | root handoff | `459..507` (false `5824`, 7 conjuncts) | `512..545` (false `708`, 4 conjuncts) | 180 B / 30 records / the inner guard / 0 dispatches | 1,983 | 6 | 21 |

Weekday is `state_u16[4]` (`6` Saturday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM, `banked_u16[209]` and `[202]` two
of the L family's affection words; flags are `global_u8`. The outer guard
wants a Saturday evening (`16:00..18:00`) with `[190]`, `[197]`, `[194]`,
`[1925]` clear; the inner guard, five bytes later, wants `9/16` to
`11/15`, the L word above `50` and `[2071]` clear - this event's own done
flag. The origin is the outer guard, with the inner guard inside its
gap: the audit accepts that shape, and `post_guard_expected` is `1`
because the callee closes only inner-guard cells.

## EVENTL13: the L family's autumn Saturday evening behind two guards, one door to FLOOR1

Seventeen witnesses pin every edge and flip every flag of both guards,
each reported with both guards' values: an outer rejection walks on to
an unrelated `FLOOR1` handoff at `29407`, an inner rejection through the
`[2841]` write at `708` into `L_INTRO` and a talk script's own question.
The prefix runs 6 messages to the handoff at `687..703`. `EVENTL13.MES`
counts `[128]` at `139` when the second L word is in `31..100` - before
its gate, so a reentry counts again - sets its own gate `[2071]` at `406`
before a word is spoken, writes `[5284]` and `[3665]`, and at its door
moves the L word up one at `1878`, stamps `banked_u16[242] = 28`, stores
the date into `banked_u16[267]` at `1912` and writes `[286]`, leaving by
`1938..1952 -> FLOOR1.MES` after 28 messages. The outer guard still
accepts the post-replacement state (the callee writes none of its
cells) while the inner guard rejects by `[2071]`, and a direct reentry
returns through the done-gate at `225` to `1982..1983` with **0
messages** after counting `[128]` once more. Segmented and unbroken runs
agree. `state_u16[8]` is rewritten at `417` before it is read and
`global_u8[4000]` reads `0` at the callee's entry whatever is seeded; the
callee has no presentation arm of its own.

Declared as `28c_l13_v6.json` with no contract, `FLOOR1`, `L_INTRO`,
`L_TALK50` and `L_TALK60` among the members (the last three reached only
by rejecting walks), one root-replacement route `28c-l13` on the outer
guard with 16 variants - the L word, the stored date and the count
varying per row - `post_guard_expected` 1, the reentry the return
record with the count's second step (the out-of-range and seeded-count
rows overriding it). Audit accepted; `original event analysis 28C L13`
passes 429 checks; a wrong callee message count and the door shifted
one byte are rejected.

## Not measured here

What hands the root to `28C.MES`; what moves the L words; the talk
scripts a rejection reaches; and `FLOOR1.MES` past the door.
