# Projected event definitions (`kakyu_event_definition/v6`)

One document per event site of the name registry
`config/contracts/event_names_v1/` (145 rows): the 142 sites v5 already
projects, re-projected unchanged but for `schema_version`,
`contract_fingerprint` and `package_binding` (a fresh package export, see
below - `names_fingerprint` is unchanged), plus the three `01m-a-date`
promise-date flow rows (`miko.town.station.date-town.1`,
`miko.town.station.date-date5.1`, `miko.town.station.date-hotel.1`), which
have no v4/v5 document of their own and gain a real top-level `flow` block
here for the first time. By `tools/project_event_definition_v6.py` (which
wraps `tools/project_event_definition_v5.py`'s whole pipeline for the 142
non-flow sites, exactly as v5 wraps v4's, and adds its own `flow` construction
for the three flow sites - no copy of the v3/v4/v5 candidate/effect/dialogue
machinery), under the contract `docs/spec/data/event_definition_v6.md` and
the fixture set `config/contracts/event_definition_v6/`. v3's, v4's and v5's
own producers, documents, indexes and tests stay byte-identical; this is a
new module that imports what it shares. `config/event_definitions/v4/` and
`config/event_definitions/v5/` stay frozen.

## What v6 adds over v5

- **A top-level `flow` block**, present only on the three `01m-a-date`
  routes' own documents: the flow's own origin/guard record, its
  `state_context`, and an ordered `hops` list - each hop's own
  `entered_by`, `answers`, `gates`, `map_locations`, `poll_supplies`,
  `dialogue` and `after`, read straight from the `kakyu_event_analysis_group/v14`
  profile (`config/event_catalog/analysis_groups/01m_a_date_v14.json`) and
  its own v2 flow replay - never re-run or re-derived. The top-level
  `dialogue` is exactly the hop markers and each hop's own lines verbatim,
  followed by one `scene_end`; the top-level `after` is the flow's own net
  effect over the whole run, decided by the same rule v4 already uses for a
  result's own effects (rule 2), applied once per hop and once more for the
  whole flow. `results` holds exactly one `result_default`
  (`selected_by.kind: "default"`), since a flow document plays its one
  chain straight through. See `docs/spec/data/event_definition_v6.md` for
  the exact field shapes and `docs/spec/mes/a_date_flow.md` for what each
  flow route measures and what stays unresolved.
- Every other document is projected by the same v5 pipeline
  (`project_event_definition_v5.py`'s own `run_site_v5`, schema/fingerprint
  patched only) v5 itself used, over the same frozen analysis-group
  profiles (`payload_sha256` unchanged) - but **not byte-identical to its
  v5 sibling**, measured: only 3 of the 142 (`schema_version`,
  `contract_fingerprint` and `package_binding.package_sha256` alone differ)
  match the "unchanged" shape the design draft predicted; the other 139
  also carry more resolved `after`/`evidence.effect_witnesses` rows and
  fewer `unresolved` lines, all from `shift_witness`-basis rows a broader
  `analysis/witnesses/` corpus answers that the corpus available when v5
  froze (2026-09-21) did not. Every added row was checked against its
  sibling: none contradicts a row v5 already decided (same cell, same
  result label, different value) - the additional resolution is monotonic,
  not a correction. `docs/spec/data/event_definition_v6.md`'s "How the
  producer decides" section records this as measured, not the
  "re-projected unchanged" the design draft predicted before this unit
  ran. **Which committed state carried that:** the first projection
  (`97382f2`) did (1,997 fewer `unresolved` lines across the 142 v5 sites,
  3,381 -> 1,384). The committed set did not from `f9a2454` until TD-37
  (2026-10-03): those regenerations ran without the witness corpus on disk
  and the producer degraded silently (0 `shift_witness` rows, 0
  `reentry_probe` done cells, the 142 sites back at v5's 3,381 lines). The
  current set carries the rows again - see "2026-10-03 (TD-37)" at the end
  for the counts. A fresh package export was also needed regardless of
  the witness corpus, since the flow route's own hop entries -
  `A_PIC.MES`, `A_DATE1.MES`/`A_DATE3.MES`/`A_DATE5.MES`/`A_DATE7.MES`,
  `A_HOTEL.MES`/`A_HOTEL1.MES`/`A_HOTEL2.MES`, `DENSHA.MES`, `TRAIN.MES`,
  `A_TIME.MES`, `YABAI.MES`, `MACHI.MES` - had to be package members for the
  flow documents' own dialogue to resolve.

**No original dialogue is stored here**, exactly as in v3/v4/v5: every
message (a hop's own included) is a `text_ref`, resolved against a local
playback package by the producer into a local, untracked `.resolved.json`
twin (`analysis/event_definitions_v6_resolved/` in the run recorded below).

`index.json` is `kakyu_event_definition_index/v2`, the same schema v4/v5
use (v6 adds no new index field: a document's own `flow` is visible in the
document, not summarized in the index).

## Reproduce

From the project root, after exporting the full playback package
(`tools/content_suite/cli/export_playback_package.gd`), the v2 replays for
every analysis-group profile (`tools/content_suite/validators/
validate_event_analysis_group.gd --replay`, written under
`analysis/replays_v2/` - the flow profile's own replay through the same CLI,
now wired for a `kakyu_event_analysis_group/v14` profile too, EP-12 / WD unit
2), and the shift/done-cell witnesses for every non-flow profile
(`tools/plan_event_effect_witnesses.py` then the validator's `--witness`
mode, per profile; the corpus is untracked and derived from the archive, the
tracked profiles and the replays):

```powershell
py tools\plan_event_effect_witnesses.py --replays analysis\replays_v2 --out analysis\witness_requests
# then, for each non-v14 profile <stem> with a non-empty request file:
#   Godot --headless --path . --script res://tools/content_suite/validators/validate_event_analysis_group.gd -- `
#     <ELFIMAGE> config/event_catalog/analysis_groups/<stem>.json `
#     --witness analysis/witness_requests/<stem>.json analysis/witnesses/<stem>.json
```

The projection **refuses** (TD-37) when a site's profile has no request file,
has requests but no witness file, or carries a `payload_sha256` that is not
the profile's, and the batch refuses before the first site when
`--witnesses-dir` (or its sibling `witness_requests`) is absent.
`--allow-missing-witnesses` is the explicit opt-out: absent evidence is
projected without it, a `WARNING` is printed per site and counted at the end
(stale evidence is still refused). The batch ends with a
`witnesses: sites_with_results=... requests=... results_used=...
shift_witness_rows=... reentry_probe_documents=...` line:

```powershell
py tools\project_event_definitions_batch.py `
  --names config\contracts\event_names_v1 `
  --catalog config\event_catalog\original_events_v1.json `
  --profiles-dir config\event_catalog\analysis_groups `
  --replays-dir analysis\replays_v2 `
  --witnesses-dir analysis\witnesses `
  --package <playback package directory> --arc <mes.arc> `
  --elfimage <ELFIMAGE directory> `
  --contract v6 --jobs 4 `
  --out config\event_definitions\v6 --resolved-out analysis\event_definitions_v6_resolved
```

`--jobs 4` (TD-41) runs four sites at once and is byte-identical to the serial
run (`--jobs 1`, the default); `tools/README.md` records the arrangement.

The driver computes the shared-line index first (as under v4/v5, over the
142 non-flow sites only - a flow route's own hop dialogue carries no
`location_line`), then projects every registry row through
`project_event_definition_v6.py` (which resolves `--contract-fingerprint`
against this contract's own directory, dispatches the three `01m-a-date`
sites to their own flow construction, and wraps v5's pipeline for every
other site) and validates each document against
`config/contracts/event_definition_v6/`. It exits 1 while any site is
invalid; the index says which.

**2026-09-25 (EP-12 / WD unit 2, first projection):** `projected=145
valid=145 invalid=0`, 145 from groups (0 from a catalog row, every site
resolves through an analysis-group profile as under v4/v5's own
2026-09-21 regeneration). `contract_fingerprint`
`74556e6406beed5fc82a51c14e2d7569e3ec748ec45c7dd595ae32ec7eefd2c9`;
`cells_fingerprint` `de21246988e7cb517ed04eda8a6c92625ba286a89f5f5e7db7441184d086cc73`
(unchanged from v4/v5); `names_fingerprint`
`149ccc398689f2b02598af5919411290fac4c96ea42b0cfd49328571633727bb`
(unchanged from v5's own in-place 2026-09-24 update); `package_sha256`
`fabd31f74c45491cf426daee733f16dde827a7c2d0326880ce5363fe5c74fe71` (a fresh
export against the same archive, `analysis/playback_package_ep12v6/`, 145
events from 241 member entries, 115 bound by 150 analysis groups; the
`analysis/replays_v2/` and `analysis/witnesses/`+`analysis/witness_requests/`
evidence directories this run read were the ones already on disk from the
v4/v5-era measurement work, plus three replays this unit generated itself:
the flow profile's own (`01m_a_date_v14.json`, the mandatory new one) and
two v13 profiles' own (`44c_m10a_v13.json`, `44c_m10b_v13.json`,
`44c_m03_v13.json` - `44c_m10b_v13.json`/`44c_m03_v13.json` support the two
WD-23 visit sites; the `replays_v2` directory on disk carried only their
now-superseded v8 stems). The three flow documents carry `flow` with 23
(`date-town`), 21 (`date-date5`) and 23 (`date-hotel`) hops, matching the
v14 profile's own route lengths; `tina.town.44c.10.2` still carries 5
visits and `tina.town.44c.03.1` still carries 16, unchanged from v5.
**Measured, not the "unchanged" shape predicted:** only 3 of the other 142
documents are byte-identical to their v5 sibling except `schema_version`/
`contract_fingerprint`/`package_binding.package_sha256`; the remaining 139
also carry additional `shift_witness`-basis `after` rows a broader witness
corpus (grown, unit by unit, since v5 froze on 2026-09-21) answered at
`97382f2` - 1,997 fewer `unresolved` lines, net, across the 142 documents
(3,381 -> 1,384), and zero rows that contradict a value v5 already decided
for the same cell (checked directly, corpus-wide): the addition is strictly
monotonic, not a correction. **Those rows were absent from the committed
set between `f9a2454` and TD-37 (2026-10-03) and are present again; see
"2026-10-03 (TD-37)" at the end.** See "What changed from the design draft"
below.

## What changed from the design draft on contact with the current evidence

`docs/spec/data/event_definition_v6.md`'s "How the producer decides" section
(unit 1, written before this unit ran) predicted the 142 non-flow documents
would be "re-projected unchanged but for schema_version and
contract_fingerprint." Running the real pipeline measured otherwise: 139 of
the 142 also gained additional resolved effect rows, because
`tools/plan_event_effect_witnesses.py`'s own request/result corpus under
`analysis/witnesses/`+`analysis/witness_requests/` grew between v5's freeze
(2026-09-21) and this unit (later units answered more shift-witness
requests for their own sites, against the same frozen, unchanged
analysis-group profiles - every reused witness result's own
`payload_sha256` was checked against its profile's current one and matches).
This producer projects from whatever evidence is on disk when it runs,
exactly as v4/v5 always have; it does not pin itself to the exact witness
snapshot v5 happened to read. The measured result is strictly an addition
(1,997 fewer `unresolved` lines net at `97382f2`, zero contradictions with
a value v5 already decided for the same cell, checked corpus-wide) - not a
disagreement with v5's own frozen documents, which stay exactly as they
are. The document above records the true, measured outcome; the design
draft's "unchanged" text was a prediction that this unit's own evidence
happened to outgrow, not a contract rule this unit bent.

A change to the contract is a new `config/contracts/event_definition_v7/`
beside v4/v5/v6 and a new directory beside this one, never an in-place
edit; v3's, v4's and v5's own directories, fingerprints and producers stay
frozen.

## 2026-09-25 (EP-12 B date template unit)

Heroine B's three `01m-b-date` sites (`mahoko.town.station.date-town.1`,
`mahoko.town.station.date-date5.1`, `mahoko.town.station.date-hotel.1`)
joined the registry and the catalog (see
`config/contracts/event_names_v1/README.md` and
`docs/spec/mes/b_date_flow.md`); `tools/project_event_definition_v6.py`'s
own `FLOW_SITES` table was generalized from three hardcoded ids naming one
profile stem/group id to a per-site table so this needed no further code
change. A fresh full regeneration (`projected=148 valid=148 invalid=0`)
against a fresh package export (`analysis/playback_package_b_date/`, 148
events from 251 member entries, 151 analysis groups) recorded
`contract_fingerprint` `74556e6406beed5fc82a51c14e2d7569e3ec748ec45c7dd595ae32ec7eefd2c9`
(unchanged - the v6 contract itself did not move), `cells_fingerprint`
`de21246988e7cb517ed04eda8a6c92625ba286a89f5f5e7db7441184d086cc73`
(unchanged), `names_fingerprint`
`fa845b5b6411d64cbd44b9edb9d376767622f13942caa64f749a8a9fdacca252` (moved,
the registry's own B-date addition), `package_sha256`
`63697260958a460754254918d405fde1b44608fb2af6ae05e24c150c5a830d0b`. The
three new flow documents carry `flow` with 23 (`date-town`), 21
(`date-date5`) and 23 (`date-hotel`) hops, matching the v14 profile's own
route lengths. `config/event_definitions/v4/` and `v5/` carried the moved
`names_fingerprint` into their own tracked documents and indexes (the
`beyond the names_fingerprint carry` exception this task's own instruction
named) without a full re-projection - no other field of any v4/v5 document
changed. `config/event_definitions/v3/` stays untouched and frozen, as
always.

## 2026-09-25 (EP-12 C..L date batch)

The ten `01m-<letter>-date` groups' own 27 declared routes
(`docs/spec/mes/heroine_date_flows.md`) joined the registry and the catalog
(`config/contracts/event_names_v1/README.md`); `project_event_definition_v6.py`'s
own `FLOW_SITES` table was replaced with `_flow_meta`, a derivation from
each site's own registry row plus the declared profiles' own schema
(`docs/spec/tech/content_tools.md`), needing no code change for a new
heroine's flow group. A full regeneration
(`projected=175 valid=175 invalid=0`) against a fresh package export
(`analysis/playback_package_ep12cl/`, untracked, 175 events from 349 member
entries, 219 bound by 161 analysis groups) recorded `contract_fingerprint`
`74556e6406beed5fc82a51c14e2d7569e3ec748ec45c7dd595ae32ec7eefd2c9`
(unchanged - the v6 contract itself did not move), `cells_fingerprint`
`de21246988e7cb517ed04eda8a6c92625ba286a89f5f5e7db7441184d086cc73`
(unchanged), `names_fingerprint`
`ea754ca2e255060bcee57b575fafb7e239b0d2dbbd7ac7a6036138e63261e096` (moved,
the registry's own C..L-date addition, regenerated a second time after
`promote_analysis_groups.py` attached `aliases.catalog_event_id` to the 27
new rows - only this final value is recorded), `package_sha256`
`530d4e006030bcfb86a0b5373df06acdaeeb7d6ee46acf263eaf748eb67b22b3`. The 27
new flow documents carry `flow` with the hop counts
`docs/spec/mes/heroine_date_flows.md`'s own table records (23 for every
`date-town` and `date-hotel`, 21 for every `date-date5`). Two of the WD-23
visit sites' own v13 replay caches (`44c_m10a_v13.json`, `44c_m10b_v13.json`)
and `44c_m03_v13.json` were regenerated (untracked, under
`analysis/replays_v2/`) so this full run could complete - the same
pre-existing gap `analysis/_undoc/ep12_b_date_report.md`'s own "Not
established" section already recorded for this worktree. `config/event_definitions/v4/`
and `v5/` carried the moved `names_fingerprint` into their own tracked
documents and indexes only, without a full re-projection, as before;
`config/event_definitions/v3/` stays untouched and frozen.

## 2026-09-25 (EP-12 PROMIS checkpoint C)

The twelve `01m-<letter>-promis` groups joined the registry and the catalog
(`config/contracts/event_names_v1/README.md`; catalog revision 32, 187
rows). Unlike a flow route, PROMIS is the *ordinary* path - each site's own
v6 document is `run_site_v6`'s plain fall-through into
`project_event_definition_v5.py`'s whole v4/v5 pipeline, the same as every
other ordinary site - but a brand-new ordinary site has no v4/v5 document to
carry forward, so it exists only here (`config/event_definitions/v4/` and
`v5/` stay frozen for these twelve exactly as they already do for a flow
route). Producing that document needs the site's own callee
(`?_PROMIS.MES`) and its `?_OUTRO.MES` member exported into a package the
projector can read - which needs a catalog row, which needs the v6
document: a genuine order problem an ordinary site's own tooling had never
hit before (a flow route's row and document are both built directly from
its profile, never the package). Resolved by a scratch, explicitly opt-in
export option, `--include-unbound-groups`
(`tools/content_suite/playback_package_export.gd`/`export_playback_package.gd`):
`analysis_group_members`'s own catalog-reference restriction already lifts
when its `events` argument is empty (the unrestricted directory scan its
own comment already named); the option threads that same empty list through
for group membership alone while `catalog_members` still reflects the real
selected events, so a plain export is unaffected (`tests/test_playback_package.gd`,
72/72 unchanged). A one-time bootstrap package built with it exported the
twelve missing members; `project_event_definition_v6.py --site <id>
--contract v6` (ordinary path) produced all twelve documents against it;
`tools/promote_analysis_groups.py` (pointed at this directory by its new
`--definitions-dir` default, alias `--v4-dir`, since it reads only v4-shape
fields and v6 is a superset - proved byte-identical for the 175
pre-checkpoint rows before this) promoted the real catalog rows from them.
A full regeneration (`projected=187 valid=187 invalid=0`) then ran against
the *standard* export (no bootstrap flag needed once the catalog referenced
the twelve groups: 187 events from 371 member entries, 230 bound by all 173
analysis groups now including them), recording `contract_fingerprint`
`74556e6406beed5fc82a51c14e2d7569e3ec748ec45c7dd595ae32ec7eefd2c9`
(unchanged), `cells_fingerprint`
`de21246988e7cb517ed04eda8a6c92625ba286a89f5f5e7db7441184d086cc73`
(unchanged), `names_fingerprint`
`0f6fc4085609ff5786867032670eb5b2b50008b349504962fb0e6ff1cf11a30b` (moved
twice - once for the registry's own twelve new rows, once more after
`promote_analysis_groups.py` attached `aliases.catalog_event_id` to them -
only the final value recorded), `package_sha256`
`f3bfada638cfff6820c0ea4a6b9c98e7ee047c1deb8349da598a0c7818daf6d8`. Every
one of the 175 pre-existing documents differs from its prior committed
version only in `names_fingerprint` and `package_binding.package_sha256`
(confirmed on a sample before the full run: a two-field diff, nothing else
moved). `config/event_definitions/v4/` and `v5/` carried the moved
`names_fingerprint` into their own tracked documents and indexes only,
without a full re-projection, as before; `config/event_definitions/v3/`
stays untouched and frozen.

## 2026-09-26 (EP-12 leftovers unit)

The route-toolchain fix that let D's own `?_HOTEL.MES` site selector and A's
own promise options 8-10 be measured (Core 0.368.0,
`docs/spec/tech/content_tools.md`) closed two of `docs/spec/mes/heroine_date_flows.md`'s
own left-out routes: `01m-d-date` gains its hotel route and `01m-l-date`
gains its date5 route. `01m-a-promis` gains its remaining three routes
(results 8-10, the archive's own confirmed latch methodology). Two brand new
sites join the registry and this directory (`maki.town.station.date-hotel.1`,
`sizuka.town.station.date-date5.1`, both `kakyu_event_analysis_group/v14`
flow sites, the same shape `date-town`/`date-date5`/`date-hotel` already
has); five existing sites' own `flow` block gains its now-three-route
sibling list (`maki.town.station.date-town.1`,
`maki.town.station.date-date5.1`, `sizuka.town.station.date-town.1`,
`sizuka.town.station.date-hotel.1`, plus `miko.town.station.promis.1`'s own
genuinely new `contract_fingerprint`, `presets` and `results` for the three
newly-succeeding options - the one document whose measured content actually
changed, not merely a sibling list or a fingerprint carry). Sequence:
registry regenerated first (189 rows, `names_fingerprint`
`41707b69365a24780c02eb7c980bf6078910dd3f42ac97bb9416243a3f3735cf`) -> a
bootstrap package exported with `--include-unbound-groups` (since
`miko.town.station.promis.1`'s own profile changed hash, its own catalog
row no longer bound its new members either, the same order problem PROMIS
checkpoint C's own item (1) hit) -> that one stale v6 document
(`miko.town.station.promis.1.json`, blocked on the old `profile_sha256`)
re-projected against the bootstrap package -> `tools/promote_analysis_groups.py`
promoted the two new catalog rows (`CATALOG_REVISION` 33, 189 events) ->
the *standard* package re-exported (189 events, 230 analysis-group members,
no bootstrap flag needed) -> all 189 v6 documents plus `index.json`
regenerated against it, twice (the registry's own second regeneration, after
promotion attached `aliases.catalog_event_id` to the two new rows, moved
`names_fingerprint` again to
`4f745428ebc83ceb68b475259aad91cf1616748e4060884977690f46dfa761db` - the v6
batch had to be re-run once more to pick that final value up, the same
"moves twice" shape the PROMIS checkpoint C entry above already names) ->
`names_fingerprint` carried into `config/event_definitions/v4/` and `v5/`
as a minimal, byte-level field patch (143 files each: 142 documents plus
`index.json`; verified as a single-line diff per file, nothing else moved -
the naive approach of reparsing and rewriting each document as JSON was
tried first and rejected: it reformatted every file's own whitespace,
which is not a field patch). `contract_fingerprint`
(`74556e6406beed5fc82a51c14e2d7569e3ec748ec45c7dd595ae32ec7eefd2c9`) and
`cells_fingerprint`
(`de21246988e7cb517ed04eda8a6c92625ba286a89f5f5e7db7441184d086cc73`) are
unchanged - confirming this unit changed no shared schema-defining content,
only site-specific data. One incidental, pre-existing inconsistency this
regeneration also fixed: `miko.town.station.promis.1.json`'s own committed
`contract_fingerprint` field held the literal placeholder string `"v6"`
instead of a real hash (every one of the other 186 pre-existing documents
already held the correct hash); the full regeneration wrote the correct
value as a side effect. `config/event_definitions/v3/` stays untouched and
frozen; `config/event_definitions/v4/` and `v5/` stay frozen beyond the
field patch above.

**Verification 2026-10-03 (EP-12 leftovers resume):** the whole set was
regenerated from the verified branch. Findings, all measured: the package
(`playback_package_ep12_leftovers`, 189 events from 371 members, 230 bound by
173 groups) hashes to `13bd0a22cd32336907975b4f5760376f9c71c5bff2f0ff49a3dfc0611e24d477`,
the value the index records - the hash folds in `content_core_version`
(`0.368.0` here), so a regeneration exports after its version bump.
`names_fingerprint` `4f745428...` quoted above never matched the committed
registry files (README + `event_names.json`); the correct value is
`36b9c8468367589ce8debb4e5eac35c8b31eddf868f918cd0772397305c16eb8`, and it
is the only field that moved in the 190 v6 files (and in the 286 v4/v5
files, carried as a one-line byte patch). The catalog, the registry content
and every other v6 field are unchanged. Witness-derived rows were 0 in this
projection (and in every committed projection since `f9a2454`: no witness
corpus was present at projection time, `--witnesses-dir analysis\witnesses_absent`),
so the "1,997 fewer `unresolved` lines" above, which came from a corpus this
regeneration did not read, were not true of the committed documents until
TD-37 restored them (end of this file; `todo/code_health.md` TD-37).

## 2026-10-03 (EP-12 date profiles at routine-40 contract v5)

The nine `01m_<x>_date_v14` profiles B, C, E, F, G, H, I, J and K were
regenerated at routine-40 choice-contract schema v5 (their committed files
carried v4 contracts without `catalog_form`/`hidden_ids`/`hidden_gates`;
`docs/spec/tech/content_tools.md`, revision 2026-10-03). A's hand-authored
profile stays v4 by design; D and L were already v5. Only the profile
`payload_sha256` is visible to this producer - it reads no contract field of the
choice contracts - so the whole v6 effect is hash-bound: the 26 flow documents
(`<heroine>.town.station.date-town|date5|hotel.1` of those nine heroines, J
without a hotel) move `evidence.groups[0].profile_sha256` and
`flow.evidence.profile_sha256`, and every one of the 189 documents plus
`index.json` moves `package_binding.package_sha256`. Nothing else in any
document or in the index changed (`contract_fingerprint`, `names_fingerprint`
`36b9c846...` and `cells_fingerprint` are unchanged; measured as a JSON diff
against the pre-unit commit `06c9d72`: 163 documents differ in the package hash alone,
26 in the two profile hashes plus the package hash, the index in the package
hash alone). The package was re-exported unchanged in membership (189 events
from 371 member entries, 230 bound by 173 groups, Core 0.368.0, no Core bump)
and hashes to `a4880971a5978b7129ab241c009870d6a75eb8cbc47626b67def1281c2e2a914`
(was `13bd0a22...`): its manifest moved only the nine analysis-group
`payload_sha256` values, the 26 preset `notes` that embed the hash prefix and
`package_sha256`. Projection: `projected=189 valid=189 invalid=0`, witness
corpus absent as before (`--witnesses-dir analysis\witnesses_absent`, TD-37).
Catalog revision 34 (189 rows; 26 rows rebound), registry unchanged.

## 2026-10-03 (TD-37: the witness-derived rows restored)

The committed v6 set had carried **0** `shift_witness` rows and **0**
`reentry_probe` done cells since `f9a2454`: the projection reads its effect
witnesses from `--witnesses-dir`, the corpus is untracked (`analysis/`), and a
profile with no corpus file silently produced no rows. The producer now fails
closed (`--allow-missing-witnesses` is the opt-out; "Reproduce" above) and the
set was re-projected with the corpus.

Corpus (regenerated from the archive, the tracked profiles and
`analysis/replays_v2`, never tracked): `plan_event_effect_witnesses.py` wrote
161 request files (every non-v14 profile; the 12 flow replays are skipped) with
4,801 shift and 363 done-probe requests, and `validate_event_analysis_group.gd
--witness` answered all 5,164 (4,409 `set`, 111 `add`, 192 `path_changes`, 89
`other`, 363 done probes; 0 errors; every result's `payload_sha256` equals its
profile's) in 1,258 s at 4 in parallel. Projection against the committed
package (`a4880971...`): `projected=189 valid=189 invalid=0`, and the batch's
witness line `sites_with_results=154 sites_without_witnesses=0 requests=5434
results_used=5434 shift_witness_rows=1718 reentry_probe_documents=46`
(requests count per site; a profile shared by two sites counts twice).

Before -> after, whole set (`index.json`, derived fields only): `effect_rows_by_basis`
variants 179 -> 129, flag_pattern 2,383 -> 2,383, clock 236 -> 236,
**shift_witness 0 -> 1,718**; `done_cell_source` guard_flag 86 -> 86, None 103
-> 57, **reentry_probe 0 -> 46**; effect `after` rows in the 154 ordinary
documents 1,771 -> 3,520 (write 1,611 -> 3,288, add 97 -> 169, consume_time 63
-> 63); `unresolved` lines 5,405 -> 1,580 (154 ordinary documents; all 189: 7,683 -> 3,858, the 35 flow documents unchanged at 2,278) (4,086 "no matching shift witness"
and 46 "no done flag identified" lines answered; 261 "witness outcome ...
not set/add" and 46 "done_cell = the witness done-cell probe's single
gate" lines added). The 142 sites v5 also covers: v5 3,381, the set at
`97382f2` 1,384, the set committed from `f9a2454` to this unit 3,381, now
1,357 (2,024 fewer than v5). The variants count fell by 50 because a row
every leaf shares moved to the body with its basis upgraded
(`promote_shared_rows_with_evidence` prefers `shift_witness`).

Monotonic, proved per document against the committed set (JSON compare, the
effective rows of every leaf result = body + ancestors + own): the 35 flow
documents are byte-identical; in the 154 ordinary documents no row both sides
decide changed value, no decided row was removed (hoisting judged on the
effective set), no field outside `after`, `evidence.effect_witnesses`,
`unresolved` and the added `reentry_probe` done condition changed, no
`cell_class` moved, and the index changed only in its derived fields
(`effect_rows_by_basis`, `effect_rows_by_type`, `effect_rows_declared_false`,
`done_cell_source`). Reproduction against `97382f2` (145 documents, no profile
hash moved since): all 1,251 of its `shift_witness` rows and all 34 of its
`reentry_probe` done cells reappear with the same value; none missing,
none differing. `promote_analysis_groups.py --check` and the registry
regeneration are unchanged (catalog revision 34, `names_fingerprint`
`36b9c846...`). `tests/test_event_definitions_tracked.py` now asserts the
set carries at least the 1,251 `shift_witness` rows and 34 `reentry_probe`
cells `97382f2` had (and that the index agrees); it fails on the previous
committed set.

## 2026-10-04 (EP-12 SCENE, heroine J's album)

Heroine J's 25 album scenes were declared as the `minatu-m-scene` flow group
(`docs/spec/mes/gallery_families.md`, "Declared: heroine J's album") and join
the set as 25 flow documents, `minatu.special.minatu_m.01.1` .. `16.1` and
`.h01.1` .. `h09.1`: two hops each (the menu, no lines; the scene to its own
`script_return`), a `callee_return` terminal, no dependencies, the baseline
preset only (`docs/spec/data/event_definition_v6.md`, "Album-scene flows"; the
producer's gallery branch is `is_gallery_registry_row` (`tools/payload_values.py`) in
`tools/project_event_definition_v6.py`). Sequence: profile built and audited
(Python audit ok; the flow validator 283 checks, no failure) and its v2 replay
written (`validate_event_analysis_group.gd --replay`, 25 routes) -> registry
regenerated (214 rows) -> `promote_analysis_groups.py` (catalog revision 35,
189 -> 214 rows, the 189 existing rows byte-identical) -> registry regenerated
again (`aliases.catalog_event_id` on the new rows) -> package exported
(214 events from 397 member entries, 255 bound by 174 groups, Core 0.368.0,
no Core change this unit) hashing to
`e2ba7c4955d091683cec77f1469dc547cbc1f6b9ecad783bdf1978333bc97a99` -> the whole
set projected: `projected=214 valid=214 invalid=0`, witness line unchanged
(`sites_with_results=154 sites_without_witnesses=0 requests=5434
results_used=5434 shift_witness_rows=1718 reentry_probe_documents=46`: the new
flow profile needs no witnesses, TD-37's guard skips v14). `contract_fingerprint`
(`74556e64...`) and `cells_fingerprint` (`de212469...`) are unchanged;
`names_fingerprint` moved (the final value is in the registry's
`names_fingerprint` file; this README is not part of that directory). Measured
as a JSON diff against the pre-unit commit: each of the 189 existing documents
differs in `names_fingerprint` and `package_binding.package_sha256` alone, the
index in `names_fingerprint`, `package_sha256` and `summary` (and its new rows).
`config/event_definitions/v4/` and `v5/` carried the moved `names_fingerprint` as
a one-line byte patch (143 files each, verified as one changed line per file).
The group's `unresolved` lines name what the v14 shape cannot hold (the other
options of `SCENE_J08`/`SCENE_J13`, the hotel path of `SCENE_J14`).

## 2026-10-04 (EP-12 SCENE, the other twelve album menus)

The twelve remaining `<NAME>_M.MES` menus were declared as analysis groups
(`config/event_catalog/analysis_groups/<name>_m_scene_v14.json`) and heroine J's
`minatu-m-scene` was re-measured with its variants and replaced
(`docs/spec/mes/gallery_families.md`, "Declared: all albums"). The set grows to
554 documents: the 340 new album scenes, each a two-hop flow with a
`callee_return` terminal, no dependencies and the baseline preset only
(`docs/spec/data/event_definition_v6.md`, "Album-scene flows"); a scene's other
question options and a recap scene's second path are variants of the route and
presets of its catalog row, not part of the document. Sequence: the 13 profiles
built, audited (Python audit ok; the flow validators 4,669 checks, no failure)
and installed, their v2 replays written (`validate_event_analysis_group.gd
--replay`, 13 files under `analysis/replays_v2/`, 456 route-variant records) ->
registry regenerated (554 rows) -> `promote_analysis_groups.py` (catalog revision
36, 214 -> 554 rows, 33 `duplicate_route`) -> registry regenerated again
(`aliases.catalog_event_id`) and once more after its README entry (the directory
fingerprint covers the README) -> package exported (554 events from 749 member
entries, 154 catalog-verified, 595 bound by 186 analysis groups, Core 0.369.0, no
Core change this unit) hashing to
`3ef6acc12182e8ce6acf7316ecb58aa051cf4a8a7f6c4655d0190c2993cf7674` -> the whole
set projected at `--jobs 4`: `projected=554 valid=554 invalid=0`, witness line
unchanged (`sites_with_results=154 sites_without_witnesses=0 requests=5434
results_used=5434 shift_witness_rows=1718 reentry_probe_documents=46`: the new
flow profiles need no witnesses, TD-37's guard skips v14).
`contract_fingerprint` (`74556e64...`) and `cells_fingerprint` (`de212469...`)
are unchanged; `names_fingerprint` moved (the final value is in the registry's
`names_fingerprint` file). Measured as a JSON diff against the pre-unit commit:
the 189 existing non-album documents differ in `names_fingerprint` and
`package_binding.package_sha256` alone; heroine J's 25 documents also carry the
new profile hash (`evidence.groups[0].profile_sha256`,
`flow.evidence.profile_sha256`) and, for `SCENE_J08`, `J13` and `J14`, lose the
`unresolved` lines that named the other options and the hotel path (now declared
as variants); the index differs in `names_fingerprint`, `package_sha256`,
`summary` and its new rows. `config/event_definitions/v4/` and `v5/` carried the
moved `names_fingerprint` as a one-line byte patch (143 files each, verified as
one changed line per file).

## 2026-10-04 (EP-12 H, the room's recollection ladders)

The 13 `?_H.MES` recollection ladders the protagonist's room calls were declared as
analysis groups (`config/event_catalog/analysis_groups/43c_<name>_h_v14.json`,
`docs/spec/mes/43c_caller_group.md`, "Declared: the 13 recollection ladders"). The set
grows to 567 documents: the 13 new ones, `<name>.town.43c.h.1`, each a two-hop flow (the
room to the ladder's call, with no lines; then the ladder, up to 911 lines) with a
`callee_return` terminal and the baseline preset only - the full recollection; the
`no-recollection` variant is a variant of the route and a preset of its catalog row, not
part of the document (`docs/spec/data/event_definition_v6.md`, "Room recollection flows").
Sequence: the 13 profiles built, audited (Python audit ok; the flow validators 25 checks
each, 26 for `NANA_H`, no failure) and installed, their v2 replays written
(`validate_event_analysis_group.gd --replay`, 13 files under `analysis/replays_v2/`, 26
route-variant records) -> registry regenerated (567 rows) -> `promote_analysis_groups.py`
(catalog revision 37, 554 -> 567 rows, the 554 existing rows byte-identical) -> registry
regenerated again (`aliases.catalog_event_id`) and once more after its README entry ->
package exported (567 events from 762 member entries, 167 catalog-verified, 595 bound by 199
analysis groups, **Core 0.370.0**, the hop `segment_budget` change) hashing to
`f45a5cd53efc4060764fb4d19b0a6071a465b8d1f0c353477d902af42226cd4b` -> the whole set projected
at `--jobs 4`: `projected=567 valid=567 invalid=0`, witness line unchanged
(`sites_with_results=154 sites_without_witnesses=0 requests=5434 results_used=5434
shift_witness_rows=1718 reentry_probe_documents=46`: the new flow profiles need no
witnesses, TD-37's guard skips v14). `contract_fingerprint` (`74556e64...`) and
`cells_fingerprint` (`de212469...`) are unchanged; `names_fingerprint` moved (the final value
is in the registry's `names_fingerprint` file). Measured as a JSON diff against the pre-unit
commit: the 519 existing non-date documents differ in `names_fingerprint` and
`package_binding.package_sha256` alone; the 35 date flow documents (A..L, three routes each, J
two) also differ in their first `unresolved` line - **TD-43 closed**: the line now spells the
document's own guard conjuncts instead of heroine A's town-date cells
(`flow_done_flag_line`); the index differs in `names_fingerprint`, `package_sha256`,
`summary` and its 13 new rows. `config/event_definitions/v4/` and `v5/` carried the moved
`names_fingerprint` as a one-line byte patch (143 files each, verified as one changed line per
file).

## 2026-10-04 (EP-12 TALK K, heroine K's conversation scripts)

Heroine K's nine conversation scripts were declared as analysis groups
(`config/event_catalog/analysis_groups/01m_k_talk_v14.json` - the eight rung scripts at the `01M.MES` ladder
block - and `27c_ev_k_talk_v14.json` - the plain `K_TALK` at `27C_EV.MES`;
`docs/spec/mes/talk_family.md`, "Declared: heroine K"). The set grows to 576 documents: the 9 new ones,
`ai.town.station.talk-<band>.1` (three-hop flows, the `natural_handoff` terminal at the town handoff) and
`ai.town.27c_ev.talk-plain.1` (a two-hop flow, `callee_return`), the baseline preset only, no `unresolved` change for
the other 567 (`docs/spec/data/event_definition_v6.md`, "TALK flows"). **The producer changed for them** (a tools change,
Core unchanged): the entries that resolve a flow's replayed lines include the scripts a hop runs inline (`K_PIC`,
`K_INTRO`, `K_OUTRO`; the first projection stopped with a `KeyError` on the eight rungs), and a TALK row's
`dependencies` are the entries its own route runs, not every rung script of the group (`is_talk_registry_row`,
`flow_involved_entries`, `flow_dependencies`, `talk_route_entries`). Sequence: the two profiles built, audited (Python audit
ok; the flow validators 164 and 20 checks, no failure) and installed, their v2 replays written
(`validate_event_analysis_group.gd --replay`, 8 routes with 14 variants and 1 route with 1) -> registry regenerated (576 rows)
-> `promote_analysis_groups.py` (catalog revision 38, 567 -> 576 rows, the 567 existing rows byte-identical) -> registry
regenerated again (`aliases.catalog_event_id`) and once more after its README entry -> package exported (576 events from 772
member entries, 168 catalog-verified, 604 bound by 201 analysis groups, **Core 0.371.0**, the scratch-split contract shape)
hashing to `7e2b40de9dcba6c135d73d18a4845510f0466f3c4997ea4c3f6cd2989b90585e` -> the whole set projected at `--jobs 4`:
`projected=576 valid=576 invalid=0`, witness line unchanged (`sites_with_results=154 sites_without_witnesses=0 requests=5434
results_used=5434 shift_witness_rows=1718 reentry_probe_documents=46`: the new flow profiles need no witnesses, TD-37's guard
skips v14). `contract_fingerprint` (`74556e64...`) and `cells_fingerprint` (`de212469...`) are unchanged; `names_fingerprint`
moved (the final value is in the registry's `names_fingerprint` file). Measured as a JSON diff against the pre-unit commit:
**all 567 existing documents differ in `names_fingerprint` and `package_binding.package_sha256` alone** (the projector change
moves no earlier document); the index differs in `names_fingerprint`, `package_sha256`, `summary` and its 9 new rows.
`config/event_definitions/v4/` and `v5/` carried the moved `names_fingerprint` as a one-line byte patch (143 files each,
verified as one changed line per file).

## 2026-10-05 (EP-12 TALK rest, the other eleven heroines, Tina and the characters N..Q)

The conversation scripts of the other eleven heroines (88 rung scripts at their `01M.MES` ladder blocks and 8 plain
scripts at `27C_EV.MES`), Tina's `M_TALK` and the characters' `N_TALK`, `N_TALK1`, `N_TALK2`, `N_TALK3`, `O_TALK`, `P_TALK`,
`Q_TALK` and `Q_TALK1` were declared as 26 more analysis groups (`config/event_catalog/analysis_groups/01m_<letter>_talk_v14.json`
and `27c_ev_<letter>_talk_v14.json` per heroine, `01m_m_talk_v14.json`, `01m_q_talk_v14.json`, `11m_n_talk_v14.json`,
`27c_ev_n_talk_v14.json`, `27c_ev_o_talk_v14.json`, `27c_ev_p_talk_v14.json`, `27c_ev_q_talk_v14.json`;
`docs/spec/mes/talk_family.md`, "Declared: all heroines, Tina and the characters N..Q"), and heroine K's `01m_k_talk_v14.json` was
regenerated (her eight contracts moved from `v5` to `v6`, Core 0.372.0). The set grows to 681 documents: the 105 new ones
(`<name>.town.station.talk-<band>.1`, three-hop flows with the `natural_handoff` terminal; `<name>.town.27c_ev.talk-plain.1`,
`common.town.<place>.talk-<letter><digit>.1` and the two other plain-numbered rows, two-hop flows with `callee_return`, except
`tina.town.station.talk-plain.1` and `common.town.station.talk-q.1`, three hops), the baseline preset only, no `unresolved`
change for the other 576 (`docs/spec/data/event_definition_v6.md`, "TALK flows"). No producer change in this unit (the K unit's two
TALK rules carry every document). Sequence: the 28 profiles built from the measured specs, audited (Python audit ok for all 28; the flow
validators 163, 131, 163, 163, 163, 195, 195, 180, 163, 179, 164 and 227 checks for the twelve ladder groups and 20..31 for the
others, no failure) and installed, their v2 replays written (`validate_event_analysis_group.gd --replay`, 28 files under
`analysis/replays_v2/`) -> registry regenerated (681 rows) -> `promote_analysis_groups.py` (catalog revision 39, 576 -> 681 rows, the 576
existing rows byte-identical except heroine K's eight rung rows, which carry the group profile hash and its preset notes) -> registry again
(`aliases.catalog_event_id`) and once more after its README entry -> package exported (681 events from 869 member entries, 188
catalog-verified, 681 bound by 227 analysis groups, **Core 0.372.0**, the contract schema v6) hashing to
`7af75165075c9d239bed221160a1ec0de6d4770c7c5f30a07c11f8dabe546238` -> the whole set projected at `--jobs 4`:
`projected=681 valid=681 invalid=0`, witness line unchanged (`sites_with_results=154 sites_without_witnesses=0 requests=5434
results_used=5434 shift_witness_rows=1718 reentry_probe_documents=46`: the new flow profiles need no witnesses, TD-37's guard skips
v14). `contract_fingerprint` (`74556e64...`) and `cells_fingerprint` (`de212469...`) are unchanged; `names_fingerprint` moved
(`94223afe...`; the final value is in the registry's `names_fingerprint` file). Measured as a JSON diff against the pre-unit commit:
**the 568 existing documents that are not heroine K's rungs (567 documents and K's plain script) differ in `names_fingerprint` and
`package_binding.package_sha256` alone; K's eight rung documents also differ in `evidence.groups[0].profile_sha256` and
`flow.evidence.profile_sha256` (the regenerated group profile's hash) and in nothing else**; the index differs in `names_fingerprint`,
`package_sha256`, `summary` and its 105 new rows. `config/event_definitions/v4/` and `v5/` carried the moved `names_fingerprint` as a
one-line byte patch (143 files each, verified as one changed line per file).

## 2026-10-05 (EP-12 TALK follow-ups, `N_TALK1`'s third hop)

The 13 `27C_EV.MES` anchors whose conversation scripts had inherited heroine K's two-hop result were re-measured with the measurer's
`resume_hop: "auto"` (scratch; `docs/spec/mes/talk_family.md`, "Hop 3 of the 14 `27C_EV.MES` anchors, measured"). Eleven stop in the day loop
and `N_TALK` stops at a question of the next block's script (no change to those two-hop documents); **`N_TALK1`'s caller reaches the
`FLOOR5.MES` handoff at `27C_EV.MES:83150`**, so `common.town.27c_ev.talk-n1.1` is now a three-hop flow (6 more messages, terminal
`script_handoff_boundary` to `FLOOR5.MES`, route outcome `map_return`; it had been two hops and `place_menu`). One group profile moved
(`config/event_catalog/analysis_groups/27c_ev_n_talk_v14.json`, `N_TALK` and `N_TALK1` re-measured together); catalog revision 40 (the same 681
rows; two changed). Sequence: the profile rebuilt from the re-measured specs, audited (Python audit ok, flow validator 33 checks, no failure) and
installed, its v2 replay rewritten -> registry regenerated (unchanged, `names_fingerprint` `94223afe...` as before) ->
`promote_analysis_groups.py` (catalog revision 40; `--check` equal byte for byte) -> package exported (681 events from 869 member entries, 188
catalog-verified, 681 bound by 227 analysis groups, Core 0.372.0; only `manifest.json` differs from the previous package) hashing to
`4d0ca40d07ed958335ab3a3ab28025aedcef54bb23643b3372cec8211e512690` -> the whole set projected at `--jobs 4`: `projected=681 valid=681 invalid=0`,
witness line unchanged -> route classification refreshed. Measured as a JSON diff against `HEAD`: **679 documents differ in
`package_binding.package_sha256` alone; `common.town.27c_ev.talk-n.1.json` also in the two profile hashes and one `unresolved` line (its measured hop-3
stop is named); `common.town.27c_ev.talk-n1.1.json` also in `dialogue`, `evidence.groups`, `flow.hops`, `flow.evidence.profile_sha256`,
`terminals.flow` and `unresolved`**; the index differs in `package_sha256` and the one document's `body_messages`. `names_fingerprint`, the
contract and cells fingerprints and `config/event_definitions/v4/` and `v5/` are unchanged (no carry). Route classification moved
`catalog_sha256` and the `27c-ev-n-talk` payload hash of `N_PIC.MES` alone.

## 2026-10-06 (WD-21 U1 C4, the rebind to the Core 0.373.0 package)

WD-21 U1 moved the package hash, so the set was regenerated **in place** and bound to the new package (tool decision D10 of the unit: a
v6 set bound to a hash no longer produced is a broken contract for the consumer, and the U3/U4 follow-ups have no date). The package is the
unit's binding export (`analysis/playback_package_wd21_u1`, Core 0.373.0, 681 events from 869 member entries; manifest `package_sha256`
`b638bd7d135b408d748dd45a2bbb74486e2b7cb71a4eb8e920de2e092f6589ad`, was `4d0ca40d...`). What moved it is in the package, not in any
definition: against the previous package (`4d0ca40d...`, Core 0.372.0) **only `manifest.json` differs** (1,739 files in each, the other 1,738
byte-identical) - `source.catalog_id` and `catalog_revision` now carry the catalog the package was built from (`kakyu-original-events`, 40;
they had been empty and 0), the manifest gains the `media_inventory` (`kakyu_media_inventory/v1`) and `script_references`
(`kakyu_script_references/v1`) blocks, and `content_core_version` is 0.373.0 (`docs/spec/data/workspace_playback_export.md`, "Media inventory
and script references"). No producer, profile, catalog or registry change in this checkpoint: the same 681 rows, the same group profiles.

The whole set was projected at `--jobs 4` with the argument list of the 2026-10-05 run and `--package` changed to the new export
(`projected=681 valid=681 invalid=0`, the witness line unchanged: `sites_with_results=154 sites_without_witnesses=0 requests=5434
results_used=5434 shift_witness_rows=1718 reentry_probe_documents=46`); 66 min 57 s. Measured as a path-level JSON diff against `HEAD`
(and as a line diff, one line per file): **all 681 documents differ in `package_binding.package_sha256` alone, and `index.json` in its
`package_sha256` alone** (682 files, 682 changed lines in all; `summary`, the 681 rows, `names_fingerprint` `94223afe...`,
`contract_fingerprint` `74556e64...` and `cells_fingerprint` `de212469...` unchanged). `config/event_definitions/v4/` and `v5/` stay frozen,
bound to their own earlier packages (`0610ff2b...` and `b4f5f293...`), and are untouched. The new fingerprint of the set's binding is the package hash above; the resolved twins stay under
`analysis/event_definitions_v6_resolved` (untracked, they carry dialogue).

## 2026-10-08 (WD-21 U2 C6, v7 is the live set; this set is frozen)

`config/event_definitions/v7/` (`kakyu_event_definition/v7`, v6 plus `presentation.resources`,
`docs/spec/data/event_definition_v7.md`) is now the **live** definition set: the promoter and the
catalog (revision 41) read it, and it is bound to the package of the same revision,
`874f53cab4f433accddf54e69db891ae9584a06cb3cc37e22bb2be46c8a462ef`. **This set is frozen, and stays
bound to `b638bd7d135b408d748dd45a2bbb74486e2b7cb71a4eb8e920de2e092f6589ad`**, the package WD-21 U1 produced (Core 0.373.0, catalog revision 40; the "WD-21 U1 C4"
section above): it is not regenerated or rebound any more, the way `config/event_definitions/v4/`
(`0610ff2b...`) and `v5/` (`b4f5f293...`) stay at the last package they were produced against. Its 681
documents were not touched by the v7 work; the v7 documents equal them in every field but
`presentation`, `schema_version`, `contract_fingerprint` and the bound package hash (a standing check,
`tests/test_event_definitions_tracked.py`).

U1's rule above - a set bound to a hash no longer produced is a broken contract for its consumer -
governs the **live** set, and it is why v7 was rebound to the revision-41 package
(`config/event_definitions/v7/README.md`, same date); a superseded set is a record, not a contract
anyone is promised. A consumer still on v6 must keep the package it was bound to (`b638bd7d`, the U1
export) or adopt v7; no tracked tool of this repository reads this set any more (the batch projector can still
produce a v6 set with `--contract v6`); only its own tracked-set tests and the comparison with v7 do. The remake's adoption of v7 is its own backlog.

*Superseded for the Core 0.377.0 delta (TD-56 C4b, 2026-10-11):* this set stays frozen (its documents and its binding to `b638bd7d...` do not move) and is the baseline `tests/test_event_definitions_tracked.py` compares v7 with, but v7 now differs from it outside `presentation` in the delta classes that test documents (`v7_delta_violations`: the library-set flag effects, the labelled call-argument-storage `unresolved` lines, the selector-0 flag clears that the witness corpus regenerated from the v3 replays decides and, for the 13 documents whose analysis-group profile TD-56 C3 re-derived, those profiles' hashes and the rows of the cells their pins moved on).
