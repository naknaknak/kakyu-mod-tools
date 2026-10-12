# Projected event definitions (`kakyu_event_definition/v5`)

One document per event site of the name registry
`config/contracts/event_names_v1/`, projected from the same evidence v4
used - the analysis-group profiles under `config/event_catalog/
analysis_groups/` (every one of the 142 sites resolves through the profile
path, as under v4 since 2026-09-21) - plus, for the two sites whose v13
profile declares a document-level visit ladder, the `visits` list WD-23
adds. By `tools/project_event_definition_v5.py` (which calls straight into
`tools/project_event_definition_v4.py`'s own pipeline for the v4 body, so
every one of the other 140 documents is byte-identical to its v4 sibling
except `schema_version` and `contract_fingerprint`), under the contract
`docs/spec/data/event_definition_v5.md` and the fixture set
`config/contracts/event_definition_v5/`. v4's own producer, documents,
index and tests stay byte-identical; this is a new module that imports what
it shares. `config/event_definitions/v4/` stays frozen.

## What v5 adds over v4

- **A document-level `visits` list**, present only on the two sites whose
  v13 analysis-group profile declares one (EP-11 parts 1a-1c;
  `docs/spec/mes/44c_caller_group.md`): `tina.town.44c.10.2` (EVENTM10 site
  B, a gated ladder that dispatches `EVENTM11.MES` from its second visit
  on) and `tina.town.44c.03.1` (EVENTM03, a sixteen-rung day-change
  ladder). Every other document carries no `visits` field.
- Each visit names the state conditions that select it (`select`, v4's own
  condition vocabulary - a plain counter-cell equality plus, where a gate
  cell is involved, the audited branch condition taken whole), its own flow
  (`dialogue`, one `scene_end`), its own effects (`after`, decided the way
  v4 decides a result's effects), which pass it continues (`follows`) and
  whether it is the fixed point the ladder no longer advances past
  (`repeats`). See `docs/spec/data/event_definition_v5.md` for the exact
  field shapes and the producer's own decision rules.

**No original dialogue is stored here**, exactly as in v3/v4: every message
is a `text_ref`, resolved against a local playback package by the producer
into a local, untracked `.resolved.json` twin (`analysis/
event_definitions_v5_resolved/` in the run recorded below).

`index.json` is `kakyu_event_definition_index/v2`, the same schema v4 uses
(WD-23 adds no new index field: a document's own `visits` are visible in
the document, not summarized in the index).

## Reproduce

From the project root, after exporting the full playback package
(`tools/content_suite/cli/export_playback_package.gd`) and the v2 replays
(`tools/content_suite/validators/validate_event_analysis_group.gd --replay`,
one per analysis-group profile, written under `analysis/replays_v2/`;
WD-23 also fixed a defect the replay step surfaced - `--replay` computed
every declared visit's own message rows and full `state_diff` for its
per-visit checks but never wrote them into the persisted file, so a v13
profile's visits carried no dialogue/effect evidence to project from until
`tools/content_suite/event_analysis_group_validation.gd` was extended to
carry them):

```powershell
py tools\project_event_definitions_batch.py `
  --names config\contracts\event_names_v1 `
  --catalog config\event_catalog\original_events_v1.json `
  --profiles-dir config\event_catalog\analysis_groups `
  --replays-dir analysis\replays_v2 `
  --witnesses-dir analysis\witnesses `
  --package <playback package directory> --arc <mes.arc> `
  --elfimage <ELFIMAGE directory> `
  --contract v5 `
  --out config\event_definitions\v5 --resolved-out analysis\event_definitions_v5_resolved
```

The driver computes the shared-line index first (as under v4), then
projects every registry row through `project_event_definition_v5.py`
(which resolves `--contract-fingerprint` against this contract's own
directory and injects `visits` for the two sites above) and validates each
document against `config/contracts/event_definition_v5/`. It exits 1 while
any site is invalid; the index says which.

**2026-09-23 (WD-23, first projection):** `projected=142 valid=142
invalid=0`, all 142 from groups (0 from a catalog row, exactly as under
v4's own 2026-09-21 regeneration). `contract_fingerprint`
`2ba14eb89d29adf7341270daa60cbbdd01cec0b8ebb9d469c0ee30caa681a471`;
`cells_fingerprint` `de21246988e7cb517ed04eda8a6c92625ba286a89f5f5e7db7441184d086cc73`
(unchanged from v4); `names_fingerprint`
`4a04c35a1897b968cd7d9357b316be282516acf3eea9a8cadf461fcc8c1cc66a`
(unchanged from v4); `package_sha256`
`b4f5f2932be5219d42c9f0e36a4e2e2636129df69008df83d11f428a9612bb7c` (a fresh
export against the same archive, `analysis/playback_package_wd23/`).
`tina.town.44c.10.2` carries 5 visits (`visit2-gate` through the fixed
point `visit5-gate`); `tina.town.44c.03.1` carries 16 (`ladder-00` through
the fixed point `ladder-15`). Every other document is byte-identical to its
v4 sibling except `schema_version` and `contract_fingerprint`.

2026-09-24 (EP-12 catalog part): following v4's own README, `names_fingerprint`
moved from `4a04c35a1897b968cd7d9357b316be282516acf3eea9a8cadf461fcc8c1cc66a`
to `149ccc398689f2b02598af5919411290fac4c96ea42b0cfd49328571633727bb` in
place across all 142 v5 documents (the three promoted `01m-a-date` flow
rows have no v4/v5 document of their own); nothing else moved.

2026-09-25 (EP-12 PROMIS checkpoint C): following v4's own README,
`names_fingerprint` moved twice (only the final value recorded) to
`0f6fc4085609ff5786867032670eb5b2b50008b349504962fb0e6ff1cf11a30b` in place
across all 142 v5 documents plus `index.json` (the twelve new
`01m-<letter>-promis` sites have no v4/v5 document of their own, the same
as a flow route); nothing else moved.

A change to the contract is a new `config/contracts/event_definition_v6/`
beside v3/v4/v5 and a new directory beside this one, never an in-place
edit; v3's and v4's own directories, fingerprints and producers stay
frozen.
