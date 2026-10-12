# Original MES Analyzer and Decompiler TODO

This is the live tracker for Phases 1-5 of the authoritative original-MES
pipeline: lossless reading, exact instruction framing, context-qualified text,
control-flow reconstruction, and decompilation. It owns safe structural
interpretation and reproducible analysis/decompiler contracts. Phase definitions
and default order live in `mes_pipeline.md`; technical findings and evidence
remain authoritative in `../docs/spec/mes/`.

Legacy roadmap references point into
`archive/legacy_todo_2026-08-30.md`; they are historical cross-references, not
duplicate live checkboxes.

## Goal

Given an authoritative MES or library payload, produce reproducible container,
instruction, expression, state, reference, control-flow, call, and trace data
without allowing bytes inside native or opaque records to execute as shadow MES
commands.

An analyzer result must either:

- preserve an exact record boundary and expose a source-qualified typed meaning;
  or
- preserve the complete bytes as an explicit, fail-closed opaque boundary.

## Non-goals

- Reproducing every native pixel, AX, audio, input, or wall-clock effect.
- Promoting an event to ordinary Event Player playback.
- Editing, relocating, assembling, or publishing changed MES programs.
- Implementing GUI presentation beyond the diagnostics needed to verify an
  analyzer contract.

Those belong to the linked Event Player, presentation/audio, and MES authoring
trackers.

## Completion Contract

An analyzer item is complete only when:

1. exact code-relative record boundaries are preserved;
2. record payload bytes cannot be decoded or executed as sibling shadow commands;
3. typed operands, control flow, and trace data are deterministic, or the entire
   unresolved record is retained as an opaque boundary;
4. original semantic claims are cross-checked against the configured
   authoritative `mes.arc` and original executable;
5. proportionate synthetic, authoritative-corpus, and regression checks pass;
6. the consuming `docs/spec/mes/` document records entry, offset, evidence type,
   confidence, and unresolved boundary; and
7. the coherent work unit is committed.

Unresolved native meaning does not block structural completion when it is
preserved and labeled accurately. It does block claiming that native meaning as
confirmed or executable.

## Phase 1 — Lossless Binary Reader

- [x] **MA-01 — Container, address-table, and source identity.**
  - Lossless bounded MES/LIB container access, code-relative coordinates,
    source fingerprints, and fail-closed malformed-input handling are covered.

The Phase 1 gate is closed. Opcode or native-effect meaning is deliberately not
part of this gate.

## Phase 2 — Opcode Dumper and Exact Record Framing

- [x] **MA-02 — Typed instruction, operand, expression, and character-stream decoding baseline.**
  - The indexed original corpus has typed command/expression handling and
    separates confirmed CP932 dialogue from native character streams.
- [x] **MA-07 — Native presentation envelope classification.**
  - Consume the exact seven-byte selector-2/6/7/8 and subcommand-10 mode-1
    envelopes as typed, non-executing records.
  - Retain the source-qualified EXE associations for selector 2 selected-cell
    state 1, selector 6 active-cell marking, selector 7 `10x32` invalidation,
    selector 8 activation/wait, and mode-1 guarded surface composition without
    making native execution a Phase 2 requirement.
  - Prevent their payloads from appearing as command-3 gameplay-state writes;
    EVENTD02/EVENTD08 no longer gain selector payload values at `global_u8[767]`.
    V44 also removes the formerly misidentified ordinary value 1: it belongs
    to EVENTD02's 13-byte selector-1 envelope.
  - EVENTB14, EVENTD02, EVENTD08, Event Catalog, EVENTB03 reduction and
    zero-state choice, plus linked analyzer/library wrappers pass against the
    unchanged original sources.
  - The exhaustive literal seven-byte subcommand-3 inventory contains only
    selectors 2/6/7/8; every member is now one exact typed record.
  - Decoder, trace schemas, source audit v2, tests, and MES docs are retained as
    one coherent unit. Actual native effects remain omitted.
  - [x] Correct argument-bearing selector-1/2 envelopes (v44): retain exact
    selected-cell records and default arguments, reject unqualified operands,
    and remove payload-shadow gameplay writes. The 7,318-candidate original
    census and full 1,016-entry structural alignment audit pass; old v43
    analyzer handoffs are rejected and must be regenerated.
  - Legacy: current analyzer portion formerly recorded under P2-10/P3.
  - [x] Correct subcommand-6 effect envelopes (v45): retain the whole typed
    list, expose only qualified named WAV requests as non-executing metadata,
    and preserve unknown selectors without payload-shadow bank writes.
    Original MES/SE/EXE audit plus 1,016-entry alignment finds 191 envelopes
    across 46 entries; v44 handoffs are rejected and must be regenerated.
- [x] **MA-08 — Archive-wide record alignment and shadow-command audit.**
  - Retain the completed indexed-intro runner baseline with no generic
    unsupported-opcode, decoder, write, or target failures.
  - [x] Consume the 332 source-qualified outer-`0x0D` native payloads whose
    handler-consumed run contains `0x0B`/`0x0C` as exact aligned records and
    retain all 1,251 strict stops as byte-preserving opaque tails. This
    includes internal shadow-control bytes, not only a branch-like first byte.
  - [x] Re-run the Phase 3 negative-space audit across 220,491 messages: every
    row has a typed text owner and none begins inside a native, expression, or
    opaque payload.
  - [x] Add the remaining source-qualified inventory showing that every confirmed compound
    native record is consumed as one record or stopped as one opaque boundary.
  - Treat newly discovered noncanonical forms as fail-closed evidence work, not
    as permission to broaden an unrelated parser rule.
  - [x] Repeat the Phase 3 negative-space audit so native, expression, and opaque
    payload bytes cannot appear as extracted strings.
    The v45 repeat covers 220,493 typed-owner messages with zero conflicts;
    strict opaque boundaries decrease to 1,180 after the effect framing fix.
  - The authoritative structural audit covers all 18,079,488 code bytes in
    134,475 bootstrap/address regions: 363,850 compound records (v45) retain exact
    typed ranges, and the sole structural stop is one byte-preserving 57-byte
    opaque tail in `08C.MES`.
  - Legacy: P2-08 plus the remaining family-wide boundary audit.

MA-07 followed by MA-08 closes Phase 2. The complete compound-record inventory
is byte aligned across the authoritative corpus, and noncanonical input remains
fail closed.

## Phase 3 — Context-Qualified String Extractor

The implementation baseline is complete inside MA-02: strict CP932 message
rows retain raw bytes, offsets, hashes, and native-stream diagnostics. MA-08's
archive-wide negative-space regression closes the gate; there is no duplicate
Phase 3 checkbox here.

## Phase 4 — Control-Flow Reconstruction

- [x] **MA-03 — State, reference, and control-flow analysis.**
  - Typed storage access, references, conditions, basic blocks, CFG metadata,
    and structural alignment are available for the current corpus contract.
  - [x] Correct numeric E6/E7 logical operands to native exact-one truth,
    retaining eager evaluation and bitwise distinctions. Bind the original
    EXE dispatch/handlers to a separate read-only auditor and test literal,
    state and persistent-stack consumers. Core 0.276.0 changes evaluation,
    not record boundaries or the language-neutral AST/trace shapes; see
    `docs/spec/mes/format_and_method.md` for the bounded proof and regressions.
- [x] **MA-04 — Isolated trace and fail-closed effect model.**
  - The sandbox runner records deterministic state effects and explicit native,
    selection, call, handoff, or opaque boundaries without touching gameplay
    saves or source archives.
- [x] **MA-05 — Nested MES, registered DEF, library, and host-activation model.**
  - Source-bound caller frames, registered definitions, shared-library calls,
    nested returns, and the command-`0x0E` host-activation evidence chain are
    implemented at their documented analyzer scope.
  - Legacy: analysis portions of P2-04, P2-05, and P2-06.
- [x] **MA-06 — Routine-40 conditional second-stage reachability.**
  - Retain the confirmed one-based first result, grouped registries, slot-13
    second result, stored consumer graph, and exact fallback coordinates.
  - Resolve source-qualified live reachability for the conditional 43C second
    stage while keeping unresolved result meaning numeric and evidence-labeled.
  - Versioned numeric reachability now revalidates the grouped source contract
    and maps every row in the evaluated default/eligible registries to an exact
    stored consumer, the `0xA304 -> 0x399F` fallback, or an empty-list `0xFFFF`
    boundary. It never executes the destination or resumes a caller.
  - Native selection UI, cadence, semantic character/place labels, and
    product-side choice bridges are not Phase 4 requirements.
  - Legacy: analyzer portion of P2-07.
- [x] **MA-09 — Stable Phase 1-4 analyzer handoff and completion audit.**
  - Publish a versioned analyzer-facing schema for container, typed/opaque IR,
    references, CFG, calls, and trace evidence without product-specific UI data.
    The core CFG component is now independently frozen as
    `kakyu_mes_reference_graph/v1`. Content Core emits the aggregate
    `kakyu_mes_analyzer_handoff/v1` and the compact
    `kakyu_mes_analyzer_completion/v1` corpus report.
  - Prove deterministic output on synthetic fixtures and the unchanged original
    corpus; document compatibility rules for later consumers.
    The first cross-language check serializes authoritative `D_TALK00.MES` in
    GDScript and validates the same fingerprint in Python without reparsing MES.
  - Freeze a Phase 1-4 analyzer-v1 completion report listing supported typed
    forms, explicit opaque/native boundaries, and remaining numeric meanings.
    The report freezes 39 typed forms, 21 compound/native boundary families,
    both strict-analysis and structural opaque inventories, five code-reference
    kinds, four resource-reference kinds, and all retained unresolved classes.

MA-09 is the closed low-level handoff consumed by both the Phase 5 decompiler
and Phase 6 compiler. It is not itself a completed decompiler. On 2026-09-06
the owner approved the instruction-v45 corpus baseline `fae349f9...eab6f5`;
`code_health.md` TD-15 closed the complete-corpus re-freeze verification. Earlier v43
completion counts and fingerprints below are historical measurements.

- [x] **MA-10 — Re-establish the Phase 1-4 authority in Python.**
  Opened by [Product roles](../docs/spec/tech/product_roles.md), which fixed the
  destination on 2026-09-05, and by the owner's go on 2026-09-06. The authority
  is MA-09's frozen measurement over 1,016 entries, not the language that
  computes it, so this is a re-verification with a recorded result rather than a
  translation. TD-12 measured the starting distance and is closed; it did not
  schedule this work and does not own it.

  **Closed 2026-09-06.** Complete Python handoff production and the
  `--require-full-equivalent` corpus audit re-established the approved v45
  measurement on all 1,016 entries. Python is now the Phase 1-4 authority.
  Actual Python hashes and the producer-only baseline projection are recorded
  separately below; the earlier implementation-unit measurements are retained.

  **The first gate was sequential framing equivalence over all 1,016 entries.**
  `audit_mes_framing_equivalence.py` reports two measures and says which one
  counts: per-record agreement sees past a failure and ranks what is missing,
  while sequential equivalence asks whether Python reproduces a whole entry's
  framing. Only the second is the Phase 2 gate.

  Measured against `export_mes_framing_digest.gd`'s digest of `mes.arc`
  `31a95b31cb0f1051…` — 1,016 entries, 2,386,774 records, 0 export failures:

  | Unit | Per-record | Entries sequential | Commands unframed |
  |---|---:|---:|---:|
  | TD-12 baseline | 58.22% | 0 | 39 |
  | Shared record list | 69.97% | 2 | 31 |
  | Double-byte character stream | 84.80% | 2 | 8 |
  | Shared write-run pairs, `0x0B` | 97.34% | 66 | 2 |
  | `0x0D` presentation tree | 100.00% | 521 | 0 |
  | Strict expression parity | **100.00%** | **1,016 of 1,016** | **0** |

  **The framing gate was met first.** `--require-equivalent` passed the
  audit's strict reading and closed the Phase 2 gate in Python. That alone
  did not move the Phase 1-4 authority: framing is one component of the whole
  MA-09 handoff at the approved v45 fingerprint `fae349f9...eab6f5`.

  Each unit moved a shared mechanism rather than a command. `0x1B`, the command
  TD-12 named as the sequential blocker, is one of eight sharing a record-list
  grammar; `0x01` and `0xFF` are one character-stream probe; nine write-run
  commands differ only in the header before one pair run.

  Two corrections came out of it rather than coverage. `0x0B` read five raw
  bytes where the authority reads a u32 target, so all 71,165 of its records
  were framed one byte long, and being a branch it desynchronized everything
  after it. `0x0C` framed correctly but handed back four separate bytes, which
  `audit_mes_routine40_groups` reassembled by hand; it now reads the u32
  operand, and that shape change — not the `0x0B` fix — is what the routine-40
  and choice-group tests were failing on.

  Strict expression parity was the last step and the one worth stating
  precisely: framing already agreed on every individual record while 495 entries
  still diverged, because agreement per record and agreement on a whole entry
  are different questions. The authority fails closed when a terminator arrives
  with a stack depth other than one and records the rest of the region as
  opaque; Python logged a diagnostic and kept decoding inside those bytes. Two
  narrower bounds went with it — the scan stops at `MAX_EXPRESSION_BYTES` from
  the expression start whatever the caller allows, and every operand read is
  bounded by the expression's own limit. Strict is the framing decoder's mode;
  permissive stays the structural mode other consumers read.

  **Typed-IR production, verified 2026-09-06.** `mes_instruction_ir.py`
  reproduces the complete instruction-v45 dictionaries, including canonical
  expression ASTs, native evidence metadata, and `0x0E`/`0x0F` op-name
  specialization. `mes_analyzer_handoff.build_typed_ir()` retains the strict
  analysis regions, diagnostics and byte-preserving opaque tails. This
  reproduces existing v45 rules; it confirms no new native meaning.

  **Record-alignment production, verified 2026-09-06.**
  `mes_record_alignment.build_record_alignment()` reproduces the complete
  structural audit-v1 result. The decoder APIs now carry an explicit
  `structural` argument; strict typed IR and structural coverage share the
  region and opaque-tail helpers in `mes_analysis_common.py`. Alignment keeps
  the authority's family precedence, first-24 samples across each container's regions, per-region
  500,000-instruction limit and exact typed-or-opaque coverage. Handoff
  production rejects an unsuccessful audit or a different alignment schema.
  The expression-mode adapter preserves the legacy three-argument public hook
  for strict callers and uses the shared parser directly for structural mode.

  **Reference production, verified 2026-09-06.** `mes_references.py` reproduces
  the ordered message, code and state lists from strict typed IR;
  `mes_resource_references.py` scans the full code for the same bounded resource
  envelopes as GDScript, including those inside strict opaque regions. The
  aggregate `references` object retains all four lists. State traversal keeps
  writes before reads, parent-before-child order and duplicate occurrences.
  Surface coordinate aliases now follow the authority's insertion order;
  instruction values and normalized fingerprints are unchanged. Existing
  collector scope is reproduced without adding inferred writes or resources.

  **Capability-report production, verified 2026-09-06.**
  `mes_capability_report.py` reproduces the final component's policy fields
  and counts. Instruction and opaque-boundary counts come from strict typed
  IR, compound-family counts from structural alignment, and reference kinds
  from the ordered code/resource lists. Optional CFG/call/trace inputs are
  counted without claiming to validate or generate their evidence. The helper
  accepts canonical string labels, preserves missing-label defaults and
  duplicate counts, and keeps returned mutable data separate from its inputs.

  **Handoff equivalence, completed 2026-09-06.**

  1. *Component measurement.* Framing is one component of MA-09. The
     authority is the whole handoff — container, typed and opaque IR,
     references, CFGs, calls and trace. Component agreement was established
     before the complete-payload result recorded in the next step.

     Measured per component rather than as one boolean, because a boolean
     cannot plan work: one wrong field in one instruction of one entry reports
     exactly what having no producer reports. `export_mes_handoff_digest.gd`
     emits a fingerprint per component under the handoff's own normalization,
     and `audit_mes_handoff_equivalence.py` compares it against the Python
     side with three verdicts — `equal`, `diverged`, and **`not_produced`**.
     The third exists so an unwritten component can never score as agreement.

     Current measurement over all 1,016 entries, 2026-09-06:

     | Component | Verdict | Size |
     |---|---|---:|
     | `container` | **equal on 1,016** | — |
     | `typed_ir` | **equal on 1,016** | 2,386,774 instructions |
     | `record_alignment` | **equal on 1,016** | 2,473,574 instructions, 363,850 compound |
     | `references` | **equal on 1,016** | aggregate of the four lists below |
     | `references.state` | **equal on 1,016** | 517,612 |
     | `references.messages` | **equal on 1,016** | 220,493 |
     | `references.code` | **equal on 1,016** | 186,030 |
     | `references.resources` | **equal on 1,016** | 36,149 |
     | `capability_report` | **equal on 1,016** | — |

     This is **9 of 9 comparison targets produced and equal**, counting the
     aggregate `references` object and its four lists separately. The component
     audit reports `equivalent=true` and passes `--require-equivalent`.
     That v1 report's CLI states `scope=component_fingerprints` and
     `full_payload=not_compared`; its component result alone did not establish
     full handoff equivalence or move authority. The historical report at
     `analysis/ma10-capability-equivalence.json` compares against the
     `analysis/ma10-current-handoff.jsonl` digest, with no missing entry or
     entry-hash mismatch. The earlier 8-of-9 reference measurement remains in
     `analysis/ma10-references-equivalence.json`, the 3-of-9 alignment measurement
     in `analysis/ma10-record-alignment-equivalence.json`, and the 2-of-9 typed-IR
     measurement in `analysis/ma10-typed-ir-equivalence.json`. These are ignored
     local audit artifacts.

     `record_alignment` decodes 86,800 more instructions than `typed_ir` over
     the same bytes because it runs the structural mode while the typed IR runs
     the strict one. The two modes separated during the framing work, so that
     distinction is already in place.

     The comparison target is the approved GDScript baseline. The full-payload
     unit reuses the verified digest after confirming the archive SHA-256 and no
     changes under `content_core/` or to `export_mes_handoff_digest.gd` since
     approved baseline commit `6e20818`. The digest has no producer-file
     manifest, so that Git check supplements its source/hash validation.
     The owner approved its instruction-v45 corpus
     fingerprint `fae349f9...eab6f5` on 2026-09-06; TD-15 verified it over the
     complete corpus and through the Python completion consumer. The earlier v43 constant
     `2d182d27...b911807` is historical and is not the migration target.
  2. *Complete handoff production and comparison.* `build_handoff()` produces
     the normalized v1 payload with source identity, compatibility metadata,
     all five component dictionaries and CFG/call/trace arrays. It validates
     source record ownership and the bounded canonical transport, and retains
     supplied attachments with their evidence schemas and CFG edges checked.
     The actual producer is `python_phase1_4`; the existing Python handoff
     consumer and Phase 5 lifter accept its exported payload.

     `audit_mes_handoff_equivalence.py --require-full-equivalent` passes on
     **1,016 of 1,016 source entries** with no limit, missing entry,
     source/producer error or entry-hash mismatch. Report v2 separates actual
     Python hashes from authoritative GD hashes and explicitly projected
     comparison hashes. Under `producer_implementation_only/v1`, validation
     precedes changing only `producer.implementation` to
     `godot_gdscript_phase1_4` in an independent comparison object.

     Every projected payload hash agrees. In the GD digest's entry order,
     the projected Python corpus hash reproduces the unchanged approved
     GDScript baseline
     `fae349f9affbaf244f44fe61f3afc380cb980f058950fe85fcb1f7d097eab6f5`.
     The actual Python corpus hash is `3eb9afe776657b120346ca880608e95b069ceb9e2ced3d5d97b803b80b3628f9`.
     These are different provenance-bearing results; the exported Python
     payload never impersonates the baseline producer. The report is
     `analysis/ma10-full-handoff-equivalence.json`, using the verified local
     `analysis/ma10-current-handoff.jsonl` digest.

     The existing component-only v1 report and `--require-equivalent` gate
     retain their meaning. The full gate is v2 `full_payload.equivalent`;
     limited or selected runs remain partial and cannot pass it. Invalid
     payloads cannot be silently omitted from a Python corpus hash.
     The frozen corpus's CFG/call/trace arrays are empty. Nonempty supplied
     attachments are preserved and validated by independent authored tests;
     their production is not inferred from the corpus comparison.

  The typed-IR unit's independent Godot oracle compared complete dictionaries
  over **2,502 authored fixtures**: 2,416 instructions, 45 aligned regions,
  and 41 typed-IR components. It includes promoted presentation forms absent
  from a particular corpus route and each envelope's prefix limits. Those
  limit cases exposed three Python recognizers that inspected a complete
  source prefix beyond the caller's limit: effect and surface dispatch need
  three available bytes, and
  named state transfer needs six. `mes_partial_decoder.py` now checks those
  limits before recognizing the prefix. All 86 mismatches pass after the fix;
  physically truncated inputs already agreed. This is a decoder-boundary
  correction, with no change to the v45 format or native interpretation.

  **Python authority is established.** The complete recorded result
  satisfies MA-10's measurement condition and the operating rule now follows
  it. The current versioned handoff remains the boundary; older Python
  projections still cannot override its exact record framing or schemas.
  TD-15's frozen GDScript completion-v1 report and consumer remain historical
  baseline checks. Existing GDScript instruments, runtime validators and the
  CFG handoff spool keep their current code paths; this closure does not claim
  Python generated those graphs or removed every Godot dependency.

  Verification for the typed-IR unit: **177 related Python tests passed**,
  including the independent 2,502-fixture oracle. Full-field comparisons match
  all 3,103 `08C.MES` instructions and its diagnostic/opaque tail, and all 9,236
  `D_TALK00.MES` instructions. The whole-corpus component audit then matches
  `container` and `typed_ir` on **1,016 of 1,016 entries**. The earlier framing
  audit's `--require-equivalent` result remains the Phase 2 proof; the full
  handoff audit cannot pass that strict condition while components are absent.

  The record-alignment unit added an independent structural Godot oracle over
  **2,546 authored fixtures**: 2,447 instructions, 49 regions and 50 alignment
  components. Its strict counterpart now contains 2,531 fixtures. Both compare
  complete dictionaries, including structural expression diagnostics and the
  AX selected-cell nonliteral-argument rejection shared by both modes.
  Regression also covers malformed decoder coverage and the handoff's
  alignment success/schema gate. Full-field comparisons match all three
  produced components for `08C.MES` (3,103 structural instructions, 362
  compounds, one 57-byte tail) and `D_TALK00.MES` (9,236 instructions, 1,173
  compounds, no tail). A fresh GDScript `LIBLARY.LIB` handoff additionally
  matches its zero-table bootstrap `[0x0, 0x14F2C)`: strict analysis stops
  after 8 instructions, while structural alignment retains 10,127 instructions,
  1,530 compounds and no opaque tail. The source is unchanged. The whole-corpus
  audit matched all three components on **1,016 of 1,016 entries**, the
  historical 3-of-9 measurement.

  The record-alignment unit's final verification also passed the complete
  local batch: **94/94 checks**,
  with 1,225 Python tests, a project parse check and 92 Godot scenes in
  190.968 seconds. The report is
  `analysis/ma10-alignment-final-local-validation.json`. The compatibility
  fix was followed by another complete source comparison at
  `analysis/ma10-alignment-final-equivalence.json`; its JSON is byte-identical
  to the earlier 3-component report, SHA-256 `1e1fbe15...2febac33`.

  The reference unit's independent Godot oracle passed **6,262 exact cases**:
  2,518 authored reference containers, including 32 focused cases; 2,469
  marker-only cases; and 1,275 MMO name cases covering first byte `0x01..0xFF`
  across five decoder modes. All **12 reference Python tests** passed.
  Full dictionary comparisons include nested state reads, duplicate
  surface/effect aliases, code-target/fallthrough ordering, raw message bytes,
  and resources inside opaque spans or crossing address-table regions. The
  whole-corpus audit matched all eight produced comparison targets on
  **1,016 of 1,016 entries**, the historical 8-of-9 measurement. This reproduces
  existing analysis-v19 reference collection and confirms no additional native meaning.
  The expanded MMO cases reproduce GDScript's Latin-1 name/raw-byte retention
  and use a `?` projection only when applying its safe-name checker. The common
  ASCII gate policy is unchanged. This is a representation-parity correction,
  with no new native interpretation.

  Final reference verification passed the complete local batch: **94/94
  checks**, with **1,237 Python tests**, project parsing and 92 Godot scenes
  in 172.325 seconds. The report is
  `analysis/ma10-references-local-validation.json`. The final MMO correction
  also passes the repeated 1,016-entry component audit and the focused
  full-field comparisons of `08C.MES`, `D_TALK00.MES` and `LIBLARY.LIB`.

  The capability unit's independent Godot oracle passes **2,572 exact cases**:
  2,569 authored containers through the validated handoff producer and three
  private aggregation fixtures for counter defaults. All **10 capability
  Python tests** pass. The focused `08C.MES`, `D_TALK00.MES` and `LIBLARY.LIB`
  comparisons match all five component dictionaries when supplied the same
  single exported GDScript CFG, including `cfg_count=1`; this does not claim
  Python graph generation. The full source-bound audit matches all nine
  comparison targets on **1,016 of 1,016 entries**. Capability aggregation
  confirms no new native meaning and does not validate a full handoff payload.

  Final capability verification passes the complete local batch: **94/94
  checks**, with **1,247 Python tests**, a project parse check and 92 Godot
  scenes in 164.803 seconds. The report is
  `analysis/ma10-capability-local-validation.json`.

  Final complete-handoff verification passes **85 valid full-payload oracle
  fixtures and 10 invalid-attachment fixtures**, plus **10,269 transport
  comparisons**. The focused `08C.MES`, `D_TALK00.MES` and `LIBLARY.LIB`
  exports reproduce their complete GD baseline payloads under the same
  explicit projection; the existing consumer and Phase 5 lifter accept the
  actual Python exports. This reproduces the v45 contract and confirms no new
  native meaning. The empty-code container case preserves GD's empty
  `bytecode_sha256` sentinel.

  The final local batch passes **94/94 checks**, with **1,288 Python tests**,
  project parsing and 92 Godot scenes in **152.011 seconds**. The report is
  `analysis/ma10-full-handoff-local-validation.json`. The complete corpus
  comparison, source rechecks and actual Python hash above close MA-10;
  earlier component-unit counts and artifacts remain historical evidence.

- [x] **MA-11 — Record `state_u16_write_run` destinations in the handoff's state references.**
  Done 2026-09-15 (Core 0.320.0): every state-storage write run now carries
  its write row (`0x04`, `0x05`, `0x06`, `0x0A` beside the existing `0x03`,
  `0x07`, `0x08`; argument slots excluded) in both producers, verified by the
  Godot oracle test and the regenerated digest below. See the "Current
  Verification Gate" entry of the same date and `format_and_method.md`,
  "State reference index completes the write runs".
  Found 2026-09-10 while measuring the 01M caller group. `references.state`
  in the Phase 1-4 handoff carries a `write` row for a `global_u8_write_run`
  (`EVENTG11.MES:3238`, index 140) but no row at all for a
  `state_u16_write_run` (`EVENTG11.MES:250..255`, `state_u16[8] <- 0`) and
  only the read operand for one whose value is an expression
  (`01M.MES:43109..43120`, `state_u16[5] <- banked_u16[2] & 128`). The
  destination is present in the instruction's `u8_index` operand, so the
  typed IR is complete; the reference index is not. `build_event_analysis_inventory.py`'s
  `write_sites` inherit the gap, which is why two dead route inputs were found
  only by runtime tracing. Fixing it changes handoff payloads and therefore the
  recorded corpus fingerprint, so it needs the full-corpus gate re-run and a
  recorded before/after; it does not change any record boundary.

## Phase 5 — Provenance-Preserving Decompiler

- [x] **MD-01 — Define decompiler IR v1 and a lossless linear source form.**
  - Lift typed instructions and expression ASTs into statements while retaining
    source entry, `[start, end)` offsets, raw identity, CFG node, and evidence
    status on every output node.
  - Represent unresolved native and opaque records explicitly; never replace
    them with guessed commands or dialogue.
  - Python now consumes only a verified `kakyu_mes_analyzer_handoff/v1`, checks
    that typed plus opaque ranges partition every code byte, and emits
    deterministic `kakyu_mes_decompiler_ir/v1`. Preamble plus ordered node
    bytes reconstruct the exact source container and bytecode hashes.
  - Synthetic typed/expression/opaque/source-map regressions pass. Focused
    authoritative handoffs reproduce all 63,245 `D_TALK00.MES` code bytes in
    9,266 typed nodes and all 25,021 `08C.MES` code bytes in 3,103 typed nodes
    plus its one 57-byte fail-closed opaque tail.
- [x] **MD-02 — Add proof-bounded control-flow structuring.**
  - Recover `if`/`else`, loops, dispatch, and call/return only where the Phase 4
    graph proves the region.
  - Preserve irreducible or incomplete flow with deterministic labels, gotos,
    and terminal boundary nodes.
  - [x] Freeze `kakyu_mes_control_flow_proof/v1`: conditional and continuation
    transfers are promoted only when statement operands and both Phase 4 graph
    coordinates agree. Every supplied edge is owned once; mismatches become
    explicit unresolved transfers and expansion-depth leaves remain unexpanded
    anchors.
  - [x] Emit `kakyu_mes_low_level_control_ir/v1`: every graph node receives a
    stable code-offset label and exactly one low-level anchor, conditional-goto,
    goto, boundary, unresolved, or unexpanded statement grouped by source
    region and graph depth.
  - [x] Prove reducible regions, then promote only verified regions to
    `if`/`else`, loop, dispatch, and call/return constructs. Retain the frozen
    label/goto form for every unproved or irreducible region.
    - [x] Promote same-source-region forward `if_then` and two-arm `if_else`
      only when exact linear coverage, single entry per arm, acyclic
      reachability, and one proved join all agree.
    - [x] Prove maximal false-edge `guard_chain` relationships after excluding
      already structured conditions; retain every label and leave semantic
      dispatch explicitly unresolved.
    - [x] Promote only guard chains whose ASTs are equality checks over one
      identical numeric state coordinate with unique literals to
      label-preserving `value_dispatch`; leave case-body extent unresolved.
    - [x] Prove same-region natural loops only when the bounded graph is
      complete, the bounded control root reaches the header and every latch, the
      header dominates every grouped back edge, all non-header entries are
      excluded, and the non-opaque linear envelope is exact. Retain exits and
      the complete label/goto fallback without guessing `while`/`for` syntax.
    - [x] Prove literal command-`0x1D` shared-library calls return to their
      physical resume only when the matching `LIBLARY.LIB` native CFG is
      complete, entry-reachable, acyclic, boundary/exit-free, and every
      terminal is an explicit command-`0x00` return. Preserve all unproved
      calls as numeric low-level fallback.
    - [x] Prove exact same-region anchor fallthrough across NUL-terminated
      native character-stream payloads and certified shared-call returns,
      retaining every consumed stored-order node and rejecting incomplete,
      opaque, non-returning, or non-NUL spans.
    - [x] Integrate execution-aware anchor fallthroughs into natural-loop
      reachability and dominance without discarding the exact label/goto
      fallback or guessing surface syntax.
    - [x] Integrate every certified literal shared call as an exact
      call-node-to-same-region-resume-node linear-CFG edge, retaining unresolved
      and cyclic callees as numeric fallback edge rejections.
    - [x] Prove or reject cross-region join relationships only when a
      bounded-complete graph shows one unique nearest join reached on every
      path and no arm has an external graph/reference entry. Retain low-level
      labels/gotos and leave surface `if` syntax unresolved even when the
      relationship is proved.
    - [x] Normalize compound/irregular ordered guard dispatches only when every
      predicate is a bounded Boolean expression over numeric state equalities.
      Retain original ASTs and labels; keep mutual exclusivity, case bodies,
      state names, and surface syntax unresolved.
    - [x] Preserve registered and external calls as typed call sites only when
      selector/target records and the exact physical resume node agree. Emit no
      return edge without a source-bound registered body or callee total-return
      proof, and retain the original linear node as fallback.
- [x] **MD-03 — Add source-qualified semantic annotations and renderers. — COMPLETE**
  - [x] Emit deterministic `kakyu_mes_semantic_annotation/v1` JSON that assigns
    every linear node and reference a source-qualified operation or canonical
    numeric/literal identity while keeping all semantic aliases unresolved.
  - [x] Compose the accepted MD-02 structure layers into one renderer input and
    emit deterministic human-readable pseudocode with source-map reversal.
    - [x] Compose the exact linear, semantic, low-level control, and reducible
      conditional layers into source-reversible `kakyu_mes_renderer_input/v1`
      while retaining the complete label/goto fallback.
    - [x] Add source-reversible guard/value/predicate-dispatch,
      cross-region-join, and call-family overlays while retaining every proof
      rejection and the complete v1 fallback.
    - [x] Add the source-bound library/shared-return/execution-fallthrough and
      natural-loop proof family with reversible loop envelopes and every
      unresolved/rejected fallback retained.
    - [x] Emit deterministic source-order `kakyu_mes_pseudocode/v1` JSON plus
      optional derived text with exact per-line reversal and no guessed surface
      syntax, decoded dialogue, or semantic aliases.
  - Keep state slots, selectors, resources, characters, places, and event roles
    numeric or unresolved until authoritative evidence supports a stronger
    annotation.
- [x] **MD-04 — Close the decompiler corpus and equivalence audit. — COMPLETE**
  - [x] Define and validate a deterministic single-entry
    `kakyu_mes_decompiler_equivalence_audit/v1` that checks the complete byte
    partition, region ownership, one-to-one node rendering, structure/overlay
    rendering, exact source-map reversal, and a fail-closed unresolved
    inventory.
  - [x] Add a bounded Python corpus consumer that reads one source-bound handoff
    at a time, executes the complete MD-01..MD-03 chain, and retains only
    compact per-entry fingerprints, coverage, invariants, and unresolved counts.
    - [x] Reuse only already validated immutable documents within one entry;
      preserve exact output while eliminating recursive validator/composer
      replay before the corpus run.
    - [x] Run independent entries in a bounded process pool, restore manifest
      order before aggregation, and prove byte-identical serial/parallel JSON.
  - [x] Export a source-bound CFG handoff spool and complete library audit to a
    fresh directory outside the project, publish its path-free manifest last,
    and reject output beside the source ARC or inside Git.
  - [x] Complete the authoritative 1,016-entry spool export and retain only its
    compact audit report outside generated local payloads.
  - [x] Require every supported analyzed region to produce structured output or an
    explicit low-level/opaque fallback.
  - [x] Run the audited decompiler chain across all 1,016 authoritative entries
    and publish deterministic aggregate coverage and unresolved counts.
  - [x] Prove corpus-wide CFG/HIR coverage equivalence, deterministic formatting, and complete
    source-map reversal; publish the unresolved-construct inventory.

## Current Verification Gate

- 2026-09-15, Core 0.320.0 (MA-11): the reference index carries a write row
  for every state-storage write run (`0x04` `state_u16`, `0x05` dynamic
  `global_u8`, `0x06` `banked_u8`, `0x0A` `global_i32`, beside the existing
  `0x03`/`0x07`/`0x08`). The frozen v45 GD digest was regenerated: 1,016 of
  1,016 entries, 0 failed, corpus fingerprint
  `74f1408836440b7194ffb25aaa498aa8b61bda695326ed148ccd35a562a1dff8`
  (667 payloads changed, every one of them in the `references`
  component only - container, record alignment, typed IR and capability
  report are byte-identical for all 1,016; state references 540,539 ->
  561,522; no record boundary changed), and
  `audit_mes_handoff_equivalence.py --require-full-equivalent` reproduces it
  from Python over all 1,016 entries. It replaces `617111b9...d94277b` in
  `config/mes_analyzer/README.md`.
  - [x] Owner: approve the regenerated instruction-v45 corpus baseline
    `74f14088...2a1dff8` (Core 0.320.0) as the authority fingerprint, the way
    `617111b9...d94277b` was approved on 2026-09-14. Approved 2026-09-15;
    `74f14088...2a1dff8` is the authority fingerprint.
- 2026-09-13, Core 0.316.0: command `0x0D` is framed as one system call
  (selector expression plus typed record list) in both decoders, after the
  libai5 cross-check showed the separator reading had cut every call in two
  and manufactured records inside it (a fake command-`0x00` return in each of
  the 133,454 message waits, fake writes and transfers in function-2 and
  function-12 calls, and the 1,180 opaque tails). The archive now decodes with
  **zero** opaque tails; the runner keeps the message counts and dialogue
  boundaries of every committed analysis group (function 19 is the wait, 14
  the name / literal insert, 9 the MMO marker, the rest omitted presentation).
  The frozen v45 GD digest was regenerated for the new framing: 1,016 of
  1,016 entries, 0 failed, corpus fingerprint
  `617111b9e4987976301774604ccef51ee4d589b9c53976c4191f851d5d94277b`
  (1,012 payloads changed; only `FLAG_INC`, `GROUND.INC`, `PARA_UP` and
  `_TEST` are byte-identical; 2,386,774 instructions became 1,708,940 and
  the 1,180 opaque boundaries 0, while message, resource and entry counts
  grew only where the tails had hidden them), and
  `audit_mes_handoff_equivalence.py --require-full-equivalent` reproduces it
  from Python over all 1,016 entries. It replaces the 2026-09-06 fingerprint
  `fae349f9...eab6f5` in `config/mes_analyzer/README.md`. See
  `../docs/spec/mes/format_and_method.md`, "Command `0x0D` is one system
  call". The records below are the 2026-09-06 state.
  - [x] Owner: approve the regenerated instruction-v45 corpus baseline
    `617111b9...d94277b` (Core 0.316.0) as the authority fingerprint, the
    way `fae349f9...eab6f5` was approved on 2026-09-06. Approved
    2026-09-14; `617111b9...d94277b` is the authority fingerprint.
- MA-10 closed on 2026-09-06. The full-payload v2 audit passes
  `--require-full-equivalent` over all **1,016 of 1,016** entries, with no
  limit or source/producer errors. Every payload and the ordered corpus
  reproduce the frozen v45 GD baseline under the explicit
  `producer_implementation_only/v1` comparison policy; actual Python hashes
  are recorded separately. Python is the Phase 1-4 authority.
- Framing remains **1,016 of 1,016 entries sequentially**, all **2,386,774**
  records and no unframed command. All nine component targets remain equal.
  The final full-handoff unit passes 85 valid and 10 invalid oracle cases,
  10,269 transport comparisons and the full local **94/94** batch with
  **1,288 Python tests**, project parsing and 92 Godot scenes. Earlier
  component-unit verification records above remain historical.
- The command role table in `../docs/spec/mes/format_and_method.md` names 28
  commands with confirmed roles and separates, rather than guesses at, the rest:
  one proposed but unpromoted (`0x06`), four with a grammar and no corpus
  occurrence (`0x0A`, `0x18`, `0x19`, `0x1E`), and the bytes above `0x1F`,
  which are dispatcher defaults or CP932 leads and never commands.
- `0x17` is settled and promoted. `audit_mes_entry_prologue.py` measures
  **133,459 address-table entries and 133,459 prologues, none missing**, with
  the archive's only other `0x17` inside `LIBLARY.LIB`'s bootstrap — the one
  file with no address table. Executable audit v101 confirms the four operand
  bytes assemble delayed state DWORD `+0x2174`, and the copy the earlier doubt
  rested on is the active *string* cloned into the saved execution context, not
  a code target. What consumes `+0x2174` stays unresolved: four writer sites,
  no reader.
- Python unit test for `audit_eventb03_native_presentation.py`: passing.
- Authoritative `mes.arc` plus original-EXE native-presentation audit v2:
  passing and source unchanged.
- Godot decoder and event-runner focused unit tests: passing.
- EVENTB03 reduction and zero-state choice, EVENTB14, EVENTD02, EVENTD08, and
  Event Catalog focused validators: passing against unchanged source archives.
- Literal subcommand-3 same-shape inventory: selectors 2/6/7/8 only; all typed
  as exact non-executing records.
- MA-08's authoritative structural pass covers all 1,016 MES/LIB entries,
  18,079,488 code bytes, and 358,924 compound records with one explicit
  57-byte opaque tail and no unowned byte.
- The Phase 3 pass retains all 220,491 messages under typed owners with zero
  native, expression, or opaque overlap. Phases 2 and 3 are closed.
- MA-06 validates 13 default-state and 40 fully eligible 43C result routes.
  The two profiles contain 8/37 stored consumers, one shared fallback each,
  four/two empty-list boundaries, and 29/0 inactive stored result branches.
  Native UI/cadence, result labels, natural caller eligibility, and consumer
  execution remain explicitly unresolved. MA-09 and MD-01 through MD-04 are
  closed; Phase 6 MW-01 and MW-02 are closed and MW-03 is current.
- MA-09's first compatibility unit passes the synthetic analysis-index scene
  and an authoritative `D_TALK00.MES` graph at owning range
  `0x07C9..0x084A`: schema v1, 38 nodes, 30 edges, five depth-2 expanded
  regions, no stop, and no truncation.
- The v1 aggregate handoff retains reconstructed container bytes, typed and
  fail-closed opaque IR, references, CFGs, accepted call/trace evidence, and a
  deterministic SHA-256 while rejecting component-schema drift and product UI
  fields. Its authoritative `D_TALK00.MES` sample contains 9,266 static
  instructions and the same 38/30 graph; GDScript and Python agree on payload
  fingerprint `722e5323...ba5874ef`, and the source archive remains unchanged.
- The v2 reducible-condition proof retains complete low-level fallback, proves
  four same-region `if_then` regions in the original focused graph, and proves
  one two-arm `if_else` at `D_TALK00.MES:0x2B4A..0x2B7C` from a fresh
  57-node/45-edge authoritative handoff. Cross-region conditions remain
  unstructured.
- The v1 guard-chain proof retains labels while recording three chains/seven
  guards in the original focused graph and five chains/12 guards in the
  `0x2B07..0x2BBA` graph. It does not promote them to `if`/`elif` or semantic
  dispatch.
- The v1 value-dispatch proof promotes one two-case numeric dispatch in the
  original focused graph and two/four cases in the `0x2B07..0x2BBA` graph.
  Compound guards, changed discriminators, semantic slot names, and case-body
  extents remain unresolved.
- The v1 cross-region join proof audits all eight cross-region conditionals in
  the focused authoritative `D_TALK00.MES:0x07C9..0x084A` graph. Neither arm
  pair reaches a common total join, so zero relationships are promoted and all
  eight retain their exact low-level fallback with a deterministic rejection.
- The v1 predicate-dispatch proof normalizes both compound/irregular guard
  chains rejected by the focused D_TALK00 simple-value layer: five ordered
  cases become six DNF alternatives containing nine numeric state-equality
  atom occurrences. Original ASTs and guard labels remain authoritative;
  exclusivity, case bodies, semantic names, and surface syntax stay unresolved.
- Call-family proof v1 validates 352 typed sites in authoritative `01M.MES`:
  351 external MES calls and one registered DEF call at `0x0143..0x0148` with
  literal selector 11. Every site has one exact physical resume node; no return
  edge is emitted because callee total-return CFGs and the live registry binding
  are not supplied. All original linear nodes remain as fallback.
- Semantic annotation v1 covers all 9,266 linear nodes and all 3,032 references
  in authoritative `D_TALK00.MES`: 585 code, 1,025 message, 28 literal resource,
  and 1,394 numeric state symbols. It emits zero semantic aliases and retains
  character, place, event-role, and state meaning as unresolved categories.
- Renderer-input v1 source-maps all 9,266 `D_TALK00.MES` linear nodes, retains
  the complete low-level fallback and all 3,032 symbols, and promotes only the
  four reducible `if_then` structures proved by the exact matching MD-02 layer.
  Renderer-input v2 adds seven reversible proof overlays: three guard chains,
  one value dispatch, two predicate dispatches, and one external call; it
  retains all eight rejected cross-region candidates and promotes no join.
  Renderer-input v3 is additionally validated on authoritative `GROUND.MES`:
  all 7,059 nodes/2,800 symbols remain, one natural-loop overlay reverses to its
  29-node `0x16E4..0x179C` envelope, and all 441 proved/39 unresolved shared
  calls plus 441 return edges remain embedded.
- Pseudocode v1 renders that `GROUND.MES` v3 input as 7,448 deterministic JSON
  lines and an optional 594,270-byte UTF-8 text projection. All 7,059 linear
  nodes render once, all 7,088 non-header lines reverse to exact source rows,
  and decoded dialogue, semantic aliases, unmapped nodes, and guessed surface
  control all remain zero. This closed MD-03 and established the MD-04 input.
- Equivalence-audit v1 accepts that exact GROUND renderer/pseudocode pair and
  proves one complete `0x0000..0x104A4` byte partition: 66,724 bytes, 7,059
  nodes, 359 regions, 15 fallback statements, one structured conditional, and
  28 overlays. Every node, structure, overlay, and source row reverses exactly.
  The fail-closed inventory retains 37 opaque nodes, two unresolved control
  boundaries, two unresolved-surface overlays, and 85 proof-rejection evidence
  paths. This closed the single-entry contract; the complete corpus result is
  recorded below.
- Corpus-audit v1 now validates a path-safe, hash-bound handoff-spool manifest
  and matching library audit, executes all Phase 5 proof/composition/rendering
  stages one entry at a time, and emits compact JSON without raw bytes or
  pseudocode text. Its bounded-process scheduler and focused regressions pass
  on synthetic and original partial spools; the authoritative completion run
  is recorded below.
- The source-bound spool producer now emits one whole-entry confirmed-flow CFG,
  verified handoff JSON, a complete all-routine library audit, and a path-free
  manifest written only after source rehash. A focused authoritative export of
  `01M.MES` and all-library evidence passes against the unchanged archive; its
  partial manifest correctly records 1/1,016 and cannot claim full closure.
  The downstream full chain proves all 89,510 code bytes, 11,537 nodes, and
  1,585 CFG edges equivalent. A scoped validation-reuse pass reduces the same
  entry from several minutes to 23.832 seconds while preserving audit SHA-256
  `99fdd6fb...9dc23e`. A fresh eight-entry authoritative spool then completes
  in 55.056 seconds serially and 30.209 seconds with four processes; both emit
  byte-identical JSON SHA-256 `e98f9786...442dee7` and internal audit SHA-256
  `b531ac8e...85faa7a`.
- The complete authoritative Phase 5 run now covers all 1,016 entries,
  18,079,488 code bytes, 2,390,675 linear nodes, 134,475 regions, 184,537 CFG
  edges, 32,580 structures, and 23,687 overlays. Every source partition,
  node/region owner, flow edge, rendered node/structure/overlay, and reverse
  source row is complete. Two four-process runs emit exact-identical compact
  JSON SHA-256 `09dd2c12...7271fc` and internal audit SHA-256
  `10715ec9...e96716b`. Explicit fallback retains 222,972 statements, 1,251
  opaque nodes, 1,342 unresolved controls, 9,688 unresolved-surface overlays,
  and the unresolved semantic categories
  character/event_role/place/state_meaning.
  The source archive remains unchanged. MD-04 and Phase 5 are closed.
- A later MD-02 transfer-direction audit exposed one Phase 2 shadow
  continuation inside the native stream owned by `D_DATE2.MES:0x40AE..0x40B6`.
  Instruction v43/analysis v19 now retain the complete record and resume at
  `0x40B6`; record alignment, message negative space, original-EXE audit v317,
  and the Phase 1-4 completion gate all pass again.
- Transfer-direction audit v1 now covers 113,613 typed conditional and
  continuation targets with zero invalid target. It records zero same-region
  backward conditional and 373 same-region backward continuation candidates
  across 106 entries. These are inputs to the next natural-loop/call-return
  proof, not 373 already-proven loops; 1,251 opaque tails/734,485 bytes remain
  outside the absence claim. Its deterministic fingerprint is
  `5ebe345d...a75bf6ba`.
- Natural-loop proof v1 consumes only the validated linear, transfer, and
  reducible-condition chain. Authoritative `08C.MES:0x0BC6..0x0C1C` proves one
  latch at `0x0C17`; `GIVEME.MES:0x008F..0x0314` proves one latch at `0x030F`
  while retaining eleven exits. `GROUND.MES:0x16E4` keeps both candidate
  latches unresolved because the bounded control root cannot reach that component
  only in the former v1 projection. V2 integrates the source-bound execution
  fallthrough and proves both back edges while retaining two exits. No
  `while`/`for` surface syntax is claimed.
- Shared-call return proof v2 confirms 441 of 480 literal command-`0x1D` calls
  in `GROUND.MES`. Fourteen direct/transitive `LIBLARY.LIB` routines were
  audited and eleven have complete, entry-reachable, acyclic, return-only
  native CFGs; routine 28 depends on certified routines 29/30 and routine 32
  on certified routine 31. The 39 calls to cyclic routines 18/25/40 remain
  numeric fallbacks. This includes `GROUND.MES:0x16FC..0x1701` calling routine
  3 at `0x0138..0x0144` and returning through its sole `0x0143` terminal.
- Execution-fallthrough proof v2 confirms `GROUND.MES` anchor
  `L_000016EB -> L_0000170F` over eleven exact linear nodes. It records two
  native character-stream payload spans and one routine-3 return; two other
  anchor candidates remain rejected rather than inheriting unaudited calls or
  a non-NUL stream stop. It also emits 441 exact call-to-resume CFG edges and
  retains 39 cyclic-callee rejections. Natural-loop v2 consumes the exact
  anchor edge.
- Natural-loop proof v2 now proves `GROUND.MES:0x16E4..0x179C` with latches
  `0x177A` and `0x1797`, 29 exact linear envelope nodes, and two retained exits.
  Regeneration against shared-call v2 retains that result with fingerprint
  `90eab392...5c1ce10c`; surface syntax remains unresolved.
- Historical instruction-v43 verification: two complete authoritative corpus
  runs reproduced handoff fingerprint `2d182d27...b911807`. That v1 completion
  report recorded 1,016 entries,
  18,079,488 code bytes, 2,389,424 static-analysis instructions, 2,478,500
  structurally aligned instructions, 39 typed forms, 21 compound/native
  families, 1,251 strict opaque tails totaling 734,485 bytes, and the one
  57-byte structural opaque tail. Python accepts completion payload
  `1f783917...0055443b`; source remained unchanged. This was MA-09's original
  Phase 4 closure measurement, not the current v45 migration target.
- The current full local synthetic batch passes all 51 Godot scenes, the Godot
  project parse check, and 634 Python tests (53 top-level checks, zero
  failures). This includes the record-alignment and transfer-direction audit
  regressions.
- Full validation has known unrelated executable-calendar audit drift recorded
  outside MA-07; it must not be confused with a native-envelope regression.

## Dependencies Out

- `event_player.md` consumes typed analyzer records and owns ordinary playback,
  choice bridges, catalogs, terminal UX, and analysis presentation.
- `presentation_audio.md` owns actual logical surfaces, pixels, AX cadence,
  input behavior, and audio transport.
- `mes_authoring.md` consumes the stable low-level and decompiler contracts and
  owns editable lossless IR, relocation, assembly, semantic diff, translation
  authoring, and changed-MES publication.
