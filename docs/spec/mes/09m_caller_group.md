# 09M caller group

Inventoried on 2026-09-13 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`09M.MES` is a root the town map names once: `MACHI.MES:56863..56874`
is a typed command-`0x0E` handoff naming it. The earlier `57907` was an
entry-file offset, before subtracting MACHI's 1,044-byte container header;
using it as a code coordinate falsely suggested a decoder error. The
source audit confirms the complete dispatch record at the corrected coordinate,
not a record embedded inside a state write. Its two unresolved EVENT intro sites are both root
handoffs (command `0x0E`) whose callees never return: `EVENTL11`, reached
only through the caller's own two-answer question at `17616` (answer `1`
hands the root to the callee, answer `2` is the caller's own decline arm
that closes the callee's gate itself), and `EVENTM20`, whose callee asks
its own two-answer question at `9634` and leaves by `44C.MES` or
`MACHI.MES` - or, by one arm, replays its question.

## The caller

| Property | `09M.MES` |
|---|---|
| framing-opaque bytes | **0 of 43,594** |
| instructions / branches / calls | 5,502 / 416 / 749 |
| address-table entries | 144 |
| EVENT intro sites | 2, for two targets |
| intros with a typed guard candidate | **both** |
| dispatch form | both root handoffs; L11 behind the caller's question, M20 with the callee's |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTL11.MES` is
one body behind its own `global_u8[2068]` gate at `219` with one door
(`6390..6403 -> MACHI.MES`) and no question; it sets `[2068]` at `6354`
just before the door. `EVENTM20.MES` is one body behind `[2517]`, which
it sets at `9484` before its question at `9634` (two definitions,
consumer the `state_u16[21]` chain at `9649`): answer `1` leaves by
`9918..9929 -> 44C.MES` after writing `[372]` - or, when a 12-conjunct
summer guard at `9774` holds, by `9867..9883 -> EVENTL10.MES`; answer `2`
leaves by `10078..10091 -> MACHI.MES` when `[532]` is clear and replays
the question from `9510` when it is set.

## The two intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|
| `EVENTL11` | `18125..18141` | root handoff behind the caller's question | `15794..15888` | 6,434 | 18 | 66 |
| `EVENTM20` | `11919..11935` | root handoff, callee asks | `10192..10236` | 10,215 | 34 | 110 |

## Two guards, one closed by the caller before its own question

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---|---|---:|:-:|---:|---:|---:|
| `EVENTL11` | `15794..15888` | `20190` | 14 | - | 2,237 | 272 | 3 | 1 (`L_PIC`) | 1 |
| `EVENTM20` | `10192..10236` | `11950` | 6 | - | 1,683 | 240 | 3 | 1 (`M_PIC`) | 0 |

L11's gap writes `[2042] = 1` at `15898` - a clear conjunct of the guard
that admitted it - and `[196]`, calls `L_PIC.MES`, then branches on
`[2062] != 0` at `16999` (when clear, the caller writes `[2068]` and
`[350]` at `20163..20174` and transfers to its epilogue without asking),
asks its question at `17616`, and by answer `1` moves the L word up one
at `18105` and hands the root off; answer `2` runs the caller's own
decline arm (`[2847]`, the date ladder, the L word down two behind a
`> 2` gate at `19302`, `[2068] = 1` at `19357`) and transfers to the
epilogue at `42698`; neither answer replays. M20's gap calls
`M_PIC.MES` at `10257` and selects a message by a clock ladder at
`10444..10750` around 15:00 before the handoff. The caller's epilogue at
`42698` ends in a two-definition question at `42928`, the routine-40
shape 06C's `38612` has.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`0` a weekday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM, and `banked_u16[209]` the L
family's affection word. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTL11` | weekday `0`, `9/25..11/15`, `10:01..16:30` | `[209] > 50` | `[399]` | `[190]`, `[194]`, `[197]`, `[2042]`, `[2068]`, `[1966]`, `[1925]` |
| `EVENTM20` | `12/24`, `14:46..15:59` | - | `[150]`, `[2516]` | `[2517]` |

Read, not yet measured. L11 is the L family's autumn weekday with the L
word above `50` and `[399]` set - the prerequisite and clear set 05M's
L06 and 06C's L08 read, with L08's own done flag `[2049]` replaced by
`[2068]`; the caller closes `[2042]` before asking and the callee closes
`[2068]` at its door. M20 is Christmas Eve afternoon with `[150]` and
`[2516]` set; its callee closes `[2517]` before asking, sets `[372]` -
the prerequisite 44C's I24 and L25 need - on the `44C` door, and its
`EVENTL10` door sits behind a summer date window the caller's `12/24`
guard can never satisfy.

## EVENTL11: the L family's autumn weekday, behind the caller's own question

Measured 2026-09-13. `09M.MES:15794..15888` (false `20190`) wants a
weekday-`0` day (`10:01..16:30`) from `9/25` to `11/15`, the L word
`banked_u16[209]` above `50`, `[399]` set, and `[190]`, `[194]`, `[197]`,
`[2042]`, `[2068]`, `[1966]`, `[1925]` clear; twenty-one witnesses pin
every edge and flip every flag, every rejection walking on to the
caller's epilogue question at `42928`. The caller closes `[2042]` - a
clear conjunct of the guard that admitted it - at `15898` and writes
`[196]` before calling `L_PIC.MES`, then, when `[2062]` is set, asks its
own question at `17616` after 24 messages (two definitions, consumer the
`state_u16[21]` chain at `17631`); when `[2062]` is clear it skips the
question, closes `[2068]` itself at `20163` and walks to the epilogue.
Answer `1` moves the L word up one at `18105` and hands the root to
`EVENTL11.MES` at `18125..18141`; answer `2` is the caller's own decline
arm - the word down two behind a `> 2` gate at `19302` (witnessed at `2`
by a direct probe, where it goes to `0`), `[2068]` closed at `19357`,
`[350]` set, the walk ending before the epilogue's question - and no
answer replays. `EVENTL11.MES` runs 89 messages to its one door
`6390..6403 -> MACHI.MES`, calling `L_PIC.MES` on the way, and just
before the door moves the L word up one more at `6334`, sets its own gate
`[2068]` at `6354`, stamps `banked_u16[242] = 9` at `6365` and writes
`[286]`; it also writes `[2069]`, `[3664]`, `[5283]` and the clock arm's
`[3288]`. The guard rejects on the post-replacement state by the caller's
`[2042]` before the callee's `[2068]` is reached, and a direct reentry
returns through the done-gate at `219` to `6433..6434` with **0
messages**. Segmented and unbroken runs agree. `state_u16[8]` is
rewritten at `359` and `5771` before each ladder and `global_u8[4000]`
reads `0` at the callee's entry whatever is seeded; `[3006]` and
`[2847]` flip presentation arms.

Declared as `09m_l11_v6.json` with the caller's contract - owner
`09M.MES`, boundary `17616` - `L_PIC` and `MACHI` among the members, one
root-replacement route `09m-l11` for answer `1` with 13 variants,
each naming the answer, `post_guard_expected` 0, the reentry the return
record; answer `2`, the caller's decline, is measured and not declared.
Audit accepted; `original event analysis 09M L11` passes 318 checks; a
wrong callee message count and the door shifted one byte are rejected.

## EVENTM20: Christmas Eve afternoon, the callee's two answers to 44C or the town

Measured 2026-09-13. `09M.MES:10192..10236` (false `11950`) wants
`12/24` between `14:46` and `15:59` with `[150]` and `[2516]` set and
`[2517]` clear - no weekday, no affection word; ten witnesses pin every
edge and flip every flag, every rejection walking on to the caller's
next question. The prefix calls `M_PIC.MES`, selects a message by the
clock at `10444..10750`, writes `[156] = 3` and runs 25 messages to the
root handoff at `11919..11935`. `EVENTM20.MES` runs 138 messages to its
question at `9634` (two definitions, consumer the `state_u16[21]` chain
at `9649`), having set its own gate `[2517]` at `9484` and `[3565]` at
`9463` on the way, called `M_PIC.MES` twice and filled `banked_u16[5..16]`
from `[168..]` at `6669`: answer `1` leaves by `9918..9929 -> 44C.MES`
after writing `[372]` - the prerequisite 44C's I24 and L25 read - and the
stamp `banked_u16[242] = 0`; answer `2` leaves by `10078..10091 ->
MACHI.MES` with `[286]` and the stamp `44` when `[532]` is clear, and
replays its question from `9510` when `[532]` is set. Both doors close
141 messages after the callee's entry. Answer `1`'s other door,
`9867..9883 -> EVENTL10.MES`, sits behind a 12-conjunct summer guard at
`9774` (`6/16..9/15`, `20:59..22:01`, the L word above `35`, `[399]` set)
that the caller's `12/24` guard can never satisfy: with only the date
moved it still fails on the clock, the L word and `[399]`. The guard
rejects on both post-replacement states by `[2517]`, and a direct
reentry returns through the done-gate at `229` to `10214..10215` with
**0 messages**. Segmented and unbroken runs agree under both answers.
`state_u16[8]` is rewritten at `518` before it is read and
`global_u8[4000]` reads `0` at the callee's entry whatever is seeded;
the clock `state_u16[19]` is recomputed mid-run by `DEF_MAIN.MES`'s
definition 11 from `state_u16[1] * 100 + state_u16[0]`, so the callee's
second clock ladder at `7666` never sees the seeded clock; `[3006]` and
`[2847]` flip presentation arms.

Declared as `09m_m20_v6.json` with the callee's contract, `M_PIC`,
`44C`, `MACHI` and `EVENTL10` among the members, two root-replacement
routes by answer with 11 variants in all, each naming its answer,
`post_guard_expected` 0, the reentry the return record; the `[532]`
replay and the `EVENTL10` door are not declared. Audit accepted;
`original event analysis 09M M20` passes 433 checks; a wrong callee
message count and the town door shifted one byte are rejected.

Every 09M intro is measured and declared: two sites, two targets, two
groups, three routes, no contract change - L11 on the caller's own
question, M20 on the callee's. Read together, the ninth floor's two
events are the floor asking first and the guest asking second: L11's
caller closes one conjunct and offers the visit before the callee sets
its own gate and stamps `9`; M20's callee closes its gate, asks, and
sends the player on to 44C with the flag that floor's winter events
need, or back to the town with the stamp `44`.

## Not measured here

What schedules `MACHI.MES:56863` into `09M.MES`; what sets `[399]`, `[150]` and `[2516]` and moves
the L word; what the caller's question at `17616`, the callee's at
`9634` and the epilogue's at `42928` offer as native input (the first
two results are supplied explicitly; the epilogue's question is not
declared); and `MACHI.MES`, `44C.MES` and `EVENTL10.MES` past the doors.
