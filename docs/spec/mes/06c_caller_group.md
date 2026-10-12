# 06C caller group

Inventoried on 2026-09-13 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`06C.MES` is a root the sixth-floor map hands off to (`06M.MES:58036`,
command `0x0E`), with two unresolved EVENT intro sites, both nested calls
(command `0x0F`) into callees that return: `EVENTL08`, whose callee asks
its own three-answer question and moves the L word by the answer, and
`EVENTJ18`, whose callee asks nothing. After either return the caller
closes the event's flags itself and transfers to its shared epilogue at
`38228`, which ends in the floor's own six-definition question at
`38612` - the routine-40 record shape 11M's `53145` has, where the v8
`def_selection_boundary` resume policy stops.

## The caller

| Property | `06C.MES` |
|---|---|
| framing-opaque bytes | **0 of 43,872** |
| instructions / branches / calls | 5,834 / 277 / 582 |
| address-table entries | 276 |
| EVENT intro sites | 2, for two targets |
| intros with a typed guard candidate | **both** |
| dispatch form | both nested calls whose callees return |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTL08.MES` is
one body behind its own `global_u8[2049]` gate, which it sets at `563`
before a word is spoken, with a question at `1898` (three definitions,
consumer the `state_u16[21]` chain at `1908`) and returns at `4784`,
`5007` and `5013`. `EVENTJ18.MES` is one body behind `[922]`, a flag it
never writes, with no question and returns at `2563`, `2802` and `2818`.
Neither callee dispatches another script.

## The two intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|
| `EVENTL08` | `6343..6359` | nested call | `4099..4200` | 5,014 | 12 | 51 |
| `EVENTJ18` | `13582..13598` | nested call | `12704..12802` | 2,819 | 11 | 32 |

## Two guards, both closed by the caller after the return

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---|---|---:|:-:|---:|---:|---:|
| `EVENTL08` | `4099..4200` | `7340` | 14 | **yes** | 2,143 | 289 | **0** | 1 (`L_PIC`) | 0 |
| `EVENTJ18` | `12704..12802` | `14320` | 15 | - | 780 | 102 | **0** | **0** | 0 |

L08's gap calls `L_PIC.MES` at `4560` on the way to the call; the
caller's `[350]` write at `4083` lies before the origin. After L08's
return the caller runs a date ladder and a `[2043]` arm, then writes
`[2042]`, `[2049]` and `[350]` at `7302..7324` - two conjuncts of the
guard that admitted it - and transfers at `7335` to `38228`. After J18's
return it runs a `[2847]` arm, the date ladder and an `[823]` arm, writes
`[922]`, `[350]` and `[854]` at `14282..14304` - `[922]` a conjunct of its
guard - and transfers at `14315` to the same `38228`.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`0` a weekday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM, and `banked_u16[209]`, `[211]`
the L and J families' affection words. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTL08` | weekday `0` (or `12/24`), `6/16..9/15`, `10:01..21:00` | `[209] > 35` | `[399]` | `[190]`, `[194]`, `[197]`, `[2042]`, `[2049]`, `[1966]`, `[1925]` |
| `EVENTJ18` | weekday `0`, any date, `18:01..21:59` | `[211] > 50` | `[802]`, `[401]` | `[210]`, `[212]`, `[215]`, `[217]`, `[214]`, `[923]`, `[922]`, `[812]`, `[784]` |

Read, not yet measured. L08 is the L family's summer weekday with the L
word above `35` and `[399]` set - the same prerequisite and clear set
05M's L06 reads, plus L06's own done flag `[2042]` - and the `12/24` arm
can never hold inside its date window; its callee sets `[2049]` early,
counts `[254]`, and moves the L word down two, up one or down three by
the answer behind `> 2` and `> 3` gates. J18 is the J family's weekday
evening on any date with the J word above `50`, `[802]` and `[401]` set
and the clear set 05M's J07 reads with `[923]` and `[922]` in place of
`[957]` and `[907]`; its callee reads `[854]`, `[823]` and `[926]` for its
arms, writes `[3033]` and `[3717]`, and touches no flag the guard reads.

## EVENTL08: the L family's summer day, the callee's own three answers, closed early by the callee and again by the caller

Measured 2026-09-13. `06C.MES:4099..4200` (false `7340`) wants a
weekday-`0` day (`10:01..21:00`, or `12/24` by an `or` arm the date
window `6/16..9/15` can never satisfy) with the L word `banked_u16[209]`
above `35`, `[399]` set, and `[190]`, `[194]`, `[197]`, `[2042]`, `[2049]`,
`[1966]`, `[1925]` clear; twenty-one witnesses pin every edge and flip
every flag, every rejection walking to the floor's own question at
`38612`. The caller's `[350]` write at `4083` lies before the origin; the
prefix calls `L_PIC.MES` at `4560` on the way to the nested call at
`6343..6359`. `EVENTL08.MES` counts `[254]` at `118`, sets its own gate
`[2049]` at `563` before a word is spoken, runs 16 messages to its
question at `1898` (three definitions, consumer the `state_u16[21]` chain
at `1908`), and returns at `5007..5008` after 36, 32 or 35 messages:
answer `1` moves the L word down two at `2699` behind a `> 2` gate and
answer `3` down three at `4385` behind a `> 3` gate - gates the guard's
`> 35` cannot fail, witnessed at `2` and `3` by direct probes where the
word goes to `0` - and answer `2` moves it up one at `3418`; every answer
writes `[3660]` and `[5279]` and the clock arm sets `state_u16[8]` to
`46` (`0` at 21:00). The caller then runs its date ladder and the
`[2043]` arm at `6538`, writes `[2042]`, `[2049]` again and `[350]` at
`7302..7324`, transfers to the floor's epilogue at `38228`, and stops 18
messages later before the floor's own six-definition question at `38612`
- the `def_selection_boundary` 11M's `53145` set the pattern for, whose
consumer the contract tool cannot name. The guard rejects on the resumed
state by `[2049]`, and a completed reentry counts `[254]` once more
before the done-gate at `234` returns it at `5013..5014` with **0
messages**. Segmented and unbroken runs agree under every answer.
`state_u16[8]` is rewritten at `271` before it is read and
`global_u8[4000]` reads `0` at the callee's entry whatever is seeded;
`[3006]` and `[2847]` flip one arm each; the stamp is not written.

Declared as `06c_l08_v8.json` with the callee's contract, `L_PIC` and
`MACHI` among the members, three caller-continuation routes by answer on
the `def_selection_boundary` resume with 16 variants in all, each
naming its answer, `post_guard_expected` 0, the reentry the done-gate
return with the counter's second step and the seeded-counter row
overriding it. Audit accepted; `original event analysis 06C L08` passes
567 checks; a wrong resume message count and the call record shifted
one byte are rejected.

## EVENTJ18: the J family's weekday evening on any date, a nested call with no question, closed by the caller

Measured 2026-09-13. `06C.MES:12704..12802` (false `14320`) wants a
weekday-`0` evening (`18:01..21:59`) on any date, the J word
`banked_u16[211]` above `50`, `[802]` and `[401]` set, and `[210]`,
`[212]`, `[215]`, `[217]`, `[214]`, `[923]`, `[922]`, `[812]`, `[784]`
clear; nineteen witnesses pin every edge and flip every flag, every
rejection ending at the next block's guard at `14320`. The prefix runs 16
messages, writing nothing, to the nested call at `13582..13598`.
`EVENTJ18.MES` asks nothing: behind its `[922]` gate at `219` it reads
`[854]` at `616` and `1467`, `[823]` and `[926]` at `2111`, `2225` and
`2361`, writes `[3033]`, `[3717]`, `[5336]` and `banked_u16[1] = 7`, and
returns at `2802..2803` after 27 messages (15 with `[854]` set). It
writes no flag its guard reads. The caller then runs the `[2847]` arm,
the date ladder and the `[823]` arm at `13907`, writes `[922]` - the
callee's own gate - `[350]` and `[854]` at `14282..14304`, transfers to
the floor's epilogue at `38228`, and stops 9 messages later (6 with
`[823]` set) before the floor's own six-definition question at `38612`,
the `def_selection_boundary` 11M's `53145` set the pattern for. The guard
rejects on the resumed state by `[922]`, and a completed reentry returns
through the done-gate at `2582` to `2802..2803` with **0 messages** and
no change. Segmented and unbroken runs agree. `state_u16[8]` is
rewritten at `256` before it is read and `global_u8[4000]` reads `0` at
the callee's entry whatever is seeded; the callee never touches the J
word or the stamp.

Declared as `06c_j18_v8.json` with no contract, `06M` and `MACHI` among
the members, two caller-continuation routes on the
`def_selection_boundary` resume with 13 variants in all - `06c-j18`
with the 9-message resume and `06c-j18-flag823` for the `[823]` rows
whose resume is 6, the shape 44C's M03 set - `post_guard_expected` 0,
the reentry the return record. Audit accepted; `original event
analysis 06C J18` passes 373 checks; a wrong resume message count and
the call record shifted one byte are rejected.

Every 06C intro is measured and declared: two sites, two targets, two
groups, five routes, no contract change - both on the v8 resume that
stops at the floor's own question, whose six-definition consumer the
contract tool cannot name. Read together, the sixth floor's two events
are the L and J families' visits the floor itself closes: L08's callee
shuts its gate before speaking and the caller shuts it again, J18's
callee leaves its gate to the caller entirely; neither writes the stamp.

## Not measured here

What schedules `06M.MES:58036` into `06C.MES`; what sets `[399]`, `[802]`
and `[401]` and moves the L and J words; what L08's question and the
epilogue's six-definition question offer as native input (L08's result
is supplied explicitly; the epilogue's question is not declared); and
the epilogue past `38612`.
