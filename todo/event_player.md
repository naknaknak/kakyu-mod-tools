# Event Player TODO

This tracker owns original-event playback and analysis UX built on Content Core
contracts. The owner closed scope to originals on 2026-09-08; added/removed mod
events and edited MES/dialogue/media playback are not completion requirements.
EP-07, EP-08, EP-12 and EP-14 are closed (EP-12 by the owner on 2026-10-05, EP-14 by its whole batch on
2026-10-11); the [Execution Order](../TODO.md#execution-order) names the next work.
This tracker consumes analyzer evidence from `mes_analyzer.md` but does not
duplicate analyzer checkboxes or technical proof history.

In the MES maturity roadmap this is a **Phase 7 consumer**. Dependencies on
Phase 2 framing, Phase 4 flow, or Phase 6 compilation do not move Event Player
work into those phases and do not duplicate their completion gates here.

## Implemented Baseline

- [x] Playback and Analysis views use the same isolated runtime objects.
- [x] The searchable original-event catalog contains 13 seeded routes: six
  `complete_playback`, five `partial_playback`, and two `analysis_only`.
  (Historical; since 2026-09-21 the catalog is 142 generated rows, 139
  `minimal_playback` and 3 `analysis_only` - EP-10 unit 5; since
  2026-09-23, catalog revision 26, all 142 `minimal_playback` - EP-03.)
- [x] Catalog presets are source-bound and applied before execution with a
  versioned receipt.
- [x] Confirmed nested MES, registered-DEF, and shared-library continuations use
  source-bound caller frames and fail closed on changed inputs.
- [x] Catalog terminal contracts distinguish continuation, return, completion,
  rejection, and unresolved outer-host handoff; representative EVENTB01 reaches
  the generic final screen.
- [x] Original evidence remains separate from effective overlay or verified
  materialized-media identity.

## Open Work

- [x] **EP-01 — Consume routine-40 results only where source-qualified.**
  - Keep the reusable one-based result bridge for confirmed simple and DENSHA
    consumers.
  - [x] Define a path-free, source-revalidated product plan that maps one exact
    live numeric pair from MA-06 to its stored consumer, stored fallback, or
    empty-list stop, with only the confirmed slot-21/slot-13 writes and a
    `remake_only` compatibility ceiling.
  - [x] Make grouped Analysis obtain consumer/fallback hints and accept the
    empty-list terminal only through that validated plan, without mutating the
    live sandbox or enabling consumer/caller execution.
  - [x] Keep 43C's conditional second-stage UI analysis-only until Event Player
    retains the required source-bound caller frame and consumes the plan
    transactionally. Native row meanings, effects, and cadence remain outside
    this contract.
  - Closed at the safe promotion boundary: confirmed simple and DENSHA bridges
    execute their source-qualified contracts; grouped 43C results cannot write
    state or enter a consumer merely because a numeric route is known.
  - Legacy: product portion of P2-07.
- [x] **EP-02 — Promote EVENTB03 ordinary playback.**
  - [x] Reduce the target-qualified observations to the structurally minimal
    result-3 candidate `state_u16[4]=6`, `state_u16[19]=1825`; exact deletion
    replay proves `[7]` and entry-overwritten `[8]` unnecessary while either
    retained field changes both later routine-25 traces when removed.
  - [x] Execute the exact nested `B_PIC.MES` target in the cloned result-3
    route. Presentation replay additionally requires `state_u16[7]=413`,
    reaches routine 22 at `0x035B/0x0360`, composes `B1.MMO` with
    `BAN.MMO`/`B.AX` low-affection column 1, and returns at `0x0759`.
  - [x] Wrap the three-field presentation candidate in the source-qualified
    `captured-result3-original` catalog preset and reapply it transactionally
    to a fresh isolated state before reproducing the exact result-3 route.
  - [x] Bind the seven post-choice command-`0x0D` character streams to their
    exact original `[start,end)` records and shared native draw/cursor/refresh
    handler. Product omission may now consume these records as typed metadata;
    native glyph pixels and cadence remain presentation-owned.
  - [x] Consume the seven bounded native character spans only through the
    original-hash/session/byte-exact Event Player allowlist, exposing an
    explicit metadata-only omitted-FX continuation and failing closed on any
    changed record or decoder boundary.
  - [x] Define a versioned caller-free `root_replacement` Play request that
    separates exact command-`0x0E` activation/end bounds from command-`0x0F`
    caller-resume semantics and requires a confirmed callee-owned next-root
    terminal. Event Player remains fail-closed for this model until execution
    integration is complete.
  - [x] Revalidate a root-replacement request in Event Player against the open
    source profile, exact command-`0x0E` record and physical end, zero-start
    target hash, and every required entry before any executor mutation.
  - [x] Start the exact EVENTB03 caller-free root session internally, consume
    only its byte-checked `0x011B..0x0131` setup pair through the bounded omit
    policy, and stop at the first original dialogue `0x039F`.
  - [x] Bind the live three-row routine-40 choice to the source-qualified
    result consumer, keep all three original labels visible, reject unresolved
    results 1/2 before state mutation, and let only confirmed result 3 write
    `state_u16[21]` and resume at the exact first suffix dialogue `0x276C`.
  - [x] Continue the live result-3 session through registered DEF 22/21, all
    seven exact metadata-only native-stream omissions, the exact `B_PIC.MES`
    presentation return, and the callee-owned `MACHI.MES` root terminal.
  - [x] Promote ordinary playback through the confirmed command-`0x0E`
    root-replacement activation and terminal contract. Catalog status is
    deliberately partial. At EP-02 closure results 1/2 remained fail-closed;
    their subsequent scoped promotion is owned by EP-03 below.
  - Depend on MA-06/MA-07 and presentation ownership without treating native
    pixels or cadence as analyzer completion requirements.
  - Legacy: P2-10 and the explicit EVENTB03 deferred item.
- [ ] **EP-03 — Complete original-derived normal-route support.**
  - [x] Bind EVENTB03's B03/B03A/B05SS event backgrounds to their exact AN/AX
    row-0 cell-0 plans, keeping source atlases hidden and preserving every
    audited draw-record and timeline boundary.
  - [x] Route exact EVENTB03 `H_H_H`/`KSE0069` timed requests through an
    independent effect channel and retain the scene BGM.
  - [x] Project the oversized B05SS source crop with visibly labeled unresolved
    native cadence, then replace the result-3 terminal with the source-ARC
    MACHI preset-16 night station frame (station EVE/01M mapping checked).
    The earlier load-time approximation is superseded by the source-ordered
    mode-7/mode-8 tool-clock implementation tracked only in PR-02.
  - [x] Isolate EVENTB03 scene AX contracts from other event sessions and
    reject mismatched activation before interrupting the current animation.
  - [x] Correct B05SS screen-space AX attachment in the legacy projection.
    The subsequent source-9-only camera and post-camera rebind supersede that
    shared-translation policy; implementation/lifetime tracking lives in PR-02.
  - [x] Replace the event-CG checkpoint with the original routine-27
    selector-11 `01MA_3.MMO` background before B_PIC for the captured date/time;
    verify the station-entry and event-tail producers separately from native
    refresh/lifetime. The earlier `01MM_3.MMO` filename guess is superseded.
  - [x] Qualify EVENTB03 results 1/2 for the existing three-field isolated
    preset: 19/20 suffix dialogues, exact B_PIC calls with affection 2/0,
    station restoration, selector-133 sound and distinct state-bound MACHI
    terminals. Frozen choice-state and per-branch caller checks reject drift.
    ARC/EXE/headless evidence is in `docs/spec/mes/eventb03_choice_routes.md`;
    user-controlled presentation acceptance remains owned by MV-08.
  - [x] Audit result 2's `state_u16[12] > 99` branch at six numeric inputs and
    qualify only the explicit initial-100 product representative: 18 suffix
    dialogues, temporary zero, source restoration to 100, unchanged B_PIC and
    station terminal. Add generic explicit catalog preset selection; bind the
    preset ID/writes, frozen state and supported results (only 2 for this new
    profile), including fail-closed activation without generic-choice fallback.
    Evidence: `docs/spec/mes/eventb03_state12_routes.md`; UI acceptance: MV-09.
  - [x] Qualify the exact initial-affection 36/76 result-2 representatives
    with initial `[12]=100`: source subtraction yields 31/71 and B_PIC
    selects middle/high column 0/2. Bind the complete trace, marker/binding
    offsets and the distinct nested state diffs to each profile. All other
    inputs remain audit-only. Evidence: `eventb03_affection_routes.md`;
    user-controlled expression acceptance passed in MV-10.
  - [x] Qualify results 1/3 for the three existing initial-100 profiles:
    preserve state12 throughout, bind exact +2/+3 affection results and each
    B_PIC face trace, and retain the branch-local dialogue/library/DEF/native/
    camera/audio/terminal contracts. The new six-route source audit and
    eleven-route live regression passed; no new preset or date is implied.
    Evidence: `eventb03_preset_choice_routes.md`; grouped UI check: MV-11.
  - [x] Audit globals 204/207/628 through 72 zero-entry source routes,
    including combined flags, post-choice 70/71 and 80/81 neighbors, and
    exact-equality discrimination for 2/255. Verify unchanged outer traces,
    complete final state and B_PIC bindings without adding a product preset.
    All four existing presets still reject those nonzero flags at request,
    choice and picture boundaries. Evidence: `eventb03_face_flag_routes.md`.
  - [x] Extract a read-only source-bound routine-27 selector-11 station
    background plan: follow numeric date/time guards, retain the selected MMO
    marker and explicit keyed surface-2-to-1 copy, and stop before routine 8.
    Audit all 12 producer arms / nine assets and consume the plan in the
    existing EVENTB03 413/1825 background guard without widening presets.
    Evidence and remaining native boundary: `station_background_selection.md`.
  - [x] Extract the read-only original B_PIC standing-selection plan with
    fixed g206=1: audit B1/B2/B3/B4 date guards across the unsigned-word
    domain, preserve dynamic copy ASTs, and stop before routine 22 or at the
    no-load face join. Require its existing B1 boundary in the transactional
    EVENTB03 picture probe without replacing full-trace/media/state guards
    or widening the four playback presets. Evidence: `mahoko_standing_selection.md`.
  - [x] Extract the read-only `01M.MES:0x7691` EVENTB03 candidate plan:
    preserve the exact eleven-field predicate and true-arm checkpoints, then
    stop at the named script-handoff record. Keep upstream preemption,
    native address-row selection and natural scheduler eligibility explicitly
    unqualified; do not add a date/state preset. Evidence:
    `eventb03_candidate_entry.md`.
  - [x] Extract the preceding 15-guard station priority plan from the exact
    `01M.MES:0x026D` source order. Require every referenced numeric cell,
    stop before the first matching candidate body, and join the existing B03
    local plan only when all 15 guards are false. Keep shared/native prefix
    completion, host zero-start, address-row selection and natural scheduler
    eligibility unqualified; add no product preset. Evidence:
    `station_candidate_priority.md`.
  - [x] Freeze the exact `01M.MES:0x0008..0x026D` conditional source prefix
    as a read-only structural plan: retain all 103 typed records, the bounded
    16-iteration local loop, the two-arm surface join and every ordered
    external/native checkpoint. Do not compute a post-prefix state or claim
    external completion, host zero-start, address-row selection or natural
    eligibility. Evidence: `station_candidate_prefix.md`.
  - [x] Compose the 15-guard priority plan and B03 candidate plan over one
    exact 79-cell caller-supplied snapshot at the assumed `0x026D` cascade
    entry. Stop at the first upstream true boundary without evaluating B03;
    otherwise classify the B03 guard's true or false boundary. Keep prefix
    completion, host entry, native row selection and natural eligibility
    unqualified, execute no body or handoff, and add no product preset.
    Evidence: `station_eventb03_decision.md`.
  - [ ] Qualify further starting-state branches before widening playback,
    including other dates or flag-dependent expressions. Current support
    is all three choices for the fresh baseline and three explicit numeric/affection
    representatives; source audits do not imply native scheduler eligibility
    or universal starting-state support.
  - [x] Bind the complete root-replacement Play request to a freshly rebuilt
    catalog/preset copy before source access or mutation. Reject changed
    preset writes, dependencies and terminal metadata without disturbing a
    running session; leave nested-event workspace presets unchanged.
  - The former P2-10 edited-MES/media expansion requirement was withdrawn by
    the original-only scope decision. Existing mixed-content paths are EP-08
    transition debt; they are not an EP-03 prerequisite.
- [x] **EP-07 — Bound the event corpus from the authoritative caller graph.**
  **Closed 2026-09-19 by owner ruling (option 1 of two).** What the item asked
  for exists: the literal dispatch graph is complete (10,474 records, zero
  dangling), every EVENT-named target is classified with per-entry evidence
  (169 rows, 11/37/1/120, the 120 all analysis-group measured), the intro
  frontier closed on 2026-09-14 (every intro of every caller declared), the
  arrival declarations of every measured origin closed the outer-eligibility
  question on 2026-09-15 (TODO.md step 1.2: the map polls of MACHI, the
  floors and GROUND declared the way TRAIN's was, 138 profiles), package
  membership of the measured routes landed under WD-21 on 2026-09-16, and
  since 2026-09-19 every one of the 142 registry sites has a projected v4
  document. The one unchecked sub-item below ("wider outer eligibility and
  remaining branch states") described exactly the 2026-09-15 closure in its
  own last sentence and is marked closed on that record. What stays open
  lives elsewhere by design: catalog promotion of measured groups (option
  (a) of the 2026-09-14 ruling, a later owner decision), further branch
  states only where they close a blocker (EP-03), and the whole-tree batch
  (EP-05 / WD-18, started the same day at Core 0.350.0).
  - **Historical: was IN PROGRESS as the primary priority, clarified by the owner 2026-09-08; EP-07 closed 2026-09-19.**
    Complete event-route analysis before remaining app identity/distribution
    polish. Advance by source-bound route groups across the whole corpus;
    isolated catalog additions are increments, not the final coverage goal.
    Include existing partial/analysis-only seeds and participating non-EVENT,
    shared-routine, registered-definition and address-table paths. Every group
    records intro/guard evidence, explored branch/choice states, state effects
    and exact terminal or specifically evidenced unresolved boundaries, with
    EP-05 regression. Unresolved native presentation is labelled, not a reason
    to postpone structurally supported event analysis.
    The intro frontier closed on 2026-09-14 at Core 0.318.0: every EVENT
    intro of every caller is measured and declared (128 profiles; 169 rows
    at 49/120/0 over 156 bound; no structural row). The four items the
    2026-09-14 sort ordered under TODO.md step 1 closed by 2026-09-15: the
    full batch on 0.318.0, the arrival declarations of every measured origin
    (138 profiles; classification unchanged), the classification ruling (b)
    and MA-11. What remains of this item is the branch-state sub-item below,
    taken only where it closes a blocker, and the package membership of the
    measured routes, which [TODO.md](../TODO.md#execution-order) orders under
    WD-21 (2026-09-16 sort, step 2).
  - [x] Inventory every literal script dispatch in the authoritative archive:
    10,474 records across all 1,016 MES/LIB entries, 312 callers, 587 targets,
    zero dangling targets and zero decode failures. Command `0x0F` is fully
    literal and command `0x0E` partitions into exactly two decoded ops with no
    residue, so the literal dispatch graph is complete rather than sampled.
    The archive partitions into 587 dispatch targets and 429 entries never
    named by a literal record; that set is a candidate pool, not a
    reachability claim, because shared-routine, registered-DEF and native-host
    entries appear in it. The scan independently reproduces
    `MACHI.MES:0xACB1 -> 01M.MES` and `01M.MES:0x788F -> EVENTB03.MES`.
    Evidence: `docs/spec/mes/event_corpus_inventory.md`.
  - [x] Classify each of the 129 reachable EVENT-named targets, and the
    non-`EVENT` callees that participate in event routes, into the catalog's
    `playable_event`, `duplicate_route`, `system_script`,
    `unreachable_stored_route` or `unresolved_route` classes with per-entry
    evidence. Filename family is an index, not evidence. The 17 multi-site
    targets are the `duplicate_route` candidate pool. This item named
    `EVENTA13.MES` and `EVENTL09.MES` as the `unreachable_stored_route`
    candidates; measurement on 2026-09-09 left only `EVENTL09.MES`, because
    `FLOOR4.MES:0x0E4C` names `EVENTA13.MES` in an opaque tail. Evidence:
    `docs/spec/mes/dispatch_naming_reachability.md`.
    A first source-bound index covers all 129 targets, two undispatched EVENT
    entries and 38 direct/shared non-EVENT dependencies: eleven qualified playable
    events, four catalog-qualified system scripts and 154 explicitly unresolved
    rows. Python audits all 10,474 caller records against originals. Reproduction
    and four evidence-mutation rejections pass; the original inventory batch
    checks the index (2/2 with parse). Semantic qualification remains open;
    assigning unresolved labels does not close this checkbox.
    **`unreachable_stored_route` has its first row, 2026-09-10.** `EVENTL09.MES`
    is classified on a scan of every shipped file - eight archives, the
    configuration and the executable, about 1.5 GB - in which its name occurs
    **zero times**, with `EVENTL10.MES` as the control at exactly its two
    measured dispatch records. The reason also records why the entry exists: its
    53 message records are byte-identical to `EVENTL10.MES`, which is dispatched,
    and the twin carries seven voice markers where L09 carries none, so this is a
    stored pre-voice build rather than an orphan. That is deliberately not filed
    as a `duplicate_route` claim, which would assert catalog ownership that does
    not exist. `unreachable_claims` is now derived from the rows instead of being
    asserted zero, and `tools/audit_unreferenced_entries.py` joins the batch
    whenever the original executable is supplied. Class counts are 11/37/1/120.
    Evidence: `docs/spec/mes/unreferenced_entries.md`. This bounds naming, not
    the native host's ability to construct a name at runtime.
    **The archive-wide twin map exists, 2026-09-10.** `tools/audit_duplicate_entries.py`
    groups every `.MES`/`.LIB` entry by the digest of its per-message record
    hashes, retaining no text: 954 entries carry messages, 903 digests are
    distinct and 49 are shared. The 365 `SCENE_*` entries are the replay
    gallery, named only in opaque tails by command-`0x0F` nested calls from
    thirteen `*_M.MES` menus, one letter per menu, which is why the strict
    inventory counted them as never dispatched. 27 of the 129 strictly decoded
    EVENT targets have a gallery copy, and so does every `?_END.MES`; each copy
    has no more records or bytes than its source and the same voice-marker
    count. The Miyuki (H) and Ai (K) galleries share six scenes byte-for-byte.
    The only two-EVENT group is L09/L10, and four large `*_TIME`/`*_TALK`
    scripts are stored twice. This files **no** `duplicate_route` row: whether
    a gallery copy belongs in that class is an ownership decision, and the
    class's candidate pool is still the 17 multi-intro targets. Evidence:
    `docs/spec/mes/duplicate_entries.md`.
    **Ruling, 2026-09-10, by the owner:** the classification stays open as
    it is. The owner reads every shared-message group other than the
    pre-voice L09/L10 pair as a replay (recollection) route; that is a
    presumption to work from, not a measured claim, and it is recorded here
    rather than as a class in the index. Revisit only if a gallery entry is
    ever measured to be dispatched from anything but a `*_M.MES` menu.
    Rebound to the corrected naming evidence on 2026-09-09. A first estimate
    that the tail records widen this pool was wrong: measured against the
    classifier's own inputs they add no non-`EVENT` dependency, no new
    multi-intro candidate and no row - the pool is the same 169 entries, and
    the `duplicate_route` pool is still 17. What changed is per-row evidence.
    The classifier now consumes `config/event_catalog/dispatch_naming_v1.json`
    and re-decodes its 650 tail records and two inline sites from the original
    bytes to the same standard as the 10,474 strict rows (11,124 audited, all
    accepted). Every row carries an `intro_scope`; two rows whose reason was
    factually false are corrected, `EVENTA13.MES` moves to
    `event_named_tail_target`, and `LIBLARY.LIB`/`DEF_MAIN.MES` carry the
    `START.MES` inline sites as intro evidence instead of an empty list.
    Thirteen mutations of the naming evidence are rejected. Class counts were
    unchanged at 11/4/154 by that step.
    Then qualified the shared scripts, 2026-09-09. "Shared" is measurable: over
    all 130 EVENT-named targets the distinct-caller count is 1 for 126 and 2 for
    four, so **2 is the archive-wide maximum for anything dispatched as an
    event**. The classifier derives that maximum at run time and fails closed if
    it moves. 33 non-`EVENT` dependencies exceed it and become `system_script`
    on that measurement rather than on filename: 26 reached only by
    command-`0x0F` nested calls that resume the caller (`A_PIC`-`Q_PIC`,
    `G_TALK00`-`G_TALK90`, `G_PROMIS`, `A_INTRO`) and 7 only by command-`0x0E`
    root handoffs that replace it (`MACHI` at 147 callers, `GROUND`,
    `FLOOR1/2/4/5`, `44C`). `B_PIC`/`D_PIC`, already system scripts by catalog
    role, sit in the same band and are the control; `05C.MES` has exactly two
    callers and is correctly left unresolved. Class counts are now 11/37/121.
    The index also carries the fourteen committed analysis-group profiles as
    per-row evidence for the 22 entries they bind, with each profile's archive
    identity and member hashes rechecked. The twelve measured EVENT entries stay
    `unresolved_route` - a bounded observation does not promote catalog
    playback - but are now distinguishable by confidence
    (`analysis_group_measured_semantics_unresolved`, 12 rows) from the 109 rows
    that are unresolved and unmeasured. Six further mutations rejected.
    Semantic qualification of those 109 remains the open work.
    **2026-09-14:** none of the 109 is unmeasured any more - all 120
    unresolved rows are analysis-group measured (128 profiles over 156 bound
    entries) - and the classifier still writes "preset, full route meaning
    and terminal qualification remain open" for each, because a bounded
    group does not promote catalog playback. Closing this checkbox is
    therefore an owner ruling, put as TODO.md Execution Order step 1.3:
    promote measured groups to `analysis_only` catalog rows (the D05/D06 and
    J04 precedent), or close on measured confidence with a vocabulary that
    says so, or require playback.
    **Closed 2026-09-14 under the owner's ruling (b).** The classifier now
    says what a group establishes: `analysis_group_qualified_route` (118
    rows, a `measured_callee` role - the entry's own route declared and
    re-verified), `analysis_group_measured_participant` (`05C.MES`, measured
    as L06's door and I21's caller) and `analysis_group_member_unmeasured`
    (`EVENTM11.MES`, membership only); the retired value is history in the
    doc. Class counts stay 11/37/1/120, the split 49/120/0 over 156. Not
    closed by this: catalog promotion (option (a), a later decision) and the
    host's path to each origin (the outer-eligibility item below).
    Evidence: `docs/spec/mes/event_route_classification.md`.
  - [x] Build the current Python handoff analysis frontier for all 169 indexed
    entries and their incoming callers (326 entries total): exact intro records,
    branch sites, dependency selectors, write sites, opaque boundaries and
    terminal candidates. The 129 EVENT targets contain 150 intro sites and
    2,716 conditional sites. Recomputable inventory v1 keeps lexical guard
    candidates separate from execution evidence; this does not qualify those
    branches or close route coverage. Evidence:
    `docs/spec/mes/event_analysis_inventory.md`.
  - [x] Measure the first GROUND H17/K09 group with exact Python source checks:
    31 guard witnesses and 17 callee runs, 155 runtime assertions. H17's
    isolated return is qualified for the tested inputs; its caller remains at
    the DEF-12 calendar-byte dependency. K09 carries actual local caller state
    to its routine-40 selection boundary. Core 0.307.0 adds bounded nested-DEF
    composition and exact stop details. No catalog coverage is promoted.
    Evidence: `docs/spec/mes/ground_event_analysis.md`.
  - [x] Continue GROUND H17 with the existing START calendar context through
    DEF11/12, callee return and caller completion. Qualify K09's three choices
    and field-208 threshold outcomes through caller completion. V2 measures
    23 variants, compares each with unbroken execution and verifies completed
    reentry rejection. Both reach MACHI under bounded runtime policy; Python's
    strict caller tails remain explicitly opaque. Core 0.308.0; evidence:
    `docs/spec/mes/ground_event_analysis.md`.
  - [x] Extend H17/K09 to 44 caller-origin variants: K09's word204 threshold,
    flag3006 conditions and choices now have both-sided witnesses. Classify
    overwritten slot8 paths and routine28's flag4000 normalization within the
    measured tool policy. Record direct completed K09 reentry's counter148
    increment; local caller rejection is a different property. Evidence:
    `docs/spec/mes/ground_event_analysis.md` (2026-09-09).
  - [x] Qualify four additional GROUND intros for H01/H02 with 72 guard witnesses
    and six full-path cases, including H02's three later choices. V3 records
    two K01 dispatch sites, the K_PIC boundary and MACHI replacement, with
    variant-specific direct reentry. Evidence:
    `docs/spec/mes/ground_h01_h02_analysis.md`. These are bounded analysis
    observations; catalog support remains unchanged.
  - [x] Continue both H01 paths through their distinct K01 callers and H02 first
    through K_PIC to the observed MACHI handoffs. V4 measures two K01 paths and
    20 K_PIC states with full carried context, continuation and direct reentry;
    origin guards remain distinguished from downstream local eligibility.
    Evidence: `docs/spec/mes/ground_k01_kpic_analysis.md`.
  - [x] Qualify K09's outer selection from GROUND:63807 with owner-bound caller
    and callee choices: 28 event paths and 27 bypass cases. Confirm that caller
    flags may change even when K09 never executes; do not treat them alone as
    completion evidence. Evidence: `docs/spec/mes/ground_event_analysis.md`.
  - [x] Qualify C07 from typed GROUND:6044 through its observed opaque local
    guard, C_PIC/O_PIC continuation and MACHI handoff. V5 measures 22 local
    guard witnesses and 35 state cases, including actual clock advancement,
    counter thresholds/saturation and direct reentry effects. Evidence:
    `docs/spec/mes/ground_c07_c12_analysis.md`.
  - [x] Qualify both sequential C12 calls under their shared opaque guard.
    Core 0.310.0 inspects each exact call without suppressing the earlier call.
    Thirty-four starting states are measured at both calls (68 route variants),
    with 23 shared guard witnesses, caller-owned phase transition, O_PIC,
    MACHI and repeated phase-1 direct reentry. Evidence:
    `docs/spec/mes/ground_c07_c12_analysis.md`.
  - [x] Qualify K02 from typed GROUND:6044 through its opaque seasonal guard,
    callee return and MACHI replacement. Eighteen local guard witnesses and
    21 full cases verify clock advancement, bit-mask preservation, the caller's
    16-word copy and state-changing direct reentry (693 assertions). Evidence:
    `docs/spec/mes/ground_k02_analysis.md`.
  - [x] Qualify H15 and A07 from typed GROUND:31450. H15 returns to its caller
    and continues to MACHI: 27 local guard witnesses, 37 full paths and 1,655
    assertions. A07 is a command-`0x0E` root replacement with no caller resume:
    33 guard witnesses, 54 chains and 1,912 assertions. Core 0.311.0 adds the
    analysis-only `follow_root_handoff` descriptor so one unbroken replacement
    chain can be compared with its segmented caller/target inspection. Both
    record counter clamps, nested H_PIC/N_PIC dependencies and direct reentry.
    Evidence: `docs/spec/mes/ground_h15_a07_analysis.md`.
  - [x] Qualify F02 from its own typed guard `GROUND:31082..31160`, the head of
    the same chain whose false edge is the H17/H15/A07 origin 31450. Unlike
    A07 the guard is a typed record, not an opaque-tail observation. 19 guard
    witnesses and 20 full root-replacement chains (607 assertions) bind the
    exact MACHI terminal, the 0..15 counter clamp, both display outcomes and a
    fully inert completed reentry. The DEF11 clock advance is measured to
    normalize an out-of-range HHMM minute or MMDD day before advancing.
    Evidence: `docs/spec/mes/ground_f02_analysis.md`.
  - [x] Qualify G08, the last GROUND EVENT intro, and the only one whose
    dispatch has **no local eligibility guard**. Measured 2026-09-09: exactly
    one edge in GROUND originating before `31051..31067` lands beyond it, the
    constant-true `5860` interval the frontier already refuses to treat as an
    event guard; the only conditional structure before the dispatch is a
    three-way banked-word-204 selector whose arms all converge on it. Rather
    than declare a selector as a guard, Core 0.312.0 adds the
    `kakyu_event_analysis_group/v7` shape, whose audit re-derives the window
    from the original bytecode and proves no edge in it can skip, divert or
    hide the dispatch. 12 selector witnesses and 19 chains (495 assertions)
    reach `EVENTG08.MES:6869..6882 -> MACHI.MES`. G08 has no completion
    predicate and never touches counter 264, so reentry replays the whole body.
    Evidence: `docs/spec/mes/ground_g08_analysis.md`. This closes GROUND's
    sixteen intro sites; the outer scheduler that reaches them does not.
  - [x] Open the `44M.MES` caller group, the second largest after GROUND.
    Inventoried 2026-09-09: 11 EVENT intro sites, every one with a typed guard
    candidate and no opaque bytes anywhere - 0 of 66,047 in the caller and 0 in
    all eleven callees - so this group is better evidence terrain than GROUND,
    where several guards were opaque-tail observations. `EVENTB14` is already
    catalogued; the other ten are not. (2026-09-19: EVENTB14 is now also a v8
    group, `44m_b14_v8.json` - results 1 and 3 declared, result 2's second
    selection undeclared - so every 44M intro is a group;
    `docs/spec/mes/44m_caller_group.md`.)
    `EVENTC18` is measured. Its guard `24767..24837` is ten typed conjuncts with
    no opaque term and nothing conditional between its true edge and the
    dispatch `25032..25048`, so it is the only local eligibility condition.
    Twenty witnesses (5 accept / 15 reject) pin all three inequalities exactly:
    `state_u16[19]` rejects 1800 and accepts 1801, accepts 2099 and rejects
    2100; `banked_u16[206]` rejects 80 and accepts 81; the date is exactly
    `12/24`. The route is invariant across 18 variants - 4 caller messages, 13
    callee messages, the exact `command_00` return `1849..1850`, and the effects
    `global_u8[3582]=1`, `global_u8[5196]=1`, `banked_u16[1]=7`.
    **The completion predicate is caller-owned**: after the callee the guard is
    still true in all 18 variants and direct reentry replays identically with no
    state difference, but after the caller's post-event sequence it is false,
    because the caller writes conjunct 9, `global_u8[1784]=1`. That is a fourth
    reentry shape beside A07's callee counter, F02's inertness and G08's absent
    predicate. The caller then stops at a routine-40 selection,
    `44M.MES:65466`, an exact bounded unresolved boundary.
    The callee's first branch `224` reads that same `global_u8[1784]`, so the
    completed reentry - measured after the caller finishes, which is the
    boundary the validator checks - emits 0 messages and returns at `1880..1881`
    instead of `1849..1850`, writing only `state_u16[2]=1`. Direct reentry
    before the caller finishes replays all 13 messages instead.
    Evidence: `docs/spec/mes/44m_caller_group.md`.
    Landed as a committed group on the owner's ruling, 2026-09-09. The schema's
    two caller-resume boundary policies are `stop_before_unprovided_dependency`
    (command `0x0F`) and `natural_handoff` (command `0x0E`); this resume ends at
    a command-`0x1D` routine-40 selection, which the schema already understood
    for callee outcomes and reentry but not as a resume policy. Rather than
    declare a policy this route does not have, **Core 0.313.0 adds
    `kakyu_event_analysis_group/v8`** with `def_selection_boundary` as a third
    policy, bound to an exact routine-40 record that names no script target and
    accepted only for v8. The runtime validator needed no new check - it already
    read that boundary for callee outcomes and reentry - so v8 changes what may
    be declared, not what is executed.
    `EVENTH11` follows on that contract with no further change. Its guard
    `8280..8367` is thirteen typed conjuncts with no conditional record between
    its true edge and the dispatch `8627..8643`; 22 witnesses (7 accept / 15
    reject) pin every boundary - `state_u16[7]` rejects 915 and accepts 916,
    accepts 1115 and rejects 1116; `state_u16[19]` rejects 1759 and accepts
    1760; `banked_u16[207]` rejects 70 and accepts 71 - and conjunct 9 is the
    first **prerequisite** seen in this group: `global_u8[2284]` must already be
    1. Nineteen variants give one invariant route: 25 callee messages, the exact
    return `2322..2323`, 18 caller messages to the same routine-40 stop.
    Its completion predicate is **callee-owned**, the opposite of C18 in the same
    caller: `global_u8[2325]` is conjunct 11 and the callee writes it, so the
    guard is already false against the state the callee leaves and the resume
    adds only `global_u8[350]=1`. Completed reentry emits 0 messages and returns
    at `2353..2354`. `global_u8[264]` independently reproduces F02's 0..15 clamp
    from a different caller: 0 becomes 1, 14 becomes 15, 15 stays 15.
    756 runtime checks pass.
    `EVENTF22` is the third, chosen by measurement rather than size: of the
    eleven intros only four have neither a branch nor another dispatch between
    the guard's true edge and the call, and `EVENTI14` is the one predicate that
    is not a pure conjunction. Its guard `13961..14049` is thirteen typed
    conjuncts with a prerequisite of its own, `global_u8[1502]=1`; 22 witnesses
    pin every boundary (1115/1116, 1510/1511, 1000/1001, 2000/2001, 110/111).
    Fifteen variants give one message count, 47 to the exact return
    `2947..2948`, but **four** branch maps, because the callee tests the date
    itself at `2297` (1224), `2330` (1301) and `2363` otherwise. Its completion
    is caller-owned like C18 - the resume writes conjunct 12,
    `global_u8[1650]=1` - but the resume emits no message of its own. The callee
    nests `F_PIC.MES`, which joins the group's source members. 669 runtime
    checks pass.
    `EVENTF17` is the fourth, measured 2026-09-10, and it makes the group's
    structure visible: its guard `13671..13765` has false edge **13961**, which
    is F22's guard, and its conjunct 7 is `global_u8[1502] == 0` where F22
    requires 1. The two share the date range, so at any moment at most one is
    eligible and that flag decides which; neither callee writes it, so what sets
    it between them stays open. Twenty-two witnesses pin every boundary
    (1115/1116, 1510/1511, 1759/1760, 2299/2300, 100/101) and every rejection
    lands on 13961, so the chain shows in the witnesses and not only in the
    source. Fifteen variants give 89 callee messages to the exact return
    `5501..5502` across **five** branch maps, the callee makes two nested
    `F_PIC.MES` calls, and completion is caller-owned through conjunct 13,
    `global_u8[1646]=1`. 669 runtime checks pass.
    `EVENTF06` is the fifth and the first here with a player choice. Its guard
    `1753..1833` is twelve typed conjuncts with the prerequisite
    `global_u8[1626]=1` and a spring-evening window, `400 < state_u16[7] < 616`
    and `1000 < state_u16[19] < 2001`; 17 witnesses pin every boundary. The
    callee stops at a routine-40 selection `1815`, resuming `1820`, with three
    definitions and results 1/2/3, so this profile is the first in the group to
    carry a choice contract and per-variant selections. The three answers give
    32/48/66 callee messages to one shared terminal `7653..7654`, and 21
    variants produce **eight** branch maps. Completion is callee-owned through
    conjunct 11, `global_u8[1628]`. Six callee branches testing `state_u16[7]`
    against 1224 and 1301 are unreachable **from this intro**, because the
    guard's window cannot produce those dates; that is recorded as measured
    unreachability from one caller, not as dead source. 1,136 runtime checks
    pass, the largest group in this caller.
    `EVENTL10` is the sixth and answers what lies past the stop every route above
    ends at. Of its three lexical guard candidates only one is its guard: `65342`
    is a **constant-true** branch, measured as such and kept in the hashed prefix
    rather than declared - the same trap the frontier records for GROUND's 5860 -
    and `65481` is the result gate requiring the caller's own selection to have
    been answered 1. The guard is `65606..65689`, twelve conjuncts with the
    prerequisite `global_u8[399]=1`; 20 witnesses pin 615/616, 915/916,
    2059/2060, 2200/2201 and 35/36.
    It is a root replacement, so there is no resume, and its callee asks a second
    routine-40 question whose two results reach **two different roots**: result 1
    gives 65 messages to `44C.MES:4659..4670`, result 2 gives 62 to
    `MACHI.MES:4815..4828`. A v6 route binds one exact terminal, which is the
    right constraint, so this is one profile with **two routes**, each declaring
    both choice contracts and answering both. Segmented and unbroken replacements
    are identical across all twenty variants. Completion is callee-owned through
    conjunct 11, `global_u8[2050]`. 575 runtime checks pass with no schema change.
    `EVENTL10.MES` is also dispatched from `EVENTM20.MES:9867`; that intro is not
    measured here and nothing claims the two are duplicates.
    Extended 2026-09-10 after reading the scene: the choice options are "go back
    into the dormitory" and "go somewhere else", matching the two measured roots.
    A third arm sits beside them at branch `4838`, reached when the choice result
    is 2 **and** `global_u8[532]` is set, and it emits a refusal that reads as a
    curfew. It does **not** read the clock or the weekday - both are already
    fixed by the guard's 21:00-22:00 window - only that one flag, whose owner is
    not established. With the flag set the scene re-asks the same selection, so
    answering it identically does not terminate: 761 messages to the segment
    limit with no branch offset the terminating runs do not also visit. That arm
    is measured and deliberately not declared, since it has no ending to bind.
    The group now carries 12 and 11 variants and passes 647 runtime checks.
    **Correction, 2026-09-10.** This item recorded four intros as not cleanly
    guarded because a branch or another dispatch stands between guard and call.
    Measuring those records retires that reading: `EVENTH18`, `EVENTA22` and
    `EVENTI14` have a nested `*_PIC.MES` call in the gap, which resumes the
    caller and cannot skip the dispatch, and the in-gap branches of `EVENTH18`
    and `EVENTJ11` have false edges landing **before** the dispatch. No edge
    anywhere in `44M.MES` enters any of those gaps from outside - zero in every
    case. The guard is the only record deciding all eleven calls; what differs is
    what happens after the dispatch.
    `EVENTH18` (13 conjuncts, two prerequisites, 21 witnesses, caller-owned
    completion) and `EVENTI14` (14 conjuncts including this caller's only
    disjunction, 29 witnesses covering both date windows and the 1250 gap between
    them, callee-owned completion) each pass 660 runtime checks on v8.
    `EVENTA22`'s callee opens with a routine-40 selection whose answer decides the
    shape of the route: results 1 and 3 return (`1839..1840`, `9524..9525`) and
    are declared as two v8 routes, 510 checks; **result 2 ends at a command-`0x0E`
    root handoff to MACHI**, suspending a nested caller that never resumes. No
    current shape expresses that - v5/v8 require the callee to return, v6/v7
    require the caller record to be `0x0E` - so it is measured and left
    undeclared rather than forced into either.
    `EVENTJ11` was measured on 2026-09-13 and left unqualified because its
    callee did not terminate under the bounded runtime - 772 messages in
    512 segments, 6,148 in 4,096, branch `234` seen with both truth
    values - until the libai5 bridge read the "cycle" as the decoder's
    `0x0D` framing: the byte at `15363` the runtime dispatched on was the
    selector of `System.function[24](4,0,"bll.mmo",0,0)` after
    `call_sub(8)`. Qualified the same day under Core 0.316.0 as
    `44m_j11_v6.json` (no contract, 469 checks): the first body ends at
    `10208..10221 -> MACHI` after 143 messages, the direct reentry takes
    the second body to `18898..18911 -> MACHI` after 78 messages, and the
    M-word-at-50 route (the second body on the first visit, 125 messages)
    is measured and not declared.
    All ten uncatalogued intros are now qualified; `EVENTB14` was already
    catalogued. Two things remain open in this caller: the contract for a nested
    call whose callee replaces the root, and EVENTJ11's M-word-at-50 route.
  - [x] Open the `01M.MES` caller group, the station script. Inventoried
    2026-09-10: nine EVENT intro sites, every one with a typed guard candidate,
    0 opaque bytes of 89,510 in the caller and 0 framing-opaque bytes in all
    nine callees (`EVENTH07`/`EVENTM06` each carry one preserved opaque
    boundary record). `EVENTB03` and `EVENTJ04` were already qualified and are
    the controls: J04's guard, false target and eight conjuncts reproduce
    exactly. The seven others sit in one cascade whose false edges chain
    B03 -> M06 -> M09 -> J04 -> D05 -> I16 -> G11, with L03 after an unmeasured
    stretch. Five intros have nothing conditional between guard and dispatch;
    `EVENTG11`'s four in-gap branches all land before its dispatch. `EVENTH07`,
    `EVENTM06` and `EVENTM09` stand behind a constant-true record and the
    result gate `state_u16[21] == 1`, the L10 shape: a player choice at the
    station. `EVENTL03` has the caller's first disjunction (weekday 0 or
    12/24). `EVENTI16` is the only intro that requires Saturday, and
    `EVENTH07` the only one whose date test is relative (the day after
    `banked_u16[268]`). Evidence: `docs/spec/mes/01m_caller_group.md`.
    `EVENTI16` is qualified, the smallest cleanly guarded root handoff here.
    Its guard `40556..40606` is seven typed conjuncts: Saturday, `9/15 < date
    < 1511`, `13:59 < clock < 16:31`, `global_u8[130]` and `[1342]` clear;
    thirteen witnesses pin 915/916, 1510/1511, 1359/1360 and 1630/1631. The
    route is 6 caller and 20 callee messages to the callee's one root handoff
    `2819..2832 -> MACHI.MES`, segmented and unbroken agreeing. The callee
    tests the clock in three 600/900/1600/1800 ladders and the guard window
    crosses 16:00, so one route carries two bands: before 16:00
    `global_u8[3274] = 1` and `state_u16[8] = 46`, from 16:00 `2` and `0`.
    Two seeded inputs are dead - `state_u16[8]` is overwritten at `271..276`
    before its test, and `global_u8[4000]` is cleared by `LIBLARY.LIB` routine
    28 called at `261` - so branches `331`/`386` are unreachable; 17 of 19
    branches are exercised. Completion is callee-owned through conjunct 7
    (`global_u8[1342]`, written at `2783..2789`); the completed reentry emits 0
    messages and returns at `2862..2863`. Declared as `01m_i16_v6.json` on the
    existing v6 contract, 306 checks, no Core or schema change.
    **Presumption, 2026-09-10, by the owner:** date values above `1231` are
    the calendar continuing past December into a thirteenth month and beyond,
    so I16's `1511` bound and I14's `1307..1510` window are a later season.
    Recorded as a reading to work from, not a measurement.
    `EVENTD05` is qualified, the first route here whose callee asks the
    player a question and runs a `?_PIC.MES` script of its own. Its
    fifteen-conjunct guard `39839..39941` (weekday 0, `4/00 < date < 6/16`,
    `08:00 < clock < 16:01`, `50 < banked_u16[212] < 80`, `global_u8[402]`
    set, seven flags clear) has twenty-two witnesses. The callee calls
    `D_PIC.MES` at `2082..2095` - executed here, not omitted as the Event
    Player's playback contract does - and reaches a three-result routine-40
    selection at `2839` whose definitions are the offsets the D05 validator
    already binds; all three results reach `5947..5960 -> MACHI.MES` with
    48/48/49 messages and move the guard's own affection word by -5/+2/0.
    Executing `D_PIC.MES` exposed one effect the omission hid:
    `global_u8[3005] = 15` when `global_u8[3006]` is set. Completion is
    callee-owned through `global_u8[753]` and the reentry replays the body,
    moving the word again. Declared as `01m_d05_v6.json`, 896 checks, no
    Core or schema change.
    `EVENTG11` is qualified, the first route here whose prefix is not a
    straight line: between its fourteen-conjunct guard `40825..40919`
    (weekday 0, `10/00 < date < 11/16`, `09:00 < clock < 16:00`,
    `banked_u16[204] > 70`, eight flags clear; twenty witnesses) and the
    handoff `43481..43497` stand a `G_PIC.MES` call and four branches whose
    false edges all land before the handoff. 38 caller and 50 callee messages
    reach `3289..3302 -> MACHI.MES`. The callee writes two of the guard's own
    flags (`global_u8[140]` at `3238`, `[1481]` at `3227`), increments
    `banked_u16[204]` and copies the date into `banked_u16[277]`, the idiom
    H07's guard reads from the other side; nothing in it tests those flags,
    so the completed reentry replays all 50 messages. `state_u16[8]` and
    `state_u16[5]` are dead inputs, overwritten at `EVENTG11.MES:250` and
    `01M.MES:43109` before their tests. Declared as `01m_g11_v6.json`, 555
    checks, no Core or schema change.
    `EVENTH07` is measured and deliberately not qualified. Its eligibility
    guard `621..675` (the day after `banked_u16[268]`, `09:30 < clock <
    11:00`, `global_u8[2300]`/`[2301]` set, `[2304]`/`[2305]` clear) has
    eleven witnesses; the station's selection at `01M.MES:3927` has two
    results, `1` reaching the handoff `6076..6092` after 67 caller messages
    and `2` reaching a different root handoff `89476..89489 -> MACHI` after
    91 more. The caller writes `global_u8[2301] = 0` and `[2304] = 1` at
    `6010..6027`, immediately before the handoff, so the guard is closed
    before the callee runs - a caller-owned completion written before the
    dispatch, a shape none of the earlier groups had. The callee's first branch `274` tests that flag
    and calls `TRAIN.MES` at `290`, and `TRAIN.MES:861` is a command-`0x0D`
    native stream whose end the export cannot bound: the probe resumes on the
    same record until the 512-segment budget is gone (identical to 4,000), 0
    callee messages, no terminal. `EVENTM06`/`EVENTM09` dispatch `TRAIN.MES`
    at their `0x00FF` and are expected to stop at the same record. Open
    instrument finding: the route probe should report a native stream whose
    resume makes no progress as an exact bounded boundary instead of
    consuming its segment budget.
    `EVENTL03` is qualified, the only nested call among the cleanly guarded
    intros and the intro with the caller's only disjunction. Its guard
    `44573..44674` (weekday 0 or 12/24; `4/00 < date < 6/16`, `10:00 < clock
    < 16:01`, `banked_u16[209] > 35`, `global_u8[399]` set, seven flags
    clear) has twenty-one witnesses, and the disjunction is measured on all
    four weekday/date combinations: `date == 1224` can never hold with
    `400 < date < 616`, so that arm is dead and weekday 0 is the only way in.
    10 caller and 15 callee messages reach the return `2306..2307`; the
    caller resumes at `45073`, calls `L_PIC.MES`, emits 38 messages and stops
    at the station exit `89476..89489 -> MACHI.MES`. Completion is owned
    twice: the callee closes conjunct 12 (`global_u8[2043]` at `599..605`)
    and the resume closes conjunct 11 (`global_u8[2042]` at `47004..47010`,
    also a clear flag of 44M's L10 guard); either alone shuts the guard, and
    both reentries emit 0 messages. Declared as `01m_l03_v5.json` on the v5
    contract with the `natural_handoff` resume policy, 324 checks, no Core or
    schema change.
    `EVENTM06` and `EVENTM09` are measured and not qualified at the same
    record. Their guards (`30889..30944`: weekday 0, `6/15 < date < 9/16`,
    `clock < 16:00`, `global_u8[2420]` set, three flags clear;
    `35012..35060`: weekday 0, `date > 7/15`, `clock < 16:00`, the same
    prerequisite, three flags clear) have twelve and ten witnesses; their
    windows overlap from 7/16 to 9/15 with M06 first in the cascade. The
    station's selections at `01M.MES:32625` and `36443` have two results:
    `1` reaches the nested call after 32/31 caller messages, `2` reaches the
    station exit `89476..89489 -> MACHI` after 50/48, and anything else
    loops back through `34980`/`39532` to re-ask. Both callees dispatch
    `TRAIN.MES` at `255` and stop at `TRAIN.MES:861` (repeat confirmed to
    8,000 segments), with no guard cell written before the stop. Every intro
    in this caller is now measured: six qualified - B03 and J04 before this
    group, D05, G11, I16 and L03 here - and three stopped at one native
    boundary.
    Corrected 2026-09-14: `TRAIN.MES:861` is `System.function[12](5)`
    under Core 0.316.0 and the walk passes it; the three callees now halt
    in the train map's click-polling loop (`849..1044`: `Util(6,8)`,
    `Util(6,13)`, `[21] = [18]`, `jz [21] == 0xFFFF` back), a native
    input wait with no boundary record inside it, so the runner spends
    its step budget there. Re-measured with the toolchain (H07's guard
    needs `banked_u16[268] = date - 1` seeded; the prefix then reaches
    the handoff): measured, not qualified, pending the owner's choice
    between a callee-side input-loop outcome, a model of the train map's
    input, and leaving them. The 01M doc carries the section.
    Ruled and declared 2026-09-14: the owner chose the general map-input
    contract with the train as its first case. ai5-sdl2's Kakyuusei map
    module names the loop: `Util(6,8)` runs the sprites, `Util(6,13)`
    writes the player's location into `state_u16[18]` (0xFFFF none), and
    the train leaves when locations 0 then 1 are reached. Core 0.318.0's
    map-location contract (`kakyu_mes_map_location_contract/v1`, schemas
    v11 / v12) supplies them; `01m_h07_v11.json` (306 checks),
    `01m_m06_v12.json` (333) and `01m_m09_v12.json` (404) declare the
    three rides. Every 01M intro is declared; no structural row is left
    (classification 49/120/0 over 156, `TRAIN` bound for the first time).
  - [x] Open the `FLOOR5.MES` caller group, the school floor the term
    Saturday starts on. Inventoried 2026-09-11 with the 01M instrument, which
    reproduces the I16 row exactly first: seven EVENT intro sites for six
    targets, 0 framing-opaque bytes of 10,126 in the caller and 0 in every
    callee, and every site a command-`0x0F` nested call. Five sites have a
    clean typed guard; `EVENTM18` -> `EVENTH10` -> `EVENTH16` chain by their
    false edges and all three begin with `state_u16[21] == 4`, so they stand
    behind one selection result on the floor. `EVENTG21` alone tests the
    weekday (Saturday) and repeats one conjunct. `EVENTE15` has two sites,
    one guarded (`5543..5627`, the same day as `banked_u16[265]`) and one
    not. `EVENTF01`'s site and E15's site A have **no guard**: each sits in
    an address-table entry (`2978`, `5299`) whose window to the dispatch is
    fifteen records with no branch, no skipping edge and no entering edge -
    G08's shape, but as nested calls, which no committed contract expresses
    yet. Evidence: `docs/spec/mes/floor5_caller_group.md`.
    `EVENTM18`, `EVENTH10` and `EVENTH16` are qualified together. Sixty-four
    witnesses pin every boundary of the three guards (`1115/1116`,
    `1510/1511`, `915/916`, `1229/1230`, `1500/1501`, `1529/1530`, the
    affection words at `55/56`, `80/81`, `70/71`, M18's counter at `10/11`).
    Each callee returns (28, 87 and 22 messages) and the floor resumes into
    one code path: `TIME_C.MES`, a reset of `state_u16[21]`, and the root
    handoff `FLOOR5.MES:4846..4860 -> FLOOR4.MES`, which lies inside the
    floor's preserved opaque tail `4730..5066` and is bound as an opaque-tail
    runtime observation. Completion is caller-owned: the resume writes the
    route's own flag (`global_u8[2515]`, `[2318]`, `[2279]` and `[2331]`),
    the callee's first branch reads it, and the completed reentry emits 0
    messages. The caller's own prefix writes `state_u16[8]` and `[2]` before
    every callee, so those tests are not inputs. Declared as
    `floor5_m18_v5.json`, `floor5_h10_v5.json`, `floor5_h16_v5.json` on the
    v5 contract with `natural_handoff`: 381, 498 and 541 checks, no Core or
    schema change.
    `EVENTG21` is qualified: Saturday on the floor, `9/15 < date < 15/11`,
    `banked_u16[204] > 120`, six flags clear (one listed twice), fourteen
    witnesses; 10 caller and 24 callee messages to the return `2264..2265`,
    12 more to the shared `FLOOR4` handoff; the resume writes
    `global_u8[1492]` at `4475..4481` and the callee's first branch reads it,
    so the completed reentry emits 0 messages. `floor5_g21_v5.json`, 264
    checks.
    `EVENTE15` is qualified at both sites. Site B's twelve-conjunct guard
    (`9/15 < date < 11/16`, `12:29 < clock < 14:30`, the same day as
    `banked_u16[265]`, `global_u8[1914]` set, six flags clear) has eighteen
    witnesses; the callee runs 11 messages to `4235..4236` and the resume
    reaches the shared `FLOOR4` handoff writing `global_u8[1915]`, the
    guard's own clear flag, so completion is caller-owned and the reentry
    replays. Site A has no guard and can run the half of the callee site B
    cannot: with `global_u8[1914]` clear the first visit runs 20 messages to
    `2842..2843` and sets that flag itself; every later run takes the
    11-message body. Either entrance writes `[1915]`. `floor5_e15b_v5.json`
    (371 checks) and `floor5_e15a_v9.json` (two routes, 388 checks).
    `EVENTF01` is qualified: no guard, a three-result routine-40 selection
    inside the callee at `2331` all reaching `4220..4221` (25/25/29
    messages), the resume writing `global_u8[1619]`, the cell the callee's
    first branch reads, so the completed reentry emits 0 messages.
    `floor5_f01_v9.json`, 359 checks. Declaring the two unguarded nested
    calls needed **Core 0.314.0's v9** - v8's continuation with v7's window
    and selection witnesses - and exposed a defect in the v7 window audit:
    it counted a protagonist-name insert (command byte `0x0E`) as a
    dispatch; it now counts by decoded op, with a unit test, and G08 is
    unchanged. Every FLOOR5 intro is now measured and declared: seven sites,
    six targets, seven groups.
  - [x] Open the `18M.MES` caller group, six unresolved intros. Inventoried
    2026-09-11 with the same instrument and control: 0 framing-opaque bytes
    of 68,049, 301 address-table entries, every intro guarded, three root
    handoffs (I05, I09, C11, each callee ending in MACHI) and three nested
    calls (M16, K13, L04). I05 -> I09 -> M16 chain by their false edges; I09
    and M16 stand behind the caller's selection (constant-true record, gate
    `state_u16[21] == 1`, a `?_PIC` call in the gap, a re-ask edge entering).
    K13, L04 and C11 are clean. The guards are earlier predicates moved along
    their arcs: I05 wants `date == banked_u16[261]` with `global_u8[130]` set
    where I16 and I09 want it clear; K13 is FLOOR5 H16's predicate with both
    affection words raised to `> 80`; L04 is 01M L03's guard with `[2044]`
    for `[2043]`; C11 clears the five flags 44M's C18 clears. Evidence:
    `docs/spec/mes/18m_caller_group.md`.
    `EVENTC11` and `EVENTI05` are qualified. C11: twenty-two witnesses, 6
    caller and 27 callee messages to `3238..3251 -> MACHI`, callee-owned
    completion through `global_u8[1755]` and `[1769]`, reentry 0 messages;
    `18m_c11_v6.json`, 351 checks. I05: the date equal to `banked_u16[261]`
    with `global_u8[130]` set - the flag I16 and I09 need clear - six
    witnesses, a three-result callee selection at `3078` all reaching
    `6445..6458 -> MACHI` (69/76/65 messages), the callee clearing `[130]`
    and setting `[1325]`; `18m_i05_v6.json`, 465 checks.
    `EVENTK13` and `EVENTL04` are qualified. K13: FLOOR5 H16's predicate
    raised to `> 80`, twenty-seven witnesses, 33 callee messages to the
    return `4336..4337`, 18 resume messages to `28471..28484 -> MACHI`,
    completion caller-owned through `global_u8[2279]`/`[2338]` in the
    resume, reentry 0 messages; `18m_k13_v5.json` with the silent `H_PIC`
    and `K_PIC` calls as members, 319 checks. L04: L03's guard with `[2044]`
    for `[2043]`, the same dead disjunction measured on four combinations,
    a three-result callee selection at `2431` all returning at
    `5818..5819` (32 messages; the word moves +1/-2/-2), completion owned
    twice (callee `[2044]` at `741`, resume `[2042]` at `34659`), 9 resume
    messages to `67529..67542 -> MACHI`; `18m_l04_v5.json`, 451 checks.
    `EVENTI09` and `EVENTM16` are qualified, both behind the caller's
    selection at `13380` / `17187` answered 1. I09: the guard admits
    `banked_u16[203]` in 51..80 but the body's branch at `11832` sends
    51..60 to the exit `67529`, so the route's window is 61..80; the caller
    writes `global_u8[1331]` right after the guard, H07's shape; the callee
    asks its own three-result question at `1811` and each result ends at a
    different MACHI handoff (`3107`, `5857`, `8244`; 30/60/49 messages);
    reentry 0 messages on the callee's seen flag `[1332]`.
    `18m_i09_v6.json`, three routes, 829 checks. M16: 46 caller messages
    through `M_PIC`, 48 callee messages to `3523..3524`, 36 resume messages
    to `19834..19847 -> MACHI`, completion caller-owned through `[2439]`
    and `[2502]` in the resume, the callee's own seen flag `[2503]`
    blocking reentry; `18m_m16_v5.json`, 358 checks. Every 18M intro is
    measured and declared: six sites, six targets, six groups, no contract
    change.
  - [x] Open the `44C.MES` caller group, the dormitory root L10 reaches,
    six unresolved sites for five targets. Inventoried 2026-09-11 with the
    same instrument and control: 0 framing-opaque bytes of 67,635, 520
    address-table entries, every site a guarded nested call, no callee with
    a root handoff or a `TRAIN.MES` dispatch (`EVENTM10` calls `EVENTM11`
    three times). `EVENTL25` and `EVENTI24` have independent guards sharing
    the prerequisite `global_u8[372]`; `EVENTM17`, both `EVENTM10` sites and
    `EVENTM03` share a constant-true record and the gate `state_u16[21] ==
    3` and chain by their false edges, M10's two sites told apart by
    `global_u8[2455]`, M03's guard a seven-arm calendar-only disjunction.
    M03, M10 and M17 are also dispatched from `L_HOTEL2.MES`, not measured
    here. Evidence: `docs/spec/mes/44c_caller_group.md`.
    `EVENTI24` and `EVENTL25` are qualified on v8: both resumes stop at the
    dormitory's own routine-40 selection `44C.MES:45952..45957` (the record
    44M C18 stops at, whose definitions the contract builder does not
    support), bound as the `def_selection_boundary` policy. I24: twenty-three
    witnesses, 6 caller and 37 callee messages to `2358..2359`, completion
    callee-owned through `[1350]`, reentry 0 messages; `44c_i24_v8.json`,
    209 checks. L25: no weekday test (weekday 6 accepts), 30 caller messages
    through two silent `L_PIC` calls, 24 callee messages to `2006..2007`,
    the callee closing `[2052]` and the resume closing `[2042]` and
    re-writing `[2052]`, L03's doubly-owned shape; `44c_l25_v8.json`, 204
    checks.
    `EVENTM03` is qualified as two routes. Its guard is a seven-arm
    calendar-only disjunction, seventeen witnesses pinning every arm; the
    45,891-byte callee runs 24 messages to `13317..13318` at baseline,
    writing `[2417]` (read by M10 site B and the caller's preludes) and
    `[2420]` (the station's M06/M09 prerequisite); with M17's clear flag
    `[2504]` set it returns at `8491..8492` instead, the second route. The
    resume stops at `45952` after advancing the clock fifteen minutes, and
    since the guard reads only the calendar it stays open except where that
    advance crosses `9:01`. That needed **Core 0.315.0**: a caller-continuation
    route may now declare its post-guard truth, route-level and per variant,
    and v8 reads per-variant reentry overrides; profiles that declare
    nothing are unchanged, and the eight 44M v8 profiles carrying a `null`
    placeholder are accepted. `44c_m03_v8.json`, 684 checks; 1,381 Python
    tests and all 42 committed groups pass under the changed validator.
    `EVENTM17`, `EVENTM10` site A and site B close the group. M17: eleven
    witnesses pinning `9/16..11/15` and `19:01`, 12 caller and 24 callee
    messages to `2125..2126`, the resume writing `[2504]` (its own guard's
    flag) and `[2417]` (M10 site B's clear flag) through `O_PIC` before
    the selection at `45952`, reentry 0 messages; the `23:59` day-end
    tail to `43C.MES` is measured and not declared; `44c_m17_v8.json`,
    175 checks. M10: one callee behind two guards told apart by `[2455]`,
    which site A's own prefix sets before dispatching, so A's guard is
    closed by the caller and B's by the callee's `[2417]`; 84 callee
    messages to `6045..6046` from either site, the 51-message second pass
    at `10734..10735` declared as the reentry, `EVENTM11` a member never
    reached; `44c_m10a_v8.json` 141 checks, `44c_m10b_v8.json` 143. Every
    44C intro is measured and declared: six sites, five targets, six
    groups; the classification binds 62 entries at 49/43/77.
  - [x] Open the `17M.MES` caller group, the map root `MACHI.MES:25259`
    hands off to, five unresolved sites for four targets - four root
    handoffs and one nested call, the first group since 44M's L10 whose
    routes end in the callee's own terminal. Inventoried 2026-09-11 with
    the same instrument and control: 0 framing-opaque bytes of 52,760, 234
    address-table entries, every site typed-guarded, no target with another
    caller, no `TRAIN.MES` dispatch; the three handoff targets all hand the
    root back to `MACHI.MES` (`EVENTA20` at seven sites). `EVENTC10`,
    `EVENTA10` and `EVENTA02` have one clean guard each; `EVENTA20` is a
    tree behind `state_u16[21] == 1` and the date `13/01`, its two
    entrances split by `global_u8[1127]` with a thirteen-arm `[1035]`
    prelude ladder on the first. C10 and A10 share the `8/25` evening, and
    A02's clear flags contain A20's. Evidence:
    `docs/spec/mes/17m_caller_group.md`.
    `EVENTC10` is qualified on v5 as two routes behind the caller's own
    selection at `42662`: eighteen witnesses, 9 caller and 15 callee
    messages to `2143..2144`, the resume closing its own guard with
    `[1755]` and `[1768]` before the selection, then result `1` through
    `A_PIC`, `A_INTRO` and `A_OUTRO` to the `MACHI.MES` handoff at
    `52741` (30 messages) and result `2` straight to `44351` (15). The
    resume writes `banked_u16[242] = 17` - the map word A10 and A02
    require not to read `17` - and never executes A10's guard, so the
    shared `8/25` evening does not chain the two. `17m_c10_v5.json`,
    447 checks; classification 64 entries at 49/44/76.
    `EVENTA10` is qualified on v6 as a root replacement: twelve witnesses
    including the map word rejected at `17` and accepted at `44`, 9 caller
    messages to the handoff at `21977`, 41 callee messages to its own
    `MACHI.MES` handoff at `3976..3989`, the callee closing the guard with
    `[1186]` and refusing a direct reentry with 0 messages; eleven variants
    all end at the same record. `17m_a10_v6.json`, 234 checks;
    classification 65 entries at 49/45/75.
    `EVENTA02` is qualified on v6 as three root-replacement routes behind
    the callee's own question at `2117`: twenty-three witnesses on a
    sixteen-conjunct spring-morning guard with the affection word in
    `31..60`; every answer reaches the same `MACHI.MES` handoff at
    `5248..5261` writing the done flag `[1111]` and the map word, and
    differs only in length (48/44/42) and in moving the word by +2/-1/-2;
    reentry 0 messages through the same handoff. `17m_a02_v6.json`, 602
    checks; classification 66 entries at 49/46/74.
    `EVENTA20` closes the group as two groups, one per site: the tree above
    both is swept from `42677` (every `[1035]` value reaches site A, the
    caller writes neither `[1127]` nor `[1035]`) and seeded below; the
    callee is two bodies behind its own `[1127]` test, each with its own
    question, the first visit through `A_INTRO` to `3451` (33) or `7811`
    (22) setting `[1127]` so the next visit arrives at site B, the second
    to `10408` (30) or `14536` (19) and repeating; both sites' guards stay
    open (`post_guard_expected` 1), and A's reentry is B's body under
    both contracts. `state_u16[12]` and `[1130]` arms measured, not
    declared. `17m_a20a_v6.json` 579 checks, `17m_a20b_v6.json` 515.
    Every 17M intro is measured and declared: five sites, four targets,
    five groups, nine routes; classification 67 entries at 49/47/73.
  - [x] Open the `23M.MES` caller group, a map root named only inside
    `GROUND.MES`'s opaque tail (`66682`, a root handoff), five unresolved
    sites for five targets, all root handoffs whose callees hand the root
    back to `GROUND.MES`. Inventoried 2026-09-12 with the same instrument
    and control: 0 framing-opaque bytes of 30,415, 172 address-table
    entries, every site typed-guarded with a clean gap, no target with
    another caller, no `TRAIN.MES` dispatch. Every guard is a Saturday
    afternoon; C02, E01 and C05 chain by their false edges on the spring
    dates and C17 and E03 form a second ladder. The C guards share C10's
    prerequisite `[396]` and clear flags - `[1755]`, which C10's resume
    sets, among them - and split on the affection word `banked_u16[206]`
    at `70/71`; the E guards share `[393]`. Evidence:
    `docs/spec/mes/23m_caller_group.md`.
    All five are qualified on v6 as root replacements, every callee to
    its own `GROUND.MES` handoff, each closing its guard with its done
    flag and its family's flag (`[1755]` for C, `[1892]` for E) and
    writing the map word `[242] = 23`, reentry 0 messages: C02 (38
    messages through a silent `E_PIC`) and C05 (24), the spring C rungs;
    E01 as three routes behind the callee's own question at `2431`
    (40/40/36, result 3 adding 1 to `banked_u16[202]`); C17 (27, the
    November rung wanting the affection word above 70) and E03 (43,
    `P_PIC` on an arm the seeds never take). `23m_c02_v6.json` 308
    checks, `23m_e01_v6.json` 623, `23m_c05_v6.json` 305,
    `23m_c17_v6.json` 296, `23m_e03_v6.json` 248. Every 23M intro is
    measured and declared: five sites, five targets, five groups, seven
    routes; classification 74 entries at 49/52/68.
  - [x] Open the `21C.MES` caller group, the root `21M.MES:41761` hands off
    to, four unresolved sites for three targets: `EVENTA08` twice and
    `EVENTC08` as root handoffs, `EVENTL07` as a nested call. Inventoried
    2026-09-12 with the same instrument and control: 0 framing-opaque
    bytes of 38,678, 225 address-table entries, every site typed-guarded,
    no target with another caller, no `TRAIN.MES` dispatch. The three
    guards chain by their false edges; A08's twenty-three conjuncts want
    both the A and E affection words in `41..79` on a weekday-0 late
    morning, and its two sites sit behind the caller's own question at
    `3823` (results 1 and 3; result 2 reaches no event); C08 is the C
    family's summer morning and L07 the L family's summer late morning
    with a Christmas Eve exception. Evidence:
    `docs/spec/mes/21c_caller_group.md`.
    All three are qualified. A08 on v6 as two root-replacement routes with
    the caller's contract, results 1 and 3 to the two sites after the
    caller moves both affection words, the same 115 callee messages to
    `8631..8644 -> MACHI.MES`, the callee closing the guard with `[1120]`
    and `[1119]`; C08 on v6, 91 messages through `O_PIC` to `7037..7050`,
    closing with `[1766]` and the C family's `[1755]`; L07 on v5 as two
    caller-continuation routes behind the caller's question at `35369`,
    24 callee messages, the resume closing `[2042]` and handing off to
    `MACHI.MES` at `38644` after 42 or 35 (the `14:45` tails measured, not
    declared). `21c_a08_v6.json` 676 checks, `21c_c08_v6.json` 350,
    `21c_l07_v5.json` 721. Every 21C intro is measured and declared: four
    sites, three targets, three groups, five routes; classification
    77 entries at 49/55/65.
  - [x] Open the `26M.MES` caller group, a map root named only inside
    `GROUND.MES`'s opaque tail (`66610`, a root handoff), four unresolved
    sites for four targets, all root handoffs whose callees hand the root
    back to `GROUND.MES`. Inventoried 2026-09-12 with the same instrument
    and control: 0 framing-opaque bytes of 26,171, 138 address-table
    entries, every site typed-guarded, no target with another caller, no
    `TRAIN.MES` dispatch. Every guard is a Saturday: C01, C04 and C21 are
    the C family on 23M's pattern (spring below the affection bar `71`,
    November above `100`), C01's guard falling into C04's, and H06 a fourth
    family's spring afternoon; C01's callee asks its own question at
    `1608`. Evidence: `docs/spec/mes/26m_caller_group.md`.
    All four are qualified on v6 as root replacements, every callee to its
    own `GROUND.MES` handoff, each closing its guard with its done flag
    and writing the map word `[242] = 26`, reentry 0 messages: C01 as
    three routes behind the callee's own question at `1608` (30/34/37
    messages, the word moved by +1/+2/-2), C04 (49, admitted in two clock
    slots, both declared), H06 (48, closing three of its own flags) and
    C21 (62, the November rung above the bar `100`). `26m_c01_v6.json`
    581 checks, `26m_c04_v6.json` 341, `26m_h06_v6.json` 291,
    `26m_c21_v6.json` 313. Every 26M intro is measured and declared: four
    sites, four targets, four groups, six routes; classification 81
    entries at 49/59/61.
  - [x] Open the `MACHI.MES` caller group, the town map every map hands
    the root back to, four unresolved sites for four targets: `EVENTG04`
    and `EVENTE18` as root handoffs, `EVENTE04` and `EVENTE10` as nested
    calls. Inventoried 2026-09-12 with the same instrument and control: 0
    framing-opaque bytes of 60,475, 260 address-table entries, every site
    typed-guarded, no target with another caller. The map asks no question
    of its own - it reads the destination number `state_u16[21]` back from
    `MACHI.INC.MES` - and the three E intros sit behind destinations `0`,
    `9` and `26`, each the event that may play before the map hands the
    root to `44M`, `13C` or `MIZUHO26`; G04 sits behind one flag with a
    seven-branch gap. G04's and E18's callees ask their own questions.
    Evidence: `docs/spec/mes/machi_caller_group.md`.
    All four are qualified. E18 on v6 as two routes by door with the
    callee's contract - answered 1 it hands the root to the dormitory and
    sets `[372]`, the prerequisite 44C's I24 and L25 require; answered 2
    back to MACHI - reentry the same door after 3 messages. G04 on v6 as
    three result routes, the caller clearing its own flag `[1470]` before
    the handoff, 156/160/144 messages replayed in full on reentry. E04 and
    E10 on v5 as caller continuations whose resumes run the map's shared
    tail, skip the destination menu with no request pending, and hand the
    root to `44M.MES` at `21230` - destination 0's target - after
    12 and 0 messages. `machi_g04_v6.json` 355 checks,
    `machi_e18_v6.json` 343, `machi_e04_v5.json` 582, `machi_e10_v5.json`
    711. Every MACHI intro is measured and declared: four sites, four
    targets, four groups, seven routes; classification 85 entries at
    49/63/57.
  - [x] Open the `03C.MES` caller group, the root `03M.MES:19455` hands off
    to, three unresolved sites for two targets, all root handoffs:
    `EVENTJ14` twice and `EVENTJ15`. Inventoried 2026-09-12 with the same
    instrument and control: 0 framing-opaque bytes of 16,337, 152
    address-table entries, every site typed-guarded, no target with
    another caller. J15's guard - a Saturday from `9/16`, the J word above
    `50`, `[484]` and one of six J flags set, `[823]` clear - is the first
    `or` over flags in a guard here, and it opens J14, whose two sites
    both need `[823]` set and split on the visit count `[919]` at `2/3`.
    Both callees are two-bodied with their own questions and several
    doors back to `MACHI.MES`. Evidence: `docs/spec/mes/03c_caller_group.md`.
    All three are qualified on v6. J14 as two groups on the A20 convention,
    one per site, two result routes each with both of the callee's
    contracts: the first body's two answers reach the same handoff at
    `5042` after 62 or 58 messages, the callee writes neither `[823]` nor
    `[919]` so the guard stays open (`post_guard_expected` 1), and the
    reentry is the second body under its own answer 1 to `11365`. J15 as
    four routes: three doors by answer, each setting `[823]` - the flag
    J14 needs - and the `[824]` second body by a fourth door.
    `03c_j14a_v6.json` 503 checks, `03c_j14b_v6.json` 565,
    `03c_j15_v6.json` 1000. Every 03C intro is measured and declared: three
    sites, two targets, three groups, eight routes; classification 88
    entries at 49/65/55.
  - [x] Open the `07M.MES` caller group, the root the town map hands off to
    at `MACHI.MES:55512`, three unresolved sites for three targets, all
    root handoffs: `EVENTA19`, `EVENTG14`, `EVENTJ19`. Inventoried
    2026-09-12 with the same instrument and control: 0 framing-opaque
    bytes of 38,396, 196 address-table entries, every site typed-guarded,
    no target with another caller. A19's guard compares the date to the
    stored word `banked_u16[259]` - the first such guard here - on an
    `18:01..21:59` evening; G14 wants three flags and two clear; J19 is a
    weekday-`0` evening from `11/16` that needs `[823]` (03C's J15) and
    sits behind the caller's own question at `15413` (answer `2`), its
    callee asking a second question with three doors. Evidence:
    `docs/spec/mes/07m_caller_group.md`.
    All three are qualified on v6. A19 as one route with no contract: 195
    callee messages to one door, the callee closing two guard conjuncts
    (`[1207]`, `[1195]`), a 0-message reentry. G14 as one route whose
    callee has no gate of its own: the reentry replays the whole body,
    counting `[254]` and restamping the clock word `[293]`, declared with
    per-variant reentry overrides. J19 as three routes by the callee's
    answer with both contracts (the caller's `15413 -> 2`, the callee's
    `6402 -> N`), each door setting `[923]`.
    `07m_a19_v6.json` 365 checks, `07m_g14_v6.json` 269,
    `07m_j19_v6.json` 1999. Every 07M intro is measured and declared: three
    sites, three targets, three groups, five routes; classification 91
    entries at 49/68/52.
  - [x] Open the `11M.MES` caller group, the root the town map hands off to
    at `MACHI.MES:25223`, five intro sites of which three are unresolved:
    `EVENTJ01` and `EVENTK14` as nested calls, `EVENTH04` as a root
    handoff (the two `EVENTB15` sites are qualified). Inventoried
    2026-09-12 with the same instrument and control: 0 framing-opaque
    bytes of 53,586, 321 address-table entries, every unresolved site
    typed-guarded, no target with another caller. J01 reads the same
    `[401]` and clear set as 07M's J19 and its `[903]` gate is closed by
    the caller after the return; K14 is the first guard here on two
    affection words at once (`[207]`, `[208]` above `80`) and the caller
    closes `[2339]` and `[2279]` after it; H04's callee closes its own
    `[2294]`. Evidence: `docs/spec/mes/11m_caller_group.md`.
    All three are qualified. J01 on v8 as three routes by the callee's
    answer: 49 callee messages to its return, the resume 6 messages
    closing `[903]` and `[350]` and stopping at the caller's own question
    at 53145, a completed reentry through the done-gate with 0 messages.
    H04 on v6 as one door, the callee closing `[2294]`, the reentry
    counting `[244]` again. K14 on v8 as one route: 49 callee messages,
    the resume 9 messages closing `[2339]`, `[2279]` and stamping `[242]`
    before the same 53145 boundary.
    `11m_j01_v8.json` 1154 checks, `11m_h04_v6.json` 328,
    `11m_k14_v8.json` 511. Every unresolved 11M intro is measured and
    declared: three sites, three targets, three groups, five routes;
    classification 94 entries at 49/71/49.
  - [x] Open the `15C.MES` caller group, the root the town map hands off to
    at `MACHI.MES:36671`, three unresolved sites for three targets:
    `EVENTI10` as a root handoff, `EVENTC06` and `EVENTE11` as nested
    calls. Inventoried 2026-09-12 with the same instrument and control: 0
    framing-opaque bytes of 37,993, 170 address-table entries, every site
    typed-guarded, no target with another caller. Every callee asks its
    own three-answer question and moves its family's word; I10's guard
    carries the first two-window date `or` and its callee - the largest
    yet at 16,389 bytes - leaves by four doors and resets the I word hard;
    C06 and E11 close their own gates and the caller, which asks no
    question of its own, resumes past them. Evidence:
    `docs/spec/mes/15c_caller_group.md`.
    Measured 2026-09-12, none declared: I10's answer 2 completes to its
    door but answers 1 and 3 replay the callee from a `command_1b` at
    6567 until the probe's segment cap; C06's and E11's callees complete
    and close their own gates but the caller's resume transfers into the
    floor's menu loop at 30516 (input wait at 30851), which no resume
    policy of v5/v8 can name. Ruled 2026-09-12: declare I10's answer 2
    only (`15c_i10_v6.json`, 494 checks) and leave C06, E11 and I10's
    answers 1 and 3 deliberately unqualified, as 01M's H07/M06/M09 are;
    a continuation boundary policy for a resume that ends in the caller's
    menu loop is its own open item below. Classification 95 entries
    at 49/72/48. Declared 2026-09-14 under that policy: `15c_c06_v10.json`
    and `15c_e11_v10.json`, three routes by answer each, 1140 and 893
    checks; the doc carries the section.
  - [x] Decide whether a caller-continuation boundary policy for a resume
    that ends in the caller's own interactive menu loop (15C.MES:30516,
    input wait at 30851; probably every C-floor caller) should exist -
    a contract change across the profile schema, the audit and the
    validator - and what `command_1b` (EVENTI10.MES:6567) does natively.
    Ruled 2026-09-14: the policy exists. Core 0.317.0's route probe
    proves a loop on request (a continuation - boundary record, stored
    values, RNG position, argument slots, persistent expression stack -
    seen twice repeats forever) and stops at its head;
    `kakyu_event_analysis_group/v10` declares it as `caller_menu_loop`
    with the head record, period, cycle rows and per-period message
    count, and the audit, validator, measurement probe, builder and
    driver carry it. `15c_c06_v10.json` (three routes by answer, 1140
    checks) and `15c_e11_v10.json` (three routes by answer, 893
    checks) declare both callees; the resume proves the same loop at
    `35759` (period 7, 9 messages per period). `command_1b` is
    `System.function[24](4,0,"bll.mmo",0,0)` under Core 0.316.0, the
    form 44M J11 was qualified through; I10's answers 1 and 3 were
    declared later the same day (`15c_i10_v6.json` rebuilt as three
    routes by answer, 580 checks). Classification 169 rows at 49/115/5
    over 150 bound at the time.
  - [x] Re-measure what Core 0.316.0 unblocked, in the owner's order of
    2026-09-14: FLOOR4 and FLOOR1 re-inventoried with the new decoder,
    then EVENTL18 and EVENTA13 (FLOOR4 map arm 4, typed guards at 3686
    and 3567) and EVENTI04 (FLOOR1 map arm 3, guards at 3918 and 4244)
    as root-replacement groups - done the same day, five groups (see the
    FLOOR4 and FLOOR1 items); then 01M's H07, M06 and M09 (their stop
    `TRAIN.MES:861` is `System.function[12](5)`, an omitted call) and
    15C I10's answers 1 and 3. Done 2026-09-14: I10 is rebuilt as three
    routes by answer (`15c_i10_v6.json`, 580 checks, the 494-check
    answer-2 profile superseded); H07, M06 and M09 re-measured and still
    not qualified - past `861` their callees halt in `TRAIN.MES`'s
    click-polling loop, an owner question recorded in the 01M item -
    then ruled and declared the same day through Core 0.318.0's
    map-location contract (see the 01M item). Closed 2026-09-14: every
    part above landed (`5ccb614`, `4184f44`, `6ff41b3`) and the
    classification carries no structural row.
  - [x] Decided 2026-09-13: option (c) - the bridge is a reading aid and
    cross-check now (caller-group docs may name presentation records as
    `System.function[N]`), and the decoder change is its own item below,
    in the order decoder -> runtime dialogue-boundary and message-count
    parity -> re-binding of the 23 opaque-tail profiles -> full original
    batch -> docs and test figures. The finding as decided on (2026-09-13,
    `docs/spec/tech/libai5_bridge.md`, `tools/libai5_bridge/`): nunuhara's
    libai5 grammar for the 2003 AI5WIN generation (`nonomura`) parses all
    1,016 entries of `mes.arc` completely and with no warning, where the
    Phase 1-4 decoder leaves 1,251 opaque tails (734,485 bytes). The one
    disagreement is command `0x0D`: the repo frames it as a separator and
    reads the bytes after it as further commands (the `0x0E` name insert,
    the `0x13 FF` cursor control, the `0x09` filename form, the rare
    `0x05`/`0x08`/`0x15`/`0x16`/`0x1A` shapes, the "unreconciled `0x18`");
    libai5 reads one system call - an expression selecting the function and
    a typed parameter list - and the reconciliation run covers all 1,180
    opaque tails the current handoff build leaves with such a call (1,168
    start one byte after the `0x0D`; 840 are `System.function[5](2)`, 214
    `System.function[24](…)`, 81 `System.function[8](…)`). Applied as Core
    0.316.0 the same day: both decoders frame `0x0D` as a selector expression
    plus the typed record list (`system_call` with `system_function`; the
    confirmed presentation forms keep their names), the runner executes
    function 19 as the message wait / dialogue boundary, 14 as the name or
    literal insert, 9 as the MMO marker and omits the rest; the archive
    decodes with zero opaque tails; the 23 profiles bound inside opaque
    tails were rebound as typed records; the frozen GDScript digest was
    regenerated. Evidence: `docs/spec/mes/format_and_method.md`, "Command
    `0x0D` is one system call". The options as they stood: (a) change the decoder's
    `0x0D` rule to expression + parameter list and let the runtime dispatch
    system functions (a structural-authority contract change; 44M J11 and
    every `native_presentation_boundary` stop follow), (b) keep the decoder
    and use the bridge as a reading aid and cross-check in the caller-group
    docs, (c) both, decoder first. libai5 is GPL-2.0 and stays an external
    checkout under `analysis/ext/`; only the bridge source is tracked.
  - [x] Decided 2026-09-13: (B) - the core and the structural
    re-derivations are committed as one commit, and the Event Player
    evidence chain is re-baselined check by check from the list below,
    each in its own commit with a doc note wherever a claim moves. The
    options as they stood: (A) all of it before the commit, (B) commit now
    and re-baseline from the list, (C) hold the working tree. State on the
    evening of 2026-09-13, when the decision was taken: the
    117-group batch passes (114 unchanged; GROUND G08, FLOOR5 F01 and E15A
    re-measured, their "return candidates" having been the `00`
    terminators of message waits); the GDScript digest reproduces
    1,016/1,016 at `617111b9...d94277b`; the repository suite and the
    Python regression pass; the structural evidence was re-derived and
    passes - the literal dispatch inventory at 11,124 rows (9,875 nested
    calls, 1,249 root handoffs, 360 callers, 1,005 targets, 11 entries
    never named, 130 EVENT targets with `EVENTL09` alone never named, the
    80,272 name inserts counted under command `0x0D`), the naming audit
    with no opaque tail and the byte scan reproducing every strict row
    (the 365 gallery rows tracked as `gallery_envelopes`), the duplicate
    report, and the classification (169 rows, 147 bound, 49/112/8
    unchanged; `EVENTA13` a strict `event_named_target`); the playback
    package and contextual authoring pass once the code source owns the
    boundary (`dialogue_boundary_end`) and `system_function` travels in a
    package. 28 original checks stay red for two reasons that follow from
    the framing rather than from doubt about it: the dialogue boundary is
    reported at the wait call, three bytes before the old `02` byte
    (resume offsets unchanged), and the old runner executed a call's
    record list as pseudo-commands and stopped at "native presentation
    boundaries" that were the mis-framing, where it now continues
    (`10M.MES:0x4AC7` reachable from an address-table intro, the PROMIS
    owner boundaries, the detached-DEF counts, EVENTB03's native-stream
    envelopes at `0x2A74`...). The holders are about 28 scripts under
    `tools/content_suite` (13k lines, ~2,300 coordinates) and
    `apps/event_player.gd` (21 `_validate_*` functions): MES unresolved
    surface-dispatch reachability; PROMIS writer owner boundaries, date
    library resumes, caller reachability and nested call routes; detached
    DEF previews; F_DATE2 nested DEF and the Event Player F_DATE2 detached
    DEF; Event Player PROMIS scheduling routes; EVENTD08 composed choice
    routes; Event Player catalog ordinary playback and fragment catalogs;
    the EVENTB01, B02, B14, B15, D01, D02, D03, D05 and D08 integrations;
    EVENTB03 zero-state choice analysis, captured and numeric presets, the
    state12, affection, preset-choices and face-flags matrices and the
    preset reduction matrix.
  - Two more stragglers surfaced on 2026-09-14 when the 328-check batch first
    ran with `--exe` on Core 0.318.0 (326 passed): the unreferenced-entry
    report's EVENTL09/L10 twin profile (typed records 620/703 -> 442/524, the
    separator-framed groups now one `system_call` each; naming unchanged)
    and the EVENTB03 sound audit's BLL.MMO marker (`0x299C` -> `0x299B`, the
    call's `0x0D` byte). Both re-baselined with dated doc corrections and the
    classification re-derived (`5252265`); the four affected checks re-run
    green.
  - [x] Re-baseline queue for Core 0.316.0, closed 2026-09-14: the 28
    checks listed in the decision above are green again. The PROMIS
    writer / date-library / nested-call / caller-reachability audits, the
    10M.MES 0x4AC7 reachability audit, the detached-DEF corpus, the F_DATE2
    nested DEF and the EVENTD08 composed routes each got their own commit;
    the Event Player integrations went in three (the byte-verified boundary
    shift, the MMO-marker / routine-27 / native-FX re-derivations, then the
    three stragglers the closing full batch found: the EVENTB02 and AX
    chain marker coordinates and the unit scene's EVENTD01/EVENTD06 rows).
    Where a recorded stop or coordinate was the separator mis-framing -
    fake returns at the `00` of a message wait, "native streams" that were
    System.function[12] calls, MMO markers one byte after their call - the
    doc that recorded it carries a dated correction beside the claim.
  - [x] Open the `25C.MES` caller group, a root named only from
    `GROUND.MES`'s opaque tail at 66574, three unresolved sites for three
    targets: `EVENTF20` and `EVENTA03` as root handoffs to `GROUND.MES`,
    `EVENTE05` as a nested call. Inventoried 2026-09-12 with the same
    instrument and control: 0 framing-opaque bytes of 23,962, 135
    address-table entries, every site typed-guarded, no target with
    another caller. A03's guard is the first to read the stamp
    `banked_u16[242]` (`!= 25`, the value F20 and A03 both write); A03's
    callee asks a three-answer question whose answers converge on one
    door; E05's callee sets its own gate before any message and the
    caller closes one of A03's conjuncts after the return. Evidence:
    `docs/spec/mes/25c_caller_group.md`.
    All three are qualified. F20 on v6 as one door: 29 callee messages,
    the callee counting `[128]` on the E word's band (again on the
    0-message reentry), closing `[1648]` and stamping `[242] = 25`. A03 on
    v6 as three routes by answer sharing one door with the callee's
    contract, each answer moving the E word and closing `[1113]`, `[1112]`
    and the stamp; the reentry hands off again. E05 on v5: the callee
    closes `[1894]` before its first message, and the resume sets `[350]`
    and `[1112]` and transfers to the shared epilogue that stamps `[242]`
    and hands off to `GROUND.MES` at 23932 - a natural handoff, not a menu
    loop.
    `25c_f20_v6.json` 383 checks, `25c_a03_v6.json` 1053,
    `25c_e05_v5.json` 337. Every 25C intro is measured and declared: three
    sites, three targets, three groups, five routes; classification 98
    entries at 49/75/45.
  - [x] Open the `30C.MES` caller group, a root named only from
    `FLOOR2.MES`'s opaque tail at 3567, three unresolved sites for one
    target, `EVENTG01`, all root handoffs to `FLOOR2.MES`. Inventoried
    2026-09-12 with the same instrument and control: 0 framing-opaque
    bytes of 24,989, 144 address-table entries, every site typed-guarded,
    no other caller. The three sites are one ladder on the G flags: site
    A wants `[1459]` clear and the caller sets it in the gap, sites B and
    C split on `[1464]`, which the callee sets at its door; the callee has
    no top gate, walks the G word's bands and dispatches one of the
    `G_TALK*.MES` scripts by band. Evidence:
    `docs/spec/mes/30c_caller_group.md`.
    All three sites are qualified on v6 with the eight talk scripts'
    contracts among the profile's contracts: each talk script asks a
    two-answer question (1370 or 1358) whose first answer is the exit, and
    with it supplied the callee reaches its door after 9..32 messages,
    writing `[1463] = 0`, `[1462] = 1`, `[1464] = 1` and the stamp `[242] =
    30`; site A closes by the caller's `[1459]`, site B by the callee's
    `[1464]`, site C stays open (`post_guard_expected` 1) and every reentry
    reaches the door again. `G_PROMIS.MES`'s question has a definition-id
    gap the contract tool rejects, so the `[1381]` row is measured to its
    boundary and not declared.
    `30c_g01a_v6.json` 672 checks, `30c_g01b_v6.json` 689,
    `30c_g01c_v6.json` 619. Every 30C intro is measured and declared:
    three sites, one target, three groups, three routes; classification
    109 entries at 49/76/44.
  - [x] Open the `35M.MES` caller group, a root named only from
    `FLOOR5.MES`'s opaque tail at 4902, the last caller with three
    unresolved sites: `EVENTG02`, `EVENTL02`, `EVENTI13`, all root
    handoffs to `FLOOR5.MES` in one ladder of Saturday guards. Inventoried
    2026-09-12 with the same instrument and control: 0 framing-opaque
    bytes of 27,618, 134 address-table entries, every site typed-guarded,
    no target with another caller. G02's first visit sets `[1391]`, the
    flag 30C's G01 guards require; L02's callee sets its own gate
    `[2041]` before its question; I13's closes `[1339]` and `[2624]`; all
    three stamp `[242] = 35`. Evidence: `docs/spec/mes/35m_caller_group.md`.
    All three are qualified on v6. G02 as three routes by answer sharing
    one door, the first visit setting `[1391]` and the callee closing
    `[1466]`, the reentry running the return-visit arm to the door again.
    L02 as three routes by answer sharing one door behind the gate the
    callee sets at 608, the reentry returning through the done-gate.
    I13 as one door closing `[1339]` and `[2624]`.
    `35m_g02_v6.json` 1177 checks, `35m_l02_v6.json` 1079,
    `35m_i13_v6.json` 319. Every 35M intro is measured and declared:
    three sites, three targets, three groups, seven routes; classification
    112 entries at 49/79/41. With 35M every caller that had three
    unresolved intros is closed.
  - [x] Open the `05M.MES` caller group, the root the town map hands off to
    at `MACHI.MES:52622`, the first caller with two unresolved sites:
    `EVENTJ07` as a root handoff and `EVENTL06` as a nested call whose
    callee never returns but hands the root to `05C.MES` or `MACHI.MES`
    by its second question - the shape the 2026-09-13 v6 revision names
    `nested_root_handoff`. Inventoried 2026-09-13 with the same instrument
    and control: 0 framing-opaque bytes of 23,756, 84 address-table
    entries, both sites typed-guarded, no target with another caller.
    J07's caller writes `[210]`, a clear conjunct of its own guard, in the
    gap; L06's callee sets its gate `[2046]` early and `[2042]` before its
    second question. Evidence: `docs/spec/mes/05m_caller_group.md`.
    Both are qualified on v6. J07 as one door closing `[907]`, the reentry
    the done-gate return that still steps the I-word counter `[138]`.
    L06 as the first `nested_root_handoff` profile: two routes by the
    second answer, each variant naming both answers, the callee closing
    `[2042]` and `[2046]`, the reentry the same door through the done-gate.
    `05m_j07_v6.json` 425 checks, `05m_l06_v6.json` 1086. Every 05M
    intro is measured and declared: two sites, two targets, two groups,
    three routes; classification 115 entries at 49/82/38, with `05C.MES`
    moved to analysis-group measured as L06's door.
  - [x] Open the `06C.MES` caller group, the root the sixth-floor map hands
    off to at `06M.MES:58036`, with two unresolved sites, both nested calls
    whose callees return: `EVENTL08` (the callee's own three-answer question
    at 1898 moving the L word by the answer, its gate `[2049]` set at 563)
    and `EVENTJ18` (no question, the caller closing `[922]` and `[854]` after
    the return). Both resumes transfer to the caller's epilogue at 38228,
    which ends in the floor's six-definition question at 38612 - 11M's
    routine-40 shape, the v8 `def_selection_boundary` resume. Inventoried
    2026-09-13: 0 framing-opaque bytes of 43,872, 276 address-table
    entries, both sites typed-guarded, no target with another caller.
    Evidence: `docs/spec/mes/06c_caller_group.md`.
    Both are qualified on v8, the resume stopping at the floor's routine-40
    record 38612 as a `def_selection_boundary`. J18 as one main route, the
    caller closing `[922]` and `[854]` after the return, the reentry the
    done-gate return, plus a second route for the `[823]` rows whose resume
    is three messages shorter (the M03 precedent). L08 as three routes by
    the callee's answer with its contract, the callee closing `[2049]`
    early and the caller closing
    `[2042]` and `[2049]` again after the return.
    `06c_j18_v8.json` 373 checks, `06c_l08_v8.json` 567. Every 06C
    intro is measured and declared: two sites, two targets, two groups,
    five routes; classification 117 entries at 49/84/36.
  - [x] Open the `09M.MES` caller group, a root the town map names once at
    `MACHI.MES:56863..56874` in a typed command-0E record. The original
    entry-file coordinate was mistaken for a code coordinate; the source
    recheck confirms the dispatch and withdraws the decoder-error claim. Two
    unresolved sites, both root handoffs: `EVENTL11` behind the caller's
    own two-answer question at 17616 (answer 1 moves the L word up one and
    hands off; answer 2 is the caller's decline arm closing `[2068]` itself and
    moving the L word down two; the caller closes `[2042]` in the gap
    before asking), and `EVENTM20` whose callee sets `[2517]` and asks two
    answers at 9634: 1 -> 44C with `[372]` (or EVENTL10 behind a summer
    window the 12/24 guard cannot satisfy), 2 -> MACHI when `[532]` is
    clear, a replay when it is set. Inventoried 2026-09-13: 0
    framing-opaque bytes of 43,594, 144 address-table entries, both sites
    typed-guarded, no target with another caller. Evidence:
    `docs/spec/mes/09m_caller_group.md`.
    Both are qualified on v6. L11 as one root-replacement route for answer
    1 with the CALLER's contract (21C A08 shape), the caller closing
    `[2042]` before asking and the callee closing `[2068]`, moving the L
    word up twice and stamping 9; answer 2, the caller's decline, is
    measured and not declared. M20 as two routes by the callee's answer -
    44C with `[372]` and stamp 0, MACHI with `[286]` and stamp 44 - the
    callee closing `[2517]` before asking; the `[532]` replay and the
    unreachable EVENTL10 door are not declared.
    `09m_l11_v6.json` 318 checks, `09m_m20_v6.json` 433. Every 09M
    intro is measured and declared: two sites, two targets, two groups,
    three routes; classification 119 entries at 49/86/34.
  - [x] Open the `27C_EV.MES` caller group, the dormitory floor's event
    script named by `43C_ASA.MES` at 15592..15606 and 38063..38077 in
    typed command-0E records. Earlier entry-file name offsets were mistaken
    for code-relative command starts. Two unresolved sites, both nested
    calls whose callees return and ask nothing: `EVENTM01` behind
    `[2404] == 1 and [2405] == 0` on any day, four picture scripts in the
    gap, the caller closing `[2405]` after the return; `EVENTM14` behind
    `4/22 and [2405] == 1 and [2406] == 0`, a ten-byte gap, the caller
    closing `[150]`, `[230]` and `[2406]` after the return. Both resumes
    walk into the floor's day (date blocks, a 12:30 wait loop at 11051,
    talk scripts, an epilogue at 48649 that rewrites the clock and hands
    the root off by date) - where they stop is the measurement's open
    question. Inventoried 2026-09-13: 0 framing-opaque bytes of 83,180,
    742 address-table entries, both sites typed-guarded, no target with
    another caller. Evidence: `docs/spec/mes/27c_ev_caller_group.md`.
    Both are qualified on v5 as natural handoffs: after closing the gate
    the caller walks the floor's whole day - five or six passes of the day
    loop advancing the calendar, the callee's own `[244]` count opening
    the N-family block - and hands the root to `FLOOR5.MES` at 83150.
    `27c_ev_m01_v5.json` 371 checks, `27c_ev_m14_v5.json` 414. Every
    27C_EV intro is measured and declared: two sites, two targets, two
    groups, two routes. The wait loop's random `[2347]` is not declared.
  - [x] Open the `FLOOR4.MES` caller group, the fourth-floor map seven
    scripts hand off to, which asks no question of its own (its menu
    branches on the `state_u16[21]` the previous map selected - the MACHI
    E04 shape). Two unresolved sites of different kinds: `EVENTF03`, a
    nested call behind a typed guard on menu arm 6 (`date ==
    banked_u16[263]`, clock < 16:01, `[100]` and `[1623]` set) whose callee
    closes `[1624]` and `[1620]` and clears `[100]` itself, the resume
    falling back into the floor's loop; and `EVENTL18`, a root handoff at
    3984 on the floor's straight entry path with no guard and no branch
    before it - the callee carries the gate (`[2075]`), asks three
    answers, and hands the root back to FLOOR4. L18's site has no typed
    origin the v5/v6/v8 schemas can name: an owner decision (01M's
    TRAIN.MES:861 ruling is the precedent for leaving it; naming a
    script-entry origin would be a contract change). Inventoried
    2026-09-13: 0 framing-opaque bytes of 5,955, 16 address-table
    entries, no target with another caller. Evidence:
    `docs/spec/mes/floor4_caller_group.md`.
    F03 is qualified on v5 as a natural handoff: the resume falls back
    into the floor's loop and hands the root to `FLOOR3.MES` at 3008 - a
    record inside the floor's opaque tail 2074..3814, bound as a runtime
    observation as FLOOR5's profiles are, so L18's site at 3984 lies past
    the floor's own exit and no measured walk
    reaches it. `floor4_f03_v5.json` 809 checks. L18 stays unqualified
    (its row is bound by membership only, the M11 precedent)
    pending the owner's decision on a script-entry origin (it is entered
    by address-table entries 3 / 4). Classification 124 entries at
    49/90/30; the two-intro tier is closed except L18.
    Corrected 2026-09-14: under Core 0.316.0 the floor's arm switch inside
    the former opaque tail is readable, and L18's site has a typed guard at
    3686 behind map arm 4 (after EVENTA13's guard at 3567 in the same arm),
    F03's shape; no new origin kind is needed and the owner decision above
    is withdrawn. EVENTI04's two FLOOR1 sites likewise sit behind arm-3
    guards at 3918 and 4244. The group doc carries the correction.
    Declared 2026-09-14 with the route toolchain from the re-inventory
    (`analysis/floor4_group_measure.json`, origin at the arm-4 test 3552
    for both): `floor4_a13_v6.json` (three routes by answer, 542
    checks) and `floor4_l18_v6.json` (three routes by answer, 568
    checks). Every FLOOR4 intro is measured and declared.
    Re-declared 2026-09-14 from the floor's arrival (Core 0.319.0): origin
    at the floor's entry `0`, `global_u8[3001] = 0` and no pending request,
    the player's location `4` supplied at the floor's own poll `2323` by a
    map-location contract spent by the prefix - the arm is walked to, not
    seeded. `floor4_a13_v11.json` (528 checks) and `floor4_l18_v11.json`
    (584) replace the v6 profiles; the menu path and the mode-2 arrival stay
    undeclared, and which mode each caller leaves is its resume's to say.
    F03 followed: `{2323, [6, 0]}` - the arrival spent by the prefix and,
    after the callee returns and the floor polls again, the way down to
    FLOOR3 spent by the resume, which the old declaration had taken from the
    seeded `[18] = 0`; `floor4_f03_v12.json` (522 checks) replaces the v5
    profile (re-verified with its two `[209]` arm variants restored, 604
    checks). Every FLOOR4 intro is now declared from the floor's arrival.
  - [x] Open the `FLOOR1.MES` caller group, the first-floor map eleven
    scripts hand off to at fourteen sites, which asks no question of its
    own (the map's `state_u16[21]` arms - the FLOOR4 shape). One target
    at two sites in arm 3: `EVENTI04`, the I family's spring
    eavesdropping in three stages - the first visit behind the guard at
    3918 (`4/00 < date < 6/16`, I word > 55, stamp != 28, `[1320]`
    clear), a later visit the same day behind the guard at 4244 (the
    stored date `[260]`, `[1320]` set, `[1321]` clear), the callee
    selecting its stage on `[1320]` / `[1323]` and leaving by a door of
    its own each time; every floor exit closes the day (`[1321]`).
    Re-inventoried 2026-09-14 under Core 0.316.0: 0 framing-opaque
    bytes of 6,254, 17 address-table entries, no target with another
    caller. Declared as `floor1_i04a_v6.json` (293 checks),
    `floor1_i04b_v6.json` (231) and `floor1_i04c_v6.json` (221),
    one group per stage. Evidence: `docs/spec/mes/floor1_caller_group.md`.
    Classification 169 rows at 49/117/3 over 152 bound; the three
    structural rows left are 01M's H07, M06 and M09.
    Re-declared 2026-09-14 from the floor's arrival (Core 0.319.0): origin
    at the floor's entry `0`, arrival mode `0` and no pending request, the
    player's location `3` supplied at the floor's own poll `2816` by a
    contract spent by the prefix; `floor1_i04a_v11.json` (271 checks),
    `floor1_i04b_v11.json` (211) and `floor1_i04c_v11.json` (201) replace
    the v6 profiles, and location `4` instead is rejected in all three.
  - [x] Close the `19C.MES` caller group (one site): `EVENTL05`, a root
    handoff behind a 13-conjunct Saturday guard, the callee setting its own
    gate `[2045]` early and closing `[2042]` at its door to MACHI, no stamp.
    `19c_l05_v6.json` 280 checks. Evidence: `docs/spec/mes/19c_caller_group.md`.
  - [x] Close the `27C1A.MES` caller group (one site): `EVENTC03`, a root
    handoff behind a 14-conjunct Saturday guard, the callee storing the date
    into `banked_u16[264]`, closing `[1757]` and `[1755]` and stamping 27 at
    its door to FLOOR1. `27c1a_c03_v6.json` 292 checks. Evidence:
    `docs/spec/mes/27c1a_caller_group.md`.
  - [x] Close the `29C.MES` caller group (one site): `EVENTA05`, a root
    handoff behind a 21-conjunct Saturday guard that excludes the stamp 29,
    the callee closing `[1115]`, stamping 29 and leaving for FLOOR4 - by the
    same door even when its gate is closed. `29c_a05_v6.json` 322
    checks. Evidence: `docs/spec/mes/29c_caller_group.md`.
  - [x] Close the `34C.MES` caller group (one site): `EVENTL20`, a root
    handoff behind a 12-conjunct guard with no weekday, the callee counting
    `[244]` before its gate, closing `[2076]` early and `[2042]` at its door to
    FLOOR5, stamp 34. `34c_l20_v6.json` 325 checks. Evidence:
    `docs/spec/mes/34c_caller_group.md`.
  - [x] Close the `33C.MES` caller group (one site): `EVENTA04`, a root
    handoff behind a 15-conjunct guard with no weekday, the callee moving the
    A word behind its `< 70` gates, closing `[1149]`, `[263]` and `[1112]`,
    counting `[128]` and stamping 33 at its door to FLOOR5 - by the same door
    even when closed. `33c_a04_v6.json` 434 checks. Evidence:
    `docs/spec/mes/33c_caller_group.md`.
  - [x] Close the `32C.MES` caller group (one site): `EVENTI23`, a root
    handoff behind a 15-conjunct Saturday guard, the callee closing `[1349]`
    and `[2624]` and stamping 32 at its door to FLOOR1. `32c_i23_v6.json`
    264 checks. Evidence: `docs/spec/mes/32c_caller_group.md`.
  - [x] Close the `10C.MES` caller group (one site): `EVENTD06`, a root
    handoff behind a 15-conjunct weekday guard, the callee with no done-gate
    of its own (the guard's `[754]` is set at its door), so a reentry replays
    the body; it moves the D word and leaves for MACHI, no stamp.
    `10c_d06_v6.json` 423 checks. Evidence: `docs/spec/mes/10c_caller_group.md`.
  - [x] Close the `20C.MES` caller group (one site): `EVENTL16`, a root
    handoff behind a 13-conjunct weekday guard, the caller closing `[2042]`
    in the gap, the callee closing its own `[2074]` early and asking three
    answers that move the L word behind `> 3` / `> 2` gates before one door to
    MACHI, stamp 20. Three routes by answer; `20c_l16_v6.json` 485
    checks. Evidence: `docs/spec/mes/20c_caller_group.md`.
  - [x] Close the `28C.MES` caller group (one site): `EVENTL13`, a root
    handoff behind two nested typed guards (the origin is the outer one; the
    audit accepts the inner guard in its gap; `post_guard_expected` 1 since
    the callee closes only inner cells), the callee counting `[128]` before
    its gate, closing `[2071]` early, moving the L word, storing the date
    word `[267]` and stamping 28 at its door to FLOOR1. `28c_l13_v6.json`
    429 checks. Evidence: `docs/spec/mes/28c_caller_group.md`.
  - [x] Close the `05C.MES` caller group (one site): `EVENTI21`, a root
    handoff behind a 14-conjunct weekday guard with a two-window winter date,
    selected by answer 1 of the caller's own three-answer question at 2121,
    the caller closing `[1346]` in the gap; the callee stores the I word into
    `[262]`, sets it to 25, closes `[130]`, counts `[138]` and stamps 15 at
    its door to MACHI. The first group qualified with the route toolchain;
    `05c_i21_v6.json` 414 checks. Evidence:
    `docs/spec/mes/05c_caller_group.md`.
  - [x] Close the `27C3B.MES` caller group (one site): `EVENTA01`, a root
    handoff behind a 17-conjunct Saturday guard, the callee asking three
    answers that move the A word (answer 3 behind a `> 1` gate), closing
    `[1110]` and `[1112]` and stamping 271 at its door to FLOOR4; a direct
    reentry jumps through its gate to the same door. Three routes by answer;
    `27c3b_a01_v6.json` 540 checks. Evidence:
    `docs/spec/mes/27c3b_caller_group.md`.
  - [x] Close the `REIKO42.MES` caller group (one site): `EVENTF07`, a root
    handoff behind a ten-conjunct summer-weekday guard, the callee counting
    `[264]` before its gate, closing `[1631]` early and asking three answers
    that move `[200]` behind `> 3` gates before stamping 42 at its door to
    MACHI. Three routes by answer; `reiko42_f07_v6.json` 453 checks.
    Evidence: `docs/spec/mes/reiko42_caller_group.md`.
  - [x] Close the `06M.MES` caller group (one site): `EVENTK06`, a root
    handoff behind a seven-conjunct guard whose date is the day after the
    stored word `[268]`, selected by answer 1 of the map's own two-answer
    question at 3905, the caller moving `[207]`/`[208]` under a clock ladder
    and closing `[2313]` in the gap; the callee counts `[198]`, moves both
    words, asks three answers and stamps 6 at its door to MACHI, and a direct
    reentry replays the whole body (no done-gate of its own). Three routes by
    answer with both contracts; `06m_k06_v6.json` 643 checks. Evidence:
    `docs/spec/mes/06m_caller_group.md`.
  - [x] Close the `16M.MES` caller group (one site): `EVENTQ01`, a root
    handoff selected by answer 1 of the map's own question inside a
    constant-true loop (origin the answer branch at 40886, the MACHI E04 /
    E10 shape; `post_guard_expected` 1), the callee's first-visit body
    advancing `[2062]`, closing `[2063]` and stamping 16 at its door to
    MACHI, a direct reentry taking the `[2063]` arm to the same door in 16
    messages; the five later stages are named and not measured.
    `16m_q01_v6.json` 156 checks. Evidence:
    `docs/spec/mes/16m_caller_group.md`.
  - [x] Close the `10M.MES` caller group (one site): `EVENTM04`, a nested
    call behind a six-conjunct guard and the map's own two-answer question at
    19649, the callee counting `[244]` before its gate and closing `[2424]`;
    the resume closes `[2423]` and `[2439]`, stamps 10 and hands the root to
    MACHI at 21144 (v5 natural handoff). `10m_m04_v5.json` 251 checks.
    Evidence: `docs/spec/mes/10m_caller_group.md`.
  - [x] Close the `19M.MES` caller group (one site): `EVENTM15`, a nested
    call behind a seven-conjunct autumn guard and the map's own question at
    12968, the callee counting `[148]` when `[204]` is in 41..80 and closing
    `[2501]`; the resume closes `[2500]` and `[2439]`, stamps 19 and hands the
    root to MACHI at 14483 (v5). `19m_m15_v5.json` 368 checks. Evidence:
    `docs/spec/mes/19m_caller_group.md`.
  - [x] Close the `21M.MES` caller group (one site): `EVENTM08`, a nested
    call behind a nine-conjunct summer guard and the map's own question at
    11618, the callee calling M_PIC and closing `[2441]`; the resume closes
    `[2440]` and `[2439]`, stamps 21 and hands the root to MACHI at 13326
    (v5). `21m_m08_v5.json` 264 checks. Evidence:
    `docs/spec/mes/21m_caller_group.md`.
  - [x] Close the `43C.MES` caller group (one site): `EVENTM05`, a nested
    call behind a four-conjunct evening guard, the callee counting `[244]`
    before its gate on `[2422]` and never writing it; the resume closes
    `[2422]` at 4957 and stops at the floor's own routine-40 at 20161 (v8
    def_selection_boundary; the post-guard truth reads the resumed state).
    `43c_m05_v8.json` 182 checks. Evidence:
    `docs/spec/mes/43c_caller_group.md`.
  - [x] Close the `46M.MES` caller group (one site): `EVENTJ09`, a nested
    call behind a 14-conjunct evening guard, the callee closing its own
    `[910]`; the resume closes `[210]`, stamps 46 and hands the root to MACHI
    at 2625 (v5). The first caller-continuation route built by the toolchain;
    `46m_j09_v5.json` 443 checks. Evidence:
    `docs/spec/mes/46m_caller_group.md`.
  - [x] Close the `A_DATE5.MES` caller group (one site): `EVENTA17`, a nested
    call behind a five-conjunct winter guard and the script's own two-answer
    question at 2835 (answer 1 moves the A word up two), the callee asking
    three answers whose chain shares one body and closing `[1125]`; the
    resume hands the root to MACHI at 3949 with no message (v5). Three routes
    by answer with both contracts; `a_date5_a17_v5.json` 333 checks.
    Evidence: `docs/spec/mes/a_date5_caller_group.md`.
  - [x] Close the `H_DATE3.MES` caller group (one site): `EVENTH19`, a nested
    call behind two nested guards (origin the outer, the H word above 90 and
    `[2081]` clear; the inner date/clock/`[2335]` guard in its gap, the 28C
    L13 shape, `post_guard_expected` 1), the callee asking three answers that
    move the H word behind `> 3` / `> 5` gates; the resume closes `[2335]` and
    hands the root to H_DATE5 at 18707 with no message (v5). Three routes by
    answer; `h_date3_h19_v5.json` 426 checks. Evidence:
    `docs/spec/mes/h_date3_caller_group.md`.
  - [x] Close the `K_DATE3.MES` caller group (one site): `EVENTK15`, a nested
    call behind a five-conjunct winter-evening guard with a 10-byte gap, the
    callee counting `[108]` when `[200]` is in 31..80 before its gate on
    `[2341]`; the resume writes `[2268]`, closes `[2341]` and hands the root
    to K_DATE5 at 17418 with no message (v5). `k_date3_k15_v5.json` 314
    checks. Evidence: `docs/spec/mes/k_date3_caller_group.md`.
  - [x] Qualify wider outer eligibility and remaining branch states across the
    measured GROUND groups. (Closed 2026-09-19 on the 2026-09-15 record the last
    sentence names: the arrival declarations of every measured origin.)
    Distinguish
    remaining branch witnesses from path-normalized states and retain Python
    strict-tail boundaries until separately refined. None of these groups
    qualifies the complete outer scheduler or all native effects.
    Widened 2026-09-14: the measured groups now span every caller, and the
    question is the same at every map-arm origin (FLOOR1/4/5, MACHI,
    GROUND): the arm the host selects is `state_u16[21]`, copied from the
    `Util(6,13)` map poll that Core 0.318.0's map-location contract can
    supply, so the polls of `MACHI`, the floors and `GROUND` can be declared
    the way `TRAIN` was and the arm selection measured instead of seeded.
    TODO.md Execution Order step 1.2.
    Started 2026-09-14 with FLOOR4 (Core 0.319.0: a contract may name the
    caller's own poll, spent by the prefix or the resume). Polls exist in
    `FLOOR1..5.MES` and their `.INC` menus, `GROUND.MES`, `MACHI.MES` and
    its menu, and `TRAIN.MES` - not in `44C.MES` or `DENSHA.MES`, so the
    44C groups' `[21]` seeds are choice results, not arms. FLOOR1 I04's
    three stages followed the same day (arm 3, poll 2816); the segmented
    chain now carries one queue so a floor entered and left again can
    declare both locations - FLOOR4 F03 is the first, `[6, 0]`, and it
    exposed that the validator started a v8/v10/v12 unbroken run at the
    guard rather than the origin (invisible while the two coincided; fixed
    with it). FLOOR5 followed: M18/H10/H16 `[4, 0]` and G21 `[0]`
    (`floor5_*_v12.json`, 482/525/668/389 checks). MACHI E04/E10 followed
    with `[9, 9]` and `[26, 26]` - and corrected their resumes: the
    2026-09-12 reading (the shared tail, the menu skipped, `44M` as
    destination 0's target) was the unseeded `[18] = 0` at the second poll;
    with the player still on the destination the map plays its scene, `13C`
    at 30797 after E04 and `MIZUHO26` at 57269 after E10
    (`machi_e04_v12.json` 402 checks, `machi_e10_v12.json` 470).
    GROUND followed: C07, C12 (both calls, the second as its own group), K02,
    H15 (v12) and F02 (v11) from the grounds' entry with location `0`, the
    cascade's branches handing the root to MACHI on their own
    (1620/1668/1272/910/1631/592 checks); A07's arrival is added
    beside its 2026-09-09 group (`ground_a07_arrival_v11.json`, 409),
    because from the grounds' entry 50 of that group's 54 chains reach
    G08's branch before A07's - a reading only the arrival gives. A parity
    check of every replaced profile against its predecessor found variants
    the drafter had not derived (F03 2, FLOOR5 4, MACHI 7, GROUND 142 across
    the five replaced); all are ported into the specs and re-verified, so no
    measured witness is dropped. MACHI E18 (`[0]`, `machi_e18_v11.json`, 480
    checks) and FLOOR5 E15B (`[2, 0]`, `floor5_e15b_v12.json`, 386) followed.
    Still on their guards until 2026-09-15: FLOOR5 F01 and E15A and GROUND G08, the
    v7/v9 window shapes. The owner asked for the audit to be widened to
    them; measured, that was not the missing piece - a window proof from
    the map's entry would contain the arm switch, whose edges skip the
    dispatch by design - so each got an arrival group beside its window
    group, and the arrival found the guards the window origins had hidden:
    G08 behind the cascade branch at 27661 (Saturday, 6/16..9/15,
    15:01..17:29, six flags), F01 behind 2778 (Saturday, 4/01..6/15,
    12:31..16:00, six flags), E15's site A behind 4938 (9/16..11/15,
    12:30..14:29, E word > 70, [2509] < 12, six flags incl. the seen flag)
    (`ground_g08_arrival_v11.json` 751 checks, `floor5_f01_arrival_v12.json`
    504, `floor5_e15a_arrival_v12.json` 543); no audit change was
    needed. Still on their guards: MACHI G04 (on the entry path before the
    poll) and the H17/K09/H01/H02/K01/K_PIC historical groups (v1-v4) - until
    2026-09-15, when the owner asked for the recommended arrival groups: H17,
    K09, K01 (both sites) and K_PIC are declared beside their v2/v4 groups
    from the grounds' entry as leaving-school events
    (ground_h17_arrival_v12.json 859, ground_k09_arrival_v12.json 1743,
    ground_k01a_arrival_v12.json 344, ground_k01b_arrival_v12.json 265,
    ground_kpic_arrival_v12.json 569 checks), H01/H02 stay - they are
    entry-path events before the poll, as MACHI G04 is. Every location intro
    is now declared from its map's arrival; step 1.2's declarations are
    complete.
    The owner's reading of the grounds (2026-09-15): location 0 is the way out
    to the town map, and the map change after an event is the location's exit,
    not the event's - the player who walks to the gate changes map with or
    without an event (every location-0 branch ends in an inline copy of the
    exit; the cascade's last branch is the bare one; the entry path closes the
    grounds past 17:59 on its own). Declared separately: the builder derives
    bypass variants from turned-away walks that leave by a `bypass_targets`
    handoff, the qualifier mutation-tests them, and the eight location-0
    groups now carry them (ground_c07_v12.json 1648, ground_c12_v12.json 1696,
    ground_c12_second_v12.json 1296, ground_k02_v12.json 935,
    ground_h15_v12.json 1685, ground_f02_v11.json 750,
    ground_a07_arrival_v11.json 434, ground_g08_arrival_v11.json 833 checks;
    16 bypasses in all, the `no-event-*` witnesses leaving by the gate with
    `[16] = 13` and the events' flags untouched; K02's 15:5x chains and
    A07's/G08's diverted chains stay measured and not declared, now with their
    door or stop named).
  - [x] Extend reachability beyond literal dispatch before any entry is called
    unreachable. Measured 2026-09-09: the corpus inventory's 587/429 partition
    is scope-bound, not archive-wide. Content Core's strict aligned decoder
    stops at the first opaque boundary in each address-table region, leaving
    1,180 preserved tails in 496 entries (719,650 bytes, 3.98% of the
    bytecode), and 418 of the 429 "never dispatched" entries are named by a
    byte-exact `<0x0F|0x0E> 01 <name> 00 00` record inside one. The scanner is
    validated against the decoder first: it reproduces all 10,474 rows at the
    same offsets and targets, disagrees on none, and finds nothing extra in any
    region the decoder read, so all 650 additional records are tail records.
    `EVENTA13.MES` is therefore no longer an `unreachable_stored_route`
    candidate - `FLOOR4.MES:0x0E4C` names it - and `EVENTL09.MES` is the only
    `EVENT*.MES` entry nothing names. The two command-`0x0D` inline script
    execution sites in `START.MES` are measured as the mechanism reaching
    `LIBLARY.LIB` and `DEF_MAIN.MES`. Eight entries are named by nothing.
    Cross-entry naming is now closed: the archive expresses it only through
    these three forms. Native address-row selection *within* an already-named
    entry stays unqualified and cannot widen the partition. Being named in a
    tail is not evidence that the record executes. Evidence:
    `docs/spec/mes/dispatch_naming_reachability.md`.
  - [x] Qualify EVENTJ04 from `01M.MES:0x9A8C` through its handoff at `0x9B85`:
    four flag-854/823 presets, shared library, exact MACHI terminal and completed
    reentry rejection. Core 0.305.0 exposes a catalog-declared bounded analysis
    action with native effects omitted. Evidence: `docs/spec/mes/eventj04_route.md`.
  - Current catalog coverage is 13 of 129 reachable EVENT-named targets. EVENTB
    and EVENTD retain their previous coverage; EVENTJ now has one qualified
    entry. Other J entries and eleven other families remain uncataloged.
  - **Superseded 2026-09-23 by EP-10 (to be restated when this item opens,
    TODO step 2):** the catalog is 142 generated rows, 139 `minimal_playback`
    and 3 `analysis_only` (`original/eventh01/ground-00000a34`,
    `ground-00000db9`, `original/eventh02/ground-000010df`). What this item
    still owns is those three rows, the rows that stop at a dependency
    boundary in the package playback check, and the unreferenced entries'
    classification.
  - **Measured 2026-09-23 (TODO step 2).** Of the 23 rows the package
    playback check reported as stopped at EP-10 unit 5c, 20 stop exactly at
    their catalog-declared `def_selection_boundary` terminal - the place
    script's own menu (`44M.MES` 0xFFBA x9, `44C.MES` 0xB380 x6, `11M.MES`
    0xCF99 x2, `06C.MES` 0x96D4 x2, `43C.MES` 0x4EC1 x1), which EP-09 names
    `place_menu`. The check now counts a stop only when it is not such a
    declared menu terminal: `original playback package playback` at Core
    0.360.0 reports 142 rows, 119 reaching a terminal, 20 ending at a
    declared place menu, 3 stopped (976 checks, pass). The 3 stops are the
    H01 first/repeat and H02 first routes of `ground_h01_h02_v3.json`, a
    v3 profile whose resume stops before GROUND dispatches the next event
    (`EVENTK01.MES` at 6308 and 16859, `K_PIC.MES` at 7227) - the same
    dispatches the K01/K_PIC group already carries to `MACHI.MES`
    (`docs/spec/mes/ground_k01_kpic_analysis.md`). How those three end is
    put to the owner.
  - **Ruled and done 2026-09-23 (owner, option 1 of three: end at the next
    event's call).** A dependency stop that lands exactly on another catalog
    row's intro dispatch ends by continuing into that event (`chain`); the
    next event plays as its own row. Catalog revision 26: the three rows are
    `minimal_playback` (142 of 142), their `dependency_stop` terminals carry
    the next event's callee as `next_target`, the loader rejects a
    `next_target` that is not another row's intro callee, and the vocabulary
    (Python and port) reads such a terminal as `chain`
    (`docs/spec/data/event_outcome_vocabulary.md`). Classification 130
    playable / 34 system / 1 unreachable / 2 unresolved over 167 (only
    `EVENTH01.MES` moves - the classification is per entry and EVENTH02 and
    K_PIC already played through other rows). The 142 v4 documents re-bound
    to the fresh package (`package_sha256` only; `projected=142 valid=142`);
    the names registry is byte-identical. Verified 2026-09-23: the Python
    suite (1,844 tests), `test_event_outcome_vocabulary` (79 Python, 325
    scene checks), `test_event_catalog.tscn` (76), the local batch (134 of
    134), `promote_analysis_groups.py --check`, and with the archive
    `original Event Catalog source bindings`, `original playback package
    export`, `original playback package playback` (119 terminal / 20 place
    menu / 3 next event / 0 stopped), `original Event Player fragment
    catalogs` and `original catalog group routes` (221 runs, 13,061 checks,
    outcomes chain 15 / map_return 172 / place_menu 28 / unresolved 6,
    1,537 s; it timed out twice at its 1,800 s limit first while a whole
    batch shared the machine - TD-33's follow-up shards it).
  - **Measured 2026-09-23, each awaiting an owner choice before any
    change:** `EVENTM11.MES` - `EVENTM10.MES` climbs a visit ladder on
    `global_u8[2456]` (0..3) and calls `EVENTM11` once on each of its
    second, third and fourth visits behind a 23-flag gate
    (`global_u8[287..302]`, `[316..318]`, `[320..323]`; the fourth adds
    `[319]`); replays with a seeded counter and gate flag reach the calls
    at `13274` and `16586` (6 messages, `global_u8[10..20]` written, return
    `37546`); the later visits need site B's `[2417]`, whose only clear is
    in registered definition 12, the day-change routine definition 11 runs
    when the clock crosses midnight - replays confirm `[2417]` clears at
    each day change - so the later visits and `EVENTM11` are reachable one
    day at a time (`docs/spec/mes/44c_caller_group.md`; not established:
    `global_u8[534]` at a natural midnight, and which events set the 23
    gate flags). **Ruled 2026-09-23 (owner, option 1 of three):** measure
    first how many events change their body over several visits the way
    EVENTM10 does, then design one representation for all of them (a
    contract change lands as a new directory beside the old); until then
    `EVENTM11.MES` stays `unresolved_route` with this evidence. The census
    spec is `analysis/_docs/ep03_visit_ladder_census_spec.md`.
  - **Visit-ladder census, 2026-09-23** (Python handoff of all 131 `EVENT*`
    entries and `K_PIC.MES`, no failures; a ladder is a chain of equality
    tests on one cell whose rungs write that cell forward): 9 entries, 34
    ladders, 84 rungs, 10 declared by a committed profile, 74 undeclared,
    2 undeclared rungs dispatching an EVENT script (EVENTM10 -> EVENTM11).
    31 ladders are the two-rung first-visit / later-visit idiom. Three have
    three or more rungs: EVENTM10 `global_u8[2456]` (4, known);
    **EVENTM03 `global_u8[2421]` (15 rungs from `14092`, none declared:
    replays with M03's baseline flag `[2420] = 1` and the counter seeded
    `0..14` reach all fifteen, 14-32 messages each, each writing the counter
    forward, all returning at `38838..38839`, no dispatch)**; and EVENTA20
    `global_u8[1131]` (3, nested in the rung of `[1127]`; replays stop at an
    unanswered menu at `0x237F` before it, not confirmed). Two-rung chains
    no committed route reaches: EVENTG01 `[1462]`, EVENTG02 `[1391]`
    (not replayed). EVENTM11's 20 chains are independent shown-once flags,
    not visits. Report and JSON: `analysis/_undoc/ep03_visit_ladder_census*`
    (untracked). The representation design is next, for the owner. `05C.MES` (ruled and done the
    same day, owner: a non-EVENT script that is the measured caller of an
    analysis group is a system script; classification 130 / 35 / 1 / 1,
    only `05C.MES` moved) - the classifier
    names a non-EVENT script a system script only when more distinct
    callers reach it than reach any EVENT target (2); 05C has exactly 2
    (`05M.MES:23549`, `EVENTL06.MES:13753`, both root handoffs), so it
    falls through to `unresolved_route` though it is the place script
    that hosts EVENTI21. The pictures - the 10 misses are six names
    (`b01z`, `b02z`, `b02zan`, `d01z`, `d01zan`, `d02z` `.mmo`) that the
    B01, B02, D01 and D02 scripts name in `mmo_resource_marker` records
    and that no shipped archive contains (`docs/spec/mes/12c_caller_group.md`,
    `13c_caller_group.md`), named by the sharded validator's
    `PLAYBACK_PICTURE_MISSING` lines since TD-33 part 2. Earlier wording of
    this entry: `EVENTM11.MES`,
    called by `EVENTM10.MES` at `9545`, `13274` and `16586` but reached by
    no measured `44c-m10a`/`44c-m10b` state; `05C.MES`, a place script
    classified `unresolved_route` because it is only a measured caller
    (`05c-i21`) and handoff terminal (`05m-l06`); and 10 of 668 pictures the playback pass does not resolve
    in the content set (658/668 since EP-10 unit 5c on 2026-09-21 - the
    check counts them without failing). Done the same day: EVENTC06 and
    EVENTE11 at `15C.MES`, whose `loop_boundary` ending the catalog-side
    vocabulary read as unresolved while the v4 and profile rules read it as
    `place_menu` - the catalog rule (Python and port) now reads it as
    `place_menu`, so every catalog row ends in a named game outcome (113 /
    22 / 7 / 0 / 0); verified by `tests/test_event_outcome_vocabulary.py`
    (80) and `test_event_outcome_vocabulary.tscn` (326).
  - Owns Event Player product goal E-01 and delivery-sequence step 1.
- [x] **EP-05 — Complete catalog-wide playback regression.**
  Closed 2026-09-23 by the owner on the whole-tree run below (375 of 375 at
  `db59f4b` with `--jobs 4`: every catalog row driven through its measured
  route by the four `original catalog group routes` shards and, from the
  bytecode and from the package alone, by `original playback package
  playback`). The regression is kept up by the tiers, the cache and
  `--jobs N` at every milestone (`docs/spec/data/validation_checks.md`).
  - **Whole batch at Core 0.360.0 with the group routes sharded,
    2026-09-23 (`db59f4b`).** `--tier full --jobs 4` with `--elfimage` and
    `--exe`, uncached, on a detached worktree: 375 checks, 375 passed,
    2,897 s (report v6, `analysis/_undoc/full_jobs4_db59f4b_report.json`),
    including the four `original catalog group routes` shards (all 142 rows,
    their sums equal to the unsharded run) and `original playback package
    playback` (142 rows: 119 terminal / 20 place menu / 3 next event / 0
    stopped). This is the closure evidence the item waited for; the owner
    closed the item on it the same day.
  - **Whole batch at Core 0.360.0, 2026-09-23 (TODO step 1).** `--tier full`
    with `--elfimage` and `--exe`, `--cache-store`, on a detached worktree of
    the committed tree `5fb4337`: 372 checks, 371 passed, 1 timed out,
    7,638 s (report `kakyu_content_tools_validation/v5`; kept as
    `analysis/_undoc/full_batch_0360_5fb4337_report.json`). The one
    non-pass is `original catalog group routes` at its 1,800 s limit while
    two agents shared the machine (it takes ~1,500 s alone and passed in
    1,537 s on the next tree the same day); every other check - the 227
    archive checks, the 12 native executable checks, the event corpus and
    the voice payload - passed, and the green results seeded the cache.
    The closure evidence for this item is a whole run at the final tree
    with the group-routes check inside its limit (TD-33 shards it).
  - **Whole-tree batch at Core 0.350.0, 2026-09-19 (WD-18).** 372 checks, 372 passed, 0 failed, 7,989 s (report schema `kakyu_content_tools_validation/v3`, run `5d44ef6a`): 129 Godot scenes, the project parse check, the Python regression suite (1,663 tests over nine shards) and 241 checks against the original archives and `AI5WIN.original.exe` - the 140 `original event analysis` group checks, 17 original Event Player integration and preset checks, the exhaustive MES entry audit (`original MES analyzer handoff corpus`, 686 s), the full Python Phase 1-4 handoff equivalence (1,196 s), the corpora, contracts and source matrices, the 12 native executable checks and the native voice payload check. Nothing needed re-baselining: the two native checks the 0.318.0 run corrected pass as recorded. This is the first whole batch since 0.318.0 (2026-09-14); the batch grew from 328 to 372 checks meanwhile (a check per analysis group and the archive-authoring, workspace and display checks of 0.319.0-0.350.0).
  - The FLOOR5 M18, H10 and H16 groups join the normal batch on the **v5**
    caller-continuation contract with `natural_handoff` resumes bound inside
    the floor's opaque tail, `original event analysis FLOOR5 M18` / `H10` /
    `H16`, and pass 381, 498 and 541 checks with no failures; the audits
    reject a shifted resume handoff and a shifted reentry return, the
    validator a wrong resume message count. They promote the three events to
    analysis-group measured and bind `FLOOR5.MES` and `FLOOR4.MES`, taking the
    bound entries to 46 and the confidence split to 49/28/92. Nine 44M
    groups, thirteen GROUND groups, four 01M groups and three FLOOR5 groups
    now run together. The FLOOR5 G21 group follows on the same contract,
    `original event analysis FLOOR5 G21`, 264 checks, bound entries 47,
    split 49/29/91. The 18M C11 (v6, 351 checks) and I05 (v6 with a callee
    contract, 465) groups follow, bound entries 51, split 49/33/87; then the
    18M K13 (v5, 319) and L04 (v5 with a callee contract, 451) groups, bound
    entries 53, split 49/35/85; then the 18M I09 (v6, three routes, 829) and
    M16 (v5 with the caller's contract, 358) groups, bound entries 56, split
    49/37/83; then the 44C I24 (v8, 209) and L25 (v8, 204) groups, bound
    entries 58, split 49/39/81; then the 44C M03 group (v8, two routes, 684),
    bound entries 59, split 49/40/80, under Core 0.315.0's declared post-guard
    truth; then the 44C M17 (v8, 175), M10A (v8, 141) and M10B (v8, 143)
    groups, bound entries 62, split 49/43/77; then the 17M C10 group (v5, two
    routes with the caller's contract, 447), bound entries 64, split
    49/44/76; then the 17M A10 group (v6, 234), bound entries 65, split
    49/45/75; then the 17M A02 group (v6, three routes with the callee's
    contract, 602), bound entries 66, split 49/46/74; then the 17M A20A (v6,
    two routes, two contracts, 579) and A20B (v6, two routes, 515) groups,
    bound entries 67, split 49/47/73; then the five 23M groups - C02 (v6,
    308), E01 (v6, three routes with the callee's contract, 623), C05 (v6,
    305), C17 (v6, 296) and E03 (v6, 248) - bound entries 74, split
    49/52/68; then the 21C A08 (v6, two routes with the caller's contract,
    676), C08 (v6, 350) and L07 (v5, two routes with the caller's contract,
    721) groups, bound entries 77, split 49/55/65; then the four 26M groups -
    C01 (v6, three routes with the callee's contract, 581), C04 (v6, 341),
    H06 (v6, 291) and C21 (v6, 313) - bound entries 81, split 49/59/61; then
    the four MACHI groups - G04 (v6, three routes, 355), E18 (v6, two routes
    by door, 343), E04 (v5, 582) and E10 (v5, 711) - bound entries 85,
    split 49/63/57; then the 03C J14A (v6, two routes, two contracts, 503),
    J14B (v6, 565) and J15 (v6, four routes by door, 1000) groups, bound
    entries 88, split 49/65/55; then the 07M A19 (v6, 365), G14 (v6, 269) and
    J19 (v6, three routes by door, two contracts, 1999) groups, bound entries
    91, split 49/68/52; then the 11M H04 (v6, 328), K14 (v8, 511) and
    J01 (v8, three routes by answer, 1154) groups, bound entries 94,
    split 49/71/49; then 15C I10 (v6, answer 2 only, 494), bound entries
    95, split 49/72/48; then the 25C A03 (v6, three routes by answer, 1053),
    F20 (v6, 383) and E05 (v5, 337) groups, bound entries 98,
    split 49/75/45; then the 30C G01A (v6, eight talk contracts, 672),
    G01B (v6, 689) and G01C (v6, 619) groups, bound entries 109,
    split 49/76/44; then the 35M I13 (v6, 319), G02 (v6, three routes by
    answer, 1177) and L02 (v6, three routes by answer, 1079) groups, bound
    entries 112, split 49/79/41; then the 05M J07 (v6, 425) and L06 (v6,
    `nested_root_handoff`, two routes by the second answer, 1086) groups,
    bound entries 115, split 49/82/38; then the 06C J18 (v8, 373) and L08
    (v8, three routes by answer, 567) groups, bound entries 117, split
    49/84/36; then the 09M L11 (v6 with the caller's contract, 318) and
    M20 (v6, two routes by the callee's answer, 433) groups, bound entries
    119, split 49/86/34; then the 27C_EV M01 (v5, 371) and M14 (v5, 414)
    and FLOOR4 F03 (v5, 809) groups, bound entries 124, split 49/90/30.
    Ninety-five committed groups were registered in the batch; then the
    19C L05 (v6, 280), 27C1A C03 (v6, 292), 29C A05 (v6, 322) groups, bound entries 128, split 49/93/27.
    Ninety-eight committed groups were registered in the batch; then the
    34C L20 (v6, 325), 33C A04 (v6, 434), 32C I23 (v6, 264), 10C D06 (v6, 423) groups, bound entries 132, split 49/97/23.
    One hundred and two committed groups were registered in the batch; then
    the 20C L16 (v6, 485), 28C L13 (v6, 429) groups, bound entries 134, split 49/99/21.
    One hundred and four committed groups were registered in the batch; then
    the 05C I21 (v6, 414), 27C3B A01 (v6, 540), REIKO42 F07 (v6, 453), 06M K06 (v6, 643), 16M Q01 (v6, 156) groups - the first qualified with the route toolchain -
    bound entries 139, split 49/104/16.
    One hundred and nine committed groups were registered in the batch; then
    the 10M M04 (v5, 251), 19M M15 (v5, 368), 21M M08 (v5, 264), 43C M05 (v8, 182), 46M J09 (v5, 443), A_DATE5 A17 (v5, 333), H_DATE3 H19 (v5, 426), K_DATE3 K15 (v5, 314) groups - the eight nested calls, the toolchain's first
    caller-continuation routes - bound entries 147, split 49/112/8; then
    the 44M J11 group (v6, 469), qualified once Core 0.316.0 read its
    second body, bound entries 148, split 49/113/7; then the 15C C06
    (**v10**, three routes by answer, 1140) and E11 (v10, three routes by
    answer, 893) groups - the first declared on the caller-menu-loop
    resume - bound entries 150, split 49/115/5; then the FLOOR4 A13 (v6,
    three routes by answer, 542) and L18 (v6, three routes by answer,
    568) and FLOOR1 I04A (v6, 293), I04B (v6, 231) and I04C (v6,
    221) groups - the sites Core 0.316.0 uncovered in the floors' arm
    switches - bound entries 152, split 49/117/3; then 15C I10 rebuilt
    as three routes by answer (v6, 580), bound entries and split
    unchanged; then the 01M H07 (**v11**, 306), M06 (**v12**, 333) and
    M09 (v12, 404) groups - the first declared through a map-location
    contract, binding `TRAIN` for the first time - bound entries 156, split
    49/120/0: no structural row left.
    One hundred and seventeen committed groups are now registered in the batch. The
    FLOOR5 E15B (v5, 371 checks), F01 (**v9**, 359) and
    E15A (v9, two routes, 388) groups follow; Core 0.314.0's v9 audit and
    validator, with the corrected window classification, accept all 33
    committed groups together (1,377 Python tests). Bound entries 49, split
    49/31/89.
  - The 01M L03 group joins the normal batch on the **v5** caller-continuation
    contract with the `natural_handoff` resume policy, `original event
    analysis 01M L03`, and passes 324 checks with no failures; the audit
    rejects a shifted resume handoff and the validator a wrong resume message
    count. It promotes `EVENTL03.MES` to analysis-group measured and binds
    `L_PIC.MES`, taking the bound entries to 41 and the confidence split to
    49/25/95. Nine 44M groups, thirteen GROUND groups and four 01M groups now
    run together.
  - The 01M D05 group joins the normal batch as a **v6** root replacement
    with a callee choice contract, `original event analysis 01M D05`, and
    passes 896 checks with no failures; the audit rejects a shifted terminal
    offset and the validator a variant declared under the wrong result. It
    promotes `EVENTD05.MES` to analysis-group measured and binds `D_PIC.MES`,
    taking the bound entries to 39 and the confidence split to 49/24/96.
    Nine 44M groups, thirteen GROUND groups and three 01M groups now run
    together.
  - The 01M G11 group joins the normal batch as a **v6** root replacement,
    `original event analysis 01M G11`, and passes 555 checks with no failures;
    the audit rejects a shifted terminal offset and the validator a wrong
    reentry message count. It promotes `EVENTG11.MES` to analysis-group
    measured and binds `G_PIC.MES` from this caller, taking the bound entries
    to 37 and the confidence split to 49/23/97. Nine 44M groups, thirteen
    GROUND groups and two 01M groups now run together.
  - The 01M I16 group joins the normal batch as a **v6** root replacement,
    `original event analysis 01M I16`, and passes 306 checks with no failures;
    the Python source audit accepts it and rejects a shifted terminal offset,
    and the validator rejects a wrong reentry message count nine times, once
    per variant. It promotes `EVENTI16.MES` to analysis-group measured and
    binds `MACHI.MES`, `DEF_MAIN.MES` and `LIBLARY.LIB` a further time, taking
    the bound entries to 36. The confidence split is now 49/22/98 over the
    same 169 rows; the 48/21/100 recorded with the L09 classification was
    already 49/21/99 by then, because that classification moved L09's own row.
    Nine 44M groups, thirteen GROUND groups and one 01M group now run
    together.
  - `audit_duplicate_entries.py` joins the batch as `original duplicate archive
    entries` whenever ELFIMAGE is supplied, reproducing its tracked report
    `config/event_catalog/duplicate_entries_v1.json` in about 13 seconds. Every
    count it reports is a fail-closed expectation, and five mutations are
    rejected: a changed count in the tracked report, a gallery envelope
    removed from the naming audit, a gallery envelope's command changed, the
    naming schema altered, and a gallery entry dropped from the set named only
    in opaque tails. The local 95-check batch still passes with the check
    registered, and an `--exe`-only run is unaffected.
  - `audit_unreferenced_entries.py` joins the batch under the original executable
    and reproduces its tracked report. The 44M L10 group grows to 647 checks with
    the `global_u8[532]` gate variants included.
  - The 44M H18, I14 and A22 groups join the normal batch on the existing v8
    contract and pass 660, 660 and 510 checks with no failures. A22 declares two
    routes for the two routine-40 results that return, and leaves the third
    measured but undeclared. Nine 44M groups and thirteen GROUND groups now run
    together; the confidence split is 48/21/100 over the same 169 rows.
  - The 44M L10 group joins the normal batch as a **v6** root replacement with
    two routes in one profile and passes 575 checks with no failures. It needed
    no schema change: two terminals became two routes rather than one route with
    a variable ending. It promotes three index rows, `EVENTL10.MES` and the two
    roots `44C.MES` and `MACHI.MES`, taking the confidence split to 48/18/103.
  - The 44M F06 group joins the normal batch on the same v8 contract and passes
    1,136 checks with no failures, the largest group in this caller. It is the
    first 44M group with a routine-40 choice contract, so its variants each
    select a result and the runtime checks all three. The confidence split is
    now 48/17/104 over the same 169 rows.
  - The 44M F17 group joins the normal batch on the same v8 contract and passes
    669 checks with no failures, taking the confidence split to 48/16/105 over
    the same 169 rows. Five 44M groups and thirteen GROUND groups now run
    together in the normal batch.
  - The 44M F22 group joins the normal batch on the same v8 contract and passes
    669 checks with no failures. It promotes two index rows rather than one,
    `EVENTF22.MES` and the nested `F_PIC.MES`, so the confidence split was then
    48/15/106 over the same 169 rows.
  - The 44M H11 group joins the normal batch on the same v8 contract and passes
    756 checks with no failures, needing no schema change of its own. Landing it
    moved the route classification again, as designed: `EVENTH11.MES` becomes
    analysis-group measured and the confidence split was then 48/14/107.
  - The 44M C18 group joins the normal batch on Core 0.313.0 and passes 571
    checks with no failures; its Python source audit reports the v8 schema. Ten
    mutations of the new caller-resume policy are rejected, including the two
    that claim an existing policy for this record and the one that points the
    stop at a real command-`0x1D` record whose routine is not 40. Five synthetic
    tests cover the same ground, taking the analysis-profile suite to 41. No
    native, GUI or catalog coverage is claimed by this run.
  - The naming report is tracked as
    `config/event_catalog/dispatch_naming_v1.json` so the route classification
    can consume it, and the audit's 33rd check compares the tracked file against
    a fresh run. That comparison ignores `content_core_version` and the
    fingerprint over it, so it does not go stale on a Core bump the way the
    inventory's recorded hash did; changing one count in the tracked file fails
    it. The classification reproduces at 11,124 audited records with thirteen
    naming-evidence mutations rejected.
  - The dispatch naming audit joins the normal batch with 33 checks and no Core
    change. It reproduces the literal dispatch inventory's own 10,474 rows,
    587 targets and 429-entry never-named set before scanning past them, so the
    two instruments are checked against each other rather than run side by
    side. Seven mutations were run: five fail closed, including both attempts to
    remove the decoder-agreement control, and two are recorded as
    non-discriminating measurements rather than gaps. No native, GUI or catalog
    coverage is claimed by this run.
  - The G08 group joins the normal batch and passes 495 assertions on the new
    v7 shape. Seventeen synthetic audit mutations and one runtime mutation were
    checked to fail closed, including widening the window until an edge escapes,
    so the window proof is not vacuous. Fifteen focused checks pass together -
    project parse, the route-probe definition scene and all thirteen GROUND
    groups - and the whole Python regression passes at 1,367 tests.
  - The F02 group joins the normal batch and passes 607 assertions with no Core
    change: v6 already carried the root-replacement contract. Its Python audit
    and runtime report hashes are recorded with the evidence. Fourteen focused
    checks pass together - project parse, the route-probe definition scene and
    all twelve GROUND groups - so no earlier group identity changed. No native,
    GUI or full corpus coverage is claimed by this run.
  - Core 0.311.0 registers the H15 and A07 groups in the normal batch. Both pass
    with 1,655 and 1,912 assertions, and their documented Python audit and
    runtime report hashes reproduce. Eleven focused checks pass alongside them:
    project parse, the route-probe definition scene and all nine existing GROUND
    groups, so the new root-handoff branch changes no earlier group identity.
    The whole Python regression passes at 1,364 tests, including the 33
    analysis-profile tests. No native, GUI or full corpus coverage is claimed
    by this run.
  - K02 V5 joins the normal batch with 693 passing assertions and exact source,
    profile and runtime identities retained in its MES evidence document.
  - Core 0.310.0 passes parse/repeated-call regression, existing V2-V4 group
    identities, all thirteen seeds' package equivalence and the new C07/C12
    groups (1,086/3,502 assertions). Twenty-nine Python profile tests and
    23 batch-runner tests pass. A source-valid unrelated-guard substitution
    fails only the required runtime acceptance proof. Both new groups join
    the normal batch; broader original/native/GUI coverage remains open.
  - V4 origin/continuation/bypass evidence passes 12 focused headless checks
    and 47 Python tests (24 profile, 23 batch runner). The three new groups
    contain 77 full-path cases and 1,971 assertions; existing V2/V3 runtime
    fingerprints remain unchanged. Parse/Core/calendar/catalog checks and all
    thirteen seeds' package equivalence pass. Each new group joins the normal
    batch; no full corpus/native/GUI verification is claimed.
  - Core 0.309.0 passes nine focused checks, including old GROUND V2, the expanded
    branch matrix (1,317 assertions), H01/H02 V3 (327 assertions), calendar,
    catalog analysis and all thirteen seeds' package equivalence. Fourteen
    analysis-profile Python tests and 23 batch-runner tests pass. The two new
    original groups are registered in the normal batch. Full corpus/native/GUI
    validation is not claimed by these checks.
  - Core 0.308.0 passes 11 focused parse/Core/original checks, including GROUND
    V2, existing catalog analysis and all thirteen seeds' original/package
    equivalence. V1's 155-assertion runtime report reproduces its original hash.
    Full catalog coverage and the full native batch are not claimed.
  - Core 0.305.0 adds the declarative analysis-route validator: source-bound Python
    handoffs, caller/preset equivalence, four J04 branches, guard negatives,
    completed reentry, request rejection and fixed logical coordinates at
    640x400/1080p/1440p. Existing package equivalence includes the thirteenth seed.
  - Exercise every supported route through its exact terminal or visible
    blocker; preserve analysis-only classifications.
  - Sole owner of this regression. `workspace_distribution.md` WD-18 depends on
    it rather than repeating it.
  - Its seed, `validate_event_player_catalog_playback.gd`, now drives the player
    through the evidence API that `code_health.md` TD-13 added, so widening it
    to the whole catalog adds typed calls rather than string ones.
  - Legacy: P9-06.
- [ ] **EP-06 — Finish user-facing Playback presentation.**
  - Verify complete event flow without debug UI covering the 640x400 frame and
    retain explicit labels for projected or omitted native effects.
  - 2026-09-20: under EP-10 the Playback view shows no omission labels; the
    omitted records stay in the Analysis trace. The frame check stays.
  - **2026-10-09, open owner question (deferred by the owner):** Playback shows
    no choice prompt; the result is picked before Play in the catalog window's
    result selector (`CatalogResultSelect`, measured options only; EP-10 unit 2),
    and the run follows that option's measured variant. The owner asked whether
    that is right, kept the current behaviour ("지금 방식 유지"), and will decide
    later whether Playback should present choices in-line (that would be a
    change to EP-10's target, and needs a rule for an unmeasured answer).
    Unverified: whether a choice's prompt or option text shows as a line in
    Playback; it depends on the row's records.

- [ ] **EP-10 — The minimal-presentation event player (the final deliverable target).**
  Ruled 2026-09-20 by the owner (option 1 of two, approved as stated after a
  restatement; `docs/spec/tech/event_player.md`, "Final deliverable target").
  Every catalog site plays from its start to its ending through the one
  shared call frame (`content_core/mes_route_probe.gd`, the executor the
  group validator already uses for all 213 routes), with no per-event code.
  What plays: text (the original lines and speakers, routine-40 menus),
  voice per line, BGM by selector kept across lines, still pictures
  (backgrounds, standing pictures, CGs; an oversized picture whole by
  enlarging or scaling the window), sound effects fire-and-forget; the
  ending in the game vocabulary (EP-09). Not played and not claimed: AX/AN
  animation, camera motion, fades, shakes, transitions, waits, timing or
  pixel equivalence; no maps, place menus, calendar, saves, titles or
  endings; no original-engine execution. Playback shows no omission labels
  (Analysis keeps them). EVENTB03's event-specific camera, AX and
  background code is deleted once the shared path plays B03 as stills.
  Units, in order:
  - [x] Promote the measured groups to `analysis_only` catalog rows generated
    from the v4 documents and the profiles (the 13 hand-authored sites stay),
    classification and package checks re-bound. Done 2026-09-20 (Core 0.352.0):
    `tools/promote_analysis_groups.py` regenerates the catalog from the 142
    v4 documents and their profiles - one row per site that has no
    hand-authored row, carrying the site's source, activation, presets,
    choices, terminals (the six v4 kinds mapped onto the catalog's) and an
    additive `analysis_group` block naming its definition and groups; the
    rows are list-only until unit 2 (Play stays disabled), the package
    export selects only the hand rows for a full build (the package's
    events, members, records and bytes are unchanged; its manifest hash
    moves with the Core version and catalog revision as it always did),
    and the classifier folds only the hand rows' dependencies into its index
    (the generated rows' members are profile members it already reads), so
    the 169 rows and the 11/37/1/120 class counts stay while `catalog_routes`
    now names every row. Three documents (`ryoko.town.30c.01.1/2/3`, EVENTG01
    with the G_TALK scripts' questions) carry no `choices` because two
    boundaries share an offset with different owners; their results stay
    reachable by route in unit 2. The events array is sorted by `event_id`
    (the validator requires it), so hand rows and generated rows interleave;
    by-name lookups (`find_callee_source` and its siblings) prefer a
    hand-authored row when a callee name is shared. Verified 2026-09-20: `tests/test_promote_analysis_groups.py` (6 tests: the byte-for-byte reproduction, the hand rows equal to HEAD's, the counts, the terminal mapping, `--check` both ways), `tests/test_event_catalog.tscn` (the new counts - 142 rows, 131 `analysis_only`, 129 generated - a generated row validates, a malformed `analysis_group` fails closed, the by-name precedence), `tests/test_playback_package.tscn` (a full build selects the 13 hand rows), the Event Player scene (1,289 checks, its catalog-shape loops over the hand rows), the Python suite (1,738 tests, with the outcome censuses over 142 and 13 rows and the names registry untouched because `tools/build_event_names.py` now counts hand rows only), the classification refresh (169 rows, 11/37/1/120, nothing newly bound or moved), and the original checks: Event Catalog source bindings, playback package export and playback (13 events from 228 member entries, unchanged), catalog bounded analysis routes, Event Player catalog ordinary playback and fragment catalogs.
  - [x] Widen the player's catalog analysis to every promoted row: 0x0F
    nested calls, choice contracts (an answer selects its result), several
    results and terminals, the resume policies (natural handoff, place menu,
    menu loop), executed as the group validator's unbroken caller path.
    Done 2026-09-20 (Core 0.353.0): a promoted row's request is a `group_route`
    (`build_play_request` with an option id; the first measured option by
    default - an option no route reaches, `terminal_ids` empty, is refused
    as "not measured" and shown disabled), `tools/content_suite/catalog_analysis_run.gd`
    resolves the group (by id and profile hash), route and variant from
    the preset (every generated preset's notes name all three - a row can
    reference several groups, an arrival group beside a continuation group
    or two versions of one group, and a route id can recur across them, so
    the preset is the primary key of a run; where a group is referenced in
    two versions only the newer schema contributes routes; the selected
    answer is checked against the named variant's selections; the variant
    supplies its selections, the seed is always the calendar plus the
    composed preset), runs `KakyuMesRouteProbe.run_route` from the
    route's origin (`guard.offset` for the pre-v4 profiles) with the
    variant's selections, the map-location queues, the root-handoff
    follow, loop detection and a dispatch stop for the routes that declare
    one, and matches the ending against the row's terminal contract,
    reported in the game vocabulary. The generator was corrected on the
    way (the rows regenerated): a row's required entries are the union of
    its definition's members and every referenced profile's source
    members, every v4 terminal is a row terminal, the presets come from the
    profiles (one per route and variant, empty-writes variants included
    since a variant may differ only by its answer, each composed from its
    route's baseline; the v4 document had projected the first route's
    variants only), and a choice
    option maps to the row terminals at the coordinates of the routes
    whose variants select that value (the callee's outcome and the
    caller's resume, which v4 folds into one terminal when routes share
    it). The Event Catalog window
    gained a Result selector for choice rows, "Analyze route" for every
    promoted row and a default preset that resolves; the profiles are loaded
    once through the new `content_core/event_analysis_profiles.gd`, indexed
    by group id and matched by `payload_sha256` (two files share the id
    `ground-h17-k09`). The new `original catalog group routes` check runs
    every promoted row's measured options through the player. The
    pre-commit review (owner rule of 2026-09-20) found ten items; nine were
    fixed before the commit (the result selector re-picks the preset, keeps
    the chosen option on a reopened row, malformed requests and a failed
    profile load are refused with their reason, dependency-stop blockers of
    generated rows no longer claim to block playback, the profile loader
    hands out read-only documents, the map-location queue builder and the
    preset lookup are shared, the generator resolves a row's groups once)
    and one is a follow-up: only the first choice boundary is exposed as a
    Result; on the ten rows with a second boundary the preset binds its
    answer. Verified 2026-09-20: `original catalog group routes` standalone - 197 runs over the 213 (row, option) pairs with 16 unmeasured options skipped, 1,468 checks, zero failures, outcomes map_return 150 / place_menu 26 / chain 12 / unresolved 9, 1,148 s in the batch (its registered timeout is 1,800 s pending TD-32) - `tests/test_event_catalog.tscn` (1,447 checks), `tests/test_event_analysis_profiles.tscn` (16), the Event Player scene (1,294), `tests/test_playback_package.tscn`, the Python suite (1,742 tests; `tests/test_promote_analysis_groups.py` grew to 10 with per-row id uniqueness), `original catalog bounded analysis routes`, `original Event Player EVENTB03 zero-state choice analysis` and `original Event Catalog source bindings`, all green; the catalog regenerated at revision 24 with 2,275 presets and 210 terminals over the 129 rows, 119 of 135 first-choice options measured. Eight correction rounds against measured data preceded the landing; the rules they settled are recorded above.
  - [x] The guard-derived starting-state form: the cells the guard reads,
    with their bounds, validated by the guard before a run; presets become
    saved inputs. Done 2026-09-20 (Core 0.354.0): `content_core/event_guard_form.gd`
    (`KakyuEventGuardForm`) turns a v4 definition's typed guard conjuncts
    into fields - one per cell the guard reads, named by the state-cell
    classifier (date, clock, weekday, a heroine's affection, a flag), with
    the bounds the conjuncts imply and the excluded values listed - and
    checks a candidate state by running the caller's guard record once, the
    check the group validator makes; the Event Catalog window shows the
    form under the Result selector (a promoted row names its definition, a
    hand-authored row is found by its site), a "Use this state" toggle
    makes the Analyze request carry the state as a `tool_seeded_analysis`
    preset over the selected preset's writes, and `run_group_route` seeds
    it while resolving the route from the preset the form started from.
    A tool-seeded run is labelled as such; the guard must pass before the
    toggle enables, and `readiness_group` runs the same guard check on a
    tool-seeded request itself, so a headless caller cannot bypass it. The
    unit also repaired two scenes units 1 and 2 had left red outside their
    targeted checks: the outcome-vocabulary scene's per-row table now
    covers the 142 rows (regenerated by the Python CLI) and the bounded
    analysis-route scene skips generated rows. The pre-commit review found
    ten items, all fixed before the commit: tool-seeded writes are
    range-checked like catalog presets, the UI and the service seed the
    candidate state through one helper (calendar context included), the
    toggle exists only on promoted rows, the tool-seeded path is keyed on
    the request's base preset rather than a preset kind, the parsed caller
    is cached and handed from readiness to the run, the accepted tool
    preset is normalised, the write-key helpers are shared, the default
    option comes from the request builder alone, and the vocabulary CLI's
    GDScript table flag reuses the catalog path. Verified 2026-09-20: `tests/test_event_guard_form.tscn` (18 checks), the Event Player scene (1,301), `tests/test_event_catalog.tscn` (1,447), `original catalog group routes` (1,519 checks: 197 runs, 16 unmeasured options skipped, 3 guard-form in-bounds runs reaching their preset's terminal, 3 out-of-bounds refusals both through the UI and directly against the service), `original Event Catalog source bindings`, the Python suite and the whole local batch (134 of 134 in 257 s). The local batch also exposed what the targeted checks of units 1 and 2 had missed: `tests/test_event_catalog_caller_route.tscn` had been timing out on full-catalog re-validations while two of its checks failed and sixteen first-row assumptions mutated the wrong row; it now builds its synthetic documents from the hand rows and passes 766 checks in 2-3 s alone or under load.
  - [x] The shared presentation adapter for Playback: text, voice, BGM, stills,
    sound effects, mapped from the runner's record classes through the
    shared resolver; unknown classes skipped. Done 2026-09-20 (Core 0.355.0):
    a promoted row's Play is a replay of its finished `run_group_route`
    result. `content_core/event_presentation_timeline.gd`
    (`KakyuEventPresentationTimeline`) joins the run's trace to its messages
    and yields one step per line carrying the voice marker, the BGM
    requests, the pictures (a background, or a foreground when a `_PIC`
    script emitted it), the animation markers (recorded, not played), the
    sound-effect requests and the omitted native records since the previous
    line, plus a closing step; the Event Player's Playback view steps
    through it with its existing controls, applying each step's stills,
    BGM, voice and sound effects through the shared resolver (the BGM and
    voice paths factored out of the trace scanners behaviour-neutrally, a
    dedicated effect audio player added), showing no omission label, and
    ending on the game-vocabulary terminal. Play and Analyze are two public
    entry points; the catalog button chooses by the view mode. The
    pre-commit review found ten items, all fixed before the commit: the
    closing step is applied, a group-route play completes at its matched
    terminal whatever the outcome and never re-fires a step, the picture
    state is cumulative per step (so stepping back shows what the line
    showed and a foreground is not wiped by a later background in the same
    line), the effect channel is the existing one under the audio identity
    contract and is silenced on reset, the view-mode switch refreshes only
    the button, the validator reads the played result instead of running
    each route twice, and the Play/Analyze prologue is shared. Verified 2026-09-20: `tests/test_event_presentation_timeline.tscn` (35 checks over a synthetic run covering every step field, the cumulative picture state, the closing step and an unknown effect), the Event Player scene (1,308), `original catalog group routes` (12,052 checks: the Analysis pass as before plus 129 Playback runs whose timelines matched their message counts and whose pictures 626/626, voices 1,539/1,539 and BGM 495/495 all resolved in the content set, no unknown effect; no default route traced a sound-effect request, so that path is exercised by the scene test only), `original Event Player EVENTB01 integration` and `original Event Player EVENTB03 captured and numeric choice presets` with PASS lines identical to before (the factored BGM and voice paths are behaviour-neutral), the Python suite, and the whole local batch (135 of 135).
  - [ ] Retire the event-specific code. **Ruled 2026-09-21 by the owner (option
    1 of two): every hand-authored row moves to the shared path, not B03
    alone, and the playback vocabulary becomes `minimal_playback` (the row
    plays through the presentation timeline to a real ending) and
    `analysis_only` (its run ends at a measurement boundary).** Three
    sub-units:
    - [x] 5a - measure the ten hand-authored sites that have no analysis
      group (B01, B02 from 13C; D01, D02, D03, D08, D14 from 12C; B15 from
      11M; B03, J04 from 01M) with the route toolchain, each registered
      with its `original event analysis` check; B14, D05 and D06 already
      have groups. Done 2026-09-21: the 12C and 13C caller inventories built
      the way 01M's was, ten specs drafted, measured, audited, validated,
      mutation-tested and registered by the toolchain (the nested calls of
      13C, 12C and 11M as v5 caller continuations, B03 and J04 as v6 root
      replacements), replays and witnesses recorded, the names registry
      regenerated with ten new group aliases (ids unchanged; the pair
      premise moved from 120 to 130), the 142 v4 documents re-projected -
      the ten sites now carry analysis-group evidence - against a fresh
      package, and the classification refreshed (168 bound entries, the
      ten newly bound, class counts unchanged). Every registry site now has
      a group, so nothing in the catalog rests on hand-authored measurement
      alone. Verified 2026-09-21: the ten new `original event analysis` checks (13C B01/B02, 12C D01/D02/D03/D08/D14, 11M B15, 01M B03/J04), `original event corpus literal dispatch inventory`, `original dispatch naming beyond the strict decode`, `original Event Catalog source bindings` and `original catalog group routes`, all green; every profile audited, validated and mutation-tested by the toolchain; the v4 batch `projected=142 valid=142`; the Python suite (the outcome censuses re-pinned: v4 results map_return 177 / unresolved 3, profile routes map_return 182) and the whole local batch (135 of 135). The package the documents bind is a fresh export (`analysis/playback_package_ep10u5a`: 13 events from 230 member entries, 213 bound by 149 groups) because the previous one predated the 12C and 13C groups. Caller documentation: `docs/spec/mes/12c_caller_group.md`, `13c_caller_group.md`, and new sections of `01m_caller_group.md` and `11m_caller_group.md`.
    - [x] 5b - regenerate: the v4 documents of those sites from their
      groups, the catalog with no hand-authored rows (142 generated rows,
      the new vocabulary, the classifier following it - a row that plays
      is a playable event), the names registry and the classification.
      Done 2026-09-21 (Core 0.356.0, with 5c): `tools/promote_analysis_groups.py`
      generates every row (catalog revision 25, 142 rows: 139
      `minimal_playback` / `playable_event`, 3 `analysis_only` /
      `unresolved_route` - the rows whose default option ends in a
      dependency stop or an undeclared continuation); `PLAYBACK_STATUSES`
      is `minimal_playback` / `analysis_only` / `blocked` / `not_applicable`
      and the `caller_route` / `analysis_route` shapes and their validators
      are gone from `content_core/event_catalog.gd`; the classifier reads a
      `minimal_playback` row as a playable event (129 playable events / 34 shared system scripts / 1 unreachable stored route / 3 unresolved routes over 167 rows, confidence
      164 `qualified_catalog_scope` / 1 `analysis_group_qualified_route` / 1 `analysis_group_measured_participant` / 1 `analysis_group_member_unmeasured`, 166 bound); the names registry names every row
      (`EXPECTED_CATALOG_COUNT` 142, fingerprint `4a04c35a...`); a full
      package build selects all 142 rows (`analysis/playback_package_ep10u5bc`);
      the 142 v4 documents re-bound to it.
    - [x] 5c - delete the per-event modules, the player's event-specific
      functions, the per-event validators and checks and their tests;
      rewrite the manual run sheet's B03 items to the minimal spec and close
      the B03 animation and camera items as superseded; golden-frame
      acceptance for what the owner has seen once. Done 2026-09-21 except the
      golden-frame acceptance, which waits on the owner's first look (WD-19
      run sheet items 4-6, rewritten to the minimal spec; MV-04/09/11
      closed as superseded): the eleven `event_player_event*.gd` modules,
      the twelve `validate_event_player_event*.gd` validators,
      `validate_event_player_catalog_playback.gd`,
      `validate_catalog_analysis_routes.gd` and
      `tools/audit_catalog_analysis_routes.py` deleted with their
      registered checks (one more, `validators/audit_eventb03_preset_reduction.gd`
      and its `original EVENTB03 preset reduction matrix` check, was missed
      by the named-check runs and retired on 2026-09-21 when TD-32's
      `archive_quick` tier ran every archive check); the player's hand-row paths (root replacement,
      nested call, confirmed-caller continuations, the EVENTB03 camera /
      large-CG / effect-cue / station code, the EVENTB14 AX / world-map /
      outcome-preview code) removed (16,054 -> 7,654 lines); every row
      plays through `group_route` Play and the presentation timeline.
      Verified 2026-09-21: the Python suite; the whole local batch (134 of 134 - the two per-event scene tests deleted, `tests/test_catalog_analysis_run.tscn` added with 21 checks of the group-route descriptor); with the archive: `original Event Catalog source bindings`, `original playback package export` (`142 events from 230 member entries (125 catalog-verified, 105 bound by 149 analysis groups)`), `original playback package playback` (976 checks over 142 rows, each driven through its measured route on both the bytecode and the packaged records: 119 reach a catalog-declared terminal, 23 stop at a dependency or def-selection boundary), `original catalog group routes` (all 142 rows, 1,502 s), `original Event Player fragment catalogs`, `original selection handoff original integration`, `original MES Editor original integration` (the editor's contextual Run binds an edited EVENTB03 to its generated row, whose 17 presets it lists), the four `contextual authoring` checks (the workspace export of the edited EVENTB03 needed the selected rows' own group members merged - a generated row's caller entry is listed only by its group - and the serializer's failure is now reported instead of a generic sentence), `original event corpus literal dispatch inventory` and `original dispatch naming beyond the strict decode`; the pre-commit code review's findings fixed.

- [x] **EP-08 — Enforce original-only Event Player inputs and UI.**
  Done 2026-09-15 (Core 0.321.0). The run-request contract accepts only
  `original_arc` + `exact_original` with identical hashes; the Event Player
  rejects other requests before mutation, activates no overlay or derived
  layer at startup, refuses a positional overlay root, applies no overlay
  text projection in `_load_entry`, and refuses to play or analyse a
  non-original document at the four execution choke points; the Overlay /
  Hot Reload / Clear Overlay / Derived affordances and the Derived ARC Layers
  window are removed (`_configure_overlay`, `_prepare_overlay_candidate`, `_on_hot_reload_pressed`, `_on_clear_overlay_pressed`, `_configure_materialized_archives`, the ten Derived-window handlers, `_consume_contextual_run` and `_run_authored_text`; 511 lines removed, 54 added); the MES Editor's
  contextual Run route and semantic-proof dialog are removed and its Run
  action opens original entries only. Shared helpers (contextual run engine,
  authoring binding, overlay package, provenance, resolver, launch context)
  are untouched. Scene checks: `test_event_player.gd`
  516 static checks -> 478 (1,279 runtime passes),
  `test_mes_editor.gd` 154 -> 154 (153 runtime passes);
  the 17 original Event Player validators, the two contextual-authoring probes, seven local scene checks and the Python regression (1,421 tests) green.
  - Audit public startup, editor Run, source selection/reload and both execution
    views; reject authored MES, text/media overlays and changed materialized
    inputs before session mutation. Preserve byte-identical original identity.
  - Remove or redirect the app's edited-Run/Derived/overlay affordances and
    editor launch routes that imply modified-content playback. Editor previews,
    compiler/semantic checks and shared headless package probes stay with their
    owning tools; do not create a second mod player or remove shared helpers.
  - Verify rejection paths preserve the active original session and original
    catalog/choice/terminal regressions still pass. This is bounded input/UI
    cleanup, not TD-11's deferred full decomposition.

- [x] **EP-09 — Report endings in the game's vocabulary.** Ruled and done
  2026-09-20 (Core 0.351.0). The owner asked for the endings of an event to be
  named as the player experiences them, changing only the vocabulary: no
  re-measurement, no contract, catalog row, v4 document or validator change.
  The five outcomes and their derivation from the code-level markers are in
  `docs/spec/data/event_outcome_vocabulary.md`: `map_return` (a world map;
  `postlude` says whether the event script handed the root itself or the
  place script continued with its own lines first), `place_menu` (the place
  script's registered-definition menu), `chain` (straight into another place
  or date script), `not_triggered` (the done gate, a false guard, a
  rejection), `unresolved` (a dependency stop or an undeclared
  continuation). Census over the tracked data: over the 142 v4 documents' 230 results - map_return 162, place_menu 39, chain 12, unresolved 17 (14 callee returns with no declared continuation, 3 dependency stops); their 230 reentries - not_triggered 154, map_return 48, place_menu 9, chain 4, unresolved 15; the 213 profile routes - map_return 164, place_menu 34, chain 10, unresolved 5; the 13 catalog rows - map_return 11, place_menu 1, unresolved 1. Implemented as
  `tools/event_outcome_vocabulary.py` (rules, CLI census) and its port
  `content_core/event_outcome_vocabulary.gd`; the Event Player's catalog
  terminal message, footer and status now lead with the phrase and keep the
  terminal's kind, owner, offset and target beside it. Verified 2026-09-20: `tests/test_event_outcome_vocabulary.py` (68 tests: every rule row both ways with its reason string, the phrases, the pinned census), `tests/test_event_outcome_vocabulary.tscn` (64 checks: the port mirrored and one check per catalog row against the Python result over the live catalog), the Event Player scene (1,288 checks, unchanged), the rules scene (68), the Python regression suite; all green.
  - **Ruling of the same day, the nonzero start coordinate:** the D05
    catalog row's `start_coordinate` 1008 (`0x03F0`) and its
    `host-selected-coordinate` blocker date from the pre-group analysis that
    could confirm the route only from the BGM selector onward; the 01M group
    (2026-09-10) enters `EVENTD05.MES` at 0 from the station script's guard
    and reproduces the whole body. The owner ruled the notion unnecessary:
    the row keeps its old values until it is regenerated from the group
    (catalog promotion), and no new work is scheduled for it.

- [ ] **EP-11 — Events that change over several visits (visit ladders).**
  Ruled 2026-09-23 by the owner (option 1 of three, both units), after the
  census under EP-03: 9 entries carry visit-counter ladders, 84 rungs, 74 of
  them declared by no profile; the multi-rung ones are EVENTM10
  `global_u8[2456]` (4 rungs, rungs 3-4 calling EVENTM11), EVENTM03
  `global_u8[2421]` (15 rungs, none reached by a declared route) and
  EVENTA20 `global_u8[1131]` (3, unconfirmed). Unit 1 (this item): a
  `visits` list on a route - each visit names the pass it follows, the cells
  it seeds (labelled tool-seeded where the natural arrival is not
  established), its exact outcome, message count, expected state and any
  nested dispatch - bound by the Python audit, replayed by the validator,
  offered as starting options on the catalog row so the Event Player plays
  them, and read by the classifier (an EVENT entry a playable row's visit
  plays is a playable event). EVENTM10 and EVENTM03 first; EVENTG01,
  EVENTG02 and EVENTA20 after their arrival is measured. Unit 2 is WD-23.
  - **Part 1a landed 2026-09-23** (`529f842`, Core 0.361.0): profile shape
    `kakyu_event_analysis_group/v13` = v8 plus a route's `visits`
    (`docs/spec/tech/content_tools.md`), bound by the audit and replayed by
    the validator; `44c_m10a_v13.json` / `44c_m10b_v13.json` replace the v8
    files with five visits each - `visit2-gate` (after the route, seed
    `[287] = 1`, EVENTM11 at `9545`), `visit3` (after the reentry, 22
    messages), `visit3-gate` (EVENTM11 at `13274`, 35 with the nested 6),
    `visit4-gate` (EVENTM11 at `16586`, 31) and `visit5-gate` (the fixed
    point, identical to visit 4). Verified: the Python suite (1,884), the
    audit tests (72), both M10 group checks (241 and 243 checks), the local
    tier 134/134, source bindings, package export and playback, the
    dispatch inventory, and the four group-route shards. EVENTM03's ladder
    at `14092` is forward-reachable from `0` through M03's own flags
    (`[2420] = 1 and [2417] = 0` at `13328`, then five rejections) and the
    44C guard reads none of them; declaring M03's visits waits for part 1b.
    Limitation: a visit's nested message count is compared per dispatched
    entry, so two calls of one entry in one visit need per-call counting.
  - **Part 1b landed 2026-09-23** (`693dbc5`, no Core change; catalog
    revision 27): each visit gains a measured `entry_state`; site B's five
    visits are starting options on its row (writes = the default preset,
    then `entry_state` minus the cells the route's guard reads - the day
    change clears those between visits - then the seeds), played through
    the caller path to the dormitory's selection `45952`: visit2-gate 60
    messages with EVENTM11 at `9545`, visit3 22, visit3-gate 35 (`13274`),
    visit4-gate and visit5-gate 31 (`16586`). Site A is single-entry by its
    own prefix (`[2455]` at `52898`) and has no visits. EVENTM11 is a
    playable event: classification 131 / 35 / 1 / 0. Verified: local tier
    134/134, the M10A/M10B group checks (141, 473), source bindings,
    package export and playback, dispatch inventory and naming, fragment
    catalogs and the four group-route shards (each visit preset in both
    passes).
  - **Part 1c landed 2026-09-23** (`bdd48e9`, no Core change; catalog
    revision 28): EVENTM03's ladder on `global_u8[2421]` is reached naturally
    one day after the route's first pass - the pass leaves `[2420] = 1`, a
    day change (definition 11 with a full day) clears `[2417]`, and nothing
    else is needed (a minimal-seed replay confirmed it); fifteen day changes
    walk rungs 0..14 and a sixteenth repeats the fixed point.
    `44c_m03_v13.json` declares `ladder-00`..`ladder-15` (14, 18, 23, 31, 23,
    29, 18, 32, 20, 22, 17, 18, 18, 17, 20 and 26 messages, all returning at
    `38838..38839`, no dispatch; each seeds only `[2417] = 0`, labelled
    tool-seeded because the day change runs in another script), and M03's
    row has the sixteen visit presets. Verified: the M03 group check (4,220
    checks), local 134/134, and with the archive source bindings, dispatch
    inventory, package export and playback, fragment catalogs and the four
    group-route shards (16 visit runs in both passes).
  - **EVENTG01, EVENTG02, EVENTA20 measured 2026-09-23:** G01's two passes
    are an if/else-if on the entering value and both are already covered by
    `30c-g01a` (`[1462] = 0`) and `30c-g01b`/`-c` (`= 1`) - the census had
    counted them undeclared by outcome, not by baseline; G02's second pass
    (`[1391] = 1` on entry, 5 messages) is declared by no route, and whether
    `35M.MES` dispatches G02 again naturally is not established; A20's
    `[1131]` chain is reachable only through its address-table entry
    `14364`, the family closed without exposure (2026-09-17), so it is
    recorded, not declared. Open under this item: G02's revisit, once the
    caller's second dispatch is measured.

- [x] **EP-12 — Bring every content script into the catalog, not only EVENT scripts.**
  **Closed 2026-10-05 by the owner** (the closing bullet at the end of this
  item lists what stays deferred).
  Raised 2026-09-24 by the owner ("the hotel and the choices after a date do
  not show") and ruled the same day (option 3 of three: everything, H, CG
  and SCENE included). Measured first: the catalog's 142 rows are exactly
  the sites where a place or map dispatches an `EVENT*.MES` script (129 of
  the 131 EVENT scripts); of the archive's 1,016 entries no `*_DATE*` (73
  scripts, 596 dispatch sites, 540 from places), `*HOTEL*` (36; 48 sites,
  date part 3 -> `HOTEL` -> `HOTEL1` -> `HOTEL2`), `*PROMIS*` (12; 500 sites),
  `*_TALK*` (142; 4,905 sites), `*_H` (13; 26 sites, `43C.MES` among the
  callers), `*_CG` (13), `*_TIME*` (13) or `SCENE_*` (365) script is a
  catalog row. The "every catalog row plays" results of EP-10/EP-11 hold for
  that EVENT scope only. Order: a census first (per family: distinct
  caller -> target routes, guards and scheduling cells, whether `SCENE_*`
  duplicates scenes found elsewhere), then the families in the order the
  census recommends, each the way the EVENT sites went (route toolchain ->
  analysis groups -> catalog rows -> v5 documents). Census spec:
  `analysis/_docs/ep12_content_census_spec.md`.
  - **Census done 2026-09-24** (`analysis/_undoc/ep12_content_census*`,
    untracked; all 1,016 entries partition by name): HOTEL 36 scripts / 48
    sites, a fixed root-handoff chain per heroine (`?_DATE3 -> ?_HOTEL ->
    ?_HOTEL1 -> ?_HOTEL2`, selectors `state_u16[21] == 3` / `== 5` / none);
    DATE 73 / 596 sites (540 nested, 56 handoffs; weekday, clock and
    schedule-cell guards of one shape; chains DATE3 -> DATE5 and DATE5/HOTEL
    -> TALK, 241 chain pairs; 108 choices in 38 scripts); PROMIS 12 / 500
    (one flag per heroine); TIME 13 / 132 (DATE-shaped; `M_TIME.MES` never
    dispatched); CG 13 / 13 (`state_u16[18] == 18`); H 13 / 26 (a
    `state_u16[13]` selector, callers `43C.MES` and `OMAKE.MES`); SCENE 365
    / 365 (one unlock flag each, from the 13 `?_M.MES` menus; 44 twin groups
    - 27 byte-identical to an EVENT, 13 to a `?_END`, 4 internal - so 50 of
    365 are gallery copies); TALK 142 / 4,905 (no shared guard shape in the
    sample; 488 choices). Never dispatched: `DATETIME.MES`, `M_TIME.MES`,
    `OMAKE.MES`. The census's own suggested order: HOTEL, CG, PROMIS, TIME,
    DATE, H, SCENE, TALK. **Order ruled 2026-09-24 (owner, option 1 of
    three): the date flow first** - 1 HOTEL (the fixed chain, ~12 groups),
    2 DATE (596 sites, 108 choices, chains into HOTEL and TALK), 3 PROMIS,
    4 TIME, 5 CG and H, 6 SCENE (one shared gallery shape), 7 TALK. EP-13
    (stills, line steps) finishes before HOTEL starts.
  - **HOTEL measured 2026-09-24** (`analysis/_undoc/ep12_hotel*`, untracked;
    heroine A's DATE3 -> HOTEL hop and all twelve HOTEL1 -> HOTEL2 hops by
    execution, the rest statically): the hotel is the tail of the date, not
    an event of its own - `?_DATE3.MES`'s own second routine-40 question
    selects `?_HOTEL.MES` (the accepting `state_u16[21]` is 3 for A/B/C/D/F/
    H/K, 2 for E/I, 1 for G/J/L, each behind a per-heroine flag),
    `?_HOTEL.MES`'s question selects `?_HOTEL1.MES` (`== 5` for all twelve),
    and `?_HOTEL1.MES` hands to `?_HOTEL2.MES` unconditionally after adding
    2 or 3 to the heroine's affection word (`banked_u16[200..212]`, one per
    heroine); `?_HOTEL2.MES` ends on the town map for nine heroines, on a
    dormitory-or-town choice for E and I, and in a wider switch for L
    (PROMIS and the EVENTM03/M10/M17 sites the 44C doc records). Each
    HOTEL2 loads one `?an.mmo` into surface 8. Not established: how a date
    reaches its hotel question from its start (a plain run of `A_DATE3.MES`
    reaches another scene; a gate `state_u16[12] < 150` then
    `global_u8[11] == 1 and [12] == 1` stands before it), what selects
    `?_HOTEL1.MES`'s 300-600 message records (the baseline run shows none),
    and E/I/L's further branches. **Two tool gaps:** the route toolchain
    declares one caller -> one callee across one handoff, not a chain of
    hops with questions inside; and `?_HOTEL.MES`'s menu is a routine-40
    shape `mes_routine40_choice_contract.gd` rejects ("neither an exact
    one-based chain nor a complete gated matrix"). So HOTEL cannot be
    declared on its own with today's shapes: the date flow needs a chained
    route shape (hops with per-hop answers) and a wider choice contract,
    and the date's own start must be measured first - a design for the
    owner once EP-13 lands.
  - **A date measured end to end 2026-09-24 (heroine A;
    `analysis/_undoc/ep12_date_entry*`, untracked):** the promise
    (`A_PROMIS.MES` from its label `0x2036`, the coordinate the promise-dates
    validator already records for all twelve) writes the promised day
    (`banked_u16[215]` = tomorrow, +1 by the audited rollover), the time
    from a ten-option question (`[216]`, e.g. 900) and a flag
    (`global_u8[610]`); the meeting place `global_u8[119]` is set outside it.
    Eleven place scripts (`01M, 02M, 04M, 06M, 09M, 10M, 17M, 18M, 19M,
    20M, 21M`) carry the same date guard: today `== [215]`, clock `>= [216]`,
    `global_u8[110] == 1`, `[117] == 2`, place `[119]` in 9..13 (per-heroine
    cells slide by the validator's field table; confirmed for A, B, L). Once
    it accepts, one pass runs `A_PIC -> A_DATE1 -> DENSHA -> A_TIME ->
    A_DATE2 -> (A_DATE7 at places 9-13) -> A_DATE3 -> A_DATE4 -> MACHI`
    unconditionally - `A_DATE1..7` are parts of one date, not separate
    dates (`A_DATE6.MES` is never dispatched, `A_DATE5.MES` only from
    `A_DATE3`); `A_DATE3.MES`'s two questions pre-empt the tail: case 2 with
    affection `banked_u16[201] >= 61` hands to `A_DATE5.MES` (11 messages,
    then MACHI; its own TALK dispatch sits behind a date gate), case 3 to
    `A_HOTEL.MES` (the hotel chain). Not established: who sets
    `global_u8[110]`/`[117]`, the `DENSHA -> TRAIN` leg (needs the v11/v12
    map-location poll), `A_HOTEL.MES`'s menu (choice contract rejects it),
    B..L beyond the guard cells. **Design for the owner:** a "flow" route
    shape - one chain declared from the place's date guard through every
    nested call and root handoff to the flow's end, with per-hop answers
    and plain-state gates - plus the choice-contract extension for the
    hotel menu and the map poll for the train leg; catalog rows per place
    and heroine date site with the branches as presets; the definitions
    extended for the remake afterwards.
  - **Ruled 2026-09-24 (owner, option 1 of three): the flow shape.** A
    profile route of kind flow declares one chain from the place's date
    guard through every nested call and root handoff to the flow's end,
    each hop with its dispatch record, its answers, its plain-state gates
    and its expected outcome; branches (DATE5, the hotel) are sibling routes
    of the group with their own answers; the audit binds every hop record,
    the validator replays the chain, the catalog row per place-and-heroine
    site offers the branches as presets. Prerequisites in flight: the
    choice-contract extension for the hotel menu's routine-40 shape, the
    map-location poll for the train leg, and the origin of the two date
    flags. Heroine A first, then B..L by the same template. Specs:
    `analysis/_docs/ep12_flow_shape_spec.md`,
    `ep12_hotel_menu_contract_spec.md`, `ep12_date_prereq_measure_spec.md`.
  - **Prerequisites measured 2026-09-24** (`analysis/_undoc/ep12_date_prereq*`,
    untracked): the train leg is `DENSHA.MES` handing to `TRAIN.MES`, whose
    own poll is the station rides' contract, `{"entry": "TRAIN.MES",
    "poll_offset": 886, "result_storage": "state_u16", "result_index": 18,
    "values": [0, 1]}` - supplied, the pass continues and DENSHA plays 16
    lines with `t.mmo`/`tan.mmo`, then stops at its own native routine-40
    at `2652`, the hotel menu's class of gap (folded into that unit). The
    two date-guard flags: flag 1 (`global_u8[110]` for A) is "the promised
    day and time have come", set by a `LIBLARY.LIB` cascade over the twelve
    heroines (A's at `8863..8949`) once the calendar reaches the promise's
    cells, with a stood-up penalty when it has passed; flag 2 (`[117]`) is a
    three-stage cell - 1 with flag 1, raised to 2 by the heroine's reminder
    conversations (`?_TALK30..90`), consumed back to 0 by the place the
    moment the date starts (replayed live). Neither is written by the
    promise script. Not established: what invokes the library cascade, and
    DENSHA past its first question.
  - **Landed 2026-09-24:** the redirect choice-consumer shape (Core
    0.363.0): all twelve `?_HOTEL.MES` menus consume their routine-40 result
    after one unconditional jump, now a third accepted form of
    `mes_routine40_choice_contract.gd` (schema v4), pinned by `original HOTEL
    menu routine-40 redirect contract` with every answer executed; DENSHA's
    five questions already build under the existing shapes (the earlier
    "unanswerable" reading was a probe started past the definitions).
    The v14 flow shape (Core 0.364.0): contract, audit (`_audit_flow_route`),
    builder (`tools/build_event_flow_profile.py`), a flow validator
    (`event_analysis_group_flow_validation.gd`, not yet wired into the
    batch), 15 audit tests and a synthetic five-script scene; no real
    profile yet. Next part: heroine A's date declared as `01m-a-date` with
    routes town / DATE5 / hotel, the validator wired into the batch, and
    the flow documented (`analysis/_docs/ep12_a_date_flow_declare_spec.md`).
  - **Heroine A's date measured as flow hops, 2026-09-24
    (`docs/spec/mes/a_date_flow.md`; no group declared):** the shared
    prefix is 19 hops from `01M.MES`'s date guard (`A_PIC`, `A_DATE1`,
    `DENSHA` with the TRAIN poll and its own first answer, `A_TIME`,
    `YABAI`, `A_DATE2`, `A_PIC`, `A_DATE7`, `A_PIC`, each with its resume) to
    the `A_DATE3` dispatch; the **town** route is complete (first question
    case 1, 7 lines, `A_DATE4`, town map). Two blockers, reported rather
    than seeded around: the **DATE5** route stops inside `A_DATE5.MES` at
    `definition 17 stopped at definition_step_limit` (a cross-file
    `script_transfer` selector, argument 170, the ROUTINE27/25/21 family -
    the same family sits at `01M.MES`'s location-9 branch and was avoided by
    running the date at location 15, a tool decision); the **hotel** route's
    second question in `A_DATE3` is not reached from a normal entry with the
    seeds tried (earlier probes reached it only by starting at its interior
    branch `29066`). **Diagnosed the same day:** the DATE5 stop is
    `DEF_MAIN.MES` definition 17, a host-wait loop on `state_u16[18]` (the
    map poll's cell) invoked at `A_DATE5.MES:488` - a supplied poll result,
    as the station rides supply `Util(6,13)`, is the treatment; the
    location-9 worry was a misattribution (every location converges on the
    same tail). The **hotel** reading had to be corrected twice: the
    "unreachable second question" was a misread of the place menu's option
    catalog (options present while `global_u8[11]`/`[12]`/`[15]` are `0`)
    plus replays that never tried affection 111. Established by replay
    from `A_DATE3` offset 0 (`analysis/ep12c_hotel_natural_probe.gd`):
    first question option 3, affection `banked_u16[201] >= 111` (every
    lower band ends the date), money `state_u16[12] >= 150`, clock at or
    below `2130` (`1830` on 12/24), first visit -> place menu -> option 3
    -> definitions 17/11 -> `A_HOTEL` at `31465` (68 messages); a return
    visit (`[992] == 1`, written only by `A_HOTEL.MES:6616`) skips the menu
    to the handoff at `32352`. `docs/spec/mes/a_date_flow.md` corrected
    both times. **Poll supply landed 2026-09-24 (`1d84536`, merged
    `0088482`, Core 0.365.0):** a v14 hop field `poll_supplies` writes a
    supplied value into a registered definition's poll cell right before
    that branch evaluates (audit binds the exact `branch_if_not_true`
    record and the definition's registration; 5 mutations rejected, 6
    runtime checks); with it `A_DATE5.MES` runs 11 messages and hands to
    `MACHI.MES` at `3949`. Both batch validators dispatch a v14 profile to
    the flow validation module; the builder merges several `--spec` files
    into one multi-route profile; DENSHA is one hop with TRAIN's
    `map_locations`. The unit's own declaration attempt stopped in
    DENSHA's definition-12 branch because the v14 validator loaded only
    `baseline` and never applied the calendar projection (bank 25) that v8
    routes get through `state_context.kind == "original_calendar"` - a
    validator gap, not a data blocker. Next (in progress,
    `analysis/_docs/ep12_a_date_declare3_spec.md`): v14 routes carry
    `state_context`, the flow validator applies it, and `01m_a_date_v14.json`
    is declared with the three routes (town; DATE5; hotel with affection
    111 and money 150 as `tool_seeded` gates, through the hotel chain) and
    registered as `original event analysis 01M A date`. **Landed
    2026-09-24 (`2a8a5ed`, merged `98482f6`):** `01m_a_date_v14.json`,
    `state_context` on v14 routes (optional; applied before the baseline;
    `--tier local` caught the GDScript fixture when it was mandatory),
    three routes measured through the real 19-hop prefix - town 23 hops
    (A_DATE3 7 lines, A_DATE4 6, MACHI at 12633), DATE5 21 hops (affection
    65 seeded, A_DATE5 11 lines, MACHI at 3949), hotel 23 hops (A_DATE3 45
    lines -> A_HOTEL 37 -> A_HOTEL1 94 -> A_HOTEL2 26 -> MACHI at 11625, the
    chain's own end); 185 runtime checks; 7 mutations rejected (the `fresh`
    context fails first in DENSHA's definition-12 branch, as predicted);
    150 groups green; the Python audit now accepts v4 routine-40 contracts
    (it had accepted only the v3 literal). The return-visit hotel variant
    (`[992] == 1`, handoff at 32352) needs a different outcome at the same
    hop, which v14 variants cannot express - reported, not built. Some of
    the flow page's earlier partial-context message counts (A_DATE7, the
    hotel case-3 total) did not reproduce; the declared numbers stand.
    Two tool decisions taken on merge so the Python suite stays green
    (1,917 OK): the outcome vocabulary classifies a flow by its terminal
    (`docs/spec/data/event_outcome_vocabulary.md`) and the event name
    registry skips v14 profiles unchanged (README revision). The tracked
    route classification was stale after the declaration (A_PIC.MES and
    TRAIN.MES gain `01m-a-date` membership) - refreshed `4873dc7`, counts
    unchanged. **Owner ruling 2026-09-24: one catalog row per flow route**
    (`a-date-town`, `a-date-date5`, `a-date-hotel`; choices shown during
    playback stay a possible later Event Player item). In progress
    (`analysis/_docs/ep12_flow_catalog_spec.md`, survey
    `analysis/_undoc/ep12_flow_catalog_survey.md`): the hop-chain runner
    extracted from the flow validator and used by the catalog run; registry
    rows keyed by the flow's first dispatch plus route (`miko.town.station.
    date-town.1` ...); the promoter emits flow rows directly from the v14
    profile (no v4 document; event ids `original/<route>/01m-00002af7`,
    presets = baseline + seeded gates, choices = the hop answers, terminal =
    the MACHI handoff); catalog revision 29 / 145 rows. **Landed
    2026-09-24 (`cf32f95` / `0cf38bd` / `ecc4dad`, merged):**
    `tools/content_suite/event_flow_runner.gd` (`KakyuEventFlowRunner`:
    `seed_flow_state`, `run_route` -> combined trace/messages/state and the
    last hop's terminal) used by the flow validator (185 checks unchanged),
    `catalog_analysis_run.gd` (`_run_group_flow_route`) and the playback-
    package check; registry rows `miko.town.station.date-{town,date5,
    hotel}.1` (fingerprint `149ccc39...`, carried into the v4/v5 documents
    as on 2026-09-21); catalog rows `original/a-date-{town,date5,hotel}/
    01m-00002af7` (presets = baseline + seeded gates, choices = the hop
    answers: DENSHA 2652, A_TIME 1497, A_DATE3 13402, plus 28100 and
    A_HOTEL 7131 for the hotel; terminals the MACHI handoffs); the rows
    play at 83 / 92 / 272 lines; package playback 145 rows, 122 reach a
    terminal (+3), 20 / 3 / 0 unchanged; local tier 135/135; Python 1,917
    OK; classification unmoved. **Owner ruling 2026-09-25: flow rows get
    a new `kakyu_event_definition/v6` shape carrying the hops** (a new
    fingerprinted directory beside v5; the remake reads it from here).
    Unit 1 landed 2026-09-25 (`1af2883`, merged `f7b58d7`):
    `docs/spec/data/event_definition_v6.md` (v5 plus an optional `flow`
    block: evidence, origin, state_context, hops with entered_by / answers
    / gates / map_locations / poll_supplies / dialogue / after /
    message_count, terminal; the top-level dialogue is hop markers + hop
    lines + one scene_end), `config/contracts/event_definition_v6/` (8
    valid / 65 invalid fixtures, fingerprint `74556e64...`), 16 new
    fail-closed reasons in `tools/validate_event_definition.py` (the
    trailing scene_end case folded into `hop_marker_mismatch`); Python
    suite 1,921 OK on main. Unit 2 landed 2026-09-25 (`97382f2`, merged):
    the group validator's `--replay` writes a v14 replay per hop from the
    flow runner's own data; `tools/project_event_definition_v6.py` wraps
    v5 for the 142 ordinary sites and builds the three flow documents
    from the origin guard, the hop replays and a fresh package
    (`fabd31f7...`, 145 events / 241 members / 150 groups); the batch
    takes `--contract v6`; `config/event_definitions/v6/` holds 145
    documents (`miko.town.station.date-town.1` 23 hops / 83 lines,
    `date-date5.1` 21 / 92, `date-hotel.1` 23 / 272; effects by v4 rule 2
    over the one variant, the rest named `unresolved`) with index
    fingerprints contract `74556e64...`, names `149ccc39...`, cells
    `de212469...`; 145/145 valid, tracked test class v6 (43/43), local
    tier 135/135, Python 1,936 OK. Recorded, accepted: the 142 ordinary v6
    documents are not byte-identical to v5 - the witness corpus under
    `analysis/` grew since v5 froze, so 139 of them carry more decided
    `after` rows (1,997 fewer `unresolved` lines, no row contradicting a
    v5 decision; true of that first run only - the committed set lost the
    rows at `f9a2454` and TD-37 restored them on 2026-10-03);
    `validate_event_definition.py`'s `ID_RE` now matches the
    registry's hyphenated `number`; `resolve_site` skips a route with no
    caller/callee. Not built: the return-visit variant; in-document
    choices between sibling routes. **Next (in progress,
    `analysis/_docs/ep12_b_date_template_spec.md`):** heroine B's date as
    the template proof - a date-flow measuring tool (`draft_date_flow_specs.py`
    + `measure_date_flow.gd`, per-heroine cells from the promise `CASES`
    table, the flag table and the hotel table) that finds the guard,
    decodes `?_DATE3`'s gates and writes the three flow specs; then
    `01m-b-date` declared, registered, promoted, named and defined (v6).
    **B landed 2026-09-25 (`f9a2454`, merged `44f8c52`):** guard
    `01M.MES:24255`; three routes (town 23 hops, DATE5 21, hotel 23;
    B_DATE3 7 / 22 / 49 lines, B_HOTEL 22, B_HOTEL1 70, B_HOTEL2 18);
    departures from A: the DATE5 ladder also tests `global_u8[539]`, the
    hotel ladder has five bands (top 91, not 111), `B_DATE5`'s special-
    date gate is a plain clock check so its TALK dispatch runs inline;
    catalog revision 30 / 148 rows, registry `fa845b5b...`, v6 148/148,
    151 groups, playback 148 rows / 125 reached / 20 / 3 / 0, Python
    1,936 OK. **C..L landed 2026-09-25 (`ba176f8` / `090ef03`, merged):**
    ten groups, 27 routes (`docs/spec/mes/heroine_date_flows.md`): C, E,
    F, G, H, I, K all three routes; D town + DATE5; J town + DATE5; L town
    + hotel. Left out and named: D's hotel and L's DATE5 (the `?_HOTEL` /
    `L_DATE5` open-choice contract cannot be rebuilt by the shared
    single-resume-point technique, a pre-existing tool limitation also in
    `measure_event_route.gd`); J's hotel (under the baseline the hotel
    case reaches an earlier unconditional MACHI handoff at 43769 before
    the real `J_HOTEL` handoff at 44083; the routing flag is unidentified,
    candidates `global_u8[823]/[868]/[3006]/[2847]`). Generic departures
    the tool now measures: a jump-chased town terminal (D/E/F/K), no money
    gate in the hotel case (E/G/I/J/L), the HOTEL site selector sharing its
    file with a later question (E/I); E/I's HOTEL2 and L's DATE5 own
    choices answered with the first option (the others named as sibling
    routes not declared), so E/I's hotel routes end on `44C.MES` (chain).
    A real tool bug fixed: the hotel answer sent the constant 3 instead of
    the heroine's selector (1 for G/J/L, 2 for E/I). `FLOW_SITES` replaced
    by derivation from the registry row + profile schema (A/B documents
    byte-identical but for fingerprints). Catalog revision 31 / 175 rows,
    registry `ea754ca2...`, v6 175 documents (all regenerated: the index's
    single package reference), 161 groups, playback 175 rows / 152 reached
    / 20 / 3 / 0, archive checks 169/169, Python 1,936 OK. TIME needs no
    unit of its own: `?_TIME` is dispatched only by the eleven date
    callers inside the declared date sequence. **Owner ruling 2026-09-25:
    PROMIS next** - one group per heroine at the station site (`01M.MES`;
    A's call at 79218 behind `global_u8[1010] == 1`, after the TALK
    ladder), the promise question's offered answers as routes, the other
    ~40 sites per heroine recorded as equivalents. **Measured 2026-09-25
    (`b85a26d`/`2e07f03`, merged `5592c7d`; `docs/spec/mes/promise_groups.md`):**
    all twelve station sites sit in one `01M.MES` address-table entry
    (77660), each one call behind its own flag (A `[1010]`, B `[598]`, C
    `[1669]`, D `[721]`, E `[1808]`, F `[1520]`, G `[1381]`, H `[2099]`,
    I `[1235]`, J `[803]`, K `[2200]`, L `[1941]`); every flag is set only
    by that heroine's own `?_TALKnn` scripts and cleared only by her
    `?_PROMIS` (archive-wide scan); every promise asks two questions - a
    15-place picker with individually gated options, then the confirmed
    ten-option time selector (option 1 hidden at location 0, options 2-10
    each a route writing the day/time pair and `global_u8[610+n]`); the
    caller's resume is the same boilerplate to `87590` for all twelve. The
    drafter gained `--question-offset` and `callee_prefix_choices`. **No
    group declared yet:** the routine-40 choice contract refuses the place
    picker's sparse catalog (offered ids with gaps; "definition identifiers
    do not match the supported stored form") - **fixed 2026-09-25
    (`a04e75e`, merged `01e12b4`, Core 0.366.0):** the contract accepts a
    sparse catalog (schema v5: `catalog_form`, `hidden_ids`, `hidden_gates`
    binding each hidden option's gate record; v3/v4 still accepted; the
    audit re-derives it), the consumer stays the one-based chain; the A
    picker offers ids 0..7 and 9..13 under the location-0 baseline (8
    hidden at gate 1587); 161 groups, hotel menus and catalog routes
    green, 39 contract checks. **The twelve promise groups landed
    2026-09-25 (`c9b9dff` / `fe2403c` / `14b7157`, merged; Core 0.367.0
    for the gate-hash degrade):** `01m_<letter>_promis_v5.json` x12 at the
    station sites (`docs/spec/mes/promise_groups.md`), the picker answered
    at position 3 = "location 2" (the consumer is a one-based position
    chain over the offered ids; position 1 loops back to the same question
    with its option hidden - how it ends natively is not established),
    the time question's ten options as routes (A 7/10: options 8-10 need
    A's own latch `global_u8[1060]`, measured and named), each route
    writing the day/time cells, `global_u8[610+n]` and the place cell and
    resuming to `MACHI.MES` after 6 lines; guard flags set only by the
    heroine's own TALK scripts and cleared by her PROMIS. The promoter now
    reads the live v6 definitions (`--definitions-dir`, v4 alias; the 175
    rows byte-identical either way; *annotation 2026-10-09: since WD-21 U2 C5
    the promoter reads v7 only and refuses a non-v7 set, catalog revision 41*); a new ordinary site's members enter
    the package through the export's opt-in `--include-unbound-groups`
    bootstrap before its row exists; a sparse-catalog contract built from
    a package code source records `RANGE_UNAVAILABLE` for a hidden gate's
    hash. Catalog revision 32 / 187 rows, registry 154 pairs, v6 187/187,
    173 groups, playback 187 rows / 164 reached / 20 / 3 / 0, local tier
    135/135, Python green. **Owner ruling 2026-09-26: the date/promise
    leftovers next** (in progress, `analysis/_docs/ep12_leftovers_spec.md`):
    the measurers build a routine-40 contract from the probe's live stop
    instead of a bare re-run (Core 0.368.0; D's hotel and L's DATE5 were
    left out only by that re-run losing the argument-slot/library
    context); J's hotel case hands off to MACHI at 43769 unconditionally
    with `[868] = 1` (no branch reaches the `J_HOTEL` handoff at 44083; an
    address-table entry 360 sits right after it, and `[868]` is read only
    by `J_DATE3`/`J_DATE5` - a two-visit affair to measure); A's promise
    options 8-10 declared with the Confirmed latch `global_u8[1060] = 1`
    (written by `A_PROMIS`'s own first pass at affection >= 100 and by
    `A_TIME`); the picker's position-1 re-ask recorded, not declared; one
    regeneration (revision 33). **Landed 2026-10-03, merged to `main` (checkpoints A `8877c90`,
    B `532a7e8`, C `d4295fd`; the unverified WIP `cd2dd1d`
    was verified, not discarded):** catalog revision 33 / 189 rows (D hotel and L
    DATE5 declared), A's promise options 8-10 declared, 173 analysis groups,
    registry 154 pairs, v6 189/189, package `13bd0a22...` (Core 0.368.0).
    Checkpoint A: the measurer change is non-regressive - the twelve date
    flows rebuilt on the branch are byte-identical to what main's own code
    produces for the ten unchanged letters, D and L reproduce their committed
    profiles byte for byte (LF-normalized), no `fallback re-run` anywhere; the committed
    B,C,E..K profiles (and J) carry routine-40 contracts of schema v4 where
    the toolchain on `main` has emitted v5 since Core 0.366.0 (pre-existing
    drift, not from this unit, not regenerated - open item below); A's profile is hand-authored
    and not reproducible by the template tool; the inputs of the ordinary
    groups and of A's promise profile are lost, so their byte-identity rests
    on `original catalog group routes` (4 shards, 189 rows) and the profile
    validator (1,006 checks). Checkpoint B: J's hotel two-visit mechanism and
    the picker's position-1 re-ask are the archive-tier check `original EP-12
    re-entry probes` (J stays measured, not declared; the native selector of
    entry 360 stays unresolved; position 1 not declared). Checkpoint C: the
    committed registry's `names_fingerprint` (`4f7454...`) never matched its own
    files; regenerated `36b9c8...` carried into v4/v5 (286 one-line patches)
    and v6 (190 one-line differences, nothing else moved); route
    classification refreshed for revision 33 (two new catalog routes, new
    payload hashes, no class moves). Every Core label bump moves the package
    hash (it folds in `content_core_version`), so a regeneration unit exports
    after its version bump. The witness-derived rows that were 0 in v6 from
    `f9a2454` are restored (`todo/code_health.md` TD-37, closed 2026-10-03:
    `shift_witness` 1,718, `reentry_probe` 46, `unresolved` 5,405 -> 1,580 in the 154 ordinary documents (all 189: 7,683 -> 3,858);
    the producer now refuses a projection without the witness corpus).
    Then the gallery families
    (CG from the 13 `?_M` menus, H from `43C`/`OMAKE`, SCENE) as a replay-
    gallery shape, TALK, the return-visit variant and the three left-out
    date routes.
  - [x] Regenerate the B, C, E..K and J `01m_<x>_date_v14` analysis-group
    profiles at routine-40 contract schema v5 (the toolchain's output since
    Core 0.366.0; the committed files carry v4 contracts without
    `catalog_form`/`hidden_ids`/`hidden_gates`), then re-project v6 and
    re-export the package. Found 2026-10-03 by the leftovers unit's
    checkpoint A (`8877c90`). **Done 2026-10-03 (checkpoint A `72d814d`,
    B `ab41d16`; no Core bump):** the nine v4-contract profiles
    (B, C, E, F, G, H, I, J, K - identified by each committed profile's
    contract schema; D and L were already v5) regenerated with the unchanged
    chain, J with its town and date5 specs only (hotel stays measured, not
    declared). Semantic diff to the committed files: the choice contracts'
    `schema`, `catalog_form` (`contiguous` in all 96), `hidden_ids` and
    `hidden_gates` (`[]`) and `payload_sha256` - nothing else; replays differ
    in `payload_sha256` alone; zero `fallback re-run`. The profile hash is the
    identity the catalog and the v6 flow documents bind, so 26 catalog rows
    (8 x 3 + J's 2; `CATALOG_REVISION` 34, 189 rows) and 26 v6 flow
    documents moved with it; the package re-exported (`a4880971...`, was
    `13bd0a22...`; membership unchanged), all 189 v6 documents and the index
    moved the package hash (163 documents that field alone); registry and
    `names_fingerprint` unchanged; route classification moved only
    `analysis_group_evidence` hashes and `catalog_sha256` (no class or
    confidence move). Verified: 12 date profile validators (184 checks each,
    J 128), `original catalog group routes` 4/4 shards, tier local 135/135,
    full batch with the archive and executable 401/402: the one failure,
    `original sequence contextual authoring`, exercises nothing this unit
    changed (`tools/mes_authoring_workflow.py` and its test are untouched);
    it stops at the test's fixed 60 s deadline (`tests/test_mes_authoring_workflow.gd`,
    `_wait_authoring`) during the EVENTB03 two-step sequence compile, and
    passed in the leftovers batch earlier the same day. The implementer
    reported it failing the same way on the pre-unit commit `06c9d72` and a
    ~62 s standalone compile, but recorded neither run (no tree-identifying
    report on disk; isolated reruns on this tree took 106-112 s per check).
    Tracked as `todo/code_health.md` TD-38, ahead of EP-12's next family.
    **Known residual:** `01m_a_date_v14` still carries routine-40 contracts
    of schema v4 - it is hand-authored and not reproducible by the template
    tool, so it stays v4 by design until its own regeneration path exists.
  - **Gallery families measured 2026-10-03** (`docs/spec/mes/gallery_families.md`;
    probes in `analysis/_undoc/ep12_gallery/`, untracked; measurement only,
    nothing declared): the album is `START.MES` -> `OPEN.MES` (title answer 4,
    a nested call) -> `GIRLS.MES` (picker id `state_u16[13]` behind the
    heroine's ending cell `global_u8[2560..2572]`) -> one of 13 `?_M.MES`
    handoffs. The menus are one native-selection template (command `0x15`,
    the result is the A6 record id of `ALBUM.A6`; not routine 40), four scene
    slots a page, nine H slots, the CG entry is A6 id 18. The 365 scene flags
    are one run `3400..3764`, each set to 1 by literal writes of
    ordinary-play scripts (133 EVENT, 108 `?_HOTEL1`, 79 date parts, 14
    ending, 12 `?_HOTEL`, 12 recap, 7 other) and never cleared by a literal
    write. CG: 13 viewers, 389 slots (`5000..5388`), no dialogue, a slot ends
    in `DEFINVOKE [0]`, which the tool's registry lacks. H is not the album:
    `?_H.MES` is the in-room recollection chain called from `43C.MES` (answer
    3 of its question at 20161, heroine in `state_u16[13]`); `OMAKE.MES`, the
    other caller, is unreachable (no archive or executable name, its A6 table
    and four MMOs are absent). SCENE: all 365 run alone to a return (295 ask
    nothing, 70 carry their own routine-40 question, 12 recap scenes read
    four state cells each and play nothing unseeded); twins are 29 scenes of
    27 shipped EVENT rows, 13 of `?_END` scripts (no row) and 8 internal H/K,
    and 236 of the other 323 scenes are a contiguous run or subsequence of
    the script that sets their flag. Toolchain trial: a two-hop v14 flow
    (menu slot -> scene) builds, audits and validates for four scenes of two
    menus (19 checks each); the menu from its own entry (command `0x15`),
    paging and the CG slots cannot run. Options memo (untracked):
    `analysis/_docs/ep12_gallery_shape_options.md`. The shape stays the
    owner's choice; nothing here changes the EP-12 order.
  - **Owner ruling 2026-10-04 (the recommended option, advisor-reviewed):**
    SCENE takes option A - one analysis group per `?_M.MES` menu (a v14
    flow: the menu's call site behind the scene's unlock flag, then the
    scene to its `script_return`), one catalog row per scene (365), no
    contract change; the menu selection (`state_u16[18]`, page
    `global_u8[20]`) is a seeded state, labelled a tool decision (command
    `0x15` cannot run). Twins: the 29 scenes message-identical to an EVENT
    callee are rows classified `duplicate_route` with `canonical_event_id`
    = that EVENT row (a tool decision documented in `docs/spec/`); the 13
    `?_END` twins are ordinary rows; of the 4 internal H/K pairs the H scene
    is canonical. Recap scenes: one row, two presets (DATE5 path all-1 by
    default, hotel path all-2); a scene's question options are presets of
    its row. `display.categories` carries `gallery` (the id stays in the
    `special` fall-through). **CG deferred** (no lines; the flag -> picture
    table goes to WD-21). **H** is not a gallery family: 13 ordinary
    `43C.MES` sites (36974..37334) after SCENE and before TALK. New order:
    SCENE (heroine J first, `MINATU_M.MES`, 25 scenes; then the other 12
    menus in one regeneration unit) -> H -> TALK; CG with WD-21.
  - **SCENE tools landed 2026-10-04 (heroine J unit, checkpoint A):**
    `tools/draft_menu_flow_specs.py` + `tools/content_suite/cli/measure_menu_flow.gd`
    (static menu recipe, seeded-selection measurement, one v14 spec per scene),
    `build_event_names.py` accepts `SCENE_*` callees of an album menu,
    `promote_analysis_groups.py` carries the `gallery` category, the returning
    scene's callee-return + menu-loop terminal pair (route outcome
    `place_menu`) and the `duplicate_route` rule; all tool decisions in
    `docs/spec/tech/content_tools.md` ("EP-12 gallery SCENE tools"). **Found
    while building them:** a v14 route holds one answer per question and one
    message count per hop, so a question's other options and a recap scene's
    second path (`SCENE_J14`: 32 messages all-1, 36 all-2; `SCENE_J08`/`J13`:
    option 2 plays the same 9/14 lines) cannot be variants yet. The advisor's
    review premise (`promote_analysis_groups.py:519` carries options as presets)
    holds for the v4/v6 paths, not for flows. Open item for the planner: an
    additive v14 variant field (answers, per-hop message counts) before the
    12-menu unit (67 question scenes, 11 recap scenes); J is declared with
    default variants and the gap recorded in each route's `unresolved`.
  - **Heroine J declared 2026-10-04 (SCENE unit, checkpoint B):**
    `minatu-m-scene` (`config/event_catalog/analysis_groups/minatu_m_scene_v14.json`),
    25 two-hop flows (menu call site behind the scene's unlock flag with the
    selection and page seeded, then the scene to its `script_return`; audit ok,
    flow validator 283 checks, 0 failures), 25 catalog rows (revision 35, 189 ->
    214: 22 playable, the 3 EVENT twins `SCENE_J03`/`J04`/`J06` as
    `duplicate_route` of the `EVENTJ04`/`J09`/`J18` rows; the `J_END` twin
    `SCENE_J16` an ordinary row), registry 214 rows, package v7 214 events from
    397 members (`e2ba7c49...`), 214 v6 documents. Details and the anchors in
    `docs/spec/mes/gallery_families.md` ("Declared"). Route classification moved
    only its `catalog_sha256` (the 167 classified entries contain no `SCENE_*`
    or menu entry; the unit expected new bindings). Presets: default variant
    only (open item above). Next: the variant fields, then the other 12 menus
    in one regeneration unit.
  - **v14 variant fields, 2026-10-04 (unit `analysis/_docs/ep12_v14_variant_answers_spec.md`,
    advisor ruling: in place, additive, not v15; no regeneration of any tracked
    artifact):** a v14 route variant may carry `answers`
    (`{hop_id, boundary_offset, result_value}`) and `message_counts`
    (`{hop_id: n}`), so a scene question's other options and a recap's second
    path can be variants (presets) of one row. Checkpoint 1 - the Python audit
    binds them (`_audit_flow_variant`, same routine-40 contract check as a hop's
    own answers; synthetic tests in `tests/test_event_analysis_group.py`); the
    stop rule (a variant whose terminal differs from the route's cannot be
    declared) is recorded in `docs/spec/tech/content_tools.md`. Checkpoint 2 -
    the runtime: `KakyuEventFlowRunner.hop_answers`/`hop_message_count` are the
    one override rule; the runner answers a variant's options, the flow
    validator asserts the variant's own count, and the catalog's
    `_selections_contain` reads the variant's answers (synthetic proof: a
    two-option QC.MES in `tests/test_event_analysis_group_flow.gd`, the helper
    rules in `tests/test_catalog_analysis_run.gd`). Checkpoint 3 - the
    promoter: `build_flow_choices` lists the hop's own answer first and then
    every other value a variant's `answers` gives that hop at that boundary
    (option 2 of a scene question is an option of the row, resolved to the
    variant's preset); every variant is already a preset, so a recap path is a
    preset with its writes; `promote_analysis_groups.py --check` still
    regenerates the tracked catalog byte for byte (no installed route carries
    the fields). Checkpoint 4 - the Event Player's phrase (Core 0.368.0 ->
    0.369.0, `content_core/` changed): a matched `callee_return_only` terminal
    of a row with a decided route outcome is phrased by that outcome
    (`matched_terminal_outcome`, GD and Python ports, parity checked against
    the pinned route-outcome snapshot over all 214 rows; an album scene reads
    "Back to the place menu"), at the three player sites; the group-routes
    validator's Playback pass asserts it per row. Rule:
    `docs/spec/data/event_outcome_vocabulary.md`. Checkpoint 5 - the two
    identical gallery-row predicates (`_is_gallery_row` in the v6 projector,
    `is_gallery_registry_row` in the promoter) are one function in
    `tools/payload_values.py` that both import (TD-05); the finding that the
    date flow documents' first `unresolved` line is heroine A's guard text is
    `todo/code_health.md` TD-43 (no fix here). **Scratch re-measure of heroine
    J (nothing installed, nothing tracked regenerated; untracked under
    `analysis/_undoc/ep12_v14_variants/`):** the J unit's 25 specs rebuild
    to the installed profile semantically identical (same `payload_sha256`);
    extended so `SCENE_J08`/`J13` option 2 are variants with `answers`
    (`option-2`) and `SCENE_J14`'s all-2 path a variant with the four cell
    writes and `message_counts` `{h2_scene: 36}` (`hotel-path`), the scratch
    profile audits ok and the flow validator passes 301 checks (283 + 18, 0
    failures; 28 variant runs), reproducing the study's counts exactly -
    J14 32 lines default / 36 all-2, J08 9 and J13 14 lines on both options,
    every variant ending at the route's own return (`script_return` at the
    same record), option 2 leaving `state_u16[21]` = 2. Promoted into a
    scratch catalog (revision 35, 214 rows): J08 and J13 each gain
    `option-2` as a second option of `choice-...-353` (two options, two
    presets) and J14 a second preset `hotel-path`; the other 22 J rows move
    only by the profile hash they bind. Through the real Event Player with
    the scratch catalog and profiles (32 checks, 0 failures): option 1 and 2
    each resolve to their own preset and run their own variant, the default
    preset refuses option 2 ("not measured by this preset's variant"), and
    J14's two presets play 32 and 36 lines, status line "Back to the place
    menu". The 12-menu unit re-measures and regenerates all 13 menus at once
    (the package binds group payload hashes, so installing J alone would
    move everything); the measurer (`measure_menu_flow.gd`) still reports
    alternatives rather than declaring them - declaring them as variants is
    that unit's step. **Verified:** Godot parse check; the Python audit,
    promoter, vocabulary, payload and projector suites; the synthetic scenes
    (`test_event_analysis_group_flow`, `test_catalog_analysis_run`,
    `test_event_outcome_vocabulary`); `--tier local --cached --jobs 6` 135/135
    after checkpoint 2; the three analysis-group checks (`MINATU M scene`,
    `01M A date`, `01M J date`) passed; `original catalog group routes` 4/4
    shards with the new Playback status assertion; `promote_analysis_groups.py
    --check` byte-identical; and, since `content_core/` changed (Core 0.369.0),
    the closing proof is the uncached whole batch: `--tier full --jobs 6
    --cache-store` with the archive and executable, detached, on the committed
    tree `46f8eff`: **403 checks, 403 passed, 3,006 s** (`cached: 0`).
  - **All 13 album menus, 2026-10-04 (unit `analysis/_docs/ep12_scene_all_menus_spec.md`,
    owner ruling 2026-10-04 option A) - checkpoint A, the measurer writes variants:**
    `measure_menu_flow.gd` now declares a scene's other answered question
    combinations (a two-question scene: each) and a recap scene's second path as
    route variants (`menu_flow_variants.gd`, synthetic proof
    `tests/test_menu_flow_variants.gd`; advisor note (c): no hand-written spec
    pass) and names any path that ends elsewhere in the route's `unresolved`
    list. The drafter ran on all 13 menus (365 scenes, no shape mismatch) and
    gained `nested_members` - four scenes (`SCENE_A15`, `C08`, `H05`, `M14`) nest
    a `*_PIC.MES` standing-picture script and could not return without it, so the
    entry is a source member of that scene's flow (a tool fix the spec did not
    name; the four entries are already members of other groups). Scratch
    measurement, build, audit and runtime validation of all 13 menus (nothing
    installed): 365 routes, 91 variants (79 option variants - 63 two-option, 5
    three-option and the two two-question scenes `SCENE_I02`/`L11` three each - and
    12 `hotel-path`), no unresolved alternative, no variant-only or skipped
    question, every profile audit ok and every flow validator pass (4,669
    checks); heroine J's profile equals the variant unit's scratch proof
    (`payload_sha256` `9e56fb89...`, 301 checks). Details per menu are recorded
    with the declaration (checkpoint B).
    **Checkpoint B - the 13 menus declared (`docs/spec/mes/gallery_families.md`,
    "Declared: all albums"):** the 13 profiles (`<menu>_scene_v14.json`; J's replaced by
    its re-measured form, same routes and sites, payload `9e56fb89...`) installed under
    `config/event_catalog/analysis_groups/`, the 12 new analysis-group checks registered
    in `config/validation/checks_v1.json` (268 -> 280 entries; same tier, group and 300 s
    timeout as J's), the SCENE advisor note (a) done (the Playback pass asserts the
    place-menu status line for every row with `gallery` in `display.categories`, no id
    prefix; `gallery_rows_checked` in the shard report). Recipe: `build_event_names.py`
    (`EXPECTED_PAIR_COUNT` 179 -> 519, `EXPECTED_CATALOG_COUNT` 214 -> 554) ->
    `promote_analysis_groups.py` (catalog revision 36, 214 -> 554 rows, **33
    `duplicate_route`**: 29 scenes of 27 EVENT callees and the four K copies of H
    scenes; no ambiguous twin) -> `build_event_names.py` (registry 554 rows;
    fingerprint in `config/contracts/event_names_v1/names_fingerprint`, its README
    entry written before the final run) -> package export at Core 0.369.0 (554 events from
    749 member entries, 154 catalog-verified, 595 bound by 186 analysis groups,
    `3ef6acc12182...`) -> the 13 profiles' v2 replays -> v6 at `--jobs 4` with the witness
    corpus (554 documents, `valid=554`, witness line unchanged) -> route classification
    refresh -> v4/v5 `names_fingerprint` carry (143 files each, one line each). Diffs
    measured, not assumed: the 189 existing non-album catalog rows are byte-identical (only
    J's 25 rows move: the profile hash, plus the presets/option of `SCENE_J08`, `J13`, `J14`);
    the 189 existing non-album v6 documents differ in `names_fingerprint` and
    `package_binding.package_sha256` alone (J's 25 also move the profile hash, J08/J13/J14
    their `unresolved` lines); **route classification moved `catalog_sha256` and, beyond the
    spec's expectation, the group list of four already classified entries** - `H_PIC.MES`,
    `M_PIC.MES`, `O_PIC.MES`, `P_PIC.MES` each gain the one album group that nests them
    (`source_member` role; bound entries 166 -> 166, no entry newly bound, no class or
    confidence move), a consequence of the drafter's `nested_members`. Advisor notes (b) and
    (d): no two-question scene (`SCENE_I02`, `L11`) hit the duplicate-answer refusal, and no
    row's question exists only on a variant's path or is skipped by one.
    **Checkpoint B2 - shard re-sizing:** a solo run of `original catalog group routes`
    `shard=1/8` on the new catalog (70 rows, 47 album rows; 95 runs, 5,304 checks, no
    failure, `gallery_rows_checked` 47) took 1,470 s, about 21 s a row - the album rows
    cost about twice what the earlier rows did - so the 554 rows are about 11,800 s of
    shard work and four shards would have exceeded their 3,000 s timeout. The entry now
    has `shards` 20 (27-28 rows, about 590 s alone, expected about 1,000 s at `--jobs 6`;
    timeout unchanged at 3,000 s); no test pins the shard count
    (`tests/test_validation_registry.py` reads it from the registry);
    `docs/spec/data/validation_checks.md` records the sizing. **Closing proof (Core
    0.369.0, `content_core/` unchanged this unit, but the plan changed):** the whole
    batch uncached with `--cache-store`, `--jobs 6`, detached through
    `launch_detached.py --godot` on the committed tree `0d03d1e`: **432 checks, 432
    passed, 4,251 s** (ordering seeded by a report planted at the `--report`
    path with the new `[K/20]` shard rows at 1,000 s - order only, not
    pass/fail; the runner itself sorts unknown shard names last, TD-44)
    (run `eab1a1e1`, `cached: 0`; 403 + 12 album-group checks + 16 more
    shards + the `test_menu_flow_variants` scene). The 20 shards took 507-695 s
    (rows 27-28 each; the estimate was about 1,000 s - the batch cost them 0.9 to 1.2
    times their solo estimate, not 1.3 to 1.85, so 12 shards would have sufficed; 20 is
    kept; `gallery_rows_checked` sums to 365), the analysis-group members 1,320 s in all (186 members, the 13 album checks
    15.0-21.4 s each), the transfer-direction corpus 941 s (0.39 of its timeout); no check
    reached 0.5 of its timeout. Then `--cached --jobs 6`: 432 of 432 cached, 6.7 s (run
    `50c1b014`). Reports kept under `analysis/_undoc/ep12_all_menus/`. Open: CG (WD-21),
    H (the 13 `43C.MES` sites), TALK, TD-43 (the date flow documents' first `unresolved`
    line), the hotel return-visit variant.
  - **H, 2026-10-04 - checkpoint A (unit `analysis/_docs/ep12_h_43c_spec.md`, owner ruling
    2026-10-04: 13 ordinary `43C.MES` sites after SCENE, before TALK):** the prerequisite is
    settled - the question at `43C.MES` 20161 is the room-action menu (selection group 0,
    six rows; definition 18493 is the leave row of `room_screen.md`; answer 3 the recollection
    row, followed by the native "memories with her" menu whose result is `state_u16[13]`;
    `docs/spec/mes/43c_caller_group.md`). **Stop and ruling:** with every gate set, 8 of the 13
    ladders need 516..649 segments (all 13: 417..649) and the probe allowed 512 (`content_core/mes_route_probe.gd`),
    so they could not reach their return; the advisor ruled an additive v14 hop field
    `segment_budget` (default 512, audit `512 < n <= 4096`, declared 1024 on the 13 second hops;
    the flow runner forwards it only for a hop that has it, so no installed profile moved),
    **Core 0.369.0 -> 0.370.0**. Tools: `tools/draft_recollection_flow_specs.py` (static: the
    room's 13 id tests, the clock-save origin, the answer and return chains, each ladder's gates
    by the structural rule - single `global_u8` flag test on the main path, not tail, presentation
    or selector cells, not enclosed by a non-gate span, nested gates are gates, a pure OR of flags is
    transparent; **330 gates over the 13 ladders, 326 cells**, against the 281 of the byte-skip
    rule) and `tools/content_suite/cli/measure_recollection_flow.gd` (default variant the full
    recollection, `no-recollection` every gate cell 0; the named cell-write variants generalize the
    recap's `hotel-path` in `menu_flow_variants.gd`); `build_event_names.py` names the rows
    `<name>.town.43c.h.1` (route id `<letter>-h`), the promoter tags them
    `["character_event", "town"]`; **TD-43 closed** (`flow_done_flag_line`). Verified: parse check,
    the synthetic scenes and Python suites for each change, `--tier local --cached --jobs 6`.
    **Gate recount (the advisor's request):** the structural rule gives **330 gates over
    326 cells, 60 nested** (`MIYUKI_H` 25, `MINATU_H` 20, `TINA_H` 18, ...; the byte-skip rule's
    281 missed every segment under 1,000 bytes and the prologue segments); a pure OR of flag tests
    is transparent (advisor addendum: `MIYUKI_H` 64394, `MINATU_H` 33672, whose member `[924]` is
    guard-only and not seeded); every static gate is evaluated and taken by the full recollection;
    the recap blocks (ORs over selector cells), the picture arms and the tail cells stay at 0
    and are reported per ladder.
  - **H, 2026-10-04 - checkpoint B, the 13 ladders declared (`docs/spec/mes/43c_caller_group.md`,
    "Declared: the 13 recollection ladders"):** 13 profiles (`43c_<name>_h_v14.json`, one route
    `<letter>-h` each: hop 1 `43C.MES` from the clock save at 36938 through the heroine's id test to the
    call, hop 2 the ladder to its `script_return` with `segment_budget` 1024; default variant 570-911
    messages, `no-recollection` 9 (`TINA_H` 18); Python audit ok, flow validators 25 checks each, 26
    for `NANA_H`) installed, 13 analysis-group checks registered (280 -> 293 entries). Recipe:
    `build_event_names.py` (`EXPECTED_PAIR_COUNT` 519 -> 532, `EXPECTED_CATALOG_COUNT` 554 -> 567) ->
    `promote_analysis_groups.py` (catalog revision 37, **554 -> 567 rows, the 554 existing rows
    byte-identical**; the ladder rows `["character_event", "town"]`, route outcome `place_menu`) -> the
    registry again (fingerprint `a28d403c...`, README entry) -> package export at **Core 0.370.0** (567
    events from 762 member entries, 167 catalog-verified, 595 bound by 199 analysis groups,
    `f45a5cd5...`) -> the 13 profiles' v2 replays -> v6 at `--jobs 4` with the witness corpus
    (567 documents, `valid=567`, witness line unchanged) -> route classification refresh -> v4/v5
    `names_fingerprint` carry (143 files each). Diffs measured, not assumed: the 519 existing
    non-date v6 documents differ in `names_fingerprint` and `package_binding.package_sha256`
    alone, the 35 date documents also in their first `unresolved` line (**TD-43's regeneration**:
    now each document's own guard); route classification moved only `catalog_sha256` and the
    group list of one entry - `O_PIC.MES` gains `43c-nana-h` as a `source_member` binding (166
    bound, no class or confidence move; no ladder entry is among the 167 classified rows).
    Group-routes cost: one solo `shard=18/20` (28 rows, two of them ladders; 34 runs, 3,464 checks, no
    failure) took 574 s against the typical shard's 590 s, so the 20 shards stay (the ladder rows did
    not raise the cost measurably; the Playback pass lists picture and animation names of the
    ladders that the shipped `mmo.arc`/`data.arc` lack, 13 and 22 names over the two ladders of that
    shard). Verified: parse check, the synthetic scenes and Python suites, `--tier local --cached
    --jobs 6` 136 of 136 (twice: after A and after the regeneration). **Closing proof (Core
    0.370.0, `content_core/` changed and 13 checks added):** the whole batch uncached with
    `--cache-store`, `--jobs 6`, detached through `launch_detached.py --godot` on the committed tree
    `2eb1127`: **445 checks, 445 passed, 5,155 s** (run `4f1ae99f`, `cached: 0`; about 14% slower
    per check than the previous whole batch); the 20 group-route shards took 587-769 s (mean 667 s,
    at most 0.26 of their 3,000 s timeout), the 13 ladder checks 17.7-22.7 s each, the transfer-direction
    corpus 1,062 s (0.44) and the analyzer handoff corpus 1,049 s; **four unrelated small-timeout
    checks reached 0.50-0.64 of their timeouts in the loaded run (solo 0.43-0.49): `todo/code_health.md`
    TD-46, not changed here.** Then `--cached --jobs 6`: 445 of 445, all cached, 8.5 s (run `8fee3d9b`).
    Reports kept under `analysis/_undoc/ep12_h_43c/`. Open: CG (WD-21), TALK, the hotel return-visit
    variant, TD-44/45/46.
  - **TALK, 2026-10-04 - measurement and shape options (unit `analysis/_docs/ep12_talk_study_spec.md`,
    `docs/spec/mes/talk_family.md`; nothing declared, no contract change; options memo
    `analysis/_docs/ep12_talk_shape_options.md`, untracked):** the 142 `*_TALK*` scripts (96 affection-banded
    rung scripts, 28 follow-ons, 9 plain, `M_TALK`, eight of the characters N..Q) are called from **4,905
    sites** by 136 callers (the census's 4,905 sites and 488 questions reproduce; its 241 DATE5/HOTEL pairs do
    not: 296 sites in 37 blocks, 200 pairs). One fixed eight-rung ladder on the heroine's affection word in all 537
    ladder blocks (4,296 sites, `TALK00` the top band) under a four-level guard (place roll `global_u8[351]`,
    presence flag, calendar window, today flag); a block ends at the town handoff. A script is a topic hub (488
    routine-40 questions, 24,066 branches; one state plays 3-4% of its text); the contract tool names **485 of
    488 questions in a fresh state but 421 of 488 in the natural presence state** (67 rejected: the first question of
    64 rung scripts of eight heroines and three of J's); 318 answer paths, 214 return, 103 re-ask. The 35
    declared date routes never reach a TALK call; a 23-hop extension of K's date5 route passes the audit and the
    flow validator (79 checks). Two- and three-hop v14 flows of K's rungs (44 checks) and `M_TALK` (21) build,
    audit and validate with a tool-seeded gate; the caller-continuation measurer hangs, the names registry has
    no TALK rule and a one-digit site ordinal. **Options (memo):** per script 142 rows (+620..1,030 s wall at
    TD-47's 23.5 CPU-s per row), per site 4,905 rows (32 CPU-hours, 5.3 h wall; needs TD-47's cache and a
    registry v2), date extension 37 or 296 routes plus per script (179 or 438 rows). **Owner ruling needed:** the
    shape and the state policy of the topic hubs (a fresh topic state, a gate recount like H's, or a
    contract-tool extension, Core 0.371.0). Verified: `--tier local --cached --jobs 6`, 136 of 136 (documents
    only). Open: the TALK declaration, CG (WD-21), the hotel return-visit variant, TD-44..47, the three tool
    gaps of the memo (contract tool, `measure_event_route.gd` hang, names registry).
  - **Owner ruling 2026-10-04 (the recommended option, advisor-reviewed):** TALK takes shape A' - one row
    per called script (~114: 96 rung scripts, 9 plain, `M_TALK`, the eight of N..Q), anchored at the
    script's confirmed caller (for the twelve heroines the `01M.MES` ladder block): hop 1 the block guard
    through `?_PIC`, `?_INTRO`, the gate and the rung test to the rung call; hop 2 the script to its return;
    hop 3 the caller resuming through `?_OUTRO` to the `MACHI.MES` handoff (a TALK block ends on the town
    map, not a place menu). The 28 follow-ons are members of their parent rung's row (an answered
    question -> `answers` variant; behind a flag -> named cell variant); a follow-on path ending at another
    record than the parent's return becomes its own row. The other ~4,763 sites are recorded as equivalents
    in `talk_family.md` (the PROMIS precedent). State policy: the anchor's natural state (presence flag set,
    every topic done-flag 0, answer 1 by default; each other answer ending at the same return an `answers`
    variant; re-asking loops `unresolved` with their count); this needs the routine-40 contract tool to name
    the one-based chain whose positions split on scratch cells (64 of the 67 rejections; J's three stay
    unresolved) - Core 0.371.0. Groups per heroine (`01m-<letter>-talk`), small groups per caller for the
    rest; installed profiles untouched. First unit heroine K (10 scripts), then the other eleven heroines,
    `M_TALK` and N..Q in one regeneration. The DATE5/HOTEL -> TALK extension (37 blocks) stays an owner
    option for later. TD-47's cache is not needed (the catalog stops near ~681 rows).
  - **TALK K, 2026-10-04 - checkpoint A, the contract extension and the tools (unit
    `analysis/_docs/ep12_talk_k_spec.md`; Core 0.370.0 -> 0.371.0; nothing declared):** the routine-40
    contract tool admits a fourth consumer shape, the per-position scratch-split chain
    (`one_based_state_u16_21_scratch_split_branch_chain`, the new key `position_gates`, same `v5`
    schema; `docs/spec/mes/format_and_method.md`). **Re-measured over the 488 TALK questions: the
    natural presence state 485 named from 421 (the 64 first questions of the rung scripts of C, E, F, G,
    H, I, K and L, every one sparse with `hidden_ids [1]`), the three of `J_TALK40/50/60` still rejected;
    the fresh, ambient and all-flags states stay 485; every one of the 624 stored contracts of the 199
    installed profiles rebuilds byte for byte** (431 `v5` identical, 193 `v3`/`v4` valid). Tools:
    `tools/draft_talk_flow_specs.py` (static: the `01M.MES` ladder block of a heroine - guard, picture,
    intro, gate, the eight rung tests and calls, PROMIS, outro - each rung script's returns and follow-on
    calls, the plain script's anchor `27C_EV.MES:31343`; the natural-state seeds) and
    `tools/content_suite/cli/measure_talk_flow.gd` (three hops per rung, option 1 at every question,
    every other answered path walked with `detect_loops`, `answers` and `flag-<cell>` variants through
    `menu_flow_variants.gd`); `build_event_names.py` names a TALK route `<letter>-talk-<band>`
    (`ai.town.station.talk-30.1`); the promoter tags a TALK row `["conversation", <category>]`; the
    three-hop flow ending at the `MACHI.MES` handoff keeps the existing handoff outcome (pinned). **K,
    measured and built in scratch (nothing installed):** 8 rung routes at `01M.MES` block `83310` (hop 1
    8..20 messages, hop 2 4/8/13/13/13/18/18/17 for `TALK30`..`TALK00`, hop 3 6 messages to the
    `MACHI.MES` handoff at `89476`; the PROMIS flag is not up on any default path), and the plain `K_TALK`
    at `27C_EV.MES:31343` as a **two-hop** route (25 messages; its caller resumes into the place's day
    loop, which has no natural end: definition 12 stops at the step limit, and under the original calendar
    the loop plays on to `END1.MES`). Per route the answers other than option 1 all re-ask (3 come back
    unchanged, 1 finds the answered option gone), so the only variants are `flag-2194` on the six rungs that
    call `K_TALKXX`; Python audit ok, flow validator 164 checks (the 8-route group, 39 s) and 20 (plain).
    TD-46 closed (the four timeouts 600/600/600/240 s; the rule: a timeout is at least twice the loaded
    `--jobs 6` duration).
  - **TALK K, 2026-10-04 - checkpoint B, heroine K declared (`docs/spec/mes/talk_family.md`, "Declared: heroine K"):**
    9 rows in two groups - `01m-k-talk` (`01m_k_talk_v14.json`: the eight rung routes `k-talk-30` .. `k-talk-00`, three
    hops each, from the `01M.MES` block guard `83310` to the `MACHI.MES` handoff `89476`; `K_TALKXX` a member of rungs 50..00,
    `flag-2194` their one variant) and `27c-ev-k-talk` (`27c_ev_k_talk_v14.json`: the plain `K_TALK`, two hops from `27C_EV.MES`
    `31225`, 25 messages; its caller's day loop has no natural end) - 2 analysis-group checks registered (293 -> 295 entries).
    The 32 re-asking answer paths (4 per rung) are `unresolved`, no answer is a variant. Recipe: `build_event_names.py`
    (`EXPECTED_PAIR_COUNT` 532 -> 541, `EXPECTED_CATALOG_COUNT` 567 -> 576) -> `promote_analysis_groups.py` (catalog
    revision 38, **567 -> 576 rows, the 567 existing rows byte-identical**; display `["conversation", "town"]`, the rungs'
    route outcome `map_return`, the plain script's `place_menu`) -> the registry again (fingerprint `acaf48ae...`, README
    entry) -> package export at **Core 0.371.0** (576 events from 772 member entries, 168 catalog-verified, 604 bound by 201
    analysis groups, `7e2b40de...`) -> the two profiles' v2 replays -> v6 at `--jobs 4` (576 documents, `valid=576`, witness
    line unchanged) -> route classification refresh -> v4/v5 `names_fingerprint` carry (143 files each). **A stop, ruled by the
    planner:** the first v6 projection failed for the eight rungs (a hop runs `K_PIC`/`K_INTRO` inline, and their lines'
    entries were not hop entries: `KeyError`); the producer now includes the entries of replayed lines, and a TALK row's
    `dependencies` are the entries its route runs (the group declares every rung script of the heroine; the album branch's
    counterpart, `is_talk_registry_row`, `docs/spec/data/event_definition_v6.md`, "TALK flows"). Diffs measured, not
    assumed: **the 567 existing v6 documents differ in `names_fingerprint` and `package_binding.package_sha256` alone**
    (the producer change moves none), the index in `names_fingerprint`, `package_sha256`, `summary` and its 9 new rows;
    route classification moved only `catalog_sha256` and the group list of `K_PIC.MES` (it gains `01m-k-talk` and
    `27c-ev-k-talk` as `source_member` bindings; no class or confidence move). Verified: parse check, the synthetic scenes
    and Python suites, `--tier local --cached --jobs 6` 136 of 136 (after A and after the regeneration).
    **Closing proof (Core 0.371.0, `content_core/` changed and 2 checks added):** the whole batch uncached with `--cache-store`, `--jobs 6`, detached through `launch_detached.py --godot` on the committed tree `7fff4af`: **447 checks, 447 passed, 4,538 s** (run `2395516c`, `cached: 0`); the 20
    group-route shards took 538-665 s (mean 606 s, 12,129 s over 576 rows, 21.1 CPU-s per row; at most 0.22 of their
    3,000 s timeout: the nine K rows did not raise the per-row cost), the two TALK checks 39.5 s (`01m-k-talk`, eight
    routes) and 14.3 s (`27c-ev-k-talk`), the transfer-direction corpus 958 s (0.40 of 2,400) and the analyzer handoff
    corpus 951 s (0.32); **no check passed 0.41 of its timeout, and the four TD-46 checks ran 158, 159, 161 and 50 s of
    their new 600/600/600/240 s (0.21-0.27)**. Then `--cached --jobs 6`: 447 of 447, all cached, 7.1 s (run `d71d0bf7`).
    Reports kept under `analysis/_undoc/ep12_talk_k/`. Open: the other eleven heroines, `M_TALK` and N..Q (one
    regeneration), the DATE5/HOTEL extension (owner option), CG (WD-21), the hotel return-visit variant, TD-44/45/47/48/49.
  - **TALK rest, 2026-10-05 - checkpoint A, the contract schema v6 and the tools (unit
    `analysis/_docs/ep12_talk_rest_spec.md`; Core 0.371.0 -> 0.372.0; nothing declared):** the routine-40 contract
    schema is `kakyu_mes_routine40_choice_contract/v6` (advisor ruling): the scratch-split consumer's
    `position_gates` key, added inside `v5` at 0.371.0, belongs to `v6`; `v5` is a prior schema that validates without
    the key and is refused with it (or whose rebuild is the split form), the schema string not compared to the rebuilt
    `v6` (`docs/spec/mes/format_and_method.md`, "The schema is v6"). **Re-proved over every installed contract:** the
    632 contracts of the 201 installed profiles - 624 of the 199 pre-TALK profiles validate (431 `v5` rebuilt
    byte for byte schema string aside, 193 `v3`/`v4` valid) and heroine K's 8 split-form contracts (`v5` with the key)
    are refused as designed, to move to `v6` in checkpoint B's regeneration; `tools/audit_event_analysis_group.py`
    accepts `v6` and re-derives the sparse-catalog fields for `v5` and `v6` alike (one test). **Tools:** one shared TALK
    predicate (`TALK_STEM`, `talk_script_parts`, `is_talk_registry_row` in `tools/payload_values.py`) now covers
    `M_TALK` (Tina) and `N_TALK`..`Q_TALK1` besides the heroines' scripts, the registry numbers them
    (`tina.town.station.talk-plain.1`, `common.town.27c_ev.talk-n1.1`); the drafter reads all twelve ladders (the
    further gate conjuncts of C and J, J's `J_MINORU` call, numbered follow-ons, C's affection cap in `C_INTRO.MES`,
    which puts the date seed at 916 for her eight rungs) and the 18 band-less anchors (`PLAIN_ANCHORS`: the nine
    plain scripts at `27C_EV.MES`, `M_TALK` at `01M.MES:47934`, `Q_TALK` at `01M.MES:48530`, `N_TALK2/3` at
    `11M.MES`), seeds a heroine's plain script from the guard and its own gate and a character's from the guard
    alone, proves each guard witness statically; the measurer decides two hops or three by running hop 3
    (`resume_hop: "auto"`) and records a question the contract tool cannot name, met off the default path, as a
    path that does not run to the terminal. **Measured in scratch (nothing installed): all 114 routes** - 96
    rungs of 12 heroines reach the `MACHI.MES` handoff `89476` in the natural state, 9 plain scripts and
    the characters' `N_TALK`, `N_TALK1`, `N_TALK2`, `N_TALK3`, `O_TALK`, `P_TALK`, `Q_TALK1` as two-hop routes, `M_TALK` and
    `Q_TALK` as three-hop routes (their caller ends at the handoff); heroine K's eight specs differ from the installed
    ones only in the contract schema string and her plain spec not at all. Verified: parse check, the contract scene (65
    checks), the Python suites, `--tier local --cached --jobs 6` 136 of 136 (nothing cached: the Core moved). Reports kept under
    `analysis/_undoc/ep12_talk_rest/`.
  - **TALK rest, 2026-10-05 - checkpoint B1, the other eleven heroines, Tina and the characters N..Q declared
    (`docs/spec/mes/talk_family.md`, "Declared: all heroines, Tina and the characters N..Q"):** **105 rows in 26 new groups (28 with
    heroine K's two): 88 rung routes (`01m-<letter>-talk`, eleven groups of eight three-hop routes, each from the `01M.MES` block guard to
    the `MACHI.MES` handoff `89476`), 8 plain scripts (`27c-ev-<letter>-talk`, two hops from `27C_EV.MES`), `M_TALK` (`01m-m-talk`, three
    hops: its caller reaches the handoff) and the characters' `N_TALK`, `N_TALK1` (`27c-ev-n-talk`), `N_TALK2`, `N_TALK3` (`11m-n-talk`, two
    hops: the caller resumes into a place menu), `O_TALK`, `P_TALK`, `Q_TALK1` (two hops) and `Q_TALK` (`01m-q-talk`, three hops)**; 26 analysis-group
    checks registered (295 -> 321 entries). Every one of the 114 routes measured in the natural state with the CLI-drafted recipe (byte
    identical to the cached-archive draft) and its specs built, **Python audit ok for all 28 profiles, flow validators 20..227 checks each, no
    failure**. Per heroine (rows incl. plain; variants; re-asking / runaway answer paths): A 9; 6; 32 / 0 - B 8; 2; 39 / 17 - C 9; 6; 32 / 0 -
    D 8; 6; 41 / 1 - E 9; 6; 30 / 0 - F 9; 10; 32 / 0 - G 9; 10; 32 / 0 - H 9; 8; 32 / 0 - I 9; 6; 38 / 0 - J 8; 8; 36 / 5 + **3 unnamed questions
    (`J_TALK40/50/60`, on the path answering option 5 then 1 only; the default paths reach their returns, the routes declared in full)** - K 9; 6;
    32 / 0 - L 9; 14; 36 / 0 - M, N..Q: 9 rows, none; **88 variants, 412 re-asking paths and 23 runaway paths in all, none a variant**. Recipe
    as K: registry (EXPECTED_PAIR_COUNT 541 -> 646) -> `promote_analysis_groups.py` (catalog revision 39, **576 -> 681 rows**; the 576 existing rows
    byte-identical except heroine K's eight rung rows, which carry her profile's new hash; display `["conversation", "town"]`, 90 route outcomes
    `map_return`, 15 `place_menu`) -> the registry again (EXPECTED_CATALOG_COUNT 681; fingerprint `94223afe...`, README entry) -> the 28
    profiles' v2 replays -> package export at **Core 0.372.0** (681 events from 869 member entries, 188 catalog-verified, 681 bound by 227
    analysis groups, `7af75165...`) -> v6 at `--jobs 4` (681 documents, `valid=681`, witness line unchanged) -> route classification refresh ->
    v4/v5 `names_fingerprint` carry (143 files each). **Diffs measured, not assumed: the 568 existing v6 documents that are not K's rungs differ in
    `names_fingerprint` and `package_binding.package_sha256` alone; K's eight rung documents also in the two profile hashes of her regenerated
    group, nothing else; the index in `names_fingerprint`, `package_sha256`, `summary` and its 105 new rows.** Route classification moved
    `catalog_sha256`, the group list of 17 entries (`A_INTRO` and the twelve `?_PIC` scripts and `N_PIC`..`Q_PIC` gain the TALK groups as
    `source_member` bindings; `M_PIC` none) and **8 classes: the `G_TALK30`..`G_TALK00` scripts, previously `system_script` (a shared
    conversation callee), are `playable_event` now that catalog rows play them (143/23/1 -> 151/15/1; confidence unchanged)**.
    The cosmetic title issue (the place stem in `Ai at 27c_ev (K_TALK)`) is not fixed: naming the place would move the titles, and so the
    documents, of rows outside this unit (registry README). Also this checkpoint: the K section of `talk_family.md` says 48 callers
    (not 49) for her 49 blocks. Verified: parse check, the Python suites and the four GD scenes with count pins, `--tier local --cached
    --jobs 6` 136 of 136 (after A and after the regeneration), `--tier archive_quick --cached --jobs 6` 217 of 217.
    **Closing proof (Core 0.372.0, `content_core/` changed and 26 checks added):** the whole batch uncached with `--cache-store`, `--jobs 6`, detached through `launch_detached.py --godot` on the committed tree `19a3853`: **473 checks, 473 passed, 5,156 s** (run `375b8653`, `cached: 0`); the 20 group-route shards took 599-867 s (mean 721 s, 14,427 s over 681 rows, 21.2 CPU-s per row, as before: the 105 TALK rows did not
    raise the per-row cost; at most 0.29 of their 3,000 s timeout), the 28 TALK checks 13.9-59.5 s (the ladder groups 38-60 s, `01m-j-talk` the slowest at
    0.20 of its 300 s timeout), the transfer-direction corpus 1,001 s (0.42 of 2,400), the analyzer handoff corpus 991 s (0.33 of 3,000), the
    playback package playback 585 s (0.32 of 1,800); the four TD-46 checks 142, 154, 144 and 53 s of 600/600/600/240 s (0.22-0.26); **one check passed 0.5:
    `original playback package export`, 326 s of its 600 s timeout (0.54; 269 s solo; the package grew to 681 events from 869 member entries) - not changed, TD-50**. Then `--cached --jobs 6` on the same tree:
    473 of 473, all cached, 8.2 s (run `30ddba75`). (A second whole run with the package export's timeout raised to 900 s ran 472 of 473 in 5,032 s: the one failure was
    `test_tier_ordering`, which caps every `archive_quick` check at 600 s, so the edit was reverted; the same tree's cache then served all 473.) Reports kept under
    `analysis/_undoc/ep12_talk_rest/`. Open: TD-50 (the package export check over 0.5 of its quick-tier timeout), the DATE5/HOTEL -> TALK extension (37 blocks, owner option),
    CG (WD-21), the hotel return-visit variant, TD-44/45/47/48/49; the place names of the `27c_ev` rows (cosmetic, registry README).
    **Follow-ups (2026-10-05, the advisor's review of `daf4050`..`23c582c`, `analysis/_docs/ep12_talk_followups_spec.md`):** (1) TD-50 is closed
    (`b406bc9`): the package export check moved to the `full` tier at 900 s (the tier follows the registered timeout; 268 s alone, 0.30), the
    open item above is settled. (2) `docs/spec/mes/event_route_classification.md` stopped at revision 32 while each unit regenerated the installed
    file; it now records revision 39 (151/15/1: the eight `G_TALK` scripts moved `system_script` -> `playable_event`, 37 TALK `source_member`
    bindings on 25 entries; the other 106 TALK callees are outside the 167-entry set), and a scratch regeneration reproduced the installed file
    exactly (`5b66f42`). (3) **The 13 `27C_EV.MES` band-less anchors' hop 3 measured, not inherited** (`02ae6a3`, the regeneration below): the two-hop result
    of heroine K's one site had been inherited through the drafter's `DAY_LOOP_CALLERS`; the measurer re-ran all 14 with `resume_hop: "auto"` in
    scratch. Eleven stop in the day loop with no handoff (`definition 12 stopped at definition_step_limit`; heroine K's, the control, the same), `N_TALK`
    stops at a question of the next block's script (`E_TALK`'s, unanswerable in hop 3: two hops), and **`N_TALK1` reaches the `FLOOR5.MES` handoff at
    `27C_EV.MES:83150`** (its block is the entry's last; 6 messages in 5 segments): its row is **three hops and `map_return`**. The drafter keys the
    two-hop rule by the twelve measured anchors (`DAY_LOOP_ANCHORS`, 31 -> 33 tests); the regeneration is one group profile
    (`27c_ev_n_talk_v14.json`, `N_TALK` and `N_TALK1` rebuilt together, audit ok, flow validator 33 checks), catalog revision 40 (the same 681 rows, two
    changed: `n-talk-1` and the group hash of `n-talk-plain`; route outcomes 255 `map_return`, 415 `place_menu`, 11 `chain`), the registry unchanged (same
    `names_fingerprint`, no v4/v5 carry), a package at Core 0.372.0 (only `manifest.json` differs: 681 events from 869 member entries, `4d0ca40d...`; the v6 set was rebound to `b638bd7d...` on 2026-10-06, WD-21 U1 C4), v6 at
    `--jobs 4` (681 of 681 valid): **679 documents differ in `package_binding.package_sha256` alone, `talk-n.1` also in its two profile hashes and one
    `unresolved` line, `talk-n1.1` in `dialogue`, `flow.hops`, `terminals.flow` and the hashes**; route classification moved `catalog_sha256` and `N_PIC.MES`'s
    `27c-ev-n-talk` payload hash alone (checkpoint B1, `faa917f`). Verified: parse check, the Python suites, the two count-pin scenes (`test_event_catalog`,
    `test_event_outcome_vocabulary`), `--tier local --cached --jobs 6` 136 of 136. **Closing proof (no Core or contract change):** `--cached --jobs 6` whole batch on
    `faa917f` (every archive and full check re-ran): run `5865c21a` passed 246 of 473 and **the analysis-group process timed out at its 3,600 s
    (eight of 227 groups left, `todo/code_health.md` TD-51, open then; closed 2026-10-05)**; the same command again (run `f02e7da7`, the process alone) **473 of 473, 3,084 s**; the package export
    315 s of 900 (TD-50). Reports kept under `analysis/_undoc/ep12_talk_followups/`.
  - **Closed 2026-10-05 by the owner** (every scene family of the 2026-09-24 ruling is catalog content: the dates, hotels, promises, album
    scenes, recollection ladders and conversation scripts above, 681 generated rows at catalog revision 40). **Four items stay deferred as
    recorded boundaries or options, not open work of this item**, each where its evidence already lives (nothing here restates or changes a
    measured claim): (1) **CG** moves to **WD-21** as the flag -> picture table (the 13 `?_CG.MES` viewers,
    `docs/spec/mes/gallery_families.md`; the static decode is untracked scratch evidence); (2) **the DATE5/HOTEL -> TALK extension**
    (37 blocks) stays an owner option (`docs/spec/mes/talk_family.md`, "The DATE5 and HOTEL ladders"); (3) **the hotel return-visit variant**
    needs a fourth route per heroine (or a per-variant hop-outcome override, which v14 does not have) and only heroine A is measured (`docs/spec/mes/a_date_flow.md`, "The return-visit variant", and the
    A/B date entries above: reported, not built); (4) **J's hotel** is measured, not declared, and entry 360's native selector is
    unresolved (`docs/spec/mes/heroine_date_flows.md`, "Not established", and the C..L entry above). The place names of the `27c_ev` rows stay
    as recorded in `config/contracts/event_names_v1/README.md` (a provisional title shows the place's file stem; cosmetic, not EP-12 work). **The next work is WD-21**
    (`todo/workspace_distribution.md`; `TODO.md` Execution Order step 4).

- [x] **EP-13 — Playback stills from the surface trace, and one step per spoken line.**
  Done 2026-09-24 (`3080652`, Core 0.362.0): the timeline classifies every
  MMO load by `native_active_surface_value` (surface 8 -> animation source,
  never drawn; surface 2 from `*_PIC.MES` -> standing picture; surface 1, 9
  or 2 from another script -> base picture; no surface value -> the old
  file-name rule, listed in `unclassified_pictures`), and a step is the run
  of message records between two `dialogue_boundary` rows, so `[<name>]line`
  reads as one line (EVENTB03: 90 steps -> 52). The player diffs a step's
  picture state against what is on screen (a background change re-draws the
  standing picture; stepping back is correct). Playback pass over all 142
  rows: pictures 385 of 391 found by role (246 base, 139 standing; the 6
  misses are the unshipped B01/B02/D01/D02 names), animation sources 546 of
  554 resolved and none drawn, voices 1,665, BGM 528. Verified: the timeline
  scene (54 checks), local 134/134, the four group-route shards, the
  fragment catalogs. Headless Godot cannot render frames, so the owner's
  eyes are the visual check (WD-19 sheet items 4-5 and the new item 8). The
  fuller model - replaying the trace's surface copies and AX frames through
  the compositor as one draw-command list - stays recorded above for the
  day animation is taken up.
  Raised 2026-09-24 by the owner from watching playback: the picture shown
  is the AX animation's image (whole, green surround included) while the
  event CG, the background CG and the standing CG are not shown; and a line
  with the protagonist's name shows as three steps (`[`, the name, `]` and
  the line) instead of `[<name>]line`. Two requirements:
  - **MUST - the still pictures.** Cause, measured on EVENTB03's trace: the
    timeline (`content_core/event_presentation_timeline.gd`) takes every
    `mmo_resource_marker` as the current picture and picks the layer by the
    naming script's file name (`*_PIC.MES` -> foreground, else background),
    ignoring where the picture is loaded. The scripts load a scene CG into
    surface 2 (`b03.mmo`, line 4) and then, for the animation, the atlas
    into **surface 8** (`b03an.mmo`, the confirmed AX chain: active surface
    8 -> MMO load -> 7 -> AX load -> binding, 1,351 sites archive-wide); the
    timeline replaces the CG with the atlas. Every MMO trace row already
    carries `native_active_surface_value`. Rule to implement (PR-01 as far
    as stills need it, per the 2026-09-20 target): a picture loaded into
    surface 8 is an animation source and is never a still; the base layer
    is the last full-frame picture (surface 2 from a non-`*_PIC` script, or
    surface 9 shown whole) - an event CG replaces the background and the
    two are never shown together; standing pictures (`*_PIC` loads into
    surface 2) overlay the base with the exact `0x00FF00` key; without
    animation playback nothing of an AX is drawn. Also fix the two drawing
    defects the survey found in `event_player.gd`: a background change
    clears the foreground and only a foreground *name* change redraws it,
    and stepping backwards compares steps n-1 and n-2 instead of the screen.
    The surface census over all 142 rows (`analysis/_undoc/pic_line_census.log`)
    is the evidence for the rule; the fuller model - replaying the
    `surface_operation_omitted` rows (evaluated rectangles and destinations,
    modes 0/1/2) through `KakyuLogicalSurfaceCompositor`, which also gives AX
    frames and CG overlays one common coordinate path (surface 8 atlas
    records copy to absolute `(x, y)` on surface 0; standing rectangles keep
    their own `(x, y)`) - is the next step if animation is ever taken up.
  - **SHOULD - one step per spoken line.** The timeline makes one step per
    message record, so the bracket, the protagonist-name insert
    (`protagonist_name_insert`, a dynamic message) and the rest of the line
    are separate steps. Merge the message records between two
    `dialogue_boundary` rows (the click waits) into one step whose text is
    the concatenation, so `[<name>]line` shows as one line; implement it in
    the shared timeline so every row and the validators' step counts follow
    (the group-routes validator pins step count = message count + closing,
    which becomes lines + closing). The v4/v5 definition dialogue lists keep
    their per-record entries (the remake joins them itself).

- [x] **EP-14 — The Playback timeline presents the media the shared library executes: routine 27's pictures and routine 9's sound effects.**
  Raised 2026-10-11 by TD-56's closing record (`todo/code_health.md`) as "the Playback timeline presents the route trace's
  media only", then **scheduled by the owner's queue of the same day** (WD-10, TD-67, EP-14, then WD-19) and **closed
  2026-10-11 by its whole batch** (below). The unit's specification is `analysis/_docs/ep14_spec.md` (machine-local); the
  documents are [Content tools](../docs/spec/tech/content_tools.md) ("Library media in the Playback timeline revision"),
  [Event Player](../docs/spec/tech/event_player.md) ("A row's `resources`"), [Media references](../docs/spec/mes/media_references.md)
  ("Presented by the instrument (EP-14)") and [Validation checks](../docs/spec/data/validation_checks.md) (gate 3 and the closing
  proof).
  - **Facts as raised (Core 0.377.0).** Gate 3 (the Playback pass of `original catalog group routes`) compared the names the
    played timeline uses with the row's declared `resources`. The timeline is built from the probe's route trace, and the probe
    never put library runner rows into that trace: `_collect_library` appended them to the signature rows only. So the pictures
    and sound effects that the shared `LIBLARY.LIB` routines 27 and 9 execute were never presented. TD-56 (Core 0.377.0,
    catalog revision 43) made the runner reach them and restored **1,093 library items** to the `resources` of 293 rows (251
    distinct: `mmo` 106, `se` 25, `unclassified` 120); the Playback pass found 0 sound effects in all of its runs, and the 1,093
    items were verified by the projector's join, the independent re-join and the tracked-set validator, **not by playback**. It
    was not a regression: before TD-56 the selector-0 `BLACK.MMO` arm was not presented either.
  - **Corrections to the item's text, found by the unit's measurement.** (1) The timeline already mapped **five** media effects,
    not three (`voice_marker`, `bgm_request`, `mmo_resource_marker`, `ax_resource_marker`, `effect_request`): the gap was
    upstream, library rows never reached the trace. (2) The cited line numbers had moved. (3) **Presenting a sound effect does
    not need PR-04's state machine**: the owner's minimal form of 2026-09-20 (sound effects fire-and-forget) is the effect channel
    EP-10 unit 4 built, and a library `effect_request` follows it. PR-04 keeps caller capture and restore, queues, overlap and
    device timing (`todo/presentation_audio.md`).
  - **The rulings.** Q1 (owner, 2026-10-11): the sound effects are included, one unit for both directions. Q2 (advisor): the
    media travel in a **separate, anchored `library_media` list** in the probe result, not as trace rows. Rows in `trace`
    were rejected because the replay writer's `resource_rows` read every media row of `trace`, so library rows would have entered
    the replays and voided the Core-pair rebind (a 64-minute re-projection); an attachment on the anchor row was rejected because
    loop detection truncates `rows` and `trace` back to its mark while the library runs after it. Q3 (advisor): the
    library-coordinate compare **fails the shard**.
  - **What changed (Core 0.377.0 -> 0.378.0; no schema or contract moved).** `KakyuMesRouteProbe` returns `library_media`,
    always present: deep copies of the library trace rows that carry a media effect, each with `source_entry` (`LIBLARY.LIB`, or
    `DEF_MAIN.MES` for a definition the library invoked), `library_call {routine, caller_entry, caller_offset,
    caller_definition_id}` (the MES-anchored coordinate of the shared call, in the walked entry or in the definition body) and
    `trace_index` (the route row the library ran after), without the library runner's `step`; `MEDIA_EFFECTS` is one constant
    the probe, the timeline and `replay_run_media.gd` share; loop detection resizes the list with `rows`. The flow runner copies
    each hop's rows before offsetting `trace_index` by the combined trace's length. `KakyuEventPresentationTimeline.build` takes
    the list as an optional fourth argument, validates it first (fail closed), applies each row at the end of its anchor row's
    iteration through the unchanged row handler (so a surface-2 load from `LIBLARY.LIB` is a base picture by the EP-13 rule),
    keeps media after a trailing `dialogue_boundary` as a closing step, and gives `pictures`, `animations` and `effects`
    entries their `source_offset`, `effects` entries their `source_entry` and library entries their `library_call`. The Event
    Player passes the list and nothing else changed. Gate 3 (tools only): the name-level compare includes the library media; a
    new compare checks each played library medium at its exact `(request_entry, request_offset, entry)` against the row's
    declared items and fails the shard (`PLAYBACK_UNDECLARED_LIBRARY_<CATEGORY>`), reading the entry from the medium's own
    `source_entry` and failing closed when it is missing; a coverage report never fails; the validator records each played
    library medium and its caller coordinate in `playback_library_media_rows`.
  - **The commits.** C1 `ba194132` (the probe, the timeline, the flow runner, Core 0.378.0); the C1 follow-up `09c5595f`
    (`source_entry` on effect entries, ruling 2 below); C3 `f92336dd` (gate 3); C4 `32c35968` (the export and the Core-pair
    rebind); C5 `a9de5086` (documents); this record (C6).
  - **A deviation.** `_run_library` refuses an empty `trace` ("shared routine N has no anchor row") **before the routine runs**,
    not at collection as the unit spec worded it: a refusal then leaves the carried state untouched. Accepted at the C1 review.
  - **C2, run neutrality: nothing a run executes moved.** All **227 replays** regenerated at Core 0.378.0 (840.4 s at
    `--jobs 6`, peak RAM 59.4%) are byte-identical to the ones written before the change (sha256, 227 of 227); the package
    playback check run solo (530.5 s) printed **682 `EVENT` and `SUMMARY:` lines byte-identical** to the 0.377.0 baseline
    (md5 `610063410a6c52ba410829f18ab0c0d9`), its PASS line differing in the Core version it prints alone. That is the
    precondition of the Core-pair rebind: the only path from this Core change to a definition would have been a moved run. One
    validator process of the full replay run crashed at start (exit `0xC06D007F` after 3.2 s, no output) under the six-way
    launch; run alone it passed in 35.1 s and was byte-identical. **An observed, unreproduced start-up failure**: it did not recur
    in C3, C4 or the closing batch.
  - **C3, the stop and rulings 1 and 2.** The 20 group-route shards (274 s) met every expected figure but one: **497 library
    items were presented (401 pictures, 96 sound effects), where the spec expected 481 (386, 95)**, and the stop condition
    fired. Exactly 16 of the 681 rows differed from the planner's default-preset estimate, all in the instrument's favour (12
    promise rows, one `mmo` item each; `eventh02`, `eventh17` and `eventj09`, one `mmo`; `eventc10`, one `se`: 15 `mmo` and 1
    `se`). The cause is the estimate, not the gate: the planner's script read the replays' `executed`, `prefix_executed` and hop
    `executed` offsets but not **`resume.executed`**, the caller's continuation after the callee returns, which the unbroken
    caller path the pass plays includes. With it the estimate equals the measurement in every row (and no row differs); a guard
    checked at closure: the replays' other `executed`-bearing fields, `reentry` and `visits`, are separate probe runs the default
    pass does not play, and reading them would over-count (405 `mmo` against the 401 measured), so the script now reads exactly the
    four fields of the unbroken path. **Ruling 1:** 497 was accepted and the script corrected; neither side was adjusted to
    match. **Ruling 2:** the timeline's `effects` entries carried no `source_entry`, which the exact compare needs, so the clean fix was taken in the
    still-unpushed Core 0.378.0 (`09c5595f`) instead of a tool decision that read a library effect as `LIBLARY.LIB`; the cache
    fingerprints hash file contents (`tools/content_suite/validation_inputs.py`), so no stale hit is possible, and C2 still holds
    (neither the replays nor the playback verdict lines read the timeline).
  - **The result** (default preset of each of the 681 rows; the batch's own shards equal the C3 re-run in every figure): **694
    library media played (556 pictures from routine 27, 138 sound effects from routine 9), all `LIBLARY.LIB`, in 271 rows with
    library pictures and 80 with library sound effects**; pictures found 2,573 of 2,643 (+556, all `base`; the 70 misses and
    gate 2's 184 registered, 0 unregistered unchanged); effects 138 of 138 found, 0 unknown effects; gate 3 name-level **15,705
    compared, 0 undeclared** (15,011 + 694); the library-coordinate compare **694 compared, 0 undeclared**; coverage **497 of the
    1,093 declared library items presented**. Rows, runs and checks stay 681 / 839 / 58,186.
  - **The residue: 596 = 508 + 88.** 508 declared items have no presented form: 483 function-24 `.mmo` loader strings (the twin
    of each rung's marker) and 25 routine-33 dispatch strings, whose native meaning is unresolved. 88 (82 `mmo`, 6 `se`) are
    reached only through non-default variants, because a row's declaration is the union over every measured variant and the
    pass plays one preset per row.
  - **What is confirmed and what is a tool decision** (`docs/spec/mes/media_references.md`). Established: the shared-call record
    at the caller coordinate, the rung selection (TD-56), the marker and `effect_request` envelopes, the active-surface cell the
    marker reads (EP-13), and routine 27's selector-11 rung (`01MA_3.MMO`, the station interior) as a base-surface producer.
    Observed, not individually confirmed: the other 378 routine-27 markers share that rung's shape. Doc defect corrected:
    routine 27's pictures are **place backgrounds, not character pictures**. Tool decisions: a library picture is a still at the
    step of the call, and a library sound effect fires at the step of the call. The original's screen refresh and surface
    lifetime are unresolved (PR-01), so a background may show earlier than the original redraws it; and the player has one effect
    channel that every request restarts, so several routine-9 effects in one step are heard as the last one (the validator still
    resolves each). That is the EP-10 channel's limit, not a claim about the original; overlap and queues are PR-04's.
  - **C4, the binding.** The Core change moves `package_sha256` through the manifest's `content_core_version`: the export
    `analysis/playback_package_ep14` is `fe9bb6bd3256189ab9dd1ff91d75f95d378d8b625aae7e011ba16ccbb849f288`, against
    `0e47e063...`, and **only `manifest.json` differs, in `content_core_version` (0.377.0 to 0.378.0) and `package_sha256`**
    (1,738 of 1,739 files byte-identical). The v7 set was rebound with `--pair core-version` (681 documents and the index, one
    line each; 681 valid, 0 invalid in one process, 9.9 s), the export check reproduces the hash. Nothing new reaches the remake.
  - **The closing batch** (2026-10-11, Core 0.378.0, uncached because Core changed; tree `a9de5086`): the whole `full` tier,
    `--jobs 6`, `--cache-store`, detached, solo, run `8b534111`: **479 of 479 passed, 0 failed, 2,400.5 s**, 10,723.2
    check-seconds (WD-10's batch: 2,546.4 s and 10,715.5), inside the unit's 2,330-2,500 s; then `--cached`: 479 of 479, all
    cached, 9.5 s. The export check printed `package_sha256=fe9bb6bd...`, the playback check passed with 4,749 checks, and the
    group-route shards' summed figures equal the C3 re-run's. The detail (starts, timeouts, memory) is in
    [Validation checks](../docs/spec/data/validation_checks.md).
  - **For WD-19's sheet (item 9): what the owner will now see.** Wherever a route calls routine 27, the place background it loads is
    shown (a base picture at that line), and wherever it calls routine 9 the sound effect plays. Examples from the validator's own
    `playback_library_media_rows`: `original/eventb03/01m-0000788f` (two routine-27 pictures, `01ma_3.mmo` at library offset
    15553, called from `EVENTB03.MES` at 5324 and 6785, steps 37 and 49) and `original/a-date-date5/01m-00002af7` (6 media:
    routine-27 pictures such as `01ca_1.mmo` at 13923 from `DENSHA.MES:220`, and routine-9 effects such as `KSE0067.WAV` at 6839
    from `TRAIN.MES:189`). The picture's timing and the effect's overlap are the tool decisions above. The release suite was
    rebuilt at Core 0.378.0 for the sheet (`analysis/windows-suite-0378-20261011/`, 2026-10-11; item 9 of the batch in
    `todo/manual_verification.md` asks the owner to look for these two rows' pictures and sound effects).
  - **Not taken, and open.** Showing library media in the Analysis view (it keeps the route trace; the library rows stay evidence in
    `rows`); the media of route-invoked `DEF_MAIN.MES` bodies (the member has no presented kind, so it would be dead code);
    presenting the loader and dispatch strings; playing non-default variants for coverage; PR-01's surface lifetime and refresh;
    the EVENTB03 adapter's retirement (TD-56's named decision); and a general declared-but-not-played report over all 18,113
    items (the pass plays one preset per row, so it would measure variant coverage, not a defect; voice and BGM coordinates are not
    in the timeline either). Caller capture and restore, queues and overlap of sound effects stay PR-04's.

## Withdrawn Scope

**EP-04 — Edited contextual Run expansion: withdrawn 2026-09-08.**
The former Event Player requirement is not marked completed. Core 0.303.0/0.304.0
state/message Run evidence remains historical in MW-12 and
`docs/spec/data/mes_contextual_run.md`. General authoring validation stays MW-11,
package coordinate/dependency validation stays WD-21, and original selection
handoff stays WD-09. The mod player is outside this repository's backlog.

## Boundaries

- Phase definitions and order belong to `mes_pipeline.md`.
- Typed instruction meaning and shadow-command prevention belong to
  `mes_analyzer.md`.
- Logical-surface ownership, native AX cadence, A6 input, and audio transport
  belong to `presentation_audio.md`.
- Changed-MES relocation and assembly belong to `mes_authoring.md`.
