# 44C caller group: every intro measured

Measured on 2026-09-11 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`44C.MES` is the root the 44M group's `EVENTL10` reaches when its choice reads
"go back into the dormitory", and the caller with six unresolved EVENT intro
sites for five targets. Three of those targets - `EVENTM03`, `EVENTM10`,
`EVENTM17` - are also dispatched from `L_HOTEL2.MES`; this group measures the
44C sites. The instrument is the one that opened the earlier groups; run first
on `01M.MES`, it reproduces the `EVENTI16` row exactly before it is run here.

## The caller

| Property | `44C.MES` |
|---|---|
| framing-opaque bytes | **0 of 67,635** |
| instructions / branches / calls | 9,537 / 215 / 820 |
| address-table entries | 520 |
| EVENT intro sites | 6, for five targets (`EVENTM10` twice) |
| intros with a typed guard candidate | **all 6** |
| dispatch form | **all six nested calls** |
| framing-opaque bytes in the callees | 0 |

No callee carries a root-handoff terminal candidate, an opaque boundary or a
dispatch of `TRAIN.MES`; all five return. `EVENTM10.MES` is the one callee
that dispatches another script, `EVENTM11.MES`, three times (`9545`,
`13274`, `16586`).

## The six intros

| Intro | Site | Guard | Callee size | Callee branches | Callee messages | Other caller |
|---|---|---|---:|---:|---:|---|
| `EVENTL25` | `27672..27688` | `25851..25946` | 2,013 | 6 | 18 | - |
| `EVENTI24` | `34164..34180` | `33748..33860` | 2,365 | 7 | 27 | - |
| `EVENTM17` | `51655..51671` | `51257..51307` | 2,132 | 7 | 18 | `L_HOTEL2.MES:18036` |
| `EVENTM10` (site A) | `53965..53981` | `52628..52651` | 17,629 | 56 | 164 | `L_HOTEL2.MES:20388` |
| `EVENTM10` (site B) | `54805..54821` | `54206..54235` | 17,629 | 56 | 164 | `L_HOTEL2.MES:21207` |
| `EVENTM03` | `61182..61198` | `60364..60461` | 45,891 | 94 | 480 | `L_HOTEL2.MES:27442` |

## Two independent guards and one ladder

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---:|---:|:-:|---:|---:|---:|---:|---:|
| `EVENTL25` | `25851..25946` | `28779` | 14 | - | 1,726 | 239 | 1 | 2 | 0 |
| `EVENTI24` | `33748..33860` | `34195` | 17 | - | 304 | 41 | **0** | **0** | 0 |
| `EVENTM17` | `51257..51307` | `52628` | 7 | - | 348 | 58 | **0** | **0** | 0 |
| `EVENTM10` A | `52628..52651` | `54206` | 3 | - | 1,314 | 204 | 3 | 0 | 0 |
| `EVENTM10` B | `54206..54235` | `55334` | 4 | - | 570 | 88 | 1 | 0 | 0 |
| `EVENTM03` | `60364..60461` | `62617` | 1 (seven arms) | **yes** | 721 | 100 | 3 | 0 | 0 |

`EVENTL25` and `EVENTI24` have their own guards and nothing else. The other
four share a prefix: a constant-true record `45100..45107` (false `67634`,
the last byte of the entry) and a gate `51227..51237` testing
`state_u16[21] == 3` (false `65955`) - the dormitory's own routine-40
selection must have been answered `3` - and then chain by their false
edges: M17's guard falls to M10 site A's, A's to B's, B's to `55334`, and
about twenty further branches that guard none of this group's targets stand
between `55334` and M03's guard. No edge enters any gap from outside. The
routes below take each intro's own guard as their origin with `state_u16[21]
= 3` seeded, as the FLOOR5 chain was measured; the selection and the gate are
before every origin and are not part of any route.

## The guards, read as scene conditions

Weekday is `state_u16[4]` (`6` is Saturday), the date `state_u16[7]` as MMDD,
the clock `state_u16[19]` as HHMM, and `banked_u16[203]`, `[209]` affection
words. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTL25` | `6/15 < date < 9/16`, `21:59 < clock < 23:01` | `banked_u16[209] > 45` | `[372]`, `[399]` | `[190]`, `[194]`, `[197]`, `[1925]`, `[1966]`, `[2042]`, `[2052]` |
| `EVENTI24` | weekday `0`, `9/15 < date < 15/11`, `18:00 < clock < 22:01` | `banked_u16[203] > 100` | `[372]`, `[1301]` | `[130]`, `[134]`, `[137]`, `[1219]`, `[1226]`, `[1228]`, `[1259]`, `[1262]`, `[1350]` |
| `EVENTM17` | `9/15 < date < 11/16`, `clock > 19:00` | - | `[2447]` | `[150]`, `[230]`, `[2504]` |
| `EVENTM10` A | - | - | `[2445]` | `[2447]`, `[2455]` |
| `EVENTM10` B | - | - | `[2445]`, `[2455]` | `[2417]`, `[2447]` |
| `EVENTM03` | Saturday after `18:59`; weekday `0` before `9:01` or after `18:59`; `12/23` before `9:01` or after `18:59`; `12/24` before `9:01` or after `19:30` | - | - | - |

Three things in the table are measured rather than read. `EVENTL25` and
`EVENTI24` are two different heroines' evening events sharing one
prerequisite, `global_u8[372]`, and each carries its family's flags one step
further along: L25 clears `[2052]` after L03's `[2043]`, L04's `[2044]` and
44M L10's `[2050]`; I24 clears the I09 family plus `[1226]`, `[1228]`,
`[1262]` and `[1350]` with the affection bar at `> 100` after I09's
`51..80`. `EVENTM10`'s two entrances are told apart by one flag,
`global_u8[2455]`: site A needs it clear, site B needs it set - the same
"first visit / later visit" idiom E15's flag `[1914]` gave FLOOR5, here as
two sites of one target. `EVENTM03`'s guard is the first in the archive with
no state cell at all beyond the calendar: a pure disjunction of day and hour
that admits nights on weekday `0` and Saturday, early mornings on weekday
`0`, and both on the two Christmas dates, with Christmas Eve's evening
starting half an hour later. Date values above `1231` follow the owner's
month-13 reading.

## EVENTI24: a dormitory evening behind seventeen conjuncts

Measured 2026-09-11. `44C.MES:33748..33860` (false `34195`) requires weekday
`0`, `9/15 < date < 15/11`, `18:00 < clock < 22:01`, `banked_u16[203] > 100`,
`global_u8[372]` and `[1301]` set, and nine flags clear. Twenty-three
witnesses - five accepting, eighteen rejecting - pin `915/916`,
`1510/1511`, `1800/1801`, `2200/2201` and `100/101`, and reject weekday
`6`, each prerequisite cleared and each flag set; every accepting witness
gives the same 6-message prefix through 41 records.

`EVENTI24.MES` runs 37 messages from `0` and returns at `2358..2359`,
writing `global_u8[1350] = 1` at `2347..2353` - its own guard's flag - and
`[3511]`, `[5108]`. The caller resumes at `34180` and, with no message and
no write, stops at a routine-40 selection at `44C.MES:45952`, the
dormitory's own question, whose definitions are not in the stored form the
contract builder supports; it is a bounded stop, not an answered choice.
Segmented and unbroken runs agree. `global_u8[3006] = 1` flips `641` and
leaves `[3005]` at `15`; `global_u8[2847] = 1` flips `1898`; `state_u16[8]`
is overwritten at `256..261` before its test and `global_u8[4000]` cleared
by routine 28 (`LIBLARY.LIB:756..762`) from `246`. Completion is
callee-owned through `[1350]`, and both reentries return at `2364..2365`
with **0 messages**. Declared as `44c_i24_v8.json` on the v8 contract with
the `def_selection_boundary` resume bound to the record `45952..45957` -
byte for byte the routine-40 call 44M's C18 stops at - audit accepted,
`original event analysis 44C I24` passes 209 checks, the stop shifted by one
byte rejected.

## EVENTL25: late night, no weekday, and a flag set twice

Measured 2026-09-11. `44C.MES:25851..25946` (false `28779`) requires
`6/15 < date < 9/16`, `21:59 < clock < 23:01`, `banked_u16[209] > 45`,
`global_u8[372]` and `[399]` set, and seven flags clear - and no weekday:
seeded `6`, the guard accepts, the one accepting witness among the
twenty-one that changes a cell the guard does not read. The others pin
`615/616`, `915/916`, `2159/2200`, `2300/2301` and `45/46`.

The gap is the group's only one with content: the branch `26806..26817`
tests `global_u8[2847] == 1` and lands before the call either way, and two
silent `L_PIC.MES` calls at `25967` and `27329` return without dialogue;
the prefix is 30 messages. `EVENTL25.MES` runs 24 messages from `0` and
returns at `2006..2007`, writing `global_u8[2052] = 1` at `400..406` - its
own guard's flag - and `[3662]`, `[5281]`. The caller resumes at `27688`,
emits 14 messages across six dialogue boundaries, writes `global_u8[2052]`
**again** at `28752..28758` and `global_u8[2042] = 1` at `28763..28769` -
a second of the guard's own flags, and 44M L10's - and stops at the same
`45952` selection. Segmented and unbroken runs agree. `global_u8[2847] = 1`
flips the callee's `1883`; `state_u16[8]` is overwritten at `411..416`;
`global_u8[4000]` is cleared by routine 28 from `246`.

Completion is owned twice, the L-series shape L03 and L04 showed: the
callee closes conjunct 12 and the resume closes conjunct 11 as well, and
both reentries return at `2012..2013` with **0 messages**. Declared as
`44c_l25_v8.json` with `L_PIC.MES` among the members, the resume carrying
both flags: audit accepted, `original event analysis 44C L25` passes 204
checks, a wrong reentry message count rejected.

## EVENTM03: a calendar-only guard on a script mostly not reached

Measured 2026-09-11. `44C.MES:60364..60461` (false `62617`) is one
disjunction of seven (day, hour) arms and nothing else. Seventeen witnesses
pin every arm: Saturday rejects `18:59` and accepts `19:00`; weekday `0`
accepts `9:00`, rejects `9:01` and `18:59`, accepts `19:00`; weekday `3`
rejects both hours; `12/23` accepts `9:00` and `19:00` and rejects `9:01`
and `18:59`; `12/24` accepts `9:00`, rejects `19:30` and accepts `19:31`;
and `state_u16[21] = 2` accepts, because the gate is before the origin.
Every accepting arm gives the same 4-message prefix. Between guard and
call, three branches on `global_u8[2419]` and `[2417]` select one of three
preludes; at baseline the first (`[2419] == 0`) is taken.

`EVENTM03.MES` is 45,891 bytes with 94 branches and 480 message records,
and the baseline route reaches twelve branches and 24 messages before
returning at `13317..13318`, writing `global_u8[2417] = 1` at
`13295..13301`, `[2420] = 1`, `[350] = 2`, `[351] = 3`, `[3554]`, `[5154]`
and `banked_u16[1] = 7`. No routine-40 selection is reached inside the
callee on any measured seed. The caller resumes at `61198`, emits 6
messages across two dialogue boundaries, advances the clock by fifteen
minutes inside a library routine (`1900 -> 1915`), and stops at the
dormitory's selection at `45952`, the stop I24 and L25 also reach.
Segmented and unbroken runs agree. Across the seven arm variants and eleven
callee-cell variants eighteen branches are reached; `global_u8[3006] = 1`
flips `11464`, `global_u8[2847] = 1` flips `13172`, and the `9:00` arms
also leave `state_u16[8]` at `46`.

Two of the callee's flags decide its shape rather than its arms. With
`global_u8[2504] = 1` - the flag M17's guard needs clear - the callee
returns elsewhere, at `8491..8492` after 25 messages, writing `[2507]`
instead of `[2420]` and `[3554]`; that is a second route, declared below.
And the callee's own `[2417]`, once set, sends any reentry to a third
return, `45884..45885`, after 17 messages: the guard stays true after both
the callee and the resume - it reads only the calendar - so there is no
completion predicate on the caller's side, G08's shape, but the event
still knows it has run.

The flags this callee writes are read elsewhere: `[2417]` by M10 site B's
guard and by the caller's own preludes, and `[2420]` by the station's M06
and M09 guards, which require it set. M03 is therefore upstream of three
routes measured before it.

### Runtime group: `44c_m03_v8.json`, and what it needed from Core 0.315.0

Declaring this route exposed two limits of the continuation contract. The
validator asserted, for every guarded continuation, that the guard rejects
after the resume - true of every route measured before, false of a guard
that reads only the calendar - and it silently ignored a v8 variant's own
`reentry` override. Core 0.315.0 lets a caller-continuation route declare
its post-guard truth, route-level and per variant, as root replacements
already could (a profile that declares nothing keeps the old assertion),
and makes v8 read per-variant reentry overrides. Both are covered by
tests, and the eight 44M v8 profiles that carried a `null` placeholder for
the field are accepted unchanged.

The profile declares two routes over the shared guard and caller record:
`44c-m03` with seventeen variants and `44c-m03-after2504` with seven,
both with `post_guard_expected: 1`. The resume's fifteen-minute clock
advance closes the guard only where it crosses `9:01`, so the three
`9:00` arms - weekday `0`, `12/23` and `12/24` - carry a per-variant `0`,
recomputed from the measured post-resume state rather than assumed; the
`global_u8[2516]` variant carries its own reentry, `40871..40872` after 2
messages. Audit accepted; `original event analysis 44C M03` passes 684
checks; the second route's return shifted by one byte, a wrong reentry
count and the route-level post-guard truth flipped to `0` are rejected,
the last one exactly on the fourteen variants that leave the guard open.

## EVENTM10: two entrances, and the caller consumes the first one itself

Measured 2026-09-11. Site A's guard `52628..52651` (false `54206`) needs
`global_u8[2445]` set and `[2447]`, `[2455]` clear; site B's `54206..54235`
(false `55334`) needs `[2445]` and `[2455]` set and `[2417]`, `[2447]`
clear. Nine witnesses over the two, and each guard rejects the other site's
baseline. Neither guard reads the calendar; the callee is measured at `9:00`,
`13:00` and `20:00` and changes no arm.

Site A's prefix runs 30 messages through three branches on `state_u16[5]`
and, at `52898..52904`, writes `global_u8[2455] = 1` **before the
dispatch**: the caller consumes its own entrance flag, so the next visit
arrives at site B. Site B's prefix is 13 messages and writes nothing the
guards read. From either site `EVENTM10.MES` runs the same 84 messages to
the same return, `6045..6046`, with the same signature and the same ten of
its 56 branches - most of the file stands behind the visit counter
`global_u8[2456]`, which the callee sets at `6023..6029` together with
`[2417] = 1` at `6034..6040`, site B's own clear flag. `EVENTM11.MES` is not
reached on the measured path. Both resumes stop at the dormitory's selection
`45952`, A after 6 messages and B after none. Segmented and unbroken runs
agree at both sites, and the two sites' callee runs are identical.

With `[2456]` already set the callee runs 51 messages and returns at
`10734..10735` - eleven arms change - which is exactly what every reentry
does: after either site's first pass the event's second pass is a different
body with a different return, the visit-counter shape M03 also has.
Completion: site A's guard is closed by the caller's prefix through
`[2455]` before the callee runs, H07's shape; site B's by the callee's own
`[2417]`. `[2445]` and `[2447]` are written by nothing measured here.

Declared as two groups over the one callee, `44c_m10a_v8.json` and
`44c_m10b_v8.json`, with `EVENTM11.MES` - the callee's static dependency,
reached on no measured path - among the members. Each carries its own
site's guard witnesses plus the other site's baseline as a rejecting case,
five first-pass variants, and the 51-message second pass at `10734..10735`
as its reentry, asserting `[2456] = 2` and `[350] = 4`; the `[2456]` seed is
that reentry, not a variant of the first pass, and is not declared twice.
Neither route declares a post-guard truth: both guards measure closed after
the resume, A's by its own prefix and B's by the callee. Audit accepted
both; `original event analysis 44C M10A` passes 141 checks and `M10B` 143;
a wrong reentry effect on A and a resume stop shifted one byte on B are
rejected.

### How `EVENTM10` reaches `EVENTM11` (measured 2026-09-23, EP-03 step 2)

Evidence: the authoritative `mes.arc` (`31a95b31...986aa6`), the Python
Phase 1-4 handoff of `EVENTM10.MES` (entry SHA-256
`5d84a459861d5e28fdbef6596e6fc1020345a6400c48c93a2da92e72d4ad1a15`, the
groups' own) read statically, and headless replays of both 44C sites through the shared
call frame (`content_core/mes_route_probe.gd`) with tool-seeded values of the
visit counter and one gate flag. Probes and the full table:
`analysis/ep03_m11_*` and `analysis/_undoc/ep03_m10_m11_report.md`
(untracked).

`EVENTM10.MES` opens with a ladder on the visit counter `global_u8[2456]`:

| Test | False target | Rung's body | Rung returns at | Rung writes `[2456]` |
|---|---:|---|---|---|
| `264..275` `[2456] == 0` | `6056` | the first pass (84 messages) | `6045..6046` | `1` at `6023..6029` |
| `6056..6067` `[2456] == 1` | `10745` | the second pass (51 messages) | `10734..10735` | `2` at `10712..10718` |
| `10745..10756` `[2456] == 2` | `14160` | the third pass (22 messages) | `14154..14155` | `3` at `14132..14138` |
| `14160..14171` `[2456] == 3` | `17628` | the fourth pass (18 messages) | `17622..17623` | none |
| otherwise | - | nothing | `17628..17629` (0 messages) | none |

Every content rung also writes `global_u8[2417] = 1` (`6034`, `10723`,
`14143`, `17611`). The counter stops at `3`, so from the fourth visit on the
fourth pass repeats. Each of the three `EVENTM11.MES` dispatches (command
`0x0F`) sits in one rung, behind one gate:

| Dispatch | Rung (visit) | Gate | False target |
|---|---|---|---:|
| `9545..9561` | `[2456] == 1` (second visit) | `9146..9289`: any of `global_u8[287..302]`, `[316..318]`, `[320..323]` non-zero (23 flags) | `9941` |
| `13274..13290` | `[2456] == 2` (third visit) | `12618..12761`: the same 23 flags | `13572` |
| `16586..16602` | `[2456] == 3` (fourth and later visits) | `15924..16073`: the same 23 flags or `global_u8[319]` (24) | `16962` |

A `global_u8[2483]` test before the second and third dispatches (`12766`,
`13044`; `16078`, `16356`) only picks presentation lines; every arm reaches
the dispatch. The 23/24 flags have no repository name yet.

Replayed from both sites: with a gate flag set (`[287] = 1`), a seeded
`[2456] = 2` reaches the dispatch at `13274` and `[2456] = 3` the one at
`16586`; `[319]` alone opens the third gate and not the second; with the
gates clear no seed reaches a dispatch; seeds `4` and `5` run the empty
tail. Every reached `EVENTM11.MES` run is identical: 6 messages, writes
`global_u8[10..20]` (eleven flags), no dispatch of its own, returns at
`37546..37547`; `EVENTM10` then finishes its rung and the 44C resume stops
at the selection `45952` as before. The first dispatch (`9545`, second
visit) is established statically only; no replay seeded `[2456] = 1` with a
gate flag.

EP-11 part 1c (owner ruling 2026-09-23): only site B's route declares
`visits`. Site A is single-entry by its own caller, already established
above (`Natural re-entry`, next paragraph) - its prefix writes
`global_u8[2455] = 1` at `52898..52904` unconditionally before the dispatch,
and site A's own guard needs `[2455]` clear, so once a genuine playthrough
enters site A that guard is closed for good; nothing in the archive clears
`[2455]` again. Site A's callee (`EVENTM10.MES`) still advances its own
visit-counter ladder exactly as described above, but nothing ever visits it
through site A a second time - the natural later visits come through site
B, whose own guard reopens at each day change (`Natural re-entry`, below).
`44c_m10a_v13.json` keeps its v13 schema, route and reentry from part 1a
with `visits` removed; `44c_m10b_v13.json` keeps them.

Two further rung effects on `global_u8[350]`/`[351]`, and one on `[287]`,
measured 2026-09-23 (EP-11 parts 1b/1c) from a direct runtime snapshot of
the gated rungs (`content_core/mes_sandbox_state.gd`'s `snapshot()`, not the
profile's own curated `expected_state` lists, which do not carry them):
`[351]` becomes `4` once the third rung's gated dispatch to `EVENTM11.MES`
has run (it holds `3` after the ungated second rung's own reentry); `[350]`
becomes `0` once the fourth rung's gated dispatch has run (it holds `4` up
to and including the third rung, gated or not); and the gate flag
`[287]` a rung's own `seed_writes` sets stays `1` afterward - `EVENTM10.MES`
never clears it (confirmed by a full state diff over the third rung's run) -
so a later rung reached without its own `seed_writes` (the fixed point at
the fourth rung, visited a second time with the counter unchanged) still
finds its gate open from the rung before. All three are genuine effects of
running a gated rung itself, not of the visit-counter ladder alone, and are
declared as `entry_state` on `44c_m10b_v13.json`'s `visit4-gate` (`[351]`)
and `visit5-gate` (`[350]`, `[287]`) since composing only the route's and
the earlier rungs' own declared `expected_state` fields does not reproduce
them.

EP-11 part 1c also found `entry_state` cannot carry every cell a route's own
local guard reads: site B's guard rejects whenever `global_u8[2417] = 1`
(the guard case `global_u8-2417-1` in `44c_m10b_v13.json`), which is exactly
the value the callee's first dispatch leaves there and the value every
visit's `entry_state` therefore declares - the day-change mechanism above,
not the callee, is what actually clears `[2417]` between visits. Playing a
visit preset through site B's own guard with that post-dispatch value loaded
rejects the guard before the callee ever runs. The tool decision
(`tools/promote_analysis_groups.py`'s `_guard_declared_cells`, read from the
route's own `guard_cases`, never a hard-coded cell list) is to drop such
cells from a visit preset's composed `entry_state`, leaving the row's
default preset's own accepting value in their place - `content_tools.md`
records the rule.

Natural re-entry. Site A is entered once: its prefix sets `[2455]`. Site B
needs `[2417]` clear, and every content rung sets it; the only write of `0`
to `[2417]` in the archive is `DEF_MAIN.MES:2638..2644`. That write is in the
body of registered definition 12 - registered at `DEF_MAIN.MES:1178`
(`0x049A`), body `1185..3835`, one of the fourteen definitions the boot walk
registers (`18, 81, 26, 11, 12, 14, 15, 17, 21, 22, 23, 20, 80, 99`, the
Phase 6 registry order) - where a chain of 21 identical tests
`state_u16[2] != 0 and global_u8[534] == 0` (`1285` .. `2622`, one more at
`3616`) each clears a run of day flags; `[2417]` is cleared behind the last
(`2622..2638`, false `2686`). Definition 11 (body `1076..1178`) advances the
clock by `state_u16[2]` minutes - the value events leave there as they
finish - and invokes definition 12 at `1167..1172`; `MACHI.MES` (85 sites,
15 minutes), `GROUND.MES` (34, 5), `DATETIME.MES` and `M_TIME.MES` (60),
`TIME_C.MES` (30) invoke definition 11, and `43C.MES` - the dormitory's own
day-end target, above - invokes definition 12 directly five times. Replayed
through the shared call frame from `[2417] = 1` on 0501: 23:50 + 15 minutes,
23:05 + 60 and 23:59 + 1 each cross midnight, advance the date to 0502 and
clear `[2417]`; 09:50 + 15, 22:05 + 60 and 23:50 + 5 do not cross and leave
it set. So **site B reopens at each day change**, and `EVENTM10` reaches its
second, third and fourth rungs one day at a time while `[2447]` stays clear
(`44C.MES` sets `[2447]` at `4367` and `9989`, which closes both sites;
`EVENTM11.MES` reads `[2447]`); `EVENTM11.MES` plays on those visits when one
of the 23 gate flags is set. Not established: whether `global_u8[534]` (read
only by `43C_ASA.MES`, `DEF_MAIN.MES` and `LIBLARY.LIB`; written by 47
entries, the per-heroine schedule scripts among them) is ever non-zero at a
natural midnight, which would skip the clears, and which natural events set
the 23 gate flags. Evidence: the Python handoff of `DEF_MAIN.MES` (entry
SHA-256 `f2012ce5...db0ef0`), an archive-wide scan of `definition_invoke`
and of the two gate cells' writers, and the day-rollover replays
(`analysis/_undoc/ep03_def_main_clear_report.md`, untracked). The committed
`44c_m10a_v8.json` and `44c_m10b_v8.json` groups are unchanged.

### EVENTM03's second ladder (measured 2026-09-23)

The archive-wide visit-ladder census found a second counter in
`EVENTM03.MES`: from `14092`, fifteen equality tests on `global_u8[2421]`
(`0` to `14`), each true arm a content body that writes `[2421]` to the next
value and joins one shared return at `38838..38839`. None of the three
declared M03 outcomes reaches it (all return before `14092`). Replayed
through the shared call frame with M03's baseline flag `[2420] = 1` and the
counter seeded `0..14`, every rung runs (14 to 32 messages), writes the
counter forward at its statically predicted offset and returns; no rung
dispatches another script. Evidence: Python handoff static census and
headless replays (`analysis/_undoc/ep03_visit_ladder_census_report.md`,
untracked).

EP-11 part 1c (measured 2026-09-23): the natural arrival is the same
day-change idiom `EVENTM10` site B uses. Route `44c-m03`'s own first pass
writes `global_u8[2417] = 1` and `[2420] = 1` at its completion (already
recorded above); nothing in `EVENTM03.MES` or `44C.MES` clears `[2417]`
again, and an immediate reentry (the route's own declared `reentry`, still
with `[2417] = 1`) returns early at `45884..45885` without ever reaching
`13328`. Replayed through the shared call frame, `DEF_MAIN.MES`'s registered
definition 11 (one full day, `state_u16[2] = 1440`: the clock is unchanged
and only the date/weekday advance) clears `[2417]` to `0` while leaving
`[2420] = 1`, `global_u8[4000] = 0` and `global_u8[3006] = 0` exactly where
the route's own variants leave them; re-entering `EVENTM03.MES` from that
state reaches the branch at `13328` (`[2420] == 1 and [2417] == 0`), falls
through it, and reaches `14092`'s first rung. A direct check confirms
`global_u8[2417] = 0` is the only cell this path needs seeded beyond what
the route's own first pass already leaves: entering from "route" state with
only `[2417]` forced to `0` and the calendar left untouched (date `1001`,
weekday `0`, clock `1915`) reaches `14092` and completes rung 0 identically
to the full day-change replay. Chained fifteen times (each subsequent rung's
own shared join at `38838..38939` writes `[2417]` back to `1`, so each later
rung again needs a day change before it), the fifteen declared rungs run in
order (`14, 18, 23, 31, 23, 29, 18, 32, 20, 22, 17, 18, 18, 17, 20` messages,
inside the `14`-`32` range already measured) and advance `global_u8[2421]`
`0` through `15`; entered a sixteenth time with the counter already at `15`,
the ladder repeats at the same join with `26` messages and leaves the
counter at `15` - the fixed point M10's fourth rung also showed. No rung or
the repeat dispatches another script.

Declared as `44c_m03_v13.json` (schema `kakyu_event_analysis_group/v13`,
route and reentry unchanged in meaning): route `44c-m03` carries sixteen
visits, `ladder-00` (`after: "route"`) through `ladder-14`, then `ladder-15`
repeating the fixed point (`after: "ladder-14"`). Every visit's
`entry_state` asserts `global_u8[2420] = 1`, the counter's own entry value,
`banked_u16[1] = 7`, `global_u8[350]`/`[351]` (an unrelated session counter
that keeps changing but is already true of the named pass), `[3554] = 1`,
`[4000] = 0` and `[5154] = 1` - all already true of the pass the visit
chains from. Every visit's `seed_writes` is `global_u8[2417] = 0`
(`seed_basis: "tool_seeded"`): the day change that clears it is a genuine
archive mechanism (`DEF_MAIN.MES` registered definition 11/12, the same one
`EVENTM10` site B's natural reentry uses), but it runs in a different
script and the v13 `after` vocabulary only chains `route`/`reentry`/an
earlier visit's own resulting state, so it cannot be named as a pass here.
The day change's other effects (the date and weekday advancing, and, over a
repeated-day-change probe, one incidental unrelated flag,
`global_u8[285]`, toggling and untoggling on one date crossing) are a tool
decision not to reproduce: `EVENTM03.MES`'s ladder body never reads them,
confirmed by the minimal-seed check above, so only the cell the ladder
actually needs is seeded. This is a separate tool decision from
`_guard_declared_cells` (M03's own local guard is calendar-only and reads no
flag cell at all, so nothing is dropped from any visit's composed catalog
writes there), applying the same underlying principle - reproduce only what
the analyzed script actually reads - to the raw analysis-group `seed_writes`
declaration instead. `44c-m03-after2504` is unaffected: no measured seed on
that route reaches `13328`. Evidence: headless replays
(`analysis/44c_m03_ladder_probe.gd`, `analysis/44c_m03_ladder_rungs.gd`,
`analysis/44c_m03_minimal_seed_check.gd`, untracked) and
`analysis/_undoc/ep11_1c_m03_report.md` (untracked). Audit accepted;
`original event analysis 44C M03` passes 4220 checks (684 before this
change); a wrong visit message count is rejected.

## EVENTM17: an autumn evening the caller closes twice over

Measured 2026-09-11. `44C.MES:51257..51307` (false `52628`, M10 site A's
guard) requires `9/15 < date < 11/16`, `clock > 19:00`, `global_u8[2447]`
set and `[150]`, `[230]`, `[2504]` clear; eleven witnesses pin `915/916`,
`1115/1116` and `1900/1901`. The prefix is 12 messages through 58 records.
`EVENTM17.MES` runs 24 messages from `0` and returns at `2125..2126`,
writing none of the group's flags; `global_u8[3006] = 1` flips `651` and
`global_u8[2847] = 1` flips `1980`, `state_u16[8]` is overwritten at
`415..420` and `global_u8[4000]` cleared by routine 28.

The caller resumes at `51671` through `O_PIC.MES` and seven dialogue
boundaries, writes `global_u8[2504] = 1` at `52558..52564` - its own guard's
flag - and `global_u8[2417] = 1` at `52569..52575` - M10 site B's clear
flag - and stops at the selection `45952` after 19 messages. At `23:59` the
same resume takes another tail and hands the root to `43C.MES` at `45734`
instead: a day-end transition measured and not declared, since it is a
second resume outcome. Completion is caller-owned through `[2504]`, C18's
shape, and the resume also closes M10's site B for the day; the completed
reentry returns at `2131..2132` with **0 messages**, the direct reentry
replays all 24.

Declared as `44c_m17_v8.json` with `O_PIC.MES` among the members: eleven
witnesses, seven variants, the resume asserting `[235]`, `[2417]` and
`[2504]` at 1, the completed reentry `2131..2132` with 0 messages. The
`23:59` seed is left out - its resume is a second outcome, the `43C.MES`
handoff - and so is the `[2504]` flip, which the guard rejects. Audit
accepted; `original event analysis 44C M17` passes 175 checks; a wrong
reentry message count is rejected.

Read together, the ladder's flags trace one order: M03 sets `[2417]` and
`[2420]`, M17's resume sets `[2504]` and `[2417]`, M10's first pass sets
`[2455]` (in the caller) and `[2417]` (in the callee), and `[2445]` and
`[2447]` - which M10 and M17 require - are set by nothing on this floor.

Every 44C intro is measured and declared: six sites, five targets, six
groups, one contract change (Core 0.315.0, for M03's calendar-only guard).
The classification binds `EVENTM10`, `EVENTM11` and `EVENTM17` on these
groups, 62 entries and 49/43/77 over the 169 rows.
