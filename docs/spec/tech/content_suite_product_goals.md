# Content Suite Product Goals

This document defines the final product goals and definitions of done for the
shared Content Core and the standalone content applications other than Event
Player. Event playback has its own product contract in
[Event Player Product Goal](event_player.md). Current implementation details,
evidence, and incremental limitations remain in
[Content Core and Independent Tools](content_tools.md).

The owner closed Event Player to original-event playback/analysis on 2026-09-08.
The authoring tools still edit and validate mod content and export packages;
modified-content playback is outside Event Player. See [Product roles](product_roles.md).
This goal update does not claim that the existing edited-Run UI has been removed;
EP-08 owns that transition and original-event analysis remains the priority.

## Suite Mission

The Kakyu Content Suite is a set of independent tools for examining, editing,
validating and packaging original and original-derived content from a
user-owned ELFIMAGE installation, with an original-only playback instrument.
It must support a complete workflow:

1. open an immutable original content set;
2. inspect an archive, script, image, animation, or audio entry;
3. author replacements in a shared mod workspace;
4. validate structure, provenance, and declared compatibility;
5. preview effective content inside its owning editor and run source-bound
   compiler/semantic validation;
6. inspect the original reference event through Event Player; and
7. publish authored changes and validated local playback packages without
   overwriting original data. Verified ARC copies retain their separate scope.

The mod player is the separately maintained `kakyu-remake`; it consumes the
playback package and never original archives. Its implementation is not planned
or tracked in this repository.

Every app uses the single versioned `content_core/` implementation. An app may
provide format-specific user interaction, but it must not copy or privately
fork archive, overlay, MES, image, animation, or audio format logic.

## Product Set

The final suite consists of:

- Shared Content Core;
- ARC Browser;
- MES Editor;
- Image and Animation ARC Editor, including MMO, DAT/PAL, A6, and AX
  workspaces;
- Audio ARC Editor;
- Content Suite Launcher and Mod Project Manager; and
- Event Player, defined separately.

MMO editing remains a focused workspace inside Image and Animation ARC Editor,
not a separate format implementation or required separate application. A
future lightweight MMO-only executable may reuse that workspace and the shared
core, but it must not introduce another codec or project contract.

## Common Content and Provenance Model

### Immutable sources

Original and derived ARCs opened as sources are read-only for the lifetime of a
tool session. No tool saves in place. An output path must be new, and publication
must use sibling temporary output, close/reopen verification, and atomic rename
after a final destination-absence check.

Original game payloads and machine-specific source paths remain local. They are
not project assets, authored source files, Git content, or distributable tool
data.

### Resolution order

Authoring tools resolve a logical archive/entry request through:

`pending authored session -> active overlay -> selected ARC content set -> res:// fallback`

The pending layer exists only in an editor that owns unsaved work. It is not
visible to another process until it has been atomically published to the shared
workspace. Other authoring tools observe the same published effective payload
after successful transactional reload. Event Player selects original-reference
content; it does not consume authored workspace layers. The mod player consumes
the exported package and has no original-archive fallback.

### Compatibility levels

Every authored payload and package declares one of:

- **original_engine_compatible**: all known structural, encoding, container,
  and original-runtime requirements for that output path have passed;
- **original_engine_unverified**: the payload is structurally valid and may be
  used for a controlled original-engine verification candidate, but playback
  compatibility has not been established;
- **remake_only**: the payload is valid for the shared Content Core and remake
  runtime but deliberately uses features or assumptions not claimed for the
  original engine.

Tools must not upgrade a compatibility label merely because a file reopens or
decodes in the remake. Original-engine claims require the documented evidence
and verification gate for that format.

### Provenance

Every replacement binds its target archive and entry, original base archive
fingerprint, original entry fingerprint, payload size and fingerprint, editor
and Content Core versions, schema version, and compatibility level. Derived ARC
copies additionally bind the source snapshot and all staged payload snapshots
used for the rebuild.

Changing an input after staging or validation must fail closed. A package or
ARC produced by one suite app must retain enough provenance for another
authoring or package tool to distinguish exact original, original-derived
compatible, and remake-only content.

## Shared Content Core

### Goal

This repository's shared Content Core supplies consistent, streaming, versioned
and fail-closed content services to its tools and instruments. Python is the
Phase 1-4 analyzer authority; the existing GDScript tools and instruments retain
their tested roles. The separately maintained remake owns its runtime copies
and consumes playback packages, not this repository's original-archive inputs.

### Required capabilities

- validate and stream every supported ARC index and entry;
- reject path traversal, duplicate canonical names, overflow, overlap, short
  reads, malformed offsets, and decompression bounds violations;
- rebuild byte-identical no-op ARCs and verified changed-entry ARC copies;
- preserve entry order, unchanged payloads, and opaque container bytes where
  the format contract requires them;
- provide atomic, source-bound, payload-bound extraction and publication;
- load, merge, validate, snapshot, and resolve overlay packages;
- coordinate manifest and cache writers with cross-process locks, conflict
  detection, stale-lock recovery, and interrupted-temp cleanup;
- manage `user://content/<source-fingerprint>/` caches with size/hash/schema
  checks and lazy media conversion;
- expose one versioned MES container, decoder, IR, assembler, sandbox, call
  runtime, and validator stack;
- expose one versioned MMO, DAT/PAL, A6, AX, OGG, WAV, and compression stack;
- expose provenance and compatibility reports usable by every app;
- keep public runtime APIs independent of GUI scenes; and
- provide synthetic tests for every malformed-input and publication path.

### Definition of done

Content Core is complete when the game and every app use it for all supported
content access; no private format implementations remain; the supported corpus
round-trips or fails with a bounded reason; concurrent writers cannot silently
lose changes; all published outputs reopen and match their declared content;
and original data is never required in the repository or distributed tests.

## ARC Browser

### Goal

ARC Browser is the safe, format-neutral archive management application. It
shows stored and effective archive contents, extracts them, compares them, and
materializes validated replacements without interpreting entry payload formats.

### Required capabilities

- open any structurally supported ARC read-only;
- show entry name, original order, offset, stored/effective size, hash, source,
  replacement status, and compatibility;
- filter and sort views without changing stored order or hidden selections;
- extract one, many, or all effective entries through bounded streaming;
- compare two ARCs or an ARC and overlay by name, order, size, and fingerprint;
- show added, missing, changed, unchanged, and reordered entries distinctly;
- stage explicitly chosen raw binary replacements with conservative
  `remake_only` or `original_engine_unverified` labeling;
- open, Hot Reload, validate, and clear a shared mod workspace transactionally;
- materialize the complete active overlay into a new, source-bound ARC copy;
- produce a machine-portable validation and provenance report without payloads
  or machine paths; and
- hand a recognized entry to its specialist editor without copying bytes into
  tracked project data.

Entry addition, deletion, and reordering are not default completion requirements
until the original lookup and order semantics are confirmed for that operation.
If later supported, they require a distinct compatibility gate rather than
being inferred from successful container reopening. The semantics were
confirmed on 2026-09-17 (`kakyu_ai5_arc_exe_audit/v5`, `entry_index`: a
name-keyed map built at open, upper-cased requests, no positional access;
adding and reordering are lookup-safe, deleting fails the name's consumers),
and the owner ruled the same day that the tools stay replacement-only until a
mod needs an entry the original archives do not have; the compatibility-gate
rule above still applies then.

### Definition of done

ARC Browser is complete when a user can safely inventory, filter, compare,
extract, replace, and materialize any supported archive; every action preserves
or explicitly reports stored order and provenance; format-specific validation
is delegated correctly; no hidden or stale row can become a write target; and
the source ARC cannot be overwritten or partially published.

## MES Editor

### Goal

MES Editor is a complete lossless analysis, authoring, assembly, and validation
environment for MES and library scripts. It must progress beyond equal-length
text patching to editing the event program while preserving every unknown byte
that the user did not intentionally change.

### Required capabilities

- browse ARC entries, address tables, entry points, bootstrap code, and opaque
  container regions;
- display Japanese CP932 text and authored UTF-8 projections without treating
  undecodable native bytes as dialogue;
- search and edit dialogue and choice text;
- inspect and edit image, animation, voice, sound, and BGM references;
- inspect and edit typed state reads, writes, expressions, and conditions;
- inspect and edit branch, continuation, shared-routine, DEF, and nested MES
  calls;
- display synchronized disassembly, structured IR, references, call graph, and
  control-flow graph;
- add, remove, duplicate, and reorder supported messages, branches, choices,
  calls, and address-table entries;
- assemble variable-length changes with complete address, branch, continuation,
  message, and entry-table relocation;
- retain unrecognized instructions and opaque data losslessly;
- validate stack, expression, target, call, string, encoding, and continuation
  invariants before publication;
- reopen the assembled payload and compare intended semantic changes against
  the source IR;
- publish multi-entry edits as one overlay transaction or one verified new ARC;
- distinguish CP932 original-engine output from UTF-8 or extended remake-only
  output; and
- open the selected original caller/event in Event Player for reference;
  validate changed output through authoring proofs and package checks; and
- write, validate and save the mod's own event definitions (new events at
  a known place, edits to a projected event's conditions and effects) into
  the workspace, and exchange them as a definition set (owner rulings of
  2026-09-18 and 2026-09-19, `docs/spec/data/mod_event_definition.md`).

### Definition of done

MES Editor is complete when a user can modify dialogue, choices, state logic,
resource references, control flow, calls, and entry points without manually
calculating offsets; unchanged scripts rebuild losslessly; unknown instructions
survive unrelated changes; the assembler rejects every unresolved relocation;
edited outputs reopen and reproduce their declared semantic changes; and
packages pass their declared compatibility contract. Event Player playback of
edited output is not a completion condition.

## Image and Animation ARC Editor

### Goal

Image and Animation ARC Editor is the unified visual-asset application for MMO,
DAT/PAL, A6, and AX content. It provides asset inspection and editing together
with an exact logical `640x400` game-frame preview that uses the same codecs,
placement, hit testing, and animation runtime as Event Player.

### MMO workspace

- decode and encode all supported original MMO variants;
- export and import PNG without silently changing dimensions or transparency;
- preserve a validated target header or generate an explicitly labeled one;
- perform flip, RGB/BGR delta transform, AI5 LZ compression, and strict reopen
  pixel verification;
- edit crop, logical placement metadata, and preview composition without
  conflating preview-only settings with stored bytes; and
- publish original-engine-compatible or remake-only replacements with the
  reason for the label.

### DAT/PAL workspace

- treat DAT indices and PAL colors as one logical asset while resolving and
  reporting each entry independently;
- view and edit the palette, including the index-zero transparency rule;
- import true-color PNG through deterministic 256-color quantization;
- encode BGR palette data and flipped indices;
- validate dimensions, index bounds, palette use, alpha, and binary round trip;
- publish a paired authored replacement atomically; and
- support and preview a valid loaded overlay that replaces only one half.

### A6 workspace

- inspect, select, edit, add, remove, duplicate, and reorder region records;
- visualize inclusive rectangles and off-frame clipping at logical coordinates;
- reproduce native first-match hit testing and diagnose overlap, duplicate,
  inversion, and unreachable-region behavior;
- preserve table order unless the user deliberately changes it; and
- encode and reopen the complete table before staging it.

### AX workspace

- decode the complete supported AX control and data stream;
- identify its source surfaces, destination rectangles, frame groups, loops,
  delays, and termination behavior;
- present a timeline and live game-frame animation preview;
- use the same scheduler and compositor as Event Player;
- edit frame selection, order, delay, loop, source crop, destination placement,
  and transparency behavior;
- add, remove, duplicate, and reorder supported animation records;
- encode a lossless no-op and verified changed AX stream; and
- fail closed on native records whose source, timing, or consumer remains
  unresolved.

### Common required capabilities

- browse all supported visual entries in one app with format-specific workspaces;
- export decoded assets and structural metadata to new files;
- stage a multi-entry session without holding large payloads unnecessarily;
- preview `pending -> overlay -> source ARC` consistently;
- save the complete session as one overlay update or one verified ARC copy;
- display source dimensions, stored dimensions, frame placement, provenance,
  and compatibility; and
- open an original event/resource usage in Event Player for reference, while
  changed media is previewed and validated in the editor.

### Definition of done

Image and Animation ARC Editor is complete when supported MMO and DAT/PAL pixels,
A6 regions, and AX animations can be losslessly inspected, deliberately edited,
re-encoded, and previewed in the editor; the logical-frame result uses shared
placement and animation behavior; original-engine compatibility is separately
verified where claimed; and no format requires an external private converter
for ordinary editing.

## Audio ARC Editor

### Goal

Audio ARC Editor is the complete voice, BGM, and sound-effect archive editor. It
validates, previews, replaces, packages, and verifies event audio without
unnecessary re-encoding.

### Required capabilities

- browse, filter, validate, and play supported OGG and WAV entries;
- show container, codec, channels, sample rate, bit depth, duration, size,
  fingerprint, source, compatibility, and a bounded waveform summary;
- extract one, many, or all effective entries through streaming;
- stage multi-entry replacement sessions using path/hash descriptors rather
  than retaining every payload in memory;
- retain byte-identical valid input without re-encoding;
- offer explicit, deterministic conversion only when the user requests it or
  the target contract requires it;
- provide documented original-engine presets and reject unsupported channel,
  sample-rate, bit-depth, or container combinations;
- search confirmed MES references to the selected entry;
- save one overlay transaction or one verified new ARC copy;
- preview replacements in the editor and inspect their original event references
  through original-only Event Player;
- verify voice/BGM ordering, overlap, retention, replacement, and stopping; and
- batch-report replacement metadata and compatibility without distributing
  audio payloads.

### Definition of done

Audio ARC Editor is complete when valid source audio can be inspected, previewed,
extracted, replaced, converted when necessary, packaged, and verified with
editor previews and source-bound reference reports; unchanged valid inputs are
never needlessly transcoded; staged files
cannot change unnoticed; WAV and OGG compatibility claims have their required
original-engine evidence; and original archives remain unchanged.

## Content Suite Launcher and Mod Project Manager

### Goal

The Launcher evolves from a process picker into the suite's mod project and
workspace manager. It coordinates tools and validation but never becomes a
sixth format implementation.

### Required capabilities

- remember and validate user-selected ELFIMAGE and source-ARC locations locally;
- create, open, clone, and inspect versioned mod workspaces;
- show target content-set fingerprints, active overlay revision, package
  compatibility, tool/core versions, and unresolved validation results;
- launch each independent app with the same source content set, workspace, and
  selected logical entry or event when applicable;
- show which tools have published changes and whether the workspace changed on
  disk, without pretending to own another process's unsaved memory;
- coordinate manifest locks, detect conflicts, and recover stale/incomplete
  publications through Content Core;
- run focused or full headless validation and present its structured summary;
- launch Event Player in playback or analysis view for the selected original event;
- materialize verified new ARC copies through the appropriate core/tool action;
- build a distributable mod package that contains no original payload unless a
  replacement is independently authored and permitted;
- reject machine-specific paths and undeclared dependencies in portable output;
  and
- launch every tool as an independent Windows application with its own export
  preset.

### Definition of done

The Launcher and Project Manager are complete when a user can create a mod,
open the original content set once, edit it across multiple independent tools,
resolve publication conflicts, validate the complete package, inspect its original
references in Event Player, and export a portable overlay or verified ARC set
without manual
file copying or hidden format work in the launcher.

## Shared Mod Workspace

The suite uses one versioned workspace rather than unrelated per-tool output
folders. A representative logical layout is:

```text
my_mod/
  manifest.json
  project.json
  replacements/
    mes.arc/
    mmo.arc/
    data.arc/
    voice.arc/
    bgm.arc/
  projections/
    mes/
  definitions/
  metadata/
    events/
    images/
    audio/
  reports/
```

`project.json` describes the mod identity and version, required Content Core and
schema versions, source content-set fingerprint, target archives, declared
compatibility objective, dependencies, and optional Event Player presets. It
must not contain a machine-specific absolute source path.

`definitions/` holds the mod's own event definitions, content-addressed and
listed in `manifest.json` like a projection (since 2026-09-19).

`manifest.json` remains the content-addressed replacement authority. Metadata
and reports may aid editing and verification but do not override the effective
payload resolver. Each tool merges only its intentional change, preserves
unrelated records, and publishes under the shared lock/revision contract.

## Suite Definition of Done

The non-Event tools reach their combined final goal when:

1. every supported original entry can be inspected without modifying its ARC;
2. every supported authored format can be edited through its specialist app;
3. all apps share one Content Core, resolver, compatibility model, and workspace;
4. concurrent or interrupted publication cannot silently lose a tool's work;
5. overlay and materialized-ARC forms resolve to the same declared payloads;
6. unchanged content is preserved byte-for-byte where its contract requires it;
7. all output is source-bound, payload-bound, atomic, reopened, and verified;
8. MES, visual, animation and audio edits have editor-side preview/validation
   and source-bound package output without manual copying;
9. Event Player reference handoff opens only the corresponding original content;
   no valid authored output depends on playback in that application;
10. original-engine-compatible, unverified, and remake-only outputs remain
    visibly distinct through editing, playback, validation, and packaging;
11. the suite can generate a portable mod package without original game data or
    machine paths;
12. each application is independently launchable and exportable;
13. headless synthetic and original read-only validation covers every safety and
    structural contract; and
14. accumulated visual, audio, and original-engine checks have a documented,
    non-focus-stealing verification batch where automation cannot prove the
    result.

## Delivery Order

Current order follows [Root TODO](../../../TODO.md#execution-order): complete
original-event analysis first, then general authoring validation and package
delivery, then remaining application identity/distribution work. EP-08 owns
bounded cleanup of old edited-content Event Player entry points. Media and
manual verification retain their domain owners and existing deferrals.

Small implementation commits should close one contract at a time and update
this document only when the product goal or definition of done changes. Detailed
evidence and current implementation status remain in their focused specifications.
Ordered implementation work and current status are maintained in the
repository-root [TODO](../../../TODO.md).
