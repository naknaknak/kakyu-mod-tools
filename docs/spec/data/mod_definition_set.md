# Mod Definition Set (`kakyu_mod_definition_set/v1`)

Status: **landed 2026-09-19** (Core 0.347.0), by the owner's transport
ruling of the same day recorded in
[the design document](mod_event_definition_design.md): a mod's own event
definitions ([Mod Event Definition](mod_event_definition.md)) travel
between workspaces in one JSON file published beside the mod's authored
deltas. The delta format ([Authored mod delta](authored_mod_delta.md)) is
not touched: a delta is one document per MES entry, and a mod whose only
change is a new event has no entry to bind one to. A mod bundle holding
deltas and definitions in one artifact is taken up by WD-10 (2026-10-11):
[Mod Bundle](mod_bundle.md) embeds a complete set document as its
`definition_set` member and leaves this file's format untouched.

## The file

```
schema               "kakyu_mod_definition_set/v1"
mod                  {id, revision}                the mod id pattern; revision an integer >= 1
source_project_id    the project_id of the workspace the set was built from
contract_fingerprint the mod event definition contract's tracked fingerprint
cells_fingerprint    the cell-class table's tracked fingerprint
names_fingerprint    the event name registry's tracked fingerprint
definitions          [{definition_id, definition_kind, target_id, definition_sha256, document}, ...]
compatibility        {target: "remake_only", minimum_core: "0.347.0", maximum_exclusive: "1.0.0"}
payload_sha256       SHA-256 of the canonical JSON of every other field
```

Exact key sets everywhere; rows sorted by `definition_id` with no
duplicate; `definition_sha256` is the SHA-256 of the row's `document` in
canonical JSON (sorted keys, no spaces, UTF-8, one trailing LF - the same
serialization the authored delta uses); every `document` is a complete
`kakyu_mod_event_definition/v1` document whose `id`, `kind`, `mod`,
`contract_fingerprint`, `cells_fingerprint` and (for an override)
`target.id` agree with its row and with the set header, carrying the real
fingerprints, never `"self"`; `target_id` is empty for a `new_event`; the
file is at most 16 MiB. A consumer fails closed on any of these, on a
changed `payload_sha256`, and - when given the registry and the tracked v4
directory - on any document that fails the full contract check, naming
the definition and the reason.

## Tools

```
py tools/mod_definition_set.py build <workspace root> <out.json> [--names <dir>] [--definitions-dir <dir>]
py tools/mod_definition_set.py validate <set.json> [--names <dir>] [--definitions-dir <dir>] [--extract <dir>]
```

`build` reads the workspace's `project.json` and `manifest.json` read-only,
first runs the workspace check (`tools/validate_workspace_definitions.py`)
and refuses on any failure, requires every definition to share one mod id
and one revision and to carry the tracked fingerprints, assembles the
set, validates it, and publishes it by the delta's atomic hard-link rule
(an existing output is never replaced; the output must lie outside the
workspace and the tracked definitions directory). `validate` rechecks a
set and, with `--extract`, writes every document's canonical bytes to
`<dir>/<definition_id>.json` - the exact bytes `definition_sha256` hashes,
which is what an importer stages. Both print one JSON line and exit 0 or
1, like the delta tool.

The Godot importer, `tools/content_suite/cli/import_mod_definition_set.gd
SOURCE_ROOT WORKSPACE SET_JSON [--replace]`
(`tools/content_suite/mod_definition_set_import.gd`), validates the set
through the Python tool with `--extract`, rechecks the set file's hash
around that step and every extracted document's hash against its row,
opens the workspace, refuses a set whose mod id differs from the
workspace's, classifies every definition as `added`, `unchanged` (same id
and an equal document; the stored bytes and a set's canonical bytes differ
after any round trip, so bytes are never compared) or - with `--replace`
only - `replaced`, refuses the whole
import when a changed definition meets no `--replace`, and stages the
rest in one `stage_mod_definitions` call under the workspace's locks and
contract validator ([Content Workspace](content_workspace.md), "Mod
Definitions"). Nothing is staged when any refusal occurs.

## Verified 2026-09-19

`tests/test_mod_definition_set.py` (build, every tamper case, atomic
publication, `--extract`, the CLI exit codes) and
`tests/test_mod_definition_set_import.tscn` (a set built by the Python
tool from a synthetic authoring workspace; import adds one, a second
import reports it unchanged, a changed definition is refused without
`--replace` with the manifest byte-identical and replaced with it, a
foreign mod id and a tampered payload hash are refused before the
workspace changes).
