# Event name registry (`kakyu_event_names_registry/v1`)

`event_names.json` is the shared event name registry for WD-22: one row per
**event site** (one callee dispatched from one place in one caller), keyed
by (callee entry, caller entry, site ordinal). It is mirrored byte-identically
in both `kakyu-mod-tools` and the remake, generated here by
`tools/build_event_names.py` from `config/event_catalog/analysis_groups/*.json`
and `config/event_catalog/original_events_v1.json`, and fingerprinted on its
own so that renaming a title never moves the `contract_fingerprint` of the
event-definition contract.

## Id rule

```
<heroine>.<category>.<place>.<number>.<site>
nana.school.gate.07.1        EVENTC07 from the grounds' gate
ai.school.gate.09.1          EVENTK09 from the gate; its three answers are results
ai.school.gate.pic.1         K_PIC from the gate
miyuki.town.station.07.1     EVENTH07 from the station, with a train ride
minatu.town.station.04.1     EVENTJ04 from the station, the first proof
```

- `heroine`: the callee's letter family resolved through the gallery-menu
  table (A miko, B mahoko, C nana, D maki, E mizuho, F reiko, G ryoko, H
  miyuki, I mayumi, J minatu, K ai, L sizuka, M tina). A callee whose stem
  is `EVENT<letter><suffix>` or `<letter>_<suffix>` but whose letter is not
  in the table gets heroine `common` (Korean `공통`) and keeps its whole
  stem suffix as the `number`, so the id stays unique - `EVENTQ01.MES`
  (the staged, non-heroine callee from `16M.MES`, `docs/spec/mes/16m_caller_group.md`)
  -> `number` `q01`, `id` `common.town.16m.q01.1`, provisional titles
  "Common event at 16m (EVENTQ01)" / "16m에서 공통 이벤트 (EVENTQ01)". Any
  other stem shape (no `EVENT` prefix and no `<letter>_` prefix) still
  stops the tool with a report.
- `category`: the caller's family - `school` (GROUND, FLOOR1..FLOOR5),
  `town` (MACHI, the station 01M and the numbered town scripts), `date`
  (`*_DATE*` callers), `special` (a caller of no family).
- `place`: within `school`, `gate` (GROUND location 0) or `floor1`..`floor5`;
  within `town`, `station` for 01M, `machi` for MACHI, otherwise the caller
  stem in lower case; within `date` and `special`, the caller stem.
- `number`: the callee's stem without the `EVENT` prefix and the heroine
  letter (`EVENTC07` -> `07`, `K_PIC` -> `pic`). A `kakyu_event_analysis_group/v14`
  flow route (EP-12 catalog part, 2026-09-24) has no callee-stem suffix of
  its own to number by - every route of one flow dispatches the same first
  callee - so it is `date-<route id tail>` instead (`a-date-town` ->
  `date-town`, stripping the `<heroine letter>-date-` the route id itself
  carries); the id regex allows this one hyphenated shape. A gallery scene
  (EP-12 gallery, 2026-10-04: a callee `SCENE_<letter><number>` or
  `SCENE_<letter>_H<nn>` dispatched from an album menu `<ENGLISH NAME>_M.MES`)
  is numbered by its callee stem - `SCENE_J03` -> `03`, `SCENE_J_H01` ->
  `h01` - with `category` `special` and `place` the menu's stem in lower case
  (`minatu.special.minatu_m.03.1`); the row's route id must be
  `<letter>-scene-<number>`.
- `site`: the 1-based order of the callee's dispatch sites within the
  caller, by dispatch offset. Offsets never enter an id. A flow route's own
  site key gains the route id too (three routes of `01m-a-date` share one
  dispatch site, `01M.MES` -> `A_PIC.MES` at 11148 - the route id, not the
  offset, tells them apart).

A row is keyed by (callee entry, caller entry, site ordinal) and carries
`id`, `title_ko`, `title_en` (provisional, generated as "<heroine> at
<place> (<CALLEE>)" / "<place>에서 <heroine> (<CALLEE>)" until the owner
names the event), `heroine`,
`category`, `place`, `number`, `site`, `scene_kinds`, `aliases` (the catalog
`event_id`, the declaring groups and their route ids) and `evidence` (the
caller's dispatch offset/end/command and the callee entry).

## Fingerprint rule

`names_fingerprint` is computed the same way as every mirrored contract
directory in this repository: the SHA-256 over the concatenation of
`"<relative path>\t<sha256 of the file bytes>\n"` for every regular file
under this directory except `names_fingerprint` itself, paths relative to
the directory with `/` separators, sorted, LF line endings -
`tools/contract_fingerprint.py --name names_fingerprint`. Both repositories
recompute it the same way, so a mirrored copy cannot drift silently. A
change to the registry's content is a new `names_fingerprint` recorded in
both trackers; it never rides on the event-definition `contract_fingerprint`.

## Revisions

- 2026-09-15: the first registry, 142 sites, `names_fingerprint`
  `b7ffcea3abac019a78f8ac19e98d5259fc778a0eb3c7123424f257b435163e1a`,
  mirrored to the remake the same day.
- 2026-09-19: regenerated after the 44M B14 group was declared: the same
  142 ids, one row changed (`mahoko.town.44m.14.1` gained its group alias
  `44m-b14`). The v3 event definitions and their fixture set stay frozen
  and validate against the fingerprint they recorded; the v4 documents
  carry the new one; the remake reads the current registry from here.
- 2026-09-21 (EP-10 unit 5a): regenerated after the ten hand-authored
  13C/12C/11M/01M sites (EVENTB01, EVENTB02, EVENTD01, EVENTD02, EVENTD03,
  EVENTD08, EVENTD14, EVENTB15, EVENTB03, EVENTJ04) gained analysis groups;
  `tools/build_event_names.py`'s `EXPECTED_PAIR_COUNT` premise moved from
  120 to 130 (the ten new (callee, caller) pairs) per the owner's
  2026-09-19 ruling. The same 142 ids; ten rows gained their group alias
  (`13c-b01`, `13c-b02`, `12c-d01`, `12c-d02`, `12c-d03`, `12c-d08`,
  `12c-d14`, `11m-b15`, `01m-b03`, `01m-j04`); no title changed. The v3
  event definitions and their fixture set stay frozen and validate against
  the fingerprint they recorded; the v4 documents carry the new one; the
  remake reads the current registry from here.
- 2026-09-21 (EP-10 unit 5b/c, part 2): regenerated after every catalog row
  became EP-10 generated (each now carries `analysis_group`);
  `tools/build_event_names.py`'s `EXPECTED_CATALOG_COUNT` premise moved
  from 13 to 142 and the hand-rows-only filter on the catalog's site
  collection was removed. The same 142 ids; the `catalog_event_id` alias
  now names every row (129 rows gained it, having had none before)
  instead of only the thirteen previously hand-qualified rows; no title
  changed. The v3 event definitions and their fixture set stay frozen and
  validate against the fingerprint they recorded; the v4 documents carry
  the new one; the remake reads the current registry from here.

- 2026-09-24 (EP-12): the first `kakyu_event_analysis_group/v14` flow
  profile (`01m-a-date`, heroine A's date) joined the analysis groups.
  A flow is a hop chain from an origin guard, not a caller/callee dispatch
  site, so `tools/build_event_names.py` skips v14 profiles by schema and the
  registry did not move (the same 142 ids, bytes unchanged, fingerprint
  unchanged). How a flow enters this registry is the open decision of the
  catalog part of EP-12.
- 2026-09-24 (EP-12 catalog part): the open decision above is resolved - a
  v14 flow route is now a site of its own: the key is the flow's first
  dispatch (its hop 0's own outcome - here, `01M.MES` -> `A_PIC.MES` at
  11148, command 15) **plus the route id**, since every route of one flow
  shares that same first dispatch. The id rule gains one case for it: a
  flow route has no callee-stem suffix to number by, so `number` is
  `date-<route id tail>` (`a-date-town` -> `date-town`, stripping the
  `<heroine letter>-date-` the route id itself carries) - `id`'s own regex
  now allows one hyphenated `number` segment for this shape.
  `EXPECTED_PAIR_COUNT` moved from 130 to 131 (the new
  (`A_PIC.MES`, `01M.MES`) pair) and `EXPECTED_CATALOG_COUNT` from 142 to
  145 (`tools/promote_analysis_groups.py`'s own flow branch promotes one row
  per route, `CATALOG_REVISION` 29). Three new ids joined:
  `miko.town.station.date-town.1`, `miko.town.station.date-date5.1`,
  `miko.town.station.date-hotel.1`, each carrying `aliases.groups` naming
  `01m-a-date` and its own one route id, and (after the promoter's rows
  exist) `aliases.catalog_event_id` naming its own promoted row
  (`original/a-date-town/01m-00002af7` and siblings - the promoter's own
  `event_id` anchors the flow's *origin* guard, `01M.MES:10999`, not this
  registry site's dispatch coordinate). `scene_kinds` carries `train_ride`
  on all three (every route's own hops include TRAIN.MES's map-location
  contract). `names_fingerprint` moved (the stored file, not a value
  quoted here - a value quoted in this paragraph would itself change the
  bytes the fingerprint covers). The v3/v4/v5 event definitions and their
  fixture sets stay frozen and
  validate against the fingerprint they recorded; a flow route has no v4/v5
  document of its own in this unit (the flow definition shape is a
  separate, later owner decision).
- 2026-09-25 (EP-12 B date template unit): the same treatment for heroine
  B's date (`01m-b-date`, three routes measured by the new
  `tools/draft_date_flow_specs.py`/`tools/content_suite/cli/measure_date_flow.gd`
  pair). `EXPECTED_PAIR_COUNT` moved from 131 to 132 (the new
  (`B_PIC.MES`, `01M.MES`) pair) and `EXPECTED_CATALOG_COUNT` from 145 to
  148 (`CATALOG_REVISION` 30). Three new ids joined:
  `mahoko.town.station.date-town.1`, `mahoko.town.station.date-date5.1`,
  `mahoko.town.station.date-hotel.1`, each carrying `aliases.groups` naming
  `01m-b-date` and its own route id, and `aliases.catalog_event_id` naming
  its own promoted row (`original/b-date-town/01m-00005ebf` and siblings -
  hex8 of B's own origin guard, `01M.MES:24255`). `scene_kinds` carries
  `train_ride` on all three, the same as A's. `names_fingerprint` moved.
  The v3/v4/v5 event definitions and their fixture sets stay frozen and
  validate against the fingerprint they recorded.
- 2026-09-25 (EP-12 C..L date batch): the ten groups `01m-c-date` through
  `01m-l-date` (heroines Nana, Maki, Mizuho, Reiko, Ryoko, Miyuki, Mayumi,
  Minatu, Ai, Sizuka), measured by the same tool pair, extended for three
  structural departures beyond A/B's shape (see
  `docs/spec/mes/heroine_date_flows.md`). `EXPECTED_PAIR_COUNT` moved from
  132 to 142 (one new `(<letter>_PIC.MES, 01M.MES)` pair per heroine) and
  `EXPECTED_CATALOG_COUNT` from 148 to 175 (`CATALOG_REVISION` 31, +27
  promoted rows: C/E/F/G/H/I/K declare all three routes, D/J/L each leave
  one route out - see `docs/spec/mes/heroine_date_flows.md`'s own
  "Per-heroine departures" section for why). Twenty-seven new ids joined
  (`nana.town.station.date-{town,date5,hotel}.1` and its ten heroines'
  siblings, one triple per heroine except `maki`/`minatu` (`date-town`,
  `date-date5` only) and `sizuka` (`date-town`, `date-hotel` only)), each
  carrying `aliases.groups` naming its own `01m-<letter>-date` group and
  route id, and `aliases.catalog_event_id` naming its own promoted row.
  `scene_kinds` carries `train_ride` on every one, the same as A/B's.
  `names_fingerprint` moved twice in this batch (once after this
  registration, once more after `promote_analysis_groups.py` promoted the
  27 new catalog rows, which let this second regeneration attach
  `aliases.catalog_event_id` to them) - only the second, final value is
  recorded in the committed file. The v3/v4/v5 event definitions and their
  fixture sets stay frozen and validate against the fingerprint they
  recorded; v6 was fully regenerated (its own `package_binding.package_sha256`
  must agree with its index's single package reference, so it is not
  exempted from regeneration the way v4/v5 are).
- 2026-09-25 (EP-12 PROMIS checkpoint C): regenerated after the twelve
  `01m-<letter>-promis` groups were declared and registered (station-site
  route B..L declares all ten time options, A declares 7 of 10 - options
  8-10 need A's own latch and are measured-not-declared).
  `EXPECTED_PAIR_COUNT` moved from 142 to 154 (one new
  `(<letter>_PROMIS.MES, 01M.MES)` pair per heroine). Twelve new ids joined
  (`<heroine>.town.station.promis.1`, e.g. `miko.town.station.promis.1`),
  each carrying `aliases.groups` naming its own `01m-<letter>-promis` group
  and route ids. `names_fingerprint` moved twice in this batch (once after
  this registration - `4de039bff08f5f11501adb18a7c0cce1a5f5be1a1057e4ed84dd97e72df10039` -
  once more after `promote_analysis_groups.py` promoted the twelve new
  catalog rows, `EXPECTED_CATALOG_COUNT` 175 -> 187, `CATALOG_REVISION` 32,
  which let this second regeneration attach `aliases.catalog_event_id` to
  them) - only the second, final value is recorded in the committed
  `names_fingerprint` file itself, not restated here: this directory's own
  fingerprint covers every regular file in it including this README, so a
  value this paragraph quoted would already be one edit stale by the time
  it was committed (the same reason the C..L date batch entry above names
  its final value only that way). Unlike a flow route, PROMIS is the
  ordinary path, but a brand-new ordinary site has no v4/v5 document of its
  own to promote from (`config/event_definitions/v4/README.md`,
  `v5/README.md`); its document exists only as v6
  (`config/event_definitions/v6/README.md`, "2026-09-25 (EP-12 PROMIS
  checkpoint C)", which also names the scratch package-export option this
  needed). The v3/v4/v5 event definitions and their fixture sets stay
  frozen and validate against the fingerprint they recorded (carried into
  v4/v5 as a field patch, not a re-projection); v6 was fully regenerated.
- 2026-09-26 (EP-12 leftovers unit): regenerated after two more routes were
  declared - D's own hotel route and L's own date5 route, both left out of
  the C..L date batch by a route-toolchain limitation now fixed (Core
  0.368.0, `docs/spec/tech/content_tools.md`); A's own promise options 8-10
  were also declared this unit but add no new registry row (they extend
  `01m-a-promis`'s existing single site, the same way B..L's own ten options
  each already share one site). `EXPECTED_PAIR_COUNT` did not move (154,
  unchanged): a flow route's own registry pair is keyed by its shared first
  dispatch (hop 0), which D's and L's new routes reuse from their own
  group's existing routes, not a new (callee, caller) pair.
  `EXPECTED_CATALOG_COUNT` moved from 187 to 189
  (`tools/promote_analysis_groups.py`'s own flow branch promotes one row per
  route, `CATALOG_REVISION` 33). Two new ids joined:
  `maki.town.station.date-hotel.1`, `sizuka.town.station.date-date5.1`, each
  carrying `aliases.groups` naming its own group and route id, and (after
  promotion) `aliases.catalog_event_id` naming its own promoted row
  (`original/d-date-hotel/01m-00006bb1`, `original/l-date-date5/01m-00005846`
  - the same hex8 their own group's other routes already carry, since a flow
  route's own catalog id anchors the flow's origin guard, not this
  registry's own dispatch coordinate). `names_fingerprint` moved twice in
  this unit (once after this registration -
  `41707b69365a24780c02eb7c980bf6078910dd3f42ac97bb9416243a3f3735cf` - once
  more after `promote_analysis_groups.py` promoted the two new catalog rows
  and this second regeneration attached `aliases.catalog_event_id` to them)
  - only the second, final value is recorded in the committed
  `names_fingerprint` file itself, not restated here, the same reason the
  PROMIS checkpoint C entry above does not restate its own final value
  either. The v3/v4/v5 event definitions and their fixture sets stay frozen
  and validate against the fingerprint they recorded (carried into v4/v5 as
  a minimal, single-line field patch per file - not a JSON reparse/rewrite,
  which would have reformatted whitespace across every document instead of
  patching one field); v6 was fully regenerated (twice, to pick up the
  registry's own second, final fingerprint - see
  `config/event_definitions/v6/README.md`'s own entry for this unit).
- 2026-10-04 (EP-12 SCENE, heroine J): regenerated after `minatu-m-scene`, the
  first album-menu group, was declared (`config/event_catalog/analysis_groups/minatu_m_scene_v14.json`,
  a `kakyu_event_analysis_group/v14` flow with 25 routes, one per scene of
  `MINATU_M.MES`). Same shape, 25 new rows
  (`minatu.special.minatu_m.01.1` .. `16.1`, `.h01.1` .. `h09.1`), 189 -> 214
  rows, `EXPECTED_PAIR_COUNT` 154 -> 179 (each scene is its own
  (`SCENE_J..MES`, `MINATU_M.MES`) pair), `EXPECTED_CATALOG_COUNT` 189 -> 214
  (`tools/promote_analysis_groups.py`, `CATALOG_REVISION` 35). The id regex is
  unchanged: the gallery keeps the `special` category fall-through and the
  `gallery` tag is the catalog row's `display.categories`, not part of the id.
  The registry moved twice in this unit (the new rows, then the
  `aliases.catalog_event_id` promotion attaches); only the final value is in
  the committed `names_fingerprint` file, not restated here (this directory's
  fingerprint covers this README, so a quoted value would be stale by the time
  it was committed - the reason the entries above give). The v3/v4/v5 event
  definitions stay frozen; v6 was regenerated (`config/event_definitions/v6/README.md`).
- 2026-10-04 (EP-12 SCENE, the other twelve album menus): regenerated after
  the twelve remaining `<NAME>_M.MES` menus were declared as analysis groups
  (`config/event_catalog/analysis_groups/<name>_m_scene_v14.json`:
  `miko`, `mahoko`, `nana`, `maki`, `mizuho`, `reiko`, `ryoko`, `miyuki`,
  `mayumi`, `ai`, `sizuka`, `tina`; heroine J's `minatu_m_scene_v14.json` was
  replaced by its re-measured form, same 25 routes and sites). Same shape, 340
  new rows - `<heroine>.special.<menu stem>.<number>.1` for the page scenes and
  `...h01.1` .. `h09.1` for the nine H scenes of each menu that has them - 214
  -> 554 rows, `EXPECTED_PAIR_COUNT` 179 -> 519 (each scene is its own
  (`SCENE_*.MES`, `<NAME>_M.MES`) pair), `EXPECTED_CATALOG_COUNT` 214 -> 554
  (`tools/promote_analysis_groups.py`, `CATALOG_REVISION` 36). The 365 album
  rows are the registry's `special` category and the catalog's `gallery`
  `display.categories`, as for J; the id regex is unchanged. The registry moved
  twice in this unit (the new rows, then the `aliases.catalog_event_id`
  promotion attaches) and once more when this entry was written (the directory
  fingerprint covers this README); only the final value is in the committed
  `names_fingerprint` file. The v3/v4/v5 event definitions stay frozen and
  carry the moved fingerprint as a one-line patch; v6 was regenerated
  (`config/event_definitions/v6/README.md`).

## Revision 2026-10-04 (EP-12 H, the room's recollection ladders)

The 13 `?_H.MES` recollection ladders the protagonist's room (`43C.MES`) calls
became analysis groups (`config/event_catalog/analysis_groups/43c_<name>_h_v14.json`,
one `kakyu_event_analysis_group/v14` flow each, group `43c-<name>-h`, route
`<letter>-h`). Same shape, 13 new rows - `<name>.town.43c.h.1`, the `town`
category and place `43c` of a digit-and-`C` floor, number `h` - 554 -> 567 rows,
`EXPECTED_PAIR_COUNT` 519 -> 532 (each ladder is its own (`<NAME>_H.MES`,
`43C.MES`) pair), `EXPECTED_CATALOG_COUNT` 554 -> 567
(`tools/promote_analysis_groups.py`, `CATALOG_REVISION` 37). The rule
(`tools/build_event_names.py`): an `<ENGLISH NAME>_H` callee resolves its heroine
from the table in reverse and takes the number `h`; it is accepted only from
`43C.MES` with a flow route whose id is `<letter>-h` (a route id naming another
heroine stops the tool). The id regex is unchanged. The registry moved twice
in this unit (the new rows, then the `aliases.catalog_event_id` promotion
attaches) and once more when this entry was written (the directory fingerprint
covers this README); only the final value is in the committed
`names_fingerprint` file. The v3/v4/v5 event definitions stay frozen and carry
the moved fingerprint as a one-line patch; v6 was regenerated
(`config/event_definitions/v6/README.md`).

## Revision 2026-10-04 (EP-12 TALK K, heroine K's conversation scripts)

Heroine K's conversation scripts became analysis groups
(`config/event_catalog/analysis_groups/01m_k_talk_v14.json`, group `01m-k-talk`,
eight routes `k-talk-30` .. `k-talk-90`, `k-talk-00` at the `01M.MES` ladder block, and
`27c_ev_k_talk_v14.json`, group `27c-ev-k-talk`, route `k-talk-plain` at `27C_EV.MES`).
Same shape, 9 new rows - `ai.town.station.talk-<band>.1` for the eight rungs (`band` `30`
.. `90`, `00`) and `ai.town.27c_ev.talk-plain.1` for the plain script - 567 -> 576 rows,
`EXPECTED_PAIR_COUNT` 532 -> 541 (each script is its own (`K_TALK<band>.MES`, `01M.MES`)
or (`K_TALK.MES`, `27C_EV.MES`) pair), `EXPECTED_CATALOG_COUNT` 567 -> 576
(`tools/promote_analysis_groups.py`, `CATALOG_REVISION` 38). The rule
(`tools/build_event_names.py`): a `<letter A..L>_TALK` callee with an optional two-digit
band, dispatched under a flow route `<letter>-talk-<band>` (`plain` for the band-less
script), takes the number `talk-<band>`; a route id naming another script or heroine, and a
TALK script without a flow route, stop the tool. The id regex is unchanged (its one
hyphenated number shape holds `talk-30`); the places are the existing ones (`01M` is
`town.station`, `27C_EV` `town.27c_ev`). The follow-on `K_TALKXX` has no row (a member of the
rungs that call it). The registry moved twice in this unit (the new rows, then the
`aliases.catalog_event_id` promotion attaches) and once more when this entry was written (the
directory fingerprint covers this README); only the final value is in the committed
`names_fingerprint` file. The v3/v4/v5 event definitions stay frozen and carry the moved
fingerprint as a one-line patch; v6 was regenerated (`config/event_definitions/v6/README.md`).

## Revision 2026-10-05 (EP-12 TALK, the other eleven heroines, Tina and the characters N..Q)

The conversation scripts of the other eleven heroines, Tina's `M_TALK` and the characters' `N_TALK`..`Q_TALK1` became
analysis groups (28 profiles in all with heroine K's two: `01m_<letter>_talk_v14.json`, group `01m-<letter>-talk`, the eight
rung routes `<letter>-talk-<band>` of each heroine at her `01M.MES` ladder block; `27c_ev_<letter>_talk_v14.json`, group
`27c-ev-<letter>-talk`, the plain script's route `<letter>-talk-plain` at `27C_EV.MES`; `01m_m_talk_v14.json`,
`01m_q_talk_v14.json`, `11m_n_talk_v14.json`, `27c_ev_n_talk_v14.json`, `27c_ev_o_talk_v14.json`,
`27c_ev_p_talk_v14.json`, `27c_ev_q_talk_v14.json`). Same shape, 105 new rows, 576 -> 681 rows, `EXPECTED_PAIR_COUNT`
541 -> 646, `EXPECTED_CATALOG_COUNT` 576 -> 681 (`tools/promote_analysis_groups.py`, `CATALOG_REVISION` 39). The rule
(`tools/build_event_names.py`, `TALK_STEM` and `talk_script_parts` in `tools/payload_values.py`): a heroine's callee
(`A`..`M`: `<letter>_TALK<band>`, the plain `<letter>_TALK`, Tina's `M_TALK`) is numbered `talk-<band>` (`talk-plain` for a
band-less script) under the heroine's own key (`miko.town.station.talk-30.1`, `mizuho.town.27c_ev.talk-plain.1`,
`tina.town.station.talk-plain.1`); a character's callee (`N`..`Q`, no entry in the heroine table:
`<letter>_TALK[<digit>]`) takes the `common` key and the number `talk-<letter><digit>` - `talk-n`, `talk-n1`, `talk-n2`,
`talk-n3`, `talk-o`, `talk-p`, `talk-q`, `talk-q1` (`common.town.27c_ev.talk-n1.1`, `common.town.station.talk-q.1`,
`common.town.11m.talk-n3.1`). The route id spells the same script (`<letter>-talk-<band, digit or plain>`: `n-talk-1`,
`q-talk-plain`); a route id naming another script, a TALK script without a flow route and a follow-on (a member of the
routes that call it) are not rows. The id regex is unchanged (its one hyphenated number shape holds all of them); the
places are the existing ones (`town.station` for `01M.MES`, `town.27c_ev`, `town.11m`). **Cosmetic, not changed:** a row's provisional
title shows the place's file stem when the place has no display name (`Ai at 27c_ev (K_TALK)`, as the three earlier
`27c_ev` rows do and every numbered place script's row); naming the place would move existing rows' titles and so
documents outside the TALK rows, which this unit must not change. The registry moved three times in this unit (the new rows,
the `aliases.catalog_event_id` promotion, and this entry, the directory fingerprint covering this README); only the final
value is in the committed `names_fingerprint` file. The v3/v4/v5 event definitions stay frozen and carry the moved
fingerprint as a one-line patch; v6 was regenerated (`config/event_definitions/v6/README.md`).

## Editing titles

The owner edits `title_ko`/`title_en` in place. `tools/build_event_names.py`
preserves an edited title across regeneration: for a row whose key already
existed in the committed `event_names.json`, the generator keeps the
committed `title_ko`/`title_en` unless they still match the provisional
pattern the generator itself would produce (in which case regeneration is
free to refresh them, e.g. when the place display name changes).
