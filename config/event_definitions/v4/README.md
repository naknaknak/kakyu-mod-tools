# Projected event definitions (`kakyu_event_definition/v4`)

One document per event site of the name registry
`config/contracts/event_names_v1/`, projected from the same evidence v3
used - the analysis-group profiles under `config/event_catalog/
analysis_groups/` (evidence kind `analysis_group`) or a catalog row of
`config/event_catalog/original_events_v1.json` (evidence kind
`catalog_event`) - plus the v2 replays and the shift/done-cell witnesses,
by `tools/project_event_definition_v4.py`, under the contract
`docs/spec/data/event_definition_v4_design.md` and the fixture set
`config/contracts/event_definition_v4/`. v3's own producer, documents,
index and tests stay byte-identical; this is a new module that imports
what it shares. `config/event_definitions/v3/` stays frozen.

## What v4 adds over v3

- **Relative effects.** Every net-changed cell a visit reaches (not only
  the ones a profile declares), decided per cell: a clock cell
  (`state_u16[0]`/`[1]`/`[19]`) becomes one `consume_time` row in minutes;
  a `global_u8` cell observed only as 0 to 1 across a result's group
  becomes `write 1` (`basis: "flag_pattern"`, no witness needed); a cell
  whose entry state varies across the group becomes an absolute `write`
  when every variant ends on the same final value, an `add` when every
  variant moves by the same delta, else `unresolved` (`basis:
  "variants"`); otherwise (every variant enters alike) the shift witness
  decides `write`/`add`/`unresolved` (`basis: "shift_witness"`). A row's
  `cell_class` comes from `tools/state_cells.classify`, recomputed once
  over the whole assembled document so a cell whose only other appearance
  (a `reentry.after` row, for instance) is not 0/1 is a `counter`, never a
  `flag`, even where the row's own evidence only ever saw 0/1. Every
  decided row carries an `evidence.effect_witnesses` entry; a row every
  result shares moves to the body `after` (the most directly evidenced
  basis wins when two results independently agree on the same row by
  different bases).
- **One dialogue flow per result.** `dialogue`/`results[<id>].dialogue` run
  from the caller's lead-in through the callee's scene to the caller's
  continuation, not the callee's scene alone; `{kind: "choice_point"}` and
  `{kind: "scene_end"}` mark a question and the point a played result's
  `after` effects and done state apply; a `text`/`name_insert` entry with
  `location_line: true` is a line that belongs to the map location, not the
  event (below the route's guard offset, or shared with another event site
  of the same caller per the batch driver's shared-line index,
  `analysis/shared_lines_v4.json`).
- **A candidate order hint** (`trigger.order_hint`) ranks the sites of one
  caller entry by the offset of their typed guard, with `chain_confirmed`
  when the guard's `false_target` leads into the next-ranked site's own
  guard. A site with no typed guard (every catalog row) carries no hint.
- **The done flag when the guard holds none.** `find_done_cell` (v3's own
  guard-flag rule) still comes first; failing that, the witness done-cell
  probe's single gate cell is the done flag (`source: "reentry_probe"`).

**A catalog document's flow stays scene-only**: `tools/content_suite/cli/
replay_event_dialogue.gd` replays the callee's own scene, never the
caller's prefix or continuation (only `EVENTJ04` records an
`analysis_route`, and even that replays the caller's state diff only, not
its messages), so a catalog row's flow is unchanged from v3's in that one
respect; every catalog row has no typed guard, so it carries no
`order_hint` and no `location_line` either. No witnesses exist for a
catalog row: its effects are decided by the `variants` rule (the presets'
own state diffs) or left `unresolved`, never by a shift witness. Both gaps
are recorded per document in `unresolved`.

**No original dialogue is stored here**, exactly as in v3: every message is
a `text_ref`, resolved against a local playback package by the producer
into a local, untracked `.resolved.json` twin.

`index.json` (`kakyu_event_definition_index/v2`) extends v1's fields with
`cells_fingerprint` (the fingerprint of `config/contracts/state_cells_v1/`)
and, per document row, `effect_rows_by_type`, `effect_rows_by_basis`,
`effect_rows_declared_false`, `location_lines`, `choice_points`,
`scene_ends`, `order_hint`, `order_hint_chain_confirmed` and
`done_cell_source`.

## Reproduce

From the project root, after exporting the full playback package
(`tools/content_suite/cli/export_playback_package.gd`), the v2 replays
(`tools/content_suite/cli/validate_event_analysis_group.gd --replay`, v2
schema, per profile, written under `analysis/replays_v2/`) and the
witnesses (`tools/plan_event_effect_witnesses.py` then the validator's
`--witness` mode; see `docs/spec/data/event_definition_v4_design.md`'s
"Unit 1a/1b measurement" for the exact commands):

```powershell
py tools\project_event_definitions_batch.py `
  --names config\contracts\event_names_v1 `
  --catalog config\event_catalog\original_events_v1.json `
  --profiles-dir config\event_catalog\analysis_groups `
  --replays-dir analysis\replays_v2 `
  --witnesses-dir analysis\witnesses `
  --package <playback package directory> --arc <mes.arc> `
  --elfimage <ELFIMAGE directory> `
  --contract v4 `
  --out config\event_definitions\v4 --resolved-out analysis\event_definitions_v4_resolved
```

(a catalog row's replay is a `kakyu_event_dialogue_replay/v2` file cached
under `<replays-dir>/catalog_<stem>.json`; the driver replays a missing
one itself with `--elfimage`.) The driver computes the shared-line index
first (`analysis/shared_lines_v4.json`), then projects every registry row
and validates each document against `config/contracts/event_definition_v4/`.
It exits 1 while any site is invalid; the index says which. Since 2026-09-19
the catalog replay loads the startup definition registry (`DEF_MAIN.MES`)
beside the row's members, seeds the audited calendar projection of
`START.MES` into every run's sandbox, loads a nested script the route asks
for from the archive on demand (reported as `extra_members`), and matches
a declared analysis boundary against the event's own call-site row, and
under `--contract v4` the driver projects a registry row through the
profile path whenever a declared analysis group covers the site, keeping
the catalog path for a row no profile declares (v3's dispatch is frozen).
That resolved three of the four sites without a document
(`maki.town.12c.14.1` from its catalog row; `maki.town.10c.06.1` and
`maki.town.station.05.1` from their groups `10c_d06_v6` and `01m_d05_v6`)
and left the other 138 documents byte-identical: 141 documents, 131 from
groups and 10 from catalog rows. `mahoko.town.44m.14.1` (EVENTB14) followed the same day from its own
group `44m_b14_v8` (the driver resolves a row to a declaring profile by
site evidence when the registry lists no group alias for it yet): 142
documents, every registry site, 132 from groups and 10 from catalog rows.

2026-09-21 (EP-10 unit 5a): the ten hand-authored sites of `13C.MES`
(EVENTB01/B02), `12C.MES` (EVENTD01/D02/D03/D08/D14), `11M.MES` (EVENTB15)
and `01M.MES` (EVENTB03/J04) gained analysis groups
(`analysis/_undoc/ep10_unit5a_report.md`,
`analysis/_undoc/ep10_unit5a_round2_report.md`). The names registry was
regenerated (`tools/build_event_names.py`'s `EXPECTED_PAIR_COUNT` premise
moved from 120 to 130 per the owner's 2026-09-19 ruling; the ten sites
gained their group alias, ids unchanged; `config/contracts/event_names_v1/README.md`,
"Revisions"). The playback package also had to be re-exported (`0323`
predated any `12C`/`13C` analysis group and lacked their caller-level
`events/*.json`) to `analysis/playback_package_ep10u5a`; `package_sha256`
changed on all 142 documents, not only the ten new ones. Every one of the
142 registry sites now resolves through the profile path (0 through the
catalog path): the batch driver's site-evidence fallback (the same one
used for `44M.MES`/EVENTB14 before its alias was registered) already
covered every site, so the registry regeneration changed only
`names_fingerprint` and 10 alias rows, not which path any document takes.
142 documents, every registry site, all 142 from groups.

A change to the contract is a new `config/contracts/event_definition_v5/`
beside v3 and v4 and a new directory beside this one, never an in-place
edit; v3's own directory, fingerprint and producer stay frozen.

2026-09-21 (EP-10 unit 5b/c, part 2): every catalog row became EP-10
generated (each now carries `analysis_group`), and the names registry
regenerated (`names_fingerprint`
`4a04c35a1897b968cd7d9357b316be282516acf3eea9a8cadf461fcc8c1cc66a`; see
`config/contracts/event_names_v1/README.md`, "Revisions"). The playback
package also had to be re-exported (`analysis/playback_package_ep10u5bc`;
`package_sha256`
`a3df8fd5748f7f8b26bfee9307fea7e958eb8a71fe41dcd64febca3a7ac51f98`) since
a full build now selects every row instead of only the thirteen
formerly-hand-authored ones. `projected=142 valid=142 invalid=0`, all 142
from groups, unchanged from unit 5a (every site already resolved through
the profile path). `contract_fingerprint`
`26625a93b191b11e0325d68d85a5c7fa028d9e208f5404b289f301e1c16f9f25`.

2026-09-23 (EP-03 step 2): the promotion tool reclassified the three
GROUND.MES dependency stops that land exactly on another catalog event's
own intro dispatch (H01 first, H01 repeat, H02 first) as `chain` endings
into EVENTK01.MES/EVENTK01.MES/K_PIC.MES, promoting those three rows to
`playable_event`/`minimal_playback` (catalog revision 26). The playback
package was re-exported to `analysis/playback_package_ep03chain`
(`package_sha256`
`0610ff2ba04cc9732474312af379447708ad8d8971b7b32cc4175da8daeafe3b`) since
a full build reads the regenerated catalog. `projected=142 valid=142
invalid=0`, all 142 from groups, unchanged from unit 5b/c (the terminal
reclassification and the promoted playback_status/classification do not
change which projection path any site takes); every document is
byte-identical except its `package_binding.package_sha256`.

2026-09-24 (EP-12 catalog part): the names registry regenerated again for
the three promoted `01m-a-date` flow rows (`config/contracts/event_names_v1/README.md`,
"Revisions") - `names_fingerprint` moved from
`4a04c35a1897b968cd7d9357b316be282516acf3eea9a8cadf461fcc8c1cc66a` to
`149ccc398689f2b02598af5919411290fac4c96ea42b0cfd49328571633727bb`. A flow
route has no v4 document of its own (`tools/promote_analysis_groups.py`
promotes it directly), so this is not a re-projection: every existing v4
document's own `names_fingerprint` field moved to the new value in place
(the same 142 documents; nothing else in any document changed), following
the 2026-09-21 precedent above.

2026-09-25 (EP-12 PROMIS checkpoint C): the twelve `01m-<letter>-promis`
groups joined the registry (`EXPECTED_PAIR_COUNT` 142 -> 154 in a first
regeneration, then `EXPECTED_CATALOG_COUNT` 175 -> 187 in a second once
`promote_analysis_groups.py` attached their `catalog_event_id` aliases;
`config/contracts/event_names_v1/README.md`, "Revisions"). None of the
twelve has a v4 document of its own (PROMIS is the ordinary path, but a
brand-new ordinary site's document is produced directly as v6 - see
`config/event_definitions/v6/README.md`; v4 stays frozen for it exactly as
it already does for a flow route), so this is the same field-patch as
2026-09-24, applied twice for the registry's two intermediate fingerprints
(`ea754ca2e255060bcee57b575fafb7e239b0d2dbbd7ac7a6036138e63261e096` ->
`4de039bff08f5f11501adb18a7c0cce1a5f5be1a1057e4ed84dd97e72df10039` ->
`0f6fc4085609ff5786867032670eb5b2b50008b349504962fb0e6ff1cf11a30b`, only
the final value recorded in the committed files): every existing v4
document's own `names_fingerprint` field moved to the final value in place
(the same 142 documents, plus `index.json`'s own copy of the field;
nothing else in any document changed).
