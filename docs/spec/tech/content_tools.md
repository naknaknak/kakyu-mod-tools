# Content Core and Independent Tools

The bounded script route probe in `content_core/mes_route_probe.gd` is shared
analysis infrastructure. The playback-package equivalence validator calls it
for both bytecode and packaged records with the same catalog preset and choice
policy. Its extraction preserves the twelve-event comparison's trace, state,
message and terminal results. It omits labelled native presentation and stops
at unsupported boundaries; a callee return does not prove a deferred caller's
completion or standalone package completeness. It is not a mod-player runtime.

Core 0.307.0 composes nested registered definitions in this shared probe,
preserving argument/expression contexts and exact caller resume. Tool limits
are eight definition levels and 128 invocations per route run. Structured
`stop_detail` retains the source entry, definition, status and offset of an
unsupported definition outcome. The [GROUND analysis group](../mes/ground_event_analysis.md)
retains the original calendar-dependent stop as its historical V1 measurement.

Core 0.308.0 adds optional `initial_state` to `run_route(provider, descriptor,
selected_preset, initial_state)`. It duplicates the full sandbox before applying
preset writes, preserving the runtime-only START calendar, relative-byte aliases
and native word baseline. Existing calls still start fresh. A continuation must
carry `state_object`, not round-trip `state` records, which intentionally omit
that backing. The original input remains untouched even when a preset fails.
The GROUND V2 validator compares segmented prefix/callee/suffix execution against
an unbroken route, including the final written-value snapshot, trace and messages.
`snapshot()` excludes runtime layout and random-generator internals; separate
clone regressions verify calendar backing and alias preservation.

Core 0.309.0 propagates a nested script handoff through every waiting caller.
Once a child replaces the script, the probe retains that exact child terminal
and executes neither a caller suffix nor the handoff target. Ordinary nested
returns still resume each caller in order. Direct and transitive synthetic
regressions cover both behaviors.

Core 0.310.0 adds an optional analysis `stop_before_dispatch` descriptor with
`entry`, `offset`, `end` and `target`. The probe retains the reached command-0F
record and carried state, then stops before invoking that child. Earlier calls
to the same member execute normally. The result has no terminal and reports
`stop_detail.status = analysis_dispatch_stop`; a different end or target at
that caller coordinate reports `analysis_dispatch_mismatch` before invoking
the child. A stop in another owner does not match. Consumers must check the
exact stop, since a requested coordinate may never be reached. This tool
inspection policy does not remove the target from the provider or change
ordinary runtime calls. A repeated-callee regression verifies segmented and
unbroken state/trace equality, changed identity rejection and seed isolation.

Core 0.311.0 adds optional `follow_root_handoff` with the same four identity
fields for one command-0E replacement. Its exact source record must be reached;
a changed end/target fails before target execution, and an unprovided target
retains the original boundary with an explicit stop. On a match the instrument
executes the target from zero with the carried sandbox and a fresh script
context. This is an explicit analysis policy. A consumed-once flag bounds a
revisited activation. The replacement's own return or next handoff owns the
terminal; no suspended caller resumes. Default calls still stop at the first
handoff. Synthetic regressions cover state/trace equivalence, expression-context
isolation, exact identity, missing members, reentry and nested caller suppression.

`kakyu_event_analysis_group/v2` adds explicit source-bound state contexts,
routine-40 contracts, per-variant choices and effects, caller resume and completed
reentry expectations. Its source audit and runtime report use V2 schemas too.
V1 profiles remain supported with unchanged qualification and report hashes;
an upgrade requires newly audited evidence, not a schema-only migration. The
default group profile is `ground_h17_k09_v2.json`. Both versions are analysis
witnesses, separate from playable catalog entries. A declared handoff inside a
Python opaque tail is hash-bound and labelled `runtime_observation_in_opaque_tail`;
only the instrument's actual caller execution can qualify that observation.
The original typed/opaque handoff is never rewritten by this validator.

`kakyu_event_analysis_group/v3` extends this evidence format for events whose
callers continue into other event decisions. Each route declares
`caller_continuation_observation`; a resume uses either `natural_handoff` or
`stop_before_unprovided_dependency`. The latter requires an exact command-0F
target absent from the group's source members and reports an observed boundary
with no terminal. This is an explicit tool stopping policy, not a missing
original entry or a completed scene. Resume bindings may name an exact typed
record or retain a containing opaque-tail hash. V3 source/runtime reports use
their own schema and preserve this qualification.

V3 direct reentry expectations can be exact returns or routine-40 choice stops;
each variant can supply a full reentry override. Every override's source record,
count and state writes are audited. Runtime selects overrides only for V3-V5,
checks the exact observed boundary and retains its state changes. A rejected
caller guard does not imply the directly invoked callee is inert. V1/V2 readers
and their historical report identities remain available unchanged; migrating
to V3 requires authoring and auditing the new policies and observations.
The [H01/H02 group](../mes/ground_h01_h02_analysis.md) exercises this contract.

`kakyu_event_analysis_group/v4` adds a required typed `origin_offset` in the
caller, at or before the declared guard. The prefix hash covers
`[origin_offset, caller.end)`, and both segmented and unbroken execution start
there. The primary command-0F caller now has an exact `record_sha256` and
`source_binding`: either a Python typed record or an observed span in a
hash-bound opaque tail. In the latter case its immediate resume may remain
inside the same tail. This permits measuring a reached opaque dispatch without
using that opaque coordinate as an arbitrary initial execution entry.

V4 routine-40 contracts bind their own `source_identity.entry` to a declared
source member. Variant selections use `(owner_entry, boundary_offset)` keys,
allowing choices in the caller and callee without offset collisions. Every
variant selects each declared contract exactly once, including valid selections
that its path never consumes. The same selection policy accompanies prefix,
callee, suffix and whole-origin execution.

Optional V4 `bypass_variants` supply origin-state writes, selections, an exact
command-0E handoff observation, message count and expected state. Source audit
checks their typed/opaque bindings; runtime additionally checks that the primary
callee is neither dispatched nor executed. Caller state changes on such a path
are not callee completion evidence. V4 inherits V3's continuation/reentry
qualification and uses source/runtime report schema V4. V1/V2/V3 retain their
historical report identities; migration requires new origin, source bindings
and owner-qualified selections, rather than changing only the version string.

`kakyu_event_analysis_group/v5` extends V4 with required `source_binding` and
`record_sha256` on the local guard. This may retain a declared predicate span
inside an authoritative Python opaque tail. The typed origin must precede that
span, the independently checked record must be a condition with the declared
end and false target, and the prefix hash still covers origin through dispatch.
The runtime prefix must actually traverse the guard's accepting edge before
the selected caller coordinate. One-step guard witnesses alone cannot qualify
that arrival, and the source auditor does not promote the span to typed IR.

V5 uses the exact dispatch stop with the complete provider, which permits
inspecting a second call to the same callee after the first has returned. It
then checks prefix/callee/suffix against unbroken execution and preserves V4's
owner-qualified choices, bypass checks and per-variant reentry observations.
V5 source and runtime reports use their own schema; V1-V4 remain available with
their previous meanings and identities. Migration requires new source-bound
guard evidence and accepting-prefix execution, not only a new schema label.

`kakyu_event_analysis_group/v6` qualifies `root_replacement_observation` routes.
It retains V5's typed origin, source-bound guard and accepting-prefix proof, but
requires command-0E and `caller_outcome = {"kind":"root_handoff"}`. The target
starts at typed offset zero. `resume` and `expected_resume_state` claims are
rejected. The prefix ends at the actual root handoff; target execution carries
the full sandbox, and `follow_root_handoff` independently checks an unbroken
origin-to-target run against the combined prefix/target trace, messages and
written-value snapshot. There is no caller suffix.

Revision 2026-09-13 (owner ruling for `05M.MES:4706 -> EVENTL06.MES`): a V6
route may instead declare `caller_outcome = {"kind":"nested_root_handoff"}`
with a command-0F caller record. That names a nested call whose callee hands
the root on by its own command-0E handoff and never returns to the suspended
caller, so the caller's frame is discarded exactly as under a root handoff.
The audit binds the command-0F intro record and rejects the other pairing of
kind and command; the validator runs the prefix to the exact `stop_before_dispatch`
of that record, as a continuation's prefix does, and the unbroken run without a
`follow_root_handoff` request - the probe nests into the callee and the callee's
handoff terminates every suspended frame. Everything else (target from typed
offset zero, exact outcome and reentry records, `post_guard_expected`, no
`resume`) is unchanged, and `{"kind":"root_handoff"}` keeps its command-0E
meaning.

Revision 2026-09-19 (route toolchain, the 44M B14 group): the measurer replays
a nested route's completed reentry without the callee's answer, the way the
validator's post-continuation check does, and records a stop at an
undeclared routine-40 selection as a `def_selection_boundary` return
record (the resume stop's rule); the builder leaves a callee answer whose
run reached no terminal undeclared and names it under `unresolved` instead
of asserting; `qualify_event_route.py` is unchanged. The event-definition
batch driver resolves a registry row to a declaring profile by its site
evidence (caller entry, dispatch offset, callee entry) when the row lists
no group alias yet, so a group declared after the last registry rebuild is
projected without a new `names_fingerprint`.

Revision 2026-09-13 (route toolchain): a V6 root-replacement group is now
produced from one spec instead of per-route scripts. `tools/mes_route_decode.py`
renders a script range or a callee summary (gate, own-gate writes, doors,
dispatches, affection and stamp writes, counters, routine-40 question) from the
instruction-v45 handoff; `tools/draft_event_route_spec.py` turns a caller's
inventory (`analysis/<caller>_group_measure.json`) and that decode into
`analysis/<route>_spec.json` plus a review sheet - package, guard conjuncts and
cells, every gap write, a baseline seed inside every conjunct, one witness per
conjunct edge, guard-edge / presentation / counter variants, and `caller_choice`
or `callee_question` when a routine-40 record sits in the gap or the callee.
`tools/content_suite/cli/measure_event_route.gd` measures the spec (witnesses,
prefix / target / whole with `identical`, post-guard with guard-cell writes,
direct reentry, two-pass profile cells with `profile_cell_effects` on every row,
contracts, one block per callee answer); `tools/build_event_route_profile.py`
declares the profile from spec and measurement only (integers restored from
Godot's float JSON, opaque-tail bindings chosen from the handoff's
`opaque_boundaries`, per-variant reentry overrides where a row's reentry
differs, direct probes reported under `unresolved`, one route per callee
answer); `tools/qualify_event_route.py` runs probe, build, audit, validator and
the two mutations (a wrong callee message count must fail the validator on
"callee message observation count", a shifted door must fail the audit) and can
register the check; `tools/register_analysis_group.py` inserts the batch entry
after a named one and runs the focused check; `tools/refresh_route_classification.py`
regenerates the classification, reports newly bound and moved rows against
HEAD, and installs it. Verified against three hand-built groups: 19C L05
(278 checks by the tool, 280 by hand), 20C L16 (three answer routes, 440 /
485) and 05C I21 (the caller's contract, 414).

Revision 2026-09-13 (nested calls): the same toolchain declares a nested call
(command 0F, `form: nested_call` in the spec) as a caller-continuation group.
The probe runs the callee to its return record, then the caller from the
dispatch end on the returned state - with the same caller choices the
validator supplies to its suffix - to its natural stop, and classifies that
stop: a root handoff is `natural_handoff` (V5), a dispatch to a script outside
the package `stop_before_unprovided_dependency` (V5), the caller's own
routine-40 without a supplied choice `def_selection_boundary` (V8). The
post-guard truth and the reentry are read on the resumed state, as the
validator reads them; the callee-only readings stay under `after_callee`. The
builder declares `resume` (start at the dispatch end, the policy, the bound
stop record, the count, and the caller's completion effects split constant /
varying exactly like the callee's, since the validator checks the route-level
list on every variant's resumed state), each variant's `expected_resume_state`,
and drops any variant whose resume stops elsewhere or after another count (it
needs its own route). The driver names the profile by the measured policy,
adds a script the walk reaches outside the package to the members and
measures again (up to three rounds), and adds a third mutation: the resume
record shifted one byte must fail the audit. Verified on 46M J09 (V5, 443
checks), 43C M05 (V8, 182) and the six other nested intros of the one-intro
tier.

Revision 2026-09-13 (libai5 bridge): `tools/libai5_bridge/` builds a second,
external decoder (nunuhara's libai5, GPL-2.0, kept under `analysis/ext/`)
that parses every entry of the archive completely; `docs/spec/tech/libai5_bridge.md`
records what it agrees and disagrees with the Phase 1-4 decoder about
(command `0x0D` is one system call, not a separator).

Revision 2026-09-13 (Core 0.316.0, command `0x0D` as a system call): the owner
ruled for the decoder change. Both decoders (`tools/mes_partial_decoder.py`,
`content_core/mes_instruction_decoder.gd`) frame `0x0D` as a selector
expression plus the typed record list, keeping the confirmed presentation forms
as named instances and emitting `system_call` (with `system_function`) for
the rest; the archive decodes with zero opaque tails. The event runner executes
function 19 as the message wait and dialogue boundary (same resume offsets,
same message counts), function 14 as the name / literal insert, function 9 as
the MMO marker, and omits every other call and walks on. The route toolchain
is unchanged; walks that used to stop at `native_presentation_boundary` or
inside an opaque tail now continue, so 44M J11's second body is measurable.
The 23 profiles bound inside opaque tails were rebound as typed records and
the frozen GDScript digest regenerated (`config/mes_analyzer/README.md`); the
source audit binds a typed record under every schema now, so the two
historical V2 GROUND groups keep their bytes and hashes with the binding kind
moved.
Details and the survey figures: `docs/spec/mes/format_and_method.md`,
"Command `0x0D` is one system call".

Revision 2026-09-14 (Core 0.317.0, the caller's own loop): the owner ruled
for a caller-continuation boundary policy for a resume that ends in the
caller's interactive menu loop. `KakyuMesRouteProbe` proves such a loop on
request (`detect_loops`) by a repeated continuation and stops at its head;
`kakyu_event_analysis_group/v10` declares it as `caller_menu_loop` with the
head record, period, cycle rows and per-period message count; the audit,
validator, measurement probe, builder and driver carry the policy. The
first two groups are 15C C06 and 15C E11, each three routes by the callee's
answer, whose resumes had been measured into the shop's own menu loop at
`15C.MES:30516` on 2026-09-12 and left undeclared.

Revision 2026-09-14 (Core 0.318.0, map-location contracts): the owner ruled
for a general map-input contract with the train as its first case. The event
runner writes a declared location into `state_u16[18]` at a declared
`Util(6,13)` record (`map_location_supplied` in the trace) and otherwise
omits the record as before; `KakyuMesRouteProbe` carries the queues through
every frame of a run and reports what remains; `kakyu_event_analysis_group/v11`
and `v12` declare the contracts; the audit, validator, measurement probe,
builder, driver and drafter carry them. The three 01M train intros - H07,
M06 and M09 - are the first groups declared through it. Their callees'
stop, first recorded as a stream at `TRAIN.MES:861` and then as the
train's click loop, was the map module's location poll waiting for the
player to walk onto the platform and the train.

Revision 2026-09-14 (Core 0.319.0): a map-location contract names the
segmented run that spends it (`spent_by`: `prefix`, `callee` or `resume`,
with the unbroken run); the segmented chain carries one queue as the
unbroken run does, a reentry starts a fresh one, the measurement probe
reports each queue's remainder per run, the builder derives the declaration
and the validator checks that each named run consumes and that the chain's
last run and the unbroken run leave nothing. Absent, the callee run - the 0.318.0
reading - so the three train groups are unchanged. FLOOR4's A13 and L18 are
the first groups re-declared from the floor's own arrival on it.

Revision 2026-09-15 (a location's exit, declared as bypasses): the probe
reports where a turned-away walk ends (`prefix_terminal`, its state diff, the
scripts it executed, its profile-cell effects); the builder declares a walk
that leaves the caller by a handoff to a script the spec lists in
`bypass_targets` as a bypass variant (writes, selections, the exact handoff,
message count, the profile cells' values and every cell the walk changed) and
lists every other turned-away walk with its door or stop; the qualifier's
mutation D accepts the bypass marker and a mutation E raises a bypass's
message count, which must fail on "bypass message observation count". No
validator change - `_bypass_routes` has replayed bypasses under every anchored
schema since V4. The grounds' eight location-0 groups are the first to carry
derived bypasses (16).

Revision 2026-10-04 (Core 0.369.0, EP-12 v14 variant fields - the Event
Player's phrase for a callee return): `content_core/event_outcome_vocabulary.gd`
gains `matched_terminal_outcome(terminal, row_terminals)`, ported to
`tools/event_outcome_vocabulary.py`, and the Event Player's three outcome
phrases (the Analysis and Playback status lines of a group-route run and the
terminal result card) call it with the play request's `terminals`. A matched
`callee_return_only` terminal - the scene's own return, which
`catalog_terminal_outcome` reads as `continuation_undeclared` - is phrased by
the row's `catalog_route_outcome` whenever that is decided (not `unresolved`):
an album scene reads "Back to the place menu", a callee return that precedes a
declared map handoff reads that handoff, and a row that declares nothing after
the return keeps `Unresolved: continuation_undeclared`. Every other terminal
reads as before, and `catalog_route_outcome` / `catalog_terminal_outcome` are
unchanged, so the pinned route-outcome snapshot of
`tests/test_event_outcome_vocabulary.gd` is the unchanged external truth the
new function is checked against over all 214 tracked rows. The Core version
moves only because `content_core/` changed; no schema constant moved and
nothing tracked was regenerated by the unit (the package manifest folds in
`content_core_version`, so the tracked package still records `0.368.0` and the
next regeneration - the 12-menu unit - exports at `0.369.0`). The group-routes
validator's Playback pass now also asserts each row's status line ends with
that phrase (and `Back to the place menu` for every album scene). Rule table:
`docs/spec/data/event_outcome_vocabulary.md`.

Revision 2026-10-03 (no Core change, EP-12 date profiles at routine-40
contract v5): the nine `01m_<x>_date_v14` profiles B, C, E, F, G, H, I, J and
K carried `kakyu_mes_routine40_choice_contract/v4` choice contracts (no
`catalog_form`/`hidden_ids`/`hidden_gates`) although the toolchain has emitted
v5 since Core 0.366.0. They were regenerated with the unchanged chain
(`draft_date_flow_specs.py` -> `measure_date_flow.gd` ->
`build_event_flow_profile.py`, route order = `--spec` order: town, date5,
hotel; J gets only its town and date5 specs, its hotel stays measured, not
declared). The semantic diff against each committed profile is exactly the
choice contracts' `schema`, `catalog_form` (`contiguous` in all 96 contracts),
`hidden_ids` (`[]`), `hidden_gates` (`[]`) and `payload_sha256`; routes, hops,
message counts, options, baseline writes and seeds are identical, and the
regenerated v2 replays differ from the earlier ones in `payload_sha256` alone.
Profile `payload_sha256` is the identity the catalog rows
(`analysis_group.groups[].profile_sha256`, preset `notes`) and the v6 flow
documents (`evidence.groups[].profile_sha256`, `flow.evidence.profile_sha256`)
bind, so those moved with them: 26 catalog rows and 26 v6 flow documents
(8 x 3 + J's 2), `CATALOG_REVISION` 34 (rows still 189; registry, its
`names_fingerprint` and every other v6 field unchanged). The re-exported
package (membership unchanged, 189 events from 371 members) moved only the
nine group `payload_sha256` values, the 26 preset `notes` and its own hash
(`a4880971...`); all 189 v6 documents and the index re-projected against it
move `package_binding.package_sha256` (163 documents: that field alone). The
route classification (`tools/refresh_route_classification.py`) moved only
`analysis_group_evidence[].payload_sha256` on ten entries (the nine
`?_PIC.MES` rows and `TRAIN.MES`), its own `payload_sha256` and the
`catalog_sha256` rebind: no class or confidence moved. A's profile is
hand-authored, not reproducible by the template tool, and stays at v4 by
design; D and L were already v5. No Core version bump: no `content_core` code
changed.

Revision 2026-09-26 (Core 0.368.0, EP-12 leftovers - the probe's stop
detail): `content_core/mes_route_probe.gd`'s `_select_choice` used to
discard the live `def_selection_boundary` result on an unanswered choice,
reporting only `"no catalog choice at 0x%X in %s"`. A caller that wanted a
`kakyu_mes_routine40_choice_contract` for that exact boundary
(`tools/content_suite/cli/measure_date_flow.gd`'s `_build_contract`,
`tools/content_suite/cli/measure_event_route.gd`'s `_contract`) used to
re-run the routine from a bare resume coordinate instead, to get a fresh
`boundary_result` for `KakyuMesRoutine40ChoiceContract.build()`; that bare
re-run lacks the argument-slot/library context the live walk already
carries and can diverge into an unrelated `shared_routine_boundary` before
reaching the boundary the contract measures (found on D's own `?_HOTEL.MES`
site selector). The fix is at the source: `_select_choice`'s "no catalog
choice" stop now returns `kind: "unanswered_choice"`, `entry`,
`boundary_offset`, the live runner `result` (already the exact
`boundary_result` shape `build()` needs - the same value the accepted-choice
path just below it already passes), `code_size` and `source_identity`
(what `build()` needs of the binding); `run_route`'s own `stop_detail`
carries this through unchanged (it already duplicates whatever `_walk`
returns). Both `_build_contract` and `_contract` now build directly from
`stop_detail` when `kind == "unanswered_choice"` and the entry matches,
falling back to the documented bare re-run only when the stop carries no
such boundary (not observed on the twelve `?_HOTEL.MES` menus or a
ten-group ordinary sample this revision rebuilt and diffed for byte
identity before any profile changed). A second, independent gap the same
unit found while measuring L's own `?_DATE5.MES` open choice: `_build_contract`'s
own re-walk lacked the `poll_supplies` descriptor the route's own walk
already supplies for a `definition_invoke` wait, stalling on
`definition_step_limit` regardless of the stop-detail fix; `_build_contract`
(and `_contract`) gained a `poll_supplies` parameter, threaded the same way
`map_locations` already threads DENSHA.MES's train poll.

Revision 2026-09-25 (Core 0.367.0, EP-12 promises): a sparse-catalog
contract built from a playback-package code source records
`RANGE_UNAVAILABLE` as a hidden gate's `gate_condition_sha256` instead of
refusing the contract - the package exposes only definition bodies and the
whole code range, and the hash is an audit aid the archive-backed audit
always recomputes (`docs/spec/mes/format_and_method.md`). The version bump
records that `content_core` change, landed with the twelve promise groups.

Revision 2026-09-25 (Core 0.366.0, EP-12 routine-40 sparse catalog): the
callee-question blocker the same day's PROMIS revision below left open did
not need a new parser for the individually-gated declaration shape after
all. `content_core/mes_routine40_choice_contract.gd`'s `build()` bumped to
`kakyu_mes_routine40_choice_contract/v5` and now accepts a definitions list
that is strictly increasing but not contiguous (`0..max_id` with gaps, every
id inside `0..16`), recording `catalog_form` (`contiguous`/`sparse`),
`hidden_ids`, and per-hidden-id `hidden_gates` (the exact branch record a
static byte walk finds, identified by each candidate's own DEF selector
rather than position, so it also reproduces inside `validate()`'s
from-scratch rebuild). Measured live, `A_PROMIS.MES:2221`'s own fifteen-place
picker registers ids `0..7,9..13` under the location-0 baseline (date
`0401`; `hidden_ids: [8]`); its consumer at `2236` is the unmodified plain
one-based chain - no consumer-side change was needed, since that chain only
ever matched sequential result positions `1..N`, never the definitions' own
ids. `tools/audit_event_analysis_group.py` independently re-derives the
sparse fields from the archive. The 182 stored `v3` contracts and any `v4`
contract stay valid unchanged (`original event analysis groups`: 161/161;
`original HOTEL menu routine-40 redirect contract`: 12/12;
`original catalog group routes`: 4/4 shards). See
`docs/spec/mes/format_and_method.md` (the v5 schema paragraph) and
`docs/spec/mes/promise_groups.md` (the toolchain-gap resolution).

Revision 2026-09-25 (EP-12 PROMIS, a callee with two questions, landed): a
`nested_call` route whose callee has an earlier, undeclared `routine-40`
before the one `--question-offset` names now measures instead of hanging.
`draft_event_route_spec.py`'s `callee_question` scopes its `definitions` to
the span after the previous `routine-40` (if any); a new
`callee_prefix_choices` list (one fixed `{boundary, result_value}` per
earlier site) is drafted alongside it - `result_value: 3` by default
(registration position, not definition id; measured for `A_PROMIS.MES:2221`:
position 1/id 0 plays its own dialogue then loops back to the same boundary
with id 0 now hidden, position 3/id 2 reaches the declared question in one
pass and is the archive's own already-Confirmed "location 2" baseline).
`measure_event_route.gd` folds those into the same `caller_choices` every
run already consults, forwards that list into the callee's own
contract-discovery walk in `_contract()` (a previously dead `if entry ==
callee and not caller_choices.is_empty(): pass` branch - inert for every
existing caller-choice-only group), and captures each prefix choice's own
contract before answering it (`callee_prefix_contracts` in its output).
`build_event_route_profile.py` binds each of those into
`choice_contracts`/`selections` the same way a `caller_choice` already is,
so the runtime validator replays the same fixed answer. Combined with the
sparse-catalog fix above (Core 0.366.0), all twelve `01m-<letter>-promis`
groups now probe/build/audit/validate/mutation-test/register end to end (A:
7 of 10 routes, options 8-10 measured to not reach a terminal without A's
own latch and named unresolved; B..L: 10 of 10). `register_analysis_group.py`
needed its own fix: it still edited the pre-TD-32 tuple table in
`run_headless_validation.py`, which the checks-as-data migration removed; it
now inserts an `analysis_group`-family entry into `config/validation/checks_v1.json`
directly. Verified: `original event analysis groups` 173/173 (12 new),
`original catalog group routes` 4/4 shards, `original playback package
export`/`...playback` passed (175 rows, unchanged), each new `original event
analysis 01M <LETTER> promise` check individually (829-1,078 checks per
heroine, 0 failures), local-tier suite 134/135 (the one exception is
Checkpoint B's reverted registry regeneration, below - not this fix). See
`docs/spec/mes/promise_groups.md`.

Revision 2026-09-25 (EP-12 PROMIS, Checkpoint B measured and reverted):
registering twelve new analysis groups moves `tools/build_event_names.py`'s
`EXPECTED_PAIR_COUNT` (142 -> 154) and the event name registry (twelve new
`<heroine>.town.station.promis.1` ids) - regenerated cleanly and then
reverted, not committed, because completing it safely needs two more steps
this unit could not complete. First, `tools/promote_analysis_groups.py`'s
ordinary (non-flow) catalog-row path reads a `config/event_definitions/v4/<id>.json`
document per site; a genuinely new site's v4 document is new content, not
the sanctioned names_fingerprint carry, and `config/event_definitions/v4/`
stays frozen beyond that carry - so no catalog row, package export, or v6
document could be produced for the twelve PROMIS sites. Second, the
names_fingerprint carry into the 142 *existing* v4 documents
(`project_event_definitions_batch.py --contract v4`, no `--only`) came back
lossy against a freshly exported package: the fresh package's own
`package_sha256` differs from the one the tracked documents recorded, so
every `shift_witness`-dependent effect that needed it read "no matching
shift witness" instead of its recorded value, rather than reproducing byte
for byte. No cached reference package export exists to diff against and
find the discrepancy. The registry and `EXPECTED_PAIR_COUNT` were reverted;
`tests/test_event_names_registry.py::test_regeneration_is_byte_identical`
fails with a precise, self-diagnosing `BuildError: premise mismatch:
expected 142 distinct (callee, caller) pairs, measured 154` naming exactly
the unfinished step, left in the local suite deliberately. `tests/test_event_outcome_vocabulary.py`'s
`PinnedCensusTest` did move (`test_profile_routes_census` map_return 212 ->
329, `test_profile_reentries_census` not_triggered 143 -> 260, +117 each -
one per declared PROMIS route), since those counts read the analysis-group
profiles directly rather than the registry/catalog. See
`docs/spec/mes/promise_groups.md`, "Checkpoint B".

Revision 2026-09-25 (EP-12 PROMIS, Checkpoint C, both Checkpoint B blockers
resolved): (1) `tools/promote_analysis_groups.py`'s document source is now
the *live* v6 definition set by default (`--definitions-dir`, alias
`--v4-dir`, default `config/event_definitions/v6`) rather than the frozen
v4 - v6 is a superset of v4's shape and this tool reads only v4-shape
fields, proved byte-identical for the 175 pre-checkpoint rows before any new
one was added (`load_v4_documents` skips a v6 document's own `flow` block,
which `generate_flow_rows` already promotes separately). *Note, 2026-10-08 (WD-21 U2 C5):* the
default is now the live **v7** set (`config/event_definitions/v7`); the promoter refuses a definitions
directory that is not v7, because a v6 set would regress every row's `resources` to `[]`, and
`--check` reproduces the revision-41 catalog byte for byte. (2) The
names_fingerprint carry into v4/v5 is a field patch of that one line in
every document and index (as the 2026-09-24/2026-09-25 checkpoint-B-era
revisions already did), never a re-projection; the earlier `--contract v4`
attempt was diagnosed as the wrong operation. A genuinely new *ordinary*
site's own document still cannot come from v4 (no v4 document exists to
carry), so it is produced as v6 directly - which needs its own callee's
package member, which needs a catalog row, which needs the document: a
circular order no ordinary site's tooling had hit before (a flow route's row
and document both come straight from its profile, never the package).
Resolved by a new, scratch, explicitly opt-in export option,
`--include-unbound-groups`
(`tools/content_suite/playback_package_export.gd`/`export_playback_package.gd`):
threads an empty `events` list through to `analysis_group_members` for
group membership alone (its own already-existing unrestricted-scan behavior
for that argument), while `catalog_members` still reflects the real
selected events - inert for every existing caller, verified
(`tests/test_playback_package.gd`, 72/72 unchanged). Sequence: registry
regenerated (154 pairs) -> bootstrap package export
(`--include-unbound-groups`) -> the twelve v6 documents projected against it
(`project_event_definition_v6.py --site <id> --contract v6`, ordinary path)
-> catalog promoted from those twelve plus the 175 existing v6 documents
(`CATALOG_REVISION` 32, 187 rows) -> the *standard* package re-exported (no
bootstrap flag needed once the catalog referenced the twelve groups) -> all
187 v6 documents and `index.json` regenerated against it -> names_fingerprint
carried into v4/v5 as a field patch. A second, independent gap then surfaced
in the *playback-package-only* replay path (not the archive-backed one this
checkpoint's own toolchain uses) - `docs/spec/mes/format_and_method.md`'s
own checkpoint-C addendum has the full account
(`mes_routine40_choice_contract.gd`'s gate-hash fix, no package schema
change). Every pin moved: `tools/build_event_names.py`
(`EXPECTED_PAIR_COUNT` 154, `EXPECTED_CATALOG_COUNT` 187),
`tools/promote_analysis_groups.py` (`CATALOG_REVISION` 32),
`tests/test_promote_analysis_groups.py` (175 -> 187 rows),
`tests/test_event_outcome_vocabulary.py`'s `test_catalog_rows_census`
(map_return 143 -> 155) and its GDScript sibling's snapshot table (187
rows), `tests/test_event_catalog.gd`/`test_event_player.gd` (175 -> 187 and
the mahoko/maki character-filter counts +1 each), `tests/test_playback_package.gd`
(175 -> 187). Validation: local tier 135/135; with the archive, `original
event analysis groups` 173/173, `original catalog group routes` 4/4 shards,
`original Event Catalog source bindings`, `original Event Player fragment
catalogs`, `original playback package export`, `original playback package
playback` (187 rows: 164 reached a terminal, 20 place-menu, 3 chain, 0
stopped). See `docs/spec/mes/promise_groups.md`, "Checkpoint C", and
`config/contracts/event_names_v1/README.md` / `config/event_definitions/v4|v5|v6/README.md`
for the fingerprint-carry ledger.

Revision 2026-09-18 (Core 0.346.0, publication lock under load): with every core
busy the multi-process scene failed 17 of 22 runs - a death judgement applied
to the lock's next owner, a two-step release that could leave an ownerless
lock directory, and an unreadable age read as old. The takeover re-verifies
the judged token before and after the rename and respects a young record,
release is one rename, and `tests/test_publication_lock_rules.tscn` fixes the
rules. Verified 2026-09-18: with every core busy the multi-process scene passed 28 of 28 runs (17 of 22 failed before), `tests/test_publication_lock_rules.tscn` (12 checks), the lock, project, workspace and liveness scenes unchanged, the local batch (124 checks), and the ten original checks that publish into a workspace or read one plus an Event Player check, 11 of 11.

Revision 2026-09-18 (Core 0.345.0, WD-15 display): the Event Player stretches a
fixed 1280x800 canvas with its window - aspect kept when windowed, not kept in
borderless fullscreen (F11, Alt+Enter, toolbar `Fullscreen`; remembered per
app) - and the five reflowing apps take a DPI content scale factor with a
scaled minimum size. Verified 2026-09-18: `tests/test_tool_window_display.tscn` (31 checks), the Event Player scene (1,288, with the toggle, F11, Alt+Enter and a scratch config), `tests/test_app_window_sizes.tscn` (54: four sizes for six apps and three DPI factors for the five reflowing apps), the Launcher scene (41), the local batch (124 checks), and the original `selection handoff` and `Event Player EVENTB03 zero-state choice analysis` checks; a probe showed one `dpi_changed` connection after three applies and the factor re-applied when the signal fires.

Revision 2026-09-18 (Core 0.344.0, WD-17 multi-process publication): the
publication lock decided an owner's death with `OS.is_process_running`, which
answers only for the caller's children, so tools that did not start each other
stole each other's live locks (measured: overlapping holders, a false failure
after a successful write, one lost record). `content_core/process_liveness.gd`
asks the operating system instead and the lock, the overlay package and the
project use it; `tests/test_workspace_multiprocess.tscn` drives a workspace
from concurrent, stale, killed and sibling processes. Verified 2026-09-18: `tests/test_workspace_multiprocess.tscn` (51 checks) ten times in a row with real contention each time (about ten attempts for four publishers), `tests/test_process_liveness.tscn` (13 checks, two stranger processes), the lock, project and workspace scenes unchanged, the local batch (121 checks), and the ten original checks that publish into a workspace or read one - the four contextual authoring checks, package export and playback, and the MES Editor, ARC Browser, Audio Editor and selection handoff integrations - 10 of 10 in 724 seconds.

Revision 2026-09-18 (Core 0.343.0, WD-16 large-archive extraction):
`tools/content_suite/arc_batch_extraction.gd` runs a batch as a stepped job
(`begin`, `step(budget_msec)`, `progress`, `cancel`, `is_done`, `result`);
the static functions run the same job to the end. The ARC Browser and the
Audio ARC Editor step it from `_process`, show progress and
`Cancel extraction` only while it runs, refuse conflicting actions meanwhile
and cancel on close; a cancelled job removes exactly the files it created.
On the original archives every other operation ends within four seconds and
peak static memory stays under 160 MiB, so nothing else is stepped.
Verified 2026-09-18: the batch extraction (48 checks), ARC Browser (97), Audio ARC Editor (111) and overlay (118) scenes, the local batch (119 checks), and on the real archives the `original ARC Browser original integration` check - a whole-archive job on `voice.arc` cancelled after 305 entries leaves no file, `bgm.arc` extracted by steps yields 52 entries with every SHA-256 equal to the reader's, peak static memory grew by 20 MiB against a 128 MiB bound, both source hashes unchanged - together with the unchanged `original Audio Editor original integration` check; the CLI extracts three real `mes.arc` entries (94,311 bytes) as before.

Revision 2026-09-18 (TD-05 Python payload helpers, no Core change):
`tools/payload_values.py` holds `canonical_payload_bytes`, `fingerprint`,
`is_sha256` and `sha256_file`; 71 tools import them under their old names
instead of defining them. The canonical JSON settings are unchanged, so no
stored `payload_sha256` moves. A new Python tool imports these instead of
copying them; a tool with a different canonical form keeps its own
function. Verified 2026-09-18: all 71 changed tools import, `tests/test_payload_values.py` (6 tests, including that two tools now share the very same function objects), the local batch (119 checks, Python 1,548), and the 29 original checks that execute Python tools - the full Phase 1-4 handoff equivalence, the four contextual authoring checks, package export and playback, the event analysis frontier and four analysis groups, the catalog analysis routes, the corpus inventory and every direct Python audit including the native ARC, MES and Ogg contracts - 29 of 29 in 2,159 seconds. The whole original run was last made for unit 2 (358 of 358).

Revision 2026-09-17 (Core 0.342.0, TD-05 headless script base):
`tools/content_suite/cli_script.gd` extends `SceneTree` with the failure
exit `_fail(message, code := 1)` and the bounded read `_read_bounded`; 81
scripts under `cli/` and `validators/` extend it by path instead of copying
both. A new headless script extends the base unless its `_fail` needs other
arguments, which GDScript's override rule forbids; such a script keeps
`extends SceneTree`. Verified: all 82 changed scripts load and instantiate, the local batch (119 checks, Python 1,542), and the whole original run with `--elfimage` and `--exe` - 358 of 358 checks in 7,362 seconds, the exhaustive MES entry audit skipped as before.

Revision 2026-09-17 (Core 0.341.0, TD-05 shared value checks):
`content_core/contract_values.gd` (`KakyuContractValues`) holds the pure
value checks the versioned contract modules used to copy - SHA-256 hashing
in its checked and unchecked form, the hash, key-set, JSON-integer,
all-true and hex checks. 258 private copies in 82 production scripts were
removed and their call sites rewritten; variants that differ in meaning
(bounded integers, typed keys, empty-input hashers) stay private, so no
contract changes what it accepts and no stored fingerprint moves. A new
contract module uses the shared checks instead of adding copies. Verified 2026-09-17: every changed script loads and instantiates (86 checked), `tests/test_contract_values.tscn` (46 checks), the local batch (119 checks, Python 1,542), and the whole original run with `--elfimage` and `--exe` - 358 of 358 checks in 7,428 seconds: 119 local, 228 original-archive, 12 native-executable, 8 native-with-archive and the voice payload check; only the exhaustive MES entry audit was skipped.

Revision 2026-09-17 (Core 0.340.0, WD-03 raw replacement staging): the ARC
Browser stages one raw file as the replacement of one existing entry into
the named workspace (`tools/content_suite/raw_replacement_staging.gd`):
bounded size, never identical to the original, format-gated where a
validator exists (MES/LIB, WAV/OGG, AX, A6, MMO) and labelled unvalidated
otherwise, always `remake_only`, target archives only. Verified 2026-09-17: the raw staging (17 checks), ARC Browser (86), workspace (34) and overlay (118) scenes, the local batch (118 checks), the original ARC Browser archive check, and a read-only probe offering every real entry of `mes.arc`, `data.arc`, `mmo.arc`, `se.arc` and `bgm.arc` as its neighbour's replacement (1,014 MES, 527 AX, 11 A6, 1,721 MMO and 99 audio entries validated, 128 staged as opaque; the only refusals were 198 byte-identical neighbours); Python untouched (1,540).

Revision 2026-09-17 (Core 0.339.0, WD-05 specialist-editor handoff): the ARC
Browser opens its selected entry in the owning specialist editor through
the selection contract (`KakyuSelectionHandoff.specialist_for` routes by
archive); the Image and Animation ARC Editor and the Audio ARC Editor now
receive selections (the selection's archive opens, the entry is verified
against its original hash and selected). Verified 2026-09-17: the selection (27 checks), ARC Browser (77), Image and Animation ARC Editor (167), Audio ARC Editor (100) and MES Editor (158) scenes, the selection handoff archive check extended to the real `data.arc` (`A01.AX` selected with its AX inspector) and `se.arc` (`KSE0031.WAV` validated), the local batch (117 checks); Python untouched (1,540).

Revision 2026-09-17 (Core 0.338.0, WD-01 ARC comparison): the ARC Browser
compares the open ARC with another ARC or with its loaded overlay through
`tools/content_suite/arc_comparison.gd` (index order, case-insensitive
names, whole-entry hashes; the overlay side re-hashed and fail-closed),
shows the rows in a differences-first panel and exports
`kakyu_arc_comparison/v1` (`docs/spec/data/arc_comparison.md`);
`cli/compare_arcs.gd` is the headless form. Verified 2026-09-17: `tests/test_arc_comparison.tscn` (47 checks), the ARC Browser scene (70), the ARC Browser archive check (the real `mes.arc` compared with itself: 1,016 identical rows, order preserved), the CLI on the same archive (0.4 s), the local batch (117 checks); Python untouched (1,540). The compare buttons live on a third toolbar row so the window still fits 1024x640.

Revision 2026-09-17 (Core 0.337.0, WD-07 workspace dashboard): the Launcher's
**Dashboard...** panel renders the re-verified provenance statement of the
open workspace (project revision and objective, core range, generation
hashes, bound archives, replacements and projections with their
compatibility and linked proofs, verification counts), fails closed on a
changed payload and exports the same statement. Verified 2026-09-17: `tests/test_workspace_dashboard.tscn` (42 checks: rendered blocks, the fail-closed changed blob and its recovery, export and refused re-export, the core range helper), the Launcher scene (41), the provenance report scene (31), the local batch (116 checks); Python untouched (1,540).

Revision 2026-09-17 (Core 0.336.0, WD-09 selection handoff): the versioned
`kakyu_content_selection/v1` document (`content_core/content_selection.gd`,
contract `docs/spec/data/content_selection.md`) travels through the new
`--selection` launch argument and `tools/content_suite/selection_handoff.gd`;
Event Player, the MES Editor and the ARC Browser receive it, the Audio ARC
Editor produces it from a confirmed MES reference (ME-05's Event Player
half). Verified 2026-09-17: `tests/test_content_selection.tscn` (22 checks), the launch context (24), Event Player run-request/selection (18), MES Editor (158), ARC Browser (57) and Audio ARC Editor (93) scenes, the new `selection handoff original integration` archive check (`EVENTB15.MES` opened from a selection with its catalog event `original/eventb15/11m-0000347b` and preset `daytime-original` selected, playback inactive, sources unchanged), the Audio Editor archive check, the local batch (115 checks); Python untouched (1,540).

Revision 2026-09-17 (Core 0.335.0, ME-06 audio batch and report): the Audio ARC
Editor extracts several selected entries or the complete audio archive
through the shared batch extractor (pending session replacements included
through descriptor overrides) and exports the portable
`kakyu_audio_metadata_report/v1` (`tools/content_suite/audio_metadata_report.gd`,
contract `docs/spec/data/audio_metadata_report.md`). Verified 2026-09-17: `tests/test_audio_metadata_report.tscn` (37 checks), the audio editor scene (86), the batch extraction and ARC Browser scenes (24, 54), the Audio Editor archive check (three `se.arc` entries and the complete archive of 87 entries and 22,923,742 bytes extracted with hashes verified; the `bgm.arc` report of 52 entries, 50 of them with confirmed MES references), the local batch (114 checks); Python untouched (1,540).

Revision 2026-09-17 (Core 0.334.0, ME-02 AX timeline editor): the Image and
Animation ARC Editor edits the selected AX cell's commands (replace,
insert, remove, reorder; loop, reset, stop and dispatch from the confirmed
subset, the other controls as raw values) and any shared record's type,
source crop and destination through the AX writer, previews the edited
animation on the tool clock, and stages the written AX into the replacement
session with its write audit. Verified 2026-09-17: the image editor scene (160 checks, the synthetic `A01.AX`: record and command edits, reorder, refusals, staging with the audit, overlay save and reload, revert, the 1024x640 fit), the AX writer scene (22), the Image Editor archive check (a record edit staged, reopened and audited on `A01.AX`, `ax_edit_staged=true`), the AX corpus check (630 no-op, 10 edits), the local batch (113 checks); Python untouched (1,540).

Revision 2026-09-17 (Core 0.333.0, ME-03 AX writer): `content_core/ax_writer.gd`
serializes the inspected AX structure byte-identically over the whole
`data.arc` corpus, edits one cell stream or one shared record by
serialize-and-reinspect, reopens through the three AX readers and binds the
change in `kakyu_ax_write_audit/v1`; the AX corpus check proves the no-op
and a one-byte stream edit on ten entries; the image editor reports the
round trip. See "AX Read-Only Binding Table and Dword Boundary".

Revision 2026-09-17 (Core 0.332.0, WD-04 provenance report): the Launcher
exports a portable, path-free, fingerprinted provenance report of the open
workspace (`tools/content_suite/provenance_report.gd`, contract
`docs/spec/data/provenance_report.md`; headless
`cli/export_provenance_report.gd`) that re-verifies the bound source
archives, every replacement blob and projection file, and links each
replacement to its reopened authoring bundle, with a compatibility summary
against the project objective. Verified 2026-09-17: `tests/test_provenance_report.tscn` (31 checks), the Launcher scene (37), every authoring scene and the original EVENTB03 edited-event and sequence archive checks (the report links the published bundle after each publication), the local batch (112 checks), the Python regression unchanged (1,540); a workspace created against the real ELFIMAGE reports its eight bound archives.

Revision 2026-09-17 (Core 0.331.0, WD-02 batch extraction): the ARC Browser
extracts several selected entries or the complete archive into a folder
through the new `tools/content_suite/arc_batch_extraction.gd` (safe unique
names, every entry resolved and every destination absent before the first
write, in-order streaming through the resolver, rollback of the batch's own
files on failure), with a headless `cli/extract_arc_entries.gd`. Verified 2026-09-17: `tests/test_arc_browser.tscn` (54 checks: multi-select, folder batch with per-source counts, refused repeat with nothing written, whole-archive extraction under an active filter, the window fit of both toolbar rows) and the new `tests/test_arc_batch_extraction.tscn` (24 checks on a synthetic three-entry ARC with one overlay replacement: rows, sources, hashes, refusals and the rollback when a destination cannot be published) pass, the local batch reaches 111 checks, and the Python regression (1,540 tests) is untouched.
On the real `mes.arc` the ARC Browser check batch-extracts `START.MES`, `DEF_MAIN.MES` and `LIBLARY.LIB` and then the complete archive (1,016 entries, 18,617,388 bytes) with every hash verified and the source unchanged (4 s). The CLI extracts the same three entries (94,311 bytes) and the whole archive in about 3 s.

Revision 2026-09-17 (Core 0.330.0, step 5 - every family and every sequence
through contextual Run and the package export): `mes_contextual_run.gd` binds
a same-size v2 proof of any family by identity (`bind_same_size_edit`, the
state family keeping its literal re-decode) and a stepped v9 bundle through
its chain proof (`bind_chain`, the bundle's step-by-step source check;
binding `kakyu_mes_contextual_run_binding/v3`); the workspace export and its
headless entry point pass the reopened bundle beside the proof; the package
integrity validator accepts binding v3; the editor's proof lookup accepts
chain proofs and maps translations through the stepped bundle. Two original
EVENTB03 archive checks are added (resource name; a two-step sequence).
Contract: `docs/spec/data/workspace_playback_export.md`.

Revision 2026-09-17 (Core 0.329.0, MW-11 operation sequences): an authoring
bundle is now an ordered sequence of operations compiled as a chain (step k
on step k-1's re-analysed output; same-size steps keep every coordinate, a
message relocation only last), with `sequence.json`, per-step `step-NN.*`
members and the chain proof `kakyu_mes_semantic_diff_chain/v1`
(`tools/diff_mes_sequence_semantics.py`, `content_core/mes_semantic_diff_chain.gd`)
as the top-level proof of a multi-step bundle; one-step bundles keep the
v8 layout. The Authoring tab gains the proposed-operation list (add,
remove, clear, preview in order with per-step status, publish). Delta v9
carries `operations`. Contextual Run and package export of multi-step
bundles are TODO step 5. Contracts: `docs/spec/data/mes_authoring_bundle.md`
(Version 9) and `docs/spec/data/authored_mod_delta.md`; scenes
`tests/test_mes_sequence_authoring.tscn`, `tests/test_mes_semantic_diff_chain.tscn`.

Revision 2026-09-17 (Core 0.328.0, MW-11 control targets): the MES Editor
Authoring tab exposes an eighth edit family, the u32 target of a
`branch_if_not_true` false branch or a `continuation_transfer`
(`retarget_control_flow`), over the existing control-target planner,
compiler and reopen validator. One candidate per typed transfer with one
exact reference; the replacement offset is edited in the numeric control
and must be a unique typed instruction start, which the workflow binds by
hash before planning. Bundle v8 adds `control_target_controls` to the
summary; delta v8 admits the operation with no dependency. Contracts:
`docs/spec/data/mes_authoring_bundle.md` (Version 8) and
`docs/spec/data/authored_mod_delta.md`; scene
`tests/test_mes_control_target_authoring.tscn`.

Revision 2026-09-17 (Core 0.327.0, MW-11 shared-routine calls): the MES Editor
Authoring tab exposes a seventh edit family, the 8-bit routine id of a
shared-routine call (`replace_shared_routine_literal`), over the existing
shared-call return proof, planner and compiler. The library audit of
`LIBLARY.LIB` that the proof needs is built on the Godot side by the new
`tools/content_suite/mes_library_audit_report.gd` (shared with the
decompiler handoff spool exporter) before `inspect` and before a delta
reconstruction, and handed to Python as `--library-audit`; the bundle keeps
it as `library.audit.json` (bundle v7), the delta names `LIBLARY.LIB` in
`dependencies` (delta v7). Contracts: `docs/spec/data/mes_authoring_bundle.md`
(Version 7) and `docs/spec/data/authored_mod_delta.md`; scenes
`tests/test_mes_library_audit_report.tscn`,
`tests/test_mes_shared_call_authoring.tscn`.

Revision 2026-09-17 (Core 0.326.0, MW-11 registered-definition calls): the
MES Editor Authoring tab exposes a sixth edit family, the 8-bit selector of
a registered-definition call (`replace_registered_definition_literal`), over
the existing call-family proof, registry proof, planner and compiler. The
bundle (`kakyu_mes_authoring_bundle/v6`) may carry the archive's
`DEF_MAIN.MES` registry proof as `registry.proof.json`, built by `inspect`;
the delta (`kakyu_authored_mod_delta/v6`) names the original entries a
reconstruction needs (`dependencies`) and the CLI loads them from the
archive. The shared-routine call family waits for a Godot-produced library
audit and follows separately. Contracts: `docs/spec/data/mes_authoring_bundle.md`
(Version 6) and `docs/spec/data/authored_mod_delta.md`; scene
`tests/test_mes_registered_call_authoring.tscn`.

Revision 2026-09-16 (Core 0.325.0, MW-11 choice options): the MES Editor
Authoring tab exposes a fifth edit family, same-length choice-option texts
(`replace_choice_option_cp932_same_length`) over the existing choice-group
proof, planner and compiler; the lister decodes an entry once and proves
only the address entries that carry a routine-40 group clear (today the
town date menu `43C.MES` entry 148). Bundle `kakyu_mes_authoring_bundle/v5`
(summary `choice_controls`; v1-v4 readable), delta
`kakyu_authored_mod_delta/v5` (minimum core 0.325.0; a per-version table of
admitted kinds keeps v1-v4 readable). The session's per-schema source table
names the audit section (`patch` for this family). Two latent defects were
closed on the way (TD-31): the byte-patch semantic diff compared source
identities including `source_kind`, which the choice-group proof never
carries, so no choice proof could be built from a real authoring model; and
the candidate lister consults the grouped-route decoder only when the model
holds a group clear, since that decoder requires the address-entry prologues
that synthetic fixtures of the other families lack. Contracts:
`docs/spec/data/mes_authoring_bundle.md` (Version 5) and
`docs/spec/data/authored_mod_delta.md`; scene
`tests/test_mes_choice_authoring.tscn`.

Revision 2026-09-24 (Core 0.362.0, EP-13): two rules from a census over every
analysis-group row's default run (`142` rows; the log is scratch, not
tracked). Part A (stills): `content_core/event_presentation_timeline.gd`
classifies an `mmo_resource_marker` row by its confirmed
`native_active_surface_value` (`banked_u16[0][1]`), not by the loading
script's file name - surface 8 (277 loads, all `*an.mmo` animation atlases)
is an animation source, joining `step.animations` with `ax_resource_marker`
rows (277 loads) and never drawn in Playback; surface 2 from a `*_PIC.MES`
script (139 of surface 2's 332 loads) is a standing picture
(`visible.foreground`); surface 1 (58 loads), surface 9 (1 load) or surface 2
from any other script (193 loads) is the base picture
(`visible.background`). A row with no surface value keeps the old file-name
rule and is additionally listed in a new `unclassified_pictures` list for the
Analysis evidence. Every `pictures` entry carries `surface` and `role`
(`base`/`standing`/`unclassified`); every `animations` entry carries
`surface`, `role` (`animation_source`) and `resource_kind` (`mmo`/`ax`, so a
caller resolves an AX resource in `data.arc` and an animation atlas in
`mmo.arc`). The Event Player's `_apply_timeline_step` now compares a step's
`visible` snapshot against what is actually on screen
(`_preview_displayed_visible`), not the previous timeline step's snapshot -
comparing against the previous *step* broke stepping backwards, which
applies the target step directly and would otherwise compare it against the
step two behind it; a background change also always re-presents the current
foreground, since `_present_mmo_resource` clears the foreground layer when
it redraws the background surface. The foreground chroma key stayed the
existing tolerant shader (`shaders/legacy_green_chroma_key.gdshader`,
already keying an exact `0x00FF00`, `Color(0, 1, 0)`, with a soft threshold);
no evidence of green retention on a standing picture was found in the
Playback pass below, but a full visual audit of every standing picture was
not performed. Part B (one step per spoken line): a step is now the run of
message records between two `dialogue_boundary` rows (the click waits), not
one record - `step.messages` (each record in order, with its `dynamic_kind`
where present) replaces one-record-per-step; a compatibility `step.message`
(the first record) is kept for callers that have not moved. Grouping walks
`trace` in encounter order and takes the next queued `messages` entry
whenever a `message`, `literal_text_insert` or `protagonist_name_insert` row
is seen (not by matching a message's own offset back onto its trace row,
which does not work for `literal_text_insert` - its message carries its
nested text record's own offset, not the enclosing instruction's).
Protagonist-name inserts: 2,653 over all 142 rows; 2,614 are exactly `text
record, name insert, text record, click wait`. The Event Player's
`_play_group_route` reports a `dialogue_boundary_count` alongside
`step_count`; `_resolve_step_presentation` concatenates each record's own
`_resolve_message_presentation` text (an unresolved name insert still shows
its placeholder). `validate_catalog_group_routes.gd`'s Playback pass now
pins step count to `dialogue_boundary_count` (+ closing) instead of the
message count, resolves every step's every record, counts pictures by role
and reports animation sources separately. EVENTB03's default option
(`01m-b03-result1-baseline`): 89 message records grouped into 90 steps
before this change, 51 `dialogue_boundary` rows grouped into 52 steps (51
lines + 1 closing) after. Verified 2026-09-24: `tests/test_event_presentation_timeline.tscn`
re-pinned and extended (54 checks: the line-grouping/collection run, the
cumulative-pictures run and a dedicated surface-role run covering surfaces
8/2/1/9/`_PIC`/missing); the local batch (`--tier local --jobs 4`, 134 of
134); with the archive, `original catalog group routes` (4 shards, 13,203
checks, 221 group-route runs, 142 Playback runs: pictures 385/391 found by
role - 246 base, 139 standing, 6 missing all `base` - animation sources
546/554 found, voices 1,665/1,665, BGM 528/528, 0 unknown effects, 21 visit
preset runs) and `original Event Player fragment catalogs`. A headless
frame-capture probe confirmed the `--headless` build's dummy rendering
driver returns a null `Texture2D` image (`texture_2d_get` errors "Parameter
"t" is null""), so the three requested EVENTB03 PNG frames could not be
exported from this environment; an earlier version of that same probe that
awaited `RenderingServer.frame_post_draw` (a signal that does not fire under
`--headless`) hung indefinitely and, since this task's instructions forbade
killing processes, its process could not be confirmed exited.

Revision 2026-09-21 (Core 0.359.0, TD-32 part 3): a green result is reused
while its inputs are unchanged. `tools/content_suite/validation_inputs.py`
computes each check's inputs by a static dependency scan (the closure of
`res://` literals, class-name references, scene resources, Python imports
and path literals from the check's script; a directory literal brings its
files, a non-literal `load(` widens the closure to the shared scripts,
the parse check and the Python suite take the whole tree) and a
fingerprint over the Core version, the normalised command, the files'
hashes and the archives' and executable's hashes (`--fingerprints`,
`--fingerprint-inputs`; the full plan fingerprints in about 4 s).
`tools/content_suite/validation_cache.py` keeps green results under
`analysis/validation_cache/` by fingerprint (never a red one), engaged
only when asked: `--cached` reads and writes - a stored green result is
reported as a `cached: true` row without running it and the
analysis-group family collapses over the misses only - and
`--cache-store` writes without reading; `--cache-dir` and `--cache-clear`
manage the store. The report is
`kakyu_content_tools_validation/v5` (cached rows, the `cached` count,
`cache` and `cache_dir` in the context; v4 and v3 load); since 2026-09-23
(TD-33) `kakyu_content_tools_validation/v6`, which adds `jobs` to the
context for `--jobs N` parallel runs (`docs/spec/data/validation_checks.md`,
"Parallel checks"). Contract:
`docs/spec/data/validation_checks.md`. Verified 2026-09-21: the full plan (361 checks with the archive) fingerprints in 3.7 s (inputs min 8 / median 35 / max 2,288 - the Python suite and the project parse check by design; one unresolved reference, a deliberately absent scene in a fixture; one dynamic load, the window-size scene iterating every app scene); `--tier local --cache-store` 134 of 134 in 249 s, then `--tier local --cached` 134 hits in 1.1 s; after touching one shared script (`content_core/event_presentation_timeline.gd`, restored byte-identical) 112 hits and 22 re-runs (the parse check and the 21 scenes whose closure reaches it) in 58 s; `--cached --check "original event analysis groups"` 149 of 149 stored in 493 s, then 149 hits in 0.9 s with no process run; `tests/test_validation_inputs.py`, `test_validation_cache.py`, `test_run_headless_validation.py` and `test_validation_report.py` (83) and `test_validation_report.tscn` (64, the panel included); the Python suite; the parse check; the pre-commit review's findings fixed.

Revision 2026-09-21 (Core 0.358.0, TD-32 part 2): the analysis-group checks
run in one Godot process. `tools/content_suite/event_analysis_group_validation.gd`
(`KakyuEventAnalysisGroupValidation`) holds the per-profile validation
that `validators/validate_event_analysis_group.gd` used to do in `_init`
(the Python exact-source audit, the archive identity, the member parses,
the probe context, the route runs and the canonical report with its
`payload_sha256` - unchanged byte for byte); the single CLI calls it, and
the new `validators/validate_event_analysis_groups.gd` calls it for a list
of profiles on one open `mes.arc`, printing one block per group and a
`GROUPS_SUMMARY` line (`kakyu_event_analysis_groups_run/v1`). The runner
collapses the `analysis_group` member checks left after `--check` into one
process check declared by the registry's `families` block (revision 2:
name, script, `process_timeout`, groups, tier) and reports one v4 row per
member - passed / failed with the group's own output tail, `timeout` or
`error` for members the process never reached. The per-group cost had
been the Python exact-source audit (6-10 s per profile: the member
entries' handoffs rebuilt for every profile), so
`tools/audit_event_analysis_group.py` gained `--profiles` /
`--profiles-file` (one process, a per-entry handoff cache, one JSON line
per profile) and the multi-profile CLI audits all its profiles once and
passes each result into `validate(..., audited)`; the single CLI's
output is byte-identical either way. Verified 2026-09-21: the single validator's canonical report JSON for five profiles (GROUND H01 H02, 01M B03, 12C D14, 44C M10A, 01M H07) byte-identical between the HEAD script, the refactored single CLI and the multi-profile process, with the Python audit's own reports byte-identical between `--profile` and `--profiles`; `--check "original event analysis groups"` over all 149 profiles: 149 of 149 in 614 s on an otherwise idle machine (part 2 alone, before the batched audit: 1,415 s; the 140 separate processes of 2026-09-19: 1,570 s; the 488 s of the first batched-audit run was measured before the review's fixes), median member 2.2 s (8.6 s before; the archive hash costs 42 ms, the rest is the route runs); one member alone 0.8 s; the Python suite (1,786) with `tests/test_run_headless_validation.py` (36: the collapse, the per-member parse with a script error isolated to its member, the family name refused when no member is planned, `main` end to end), `tests/test_validation_registry.py` (29) and `tests/test_event_analysis_group.py` (69: the cache equal to the uncached audit, the cache reused across profiles and never across archives, the `--profiles` lines); the `--profiles-file` fallback byte-identical to the direct form; the parse check; `--tier local` 134 of 134; the pre-commit review's findings fixed.

Revision 2026-09-21 (Core 0.357.0, TD-32 part 1): the validation checks are
data. `config/validation/checks_v1.json` (`kakyu_validation_checks/v1`)
carries every check of `tools/content_suite/run_headless_validation.py` -
name, kind (`python`, `godot_editor`, `godot_scene`, `godot_script`),
script, arguments with placeholders, timeout, coverage groups, `requires`
and `tier` - with one family entry for the discovered `tests/*.tscn` scenes
and one `analysis_group` entry per tracked profile; `build_checks()` is its
loader (fail-closed on an unknown kind, placeholder, group or tier, a
missing script or profile, a duplicate name) and produces, for every
argument combination, exactly the checks the hand-written table produced
(the baseline dump before and after is identical). `--tier
local|archive_quick|full` (default `full`) plans by tier and composes with
`--check`. 242 registry entries (221 `godot_script`, 19 `python`, one `godot_editor`, one scene family; 149 `analysis_group` entries) planning 134 checks locally, 361 with the archive, 373 with the archive and the executable (372 without `se.arc` or with `--skip-event-corpus`); tiers `local` 3 entries (the 134 local checks), `archive_quick` 81, `full` 158 (the nine long checks and the 149 analysis-group entries, whose runs are the long part of the batch). Verified 2026-09-21: the baseline dump of six argument combinations identical before and after the change; `tests/test_run_headless_validation.py` (24) and the new `tests/test_validation_registry.py` (12: load and validation, script and profile existence, the scene family, the placeholder set, the tier ordering, five malformed registries failing closed by entry name); the Godot parse check; `--tier local` 134 of 134 (255 s); `--tier archive_quick` on `original Event Catalog source bindings`, `original playback package export` and `original Event Player fragment catalogs` (3 of 3); the pre-commit review's findings fixed.

Revision 2026-09-23 (Core 0.360.0, EP-03 step 2, owner ruling): a row
whose run stops in front of another row's intro dispatch ends by continuing
into that event. `tools/promote_analysis_groups.py` (catalog revision 26)
builds an intro index from the v4 documents' triggers, writes the next
event's callee entry as the `next_target` of such a `dependency_stop`
terminal (kind, outcome and runtime status unchanged) and drops its
`dependency-stop-*` blocker; the three GROUND rows H01 first, H01 repeat and
H02 first become `minimal_playback` (142 of 142). `content_core/event_catalog.gd`
rejects a `script_dispatch_boundary` terminal whose `next_target` is not the
callee of the row whose `source.caller` is that terminal's coordinate, and
the vocabulary reads such a terminal as `chain`. `original playback package
playback` reports 119 rows reaching a terminal, 20 ending at a declared place
menu, 3 continuing into the next event and 0 stopped.

Revision 2026-09-21 (Core 0.356.0, EP-10 units 5b and 5c): every catalog row is
generated and every per-event path is retired. `tools/promote_analysis_groups.py`
generates all 142 rows (catalog revision 25) from the v4 documents and the
profiles; a row's `playback_status` is `minimal_playback` when its default
option's winning route ends in a map return, a place menu or a chain (139
rows, `classification` `playable_event`) and `analysis_only` when it ends in
a dependency stop or an undeclared continuation (3 rows, `unresolved_route`).
`content_core/event_catalog.gd` accepts `minimal_playback` / `analysis_only`
/ `blocked` / `not_applicable` and no longer carries the `caller_route` /
`analysis_route` shapes, their validators or the caller-route builders;
`build_play_request` builds a `group_route` request for both statuses (the
status tells the browser what the run reaches). The classifier counts a
`minimal_playback` row as a playable event (129 playable events / 34 shared system scripts / 1 unreachable stored route / 3 unresolved routes over 167 rows); the names registry
names every row (`EXPECTED_CATALOG_COUNT` 142); a full package build selects
every row. Deleted: the eleven `event_player_event*.gd` modules, the twelve
per-event validators, `validate_event_player_catalog_playback.gd`,
`validate_catalog_analysis_routes.gd`, `tools/audit_catalog_analysis_routes.py`
and their registered checks, and the player's hand-row paths - the
`root_replacement` / `nested_call` execution models, the confirmed-caller
continuations, the EVENTB03 camera / large-CG / effect-cue / station code and
the EVENTB14 AX / world-map / outcome-preview code (player 16,054 -> 7,654
lines); the evidence and rules modules keep their generic members. Every row
now plays through `group_route` Play and the presentation timeline; the
`original catalog group routes` check covers all 142 rows. Verified 2026-09-21: the Python suite; the whole local batch (134 of 134 - the two per-event scene tests deleted, `tests/test_catalog_analysis_run.tscn` added with 21 checks of the group-route descriptor); with the archive: `original Event Catalog source bindings`, `original playback package export` (`142 events from 230 member entries (125 catalog-verified, 105 bound by 149 analysis groups)`), `original playback package playback` (976 checks over 142 rows, each driven through its measured route on both the bytecode and the packaged records: 119 reach a catalog-declared terminal, 23 stop at a dependency or def-selection boundary), `original catalog group routes` (all 142 rows, 1,502 s), `original Event Player fragment catalogs`, `original selection handoff original integration`, `original MES Editor original integration` (the editor's contextual Run binds an edited EVENTB03 to its generated row, whose 17 presets it lists), the four `contextual authoring` checks (the workspace export of the edited EVENTB03 needed the selected rows' own group members merged - a generated row's caller entry is listed only by its group - and the serializer's failure is now reported instead of a generic sentence), `original event corpus literal dispatch inventory` and `original dispatch naming beyond the strict decode`; the pre-commit code review's findings fixed.

Revision 2026-09-20 (Core 0.355.0, EP-10 unit 4): a promoted row plays. Play on
such a row runs `run_group_route` and replays the finished result:
`content_core/event_presentation_timeline.gd` (`KakyuEventPresentationTimeline`)
turns the trace and messages into one step per dialogue line - the voice
marker, BGM requests, pictures (background, or foreground from a `_PIC`
presentation script), animation markers (recorded only), sound-effect
requests and the omitted native records since the previous line, and a
closing step - and the Playback view steps through it with the existing
Continue and arrow controls, presenting stills through the shared
compositor (an oversized picture scaled to fit the frame), BGM and voice
through the paths factored out of the trace scanners, sound effects on a
dedicated player, fire and forget; nothing is animated, no omission label
is shown, and the ending is the game-vocabulary phrase. Analyze keeps the
Analysis view. The `original catalog group routes` check gained a Playback
pass that counts the resolved and missing presentation resources. Verified 2026-09-20: `tests/test_event_presentation_timeline.tscn` (35 checks over a synthetic run covering every step field, the cumulative picture state, the closing step and an unknown effect), the Event Player scene (1,308), `original catalog group routes` (12,052 checks: the Analysis pass as before plus 129 Playback runs whose timelines matched their message counts and whose pictures 626/626, voices 1,539/1,539 and BGM 495/495 all resolved in the content set, no unknown effect; no default route traced a sound-effect request, so that path is exercised by the scene test only), `original Event Player EVENTB01 integration` and `original Event Player EVENTB03 captured and numeric choice presets` with PASS lines identical to before (the factored BGM and voice paths are behaviour-neutral), the Python suite, and the whole local batch (135 of 135).

Revision 2026-09-20 (Core 0.354.0, EP-10 unit 3): the starting state of a
promoted row is user input bounded by the guard. `content_core/event_guard_form.gd`
(`KakyuEventGuardForm`) derives, from the typed guard of the row's v4
definition (`guard.conjuncts`), one field per cell the guard reads with the
bounds and exclusions the conjuncts imply, labelled through the state-cell
classifier; `guard_result` runs the caller's guard record once on a
candidate state, the same check the group validator makes after a
continuation. The Event Catalog window shows the form under the Result
selector, initialised from the selected preset, with a "Guard: passes /
fails" line and a "Use this state" toggle; when the toggle is on the
Analyze request carries the candidate state as a `tool_seeded_analysis`
preset over the selected preset (`base_preset_id`), which
`run_group_route` seeds while resolving the route and variant from the
base preset's notes. A row without a typed guard (the ten `caller_prefix`
origins) shows that the presets are its only starting states. Verified 2026-09-20: `tests/test_event_guard_form.tscn` (18 checks), the Event Player scene (1,301), `tests/test_event_catalog.tscn` (1,447), `original catalog group routes` (1,519 checks: 197 runs, 16 unmeasured options skipped, 3 guard-form in-bounds runs reaching their preset's terminal, 3 out-of-bounds refusals both through the UI and directly against the service), `original Event Catalog source bindings`, the Python suite and the whole local batch (134 of 134 in 257 s). The local batch also exposed what the targeted checks of units 1 and 2 had missed: `tests/test_event_catalog_caller_route.tscn` had been timing out on full-catalog re-validations while two of its checks failed and sixteen first-row assumptions mutated the wrong row; it now builds its synthetic documents from the hand rows and passes 766 checks in 2-3 s alone or under load.

Revision 2026-09-20 (Core 0.353.0, EP-10 unit 2): every promoted catalog row is
runnable in the Event Player. "Analyze route" on a row with an
`analysis_group` block builds a `group_route` request (the selected preset
and, for a choice row, the selected option of its first choice), and
`tools/content_suite/catalog_analysis_run.gd` runs it the way the group
validator runs a route: the profile is loaded through
`content_core/event_analysis_profiles.gd` (`KakyuEventAnalysisProfiles`,
indexed by group id and matched by `payload_sha256`, since two tracked files
share one id), the preset is the primary key of a run - its notes name the
group with its profile hash, the route and the variant, since a row may
reference several groups (or two versions of one, of which only the newer
schema contributes routes) and a route id may recur across them - the
selected answer must be one the named variant selects, the variant
supplies its selections, the seed is the START.MES calendar projection plus the composed preset, and
`KakyuMesRouteProbe.run_route` walks the unbroken caller path from the
route's origin (the guard offset for the pre-v4 profiles) with the
variant's selections, the map-location queues, the root-handoff follow,
loop detection and, for a route declared to stop before an unprovided
dependency, the dispatch stop. An option no measured route reaches
(`terminal_ids` empty) is refused as not measured and shown disabled. The
generator of unit 1 was corrected with it: required entries are the union
of the definition's members and the referenced profiles' source members,
every v4 terminal is a row terminal, presets are generated per route and
variant from the profiles, empty-writes variants included (the v4 document
carried the first route's only), and options map to terminals by the coordinates of the routes whose
variants select the value. The ending must match the
row's terminal contract (a dependency stop matches the row's declared
`analysis_boundary`), the Analysis view shows the trace, messages and state
diff, and the status line ends with the game-vocabulary phrase. The new
`original catalog group routes` check runs every promoted row's measured
options through the player. Verified 2026-09-20: `original catalog group routes` standalone - 197 runs over the 213 (row, option) pairs with 16 unmeasured options skipped, 1,468 checks, zero failures, outcomes map_return 150 / place_menu 26 / chain 12 / unresolved 9, 1,148 s in the batch (its registered timeout is 1,800 s pending TD-32) - `tests/test_event_catalog.tscn` (1,447 checks), `tests/test_event_analysis_profiles.tscn` (16), the Event Player scene (1,294), `tests/test_playback_package.tscn`, the Python suite (1,742 tests; `tests/test_promote_analysis_groups.py` grew to 10 with per-row id uniqueness), `original catalog bounded analysis routes`, `original Event Player EVENTB03 zero-state choice analysis` and `original Event Catalog source bindings`, all green; the catalog regenerated at revision 24 with 2,275 presets and 210 terminals over the 129 rows, 119 of 135 first-choice options measured. Eight correction rounds against measured data preceded the landing; the rules they settled are recorded above.

Revision 2026-09-20 (Core 0.352.0, EP-10 unit 1): the Event Catalog carries an
`analysis_only` row for every measured site. `tools/promote_analysis_groups.py`
regenerates `config/event_catalog/original_events_v1.json` from the v4 event
definitions and the analysis-group profiles: the hand-authored rows stay
(re-serialized in one uniform format, content unchanged) and every other v4
document becomes a row with its caller/callee source, activation by dispatch
command, the group's presets, its routine-40 choices bound to the results'
terminals, its terminals (v4 `root_handoff` / `natural_handoff` /
`callee_return` / `def_selection_boundary` / `caller_menu_loop` /
`dependency_stop` mapped onto the catalog's kinds and runtime statuses), the
bounded-presentation blocker and an additive `analysis_group` block
(definition id, groups, profile hashes, route ids) that
`content_core/event_catalog.gd` validates and reports as `generated_count`.
`--check` proves the tracked file is a reproduction. The rows are list-only
in this revision: `build_play_request` still refuses `analysis_only`, so the
Event Player lists them under its "Analysis only" filter with Play disabled
until the wider catalog analysis (EP-10 unit 2). The package export selects
only the hand rows for a full build, so the package's content is unchanged
(its manifest hash follows the Core version and catalog revision, as
before - *annotation 2026-10-07: that was not so on 2026-09-20, because the
manifest's `source.catalog_id` and `source.catalog_revision` were written empty
until WD-21 U1 C1 (2026-10-06), so a catalog revision bump alone did not move the
hash; it follows the catalog revision since*); the classifier folds only the hand rows' dependencies into its
index; by-name catalog lookups prefer a hand-authored row when a callee
name is shared with generated rows, and stay empty when only generated rows
share it. Verified 2026-09-20: `tests/test_promote_analysis_groups.py` (6 tests: the byte-for-byte reproduction, the hand rows equal to HEAD's, the counts, the terminal mapping, `--check` both ways), `tests/test_event_catalog.tscn` (the new counts - 142 rows, 131 `analysis_only`, 129 generated - a generated row validates, a malformed `analysis_group` fails closed, the by-name precedence), `tests/test_playback_package.tscn` (a full build selects the 13 hand rows), the Event Player scene (1,289 checks, its catalog-shape loops over the hand rows), the Python suite (1,738 tests, with the outcome censuses over 142 and 13 rows and the names registry untouched because `tools/build_event_names.py` now counts hand rows only), the classification refresh (169 rows, 11/37/1/120, nothing newly bound or moved), and the original checks: Event Catalog source bindings, playback package export and playback (13 events from 228 member entries, unchanged), catalog bounded analysis routes, Event Player catalog ordinary playback and fragment catalogs.

Revision 2026-09-20 (Core 0.351.0, EP-09): endings are reported in the game's
vocabulary. `content_core/event_outcome_vocabulary.gd`
(`KakyuEventOutcomeVocabulary`, the port of `tools/event_outcome_vocabulary.py`)
derives one of five outcomes - `map_return` (with the postlude's owner),
`place_menu`, `chain`, `not_triggered`, `unresolved` - from a catalog
terminal or a v4 terminal without changing either, and the Event Player's
catalog terminal message, footer and status lead with the phrase ("Back to
the town map after the place's own lines", "Back to the place menu",
"Continues into K_DATE5.MES", ...) while keeping the terminal's kind, owner,
offset and target beside it. Nothing was re-measured and no contract, row or
document changed. Verified 2026-09-20: `tests/test_event_outcome_vocabulary.py` (68 tests: every rule row both ways with its reason string, the phrases, the pinned census), `tests/test_event_outcome_vocabulary.tscn` (64 checks: the port mirrored and one check per catalog row against the Python result over the live catalog), the Event Player scene (1,288 checks, unchanged), the rules scene (68), the Python regression suite; all green.

Revision 2026-09-19 (Core 0.350.0, MW-13): the Definitions tab's right pane
is a Form / JSON pair over one document. The form
(`tools/content_suite/mod_definition_form.gd`, rows in
`mod_definition_rows.gd`) edits the header, trigger, display and
presentation as fields and the conditions, dialogue entries and effects
as typed rows in the contract's vocabulary, the single default result of
a plain event in place, and an override's `replace_conditions`,
`replace_after`, `replace_order_hint` and `disable` operations as rows;
a document it does not cover (a question, several results, a nested
question, `replace_result`, `append_result`) stays JSON-only and the form
says why. Switching Form to JSON serializes; JSON to Form parses, or
stays on JSON with the reason; Validate and Save always read the JSON
text. Every `legacy_cell`, write and add row carries the cell class
computed as the validator computes it, by `content_core/state_cells.gd`
(`KakyuStateCells`, the port of `tools/state_cells.py`, its table checked
against the tracked fingerprint by `ContractValues.directory_fingerprint`).
Verified 2026-09-19: `tests/test_mod_definition_form.tscn` (29 checks: exact round trips of the covered fixtures, refusals with reasons, flag/counter relabeling, affection and clock classes, the U+000A and `{name}` line, the rebase hash against the Python rule, the changed signal), `tests/test_state_cells.tscn` (49), the Definitions panel scene (38, Form/JSON switching and a save from the form), the MES Editor scene (158), `tests/test_contract_values.tscn` (48), the local batch 131/131, Python 1,663.

Revision 2026-09-19 (TD-11 unit 2b, Event Player constants): every event
constant of the player (473 declarations) lives in its event module and
the four shared evidence constants in `event_player_evidence.gd`; the
player references them module-qualified and no module references the
player. Player 16,054 -> 15,348 lines; after units 1 to 2b the scene
script is 15,348 lines and 357 functions, from 18,344 and 458
(`todo/code_health.md`, TD-11).

Revision 2026-09-19 (TD-11 unit 2, Event Player evidence context): the 61
per-event functions and 11 generic source helpers that only read the
player's source and run state moved out of the scene script.
`tools/content_suite/event_player_evidence.gd` (`KakyuEventPlayerEvidence`)
holds references to those fifteen members, built by the player's
`_evidence()` per call, and carries the helpers as methods (the player
keeps one-line delegates); the per-event functions are statics with
`evidence` first in `event_player_event<xx>.gd` (b01, b02, b03, b14, b15,
d01, d02, d03, d05, d08, d14). State stays on the player: tests and
validators reach its members by name. Player 17,617 -> 16,054 lines. (The
eleven per-event modules were deleted on 2026-09-21, EP-10 unit 5c.)
Covered by `tests/test_event_player_evidence.tscn` and the unchanged
scene and original checks (`todo/code_health.md`, TD-11).

Revision 2026-09-19 (TD-11 unit 1, Event Player pure rules): the Event Player's
41 pure functions and 29 constants - the generic run-request, trace and
routine-40 matchers, the EVENTB03 preset and picture contracts, the
EVENTB14 outcome matchers and their tables - live in three static modules,
`tools/content_suite/event_player_rules.gd` (`KakyuEventPlayerRules`),
`event_player_eventb03.gd` (`KakyuEventPlayerEventB03`) and
`event_player_eventb14.gd` (`KakyuEventPlayerEventB14`), which the player
references one way; bodies unchanged, no wrapper, the scene test's direct
calls rewritten to the modules. Covered by `tests/test_event_player_rules.tscn`
and the unchanged Event Player scene and original checks
(`todo/code_health.md`, TD-11).

Revision 2026-09-19 (Core 0.349.0, catalog replay): the audited calendar
table hash lives in `content_core/mes_calendar_state.gd`
(`KakyuMesCalendarState.AUDITED_TABLE_SHA256`), which the Event Player
and the catalog replay CLI both reference; the replay CLI's new inputs
(startup registry, calendar projection, on-demand nested members,
call-site boundary matching) are described in `tools/README.md` and
their measured effect on the projected documents in
`docs/spec/data/event_definition_v4.md`.

Revision 2026-09-19 (Core 0.348.0, mod event definitions): the MES Editor gains
a **Definitions** tab (`tools/content_suite/mod_definition_panel.gd`) for
the definitions a mod writes itself
(`docs/spec/data/mod_event_definition.md`). It lists the named workspace's
definitions from the overlay manifest, opens one as its stored JSON text,
fills a `new_event` or `override` template (the tracked fingerprints, the
workspace's mod id, a placeholder English title, and for an override the
LF-normalized SHA-256 of the tracked v4 document the target id names),
validates the text through `KakyuModDefinitionBinding` (the Python
contract validator) with the verdict inline, saves through
`KakyuContentWorkspace.stage_mod_definitions` with that validator - so a
document the contract refuses never reaches the manifest - removes one,
and imports or exports a definition set
(`docs/spec/data/mod_definition_set.md`) through the Python tool and the
Godot importer. The editor refreshes the panel after a Hot Reload of the
same workspace and re-reads the overlay after a save. Without a named
workspace the tab's actions are disabled. A structured form in place of
JSON text is a later increment. Verified 2026-09-19: `tests/test_mod_definition_panel.tscn` (33 checks: the idle editor's disabled actions, template, validate, save, refused save with the manifest byte-identical, override template hash agreeing with the Python rule, export, remove, import, layout), the MES Editor scene (158), the set importer scene (21), the overlay scene (152, with the new carried-over record check), the local batch (127 checks), Python 1,663. Two defects found by the panel's round trip and fixed on the way (Core 0.348.0): a definition record carried over from a loaded manifest was written back with a float `mod_revision` (Godot's JSON parser yields floats), which the Python side refused after the second save - records are now folded to integers on load; and the set importer judged "unchanged" by the stored bytes' hash, which never matches a set's canonical bytes after a round trip - it now compares the parsed documents.

Revision 2026-09-16 (Core 0.324.0, MW-11 resource names): the MES Editor
Authoring tab exposes a fourth edit family, same-length resource names
(`replace_resource_name`: MMO, AX and voice markers), over the existing
resource-name planner and compiler. The authoring bundle is
`kakyu_mes_authoring_bundle/v4` (summary `resource_controls`; v1-v3
readable) and the distributable delta `kakyu_authored_mod_delta/v4` (minimum
core 0.324.0; v1-v3 readable). The session adds the resource reopen
validator and the name range to its per-schema table. Contracts:
`docs/spec/data/mes_authoring_bundle.md` (Version 4) and
`docs/spec/data/authored_mod_delta.md`; scene
`tests/test_mes_resource_authoring.tscn`.

Revision 2026-09-15 (Core 0.322.0, MW-11 condition literals): the MES Editor
Authoring tab exposes a third edit family, same-width condition literals
(`replace_condition_literal`), over the existing condition planner and
compiler. The authoring bundle is `kakyu_mes_authoring_bundle/v3` (summary
`condition_controls`; v1 and v2 readable) and the distributable delta
`kakyu_authored_mod_delta/v3` (minimum core 0.322.0; v1 and v2 readable).
`mes_authoring_session.gd` selects the Godot reopen validator by compile-audit
schema and checks the patched byte range per family; unknown audit schemas are
refused. Contracts: `docs/spec/data/mes_authoring_bundle.md` (Version 3) and
`docs/spec/data/authored_mod_delta.md`; scene
`tests/test_mes_condition_authoring.tscn`.

Revision 2026-09-15 (WD-22, the event-definition agreement): four tools and
one CLI project qualified routes into the shared `kakyu_event_definition/v3`
(`docs/spec/data/event_definition_projection.md`).
`tools/build_event_names.py` generates the event name registry
`config/contracts/event_names_v1/` (142 sites keyed by callee, caller and
dispatch-site ordinal, five-segment ids, provisional titles the owner edits in
place, `names_fingerprint` `b7ffcea3...5163e1a`);
`tools/contract_fingerprint.py` computes and checks a mirrored directory's
fingerprint (SHA-256 over sorted `path<TAB>sha` lines);
`tools/content_suite/cli/replay_event_dialogue.gd` replays a catalog event's
presets and choice options in the bounded sandbox and records the message
records (entry, offset, hash - never text), the terminal and the reentry;
`tools/project_event_definition.py` projects a catalog event row with that
replay and the local playback package into the tracked document (text
referenced by package entry, record offset and string index) and a local
resolved document with a readable `script` block;
`tools/validate_event_definition.py` validates a document fail-closed
(eighteen reason codes in a fixed order) and, given the package, resolves
every reference. `config/contracts/event_definition_v3/` is the conformance
fixture set (`contract_fingerprint` `7545e37e...272fb55`), mirrored
byte-identically in the remake; `tests/test_event_names_registry.py` and
`tests/test_event_definition_contract.py` recompute both fingerprints and run
every fixture.

Revision 2026-09-15 (Core 0.320.0, MA-11): `references.state` carries a
write row for every write run whose destination is a state storage - `0x04`
`state_u16`, `0x05` dynamic `global_u8`, `0x06` `banked_u8` and `0x0A`
`global_i32` join `0x03`, `0x07` and `0x08`; the argument-slot runs stay
without one - in both producers, so the analysis inventory's write sites name
their destinations. The frozen v45 digest is regenerated (667 payloads
changed in their `references` component only; corpus fingerprint
`74f14088...2a1dff8`, approved by the owner on 2026-09-15) and the full Python
equivalence gate
reproduces it.

V6 target outcomes and direct reentry outcomes each require an exact record
hash and typed/opaque source binding. They may be a return, routine-40 choice
stop or command-0E handoff with its original target. Reentry uses the same
owner-qualified choices as the variant, and can have a per-variant expectation.
The required `post_guard_expected` (0 or 1, optionally overridden per variant)
records the old caller's local predicate evaluated on the target's final state;
this is not an assertion that the old caller resumes or that the event becomes
inert. Source/runtime report schemas use V6; opaque observations remain opaque,
and V1-V5 retain their existing meanings and report identities.

`kakyu_event_analysis_group/v7` is V6 for a dispatch that has no local
eligibility guard at all. It declares no `guard`, no `post_guard_expected`
and `unconditional_root_replacement_observation`; declaring any of those
fails closed. In place of guard witnesses it carries `unconditional_dispatch`,
a source-bound statement about the interval from the typed origin to the
dispatch: the audit re-derives the window from the original bytecode and
requires the declared record and code-offset-edge counts, the declared return
candidate offsets and the prefix hash to match. It rejects the route if any
edge in the window targets past the dispatch offset, if the window contains
another command-0E/0F dispatch, or if it overlaps an opaque tail. The measured
window is returned in `unconditional_dispatch_windows`, so the proof is visible
rather than only enforced.

This is a structural statement about one interval, not reachability: it says
nothing about how execution arrives at the origin, and a return candidate
inside the window is reported rather than ruled inert. `selection_cases`
replace `guard_cases` and carry no `expected` truth - each is a state witness
that must still reach the same dispatch record with its declared caller
message count, checked at runtime. Source/runtime report schemas use V7.

`kakyu_event_analysis_group/v8` is V5's returning callee with one addition: a
third caller-resume `boundary_policy`, `def_selection_boundary`. V5 accepts a
resume that ends at a command-`0x0F` dependency stop or a command-`0x0E` natural
handoff; some callers instead run their post-event sequence into a routine-40
registered-definition selection and stop there because no catalog choice is
supplied. The audit binds that stop as an exact command-`0x1D` record whose
routine is 40, requires it to name no script target, and keeps the policy
V8-only so no existing profile can widen its contract by a schema field alone.
Everything else is V5: a typed or opaque-bound guard with both acceptance and
rejection witnesses, an exact returning-callee outcome, and a completed reentry
measured after the caller finishes. The runtime side needed no new check - the
validator already read this boundary for callee outcomes and reentry
observations - so V8 changes what may be declared, not what is executed.
Source/runtime report schemas use V8.

`kakyu_event_analysis_group/v9` is V8's caller-continuation contract with V7's
unguarded declaration in place of the local guard: a returning callee, all
three caller-resume `boundary_policy` values including `def_selection_boundary`,
reentry, and choice contracts, but no `guard`, no `guard_cases` and no
`post_guard_expected` - declaring any of those fails closed, the same as V7.
In their place it carries `unconditional_dispatch` (`record_count`,
`edge_count`, `return_candidate_offsets`, `prefix_sha256`), re-derived by the
same window audit from the typed origin to the caller record, and
`selection_cases` in place of `guard_cases`: state witnesses with no `expected`
truth, each required to reach the same dispatch record with its declared
`caller_message_count`. The qualification is
`unconditional_caller_continuation_observation`.

The runtime side treats V9's witnesses as unguarded, the way V7's are: each
selection case runs a `stop_before_dispatch` prefix and requires the resulting
stop to be the exact `analysis_dispatch_stop` at the declared caller
offset/end/command/target, rather than V7's natural `script_handoff_boundary`
terminal, because a nested call (command-`0x0F`) would otherwise actually
invoke its callee where a root handoff (command-`0x0E`) never does. Everything
after that - the callee outcome, caller resume, reentry and per-variant checks
- runs exactly as V5/V8's do. Source/runtime report schemas use V9.

`kakyu_event_analysis_group/v10` is V8's returning callee with a fourth
caller-resume `boundary_policy`, `caller_menu_loop`. Some callers run their
post-event sequence into their own interactive loop - a floor's menu, which
only native input leaves - so the resume reaches no handoff, no dependency
stop and no routine-40; before 0.317.0 the probe spent its 512-segment budget
there and the route could not be declared (15C's C06 and E11). The probe now
takes a `detect_loops` request: a continuation is the boundary record the
runner stopped at together with the stored values, the RNG position, the
argument slots and the persistent expression stack, and since the runner is
deterministic a continuation seen twice repeats forever. The walk then stops
at the continuation's first occurrence - the loop head - keeps only what it
had collected up to it, and reports the cycle (the segments between the two
occurrences), its period and the messages one period emits. The profile
declares that head as the resume outcome, status `loop_boundary`, and a
`loop` block: `period`, `period_message_count` and the `cycle` rows, each an
exact typed record of the caller that is either a message wait
(`System.function[19]`) or a shared-routine call. The audit binds every row,
requires the head to be the first cycle row, refuses a row outside the
caller, and keeps the policy V10-only so no existing profile can widen its
contract by a schema field alone. The runtime side runs the suffix and the
unbroken path with the request and compares the cycle the probe proved with
the declared one, row by row, period and per-period count included; every
other check (callee outcome, resume state, post-guard truth, reentry) runs as
V5/V8's do. A loop that keeps changing state - a counter - proves nothing and
still spends the budget. Source/runtime report schemas use V10.

`kakyu_event_analysis_group/v11` and `v12` add map-location contracts. The
map scripts - `MACHI`, `FLOOR1`..`FLOOR5`, `GROUND` and `TRAIN` - read the
player's position through the native map module: `Util(6,8)` runs the
sprites and redraws, `Util(6,13)` writes the location the player sprite
stands on into `state_u16[18]` (`0xFFFF` for none), and the script copies it
into `state_u16[21]` and branches on it, polling again until a location
arrives. That is the loop every map's "what selects `state_u16[21]`" note
pointed at, and the train's boarding loop at `TRAIN.MES:849..1044`; nothing
inside such a loop is a boundary record, so the probe's loop detection
cannot see it and the runner spends its step budget. A `map_location_contract`
(`kakyu_mes_map_location_contract/v1`) names a source member, the exact
`Util(6,13)` record (`poll_offset`, `poll_end`, `record_sha256`, the two
literal records `[6, 13]`), the cell the module writes (`state_u16[18]`,
`none_value` `0xFFFF`) and the ordered `locations` the player reaches. The
runtime supplies the next location at that record - and only there, and only
while the queue lasts; a spent or absent contract leaves the record an
omitted native as before - and the callee and unbroken runs must spend every
declared location. The audit binds each contract to its member and pins the
result cell; V11 is V6's root replacement with contracts, V12 is V10's caller
continuation with contracts, and the field is refused under every other
schema, so no existing profile can gain an input by a field alone. The
semantics are read from ai5-sdl2's Kakyuusei map module (`System.Map.function[8]`
and `[13]`, `analysis/ext/ai5-sdl2`, GPL-2.0, kept outside the tree like
libai5): the 1998 engine's `System.Map` is this edition's utility group `6`.
The first contracts are the train's boarding, locations `0` then `1`, on the
three 01M intros whose callees ride to Hazuki town. Source/runtime report
schemas use V11 / V12.

`kakyu_event_analysis_group/v13` (0.361.0, EP-11 part 1a, tool decision) is
V8 plus an optional route field `visits`: an ordered list that extends the
one committed `reentry` pass with further replays of the same returning
callee, for a callee whose own visit counter keeps changing what it does
past the first reentry (EVENTM10.MES's `global_u8[2456]` ladder is the
first case). Each visit has a unique `visit_id`; an `after` naming `"route"`
(the state the dispatch and caller resume left, the same state `reentry`
itself starts from), `"reentry"`, or an earlier visit's own `visit_id` - no
cycle and no forward reference; `seed_writes` (state writes applied before
the visit, possibly empty) with a `seed_basis` of `"tool_seeded"` whenever
`seed_writes` is non-empty and the natural source of those values is not
established, else `"none"`; an `outcome` bound the same way as
`reentry.outcome`; `message_count` for the callee's own run plus every
nested call it makes; `expected_state`; and `dispatches` - the nested calls
the visit makes, each an `entry` (the dispatched member), the `offset`/`end`
of the exact `script_dispatch` record in the callee, the nested call's own
`outcome` (bound in `entry` the same way) and its `message_count`; empty
when the visit makes no nested call. The audit binds every visit outcome as
an exact return record in the callee, every dispatch to its exact
`script_dispatch` record and dispatched member, every nested outcome as an
exact return record in that member, and every `after` to a known pass with
no cycle or forward reference; it rejects anything else fail-closed, naming
the visit. The runtime replays each visit in declared order from the state
its `after` pass left plus `seed_writes`, through the same call frame, and
checks the outcome, message count, expected state and that exactly the
declared dispatches occurred. V8 profiles are unaffected: `visits` is
optional and only V13 may declare it. Source/runtime report schemas use
V13.

EP-11 part 1b (0.362.0, owner ruling 2026-09-23, tool decision) adds a
required field to every V13 visit, `entry_state`: the cells whose values the
visit is entered with that distinguish it from the route's own start -
measured from the state its `after` pass left, not composed by rule alone.
The audit requires the field on every V13 visit as a list of `{storage,
bank, index, value}` cells (shape only; it does not re-derive the values);
`visits` is refused under every other schema already, so `entry_state`
inherits that boundary. The runtime validator checks that the `after`
pass's own state holds exactly those values before the visit's
`seed_writes` apply, distinct from the post-run check `expected_state`
already makes.

EP-11 part 1c (0.363.0, owner ruling 2026-09-23) found `entry_state` cannot
be derived by composing only a route's and its passes' own declared
`expected_state` fields, and that only one of EVENTM10.MES's two caller
sites can host visit presets at all - see `docs/spec/mes/44c_caller_group.md`
for the full measurement:

- **Site A (`44c-m10a`) declares no `visits`.** Its own guard needs
  `global_u8[2455]` clear and its own prefix sets `[2455] = 1`
  unconditionally before the dispatch, so a genuine playthrough closes that
  guard for good; nothing in the archive ever clears it again. Site A's
  route, reentry and every other v13 field are unchanged from part 1a;
  `44c_m10a_v13.json` only lost its `visits` array (and, with it, every
  visit preset `promote_analysis_groups.py` had generated for that row).
- **Site B (`44c-m10b`) keeps `visits`, with `entry_state` extended past the
  9 cells part 1b first used** (the route's declared `expected_state` plus
  `reentry.expected_state`'s override) **to every cell a direct runtime
  snapshot actually finds different**, not a hand-picked subset: `[351]`
  becomes `4` once `visit3-gate`'s gated dispatch to EVENTM11.MES has run,
  `[350]` becomes `0` once `visit4-gate`'s has, and the gate flag `[287]` a
  rung's own `seed_writes` opens stays `1` afterward (EVENTM10.MES never
  clears it), which `visit5-gate` needs since it reaches the same fixed-point
  rung as `visit4-gate` without seeding its own gate flag.
- **A visit preset excludes any cell the route's own local guard reads.**
  Site B's guard rejects whenever `global_u8[2417] = 1` (its
  `global_u8-2417-1` guard case) - exactly the value every visit's
  `entry_state` declares, since that is the value the callee's first
  dispatch leaves and the guard is meant to check *before* that dispatch;
  the day change (`DEF_MAIN.MES`'s registered definition 12, not the
  callee) is what actually clears it between visits.
  `tools/promote_analysis_groups.py`'s `_guard_declared_cells(route)` reads
  this straight from the route's own `guard_cases` (the union of every
  case's `writes`) - never a hard-coded cell list - and a visit preset's
  composed `entry_state` drops any cell in that set, leaving the row's
  default preset's own accepting value there instead.

A visit is also a catalog preset: `tools/promote_analysis_groups.py`
(catalog revision 27) adds, for every visit of the route a row's default
option uses, one preset `<route_id>-<visit_id>` whose writes are the row's
default measured preset's own writes (the default route's `baseline` plus
its default variant's `writes`), then the visit's `entry_state` with the
guard's own cells removed, then its `seed_writes` (later writes win,
`compose_writes` chained); `kind` `tool_seeded_analysis` when the visit's
`seed_basis` is `tool_seeded`, else `original_branch`; `label`
`"visit <visit_id>"`; `notes`
`analysis-group variant <group_id>@<hash12>/<route_id>/<visit_id>`, the
ordinary preset notes shape with the visit's own id in the variant slot.
Nothing else in a row changes. `tools/content_suite/catalog_analysis_run.gd`'s
`_find_variant_in_route` falls back to a route's `visits` when no variant
matches the requested id, returning the visit itself (aliased with a
`variant_id` key) as the stand-in: a visit declares no `selections` of its
own, so `build_group_route_descriptor` builds no choices for it, and the
route still runs from the caller's own guard/origin with the preset's
composed writes - the callee reads the seeded visit-counter cell and runs
that visit's rung, and the caller's resume ends at the route's own terminal
exactly as it does for every other preset of that route (EVENTM10.MES: the
dormitory's selection at `44C.MES:45952`). `validate_catalog_group_routes.gd`
runs every such visit preset through both the Analysis and Playback passes
per shard and checks the run completes at a declared terminal, the played
message count summed over the callee and every declared dispatch target
(`message_count` is "the callee's own run plus every nested call it makes",
the field's own v13 definition) equals the visit's `message_count`, and the
visit's declared dispatches occur (entry and offset in the trace); its PASS
line and JSON report the count as `visit_runs`, not asserted positive per
shard since only one of the catalog's 142 rows (`44c-m10b`) declares
`visits`.

`tools/classify_event_routes.py` also reads `visits`: a v13 visit's
`dispatches` target gets the `measured_callee` role (as a route's own callee
already does), and an EVENT entry a `minimal_playback` row's visit dispatches
is `playable_event`, its reason naming the row and the visit, even though it
is not that row's own callee (owner-approved direction, tool decision).
EVENTM11.MES, dispatched only from EVENTM10.MES's site-B visits, moves from
`unresolved_route` to `playable_event` this way (classification
131/35/1/0, from 130/35/1/1).

`kakyu_event_analysis_group/v14` (EP-12, owner ruling 2026-09-24, tool
decision) declares a **flow**: a date's own chain from a place's date guard
through every nested call and root handoff to the flow's end, measured in
`analysis/_undoc/ep12_date_entry_report.md` (the promise's writes, the shared
date guard, one pass of seven parts, `A_DATE3.MES`'s branches) and
`ep12_hotel_report.md` (the hotel chain) - a shape neither v6's single root
replacement nor v13's single returning callee plus visits can express,
because a date runs up to seven nested scripts in one caller pass before its
own root handoff, with per-hop routine-40 answers and plain-state gates
sitting between an answered question and its handoff. This first part built
and proved the shape only on synthetic archives; the real declaration
(`config/event_catalog/analysis_groups/01m_a_date_v14.json`, group
`01m-a-date`, EP-12 part 3, 2026-09-24) followed once the hotel-menu choice
contract, the train-leg map-location poll and `state_context` (below) landed
- see `docs/spec/mes/a_date_flow.md`'s "Declared" section for the three
routes, their hop/message counts and what remains unresolved.

A v14 route has `route_id`; `origin` - `entry` (the flow's first hop's own
script), `offset` (a typed record preceding the guard), `guard` (`offset`,
`end`, `false_target`, `prefix_sha256`, `record_sha256`, `source_binding`,
the same shape v5/v6 declare), and `guard_cases` (acceptance and rejection
witnesses, the same vocabulary as every other guarded schema); `baseline`
(the seeded state, including the promise's own cells); `state_context`
(EP-12 part 3, 2026-09-24, tool decision, additive to v14 - the same object
v8/v6 routes carry, `{"kind": "fresh"}` or `{"kind": "original_calendar",
"entry", "table_sha256"}`, audited by the existing `_audit_context` and
applied by the runtime flow validator to the guard witness and every
variant's run state before `baseline` and the variant's own writes, exactly
as `event_analysis_group_validation.gd`'s own `_seed_route` does for a v8
continuation route; `START.MES` must be a declared source member when the
kind is `original_calendar` - the fix that lets a real flow through
`DENSHA.MES`'s own definition-12 branch, whose month scan needs the calendar
table `START.MES` fills, past the `DENSHA.MES` stop
`docs/spec/mes/a_date_flow.md` records. Unlike v8/v6, where `state_context`
is mandatory, a v14 route may omit it entirely (`_audit_flow_route` reads
`route.get("state_context", {"kind": "fresh"})`, matching the runtime
validator's own default): a v14 profile that predates this field - the
GDScript-only synthetic fixture in `tests/test_event_analysis_group_flow.gd`
already was one - must keep validating unchanged); `hops` (ordered);
`terminal` (the flow's end - exactly the last hop's own `expected.outcome`,
named again at route level so a truncated hop list is visible without
reading every hop); `variants` (`variant_id`, `writes`, `expected_state`, the
same shape v6 variants carry); `choice_contracts` (v3 routine-40 contracts,
the same shape as every other schema, keyed by owner entry and boundary
offset since a flow's choices are rarely all in one script); and
`unresolved` (a plain list, carried through by the validator but not
re-derived by the audit, the same as every other schema).

Each hop has `hop_id`; `entry` (the script this hop runs in); `entered_by` -
`{"kind": "origin"}` for the flow's first hop, or `{"kind": "nested_call" |
"root_handoff" | "resume", "offset", "end", "op", "record_sha256",
"source_binding"}` for every later hop. The record is always found in the
hop before it, which is what makes the chain auditable with no separate
"caller" object per hop: a `nested_call` or `root_handoff` hop's record is
exactly the previous hop's own `expected.outcome` (v14 states a fourth
outcome status beside v6's three, `script_dispatch_boundary`, for a hop that
ends by dispatching the next hop rather than returning, selecting or handing
off - command 15, the same the existing schemas already call
`script_dispatch`); a `resume` hop's record is exactly the previous hop's own
return record (its `expected.outcome` when that status is `script_return`),
since resuming happens where the callee just returned, and the resuming
hop's own `entry` must be the script that made that nested call - the hop
two before it. This is a tool decision, not a recovered native mechanism:
the archive has no separate "resume" record, only a call and a return: v14
names the return record as the resume's own identity because that is the
exact typed coordinate execution is at when the caller continues.

`answers` are routine-40 selections made inside the hop, `{boundary_offset,
result_value}` (no `owner_entry` - the hop's own `entry` is the choice's
owner), bound against the route's `choice_contracts` the same way every
other schema's selections are, keyed by `(entry, boundary_offset)`; the
audit rejects an answer whose boundary or value the contract cannot build.
`gates` are plain-state conditions that must hold when the hop starts -
`{storage, bank, index, op, value}`, `op` one of `equal`, `not_equal`,
`greater_than`, `less_than`, `greater_or_equal`, `less_or_equal` - each with
a `basis`: `baseline` or `written_by:<hop_id>` (a check only, against state
the flow itself produced) naming an earlier hop, or `tool_seeded` (the
validator writes the value directly before the hop runs, the same technique
`ep12_hotel_report.md` and `ep12_date_entry_report.md` used throughout for a
gate whose own natural origin is unresolved); the audit checks the shape and
that a `written_by:` reference names a hop declared earlier in the same
flow, not the runtime truth of the gate, which is the validator's claim.
`map_locations` is optional per hop, the same `kakyu_mes_map_location_contract/v1`
shape v11/v12 carry at route level. `poll_supplies` (EP-12 part 2,
2026-09-24, tool decision, additive to v14) is also optional per hop: a plain
list of `{definition, poll_offset, entry, result_storage, result_index,
value}`, one entry per registered definition whose own body polls a plain
state cell in a loop the tooling cannot otherwise resolve (definition 17's
`state_u16[18]` wait, invoked from `A_DATE5.MES:488` into `DEF_MAIN.MES`,
`docs/spec/mes/a_date_flow.md`'s "Two selector sites, re-read"). The audit
binds `poll_offset` to an exact `branch_if_not_true` record in `entry` whose
own condition reads `result_storage[result_index] == value`, and binds
`definition` to a `bootstrap_transfer` registration in the same entry whose
own body covers `poll_offset`; it does not claim the definition ever reaches
that poll in a real pass. The runtime seam is the same one `map_locations`
uses for a command-0x12 `Util(6,13)` poll, generalised only as far as this
needs: `mes_event_runner.gd`'s own command-0x0B handler writes `value` into
`result_storage[result_index]` immediately before evaluating that exact
branch's condition, every time it is reached (a fixed value, not a consumed
queue - a wait loop asks the same question every pass), threaded through
`mes_route_probe.gd`'s `_run_definition` and
`mes_registered_definition_call.gd`'s own context, not through the
native-record-omission path `map_locations` itself uses. `expected` is `message_count` (the hop's
own run), `outcome` (the exact record this hop ends at, one of the four
statuses above, and its `target` when it dispatches or hands off), and
`expected_state` (the cells the hop leaves, the same vocabulary as every
other schema's `expected_state`).

**Hop `segment_budget` (EP-12 H, 2026-10-04, tool decision, additive to v14 -
the same kind of field as `poll_supplies`; advisor ruling: a limit the tool
needs, not a measurement).** The route probe (`content_core/mes_route_probe.gd`)
spends at most 512 segments in one script frame and stops there with
"segment limit reached"; a message is one segment. The 13 recollection ladders
of the room play 570..911 messages in 417..649 segments with their gate flags
set, so eight of them cannot reach their own return under the default (measured
2026-10-04: with the budget lifted all 13 return at the same record as their
no-recollection run). A hop may therefore carry `segment_budget`, an integer:

- **Default and absence.** Absent means 512, and the request the flow runner
  builds for a hop without it is byte-for-byte the request it always built
  (`tools/content_suite/event_flow_runner.gd` puts the key in only when the hop
  has it), so no installed profile moved. The validator, the catalog run and the
  Event Player all run a flow through that runner.
- **Probe.** `run_route` reads `descriptor.segment_budget` (default
  `DEFAULT_SEGMENT_BUDGET`, 512) once; a value that is not a whole number
  (JSON gives a float, so `1024.0` is accepted) or is below 1 stops the run with
  "invalid segment budget"; the walk then allows that many segments per script
  frame (`range(budget)`), the meaning of the 512 before it, and the stop phrase
  at the limit is unchanged. Core 0.369.0 to 0.370.0 for this change.
- **Audit.** `_audit_flow_segment_budget`: when present it is an integer (not a
  bool, not a string, not a float) with `512 < n <= 4096`; a value at or below the
  default would change nothing and is refused rather than carried.
- **Builder.** A hop spec's `segment_budget` is copied into the hop only when
  present (`tools/build_event_flow_profile.py`).
- **What it is not.** `expected.message_count` records what the hop plays; the
  budget is the room the probe is given to play it. It enters no document: the
  v6 projector enumerates a hop's keys and does not carry it (no v6 shape change).
  Declared as 1024 on the second hop of each recollection route only
  (`docs/spec/mes/43c_caller_group.md`); none on the first.

The audit (`audit_event_analysis_group.py`) binds the origin guard exactly
as v5/v6 do; requires the first hop's own `entry` to be the origin's and its
`entered_by` to be exactly `{"kind": "origin"}`; walks the hop list checking
each `entered_by` against the hop before it (kind, exact record identity,
and - for `resume` - that the hop before was itself `entered_by`
`nested_call` and that this hop's `entry` matches the hop two back); binds
every hop's own `outcome` as an exact record under its declared status;
checks every answer against the shared `choice_contracts` and every gate's
shape and `basis` reference; and requires `terminal` to equal the last hop's
own `outcome` exactly, entry included. It rejects a shifted or retargeted
`entered_by` record, a hop whose declared outcome is not the exact original
record, hops out of chain order, an answer outside its contract, a gate
naming an unknown or later hop, and a state write that is unsupported,
duplicated or out of range - each failure names the hop. The qualification
and runtime schema are `kakyu_event_analysis_group_source_audit/v14` /
`kakyu_event_analysis_group_runtime/v14`.

**Variant `answers` and `message_counts` (EP-12, 2026-10-04, tool decision,
additive to v14; owner ruling 2026-10-04: an album scene's question options
and a recap scene's second path are presets of the scene's row; advisor
ruling: an in-place extension like `state_context` and `poll_supplies`, not
v15, with no change under `config/contracts/` and the v6 document shape
unchanged - `tools/project_event_definition_v6.py` projects `variants[0]`
only).** A hop fixes one answer per question and one message count, so a v14
route could not carry another option of a scene's question or a recap scene's
second path (found by the SCENE J unit: `SCENE_J08`/`J13` option 2 plays
9/14 lines, `SCENE_J14` plays 32 lines on the DATE5 path and 36 on the hotel
path). A route variant may now also carry two optional fields:

- `answers`: a list of `{hop_id, boundary_offset, result_value}`. Each entry
  replaces the named hop's own answer at that boundary for this variant (or
  supplies it when the hop declares none), the choice owned by that hop's
  entry exactly as a hop's own `answers` are.
- `message_counts`: an object `{hop_id: n}`, the variant's own message count
  for a hop in place of that hop's `expected.message_count` (the hop's own
  count stays the default and the count of every variant that does not name
  it).

Absent, both change nothing: every profile that predates them keeps
validating, promoting and projecting exactly as before (every installed
flow route has a single variant carrying neither). The audit
(`_audit_flow_variant`) binds each `answers` entry to the route's
`choice_contracts` with the same check as a hop's own answers
(`_audit_flow_answer`: the `(hop entry, boundary_offset)` must be a declared
contract, the value one of its `result_values`, no repeat within the
variant), requires the `hop_id` to be a declared hop, and requires
`message_counts` keys to be declared hop ids with nonnegative integer values;
a malformed field (a non-list `answers`, a non-object `message_counts`, an
entry without an integer `boundary_offset`/`result_value` and a string
`hop_id`) is refused, and each failure names the variant.

**Stop rule.** A variant can differ from the route's default path only in the
answers it gives, the cells it writes and the number of messages a hop plays;
every variant still ends at the route's own `terminal` and every hop still
reaches its declared `expected.outcome`. A path whose terminal record differs
from the route's `terminal` (an option that leaves the scene through another
return or handoff) cannot be declared as a variant - it stays recorded as
`unresolved` in the route - and a per-variant outcome override is out of
scope, the same limit as the v6 return-visit variant. The runtime flow
validator enforces this by checking the declared outcome of every hop for
every variant.

**Runtime.** One rule decides what a variant answers and plays:
`KakyuEventFlowRunner.hop_answers(hop, variant)` is the hop's own `answers`
with each variant entry naming that hop replacing the hop's answer at the
same boundary (a variant entry at a boundary the hop does not answer is
appended), and `KakyuEventFlowRunner.hop_message_count(hop, variant)` is
`variant.message_counts[hop_id]` when named, else the hop's own
`expected.message_count`. `KakyuEventFlowRunner.run_route` builds each hop's
`choices` from `hop_answers`, so the walk of a variant answers the variant's
option; the flow validator asserts `hop_message_count` for every variant
(its failure line still names the route, variant and hop); and
`tools/content_suite/catalog_analysis_run.gd`'s `_selections_contain` reads
`hop_answers` for a flow route, so a catalog request that selects option 2 of
a question is contained by exactly the variant that answers option 2 -
`pick_measured_preset_id` resolves that option to the variant's preset and
`readiness_group` accepts the pair - while a variant carrying neither field
reads as before. A variant that is not a `variants[]` entry (a v13 visit
stand-in) has neither field. Synthetic proof:
`tests/test_event_analysis_group_flow.gd` (a two-option QC.MES whose option 2
plays one message: the second variant validates, and a count without its
answer, an answer without its count and a wrong count each fail naming
`h4`) and `tests/test_catalog_analysis_run.gd` (the selection and helper
rules).

The runtime side (`tools/content_suite/event_analysis_group_flow_validation.gd`,
a sibling of the shared `event_analysis_group_validation.gd` rather than a
branch inside it, since a flow's hops have no per-route caller/callee pair
to interleave into that script's existing branches) runs each hop as its own
`content_core/mes_route_probe.gd` call from the state the hop before it
left - the same hand-chained technique `ep12_hotel_chain_probe.gd` and
`ep12_date_entry_probe.gd` used to measure the real chain, not one
continuous walk, because reaching some of a date's own branches needs a
state seeded directly at an interior offset rather than reached by natural
execution. A `tool_seeded` gate is written into the state before its hop
runs; a `baseline`/`written_by:` gate is only checked. Each hop's declared
`outcome` selects how the probe is asked to stop: a natural terminal for
`script_return` / `script_handoff_boundary`, `stop_before_dispatch` for
`script_dispatch_boundary`, and the existing "no catalog choice" stop for an
observed but unanswered `def_selection_boundary`. A shifted record, a wrong
message count or a missed gate fails with the hop named, exactly as the
work asked. Both the single-profile CLI (`validate_event_analysis_group.gd`)
and the shared multi-profile one (`validate_event_analysis_groups.gd`) now
dispatch a v14 profile to this validator by its own declared `schema`
(EP-12 part 2); `01m_a_date_v14.json` (EP-12 part 3) is the first real
profile to run through it, in the `GROUPS_SUMMARY` row alongside every other
schema's own members.

`tools/build_event_flow_profile.py` builds a v14 profile from a spec naming
only each hop's own entry, its outcome's offset/status/target, message
count, gates, answers and expected state, plus the origin's guard offsets
and the route's baseline/guard_cases/variants: every record shape (`end`,
`op`, hash, source binding) is read from the original bytecode, and each
hop's own `entered_by` is derived from the hop before it by the same rule
the audit checks, never hand-supplied, so a shifted spec cannot silently
produce a mismatched chain. It is not run against the authoritative archive
by this part of EP-12.

**EP-12 catalog part (2026-09-24)** carries a v14 flow into the catalog and
the Event Player. The hop-chain walk itself moved out of
`event_analysis_group_flow_validation.gd` into a shared
`tools/content_suite/event_flow_runner.gd` (class `KakyuEventFlowRunner`,
TD-05): `KakyuEventFlowRunner.seed_flow_state(route, writes, documents)`
applies `state_context` then `writes` (baseline + variant writes, the same
order as before) and returns `{ok, state, checks}` so a caller (the guard
witness loop, or the runner's own per-variant seeding) still runs its own
`_check` accounting over `checks`'s labelled entries.
`KakyuEventFlowRunner.run_route(probe, provider, documents, route, variant,
options)` walks `route.hops` from `route.origin.offset`, writing a hop's own
`tool_seeded` gates into the carried state and only reading any other gate
(`gate_reads`, left for the caller to judge), building each hop's
`probe.run_route` request (`stop_before_dispatch` for a
`script_dispatch_boundary` outcome), and returns `{ok, failures, seed_checks,
hops:[{hop_id, entry, start_coordinate, run, gate_reads}], trace, messages,
state, state_object, state_diff, terminal}` - `trace`/`messages` concatenated
in hop order, `terminal` the last hop's own natural `run.terminal` (with
`target`). The flow validator now only compares that raw data against each
hop's own `expected` block, in its own wording; `catalog_analysis_run.gd`
uses the same runner for a promoted flow row: `resolve_group_route_reference`
now returns the resolved profile's own `schema`, and `run_group_route`
branches (`_run_group_flow_route`, its own function, not `if` arms in the
existing path) to run the whole hop chain and match the last hop's own
terminal with `catalog.match_terminal`, exactly as any other row's terminal
is matched - `build_group_route_descriptor` does not apply (a flow route has
no per-route `caller`/`callee`/`origin_offset`). `_selections_contain` also
gained a `route.has("hops")` branch: a flow route's measured answers live on
its own hops (`hop.answers`), not on the variant (a flow has exactly one
variant per route, nothing to disambiguate), so a request's selection is
checked against every hop's own answers instead of `variant.selections`.
(Since 2026-10-04 the variant's own `answers` count too: the check reads
`KakyuEventFlowRunner.hop_answers(hop, variant)`, the hop's answers with the
variant's overrides applied - see "Variant `answers` and `message_counts`"
above.)

The registry (`tools/build_event_names.py`) and the promoter
(`tools/promote_analysis_groups.py`) both learn flows in this part. A v14
profile's route is now one registry site of its own - its `hops[0]`'s own
outcome (the flow's first dispatch: for `01m-a-date`, `01M.MES` ->
`A_PIC.MES` at 11148, command 15, confirmed directly against the archive
with `mes_basic_block_ir_v6.decode_mes` since a hop's own outcome record
carries no `command` field) - keyed additionally by the route id, since every
route of one flow shares that dispatch; a route's own `number` is
`date-<route id tail>` (`a-date-town` -> `date-town`) rather than a
callee-stem suffix, and the id regex allows that one hyphenated shape. See
`config/contracts/event_names_v1/README.md`'s 2026-09-24 (EP-12 catalog
part) revision for the full rule and the three ids it declared
(`miko.town.station.date-town.1` and its `date-date5`/`date-hotel`
siblings). `promote_analysis_groups.py` promotes a v14 profile's route
directly (`build_flow_row`, its own function): `event_id` anchors the
flow's own *origin* guard (`original/<route_id>/<origin caller
stem>-<hex8 origin.offset>`, e.g. `original/a-date-town/01m-00002af7` -
`01M.MES:10999`, not the registry site's own dispatch coordinate),
`display.title`/`character_ids`/`scene_kinds` come from the registry row
(a flow route has no v4 document of its own to carry a title), the row's
one preset per variant composes `baseline` + variant `writes` + every hop's
own `tool_seeded` gate writes, `choices` is one entry per hop `answers` item
(its single measured option; since 2026-10-04 also every other value a
variant's `answers` gives that hop at that boundary, see "Variant `answers`
and `message_counts`" above and `build_flow_choices`: the hop's own value
first, then the variants' in order, each leading to the row's one terminal,
`source_row` the option's position), and `terminals` is the route's own `terminal`
mapped as a v4 `root_handoff` would be (`root_replacement` /
`normal_completion` / `script_handoff_boundary`) at `sequence` 0.
`CATALOG_REVISION` 29; `EXPECTED_PAIR_COUNT` (registry) 131,
`EXPECTED_CATALOG_COUNT` 145. A flow route still has no v4/v5 event
definition of its own in this unit - that shape is a separate, later owner
decision - so a test or the batch that demands one per catalog row excludes
a v14-backed row by its group's own profile schema.

**EP-12 / WD unit 2 (2026-09-25)** landed that separate decision as
`kakyu_event_definition/v6`'s own `flow` block (`docs/spec/data/
event_definition_v6.md`) and its producer, `tools/project_event_definition_v6.py`:
a `build_flow_document` function of its own for the three `01m-a-date`
sites, wrapping `project_event_definition_v5.py`'s whole pipeline
(schema/fingerprint patched) for every other registry row, exactly as v5
wraps v4's. `validate_event_analysis_group.gd --replay` gained a v14 branch
in the same unit: a v14 profile now writes a replay too (`schema
kakyu_event_analysis_group_replay/v2`, `runtime_schema
kakyu_event_analysis_group_runtime/v14`, one row per route
`{route_id, origin, terminal, variants[]}`, each variant
`{variant_id, writes, reached, hops[{hop_id, entry, start_coordinate,
messages, message_count, state_changes, terminal}], messages, final_state,
state_changes, terminal}`), read straight from `KakyuEventFlowRunner.run_route`'s
own per-hop data through the same `_shared` pure helpers
(`_message_rows`/`_replay_terminal`) the v6/v13 replay path already uses -
one code path for the CLI's `--replay` flag regardless of profile schema.
`tools/project_event_definitions_batch.py --contract v6` dispatches a row
whose group names a `kakyu_event_analysis_group/v14` profile straight to
the site path (`project_event_definition_v6.py`'s own flow construction,
never the v3/v4/v5 site-evidence resolver, which cannot resolve a route
with no `caller`/`callee` pair at all); every other row goes through the
same code the `v4`/`v5` flags already use. `config/event_definitions/v6/README.md`
records the first projection (145/145 valid) and its own measured
divergence from v5's frozen documents (most of the 142 non-flow documents
gained more resolved effect rows from a witness corpus that grew after v5
froze, not from any change to the producer's own decision rules).

**EP-12 B date template unit (2026-09-25)** generalized `project_event_definition_v6.py`'s
own `FLOW_SITES` table from three hardcoded ids naming one profile stem/group
id (`01m_a_date_v14`/`01m-a-date`) to a per-site table naming each site's own
`route_id`/`profile_stem`/`group_id`, and added heroine B's three sites
(`01m-b-date`) alongside A's - the same generalization the new
`tools/draft_date_flow_specs.py`/`tools/content_suite/cli/measure_date_flow.gd`
pair makes on the measuring side (`docs/spec/mes/b_date_flow.md`). Adding a
further heroine's three sites (C..L, a later batch unit) needs only three
more `FLOW_SITES` entries, not a code change. `CATALOG_REVISION` moved to
30; `EXPECTED_PAIR_COUNT` (registry) to 132, `EXPECTED_CATALOG_COUNT` to 148.
`config/event_definitions/v6/README.md` records the regeneration (148/148
valid).

**EP-12 C..L date batch (2026-09-25)** replaced that per-site `FLOW_SITES`
table with `_flow_meta`, a derivation from a site's own registry row
(`aliases.groups`) cross-referenced against the declared profiles' own
`schema == "kakyu_event_analysis_group/v14"` field - the same test
`tools/project_event_definitions_batch.py`'s own `flow_group_ids`/`row_is_flow`
already used to route a row to the flow path, not a second, hand-kept fact.
A new heroine's flow group now needs no code change here at all, only its
own declared profile and registry row. Proven byte-for-byte identical to the
prior hand table's own behavior for A's and B's six sites before the ten new
groups' own documents were projected (`_flow_meta` returns the exact same
`route_id`/`profile_stem`/`group_id` the table did, and the six regenerated
documents differ from their tracked siblings only in `names_fingerprint` and
`package_binding.package_sha256`, the registry/package moves this batch also
made). `CATALOG_REVISION` moved to 31; `EXPECTED_PAIR_COUNT` (registry) to
142, `EXPECTED_CATALOG_COUNT` to 175. `config/event_definitions/v6/README.md`
records the full regeneration this batch also ran (175/175 valid), needed
because a v6 document's own `package_binding.package_sha256` must agree with
its index's single package reference - unlike v4/v5, which this batch's own
instruction kept frozen (`names_fingerprint` carried into their tracked
documents and indexes only), v6 is not exempted from full regeneration when
its own registry or package moves.

**EP-12 gallery SCENE tools (2026-10-04, owner ruling 2026-10-04)** make the
album's scenes declarable as v14 flows, one analysis group per `?_M.MES` menu
and one catalog row per scene (the measured family is
`docs/spec/mes/gallery_families.md`). No contract changes; five tool changes:

- **Menu drafter and measurer.** `tools/draft_menu_flow_specs.py` reads a
  menu statically (the typed IR through `tools/mes_route_decode.py`, no
  execution) and writes a recipe: for every nested `CALL SCENE_*` its page
  test (`global_u8[20] == page`, ordinary scenes only), slot test
  (`state_u16[18] == slot`; slots 1..4, and 9..17 for the H scenes), unlock test
  (`global_u8[flag] == 1`, flags one consecutive run), dispatch record, the
  scene's routine-40 sites, a recap scene's state cells (cells its branches read
  that the heroine's `?_DATE5.MES` writes 1 to and `?_HOTEL.MES` writes 2 to)
  and its census twins. It stops with a named error (`menu shape mismatch: ...`)
  when the menu is not that template, when a dispatch is not a `SCENE_` entry
  of the menu's heroine, or when the `GIRLS.MES` ambient writes it relies on are
  gone. `tools/content_suite/cli/measure_menu_flow.gd` takes the recipe and writes
  one `tools/build_event_flow_profile.py` spec per scene: hop 1 the menu from the
  route's origin (the page test of an ordinary scene, the slot test of an H
  scene) to the scene's nested-call record with zero messages, hop 2 the scene
  entered by that call to its own `script_return`, a rejected guard case with
  the flag cleared, and the first option answered at each of the scene's own
  questions. **The menu selection is a seeded state - a tool decision**: the menu's
  own selection record (command `0x15`) cannot run in the tools, so the
  baseline writes the ambient cells a gallery visit starts from
  (`state_u16[19] = 1200`, `[8] = 0` as `GIRLS.MES` leaves them, `[21] = 4`
  from the title answer), the page, the slot's A6 record id in `state_u16[18]`
  and the scene's unlock flag. A recap scene's default route seeds its cells
  to 1 (the DATE5 path). The route's own path is its **default variant**; what
  the scene can otherwise do is **declared as variants** (EP-12 all-menus unit,
  2026-10-04, advisor note (c): the measurer writes them, there is no hand-written
  spec pass): the measurer walks the scene's questions depth first (every option
  of each question, in option order, with the answers given so far) and every
  answered combination that ends at the route's own `script_return` is a variant
  with `answers` (only what differs from the default path), named
  `option-<values in the order asked>` (`option-2`, `option-2-1`: a two-question
  scene declares each of its other answered combinations); a recap scene's
  second path (its four cells all 2) is the variant `hotel-path` with the cell
  writes. A variant carries `message_counts` only when it plays another number of
  messages than the default. `tools/content_suite/menu_flow_variants.gd` holds
  these rules (synthetic proof `tests/test_menu_flow_variants.gd`). **Stop rule**
  (above): a path that ends at another record, or does not return, is not a
  variant - the measurer names it in the route's `unresolved` list and its
  report. A question that exists only on a variant's path (the default path never
  asks it) gets its own `choice_contracts` entry and a variant-supplied answer,
  and a default question a variant's path never reaches is reported as skipped;
  both are listed per route in the report (`variant_only_questions`,
  `skipped_questions`) because the default play request could then pick an
  option the default preset refuses. A scene that nests helper scripts (the
  `*_PIC.MES` standing-picture scripts: four scenes, `SCENE_A15`, `C08`, `H05`,
  `M14`) cannot return unless those entries are loaded: the drafter lists each
  scene's nested entries, transitively, as `nested_members`
  (`_nested_members`), and the measurer loads them and adds them to that scene's
  `source_members` (the same practice as the date flows that nest them).
- **Names.** `tools/build_event_names.py` accepts a `SCENE_<letter><number>` /
  `SCENE_<letter>_H<nn>` callee dispatched from one of the 13 album menus
  (`<NAME>_M.MES`): id `<heroine>.special.<menu stem>.<number>.1` (for example
  `minatu.special.minatu_m.03.1`, `...h01.1`), the `special` category
  fall-through (the id regex is unchanged), numbered by the callee stem; the
  route id must spell the same scene (`j-scene-03`, `j-scene-h01`). Provisional
  titles read "in the album".
- **Catalog row.** `tools/promote_analysis_groups.py` gives a gallery flow row
  `display.categories = ["gallery"]` and, because a scene flow ends in its own
  `script_return`, **two terminals** - `callee_return_only` (`script_return`,
  sequence 10, the scene's closing record, the one a run observes) and
  `analysis_boundary`/`loop_boundary` (sequence 30, owner the menu, coordinate
  the first hop's dispatch end, never observed by a flow run: the menu
  resuming into its next selection is a measured fact of the study, not a hop).
  That is the pair the two `15C.MES` returning-callee rows already carry, so
  the catalog-side route outcome is `place_menu`; `tools/event_outcome_vocabulary.py`
  reads a two-hop flow whose first hop ends in `script_dispatch_boundary` and
  whose second is a `nested_call` hop ending in `script_return` the same way
  (`place_menu`); any other returning flow stays `unresolved`
  (`flow_return`). Tool decision. The Event Player phrases the matched
  `callee_return_only` terminal by this route outcome ("Back to the place
  menu") since Core 0.369.0 (`matched_terminal_outcome`, revision of
  2026-10-04 above).
- **`duplicate_route`** (tool decision). A gallery scene whose callee is
  *message-identical* to a callee that already has a catalog row is classified
  `duplicate_route` with `canonical_event_id` = that row, and nothing else about
  the row changes (it stays a playable route of its own, `minimal_playback`).
  "Message-identical" is the census definition of
  `tools/audit_duplicate_entries.py`: the ordered sequence of the entry's
  message records hashes equal (`config/event_catalog/duplicate_entries_v1.json`),
  which says the *content* is identical, not which entry the product owns.
  `gallery_copy_of_event` groups give the EVENT callee as canonical (a callee
  with more than one row is ambiguous and stops the tool); `gallery_internal`
  pairs give the first entry name (the four H/K pairs: the H scene) as canonical;
  `gallery_copy_of_other` groups (a scene copy of an `?_END.MES`, which has no
  row) stay ordinary rows. A copy with no row of its own, or whose canonical has
  none yet, is left alone and takes the classification when both exist.
  `promote_analysis_groups.py --duplicates` names the census.
- **v6 projection of an album scene** (`tools/project_event_definition_v6.py`,
  `is_gallery_registry_row` in `tools/payload_values.py`, shared with the promoter): the flow document's terminal is `callee_return`, its
  `dependencies` are only the entries the route's own hops run (the group
  declares every scene of its menu as a member) and its first `unresolved`
  line names the scene's unlock test instead of the date guard's text
  (`docs/spec/data/event_definition_v6.md`, "Album-scene flows"). Date flows'
  documents are unchanged.

Heroine J's album was the first declaration (2026-10-04): `CATALOG_REVISION`
35, `EXPECTED_PAIR_COUNT` (registry) 179, `EXPECTED_CATALOG_COUNT` 214
(`docs/spec/mes/gallery_families.md`, "Declared"). The other twelve menus
followed in one unit the same day (J re-measured with its variants):
`CATALOG_REVISION` 36, `EXPECTED_PAIR_COUNT` 519, `EXPECTED_CATALOG_COUNT` 554,
365 album rows of which 33 are `duplicate_route`, 91 variants
(`docs/spec/mes/gallery_families.md`, "Declared: all albums"). The Playback pass
of `validate_catalog_group_routes.gd` asserts the place-menu status line for
every row carrying `gallery` in `display.categories` (no id-prefix test) and
reports the count as `gallery_rows_checked` (the shards sum to 365).

**EP-12 H tools (2026-10-04, owner ruling 2026-10-04: H is not a gallery family -
13 ordinary `43C.MES` sites).** The 13 `?_H.MES` recollection ladders are called
by the protagonist's room behind `state_u16[13] == id`, reached through answer 3
of its room-action menu (`docs/spec/mes/43c_caller_group.md`). One v14 group and
one route per ladder (`43c-<name>-h`, route `<letter>-h`; one group for all 13
would pull the other 12 ladders into every row's `required_entries` and every v6
document's dependencies). Tools:

- **Static drafter and measurer.** `tools/draft_recollection_flow_specs.py` finds
  the room's side (the 13 id tests and calls, the clock save the tests start
  after - the route's origin - the `state_u16[21] == 1 / 2 / 3` chain back to the
  question, the return chain to the loop head) and each ladder's **gates** by a
  structural rule (a single `global_u8` flag test, `== 1` or `!= 0`, on the main
  path: not a tail cell `[11]`/`[2573]`, not a presentation cell, not a selector
  cell compared with another value, not enclosed by the skip span of a non-gate
  branch; gates nest; a pure OR of such flag tests is transparent, its member cells
  that are tested as flags inside it gates and the others `guard_only_cells`), and
  reports every other branch cell under its reason (`excluded`). It is not a byte-skip
  rule and not the menu template (`draft_menu_flow_specs.py` is unchanged).
  `tools/content_suite/cli/measure_recollection_flow.gd` seeds the room's selection
  (**a tool decision**: `state_u16[13]` the picker id, `[21]` 3 - the question is a shape
  the choice-contract tool cannot name and the id is the native secondary
  selection's result, which `43C.MES` never writes - and the room's evening ambient
  cells `state_u16[19] = 2015`, `[8] = 0`, `global_u8[2573] = 0`), runs the two hops
  through the shared call frame and writes one `build_event_flow_profile.py` spec per
  ladder: hop 1 the room from the clock save through the id test to the ladder's
  nested-call record (no message), hop 2 the ladder from its start to its own
  `script_return` with `segment_budget` 1024. It stops when a recipe gate is not
  evaluated and taken under the full recollection.
- **Variants.** The default variant is the **full recollection**: the baseline sets
  every gate cell to 1. The second, `no-recollection`, writes every gate cell 0 (a
  room before any of the events); it must end at the same `script_return`. Both are
  assembled by `menu_flow_variants.gd`, whose recap `hotel-path` is now one instance of a
  named **cell-write variant** (`cell_variant`, `assemble`'s `cell_paths`; synthetic proof
  `tests/test_menu_flow_variants.gd`). Per-segment combinations (2^n) are not walked.
- **Hop `segment_budget`** (above): a ladder needs 417..649 segments.
- **Names.** `tools/build_event_names.py`'s `heroine_letter_and_number` resolves an
  `<ENGLISH NAME>_H` callee by the heroine table in reverse, number `h`; a ladder is
  accepted only from `43C.MES` with a flow route whose id is `<letter>-h`. Rows read
  `<name>.town.43c.h.1` (the `town` category of a digit-and-`C` floor, place `43c`).
- **Display.** `promote_analysis_groups.py`'s `build_flow_display` tags a flow row
  `date` when the registry number is `date-*`, `gallery` for an album scene, and else
  - the ladders - `["character_event", <registry category>]` like an ordinary site row.
- **TD-43 closed.** The v6 projector's first `unresolved` line of a non-album flow
  document is generated from the guard conjuncts it already reads
  (`flow_done_flag_line`) instead of heroine A's date guard text.

Declared in the same unit: `CATALOG_REVISION` 37, `EXPECTED_PAIR_COUNT` (registry) 532,
`EXPECTED_CATALOG_COUNT` 567 (the 13 ladder rows, all `minimal_playback`, route outcome
`place_menu`: a two-hop flow whose first hop dispatches the ladder and whose second returns
- the same rule as an album scene, `tools/event_outcome_vocabulary.py`), Core 0.370.0
(`docs/spec/mes/43c_caller_group.md`, "Declared: the 13 recollection ladders").

**EP-12 TALK tools (2026-10-04, owner ruling 2026-10-04: one row per called script,
anchored at its confirmed caller; Core 0.371.0).** The measured family is
`docs/spec/mes/talk_family.md`. No v14 change: a TALK route is a three-hop flow
(a plain script's a two-hop one) built from the existing hop grammar, the
`resume` hop included. Tools:

- **Static drafter and measurer.** `tools/draft_talk_flow_specs.py` finds, in the
  `01M.MES` ladder block of a heroine, the block guard (the first branch holding
  her `global_u8[351] == id - 1` draw, the route's origin), the picture and intro
  calls, the gate (`banked_u16[199 + id] > 20` and her today flag clear), the eight
  rung tests (`< 31` ... `< 91`, then `> 90`) and calls, the PROMIS guard and call
  and the outro call; for each rung script the return records and every follow-on
  call (`<letter>_TALKXX.MES`) with the conditions enclosing it; and, for a plain
  `<letter>_TALK.MES`, its anchor caller's guard (`PLAIN_ANCHORS`: K at
  `27C_EV.MES:31343`; the other scripts' anchors since the 2026-10-05 unit, below). It seeds the **natural state at the anchor** (tool
  decisions, labelled in each route's `unresolved`): the guard's first
  alternative (weekday 0, the clock inside its window, the first full hour),
  `global_u8[351] = id - 1`, the heroine's presence flag 1, her block flag and
  today flag 0, the affection word in the rung's band (`limit - 6`, 100 for
  `TALK00`), the date 401 and the cells no guard names. It stops with a named error
  (`talk shape mismatch: ...`) when a block is not that template.
  `tools/content_suite/cli/measure_talk_flow.gd` takes the recipe and writes one
  `build_event_flow_profile.py` spec per route: hop 1 the caller from the
  guard through `?_PIC`, `?_INTRO`, the gate and the rung test to the rung's
  call (`stop_before_dispatch`), hop 2 the script from its start to its own
  return answering option 1 at every question (each contract built from the
  live stop), hop 3 the caller resuming at the call's end through `?_PROMIS` (when
  the flag is up) and `?_OUTRO` to its natural end, the `MACHI.MES` handoff. It
  checks the two guard witnesses the way the flow validator does and stops when
  a default question is not nameable, the default path does not return at one of
  the script's own return records, or hop 3 does not end at a handoff or a return.
- **Variants.** The default path is the natural state (every topic done-flag 0)
  and option 1. The measurer walks every other answered combination depth first
  (`detect_loops` on, hop 3 run for each path that returns) and declares through
  `menu_flow_variants.gd`: an `answers` variant `option-<values>` for each path
  that ends at both of the route's own outcomes (its `message_counts` name hop 2
  and hop 3 when they differ); a follow-on call behind a single `global_u8` flag
  is a named cell variant `flag-<cell>` (the flag flipped; `K_TALKXX` sits inside
  option 1's arm behind `global_u8[2194] == 0`). A path that re-asks a question it
  answered (the topic hubs' decline arms), that does not return or that ends
  elsewhere is not a variant (the stop rule): it is counted in the route's
  `unresolved` line and the report. A follow-on behind neither an answer arm nor a
  single flag stops the tool.
- **Plain script, two hops.** The caller of the plain script resumes into the
  place's day loop (`27C_EV.MES` `48649`), which runs on day after day: its definition 12
  stops at the probe's step limit under the fresh state and, under the original
  calendar, the loop plays through to the game's ending (`END1.MES`). There is no
  natural end to measure, so the plain route ends at the script's return like an album
  scene, and the existing returning-flow rule reads it as `place_menu`.
- **Contract.** The natural presence state registers the ids 0, 2, 3, 4, 5, a
  sparse catalog whose consumer splits positions on scratch cells: the routine-40
  contract tool admits it as a fourth shape (`docs/spec/mes/format_and_method.md`,
  Core 0.371.0, `position_gates`; every installed contract rebuilds byte for
  byte).
- **Names.** `tools/build_event_names.py`'s `TALK_STEM` (`<letter A..L>_TALK` with
  an optional two-digit band): a flow route `<letter>-talk-<band>` (`band` =
  `30`..`90`, `00`, `plain`) numbers its row `talk-<band>`; the id
  `ai.town.station.talk-30.1` (the caller `01M.MES` is the `town`/`station`
  place already). A route id that names another script or heroine, and a TALK
  script without a flow route, stop the tool. The follow-on `<letter>_TALKXX` is not this rule
  (Tina's `M_TALK` and the characters' `N_TALK`..`Q_TALK1` joined it on 2026-10-05, below).
- **Display and outcome.** `promote_analysis_groups.py`'s `build_flow_display`
  tags a TALK row `["conversation", <registry category>]`, neither `date`, `gallery`
  nor `character_event`. The route outcome needs no new rule: a three-hop flow
  ending at the `MACHI.MES` handoff is the existing handoff outcome (`map_return`,
  town: "Back to the town map"), a two-hop returning flow `place_menu`
  (`tools/event_outcome_vocabulary.py`; pinned by `tests/test_event_outcome_vocabulary.py`).
- **TD-46 closed: the timeout rule.** A check's timeout is at least twice its duration in a
  loaded whole-batch run (`--jobs 6`), not twice its solo duration (four archive-tier checks
  sat at 0.43-0.49 of their timeouts alone and 0.50-0.64 loaded): `original dispatch naming
  beyond the strict decode`, `original playback op profile` and `original event corpus
  literal dispatch inventory` 300 -> 600 s, `original Event Catalog source bindings` 120 ->
  240 s (`config/validation/checks_v1.json`).
- **v6 producer (checkpoint B, tools only).** `tools/project_event_definition_v6.py`: the entries that
  resolve a flow's replayed lines include every entry that played one (the inline nested `K_PIC`,
  `K_INTRO`, `K_OUTRO` of a rung's hops; no earlier document moves), and a TALK row's `dependencies` are
  the group members its own route runs (`talk_route_entries`: lines played in any variant, silent nested
  scripts dispatched inside a hop's span, minus the other routes' callees), the album branch's counterpart,
  selected by the shared `is_talk_registry_row` (`tools/payload_values.py`, with `TALK_STEM`)
  (`docs/spec/data/event_definition_v6.md`, "TALK flows"; `tests/test_project_event_definition_v6_talk.py`).

Declared in the same unit (heroine K, `docs/spec/mes/talk_family.md`, "Declared: heroine K"): `CATALOG_REVISION` 38,
`EXPECTED_PAIR_COUNT` (registry) 541, `EXPECTED_CATALOG_COUNT` 576 (the 9 rows, all `minimal_playback`, the eight
rungs route outcome `map_return`, the plain script `place_menu`), the groups `01m-k-talk` (eight routes, 14 variants
in the replay) and `27c-ev-k-talk`, Core 0.371.0.

**EP-12 TALK tools, the other heroines, Tina and the characters N..Q (2026-10-05, unit
`analysis/_docs/ep12_talk_rest_spec.md`; Core 0.372.0).** The K tools above generalise; nothing in v14 or in the
v6 document contract changes. What is new:

- **Contract schema v6.** The routine-40 contract schema is `kakyu_mes_routine40_choice_contract/v6` (the
  scratch-split consumer's `position_gates` key belongs to it; `v5` is a prior schema that validates without the
  key and is refused with it). Every installed `v5`/`v4`/`v3` contract stays byte for byte
  (`docs/spec/mes/format_and_method.md`, "The schema is v6"); `tools/audit_event_analysis_group.py` accepts `v6`.
- **One predicate for every TALK script.** `tools/payload_values.py`'s `TALK_STEM` / `talk_script_parts` /
  `is_talk_registry_row` now cover `<A..L>_TALK<band>`, the plain `<A..L>_TALK`, Tina's `M_TALK` and the characters'
  `<N..Q>_TALK[<digit>]` (the follow-on `<L>_TALKXX` is not one); the registry builder, the promoter and the v6
  projector all use it. The registry numbers a heroine's script `talk-<band>` (`talk-plain` for a band-less one: `ai.town.27c_ev.talk-plain.1`,
  Tina's `tina.town.station.talk-plain.1`) and a character's `talk-<letter><digit>` under the heroine key `common`
  (`common.town.27c_ev.talk-n1.1`, `common.town.station.talk-q.1`), the route id `<letter>-talk-<band, digit or plain>`
  spelling the same script (`n-talk-1`, `q-talk-plain`).
- **The drafter reads all twelve ladders** (`draft_talk_flow_specs.py --letters A,B,...,L`). Two shapes K did not
  have: the gate of heroines C and J carries further conjuncts of its own (`global_u8[1775] == 0` for C,
  `[401] == 1` and `[824] == 0` for J), each seeded like the guard's (`gate_extra_atoms`; a conjunct that
  contradicts a seed stops the tool), and J's block calls `J_MINORU.MES` before the outro (`extra_calls`, loaded as a
  block member). C's `C_INTRO.MES` caps the affection word at 50 while the date is below 916 (`date < 916 and
  affection > 50` -> 50, before the rung test): the drafter finds the cap (`intro_affection_cap`) and seeds the date at
  916 for her eight rungs, the first date a rung above 50 is reachable (a tool decision, named in each route's
  `unresolved`); the other eleven keep the ambient date 401. A rung's follow-ons are every call of the heroine's own
  `<L>_TALKXX` or `<L>_TALK<nn>` scripts. The static guard proof (`holds`, `_prove_guard`) evaluates the seeded
  baseline against the guard and the rejecting write against the same guard before anything is measured; a guard of
  alternatives is rejected by a cell every alternative pins with an `equal` conjunct, written to a value none of them
  holds (heroine A's day-loop guard pins her block flag to 0 and 1: written 2).
- **Band-less scripts at their anchors** (`PLAIN_ANCHORS`, a table of `(caller, call offset)` per script). The rule
  that picked each: the preferred caller is `27C_EV.MES` (every plain script has sites there; heroine K's anchor of the K
  unit), `01M.MES` for `M_TALK` (the study's anchor) and `Q_TALK` (no site in `27C_EV.MES`) and `11M.MES` for `N_TALK2`
  and `N_TALK3` (no site there either); within it the lowest-offset site whose block is the script's own - a guard
  that encloses the call with only picture scripts dispatched between the guard and the call (a block that plays
  another script first, `E_TALK` at 1746 after `N_TALK`, would run it inside hop 1) and, for a heroine's plain
  script, a guard its own gate can be solved together with (`I_TALK` at 11661 and 12390 test a special date its gate
  excludes). The picture script is any `*_PIC.MES` (`M_TALK`'s block calls `O_PIC`), or one the block's own lines separate from
  the call (`N_TALK2`: `N_PIC`, then lines of its own, then the call). A heroine's plain script seeds the guard and its own once-only gate (its first branch: date,
  affection word and done flag); a character's script is a chain of bodies selected by flags and dates and is seeded by
  the guard alone, every other cell 0 (the natural state: the body that state selects plays).
- **Two hops or three, by measurement.** The recipe says `resume_hop: false` (two hops) for the twelve anchors
  (`DAY_LOOP_ANCHORS`) whose resume was measured to run into the `27C_EV.MES` day loop and stop there with no natural
  end - heroine K's (2026-10-04) and the eleven others' (2026-10-05, each re-run with `"auto"` rather than inherited
  from K's site) - and `resume_hop: "auto"` for every other anchor: the measurer runs hop 3 once on the default path
  and keeps it when the caller reaches a handoff or a return, else records the stop in the route's `unresolved`
  (`report.hop3_probe` either way). Of the 14 `27C_EV.MES` anchors, `N_TALK` stops at a question of the next block's
  script and `N_TALK1` (the entry's last block) reaches the `FLOOR5.MES` handoff: both are `"auto"`. A question the contract tool cannot name, met by an answered
  path other than the default one (heroine J's three, `docs/spec/mes/talk_family.md`), is a path that does not
  run to the route's terminal: not a variant, named in `unresolved`; one on the default path still stops the tool.
- **Tests.** `tests/test_draft_talk_flow_specs.py` (33 cases: the guard witnesses, the further gate conjuncts, an extra
  call, a numbered follow-on, the intro cap, a character script seeded by the guard alone, a block with no picture,
  a chained block, the OR guard's rejecting write), `tests/test_event_names_registry.py` (Tina's and the characters'
  rows), `tests/test_project_event_definition_v6_talk.py` (the shared predicate), `tests/test_event_definitions_tracked.py`
  (the TALK sites derived from the registry: every heroine with a ladder holds all eight bands).

Declared in checkpoint B of the same unit (`docs/spec/mes/talk_family.md`, "Declared: all heroines, Tina and the
characters N..Q"): `CATALOG_REVISION` 39, `EXPECTED_PAIR_COUNT` (registry) 646, `EXPECTED_CATALOG_COUNT` 681 (the 105 rows, all
`minimal_playback`, 90 route outcome `map_return` and 15 `place_menu`), 26 new groups (28 with heroine K's two; 26 new
`original event analysis <caller> <letter> talk` checks, 295 -> 321 entries), Core 0.372.0.

Follow-up of 2026-10-05 (`docs/spec/mes/talk_family.md`, "Hop 3 of the 14 `27C_EV.MES` anchors, measured"): the 13 `27C_EV.MES`
anchors that had inherited heroine K's two-hop result were re-measured with `resume_hop: "auto"`; `N_TALK1`'s caller reaches the
`FLOOR5.MES` handoff, so its row is three hops and `map_return` (route outcomes over the 681 rows: 255 `map_return`, 415
`place_menu`, 11 `chain`), `CATALOG_REVISION` 40, `27c_ev_n_talk_v14.json` rebuilt (the `27c-ev-n-talk` group re-hashed, `N_TALK`'s route
re-measured with it and two hops still); the registry, its fingerprint and Core 0.372.0 are unchanged.

0.315.0 lets a caller-continuation route declare its post-guard truth: V5 and
V8 routes may carry an optional `post_guard_expected` (0 or 1), overridable
per variant, checked with V6's own type rule (`_audit_root_replacement`'s
rule, now shared). No schema number changed - a profile that omits the field
keeps the prior unconditional behavior, asserting rejection, so every
existing profile is unchanged. The reason is a real caller whose local guard
is a pure calendar disjunction with no self-clearing flag: the caller's own
clock nudge on resume closes it only when that nudge happens to cross one of
the guard's own boundaries, and stays open for every other accepting arm, so
a fixed "must reject" assumption cannot describe it. V9 remains unguarded and
keeps rejecting the field on both route and variant, exactly as V7 does - an
unguarded route has no local guard for a post-guard truth to describe. The
runtime's own per-variant `reentry` override, already honored for V5 and V9,
now also applies to V8: a validator bookkeeping gap, not a schema change, had
left it inert there.

Routine-40 contract validation also uses the shared canonical JSON comparison
for nested fields. In-memory integers and transported whole floats now compare
equally; fractional coordinates, changed definitions and result consumers still
fail. The choice contract remains V3: the accepted data meaning is unchanged.

The probe's registered-definition calls set `exclude_provenance_steps: true`
in the runner context: inert `1F` source markers and `17` entry labels do not
consume the 10,000-command limit. This preserves bounded trace/state parity
when a package omits those records. Default runner calls retain record-count
limits, and native presentation boundaries retain their existing behavior.

This document defines the shared content boundary used by the remake and its
standalone content tools. Original game archives are user-supplied, read-only
inputs. They are never project assets, authored source, or distributable tool
data.

Related documents:

- [Tooling](tooling.md)
- [Content Suite Product Goals](content_suite_product_goals.md)
- [Event Player Product Goal](event_player.md)
- [Architecture](architecture.md)
- [Asset Resolution](../systems/asset_resolution.md)
- [MES Format and Method](../mes/format_and_method.md)

## Playback package membership revision, 2026-09-16

Core `0.323.0` widens the full original package's membership to every
`mes.arc` entry a committed analysis-group profile lists as a source member
(owner ruling (a), WD-21): 228 entries instead of 17, the catalog still
the only source of `manifest.events`. The schema stays
`kakyu_playback_package/v7`; the manifest's `membership` and
`incompleteness` blocks and the per-entry `bound_by` list are additive and
checked fail-closed when present. Details in the
[workspace export contract](../data/workspace_playback_export.md); the
separately maintained remake schema document was not edited.

## Playback package catalog binding revision, 2026-10-06

The manifest's `source.catalog_id` and `source.catalog_revision`, written as
`""` and `0` since the split, now carry the tracked catalog's identity, and
`serialize()` refuses a build result without a valid binding or without its
`resource_names`. The schema stays `kakyu_playback_package/v7` (the fields
existed); the package hash now moves with `catalog_revision`; the reader does
not read the binding. Details in the
[workspace export contract](../data/workspace_playback_export.md).

## Runner argument-storage revision, 2026-10-11

Core `0.377.0` (TD-56) changes what the generic runner does with command `0x09`.
Command `0x09` now writes the storage that expression token `0xF6` reads,
`global_i32`. That storage is the original's
`common_state + 0x3000 + index * 4`, a confirmed rule whose home is
[Format and method](../mes/format_and_method.md) (the TD-56 section).

Routine 0's message id and routine 23's selector read that storage.
`argument_slots` survives only as per-run provenance. Command `0x16` stays
argument-slot-only, and its storage is unresolved. The route probe now keys
library-reached `DEF_MAIN.MES` rows by their own entry (TD-55).

What consumers see:

- The replays' `state_diff` gains `global_i32` rows.
- The shared media ladders in `LIBLARY.LIB` select by the caller's real
  selector. Routine 9 reaches 25 of its 78 SE rungs, and routine 27 reaches
  44 of its 74 rungs.
- The v7 event definitions change in the delta classes of the TD-56 record,
  including the flags the library now sets. The projector leaves `0x09`
  argument storage out of event effects by a labelled tool decision, D11.
- Catalog revision 43 restores the `LIBLARY.LIB` items: 18,113 items in all.
- The live package is `0e47e063...`.

The package schema stays `kakyu_playback_package/v7`. The member records are
byte-identical. The Playback timeline did not present library-executed media at
0.377.0 (presented since Core 0.378.0, EP-14; the library media revision below).
Details are in `todo/code_health.md` (TD-56).

## Mod bundle revision, 2026-10-11

WD-10 adds the mod bundle without a Core change: the Core stays `0.377.0`, and
no `content_core/` file, delta format (v9) or definition set format (v1) moves.
Everything lands under `tools/`, `tests/`, `config/validation/` and `docs/`.

`kakyu_mod_bundle/v1` is one JSON file carrying a workspace's authored v9
deltas, its translation-only entries (`text_projections`) and its definition
set. It is a tool-to-tool transport, documented in
[Mod Bundle](../data/mod_bundle.md) and not a fingerprinted
`config/contracts/` directory, because the remake never reads one.
`tools/mod_bundle.py` builds it from a workspace (the whole workspace or
nothing), validates it with or without the archive, and extracts its members;
the file is at most 64 MiB, checked on its size before any read.

`tools/content_suite/authored_delta_import.gd` is now a staged-import engine
(`import_members`) with two front doors. `import_delta` is the one-member door
and keeps its result and messages; `mod_bundle_import.gd` (`import_bundle`,
entered headlessly through `cli/import_mod_bundle.gd`) reconstructs every member
of a bundle into one fresh workspace - the deltas into
`authoring/delta-<ENTRY>`, all replacements and then all projections in one
staging call each, the definition set through the set importer - and reopens the
stage to check every effective identity before the existing lock-and-rename
publication. Nothing is merged into an existing workspace (WD-12). A bundle
without a definition set declares its mod in the header, which is verified and
not persisted: the workspace derives `mod_id` from its definitions, so such an
import reports `mod_persisted` false and leaves `mod_id` empty.

The shared helpers the unit extracted (each replaced copies):

- `publish_new_document` in `tools/payload_values.py` is the one hard-link
  publication rule. `authored_mod_delta.publish`, `mod_definition_set.publish`
  and `prepare_mes_editable_ir.publish_new` are wrappers over it with their
  messages and temporary names unchanged; three copies became one.
- `validate_text_edits` in `tools/authored_mod_delta.py` holds the delta's
  text-edit rules, which the bundle's text rows call.
- `python_validated_extract.gd` holds the hash-before/after, `--extract`
  handling, verdict line and tree removal that both importers use; the set
  importer's copies are gone, and `mod_definition_binding.gd` calls its
  `last_json_line` in place of a byte-identical private one.
- `workspace_project_document.gd` builds a workspace project document from a
  content set, moved out of `validate_selection_handoff_original.gd`; the
  Launcher's own copy is left to WD-24.
- Integer fields parsed from the bundle's JSON fold back through the Core's
  existing `ContractValues.intify`.

The playback package, the v7 event definitions and the catalog are untouched:
no re-export and no rebind. The same unit's TD-67 changes the validation
runner's ordering only (`docs/spec/data/validation_checks.md`).

The checks it adds: `tests/test_mod_bundle.py` (67 tests, in the
`python regression suite`); `Godot test_mod_bundle_import.tscn` (local tier,
synthetic mode, 79 checks); and the archive check `original mod bundle
round trip`, which runs the same test over the original `mes.arc` (tier `full`,
900 s, group `original_corpus`, requires `elfimage`; 179.5 s and 179.0 s solo,
the two runs printing an identical PASS line). The registry revision stays 5.
WD-10 closed the same day by the whole batch (run `e6cb6108`, 479 of 479 in 2,546 s,
[Validation Checks](../data/validation_checks.md)), and TD-67 closed with it.
Details are in [Mod Bundle](../data/mod_bundle.md) ("Verified") and
`todo/workspace_distribution.md` (WD-10, closed; WD-24 opened).

## Library media in the Playback timeline revision, 2026-10-11

Core `0.378.0` (EP-14) lets the Playback timeline present the media a shared
`LIBLARY.LIB` routine executes: routine 27's pictures and routine 9's sound
effects, at the line where the script calls the routine. Until `0.377.0` those
rows reached only the probe's signature rows, so the Event Player showed none
of them. The pictures are stills under the EP-13 surface rule; the sound
effects fire and forget through the effect channel EP-10 unit 4 built.

What is added:

- `KakyuMesRouteProbe.MEDIA_EFFECTS`: the five effects the runner emits for a
  media request (`mmo_resource_marker`, `ax_resource_marker`, `voice_marker`,
  `effect_request`, `bgm_request`). `replay_run_media.gd` and the timeline
  read it instead of keeping copies.
- `run_route` returns `library_media`, always present (`[]` when no library
  routine ran): a separate list, in call order, of deep copies of the library
  trace rows whose effect is a media effect. A row is the library runner's own
  row with:
  - `source_entry`: `LIBLARY.LIB`, or `DEF_MAIN.MES` for a row carrying
    `external_definition_id` (TD-55's key); `source_offset` stays the row's own
    library-relative (or DEF-relative) offset;
  - `library_call`: `{routine, caller_entry, caller_offset,
    caller_definition_id}`. `routine` is the routine the caller invoked; the
    row keeps its own `library_routine_id` and `library_call_depth`. From a
    walked entry the caller is that entry and the shared-call record's
    code-relative offset, which is the MES intro anchor of the medium, with
    definition id `-1`. From a registered definition body the caller is
    `DEF_MAIN.MES`, the definition's own shared-call record (DEF-relative) and
    the definition id;
  - `trace_index`: the index in `trace` of the route row after which the
    library ran, the `shared_routine_boundary` row for a call from a walked
    entry and the `definition_invoke_boundary` row for a call from a
    definition body. A call with an empty `trace` is refused
    (`shared routine N has no anchor row`) before the routine runs (a deviation from the unit spec,
    which worded the refusal as made at collection: refusing first leaves the carried state untouched;
    accepted at the C1 review);
  - no `step`: the library runner's counter means nothing to a consumer.
- Loop detection records the list's size in its mark, and the proven loop
  resizes the list with `rows`, so a dropped head drops its media with its
  signature rows.
- `KakyuEventFlowRunner.run_route` returns the combined `library_media`: each
  hop's rows are copied, their `trace_index` offset by the combined `trace`'s
  length before that hop's rows were appended, then added in hop order. Each
  hop report's own `run` keeps hop-local indices.
- `KakyuEventPresentationTimeline.build(trace, messages, terminal_match,
  library_media = [])`. The list is validated first and refused whole
  (`{"ok": false, "error"}`) unless every element is a Dictionary with an int
  `trace_index` inside `trace`, non-decreasing, and an `effect` in
  `MEDIA_EFFECTS`. Rows anchored at index `i` are applied at the end of
  iteration `i`, through the same row handler as a route row: after the anchor
  row's own handling, or, when the anchor is a `dialogue_boundary`, into the
  step it opens. A library row never consumes a message and never counts toward
  a step's rows, so the message grouping and the step count do not change. A
  trailing `dialogue_boundary` with library media anchored at it still forms
  the closing step (`"closing": true`) instead of dropping them, so the step
  count stays the boundary count plus one.
- Every `pictures`, `animations` and `effects` timeline entry gains its row's
  own `source_offset`, and an `effects` entry its row's `source_entry` (the
  other two kinds already carried it), so the three kinds name a medium's exact
  `(source_entry, source_offset)` coordinate; an entry built from a library row
  also gains `library_call`. `voice` and `bgm` entries keep their shapes. A library
  picture is classified by its own `native_active_surface_value` and
  `source_entry`, so a surface-2 load from `LIBLARY.LIB` is a base picture.
- The Event Player passes `probe.library_media` as the fourth argument; no
  other player change. The Analysis view keeps the route trace, and the library
  rows stay evidence in the signature `rows`.

What is unchanged: `trace`, `rows`, `signature`, `messages`, the carried state,
the terminal and every replay field (the list is a new key the replay writers
do not name), the catalog, the package records and schema
(`kakyu_playback_package/v7`), the v7 definitions' content and every
`config/contracts/` file. The probe result and the timeline are in-memory
structures with no schema id, so the new keys are additive. Nothing new reaches
`kakyu-remake`: the library records, their inventory occurrences and the v7
library items are already in the package and the definitions.

What is confirmed and what is a tool decision:

- Established: the shared-call record at the caller coordinate; the rung
  selection (TD-56); the marker and `effect_request` envelopes and the
  active-surface cell the marker reads (EP-13); routine 27's selector-11 rung
  as a base-surface producer (`docs/spec/mes/character_events.md`).
- Observed, not individually confirmed: every routine-27 marker has that
  rung's shape (write surface 2, marker, write surface 7, mode-1
  subcommand-11 copy).
- Tool decisions: a library picture is presented as a still at the step of the
  call, and a library sound effect fires at the step of the call. The
  original's screen refresh, surface lifetime and sound-effect cadence are
  unresolved (PR-01, PR-04), so a background may show earlier than the
  original redraws it. The player's one effect channel is stopped before every
  request, so several effects in one step are heard as the last one; the
  validator still resolves each effect separately.
- Not presented: the function-24 `.mmo` loader strings and routine 33's
  dispatch strings, whose native meaning is unresolved, and the media of
  route-invoked `DEF_MAIN.MES` bodies (`DEF_MAIN.MES` carries no presented
  kind).

The Core moves to `0.378.0` with no schema or contract change; the package hash
follows through the manifest's `content_core_version` (`0e47e063...` to
`fe9bb6bd...`), and the v7 set was rebound with the Core pair after the
replays were proved byte-identical (227 of 227). EP-14 closed the same day by
the whole batch (run `8b534111`, 479 of 479 in 2,401 s,
[Validation Checks](../data/validation_checks.md)); details are in
`todo/event_player.md` (EP-14, closed).

## Playback package reader memory revision, 2026-10-10

Core `0.376.0` (TD-64 part 2) changes what the package reader holds, not what it
accepts: `KakyuPlaybackPackage.load_directory` no longer keeps the member documents as
parsed Variants. It verifies each member file in one streaming pass, keeps the verified
bytes, and parses a code source from them on demand under a bounded cache (32 sources
by default, a tool decision); the exporter's `build()` likewise serializes each member
as it is built. The schema stays `kakyu_playback_package/v7` and every package file is
byte-identical to Core 0.375.0's apart from the manifest's `content_core_version` and
the `package_sha256` that follows from it. Details in the
[workspace export contract](../data/workspace_playback_export.md) ("The reader") and
`todo/code_health.md` (TD-64).

## Playback export integrity revision, 2026-09-08

Core `0.298.0` introduced `kakyu_playback_package/v4` and `0.300.0` introduced
v5. Core `0.303.0` added workspace identities and UTF-8 in v6. Current Core
`0.304.0` produces and accepts v7 exactly, adding mapped message-authoring
start/choice/terminal/resume coordinates to the
[workspace export contract](../data/workspace_playback_export.md). The historical record layout
and cross-repository contract remain referenced at
`kakyu-remake/docs/spec/tech/playback_package_schema.md`; that repository and
its v3 document were not edited by this producer repair. A v3/v4 consumer rejects
the new version. Compatibility with a separately updated consumer is not
claimed here, and v3/v4 data is migrated by re-export rather than silently
relabeling its weaker integrity evidence.

The producer's v4 integrity change binds a sorted `files` inventory (relative
name, exact byte size, SHA256) for every event/text document into the manifest.
`package_sha256` is the shared canonical payload fingerprint of
`{"manifest": manifest_without_package_sha256}`. The enclosing object ensures
that no manifest field is omitted by the fingerprint helper's reserved
`payload_sha256` rule. Canonical number normalization permits JSON round trips;
file fingerprints continue to cover the exact file bytes. The reader checks
the manifest hash before loading members, enforces unique safe member names
and complete inventory, checks file identity and basic typed ranges, and
rejects out-of-range event starts and packaged-owner terminals. Caller-owned
terminals outside membership remain the previously recorded unresolved
boundary, not implicitly included content.

Loading is transactional: a successful load replaces all manifest, entry,
text and code-source state at once. Failure preserves the entire last verified
snapshot (or the empty initial state), with the failure in `last_error`.
Returned text arrays are copies. These changes do not add media extraction or
claim that a script/text-only package contains every playback dependency.

Core `0.299.0` publishes only to a new destination. The writer checks the
serialized inventory and payload fingerprints before acquiring the shared
publication lock, writes a unique sibling staging directory, flushes and checks
each file, and reopens the complete staged package through the reader. It then
renames the directory into place. Existing output is never overwritten. Failed
writing/reopen removes only this operation's staged inventory, leaving final
output untouched; a competing publisher is refused by the lock. A lock-release
error after successful publication retains `published=true` in the result so
the caller can distinguish that state from an unpublished failure.

The v5 boundary extension retains `provenance_records` (`at`, `end`, no bytes)
on every event record group and every library routine. These are the exact
starts/ends of inert source markers omitted by the linear sweep or transfer
closure. An opaque interval may overlap a separately decoded path; exact kept
record starts remain valid. Forward resolution from inside an opaque interval
requires a contiguous chain of these recorded provenance starts to the next
kept record. An arbitrary interior offset, including the payload interior of a
provenance record, is refused. Outside opaque ownership, the existing forward
resolution rule is preserved. Every returned record must end at or before the
caller's requested limit, so rejection occurs before messages/state effects.

This is a producer/reader decision using already established source-marker
framing, not a new claim about native behavior. Synthetic tests distinguish
opaque interiors, exact linear/transfer-owned overlaps, proven marker chains,
and caller limits; the original 12-event bytecode/package comparison passes
with those guards enabled (`analysis/r5-v5-validation.json`).

Core `0.299.0` publishes only to a new destination. The writer checks the
serialized inventory and payload fingerprints before acquiring the shared
publication lock, writes a unique sibling staging directory, flushes and checks
each file, and reopens the complete staged package through the reader. It then
renames the directory into place. Existing output is never overwritten. Failed
writing/reopen removes only this operation's staged inventory, leaving final
output untouched; a competing publisher is refused by the lock. A lock-release
error after successful publication retains `published=true` in the result so
the caller can distinguish that state from an unpublished failure.

## Ownership and Directory Contract

## Playback export integrity revision, 2026-09-08

Core `0.298.0` produces `kakyu_playback_package/v4` and this repository's
instrument reader accepts that version exactly. The historical record layout
and cross-repository contract remain referenced at
`kakyu-remake/docs/spec/tech/playback_package_schema.md`; that repository and
its v3 document were not edited by this producer repair. A v3 consumer rejects
the new version. Compatibility with a separately updated consumer is not
claimed here, and v3 data is migrated by re-export rather than silently
relabeling its weaker integrity evidence.

The producer's v4 integrity change binds a sorted `files` inventory (relative
name, exact byte size, SHA256) for every event/text document into the manifest.
`package_sha256` is the shared canonical payload fingerprint of
`{"manifest": manifest_without_package_sha256}`. The enclosing object ensures
that no manifest field is omitted by the fingerprint helper's reserved
`payload_sha256` rule. Canonical number normalization permits JSON round trips;
file fingerprints continue to cover the exact file bytes. The reader checks
the manifest hash before loading members, enforces unique safe member names
and complete inventory, checks file identity and basic typed ranges, and
rejects out-of-range event starts and packaged-owner terminals. Caller-owned
terminals outside membership remain the previously recorded unresolved
boundary, not implicitly included content.

Loading is transactional: a successful load replaces all manifest, entry,
text and code-source state at once. Failure preserves the entire last verified
snapshot (or the empty initial state), with the failure in `last_error`.
Returned text arrays are copies. These changes do not add media extraction or
claim that a script/text-only package contains every playback dependency.

## Ownership and Directory Contract

Tracked code is divided by responsibility:

```text
content_core/
  content_core_version.gd
  content_set.gd
  content_service.gd
  arc_reader.gd
  arc_writer.gd
  audio_entry_validator.gd
  cp932_codec.gd
  ai5_lz.gd
  mmo_codec.gd
  dat_pal_codec.gd
  a6_layout.gd
  ax_dword_stream.gd
  overlay_package.gd
  content_resolver.gd
  mes_container.gd
  mes_expression.gd
  mes_instruction_decoder.gd
  mes_analysis_index.gd
  mes_text_patcher.gd
  mes_sandbox_state.gd
  mes_event_runner.gd
  mes_detached_definition_preview.gd
  mes_script_call_runner.gd
  mes_caller_route.gd
  mes_text_cache.gd
tools/content_suite/
  tool_window_profile.gd
  tool_game_preview.tscn
  content_suite_launcher.tscn
  arc_browser.tscn
  audio_arc_editor.tscn
  mes_editor.tscn
  event_player.tscn
  image_arc_editor.tscn
tests/
  test_content_core_arc.*
```

The game and every app import `content_core/`; an app must not carry a private
copy of an archive, MES, image, or audio codec. `ContentCoreVersion.CORE_VERSION`
versions the implementation. Persisted contracts have separate schema strings
so a core release does not silently change cache or overlay data.

## Desktop Tool Window Contract

The launcher and every independent content tool use native desktop client
pixels. `640x400` remains the game's logical coordinate system and the fixed
coordinate space for an embedded game-frame preview; it is not the coordinate
system for tool chrome, tables, inspectors, or editors.

`ContentToolWindowProfile` disables project-level content scaling for a tool
process, uses `1280x800` as the preferred initial client size, and enforces a
`1024x640` minimum. Full-rect tool roots therefore reflow when the window is
resized or maximized instead of magnifying a 640-wide interface. This profile
does not change the game project's viewport settings and is applied only by
the standalone content-tool scenes.

Since Core 0.345.0 (2026-09-18, owner ruling of the same day) two things refine
that rule. The profile sets `content_scale_factor` from the screen DPI
(`scale_for_dpi`: DPI / 96 rounded to a quarter, 1.0 to 3.0) and scales the
minimum and the initial size with it, so the five reflowing apps - Launcher,
ARC Browser, MES Editor, Image and Animation ARC Editor, Audio ARC Editor -
keep their logical 1024x640 minimum on a scaled display and follow a window
moved to another screen. The Event Player alone is a stretched view
(`tools/content_suite/tool_window_display.gd`, `ContentToolWindowDisplay`): its
whole window content is drawn on a fixed 1280x800 canvas that stretches with
the window. Windowed, the 16:10 aspect is kept and a window of another ratio
shows black bars; in borderless fullscreen (F11, Alt+Enter or the toolbar's
`Fullscreen`) the content is stretched to the screen as it is, aspect not
kept - the owner chose this knowing that text and the 640x400 frame spread by
about a ninth on a 16:9 screen. There is no exclusive fullscreen: the apps
open each other and their dialogs, which would minimise it. The mode is
remembered per app in `user://content_tools/window_display.cfg`. The player's
logical layout is therefore 1280x800 at every window size, and its minimum
window is 640x400.

`ContentToolGamePreview` is the shared embedded game-frame boundary. Its
`SubViewport` always renders at `640x400`, while its desktop texture surface
supports Fit, 1x, 2x, and integer scaling with nearest-neighbor filtering and
letterboxing. It exposes a caller-owned overlay root without changing the
logical frame size. Frame content can independently fit, stretch, remain at
native pixels in the center, or remain at native pixels at an explicit logical
position; this lets an image tool inspect exact in-game cropping without
altering decoded pixels. Pointer coordinates are mapped back to logical game
coordinates.

Preview input is disabled by default. A host such as Event Player must enable
it explicitly; the user must then click the rendered frame before mouse or
keyboard events are forwarded to the `SubViewport`. That focus-acquisition
click is consumed rather than delivered as a game action. Esc or ordinary focus
loss releases the boundary. The component does not use global `_input`, synthesize
operating-system input, or claim focus when it is created, so headless tool
verification cannot take foreground input through this path.

`KakyuCp932Codec` performs runtime decoding without Python or an OS locale. A
generated 23,088-byte `KCP932V1` table covers CP932 single-byte, standard
double-byte, and Windows extension mappings. The strict API returns the exact
source-byte offset for a truncated, invalid, or undefined sequence. The table
is reproducible from Python's standard `cp932` codec with
`tools/generate_cp932_table.py`; it contains no original game data.
The shared encoder derives a deterministic reverse index from that same table
at runtime. It prefers a one-byte mapping, then the numerically lowest byte
pair when CP932 has duplicate Unicode mappings, and fails with the exact
character index for text outside CP932. Encoding always decodes back to the
same Unicode text; message-specific length and terminator constraints remain a
separate MES patch-validation responsibility.

## ELFIMAGE Content-Set Contract

`KakyuContentSet` opens a user-selected ELFIMAGE directory as one read-only
runtime source. `mes.arc` is required. `mmo.arc`, `data.arc`, `bgm.arc`,
`se.arc`, `voice.arc`, `tina1.arc`, and `tina2.arc` are optional and reported
individually when absent. Every archive that is present must pass the shared
ARC index and bounds validation; a malformed optional archive rejects the
whole attempted set instead of leaving a partially open mixture.

The content set retains one streaming `KakyuArcReader` per archive, preserves
canonical archive search order, supports preferred-archive entry lookup, and
does not eagerly read payloads or hash multi-hundred-megabyte archives while
opening. Its `kakyu_elfimage_content_set/v1` summary contains only archive
names, sizes, entry counts, and missing-optional warnings. The machine path is
runtime state and must never be written to tracked data, cache manifests, or
overlay packages. Closing the set closes every reader; no source file is ever
opened for writing.

Local and generated data use these roots:

```text
user://content/<archive-sha256>/index.json
user://content/<archive-sha256>/cache/<codec-version>/...
user-selected-mod/
  manifest.json
  replacements/<archive-name>/<replacement-sha256>-<entry-name>
  projections/mes/<entry-stem>.json
```

Overlay manifest loading returns the SHA-256 of the exact bounded bytes that
were parsed. Every shared replacement/projection publisher carries that
revision through payload preparation and compares it again immediately before
the atomic manifest rename. If the manifest appeared, disappeared, or changed
since the read, publication fails, preserves the newer file, and removes its
sibling temporary manifest; already written content-addressed payloads may
remain unreferenced for recovery. The publisher also reopens the result and
requires the published SHA before reporting success.

Content Core `0.145.0` places that full read/prepare/CAS/publish/reopen sequence
inside a `kakyu_workspace_publication_lock/v1` directory lock. Directory
creation is the cross-process exclusion primitive; its owner record binds a
unique token, process ID, and creation time. A live owner makes another
publisher fail with an explicit retry result. A dead owner is first renamed to
a unique quarantine directory and only the successful stealer removes it, so
two recovery attempts cannot both enter the transaction. Release rechecks the
owner token and refuses to remove a lock whose ownership changed.

Core `0.344.0` (2026-09-18, WD-17) corrects how "dead" is decided.
`OS.is_process_running` answers only for children of the calling process, so
through Core 0.343.0 every live owner that was not the caller's own child read
as dead and its lock was stolen; `content_core/process_liveness.gd` now asks
the operating system (`tasklist` on Windows, `/proc` or `ps` elsewhere),
compares the image name the owner record stores beside the process id so a
reused id is not the owner, and answers "running" when it cannot decide. The
abandoned-temporary cleanup below uses the same check. A create that fails
because another process is removing the lock directory at that instant is
retried briefly, and both transient refusals say "retry".

Core `0.346.0` (2026-09-18) closes what full CPU load exposed. Judging an owner
dead takes long enough for the lock to change hands, so a takeover re-reads
the record and requires the judged token right before the rename, verifies
the record inside the quarantined directory after it (a directory with
another token goes back under its name), and does not ask at all about a
record younger than three seconds. Release is a single rename to a retired
name, so a lock directory never exists without its owner record; an
unreadable directory age counts as inside the grace period.

After acquiring the lock, OverlayPackage removes abandoned sibling
`manifest.json.tmp-<pid>-*`, replacement, and projection temporary files whose
recorded process no longer exists. Missing or invalid owner records receive a
30-second grace period so another process cannot mistake the small
directory-create/owner-write window for a crash. Content-addressed final blobs
and valid manifests are never removed by recovery. The existing manifest
revision/CAS check remains inside the lock as defense in depth.

Replacement and MES-projection blobs use a separate content-addressed publish
guard. A verified sibling temporary file is renamed only when its destination
is absent. If another publisher creates the destination first, the operation
reuses it only when its SHA-256 is identical; different bytes are preserved and
the staging operation fails without replacing them. A successful new publish is
reopened and rehashed before the blob can be referenced by the manifest. The
filesystem still has a narrow existence-check-to-rename race on platforms
without an exclusive atomic create/rename primitive; the manifest revision
guard remains the authoritative package publication boundary.

Content Core `0.146.0` adds the strict portable
`kakyu_content_project/v1` contract described in
[Content Project Contract](../data/content_project.md). `project.json` binds a
mod identity and semantic version, exact source content-set fingerprint,
non-empty target archive subset, compatibility objective, dependencies, and
optional Event Player presets without storing an ELFIMAGE path or payload.
Unknown fields and incompatible core ranges fail closed. New projects start at
revision 1; updates must increment exactly once and match the exact previously
opened SHA-256. Publication uses `.project.lock`, verified sibling temporary
bytes, atomic rename, and loader reopen validation. The overlay manifest remains
the effective payload authority composed by the workspace service below.

Content Core `0.147.0` implements that composition as
`KakyuContentWorkspace`; see
[Content Workspace Contract](../data/content_workspace.md). Create/Open binds
the exact project and manifest bytes to every present selected source ARC and
entry, then exposes one path-free deep-copied generation snapshot. Failed open,
refresh, source mutation, or compatibility validation preserves the last active
generation. Target-scoped replacement and MES-projection publication freezes
the project revision, delegates to OverlayPackage's latest-manifest merge, and
reopens the composed snapshot, so an unrelated record published by another
specialist app is retained. Project updates cannot orphan active targets.
Launcher and independent-app handoff to this service remains P1-07.

Content Core `0.148.0` adds
`kakyu_materialized_arc_provenance/v1`; see
[Materialized ARC Provenance Contract](../data/materialized_arc_provenance.md).
Every ARC Browser, MES Editor, Image Editor, and Audio Editor materialization
now publishes a strict sibling sidecar that binds the opened source ARC,
derived ARC, and every original/replacement entry snapshot. Publication is
source- and payload-bound, locked, non-overwriting, reopen-verified, and never
stores a machine path or original payload. Another suite app can classify a
selected file as exact original, verified original-derived, declared but not
source-verified derived, or unknown raw. Lineage verification never upgrades
the separately declared engine-compatibility level.

Content Core `0.149.0` adds the runtime-only
`kakyu_content_identity/v1` projection described by the
[Content Identity Contract](../data/content_identity.md). It binds immutable
original ARC/entry evidence to the effective resolver descriptor, bytes, and a
versioned format-interface validation without conflating them. Event Player
uses it for resolved MMO, AX, BGM, and voice payloads: media overlays retain
the independently proven MES route while receiving exact-original,
original-derived-compatible, or remake-only effective labels. Changed MES
control flow fails closed unless a versioned validator explicitly proves its
required interface. Verified materialized-ARC lineage is an accepted identity
input; normal mixed/derived content-set selection remains the P2-10 playback
integration task.

Content Core `0.150.0` adds the autoloaded `KakyuContentService`; see the
[Runtime Content Service Contract](../data/runtime_content_service.md). It
prepares and atomically swaps one read-only ContentSet/Resolver generation,
validates an overlay as a candidate across every targeted selected archive,
and exposes MMO, DAT/PAL, WAV, Ogg, and ordered voice-bank adapters. Runtime
clients now resolve original and edited media through
`overlay -> selected ARC -> res:// fallback`. A rejected source or overlay
generation retains the previous resolver and visible media; a higher-layer
integrity error is not silently converted into a fallback. Launcher selection
and workspace handoff remain P1-07.

Content Core `0.160.0` begins P2-10 with a provenance-aware materialized ARC
resolver layer. A logical archive keeps its authoritative original reader for
route evidence while a second reader supplies effective bytes only after
`kakyu_materialized_arc_provenance/v1` verifies the full original/derived
lineage. Overlay remains highest priority, followed by materialized ARC,
original ARC, and fallback. Failed derived activation is transactional;
re-registering original evidence invalidates the prior lineage. Event Player
now consumes this as a media-only transaction while retaining the original
ContentSet for MES route evidence. Overlay reload and clear rebuild the same
derived layers rather than silently dropping them. Changed `mes.arc` remains
excluded. Event Player exposes the transaction through **Derived...**: Add
selects a provenance-bearing ARC and infers its logical archive from the
sidecar, selecting another copy for the same logical archive replaces only
that layer, Remove detaches the selected layer, and Clear restores every
effective media archive to the original ContentSet below any active overlay.
The manager shows only the selected filename, compatibility, and replacement
count in its table; machine-local paths remain runtime-only tooltips and are
never serialized.

Content Core `0.161.0` adds
`kakyu_mes_routine40_choice_contract/v1`. A reached routine-40 DEF boundary may
become a reusable Event Player result bridge only when the current resolved
MES bytecode supplies 2..17 zero-based sequential definitions with unchanged
body hashes and the complete immediate one-based
`state_u16[21] == 1..N-1` consumer chain. The bridge is source-bound and is
rebuilt before confirmation. Explicit remake input writes only the selected
one-based value to caller-visible slot 21, then resumes at the original
post-routine coordinate so the stored branch chain selects the destination.
The Summary and game-frame footer distinguish this from native playback.
Original-EXE audit v41 confirms that helper mode 1 converts its zero-based
selected record to the exact one-based value written through slot 18 and
returned by the modal runner; an empty list yields `0xFFFF`. Device bindings,
cadence, the original UI, and the attached display content/lifetime behind
routine 20's now-bounded rectangle refresh remain unresolved and are not
synthesized. Native group-vector clearing is instead a
confirmed manager-only cleanup that the Event Player bridge may omit because
its projected registry is execution-local; see executable audit v81 below.
DEF-route audit v4 further separates the prior
multi-definition outliers. One authoritative DENSHA route stores a complete
three-result by `global_u8[2461]` 0/1 consumer matrix. Command-`0x03` audit v3 finds exactly two stored writes to the
gate across the authoritative archive, both DENSHA literal-1 writes. A bridge
may therefore preserve and revalidate an existing 0/1 gate, but must not set it
as a choice side effect. Executable audit v70 confirms zero for a newly
allocated state buffer; serialized reload and later reset lifetime remain
separate unresolved boundaries.
Content Core `0.162.0` schema
`kakyu_mes_routine40_choice_contract/v2` implements that exact complete-matrix
case. Event Player snapshots the current allowed gate, displays it outside the
choice text, rejects source or gate drift, writes only slot 21, and resumes the
stored branch matrix. The 43C route also consumes native secondary
`state_u16[13]` values 1..7. EXE audit v41 confirms that routine 40's mode-1
helper prepares an embedded native control, produces a one-based selected-row
result, optionally returns it through its modal object, and passes the second
result through slot 18 before the script copies it to slot 13. The records in
that dynamic second-stage list and their 43C gameplay use remain unresolved,
so 43C stays fail-closed instead of being flattened into the one-result bridge.
Content Core `0.176.0` advances the contract to
`kakyu_mes_routine40_choice_contract/v3` and admits the third exact stored
shape: one DEF row followed by a literal `state_u16[21] == 1` branch. The
single row may retain its original non-zero definition ID; its body hash,
comparison, true destination, and separate false destination are all bound.
Event Player numbers the visible remake option as row 1, writes only result 1,
and resumes the true branch. The false destination remains unlabeled graph
evidence and is not presented as cancel/back.
EXE audit v42 proves that the second record's slot-21 value selects a 16-byte
native group descriptor and that the engine copies its 8-byte records into the
active choice vector while publishing the exact count. It does not yet prove
which records belong to each key. EXE audit v44 identifies command `0x10` as
the group-record producer: it appends an 8-byte record to the current
16-byte group descriptor and stores active script-context pointer plus code
coordinate as the first dword later copied by the materializer. It also fixes
command `0x1B` as an evaluated-expression group selector/clear: its raw
`+0x4B6D5` access is parser-relative `+0x4B6D1` after the handler's `+4`
object adjustment, not the next record header. The source-bounded
`kakyu_mes_routine40_group_route_audit/v4` now inventories the complete
`43C.MES` address-entry-148 topology: group registration counts
`6,15,0,14,2,0,7`, explicit empty groups 2 and 5, group-1 guards
`global_u8[376..390] == 1`, and group-3's 13 simple plus one 16-flag OR guard.
The seven-row group-6 route reaches routine 40 at `0x4EC1`. This proves stored
construction. A single multi-index v3 producer pass further finds 116
strict-valid command-`0x03` writes across all 44 distinct group-1/group-3
guard flags; every stored write is literal 1 and every guard has at least one
MES producer. That closes MES-side producer coverage but not initial values,
native resets, save lifetime, caller reachability, native two-stage input or
combined gameplay use, so the fail-closed boundary is unchanged.

Executable audit v81 retains v71's complete command-`0x1B` handler and erase-
helper fingerprints. The handler supplies the selected 16-byte descriptor's
complete `[begin,end)` range; the helper sets its end pointer to begin while
preserving the allocation/capacity pointer and without zeroing inactive backing
records.
The authoritative `LIBLARY.LIB` routine-40 suffix calls routine 20 at
`0x1D07`, restores entry label 0, clears selectors `1..17` with seventeen exact
command-`0x1B` rows at `0x1D11..0x1D61`, and returns at `0x1D66`. This closes
the vector lifetime and ordering question. V72 additionally binds routine 20's
mode-13 common tail to a conditional attached-display rectangle refresh, and
the paired source audit fixes its exact local rectangle as `(0,0) 544x60`.
Attached backing content, lifetime, and final composition order remain
unresolved, so Event Player continues to omit the native refresh.
The same v4 report follows the stored caller consumer after routine 40. It
requires first-stage `state_u16[21]` results 1..6 to match group selectors
1..6, then checks secondary `state_u16[13]` false chains against each group's
registered row count. Groups 1/3/6 are complete at 15/14/7 rows and empty
groups 2/5 have no secondary chain. Group 4 has two registered rows but only
secondary result 1 has an explicit compound branch. Result 2 joins the common
false chain and reaches stored command `0x0C` at `0xA304`, which transfers to
the earlier dispatcher at `0x399F`. V4 binds that destination to address-table
entry 127 (`0x3917..0x39BC`) and its constant-true command-`0x0B` fallthrough,
so this is dispatcher re-entry rather than a detached cancel body. It also
finds all six command-`0x0E` records naming `43C.MES` across `43C_ASA.MES`,
`44C.MES`, and `L_HOTEL2.MES`. EXE audit v56 resolves the public-context
receiver and flag lifecycle but still confirms that command `0x0E` does not
establish a callee coordinate or caller restoration, so these records do not
prove which host call reaches address entry 148. V4 retains the
exact fallback and this shared host-activation blocker while leaving their
UI/gameplay meaning unresolved. This structural result does not
enable Event Player input for 43C or assign a cancel/back meaning. In contrast,
DEF-route audit v4 proves the 27 single-definition paths have exact result-1
branches and Content Core v3 admits those source-bound rows through the same
explicit remake-input bridge.

Content Core `0.177.0` / Event trace v64 preserves the command-`0x1B` group
registry instead of returning the last or flattened command-`0x10` rows as one
menu. Because audited routine 40's first native record uses fixed key `0`, the
visible first-stage list is group 0 whenever it was built. Content Core
`0.194.0` added `kakyu_mes_routine40_group_preview/v1` for the narrower
analysis-only case where group 0 has `N` rows and the ordered registry contains
exact selectors `0..N`. It fingerprints every retained DEF body and the whole
resolved bytecode, binds the logical source identity, maps a first one-based
row only to the same-numbered second-stage group, and forbids gameplay-state
writes and caller resume.

Event Player exposes this as **Routine 40 grouped analysis**. The first step
opens the retained second-stage rows; the second step may inspect one body in
a cloned sandbox. Empty groups stop at the EXE-confirmed `0xFFFF` result
boundary. Both stages use the confirmed three-row, clamped, non-wrapping
navigation policy. They never write `state_u16[21]` or `[13]`, execute the
post-result dispatch, or present the route as normal event playback. The
original `43C.MES` validator fixes six first-stage rows under both a fresh
state (`6,0,0,0,2,0,7`) and the complete audited eligibility state
(`6,15,0,14,2,0,7`) and validates the new contract with caller resume
forbidden. Its live host activation, slot-13 gameplay meaning, and group-4
fallback remain fail-closed.

Content Core `0.195.0` advances the grouped contract to
`kakyu_mes_routine40_group_preview/v2`. The common result-dispatch parser now
fingerprints and retains the exact first/second comparison graph and default
command-`0x0C` coordinate transfer alongside the reached group registry.
Event Player displays a selected row's stored consumer coordinate, or the
unmatched common fallback coordinate with unresolved meaning, but never enters
either path. `43C.MES` validates stored secondary counts `15,0,14,1,0,7` and
the group-4 result-2 fallback `0xA304 -> 0x399F` in both default and fully
eligible isolated states. Slots 21/13, native input, consumer execution, and
caller restoration remain forbidden by this analysis-only contract.

Cache/IR JSON is generated, disposable, and versioned. It is not authored
content. Large image and audio entries are indexed without eager conversion;
decode and full reads happen on selection or playback. A cache writer must use
a per-fingerprint lock and recover or discard an incomplete temporary file.

`kakyu_mes_text_cache/v1` is an optional generated UTF-8 presentation
projection. Its manifest binds the base `mes.arc` SHA-256, every entry SHA-256,
each projection-file SHA-256, and a safe relative path. Individual
`kakyu_mes_text_entry/v1` files map code-relative message offsets to UTF-8 and
the original CP932 record hash. `KakyuMesTextCache` rejects a stale archive,
entry, projection file, unsafe path, or duplicate offset. Manifest and entry
JSON are each bounded to 16 MiB. Entry files are SHA-256-checked again from the
same bounded byte buffer used for parsing whenever they are loaded, so a cache
publisher cannot silently retarget a configured projection. MES Editor and
Event Player can run without this disposable cache and fall back to decoded
original/effective CP932 when a cached entry is rejected; neither invokes
Python at runtime.

## ARC Reader Contract

`KakyuArcReader` implements `kakyu_ai5_arc/v1` using the existing confirmed
index rules in [MES Format and Method](../mes/format_and_method.md). Opening an
archive reads only its index. Entry data is accessed through bounded range
reads or a bounded-chunk callback, so listing an archive never loads its full
payload.

Open fails closed when:

- the count-derived index exceeds the file;
- a record is truncated, empty, non-ASCII, path-like, or duplicated
  case-insensitively;
- an entry begins inside the index or its offset/size exceeds the archive;
- a requested entry range exceeds that entry.

Entry names are identifiers, not paths. `/`, `\`, `:`, `.` and `..` path forms
are rejected before extraction. Extraction refuses to overwrite an existing
file. It streams to a uniquely named sibling temporary file, hashes the bytes
while writing, closes and reopens that file, verifies its byte count and
SHA-256, rechecks that the destination is still absent, and only then publishes
it with an atomic rename. Every failed path removes its temporary file; a
successful result reports the verified SHA-256 alongside its byte count and
path. The reader exposes entry index, decoded name, offset, size, archive
fingerprint, bounded reads, streaming, and safe extraction.

The legacy Python `tools/extract_kakyu_arc.py` keeps its tuple-returning API for
analysis-tool compatibility, but follows the same index-only read, bounds,
duplicate-name, traversal-name, source-immutability, and chunked extraction
rules. It is an audit/CLI adapter; the Godot apps share the GDScript core.

### Native ARC Reader Cross-Check

The embedded runtime PE independently confirms the same container contract.
`CAI5Arc` construction installs vtable `0x0047A000` at `0x00402506`. Its open
path allocates `entry_count * 0x108` bytes at `0x00402773`, then calls the
record decoder at `0x00402E80`. That decoder XORs exactly 256 filename bytes
with `0x72` at `0x00402E8D..0x00402EB0`, XORs the following stored size with
`0xF97FD0EC` at `0x00402EB2`, XORs the stored offset with `0xA2C947FC` at
`0x00402EB9`, and advances by `0x108` at `0x00402EC2`.

The same executable registers the INI-selectable default `Data.arc` using
`ArcDataName`, constructs a `CAI5Arc`, appends it to the manager collection at
receiver offset `+0x20`, and opens it at `0x0043BFCC..0x0043C0A7`. The parallel
`mmo.arc`/`ArcBgName` path uses collection offset `+0x30` at
`0x0043C0E8..0x0043C1D9`. This distinction corroborates the archive identities
used by Content Core. On its own it does not identify an AX consumer or prove
AX token meaning; the separate MES executable audit v38 supplies the bounded
selector-0 Data-loader route described below.

The named-entry path independently confirms how decoded metadata becomes a
bounded stream. `0x00402ED0` performs a normalized string-key lookup and
returns the entry metadata view. The whole-entry loader calls the stream setup
at `0x00402A23`, reads metadata field `+0` as the requested length at
`0x00402A80..0x00402A8D`, and invokes the `CAI5Arc` virtual read slot `+0x18`.
That slot is `0x00409530` and reaches Win32 `ReadFile` at `0x0040954E`. The
setup path separately reads metadata field `+4` as the absolute archive offset
at `0x00402D88..0x00402D95`, invokes virtual slot `+0x20`, and stores metadata
field `+0` as the logical stream size at `0x00402E2C..0x00402E37`. Slot `+0x20`
is `0x00427D80`; it reaches `SetFilePointer` at `0x00427D9C` and rejects the
`0xFFFFFFFF` failure result. This confirms the size/offset field roles and
read-only named-entry streaming, but not decompression, AX token semantics, or
the identity of a later renderer.

The document construction path installs adjusted-subobject vtable `0x0047A8EC`
at `0x004072A5`. Its virtual slot `+0x24` points to the Data loader
`0x0043DDA0`. That function reads the collection whose object offset is
`+0x20` (vector begin `+0x24`) and calls the whole-entry loader at
`0x0043DE48`; its direct-file/ARC compatibility mode is selected by the
`DataType` INI key. The title menu's selected `.A6` name calls this same slot at
`0x00443DA4..0x00443DAF`, and `inputname.a6` does so independently at
`0x00430315..0x0043032E`. This closes the native route for those static A6
callers. The ARC audit alone does not prove that a dynamic `.AX` name reaches
this slot; the paired MES audit v38 retains that route for the exact
presentation-subcommand-8 selector-0 envelope.

`tools/audit_ai5_arc_exe.py` accepts either the original launcher or the
extracted runtime PE. For a launcher it locates the matching embedded PE and
records both hashes plus the payload file offset; it then rechecks all of these
byte, pointer, string, and relative-call sites without launching the engine.
Audit v4 also pins A6 hit-test helpers `0x00411400` and `0x00411450`, their
field-access order, record stride, inclusive comparisons, no-hit result, and
three original callers. Audit v5 (2026-09-17, WD-06 lookup evidence) pins the
entry index as its `entry_index` section: `CAI5Arc` open `0x00402620`
allocates `count * 0x108` bytes with no fixed record limit, decodes every
record, inserts each stored name unchanged into a name-keyed ordered map
through unique insert `0x00402FC0` (the first of two equal names is kept)
and releases the index buffer at `0x00402979`, so no positional access
survives the open; stream preparation `0x00402BC0` and whole-entry loader
`0x004029B0` upper-case the requested name with the ASCII loop at
`0x0046AC4A` and ask map find `0x00403130`, and a miss returns `-1` after an
optional `%s - file search error` message box. The index order therefore
carries no meaning for the engine, an added upper-case name is found like an
original one, and a removed name fails every consumer that asks for it. All
eight original archives store upper-case names in name order with the data
following the index. It emits schema `kakyu_ai5_arc_exe_audit/v5` and labels
its semantic boundary
`container_streaming_static_data_route_and_a6_input_rectangles`. Evidence type:
embedded executable vtable, constructor, index loop, record decoder,
archive-manager, name-lookup, static A6 load callers, A6 input-region
consumers, and Win32 read/seek disassembly; confidence:
**Confirmed** for the ARC record size, field obfuscation, size/offset roles,
named-entry streaming, Data/MMO registration split, and the static A6 Data
route, plus A6 field order and inclusive hit-test semantics; **Unresolved** for
AX rendering and token semantics and for higher-level A6 ID meanings.

The 2026-08-11 v4 direct run against the configured user-owned original launcher
found the runtime PE at file offset `0x1B000`. The launcher SHA-256 was
`3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5`; the
embedded runtime SHA-256 was
`5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da`.
No original file was written or extracted by the audit.

`tools/audit_ai5_mes_exe.py` applies the same non-executing embedded-PE method
to the bounded MES dispatcher contract. It verifies raw jump-table routes
`0x02`, `0x03`, `0x04`, `0x05`, `0x06`, `0x07`, `0x08`, `0x09`, `0x0A`,
`0x0B`, `0x0C`, `0x0D`, `0x0E`, `0x0F`, `0x10`, `0x11`, `0x12`, `0x14`, `0x15`, `0x16`,
`0x17`, `0x18`, `0x19`, `0x1A`, `0x1B`, `0x1C`, and `0x1D` at
`0x0041845C`, their wrapper slots in all three checked script-manager vtables,
and 968 bounded handler/token/RTTI/import byte sites, 693 checked
vtable/table/RTTI pointers, plus 233 direct-call targets. These
include expression evaluation, internal string copying, context-map access,
and the command-`0x17` execution-context clone. Its schema is
`kakyu_ai5_mes_exe_audit/v317`; its semantic boundary additionally includes
presentation-subcommand-4 named relative-bank offset restoration,
presentation-subcommand-9 named MMO decode into the state-selected active
surface with default origin arguments, presentation-subcommand-11 opaque,
RGB-key, and active-surface rectangle operations, and
presentation-subcommand-12 public-context-slot-`+0x3C` bounded input and
presentation polling through control word `+0x20BC` bit 8, and
presentation-subcommand-8 selector-0 Data-archive loading and selector-2/3
inline script execution, plus command-`0x0B`'s
expression-equals-one fallthrough/false-target transfer and command-`0x0C`'s
unconditional little-endian target transfer. Both target handlers write the
active code-coordinate member at `+0x4B590`; the audit does not assign
gameplay intent to the tested expressions.
The v219 boundary widens the conservative one-hop register-transfer search
from 528 to 544 bytes. Ten new byte-level routes are all rejected as direct
`CScript::run` receivers after exact original-runtime checks: timestamp,
image-width/stride, pixel-placement, point, and presentation-effect values are
consumed or overwritten before a later receiver is loaded, and one apparent
transfer is an unaligned byte pair inside another instruction. The checked
one-hop inventory therefore has 61 conservative routes but no newly confirmed
script runner.
The v220 boundary widens the conservative same-register search from 544 to
560 bytes. Its one addition starts from a surface lookup coordinate, which is
adjusted by `0xD0`, consumed by the surface helper, and overwritten before the
two possible owner returns. The eventual indirect call is in a separate
RTTI-bound `CName` handler that reloads its own vtable and invokes slot `+0x08`.
The checked 560-byte inventory therefore has 189 conservative calls but no
newly confirmed script runner.
The v221 boundary widens the one-hop register-transfer search from 544 to 560
bytes. Three added byte-level routes cross returned native functions. The
final handlers independently reload `GetPrivateProfileIntA`, a receiver in
the RTTI-bound `CBaseRenderer`/`CBaseVideoRenderer`/`CVideoRenderer` family,
or `IMediaSeeking` slot `+0x24`. The checked one-hop inventory therefore has
64 conservative routes but no newly confirmed script runner.
The v222 boundary widens the same-register search from 560 to 576 bytes. Its
single added byte-level route begins in the shared `IPin::QueryPinInfo`
handler's copy of the pin direction to `PIN_INFO.dir`; that owner returns
before the independent `CMemAllocator::ReleaseBuffer` handler reloads an
`IMediaSample` and invokes `Release` at slot `+0x08`. The checked inventory is
190 conservative calls with no newly confirmed script runner.
The v223 boundary widens the one-hop register-transfer search from 560 to 576
bytes. Two added byte-level routes share one application-caption load that is
consumed by `MessageBoxA` before its helper returns zero. Later owner copies
cross an expression-vector helper or RTTI-bound `Cai5ComManager` destructor;
the final independent call is RTTI-bound `CWinHookList` slot `+0x00`, which
registers the newly constructed `CAI5Display`. The checked one-hop inventory
has 66 conservative routes with no newly confirmed script runner.
The v224 boundary widens the same-register search from 576 to 592 bytes. It
adds no candidate: the inventory remains 190 conservative calls with the same
fingerprint and no newly confirmed script runner.
The v225 boundary widens the one-hop register-transfer search from 576 to 592
bytes. Four additions begin as an SEH-chain restore value, an application
caption, a critical-section pointer, or a narrow source string. Function
returns or explicit register overwrites separate them from final
`CItemSelect`, `CScriptManager`-family, `IUnknown::AddRef`, and
`LCMapStringA` receiver reloads. The checked one-hop inventory has 70
conservative routes with no newly confirmed script runner.
The v226 boundary widens the same-register search from 592 to 608 bytes. Its
three additions begin as a cursor X stack local, application caption, or input
pin argument. The candidate is consumed or its owner returns before an
independent receiver reload reaches `CWinHookList` registration,
`CAnimeManager` deleting-destructor, or `IUnknown::Release`. The checked
inventory has 193 conservative calls with no newly confirmed script runner.
The v227 boundary widens the one-hop register-transfer search from 592 to 608
bytes. It adds no route: the inventory remains 70 conservative routes with
the same fingerprint and no newly confirmed script runner.
The v228 boundary widens the same-register search from 608 to 624 bytes. Its
single addition is a presentation-subcommand-10 surface-vector stack local,
consumed before that handler returns. The independent following surface
adapter reloads public-context slot `+0x38`. The checked inventory has 194
conservative calls with no newly confirmed script runner.
The v229 boundary widens the one-hop register-transfer search from 608 to 624
bytes. Five additions begin as a consumed rectangle-helper argument,
display-effect step width, virtual-clock function pointer/timestamp result, or
requested IID. Owner returns and explicit receiver reloads separate them from
the later application-root/native-object, `IMediaSample`, and `IMediaSeeking`
calls. The checked one-hop inventory has 75 conservative routes with no newly
confirmed script runner.
The v230 boundary widens the same-register search from 624 to 640 bytes. Its
two additions begin as a sample-conversion outer-row index and a packed native
window-message coordinate. Each value is consumed and its owner returns before
an independent window-style adapter or `BeginPaint`/`EndPaint` handler reloads
its own receiver. The checked inventory has 196 conservative calls with no
newly confirmed script runner.
The v231 boundary widens the one-hop register-transfer search from 624 to 640
bytes. Three additions begin as an application caption, a text-composition
stack argument, and a native critical-section pointer. Each is consumed, or
its owner returns, before unrelated result copies and independent window
message, native application-adapter, or `EnterCriticalSection` reloads. The
checked one-hop inventory has 78 conservative routes with no newly confirmed
script runner.
The v232 boundary widens the same-register search from 640 to 656 bytes.
Three additions begin as a record-grid row offset, an application caption,
and an MSVC C++ exception-handler-table cursor. Coordinate arithmetic,
`MessageBoxA`, explicit owner returns, and cursor advancement separate them
from the later independently reloaded public-context slot `+0x44`,
`lstrlenA` import, and exception-unwind action pointer. The checked inventory
has 199 conservative calls with no newly confirmed script runner.
The v233 boundary audits the configured original launcher's outer PE as a
separate ownership layer instead of widening another conservative window.
Its four checked sections end at file offset `0xB000`; the extraction helper
adds `0x10000` and therefore locates the embedded runtime at `0x1B000`.
Across 584 exact wrapper bytes and complete absolute-IAT call-site inventories,
the outer layer extracts a temporary executable, creates/resumes its child,
optionally reads and writes one descriptor-bounded protection patch, waits,
and posts `WM_CLOSE`. The file-backed wrapper contains zero `.MES`, `mes.arc`,
and `ELFIMAGE` tokens, and no checked route forwards command-`0x0E`'s retained
name. The audit consequently classifies it as a
`softdenchi_process_wrapper`, excludes it from the missing host-activation
consumer search, and leaves multi-hop, spilled, or another indirect consumer
inside the embedded runtime as the targeted P2-05 frontier.
The v234 boundary changes the embedded-runtime search from another byte-window
widening to exact EBP-frame ownership. Exact `push ebp; mov ebp, esp`
prologues partition the checked executable extents before pairing a slot
`+0x10` load, negative EBP-local spill, and call through that same local. The
only conservative route is in frame `0x0044FD0A..0x0044FDDF`: candidate load
`0x0044FD8D` is clobbered by direct call `0x0044FD93`, then callback load
`0x0044FD98` takes the call result's member `+0x80` before spill `0x0044FD9E`
and indirect call `0x0044FDAA`. It is excluded as a native callback route, not
a `CScript::run` receiver. Multi-hop, non-EBP-local, and object-field spills
remain the targeted P2-05 frontier.
The v235 boundary takes the next ownership-led slice without scanning the
embedded runtime as one undifferentiated `610,304`-byte program. It checks only
the two shortest direct-call-target/prologue partitions that retained a
two-register-transfer slot-`+0x10` candidate:
`0x00449470..0x00449660` and `0x0044B230..0x0044B3A0`. The first candidate is
replaced by an intervening indirect call result before the second transfer,
then the final call receiver is independently reloaded at `0x00449607`. The
other two are SEH-chain restore loads at `0x0044B27D` and `0x0044B2C6`; their
apparent transfer chain crosses returns, `int3` padding, and the next function,
whose actual member-`+0x54` call is loaded at `0x0044B368..0x0044B36B`.
All three are excluded from `CScript::run`. Longer ownership partitions,
non-EBP locals, and object-field spills remain the targeted P2-05 frontier.
The v236 boundary checks the next shortest candidate-bearing partition,
`0x00401E20..0x004023F0` (`0x5D0` bytes), and finds four conservative routes
that share load `0x00401EBD`, first transfer `0x004020BB`, and call
`0x004023CC`. Exact flow rejects the common chain twice: direct call
`0x00401EC6` is followed by an independent ESI reload at `0x00401ECB`, and
the apparent `mov edx, esi` at `0x004020BB` starts inside the ModRM and
displacement of the aligned word load at `0x004020B9`. The final call pointer
is independently loaded from member `+0x14` at `0x004023C8`. These four
routes are also excluded from `CScript::run`; the next shortest
candidate-bearing owner remains the P2-05 frontier.
The v237 boundary checks the smaller next `0x6C0` partition,
`0x0041D6F0..0x0041DDB0`. Its 51 conservative route products collapse to one
`mov ecx, [esp+0x10]` stack-local load, three first transfers, 15 second
transfers, and three later calls. The stack-reading function returns at
`0x0041D82D` before any transfer; `int3` padding then separates it from the
later functions. Those functions independently call member `+0x14` once and
member `+0x3C` twice, accounting for route groups of 13, 19, and 19 products.
All 51 are excluded from `CScript::run`. The other `0x6C0` graphics/media
owner, non-EBP locals, and object-field spills remain the targeted P2-05
frontier.
The v238 boundary closes that other `0x6C0` media owner without walking all
3,304 conservative combinations independently. Three candidate loads, 23
first transfers, 23 second transfers, and 18 later calls form the complete
grouped inventory. Every first transfer captures the immediately preceding
COM/DirectShow call result, and every second transfer enters a wrapper
epilogue that returns before a later call. All 3,304 products are excluded
from `CScript::run`; non-EBP locals and object-field spills remain the
targeted P2-05 frontier.
The v239 boundary begins positive ESP-relative local coverage with the two
adjacent `CAdvSelect` rectangle owners. Each of the two conservative routes
stores and reloads member `+0x10` as a rectangle coordinate, consumes it as a
refresh argument, then independently overwrites EAX from application-root
slot `+0x14` before the indirect call. Both are excluded from `CScript::run`;
larger non-EBP-local owners and object-field spills remain the targeted P2-05
frontier.
The v240 boundary resolves the current owner-partition pass's remaining large
ESP-local route inside the complete command-`0x0E` mode-`0x40` handler. Its
apparent slot-`+0x10` load is itself `[esp+0x10]`; EAX is replaced before the
later `[esp+0x14]` store. The saved `CAI5View` value is consumed by imported
`EnableMenuItem`, while the final call independently loads `CPopUpMenu` slot
`+0x4C`. Exclude this route from `CScript::run`; continue with unpartitioned
non-EBP locals and object-field spills.
The v241 boundary starts object-field work by freezing an eight-row candidate
inventory. It uses explicit 128-byte load-to-store, 512-byte store-to-reload,
and 128-byte reload-to-call limits, requires the same non-stack base and field
for store/reload, and records an ordered fingerprint. EBP prologues are only
discovery partitions, not asserted function ends. All eight rows remain
unclassified pending exact owner, control-flow, object-identity, and receiver
analysis.
The v242 boundary resolves the two inventory products ending at popup
visibility call `0x00407036`. The original slot-`+0x10` candidate is invoked
and its owner returns before a separate handler stores constant `1` to
`CAI5View +0x98`. One reload route returns before the call; the other consumes
the mode in comparisons and then independently reloads `CAI5View +0x6C`,
adjusted `CPopUpMenu`, and its visibility slot. Both products are excluded
from `CScript::run`; six object-field rows remain candidate-only.
The v243 boundary resolves the inventory product ending at ARC-open call
`0x0040266A`. The original slot-`+0x10` candidate is called and returns; a
separate constructor then self-links a fresh archive-list sentinel and also
returns. The final owner independently loads checked `CAI5Arc` primary-vtable
slot `+0x08`, now fixed in the MES audit to read-only open handler
`0x00409420`. Exclude the cross-function register-reuse product from
`CScript::run`; five object-field rows remain candidate-only.
The v244 boundary resolves the selected-control product ending at
`0x004343E2`. Owner field `+0x10` is consumed by a direct helper before ECX is
recomputed as the embedded `CAdvSelect` pointer stored at owner `+0x6C`. The
apparent reload returns from the false branch, while the true branch
independently reloads selected `CAdvSelect`/`CItemSelect` slot `+0x20`.
Exclude the product from `CScript::run`; four object-field rows remain
candidate-only.
The v245 boundary resolves the last four initial object-field products. Their
apparent stores are ECX aliases of ESP-backed 16-byte temporary structure
copies, and their owner returns before three later `IUnknown.AddRef` products
and one `IUnknown.QueryInterface(IID_IMediaEventSink)` product. The initial
eight-row inventory is exhausted without a `CScript::run` receiver;
unpartitioned non-EBP and other object-field shapes remain open.
The v246 boundary adds the first bounded whole-text ESP-local inventory rather
than requiring a manual sequential runtime read. It fixes 11 ordered products;
four reproduce prior exact exclusions and seven remain candidates pending
owner, stack-balance, clobber, and control-flow proof.
The v247 boundary excludes the first new product: its ESP local is consumed by
a direct helper and its owner returns; a separate message-dispatch block then
returns before an alternate block independently loads virtual slot `+0x18`.
Six initial ESP-local products remain candidate-only.
The v248 boundary excludes the second new product. Both apparent values are
timestamp arithmetic in separate `CAsyncOutputPin` handlers, while the final
call independently reloads confirmed `CFileStream` slot `+0x10` for a native
asynchronous file-size query. Five initial products remain candidate-only.
Version 157 widens the conservative register-loaded slot-`+0x10` search to
32 bytes. The 71-site set adds eight calls beyond the original 63-site compact
inventory. Exact instruction flow rejects six register-overwrite or
control-flow-crossing false positives; presentation-subcommand-0 call
`0x00428196` resolves through the constructed root table to a fixed
`FLAG%02u` save-path formatter, and popup-presentation call `0x0043A244`
resolves through the `CAI5View` window subobject to `IsWindowVisible`.
Neither route reaches `CScript::run`; at that version, register-separated and
beyond-32-byte forms remained the next native audit boundary.
Version 158 preserves the 32-byte set and adds a 48-byte extended inventory.
It contains 85 calls and adds 14 sites. Exact control/data flow classifies
five as DirectInput keyboard `Acquire` calls before `GetDeviceState`, two as
application-root rectangle refresh calls, one as a native selection-control
slot-`+0x20` call, one as current-document slot `+0x3C`, and five as
return/jump crossings or overwritten call registers. None reaches
`CScript::run`; register-separated and beyond-48-byte forms remain the next
native audit boundary.
Version 159 preserves the 48-byte inventory and adds a distinct 64-byte wide
inventory. It contains 100 calls and adds 15 sites. Exact original-runtime
flow classifies nine as return/jump-separated control-flow crossings, five as
data-only or overwritten call registers, and one as an embedded graphics
interface field followed by actual vtable slot `+0x18`. Two of the nine
crossings are failure-message branches; their reachable allocation calls use
the `VirtualAlloc` pointer loaded from the checked import cell. None reaches
`CScript::run`; register-separated and beyond-64-byte forms remain the next
native audit boundary.
Version 160 adds a distinct 64-byte one-hop register-transfer inventory. The
byte-conservative scan finds one candidate, but exact instruction alignment
shows that its apparent register transfer begins inside a `lea` displacement.
The surrounding block instead calls three graphics interfaces at owner fields
`+0x10`, `+0x70`, and `+0xD0` through their actual vtable slot `+0x1C`.
No one-hop candidate reaches `CScript::run`; same-register or one-hop calls
beyond 64 bytes and multi-hop or spilled forms remain the next native audit
boundary.
Version 161 widens the same-register inventory from 64 to 80 bytes. Its two
additional candidates are the choice UI's `CAI5View` window-subobject
`ClientToScreen` call and a return-crossing match into a DirectShow
position-pass-through helper's upstream-pin slot `+0x18` call before an
`IMediaPosition` query. Neither reaches `CScript::run`; same-register calls
beyond 80 bytes, one-hop calls beyond 64 bytes, and multi-hop or spilled forms
remain the next native audit boundary.
Version 162 widens the same-register inventory from 80 to 96 bytes. Its three
additions are one application-root rectangle refresh in the choice-region
path and two `IMediaSample::SetTime` calls inside RTTI-bound
`CAsyncOutputPin` timestamp adjustment. None reaches `CScript::run`;
same-register calls beyond 96 bytes, one-hop calls beyond 64 bytes, and
multi-hop or spilled forms remain the next native audit boundary.
Version 163 widens the separate one-hop register-transfer inventory from 64 to
96 bytes. Its sole addition begins at candidate load `0x0040D4C3`, but the
aligned OGG streaming handler overwrites the call register from owner member
`+0x30` and calls `IDirectSoundBuffer` slot `+0x4C` at `0x0040D521` to unlock
two filled buffer regions. It does not reach `CScript::run`; same-register or
one-hop calls beyond 96 bytes and multi-hop or spilled forms remain the next
native audit boundary.
Version 164 widens the one-hop inventory from 96 to 112 bytes. Its sole
addition crosses helper `0x004104B0`'s `SetWindowPos` return and padding into
the next `CAI5Wnd`/adjusted-`CAI5View` slot-`+0x4C` handler. The actual call at
`0x0041057F` uses popup member `+0x68`, secondary adjustment `+4`, and the
checked `CPopUpMenu` slot `+0x4C` native-handle handler. It does not reach
`CScript::run`; same-register calls beyond 96 bytes, one-hop calls beyond 112
bytes, and multi-hop or spilled forms remain the next native audit boundary.
Version 165 widens the same-register inventory from 96 to 112 bytes. The four
new candidates are a copied WAVEFORMAT word before the checked DirectSound
buffer-creation call, a failure branch before the checked `VirtualAlloc`
voice-buffer allocation, and two return-crossing matches into RTTI-bound
`CMediaSample::Release`/`SetMediaType(NULL)` and a native interface-copy
`IUnknown::AddRef`. None reaches `CScript::run`; same-register and one-hop
calls beyond 112 bytes, plus multi-hop or spilled forms, remain the next
native audit boundary.
Version 166 widens the same-register inventory from 112 to 128 bytes. The six
new conservative candidates comprise three return-crossing matches into a
paired native-control dispatcher, an ordered-container payload callback, and
a COM interface release; one freed-and-zeroed buffer before an owned-member
scalar deleting destructor; the established `CScript::run` loop's actual
slot-`+0x14` step call; and DirectShow pin slot `+0x28` preflight before the
already checked peer `ReceiveConnection` call. None is a recursive or new
`CScript::run` receiver. Same-register calls beyond 128 bytes, one-hop calls
beyond 112 bytes, and multi-hop or spilled forms remain the next native audit
boundary.
Version 167 widens the one-hop register-transfer inventory from 112 to 128
bytes. The checked whole-`.text` result remains the same three routes with
fingerprint
`4422a2e968c7b9dcdcb770d289e39b591735551003082d7e202800e1b3640fd2`;
the added-route set is empty. Same-register and one-hop calls beyond 128 bytes,
and multi-hop or spilled forms, remain the next native audit boundary.
Version 168 widens the one-hop register-transfer inventory from 128 to 144
bytes. Its sole addition crosses two separate `ret 8` function boundaries and
padding. The final helper reloads an interface from its own argument and calls
COM slot `+0x08` to release the temporary reference. It does not reach
`CScript::run`; same-register calls beyond 128 bytes, one-hop calls beyond 144
bytes, and multi-hop or spilled forms remain the next native audit boundary.
Version 169 widens the same-register inventory from 128 to 144 bytes. Its five
additions are a `CAdvSelect` rectangle value before `UnionRect`, an earlier
character-stream argument before a reloaded surface slot-`+0x08` dispatch,
two cross-return matches into a `CConfig` embedded-member callback and an
adjusted `CAI5Doc` slot-`+0x38` dispatch, and peer `IPin::QueryDirection`
inside the DirectShow connection chain. None reaches `CScript::run`;
same-register and one-hop calls beyond 144 bytes, plus multi-hop or spilled
forms, remain the next native audit boundary.
Version 170 widens the one-hop register-transfer inventory from 144 to 160
bytes. One new candidate stores a `CAdvSelect` rectangle coordinate before
the register becomes a stack-rectangle pointer and the actual application-root
slot-`+0x14` refresh is reloaded. A second is consumed as an OGG stream region
before the actual DirectSound buffer slot-`+0x4C` `Unlock` reload. The last
two cross the return of command-`0x1D`'s native MessageBox error branch and
alias the already confirmed shared-script context lookup/run block. They add
no new script receiver or arbitrary command-`0x0E` target consumer;
same-register calls beyond 144 bytes, one-hop calls beyond 160 bytes, and
multi-hop or spilled forms remain the next native audit boundary.
Version 171 widens the same-register inventory from 144 to 160 bytes. Its four
additions cross cleanup/helper boundaries into an `IGraphBuilder`
`QueryInterface`, an RTTI-bound `CMouse` registration callback, an
application-root rectangle refresh, and RTTI-bound `CSlot` cursor-hit and
selection update. The earlier values are released, overwritten, or belong to
returned helpers; none reaches `CScript::run`. Same-register and one-hop calls
beyond 160 bytes, plus multi-hop or spilled forms, remain the next native
audit boundary.
Version 172 widens the one-hop register-transfer inventory from 160 to 176
bytes. Two additions cross command-`0x11`'s returning MessageBox error branch
and alias its already confirmed registered-definition `CScript::run`; one
earlier native-helper argument crosses two `ret 8` boundaries into the same
bounded `IUnknown::Release` route classified at 144 bytes. No candidate adds
a script receiver or command-`0x0E` target consumer. Same-register calls
beyond 160 bytes, one-hop calls beyond 176 bytes, and multi-hop or spilled
forms remain the next native audit boundary.
Version 173 widens the same-register inventory from 160 to 176 bytes. Its
five additions are a native audio-sink callback, DirectShow pin media-type
check, `IUnknown::AddRef`, `CMemAllocator::ReleaseBuffer`, and
`IReferenceClock::GetTime`; each reloads its real receiver after the scanner's
candidate is overwritten, branched away, or separated by returns. None adds
a script receiver or command-`0x0E` target consumer. Same-register and
one-hop calls beyond 176 bytes, plus multi-hop or spilled forms, remain the
next native audit boundary.
Version 174 widens the one-hop register-transfer inventory from 176 to 192
bytes. The complete set remains 11 routes and the added set is empty, so no
new script receiver or command-`0x0E` target consumer is present.
Same-register calls beyond 176 bytes, one-hop calls beyond 192 bytes, and
multi-hop or spilled forms remain the next native audit boundary.
Version 175 widens the same-register inventory from 176 to 192 bytes. Its five
additions resolve to `IDirectSoundBuffer::SetVolume`, application-root
rectangle refresh, a `CNormalSelect` composed-script popup callback,
RTTI-bound `CTitle` menu-A6 activation, and `CMemAllocator` interface
`IUnknown::AddRef`. Each scanner candidate is overwritten, consumed, or
separated by a function return before the actual receiver reload. None adds a
script receiver or command-`0x0E` target consumer. Same-register and one-hop
calls beyond 192 bytes, plus multi-hop or spilled forms, remain the next
native audit boundary.
Version 176 widens the same-register inventory from 192 to 208 bytes. Its two
additions are a script-stream byte read in expression token `0xF6` and an
MSVC C++ unwind non-local-goto action thunk. The first scanner candidate is
consumed in the distinct token-`0xF3` case; the second is pushed before `EAX`
is overwritten and its function returns. Neither candidate reaches the
reported call, and neither call is `CScript::run` or a command-`0x0E` target
consumer. Same-register calls beyond 208 bytes, one-hop calls beyond 192
bytes, and multi-hop or spilled forms remain the next native audit boundary.
Version 177 widens the one-hop register-transfer inventory from 192 to 208
bytes. Three additions cross a `CAdvSelect` return into adjacent `UnionRect`
argument preparation before application-root rectangle refresh; one is an
unaligned decode inside a document-member load before a `CNormalSelect`
internal-record push; one crosses two native wrapper returns before an
independent `IUnknown::Release`. None adds a script receiver or
command-`0x0E` target consumer. Same-register and one-hop calls beyond 208
bytes, plus multi-hop or spilled forms, remain the next native audit boundary.
Version 178 widens the one-hop register-transfer inventory from 208 to 224
bytes. Its sole addition consumes a rectangle coordinate as a delta in the
current helper and crosses `ret 0x10` plus padding into the paired native
control slot-`+0x28` query already bounded by v166. It adds neither a script
receiver nor a command-`0x0E` target consumer. Same-register calls beyond
208 bytes, one-hop calls beyond 224 bytes, and multi-hop or spilled forms
remain the next native audit boundary.
Version 179 widens the same-register inventory from 208 to 224 bytes. Its
three additions resolve to application-root rectangle refresh after a public
context-record loop, imported `CloseHandle` after a `Cai5WaveThread`
initializer return, and command-`0x05` dynamic `global_u8` write after native
bitmap copying and a transparent-RGB test. In each route the actual call
receiver or import is reloaded independently; none is `CScript::run` or a
command-`0x0E` target consumer. Same-register and one-hop calls beyond 224
bytes, plus multi-hop or spilled forms, remain the next native audit boundary.
Version 180 widens the same-register inventory from 224 to 240 bytes. Its
three additions resolve to `Cai5OggVorbisFileUser` source-window
configuration after the candidate owner has returned, mutually exclusive
modal auxiliary branches `0x0101` and `0x0103` whose latter branch invokes
public-context presentation subcommand 7 mode 1, and DirectShow peer-pin
`IUnknown::AddRef` after several helper boundaries. Each actual receiver is
independently reloaded; none is `CScript::run` or a command-`0x0E` target
consumer. Same-register calls beyond 240 bytes, one-hop calls beyond 224
bytes, plus multi-hop or spilled forms, remain the next native audit boundary.
Version 181 widens the one-hop register-transfer inventory from 224 to 240
bytes. Its four additions separate a stored-and-overwritten rectangle
coordinate from a later `UnionRect` pointer and `ScreenToClient` reload, an
MSVC exception-chain restore from later native critical-section entry, a
`CFileStream` size call/result temporary from
`IMediaSample::SetActualDataLength`, and two wrapper returns from a final
`IUnknown::Release`. None adds a `CScript::run` receiver or command-`0x0E`
target consumer. Same-register and one-hop calls beyond 240 bytes, plus
multi-hop or spilled forms, remain the next native audit boundary.
Version 182 widens the same-register inventory from 240 to 256 bytes. Its
three additions separate an already consumed window-member value from a later
application-root rectangle refresh, a tail-jumped composed-script view adapter
from the following record parser's independent slot-`+0x0C` call, and a
returned position-pass-through helper argument from a later
`ITypeInfo::Invoke`. None adds a `CScript::run` receiver or command-`0x0E`
target consumer. Same-register calls beyond 256 bytes, one-hop calls beyond
240 bytes, plus multi-hop or spilled forms, remain the next native audit
boundary.
Version 183 widens the one-hop register-transfer inventory from 240 to 256
bytes. Its one addition separates a consumed presentation coordinate and
overwritten source register from a later coordinate transfer into a direct
native helper; the eventual virtual call independently reloads the
application root and invokes its checked full-frame rectangle-refresh slot.
It adds neither a `CScript::run` receiver nor a command-`0x0E` target
consumer. Same-register and one-hop calls beyond 256 bytes, plus multi-hop or
spilled forms, remain the next native audit boundary.
Version 184 widens the same-register inventory from 256 to 272 bytes. The
complete inventory remains the same 145 sites with fingerprint
`d63c59fc57d0ccf34a770900e99a7d72d5bbf620c89b26c2dcdc26adffb7b49c`;
the empty delta fingerprints to
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
The widened window therefore adds neither a `CScript::run` receiver nor a
command-`0x0E` target consumer. Same-register calls beyond 272 bytes,
one-hop calls beyond 256 bytes, plus multi-hop or spilled forms, remain the
next native audit boundary.
Version 185 widens the one-hop register-transfer inventory from 256 to 272
bytes. Its one addition starts from a native rectangle-limit value already
consumed by a comparison. The source register is overwritten before the
coordinate transfer, the transferred coordinate is consumed by a direct
helper, and the candidate-owning function returns before a separate handler
reloads owner member `+0x254` and invokes native-control slot `+0x28`. It adds
neither a `CScript::run` receiver nor a command-`0x0E` target consumer.
Same-register and one-hop calls beyond 272 bytes, plus multi-hop or spilled
forms, remain the next native audit boundary.
Version 186 widens the same-register inventory from 272 to 288 bytes. Its two
additions separate a consumed selection-rectangle coordinate from later
`CAI5View::ScreenToClient`, and a consumed copied-record mode from the
independently entered `state_u16[18]` literal writer's adjusted document
slot-`+0x14` preflight. Both candidate owners return before the actual call
receiver is reloaded. Neither adds a `CScript::run` receiver or command-`0x0E`
target consumer. Same-register calls beyond 288 bytes, one-hop calls beyond
272 bytes, plus multi-hop or spilled forms, remain the next native audit
boundary.
Version 187 widens the one-hop register-transfer inventory from 272 to 288
bytes. Its one addition begins in a completed MSVC exception-frame epilogue:
the loaded value restores the saved SEH chain and its owner returns. A second
handler aliases its independent `this` pointer and also returns. Only a later
worker overwrites the target register from import cell `0x004720C8` before
calling the PE-import-bound `KERNEL32.LeaveCriticalSection`. The candidate
therefore cannot reach that call and is not `CScript::run`.
Version 188 widens the same-register inventory from 288 to 304 bytes. Its
seven additions are all cross-return false positives: a consumed selection
rectangle argument before independent `CAdvSelect` preparation; an Ogg
thread buffer-region argument before a separately loaded
`Cai5OggVorbisDecodeUser` callback; a consumed native string before imported
`USER32.LoadStringA`; a consumed message argument before a separately loaded
DirectInput device call; a copied source string before an independently
loaded character renderer; and two consumed helper arguments before the
RTTI-qualified `CBaseRenderer` destructor releases an owned helper and calls
imported `KERNEL32.DeleteCriticalSection`. None adds a `CScript::run` receiver
or command-`0x0E` target consumer. Same-register calls beyond 304 bytes,
one-hop calls beyond 288 bytes, plus multi-hop or spilled forms, remain the
next native audit boundary.
Version 189 widens the one-hop register-transfer inventory from 288 to 304
bytes. Its one addition starts at the already RTTI-bound Ogg stream handler's
`IDirectSoundBuffer` slot-`+0x10` cursor-query function pointer. That pointer
is immediately called and replaced by its result. A later slot-`+0x60` Lock
call supplies the apparent transfer value, and the final call register is
independently reloaded from the same buffer's slot `+0x4C`, the already
confirmed Unlock operation. It adds neither a `CScript::run` receiver nor a
command-`0x0E` target consumer. Same-register and one-hop calls beyond 304
bytes, plus multi-hop or spilled forms, remain the next native audit boundary.
Version 190 widens the same-register inventory from 304 to 320 bytes. Its
three additions are conservative false positives: a native interface slot is
spilled before EAX is overwritten and an application-document secondary
subobject reloads slot `+0x44`; an aligned stack-argument load is consumed by
a direct helper and returns two functions before an incoming COM interface
calls `IUnknown::AddRef`; and another aligned stack-argument load returns
before a native filter interface calls `IUnknown::QueryInterface` for the
SDK-qualified `IQualityControl` IID. None adds a `CScript::run` receiver or a
command-`0x0E` target consumer. Same-register calls beyond 320 bytes,
one-hop calls beyond 304 bytes, plus multi-hop or spilled forms, remain the
next native audit boundary.
Version 191 widens the one-hop register-transfer inventory from 304 to 320
bytes. Its one addition is wholly inside the already RTTI-bound Wave stream
handler: the buffer slot-`+0x10` `GetCurrentPosition` function pointer is
called immediately and overwritten by its HRESULT; a later owner slot-`+0x60`
call supplies the apparent transfer result, whose target register is then
zeroed for division; and the final call register is independently reloaded
from the same buffer's slot `+0x4C` `Unlock`. It adds neither a
`CScript::run` receiver nor a command-`0x0E` target consumer. Same-register
and one-hop calls beyond 320 bytes, plus multi-hop or spilled forms, remain
the next native audit boundary.
Version 192 widens the same-register inventory from 320 to 336 bytes. Its four
additions cross returned native helper boundaries before the eventual caller
independently reloads an RTTI-bound Cai5 audio-thread cursor-query slot, a
CAI5 window message slot, `IReferenceClock::Release`, or
`IMemAllocator::Release`. None adds a `CScript::run` receiver or a
command-`0x0E` target consumer. Same-register calls beyond 336 bytes,
one-hop calls beyond 320 bytes, plus multi-hop or spilled forms, remain the
next native audit boundary.
Version 193 widens the one-hop register-transfer inventory from 320 to 336
bytes. Two additions cross returned heap and message-pump helpers before the
actual window-style and popup-handle calls reload their native receivers.
Seven additions share one native interface-output candidate but transfer
renderer self aliases in adjacent functions; all return before the final
handler independently reloads `IMediaSample` slot `+0x14` `GetTime`. None adds
a `CScript::run` receiver or command-`0x0E` target consumer. Same-register and
one-hop calls beyond 336 bytes, plus multi-hop or spilled forms, remain the
next native audit boundary.
Version 194 widens the same-register inventory from 336 to 352 bytes. Its one
addition crosses the returned AX renderer and seven unrelated native helpers.
The final helper belongs to RTTI-bound `CAsyncOutputPin`, reloads its async
source member, and calls `CFileStream` slot `+0x14`, whose exact handler
returns alignment 1 for a sample-buffer alignment test. It adds neither a
`CScript::run` receiver nor a command-`0x0E` target consumer. Same-register
calls beyond 352 bytes, one-hop calls beyond 336 bytes, plus multi-hop or
spilled forms, remain the next native audit boundary.
Version 195 widens the one-hop register-transfer inventory from 336 to 352
bytes. Its three additions begin at an earlier `CAdvSelect` rectangle
coordinate. That owner overwrites the register and returns before the adjacent
selection method creates three independent `UnionRect` stack-pointer aliases;
the final call reloads application-root slot `+0x14` for rectangle refresh.
None adds a `CScript::run` receiver or command-`0x0E` target consumer.
Same-register and one-hop calls beyond 352 bytes, plus multi-hop or spilled
forms, remain the next native audit boundary.
Version 196 widens the same-register inventory from 352 to 368 bytes. The
first of two additions starts at `CBGSelect` member `+0x10`, whose checked
slot-`+0x08` handler passes the dynamic hit-table pointer directly to
`0x00411400`; the eventual indirect call reloads application-root slot
`+0x14` rectangle refresh. The second starts at modal surface destination X
in helper `0x004354E0`, which performs its own rectangle refresh and returns
at `0x00435684`. The later call belongs to presentation update `0x00435730`
and reloads the established public-context slot `+0x44` handler
`0x0042B2C0`, whose zero-coordinate script run and caller-context restoration
were already bounded independently. Neither addition carries the scanned
slot-`+0x10` value to the call or adds a command-`0x0E` target consumer.
Same-register calls beyond 368 bytes, one-hop calls beyond 352 bytes, plus
multi-hop or spilled forms, remain the next native audit boundary.
Version 197 widens the one-hop register-transfer inventory from 352 to 368
bytes. One route copies a profile-selected display-effect step width before
the value is negated and its register overwritten; the final call reloads
application-root slot `+0x14` for a full-frame rectangle refresh. The other
crosses returned position-pass-through helpers and an HRESULT transfer before
the final handler independently loads `IMediaSeeking::CheckCapabilities`.
Neither route adds a `CScript::run` receiver or command-`0x0E` target
consumer. Same-register and one-hop calls beyond 368 bytes, plus multi-hop or
spilled forms, remain the next native audit boundary.
Version 198 widens the same-register inventory from 368 to 384 bytes. Its
three additions cross returned native owners before independently loaded
`IDirectDraw7::SetCooperativeLevel`, active-state owner notification, and
`OLEAUT32::LoadRegTypeLib` calls. The source values are respectively a pixel-
transform loop count, a freed and cleared bitmap buffer, and a renderer-
constructor stack argument. None adds a `CScript::run` receiver or
command-`0x0E` target consumer. Same-register calls beyond 384 bytes, one-hop
calls beyond 368 bytes, plus multi-hop or spilled forms, remain the next
native audit boundary.
Version 199 widens the one-hop register-transfer inventory from 368 to 384
bytes. The one added route crosses the returned boundaries of
`CEnumMediaTypes::QueryInterface` and `Release`: the apparent transfer is the
native reference count, then `Next` independently reloads pin member `+0x08`
and invokes its slot-`+0x34` indexed media-type callback. The requested IID and
reference count do not reach that call, so this adds neither a `CScript::run`
receiver nor a command-`0x0E` target consumer. Same-register and one-hop calls
beyond 384 bytes, plus multi-hop or spilled forms, remain the next native
audit boundary.
Version 200 widens the same-register inventory from 384 to 400 bytes. Its one
addition begins in a shared audio-parser owner that stores status and returns;
a constructor and destructor also return before a distinct `Cai5WaveThread`
initializer reloads its own slot-`+0x0C` shared-memory allocator and stores the
wave-buffer result at member `+0xCC`. The scanned owner does not reach that
call, so this adds neither a `CScript::run` receiver nor a command-`0x0E`
target consumer. Same-register calls beyond 400 bytes, one-hop calls beyond
384 bytes, plus multi-hop or spilled forms, remain the next native audit
boundary.
Version 201 widens the one-hop register-transfer inventory from 384 to 400
bytes. The two additions share one consumed and overwritten presentation-
coordinate owner, then follow two independently reloaded coordinates into
native rectangle helpers. The eventual virtual call independently reloads the
application root and its full-`640x400` rectangle-refresh slot. Neither path
adds a `CScript::run` receiver or command-`0x0E` target consumer. Same-register
and one-hop calls beyond 400 bytes, plus multi-hop or spilled forms, remain the
next native audit boundary.
Version 202 widens the same-register inventory from 400 to 416 bytes. One
addition starts from a GDI font handle which is deleted, cleared, and returned
before the next public-context character-stream function reloads slot `+0x58`.
The other starts from a temporary stack object's vtable, which is consumed by
that object's slot-`+0x10` cleanup before return; the later presentation
subcommand-7 function independently reloads public-context slot `+0x28` for
the native voice-queue callback. Neither adds a `CScript::run` receiver or
command-`0x0E` target consumer. Same-register calls beyond 416 bytes, one-hop
calls beyond 400 bytes, plus multi-hop or spilled forms, remain the next native
audit boundary.
Version 203 widens the one-hop register-transfer inventory from 400 to 416
bytes. Its two additions cross mutually exclusive error/string-copy paths
before an independently loaded application-document manager callback, and an
already released COM member plus fresh `CFileReader` allocation before the
new object's `IUnknown::AddRef`. Neither adds a `CScript::run` receiver or
command-`0x0E` target consumer.
Version 204 widens the same-register inventory from 416 to 432 bytes. Its one
addition is the `IAsyncReader::Request` user-cookie stack argument, consumed
and stored in an async request record before its handler returns. A later
handler independently reloads `IMediaSample` slot `+0x30` for
`SetActualDataLength`. This adds neither a `CScript::run` receiver nor a
command-`0x0E` target consumer. Same-register calls beyond 432 bytes, one-hop
calls beyond 416 bytes, plus multi-hop or spilled forms, remain the next native
audit boundary.
Version 205 widens the one-hop register-transfer inventory from 416 to 432
bytes. One addition consumes a `WM_MOUSEWHEEL` stack argument before return,
crosses an independent `ShowCursor` target, and terminates at a separately
loaded `RegisterWindowMessageA` import. The other consumes a requested IID
before return, crosses a `CheckCapabilities` HRESULT, and terminates at an
independently queried `IMediaSeeking::IsFormatSupported` receiver whose two
RTTI-bound primary-vtable cells are checked. Neither adds a `CScript::run`
receiver or command-`0x0E` target consumer. Same-register and one-hop calls
beyond 432 bytes, plus multi-hop or spilled forms, remain the next native audit
boundary.
Version 206 widens the same-register inventory from 432 to 448 bytes. It adds
no candidate: the complete set remains 171 calls with the same fingerprint.
Same-register calls beyond 448 bytes, one-hop calls beyond 432 bytes, plus
multi-hop or spilled forms, remain the next native audit boundary.
Version 207 widens the one-hop register-transfer inventory from 432 to 448
bytes. It adds no route: the complete set remains 47 routes with the same
fingerprint. Both search forms beyond 448 bytes, plus multi-hop or spilled
forms, remain the next native audit boundary.
Version 151 classifies compact slot-`+0x10` call `0x00448560` as the
`IMediaSample::GetSize()` fallback used by a native DirectShow sample-property
snapshot helper. The same helper first queries `IMediaSample2` and requests a
`0x30`-byte property block through slot `+0x4C`; three RTTI-bound renderer
vtables share its sole direct caller. The route is therefore excluded from
direct `CScript::run` coverage, while MES reachability remains unclaimed.
Version 152 classifies compact slot-`+0x10` call `0x0044921C` as the primary
`CMemAllocator::Free` callback reached inside the offset-`0x0C`
`IMemAllocator::Decommit` handler. Exact RTTI, primary/interface vtables, and
both constructor/destructor installations bind the receiver; the paired
`Commit` handler calls the adjacent `Alloc` slot, while this concrete `Free`
body is a single return. It is excluded from direct `CScript::run` coverage,
leaving four compact receiver identities and non-compact consumers unresolved.
Version 153 classifies compact call `0x0044A29F` as the same primary
`CMemAllocator::Free` callback reached from the offset-`0x0C`
`IMemAllocator::ReleaseBuffer` handler. Its exact slot `+0x20` body returns
the sample to the free list and invokes `Free` only when a pending decommit
sees every allocated sample returned. This is native DirectShow allocation
plumbing rather than direct `CScript::run`; three compact receiver identities
and non-compact consumers remain unresolved.
Version 154 classifies compact call `0x0044AECC` as
`IReferenceClock::AdviseTime` inside RTTI-bound
`CBaseRenderer::ScheduleSample`. The base renderer and both checked video
renderer overrides bind the scheduling chain, while the exact call passes two
reference times, a render event, and an advise-cookie pointer. This native
DirectShow clock route is excluded from direct `CScript::run`; two compact
receiver identities and non-compact consumers remain unresolved.
Version 155 classifies the final compact calls `0x0044D475` and
`0x0044D643` through RTTI- and constructor-bound `CPosPassThru` and
`CRendererPosPassThru` objects. The first is the secondary `IDispatch::Invoke`
handler's `GetTypeInfo` request; the second queries the retained upstream
interface for the exact `IMediaSeeking` IID and forwards
`CheckCapabilities`. Both are native DirectShow position plumbing rather than
`CScript::run`. The compact same-register slot-`+0x10` inventory is now fully
classified; possible non-compact indirect consumers and command-`0x0E` host
activation/restoration remain unresolved.
Version 156 expands the scan to direct-memory `FF /2` calls, `FF /4` jumps,
and absolute transfers through the five checked script vtable cells. It finds
three `[register + 0x10]` calls and binds all three to static backend
descriptor tables used only by RTTI-bound `Cai5OggVorbisDecodeUser` setup and
clear methods. Exact table roots, descriptor pointers, callback cells, and
complete helper caller sets are audited; none supplies a script receiver.
No matching direct-memory jumps or absolute script-cell transfers exist.
Register-separated or longer-range indirect dataflow remains the next bounded
search frontier.
Version 106 additionally binds presentation subcommands 5, 6, and 7 to three
typed-record adapters, public-context slots `+0x20`, `+0x24`, and `+0x28`, and
their common callback-result store in state dword `+0x2134`. Exact dispatcher
table entries, direct calls, and return tails exclude these three sites from
the command-`0x0E` active-target consumer search without assigning gameplay
semantics to subcommands 5 or 6.
Version 107 binds presentation subcommand 10's jump-table entry and direct
adapter call to public-context virtual slot `+0x34`. All three checked public
context vtables resolve that slot to `0x0042A8B0..0x0042ABA0`. Its sole
field-first alias at literal site `0x0042A8C5` is state control word
`+0x20BC`: the handler snapshots the word, clears bit `0x0002` while it
performs bounded surface composition and root refresh, and restores the
snapshot before returning. Exact adapter, entry/tail, vtable, dispatcher, and
call evidence excludes this path from the command-`0x0E` active-target
consumer search without assigning higher-level gameplay meaning to its three
mode arguments.
Version 108 partitions six more field-first aliases inside the already bound
presentation-subcommand-11 consumer `0x0042AC30..0x0042B015`. Exact mode
bodies show mode 1 reading auxiliary RGB/context dword `+0x2178`, mode 2
reading active-surface index `+0x20BA` twice around its confirmed fill/tail
path, mode 4 reading the same active-surface index twice around its bounded
helper/tail path, and mode 5 reading `+0x2178` as an auxiliary helper argument.
These state-field reads do not consume the leading command-`0x0E` target
string. Mode 4/5's higher-level pixel effects and composition order remain
unresolved.
Version 109 partitions three more field-first aliases through presentation
subcommand 12. Dispatcher entry `0x00428500`, adapter `0x0042B040`, and all
three checked public-context slot-`+0x3C` entries bind handler
`0x0042B070..0x0042B28A`. Sites `0x0042B0EC`, `0x0042B1AD`, and
`0x0042B20A` read state control word `+0x20BC` bit 8 while the bounded body
polls input and presentation paths. The body does not consume the leading
active target string, load or run a target, or restore a caller. Numeric input
and resource identifiers remain unresolved rather than receiving authored
labels.
Version 110 partitions two more field-first aliases through presentation
subcommands 15 and 16. Dispatcher entries `0x0042850C` and `0x00428510`,
their two direct adapter calls, and all three checked public-context vtables
bind slots `+0x48` and `+0x4C` to handlers `0x0042B370` and `0x0042B3C0`.
The adapters store the 16-bit callback results in state words `+0x20A8` and
`+0x20E4`. Exact adapter and handler bodies exclude these paths from the
command-`0x0E` active-target consumer search without assigning user-facing
meanings to either callback.
Version 111 partitions eight more field-first aliases through presentation
subcommand 19 and v97's bounded public-context notification store. The outer
dispatcher and direct adapter call bind slot `+0x58` to the primary/common
notification implementations. The adapter stores record-shape-5's 16-bit
callback result in state `+0x20A8` and record-shape-4/3 DWORD results in
`+0x2134`; the common handler's five sites are its confirmed `+0x20BC`
enable/pending-mask accesses. Exact bodies exclude this route from the
command-`0x0E` active-target consumer search without assigning user-facing
meaning to the notification.
Version 112 partitions two more field-first aliases through presentation
subcommand 20. The outer dispatcher and direct adapter call bind
`0x0042B850..0x0042B8A8` to public-context slot `+0x44`; all three checked
vtables resolve the slot to `0x0042B2C0`. The adapter sets and clears state
control-word bit `0x0800` around that call and initializes result dword
`+0x2134` to zero. Exact bytes exclude this guard from the command-`0x0E`
active-target consumer search without assigning a user-facing call meaning.
Version 113 partitions two more field-first aliases through presentation
subcommand 22. The outer dispatcher calls the exact six-selector
`CInputName` adapter at `0x0042B930..0x0042BAD7`; its start and stop helpers
use `WINNLSEnableIME` and IMM32 composition-context APIs. Selector 0 reads
public-state input coordinates `+0x20D0/+0x20D2`, and selector 4 writes the
bounded text-copy byte count to public-state word `+0x20A8`. The complete
adapter and selector table exclude this native name-input bridge from the
command-`0x0E` active-target consumer search.
Version 114 partitions three more field-first aliases through presentation
subcommand 23. Its dispatcher uses public-context slot `+0x60`; all three
checked vtables resolve that slot to the exact modal-media handler
`0x0042BAF0..0x0042BE5C`. Selector 0 opens, installs, and runs the parsed
presentation-record filename through DirectShow, while selector 1 stops and
releases it. Exact handler bytes and interface GUIDs bind
`IGraphBuilder`/`IMediaEvent`/`IBasicAudio`/`IMediaControl`, public result word
`+0x20A8`, and control bit `+0x20BC & 0x4000`. This distinct record filename
does not consume the command-`0x0E` active target; the accepted extension and
user-facing media meaning remain unresolved.
Version 115 partitions five more field-first aliases through presentation
subcommand 24. The exact dispatcher calls a parsed-record adapter and its
eight-selector helper. Selectors 2 and 3 use state pointer `+0x2158` for
bounded record/public-context transfers, while selector 5 writes `0xFFFF` to
result word `+0x20A8` on lookup failure. Exact adapter/helper bytes, direct
calls, and all eight selector-table entries exclude this record bridge from
the command-`0x0E` active-target consumer search without assigning
user-facing meanings to the selectors.
Version 116 partitions 17 more field-first aliases through presentation
subcommands 25 through 29. Exact dispatcher tails, five public-context slots
across all three checked vtables, two direct adapters, seven complete function
extents, and subcommand 26's five-entry selector table bind the family to
active-surface records, callback/bit-store results, private-profile access,
fixed display values, and a host time sample. None consumes the command-`0x0E`
active target, loads or runs a MES stream, forwards an activation coordinate,
or restores a caller. The user-facing service meanings remain unresolved;
only one field-first alias remains outside the bounded families.
Version 117 partitions that final field-first alias in the RTTI-bound
`CNormalSelect` renderer. Its exact local guard sets public control-word flag
`0x0800`, stores a callback argument in state dword `+0x2134`, calls the
indirect slot `+0x44`, and clears the flag. The checked
renderer extent, both direct callers, adjusted pointer reload, and guard bytes
show no retained-name consumption, target coordinate/context, MES load/run,
or caller restoration. All 123 field-first aliases are now classified; P2-05
remains open at the higher-level indirect host/ownership edge rather than at
another raw state-displacement candidate.
Version 118 expands that guard to its receiver loads and corrects the slot's
ownership. The renderer loads the application document at root member
`+0xE8`, adds `8` to select its composed script-manager subobject, and calls
that object's slot `+0x44`. All five checked composed-script tables resolve it
to `0x0043E700`, which tail-dispatches application view member `+0xE4` through
`CAI5View` slot `+0x0C` to popup presentation. The view handler does not
consume the passed callback argument or any active target and performs no MES
load, install, run, coordinate/context forwarding, or caller restoration.
This binds the final alias to the already audited command-`0x0E` mode-`0x80`
popup adapter without closing P2-05's remaining arbitrary-target host search.
Version 119 exhausts the popup presentation handler's remaining indirect
calls. Checked secondary vtables bind `CAI5View` window slots `+0x3C/+0x44`
to `GetClientRect` and `ClientToScreen`, and `CPopUpMenu` window slots
`+0x28/+0x1C` to `SetForegroundWindow` and `SetWindowPos`. Exact leaf bytes
show only client-to-screen geometry conversion, foreground activation, and
popup placement. No path consumes the retained target, forwards a script
coordinate/context, loads or runs MES, or restores a caller; P2-05 moves past
the now-complete popup window lifecycle.
Version 120 fixes the next script-runner search boundary. The concrete
`CScript::run` handler address appears only in five RTTI-bound script-family
slot-`+0x10` vtable cells and has no direct relative callers. A complete
compact same-register slot-`+0x10` scan over the original runtime `.text`
finds 63 sites. Application startup, command-`0x0F` nested execution, and
presentation-subcommand-8 inline execution are the three already qualified
routes; the other 60 sites remain receiver-unclassified and fingerprinted.
The audit deliberately leaves non-compact indirect calls open and does not
promote this inventory to command-`0x0E` target activation.
Version 121 classifies four members of the compact remainder as application
view lifecycle calls. Each exact block loads application root member `+0xE4`
and invokes `CAI5View` slot `+0x10`, whose checked handler is popup
visibility/dismiss logic rather than `CScript::run`. The three owning
methods were initially misattributed; version 131 corrects them to
`CAI5Display` vtable slots `+0x08/+0x0C/+0x10`. Removing their four calls
leaves 56 receiver-unclassified compact sites.
Version 122 classifies four more compact calls as popup-window visibility
tests. They all reach `CAI5View` member `+0x6C`, adjust its `CPopUpMenu`
receiver by `+4`, and invoke secondary-vtable slot `+0x10`, which resolves to
the exact `IsWindowVisible` wrapper at `0x0040C120`. These calls cannot be
direct `CScript::run` receivers; 52 compact receiver identities and possible
non-compact indirect forms remain open.
Version 123 links the already complete v94 full-frame wait/input message-pump
route to the same global compact inventory. Its call at `0x0041045B` uses the
message pump's `CAI5View` argument and slot `+0x10`, resolving to popup-dismiss
handler `0x00410320`, not `CScript::run`; 51 compact receiver identities remain.
Version 124 links the existing modal-confirm finalizer at `0x00434F67` to the
global inventory. The modal-control vtable maps its slot `+0x10` to result-copy
and stop handler `0x00435300`, not `CScript::run`. Version 125 additionally
classifies the command-`0x11`, command-`0x1D`, and public-context
coordinate/context swap-run-restore calls as direct script-family routes; 47
compact receiver identities remain. Version 126 classifies call
`0x004024B9` as the shared `CAI5Arc`/`CAI5File` slot-`+0x14` close forwarder:
both receiver tables map leaf slot `+0x10` to `0x004094F0`, which closes the
native handle and clears stream state rather than running a script. Forty-six
compact receiver identities remain. Versions 127-128 initially attributed
`0x00406EDF` and `0x00406F35` to distant application-root script slots;
version 131 withdraws that claim after binding the adjacent table start to
RTTI-qualified `CAI5Display`. Both are display-mode self calls. Version 129
excludes candidate
`0x00408A89` as a conservative compact-scanner false positive: the candidate
register is overwritten by a `CPopUpMenu` slot-`+0x4C` native-handle lookup
before an `EnableMenuItem` call. Forty-three compact receiver identities
remain. Version 130 classifies `0x0040B366` as the RTTI-bound
`Cai5OggVorbisFileUser` terminal-page rewind: its slot `+0x10` seeks the native
stream to its stored origin and clears its cursor, not a script execution.
Version 131 corrects v127-v128's application-root ownership attribution:
`0x00406EDF` and `0x00406F35` are `CAI5Display` self-calls to its windowed
slot, not current-script execution. It also classifies calls `0x0040CAD7` and
`0x0040CBAA` through the `CAI5View +0xA0` RTTI-bound `CAI5Display` object.
The first selects its windowed slot; the second toggles between the checked
640x480 exclusive mode and windowed mode while preserving the logical cursor
point. None is a script receiver, leaving 40 compact receiver identities.
Version 132 additionally classifies calls `0x0040D14F`, `0x0040D176`,
`0x0040D38C`, and `0x0040D401` inside the RTTI-bound native Ogg stream
family. The first pair release two `Cai5OggWaveThread` buffers through its
`VirtualFree` wrapper; the third captures the current underlying file position
through `Cai5OggVorbisDecodeUser`/`Cai5OggVorbisFileUser`; the fourth queries
the stream's DirectSound play/write cursors. None consumes a MES target or
runs a script, leaving 36 compact receiver identities.
Version 133 classifies calls `0x0040DFC8`, `0x0040E4D4`, `0x0040F358`, and
`0x0040FEF9` as native Wave/DirectSound service dispatch. The first queries
the global `IDirectSound` interface's device-capability structure; the second
releases a `Cai5WaveThread` buffer through the already checked `VirtualFree`
wrapper; the third queries play/write cursors through member `+0x30`; and the
fourth unlocks two regions returned by the matching buffer Lock call. RTTI,
vtable ownership, the DirectSound creation path, and exact call blocks exclude
all four as script receivers, leaving 32 compact receiver identities.
Version 73 additionally resolves both active-state `+0x2158` destination
references as nonzero-format scratch-buffer paths in the bounded MES and Data
ARC loaders. Their lookup key is a distinct caller filename argument, and the
scratch payload is consumed only by the optional AI5 LZ helper. Neither loader
is the unresolved command-`0x0E` host activation consumer.
Version 83 additionally binds the two application-document adjusted
`CScript` slot-`+0x14` step calls, their helper extents, and all thirteen
direct callers. The bounded family stops on presentation flag 8 and contains
no active-string pointer, code-coordinate, context-pointer, or slot-`+0x10`
runner call. Seven raw adjusted-state aliases in one caller are retained and
bound to presentation words `+0x20D0`, `+0x20D2`, `+0x20A8`, and `+0x20BC`;
they are not silently treated as string consumption. This closes that
presentation-step candidate without closing P2-05's higher-level host search.
Version 84 distinguishes the composed `CScript` method-table slot `+0x58`
from the public-context notification slot with the same numeric offset. The
top-level runner's flag-8 branch clears the flag and calls the composed slot
with the already installed stream pointer at `CScript +0x70`; all five bounded
method tables resolve it to `0x0043E7C0`. That installer selects
`stream + 4` as context, derives the code start as
`stream + 4 + entry_count * 4`, and clears the stream cursor. It receives no
active target string and performs no archive lookup, so it is recorded as a
root-stream re-entry boundary rather than command-`0x0E` target activation.
Version 85 follows application-document initialization and binds the root
stream's identity. `CAI5Doc`'s adjusted slot `+0x04` initializer reads
`Common/StartMes` (default `start.mes`), copies the chosen name to the active
state, loads the named `mes.arc` entry through slot `+0x20` into direct
`CScript +0x70`, and installs that same buffer through slot `+0x58`. The v84
flag-8 reset therefore re-enters the configured startup MES code start. This
does not resolve command-`0x0E`'s separate target activation coordinate or
caller restoration.
Version 86 follows the original application lifecycle after that initializer.
The single direct caller of dispatcher `0x00404730` enters root-object startup
slot `+0x08`; its success value 1 gates root slot `+0x10`. That slot resolves
to thunk `0x004059C0`, which adjusts `CAI5Doc +0xE8` to its virtual `CScript`
base and tail-dispatches slot `+0x10`, the checked runner at `0x0043D560`.
The configured startup stream is therefore installed and executed by the
original host. This closes startup execution but does not invent a
command-`0x0E` target coordinate, caller restoration, or isolated-preview
startup inheritance.
Version 87 extends the checked runner from the prior flag-8 reset site through
its full `0x0043D560..0x0043D630` extent. Nested runner depths decrement and
return without clearing flag 8. Command `0x0F` restores its temporary script
context before testing that flag, but the flag-set exit skips the normal
active-name and caller-coordinate restoration, allowing the flag to propagate
to depth one and trigger the configured `START.MES` reset. The outer
application lifecycle posts its quit request immediately after the run call,
which excludes a separate post-run active-name consumer. Companion startup
audit v2 also binds the `START.MES` root bootstrap and the sole stored terminal
command `0x0E` naming `OPEN.MES`; it does not claim that every root path
reaches that record or supply the target activation coordinate. The remaining
P2-05 frontier is therefore the in-loop consumer that turns the retained name
into a loaded and executed target.
Version 88 resolves the mode-`0x80` branch of that in-loop step dispatch. Its
sparse table reaches the flag-8 branch, composed `CScript` slot `+0x44`, the
application `CAI5View` slot `+0x0C`, and `CPopUpMenu` visibility/presentation.
The view converts mode `0x80` to 1. Exact bounded scans contain no active target
string, archive entry load, activation coordinate/context, or caller restore,
so this route is retained as a presentation/lifecycle exclusion rather than
the missing host activation.
Version 89 resolves the adjacent mode-`0x100` branch. Sparse-table byte 6
dispatches composed `CScript` slot `+0x48` to application `CAI5View` slot
`+0x10`. The view retains modes 8/16/32/64, changes `0x100` to 1, checks popup
visibility twice, and, when still visible, reaches popup slot `+0x24` with
argument 0. That slot is the exact `ShowWindow(window, 0)` adapter. Bounded
scans find no target string, archive lookup/load, activation coordinate or
context, or caller restore; this is a popup-dismiss lifecycle exclusion.
Version 90 resolves mode `0x40` through composed `CScript` slot `+0x54`.
`CAI5Doc` alone overrides that slot with a native transition handler; all
checked MES-load predecessors replace the active name with fixed `main.mes` or
`open.mes`, call the existing slot-`+0x20` archive loader into root-stream
destination `+0x70`, and install that stream through slot `+0x58`. A distinct
UI-success edge skips loading. Direct source comparison finds `OPEN.MES` but
not `MAIN.MES` in the configured authoritative archive, while the six audited
`43C.MES` command-`0x0E` handoffs remain present. The fixed transition is
therefore recorded as an archive-load lifecycle path but explicitly excluded
as the generic arbitrary retained-name consumer; P2-05 remains open.
Version 91 resolves mode `0x10` through composed `CScript` slot `+0x4C`.
`CAI5Doc`'s adjusted override references the single fixed literal
`Dialog04.mmo`, calls a bounded resource helper, and reaches a document
presentation dispatch before clearing control mask `0x10`; the other four
script-family handlers select only application view mode 8 or 1. Exact scans
of the complete branch/thunk/handler extents find no retained target string,
active coordinate/context, MES loader, root-stream installer, script runner,
or caller restoration. Direct read-only source comparison confirms
`DIALOG04.MMO` exists in the authoritative `mmo.arc`. This is a fixed MMO
presentation adapter and is excluded as the generic command-`0x0E` host
activation consumer; P2-05 remains open.
Version 92 resolves mode `0x20` through composed `CScript` slot `+0x50`.
`CAI5Doc`'s adjusted override applies fixed menu command `0x9C53`, calls the
imported `EnableMenuItem` and `DrawMenuBar` functions, reads
`DispEffect/IsPlay` through `GetPrivateProfileIntA`, sets presentation-state
mask `0x2000` and clears it when the profile result is 2, and retains view
mode 8 or sets mode 1
before clearing control mask `0x20`. The other four script-family handlers
only set application view mode 1. Exact scans of the complete
branch/thunk/handler extents find no retained target string, active
coordinate/context, MES loader, root-stream installer, script runner, or
caller restoration. This is a fixed menu/presentation-state adapter and is
excluded as the generic command-`0x0E` host activation consumer; P2-05 remains
open.
Version 93 resolves mode `0x08` through sparse-table byte 1 and jump-table
entry 1. The complete `0x0043D795..0x0043D79D` branch restores its bounded
frame, clears the return register, and returns without any virtual or native
dispatch. Exact scans find no retained target string, active
coordinate/context, MES loader, root-stream installer, script runner, or
caller restoration. This immediate-zero path is excluded as the generic
command-`0x0E` host activation consumer; P2-05 remains open.
Version 94 resolves modes `0x02` and `0x04`, whose sparse-table bytes at
`0x0043D7C0` and `0x0043D7C2` both select jump entry 0 and the bounded
`0x0043D71C..0x0043D76D` adapter. While either view mode remains active and
the shared message pump returns nonzero, the adapter repeats. It then invokes
the already audited application-root slot `+0x14` refresh with arguments
`0, 0, 640, 400, 0`, followed by composed `CScript` slot `+0x3C` with input
selector 0. That handler drains an already-active Return, Numpad Enter, or
input-member-`+0x1C` state while the message pump remains live and active-state
flag 8 is clear. The message pump's own slot-`+0x10` call is receiver-bound to
`CAI5View`, not the composed `CScript` runner. Exact scans find no retained
target string content, coordinate/context, MES loader, root-stream installer,
script runner, or caller restoration. This full-frame wait/input lifecycle is
excluded as the generic command-`0x0E` host activation consumer; P2-05 remains
open.
Version 95 resolves application view mode `1`. Its unsigned
`view_mode - 2` index is `0xFFFFFFFF`, above the sparse-table bound `0xFE`, so
the step handler bypasses the table and reaches `0x0043D6A1..0x0043D6BF`.
That bounded branch returns one because the current mode is not `8`; it makes
no virtual or native dispatch. Exact scans find no retained target string,
active coordinate/context, MES loader, root-stream installer, script runner,
or caller restoration. This direct continue-return path is excluded as the
generic command-`0x0E` host activation consumer; P2-05 remains open.
Version 96 follows the actual command-byte return cycle after the runner's
pre-dispatch flag-8 test. `CScript::run` fetches the next byte through slot
`+0x0C`; ordinary byte `0x0E` enters `CAI5Doc` slot `+0x70`, remap value 4,
and generic dispatcher `0x00418180`. Its command-`0x0E` wrapper calls the
already audited handler but discards that handler's return and forces result
one before returning to the runner. The runner can then pump messages and
loop; flag 8 is observed only by the next successful step, or remains set
while the current runner unwinds when the pump stops. Exact scans of the
bounded dispatch/return glue find no retained target read, active
coordinate/context, MES load, stream install, script run, or caller restore.
The missing arbitrary-name consumer is therefore outside this direct
post-handler glue, and P2-05 remains open at the indirect host/notification
boundary.
Version 97 resolves both public-context slot-`+0x58` notification
implementations and the complete selector-0-through-5 common body. The primary
implementation treats selector 6 as a zero result; the common implementation
uses control word `+0x20BC`, masks `0x10/0x20`, a 66-record capacity, and
`0x084C`-byte stride to reset, reserve, finalize, find, or query internal
records. Its sole direct call is the already audited zero-fill helper. Exact
first-field classification and bounded scans find no active target-string
read, coordinate/context, MES loader, root-stream installer, script runner, or
caller restoration. These notifications are therefore excluded as the
arbitrary command-`0x0E` retained-name activation consumer; P2-05 remains open
at a separate host edge.
Version 98 fingerprints the complete public-context slot-`+0x20` receiver
dispatcher at `0x00429A70..0x00429D54`. Its first argument is the command
handler's active-string pointer, but the dispatch table accepts only unsigned
selectors 0 through 5. A valid application string address therefore takes the
`ja` default edge at `0x00429AB2`, skips all six selector bodies, performs the
common cleanup at `0x00429B33..0x00429B6A`, and returns zero without
dereferencing the string. The complete dispatcher has no direct shared-state,
active-coordinate, or active-context literal, while the command path contains
no MES loader, stream installer, or script runner call. This slot-`+0x20`
receiver path is also excluded as the retained-name activation consumer;
P2-05 remains open at another indirect host edge.
Version 140 additionally resolves compact call `0x00429B31` inside selector
0 of that dispatcher. The selector body owns a stack-local RTTI-bound
`CFile`; its virtual slot `+0x10` reaches `0x00427D10`, which closes a nonzero
native handle and clears the local handle slot. The command-`0x0E` active
string cannot reach selector 0 because it takes the already fixed default
edge. This removes one scanner candidate without assigning a user-facing
meaning to the unrelated selector body and leaves 22 receiver-unclassified
compact calls plus non-compact forms.
Version 141 resolves the next compact candidate `0x00429EC6` in presentation
subcommand 6. Its adapter calls public-context slot `+0x24`; all three checked
context vtables bind that slot to `0x00429E00`, whose selector 0 constructs a
stack-local `CFile` and closes/clears its adjacent handle through the same
RTTI-qualified slot `+0x10` close handler. This native resource teardown is
not direct script execution. Selector meaning and authoritative MES
reachability remain unresolved, with 21 receiver-unclassified compact calls
plus non-compact forms left open.
Version 142 removes compact candidate `0x004302F7` as a scanner false
positive. RTTI, vtable cells, and the two exact vtable-install literals bind
the containing method to `CInputName` slot `+0x04`. It clears the active byte
and four cell-active bytes, then calls application-root rectangle refresh slot
`+0x14`; the earlier load from object member `+0x10` is the top coordinate and
the call register is overwritten before dispatch. This is native input-name
teardown, not direct script execution. The audit links it only to the same
RTTI-bound family used by presentation subcommand 22, deliberately leaves
authoritative MES reachability unresolved, and reduces the compact remainder
to 20 calls plus non-compact forms.
Version 143 classifies compact call `0x004333CE` as native DirectShow graph
teardown. The checked helper `0x00433320..0x0043343E` loads its
`IGraphBuilder` member at `+0x08`, enumerates filters, removes each through
virtual slot `+0x10`, releases the filter and enumerator, and re-enumerates.
Its exact four-caller set includes three calls in the already bounded
presentation-subcommand-23 handler—including confirmed selector-1
stop/release—and one setup-failure cleanup call. This is not direct script
execution and reduces the compact remainder to 19 calls plus non-compact
forms; no event-specific MES reachability is inferred from the native helper.
Version 144 classifies compact call `0x004343C2` as the shared native
selection-control preparation dispatch. Exact helper bytes and eight direct
record-dispatcher callers show modes 1/3/4 selecting the RTTI-qualified
`CAdvSelect` control at owner offset `+0x8C`, while modes 0/2 select
RTTI-qualified `CItemSelect` at `+0x1C4`; both receive the third native-record
expression through virtual slot `+0x10`. Constructor calls, vtable-install
literals, complete-object locators, type descriptors, and handler cells bind
the two receiver classes. The authoritative hash-bound `LIBLARY.LIB`
routine-40 records take the already confirmed mode-1 `CAdvSelect` route. This
is not direct script execution and reduces the compact remainder to 18 calls
plus non-compact forms; other helper-mode archive reachability remains
unresolved.
Version 145 classifies compact calls `0x0043DA47` and `0x0043DBFB` in the
file-read and file-write virtual methods shared by the five RTTI-bound
script/document-family tables. The methods construct stack-local `CAI5File`
and `CFile` receivers with adjacent native handles, then call the receivers'
slot `+0x10` close/clear handlers after successful I/O. Exact local-object
blocks, RTTI, type descriptors, vtables, and install literals exclude both
calls from recursive direct script execution. The audit does not assign a
specific MES route to these generic methods and leaves 16 compact receiver
identities plus non-compact forms unresolved.
Version 146 classifies compact calls `0x00443243` and `0x004433C6` in the
paired native fixed-`0x3000` buffer read/write helpers. Each helper constructs
a stack-local RTTI-qualified `CFile`, calls `ReadFile` or `WriteFile`, and
closes/clears the adjacent native handle through slot `+0x10`. The exhaustive
11-site read and six-site write caller inventories are independently
fingerprinted; the read set contains the already bounded public-context
state-reload call `0x00429400`. No specific MES entry is inferred, and 14
compact receiver identities plus non-compact forms remain unresolved.
Version 68 additionally binds the complete ten-entry logical-surface dimension
table and the two exact native literal writes which select logical surface 1.
Surface 1 is 2688x864. RTTI, complete-object locators, secondary vtables,
constructors, entry virtuals, and renderer calls attribute those writes to
`CBGSelect` and `CNormalSelect` selection-presentation paths. This narrows the
surface-producer family but does not establish that either instance or its
pixel lifetime reaches EVENTB14 routine 21; Event Player therefore retains the
ARC-backed world-map result as a source-qualified projection.
Version 69 additionally follows the bank-zero word pointer initialized with
`state+0x20B8` and binds the adjacent word `banked_u16[0][1]` to the named-MMO
consumer's active-surface state `+0x20BA`. This makes the exact EVENTB02 and
EVENTB14 write-8 -> AN-MMO-load sequences sufficient to identify their
surface-8 AX producer, while leaving unrelated route lifetime and host cadence
unclaimed.
Version 70 locks the state buffer's byte-fill helper as well as its caller. A
new `0x3194`-byte allocation is zero-filled over `[0x0000,0x3190)` before the
owner backpointer at `0x3190` is installed. Because command `0x03` maps
`global_u8` from offset `0x80`, DENSHA routine-40 gate index 2461 maps to
zero-filled offset `0x0A1D` and therefore has new-state default zero. The
serialized reload path remains a separate boundary and may replace that
default; tools must preserve the current value rather than synthesize it.
Version 53 retains command-`0x0E`'s complete bounded handler, all three
public-context receiver vtables, both receiver implementations, and the full
known flag-bit-8 lifecycle (15 readers, three writers). Slot `+0x20` receives
the active-string pointer as its switch argument and takes the bounded default
path; slot `+0x58` receives the parsed selector as a notification. The stream
loop later clears the flag in mode 1 and resets its private stream coordinate
before continuing dispatch. None of these checked paths writes an active MES
coordinate, runs a script, or restores a caller. Version 87 later excludes a
post-run application-lifecycle consumer, version 88 excludes the bounded
mode-`0x80` view/popup route, and version 89 excludes the bounded mode-`0x100`
popup-dismiss route. The remaining host-activation boundary is another
indirect in-loop/lifecycle consumer.
Version 53 also binds five unique public-context slot-`+0x44` caller shapes:
one call inside a three-context iteration and four calls in the `CBGSelect`
caller family. Each passes a caller stack-context pointer, and neither checked
caller extent directly references the active-string field. The public
zero-coordinate context route is therefore not the missing direct
command-`0x0E` consumer. It also
corrects the storage identity: raw manager displacement `+0x4B55C` plus the
primary `+0x64` virtual-base adjustment resolves to the direct
`CScript +0x4B558` buffer pointer, while direct `CScript +0x4B55C` is a font
pointer. The audit fixes the `0x3194`-byte allocation/initialization lifecycle
and all 22 literal direct references. Version 53 partitions those references
without overlap into four lifecycle, nine diagnostic-context, two native
destination-buffer, and seven control/flag uses. Five related native method
vtables are bound across fourteen checked slots, and no classified literal use
hands the target to a script runner. This does not exclude an indirect or
higher-level host consumer. RTTI identifies those adjusted tables as
`CAI5Doc`, `CCommon`, `CFunc`, `CScript`, and `CScriptManager` subobjects, so
the remaining search is one shared script/document ownership family rather
than five unrelated consumers. Its exact base arrays establish
`CAI5Doc -> CScriptManager -> CFunc/CCommon`, with both latter branches
converging on virtual `CScript`/`CThread` bases. The unique constructor path
allocates a `0x72C98`-byte `CAI5Doc`, publishes it at application member
`+0xE8`, and constructs its nested `CScript`, `CScriptManager`, `CFunc`, and
`CCommon` subobjects. That is ownership evidence, not an activation coordinate
or caller frame. It additionally fixes the state buffer's owner
backpointer at `+0x3190`, its initialization dispatch, and the checked
public-context `+0x1C` reload path. That path reads a serialized
`0x3000`-byte state image and invokes the owner callback to rebind
state-storage pointers. It then forwards the reloaded state pointer through
the same bounded receiver/notification/flag sequence, while writing no MES
coordinate, invoking no script runner, and restoring no caller. A remaining
activation route must therefore use a different escaped pointer or
higher-level host path rather than an unexamined direct reference to the
ambiguous old offset or this reload callback.
Version 26 also extends that semantic boundary with the shared character
stream's peek/consume/terminator contract; rendered output remains outside the
static audit.
Version 27 added a deliberately non-semantic native-write envelope for
`state_u16[18]` (`state base + 0x20A8`). It pins the two-call 0/1 writer,
the native record-dispatch cases 20 through 23 that store a presentation-helper
return, and
three independent writer examples. The record explicitly marks its writer set
as selected rather than exhaustive and keeps both routine-40 reachability and
the stored values' gameplay meaning unresolved.
Version 28 fixes the normal script-manager byte route around that envelope.
It pins virtual slots `+0x6C`, `+0x70`, `+0x60`, and `+0x74`, the byte-`0x12`
remap branch, the typed-record parser, both adjusted vtable thunks, and the
direct wrapper/caller chain to the existing record dispatcher. It reports
command-`0x12` ingress as confirmed while keeping selected-intro execution and
the stored result semantics unresolved.
Version 29 pins subcommand-8 selector 0 at `0x0042A519`, including its two
zero arguments, adjusted document vtable slot `+0x24`, Data loader
`0x0043DDA0`, archive collection index zero, and named-entry lookup call at
`0x0043DE48`. The matching original MES envelope supplies a safe `.AX` name
and `banked_i32[0][2]` as the second loader argument. The named Data-archive
load is confirmed. Version 30 follows that argument through state initializer
`0x00407C70` and the Data loader: bank-zero dword slot `state+0x215C` receives
the adjusted owner's `+0x94` pointer; raw entries are read directly there,
while compressed entries are read to scratch slot `state+0x2158` and decoded
there by AI5 LZ helper `0x00432890`. The argument is therefore an
engine-initialized destination-buffer pointer. AX dword semantics, placement,
and rendering remain unresolved.
Version 35 retains the later AX/MMO and shared-character-stream checks and
adds presentation-subcommand 11. It pins dispatcher call `0x004282A1`, adapter
`0x0042ABA0`, public-context slot `+0x38`, active consumer `0x0042AC30`, both
fallback consumers, surface lookup `0x00401030`, and opaque/RGB-key/fill pixel
helpers `0x004254D0`/`0x004255D0`/`0x00425B10`. The audit confirms inclusive
endpoint expansion and mode selection without claiming an active surface or
executing pixels.
Version 20 fixes the `CAI5Doc -> CScriptManager -> CCommon` owner chain, the
registry member at object `+0x18`/map `+0x1C`, its one-time sentinel
initialization, and its tree-clear/sentinel-release manager teardown path. It
also locks the executable's `Common/StartMes` default `start.mes` selection.
Version 21 locks the native `0x0D` presentation dispatcher, subcommand 8,
typed-record parser, public slot `+0x2C`, selector-2/selector-3 ARC load paths,
temporary stream installation, synchronous execution, and restoration of the
prior coordinate/context pair. The companion read-only
`tools/audit_mes_startup_bootstrap.py` schema
`kakyu_mes_startup_bootstrap_audit/v2` confirms `START.MES:0x014C` selector 2
targets `LIBLARY.LIB` and `START.MES:0x0165` selector 3 targets
`DEF_MAIN.MES`, in that order. Version 2 also verifies the selector-18 root
bootstrap to entry label `0x0008`, the sole terminal command-`0x0E` record
naming `OPEN.MES`, its existing archive target, and the tail return. It reports
only hashes and coordinates. These audits prove the bounded original startup
execution envelope; Content Core still does not pretend that an isolated
preview replayed or inherited it, or that the retained target name establishes
an activation coordinate.
Version 22 locks subcommand 4's adapter `0x00429370`, public-context slot
`+0x1C`, handler `0x004293A0`, selector-13 dispatch, and the bounded
`0x00429920..0x00429976` loop that maps letters `A..Z` to relative-offset
slots at `+0x2084` (or the `_A.._Z` dword table at `+0x20EC`). The checked loop
copies offsets only and does not establish bank contents. This evidence is
paired with command-`0x04` archive audit v2, whose `--focus-index 25` output
finds 23 strict-valid writes covering `state_u16[25]`, including DEF12's
dynamic bank-zero row alias. The tool sandbox still keeps logical banks
separate, so this audit revision documents the missing physical alias without
enabling speculative execution.
Version 23 corrects command `0x07` bank zero from an inline base to the pointer
stored at state `+0x2080`. It fixes native initializer `0x00407C70` and its
table reference `0x0047A7F0`: the pointer targets state `+0x20B8`, whose first
word is initialized to relative offset `0x24A0`. The companion read-only
`tools/audit_mes_calendar_rows.py` schema
`kakyu_mes_calendar_rows_audit/v1` cross-checks that layout against the
authoritative `START.MES` and `FLAGINI.MES` command-`0x06` table builders.
Both entries produce the same 12 rows at stride 32 with sentinel 15 after
month lengths `31/28/31/30/31/30/31/31/30/31/30/31`. This confirms the
static storage read by DEF12 without yet enabling the sandbox's physical
relative-address alias.
Version 24 promotes the shared-library contract into the repeatable executable
audit. It fixes command `0x1C` at wrapper `0x0041840B`, slot `+0x64`, handler
`0x0041A2A0`, and command `0x1D` at wrapper `0x00418420`, slot `+0x68`,
handler `0x0041A3D0` in all three manager vtables. The checked `0x1D` slices
parse the routine record, look up the registered context through
`0x0041A840`, save and replace manager coordinates `+0x4B590/+0x4B594`, call
the selected script at virtual slot `+0x10`, and restore both fields. They do
not clear the manager evaluator at `+0x4B564`. This bounds Content Core's
explicit shared-call frame; it does not authorize a library body whose own
path still reaches an unsupported command or native effect.
Version 19 adds the full command-`0x03`/`0x07`/`0x08` wrapper, three-vtable,
handler, and evaluator-call checks used by the EVENTD03 caller suffix while
retaining v18's command-`0x0F` zero-start/call/restore contract and public
context-call checks, including public method `0x0042B2C0` at slot `+0x44` in
three adjusted vtables.
That method installs an opaque caller-supplied context at coordinate zero,
calls it, and restores the prior pair, but its checked body performs no address-
table lookup and does not resolve a catalog fragment selector. It explicitly verifies that `0x02`, `0x0D`, and
`0x12` share wrapper `0x004181F2`, manager slot `+0x04`, and handler
`0x004187C0`. Run it directly with
`python tools/audit_ai5_mes_exe.py <AI5WIN.exe> --json`, or pass the launcher to
the standard headless suite with `--exe`; that suite now runs the native ARC
and MES audits plus the bounded Ogg/Voice ARC stream-route audit. When both
`--exe` and `--elfimage` are supplied, audio audit v7 also reads the available
`mes.arc` and optional `voice.arc`. The Voice ARC check binds the executable's
`e0820.ogg` literal to the case-folded archive entry and stream-checks its
Ogg/Vorbis identification metadata. The MES check validates the native
presentation-subcommand-7 selector-2 typed-record grammar across the archive.
A missing optional Voice ARC preserves the EXE/MES audit. These cross-checks
read original archives without extraction or mutation and report no machine
path or payload bytes.
Audio audit v7 classifies that literal route as selector `2` of the
original settings subsystem's three-way sample function `0x0041F200`. Selectors
`0` and `1` use `kokuhaku.wav` and `kse0006.wav`; the active settings-row
dispatcher at `0x0041DD22` reaches adjustment function `0x0041ED00`, whose two
change paths call the sample function at `0x0041EE71` and `0x0041F15A`. The
same subsystem references `IsVoice` and `AutoMesSpeed`. That literal remains a
settings-screen sample, while the separate MES event-voice route is bound by
the v7 presentation dispatcher, filename queue, `IsVoice` gate, named-stream
loader, Ogg consumer RTTI, and DirectSound Play dispatch. The static audit does
not observe host-device or physical speaker output.
The direct
configured-launcher run found the same
payload offset and launcher/runtime hashes recorded above. This is regression
evidence for command routing and the bounded handler mechanics, not proof of
complete MES execution or UI behavior.

`tools/audit_mes_definition_registry.py` performs the complementary read-only
archive audit. Schema `kakyu_mes_definition_registry_audit/v2` scans reachable
structural commands in every MES/LIB entry and separates command-`0x14`
manager-context registrations from command-`0x10` choice-definition bodies.
It accepts only literal forward context registrations with an in-bounds
instruction-boundary target, inventories literal command-`0x11` calls, and
reports noncanonical command-`0x10` record/target shapes without treating their
record values as context keys. It emits counts and source coordinates, not
payload bytes or dialogue, and does not execute registered bodies or infer
registration lifetime. The standard `--elfimage` headless batch runs this
audit against the user-owned `mes.arc`.

## ARC Writer Boundary

`KakyuArcWriter` exposes a conservative copy path and an explicit
resize-capable path:

- source and output must be different paths;
- an existing output is never overwritten;
- output is first written to a sibling temporary file, reopened, validated,
  checked again for a destination that appeared during the rebuild, then
  atomically renamed; a late destination is preserved and the verified
  temporary file is removed;
- a no-op build is a streaming byte-for-byte copy and must have the same
  SHA-256 as the source;
- `write_copy` retains the byte-identical no-op/equal-size patch contract. It
  copies the complete source and changes only selected equal-size payload
  bytes;
- `write_repacked_copy` permits size changes only after proving that the source
  is canonical: payloads begin immediately after the index, follow index order,
  have no gaps or overlaps, and end at EOF;
- a repack copies all 256-byte encoded name fields verbatim, rewrites only the
  encrypted size/offset words, and streams unchanged payloads in original entry
  order;
- total sizes and offsets must remain representable as unsigned 32-bit values;
- the temporary result is reopened, entry order/names/sizes/contiguous offsets
  are checked, every replacement is byte-compared, every unchanged entry is
  streamed and byte-compared, and opaque name fields are compared before
  publication;
- a noncanonical archive is rejected instead of guessing how gaps, overlaps,
  or trailing bytes should be preserved.

The byte-array APIs remain available for small generated payloads. The parallel
`write_copy_from_files` and `write_repacked_copy_from_files` APIs normalize
replacement paths to size/hash-bound descriptors, stream them in 1 MiB chunks,
rehash while writing, and compare the rebuilt entry back to the source file in
bounded chunks. A file that is missing, aliases the source ARC, changes size
before writing, or changes content while writing is rejected. Multi-file audio
exports therefore do not retain the combined replacement payloads in memory.

Content Core `0.142.0` adds `*_if_source_matches` variants for both byte-array
and file-backed copy/repack operations. A caller supplies the SHA-256 captured
when its source ARC session was opened. The writer reopens the source, rejects
an invalid or changed fingerprint before creating a temporary copy, and
rehashes the source again after output verification and before publication.
If the source changed while the copy was being built, the temporary output is
removed and no final file appears. These methods bind a new ARC copy to the
content snapshot the user inspected; the unbound methods remain for controlled
no-op corpus checks and compatibility callers. Audio ARC Editor, Image ARC
Editor, and MES Editor new-ARC exports all pass their open-time source
fingerprint through this API. A rejection preserves the pending authored
session so the user can reopen the changed source and decide whether to restage.

Content Core `0.143.0` adds a bound file-backed repack input: every replacement
path carries the SHA-256 selected by the validated overlay manifest. The writer
checks that fingerprint before creating output and again while streaming, so a
same-size payload change cannot be silently materialized into a new ARC copy.
This is the required bridge for exporting a validated overlay from a generic
ARC consumer; persisted ARC and overlay schemas are unchanged.
Audio and Image Editor also pass their pending-session cache paths through this
bound input, using the SHA already revalidated for each staged replacement.
Thus the handoff from session validation to writer streaming cannot accept a
different same-size cache payload.

Content Core `0.144.0` added the payload-free Event Catalog loader; Content Core
`0.163.0` upgrades its lifecycle records to
`kakyu_event_player_catalog/v2`. The first tracked revision lives at
`config/event_catalog/original_events_v1.json` and binds twelve existing
EVENTB/EVENTD controller routes to their caller, callee, status, reusable
blockers, and headless validators. The loader rejects unsafe paths, dialogue or
payload fields, invalid source hashes, duplicate/unsorted IDs, dangling choice
references, and unsupported complete-playback claims. It is shared metadata for
future catalog browsing; it does not bypass the Event Runner's source and
boundary checks.

**Catalog caller routes, Content Core `0.293.0` (2026-09-06).** (Historical:
since 2026-09-21, Core 0.356.0, the catalog is generated from the analysis
groups and carries no `caller_route` or `analysis_route`; the loader no
longer validates them and the builders below are deleted.)
`kakyu_event_player_catalog/v7`, seeded revision 22, carries an optional
`caller_route` object on an event. `bgm_then_handoff` covers EVENTB01/B02,
introduced in Core `0.289.0` with catalog v3/revision 17.
`completion_bgm_then_handoff` added EVENTD01/D02/D03/D14 in catalog
v4/revision 18 while preserving their completion-state guards. `direct_handoff`
adds EVENTB15 in v5. `caller_choice_projection` adds EVENTB14 in v6, and
`restore_followup` adds EVENTD08 in v7. All nine
obtain their caller specifications from this metadata. `kakyu_event_catalog_play_request/v4`,
`kakyu_event_catalog_terminal_contract/v1` and the browser projection retain
their contracts.

The two BGM kinds contain exactly these eleven fields:

| Field | Meaning |
|---|---|
| `kind` | `bgm_then_handoff` or `completion_bgm_then_handoff` |
| `return_terminal_id`, `bgm_terminal_id`, `handoff_terminal_id` | Explicit references to the event's three lifecycle records |
| `bgm_sha256` | SHA-256 of caller code `[resume_offset, bgm_boundary)` |
| `date_index`, `bgm_routes` | `state_u16` date slot and exact-date/default BGM selectors and WAV basenames |
| `handoff_end`, `handoff_sha256` | Physical suffix end and SHA-256 of `[bgm_boundary, handoff_end)` |
| `handoff_trace_commands` | Exact command sequence, ending at command `0x0E` |
| `state_writes` | Expected post-execution state values/diff, not preset seed writes |

`build_caller_route_specification(full_event_id)` combines those fields with
the source caller/callee identities and the referenced terminal coordinates.
The unconditional kind returns the existing 18-field `MesCallerRoute` input;
entry names and hashes, dispatch/resume, return, BGM boundary, handoff offset and target are
derived rather than copied into the new object. Each terminal must have the
matching kind, source owner, runtime status and confirmed evidence, and a
consistent physical resume. The unconditional kind requires empty terminal
state conditions. Return, BGM and handoff sequence values must increase.
The route requires a confirmed MES
command-`0x0F` zero-start call. Invalid/fractional coordinates, unsafe names,
bad hashes, unknown fields/kinds, duplicate exact dates or state keys, and
missing/multiple defaults are rejected. A default row's `date` is its replay
representative and must differ from every exact-date row; it matches dates
without an exact row. JSON numeric values are projected to integer execution
fields, including the nested BGM, trace and state arrays.

The completion kind uses the same eleven metadata fields. Each of its three
referenced terminals must carry exactly one identical condition:
`{storage: global_u8, bank: 0, index: N, operator: equals, value: 1}`.
The condition has exactly those five fields and integral numeric values.
The projection derives the nineteenth execution field,
`completion_state_index`, from `N`; it is not duplicated in `caller_route`.
An absent condition, a different stage's index, other storage/bank/operator,
or any value other than one is rejected. D01/D02/D03 now explicitly declare
their existing callee returns as sequence-10 `callee_return_only` terminals
with outcome `continue`; D14 already declared its return. The completion flag
is a continuation precondition, separate from the two caller handoff
postconditions `global_u8[286] = 1` and `banked_u16[0][242] = 12`.

The `direct_handoff` kind contains exactly seven fields: `kind`,
`return_terminal_id`, `handoff_terminal_id`, `handoff_end`, `handoff_sha256`,
`handoff_trace_commands` and `state_writes`. It binds two unconditional
terminals, preserving return as `continue` and handoff as `normal_completion`.
It requires the same confirmed nested-zero-start source, increasing stage
sequence and `dispatch < resume < handoff < handoff_end` coordinates.
Its suffix hash covers `[resume_offset, handoff_end)`. No BGM terminal, date
selection or completion-index field is permitted. The projection reconstructs
B15's existing 15-field specification, including `direct_handoff: true`.

The `caller_choice_projection` kind contains exactly seven fields:

| Field | Meaning |
|---|---|
| `kind` | `caller_choice_projection` |
| `return_terminal_ids` | Ordered, distinct callee return witnesses; each resumes the same caller |
| `choice_terminal_id` | Confirmed caller-owned `analysis_boundary` with `def_selection_boundary` status and unresolved outcome |
| `suffix_sha256` | SHA-256 of caller code `[resume_offset, choice_offset)` |
| `bgm_offset` | Caller routine-23 request coordinate |
| `definition_offsets` | Ordered caller DEF registrations between BGM and choice |
| `bgm_resources` | Distinct ASCII WAV names accepted by the stored-suffix probe |

All referenced terminals have empty state conditions and targets. Return
sequences precede the choice sequence; each return has the source caller's
physical resume, while the choice retains its own coordinate. The ordered
caller coordinates are `dispatch < resume < BGM < definitions < choice`.
The projection preserves B14's thirteen existing specification fields and adds
`caller_bgm_resources`, moving the old validator's accepted resource list into
data. Source and terminal identities are derived; no handoff or completion
postcondition is inferred from this distinct route kind.

`MesCallerRoute.validate_choice_projection()` shares direct validation's
structurally indexed dispatch check, then checks the exact suffix hash and
executes from the proven physical resume in a fresh isolated default sandbox.
Every executed trace row must match an instruction's source, end and command
under structural framing of its actual container region. This rejects jumps
into payload bytes, including intermediate writes before an otherwise aligned
BGM or choice. Region indexes are reused within the validation call.
It requires the declared routine-23 BGM record, exact DEF registration offsets
and the final routine-40 choice boundary. Its result schema is
`kakyu_mes_caller_choice_projection/v1`. The original catalog audit checks both
declared callee return records and emits a separate
`kakyu_event_catalog_caller_choice_projection_audit/v1` diagnostic. This proves
the stored caller suffix under the reported default state; it does not execute
the unresolved choice, validate every allowed BGM branch or transfer a cloned
callee result into the live sandbox. Event Player retains its callee-start and
archive/resolver provenance guards before calling the same shared validator.

The `restore_followup` kind contains exactly seven fields: `kind`,
`return_terminal_id`, `handoff_terminal_id`, `restore_entry`,
`restore_dispatch_offset`, `followup_offset` and `restore_prefix_sha256`.
Its source must be a confirmed nested zero-start call. It binds an unconditional
callee return and caller handoff, with increasing terminal sequence and
`dispatch < resume < restore_dispatch < followup < handoff` coordinates.
`restore_entry` names exactly one `mes.arc` required-entry binding; missing,
duplicate or conflicting bindings fail closed. The restore entry/hash and
terminal/source coordinates are derived into D08's existing fifteen-field
execution specification. The sixteenth field, `restore_prefix_sha256`, binds
caller bytes `[resume_offset, followup_offset)`, including the selector reset
and complete restore call. The added callee-return terminal has sequence zero,
before the existing sequence-10 caller dialogues and sequence-20 handoff.

`MesCallerRoute.validate_restore_followup()` shares the structural index helpers
to verify both exact command-`0x0F` envelopes, the followup instruction start
and the command-`0x0E` handoff target. Its fresh default sandbox probe must stop
at the restore dispatch with the declared physical resume. Every executed
record must match its structural source/end/command. A dispatch boundary has
runtime `ok: false` because the nested body is not executed; the validator
checks that exact status, target and coordinate rather than treating it as a
runtime completion. Its result is `kakyu_mes_caller_restore_followup/v1`.

The separate `kakyu_event_catalog_caller_restore_followup_audit/v1` diagnostic
records the prefix hash, both calls, the indexed callee return and handoff,
and the verified trace count. It does not claim callee or complete followup
reachability, restore-body execution or host execution. The player retains
its original archive/resolver checks, one-based choice guard, saved arguments
and expression stack, and state rollback. Its live restore/followup uses the
same catalog coordinates while retaining the existing D.MMO/background tool
presentation and all three source-bound followup dialogue paths.

`find_caller_route_specification(callee_entry)` is a case-insensitive lookup
that succeeds only when exactly one catalog event names that callee, even if
another matching event lacks route metadata. Unknown IDs, absent metadata and
ambiguous callees return an empty dictionary. Event Player uses this lookup for
all nine caller specifications, with no hardcoded route fallback. Other event
data and presentation adapters remain separate. Its three evidence-API methods
`catalog_caller_route_evidence(event_id)`,
`catalog_caller_handoff_evidence(event_id)` and
`catalog_direct_caller_evidence(event_id)` are the only per-event caller entry
points; adding a cataloged event needs no method, constant or arm in the player.
The handoff method starts at the route validation's returned `boundary_offset`,
which is the catalog's own `caller_postlude` terminal offset, rather than at a
constant repeating it. `catalog_source_contract_evidence(definition)` and
`confirmed_address_catalog(entry, sha256)` expose the generic address-catalog
source guard so a validator can prove it refuses a changed entry hash,
address-table count or declared caller as well as accept the original; the
positive field comparison alone cannot show a guard rejects anything. The existing source-entry checks and `MesCallerRoute.validate()`
still verify dispatch bytes, both slice hashes, representative BGM execution,
handoff trace and postconditions against the read-only source. The original
catalog validator applies the matching shared check to every cataloged caller
route. It also rechecks the callee hash and confirms that its declared return
is an aligned command-`0x00` record in the current analysis index, then executes
only that record to reproduce `script_return` without state changes. Complete
callee reachability and completion flag writes remain covered by the existing
event integration checks. An unresolved record elsewhere in an entry does not
invalidate a separately indexed return. This does not execute the outer host
after the handoff. Each of the seven handoff routes prints a
`kakyu_event_catalog_caller_route_audit/v2` diagnostic with its kind, intro and
return coordinates, selected state and final handoff. BGM routes retain their
representative dates; direct routes report the fresh handoff probe's initial
write-target values. It identifies
the completion flag as a continuation guard and distinguishes the one-record
return check from full-callee reachability and state-write evidence.

Content Core `0.295.0` adds `build_callee_source(event_id)` and
`find_callee_source(callee_entry)`, the callee half of the same `source`
block: the entry that holds an event, that entry's hash, and the coordinate
the event starts at. `find_callee_source` is case-insensitive and applies the
same uniqueness rule as `find_caller_route_specification`, so a callee entry
two events name resolves to neither. A callee with no `start_coordinate`,
which the schema permits for an `unresolved_route`, projects an empty
dictionary rather than a partial identity. Event Player reads every cataloged
event's callee identity from it instead of the twelve `EVENT*_ENTRY_SHA256`
and ten `EVENT*_EVENT_ANCHOR` constants it used to freeze in code; its public
`catalog_callee_source(event_id)` exposes the same projection. The ten
cataloged `CONFIRMED_PREVIEW_ANCHORS` entries and both
`CONFIRMED_ADDRESS_CATALOGS` entries declare `CATALOG_SOURCED_ENTRY` and carry
no hash or start offset of their own. All of these paths fail closed: with the
catalog unloaded there is no confirmed anchor, no address catalog and no
callee match — a frozen constant could not fail, but it also could not follow
a catalog revision. This adds no catalog datum and no schema change; v7 stays
at revision 22.

Content Core `0.296.0` adds `build_caller_source(event_id)` and
`find_caller_source(callee_entry)`, the caller half of the same `source` block:
which original entry dispatches an event, that entry's hash, the coordinate it
dispatches from, the coordinate it resumes at, and the dispatch command.
`find_caller_source` resolves by callee entry name, is case-insensitive, and
applies the same uniqueness rule as `find_callee_source`, so a callee entry two
events name resolves to neither. An event whose `source` names no caller at
all — which the schema permits for an `unresolved_route` or an `analysis_only`
route — projects an empty dictionary rather than a partial identity. Event
Player reads every cataloged event's caller identity from it instead of the
twelve `EVENT*_CALLER_ENTRY`, eight `EVENT*_CALLER_ENTRY_SHA256`, the shared
`AUDITED_12C_ENTRY_SHA256` and the dispatch and resume offsets it used to
freeze in code; its public `catalog_caller_source(event_id)` exposes the same
projection.

Sixteen further constants repeated the catalog's own `caller_handoff` terminal
rather than its `source` block — eight offsets and eight targets. They are gone
too: `_is_catalog_caller_handoff(result, event_id)` reads that terminal through
the caller-route specification's `handoff_offset` and `handoff_target`, and one
predicate now serves the eight per-event blocks that used to spell the same
eight conditions out. Both `CONFIRMED_ADDRESS_CATALOGS` entries take their
entire caller envelope — entry, hash, dispatch, resume and command — from the
same `CATALOG_SOURCED_ENTRY` resolution that already supplied their callee
hash.

Every one of these paths fails closed. With the catalog unloaded there is no
caller identity, no address catalog, no handoff boundary and no caller match.
The nine start validators that build a `required_entries` map keyed by the
caller entry name return an explicit unavailable-caller error before building
it, because a map keyed by an empty entry name is satisfied by anything — a
frozen constant could not fail, but neither could an absent one be noticed.
This adds no catalog datum and no schema change; v7 stays at revision 22.

Content Core `0.297.0` adds `find_source_entry(entry)`, the third part of the
same `source` block. It answers the archive identity of an entry the catalog
records as some event's required entry: which archive holds it and what it
hashes to. It is deliberately identity and not requirement — it says what an
entry is, never which events need it — because the player uses several of
these shared entries in events the catalog does not record them under, and a
per-event lookup would have asserted a dependency the catalog has not
measured. An entry two events record with different archives or hashes
resolves to neither, and a callee entry is not a required entry and answers
nothing here.

Event Player reads thirteen frozen hashes from it: the shared library
(`LIBLARY.LIB`, 32 read sites), the definition script (`DEF_MAIN.MES`), both
picture scripts (`B_PIC.MES`, `D_PIC.MES`), the standing and expression layers
(`B1.MMO`, `BAN.MMO`), the expression animation (`B.AX`) and the character BGM
(`MAHOKO.WAV`). `_is_catalog_source_entry(entry_sha256, entry)` carries the
comparison, and fails closed: an unloaded catalog leaves no expected hash, and
an absent expected hash matches nothing rather than matching an absent
document hash. Two entries in `CONFIRMED_PREVIEW_ANCHORS` cannot call a
function, being `const` data, so `DEF_MAIN.MES` declares `CATALOG_SOURCED_ENTRY`
as its source and `EVENTD08`'s prelude anchor declares it as its
`prelude_bgm_entry_sha256`; both are resolved when the anchors are handed out,
and an unresolvable name yields no anchor at all.

The entry *names* stay in code, and the measurement behind that is worth
recording: `MAHOKO.WAV` is spelled by four constants under four event
prefixes, `B_PIC.MES` by three under two, and `D_PIC.MES` by two. They are the
lookup keys rather than the looked-up data, and the catalog records those
entries under `EVENTB03` and `EVENTD05`/`D08`/`D14` only, so consolidating them
against the catalog would need it to record the other events' use of the same
files first. This adds no catalog datum and no schema change; v7 stays at
revision 22.

As of Core `0.293.1`, `MesCallerRoute.validate(bytecode, code_size,
specification, address_table_offsets)` applies that same structural boundary to
the BGM-then-handoff routes. It had decoded its dispatch at the catalog
coordinate since the B01/B02 unit, which cannot establish a command boundary
because payload bytes can decode as a dispatch-shaped envelope; the direct,
choice and restore routes had each been corrected and this one had not. Every
executed BGM-prefix and handoff record must now also preserve its container
region's indexed source, end and command, and the caller's source-derived
address table is forwarded to the runner so its framing and the check's agree.
An absent table keeps the previous runner behaviour, so a caller that supplies
none is unchanged. The result schema, catalog data and every recorded original
claim are unchanged; this is a guard the six existing routes already satisfied.

`MesCallerRoute.validate_direct(bytecode, code_size, specification,
address_table_offsets)` owns direct-route bytecode validation. It verifies the
exact dispatch envelope, suffix hash, decoded handoff target and physical end,
then probes the suffix in a fresh sandbox using the caller's address table.
As of Core `0.291.1`, the dispatch must first be an indexed instruction under
the analysis index's structural framing of its complete container region;
decoding at the catalog coordinate alone cannot establish a command boundary.
The caller's source-derived address table supplies the region limits (or the
whole bytecode when absent) and must be strictly increasing, without duplicates
or offsets outside the bytecode. A dispatch-shaped envelope inside a native
record or message payload is rejected. Opaque bytes before the dispatch in the
same region prevent attestation; an earlier separate region or a later opaque
tail does not invalidate an already indexed dispatch. The existing physical
resume check now compares against the end of that indexed instruction.
Its `kakyu_mes_direct_caller_route/v1` result reports caller/start/handoff/end,
target and expected writes. `direct_result_matches(result, before,
specification, state)` checks the exact trace and changed state keys/values
against the supplied snapshot, including snapshots with unrelated existing
state. Event Player retains archive/resolver provenance checks, the B15 callee
completion guards, zero preconditions for suffix writes, saved frame arguments
and expression stack, and rollback on a failed live execution. Both the player
and the original catalog audit use this shared direct validator.

Core `0.291.2` also audits every catalog terminal labelled confirmed with
`script_return` or `script_handoff_boundary`, including events without
`caller_route` metadata. Its owner must resolve unambiguously to a source
caller, callee or required-entry hash binding. A cached structural index must
contain the exact command-`0x00` return or command-`0x0E` handoff to the declared
target at that owner-relative coordinate. A matching byte inside another
record is insufficient. Each `kakyu_event_catalog_terminal_boundary_audit/v1`
diagnostic identifies source ownership and the indexed record, and explicitly
does not claim branch reachability, required-state verification or host
execution. The summary counts these terminal boundaries separately from caller
routes. Other terminal statuses retain their dedicated integration checks.
Catalog v5/revision 20 corrects B14's callee-owned handoff and separates its
two returning choices from the unresolved caller choice; its nested-call
execution model and partial-playback classification remain unchanged.
It also removes D05's payload-derived choice-3 return. That branch now retains
the framed dialogue continuation after its single audited native omission and
joins the same callee-owned handoff and completion-state condition as choices
1 and 2. D05's original nonzero entry activation remains unresolved, so its
analysis-only classification does not change.

Loading/validation accepts exactly v8. The explicit, in-memory
`migrate_document(legacy_document)` operation accepts v2 through v7, validates a
deep copy, changes only the schema version and preserves the original catalog revision and all event
data. It returns `{ok, from_schema, schema, document}` without changing the
input, the loaded catalog or a file. A v2 document carrying `caller_route` is
rejected; v3 accepts only its original unconditional `bgm_then_handoff`
metadata, v4 accepts the two BGM kinds, v5 also accepts `direct_handoff`, and v6
adds `caller_choice_projection`; v7 also accepts `restore_followup`. v2-v6 reject restore-followup
metadata before migration; v2-v5 also reject caller-choice metadata, and v2-v4
reject direct-route metadata. Migration does not infer missing return terminals
or new routes. Every legacy input rejects `analysis_route`. v1, current v8 and unknown
versions are unsupported migration inputs. Loaded records and
accessor results are detached from caller-owned dictionaries; failed loads or
validation clear the catalog and its lookup index.

**Bounded catalog analysis, Content Core `0.305.0` (2026-09-08).**
Catalog v8, revision 23, adds optional `analysis_route` with exactly four fields:
`kind: bounded_callee`, `caller_start_coordinate`, `caller_prefix_sha256` and
`native_presentation: omitted`. The hash binds caller code from that start
through the existing dispatch's physical resume. This profile requires a
confirmed command-0x0E zero-start activation, partial playback, explicit
original-branch presets, MES/LIB dependencies and one callee-owned root
terminal. Choices and caller postludes are outside this profile. Coordinates
and preset writes must be integral; duplicate writes are rejected.

The Event Player labels its catalog action **Analyze route** and shows the
bounded trace, messages and final state in Analysis view. A shared runner
rebuilds the complete catalog request, verifies original/effective source
identities and the caller prefix, then executes the callee and declared
dependencies with the shared route probe. Exact terminal status, owner, offset,
end, target and state assertions must match before replacing the visible
session. Unsupported or modified requests fail closed. Native effects and
caller execution are explicitly omitted; the original validator proves that
each preset is equivalent to carrying state from the qualified caller prefix.
No event-ID branch is added to the application. Catalog requests remain v4;
the analysis profile is read from the current validated catalog, not supplied
by request callers. Package v7 retains its bounded callee descriptor contract.
The first profile is [EVENTJ04](../mes/eventj04_route.md).

Verification for the first B01/B02 catalog unit: 255 assertions across the existing
catalog and caller-route scenes plus the new 171-check caller-route scene;
the full local batch passes 95/95 checks (1,288 Python tests, project parsing
and 93 Godot scenes). The focused original batch passes all four catalog
source/route, ordinary-play and B01/B02 integration checks. These preserve the
ten existing playable routes and both original caller sequences without
changing source archives. Reports are
`analysis/td04-b01-b02-local-validation.json` and
`analysis/td04-b01-b02-original-validation.json`.

The conditional-route unit passes 431 assertions across those same three
scenes (347 catalog caller-route, 73 catalog and 11 shared caller-route
checks). Four independent legacy specifications preserve all 19 typed
execution fields. Tests cover missing/zero/one completion flags at all three
stages, mismatched conditions, integer projection, copy isolation, renamed
synthetic events and lossless v2/v3 migration with forward metadata rejection.
Playback-package verification passes 76 checks over all twelve events,
matching the bytecode reference on segments, trace, message payloads, final
state and terminal. The new D01/D02/D03 return metadata is carried through
the unchanged package v3 contract. Package report:
`analysis/td04-completion-package-validation.json`.
The full local batch passes 95/95 checks (1,288 Python tests, project parsing
and 93 Godot scenes); the focused original batch passes 6/6 source/route,
ordinary-play, D01/D02/D03 and D14-containing fragment-catalog checks.
Source archives remain unchanged. Reports:
`analysis/td04-completion-local-validation.json` and
`analysis/td04-completion-original-validation.json`.

The B15 direct-route unit passes 569 assertions across the same three scenes:
412 caller-catalog, 73 catalog and 84 shared caller-route checks. These preserve
all seven legacy specifications, reject cross-kind metadata and forward
migration, and test direct dispatch/hash/trace/state changes, a handoff-shaped
record inside message payload, nonzero snapshots, unexpected changed keys and
caller address-table propagation. The complete local batch passes 95/95
(1,288 Python tests, project parsing and 93 Godot scenes). The focused original
batch passes 4/4: all seven catalog caller routes, ordinary Play for ten routes,
B15 integration and twelve-event package equivalence. Source archives remain
unchanged. Reports: `analysis/td04-b15-local-validation.json` and
`analysis/td04-b15-original-validation.json`.

All eight authoritative ARC files satisfy this canonical contiguous layout.
The resize path was additionally exercised against `se.arc` by expanding
`KSE0010.WAV` from 7,088 to 7,089 bytes in a temporary new archive; the result
reopened and verified while the source SHA-256 remained unchanged. On
2026-07-30, an isolated copy of the original engine then launched with that
rebuilt archive, created its child game window titled
`下級生 -オリジナル復刻版-`, and remained responsive until the test process tree
was stopped. This is evidence that the original engine accepts the rewritten
container index and reaches the title window.

On 2026-07-31, a second isolated test replaced all 87 WAV entries in `se.arc`
with the same 1.000-second, mono, 22,050 Hz, 16-bit PCM probe. This exercised a
multi-entry size-changing rebuild: 22,923,742 payload bytes became 3,843,486
bytes, and the verified archive SHA-256 was
`7706da687fe542b579854b13966f0e6533ac23ca7374828fbfb82de190195627`.
Music and voice were disabled in the isolated configuration while effects
remained enabled. The original engine's child process produced a zero baseline,
then a peak of `0.07115421` over a 1,091 ms active interval when the startup
`KSE0031.WAV` request ran. The original entry is 11.035 seconds, so the measured
approximately one-second signal demonstrates that the engine decoded and
played the replacement PCM payload from the rebuilt archive rather than the
original payload. The process remained responsive.

This validates the writer's multi-entry offset rewrite and original-engine PCM
WAV playback path. It does not certify arbitrary WAV parameters, Ogg playback,
or every replacement entry. The tool therefore does not automatically label
exports `original_engine_compatible`: that remains a per-payload validation
decision. Overlay remains the default authored save path. No writer API ever
modifies the opened source archive.

The Windows-only `test_original_engine_audio.ps1` automation repeats the
stronger single-entry form of this test. It copies the user-owned installation
to a unique temporary directory, replaces only `KSE0031.WAV`, disables music
and voice in the copied INI, measures the child process through Core Audio,
checks source hashes and archive metadata, stops only processes executing below
the temporary root, and removes the root in `finally`. Its first end-to-end run
produced verified archive SHA-256
`d5e2bf23a42f6476aa206b7ca10d124dfc6de61fe17d6929d13c15876b1f7385`,
a zero pre-session baseline, peak `0.1137618`, and a 1,092 ms active interval.
Two immediate repeats produced the same archive hash and peak with 1,079 ms and
1,076 ms active intervals. The source remained unchanged and temporary-data
cleanup completed in all three runs. After the file-backed streaming writer was
introduced, the same automation produced the identical rebuilt ARC hash, peak
`0.1137618`, and a 1,093 ms active interval. The source again remained
unchanged and temporary data was removed. This fourth run confirms that the
streaming input path reaches the same original-engine-playable bytes.

## Overlay Manifest Contract

`kakyu_content_overlay/v1` is the authored package contract. `manifest.json`
contains package-level `schema`, `editor_version`, and an array of replacements:

```json
{
  "schema": "kakyu_content_overlay/v1",
  "editor_version": "0.1.0",
  "replacements": [
    {
      "base_archive_sha256": "<sha256>",
      "original_entry_sha256": "<sha256>",
      "replacement_sha256": "<sha256>",
      "target_archive": "voice.arc",
      "target_entry": "D0044.OGG",
      "replacement_path": "replacements/voice.arc/<sha256>-D0044.OGG",
      "compatibility": "remake_only",
      "text_encoding": "not_applicable"
    }
  ]
}
```

`compatibility` is `remake_only`, `original_engine_unverified`, or
`original_engine_compatible`. The unverified value records a structurally
validated candidate whose original-engine execution has not passed its
independent manual gate; consumers must not promote it implicitly.
`text_encoding` is `utf8`, `cp932`, `utf8_and_cp932`, or `not_applicable`.
Archive, original-entry, and replacement hashes are mandatory, preventing an
overlay from silently targeting a different release or accepting a modified
payload. Replacement paths are normalized package-relative paths and may not
escape the package root. `KakyuOverlayPackage` publishes content-addressed
payloads and an atomically replaced manifest, then reopens and validates the
package. An interrupted update leaves either the old valid manifest or an
unreferenced content-addressed payload; it cannot silently retarget old data.
`stage_replacements` accepts a batch for one source ARC. It resolves canonical
entry names, validates every target and fingerprints every payload before any
file is created, publishes all content-addressed payloads, and replaces the
manifest exactly once. A rejected batch leaves the prior manifest
byte-identical. The single-entry API delegates to this batch contract.
`stage_replacements_from_files` applies the same transaction to path-backed
payloads: each file is size/hash-bound before publication, copied and rehashed
in 1 MiB chunks, and exposed by the manifest only after all payloads verify.

The v1 manifest also accepts an optional `projections` array. Its first
projection kind is `mes_text`, backed by a content-addressed
`projections/mes/<projection-sha256>-<entry>.json` file using
`kakyu_mes_text_overlay_entry/v1`. Each record binds the base archive, original
MES entry, target archive/entry, projection file, compatibility, and encoding
by SHA-256 or a safe identifier. Each UTF-8 edit binds a code-relative source
offset to the SHA-256 of the original message bytes. Staging re-parses the
authoritative entry and accepts only messages retained by strict structural
analysis; duplicate, stale, cache-only, or post-stop offsets fail before the
manifest changes. MES text projections are always `remake_only` and `utf8`.
They do not claim to be assembled MES bytecode. Binary replacement updates
preserve projection records, and both payload kinds share the same atomic
manifest publication and reopen-validation boundary. The shared loader returns
offset-indexed edits only after the manifest, projection payload, current base
ARC hash, and current MES entry hash all match; an absent target is reported as
an empty optional projection rather than synthesized text.

`stage_mes_text_projections` validates and encodes every targeted MES/LIB entry
before it creates any projection payload, publishes each content-addressed
file, and replaces the manifest once. A missing entry, stale raw-message hash,
duplicate canonical target, or invalid edit rejects the entire batch without a
new payload or manifest change. The single-entry staging API delegates to this
batch contract.

`stage_mes_utf8_overlay_plan` is the Phase 6 bridge for a validated
`kakyu_mes_utf8_overlay_plan/v1`. It accepts only the explicit
`replace_message_utf8_overlay`/`utf8`/`remake_only`/`do_not_assemble_mes`
combination, rechecks the active archive and entry hashes, and delegates the
single bound edit to the same projection transaction. It cannot publish an MES
binary or acquire original-engine compatibility by changing labels.

The v1 manifest also accepts an optional `definitions` array since 2026-09-19
(Core 0.347.0): one record per mod event definition
(`kakyu_mod_event_definition/v1`, `docs/spec/data/mod_event_definition.md`),
backed by a content-addressed `definitions/<sha256>-<definition id>.json`
file holding the document's exact bytes. A record carries `kind`
(`mod_event_definition`), `schema`, `definition_id`, `definition_kind`,
`mod_id`, `mod_revision`, `target_id` (an override's target, empty for a
new event), `definition_sha256`, `definition_path`, `contract_fingerprint`,
`cells_fingerprint`, `compatibility` (always `remake_only`) and
`text_encoding` (always `utf8`). Loading a manifest rechecks every record
against its file (hash, header, an override's target, no `text_ref` or
`raw_sha256` anywhere), refuses duplicate ids and a second `mod_id`.
`stage_mod_definitions` prepares the whole batch before creating any
payload, publishes each content-addressed file, replaces a record of the
same id in place and appends the rest, then replaces the manifest once;
`remove_mod_definition` removes only the manifest reference and keeps the
payload. The contract check itself is the workspace layer's
(`docs/spec/data/content_workspace.md`, "Mod Definitions").

Removing a MES text projection atomically removes only its manifest reference.
The content-addressed projection file is intentionally retained as an
unreferenced recovery artifact; routine editing never destructively deletes an
authored payload. Removing a target that is already absent is idempotent and
leaves the manifest byte-identical.

## Runtime Resolution

`KakyuContentResolver` provides one stable lookup operation keyed by archive
and entry. It resolves in this order:

1. a validated, base-hash-matching overlay replacement;
2. the configured user-owned original ARC through `KakyuArcReader`;
3. a `res://` fallback or placeholder declared by the caller.

An overlay target fails closed when its base archive or original entry hash
does not match the registered original. No gameplay loader should add another
`res://data` or `res://assets/original` hardcoding. Existing loaders have not
yet migrated to the resolver; this increment does not change Saturday slice
behavior.

`extract_resolved()` preserves the same priority and copies the selected
descriptor only to a new output path. Original entries delegate to the ARC
reader's streaming extractor. Overlay and fallback files use bounded chunks.
A fallback descriptor binds the source file's size and SHA-256 when it is
resolved; overlay descriptors retain their manifest hash binding. Extraction
checks that binding before copying, writes to a unique sibling temporary file,
closes and reopens it, verifies its size and SHA-256, and atomically renames it
only after rechecking that the requested destination is absent. The successful
result reports that verified SHA-256. Existing output, an unsafe chunk size, a
missing registered reader, a changed overlay or fallback, or a short read fails
closed without changing the destination and removes every incomplete temporary
file. Content Core `0.125.0` introduced the shared resolved-extraction API;
`0.130.0` adds atomic reopen-verified publication and fallback source binding.
`0.131.0` exposes a deep-copied snapshot of the resolver's single validated
overlay manifest so tools can bind displayed metadata to the exact active read
layer without loading the manifest a second time. Persisted schemas are
unchanged.
Content Core `0.132.0` adds an archive-level binding transaction for candidate
activation. It fingerprints one registered ARC once, validates every matching
replacement and original-entry hash as an all-or-nothing set, preserves the
records in manifest order, and returns descriptors keyed by canonical uppercase
entry name. A registered archive with no matching targets still returns its one
fingerprint with empty collections. Returned collections are deep copies and
are not an integrity cache: ordinary resolution continues to check the live
source ARC and entry fingerprints, and payload reads/extraction continue to
check replacement SHA-256.
Persisted ARC and overlay schema strings are unchanged.
Content Core `0.133.0` adds the final ArcWriter publication guard: after the
temporary rebuild has reopened and passed byte/hash/layout verification, the
writer checks the destination again immediately before the sibling rename. If
another publisher created that path during the rebuild, its file is preserved,
the temporary ARC is removed, and the write fails. Persisted schemas are
unchanged.
Content Core `0.134.0` bounds each MES text-cache JSON file to 16 MiB and
rechecks an entry file's configured SHA-256 over the exact bytes parsed at load
time. Cache mutation, truncation, or oversized input fails closed without
changing the MES text-cache schema.
Content Core `0.135.0` binds every OverlayPackage manifest update to the SHA-256
revision parsed at the start of that operation. A stale or newly appeared
manifest is preserved and the candidate temporary manifest is removed; the
published revision is reopened and compared before success. Overlay schema
`v1` is unchanged.

## Independent Apps

The final product scope and definitions of done for Content Core, ARC Browser,
MES Editor, Image and Animation ARC Editor, Audio ARC Editor, and the Launcher
are defined in [Content Suite Product Goals](content_suite_product_goals.md).
The descriptions below record the current implementation contract and do not
limit those final goals.

Each app is a separate main scene and later receives its own export preset.
The first runnable shells are:

- ARC Browser: open read-only ARC, list index metadata and fingerprint, filter
  entry names without case sensitivity, attach, Hot Reload, or clear an overlay
  package, display each entry's effective size and source, and stream-extract
  the resolved entry without overwrite. **Export overlay ARC...** materializes
  all targets from the active validated snapshot into a new ARC copy and
  portable provenance sidecar. Both the
  open source fingerprint and every content-addressed payload fingerprint are
  bound through Content Core `0.143.0`; changed input, source overwrite, and an
  existing output fail without publication. Its status distinguishes the visible
  row count from the complete index. Overlay rebuilds preserve the filter and a
  still-visible selection; a filter-hidden selection is cleared so extraction
  fails closed. It uses the shared resolver and contains no format-specific
  decoder. Since Core 0.331.0 (2026-09-17, WD-02) the entry list is
  multi-select: **Extract selected to folder...** extracts every selected
  visible row and **Extract archive...** the complete index regardless of the
  filter, both through `tools/content_suite/arc_batch_extraction.gd` into a
  chosen folder, one file per entry name: the list must be
  non-empty, safe and free of case-insensitive repeats, every entry must
  resolve, every destination must be absent before the first write, entries
  are stream-extracted in order through the resolver, and a failure removes
  every file that batch created and names the failing entry; the status
  reports the entry, overlay, original and byte counts. The extraction and overlay buttons moved to a second toolbar row so the window still fits the shared minimum desktop size. The headless
  `cli/extract_arc_entries.gd` runs the same batch on a listed set of
  entries or a whole archive, optionally under an overlay package. The
  single-entry save-file extraction is unchanged. Since Core 0.338.0
  (2026-09-17, WD-01) **Compare with ARC...** and **Compare with overlay**
  compare the open ARC's index and whole-entry hashes with another ARC
  (identical, changed, only on one side, order preserved or not) or with
  the loaded overlay (identical, changed, or an overlay replacement equal
  to the original), show the rows in a panel that lists differences only by
  default, and export the path-free `kakyu_arc_comparison/v1`
  ([contract](../data/arc_comparison.md)); `cli/compare_arcs.gd` compares
  two ARC files headlessly. Since Core 0.340.0 (2026-09-17, WD-03) **Stage raw
  replacement...** stages one file as the replacement of the one selected
  existing entry into the named workspace's overlay
  (`tools/content_suite/raw_replacement_staging.gd`): the file must be
  non-empty, at most 64 MiB and different from the original; an entry type
  the repository can check (MES/LIB container, WAV/OGG header, AX, A6, MMO)
  must pass its validator, any other type is staged as opaque bytes and
  labelled unvalidated; the record is always `remake_only`, the archive must
  be a project target archive, and nothing is added, removed, renamed or
  reordered.
- Audio ARC Editor shell: filter OGG/WAV entries, lazily validate a selected
  header, load full bytes only for preview, stream-extract without overwrite,
  and maintain a multi-entry replacement session without re-encoding. The
  session retains replacement paths, sizes, and hashes rather than audio
  payloads; validation reads at most a 64 KiB header and streams the file hash.
  Each file is rechecked immediately before save, then streamed without
  assembling the batch in memory. One action publishes the whole session as a `remake_only`
  overlay batch, or passes the whole session to one structurally verified new
  ARC rebuild. Ogg Vorbis identification metadata and PCM WAV chunks, channels,
  sample rates, and WAV bit depth are validated. Overlay activation uses one
  candidate resolver snapshot and uses the shared one-fingerprint archive
  binding transaction to check every record for the open archive against its
  original ARC and entry hashes before replacing the active read layer.
  Its fingerprint must still match the one captured when the editor opened the
  displayed index, so an externally replaced source path cannot mix snapshots.
  Since Core 0.335.0 (2026-09-17, ME-06) the entry list is multi-select:
  **Extract selected to folder...** and **Extract archive...** run the shared
  batch extractor over the effective audio (overlay, pending session file
  or original; per-source counts, no overwrite, rollback on failure), and
  **Export audio report...** writes the portable
  `kakyu_audio_metadata_report/v1` ([contract](../data/audio_metadata_report.md))
  for the selected rows or the whole archive: archive and overlay identity,
  the MES reference index summary, one row per entry with its source, size,
  hash, header-validated container/codec/channels/rate/depth/duration, the
  overlay record and the confirmed MES reference count, and a summary;
  path-free, fingerprinted, refused when the output exists.
- MES Editor shell: filter MES/LIB archive entries, validate the lossless
  container on selection, inspect address-table/code-relative ranges and the
  bootstrap prefix, and view strict read-only disassembly plus a bounded byte
  preview. A tabbed analysis view searches messages in the selected entry,
  lists structurally decoded code targets and confirmed condition fallthroughs,
  lists numeric state reads/writes without assigning symbolic meanings, and
  gives exact MMO/AX/voice metadata references a separate full-height subtab.
  Resource rows retain archive candidates and distinguish `strict_indexed`
  instructions from exact `bounded_envelope_scan` matches beyond a decoder
  stop; neither boundary assigns native playback or rendering semantics.
  The CFG tab renders a bounded reference graph for the selected address range:
  indexed targets are green, unresolved targets amber, and exact decoder stops
  red. Condition true/false and continuation edges are labeled confirmed;
  bootstrap/library-body skip targets remain explicitly structural.
  Indexed original messages are decoded and searched as Japanese through the
  shared CP932 codec. An optional archive/entry-hash-bound UTF-8 cache or
  authored overlay overrides matching records. Raw hex remains available only
  through `hex:` search and tooltips. A native double-byte row that fails strict
  CP932 remains a visible, read-only `native bytes` diagnostic instead of
  appearing as dialogue; authored projections cannot override that gate.
  Invalid expressions and unresolved boundaries stop visibly.
  MES payload loading uses the shared resolver, so a validated binary
  replacement is inspected through `overlay -> original ARC` without changing
  the source archive. Generated cache and authored text projections stay bound
  to the original entry hash, while each message's raw-byte hash prevents stale
  text from being applied over a changed binary message.
- Event Player shell: open either a standalone `mes.arc` or a user-owned
  ELFIMAGE content-set directory, resolve MES through overlay then original
  ARC, select an address-table or explicit code-relative intro, load isolated
  raw storage records, trace confirmed entry/text/condition/continuation
  behavior, show state diff, and stop on every unsupported opcode. The content
  set keeps image and audio ARC readers ready for lazy presentation lookup.
  Overlay manifests can be hot-reloaded. A matching authored MES text
  projection supplies UTF-8 text ahead of the generated hash-bound cache; each
  displayed record still checks its original raw-message hash. Overlay load
  and Hot Reload are transactional across the open content set: a separate
  resolver registers every available source ARC, rejects targets outside that
  session, batch-binds every binary-targeted archive to the fingerprint captured
  when its index was opened, parses all targeted MES/LIB replacements, validates
  every MES projection against the pinned MES/entry hashes, and preflights the
  selected entry. Only a completely
  valid candidate replaces the active resolver. A wrong-base media record,
  malformed MES replacement, changed projection, or manifest revision race
  leaves the previous document, library/startup context, trace, continuation,
  game-frame/audio preview, and isolated sandbox state active. No source ARC is
  reopened for writing. **Clear Overlay** builds a separate original-only
  resolver, rechecks every open source ARC against its session fingerprint, and
  parses the selected MES before swapping. A failed clear therefore preserves
  the same active overlay session; success reloads the selected entry through
  original ARC plus the configured generated text cache.
  The shell's final product direction is the complete event replacement player
  defined in [Event Player Product Goal](event_player.md). That scope includes
  authoritative originals and original-derived overlays or ARC copies produced
  by MES Editor, Image ARC Editor, Audio ARC Editor, and ARC Browser. Exact
  original evidence remains hash-bound; compatible edited media or MES must be
  identified by provenance and interface validation rather than mislabeled as
  the unchanged original.
  The default **Playback** view now keeps only the catalog and event-facing
  game-frame controls visible. **Analysis** restores MES entry/address tables,
  explicit coordinates, bounded-run and fragment actions, resource evidence,
  isolated state editing, trace/call/message/state-diff tables, and boundary
  status. The selector changes visibility only: both modes retain the same
  resolver, runner, sandbox, selected document, current result, and media
  session. A playable catalog row can start its recommended original branch in
  a fresh isolated sandbox and automatically cross confirmed internal
  continuations until the next dialogue, choice, or confirmed terminal.
- Image ARC Editor shell: browse and lazily decode MMO or paired DAT/PAL
  entries, preview their source dimensions, report explicitly padded MMO
  previews, export the decoded preview to a new PNG without overwriting, and
  stage same-dimension PNG replacements for MMO or paired DAT/PAL entries.
  Imports encode and decode again for pixel verification, then retain only
  hash-bound payload paths in a per-process `user://content/` cache. A DAT/PAL
  edit binds both archive entries to one logical session item. The
  full verified session can be saved to an overlay package or a new ARC copy;
  the original ARC remains open read-only. Overlay load and Hot Reload use a
  separate candidate resolver and one validated manifest snapshot. The active
  resolver, labels, and preview change together only after every replacement
  record for the open ARC passes its base-ARC and original-entry bindings. Its
  case-insensitive entry filter retains a selection only while that row remains
  visible. Hiding a selected row clears the decoded/structural preview and
  disables Import, Remove pending, and PNG Export; clearing the filter does not
  silently restore that former write target. Since Core 0.334.0 an AX entry
  is edited in place: the AX timeline editor below the inspector edits the
  selected cell's commands and any shared record through the AX writer,
  previews the result on the shared tool clock, and stages the written AX
  into the same session ("AX Read-Only Binding Table and Dword Boundary").

Current and planned app increments:

Content Core 0.152 provides the Event Catalog's versioned browser projection.
It supports composable character/date/place/event-type/support filters and
returns recommended preset, material-branch counts, compatibility, and blocker
summaries without embedding dialogue. Event Player exposes that projection in
a bounded desktop catalog window. Selecting a row shows its playback status,
compatibility, and limitations; **Select MES source in Analysis** is enabled
only when the cataloged callee actually exists in the open source ARC.

Content Core 0.153 adds the separate
`kakyu_event_catalog_play_request/v1` projection. It admits only confirmed,
nonblocking playable events with an original-branch preset and returns the
exact callee binding/start coordinate plus deep-copied sandbox writes. This is
selection metadata rather than execution authority: Event Player must still
check the open content set and effective MES identity before starting a fresh
isolated session. **Play catalog preset** performs those checks, applies the
preset, and drives only confirmed internal continuations. Unknown,
non-progressing, and over-limit boundaries stop fail-closed for Analysis.

Content Core 0.193 adds the versioned
`kakyu_event_catalog_preset_application/v1` pre-execution receipt. Event Player
issues it only after every normalized preset row matches the fresh isolated
sandbox and rejects contradictory duplicate writes. The receipt is retained
in the Play result even when original MES subsequently changes one of those
fields. The original catalog integration therefore proves EVENTB14 applied
`global_u8[642] = 0` before execution and independently verifies that its
confirmed zero-start prefix changed the live sandbox to `1` before the first
dialogue. Runtime state is no longer mistaken for an immutable preset copy.

The optional Content Suite Launcher is the format-neutral project/workspace
manager and independent-process launcher, not a sixth format implementation.
It keeps the optional specialist ARC separate from the user-owned ELFIMAGE
content set. **Create Workspace** fingerprints every present supported ARC,
publishes a revision-1 portable `project.json` plus empty `manifest.json`, and
reopens the result through `KakyuContentWorkspace`; **Open Workspace** validates
the same project/source/manifest generation transactionally. A failed open
retains the previous valid generation. Original ARCs remain read-only and the
launcher never interprets or writes archive payloads itself. It passes the
validated content-set/workspace pair through strict named arguments; every
child reopens the generation before activating its own resolver and preferred
specialist ARC. Since Core 0.336.0 (2026-09-17, WD-09) a launch may also carry
`--selection <path>`: a `kakyu_content_selection/v1` document
([contract](../data/content_selection.md)) bound to the workspace generation
that names one bound archive, one entry with its original hash and,
optionally, one original catalog event and preset; a launch carries either
a selection or a MES Editor Run request. `tools/content_suite/selection_handoff.gd`
writes the document under the workspace's `.handoff/` directory and resolves
the receiving app's executable and arguments. Event Player receives
original-reference selections only (the `mes.arc` entry opens in the
Analysis view; an attached catalog event is selected with its preset, not
played); the MES Editor and the ARC Browser select the entry. The Audio ARC
Editor is the first producer (ME-05): it lists the selected audio entry's
confirmed MES references and opens the referencing entry in Event Player,
attaching the catalog event when the catalog names exactly one event whose
callee is that entry. Since Core 0.339.0 (2026-09-17, WD-05) the ARC Browser's
**Open in editor...** hands its one selected entry to the editor that owns
the archive (MES Editor, Image and Animation ARC Editor, Audio ARC Editor),
and the two media editors receive selections like the MES Editor does. Since Core 0.332.0 (2026-09-17, WD-04) **Export report...**
writes the open workspace's portable provenance report
(`kakyu_content_provenance_report/v1`,
[contract](../data/provenance_report.md)): project identity and core range,
workspace generation hashes, the bound source archives, every replacement
and projection with its hashes, sizes and declared compatibility, the
compiled authoring proof linked to a replacement when its bundle reopens,
and a compatibility summary against the project objective - produced only
after every claim is re-verified against the workspace files, path-free,
fingerprinted, and refused when the output exists. The headless
`cli/export_provenance_report.gd` produces the same document. Since Core
0.337.0 (2026-09-17, WD-07) **Dashboard...** renders that verified statement in
the Launcher (`tools/content_suite/apps/workspace_dashboard_panel.gd`): the
project identity, revision and objective, the running Content Core against
the project's core range, the generation hashes, the bound source archives,
one row per replacement and projection with sizes, compatibility, encoding
and the linked authoring proof, the objective/declaration summary and the
verification counts; a payload that no longer verifies shows the builder's
error instead of a stale table, and **Refresh** and **Export report...** act
on the same rebuilt statement.

The Launcher's **Validation results and coverage...** panel starts the repository
headless suite in a separate background process. It offers local synthetic checks, an opt-in
selected ELFIMAGE directory, and an optional original executable for static
audits. The panel shows the run's frozen source selection, included and unrun
coverage with reasons, individual results, durations, and bounded failure
output. This repository suite does not validate modifications in the active
workspace or certify a mod package. Coverage groups may overlap.

Each run receives a UUID and a unique machine-local report under
`user://content_tools/validation/`. The launcher rejects a missing report,
wrong run or source identity, invalid fingerprint/schema/counts, or an exit
code inconsistent with the report. A run continues if the launcher closes;
**Open saved report...** can inspect it later. Saved reports are labeled
separately from a just-completed run. Development Python/runner availability
controls execution; saved reports remain readable without them. Historical
v2 reports are migrated for display as unsigned evidence with unknown coverage.

After the launcher or Event Player successfully accepts an ELFIMAGE content
set, the absolute directory is stored only in
`user://content_tools/path_history.cfg`. The next ELFIMAGE chooser in either
app starts at that directory, including after restarting the tool. Missing or
invalid stored directories are ignored. This machine-local convenience setting
is not authored content, is never written into the repository, and does not
change the read-only archive contract.
The last validated workspace directory is stored alongside that setting and is
used only as the next workspace chooser location; it is never copied into the
portable project document or overlay manifest.
The Launcher plus ARC Browser, MES Editor, Event Player, Image ARC Editor, and
Audio ARC Editor also share a `source_directory` setting in that file. A
successfully opened ARC updates it, and every source-ARC chooser starts there;
when no ARC directory has been recorded, the last valid ELFIMAGE root is used.
Output, replacement, cache, and overlay choosers do not reuse this value, so a
source selection cannot silently redirect authored or exported files.

1. **MES Editor:** entry/address-table, lossless container browsing, strict
   structural disassembly, selected-entry message search, code-target and
condition-fallthrough references, numeric state references, exact bounded
MMO/AX/voice resource references in full-height subtabs, stopped-boundary
diagnostics, a bounded partial CFG/reference graph, confirmed-flow cross-range
   expansion, display-only flow/structural/stop filters, selected-node focus,
   and bounded Back/Forward range navigation are implemented. The shared core
   now stages hash-bound, remake-only UTF-8 message projections while keeping
   original MES bytes read-only. The Messages tab loads a validated overlay,
   edits a keyboard-selected strict-indexed message, stages or reverts the
   current-entry session, saves it to an overlay directory, and immediately
   reopens the published projection. Pending text overrides overlay text, which
   overrides generated cache text. Cache-only records beyond a strict decoder
   stop remain read-only. Pending edits survive entry changes and block an ARC
   switch until saved or reverted. **Save all** merges each pending entry with
   any matching projection already present in the chosen package, then uses the
   shared batch API to publish every pending entry with one manifest update.
   **Detach entry** removes the selected saved projection only when that entry
   has no pending edits, immediately falls back to cache/raw presentation, and
   retains the detached payload for recovery.
   Message display priority is pending edit, authored overlay, generated cache,
   then decoded original CP932 Japanese, but only after the original bytes pass
   strict CP932. Rows that fail that gate display a neutral native-presentation
   diagnostic, keep raw hex in the tooltip and `hex:` search, and disable both
   UTF-8 staging and binary output. Selecting an unprojected valid message also
   seeds the edit field with that decoded CP932 text, so an equal-length binary
   edit can begin without first generating a cache.
   The shared `KakyuMesTextPatcher` now provides a deliberately narrow binary
   foundation for strictly indexed messages. It requires the current raw-byte
   hash, strict CP932 source and replacement text, an unchanged encoded byte
   length, the original NUL boundary, and a unique instruction offset. It
   patches a duplicate buffer, reparses it, requires the address table and
   strict decoder stop count to remain unchanged, and confirms every authored
   message decodes back exactly. The result is labeled
   `original_engine_unverified`; it may be published as a binary overlay or a
   distinct new ARC copy with matching provenance, but it is never labeled
   compatible and never overwrites the source ARC.
   The editor's selected-entry loader already consumes binary MES replacements
   through the shared resolver. Loading a different overlay is blocked while
   text edits are pending, and the resolved source is shown in the inspector.
   **Hot Reload** revalidates the currently loaded overlay manifest and then
   reopens the selected entry through the shared resolver. This reruns both the
   UTF-8 projection binding and binary MES analysis, so an externally changed
   projection or replacement becomes visible without reopening the source ARC.
   **Clear Overlay** detaches the overlay from the resolver and reopens the
   selected entry from the read-only original ARC; message presentation then
   falls back to the matching generated cache and decoded original CP932.
   Both actions fail before changing resolver or selection state whenever any
   entry has pending edits or the active message field contains an unstaged
   draft. A reload candidate must validate its manifest and source hashes,
   reopen every targeted MES payload, and parse the selected entry before it
   can replace the active resolver; a malformed or stale candidate leaves the
   prior overlay and analysis view intact. This preserves the common
   `overlay -> original ARC -> res:// fallback` lookup order and prevents an
   external reload or clear from discarding unsaved authored text. Neither
   action opens the original ARC for writing. The same unstaged-draft guard
   also blocks entry and ARC switches and restores the prior visible entry
   selection (clearing a filter that hid it when necessary), so typing cannot
   be discarded by navigation. Save, export, and projection detach actions are
   disabled until a live draft is staged or discarded; an older staged value
   can never silently replace newer text still in the field.
   **Save CP932...** applies the narrow patcher to every pending entry before
   publishing anything. A single invalid character, changed byte length, stale
   source hash, or structural reopen failure rejects the entire batch. Success
   publishes hash-bound binary entry replacements with `text_encoding: cp932`
   and `compatibility: remake_only`, clears the pending session, and immediately
   reopens the selected replacement through the resolver. The separate **Save
   all...** action remains the unrestricted remake-only UTF-8 projection path.
   The binary row evaluates the selected edit while the user types. It shows
   encoded/current byte counts for length mismatches, an eligible exact count,
   or a concise native-byte/encoding rejection; the full reason remains in its
   tooltip. This is advisory feedback only, and save/export always reruns the
   complete batch validation.
   Original-EXE cross-checking also excludes CP932 user-defined lead bytes
   `F0..F9`: the native MES dispatcher and ANSI font path recognize only
   `81..9F`, `E0..EF`, and `FA..FC` as double-byte leads. This additional gate
   is narrower than generic Windows CP932 round-trip support.
   Analysis v3 carries the EXE-matched stream probe and projection-match flag
   onto each strict-indexed message record. MES Editor marks mismatches in the
   message table and tooltip while preserving the remake-only UTF-8 overlay
   path. A pending mismatch disables both CP932 binary outputs, and each output
   handler repeats that gate even when invoked directly. For an originally
   matching message, live validation and final batch preparation also require
   every replacement character to remain one native double-byte pair. This
   prevents the equal-length writer from presenting a structurally valid but
   native-handler-divergent text projection as a binary test candidate.
   **Export ARC...** passes the same fully prepared equal-size entry batch to
   the conservative ARC writer. It refuses source overwrite and existing
   output, atomically publishes a new copy, reopens it, verifies replacements
   and unchanged entries, and leaves the edit session intact. The output is a
   test candidate only: its original-engine playback status remains unverified.
   The dense analysis shell uses an 11px tool-specific theme instead of the
   project default font size. Both the top toolbar and complete
   message-authoring row must report a combined minimum width no greater than
   their assigned desktop panel width; window resizing must reflow rather than
   magnify or clip these controls.
   An original-engine export remains unavailable until CP932 validation,
   relocation, continuation/branch repair, and lossless unknown-opcode
   preservation are complete. An experimental binary patch may be constrained
   to identical CP932 byte length.
2. **Event Player:** archive entry plus code-relative intro selection, generic
   isolated state records, opcode trace, state diff, unsupported-op stop,
   overlay hot reload, and hash-bound UTF-8 message preview are implemented.
   **Open ELFIMAGE...** validates the complete user-owned content set and uses
   its shared `mes.arc` reader; **Open mes.arc...** remains available for
   synthetic fixtures and partial analysis. The desktop shell keeps the shared
   640x400 game-frame preview visible above
   the Sandbox/Results tabs. Dialogue reached by the strict runner is decoded
   as original CP932 Japanese or resolved through cache/overlay priority and
   rendered in a game-shaped dialogue panel. Click or Space/arrow input can
   browse the reached messages only after explicit preview focus; Esc releases
   it. Entry, intro, and exact stop coordinates remain visible in the frame.
   Presentation is explicitly labeled unresolved when a confirmed resource
   request has not been reached instead of being inferred from unsupported
   opcodes. The Results area presents Trace,
   Messages, State Diff, and Summary tabs. The Sandbox tab provides direct
   numeric controls for the source-backed weekday `state_u16[4]`, legacy date
   code `state_u16[7]`, HHMM `state_u16[19]`, Mahoko affection
   `banked_u16[0][210]`, and Maki affection `banked_u16[0][212]`, plus an
   arbitrary raw `global_u8` flag editor. Applying
    either row updates the canonical JSON view, clears stale continuation/choice
    state, and never touches a gameplay save. The slot labels are bounded by
    direct original MES uses; the word-storage mechanics are independently
    cross-checked against embedded handlers `0x00418B20` and `0x00418F50`.
    EVENTB14's source-authentic recommended context is MMDD `1001`, HHMM
    `1900`, weekday zero, the matching banked date, Mahoko affection `81`, and
    the four exact caller eligibility flags. The bounded player now follows
    authoritative `B3.MMO` through `B_PIC.MES` routine 22 at
    `0x04AF/0x04B4`, then joins the high-affection `BAN.MMO`/`B.AX` route.
    The `0600` route remains a compatibility/debug preview only.
   Symbolic labels for other state, generic interactive choices, and additional
   opcode effects remain unresolved; raw numeric storage is retained meanwhile.
   At an otherwise unmatched routine-40 `def_selection_boundary`, the game
   frame now offers the bounded command-`0x10` DEF rows as **Explicit detached
   DEF preview** options. Selecting one runs only its hash-checked
   `body_offset..target_offset` range in a full duplicate of the current
   sandbox, with bounded native presentation/record effects explicitly
   omitted. `KakyuMesDetachedDefinitionPreview` resumes each confirmed dialogue
   trailer inside those bounds, preserves temporary argument/evaluator context,
   and collects messages in order until the body returns or reaches another
   explicit boundary. The duplicate, including physical preview aliases and
   PRNG state, is discarded afterward. Caller continuation and routine-40
   result mapping are disabled, and the frame plus Summary label the selection
   as tool input. Exact hash/coordinate-bound event projections still take
   precedence.
   The audited original `DEF_MAIN.MES` exposes **Start Isolated DEF Body** at
   `0x0203`. It stops at the first command-`0x12` typed-record boundary. When
   that list has the exact decoded end at `0x0216`, four expression records,
   and a consumed list terminator, **Continue (Omit Body Records)** advances
   once with the analysis-only bounded-record omission policy and reaches the
   body return. The controller requires the
   original entry hash, isolated-body session, start `0x0203`, stop `0x0208`,
   command `0x12`, and full probe metadata together. Ordinary Intro runs and
   shifted or mismatched boundaries remain fail-closed. This is isolated
   inspection: it does not simulate the routine-25 command-`0x11` caller frame
   or reproduce display/cursor effects.
   Trace effect rows include evaluated shared routine and DEF IDs, argument-slot
   assignments, command-`0x14` selectors, internal-vector selectors, and native
   command-`0x15` selection record counts so a
   boundary can be audited without reopening its raw operand tree.
   MES Editor disassembly similarly prints compact confirmed operands for DEF
   registration/invocation, shared-routine and internal-vector selectors,
   entry/source-line markers, and branch/continuation targets beside lossless
   raw bytes. Dynamic or unresolved records remain visibly nonliteral.
   Content Core `0.126.0` adds sandbox duplication for this detached analysis.
   Content Core `0.127.0` adds the shared
   `kakyu_mes_detached_definition_preview/v1` result contract and archive-wide
   read-only audit. Against authoritative `mes.arc`, all 133,459 address-table
   intros expose 797 routine-40 selection boundaries and 2,622 detached preview
   runs covering 2,614 unique bodies in 277 MES entries. All 2,622 expose a
   message; 2,621 reach their bounded script return. The remaining
   `F_DATE2.MES` entry 187, DEF 1 body `0x67BB..0x67F1`, stops at the nested DEF
   invocation at `0x67CD`; it is not auto-invoked. The audit reopens and
   fingerprints the archive after the run. The original executable audit v38
   independently rechecks the native typed-record ingress and selected
   slot-18 writer envelope, but still does not establish routine-40 choice or
   result semantics. No persisted cache/overlay schema changes.
   Content Core `0.128.0` advances the detached result to
   `kakyu_mes_detached_definition_preview/v2`. A caller may now supply the
   already hash-checked startup registry explicitly. The preview composes a
   reached command-`0x11` only when that registry contains its evaluated
   selector, restores the outer bounded body, records every registered call,
   and still discards the cloned sandbox. Without a matching explicit entry it
   stops at the original invocation boundary. The v2 full-corpus audit now
   completes all 2,622 previews, collects 2,623 messages, records one registered
   call, and reaches 2,622 script returns in 5,250 trace rows. The sole added
   composition is `F_DATE2.MES` entry 187, outer DEF 1: it invokes startup DEF
   99 at `0x67CD`, returns to `0x67D2`, exposes the second outer message, and
   reaches `0x67F0` with no state diff. Event Player labels the two-message body
   complete and reports startup-registry provenance outside the game frame;
   continuation into the routine-40 caller remains disabled. Original
   executable audit v38 rechecks the bounded registration/call/restore and
   native-result writer envelopes, not the choice that selected this detached
   body.
   Detached corpus audit v3 separates the runner's first-stage presentation
   list from its complete final group registry. All 797 audited routine-40
   boundaries carry at least group 0; 268 retain more than one observed group
   selector, including empty cleared groups. Only one all-zero-state boundary,
   `43C.MES` address entry 148, retains registered rows outside presented group
   0: nine rows across groups 4 and 6. Enumerating group order and then any
   remaining numeric selector restores the same complete 2,622-preview,
   2,614-unique-body, 2,623-message baseline without changing Event Player's
   six-row first-stage display or inferring second-stage input.
   Content Core `0.129.0` makes registered-body ownership a shared data
   contract. Startup context v2 stores `source_entry` on every registration
   and runtime-only body mapping; registered call v3 and recursive trace v4
   copy it to external trace rows, messages, and call records. Detached preview
   v3 and library trace v6 carry the same field unchanged. Event Player now
   reads that field directly and no longer derives a filename from the
   descriptive `source` label. The focused F_DATE2 validator requires all four
   nested DEF99 rows to identify `DEF_MAIN.MES`; corpus counts, bounded
   coordinates, sandbox results, and original-file fingerprints are unchanged.
   The versioned `kakyu_mes_event_runner_corpus_audit/v31` headless audit runs
   every MES address-table intro with a fresh all-zero sandbox state. It counts
   result statuses, unsupported command IDs, trace steps, and message
   reachability, then rechecks the source archive fingerprint. This is a
   representative prioritization baseline rather than execution coverage:
   alternate state branches, non-address-table callers, and user choice
   continuations require separate anchored validators.
   A command `0x01` native double-byte probe that consumes no character and
   therefore has no CP932 operand is a visible native presentation boundary.
   The runner must not index a missing operand or fabricate an empty message.
   The audit-v20 original-archive baseline covered 1,015 MES entries
   and 133,459 address-table intros with a 2,000-step limit. Before bounded
   command-`0x1B` support it stopped at 1,715 such commands. The corrected
   native record-buffer interpretation now executes 20,044 exact single-
   expression rows. Trace v63 corrects their metadata so each evaluated result
   is also the native internal group selector; the runner still records the
   clear without mutating gameplay sandbox state. The audit reached 131,804
   dialogue boundaries, 798 DEF selection boundaries, 42 script returns,
   30 invalid targets, 343 decode boundaries, three step limits, one reached
   native command-`0x15` selection boundary, 88 native presentation boundaries, 103 DEF
   invocation boundaries, 242 shared-routine boundaries, five nested-script
   dispatch boundaries, and no unsupported-opcode boundaries. It retained
   965,478 trace rows, reached messages from 131,891 intros, and rechecked the
   original archive fingerprint unchanged.
   The former singleton command `0x05` in test-only `_TEST.MES` now continues
   to the representative step limit; this does not establish that the test
   script terminates. These counts
   describe only the all-zero representative state.
   Audit v13 makes that queue reproducible: the command-`0x14` stops are
   `DEF_MAIN.MES` entry zero, intro `0x0008`, stop `0x008F`, literal `81`,
   target `0x01FC`; and `MACHI.INC.MES` entry zero, intro `0x0008`, stop
   `0x0170`, literal `0`, target `0x0178`. The three command-`0x09` stops are
   six-byte four-operand forms in `N_TEL.MES:0x00DF`, `P_TEL.MES:0x00E6`, and
   `Q_TEL.MES:0x00EB`. Singleton samples are `START.MES:0x00BB` (`0x02`),
   `_TEST.MES:0x00A5` (`0x05`), `06C.MES:0xA07E` (`0x0E`), and
   `F_DATE2.MES:0x67B2` (`0x10`). These summaries retain no dialogue or raw
   payload bytes and do not promote any operand to executable semantics.
   Audit v14 then follows 23 confirmed command-`0x14` transfers from those two
   entry-zero paths: 21 targets start another `0x14`, one starts `0x00`, and
   one starts `0x1B`; none is an address-table offset. It also executes two
   reached command-`0x16` argument-slot runs in one entry, starting at slots
   `1` and `17`, with one value each. The path formerly reported as a native
   selection now proceeds to shared routine `36`.
   Audit v15 originally separated command-`0x1B`'s evaluated record value from
   a supposed next-row-derived selector. EXE audit v44 corrects that historical
   interpretation: the parser-object `+4` adjustment makes the raw
   `+0x4B6D5` access the first evaluated result at parser-relative `+0x4B6D1`,
   so the record value is the selector. The 20,044 reached values cover
   `0..17` plus value `100` once at `MACHI.INC.MES:0x846A`. That path then reaches the actual command-`0x15`
   native selection boundary at `0x846F`, with one expression record.
   Audit v16 promotes the standalone `START.MES:0x00BB` command-`0x02` stop to
   the shared native presentation-boundary family. Its bounded probe consumes
   six bytes through NUL; rendering and cursor effects remain unexecuted.
   Audit v17 executes the native command-`0x09` u16-indexed temporary slot
   grammar at the three telephone sites listed above. Each path writes literal
   `2` to temporary slot `2` and advances to the existing shared-routine-`9`
   boundary, reducing the representative unsupported queue from six to three.
   Audit v18 executes the single-string command-`0x0E` insertion at
   `06C.MES:0xA07E`. That intro advances 33 additional instructions and reaches
   the existing DEF selection boundary at `0x96D4`, adding one retained message
   fragment and reducing the unsupported queue to two.
   Audit v19 accepts the structurally complete nested DEF body at
   `F_DATE2.MES:0x67B2`, hashes and projects it without executing its nested
   command `0x11`, and follows target `0x67F1` to a DEF selection boundary.
   This adds five trace rows and leaves only the test-only command `0x05` stop.
   Audit v20 executes that final command `0x05` through its EXE-confirmed
   expression-derived `global_u8` byte-write grammar. The all-zero test path
   writes zero to index zero, produces no state diff, and continues to the
   2,000-step limit. The representative audit now has no unsupported-opcode
   boundary, while decode, native-presentation, native-input, shared-routine,
   and step-limit boundaries intentionally remain fail-closed.
   Audit v21 does not change runner behavior or the representative counts. It
   separates the 343 decoder failures by stopped command byte and by a
   coordinate-normalized error reason, and emits at most 24 reproducible
   entry/intro/stop samples without raw payloads or dialogue. The complete
   original-archive pass groups them as command `0x05` (298), `0x08` (26),
   `0x07` (16), and one each at `0x04`, `0x06`, and `0x0A`. Of these, 341 end
   an operand expression with an empty stack, while the two singletons leave
   two or three values. These are decoder-shape diagnostics only; they do not
   establish additional command semantics.
   Audit v22 adds an execution-local persistent expression stack. Each
   address-table run starts with an empty stack; locally produced surplus
   values can be consumed by later empty fragments in the same run, while an
   empty fragment with no carry uses the native evaluator's confirmed zero
   fallback. It does not import or guess a caller's incoming stack. The full
   original-archive pass retained 968,230 trace rows, evaluated 41,820
   expression fragments in this model, executed 380 structural instructions,
   used 341 empty-stack zero fallbacks, and observed a maximum isolated depth
   of 62. The former 343 decode failures fell to zero. It reached 131,805
   dialogue, 798 DEF-selection, 103 DEF-invocation, 27 native-selection, 88
   native-presentation, 539 shared-routine, five nested-script-dispatch, 51
   script-return, 38 invalid-target, one invalid-write, and three step-limit
   boundaries. One fail-closed unsupported boundary remains: command `0x06`
   in `FLAGINI.MES` entry zero at code-relative `0x0121`. The run retained
   291,659 messages from 131,892 intros and rechecked the archive fingerprint
   unchanged. These remain all-zero, empty-incoming-stack prioritization
   figures rather than complete original execution coverage.
   Audit v23 implements the EXE-confirmed command-`0x06` banked-byte grammar.
   The former `FLAGINI.MES` entry-zero stop at `0x0121` now performs its
   isolated `banked_u8` write and continues. The full original-archive pass
   retained 969,803 trace rows and evaluated 43,750 expression fragments; it
   reports no decode errors and no unsupported opcode. Status totals are
   131,805 dialogue, 798 DEF-selection, 103 DEF-invocation, 27 native-
   selection, 88 native-presentation, 539 shared-routine, five nested-script-
   dispatch, 51 script-return, 38 invalid-target, two invalid-write, and three
   step-limit boundaries. Both invalid writes are the existing fail-closed
   command-`0x04` byte-index overflow policy, at `ENDING.MES:0x0099` and the
   newly reached `FLAGINI.MES:0x0672`; v23 prints their command, normalized
   reason, and reproducible coordinates. These deeper stops do not indicate a
   command-`0x06` failure or authorize native index wrapping.
   Audit v24 enables only the EXE-confirmed command-`0x04` 8-bit index wrap.
   The two former invalid-write paths at `ENDING.MES:0x0099` and
   `FLAGINI.MES:0x0672` now write index `255` and then index `0`; invalid-write
   boundaries fall to zero. The full pass retains 969,859 trace rows, evaluates
   43,778 expression fragments, and executes 386 structural instructions.
   `ENDING.MES` continues to an existing boundary; the deeper `FLAGINI.MES`
   path adds one shared-routine-`28` reach and then stops fail-closed at the
   separately unresolved internal command `0x1A` at `0x0721`. The representative
   totals therefore contain 540 shared-routine and one unsupported-opcode
   boundary while all other v23 status counts remain unchanged.
   Audit v25 follows operand-free commands `0x19`/`0x1A` as manager-only
   record push/pop effects without reconstructing their native strings. The
   `FLAGINI.MES:0x0721` pop adds one trace row and moves the sole unsupported
   boundary to the immediately following `0xFF` at `0x0722`; all status totals
   and message counts remain unchanged. The pass retains 969,860 trace rows,
   no decode errors, and no invalid writes.
   Audit v26 uses the shared decoder's existing EXE-matched native handler
   family for default high bytes. `FLAGINI.MES:0x0722` (`0xFF`) becomes a
   fail-closed single-byte presentation boundary with a four-byte probe through
   NUL. Native-presentation results rise from 88 to 89 and unsupported-opcode
   results fall to zero; trace rows, messages, and gameplay state are unchanged.
   Audit v27 is diagnostic-only. It groups every remaining invalid target by
   stopped command and target-minus-code-size, and emits bounded reproducible
   samples. All 38 are structural native-stream fallthrough shapes: eight stop
   at apparent command `0x0B` with target `0x02FF0102`, while 30 stop at
   apparent command `0x0C` with `0xFFxx02FF` targets. Every target is far beyond
   its MES code size. The audit does not reinterpret these byte patterns as
   executable jumps or consume them past the fail-closed boundary.
   Audit v28 applies that evidence at the preceding command `0x0D`. If its
   bounded native probe contains a non-empty payload beginning with apparent
   branch byte `0x0B` or `0x0C`, trace v37 returns a fail-closed native
   presentation boundary before the payload can become tool-side control flow.
   The complete original-archive pass retains 969,822 trace rows and 291,659
   messages. It reports 127 native-presentation boundaries in 107 entries and
   no invalid target, invalid write, decoder error, or unsupported opcode.
   The added 38 probes consume four bytes four times, six bytes 27 times, and
   nine bytes seven times. Dialogue (131,805), DEF selection (798), DEF
   invocation (103), native selection (27), nested dispatch (5), script return
   (51), shared routine (540), and step-limit (3) totals are unchanged. The
   source ARC fingerprint is rechecked after the pass; gameplay state and saves
   are never modified.
   Audit v12 retains the bounded command-`0x0F` summary after promoting those
   five stops to explicit read-only dispatch boundaries.
   All five reached sites are address-table entry zero, contain one nine-byte
   ASCII string record, and continue with command `0x1F`: `DENSHA.MES:0x00AA`,
   `EVENTM06.MES:0x00FF`, and `EVENTM09.MES:0x00FF` target `train.mes`;
   `EVENTF22.MES:0x0105` targets `f_pic.mes`; and `EVENTG01.MES:0x0350`
   targets `g_pic.mes`; all five names resolve through the authoritative ARC
   index. This is operand-shape and reachability evidence, not execution of the
   target script or proof of caller restoration.
   The audit also confirms the corrected command-`0x11` record-list boundary:
   all 103 reached sites are entry zero in distinct MES entries, resolve literal
   DEF selectors `11` (91) or `23` (12), and continue with command `0x1F` after
   the structured operand. The runner exposes that selector as a dedicated
   `definition_invoke_boundary`; native registered-body invocation remains
   unexecuted because its registration lifetime and caller frame are absent.
   Command-`0x1D` shared-routine boundaries are grouped by routine and most recent
   argument assignment. Of 239 stops in 236 entries, routine `28` accounts for
   216, followed by routine `33` (12), routine `1` (6), routine `32` (4), and
   routine `36` (1); 217 paths most recently assigned argument slot 1 to value
   1. This makes routine `28` the next library-interpreter priority without
   treating structural-only library rows as executable. Literal routine IDs
   are now reported as `shared_routine_boundary`; a body is never executed by
   this classification alone.
   The path in `FLAGINI.MES` previously labeled as a native selection is a
   command-`0x16` temporary argument-slot write followed by shared routine
   `36`. The corrected all-zero audit instead reaches one command-`0x15` input
   loop in `MACHI.INC.MES`, where it remains an explicit no-input-simulation
   boundary.
   The 88 native presentation boundaries occur in 80 entries. Forty are
   command `0x12` single-byte-family probes: four consume two bytes and 36
   consume eight before NUL. One command `0x02` probe consumes six bytes, and
   the other 47 are command `0x01` double-byte-family
   probes that consume zero characters and defer the following single-byte
   marker. Event Player displays the family and probe metadata plus the omitted
   native display/cursor effects without advancing the script or changing the
   sandbox.
   Native EXE cross-checking now
   confirms command `0x10` as DEF body registration/skip and command `0x11`
   as later selected-DEF invocation. Event-local option projection must remain
   context-bound until the intervening shared selection routine is reconstructed;
   Event Player must not treat every command `0x10` as a generic choice or
   synthesize a `state_u16[21]` write. It never writes a
   gameplay save. Authored MES text projections are loaded through the shared
   overlay core and participate in Hot Reload with priority over cache text.
   Hot Reload also reopens a binary MES replacement created by MES Editor.
   Cache and UTF-8 projection records whose raw-message hashes no longer match
   the replacement are skipped; changed bytes are decoded and labeled
   `overlay CP932`, while unchanged matching records may still use projections.
   In ELFIMAGE mode every opened ARC is also registered with the shared
   resolver. MMO, BGM, and voice reads therefore use the same verified
   `overlay -> original ARC` contract; the frame displays `overlay` or
   `original_arc` for the payload actually used. Binary overlay records must
   still match the current base-ARC and original-entry hashes, and the resolved
   replacement hash is rechecked at read time.
   When current trace v56 reaches the bounded outer-command-`0x0D`,
   presentation-subcommand-9 MMO filename record, Event Player lazily reads
   only that entry from the content set's
   `mmo.arc`, strictly decodes it, and displays its native pixels in the game
   frame. The EXE-audited one-argument native route loads the name into the
   state-selected active surface with origin defaults `(-1,-1)`. The tool's
   centered placement remains explicitly inspection-only because active-surface
   identity and later composition order are not yet reconstructed. Missing or
   malformed entries remain visible diagnostics and do not erase the MES trace.
   When the same trace reaches the constrained argument-slot-1 / routine-23
   BGM request, Event Player preferred-resolves the table filename in
   `bgm.arc`, validates its header with a bounded read, then lazily loads the
   complete PCM WAV only for playback. A repeated request for the already
   playing filename does not restart it. Standalone MES mode, missing entries,
   malformed WAV, and Godot decode failure remain visible diagnostics without
   erasing trace results or reading any source archive for writing.
   When the current trace reaches a bounded `voice_marker`, Event Player searches
   `voice.arc`, `tina1.arc`, then `tina2.arc`, validates and lazily reads the
   matched Ogg Vorbis payload, and plays it through a voice player separate
   from BGM. Multiple matching Tina banks remain visibly ambiguous and the
   first match is labeled as a tool-preview choice. Every voice status
   distinguishes the confirmed native queue/stream/DirectSound Play route from
   unobserved host-device output and labels Godot playback as a tool preview.
   Headless verification reads
   and validates full BGM and voice payloads but deliberately does not invoke
   Godot audio decoding or playback; interactive tool runs decode and play
   normally.
   The Address list places a small set of hash-bound `Confirmed` resource
   inspection anchors before ordinary MES address-table rows: six audited
   `D_PIC.MES` MMO markers, the bounded `EVENTB01.MES` and `EVENTB02.MES` callee/caller routes,
   the `EVENTB14.MES` original-caller-to-read-only-choice route,
   the bounded `EVENTB15.MES` callee/caller route,
   the `EVENTD01.MES`, `EVENTD02.MES`, and `EVENTD03.MES` bounded Maki events, and the
   `EVENTD08.MES` coordinate-zero dialogue-to-choice route. A hash
   mismatch hides all anchors. The EVENTD03 anchor begins at the original
   command-`0x0F` callee coordinate `0x0000`, dispatches entry zero at
   `0x0008`, and reaches the `D03.MMO` marker at `0x01A4` in original control-
   flow order through the same overlay-aware resolver. It no longer preloads
   that image as detached context. The frame labels the decoded MMO as a tool
   preview because active-surface identity, placement, and composition remain
   unresolved.
   After a confirmed-start validation succeeds, a new session clears any
   retained background, foreground, AX, BGM, and voice presentation before it
   prepares that anchor and executes its first segment. A failed validation
   leaves the current presentation untouched. This prevents a prior time-band
   frame or audio request from appearing as evidence in a restarted route.
   Selecting the exact original `EVENTB01.MES` enables **Start Event
   Dialogue** at `0x0000` only after binding its `13C.MES:0x0F93..0x0FA3`
   caller envelope, original-ARC MES/library sources, X/Y MMO fingerprints,
   expected Z absence, and MAHOKO/B0796/B0797 audio fingerprints. The tool crosses
   exact shared routine boundaries `0x00E6`, `0x0269`, and `0x0279`, and grants
   one bounded omission for the paired command-`0x12` lists at
   `0x0105..0x011B`. It then presents the time-selected MMO plus validated
   `MAHOKO.WAV` and `B0796.OGG` before dialogue `0x031D`. (Dialogue boundary
   coordinates in this section are the pre-0.316.0 `02`-byte coordinates; since
   2026-09-13 the runtime reports each three bytes earlier, at the wait call -
   `format_and_method.md`, "Command `0x0D` is one system call", Coordinates.) It continues through
   six more exact dialogue boundaries, routines 28/32/25, the exact
   `0x05F1..0x0609` three-record omission, and routine 28 before return
   `0x06A0`. **Preview Caller BGM** follows the original `13C.MES`
   date-selected prefix `0x0FA3..0x1017`; **Continue Caller Handoff** applies
   only `global_u8[286] = 1` and stops at `MACHI.MES:0x1022` without running
   the native host consumer.
   The matching `EVENTB02.MES` start applies the same fail-closed policy to the
   exact `13C.MES:0x10CD..0x10DD` caller and coordinate-zero prefix. It presents
   the selected B02 X/Y background, the AN/AX animation pair,
   `MAHOKO.WAV`, and B0798..B0800 before eight exact dialogues. Exact AX cell
   `(0,0)` divides the X source into three 104x112 frames at destination
   `(216,48)`, or the Y source into three 128x112 frames at destination
   `(216,56)`. The keyed overlay follows the original thirteen-frame dispatch
   order and counted loops. Playback uses a labeled 60 Hz tool clock because
   the original host's wall-clock cadence is not yet confirmed.
   B02Z/B02ZAN/B02Z.AX remain explicit original-entry absence diagnostics, and
   native wall-clock cadence remains unresolved. After the final dialogue the tool
   permits only routines 28/32/25, the exact `0x081A..0x0822` record omission,
   and routine 28 before callee return `0x08C9`. **Preview Caller BGM** then
   resumes the original `13C.MES` at `0x10DD`, runs only the hash-bound
   date-selected BGM prefix through `0x1151`, and changes no sandbox state.
   **Continue Caller Handoff** applies the confirmed `global_u8[286] = 1`
   write and stops at the `MACHI.MES` marker `0x115C`; the native host consumer
   after that marker remains unresolved and is not executed.
   Selecting the exact original `EVENTB14.MES` enables a deliberately bounded
   coordinate-zero start only after binding its `44M.MES:0xC915..0xC925`
   caller envelope, the preceding `44M:0xC8F8..0xC915` picture update, the
   `13C.MES` normal-conversation setup, original `B_PIC.MES`/library sources,
   zero-through-choice slice, and original media entries. The tool reconstructs
   the sandbox-HHMM-selected `44M_1/2/3.MMO` location projection, caller-owned
   date-qualified standing art (`B3.MMO` on the original 19:00 route and
   `B.MMO` on the retained daytime compatibility route), a 96x80
   `BAN.MMO`/`B.AX` face overlay at `(264,72)`, and `MAHOKO.WAV`. The three 44M
   frames and both standing layers are original hash-bound 640x400 MMO
   entries; their association with the confirmed `TIME_C` bands is labeled as
   a location-family projection because the EVENTB14 callee itself does not
   load them. Seven exact dialogue continuations with B0829..B0832 end at
   routine 40 `0x04CF`, where three hash-bound DEF bodies are displayed as
   read-only options. An explicit option action can clone the current sandbox,
   project `state_u16[21] = 1/2/3`, and display the corresponding stored outcome
   dialogue route. Confirmation clears the outer choice projection, so dialogue
   clicks, arrows, Enter, and number keys cannot switch to another stored branch.
   A different outcome requires returning to the outer choice. **Continue Outcome
   Preview** advances through 6, 17, or 12
   exact dialogue boundaries. Values 1 and 3 execute only their exact audited
   routine-27/25/21 and bounded command-`0x12` suffixes in the clone, then
   confirm callee returns `0x08FA` and `0x291E`. With a valid legacy MMDD,
   value 2 retains the START-derived relative calendar layout in the clone,
   returns through DEF17, DEF11/DEF12, shared routines 3/26/32, omits the exact
   four- and three-record native spans, and crosses routines 28/21/28. The
   ordinary-date route validates and plays original `IDOU.WAV` from the exact
   `0x0B01/0x0B07` selector/request pair. During the following two stored
   dialogues the footer labels a forced accompanying move, keeps the dormitory
   caller frame, and leaves map/destination/choice input locked; normal dialogue
   advance is the only available navigation. The first `B14.MMO` park dialogue
   marks movement completion. The
   resulting event frame uses original `B14.MMO` as its 640x400 background and
   `B14AN.MMO` plus `B14.AX` as a four-frame 120x128 overlay at `(400,8)`.
	Eleven additional dialogues then offer **Show Nested Choice**, which reaches
	and displays the exact three-row routine-40 boundary `0x133F`. Those rows are
	read-only original definitions. Selecting one explicitly clones the nested
	choice state, projects `state_u16[21] = 1/2/3`, and replays 8, 6, or 13
	stored dialogue boundaries from the physical routine end `0x1344`. The nested
	choice is likewise locked after confirmation through B_PIC return and the
	post-picture dialogue.
	**Continue Nested Outcome** advances only that cloned branch. **Finish Nested
	Outcome** then follows the exact shared routine-28/DEF80/routine-27/25/21/
	DEF11/routine-32/28 suffix and reaches the stored `B_PIC.MES` dispatch
	`0x1FC0`. **Run B_PIC Return** executes the audited coordinate-zero
	expression route in the clone, restores the HHMM-selected `18M_1/2/3.MMO`
	children's-park location background, keys the date-qualified `B3.MMO` (or
	compatibility `B.MMO`), `BAN.MMO`, and `B.AX` over it, and resumes five
	stored post-event dialogues. `B14.MMO` is the preceding event CG, not the
	post-return location background; it is cleared before dialogues one through
	three. Neither EVENTB14 nor the nested B_PIC route loads a 44M background at
	this point, so the pre-move dormitory frame is not reconstructed.
	The routine-21 boundary between the third and final two dialogues contains a
	confirmed full-frame mode-0 copy from logical surface 1 to the destination
	selected by `banked_u16[0][23]`. After that exact boundary, the last two
	dialogues use a source-qualified tool projection from the independently
	confirmed MACHI HHMM table, effective `MACHI.MPC` layout, and
	`MACHIN_1/2/3.DAT/.PAL` tile atlas. The shared MPC compositor applies each
	cell's opaque base and index-zero-transparent overlay before taking the
	source-bound 640x400 camera crop; the raw atlas is never presented as a map.
	The 19:00 catalog preset selects `MACHIN_3`, uses MACHI event/preset 4 at
	camera cell `(80,32)`, and draws original CHARA frame 1 for actor cell
	`(95,40)` at viewport pixel `(240,128)`. Exact original and edited effective
	inputs both use the shared ARC-backed MPC/DAT/PAL compositor; no extracted
	or local full-map PNG participates in resolution. The tool
	labels that the native host
	action which populated surface 1 remains unresolved; it does not attribute
	the frame to the later MACHI handoff.
	**Finish EVENTB14** stops at `MACHI.MES` handoff `0x230C`; that handoff
	target is not executed. The tool labels this as an explicit
	projection because the one-based nested routine-40 result mapping is
	confirmed but its native UI/cadence, dynamic list, and effects are not
	executed. Date `0000` fails closed before the calendar suffix.
   Each step reconstructs a fresh clone from `0x04D4`; the projection is
   discarded after presentation and never updates the live sandbox. The callee
   itself reaches no MMO/BGM request before the outer choice. Native animation
   cadence, native routine-40 UI/effects, value-2 branches after
	`0x133F`, source-surface ownership for the confirmed routine-21 full-frame
	copy, other native presentation effects omitted within the cloned suffixes,
	and execution after the `MACHI.MES` handoff remain unresolved.
   Selecting the exact original `EVENTB15.MES` enables a confirmed
   start at coordinate zero after binding `11M.MES:0x347B..0x348B`, the
   original MES/library sources, B15 X/Y fingerprints, expected Z absence, and
   `MAHOKO.WAV`. The route permits only routine 28 at `0x00F6`, the exact
   paired command-`0x12` omission at `0x0115..0x012B`, routine 21 at `0x02E0`,
   and routine 28 at `0x02F0` before first dialogue `0x035D`. The embedded
   frame shows the selected 640x400 X/Y MMO, or an explicit missing-B15Z
   diagnostic, and reports no voice because none is reached in the confirmed
   route. Nine exact dialogue continuations then cross routines 28/32/25, the
   exact `0x0721..0x0739` record omission, and routine 28 before callee return
   `0x0778`. **Continue Caller Handoff** resumes `11M.MES` directly at
   `0x348B`, applies only the audited `banked_u16[0][242] = 11` and
   `global_u8[286] = 1` sandbox writes, and stops at `MACHI.MES:0x34AE`.
   There is no caller BGM request in this suffix, and the native consumer is
   not executed. Selecting the exact original `EVENTB03.MES` instead displays
   a non-selectable **Deferred** row bound to the exact
   `01M.MES:0x788F..0x789F` command-`0x0E` envelope and changes the disabled
   control to **Start Event (Deferred)**. That command stores the target name,
   but it is not promoted to a confirmed start because its native host
   activation and callee coordinate remain unresolved. EXE audit v56 binds the
   active-string copy, public-context receiver implementations, and all known
   flag-bit-8 consumers. Those paths only perform bounded notification and
   stream/input/window gating; they have no MES coordinate write, synchronous
   script call, or caller restoration. The remaining blocker is a higher-level
   host consumer of the active string. The state buffer's `+0x3190` owner
   backpointer is not that consumer: its only direct callback-helper caller is
   a serialized-state reload case that rebinds state-storage pointers and
   replays bounded notification, but writes no MES coordinate, invokes no
   script runner, and restores no caller.
   Hash/source/envelope
   mismatch removes the special diagnostic rather than weakening the guard.
   Selecting the exact original `EVENTD01.MES` enables **Start Event
   Dialogue** at the hash-bound callee coordinate `0x0000`, after rechecking the
   `12C.MES:0x07CD..0x07DD` command-`0x0F` envelope, decoded target/end,
   EXE-confirmed zero-coordinate entry/caller restore, archive/entry hashes,
   and original-ARC resolver source. The
   tool follows the original bootstrap to routine 28, records the two adjacent
   command-`0x12` lists as exact native-effect omissions, and continues only
   from their verified physical ends. With explicit sandbox `HHMM=0600`, the
   embedded frame reaches the original `D01X.MMO` 640x400 background and its
   independent state write. The initial routine 28 normalizes
   `global_u8[4000]` to zero, so the branch at `0x0234` bypasses the exact
   mode-0 surface envelope `0x023F..0x0264` and continues through routines 21
   and 28. The tool still validates that stored envelope as a source guard but
   does not report or execute it as part of the normalized route. It then
   reaches the 120x168 `D01XAN.MMO` foreground and the `D01X.AX` load/binding
   before selector 33, routine 23, `MAKI.WAV`, and first dialogue `0x043E`.
   Start validation binds both the daytime X-family and evening Y-family base
   entry fingerprints and confirms that the referenced Z-family entries are
   absent from their original indexes. A `HHMM=1600` regression separately
   requires the original 640x400 `D01Y.MMO`, 112x192 `D01YAN.MMO`, and
   `D01Y.AX` path without substituting X- or Z-family media. Native
   AX placement, surface ownership, and composition remain unresolved; decoded
   foreground placement is explicitly an overlay-aware tool preview, not a
   reproduction of the original renderer. A fresh/default night value instead
   reaches the stored `D01Z` branch. Its MMO/foreground resources are absent
   from all original ARC indexes, so the frame retains a missing-original-
   resource diagnostic rather than substituting a daytime image. Any failure
   in the zero-start chain disables the confirmed route instead of falling back
   to the old `0x03E6` shortcut. Six explicit dialogue continuations then reach
   three decoded original DEF rows at `0x07AB`.
   When their complete ID/source/target tuple matches, the focused frame accepts
   the same pointer and keyboard controls as EVENTD08, writes the one-based
   choice only to isolated `state_u16[21]`, and resumes at `0x07B0`. Choices
   1/2/3 traverse 7/9/7 additional dialogue boundaries and converge on the
   hash-bound `0x1114` script return with `global_u8[749] = 1`. The final
   boundary at `0x1045` labels itself **FINAL DIALOGUE** before the user
   advances; that advance displays an explicit EVENTD01 completion screen and
   confirmed `12C.MES:0x07DD` caller resume. **Preview Caller BGM** then runs
   only the hash-bound `0x07DD..0x0851` date-selected prefix without a state
   change. **Continue Caller Handoff** applies the exact two caller sandbox
   writes and stops at the confirmed `MACHI.MES` marker `0x086A`, whose host
   consumer is not executed. The game frame changes from callee completion to
   caller BGM preview and finally to explicit EVENTD01-plus-caller completion.
   Generic routine-40 input remains unresolved; this path is an
   EVENTD01-specific sandbox projection.
   Selecting `EVENTD02.MES` enables **Start Event Dialogue** only after binding
   the original `mes.arc`, `EVENTD02.MES`, `12C.MES`, and `LIBLARY.LIB` hashes
   and the exact `12C.MES:0x098D..0x099D` command-`0x0F` caller envelope. That
   envelope names the callee and physical resume but has no coordinate operand;
   configured-original executable audit v38 separately establishes that the
   handler saves the caller coordinate, starts the callee at zero, and restores
   the caller on return. The one-click route therefore begins at
   `EVENTD02.MES:0x0000`, not the old `0x03E6` shortcut. It crosses routine 28
   at `0x00E6`, omits only the two complete command-`0x12` lists at
   `0x0105..0x011B`, follows the normalized branch through routines 21 and 28
   at `0x0269` and `0x0279`, then reaches the time-selected foreground/AX
   records. On `HHMM=0600`, the frame uses the original 640x400 `D01X.MMO`,
   120x168 `D01XAN.MMO`, and `D01X.AX` metadata before selector 33 / routine 23
   at `0x03E6/0x03EC`, `MAKI.WAV`, and first dialogue `0x0456`. An automated
   `HHMM=1600` path binds `D01Y.MMO`, `D01YAN.MMO`, and `D01Y.AX`; fresh
   `HHMM=0000` instead retains the expected missing-original diagnostics for
   absent `D01Z.MMO`, `D01ZAN.MMO`, and `D01Z.AX` and may continue without
   substituting daytime media. Native AX placement/composition remains
   unresolved. The normalized prefix route bypasses stored surface envelope
   `0x023F..0x0264`; this is distinct from the later EVENTD02 surface paths at
   `0x0C9B..0x0CC0` and `0x132C..0x1351`. The full-session guard binds those
   later paths to original `D02X.MMO` SHA-256
   `b9852c0b70dc0cb3cd2004367659117d17d76ab3f5fdbc68d551418345ce4039`
   and `D02Y.MMO` SHA-256
   `173682b430708ad41e4de4fa5efd9fd60a594a266ce0b605d4e6c0c5c103be74`
   and separately requires `D02Z.MMO` to remain absent.
   Original-content validation completes before the tool clears or replaces
   the current frame, foreground, AX metadata, BGM, or voice. Any shifted
   routine/native boundary, source/hash, coordinate, media-presence, or media-
   absence mismatch disables the start while preserving the prior presentation.
   Original ARCs remain read-only, and overlay presentation cannot weaken the
   base-source checks.
   Explicit continuation exposes 17 dialogue boundaries and nine distinct
   validated voice markers. On default sandbox `HHMM=0000`, bounded library
   continuation follows routine 27, routine 25, the separately audited
   registered DEF26 body, and routine 21; the routine 27 and 25 bodies need not
   emit dialogue. Continuing after the seventeenth boundary reaches command
   `0x0D` at `0x0BAD` with three retained message fragments. Its first native-
   stream payload byte is `0x0C`, not a MES continuation command. The game
   frame keeps the original final message visible, but its footer and desktop
   status both say **EVENTD02 PAUSED / EVENT NOT COMPLETE**. Only the exact hash-bound
   stream probe enables **Continue (Omit Native FX)** at post-NUL coordinate
   `0x0BB4`; this is an explicit tool omission, not simulated native rendering.
   (Since Core 0.316.0, 2026-09-13, that payload is `System.function[12](30)`,
   an omitted call the route runs past: no pause, a seventh suffix dialogue at
   `0x0BBC`, then routine 28 at `0x0BE0`.)
   The resumed route traverses four routine-28 boundaries, plus newly exposed
   routine-21 boundaries at `0x0CC5` and `0x1356`, and 23 additional dialogue
   boundaries, for 40 total and ordered voice markers `D0957.OGG` through
   `D0976.OGG`. The two routine-21 calls follow exact mode-0 surface envelopes
   `0x0C9B..0x0CC0` and `0x132C..0x1351`; Event Player reports their decoded
   surface operations while omitting native pixels. The final dialogue at
   `0x1811` is labeled before its
   `0x1815` advance reaches script return `0x18C6` and
   `global_u8[750] = 1`. The resulting completion screen names
   `12C.MES:0x099D`. **Preview Caller BGM** then runs only the hash-bound
   `0x099D..0x0A11` date-selected prefix, requiring `1224 -> X_MAS.WAV`,
   `1301 -> SHOGATU.WAV`, and default `-> IDOU.WAV` with no state change.
   **Continue Caller Handoff** applies only `global_u8[286] = 1` and
   `banked_u16[0][242] = 12`, then stops at the exact `MACHI.MES` marker
   `0x0A2A`. The game frame reports EVENTD02-plus-caller completion while the
   unresolved host consumer remains unexecuted. A separate `HHMM=0600` replay
   bypasses DEF26 and reaches the later stored post-event `D01XAN.MMO`
   presentation before the same completion return. Neither that later record
   nor the coordinate-zero foreground preview is attributed to a simulated
   native blit.
   Selecting `EVENTD05.MES` enables a hash-bound **Start Event Dialogue** at
   `0x03F0` after validating its `01M.MES:0x9E52..0x9E62` command-`0x0E`
   handoff marker, selector-33/routine-23 BGM prefix, `D_PIC.MES` dispatch,
   choice coordinates, and terminal `MACHI.MES` marker. Sandbox HHMM selects
   the stored `D05X/D05Y/D05Z.MMO` pre-anchor frame family. Twelve dialogue
   boundaries and routines `28/27/25+DEF26/21/32/28` lead through the exact
   `D_PIC.MES:0x00CC` `D.MMO` standing preview to three decoded options at
   `0x0B17`. Keyboard or pointer selection writes only isolated
   `state_u16[21]` and resumes at `0x0B1C`. Choices 1 and 2 cross their
   branch-specific dialogue, the exact bounded command-`0x12` presentation at
   `0x1494` with its 10-byte probe ending at `0x149F`, and the common suffix
   before reaching `global_u8[753] = 1` and
   `MACHI.MES` handoff marker `0x173B`; the completion screen explicitly says
   that the host consumer was not executed. Choice 3 omits the exact
   command-`0x0D` stream at `0x12AC`, then recognizes outer presentation
   control `0x1301` and the nested subcommand-7 `D0994.OGG` voice record at
   `0x1302` without a second omission. The native skip policy ends with the
   audited span; subsequent name/text records remain framed and choice 3
   joins the common suffix, completion flag and `0x173B` handoff. The old
   `0x1380` early return was a payload interpretation defect corrected in
   Core `0.291.2`. All image composition, BGM, dialogue, choices, voice previews, and
   terminal state remain inside the tool sandbox.
   These EVENTD05 native continuations require the original entry hash,
   confirmed event session, exact command ID/coordinate, and full probe end;
   they are not supplied by a generic command-`0x12` fallback.
   Selecting hash-bound `EVENTD06.MES` or `EVENTD14.MES` changes the Address
   list into a read-only catalog: entry zero is **Catalog setup**, and every
   remaining address-table entry is a numbered **Fragment**. A dedicated
   **Preview Fragment** action, or double-clicking a fragment, starts a fresh
   isolated run at that exact original coordinate and renders any reached
   dialogue and resolved media inside the 640x400 frame. Catalog identity,
   caller validation, and stop diagnostics remain outside the game frame.
   The tool requires the authoritative target and caller hashes, exact
   command-`0x0E`/`0x0F` caller envelope, original-ARC resolver source, and a
   command-`0x17` entry label matching every address-table index. It never
   concatenates nonzero fragments or infers their native host order.

   EVENTD14 additionally exposes **Start Confirmed Event**. Configured-original
   executable audit v34 retains v28's confirmation that the `12C.MES` command-`0x0F` caller starts
   the target at coordinate zero; the exact command-`0x14` bootstrap transfers
   to entry zero `0x0008`. The hash-bound controller follows that continuous
   path through routine 28 at `0x014D`, the exact command-`0x12` typed-record
   list `0x016C..0x0177`, a second routine-28 boundary at `0x0288`, and the
   registered DEF-21 call `0x032E..0x0333`. DEF 21 resolves only through the
   audited runtime registry to `DEF_MAIN.MES:0x10C4..0x1102`. Fourteen original
   dialogue boundaries then lead to the exact three-option DEF boundary at
   `0x0942`. The tool enables keyboard/pointer selection, writes only isolated
   `state_u16[21]`, preserves evaluator carry, and resumes at `0x0947`.
   The choice boundary has 25 state records. Each explicit choice now continues
   through only its hash-bound DEF, shared-library, typed-record, and
   `D_PIC.MES` boundaries to common script return `0x256D`. Choices 1, 2, and 3
   reach 22, 20, and 10 post-choice dialogue boundaries and finish with 45, 46,
   and 45 sandbox records. Their D_PIC dispatches are
   `0x0ED4..0x0EE1`, `0x1963..0x1970`, and `0x21CA..0x21D7`; choice 2 alone
   crosses the six-record list `0x13E1..0x13F9`. At the exact return, Event
   Player shows **Event complete** and the confirmed `12C.MES` caller resume
   `0x1C33`, but only when the common completion write `global_u8[763] = 1` is
   present. **Preview Caller BGM** runs the exact hash-bound
   `12C.MES:0x1C33..0x1CA7` prefix. Sandbox dates `1224`, `1301`, and all other
   values select `X_MAS.WAV`, `SHOGATU.WAV`, and the explicit `IDOU.WAV`
   default, respectively, without a state change. **Continue Caller Handoff**
   then runs only `0x1CA7..0x1CCD`, applies the confirmed isolated writes
   `global_u8[286] = 1` and `banked_u16[0][242] = 12`, and stops at the
   `MACHI.MES` marker at `0x1CC0`. The order of separate nonzero fragments,
   native media placement, pre-event BGM inheritance, and the final host
   consumer remain unresolved/unexecuted.

   EVENTD06 remains a conservative source-table analysis with **Start Event**
   disabled. **Preview Setup** starts at entry zero `0x0008`, reaches routine
   28 at `0x00E6` with 11 records, resumes at `0x00EB`, omits only the exact
   command-`0x12` records `0x0105..0x0110`, and continues through the corrected
   MMO boundary. The `D06Z.MMO` record `0x021F..0x022D` is immediately followed
   by an independent command-`0x07` write at `0x022D` that stores
   `banked_u16[0][1]=7`; it is not an MMO suffix. The fresh sandbox route then
   reaches routines 21/28, four dialogue boundaries, routines 27/25, the
   audited DEF26 continuation, routine 21, seven more dialogue boundaries, and
   stops fail-closed at native presentation boundary `0x0B52` with 26 isolated
   state records. (Since Core 0.316.0, 2026-09-13, that boundary is
   `System.function[12](30)`, an omitted call the setup runs past: the setup
   reaches one more dialogue at `0x0B5F` and ends at the extension terminal,
   routine 21 at `0x0C0E`, with no separate **Continue (Omit Setup FX)**
   step.) Only at that exact entry/hash/session boundary, **Continue
   (Omit Setup FX)** grants `native_stream_policy=skip_bounded` for the
   six-byte command-`0x0D` payload and consumed NUL through `0x0B59`. That
   single run collects one further original message ending at `0x0B7F` and
   stops at routine 28 `0x0B83` (resume `0x0B88`), without an intermediate
   dialogue stop. After that routine, the bounded suffix retains
   its state writes, resolves `D07.MMO` from marker `0x0BA3` inside
   `0x0BA2..0x0BAF`, executes the separate following write
   `0x0BAF..0x0BB6`, and records the surface operation `0x0BB6..0x0BD9`
   without native pixels. The fresh-zero branch reads `global_u8[4000] == 0`
   and stops at routine 21 `0x0C0E`, whose stored resume is `0x0C13`.
   Routine 28 normally initializes that flag to zero; a separate isolated
   probe from its stored caller resume `0x0B88` with value `1` follows the
   alternate surface record `0x0BE4..0x0C09` and stops at routine 28
   `0x0C1E`, whose stored resume is `0x0C23`. The controller offers no
   continuation from either terminal routine in this bounded unit. Its screen
   and tooltip keep **host activation unresolved** because executable audit
   v53 retains the proof that the
   `10C.MES` command-`0x0E` handler copies an active string, performs bounded
   public-context notification, and sets a presentation flag whose complete
   checked lifecycle never changes the MES code coordinate, calls the script
   runner, or restores a caller. It also
   independently confirms the NUL-consuming command-
   `0x0D` stream plus subcommand-9 MMO and subcommand-11 surface handlers, but
   does not prove which host layer invokes the catalog.
   This is a sandbox-only setup-derived route, not proof that the native host
   selected an event fragment. Both tools leave gameplay saves untouched.
   Exact state counts, boundary coordinates, typed-record spans, terminal coordinates, DEF mapping,
   choice signature, and source `mes.arc` hash are regression-checked.
   For a verified catalog, the **Bytes / first stop** column runs
   each nonzero row once in a fresh sandbox and shows a compact `N msg`,
   `N DEF`, `native FX`, or return summary. Its tooltip retains only the stop
   kind and message/DEF/state-change counts; it does not duplicate original
   dialogue or promote that first stop to a complete route. **Prev row** and
   **Next row** controls directly below the Address list move through adjacent
   rows of the same displayed kind—verified fragments or ordinary address
   rows—and immediately preview the selected row. They never cross a Catalog
   setup row.
   Their tooltips and status text explicitly say this is source-table order,
   not a confirmed native event order. A fragment return is labeled **FRAGMENT END**
   or **Fragment preview ended**, never **Event complete**. Keeping these
   controls in the source pane also preserves the shared 1024x640 minimum tool
   layout and the full embedded game frame.
   A separate **Content stops** row exposes **Prev hit** and **Next hit**. It
   lazily scans rows of the same displayed kind until the shared runner reports
   at least one message, at least one DEF, or an exact
   `native_presentation_boundary`; empty returns, state-only rows, and
   failure-only stops are skipped. Scanned rows reuse the same disposable-sandbox summary
   cache and update their visible first-stop cells without storing dialogue or
   changing the active sandbox. After a hit is chosen, its ordinary isolated
   preview runs normally. A click inspects at most 16 rows on the UI thread. If
   no hit appears in that bounded batch, selection moves to the final inspected
   row and the status asks the user to click the same button again; this keeps a
   long or no-hit MES search incremental. The action remains an analysis search
   through displayed source-table order, not an inferred original event sequence.
   For a non-catalog MES entry, selecting an ordinary address-table row enables
   **Preview Row #xxxx** and double-clicking the row invokes the same action.
   The tool runs only that displayed code-relative row in the isolated sandbox;
   it does not call it an event start or infer the native host selector.
   **Prev row**/**Next row** traverse only adjacent ordinary rows in displayed
   table order. The game-frame header and desktop status retain the selected row
   number. On first selection, the tool runs a fresh temporary
   sandbox only far enough to populate that row's **Bytes / first stop** cell
   and tooltip with message/DEF/state-change counts; no dialogue text is cached
   and the active sandbox remains byte-for-byte unchanged. The original F_DATE2
   integration validator requires displayed row `#0187` to show `3 DEF`, moves
   through **Next row** to `#0188`, returns through **Prev hit** to the known
   DEF row `#0187`, and only then reaches its detached options. The screen
   workflow therefore no longer depends on manually typing `0x6768`. This UI
   classification adds no opcode meaning: it consumes existing runner results,
   while the authoritative entry hash and configured-original executable audit
   v37 retain the underlying bounded MES/dispatcher evidence.
   Source-row analysis always keeps these options detached, even when the
   stopped bytecode also matches the reusable routine-40 result-bridge
   contract. A row preview is an isolated inspection coordinate rather than a
   confirmed gameplay caller; it therefore cannot write slot 21 or resume the
   inferred consumer. Dedicated event routes and ordinary non-row playback may
   still opt into the exact source-bound bridge.
   Selecting `EVENTD03.MES` also enables **Start Event Dialogue**. It selects
   hash-bound coordinate `0x0000`, validates entry-zero bootstrap, stops at
   routine 28, and offers **Continue (Omit Native Records)** only for the two
   adjacent three-record command-`0x12` lists at `0x0105..0x011B`. The resumed
   original path reaches `D03.MMO`, the independent `banked_u16[0][1] = 7`
   write, the surface envelope, the `global_u8[4000] == 0` default branch,
   routines 21/28, selector 33 at `0x022E`, and routine 23 at `0x0234`. It then
   starts the resolved `MAKI.WAV` preview and reaches the three-row first
   dialogue at `0x0284` without requiring a manually entered offset. The
   three pre-dialogue library stops are restricted to their exact routine,
   boundary, and resume tuples. Initial routine 28 also normalizes a seeded
   `global_u8[4000] = 1` to `0`; a shifted tuple cannot fall through to the
   generic shared-routine continuation. The original `D03.MMO` base entry hash
   is required, while a loaded overlay may still win presentation resolution.
   The BGM play/stop control is enabled only after interactive Godot decoding succeeds;
   headless validation labels the complete payload as validated without
   claiming that audio was played. `EVENTD08.MES` exposes **Start Event
   Dialogue** from its native coordinate-zero entry. That anchor also rechecks
   original `D_PIC.MES` and
   its selector-33/routine-23 prefix at `0x009A..0x00A0`, then validates and
   loads inherited `MAKI.WAV` before presenting the first dialogue. Interactive
   runs play it through the existing BGM channel; headless runs report only
   full payload validation. The track remains loaded through the later 12C
   caller follow-up. Entries and hashes without a confirmed event anchor keep
   the one-click action disabled.
   EVENTD08 first advances nine dialogue boundaries at `0x013F`, `0x01A4`,
   `0x0240`, `0x02A9`, `0x0315`, `0x052B`, `0x059D`, `0x05E4`, and
   `0x0648`. They expose 17 original message fragments and voice markers
   `D1028.OGG` through `D1032.OGG`. Between the two dialogue groups, the
   controller follows routines 28/21/28 and offers **Continue (Omit Native
   Records)** only at the two adjacent three-record command-`0x12` lists
   `0x03BC..0x03D2`. That action sets only
   `native_record_policy=omit_bounded`; it does not grant
   `native_stream_policy=skip_bounded`.
   The same reached path discovers `D08.MMO` naturally at `0x045B..0x0467`
   rather than preloading it as detached context. Its filename NUL at `0x0465`
   and argument-list NUL at `0x0466` remain separate from command `0x07` at
   `0x0467`. The frame decodes the image without claiming its unresolved
   active-surface identity, placement, or composition. The route then follows
   the three exact DEF skip targets to routine `40`.
   Results and the game frame show the decoded option bodies. Only when the
   entry hash, three DEF IDs/offsets/targets, routine-`40` boundary `0x0735`, and
   physical resume `0x073A` match the audited route, the focused game frame
   accepts Up/Down plus Enter, number keys `1..3`, or a pointer click. The tool
   writes the one-based selection to isolated `state_u16[21]`, resumes original
   bytecode, and labels the operation as a confirmed EVENTD08 sandbox
   projection. Generic routine-`40` input remains unresolved; nonmatching DEF
   boundaries stay read-only and expose no continuation.
   Trace v15 also passes through command `0x1F` source-line markers and command
   `0x0D` statement separators without changing sandbox state. After the
   confirmed coordinate-zero EVENTD03 prefix reaches `0x022E`, it advances
   through markers `21..25`, the intervening bounded `global_u8`
   write, and the first original CP932 message at `0x0258`; it retains the
   separator at `0x025C`, inserts the Sandbox tab's tool-only preview name at
   `0x025D`, and joins the surrounding original fragments into one preview
   line. An empty preview name remains visibly `〈主人公名〉`; it is never read
   from or written to a gameplay save. Exact `13 FF` at `0x0282` is retained
   as a no-state message-cursor control and falls through. The exact
   `02 02 FF 00` trailer at `0x0284` is reported as a supported dialogue
   boundary with physical continuation `0x0288`. Event Player enables Continue
   only for that supported result; the button and focused game-frame
   click/Space/Enter/right input resume from the retained offset and temporary
   argument-slot snapshot. The first continuation retains routine `0` value
   `47181` as post-message metadata and reaches the next original dialogue
   boundary at `0x02E2`. A second continuation recognizes outer native
   presentation control at `0x0305` and its subcommand-7/name record beginning
   at `0x0306`, previews the validated `voice.arc` payload without interrupting
   BGM, and reaches the third dialogue boundary at `0x0378`. Repeated explicit
   continuation reaches all 12 bounded dialogue trailers, message-record IDs
   `47181..47192`, all four validated voice markers, and the isolated completion
   write `global_u8[751] = 1`, then stops successfully at command `0x00` at
   `0x07FF`. That stop is a confirmed `script_return` boundary; Event Player
   does not synthesize the absent caller stack. The authoritative `12C.MES`
   command-`0x0F` envelope at `0x0DDE` names `EVENTD03.MES` and ends at physical
   caller resume `0x0DEE`; Event Player rechecks both entry hashes, decoded
   target/end, and exact envelope bytes before classifying the return as event
   completion. Configured-original executable audit v38 separately confirms
   command `0x0F` through manager slot `+0x38` and handler `0x004192A0`,
   including entry at callee coordinate zero and caller-context restoration.
   This is a complete bounded EVENTD03 callee preview from the original zero-
   coordinate contract, not execution of its original caller. The final
   dialogue footer announces
   `EVENT COMPLETE`; advancing once more opens an explicit completion screen
   that labels `12C.MES:0x0DEE` as the caller resume. The enabled **Preview
   Caller BGM** action then runs only the exact hash-bound
   `12C.MES:0x0DEE..0x0E62` prefix. It selects `X_MAS.WAV` for sandbox date
   `1224`, `SHOGATU.WAV` for `1301`, or `IDOU.WAV` otherwise, presents the
   resolved `bgm.arc` entry through the existing preview channel, and stops
   before command `0x03` at `0x0E62`. All three date routes are probed before
   the action is offered; each emits one expected routine-23 request with no
   state diff. Neither completion UI transition nor caller BGM preview changes
   sandbox state. The resulting **Continue Caller Handoff** action is available
   only for the original `12C.MES` hash and exact EVENTD03 session. It executes
   the separately hash-bound `0x0E62..0x0E88` suffix, records isolated
   `global_u8[286] = 1` and `banked_u16[0][242] = 12`, and stops at the
   `MACHI.MES` active-string handoff marker `0x0E7B`. The completion screen
   explicitly says that the unresolved host consumer was not executed.
   Between continuation segments, the tool retains the most recently confirmed
   MMO texture and loaded BGM/voice streams until a later trace replaces them
   or the selected entry is reset. The frame labels these as unchanged session
   state; absence of a new resource request is not presented as new original
   behavior.
   Entry/stop coordinates and resolved MMO, AX, BGM, and voice diagnostics are
   displayed in a desktop panel above the preview rather than drawn over the
   logical 640x400 frame. The embedded frame is reserved for the decoded game
   image and its dialogue/choice presentation; moving these tool diagnostics
   does not change original coordinates or execution semantics.
3. **Image ARC Editor:** MMO and DAT/PAL browsing, source dimension validation,
   lazy PNG-equivalent preview, and new-file PNG export are implemented. Its
   right workspace separates **Asset View** from **Game Frame**. Asset View
   shows the decoded source and its exact dimensions; Game Frame reuses the
   same decoded texture in the shared fixed 640x400 viewport, preserves native
   pixels, and exposes preview-only logical X/Y placement plus Center. Images
   larger than the game frame are clipped by that frame instead of scaled down,
   while smaller sprites are not enlarged. Placement never changes staged
   bytes, overlay records, or ARC output. The shared MMO encoder now has
   synthetic pixel round-trip coverage with strict
   target-header and dimension validation. The GUI can stage and remove
   verified same-dimension PNG replacements and save the session to one overlay
   update or one verified new ARC copy. Same-dimension replacements encoded
   with the exact target header are `original_engine_compatible`; generated
   headers and every unresolved image path remain `remake_only`.
   **Load Overlay** attaches an existing hash-bound package as a read layer;
   **Hot Reload Overlay** reopens its manifest and payloads after an external
   update, and **Clear Overlay** returns previews to the original ARC. All
   supported image paths use one resolution order: the editor's pending
   session, then the loaded overlay, then the read-only original ARC. DAT and
   PAL are resolved independently so a valid package may replace either or
   both halves of the logical pair. Load and Hot Reload first register the
   current read-only ARC with a separate candidate resolver, configure the
   candidate once, and run the shared archive-binding transaction. It checks
   every current-archive record, including entries outside image formats, from
   one deep-copied validated manifest snapshot and one ARC fingerprint.
   That fingerprint must still match the one captured with the displayed index.
   Every record in that snapshot targeting the open ARC must name an existing
   entry and match the same base-ARC SHA-256 and that entry's original SHA-256.
   Entry labels are derived from that same snapshot rather than by reopening
   the manifest. Only then are the candidate resolver, overlay root, target
   labels, selected-entry details, and decoded preview activated together. A
   malformed, changed, wrong-base, missing-entry, or resolver-mismatched
   candidate is closed and leaves the last valid read layer and visible
   preview unchanged. This validation is per archive entry: a loaded DAT/PAL
   package may still replace only DAT or only PAL, and the unmentioned half
   continues to resolve through the normal resolver priority. By contrast, an
   authored pending DAT/PAL edit remains one logical session item that owns and
   publishes both cache-backed entries together. Changing or clearing the
   loaded overlay is refused while pending edits depend on that layer. A
   successful overlay save attaches the just-published package through the
   same candidate transaction without discarding the pending session; removing
   the pending records then reveals the saved overlay bytes.
   The shared DAT/PAL encoder now provides deterministic weighted median-cut
   quantization, BGR palette output, bottom-up indices, and strict binary
   index-zero alpha for 640x32 strips. The GUI stages and saves both paired
   entries together. Content Core `0.185.0` adds the versioned
   `kakyu_ai5_dat_pal_diagnostics/v1` contract. Decode reports the number of
   used and unused palette indices plus the exact index-zero pixel count; for a
   640x32 strip that count is explicitly the transparent-pixel count and index
   zero is reserved. Encode reports source and palette color counts, opaque and
   transparent pixels, changed colors and pixels, exact pixels, RGB mean
   absolute and root-mean-square error, and maximum per-channel error. Error
   metrics cover opaque RGB samples only; RGB stored beneath alpha zero is not
   presented as visible loss. Image Editor shows these values for decoded and
   pending pairs. A candidate that changes visible pixels remains outside the
   authored pending session while a modal comparison shows the imported PNG
   beside the deterministic encoded result. The comparison reports changed
   pixels, source/palette colors, RGB mean absolute and RMS error, and maximum
   channel error. Reject closes it and deletes both transient cache files.
   Accept rechecks the selected entry, open-ARC fingerprint, cache size/hash,
   and reopened pixels before it promotes the exact reviewed DAT/PAL pair into
   the ordinary remake-only pending session. A changed candidate fails closed
   without disturbing an older pending replacement.
   This diagnostic contract does not promote DAT/PAL original-engine
   compatibility, which remains separately unverified.
   Content Core `0.186.0` adds `kakyu_ai5_dat_pal_palette/v1`. Its inventory
   enumerates all 256 BGR-backed entries with decoded RGB, archive index,
   reference count, used/unused state, and the 640x32 index-zero reservation.
   Mutation accepts one finite opaque RGB value, writes only that entry's three
   BGR bytes into a detached PAL copy, and rejects an out-of-range entry or the
   reserved transparent index. Image Editor exposes this inventory below the
   selected DAT/PAL preview. A non-reserved edit is encoded, reopened with the
   current effective DAT bytes, and staged as the existing two-file logical
   session; the original ARC and loaded overlay remain read-only. Removing it
   reveals the previous resolver layer. This supports direct palette editing
   as well as explicit approval of a lossy PNG import.
   AX and A6 entries are also listed and inspected. A6 exposes the
   EXE-confirmed `ID, left, top, right, bottom` input regions, inclusive-edge
   policy, first-match behavior, and duplicate/inverted-region diagnostics.
   Existing A6 records can be selected and edited without changing table order;
   the encoded table must reopen before it enters the cache-backed overlay or
   new-ARC session. Its Game Frame outlines the stored inclusive rectangles at
   logical coordinates and maps a pointer click through the confirmed native
   first-match rule. This is a metadata visualization, not a decoded image;
   off-frame coordinates are merely clipped. Add, remove, and reorder remain
   disabled. AX exposes neutral aligned dword tokens and its terminal padding.
   Its structural Game Frame lists non-`0xFF` binding cells and outlines the
   confirmed destination records directly referenced by the selected stored
   stream, without executing loop controls or tick timing. Neither path offers
   a pixel preview or PNG import: A6 has no decoded pixels, while AX still lacks
   source-surface contents, host timing, and a writer.
4. **Audio ARC Editor:** multi-entry authored sessions, batch overlay save, and
   batch new-ARC export are implemented with PCM WAV and Ogg Vorbis
   codec/channel/sample-rate checks, entry-name binding, change detection for
   staged source files, and no re-encoding. Pending work survives individual
   saves but is explicitly confirmed before an ARC switch or whole-session
   clear. New ARC export refuses source overwrite, an existing output, and
   noncanonical source layouts. The resize-capable `se.arc` output has passed
   both isolated original-engine title launch and PCM replacement playback as
   described above. A no-reencode `D0977.OGG` <- `D1033.OGG` replacement
   candidate can now be prepared and reopened headlessly; its Ogg playback and
   explicit original-engine playback of other replacements remain later work.
   Existing overlay packages can be attached, Hot Reloaded, or cleared through
   the shared resolver. Entry labels, bounded header inspection, playback, and
   extraction all resolve `pending session -> loaded overlay -> original ARC`.
   Header inspection keeps the 64 KiB bound; playback loads only the selected
   stream, and extraction copies pending/overlay files in bounded chunks to a
   new path. Overlay changes are refused while pending replacements exist. A
   successful save attaches the published package so removing pending records
   reveals the saved audio without reopening the source archive. Load and Hot
   Reload first register the current read-only ARC with a candidate resolver,
   configure one validated manifest snapshot, and resolve every record that
   targets that archive. Only a fully source-bound candidate replaces the
   active resolver, root, and entry labels. A malformed, wrong-base, missing-
   entry, or resolver-mismatched candidate leaves the previous overlay,
   details, and preview stream unchanged.

Content Core `0.189.0` adds `kakyu_audio_timeline_summary/v1` as the shared
audio-analysis record. PCM WAV validation now retains the exact data-chunk
offset and size, byte rate, block alignment, whole sample-frame count, and
duration. A full selected payload may be summarized into at most 256
min/max/RMS buckets while inspecting no more than 262,144 evenly distributed
PCM frames; the record states whether every frame was inspected. Ogg Vorbis
duration is computed from the final nonnegative granule of one bounded logical
stream. The core deliberately returns `waveform_available=false` for Vorbis
until decoded PCM is supplied, rather than treating compressed bytes as visual
amplitude. Audio Editor's explicit **Analyze timeline** action consumes this
contract without changing its 64 KiB selection-time header bound: original ARC
WAVs use one range read per waveform bucket, file-backed layers are hash-checked
before and after analysis, and Ogg reads only its header plus at most a 128 KiB
tail. Details show duration, total/analyzed frames, complete versus sampled
provenance, and a compact amplitude summary. The authoritative read-only corpus
check validated all 17,503 audio headers and one range-summary representative
per present ARC/format with zero failures; it does not play a device or establish
original-engine replacement compatibility.

Audio Editor exposes that contract through **Load MES references...**. The
selected original or verified materialized `mes.arc` is read-only and
fingerprinted before and after indexing; any entry read/container parse
failure rejects the candidate without replacing the last valid index. The UI
processes 16 source entries per frame and reports progress. Once active, the
selected OGG/WAV details show the confirmed count and bounded MES source
locations. The authoritative corpus gate indexed all 1,016 entries and found
5,361 strict BGM pairs plus 26,069 confirmed voice envelopes, including
`EVENTD01.MES:0x03E6` selector 33 / routine 23 for `MAKI.WAV` and
`EVENTB01.MES:0x02BF` for `B0796.OGG`; all source archive hashes remained
unchanged. These totals are static reference occurrences, not route
reachability claims.

Content Core `0.190.0` adds the pure `kakyu_mes_audio_reference_index/v1`
projection used by audio tooling. Voice results come only from the bounded
command-`0x0D`/subcommand-7 Ogg marker already classified by MES analysis.
BGM results require two strict instructions in the same decoded region with no
gap: command `0x09` assigns one literal selector to argument slot 1 and the
immediately following command `0x1D` invokes literal shared routine 23. The
selector is resolved through the archive-derived `LIBLARY.LIB` catalog. Dynamic
selectors, other slots or routines, intervening instructions, unknown selector
values, and filename-like byte strings are deliberately omitted. Each result
retains the MES entry, code-relative assignment or marker offset, call offset
where applicable, archive candidates, boundary class, and evidence label.

Content Core `0.191.0` adds the pure `kakyu_audio_conversion/v1` contract and
three explicit target presets. `se.arc` WAV targets use mono, 22.05 kHz,
16-bit PCM, the profile exercised by the controlled original-engine
`KSE0031.WAV` replacement check. `bgm.arc` WAV targets use the original corpus
profile of stereo, 44.1 kHz, 16-bit PCM, but remain
`original_engine_unverified` until a replacement is played in the original
engine. Voice-bank Ogg targets expose a mono, 44.1 kHz Vorbis preserve-only
profile: matching input is retained byte-for-byte, while nonmatching input is
rejected because the suite does not yet contain a verified Vorbis encoder.

PCM conversion is never implicit. A matching WAV returns the complete input
unchanged, including valid opaque or trailing bytes. An explicit conversion
emits a canonical PCM RIFF/WAVE container after deterministic signed channel
mixing or duplication and integer linear resampling. Output-frame rounding,
interpolation rounding, endpoint retention, and PCM16 clamping are fixed by
the shared implementation, and the result is validated again before it leaves
the core. Input and output are each limited to 512 MiB and receive separate
SHA-256 fingerprints.

Audio Editor exposes the encoder-capable WAV profiles through **Convert WAV to
target...**. This action is distinct from no-reencode **Add/update
replacement...**. It binds the visible ARC entry and source-file fingerprint,
requires a new `.wav` destination, then converts from the captured bytes. The
core writes a unique sibling temporary file, checks size and SHA-256 after
reopen, rechecks that the destination is absent, atomically renames it, and
verifies the final file. Only that verified path/hash enters the pending
session; a changed input, hidden/changed target, existing output, write error,
or reopen failure publishes no replacement and leaves no temporary residue.
The pending record displays the preset, compatibility, input fingerprint, and
output fingerprint without retaining PCM bytes in memory while idle. A session
containing only verified SE-preset conversions may retain
`original_engine_compatible`; BGM conversion is
`original_engine_unverified`; any ordinary imported replacement keeps the
existing conservative `remake_only` package declaration.

## Verification Gates

The aggregate headless runner publishes `kakyu_content_tools_validation/v6`
(since 2026-09-23, TD-33: v5 plus `jobs` in the context; v5 reports load
as `jobs: 1`). v5 (since 2026-09-21, TD-32: v3 plus the run's `tier` in the context, the source
flags true only when the tier planned such checks, the coverage reason
`Excluded by --tier <tier>.`, the cached rows with the `cached` count and
the `cache` / `cache_dir` context; v4 and v3 reports still load).
The stored envelope carries `schema`, `payload_json`, and `payload_sha256`;
the fingerprint covers the exact UTF-8 payload string before JSON parsing.
The payload includes a run UUID, repository-only source context, six coverage
groups with inclusion/omission reasons, result counts, and per-check status,
duration, exit code, and up to 4,096 characters of failure output. Configuration
errors are reports too. Writes are atomic; readers reject unknown versions or
inconsistent fields rather than treating an incomplete report as a pass.
Direct Godot checks also reject `SCRIPT ERROR`, script-load failures, and
autoload creation failures even when the engine exits with code zero. ANSI
color escapes are removed for matching, and a bounded diagnostic is appended
to the failure tail so later output cannot hide its cause. Expected application
rejections (`push_error`) do not by themselves fail a test; Python negative-test
subprocess output remains subject to the Python test's own verdict. A script
diagnostic with child exit code zero is an `error` check with null `return_code`
under the existing v3 report contract, and the actual child exit code is retained
in its bounded diagnostic. A nonzero child exit remains a `failed` check. This
lets detection, failed aggregate status, atomic report publication and viewer
reopening agree without changing the report schema.

The `--elfimage` batch also runs **original Python Phase 1-4 full handoff
equivalence**, with `--require-full-equivalent` and no entry limit. Its tracked
comparison input is `config/mes_analyzer/frozen_gd_instruction_v45.jsonl`, a
fingerprint/count-only digest of all 1,016 approved historical GD handoffs.
The Python audit reads the original archive, validates every actual handoff,
and reports actual Python and producer-only projected hashes separately. Its
one-hour timeout fails closed. The existing Godot handoff completion check
remains a separate historical baseline check, not a substitute for this gate.

The launcher/session/report regressions cover malformed reports, stale run
identity, failed and missing processes, legacy v2 display, and geometric fit at
1024x640, 1920x1080, and 2560x1440. Manual Windows DPI and visual verification
remain in the accumulated distribution batch.
The 2026-09-06 local v3 run passed 94/94 checks in 156.874 seconds: 1,209
Python tests, project parsing and all 92 Godot test scenes. The completed
report reopened through the Godot reader. Separate actual Windows process
checks covered successful and configuration-error session completion, and
Python-produced pass/fail/launch-error/timeout reports all reopened in Godot.
Its original-content batch includes the bounded routine-28 execution,
routine-25 external-DEF audit, composed EVENTD08 choice routes, and Event Player
integration, including the EVENTD02 native-effect omission and completion route, in addition to
the archive/codec corpora. With an original launcher
it runs the native ARC, MES, and bounded Ogg/voice executable audits; it never
launches either GUI.
A historical bounded v2 run against the configured authoritative sources passed
all 88 checks in 228.2 seconds: 111 Python tests, the Godot parse and
synthetic app/core suite, every configured original archive corpus/integration
check, the surface-dispatch reachability audit, the DEF context registry audit,
and all configured executable audits. The included exhaustive runner covered
1,015 executable MES entries and 133,459 indexed intro anchors in
969,912 traced steps with no fatal runner failure. Together these checks include complete
EVENTD01, EVENTD02, and EVENTD03 callee-to-12C caller continuations, the
EVENTD05 route variants, the EVENTD08 caller continuation and inherited BGM,
the two `L_TALK30.MES` caller/choice compositions through their exact
`L_PROMIS.MES` boundaries, the dedicated caller-route core contract test, and
unchanged `mes.arc`,
`mmo.arc`, `bgm.arc`, and `voice.arc` hashes. The
known missing local-only calendar-rules diagnostic remained non-fatal and did
not change any content or gameplay save.
The same no-window batch validates the EVENTD06/EVENTD14 catalogs and caller
envelopes, including all three EVENTD14 choices through their current-date
caller BGM preview and exact `MACHI.MES` handoff suffix. The shared source
contract separately replays both special dates and the explicit default,
executes all 131 nonzero fragments to their first safe boundary in fresh
sandboxes, previews fragment 1 from each entry through the actual controller,
and rechecks the source `mes.arc` hash. It rejects decoder, expression,
address, write, step-limit, and unsupported-command failures.
The original-app controller batch also reproduces all 1,016 `mes.arc` index
rows in ARC Browser, case-fold filters `START.MES`, rejects extraction after
the selected row is hidden, and hash-checks a streamed extraction after the row
is selected again. It loads
`01CA_1.MMO` and `CHARA.DAT/PAL` through Image Editor into its native-pixel
640x400 game frame, and validates `KSE0031.WAV` plus `D0044.OGG` through Audio
Editor without starting playback. These checks require empty authored sessions
and byte-identical source archives.

Synthetic tests cover valid reads, range/chunk streaming, malformed headers,
out-of-bounds entries, traversal names, no-op SHA equality, source immutability,
equal-size changed-entry behavior, resize refusal on the conservative API,
explicit variable-size rebuilds, contiguous offset repair, opaque name-field
preservation, unchanged-entry byte equality, existing-output refusal, and
noncanonical-gap rejection. Corpus checks cover no-op rebuilds and canonical
layout eligibility for every original ARC. Codec work
adds decode round trips and malformed compressed-stream rejection. Every GUI
increment must parse in Godot 4.7 Compatibility and remain usable without any
local original archive.

Overlay tests additionally cover coexistence of binary replacements and MES
text projections, strict message-offset and original-byte-hash binding,
UTF-8/schema retention, rejected-update manifest immutability, and preservation
of projection records across later binary replacement transactions. Loader
coverage includes current-source binding, offset-indexed text, and an explicit
absent-projection result. Two-entry batch coverage requires one manifest update
and both payloads to reopen; a batch with one stale target must leave both the
manifest and projection-file set unchanged.
Projection-removal coverage requires the selected manifest record to disappear,
all other records to remain valid, the unreferenced payload to remain present,
and a repeated removal to perform no write.

The MES Editor headless test stages edits in two ARC entries, changes entry
selection without losing either edit, performs one batch save, reopens both
projections, and requires the original synthetic archive hash to remain
unchanged. It then detaches one saved entry, requires cache presentation to
resume, and verifies that the other manifest projection remains intact.
The original-content MES Editor integration validator separately opens an
authoritative entry through the actual UI controller, requires decoded CP932
in both the table and edit field, checks live byte-count eligibility, and
prepares one changed equal-size binary entry entirely in memory while requiring
the source archive SHA-256 to remain unchanged.

The Event Player headless test stages a MES text projection through the shared
core, requires overlay text to override cache text only when its raw-message
hash matches, publishes an external update, and requires Hot Reload to display
the new text without changing the source archive. The same test then creates
a remake-only equal-length binary MES patch through the shared patcher's
non-native-strict path, publishes it in
the same package, and requires Hot Reload to use that replacement while a
stale raw-message projection is bypassed in favor of decoded `overlay CP932`.
It also requires a supported
dialogue boundary to enable both the explicit Continue button and the
game-frame continuation hint. Its synthetic second segment uses the exact
set/voice-marker/clear envelope, requires the full `D0977.OGG` payload to
validate through `voice.arc`, and preserves separate confirmed-native-route,
native-DirectSound-dispatch, unobserved-device-output, and tool-preview labels.
The same session stages MMO, WAV, and OGG binary replacements, requires
Hot Reload to prefer all three through the shared resolver, and verifies that
a confirmed script return clears the session continuation without touching any
source archive.

The original-content Event Player integration validator additionally drives
hash-bound `EVENTD03.MES` from coordinate zero through the GUI controller in
headless mode. It requires the exact entry-zero bootstrap, routine-28 boundary,
two bounded three-record list omissions, naturally reached original-ARC
`D03.MMO`, independent banked write, decoded-but-unexecuted surface operation,
default `global_u8[4000] == 0` branch, routine-21/routine-28 sequence, retained
`MAKI.WAV`, 12 explicit dialogue continuations, ordered `D0977.OGG` through
`D0980.OGG` previews, sandbox completion, and the confirmed callee return while
source archive hashes remain unchanged. It also requires the final
`EVENT COMPLETE` footer, explicit completion screen, unchanged sandbox state,
the exact `12C.MES:0x0DEE..0x0E62` BGM prefix, all three date-selected catalog
routes, and the default-date `IDOU.WAV` preview through the actual UI
controller. A source/slice hash, coordinate, record count, marker, branch, or
media mismatch fails closed. It then drives the exact caller suffix, requires
the two confirmed
sandbox writes, and stops at `MACHI.MES:0x0E7B` with no continuation. This
closes the wiring gap between the lower-level route validator and the
independent app without claiming audible headless playback, native MMO
placement, or execution of the handoff's host consumer.

### MES Editor Run Handoff

Revision 2026-09-15 (Core 0.321.0, EP-08): `kakyu_mes_editor_run_request/v1`
keeps its shape and accepts only `original_arc` content with an
`exact_original` interface and identical source/effective entry hashes; the
semantic-diff interface and the derived-compatibility claims described below
are no longer accepted by the contract, the MES Editor no longer publishes
them, and the Event Player rejects them before any session mutation. The
paragraphs that follow describe the contract as frozen at 0.266.0 and are
retained as history.

Content Core `0.266.0` freezes `kakyu_mes_editor_run_request/v1` as the
path-free boundary between MES Editor and Event Player. The request binds the
immutable workspace generation/project/manifest/content-set fingerprints, one
logical `mes.arc` entry and effective byte identity, either an explicit
Analysis coordinate or a declared catalog event/preset, and one declared
interface-proof identity. Exact-original requests require identical original/effective
entry hashes. Original-derived requests require a Phase 6 semantic-diff v1-v4
fingerprint and may claim only remake-only or original-engine-unverified
compatibility; structural preservation alone cannot promote an edited MES to
original-engine compatible.

The compact request binds the semantic-diff schema and fingerprint but does not
embed the full proof. The eventual publisher and consumer must each load and
validate that proof through the matching Content Core contract. The request
deliberately contains no content-set, workspace, overlay, or payload path. A
consumer must reopen the named startup workspace separately,
re-resolve the effective MES, recheck its size/hash and workspace generation,
then validate the selected catalog/preset before changing the current player
session.

The MES Editor controller can now publish the selected parsed entry as an
Analysis-mode v1 request. Publication requires an active named workspace and a
stable current manifest; it re-resolves the effective entry, rechecks its hash
and size against the editor document, validates the requested instruction or
address-entry start, and builds either an exact-original interface or a
matching Phase 6 semantic-diff interface. It refuses pending edits and an
unstaged message draft, writes outside the source ARC directory to a new JSON
path through a temporary file, reopens the complete request against the same
workspace generation and effective bytes, and never replaces an existing
request. This controller boundary neither mutates nor copies the source ARC.

The v1 contract itself does not launch a process, declare a catalog route
playable, or execute the original engine. Those remain controller concerns.

Content Core `0.267.0` extends named tool startup with optional
`--run-request` and `--interface-proof` runtime inputs. These paths are never
copied into the request or workspace snapshot. The launch context checks only
that each named input is a readable JSON file and requires a Run request when
an interface proof is supplied; the Event Player remains responsible for the
documents' schemas and identities.

Content Core `0.268.0` adds the path-free
`kakyu_mes_translation_catalog/v1` exchange contract. It exports only stable
entry/offset/message-hash identities for strict CP932 dialogue and never
includes original text, raw bytes, lossless bytecode, payloads, or filesystem
paths. Translation rows carry editorial state, translator ID, and increasing
revision provenance. Reconciliation rebuilds the current parsed-message index
and separates stale source, stale entry, stale message, missing source row,
missing catalog row, and conflicting row diagnostics. Only an exact source
generation and exact entry/message bindings yield offset/hash-bound UTF-8 edit
inputs.

MES Editor exposes selected-original-entry Catalog Export, Update, and Import
actions in its Messages tab. They require an active named workspace, keep every
catalog path below that workspace, write new files exclusively and atomically,
and reopen each output through the shared validator. Update applies the
selected entry's staged translations with an explicit translator ID and
increasing catalog/row revisions. Import rebuilds the current selected-entry
catalog and rejects the whole operation on stale source, stale entry/message,
missing, mixed-entry, or conflicting diagnostics. Exact translated rows enter
the existing offset/raw-hash-bound pending-edit session; the ordinary UTF-8
Save-all transaction publishes and reopens them, and clearing the overlay
restores original dialogue without changing the source ARC. Merged-main
user-controlled verification completed that entire workflow: revision-one
export, staged revision-two update with translator provenance, revert/import,
UTF-8 overlay publication, and original-dialogue restoration.

Content Core `0.269.0` adds `kakyu_mes_text_output_policy/v1` as the
pre-publication compatibility boundary for one source-bound pending message
edit. Its path-free report retains only logical names, coordinates, counts, and
hashes. The remake target accepts source-valid UTF-8 as a `remake_only` text
projection without applying CP932 length rules. The original-runtime candidate
also requires strict CP932 representation, the native byte/projection and
text-consumption constraints, and exact source/replacement byte length; it
reports overflow and underflow separately. A ready CP932 result remains
`original_engine_unverified` until the independent original-engine gate passes.
Stale archive, entry, or message identity and embedded NUL block both targets.
Content Core `0.270.0` integrates the report into every MES Editor UTF-8 and
CP932 publication callback. Each pending entry is freshly resolved and parsed,
the current archive/entry/message identities are compared with the staged
identities, and all target-specific blockers are aggregated before any writer
runs. Refusal retains the complete pending session. The live message row shows
independent remake-only UTF-8 and unverified CP932 readiness; successful CP932
overlays and ARC provenance carry `original_engine_unverified` rather than a
false compatibility claim. Focused headless regressions and user-controlled
MV-C06 cover the resulting editor workflow. MW-10 is complete; MV-03 remains
the only gate that may supply original-engine playback evidence.

Content Core `0.271.0` adds
`kakyu_event_player_routine40_consumer_plan/v1`. This Phase 7 consumer rebuilds
the current grouped routine-40 reachability contract and accepts only a live
numeric result pair. It yields an exact stored consumer, exact stored fallback,
or empty-list stop together with the fixed slot-21/slot-13 writes. The plan is
path-free, fingerprinted, JSON-safe, and `remake_only`; it excludes definition
payload, text labels, native effects, and caller restoration. Product execution
therefore still requires a separately retained source-bound caller frame.

Event Player now consumes `analysis_entry` requests. Before changing the
visible session it validates the request against the reopened workspace,
re-resolves the selected original or overlay MES, rechecks the source archive,
source entry, effective entry hash and byte count, parses the candidate, and
validates the exact code-offset or address-table start. Exact-original requests
reject an unrelated proof file. Changed-MES requests require the complete
Phase 6 semantic-diff JSON and recheck its schema, fingerprint, source identity,
and output binding. The requested program is first run against a fresh sandbox;
only a typed result commits the selected entry, fresh state, Analysis view,
start coordinate, and result. A rejected request therefore retains the current
session.

Exact-original `catalog_event` requests now resolve either the named catalog
preset or a workspace project preset. A project preset may reference an exact
catalog base and replace its sandbox writes only after the workspace has
validated the complete project record. The consumer requires the catalog's
callee entry and hash to equal the request's effective entry, then delegates to
the existing catalog readiness and ordinary-play transaction. The authoritative
EVENTB01 integration reopens a temporary named workspace over the read-only
original content set, consumes an exact-original Run request, applies the
catalog's daytime preset, and reaches its first user-facing dialogue while all
source archive hashes remain unchanged. Changed-MES Catalog Run remains
fail-closed because a general Phase 6 semantic diff does not yet prove or map
every caller, callee, choice, continuation, and terminal control point consumed
by the catalog. Such content can still use `analysis_entry` Run safely.

MES Editor now exposes this Analysis handoff as a toolbar `Run` action. It is
enabled only for a parsed entry in an active named workspace with neither
pending edits nor an unstaged message draft. The action uses the selected
disassembly record's code-relative offset, falling back to offset zero when no
record is selected, and publishes a uniquely named immutable request under the
workspace's `run_requests/` directory. It then starts a separate Event Player
process with the content-set root, workspace root, and request path supplied as
distinct runtime-only arguments. An effective overlay MES first requires the
matching full Phase 6 semantic-diff JSON through a chooser and passes that path
separately as `--interface-proof`; the compact request continues to contain
only its proof identity. The source ARC is never a publication target. Process
startup failure leaves the already validated request as immutable diagnostic
evidence rather than deleting or replacing it.
The EVENTD02 integration validator drives the exact one-click controller path
from coordinate zero. It binds the `12C.MES:0x098D..0x099D` envelope and checks
that only the executable audit supplies the zero-start/save-coordinate-restore
semantics, then requires the bootstrap, routine `28`, paired command-`0x12`
omissions, normalized `0x023F..0x0264` surface bypass, routines `21/28`, and
source-bound foreground/AX records before `0x03E6/0x03EC` and first dialogue
`0x0456`. X/Y MMO, foreground-MMO, and AX entries are fingerprinted; all three
coordinate-zero D01Z-family absences are part of the original content-set
contract. Later `D02X.MMO` and `D02Y.MMO` are independently fingerprinted and
`D02Z.MMO` is required absent for the later surface paths. The validator
then crosses routines 27, 25, audited DEF26, and 21. It requires the `0x0BAD`
native-presentation pause to remain non-complete while cycling its three
retained message fragments, and enables only the exact `0x0BB4` effect-omitting
continuation. (The pause no longer exists under Core 0.316.0 - see the
correction above - and the validator follows the seventh suffix dialogue
into routine 28 instead.) Four later routine-28 boundaries and 23 later dialogue boundaries
bring the session to 40 total, followed by completion `global_u8[750] = 1`,
return `0x18C6`, and the explicit caller-resume screen. It drives the default-
date caller BGM prefix through `0x0A11` without a state change and requires the
exact two-write suffix to stop at `MACHI.MES:0x0A2A`. Failed start validation
must preserve the prior presentation state. The check verifies unchanged
`mes.arc`, `mmo.arc`, `data.arc`, `bgm.arc`, and `voice.arc` hashes throughout.
The original-content EVENTD08 integration validator similarly drives the
actual Event Player controller from the hash-bound coordinate-zero action. It
requires the exact `12C.MES:0x0FA6..0x0FB6` command-`0x0F` envelope, first
address-table entry `0x0008`, nine ordered dialogue boundaries, 17 decoded
message fragments, and the five ordered `D1028.OGG..D1032.OGG` markers. It
also requires inherited `MAKI.WAV`, both exact command-`0x12` lists, record-
only omission, the naturally reached two-NUL `D08.MMO` envelope, and routines
28/21/28 before the three ordered DEF presentations appear in Results and the
game frame. Continuation remains disabled at the choice itself. The validator
then sends keyboard keys `1`, `2`, and `3` in three reset sandbox sessions,
requires the one-based `state_u16[21]` projection, an explicit state diff, and
an original dialogue boundary on every branch while `mes.arc`, `mmo.arc`,
`bgm.arc`, and `voice.arc` hashes remain unchanged.
The lower-level validator independently confirms first dialogue boundaries
`0x0780`, `0x0835`, and `0x09A7`. (Reported at the wait call since Core 0.316.0,
2026-09-13: `0x077D`, `0x0832`, `0x09A4`; the resume offsets are unchanged.) A second bounded route validator follows all
explicit continuations: choices `1/2/3` reach `2/4/2` dialogue boundaries,
`4/8/4` decoded message fragments, and voice markers
`D1033.OGG`/`D1034.OGG`/`D1033.OGG`, respectively. All three then stop at
`EVENTD08.MES:0x0A25`, an exact command-`0x1D` transfer to shared routine `28`.
Event Player resolves that ID through the loaded `LIBLARY.LIB` index and shows
its `0x02D0..0x03EB` body range before offering an explicit sandbox-only
continuation. The bounded runner follows routines 28, 27, and 25; the
hash-bound second action at the DEF-26 boundary composes the audited
`DEF_MAIN.MES:0x0203..0x042D` body. (Corrected under Core 0.316.0 on 2026-09-13:
the separator framing cut routine 27 after four rows at the `00` of a message
wait read as command `0x00`, leaving `banked_u16[0][1]` at 2; the routine
runs nineteen rows with three nested calls and leaves that cell at 7, and
routine 25 still stops at the DEF-26 boundary `0x0A66` after three rows.) Routines 21, 32 (including its nested
routine-31 call), and final routine 28 then reach the main-script return at
`0x0AE6`. The Results workspace also populates a **Shared Routine** tab with structural
branch/transfer targets, decoded Japanese text when present, lossless raw
bytes, and explicit strict-versus-structural diagnostics. For routine `28` the
strict prefix remains five instructions and stops at `0x02EE` on an unresolved
command-`0x0A` empty-stack destination. (Under Core 0.316.0, 2026-09-13, the strict
decode of routine 28 is complete - 33 rows through `0x03EB`, none structural
only, five typed record lists, a 33-coordinate/39-edge/5-span dispatch graph -
because the eleven "native streams" the structural pass counted were system
calls.) A separate non-executable structural
pass retains that command's full `0x02EE..0x02F4` extent and reaches the indexed
routine end `0x03EB`: 71 top-level instructions are visible, 11 of which
contain a non-singleton expression and are labeled **structural only**. Those
stored-order audit rows and the tab are not treated as an executed CFG path;
execution uses the separately bounded native-dispatch runner.
The native evaluator preserves a stack across expression calls; routine `28`'s
`0x02EE` command requires one incoming carried value and restores the same
depth. The structural row shows `persistent stack min 1, delta +0` beside its
non-executable label. A detached arbitrary intro cannot reconstruct that
incoming value; the confirmed EVENTD08 zero-coordinate path now carries its
audited temporary context through the choice instead. The Shared Routine tab
remains a read-only structural view. This
validates the exact tool projection and bounded caller path; it does not claim
reconstruction of the original routine-`40` key reader or native presentation
effects.

CP932 codec tests cover ASCII, half-width katakana, standard Japanese,
multi-character text, a Windows extension character, truncated lead bytes,
invalid trails, and undefined pairs. The current authoritative instruction-v18
corpus pass decoded 219,878 of 219,910 strict-indexed message candidates and
retained 32 exact CP932 diagnostics as unresolved structural/text boundaries.
After FF-boundary refinement, none of the accepted message candidates contains
the native-incompatible `F0..F9` lead range.

Routine automated verification is headless and must not take foreground input.
Checks that require the original engine or an interactive Godot window are
collected into a documented verification batch and presented to the user only
after the batch has meaningful coverage.

The headless preparation contract for that batch is
`kakyu_original_engine_verification_batch/v1`. It records a
`prepared_unverified` status, the checked launcher hash, an explicit
`launches_original_engine: false` flag, source-integrity result, and the three
candidate descriptors. Each descriptor binds its relative path, source and
candidate archive hashes, byte size, target entries, expected observation, and
`original_engine_unverified` compatibility. The PowerShell orchestrator
publishes the manifest and candidates only after all three individual
preparers succeed in a guarded sibling staging directory; absolute source and
tool paths are deliberately excluded.

The license-independent disposable-copy wrapper uses
`kakyu_local_verification_copy/v1`. It copies the checked launcher, INI, eight
ARC files, and relevant saves into a new local directory, replaces only the
three copied candidate archives, and rehashes every copied ARC before atomic
publication. The source installation and candidate batch are fingerprinted
before and after publication. Preparation never launches a GUI; opening the
copied executable remains the explicit user-controlled boundary because the
original engine may take keyboard focus. No optional OS virtualization feature
is required or offered as a verification path.

Manual observations from that boundary use
`kakyu_original_engine_verification_result/v1`. The recorder requires explicit
isolated-run attestation and one `pass`, `fail`, or `not_observed` value for
each MES, DAT/PAL, Ogg, and responsiveness check. Before atomic no-overwrite
publication, it reopens the prepared manifest, rejects traversal or a changed
safety contract, and verifies the byte size and SHA-256 of all three candidate
archives. The result binds the batch-manifest hash, launcher hash, source and
candidate archive hashes, target entry names, and observations without storing
machine paths or original payloads. Even an `all_observations_passed` result
retains `compatibility_promotion: not_performed` and
`manual_observation_only`; promotion remains a separate reviewed action.

The current deferred interactive batch contains the DAT/PAL atlas-marker check
in an isolated original-engine copy, playback of the prepared equal-length
`EVENTD03.MES:0x029F` CP932 marker candidate, the same event's distinctive
no-reencode `D0977.OGG` voice-swap candidate, visual/keyboard confirmation of
the MES Editor compact message-authoring row at the minimum desktop size and maximized
output, source-folder chooser history, and one complete EVENTD08 screen path.
The EVENTD08 check starts from the Confirmed row, requires inherited Maki BGM,
advances nine common dialogue boundaries, and observes the D08 background when
its original marker is reached. It then requires three Japanese DEF option
lines, covers Up/Down highlight movement and direct number-key selection, and
uses only game-frame click/Space/Enter/Right input for every dialogue and
bounded shared/DEF continuation. Expected visible milestones are the sandbox-
only state diff,
Routine 25's audited DEF-26 notice, the Routine-32 boundary without a false
CP932 dialogue row, final Routine 28, the completed script-return frame, and one
more Continue to the restored D.MMO plus branch-specific 12C caller dialogue.
Debug trace/state information must remain outside the 640x400 game frame throughout.
The **Shared Routine** tab must retain routine 28's five-row strict stop and
complete 71-row structural audit. None is a release claim until the larger
user-visible batch has been run.

The former direct `EVENTD03.MES:0x022E` Event Player anchor passed its user-
visible Godot check on 2026-08-02. An entered tool-only preview name appeared
inside the
single composed Japanese message, Reset restored the explicit `〈主人公名〉`
placeholder, and both runs stopped at the then-current `0x0282` boundary. This
confirmed presentation of that bounded trace only. It is historical evidence
for the inner dialogue presentation, not a validation of the newer coordinate-
zero start. The later headless `13 FF` increment and zero-start prefix are
recorded separately and have not been promoted to a new interactive validation
claim.

Content Core `0.188.0` adds the versioned
`kakyu_event_audio_state/v1` pure transition model. It accepts only a complete
effective audio identity (logical ARC, entry, resolver source, and payload
SHA-256), so an original, overlay, verified materialized ARC, or fallback
resource cannot be silently retained as a different revision. BGM transitions
separate start, identical retain, replace, stop, bounded caller capture, and
caller restore. Voice transitions explicitly select replace, queue, or overlap
behavior and promote queued identities deterministically after completion.
The contract owns no `AudioStreamPlayer` and makes no native timing claim.
Event Player now mirrors successfully resolved BGM and voice identities into
it, including overlay and verified materialized-ARC SHA changes, while keeping
its existing single-player preview transport. Failed derived-layer activation
preserves the active audio snapshot. Caller restore and real queued/overlapping
transport remain later P3-05 steps.

The machine-local source-path configuration was unavailable during the initial
synthetic implementation and was configured before the corpus checks below.
No new opcode or scene-behavior meaning is inferred by these container and
codec validations.

The GDScript instruction decoder was cross-checked against a generated Python
v6 IR oracle for `START.MES`, `MACHI.MES`, `EVENTD03.MES`, `D_TALK00.MES`, and
`D_DATE3.MES`. The stale C-string oracle first exposed 54 deferred-`0xFF`
boundary disagreements in 2,323 rows. After the Python compatibility reader
adopted the same executable-confirmed double-byte probe, all 2,335 regenerated
strict-valid instructions matched source/end offset, command ID, and raw
bytes. Tolerant candidates with invalid expression diagnostics remain counted
but are excluded from executable samples. A separately regenerated cache for
those five entries loaded 2,122 UTF-8 message offsets with archive, entry, and
projection-file hash checks and zero failures; the lower count excludes false
C-string messages that crossed native `0xFF` boundaries.

Content Core `0.54.0` adds versioned MES resource-reference browsing alongside
`kakyu_ai5_ax_dword_stream/v1` and
`kakyu_ai5_a6_record_table/v1` and continues to use versioned
`ai5_mes_instruction/v20`,
`kakyu_mes_library_index/v1`, `kakyu_mes_library_audit/v6`,
`kakyu_mes_stack_effect/v1`, `kakyu_mes_analysis/v4`, and
`kakyu_mes_event_trace/v17` records. Instruction v20 retains v19's exact
bounded command-`0x08` AX filename envelope as `ax_resource_marker` before
trying the numeric dword-write grammar. Trace v17 retains the normalized
resource name and explicit unresolved native-consumer status, falls through,
and performs no command-`0x08` sandbox-state write for that marker. Instruction
v20 also narrows voice-marker names to the archive-audited ASCII letter plus
three or four digits and `.og`/`.ogg` grammar; a merely wrapped arbitrary OGG
filename is no longer promoted to voice metadata. This matches the independent
archive audit while preserving the EXE-confirmed fact that native command
`0x07` is a word-state writer. Instruction v20 otherwise retains the v18
structural behavior described below.
Content Core `0.55.0` advances the current instruction contract to
`ai5_mes_instruction/v21` and Event Runner output to
`kakyu_mes_event_trace/v18`. Instruction v21 corrects command `0x11` from the
earlier operand-free projection to its EXE-confirmed common record-list
operand and names the boundary `definition_invoke`. Trace v18 evaluates and
retains the selected DEF ID while still stopping before the unreconstructed
native registered-body call frame. All other v20 instruction and v17 trace
behavior remains compatible.
Content Core `0.56.0` advances Event Runner output to
`kakyu_mes_event_trace/v19`. Trace v19 added a provisional command-`0x16`
`native_selection_boundary`; the later executable cross-check recorded under
Content Core `0.62.0` corrects that command-ID assignment. Instruction schema
v21 was unchanged in this historical revision.
Content Core `0.57.0` advances Event Runner output to
`kakyu_mes_event_trace/v20` and the full runner audit to
`kakyu_mes_event_runner_corpus_audit/v7`. Trace v20 reports command `0x12` as
an explicit `native_presentation_boundary`, retaining its bounded native-stream
probe and a no-sandbox-write marker. It does not reproduce native display or
cursor state. Instruction schema v21 is unchanged.
Content Core `0.58.0` advances Event Runner output to
`kakyu_mes_event_trace/v21` and the full runner audit to
`kakyu_mes_event_runner_corpus_audit/v8`. Trace v21 reports command `0x11` as
an explicit `definition_invoke_boundary` with its evaluated DEF selector and a
no-sandbox-write boundary. The native registration lookup and caller frame are
still not reconstructed. Instruction schema v21 is unchanged.
Content Core `0.59.0` advances Event Runner output to
`kakyu_mes_event_trace/v22` and the full runner audit to
`kakyu_mes_event_runner_corpus_audit/v9`. Trace v22 reports a command `0x1D`
with a resolved literal routine ID as `shared_routine_boundary`; Event Player
uses the shared library index to display its bounded read-only body audit.
Generic call execution and nonliteral selectors remain unsupported.
Instruction schema v21 is unchanged.
Content Core `0.60.0` advances Event Runner output to
`kakyu_mes_event_trace/v23` and the full runner audit to
`kakyu_mes_event_runner_corpus_audit/v10`. Trace v23 reports a zero-character
command `0x01` as the same fail-closed `native_presentation_boundary` family as
command `0x12`, while retaining its distinct double-byte handler family and
probe. It never creates an empty message. Instruction schema v21 is unchanged.
The audit-only `kakyu_mes_event_runner_corpus_audit/v11` revision adds bounded
command-`0x0F` target, record-shape, entry, sample-coordinate, and following-
command summaries. It does not change Content Core, instruction, or trace
contracts and does not execute the referenced script.
Content Core `0.61.0` advances instructions to `ai5_mes_instruction/v22`, Event
Runner output to `kakyu_mes_event_trace/v24`, and the full audit to
`kakyu_mes_event_runner_corpus_audit/v12`. One ARC-safe ASCII `.MES` string
record now decodes as `script_dispatch`; the runner reports its target through
`script_dispatch_boundary` and stops without target execution, caller-return
inference, or sandbox writes. Audit v12 also verifies that every reached target
resolves in the authoritative archive. Other command-`0x0F` record shapes stay
numeric and unsupported.
The audit-only `kakyu_mes_event_runner_corpus_audit/v13` revision adds bounded
per-command samples for every remaining unsupported stop: entry and address-
table anchor, code-relative stop, decoded operation, operand shape or target,
and instruction length. It emits no dialogue or raw payload bytes and leaves
Content Core, instruction, and trace contracts unchanged.
Content Core `0.62.0` advances instructions to `ai5_mes_instruction/v23`, Event
Runner output to `kakyu_mes_event_trace/v25`, and the full audit to
`kakyu_mes_event_runner_corpus_audit/v14`. A direct native jump-table and
three-vtable recheck corrects the selection loop from command `0x16` to
command `0x15`. Command `0x16` now executes its native continuation-controlled
temporary argument-slot write run, while command `0x14` follows its confirmed
same-script code-coordinate target and records—but does not emulate—the native
manager context-map side effect. Event Player displays command-`0x15` common-
record counts without inventing input or result state. Audit v14 records the
reached `0x14` target chain and `0x16` slot ranges without emitting payloads.
Content Core `0.63.0` advances Event Runner output to
`kakyu_mes_event_trace/v26`, the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v15`, and the executable audit to
`kakyu_ai5_mes_exe_audit/v2`. The command-`0x1B` trace now separates the
evaluated expression record from the native vector selector derived from the
zeroed next record row. Exact one-expression rows clear native vector `0`;
other record shapes remain unsupported. Executable audit v2 adds the raw
`0x1B` route, common-record next-row read, and vector-table indexing sites.
Content Core `0.64.0` advances Event Runner output to
`kakyu_mes_event_trace/v27`, the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v16`, and the executable audit to
`kakyu_ai5_mes_exe_audit/v3`. A standalone command `0x02` reports a fail-closed
native character-stream presentation boundary, while the exact traced dialogue
trailer keeps its narrower resumable contract. The later v33 correction
separates command `0x12` into the typed-record dispatcher family.
Executable audit v3 adds command `0x02`'s dispatcher, wrapper, three-vtable
route, and single-byte stream classification sites.
Content Core `0.65.0` advances instructions to `ai5_mes_instruction/v24`, Event
Runner output to `kakyu_mes_event_trace/v28`, the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v17`, and the executable audit to
`kakyu_ai5_mes_exe_audit/v4`. Command `0x09` now executes its complete native
u16-indexed, continuation-controlled dword slot run in temporary preview call
context. Executable audit v4 locks its dispatcher, wrapper, three-vtable route,
handler write sites, and both expression-evaluator calls. The three original
telephone paths now retain slot `2 = 2` at a fail-closed shared-routine-`9`
boundary without changing gameplay state.
Content Core `0.66.0` advances instructions to `ai5_mes_instruction/v25`, Event
Runner output to `kakyu_mes_event_trace/v29`, the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v18`, and the executable audit to
`kakyu_ai5_mes_exe_audit/v5`. A single-string command `0x0E` now retains its
literal CP932 record as a native text insertion and continues without changing
gameplay state. Executable audit v5 fixes the `0x0E` dispatcher/vtable route,
record-result C-string copy, and presentation-flag update to original runtime
bytes.
Content Core `0.67.0` advances Event Runner output to
`kakyu_mes_event_trace/v30`, the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v19`, and the executable audit to
`kakyu_ai5_mes_exe_audit/v6`. Literal command-`0x10` DEF registrations now
accept any non-empty body that structurally decodes to its exact forward
target. The body is never executed; the trace retains only bounded metadata,
SHA-256, and a read-only text projection before following the native skip.
Executable audit v6 locks the original handler's target-byte assembly and
active-coordinate store.
Content Core `0.68.0` advances instructions to `ai5_mes_instruction/v26`, Event
Runner output to `kakyu_mes_event_trace/v31`, the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v21`, and the executable audit to
`kakyu_ai5_mes_exe_audit/v7`. Command `0x05` now writes continuation-controlled
byte values to isolated `global_u8` using its native expression-derived 16-bit
destination. Executable audit v7 locks the dispatcher/vtable route, evaluator
calls, initial and repeated stores, and byte/index widths.
Corpus-audit v21 is an audit-only diagnostic revision layered on that Content
Core release; it adds normalized decoder-failure grouping and bounded samples
without changing instruction or trace schemas.
Content Core `0.69.0` advances Event Runner output to
`kakyu_mes_event_trace/v32`, the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v22`, and the executable audit to
`kakyu_ai5_mes_exe_audit/v8`. Runner v32 uses a fresh execution-local native
expression stack, records each local depth and before/after depth in the trace,
and exposes empty-stack zero fallbacks in Event Player. It executes confirmed
command-`0x0A` writes to isolated `global_i32` with the original low-16-bit
destination rule. Executable audit v8 locks the `0x0A` dispatcher and three
vtable routes, all three evaluator calls, both dword stores, the `+0x3000`
base, and the 16-bit index/32-bit value widths.
Content Core `0.70.0` advances instructions to `ai5_mes_instruction/v27`,
Event Runner output to `kakyu_mes_event_trace/v33`, the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v23`, and the executable audit to
`kakyu_ai5_mes_exe_audit/v9`. Command `0x06` now decodes and executes its
expression-derived, bank-selected, continuation-controlled `banked_u8` write
run in the isolated sandbox. Executable audit v9 locks its dispatcher and
three-vtable route, destination/value evaluator calls, relative bank table,
initial/repeated byte stores, and matching expression-token-`0xC0` byte read.
Content Core `0.71.0` advances Event Runner output to
`kakyu_mes_event_trace/v34`, the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v24`, and the executable audit to
`kakyu_ai5_mes_exe_audit/v10`. Command `0x04` now applies the original
8-bit wrapping index increment to isolated `state_u16` and exposes the mask
and wrap in Event Player trace text. Executable audit v10 locks its dispatcher,
three-vtable route, initial/repeated evaluator calls and word stores, `+0x2084`
base, and `add bl, 1` wrap instruction.
Content Core `0.72.0` advances Event Runner output to
`kakyu_mes_event_trace/v35`, the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v25`, and the executable audit to
`kakyu_ai5_mes_exe_audit/v11`. Operand-free commands `0x19`/`0x1A` now expose
manager-record deltas and unresolved native-string effects without changing
the gameplay sandbox. Executable audit v11 locks both dispatcher/three-vtable
routes, 16-byte manager-vector mechanics, and both internal string-copy calls.
Content Core `0.73.0` advances Event Runner output to
`kakyu_mes_event_trace/v36`, the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v26`, and the executable audit to
`kakyu_ai5_mes_exe_audit/v12`. A default dispatcher byte carrying a confirmed
native handler family now returns the same fail-closed presentation boundary
as explicit presentation commands. Executable audit v12 exposes the already
checked native lead ranges and records `0xFF` in the non-lead single-byte
family; it adds no speculative display behavior.
Content Core `0.74.0` advances Event Runner output to
`kakyu_mes_event_trace/v37` and the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v28`. A command-`0x0D` native probe whose
payload begins with apparent branch byte `0x0B` or `0x0C` now stops before that
payload can be misread as MES control flow. This uses executable audit v12's
existing shared-handler evidence and adds no new native-rendering claim.
Content Core `0.75.0` advances Event Runner output to
`kakyu_mes_event_trace/v38` and the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v29`. Shared-routine boundaries retain the
isolated persistent-expression stack and Event Player displays its depth and
top value. The full authoritative audit finds routine 28 with an empty stack
216 times and with exactly `[2]` 297 times; no other routine-28 call-frame
shape occurs. This is diagnostic call-frame evidence only and does not execute
the indexed library body.
Content Core `0.76.0` advances the shared library audit to
`kakyu_mes_library_audit/v7`. It adds a native-dispatch CFG that follows both
branch edges and advances across EXE-bounded character-stream spans without
decoding their payload bytes as commands. Authoritative routine 28 reduces
from 71 stored-order structural rows to 41 reachable dispatcher coordinates,
47 edges, 20 native spans, and one explicit return with no graph boundary or
failure. This graph evaluates no expression, chooses no branch, executes no
nested call, and applies no state change.
Content Core `0.77.0` advances the shared library audit to
`kakyu_mes_library_audit/v8`. Native-flow rows now retain stack-effect,
branch/continuation target, literal shared-call ID, and fixed write-range
metadata. Routine 28 calls presentation-only routines 29 and 30 twice each;
its graph contains three one-byte `global_u8[0xFA0]` sites and two each at
`global_u8[0xFFA]` and `[0xFFB]`. Event Player displays these as unexecuted
graph metadata.
Content Core `0.78.0` advances Event Runner output to
`kakyu_mes_event_trace/v39` and the corpus audit to
`kakyu_mes_event_runner_corpus_audit/v30`. An explicit analysis context may
advance over one EXE-bounded native presentation span while recording omitted
effects, and may restore/return the isolated evaluator stack. Default tool runs
still stop at presentation boundaries; no gameplay save is touched.
Content Core `0.79.0` adds `kakyu_mes_library_trace/v1` and the bounded
`KakyuMesLibraryRunner`. It restores indexed caller frames across nested
command-`0x1D` calls, carries temporary arguments and the isolated evaluator
stack, uses only the explicit bounded-native analysis policy, and aggregates
sandbox-only state diffs. Original routine-28 all-zero baselines for `[]` and
`[2]` each return after eight rows with one omitted presentation span and no
state write or nested call.
The hash-bound EVENTD08 choice-route validator now composes the main MES runner
with that library runner. From its explicit detached choice coordinate and
empty temporary context, each of the three projected choices returns from
routine 28 after eight rows with no write, resumes the caller, executes a
four-row routine-27 path that writes only `banked_u16[0][1] = 2`, and stops
fail-closed at the following routine-25 command-`0x11` DEF invocation. This is
the current safe original-event continuation boundary; the native registered-
DEF call frame remains unresolved.
Event Player exposes the same bounded continuation through its Continue button,
but the complete coordinate-zero start preserves the original prefix's
temporary arguments and evaluator carry into the choice. Its first post-choice
routine-28 run therefore follows the separately validated six-row path, with
one omitted presentation span and no routine-local state diff. At each
command-`0x1D` boundary it runs the indexed library routine in the isolated
sandbox, resumes the original caller only after a confirmed library return,
and retains the library-local state diff separately from the composed caller
diff. The three EVENTD08 choices continue through routines 28 and 27, then stop
fail-closed at routine 25's native registered-DEF invocation.
Content Core `0.80.0` advances the shared library audit to
`kakyu_mes_library_audit/v9`. Native-flow rows now retain command-`0x10`
registration and command-`0x11` invocation IDs and coordinates, and each call
lists same-graph matching registration coordinates without claiming dominance
or native lifetime. Original routine 25 contains two reachable DEF-26 calls
and no local registration, which keeps Event Player's current stop mandatory.
At an indexed routine boundary, Event Player displays these registration and
invocation coordinates with same-routine match counts as graph-only metadata.
Content Core `0.81.0` advances the shared library audit to
`kakyu_mes_library_audit/v10`. Local registration matching now uses
command-`0x14` context-map coordinates, which are the native store consumed by
command `0x11`; command-`0x10` rows retain only their separate choice-body
record value and skip target. This corrects v9's overly broad linkage without
changing the fail-closed runner boundary.
Content Core `0.107.0` advances the library audit to
`kakyu_mes_library_audit/v11` and adds
`native_dispatch_flow.shadowed_structural_instructions`. Each record identifies
a row produced by lossless stored-order structural decoding whose start lies
inside an EXE-matched native-consumption span, together with the owning span and
handler family. Such a row remains visible for byte-preserving analysis but is
not a reached dispatcher command. The hash-bound routine-40 validator fixes 36
reached coordinates, 40 edges, three native spans, and ten shadowed rows. In
particular, the command-looking `0x15` rows at `LIBLARY.LIB:0x1C9A` and
`0x1CC9` are command-`0x12` character-stream payload; the reached graph has no
command-`0x15` operation. Event Player marks those rows **inside native payload;
not dispatcher** and reports the aggregate outside the `640x400` game frame.
This corrects presentation of the audit without executing routine 40's native
choice UI or effects. Audit v41 later fixes its numeric return as a one-based
selected-record index.
When a `def_selection_boundary` reaches routine 40, Event Player also places a
**Choice input provenance** record in the Summary panel outside the game frame.
Only an exact original `mes.arc` plus `LIBLARY.LIB` hash match receives the
authoritative 36-coordinate/40-edge and `0x1C9A,0x1CC9` statement. Other
resolved libraries receive only their local audit result. Every variant labels
the displayed selection as explicit tool/remake input; only the exact original
hash receives the v41 one-based result statement, while native UI/effects stay
unresolved.
Content Core `0.108.0` advances the library audit to
`kakyu_mes_library_audit/v12` and adds
`native_dispatch_flow.unreached_structural_instructions`. Stored rows absent
from the reached native graph are classified separately as native payload or
control-flow-unreached. Event Player keeps the existing payload label and adds
**not reached by native dispatch graph** for the latter. On authoritative
routine 40 this identifies one additional stored command-`0x0C` at `0x1CB5`;
it is shown outside the game frame and is not presented as an executed
transfer.
Content Core `0.109.0` advances the library audit to
`kakyu_mes_library_audit/v13`. Native-flow branch rows retain condition ASTs;
`state_u16` write rows retain destinations and unevaluated ASTs; entry-label
and vector-clear rows retain their literal values. The routine-40 original
validator binds the resulting slot-18/21/13 control envelope, routine-20 call,
and record values `1..17`. Event Player shows that script envelope as a second
**Choice input provenance** line outside the game frame, while explicitly
leaving native slot production and gameplay meanings unresolved.
At a routine-40 DEF selection boundary, Event Player also fills a dedicated
**Routine 40 Audit** result tab from the same indexed `LIBLARY.LIB` body. The
game frame continues to contain only the projected original presentation and
explicit tool choices; stored-order rows, native-payload shadows, the
both-branch graph, and the control-flow-unreached row remain outside it. The
panel is labeled `choice_provenance` and is graph metadata only: opening or
displaying it does not execute routine 40 or mutate sandbox state.
Content Core `0.110.0` advanced the shared library audit to
`kakyu_mes_library_audit/v14`. Each native dispatch span now separates its
dispatch coordinate, payload start/end, consumed byte count, content byte
count, and whether a terminating NUL was consumed. The authoritative
routine-40 envelope is three spans: command `0x12` at `0x1C95` has seven
content bytes plus NUL; command `0xFF` at `0x1C9E` has empty content plus NUL;
command `0x12` at `0x1CC4` has ten content bytes plus NUL. Event Player reports
those coordinates in Summary and retains the full records as metadata in the
**Routine 40 Audit** tab, without copying payload bytes or simulating their
rendered/cursor effects. Executable audit v28 retains the shared-handler byte
evidence but also shows that normal script-manager byte ingress intercepts
command `0x12` before the generic table and enters the typed-record parser/
dispatcher path.
For the exact original archive/library hashes only, the same Summary now also
shows executable audit v41's selected slot-18 writer envelope. It names the
0/1 literal writers, record-dispatch cases 20 through 23, and the existence of
independent non-unique writers, and the confirmed command-`0x12` record ingress
while fixing helper mode 1's selected result as a one-based record index and
its empty-list result as `0xFFFF`. Selected-intro execution and the original
presentation/effect loop remain unresolved. Modified/resolved content does not
inherit this original-EXE statement.
Content Core `0.111.0` corrects that v14 interpretation and advances the
instruction, library-audit, Event Runner, and Library Runner schemas to
`ai5_mes_instruction/v33`, `kakyu_mes_library_audit/v15`,
`kakyu_mes_event_trace/v50`, and `kakyu_mes_library_trace/v3`. Command `0x12`
now consumes a complete typed record list through its zero list terminator.
This removes the false routine-40 boundary at `0x1C9E`: the authoritative
spans are `0x1C95..0x1CA0` and `0x1CC4..0x1CD0`, each with three expression
records. The corrected graph has 35 coordinates, 39 edges, two record spans,
no native-payload shadow rows, and one separately control-flow-unreached row at
`0x1CB5`. Event Player shows record counts and exact extents outside the game
frame. Default execution stops at `native_record_boundary`; only an explicit,
bounded tool action records `native_record_effects_omitted` and resumes at the
decoded instruction end. Library trace v3 reports record omissions separately
from character-stream presentation omissions. Original executable audit v28's
`0x12` remap, `0x0043E800` typed parser, `+0x74` dispatch route, and
`0x00414CA0` record dispatcher independently support this correction. Record
side effects, native input timing, and routine-40 presentation remain
unresolved; audit v41 separately confirms its one-based selected-record result
encoding. This
supersedes v11-v14's character-stream span and shadow-row counts.
Content Core `0.112.0` advances Event Runner and Library Runner output to
`kakyu_mes_event_trace/v51` and `kakyu_mes_library_trace/v4`. An explicit
`native_stream_policy=skip_bounded` request now actually resumes command
`0x02` at its decoded bounded-stream end. The previous runner path recorded the
omission but then overwrote it with the same fail-closed boundary, so composed
library/event previews could not make progress. The corrected path preserves a
deferred primary double-byte lead for the normal text decoder and still changes
no sandbox state. The default policy remains a visible native-presentation
stop. Synthetic control-flow tests lock both cases, while executable audit v28
remains the independent source for single-byte consumption and primary-lead
deferral; native rendering and cursor effects are not simulated.
Corrected audit `kakyu_mes_definition_registry_audit/v2` expands that check to
all 1,016 authoritative MES/LIB entries and separates the two native stores.
It accepts 1,154 literal command-`0x14` context registrations and locates the
single DEF-26 registration at `DEF_MAIN.MES:0x01FC`, body `0x0203..0x042D`.
The two calls remain `LIBLARY.LIB:0x1E22` and `0x1F2E`. The 3,567 canonical
command-`0x10` rows are choice-definition bodies, not context-map keys.
Executable audit `kakyu_ai5_mes_exe_audit/v16` retains v15's independently
fixed command-`0x14` manager-map lookup/replacement/insertion and command-`0x11`
lookup, temporary swap, virtual script call, and restore sites. The body and
skip bounds are confirmed, but the registration lifetime at an isolated intro
and the invoked-body call frame remain unresolved, so routine 25 still stops.
Content Core `0.82.0` adds `kakyu_mes_context_index/v1`. The index accepts only
caller-supplied, previously audited code-relative command-`0x14` coordinates;
it validates the literal selector and exact forward body/skip bounds and does
not scan arbitrary payload bytes or claim that a coordinate is reachable.
The hash-bound original validator supplies `DEF_MAIN.MES:0x01FC`, confirms
selector `26` and body `0x0203..0x042D`, then probes only the body's first safe
runner boundary. That probe stops at command `0x12` at `0x0208` with two trace
rows, no dialogue, and no sandbox state diff. It does not continue through the
native presentation command or use the result to enable routine-25 execution.
A separate analysis-only run applies the existing `skip_bounded` policy only
to EXE-bounded, NUL-terminated presentation spans. It reaches the body return
at `0x042C` with exactly 54 trace rows: 21 source-line markers, 32 omitted
presentation spans, and one return. It produces no dialogue projection and no
sandbox state diff. Event Player reports this outside the game frame but does
not invoke the body or synthesize the missing native presentation effects.
Content Core `0.83.0` advances Event Runner output to
`kakyu_mes_event_trace/v40`. A default command-`0x12` boundary whose shared
native probe consumed a terminating NUL now returns its exact probe-end offset,
temporary arguments, evaluator stack, and the explicit resume policy
`native_presentation_effects_omitted`. Event Player accepts that continuation
only after the user starts the hash-bound original DEF26 isolated-body anchor;
one Continue uses `skip_bounded` for the remaining spans. Other boundary types,
non-NUL probe stops, overlays, and routine-25 command-`0x11` remain fail-closed.
Content Core `0.84.0` advances the bounded library runner to
`kakyu_mes_library_trace/v2`. Its default remains unchanged: a command-`0x11`
without an explicit registered body stops at
`library_definition_invoke_boundary`. A caller may instead provide a bounded
selector-to-body map produced by the shared context index. The runner executes
that external body with `skip_bounded`, labels every external trace row with
its DEF ID/source, requires a script return inside the supplied bounds, then
resumes at the exact command-`0x11` end while retaining nested library frames,
arguments, evaluator stack, and sandbox diffs. It never discovers registration
lifetime or selects an unaudited body on its own.

Content Core `0.87.0` advances instruction output to
`ai5_mes_instruction/v28`, Event Runner output to
`kakyu_mes_event_trace/v42`, and the exhaustive runner audit to
`kakyu_mes_event_runner_corpus_audit/v32`. Safe ASCII `*.MES` records in
command `0x0E` are now retained as `script_handoff_marker` boundaries rather
than rendered as dialogue. The boundary exposes the safe target and native
active-string change, performs no gameplay-state write, and deliberately does
not execute the unresolved host consumer. The corpus audit groups reached
handoff targets, source entries, missing archive targets, and bounded samples.

Content Core `0.88.0` advances Event Runner output to
`kakyu_mes_event_trace/v43` and the exhaustive runner audit to
`kakyu_mes_event_runner_corpus_audit/v33`. Command `0x18` now evaluates its
selector and transfers through a caller-supplied active MES address table. Missing tables,
out-of-range indexes, and out-of-bounds table coordinates stop with distinct
diagnostics. Event Player supplies only the address table of its currently
parsed document. This does not infer the unresolved host-side selector for the
catalog-shaped EVENTD06/EVENTD14 scripts and does not enable either as a
one-click event route. The complete v33 read-only replay covered all 1,015
executable MES entries and 133,459 indexed intros: 969,789 trace rows, no
fatal/decode/invalid/unsupported failures, and zero reached `0x18` dispatches.
That zero applies only to the isolated address-entry starts and does not resolve
the native host selector.

Content Core `0.89.0` adds `kakyu_mes_caller_route/v1`. The shared caller-route
contract accepts a caller bytecode buffer plus explicit, hash-bound coordinates
for one nested-script dispatch, one date-selected BGM prefix, and one terminal
handoff suffix. It requires the decoded command-`0x0F` target and physical
resume, exact lowercase filename envelope, prefix and suffix SHA-256 values,
one explicit default BGM route, zero prefix state changes, the declared
command sequence and isolated state writes, and the exact command-`0x0E`
handoff target. Any shifted coordinate, changed hash, extra/missing BGM request,
state mismatch, or target mismatch fails closed. Event Player supplies the
separately audited EVENTD01, EVENTD02, and EVENTD03 specifications and retains
original-ARC resolver/hash checks outside the bytecode contract. Those three
routes now share this core validator and executor rather than duplicating MES
format logic in each event UI path. The schema stores no original bytecode or
dialogue and does not execute the native host consumer.

Content Core `0.100.0` advances instruction output to
`ai5_mes_instruction/v32`, analysis output to `kakyu_mes_analysis/v8`, Event
Runner output to `kakyu_mes_event_trace/v48`, and the exhaustive runner audit
to `kakyu_mes_event_runner_corpus_audit/v37`. The shared decoder now consumes
the complete EXE-v22-confirmed presentation subcommand-4 / selector-13 typed
record as one `named_state_transfer` instruction. It retains the snapshot
selector, `A..Z`/`_A.._Z` mapping slots, and the confirmed offset-only scope.
Event Runner fails closed at `native_state_transfer_boundary`; MES Editor and
Event Player display the mapping outside the logical game frame without
loading a native record or mutating sandbox state.

The hash-bound `kakyu_mes_presentation_state_transfer_audit/v1` finds exactly
five original envelopes: four in `43C.MES` and one in `OPEN.MES`. Every record
uses snapshot selector `state_u16[25]` and mapping `HTE`; no original envelope
in this set names `Z`. The 1,016-entry analysis corpus remains free of fatal
failures, and the 133,459-anchor v37 runner corpus retains 969,760 traced steps,
zero decode/unsupported/invalid failures, and no newly executable host-state
path. This is read-only metadata coverage, not bank-alias emulation.

Content Core `0.99.0` advances the bounded registered-definition runner to
`kakyu_mes_registered_definition_trace/v2`. It keeps an explicit caller-frame
stack, so a mapped DEF may invoke another mapped DEF and return through both
the body and root continuation. Every call records its caller selector and
depth; independent total-call, depth, and instruction limits fail closed.
Missing mappings and shared-library boundaries still stop without inference.

Content Core `0.115.0` advances the shared single-body and recursive contracts
to `kakyu_mes_registered_definition_call/v2` and
`kakyu_mes_registered_definition_trace/v3`. This carries the corrected
command-`0x12` typed-record boundary through both composition layers. Root and
registered-body execution have separate caller-supplied
`native_record_policy` and `registered_definition_native_record_policy`
settings; both default to `stop`, while only explicit `omit_bounded` analysis
may cross a complete decoded record list. Results count
`native_record_effects_omitted` separately from character-stream presentation
omissions. No native record side effect is synthesized.

Content Core `0.157.0` advances the recursive trace to
`kakyu_mes_registered_definition_trace/v5` and adds
`kakyu_mes_registered_definition_continuation/v1`. When execution pauses on
dialogue inside an explicitly mapped DEF, the continuation binds the root
bytecode, registered-body identities and bounds, active root/DEF frame stack,
command-`0x11` call/resume coordinates, counters, and temporary argument and
evaluator context. Resume accepts only the same registered map, re-decodes each
active caller site, and rejects changed bytes, missing bodies, malformed
frames, shifted resumes, and tighter call/depth limits before execution. The
contract remains in-memory, sandbox-only, and fail-closed at native or unmapped
boundaries; it does not infer native DEF selection.

Content Core `0.158.0` adds
`kakyu_mes_library_continuation/v1` and advances the library trace to v7. When
an indexed root or nested shared routine reaches a confirmed dialogue trailer,
the result retains the library SHA-256/index binding, the active routine and
exact trailer resume, every active command-`0x1D` caller frame, and temporary
argument/evaluator state. The runner revalidates the complete source/index and
each active call site before resuming and unwinds nested routine callers in
LIFO order. Its new Event Runner v62 policy omits other bounded native
character streams but checks the exact dialogue-trailer shape first, avoiding
the previous analysis-only behavior that consumed dialogue as presentation.
This continuation remains in memory, is not an authored/cache format, and does
not yet compose a dialogue-bearing registered DEF nested inside the library.

Event Player consumes this continuation as an ordinary library-dialogue
`Continue` action. In addition to the core library source/index and call-frame
checks, the controller records the selected MES entry identity, bytecode hash,
code size, and physical caller resume. It resumes the library first and returns
to the MES caller only after the complete library frame finishes. A changed
library or caller is rejected before further sandbox execution. This is a
generic controller path; catalog routes still require their own confirmed
activation and completion evidence.

Event Player also adopts
`kakyu_mes_registered_definition_continuation/v1` for an audited root-MES
command-`0x11` boundary. It preserves the selected root bytecode, code range,
address table, explicit registered-definition snapshot, argument slots, and
evaluator carry. A visible DEF dialogue pauses before caller restoration;
`Continue` revalidates the DEF call stack and finishes the body before returning
to the exact root coordinate. Changed root or registered-body bytes are rejected
before further sandbox execution. Generic native streams in the DEF remain
fail-closed; their effects are not invented to reach later dialogue.

Content Core `0.159.0` advances library traces to
`kakyu_mes_library_trace/v8` and continuations to
`kakyu_mes_library_continuation/v2`. When a command-`0x11` body invoked from a
root or nested shared routine reaches dialogue, v2 embeds the active
`kakyu_mes_registered_definition_continuation/v1` beside the library routine
and command-`0x1D` caller frames. Resume first revalidates both source-binding
sets, completes the active DEF stack, completes the current routine, and then
unwinds outer routine callers in LIFO order. A changed library/index,
registered body, command-`0x11` caller, or command-`0x1D` caller rejects the
whole continuation before caller restoration. Non-dialogue registered bodies
retain the preceding bounded execution path; unresolved native streams remain
explicit stop boundaries for the mixed dialogue path.

The hash-bound startup-definition audit advances to v2. The 91 selector-11
bodies all invoke selector 12 at `DEF_MAIN.MES:0x048F`, producing 201 total
calls across the same 103 entries. None of those selector-12 paths completes
within the 2,000-row per-entry analysis limit: 51 stop at `0x04DC`, 14 at
`0x04E8`, and 26 at `0x04F0`. The seven selector-22 paths still stop at shared
routine 3 and five selector-23 caller continuations still stop at root routine
28. This is an explicit unresolved loop/state boundary, not an event-complete
result, and remains unavailable in Event Player.

Audit v3 identifies why the selector-12 runs do not finish in a zeroed tool
sandbox. The body initializes cursor `state_u16[1]`, rewrites
`state_u16[25]` as a relative offset into a bank-zero row, then tests
`banked_u8[25][state_u16[1]] != 15` at `0x04DC`, increments the cursor at
`0x04E8`, and returns to the test through `0x04F0`. All 91 paths therefore
repeat `0x04DC -> 0x04E8 -> 0x04F0` because the isolated bank 25 contains no
aliased bank-zero bytes or host-populated sentinel `15`. The audit structurally
revalidates the AST and exact transition/write/condition distributions without
printing expression bytes. Executable audit v22 confirms that native token
`0xC0` treats the rewritten slot as a relative address, while command-`0x04`
audit v2 finds the exact slot-25 writer. This turns the earlier generic step
limit into an identified missing host-state/physical-alias dependency; it
still does not authorize a fabricated sentinel.

Content Core `0.98.0` adds
`kakyu_mes_registered_definition_trace/v1`. The bounded runner executes a
selected MES range in a caller sandbox, resolves command-`0x11` only from an
explicit validated registry, invokes the shared single-body primitive, and
resumes at Event Runner's exact v47 continuation coordinate. It aggregates
caller/body traces and state diffs while enforcing step and call-count limits.
Native presentation omission for a body remains a separate explicit policy.
The first contract is deliberately one body deep: a nested DEF invocation or
shared-library call inside that body remains a visible boundary rather than a
recursive guess.

The hash-bound `kakyu_mes_startup_definition_calls_audit/v1` applies that
one-level contract to entry zero of all 1,015 original MES entries. It finds
103 entries and 110 explicit calls after caller continuation: selector 11 at
91 calls, selector 23 at 12, and selector 22 at seven. All selector-11 bodies
stop at their nested selector-12 invocation; seven selector-22 bodies stop at
shared routine 3, while five selector-23 callers next stop at root shared
routine 28. No message is fabricated and the archive remains unchanged. These
boundaries are analysis evidence only and are not enabled as Event Player
continuations.

Content Core `0.97.0` adds
`kakyu_mes_registered_definition_call/v1`. The shared primitive accepts one
explicit selector/body mapping, validates its code bounds, runs only inside a
caller-supplied sandbox, and returns argument slots, persistent expression
stack, state diff, and externally labelled trace rows. Native presentation
effects stop by default; only an explicit `skip_bounded` analysis policy may
omit EXE-delimited spans. `KakyuMesLibraryRunner` now delegates its registered
DEF body work to this primitive instead of carrying a second implementation.
The primitive never discovers a registry, grants startup inheritance, or
serializes source bytecode.

Content Core `0.96.0` advances Event Runner output to
`kakyu_mes_event_trace/v47` and the exhaustive corpus audit to
`kakyu_mes_event_runner_corpus_audit/v36`. A command-`0x11` registered-DEF
boundary remains fail-closed, but now returns the exact post-record resume
coordinate together with copies of its temporary argument slots and persistent
expression stack. The resume policy is explicitly
`registered_definition_call_restore`, matching executable audit v21's native
lookup, stored interpreter-pair swap, body call, and prior-pair restoration.
No body lookup or execution occurs in Event Runner; a later bounded compositor
must still receive an explicit validated registry.

Content Core `0.95.0` adds runtime-only projection
`kakyu_mes_startup_context/v1`. Given one parsed startup-definition document,
it runs coordinate zero in a fresh sandbox and accepts only source-line markers,
manager-internal vector clears, command-`0x14` transfers, ordinary fallthrough,
and a confirmed return. Dialogue, gameplay diff, unknown effects, malformed
bounds, or duplicate selectors fail closed. Every reached coordinate is
revalidated through `kakyu_mes_context_index/v1`; the result retains body bounds
and source bytecode only in memory for explicit `KakyuMesLibraryRunner` calls.
It labels itself non-serializable authored/cache data and does not execute any
registered body during projection. The original startup-context audit consumes
this shared result and fixes its 14-entry contract.

Content Core `0.129.0` advances this projection to
`kakyu_mes_startup_context/v2`. The top-level source identity is now copied to
each registration and runtime-only registered-body mapping as `source_entry`.
This is provenance only: it does not serialize source bytecode, discover a
registry, execute a body, or broaden startup inheritance.

Content Core `0.94.0` advances instruction output to
`ai5_mes_instruction/v31`, analysis output to `kakyu_mes_analysis/v7`, and
Event Runner output to `kakyu_mes_event_trace/v46`. The shared decoder now
recognizes only the complete subcommand-8 typed-record envelopes confirmed by
audit v21: selector 2 requires a safe `.LIB` ARC entry name and selector 3 a
safe `.MES` name. Both become `inline_script_execution` records with their
execution role and confirmed native context restore. The analysis index exposes
them as `mes_script` references to `mes.arc`, so MES Editor displays readable
targets instead of filename payload bytes. Event Runner reports
`native_script_execution_boundary` and does not load or execute the target in
an isolated sandbox. Event Player renders the target, selector, and bootstrap
role in its game-frame explanation and labels the native load/execute/restore
contract as confirmed while clearly stating that the isolated preview stopped
before execution. The hash-bound original validator confirms the two START.MES
coordinates and source immutability. A full original-archive analysis finds
exactly two `mes_script` references across 1,016 MES/LIB entries; the exhaustive
133,459-anchor runner audit retains zero fatal failures.

The separate `kakyu_mes_startup_context_audit/v1` follows the hash-bound
`DEF_MAIN.MES` zero-start path after the confirmed START handoff. It indexes 14
reached command-`0x14` registration bodies in original order and requires the
42-row path to return with no dialogue or gameplay-state diff. The audit is
paired with executable audit v21 when the optional original launcher is
supplied and consumes the shared startup-context projection.

Event Player may load that projection only when `mes.arc`, `START.MES`,
`LIBLARY.LIB`, and `DEF_MAIN.MES` match the audited original hashes and every
entry resolves from `original_arc`. It reports the 14-entry read-only index
outside the 640x400 game frame. The map is supplied only to the already
hash-bound EVENTD08 shared-library continuation; routine 25 then requests
selector 26 through the normal `KakyuMesLibraryRunner` contract. The other
registered bodies remain indexed but unexecuted. An overlay of any startup
component, a changed archive, an arbitrary intro, or any route without the
existing explicit continuation remains fail-closed and receives no projected
registry.

Content Core `0.93.0` retains the `0.91.0` instruction, analysis, and Event
Runner schemas while advancing the native MES audit contract to
`kakyu_ai5_mes_exe_audit/v21` and adding
`kakyu_mes_startup_bootstrap_audit/v2`. Event Player now distinguishes the
confirmed original `START.MES -> LIBLARY.LIB -> DEF_MAIN.MES` execution and
owning-script-manager lifetime of command-`0x14` registrations from an isolated
tool preview that does not replay that bootstrap. It continues to load the
hash-bound DEF-26 body explicitly rather than silently assuming that the
registration is active.

Content Core `0.92.0` established the owning-script-manager lifetime of the
native context registry while leaving the startup execution contract
unresolved.

Content Core `0.91.0` advances instruction output to
`ai5_mes_instruction/v30`, analysis output to `kakyu_mes_analysis/v6`, and
Event Runner output to `kakyu_mes_event_trace/v45`; the exhaustive runner
audit advances to `kakyu_mes_event_runner_corpus_audit/v35`. A voice record now begins
at the outer native presentation-control byte `0x0D`; the following `0x07` is
nested presentation subcommand 7 rather than an ordinary banked-word command.
The typed record retains queue selector `2`, safe ASCII `.ogg` name, terminal
value `0`, and the EXE-confirmed selector-3 stream-advance route. Instruction
and trace records expose
`native_consumer_semantics: presentation_queue_and_stream_handoff_confirmed`,
`native_audible_output: confirmed_directsound_play_dispatch`,
`native_audible_evidence: static_executable_rtti_vtable_and_idirectsoundbuffer_abi`,
`native_host_device_output: not_observed_by_static_audit`, and
`tool_preview_semantics: godot_only`. The marker changes no sandbox state.
Event Player presents those three boundaries separately outside its 640x400
game frame.

Audio audit v7 binds the runtime object's RTTI name
`Cai5OggWaveThread` to vtable `0x0047AE3C`. Its `+0x78` Ogg handoff resolves to
`0x0040D2A0`, while the following `+0x28` call resolves to common audio start
method `0x0040E730`. That method uses DirectSound-buffer ABI slots `+0x2C` and
`+0x4C` for Lock/Unlock and invokes slot `+0x30` at `0x0040E8B1` with
`(0, 0, 1)`, matching `IDirectSoundBuffer::Play` with the looping flag. This
is static dispatch evidence, not an observation of mixer or speaker output.

Analysis v12 accepts the complete EXE-audited safe ASCII Ogg-name grammar rather
than v20's historical one-letter numeric subset. A direct read-only pass over
all 1,016 authoritative MES/LIB entries retained 2,262,909 strict-prefix
instructions, 219,980 message records, 150,609 code references, 464,553 state
references, and 36,149 resource references with zero container/index fatal
failures. Resource totals are 2,433 AX, 7,645 MMO, 26,069 voice, and two nested
MES script references; 27,705 begin at strict-indexed instructions and 8,444
are bounded byte-envelope scans.
The source archive fingerprint remained unchanged.

The v35 exhaustive read-only replay covered all 1,015 executable MES entries
and 133,459 indexed intros. It retained 969,760 trace rows and 291,658 message
records with no fatal, decode, invalid-write, invalid-target, or unsupported
failures. Voice presentation rows now use their native outer boundary; 51
starts reach an explicit script return and 131,805 reach a dialogue boundary. No active-table
`0x18` dispatch was reached from these isolated starts.

Content Core `0.86.0` keeps the existing Event Runner schemas and moves the
strict-CP932 promotion gate into overlay publication as well. A text projection
batch now reparses each authoritative source entry and rejects the whole batch
before creating payloads when any bound message row is native presentation
data rather than valid CP932 dialogue. This makes the MES Editor UI rule a
shared writer invariant for future clients.

Content Core `0.85.0` advanced Event Runner output to
`kakyu_mes_event_trace/v41` and the exhaustive runner audit to
`kakyu_mes_event_runner_corpus_audit/v31`. A double-byte native presentation
pair must now pass the shared strict CP932 codec before Event Runner may emit it
as human-readable dialogue. Invalid pairs remain lossless decoder/audit rows;
default execution stops at their native presentation boundary and explicit
bounded analysis records them as omitted presentation effects. The triggering
authoritative row is `LIBLARY.LIB:0x0405` (`8F 01 FF...`) in routine 21. The
original EXE's audited paired-character handler consumes `8F 01` as one native
pair but does not validate the trail as CP932, so the tool neither invents a
glyph nor displays an encoding error inside the game frame. MES Editor applies
the same promotion gate: its lossless analysis row remains searchable by raw
hex but cannot accept a cached, overlay, or newly staged dialogue projection.
Event Player's result-message resolver also decodes the bound source bytes
before consulting cache or overlay text, so a stale or externally authored
projection cannot bypass the game-frame rule.

The hash-bound original composition validator maps selector `26` to
`DEF_MAIN.MES:0x0203..0x042D` and runs routine 25 with argument slot `1 = 120`.
It returns at `LIBLARY.LIB:0x2018` after 69 rows, of which 54 are external DEF
rows, omits zero character-stream presentation spans and 36 typed-record
dispatch effects, and changes only isolated
`global_u8[3000]` from `0` to `4`. This establishes that explicit root path;
the alternate call at `0x1F2E`, native rendering, and registration lifetime
remain separate boundaries.
When Event Player reaches routine 25 from the hash-bound authoritative
`mes.arc` and the resolved `LIBLARY.LIB` is still `original_arc`, its Summary
tab resolves `DEF_MAIN.MES` through Content Core, requires it to remain the
audited original entry, and shows the single registration/body, both LIBLARY
calls, the bounded `0x0203 -> 0x0208` first stop, and the 54-row
record-effects-omitted body audit outside the 640x400
game frame. The note is withheld for a different archive hash or an
overlay-provided library/DEF entry. At the first routine-25 DEF26 stop it also
enables a second explicit Continue. That action supplies only the audited
selector/body map, composes 54 external DEF rows, returns routine 25 after 69
rows with 36 omitted record dispatches, and resumes EVENTD08 in the sandbox. The next main-
script boundary is routine `21` at `0x0AA0`; continuing it reaches routine
`32` at `0x0AC7` while retaining the invalid native pair as omitted
presentation evidence. A further Continue executes routine 32's
11-row path, including nested routine 31 and four omitted spans, then reaches
routine 28 at main coordinate `0x0AD7`. The final Continue executes routine
28's eight-row path with one omitted span and reaches the EVENTD08 script
return at `0x0AE6`. That exact return enables one more explicit, hash-bound
Continue into `12C.MES`: it resumes the caller at `0x0FB6`, executes the
selector-zero reset, stops at the verified `D_PIC.MES` call at `0x0FCB`,
substitutes only the separately audited `D.MMO` restoration, and continues
caller bytecode at `0x0FD8`. The preview no longer treats that standing sheet
as an opaque background. It resolves the current sandbox HHMM through the
confirmed `TIME_C.MES` bands to a `12C_1/2/3.MMO` background, then places the
unmodified `D.MMO` RGB image in the shared foreground layer with the shared
soft green-key material. Resource names, HHMM projection, and the unresolved
native compositor are reported outside the 640x400 game frame. All three
choices reach their distinct first
caller-owned dialogue rows. Their remaining caller dialogue requires 8, 6, and
14 explicit Continue actions, converges on `0x1984` and `0x19D7`, writes the
confirmed completion flag `global_u8[756] = 1` at `0x19E9`, and stops at the
exact command-`0x0E` `MACHI.MES` handoff marker at `0x1A18`. The completion
screen requires that hash-bound target/offset/flag combination and says the
host consumer was not executed; it no longer claims a later script return.
Generic nested-script execution, the rest of
`D_PIC.MES`, and the caller above `12C.MES` remain unavailable.
When this exact EVENTD08 session reaches that hash-bound caller handoff, the
last dialogue footer says `EVENT COMPLETE` instead of advertising another
unqualified next action. One more click, Space, Enter, or Right Arrow replaces
the dialogue with an explicit completion screen; Left Arrow restores the last
dialogue. This is tool UI state only: it does not write another sandbox value,
stop retained BGM, touch a gameplay save, or generalize an arbitrary MES
`script_return` into a completed event. Direct scripts whose caller is not
confirmed retain the existing `caller is not simulated` result.
The tool displays all omitted effects and state diffs outside the game frame.
Nothing is enabled for a hash/overlay mismatch, and no gameplay save is
changed. Whenever one of these bounded continuations is available and no
dialogue or choice is currently displayed, a click inside the game frame or
Space, Enter, or Right Arrow invokes the same sandbox-only action as the
desktop Continue button; the footer advertises that input at shared-routine
and audited-DEF boundaries.

The six hash-bound `D_PIC.MES` inspection anchors are also presentation-role
aware. Running `D.MMO`, `D5.MMO`, or `D1..D4.MMO` directly clears any stale
background and shows the decoded image only in the shared keyed foreground
layer. Because a `D_PIC.MES` anchor does not identify its caller's local
background, the outside-frame diagnostic explicitly says `standing-only` and
`caller background unresolved` instead of inventing a composition.
Instruction v18 distinguishes the exact
confirmed command `0x0E` protagonist-name insertion from unresolved record
forms; trace v16 records whether the tool-only preview value was resolved.
Instruction v18 renames command `0x1C` from the earlier provisional
`call_like_transfer` label to confirmed `library_register_skip`. The shared
library index follows only literal forward skip registrations from the
zero-entry-table `LIBLARY.LIB` bootstrap, rejects duplicate IDs, nonliteral
keys, backward/out-of-range targets, unexpected top-level commands, and a
missing terminal return, and retains body bounds without decoding or executing
the bodies. The authoritative hash-bound integration check indexes 43 routines
and fixes routine `23`, `28`, and `40` bodies at `0x05A8..0x0E18`,
`0x02D0..0x03EB`, and `0x1C8E..0x1D67`.
Trace v16 adds the decoded literal `routine_id` to command-`0x1D` records,
including unsupported stops; nonliteral forms retain `-1`. Clients can
therefore resolve an exact literal boundary against the separate library index
without pretending to execute the shared body.
Library audit v6 labels its whole-body `linear_stack_effect` scope as stored
structural instruction order rather than a CFG path and also splits that order
at every explicit command-`0x00` return. Each return-delimited segment has
independent bounds, structural-only count, return status, and stack effect.
This prevents instructions after an earlier return from being silently folded
into a path-like stack claim while preserving all bytes for read-only analysis.
Event Player consumes this shared v6 audit at an indexed routine boundary and
prints each return-delimited range with its minimum incoming stack and delta.
The UI labels the ranges as stored-order diagnostics rather than CFG paths;
they remain read-only and are not supplied to Event Runner. Audit v6 also
retains every unresolved native stream-dispatch token in a separate list and
marks each return-delimited segment with its first such token. Each token also
carries its EXE-matched single- or double-byte consumption probe. Rows after that
coordinate remain stored-order diagnostics because those local probes do not
by themselves reconstruct the enclosing control-flow path.
Event Player labels every such row as a native stream boundary and shows its
consumed-byte count, stop coordinate, and stop reason without executing it.
Instruction v18 also probes the EXE-matched double-byte handler used by
command `0x01` and lead-dispatch text. A zero-character `01 FF` is retained as
a one-byte native token rather than a false message; lead-dispatch text ending
at deferred `FF` retains only the consumed character pair. The audit retains
whether a text projection ends at the same NUL or deferred marker. Event Player
displays decoded Japanese text together with `matches probe` or `crosses probe
stop`, and explicitly labels an empty command-`0x01` boundary; none extends
Event Runner.
Library audit v7 preserves this v6 stored-order view and adds
`native_dispatch_flow` beside it. The flow is deliberately graph-only: branch
conditions are not evaluated, and unresolved jump tables become explicit
boundaries rather than guessed fallthroughs. Native probe spans determine the
next dispatcher coordinate, preventing bytes already consumed by the original
handler from appearing as reached MES opcodes.
The headless corpus validator aggregates the two native handler families and
projection mismatches without writing original dialogue or payload bytes.
Against the hash-bound original archive it found 888,437 probes (666,962
single-byte and 221,475 double-byte), including 221,474 matching double-byte
boundaries and one retained non-FF mismatch, with zero fatal decode failures
and an unchanged source hash. It also reports double-byte projections by
instruction kind, deferred-byte histogram, and consumed-character histogram
without emitting dialogue or raw payloads.
Instruction v18 additionally names operand-free commands `0x19`/`0x1A`
`internal_record_push`/`internal_record_pop`. Their native handlers save and
restore the manager's active internal string through a 16-byte-record vector;
the runner does not emulate that manager state. Instruction v18 replaces command
`0x0A`'s provisional fixed grammar with the
EXE-confirmed dynamic `global_i32` destination plus repeated
value-expression/continuation pairs. Strict-invalid expressions remain decoder
stops and are never executed. Its separate structural API retains terminated
non-singleton expressions, marks their instructions `structural_only`, and is
used only for read-only inspection. The shared stack-effect record reports the
ordered isolated expression depths, minimum required incoming persistent stack,
and net delta for one instruction or a sequence; MES Editor, Event Player, and
headless audits must consume this Content Core result rather than implement
their own stack arithmetic. The record is diagnostic only and never supplies a
missing stack value to Event Runner. The original EXE confirms that evaluator
entry `0x00405F10` does not clear its object-owned dword vector and that the
`0xFF` path pops exactly one result through `0x00406780`. Consequently the v2
command-`0x0A` audit also reports minimum incoming persistent-stack depth and
net stack delta; it does not synthesize the unknown incoming stack for an intro
anchor. The post-v18 authoritative rescan exposes 50 aligned rows rather than
the pre-split 46; all remain structural-only, and the seven `LIBLARY.LIB` rows
still require one incoming carried value. Instruction v18 also replaces command `0x04`'s provisional fixed
shape with the native byte start index plus repeated expression/continuation
write run. Event Runner writes strict-valid results sequentially to
`state_u16`, so a later expression in the same run observes earlier writes,
and rejects any run that would exceed index `255`. The archive-wide candidate
audit deliberately separates strict-valid rows from structural-only aligned
rows; it never treats tolerant expression recovery as executable input.
Instruction v18 names operand-free command `0x0D`
as `statement_separator` and records
`native_handler_family=character_stream_presentation` for commands `0x02`,
`0x0D`, and `0x12`, together with
`native_stream_consumption=single_byte_run_until_nul_or_primary_double_byte_lead`.
The shared probe records how many subsequent bytes the native loop consumes,
whether it consumed NUL, deferred a primary double-byte lead, or reached its
decode limit, and the exact stop coordinate. Ordinary non-lead bytes above
`0x1F` carry the same metadata because the outer dispatcher routes them to the
same handler. The original executable routes all three through one
nontrivial character/cursor presentation handler. Commands `0x02` and `0x12`
therefore stop at explicit fail-closed native presentation boundaries, while
`0x0D` remains only a structural fallthrough with omitted native presentation
effects. Trace v27 retains the native handler family on every
affected record and keeps the `0x0D` boundary with no sandbox-state effect.
Instruction v18 also keeps the fixed five-byte
command `0x1F` as `source_line_marker` and types its retained u32 operand as
`source_line`; trace v16 records that value while applying no sandbox-state
effect. Instruction v18 additionally distinguishes exact `13 FF` as
`message_cursor_no_advance`; trace v16 falls through with no sandbox-state
effect while all other command `0x13` operands remain numeric and unsupported.
When that trace follows decoded dialogue and the next four bytes are exactly
`02 02 FF 00`, trace v16 returns a successful `dialogue_boundary`, physical
continuation offset, and temporary argument-slot snapshot. The same bytes
outside this bounded context remain unsupported.
The Event Runner executes native command
`0x03` `global_u8` and command `0x04` `state_u16` write runs, with the former's
`0..15` clamp, and command `0x07`
`banked_u16` plus command `0x08` `banked_i32` write runs with an expression
destination, static bank, and sequential value evaluation. All report isolated state diffs and reject
unsafe preview indices. The Python `ai5_mes_basic_block_ir/v6` generator
retains the complete repeated operands; runtime execution remains
GDScript-only. Instruction v16 and trace v16 retain the exact safe `.MMO`
resource name for a bounded filename marker while carrying explicit unresolved
native-consumer status and applying no inferred `0x09` state write. The current
instruction v24 also executes regular command `0x09` records using the
EXE-confirmed u16 starting slot and continuation-controlled expression run. It
recognizes the directly audited literal argument-slot-1 command `0x09` followed
by single-literal shared routine `23`,
and emits the selector plus authoritative BGM-table filename as a read-only
presentation request. Trace v15 also retains routine `0`'s preceding literal
slot-1 value as `message_record_id` at the directly audited post-dialogue call
sites. Other `0x1D` contexts beyond the exact routines `0`, `23`, and bounded
`40` case remain fail-closed shared-routine boundaries; generic script
transfer and return semantics are not claimed. Trace v15 additionally
accepts a literal command-`0x10` DEF record only when its forward target ends a
non-empty, exactly decoded instruction region. It retains body metadata and
projected text without executing any body command, and stops successfully at a following literal
routine `40` as `def_selection_boundary`. The boundary is read-only: no option
is selected, no continuation is exposed, and no state write is synthesized.

The shared AI5 LZ codec now provides deterministic compression as well as
bounded decompression. Its compressor uses the confirmed 4 KiB ring window,
3..18-byte references, and LSB-first flag groups with a bounded greedy match
search. Synthetic tests cover literals, repeated references, ring-window wrap,
deterministic output, and byte-identical decompression round trips. This is a
container-codec round-trip result only; it does not by itself establish that a
newly encoded MMO is accepted by the original executable.

The MMO encoder performs the inverse vertical flip, RGB-to-BGR conversion,
delta transform, and shared AI5 LZ compression. Replacement encoding requires
the PNG dimensions to match an exact 0x28-byte target-entry header template;
all target-template bytes are retained. Content Core `0.184.0` classifies the
template with `kakyu_ai5_mmo_header_profile/v1` before assigning compatibility.
Only the observed standard mirrored-dimension profile is promoted to
`original_engine_compatible`; special or unclassified original profiles remain
`remake_only` even when their exact header bytes are preserved. A generated
canonical header mirrors its primary dimensions into the observed secondary
dimension fields but remains explicitly `remake_only`. Both template and
generated paths are decoded again in synthetic pixel round-trip tests. The
standard template-bound path was initially labeled
`original_engine_unverified`; the isolated result below establishes only the
narrow compatibility boundary required to promote that profile.

On 2026-08-02 the copied original executable accepted and displayed a
marker-bearing re-encode of `LOGOBKC.MMO`. The smoke harness strictly decoded
the original entry, added an 80x80 magenta/green marker, retained the exact
0x28-byte header, rebuilt and reopened a copied `mmo.arc`, launched only an
executable below the isolated system-temporary root, and captured the marker
from its 640x400 client. It then stopped only copied processes, verified the
original executable, INI, `mmo.arc`, relevant save hashes, and all source ARC
sizes/timestamps, and removed the temporary root. The screenshot is retained
only under the machine-local `.agents/local/` directory. This confirms the
same-dimension, exact-header MMO writer path for the tested original engine;
it does not validate resized images, generated headers, `CALFACE.MMO`, or
other image formats.

The direct `0x07` audit covered all 1,016 MES/LIB entries and retained 82,324
strict-valid runs with 84,324 writes. Its longest run contains 256 values;
strict-valid bank selectors are limited to 0, 1, 2, and 4. The decoder keeps
the destination expression separate from the static bank byte and value-run
continuations. A parallel `0x08` audit retained 53 strict-valid runs with 137
dword writes and keeps that storage distinct from the direct `0x07` u16 state.

Filename discovery remains separate from ordinary command-`0x07` word-state
semantics. The older conservative audit found 24,935 one-letter numeric names
inside set/filename/clear envelopes across 778 MES entries, all resolving to
original voice archives. Executable audio audit v7 corrects the instruction
boundary: outer `0x0D` enters native presentation dispatch and the following
`0x07` is nested subcommand 7. Across the complete authoritative archive, all
26,069 selector-2 occurrences match value 2, safe ASCII `.ogg` name, value 0.
Native bridge selector 2 queues the name and selector 3 checks `IsVoice`, loads
the named stream, performs a bounded Ogg stream handoff, and reaches
`IDirectSoundBuffer::Play(0, 0, DSBPLAY_LOOPING)`. Content Core v0.91 therefore
records the confirmed native Play dispatch separately from unobserved
host-device output and Godot-only tool playback. The marker itself performs no
sandbox write; independently decoded surrounding set and clear writes still
execute.

The historical read-only `kakyu_mes_analysis/v4` projection decodes each bootstrap or
address-table range independently and retains only its strict prefix. It does
not reinterpret the remainder after a decoder error. Message records carry the
bounded native stream probe and projection-match result from instruction v18.
A direct pass over all 1,016 authoritative MES/LIB entries completed with zero
container/index fatal failures and retained 2,237,373 strict-prefix
instructions, 219,910 raw message records, 133,854 code references, and
442,958 numeric state references. There were 8,827 explicitly retained stop
diagnostics across 820 entries. The v20 count change comes from rejecting
arbitrary wrapped OGG names outside the independently audited voice filename
grammar rather than treating those bytes as metadata instructions. These
counts describe a browsing/search projection, not executable coverage or a
complete control-flow graph; cache-backed UTF-8 records can supplement message
search after archive and entry hashes match.

Analysis v4 additionally invokes the instruction decoder's exact resource-only
marker matcher over the complete bytecode. It emits 32,797 resource references:
2,433 AX, 5,429 MMO, and 24,935 voice. The historical MMO figure used the
superseded suffix rule that swallowed an adjacent command-`0x07` prefix; v12's
outer-command matcher and audit v2 replace it with 7,645 exact records. Of the
historical v4 rows, 24,007 begin at a strict-indexed
instruction and 8,790 are retained as `bounded_envelope_scan` because an
earlier decoder boundary stopped that address range. The latter is structural
metadata evidence, not recovered execution flow. Each record contains only
the code-relative offset, region, normalized/original filename, bounded archive
candidates, boundary class, and unresolved native-semantics label; no original
payload or dialogue is copied. The corpus validator re-read the original ARC
read-only and confirmed its fingerprint remained unchanged.

The current v12 corpus totals supersede those historical v4 figures: 36,149
resource references comprise 2,433 AX, 7,645 MMO, 26,069 voice, and two nested
MES script records. 27,705 are `strict_indexed` and 8,444 are
`bounded_envelope_scan`. Voice
references expose the confirmed presentation queue/stream and DirectSound Play
semantics plus a separate unobserved-host-device field. MMO references expose
the confirmed named active-surface load but retain state-dependent surface
identity and composition as unresolved; AX consumer boundaries remain
unchanged.

`build_reference_graph` starts from one selected address range with a default
120-node limit. Without an explicit expansion depth it includes only sources
already retained in that range, their referenced targets, and decoder-stop
nodes. The MES Editor requests depth two with at most eight additional address
ranges. Only aligned targets of confirmed condition branches/fallthroughs and
continuations can enqueue another range; structural bootstrap/library-body skip
targets remain visible without causing expansion. A target inside bytecode but
not at an indexed instruction remains unresolved. Every reached range is still
limited to its strict prefix, and node, stop, or range omissions are reported
as truncation.

The authoritative `D_TALK00.MES` range containing code-relative `0x082F`
produced 39 nodes, 30 edges, five reached ranges, and one explicit decoder stop
at depth two with no limit truncation. MES Editor graph selections record the
owning address range in a bounded 128-item history; Back and Forward rebuild
the graph from that prior seed without changing the source archive. Flow,
structural-reference, and stop-node toggles filter only the retained projection
shown by `GraphEdit`; they do not re-decode bytes or promote structural edges.
Focus recenters the last selected visible node without changing the seed range.
The editor exports either versioned `kakyu_mes_reference_graph_export/v1` JSON
or Graphviz DOT to a new file. JSON retains both the complete bounded graph and
the current visible projection plus archive/entry hashes, but no machine path,
dialogue, or bytecode. DOT contains only the currently visible nodes and edges.
Both outputs are written to a sibling temporary file, read back, and published
only when the requested destination does not already exist.

## MMO Presentation Load Boundary

Content Core `0.121.0` recognizes an MMO reference only from the complete
outer-command-`0x0D`, presentation-subcommand-9 record with one safe ASCII
`.MMO` filename and its argument-list terminator. It does not consume bytes
from the following MES command. This is distinct from top-level command
`0x09`, which remains the native temporary argument-slot dword writer.

Executable audit `kakyu_ai5_mes_exe_audit/v34` fixes the presentation path as
dispatcher `0x00428120`, case-9 call `0x0042827B`, adapter `0x0042A640`, all
three public-context vtable `+0x30` routes to consumer `0x0042A6A0`, and the
consumer call at `0x0042A78C` into surface decode/blit path `0x00425190`.
The one-name adapter form supplies `(-1,-1)` as default origin arguments. The
consumer selects a surface through state offset `+0x20BA` and reaches AI5 LZ
MMO decode helper `0x004329D0`; runtime configuration independently identifies
the MMO archive. This confirms a named MMO load into the active surface, but
not the state-dependent surface identity or later composition order.

The v2 authoritative archive audit finds 7,645 exact presentation records in
659 MES/LIB entries, of which 6,647 resolve to the original `mmo.arc`. The 998
unresolved rows cover 180 names. Immediately following command counts are
`0x07`: 5,429, `0x0B`: 1, `0x0C`: 1,072, `0x0D`: 1,084, and `0x1F`: 59.
Consequently, Event Runner trace v55 retains the confirmed active-surface load
metadata while executing any following command independently. Event Player
uses the shared overlay resolver to decode a tool preview, labels active
surface/composition as unsimulated, and performs no native call or inferred
surface-state write.

## AX Read-Only Binding Table and Dword Boundary

The authoritative `data.arc` contains 630 `.AX` entries. Every entry begins
with one or more aligned four-byte values, reaches a first aligned
`0xFFFFFFFF` dword, and contains only `0xFF` bytes from that terminator through
EOF. The shared `kakyu_ai5_ax_dword_stream/v1` reader retains each raw dword
and source offset plus the exact terminator offset and suffix length. It
rejects an absent aligned terminator or any non-`0xFF` suffix byte. It does not
interpret a token as a coordinate, command, frame, mask, or pixel value.

The original corpus contains 310,018 pre-terminator tokens. Individual files
contain 343 through 1,358 tokens and 311 through 320 terminal/padding bytes.
All 630 entries pass the headless reader and the source archive fingerprint
remains unchanged.

Content Core `0.118.0` also exposes the separately versioned
`kakyu_ai5_ax_binding_table/v1` read-only projection. It reads exactly 320
little-endian entry-relative offsets from the first `0x500` bytes, maps them
as the native 10-by-32 consumer table, and rejects any target inside the table
or outside the current entry. Each result retains its row, column, table
offset, target offset, and target first byte. A non-`0xFF` first byte is only a
structural diagnostic in this projection; the separate animation projection
below validates it as the first stream opcode.

All 630 authoritative AX entries have a complete bounded table. Their 201,600
cells contain 200,670 `0xFF` targets and 930 non-`0xFF` targets; the latter
first-byte counts are `0x01`: 841, `0x02`: 12, `0x05`: 10, `0x07`: 6, and
`0x09`: 61. Every file's 320 offsets is strictly increasing and unique, and
entry sizes range from 1,692 through 5,750 bytes. These corpus-wide properties
are observed diagnostics, not additional native rejection rules. The original
`data.arc` fingerprint remained unchanged.

The independently audited MES corpus contains 2,433 `.AX` strings across 488
entries, and every broad token has the same exact outer-command-`0x0D`,
presentation-subcommand-8, selector-0 envelope. Of those rows, 2,013 resolve
to a current `data.arc` entry;
420 rows cover 66 unresolved names and remain visible as unresolved evidence.
Representative outer-command coordinates are `01M.MES:0x12720` (`B19.AX`)
and `03C.MES:0x0239`/`0x3BBB` (`W.AX`). Executable audit v34 confirms that
subcommand-8 selector 0 reaches the adjusted document Data loader
`0x0043DDA0`, archive collection index zero, and the named-entry lookup at
`0x0043DE48`. State initializer `0x00407C70` places the adjusted owner's
`+0x94` pointer in `banked_i32[0][2]` (`state+0x215C`). The loader uses that
argument as the direct ARC-read destination when `DataType=0` and as AI5 LZ
helper `0x00432890`'s output buffer when `DataType` is nonzero. Separately,
native command-`0x08` handler `0x00419020` remains the confirmed banked dword
writer; the two routes are not conflated. The original MES command audit finds
no strict literal command-`0x08` write to bank-zero index 2; six non-strict
dynamic-destination candidates prevent a stronger never-overwritten claim.

The loaded buffer's next bounded route is now independently fixed. MES audit
`kakyu_mes_ax_binding_audit/v2` retains 4,810 exact outer-`0x0D`,
presentation-subcommand-3 selector-0 bindings across 677 entries: 2,748 use
consumer cell `(0,0)`, 1,389 use `(0,1)`, and 673 use `(0,2)`. Executable
audit v34 follows the subcommand-3 adapter `0x00428F50` and dispatch
`0x00429050` to the only consumer registered at document vector `+0x4B578`.
Its vtable `0x0047B1D4` slot `+0x08` is function `0x00410BA0`. The bounded
function uses a 10-by-32 cell index, reads an entry-relative dword from a
320-entry AX offset table, installs the pointed-to stream in the selected
consumer cell, and retains `buffer+0x500` after that table. It performs no
pixel draw in the binding function; the separate step/render route below owns
that work.
Evidence type: direct authoritative `data.arc` structural audit, direct
authoritative `mes.arc` envelope audit, and embedded executable dispatcher,
selector case, state initializer, vtable, loader, LZ helper, and handler
disassembly; confidence: **Confirmed** for the bounded file shape,
presentation envelope, Data-archive named-entry load, destination-buffer role,
separate numeric writer, and bounded AX consumer-table binding.

The same audit also finds 6,754 exact no-argument selector-7 records across
731 entries. Executable audit v276 resolves selector 7 to the registered
consumer's vtable slot `+0x20`: handler `0x00410CC0` visits all 10-by-32 cells
and calls slot `+0x14` (`0x00410C30`), which writes state byte `0xFF` to each
cell. The tool contract therefore classifies selector 7 as all-cell AX
invalidation, not as a drawable asset request or a substitute for selector-0
binding.

Executable audit v34 continues through consumer vtable slot `+0x24`, function
`0x00410D60`. Each `0x2C`-byte cell retains its stream pointer at cell `+4`
and cursor at `+8`. The step function recognizes controls `0x00..0x08` and
terminal `0xFF`; controls `0x01`, `0x02`, `0x05`, and `0x07` consume a
little-endian u32. Bytes `0x09..0xFE` consume a u32 index into the shared table
at `buffer+0x500`, whose records are seven dwords (`0x1C` bytes): dispatch
type, source X/Y, width/height, and destination X/Y. In this sole registered
consumer, dispatch types 0 and 1 both reach renderer `0x00411330`; type 2 and
other values use no-op slots. The renderer passes the six rectangle fields to
pixel-copy helper `0x004255D0`, which copies three bytes per pixel and skips a
pixel matching RGB `0x00FF00`. It also reports the destination rectangle to the
host display object. The startup surface initializer at `0x0040506A` creates
surface 0 as 640x400 and surface 8 as 2688x864; the renderer reads source
surface vector element 8 and destination element 0. This confirms the bounded
chroma-key blit surfaces. Audit v69 maps active-surface state `+0x20BA` to
`banked_u16[0][1]`; exact EVENTB02 and EVENTB14 traces write value 8 before
their selected AN MMO marker and therefore identify those named MMO loads as
the route-local surface-8 producer. Generic producer/lifetime coverage, native
tick cadence, composition order, and a standalone AX image remain unresolved.

Content Core `0.182.0` generalizes the producer-side structural evidence with
`kakyu_mes_active_surface_ax_audit/v1`. The hash-bound original corpus contains
1,352 exact ordered surface-8/AN-MMO/restore-7/AX chains in 398 scripts; 1,351
also reach a bounded AX binding. This audit does not auto-enable playback for
all of them: it records stored structure only, while Event Player still
requires a source-qualified execution trace before attaching a live surface
binding. Branch-family routes such as EVENTB02 remain separately qualified.
Native lifetime, layer order, and cadence remain unresolved.

Content Core `0.183.0` adds `kakyu_mes_ax_runtime_chain/v1` between that
structural projection and the playback plan. A pending source is created only
when one live MMO trace matches exactly one audited marker coordinate/name and
observes `banked_u16[0][1] == 8`. It becomes runtime-confirmed only when a
later trace contains the exact audited AX marker coordinate/name and exact AX
binding coordinate/cell. EVENTB14 option 2 now requires this end-to-end
contract before starting `B14.AX`; shifted markers, a different cell, or a
merely stored but unexecuted chain stop fail-closed. EVENTB02 retains its
separate branch-family validator because it is not a canonical adjacent chain.
This establishes execution of one stored producer/consumer chain, not generic
surface lifetime or native timing.

The `kakyu_ai5_ax_animation/v3` Content Core projection implements only that
bounded native grammar. Across all 630 original entries it finds 6,332 shared
records (type 0: 4,684; type 1: 1,648); every source rectangle lies within
native surface 8's 2688x864 bounds and every destination rectangle lies within
surface 0's 640x400 logical frame. All 201,600 cell streams terminate and contain
254,695 commands: `01`: 8,439; `02`: 24,347; `03`: 860; `04`: 18; `05`:
1,743; `06`: 1,742; `07`: 6; `08`: 6; `09`: 15,952; `FF`: 201,582. No other
opcode occurs, every one of the 15,952 opcode-`09` record indices is in range,
and the original archive fingerprint remains unchanged. The reader fails
closed on a non-monotonic stream table, truncated operand, missing terminal,
unconsumed bytes, or out-of-range record index. Its bounded tool-timeline
compiler additionally expands only the confirmed counter/reset/count-loop and
shared-dispatch subset. It rejects unsupported or malformed loop structure;
one expanded command equals one tool tick and does not assert native timing.

Content Core 0.333.0 (2026-09-17, ME-03) adds the writer of that structure,
`content_core/ax_writer.gd`. `serialize` re-encodes an inspected (or edited)
animation document - the 320-cell offset table recomputed from the stream
lengths, the shared draw records, every cell stream with its operands,
terminal and optional trailing `FF` - and refuses a record outside the
2688x864 source or 640x400 destination bounds, a dispatch index out of
range, a stream without exactly one final terminal, a truncated operand or
a cell count other than 320. `replace_stream` and `replace_shared_record`
edit one cell or one record by serializing and re-inspecting, so an edited
document always equals the reopened bytes; `reopen` requires the dword,
binding-table and animation readers to accept the output; `write_audit`
(`kakyu_ax_write_audit/v1`) binds source and output hashes, sizes, the byte
delta, the record/stream/command counts and the changed cells. Measured 2026-09-17 over the whole `data.arc` corpus: all 630 AX entries re-serialize byte-identically (201,600 streams, 254,695 commands, 6,332 records), and a one-byte control inserted before the terminal of the first non-FF cell of ten entries reopens with the later cells' targets shifted by one byte, every other stream identical and an audit `byte_delta` of 1.
The image editor runs the no-op round trip on every inspected AX entry and
reports it in the details. Core 0.334.0 (2026-09-17, ME-02) adds the timeline
editor over this writer: for the selected cell, the command list is edited
(replace, insert after, remove, move up/down) with the grammar's opcodes and
raw u32 operands - the count loop `05`/`06`, the reset `03`, the stops `04`
and `FF` and the dispatch of a shared record are the confirmed subset the
tool timeline expands; the `00`/`01`/`02`/`07`/`08` controls keep their
native meaning unconfirmed and are edited as values - and any shared
record's dispatch type, source crop and destination are edited within the
2688x864 and 640x400 bounds. Every edit goes through
`replace_stream`/`replace_shared_record`, so the working document is always
a reopened one; the existing cell selector, Game Frame destination overlay
and tool-clock preview show the edited animation; **Stage AX** serializes,
reopens, audits (`kakyu_ax_write_audit/v1`) and stages the bytes into the
image replacement session as an `original_engine_unverified` item (the
overlay batch then follows the session's existing compatibility collapse),
**Revert edits** discards them. An edited AX is not played by Event
Player. Verified 2026-09-17: `tests/test_ax_writer.tscn` (22 checks: no-op, reopen, growth, `04 FF`, record edit, eight rejections), the image editor scene (141), the AX corpus and Image Editor archive checks, the local batch (113 checks); Python untouched (1,540).

Content Core `0.178.0` adds the versioned
`kakyu_ax_tool_scheduler/v1` clock over that compiled timeline. It accepts only
strictly increasing, in-cycle dispatch ticks, advances either by explicit tool
ticks or an explicit seconds-per-tick value, preserves sub-tick and bounded
catch-up backlog, stops terminal timelines, and emits exact shared-record
dispatches across a cycle wrap only when the compiled reset control requests it.
Configuration, advance, snapshot, and clear are independent of rendering and
original resources. Its timing basis is always
`explicit_tool_clock_native_host_cadence_unconfirmed`; it is a shared
deterministic preview policy, not evidence for the original engine timer.
Event Player consumes this scheduler for both audited EVENTB02 and EVENTB14
AN/AX projections. Their route-specific code supplies validated local frame
indices and applies emitted dispatches to retained compositor checkpoints; it
does not maintain a second elapsed-time or cycle implementation.

Content Core `0.179.0` adds the versioned `kakyu_ax_playback_plan/v1` adapter
between the inspected animation and that scheduler. For one selected binding
cell it collects referenced shared records in stable source-record order,
assigns local playback-frame indices, and remaps every dispatch while retaining
its original shared-record index. Drawable records must be type 0/1 green-key
copies whose crop fits the caller-supplied detached source image and whose
destination fits 640x400. Explicit native no-op records may be retained for
structural playback; consumers that require drawable-only output reject them.
The v1 plan labels its input as an explicit detached image and does not itself
establish which original host action populated surface 8 or native cadence.
EVENTB02 and EVENTB14 take both their frame crops and destinations from this
common plan after their exact route/media contracts pass.

Content Core `0.180.0` advances that adapter to
`kakyu_ax_playback_plan/v2` and adds `kakyu_ax_surface_binding/v1`.
Instruction v40/event trace v65 retain the MMO marker's active-surface storage
identity and the sandbox value observed at the marker. A playback plan may now
carry a validated producer binding only when a confirmed named MMO trace sees
`banked_u16[0][1] == 8` (`state+0x20BA`). EVENTB02 and EVENTB14 use this path
for their audited AN MMO/AX sequences; a detached Image Editor selection has
no MES route and remains explicitly unbound. The plan still labels its clock
as tool timing, and ordinary resolver reads continue to validate effective
overlay media independently of the original-route evidence.

Image Editor consumes this projection without adding an app-local AX
interpreter. The AX selector lists only binding cells whose target does not
begin with terminal `0xFF`. Choosing a cell first shows a labeled structural
overview of its directly referenced type-0/type-1 destination rectangles in
the fixed 640x400 Game Frame. The shared timeline compiler expands only its
confirmed bounded control subset, then the shared scheduler owns
Play/Pause/Restart, terminal stop, reset-requested wrap, and elapsed-time
accumulation. After a dispatch the Game Frame outlines only that current
confirmed destination. It still does not read or invent source-surface pixels,
and its explicit 60 Hz tool clock is not native cadence evidence. The original
`A01.AX` integration check displays 13 structural destination references,
configures the shared clock, retains an empty authored session, and rechecks
the source archive hash.

Content Core `0.121.0`, instruction schema `ai5_mes_instruction/v37`, analysis
schema `kakyu_mes_analysis/v12`, and event trace
`kakyu_mes_event_trace/v55` accept an AX record only when its outer `0x0D`,
subcommand, selector, safe ASCII `.AX` name, NUL, and complete typed suffix
match. The trace carries `data_arc_named_entry_load_confirmed` without
executing the native load or applying ordinary command-`0x08` numeric writes.
Event Player then preferred-resolves the referenced entry from `data.arc`
through the shared overlay resolver and validates its bounded dword-stream
shape. It shows the source, raw token count, and confirmed native destination
buffer role and retains that metadata across a continuation, but does not
simulate the host surface or animation clock. A
hash-preserving original-input validator re-read `01M.MES:0x12720` (`B19.AX`)
and `03C.MES:0x0239`/`0x3BBB` (`W.AX`), decoded all three exact records, and
validated both referenced AX entries with unchanged `mes.arc` and `data.arc`
fingerprints.

The same versions recognize the complete 18-byte subcommand-3 binding as
`ax_presentation_binding`, retain consumer 0 and cell `(0,0..2)`, and advance
without sandbox changes or native execution. This removes the former
one-byte-late false interpretation of nested byte `0x03` as an authored
`global_u8` write. MES Editor shows the consumer cell in disassembly; Event
Player shows a confirmed native bind without executing it. When the referenced
AX entry is available,
Event Player now resolves the traced row and column through the same versioned
animation projection and displays its exact entry-relative stream offset and
start opcode outside the game frame. It retains that bounded table across a
continuation. The tool validates shared render records and reports the bounded
surface-8-to-surface-0 route, but does not reconstruct surface 8's MES-driven
contents or advance its tick state.

The 2026-08-11 headless original-corpus replay retained all 2,433 AX references
inside 36,149 total resource references, together with 7,645 MMO, 26,069
voice, and two inline-MES references. Current analysis v14 retained 2,404,618
instructions, 220,491 messages, 185,994 code references, and 535,505 state
references with zero fatal failures and an unchanged source hash. The
133,459-anchor Event Runner corpus also retained zero fatal failures and
969,912 traced steps after exact subcommand-11 surface boundaries were added.

## MES Surface Composition Boundary

Content Core `0.192.0` recognizes the exact outer-`0x0D`, presentation-
subcommand-11 expression-record envelope. Archive audit
`kakyu_mes_surface_operation_audit/v4` found 11,317 complete typed-record
candidates. Of
those, 11,315 are confirmed operations across
740 authoritative entries: 7,273 opaque copies, 3,676 RGB-key copies, and 366
active-surface fills. One other candidate is the separately confirmed
non-pixel `surface_display_refresh`, a six-record literal mode-13 list at
`LIBLARY.LIB:0x00FD`. Only the empty list at `10M.MES:0x4AC7` remains
`surface_dispatch_unresolved`. Candidate status does not imply reachability.
(Since Core 0.316.0, 2026-09-13, that raw prefix is known to be the interior of
the literal `2829` in the argument-slot write at `10M.MES:0x4AC3..0x4ACB`.)

Configured-original executable audit v81 retains v38's dispatcher call
`0x004282A1` binding to
adapter `0x0042ABA0` and public-context slot `+0x38`. Its active consumer
`0x0042AC30` expands inclusive endpoints to width/height and selects helpers
`0x004254D0`, `0x004255D0`, or `0x00425B10` for opaque copy, RGB-key copy, or
active-surface fill. Surface lookup remains state-dependent through vector
offset `+0x128` and active index state `+0x20BA`. The shared decoder therefore
retains mode, expression arguments, rectangle, and helper metadata without
claiming the current surface contents. The same consumer accepts mode 0 through
7 through table `0x0042B018`; larger values skip the mode-specific body at
`0x0042AFDD` and enter common tail `0x0042AFE5`. The common parser at
`0x0043E800` zeros its complete `0x546`-byte record workspace, so the six-row
mode-13 form has default origin `(0,0)` and takes the tail's virtual-slot-`+0x14`
call at `0x0042B00C`. Initializer `0x004047ED` binds the global object to vtable
`0x0047A42C`; slot `+0x14` reaches `0x004059E0`, which returns when its attached
target is null or forwards the rectangle to locked-copy helper `0x00427640`.
That helper calls `BitBlt` with `SRCCOPY`, and both paths return at
`0x0042B012` with `ret 0x34`. Modes 3 through 7, empty-list record defaults,
and the attached display's backing content/lifetime and final composition
remain unresolved.

Instruction v41, analysis v16, Event Runner trace v66, and library trace v9
evaluate only present bounded arguments. Confirmed shapes emit
`surface_operation_omitted`; the confirmed non-pixel form emits
`surface_display_refresh_omitted`; an executable unresolved form emits
`surface_dispatch_omitted`. Trace-bearing registered-call, registered-runner,
detached-preview, and script-call envelopes advance to v4, v6, v4, and v2 so
older consumers cannot silently reinterpret the new row.
No native helper or common-tail display refresh is called and no gameplay save or
sandbox storage is changed. MES Editor shows mode, record count, and resolution
status. Event Player lists decoded-operation and unresolved-dispatch counts
separately in desktop diagnostics outside the 640x400 frame. The library audit
keeps each typed record extent without inventing a character-stream probe.
Original ARC inputs stay read-only.

The standard original-source batch runs both independent implementations. The
Python pattern audit and shared GDScript core audit v4 agree on all 11,317
candidates, 11,315 confirmed pixel operations, one confirmed display refresh,
one unresolved empty dispatch, 740 pixel-operation owning entries, three
confirmed pixel-mode totals, and three pixel record-count totals. The GDScript
pass locks the display-refresh and unresolved coordinates separately, verifies
the source fingerprint before and after, and fails if a future decoder leaves
any raw prefix unmatched or changes a count or coordinate.

The paired `kakyu_mes_surface_dispatch_reachability_audit/v3` then prevents raw
candidate counts from being mistaken for execution coverage. `10M.MES` entry
59 owns the physical range `0x4A96..0x4B09` but returns at `0x4AA6`; no route
from any of its 134 address-table intros reaches `0x4AC7`, and its bounded
all-zero execution has zero hits. (Corrected under Core 0.316.0 on 2026-09-13:
the return at `0x4AA6` was a byte inside the name-insert call read as command
`0x00`; the route from the intros lands on the argument-slot write
`0x4AC3..0x4ACB` that owns the candidate's bytes, so the audit records the
candidate as shadowed, and the all-zero run proceeds to a DEF selection
boundary at `0x4CC1` after 57 rows, still with zero hits and no state diff.) `LIBLARY.LIB` routine 20 owns
`0x0068..0x011E`, reaches mode 13 through `0x00E0 -> 0x00FD -> 0x011D`, and its
six records evaluate to `[13, 34, 316, 577, 375, 0]`. Inclusive expansion plus
the zeroed missing origin records produces an exact `(0,0) 544x60` refresh;
all-zero library execution records one omitted display refresh followed by
normal return. Event Runner corpus v39 independently records 16 reached
confirmed pixel operations, zero display refreshes, and zero reached unresolved
dispatches across all 133,459 normal
MES intros. Original ARC and sandbox/save isolation remain unchanged.

Content Core `0.166.0` introduces the shared
`kakyu_logical_surface_compositor/v1` execution foundation for the three
confirmed modes. It stores detached RGB8 surfaces, reserves surface 0 as the
fixed 640x400 logical frame, records explicit surface roles and active-surface
selection, expands inclusive endpoints, and preflights both rectangles before
mutation. Mode 0 performs an opaque rectangle copy, mode 1 compares an exact
quantized 24-bit RGB key before copying, and mode 2 fills the active surface.
Snapshots returned to tools are detached and cannot mutate compositor state.

This foundation does not infer the generic native contents or lifetime of surface 8,
the ownership and restoration of other surfaces, layer order, or AX tick
cadence. App integrations remain bounded P3-01/P3-02 work and must preserve the existing
fail-closed boundary until the missing producer and timing evidence is bound.
The implementation consumes the already documented executable-audit contract;
it makes no new claim about original opcodes or host behavior.

Content Core `0.167.0` adds the corresponding strict MES-trace adapter. It
accepts only a runner row still marked `surface_operation_omitted`, with
subcommand 11, unchanged sandbox state, the confirmed inclusive-endpoint tag,
the exact helper for its mode, and the exact evaluated argument count. The
adapter maps eight-record mode 0 to the default logical destination and the
nine-record forms to their explicit destination. Mode 1 requires an explicit
RGB key and mode 2 an explicit fill color from presentation context; neither is
guessed from MES or current pixels. A missing context or any evidence mismatch
fails before compositor mutation. Event Player continues to omit these effects
until surface ownership and producer state can be supplied safely.

Content Core `0.168.0` adds deterministic operation sequence numbers and
`kakyu_logical_surface_checkpoint/v1`. A checkpoint contains detached RGB8
payloads with per-surface SHA-256 plus a whole-state binding over sorted surface
metadata, roles, active index, and operation sequence. Restore reconstructs and
validates every candidate surface before atomically replacing live state; a
bad pixel hash, duplicate index, unsupported role/format, wrong 640x400 surface
0, invalid active index, or changed state binding leaves the current frame
untouched. This is an in-memory caller-frame contract, not a persisted mod
format. Event Player call frames do not own it yet.

Content Core `0.169.0` adds ordered composition transactions. A caller supplies
an explicit operation array; successful operations receive consecutive
sequence numbers and later operations therefore define overlap order. The core
captures its own checkpoint before the first operation. If any later source,
destination, rectangle, color, or mode is invalid, it restores every surface,
role, active index, and sequence and reports the failed stored-order index.
An empty sequence is a successful no-op. This contract does not discover or
schedule layers; it only guarantees deterministic application of layers whose
producer and timing have already been established.

Content Core `0.170.0` adds
`kakyu_tool_game_preview_compositor_binding/v1` to the shared 640x400
`ContentToolGamePreview` instantiated by both Event Player and Image Editor.
It accepts only logical compositor surface 0, captures a detached snapshot,
records role and operation sequence, switches the frame to exact 640x400
presentation, and clears any stale separate foreground layer. The displayed
snapshot never changes merely because the compositor later advances; refresh
is explicit. A wrong schema, missing surface, non-logical size, or other index
leaves the last valid preview and binding untouched. Existing app-specific
media paths have not yet been replaced by this binding.

Content Core `0.171.0` migrates Image Editor's decoded MMO and DAT/PAL Game
Frame producer to the shared compositor. Asset View still owns the untouched
decoded source image. Game Frame creates a detached black 640x400 surface 0,
registers the decoded image as a tool source surface, intersects the requested
X/Y placement with logical bounds, applies one opaque copy when the intersection
is nonempty, and presents the resulting compositor snapshot. Negative placement
clips the source origin; a fully offscreen image produces a valid empty black
frame. This is tool placement only and does not assert the original engine's
surface-8 producer, transparency state, or AX scheduling.

Content Core `0.172.0` migrates Event Player's already validated EVENTB02 and
EVENTB14 AN/AX presentation cases to the same surface-0 binding. A decoded
640x400 MMO becomes the retained background checkpoint. EVENTB14's confirmed
full-frame keyed `B.MMO` layer is folded into that checkpoint. Each B02 or B14
AX dispatch then restores the checkpoint, registers the decoded AN atlas as a
detached source, applies exactly one RGB-key source rectangle at the
event-specific audited destination, and explicitly refreshes Game Preview.
This prevents three- or four-frame atlas strips and prior frames from leaking
into the visible result. Original-ARC validators compare every pixel in the
active rectangle with either the selected AN frame or the retained background
for exact green-key pixels. The existing 60 Hz tool clock remains explicitly
non-native; generic surface-8 production, layer lifetime, caller-frame surface
ownership, and routes without proven AX placement remain unresolved.

Content Core `0.173.0` fixes EVENTB14 branch playback after an explicit choice.
The selected outer or nested branch is carried only by its bounded continuation
context; the choice projection is not reattached between dialogue boundaries,
so ordinary advance input cannot select or append a sibling outcome. The
source-bound B_PIC return also selects the confirmed B.AX face column from
Mahoko affection (`banked_u16[0][210]`): low, middle, and high bands use columns
1, 0, and 2 respectively. Event Catalog now uses the source-authentic original
19:00 caller gate. That route binds `B3.MMO`, resumes the second routine-22
coordinate `B_PIC.MES:0x04AF/0x04B4`, and joins the high-affection column-2
face route. The old 06:00 composition remains compatibility/debug coverage.
Persisted Content Core schemas are unchanged.

## A6 Input-Region Read/Write Boundary

The authoritative `data.arc` contains 12 `.A6` entries. Every entry has an
exact `(N * 10) + 2` byte size, divides into `N` records of five little-endian
unsigned 16-bit words, and ends with a standalone `0xFFFF` ID word. Original
EXE helper `0x00411400` proves the field order is
`ID, left, top, right, bottom`: it advances by ten bytes, stops when the next
ID is `0xFFFF`, and returns the first ID whose left/right and top/bottom bounds
contain the input coordinate. All four edges are inclusive. Helper
`0x00411450` searches the same table for the first matching ID and copies its
four bounds in that order; a miss produces a zero rectangle.

Content Core `0.124.0` advances the shared contract to
`kakyu_ai5_a6_input_regions/v3`. The reader validates the complete byte
shape, retains raw fields and offsets, exposes the confirmed names, mirrors the
first-match hit test and ID lookup, and reports duplicate IDs or inverted
rectangles without rewriting or rejecting otherwise bounded bytes. It now also
rejects a record ID of `0xFFFF` before the physical table end because the native
helpers would treat that word as an early terminator.

Content Core `0.187.0` advances that additive contract to
`kakyu_ai5_a6_input_regions/v4`. For each valid rectangle it intersects all
earlier records under the confirmed first-match order, uses an exact
coordinate-compressed union rather than a screen-sized approximation, and
reports total, covered, and still-visible inclusive pixel area. A later record
with zero remaining area is `fully_unreachable_by_first_match`; one with both
covered and visible area is partially occluded. The layout also reports the
overlap-pair, partial, and unreachable totals. Invalid source rectangles remain
structural diagnostics and do not participate in the coverage calculation.
The same version adds insert, duplicate, remove, and move operations over a
validated table. Each operation rebuilds and reopens the whole byte sequence,
returns the exact selected row, and preserves the terminal and compatibility
rules; out-of-range indices fail before publication.

The paired writer accepts ordered dictionaries with exact
`id,left,top,right,bottom` unsigned-16-bit fields, rejects the terminal ID,
out-of-range fields, and inverted authored rectangles, appends one terminal
word, reopens the result, and reports `original_engine_compatible`. It preserves
record order and duplicate IDs so native first-match behavior is unchanged.
A6 remains input metadata rather than a standalone pixel image; Image Editor
therefore offers no PNG path. Its bounded editor selects one existing record
and can change the five confirmed fields, add a new row after the selection,
duplicate or remove a row, and move a row one position up or down. Every action
encodes and reopens the entire ordered table before staging it as
`original_engine_compatible`. The operation bar disables impossible moves and
reports overlap-pair, partially occluded, and fully unreachable counts plus the
selected row's visible pixel area. Reordering is therefore explicit: it can
change native first-match behavior and the updated diagnostics make that effect
visible before publication. Overlay and new-ARC saves share the same
content-addressed session and never write the opened source archive.

The Image Editor projects these records into its fixed 640x400 Game Frame.
Every non-inverted region is outlined with `right-left+1` by `bottom-top+1`
logical pixels, preserving the confirmed inclusive edges. Pointer hover and
click call the shared A6 hit test; therefore duplicate overlaps resolve to the
first stored record exactly as the native helper does. Selecting through the
frame updates the same numeric editor but stages nothing by itself. Coordinates
outside 640x400 remain in the table and numeric controls and are only clipped
by the preview. This view does not infer A6 ID meanings or an associated image.

The original-file corpus contains 153 records: `ALBUM.A6` 19, `GIRLS.A6` 15,
`LOG.A6` 3, `MENU1.A6` 1, `MENU3.A6` 3, `MENU3_2.A6` 3, `MENU5.A6` 5,
`MENU6.A6` 6, `MUSIC.A6` 20, `SLOT.A6` 4, `SMP1.A6` 44, and `SMP2.A6` 30.
These tables contain nine duplicate-ID records and no inverted rectangles.
The v4 first-match analysis finds 21 overlapping record pairs, 19 partially
occluded records, and no fully unreachable original record. All 12 tables still
rebuild byte-identically under the expanded inspection contract.
Duplicates are retained because the native functions explicitly use
first-match order. Coordinates range outside the remake's 640x400 gameplay
frame in some tables, including a bottom bound of 480; the tool does not clip
or reinterpret the stored values. The headless validator re-reads these entries
through `KakyuArcReader`, locks all counts, exercises first-record ID lookup and
inclusive-edge hit testing, byte-identically rebuilds all 12 entries through
the writer, and verifies that the source archive fingerprint remains unchanged.

Executable cross-checking confirms that A6 names are active `Data.arc`
resources and independently proves the input-region field order. The embedded
original executable selects `menu3_2.a6`, `menu1.a6`, `menu5.a6`, `menu3.a6`,
or `menu6.a6` in the title UI method at `0x00443D10`; the selected filename is
passed at `0x00443DAF` through the adjusted document vtable's Data-loader slot
`+0x24`. `inputname.a6` is independently passed through the same slot at
`0x00430329`. That slot resolves to `0x0043DDA0`, selects the `Data.arc`
collection at object offset `+0x20`, and invokes the named whole-entry loader
at `0x0043DE48`. The title pointer path calls `0x00411400` at `0x00443E2C`.
Two independent UI paths call `0x00411450` at `0x00401EC6` and `0x00431916`,
then calculate the returned rectangle midpoint. Audit schema
`kakyu_ai5_arc_exe_audit/v4` and later lock those helpers and call sites. Evidence type:
direct authoritative `data.arc` corpus audit plus embedded executable vtable,
collection, string-xref, hit-test helper, rectangle-lookup helper, and caller
disassembly; confidence: **Confirmed** for file shape, runtime filename use,
the native Data archive load route, field order, inclusive edges, and
first-match behavior, the writer's bounded field validation, and byte-identical
no-op rebuilds; **Unresolved** for higher-level ID meanings and association with
rendered image resources. No original ARC is rewritten by this validation.

## Verified Original Corpus

After a user-owned source directory was configured locally, all eight original
archives were opened directly with both the Python compatibility reader and the
Godot shared reader. Sequential no-op copies were written outside the source,
reopened, compared by SHA-256, and removed before processing the next archive.
All passed and every source hash remained unchanged:

| Archive | Entries | Bytes |
|---|---:|---:|
| `bgm.arc` | 52 | 493,788,716 |
| `data.arc` | 867 | 8,406,691 |
| `mes.arc` | 1,016 | 18,885,616 |
| `mmo.arc` | 1,727 | 419,962,992 |
| `se.arc` | 87 | 22,946,714 |
| `tina1.arc` | 967 | 32,439,192 |
| `tina2.arc` | 959 | 30,260,198 |
| `voice.arc` | 15,438 | 521,097,594 |

Bounded audio validation covered 17,503 entries with zero failures: 52 stereo
PCM WAV files at 44.1 kHz, 87 mono PCM WAV files at 22.05 kHz, and 17,364 mono
Ogg Vorbis files at 44.1 kHz. DAT/PAL decode covered all 100 pairs: 80
`640x32` index-zero-alpha strips, 18 `640x400` images, one `640x288` image,
and one `640x64` image. The corpus validator also re-encodes `CHARA.DAT/.PAL`
and `MACHIN_3.DAT/.PAL`, requires their fixed pair sizes, opaque RGB pixels,
and alpha masks to remain identical, and rechecks the source archive
fingerprint. RGB stored beneath fully transparent source pixels is intentionally
ignored because index-zero alpha cannot preserve it visibly.

A6 input-region validation covered all 12 `data.arc` entries and all 153
five-word records with zero failures, nine duplicate-ID records, and zero
inverted rectangles. It also checks first-ID lookup and both inclusive rectangle
corners. These checks establish the native read contract; they are not image-decode
or writer validation.

AX structural validation covered all 630 `data.arc` entries and all 310,018
pre-terminator dwords with zero failures. The same pass bounded all 201,600
10-by-32 binding-table targets, including 930 non-`0xFF` targets, with all 630
tables strictly increasing and unique. These checks establish the table,
target bounds, and suffix shape. It additionally validated 6,332 shared draw
records, 201,600
terminated streams, 254,695 commands, 15,952 bounded record dispatches, and all
6,332 destination rectangles inside 640x400. This is read-only stream/render-
contract validation, not a standalone image decoder or writer validation.

## Opt-In Native Relative Byte Memory

Content Core `0.101.0` adds an opt-in physical byte layer to
`KakyuMesSandboxState`. With the mode disabled, `banked_u8` retains the prior
isolated logical-bank behavior. Once a verified caller enables it, each read or
write resolves to `state_u16[bank] + index` in a shared `relative_u8` address
space, matching executable audit v23's token-`0xC0` and command-`0x06`
contract. The sandbox exposes physical addresses in state diffs and rejects
addresses beyond the bounded `0x0000..0xFFFF` tool range.

The primitive deliberately does not enable itself or seed original data.
Original `START.MES` calendar reconstruction and date validation must be
hash-bound before Event Player can opt into this mode; ordinary isolated
intros therefore keep their existing behavior.

Content Core `0.102.0` adds that reconstruction as the separate runtime-only
`kakyu_mes_calendar_state/v1` projection. It accepts a parsed `START.MES`,
requires the audited base registration at `0x05DF`, sentinel writer at
`0x05FC`, and all twelve command-`0x06` row shapes at their exact code-relative
coordinates, then builds the 384-byte table in memory. Applying a projection
rechecks its SHA-256, seeds the baseline at `0x24A0`, fixes
`banked_u16[0][0]`, and explicitly enables the alias. Baseline bytes are not
included in authored sandbox JSON or ordinary state diffs; later physical
overrides are. `kakyu_mes_calendar_state_audit/v1` hash-binds this projection
to the authoritative archive and proves all twelve DEF12-style scans reach
sentinel 15 without changing the source.

The separate `kakyu_mes_def12_calendar_execution_audit/v1` applies the same
runtime-only projection to registered DEF12 for the first day of all twelve
months plus wrapped date `1301`. Every path takes exactly 28, 30, or 31 true
sentinel checks, branches to `0x04F5` once, and then reaches shared routine 26
at `DEF_MAIN.MES:0x0EF0`. That shared routine remains fail-closed; the audit
proves exit from the calendar scan, not completion of the whole native call.

`kakyu_mes_def12_library26_execution_audit/v1` composes the next explicit
step without changing the default Event Runner boundary. For all thirteen
dates it enters hash-bound shared routine 26 at `LIBLARY.LIB:0x2020`, follows
27 decoded coordinates to return `0x3540`, makes no nested call, native-effect
omission, message, or sandbox write, restores the caller at
`DEF_MAIN.MES:0x0EF5`, and reaches the caller return at `0x0EFA` in two rows.
The routine's stored body still contains other state-dependent branches and
thirteen static routine-24 call sites; this result applies only to the explicit
projected date states. Executable audit v24 independently fixes the native
`0x1D` lookup/call/restore frame used by the composition.

The separate `kakyu_mes_library26_routine24_execution_audit/v2` exercises all
thirteen branches only after labeling their inputs as tool-seeded. Direct
routine 24 advances `0101` by 27 days to `0128` through the reconstructed month
table. The composed cases pair value fields `200..212` with odd date fields
`213..237`; each calls routine 24 at `0x217D + n * 0x1A0`, resumes five bytes
later, and returns with its exact bounded diff recorded in the MES format
specification. This validates every stored nested-call block and the physical
calendar alias; it does not infer that the original game naturally produced
those field values.

The Python cross-audit `kakyu_mes_promise_calendar_fields_audit/v2` narrows
that uncertainty without executing the original engine. It verifies the nine
static banked writes in each of the thirteen routine-26 blocks, then checks
twelve `*_PROMIS.MES` entries that copy `state_u16[10]` into the paired date
field and `state_u16[19]` into the following auxiliary field. It also runs
original executable audit v25 and requires the native command-`0x07` 16-bit
bank-selected writer contract. Block 5 fields `205 / 223 / 224` have no
matching PROMIS entry and remain explicitly unresolved. The result contains
only hashes, entry names, field indices, and code-relative offsets.
Version 2 also maps each writer to its owning original address-table intro;
that mapping is intentionally labeled structural until runtime reachability is
audited.
The follow-up owner-boundary execution audit confirms that none of those 24
intros directly reaches its enclosed writer under isolated state: date owners
split into nine shared-routine boundaries and three returns, while all twelve
auxiliary owners return. Event Player must not promote these structural owners
to start buttons until their real caller/resume routes are confirmed.
(Corrected under Core 0.316.0 on 2026-09-13: those returns were the end of a
message wait read as command `0x00`; the date owners stop at their
shared-routine boundary after nine or eleven rows, while every auxiliary owner
runs on to its writer and stores `1800`. See `format_and_method.md`, the
correction under the owner-boundary audit.)
All twelve date routes now have a safe explicit composition: with legacy caller date
`0401`, their owner prefix reaches routine 24, the shared calendar runner
returns, and the caller suffix stores `0402`. (Since Core 0.316.0, 2026-09-13, the
suffix probe runs on from that store to the time selector's DEF selection
boundary - the route's `choice_boundary` - instead of the fake return it
once stopped at; the Event Player's route table records the suffix row count
per entry.) Event Player exposes these twelve
hash-bound intros as **Start PROMIS Schedule** only while the original calendar
and `LIBLARY.LIB` context are active and the isolated legacy date is valid.
The controller presents the original pre-call dialogue, owns the explicit
routine-24 continuation, presents the post-write dialogue, and stops at each
entry's exact ten-option routine-40 time selection. The fixed `640x400` game
frame pages three options at a time; Up/Down, Enter, number keys `1..9/0`, and
pointer rows remain usable without allowing the choices to overflow the frame.
The route-specific projection writes the one-based choice only to isolated
`state_u16[21]` after verifying that the physical resume first branches on
that field. In an otherwise empty sandbox, choice 1 produces two original
rejection-dialogue boundaries and returns to the same time choice. The
read-only location-route audit now identifies the missing input as the
entry-specific selected-location field and confirms that option 1 accepts IDs
`2,3,5,6,7,9,10,12,14`. A Sandbox-only **PROMIS location** control is enabled
only for an original-ARC entry whose hash matches that route. It writes the
entry-specific `global_u8` field explicitly, clears stale continuation/choice
state, and refreshes the audited time-row availability. It does not seed or
infer the native outer selection. At the ten-option selector, each visible row
now appends `[OK]`, `[NO]`, or `[GATE]` from the v3 matrix; the result panel
shows the full 09–18 matrix outside the `640x400` game frame. `[GATE]` is used
only for A-entry 16–18 while latch 1060 is zero, keeping that condition distinct
from location rejection. Location `0` therefore retains the audited 09:00
rejection loop. An accepted route displays **PROMIS PREFIX END** at its exact
MES return but does not label that point as whole-event completion. Promotion
of `C/E/I` uses their exact dynamic-protagonist-name dialogue boundary before
routine 24 rather than a synthetic intermediate return. Native outer-caller
selection remains unresolved.

`validate_event_player_promise_dates.gd` drives all twelve routes through the
actual controller with input `0401`: one pre-call dialogue boundary, routine
24, the exact `0402` writer, 2..5 post-write dialogue boundaries, the exact
ten-option time selector, and the choice-1 rejection loop. It also rejects an
invalid `0230` date, checks all twelve month-end transitions through the
original variable-length routine-24 paths (`96`, `102`, or `105` rows), and
retains the source's terminal `1231 -> 1301` result rather than inventing an
annual wrap to `0101`. It then applies accepted location ID `2`, snapshots each
exact selector state, and executes all ten choices in all twelve entries. All 120
accepted routes write their initially cleared success flag `610..619`, expose
transient HHMM `0900..1800` after the first success dialogue, store the same
time in the paired banked field, and resume the entry's 3..5 dialogue boundaries
to its exact `script_return`. The original suffix resets scratch HHMM to `0`
while retaining the success flag and paired time. A-entry options 8..10 are
tested with the separately audited latch 1060 set; the validator does not infer
that latch from location. The controller keeps `_preview_event_complete` false
because the native outer caller remains unresolved. It then rehashes `mes.arc`.
Executable audit v25 separately
reconfirms command `0x1D` as the native registered-routine lookup/call/context-
restore envelope; it does not resolve routine 40's input loop, so this remains
a hash-bound sandbox projection rather than a generic interpreter rule.

The same controller check executes A-entry options 8..10 through their separate
gate instead of validating only an already-set latch. With accepted location
`2`, field 201 value `99` produces two dialogue boundaries and a selector retry
without setting latch 1060; value `100` produces eight boundaries, sets the
latch, and retries without setting the option success flag. Re-selecting the
same row then completes the normal three-dialogue success suffix. It also
checks `state_u16[7]=0824` plus location `14` at the high threshold: the earlier
two-dialogue date/location branch wins and leaves the latch clear. The result
panel reports the current field-201/latch values and these boundary counts
outside the logical game frame; the tool does not assign a gameplay meaning to
field 201 or infer its native value.

`audit_mes_promise_location_routes.py` adds the independent static side of
that result. Schema v3 requires 15 literal location-field writers and all ten
selector blocks in all twelve hash-bound entries. It fixes each time's rejected and
accepted location sets, two-boundary ordinary retry bodies, success flags
`global_u8[610..619]`, and HHMM writes `0900..1800`. Options 1..9 use the
entry-specific success transfer; option 10 falls through. The audit keeps the
three A-entry 16–18 preconditions separate: date/location special case,
banked field 201 threshold, and latch `global_u8[1060]`. It also runs
executable audit v25 and requires the native command-`0x0B` true-fallthrough/
false-transfer and command-`0x0C` transfer contracts. The report contains no
dialogue or source payload bytes and rehashes both sources after the read-only
pass. The Event Player consumes only this fixed hash-bound matrix for row tags;
it does not derive new generic interpreter policy or automatically seed any
location/latch state.

The focused `kakyu_mes_promise_cei_date_routes_audit/v1` closes the former
presentation-boundary gap for `C/E/I_PROMIS.MES`. It resumes each exact
dynamic-name dialogue before routine 24, requires the 102-row library return and
one date writer, then reaches the exact ten-option selector after four dialogue
boundaries with `0401 -> 0402`. At unseeded location ID `0`, option 1 must retry
after two dialogue boundaries while options 2..10 complete after three,
writing flags `611..619` and paired times `1000..1800`. It rehashes the archive;
natural owner selection remains unresolved.

`audit_mes_promise_callers.py` now inventories the native activation boundary
behind those isolated starts. The configured original archive has 500 exact
literal command-`0x0F` PROMIS dispatches, owned by 146 address-table entries in
66 caller scripts, and covers every `A..L_PROMIS.MES` target. Audit schema v2
also requires every call block to have one resolved `0x0B` true edge and binds
all 500 to one of twelve target-specific `global_u8[index] == 1` flags. All
twelve targets enter at code coordinate zero and immediately use the identical
command-`0x14` selector-18 transfer to setup entry zero at `0x0008`. Executable
audit v25 cross-checks the branch's exact-one fallthrough rule, nested zero-
start/caller-coordinate restoration, and context-registration transfer. This
evidence does not identify the flag producers or later host selector for a
nonzero scheduling entry, so Event Player does not concatenate a map caller,
setup, and isolated date prefix or relabel it as a natural event. The report
contains hashes, names, counts, conditions, and code-relative coordinates only
and rehashes both original sources after the pass.

The no-window `audit_mes_promise_caller_reachability.gd` check independently
starts all 146 physical owners with their original address tables. A fresh
all-zero sandbox reaches none of the 500 stored PROMIS calls. The two owners
that first reach routine 27 are continued through the hash-bound routines 27,
25 plus registered DEF26, and 21; both then dispatch `L_OUTRO.MES`. The locked
terminal distribution is 140 returns, four other-script dispatches, and two
floor-script handoffs across 995 total trace rows. No probe reaches dialogue,
and the archive hash is unchanged. This prevents the GUI from promoting a
filename-owning caller to **Start Event** while the original incoming state and
host catalog selection remain unknown. Both the static caller/native audit and
this composed dynamic negative baseline are part of the aggregate original-
content validation batch.

Reachability audit v3 also tests every one of the 499 unique owner/target pairs
with only its v2-confirmed target gate set to `1`. All other state remains zero;
none reaches PROMIS or dialogue, with 493 returns, four other-script dispatches,
and two handoffs over 2,760 trace rows. Event Player therefore does not offer a
misleading target-flag-only caller start. The remaining implementation boundary
is the preceding state path and bounded nested `*_TALKxx.MES` call/restore, not
the immediate command-`0x0B` gate itself.

The original-corpus `audit_mes_promise_nested_calls.gd` check exercises that
next bounded layer for the two known `L_TALK30.MES` callers. With an explicit
conversation-state seed and `L_PROMIS.MES` immediate gate present, it runs both
local definition IDs as explicit tool choices, restores `44C.MES:#376` and
`L_HOTEL2.MES:#142`, and stops all four routes at their exact `L_PROMIS.MES`
dispatches. The PROMIS target is intentionally not present in the script map.
Routine-40 native choice logic therefore remains unresolved; the trace labels
each selection as tool input. The original executable v25 MES audit in the same
aggregate batch independently verifies the zero-start command-`0x0F` call and
caller-coordinate restoration used by the shared compositor.

Event Player consumes this contract only for the two exact original caller
hashes. Their confirmed address rows expose **Start Nested Dialogue**. The tool
loads the unshadowed original `L_TALK30.MES` through the shared resolver,
applies the documented seed to its isolated sandbox, and renders the reached
two-row local choice in the embedded game frame. Pointer, arrow/Enter, and
number-key confirmation rerun from the captured pre-choice sandbox snapshot,
so initialization effects are not applied twice. The chosen body returns to
the original caller and the frame explicitly reports the reached
`L_PROMIS.MES` boundary; that target is not executed. Any archive, entry,
overlay-priority, address-table, local-choice, or terminal-coordinate mismatch
disables or fails the route closed.

Trace rows identify their owning MES entry beside the code-relative offset, and
message rows identify both the owning MES entry and text source. A selected
root entry's UTF-8 cache or overlay projection is never applied to a nested
callee merely because its message has the same offset and raw hash. This keeps
multi-script previews auditable without confusing root and callee coordinates.
The adjacent **Script Calls** tab lists depth, caller/call coordinate, callee,
physical resume coordinate, and whether the callee has returned. A route paused
inside `L_TALK30.MES` shows `not returned`; after explicit selection the same
row shows the exact callee return coordinate while retaining the caller resume.
The same table also accepts detached registered-DEF provenance without placing
it in the game frame. Such a row is marked `DEF`, retains the outer MES or
parent-DEF caller coordinate, identifies the selector and startup registration
source, and shows the physical caller resume as bounded composition. It does
not claim that native routine 40 selected the outer body or that the registered
call represents a separate MES file dispatch.

Registered-DEF trace rows display their registered source entry beside each
code-relative body offset. For example, a body registered from `DEF_MAIN.MES`
must not inherit the selected caller entry's name in the Trace tab. Detached
preview status hints use a normal Unicode middle dot as their visual separator;
legacy half-width mojibake is rejected by the original-content GUI validator.

Content Core `0.104.0` advances Event Runner output to
`kakyu_mes_event_trace/v49`. A safe command-`0x0F` boundary now returns the
decoded instruction end as its physical caller resume and copies the tool's
currently evaluated argument slots and persistent expression stack. It still
does not open or execute the target, synthesize a return, or change sandbox
state. This makes a later explicit script-stack compositor consume one shared
decode result instead of rediscovering the filename envelope or resume
coordinate in tool-specific code.

Content Core `0.106.0` adds `kakyu_mes_script_call_trace/v1`. The shared
script-call runner accepts only an explicit case-insensitive map of safe MES
basenames to already parsed bytecode and address tables. A decoded command-
`0x0F` may enter a mapped target at coordinate zero; an unmapped or unsafe
target remains the original visible dispatch boundary. Caller frames retain
the exact v49 resume coordinate and the tool's temporary argument/expression
context, while every callee starts with a fresh temporary context and shares
only the caller-supplied isolated gameplay sandbox. A callee `script_return`
restores the preceding frame. Aggregate instruction, call-count, and call-depth
limits fail closed, and nested dialogue stops by default. An explicit
`dialogue_policy=continue` is available for read-only audits that need to cross
already decoded dialogue boundaries; messages retain their source entry and
call depth. This is a bounded tool composition policy built on the executable-
confirmed zero-start/coordinate-context restore sequence, not a claim that the
native engine separately stores the tool's argument and expression objects.
Content Core `0.154.0` makes the default visible nested-dialogue stop
resumable without forcing `dialogue_policy=continue`. Its versioned
continuation binds the full explicit script map, active LIFO frames, physical
caller resumes, call trace, and temporary argument/expression context. Resume
rejects changed bytecode/address tables and malformed or out-of-range frames
before execution. It can therefore cross the user-visible dialogue later and
return to the exact caller while keeping the gameplay sandbox shared. Event
Player route migration remains tracked by `P2-04`; this core contract does not
by itself promote unresolved host or shared-library calls.
Content Core `0.155.0` upgraded the Event Catalog play request to a source-bound
caller-frame form. Content Core `0.272.0` introduced
`kakyu_event_catalog_play_request/v4`. A `nested_call` request carries a deep-
copied, source-bound command-`0x0F` caller frame (caller entry/hash, dispatch,
and physical resume) alongside the callee start and a
`kakyu_event_catalog_terminal_contract/v1`. The terminal lifecycle explicitly
orders callee return, caller post-event presentation, normal completion, early
end, rejection, and unresolved outer-host stages. Exact runtime status, state
assertions, and next-target matching prevent a raw script return from being
promoted to completion. A `root_replacement` request has no caller frame: it
binds the command-`0x0E` source record and zero-start target and requires a
confirmed callee-owned replacement terminal with a named next root. The current
Event Player revalidates the open source profile, exact command-`0x0E` record
and physical end, zero-start target, and all required entry hashes before using
an event-specific root adapter. Before any source lookup or session mutation,
it also rebuilds the complete root Play request from the loaded catalog and
its explicit preset ID. The request must equal that canonical copy, including
preset writes, dependencies, compatibility and terminal contract. A changed
copy cannot retain the original preset ID while injecting other state or
dropping a required source. Missing/unknown presets and stale catalog requests
fail closed. This root-only guard does not change the separately validated
workspace-preset workflow for nested events, and it introduces no schema or
original-engine semantic change.

The browser's **Preset** selector is bound to the selected event, and both
readiness and Play build a request with its explicit preset ID. Switching
events selects that event's first original-branch recommendation. Refreshing
the same event retains the ID; missing or removed selections disable Play
instead of silently choosing another preset. Filtering away the selection
clears it. Analysis/remake-only presets remain visible but cannot enable
ordinary catalog playback. Selecting a preset changes only catalog details,
not the active source, sandbox or running session. Full labels and notes are
available in the details/tooltip without expanding the logical gameplay frame.

EVENTB03 retains `captured-result3-original` as its default three-field fresh
preset with choices 1-3. The additional `source-state12-100` profile adds only
`state_u16[12]=100` and allows results 1-3. The choice projection
freezes its preset ID, exact writes, allowed result list and complete current
snapshot. Canonical catalog JSON numbers are compared by scalar value against
the typed profile, without lossy integer truncation. Failed B03 qualification
at choice activation remains read-only and cannot fall through to the generic
routine-40 bridge or detached analysis. Unsupported rows remain visible with
an explicit label and cannot write the result. Source evidence for the 18
suffix dialogues and temporary/restored slot-12 value is in
`docs/spec/mes/eventb03_state12_routes.md`. Other audited values, host states
and native effects are not automatically promoted. No catalog or Core schema
change is required; this uses the existing multi-preset contract.

Catalog revision 13 adds two more exact result-2 representatives,
`source-state12-100-affection36` and `source-state12-100-affection76`.
They retain the initial-100 state12 profile and set bank-0 `banked_u16[210]`
to 36 or 76. The original suffix subtracts 5, so the nested B_PIC contract
requires 31 or 71, respectively. Its exact trace, BAN/B.AX marker offsets,
binding and state diff select row-0 column 0 (middle) or 2 (high), not the
baseline column 1. In particular `global_u8[3005]` remains zero for the middle
path and becomes 2 for the high path; an empty middle-path diff is expected,
not evidence that B_PIC did not run. The controller revalidates the canonical
preset again before live B_PIC execution. Unknown values or mismatched
profiles cannot reuse another preset's picture contract. Face-override flags
204/207/628 must remain zero. B_PIC executes in a disposable cloned state and
commits its snapshot only after all trace, binding, state and media checks
pass; a rejected probe cannot leave partial state writes live. Existing default and
initial-100/zero-affection behavior is unchanged. These are source-audited
isolated-state representatives, not original-runtime captures or proof that
the native station scheduler can trigger the event in those states. Evidence
and numerical coverage live in `docs/spec/mes/eventb03_affection_routes.md`;
the two new result-2 expressions have passed user-controlled acceptance in MV-10.
Remaining preset-reset and active-session isolation controls stay pending in MV-09.

Catalog revision 15 qualifies results 1/3 for all three initial-100 profiles,
without adding presets or widening dates. The exact initial 36 profile yields
38/31/39 for results 1/2/3, and initial 76 yields 78/71/79. The picture
contracts use those explicit result/value pairs, not a general affection-band
rule. Initial zero retains 2/0/3 and the low face. Results 1/3 never write
state12 or bank-0[251]; state12 remains 100 throughout. Each route keeps the
same branch-local library/DEF/native/camera/audio boundaries as its baseline.
All three rows are now playable for each supported preset, superseding the
earlier initial-100 row-1/3 restriction. Frozen-state, canonical-request,
unknown-profile and transactional B_PIC rejection remain unchanged. The
independent source matrix and full live regression, rather than a permissive
fallback, qualify the added six routes. Evidence is in
`docs/spec/mes/eventb03_preset_choice_routes.md`. MV-11 owns the new grouped
result-1/3 presentation check; prior result-2 acceptance is not reused as
acceptance of newly enabled choices.

EVENTB03 reaches its first original dialogue
from a caller-free zero-coordinate session after consuming only the exact
bounded setup records. The source-qualified third result carries that session through registered DEF
22/21, seven byte-exact metadata-only native-stream omissions, the exact
`B_PIC.MES` presentation return, and the callee-owned `MACHI.MES` root terminal.
Catalog revision 10 also accepts results 1/2 for the same fresh three-field
starting preset. A branch table binds each B_PIC caller/resume, expected
affection and MACHI terminal: result 1 uses `0x1615/0x1622`, affection 2,
terminal `0x1BB6`; result 2 uses `0x2238/0x2245`, affection 0, terminal
`0x26F4`. Result 3 retains `0x37B9/0x37C6`, affection 3 and `0x3D46`.
Every terminal additionally requires matching `state_u16[21]`; a boundary
from another branch cannot complete the route. Choice confirmation validates
the frozen sandbox snapshot and the qualified starting fields before writing
the result. The new branches reuse existing shared-library DEF execution,
station/B_PIC composition, voice, selector-133 audio and station-map rendering;
they do not enable the result-3-only camera or routine-9 impact sequence.
The stable preset ID and private projection kind retain their `result3` names
for compatibility. The row remains partial because additional starting
states beyond the explicit representative profiles are unqualified and native
presentation equivalence is not established. See
`docs/spec/mes/eventb03_choice_routes.md` for ARC/EXE evidence and
`validate_event_player_eventb03_choices.gd` (retired 2026-09-21, EP-10 unit 5c;
B03 is covered by `original catalog group routes`) for the complete live headless
routes. The baseline choices were accepted in MV-08; the initial-100 route
was separately accepted in MV-09, whose remaining selector checks stay open.
The same result-3 adapter now keeps the event-local B03/B03A/B05SS backgrounds,
uses their exact row-0 cell-0 AX plans instead of displaying AN source strips,
plays the two routine-23 source-bound cues on a separate effect channel, projects the
oversized B05SS crop with an explicitly unresolved native cadence, and replaces
the terminal frame with the original-ARC MACHI preset-16 station projection.
The former eight-second load-time pan is replaced by exact-source-command
stops at `EVENTB03.MES:0x32F9` (mode-7 automatic round trip) and `0x3316`
(mode-8 manual pan, then animated return). Initial loading is stationary.
Core `0.274.0` adds the reusable `KakyuOversizedCgCamera`, projecting the audited
geometry and nominal 15-ms deadlines onto a deterministic tool clock. Mode 7's uninterrupted budget
is 6205 ms; mode 8 waits for drag/arrows and Enter or **Finish CG inspection**,
then returns over distance-dependent samples before resuming MES at `0x332E`.
Click/Space cannot advance dialogue while camera input is owned. Esc releases
focus; loss of focus cancels dragging. Automatic/return phases cannot be
skipped by dialogue controls. Preview labels distinguish tool clock from
native cadence. Full entry/source, command hash/extent and source-9 image
checks keep this adapter limited to the audited B03 route.
The camera displays source-9 crops only and pauses/suppresses AX under an
explicit conservative tool policy, not a claim about native graceful-stop
timing or message-driven overlap. The exact post-camera B05SS binding and
activation reset its retained plan rather than resuming a stale cursor.
`audit_eventb03_camera.py` verifies original records, EXE spans and current
GDScript framing. See `docs/spec/mes/character_events.md` for native evidence;
PR-02 retains unresolved native timing, x87 intermediate pixels and AX overlap.
The result-3 beating sequence additionally consumes the original routine-9
`se.arc` path: the first blackout pair requests `KSE00131.WAV`, then
`KSE00130.WAV`; four later requests remain in source order. Each of the six
caller occurrences validates its MES/library identities, exact call and typed
audio-request boundaries, channel 0 and original WAV fingerprint before using
the normal effective-media resolver. WAV decoding is exercised even headless;
headless validation does not claim audible device output. The source-qualified
routine-9 projection stages argument slots 1/2 into matching `global_i32`
locations only in a disposable sandbox, verifies no subsequent state writes,
and discards it. This does not silently change the general runner argument ABI.
Playback starts before the caller reaches its exact following native wait.
The source counter thresholds 6/13 are projected onto a 15-ms tool clock:
90/195/90/195/90/90 ms for the six calls. During each wait, catalog autodrive
and dialogue input cannot advance the caller; the next channel-0 cue explicitly
restarts the sound, even when the previous WAV is unfinished. BGM is unchanged.
Reset discards pending waits and decoded effect state. Occurrence receipts,
not unique filenames, verify repetition. Native early-input interruption,
device latency and exact wall-clock cadence are not claimed. Evidence and
reproduction commands are in `docs/spec/mes/audio.md`.
Before the later B_PIC standing scene, the exact EVENTB03 session and captured
MMDD 413 / HHMM 1825 state select the hash-qualified original `01MA_3.MMO`
through the normal media resolver, following the original station-entry and
event-tail routine-27 selector-11 branches. A non-640x400 effective
background is rejected. The transition releases the oversized CG/camera and
old AX plan, replaces the compositor checkpoint, then composes B1/BAN/B.AX;
it must not leave an event CG behind the standing layer. Resource selection
and the routine's surface-2-to-1 producer are source-confirmed; complete native
refresh/lifetime and cadence remain unresolved. The terminal uses station EVE
16 and reads CCD preset 16's paired camera/actor bytes, not record 0. It uses an
in-bounds static entrance frame and does not resume native retained map input.
This pre-B_PIC station interior is distinct from the later MACHI station map.
The B03/B03A/B05SS AX contract additionally requires the exact `eventb03`
session and selected `EVENTB03.MES` entry, including direct contract inspection.
The shared activator restricts EVENTB14 to B/B14 AX and EVENTB03 to B/B03/B03A/
B05SS AX. Session, resource, contract, and source-image validation precede
stopping the current animation; rejected requests retain the live plan and
source. This is a tool isolation guarantee, not a new original-engine semantic
claim or a promotion of another event's presentation support.
Ordinary Event Player Playback now consumes this contract directly. It first
checks that the request copy still equals the contract derived from the loaded
catalog, then matches the runtime owner entry, offset, result class, state, and
target. Nonterminal stages continue through the existing source-bound caller
frame; only an exact route-ending match gets a generic ended screen. The
original-content catalog validator drives EVENTB01 through its final
`13C.MES` to `MACHI.MES` handoff and verifies that the external host remains
unexecuted and every source ARC remains unchanged. This controller integration
is Content Core `0.164.0`; persisted catalog, play-request, and terminal schema
identifiers are unchanged.
Content Core `0.165.0` makes that contract the sole ordinary-Playback completion
classifier after source-bound startup. Route-local completion predicates remain
available to Analysis, but they can neither promote nor veto a catalog ending.
A changed contract is rejected before startup, and a changed observation at a
cataloged terminal coordinate is rejected before its continuation executes.
Content Core `0.156.0` adds `kakyu_event_player_caller_frame/v1`. Before a
confirmed Start changes presentation or isolated state, Event Player rereads
the request's exact caller command-`0x0F`, verifies its target and physical
resume, and binds the caller/callee fingerprints. EVENTB01, EVENTB02, EVENTB14,
EVENTB15, EVENTD01, EVENTD02, EVENTD03, EVENTD08, and EVENTD14 use this one
common frame across each supported path. The eight routes with confirmed caller
completion retain it through callee return and the final handoff. EVENTB15 uses the same frame for
its direct 11M.MES suffix without a caller BGM stage. EVENTD08 uses a versioned
restore-follow-up adapter: the frame reaches the exact 12C.MES resume, validates
the intervening D_PIC.MES dispatch and source identity, carries temporary
argument/evaluator state into the caller-owned dialogue, and remains active at
the MACHI.MES handoff. A changed or absent frame fails closed before caller
code. The old event-specific, frame-less postlude/handoff continuation kinds
and their one-line execution wrappers are removed: a matching callee return or
caller offset is evidence available to Analysis, not authority to synthesize a
call frame. EVENTB14 retains the frame across its explicit cloned outcome
projections but intentionally does not resume the live caller: the exact
`44M.MES:0xC925` suffix reaches a second caller-owned routine-40 choice at
`0xFFBA`. Its one-based result is confirmed; its dynamic list, native UI,
wall-clock cadence, and effects remain P2-07 work. Any newly confirmed
command-`0x0F` route must provide the same source-bound frame contract before
ordinary playback can enter its caller continuation.
Executable audit v66 narrows that routine-40 input gap without claiming a
complete native UI. The original modal update samples `GetCursorPos`, converts
the point through the active window, selects one of two control-owned hit
tables, and stores the first ID whose inclusive 10-byte rectangle contains the
point. IDs `0x0100/0x0102` feed signed deltas `-1/+1` to a shared helper that
clamps the visible-window start to `0..count-1`; neither ID proves row
selection. The control is a parent `+0x60` subobject, and the audit now binds
its two table pointers to complete embedded EXE `AREA` resources 142/143,
whose exact hit-ID domains are `{0x0000,0x0001}` and
`{0x0100,0x0101,0x0102,0x0103}`. They are not `PARTS.MMO` metadata. Event
Player may reproduce that coordinate classification and bounded window
navigation. The selected mode-1 control owns a different dynamic hit table:
zero in the ID high byte marks a selectable row, the low byte is the visible
row ordinal, and confirm adds the current window start, bounds-checks it
against the total count, resolves the routine-40 mode-0 host row mapping, then
adds one. This proves that none of the modal `AREA` IDs is a choice row and
fixes the original one-based pointer-row result path. V62 also binds the input
edge. The application key object at `+0xF0` receives `WM_LBUTTONDOWN`, captures
the game window when needed, and stores a left-button latch at object `+0x1C`.
Modal update tests that latch only while modal `AREA` ID `0` is active, invokes
the modal confirm slot `+0x0C`, calls the selected control's confirm slot `+4`,
copies its one-based value to the modal result, and stops the modal. The exact
`WM_LBUTTONUP` jump-table case releases capture and clears the latch. This is a
down/held latch sampled by update, not evidence for a separate button-up
activation. `AREA` ID `1` has two source-bound paths: bytes `+0x3DF`, `+0x3E0`,
and `+0x3E1` all zero call helper `0x00435850` and return without a direct
modal-result copy or modal stop; otherwise the callback falls through to the
selected-control confirm path. V64 also locks the two remaining primary-table
branches. ID `0x0101` conditionally updates native control bytes `+0x3DC` and
`+0x3E0` across fixed helper/application calls; ID `0x0103` clears `+0x3DC`
before its own fixed helper sequence. Neither branch directly copies a modal
result or stops the modal, so Event Player may describe them only as auxiliary
control/presentation-state actions. Their shared exact helper chain prepares a
document region at `0x00434950`, runs presentation update `0x00435730`, and
tail-dispatches the current document embedded object's virtual slot `+0x3C`
through `0x0043FFC0`. The update temporarily sets/restores document byte
`+0xB7A`, clears then sets flag `0x10` at `+0x20BC`, and forwards a rectangle
derived from `+0x20C2/+0x20C4/+0x20C6/+0x20C8`. ID `1`'s visible label,
`0x0101/0x0103` user-facing meanings, sound, redraw, and the
remaining callback effects stay unresolved and are not synthesized as original
behavior. V65 now binds the complete `0x00401E20` mode-1 navigation function
and its `0x00411450` row-rectangle lookup. Total count `+0x2C`, window start
`+0x30`, and ordinals `0..2` define exactly three visible rows. Up at ordinal
zero decrements the start only above zero; Down at ordinal two increments it
only below `total_count - 3`. Absolute first/last rows are clamped and never
wrap to the opposite end. The matching dynamic 10-byte row rectangle is
resolved by ID and its midpoint is sent to the existing cursor adapter. This
is sufficient for a faithful three-row non-wrapping remake list. V66 also
binds the complete 523-byte modal runner and its complete 259-byte message
pump. Every DirectInput binding is a level-state query performed again on each
modal iteration, so a held direction can dispatch once per completed
iteration; there is no local first-repeat delay or fixed repeat interval. The
active-window pump calls `Sleep(0)`, while an inactive window calls
`Sleep(30)`. The original wall-clock repeat rate is therefore host message-pump
and scheduler dependent rather than a fixed millisecond value that Event
Player should invent. The remaining auxiliary labels and callback effects are
still unresolved.
Executable audit v67 binds AREA ID `1`'s complete 1,339-byte helper and all
three callers. For a nonempty record list it stores `count - 1` as the visible
window start, toggles mode byte `+0x43D`, and either activates document
rectangle `(34,316)-(578,376)` or restores the rectangle saved at `+0x414`.
The paired paths refresh the 640x400 surface/document state but never copy the
modal result or stop the modal. Event Player may describe this as a
nonterminal presentation-region toggle. It must not label it cancel/back or
a choice row, and the native visible label remains unresolved.
Version `0.106.0` also retains a nested script's unresolved local-DEF selection
records and annotates each definition and its message projection with the MES
source entry and script-call depth. It still performs no native selection.
The same version accepts an optional ordered `local_definition_choices` array
from a tool or audit. Each ID is consumed only at a reached local-DEF boundary,
must match exactly one structurally bounded definition, and executes that body
before normal script return/caller restoration. The default remains a visible
stop. Every consumed choice is marked `selection_policy=explicit_tool_choice`
in the boundary trace; it is user/tool input, not reconstructed native choice
logic. Missing IDs, malformed bodies, and invalid choice input fail closed.

Content Core `0.106.0` keeps the fixed `banked_u16[0][0]` word outside authored
sandbox records alongside the byte baseline. Event Player now activates both
only when `mes.arc`, `START.MES`, `LIBLARY.LIB`, `DEF_MAIN.MES`, startup
registrations, and the reconstructed table hash all match the audited original
set with no overlay substitution. Source or overlay changes clear the native
layout. Sandbox reset and JSON load reapply it after validation; a loaded
record cannot replace the audited bank-zero base. The toolbar status appends
`calendar state active` so the condition is visible. With a valid legacy date,
manual `DEF_MAIN.MES:0x04A1` execution can now leave DEF12's sentinel loop and
stops at shared routine 26. The existing explicit **Continue** action executes
the bounded library runner; for the audited date states it returns to DEF12 at
`0x0EF5` and finishes at `0x0EFA` without an additional sandbox change.

All 1,727 MMO headers passed. The source-bound compatibility matrix contains
302 primary dimension pairs and three conservative profiles. Exactly 1,718
entries use the standard profile: the observed reserved fields are zero,
primary and secondary dimensions match, and the control and trailing fields
are zero. Eight entries (`DIALOG00..04.MMO`, `FRAME.MMO`, `PARTS.MMO`, and
`VOL.MMO`) retain a nonzero trailing field. `CALFACE.MMO` alone has control
value 3 and different primary/secondary dimensions. No original entry is
unclassified. These are archive observations, not names for unconfirmed native
field semantics: executable audit v69 still proves only the named MMO load and
decoder path, not the special fields' ownership or relocation rules.

A representative standard `640x400` entry decoded strictly. The same
representative is encoded with its original 0x28-byte header and decoded again;
the validator requires an identical header and RGB pixel buffer but does not
require identical compressed bytes. `CALFACE.MMO` is the one known short
stream: it produces 22,248 of
22,464 expected decoded bytes. The shared codec rejects it in strict mode and
allows exactly 216 zero-filled bytes only when the caller explicitly requests
preview padding, matching the prior extraction tool while keeping the anomaly
visible. Its exact special header can be preserved for remake preview output,
but the encoder and Image Editor refuse to label that output original-engine
compatible. Image Editor displays the profile and header provenance for every
decoded or pending MMO. Event Player reports the same structural profile next
to the effective content compatibility, so an overlay with a standard-looking
generated header remains visibly `remake_only`.
