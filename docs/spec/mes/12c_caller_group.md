# 12C caller group: EVENTD01, D02, D03, D08 and D14 measured as groups

Measured on 2026-09-21 (EP-10 unit 5a) against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`, with the
route toolchain (`tools/draft_event_route_spec.py` on the caller inventory
`analysis/12c_group_measure.json`, then `tools/qualify_event_route.py
--register`). All coordinates are code-relative with exclusive end offsets.
This is a bounded original-event observation; the five sites were qualified
before as hand-authored catalog rows (Maki events D01, D02, D03, D08 and
D14), and the groups reproduce what those rows declared through the shared
call frame.

`12C.MES` is the town place MACHI location 10 dispatches
(`docs/spec/mes/map_location_entries.md`). Its five EVENT intros are nested
calls (command `0x0F`); every callee returns and the caller hands the root
to `MACHI.MES` (`natural_handoff`). D08 is the one site whose caller
continues with its own messages after the return (the `D_PIC.MES`
follow-up the hand row called the caller restore route).

| Route | Guard | Dispatch | Callee return | Caller resume -> handoff | Variants | Messages |
|---|---|---|---|---|---|---|
| `12c-d01-result1/2/3` (`12c_d01_v5.json`) | `1621..1710`, false `2182` | `1997..2013` -> `EVENTD01.MES` | `4372` | `2013` -> `MACHI.MES` at `2154` | 9 / 1 / 1 | 27 / 31 / 27 (reentry 12) |
| `12c-d02` (`12c_d02_v5.json`) | `2182..2274`, false `2630` | `2445..2461` -> `EVENTD02.MES` | `6342` | `2461` -> `MACHI.MES` at `2602` | 9 | 82 (reentry 82) |
| `12c-d03` (`12c_d03_v5.json`) | `2630..2722`, false `3735` | `3550..3566` -> `EVENTD03.MES` | `2047` | `3566` -> `MACHI.MES` at `3707` | 9 | 20 (reentry 20) |
| `12c-d08-result1/2/3` (`12c_d08_v5.json`) | `3735..3810`, false `6708` | `4006..4022` -> `EVENTD08.MES` | `2790` | `4022` -> `MACHI.MES` at `6680`, 16 / 12 / 28 caller messages | 9 / 1 / 1 | 21 / 25 / 21 (reentry 17) |
| `12c-d14-result1/2/3` (`12c_d14_v5.json`) | `6708..6783`, false `7388` | `7203..7219` -> `EVENTD14.MES` | `9581` | `7219` -> `MACHI.MES` at `7360` | 9 / 1 / 1 | 72 / 70 / 50 (reentry 28) |

Members: `12C.MES`, the callee, `START.MES` (calendar context),
`DEF_MAIN.MES`, `LIBLARY.LIB`, and `D_PIC.MES` for D08 and D14. D01, D08
and D14 ask the player a question (one routine-40 contract each, three
answers, one route per answer). Manual seeds: D02's guard compares the date
with `banked_u16[253]` (the day D01 stamped), so `banked_u16[253] = 501` was
seeded into the baseline and its date cases; D03's guard requires the
opposite (`state_u16[7] != banked_u16[253]`) and the drafter's default
`banked_u16[253] = 0` satisfies it; D01's and D14's own free branches on
`banked_u16[212]` (Maki's affection) were resolved into direct variants by
the drafter. Every ending in the game vocabulary is a map return whose
postlude is the place's.

Batch checks: `original event analysis 12C D01`, `12C D02`, `12C D03`,
`12C D08`, `12C D14`. The v4 documents `maki.town.12c.01.1`, `.02.1`,
`.03.1`, `.08.1` and `.14.1` are projected from these groups since the same
day.

## Pictures the scripts name and the archives do not ship (2026-09-23)

`EVENTD01.MES` names `d01z.mmo` in the `mmo_resource_marker` records at
`431..445` and `543..557` and `d01zan.mmo` at `680..696` and `884..900`;
`EVENTD02.MES` names the same two at the same four coordinates, `d02z.mmo`
at `3083..3097` and `3195..3209`, and `d01z.mmo` / `d01zan.mmo` again at
`4764..4778`, `4876..4890`, `5013..5029` and `5217..5233`. The Playback
pass of `original catalog group routes` reaches them on both rows' default
routes (D01 step 7; D02 steps 6, 43 and 71). No shipped archive contains
any of the three names - not `mmo.arc` (the picture archive `AI5WIN.INI`
configures), `data.arc`, or any other ARC in ELFIMAGE - while the same
record shape names pictures that do ship elsewhere (`a17z.mmo`,
`e06z.mmo`, `l06z.mmo` and their `...zan.mmo`). `SCENE_D01.MES` and
`MAKI_H.MES` name them too. Evidence type: the authoritative `mes.arc`
records and a name search of every ELFIMAGE archive; what the native host
does when the resource is absent is not established.

*Annotation 2026-10-07 (WD-21 U1 C5).* The step numbers above (D01 step 7; D02
steps 6, 43 and 71) are the Playback pass's of 2026-09-23; one playback step per
spoken line (EP-13, Core 0.362.0, 2026-09-24) renumbered them, so they are history,
while the names, the record coordinates and the absence are unchanged. The three
names are in the known-absent register
(`config/event_catalog/known_absent_media_v1.json`, `D01Z.MMO`, `D01ZAN.MMO`,
`D02Z.MMO`), and the group-route check fails on an absence the register does not list.
