# Media Editors TODO

This tracker owns Image/Animation and Audio ARC editor authoring workflows.

## Implemented Baseline

- [x] MMO inspection, PNG export/import, encode, logical placement, and current
  header-profile diagnostics.
- [x] DAT/PAL decode, quantization diagnostics, palette inventory/editing,
  paired staging, and publication.
- [x] A6 ordered-table insert, duplicate, remove, reorder, overlap, and
  reachability diagnostics.
- [x] AX structural inspection, selected-cell tool timeline, shared playback
  plan, and tool-clock preview.
- [x] AX writer: byte-identical no-op over the corpus, one-cell and
  one-record edits by serialize-and-reinspect, reopen and write audit
  (Core 0.333.0).
- [x] AX timeline editor: per-cell command editing and shared-record
  crop/destination editing over the writer, tool-clock preview of the
  edited animation, staging into the image replacement session
  (Core 0.334.0).
- [x] WAV/Ogg validation, playback, extraction, replacement, duration/waveform
  summaries, confirmed MES-reference index, and deterministic WAV conversion.
- [x] Multi-entry audio batch extraction and the portable audio metadata /
  provenance report (Core 0.335.0).

## Open Work

- [ ] *(deferred by stance)* **ME-01 — Verify DAT/PAL replacement in the original engine.**
  - Deferred with MV-01: mods target the remake runtime, so original-engine
    display is not a product gate. See
    [Stance Toward the Original Game](../docs/spec/tech/original_source_stance.md).
  - Legacy: P5-03; procedure is owned by `manual_verification.md`.
- [x] **ME-02 — Implement the general AX timeline editor.** Closed 2026-09-17
  at Core 0.334.0: the Image and Animation ARC Editor's AX editor edits the
  selected cell's command list (replace, insert after, remove, move up and
  down) with the grammar's opcodes and u32 operands - order, the count loop
  (`05`/`06`), the reset (`03`) and the stops (`04`/`FF`) are the confirmed
  subset; `00`/`01`/`02`/`07`/`08` stay "native meaning unconfirmed" and
  are edited as values - and any shared record's dispatch type, source
  crop and destination within the 2688x864 / 640x400 bounds, all through
  `KakyuAxWriter.replace_stream`/`replace_shared_record`; the inspector's
  cell selector, Game Frame overlay and tool-clock preview show the edited
  animation; `Stage AX` audits and stages the written bytes into the
  replacement session (`original_engine_unverified`); `Revert edits`
  discards them. Verified 2026-09-17: the image editor scene (160 checks, the synthetic `A01.AX`: record and command edits, reorder, refusals, staging with the audit, overlay save and reload, revert, the 1024x640 fit), the AX writer scene (22), the Image Editor archive check (a record edit staged, reopened and audited on `A01.AX`, `ax_edit_staged=true`), the AX corpus check (630 no-op, 10 edits), the local batch (113 checks); Python untouched (1,540). Edited AX playback in Event Player stays out of
  scope; native delay cadence is not claimed.
  - Legacy: P5-05.
- [x] **ME-03 — Implement the AX writer.** Closed 2026-09-17 at Core 0.333.0:
  `content_core/ax_writer.gd` (`serialize`, `replace_stream`,
  `replace_shared_record`, `reopen`, `write_audit` /
  `kakyu_ax_write_audit/v1`), structural validation against the corpus
  contract (bounded rectangles, in-range dispatch indices, one final
  terminal, 320 cells), the no-op and one-byte-edit proofs in
  `cli/validate_ax_corpus.gd`, and the round-trip line in the image editor's
  AX details. Measured 2026-09-17 over the whole `data.arc` corpus: all 630 AX entries re-serialize byte-identically (201,600 streams, 254,695 commands, 6,332 records), and a one-byte control inserted before the terminal of the first non-FF cell of ten entries reopens with the later cells' targets shifted by one byte, every other stream identical and an audit `byte_delta` of 1. Verified 2026-09-17: `tests/test_ax_writer.tscn` (22 checks: no-op, reopen, growth, `04 FF`, record edit, eight rejections), the image editor scene (141), the AX corpus and Image Editor archive checks, the local batch (113 checks); Python untouched (1,540). Editor preview of an edited AX arrives
  with the timeline editor (ME-02); edited AX playback in Event Player stays
  out of scope.
  - Legacy: P5-06.
- [ ] *(deferred by stance)* **ME-04 — Verify replacement OGG in the original engine.**
  - Deferred with MV-02, for the same reason as ME-01.
  - Use a license-independent disposable local-copy procedure and keep engine
    launch user-controlled.
  - Legacy: P6-04.
- [x] **ME-05 — Connect original-event references and editor audio checks.**
  Closed 2026-09-17 at Core 0.336.0 with WD-09: the Audio ARC Editor lists the
  selected audio entry's confirmed MES references and `Open in Event Player`
  hands the referencing MES entry - with its original catalog event and
  preset when the catalog names exactly one - to Event Player through the
  selection contract; Event Player opens it for reference inspection without
  playback, and replacement audio is never forwarded. Measured on the real ELFIMAGE: `EVENTB15.MES` has exactly one catalog event (`original/eventb15/11m-0000347b`), which the selection carries with the `daytime-original` preset.
  - Open the source event in original-only Event Player for reference inspection;
    validate authored audio in the editor and package tools. Replacement audio
    is not forwarded for Event Player playback (scope decision 2026-09-08).
  - Status 2026-09-17: the editor audio checks exist (header validation on
    selection, staged files rechecked before every save, overlay and new-ARC
    export verification, and the audio metadata report of ME-06); the
    "open the source event in Event Player" half needs the versioned
    selection contract of WD-09 (Event Player takes only a content set /
    workspace today, no entry or event selection), so it is scheduled with
    WD-09 rather than built as a one-off argument.
  - Legacy: P6-05, narrowed by the original-only scope decision.
- [x] **ME-06 — Add multi-entry audio metadata/provenance reporting and batch extraction.**
  Closed 2026-09-17 at Core 0.335.0: the Audio ARC Editor's entry list is
  multi-select; `Extract selected to folder...` / `Extract archive...` run
  `tools/content_suite/arc_batch_extraction.gd` over the effective audio
  (overlay, pending session file through descriptor overrides, or
  original; per-source counts, no overwrite, rollback); `Export audio
  report...` writes `kakyu_audio_metadata_report/v1`
  (`tools/content_suite/audio_metadata_report.gd`,
  `docs/spec/data/audio_metadata_report.md`): archive and overlay identity,
  the MES reference index summary, per-entry source, size, hash,
  header-validated metadata, overlay record and confirmed reference count,
  and a summary; path-free and fingerprinted. Verified 2026-09-17: `tests/test_audio_metadata_report.tscn` (37 checks), the audio editor scene (86), the batch extraction and ARC Browser scenes (24, 54), the Audio Editor archive check (three `se.arc` entries and the complete archive of 87 entries and 22,923,742 bytes extracted with hashes verified; the `bgm.arc` report of 52 entries, 50 of them with confirmed MES references), the local batch (114 checks); Python untouched (1,540).
  - Legacy: P6-06.

## Boundaries

- Runtime surface/cadence/input/audio behavior belongs to
  `presentation_audio.md`.
- Cross-app launch and portable packaging belong to
  `workspace_distribution.md` and `event_player.md`.
