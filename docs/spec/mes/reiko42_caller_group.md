# REIKO42 caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`REIKO42.MES` is a character script with one unresolved EVENT intro site,
`EVENTF07`: a root handoff (command `0x0E`) behind a typed guard, whose
callee counts a visit, asks its own three-answer question and leaves by
one door to the town. Qualified with the route toolchain.

## The caller and the intro

| Property | `REIKO42.MES` |
|---|---|
| framing-opaque bytes | **0 of 13,545** |
| instructions / branches / address entries | 1,800 / 101 / 77 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTF07` | `7973..7989` | root handoff | `6086..6154` | `8004` | 10 | 1,819 B / 93 records / 17 branches / 0 dispatches | 8,791 | 13 | 95 |

Two single-conjunct guard candidates precede it (`2877..2967`, false
`10025`; `5594..5605`, false `9955`); the origin is the ten-conjunct guard
at `6086`. Weekday is `state_u16[4]` (`0` a weekday), the date
`state_u16[7]` as MMDD, the clock `state_u16[19]` as HHMM, `banked_u16[200]`
an affection word the callee moves; flags are `global_u8`. The guard wants
a weekday from `7/26` to `8/31` between `10:01` and `16:00` with `[104]`,
`[105]`, `[1545]`, `[1502]`, `[1631]` clear - `[1631]` is this event's own
done flag. The gap is the caller's presentation bookkeeping: `[2811]` and
`[2809]` toggled, `banked_u16[5]` and `[9]` recomputed, and a seventeen-arm
ladder on `state_u16[2]` at `6644..7217` after `state_u16[2] = 13` at
`6639`.

## EVENTF07: a summer weekday, a counted visit and three answers to one door

Fourteen witnesses pin every edge and flip every flag, every rejection
walking on to the caller's own `MACHI` handoff at `10002..10015`. The
prefix runs 19 messages to the handoff at `7973..7989`. `EVENTF07.MES`
counts `[264]` at `143` - before its gate, so a reentry counts again -
writes `[4000] = 1` at `560` and its own gate `[1631]` at `571` before a
word is spoken, walks its `[3249]` presentation ladder at `594..674`,
writes `[5005]` at `747`, and asks its question at `2657` (three
definitions `2495`, `2536`, `2577`; 25 messages before it): answer `1`
moves the word down three behind a `> 3` gate at `6027` (false `6068`,
which zeroes it) and writes `[1632]` and `[5006]`, answer `2` moves it up
two at `7461`, answer `3` down three behind the same gate at `8645` (false
`8686`); every answer then stamps `banked_u16[242] = 42` at `8711` and
writes `[286]`, leaving by `8747..8760 -> MACHI.MES` after 77, 48 or 44
messages. The guard rejects every post-replacement state by `[1631]`, and
a direct reentry returns through the done-gate to `8790..8791` with **0
messages** after counting `[264]` once more and resetting `state_u16[2]`.
Segmented and unbroken runs agree under every answer. `state_u16[8]` is
rewritten at `281` before it is read and `global_u8[4000]` reads `0` at
the callee's entry whatever is seeded; the `16:00` witness flips arms at
`628` and `651`, and the word at `4` takes the gate's other arm.

Declared as `reiko42_f07_v6.json` with the callee's contract, `MACHI`
among the members, three root-replacement routes by answer sharing the
one door with 14 variants in all, each naming its answer,
`post_guard_expected` 0, the reentry the return record with the count's
second step (the seeded-count row overriding it). Audit accepted;
`original event analysis REIKO42 F07` passes 453 checks; a wrong callee
message count and the door shifted one byte are rejected.

## Not measured here

What hands the root to `REIKO42.MES`; what moves `[200]` outside this
callee; what the question offers as native input (its results are
supplied explicitly); and `MACHI.MES` past the door.
