# 15C caller group

Inventoried on 2026-09-12 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`15C.MES` is a root the town map hands off to (`MACHI.MES:36671`, command
`0x0E`, its only literal caller), a caller with three unresolved EVENT intro
sites for three targets: `EVENTI10` as a root handoff into a callee that
hands the root back to `MACHI.MES` by one of several doors, and `EVENTC06`
and `EVENTE11` as nested calls the caller resumes after. All three callees
ask their own three-answer question, and every answer moves the family's
affection word. The caller asks none of its own. The instrument is the one
that opened the earlier groups; run first on `01M.MES`, it reproduces the
44C-era control exactly before it is run here.

## The caller

| Property | `15C.MES` |
|---|---|
| framing-opaque bytes | **0 of 37,993** |
| instructions / branches / calls | 4,830 / 364 / 554 |
| address-table entries | 170 |
| EVENT intro sites | 3, for three targets |
| intros with a typed guard candidate | **all 3** |
| dispatch form | I10 a root handoff, C06 and E11 nested calls |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTI10.MES`, the
largest callee measured so far at 16,389 bytes, is one body behind its own
`global_u8[1333]` gate with a question at `5582` whose three answers leave
by three doors (`8506..8519`, `12345..12358`, `15874..15887`), a fourth
body at `15892` leaving by `16370..16383`, and `I_PIC.MES` dispatched on
every path; `EVENTC06.MES` is one body behind `[1762]` with a question at
`2210` and returns; `EVENTE11.MES` is one body behind `[1905]` with a
question at `1800` and returns. No callee dispatches `TRAIN.MES`.

## The three intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---:|---:|---:|
| `EVENTI10` | `841..857` | root handoff | `558..668` | 16,389 | 83 | 128 |
| `EVENTC06` | `5139..5155` | nested call | `4854..4948` | 5,389 | 28 | 50 |
| `EVENTE11` | `7607..7623` | nested call | `6307..6403` | 6,398 | 17 | 69 |

## Three guards, one with two date windows

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---|---:|:-:|---:|---:|---:|---:|
| `EVENTI10` | `558..668` | `867` | 13 | **yes** | 173 | 32 | 1 | **0** | 0 |
| `EVENTC06` | `4854..4948` | `5181` | 14 | - | 191 | 33 | **0** | **0** | 0 |
| `EVENTE11` | `6307..6403` | `8598` | 14 | - | 1,204 | 157 | **0** | 1 (`E_PIC`) | 0 |

I10's gap holds one branch of its own, `673` `date > 6/15`, which writes
`[2612] = 1` - a cell the callee reads twice (`343`, `2389`) to choose its
opening - and `[440] = 1` before the handoff. C06's gap is presentation
only; after the call the caller writes `[350] = 1` at `5165` and falls
into a Q-family guard at `5181`. E11's gap writes `[126]` and dispatches
`E_PIC.MES` at `6424`; after the call the caller writes `[126]` again,
dispatches `E_PIC` again, runs a `[2847]` arm and a date ladder, writes
`[350] = 1` at `8582` and reaches the next guard at `8598`. Neither
nested resume meets a question of the caller's - `15C.MES` has no
routine-40 record - so both are expected to walk on to a handoff.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`0` a weekday, `6` Saturday), the date
`state_u16[7]` as MMDD, the clock `state_u16[19]` as HHMM, and
`banked_u16[203]`, `[206]`, `[202]` the I, C and E families' affection
words. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTI10` | Saturday, `5/01..7/20` **or** `9/01..9/15`, `15:01..18:00` | `[203]` in `41..80` | - | `[130]`, `[132]`, `[137]`, `[134]`, `[1259]`, `[1333]`, `[1219]` |
| `EVENTC06` | weekday `0`, `4/01..6/15`, `10:00..16:30` | `[206] < 71` | `[396]` | `[160]`, `[164]`, `[1694]`, `[167]`, `[1762]`, `[1775]`, `[1653]` |
| `EVENTE11` | weekday `0`, `6/16..9/15`, `9:01..20:00` | `[202]` in `61..80` | `[393]` | `[120]`, `[124]`, `[1833]`, `[127]`, `[1905]`, `[1792]` |

Read, not yet measured. I10 is the I family's Saturday late afternoon
with the first two-window date `or` seen in a guard here, and its callee
writes its own gate `[1333]` at every door while resetting the I word
hard - to `10` on answer `1`, up three on answer `2`, to `25` on answer
`3`. C06 is the C family's spring weekday daytime with the C word below
`71` and no prerequisite flag but `[396]`; E11 the E family's summer
weekday with the E word in `61..80` and `[393]`. Both nested callees
write their own gates (`[1762]` at `5212`, `[1905]` in every answer) and
move their words by the same pattern: down three on answer `1`, down two
on answer `2`, up one on answer `3`.

## Measured, not yet declared: two instrument limits

(The second limit is lifted: C06 and E11 are declared since
2026-09-14 on the v10 caller-menu-loop resume, two sections below. The
first is lifted too: I10's answers 1 and 3 are declared since 2026-09-14,
Core 0.316.0 reading the `command_1b` record as `System.function[24]`.)

Measured 2026-09-12. Only I10's answer 2 is declared (next section), for
the two reasons below. The measurements are kept under `analysis/15c_*`.

**EVENTI10.** Twenty-five witnesses pin the guard, including both date
windows at every edge and the gap's `673` arm (`date > 6/15` writes
`[2612]`, which the callee reads at `343` and `2389` to choose its
opening). The callee's contract at `5582` offers three answers. Answer
`2` completes: 12 caller messages, the callee through `I_PIC.MES` to the
door `12345..12358 -> MACHI.MES`, writing `[1333]` (its own gate, a
conjunct of the guard), `[1336]`, `[138]` by one, the I word
`banked_u16[203]` up three, `banked_u16[242] = 15` and `[286]`; the guard
rejects afterwards and a direct reentry returns at `16388` with 0
messages; segmented and unbroken runs agree and every variant is
recorded. Answers `1` and `3` do not complete under the instrument: at
`6567` (answer `1`) the callee reaches a `command_1b` record that the
probe follows back to offset `13`, the script's start, so the body
replays from the top - 28 distinct lines repeated - until the probe's
512-segment cap stops it with no door reached and `[1333]` never
written. What `0x1B` means natively is not established; until it is,
answers `1` and `3` cannot be declared, and the fourth body at `15892`
is not reachable from the question at all.

**EVENTC06 and EVENTE11.** Both guards are pinned (twenty-one witnesses
each), both callees' contracts build (`2210` and `1800`, three answers
each), and every answer runs to the callee's return: C06 after 35, 35 or
31 messages, moving the C word `banked_u16[206]` from `60` to `57`, `58`
or `61`, writing `[1762]` (its own gate) at `5212`, `[3218]` and, on the
`banked_u16[203]` in `41..80` arm, `[138]`; E11 after 42, 42 or 38
messages, moving the E word `[202]` from `70` to `67`, `68` or `71` and
writing `[1905]` (its own gate), `[5065]` and `[3466]`. Both guards
reject on the resumed state and both direct reentries return through the
done-gate with 0 messages. The caller's resume is the problem: after
C06's return it writes `[350]` at `5165` and immediately transfers to
`30516`; after E11's it writes `[126]`, dispatches `E_PIC.MES` at `7644`,
runs its `[2847]` arm and date ladder, writes `[350]` at `8582` and
transfers from `8593` to the same `30516`. That block is the floor's own
menu: routines `34`, `36`, `39`, a self-referencing branch at `30851`
(`next_offset == offset`, an input wait) and a seven-segment cycle
through `35759`, `30869`, `34622`, `34869`, `35114`, `35649`, `35731`
that the probe repeats until its cap. The static guards at `5181..`
and `8598..` that the inventory lists after the calls are never reached
on these paths. No root handoff lies on the path (the two `MACHI.MES`
handoffs at `32098` and `32620` are past the loop) and the only nested
dispatch on E11's path, `E_PIC.MES`, is also needed by its gap, so
neither `natural_handoff` nor `stop_before_unprovided_dependency`
describes this resume, and 15C has no routine-40 record for the v8
policy. A resume that ends in the caller's interactive loop has no
boundary the current schemas can name.

## Declared under the 2026-09-12 ruling

The owner ruled on 2026-09-12 to declare what the current schemas can
name and to leave the rest deliberately unqualified, as 01M's H07, M06
and M09 were left by the `TRAIN.MES:861` ruling, rather than adopt a new
caller-continuation boundary policy now.

I10's answer `2` is declared as `15c_i10_v6.json` with the callee's
contract, `I_PIC` and `MACHI` among the members, one root-replacement
route `15c-i10-result2` with 16 variants each naming answer `2`,
`post_guard_expected` 0, the reentry the done-gate return. Audit
accepted; `original event analysis 15C I10` passes 494 checks; a wrong
callee message count and the door shifted one byte are rejected. Its
answers `1` and `3`, and `EVENTC06` and `EVENTE11` whole, stay
`structural_confirmed_semantics_unresolved` with their measurements kept
under `analysis/15c_*`: the first two wait on the native meaning of
`command_1b`, the last two on a boundary policy for a resume that ends
in the caller's menu loop, which is recorded as its own open item
(both resolved and all five declared on 2026-09-14, next section).

## Declared under the 2026-09-14 ruling: the caller's own loop

The owner ruled on 2026-09-14 for the boundary policy the 2026-09-12
section could not name: a resume that ends in the caller's own
interactive loop. Core 0.317.0's route probe proves such a loop instead
of spending its segment budget in it - a continuation (the boundary
record, the stored values, the RNG position, the argument slots and the
persistent expression stack) seen twice repeats forever, so the walk
stops at that continuation's first occurrence and reports the cycle -
and `kakyu_event_analysis_group/v10` declares it as `caller_menu_loop`
with the head record, the period, the cycle's records and the messages
one period emits ([content tools](../tech/content_tools.md)).

Both callees were re-measured with the toolchain on 2026-09-14
(`analysis/15c_c06_spec.json`, `analysis/15c_e11_spec.json`), one
route per answer. The caller's resume is the same in all six routes:
after the callee's return it writes `[350]` and runs into the shop's
menu at `30516`, and the probe proves the loop at `35759`, the
`call_sub(34)` record, with a period of seven segments - `35759`,
`30869` and `34622` (shared-routine calls), `34866` (message wait),
`35111` (message wait), `35649` (shared-routine call), `35728` (message
wait) - and 9 messages per period. That is the block the
2026-09-12 measurement had recorded as the seven-segment cycle; the
head is the first record whose continuation recurs, one iteration after
the resume enters the block, so the resume's message count includes
the block's first pass.

**EVENTC06** - `15c_c06_v10.json`, routes `15c-c06-result1` (14
variants), `-result2` and `-result3` (one each), 1140 checks. The
callee returns at `5357..5358` after 35, 35 or 31 messages, moving the
C word `banked_u16[206]` by -3, -2 or +1 and writing its own gate
`[1762]`, `[3218]` and, on the `banked_u16[203]` in `41..80` arm,
`[138]`; the resume emits 33 messages to the loop head, writes `[350]`
and eighteen further cells constant across every variant, the guard
rejects on the resumed state (`post_guard_expected` 0), and a direct
reentry returns through the done-gate at `5388..5389` with 0 messages.
The three `word206-*-direct` rows (the callee's own reads of the C word
at `3068` and `4013`) are measured and listed under `unresolved`, not
declared, as the toolchain's direct variants always are.

**EVENTE11** - `15c_e11_v10.json`, routes `15c-e11-result1` (11
variants), `-result2` and `-result3` (one each), 893 checks. The
callee returns at `6366..6367` after 42, 42 or 38 messages, moving the
E word `banked_u16[202]` by -3, -2 or +1 and writing its own gate
`[1905]`, `[5065]` and `[3466]`; the resume writes `[126]`, dispatches
`E_PIC.MES` at `7644` (a member), runs its `[2847]` arm and date ladder,
writes `[350]` at `8582` and enters the same loop, 48
messages to the same head; the guard rejects on the resumed state and
the direct reentry returns through the done-gate with 0 messages.

Audit accepted for both; `original event analysis 15C C06` and `15C
E11` pass; a wrong callee message count, the return record shifted one
byte and the loop head shifted one byte are each rejected.

**EVENTI10, all three answers.** The `command_1b` record at `6567` that
stopped answers `1` and `3` on 2026-09-12 is, under Core 0.316.0,
`System.function[24](4,0,"bll.mmo",0,0)` at `6566..6591` - the form 44M
J11 was qualified through - and the walk continues past it. Rebuilt with
the toolchain on 2026-09-14 (`analysis/15c_i10_spec.json`),
`15c_i10_v6.json` now declares three root-replacement routes by answer:
`15c-i10-result1` (14 variants) leaves by `8506..8519 -> MACHI.MES`
after 58 messages, setting the I word `banked_u16[203]` to `10`;
`-result2` by `12345..12358` after 80, the word up `3`; `-result3` by
`15874..15887` after 63, the word set to `25`; every answer writes the
gate `[1333]` and stamps `15`, the guard rejects afterwards and a direct
reentry returns through the done-gate at `16388` with 0 messages. The
fourth door `16370..16383` (stamp `18`, the word down `2`) is reached by
no declared row. 580 checks; the 2026-09-12 profile with answer `2`
alone (494 checks) is superseded.

## Not measured here

What schedules `MACHI.MES:36671` into `15C.MES`; what sets `[396]` and
`[393]` and what moves the three affection words outside these callees;
what the three questions offer as native input; what `command_1b` does
natively at `EVENTI10.MES:6567` and its answer-`3` counterpart; what the
floor's menu block at `30516` does with input; and `MACHI.MES` past I10's
doors.
