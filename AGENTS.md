# Kakyu Mod Tools Development Rules

This repository is **the original analyzer**. It reads user-owned original
archives, establishes what the original does, records the evidence, and authors
changed content from it.

Two things follow from `docs/spec/tech/product_roles.md`, and they are the first
thing to know here. The **original ARC/MES player is an instrument of the
analysis, not a product** - it exists so a claim about an entry can be checked by
executing it. The **mod player is `kakyu-remake`**, which consumes the playback
package this repository exports and never reads an original archive.

## Runtime

- Use Python for the authoritative Phase 1-4 analyzer without a Godot runtime
  dependency. Use Godot 4.7 stable and GDScript for the existing GDScript
  Content Core, the Content Suite applications, runtime instruments and their
  headless validators.
- Use the Compatibility renderer unless a feature requires another renderer.
- Use `640x400` as the logical coordinate system wherever a tool presents
  original content — Event Player playback, Image Editor logical placement, A6
  hit-testing. Tool chrome may use the window's own size.
- Support `1920x1080` and `2560x1440` output without changing those logical
  coordinates.
- Run Python tools from the project root with the Windows `py` launcher. Image
  tools require Pillow. Python tools default to reading a versioned handoff or
  the authoritative archive and printing a JSON report; they do not open windows.

## Source Of Truth

- What this repository is for is fixed by `docs/spec/tech/product_roles.md`.
  Read it before planning work that changes which side of the analyzer/player
  line something falls on.
- **The specifications this repository owns live in `docs/spec/`**, indexed by
  `docs/spec/index.md`. The owner ruled on 2026-09-05 that a document lives
  where its producer lives, so the MES analysis evidence, the tool and content
  boundary documents, and the data contracts `content_core/` implements are
  here. Update the related document in the same task that changes behaviour or a
  data contract.
- The mod player's game shell keeps its own specifications in
  `kakyu-remake/docs/spec/`, and so do the two documents that must not be
  duplicated: the playback package schema, which is the contract between the
  repositories, and the split plan, which is the remake's record of its own
  transformation. Reference those by path. `docs/spec/index.md` lists exactly
  what stays there and why; links into that set are cross-repository references,
  not broken links to fix.
- `TODO.md` is the repository-wide priority summary and navigation index. Phase
  definitions, gate status and execution order live in `todo/mes_pipeline.md`.
  Each detailed checkbox belongs to exactly one domain tracker under `todo/`.
  Do not duplicate detailed progress across trackers.

## Current Work Routing

- The original game is a **specification, not an execution target**. Mods run in
  the remake runtime, so do not treat original-engine execution compatibility as
  a gate, and do not block work on an unresolved native host mechanism: where
  the original's internal mechanism cannot be established, the tools define
  their own and label it a tool decision.
- Follow the maturity gates and default execution order in
  `todo/mes_pipeline.md`. The current default is the earliest open gate unless
  the user explicitly requests another area or a bounded prerequisite must be
  completed first. Later-phase prototypes do not close an earlier gate, and a
  newly discovered boundary defect may move the current focus back to the
  affected earlier phase without invalidating already verified later work.
- **A defect that prevents the validation batch from running precedes feature
  work.** Proportionate verification is required before any item can be closed,
  so anything that stops the batch blocks every other closure. Two such defects
  were closed on 2026-09-05; `todo/code_health.md` owns any that follow.
- An MES analyzer item is complete only when exact record boundaries are
  preserved, payload bytes cannot execute as shadow MES commands, and the result
  is reproducible typed IR/control flow/trace or a byte-preserving opaque
  boundary. Proportionate corpus and regression checks must pass and the related
  MES evidence must be updated. Original semantic claims remain subject to the
  source-audit rules below.
- Analyzer completion means safe and reproducible structural interpretation, not
  complete reproduction of every native engine effect. An unresolved native
  meaning may remain explicitly typed or opaque without blocking structural
  completion, but that meaning itself must not be marked confirmed.
- Keep the Phase 1-4 boundary language-neutral. **Python is the
  container/framing/typed and opaque IR authority.** MA-10 re-established
  MA-09's complete measurement over all 1,016 entries on 2026-09-06, fulfilling
  the destination decided in `docs/spec/tech/product_roles.md`. Corpus tools
  and the Phase 5 decompiler consume the versioned analyzer handoff; an
  alternate projection must prove exact boundary/schema parity before
  replacing it. Do not silently substitute an older Python projection for
  the current instruction or record-boundary schema.
  Actual Python handoffs identify `python_phase1_4`. The explicit
  `producer_implementation_only/v1` policy is for labelled comparison with the
  frozen GDScript baseline only; it changes only `producer.implementation`
  and recomputes the comparison hash. Record actual Python hashes separately.
  Keep the existing GDScript completion baseline as a historical reference
  check. GDScript instruments, CFG-spool exporters and runtime validators
  remain available in their existing paths; authority migration does not
  imply that every Godot tool has been replaced.
- Route pixel/audio effects and native cadence to `todo/presentation_audio.md`;
  event playback, catalogs, and player UI to `todo/event_player.md`; MES
  editing, relocation, and assembly to `todo/mes_authoring.md`; media editor
  authoring to `todo/media_editors.md`; workspace, packaging, and distribution
  to `todo/workspace_distribution.md`; and repository defects and structural
  debt to `todo/code_health.md`.

## Boundary With `kakyu-remake`

`kakyu-remake` is maintained separately. Do not plan, schedule, or track work in
it from here, and do not edit it. What follows is the boundary this repository
has to respect, not a shared backlog. The one scoped exception the owner
granted on 2026-09-14 - the `kakyu_event_definition/v3` agreement
(`todo/workspace_distribution.md` WD-22) - was used by the remake's adoption
commit of 2026-09-15 and closed by the owner on 2026-09-16; no exception is
open. Since that decision the shared conventions the remake consumes - the
fingerprinted JSON contracts under `config/contracts/` (the event-definition
fixture set and the event name registry) and any later one - are owned and
changed in this repository only, and the remake reads them from here; how
it reads them is its own arrangement. A change of a contract's shape (its
schema) lands as a new directory beside the old rather than an in-place
edit; a regeneration of the same shape (new rows, new aliases, a moved
fingerprint) stays in place, with the directory's README recording the
revision and the fingerprint (owner ruling of 2026-09-21, confirming the
practice of 2026-09-19 and 2026-09-21). The projected event definitions under
`config/event_definitions/` are read the same way; they reference original
dialogue through the playback package and never embed it, and
`tests/test_event_definitions_tracked.py` refuses a tracked document that
does.

- The load-bearing invariant is that **the remake never reads an original ARC or
  MES entry**. Everything it plays arrives through the playback package. That is
  what this repository's output must satisfy: a package has to carry everything
  playback needs, because the other side cannot fall back to the archive.
- The playback package is a versioned contract. This producer now emits
  `kakyu_playback_package/v7` with mapped authoring coordinates, workspace/effective identities, UTF-8 authoring, manifest-bound integrity and exact dropped
  provenance boundaries; the separately
  maintained sibling v3 specification remains a historical reference here.
  Do not claim compatibility with its v3 consumer. Both sides check schema
  version and package hash fail-closed, so a
  schema change needs a version bump rather than an in-place edit — an
  incompatible package is rejected, not silently misread.
- 52 source files also exist there, because the split copied rather than moved
  what both sides needed. The copies here are the ones this repository tests and
  ships. Treat them as ordinary files of this repository.
- `tools/content_suite/apps/event_player.gd` is this repository's alone.

## Assets

- The entire `assets/` directory is local-only and excluded from Git, along with
  `data/`, `analysis/` and `reverse_engineering/`.
- Never modify source assets outside this project, and never direct generated
  output back into an original game installation.
- Keep source archives and generated images under `assets/`, or pass an external
  source path only as read-only input.

## Reverse Engineering Sources

- Before making claims about original MES behavior, read
  `.agents/local/source_paths.md` and inspect the configured `ELFIMAGE` source
  directory.
- Treat the configured `ELFIMAGE/mes.arc` entries as the authoritative MES
  originals; generated JSON projections and extracted runtime data are
  supporting artifacts, not substitutes for checking the archive.
- Keep machine-specific absolute source paths only under `.agents/local/`. Never
  add those paths or original game data to Git.
- Personal names, e-mail addresses and drive-letter machine paths never enter
  tracked files (tests use made-up roots, and documents use the `<ELFIMAGE>`,
  `<EXE>` and `<GODOT>` placeholders); `tests/test_no_personal_data.py` enforces
  it, and its user-name and git-address rules depend on the machine it runs on.
- If the local source-path file or required archive is unavailable, state that
  the original could not be checked instead of presenting a projection as
  original-source evidence.

## MES Analysis Documentation

- In the same task that confirms a new MES format rule, opcode meaning, state
  condition, call relationship, or scene behavior, document the result under
  `docs/spec/mes/` and update `docs/spec/mes/index.md` when navigation changes.
- Organize MES findings by the consumer that uses them. Shared container,
  expression, and interpreter rules go in `docs/spec/mes/format_and_method.md`.
- Record the authoritative archive entry, code-relative offset, evidence type,
  and confidence or unresolved boundary needed to reproduce each claim.
- Do not place original dialogue, lossless bytecode, long hex dumps, archive
  payloads, or machine-specific source paths in tracked documentation.
- No tracked file holds a copy of the original executable - code, data tables or
  strings. A native audit's byte expectation is an address, a length and a
  SHA-256; its content is read from the user's own executable at run time and
  used only after the hash matches. Identifier names the documents use as
  evidence (class, file and key names) are the exception.
  `tests/test_no_original_executable_bytes.py` enforces the byte rule; a
  synthetic sequence of 8 bytes or more in a test carries a synthetic
  immediate.
- No tracked file holds an 8-byte or longer window (4 Japanese characters) of an
  original archive entry (`mes.arc`, `data.arc`) that fewer than 100 entries share,
  except the chance classes `docs/spec/tech/tooling.md` lists;
  test fixtures and text are synthetic. Windows held by 100 or more entries are
  treated as the format's command encoding - a **tool decision**, measured at
  78-94% of the entries (the protagonist-name insertion in 948, the voice-bit
  records in 788-822) - and may stay. A fixture changes an operand the test does
  not depend on, moving only the expected values tied to it; a record whose exact
  encoding is the subject and that has no free operand is built once from named
  grammar constants (`tests/mes_record_grammar.gd`, `tools/payload_values.py`), a
  recorded exception and never an allowlist. When a changed fixture file is shared
  (extended or preloaded by other scenes), run every scene that shares it.
  `tests/test_no_original_archive_bytes.py` enforces the rule when the batch passes
  `--elfimage` (it reads `KAKYU_MES_ARC` and `KAKYU_DATA_ARC`).

## MES-Anchored Routes

- Whenever feasible, every Event Player route, catalog entry and headless
  validator that represents an original scene, event, encounter, date or
  conversation begins at the confirmed MES intro caller or entry coordinate in
  the authoritative `mes.arc` entry.
- An MES intro coordinate means a code-relative caller offset or address-table
  entry offset, not a screen position, map coordinate, or generated JSON
  location.
- Trace forward from that intro anchor in original call and control-flow order
  when selecting presentation, dialogue records, choices, state conditions, and
  outro/completion behavior.
- Prefer source-offset-audited projections or runtime interpretation over
  authored substitute dialogue when the required MES path has been confirmed.
- Record the intro anchor, called MES entry, selected branch state, and
  supported/unresolved boundary in the related MES document and in the
  validator's own output.
- If no authoritative intro coordinate can be confirmed, keep the route runnable
  with an explicitly labeled placeholder, state that the original path is
  unresolved, and do not present the placeholder as MES-backed behavior.
- Tooling with no original counterpart — the launcher, editors' own UI, workspace
  management — is exempt.

## Engineering

- Prefer data-driven conditions for events, presets, schedules and routes. The
  catalog at `config/event_catalog/` is the intended mechanism; new per-event
  behavior belongs there, not in a new constant or `if event_id ==` arm. TD-04
  is the outstanding debt from not following this.
- Workspace, project, package and audit formats must be versioned and support
  migration. Check schema version and fingerprint fail-closed on both read and
  write.
- Extract a shared helper rather than copying one. TD-05 and TD-06 (closed
  2026-09-21 and 2026-09-06) took the measured copies from 583 to a
  recorded residue (112 exact-body groups, each kept for a stated reason);
  new code should not add to it. The shared homes are
  `content_core/contract_values.gd`, `tools/content_suite/cli_script.gd`,
  `tools/payload_values.py`, `tests/test_case.gd` and `tests/synthetic_arc.gd`;
  a Python tool's command-line entry is its own by convention.
- Do not add third-party plugins unless they remove a demonstrated maintenance
  burden.

## Git Workflow

- Commit each small, coherent work unit after it is completed and
  proportionately verified instead of accumulating a large batch of unrelated
  work.
- Direct commits to the default branch are allowed unless the user requests a
  separate branch.
- Before asking the user to perform GUI or UI verification, finish the relevant
  automated checks and commit the work unit; request UI verification only from
  the committed state.
- Keep unrelated pre-existing user changes out of each commit unless the user
  explicitly asks to include the entire worktree.
- Use concise commit messages that describe the completed unit.
- The public repository receives only snapshots built from this repository's
  tree, in a separate directory; its remote is never added here.

## Verification

- Parse-check the project after changes with Godot's console executable.
- Keep a runnable main scene at
  `res://tools/content_suite/apps/content_suite_launcher.tscn`, which `project.godot`
  declares.
- Run the batch from the project root:
  ```powershell
  py tools\content_suite\run_headless_validation.py `
    --elfimage "<user-owned-ELFIMAGE>" `
    --exe "<user-owned-AI5WIN.exe>" `
    --jobs 6 --cache-store
  ```
  The local synthetic suite is always available; `--elfimage` adds the read-only
  original-corpus checks and `--exe` the native executable audits. The Godot
  scenes are discovered from `tests/*.tscn`, so a new test scene joins the batch
  without an edit here. `--jobs 6` runs six independent checks at once (the
  runner's own default stays `1`, so a run the Launcher starts in the
  background does not take six cores; owner ruling of 2026-09-23 set the
  parallel batch, TD-40 measured 6 on 2026-10-03 against 5 (and the earlier
  `--jobs 4` batch on `b9fa356`): 402 of 402 in 3,980 s, no check beyond
  0.43 of its timeout, memory peak ~85% of this 16 GB machine at 5 and 6
  alike; TD-42 re-measured 6 at `7c50cdd`: 402 of 402 in 3,021 s, memory
  peak 77%, no sustained paging - `todo/code_health.md`); use
  `--tier local|archive_quick` and `--cached` for iteration.
- **A unit's closing proof may be a cached whole batch** (owner ruling of
  2026-10-03, TD-40): `--cached` over the full tier with `--elfimage` and
  `--exe` is sufficient when this machine's cache was seeded by an uncached
  run, and the report states how many checks were cached. Run the whole batch
  **uncached with `--cache-store`** (never plain uncached, so the cache and the
  longest-first ordering stay current) when the Core version, a contract or
  schema version, the Phase 1-4 analyzer, or the validation runner/cache code
  changes; when the machine or the original archive changes; and at least
  once a week. Launch any run expected to exceed a few minutes detached from
  the agent session (`tools/content_suite/launch_detached.py`, TD-40), so a
  session exit does not kill it; its report is the record.
- Verify both the original logical frame and widescreen presentation before
  completing UI work.
- Keep routine automated verification headless and non-focus-stealing.
  Accumulate checks that require opening the original engine or a Godot GUI,
  then ask the user to run or approve one documented verification batch once it
  has meaningful coverage.
- Do not use or recommend Windows Sandbox as a verification option. Use a
  license-independent disposable local-copy workflow or an available clean
  Windows environment for the relevant manual check.
