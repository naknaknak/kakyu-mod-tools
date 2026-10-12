# 05M caller group

Inventoried on 2026-09-13 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`05M.MES` is a root the town map hands off to (`MACHI.MES:52622`, command
`0x0E`, its only literal caller), the first of the callers with two
unresolved EVENT intro sites: `EVENTJ07` as a root handoff into a callee
that hands the root back to `MACHI.MES`, and `EVENTL06` as a nested call
(command `0x0F`) into a callee that never returns - it asks two questions
and then hands the root on itself, to `05C.MES` or to `MACHI.MES` by the
second answer. That second shape is new to the measured corpus: a nested
call that ends as a root replacement, which the 2026-09-13 revision of
the v6 schema names `nested_root_handoff`. The instrument is the one that
opened the earlier groups; run first on `01M.MES`, it reproduces the
44C-era control exactly before it is run here.

## The caller

| Property | `05M.MES` |
|---|---|
| framing-opaque bytes | **0 of 23,756** |
| instructions / branches / calls | 2,987 / 276 / 393 |
| address-table entries | 84 |
| EVENT intro sites | 2, for two targets |
| intros with a typed guard candidate | **both** |
| dispatch form | J07 a root handoff, L06 a nested call whose callee replaces the root |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTJ07.MES` is
one body behind its own `global_u8[907]` gate with one door (`2397..2410
-> MACHI.MES`) and no question. `EVENTL06.MES` is one body behind
`[2046]`, which it sets at `741` before its first question at `3953`
(three answers, each through `L_PIC.MES`), and a second question at
`13455` whose answers leave by two doors: `13753..13764 -> 05C.MES` and
`13941..13954 -> MACHI.MES`; the done-gate at `219` lands just before
the second question. No callee dispatches `TRAIN.MES`.

## The two intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---:|---:|
| `EVENTJ07` | `1391..1407` | root handoff | `1112..1211` | 2,441 | 10 | 21 |
| `EVENTL06` | `4706..4722` | nested call, root replaced by the callee | `3943..4044` | 13,960 | 66 | 127 |

## Two guards, one marking its own clear flag

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---|---:|:-:|---:|---:|---:|---:|
| `EVENTJ07` | `1112..1211` | `1417` | 15 | - | 180 | 32 | **0** | **0** | 0 |
| `EVENTL06` | `3943..4044` | `4737` | 14 | **yes** | 662 | 99 | **0** | **0** | 0 |

J07's gap writes `[915] = 1` and `[210] = 1` before the handoff - `[210]`
is a clear conjunct of the guard that admitted it, closed by the caller
as 30C's site A closes `[1459]`. The caller writes `[476]` and `[350]`
just before the two guards, outside the origins, and after each site a
`continuation_transfer` leads to the caller's epilogue at `23033` -
unreachable after L06, whose callee's handoff discards the caller's
frame.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`0` a weekday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM, and `banked_u16[211]`, `[209]`
the J and L families' affection words. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTJ07` | weekday `0`, `date < 9/16`, `18:01..21:59` | `[211] > 50` | `[401]` | `[210]`, `[212]`, `[215]`, `[217]`, `[214]`, `[957]`, `[907]`, `[812]`, `[784]` |
| `EVENTL06` | weekday `0` (or `12/24`), `4/01..6/15`, `17:31..21:00` | `[209] > 35` | `[399]` | `[190]`, `[194]`, `[197]`, `[2042]`, `[2046]`, `[1966]`, `[1925]` |

Read, not yet measured. J07 is the J family's weekday evening before
mid-September with the J word above `50`, `[401]` set and the same clear
set 07M's J19 and 11M's J01 read; its callee closes its own `[907]`,
stamps `banked_u16[242] = 7` and counts `[138]` when the I word is in
`41..80`. L06 is the L family's spring weekday evening with the L word
above `35` and `[399]` set - the `or` arm for `12/24` can never hold
inside its own date window; its callee sets `[2046]` early and `[2042]`
before its second question, moves the L word up one on every first
answer, and leaves by `05C.MES` (stamp `0`) or `MACHI.MES` (stamp `5`).

## EVENTJ07: the J family's weekday evening before autumn, closed by the caller and the callee both

Measured 2026-09-13. `05M.MES:1112..1211` (false `1417`) wants a
weekday-`0` evening (`18:01..21:59`) before `9/16`, the J word
`banked_u16[211]` above `50`, `[401]` set, and `[210]`, `[212]`, `[215]`,
`[217]`, `[214]`, `[957]`, `[907]`, `[812]`, `[784]` clear; twenty-one
witnesses pin every edge and flip every flag. The caller's `[476]` write
at `1096` lies before the origin; the prefix runs 6 messages, writing
`[915] = 1` and `[210] = 1` - a clear conjunct of the guard that admitted
it - to the root handoff at `1391..1407`. `EVENTJ07.MES` first reads the
I word `[203]` in `41..80` at `118` to count `[138]`, then runs 18
messages to its one door `2397..2410 -> MACHI.MES` (24 when `[824]` is
set and the `1960` arm writes `[927]`), writing `[5335]`, `[3716]`, `[854]`,
`[286]`, the stamp `banked_u16[242] = 7` and, at `2310`, its done flag
`[907]`, a conjunct of the guard. The guard rejects on the
post-replacement state by both hands, and a direct reentry returns
through the done-gate at `2440..2441` with **0 messages** - but not before
the counter at `139` runs again, so `[138]` reads `2` after the reentry
whenever the I word is in `41..80` and is untouched outside it. Segmented
and unbroken runs agree. `state_u16[8]` is rewritten at `411` before it is
read and `global_u8[4000]` reads `0` at the callee's entry whatever is
seeded; `[3006]` flips two arms; the callee touches neither affection
word.

Declared as `05m_j07_v6.json` with no contract and `MACHI` among the
members, one root-replacement route `05m-j07` with 15 variants,
`post_guard_expected` 0, the reentry the return record with the counter's
second step and the two out-of-window rows overriding it. Audit accepted;
`original event analysis 05M J07` passes 425 checks; a wrong callee
message count and the door shifted one byte are rejected.

## EVENTL06: the L family's spring evening, a nested call that never returns, two questions to two doors

Measured 2026-09-13. `05M.MES:3943..4044` (false `4737`) wants a
weekday-`0` evening (`17:31..21:00`, or `12/24` by an `or` arm the date
window `4/01..6/15` can never satisfy), the L word `banked_u16[209]`
above `35`, `[399]` set, and `[190]`, `[194]`, `[197]`, `[2042]`, `[2046]`,
`[1966]`, `[1925]` clear; twenty-one witnesses pin every edge and flip
every flag, every rejection walking to the caller's own handoff. The
caller's `[350]` write at `3927` lies before the origin; the prefix runs
15 messages, writing nothing, to the **nested call** at `4706..4722`
(command `0x0F`) - and the caller's continuation at `4732` is never
reached, because `EVENTL06.MES` hands the root on itself. It sets its own
gate `[2046]` at `741` before a word is spoken, asks its first question at
`3953` (three definitions, consumer the `state_u16[21]` chain at `3963`),
each answer walking through `L_PIC.MES` and moving the L word up one at
`5698`, `9047` or `12428` - answers `2` and `3` also set `[2047]` to `1` or
`2` and count `[264]` and `[3002]` - then writes `[2042]` at `13321` and
`[2046]` again at `13332` before its second question at `13455` (two
definitions, consumer the chain at `13470`), and by that answer leaves
either by `13753..13764 -> 05C.MES` with the stamp `banked_u16[242] = 0`
after 77, 91 or 91 messages, or by `13941..13954 -> MACHI.MES` with the
stamp `5` and `[286]` after 71, 85 or 85; every run writes `[196]`,
`[3657]`, `[4090]`, `[4091]`, `[5276]`, `banked_u16[1] = 7` and the clock
ladder's `[3287]`. The guard rejects on every post-replacement state by
the callee's own `[2042]` and `[2046]`, and a direct reentry enters at the
done-gate `219`, jumps to `13343`, and asks only the second question
again - the `05C` door after 9 messages, the `MACHI` door after 3 - moving
no profile cell. With `[477]` set the first visit itself runs the shorter
arm (71 messages to `05C`, reentry 3). Segmented and unbroken runs agree
under every answer pair. `state_u16[8]` is rewritten at `359` and set to
`1` at `12573` whatever is seeded; `global_u8[4000]` reads `0` at the
callee's entry; the seeded `banked_u16[2]` bit never reaches the `[5]`
arms; `[3006]` flips a presentation arm.

Declared as `05m_l06_v6.json` - the first `nested_root_handoff` profile
under the 2026-09-13 revision: a command-`0x0F` caller record whose
callee replaces the root - with both of the callee's contracts, `L_PIC`,
`05C` and `MACHI` among the members, two root-replacement routes by the
second answer with 34 variants in all, each naming both answers,
`post_guard_expected` 0, the reentry the same door again with its
measured count and the `[477]` row overriding it. Audit accepted;
`original event analysis 05M L06` passes 1086 checks; a wrong callee
message count is rejected, and the audit rejects the caller record
re-typed as command `0x0E` and the outcome re-typed as a plain
`root_handoff`.

Every 05M intro is measured and declared: two sites, two targets, two
groups, three routes, and the first profile under the `nested_root_handoff`
revision. Read together, the fifth floor's evenings are two families'
turns: J07 the J family's weekday evening the caller and the callee both
close, stamping `7`; L06 the L family's spring evening that leaves the
floor by one of two doors, `05C` stamped `0` or the town stamped `5`,
with the L word one higher either way.

## Not measured here

What schedules `MACHI.MES:52622` into `05M.MES`; what sets `[401]` and
`[399]` and moves the J and L words; what L06's two questions offer as
native input (their results are supplied explicitly); and `05C.MES` and
`MACHI.MES` past the doors.
