# Audio Metadata Report Contract

## Purpose

`kakyu_audio_metadata_report/v1` is the portable per-entry statement of one
audio archive as the Audio ARC Editor sees it (ME-06, Core 0.335.0): which
archive, which overlay, which MES reference index, and for every reported
entry its effective source, size, hash, header-validated metadata, overlay
record and confirmed MES reference count. It reports; it does not decode
payloads beyond the 64 KiB header the editor validates, and it never
contains a machine path, `user://`, or payload bytes.

## Versioned document

The exact top-level fields are:

- `schema`: `kakyu_audio_metadata_report/v1`;
- `core_version`: the publishing Content Core version;
- `archive`: `name`, `sha256`, `bytes`, `entries` (index count) and
  `audio_entries` (WAV/OGG names in the index);
- `overlay`: `loaded` and `replacements_for_archive`;
- `mes_references`: `indexed`, `source` (file name only), `source_sha256`,
  `source_count`, `reference_count`, `bgm_count`, `voice_count` (zeros and
  empty strings when no index is loaded);
- `entries`: one row per requested entry in request order - `name`,
  `source` (`original_arc`, `overlay` or `pending`), `size`, `sha256`,
  `valid`, `container`, `codec`, `channels`, `sample_rate`, `bit_depth`,
  `duration_ms` (each `null` when the validator does not report it or the
  entry is invalid), `error` ("" when valid), `overlay` (`null`, or
  `original_entry_sha256`, `replacement_sha256`, `compatibility`,
  `text_encoding` from the overlay record), `mes_reference_count` (`null`
  when no index is loaded);
- `summary`: `entry_count`, `original_count`, `overlay_count`,
  `pending_count`, `wav_count`, `ogg_count`, `invalid_count`,
  `total_bytes`, `known_duration_ms`, `referenced_count`;
- `payload_sha256`: the fingerprint over the canonical document JSON
  (`mes_payload_fingerprint.gd`).

An invalid audio entry is a row (`valid` false with the validator's error),
not a build failure. A changed overlay or pending file is a build failure:
the builder re-hashes both before reporting them. `read_path` reads at most
4 MiB and validates the exact key sets, the schema, the fingerprint, the
value sets and the count consistency; it does not re-verify files.

## Production

`tools/content_suite/audio_metadata_report.gd` (`KakyuAudioMetadataReport.build`)
takes the editor's open reader, its resolver, the archive name, the entry
names, the replacement session, and the loaded MES audio reference index.
The Audio ARC Editor's **Export audio report...** covers the selected rows,
or every audio entry when nothing is selected; `write` refuses an existing
output, writes a sibling temporary, rehashes it and publishes by rename.

The same unit makes the editor's entry list multi-select: **Extract
selected to folder...** and **Extract archive...** run the shared batch
extractor (`tools/content_suite/arc_batch_extraction.gd`) over the effective
audio, with a pending session replacement supplied through a descriptor
override so the staged file is what gets extracted; the status reports the
overlay, pending, original and byte counts.

## Verification

`tests/test_audio_metadata_report.tscn` builds the report on the synthetic
audio fixture (an overlay row, a pending row, an original row, a truncated
invalid row, the selector-33 BGM reference), checks every block, the
path-free rule, the fingerprint, the write/read refusals and the fail-closed
changed-pending case; `tests/test_audio_arc_editor.tscn` drives the batch
and report actions through the editor; the original Audio Editor archive
check batch-extracts three entries and the complete `se.arc` and builds the
`bgm.arc` report against the real MES reference index.
