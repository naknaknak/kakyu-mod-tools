# MES authoring bundle

Scope update 2026-09-08: Event Player is original-only. The edited-Run UI
behavior documented below is historical; EP-08 owns its removal from the app.
Authoring bundles, semantic/coordinate proofs and headless package validation
remain supported by their owning tools. This decision changes no data schema
and does not claim that existing executable entry points have already changed.

`kakyu_mes_authoring_bundle/v9` is the current local editor bridge in Content
Core 0.329.0; v8 (Core 0.328.0) added control targets, v7 (Core 0.327.0)
shared-routine calls, v6 (Core 0.326.0) registered-definition calls, v5
(Core 0.325.0) choice options, v4 (Core 0.324.0) resource names, v3 (Core
0.322.0) condition literals, v2 (Core 0.304.0) variable-length messages,
and the state-only v1 bridge was introduced in 0.302.0. V9 makes a bundle
an ordered sequence of operations (Version 9 below).
`tools/mes_authoring_workflow.py` connects the
authoritative Python Phase 1-4 handoff to the existing Phase 5 editable
model and the state-literal, condition-literal, resource-name,
choice-option, registered-definition call, shared-routine call,
control-target and message/control-target-relocation planners, compilers
and semantic diffs. It does not introduce a second analyzer or compiler.

A bundle contains original source evidence and is not a distributable mod
package. Keep it below the user's local named workspace, outside the original
archive directory. Tracked examples contain only wholly authored fixtures.

The manifest has exactly `ok`, `schema`, `summary`, `files`, and
`payload_sha256`. Its fingerprint uses the existing Phase 6 canonical JSON
convention, excluding its own hash and retaining exact integer fields. The
sorted file inventory binds every member's safe fixed name, byte size and SHA256.

An inspection bundle contains `handoff.json`, `handoff.payload.json`, and
`editable.json`. The source identity is the original `mes.arc` name, safe MES
entry name, original-archive source kind and archive fingerprint. The summary
binds the source entry hash, actual Python handoff hash, compiled status and
typed literal state-write and strict CP932 message candidates. Candidate display is not compiler approval;
the existing planner validates the selected operation fully.

`handoff.payload.json` retains the exact canonical bytes signed by the Python
handoff producer, without the handoff's root `payload_sha256` field. Its raw
SHA256 must equal that field, and its parsed object must equal the remaining
handoff. This preserves integer-versus-float serialization: Godot's JSON reader
turns integer tokens into floats, so reserializing a parsed object cannot be
used to recalculate the authoritative handoff hash. The witness does not change
the handoff schema, producer identity, canonicalization or corpus baseline.

A compiled bundle additionally contains `plan.json`, `output.mes`,
`output.handoff.json`, `compile.audit.json`, and `semantic.diff.json`. Version 1
connects one `replace_state_write_literal` operation. Python reconstructs the
source from the validated handoff, compiles the exact same-width expression,
reopens the output through its authoritative analyzer, and rebuilds the semantic
proof. Bundle reopening reproduces every compiled member from the exact inputs.
The v2 message extension and the v3 condition-literal extension are described
below; other families and operation sequences remain MW-11 work.

Publication uses a unique sibling staging directory, exclusive file writes,
complete reopening, and rename to a new destination. Existing destinations are
refused. Failure cleanup is restricted to known files in that newly created
stage. A background process writes a separate result file; the app requires its
exit status and manifest identity to agree before accepting the result.

The MES Editor Authoring tab lists state candidates, accepts a new value, shows
the complete one-expression change, and publishes only a successful preview.
Before workspace publication it rechecks the selected source and generation,
independently reopens the compiled MES in Godot, binds the semantic proof to the
source/output identities, and compares the output directly with original bytes
outside the declared expression. Failed or stale input cannot overwrite an
existing user output or become an active edit.

The named workspace publishes the replacement under its shared locks and
reopens the effective content. MES Editor refreshes its launch-context generation
when loading its own workspace overlay, so a following Run request binds the
new generation. The generated semantic proof is selected automatically for
changed Analysis Run. Existing UTF-8 projections survive the same-width edit.
State and message edits support the source-bound
[contextual analysis Run](mes_contextual_run.md). Relocation and remaining
edit families are described below and in MW-11/WD-21; original-only Catalog Play
keeps its source guards.

Verification uses an actual Python background process and editor controls on
authored input: UTF-8 save → state preview → workspace publication → current
Run request → Event Player state effect. It covers stale publication, unrelated
byte mutation, source preservation and 1920x1080/2560x1440 layout. The original
EVENTB01 source-derived state edit at code offset `0x8F` separately reproduces
all 269 typed nodes during independent Godot reopening. This is compiler
validation, not confirmation of a new original scene meaning or GUI review.

## Version 2 message relocation

A message bundle adds `control.plan.json` to the compiled inventory. The
`replace_message` operation uses the existing message plan v1, control-target
plan v2, control-target compiler and semantic diff v4. It carries the source
message offset/hash, authored text, `encoding: cp932` and
`native_projection: require_match`. A replacement must change byte length,
round-trip through CP932 without Unicode aliases and retain safe text framing.
This framing condition prevents payload bytes becoming executable instructions;
it does not require native-engine execution. Unsupported shifted opaque records
and targets remain compiler blockers. Unicode translations remain separate.

The Authoring tab lists both families and shows the byte delta before publication.
The existing Godot control-target reopen validator independently reanalyzes the
output. `mes_authoring_binding.py` then rebuilds the authoritative input, plan,
output and full semantic proof from actual original/output bytes. Its versioned
`kakyu_mes_authoring_binding/v1` report binds their hashes and lists every record
start/end correspondence plus message raw hashes. It is local evidence, never
an archive-independent playback dependency. Godot verifies report identity and
fingerprint; its bounded cache is keyed by all three exact input hashes.

Only the Phase 6 audit JSON uses whole-number normalization for transport; the
Python handoff retains its separate canonical byte witness unchanged.

V1 bundles remain readable with their original inventory and summary. V2 writes
include `message_controls`; state-only v1 cannot contain a relocation plan.
Regeneration of the new manifest is the migration, without changing MES/proof
bytes. Each operation starts from the original; operation sequences and the
remaining structural UI families stay under MW-11.

The editor discovers a matching local bundle in `authoring/*` or
`.authoring/delta` when reopening a replacement. Original-coordinate translations
map only through reproduced message correspondences. An overlap with the changed
message is rejected before publication; translating a later unchanged message
is preserved at its new coordinate. Contextual Run and package export use the
same mapping. Verification is in `test_mes_message_authoring.py`, the matching
Godot scene and the original contextual authoring CLI's `--message-relocation`
mode. V1 state-operation semantics and proof hashes are preserved.

Background completion is accepted only if the selected operation and draft still
match the submitted operation. Default Analysis Run also verifies the relocation
proof and maps UTF-8 text before state/UI publication, then rechecks the named
workspace generation. A changed draft cannot make an older preview publishable.

Core 0.304.0 evidence: 98/98 local checks with 1,316 Python tests, six focused
original/authoring/package checks, and five final UI/Run/package checks. The
retained original delivery is `analysis/message-authored-delivery-final-20260908/`
and its matching log; it includes package v7 and a 1,017-byte authored delta v2.

## Version 3 condition literals

A v3 manifest summary adds `condition_controls` beside `state_controls` and
`message_controls`: one candidate per literal inside the condition of a typed
`branch_if_not_true` statement (command `0x0B`), carrying the operation
`{kind: replace_condition_literal, source_offset, instruction_raw_sha256,
literal_offset, value}`, the literal width, the instruction end and the
branch's false target. Candidate display is not compiler approval: the
existing condition-literal planner
(`kakyu_mes_condition_literal_edit_plan/v1`) validates the chosen edit fully
and the compiler (`kakyu_mes_condition_literal_compile_audit/v1`) keeps the
literal's width, the condition terminator and the false-target operand
exactly. The proof is the v2 byte-patch semantic diff (family
`condition_literal_edit`); no bundle member is added.

In Godot, the session selects the reopen validator by the compile audit's
schema - the state or the condition validator, or the control-target validator
when `control.plan.json` is present - and the pre-publication byte check reads
each family's patched range and source hash from a per-schema table
(`expression_start`/`expression_end` for state, `literal_start`/`literal_end`
for condition, both code-relative). Any other audit schema is refused before
publication. The Authoring tab lists the third family as `Condition literal`
with the literal's code offset and width, bounds the value control to the
literal's width, and previews the value change together with the branch's
preserved false target. Publication, workspace generation checks, translation
preservation and stale-draft refusal are the same as for state literals.

V1 and v2 bundles remain readable; their summaries omit the newer control
lists, and regenerating the manifest is the migration, without changing MES or
proof bytes. A condition edit requires a v3 bundle. The distributable form is
`kakyu_authored_mod_delta/v3` (`docs/spec/data/authored_mod_delta.md`), which
admits the condition operation and keeps v1/v2 readable.

Verification (2026-09-15): `tests/test_mes_authoring_workflow.py` (condition
candidate listing, compile and reopened proof, stale/out-of-width/unknown
rejections, publication and v2/v1 legacy round trips),
`tests/test_authored_mod_delta.py` (condition delta build, validate and
reconstruct; a condition operation under the v2 label is rejected) and the
Godot scene `tests/test_mes_condition_authoring.tscn`, which drives the whole
editor flow on a synthetic branch (preview, byte-exact source check against
the audit's literal bounds, single-byte output difference, publication,
translation preservation, stale refusal, Run refusal, delta export and
import). Core 0.322.0 evidence: 18 focused Python tests across the three
modules, 1,435 Python regression tests and six focused Godot scenes (state 17,
message 22 and condition 20 checks, both reopen validators 9 each, MES Editor
153); the original EVENTB03 contextual authoring checks (edited event and
relocated message) pass against the archive. The contextual-run probe stays
state-only. Resource, choice, call, control-target and address-entry controls,
the proposed-operation list and operation sequences remain MW-11.

## Version 4 resource names

A v4 manifest summary adds `resource_controls` beside the three earlier
lists: one candidate per strictly indexed resource reference the editable
model carries - an MMO marker, an AX marker or a voice marker, each one
`0x0D` system-call record since Core 0.316.0 - with the operation `{kind: replace_resource_name,
source_offset, instruction_raw_sha256, reference_id, name}`, the resource
kind, the normalized name, the name's byte length, its extension, the
archive candidates and the instruction end. Candidate display is not
compiler approval: the existing resource-name planner
(`kakyu_mes_resource_name_edit_plan/v1`) requires the replacement to keep
the byte length and the extension and to be a safe entry name, and the
compiler (`kakyu_mes_resource_name_compile_audit/v1`) keeps the marker's
prefix and suffix bytes exactly, so only the name bytes change. The proof
is the v2 byte-patch semantic diff (family `resource_name_edit`); no bundle
member is added.

In Godot, the session selects the resource reopen validator by the compile
audit's schema and reads the patched range from the per-schema table
(`name_start`/`name_end`, code-relative, with `source_name_sha256`). The
Authoring tab lists the fourth family as `Resource name (<kind>)` with the
name's byte length and archive candidates, edits the name in the same text
control the messages use, and previews the name change with the preserved
length and extension. Publication, workspace generation checks, translation
preservation and stale-draft refusal are the same as for the other
families.

V1, v2 and v3 bundles remain readable; their summaries omit the newer
control lists, and regenerating the manifest is the migration, without
changing MES or proof bytes. A resource edit requires a v4 bundle. The
distributable form is `kakyu_authored_mod_delta/v4`
(`docs/spec/data/authored_mod_delta.md`), which admits the resource
operation and keeps v1-v3 readable.

Verification (2026-09-16): `tests/test_mes_authoring_workflow.py` (resource
candidate listing, compile and reopened proof, stale / wrong-reference /
length / extension / unsafe-name / unknown rejections, publication and
v3/v2/v1 legacy round trips), `tests/test_authored_mod_delta.py` (resource
delta build, validate and reconstruct; a resource operation under the v3
label is rejected) and the Godot scene `tests/test_mes_resource_authoring.tscn`,
which drives the whole editor flow on a synthetic MMO marker (preview,
byte-exact source check against the audit's name bounds, single-byte output
difference, publication, translation preservation, stale refusal, Run
refusal, delta export and import). Core 0.324.0 evidence: 25 focused
Python tests across the three modules, 1,492 Python regression tests,
six focused Godot scenes (state 17, message 22, condition 21 and resource 21 checks, the resource reopen validator 9, MES Editor 153), and the original EVENTB03 contextual authoring checks (edited event and relocated message) pass against the archive. The contextual-run probe stays state-only. Choice, call,
control-target and address-entry controls, the proposed-operation list and
operation sequences remain MW-11.

## Version 5 choice options

A v5 manifest summary adds `choice_controls`: one candidate per definition of
every routine-40 grouped registry the entry's address table holds - the
command-`0x1B` group clears and command-`0x10` registrations the choice-group
proof (`kakyu_mes_choice_group_authoring_proof/v1`) binds - with the
operation `{kind: replace_choice_option_cp932_same_length, group_selector,
definition_id, source_payload_sha256, text, encoding}`, the address entry
index, the payload size and the payload's code-relative range. The lister
decodes the entry once and proves only the address entries that carry a
group clear; today that shape exists in the town date menu `43C.MES`
(address entry 148, seven groups, 44 option texts), and none of the EVENT
callees' own questions has it, so a plain event lists no choice candidate.
Candidate display is not compiler approval: the existing choice-option
planner (`kakyu_mes_choice_option_edit_plan/v1`) requires the replacement
to encode to exactly the source payload length and to differ from it, and
the compiler (`kakyu_mes_choice_option_compile_audit/v1`) rebuilds the whole
grouped proof over the output, keeping every group, result, terminal and
resume coordinate. The proof is the v2 byte-patch semantic diff (family
`choice_option_edit`); no bundle member is added.

In Godot, the session selects the choice reopen validator by the compile
audit's schema and reads the patched range from the per-schema table, which
now names the audit section as well (`patch.code_start`/`patch.code_end`
with `source_payload_sha256`; the earlier families stay under `target`).
The Authoring tab lists the fifth family as `Choice option` with its group,
definition and byte length, edits the text in the same control the messages
use, and previews the change with the preserved length. Publication,
workspace generation checks, translation preservation and stale-draft
refusal are the same as for the other families.

V1-v4 bundles remain readable; their summaries omit the newer control lists,
and regenerating the manifest is the migration, without changing MES or
proof bytes. A choice edit requires a v5 bundle. The distributable form is
`kakyu_authored_mod_delta/v5` (`docs/spec/data/authored_mod_delta.md`),
whose per-version table of admitted operation kinds keeps v1-v4 readable.

Verification (2026-09-16): `tests/test_mes_authoring_workflow.py` (choice
candidate listing on the prover's synthetic grouped fixture, compile and
reopened proof, stale / wrong-definition / length / unchanged / non-CP932 /
unknown rejections, publication and v4..v1 legacy round trips),
`tests/test_authored_mod_delta.py` (choice delta build, validate and
reconstruct; a choice operation under the v4 label is rejected; the
message operation validates under every label since v2) and the Godot
scene `tests/test_mes_choice_authoring.tscn`, which drives the whole editor
flow on the grouped fixture. Core 0.325.0 evidence: 40 focused
Python tests across the authoring modules, 1,503 Python regression
tests, nine focused Godot scenes (state 17, message 22, condition 21, resource 21 and choice 21 checks, the choice plan and reopen validators 8 each, the semantic diff 15, MES Editor 153), and the original EVENTB03 contextual authoring checks (edited event and relocated message) pass against the archive, while a probe over the real `43C.MES` lists the 44 options of entry 148 (payloads of 12 to 20 bytes), compiles group 0 definition 0 with a same-length text (20 bytes changed at entry-absolute 0x4B5F..0x4B73, nothing else), publishes the v5 bundle and reads it back. The contextual-run probe stays state-only. Call,
control-target and address-entry controls, the proposed-operation list and
operation sequences remain MW-11.

## Version 6 registered-definition calls

A v6 bundle may carry one more source member, `registry.proof.json`: the
registered-definition registry proof
(`kakyu_mes_registered_definition_registry_proof/v1`) of the archive's
`DEF_MAIN.MES`, which the `inspect` command builds from the same archive
(today the only registry entry; it registers selectors 11, 12, 14, 15, 17,
18, 20, 21, 22, 23, 26, 80, 81 and 99). The member must belong to the
handoff's archive; a bundle without it lists no call candidate and refuses
the family. The manifest summary adds `call_controls`: one candidate per
`registered_definition_call_site` of the entry's call-family proof
(`kakyu_mes_call_family_proof/v1`, rebuilt from the handoff) whose selector
is an 8-bit literal with an exact physical resume - the operation `{kind:
replace_registered_definition_literal, source_offset,
instruction_raw_sha256, selector}`, the call's end and physical resume, and
the registry's selectors. Candidate display is not compiler approval: the
existing planner (`kakyu_mes_registered_definition_call_edit_plan/v1`)
requires both the source and the replacement selector to be registered with
exact command-14 body boundaries, and the compiler
(`kakyu_mes_registered_definition_call_compile_audit/v1`) changes the one
literal byte, keeping the call's physical resume and every other coordinate.
The proof is the v2 byte-patch semantic diff (family
`registered_definition_call_edit`). The shared-routine call (command `0x1D`)
is not in this version: its planner needs the library audit that only the
Godot side produces, and it follows as its own unit.

In Godot, the session selects the registered-call reopen validator by the
compile audit's schema and reads the literal range from the per-schema
table. The Authoring tab lists the sixth family as `Registered definition
call` with the current selector and the registry's selectors, edits the
selector in the numeric control, and previews the change with the
replacement's registry body. Publication, workspace generation checks,
translation preservation and stale-draft refusal are the same as for the
other families.

V1-v5 bundles remain readable; their summaries omit the newer control lists,
a legacy bundle cannot carry the registry member, and regenerating the
manifest is the migration. A registered-call edit requires a v6 bundle. The
distributable form is `kakyu_authored_mod_delta/v6`
(`docs/spec/data/authored_mod_delta.md`), which names the original entries
a reconstruction needs beside the source.

Verification (2026-09-17): `tests/test_mes_authoring_workflow.py` (registered
call candidate listing against a synthetic two-registration registry,
compile and reopened proof, stale / unregistered / unchanged / unknown
rejections, a bundle without the registry member, publication and v5..v1
legacy round trips), `tests/test_authored_mod_delta.py` (registered-call
delta build with its DEF_MAIN.MES dependency, validate, reconstruct with
and without the dependency payload; a registered-call operation under the
v5 label is rejected) and the Godot scene
`tests/test_mes_registered_call_authoring.tscn`, which drives the whole
editor flow on a two-entry synthetic archive. Core 0.326.0 evidence:
42 focused Python tests across the authoring modules, 1,512
Python regression tests, ten focused Godot scenes (state 17, message 22, condition 21, resource 21, choice 21 and registered call 27 checks, the registered-call plan and reopen validators 8 each, the semantic diff 15, MES Editor 153) and the local batch (105 checks), and the original EVENTB03 contextual authoring checks (edited event and relocated message) pass against the archive, while the real CLI flow on `EVENTD14.MES` builds a v6 bundle with the `DEF_MAIN.MES` registry proof, lists its eight registered calls (selectors 21 and 22), compiles selector 21 to 22 in one byte, builds the v6 delta with its dependency and reconstructs it from the archive to the same output hash. The contextual-run probe stays
state-only. The shared-routine call, control-target and address-entry
controls, the proposed-operation list and operation sequences remain MW-11.

## Version 7 shared-routine calls

A v7 bundle may carry a second Godot-built source member,
`library.audit.json`: the library audit (`kakyu_mes_library_audit/v17`) of
the archive's `LIBLARY.LIB` - every registered routine's strict and
structural decode, native dispatch flow and return offsets - built by the
Godot side (`tools/content_suite/mes_library_audit_report.gd`, the same
builder the decompiler handoff spool uses) before `inspect` runs and handed
to Python as `--library-audit`; Python verifies it against the archive's
`LIBLARY.LIB` hash and keeps it as a member (3.7 MB on the real archive).
The manifest summary adds `shared_call_controls`: one candidate per proved
call of the shared-call return proof (`kakyu_mes_shared_call_return_proof/v2`,
rebuilt from the handoff and the audit) - a `script_transfer` (command
`0x1D`) whose 8-bit literal names a routine with a total-return certificate
- carrying the operation `{kind: replace_shared_routine_literal,
source_offset, instruction_raw_sha256, routine_id}`, the call's end and
physical resume, the callee body and the routine ids a replacement may use
(33 of the 43 library routines today; the ten others have cyclic or
non-total-return bodies and their calls are listed by the proof as
unresolved, never as candidates). Candidate display is not compiler
approval: the planner (`kakyu_mes_shared_routine_call_edit_plan/v1`)
requires the replacement to differ and to hold a total-return certificate,
and the compiler (`kakyu_mes_shared_routine_call_compile_audit/v1`) changes
the one literal byte, keeping the call's physical resume and every other
coordinate. The proof is the v2 byte-patch semantic diff (family
`shared_routine_call_edit`).

In Godot, the session builds the audit, selects the shared-call reopen
validator by the compile audit's schema and reads the literal range from
the per-schema table; the delta importer builds the same audit before a
reconstruction. The Authoring tab lists the seventh family as `Shared
routine call` with the current routine and the replaceable ids, edits the
id in the numeric control, and previews the change with the replacement's
library body. Publication, workspace generation checks, translation
preservation and stale-draft refusal are the same as for the other families.

V1-v6 bundles remain readable; a legacy bundle cannot carry the library
member. A shared-call edit requires a v7 bundle. The distributable form is
`kakyu_authored_mod_delta/v7` (`docs/spec/data/authored_mod_delta.md`), whose
`dependencies` name `LIBLARY.LIB` and whose reconstruction needs the
Godot-built audit.

Verification (2026-09-17): `tests/test_mes_authoring_workflow.py` (shared-call
candidate listing against a synthetic two-routine audit, compile and
reopened proof, stale / absent-routine / unchanged / foreign-audit /
unknown rejections, a bundle without the member, publication and v6..v1
legacy round trips), `tests/test_authored_mod_delta.py` (shared-call delta
build with its `LIBLARY.LIB` dependency, validate, reconstruct with the
audit and without it), the Godot scenes
`tests/test_mes_library_audit_report.tscn` and
`tests/test_mes_shared_call_authoring.tscn` (the whole editor flow on a
synthetic archive with a two-routine library, delta export and import
included). Core 0.327.0 evidence: 50 focused Python tests across the
authoring modules, 1,520 Python regression tests, twelve focused Godot scenes (library audit report 12, state 17, message 22, condition 21, resource 21, choice 21, registered call 27 and shared call 27 checks, the shared-routine-call plan and reopen validators 8 each, the semantic diff 15, MES Editor 153) and the local batch (107 checks), and
the original EVENTB03 contextual authoring checks (edited event and relocated message) pass against the archive, while the real CLI flow on `EVENTB14.MES` builds the 43-routine `LIBLARY.LIB` audit on the Godot side (3.7 MB, under one second), builds a v7 bundle carrying it, lists its 103 proved shared-routine calls (routines 0, 21, 23, 27, 28, 32 and 33), changes one call's routine id in one byte, builds the v7 delta with its `LIBLARY.LIB` dependency and reconstructs it from the archive and the audit to the same output hash. The spool exporter's library audit is byte-identical before and after the extraction. The contextual-run probe stays state-only. Control-target and
address-entry controls, the proposed-operation list and operation
sequences remain MW-11.

## Version 8 control targets

The manifest summary adds `control_target_controls`: one candidate per
typed control transfer whose target the control-target planner
(`kakyu_mes_control_target_edit_plan/v1`) can retarget - a
`branch_if_not_true` (command `0x0B`, its trailing u32 false target) or a
`continuation_transfer` (command `0x0C`, `0C <u32>`) that is a unique
strict typed instruction start with exactly one aligned in-code reference
of that kind, whose current target is itself a unique strict typed
instruction start. The row carries the operation `{kind:
retarget_control_flow, source_offset, reference_kind,
source_instruction_raw_sha256, replacement_target_offset}` with the current
target as the replacement (an unedited row is rejected as unchanged), the
current target's operation name, the transfer's end and the code size. The
editor edits the replacement offset in the numeric control; when the
operation reaches `compile_edit` without
`replacement_target_instruction_raw_sha256`, the workflow fills it from the
unique typed node at that offset and refuses an offset that is not one.
Candidate display is not compiler approval: the planner re-checks the
source form, the reference, both targets and both hashes, and the compiler
(`kakyu_mes_control_target_edit_compile_audit/v1`) rewrites the four-byte
little-endian operand only, keeping the transfer's other bytes and every
other coordinate. The proof is the v2 byte-patch semantic diff (family
`control_target_edit`). No new bundle member: the family needs nothing
beyond the entry.

In Godot, the session selects the control-target reopen validator by the
compile audit's schema and reads the whole transfer instruction from the
per-schema table (`source_control`, `instruction_start`..`instruction_end`,
`source_instruction_sha256`); the compiled output differs only inside that
instruction. The Authoring tab lists the eighth family as `Control target`
with the reference kind and the current target, edits the replacement
offset in the numeric control bounded by the code size, and previews the
change with the replacement's operation name. Publication, workspace
generation checks, translation preservation and stale-draft refusal are
the same as for the other families.

V1-v7 bundles remain readable and list no control-target candidates. A
control-target edit requires a v8 bundle. The distributable form is
`kakyu_authored_mod_delta/v8` (`docs/spec/data/authored_mod_delta.md`),
with no `dependencies` row.

Verification (2026-09-17): `tests/test_mes_authoring_workflow.py`
(control-target candidate listing on a continuation and a branch entry,
compile with the filled replacement hash and reopened proof, unchanged /
non-instruction / out-of-code / stale-source / wrong-replacement-hash /
bad-kind rejections, publication and v7..v1 legacy round trips),
`tests/test_authored_mod_delta.py` (control-target delta build, validate,
reconstruct, v7 relabel rejected), the Godot scene
`tests/test_mes_control_target_authoring.tscn` (the whole editor flow on a
synthetic continuation entry, delta export and import included). Core
0.328.0 evidence: 57 focused Python tests across the authoring
modules, 1,527 Python regression tests, eleven focused Godot scenes (state 17, message 22, condition 21, resource 21, choice 21, registered call 27, shared call 27 and control target 27 checks, the control-target reopen validator 9, the semantic diff 15, MES Editor 153) and the local batch (108 checks), and
the original EVENTB03 contextual authoring checks (edited event and relocated message) pass against the archive, while the real CLI flow on `EVENTB14.MES` builds a v8 bundle, lists its 56 control-target candidates (37 false targets, 19 continuations), retargets the first branch's false target from 0x905 to 0x90F in one byte, builds the v8 delta with no dependency and reconstructs it from the archive to the same output hash. The contextual-run probe stays state-only. The
address-entry family stays unexposed by owner ruling (2026-09-17: its
backend inserts a bare table cell, which contradicts the `0x17`
entry-prologue rule of `docs/spec/mes/format_and_method.md`); the
proposed-operation list and operation sequences are Version 9.

## Version 9 operation sequences

A v9 bundle compiles an ordered sequence of one or more operations as a
chain: step 1 on the original entry, step k on step k-1's output,
re-analysed by the authoritative analyzer between steps, every step through
the same single-operation engine the earlier versions proved. Same-size
steps keep every code coordinate, so the candidates listed from the
original stay valid for every later step; a second operation on an
instruction already edited is rejected by that step's planner as stale (the
error names the step: "Step 2 (replace_state_write_literal at 0x76): ...");
a message relocation changes coordinates and is admitted only as the last
step. Measured on `EVENTB14.MES`, a four-step chain (condition literal,
state literal, control target, then a one-character-longer message) takes
about 1.4 s of planning and compiling plus about 1.3 s of re-analysis per
step; after each same-size step the candidate lists are identical except
the edited instruction's rows. Reopening recompiles the sequence as its
integrity check, so the CLI round trip of that chain is about 41 s
(Version 9 evidence below).

Layout. `sequence.json` (`kakyu_mes_authoring_sequence/v1`) lists the
steps in order with each step's operation, source/output entry hashes and
plan / compile-audit / semantic-diff (/ control-plan) hashes, and is
fingerprinted like the manifest. A one-step v9 bundle is the v8 layout plus
`sequence.json`, so every single-operation consumer (the local proof lookup,
contextual Run, package export, delta readers) is unchanged. A bundle of two
or more steps is "stepped": the top level holds the final `output.mes` and
`output.handoff.json`, `sequence.json`, the source members, and as
`semantic.diff.json` the chain proof `kakyu_mes_semantic_diff_chain/v1`
(`tools/diff_mes_sequence_semantics.py`; Godot
`content_core/mes_semantic_diff_chain.gd`): source and output bindings, one
row per step (kind, family, proof and audit schemas and hashes, source and
output hashes, byte delta), and a composition block naming the relocation
step (or none) and the same-size patches in original coordinates. Each
step's plan, compile audit, semantic diff, output and output handoff live
in `step-NN.*` members, plus `step-NN.control.plan.json` for a relocation.
A stepped bundle has no top-level plan or compile audit, so no
single-operation consumer can mistake a step proof for an original-to-final
proof; contextual Run and the package export accept stepped bundles
through the chain proof since Core 0.330.0
(`docs/spec/data/workspace_playback_export.md`). The
manifest summary adds `step_count` and the ordered `operations`.
Reopening recompiles the whole sequence from `sequence.json` and requires
identical members; Godot reopens every step with that step's reopen
validator, validates every step proof and the chain proof, and checks the
hash chain; publication validates the source step by step (a relocation's
coordinate binding reaches the editor as before). V1-v8 bundles remain
readable as one-step bundles; a legacy label cannot carry `sequence.json`.

The Authoring tab gains the proposed-operation list: `Add to list` stages
the selected candidate with its edited value, refusing a duplicate
coordinate; `Remove selected` and `Clear list` edit it; `Preview change`
compiles the list in order (or the single selected edit when the list is
empty) and reports each step's status, the failing step's error, and the
final output size; `Publish to workspace` publishes the compiled sequence.
The distributable form is `kakyu_authored_mod_delta/v9`
(`docs/spec/data/authored_mod_delta.md`), whose `operations` carry the
sequence and whose `dependencies` are the union over its operations.

Verification (2026-09-17): `tests/test_mes_authoring_sequence.py` (one-step
equivalence with the single engine, a three-step chain on a synthetic entry
- state literal, control target, then a relocation - with the designed
layout, chained hashes, a validated chain proof and the hand-computed final
bytes, relocation-not-last / already-edited-instruction / empty /
tampered-sequence / missing-member rejections, v8 legacy reads and the
refused relabel), `tests/test_authored_mod_delta.py` (three-operation
delta build, validate, reconstruct, v8 relabel rejected), the Godot scenes
`tests/test_mes_sequence_authoring.tscn` (the whole editor flow: stage
three edits, preview, publish, delta export and import) and
`tests/test_mes_semantic_diff_chain.tscn`. Core 0.329.0 evidence:
70 focused Python tests across the authoring modules, 1,540
Python regression tests, twelve focused Godot scenes (sequence 24, chain proof 10, state 17, message 22, condition 21, resource 21, choice 21, registered call 27, shared call 27, control target 27, the semantic diff 15, MES Editor 153 checks) and the local batch (110 checks), and
the original EVENTB03 contextual authoring checks (edited event and relocated message) pass unchanged against the archive. The real CLI flow on `EVENTB14.MES` compiles the four-operation sequence (condition literal, state literal, control target, relocated message) into a stepped v9 bundle with the chain proof (final size 10,835 bytes; about 41 s including the reopen recompile), reads it back, builds the v9 delta with four operations and no dependency, and reconstructs it from the archive to the same final output and chain-proof hashes. Contextual Run and the package export accept every family and every stepped bundle since Core 0.330.0.
