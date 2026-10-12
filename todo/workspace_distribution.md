# Workspace and Distribution TODO

This tracker owns format-neutral workspace management, ARC Browser completion,
cross-app coordination, portable packaging, export, and final distribution
verification.

## Implemented Baseline

- [x] Versioned portable project and workspace contracts.
- [x] Shared publication locks, revision/CAS checks, stale-owner recovery, and
  reopen validation for current publishers.
- [x] Path-free materialized-ARC provenance and source/effective content identity.
- [x] Shared original/materialized/overlay resolution; the engine-bound
  ContentService was removed by TD-13.
- [x] Minimal Launcher Create/Open, path history, and independent app launch.
- [x] ARC Browser read-only inventory, filtering, selected extraction, overlay
  lifecycle, and verified existing-entry ARC materialization.

## ARC Browser

- [x] **WD-01 — Add ARC-to-ARC and ARC-to-overlay comparison.** Closed
  2026-09-17 at Core 0.338.0: `tools/content_suite/arc_comparison.gd` compares
  indexes and whole-entry hashes (identical / changed / only left / only
  right, order preserved or not; against the loaded overlay: identical /
  changed / overlay identical, the overlay files re-hashed and
  fail-closed); the ARC Browser's `Compare with ARC...` and `Compare with
  overlay` show a differences-first panel and export the path-free
  `kakyu_arc_comparison/v1` (`docs/spec/data/arc_comparison.md`);
  `cli/compare_arcs.gd` is the headless form. Verified 2026-09-17: `tests/test_arc_comparison.tscn` (47 checks), the ARC Browser scene (70), the ARC Browser archive check (the real `mes.arc` compared with itself: 1,016 identical rows, order preserved), the CLI on the same archive (0.4 s), the local batch (117 checks); Python untouched (1,540). The compare buttons live on a third toolbar row so the window still fits 1024x640. Byte-level diffing
  inside an entry belongs to the specialist editors.
- [x] **WD-02 — Add multi-entry and complete-archive extraction.** Closed
  2026-09-17 at Core 0.331.0: the entry list is multi-select; `Extract selected
  to folder...` and `Extract archive...` run
  `tools/content_suite/arc_batch_extraction.gd` (safe unique names, every
  entry resolved and every destination absent before the first write,
  in-order streaming through the resolver, rollback of the batch's own
  files on failure, per-source counts in the status); the headless
  `cli/extract_arc_entries.gd` runs the same batch. On the real `mes.arc` the ARC Browser check batch-extracts `START.MES`, `DEF_MAIN.MES` and `LIBLARY.LIB` and then the complete archive (1,016 entries, 18,617,388 bytes) with every hash verified and the source unchanged (4 s). The CLI extracts the same three entries (94,311 bytes) and the whole archive in about 3 s.
  Cancellation and progress for the gigabyte archives stay WD-16; the
  provenance sidecar stays WD-04.
- [x] **WD-03 — Add conservative raw replacement staging.** Closed 2026-09-17
  at Core 0.340.0: the ARC Browser's `Stage raw replacement...` stages one
  file over the one selected existing entry into the named workspace
  through `KakyuContentWorkspace.stage_replacements`
  (`tools/content_suite/raw_replacement_staging.gd`): non-empty, at most
  64 MiB, not identical to the original, validated where the repository has
  a validator (MES/LIB container, WAV/OGG header, AX, A6, MMO) and labelled
  unvalidated otherwise, always `remake_only`, target archives only; no
  add, delete, rename or reorder. Verified 2026-09-17: the raw staging (17 checks), ARC Browser (86), workspace (34) and overlay (118) scenes, the local batch (118 checks), the original ARC Browser archive check, and a read-only probe offering every real entry of `mes.arc`, `data.arc`, `mmo.arc`, `se.arc` and `bgm.arc` as its neighbour's replacement (1,014 MES, 527 AX, 11 A6, 1,721 MMO and 99 audio entries validated, 128 staged as opaque; the only refusals were 198 byte-identical neighbours); Python untouched (1,540).
- [x] **WD-04 — Add portable provenance/compatibility report export.** Closed
  2026-09-17 at Core 0.332.0: `kakyu_content_provenance_report/v1`
  (`docs/spec/data/provenance_report.md`) built by
  `tools/content_suite/provenance_report.gd` from the reopened workspace and
  content set - project identity, generation hashes, bound archives, every
  replacement/projection with hashes, sizes and declared compatibility, the
  linked authoring bundle (`step_count`, proof schema, operations), and the
  objective/declaration summary - fail-closed on any changed file,
  path-free, fingerprinted; Launcher `Export report...` and
  `cli/export_provenance_report.gd`. Verified 2026-09-17: `tests/test_provenance_report.tscn` (31 checks), the Launcher scene (37), every authoring scene and the original EVENTB03 edited-event and sequence archive checks (the report links the published bundle after each publication), the local batch (112 checks), the Python regression unchanged (1,540); a workspace created against the real ELFIMAGE reports its eight bound archives. Materialized ARC copies
  outside the workspace keep their own sidecar; a workspace dashboard stays
  WD-07.
- [x] **WD-05 — Add specialist-editor handoff.** Closed 2026-09-17 at Core
  0.339.0: the ARC Browser's `Open in editor...` hands its one selected
  entry, with the original entry hash, to the editor that owns the archive
  (`mes.arc` → MES Editor; `mmo.arc`/`data.arc` → Image and Animation ARC
  Editor; WAV/OGG entries of the audio archives → Audio ARC Editor) through
  the WD-09 selection contract; the two media editors became receivers.
  Verified 2026-09-17: the selection (27 checks), ARC Browser (77), Image and Animation ARC Editor (167), Audio ARC Editor (100) and MES Editor (158) scenes, the selection handoff archive check extended to the real `data.arc` (`A01.AX` selected with its AX inspector) and `se.arc` (`KSE0031.WAV` validated), the local batch (117 checks); Python untouched (1,540).
- [x] **WD-06 — Reassess add/delete/reorder only after lookup evidence exists.**
  Closed 2026-09-17 by owner ruling (option 1 of three): the reassessment is
  done and the tools stay replacement-only. Reasoning: the evidence below
  shows that adding and reordering would be lookup-safe and deleting would
  not, but new events are authored as definitions, no concrete need for new
  archive entries exists, and adding them would first need a shared new-media
  contract for the remake. Options 2 (add-only behind a new compatibility
  gate) and 3 (add, delete and reorder including materialized copies) were
  not chosen; either reopens as a new item when a mod needs an entry the
  original archives do not have.
  - Lookup evidence measured 2026-09-17 and pinned as
    `kakyu_ai5_arc_exe_audit/v5` (`entry_index`): the original engine builds
    a name-keyed ordered map at open (unique insert, first of two equal names
    kept, stored names unchanged, no fixed record limit), releases the index
    buffer, upper-cases every requested name and fails a miss with `-1`. The
    index order means nothing to the engine, an added upper-case name
    resolves like an original one, a removed name fails its consumers. All
    eight original archives store upper-case names in name order. Today the
    overlay and the ARC writer refuse a target absent from the source ARC, and
    no contract carries new media for an authored event.

Legacy: P7-01 through P7-06.

## Launcher and Project Manager

- [x] **WD-07 — Add workspace revision and compatibility dashboard.** Closed
  2026-09-17 at Core 0.337.0: the Launcher's `Dashboard...` panel
  (`tools/content_suite/apps/workspace_dashboard_panel.gd`) renders
  `KakyuProvenanceReport.build` for the open workspace - project identity,
  revision and objective, the running Core against the project's range, the
  generation hashes, the bound archives, every replacement and projection
  with sizes, compatibility, encoding and linked authoring proof, the
  objective/declaration summary and the verification counts - shows the
  builder's error when a payload no longer verifies, and refreshes and
  exports the same statement. Verified 2026-09-17: `tests/test_workspace_dashboard.tscn` (42 checks: rendered blocks, the fail-closed changed blob and its recovery, export and refused re-export, the core range helper), the Launcher scene (41), the provenance report scene (31), the local batch (116 checks); Python untouched (1,540). The workspace keeps no revision
  history, so the dashboard shows the current revision only.
- [x] **WD-08 — Add structured validation runner and result viewer.**
  - Closed 2026-09-06. Launcher starts the repository suite without blocking
    or opening a console, using optional read-only ELFIMAGE/EXE inputs. The
    selected context and run UUID bind the result to that process.
  - Report v3 uses an atomic SHA256 envelope, exact schema/count validation,
    six coverage groups with unrun reasons, and bounded failure output.
    The viewer distinguishes current and saved results and migrates v2 as
    unsigned historical evidence with unknown coverage. It does not certify
    active workspace modifications or a playback package.
  - Verified: 26 Python runner/report regressions, 48 Godot report/session/UI
    assertions, existing launcher regressions, and actual Windows background
    process success/configuration-error paths. Python-generated passing,
    failed, unavailable-process and timeout reports all reopen in Godot.
    The full local batch passes 94/94 checks: 1,209 Python tests, a project
    parse check and 92 Godot scenes, in 156.874 seconds. Its v3 report also
    reopens through the viewer reader. Headless layout checks cover 1024x640,
    1920x1080 and 2560x1440; manual DPI/visual checks stay in WD-15/WD-19.
- [x] **WD-09 — Add selected-entry/event handoff between apps.** Closed
  2026-09-17 at Core 0.336.0: `kakyu_content_selection/v1`
  (`content_core/content_selection.gd`, `docs/spec/data/content_selection.md`)
  binds the workspace generation, one bound archive, one entry with its
  original hash and an optional original catalog event/preset; the launch
  context accepts `--selection` (never together with a Run request);
  `tools/content_suite/selection_handoff.gd` writes the document under
  `.handoff/` and resolves the receiver's launch; Event Player receives
  original-reference selections only (entry into the Analysis view, catalog
  event and preset selected without playback), the MES Editor and the ARC
  Browser select the entry; the Audio ARC Editor is the first producer.
  Verified 2026-09-17: `tests/test_content_selection.tscn` (22 checks), the launch context (24), Event Player run-request/selection (18), MES Editor (158), ARC Browser (57) and Audio ARC Editor (93) scenes, the new `selection handoff original integration` archive check (`EVENTB15.MES` opened from a selection with its catalog event `original/eventb15/11m-0000347b` and preset `daytime-original` selected, playback inactive, sources unchanged), the Audio Editor archive check, the local batch (115 checks); Python untouched (1,540). ARC Browser to specialist editor launches stay WD-05. The MES
  Editor's Run request is unchanged.
  - Share a versioned selection contract for named workspace, entry and optional
    original catalog event/preset. Event Player receives original-reference
    selection only; MES authoring/proof validation stays MW-11/MW-12 and
    package validation stays WD-21. EP-08 owns old edited-launch UI cleanup.
- [x] **WD-10 — Add portable mod-package build.**
  **Closed 2026-10-11** at Core 0.377.0 (no Core change; spec `analysis/_docs/wd10_spec.md` v2, machine-local). One mod artifact,
  `kakyu_mod_bundle/v1`, carries a workspace's authored v9 deltas, its translation-only entries and its definition set in one JSON
  file. `tools/mod_bundle.py` builds and validates it, and one staged-import engine reconstructs it into a fresh workspace and
  reopens every effective identity before publication. Owner rulings of 2026-10-11: the bundle carries the translation-only
  entries (`text_projections`, Q1), and WD-10 closes on the headless proof with the Launcher's export and import as **WD-24**,
  unscheduled (Q2). Contract and verification: `docs/spec/data/mod_bundle.md`.
  - **2026-10-11, closing record.**
    - **The commits:** C1 `bd3093ee` (the contract, `tools/mod_bundle.py`, the shared publisher) with its review follow-up
      `6300719d`; C2 `1ed5cff2` (the import engine, the bundle importer and its CLI) with `235bfb4c`; C3 `6d237bb6` (the archive
      check `original mod bundle round trip`); C4 `48541898` (TD-67, `todo/code_health.md`); C5 `8f81d232` (the definition,
      workspace, gap-matrix and tools records); C6 the closing records.
    - **The build** (`py tools/mod_bundle.py build`) carries the whole workspace or nothing: each `mes.arc` replacement with a
      linked authoring bundle becomes a v9 delta, each `mes.arc` projection on an entry with no replacement becomes a
      `text_projections` row, and the definitions become the set. It refuses, naming the record, a raw replacement (a staged MES
      with no authoring bundle, or any replacement outside `mes.arc`), a projection outside `mes.arc`, an empty workspace and a
      projection that overlaps a relocated message. The mod identity is the set's when the workspace has definitions
      (`--mod-id` and `--mod-revision`, if given, must agree); without definitions `--mod-id` is required and the revision
      defaults to 1. Two authoring bundles that match one replacement but name different operations are refused as ambiguous;
      otherwise "the first readable bundle wins" is safe, because a bundle must bind the entry and both the original and the
      replacement hashes and `read_bundle` verifies every file. The file is at most 64 MiB, checked on its size before any parse.
      Every hash in it is a SHA-256 of `mes_authoring_workflow._json` bytes (one trailing LF), never `payload_values.fingerprint`
      (TD-66 records the two conventions).
    - **The import** (`tools/content_suite/cli/import_mod_bundle.gd`) is one engine with two front doors.
      `authored_delta_import.gd` became the engine (`import_members`); `import_delta` is its one-member door with its result and
      messages unchanged; `mod_bundle_import.gd` reconstructs every member into one fresh workspace (the deltas into
      `authoring/delta-<ENTRY>`, one `stage_replacements` and one `stage_mes_text_projections` call, the set through the set
      importer) and reopens the stage to check each entry hash, each projection's exact edits, the counts and the definitions
      before the existing lock-and-rename publication. A failure leaves no destination.
    - **The recorded boundary: a deltas-only bundle's mod identity is not persisted.** A v9 delta names no mod, and a workspace
      derives `mod_id` from its definitions (`content_workspace.gd`), so a bundle without a set declares its `mod` in the header,
      verified and not persisted: the import reports `mod_persisted` false and the reopened `mod_id` is empty. Persisting it would
      be a `content_core/` change, which this unit excluded. It is a boundary of the contract, not a defect.
    - **The D11 deviation.** The spec put the deltas-only bundle among both modes' assertions. It, the CLI and the refusals run in
      the synthetic mode only: the boundary is workspace behaviour, pinned by the synthetic scene, and running it in the original
      mode too would have lifted the archive check from 179 s to about 250 s (an estimate) against its 300 s stop.
    - **Helper accounting** (each item replaced copies; by construction nothing was added to the TD-05/TD-06 residue, which was
      not re-measured):
      - `publish_new_document` (`tools/payload_values.py`) is the one hard-link publication rule. `authored_mod_delta.publish`,
        `mod_definition_set.publish` and `prepare_mes_editable_ir.publish_new` became wrappers with their messages and temporary
        names unchanged, so `publish_new` did stay behind a wrapper (the spec's exit for a wrapper that could not keep its
        behaviour was not needed): three copies became one helper, and the bundle publishes through it too. The review
        follow-up made the post-link removal of the temporary best-effort (a failed removal before the link still propagates;
        two tests pin both directions) and made the build assert that the built delta reproduces the workspace's replacement.
      - `validate_text_edits` (`tools/authored_mod_delta.py`) holds the delta's text-edit rules in one function, called by the
        delta and by the bundle's text rows; the delta's messages are unchanged.
      - `tools/content_suite/python_validated_extract.gd` holds the hash-before/after, `--extract`, last-JSON-line verdict and
        tree removal. `mod_definition_set_import.gd` migrated to it (its private `_last_json_line` and `_remove_tree` and
        `build_set`'s inline last-line parse are gone), and `235bfb4c` moved `mod_definition_binding.gd`, whose private
        `_last_json_line` was byte-identical, onto its `last_json_line`: one more copy removed. The bundle importer is its second
        consumer and adds none. A wording note from the C2 review: `build_set`'s "produced no verdict" refusal also covers a `{}`
        verdict, because `last_json_line` returns an empty dictionary for no JSON line and for `{}` alike; no tool prints `{}`.
      - `tools/content_suite/workspace_project_document.gd` builds a workspace project document from a content set, extracted
        from `validate_selection_handoff_original.gd`, which uses it. The Launcher's `_build_default_project_document` keeps its
        own copy until WD-24.
      - `ContractValues.intify`, the Core's existing helper, folds the bundle's JSON integers back, so there is no new copy of
        that conversion. The `new_event` definition fixture moved to `tests/test_helpers.gd`, which the set-import test now calls.
    - **Verified:** `tests/test_mod_bundle.py` (67 tests, in the Python suite); `tests/test_mod_bundle_import.tscn` (79 checks in
      the synthetic mode: a multi-entry bundle, a deltas-only bundle, a bundle without a delta, the CLI and every refusal); the
      archive check `original mod bundle round trip` (`EVENTB01.MES` and `EVENTB03.MES` state edits, `EVENTB03.MES`'s and
      `EVENTB02.MES`'s synthetic translations, one `new_event` definition; tier `full` at 900 s; 179.5 s and 179.0 s solo with an
      identical PASS line, 29 assertions). The existing delta-flow, set-import, definition-panel and provenance scenes passed in
      the closing batch.
    - **The closing batch:** the whole `full` tier, uncached, `--jobs 6`, on tree `8f81d232` (run `e6cb6108`): **479 of 479 in
      2,546.4 s** and 10,715.5 check-seconds; `--cached` on the same tree 479 of 479, all cached, 9.5 s. The new archive check ran
      179.5 s of its 900 s (0.20) and `Godot test_mod_bundle_import.tscn` 11.9 s of 180; no check passed 0.4 of its timeout; RAM
      peak 78.8%. The wall time was 46 s above the unit's range because the new check had no cache entry and ran at the tail.
      TD-67 closed with the batch (`todo/code_health.md`). The record is in `docs/spec/data/validation_checks.md`.
    - **Left open** (none scheduled): **WD-24**; WD-12 (merging into an existing workspace and the conflict UI, deferred by the
      owner); persisting a deltas-only bundle's mod identity (a `content_core/` change nobody has asked for); assembly of a
      bundle from loose delta and set files, and older delta versions as members; exporting the imported workspace to a
      playback package (WD-21, U4 deferred); the release build's smoke import list (`tools/build_windows_distribution.py` names
      `authored_mod_delta`, not `mod_bundle`; the tool itself ships, since every top-level `tools/*.py` is copied).
    - **Documents updated:** `docs/spec/data/mod_bundle.md` (new), `docs/spec/index.md`, `mod_definition_set.md`,
      `authored_mod_delta.md`, `mod_event_definition.md`, `mod_event_definition_design.md` (ruling 3), `content_workspace.md`,
      `docs/spec/tech/content_suite_gap_matrix.md`, `docs/spec/tech/content_tools.md` (a dated revision section),
      `docs/spec/data/validation_checks.md` (the ordering rule and the closing proof), `tools/README.md`,
      `todo/code_health.md`, `TODO.md` and `todo/mes_pipeline.md`.
  - Core 0.329.0/0.330.0 (2026-09-17): delta v9 carries every authoring family
    and ordered operation sequences (`operations`, dependencies as their
    union); the headless importer reconstructs and reopens stepped bundles
    (`tests/test_mes_sequence_authoring.tscn` delta flow; the sequence
    archive check). Import conflicts and clean-machine delivery remain,
    deferred by the owner on 2026-09-17: a conflict needs two mods merged
    into one workspace, which no one has asked for; WD-12 keeps the UI and
    WD-20 the clean machine (closed unverified by the owner, 2026-10-09).
  - Core 0.304.0 adds authored delta v2 for one variable-length message edit
    plus non-overlapping original-coordinate translations. V1 state deltas
    remain readable. Reconstruction must reproduce exact output/proof hashes;
    the imported local bundle supplies the mapping when an editor reopens it.
  - The first authored-only delta v1 and fresh-workspace headless importer pass
    on original EVENTB03. The delta contains one state-edit operation, UTF-8
    edits and hashes; Python reconstruction reproduces the compiled output and
    semantic proof, and Godot imports/reopens the same MES/text identities.
    The original/template workspace and existing output destinations are
    preserved. Evidence: `analysis/authored-delivery-20260908.log` plus three
    Python mutation/publication test cases. General multi-entry/family support,
    dependencies, import conflict UI and clean-machine delivery remain open.
  - Reject original payload leakage, absolute paths, missing dependencies, and
    incompatible schemas/core versions.
  - Ship only authored changes and source-fingerprint provenance. A local full
    playback package can contain user-owned original content and is a separate
    WD-21 output; never label it as a distributable mod delta.
  - Reopen and apply the delta against a matching local source/workspace and
    reproduce the authored effective identities without embedding the archive.
- [ ] **WD-11 — Coordinate verified ARC-set materialization.**
- [ ] **WD-12 — Add recovery and conflict-resolution UI.** Deferred by the
  owner on 2026-09-17 until a second mod has to be merged into an existing
  workspace; today's importers (a single delta's and, since WD-10, a mod
  bundle's) create one fresh workspace per import - a delta, or a whole
  bundle of deltas, translation-only entries and definitions - and refuse an
  existing destination, a changed source or a mismatched proof. Two members
  for one entry are refused in a bundle; merging them stays WD-12's.
- [ ] **WD-21 — Export authored workspace content to a local playback package.**
  - Core 0.330.0 (2026-09-17, TODO step 5): the export and its contextual Run
    accept every authoring family (same-size v2 proofs bind by identity
    after byte-level checks; relocation as before) and every stepped v9
    bundle (chain proof plus the bundle's step-by-step source check;
    contextual binding v3 with the chain hash and step count). Headless
    entry point unchanged in shape; it passes the reopened bundle. Archive
    checks `original resource contextual authoring` and `original sequence
    contextual authoring` join the edited-event and relocated-message
    checks. Contract: `docs/spec/data/workspace_playback_export.md`.
  - Core 0.304.0/package v7 carries message-relocated event/choice/terminal and
    owned resume coordinates, cross-checked against contextual bindings. UTF-8
    overlays map by reproduced source/output message identities. Older packages
    require re-export; the separate remake contract remains unmodified.
  - The first supported workspace export is implemented in Core 0.303.0/package
    v6: same-width callee state edits with semantic proof and UTF-8 projections.
    Original EVENTB03 reopens and runs from the package alone with the authored
    state, Korean string table and expected terminal. New-destination publication,
    immutable generation and source/effective identity checks pass alongside all
    12 original package routes (5/5, `analysis/workspace-playback-validation.json`).
    Other structural families, modified shared entries, richer dependency
    contracts and export UI remain open; deferred media/caller work stays deferred.
  - Accept an immutable active workspace, validated compiled MES/proofs and
    UTF-8 overlays; package the effective content rather than fixed originals.
  - Bind source, effective identities and every packaged file to the manifest;
    stage, reopen and atomically publish only a new destination.
  - Inventory shared script/media dependencies with source evidence. **Done
    for the package's own records by U1 (Core 0.373.0, 2026-10-06):** the manifest's
    `media_inventory` and `script_references` blocks list every media and script
    reference of every member with its offset, which of the media the original archives
    ship (identity) and which they do not (the known-absent register, gated in the
    batch). What stays open from the TD-04 contract is the scope of **modified shared
    entries in an authored export** (U4, deferred by the owner); the CG table (U3) was withdrawn by
    the owner on 2026-10-09 (the last bullet of this item).
  - Report the deferred media extraction and the caller-owned completion
    terminals outside the package as explicit package incompleteness. They are
    not newly authorized by this item; a script-only package must not claim
    standalone completeness. Media extraction stays deferred
    (`incompleteness.media_extraction` is the literal `deferred`; U1 inventories
    the media, it extracts nothing). **External terminals are a property of the
    export's membership:** the full original export of Core 0.373.0 (681 events,
    869 members) has **0** - `12C.MES` and `13C.MES` are analysis-group members
    now, and the 7 terminals they own are in the package - while a
    `--event` export lists every terminal whose owner entry is not among its
    members. (Measured 2026-09-16 at Core 0.323.0, 13 catalog events from 228
    members: 7 events, 16 terminal rows, all in `12C.MES`/`13C.MES`; "eight" was the
    count under the 17-entry membership. Both are dated measurements, not the
    current package.)
  - **Membership rule, 2026-09-16, owner ruling (a), Core 0.323.0.** The full
    original package carries every `mes.arc` entry a committed analysis-group
    profile lists as a source member, beside the catalog events' members; the
    catalog stays the playback-qualified subset. Measured over 138 profiles:
    216 distinct source members (not the 156 index rows the ruling was put
    with - the profiles also list 60 callers, talk and system scripts outside
    the classification index), 5 already catalog members, package 228
    entries (211 `analysis_group_member`), 81,521,185 bytes,
    246,930 records, 67 s to export. Schema stays v7 (additive; the
    v3 event-definition contract pins it): manifest `membership` (rule,
    counts, one row per profile with its payload hash) and `incompleteness`
    (`standalone_complete` false, `media_extraction` deferred,
    `external_terminals` in the workspace binding's shape), per-entry
    `bound_by`; the reader recomputes and rejects inconsistent blocks and
    still loads a manifest without them. Entry names with interior dots are
    accepted (`GROUND.INC.MES`). Evidence: `tests/test_playback_package.tscn`
    (membership blocks, eight fail-closed mutations, additive tolerance,
    profile merge with fingerprint-conflict, duplicate-payload and malformed
    cases, entry-name rule), `original playback package export` and
    `original playback package playback` green: "PASS: playback package export: 13 events from 228 member entries (17 catalog-verified, 211 bound by 138 analysis groups); 246930 records, 109237 provenance instructions dropped, 97 analysis fields dropped by rule, 81521185 bytes over 3685697 bytes of bytecode; archive unchanged. Core 0.323.0 / kakyu_playback_package/v7. Media extraction, package-scope sharing of the library and playback itself are not included." / "PASS: playback package playback: 82 checks over 13 catalog events; 12 reach a catalog-declared terminal, 251 dialogue boundaries and 509 message payloads run from the package alone with no archive access, matching the bytecode reference on segments, trace rows, message payloads, final state and terminal. Core 0.323.0 / kakyu_playback_package/v7. Media, native presentation cadence and unselected choices are not part of this run.".
    Contract: `docs/spec/data/workspace_playback_export.md`.
  - **Annotation, 2026-10-07 (U1 C5): the dated bullets above are history.** Their figures
    are those of their day (Core 0.304.0-0.330.0: 12-17 catalog events, 228 members), not of the
    current package (681 events, 869 members, Core 0.373.0, `b638bd7d...`). Three statements
    in them are superseded: "richer dependency contracts" and "deferred media/caller work" (the
    Core 0.303.0 bullet) - U1 inventories the media and script references of every member and the
    external-terminal list is empty for the full export (the bullets above say so); and the
    package export's PASS line of the membership bullet ("Media extraction, package-scope sharing
    of the library and playback itself are not included"), which was that revision's text and is
    not the current line. "Modified shared entries" is U4 (deferred).
  - Respect the versioned cross-repository contract; this tracker owns only the
    producer and its local validator, never the remake implementation.
  - **2026-10-05, owner ruling: this item is the next work** (`TODO.md`
    Execution Order step 4), after TD-51 (batch trust). It receives EP-12's
    deferred CG, the flag -> picture table (a static decode of the 13
    `?_CG.MES` viewers, `docs/spec/mes/gallery_families.md`; whether the CG
    viewers join the package membership is a ruling this item still asks).
  - **2026-10-06, owner rulings on the scoping survey's later units.** U2, the
    per-row `resources` (catalog and v6 `presentation.resources`, `[]` in every
    row today): taken from the **measured route**, not a static
    over-approximation. U3 (whether the 13 `?_CG.MES` viewers join the package
    membership) and U4 (the scope of modified shared entries in an authored
    export) are deferred, to be decided later. U1 (the media and script
    inventory, the known-absent register, the catalog binding;
    `analysis/_docs/wd21_u1_spec.md`) is in progress, and its record lands
    here when it closes.
    *Later the same day, owner ruling on U3:* the CG data is **exported from
    the original `?_CG.MES`** - the flag -> picture table, statically decoded
    with source provenance (entry, code-relative offset) as a versioned,
    fingerprinted contract this repository owns - and **whether the remake
    uses it is the remake's decision**. The viewers are not added to the
    package membership for playback (the table carries what they contribute;
    planner's reading of the ruling, the owner may overrule). Still to settle
    in U3's spec: whether a slot's several picture loads are layers or a
    sequence (shared routines 21/22, system call 12), and that the table's
    picture names join the media inventory and the known-absent gate. **The
    table also carries the page layout** (owner, same day): pages and slots
    per page (`global_u8[20]`/`[27]`, four slots a page) and the `ALBUM.A6`
    regions of the slots and buttons. U4 stays deferred.
    *Annotation 2026-10-08 (U2):* "`[]` in every row today" was true of its day. Since U2 (catalog
    revision 41) every row carries its measured list, and the filled field landed in a new
    `kakyu_event_definition/v7` rather than in v6, by the owner's confirmation of 2026-10-08 below.
  - **2026-10-06, U1 C1 and C2a (code; recorded in C5).** C1 (`85bc841`, with its
    review fixes `5125443`, `c76094a`, `4a8145b`; `tools/` and `tests/` only, no Core
    bump) fixed the manifest's catalog binding: `build()` had read a `document` key the
    catalog's load result does not have, so `source.catalog_id` and
    `source.catalog_revision` were `""` and `0` since the split; it now carries both
    from the load result, `serialize()` refuses a build result with no slug id or a
    non-positive revision, and `media.referenced_resource_names` comes from the build
    result. **The package hash now follows `catalog_revision`:** `package_sha256` covers
    the whole manifest, so a catalog revision bump moves the hash (and so rebinds the
    v6 set), where before a catalog revision bump alone did not move the hash;
    the reader stays tolerant of a manifest with an empty or absent binding.
    C2a (`7780071`, review fix `a78754a`; Core 0.372.0 -> 0.373.0) added the classifier,
    the identity table, the two blocks and the reader's recompute. The C2b, C3 and C4
    records follow.
  - **2026-10-06, U1 C2b measurement** (the Core 0.373.0 state is `a78754a`;
    nothing pushed). Schema ruling D1 (advisor): `media_inventory`
    (`kakyu_media_inventory/v1`) and `script_references`
    (`kakyu_script_references/v1`) are additive optional v7 manifest blocks with
    their own ids, no v8; this repository's reader fails closed on an unknown id,
    recomputes the ids it knows and ignores an absent block (no claim about the
    remake's reader). Full original export, measurement directory
    `analysis/playback_package_wd21_u1` (untracked), package `b638bd7d...`,
    Core 0.373.0: 681 events, 869 members, 987,386 records, `manifest.json`
    13,419,998 bytes against 7,580,550 (`4d0ca40d`). Time: the registry check
    `original playback package export` (no `--out`) 309.5 s of 900 s solo through
    the runner (0.344, under the 0.35 stop; TD-50 baseline 274.3 s); the export
    with `--out` 361.9 s (0.402), 53.3 s of it writing 329.7 MB and `write()`
    reopening it - a one-off of the binding export, not a check; `--out` must be
    an **absolute** directory (a relative one is refused after the build); the
    reader reopens the package in 41.9 s (inventory recompute 10.7 s).
    Occurrences / names / absent: `mmo` 6,738 / 1,577 / 161, `ax` 2,316 / 465 /
    66, `voice` 23,027 / 14,187 / 0 (878 Tina names in both banks), `se` 79 / 78 /
    0, `a6` 13 / 1 / 0, `bgm` 5,157 / 45 / 0, `unclassified` 1,460 / 547 / 19;
    16,654 of 16,900 names shipped, 246 absent, 0 undecided, 0 `scan_only`, every
    scan hit a record (6,738 / 2,316 / 23,027 / 2 strict). The 246 are the
    refuter's 227 marker-kind names (161 `.mmo` + 66 `.AX`, containing all 163
    reached misses of 17 events) plus 19 loader-string absences (eleven
    function-24 `.mmo`, two `.gp8`, six function-5 `.wav`). **The six BGM-table
    names (BOALING, IDO_DWN, NANA2, PB, SHOCK, STAY) are `unclassified`
    function-5 `.wav` absences, not `bgm`-kind ones** - no packaged record selects
    them. Unclassified loader strings: function 8 `.ccd` 58 / 8, `.mpc` 58 / 8,
    `.eve` 8 / 7, function 9 `.gp8` 6 / 2, function 24 `.mmo` 592 / 332, function 5
    `.wav` 56 / 56, and `native_record_dispatch` `.dat` 341 / 98, `.pal` 239 / 19,
    `.mmo` 102 / 17 (21 members); native meanings stay unresolved. The BGM
    inventory equals `KakyuMesAudioReferenceIndex` over the 869 members (5,157 =
    5,157, no difference; none of the 980,797 non-library records outside a
    region). D9 holds: `source.catalog_id` is the tracked catalog's id,
    `catalog_revision` 40, `media.referenced_resource_names` equals the `4d0ca40d`
    list (16,231). Records: `analysis/_undoc/wd21_u1/c2b_*` (untracked). Documents:
    `docs/spec/data/workspace_playback_export.md` ("Media inventory and script
    references"), `docs/spec/mes/media_references.md` (the classification rules,
    their evidence and what is a tool decision). The register, the gates and the
    v6 rebind are C3 and C4.
  - **2026-10-06, U1 C3: the known-absent register and the two gates** (tools,
    config and tests only; Core 0.373.0 and package `b638bd7d...` unchanged;
    nothing pushed). Register `config/event_catalog/known_absent_media_v1.json`
    (`kakyu_known_absent_media/v1`, `payload_sha256` `799f4266...3cfe`), written
    from the C2b export by `tools/build_known_absent_media.py <package-dir> --out
    <path>` (pure Python, LF; it refuses a manifest without `media_inventory`, an
    unknown block schema id, a selected-event export, one without analysis-group
    members and any `shipped: null` row; it cannot tell an `--include-unbound-groups`
    superset from the default full export, which the manifest does not record, and gate 1's
    exact compare catches a register written from one as stale rows - corrected
    2026-10-07, C5, from "a non-full export"): a header with the SHA-256 of the seven media archives the
    producer opened and **246 rows - 161 `mmo`, 66 `ax`, 19 `unclassified`** (no
    `voice`, `se`, `bgm` or `a6` row), each `(kind, normalized name)` with the
    archives searched and no evidence. Two pure compares in
    `tools/content_suite/known_absent_media.gd` (a tool decision over an
    original-data fact; not in `content_core`): **gate 1** in
    `export_playback_package.gd` only, before anything is written - the default
    full build's absent set must equal the register exactly (a new absence or a
    stale row fails) and the package's `archives` header must equal the register's,
    an `--event` or other variant is held to "no unregistered absence"; **gate 2** in
    the group-route Playback pass - a picture, animation source, voice, BGM or
    effect miss must be a registered `(kind, name)` or the shard fails, and a failed
    shard now prints `FAIL shard` (it printed `PASS shard` unconditionally; the exit
    code already failed). Tests: 25 Python cases (writer, fail-closed, determinism) and
    `tests/test_known_absent_media.tscn` (129 checks: both gates' positive and
    negative cases, malformed register, schema and header mismatch, category
    mapping, the tracked register's cross-language fingerprint). Measured solo
    through the runner: `original playback package export` with gate 1 **312.4 s of
    900 (0.347)**, package hash `b638bd7d...` unchanged, register 246 rows against
    246 absent, `compare=exact` (309.5 s without the gate); `original catalog group
    routes [12/20]` (34 rows, holding the `e-h`, `k-h`, `l-h` ladders, `eventb02` and
    `eventd02`) **609.1 s of 3,000 (0.203)**, `PASS shard`, 46 misses (18 pictures, 28
    animation sources), all registered; local tier 138 of 138 in 257.6 s (134 cached).
    Records: `analysis/_undoc/wd21_u1/c3_*` (untracked). The other 19 shards, the
    full-tier checks the unit touches and the closing batch are C3.5 and C5.
    **The F2 boundary (C3 review, recorded in C5):** gate 2 looks a BGM miss up as
    `bgm`, while the six absent BGM-table names (BOALING, IDO_DWN, NANA2, PB, SHOCK,
    STAY) are registered as `unclassified` function-5 `.WAV` rows, because no packaged
    BGM record selects them; a future BGM miss on one of them would therefore fail as
    unregistered. That is a classifier-level fact, not a register defect, and it is
    unreachable today (the playback pass has had no BGM miss).
  - **2026-10-06, U1 C4: the v6 rebind** (no code change; Core 0.373.0). C3.5
    passed first (run `0dd818e6`, 27 of 27, every check under 0.5 of its timeout;
    report `analysis/_undoc/wd21_u1/c35_report.json`). The C2b measurement export
    `analysis/playback_package_wd21_u1` is the binding export: `git diff
    9e63018..644e3e1` over `content_core/` and `playback_package_export.gd` is
    empty and its manifest `package_sha256` is `b638bd7d...`; against the
    previous package (`4d0ca40d...`) only `manifest.json` differs (1,739 files in
    each). The 681 v6 definitions were regenerated in place with the 2026-10-05
    command and the new `--package` (detached, solo, `--jobs 4`, 66 min 57 s,
    `projected=681 valid=681 invalid=0`, witness line unchanged). Diff against
    `HEAD`: **681 of 681 documents differ in `package_binding.package_sha256`
    alone and `index.json` in `package_sha256` alone** (682 files, 682 changed
    lines; `names_fingerprint` `94223afe...`, `contract_fingerprint`
    `74556e64...` and `cells_fingerprint` `de212469...` unchanged; v4 and v5 stay
    frozen). Dated section in `config/event_definitions/v6/README.md`; the hash in
    `TODO.md` follows. Verified: `tests/test_event_definitions_tracked.py` (49 OK) and
    the registry's `python regression suite` (the only check that reads the v6 set:
    4 shards, 2,180 tests, 239.2 s) passed; the Godot scenes read v4 only. Logs
    `analysis/_undoc/wd21_u1/c4_*` (untracked). C5 (stale statements, the closing
    batch) remains.
  - **2026-10-07, U1 is done (C5: the stale records and the closing proof).** Owner
    ruling TD-54 first (`cdd5b5f`): the relocated-message, edited-event and resource
    contextual-authoring checks moved from `archive_quick`/600 s to `full`/900 s
    (C3.5 had them at 290.8, 267.1 and 233.5 s loaded). Then the live statements U1
    made false were rewritten and the dated ones annotated (`dc99e46`): the package
    contract page, the gap matrix, TODO.md, this item's scope bullets (the full export
    has 0 external terminals: `12C.MES`/`13C.MES` are members), the 43C, 12C and 13C
    pages, `content_tools.md`'s "hash follows the catalog revision, as before"
    (not so before C1). **Closing proof:** the whole `full` tier, uncached with
    `--cache-store`, `--jobs 6`, detached and solo, on the committed tree `dc99e46`
    (Core 0.373.0, package `b638bd7d...`): **475 of 475 passed in 5,253.6 s** (run
    `7513c6ad`, `cached: 0`), the analysis-group process 3,691.5 s of 8,000 (0.46), the
    export check 309.1 s of 900 (0.34), the playback check 745.1 s of 1,800 (0.41), the
    20 shards 582-906 s of 3,000 (0.30 at most), the three moved checks 221.8, 242.5 and
    231.0 s of 900 (0.25-0.27), no check past 0.45 (the highest, the transfer-direction
    corpus, 0.42); the shards passed with 70 picture and 114 animation-source misses, all
    184 registered, 0 unregistered. Then `--cached --jobs 6`: 475 of 475 cached, 8.5 s (run
    `3b0a2572`). TD-53 closes with this batch. **WD-21 itself stays open:** U2 (the per-row
    `resources`, from the measured route) is next by owner ruling, then U3 (the CG table
    exported from the original `?_CG.MES`, with its page layout), and U4 (modified shared
    entries in an authored export) is deferred. Reports: `analysis/_undoc/wd21_u1/closing.json`,
    `closing_cached.json` (untracked).
  - **2026-10-08, U2 spec and owner confirmation.** The U2 spec (`analysis/_docs/wd21_u2_spec.md`,
    v2 after an advisor and a refuter pre-review) defines a row's measured route as the package's
    `media_inventory` occurrences whose record a measured run of the row executed, unioned over
    every replayed variant, run and hop. The owner confirmed its two tool decisions the same day:
    **the filled field lands in a new `kakyu_event_definition/v7`** (items `{entry, source_offset,
    kind, name}`; the 2026-10-06 ruling's wording named v6, and adding `entry` is a shape change,
    so v6 is frozen at `b638bd7d...` as v4 and v5 are at theirs), and **media a shared
    `LIBLARY.LIB` routine or DEF definition loads while the route runs are part of the route's
    resources** (78 of the 79 `se` and 383 `mmo` occurrences are library-executed).
  - **2026-10-08, owner ruling: no `LIBLARY.LIB` items in the live lists for now.** The C2
    replays (`kakyu_event_analysis_group_replay/v3`, `9e5c553`; 227 profiles, 12,152 runs) showed
    that every measured library media ladder sees selector 0: routines 9 and 27 select on
    `global_i32[1]`, the generic runner keeps command-`0x09` writes in `argument_slots` only
    (`content_core/mes_event_runner.gd:1077-1095`; the native storages are one, the runner's ABI
    is recorded as uncorrected, `docs/spec/mes/audio.md:604-614`). Routine 9 (468 runs) reaches 0
    of 78 SE; routine 27 (3,839 runs) always takes its selector-0 `BLACK.MMO` arm, which the
    union would have put into 272 of 681 rows as a tool artifact. Asked to choose between
    continuing with library items excluded and modelling the feed first (a Core change that
    regenerates the replays and voids the v6 equality proof), the owner chose the former: the
    live v7 documents and the catalog list no `LIBLARY.LIB` occurrence, the replays keep the
    library offsets, the 12 `DEF_MAIN.MES` items stay, the v7 contract keeps `LIBLARY.LIB` a valid
    entry, and the contract page and `docs/spec/mes/media_references.md` state why with the
    counts. The feed is TD-56 (`todo/code_health.md`), after U2; then v7 and the catalog
    regenerate in the same shape. The v7 contract itself landed in `36e1f68` (C3).
  - **2026-10-08, U2 C2-C7a landed (closing batch pending).** The spec is
    `analysis/_docs/wd21_u2_spec.md` (v3 plus the C1-C5 result sections). Each checkpoint had an
    advisor checkpoint review.
    - **C2 `9e5c553`:** the replay writers emit `kakyu_event_analysis_group_replay/v3` (per run
      `executed` and `resource_rows`) and `tools/regenerate_group_replays.py` regenerates them.
      `analysis/replays_v3/` holds 227/227, which equal v2 minus the additions; 12,152 runs.
    - **C3 `36e1f68` + `739f171`:** the v7 contract, 9 valid and 81 invalid fixtures, fingerprint
      `a48267ac...`.
    - **C4 `90d4ede` + `425c7761`:** `tools/project_event_definition_v7.py` and 681 v7 documents
      in 70 min. Outside `presentation` they equal v6 in 681/681, and an independent re-join
      agrees in 681/681. Items: 17,020, 14,710 distinct (route 14,698, DEF 12; library 544 held
      back, the R7 pair); voice 9,113, mmo 2,972, bgm 1,288, ax 1,022, unclassified 315
      distinct; none empty.
    - **C5 `676f1538` + `f2817587`:** the promoter reads v7 only, catalog revision 41 (the diff is
      the revision and 681 `resources` arrays; 18.7 -> 21.6 MB), and gate 3
      (`tools/content_suite/declared_media.gd`). The C5.5 pre-run `d9ab937c` passed 22 of 22:
      15,011 played names compared, 0 undeclared; gate 2 0 unregistered; at most 0.36 of a
      timeout.
    - **C6 `b774ec92` + `e46e2e41`:** the rebind tool `tools/rebind_event_definitions.py`. The
      binding export `874f53ca...` differs from U1's only in `manifest.json`'s `package_sha256`
      and `source.catalog_revision`, and the v7 set is rebound to it: 681/681 valid. v6 stays
      frozen at `b638bd7d...`.
    - **C7a `0292d17d`:** the measured-route section of `docs/spec/mes/media_references.md` and
      the stale-statement sweep.
    - Also found by the unit: TD-55 (`75384fb`), TD-56 (the library ladders), and the planner's
      R9, which keeps the fingerprinted v7 contract README's C3 wording.
  - **2026-10-09, U2 is done (C7: the records and the closing proof).**
    - **Before the batch:** the pre-batch records (`08ed27c1`) and the C6 review's wording fixes
      (`d5fa4395`). The C6 review checked batch readiness and found no check at risk. It missed
      one: the route classification binds the SHA-256 of the catalog's canonical JSON.
    - **Uncached run:** the whole `full` tier, uncached with `--cache-store`, `--jobs 6`, detached
      and solo, on `d5fa4395`: **475 of 477 in 4,770.3 s** (run `4d0be71d`). The two failures,
      `original event analysis frontier` and `original event corpus literal dispatch inventory`,
      came from that binding: C5 had not refreshed `config/event_catalog/route_classification_v1.json`
      for revision 41.
    - **Fix (`425d9b0d`):** only `catalog_sha256` and the payload hash moved; no row, class or
      confidence. The two checks then passed solo.
    - **Cached run:** `--cached` on `425d9b0d` passed **477 of 477, 474 cached, 242.6 s** (run
      `94a6094d`).
    - **Uncached run, in detail:** the analysis-group process took 3,180.4 s of 8,000. No check
      passed 0.37 of its timeout; the highest were the transfer-direction corpus at 0.365 and package
      playback at 0.35. Gate 3 compared 15,011 names with 0 undeclared; gate 2 had 184 registered
      misses and 0 unregistered.
    - TD-62 (`todo/code_health.md`) adds the local-tier guard that would have caught the missed
      refresh.
    - **WD-21 stays open:** U3 (the CG table exported from the original `?_CG.MES`, with its page
      layout) and U4 (deferred). TD-56 restores the library items afterwards. The batch speed items
      (TD-57 first) come right after U2 by owner ruling; where U3 falls relative to them is not
      ruled.
    - Reports: `analysis/_undoc/wd21_u2/closing.json`, `closing_fix_targeted.json`,
      `closing_cached.json` (untracked).
  - **2026-10-09, owner ruling: U3 is withdrawn.** No CG table is written as long as the CG pictures
    themselves are there. The viewers stay outside the membership, and no CG contract is exported.
    - **Checked the same evening** by a static scan of the 13 `?_CG.MES` viewers' MMO presentation
      records (command `0x0D`, subcommand 9; the pattern of `tools/audit_mes_mmo_markers.py`). The scan
      read `mmo.arc` and the `media_inventory` of package `5ae6aabe...`.
    - The viewers make **586 loads naming 572 distinct pictures, all shipped in `mmo.arc`**. **556 are
      already inventory names**, because member events play them.
    - **The 16 that are not:**
      - each viewer's own page picture `CG_<heroine>_M.MMO` (13);
      - three pictures that no member names: `D15SS.MMO`, `G05SS.MMO` and `M22C.MMO`. Only the
        viewers name the first two; `M22C.MMO` is also named by the non-member `44C_END.MES`.
    - The offsets are in `docs/spec/mes/gallery_families.md`. The owner chose to record the 16, not to
      inventory the viewers.
    - **WD-21 stays open with U4 (deferred).** TD-56 restores the library items to the v7 lists and the
      catalog.
  - **2026-10-11, TD-56 restored the `LIBLARY.LIB` items** (`todo/code_health.md` TD-56; this closes the 2026-10-08
    option (a) above). Core 0.377.0 models the one storage behind command `0x09` and token `0xF6`, so the shared media
    ladders select by the caller's real selector. The v7 documents were re-projected (against the Core 0.377.0 export
    `3af3779f...`) and list the library items, and the catalog is revision 43: **1,093 `LIBLARY.LIB` items in the `resources`
    of 293 rows (251 distinct: `mmo` 106, `se` 25, `unclassified` 120; the first sound-effect items any row declares), 17,020
    -> 18,113 items in all.** The live package is TD-56's export B (`0e47e063...`, catalog revision 43). Two consequences the
    2026-10-08 ruling did not foresee: the library-set flags `global_u8[4000]`, `[4090]` and `[4091]` = 1 enter the
    definitions as ordinary effects (owner ruling 2026-10-11) while the argument storage is excluded (D11); and playback
    did not present library media, so gate 3 could not see the items (EP-14, `todo/event_player.md`, closed 2026-10-11: the
    Playback pass presents them since Core 0.378.0, 497 of the 1,093 by the default runs, and the live package is `fe9bb6bd...`). The
    closing batch: 477 of 477, run `bcd678df`. **WD-21 stays open with U4 (deferred).**
- [x] **WD-22 — Project qualified routes to a shared `kakyu_event_definition/v3` contract.**
  Opened 2026-09-14 on the owner's direction: a Godot-side JSON event script is
  not a new format to invent but the remake's existing
  `kakyu_event_definition/v2` (its local-only `docs/spec/data/event_definition_contract.md`,
  a prototype with 5 files under `data/events/`, 3 of them declaring the v2 schema, `write_legacy_value`,
  `complete_event`, `return_to_map` effects and `mes_expression` /
  `mes_expression_file` conditions) raised to a **v3 agreed by both
  repositories**, produced here from the analysis-group evidence. Scheduled
  after the current analysis work (Execution Order step 1); nothing in it is
  started before then.
  **Ruling, 2026-09-14, by the owner:** for this agreement the remake may be
  edited from here - its contract document raised to v3, the mirrored
  fixtures and recorded fingerprint, its validator and fixture test, and its
  TODO entry for the adoption. Executing the new condition, effect and
  terminal kinds in the remake's game shell stays the remake's own backlog;
  the general boundary in `AGENTS.md` is otherwise unchanged.
  **Ruling, 2026-09-21, by the owner (option 1 of two):** the pre-commit
  review of EP-10 unit 5 read the "new directory beside the old" rule as
  forbidding the in-place regeneration of `config/contracts/event_names_v1`
  (129 rows gained the `catalog_event_id` alias, fingerprint `dbad4b00...`
  to `4a04c35a...`). The owner kept the practice: a shape (schema) change
  goes to a new directory; a regeneration of the same shape stays in place
  with the README revision line and the fingerprint. `AGENTS.md` now says so.
  **Remake state read the same day (read-only):** its last commit, `7504aef5`
  of 2026-09-05, removed the ARC reader, the bytecode code source and the
  instruction decoder, and kept the playback-package code source and the
  runners - so the package is what the remake executes and a `text_ref`
  into the package's UTF-8 table is something it can resolve. Its TODO still
  cites `kakyu_playback_package/v3` while this producer writes v7, the drift
  the fixture fingerprint is for. Its `main` carries 44 unpushed commits;
  commits for this agreement land there separately and name the fingerprint.
  - **What v3 must carry that v2 does not, read off what the 128 profiles
    already declare:** a `caller_dispatch` trigger (caller entry, intro offset,
    nested call or root handoff, and the map-arm origin the outer-eligibility
    item measures, which later becomes the `arrival` mapping); the guard as an
    inline typed conjunct list - date, weekday, clock and affection cells by
    their names, everything else as a `mes_expression` AST - bound to the
    record's offset, end and hash, with the accepting and rejecting witnesses;
    choices from the routine-40 contracts and the variants' `result_value`s,
    with per-branch effects from the per-variant `expected_state`; effects as
    absolute `write_legacy_value` rows (storage, bank, index, value), never
    deltas, split route-level and per-branch as the profiles split them; a
    terminal vocabulary mirroring the outcome kinds (root handoff target,
    natural handoff resume, definition selection, caller menu loop, nested
    root handoff, map-location contract); reentry (the done-gate cells and
    the second visit's effects and message count); `dependencies` for nested
    presentation and talk scripts with their own questions; presentation as
    resource names and marker offsets with `status: deferred` until media
    extraction; and an evidence binding - archive SHA-256, group id, profile
    SHA-256, member entry hashes.
  - **Text is referenced, not embedded.** A dialogue entry of an original
    event carries `text_ref` (entry, message offset, raw-text hash) resolved
    from the playback package's UTF-8 string table, plus a `package_binding`
    (package schema and SHA-256); inline `text` stays legal for authored
    content only. This is the standing rule, not a choice: original dialogue
    never enters a tracked file here, so a projection of an original event is
    trackable evidence and the package remains the only carrier of text.
    Presentation stays labelled and deferred for the same reason.
  - **Sharing method - agreement by fixtures, mirrored, fingerprinted:**
    1. The contract is three artifacts: the prose contract (fields, consumer
       semantics, the condition and effect vocabularies) in the remake, where
       its consumer lives; the producer mapping (how each profile field
       becomes a v3 field and what stays unresolved) here, as
       `docs/spec/data/event_definition_projection.md`; and a **conformance
       fixture set** - valid documents, invalid documents and their expected
       verdicts - mirrored byte-identically in both repositories under
       `config/contracts/event_definition_v3/` with a recorded
       `contract_fingerprint` (SHA-256 over the canonical fixture files in
       sorted order). Each repository tests its own copy against its own
       recorded fingerprint and its own validator against every fixture, so
       the copies cannot drift silently - the failure the package contract
       already suffered (this producer writes v7 against a sibling
       specification that stopped at v3).
    2. Every v3 document carries `schema_version`, `contract_fingerprint` and
       the evidence and package bindings; both sides fail closed on any of
       them, as the package does. A change is a v4 fixture directory beside
       v3, never an edit of v3 in place.
    3. Reaching the agreement, in one line of work under the ruling above:
       draft the projection document and the fixture set here; run the
       producer on one route already carried by the package (EVENTJ04 or
       EVENTB03, so no catalog promotion is needed); copy the fixtures into
       the remake, raise its contract document to v3, make its validator and
       fixture test pass on the same fingerprint, and record the adoption in
       its TODO; then record the same fingerprint in both trackers on the
       same day - that record is the agreement. Until then the documents are
       drafts and no compatibility is claimed. Commits land in each
       repository separately, with the fingerprint named in both messages.
    4. Not chosen now: a third contracts repository shared by both sides. It
       would hold this contract, the package schema, the condition projection
       and the translation catalog cleanly, but it changes what each
       repository owns - the split chose copies over shared checkouts - and is
       the owner's call if a second cross-repository contract drifts.
  - **Dependencies and order.** The first proof needs only the current package
    and a qualified route it already carries. Widening to the 118 qualified
    routes needs the package to carry their entries, which is WD-21's
    membership rule or the deferred option (a) of the classification ruling
    (`analysis_only` catalog rows); the `arrival` trigger needs the
    outer-eligibility measurement. Producer and local validator are this
    repository's; the remake's validator and fixture test are done under the
    ruling above, and its runtime execution of the new kinds is not planned
    here.
  - **Draft, 2026-09-15.** Steps 1 and 2 of the execution order closed, the
    producer mapping is drafted as
    `docs/spec/data/event_definition_projection.md`: the v3 shape (evidence
    and package bindings, `caller_dispatch` trigger with a typed-guard,
    map-arrival or caller-prefix origin, the guard as named-cell conjuncts
    with witnesses beside a runnable `mes_expression` condition, presets,
    choices, branches, absolute-row effects, the six terminal kinds, reentry,
    dependencies, deferred presentation), the mapping from a catalog row and
    from a profile route, `text_ref` = package entry + record offset + string
    index + raw hash, dialogue captured by replay per branch, the fixture set
    layout and the fingerprint rule (SHA-256 over sorted `path	sha` lines).
    The owner confirmed the design the same day (dialogue by replay; text
    referenced in tracked documents and resolved locally with a readable
    `script` block; the guard vocabulary; a five-segment id
    `<heroine>.<category>.<place>.<number>.<site>` from a shared name registry
    with its own fingerprint; scenes from the map contracts; the event body
    separated from a `results` map, `choice_event` with a `choice` block) and
    the agreement landed: the projection document,
    `tools/build_event_names.py` (the registry, 142 sites),
    `tools/project_event_definition.py` with
    `tools/content_suite/cli/replay_event_dialogue.gd` (EVENTJ04 projected as
    `minatu.town.station.04.1`: four results, one per replayed run, 21 entries
    each of which seven are protagonist name inserts, five typed completion
    writes in the body, the done cell on the completion gate; every text
    reference and member hash resolves against the local package),
    `tools/validate_event_definition.py` and the conformance fixture set (6
    valid, 26 invalid). The remake received the mirrored fixture set and
    registry, its contract document raised to v3, a GDScript validator with a
    fixture test, and its tracker entry, committed there separately.
    **Agreement recorded 2026-09-15: `contract_fingerprint`
    `7545e37e08d3dacac8eafb4757ec3ca68305af8afb9278001cce3932a272fb55`,
    `names_fingerprint`
    `b7ffcea3abac019a78f8ac19e98d5259fc778a0eb3c7123424f257b435163e1a`.**
    Open: widening from the 13 package-carried events to the 118 qualified
    routes (WD-21's membership rule), the profile-route side of the producer
    (the mapping is written; the first proof used a catalog row), and
    executing the new kinds in the remake's shell (its own backlog).
  - **Ruling, 2026-09-16, by the owner: the remake is not edited from here
    again.** The exception above was spent by the remake's adoption commit of
    2026-09-15 and is closed. The sharing method changes for every later
    revision: the contract artifacts - the fixture set, the registry, a
    future `event_definition_v4/` - are changed in this repository only, and
    the remake reads the shared conventions from this repository; how it
    reads them is its own arrangement, not tracked here. The 2026-09-15
    fingerprints stay the record of the v3 agreement and the copies the
    remake received that day are its own files. The READMEs inside the two
    contract directories describe that mirrored landing and are part of the
    fingerprinted bytes, so they keep their wording.
  - **Ruling, 2026-09-16, by the owner: the remake schedules and plays from
    event definitions only.** Asked whether its shell should run the original
    caller scripts and override them at declared dispatch sites, or replace
    that scheduling with definitions, the owner chose the latter: the remake
    does not run original scripts. New events and changes to when an existing
    event fires are authored as definitions; MES editing (MW-11) stays for the
    interiors of original event scripts. Consequences here: the projection of
    every qualified route (the widening above) is the mod player's schedule
    and event bodies, so each definition must carry what a body needs without
    the script - dialogue by replay, effects as absolute rows, choices and
    results, terminals as scene transitions, presentation as labelled
    resource names - which v3 already does with presentation deferred; the
    package stays the analyzer's local carrier the producer resolves text
    against, and the remake consumes the resolved document. The remake's own
    definition-based scheduler is its backlog. An animation timeline contract
    (PNG frames plus a JSON timeline in place of AX playback) was raised the
    same day and skipped by the owner for now.
  - **Widened, 2026-09-16 (Core 0.323.0).** Part A: the analysis-group
    validator writes `--replay` records from the runs it already performs
    (138 replay files, 2,329 variants, every declared message count
    matched). Part B: `tools/project_event_definition.py --site <registry
    id>` projects a site from its profiles, and
    `tools/project_event_definitions_batch.py` projects and validates every
    registry row: 142 sites (13 catalog, 129
    profile), 138 documents, 138 valid, 4 invalid against
    package `bf3d1f6e...` and the recorded fingerprints. The four invalid sites are catalog rows whose replay the bounded route probe cannot finish: EVENTB14, EVENTD05 and EVENTD06 stop inside shared routine 25 at a library definition invoke, and EVENTD14 needs definition 21, registered by a caller prefix that no recorded analysis route replays; the Event Player proves those four with its own runner, and the follow-up is to record their analysis routes as EVENTJ04's or to declare them as analysis groups so the profile path covers them. Tracked
    under `config/event_definitions/v3/` with `index.json` and a README by
    the owner's decision (A) of 2026-09-16 - the remake reads them from this
    repository and resolves text against its own package copy; the resolved
    documents with text go to a local directory (`--resolved-out`), and
    `tests/test_event_definitions_tracked.py` guards the set (contract,
    fingerprints, no text, index agreement). Recorded gaps: the resume's messages
    after a nested-call event are counted, not projected (v4 candidate -
    projected since v4, 2026-09-18, see `docs/spec/data/event_definition_v4.md`);
    seed-dependent effects and the done cell of callee-gated reentries are
    named in each document's `unresolved` (a probe follow-up for the latter). Evidence: `tests/test_project_event_definition.py`,
    `tests/test_event_definition_contract.py`, the batch index.

Legacy: P8-01 through P8-06.

- [x] **WD-23 — Carry visit ladders to the mod player (`kakyu_event_definition/v5`).**
  Done 2026-09-23 (`a800e1e`): `docs/spec/data/event_definition_v5.md`;
  `config/contracts/event_definition_v5/` (`contract_fingerprint`
  `2ba14eb89d29adf7341270daa60cbbdd01cec0b8ebb9d469c0ee30caa681a471`, 7
  valid and 49 invalid fixtures); `tools/project_event_definition_v5.py`
  and the batch driver's `--contract v5`; `config/event_definitions/v5/`,
  `projected=142 valid=142`, EVENTM10 site B carrying 5 visits and EVENTM03
  16, each selected by the counter equality and, for gated visits, the
  whole gate condition from the bytecode; `repeats` on the fixed points.
  Effects a visit's single sample cannot decide stay named in `unresolved`.
  v3/v4 and the names registry unchanged; the remake's adoption is its own
  backlog. Verified: the contract and tracked-document tests (40), the v3/v4
  producer tests (75), local 134/134, package export and playback, source
  bindings.
  Ruled 2026-09-23 by the owner with EP-11 (unit 2): once EP-11 declares
  visits, the event definitions carry them so the remake can schedule a
  later visit. v4 has one `reentry` per result, so this is a shape change:
  `config/contracts/event_definition_v5/` beside v4 (v4 stays and keeps
  validating), `config/event_definitions/v5/` projected for every site, the
  names registry unchanged unless a site is added. The remake's adoption is
  its own backlog.
  - **Shape ruled 2026-09-23 (owner, option 1 of three):** a document-level
    `visits` list, each visit selected by state conditions (the counter
    value and gate flags, taken from the bytecode in v4's condition form),
    with v4's `reentry` unchanged and the visits continuing after it; a
    `repeats` marker on the fixed-point visit. Spec:
    `analysis/_docs/wd23_event_definition_v5_spec.md`.

- [ ] **WD-24 — Launcher export and import of the mod bundle.**
  Opened 2026-10-11 by the owner's ruling on WD-10 (Q2: WD-10 closes on the headless proof); unscheduled. The bundle
  (`kakyu_mod_bundle/v1`, `docs/spec/data/mod_bundle.md`) is built and imported headlessly today - `py tools/mod_bundle.py build`
  and `validate`, `tools/content_suite/cli/import_mod_bundle.gd` - and the Launcher offers neither. WD-24 adds
  `Export mod bundle...` (a named workspace to a bundle file, through `tools/mod_bundle.py build`) and `Import mod bundle...` (a
  bundle file into a new workspace beside the template, through `mod_bundle_import.gd`), and migrates the Launcher's
  `_build_default_project_document` (`tools/content_suite/apps/content_suite_launcher.gd`) to
  `tools/content_suite/workspace_project_document.gd`, the helper WD-10 extracted. An import still creates one fresh workspace per
  bundle: merging into an existing workspace and the conflict UI stay WD-12. The gap matrix's Launcher row
  (`docs/spec/tech/content_suite_gap_matrix.md`) points here.

## Distribution and Final Regression

- [x] **WD-13 — Add one Windows export preset per independent application.**
  - Closed 2026-09-08, Core 0.306.0. All six EXE/PCK pairs use official Godot 4.7
    release templates, with independent default scenes and direct startup.
    Build-time audits and post-publication audits from another working directory
    pass for every app: 561 resources each, no original/local-only payload paths,
    and no editor feature. The 329-file inventory and portable ZIP verify.
  - Reproduction, artifact identities and exact limits are recorded in
    [Windows Application Distribution](../docs/spec/tech/windows_distribution.md).
- [x] **WD-14 — Add app identity, icon, version, and workspace arguments.**
  - Core 0.306.0 carries application/Core/engine identities and uses named
    companion EXEs for launcher and edited-event Run, preserving workspace
    arguments. Official release templates cannot use editor scene/path overrides.
  - Isolated Python 3.14.5/Pillow 12.2.0 and authoring workers are packaged with
    exact version/hash/file checks. All six apps pass synthetic authoring and
    native Pillow diagnostics without installed Python on PATH. Licenses ship
    alongside versioned runtime/distribution manifests.
  - Icons and native executable version metadata remain open. Clean Windows is
    still WD-20; headless development-machine verification does not close it.
  - **Native version metadata, 2026-09-18.** Measured first: with the builder's
    `application/modify_resources=false` every exported app presented itself
    to Windows as file version `4.7`, description `Godot Engine`, no product
    name. Godot 4.7 rewrites the template's version resource by itself when
    `modify_resources=true` - no rcedit, headless - and the rewritten
    executable still runs. `tools/build_windows_distribution.py` now injects
    that setting with `file_version` and `product_version` set to the Core
    version plus a zero build number, reads every exported executable back
    with the new pure-Python `tools/windows_pe_version.py`, and refuses the
    build unless the fixed versions equal the Core version and the product
    name and description equal what the app's export preset declares. Each
    application's report in the distribution manifest carries its `identity`,
    and the manifest adds `native_version_metadata: true`;
    `native_identity_metadata` stays false because the icons are still the
    engine's. No company name or copyright is written. Verified 2026-09-18 by a complete build at Core 0.344.0 (`analysis/windows-suite-0344-20260918/`, 667 inventoried files, distribution fingerprint `6033edf76ed2823a7fe9422da94b35561fe0de81e696ca153acd19a026a5b9c6`): all six apps export, carry `0.344.0.0` with their own description, run and pass the distribution audit with host Python off the PATH, `--verify` reopens the inventory, and rereading each executable reproduces the identity the manifest records; `tests/test_windows_pe_version.py` (6 tests, a synthetic PE), the local batch (121 checks, Python 1,554).
  - Still open: the executable icons, which need artwork the owner chooses.
  - **Closed 2026-10-09 by owner ruling: the icons are Godot's default.** No artwork is commissioned.
    Neither `project.godot` nor `export_presets.cfg` sets an icon, so the six apps already export with
    the engine's, and nothing is built or changed. The manifest's `native_identity_metadata: false` and
    the builder's README line keep their meaning: the icons are not the suite's own.
- [ ] **WD-15 — Verify minimum size, 1080p, 1440p, and Windows DPI.**
  - **The part a machine can check, 2026-09-18.** The shared window profile
    disables content scaling, so an app's layout follows the real window
    size; each app's own scene already checked the 1024x640 minimum.
    `tests/test_app_window_sizes.tscn` now opens all six apps at 1024x640,
    1280x800, 1920x1080 and 2560x1440 and requires that the root fills the
    window, every visible control lies inside it and none is squeezed below
    its combined minimum size (content of scroll containers, trees, lists and
    text views excepted): 24 of 24 pass. The check has teeth: at 700x420
    every app fails it, and the profile's minimum size holds the root at
    1024x640. Local batch 122 of 122.
  - **Display ruling and unit, 2026-09-18, Core 0.345.0.** The owner asked for
    fullscreen, borderless and auto-stretch and, with the trade-offs laid
    out, chose: the Event Player only (the five editors keep reflowing, which
    is what gives them working area on a large monitor, and take a DPI
    factor instead); windowed stretch keeps the 16:10 aspect with black bars;
    borderless fullscreen stretches the content to the screen as it is,
    aspect not kept (chosen over expanding the layout, accepting the spread of
    text and the 640x400 frame on 16:9); windowed and borderless fullscreen
    only, F11 and Alt+Enter, remembered per app, no exclusive fullscreen
    because the apps open each other and their dialogs.
    `tools/content_suite/tool_window_display.gd` implements the player's
    modes and `ContentToolWindowProfile` the DPI factor (`scale_for_dpi`,
    scaled minimum and initial size, re-applied when the window changes
    screen). `tests/test_app_window_sizes` now expects the player's 1280x800
    canvas at every size and lays the five reflowing apps out at factors
    1.25, 1.5 and 2.0 as well. Verified 2026-09-18: `tests/test_tool_window_display.tscn` (31 checks), the Event Player scene (1,288, with the toggle, F11, Alt+Enter and a scratch config), `tests/test_app_window_sizes.tscn` (54: four sizes for six apps and three DPI factors for the five reflowing apps), the Launcher scene (41), the local batch (124 checks), and the original `selection handoff` and `Event Player EVENTB03 zero-state choice analysis` checks; a probe showed one `dpi_changed` connection after three applies and the factor re-applied when the signal fires.
  - Still open, and not a machine's to close: how the stretched player and
    the scaled editors look on real monitors, above all on a display scaled
    above 100%, which the development machine (2560x1440 and 1920x1080 at
    100%) cannot show. That check is MV-06.
- [x] **WD-16 — Verify large-ARC streaming, memory bounds, and cancellation.**
  Closed 2026-09-18 at Core 0.343.0. Measured first on the three largest original
  archives, every operation the tools offer:

  | Archive | Entries | Size | Open | Fingerprint | Self comparison | Extract all | Same-size copy | Repacked copy | Peak static memory |
  |---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
  | `bgm.arc` | 52 | 470 MiB | 0.0 s | 0.9 s | 2.8 s | 2.3 s | 2.2 s | 2.4 s | 64 MiB |
  | `mmo.arc` | 1,727 | 400 MiB | 0.0 s | 0.8 s | 2.4 s | 10.5 s | 1.8 s | 2.0 s | 51 MiB |
  | `voice.arc` | 15,438 | 496 MiB | 0.1 s | 0.9 s | 3.5 s | 63.3 s | 2.5 s | 3.0 s | 159 MiB |

  Streaming and the memory bound already held: the largest single entry is
  19 MiB, nothing grows with the archive beyond the entry rows, and every
  operation but one ends within four seconds. The exception was the
  file-writing loop of the batch extraction - a minute for `voice.arc` on the
  main thread with no progress and no way to stop (preparation, resolving
  15,438 entries and checking their destinations, takes 0.3 s and stays
  synchronous). `KakyuArcBatchExtraction` is now a stepped job (`begin`,
  `step(budget_msec)`, `progress`, `cancel`, `is_done`, `result`); the static
  `extract_entries` and `extract_archive` run the same job to the end with
  unchanged results, so the CLI is as before. The ARC Browser and the Audio
  ARC Editor drive the job from `_process` with a 12 ms budget, show a
  progress bar and `Cancel extraction` on a row that exists only while a job
  runs, refuse a second extraction and whatever would close or replace the
  resolver the job reads through (opening another archive, raw staging and
  overlay export in the browser; reopening and changing the overlay read
  layer in the audio editor), and cancel on close. Cancelling removes exactly
  the files the job created, the rollback a failing entry already used. No
  threads. The ARC writer and the comparison keep running to the end: two to
  four seconds on the largest archives. Verified 2026-09-18: the batch extraction (48 checks), ARC Browser (97), Audio ARC Editor (111) and overlay (118) scenes, the local batch (119 checks), and on the real archives the `original ARC Browser original integration` check - a whole-archive job on `voice.arc` cancelled after 305 entries leaves no file, `bgm.arc` extracted by steps yields 52 entries with every SHA-256 equal to the reader's, peak static memory grew by 20 MiB against a 128 MiB bound, both source hashes unchanged - together with the unchanged `original Audio Editor original integration` check; the CLI extracts three real `mes.arc` entries (94,311 bytes) as before.
- [x] **WD-17 — Verify crash recovery and true multi-process publication.**
  Closed 2026-09-18 at Core 0.344.0, and the verification found a real defect
  first. The overlay layer's lock test used one real holder process, but the
  holder was always a child of the test, and its crash case was fabricated by
  hand; nothing drove the composed workspace (workspace, project and manifest
  locks, manifest revision, content-addressed payloads) from processes that
  are strangers to each other. `tests/test_workspace_multiprocess.tscn` with
  `tests/helpers/workspace_publication_worker.gd` does: four concurrent
  publishers on four entries, two on one entry, a stale in-process workspace
  publishing after them, a really killed holder with its locks and
  temporaries on disk, a live holder refused from the parent, and a live
  holder respected by a sibling publisher that then recovers once the holder
  is killed.

  **The defect: `OS.is_process_running` answers only for children of the
  caller.** For a live process started by anyone else it returns false
  (reproduced: a sleeping Godot process, asked about by an unrelated one,
  reads as not running while `tasklist` lists it). `publication_lock.gd`
  used that call to decide whether a lock's owner was dead, so every
  publisher read every other tool's live lock as abandoned and stole it.
  Measured on the lock alone, four racing processes violated mutual
  exclusion in 5 of 20 acquisitions, two holding the lock at once; on a real
  workspace, publishers reported failure after a write that had succeeded
  ("ownership changed before release"), and one run lost a record outright:
  three of four workers reported success, the fourth gave up on
  `Could not create publication lock (error 32)`, and the manifest held three
  replacements. The existing tests could not see it because a test's holder
  is its own child, the one case the engine call answers. The same call
  decided whether an abandoned manifest, payload or project temporary could
  be deleted.

  The fix: `content_core/process_liveness.gd` (`KakyuProcessLiveness`) asks
  the operating system - `tasklist /FI "PID eq n" /FO CSV /NH` on Windows,
  `/proc/<pid>` or `ps -p` elsewhere - after the cheap answers (own id,
  a known child), compares the image name the owner record now stores so a
  reused id is not mistaken for the owner, and answers "running" whenever
  the question cannot be decided: a lock held a little too long is a retry,
  a stolen live lock is lost work. The lock, the overlay package's and the
  project's temporary cleanup use it. The lock also retries its directory
  create briefly when another process is removing the directory at that
  instant, and its two transient refusals now say "retry", so a caller that
  retries on the wording does not give up on a lock changing hands. The
  owner record gains `image`; older records without it fall back to the id
  alone, and the lock schema string is unchanged because every reader
  ignores fields it does not know. The sibling phase fails on the old code
  (the waiting publisher steals both locks within two seconds) and passes on
  the new. Verified 2026-09-18: `tests/test_workspace_multiprocess.tscn` (51 checks) ten times in a row with real contention each time (about ten attempts for four publishers), `tests/test_process_liveness.tscn` (13 checks, two stranger processes), the lock, project and workspace scenes unchanged, the local batch (121 checks), and the ten original checks that publish into a workspace or read one - the four contextual authoring checks, package export and playback, and the MES Editor, ARC Browser, Audio Editor and selection handoff integrations - 10 of 10 in 724 seconds.

  **Follow-up the same day, Core 0.346.0: the lock under full CPU load.**
  One run of the multi-process scene failed inside another unit's batch. It
  was not dismissed as timing: with every core busy the scene failed 17 of
  22 times, with publishers reporting `Could not release publication lock
  (error 1)`, `ownership changed before release`, two processes inside the
  manifest transaction and missing records. Instrumenting the takeover showed
  three defects, all in `publication_lock.gd`:
  1. **A judgement applied to the wrong owner.** Asking the operating system
     whether owner A is alive takes a second or two under load; meanwhile A
     releases and exits and C takes the same lock name, and "A is dead" - true
     - was then used to take C's live lock. The takeover now re-reads the
     owner record and requires the judged token immediately before the rename,
     checks the record inside the quarantined directory after it and puts a
     directory with another token back under its name; and a record younger
     than three seconds is respected without asking at all, because a normal
     hold is far shorter than the question.
  2. **Release in two steps.** The holder deleted `owner.json` and then
     removed the directory; a contender probing the directory in between could
     refuse the removal, leaving an ownerless lock directory that everyone
     else read as a crash inside its grace period. Release is now one rename
     to a retired name (retried briefly), so the lock name is free at once
     and never exists without its owner record.
  3. **An unreadable age read as old.** A lock directory whose modified time
     could not be read fell through to the takeover; it is now treated as
     inside the grace period.
  Transient refusals (`Could not write publication lock owner`) now say
  "retry". `tests/test_publication_lock_rules.tscn` fixes the rules without
  processes (a young record of a dead process is respected, an old one is
  recovered, an old record of a live process is respected, an ownerless
  directory waits, release leaves nothing behind and refuses a replaced
  record). Verified 2026-09-18: with every core busy the multi-process scene passed 28 of 28 runs (17 of 22 failed before), `tests/test_publication_lock_rules.tscn` (12 checks), the lock, project, workspace and liveness scenes unchanged, the local batch (124 checks), and the ten original checks that publish into a workspace or read one plus an Event Player check, 11 of 11.

  What stays as it was: a holder that hangs without dying keeps its lock
  until someone ends it - there is no lease or heartbeat - and the narrow
  existence-check-to-rename race of the content-addressed payloads recorded
  in `content_tools.md` is unchanged. A takeover that catches a live lock in
  the instant between its last check and the rename and cannot put it back
  (the name was retaken meanwhile) would still end in a refused release for
  the victim; no run has shown it.
- [x] **WD-18 — Run the complete caller-derived Event Catalog regression.**
  Closed 2026-09-19 at Core 0.350.0: the whole-tree batch with the archives and
  the original executable ran detached on the committed tree `28dff38`.
  372 checks, 372 passed, 0 failed, 7,989 s (report schema `kakyu_content_tools_validation/v3`, run `5d44ef6a`): 129 Godot scenes, the project parse check, the Python regression suite (1,663 tests over nine shards) and 241 checks against the original archives and `AI5WIN.original.exe` - the 140 `original event analysis` group checks, 17 original Event Player integration and preset checks, the exhaustive MES entry audit (`original MES analyzer handoff corpus`, 686 s), the full Python Phase 1-4 handoff equivalence (1,196 s), the corpora, contracts and source matrices, the 12 native executable checks and the native voice payload check. Nothing needed re-baselining: the two native checks the 0.318.0 run corrected pass as recorded. This is the first whole batch since 0.318.0 (2026-09-14); the batch grew from 328 to 372 checks meanwhile (a check per analysis group and the archive-authoring, workspace and display checks of 0.319.0-0.350.0). The record and any re-baselining live under EP-05 and the
  TODO gate paragraph.
  - Owned by `event_player.md` **EP-05**; this is the distribution-side
    dependency on it, not a second copy. Legacy P9-06 belongs to EP-05.
- [ ] **WD-19 — Build and run the accumulated visual/audio/original-engine batch.**
  - **Built 2026-09-19.** The batch is the run sheet "Batch of 2026-09-19" in
    `todo/manual_verification.md`: six numbered checks over MV-04, MV-05,
    MV-06, MV-09's remaining controls and MV-11, on the six release apps
    rebuilt at Core 0.350.0 (`analysis/windows-suite-0350-20260919/` (931 inventoried files, distribution fingerprint `fd9085a06370021e8e0ae89e0adb2b74d6d720918398de8df669911d1e1fc16e`, all six apps verified at `0.350.0.0`, built in 49 s from the pinned 2026-09-08 dependencies; the 264 files added since the 0.344.0 build are the v4 event definitions, the contract fixtures and the definition tools).). The run is the owner's, at a time
    of their choosing; MV-01..03 stay deferred by stance and MV-07 is WD-20.
  - **Rebuilt 2026-10-11 at Core 0.378.0**, after the 0.356.0 (2026-09-21) and 0.362.0 (2026-09-24) rebuilds:
    `analysis/windows-suite-0378-20261011/` (2,788 inventoried files, distribution fingerprint
    `0740e55ece8b65e842417af0c9d939e5c5d2459ecea46f67c6f3e37e4c05bd24`, all six apps verified at `0.378.0.0` from the
    pinned 2026-09-08 dependencies; the build command took 143.6 s; `--verify` reproduces the fingerprint and the count;
    `tests/test_windows_distribution.py` and `tests/test_windows_pe_version.py` pass). The sheet is the one in
    `todo/manual_verification.md` and gains item 9 (EP-14's library pictures and sound effects); the 0.350.0, 0.356.0
    and 0.362.0 builds are superseded and the sheet is ready for the owner. **The release was built with a separately
    obtained Godot 4.7-stable editor**, because the builder requires `4.7.stable` and this machine's validation Godot is
    4.7.2: the validation batch runs 4.7.2 while the release is 4.7-stable. That is a fact recorded for the owner; no
    ruling was taken on it, and neither the builder nor the lock changed.
- [x] **WD-20 — Verify portable packages in a clean Windows environment.**
  **Closed 2026-10-09 by owner ruling, unverified.** The owner closed the item for now. No
  clean-Windows run was made and none is claimed: the development-machine headless checks remain the
  only evidence, and the distribution manifest keeps `clean_machine_verified: false`. Reopen it when a
  clean environment becomes available. MV-07 closes with it.
  - Use an available clean machine or other license-independent disposable
    local-copy workflow. No license-specific optional OS virtualization feature
    is a required verification path.
  - Deferred by the owner's ruling of 2026-09-17 and reaffirmed on
    2026-09-20 (option 2 of two): no clean environment is available, so the
    item waits for one. The build it would verify is the Core 0.378.0
    distribution of WD-19's sheet (`analysis/windows-suite-0378-20261011/`,
    rebuilt 2026-10-11 after EP-14; the 0.350.0, 0.356.0 and 0.362.0 builds
    are superseded).
- [ ] **WD-25 — Prepare the repository for public release.**
  Opened 2026-10-11 by the owner. The GitHub repository was public from its creation (2026-09-12); an
  audit before publicizing it (2026-10-11, tree `ac59510c`) found no tracked original media or archive;
  what it found to settle was the native executable audits, whose data derives from the user-owned
  original executable (items 1 and 7). Two of its first readings were wrong: "no tracked file with
  Japanese text" (the measurement of 2026-10-12 found Japanese characters in 30 tracked files, nearly
  all tool-authored; item 1b held the original text among them) and "machine paths only under the
  ignored `.agents/local/`" (the privacy check of 2026-10-12 found two more: a drive-letter path into a
  user profile in a test and one in a document, both removed, with the owner's user name in the test;
  `tests/test_no_personal_data.py` keeps them out). The owner made the repository
  private while this item is worked. The decisions (D1-D6 below) are the owner's; nothing here is
  published, made public again or force-pushed without the owner's explicit approval. While the
  repository is private, a consumer that fetches it from GitHub cannot; how `kakyu-remake` reads the
  shared contracts is its own arrangement.
  - [x] **1. No original executable bytes in tracked files** (closed 2026-10-12, owner 2026-10-11).
    `config/ai5_exe_audit/expected_bytes_v1.json` held 696 `{address, bytes}` entries of the original
    executable's code (about 41 KB as hex; 694 verbatim spans at the inventory's measure), and
    `tools/audit_ai5_mes_exe.py` and `tools/audit_ai5_audio_exe.py` carried hex literals of 50 bytes or
    more (first read as about 1.3 KB; the closure below has the measured figures); the file also ships in
    the release build's
    `runtime/config/`. Replace them with what the native audits need (each span's identity, such as its
    address, length and SHA-256, its content read from the user's own executable at run time) as a new
    schema version, the audits' verdicts proven identical on the user's executable, and decide by
    measurement which shorter byte patterns may stay. Spec: `analysis/_docs/exe_bytes_spec.md`.
    - **Closure (2026-10-12)**, commits `2621d0ac` (spans, the Python suite's optional executable, the
      test-side reader), `2bcabd69` (the MES audit), `731189e0` (the ARC and audio audits, the guard,
      `--measure-span`), `a22c1648` (the documents); item 1b's `8f13a7ae` tightened the guard's ASCII
      class and the C5 commit aligned its extraction.
      - *The inventory, corrected:* **1,143 verbatim spans, 69,652 bytes, in four files**
        (`config/ai5_exe_audit/expected_bytes_v1.json` 694, `tools/audit_ai5_mes_exe.py` 405,
        `tools/audit_ai5_audio_exe.py` 32, `tools/audit_ai5_arc_exe.py` 12). "About 1.3 KB" was the
        single-line count; the multi-line implicitly concatenated literals hold most of it. No span lies
        outside the four files.
      - *The rule:* no tracked file holds a region of the original executable, whatever its length; every
        expectation is an address plus a `ByteSpan(length, sha256)` whose content is read from the
        user's executable at run time. What stays, by measured decision: ASCII identifier strings,
        generic opcode templates of seven bytes or fewer inside functions, test-authored synthetic bytes
        (eight or more carry a synthetic immediate) and numeric facts (`docs/spec/tech/tooling.md`).
      - *The data:* `expected_bytes_v2.json`, schema `kakyu_ai5_mes_exe_expected_bytes/v2`, pinned by
        `EXPECTED_BYTES_DATA_SHA256` `177b04ad2b4845d9ec1e9e6229b0a656f72e067cd3b4618608d348a00f4a98f3`;
        v1 is deleted and refused by schema.
      - *The equivalence proof, on the user's executable:* the 16 native-executable commands give
        byte-identical outputs, the 54 span-table digests are unchanged and the 4 fixture hashes are
        unchanged.
      - *The guard and its gate:* `tests/test_no_original_executable_bytes.py` (Part A local, Part B with
        `KAKYU_ORIGINAL_EXE`) finds 0; **299** Python tests (not 294) skip without the executable. Its
        ASCII class was tightened by item 1b (NUL only as trailing padding; the exemptions are
        unchanged, none lost), and it now reads composed hex strings as the archive guard does.
      - *What is left:* item 2 (the rebuild: the 0.378.0 build still ships v1), item 5 (the history) and
        item 7a's flags (run both byte guards and the privacy guard on the snapshot).
  - [x] **1b. No original MES archive content in tracked files** (closed 2026-10-12; owner 2026-10-12:
    opened, threshold 8 bytes, before going public). The read-only measurement of 2026-10-12
    (`analysis/_docs/archive_literals_inventory.py`; `mes.arc`'s 1,016 entries, `data.arc`'s 867 and the
    media archives' stored form) found no original message text in any literal and no media content, but:
    one original 6-character MES menu label (5 occurrences: a tool's search key, three lines of a
    document and one of `tools/README.md`), and short MES opcode records of 8 bytes or more held by few
    entries (nearly all in test fixtures; a few functional signatures in tools and two record examples in
    a document). The label became a length and SHA-256 match and the documents describe it; each record
    became synthetic (an operand the test does not depend on changed) or, for a tool's signature, a
    length and hash or a record built from named grammar constants; a guard over `mes.arc` and
    `data.arc`, gated on the user's archives, keeps them out. The README notice's "no scripts, text"
    sentence is true now.
    - **Closure (2026-10-12)**, commits `8f13a7ae` (C1a: the shared literal helper, the ASCII class),
      `84e3edfa` (C1b: the privacy fixes and guard), `f0a6af03` and `c308d4dd` (C2: the GDScript
      fixtures), `9e7925a4` (C3: the Python fixtures, the label, the tools, the document examples),
      `150b6cf7` (C4: the archive guard and the batch plumbing), `ca094c20` (C4 follow-up: the authoring
      workflow fixture) and the C5 commit (these records).
      - *The measurement, corrected twice:* the first count, "91 records held by 1-9 entries", was an
        overcount - the holder count was capped at 400 positions per window, so a frequent run looked
        rare; an exact recount found 29 of the 91 rows (9 runs) held by 788-951 entries (the protagonist
        name insertion in 948, the voice-bit records in 788-822, two short sequences in 925 and 951).
        The window rule at bar 100 with the text form measured **88 findings in 38 files (85 byte and 3
        text, the label, held by 97 entries)**, none in `content_core/` or the four Phase 1-4 analyzer
        modules. The first reading "no tracked file with Japanese text" was also wrong (30 files, nearly
        all tool-authored).
      - *The rule (the 1b spec's D1):* no tracked file holds an 8-byte window (4 Japanese characters, encoded to cp932)
        that 1-99 entries of `mes.arc` or `data.arc` hold, except where its interval is a chance class
        (printable ASCII with NUL only as trailing padding, fewer than 5 distinct values, a small-integer
        progression). Windows held by 100 or more entries are the format's command encoding and may stay.
        **That bar is a tool decision, not a fact about authorship;** its measured basis is that today's
        idioms are held by 78-94% of the entries, so it removes nothing a script in this format must
        write, and it sits above the records a family of related scripts shares. If the owner wants the
        bar higher or the class gone, the decoders could not recognise a name insertion.
      - *The treatments as landed (88 findings):* **S 73** (50 GDScript and 23 Python rows: a synthetic
        operand with only the tied expected value moved), **T 3** (the label, by length and SHA-256 of its
        cp932 bytes, no raw-byte pre-filter; the same output on the original, 13 s against 11 s),
        **H 1** (`validate_mes_bgm_route.gd`, by length and SHA-256), **D 2** (a document example and a
        comment, in words) and **G 9 rows**, which are **4 record families / 5 byte forms** - under the
        owner's ruling of 2026-10-12 (G only for a grammar-only record, counted by distinct record, cap 5;
        the unit spec had expected 1 and stopped at more than 3), the strict count is 4 families under the
        cap and 5 byte forms at it. A G record is built once from named grammar constants
        (`tests/mes_record_grammar.gd`, decoded by the scene `test_mes_record_grammar`;
        `tools/payload_values.py`, decoded by `test_payload_values`), only where no byte can change
        without naming another engine function or record or breaking its decoding; the guard cannot see
        it, so it is a recorded exception, never an allowlist:
        1. *the map-location poll `Util(6,13)`* - command `0x12`, expression-record tag, `0xFF`, list end,
           module 6, function 13; fixed by the drafter's search (`tools/draft_event_route_spec.py`:
           the same eight bytes as before, 14 entries and 33 occurrences in `mes.arc`) and by the
           analysis-group contract (`poll_function [6,13]`); sites: `test_mes_event_runner.gd`,
           `test_mes_route_probe_definitions.gd`, the drafter, `test_event_route_tools.py`,
           `test_event_analysis_group.py` (the Core runner matches a contract by `poll_offset` alone, so
           the two scenes do not pin the function byte; the Python consumers do);
        2. *the routine-40 selection `Util(1,21,x)`* (two byte forms: the literal 0 and `state_u16[21]`
           as the last argument) - fixed by the exact signature `tools/audit_mes_runtime_trace_terminal.py` checks;
           site: `test_audit_mes_runtime_trace_terminal.py`;
        3. *the START bootstrap calendar fill* - command `0x06`, token `0x80`, `state_u16[8]`, bank 0,
           the sentinel, continuation 0; fixed by `content_core/mes_calendar_state.gd`
           (`_matches_fill_write`); site: `test_mes_calendar_state.gd`;
        4. *the script-execution marker head of selector 3* with its name terminator and list end; fixed
           by the inline-script decoder and the analysis index; site: `test_mes_analysis_index.gd`.
        The public tree carries these record forms by construction: the poll is held by 14 original
        entries and the others by 1-2.
      - *The proof (the 1b spec's D8):* assertion-call counts are unchanged in every changed file; each changed fixture
        keeps its instruction kinds, except these recorded exceptions (the moved offsets and indices were
        listed in the unit record): **length** `tests/test_event_player.gd:1139,2118`,
        `tests/test_authored_mod_delta.py:146`, `tests/test_mes_authoring_workflow.py:271` (and the
        authoring workflow scene's choice fixture, a lengthened label); **reorder**
        `test_event_player.gd:2118`, `test_mes_event_runner.gd:435,1403`; **one inserted no-op
        source-line marker** `test_mes_event_runner.gd:435` (and one before the registered-call
        registry payload in `test_mes_authoring_workflow.gd`). The mutation protocol (re-mutating an
        operand fails where an asserted value moved, passes where it is free; a pinned byte fails) ran
        for every changed row. Some fixtures pin no byte (the control-target compile-reopen literal,
        three authoring-workflow rows of the base scene, the parity fixtures of
        `test_mes_instruction_ir.py`); each is recorded as such.
      - *The tools:* the label tool, the surface-dispatch check and the drafter give the output they gave
        before (the label tool's stdout modulo its output file name, stderr, exit code and output hash;
        the drafter's listing); the BGM validator gives the same failure as its baseline (exit code 1 at
        the dialogue-boundary step; a mutated digest fails at the prelude step instead, so the hash
        comparison is exercised).
      - *The guard (the 1b spec's D5):* `tests/test_no_original_archive_bytes.py` reads the archives from
        `KAKYU_MES_ARC` and `KAKYU_DATA_ARC` (both required, `tests/original_archives.py`) and scans
        `tools/`, `tests/`, `content_core/`, `docs/`, `config/` and the root `*.md` files in about 31 s
        (budget 90 s) for 0 byte and 0 text findings; on a worktree at `77354fc8` it reports the C0
        figures, 88 (85 + 3) in 38 files. Base64 strings and tracked binary files are outside it (the
        author's companion inventory covers them and found nothing); `docs/` lies outside the suite's
        fingerprint roots. The Python suite takes `--mes-arc/--data-arc` and the batch passes them with
        `--elfimage` (`docs/spec/data/validation_checks.md`).
      - *The privacy checkpoint (the 1b spec's D7):* `tests/test_launch_detached.py` used the owner's user name in a
        profile path and `docs/spec/mes/promise_groups.md` carried a drive-letter path; both are fixed,
        and `tests/test_no_personal_data.py` (profile paths, machine paths outside the tests, the user
        name and the git address read at run time, e-mail addresses; the no-reply addresses allowed)
        keeps them out.
      - *The closing runs:* the uncached merged batch for items 1 and 1b at `150b6cf7`
        (`--elfimage --exe --jobs 6 --cache-store`, detached): **478 of 480 in 2,591.6 s**, `cached: 0`;
        the two failures were `test_mes_registered_call_authoring` and `test_mes_choice_authoring`,
        scenes that share `tests/test_mes_authoring_workflow.gd`, whose registered-call and choice modes
        two of this unit's fixture edits had broken (an operand edit of a registry header and of a branch
        constant the choice prover pins). Fixed in `ca094c20` (the unit's lesson: run every scene that
        shares a changed fixture file); the nine authoring scenes pass at their baseline pass counts. The
        Python suite in that batch and alone: 2,630 tests, 4 skipped with the executable and both
        archives, 304 skipped without them (4 + 299 + the guard's Part B).
        **The cached full tier at the C5 commit `53a86f6d`** (`--tier full --jobs 6 --cached --cache-store`
        with `--elfimage` and `--exe`; run `05c0ccb0`): **480 of 480 passed, 465 cached, 502.1 s** - the
        15 that ran were the Python suite, the parse check, the nine authoring scenes and the four
        contextual-authoring checks, as their fingerprints predicted.
      - *Left open, outside this item:* the pre-existing defects found on the way are items of
        `todo/code_health.md` (TD-68 to TD-73).
  - [ ] **2. Rebuild the release suite** without the v1 file: WD-19's build of 2026-10-11 ships it. No
    binary is published (D4, source only), so this is the private builds' hygiene and is not a
    condition of going public; the next WD-19 rebuild takes it.
  - [ ] **3. A license** (D1, **owner 2026-10-11: viewing only**). No LICENSE file; the README states all
    rights reserved and grants no license to use, copy, modify or redistribute, beyond what GitHub's Terms
    of Service allow for viewing and forking on GitHub. Third-party licenses already ship with the build
    (Godot, Python, Pillow).
  - [ ] **4. A README notice** (D5, **owner 2026-10-11: as drafted, non-commercial stated, removal
    requests through the repository's issues, English only**). The notice, added to the public
    snapshot's README at 7a, once item 1 makes its "no program code" sentence true:

    > Kakyu Mod Tools is an unofficial, non-commercial fan project. It is not affiliated with,
    > endorsed by, or sponsored by the rights holders of *Kakyūsei* or its engine. All product names
    > and trademarks belong to their respective owners.
    >
    > - **You need your own copy.** The tools read the original archives of a legally obtained copy of
    >   the game that you own, and never modify them.
    > - **No game data is included.** This repository and its builds contain no original game data: no
    >   images, audio, scripts, text or program code from the original. Analysis output that could
    >   contain original content stays on your machine and is excluded from version control.
    > - **All rights reserved.** The source is published for viewing only. No license is granted to
    >   use, copy, modify or redistribute it, beyond what GitHub's Terms of Service allow for viewing
    >   and forking on GitHub. Third-party components in the builds (Godot Engine, Python, Pillow) keep
    >   their own licenses, which ship with the builds.
    > - **No warranty.** The software is provided as is, without warranty of any kind.
    > - **Removal requests.** If you hold rights in the original and want any part of this project
    >   changed or removed, please open an issue on this repository. Requests are answered promptly.
  - [ ] **5. The history** (D2, **owner 2026-10-11: a fresh public repository**). The history is not
    rewritten: a rewrite in place would change all 600 commit ids the trackers and documents cite (374
    backticked 7-8 digit hex ids at `ac59510c`, some of them package hashes). So this repository stays
    private with its whole history, renamed first
    (proposed `kakyu-mod-tools-dev`; the local remote follows), and a new public repository named
    `kakyu-mod-tools` starts from a cleaned snapshot. The owner creates and renames the repositories on
    GitHub; nothing is pushed to the public one without the owner's approval.
  - [ ] **6. The author e-mail** (D3, **owner 2026-10-11: no-reply on the public side**). Every commit
    here carries the owner's personal address, which a public repository exposes. The public
    repository's commits use the owner's GitHub no-reply address,
    `10555846+naknaknak@users.noreply.github.com` (given 2026-10-11); this repository keeps its address.
  - [ ] **7. What is public** (D4, **owner 2026-10-11: the tree without the native executable audits**).
    The public snapshot leaves out the three audit tools (`tools/audit_ai5_mes_exe.py`,
    `tools/audit_ai5_audio_exe.py`, `tools/audit_ai5_arc_exe.py`), their tests and
    `config/ai5_exe_audit/`; the documents stay, including the executable-derived evidence (addresses
    and behaviour) in 18 of them. Analysing the program and passing on what it yields is the most
    sensitive part (the Korean Copyright Act's Article 101-4 limits disclosing information obtained by
    program-code analysis to interoperability), so the tools that do it stay private. **Source only**
    (owner 2026-10-11): no Windows build is published.
    *Realised by the exclusion list of item 7a (built and proven; not yet public).*
  - [x] **7a. The public snapshot** (follows D2 and D4; closed 2026-10-12 as a procedure: **the snapshot
    is built and proven and awaits the owner's approval; nothing is pushed**). A reproducible way to make
    the public tree from this one - the exclusion list, the validation registry and the tests consistent
    without the excluded files (no entry or test naming a missing file), links into excluded files
    resolved, the README notice, one squashed commit by the no-reply author - and how later updates reach
    it. The unit's spec is `analysis/_docs/public_snapshot_spec.md` (v2: the advisor's pre-review R1-R4
    and the owner's ruling Q1 folded in).
      - *The procedure:* `tools/build_public_snapshot.py --source-commit <commit> --output <dir>
        [--init] [--commit] [--date YYYY-MM-DD]` (its module docstring is the usage; `--dry-run` runs
        every check and writes nothing). It reads the tree of the commit with `git archive`, never the
        working tree, so an untracked or ignored file cannot enter; recomputes the import closure of the
        three native audits (a module name resolves to a tracked path first, so `tests.test_x` is
        `tests/test_x.py`, then by bare stem) and refuses to build if it differs from the data's
        `closure_expected`; drops the excluded files; filters the validation registry (an entry is dropped
        when its script, arguments or name name an excluded path; the runner then validates the result
        as usual, so no fail-closed check is bypassed; the serialisation round-trips the tracked file
        byte for byte, checked on every build); inserts the README notice after the first heading;
        syncs, stages and proves content identity. The snapshot lives in its own directory outside this
        checkout, a fresh git repository whose only remote is the public one; the builder refuses an
        output tied to this checkout (inside it, around it, or sharing its object store), a private
        remote naming the public repository, a foreign remote or author in the output, a stray file,
        and an unchanged tree. It commits as `naknaknak` with the no-reply address, UTC dates and the
        message `Source snapshot <date>` (no private commit id). It never pushes; the public remote is
        never added to this repository. Later releases are new snapshot commits on top of the public
        history, built from a new private commit (spec D6), never fetched or merged from this
        repository. The manifest of what was left out is private (`analysis/_undoc/public_snapshot/`,
        ignored).
      - *The exclusion data:* `config/public_snapshot/exclusions_v1.json`
        (`kakyu_public_snapshot_exclusions/v1`), SHA-256 `eceea5baf0f323c0643b5f741de664beb12d13dfef91df0e006cebb58c272926`
        at `5fe4c96f` (a regeneration of the same shape stays in place; the earlier 41-file revision
        was `025b45cd...`). **42 files out:** 17 tools (the three audits and 14 that import them,
        directly or through another), 19 tests, 1 data file (`config/ai5_exe_audit/expected_bytes_v2.json`)
        and 5 snapshot-tooling files (the builder, its test, the exclusion data, the notice source and
        `docs/development_setup.md`); **11 registry entries dropped** (the native ARC, MES and Ogg voice
        contracts, the logical truth, EVENTB03 camera and SE, calendar state-layout, promise
        calendar-field, host-activation slice, promise location-route and PROMIS caller/native checks);
        **3,973 files in**. The closure goes beyond D4's three tools because 14 tools import them; two
        parity tests (`test_mes_handoff_equivalence`, `test_mes_full_handoff_equivalence`) imported the
        audio audit's archive helper and were switched to `tests.test_extract_kakyu_arc`, which writes the
        same ARC layout, so they stay public. `tools/audit_unreferenced_entries.py` and its check stay
        public by the owner's ruling (Q1, 2026-10-12): it reads the executable only for name presence and
        a hash.
      - *The tolerant tests (spec D4, C1 and C3):* five test files were made tolerant of a missing
        audit; each still asserts in full in this repository, where every script exists: the registry
        placeholder test
        (`se_arc` and `voice_arc` may go unused only when the script that needs them is absent);
        `tests/test_run_headless_validation.py` (the assertions about the 11 dropped checks, the
        voice-archive test, and - found by the snapshot's own suite - the coverage test's
        `native_corpus` and `voice_payload` groups); the executable-guard test that asserted an audit in
        the scanned list; and the two parity tests' import. More than 10 such tests would have stopped
        the unit; one was found beyond the spec's list.
      - *The README move (owner, 2026-10-12, Q1):* the two sections of `README.md` about the agent setup
        and about resuming interrupted work moved verbatim to `docs/development_setup.md`, which the
        snapshot leaves out; the public README keeps one line saying the project is developed with AI
        agents and that `AGENTS.md` holds the rules, with no link to the excluded document
        (`tests/test_build_public_snapshot.py` pins both). `AGENTS.md`, `TODO.md` and `todo/` stay public
        as they are (owner, Q2); their commit ids do not resolve in the public repository, which the
        snapshot README states in one sentence after the notice.
      - *The proof, measured on the build from `c954c541`* (41 files out then; the README move has since
        made it 42 out and 3,973 in, and the snapshot is rebuilt from the records commit and this proof
        run again there before the owner is asked): the Godot project parse check passed; the Python
        suite without the originals passed, **2,175 tests, 7 skipped** (this repository, with the
        executable and both archives: 2,664 tests, 4 skipped); the local tier, uncached
        (`--tier local --jobs 6 --cache-store`), **142 of 142 passed in 99 s**; the three guards, with the
        originals through the environment, found 0 (**11, 9 and 17 tests**, none skipped); the relative
        Markdown links resolved against `git ls-files` leave **47 unresolved targets, the same 47 as in
        this tree** (none added); content identity: **0 differences** in the other 3,971 files (only
        `README.md` and the filtered registry differ); and the pre-push gate's items 1-8 (spec D8: the
        remote, the identity, the message, the file set with content identity, the guards, the privacy
        probe, the run-time personal-value grep over the working tree and `git log -p` with 0 findings,
        and this proof) were true on that build: the advisor ran the items that can be run read-only, and
        the proof item is this bullet's own figures. The builder's test (34 cases) is part of this
        repository's Python suite.
      - *Release log* (source commit -> snapshot tree id -> public commit id):
        1. first release: built from the records commit of this unit (the commit that holds this
           line); the tree id and the public commit id are recorded after the push.
      - **The cached full tier at the records commit `b7a4c021`** (`--tier full --jobs 6 --cached --cache-store`
        with `--elfimage` and `--exe`; run `7be56370`): **480 of 480 passed, 479 cached, 265.5 s** - the Python
        suite re-ran (the builder test and the exclusion data are in its fingerprint roots).
      - *Left open, not closed by this item:* the owner's approval of the snapshot (spec D8.9) and the
        push, items 5, 6 and 8 with them. **Residual, found by the advisor's review:** the closure is
        seed-based, so a future tool that reads the executable without importing the three seeds would
        be public by default. A later gate line closes it: every kept file naming `--exe`,
        `KAKYU_ORIGINAL_EXE` or `original_executable` is in the data's `keep_public` or is batch
        plumbing; add it to the gate before the next release.
  - [ ] **8. When it goes public** (D6, **owner 2026-10-11: once items 1 and 7a are done**; 1b joined them
    2026-10-12), with the
    owner's approval of the snapshot before the first push.

Legacy: P9-01 through P9-08, except P9-06, which EP-05 owns.
