# Mod Bundle (`kakyu_mod_bundle/v1`)

Status: **landed 2026-10-11** (WD-10 closed, Core 0.377.0, no Core change): the
Python tool (checkpoint C1), the headless importer (C2), the original-archive
proof (C3) and the whole-batch closing proof (C6) are recorded below and in
`todo/workspace_distribution.md` WD-10. The Launcher's export and import UI is
WD-24 (unscheduled).

One mod artifact: a single JSON file carrying everything a workspace authored
for the original `mes.arc` - every authored delta
([Authored Mod Delta](authored_mod_delta.md), `kakyu_authored_mod_delta/v9`,
one per authored MES entry), the UTF-8 translations of entries that have no
structural edit (`text_projections`) and the workspace's definition set
([Mod Definition Set](mod_definition_set.md), `kakyu_mod_definition_set/v1`).
It closes the topic the transport ruling of 2026-09-19 left open
([the design document](mod_event_definition_design.md), ruling 3: "a mod
bundle ... stays a later topic, to be taken up when the multi-entry delta is").

The bundle is a **tool-to-tool transport**. It is a tool data contract in
`docs/spec/data/`, not a fingerprinted `config/contracts/` directory: the
remake never reads it, because applying a delta needs the original archive
(reconstruction), which the remake by its invariant never reads. The remake
reads the playback package exported from the imported workspace. If the
remake ever consumes a bundle, the contract moves to a fingerprinted
directory then.

It never carries an original payload, an absolute path or a local evidence
bundle: no ARC, no complete MES, no raw instruction bytes, no handoff, no
original message text.

## The file

Exact key sets at every level.

```
schema             "kakyu_mod_bundle/v1"
mod                {id, revision}            the mod id pattern (validate_mod_event_definition.MOD_ID_RE); revision an integer >= 1
source_project_id  the project_id of the workspace it was built from
source             {archive: "mes.arc", archive_sha256, source_kind: "original_arc"}
dependencies       [{entry, entry_sha256}]   the deltas' dependency union, sorted by entry, one hash per entry
deltas             [{entry, source_entry_sha256, output_entry_sha256, delta_sha256, document}]   sorted by entry
text_projections   [{entry, source_entry_sha256, text_edits}]                                   sorted by entry
definition_set     null | {set_sha256, definition_count, document}
compatibility      {target: "remake_only", minimum_core: "0.377.0", maximum_exclusive: "1.0.0"}
payload_sha256     SHA-256 of the canonical JSON of every other field
```

Row rules:

- `deltas[].document` is a complete **v9** delta. Older delta versions are
  not members. Its `source.archive_sha256` equals the bundle's, its
  `source.entry` equals the row's `entry`, and the row's two entry hashes
  equal the document's. `delta_sha256` is the SHA-256 of the document's
  canonical bytes.
- `text_projections[].text_edits` obey the delta's text-edit rules - the
  same single function, `authored_mod_delta.validate_text_edits`: an array of
  `{source_offset, raw_sha256, text}` with strictly increasing offsets, no
  NUL, UTF-8 text - and are non-empty. `source_entry_sha256` is the original
  entry's. The edits are in original coordinates.
- `definition_set.document` is a complete set document. Its `mod` equals the
  bundle's `mod` and its `source_project_id` the bundle's; `set_sha256` is
  the SHA-256 of its canonical bytes and `definition_count` its row count.
- Entries are unique case-insensitively across `deltas` and
  `text_projections` together. Two deltas for one entry, or a delta and a text
  row for one entry, are refused - a delta already carries its own
  translations, and merging two changes to one entry is WD-12's topic.
- There is at least one member: `deltas` or `text_projections` non-empty, or
  `definition_set` not null.
- `dependencies` equals the union of the deltas' own `dependencies` (for
  example `DEF_MAIN.MES` for a registered-definition call, `LIBLARY.LIB` for a
  shared-routine call), one hash per entry.
- The file is at most **64 MiB**, and each member also obeys its own bound
  (16 MiB of canonical bytes).

### Translation-only entries

An entry whose only authored change is its UTF-8 translation has no delta to
bind a text edit to. It travels as a `text_projections` row (owner decision
2026-10-11). On import it becomes the workspace's `mes_text` projection for
that entry exactly as a delta's `text_edits` do. A row needs no rule of its
own: the delta's text-edit rules at validation, the exact-message binding
(`authored_mod_delta._check_text`) at build and at `validate --arc`, and the
overlay's own projection validator at import.

### Canonical form

Every hash in a bundle is a SHA-256 of `mes_authoring_workflow._json` bytes -
the delta and set form: sorted keys, `(",", ":")` separators, UTF-8 without
`ensure_ascii`, **one trailing LF**.

- `payload_sha256` is `authored_mod_delta.fingerprint(document)`, reused:
  `_json` of every field but `payload_sha256`.
- `delta_sha256` is `sha256(_json(delta document))` and `set_sha256` is
  `sha256(_json(set document))`.
- `--extract` writes exactly those `_json` bytes.
- **The bundle never goes through `payload_values.fingerprint`**, whose
  canonical bytes carry no trailing LF. The two conventions are not
  interchangeable: a document hashed by one never verifies under the other.

### Versioning

`v1` is read exactly: the schema string, the exact key sets, the
compatibility constant and `payload_sha256`. A shape change lands as
`kakyu_mod_bundle/v2`. Whether v1 is then refused by name or read through a
listed legacy path (as `authored_mod_delta.py` reads v1-v8) is decided at
that time, never as an in-place edit. A member's own contract keeps its own
constants (minimum core 0.329.0 for the delta, 0.347.0 for the set).

## Fail-closed rules

| Rule | Mechanism |
|---|---|
| Unsupported schema version, an extra or missing field, a changed `payload_sha256` | the schema string must be exactly `kakyu_mod_bundle/v1` (any other, a later version included, is refused by name, before the key set is read); exact key sets; `fingerprint` |
| Incompatible core | `compatibility` must equal the constant, as for the delta and the set: a tool that knows `kakyu_mod_bundle/v1` is at or above 0.377.0 by construction, and any other requirement is refused |
| Original payload leakage | exact key allowlists at every level and the members' own validators (no `raw_hex`, no instruction bytes, no handoff); the tests assert that the canonical bundle bytes contain no source or output entry hex and none of `"raw_hex"`, `"handoff"`, `"source_path"` |
| Absolute paths | no field of the contract is a path; entries pass the delta's source-identity rule (a path-free `.MES` name); the CLI refuses an output inside the workspace, the original archive directory or the tracked definitions directory |
| Missing or changed dependencies | the header's `dependencies` equal the members' union, with one hash per entry; `validate --arc` checks every one against the archive; reconstruction refuses a missing or changed one (existing delta behaviour) |
| Duplicate entries | the case-insensitive uniqueness rule above |
| A delta and a definition set for different mods | a v9 delta carries no mod identity, so the header **is** its identity; the set's `mod` and `source_project_id` must equal the header's |
| Wrong source | `validate --arc` checks the archive SHA-256, each member entry's hash and every text edit bound to an exact source message; an importer's template workspace must bind the same `mes.arc` |
| Oversize | refused on the file's size **before** any read or parse, by every consumer |
| Tampering between validation and import | the importer hashes the file before and after the Python validation and every extracted member against its row |

## Tools

```
py tools/mod_bundle.py build <mes.arc> <workspace root> <out.json> [--mod-id ID --mod-revision N]
                             [--names DIR] [--definitions-dir DIR]
py tools/mod_bundle.py validate <bundle.json> [--arc <mes.arc>] [--names DIR] [--definitions-dir DIR] [--extract DIR]
```

Both print one JSON line and exit 0 or 1: `{ok, schema, mod_id, mod_revision,
delta_count, text_projection_count, definition_count, payload_sha256}` on
success, `{ok: false, error}` otherwise. The core functions take an entry
reader (`read_entry(name) -> bytes`) and the archive's SHA-256; only `main`
binds them to an ARC file.

### Build

`build` reads the workspace's `project.json` and `manifest.json` read-only and
carries **the whole workspace, or nothing**:

- Each `mes.arc` replacement with a linked authoring bundle becomes a delta.
  The link is the rule the provenance report and the authoring-proof lookup
  already use: each candidate under `.authoring/delta` and `authoring/*`, in
  sorted order, is read by its `manifest.json` summary first; the first match
  by entry, original hash and replacement hash is reopened with
  `read_bundle`. Matches that name different operations are refused as
  ambiguous. The replacement file must hash to its record, and the entry's
  projection edits, if any, become the delta's `text_edits`. The delta is built
  by `authored_mod_delta.build`.
- Each `mes.arc` projection on an entry with no replacement becomes a
  `text_projections` row, checked with `_check_text`.
- The definitions, if any, become the set (`mod_definition_set.build`).

Refused, naming the record:

- a replacement outside `mes.arc` (a raw media replacement is payload);
- a `mes.arc` replacement with no linked authoring bundle (a raw staged MES is
  payload);
- a projection outside `mes.arc`;
- an empty workspace;
- a projection on an entry whose replacement relocates a message at an offset
  the projection also edits (the delta's own rule would refuse it; the build
  names the entry and the offset first);
- a project or record bound to another archive, a replacement or projection
  file that does not hash to its record, an original entry that differs from
  the archive.

The mod identity is the set's when the workspace has definitions
(`--mod-id` / `--mod-revision`, if given, must agree). Without definitions
`--mod-id` is required and `--mod-revision` defaults to 1. The workspace must
not change during the build: `project.json` and `manifest.json` are re-hashed
at the end. The assembled bundle is validated in full - structure, every
member, and against the archive - before it is published, and the build is
deterministic.

Publication uses `payload_values.publish_new_document`, the one hard-link rule
the delta, the set and the editable-IR writers share: temporary file,
`fsync`, reopen and compare, `os.link`; an existing output is never replaced.

### Validate

The size is checked first, on `st_size`, before the file is read or parsed
(64 MiB). Without `--arc` the structure and every member through its own
validator are checked, and the set gets the full contract check against the
tracked directories. With `--arc` the source rules above are checked as well;
reconstruction of a delta is the importer's step. With `--extract` the tool
writes `deltas/<ENTRY>.json` and `definition_set.json`, the exact `_json` bytes
the rows' hashes name.

## Import

```
Godot --headless --path . --script res://tools/content_suite/cli/import_mod_bundle.gd -- SOURCE_ROOT TEMPLATE_WORKSPACE BUNDLE_JSON NEW_WORKSPACE
```

`tools/content_suite/mod_bundle_import.gd` `import_bundle(source_root,
template_workspace, bundle_path, output_root)` is the bundle front door of the
staged-import engine in `tools/content_suite/authored_delta_import.gd`
(`import_members`; `import_delta` is its one-member front door and keeps its
contract and messages). The CLI prints the result as one JSON line and exits 0
or 1.

1. **The size comes first.** A file over 64 MiB is refused on its length before
   anything is read or parsed, and again on the bytes parsed.
2. **Validation.** `mod_bundle.py validate --arc <SOURCE_ROOT>/mes.arc --extract`
   runs through the one helper both importers share,
   `python_validated_extract.gd`: the file's SHA-256 before, the tool's last
   JSON line as the verdict, the SHA-256 after (a changed file is refused), the
   extract tree handed to the importer and removed on every exit. The set
   importer (`mod_definition_set_import.gd`) calls the same helper, so the
   hash-before/after, `--extract` and verdict handling exist once.
3. **Parse and check.** The verified bytes are parsed for the rows.
   `JSON.parse_string` yields every number as a float, so the integer fields
   (`source_offset` and the rest) fold back through `ContractValues.intify`,
   the Core's existing helper. Each extracted file must hash to its row
   (`delta_sha256`, `set_sha256`).
4. **The template.** The template workspace supplies only its project, as for a
   single delta; its `mes.arc` binding must equal the bundle's `source`, and the
   destination must be new and outside the content set. Nothing is merged into
   an existing workspace (WD-12).
5. **The engine, inside one stage** (a `.staging-<hex>` sibling, a lock, the
   project-id suffix `.bundle`):
   - every delta reconstructs into `authoring/delta-<ENTRY>` - the directory the
     provenance report and the authoring-proof lookup already scan; a single
     delta still uses `.authoring/delta` - the library audit is built once when
     `mes.arc` holds `LIBLARY.LIB`, and each proof and source are checked as for
     a single delta;
   - all replacements are staged in one `stage_replacements` call, then all
     projections (the deltas' `text_edits` and the translation-only rows) in one
     `stage_mes_text_projections` call, then the workspace is refreshed;
   - the definition set, if any, is imported by the set importer into the stage
     (a fresh workspace, so every definition is added);
   - the stage is reopened and every effective identity is checked: each delta
     entry resolves to its `output_entry_sha256`, each projection loads with
     exactly the bundle's edits, the counts match, and the definitions'
     identity matches (below).
6. **Publication** is the existing lock-and-rename rule. A failure leaves the
   stage as local evidence and never publishes it.

The result is `{ok, schema, bundle_file_sha256, mod_id, mod_revision,
mod_persisted, delta_count, text_projection_count, definition_count, members:
[{entry, output_entry_sha256, authored_text_count}], workspace}`, the members
listed by entry; a translation-only member has an empty `output_entry_sha256`.

Refused, each leaving no destination: an existing destination, a destination
inside the content set, a template on another archive, an oversize or missing
file, two deltas for one entry, a delta row whose archive differs, a set for
another mod than the header's, a changed member (a re-signed bundle whose delta
no longer reconstructs to its output), a stale payload hash, and any validator
refusal.

**Memory.** Godot's parser holds JSON text as Variants at about 18x its size
(TD-64 C0), so a worst-case 64 MiB bundle costs about 1.2 GB for the import's
lifetime. That is acceptable for a one-shot tool; real bundles are kilobytes.

## The mod identity of a bundle without definitions

A v9 delta names no mod, and a workspace derives its `mod_id` from its
definitions: there is no standalone workspace field to carry one. A bundle
with a definition set therefore persists its mod identity through the
definitions the import stages. A **deltas-only (or translation-only) bundle
declares its `mod` in the header, which is verified against the bundle and not
persisted by the import**: the imported workspace's `mod_id` stays empty and
the import result reports `mod_persisted` false (it is true only with a set).
`content_workspace.gd` derives `mod_id` from the manifest's definitions
(`:331`, `:336-340`), so persisting a declared identity without definitions
would be a `content_core/` change. This is a recorded boundary of the contract,
not a defect. The engine's reopen check asserts both sides: with a set the
reopened `mod_id`, `definition_count` and every definition's hash equal the
bundle's; without one the reopened `mod_id` is empty.

## Not in this contract

- The Launcher's export and import UI (WD-24), and merging into an existing
  workspace (WD-12).
- Assembly of a bundle from loose delta and set files, and older delta
  versions as members.
- Exporting the imported workspace to a playback package (WD-21).

## Verified

`tests/test_mod_bundle.py` (2026-10-11, 67 tests): a build from a hand-written
workspace over a synthetic `mes.arc` (two authored entries, one translated, one
translation-only entry, two definitions) validated, deterministic and free of
leakage; the canonical-form pin (the delta/set fingerprint, different from
`payload_values.fingerprint`); definitions-only, deltas-only and text-only
builds with the mod-identity rules; every refusal of the table and of the
build, each rehashed so the payload hash is not the reason; the 64 MiB
pre-parse refusal; `--extract` bytes against the row hashes; `--arc` through
the injected reader; atomic publication; the CLI exit codes and JSON line;
and the three publication wrappers' messages and temporary names.

`tests/test_mod_bundle_import.tscn` (2026-10-11, synthetic mode, 79 checks): a
multi-entry bundle built by the Python tool from a headlessly authored workspace
over a three-entry synthetic `mes.arc` - entry A a state edit, entry B a state
edit and a translation, entry C a translation only, and one `new_event`
definition - imported into one fresh workspace and reopened: every effective MES
hash equal to the authored output, every projection carrying exactly the
bundle's edits, the definition and the persisted mod id, the provenance report
linking each replacement to its `authoring/delta-<ENTRY>` bundle, and the
original archive and the template workspace byte-unchanged. Also a deltas-only
bundle importing with `mod_persisted` false and an empty reopened `mod_id` (also through the CLI, exit 0 and 1); a
bundle without a delta importing its translation and definition; and every
refusal listed above plus the three at build (a raw MES replacement, a raw
replacement in another archive, a projection overlapping a relocated message).

`original mod bundle round trip` (2026-10-11; the same test in its original mode, run by
`tools/content_suite/validators/validate_mod_bundle_original.gd` over the read-only original
`mes.arc`; registry entry in the `full` tier at 900 s, group `original_corpus`, requires `elfimage`):
`EVENTB01.MES` with a state edit at `0x8F` (value 2), `EVENTB03.MES` with a state edit at `0x76`
(value 2) and one translation, `EVENTB02.MES` with a translation only (the entry's first message,
offset `0x444`), and one `new_event` definition, built into a bundle, validated with `--arc`, imported into
one fresh workspace, reopened and checked as in the synthetic mode: every effective MES hash equal to the
delta's output hash, every projection carrying exactly the bundle's edits, the definition and the persisted
mod id, the provenance report linking both replacements to their `authoring/delta-<ENTRY>` bundles, a second
import to the same destination refused, and the original archive (hash), every top-level file of the
content set (length and modification time) and the template workspace's manifest unchanged. The refusals,
the deltas-only bundle and the CLI are the synthetic mode's only.

- **Footprint.** The check writes only under `user://` (the batch gives each worker its own `APPDATA`,
  so Godot's `user://` and the Python children's `TEMP` are per worker), removes its template, authoring and
  destination workspaces, bundles, scratch and extract trees on every exit, and never writes the project
  tree, `assets/` or the original directory. Every translation string is synthetic (`번들 확인 2`/`3`), never
  original text.
- **Output.** Failures are reported as they happen; a pass prints one line with entries, offsets, counts, the
  bundle's `payload_sha256`, `effective_identities=verified`, `sources_unchanged=true` and the assertion
  count, and no message or its text. Two solo runs printed the identical line
  (`bundle_sha256=307d4cc6...b21d349`, 29 assertions).
- **Duration and tier.** Solo, on an idle machine, `--jobs 1`: **179.5 s and 179.0 s**. The pieces of a run
  (a direct run, seconds from start): the template workspace on the original content set 15, authoring both
  entries 39, the two message lookups 12, the staging calls 10, `mod_bundle.py build` 15, the import 71,
  the reopen and the identity checks 5, the provenance report 11. By TD-46's rule (a loaded duration of
  about 1.5 times solo, at most 0.5 of the timeout) it is not an `archive_quick` check (solo above ~100 s):
  `full` at 900 s, a solo ratio of 0.20 and a loaded estimate of 0.30. The registry revision stays 5
  (an entry is added; the vocabulary does not change).

**Closing verification** (2026-10-11): the whole `full` tier at `--jobs 6`, uncached, on tree `8f81d232` (run `e6cb6108`;
the record is in [Validation Checks](validation_checks.md)). **479 of 479 passed** in 2,546.4 s, and `--cached` on the same
tree passed 479 of 479, all cached, in 9.5 s. Both of the unit's checks passed inside it: `Godot test_mod_bundle_import.tscn`
in 11.9 s of its 180 s (0.07) and `original mod bundle round trip` in 179.5 s of its 900 s (0.20), the latter printing the
solo runs' bundle hash and assertion count (`bundle_sha256=307d4cc6...b21d349`, 29 assertions). Its duration equals the solo runs'
because the check had no cache entry when the batch was launched, so the ordering put it after every keyed check and it ran
nearly alone at the tail; it has one now, and the next uncached batch orders it by its recorded duration.

**Deviation from the unit spec (D11).** The spec listed the deltas-only bundle among the assertions of both modes. It, the CLI
and the refusals run in the synthetic mode only: the deltas-only boundary is workspace behaviour (a workspace derives its
`mod_id` from its definitions), pinned by the synthetic scene, and running it in the original mode as well would have lifted
the original check from 179 s to about 250 s (an estimate) against its 300 s stop.
