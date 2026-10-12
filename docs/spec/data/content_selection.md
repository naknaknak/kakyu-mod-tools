# Content Selection Contract

## Purpose

`kakyu_content_selection/v1` is the portable, workspace-bound statement of
one selected entry - and optionally one original catalog event and preset -
that a Content Suite app hands to another app (WD-09, Core 0.336.0). It
replaces app-specific launch arguments with one document every app can
produce and validate. The MES Editor's Run request
(`kakyu_mes_editor_run_request/v1`) stays separate: it carries a start
coordinate and an interface proof for an Analysis Run; a selection only
chooses what the receiving app shows.

## Versioned document

The exact top-level fields are:

- `ok`, `schema`, `producer` (`app`: one of `audio_arc_editor`,
  `mes_editor`, `arc_browser`, `image_arc_editor`, `event_player`,
  `launcher`; `contract`: the schema);
- `workspace`: `project_id`, `project_revision`, `generation_sha256`,
  `project_sha256`, `manifest_sha256`, `source_content_set_sha256` - the
  binding of the producing workspace generation, identical in shape to the
  Run request's;
- `selection`: `archive` (a lower-case archive name bound by the
  workspace's source content set), `entry` (a safe entry name),
  `source_entry_sha256` (the original entry's hash in that archive),
  `catalog_id`, `event_id`, `preset_id` (empty strings when no catalog
  event is attached; a preset needs an event);
- `purpose`: `reference_inspection`;
- `payload_sha256`: the fingerprint over the canonical document JSON.

Unknown fields, unknown producers, unbound archives, unsafe entry names,
malformed hashes and a mismatched fingerprint fail closed. A receiving app
validates the document against its own launch-context snapshot: every
workspace field must match and the archive must be bound.

## Transport

`content_core/content_launch_context.gd` accepts `--selection <path>` beside
`--content-set` and `--workspace`; a launch carries either a selection or a
Run request, never both. `tools/content_suite/selection_handoff.gd`
(`KakyuSelectionHandoff.launch`) writes the document as a new file under
`<workspace>/.handoff/` and resolves the receiving app's executable and
argument list; `start` spawns the process.

## Receivers

- Event Player: original-reference selection only. The archive must be
  `mes.arc`, the entry must exist in the original archive with the recorded
  hash; the entry opens in the Analysis view, and an attached catalog event
  (whose callee must be that entry) is selected in the catalog browser with
  its preset - nothing is played.
- MES Editor: a `mes.arc` selection chooses the entry after the workspace
  and its overlay open.
- ARC Browser: the selection's archive opens and its entry row is selected.
- Image and Animation ARC Editor and Audio ARC Editor (Core 0.339.0): a
  selection for an archive the editor accepts (`mmo.arc`/`data.arc`; the
  five audio archives) opens that archive instead of the default, and the
  entry - which must exist with the recorded original hash - is selected
  through the editor's normal preview/details path.

## Producers

The Audio ARC Editor (ME-05) lists the selected audio entry's confirmed MES
references and opens the referencing MES entry in Event Player, attaching
the original catalog event when the catalog names exactly one event whose
callee is that entry and the workspace project uses that catalog. The ARC
Browser (WD-05, Core 0.339.0) opens its one selected entry in the editor
that owns the archive - `mes.arc` in the MES Editor, `mmo.arc`/`data.arc` in
the Image and Animation ARC Editor, WAV/OGG entries of the audio archives in
the Audio ARC Editor (`KakyuSelectionHandoff.specialist_for`).

## Verification

`tests/test_content_selection.tscn` covers the document, its rejections,
the workspace validation and the handoff launch arguments;
`tests/test_content_launch_context.tscn`, `tests/test_event_player_run_request.tscn`,
`tests/test_mes_editor.tscn`, `tests/test_arc_browser.tscn` and
`tests/test_audio_arc_editor.tscn` cover the receivers and the audio
producer; the original `selection handoff original integration` archive
check opens a real catalog event's entry in Event Player from a selection
without playback.
