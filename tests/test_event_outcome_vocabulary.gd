extends "res://tests/test_case.gd"

## EP-09: synthetic coverage mirroring the Python unit cases for
## `KakyuEventOutcomeVocabulary`'s four ported functions (`v4_terminal_outcome`,
## `catalog_route_outcome`, `catalog_terminal_outcome`, `phrase`), plus one
## check per tracked catalog row (`config/event_catalog/original_events_v1.json`)
## that the GDScript `catalog_route_outcome` equals the Python result. The
## Python table below is a literal snapshot, regenerated 2026-10-05 (EP-12 TALK
## follow-ups) after `N_TALK1`'s resume was measured to reach the `FLOOR5.MES`
## handoff (681 rows, catalog revision 40: `n-talk-1` is a three-hop flow, a
## `map_return` to "school floor 5" with `postlude: "event"`, no longer a
## `place_menu`; no other row moved); regenerated 2026-10-05 (EP-12 TALK
## rest unit) after `promote_analysis_groups.py` promoted the other eleven
## heroines' conversation scripts, Tina's `M_TALK` and the characters' `N_TALK`..
## `Q_TALK1` (681 rows, catalog revision 39: the 88 rung scripts and the
## three-hop `m-talk-plain` and `q-talk-plain` are `map_return` with `postlude:
## "event"`, the 8 plain scripts and the seven two-hop character rows
## `place_menu`); regenerated 2026-10-04 (EP-12 TALK
## K unit) after `promote_analysis_groups.py` promoted heroine K's nine
## conversation scripts (576 rows, catalog revision 38; the eight rung scripts,
## three-hop flows ending at the `MACHI.MES` handoff, are `map_return` with
## `postlude: "event"`; the plain script, a two-hop flow, is `place_menu`);
## regenerated 2026-10-04 (EP-12 H
## unit) after `promote_analysis_groups.py` promoted the 13 recollection
## ladders of the room (567 rows, catalog revision 37; all 13 are `place_menu`:
## a two-hop flow whose ladder hop returns to the room, whose return chain
## reaches the room-action menu again); regenerated 2026-10-04 (EP-12
## all-menus unit) after `promote_analysis_groups.py` promoted the other
## twelve album menus (554 rows, catalog revision 36; all 365 album-scene
## rows are `place_menu`); regenerated 2026-10-04 (EP-12 SCENE J unit) after
## heroine J's 25 album scenes (214 rows, catalog revision 35; all 25 are
## `place_menu`: the row's last terminal is the menu loop boundary that
## follows the scene's own return); previously regenerated 2026-09-25 (EP-12
## PROMIS checkpoint C) after `promote_analysis_groups.py` promoted the
## twelve `01m-<letter>-promis` rows (187 rows, catalog revision 32; all
## twelve are `map_return` to MACHI.MES, `postlude: "place"` - each route's
## default option is a nested_call whose caller resume is `natural_handoff`);
## previously regenerated 2026-09-25 (EP-12 C..L date batch) after
## `promote_analysis_groups.py` promoted the 27
## `01m-<letter>-date` flow routes C..L declared to their own rows (175 rows,
## catalog revision 31; 24 of the 27 are `map_return` to MACHI.MES, 3 are
## `chain` - E/I's own HOTEL2 open choice and L's own hotel terminal, each to
## `44C.MES`, per docs/spec/mes/heroine_date_flows.md); previously
## regenerated 2026-09-25 (EP-12 B date template unit) after
## `promote_analysis_groups.py` promoted the three `01m-b-date` flow routes
## to their own rows (148 rows, catalog revision 30; all six a-date/b-date
## routes are `map_return` to MACHI.MES); previously regenerated 2026-09-24
## (EP-12 catalog part) after the three
## `01m-a-date` flow routes were promoted (145 rows, catalog revision 29);
## before that (EP-03 step 2, owner ruling 2026-09-23) after the promotion tool
## reclassified the three GROUND.MES dependency stops landing exactly on
## another event's intro dispatch as `chain` (catalog revision 26);
## before that (EP-10 unit 5, 2026-09-21) after every catalog row became
## generated (142 rows, no hand-authored rows; first regenerated 2026-09-20
## after units 1/2):
##
##     py tools/event_outcome_vocabulary.py --catalog-outcomes-gd --catalog config/event_catalog/original_events_v1.json
##
## keyed by `event_id`, in the catalog's own row order.

const PYTHON_CATALOG_ROUTE_OUTCOMES := {
	"original/a-date-date5/01m-00002af7": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/a-date-hotel/01m-00002af7": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/a-date-town/01m-00002af7": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/a-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-01/miko_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-02/miko_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-03/miko_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-04/miko_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-05/miko_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-06/miko_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-07/miko_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-08/miko_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-09/miko_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-10/miko_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-11/miko_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-12/miko_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-13/miko_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-14/miko_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-15/miko_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-16/miko_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-17/miko_m-00000b83": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-18/miko_m-00000b83": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-19/miko_m-00000b83": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-20/miko_m-00000b83": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-21/miko_m-00000d5f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-h01/miko_m-00000e18": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-h02/miko_m-00000ea1": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-h03/miko_m-00000f2a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-h04/miko_m-00000fb3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-h05/miko_m-0000103c": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-h06/miko_m-000010c5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-h07/miko_m-0000114e": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-h08/miko_m-000011d7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-scene-h09/miko_m-00001260": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a-talk-00/01m-0001337e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/a-talk-30/01m-0001337e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/a-talk-40/01m-0001337e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/a-talk-50/01m-0001337e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/a-talk-60/01m-0001337e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/a-talk-70/01m-0001337e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/a-talk-80/01m-0001337e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/a-talk-90/01m-0001337e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/a-talk-plain/27c_ev-00003f6c": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/a_promis/01m-00013572": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b-date-date5/01m-00005ebf": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b-date-hotel/01m-00005ebf": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b-date-town/01m-00005ebf": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-01/mahoko_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-02/mahoko_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-03/mahoko_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-04/mahoko_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-05/mahoko_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-06/mahoko_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-07/mahoko_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-08/mahoko_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-09/mahoko_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-10/mahoko_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-11/mahoko_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-12/mahoko_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-13/mahoko_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-14/mahoko_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-15/mahoko_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-16/mahoko_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-17/mahoko_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-h01/mahoko_m-00000c40": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-h02/mahoko_m-00000cc9": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-h03/mahoko_m-00000d52": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-h04/mahoko_m-00000ddb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-h05/mahoko_m-00000e64": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-h06/mahoko_m-00000eed": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-h07/mahoko_m-00000f76": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-h08/mahoko_m-00000fff": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-scene-h09/mahoko_m-00001088": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/b-talk-00/01m-00014ba0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b-talk-30/01m-00014ba0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b-talk-40/01m-00014ba0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b-talk-50/01m-00014ba0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b-talk-60/01m-00014ba0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b-talk-70/01m-00014ba0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b-talk-80/01m-00014ba0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b-talk-90/01m-00014ba0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/b_promis/01m-00014d7e": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-date-date5/01m-000044db": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-date-hotel/01m-000044db": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-date-town/01m-000044db": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-01/nana_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-02/nana_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-03/nana_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-04/nana_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-05/nana_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-06/nana_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-07/nana_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-08/nana_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-09/nana_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-10/nana_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-11/nana_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-12/nana_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-13/nana_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-14/nana_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-15/nana_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-16/nana_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-17/nana_m-00000b83": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-18/nana_m-00000b83": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-19/nana_m-00000b83": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-20/nana_m-00000b83": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-21/nana_m-00000d5f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-h01/nana_m-00000e18": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-h02/nana_m-00000ea1": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-h03/nana_m-00000f2a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-h04/nana_m-00000fb3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-h05/nana_m-0000103c": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-h06/nana_m-000010c5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-h07/nana_m-0000114e": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-h08/nana_m-000011d7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-scene-h09/nana_m-00001260": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c-talk-00/01m-00013f92": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-talk-30/01m-00013f92": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-talk-40/01m-00013f92": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-talk-50/01m-00013f92": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-talk-60/01m-00013f92": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-talk-70/01m-00013f92": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-talk-80/01m-00013f92": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-talk-90/01m-00013f92": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/c-talk-plain/27c_ev-0000738a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/c_promis/01m-000141a0": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d-date-date5/01m-00006bb1": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d-date-hotel/01m-00006bb1": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d-date-town/01m-00006bb1": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-01/maki_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-02/maki_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-03/maki_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-04/maki_m-00000463": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-05/maki_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-06/maki_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-07/maki_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-08/maki_m-0000062b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-09/maki_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-10/maki_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-11/maki_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-12/maki_m-000007f3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-13/maki_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-14/maki_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-15/maki_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-16/maki_m-000009bb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-17/maki_m-00000b83": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-18/maki_m-00000b83": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-19/maki_m-00000b83": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-h01/maki_m-00000d18": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-h02/maki_m-00000da1": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-h03/maki_m-00000e2a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-h04/maki_m-00000eb3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-h05/maki_m-00000f3c": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-h06/maki_m-00000fc5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-h07/maki_m-0000104e": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-h08/maki_m-000010d7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-scene-h09/maki_m-00001160": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/d-talk-00/01m-000151f4": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d-talk-30/01m-000151f4": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d-talk-40/01m-000151f4": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d-talk-50/01m-000151f4": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d-talk-60/01m-000151f4": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d-talk-70/01m-000151f4": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d-talk-80/01m-000151f4": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d-talk-90/01m-000151f4": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/d_promis/01m-00015465": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/e-date-date5/01m-00003170": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/e-date-hotel/01m-00003170": {"outcome": "chain", "postlude": "", "next_target": "44C.MES", "map": "", "reason": ""},
	"original/e-date-town/01m-00003170": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/e-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-01/mizuho_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-02/mizuho_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-03/mizuho_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-04/mizuho_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-05/mizuho_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-06/mizuho_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-07/mizuho_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-08/mizuho_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-09/mizuho_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-10/mizuho_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-11/mizuho_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-12/mizuho_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-13/mizuho_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-14/mizuho_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-15/mizuho_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-16/mizuho_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-17/mizuho_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-18/mizuho_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-19/mizuho_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-20/mizuho_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-21/mizuho_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-22/mizuho_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-23/mizuho_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-24/mizuho_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-h01/mizuho_m-00000f66": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-h02/mizuho_m-00000fef": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-h03/mizuho_m-00001078": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-h04/mizuho_m-00001101": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-h05/mizuho_m-0000118a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-h06/mizuho_m-00001213": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-h07/mizuho_m-0000129c": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-h08/mizuho_m-00001325": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-scene-h09/mizuho_m-000013ae": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e-talk-00/01m-0001365e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/e-talk-30/01m-0001365e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/e-talk-40/01m-0001365e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/e-talk-50/01m-0001365e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/e-talk-60/01m-0001365e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/e-talk-70/01m-0001365e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/e-talk-80/01m-0001365e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/e-talk-90/01m-0001365e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/e-talk-plain/27c_ev-000044ab": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/e_promis/01m-00013866": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventa01/27c3b-00000697": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR4.MES", "map": "school floor 4", "reason": ""},
	"original/eventa02/17m-00005a33": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventa03/25c-00002bc7": {"outcome": "map_return", "postlude": "event", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/eventa04/33c-000002d6": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR5.MES", "map": "school floor 5", "reason": ""},
	"original/eventa05/29c-0000310b": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR4.MES", "map": "school floor 4", "reason": ""},
	"original/eventa07/ground-00009fcc": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventa08/21c-000012b9": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventa08/21c-00001cf6": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventa10/17m-000055d9": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventa13/floor4-00000e4c": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR4.MES", "map": "school floor 4", "reason": ""},
	"original/eventa17/a_date5-00000c0f": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventa19/07m-0000025e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventa20/17m-0000aa11": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventa20/17m-0000ab73": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventa22/44m-0000c7f9": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventb01/13c-00000f93": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventb02/13c-000010cd": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventb03/01m-0000788f": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventb14/44m-0000c915": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventb15/11m-0000347b": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventc01/26m-0000034b": {"outcome": "map_return", "postlude": "event", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/eventc02/23m-00000e20": {"outcome": "map_return", "postlude": "event", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/eventc03/27c1a-000003bd": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR1.MES", "map": "school floor 1", "reason": ""},
	"original/eventc04/26m-00000750": {"outcome": "map_return", "postlude": "event", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/eventc05/23m-00001086": {"outcome": "map_return", "postlude": "event", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/eventc06/15c-00001413": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventc07/ground-00002743": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventc08/21c-00001f86": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventc10/17m-00003481": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventc11/18m-00009e4f": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventc12/ground-00003203": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventc12/ground-0000366f": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventc17/23m-00002c33": {"outcome": "map_return", "postlude": "event", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/eventc18/44m-000061c8": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventc21/26m-0000263c": {"outcome": "map_return", "postlude": "event", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/eventd01/12c-000007cd": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventd02/12c-0000098d": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventd03/12c-00000dde": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventd05/01m-00009e52": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventd06/10c-00005f77": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventd08/12c-00000fa6": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventd14/12c-00001c23": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/evente01/23m-00000f79": {"outcome": "map_return", "postlude": "event", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/evente03/23m-00002d31": {"outcome": "map_return", "postlude": "event", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/evente04/machi-00007634": {"outcome": "chain", "postlude": "", "next_target": "13C.MES", "map": "", "reason": ""},
	"original/evente05/25c-0000317d": {"outcome": "map_return", "postlude": "place", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/evente10/machi-0000df19": {"outcome": "chain", "postlude": "", "next_target": "MIZUHO26.MES", "map": "", "reason": ""},
	"original/evente11/15c-00001db7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/evente15/floor5-0000151d": {"outcome": "map_return", "postlude": "place", "next_target": "FLOOR4.MES", "map": "school floor 4", "reason": ""},
	"original/evente15/floor5-0000162d": {"outcome": "map_return", "postlude": "place", "next_target": "FLOOR4.MES", "map": "school floor 4", "reason": ""},
	"original/evente18/machi-000052c0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventf01/floor5-00000bec": {"outcome": "map_return", "postlude": "place", "next_target": "FLOOR4.MES", "map": "school floor 4", "reason": ""},
	"original/eventf02/ground-00007abb": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventf03/floor4-000013d6": {"outcome": "map_return", "postlude": "place", "next_target": "FLOOR3.MES", "map": "school floor 3", "reason": ""},
	"original/eventf06/44m-000007f8": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventf07/reiko42-00001f25": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventf17/44m-00003646": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventf20/25c-0000168b": {"outcome": "map_return", "postlude": "event", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/eventf22/44m-0000377a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventg01/30c-00000e52": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR2.MES", "map": "school floor 2", "reason": ""},
	"original/eventg01/30c-0000141d": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR2.MES", "map": "school floor 2", "reason": ""},
	"original/eventg01/30c-0000151c": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR2.MES", "map": "school floor 2", "reason": ""},
	"original/eventg02/35m-00000dbb": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR5.MES", "map": "school floor 5", "reason": ""},
	"original/eventg04/machi-00001727": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventg08/ground-0000794b": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventg11/01m-0000a9d9": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventg14/07m-00003660": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventg21/floor5-00000f4b": {"outcome": "map_return", "postlude": "place", "next_target": "FLOOR4.MES", "map": "school floor 4", "reason": ""},
	"original/eventh01/ground-00000a34": {"outcome": "chain", "postlude": "", "next_target": "EVENTK01.MES", "map": "", "reason": ""},
	"original/eventh01/ground-00000db9": {"outcome": "chain", "postlude": "", "next_target": "EVENTK01.MES", "map": "", "reason": ""},
	"original/eventh02/ground-000010df": {"outcome": "chain", "postlude": "", "next_target": "K_PIC.MES", "map": "", "reason": ""},
	"original/eventh02/ground-000014a5": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventh04/11m-00003c20": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventh06/26m-00000d07": {"outcome": "map_return", "postlude": "event", "next_target": "GROUND.MES", "map": "campus", "reason": ""},
	"original/eventh07/01m-000017bc": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventh10/floor5-00001d91": {"outcome": "map_return", "postlude": "place", "next_target": "FLOOR4.MES", "map": "school floor 4", "reason": ""},
	"original/eventh11/44m-000021b3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventh15/ground-00008036": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventh16/floor5-00001fe2": {"outcome": "map_return", "postlude": "place", "next_target": "FLOOR4.MES", "map": "school floor 4", "reason": ""},
	"original/eventh17/ground-00007b70": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventh18/44m-00006ad3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventh19/h_date3-00004867": {"outcome": "chain", "postlude": "", "next_target": "H_DATE5.MES", "map": "", "reason": ""},
	"original/eventi04/floor1-0000107a": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR1.MES", "map": "school floor 1", "reason": ""},
	"original/eventi04/floor1-000011a8": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR1.MES", "map": "school floor 1", "reason": ""},
	"original/eventi05/18m-00002af0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventi09/18m-000035bd": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventi10/15c-00000349": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventi13/35m-00000fe5": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR5.MES", "map": "school floor 5", "reason": ""},
	"original/eventi14/44m-000047a6": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventi16/01m-00009f5f": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventi21/05c-00000a00": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventi23/32c-00000bed": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR1.MES", "map": "school floor 1", "reason": ""},
	"original/eventi24/44c-00008574": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventj01/11m-000032c2": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventj04/01m-00009b85": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventj07/05m-0000056f": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventj09/46m-0000066a": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventj11/44m-0000cea4": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventj14/03c-00002ad5": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventj14/03c-00002c10": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventj15/03c-0000391b": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventj18/06c-0000350e": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventj19/07m-00004190": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventk01/ground-000018a4": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventk01/ground-000041db": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventk02/ground-000045a8": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventk06/06m-0000177c": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventk09/ground-0000fab1": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventk13/18m-00006bea": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventk14/11m-00006a10": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventk15/k_date3-000043da": {"outcome": "chain", "postlude": "", "next_target": "K_DATE5.MES", "map": "", "reason": ""},
	"original/eventl02/35m-00000eb9": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR5.MES", "map": "school floor 5", "reason": ""},
	"original/eventl03/01m-0000b001": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventl04/18m-000085dc": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventl05/19c-00000f50": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventl06/05m-00001262": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventl07/21c-00002185": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventl08/06c-000018c7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventl10/44m-000100a3": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventl11/09m-000046cd": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventl13/28c-000002af": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR1.MES", "map": "school floor 1", "reason": ""},
	"original/eventl16/20c-0000050b": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventl18/floor4-00000f90": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR4.MES", "map": "school floor 4", "reason": ""},
	"original/eventl20/34c-0000096c": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR5.MES", "map": "school floor 5", "reason": ""},
	"original/eventl25/44c-00006c18": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventm01/27c_ev-0000170e": {"outcome": "map_return", "postlude": "place", "next_target": "FLOOR5.MES", "map": "school floor 5", "reason": ""},
	"original/eventm03/44c-0000eefe": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventm04/10m-00004dcc": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventm05/43c-00000e56": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventm06/01m-00008072": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventm08/21m-00002fb3": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventm09/01m-000090ca": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventm10/44c-0000d2cd": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventm10/44c-0000d615": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventm14/27c_ev-00003237": {"outcome": "map_return", "postlude": "place", "next_target": "FLOOR5.MES", "map": "school floor 5", "reason": ""},
	"original/eventm15/19m-000033bb": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventm16/18m-00004440": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventm17/44c-0000c9c7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/eventm18/floor5-0000182b": {"outcome": "map_return", "postlude": "place", "next_target": "FLOOR4.MES", "map": "school floor 4", "reason": ""},
	"original/eventm20/09m-00002e8f": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/eventq01/16m-0000a4f2": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-date-date5/01m-0000247e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-date-hotel/01m-0000247e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-date-town/01m-0000247e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-01/reiko_m-00000465": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-02/reiko_m-00000465": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-03/reiko_m-00000465": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-04/reiko_m-00000465": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-05/reiko_m-0000062d": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-06/reiko_m-0000062d": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-07/reiko_m-0000062d": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-08/reiko_m-0000062d": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-09/reiko_m-000007f5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-10/reiko_m-000007f5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-11/reiko_m-000007f5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-12/reiko_m-000007f5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-13/reiko_m-000009bd": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-14/reiko_m-000009bd": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-15/reiko_m-000009bd": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-16/reiko_m-000009bd": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-17/reiko_m-00000b85": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-18/reiko_m-00000b85": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-19/reiko_m-00000b85": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-20/reiko_m-00000b85": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-21/reiko_m-00000d61": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-h01/reiko_m-00000e1a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-h02/reiko_m-00000ea3": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-h03/reiko_m-00000f2c": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-h04/reiko_m-00000fb5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-h05/reiko_m-0000103e": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-h06/reiko_m-000010c7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-h07/reiko_m-00001150": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-h08/reiko_m-000011d9": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-scene-h09/reiko_m-00001262": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f-talk-00/01m-0001308a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-talk-30/01m-0001308a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-talk-40/01m-0001308a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-talk-50/01m-0001308a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-talk-60/01m-0001308a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-talk-70/01m-0001308a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-talk-80/01m-0001308a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-talk-90/01m-0001308a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/f-talk-plain/27c_ev-0000329f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/f_promis/01m-00013292": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-date-date5/01m-00003e62": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-date-hotel/01m-00003e62": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-date-town/01m-00003e62": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-01/ryoko_m-00000465": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-02/ryoko_m-00000465": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-03/ryoko_m-00000465": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-04/ryoko_m-00000465": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-05/ryoko_m-0000062d": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-06/ryoko_m-0000062d": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-07/ryoko_m-0000062d": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-08/ryoko_m-0000062d": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-09/ryoko_m-000007f5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-10/ryoko_m-000007f5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-11/ryoko_m-000007f5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-12/ryoko_m-000007f5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-13/ryoko_m-000009bd": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-14/ryoko_m-000009bd": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-15/ryoko_m-000009bd": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-16/ryoko_m-000009bd": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-17/ryoko_m-00000b85": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-h01/ryoko_m-00000c3e": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-h02/ryoko_m-00000cc7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-h03/ryoko_m-00000d50": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-h04/ryoko_m-00000dd9": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-h05/ryoko_m-00000e62": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-h06/ryoko_m-00000eeb": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-h07/ryoko_m-00000f74": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-h08/ryoko_m-00000ffd": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-scene-h09/ryoko_m-00001086": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g-talk-00/01m-00013cb0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-talk-30/01m-00013cb0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-talk-40/01m-00013cb0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-talk-50/01m-00013cb0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-talk-60/01m-00013cb0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-talk-70/01m-00013cb0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-talk-80/01m-00013cb0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-talk-90/01m-00013cb0": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/g-talk-plain/27c_ev-00002966": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/g_promis/01m-00013ea6": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-date-date5/01m-00004b54": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-date-hotel/01m-00004b54": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-date-town/01m-00004b54": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-01/miyuki_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-02/miyuki_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-03/miyuki_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-04/miyuki_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-05/miyuki_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-06/miyuki_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-07/miyuki_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-08/miyuki_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-09/miyuki_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-10/miyuki_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-11/miyuki_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-12/miyuki_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-13/miyuki_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-14/miyuki_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-15/miyuki_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-16/miyuki_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-17/miyuki_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-18/miyuki_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-19/miyuki_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-20/miyuki_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-21/miyuki_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-h01/miyuki_m-00000e1c": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-h02/miyuki_m-00000ea5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-h03/miyuki_m-00000f2e": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-h04/miyuki_m-00000fb7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-h05/miyuki_m-00001040": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-h06/miyuki_m-000010c9": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-h07/miyuki_m-00001152": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-h08/miyuki_m-000011db": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-scene-h09/miyuki_m-00001264": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h-talk-00/01m-0001428c": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-talk-30/01m-0001428c": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-talk-40/01m-0001428c": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-talk-50/01m-0001428c": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-talk-60/01m-0001428c": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-talk-70/01m-0001428c": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-talk-80/01m-0001428c": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-talk-90/01m-0001428c": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/h-talk-plain/27c_ev-000077c4": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/h_promis/01m-00014482": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/i-date-date5/01m-000037e9": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/i-date-hotel/01m-000037e9": {"outcome": "chain", "postlude": "", "next_target": "44C.MES", "map": "", "reason": ""},
	"original/i-date-town/01m-000037e9": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/i-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-01/mayumi_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-02/mayumi_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-03/mayumi_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-04/mayumi_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-05/mayumi_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-06/mayumi_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-07/mayumi_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-08/mayumi_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-09/mayumi_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-10/mayumi_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-11/mayumi_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-12/mayumi_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-13/mayumi_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-14/mayumi_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-15/mayumi_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-16/mayumi_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-17/mayumi_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-18/mayumi_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-19/mayumi_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-20/mayumi_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-21/mayumi_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-22/mayumi_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-23/mayumi_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-24/mayumi_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-h01/mayumi_m-00000f66": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-h02/mayumi_m-00000fef": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-h03/mayumi_m-00001078": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-h04/mayumi_m-00001101": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-h05/mayumi_m-0000118a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-h06/mayumi_m-00001213": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-h07/mayumi_m-0000129c": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-h08/mayumi_m-00001325": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-scene-h09/mayumi_m-000013ae": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i-talk-00/01m-00013952": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/i-talk-30/01m-00013952": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/i-talk-40/01m-00013952": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/i-talk-50/01m-00013952": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/i-talk-60/01m-00013952": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/i-talk-70/01m-00013952": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/i-talk-80/01m-00013952": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/i-talk-90/01m-00013952": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/i-talk-plain/27c_ev-000053ab": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/i_promis/01m-00013bc4": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/j-date-date5/01m-00006538": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/j-date-town/01m-00006538": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/j-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-01/minatu_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-02/minatu_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-03/minatu_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-04/minatu_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-05/minatu_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-06/minatu_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-07/minatu_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-08/minatu_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-09/minatu_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-10/minatu_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-11/minatu_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-12/minatu_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-13/minatu_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-14/minatu_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-15/minatu_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-16/minatu_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-h01/minatu_m-00000bae": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-h02/minatu_m-00000c37": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-h03/minatu_m-00000cc0": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-h04/minatu_m-00000d49": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-h05/minatu_m-00000dd2": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-h06/minatu_m-00000e5b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-h07/minatu_m-00000ee4": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-h08/minatu_m-00000f6d": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-scene-h09/minatu_m-00000ff6": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/j-talk-00/01m-00014e6a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/j-talk-30/01m-00014e6a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/j-talk-40/01m-00014e6a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/j-talk-50/01m-00014e6a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/j-talk-60/01m-00014e6a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/j-talk-70/01m-00014e6a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/j-talk-80/01m-00014e6a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/j-talk-90/01m-00014e6a": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/j_promis/01m-000150e3": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-date-date5/01m-000051cd": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-date-hotel/01m-000051cd": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-date-town/01m-000051cd": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-01/ai_m-0000045f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-02/ai_m-0000045f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-03/ai_m-0000045f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-04/ai_m-0000045f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-05/ai_m-00000627": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-06/ai_m-00000627": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-07/ai_m-00000627": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-08/ai_m-00000627": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-09/ai_m-000007ef": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-10/ai_m-000007ef": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-11/ai_m-000007ef": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-12/ai_m-000007ef": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-13/ai_m-000009b7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-14/ai_m-000009b7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-15/ai_m-000009b7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-16/ai_m-000009b7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-h01/ai_m-00000ba6": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-h02/ai_m-00000c2f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-h03/ai_m-00000cb8": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-h04/ai_m-00000d41": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-h05/ai_m-00000dca": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-h06/ai_m-00000e53": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-h07/ai_m-00000edc": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-h08/ai_m-00000f65": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-scene-h09/ai_m-00000fee": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k-talk-00/01m-0001456e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-talk-30/01m-0001456e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-talk-40/01m-0001456e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-talk-50/01m-0001456e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-talk-60/01m-0001456e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-talk-70/01m-0001456e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-talk-80/01m-0001456e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-talk-90/01m-0001456e": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k-talk-plain/27c_ev-000079f9": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/k_pic/ground-00001c3b": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/k_promis/01m-0001479b": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/l-date-date5/01m-00005846": {"outcome": "chain", "postlude": "", "next_target": "44C.MES", "map": "", "reason": ""},
	"original/l-date-hotel/01m-00005846": {"outcome": "chain", "postlude": "", "next_target": "44C.MES", "map": "", "reason": ""},
	"original/l-date-town/01m-00005846": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/l-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-01/sizuka_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-02/sizuka_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-03/sizuka_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-04/sizuka_m-00000467": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-05/sizuka_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-06/sizuka_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-07/sizuka_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-08/sizuka_m-0000062f": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-09/sizuka_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-10/sizuka_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-11/sizuka_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-12/sizuka_m-000007f7": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-13/sizuka_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-14/sizuka_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-15/sizuka_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-16/sizuka_m-000009bf": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-17/sizuka_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-18/sizuka_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-19/sizuka_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-20/sizuka_m-00000b87": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-21/sizuka_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-22/sizuka_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-23/sizuka_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-24/sizuka_m-00000d63": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-h01/sizuka_m-00000f66": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-h02/sizuka_m-00000fef": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-h03/sizuka_m-00001078": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-h04/sizuka_m-00001101": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-h05/sizuka_m-0000118a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-h06/sizuka_m-00001213": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-h07/sizuka_m-0000129c": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-h08/sizuka_m-00001325": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-scene-h09/sizuka_m-000013ae": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l-talk-00/01m-00014887": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/l-talk-30/01m-00014887": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/l-talk-40/01m-00014887": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/l-talk-50/01m-00014887": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/l-talk-60/01m-00014887": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/l-talk-70/01m-00014887": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/l-talk-80/01m-00014887": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/l-talk-90/01m-00014887": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/l-talk-plain/27c_ev-00007c3c": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/l_promis/01m-00014ab4": {"outcome": "map_return", "postlude": "place", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/m-h/43c-0000904a": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-01/tina_m-00000468": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-02/tina_m-00000468": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-03/tina_m-00000468": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-04/tina_m-00000468": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-05/tina_m-00000630": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-06/tina_m-00000630": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-07/tina_m-00000630": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-08/tina_m-00000630": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-09/tina_m-000007f8": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-10/tina_m-000007f8": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-11/tina_m-000007f8": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-12/tina_m-000007f8": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-13/tina_m-000009c0": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-14/tina_m-000009c0": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-15/tina_m-000009c0": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-scene-16/tina_m-000009c0": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/m-talk-plain/01m-0000bac1": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
	"original/n-talk-1/27c_ev-000141fb": {"outcome": "map_return", "postlude": "event", "next_target": "FLOOR5.MES", "map": "school floor 5", "reason": ""},
	"original/n-talk-2/11m-000085e5": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/n-talk-3/11m-0000894b": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/n-talk-plain/27c_ev-00000637": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/o-talk-plain/27c_ev-00008b3c": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/p-talk-plain/27c_ev-00009cc0": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/q-talk-1/27c_ev-00009404": {"outcome": "place_menu", "postlude": "", "next_target": "", "map": "", "reason": ""},
	"original/q-talk-plain/01m-0000bd47": {"outcome": "map_return", "postlude": "event", "next_target": "MACHI.MES", "map": "town", "reason": ""},
}



func _ready() -> void:
	_test_v4_terminal_outcome()
	_test_catalog_route_outcome()
	_test_catalog_terminal_outcome()
	_test_matched_terminal_outcome()
	_test_phrase()
	_test_catalog_rows_match_python()
	get_tree().quit(1 if _failed else 0)


func _test_v4_terminal_outcome() -> void:
	var root_map := KakyuEventOutcomeVocabulary.v4_terminal_outcome({"kind": "root_handoff", "next_target": "MACHI.MES"})
	_check(
		root_map.outcome == "map_return" and root_map.postlude == "event" and root_map.map == "town",
		"v4_terminal_outcome: root_handoff to a map is map_return/event"
	)
	var root_chain := KakyuEventOutcomeVocabulary.v4_terminal_outcome({"kind": "root_handoff", "next_target": "13C.MES"})
	_check(root_chain.outcome == "chain", "v4_terminal_outcome: root_handoff to a non-map is chain")
	var natural_map := KakyuEventOutcomeVocabulary.v4_terminal_outcome({"kind": "natural_handoff", "next_target": "GROUND.MES"})
	_check(
		natural_map.outcome == "map_return" and natural_map.postlude == "place" and natural_map.map == "campus",
		"v4_terminal_outcome: natural_handoff to a map is map_return/place"
	)
	var natural_chain := KakyuEventOutcomeVocabulary.v4_terminal_outcome({"kind": "natural_handoff", "next_target": "EVENTK01.MES"})
	_check(natural_chain.outcome == "chain", "v4_terminal_outcome: natural_handoff to a non-map is chain")
	_check(
		KakyuEventOutcomeVocabulary.v4_terminal_outcome({"kind": "def_selection_boundary"}).outcome == "place_menu",
		"v4_terminal_outcome: def_selection_boundary is place_menu"
	)
	_check(
		KakyuEventOutcomeVocabulary.v4_terminal_outcome({"kind": "caller_menu_loop"}).outcome == "place_menu",
		"v4_terminal_outcome: caller_menu_loop is place_menu"
	)
	var dependency_stop := KakyuEventOutcomeVocabulary.v4_terminal_outcome({"kind": "dependency_stop"})
	_check(
		dependency_stop.outcome == "unresolved" and dependency_stop.reason == "dependency_stop",
		"v4_terminal_outcome: dependency_stop is unresolved/dependency_stop"
	)
	var callee_return := KakyuEventOutcomeVocabulary.v4_terminal_outcome({"kind": "callee_return"})
	_check(
		callee_return.outcome == "unresolved" and callee_return.reason == "continuation_undeclared",
		"v4_terminal_outcome: callee_return is unresolved/continuation_undeclared"
	)
	var unknown := KakyuEventOutcomeVocabulary.v4_terminal_outcome({"kind": "something_else"})
	_check(
		unknown.outcome == "unresolved" and unknown.reason == "unknown_kind:something_else",
		"v4_terminal_outcome: an unrecognized kind is unresolved with the kind named"
	)


func _test_catalog_route_outcome() -> void:
	var caller_handoff_map := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "caller_handoff", "next_target": "MACHI.MES", "sequence": 10},
	])
	_check(
		caller_handoff_map.outcome == "map_return" and caller_handoff_map.postlude == "place",
		"catalog_route_outcome: caller_handoff to a map is map_return/place"
	)
	var root_replacement_map := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "root_replacement", "next_target": "MACHI.MES", "sequence": 10},
	])
	_check(
		root_replacement_map.outcome == "map_return" and root_replacement_map.postlude == "event",
		"catalog_route_outcome: root_replacement to a map is map_return/event"
	)
	var normal_completion_map := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "normal_completion", "next_target": "GROUND.MES", "sequence": 10},
	])
	_check(
		normal_completion_map.outcome == "map_return" and normal_completion_map.postlude == "event",
		"catalog_route_outcome: normal_completion to a map is map_return/event"
	)
	var caller_handoff_chain := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "caller_handoff", "next_target": "13C.MES", "sequence": 10},
	])
	_check(caller_handoff_chain.outcome == "chain", "catalog_route_outcome: caller_handoff to a non-map is chain")
	var target_missing := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "caller_handoff", "next_target": "", "sequence": 10},
	])
	_check(
		target_missing.outcome == "unresolved" and target_missing.reason == "target_missing",
		"catalog_route_outcome: caller_handoff with an empty target is unresolved/target_missing"
	)
	var def_selection := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "analysis_boundary", "runtime_status": "def_selection_boundary", "sequence": 10},
	])
	_check(def_selection.outcome == "place_menu", "catalog_route_outcome: analysis_boundary/def_selection_boundary is place_menu")
	var menu_loop := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "analysis_boundary", "runtime_status": "loop_boundary", "sequence": 30},
	])
	_check(
		menu_loop.outcome == "place_menu" and str(menu_loop.reason).is_empty(),
		"catalog_route_outcome: analysis_boundary/loop_boundary (a caller_menu_loop resume) is place_menu"
	)
	var other_status := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "analysis_boundary", "runtime_status": "shared_routine_boundary", "sequence": 10},
	])
	_check(
		other_status.outcome == "unresolved" and other_status.reason == "shared_routine_boundary",
		"catalog_route_outcome: analysis_boundary with another runtime_status is unresolved with that status named"
	)
	var script_dispatch_chain := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "analysis_boundary", "runtime_status": "script_dispatch_boundary", "next_target": "EVENTK01.MES", "sequence": 10},
	])
	_check(
		script_dispatch_chain.outcome == "chain" and script_dispatch_chain.next_target == "EVENTK01.MES",
		"catalog_route_outcome: analysis_boundary/script_dispatch_boundary with a next_target is chain (EP-03 step 2)"
	)
	var script_dispatch_no_target := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "analysis_boundary", "runtime_status": "script_dispatch_boundary", "sequence": 10},
	])
	_check(
		script_dispatch_no_target.outcome == "unresolved" and script_dispatch_no_target.reason == "script_dispatch_boundary",
		"catalog_route_outcome: analysis_boundary/script_dispatch_boundary without a next_target stays unresolved"
	)
	var rejection := KakyuEventOutcomeVocabulary.catalog_route_outcome([{"kind": "rejection_return", "sequence": 10}])
	_check(
		rejection.outcome == "not_triggered" and rejection.reason == "rejection_return",
		"catalog_route_outcome: rejection_return is not_triggered/rejection_return"
	)
	var early_map := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "early_return", "next_target": "MACHI.MES", "sequence": 10},
	])
	_check(
		early_map.outcome == "map_return" and early_map.postlude == "event",
		"catalog_route_outcome: early_return to a map is map_return/event"
	)
	var early_end := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "early_return", "next_target": "", "sequence": 10},
	])
	_check(
		early_end.outcome == "unresolved" and early_end.reason == "early_end",
		"catalog_route_outcome: early_return to a non-map is unresolved/early_end"
	)
	var callee_return_only := KakyuEventOutcomeVocabulary.catalog_route_outcome([{"kind": "callee_return_only", "sequence": 10}])
	_check(
		callee_return_only.outcome == "unresolved" and callee_return_only.reason == "continuation_undeclared",
		"catalog_route_outcome: callee_return_only as the last terminal is unresolved/continuation_undeclared"
	)
	var caller_postlude := KakyuEventOutcomeVocabulary.catalog_route_outcome([{"kind": "caller_postlude", "sequence": 10}])
	_check(
		caller_postlude.outcome == "unresolved" and caller_postlude.reason == "continuation_undeclared",
		"catalog_route_outcome: caller_postlude as the last terminal is unresolved/continuation_undeclared"
	)
	var prefix_end := KakyuEventOutcomeVocabulary.catalog_route_outcome([{"kind": "prefix_end", "sequence": 10}])
	_check(
		prefix_end.outcome == "unresolved" and prefix_end.reason == "prefix_end",
		"catalog_route_outcome: prefix_end is unresolved with the kind named"
	)
	var unresolved_host_handoff := KakyuEventOutcomeVocabulary.catalog_route_outcome([{"kind": "unresolved_host_handoff", "sequence": 10}])
	_check(
		unresolved_host_handoff.outcome == "unresolved" and unresolved_host_handoff.reason == "unresolved_host_handoff",
		"catalog_route_outcome: unresolved_host_handoff is unresolved with the kind named"
	)
	var ordered := KakyuEventOutcomeVocabulary.catalog_route_outcome([
		{"kind": "caller_handoff", "next_target": "MACHI.MES", "sequence": 30},
		{"kind": "caller_postlude", "sequence": 20},
		{"kind": "callee_return_only", "sequence": 10},
	])
	_check(ordered.outcome == "map_return", "catalog_route_outcome: orders by sequence before taking the last")
	var empty_list := KakyuEventOutcomeVocabulary.catalog_route_outcome([])
	_check(
		empty_list.outcome == "unresolved" and empty_list.reason == "terminals_missing",
		"catalog_route_outcome: an empty list is unresolved/terminals_missing"
	)


func _test_catalog_terminal_outcome() -> void:
	var caller_handoff := KakyuEventOutcomeVocabulary.catalog_terminal_outcome({"kind": "caller_handoff", "next_target": "MACHI.MES"})
	_check(
		caller_handoff.outcome == "map_return" and caller_handoff.postlude == "place",
		"catalog_terminal_outcome: caller_handoff is postlude place"
	)
	var root_replacement := KakyuEventOutcomeVocabulary.catalog_terminal_outcome({"kind": "root_replacement", "next_target": "MACHI.MES"})
	_check(
		root_replacement.outcome == "map_return" and root_replacement.postlude == "event",
		"catalog_terminal_outcome: root_replacement is postlude event"
	)
	var normal_completion := KakyuEventOutcomeVocabulary.catalog_terminal_outcome({"kind": "normal_completion", "next_target": "GROUND.MES"})
	_check(
		normal_completion.outcome == "map_return" and normal_completion.postlude == "event",
		"catalog_terminal_outcome: normal_completion is postlude event"
	)
	var script_dispatch_chain := KakyuEventOutcomeVocabulary.catalog_terminal_outcome(
		{"kind": "analysis_boundary", "runtime_status": "script_dispatch_boundary", "next_target": "K_PIC.MES"}
	)
	_check(
		script_dispatch_chain.outcome == "chain" and script_dispatch_chain.next_target == "K_PIC.MES",
		"catalog_terminal_outcome: analysis_boundary/script_dispatch_boundary with a next_target is chain (EP-03 step 2)"
	)


## EP-12 gallery (2026-10-04, tool decision): the Event Player phrases a
## matched `callee_return_only` terminal by the row's decided route outcome,
## mirroring `tests/test_event_outcome_vocabulary.py`'s
## `MatchedTerminalOutcomeTest`.
func _test_matched_terminal_outcome() -> void:
	var scene_row := [
		{"kind": "callee_return_only", "outcome": "continue", "runtime_status": "script_return", "sequence": 10, "next_target": ""},
		{"kind": "analysis_boundary", "outcome": "unresolved", "runtime_status": "loop_boundary", "sequence": 30, "next_target": ""},
	]
	var scene_return := KakyuEventOutcomeVocabulary.matched_terminal_outcome(scene_row[0], scene_row)
	_check(
		scene_return == KakyuEventOutcomeVocabulary.catalog_route_outcome(scene_row)
		and KakyuEventOutcomeVocabulary.phrase(scene_return) == "Back to the place menu",
		"matched_terminal_outcome: an album scene's callee return is phrased as the place menu"
	)
	var handoff_row := [
		scene_row[0],
		{"kind": "caller_handoff", "outcome": "normal_completion", "runtime_status": "script_handoff_boundary", "sequence": 30, "next_target": "MACHI.MES"},
	]
	var before_handoff := KakyuEventOutcomeVocabulary.matched_terminal_outcome(handoff_row[0], handoff_row)
	_check(
		before_handoff.outcome == "map_return" and before_handoff.map == "town" and before_handoff.postlude == "place",
		"matched_terminal_outcome: a callee return before a map handoff is phrased by the handoff"
	)
	var only := [scene_row[0]]
	var undecided := KakyuEventOutcomeVocabulary.matched_terminal_outcome(only[0], only)
	_check(
		undecided.outcome == "unresolved" and undecided.reason == "continuation_undeclared",
		"matched_terminal_outcome: a row whose route outcome is unresolved keeps the terminal's own reading"
	)
	for terminal in [scene_row[1], {"kind": "caller_postlude", "runtime_status": "script_return", "sequence": 20, "next_target": ""}, handoff_row[1]]:
		_check(
			KakyuEventOutcomeVocabulary.matched_terminal_outcome(terminal, scene_row) == KakyuEventOutcomeVocabulary.catalog_terminal_outcome(terminal),
			"matched_terminal_outcome: a %s terminal is read as before" % str(terminal.kind)
		)


func _test_phrase() -> void:
	_check(
		KakyuEventOutcomeVocabulary.phrase({"outcome": "map_return", "map": "town", "postlude": "event"}) == "Back to the town map",
		"phrase: map_return/town"
	)
	_check(
		KakyuEventOutcomeVocabulary.phrase({"outcome": "map_return", "map": "campus", "postlude": "event"}) == "Back to the campus map",
		"phrase: map_return/campus"
	)
	_check(
		KakyuEventOutcomeVocabulary.phrase({"outcome": "map_return", "map": "train", "postlude": "event"}) == "Back to the train",
		"phrase: map_return/train"
	)
	_check(
		KakyuEventOutcomeVocabulary.phrase({"outcome": "map_return", "map": "school floor 3", "postlude": "event"}) == "Back to school floor 3",
		"phrase: map_return/school floor N"
	)
	_check(
		KakyuEventOutcomeVocabulary.phrase({"outcome": "map_return", "map": "town", "postlude": "place"}) == "Back to the town map after the place's own lines",
		"phrase: map_return with a place postlude adds the suffix"
	)
	_check(KakyuEventOutcomeVocabulary.phrase({"outcome": "place_menu"}) == "Back to the place menu", "phrase: place_menu")
	_check(
		KakyuEventOutcomeVocabulary.phrase({"outcome": "chain", "next_target": "13C.MES"}) == "Continues into 13C.MES",
		"phrase: chain"
	)
	_check(KakyuEventOutcomeVocabulary.phrase({"outcome": "not_triggered"}) == "Not triggered", "phrase: not_triggered")
	_check(
		KakyuEventOutcomeVocabulary.phrase({"outcome": "unresolved", "reason": "dependency_stop"}) == "Unresolved: dependency_stop",
		"phrase: unresolved"
	)


func _test_catalog_rows_match_python() -> void:
	var seed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/event_catalog/original_events_v1.json"))
	var events: Array = seed.get("events", [])
	_check(events.size() == PYTHON_CATALOG_ROUTE_OUTCOMES.size(), "the catalog and the Python snapshot table cover the same number of events")
	for event in events:
		var event_id := str(event.get("event_id", ""))
		var expected: Dictionary = PYTHON_CATALOG_ROUTE_OUTCOMES.get(event_id, {})
		_check(not expected.is_empty(), "the Python snapshot table has an entry for %s" % event_id)
		var actual := KakyuEventOutcomeVocabulary.catalog_route_outcome(event.get("terminals", []))
		_check(
			actual.outcome == expected.get("outcome")
			and actual.postlude == expected.get("postlude")
			and actual.next_target == expected.get("next_target")
			and actual.map == expected.get("map")
			and actual.reason == expected.get("reason"),
			"catalog_route_outcome(%s) matches the Python result" % event_id
		)
		# `matched_terminal_outcome` is the Python snapshot's route outcome for
		# a `callee_return_only` terminal of a row with a decided route outcome,
		# and `catalog_terminal_outcome` for every other terminal.
		for terminal_value in event.get("terminals", []):
			var terminal: Dictionary = terminal_value
			var matched := KakyuEventOutcomeVocabulary.matched_terminal_outcome(terminal, event.get("terminals", []))
			if str(terminal.get("kind", "")) == "callee_return_only" and str(expected.get("outcome")) != "unresolved":
				_check(
					matched.outcome == expected.get("outcome") and matched.postlude == expected.get("postlude")
					and matched.next_target == expected.get("next_target") and matched.map == expected.get("map")
					and matched.reason == expected.get("reason"),
					"matched_terminal_outcome(%s) takes the Python route outcome for its callee return" % event_id
				)
			else:
				_check(
					matched == KakyuEventOutcomeVocabulary.catalog_terminal_outcome(terminal),
					"matched_terminal_outcome(%s) reads a %s terminal as catalog_terminal_outcome does" % [event_id, str(terminal.get("kind", ""))]
				)
