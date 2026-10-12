# 23M caller group

Inventoried on 2026-09-12 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`23M.MES` is a map root no strictly decoded dispatch names: the one record
that names it is a root handoff inside `GROUND.MES`'s opaque tail
(`66682..66693`, command `0x0E`), which is why the entry has no row of its
own in the route classification. It is the caller with the most unresolved
EVENT intro sites left after 17M: five sites for five targets, every one a
root handoff, every callee handing the root back to `GROUND.MES`. The
instrument is the one that opened the earlier groups; run first on
`01M.MES`, it reproduces the 44C-era control exactly before it is run here.

## The caller

| Property | `23M.MES` |
|---|---|
| framing-opaque bytes | **0 of 30,415** |
| instructions / branches / calls | 3,982 / 174 / 446 |
| address-table entries | 172 |
| EVENT intro sites | 5, for five targets |
| intros with a typed guard candidate | **all 5** |
| dispatch form | **all five root handoffs** |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. All five callees end
by handing the root to `GROUND.MES` - `EVENTC02.MES` at `3280..3294`,
`EVENTE01.MES` at `4821..4835`, `EVENTC05.MES` at `3118..3132`,
`EVENTC17.MES` at `1816..1830`, `EVENTE03.MES` at `4226..4240` - and two
carry a picture script as a second static dependency, `E_PIC.MES` for C02
and `P_PIC.MES` for E03. No callee dispatches `TRAIN.MES`.

## The five intros

| Intro | Site | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---:|---:|---:|
| `EVENTC02` | `3616..3632` | `3231..3331` | 3,300 | 20 | 27 |
| `EVENTE01` | `3961..3977` | `3642..3722` | 4,866 | 23 | 45 |
| `EVENTC05` | `4230..4246` | `3987..4081` | 3,163 | 19 | 20 |
| `EVENTC17` | `11315..11331` | `11064..11164` | 1,861 | 13 | 18 |
| `EVENTE03` | `11569..11585` | `11341..11415` | 4,271 | 20 | 34 |

## Two ladders, five clean gaps

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---:|---:|:-:|---:|---:|---:|---:|---:|
| `EVENTC02` | `3231..3331` | `3642` | 15 | - | 285 | 57 | **0** | **0** | 0 |
| `EVENTE01` | `3642..3722` | `3987` | 12 | - | 239 | 44 | **0** | **0** | 0 |
| `EVENTC05` | `3987..4081` | `4256` | 14 | - | 149 | 29 | **0** | **0** | 0 |
| `EVENTC17` | `11064..11164` | `11341` | 15 | - | 151 | 29 | **0** | **0** | 0 |
| `EVENTE03` | `11341..11415` | `11595` | 11 | - | 154 | 30 | **0** | **0** | 0 |

Every gap is clean, and the guards chain by their false edges into two
ladders: C02's false edge is E01's guard and E01's is C05's, so the three
spring intros are tried in that order; C17's false edge is E03's guard.
Nothing enters any gap from outside, and no guard uses `or`.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`6` is Saturday), the date `state_u16[7]` as
MMDD, the clock `state_u16[19]` as HHMM, and `banked_u16[206]` the
affection word 44M's `EVENTC18` needs above `80`. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTC02` | Saturday, `4/00 < date < 6/16`, `14:29 < clock < 17:30` | `[206] < 71` | `[396]` | `[127]`, `[160]`, `[164]`, `[167]`, `[1653]`, `[1694]`, `[1755]`, `[1756]` |
| `EVENTE01` | Saturday, `4/00 < date < 6/16`, `14:30 < clock < 16:30` | - | `[393]` | `[120]`, `[127]`, `[1792]`, `[1865]`, `[1889]`, `[1892]` |
| `EVENTC05` | Saturday, `4/00 < date < 6/16`, `14:29 < clock < 16:30` | `[206] < 71` | `[396]` | `[160]`, `[164]`, `[167]`, `[1653]`, `[1694]`, `[1755]`, `[1760]` |
| `EVENTC17` | Saturday, `11/15 < date < 15/11`, `14:29 < clock < 17:30` | `[206] > 70` | `[396]`, `[1778]` | `[160]`, `[164]`, `[167]`, `[1653]`, `[1694]`, `[1755]`, `[1782]` |
| `EVENTE03` | Saturday, `4/00 < date < 6/16`, `14:30 < clock < 16:30` | - | `[393]` | `[120]`, `[1792]`, `[1865]`, `[1891]`, `[1892]` |

Read, not yet measured. Every one of the five is a Saturday afternoon, and
four are spring afternoons on the same dates; the E pair and the C pair
inside the spring ladder overlap by the minute (`14:31..16:29` inside
`14:30..17:29`), so which of C02, E01 and C05 fires on a given Saturday is
decided by the flags and the affection word, in ladder order. The three C
guards share 17M `EVENTC10`'s prerequisite `[396]` and its clear flags
`[160]`, `[164]`, `[167]`, `[1694]`, `[1755]`, and 44M `EVENTC18`'s
`[1653]`; each adds one flag of its own - `[1756]`, `[1760]`, `[1782]` -
and C17 also requires `[1778]`. `[1755]` is the flag C10's resume sets on
`8/25`, so the spring C events precede C10 and the November C17 lies on a
branch where C10 did not run. The affection word splits the family:
below `71` admits C02 and C05, above `70` admits C17, and C18 wants above
`80`. The two E guards share `[393]` and the clear flags `[120]`,
`[1865]`, `[1892]`, `[1792]`, each adding one - `[1889]`, `[1891]` - with
`[127]` shared between C02 and E01 only.

## EVENTC02 and EVENTC05: the spring ladder's two C rungs

Measured 2026-09-12. `EVENTC02`'s guard `3231..3331` (false `3642`, E01's
guard) needs Saturday, `4/01..6/15`, `14:30..17:29`, the affection word
`banked_u16[206]` below `71`, `global_u8[396]` set and `[127]`, `[160]`,
`[164]`, `[167]`, `[1653]`, `[1694]`, `[1755]`, `[1756]` clear; twenty-one
witnesses pin every edge and flip every flag. The prefix is 12 messages
through 57 records with no branch, and the dispatch at `3616..3632` is a
root handoff. `EVENTC02.MES` runs 38 messages from `0` through a silent
`E_PIC.MES` to its handoff `3280..3294 -> GROUND.MES`, writing
`banked_u16[1] = 7`, `global_u8[126] = 6`, `[286]`, `[3005]`, `[3215]`,
`[3569]`, `[5181]`, `state_u16[8] = 46`, the map word `banked_u16[242] =
23`, and at `3233..3250` two of its own guard's flags, `[1756] = 1` - its
done flag - and `[1755] = 1`. `EVENTC05`'s guard `3987..4081` (false
`4256`) is the same Saturday afternoon until `16:29` with `[1760]` in place
of `[1756]` and without `[127]`; twenty witnesses. Its prefix is 6 messages
through 29 records, the handoff at `4230..4246`, and the callee runs 24
messages to `3118..3132 -> GROUND.MES` writing `[264]`, `[286]`, `[3217]`,
`[3572]`, `[5184]`, the map word, `[1760]` and `[1755]` at `3056..3073`.
Both callees are A10's shape: completion callee-owned through the done
flag, the guard rejecting after the replacement, a direct reentry sent by
the gate at `224` to the final return (`3299..3300`, `3162..3163`) with
**0 messages**; `global_u8[4000]` a dead input and `state_u16[8]` cleared
at `261` before its own ladder reads it and left at `46` by the afternoon
arm or `0` from `16:00`; the clock ladders leaving `[3215]` / `[3217]` at
`2` from `16:00`;
`global_u8[3006]` and `[2847]` flipping presentation arms without moving
the terminal; segmented and unbroken runs agreeing (50 and 30 messages).
When either guard rejects, the caller's walk falls down the ladder and,
with every rung refusing, out through `23M.MES:30385..30399 -> GROUND.MES`.

`[1755]` is the flag that ties the C family together: C02 and C05 each set
it, every C guard on this map and 17M's C10 require it clear, and C10's own
resume sets it too. Whichever C event fires first on a Saturday afternoon
closes the others until something clears it, and that something is not on
this map.

Declared as `23m_c02_v6.json` (with `E_PIC.MES` among the members) and
`23m_c05_v6.json`, one root-replacement route each, `post_guard_expected`
0, twelve variants each. Audits accepted; `original event analysis 23M
C02` passes 308 checks and `23M C05` 305; a wrong reentry message count
on C02 and C05's handoff shifted one byte are rejected.

## EVENTE01: the spring ladder's middle rung, with three answers

Measured 2026-09-12. `23M.MES:3642..3722` (false `3987`, C05's guard) is
reached only when C02's guard rejected, and needs Saturday, `4/01..6/15`,
`14:31..16:29`, `global_u8[393]` set and `[120]`, `[127]`, `[1792]`,
`[1865]`, `[1889]`, `[1892]` clear; seventeen witnesses pin every edge and
flip every flag. The prefix is 9 messages through 44 records with no
branch, and the dispatch at `3961..3977` is a root handoff.
`EVENTE01.MES` asks its own routine-40 question at `2431` (resume `2436`,
three definitions, consumer the `state_u16[21]` chain at `2441`), in the
stored form the contract builder supports, so all three results are
supplied. Every answer reaches the same handoff `4821..4835 -> GROUND.MES`
and writes the same cells - `banked_u16[1] = 7`, the map word
`banked_u16[242] = 23`, `global_u8[286]`, `[3236]`, `[3460]`, `[5059]`,
`state_u16[8] = 46`, its own done flag `[1889] = 1` at `741..747` and
`[1892] = 1` at `4785..4791`, both conjuncts of the guard that admitted it
- and differs in length and in the affection word `banked_u16[202]`:
results `1` and `2` run 40 messages and leave the word alone, result `3`
runs 36 and adds 1 at `4079..4094`. Inside result `2` the gate at `3626`
reads the word above `2`, choosing a message block and nothing else; the
guard does not bound the word, so both arms are witnessed (`2` and `3`).
Completion is callee-owned twice over, and the done-gate at `219` sends a
direct reentry to the return `4865..4866` with **0 messages** - after the
handoff, so a reentry never hands off again. Segmented and unbroken runs
agree under every result (49 / 49 / 45 messages). `global_u8[4000]` is a
dead input and `state_u16[8]` is cleared before its own ladder reads it,
then left at `46` by the afternoon arm or `0` from `16:00`, when the
clock ladders also choose the later epilogue and leave `[3236]` at `2`;
`[3006]` flips `1058` and `[2847]` flips `4308`.

`[1892]` is the E family's `[1755]`: E01 sets it and both E guards on this
map require it clear, so the first E event on a spring Saturday closes the
other.

Declared as `23m_e01_v6.json` with the callee's contract, three
root-replacement routes over the one guard - `23m-e01-result1` with 10
variants, `-result2` with 12 and `-result3` with 4 - each variant
naming its result, `post_guard_expected` 0. Audit accepted; `original
event analysis 23M E01` passes 623 checks; a wrong callee message count
on result 2 and result 3's handoff shifted one byte are rejected.

## EVENTC17 and EVENTE03: the November ladder

Measured 2026-09-12. `EVENTC17`'s guard `11064..11164` (false `11341`,
E03's guard) needs Saturday, `11/16..15/10` under the owner's month-13
reading, `14:30..17:29`, the affection word `banked_u16[206]` above `70`,
`global_u8[396]` and `[1778]` set and `[160]`, `[164]`, `[167]`, `[1653]`,
`[1694]`, `[1755]`, `[1782]` clear; twenty-one witnesses pin every edge,
including the word at `70/71` where the spring C rungs' bar sits the
other way. The prefix is 6 messages through 29 records, the dispatch at
`11315..11331` a root handoff, and `EVENTC17.MES` - the smallest callee on
the map, with no `[3006]` or `[2847]` arm - runs 27 messages to
`1816..1830 -> GROUND.MES`, writing `banked_u16[1] = 7`, the map word
`banked_u16[242] = 23`, `global_u8[168]`, `[286]`, `[1727]`, `[3224]`,
`[3581]`, `[5195]`, `state_u16[8] = 46`, its done flag `[1782] = 1` at
`1743..1749` and `[1755] = 1`. `EVENTE03`'s guard `11341..11415` (false
`11595`) is the E pair's spring afternoon again - `4/01..6/15`,
`14:31..16:29`, `[393]` set, `[120]`, `[1792]`, `[1865]`, `[1891]`,
`[1892]` clear - so the two rungs of this ladder never share a date;
sixteen witnesses. Its prefix is 6 messages through 30 records, the
handoff at `11569..11585`, and the callee runs 43 messages to `4226..4240
-> GROUND.MES` writing `[265]`, `[286]`, `[3005]`, `[3238]`, `[3461]`,
`[5060]`, the map word, its done flag `[1891] = 1` at `638..644` and
`[1892] = 1`; `P_PIC.MES` is dispatched only on the `[2847]` arm and
emits nothing on the measured seeds. Both are A10's shape: completion
callee-owned, the guard rejecting after the replacement, a direct reentry
sent by the gate at `224` / `219` to the final return (`1860..1861`,
`4270..4271`) with **0 messages**, `global_u8[4000]` a dead input,
`state_u16[8]` cleared before its own ladder - E03's afternoon arm then
leaves it at `46`, or `0` from `16:00`, while C17 leaves it at `0` - and
clock ladders choosing the later epilogue from `16:00`; segmented and
unbroken runs agree (33 and 49 messages). When either guard rejects the
walk ends, as on the spring ladder, at `23M.MES:30385..30399 -> GROUND.MES`.

Declared as `23m_c17_v6.json` and `23m_e03_v6.json` (with `P_PIC.MES`
among the members), one root-replacement route each, `post_guard_expected`
0. Audits accepted; `original event analysis 23M C17` passes 296 checks
and `23M E03` 248; a wrong reentry message count on C17 and E03's handoff
shifted one byte are rejected.

Every 23M intro is measured and declared: five sites, five targets, five
groups, seven routes, no contract change. Read together, the map's five
events are two families' Saturday afternoons: the C family sets `[1755]`
and reads the affection word `banked_u16[206]` on either side of `70`,
the E family sets `[1892]`, and every callee writes the map word `23`
before handing the root back to `GROUND.MES`. The classification binds
`EVENTC17`, `EVENTE03` and `P_PIC`, 74 entries at 49/52/68.

## Not measured here

What schedules `GROUND.MES:66682` into `23M.MES` and any of these guards;
what sets `[396]`, `[393]` and `[1778]`, and what clears `[1755]` and
`[1892]` between Saturdays; what moves the affection words; and
`GROUND.MES` past every handoff.
