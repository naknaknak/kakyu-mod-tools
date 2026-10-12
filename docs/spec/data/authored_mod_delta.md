# Authored mod delta

`kakyu_authored_mod_delta/v9` is the current distributable change format. Its exact
key allowlist carries an original archive/entry identity, source/output hashes,
an ordered list of state-literal, condition-literal, resource-name, choice-option, registered-definition call, shared-routine call, control-target or variable-length CP932 message operations (`operations`; a message relocation only last), a reproduced semantic-proof hash,
the original entries a reconstruction needs beside the source (`dependencies`),
authored UTF-8 message edits and explicit core compatibility requirements.
Its payload hash covers all those fields. ARC/MES files, raw instruction bytes,
original message text, handoffs and opaque payloads are excluded. Extra fields,
unsupported versions, invalid text coordinates and changed hashes fail closed.

`tools/authored_mod_delta.py build` verifies a local compiled authoring bundle
against the actual original before emitting the small delta. Atomic hard-link
publication only creates a new file; existing outputs survive retries/races.
`reconstruct` validates the matching local original, reruns authoritative Python
analysis and compilation, and requires identical output and semantic-proof hashes.
The reconstructed bundle contains local evidence and is not distributable.

`tools/content_suite/cli/import_authored_mod_delta.gd` takes the original content
set, a matching source workspace as its project template, the delta file and a
new destination. It constructs a fresh named workspace in staging, independently
reopens the Python result in Godot, stages the replacement and UTF-8 edits,
refreshes the workspace, then renames only to an unused destination under a
publication lock. The template workspace is unchanged. Failed staging is retained
as local evidence and is never published as the destination. This is a headless
bounded importer, not merge/conflict UI.

Since WD-10 (2026-10-11) `authored_delta_import.gd` is one staged-import engine
(`import_members`) with two front doors. `import_delta` is the one-member plan
described above; its result and messages are unchanged. The second is
`tools/content_suite/mod_bundle_import.gd`, which imports a
[`kakyu_mod_bundle/v1`](mod_bundle.md) - the multi-entry form: one v9 delta per
authored entry, the translation-only entries and the definition set - into one
fresh workspace, with one staging transaction per kind, a reopen check of every
effective identity before publication, and the same lock-and-rename rule. Both
reconstruct each delta through the same per-delta steps. The engine also
reopens the stage and verifies the replaced entry's effective hash and the
projection's edits, for a single delta as well.

The original EVENTB03 delivery regression builds the actual delta, imports it
into a second workspace, reopens it against the originals and verifies identical
effective MES and UTF-8 text. Existing destination rejection and source archive
preservation pass. Evidence and reviewable outputs are retained under
`analysis/authored-delivery-20260908/`; the local log is
`analysis/authored-delivery-20260908.log`. Three Python test cases additionally
cover rehashed field injection, invalid operations/text bindings, wrong sources,
changed outputs, tampering and atomic publication.

V2 requires Core 0.304.0 and admits the exact `replace_message` operation fields
from the existing message planner. Only the replacement text is authored data;
source/raw instruction bytes and the local plans are not copied into the delta.
A UTF-8 edit overlapping the replaced CP932 message is rejected. Other UTF-8
edits retain original coordinates/hashes so reconstruction can verify the source
before mapping them for execution and export.

V3 (2026-09-15) requires Core 0.322.0 and admits the exact
`replace_condition_literal` operation fields from the condition-literal
planner (`source_offset`, `instruction_raw_sha256`, `literal_offset`,
`value`). Like the state operation it carries no instruction bytes;
reconstruction reruns the planner and compiler against the matching original
and requires the identical output and semantic-proof hashes.

V4 (2026-09-16) requires Core 0.324.0 and admits the exact
`replace_resource_name` operation fields from the resource-name planner
(`source_offset`, `instruction_raw_sha256`, `reference_id`, `name`); the name
must be a safe entry name, and reconstruction reruns the planner, which
requires the same byte length and extension as the source name.

V5 (2026-09-16) requires Core 0.325.0 and admits the exact
`replace_choice_option_cp932_same_length` operation fields from the
choice-option planner (`group_selector`, `definition_id`,
`source_payload_sha256`, `text`, `encoding` "cp932"); reconstruction reruns
the grouped proof, the planner and the compiler against the matching
original, which requires the same payload length.

V6 (2026-09-17) requires Core 0.326.0 and admits the exact
`replace_registered_definition_literal` operation fields from the
registered-definition call planner (`source_offset`,
`instruction_raw_sha256`, `selector`). It adds `dependencies`: the original
entries a reconstruction needs beside the source, as `{entry, entry_sha256}`
rows - empty for every other kind, and for a registered call exactly the
archive's `DEF_MAIN.MES` with its hash. Reconstruction loads each dependency
from the archive, refuses a missing or changed one, rebuilds the registry
proof and the call-family proof, and reruns the planner and compiler.

V7 (2026-09-17) requires Core 0.327.0 and admits the exact
`replace_shared_routine_literal` operation fields from the shared-routine
call planner (`source_offset`, `instruction_raw_sha256`, `routine_id`); its
`dependencies` row names `LIBLARY.LIB` with its hash. Reconstruction of a
shared-call delta needs the Godot-built library audit of that entry
(`kakyu_mes_library_audit/v17`, passed to the CLI as `--library-audit`),
whose entry hash must match the dependency and the archive; the Godot delta
importer builds it before reconstructing.

V8 (2026-09-17) requires Core 0.328.0 and admits the exact
`retarget_control_flow` operation fields from the control-target planner
(`source_offset`, `reference_kind`, `source_instruction_raw_sha256`,
`replacement_target_offset`, `replacement_target_instruction_raw_sha256`);
`reference_kind` is one of the planner's supported forms
(`condition_false_target`, `continuation_target`) and the operation names
no dependency. Reconstruction needs only the original entry.

V9 (2026-09-17) requires Core 0.329.0 and replaces the single `operation`
with `operations`: the bundle's ordered sequence (one or more; a
`replace_message` only last), each validated by its kind's rules, with no
new kind. `dependencies` is the union over the operations (`DEF_MAIN.MES`
for a registered call, `LIBLARY.LIB` for a shared call), deduplicated.
`semantic_diff_sha256` names the bundle's top-level proof: the step proof
of a one-step sequence, the chain proof
(`kakyu_mes_semantic_diff_chain/v1`) of a longer one. Reconstruction reruns
the whole chain against the matching original and requires the identical
final output and proof hashes; the Godot importer reopens the stepped
bundle step by step.

The operation kinds each version admits are one table: v1 the state
literal; v2 adds the message; v3 the condition literal; v4 the resource
name; v5 the choice option; v6 the registered-definition call; v7 the
shared-routine call; v8 the control target; v9 admits the same kinds as an
ordered list. Every older version remains readable with its own core
requirement, its own exact key set and its single operation (v8 0.328.0,
v7 0.327.0, v6 0.326.0, v5 0.325.0, v4 0.324.0, v3 0.322.0, v2 0.304.0, v1
0.303.0). Rebuilding a delta emits v9. Reconstruction keeps the original
output/proof hash requirements for every version; changing the format
label never makes newer operations valid in an older version - a
multi-operation document under the v8 or any older label, a control-target
operation under the v7 label, a shared-call operation under the v6 label, a
registered-call operation under the v5 label, a choice operation under the
v4 label, a resource operation under the v3 label, or a condition operation
under the v2 or v1 label, is rejected.
