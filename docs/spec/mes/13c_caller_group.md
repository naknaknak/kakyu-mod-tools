# 13C caller group: EVENTB01 and EVENTB02 measured as groups

Measured on 2026-09-21 (EP-10 unit 5a) against the configured original
`ELFIMAGE/mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`, with the
route toolchain (`tools/draft_event_route_spec.py` on the caller inventory
`analysis/13c_group_measure.json`, then `tools/qualify_event_route.py
--register`). All coordinates are code-relative with exclusive end offsets.
This is a bounded original-event observation; the two sites were qualified
before as hand-authored catalog rows (Mahoko events B01 and B02), and the
groups reproduce what those rows declared through the shared call frame.

`13C.MES` is a town place script (MACHI location 10's target is `12C.MES`;
13C is the sibling place the same map dispatches). Its two EVENT intros
are nested calls (command `0x0F`) whose callee returns and whose caller
then hands the root to `MACHI.MES` after its own date-selected BGM prefix
(`X_MAS.WAV` on 1224, `SHOGATU.WAV` on 1301, `IDOU.WAV` otherwise, the
`0x0FA3..0x1017` prefix `docs/spec/mes/character_events.md` records for
B01).

| Route | Guard | Dispatch | Callee return | Caller resume -> handoff | Variants | Messages |
|---|---|---|---|---|---|---|
| `13c-b01` (`13c_b01_v5.json`) | `3876..3913`, false `4158` | `3987..4003` -> `EVENTB01.MES` | `1696` | `4003` -> `MACHI.MES` at `4130` (`natural_handoff`) | 7 | 17 (reentry 17) |
| `13c-b02` (`13c_b02_v5.json`) | `4158..4195`, false `4472` | `4301..4317` -> `EVENTB02.MES` | `2249` | `4317` -> `MACHI.MES` at `4444` (`natural_handoff`) | 7 | 18 (reentry 18) |

Members: `13C.MES`, the callee, `START.MES` (calendar context),
`DEF_MAIN.MES`, `LIBLARY.LIB`. Neither callee asks a question; the variants
are the guard edges the drafter derived (date and clock arms), no manual
seed was needed. The ending in the game vocabulary is a map return whose
postlude is the place's (`natural_handoff`). A reentry replays the callee
(no done gate of its own; the caller's guard closes the site).

Batch checks: `original event analysis 13C B01`, `original event analysis
13C B02`. The v4 documents `mahoko.town.13c.01.1` and `mahoko.town.13c.02.1`
are projected from these groups since the same day.

## Pictures the scripts name and the archives do not ship (2026-09-23)

`EVENTB01.MES` names `b01z.mmo` in the `mmo_resource_marker` records at
`431..445` and `543..557`; `EVENTB02.MES` names `b02z.mmo` at the same two
coordinates and `b02zan.mmo` at `680..696` and `884..900`. The Playback
pass of `original catalog group routes` reaches these records on both rows'
default routes (B01 step 3; B02 step 3). No shipped archive contains either
name - not `mmo.arc` (1,727 entries, the picture archive `AI5WIN.INI`
configures), `data.arc`, or any other ARC in ELFIMAGE - while the same
record shape names pictures that do ship elsewhere (`a17z.mmo` /
`a17zan.mmo` in `EVENTA17.MES`, `e06z.mmo` / `e06zan.mmo` in
`E_DATE2.MES`). The scene-replay scripts `SCENE_B01.MES`, `SCENE_B02.MES`
and `MAHOKO_H.MES` name them too. Evidence type: the authoritative
`mes.arc` records and a name search of every ELFIMAGE archive; what the
native host does when the resource is absent is not established.

*Annotation 2026-10-07 (WD-21 U1 C5).* The step numbers above (B01 step 3; B02
step 3) are the Playback pass's of 2026-09-23; one playback step per spoken line
(EP-13, Core 0.362.0, 2026-09-24) renumbered them, so they are history, while the
names, the record coordinates and the absence are unchanged. The three names are
in the known-absent register (`config/event_catalog/known_absent_media_v1.json`,
`B01Z.MMO`, `B02Z.MMO`, `B02ZAN.MMO`), and the group-route check fails on an
absence the register does not list.
