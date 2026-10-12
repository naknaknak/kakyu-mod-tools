# Kakyu Mod Tools Spec

The specifications this repository owns. It is the original analyzer, so it owns
the evidence its tools produce and the contracts its tools implement; the mod
player's game shell keeps its own. See
[Product roles](tech/product_roles.md) for the boundary and
[Stance Toward the Original Game](tech/original_source_stance.md) for what the
original is used for.

Moved here from `kakyu-remake` on 2026-09-05 by the owner's ruling: a document
lives where its producer lives.

## Product goals and decisions

- [Product Roles](tech/product_roles.md) — analyzer, instrument, mod player
- [Stance Toward the Original Game](tech/original_source_stance.md)
- [Content Suite Product Goals](tech/content_suite_product_goals.md)
- [Event Player Product Goal](tech/event_player.md)
- [Content Suite Implementation Gap Matrix](tech/content_suite_gap_matrix.md)

## Tools and content boundary

- [Content Core and Independent Tools](tech/content_tools.md)
- [Tooling](tech/tooling.md)
- [Early Windows Prototype](tech/windows_prototype.md) — reproducible export and explicit release limits
- [Windows Application Distribution](tech/windows_distribution.md) — six release apps, isolated Python runtime and portable verification

## Data contracts implemented here

Each of these describes a format produced or validated by `content_core/`.

- [Content Project](data/content_project.md) — `content_project.gd`
- [Content Workspace](data/content_workspace.md) — `content_workspace.gd`
- [Content Identity](data/content_identity.md) — `content_identity.gd`
- [Materialized ARC Provenance](data/materialized_arc_provenance.md) —
  `arc_provenance.gd`
- [Content Provenance Report](data/provenance_report.md) — the portable,
  path-free, re-verified lineage statement of one workspace
  (`tools/content_suite/provenance_report.gd`, WD-04)
- [Audio Metadata Report](data/audio_metadata_report.md) — the portable
  per-entry audio metadata, source and MES-reference report of an audio
  archive (`tools/content_suite/audio_metadata_report.gd`, ME-06)
- [Content Selection](data/content_selection.md) — the workspace-bound
  selection one app hands to another (`content_core/content_selection.gd`,
  `--selection`, WD-09)
- [ARC Comparison](data/arc_comparison.md) — the path-free index and
  whole-entry hash comparison of an ARC with another ARC or with its loaded
  overlay (`tools/content_suite/arc_comparison.gd`, WD-01)
- [Compiler and Framing Region Counts](tech/mes_compile_region_counts.md) —
  the retained empty bootstrap versus nonempty framing coverage
- [Authored Mod Delta](data/authored_mod_delta.md) — authored-only portable changes and local reconstruction
- [Mod Bundle](data/mod_bundle.md) — `kakyu_mod_bundle/v1`: a workspace's authored deltas, translation-only entries and definition set in one portable file (WD-10)
- [Workspace Playback Export](data/workspace_playback_export.md) — local effective MES and UTF-8 package
- [Validation Checks Registry](data/validation_checks.md) — the tracked list of every validation check, its tier and what it requires (TD-32)
- [Event Definition Projection](data/event_definition_projection.md) — draft producer mapping to the shared `kakyu_event_definition/v3` (WD-22)
- [Event Definition v5](data/event_definition_v5.md) — v4's document (`data/event_definition_v4_design.md`) plus an optional document-level `visits` list selected by state conditions (WD-23)
- [Event Definition v6](data/event_definition_v6.md) — v5's document plus an optional top-level `flow` block carrying a `kakyu_event_analysis_group/v14` route's own hop chain, for a date site (EP-12 / WD, 2026-09-25; contract and producer landed)
- [Event Definition v7](data/event_definition_v7.md) — v6's document plus the `presentation.resources` item rule: `{entry, source_offset, kind, name}` in the package inventory's vocabulary, the media a row's measured route reaches (WD-21 U2, 2026-10-08; contract and producer landed, 681 documents in `config/event_definitions/v7/`)
- [MES Contextual Run](data/mes_contextual_run.md) — source-bound edited-event analysis
- [MES Authoring Bundle](data/mes_authoring_bundle.md) — local Python/editor
  inspection, state/message preview and source-bound compiled publication

## MES analysis

Every finding about the original script. [MES Analysis Index](mes/index.md) is
the navigation table; [Format and Method](mes/format_and_method.md) holds the
shared container, expression and interpreter rules.

The documents are organized by the consumer that uses a finding, which is why
some are named after mod-player scenes. They record original source flow,
offsets and evidence — not remake implementation — and they are the output of
this repository's analysis tools.

## What stays in `kakyu-remake`

Referenced from here by path, not duplicated:

| Document | Why it stays |
|---|---|
| `tech/playback_package_schema.md` | The contract between the repositories. Copying it is the drift the contract exists to prevent. |
| `tech/modtools_split_plan.md` | The remake's record of its own transformation. |
| `tech/architecture.md` | The mod player's Godot architecture. |
| `systems/*`, `scenes/*` | The game shell. |
| `data/mes_condition_projection.md`, `data/event_definition_v3.md`, `data/dating_data_examples.md` | Consumed by the game shell; no implementation here. `event_definition_v3.md` is the consumer side of the WD-22 agreement whose producer side is `data/event_definition_projection.md` here (2026-09-15); the v2 `event_definition_contract.md` it superseded was never tracked there. |
| `data/runtime_content_service.md` | Documents `content_service.gd`, removed here on 2026-09-05 as dead code. |

Ten links from the documents above point into that set, counted 2026-09-06 and
recountable by resolving every relative link under `docs/spec/`. They are
cross-repository references and are expected to be unresolvable from this
checkout; nothing else under `docs/spec/` is. Paths outside this repository are
written as paths rather than links elsewhere — see `AGENTS.md` and
`tech/product_roles.md` — so a link that does not resolve here is either one of
these ten or a defect.
