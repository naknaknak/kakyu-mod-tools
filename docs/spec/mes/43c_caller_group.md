# 43C caller group

Inventoried and measured on 2026-09-13 against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`. All
coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`43C.MES` is a floor script with one unresolved EVENT intro site,
`EVENTM05`: a nested call (command `0x0F`) behind a typed guard, whose
callee counts a visit and returns, and whose caller closes the guard and
walks on to its own question. Qualified with the route toolchain on its
caller-continuation form with the `def_selection_boundary` policy.

## The caller and the intro

| Property | `43C.MES` |
|---|---|
| framing-opaque bytes | **0 of 41,738** |
| instructions / branches / address entries | 5,575 / 341 / 234 |
| EVENT intro sites | 1 |

| Intro | Site | Form | Guard | False target | Conjuncts | Gap | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|---|---|---|
| `EVENTM05` | `3670..3686` | nested call | `1435..1465` | `4973` | 4 | 2,205 B / 3 branches / 1 dispatch | 1,767 | 6 | 12 |

The clock is `state_u16[19]` as HHMM; flags are `global_u8`. The guard
wants the clock past `19:00` with `[2420]` set and `[150]`, `[2422]`
clear - `[2422]` is the flag the caller closes after the call, and the
callee's own gate cell. In the gap the caller recomputes `state_u16[5]`
from bit 128 of `banked_u16[2]` at `1564` and `1785` (clearing `[199]`),
clears `[156]` and calls `M_PIC.MES` at `2005`, and resets `[2836]`,
`[3000]`, `[2841]` at `3483..3495` behind a `[2847]` branch.

## EVENTM05: an evening body, the floor closes the flag and asks its question

Five witnesses pin the clock edge and flip every flag, every rejection
stopping at the floor's own question at `20161`. The prefix runs 41
messages to the dispatch at `3670..3686`. `EVENTM05.MES` counts `[244]` at
`118` - before its gate at `244` on `[2422]` (false `1741`), so a reentry
counts again - writes `[5155]` and `[3555]` and returns at `1735..1736`
after 16 messages, never writing `[2422]` itself. The caller resumes at
`3686` for 25 messages: it closes `[2422]` at `4957` and stops at its own
routine-40 question at `20161..20166`, a definition-selection boundary the
contract tool does not name (the 11M shape). The guard still accepts the
callee's returned state - `post_guard_expected` reads the resumed state,
where `[2422]` rejects it - and a reentry on the resumed state returns
through the callee's gate to `1766..1767` with **0 messages** after
counting `[244]` again (the seeded-count row overrides it). Segmented and
unbroken runs agree. `state_u16[8]` is rewritten at `430` before it is
read and `global_u8[4000]` reads `0` at the callee's entry whatever is
seeded; `[2847]` flips one arm at `1612`.

Declared as `43c_m05_v8.json` with no contract, `M_PIC` among the members,
one caller-continuation route `43c-m05` on the `def_selection_boundary`
policy with 8 variants - the count varying per row -
`post_guard_expected` 0, the reentry the return record with the count's
next step. Audit accepted; `original event analysis 43C M05` passes 182
checks; a wrong callee message count, the return record shifted one byte
and the resume's selection record shifted one byte are rejected.

## The question at 20161 is the room-action menu

Established on 2026-10-04 (EP-12 H) with one instrumented probe: the route
probe run from the room's loop head (`14751`) with the clock at 20:15 to the
question's boundary, reading the registered options. The routine-40 record at
`20161` selects definition group 0, six unconditional rows registered at
`18345`, `18382`, `18419`, `18456`, `18493` and `18530`; definition `18493` is
the leave-the-room row of [Room Screen](room_screen.md) (its body starts at
`18502`, `0x4846`, the address-entry-148 code that document binds), so the
question is the room-action menu. By meaning, read from the row text locally
(the text is not recorded): row 1 phones someone, row 2 checks belongings,
**row 3 recalls a girl's memories**, row 4 ends the day's activity (the adjacent
end-activity action of Room Screen), row 5 leaves the room for the corridor,
row 6 opens the other commands. The result is stored in `state_u16[21]` and the
first-stage consumer tests it one-based in the order of the rows
(`20196` `== 1` false to `35527`, `35527` `== 2` false to `36923`, `36923` `==
3` false to `38400`; the audit of
[Format and Method](format_and_method.md), "sole remaining routine-40
result-consumer outlier", aligned the six values with group 0's six rows).
Answer 3 is the recollection row.

The secondary menu is the room's other half. The probe with the flags set shows
group 3 registering 13 rows at `19198`, `19235`, ... `19646` (definition 0..12),
each a row for recalling time with that heroine, in the order of the picker ids below, each
registered behind its own flag test: `global_u8[391..395]` for ids 1-5, `[403]`
for id 6 (Tina; `EVENTM01.MES` writes it, [Format and Method](format_and_method.md))
and `[396..402]` for ids 7-13. The picked row's id is the native
secondary result `state_u16[13]` the 13 id tests at `36964..37324` read; no
`43C.MES` record writes it, so a tool that starts at the answer-3 arm **seeds**
`state_u16[13]` (the id) and `state_u16[21]` (3) - a tool decision, the same kind
as the album's `state_u16[18]`, labelled in the profiles' `unresolved` lists.

| Picker id | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Ladder | `REIKO_H` | `MIKO_H` | `MIZUHO_H` | `MAYUMI_H` | `RYOKO_H` | `TINA_H` | `NANA_H` | `MIYUKI_H` | `AI_H` | `SIZUKA_H` | `MAHOKO_H` | `MINATU_H` | `MAKI_H` |
| Heroine letter | F | A | E | I | G | M | C | H | K | L | B | J | D |

The 13 id tests and the calls they guard (code-relative; each test ends exactly
where its call begins): id 1 `36964..36974` then `36974..36989`, id 2
`36994..37004` then `37004..37018`, id 3 `37023..37033` / `37033..37049`, id 4
`37054..37064` / `37064..37080`, id 5 `37085..37095` / `37095..37110`, id 6
`37115..37125` / `37125..37139`, id 7 `37144..37154` / `37154..37168`, id 8
`37173..37183` / `37183..37199`, id 9 `37204..37214` / `37214..37226`, id 10
`37231..37241` / `37241..37257`, id 11 `37262..37272` / `37272..37288`, id 12
`37293..37303` / `37303..37319`, id 13 `37324..37334` / `37334..37348`. The tests
form one chain (each false target is the next test) behind the clock save
`banked_u16[195] = state_u16[19]` at `36938..36948`, which is where a route
starts: the jump before each test is not a typed record the audit accepts as an
origin, and the answer-3 test at `36923` sits before it. After each call a jump
goes to `38374`, whose write and routine 23 lead through `41642` to the jump at
`41732` back to `14751`: the room's loop head, which is the room-action menu
again - the basis of the `place_menu` phrase for a route that ends at the
ladder's own return (a tool decision, as for the album scenes).

## Declared: the 13 recollection ladders (EP-12 H, 2026-10-04)

The owner ruled on 2026-10-04 (`todo/event_player.md` EP-12) that H is not a
gallery family: the 13 `?_H.MES` scripts are **13 ordinary `43C.MES` sites**,
declared after SCENE and before TALK. One analysis group per ladder
(`config/event_catalog/analysis_groups/43c_<name>_h_v14.json`, group
`43c-<name>-h`, `kakyu_event_analysis_group/v14`, no contract change; one group for
all 13 would put the other 12 ladders into every row's `required_entries` and every
v6 document's dependencies), one route `<letter>-h`, one catalog row
`<name>.town.43c.h.1`. Built with the tools of `docs/spec/tech/content_tools.md`
("EP-12 H tools"): `tools/draft_recollection_flow_specs.py` (static),
`tools/content_suite/cli/measure_recollection_flow.gd` (measurement, specs),
`tools/build_event_flow_profile.py` (profile).

**The route.** Hop 1 is `43C.MES` from the **origin** `36938` - the clock save
`banked_u16[195] = state_u16[19]`, so the tail's restore of the clock is faithful;
the answer-3 test at `36923` sits before it and the jump before each id test is not
an origin the audit accepts - through the heroine's id test (the route's origin
guard, `state_u16[13] == id`, with the rejected case writing another heroine's id)
to the ladder's nested `CALL` (command `0x0F`), zero messages. Hop 2 is the ladder,
entered by that call at its start, ending at its own closing `script_return`, with
`segment_budget` 1024 (`docs/spec/tech/content_tools.md`, "Hop `segment_budget`").
The flow ends there: the jump to `38374`, the return chain to the room's loop head
and the next room-action menu are a measured fact of the study (above), not a hop.

**Tool decisions (labelled in each route's `unresolved`).** The room-action menu's
selection is **seeded state**: the question at `20161` is a shape the
choice-contract tool cannot name, and the picked girl's id is the native secondary
selection's result, which no `43C.MES` record writes - the baseline writes
`state_u16[13]` (the picker id) and `state_u16[21]` (3). The room's evening
ambient cells are tool decisions too: `state_u16[19] = 2015` (consistent with the
20:15 room-action menu of [Room Screen](room_screen.md)), `state_u16[8] = 0` (rewritten
before it is read in the callees) and `global_u8[2573] = 0` (the gallery-mode cell
the ladder's tail tests). **State policy:** the default variant is the **full
recollection** - every gate flag of the ladder set, the most evidence - and the second
variant, `no-recollection`, writes every gate cell 0 (a room before any of the events
ran); both end at the same `script_return`. Per-segment combinations (2^n) are not
walked.

**The gates, recounted by the structural rule.** A gate is a single `global_u8`
flag test (`== 1` or `!= 0`) on the ladder's main path: not a tail cell (`[11]`, the
segment-done marker; `[2573]`), not a presentation cell (`[4000]`, `[3006]`, `[2847]`),
not a selector (a cell the script also compares with another value: `[3201..3206]`-type
picture arms, the recap cells `[2676..2679]`-type that are 1 or 2), not enclosed by the
skip span of a branch that is not itself a gate; gates nest; a pure OR of such flag
tests is **transparent** (a guard of its block: MIYUKI_H `64394` over `[2176 2177 2179
2180 2181]`, MINATU_H `33672` over `[923 924]`, the member `[924]` tested only inside
the guard and not seeded). It is a byte-position rule: the earlier byte-skip count
(single-cell tests that skip more than 1,000 bytes, 281 over the 13 scripts, outside
the presentation cells) missed every segment shorter than 1,000 bytes and the prologue
segments. **330 gates over 326 cells (summed per ladder; 320 distinct cells over the set), 60 of them nested**; every ladder's gates include its
heroine's ending cell (`global_u8[2560..2572]`), the last gate of every ladder but MIZUHO's. The other branch cells are left at
their ambient 0 and reported per ladder (`excluded` in the recipe): the recap blocks (an
OR over cells the heroine's `?_DATE5.MES` writes 1 and `?_HOTEL.MES` 2, each tested `== 1`
and `== 2` inside) are skipped in the default variant, as are the picture arms; every
static gate is evaluated, and taken, by the full recollection's run.

| Id | Ladder (heroine) | Group / route | Gates (cells) | Id test / call | Messages: full / none | Segments: full / none | Return |
|---|---|---|---:|---|---|---|---:|
| 1 | `REIKO_H` (F) | `43c-reiko-h` / `f-h` | 30 (30) | 36964 / 36974 | 721 / 9 | 542 / 4 | 72385 |
| 2 | `MIKO_H` (A) | `43c-miko-h` / `a-h` | 26 (26) | 36994 / 37004 | 911 / 9 | 649 / 4 | 79656 |
| 3 | `MIZUHO_H` (E) | `43c-mizuho-h` / `e-h` | 29 (29) | 37023 / 37033 | 688 / 9 | 491 / 4 | 66107 |
| 4 | `MAYUMI_H` (I) | `43c-mayumi-h` / `i-h` | 30 (29) | 37054 / 37064 | 793 / 9 | 541 / 4 | 73452 |
| 5 | `RYOKO_H` (G) | `43c-ryoko-h` / `g-h` | 25 (25) | 37085 / 37095 | 699 / 9 | 487 / 4 | 62024 |
| 6 | `TINA_H` (M) | `43c-tina-h` / `m-h` | 18 (18) | 37115 / 37125 | 902 / 18 | 577 / 7 | 67276 |
| 7 | `NANA_H` (C) | `43c-nana-h` / `c-h` | 27 (26) | 37144 / 37154 | 751 / 9 | 531 / 4 | 71931 |
| 8 | `MIYUKI_H` (H) | `43c-miyuki-h` / `h-h` | 25 (25) | 37173 / 37183 | 890 / 9 | 619 / 4 | 82332 |
| 9 | `AI_H` (K) | `43c-ai-h` / `k-h` | 23 (23) | 37204 / 37214 | 751 / 9 | 525 / 4 | 68185 |
| 10 | `SIZUKA_H` (L) | `43c-sizuka-h` / `l-h` | 27 (26) | 37231 / 37241 | 784 / 9 | 516 / 4 | 83060 |
| 11 | `MAHOKO_H` (B) | `43c-mahoko-h` / `b-h` | 23 (23) | 37262 / 37272 | 577 / 9 | 425 / 4 | 54359 |
| 12 | `MINATU_H` (J) | `43c-minatu-h` / `j-h` | 20 (20) | 37293 / 37303 | 577 / 9 | 419 / 4 | 60258 |
| 13 | `MAKI_H` (D) | `43c-maki-h` / `d-h` | 27 (26) | 37324 / 37334 | 570 / 9 | 417 / 4 | 55291 |

(9,614 messages over the 13 default variants; 8 of the 13 full runs need more than the
probe's default 512 segments - REIKO, MIKO, MAYUMI, TINA, NANA, MIYUKI, AI, SIZUKA.
`NANA_H` nests `O_PIC.MES` at `15781` - the standing-picture script, a member of
that route's flow like the date flows' `*_PIC.MES` members - and returns only when
it is loaded. The codes are code-relative; every ladder's return is the one its
no-recollection run reaches, so the three tail arms converge.)

**Registry, catalog, package.** Registry 567 rows (the 13 new sites
`<name>.town.43c.h.1`, the 554 earlier rows unchanged; `EXPECTED_PAIR_COUNT` 532); catalog
revision 37, 554 -> 567 rows, all `minimal_playback` (the 13 ladders `playable_event`, each
with two presets - `default` the full recollection and `no-recollection` - and a route
outcome `place_menu`; each row's terminals are the ladder's `script_return` and the room's
loop boundary after the call; `display.categories` is `["character_event", "town"]`, no
`gallery`); the 554 existing rows are byte-identical. Package v7: 567 events from 762 member
entries (167 catalog-verified, 595 bound by 199 analysis groups), Core 0.370.0, SHA-256
`f45a5cd53efc4060764fb4d19b0a6071a465b8d1f0c353477d902af42226cd4b`. 567 v6 documents
(`config/event_definitions/v6/README.md`; a ladder's document carries 570-911 lines).
Route classification moved its `catalog_sha256` and one group list: `O_PIC.MES` gains
`43c-nana-h` as a `source_member` binding (166 entries bound, no class or confidence
move; no `?_H.MES` entry is among the 167 classified rows).

**Verified** against the archive: the Python audit (`ok`) and the runtime flow validator for
each of the 13 profiles (25 checks each, 26 for `NANA_H`, no failure; a check each in
`config/validation/checks_v1.json`, 293 entries; 17.7-22.7 s each in the whole batch), the 20
shards of `original catalog group routes` (567 rows; one solo shard holding two ladders took
574 s), and the whole `full` tier at Core 0.370.0: 445 checks, 445 passed, 5,155 s, then 445
of 445 cached. The Playback pass lists picture and animation names of the ladders that the
shipped `mmo.arc` and `data.arc` do not hold (13 and 22 names over the two ladders of the
measured shard); *at Core 0.370.0 it was a report, not a failure, as for the earlier
rows. Since WD-21 U1 C3 (2026-10-06) every such name is a registered known absence
(`config/event_catalog/known_absent_media_v1.json`) and a Playback-pass miss the register
does not list fails the shard.*

## Not measured here

What hands the root to `43C.MES`; the native presentation of the secondary
menu and of `M_PIC.MES`.
