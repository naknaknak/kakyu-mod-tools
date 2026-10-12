# Tooling

Existing analysis/remake tooling should remain available while the Godot project is built.

The shared ARC/content runtime and independent GUI app contract is defined in
[Content Core and Independent Tools](content_tools.md). The tracked
`content_core/` implementation is the only format layer used by the new GUI
apps; existing Python extraction and reverse-engineering tools remain audit
utilities rather than app-local codec copies.

The final product scope for Content Core, ARC Browser, MES Editor, Image and
Animation ARC Editor, Audio ARC Editor, and the Launcher/Mod Project Manager is
defined in [Content Suite Product Goals](content_suite_product_goals.md).

The standalone Event Player's product-level scope, including complete-event
playback and support for original-derived content produced by the other suite
editors, is defined in [Event Player Product Goal](event_player.md). The
bounded commands and validators below are evidence and regression tools used to
reach that goal; their current analysis boundaries are not the final playback
experience.

## Optional Ghidra data-flow accelerator

Native reverse-engineering audits may use a local Ghidra 12.1.3 installation
with a Java 21 JDK through `tools/run_ghidra_mes_dataflow.py`. This dependency
is optional and must not become a runtime, editor, export, or routine validation
requirement. Machine paths, the extracted embedded runtime, Ghidra projects,
and generated reports stay outside Git.

The wrapper accepts only the embedded runtime whose SHA-256 is already bound by
the executable audit. It verifies the original launcher before and after the
read, materializes the runtime in a local analysis cache, and reuses subsequent
Ghidra projects in read-only processing mode. The tracked Java script exports
function/basic-block ownership, normalized high p-code at each candidate site,
and a bounded indirect-call target definition tree. A second anchor report
covers the exact command-`0x0E`, flag-8, startup, load, install, and run sites;
it records all calls in their containing functions, bounded definition trees
for every call input, and function-entry references. The wrapper checks that
the run/loader/installer slots converge on the same five script-family vtable
bases. Its JSON is advisory input to the exact-byte audit rather than a
replacement for authoritative MES/EXE cross-checks. In particular, a recovered
function boundary may reject an obvious distance-scan association, but it may
not promote an activation route or establish original behavior by itself. A
lack of recovered direct calls also does not exclude a virtual or other
indirect host edge.

`tools/build_mes_runtime_trace_plan.py` prepares the bounded dynamic follow-up
without launching or attaching to the original program:

```powershell
py tools\build_mes_runtime_trace_plan.py
```

The generator resolves ignored source and Ghidra settings through
`.agents/local/source_paths.md`, reruns the authoritative `mes.arc` and original
EXE audits, verifies the embedded runtime identity and x86 PE metadata, probes
an isolated Ghidra dbgeng Python environment, and writes
`kakyu_mes_runtime_trace_plan/v3` beneath the untracked local analysis cache.
The report contains module-relative breakpoint RVAs and a staged four-slot
hardware-watchpoint budget, never machine paths or original payload bytes. A
successful plan and dependency probe mean only that collection is ready; they
are not a dynamic trace and must not promote the P2-05 activation route.

Validate the generated plan without importing the debugger or attaching:

```powershell
py tools\collect_mes_runtime_trace.py
```

`--list-candidates` enumerates only PID and basename for running images whose
full file size and SHA-256 match the audited embedded runtime; it does not
attach. Live collection is intentionally separate and requires either an
explicit running process ID through `--pid` or `--auto-pid`, which fails unless
exactly one such full-file match exists. The collector refuses a non-x86
process, a changed main-module size, or any mismatch among four hash-bound code
probes before it installs breakpoints. A 64-bit dbgeng host attached to the
audited PE32 runtime is explicitly switched to its WOW64 x86 effective-machine
context before module or code identity is accepted. Module identity is checked
from the in-memory DOS/PE headers at the audited non-relocatable image base,
avoiding debugger module-name decoding and machine-local path encodings, before
the four code probes are read. It never launches or terminates the
process, removes its
breakpoints and attempts detach on every exit path, and writes the versioned
`kakyu_mes_runtime_trace_capture/v3` capture only under the untracked local
cache by default. Target qualification, matched load/install/execution
ordering, and terminal classification are recorded separately so an earlier
caller return, nested shared-stream return, or unrelated load cannot satisfy a
proof obligation. A post-start `target_root_replacement` requires the same
owner thread and active state plus one non-target MES name observed in order at
the command-`0x0E` receiver, archive loader and lookup, stream installer,
coordinate write, and matching flag writer. This excludes nested resource
loads such as `B_PIC.MES` that do not have the complete command-`0x0E` chain.
`target_execution_start` accepts either a matching fresh run entry or the
observed same-owner flag-8 resume after stream installation; it rejects
different receiver/state/thread values, a cleared flag, or zero nesting. Each
hardware watchpoint records only its first target-owner hit and reports later
hits as suppressed counters so repeated coordinate writes cannot consume the
bounded event budget. Use the isolated debugger Python configured by the plan
for live mode. The normal `py` command automatically re-executes itself through that
machine-local interpreter when live collection is requested, preserving the
argument list without a shell. Routine project validation uses no debugger
dependency.
Operator replays should also pass `--expect-target` with the intended plain MES
entry. This fails before attachment if a default or stale local plan names a
different target. `--stop-file` adds a local-cache external stop policy: between
debugger events, the collector checks for a new regular sentinel file, then
removes its breakpoints and detaches normally. The sentinel must be outside both
Git and the configured original-source roots and must not exist before
collection starts. It never shortens the configured event wait. Pybag implements
a finite wait by racing a worker-thread interrupt against the caller; repeated
one-second waits produced synthetic breaks followed by `E_ACCESSDENIED` and zero
target events in a live EVENTB03 replay. That capture is discarded.
Repeated software-breakpoint diagnostics use bounded first-N sampling by their
final normalized event ID. The report exposes the per-ID limits plus observed,
recorded, and suppressed counts, and retains the first evidence-bearing hit even
when earlier non-evidence examples filled that ID's sample. Dbgeng output is
left unchanged. Output-mask changes before and after attach, plus replacement of
pybag's text callback in an EVENTB03-ready state, all caused first-continuation
`E_ACCESSDENIED` failures with zero evidence. Console breakpoint chatter is
retained; bounded event sampling controls report size without mutating debugger
output state.
A target-inactive live control probe must remain in `collecting` state across at
least one stop-file polling interval and then finish as `operator_stop` with zero
events while the game remains responsive. This validates attach/continue/detach
control only and must not be cited as target MES evidence. It also does not
establish that output callback replacement is safe once EVENTB03 is ready.

Manual event replays may opt into two bounded active-state snapshots with
`--capture-state-snapshots`. The collector announces
`MES_RUNTIME_TRACE_ATTACHED` only after source/runtime identity checks and all
software breakpoints are installed. It then stores the exact `0x3000`-byte
state at the source-qualified target execution start and first stream-qualified
target run return or root replacement, plus hashes and the diagnostic
`state_u16[13/18/21]` values, inside the
same local-only capture. This is a collection aid rather than MES evidence by
itself: a timed-out, unmatched, or incomplete trace cannot promote a branch or
choice claim.
The same source-audited plan includes the primary-1/secondary-21 native result
store at runtime VA `0x00414DC5`. A hit becomes `target_choice_result` only
inside the matching target run, on its owner thread, with the same active-state
pointer. The capture normalizes `AX` to a one-based 16-bit result and records
the current code-relative coordinate before the store to `state_u16[18]`.
This closes neither a route mapping nor a terminal by itself; those require a
user-observed selection and the matching target trace from the same replay.
The first such row-3 replay did not hit that route, so the plan also includes
the audited common modal result copy at runtime VA `0x0043532E`. Before
`mov [esi+8], eax`, `EAX` is the one-based selected-record result. It is
accepted only inside the same qualified owner-thread target run and records
the active stream-relative coordinate, allowing a real choice to be mapped
without assuming which command-`0x12` record route returned it.
If that downstream modal copy is bypassed, the plan also samples the earlier
selected-control store at runtime VA `0x00401CF7`. The original EXE maps the
host row, adds one, and stores `ECX` to the control's result field there.
Keyboard and pointer confirmation share this value, so the collector can keep
the same source qualification without guessing a later return route.
The fourth diagnostic probe covers the separate standard-message candidate,
the `CNormalSelect` result store at runtime VA `0x00438DAD`. It captures `ECX`
after the class-specific host-row mapping and `+1`, verifies the retained
active-state pointer, and records `normal_select_store`. A nested stream whose
coordinate is not relative to the saved target context is retained with null
`code_offset` and `nested_stream_unresolved`; the tool never subtracts those
unrelated pointers.
All four result probes remained untouched in the five complete target-qualified
row-3 replays. The report now distinguishes this absence from a hit that fails
qualification: `target_choice_probe_diagnostics` lists any post-start rejected
hit with its probe/result path, observed and expected active state, stream
pointers, and rejection reasons. Only fully qualified hits appear in
`target_choice_results`. The next trace expansion belongs upstream at the
audited command-`0x1D` shared-script call and command-`0x12` ingress.
Those upstream observations are now part of the 24-breakpoint plan. The
command-`0x1D` probe at `0x0041A533` captures its adjusted script receiver,
retained active state, selected cursor/code base, destination first dword at
base plus cursor, saved caller resume cursor/code base, and stack. The
command-`0x12` probe at `0x0043F2ED` captures the active stream before
native-record dispatch. Qualified records appear in
`target_native_path_observations`; they are diagnostics, not additional proof
obligations. Executable audit v315 fixes adjusted receiver `+0x4B58C` as the
cursor and `+0x4B590` as the code base. Reports expose their sum as
`active_instruction_pointer`, retain the cursor as `active_stream_offset`, and
publish target `code_offset` or `caller_resume_code_offset` only when the
corresponding base equals the matched target installation's code base.
Executable audit v316 additionally fixes the pre-restore `CScript::run` return
probe at `0x0043D629`. Runtime trace plan/capture v3 records the receiver's
active state, cursor, code base, nesting, and frame return address there. A
matching owner on a different code base is a nested-stream return and cannot
complete the target-return obligation. `--continue-after-matching-return` keeps
an operator-driven session attached after the first stream-qualified target
return until another bounded stop condition or Ctrl+C.

Executable audit v317 binds command-`0x12` primary-1 secondary selectors 3/4
to the original runtime's `CSpriteDays` and `CSpriteTimeMoney` members. It
checks the secondary remap targets, owner construction/vtables and RTTI, their
shared slot-`+0x24` handler at `0x00436750`, and the handler's visible-flag
write plus rectangle refresh. The `native_status_sprite_visibility` result
records that a literal-zero third expression hides the selected status sprite
and that these routes do not read the EVENTB03 weekday/date/HHMM context
fields. This is a bounded presentation-effect result, not evidence of complete
EVENTB03 playback sufficiency.

`audit_mes_runtime_trace_preset.py` schema v4 performs the corresponding
cross-source join. It reopens authoritative `EVENTB03.MES`, parses the complete
typed record lists at `0x011B..0x0126` and `0x0126..0x0131`, requires literal
tuples `(1,3,0)` and `(1,4,0)`, and binds each selector to the v317 route. The
path-free report emits record coordinates, envelope hashes, classes, and
effects under `native_setup_records`; it emits neither payload bytes nor local
paths. A changed record, route class, visibility handler, or source hash fails
the audit. Schema v4 additionally requires a 100%-aligned target projection
with no unresolved condition coordinates and scans every decoded instruction
operand. Across 2,237 instruction identities and 174 references to 14 fields
covered by the captured layout, no target-local consumer of context
`state_u16[4]`, `[7]`, or `[19]` exists. Those stable values remain path-free
surrounding-host observations; the target-local candidate field set is empty.
Encountered `banked_i32` operands are reported as outside the mapped snapshot
storage families rather than silently interpreted.

The companion EVENTB03 deletion matrix now retains a hash-bound summary for
each pre-choice library call returned by Event Player's analysis helper. Calls
at EVENTB03 `0x00FC/0x0225/0x0235/0x08DF` select routines `28/21/28/21` with
argument slot 1 values `1/1/0/46635`. Their exact LIBLARY traces have
`8/5/6/5` rows and retain `1/2/1/2` aggregate omitted-presentation counts.
Content Core `0.196.0` additionally binds typed control lists: routine 28's
row is selector-7 AX invalidation, while routine 21's two rows are selector-8
AX activation/wait and subcommand-10 mode-1 guarded surface composition. The
full signature and typed list are identical for the observed, empty, and four
deletion states. These effects remain non-executing and produce no sandbox
state diff.

Content Core `0.197.0` introduced the narrow aligned-region projection used by
the static MES analysis index. Content Core `0.210.0` extends its qualified
case from a branch-like first payload byte to a handler-consumed run containing
`0x0B/0x0C` at any position. The authoritative analysis-corpus validator
reports 332 such records/2,247 payload bytes, 1,251 byte-preserving
opaque tails/734,485 bytes, and 220,491 owned messages with zero native,
expression, or opaque payload conflicts. This is structural and extraction
safety evidence, not native-effect execution.

Content Core `0.198.0` adds the versioned record-alignment audit. The
authoritative pass partitions all 18,079,488 code bytes across 134,475 regions:
2,478,500 typed instructions own 18,079,431 bytes, and one 57-byte fail-closed
opaque tail owns the remainder. Its 358,924 compound records/3,842,271 bytes
are grouped by typed family, with exact source slices checked per record.
`audit_mes_record_alignment_corpus.gd` is part of the original-source headless
batch and fails on gaps, overlaps, changed raw bytes, or source mutation.

`audit_mes_transfer_direction_corpus.gd` scans only current-schema typed
conditional and continuation operands after verifying every per-entry Phase
1--4 handoff. The current report covers 113,613 transfers with zero invalid
target and retains 373 same-region backward continuation candidates for the
next natural-loop proof. Opaque ranges remain counted but unscanned. Write the
optional path-free JSON outside the source archive directory:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_transfer_direction_corpus.gd -- `
  <mes.arc> <transfer-direction.json>
```

Content Core `0.214.0` reserves `kakyu_mes_natural_loop_proof/v2` for the
Python Phase 5 consumer. `tools/prove_mes_natural_loops.py` accepts matching
linear, transfer, reducible-condition, execution-fallthrough, shared-call, and
library-audit proofs. It computes dominators only
on labels reachable from the bounded local control root or a confirmed external
entry, groups backward gotos by header, and proves a loop only when that header
dominates every latch and all non-header entries are excluded. The exact
non-opaque linear envelope, exits, and fallback statement IDs are retained;
`while`/`for` syntax remains unresolved.

```powershell
py tools\prove_mes_natural_loops.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json> `
  <execution-fallthroughs.json> <shared-call-returns.json> `
  <library-audit.json> <natural-loops.json>
```

Content Core `0.215.0` reserves
`kakyu_mes_shared_call_return_proof/v2`. The Python consumer accepts a
validated linear IR and a `kakyu_mes_library_audit/v17` report, then emits a
return certificate only for a literal command-`0x1D` selector whose audited
callee CFG is complete, entry-reachable, acyclic, boundary/exit-free, and
return-only at every terminal. Strict/structural diagnostic incompleteness does
not block a complete native CFG, while every nested literal shared call must be
resolved to another total-return certificate by a deterministic fixed point.
Unproved calls remain numeric fallback nodes.

```powershell
py tools\prove_mes_shared_call_returns.py `
  <linear-ir.json> <library-audit.json> <shared-call-returns.json>
```

Content Core `0.219.0` reserves `kakyu_mes_call_family_proof/v1`. Its Python
producer validates external command-`0x0F` target ASCII case-insensitively and
registered command-`0x11` selector expressions, then binds each accepted call to the one
linear node beginning at its exact physical resume coordinate. The input does
not contain an external callee's total CFG or the live registered-body binding,
so the proof deliberately emits no return edge and retains the original linear
node as fallback:

```powershell
py tools\prove_mes_call_families.py `
  <linear-ir.json> <call-families.json>
```

This closes the MD-02 call-family site boundary without claiming callee effects,
registered-body lifetime, or caller continuation. Those require separately
source-bound evidence before a future consumer may add a CFG edge.

Content Core `0.216.0` reserves
`kakyu_mes_execution_fallthrough_proof/v2`. Its Python producer consumes the
matching linear, transfer, and shared-call proofs plus the library audit needed
to revalidate that call certificate. It proves a next-anchor fallthrough only
when every intervening byte is retained as an ordinary typed node, an exact
NUL-consumed native character-stream payload, or a certified shared call that
returns to its physical resume. It also emits an explicit call-to-resume edge
only when the certified call and exact same-region target linear node agree;
all unproved or mismatched calls retain fallback records.

```powershell
py tools\prove_mes_execution_fallthroughs.py `
  <linear-ir.json> <flow-proof.json> <shared-call-returns.json> `
  <library-audit.json> <execution-fallthroughs.json>
```

`tools/audit_eventb03_native_presentation.py` narrows that boundary using an
independent, fail-closed cross-source audit. It scans only the complete literal
`0D 03` selector-2/6/7/8 and `0D 0A` mode-1 envelopes, requires their exact
archive-wide counts and `LIBLARY.LIB` coordinates, reruns executable audit
v317, and checks the additional AX activation/wait and surface-composition
native spans and direct call targets. Its path-free v2 report records bounded
effects and hashes but never claims to execute native cadence, compose source
pixels in the tool, or establish full EVENTB03 playback sufficiency.

V2 additionally binds selector 2's selected-cell state-1 handler and selector
6's consumer and nested-cell handlers. An exhaustive same-shape inventory
contains no literal subcommand-3 selector other than 2/6/7/8; selector 2 has
2,583 exact envelopes in 568 entries and selector 6 has 5,183 in 664. This
corrected the first EVENTD02 shadow-write defect for selectors 6/8. The then
remaining `global_u8[767] = 1` was also a shadow, not an ordinary MES write:
v44 additionally consumes selector 1's `0x03C9..0x03D6` record, leaving `[767]`
unchanged. See the v44 selected-cell correction in the format document. The five exact
seven-byte envelopes are now first-class decoder metadata
under instruction v42. Event trace v67 advances over each complete envelope
and emits one explicit omitted-effect row without mutating the gameplay
sandbox. Near-matching selector, mode, or framing bytes continue to fail
closed at the generic native boundary. The deletion matrix hash-checks those
typed effects, so a later decoder regression cannot silently turn them back
into generic skips.

Python structured IR v4 now consumes command `0x12` typed records and the
confirmed `0x0D/0x09` MMO plus `0x0D/0x0B` surface-operation envelopes as
whole structural units. This eliminates record-body shadow instructions from
downstream basic-block IR. On authoritative EVENTB03 the v6 basic-block layer
therefore reports 32 valid conditions, zero unresolved conditions, and a
100% aligned projection; the prior ten empty-stack branch candidates were
presentation-record overlap artifacts.

`tools/audit_mes_runtime_trace_terminal.py` reclassifies a complete
root-replacement chain already present in a local v3 capture whose older plan
did not list that terminal alternative. It requires the six non-terminal proof
obligations, verifies the selected-control result and command-`0x12` mirror/
sentinel-reset sequence, reopens the authoritative target entry, and matches
the successor to its command-`0x0E` records. The source archive is hashed before
and after. Schema v2 binds the runtime choice stream to `LIBLARY.LIB` with
six distinct command-`0x1D` dword anchors, including both a target-linked call
and a library-self-linked call. It validates result `3` at routine-40 record
`0x1C95..0x1CA0` and the later sentinel reset at `0x1CC4..0x1CD0`. The
schema-v3 report then joins that source-bound result to the authoritative
`state_u16[21]` dispatch chain: results 1/2/3 reach only the command-`0x0E`
handoffs at `0x1BB6`/`0x26F4`/`0x3D46`, respectively, before their common
return. It promotes only `command_0e_host_activation` and keeps portable caller
state unresolved.

The first versioned Event Player catalog is
`res://config/event_catalog/original_events_v1.json`. It is loaded through the
shared Content Core validator rather than as unvalidated UI JSON. Its twelve
seeded routes are metadata only: no dialogue, original payload, extracted
asset, or machine-local source path is stored. Run the synthetic catalog test
for schema/reference rejection and the original binding validator for a
configured read-only `mes.arc`; neither opens a window.
Event Player's **Event Catalog...** window consumes the same validated browser
projection. Character/date/place/type/support filters compose, selection shows
recommended preset, branch/choice/terminal coverage, compatibility and blocker
summaries, and MES-source handoff remains disabled unless the selected callee
exists in the currently open ARC.

Event Player starts in **Playback** mode. This leaves the catalog, logical
game frame, confirmed Start/Continue actions, and BGM control visible while it
hides source offsets, manual boundary execution, resource diagnostics, sandbox
editing, trace tables, and the debug status line. Choose **Analysis** from the
toolbar to restore those controls on the same live runner and isolated state;
switching modes does not reload the ARC, restart the event, or discard the
current result. **Select MES source in Analysis** in the catalog performs that
mode switch after selecting an available callee. **Play catalog preset**
instead verifies the open source profile and effective MES identity, creates a
fresh isolated state from the catalog preset, starts at the confirmed
coordinate, and automatically crosses confirmed internal boundaries to the
next dialogue, choice, or terminal. Switch to Analysis at any time to inspect
the same live session. Unsupported or non-progressing traversal fails closed.

With an ELFIMAGE content set open, **Derived...** opens the media-layer
manager. Choose **Add or replace...** and select an ARC copy written by the
suite together with its `.kakyu-provenance.json` sidecar. The sidecar supplies
the logical archive identity; choosing another copy for the same logical
archive replaces that effective layer transactionally. The table reports the
logical archive, selected filename, compatibility, and replacement count.
**Remove selected** detaches one layer and **Clear all** detaches every derived
layer. Overlay remains above derived content, and original ARC remains below
it. Changed `mes.arc`, a missing or stale sidecar, a source mismatch, or a
failed candidate preflight leaves the current document, Results, continuation,
preview media/audio, and sandbox untouched. The file chooser remembers the
last successfully selected folder; no absolute path is written to tracked
metadata.

All OverlayPackage writers use the shared cross-process publication lock before
reading the manifest revision. A competing app receives a retry error and does
not prepare or publish a manifest. Dead owner processes are quarantined, and
their recognized sibling temporary files are removed before the existing
revision/CAS transaction starts. The synthetic lock scene launches a second
headless Godot process to prove that two publishers preserve both records; it
does not open a window or take input.

Portable mod metadata uses `project.json` schema
`kakyu_content_project/v1`; see
[Content Project Contract](../data/content_project.md). The shared loader
rejects unknown fields, payloads, absolute/source paths, invalid source-set
fingerprints, incompatible Content Core ranges, and out-of-width Event Player
preset writes. The publisher performs an exact revision/SHA compare-and-swap
under `.project.lock`, reopens the result, and never writes an original ARC.
Run `res://tests/test_content_project.tscn` headlessly for schema, conflict,
lock, recovery, and portability regressions.

`KakyuContentWorkspace` composes that project with the validated overlay and
the exact selected ContentSet as a path-free
`kakyu_content_workspace_snapshot/v1`. Open/Create is transactional; failure
keeps the last generation active. Its target-scoped staging methods merge over
the latest manifest while preserving unrelated tool records and require the
source hash computed by OverlayPackage to equal the project binding. Run
`res://tests/test_content_workspace.tscn` headlessly for create/open, immutable
snapshot, external-record merge, stale revision, source mutation, and lock
regressions. The Content Suite Launcher now exposes minimal Create/Open actions,
builds source bindings from the selected ELFIMAGE set, and retains a validated
workspace generation on failure. All five independent apps consume the same
strict named startup context, reopen the workspace in their own process, choose
only a compatible bound ARC, and then activate the shared manifest. Legacy
positional/direct opening remains available.

The native executable audits hold no copy of the executable (WD-25 item 1,
2026-10-11). **The rule:** no tracked file holds a region of the original
executable - code, data tables or vtables, whatever its length. Every byte
expectation of `tools/audit_ai5_mes_exe.py`, `tools/audit_ai5_arc_exe.py` and
`tools/audit_ai5_audio_exe.py` is an address plus a `ByteSpan(length, sha256)`.
What stays, by measured decision: ASCII identifier strings (RTTI names, INI
keys, archive and file names, `EXPECTED_STRINGS`, `EXPECTED_TEXT`); generic
opcode templates of seven bytes or fewer inside functions; test-authored
synthetic instruction bytes, where a sequence of eight bytes or more must carry
a synthetic immediate (for example a pointer such as `0x01234567`), because
generic x86 idioms of that length occur in the original; and numeric facts
(addresses, `EXPECTED_U32` pointer values, `EXPECTED_CALLS` targets).

**The reading rule.** A tool or test that needs the content of a span reads it
from the user's own executable at run time and uses it only after its SHA-256
matches. `ByteSpan` (`length`, an exact int in 1..0x100000, and `sha256`, 64
lowercase hex digits; a malformed literal fails at import), `span_matches`,
`span_bytes` (the bytes, or `None` on a different hash) and `measure_spans` live
in `tools/audit_ai5_arc_exe.py` beside `PeImage` and raise as `read_va` does for
an unmapped or non-file-backed address. A comparison at an address is
`span_matches`; the two exact-sequence searches (`PUBLIC_CONTEXT_CALL_SHAPES`,
`COMMAND_ACTIVE_STRING_DOCUMENT_STEP_CALL_SHAPES`) and the one report field that
needs a byte (the call register of the media two-hop capture groups) take the
bytes from `span_bytes` at the expected site; reports print `span.length` and
`span.sha256`. No report schema changed: the audits' outputs are byte-identical
to those of the bytes-holding code on the user's executable.

**The data.** `tools/audit_ai5_mes_exe.py` keeps its anonymous address-to-span
expectations in `config/ai5_exe_audit/expected_bytes_v2.json`, schema
`kakyu_ai5_mes_exe_expected_bytes/v2` (v1, which held the payloads as hex, is
deleted and refused by schema). An expectation is data only when both its
address and its span are plain literals; one whose key or value names a constant
stays in the module, because there the name carries the evidence that a bare
address would not. Entries are `{address, length, sha256}` in strictly
increasing address order. `_load_expected_bytes()` fails closed on a missing
file, any schema other than v2, an unexpected or missing key at any level,
header and list counts other than 696 and 3, an address that is not an exact
integer in `[0, 2^32)` or is repeated or out of order (in both lists), a span
that leaves the 32-bit address space, a malformed length or hash, a shadowed
record that does not name a live address, differ from it and name it as its
winner, a shadowed address set other than the three preserved sites, and a data
digest other than the pinned `EXPECTED_BYTES_DATA_SHA256`
(`177b04ad2b4845d9ec1e9e6229b0a656f72e067cd3b4618608d348a00f4a98f3`: SHA-256
over the schema line, then each entry as address, length and raw digest, then
each shadowed entry the same plus the superseding length and digest). The build
ships the file without the tests, so the audit itself refuses a modified one;
the mismatch error prints the computed digest, so a legitimate regeneration
learns its new pin from the error. The file also carries `shadowed_entries`:
spans an earlier declaration of the same address recorded before a later one
overwrote it. They are kept because they are measured evidence, and validated
as above, but never returned, so what the audit checks is unchanged. The
table's symbolic siblings, `EXPECTED_U32` and `EXPECTED_CALLS`, stay in code for
the same reason.

Anonymous and symbolic tables are merged with explicit collision checks and a
1,043-site count gate. Four pre-existing overlaps are retained explicitly:
`0x00433D81` and `0x0043E800` have equal spans; `0x00434230` and `0x00437540`
have different anonymous evidence and symbolic winners. Both values are
SHA-256 pinned and the historical symbolic winner remains active. Neither
evidence is deleted or silently added to the audited set. Any new collision or
changed alias fails. The complete sorted `(address, length, sha256)`
fingerprint of the merged table is
`99bc1fd9dcac9c3312f81692d076db0a75b84016a1ace7ac7e6447d6fe91d44d`; the
per-table digests of the 54 span tables are unchanged by the representation.

**The tests.** The MES, ARC and audio audit tests rebuild their synthetic PE
fixtures byte for byte from the user's executable, found through the
environment variable `KAKYU_ORIGINAL_EXE` alone (`tests/original_executable.py`;
there is deliberately no fallback to `.agents/local/source_paths.md`, because
the validation cache fingerprints the executable only when the run passes it).
They skip without it, and a set but wrong executable errors. The batch passes
`--exe` to the Python suite (`docs/spec/data/validation_checks.md`).
`tests/test_expected_bytes_data.py` needs no executable.
`tests/test_no_original_executable_bytes.py` enforces the rule: Part A (local)
forbids module-level byte literals of eight bytes or more in the tools that read
the executable; Part B (with the executable) asserts that no literal of eight
bytes or more, with five or more distinct values and not ASCII, occurs verbatim
in it anywhere in the tracked and shipped files of `tools/`, `tests/`,
`content_core/`, `docs/`, `config/ai5_exe_audit/` and the root `*.md` files.
There is no allowlist: a coincidental idiom is fixed in the test.

**Adding an expectation.** Measure it, never paste it:
`py tools\audit_ai5_mes_exe.py <AI5WIN.exe> --measure-span 0xADDR:LEN
[--measure-span ...] [--image runtime|launcher]` prints one JSON row
`{image, address, length, sha256}` per request and never a byte, after checking
that the input is the original executable the audits pin. Put the row's length
and hash in a `ByteSpan(length, "sha256")`, or in `expected_bytes_v2.json` plus
the new pin when the pair is anonymous.

**No original archive content in tracked files (WD-25 item 1b, 2026-10-12).** One
rule covers bytes and text. A window of 8 bytes is *rare* when 1 to 99 entries of
the user's `mes.arc` or `data.arc` hold it, and no tracked file may hold a literal
in which rare windows form an interval that is not a chance class (printable
ASCII, with tab, CR and LF anywhere and NUL only as trailing padding; fewer than 5
distinct values; a small-integer progression). Text is every run of 4 or more
Japanese-script characters in tracked text, encoded to cp932 (4 double-byte
characters are 8 bytes); a run cp932 cannot encode cannot be original text and is
skipped. Windows held by 100 or more entries are the format's command encoding
and may stay: that bar (`IDIOM_HOLDERS = 100`) is a **tool decision**, not a fact
about authorship. Its measured basis is that today's idioms are held by 78-94% of
the 1,016 entries (the protagonist-name insertion in 948, the voice-bit records in
788-822, two short sequences in 925 and 951), so it removes nothing a script in
this format must write, and it sits above the records a family of related scripts
shares (10-99 entries), which are findings. The tree-wide measurement at that bar
was 88 findings in 38 files (85 byte and 3 text) and none in `content_core/` or the
Phase 1-4 analyzer.

**The treatments.** S, a synthetic operand: a fixture changes an operand the test
does not depend on (a constant, an index, a script or resource name, text) and,
where an asserted value moved with it, only that expected value moves; a fixture
whose windows cannot be cleared by an operand alone may reorder independent
instructions, re-encode a literal at another width (16 or 32 bits), lengthen a
label with its layout targets, or insert one no-op source-line marker, each
recorded as an exception to "same instruction kinds and lengths" with the moved
offsets listed. T, the menu label of `tools/inspect_normal_talk.py`, is matched by
the length and SHA-256 of its cp932 bytes (no raw-byte pre-filter, so every entry
is decoded) and the documents describe it in words. H, a length and a hash:
`validate_mes_bgm_route.gd` compares its prelude marker so. D, a description in
prose. G, a record built from named grammar constants, only where the exact record
is the subject and no byte can change without naming another engine function or
record or breaking its decoding; each is built once and every site takes it from
`tests/mes_record_grammar.gd` or `tools/payload_values.py` (the scene
`test_mes_record_grammar` and `test_payload_values` decode each builder). The guard
cannot see bytes built this way, so G is a recorded exception and never an
allowlist: four record families (the map-location poll `Util(6,13)`, the
routine-40 selection `Util(1,21,x)`, the START bootstrap calendar fill, the
script-execution marker head of selector 3), five byte forms, at the cap of five.

**The guard.** `tests/tracked_literals.py` holds the extraction both byte guards
share (`python_byte_literals`, `python_hex_strings`, `python_integer_lists`,
`text_hex_literals`, `integer_list_literals`, `escaped_byte_literals`,
`japanese_text_runs`, `window_findings`). `tests/original_archives.py` reads the
user's archives from `KAKYU_MES_ARC` and `KAKYU_DATA_ARC` alone, both required.
`tests/test_no_original_archive_bytes.py` Part A is a local self-test of the
scanner on synthetic entries; Part B scans `tools/`, `tests/`, `content_core/`,
`docs/`, `config/` and the root `*.md` files in about 30 s (budget 90 s) and
reports file, line, form, length, interval offsets and the fewest holders - never
a byte or a character. Base64 strings and tracked binary files are outside the
guards; the author's companion inventory covers them and found nothing.
`tests/test_no_personal_data.py` keeps the owner's user name, drive-letter paths
into a user profile or outside the tests, and personal e-mail addresses out of
tracked files (its user-name and git-address rules read the machine at run time).
A fixture file that other scenes extend or preload is verified by running every
scene that shares it, not only its own.

`tools/content_suite/` is laid out in three directories plus a shared root, as
of 2026-09-08. `apps/` holds the ten GUI application, launcher and panel scripts
with their seven scenes. `validators/` holds the 23 CLI scripts that instantiate
a GUI application — nineteen drive `event_player.tscn` and one each the ARC
Browser, MES Editor, Image Editor and Audio Editor. `cli/` holds the 106
headless CLI scripts. The directory root keeps `tool_path_history.gd`,
`tool_window_profile.gd`, `playback_package_export.gd`, `validation_report.gd`
and `validation_session.gd`, which `apps/` and `cli/` both reach, together with
the Python and PowerShell runners.

The middle directory exists because the dependency it names is real: those 23
scripts run headless like any other check while depending on a GUI application,
so a two-way split would have filed them as CLI and made the structure claim an
independence the code does not have. `run_headless_validation.py` names each
check's script group-qualified, and it is the only place that builds a
`content_suite` path from a variable.

`tools/content_suite/run_headless_validation.py` is the versioned batch entry
point for accumulated Content Core and independent-app verification. Its base
layer runs Python regressions, a Godot parse check, and synthetic GDScript tests
without opening a window. The complete Python mutation/audit corpus has an
explicit 3,600-second child-process budget, separate from the shorter ordinary
checks; `--python-timeout <seconds>` may raise or lower that finite bound for a
known host, and exceeding it remains a failed batch rather than a silent skip.
The v165 native-MES executable audit test file alone measured 1,932.744 seconds
on the configured development host, so the former 1,800-second aggregate bound
could not complete even that one regression module. Audit v182 keeps the same
schema and evidence inventories while adding two audit-local, source-derived
indexes: all relative direct-call destinations are collected in one section
pass, and bounded MOV memory-load candidates are decoded once per immutable
`PeImage` extent set for reuse by same-register and one-hop distance queries.
The indexes never cross an opened image boundary. On the same development
host, the accepted synthetic full audit measured about 13.8 seconds before and
1.7 seconds after this change; the original embedded runtime audit measured
about 6.5 seconds before and 1.2 seconds after it. The complete native-MES
module measured 325.611 seconds for 164 tests, down from the v181 baseline of
2,787.038 seconds for 163 tests. A follow-up measured profile shared that same
per-image bounded ModRM operand index with the indirect-memory `call`/`jmp`
queries; the accepted synthetic audit then measured about 1.0 second. Its
consumers still independently filter opcode, operation, virtual slot, base
register, and displacement, so the optimization does not broaden the evidence
contract. The complete module then measured 195.887 seconds for 165 tests,
about 93 percent below the 2,787.038-second v181 baseline. These are
development-host observations, not
portable timeout promises; the finite 3,600-second batch budget remains a
safety ceiling. When given a user-owned
`ELFIMAGE` directory, its
original-source layer adds read-only ARC/MES/audio/image corpus checks, the ARC
writer no-op rebuild corpus, original ARC Browser, MES Editor, and Event Player integrations,
the START.MES inline-script execution record check, the zero-start DEF_MAIN
context-path audit, the one-level startup-definition call audit, and the
exact surface-operation corpus and reachability audits, and the exhaustive
Event Runner anchor audit.
`audit_mes_analyzer_handoff_corpus.gd` also runs in the `--elfimage` layer
with a 1,800-second budget. It recomputes the Phase 1-4 handoff fingerprint
over the complete archive and fails the batch on a frozen-baseline mismatch.
Failure prints `MES_ANALYZER_COMPLETION status=failed` (with its schema and
failure count) instead of claiming completion, and writes no completion file.
The owner approved the instruction-v45 baseline `fae349f9...eab6f5` on
2026-09-06. TD-15 verified it over the complete archive and through the Python consumer;
the historical v43 fingerprint is no longer the current target. An optional
original launcher path runs the bounded `kakyu_ai5_arc_exe_audit/v5` native
ARC/A6 read-contract check, `kakyu_ai5_mes_exe_audit/v317` MES route check, and
`kakyu_ai5_audio_exe_audit/v7` Ogg/Voice route check in the same batch. The
summary contract is
`kakyu_content_tools_validation/v6` (since 2026-09-23: v5 plus `jobs` in the
context for `--jobs N`; v5 was v4 plus the cached rows, the `cached` count
and the cache context; v5, v4 and v3 reports still load); optional JSON reports are machine-local
evidence and must not be committed when they contain source paths. The report
envelope stores `schema`, `payload_json`, and `payload_sha256`, hashing the exact
UTF-8 payload string so Python and Godot need not reproduce one another's JSON
number serialization. Its payload retains the summary/check results and adds
a UUID `run_id`, immutable repository-suite source context, six explicit
coverage groups with unrun reasons, and a configuration-error diagnostic.
Since 2026-09-21 (TD-32 part 1) the checks are a tracked registry,
`config/validation/checks_v1.json` (`kakyu_validation_checks/v1`), that
the runner loads and validates, and `--tier local|archive_quick|full`
selects by tier (`tools/README.md`, "Content Suite validation").
Per-check statuses are `passed`, `failed`, `timeout`, or `error`; unsuccessful
checks retain at most 4,096 output characters. `--report <path>` writes this
validated envelope atomically even for configuration errors. `--check <name>`
may select named checks repeatedly; unknown/unavailable names fail configuration,
and filtered-out checks remain visible in coverage reasons. `--run-id <UUID>`
allows the launcher to correlate a child result with its request.

The Launcher **Validation results and coverage...** panel invokes the same
runner without a shell or console window, freezes the selected source context, and polls without
blocking its UI. It reads a result only after the process exits and checks
report schema/fingerprint/counters, UUID, source paths, and matching exit code.
Reports default to `user://content_tools/validation/`; reopening one labels it
as stored evidence. v2 reports remain readable through an explicit unsigned
migration with unknown coverage. Execution requires the development runner,
Windows `py`, and Godot; report reading does not. The displayed repository suite
does not validate workspace overlays or a playback package. Native MES
exact-sequence and literal inventories reuse results only within a single
immutable opened PE image. Synthetic mutation fixtures and separately opened
original executables therefore retain independent caches and cannot inherit
one another's scan results. The aggregate batch discovers every Python
unittest case once, weights the measured native-MES audit module as the slow
group, and runs balanced subprocess shards with a bounded per-shard timeout.
The default maximum is four workers and is explicitly overridable for hosts
with lower CPU or memory capacity.

## Existing Tools

(The per-event Event Player validators whose run lines appear below -
`validate_event_player_event*.gd` - were retired on 2026-09-21, EP-10 unit 5c;
the lines are historical.)

- Kakyu image extraction pipeline documented in `tools/README.md`:
  - `tools/ai5_lz.py`
  - `tools/extract_kakyu_arc.py`
  - `tools/extract_kakyu_all.py`
  - `tools/convert_mmo_best.py`
  - `tools/convert_dat_pal.py`
- Kakyu MES extraction pipeline documented in `tools/README.md`:
  - `tools/mes_archive_ir.py` for lossless `ai5_mes_container/v1` JSON
  - `tools/mes_basic_block_ir_v6.py` for production `ai5_mes_basic_block_ir/v6` JSON
  - `tools/export_map_location_entries.py` for all-map MES location-entry runtime projections
  - `tools/inspect_mes_bgm.py` for authoritative `LIBLARY.LIB` BGM selector/WAV evidence
  - `tools/audit_mes_mmo_markers.py` for exact filename-envelope counts and optional `mmo.arc` resolution
  - `tools/audit_mes_voice_markers.py` for exact voice-envelope counts and original audio-ARC resolution
  - `tools/audit_mes_surface_operations.py` for every exact presentation-subcommand-11 typed envelope, confirmed mode/record-shape counts, and unresolved-dispatch coordinates
  - `tools/content_suite/cli/audit_mes_surface_operations.gd` for the independent shared-decoder corpus oracle and source-hash guard
- Human-readable, scene-oriented results are indexed in
  [MES Analysis](../mes/index.md).
  - supporting `tools/mes_*.py` decoder stages retained for auditability
- `tools/extract_eve_tables.py`
- `tools/build_map_event_dataset.py`
- `tools/build_machi_movement.py`
- `tools/inspect_map_sources.py` for authoritative `MPC/CCD/EVE` auditing,
  collision-mask previews, local runtime projections, and native tiled map
  texture reconstruction
- `tools/map_coordinate_picker.html`
- `tools/capture_saturday_ui.tscn` for deterministic 640x400 room and town UI
  captures; set `KAKYU_CAPTURE_DIR` to choose an output directory
- VM/static analysis tools under `tools/`

Kakyu source archives and generated extraction output are local-only. The integrated pipeline reads from `assets/_source/kakyu/ELFIMAGE` by default and writes below `assets/_extracted/kakyu`; neither location belongs in Git.
MES analysis JSON should be generated below the Git-ignored `analysis/` directory. `mes.arc` entries are the authoritative MES source; transformed standalone `.MES` files are not a substitute for the raw archive container.

Run the bounded EVENTB01 coordinate-zero route through its caller handoff
without opening a window or taking foreground input:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventb01.gd -- `
  <ELFIMAGE-directory>
```

This check binds authoritative `mes.arc`, `EVENTB01.MES`, `13C.MES`, and
`LIBLARY.LIB`, plus the exact `13C:0x0F93..0x0FA3` command-`0x0F` envelope.
The envelope supplies the target and physical resume; original EXE audit v38
separately confirms callee coordinate zero and caller-coordinate restoration.
The replay permits only routine 28 at `0x00E6`, the exact paired command-`0x12`
records at `0x0105..0x011B`, routine 21 at `0x0269`, and routine 28 at
`0x0279` before reaching `MAHOKO.WAV`, B0796/B0797, and seven dialogue
boundaries. It then checks routines 28/32/25, the exact three-record omission
at `0x05F1`, routine 28, callee return `0x06A0`, the `13C.MES` date-routed BGM
prefix, and `MACHI.MES` handoff `0x1022`. It also tests `HHMM=0600`
(`B01X.MMO`), `1600` (`B01Y.MMO`), and the default missing `B01Z.MMO`
branch without substitution. Source archive hashes must remain unchanged.

Run the equivalent EVENTB02 callee route, including its bounded AN/AX
animation overlay, without opening a window:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventb02.gd -- `
  <ELFIMAGE-directory>
```

This binds `EVENTB02.MES`, its `13C:0x10CD..0x10DD` caller, shared library,
B02 X/Y background/AN-source/AX entries, expected Z-family absence,
`MAHOKO.WAV`, and `B0798.OGG`. It replays exact stops at `0x00E6`, `0x0105`,
`0x0269`, and `0x0279`, then eight exact dialogue boundaries. The confirmed
suffix crosses routines 28/32/25, one exact two-record omission, and routine 28
before callee return `0x08C9`. It then verifies the original `13C.MES`
date-routed BGM prefix `0x10DD..0x1151`, the isolated
`global_u8[286] = 1` suffix, and the `MACHI.MES` handoff at `0x115C`.
The native consumer after that handoff is not run.
All five source archive hashes are checked again after replay. The validator
also requires the 640x400 B02 background to remain visible while three X
frames occupy `(216,48,104,112)` or three Y frames occupy
`(216,56,128,112)`. It checks the exact AX dispatch order and 215-tool-tick
cycle. The 60 Hz scheduler is explicitly a tool clock; native host cadence is
still unresolved.

Run the bounded EVENTB14 caller-to-read-only-choice route without opening a window:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventb14.gd -- `
  <ELFIMAGE-directory>
```

This EVENTB14 check binds authoritative `mes.arc`, `EVENTB14.MES`, the
`44M.MES:0xC8F8..0xC925` caller picture/event sequence, the `13C.MES`
normal-conversation setup, original `B_PIC.MES`, the `44M_1/2/3.MMO` location
family, `B3.MMO`, compatibility `B.MMO`, `BAN.MMO`, `B.AX`, `MAHOKO.WAV`, and
B0829..B0832. Original EXE audit v38 separately confirms that
command `0x0F` enters the callee at coordinate zero and supports the stored
MMO/AX/BGM consumers. The replay reconstructs the Mahoko standing layer and
96x80 face animation at `(264,72)`, crosses seven exact dialogue boundaries,
and reaches three hash-bound DEF bodies at routine 40 `0x04CF`. The frame uses
the original 44M family selected by sandbox HHMM through the explicitly labeled
`TIME_C` location-family projection. Native location composition and animation cadence remain unresolved. The
one-based choice-result mapping is EXE-confirmed; native UI/cadence, the dynamic
second-stage list, and effects remain unresolved. Direct B_PIC replay also locks Mahoko
affection bands `0..30/31..70/71+` to B.AX columns `1/0/2`. The original-event
recommendation is the caller-qualified night context, represented by HHMM
`1900`, MMDD `1001`, affection `81`, and the exact caller flags. Original
B_PIC replay reaches `B3.MMO`, routine 22 at `0x04AF`, resumes at `0x04B4`,
and joins the high-affection face route. HHMM `0600` is retained only as a
playable compatibility/debug composition. The validator also projects each
explicit value `state_u16[21] = 1/2/3` in a cloned sandbox and requires all
6/17/12 stored dialogue boundaries, one displayed dialogue per boundary, and an
unchanged live sandbox. Values 1 and 3 must pass exact cloned routine-27/25/21
contracts, omit only the audited three-record command-`0x12` envelopes, and
return at `0x08FA` and `0x291E`. With Date set to a valid legacy MMDD, value 2
must preserve the START-derived relative calendar layout, return through
DEF17, DEF11/DEF12, and routines 3/26/32, then omit the exact `0x0C9E..0x0CAC`
and `0x0CE5..0x0CF0` native records and return through routines 28/21/28. It
must validate the exact `0x0B01/0x0B07` date-selected movement request, play
`IDOU.WAV` for the 1001 preset, keep the 44M/B3 caller frame during the two
in-transit dialogues, and label map/destination/choice input as locked. It
must display the original `B14.MMO` background plus the `B14AN.MMO`/`B14.AX`
120x128 four-frame overlay at `(400,8)`, switch to selector 44 / `FURARE.WAV`
at the exact `0x0E99` park-scene request, continue through 17 total branch
dialogues, then use one final continuation to display the exact three-row nested
choice at `0x133F`. Explicitly selecting a row projects `state_u16[21] = 1/2/3`
only in the cloned nested state and must replay the exact 8/6/13 stored dialogue
boundaries from `0x1344`. Both choice projections must be empty while their
selected dialogue branch is active, preventing input from mixing outcomes. The
one-based nested result mapping is EXE-confirmed, while its native UI,
cadence, dynamic second-stage records, and effects remain unresolved.
**Finish Nested Outcome** must cross the exact shared suffix to the
`B_PIC.MES` dispatch `0x1FC0`. **Run B_PIC Return** then executes the audited
expression route over the HHMM-selected `18M_1/2/3.MMO` children's-park
location background and exposes five final dialogues; the B14 event CG and
pre-move 44M frame must not reappear;
routine 21 lies between dialogue three and the final two messages. Those last
two messages must switch to the effective `MACHIN_1/2/3.DAT/.PAL` pair selected
by the source-confirmed MACHI HHMM thresholds (`MACHIN_3` for the 19:00 preset),
use event/preset 4 camera `(80,32)` plus CHARA actor `(95,40)`, label that the
exact native surface-1 producer remains unresolved, and identify the frame as
a presentation-only world-map monologue with map input locked.
**Finish EVENTB14** stops at the later `MACHI.MES` handoff `0x230C`. Invalid date `0000`
fails closed before that suffix. The validator also requires the common
caller-frame identity to remain active, hashes `44M.MES:0xC925..0xFFBA`, and
proves that a live caller return would next request BGM, register two DEF rows,
and stop at another routine-40 boundary. It does not select that caller-owned
choice. All five source ARC files are rehashed after
the run; the final handoff target is not executed and the frozen map is not
silently promoted to an interactive movement session.
Caller continuation is available only when the confirmed Start action created
and retained the common caller frame. Running the same callee return offset as
an isolated Analysis fragment never recreates or resumes its original caller.

Run the EVENTB03 direct-start and partial ordinary-playback check without
opening a window:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventb03.gd -- `
  <ELFIMAGE-directory>
```

This check binds the original `mes.arc`, `EVENTB03.MES`, `01M.MES`, and the
exact `01M.MES:0x788F..0x789F` command-`0x0E` envelope. It requires the Event
Player to expose a non-selectable **Deferred: direct start** evidence row, keep
**Start Event (Deferred)** disabled, and distinguish that state-unqualified
action from catalog Play using `captured-result3-original`. It
replays zero through routine 28 at `0x00FC/0x0101`, verifies the complete
three-record boundary `0x011B..0x0126`, and omits only complete command-`0x12`
record effects. Without generic native-stream skipping, a fresh all-zero
sandbox must reach routines `28/21/28`, 28 dialogue boundaries beginning at
`0x039F`, another routine 21 at `0x08DF`, and a three-definition routine-40
choice at `0x12D2`. The obsolete `0x01C5` return is explicitly excluded as a
skip-policy artifact. Runtime-trace schema v3 plus the source-bound terminal
audit separately supply all seven target identity, load/install, execution
ownership, and root-replacement terminal obligations.
The validator also exposes the terminal-audit-v3 contract: all seven host
obligations are complete, the captured result `3` is source-bound from
`LIBLARY.LIB:0x1C95` to the `EVENTB03.MES:0x3D46` `MACHI.MES` handoff, and the
common return is `0x3D5D`. It rejects changed target/library hashes and overlay-
shadowed target documents, rehashes `mes.arc` afterward, and never modifies the
source archive. It then builds the ordinary root-replacement request from the
loaded catalog, reaches all three original labels, rejects results 1/2 before
mutation, and drives result 3 through registered DEF 22/21, seven exact
metadata-only native-stream omissions, `B1.MMO` plus `BAN.MMO`/`B.AX` column 1,
and the callee-owned `MACHI.MES` terminal. It also requires exact B03/B03A and
B05SS AN/AX composition without exposing their source atlases, both bounded
EVENTB03 effect cues on the independent effect channel, the labeled oversized-
CG pan projection, and the source-qualified preset-0 night MACHI station frame.

Run the complete bounded EVENTB15 callee/caller route without opening a window:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventb15.gd -- `
  <ELFIMAGE-directory>
```

This binds `EVENTB15.MES`, its `11M.MES:0x347B..0x348B` original caller,
`LIBLARY.LIB`, B15 X/Y MMO fingerprints, expected B15Z absence, and
`MAHOKO.WAV`. It replays routine 28 at `0x00F6`, the exact paired
command-`0x12` omission at `0x0115`, routine 21 at `0x02E0`, routine 28 at
`0x02F0`, first dialogue `0x035D`, all nine dialogue boundaries, routines
28/32/25, the exact three-list omission at `0x0721`, routine 28, and return
`0x0778`. The restored `11M.MES` suffix then writes
`banked_u16[0][242] = 11` and `global_u8[286] = 1` before stopping at
`MACHI.MES:0x34AE`. `HHMM=0600` requires B15X,
`1600` requires B15Y, and the night branch retains the missing-B15Z
diagnostic. No voice marker is expected anywhere in this route, no caller BGM
is fabricated, and the native MACHI consumer remains fail-closed. All source
archive hashes are checked again after replay.

Run the bounded EVENTD01 pre-choice path through the actual Event Player UI
controller without opening a window or taking foreground input:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventd01.gd -- `
  <ELFIMAGE-directory>
```

This source-bound check requires the authoritative `mes.arc`, `EVENTD01.MES`,
`12C.MES`, and `LIBLARY.LIB` hashes and the exact
`12C.MES:0x07CD..0x07DD` dispatch envelope. It verifies that command `0x0F`
names the callee and physical resume, while the configured-original executable
audit confirms entry at coordinate zero and restoration of the caller
coordinate. The replay starts through the exact `0x0000..0x0008` bootstrap,
continues routine 28 at `0x00E6`, and omits only the two complete
command-`0x12` lists at `0x0105..0x011B`. Its explicit `HHMM=0600` replay then
requires the `D01X.MMO` marker at `0x01CF` and the independent state write.
It also verifies the exact stored mode-0 surface envelope, while asserting
that routine 28 normalizes `global_u8[4000]` to zero and the branch at
`0x0234` bypasses that envelope on the replayed route. It then requires
routines 21/28, the `D01XAN.MMO` and `D01X.AX` foreground records, the
selector-33/routine-23 `MAKI.WAV` request, and first dialogue boundary
`0x043E`. It treats the decoded 120x168 foreground as a tool
preview because native AX placement/composition remains unresolved. The fresh
night route must instead expose the missing `D01Z` resource diagnostic; it may
not substitute the daytime frame.

The same check continues through six common dialogue boundaries, three voice
targets, and the three exact DEF body coordinates at `0x07AB`. It then selects
all three options through the Event Player keyboard controller, requires 7/9/7
additional dialogue boundaries, validates each route's voice order, and reaches
the common `0x1114` return and explicit completion screen with
`global_u8[749] = 1`. From the final route it also drives the explicit
`12C.MES:0x07DD..0x0851` caller BGM preview, requires the default-date
`IDOU.WAV` request without a state change, then executes the exact
`0x0851..0x0877` sandbox suffix. The suffix must write only
`global_u8[286] = 1` and `banked_u16[0][242] = 12`, and stop at the
`MACHI.MES` handoff marker `0x086A` without invoking its host consumer.
It also checks the time-routed frame references: available `D01X.MMO` and
`D01Y.MMO` decode as 640x400, while absent `D01Z.MMO` remains an explained
diagnostic rather than a substituted image. The start contract binds the X/Y
MMO, foreground-MMO, and AX base-entry fingerprints and confirms that the
three Z-family entries remain absent. The `HHMM=1600` replay checks the
original 640x400 `D01Y.MMO`, 112x192 `D01YAN.MMO`, and `D01Y.AX` sequence.
A day-to-night restart must clear the
previous frame, foreground, AX, and BGM before the new route reaches any media
marker. `mes.arc`, `mmo.arc`, `data.arc`,
`bgm.arc`, and `voice.arc` hashes must remain unchanged. Choice writes remain
isolated to the tool sandbox. The check does not run native record/pixel/AX
effects or routine-40 input loops, play audible headless audio, or modify a
gameplay save. The source guard is not evidence that the bypassed surface
envelope executed. Configured-original executable audit v38 independently checks
the command-`0x0F` zero-coordinate save/call/restore contract, command-`0x12`
consumption, mode-0 surface adapter, and AX consumer boundary.

Run the hash-bound complete bounded EVENTD02 route through the Event Player
controller:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventd02.gd -- `
  <ELFIMAGE-directory>
```

This source-bound check requires authoritative `mes.arc`, `EVENTD02.MES`,
`12C.MES`, and `LIBLARY.LIB` hashes plus the exact
`12C.MES:0x098D..0x099D` dispatch envelope. It verifies that command `0x0F`
names the callee and physical resume and carries no coordinate operand;
configured-original executable audit v38 separately confirms entry at callee
coordinate zero and restoration of the saved caller coordinate. The replay
starts through the exact `0x0000..0x0008` bootstrap, continues routine 28 at
`0x00E6`, and omits only the paired complete command-`0x12` record lists at
`0x0105..0x011B`. Its `HHMM=0600` path requires the `D01X.MMO` marker and
independent state write, then proves that normalized `global_u8[4000] = 0`
bypasses stored surface envelope `0x023F..0x0264`. It proceeds through routines
21/28, the `D01XAN.MMO`/`D01X.AX` records, selector-33/routine-23
`MAKI.WAV` request, and first dialogue `0x0456`. The X and Y base MMO,
foreground-MMO, and AX fingerprints are bound to original `mmo.arc` and
`data.arc`; fresh `HHMM=0000` must instead report the expected absence of all
three D01Z-family entries without substituting daytime media. Native AX
placement/composition remains unresolved. The full-session source guard also
binds later `D02X.MMO` SHA-256
`b9852c0b70dc0cb3cd2004367659117d17d76ab3f5fdbc68d551418345ce4039`
and `D02Y.MMO` SHA-256
`173682b430708ad41e4de4fa5efd9fd60a594a266ce0b605d4e6c0c5c103be74`
while requiring `D02Z.MMO` absent; those resources belong to the later surface
paths, not the coordinate-zero D01 time-band prefix. Failed validation leaves
the prior frame and audio state intact, and no shifted stop or generic execution
fallback is accepted.

The same check requires 40 dialogue boundaries and ordered `D0957.OGG` through
`D0976.OGG` markers. On default `HHMM=0000` it explicitly composes shared
routines 27 and 25, audited registered DEF26, and the first later routine 21,
then requires the bounded command-`0x0D` pause at `EVENTD02.MES:0x0BAD`. The
following `0x0C` is native-stream payload rather than a MES branch. The UI must
first say **EVENT NOT COMPLETE**, then expose only the exact effect-omitting
resume at `0x0BB4`. The validator continues through four later routine-28
boundaries and routine-21 calls at `0x0CC5` and `0x1356`. Their preceding exact
mode-0 surface envelopes `0x0C9B..0x0CC0` and `0x132C..0x1351` are separate
from the bypassed prefix surface and are reported as metadata-only operations.
It then requires completion flag `global_u8[750] = 1`, the `0x18C6` return,
final-dialogue footer, and explicit completion screen naming physical caller
resume `12C.MES:0x099D`. It drives the default-date `IDOU.WAV` caller prefix
through `0x0A11` without a state change, applies exactly
`global_u8[286] = 1` and `banked_u16[0][242] = 12`, and stops at
`MACHI.MES:0x0A2A` without executing the host consumer. A second `HHMM=0600`
replay requires the reached later post-event `D01XAN.MMO` record and completes
without entering the default-route DEF26 branch. `mes.arc`, `mmo.arc`,
`data.arc`, `bgm.arc`, and `voice.arc` hashes must remain unchanged; native
records, AX placement, and pixels remain unexecuted.

EVENTD01, EVENTD02, and EVENTD03 caller checks all use the shared
`kakyu_mes_caller_route/v1` Content Core contract. A synthetic scene locks its
dispatch-envelope, BGM-route, segment-hash, isolated-write, trace-command, and
handoff-target rejection rules before any original-content integration check
runs.

Run the focused inner EVENTD03 BGM/dialogue audit against user-owned archives
with (the validator also opens sibling `voice.arc`):

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/content_suite/cli/validate_mes_bgm_route.gd -- <mes.arc> <bgm.arc>
```

This lower-level audit begins directly at `EVENTD03.MES:0x22E`; it is retained
as a focused regression rather than the Event Player's current one-click intro.
It verifies the exact selector-33 assignment, adjacent
routine-23 transfer, resolved `MAKI.WAV` entry, all 12 dialogue continuations,
message-record IDs `47181..47192`, four resolved and bounded-valid Ogg Vorbis
voice entries, sandbox completion flag `global_u8[751]`, and command-`0x00`
return at `0x7ff`. It also checks the earlier `D03.MMO` marker at
`0x1a4` and strictly decodes that sibling `mmo.arc` entry as 640x400. It does
not play audio, execute the coordinate-zero prefix, infer native presentation
effects, or modify any archive.

Run the same route through the actual Event Player UI controller without
opening a window or taking foreground input:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventd03.gd -- `
  <ELFIMAGE-directory>
```

This integration check opens the user-owned content set through the shared
resolver and requires `EVENTD03.MES` SHA-256
`3c189313411fdbe151819fae44b809e1395ee08a76d5325f1b5f4f92e3d9e6fb`.
It starts at coordinate `0x0000`, validates the exact eight-byte bootstrap and
entry-zero target `0x0008`, continues routine 28 at `0x00E6/0x00EB`, and
permits omission only for the adjacent three-record command-`0x12` lists at
`0x0105..0x011B`. It then requires the naturally reached `D03.MMO` marker,
independent `banked_u16[0][1] = 7` write, decoded-but-unexecuted surface
operation, `global_u8[4000] == 0` default branch, routines 21/28, selector 33,
routine 23, resolved `MAKI.WAV`, and the three-row first dialogue at
`0x0284/0x0288`. It binds the original `D03.MMO` base entry SHA-256, rejects a
shifted pre-dialogue shared-routine tuple, and separately seeds
`global_u8[4000] = 1` to prove initial routine 28 normalizes the default branch
back to zero. The check advances all 12 dialogue boundaries, observes the
four voice previews in order, and requires the sandbox completion flag and
callee return. It also verifies the final `EVENT COMPLETE` footer, explicit
completion screen, unchanged completion-screen sandbox state, and the exact
`12C.MES:0x0DDE` dispatch envelope ending at caller resume `0x0DEE`. It then
checks the exact 116-byte caller BGM prefix through `0x0E62` for date-selected
routes `1224 -> 26 / X_MAS.WAV`, `1301 -> 42 / SHOGATU.WAV`, and default
`-> 1 / IDOU.WAV`, and drives the completion screen into the default BGM
preview. A second exact continuation executes the hash-bound 38-byte suffix,
requires `global_u8[286] = 1` and `banked_u16[0][242] = 12`, and stops at the
`MACHI.MES` handoff marker at `0x0E7B` without executing its host consumer.
The start contract checks the bootstrap, caller, two-list, MMO, write, and
surface slice hashes documented in the MES character-event specification. Any
hash, coordinate, record count/terminator, marker, default branch, request, or
media mismatch fails closed. SHA-256 checks require `mes.arc`, `mmo.arc`,
`bgm.arc`, and `voice.arc` to remain unchanged. Headless audio payload
validation is not an audible playback claim, and decoded MMO/surface metadata
is not a claim that native pixels or placement ran.

Validate the conservative equal-length MES text patcher against an
authoritative archive entry without creating any output:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_equal_length_patch.gd -- `
  <mes.arc> [entry.MES]
```

The default entry is `EVENTD03.MES`. The validator decodes every strict-indexed
CP932 message it reaches, requires a no-op patch batch to be byte-identical,
then makes one same-byte-count change in memory and requires structural reopen
validation while the source archive hash remains unchanged. It prints no
dialogue and does not establish original-engine compatibility.

Drive the same read/edit preparation path through the actual MES Editor UI
controller without opening a window or creating an output file:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_mes_editor_original.gd -- `
  <mes.arc> [entry.MES]
```

The default entry is `EVENTD03.MES`. This check requires the Messages table and
edit field to show decoded CP932, verifies live unequal/equal byte-count
feedback, stages one replacement, and prepares the complete validated binary
batch in memory. It records only an entry name, offset, and byte count in its
result; original dialogue and archive data are not copied into the repository.

Validate the bounded, read-only EVENTD08 DEF option route without selecting an
option or opening a window:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_def_route.gd -- `
  <mes.arc>
```

This hash-bound check starts at `EVENTD08.MES:0x0687`, requires the three exact
literal DEF records and their aligned skip targets, and stops at literal shared
routine `40` at `0x0735`. It verifies that the option bodies remain lossless,
the sandbox state diff is empty, no synthetic resume is exposed, and the source
archive hash is unchanged. It prints no option or dialogue text.

Drive the complete original EVENTD08 route through the actual Event Player UI
controller without opening a window:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventd08.gd -- `
  <ELFIMAGE-directory>
```

This integration check verifies the hash-bound
`12C.MES:0x0FA6..0x0FB6` command-`0x0F` dispatch, starts EVENTD08 at coordinate
zero, and requires `kakyu_event_player_caller_frame/v1` to retain that caller,
physical resume, callee identity, and temporary argument/evaluator context
before the isolated session begins. It advances the exact common prefix: nine dialogue boundaries, 17 raw
message fragments, voice markers `D1028.OGG..D1032.OGG`, routines 28/21/28,
and the two adjacent command-`0x12` record lists at `0x03BC..0x03D2`. The
record continuation grants only `native_record_policy=omit_bounded`; it then
requires the naturally reached two-NUL `D08.MMO` marker at
`0x045B..0x0467`, inherited `MAKI.WAV`, and three decoded DEF rows in Results.
It selects all three choices through the actual Event Player controller,
follows the bounded shared-library and explicit DEF26 continuations, returns
through the common frame and source-bound D_PIC restoration adapter into the
confirmed `12C.MES` caller, advances its 8/6/14 dialogue boundaries,
checks the completion write, and reaches the exact `MACHI.MES` command-`0x0E`
handoff at `0x1A18` without executing its unresolved host consumer.
At the caller transition it also verifies all four `TIME_C` HHMM projection
cases, separate background/foreground textures, the shared chroma-key material,
and the authoritative `D.MMO` 640x400 green field (186,408 exact-green pixels
and four green corners). Before running EVENTD08 it loads the authoritative
`D_PIC.MES` and checks all six confirmed standing resources render in the keyed
foreground with no stale background and an explicit unresolved-caller label.
For each EVENTD08 choice, the validator also advances to the last caller-owned
dialogue, requires the immediate `EVENT COMPLETE` footer, opens the explicit
completion screen, returns to the final dialogue with Left, and verifies that
these UI actions produce no sandbox state diff.
Source `mes.arc`, `mmo.arc`, `bgm.arc`, and `voice.arc` hashes must remain
unchanged throughout.

## Output Paths

Where the tools above write. `analysis/` is Git-ignored, so these are absent
from a fresh checkout and are reproduced by re-running the tool, not fetched.

- `analysis/event_tables`
- `analysis/remake_data/machi_movements.json`
- `analysis/remake_data/machi_movements.csv`
- `analysis/remake_data/machi_movement_preview.html`
- `analysis/map_source_audit_v2.json`
- `analysis/manual_map_picks/MACHI_SMP1_picks.csv`
- [Original Map Movement Sources](../mes/map_movement_sources.md) — tracked, and
  the document that reads the audit above

`inspect_map_sources.py --runtime-dir data/maps/original` also writes the
`kakyu_original_map_collision/v1` files consumed by Godot. These projections
remain local with the rest of `data/` and are reproducible from `data.arc`.
`--machi-world assets/original/maps/MACHI_NATIVE_NIGHT.png` additionally
rebuilds the source-aligned MACHI movement texture; `--machi-atlas` selects the
DAT/PAL stem and defaults to the 18:00-and-later `MACHIN_3`. PAL channels are
decoded as BGR. `--protagonist-sprite
assets/original/map_actors/CHARA.png` extracts the original twelve-frame map
actor strip with palette-index-zero transparency.

## Future Tools

- data validator for event/map/date JSON
- Godot import helper for map path/destination data
- screenshot-based UI regression checks
- debug overlay for map nodes, entrance regions, event IDs, and active conditions

## Content Suite Shells

Run the current Content Suite Launcher or any independent ARC Browser, Audio ARC
Editor, MES Editor, Event Player, and Image ARC Editor shell from the project
root with Godot 4.7:

```powershell
Godot_v4.7-stable_win64.exe --path . res://tools/content_suite/apps/content_suite_launcher.tscn
Godot_v4.7-stable_win64.exe --path . res://tools/content_suite/apps/arc_browser.tscn
Godot_v4.7-stable_win64.exe --path . res://tools/content_suite/apps/audio_arc_editor.tscn
Godot_v4.7-stable_win64.exe --path . res://tools/content_suite/apps/mes_editor.tscn
Godot_v4.7-stable_win64.exe --path . res://tools/content_suite/apps/event_player.tscn
Godot_v4.7-stable_win64.exe --path . res://tools/content_suite/apps/image_arc_editor.tscn
```

The launcher can pass one optional existing `.arc` path to a selected app, or
an ELFIMAGE directory containing `mes.arc` to Event Player, and starts it in a
separate Godot process. Leaving the path empty lets the app use its own Open
dialog. It does not load an archive or duplicate any Content Core format logic.

Validate and index a complete user-owned ELFIMAGE content set without reading
entry payloads:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_content_set.gd -- `
  <ELFIMAGE-directory>
```

The validator requires `mes.arc`, reports missing optional archives, rejects
any present malformed archive, and closes every read-only reader before exit.

ARC Browser shows the immutable stored offset plus the effective byte count and
source for every entry. **Load overlay**, **Hot Reload**, and **Clear overlay**
switch its read layer without changing the ARC. **Extract selected** resolves
`overlay -> original ARC`, refuses an existing destination, and streams through
the shared Content Core extraction API. The extractor publishes a sibling
temporary file only after closing, reopening, and SHA-256-verifying it, and
removes the temporary file on failure. **Export overlay ARC...** streams every
target from the active manifest snapshot through the source- and payload-bound
ArcWriter through the shared provenance publisher, publishes only a new
reopen-verified ARC plus its `.kakyu-provenance.json` sidecar, and keeps the
source read-only. The same sidecar is emitted by MES, Image, and Audio ARC
exports. Another app can verify the selected original and every changed or
unchanged entry before accepting the result as original-derived; a missing or
invalid proof remains unknown raw input. It is a format-neutral package/index
inspector and materializer; it
does not decode payloads. The entry-name field filters
without case sensitivity, while status reports `visible / total` index rows.
The filter survives overlay load, Hot Reload, and clear. Rebuilding the table
restores its selection only when that entry remains visible; otherwise the
selection is cleared and extraction fails closed instead of acting on a hidden
row. The browser binds table metadata and extraction to one validated resolver
manifest snapshot; a changed or invalid overlay leaves the previous read layer
active instead of mixing two manifest revisions.

All shared overlay save/detach operations also carry the SHA-256 revision of
the exact manifest bytes they loaded. Immediately before the atomic rename,
the publisher rejects a manifest that appeared, disappeared, or changed and
preserves that newer revision; it then reopens and checks its own published SHA
before reporting success. A rejected save can leave only an unreferenced
content-addressed payload. This optimistic guard avoids ordinary lost updates
between independent tools, but it is not a stale-lock recovery mechanism and
does not claim to eliminate the final filesystem check-to-rename race.

Content-addressed replacement and MES-projection files also refuse to overwrite
an already published path. A competing file is reused only when its SHA-256 is
the expected content hash; a different file is left untouched and the save is
rejected. Newly published blobs are reopened and rehashed before the manifest
may point at them.

Append `-- <archive-path>` to open a user-owned archive at startup. All shells
open sources read-only. Extraction requires a new output path and refuses an
existing file. Resolved extraction uses bounded chunks, a sibling temporary
file, and reopen-verified atomic publication; a changed overlay or fallback
source fails without leaving a final or temporary output. The Audio ARC Editor
collects any number of validated OGG/WAV replacement paths in one session.
Saving rechecks that each staged file still has its recorded hash and remains
valid for its bound ARC entry, then publishes one overlay-manifest update or
one verified new ARC rebuild plus portable provenance sidecar for the full
batch.
Header validation is bounded to 64 KiB; fingerprinting and both output paths
stream file-backed replacements in bounded chunks. Pending and save-time audio
bytes are never accumulated as one batch. The editor never writes
into the opened archive, never overwrites an existing output, and does not
re-encode already valid input. New-ARC export is bound to the SHA-256 captured
when the source ARC was opened. A same-size external source change aborts before
publication and preserves the pending replacement session.
Each pending audio path and its staged SHA-256 are handed to the bound-file
writer together, closing the interval between session revalidation and streaming.

The Audio ARC Editor also supports **Load overlay**, **Hot Reload overlay**, and
**Clear overlay**. The entry tree marks effective `Overlay` and `Pending`
sources. Detail validation, Preview, and Extract selected use `Pending ->
Overlay -> original ARC`; extraction always requires a new destination and
streams file-backed pending/overlay content in bounded chunks. The 64 KiB
detail-header bound is unchanged. Loading, reloading, or clearing an overlay is
blocked while pending replacements exist. Saving an overlay attaches that
package as the active read layer without clearing the authored session. Load
and Hot Reload build a separate resolver. Content Core fingerprints the open
ARC once and batch-binds every matching record, including non-audio records, to
its base and original-entry hashes. Audio labels are derived from the OGG/WAV
subset of those manifest-ordered records. The candidate replaces the active read
layer only after all checks pass; a wrong-base or otherwise invalid reload
retains the previous resolver, labels, details, and preview stream.
Its fingerprint must still match the one captured when the displayed ARC index
was opened, so an externally replaced source path is rejected as a reload.

Content Core `0.189.0` also provides the versioned audio timeline summary used
by Audio Editor's explicit **Analyze timeline** action. Exact PCM WAV duration comes from
validated whole frames. Its min/max/RMS waveform is a deterministic bounded
sample with at most 256 buckets and 262,144 inspected frames. Ogg Vorbis
duration comes from the final granule of one logical stream; compressed Vorbis
bytes do not produce a false waveform. The existing 64 KiB selection-time
header validation remains unchanged. Analysis reads one bounded original-ARC
range per WAV bucket or at most a 128 KiB Ogg tail; file-backed pending and
overlay layers are fingerprinted before and after their range reads. Full
payload loading remains confined to the separately requested Preview action.

Use **Load MES references...** to choose a read-only original or verified
materialized `mes.arc`. The editor fingerprints it before and after the scan,
parses every `.MES`/`.LIB` entry, and activates no partial index if a container
cannot be read or parsed. The interactive scan processes 16 source entries per
frame and reports progress instead of monopolizing the UI. Selecting an audio
entry then shows only confirmed static references: bounded subcommand-7 Ogg
voice markers, or an immediately adjacent literal slot-1 selector assignment
and literal shared-routine-23 BGM call. Results include the MES filename,
code-relative offset, boundary class, and BGM selector/call offset. A zero
result means the loaded index contains no confirmed reference for that entry;
it does not prove the audio is unreachable through an unresolved native host.

Content Core `0.191.0` defines deterministic target profiles without changing
the existing replacement action. SE WAV uses PCM16 mono at 22.05 kHz; BGM WAV
uses PCM16 stereo at 44.1 kHz; voice-bank Ogg accepts only already-matching
mono 44.1 kHz Vorbis and preserves it byte-identically. Already matching WAV
also remains byte-identical. Explicit PCM conversion uses fixed integer channel
mixing/duplication and linear resampling, validates the canonical output, and
reports separate input/output fingerprints. BGM and voice outputs remain
`original_engine_unverified`; only the controlled SE PCM profile has the
documented compatible replacement-playback evidence.

For a selected WAV target, use **Convert WAV to target...**, choose a PCM WAV
source, then choose a new `.wav` output. The source is fingerprinted before the
second chooser and checked again before conversion. Publication uses a sibling
temporary file, reopen size/SHA verification, destination-absence recheck, and
atomic rename. The verified output is then staged by path and hash with its
preset audit; no converted payload remains resident in the idle session. This
button is disabled for preserve-only Ogg targets. Continue to use **Add/update
replacement...** when the input is already a valid target-format file and no
conversion was requested.

When Event Player presents an edited MMO, AX, BGM, or voice entry, its analysis
header shows a Content Identity label for the effective payload. That label is
derived from the live resolver descriptor, effective bytes, selected original
entry fingerprints, and a versioned format-interface check. It does not alter
the separate MES route evidence. Materialized-ARC lineage uses the same core
contract, while selecting a derived content set through the ordinary playback
workflow remains tracked under P2-10.

The game runtime now owns the same resolution order through the autoloaded
ContentService. AudioService and legacy presentation callers ask it for MMO,
DAT/PAL, WAV, or Ogg content before using imported `res://` assets. Source and
overlay changes are candidate transactions, so a failed switch retains the
last valid runtime generation. Until the P1-07 Launcher handoff supplies a
selected content set, the service stays unconfigured and existing tiered
assets remain the final runnable fallback.

The Image ARC Editor imports a PNG for a selected MMO or paired DAT/PAL target
with exactly matching dimensions. MMO preserves the target's opaque header;
DAT/PAL applies deterministic quantization and strict alpha validation. Both
paths encode and immediately decode the candidate, then stage verified payloads
in `user://content/image_editor_sessions/`. One DAT/PAL logical item owns both
cache files. Removing it or closing the editor clears both. Overlay and new-ARC
save controls stream all cache-bound payload paths through the shared writers.
Same-dimension MMO replacements with the exact target header are recorded as
`original_engine_compatible`; generated headers remain `remake_only`. New ARC
output refuses source overwrite and an existing output, then reopens and
verifies the finished copy. It also requires the source ARC to retain the
open-time SHA-256; an external same-size change rejects the export without
discarding the pending image session.
The same bound-file contract carries each staged MMO/DAT/PAL/A6 cache SHA into
writer streaming, so a same-size cache mutation is rejected as well.

Content Core `0.185.0` exposes DAT/PAL palette and import-loss measurements as
`kakyu_ai5_dat_pal_diagnostics/v1`. The selected pair reports used/unused
indices and index-zero pixels; 640x32 strips explicitly label index zero as the
reserved transparent index. PNG encoding reports source/palette colors,
opaque/transparent pixels, changed colors/pixels, RGB mean absolute and RMS
error, and maximum channel error. Transparent hidden RGB is excluded. Exact
imports retain that record with the paired pending session. Lossy imports
remain outside that session while a modal panel compares the imported PNG and
the deterministic decoded DAT/PAL result. **Reject** deletes its two transient
cache files. **Accept and stage DAT/PAL** rechecks the selected target, the
open-time ARC fingerprint, both cache hashes and sizes, and the reopened pixels
before transferring the exact reviewed files into one remake-only pending
item. A changed candidate is discarded without replacing an earlier pending
item. This is authoring diagnostics, not an original-engine compatibility
result.

Content Core `0.186.0` also exposes every effective palette entry through
`kakyu_ai5_dat_pal_palette/v1`. Select a decoded DAT/PAL row, choose one of its
256 entries, and use **Stage palette color** to publish a finite opaque RGB
change into the normal paired pending session. The panel reports each entry's
RGB value and pixel reference count. Entry zero is visibly reserved and the
stage action is disabled for 640x32 alpha strips; opaque layouts may use entry
zero normally. The codec writes a detached three-byte BGR mutation, and the
editor reopens the DAT/PAL pair before it replaces any previous pending pair.
Save/remove behavior is therefore identical to a paired PNG import, while the
source ARC and loaded overlay are never modified.

Content Core `0.187.0` advances A6 inspection to
`kakyu_ai5_a6_input_regions/v4`. It measures how much of each inclusive region
remains reachable after all earlier first-match records, distinguishes partial
occlusion from a fully unreachable row, and counts every earlier overlap. Its
insert, duplicate, remove, and move helpers encode and reopen the complete
ordered table and reject invalid indices. The configured original corpus locks
12 byte-identical tables, 153 records, 21 overlap pairs, 19 partial rows, and
zero fully unreachable rows. These core operations are not yet exposed as
Image Editor buttons; the existing field editor remains the only GUI writer in
this unit.

Use **Load Overlay** to attach an existing package whose base ARC and original
entry hashes match the open archive. **Hot Reload Overlay** revalidates that
same directory after another tool changes it, while **Clear Overlay** restores
the original ARC read layer. The tree labels resolved entries as `Overlay` and
new unsaved edits as `Pending`; preview and editing resolve `Pending -> Overlay
-> original ARC`. MMO, A6, and AX use that source directly. DAT and PAL resolve
independently before they are decoded as one logical image. Load and Hot Reload
build a separate resolver registered to the current read-only ARC, configure
the package once, and use the shared one-fingerprint archive-binding result for
both target labels and later reads. Every snapshot record for the open ARC,
including non-image entries, must still name
an existing entry and match the current base-ARC and original-entry hashes.
The binding fingerprint must also match the fingerprint captured with the
displayed index.
The candidate becomes the active resolver, overlay root, labels, details, and
preview only after the whole set passes. A malformed, changed, wrong-base,
missing-entry, or resolver-mismatched candidate is closed and the previous
read layer and visible preview remain active. This transaction does not impose
an all-or-nothing rule on a loaded DAT/PAL pair: DAT-only and PAL-only overlay
records remain valid and the other half resolves through the normal priority
order. An authored pending DAT/PAL edit still owns and publishes both entries
as one session item. Loading, reloading, or clearing an overlay is blocked
while a pending session exists, because its templates may depend on the loaded
bytes. Saving the pending session attaches the newly published package through
the same candidate transaction; the original ARC is never opened for writing.
The image/layout name filter never retains a hidden edit target. If the current
row no longer matches, the editor clears its pixel/A6/AX preview, disables PNG
Import/Export and Remove pending, and requires an explicit visible-row
selection after the filter is cleared. Already staged session payloads remain
intact and can be selected again normally.

Content Core `0.166.0` also provides the headless
`kakyu_logical_surface_compositor/v1` foundation shared by Event Player
and Image Editor presentation. It owns detached RGB8 surfaces, a fixed 640x400
logical surface 0, explicit roles and active-surface selection, inclusive
rectangle expansion, and the confirmed opaque-copy, RGB-key-copy, and
active-surface-fill operations. It rejects an invalid source or destination
rectangle before changing pixels. Surface-8 assembly and lifetime and native
AX cadence remain unresolved rather than being inferred.

Content Core `0.167.0` can also consume the exact non-executing surface row
emitted by the MES runner. The adapter rechecks subcommand, mode, helper,
inclusive-endpoint semantics, argument count, and sandbox isolation before
mapping it to the compositor. RGB key and fill color remain mandatory explicit
presentation-context inputs. This is a headless integration seam, not an
enablement of native pixel effects in Event Player.

Content Core `0.192.0` separates the EXE-confirmed six-record mode-13 host
action from generic unresolved surface dispatches. Instruction schema v41
publishes it as `surface_display_refresh`; event trace v66 and library trace v9
publish only a non-executing `surface_display_refresh_omitted` record with the
evaluated arguments and inclusive-expanded rectangle. Registered-definition,
detached-definition, and script-call trace wrappers are versioned with that new
row. The empty `10M.MES` form and any other noncanonical shape continue to fail
closed as `surface_dispatch_unresolved`. Event Player and MES Editor may show
the confirmed refresh evidence, but neither app supplies unresolved backing
content, surface lifetime, or composition order.

Content Core `0.168.0` assigns successful pixel operations a deterministic
sequence and exposes a detached `kakyu_logical_surface_checkpoint/v1`. Each
surface payload and the complete role/active/sequence state are SHA-bound;
restore validates the entire candidate before replacing the live compositor.
This enables later nested-caller frame restoration without sharing mutable
Image objects. The current Event Player still does not attach checkpoints to
its MES caller frames.

Content Core `0.169.0` can apply an explicit list of compositor operations as
one ordered transaction. Later stored operations win at overlapping pixels.
If any step fails validation, the internal checkpoint restores the complete
pre-batch frame and sequence and reports that step's index. The API guarantees
order and rollback only; it does not infer a resource producer or native tick.

Content Core `0.170.0` lets the shared Game Preview used by Event Player and
Image Editor present compositor surface 0 through
`kakyu_tool_game_preview_compositor_binding/v1`. Presentation is a detached
640x400 snapshot labeled with role and operation sequence. It removes a stale
separate foreground, requires explicit refresh after later operations, and
preserves the last valid frame when a binding fails. Producer migration is
explicit and source-bound.

From Content Core `0.171.0`, Image Editor's decoded-image **Game Frame** uses
that binding. **Asset View** remains the original decoded image, while the Game
Frame is a detached black 640x400 composition with the requested X/Y placement.
Images are clipped at all logical edges, including negative coordinates; a
fully offscreen placement is an empty valid frame. This does not change encoded
payloads or stage/save behavior. A6 and AX structural overlays remain separate
metadata layers.

From Content Core `0.172.0`, the source-bound EVENTB02 and EVENTB14 validators
also drive this binding. A 640x400 MMO supplies the static checkpoint; each
confirmed AX frame restores it and RGB-key copies one rectangle from the AN
atlas at the audited B02/B14 destination. The validator checks the complete
rectangle pixel-for-pixel, including restoration under exact green pixels, so
the vertical atlas and preceding animation frame cannot remain visible. The
display cadence is still the labeled 60 Hz tool clock, not a claim about the
native timer. D01/D02 AN presentation remains a separate unresolved preview
until its AX placement is proven.

Content Core `0.178.0` separates that labeled preview clock from both apps as
`kakyu_ax_tool_scheduler/v1`. The scheduler consumes a validated AX tool
timeline, retains sub-tick time, stops terminal streams, advances exact dispatch
order across reset-requested cycle wrap, and caps catch-up work without
discarding the remaining backlog. It owns no textures or compositor state.
Event Player uses this clock for both of its source-bound EVENTB02 and EVENTB14
AN/AX projections; its event-specific code owns only source crops, compositor
checkpoints, and presentation labels. Image Editor uses the same clock for the
selected AX cell. **Play/Pause** advances or retains the current dispatch,
**Restart** returns to tick zero and the labeled structural overview, and
terminal versus resetting streams follow the compiled timeline. Because AX has
no pixels, the editor animates only the current confirmed destination outline;
its detached selection has no MES-bound surface-8 producer pixels and native
cadence remains unresolved. This completes
the shared-scheduler scope of P3-03 without claiming native timing.

Content Core `0.179.0` also shares cell-to-frame interpretation as
`kakyu_ax_playback_plan/v1`. Image Editor no longer feeds global shared-record
indices directly to its clock: the plan preserves those source indices for
inspection while assigning stable local frame indices for playback. Event
Player uses the same plan for EVENTB02 and EVENTB14 source crops and 640x400
destinations. A plan requires an explicit detached source size and fails closed
on an out-of-bounds crop, destination, or unsupported consumer. This is a P3-02
increment only; it does not identify the native surface-8 producer or timer.

Content Core `0.180.0` advances the plan to
`kakyu_ax_playback_plan/v2` and adds `kakyu_ax_surface_binding/v1`.
Executable audit v69 maps active-surface state `+0x20BA` to
`banked_u16[0][1]`; MES instruction v40 and event trace v65 preserve that
storage identity and its value at each confirmed MMO marker. The exact
EVENTB02 and EVENTB14 routes select value 8 before loading their AN MMO, so
Event Player now passes a validated surface-8 producer binding into the common
plan. Image Editor's standalone AX selection remains detached because no MES
route has been selected, and native cadence remains unresolved.

Content Core `0.182.0` also supplies
`kakyu_mes_active_surface_ax_audit/v1` for headless corpus work. It recognizes
only the exact ordered structural chain `surface 8 -> AN MMO -> restore 7 ->
AX`, preserves every coordinate and resource name, and labels reachability as
unproven. The configured-original audit locks 1,352 such chains across 398
scripts and keeps EVENTB02's intervening time branch outside this canonical
class. This projection is evidence for later route qualification, not a
standalone playback preset.

Content Core `0.183.0` performs that qualification with
`kakyu_mes_ax_runtime_chain/v1`. Event Player begins a pending chain from the
exact audited MMO marker plus the live surface-8 state, then finalizes it only
after the exact AX marker and binding cell occur in the runtime trace.
EVENTB14 option 2 uses this common contract before animation activation;
EVENTB02 remains on its audited branch-family path. The tool therefore never
turns the archive-wide structural count into an automatic reachability claim.

From Content Core `0.173.0`, EVENTB14 locks the selected branch until that
branch completes and exposes Mahoko affection separately in Quick Sandbox.
Advancing dialogue no longer reopens the choice projection. Event Catalog's
recommended preset supplies the exact original caller-qualified night state,
uses original `B3.MMO`, and selects the confirmed high-expression B.AX column.
The daytime `B.MMO` route remains compatibility/debug coverage.

Run its focused non-GUI check with:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  res://tests/test_logical_surface_compositor.tscn
```

For an A6 entry, select one existing record in the compact editor below the
metadata view, then edit its ID, left, top, right, or bottom field and press
**Stage A6 rectangle**. The editor rejects the native terminal ID, unsigned
16-bit overflow, and inverted inclusive rectangles. It encodes and reopens the
whole table before publishing one cache-backed `original_engine_compatible`
replacement into the same overlay/new-ARC session. **Add after**, **Duplicate**,
**Remove**, **Move up**, and **Move down** perform the corresponding ordered
table operation and reopen the result through the same validation boundary.
The adjacent diagnostic reports overlap, partial occlusion, unreachable rows,
and selected-row visible area because moving or duplicating a row can change
native first-match input behavior. A6 remains metadata-only and does not accept
PNG import or export.

The A6 Game Frame is a tool-only 640x400 coordinate projection. It outlines
each stored inclusive rectangle, highlights the selected record, reports the
first record hit while the pointer moves, and selects that first match on a
click without enabling gameplay input capture. Coordinates outside the logical
frame remain stored and editable but are naturally clipped in this view. No
background image, A6 ID meaning, or association with an image resource is
inferred.

Use **Asset View** to inspect the decoded source and dimension details. Use
**Game Frame** to place those same decoded native pixels at logical X/Y inside
the fixed 640x400 frame; **Center** restores the calculated centered position.
This placement is inspection-only and is deliberately excluded from replacement
payloads, overlays, and ARC exports.

For AX entries, **Asset View** remains metadata-only. It shows the shared
Content Core's EXE-confirmed 10-by-32 binding table, 320 entry-relative cell
streams, shared `0x1C`-byte source/destination rectangle records, opcode
counts, and a short list of non-`0xFF` stream starts. The native three-byte
green-key copy is identified, but AX contains no standalone pixels and the
host source surface is unresolved. **Game Frame** offers a structural cell
view: choose a non-`0xFF` binding cell to outline the bounded destination
rectangles referenced directly by its stored dispatch commands. This neither
executes control/loop commands nor advances animation time, and the rectangles
contain no inferred pixels. PNG import and ARC/overlay replacement remain
unavailable for AX.

The MES Editor accepts an optional second startup argument pointing to a
generated hash-bound UTF-8 text cache. It searches only the selected MES/LIB
entry and never treats the cache as original source. Cache manifest and entry
JSON are limited to 16 MiB each, and every entry SHA-256 is rechecked over the
same bytes parsed at load time. A changed, truncated, or oversized disposable
cache entry is ignored; the effective MES bytes remain available as decoded
CP932. Without a cache, original
CP932 is decoded and searchable as Japanese; use `hex:<CP932 bytes>` only for
byte-level diagnostics. To author remake-only text, select a strictly
indexed Messages row with the mouse or keyboard, type in the UTF-8 field, and
press Enter or **Stage**. **Revert** removes only that pending edit. **Save
all...** creates or updates a validated overlay package for every entry with
pending edits, publishes one manifest update, and reopens the selected entry;
**Load overlay...** applies a previously saved projection after current ARC and
entry hashes match. **Detach entry** removes only the selected manifest
reference after pending edits are resolved; its content-addressed payload is
retained for recovery. **Hot Reload** revalidates the loaded manifest and
reopens the selected entry through resolver priority, reapplying an externally
updated UTF-8 projection or reanalyzing an updated binary replacement. **Clear
Overlay** detaches the resolver overlay and reopens the selected entry from the
read-only original ARC, with its hash-bound generated cache used for message
presentation when available. Either action is rejected while any entry has
pending edits or the active field contains an unstaged draft, leaving the
loaded manifest, resolver state, and edit session unchanged. Reload candidates
are activated only after manifest, source-hash, targeted-MES parse, and
selected-entry reopen checks succeed, so a malformed or stale package cannot
replace the last valid view. Cache-only rows beyond a decoder stop cannot be
edited. Entry and ARC switches use the same unstaged-draft guard and retain the
current visible selection until the user stages or discards the draft. If a
filter hid that entry, the editor clears the filter before restoring its row.
Save, binary export, and projection detach actions use the same guard, so a
newer field value cannot be silently replaced by an older staged value. MES bytes
continue to resolve as `overlay -> original ARC -> res:// fallback`, and the
opened ARC is never written. Equal-length CP932 new-ARC export is bound to the
source SHA-256 captured at archive open. If that source changes before
publication, export is rejected and the staged edit session remains available.
The MES Editor intentionally uses an 11px
tool-specific font for dense tables. Like the other independent content tools,
it uses native desktop pixels with a 1280x800 preferred client size and a
1024x640 minimum; resizing and maximizing reflow the workspace instead of
scaling a 640x400 tool canvas. The 640x400 coordinate system is reserved for
gameplay and embedded game-frame previews.

Prepare one equal-length CP932 marker edit only as a new, isolated `mes.arc`
candidate:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/prepare_mes_smoke_copy.gd -- `
  <source-mes.arc> EVENTD03.MES 0x29F <new-mes.arc>
```

The preparer accepts only a safe `.MES` basename and a strict-indexed message
whose stored boundary matches the executable-derived native text probe. It
replaces the selected payload with the same number of CP932 double-byte marker
characters, uses the equal-length patcher with native-boundary enforcement,
rebuilds a new archive without relocation, reopens the output, compares the
entire replacement entry, and rechecks the source archive hash. Existing output
and source overwrite remain forbidden by `ArcWriter`. The marker candidate is
still `original_engine_unverified` until it is displayed by an isolated copy of
the original engine.

The full read-only strict-prefix analysis corpus can be checked with:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_analysis_corpus.gd -- `
  <mes.arc>
```

The validator reports stopped range boundaries separately from fatal
container/index failures; it does not infer instructions beyond a stop. It also
reports strict CP932 valid/diagnostic counts without printing dialogue. The
current pass additionally separates generic CP932 success from the narrower
native text-byte envelope derived from the original executable and summarizes
excluded lead-byte counts.

The current Event Player keeps a shared fixed 640x400 game-frame panel inside its
native desktop window. Switch to **Analysis** for the explicit source and trace
workflow described below. Use **Open ELFIMAGE...** for original-event work so the
MES, image, and audio ARC indexes remain available together; standalone
`mes.arc` remains supported for focused analysis. Run a selected MES intro to
render the reached CP932 or
overlay/cache dialogue while Trace, Messages, State Diff, and Summary remain
available below it. Click once to focus the preview, then use click, Space, or
left/right arrows to browse reached messages; Esc releases input. Background,
choice, and audio presentation remain visibly unresolved until their opcode
contracts are confirmed. A bounded filename-bearing voice marker can drive a
separate Ogg Vorbis tool preview from `voice.arc` or a Tina archive while BGM
continues. The frame labels this as a MES marker preview and keeps the original
executable's playback consumer explicitly unresolved.
Continue preserves the last confirmed MMO and loaded audio streams in the tool
frame when the next bounded segment contains no replacement request; the status
uses `unchanged` rather than attributing another request to the original MES.

**Choose Overlay...**, **Hot Reload**, and **Clear Overlay** prepare a separate resolver before
changing the active Event Player session. Every overlay target must belong to
an ARC opened with the current standalone/archive-set session. Each targeted
binary archive is batch-checked against the SHA-256 captured with its displayed index;
MES/LIB replacements are parsed, MES text projections are checked against the
pinned MES/entry hashes, and
the selected entry is reopened in the candidate. The resolver is swapped only
after the complete candidate passes. A failed media binding, malformed MES,
changed manifest, or missing projection therefore preserves the last valid
library/startup context, selected document and Results, continuation/choice
state, game-frame/audio preview, and sandbox. Retry **Hot Reload** after an
external publisher finishes its atomic update. Clear Overlay verifies every
open source ARC against the fingerprint captured with its index and parses the
selected original MES before it swaps to an original-only resolver. Failure
keeps the active overlay and complete preview session; success restores original
binary content while retaining the configured generated text cache. Original
ARCs remain read-only.

When a routine-40 boundary has the exact Content Core 0.176 contract, the game
frame labels it **Routine 40 remake bridge**. Up/Down, number keys, Enter, or
pointer input select an explicit remake option. Confirmation revalidates the
current bytecode, writes only the one-based caller-visible
`state_u16[21]` value, and resumes the stored MES consumer. A complete gated
matrix also shows the existing global gate value; confirmation requires that
value to remain unchanged and never writes it. The footer and
Summary keep the native helper input/effects unresolved. If the boundary has
one source-bound DEF row, the tool displays it as remake option 1 and requires
the exact stored result-1 branch plus its separate false destination; it does
not infer a cancel/back meaning for that false path. If the boundary has
bounded DEF rows but neither this consumer contract nor a dedicated
hash-bound projection, the frame instead labels them **Explicit detached DEF
preview**. That fallback runs only one hash-checked body in a duplicated
sandbox, disables Continue, discards all state, and never resumes the caller.
An address-table **Preview Row** session always uses this detached contract,
including when the inspected row happens to match the reusable result bridge:
source-table order alone is not authority to write the caller-visible result
or resume a gameplay consumer.
Original EVENTD01 validation additionally reopens DEF body 0 at
`0x0704..0x0729` through this detached path before reproducing its separately
confirmed route.

Reproduce the stored `43C.MES` two-stage group topology without exporting
dialogue or executing native input:

```powershell
py tools\audit_mes_routine40_groups.py <ELFIMAGE\mes.arc> `
  --entry 43C.MES --address-entry 148 `
  -o analysis\mes_routine40_groups_43c.json
```

Schema `kakyu_mes_routine40_group_route_audit/v4` checks each literal group
clear, registration body and guard skip target, the unique routine-40
terminal, and the matching seven-row route. It also joins the post-routine
one-based slot-21/slot-13 consumer to the registered group counts. The report
keeps incomplete mappings explicit: authoritative group 4 registers two rows
but has a stored branch only for secondary result 1. Result 2 follows the
common default chain to command `0x0C` at `0xA304` and its backward coordinate
transfer to `0x399F`. V4 additionally binds that destination to address-table
entry 127 and its constant-true fallthrough back into the dispatcher. It scans
the same source ARC for exact command-`0x0E` records naming the target MES and
reports six such envelopes in three caller entries. Since the EXE-audited
handler still supplies neither callee coordinate nor caller restoration, the
report records a shared host-activation blocker rather than promoting entry
148 to playback. It assigns neither cancel/back semantics nor a host-selected
start coordinate. The report contains source
coordinates, state indices and hashes but no text or raw MES payload. It is a
structural evidence tool: group eligibility during a real play state, native
selection cadence/effects and combined result meaning remain unresolved.

Content Core `0.199.0` adds the separate
`kakyu_mes_routine40_reachability/v1` projection. It revalidates the v2 grouped
contract and emits numeric-only routes for the currently evaluated registry.
The authoritative default/fully eligible profiles contain 13/40 routes:
8/37 exact stored consumers, one common `0xA304 -> 0x399F` fallback each, and
four/two `0xFFFF` empty-list boundaries. The default profile also records 29
stored group-1/group-3 branches as inactive; the eligible profile records none.
No destination is executed and no caller or gameplay label is synthesized.

Recheck the six directly verified `D_PIC.MES` MMO presentation resources
against the authoritative archive without extracting payloads:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_presentation_resources.gd -- `
  <mes.arc> [mmo.arc]
```

The validator checks the entry hash, code-relative offsets, command `0x09`
shape, and expected safe MMO names. When `mmo.arc` is supplied, it also reads
and strictly decodes only those six referenced entries. It does not generalize
other `0x09` forms.

Validate one bounded partial reference graph by address index, `bootstrap`, or
an owning code-relative coordinate. The optional final arguments are confirmed
flow expansion depth and maximum additional ranges:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_reference_graph.gd -- `
  <mes.arc> D_TALK00.MES offset:0x82f 2 8
```

Content Core `0.200.0` labels this core projection
`kakyu_mes_reference_graph/v1`. Downstream analyzer and decompiler consumers
must check that schema directly; the separately versioned editor JSON export
is only a transport wrapper and does not establish core compatibility.

Build and repeat-check one language-neutral Phase 1-4 handoff, optionally
writing its deterministic JSON outside the source archive directory, then
validate that exact document from Python:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_analyzer_handoff.gd -- `
  <mes.arc> D_TALK00.MES offset:0x82f <handoff.json>
py tools\validate_mes_analyzer_handoff.py <handoff.json>
```

The GDScript producer owns the current Phase 1-4 byte boundaries. Python is
the default offline Phase 5 consumer and verifies the handoff schema and
fingerprint without reparsing the MES. Independent Python source audits remain
evidence tools and require parity before serving as replacement IR producers.

Regenerate and verify the compact Phase 1-4 completion report. The first tool
builds and re-verifies all 1,016 per-entry handoffs but writes only aggregate
schemas, inventories, counts, and fingerprints:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_analyzer_handoff_corpus.gd -- `
  <mes.arc> <completion.json>
py tools\validate_mes_analyzer_completion.py <completion.json>
```

Current completion schema is `kakyu_mes_analyzer_completion/v1`. The owner
approved the instruction-v45 corpus fingerprint
`fae349f9affbaf244f44fe61f3afc380cb980f058950fe85fcb1f7d097eab6f5` on
2026-09-06; TD-15's complete audit against that baseline passes. Its verified
compact payload fingerprint is
`a0883d4ffcd4f6c0831818ad2187dcfc3e81dc1002f54c9bfc19f35e134ea828`. The
historical v43 corpus fingerprint `2d182d27...b911807` and compact payload
fingerprint `1f783917...0055443b` identify the earlier report, not a current
reproduction target. Output must remain outside the source archive directory.

Lift a verified handoff into the Phase 5 lossless linear decompiler form:

```powershell
py tools\decompile_mes_handoff.py <handoff.json> <linear-ir.json>
```

`kakyu_mes_decompiler_ir/v1` is produced by Python but consumes the exact
GDScript Phase 1-4 schema lock. It retains expression ASTs, typed and opaque
nodes, source and raw-byte identities, reference ownership, bounded CFG links,
and call/trace evidence. Its validator reconstructs the source container from
the retained preamble and ordered nodes before accepting the output. This is a
lossless linear decompiler baseline, not yet proof-bounded `if`/loop structuring
or human-readable pseudocode.

Annotate that verified linear form without introducing semantic names:

```powershell
py tools\annotate_mes_decompiler.py `
  <linear-ir.json> <semantic-annotations.json>
```

Content Core `0.220.0` reserves `kakyu_mes_semantic_annotation/v1`. The output
assigns every node and source reference one exact owner and source-qualified
operation or canonical numeric/literal identity. Messages retain coordinates
and raw identity rather than decoded dialogue. All character, place, event-role,
and state-meaning aliases remain explicitly unresolved. Validation regenerates
the projection from the hash-bound linear input and rejects alias injection or
unknown reference kinds.

Compose the validated source and first proved structure layers into one
standalone renderer input:

```powershell
py tools\compose_mes_renderer_input.py `
  <linear-ir.json> <semantic-annotations.json> `
  <flow-proof.json> <region-proof.json> <renderer-input.json>
```

Content Core `0.221.0` reserves `kakyu_mes_renderer_input/v1`. This core layer
retains the complete low-level label/goto fallback, full linear nodes and
symbols, proved `if_then`/`if_else` rows, and a reversible source-map row for
every linear node. All four upstream documents are validated and hash-bound;
mixing proofs from another linear projection fails closed. Later dispatch,
loop, cross-region, and call overlays remain separate MD-03 work.

Add the validated non-loop MD-02 proof family without discarding the v1 core:

```powershell
py tools\compose_mes_renderer_overlays.py `
  <linear-ir.json> <semantic-annotations.json> `
  <flow-proof.json> <region-proof.json> `
  <guard-proof.json> <value-proof.json> <predicate-proof.json> `
  <cross-region-join-proof.json> <call-family-proof.json> `
  <renderer-input-v2.json>
```

Content Core `0.222.0` reserves `kakyu_mes_renderer_input/v2`. It embeds each
complete proof document and promotes only accepted guard, dispatch, join, and
call rows with exact linear-node reversal. Rejected candidates remain visible;
natural-loop composition and text rendering remain open.

Complete the proved structure family with source-bound natural loops:

```powershell
py tools\compose_mes_renderer_loops.py `
  <linear-ir.json> <semantic-annotations.json> `
  <flow-proof.json> <region-proof.json> `
  <guard-proof.json> <value-proof.json> <predicate-proof.json> `
  <cross-region-join-proof.json> <call-family-proof.json> `
  <library-audit.json> <shared-call-proof.json> `
  <execution-fallthrough-proof.json> <natural-loop-proof.json> `
  <renderer-input-v3.json>
```

Content Core `0.223.0` reserves `kakyu_mes_renderer_input/v3`. It validates and
embeds the complete library/return/execution/loop chain, adds only proved loop
envelopes as reversible overlays, and retains unresolved calls, rejected
fallthroughs/headers, exits, and the full v2 fallback. It does not choose
`while` or `for` syntax; deterministic text rendering is the remaining MD-03
step.

Render the completed v3 structure family as source-reversible pseudocode JSON:

```powershell
py tools\render_mes_pseudocode.py `
  <renderer-input-v3.json> <pseudocode.json> `
  --text-output <optional-pseudocode.txt>
```

Content Core `0.224.0` reserves `kakyu_mes_pseudocode/v1`. JSON is the primary
output; the optional text file is derived from its ordered line strings. Each
linear node appears once with exact source coordinates and raw identity, while
proved structures and overlays receive separate source-qualified marker lines.
Messages remain coordinates, semantic aliases stay unresolved, and control is
rendered as proved branch/goto/overlay tokens rather than guessed
`switch`/`while`/`for` syntax.

Audit one exact renderer/pseudocode pair before adding it to corpus closure:

```powershell
py tools\audit_mes_decompiler_equivalence.py `
  <renderer-input-v3.json> <pseudocode.json> <equivalence-audit.json>
```

Content Core `0.225.0` reserves
`kakyu_mes_decompiler_equivalence_audit/v1`. The validator replays both input
contracts and requires a contiguous `[0,end)` byte partition, unique region
ownership, exactly one rendered line per linear node, exactly one marker for
every structure and overlay, and exact source-row reversal. Opaque nodes,
unresolved controls, unresolved surface syntax, and proof rejection evidence
paths are inventoried rather than promoted. V1 is a single-entry contract; it
does not claim corpus closure.

Create a fresh source-bound spool outside both the project and source archive
directory. `0` exports every eligible MES/LIB entry; a positive limit is for a
partial verification spool and cannot claim archive completion:

```powershell
godot --headless --path . `
  --script res://tools/content_suite/cli/export_mes_decompiler_handoff_spool.gd -- `
  <mes.arc> <new-output-directory> <max-entries-or-0>
```

Content Core `0.227.0` adds the producer. It builds one whole-entry
confirmed-flow CFG per handoff, audits all registered `LIBLARY.LIB` routines,
rehashes the source ARC, and publishes `handoff-spool-manifest.json` only after
every selected payload succeeds. Generated spool files are local-only evidence
and must not be added to Git.

Consume that spool without retaining every large derived Phase 5 document:

```powershell
py tools\audit_mes_decompiler_corpus.py `
  <handoff-spool-manifest.json> <library-audit.json> <corpus-audit.json> `
  --jobs 4
```

Content Core `0.226.0` reserves
`kakyu_mes_decompiler_handoff_spool/v1` and
`kakyu_mes_decompiler_corpus_audit/v1`. The manifest contains ordered relative
handoff filenames and exact source/handoff hashes; traversal and archive/order
drift fail closed. The consumer holds one entry's intermediate documents in
memory, runs MD-01 through pseudocode and single-entry equivalence, and writes
only compact fingerprints, numeric coverage, invariants, and unresolved
semantic categories. It never copies raw bytes or pseudocode text into the
aggregate. The authoritative full run remains a separate step.

Within one entry only, the consumer memoizes successful validator and nested
renderer-composer calls by Python object identity, schema, and retained payload
hash. Every document is still validated on first production, the cache is
discarded before the next entry, and public standalone validators are unchanged.
This is validation reuse for immutable pipeline values, not a relaxed or
skip-validation mode.

Content Core `0.229.0` permits one to four independent entry processes. A
worker receives the already source-bound manifest and library audit, loads and
validates one handoff at a time, and owns a private validation-reuse scope. The
parent accepts each compact result once, restores manifest position order, and
only then aggregates and hashes the report. Worker count and completion order
are excluded from the contract, so serial and parallel output must be exactly
identical. On failure, queued work is cancelled before the error is propagated.

The complete authoritative run consumes all 1,016 source-bound handoffs and
emits a 1,804,540-byte compact report. Two four-process executions are
byte-identical at file SHA-256
`09dd2c12de69545921407c2cf9b34f7269347fd3f1bfa3dd5972199c5f7271fc`
and contract fingerprint
`10715ec9672bb26549b666b96d14a31546eff4ec8f4cc9589e93db956e96716b`.
The generated handoff spool is disposable local evidence; only the compact
path-free aggregate needs to be retained.

Prepare the Phase 6 editable JSON boundary from one validated linear IR:

```powershell
py tools\prepare_mes_editable_ir.py <linear-ir.json> <editable-ir.json>
```

Compile the currently supported zero-operation document to a new MES and a
compact audit published last:

```powershell
py tools\compile_mes_noop.py `
  <editable-ir.json> <new-output.mes> <new-compile-audit.json>
```

Content Core `0.230.0` reserves `kakyu_mes_editable_ir/v1` and
`kakyu_mes_noop_compile_audit/v1`. The editable IR embeds the immutable,
fingerprinted Phase 5 linear source and an ordered operation list. The current
compiler accepts only an empty list, reconstructs every preamble/typed/opaque
byte, reopens the address table, requires exact source hashes, and refuses to
replace inputs or existing outputs. This is the MW-01 no-op baseline, not
variable-length assembly or an original-engine compatibility claim.

Reopen the emitted binary through the current GDScript Phase 1-4 analyzer and
cross-check the Python audit:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_noop_compile.gd -- `
  <new-output.mes> <new-compile-audit.json>
```

Content Core `0.231.0` reserves `kakyu_mes_noop_reopen_audit/v1`. The validator
checks the compile-audit fingerprint and exact fields, reparses the container,
rebuilds typed/opaque analysis, alignment, and the analyzer handoff, and
requires all hashes and coverage counts to agree. Integral JSON numbers are
canonicalized across Python and Godot; fractional counts remain invalid.

Compile a completed source-bound handoff spool in bounded parallel workers:

```powershell
py tools\audit_mes_noop_compile_corpus.py `
  <handoff-spool-directory> <new-compile-spool-directory> --jobs 4
```

Then reopen the complete compile spool through GDScript while rehashing the
authoritative source archive before and after:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/audit_mes_noop_reopen_corpus.gd -- `
  <compile-spool-directory> <mes.arc>
```

Content Core `0.232.0` reserves `kakyu_mes_noop_compile_spool/v1` and
`kakyu_mes_noop_reopen_corpus_audit/v1`. The Python manifest is path-free and
published last; its directory contains only compiled MES bytes, compact audits,
and that manifest. The GDScript pass validates safe basenames, every per-entry
audit and Phase 1-4 reopen, exact aggregate coverage, archive order, and source
archive immutability.

Build a fail-closed variable-length message relocation preflight:

```powershell
py tools\plan_mes_message_relocation.py `
  <editable-ir.json> <replace-message-operation.json> <new-plan.json>
```

Content Core `0.233.0` reserves
`kakyu_mes_message_relocation_plan/v1`. The operation supplies a code-relative
message offset, exact source-message SHA-256, authored CP932 text, and required
native-projection policy. The tool emits JSON only. It inventories changed
address-table cells and source/target reference coordinates, and sets
`assembly_ready` false when an opaque record would shift or an encoded code
target requires the still-open MW-03 relocation implementation.

Compile a blocker-free plan into new MES and audit files, then independently
reopen them through Godot:

```powershell
py tools\compile_mes_message_relocation.py `
  <editable-ir.json> <plan.json> <new-output.mes> <new-audit.json>

& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_message_compile.gd -- `
  <new-output.mes> <new-audit.json>
```

Content Core `0.235.0` reserves `kakyu_mes_message_compile_audit/v1` and
`kakyu_mes_message_reopen_audit/v1`. The compiler refuses blocked plans,
existing output paths, and any drift in the source/plan relationship. The
GDScript pass validates the Python audit fingerprint and rebuilds the current
container, analysis, alignment, and handoff contracts from the changed bytes.
This is structural compatibility only; the audit remains explicit that native
engine compatibility is unverified.

Build a distinct remake-only UTF-8 overlay plan and optionally bind it again to
the source ARC through Godot:

```powershell
py tools\plan_mes_utf8_overlay.py `
  <editable-ir.json> <utf8-overlay-operation.json> <new-plan.json>

& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_utf8_overlay_plan.gd -- `
  <new-plan.json> [<mes.arc>]
```

Content Core `0.236.0` reserves `kakyu_mes_utf8_overlay_plan/v1`. Its operation
kind is `replace_message_utf8_overlay`; encoding must be `utf8`, compatibility
must be `remake_only`, and container policy must be `do_not_assemble_mes`.
The plan contains one `kakyu_mes_text_overlay_entry/v1` document and no MES
bytes. `KakyuOverlayPackage.stage_mes_utf8_overlay_plan()` rechecks the active
ARC and entry hashes, then feeds the bound edit into the established atomic
projection publication/reopen path. This closes the separate UTF-8 portion of
MW-02 without claiming original-engine UTF-8 support.

Project only the control transfers that have matching linear operands and
Phase 4 graph edges:

```powershell
py tools\prove_mes_control_flow.py <linear-ir.json> <flow-proof.json>
```

`kakyu_mes_control_flow_proof/v1` proves exact conditional true/false and
continuation targets, accounts for every supplied graph edge once, and keeps
unconfirmed shapes, expansion-depth leaves, and opaque stops explicit. It is
the first MD-02 proof layer; it does not yet claim structured regions.

Emit the deterministic low-level fallback used before high-level region
promotion:

```powershell
py tools\emit_mes_low_level_control.py <flow-proof.json> <control-ir.json>
```

`kakyu_mes_low_level_control_ir/v1` assigns one stable label and one statement
to every proof graph node. It emits proved conditional/goto targets and keeps
boundaries, unresolved transfers, and unexpanded leaves explicit. Validation
rebuilds the projection from the embedded proof graphs.

Prove only same-region forward conditions whose full body and join satisfy the
reducibility contract:

```powershell
py tools\prove_mes_if_regions.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json>
```

`kakyu_mes_reducible_region_proof/v2` embeds the low-level fallback, records
proved `if_then`/`if_else` source maps and nesting, and keeps deterministic
reasons for every rejected conditional. Cross-region flow remains
unstructured.

Prove or reject bounded cross-region join relationships without guessing
surface syntax:

```powershell
py tools\prove_mes_cross_region_joins.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json> `
  <cross-region-joins.json>
```

`kakyu_mes_cross_region_join_proof/v1` requires both arms of a cross-region
conditional to reach one unique nearest join on every bounded path. External
graph entries and confirmed code references into either arm reject the
relationship. The output binds the complete low-level fallback and reports
source-qualified path/join labels; it deliberately leaves `if` syntax
unresolved.

Record maximal false-edge guard relationships without hiding any fallback
label:

```powershell
py tools\prove_mes_guard_chains.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json> <guard-chains.json>
```

`kakyu_mes_guard_chain_proof/v1` excludes conditions already promoted to
`if_then`/`if_else`, retains every guard, case, and default label, and leaves
semantic dispatch unresolved.

Promote only simple repeated equality guards to numeric value dispatches:

```powershell
py tools\prove_mes_value_dispatches.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json> `
  <guard-chains.json> <value-dispatches.json>
```

`kakyu_mes_value_dispatch_proof/v1` requires one exact numeric state coordinate
and unique literal values. It retains labels and leaves case-body extent and
semantic state names unresolved.

Normalize compound or irregular state-equality guard chains without guessing
high-level syntax:

```powershell
py tools\prove_mes_predicate_dispatches.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json> `
  <guard-chains.json> <value-dispatches.json> `
  <predicate-dispatches.json>
```

`kakyu_mes_predicate_dispatch_proof/v1` consumes only chains rejected by the
simple value-dispatch layer. Guards made entirely from numeric state equality,
`logical_and`, and `logical_or` receive an exact bounded DNF projection plus
their original AST and ordered labels. Unsupported terms and expansion beyond
the schema limits fail closed. Evaluation cadence, mutual exclusivity,
case-body extent, semantic names, and surface syntax remain unresolved.

The Event Player accepts optional startup arguments in this order:
`<mes.arc> <overlay-root> <text-cache-root>`. It never launches Python. Generate
the disposable UTF-8 cache separately when readable dialogue preview is
needed. A validated authored MES text projection from the overlay takes
priority over that cache after its current ARC, entry, and raw-message hashes
match; **Hot Reload** refreshes both binary replacements and authored text.
In ELFIMAGE mode the binary path covers traced MMO, BGM, and voice resources
through the same hash-bound `overlay -> original ARC` resolver, and the game
frame labels the selected source:

```powershell
py tools\export_mes_text_cache.py <mes.arc> -o analysis\mes_text_cache
```

Pass `--all` to cover every MES/LIB entry, or repeat `--entry NAME.MES` for a
focused cache. The strict GDScript/Python instruction-boundary oracle and text
cache can be checked with:

```powershell
py tools\export_mes_instruction_oracle.py <mes.arc> `
  -o analysis\mes_instruction_oracle.json
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_instruction_oracle.gd -- `
  <mes.arc> analysis\mes_instruction_oracle.json
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_text_cache.gd -- `
  <mes.arc> analysis\mes_text_cache
py tools\audit_mes_command03.py <mes.arc> `
  -o analysis\mes_command03_audit.json
py tools\audit_mes_command03.py <mes.arc> --focus-index 2461 `
  -o analysis\mes_command03_index2461_audit.json
py tools\audit_mes_command03.py <mes.arc> `
  --focus-index 376 --focus-index 377 --focus-index 403 `
  -o analysis\mes_command03_group_guard_producers.json
py tools\audit_mes_command04.py <mes.arc> `
  -o analysis\mes_command04_audit.json
py tools\audit_mes_command07.py <mes.arc> --command-id 6 `
  -o analysis\mes_command06_audit.json
py tools\audit_mes_command07.py <mes.arc> `
  -o analysis\mes_command07_audit.json
py tools\audit_mes_command07.py <mes.arc> --focus-start-index 200 `
  --focus-end-index 237 --focus-bank 0 --focus-record-limit 256 `
  -o analysis\mes_command07_fields_200_237.json
py tools\audit_mes_command07.py <mes.arc> --command-id 8 `
  -o analysis\mes_command08_audit.json
```

Command-`0x03` audit v3 accepts repeated `--focus-index` options and decodes
the archive once for the complete requested set. Results preserve request
order, remove duplicate indices, retain zero-writer rows, and include the
covering pair and expression AST without dialogue. A single option retains the
v2-compatible `focus_index` field in addition to the ordered v3 list.

Banked-write audit v3 always counts the complete selected focus interval. It
reports literal destinations by written index and entry, keeps dynamic
destinations as separate possible candidates, and retains at most the requested
number of detailed records so a corpus-wide audit cannot produce an unbounded
JSON projection. A record limit of zero emits only complete aggregate counts.

To validate every ARC in a user-owned `ELFIMAGE` directory with the shared
reader and a sequential byte-identical no-op copy, run:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_arc_corpus.gd -- <ELFIMAGE>
```

The validator creates a unique temporary directory, processes one archive at a
time, compares source/output SHA-256, verifies the source hash remains stable,
checks resize-layout eligibility, and removes only its generated copy before
continuing. ArcWriter also checks the destination again after temporary-copy
verification and immediately before publication. If a file appeared at that
path during the rebuild, it is preserved and the temporary ARC is removed.
To exercise a one-byte variable-size rebuild against a selected
original entry in a disposable output, run:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_arc_repack.gd -- `
  <archive> <entry>
```

For an isolated original-engine smoke-test copy, the audio preparation helper
can either append one byte to one otherwise unchanged entry or use a supplied
validated replacement. Source and output must be different paths, and an
existing output is refused:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/prepare_arc_smoke_copy.gd -- `
  <source-archive> <entry> <new-archive> [replacement-audio]
```

Passing `*` as `<entry>` requires `replacement-audio` and targets every WAV/Ogg
entry. The operation fails if that one payload is not valid for every target
extension. This is a validation probe, not an authored multi-entry editing
interface. The helper validates every target through the shared audio
validator, uses the file-backed streaming `KakyuArcWriter` API when a
replacement path is supplied, reopens the result, and verifies that the source
archive hash did not change.

To prepare a no-reencode Ogg/WAV replacement candidate entirely from two
entries already present in one source archive:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/prepare_audio_swap_smoke_copy.gd -- `
  <source-audio.arc> D0977.OGG D1033.OGG <new-audio.arc>
```

The target and donor must be safe distinct basenames with the same container,
codec, channel count, sample rate, and WAV bit depth when applicable. The
helper validates both complete payloads, replaces only the target through the
resize-capable writer, reopens the output, requires the rebuilt target and
unchanged donor entry to equal the donor bytes, and rechecks the source hash.
It does not decode or re-encode the audio. This prepares a distinctive playback
candidate but does not establish original-engine compatibility.

On Windows, the complete original-engine PCM playback check is automated:

```powershell
.\tools\content_suite\test_original_engine_audio.ps1 `
  -GameRoot "<user-owned-game-root>"
```

The game root must contain `AI5WIN.original.exe` and `ELFIMAGE`. Godot 4.7's
console executable must be on `PATH`, or may be supplied with `-GodotConsole`.
The test also requires an enabled default Windows multimedia output endpoint.
It creates a one-second mono 22,050 Hz 16-bit PCM probe without ffmpeg, replaces
only `KSE0031.WAV`, and starts the isolated original engine without foreground
input or save interaction. The copied INI disables music and voice while
leaving effects enabled, so Core Audio activity is attributable to the startup
effect request recorded in `docs/spec/mes/audio.md`.

The test passes only when the child process creates a titled responsive window,
its audio peak exceeds the configured threshold, and the active interval fits
the one-second probe window. Original executable/INI/target-archive/save hashes
and all source ARC sizes/timestamps are compared after execution. Only
processes whose executable path is below the unique test root are stopped, and
the direct child of the system temporary directory is removed in `finally`.
The script prints `ORIGINAL_ENGINE_AUDIO_SMOKE_PASS` only after these checks and
cleanup succeed.

Prepare the complete deferred interactive candidate set without launching an
engine or GUI:

```powershell
.\tools\content_suite\prepare_original_engine_verification_batch.ps1 `
  -GameRoot "<user-owned-game-root>" `
  -OutputRoot "<new-local-output-directory>" `
  -GodotConsole "<Godot-4.7-console-path>"
```

Use `-PlanOnly` to perform only the source-identity, destination-safety, and
space preflight. The preparer is version-locked to the checked launcher plus
`mes.arc`, `data.arc`, and `voice.arc` hashes. It refuses an existing output or
an output inside the source installation, prepares all three candidates below
a uniquely named sibling staging directory, verifies source hash/size/timestamp
identity, writes `kakyu_original_engine_verification_batch/v1`, then publishes
the complete directory with one rename. Failure removes only the guarded
staging directory. Its manifest contains basenames, hashes, byte sizes, target
entries, and expected observations, but no machine paths or original payloads.
The published status remains `prepared_unverified` and
`launches_original_engine` remains `false` until a disposable local copy is
explicitly launched by the user.

Prepare the license-independent disposable local copy without opening it:

```powershell
.\tools\content_suite\prepare_local_verification_copy.ps1 `
  -GameRoot "<user-owned-game-root>" `
  -BatchRoot "<prepared-candidate-batch>" `
  -OutputRoot "<new-local-verification-copy-directory>"
```

The generator rechecks the launcher, candidate manifest, all three candidate
hashes, and eight source ARC files. It copies the launcher as `AI5WIN.exe`, the
INI, ARC files, optional compatibility files, and relevant saves below a unique
sibling staging directory. It replaces only copied `mes.arc`, `data.arc`, and
`voice.arc`, rehashes the entire copied archive set, rechecks every input, then
publishes `kakyu_local_verification_copy/v1` with one rename. `-PlanOnly`
performs identity, destination, and disk-space checks only. Preparation never
opens the copied engine. The directory contains user-owned original data and
must remain local and untracked; delete it after the user-controlled check.
No optional OS virtualization feature is part of the verification options;
the local-copy contract works on the supported Windows editions directly.

The audio-header corpus validator performs bounded header reads and exercises
the same WAV/Vorbis validator used by the Audio ARC Editor:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_audio_corpus.gd -- <ELFIMAGE>
```

The MES container corpus validator checks every MES/LIB address table directly
from `mes.arc`:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_corpus.gd -- <mes.arc>
```

Inspect selected shared-library routines without executing them or exporting
their text/bytecode:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_library_routines.gd -- `
  <mes.arc> 0 28 40
```

Add `--summary` before or after the routine IDs for compact CI output containing
only source fingerprints, bounds, decode counts/stops, linear stack totals,
scope, and return-segment counts. The default remains the complete JSON
diagnostic report. Add `--output <report.json>` to write that path-free report
for downstream proof tools; it refuses to replace the source archive and can
be combined with `--summary`.

The JSON report contains only routine and instruction bounds, opcode names,
strict/structural decode stops, and the shared persistent-stack diagnostics.
Its routine-level stack total is explicitly named `linear_stack_effect`: it
follows stored instruction order and is not an executed control-flow path.
Audit schema v2 records that scope explicitly and additionally reports
`return_delimited_segments`, which split the same structural order after every
command-`0x00` return. These segments are still diagnostics, not reconstructed
branch paths.
It fingerprints `mes.arc` and `LIBLARY.LIB`, rechecks the archive fingerprint
after the audit, and never writes or extracts either source.

MMO and DAT/PAL corpus validators exercise the shared image codecs directly:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mmo_corpus.gd -- <mmo.arc>
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_dat_pal_corpus.gd -- <data.arc>
```

The MMO validator checks every header and strictly decodes `01CA_1.MMO`, then
encodes that representative with its original header and requires header- and
pixel-identical decode output. It does not write an archive and does not claim
new original-executable compatibility beyond the separately isolated standard
header smoke test. Content Core `0.184.0` additionally fixes the original
header matrix: 1,718 standard mirrored-dimension headers, eight preserved
nonzero-trailer headers, one flagged secondary-dimension `CALFACE.MMO` header,
302 primary dimension pairs, and no unclassified entry. Special templates and
generated canonical headers are always `remake_only`. The known short
`CALFACE.MMO` stream remains an explicit strict-fail/216-byte-preview-padding
boundary, and the validator rechecks that source `mmo.arc` did not change.

The DAT/PAL validator decodes all paired entries and additionally re-encodes
the representative transparent `CHARA` strip and opaque `MACHIN_3` background.
It requires fixed DAT/PAL sizes, visually identical decode output, and an unchanged
source archive fingerprint. For the transparent strip, equality covers its
alpha mask and opaque RGB pixels; hidden RGB under alpha zero is excluded.
This remains a codec round trip, not an
original-executable compatibility claim.

Prepare a marker-bearing `mmo.arc` only inside an isolated smoke-test root:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/prepare_image_smoke_copy.gd -- `
  <source-mmo.arc> TITLE_ <new-mmo.arc>
```

The preparer strictly decodes every matching MMO, adds an 80x80 magenta/green
screen-detection marker, encodes with each target's exact 0x28-byte header,
rebuilds a new archive, reopens every replacement, and rechecks the marker and
source-archive hash. It refuses an existing output. This utility must never be
pointed at the source archive as its output.

Prepare a marker-bearing `data.arc` for the paired map background only inside
an isolated smoke-test root:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/prepare_dat_pal_smoke_copy.gd -- `
  <source-data.arc> MACHIN_3 <new-data.arc>
```

The DAT/PAL preparer requires an exact stem without path separators or an
extension. It strictly decodes the pair, replaces every 16x16 atlas tile with a
repeating magenta/green detection pattern, encodes both files, verifies the
decoded marker, rebuilds a new archive, reopens both replacements, and rechecks
the source hash. Repeating the marker in every source tile keeps it detectable
after the original engine assembles the visible map from the atlas. This is
preparation for an isolated engine test only; it does not by itself establish
original-engine compatibility.

Run the complete isolated visual smoke test only with explicit approval:

```powershell
powershell -ExecutionPolicy Bypass -File `
  tools/content_suite/test_original_engine_image.ps1 `
  -GameRoot "<user-owned-game-root>" `
  -EvidencePath "<local-untracked-evidence.png>"
```

The harness targets `LOGOBKC.MMO`, the persistent menu background observed in
an isolated capture. It copies the original executable, INI, ARC files, and relevant save
files into one uniquely named child of the system temporary directory. It
disables audio only in the copied INI, prepares the marker-bearing copied
`mmo.arc`, launches only the copied executable, and requires both marker colors
in a captured client image. In `finally` it stops only processes whose
executable path is below that temporary root, rechecks original executable,
INI, target archive, save hashes, and every source ARC size/timestamp, then
removes the validated temporary child. Evidence output is optional, local,
refuses overwrite, and must never be tracked.
