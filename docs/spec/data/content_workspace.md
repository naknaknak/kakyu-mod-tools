# Content Workspace Contract

This document defines the runtime service that composes one portable
[`project.json`](content_project.md), one content-addressed `manifest.json`, and
one user-selected read-only source content set. It does not replace either file
schema and it does not persist the machine-specific source path.

## Snapshot

`KakyuContentWorkspace` exposes a deep-copied
`kakyu_content_workspace_snapshot/v1` dictionary. Its identity is:

- the exact reopened `project.json` SHA-256;
- the exact validated `manifest.json` SHA-256;
- the project-bound source content-set fingerprint; and
- a generation SHA-256 over those three identities.

The snapshot contains the validated project and manifest documents, portable
source archive names/hashes/counts, replacement/projection/definition counts
and the workspace's `mod_id` (the one mod id its definitions share, empty
when it holds none). It never
contains the workspace directory, ELFIMAGE directory, or an absolute payload
path. Callers cannot mutate the active service by changing a returned snapshot.

## Open and Create

Open is transactional. A candidate service:

1. loads and validates `project.json`;
2. opens the selected ContentSet read-only;
3. requires its complete present-archive set and every archive SHA-256 to match
   the project source bindings;
4. loads and payload-validates `manifest.json`;
5. requires every replacement and projection to target a declared project
   archive and the exact bound original entry;
6. applies the project compatibility objective; and
7. rechecks both metadata-file hashes before publishing the snapshot.

Only full success replaces the active readers and snapshot. A failed open or
refresh retains the last valid active generation.

Create requires an absent `project.json` and `manifest.json`, a revision-1
project document, and a source content set that already matches its bindings.
It publishes an empty validated manifest and the project under the workspace
coordination lock, then reopens them through the normal candidate path. It
never replaces an existing workspace file or writes a source ARC.

## Intentional Changes and Merge

Workspace replacement and MES-projection methods accept only archives listed
in `target_archives`. They hold `.workspace.lock`, freeze the currently opened
project revision with `.project.lock`, and delegate the actual payload and
manifest transaction to OverlayPackage's `.manifest.lock` publisher. The
publisher loads the latest manifest inside that transaction, replaces only the
requested target keys, and preserves every unrelated replacement/projection
record. The source fingerprint computed inside publication must still equal the
project binding.

A project update validates the latest manifest while holding its publication
lock. It cannot remove a target archive used by an existing record or narrow
the compatibility objective below a staged record. ContentProject still owns
the exact SHA/revision compare-and-swap. After either kind of change, the
workspace prepares and swaps a new immutable snapshot; a stale project requires
an explicit refresh before more content can be published.

Legacy tools that publish directly through OverlayPackage remain safe because
the manifest publisher has its own cross-process lock and merges by target.
They do not update another process's already immutable snapshot; that process
must Hot Reload or refresh. The Launcher creates and opens this generation and
passes the selected source/workspace pair to every independent app, so the
coordinated path is the ordinary launched workflow.

## Mod Definitions

Since 2026-09-19 (Core 0.347.0) a workspace also holds the definitions a mod
writes itself (`kakyu_mod_event_definition/v1`,
[Mod Event Definition](mod_event_definition.md)): one JSON file per
document under `definitions/`, content-addressed
(`definitions/<sha256>-<definition id>.json`) and listed in the overlay
manifest's `definitions` array with the document's id, kind, mod id and
revision, target (for an override), hashes and fingerprints. Staging goes
through `stage_mod_definitions(documents, validate)`: the caller supplies
the contract check as a Callable (the tool layer's
`KakyuModDefinitionBinding.validator()`, which runs
`tools/validate_mod_event_definition.py`), every document must pass it
before any lock is taken, and the batch then follows the same
workspace/project lock choreography and the same atomic manifest
transaction as a replacement. The overlay package itself checks each
record's header against its file (schema, kind, mod, id, fingerprints,
an override's target, no projected text reference) on every load, so a
manifest whose definitions disagree with their files fails to open. A
workspace holds the definitions of exactly one mod id; a second id is
refused. `remove_mod_definition` drops the record and keeps the
unreferenced payload, like a projection. Definitions target no archive
and never enter a package export or an original-engine path;
`tools/validate_workspace_definitions.py` rechecks a workspace's
definitions from Python; between workspaces they travel as a
[Mod Definition Set](mod_definition_set.md), built from and imported into
a workspace by the tools that document names. The MES Editor's Definitions
tab is the editor for them - a structured form for the common shapes and
the JSON text for the rest (`docs/spec/tech/content_tools.md`, revisions
of 2026-09-19). The mod id is the documents' own identity, not
the project id (a project id may hold `.` and `-`, a mod id may not).

Since 2026-10-11 (WD-10, no Core change) a whole mod also arrives in one step:
a [Mod Bundle](mod_bundle.md) import (`cli/import_mod_bundle.gd`) fills a
**fresh workspace** - the destination must be new, and nothing is merged into
an existing one (WD-12) - with the bundle's replacements, projections and
definitions through the workspace's own staging calls (`stage_replacements`,
`stage_mes_text_projections`, `stage_mod_definitions`). The workspace still has
no standalone mod field: `mod_id` is derived from the manifest's definitions
and **persists only through definitions**. A bundle carrying a definition set
imports with its mod id persisted; a deltas-only (or translation-only) bundle
declares its mod in the header, which is verified and not persisted, so its
workspace imports with `mod_persisted` false and an empty `mod_id`. Persisting
a declared identity without definitions would be a `content_core/` change and
is not made.

## Independent-process handoff

Content Core 0.151 defines the runtime-only
`kakyu_content_launch_context/v1` contract. Arguments after Godot's `--` marker
use strict flag/value pairs: `--content-set <ELFIMAGE> --workspace <root>` and
an optional `--archive <bound ARC>`. The child process reopens the workspace
instead of trusting the parent's memory. Unknown, duplicate, partial, empty,
outside-root, unbound, and specialist-incompatible archive selections fail
closed. Positional startup arguments remain supported for direct and legacy
tool invocation.

With no explicit ARC, ARC Browser and MES Editor choose `mes.arc`, Event Player
opens the complete content set, Image Editor prefers `mmo.arc` then `data.arc`,
and Audio Editor prefers `voice.arc`, `bgm.arc`, `se.arc`, then the Tina voice
banks. Each app activates the workspace manifest only after reopening its own
read-only source reader and resolver. Closing the app releases both the launch
workspace snapshot and the specialist reader.

## Failure and Recovery

The service uses the shared `kakyu_workspace_publication_lock/v1` primitive for
`.workspace.lock`, while the two underlying publishers retain their own locks,
CAS checks, temporary recovery, atomic rename, and reopen validation. Lock
ordering is bounded by the workspace service; direct single-file publishers
never acquire both subordinate locks. A rejected change does not replace the
active in-memory generation. If disk publication succeeded but a later source
integrity check fails, the service stays on its last snapshot and requires a
refresh after the source problem is resolved.

The workspace is a metadata and resolver foundation. Portable derived-ARC
provenance is P1-04, runtime game integration is P1-06, and Launcher plus
independent-process workspace handoff is P1-07.
