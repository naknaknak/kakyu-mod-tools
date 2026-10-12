# Content Project Contract

This document defines the portable project metadata shared by the Content
Suite. The product scope is defined in
[Content Suite Product Goals](../tech/content_suite_product_goals.md). The
overlay manifest remains the payload authority; `project.json` identifies the
workspace, its source lineage, compatibility objective, dependencies, and
optional Event Player presets.

## Schema and Location

The v1 schema string is `kakyu_content_project/v1`. The bounded UTF-8 JSON file
is named `project.json` and lives beside `manifest.json` at the workspace root.
Unknown schema versions, unknown fields, non-canonical values, and files larger
than 1 MiB fail closed.

```json
{
  "schema": "kakyu_content_project/v1",
  "project_id": "sample.maki.mod",
  "project_version": "0.1.0",
  "display_name": "Sample Maki Mod",
  "project_revision": 1,
  "content_core": {
    "minimum_version": "0.146.0",
    "maximum_exclusive": "1.0.0"
  },
  "source_content_set": {
    "profile_id": "original-jp",
    "fingerprint_sha256": "<64 lowercase hex>",
    "archives": [
      {"archive": "mes.arc", "sha256": "<64 lowercase hex>", "required": true}
    ]
  },
  "target_archives": ["mes.arc"],
  "compatibility_objective": "mixed",
  "dependencies": [],
  "event_player": {
    "catalog_id": "kakyu-original-events",
    "presets": []
  },
  "overlay_manifest": "manifest.json"
}
```

Object member order has no meaning. `source_content_set.archives`,
`target_archives`, and `dependencies` use unique, canonical sorted order so the
same logical metadata has one fingerprint and reviewable diff.

## Identity, Revision, and Core Range

`project_id` is portable lowercase ASCII and is the dependency identity.
`project_version` and dependency/core ranges are canonical three-component
semantic versions. `project_revision` starts at 1 and increments by exactly
one for every successful metadata publication; it is an optimistic publication
revision, not the distributable mod version.

The running Content Core must be at least `minimum_version` and below a
non-empty `maximum_exclusive`. An incompatible project is not partially opened
or migrated implicitly.

## Source and Target Bindings

Every source archive binding contains its lowercase safe ARC name, SHA-256,
and whether the source profile requires it. `mes.arc` is mandatory. The
content-set fingerprint is SHA-256 over the Content Core canonical projection
of the sorted archive bindings; it binds the complete selected source lineage
without storing the ELFIMAGE path.

`target_archives` is a non-empty sorted subset of those bindings. It declares
intent and does not grant permission to rewrite an original ARC. Effective
payload selection remains `overlay -> selected ARC -> res:// fallback`, and
materialized copies require the later provenance contract.

## Compatibility and Dependencies

`compatibility_objective` is one of `remake_only`,
`original_engine_compatible`, or `mixed`. This is a project objective, not a
claim that every staged record has already passed that gate. Record-level and
validation reports may only narrow it. An original-engine-compatible project
cannot contain a remake-only Event Player preset.

Dependencies are sorted by project ID and carry a minimum version, optional
exclusive maximum, and explicit optional flag. Self-dependencies, duplicate
IDs, and empty version ranges fail closed. Dependency payloads are not embedded
in this file.

## Event Player Presets

Each optional preset has a stable ID and label, a catalog event ID, a kind,
and isolated sandbox writes. `catalog_reference` requires a catalog preset ID;
`tool_seeded_analysis` and `remake_only` must not impersonate one. State writes
use explicit storage, bank, index, and integer value, and values must fit the
declared storage width. Presets select initial tool state only; they do not
embed dialogue, bytecode, images, or audio.

## Portability and Publication

Portable project metadata rejects payload fields, source paths, absolute
paths, and parent traversal anywhere in the document. Original game data and
machine-specific ELFIMAGE paths never belong in `project.json`.

Publication uses the shared `kakyu_workspace_publication_lock/v1` directory
lock at `.project.lock`. A publisher validates the candidate, acquires the
lock, removes recognized dead-process sibling temporaries, verifies the
expected existing `project.json` SHA-256, enforces the exact revision step,
writes and hashes a unique sibling temporary, rechecks compare-and-swap state,
atomically renames, then reopens and validates the result. A conflict preserves
the currently published project. The service never writes a source ARC.

`KakyuContentProject` owns this schema and publication boundary.
[`KakyuContentWorkspace`](content_workspace.md) composes its immutable project
snapshot with the overlay manifest and source content set without duplicating
or weakening these checks.
