# Talk Family: the `?_TALK*.MES` Conversation Scripts and Their 4,905 Call Sites

Measured on 2026-10-04 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`
(1,016 entries). All coordinates are code-relative; ranges are `[start,end)`
where an end is given. No dialogue, bytecode dump or archive payload is
reproduced here. This began as a measurement unit (EP-12, the last family) that
promoted no catalog row, profile or contract; the declarations are recorded below: heroine K's nine
scripts ("Declared: heroine K", 2026-10-04) and the other eleven heroines', Tina's and the characters' 105 more
("Declared: all heroines, Tina and the characters N..Q", 2026-10-05). The first TALK facts of the
2026-09-24 census (142 scripts, 4,905 dispatch sites, 488 choices) were
re-measured from the archive and match it; its 241 DATE5/HOTEL "chain pairs"
do not reproduce under any definition tried: sites, (caller, callee) pairs and (caller, address entry,
callee) triples (see "The DATE5 and HOTEL ladders").
Related: [Normal Conversation](normal_conversation.md) (the 96 rung scripts'
first menu entry and the Maki caller's bands), [Promise Groups](promise_groups.md)
(the flags TALK sets and PROMIS clears; the equivalent-sites precedent),
[Gallery Families](gallery_families.md) (the measurement-unit precedent),
[43C Caller Group](43c_caller_group.md) (the room), [Heroine Date Flows](heroine_date_flows.md).

## What this document answers

| Question | Answer in one line | Confidence |
|---|---|---|
| What the family is | 142 scripts: 96 affection-banded **rung** scripts (heroines A..L, eight each), 28 **follow-ons** called from a rung, 9 plain `?_TALK.MES` once-only scripts, `M_TALK.MES` (Tina's single script) and 8 scripts of the non-heroine characters N, O, P and Q; every one is a callee that returns, none hands the root on | Confirmed |
| Who calls them | 4,905 sites (all command `0x0F`) from 136 caller entries: 56 place scripts, 12 DATE5, 13 HOTEL, 11 character scenes, `EVENTG01`, `GROUND`, `N_TEL` and 41 TALK scripts; 782 (caller, address-entry) owners | Confirmed |
| How a heroine's scripts are ordered | one fixed **eight-rung ladder on her affection word** (`< 31` ... `< 91` then `> 90` -> `TALK30` ... `TALK90`, `TALK00`), identical in all 537 ladder blocks (4,296 sites); not random, not day-indexed; whether she appears at a place is a separate guard (a per-visit roll of `global_u8[351]`, her presence flag, a calendar window and two per-heroine flags) | Confirmed |
| Guard shapes at the 4,905 sites | 537 ladder blocks (467 in one place-script template, 12 phone ladders in `43C.MES`, 24 DATE5, 13 HOTEL, 10 named scenes, 6 home variants, 4 singular, 1 EVENT) and 609 single-site blocks (`M_TALK` 331, `Q_TALK` 167, plain 49, other characters 21, follow-ons 41) | Confirmed |
| Flags | each heroine's own PROMIS guard flag is set by 2..7 of her rung scripts (56 in all) and cleared only by her PROMIS; each heroine has one gate flag her rung scripts test first; a plain script is gated by its own date, affection word and once-only flag | Confirmed (cells); meanings Unresolved |
| Inside a script | a **topic hub**: a gated menu of conversation topics, one routine-40 question, one body per topic; 488 questions in 97 scripts, 24,066 branches in all; 3-4% of a script's text plays under one state | Confirmed |
| Questions the contract tool can name | 485 of 488 in a fresh state, **421 of 488 in the natural presence state** (the first question of 64 rung scripts of eight heroines is rejected there, plus three of J's) - **485 in every state since Core 0.371.0**, which names the 64 (a per-position scratch-split chain, `docs/spec/mes/format_and_method.md`); J's three stay rejected | Confirmed for the four states tried |
| Terminals, nested calls, segments | every script returns; nested calls are `*_PIC.MES` (11 scripts), 41 follow-on calls; the longest answered path is 24 segments (default budget 512); runaway re-asks exist | Confirmed |
| DATE5/HOTEL -> TALK | 296 sites in 37 blocks on branches the 35 declared date routes do not take; a hop chain extends one route (trial passes audit and flow validator) | Confirmed for one heroine's trial |
| Twins | two message-identical pairs (`C_TALK01`/`C_TALK81`, `I_TALK71`/`I_TALK81`); 70% of the family's text records sit in runs of five or more that another TALK script also holds | Confirmed |
| Fit with the tools | v14 two- and three-hop flows build, audit and validate for a ladder rung and `M_TALK`; the natural presence state, the names registry (a TALK rule) and the v6 projector (inline nested lines, a TALK row's dependencies) fit since the K unit; the caller-continuation measurer still hangs (TD-48) | Confirmed for the trials and for heroine K |

## Inventory

### The 142 scripts

| Role | Scripts | Count |
|---|---|---:|
| Rung | `A_TALK..` to `L_TALK..`: `TALK30`, `40`, `50`, `60`, `70`, `80`, `90`, `00` for each of the 12 heroines | 96 |
| Follow-on | `A`: `51 61 71 81 91`; `B`: `01 61 71 81 91`; `C`: `01 81`; `D`: `01 81 91`; `E`: `61 71`; `F`: `01 81 91`; `G`: `71`; `I`: `61 71 81`; `J`: `71`; `L`: `91`; `H_TALKXX`, `K_TALKXX` | 28 |
| Plain | `A`, `C`, `E`, `F`, `G`, `H`, `I`, `K`, `L` `_TALK.MES` | 9 |
| Tina | `M_TALK.MES` (Tina has no ladder) | 1 |
| Non-heroine | `N_TALK`, `N_TALK1`, `N_TALK2`, `N_TALK3`, `O_TALK`, `P_TALK`, `Q_TALK`, `Q_TALK1` (letters N..Q have a `*_PIC.MES`; `N`, `P`, `Q` also a `*_TEL.MES`) | 8 |

A follow-on is called only from a rung script (41 nested calls from 41 rung scripts): a rung
`TALKn0` calls its own `TALKn1` (`TALK00` calls `TALK01`) where the heroine has one, H's eight rungs call
`H_TALKXX` and K's `00`, `50`..`90` call `K_TALKXX`; none has a place caller. Letters A..L are the twelve heroines, M is Tina
([Gallery Families](gallery_families.md) numbering); the repository's evidence does not name N..Q.

### Callers and site counts

Every one of the 4,905 sites is a nested call (command `0x0F`, literal target); no TALK
script is handed the root. Callers by class, with the sites each hosts:

| Caller class | Callers | Ladder blocks (sites) | `M_TALK` | `Q_TALK` | plain | other characters | follow-on | Sites (per caller) |
|---|---:|---|---:|---:|---:|---:|---:|---|
| place scripts `NN M` | 24 | 278 (2,224) | 218 | 107 | 12 | 5 | | 2,566 (82..124) |
| place scripts `NN C` | 22 | 178 (1,424) | 92 | 55 | 7 | | | 1,578 (16..109) |
| `27C*.MES` (the Saturday floor family) | 10 | 33 (264) | 21 | 5 | 27 | 12 | | 329 (25..58) |
| `?_DATE5.MES` | 12 | 24 (192) | | | | | | 192 (16 each) |
| `?_HOTEL.MES`, `L_HOTEL2.MES` | 13 | 13 (104) | | | | | | 104 (8 each) |
| character scenes (ten name-and-number scripts, `MINORU29`) | 11 | 10 (80) | | | | 2 | | 82 (8, `MINORU29` 2) |
| `EVENTG01.MES` | 1 | 1 (8) | | | | | | 8 |
| `GROUND.MES` | 1 | | | | 3 | | | 3 |
| `N_TEL.MES` | 1 | | | | | 2 | | 2 |
| TALK scripts (follow-on calls) | 41 | | | | | | 41 | 41 (1 each) |
| **136 callers** | | **537 (4,296)** | **331** | **167** | **49** | **21** | **41** | **4,905** |

The ten name-and-number scenes are `AI33`, `MAHOKO38`, `MAKI12`, `MAYUMI28`, `MIYUKI31`,
`MIZUHO26`, `NANA32`, `REIKO42` (also [REIKO42 Caller Group](reiko42_caller_group.md)),
`RYOKO36` and `SIZUKA44`; each hosts the owner heroine's ladder once. The largest callers:
`18M.MES` 124, `01M.MES`, `16M.MES` and `17M.MES` 119 each, `44M.MES` 117, `46M.MES` 116.
The address-table owners of the 4,905 sites number 782 (741 outside the TALK scripts):
most owners hold one block, 21 hold twelve (the twelve heroine blocks of one place
script). 4,321 distinct (caller, callee) pairs; 221 pairs have more than one site, 15
more than nine (all `M_TALK`, up to 18 from `18M.MES`). All 142 scripts have a caller.
**Already members of declared groups:** 18 of the 142 scripts (the eight `G_TALK*` rungs
of the `30C` EVENTG01 groups, `L_TALK50`/`60`, the plain scripts of the `27C_EV` and ground
groups, `N_TALK`, `Q_TALK1`) are source members of committed analysis groups, run as nested
callees inside EVENT routes; none has a catalog row of its own.

## Guards and scheduling

### The ladder is fixed

All 537 ladder blocks hold the same eight rungs, in the same order, on the same cell: the
heroine's affection word `banked_u16[0:199 + picker id]` (zero mismatches; ids are those of
[Gallery Families](gallery_families.md)):

| Rung | Affection | Callee |
|---|---|---|
| gate | `> 20` (and the today flag below clear) | all rungs |
| 1 | `< 31` | `?_TALK30` |
| 2 | `< 41` | `?_TALK40` |
| 3 | `< 51` | `?_TALK50` |
| 4 | `< 61` | `?_TALK60` |
| 5 | `< 71` | `?_TALK70` |
| 6 | `< 81` | `?_TALK80` |
| 7 | `< 91` | `?_TALK90` |
| 8 | `> 90` | `?_TALK00` |

So `TALK00` is the top band and the family has no day-indexed table and no random rung. The
anchor `01M.MES`, heroine K, ladder block: the rung tests at `83504`, `83548`, `83592`, `83636`,
`83680`, `83724`, `83768`, `83812` (each a branch whose false target is the next test) and the
calls at `83522`, `83566`, `83610`, `83654`, `83698`, `83742`, `83786`, `83830`
(`K_TALK30` .. `K_TALK00`, 16 bytes each). Within a place script the twelve heroine blocks
follow the picker order (F A E I G C H K L B J D; `M` has none): 52 of the 55 place
scripts with ladders keep it, the other three (`17M`, `28C`, `46M`) carry one extra or out-of-place block.

### The block around the ladder

450 of the 489 place ladders share one body, run inside the block guard and ending in the
same shared continuation: `?_PIC` -> `?_INTRO` -> the eight rungs -> `?_PROMIS` (behind the
heroine's PROMIS flag) -> `?_OUTRO` -> a jump to the place script's shared tail; 21 (heroine
J's) add `J_MINORU` before the outro; the 12 phone ladders in `43C.MES` start with `?_TEL`
instead of the picture and intro (J's adds `J_MINORU`); seven vary: `11C` J (two blocks: an
extra `J_PAY` call and a `MACHI.MES` handoff after the outro), `17M` A (a handoff after the
outro), `28C` L (an EVENTL13 handoff and two `FLOOR1.MES` handoffs around the ladder), `44C` L
(a second picture call) and `46M` J (`MACHI.MES` handoffs around it); `28C`'s handoffs sit in
its branches, not in one path.
The anchor again (`01M.MES`, K): block guard `83310..83403` (false `84103`), `K_PIC` call
`83442..83455`, `K_INTRO` `83460..83475`, the gate `83480..83499` (false `83888`), the
ladder, `K_PROMIS` guard `83851..83862` and call `83867..83883`, `K_OUTRO` `84073..84088`,
`JMP 87590` at `84098`. Resuming after the ladder (trial, below) the shared tail plays 6
messages and hands the root to `MACHI.MES` at `89476..89489`: **the block ends at the town
map**, not at a menu.

### The guard levels

Four nested levels enclose a rung call. Level 0 is the place script's own gate
`global_u8[350] == 0` (the place scripts roll `global_u8[350] = random_below(3)` in their entry
prologue; `01M.MES` at `279`). Level 1 is the block guard; level 2 the gate `affection > 20`
with the heroine's **today flag** clear; level 3 the rung. The block guard of 467 place
ladders is one template, instantiated per heroine and place:

```
(a weekday or date == 1224 [or date == 1301])  and  clock window
  and  global_u8[351] == picker id - 1
  and  the heroine's presence flag == 1  and  her block flag (90 + 10 * id) == 0
(an alternative arm adds a Saturday window; some places drop the date alternatives)
```

| Id | Letter | Menu stem | Ladder blocks | Affection word | `[351]` | Presence | Today (level 2) | Gate flag | PROMIS flag | TALK scripts that set the PROMIS flag |
|---:|---|---|---:|---|---:|---|---|---|---|---|
| 1 | F | REIKO | 49 | `[200]` | 0 | `[391]` | `[104]` | `[1512]` | `[1520]` | 5 (00 60 70 80 90) |
| 2 | A | MIKO | 44 | `[201]` | 1 | `[392]` | `[114]` | `[1002]` | `[1010]` | 7 (00 40 50 60 70 80 90) |
| 3 | E | MIZUHO | 55 | `[202]` | 2 | `[393]` | `[124]` | `[1800]` | `[1808]` | 5 (00 60 70 80 90) |
| 4 | I | MAYUMI | 47 | `[203]` | 3 | `[394]` | `[134]` | `[1227]` | `[1235]` | 6 (00 50 60 70 80 90) |
| 5 | G | RYOKO | 47 | `[204]` | 4 | `[395]` | `[144]` | `[1373]` | `[1381]` | 5 (00 60 70 80 90) |
| 6 | M | TINA | 0 | `[205]` | | `[403]` | | | | |
| 7 | C | NANA | 49 | `[206]` | 6 | `[396]` | `[164]` | `[1661]` | `[1669]` | 4 (00 70 80 90) |
| 8 | H | MIYUKI | 49 | `[207]` | 7 | `[397]` | `[174]` | `[2091]` | `[2099]` | 4 (00 70 80 90) |
| 9 | K | AI | 49 | `[208]` | 8 | `[398]` | `[184]` | `[2192]` | `[2200]` | 4 (00 70 80 90) |
| 10 | L | SIZUKA | 57 | `[209]` | 9 | `[399]` | `[194]` | `[1933]` | `[1941]` | 2 (00 90) |
| 11 | B | MAHOKO | 28 | `[210]` | 10 | `[400]` | `[204]` | `[675]` | `[598]` | 5 (00 60 70 80 90) |
| 12 | J | MINATU | 28 | `[211]` | 11 | `[401]` | `[214]` | `[794]` | `[803]` | 4 (00 70 80 90) |
| 13 | D | MAKI | 35 | `[212]` | 12 | `[402]` | `[224]` | `[686]` | `[721]` | 5 (00 60 70 80 90) |

(Cells are `banked_u16` for the word and `global_u8` for the rest. The PROMIS table of [Promise
Groups](promise_groups.md) is reproduced: the same twelve flags, the same setting scripts,
56 in all; the flag is cleared only by the heroine's own `?_PROMIS.MES`. The gate flag is the
first test of all eight rung scripts of eleven heroines (of J's only `TALK00` and `TALK70` start with it; `TALK30` tests
other cells, `TALK40`, `50`, `60`, `80` and `90` no cell); her TALK scripts set it, `?_DATE5` and `?_HOTEL` write it 1 and then 0 around their ladders and her
`?_OUTRO` clears it. The today flag is set by her own `?_INTRO.MES` and `?_TEL.MES`. The names are
labels of position, what the cells **mean** is not established.)

**Scheduling is a roll, a window and flags.** The place scripts draw `global_u8[351]` at
entry (`01M.MES` `291`: `random_below(13)`, with `global_u8[350] = random_below(3)` at `279`).
28 place scripts draw `random_below(13)` and host all 13 selectors; 23 (`10C` also draws other bounds,
`23M`, `24M`, `25C`, `26M`, `27C1A`..`27C3C`, `28C`..`34C`, `35M`, `47C`) draw `random_below(10)` and never
reach the selectors 10..12:
heroines B, J and D have place ladder blocks only in the 28 places (21, 22 and 28 blocks), which is
why they have 28, 28 and 35 blocks in all against 44..57 for the others. Each TALK rung script
re-rolls `[350]` and `[351]` with `random_below(3)` at its own entry (offsets `113` and `125`).
The presence flags are written 1 and never cleared by a literal write: by `OPEN.MES` (`[391]`..`[393]`
and `[399]`), `GROUND.MES` (`[395]`, `[396]`), the heroine's own scripts (`I_TALK` `[394]`, the `B_TALK*`
rungs `[400]`, `J_INTRO` `[401]`, `D_INTRO` and the `D_TALK*` rungs `[402]`), four place scripts
(`01M`, `11M`, `15C`, `18M`: `[397]`, `[398]`) and `EVENTM01.MES` (`[403]`). The 537 ladder blocks have
32 distinct guard-chain shapes when numbers and cell indices are stripped (the eight largest cover
401 blocks); the per-place windows differ only in their constants.

### Ladder blocks by context (537)

| Context | Blocks | Guard |
|---|---:|---|
| place-script template | 467 | the block guard above, level 0, level 2 |
| `43C.MES` phone ladders | 12 | the room-action menu's answer 1 (`state_u16[21] == 1` at `20196`; [43C Caller Group](43c_caller_group.md) names the row) then `state_u16[13] == picker id` (the secondary menu's result), level 2 with the heroine's second cell `== 2`; 96 sites from `20617` |
| `?_DATE5.MES` | 24 | block 1: `clock < 1800` and a per-heroine special-date arm (`date == 1224` with `[flag] == 0`, or a second date with a `[30x]` event flag); block 2: the after-date menu's answer `state_u16[21] == 5` |
| `?_HOTEL.MES` / `L_HOTEL2.MES` | 13 | the hotel menu's answer `== 6` (`L_HOTEL2`: `== 2`) |
| character scenes | 10 | the heroine's block-cell pair clear (`[100 + 10 (id - 1)]` and the next; none in `MAHOKO38`), then level 2; no calendar arm |
| `11C`/`12C`/`13C` home variants | 6 | a pair of blocks each (a flag 0 and a flag 1): `13C` B `[368]`, `12C` D `[369]`, `11C` J `[810]` |
| singular | 4 | `17M` A, `28C` L, `44C` L, `46M` J |
| `EVENTG01.MES` | 1 | the rung tests alone (no level 2, no outer guard inside the EVENT callee) |

### The single-site blocks

- **`M_TALK.MES`** (331 sites, 40 callers): one guarded block per site, a picture script then `M_TALK`
  (`M_PIC` mostly, `O_PIC` 49 and `P_PIC` 18; about 30 blocks hand the root to `MACHI.MES` afterwards). The
  guard is an EVENT-style calendar window (a Saturday arm and a weekday arm, a date bound, a clock window)
  and four flags; 15 distinct normalized shapes. Anchor `01M.MES` `47809..47890` (false `48455`),
  `O_PIC` call `47911`, `M_TALK` call `47934..47948`.
- **`Q_TALK.MES`** (167 sites, 33 callers): the same shape, `Q_PIC` then `Q_TALK` (`L_PIC` first in 18;
  14 blocks end in a `MACHI.MES` handoff), 11 shapes.
- **Plain `?_TALK.MES`** (49 sites, 27 of them in the `27C*` family): the callee gates itself and writes its
  own done flag at its end; the done flags `global_u8[2529..2539]` are each written and read by their
  script alone (`[2533]` belongs to `L_HOTEL`/`44C`). The call-site guards are calendar blocks of the day loop.

  | Script | `state_u16[7] >` | Word `>` | Done flag |
  |---|---:|---:|---|
  | `A_TALK` | 1423 | `[201]` 50 | `[2537]` |
  | `C_TALK` | 1423 | `[206]` 70 | `[2536]` |
  | `E_TALK` | 1502 | `[202]` 30 | `[2534]` |
  | `F_TALK` | 1502 | `[200]` 60 | `[2531]` |
  | `G_TALK` | 1502 | `[204]` 50 | `[2535]` |
  | `H_TALK` | 1423 | `[207]` 80 | `[2539]` |
  | `I_TALK` | 1502 | `[203]` 50 | `[2530]` |
  | `K_TALK` | 1423 | `[208]` 70 | `[2538]` |
  | `L_TALK` | 1502 | `[209]` 40 | `[2532]` |

  `Q_TALK1` is gated by `[254] != 0`, `date > 1502` and `[2529]`.
- **`N_TALK*`, `O_TALK`, `P_TALK` and `Q_TALK1`**: one to six call sites each (12 in the `27C*` family, five in
  `06M`, `11M`, `18M` and `44M`, two in `MINORU29`, two in `N_TEL`).
- **Follow-ons**: 27 behind the parent's own `state_u16[21] == k` consumer arm, 14 behind a flag test.

## Inside a TALK script

**A topic hub.** A rung script clears the scratch cells `global_u8[10..50]`, then registers its menu: a chain of single
`command 0x10` definitions, each behind its own test (the heroine's presence flag, the topic's own done
flag, exclusions), then clears groups 1..10 and asks one routine-40 question. The consumer is a
one-based branch chain on `state_u16[21]`; position 1 of the first question is the ordinary-conversation
body ([Normal Conversation](normal_conversation.md), 96 exact-label owners, all of them confirmed as rung
scripts here). Anchor `K_TALK30.MES`: `command_1b` group 0 at `600`, definitions from `621`, the question at
`1370`, the first consumer test `1395..1405`. Under a fresh state two options register (in
`A_TALK30` and the K rungs the first leads to the ordinary-conversation body, the second plays three messages
and asks again); flags register more.

**Questions: 488 in 97 scripts** (45 scripts have none: 28 follow-ons and 17 others, the census count of 488
choices is exact). Under the fresh state the contract tool (`kakyu_mes_routine40_choice_contract/v5`) names
485 (469 contiguous, 16 sparse; every consumer an exact one-based chain) and rejects 3 (the last question of
`J_TALK40`, `J_TALK50` and `J_TALK60`, at `33687`, `38723` and `47914`, six registered ids each, "neither an
exact one-based chain nor a complete gated matrix"). Option counts of the 485: 1 (8), 2 (72), 3 (401), 5 (1), 8 (3). The result does not move with the
ambient clock, the date or the all-flags-set state (485 under three states). **It moves with the natural
state:** with the heroine's presence flag and her L1 cells set (the state at which a place calls the ladder)
the first question of the eight rung scripts of C, E, F, G, H, I, K and L registers the ids 0, 2, 3, 4 and 5
(id 1 hidden) and the tool rejects it with the same message: 64 sites, plus the three of J, **67 of 488
rejected, 421 named**; A's, B's and D's scripts stay named. A route through such a question cannot be
declared with today's tool.

**Decline arms re-ask.** An option that plays a few messages and returns to the question that was asked
(for example `A_TALK00`, `A_TALK30` and the K rungs) is a loop, not a return: 88 scripts have
such an answer path. A depth-first walk of every option of every nameable question under the fresh state
finds **318 answer paths for the 142 scripts: 214 reach the script's own return, 103 loop back (90 to the
question itself, 13 to another point of the script), 1 runs away** (7 under the ambient state: that one and
the B rung scripts' second question after the first question's option 2, each re-asking with changing state
until the 4,096-segment budget stops it). The 214 returning paths are the 142 default paths and 72 option
variants by the stop rule of [Content Tools](../tech/content_tools.md) (a path that does not end at the
route's own return stays `unresolved`, as the PROMIS location question's re-ask does).

**What a run plays.** From its start under the fresh or the ambient state every one of the 142 scripts
returns (284 runs, none stops); the first-option path plays 0..45 messages (median 14, 2,178 over the
family; rung scripts 4..45, follow-ons 7..16, plain 7..29) in at most **24 segments**: no answered path
comes near the probe's default 512 (the hop `segment_budget` of
[Content Tools](../tech/content_tools.md) is not needed for a TALK script; the runaway re-asks need no
budget either, they are not a return). The scripts hold 94,217 text records and 24,066 branches; each rung script
tests a median of 49 distinct `global_u8` cells (maximum 112), 1,091 distinct cells family-wide
(presentation and scratch cells excluded). **One state plays 3-4% of that text:
3,868 records (4.1%) are executed by some answer path under the fresh state, 4,108 (4.4%) under the
ambient state, per script 0..45%, median 3%.** One flag at a time opens more: for the eight rung scripts of
K and `A_TALK30`, 33..81 single-flag toggles each change the run in 6..8 cases and the union over all
toggles reaches 18..42% of the text. A TALK row therefore needs a stated state policy; the H ladders'
"full recollection" has no counterpart here until the topic gates are recounted.

**Terminals and nested calls.** No TALK script has a handoff or an exit other than a return into its
caller (every typed instruction was scanned). Nested calls inside TALK scripts: `*_PIC.MES` from
`C_TALK` (`N_PIC`, `P_PIC`), `E_TALK` and `G_TALK` (`N_PIC`), `I_TALK` (`I_PIC`), `J_TALK00/70/80/90`
(`J_PIC`), `L_TALK` (`P_PIC`), `M_TALK` (`M_PIC`) and `N_TALK` (`E_PIC`, `L_PIC`); the 41 follow-on calls.
The scripts write the heroine's affection word (adding or subtracting a few points, or setting it; 130 of
the 142 scripts write their own word) and, for the rungs, her gate flag; `state_u16[13]` is written only by
`LIBLARY.LIB` and `OMAKE.MES` ([Gallery Families](gallery_families.md)). The caller resumes at the
dispatch end: for a place ladder that is the PROMIS and OUTRO calls and the town handoff described above.

## The DATE5 and HOTEL ladders

**What the 241 was.** The census's "241 chain pairs" is not reproduced. Measured: the DATE5 and HOTEL
scripts hold **296 TALK sites in 37 blocks** (24 DATE5 blocks: 192 sites; 12 `?_HOTEL.MES` blocks and
`L_HOTEL2.MES`: 104 sites), which are **200 distinct (caller, callee) pairs** over 96 callees (the 96
rung scripts; no follow-on, plain or other script is called from a date tail). The 56 `?_DATE3 -> ?_DATE5`
references (the `?_DATE3` handoffs to `?_DATE5`) are the date flows' own hop.

**Where they sit.** In `?_DATE5.MES` block 1 is inside `clock < 1800` and a special-date arm (for A:
`date` 1318 or 1319 with `[1008]` clear and `[304]` set, or 1224 with `[1007]` clear; anchor
`A_DATE5.MES` ladder at `1509`); block 2 is the answer 5 arm of the after-date menu loop
(`A_DATE5.MES` `14538`), a menu the loop returns to after the ladder (`JMP 16979` -> `JMP 4368`). In
`?_HOTEL.MES` the ladder is the menu's answer 6 (`A_HOTEL.MES` `13756`). Neither is a tail of the declared
route: running all 35 declared date routes (`kakyu_event_analysis_group/v14`, default variants, all hops)
and listing every nested dispatch shows **no TALK call in any of them**; the DATE5 hop dispatches only
the picture script and the final `MACHI.MES` handoff, the hotel chain only its own parts.

**An extension is a hop chain.** Trial (scratch, heroine K, nothing declared): the installed
`k-date-date5` route's hops 1..20, then hop `d21` = `K_DATE5.MES` from its start to the `K_TALK00` call
at `5075..5091` with the special-date arm seeded by a tool gate (`state_u16[7] = 1224`, `[2197] = 0`;
the route's own affection gate already seeds the top band), `d22` = `K_TALK00.MES` entered by that call
to its return (17 messages, its one question answered at its first option), `d23` = `K_DATE5.MES`
resuming to the same `MACHI.MES` handoff the installed route ends at (`6511`, 4 messages; hop `d21` plays
16). The 23-hop route builds with `tools/build_event_flow_profile.py`, passes `audit_event_analysis_group.py`
and the runtime flow validator (79 checks, no failure, 46 s). It is a route of its own, not a variant of the
installed one: its first hop ends at another record (a variant cannot change a hop's outcome, [Content
Tools](../tech/content_tools.md) "Variant `answers` and `message_counts`"). The route-consistent rung is
`TALK00` (the installed date5 route tool-seeds an affection of at least 111); the other seven rungs would
be seven more routes per block. Block 2 and the hotel ladder end the same way or at the TALK return (the menu loop is not a hop).

## Twins

- **Identical message sequences:** `C_TALK01` = `C_TALK81` (477 records) and `I_TALK71` = `I_TALK81`
  (556), both follow-on pairs and both already in `config/event_catalog/duplicate_entries_v1.json` as
  `non_gallery` groups. No TALK script is a twin of a non-TALK entry.
- **Shared runs:** 65,685 of the 94,217 text records (70%) lie in runs of five or more consecutive
  identical records that another TALK script also holds (26 scripts have more than 90% of their records
  in such runs, 18 less than 10%: seven plain scripts, `M`, `N`..`Q`, `H_TALKXX`, `K_TALKXX`, `L_TALK91`); only 465 records share such a run
  with a non-TALK entry (mostly `I_TEL`, `I_INTRO`, `J_DATE3`, `E_HOTEL2`). The rung scripts of one heroine are
  largely re-statements of one another's topics.
- **Equivalent sites:** the 4,296 ladder sites call 96 scripts, 44.75 sites per script (28..57 blocks
  per heroine); a place block is the same eight callees behind a different place guard. `M_TALK` has 331
  sites, `Q_TALK` 167.

## Fit with the route toolchain

Scratch trials (untracked probes and specs under `analysis/_undoc/ep12_talk/`; nothing declared) with the
route probe, the Python flow builder, auditor and the Godot flow validator:

| Trial | Result |
|---|---|
| `01M.MES` K block, rungs `TALK30`, `TALK90`, `TALK00`, natural presence state (a two-hop v14 flow: the block guard `83310..83403` through `K_PIC`, `K_INTRO` to the rung call, then the rung from its start) | hop 1 runs (8 messages for `TALK30` and `TALK00`, 17 for `TALK90`: the intro's count differs by band); hop 2 stops at the first question, "no catalog choice", the contract tool rejecting it |
| same with a tool-seeded gate `global_u8[398] = 0` (the presence flag) before hop 2 - a state hop 1's own guard excludes (`83310` requires `[398] == 1`), so a placeholder, not the anchored state | `TALK30`: 4 messages, one question, return at `18022`; `TALK90`: 18, return `58530` (the follow-on `K_TALKXX` a member); `TALK00`: 17, return `60038`; the three-route profile builds, audits `ok` and the flow validator passes **44 checks, no failure** (28 s) |
| the `TALK30` flow with a third hop (the caller resumes: `K_OUTRO`, the shared tail) | 6 more messages, `script_handoff_boundary` to `MACHI.MES` at `89476`; audit `ok`, 25 checks (23 s) |
| `M_TALK` at `01M.MES` `47934` (guard `47809..47890`, `O_PIC` in hop 1) | two hops, 0 + 13 messages, return at `36649`; audit `ok`, 21 checks (20 s) |
| DATE5 extension, heroine K | 23 hops, see above; audit `ok`, 79 checks (46 s) |
| caller-continuation drafter `tools/draft_event_route_spec.py` with a hand-written one-intro inventory (`01M.MES` guard `83310`, call `83522`, callee `K_TALK30`) | drafts a spec and review sheet; the OR guard needs manual seeds, the gate and rung tests (levels 2 and 3) are listed as gap branches the baseline must satisfy by hand, the callee's 58 free branches yield 100 "add a variant per arm" notes, the question is the first routine-40 only |
| `tools/qualify_event_route.py` on that spec, baseline completed by hand | the probe step (`measure_event_route.gd`) stops consuming CPU and the wrapper's 900 s timeout kills it; the failure is not an error message. The known undeclared-routine-40 hang of [Promise Groups](promise_groups.md) ("Toolchain fixes") is the likely cause; the question is unnameable in the guard-satisfying state |
| `tools/build_event_names.py` (read, not run: its premise counts stop a run first) | a flow route whose callee is `<letter>_TALKnn` falls in the generic flow branch and stops: the route id must start `<letter>-date-`; the site ordinal in the id regex is one digit (`[1-9]`), the 15 pairs with 10..18 sites (`M_TALK`) do not fit |
| inventory builders | `tools/build_event_analysis_inventory.py` takes an EVENT-only classification (it refuses one that omits an EVENT entry) and has no TALK callee input; the drafter itself takes any inventory JSON, so the limit is the producer |

What works: a rung or a single script as a two-hop (or three-hop) v14 flow entered at its place guard, and a
date extension as a hop chain, with the existing builder, auditor and validator. What failed or was missing then:
the question at the natural presence state (a contract-tool gap, closed by Core 0.371.0), the
caller-continuation measurer (still open, TD-48), a TALK rule in the names registry and its count premises (the K
unit), and a state policy (the natural state, "Declared: heroine K").

## Declared: heroine K (EP-12 TALK K unit, 2026-10-04)

Heroine K's conversation scripts are the first TALK declaration: **nine catalog rows in two
`kakyu_event_analysis_group/v14` groups**, the owner's shape A' (one row per called script, anchored at the
script's confirmed caller, the caller's natural state; ruling 2026-10-04, `todo/event_player.md` EP-12). Core
**0.371.0** (the routine-40 contract tool names the first question of the natural presence state,
`docs/spec/mes/format_and_method.md`); catalog revision **38** (567 -> 576 rows, the 567 earlier rows byte-identical);
the registry rows `ai.town.station.talk-<band>.1` and `ai.town.27c_ev.talk-plain.1`.

| Row (route) | Anchor | Hop 1: caller to the call (messages) | Hop 2: script to its return (messages, return record) | Hop 3: caller to the handoff | Variants |
|---|---|---|---|---|---|
| `talk-30` (`k-talk-30`) | `01M.MES` guard `83310`, call `83522` | 8 | 4, `18022` | 6, `MACHI.MES` `89476` | default |
| `talk-40` | call `83566` | 8 | 8, `18909` | 6 | default |
| `talk-50` | call `83610` | 9 | 13, `25312` | 6 | default, `flag-2194` (hop 2: 5) |
| `talk-60` | call `83654` | 8 | 13, `25884` | 6 | default, `flag-2194` (5) |
| `talk-70` | call `83698` | 20 | 13, `28469` | 6 | default, `flag-2194` (5) |
| `talk-80` | call `83742` | 8 | 18, `58393` | 6 | default, `flag-2194` (10) |
| `talk-90` | call `83786` | 17 | 18, `58530` | 6 | default, `flag-2194` (10) |
| `talk-00` | call `83830` | 8 | 17, `60038` | 6 | default, `flag-2194` (9) |
| `talk-plain` (`k-talk-plain`) | `27C_EV.MES` guard `31225`, call `31343` | 0 | 25, `1357` | none (two hops) | default |

The eight rungs are one group `01m-k-talk` (`01m_k_talk_v14.json`), the plain script a group of its own,
`27c-ev-k-talk` (`27c_ev_k_talk_v14.json`). A rung is a route (a variant cannot change a hop's outcome); its hop 1
runs `01M.MES` from the block guard through `K_PIC` (`83442`), `K_INTRO` (`83460`), the gate (`83480`) and the rung's
test (`83504` .. `83812`) to the rung's call, hop 2 the script, hop 3 the caller resuming (`K_PROMIS` only when the
flag is up - it is not on any default path -, `K_OUTRO` at `84073`, the shared tail) to the town handoff at
`89476..89489`, 6 messages in 8 segments; hop 2 takes 5, 7, 12, 12, 12, 15, 15 and 14 segments for `talk-30` .. `talk-00`
(no `segment_budget`). The source members of a route are the entries its runs visit: the caller, the script, `K_PIC`,
`K_INTRO`, `K_OUTRO` and, for the rungs 50..00, `K_TALKXX`, with the three supports (`LIBLARY.LIB`, `DEF_MAIN.MES`,
`START.MES`).

**Seeded state (tool decisions, in each route's `unresolved`).** The origin is the block guard (the place's own
level-0 gate and the day loop before it are not part of the route). The drafter solves the guard's first alternative
and the gate: weekday `state_u16[4] = 0`, the clock `state_u16[19] = 1200` (the first full hour in the guard's window),
the date `state_u16[7] = 401`, `state_u16[8] = 0`, `global_u8[350] = 0` (not evaluated), the place's draw
`global_u8[351] = 8` (id - 1), **the presence flag `global_u8[398] = 1` (the natural presence state the guard requires)**,
her block flag `[180]` and today flag `[184]` clear, and the affection word `banked_u16[208]` inside the rung's band
(25, 35, 45, 55, 65, 75, 85, 100). The topic state is the natural one: every topic's done flag and the scratch cells
the script clears at its start are 0, and every default answers option 1. The rejected guard witness writes the
presence flag 0. The plain script's state is the guard of `27C_EV.MES:31225` (`[180]`, `[184]`, `[185]`, `[2225]` clear,
`[188] = 1`) together with the script's own gate (its date above `1423` - `1430` -, its affection word above 70 - `80` - and
its once-only flag `[2538]` clear).

**The question and its contract.** Every rung asks one question at its start (`1370` for `talk-30` .. `talk-70`, `1358` for
`talk-80`, `talk-90`, `talk-00`) with five registered options (ids 0, 2, 3, 4, 5; id 1 hidden: `catalog_form: sparse`), a
consumer that is a one-based chain whose positions split on scratch cells (`one_based_state_u16_21_scratch_split_branch_chain`).
Option 1 is the ordinary conversation and the way out; the default path answers it.

**Variants and what stays unresolved.** The other answered paths of every rung all fail the stop rule: of the four per
rung (options 2..5) three come back to the question unchanged (a proven loop) and one finds the answered option gone when
the question returns (its topic is spent), so **no answer is a variant and 32 re-asking paths (4 x 8) are recorded in the
rungs' `unresolved` lines**, the topic hub's decline arms, not declared. The only variants are `flag-2194` on the six
rungs that call the follow-on `K_TALKXX.MES` (six call sites, each inside option 1's arm behind `global_u8[2194] == 0`, its
own done flag): the flag set plays the script without the follow-on (hop 2: 5, 5, 5, 10, 10, 9 messages against 13, 13,
13, 18, 18, 17). `K_TALKXX` is a member of those six routes, not a row. Other topic states (flags other events set; the
walk reaches 3-4% of a script's text) are not walked.

**The plain script is a two-hop route.** `K_TALK.MES` at `27C_EV.MES:31343` (verified: guard `31225..31268`, `K_PIC` at
`31325`, the call at `31343..31357`) plays 25 messages and returns at `1357`. Its caller resumes into the place's day loop
(a jump to `48649`), which has no natural end the probe can measure: definition 12 stops at the step limit under the
fresh state and, under the original calendar, the loop plays on, day after day, to the game's ending (`END1.MES`). The
flow therefore ends at the script's own return, like an album scene, and the existing returning-flow rule reads its
route outcome as `place_menu`; the three-hop rungs end at the `MACHI.MES` handoff, the existing handoff outcome
(`map_return`, town: "Back to the town map"; `tools/event_outcome_vocabulary.py`, unchanged).

**Tools.** `tools/draft_talk_flow_specs.py` and `tools/content_suite/cli/measure_talk_flow.gd`
(`docs/spec/tech/content_tools.md`, "EP-12 TALK tools"); the registry rule (`talk-<band>`), the catalog tag
(`display.categories` `["conversation", "town"]`), the v6 producer's two TALK rules
(`docs/spec/data/event_definition_v6.md`, "TALK flows") and the shared predicate `is_talk_registry_row`
(`tools/payload_values.py`). Python audit ok; the flow validator 164 checks for `01m-k-talk` and 20 for `27c-ev-k-talk`.

### Equivalent sites of heroine K

Each K row is one site of many; the others are recorded here as equivalents, the PROMIS precedent
([Promise Groups](promise_groups.md), "Equivalent sites"), not rows. K's ladder is called from **49 blocks, 392 sites**
in 48 callers: the declared `01M.MES` block (a place script, the anchor), 23 other `NN M` place scripts (`02M` .. `11M`,
`16M` .. `21M`, `23M`, `24M`, `26M`, `35M`, `44M` .. `46M`), 17 `NN C` place scripts (`02C`, `06C`, `09C`, `10C`, `15C`, `19C`,
`20C`, `21C`, `25C`, `28C`, `29C` .. `34C`, `47C`), three scripts of the Saturday floor family (`27C2A`, `27C2B`, `27C2C`),
the room's phone ladder (`43C.MES` `27713`), the character scene `AI33.MES` (`11330`), `K_DATE5.MES` (two blocks, `4767` and
`21571`, the special-date arm and the after-date menu) and `K_HOTEL.MES` (`21686`); each calls the same eight rung scripts
behind its own guard (the place's calendar window, clock window and flags). The plain `K_TALK.MES` has a second site, `27C_EV.MES`
`53485`, beside the declared `31343`, and `K_TALKXX.MES` six call sites (the rungs 50..00 above, no place caller).

## Declared: all heroines, Tina and the characters N..Q (EP-12 TALK rest unit, 2026-10-05)

The other eleven heroines' conversation scripts, Tina's `M_TALK` and the characters' `N_TALK`..`Q_TALK1` are declared
the way heroine K's were: **105 more catalog rows (114 TALK rows in all: 96 rung scripts, 9 plain scripts, `M_TALK`
and 8 character scripts) in 28 `kakyu_event_analysis_group/v14` groups** (26 new, the two of K kept), one row per called
script anchored at its caller, the caller's natural state. Core **0.372.0** (the routine-40 contract schema is
`v6`, `docs/spec/mes/format_and_method.md`, "The schema is v6"); catalog revision **39** (576 -> 681 rows, the 576
earlier rows unchanged except heroine K's eight rung rows, whose group profile hash moved with her contracts' schema
string); the registry rows `<name>.town.station.talk-<band>.1` (the rungs), `<name>.town.27c_ev.talk-plain.1` (the
plain scripts), `tina.town.station.talk-plain.1` and `common.town.<place>.talk-<letter><digit>.1` (the characters; the
numbering rule is in `config/contracts/event_names_v1/README.md`). **Heroine K was re-measured with the rest** (her
specs differ from the installed ones in the eight contract schema strings alone, her plain spec not at all): her
eight contracts moved from `v5` to `v6`, nothing else.

**Rungs: 96 routes, all in the natural state.** Every rung of the twelve heroines runs the three hops (the `01M.MES`
block guard through `?_PIC`, `?_INTRO`, the gate and the rung's test to the call; the script to its return answering
option 1 at every question; the caller resuming through `?_OUTRO` to the `MACHI.MES` handoff `89476..89489`) and ends at
that handoff: hop 3 plays 6 messages in 8 segments for 95 of the 96 rungs and 12 messages in 10 segments for
`C_TALK50` (the same handoff; why that one default path leaves a longer tail was not diagnosed). The `?_PROMIS`
call is not reached on any default path measured. The default path asks one question in 61 rungs and two in 35;
every question is named by the contract tool in the natural state (the scratch-split chain, `catalog_form: sparse`, at the
first question of the rungs of C, E, F, G, H, I, K and L; the plain one-based chain elsewhere).

| Heroine | Hop 1 (30..00) | Hop 2 (30..00) | Hop 3 | Variants | Re-asking paths | Runaway / unnamed paths | Plain script (hop 2, return) |
|---|---|---|---|---|---|---|---|
| A (Miko) | 4/12/11/5/8/11/16/20 | 23/21/21/14/14/18/14/15 | 6 | 6 (`option-1-2` x3, `option-1-3` x3) | 32 | 0 | 13, `2345` |
| B (Mahoko) | 5/5/7/5/7/8/17/7 | 21/17/29/22/22/22/22/20 | 6 | 2 (`option-1-2`, `option-1-3`) | 39 | 17 | - |
| C (Nana) | 8/8/8/8/16/8/12/12 | 12/31/31/31/14/14/18/22 | 12/6 | 6 (`option-1-2` x3, `option-1-3` x3) | 32 | 0 | 17, `1226` |
| D (Maki) | 5/7/10/4/9/11/8/8 | 32/32/39/25/29/30/34/34 | 6 | 6 (`option-1-2` x3, `option-1-3` x3) | 41 | 1 | - |
| E (Mizuho) | 4/4/8/8/8/8/12/8 | 8/49/46/21/21/25/21/29 | 6 | 6 (`option-1-2` x2, `option-1-3` x2, `option-5` x2) | 30 | 0 | 34, `3857` |
| F (Reiko) | 16/16/17/20/16/9/8/12 | 16/16/16/16/16/20/20/8 | 6 | 10 (`option-1-2` x5, `option-1-3` x5) | 32 | 0 | 13, `1900` |
| G (Ryoko) | 12/12/12/4/14/8/8/12 | 28/28/28/28/28/17/17/17 | 6 | 10 (`option-1-2` x5, `option-1-3` x5) | 32 | 0 | 19, `2274` |
| H (Miyuki) | 10/10/20/8/4/5/12/4 | 17/17/17/17/17/17/25/21 | 6 | 8 (`flag-2093` x8) | 32 | 0 | 21, `1296` |
| I (Mayumi) | 4/4/11/12/7/9/32/29 | 8/8/21/21/8/16/20/20 | 6 | 6 (`option-1-2` x2, `option-1-3` x2, `option-5` x2) | 38 | 0 | 19, `2285` |
| J (Minatu) | 5/10/8/11/13/16/12/9 | 8/24/24/24/24/21/17/14 | 6 | 8 (`option-1-2` x4, `option-1-3` x4) | 36 | 5 + 3 unnamed | - |
| K (Ai) | 8/8/9/8/20/8/17/8 | 4/8/13/13/13/18/18/17 | 6 | 6 (`flag-2194` x6) | 32 | 0 | 25, `1357` |
| L (Sizuka) | 4/5/8/9/12/12/12/12 | 8/22/22/22/22/22/22/22 | 6 | 14 (`option-1-2` x7, `option-1-3` x7) | 36 | 0 | 40, `3582` |

Per heroine, hop 1 is the caller from the block guard to the call (messages), hop 2 the script, hop 3 the caller to the
handoff (messages; the one 12 is `C_TALK50`); *variants* are the answered paths that end at both of the route's
outcomes (`option-<values asked>`, the `answers` form: a second question answered differently after option 1; `flag-<cell>`,
the follow-on behind its own done flag: `H_TALKXX`'s `[2093]`, `K_TALKXX`'s `[2194]`); *re-asking paths* are the answered paths
that come back to a question they answered (339 back to it unchanged, 73 with the answered option gone), the topic
hub's decline arms, recorded in each route's `unresolved` with their count and not declared; *runaway* paths are
answered paths that re-ask with changing state until the 512-segment limit stops them (`B_TALK50`..`00`, `D_TALK40`,
`J_TALK40`, `J_TALK60` and `J_TALK70`: 23, each named in its route's `unresolved`, none a variant). Over the 96 rungs: 608 answered paths
measured (the 18 band-less routes have one each), 88 variants, 412 re-asking paths, 23 runaway paths, 3 unnamed-question paths.

**Heroine J's three unnamed questions stay unresolved.** `J_TALK40`, `J_TALK50` and `J_TALK60` hold the question the
contract tool cannot name (`33687`, `38723`, `47914`, six registered ids, "neither an exact one-based chain nor a complete
gated matrix nor a per-position scratch-split chain"). The default path of each answers option 1 at two named
questions and reaches its return in 24 messages without meeting it, so the three routes are declared in full; the question is on
the path that answers option 5 at the first question and option 1 at the next (`option-5-1`, 18 messages, the next question at
`33215`, `38251`, `47442`), which each route's `unresolved` names as a path that does not run to the route's terminal (not a
variant, the stop rule).

**State decisions this unit added (tool decisions, each named in the route's `unresolved`).** Heroine C's gate
carries a further conjunct (`global_u8[1775] == 0`), J's two (`[401] == 1`, `[824] == 0`): seeded. `C_INTRO.MES` caps
the affection word at 50 while the date is below 916 (`date < 916 and affection > 50` -> 50, a branch at `241`, before the
rung's test): a rung above 50 is unreachable on the ambient date 401, so C's eight rungs seed the date 916 (the
first date the cap is off); the other eleven keep 401. J's block calls `J_MINORU.MES` before the outro on a branch the
default path does not take (a block member, not an entry of any measured route). The other cells are the K unit's.

**Band-less scripts, the anchors.** A script's anchor is the lowest-offset site of its preferred caller whose block is
its own: `27C_EV.MES` for the nine plain scripts (heroine K's anchor; every plain script has sites there), `N_TALK`,
`N_TALK1`, `O_TALK`, `P_TALK` and `Q_TALK1`; `01M.MES` for `M_TALK` (the study's anchor) and `Q_TALK` (no site in
`27C_EV.MES`); `11M.MES` for `N_TALK2` and `N_TALK3` (the first of their three callers; `MINORU29.MES` and `N_TEL.MES` are the
others). "Its own block": a guard that encloses the call with only picture scripts dispatched between the guard and
the call (`E_TALK` at `27C_EV.MES:1746` and `F_TALK` at `1814` follow `N_TALK`'s block, which would play `N_TALK` inside hop 1;
`I_TALK` at `11661` and `12390` test a special date its own gate excludes: the drafter stops on both, the next
site is the anchor). A heroine's plain script is seeded from the guard and its own once-only gate (its first branch: a date, the
affection word and its done flag), a character's script, a chain of bodies each selected by flags and dates, from the guard
alone (every other cell 0: the body that state selects plays).

| Script | Route | Anchor (caller, guard, call) | Hop 1 | Hop 2 (messages, return) | Hop 3 | Questions | Group |
|---|---|---|---:|---|---|---:|---|
| `A_TALK` | `a-talk-plain` | `27C_EV.MES` guard `16236`, call `16416` | 0 | 13, `2345` | none (two hops) | 0 | `27c-ev-a-talk` |
| `C_TALK` | `c-talk-plain` | `27C_EV.MES` guard `29578`, call `29752` | 0 | 17, `1226` | none (two hops) | 0 | `27c-ev-c-talk` |
| `E_TALK` | `e-talk-plain` | `27C_EV.MES` guard `17579`, call `17697` | 0 | 34, `3857` | none (two hops) | 0 | `27c-ev-e-talk` |
| `F_TALK` | `f-talk-plain` | `27C_EV.MES` guard `12959`, call `13077` | 0 | 13, `1900` | none (two hops) | 0 | `27c-ev-f-talk` |
| `G_TALK` | `g-talk-plain` | `27C_EV.MES` guard `10598`, call `10691` | 0 | 19, `2274` | none (two hops) | 0 | `27c-ev-g-talk` |
| `H_TALK` | `h-talk-plain` | `27C_EV.MES` guard `30660`, call `30778` | 0 | 21, `1296` | none (two hops) | 0 | `27c-ev-h-talk` |
| `I_TALK` | `i-talk-plain` | `27C_EV.MES` guard `21419`, call `21537` | 0 | 19, `2285` | none (two hops) | 0 | `27c-ev-i-talk` |
| `K_TALK` | `k-talk-plain` | `27C_EV.MES` guard `31225`, call `31343` | 0 | 25, `1357` | none (two hops) | 0 | `27c-ev-k-talk` |
| `L_TALK` | `l-talk-plain` | `27C_EV.MES` guard `31804`, call `31922` | 0 | 40, `3582` | none (two hops) | 0 | `27c-ev-l-talk` |
| `M_TALK` | `m-talk-plain` | `01M.MES` guard `47809`, call `47934` | 0 | 13, `36649` | 12, `MACHI.MES` `89476` | 0 | `01m-m-talk` |
| `N_TALK` | `n-talk-plain` | `27C_EV.MES` guard `1591`, call `1678` | 0 | 19, `6879` | none (two hops) | 0 | `27c-ev-n-talk` |
| `N_TALK1` | `n-talk-1` | `27C_EV.MES` guard `82427`, call `82509` | 0 | 23, `3931` | 6, `FLOOR5.MES` `83150` | 0 | `27c-ev-n-talk` |
| `N_TALK2` | `n-talk-2` | `11M.MES` guard `34277`, call `34692` | 10 | 17, `8008` | none (two hops) | 0 | `11m-n-talk` |
| `N_TALK3` | `n-talk-3` | `11M.MES` guard `35147`, call `35558` | 10 | 13, `14502` | none (two hops) | 0 | `11m-n-talk` |
| `O_TALK` | `o-talk-plain` | `27C_EV.MES` guard `35644`, call `35736` | 0 | 9, `6556` | none (two hops) | 0 | `27c-ev-o-talk` |
| `P_TALK` | `p-talk-plain` | `27C_EV.MES` guard `40128`, call `40244` | 0 | 9, `29274` | none (two hops) | 0 | `27c-ev-p-talk` |
| `Q_TALK` | `q-talk-plain` | `01M.MES` guard `48455`, call `48530` | 0 | 11, `20749` | 6, `MACHI.MES` `89476` | 0 | `01m-q-talk` |
| `Q_TALK1` | `q-talk-1` | `27C_EV.MES` guard `37892`, call `37984` | 0 | 37, `2034` | none (two hops) | 0 | `27c-ev-q-talk` |

Hop 1 is silent (0 messages) for every `27C_EV.MES` anchor (the picture scripts play none) and plays 10 for `N_TALK2` and
`N_TALK3` (their block's own lines in `11M.MES`). **Two hops or three, by measurement:** for `01M.MES` and `11M.MES` the
measurer ran hop 3 once: `M_TALK`'s and `Q_TALK`'s callers reach the `MACHI.MES` handoff `89476` (three hops: 12 and 6 messages),
`N_TALK2`'s and `N_TALK3`'s caller stops at a routine-40 question the probe cannot answer (`no catalog choice at 0xCF99 in
11M.MES`, a place menu: two hops, the existing returning-flow rule reads them as `place_menu`); for the 14 `27C_EV.MES`
anchors, see the next paragraph but one. None of the 18 band-less scripts asks a
question on its default path. The 18 scripts return in 9 .. 40 messages; `M_TALK` plays 13 and returns at `36649` (its own first branch tests
`date < 616` and the guard seeds the date 620, so a later body of the chain plays), `Q_TALK` 11 at `20749` (its guard fixes
`global_u8[2031] == 15`, a cell whose value selects one body of the script).

**Hop 3 of the 14 `27C_EV.MES` anchors, measured (EP-12 TALK follow-ups, 2026-10-05).** The first declaration took the day-loop
result of heroine K's one measured site (`27C_EV.MES:31343`) for the other 13 anchors in that caller (the drafter's
`DAY_LOOP_CALLERS`). The measurer re-ran all 14 with `resume_hop: "auto"` in scratch (hop 3 once on the default path, from the call's
end): **eleven of the 13 stop in the day loop with no handoff** - `A_TALK` and `L_TALK` (12 messages in 7 segments each), `C_TALK`,
`E_TALK`, `F_TALK`, `G_TALK`, `H_TALK`, `I_TALK`, `O_TALK`, `P_TALK` and `Q_TALK1` (6 messages in 5 segments each), each at
`definition 12 stopped at definition_step_limit` (heroine K's, re-run as the control, stops the same way: 6 in 5); **`N_TALK` stops at a
question** of the next block's script (`no catalog choice at 0x114F in E_TALK.MES` after 5 messages in 8 segments: its block is followed
by `E_TALK`'s, whose first routine-40 question the probe cannot answer), no handoff reached, so two hops by the same rule as `N_TALK2` and
`N_TALK3` (not a measured day-loop stop); and **`N_TALK1` reaches a handoff**: its block is the entry's last, hop 3 plays 6 messages in
5 segments and ends at the handoff to `FLOOR5.MES` at `27C_EV.MES:83150`, so its route is **three hops and `map_return`** ("Back to
school floor 5"), declared so with catalog revision 40. The other eleven plain scripts' groups keep their profiles byte for byte;
`N_TALK` shares `N_TALK1`'s group (`27c-ev-n-talk`), whose profile is rebuilt from both re-measured specs (`N_TALK`'s route stays two
hops and names its measured stop). The twelve day-loop stops (eleven and K's) are the drafter's `DAY_LOOP_ANCHORS` now; `N_TALK` and
`N_TALK1` decide by measurement like any other anchor. Whether answering `E_TALK`'s question would let `N_TALK`'s hop 3 run on to a
handoff was not measured (the probe has no answer for it in hop 3).

**Cells and outcomes.** A rung row's route outcome is `map_return` (town: "Back to the town map"), the plain and character
two-hop rows `place_menu`, `M_TALK`, `Q_TALK` (the `MACHI.MES` handoff) and `N_TALK1` (the `FLOOR5.MES` handoff) `map_return`: 255
`map_return`, 415 `place_menu`, 11 `chain` over the 681 catalog rows (`tests/test_event_outcome_vocabulary.py`; 254 / 416 / 11 at
revision 39, before `N_TALK1`'s third hop); the display is `["conversation", "town"]` for all 105 (the `common` rows carry no
character id).

### Equivalent sites of the other heroines

Each row is one site of many ([Promise Groups](promise_groups.md)'s precedent); the others are recorded here. A heroine's
ladder is called from her blocks (eight sites each) in these callers; each calls the same eight rung scripts behind its own
guard (the place's calendar window, clock window and flags). Heroine K's own record is above.

| Heroine | Blocks | Sites | Callers | `NN M` | `NN C` | `27C*` floor | `43C` phone | scene | `?_DATE5` | `?_HOTEL` | other |
|---|---:|---:|---:|---:|---:|---|---:|---|---:|---:|---|
| A (Miko) | 44 | 352 | 42 | 24 | 14 | 27C3B | 1 | - | 1 | 1 | - |
| B (Mahoko) | 28 | 224 | 26 | 20 | 2 | - | 1 | MAHOKO38 | 1 | 1 | - |
| C (Nana) | 49 | 392 | 48 | 24 | 17 | 27C1A, 27C1B, 27C1C | 1 | NANA32 | 1 | 1 | - |
| D (Maki) | 35 | 280 | 33 | 20 | 9 | - | 1 | MAKI12 | 1 | 1 | - |
| E (Mizuho) | 55 | 440 | 54 | 24 | 17 | 27C1A, 27C1B, 27C1C, 27C2A, 27C2B, 27C2C, 27C3A, 27C3B, 27C3C | 1 | MIZUHO26 | 1 | 1 | - |
| F (Reiko) | 49 | 392 | 48 | 24 | 17 | 27C3A, 27C3B, 27C3C | 1 | REIKO42 | 1 | 1 | - |
| G (Ryoko) | 47 | 376 | 46 | 24 | 16 | 27C3C | 1 | RYOKO36 | 1 | 1 | EVENTG01 |
| H (Miyuki) | 49 | 392 | 48 | 24 | 17 | 27C2A, 27C2B, 27C2C | 1 | MIYUKI31 | 1 | 1 | - |
| I (Mayumi) | 47 | 376 | 46 | 24 | 17 | 27C3C | 1 | MAYUMI28 | 1 | 1 | - |
| J (Minatu) | 28 | 224 | 25 | 20 | 2 | - | 1 | - | 1 | 1 | - |
| K (Ai) | 49 | 392 | 48 | 24 | 17 | 27C2A, 27C2B, 27C2C | 1 | AI33 | 1 | 1 | - |
| L (Sizuka) | 57 | 456 | 56 | 24 | 18 | 27C1A, 27C1B, 27C1C, 27C2A, 27C2B, 27C2C, 27C3A, 27C3B, 27C3C | 1 | SIZUKA44 | 1 | 2 (`L_HOTEL`, `L_HOTEL2`) | - |

`NN M`, `NN C`: the place scripts; `27C*`: the Saturday floor family; `43C`: the phone ladder (`43C.MES`, 8 sites);
scene: the named character scene hosting the owner heroine's block once (`AI33` is heroine K's, `NANA32` C's, ...; none for A and J);
`?_DATE5` and `?_HOTEL`: the heroine's own scripts (two DATE5 blocks, one HOTEL block; `L_HOTEL2.MES` is the second `?_HOTEL` of L); the
count of blocks is the site count over eight (a `?_DATE5.MES` holds two). The plain scripts' other sites, the band-less scripts'
equivalents: `A_TALK` 9 sites in 8 callers (`01M.MES`, `17M`, `27C3B`, `27C_EV` x2, `30C`, `34C`, `35M`, `44M`), `C_TALK` 15 in 13,
`E_TALK` 3, `F_TALK` 3, `H_TALK` 2, `I_TALK` 4, `K_TALK` 2 and `L_TALK` 2 (all in `27C_EV.MES`), `G_TALK` 9 in 6 (`27C3C`, `27C_EV` x4,
`30C`, `33C`, `35M`, `GROUND`); `M_TALK` 331 sites in 40 callers (Tina has no ladder), `Q_TALK` 167 in 33; `N_TALK` 6 sites in
`27C_EV.MES`, `N_TALK1` 4 (`06M`, `18M`, `27C_EV`, `44M`), `N_TALK2` and `N_TALK3` 3 each (`11M`, `MINORU29`, `N_TEL`), `O_TALK` 1, `P_TALK`
2, `Q_TALK1` 2 (all in `27C_EV.MES`). The follow-on scripts have no place caller; each is a member of the routes that reach it
(`A_TALK51`, `61`, `71`, `81`, `91`; `B`: `01`, `61`, `71`, `81`, `91`; `C`: `01`, `81`; `D`: `01`, `81`, `91`; `E`: `61`, `71`; `F`: `01`, `81`, `91`; `G`: `71`;
`H_TALKXX`; `I`: `61`, `71`, `81`; `J_TALK71`; `L_TALK91`; `K_TALKXX`), and not a row.

## Not established

- What the cells mean: the presence, today and talk-started flags, `global_u8[351]` (its draw is a code fact;
  the player-visible probability is not claimed), `[350]`.
- Which engine mechanism makes the menu answer 1 the ordinary conversation (`command 0x10` semantics are
  unresolved, [Normal Conversation](normal_conversation.md)); how the native menu orders its options.
- J's six-id rejections: measured, not diagnosed. The 64 natural-state rejections were diagnosed (advisor
  decode, 2026-10-04, Confirmed) and are named since Core 0.371.0: the first question's consumer chain is a one-based chain whose positions 3
  and 4 split on scratch cells (`K_TALK30.MES` `1395` `== 1`, `9966` `== 2`, `10085`/`10376` `== 3` and
  `global_u8[10] == 0 / 1`, `10655`/`11422` `== 4` and `[11] == 0 / 1`, `11709` `== 5` and `[2207] == 0`,
  `12495` `== 6`, `13092` `== 7`; C's and E's `TALK30` have the same shape, A's and B's are pure `== k`
  chains). With two registered ids (the fresh state) only `== 1` must be a pure comparison, so it passes; with
  five, positions 1..4 must be (`content_core/mes_routine40_choice_contract.gd` ~416-426), and the gated-matrix
  form needs one shared cell for every row (~483-495). That `[10]`/`[11]` are cells the registering definition
  bodies write is inferred.
- Which states open which topics: the state space of a rung script (about 49 selector cells each) was sampled
  by single flags, not enumerated.
- The text of the topics; whether one conversation recurs across a heroine's rung scripts beyond the shared
  runs measured.
- The census's 241 "chain pairs".

## Evidence

| Claim | Evidence type | Confidence |
|---|---|---|
| 142 scripts, 4,905 sites, 136 callers, class table, address-table owners | Python instruction decode of all 1,016 entries (every entry decodes completely); dispatch records by literal target; the 4,905 and 488 of the 2026-09-24 census reproduced | Confirmed |
| the fixed ladder, guard levels, per-heroine cells, picker-order blocks, block anatomy | the same decode, enclosing-branch chains per site; `tools/mes_route_decode.py` agrees on the anchor records | Confirmed |
| PROMIS flag setters, once-only flags, who writes `[350]`/`[351]` | archive-wide scan of literal `global_u8` writes (the 12 PROMIS flags and the 2026-09-25 table reproduced) | Confirmed |
| 488 questions, naming by the contract tool under four states, option counts | route probe started at each registration block; `KakyuMesRoutine40ChoiceContract.build` on each stop | Confirmed for those states |
| answer paths, messages, segments, coverage | route probe over all 142 scripts, depth-first over every option under two states, message offsets | Confirmed for the tool's interpretation |
| declared date routes never reach TALK; the DATE5 extension | all 35 declared date routes run through the shared flow runner; a 23-hop flow built, audited and validated | Confirmed for one heroine |
| twins, shared runs | message-record hashes (the `audit_duplicate_entries.py` rule) and five-record runs | Confirmed |
| trials in "Fit with the route toolchain" | `build_event_flow_profile.py`, `audit_event_analysis_group.py`, `validate_event_analysis_group.gd`, `draft_event_route_spec.py`, `qualify_event_route.py` run; `build_event_names.py` and the inventory builder read | Confirmed (run) / read |

## Reproduction

The scans and probes are scratch under `analysis/_undoc/ep12_talk/` (untracked: the decode cache,
`inv*.py`, `blocks.py`, `chain.py`, `classify.py`, `rungs.py`, `l1.py`, `l2.py`, `flags*.py`, `static_talk.py`,
`probe_talk.gd`, `probe_q40.gd`, `probe_dateflow.gd`, `trial_flow.gd`, `trial_date5.gd`, `trial_resume.gd` and
the trial specs). The tracked tools that carry the claims:

```powershell
py tools/mes_route_decode.py --arc <ELFIMAGE-directory>/mes.arc 01M.MES:83480:83540 K_TALK30.MES:1360:1400
py tools/audit_duplicate_entries.py <ELFIMAGE-directory>/mes.arc `
  --check config/event_catalog/duplicate_entries_v1.json
py tools/build_event_flow_profile.py --arc <ELFIMAGE-directory>/mes.arc `
  --spec <talk-spec>.json --out <scratch-profile>.json
py tools/audit_event_analysis_group.py <ELFIMAGE-directory> --profile <scratch-profile>.json
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_analysis_group.gd -- `
  <ELFIMAGE-directory> <scratch-profile>.json
```
