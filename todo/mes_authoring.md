# MES Compiler and Authoring TODO

This tracker owns Phase 6 compilation and the editor-side portion of Phase 7
translation/event modding. It consumes the stable analyzer/decompiler model but
does not redefine original instruction meaning. Phase definitions and default
order live in `mes_pipeline.md`.

## Implemented Baseline

- [x] Read-only container/address/disassembly/reference/CFG analysis.
- [x] Strict CP932 message rows, UTF-8 overlay projections, and transactional
  hot reload.
- [x] Narrow equal-length CP932 binary replacement with reopen and preservation
  checks; this is a patcher prototype, not a general compiler, and
  original-engine compatibility remains manually unverified.

## Authoring Target

Per [Stance Toward the Original Game](../docs/spec/tech/original_source_stance.md),
authored output targets the remake runtime. Variable-length UTF-8 is therefore
the normal authoring path, not a fallback, and the equal-length CP932
constraint is no longer a goal to satisfy — it stays implemented and reported
for a possible future audience change. New modded events do not have to be MES
at all; this tracker's compiler remains the right tool for editing existing
original entries.

## Phase 6 — Relocating Compiler Backend

The Phase 6 gate requires a byte-identical no-op rebuild and safe relocation.
The existing equal-length patcher does not close this gate.

- [x] **MW-01 — Stabilize an editable lossless MES IR and no-op compiler.**
  - Preserve known instructions, opaque records, entries, strings, calls,
    targets, and provenance through a no-op transformation.
  - Require unchanged supported input to assemble byte-identically and reopen
    through the Phase 1-4 analyzer contract.
  - [x] Freeze `kakyu_mes_editable_ir/v1` as an immutable embedded Phase 5
    source plus ordered operations, and implement the operation-free Python
    compiler/audit with exclusive new-file publication and explicit rejection
    of every unimplemented edit.
  - [x] Reopen the no-op output through the current GDScript Phase 1-4 analyzer
    contract and cross-check its Python audit fingerprint, container hashes,
    typed/opaque partition, alignment, and handoff.
  - [x] Complete the authoritative corpus no-op audit.
- [x] **MW-02 — Implement relocatable message assembly.**
  - Support variable-length CP932 and remake-only UTF-8 changes while repairing
    tables, following records, and references.
  - [x] Freeze `kakyu_mes_message_relocation_plan/v1` as a JSON-only,
    fail-closed preflight that binds one variable-length CP932 edit to its
    unique typed message owner and plans node, region, address-table, and
    reference coordinate shifts without publishing MES bytes.
  - [x] Assemble and reopen a relocation-ready CP932 plan while preserving all
    unaffected typed records byte-for-byte.
  - [x] Define the distinct remake-only UTF-8 overlay operation; do not encode
    UTF-8 bytes into an original-compatible MES container.
- [x] **MW-03 — Implement branch and continuation relocation.**
  - Reject unresolved or non-instruction targets before publication.
  - [x] Freeze `kakyu_mes_control_target_relocation_plan/v1` as a JSON-only
    augmentation of the immutable MW-02 message plan. Resolve only exact
    command-`0x0B` trailing and command-`0x0C` command-plus-one little-endian
    `u32` operands whose old targets are aligned typed instruction starts;
    retain every unsupported blocker and publish no MES bytes.
  - [x] Apply the validated control-target patches during message assembly and
    reject overlaps, stale bytes, out-of-range output targets, or any remaining
    blocker before exclusive publication.
  - [x] Extend the augmentation as
    `kakyu_mes_control_target_relocation_plan/v2`, requiring every shifted
    command-`0x10` definition-skip target to be decoded from its exact trailing
    little-endian `u32`, relocated, and independently reopened at an aligned
    typed instruction start.
  - [x] Reopen a source-bound changed entry across Python and current GDScript
    Phase 1-4 contracts, then close MW-03 with proportionate corpus coverage.
- [x] **MW-04 — Add structured resource/state/condition editing.**
  - [x] Freeze `kakyu_mes_state_literal_edit_plan/v1` as a JSON-only,
    fail-closed plan for one exact literal expression inside a typed state-write
    run. Bind the instruction hash and pair index, preserve the destination,
    continuation, width, length, and every unrelated byte, and publish no MES
    bytes.
  - [x] Assemble and reopen a validated same-width state-literal edit.
  - [x] Freeze `kakyu_mes_condition_literal_edit_plan/v1` as a JSON-only,
    fail-closed plan for one exact same-width literal token inside a typed
    conditional branch. Bind the instruction hash, AST source offset, condition
    terminator, and indexed false-target reference and operand; publish no MES
    bytes.
  - [x] Assemble and reopen a validated same-width condition-literal edit.
  - [x] Add a structured resource edit contract without assigning semantic
    names to unresolved numeric operands.
    - [x] Freeze `kakyu_mes_resource_name_edit_plan/v1` for one exact
      same-length printable-ASCII name inside a strict-indexed typed MMO, AX,
      or voice marker. Bind the resource reference and preserve every prefix,
      suffix, selector, and other numeric byte without adding a semantic label;
      inline MES/LIB execution names remain owned by MW-05.
    - [x] Assemble and reopen a validated same-length resource-name edit.
- [x] **MW-05 — Add choice, DEF, library, and nested-call editing.**
  - [x] Add same-length inline `.LIB`/`.MES` execution-target editing. Preserve
    selector 2/3, the selector-specific extension and role, the exact double-NUL
    envelope, and every byte outside the name. Accept either a strict typed
    instruction or the already indexed bounded envelope inside one preserved
    opaque owner; do not claim the replacement exists or executes natively.
    - [x] Freeze `kakyu_mes_inline_script_name_edit_plan/v1` as a JSON-only
      preflight bound to the indexed reference, containing-node hash, exact
      selector envelope, and same-length extension-preserving replacement.
    - [x] Assemble and reopen a validated inline script target edit while
      retaining the containing typed/opaque partition and reindexed reference.
  - [x] Add literal shared-library routine-call target editing only where the
    command-`0x1D` expression and the indexed callee/resume evidence are exact.
    - [x] Freeze `kakyu_mes_shared_routine_call_edit_plan/v1` as a JSON-only
      same-width preflight. Bind the typed call, literal token, unique physical
      resume node, source total-return call certificate, and replacement
      routine's total-return certificate; publish no MES bytes.
    - [x] Assemble and reopen a validated shared-routine literal edit while
      retaining the caller partition, physical resume, and replacement callee
      certificate.
  - [x] Add registered-DEF invocation and body-boundary editing without
    conflating command-`0x10` choice bodies with command-`0x14` context keys.
    - [x] Freeze `kakyu_mes_registered_definition_registry_proof/v1` from one
      source-bound zero-start command-`0x14` registration path. Retain each
      literal selector, exact `[body_start, skip_target)` range and body hash;
      exclude command-`0x10` from the registry family and execute no body.
    - [x] Freeze a JSON-only command-`0x11` invocation-target edit plan bound
      to one call-family proof, physical resume, and source/replacement registry
      body boundaries.
    - [x] Assemble a validated registered-DEF invocation edit into a new MES
      while preserving its container, caller resume bytes, and both registry
      body bindings in a source-reproducible compile audit.
    - [x] Reopen that changed MES through the current Phase 1-4 GDScript path
      while preserving its caller partition and both registry body bindings.
  - [x] Add choice-group editing after its DEF registrations, materialized
    options, result mapping, and caller resume remain source-bound.
    - [x] Freeze `kakyu_mes_choice_group_authoring_proof/v1` for one exact
      command-`0x1B`/`0x10` grouped route. Bind every group clear,
      registration, strict CP932 message payload hash, return, guard, numeric
      first/second-result route, stored fallback, routine-40 terminal, and
      physical resume without exporting dialogue or executing native input.
    - [x] Add a JSON-only same-byte-length CP932 choice-option edit plan
      against that proof while retaining every unchanged group/result/caller
      boundary and publishing no MES bytes.
    - [x] Assemble and reopen the validated same-length choice-option edit.
    - [x] Extend choice-option payload length only after every shifted local
      target, address-table cell, result route, and caller resume is exact.
- [x] **MW-06 — Add entry-point and control-flow authoring.**
  - [x] Add one address-table entry only at an exact typed instruction boundary
    strictly inside an existing entry, without changing bytecode coordinates.
    - [x] Freeze `kakyu_mes_address_entry_insert_plan/v1` as a JSON-only,
      fail-closed plan. Bind the source entry, target instruction hash, inserted
      little-endian cell, sorted table geometry, region-ownership change, and
      unchanged bytecode/code-relative coordinate policy.
    - [x] Assemble and reopen the validated address-entry insertion while
      retaining byte-identical bytecode, unchanged code-relative coordinates,
      the exact new region split, and the complete source node partition.
  - [x] Add explicit conditional and continuation target authoring only after
    the source expression/transfer form and replacement typed target are exact.
    - [x] Freeze `kakyu_mes_control_target_edit_plan/v1` as a JSON-only,
      fail-closed plan for command-`0x0B` false targets and command-`0x0C`
      continuations. Bind the complete source instruction, conditional
      expression or fixed transfer form, unique indexed reference, current
      typed target, replacement typed target, and exact four-byte patch.
    - [x] Assemble and reopen the validated target edit while preserving the
      container layout, all bytes outside the selected operand, the complete
      typed/opaque partition, and the rebuilt code-reference edge.
  - [x] Add control-flow body insertion/removal only after every affected entry,
    target, call resume, opaque boundary, and source-map coordinate is exact.
    - [x] Freeze `kakyu_mes_control_body_edit_plan/v1` as a JSON-only,
      fail-closed plan for copying one contiguous strict-typed donor span before
      an exact typed anchor or removing one strict-typed span. Bind every
      affected address cell, region, source-map node, reference, encoded
      branch/continuation/definition-skip target, CFG node/edge ID, call/trace
      inventory, and shifted opaque boundary; publish no MES bytes.
    - [x] Assemble and reopen validated insertion and removal plans while
      retaining every unaffected byte and rebuilding the exact shifted
      partition, references, and CFG evidence.
- [x] **MW-07 — Add semantic source/output diff and reopen validation.**
  - [x] Freeze `kakyu_mes_semantic_diff/v1` for control-body insertion/removal.
    Export the compiled file through the standard Phase 1-4 analyzer handoff,
    reconstruct the exact intended output independently from the source
    editable IR and compile audit, map every retained/inserted/removed/patched
    node, verify rebuilt target references, and prove every unrelated typed and
    opaque node survives exactly.
  - [x] Extend the same source/output semantic-diff boundary to every remaining
    MW-02 through MW-06 compile-audit family, retaining family-specific intended
    changes and a common exact preservation report.
    - [x] Freeze `kakyu_mes_semantic_diff/v2` for same-layout state-literal,
      condition-literal, resource-name, and inline-script-name edits. Distinguish
      an explicitly intended bounded opaque-owner patch from unrelated opaque
      nodes that must remain byte-identical.
    - [x] Extend v2 to same-layout shared-routine calls, registered-DEF calls,
      and explicit control-target edits with family-bound literal or indexed
      target assertions.
    - [x] Add the same-layout choice-option family with a unique typed text
      owner and CP932 payload-hash assertion that retains no option text.
    - [x] Add the address-entry insertion family. V3 treats the inserted table
      cell and resulting region repartition as the intended structural change,
      while requiring byte-identical code, statements, reference coordinates,
      and complete node mapping.
    - [x] Add variable-length message relocation, including the blocker-free
      message-only compile audit and the augmented branch/continuation/
      definition-skip target-repair audit.
    - [x] Add source-bound variable-length choice relocation coverage. Reopen
      the authoritative 43C.MES choice owner through the explicit structural
      relocation boundary, repair every encoded target, and retain the complete
      grouped-choice proof after the semantic diff.
  - [x] Run proportionate source-bound reopen/diff coverage across the supported
    edit families and close the Phase 6 compiler gate without claiming native
    engine execution compatibility.

Opaque records must survive unchanged. Publication must fail closed when a
changed length would require relocating an unresolved target or crossing an
opaque boundary.

## MW-07 and Phase 6 Closure Evidence

- Semantic diff v1 covers control-body insertion/removal; v2 covers every
  same-layout literal, resource, script/call, choice, and explicit-target
  family; v3 covers address-entry insertion and derived region repartition;
  and v4 covers variable-length typed messages with optional encoded-target
  repair. Every contract reconstructs the intended output and requires a
  complete source/output node accounting rather than trusting the compiler
  audit alone.
- Authoritative source-bound regressions cover 03C.MES message/control and
  address-table relocation, EVENTB03.MES shared calls, 01M.MES registered DEF
  calls, and 43C.MES same- and variable-length choice owners. The latter
  reopens 5,847 typed records with no opaque boundary, applies 525 exact target
  repairs, and retains all seven choice groups and 44 definitions.
- Focused Python mutation suites and independent Godot 4.7 validators reject
  stale identities, wrong family labels, changed node/reference mappings,
  unplanned bytes, opaque-boundary drift, and semantic-diff accounting drift.
  MW-01 separately retains the byte-identical 1,016-entry no-op corpus proof;
  remake-only UTF-8 remains an overlay and is never assembled into source MES.
- This closes the safe structural Phase 6 compiler gate. It does not claim
  original-engine execution compatibility, native presentation/input, or
  gameplay meaning for any hypothetical changed output.

## MW-01 Closure Evidence

- The Phase 5 analyzer/decompiler input is closed across all 1,016 source
  entries; MW-01 consumes that frozen JSON contract instead of reparsing MES.
- Nine focused Python regressions cover deterministic editable preparation,
  exact typed/opaque no-op output, wrapper/source/audit mutation rejection,
  unsupported-operation rejection, malformed address tables, JSON transport,
  and exclusive output publication.
- Seven GDScript checks cover current Phase 1-4 reopen, integral JSON-number
  transport, changed output and coverage rejection, unknown fields, changed
  fingerprints, and non-integral count rejection.
- Five Python corpus regressions cover deterministic publication, serial versus
  bounded-parallel identity, exclusive output directories, absent completion
  manifests on failure, and aggregate mutation rejection. Seven GDScript
  corpus checks cover JSON transport, source identity, per-entry coverage,
  unknown fields, and path traversal.
- The first source-bound `01M.MES` no-op output is 91,218 bytes with 426
  entries and 11,537 retained nodes. Its entry and bytecode hashes exactly
  match the authoritative handoff; the source archive remains unchanged.
- The current GDScript Phase 1-4 contract independently reopens that output as
  426 entries and 11,537 typed nodes. Its handoff fingerprint is
  `be77152c116921355e37ea99e4c71e7c5e7dbc6c814bfcb156e82e01bef5f947`
  and its reopen-audit fingerprint is
  `27cd1c61c94f29945273ca5cf02941a63776b81078288a3f0bb92fd85a1f55c6`.
- The authoritative no-op corpus covers all 1,016 MES/LIB entries, 18,617,388
  container bytes, 18,079,488 code bytes, 134,475 regions, 2,390,675 nodes,
  2,389,424 typed nodes, and 1,251 byte-preserving opaque nodes. The Python
  compile-spool fingerprint is
  `e14ecfad4fe43074eb9c69f5c1a14c9d06c0d143d7dc32188bc335068712c757`.
- Godot 4.7 reopens all 1,016 compiled containers through the current Phase
  1-4 contract. The ordered reopen stream fingerprint is
  `a9c088484975d848741f48133734a270f3c0813976b0a25bced1b1a60e7cb8b8`
  and the corpus reopen-audit fingerprint is
  `b7e3c4ff50b40d4b9cfbf8ef2ac8705f8d68a3cead986e441fdb6f5b90a536ed`.
  The authoritative source archive remains unchanged. MW-01 is closed.

## MW-03 Closure Evidence

- The compiler accepts only a matching editable IR, message plan, and
  control-target plan with no remaining blocker. It rejects stale, overlapping,
  malformed, or out-of-range target operands before exclusive publication.
- Python regressions cover exact continuation and variable-condition branch
  output, deterministic JSON audit, stale patches, opaque blockers, unknown
  fields, and publication cleanup. GDScript independently rejects changed
  target bytes/references, changed output, unknown fields, fractional counts,
  and stale fingerprints.
- The authoritative `03C.MES` single-patch audit expands the message at
  `0x3EFF..0x3F03`, repairs the `0x3EF1..0x3EF5` continuation operand, and
  reopens all 2,516 typed nodes in Godot 4.7.
- The proportionate wider audit expands `0x02B6..0x02E8`, relocates 151 address
  cells and 747 references, and independently reopens all 71 encoded repairs:
  52 conditional false targets and 19 continuations.
- Both outputs are 16,951-byte new files derived from the unchanged 16,949-byte
  source entry. The authoritative archive remains unchanged. Structural
  branch/continuation relocation is closed; original-engine execution remains
  unverified and is not part of this claim.

## Phase 7 — Translation and Event-Mod Authoring

- [x] **MW-08 — Integrate MES Editor Run with Event Player. — COMPLETE**
  - [x] Freeze the path-free `kakyu_mes_editor_run_request/v1` handoff. Bind
    one workspace generation, effective MES identity, analysis coordinate or
    catalog preset, and exact-original or semantic-diff proof identity;
    structural proofs cannot claim original-engine compatibility.
  - [x] Publish a selected-entry request from MES Editor without mutating the
    source ARC or silently saving an unstaged draft. The controller requires
    an active named workspace, re-resolves and re-hashes the selected effective
    entry, accepts exact-original identity or a matching validated Phase 6
    semantic diff, and publishes a new path-free JSON file exclusively and
    atomically. Pending edits, an unstaged text draft, a changed manifest, an
    invalid start coordinate, or an existing output fail closed.
  - [x] Reopen the named workspace in Event Player, re-resolve the effective
    MES, validate the declared interface, and transactionally start an isolated
    Analysis session. Content Core `0.267.0` carries the Run request and optional
    full semantic proof as separate runtime-only JSON inputs. The consumer
    validates the unchanged workspace generation, original and effective entry
    identities, complete proof binding, parsed start boundary, and a fresh
    sandbox result before committing the selected entry and result view; stale
    or mismatched input leaves the current session unchanged.
  - [x] Resolve the request's catalog/project preset and transactionally start
    an exact-original Catalog session through the existing ordinary-play
    controller. The authoritative EVENTB01 integration reaches its first user
    dialogue with the bound original preset and unchanged source archives.
    Changed-MES Catalog Run remains fail-closed until its proof can preserve or
    map every catalog control point used by playback; changed MES remains
    available through the completed Analysis Run path.
  - [x] Expose the selected-entry Run action in MES Editor. Run uses the
    selected disassembly address (or code offset zero when no address is
    selected), publishes a unique immutable request below the active named
    workspace, and launches an independent Event Player process with the
    content set, workspace, and request as separate runtime arguments. A
    changed overlay additionally requires a user-selected Phase 6 semantic
    proof; pending or unstaged edits disable Run. Headless controller, layout,
    argument, draft-guard, and source-immutability checks pass. Merged-main UI
    verification confirmed both the draft guard and the selected-address
    Analysis handoff at `01M.MES:0x0008`.
- [x] **MW-09 — Add a stable translation catalog workflow. — COMPLETE**
  - [x] Freeze `kakyu_mes_translation_catalog/v1` in Content Core `0.268.0`.
    It exports deterministic strict-CP932 message identities without original
    text, raw bytes, paths, or archive payload; retains translation state and
    revision provenance; and reconciles current parsed MES into exact
    offset/hash-bound edits plus stale source/entry/message, missing-source,
    missing-catalog, and conflicting-row diagnostics.
  - [x] Add transactional MES Editor export/update/import file actions using
    the shared contract and active named workspace. Selected-original-entry
    catalogs are written only as new files below the named workspace, through
    atomic write/reopen validation. Update advances catalog and per-row
    provenance from staged edits; mixed-entry, changed-source, partial, stale,
    conflicting, or overwrite attempts fail closed.
  - [x] Publish reconciled translations through the existing UTF-8 overlay
    batch path. Exact offset/raw-hash-bound imports become ordinary pending
    edits, so the existing multi-entry Save-all transaction publishes and
    reopens them without modifying MES bytes or the source ARC. Clear Overlay
    restores the original decoded dialogue. Synthetic tests cover the complete
    export/update/import/save/reload/clear sequence. Merged-main UI verification
    confirmed revision-one export, staged revision-two update, exact import,
    overlay publication, and original-dialogue restoration.
- [x] **MW-10 — Separate remake and original-compatible text policies. — COMPLETE**
  - [x] Freeze `kakyu_mes_text_output_policy/v1` in Content Core `0.269.0`.
    The path-free report binds current/source archive, entry, message offset,
    and hashes without retaining dialogue or payload bytes. It independently
    classifies remake-only UTF-8 projection and an equal-length CP932 binary
    candidate, reporting stale identity, embedded NUL, CP932 representation,
    native byte/projection/boundary, overflow, and underflow blockers. CP932
    readiness is capped at `original_engine_unverified` until MV-03.
  - [x] Apply the shared report to MES Editor pending edits before UTF-8 overlay
    or CP932 binary publication. Show target compatibility and every blocker,
    and refuse a stale or incompatible selected output without altering the
    pending session. Content Core `0.270.0` also permits the explicit
    `original_engine_unverified` value in a binary overlay manifest so a ready
    CP932 candidate cannot be mislabeled as either remake-only or verified.
    Focused editor, overlay, policy, patcher, and UTF-8-plan regressions pass;
    user-controlled UI verification confirmed the remaining compatibility,
    blocker, refusal, and successful-publication flows.

- [x] **MW-11 — Expose structured MES authoring in MES Editor.** Closed
  2026-09-17 at Core 0.329.0: seven edit families, the proposed-operation list
  and operation sequences are in the Authoring tab; the address entry is
  closed by owner ruling (below); contextual Run and package export of
  multi-step bundles landed with Core 0.330.0 (TODO step 5, WD-21).
  - Open the authoritative Python handoff and its Phase 5/6 editable model in
    the selected-entry workspace context. Keep opaque records byte-preserving
    and display unsupported operations as explicit blockers.
  - Add state, condition, resource, choice, call, control-target and address-entry
    editing over the completed backend; show the complete proposed operation
    list, source coordinates, validation errors and semantic change preview.
  - Publish a compiled entry and matching semantic proof through the named
    workspace, reopen both, and keep failed or stale drafts uncommitted.
  - Phase 6 backend completion remains closed. This item owns the general
    authoring UI and composed-edit validation. MW-12 retains the historical
    first edited-event workflow; Event Player is now original-only, so edited
    Run expansion is withdrawn. Shared headless authoring probes remain usable.
  - Core 0.302.0 adds the Authoring tab's first bounded control: inspect an
    original entry with Python, select a typed state literal, preview one
    same-width change with compiler/semantic evidence, and publish to the named
    workspace. Other families and multi-operation editing remain open. Contract:
    `docs/spec/data/mes_authoring_bundle.md`.
  - Core 0.304.0/bundle v2 adds variable-length CP932 message controls through
    the existing branch/address compiler. Preview reports the byte delta; exact
    Python proof reconstruction, independent Godot reopening, translation conflict
    rejection and mapped later translations are connected to publication.
    Other edit families and operation sequences remain open. Regression:
    `tests/test_mes_message_authoring.py` and its Godot scene.
  - Core 0.322.0/bundle v3 (2026-09-15) adds same-width condition-literal
    controls over the existing condition planner and compiler: one candidate
    per literal inside a typed `branch_if_not_true` condition, a width-bounded
    value control, a preview naming the preserved false target, publication
    through the same byte-exact source check (now a per-audit-schema table)
    and reopen validator selection by schema; delta v3 carries the operation
    and keeps v1/v2 readable. Regression:
    `tests/test_mes_authoring_workflow.py`, `tests/test_authored_mod_delta.py`
    and the scene `tests/test_mes_condition_authoring.tscn`.
  - Core 0.324.0/bundle v4 (2026-09-16) adds same-length resource-name controls
    over the existing resource-name planner and compiler: one candidate per
    strictly indexed MMO, AX or voice marker, the name edited in the message
    text control, the planner holding the byte length and the extension, a
    preview naming the preserved length, publication through the per-schema
    byte-exact source check and the resource reopen validator; delta v4
    carries the operation and keeps v1-v3 readable. Regression:
    `tests/test_mes_authoring_workflow.py`, `tests/test_authored_mod_delta.py`
    and the scene `tests/test_mes_resource_authoring.tscn`.
  - Core 0.325.0/bundle v5 (2026-09-16) adds same-length choice-option controls
    over the existing choice-group proof, planner and compiler: one candidate
    per definition of a routine-40 grouped registry (the entry decoded once,
    only address entries with a group clear proved - today `43C.MES` entry
    148, 44 option texts), the text edited in the message text control, the
    planner holding the payload length, publication through the per-schema
    source check (now naming the audit section) and the choice reopen
    validator; delta v5 carries the operation through a per-version table of
    admitted kinds and keeps v1-v4 readable. Regression:
    `tests/test_mes_authoring_workflow.py`, `tests/test_authored_mod_delta.py`
    and the scene `tests/test_mes_choice_authoring.tscn`.
  - Core 0.326.0/bundle v6 (2026-09-17) adds registered-definition call controls
    over the existing call-family proof, registry proof, planner and
    compiler: the bundle carries the archive's `DEF_MAIN.MES` registry proof
    (`registry.proof.json`, built by `inspect`), one candidate per typed
    registered-definition call site with a literal selector, the selector
    edited in the numeric control against the registry's selectors, a
    preview naming the replacement's registry body, publication through the
    per-schema source check and the registered-call reopen validator; delta
    v6 names the original entries a reconstruction needs (`dependencies`)
    and keeps v1-v5 readable. Regression:
    `tests/test_mes_authoring_workflow.py`, `tests/test_authored_mod_delta.py`
    and the scene `tests/test_mes_registered_call_authoring.tscn`.
  - Core 0.327.0/bundle v7 (2026-09-17) adds shared-routine call controls over
    the existing shared-call return proof, planner and compiler: the Godot
    side builds the `LIBLARY.LIB` library audit
    (`tools/content_suite/mes_library_audit_report.gd`, shared with the
    handoff spool exporter) before `inspect` and before a delta
    reconstruction and hands it to Python (`--library-audit`); the bundle
    keeps it as `library.audit.json`; one candidate per proved call (a
    literal routine id with a total-return certificate; 33 of the 43 real
    routines), the id edited in the numeric control, a preview naming the
    replacement's library body, publication through the per-schema source
    check and the shared-call reopen validator; delta v7 names `LIBLARY.LIB`
    in `dependencies`. Regression: `tests/test_mes_authoring_workflow.py`,
    `tests/test_authored_mod_delta.py`, the scenes
    `tests/test_mes_library_audit_report.tscn` and
    `tests/test_mes_shared_call_authoring.tscn`.
  - Core 0.328.0/bundle v8 (2026-09-17) adds control-target controls over the
    existing control-target planner, compiler and reopen validator: one
    candidate per typed `branch_if_not_true` false target or
    `continuation_transfer` with one exact aligned reference (EVENTB14: 56,
    37 false targets and 19 continuations), the replacement offset edited
    in the numeric control bounded by the code size and bound by hash to a
    unique typed instruction start before planning, a preview naming the
    replacement's operation, publication through the per-schema source
    check (the whole transfer instruction) and the control-target reopen
    validator; delta v8 admits the operation with no dependency.
    Regression: `tests/test_mes_authoring_workflow.py`,
    `tests/test_authored_mod_delta.py` and the scene
    `tests/test_mes_control_target_authoring.tscn`.
  - Address-entry controls are closed without editor exposure by owner
    ruling (2026-09-17, option 1 of three). The Phase 6 backend
    (`plan_mes_address_entry_insert.py`, its compiler and the v3 semantic
    diff, frozen 2026-09-05) inserts one bare four-byte table cell, but the
    entry-prologue finding settled the next day
    (`docs/spec/mes/format_and_method.md`: command `0x17` opens every
    address-table entry carrying that entry's own index; 133,459 of 133,459
    over `mes.arc`, EVENTB14 74 of 74) means an inserted entry has no
    prologue and every later entry's prologue index goes stale; the editor
    would also need a size-changing source check and the package export a
    v3-proof path. Under the remake ruling (new events are authored as
    definitions, original scripts are not run) the family has no consumer.
    Measured before the ruling with a throwaway probe: EVENT scripts carry
    7..364 entries, the backend plans, compiles and diffs an insertion in
    about a second, and the result is exactly the stale-prologue container
    described. Reopening it means a prologue-bearing insertion (bytes
    inserted, later offsets relocated, later prologues renumbered) as a new
    Phase 6 unit, not an MW-11 control.
  - Core 0.329.0/bundle v9 (2026-09-17) adds operation sequences and the
    proposed-operation list: a bundle compiles an ordered list of
    operations as a chain through the single-operation engine (step k on
    step k-1's re-analysed output; same-size steps keep every coordinate
    and a second edit of an already edited instruction is rejected as stale
    by that step's planner; a message relocation only last), with
    `sequence.json`, `step-NN.*` members and the chain proof
    `kakyu_mes_semantic_diff_chain/v1` as the top-level proof of a
    multi-step bundle (one-step bundles keep the v8 layout, so every
    single-operation consumer is unchanged). The Authoring tab stages
    edits in a proposed-operation list (add / remove / clear), previews
    them in order with per-step status and the failing step's error, and
    publishes the compiled sequence; delta v9 carries `operations`.
    Measured on EVENTB14: a four-step chain (condition, state, control
    target, relocated message) costs about 2.7 s per step, about 41 s for
    the CLI round trip that recompiles the sequence on reopen. Regression:
    `tests/test_mes_authoring_sequence.py`, `tests/test_authored_mod_delta.py`,
    the scenes `tests/test_mes_sequence_authoring.tscn` and
    `tests/test_mes_semantic_diff_chain.tscn`. Contextual Run and package
    export of multi-step bundles landed with Core 0.330.0 (TODO step 5):
    contextual Run binds every family and every stepped bundle.
- [x] **MW-12 — Complete one edited event from authoring to contextual Run.**
  - Exercise Python handoff, a structural edit and a UTF-8 translation through
    editor controls, workspace publication, semantic diff and output reopening.
  - Bind the original-to-output coordinate map to the exact compiled identity;
    the historical EP-04 path applied it to catalog control points and presets.
    The 2026-09-08 original-only decision withdraws further Event Player work;
    MW-11/WD-21 retain authoring and package proof validation.
  - Verify the displayed dialogue, expected changed state and terminal against
    the published output, plus stale-proof/refused-publication rollback.
  - WD-09 owns format-neutral selection handoff and WD-21 owns package output;
    neither duplicates this editor workflow's completion checkbox.
  - The actual Python/editor synthetic flow now passes translation save, state
    compilation, source-bound publication, current workspace generation, proof
    selection and changed Analysis execution. Five focused scenes/parse checks
    pass in `analysis/authoring-final-validation.json`; Python regression passes
    1,308 tests. Source-derived EVENTB01 state compilation/reopening also passes.
  - Closed 2026-09-08 with the actual EVENTB03 original: UTF-8 save, state
    literal change at `0x76`, Python handoff/compile, workspace publication,
    preset selection and strict MACHI.MES terminal match. Authored state value
    and UTF-8 display, all five identity-mapped callee points, original caller
    audit, output mutation rejection and invalid-preset rollback pass.
    `analysis/contextual-final-validation.json` covers the synthetic workflow,
    original workflow, 12 original package routes and project parsing (4/4).
    General authoring proof work stays MW-11 and package output stays WD-21.

- [x] **MW-13 — A structured form for the Definitions tab.** Scheduled by
  the owner on 2026-09-19 as the first line after TD-11 closed and
  **closed the same day (Core 0.350.0)**: `tools/content_suite/mod_definition_form.gd`
  (`KakyuModDefinitionForm`) with the row editors of `mod_definition_rows.gd`
  is the "Form" tab beside "JSON" in the Definitions tab; it covers a plain
  event (one default result, no question) and an override of conditions,
  effects, order hint or presence, refuses the rest with a reason, computes
  every row's cell class the way the validator does through the new
  `content_core/state_cells.gd` (`KakyuStateCells`, the Python table port
  checked against the tracked `cells_fingerprint` by the new
  `ContractValues.directory_fingerprint`), and round-trips the covered
  fixtures exactly, keeping a loaded document's terminal id. Verified 2026-09-19: `tests/test_mod_definition_form.tscn` (29 checks: exact round trips of the covered fixtures, refusals with reasons, flag/counter relabeling, affection and clock classes, the U+000A and `{name}` line, the rebase hash against the Python rule, the changed signal), `tests/test_state_cells.tscn` (49), the Definitions panel scene (38, Form/JSON switching and a save from the form), the MES Editor scene (158), `tests/test_contract_values.tscn` (48), the local batch 131/131, Python 1,663. The
  Definitions tab (2026-09-19, `tools/content_suite/mod_definition_panel.gd`)
  edits a `kakyu_mod_event_definition/v1` document as JSON text with
  templates and the validator's verdict inline. The form is a second view
  of the same document beside the JSON: fields for the header, trigger,
  display and presentation; row editors for conditions, dialogue entries
  and effects, each typed by the contract's vocabulary
  (`docs/spec/data/mod_event_definition.md`) with the cell class computed
  the way the validator computes it; the single default result of a plain
  event edited in place; an override's `replace_conditions`,
  `replace_after`, `replace_order_hint` and `disable` operations edited as
  rows. A document the form does not cover (a choice, several results, a
  nested question, `replace_result`/`append_result`) stays JSON-only, and
  the form says so. The JSON text remains what Validate and Save read.

Legacy: P4-01 through P4-08.

## Dependencies

- Phase definitions and order: `mes_pipeline.md`.
- Analyzer output stability: `mes_analyzer.md` MA-09.
- Decompiler source maps and structured output: `mes_analyzer.md` MD-01..MD-04.
- Original-reference launch and original-only input cleanup: `event_player.md`;
  changed-MES proof validation remains authoring/package work.
- Portable publication and package reporting: `workspace_distribution.md`.
