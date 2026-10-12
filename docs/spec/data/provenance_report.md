# Content Provenance Report Contract

## Purpose

`kakyu_content_provenance_report/v1` is the portable lineage statement of one
content workspace (WD-04, Core 0.332.0). It says which original content set
the workspace is bound to, what the workspace changes, what compatibility
those changes declare, and which compiled authoring proof stands behind a
replacement - and it is produced only after every one of those claims has
been re-verified against the workspace files. It complements the
[materialized ARC provenance sidecar](materialized_arc_provenance.md), which
describes one exported ARC copy; the report describes the workspace itself.

The report contains hashes, portable identities, counts and authored values
only. It never contains a workspace or ELFIMAGE path, an absolute path, a
payload byte of an original entry, or dialogue.

## Versioned document

The exact top-level fields are:

- `schema`: `kakyu_content_provenance_report/v1`;
- `core_version`: the publishing Content Core version;
- `project`: `project_id`, `project_version`, `display_name`,
  `project_revision`, `compatibility_objective`, `content_core`
  (`minimum_version`, `maximum_exclusive`), `target_archives`,
  `dependencies` as declared, and `event_player` (`catalog_id`,
  `preset_count`);
- `workspace`: `generation_sha256`, `project_sha256`, `manifest_sha256`
  and `manifest_editor_version` from the reopened workspace snapshot;
- `source_content_set`: `profile_id`, `fingerprint_sha256` and one row per
  bound archive (`archive`, `sha256`, `required`, `bytes`, `entries`);
- `replacements`: one row per overlay replacement in manifest order -
  `target_archive`, `target_entry`, `original_entry_sha256`,
  `original_size`, `replacement_sha256`, `replacement_size`,
  `compatibility`, `text_encoding`, and `authoring`: `null`, or the linked
  authoring bundle's `bundle_schema`, `proof_schema`, `step_count` and
  ordered `operations` (the same hashes, coordinates and authored values
  the bundle summary and the authored delta carry);
- `projections`: one row per MES text projection - `kind`,
  `target_archive`, `target_entry`, `original_entry_sha256`,
  `projection_sha256`, `edit_count`, `compatibility`, `text_encoding`;
- `compatibility`: the project `objective`; `declared` - `not_applicable`
  when nothing is replaced or projected, the one value every replacement and
  projection shares, or `mixed`; `consistent_with_objective` (true for a
  `mixed` objective, for an objective equal to the declaration, or for
  `not_applicable`); and `original_engine_verification`, always
  `unverified` - this tool never executes the original engine;
- `verification`: `manifest_payloads_verified` (always true in a published
  report), `replacement_blobs`, `projection_files` and
  `authoring_bundles_reopened` counts;
- `payload_sha256`: the fingerprint over the canonical document JSON
  (`mes_payload_fingerprint.gd`).

Object member order has no meaning. Unknown fields, unknown schema strings,
malformed hashes, invalid numeric values, values outside the compatibility
and text-encoding sets, and a mismatched fingerprint fail closed in
`read_path`, which validates shape and fingerprint only.

## Production

`tools/content_suite/provenance_report.gd` (`KakyuProvenanceReport.build`)
reopens the workspace transactionally through `KakyuContentWorkspace` and
the selected content set through `KakyuContentSet`, then:

1. requires every bound source archive to fingerprint as the project binds
   it;
2. requires every replacement's original entry to exist with the recorded
   hash and its blob (`replacement_path` under the workspace) to exist with
   the recorded hash; the row records both sizes;
3. requires every projection file to exist with its hash and to parse to an
   edit list;
4. links a replacement to the first authoring bundle (sorted:
   `.authoring/delta`, then `authoring/*`) that `KakyuMesAuthoringSession.read_bundle`
   reopens with the same source and output entry hashes and the same target
   entry, so a link also implies the bundle's reopen validators and proofs
   passed; and
5. derives the compatibility summary and fingerprints the document.

Any failure returns an error and no report. A blob or projection changed
under the manifest is already refused when the workspace reopens; the
builder re-checks every file itself as defense in depth.

`write` refuses an existing output, writes a sibling temporary, rehashes it
and publishes by rename; `read_path` reads at most 1 MiB.

The Launcher's **Export report...** (workspace row) exports the report of the
open workspace as `<project_id>-r<revision>.kakyu-provenance.json`; the
headless `tools/content_suite/cli/export_provenance_report.gd
<content_set_root> <workspace_root> <output.json>` prints one JSON line with
the path, hash, counts and declaration.

## Verification

`tests/test_provenance_report.tscn` builds a synthetic workspace with one
replacement and one MES text projection and checks the document, the
path-free rule, the fingerprint, write/read refusals, the fail-closed blob
mutation and the objective/declaration consistency cases;
`tests/test_content_suite_launcher.tscn` exports through the launcher; every
authoring scene and the original EVENTB03 contextual authoring checks build
the report after publication and require the replacement row to link the
published bundle (`step_count`, `proof_schema`). Measured 2026-09-17 on the
real ELFIMAGE: a freshly created workspace reports eight bound archives
(`bgm`, `data`, `mes`, `mmo`, `se`, `tina1`, `tina2`, `voice`; 1,016 `mes.arc`
entries, 15,438 `voice.arc` entries) and `declared` `not_applicable`.
