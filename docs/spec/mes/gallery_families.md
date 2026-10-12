# Gallery Families: the Album Menus, CG Viewers, H Scripts and SCENE Entries

Measured on 2026-10-03 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`
(1,016 entries), and the A6 input tables of the same installation's
`data.arc`. All coordinates are code-relative; ranges are `[start,end)` where
an end is given. No dialogue, bytecode dump or archive payload is reproduced
here. This is a measurement unit (EP-12, the gallery families): it promotes no
catalog row, profile or contract - except the 13 album menus, which the owner's
ruling of 2026-10-04 made declarations: heroine J's first ("Declared: heroine
J's album" below), then all 13 in one unit ("Declared: all albums"). The
tracked census of twin entries is
[Duplicate Entries](duplicate_entries.md); the 43C floor is
[43C Caller Group](43c_caller_group.md) and [Room Screen](room_screen.md).

## What this document answers

| Question | Answer in one line | Confidence |
|---|---|---|
| Who dispatches the 13 `?_M.MES` menus and how | `GIRLS.MES` hands off to each by the picker id `state_u16[13]` (1..13) behind that heroine's ending-seen cell `global_u8[2560..2572]`; each `?_CG.MES` hands back; `GIRLS.MES` is a nested call of the title menu `OPEN.MES` (title answer 4) | Confirmed (static decode; execution resumed after the selection record) |
| Menu mechanism | not a routine-40 question: one native selection record (command `0x15`) over an A6 hit-test table, result in `state_u16[18]` = the A6 record id; four scene slots per page, `global_u8[20]` is the page, nine H slots | Confirmed |
| Unlock flag | each scene has its own flag, read as `global_u8[flag] == 1` right before the nested call; the 365 flags are one contiguous run `3400..3764`; each is set to 1 by literal writes of ordinary-play scripts (event, date part, hotel part, ending) and never cleared | Confirmed (archive-wide scan) |
| `?_CG.MES` | an image viewer with no dialogue; 389 CG slots (`5000..5388`, 573 picture loads) behind the album's CG tab, A6 id 18 | Confirmed |
| `?_H.MES` | not part of the album: 13 in-game recollection scripts called from `43C.MES` (the protagonist's room) by `state_u16[13]`; `OMAKE.MES` calls them in a gallery mode but is unreachable and names resources absent from the archives | Confirmed for the call paths; the segment gating is a structural count only |
| `SCENE_*.MES` | all 365 run standalone from their own start to a closing return; 295 need no answer, 70 contain their own routine-40 question; 12 recap scenes depend on state cells; 50 are twins of another entry | Confirmed (execution of all 365) |
| Fit with the route toolchain | a two-hop v14 flow (menu slot -> scene) builds, audits and validates for one twin and one unique scene of two heroines; the menu's own selection, its paging and the CG viewer's closing definition cannot run | Confirmed for the four trials |

## How the album is reached

The chain, in dispatch order, with the record that carries each step:

| Step | Entry and record | Guard | Form |
|---|---|---|---|
| Title | `START.MES` `0x0BCA` (3018): handoff to `OPEN.MES` | none | command `0x0E` |
| Title menu | `OPEN.MES` question result in `state_u16[21]` (native record dispatch at 1152) | answer 4 at 1453 | nested call `girls.mes` at 1506 (command `0x0F`) |
| Heroine picker | `GIRLS.MES`: loads the `GIRLS.A6` table (ids 1..13 heroines, 14 the poster, two rectangles), native record dispatch at 1408, result `state_u16[13]` | per heroine `state_u16[13] == id` and ending-seen cell `== 1`, one `BRZ` each from 1447 to 2227 | command `0x0E` to `?_M.MES` (offsets in the table below) |
| Album | `?_M.MES` | see the next section | nested calls and handoffs |

Other exits of the picker: id 14 (`CALL poster.mes` at 2418, behind sixteen
`global_u8` tests of the ending and slot cells, not decoded here) and value 15
(`HANDOFF open.mes` at 2506); every other value returns to the picker loop at
308. `GIRLS.MES` writes
`state_u16[19] = 1200` at 1430 before its handoff chain and brackets every
handoff with `global_u8[2573] = 1` and `= 0`; the `?_H.MES` scripts and
`OMAKE.MES` read that cell (see below). The code after each handoff re-arms
`GIRLS.MES`'s own loop (for example `global_u8[23] = 1`, a BGM routine call and
a jump to 2470); whether the engine resumes it when the menu returns is the
open command-`0x0E` caller-restoration question in
[Format and Method](format_and_method.md), not decided here.

Heroine-unlock cells: `global_u8[2560..2572]` are written to 1 at offset 162
of the heroine's own `?_END.MES` (13 scripts, one cell each) and by no other
script (`global_u8[2573]` belongs to the gallery mode above, `2575..2582` to
`SLOT.MES`). The picker ids and cells:

| Letter | Menu | Picker id | Ending cell | Handoff in `GIRLS.MES` (guard at) |
|---|---|---:|---:|---|
| F | `REIKO_M.MES` | 1 | 2560 | 1469 (1447) |
| A | `MIKO_M.MES` | 2 | 2561 | 1534 (1512) |
| E | `MIZUHO_M.MES` | 3 | 2562 | 1598 (1576) |
| I | `MAYUMI_M.MES` | 4 | 2563 | 1664 (1642) |
| G | `RYOKO_M.MES` | 5 | 2564 | 1730 (1708) |
| M | `TINA_M.MES` | 6 | 2572 | 1795 (1773) |
| C | `NANA_M.MES` | 7 | 2565 | 1859 (1837) |
| H | `MIYUKI_M.MES` | 8 | 2566 | 1923 (1901) |
| K | `AI_M.MES` | 9 | 2567 | 1989 (1967) |
| L | `SIZUKA_M.MES` | 10 | 2568 | 2051 (2029) |
| B | `MAHOKO_M.MES` | 11 | 2569 | 2117 (2095) |
| J | `MINATU_M.MES` | 12 | 2570 | 2183 (2161) |
| D | `MAKI_M.MES` | 13 | 2571 | 2249 (2227) |

The letter is the one `duplicate_entries.md` and the `SCENE_<letter>` names
use. The picker id order is the A6 table's order, not the letter order.

## The `?_M.MES` menus

All 13 menus are one template (sizes 2,977..5,200 bytes, differing in the
number of scene arms; the front part up to the selection record is the same,
with the selection at 486..491). `MIKO_M.MES` anchors the description.

| Offset | Record | Meaning |
|---:|---|---|
| 13..93 | seventeen command-`0x1B` records | group clears |
| 113 | system call 8 (`album.a6`) | loads the album's A6 table from `data.arc` |
| 145..383 | seeds | `global_u8[36]` last page index, `[37]` count of ordinary scenes, `[38]` H count (9; 0 for `TINA_M.MES`), `state_u16[0]` first scene flag, `state_u16[1]` first H flag |
| 400 | `BRZ 1 -> 4865` | the loop head; every path that does not leave by a handoff returns here (via 4860, a `JMP 400`) |
| 471 | shared routine 43 | called once per loop before the selection, presumably the page draw (with the surface operations at 532..573 on the paging arms); not decoded |
| 486 | command `0x15`, record `[100]` | the native selection; result in `state_u16[18]` |
| 501, 631 | `state_u16[18] == 5 / 6` | 5: previous page (`global_u8[20] - 1`, not below 0); 6: next page (`+ 1`, not past `[36]`); each then `DEFINVOKE [0]` and the loop |
| 763, 880, 986 | `== 7 / 8 / 18` | 7: shared routine 28 then `HANDOFF girls.mes` (847); 8: `HANDOFF open.mes` (954); 18: `HANDOFF miko_cg.mes` (1048) |
| 1083 | `state_u16[18]` in 1..4 | the scene slots: `global_u8[20] == page` (1123) then `state_u16[18] == slot` (1139) |
| 1154 | `BRZ (global_u8[3430] == 1) -> 1229` | the unlock test of the first scene; the false target 1229 reaches `JMP 400` at 1234 (a locked slot only redisplays) |
| 1170 | `CALL scene_a01.mes` (command `0x0F`) | the scene |
| 1192..1214 | arg 1 + routine 28, arg 6 + routine 23 | after the scene; routine 23 is the BGM routine (the argument is not decoded); then jumps through 1244 and 1574 to 3564: `global_u8[21] = 1`, `[22] = 255`, `JMP 4860`, which is `JMP 400` |
| 3593..4836 | slots 9..17 | nine H scenes (`SCENE_A_H01..09`), each `CALL`, then `DEFINVOKE [22]`, then the loop (4836) |

The result values are the record ids of the album's A6 table
(`ALBUM.A6`, 19 records, first-match inclusive rectangles on the 640x400
frame): 1..4 the 2x2 thumbnail rectangles, 5 and 6 two rectangles at the
bottom (the page buttons), 7 and 8 two at the lower right, 9..17 nine rows
along the right edge (the H list), 18 and 19 two adjacent rectangles at the
top. Id 18 is therefore the menu's CG entry (the census's `state_u16[18] == 18`
gate), and the CG viewer's way back to the scenes is id 19 of the same table.
The rectangle roles are read from where the scripts send each id; the
geometry is the table's. How an active top entry or a locked slot is drawn is
the native page redraw and is not decoded.

**Not a routine-40 question.** None of the 26 menu and viewer scripts has a
command-`0x10` definition or a shared-routine-40 call; each has exactly one
command-`0x15` record. The result cell `state_u16[18]` is the one the map
poll writes, but the map-location contract supplies a command-`0x12` poll;
there is no supply seam for command `0x15` in the tools (see "Fit with the
route toolchain").

### Per-heroine layout

| Letter | Scenes + H | Pages | Scene flags (first H flag) | CG slots, CG flags, picture loads |
|---|---:|---:|---|---|
| A | 21 + 9 | 6 | 3430..3459 (3451) | 30, 5029..5058, 41 |
| B | 17 + 9 | 5 | 3686..3711 (3703) | 26, 5304..5329, 40 |
| C | 21 + 9 | 6 | 3568..3597 (3589) | 31, 5180..5210, 49 |
| D | 19 + 9 | 5 | 3737..3764 (3756) | 28, 5361..5388, 42 |
| E | 24 + 9 | 6 | 3460..3492 (3484) | 31, 5059..5089, 44 |
| F | 21 + 9 | 6 | 3400..3429 (3421) | 29, 5000..5028, 44 |
| G | 17 + 9 | 5 | 3526..3551 (3543) | 29, 5122..5150, 39 |
| H | 21 + 9 | 6 | 3598..3627 (3619) | 31, 5211..5241, 50 |
| I | 24 + 9 | 6 | 3493..3525 (3517) | 32, 5090..5121, 49 |
| J | 16 + 9 | 4 | 3712..3736 (3728) | 31, 5330..5360, 42 |
| K | 16 + 9 | 4 | 3628..3652 (3644) | 30, 5242..5271, 41 |
| L | 24 + 9 | 6 | 3653..3685 (3677) | 32, 5272..5303, 57 |
| M | 16 + 0 | 4 | 3552..3567 | 29, 5151..5179, 35 |

257 ordinary scenes + 108 H scenes = 365. The dispatch order is the scene
numbering: ordinary scenes in page-major order, four to a page, then the nine
H scenes in slots 9..17. The order of the unlock events is not that order
(for example `SCENE_A04`'s flag is written by `EVENTA05` and `SCENE_A05`'s by
`EVENTA04`).

### Where each unlock flag is set

An archive-wide scan of every literal `global_u8` write record (command
`0x03`) finds a writer for each of the 365 scene flags and each of the 389 CG
flags; every one of those writes stores 1 and none stores 0. The dynamic-index
writes (command `0x05`, 298 records) were scanned too: 219 have a literal
index (the highest is 3042) and none touches either range; the other 79 use
three counter expressions (`3041 + state_u16[8]` 75 times, `27 +
state_u16[8]` twice and the new-game clear loops' `state_u16[2]` twice) which
were not traced, so a computed write into either range is not excluded.
`OPEN.MES`'s new-game initialiser (2239..2271) clears `global_u8[0..3098]`
only, so it covers the ending cells but not the scene or CG flags; how the
host persists any of the ranges across games is not decoded. 351 scene flags
have one writer script and 14 have two or three.

Writer class of the 365 scene flags (each flag once; a flag whose writers are
of two classes has its own row):

| Writer | Scenes |
|---|---:|
| an `EVENT*.MES` script | 133 |
| the heroine's `?_HOTEL1.MES` (her nine H scenes, 12 heroines) | 108 |
| a `?_DATE2/3/5/7.MES` script | 79 |
| the heroine's `?_DATE5.MES` and `?_HOTEL.MES` (the 12 recap scenes) | 12 |
| the heroine's `?_HOTEL.MES` | 12 |
| a `?_END.MES` script (`M_END.MES` writes two) | 14 |
| a floor or other script (`01M`, `07M`, `28C` x2, `GROUND`, `J_INTRO`, `I_TALK`) | 7 |

The 14 multi-script flags are the 12 recap scenes and `SCENE_L15` /
`SCENE_L16`, which are written by other heroines' `?_DATE2.MES` scripts
(`D`, `E`, `G` and `A`, `B`, `I`). 126 distinct `EVENT` scripts write scene
flags and all 126 are the callee of a row of the shipped catalog; 51 distinct
date or hotel scripts write them and 49 are hops of a declared date flow (the
two others are `J_HOTEL.MES` and `J_HOTEL1.MES`, whose route is measured but
not declared). CG flags: 167 have an `EVENT` writer, 90 a date part, 46 a
`?_HOTEL1.MES`, 36 a date part and a hotel script, 32 an ending, 12 a
`?_HOTEL.MES`, 5 another script and 1 a date part and another script; 349
have one writer script.

## The `?_CG.MES` viewers

13 scripts of 10,882..14,702 bytes, each reached only by the handoff from its
own menu (offsets 1046..1053 in the menus) and each with no text record (no
dialogue, no voice). Structure of `MIKO_CG.MES`: the same selection template
(command `0x15` at 364, A6 `ALBUM.A6`), pages by `global_u8[20]` with the upper
bound in `[27]` (6 or 7), four slots per page; id 7: `HANDOFF girls.mes`
(699); id 8: `HANDOFF open.mes` (806); id 19: `HANDOFF miko_m.mes` (906),
the way back to the scenes. A slot tests its flag (`global_u8[5029 + n] == 1`,
the base is `state_u16[0]`), loads one to eight picture names into the active
surface (573 loads over 389 slots, 260 slots with one; the names are resource
names only), runs presentation steps (surface operations, shared routines 21
and 22, system call 12), and ends with `DEFINVOKE [0]` and a jump to the loop
head. Definition 0 is not among the 14
definitions the `DEF_MAIN.MES` registry builds (`11, 12, 14, 15, 17, 18, 20,
21, 22, 23, 26, 80, 81, 99`), so the route probe stops there with "definition
0 is not registered" (see below); the paging buttons of the menus end the same
way.

**The viewers' pictures against the playback package** (2026-10-09; static
scan of `mes.arc` and `mmo.arc` for the exact MMO presentation record, command
`0x0D` subcommand 9, the pattern of `tools/audit_mes_mmo_markers.py`; the scan
found no `.mmo` token outside such a record; Confirmed):
- The 13 viewers hold 586 records naming 572 distinct pictures, and `mmo.arc`
  ships all 572.
- 556 are `media_inventory` names of package `5ae6aabe...`, because member
  events play them.
- The other 16 are not:
  - each viewer's page picture `CG_<heroine>_M.MMO`, loaded at code-relative
    297 in every viewer and once more in `MAHOKO_CG.MES` (2602), `MAKI_CG.MES`
    (5315), `RYOKO_CG.MES` (2283) and `TINA_CG.MES` (6585);
  - `D15SS.MMO` (`MAKI_CG.MES` 5171) and `G05SS.MMO` (`RYOKO_CG.MES` 2109),
    which no other entry names;
  - `M22C.MMO` (`TINA_CG.MES` 8671), also named by `44C_END.MES` (12700),
    which is not a package member.

The owner withdrew the flag -> picture table (WD-21 U3) on 2026-10-09, because
the pictures suffice. The owner also chose to record these 16 here, not to
inventory the viewers.

## The `?_H.MES` scripts

13 scripts of 54,376..83,077 bytes (498..819 text records, 147..256 voice
markers each). Two call paths exist, 13 sites each:

| Caller | Sites | Guard |
|---|---|---|
| `43C.MES` | `CALL ?_h.mes` at 36974..37334 (about 30 bytes apart), one per picker id 1..13 | answer 3 of the 43C routine-40 question at 20161 (tests at 20196, 35527 and 36923; the question has three definitions at 20053, 20084, 20119), then `state_u16[13] == id` |
| `OMAKE.MES` | `CALL ?_h.mes` at 6044..6548, one per id, each between `global_u8[2573] = 1` and `= 0` | the omake menu's selection result in `state_u16[13]` |

`state_u16[13]` carries the heroine id in the same 1..13 numbering as the
picker (14 is the poster, 15 leaves). Its only writers in the archive are
`LIBLARY.LIB` (ten sites; one copies a native selection result,
`state_u16[13] = state_u16[18]`, at 7415) and `OMAKE.MES` (two); `43C.MES`
itself does not write it, so the room reaches its H branch with a heroine
chosen outside that file. (Matched afterwards, 2026-10-04: the 43C question is
the room-action menu of [Room Screen](room_screen.md), answer 3 its
recollection row, and the heroine id the native secondary selection's result;
see [43C caller group](43c_caller_group.md), which also holds the declaration of
the 13 ladders and the structural gate recount that replaces the 281 below.)

Each `?_H.MES` begins with its heroine guard (`BRZ state_u16[13] == id` at
189, 184 or 158) and is a fixed ladder of flag-gated segments: 8 to 27
single-cell `== 1` tests that skip more than 1,000 bytes (281 over the 13
scripts, outside the presentation cells), each segment closing with
`global_u8[11] = 1`, then a tail that tests `global_u8[11]` and the
gallery-mode cell 2573. The gate flags are cells the ordinary events set (for
`MIKO_H.MES`: 1110 is written by `EVENTA01`, 1111 by `EVENTA02`, 1113 and 1114
by `EVENTA03`, 1115 by `EVENTA05`, 1116 by `A_DATE2.MES`, and so on). A run of
`MIKO_H.MES` from its start with `state_u16[13] = 2` and no gate flag plays 9
messages and returns; with only `global_u8[1110] = 1` it plays 45 and returns;
with `state_u16[13] = 3` it plays none and returns. That is a recollection chain of the events the
player has seen, which the room offers, not the album.

**`OMAKE.MES` is unreachable.** No archive record names it (the strict decode
finds no dispatch or handoff of it, as the census recorded); the executable
holds exactly three `.mes` literals (`start.mes`, `main.mes`, `open.mes`); and
the resources it loads are absent: `omake.a6` is not among the 12 A6 tables of
`data.arc`, and `omake.mmo`, `fwaku.mmo`, `yoko1.mmo` and `yoko2.mmo` are not
among the 1,727 `mmo.arc` entries. Construction of a name from pieces by the
host is not excluded; nothing suggests it.

## The `SCENE_*.MES` entries

### Standalone behaviour

All 365 were run alone from their own start in the route probe, once from an
all-zero state and once from the ambient state of the gallery
(`state_u16[19] = 1200` and `[8] = 0` as `GIRLS.MES` writes them, `[21] = 4` as
the title answer leaves it). With the first option
answered where the scene asks, all 365 reach their closing return
(`script_return`); the message sequences are identical in both states for the
295 scenes that ask nothing.

| Class | Scenes | Note |
|---|---:|---|
| no question | 295 | message sequence identical in both states |
| one routine-40 question | 68 | 63 with two definitions, 5 with three; the question is the original event's own, preserved in the copy |
| two questions | 2 (`SCENE_I02`, `SCENE_L11`) | two definitions each |

Totals under the first-option answers: 15,509 messages (smallest 0, largest
145). The scenes read the clock `state_u16[19]` in 70 scripts (picture arms
at the thresholds 600, 900, 1600, 1800); 47 scenes read a `global_u8` or
`banked_u16` play-state cell beyond the presentation options.

Twelve of the 295 question-free scenes are the recap scenes (`SCENE_A20`,
`B15`, `C20`, `D16`, `E21`, `F19`, `G15`, `H19`, `I22`, `J14`, `K14`, `L22`).
Each reads four cells (`A`: `global_u8[2676..2679]`; the twelve sets together
are `2672..2719`). Each cell is written 1 at one point of the heroine's
`?_DATE5.MES` and 2 at the matching point of her `?_HOTEL.MES`, and in the
recap it selects which of two alternative texts plays at that point. From an
all-zero state they play 0 messages. `SCENE_A20` over all 16 combinations of
1/2 plays 36..57 messages (`1111`: 40, `2222`: 53); the two combinations the
writers produce are all-1 (the DATE5 path) and all-2 (the hotel path).

Terminal: every scene ends in a closing command-`0x00` record, which returns
to the menu's nested call; the menu then runs the after-scene records above and
returns to its loop head, that is, to the next selection.

### Twins and containment

The census's twin groups are identical message-record sequences, not
identical entries (copies are never larger and carry the same voice-marker
count, [Duplicate Entries](duplicate_entries.md)):

| Twin of | Scenes | Existing catalog row |
|---|---:|---|
| an `EVENT*.MES` script | 29 (27 scripts; `EVENTH16`/`EVENTH17` appear in both the H and K albums) | yes: all 27 are the callee of a shipped row |
| a `?_END.MES` script | 13 (`SCENE_A21`, `B17`, `C21`, `D19`, `E24`, `F21`, `G17`, `H21`, `I24`, `J16`, `K16`, `L24`, `M16`) | no row (no `?_END` script is the callee of a shipped row); the endings are reached by `44C_END.MES` handoffs |
| another scene | 8 (`SCENE_H06/K03`, `H09/K06`, `H12/K09`, `H13/K10`) | their writers `EVENTH07`, `EVENTK06`, `EVENTK13`, `EVENTK14` are rows |

The 27 EVENT twins by letter: `C03`=`EVENTC03`, `C09`=`EVENTC10`, `C15`=`EVENTC18`;
`D02`=`EVENTD03`; `E04`=`EVENTE05`, `E08`=`EVENTE10`; `F03`=`EVENTF03`;
`G09`=`EVENTG21`; `H08`=`EVENTH11`, `H10`=`EVENTH16` (+`K07`), `H11`=`EVENTH17`
(+`K08`), `H15`=`EVENTH18`; `I13`=`EVENTI14`; `J03`=`EVENTJ04`, `J04`=`EVENTJ09`,
`J06`=`EVENTJ18`; `K02`=`EVENTK02`, `K13`=`EVENTK15`; `L10`=`EVENTL25`,
`L13`=`EVENTL13`; `M01`=`EVENTM01`, `M04`=`EVENTM05`, `M05`=`EVENTM04`,
`M10`=`EVENTM17`, `M11`=`EVENTM15`, `M12`=`EVENTM16`, `M13`=`EVENTM18`.

Beyond identity, the scenes are mostly cut out of the script that sets their
flag. Comparing each of the 365 scenes' ordered text-record hashes with the
flag writer's (best over writers): 42 equal (the 29 + 13 twins), 141 are a
contiguous run of the writer's records, 95 an ordered subsequence, and 87
share records without forming an ordered run (63 of them have exactly two
records the writer lacks). So most gallery scenes
replay content already reachable through a shipped row, re-cut into a shorter
scene; they are not new text, but they are new playback units (a different
start, a different end, often no choice of the original).

## Fit with the route toolchain

Scratch trials (untracked probes under `analysis/_undoc/ep12_gallery/`; nothing
declared) on `MIKO_M.MES` with `SCENE_A01` (unique) and `SCENE_A21` (twin of
`A_END.MES`, not a row), and on `MINATU_M.MES` with `SCENE_J01` (unique) and
`SCENE_J03` (twin of `EVENTJ04.MES`, a row), with the Event Runner and the
route probe:

| Trial | Result |
|---|---|
| menu from its own entry (`start_coordinate` 8), flag set or not | stops at the selection: `native_selection_boundary at 0x1E6` (A) / `0x1E8` (J), 0 messages; the probe has no handler or supply for command `0x15` |
| menu resumed at the end of the selection record (491 / 493) with page, slot and flag seeded | runs the page and slot tests, the unlock test, the nested scene, the after-scene routines and the redisplay up to the next selection; scenes play 36 / 101 / 33 / 21 messages |
| same, flag not set | the locked branch, 0 messages, the next selection |
| scene alone from its start | `script_return`, 36 / 101 / 33 / 21 messages, from an all-zero or the ambient state |
| twin alone | `A_END.MES` 101 messages, then the handoff to `ENDING.MES`; `EVENTJ04.MES` 21 messages, then the handoff to `MACHI.MES`; the same counts as the scene copies |
| paging buttons, CG slots | stop at `DEFINVOKE [0]`: "definition 0 is not registered" |
| H slot of the menu (`state_u16[18] = 9`) | 94 messages, `DEFINVOKE [22]` runs, the next selection |
| CG button (18) | `script_handoff_boundary` to `MIKO_CG.MES` at 1048 |

A two-hop `kakyu_event_analysis_group/v14` flow per scene was then built from a
hand-written hop spec with `tools/build_event_flow_profile.py`: hop 1 in the
menu from the page test to the nested-call record (origin 1123 / 3423 / 1127 /
1127, guard the unlock test at 1154 / 3454 / 1158 / 1378, `script_dispatch_boundary`
to the scene), hop 2 the scene entered by `nested_call` and leaving by its
`script_return`, the ambient cells and the page, slot and flag as `baseline`
writes, the accepted and the rejected (flag cleared) guard cases. All four
profiles pass `tools/audit_event_analysis_group.py` and the runtime flow
validator (`validate_event_analysis_group.gd`, 19 checks each, no failure).
What the shape cannot do:

- A third hop (the menu's resume after the scene) cannot end the flow: the
  resume runs the after-scene records and the redisplay and stops at the next
  selection, and a v14 hop outcome is only a return, a routine-40 selection, a
  handoff or a dispatch. The flow ends on the scene's own return.
- The menu cannot be entered at its start, so the menu answer is a seeded state
  (`state_u16[18]`, `global_u8[20]`), not a choice.
- Scenes with their own question (70) need their answers as `choice_contracts`;
  the probe built and ran the contract of all 70 under the first option; other
  options are further routes.
- Read from the tools, not executed: the v6/v8/v10 caller-continuation
  drafter (`tools/draft_event_route_spec.py`) takes a group-measure inventory
  of `EVENT*` intro sites (`tools/build_event_analysis_inventory.py`) and has no
  input for a `SCENE_*` callee; the name registry builder
  `tools/build_event_names.py` stopped on a callee stem that is neither
  `EVENT<letter>...` nor `<letter>_...`, which is what `SCENE_A01` is. Both gaps
  are closed by the 2026-10-04 SCENE tools (a menu drafter and measurer pair, a
  `SCENE_` rule in the registry builder); see "Declared" below.

## Declared: heroine J's album (EP-12 SCENE, 2026-10-04)

The owner ruled on 2026-10-04 (`todo/event_player.md` EP-12) that SCENE takes
the menu-group shape: one analysis group per `?_M.MES` menu, a v14 flow per
scene, one catalog row per scene, no contract change. Heroine J (`MINATU_M.MES`,
25 scenes) is the first menu: group `minatu-m-scene`,
`config/event_catalog/analysis_groups/minatu_m_scene_v14.json`
(`kakyu_event_analysis_group/v14`, `payload_sha256`
`eb8b41f5a452e703f758b48abc5743a59c5fa26822152a20d9f90159d43381ae`, 25 routes of
two hops, 29 source members: the menu, the 25 scenes, `LIBLARY.LIB`,
`DEF_MAIN.MES`, `START.MES`). Built with the tools of
`docs/spec/tech/content_tools.md` ("EP-12 gallery SCENE tools"):
`tools/draft_menu_flow_specs.py` (static recipe),
`tools/content_suite/cli/measure_menu_flow.gd` (measurement, specs),
`tools/build_event_flow_profile.py` (profile).

**The route.** Hop 1 runs the menu from the route's **origin** - the page test
`global_u8[20] == page` for the 16 ordinary scenes (`MINATU_M.MES` 1127 for
page 0, 1583 page 1, 2039 page 2, 2495 page 3), the slot test
`state_u16[18] == slot` for the nine H scenes (2990, 3127, 3264, 3401, 3538,
3675, 3812, 3949, 4086) - through the slot test and the **unlock test**
`global_u8[flag] == 1` (the route's origin guard; the rejected case clears the
flag) to the scene's nested `CALL` (command `0x0F`), zero messages. Hop 2 is the
scene, entered by that call at its start, ending at its own closing
`script_return`. The flow ends there: what the menu does after the scene
(the after-scene routines, the redisplay and the next selection) is a
measured fact of the study, not a hop. Anchors, all `MINATU_M.MES` unless a
scene is named (code-relative offsets):

| Scene | Page, slot | Unlock flag | Origin / guard / call | Messages | Return in the scene | Twin |
|---|---|---:|---|---:|---:|---|
| `SCENE_J01` | 0, 1 | 3712 | 1127 / 1158 / 1174 | 33 | 2596 | |
| `SCENE_J02` | 0, 2 | 3713 | 1127 / 1268 / 1284 | 27 | 2138 | |
| `SCENE_J03` | 0, 3 | 3714 | 1127 / 1378 / 1394 | 21 | 1460 | `EVENTJ04` |
| `SCENE_J04` | 0, 4 | 3715 | 1127 / 1488 / 1504 | 15 | 1732 | `EVENTJ09` |
| `SCENE_J05` | 1, 1 | 3716 | 1583 / 1614 / 1630 | 18 | 1739 | |
| `SCENE_J06` | 1, 2 | 3717 | 1583 / 1724 / 1740 | 27 | 2349 | `EVENTJ18` |
| `SCENE_J07` | 1, 3 | 3718 | 1583 / 1834 / 1850 | 45 | 3482 | |
| `SCENE_J08` | 1, 4 | 3719 | 1583 / 1944 / 1960 | 9 | 1737 | |
| `SCENE_J09` | 2, 1 | 3720 | 2039 / 2070 / 2086 | 47 | 16231 | |
| `SCENE_J10` | 2, 2 | 3721 | 2039 / 2180 / 2196 | 53 | 3829 | |
| `SCENE_J11` | 2, 3 | 3722 | 2039 / 2290 / 2306 | 38 | 2708 | |
| `SCENE_J12` | 2, 4 | 3723 | 2039 / 2400 / 2416 | 13 | 5533 | |
| `SCENE_J13` | 3, 1 | 3724 | 2495 / 2526 / 2542 | 14 | 3087 | |
| `SCENE_J14` | 3, 2 | 3725 | 2495 / 2636 / 2652 | 32 | 6143 | recap |
| `SCENE_J15` | 3, 3 | 3726 | 2495 / 2746 / 2762 | 19 | 1371 | |
| `SCENE_J16` | 3, 4 | 3727 | 2495 / 2856 / 2872 | 66 | 4916 | `J_END` |
| `SCENE_J_H01` .. `H09` | H slots 9..17 | 3728..3736 | see above | 57, 69, 76, 65, 84, 56, 60, 44, 40 | 4188, 5208, 5530, 4822, 6006, 4104, 4019, 3949, 2886 | |

(An H scene's guard is its slot test's offset + 15 and its call + 41: 3005 and
3031 for `H01`, 3142 and 3168 for `H02`, and so on to 4101 and 4127 for `H09`.)
1,028 messages over the 25 routes under the default variants.

**Tool decision: the menu selection is seeded state.** The menu's own selection
record (command `0x15`, offset 488 here) cannot run in the tools, so every
route's baseline writes the cells the selection would have left: `state_u16[18]`
(the slot's A6 record id, 1..4 or 9..17), `global_u8[20]` (the page, ordinary
scenes), the scene's unlock flag, and the ambient cells of a gallery visit -
`state_u16[19] = 1200` and `[8] = 0` as `GIRLS.MES` writes them (checked
statically by the drafter), `state_u16[21] = 4` from the title answer that leads
to `GIRLS.MES`. Locked and unlocked is therefore representable only as the
guard's accepted and rejected cases; paging and the CG viewer are not.

**Twins.** The three EVENT twins are rows classified `duplicate_route` with
`canonical_event_id` the EVENT row (`SCENE_J03` -> `original/eventj04/01m-00009b85`,
`SCENE_J04` -> `original/eventj09/46m-0000066a`, `SCENE_J06` ->
`original/eventj18/06c-0000350e`); each stays `minimal_playback` and plays as its
own route. "Message-identical callee" is the census definition of
`config/event_catalog/duplicate_entries_v1.json` (identical ordered message
records), a tool decision documented in `docs/spec/tech/content_tools.md`. The
`?_END` twin `SCENE_J16` (copy of `J_END.MES`, which has no row) is an ordinary
row. The other 21 routes are ordinary rows.

**Presets and what the shape cannot hold (as first declared).** The J unit
declared every route with its default variant only: the recap `SCENE_J14` reads
four cells (`global_u8[2708..2711]`, written 1 by `J_DATE5.MES` and 2 by
`J_HOTEL.MES`; the default route seeds them to 1, the DATE5 path, 32 messages,
the hotel path 36), and `SCENE_J08` and `SCENE_J13` each carry one routine-40
question (boundary 353, two options; option 2 plays the same 9 and 14 messages
and returns at the same record), and a v14 route then held one answer per
question and one message count per hop. The additive variant fields (`answers`,
`message_counts`, 2026-10-04) removed that limit and the all-menus unit
re-measured J with them (28 variants over its 25 routes: `SCENE_J08`/`J13`
`option-2`, `SCENE_J14` `hotel-path`; see "Declared: all albums"); the J figures
in this section are the first declaration's.

**Registry, catalog, package (as first declared).** `minatu.special.minatu_m.01.1` ..
`16.1` and `.h01.1` .. `h09.1` (the `special` fall-through; catalog rows carry
`display.categories = ["gallery"]`), registry 214 rows; catalog revision 35, 214
rows (189 + 25: 22 `playable_event`, 3 `duplicate_route`, all
`minimal_playback`); each row's terminals are the scene's `script_return` and the
menu loop boundary, so its route outcome is `place_menu` (the Event Player
phrases the matched `script_return` terminal as an undeclared continuation, a
known residue); package v7 214 events from 397 member entries, 255 bound by 174
groups; 214 v6 documents (a gallery document's `terminals` entry is
`callee_return`, its `dependencies` are empty). Route classification moved only
its `catalog_sha256`: the 167 classified entries are EVENT and system scripts,
and no `SCENE_*` or `?_M.MES` entry is among them, so the "newly bound" delta
the unit expected is empty.

**Verified** against the archive: the Python audit (`ok`), the runtime flow
validator over the 25 routes (283 checks, no failure; guard witnesses, hop
outcomes, message counts, writes) and its replay.

## Declared: all albums (EP-12 SCENE all-menus unit, 2026-10-04)

The other twelve menus were declared in one unit, and heroine J's profile was
re-measured with its variants and replaced (the package binds each group's
payload hash, so J could not stay as it was). Every `<NAME>_M.MES` is one
analysis group, `<menu stem>_scene_v14.json` under
`config/event_catalog/analysis_groups/` (`miko`, `mahoko`, `nana`, `maki`,
`mizuho`, `reiko`, `ryoko`, `miyuki`, `mayumi`, `minatu`, `ai`, `sizuka`,
`tina`), built by the tools of `docs/spec/tech/content_tools.md` ("EP-12
gallery SCENE tools") exactly as J's was: the drafter ran on all 13 menus
(365 scenes, no shape mismatch), `measure_menu_flow.gd` measured each scene
and wrote its spec, `build_event_flow_profile.py` built the profile. Every
profile passes the Python audit and the runtime flow validator (4,669 checks
over the 13, no failure). The routes are two hops exactly as J's (the menu
from the page or slot test through the unlock test to the nested call, zero
messages; the scene to its own `script_return`).

**The seeded selection stays a tool decision.** The menu's own selection
record (command `0x15`) cannot run in the tools, so each route's baseline writes
the cells the selection would have left (`state_u16[18]` the slot's A6 record
id, `global_u8[20]` the page for an ordinary scene, the scene's unlock flag) and
the ambient cells of a gallery visit (`state_u16[19] = 1200`, `[8] = 0`,
`[21] = 4`), identically for all 365 scenes; locked and unlocked are the guard's
accepted and rejected cases, and paging and the CG tab are not represented. A
recap scene's default route seeds its four cells to 1 (the DATE5 path).

**What is declared besides the default path.** The default variant of a route
is the first option at each question the scene asks and the DATE5 cells. Every
other path that ends at the route's own return is a variant
(`docs/spec/tech/content_tools.md`, "Variant `answers` and `message_counts`";
the measurer writes them): 79 option variants - 63 two-option questions one
each, the five three-option questions (`SCENE_A18`, `B13`, `E06`, `F04`,
`F12`) two each, and the two two-question scenes (`SCENE_I02`, `L11`) every
other answered combination (three each) - and the 12 recap scenes' `hotel-path`
(four cells all 2, its own message count): **91 variants, no alternative left
`unresolved`** (every measured path ended at its scene's own return, none
differed in terminal), no question that exists only on a variant's path and no
default question that a variant skips. A route's choices and presets follow
(`promote_analysis_groups.py`): 70 rows carry a choice (two of them two choices),
every option is an option of the row resolved to its variant's preset, and
365 default + 91 variant presets make 456 presets. Four scenes (`SCENE_A15`,
`C08`, `H05`, `M14`) nest a `*_PIC.MES` standing-picture script
(`P_PIC`, `O_PIC`, `H_PIC`, `M_PIC`, already members of other groups) and
return only when it is loaded, so it is a source member of that scene's flow
(the drafter's `nested_members`).

| Menu | Heroine | Routes | Question scenes | Variants | Twins (`duplicate_route`) | Unresolved paths | Lines (default path) |
|---|---|---:|---:|---:|---|---:|---:|
| `MIKO_M` | A | 30 | 4 | 6 (5 option, 1 recap) | 0 | 0 | 1,383 |
| `MAHOKO_M` | B | 26 | 7 | 9 | 0 | 0 | 860 |
| `NANA_M` | C | 30 | 10 | 11 | 3 EVENT | 0 | 1,184 |
| `MAKI_M` | D | 28 | 5 | 6 | 1 EVENT | 0 | 1,074 |
| `MIZUHO_M` | E | 33 | 6 | 8 | 2 EVENT | 0 | 1,327 |
| `REIKO_M` | F | 30 | 8 | 11 | 1 EVENT | 0 | 1,429 |
| `RYOKO_M` | G | 26 | 2 | 3 | 1 EVENT | 0 | 1,227 |
| `MIYUKI_M` | H | 30 | 8 | 9 | 4 EVENT | 0 | 1,547 |
| `MAYUMI_M` | I | 33 | 6 | 9 | 1 EVENT | 0 | 1,449 |
| `MINATU_M` | J | 25 | 2 | 3 | 3 EVENT | 0 | 1,028 |
| `AI_M` | K | 25 | 3 | 4 | 4 EVENT + 4 internal | 0 | 1,364 |
| `SIZUKA_M` | L | 33 | 8 | 11 | 2 EVENT | 0 | 1,453 |
| `TINA_M` | M | 16 | 1 | 1 (option; no recap scene) | 7 EVENT | 0 | 818 |
| **13 menus** | | **365** | **70** | **91** | **33** | **0** | **16,143** |

(Lines are the messages a route's own scene plays under the default variant.
They exceed the study's 15,509 because the study ran the 12 recap scenes from an
all-zero state, where they play nothing, and the route seeds their DATE5 cells.)

**Twins.** The 33 `duplicate_route` rows are the 29 scenes message-identical to
one of 27 EVENT callees (each the callee of one shipped row, so every mapping
is unambiguous: `SCENE_H10` and `SCENE_K07` both point at the `EVENTH16` row,
`SCENE_H11` and `SCENE_K08` at the `EVENTH17` row) and the four K scenes that
are internal copies of H scenes (`SCENE_K03`, `K06`, `K09`, `K10` -> `SCENE_H06`,
`H09`, `H12`, `H13`, the H scene canonical). The 13 `?_END` twins stay ordinary
rows. Each twin stays a playable `minimal_playback` route of its own.

**Registry, catalog, package.** Registry 554 rows (the 340 new sites
`<heroine>.special.<menu stem>.<number>.1`, the 214 earlier rows unchanged;
`EXPECTED_PAIR_COUNT` 519); catalog revision 36, 214 -> 554 rows, all
`minimal_playback` (521 `playable_event`, 33 `duplicate_route`), the 365 album
rows tagged `gallery` in `display.categories`, every row's route outcome
`place_menu`; the 189 non-album rows are byte-identical to revision 35 and only
heroine J's 25 rows moved (the profile hash they bind, and the three rows that
gained presets or a second option: `SCENE_J08`, `J13` option 2, `J14`
`hotel-path`). Package v7: 554 events from 749 member entries (154
catalog-verified, 595 bound by 186 analysis groups), Core 0.369.0, SHA-256
`3ef6acc12182e8ce6acf7316ecb58aa051cf4a8a7f6c4655d0190c2993cf7674`. 554 v6
documents (see `config/event_definitions/v6/README.md`). Route classification
moved its `catalog_sha256` and gained four `source_member` bindings - the
`*_PIC.MES` entries the four nesting scenes reach (`H_PIC`, `M_PIC`, `O_PIC`,
`P_PIC` -> their album groups); 166 entries bound, no class or confidence
move.

**Verified** against the archive: the Python audit and the runtime flow
validator for each of the 13 profiles (a check each in
`config/validation/checks_v1.json`, 280 entries; 15.0-21.4 s each in the whole
batch), the 20 shards of `original catalog group routes` (554 rows, 365 album
rows' status lines), and the whole `full` tier at Core 0.369.0: 432 checks, 432
passed, 4,251 s, then 432 of 432 cached.

## Not established

- Which engine mechanism returns control from a handed-off menu to `GIRLS.MES`
  or `OPEN.MES` (command `0x0E` caller restoration, unresolved in
  [Format and Method](format_and_method.md)).
- What shared routines 21, 22, 28, 42 and 43 and definitions 0 and 22 draw or
  wait for in the menus and viewers; how the host marks unlocked slots.
- How the host persists the scene, CG and ending flags across new games (the
  initialiser in `OPEN.MES` leaves the first two ranges alone and clears the
  third).
- (Closed 2026-10-04: the 43C question at 20161 is the room-action menu and
  `state_u16[13]` the native secondary selection's result, [43C caller
  group](43c_caller_group.md).)
- Native meaning of arguments to routine 28 and 23 in the after-scene records
  beyond routine 23 being the BGM routine.

## Evidence

| Claim | Evidence type | Confidence |
|---|---|---|
| dispatch chain, offsets and guards above | Python instruction-v45 decode of all 1,016 entries (every entry decodes completely); the strict dispatch records | Confirmed |
| menu template, result cell, A6 ids | decode of the 26 menu and viewer scripts; the 12 tables of `data.arc` read with the A6 record layout (`ID, left, top, right, bottom`, inclusive, 0xFFFF terminator) | Confirmed for the ids; the region geometry is read, the labels are inferred from the scripts |
| unlock flags, writers, class counts | archive-wide scan of literal `global_u8` writes and of dynamic writes (command `0x05`) | Confirmed |
| standalone scene runs, message counts, questions | the route probe over all 365 scenes in two states, with the first option at each question | Confirmed for the tool's interpretation; native presentation is not part of the claim |
| twins, containment | message-record hashes (the `audit_duplicate_entries.py` rule) per entry and per scene against its writer | Confirmed |
| flow trial | `build_event_flow_profile.py`, `audit_event_analysis_group.py`, `validate_event_analysis_group.gd` on four scratch profiles | Confirmed |
| the 13 declared menus, their variants | `draft_menu_flow_specs.py`, `measure_menu_flow.gd`, `build_event_flow_profile.py` per menu; `audit_event_analysis_group.py` and `validate_event_analysis_group.gd` over each profile (4,669 checks, no failure) | Confirmed for the tool's interpretation (the seeded selection is a tool decision) |
| `OMAKE.MES` unreachable | archive record scan, executable literal scan, resource-name lookup in `data.arc` and `mmo.arc` | Confirmed for the shipped data; host construction of a name is not excluded |
| recollection role of the `?_H.MES` scripts | the call path, the flag ladder and three probe runs | High-confidence contextual (structure measured, intent inferred) |

## Reproduction

The scans and probes are scratch under `analysis/_undoc/ep12_gallery/`
(untracked: decode and scan scripts, `probe_gallery.gd`, `probe_scenes.gd`,
`probe_variants.gd`, `probe_cg.gd`, `probe_def.gd` and the four scratch v14
specs). The tracked tools that carry the claims:

```powershell
py tools/audit_duplicate_entries.py <ELFIMAGE-directory>/mes.arc `
  --check config/event_catalog/duplicate_entries_v1.json
py tools/build_event_flow_profile.py --arc <ELFIMAGE-directory>/mes.arc `
  --spec <scene-spec>.json --out <scratch-profile>.json
py tools/audit_event_analysis_group.py <ELFIMAGE-directory> --profile <scratch-profile>.json
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_analysis_group.gd -- `
  <ELFIMAGE-directory> <scratch-profile>.json
```
