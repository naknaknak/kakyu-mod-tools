# Projected event definitions (`kakyu_event_definition/v3`)

One document per event site of the name registry
`config/contracts/event_names_v1/`, projected from the analysis-group
profiles under `config/event_catalog/analysis_groups/` (evidence kind
`analysis_group`) or from a catalog row of
`config/event_catalog/original_events_v1.json` (evidence kind
`catalog_event`) by `tools/project_event_definition.py`, under the contract
`docs/spec/data/event_definition_projection.md` and the fixture set
`config/contracts/event_definition_v3/`. The owner decided on 2026-09-16
that the projections are tracked here; the mod player (`kakyu-remake`)
reads them from this repository.

**No original dialogue is stored here.** Every message is a `text_ref`
(package entry, record offset, string index, SHA-256 of the raw CP932
bytes) that resolves against the local playback package the document's
`package_binding` names. The producer writes the resolved twin
(`<id>.resolved.json`, with the text and a readable `script` block) to a
local directory (`--resolved-out`), never here; the validator rejects a
tracked document that carries inline `text`, and
`tests/test_event_definitions_tracked.py` checks every file in this
directory for that and for the recorded fingerprints.

`index.json` (`kakyu_event_definition_index/v1`) records the contract and
registry fingerprints, the package hash the documents were resolved against,
one row per registry site with its validator verdict, and the summary. A
site whose projection or validation failed has an index row with its reason
and no document.

Reproduce, from the project root, after exporting the full playback package
(`tools/content_suite/cli/export_playback_package.gd`) and the replay
records (`validate_event_analysis_group.gd --replay` per profile; the batch
driver replays catalog rows itself):

```powershell
py tools\project_event_definitions_batch.py `
  --names config\contracts\event_names_v1 `
  --catalog config\event_catalog\original_events_v1.json `
  --profiles-dir config\event_catalog\analysis_groups `
  --replays-dir analysis\replays `
  --package <playback package directory> --arc <mes.arc> `
  --elfimage <ELFIMAGE directory> `
  --out config\event_definitions\v3 --resolved-out analysis\event_definitions_resolved
```

The driver exits 1 while any site is invalid; the index says which. A
change to the contract is a new `config/contracts/event_definition_v4/`
beside v3 and a new directory beside this one, never an in-place edit.
