# Content Suite Implementation Gap Matrix

Updated 2026-09-20 against the current code, tests and domain trackers (the
previous refresh was 2026-09-08); the Event Player instrument and Local
playback package rows were refreshed 2026-10-11 for TD-56 (catalog revision 43; WD-21 U2's, 2026-10-08, was
revision 41 and EP-12's closure, 2026-10-05, revision 40); the MES Editor, Launcher and Delivery rows, S-11 and the Authored portable delta row were refreshed 2026-10-11 for WD-10 (the mod bundle); every other row and table below is as of 2026-09-20. This maps [suite goals](content_suite_product_goals.md)
and [Event Player goals](event_player.md) to implemented scope and remaining
work. [Root TODO](../../../TODO.md#execution-order) owns priority; domain
trackers own checkboxes. Historical investigation below is not a second
backlog.

**Implemented** means verified at the stated scope. **Partial** means a working
foundation remains short of a final goal. **Open** means no complete user flow
exists. Unresolved original meanings stay explicit; original-engine execution
and full native-effect reproduction are not product completion gates.

The 2026-09-08 scope decision closed Event Player to original playback and
analysis; EP-08 (Core 0.321.0) removed the mixed-input UI. On 2026-09-20 the
owner set the instrument's own final form: a *minimal-presentation event
player* that plays every catalog site through the one shared call frame with
text, voice, BGM and still pictures, no animation and no game runtime
(`event_player.md`, "Final deliverable target"; `todo/event_player.md` EP-10).
Endings are reported in the game's vocabulary (`../data/event_outcome_vocabulary.md`).

## Current Capability and Ownership

| Area | Verified foundation | Remaining product scope | Live owner |
|---|---|---|---|
| Analyzer/decompiler | Authoritative Python Phase 1-4 handoff over all 1,016 entries, zero opaque tails since Core 0.316.0, provenance-preserving Phase 5 output; the whole batch (372 checks) ran green at Core 0.350.0 on 2026-09-19 | Keep the full-corpus gate in the official batch on schema or boundary changes | MA-10/MA-11 complete |
| Compiler backend | Editable lossless IR, no-op rebuild, the seven edit families, the proposed-operation list and operation sequences, semantic diff and independent reopen validators | None: MW-11 closed 2026-09-17 (the address entry closed without exposure by owner ruling) | MW-01..MW-11 complete |
| MES Editor | Analysis, authoring of the seven families and sequences, translation catalog and text policy, workspace publication, contextual Run of stepped bundles, the Definitions tab (a mod's own event definitions as a form or JSON) | None scheduled; the single mod bundle landed as a tool and a headless importer, not as an editor feature (WD-10, 2026-10-11) | MW-12/MW-13 complete |
| Shared Content Core | ARC streaming/writer, codecs, transactional resolver, named workspace/project with `definitions/`, portable provenance, publication locks verified from real processes, the state-cell classifier | Recovery UI when a second mod is merged (deferred); the scope of modified shared entries in an authored export (WD-21 U4, deferred) | WD-12 (deferred), WD-21 |
| ARC Browser | Inventory/filter, single and batch extraction, effective resolution, materialization, comparisons, conservative replacement staging, selection handoff | None scheduled (add/delete/reorder stays out by owner ruling, 2026-09-17) | WD-01..WD-06 complete |
| Image/Animation Editor | MMO and DAT/PAL encoding, ordered A6 editing, shared 640x400 preview, AX inspection, the AX timeline editor and writer (Core 0.333.0/0.334.0) | None in the tool; original-engine display checks deferred by stance | ME-01/04 deferred; ME-02/03 complete |
| Audio Editor | Validation, playback, waveform, references, conversion presets, multi-entry output, batch extraction and report, Event Player handoff | None in the tool; original-engine playback checks deferred by stance | ME-05/06 complete |
| Launcher | Named workspace Create/Open, independent app launch, validation runner/viewer, dashboard, selected-entry handoff | Export and import of the mod bundle (WD-24, unscheduled); recovery UI (WD-12, deferred) | WD-07/09 complete; WD-24 |
| Event Player instrument | 681 generated catalog rows at catalog revision 43 (2026-10-11, TD-56 C5; revision 41 at WD-21 U2, 2026-10-08; revision 40 at EP-12's closure, 2026-10-05), each declaring the media its measured route reaches (`resources`, 18,113 items, the 1,093 `LIBLARY.LIB` items TD-56 restored included) and checked by the Playback pass against what its timeline plays (gate 3; since Core 0.378.0, EP-14, that includes the media a shared library routine executes - the name-level compare plus a compare at each library medium's exact coordinate), all `minimal_playback`: the 142 EVENT-site rows since catalog revision 26 (2026-09-23; 139 and 3 `analysis_only` before), and every other scene family EP-12 brought in (the heroines' promise dates, hotels and promises, all 365 album scenes, the 13 recollection ladders, the conversation scripts; EP-12 closed by the owner 2026-10-05); every one played through the shared call frame from a guard-bounded starting state and presented by the shared timeline (text, voice, BGM, stills, sound effects; Core 0.356.0, 2026-09-21); no per-event code; every EVENT target classified with per-entry evidence; endings in the game vocabulary | The owner's acceptance of the first representatives (WD-19), then golden frames (the CG viewers' flag -> picture table was withdrawn by the owner 2026-10-09, WD-21); the DATE5/HOTEL -> TALK extension, the hotel return-visit variant and J's hotel stay recorded boundaries or owner options (`todo/event_player.md`, EP-12 closing bullet); EP-03 only where a branch state closes a blocker | EP-10 acceptance; EP-03/06 (EP-05 closed 2026-09-23, 375 of 375) |
| Local playback package | v7 with the full membership rule (681 events from 869 member entries, 227 groups bound at Core 0.378.0, fail-closed `membership`/`incompleteness`, and since WD-21 U1 a `media_inventory` and `script_references` block naming every media and script reference with the identity of what the original archives ship and the registered names they do not, the catalog binding in the manifest), the projected event definitions (681 `kakyu_event_definition/v7` documents are the live set, bound to the revision-43 package `fe9bb6bd...` (the Core 0.378.0 export, rebound by EP-14 C4, 2026-10-11; before that `0e47e063...`, the Core 0.377.0 export projected against `3af3779f...` and rebound by TD-56 C5, and `47b1ee8d...` by TD-64 part 2, `ede69366...` by TD-64 part 1, `5ae6aabe...` by TD-57 and `874f53ca...`), with each row's measured `resources`; v3 frozen, v4 and v5 frozen for the 142 EVENT sites, v6 frozen at the WD-21 U1 package `b638bd7d...`) and the mod definition set beside the deltas | The scope of modified shared entries in an authored export (WD-21 U4, deferred) (WD-21 U2 itself closed 2026-10-09, 477 of 477; the library occurrences of the measured `resources` were restored by TD-56); contract acceptance is the remake's backlog | WD-21 |
| Delivery | Delta v9 carries every family and sequence and reconstructs a fresh workspace; the mod bundle (`kakyu_mod_bundle/v1`, 2026-10-11) carries every delta, the translation-only entries and the definition set as one file, built and validated by `tools/mod_bundle.py` and imported into a fresh workspace by `cli/import_mod_bundle.gd`; six release EXE/PCK pairs with native version metadata, rebuilt at Core 0.350.0 for the manual batch | DPI on a real monitor; the Launcher's export and import of the mod bundle (WD-24) (the executable icons are Godot's default, and the clean-Windows check was closed unverified, both by owner ruling on 2026-10-09) | WD-15; WD-24 (WD-14, WD-20 closed) |

## Suite Definition of Done

| ID | Final condition | Current status and remaining work | Owner |
|---|---|---|---|
| S-01 | Inspect supported original entries read-only | Implemented for every format the tools read; under the 2026-09-20 target animation boundaries are reported, not played | EP-10 |
| S-02 | Author supported formats in specialist apps | Implemented: the seven MES families and sequences, AX timeline/writer, audio batch and images | MW-11, ME-02/03/06 complete |
| S-03 | Shared core, resolver, compatibility and workspace | Implemented through ContentWorkspace/Resolver, extended to mod definitions (Core 0.347.0) | complete |
| S-04 | Concurrent/interrupted publication preserves work | Verified from real concurrent, stale, killed and sibling processes (WD-17, 2026-09-18); merging a second mod into an existing workspace stays deferred | WD-12 (deferred) |
| S-05 | Overlay and materialized output resolve identical payloads | Resolver foundations exist; composed output equivalence has no scoped item (WD-11 is a title only) | WD-11/21 |
| S-06 | Preserve unchanged content byte-for-byte | ARC, Phase 6 MES no-op/opaque preservation and the AX writer (ME-03) | complete |
| S-07 | Source-bound, atomic, reopened output | Implemented: every family and stepped bundle is exported, contextually run, carried by delta v9 and reopened (Core 0.330.0) | complete; WD-21 for shared dependencies |
| S-08 | Editor previews/validation and original-reference handoff | Implemented (MW-11, WD-09, ME-05, 2026-09-17) | complete |
| S-09 | Validate authored outputs without Event Player playback | Implemented for every family; the media and script inventory is done (WD-21 U1, 2026-10-06); modified shared entries in an authored export remain (U4, deferred) | WD-21 |
| S-10 | Preserve compatibility labels end to end | Implemented: UTF-8 remake policy, CP932 candidate labels, provenance reports (WD-04) and the launcher dashboard (WD-07) | complete |
| S-11 | Portable mod delta without original payload or local paths | Delta v9 carries every family; the mod bundle (WD-10, 2026-10-11) ships the deltas, the translation-only entries and the definition set as one file with no original payload or path, and imports into a fresh workspace (proven on the original archive by `original mod bundle round trip`); the Launcher's export and import UI (WD-24) and import conflicts (deferred until two mods merge) remain | WD-24; WD-12 (deferred) |
| S-12 | Independent exported applications | Six release apps with native version metadata and Godot's default icons; real-monitor DPI remains. The icons and the clean-Windows check were both closed by owner ruling on 2026-10-09, the latter unverified | WD-15 (WD-14, WD-20 closed) |
| S-13 | Automated safety/structure validation | The whole batch: 372 checks green at Core 0.350.0 (2026-09-19); each unit adds its checks | continuous |
| S-14 | Batched non-automatable verification | The run sheet of 2026-09-19 (six numbered checks on the Core 0.350.0 build) awaits the owner; original-engine checks stay deferred by stance | WD-19 |

## MES Authoring Backend Versus User Flow

Every row of the former table closed: the backend items MW-01..MW-08 and the
user flows MW-09..MW-13 are complete (the last, the Definitions tab's
structured form, on 2026-09-19). The compiled backend is not reopened merely
because a control is missing. Opaque bytes remain preserved and unsupported
transformations remain explicit blockers. UTF-8 overlays are not written as
native MES byte strings.

## Event Player Definition of Done

| ID | Final condition | Current status and remaining work | Owner |
|---|---|---|---|
| E-01 | Caller-derived catalog and classification | Complete: every EVENT target classified with per-entry evidence, every intro and arrival declared, all 142 registry sites documented (EP-07 closed 2026-09-19) | closed |
| E-02 | Material route terminals without debug actions | All 142 rows play from their catalog start to their game-vocabulary ending through the shared call frame (2026-09-23: the 3 former `analysis_only` rows end by continuing into the next event, whose intro their run reaches) | closed |
| E-03 | Stored choices produce caller-visible results | Confirmed choice/result bridges; a promoted row's options select its result route and the run ends at that result's terminal (EP-10 unit 2, 2026-09-20); unresolved native meanings stay labelled | EP-10; EP-03 |
| E-04 | Representative state branches choose correct behavior | Every measured variant is a preset and, since EP-10 unit 3 (2026-09-20), any state the definition's guard accepts can be entered in the guard form and run as a tool-seeded state | EP-10 |
| E-05 | Declared visual composition and animation | Restated 2026-09-20: backgrounds, standing pictures and CGs as stills, an oversized picture whole; animation and camera motion are not played and not claimed. Implemented for every row by the presentation timeline (EP-10 unit 4, 2026-09-20; the hand-authored paths deleted 2026-09-21); library-executed stills (routine 27's place backgrounds, as base pictures) since Core 0.378.0 (EP-14) | closed at the minimal target; PR-02 deferred |
| E-06 | Declared voice/sound/BGM behavior | Restated 2026-09-20: a line's voice with the line, BGM by selector kept across lines, sound effects where a file resolves; no timing equivalence. Implemented for every row by the presentation timeline (EP-10 unit 4, 2026-09-20; the hand-authored paths deleted 2026-09-21); library-executed sound effects (routine 9, fire and forget on the one effect channel) since Core 0.378.0 (EP-14) | closed at the minimal target; PR-04 minimal |
| E-07 | Distinguish completion, return, rejection and handoff | Reported in the game vocabulary since EP-09 (map return with its postlude owner, place menu, chain, not triggered, unresolved) with the code-level terminal beside it; the caller-owned terminals of `12C.MES`/`13C.MES` (16 rows over 7 events at Core 0.323.0) are inside the package since those scripts became analysis-group members - the full export's `external_terminals` list is empty (Core 0.373.0) | closed; WD-21 dependency report |
| E-08 | Playback view without evidence controls on the game frame | Under EP-10 the Playback view shows no omission labels (Analysis keeps them); the frame check stays | EP-06 |
| E-09 | Reproducible Analysis and fail-closed evidence | Implemented; every unit adds bounded contracts | continuous |
| E-10 | Validate original media identity | Closed for this app (Core 0.321.0) | closed |
| E-11 | Reject modified-content execution | Closed for this app (Core 0.321.0) | closed |
| E-12 | Preserve original session on source/reload failure | Closed for this app (Core 0.321.0) | closed |
| E-13 | Supported original routes have appropriate regression | The whole batch ran 372/372 at Core 0.350.0 (WD-18 closed 2026-09-19); every measured route has its group check and, since EP-10 unit 2, the `original catalog group routes` check runs every catalog row through the player (all 142 since 2026-09-21; the per-event validators are retired) | EP-05 |
| E-14 | Unresolved routes are never presented as complete | Closed by the 2026-09-14 ruling: the 120 unresolved rows are analysis-group measured and the catalog shows each row's support level | closed |

## Distribution and Verification

| Contract | Current scope / remaining work | Owner |
|---|---|---|
| Authored portable delta | Delta v9 carries every family and sequence with provenance and rejects source payloads, paths and stale identities; a mod's deltas, translation-only entries and definition set travel as one `kakyu_mod_bundle/v1` file ([Mod Bundle](../data/mod_bundle.md), 2026-10-11); import conflicts deferred until two mods merge | WD-24 (the Launcher UI); WD-12 (deferred) |
| Local full playback package | May contain user-owned original content; inventories every media and script reference its records carry, with the identity of what the original archives ship or the registered absence (`media_inventory`, `script_references`, Core 0.373.0, WD-21 U1) and reports the deferred media extraction (`membership` and `incompleteness` since Core 0.323.0); a full build selects every catalog row (2026-09-21). Modified shared entries in an authored export are not covered (U4, deferred) | WD-21 |
| Independent Windows build | Six release-template apps with isolated Python/Pillow and native version metadata (Core 0.344.0), rebuilt at 0.356.0 (2026-09-21, `analysis/windows-suite-0356-20260921/`); the executable icons are Godot's default (owner ruling, 2026-10-09) | complete (WD-14 closed) |
| Resolution/DPI | The 640x400 logical frame is preserved; headless sizes and DPI factors verified (WD-15, 2026-09-18); a real monitor above 100% is the run sheet's item 2 | WD-15 via WD-19 |
| Large content and interruption | Verified on the largest original archives (WD-16) and from real processes (WD-17), 2026-09-18 | complete |
| Catalog regression | The whole batch at Core 0.350.0, 372/372 (WD-18 closed); EP-05 keeps the record | EP-05 |
| Manual/clean Windows | The run sheet of 2026-09-19 awaits the owner. The clean-Windows check was closed unverified by owner ruling on 2026-10-09; no clean-machine evidence exists | WD-19 (WD-20 closed) |

## Current Dependency Chain

The analysis chain is closed: source-bound inventory -> measured groups for
every site -> projected definitions -> the whole-batch gate. What follows is
the 2026-09-20 target in its five units (EP-10), all landed by 2026-09-21:
generated catalog rows, the wider catalog analysis through the shared call
frame, the guard-derived starting-state form, the shared presentation
adapter, the retirement of every per-event path. What remains of the target
is the owner's acceptance. Authoring, packaging and delivery are
complete except the items named above; work in the separately maintained
remake is not a prerequisite imposed by this matrix.

## Historical Runtime Investigation Reference

The following blocker analysis and P-era investigation chronology are retained
as historical context. Their P identifiers are not live task dependencies.
Current ownership and execution order are the matrices above and the root TODO.
An unresolved native mechanism is a labelled analysis boundary, not by itself
a product gate. No original behavior was newly confirmed by this refresh.

### Event Runtime Blocker Classes

These are the reusable blocker classes that should replace a growing list of
event-specific exceptions:

| Blocker class | Current treatment | Required promotion evidence | TODO |
|---|---|---|---|
| Nested command-`0x0F` call/return | Several confirmed route-specific compositions plus shared runners | Generic call frame and caller restoration across corpus | P2-04 |
| Command-`0x0E` active-string/host activation | Visible handoff boundary; EVENTB03 deferred; EXE audit v56 resolves the receiver/flag lifecycle and exact active buffer, v81-v83 close direct-field and bounded step candidates, and v84-v87 bind configured-root installation/execution/re-entry plus nested flag propagation; v88-v98 exclude bounded application-view, transition, dispatcher, and notification paths; v99-v117 exhaust all field-first aliases across character, command, state-transfer, image, input, media, and selection-presentation paths. v118 binds the final selection guard to the composed-script `+0x44`/`CAI5View +0x0C` popup path, and v119 resolves its leaf calls as window geometry/focus operations. v120 fixes the `CScript::run` search frontier: the handler pointer exists only in five RTTI-bound script-family slot-`+0x10` vtable cells, no direct relative calls target it, and a complete compact same-register slot-`+0x10` scan has 63 calls. Startup, command-`0x0F`, and presentation-subcommand-8 are qualified script routes. v121 classifies four calls through application root member `+0xE4` as `CAI5View` popup-dismiss lifecycle; v122 classifies another four through the view's `+0x6C` `CPopUpMenu` secondary object as `IsWindowVisible` tests; v123 links the already bounded full-frame message-pump `CAI5View +0x10` popup-dismiss call; v124 links the modal-confirm `slot +0x10` result-copy/stop finalizer. v125 promotes the already bounded command-`0x11`, command-`0x1D`, and public-context context-swap calls to direct script-family execution routes. v126 excludes the shared `CAI5Arc`/`CAI5File` handle-close forwarder. v127-v128 initially attributed the monitor-profile and masked-message `0xF120` callbacks to distant application-root script slots; v131 corrects both as `CAI5Display` windowed-mode self-dispatch. v129 removes `0x00408A89` as a conservative scanner false positive after binding the overwritten call register to a `CPopUpMenu` native-handle lookup used by `EnableMenuItem`. v130 binds `0x0040B366` to an RTTI-qualified Ogg file-user terminal-page rewind. v131 also binds `0x0040CAD7` and `0x0040CBAA` to the same RTTI-qualified `CAI5Display` windowed/exclusive mode lifecycle. v132 excludes two Ogg stream-buffer releases, one current-file-position query, and one DirectSound play/write-cursor query. v133 additionally excludes a DirectSound caps query, one Wave buffer release, one Wave play/write-cursor query, and one Wave buffer unlock. v134 excludes four RTTI- and constructor-bound `CAsyncOutputPin` calls that reach `CFileStream` slot `+0x10` only to query total and available source size. v135 excludes the RTTI-bound `CAnimeManager`/`CAnimeBase` self-call that resets every noninactive AX cell to state 1. v136 excludes the generic byte-dispatch case that routes command `0x16` through the three RTTI-bound command manager tables to the already confirmed argument-slot writer. v137 binds the next compact candidate to the RTTI-qualified stack-local `CFile` close path used after three fixed audio-source handoffs. v138 removes `0x00424CEB` as another conservative scanner false positive: its apparent slot-`+0x10` load is a document top coordinate, and the actual call uses the already audited application-root rectangle-refresh slot `+0x14`. v139 binds `0x00429113` to presentation-subcommand-3 selector 2 and the sole registered RTTI-qualified `CAnimeManager`; its slot `+0x10` sets one selected AX cell to state 1. v140 binds `0x00429B31` inside the already bounded receiver dispatcher's selector-0 body to the RTTI-qualified stack-local `CFile` close handler; the command active-string path takes the default edge and cannot enter that numeric selector body. v141 binds `0x00429EC6` inside presentation-subcommand-6's public-context slot-`+0x24` handler selector 0 to the same stack-local `CFile` close path. v142 removes `0x004302F7` as a `CInputName` deactivation/rectangle-refresh scanner false positive. v143 classifies `0x004333CE` as `IGraphBuilder::RemoveFilter` inside the already bounded presentation-subcommand-23 DirectShow stop/release and setup-failure cleanup helper. v144 binds `0x004343C2` to RTTI-qualified `CAdvSelect`/`CItemSelect` native preparation handlers selected by the command-`0x12` record dispatcher, with the hash-bound `LIBLARY.LIB` routine-40 path confirmed on mode 1. v145 excludes two adjacent local-file close calls in script-family file-read/write virtual methods after binding their stack-local receivers as `CAI5File` and `CFile`. v146 excludes the paired fixed-`0x3000` buffer read/write helpers after binding both stack-local `CFile` close calls and cross-linking the read side to the already bounded public-context state reload. v147 excludes the RTTI-bound `CSlot` fixed-`comical.wav` archive-handoff branch's stack-local `CFile` close and confirms the resource in authoritative `bgm.arc`. v148 excludes three RTTI-bound `CEnumMediaTypes` calls that snapshot or compare the shared pin media-type version field through concrete `CRendererInputPin` and `CAsyncOutputPin` base vtables. v149 completes the same native enumerator family by binding Skip, Reset, and Clone version calls. v150 excludes the peer-pin ReceiveConnection call through the RTTI-bound `CRendererInputPin` Connect/media-negotiation chain. v151 excludes `IMediaSample::GetSize()` in the RTTI-bound renderer sample-receive fallback after binding the preferred `IMediaSample2::GetProperties` path. v152 excludes the RTTI- and constructor-bound `CMemAllocator` primary `Free` callback reached by `IMemAllocator::Decommit`, whose paired `Commit` dispatches `Alloc`. v153 excludes the same `Free` callback reached from `IMemAllocator::ReleaseBuffer` when the last allocated sample returns during a pending decommit. v154 excludes `IReferenceClock::AdviseTime` inside RTTI-bound `CBaseRenderer::ScheduleSample`. v155 excludes the final two compact candidates as `CPosPassThru`/`CRendererPosPassThru` automation `GetTypeInfo` and `IMediaSeeking::CheckCapabilities` forwarding; the compact same-register inventory is exhausted. v156 finds three direct-memory calls through `[register + 0x10]` and binds all three to static Ogg/Vorbis backend descriptor tables reached only from RTTI-bound `Cai5OggVorbisDecodeUser` setup/clear methods; no direct-memory jumps or absolute calls/jumps through the five checked script vtable cells remain, while register-separated and longer-range non-compact forms stay explicitly unresolved. These bounded paths contain no proven arbitrary retained-target consumption, MES activation coordinate/context, or caller restore. Direct archive comparison finds `OPEN.MES` but no `MAIN.MES`, retains six stored `43C.MES` handoffs, confirms `DIALOG04.MMO`, and finds the fixed audio names in their authoritative ARC indexes, so none of the fixed paths is promoted as the generic retained-name consumer | Arbitrary retained-target activation coordinate and possible register-separated or longer-range indirect consumers, requiring ownership/caller-chain evidence for target activation and caller restoration | P2-05 |
| Shared library and DEF invocation | Indexed/bounded runners for selected contexts | Generic registration, argument/result and nested return behavior | P2-06 |
| Routine-40 native choice | Event-specific projections, Content Core 0.176's source-bound remake result bridge for 600 exact simple consumers (including all 27 single-row result-1 branches) plus the complete DENSHA gated matrix, or detached cloned preview; EXE audits v41-v44 fix one-based first/second results and their command-10 group registry; v56 fixes Return/Numpad Enter confirmation, Escape's shared finalizer, installed mode-1 Up/Down selected-row navigation, and keyboard-to-mouse cursor recentering through `SetCursorPos`; v57 adds screen-pointer sampling, window-coordinate conversion, and ordered inclusive-rectangle hit classification; v58 identifies hit IDs `0x0100/0x0102` as clamped visible-window deltas `-1/+1`, not row selection; v59 binds the exact two/four-record ID domains to EXE `AREA` resources 142/143 and rules out MMO metadata ownership; v60 proves choice rows instead use the selected control's dynamic zero-high-byte/low-byte visible-row IDs, window-start bounds, host row mapping, and one-based result; v61 binds the left-button latch and modal-ID-0 confirmation to the selected control's one-based result copy and modal stop; v62 separates modal-ID-1's gated helper-return path from its selected-control-confirm fallthrough; v63 fixes the complete `0x0101/0x0103` auxiliary control/presentation-state branches and confirms neither directly returns a result nor stops the modal; v65 fixes exactly three visible rows, clamped non-wrapping Up/Down scrolling, dynamic row-rectangle lookup, and cursor centering; v67 fixes modal ID `1` as a nonterminal fixed-region presentation toggle that does not copy a result or stop the modal; v70 proves DENSHA gate 2461 is zero in newly allocated native state while leaving serialized reload/reset lifetime separate; Event trace v64 retains each group, exposes fixed-key group 0 as the first stage, and keeps 43C's remaining groups available as read-only evidence rather than flattening them | Modal ID `1`'s native visible label, user-facing meanings for IDs `0x0101/0x0103`, scheduler-dependent repeat cadence, post-load/reset DENSHA gate lifetime, and 43C second-stage execution, fallback UI/gameplay meaning, and live reachability | P2-07 |
| Representative opcode coverage | Corpus v39 has no unsupported-opcode, decode, write, or target failures across 133,459 indexed intros; unresolved effects stop under typed native boundary classes, and the exact routine-20 mode-13 form has its own omitted-display-refresh class | New noncanonical forms discovered outside the indexed corpus remain fail-closed and require their own evidence | Completed P2-08 |
| Native presentation records | Explicit omission or event-specific adapter; Content Core 0.167 strictly maps confirmed non-executing MES pixel-operation rows into the shared compositor when presentation colors are explicit, while Content Core 0.192 identifies the exact routine-20 attached-display refresh without executing it | Attached-display backing content, surface ownership/resource producer/lifetime, app wiring, composition order, and remaining consumer semantics | P3-01/P3-02 |
| Whole-event terminal | Catalog v2 plus `kakyu_event_catalog_terminal_contract/v1`; ordinary Playback uses it as the sole completion classifier and representative EVENTB01 reaches its generic final screen; route-specific predicates remain Analysis evidence | Expand full-route catalog regression; never execute unresolved outer-host consumers without new evidence | Completed P2-09; P9-06 |
| Edited MES identity | Exact original hash or narrow overlay contract | Versioned structural interface and relocation validation | P4, P2-10 |

Current status note: the long command-`0x0E` row above preserves the static
investigation history, but its final P2-05 gap is superseded by runtime-trace
v3 and the source-bound terminal audit. All seven target/load/install/
coordinate/ownership/root-replacement obligations are complete. EVENTB03
remains blocked for a different reason: its confirmed zero start reaches 28
dialogue boundaries and a three-definition routine-40 choice at `0x12D2` in a
source-unqualified all-zero sandbox. The original replay confirms visible
row/result `3`, binds it to `LIBLARY.LIB:0x1C95..0x1CA0`, and reaches the later
`MACHI.MES` terminal, while portable caller state and source-bound continuation
remain tracked under P2-07/P2-10. The earlier `0x01C5` return was a generic-skip
artifact and is not route evidence. The separate dormitory first-entry
observation covers `44C.MES` to `43C.MES`, not EVENTB03 presentation.

### P2-05 Investigation Decision

P2-05 is complete. A target-qualified original-runtime capture confirms the
retained target lookup, stream installation, code-relative zero write,
same-owner flag-8 execution, first target consumption, one-based result `3`,
and the complete `EVENTB03.MES -> MACHI.MES` root-replacement chain. The
paragraphs below record the earlier static-search decision and are retained as
investigation history, not as the current product blocker.

Command-`0x0E` promotion is now governed by an evidence contract rather than an
ever-growing byte-distance scan. Completion requires a single reproducible
chain covering retained target identity, host-consumption timing, archive
lookup, stream installation, code-relative intro coordinate, caller/context
ownership, and return-versus-terminal behavior. Static work must use a
bidirectional slice from authoritative command producers and confirmed
load/install/run consumers, including asynchronous root or message-loop edges.

Audit v268 classifies the sole candidate first exposed at the exact 9,000-byte
bound as a cross-return native-object false association and closes that audit
lineage. Unconditional frontier widening stops there. If the static slice is
still inconclusive, Event Player retains the typed
`external_host_activation` boundary and dependent catalog routes remain
partial or blocked until a later batched original-runtime watchpoint trace.
Neither scanning the complete embedded runtime nor failing to find another
candidate is sufficient promotion evidence. This decision changes the
investigation method only; it does not implement activation or weaken any
current fail-closed route.

Audit v269 adds a separate whole-text inventory for the archive loader's
virtual slot `+0x20`. The compact same-register shape yields 36 calls. A
local signed-displacement ownership classifier binds only `0x00407478` and
`0x00408B4B` to the direct `CScript` root-stream loader: the former loads the
configured startup entry and the latter is the fixed mode-`0x40`
`main.mes`/`open.mes` transition. Four active-state public-context calls are
receiver dispatch/replay paths rather than loader calls, and the remaining 30
calls are not promoted without receiver evidence. Host-activation slice v3
therefore narrows the static frontier to a nonlocal or indirect `CScript`
receiver alias entering a three-argument slot-`+0x20` loader call; it still
does not supply an activation coordinate or caller-restoration contract.

Audit v270 and host-activation slice v4 remove five more generic candidates by
ownership rather than distance. Two are already bounded public-context
presentation dispatches to handler `0x00429A70`; one is an overwritten-
register COM interface-query false positive; and two are RTTI/vtable-bound
media position/seeking forwarders. The complete 36-site partition is now two
direct `CScript` loaders, six public-context non-loaders, three native
non-loader candidates, and 25 generic candidates. The P2-05 blocker and next
static edge remain unchanged: a source-backed nonlocal or indirect `CScript`
receiver alias must connect a retained target to the loader filename argument
before activation can be promoted.

Audit v271 and host-activation slice v5 reuse existing exact native receiver
proofs to exclude a paint slot-`+0x14` scanner false positive, selected native
control dispatch, DirectShow pin query forwarding, and media-sample allocator
release. This narrows the 36 compact calls to 2 direct loaders, 6 public-
context non-loaders, 7 native non-loaders, and 21 generic candidates without
changing the P2-05 promotion requirements or runtime boundary.

Audit v272 and host-activation slice v6 bind three more candidates to the
application-owned `CAI5View` window subobject and its checked slot-`+0x20`
`USER32.SetMenu` wrapper. Two calls apply the view-selected menu handle during
display-mode transitions and one detaches it with a null handle before the
exclusive-mode geometry change. The complete partition is now 2 direct
loaders, 6 public-context non-loaders, 10 native non-loaders, and 18 generic
candidates. The P2-05 promotion requirements and `external_host_activation`
boundary are unchanged.

Audit v273 and host-activation slice v7 reuse the RTTI- and constructor-bound
selected-control ownership proof to exclude two additional calls through owner
member `+0x6C`. One conditionally chooses selected-control slot `+0x20` or
`+0x24`; the other uses slot `+0x20` after a surface transition. Both resolve
only to `CAdvSelect`/`CItemSelect` native handlers. The complete partition is
now 2 direct loaders, 6 public-context non-loaders, 12 native non-loaders, and
16 generic candidates. The P2-05 promotion requirements and
`external_host_activation` boundary are unchanged.

Audit v274 and host-activation slice v8 bind compact call `0x004267A2` to a
stack-local `IDirectDraw7` returned by `DirectDrawCreateEx`. The checked IID,
slot `+0x20` call, callback address, `EnumDisplayModes` failure label, and
slot-`+0x08` failure cleanup identify `IDirectDraw7::EnumDisplayModes`; this is
display-mode discovery, not a `CScript` archive load. The complete partition
is now 2 direct loaders, 6 public-context non-loaders, 13 native non-loaders,
and 15 generic candidates. The P2-05 promotion requirements and
`external_host_activation` boundary remain unchanged.

Audit v275 and host-activation slice v9 classify compact call `0x0041828E` as
the already source-bound command-`0x06` manager dispatch. Wrapper `0x00418285`
passes its embedded manager receiver through slot `+0x20`; all three checked
manager vtables resolve that slot to native banked-u8 write handler
`0x00418E90`. A fresh authoritative archive audit retains 28 strict-valid
command-`0x06` runs and 734 byte writes. The complete partition is now 2
direct loaders, 6 public-context non-loaders, 14 native non-loaders, and 14
generic candidates. No arbitrary target or `CScript` receiver is introduced.

Audit v276, host-activation slice v10, and AX-binding audit v2 classify compact
call `0x00429243` as presentation-subcommand-3 selector 7. The checked branch
selects the sole registered `CAnimeManager` and dispatches slot `+0x20`; that
handler visits all 10 x 32 cells and invokes slot `+0x14`, whose exact handler
writes inactive state `0xFF`. The authoritative archive contains 6,754 exact
no-argument selector-7 records across 731 entries. The complete partition is
now 2 direct loaders, 6 public-context non-loaders, 15 native non-loaders, and
13 generic candidates. No arbitrary target, MES filename, or `CScript`
receiver is introduced, so P2-05 remains at `external_host_activation`.

Audit v277 and host-activation slice v11 classify compact call `0x0043FF75`
as the existing choice-modal `DIK_RIGHT` route. The checked modal runner tests
scan code `0xCD`, keeps the modal control as receiver, and dispatches its
vtable slot `+0x20` to right-direction callback `0x00433D00`. The complete
partition is now 2 direct loaders, 6 public-context non-loaders, 16 native
non-loaders, and 12 generic candidates. This native input route has no
`CScript` receiver or MES filename, so the P2-05 boundary is unchanged.

Audit v278 and host-activation slice v12 classify compact call `0x004411DF`
as a second native `CAnimeManager` all-cell invalidation route. Handler
`0x00441160` requires exactly one document consumer at vector offset
`+0x4B578`, takes its first element, and invokes slot `+0x20`; the checked
consumer registration and vtable resolve that call to the same 10 x 32,
nested-slot-`+0x14`, state-`0xFF` invalidator used by selector 7. The complete
partition is now 2 direct loaders, 6 public-context non-loaders, 17 native
non-loaders, and 11 generic candidates. This native document cleanup route
has no `CScript` receiver or MES filename, so P2-05 remains at
`external_host_activation`.

Audit v279 and host-activation slice v13 classify compact call `0x00405857`
as keyboard-device teardown. Startup installs the RTTI-bound
`CAI5KeyManager` at application member `+0xF0`; its initializer creates a
`GUID_SysKeyboard` DirectInput device in manager member `+0x28`, applies the
keyboard data format and cooperative level, and acquires it. Application
shutdown calls the same device's slot `+0x20` `Unacquire`, slot `+0x08`
`Release`, and clears the field. The complete partition is now 2 direct
loaders, 6 public-context non-loaders, 18 native non-loaders, and 10 generic
candidates. This native input lifecycle has no `CScript` receiver or MES
filename, so P2-05 remains at `external_host_activation`.

Audit v280 and host-activation slice v14 classify compact call `0x00407B93`
as the deleting-destructor phase of a document-owned `CMesWnd`. The
RTTI-bound `CAI5Doc` constructor zeros member `+0x225EC`; setup allocates,
constructs, and stores a `CMesWnd` there. Teardown calls its primary-vtable
slot `+0x1C` cleanup, then slot `+0x20` deleting destructor with flag 1, and
clears the member. The complete partition is now 2 direct loaders, 6 public-
context non-loaders, 19 native non-loaders, and 9 generic candidates. This
native window lifecycle has neither a MES archive filename nor the loader's
three-argument call shape, so P2-05 remains at `external_host_activation`.

Audit v281 and host-activation slice v15 classify compact call `0x0040AE32`
as the header stage of an RTTI-bound Ogg/Vorbis decoder open operation. Both
`Cai5OggVorbisDecodeBase` and `Cai5OggVorbisDecodeUser` map virtual slot
`+0x08` to handler `0x0040AE00`. The handler configures the
`Cai5OggVorbisFileUser` backend stored at member `+0x308`, then invokes decoder
slot `+0x20` for page/header work and slot `+0x24` to prime stream state. The
complete partition is now 2 direct loaders, 6 public-context non-loaders, 20
native non-loaders, and 8 generic candidates. This audio-decoder route has no
`CScript` receiver or MES filename, so P2-05 remains at
`external_host_activation`.

Audit v282 and host-activation slice v16 classify compact call `0x0040EDD0`
as `IDirectSoundBuffer::GetFrequency`. Four RTTI-bound Ogg/Wave thread and
notify vtables share slot `+0x48` handler `0x0040EDB0`; it loads the DirectSound
buffer installed at owner member `+0x30` and calls buffer slot `+0x20` with a
frequency output pointer. Their adjacent owner slot `+0x4C` handler calls
buffer slot `+0x44` `SetFrequency`, closing the paired interface contract. The
complete partition is now 2 direct loaders, 6 public-context non-loaders, 21
native non-loaders, and 7 generic candidates. This native audio query has no
`CScript` receiver or MES filename, so P2-05 remains at
`external_host_activation`.

Audit v283 and host-activation slice v17 classify compact call `0x00410638`
as the native `WM_CREATE` callback dispatch for `CAI5View` and `CAI5Wnd`.
Both RTTI-bound owner vtables map slot `+0x04` to the shared message dispatcher
and slot `+0x20` to handler `0x00410850`. The message-1 remap selects the
checked call; the handler loads accelerator resource 7 through
`USER32.LoadAcceleratorsA`, stores the handle at object member `+0x9C`, and
returns success for the dispatcher's zero-result contract. The complete
partition is now 2 direct loaders, 6 public-context non-loaders, 22 native
non-loaders, and 6 generic candidates. This window initialization has no
`CScript` receiver or MES filename, so P2-05 remains at
`external_host_activation`.

Audit v284 and host-activation slice v18 classify compact calls `0x00447BB1`
and `0x00447F2D` as DirectShow pin media-type acceptance. The first belongs to
outbound `AttemptConnection`; the second belongs to inbound
`ReceiveConnection`. RTTI binds the possible self receivers to
`CRendererInputPin` and the base pin subobject of `CAsyncOutputPin`, whose
vtables map slot `+0x20` to the checked handlers. Exact HRESULT zero proceeds
to peer storage and slot `+0x24` media-type installation; all other results
reject the connection. The complete partition is now 2 direct loaders, 6
public-context non-loaders, 24 native non-loaders, and 4 generic candidates.
These native media negotiations expose neither a `CScript` receiver nor a MES
filename, so P2-05 remains at `external_host_activation`.

Audit v285 and host-activation slice v19 classify compact call `0x00448577`
as the renderer media-sample dynamic type check. The properties helper is
called only by the RTTI-bound renderer receive handler, derives
`CRendererInputPin` self at pointer delta `-0x98`, and performs its checked
slot-`+0x38` preflight. When properties flag `0x08` is present, the media type
pointer at offset `+0x34` is passed to pin slot `+0x20`; only exact HRESULT
zero continues. The complete partition is now 2 direct loaders, 6
public-context non-loaders, 25 native non-loaders, and 3 generic candidates.
This native sample negotiation exposes neither a `CScript` receiver nor a MES
filename, so P2-05 remains at `external_host_activation`.

Audit v286 and host-activation slice v20 classify compact call `0x004486C8`
as a downstream DirectShow blocking-capability query. RTTI binds owner handler
`0x00448630` to the `CRendererInputPin` `IMemInputPin` subobject at this offset
`+0x98`. It enumerates the owning filter's connected output pins, obtains each
peer, queries IID `56a8689d-0ad4-11ce-b03a-0020af0ba770`, and invokes the
returned interface's slot `+0x20`, SDK method `IMemInputPin::ReceiveCanBlock`.
The complete partition is now 2 direct loaders, 6 public-context non-loaders,
26 native non-loaders, and 2 generic candidates. This native graph query
exposes neither a `CScript` receiver nor a MES filename, so P2-05 remains at
`external_host_activation`.

Audit v287 and host-activation slice v21 classify the last compact calls
`0x0044987E` and `0x004498EE` as DirectShow `IAMovieSetup` setup-data queries.
Four RTTI-qualified filter owners install matching `IAMovieSetup` secondary
vtables and primary renderer/reader vtables. SDK slots `+0x0C` `Register` and
`+0x10` `Unregister` adjust to the primary object and call slot `+0x20`; every
checked primary cell reaches the same complete constant-null provider at
`0x00411FA0`, causing `S_FALSE` before the filter-mapper path. The complete
compact partition is now 2 direct loaders, 6 public-context non-loaders, 28
native non-loaders, and 0 generic candidates. Compact same-register
slot-`+0x20` classification is exhausted. P2-05 remains at
`external_host_activation` because the nonlocal/indirect `CScript` receiver,
target consumption, activation coordinate, and caller restoration are still
unproved.

Audit v288 and host-activation slice v22 pivot from call-site candidates to the
five checked script-family archive-loader slot-`+0x20` vtable cells. Whole-text
instruction-boundary enumeration finds no direct-memory `call` or `jmp` through
`[register+0x20]` and no absolute indirect transfer through any checked cell.
The empty transfer inventory is hash-bound and mutation-tested. A fresh
read-only original EXE and authoritative `43C.MES` cross-audit retains the six
source producers and anchor
`23d3b73af3d36470b729c1001b4a3e2e8539f10f4a9569485e75176182064f33`.
P2-05 therefore remains at `external_host_activation`, narrowed to a
register-loaded or reloaded nonlocal receiver ownership chain plus the still
missing activation/return contract.

Audit v289 and host-activation slice v23 bind the loader-capable script-family
objects to one static construction graph. All 11 file-backed literals for the
five checked vtables are constructor/destructor lifecycle references. The
complete direct-constructor sets connect application document allocation to
`CAI5Doc`, its composed `CScript` and `CScriptManager`, then the manager's
`CFunc` and `CCommon` bases. The application root stores the document at member
`+0xE8`. The original EXE plus authoritative `43C.MES` anchor is
`1eb80ce99b678d356d9f9c71dd5a3037d86b2a086fba52b9eab08aab40b9dd73`.
This static result does not claim one runtime instance or target activation;
P2-05 remains fail-closed while its next ownership edge is narrowed to an
adjusted script-family receiver derived from application document member
`+0xE8` before the archive-loader call.

Audit v157 supersedes the v156 row's broad "longer-range" remainder with an
exact 32-byte near window. Its eight additions are six register/control-flow
false positives, presentation-subcommand-0's fixed `FLAG%02u` path formatter,
and the `CAI5View` window-subobject `IsWindowVisible` test. None is
`CScript::run`; the remaining P2-05 indirect frontier is now specifically
register-separated or beyond 32 bytes at that audit stage.

Audit v158 preserves the near set and extends the exact conservative window to
48 bytes. Its 14 additions resolve to five DirectInput keyboard `Acquire`
calls, two application-root rectangle refreshes, one native selection-control
slot-`+0x20` call, one current-document slot-`+0x3C` call, and five
control/data-flow false positives. None is `CScript::run`; the remaining P2-05
indirect frontier is now specifically register-separated or beyond 48 bytes.

Audit v159 preserves the 48-byte inventory and extends the conservative window
to 64 bytes. Its 15 additions are nine control-flow crossings, five
data-only/overwritten-register candidates, and one embedded graphics-interface
field followed by actual vtable slot `+0x18`. The two apparent allocation
calls retain the checked `VirtualAlloc` import on their reachable path; the
candidate field loads belong to failure branches that exit first. None is
`CScript::run`; the remaining P2-05 frontier is register-separated or beyond
64 bytes.

Audit v160 adds a byte-conservative 64-byte one-hop register-transfer scan.
Its sole candidate is an unaligned match whose apparent transfer begins in a
`lea` displacement. Exact original-runtime flow instead invokes three
graphics interfaces at owner fields `+0x10`, `+0x70`, and `+0xD0` through
their real slot `+0x1C`; it does not reach `CScript::run`. The remaining
P2-05 frontier is same-register or one-hop dataflow beyond 64 bytes and
multi-hop or spilled indirect calls.

Audit v161 widens the same-register window from 64 to 80 bytes. Its two new
candidates resolve to the choice cursor's `CAI5View` window
`ClientToScreen` call and a return-crossing match into a DirectShow
position-pass-through upstream-pin slot `+0x18` call before an
`IMediaPosition` query. Neither reaches `CScript::run`. The remaining P2-05
frontier is same-register calls beyond 80 bytes, one-hop calls beyond 64
bytes, and multi-hop or spilled indirect calls.

Audit v162 widens the same-register window from 80 to 96 bytes. Its three new
candidates resolve to one application-root rectangle refresh in the choice
region path and two `IMediaSample::SetTime` calls inside RTTI-bound
`CAsyncOutputPin` timestamp adjustment. None reaches `CScript::run`. The
remaining P2-05 frontier is same-register calls beyond 96 bytes, one-hop calls
beyond 64 bytes, and multi-hop or spilled indirect calls.

Audit v163 widens the one-hop register-transfer window from 64 to 96 bytes.
Its sole new candidate is inside the RTTI-bound OGG stream fill handler; the
actual call register is reloaded from owner member `+0x30` and dispatches
`IDirectSoundBuffer::Unlock` through slot `+0x4C`. It does not reach
`CScript::run`. The remaining P2-05 frontier is same-register or one-hop calls
beyond 96 bytes and multi-hop or spilled indirect calls.

Audit v164 widens the one-hop register-transfer window from 96 to 112 bytes.
Its sole addition crosses a window-position helper's return and padding into
the next `CAI5Wnd`/adjusted-`CAI5View` slot-`+0x4C` handler; the actual call
uses the view popup member and checked `CPopUpMenu` slot `+0x4C` native-handle
method. It does not reach `CScript::run`. The remaining P2-05 frontier is
same-register calls beyond 96 bytes, one-hop calls beyond 112 bytes, and
multi-hop or spilled indirect calls.

Audit v165 widens the same-register window from 96 to 112 bytes. Its four new
candidates resolve to a WAVEFORMAT word-copy false positive before
`IDirectSound::CreateSoundBuffer`, a failure branch before the checked
`VirtualAlloc` voice-buffer call, and two return-crossing matches into
RTTI-bound `CMediaSample::Release`/`SetMediaType(NULL)` and a native
interface-copy `IUnknown::AddRef`. None reaches `CScript::run`. The remaining
P2-05 frontier is same-register and one-hop calls beyond 112 bytes, plus
multi-hop or spilled indirect calls.

Audit v166 widens the same-register window from 112 to 128 bytes. Its six new
candidates resolve to three cross-function matches into paired native-control,
ordered-container, and COM-release paths; one freed buffer before an owned
member's scalar deleting destructor; the already bounded `CScript::run`
slot-`+0x14` step call; and DirectShow pin slot-`+0x28` preflight before the
checked peer `ReceiveConnection` call. None is a direct recursive
`CScript::run` receiver. The remaining P2-05 frontier is same-register calls
beyond 128 bytes, one-hop calls beyond 112 bytes, and multi-hop or spilled
indirect calls.

Audit v167 widens the one-hop register-transfer window from 112 to 128 bytes.
The complete set remains the same three routes and the added-route set is
empty, so no new direct `CScript::run` receiver is present. The remaining
P2-05 frontier is same-register and one-hop calls beyond 128 bytes, plus
multi-hop or spilled indirect calls.

Audit v168 widens the one-hop register-transfer window from 128 to 144 bytes.
Its sole candidate crosses two `ret 8` functions and padding before the final
helper reloads an argument interface and calls `IUnknown::Release` through
slot `+0x08`. It is not a direct `CScript::run` receiver. The remaining P2-05
frontier is same-register calls beyond 128 bytes, one-hop calls beyond 144
bytes, and multi-hop or spilled indirect calls.

Audit v169 widens the same-register window from 128 to 144 bytes. Its five new
candidates resolve to `CAdvSelect`/`UnionRect`, a character-stream surface
slot-`+0x08` dispatch, a `CConfig` embedded callback, an adjusted-document
slot-`+0x38` dispatch, and peer `IPin::QueryDirection`. None is a direct
`CScript::run` receiver. The remaining P2-05 frontier is same-register and
one-hop calls beyond 144 bytes, plus multi-hop or spilled indirect calls.

Audit v170 widens the one-hop register-transfer window from 144 to 160 bytes.
Its four additions are a `CAdvSelect` rectangle-to-root-refresh false
dataflow, an earlier OGG stream-region value before the existing DirectSound
`Unlock`, and two return-crossing aliases of the already confirmed
command-`0x1D` `CScript::run` call. The latter call is genuine script
execution, but the candidate MessageBox-caption branch returns before it and
does not reveal a new receiver. The remaining P2-05 frontier is same-register
calls beyond 144 bytes, one-hop calls beyond 160 bytes, and multi-hop or
spilled indirect calls.

Audit v171 widens the same-register window from 144 to 160 bytes. Its four
new candidates resolve to native `IGraphBuilder::QueryInterface`, a
`CMouse` registration callback, application-root rectangle refresh, and a
`CSlot` cursor-hit/selection update after their candidate values are released,
overwritten, or separated by returns. None is a direct `CScript::run`
receiver. The remaining P2-05 frontier is same-register and one-hop calls
beyond 160 bytes, plus multi-hop or spilled indirect calls.

Audit v172 widens the one-hop register-transfer window from 160 to 176 bytes.
Two routes cross command-`0x11`'s returning MessageBox branch and alias the
already confirmed registered-definition `CScript::run`; the third crosses two
native `ret 8` boundaries into the previously bounded `IUnknown::Release`.
No candidate reveals a new script receiver. The remaining P2-05 frontier is
same-register calls beyond 160 bytes, one-hop calls beyond 176 bytes, and
multi-hop or spilled indirect calls.

Audit v173 widens the same-register window from 160 to 176 bytes. Its five
new candidates resolve to a native audio-sink callback, DirectShow pin
media-type check, `IUnknown::AddRef`, `CMemAllocator::ReleaseBuffer`, and
`IReferenceClock::GetTime` after candidate overwrite, branch exit, or function
return. None is a direct `CScript::run` receiver. The remaining P2-05 frontier
is same-register and one-hop calls beyond 176 bytes, plus multi-hop or spilled
indirect calls.

Audit v174 widens the one-hop register-transfer window from 176 to 192 bytes.
The complete inventory remains the same 11 routes and the delta is empty, so
no new direct `CScript::run` receiver is present. The remaining P2-05 frontier
is same-register calls beyond 176 bytes, one-hop calls beyond 192 bytes, and
multi-hop or spilled indirect calls.

Audit v175 widens the same-register window from 176 to 192 bytes. Its five
new candidates resolve to DirectSound volume, application-root rectangle
refresh, `CNormalSelect` composed-script popup presentation, `CTitle` menu-A6
activation, and allocator `IUnknown::AddRef` after overwrite, consumption, or
function return. None is a direct `CScript::run` receiver. The remaining
P2-05 frontier is same-register and one-hop calls beyond 192 bytes, and
multi-hop or spilled indirect calls.

Audit v176 widens the same-register window from 192 to 208 bytes. Its two
new candidates resolve to an expression-token script-stream byte read and an
MSVC C++ unwind non-local-goto action thunk after case exit, register
overwrite, or function return. Neither is a direct `CScript::run` receiver.
The remaining P2-05 frontier is same-register calls beyond 208 bytes,
one-hop calls beyond 192 bytes, and multi-hop or spilled indirect calls.

Audit v177 widens the one-hop register-transfer window from 192 to 208 bytes.
Three new candidates cross a `CAdvSelect` return into adjacent `UnionRect`
argument preparation, one is an unaligned middle-byte decode before a
`CNormalSelect` internal-record push, and one crosses two native wrapper
returns before `IUnknown::Release`. None is a new direct `CScript::run`
receiver. The remaining P2-05 frontier is same-register and one-hop calls
beyond 208 bytes, plus multi-hop or spilled indirect calls.

Audit v178 widens the one-hop register-transfer window from 208 to 224 bytes.
Its sole new candidate is consumed as a rectangle delta before `ret 0x10`;
the later call independently reloads the paired native-control slot-`+0x28`
receiver already bounded by v166. It is not a new direct `CScript::run`
receiver. The remaining P2-05 frontier is same-register calls beyond 208
bytes, one-hop calls beyond 224 bytes, and multi-hop or spilled indirect
calls.

Audit v179 widens the same-register window from 208 to 224 bytes. Its three
new candidates resolve to a public-context record loop before root rectangle
refresh, `Cai5WaveThread` teardown through imported `CloseHandle`, and bitmap
copying before the separately reloaded command-`0x05` dynamic `global_u8`
handler. None is a direct `CScript::run` receiver. The remaining P2-05
frontier is same-register and one-hop calls beyond 224 bytes, plus multi-hop
or spilled indirect calls.

Audit v180 widens the same-register window from 224 to 240 bytes. Its three
new candidates resolve to Ogg file-user source-window configuration after an
earlier function return, mutually exclusive modal auxiliary branches before a
public-context subcommand-7 callback, and DirectShow peer-pin
`IUnknown::AddRef`. Every actual receiver is independently reloaded, so none
is a direct `CScript::run` receiver. The remaining P2-05 frontier is
same-register and one-hop calls beyond 256 bytes, and
multi-hop or spilled indirect calls.

Audit v181 widens the one-hop register-transfer window from 224 to 240 bytes.
Its four candidates resolve to a rectangle value overwritten before a later
`UnionRect` pointer and `ScreenToClient` reload, an exception-chain restore
before a later imported `EnterCriticalSection`, a `CFileStream` size result
before a separately reloaded `IMediaSample::SetActualDataLength`, and two
native wrapper returns before `IUnknown::Release`. None is a new direct
`CScript::run` receiver. The remaining P2-05 frontier is same-register and
one-hop calls beyond 240 bytes, plus multi-hop or spilled indirect calls.

Audit v182 widens the same-register window from 240 to 256 bytes. Its three
candidates resolve to a consumed window-member value before a new root
rectangle-refresh handler, a composed-script view-adapter tail jump before an
independent parser slot-`+0x0C` call, and a returned
position-pass-through-helper argument before `ITypeInfo::Invoke`. None is a
new direct `CScript::run` receiver. The remaining P2-05 frontier is
same-register calls beyond 256 bytes, one-hop calls beyond 240 bytes, and
multi-hop or spilled indirect calls.

Audit v183 widens the one-hop register-transfer window from 240 to 256 bytes.
Its one candidate is a presentation coordinate that is consumed before its
source register is overwritten; a different coordinate is then transferred
to a direct helper, while the eventual virtual call independently reloads the
application root and invokes its checked full-frame rectangle-refresh slot.
It is not a new direct `CScript::run` receiver. The remaining P2-05 frontier
is same-register and one-hop calls beyond 256 bytes, plus multi-hop or spilled
indirect calls.

Audit v184 widens the same-register window from 256 to 272 bytes. The complete
inventory remains the same 145 call sites, so the widened interval contributes
an empty delta and no new direct `CScript::run` receiver. The remaining P2-05
frontier is same-register calls beyond 272 bytes, one-hop calls beyond 256
bytes, plus multi-hop or spilled indirect calls.

Audit v185 widens the one-hop register-transfer window from 256 to 272 bytes.
Its one candidate is a consumed native rectangle-limit value whose source
register is overwritten before a later coordinate transfer. That transferred
coordinate is consumed by a direct helper, its function returns, and a
separate handler reloads owner member `+0x254` before invoking native-control
slot `+0x28`. It is not a new direct `CScript::run` receiver. The remaining
P2-05 frontier is same-register and one-hop calls beyond 272 bytes, plus
multi-hop or spilled indirect calls.

Audit v186 widens the same-register window from 272 to 288 bytes. Its two
candidates resolve to a consumed selection-rectangle coordinate before later
`CAI5View::ScreenToClient`, and a consumed copied-record mode before the
independently entered `state_u16[18]` literal writer rebuilds an adjusted
document slot-`+0x14` receiver. Both candidate owners return before the actual
receiver reload, so neither is a direct `CScript::run` receiver. The remaining
P2-05 frontier is same-register calls beyond 288 bytes, one-hop calls beyond
272 bytes, plus multi-hop or spilled indirect calls.

Audit v187 widens the one-hop register-transfer window from 272 to 288 bytes.
Its one candidate is a saved MSVC exception-chain pointer consumed by the SEH
restore before that function returns. A separate handler's `this` alias also
returns, and only a later worker reloads the eventual call register from the
PE-import-bound `KERNEL32.LeaveCriticalSection` cell. It is not a direct
`CScript::run` receiver.

Audit v188 widens the same-register window from 288 to 304 bytes. Its seven
candidates are consumed native arguments or values whose owners return before
independent selection, Ogg decode, imported `LoadStringA`, DirectInput,
character-renderer, owned-renderer-helper, or imported
`DeleteCriticalSection` receivers are loaded. None is a direct
`CScript::run` receiver. The remaining P2-05 frontier is same-register calls
beyond 304 bytes, one-hop calls beyond 288 bytes, plus multi-hop or spilled
indirect calls.

Audit v189 widens the one-hop register-transfer window from 288 to 304 bytes.
Its one candidate is the already bounded Ogg stream handler's DirectSound
cursor-query function pointer. The function pointer is called immediately;
the apparent transfer comes from a later Lock call, and the final call
register is reloaded from the buffer's confirmed Unlock slot. It is not a new
direct `CScript::run` receiver. The remaining P2-05 frontier is same-register
and one-hop calls beyond 304 bytes, plus multi-hop or spilled indirect calls.
Audit v190 widens the same-register window from 304 to 320 bytes. Its three
new candidates resolve to a spilled-and-overwritten native interface slot
before a document-subobject slot-`+0x44` reload, a stack argument whose owner
returns before an independent COM `AddRef`, and a stack argument whose owner
returns before an independent `IQualityControl` `QueryInterface`. None is a
`CScript::run` receiver. Continue with same-register calls beyond 320 bytes,
one-hop calls beyond 304 bytes, plus multi-hop or spilled indirect calls.
Audit v191 widens the one-hop register-transfer window from 304 to 320 bytes.
Its sole addition starts from the confirmed Wave stream
`IDirectSoundBuffer::GetCurrentPosition` pointer, which is called immediately.
The apparent transfer comes from a later Wave-owner slot-`+0x60` call, its
target is overwritten during arithmetic, and the final call reloads the
buffer's confirmed `Unlock` slot. It is not a new direct `CScript::run`
receiver. Continue with same-register and one-hop calls beyond 320 bytes,
plus multi-hop or spilled indirect calls.
Audit v192 widens the same-register window from 320 to 336 bytes. Its four
additions cross returned native helpers into independently reloaded audio
thread cursor queries, CAI5 window message dispatch,
`IReferenceClock::Release`, and `IMemAllocator::Release`. None is a new direct
`CScript::run` receiver. Continue with same-register calls beyond 336 bytes,
one-hop calls beyond 320 bytes, plus multi-hop or spilled indirect calls.
Audit v193 widens the one-hop register-transfer window from 320 to 336 bytes.
Two additions cross returned heap/message-pump helpers before independently
reloaded window-style or popup-handle receivers. Seven more alias adjacent
renderer methods before the final handler reloads
`IMediaSample::GetTime`. None is a new direct `CScript::run` receiver.
Continue with same-register and one-hop calls beyond 336 bytes, plus multi-hop
or spilled indirect calls.
Audit v194 widens the same-register window from 336 to 352 bytes. Its sole
addition crosses a returned AX rectangle-field owner and unrelated helpers
before an RTTI-bound `CAsyncOutputPin` reloads `CFileStream` slot `+0x14` to
validate alignment 1. It is not a new direct `CScript::run` receiver.
Continue with same-register calls beyond 352 bytes, one-hop calls beyond 336
bytes, plus multi-hop or spilled indirect calls.
Audit v195 widens the one-hop register-transfer window from 336 to 352 bytes.
Its three additions cross a returned `CAdvSelect` rectangle-coordinate owner
before three independent `UnionRect` stack-pointer aliases and an application-
root slot-`+0x14` rectangle refresh. None is a new direct `CScript::run`
receiver. Continue with same-register and one-hop calls beyond 352 bytes, plus
multi-hop or spilled indirect calls.
Audit v196 widens the same-register window from 352 to 368 bytes. Candidate
`0x0041310D` begins at `CBGSelect`'s dynamic hit-table pointer, which direct
helper `0x00411400` consumes before application-root rectangle refresh is
reloaded. Candidate `0x004357CE` begins at a modal surface destination-X
coordinate whose owner returns before the already confirmed public-context
slot-`+0x44` zero-coordinate run/restore call. Neither is a new direct
`CScript::run` receiver. Continue with same-register calls beyond 368 bytes,
one-hop calls beyond 352 bytes, plus multi-hop or spilled indirect calls.
Audit v197 widens the one-hop register-transfer window from 352 to 368 bytes.
One addition is a profile-selected display-effect step width that is consumed
and overwritten before an independently reloaded full-frame rectangle
refresh. The other crosses returned `CPosPassThru` helpers and an HRESULT
alias before an independently loaded `IMediaSeeking::CheckCapabilities` call.
Neither is a new direct `CScript::run` receiver. Continue with same-register
and one-hop calls beyond 368 bytes, plus multi-hop or spilled indirect calls.
Audit v198 widens the same-register window from 368 to 384 bytes. Its three
additions are a returned pixel-loop scalar before DirectDraw cooperative-level
setup, a freed bitmap buffer before the established state-owner callback, and
a returned renderer-constructor argument before resolved
`OLEAUT32::LoadRegTypeLib`. None is a new direct `CScript::run` receiver.
Continue with same-register calls beyond 384 bytes, one-hop calls beyond 368
bytes, plus multi-hop or spilled indirect calls.
Audit v199 widens the one-hop register-transfer window from 368 to 384 bytes.
Its sole addition crosses `CEnumMediaTypes::QueryInterface`, `Release`, and
`Next`: the scanned values are respectively the requested IID and the returned
reference count, while `Next` independently reloads its pin member and invokes
slot `+0x34` for indexed media-type enumeration. It is not a new direct
`CScript::run` receiver. Continue with same-register and one-hop calls beyond
384 bytes, plus multi-hop or spilled indirect calls.
Audit v200 widens the same-register window from 384 to 400 bytes. Its sole
addition crosses the return of a shared audio-parser owner, a constructor, and
a destructor before a distinct `Cai5WaveThread` initializer reloads its own
vtable slot `+0x0C`, allocates a wave buffer, and stores it at member `+0xCC`.
The candidate value cannot reach that call and is not a new direct
`CScript::run` receiver. Continue with same-register calls beyond 400 bytes,
one-hop calls beyond 384 bytes, plus multi-hop or spilled indirect calls.
Audit v201 widens the one-hop register-transfer window from 384 to 400 bytes.
Two additions share one consumed and overwritten presentation-coordinate
owner before separate coordinate reload/transfer paths. Both are consumed by
native rectangle helpers before the application root is freshly loaded for
its full-`640x400` rectangle refresh. Neither is a new direct `CScript::run`
receiver. Continue with same-register and one-hop calls beyond 400 bytes, plus
multi-hop or spilled indirect calls.
Audit v202 widens the same-register window from 400 to 416 bytes. Its first
addition is a deleted and cleared GDI font handle before a returned function
boundary and a fresh public-context character-stream slot-`+0x58` load. Its
second is a temporary stack-object vtable consumed by cleanup before return;
presentation subcommand 7 later reloads public-context slot `+0x28` for its
voice-queue callback. Neither is a new direct `CScript::run` receiver.
Continue with same-register calls beyond 416 bytes, one-hop calls beyond 400
bytes, plus multi-hop or spilled indirect calls.
Audit v203 widens the one-hop register-transfer window from 400 to 416 bytes.
One addition separates mutually exclusive `MessageBoxA` caption and zeroed
string-copy branches before the next function reloads the application
document manager's character-stream slot. The other crosses an already
released/cleared COM member and a fresh `CFileReader` allocation before the
new object reloads its `IUnknown::AddRef` slot. Neither is a new direct
`CScript::run` receiver.
Audit v204 widens the same-register window from 416 to 432 bytes. Its sole
addition is the `IAsyncReader::Request` user-cookie stack argument copied into
an async request record before return. The later call independently reloads
an `IMediaSample` and invokes `SetActualDataLength`; the cookie is not its
receiver. Continue with same-register calls beyond 432 bytes, one-hop calls
beyond 416 bytes, plus multi-hop or spilled indirect calls.
Audit v205 widens the one-hop window from 416 to 432 bytes. Its additions are
a consumed `WM_MOUSEWHEEL` argument crossing independent cursor and registered-
message functions, and a consumed requested IID crossing a
`CheckCapabilities` HRESULT before a separately queried
`IMediaSeeking::IsFormatSupported` call. Neither is a new direct
`CScript::run` receiver. Continue with both search forms beyond 432 bytes,
plus multi-hop or spilled indirect calls.
Audit v206 widens the same-register window from 432 to 448 bytes and finds no
new candidate; the checked 171-call inventory and fingerprint are unchanged.
Continue with same-register calls beyond 448 bytes, one-hop calls beyond 432
bytes, plus multi-hop or spilled indirect calls.
Audit v207 widens the one-hop window from 432 to 448 bytes and finds no new
route; the checked 47-route inventory and fingerprint are unchanged. Continue
with both search forms beyond 448 bytes, plus multi-hop or spilled indirect
calls.
Audit v208 widens the same-register window from 448 to 464 bytes. Five added
distance-only candidates are consumed stack/control values or overwritten
registers before independent critical-section or virtual calls; none is a new
direct `CScript::run` receiver. Continue with same-register calls beyond 464
bytes, one-hop calls beyond 448 bytes, plus multi-hop or spilled indirect
calls.
Audit v209 widens the one-hop window from 448 to 464 bytes. Its sole addition
consumes a requested IID, then crosses an overwritten reference-count transfer
and a separate slot-`+0x1C` cleanup receiver. It is not a new direct
`CScript::run` route. Continue with both search forms beyond 464 bytes, plus
multi-hop or spilled indirect calls.
Audit v210 widens the same-register window from 464 to 480 bytes. Its two
additions are an immediately overwritten owner field before a later slot-0
reload and a consumed helper argument before a separate slot-`+0x1C` reload.
Neither is a new direct `CScript::run` route. Continue with same-register calls
beyond 480 bytes, one-hop calls beyond 464 bytes, plus multi-hop or spilled
indirect calls.
Audit v211 widens the one-hop window from 464 to 480 bytes and finds no new
route; the checked 48-route inventory and fingerprint are unchanged. Continue
with both search forms beyond 480 bytes, plus multi-hop or spilled indirect
calls.
Audit v212 widens the same-register window from 480 to 496 bytes. Its four
additions are consumed state-owner, surface, cursor-helper, or pixel-layout
values before independent slot-`+0x1C`, slot-`+0x28`, slot-`+0x1C`, or
slot-`+0x14` receiver reloads. None is a new direct `CScript::run` route.
Continue with same-register calls beyond 496 bytes, one-hop calls beyond 480
bytes, plus multi-hop or spilled indirect calls.
Audit v213 widens the one-hop window from 480 to 496 bytes. Its sole addition
crosses a consumed requested IID and an `IsFormatSupported` HRESULT before a
separate `IMediaSeeking::QueryPreferredFormat` slot-`+0x18` reload. It is not a
new direct `CScript::run` route. Continue with both search forms beyond 496
bytes, plus multi-hop or spilled indirect calls.
Audit v214 widens the same-register window from 496 to 512 bytes. Its sole
addition is a render-setup stack argument consumed by a prior virtual call
before a separate renderer reloads slot `+0x3C`; it is not a new direct
`CScript::run` route. Continue with same-register calls beyond 512 bytes,
one-hop calls beyond 496 bytes, plus multi-hop or spilled indirect calls.
Audit v215 widens the one-hop window from 496 to 512 bytes. Its two additions
start from the same signed wheel/control delta that is consumed and returned
inside its owner handler. The later transfers are `ShowCursor(0)` and
`ShowCursor(1)` display-count results; a separate caller independently reloads
`RegisterWindowMessageA` for `MSWHEEL_ROLLMSG`. Neither is a new direct
`CScript::run` route. Continue with both search forms beyond 512 bytes, plus
multi-hop or spilled indirect calls.
Audit v216 widens the same-register window from 512 to 528 bytes. Three
additions are DIB/image-layout/stack-allocation values consumed or overwritten
before separate slot-`+0x08`, slot-`+0x04`, or callback-`+0x78` reloads. The
fourth is an unaligned `FF D3` byte pair crossing an `or` and the following
shift instruction, not a decoded call. None is a new direct `CScript::run`
route. Continue with same-register calls beyond 528 bytes, one-hop calls
beyond 512 bytes, plus multi-hop or spilled indirect calls.
Audit v217 widens the one-hop window from 512 to 528 bytes. It adds no routes:
the complete conservative inventory remains 51 routes with the same checked
fingerprint. Continue with both search forms beyond 528 bytes, plus multi-hop
or spilled indirect calls.
Audit v218 widens the same-register window from 528 to 544 bytes. Its sole
addition crosses from a timer wrapper, where the candidate is consumed by
`timeSetEvent`, into a separate DirectShow media-type copy that reloads the
copied `pUnk` field and calls `IUnknown::AddRef`. It is not a new direct
`CScript::run` route. Continue with same-register calls beyond 544 bytes,
one-hop calls beyond 528 bytes, plus multi-hop or spilled indirect calls.
Audit v219 widens the one-hop window from 528 to 544 bytes. Ten additions are
consumed timestamp, width/stride, placement, point, or presentation-effect
values that cross function returns or are overwritten before independent
receiver reloads; one apparent transfer is unaligned inside another
instruction. None is a new direct `CScript::run` route. Continue with both
search forms beyond 544 bytes, plus multi-hop or spilled indirect calls.
Audit v220 widens the same-register window from 544 to 560 bytes. Its sole
addition is a surface lookup coordinate adjusted by `0xD0`, consumed, and
overwritten before either owner return. The later call belongs to a separate
RTTI-bound `CName` handler and reloads that object's own slot `+0x08`; it is
not a direct `CScript::run` route. Continue with same-register calls beyond
560 bytes, one-hop calls beyond 544 bytes, plus multi-hop or spilled indirect
calls.
Audit v221 widens the one-hop window from 544 to 560 bytes. Its three
additions cross returned selection, `IUnknown` query, or `IMediaSeeking`
wrapper functions before independent reloads of `GetPrivateProfileIntA`, an
RTTI-bound renderer interface, or `IMediaSeeking` slot `+0x24`. None is a new
direct `CScript::run` route. Continue with both search forms beyond 560 bytes,
plus multi-hop or spilled indirect calls.
Audit v222 widens the same-register window from 560 to 576 bytes. Its single
addition is a pin-direction value copied by the shared `IPin::QueryPinInfo`
handler before return; the later independent call is
`CMemAllocator::ReleaseBuffer` invoking `IMediaSample::Release` at slot
`+0x08`. It is not a new direct `CScript::run` route. Continue same-register
calls beyond 576 bytes, one-hop calls beyond 560 bytes, plus multi-hop or
spilled indirect calls.
Audit v223 widens the one-hop window from 560 to 576 bytes. Two added routes
share an application-caption candidate consumed by `MessageBoxA` before the
expression-pop helper returns zero. Their later register copies belong to an
expression-vector helper or RTTI-bound `Cai5ComManager` destructor; the final
independent receiver is RTTI-bound `CWinHookList` slot `+0x00`, registering a
new `CAI5Display`. Neither route is a direct `CScript::run` call. Continue both
search forms beyond 576 bytes, plus multi-hop or spilled indirect calls.
Audit v224 widens the same-register window from 576 to 592 bytes. It adds no
candidate: the checked original runtime retains the same 190-call inventory
and fingerprint. Continue same-register calls beyond 592 bytes, one-hop calls
beyond 576 bytes, plus multi-hop or spilled indirect calls.
Audit v225 widens the one-hop window from 576 to 592 bytes. Its four additions
cross an SEH-restoring constructor, an error-caption owner, a critical-section
handler, or an overwritten locale-conversion value before independent
`CItemSelect`, `CScriptManager`-family, COM `AddRef`, or `LCMapStringA`
receiver reloads. None is a direct `CScript::run` call. Continue both search
forms beyond 592 bytes, plus multi-hop or spilled indirect calls.
Audit v226 widens the same-register window from 592 to 608 bytes. Its three
additions begin as cursor X, application-caption, or input-pin argument values
before owner termination or receiver reload separates them from independent
`CWinHookList` registration, `CAnimeManager` deleting-destructor, and COM
`Release` calls. None is a direct `CScript::run` call. Continue same-register
calls beyond 608 bytes, one-hop calls beyond 592 bytes, plus multi-hop or
spilled indirect calls.
Audit v227 widens the one-hop window from 592 to 608 bytes. It adds no route:
the checked original runtime retains the same 70-route inventory and
fingerprint. Continue both search forms beyond 608 bytes, plus multi-hop or
spilled indirect calls.
Audit v228 widens the same-register window from 608 to 624 bytes. Its one
addition is a subcommand-10 surface-vector local that is dereferenced before
the handler returns. The later independent surface adapter reloads the already
bound public-context slot `+0x38`; it is not a direct `CScript::run` call.
Continue same-register calls beyond 624 bytes, one-hop calls beyond 608 bytes,
plus multi-hop or spilled indirect calls.
Audit v229 widens the one-hop window from 608 to 624 bytes. Five additions
cross consumed rectangle-helper, display-effect-step, virtual-clock/timestamp,
or requested-IID values before independent application-root/native-object,
`IMediaSample::SetActualDataLength`, or `IMediaSeeking::GetTimeFormat`
receiver reloads. None is a direct `CScript::run` call. Continue both search
forms beyond 624 bytes, plus multi-hop or spilled indirect calls.
Audit v230 widens the same-register window from 624 to 640 bytes. Two
additions are a sample-conversion outer-row index and a packed native
window-message coordinate. Their owners consume the values and return before
independent window-style and paint-handler receiver reloads. Neither is a
direct `CScript::run` call. Continue same-register calls beyond 640 bytes,
one-hop calls beyond 624 bytes, plus multi-hop or spilled indirect calls.
Audit v231 widens the one-hop window from 624 to 640 bytes. Three additions
cross a consumed application caption, text-composition argument, or critical-
section pointer before independent window-message, application-adapter, and
`EnterCriticalSection` reloads. None is a direct `CScript::run` call. Continue
both search forms beyond 640 bytes, plus multi-hop or spilled indirect calls.
Audit v232 widens the same-register window from 640 to 656 bytes. Three
additions are a consumed record-grid row offset, an application caption used
by `MessageBoxA`, and an exception-handler-table cursor. Their final calls
independently reload public-context slot `+0x44`, `lstrlenA`, or an MSVC unwind
action pointer. None is a direct `CScript::run` call. Continue same-register
calls beyond 656 bytes, one-hop calls beyond 640 bytes, plus multi-hop or
spilled indirect calls.
Audit v233 changes the search axis rather than widening another byte window.
The configured original launcher's checked outer PE has a `0xB000`
file-backed extent and an extraction formula of outer extent plus `0x10000`,
placing the embedded runtime at file offset `0x1B000`. Exact wrapper blocks
and absolute-IAT call inventories bind this layer to temporary-payload
extraction, child creation/resume, one bounded process-memory patch route,
wait, and `WM_CLOSE`; its file-backed sections contain no `.MES`, `mes.arc`,
or `ELFIMAGE` token. No checked outer path hands the retained command-`0x0E`
name to the child, so the wrapper is excluded as the missing activation host.
The remaining P2-05 frontier is inside the embedded runtime or another
indirect owner/caller chain, specifically multi-hop, spilled, or otherwise
indirect retained-name consumption and caller restoration.
Audit v234 partitions the embedded runtime at exact EBP frame prologues and
checks slot-`+0x10` values spilled to negative EBP locals before an indirect
call through the same local. The sole conservative route lies in
`0x0044FD0A..0x0044FDDF`, where direct call `0x0044FD93` replaces the candidate
register and load `0x0044FD98` reads a callback from the returned object's
member `+0x80` before spill/call `0x0044FD9E`/`0x0044FDAA`. It is therefore a
native callback false positive, not `CScript::run`. Continue multi-hop,
non-EBP-local, and object-field spill ownership rather than mechanical window
widening.

Executable audit v64 further narrows both routine-40 rows above: the exact
`0x0101/0x0103` auxiliary branches share document-region preparation, a
temporary document latch, update flag `0x10`, stored-rectangle forwarding, and
current-document embedded-object virtual-slot-`0x3C` dispatch. This does not
promote either hit ID to a choice row or terminal, and their user-facing
meanings remain in the P2-07 gap.

Executable audit v66 narrows the table's remaining “repeat cadence” wording to
wall-clock rate only. The complete modal runner requeries the DirectInput high
bit for each binding on every modal iteration, so held directions are
level-triggered at most once per completed iteration. Its complete message
pump uses `Sleep(0)` while active and `Sleep(30)` while inactive and contains
no local first-repeat delay or fixed interval. Scheduler-dependent elapsed
time, the auxiliary hit-ID meanings, and the other listed gameplay effects
remain in P2-07.

Executable audit v67 closes AREA ID `1`'s source-level effect: the complete
helper toggles a fixed document presentation region or restores the saved
region, refreshes the 640x400 surface/document state, and never copies a modal
result or stops the modal. The table's auxiliary-ID gap now refers to the
native visible label and IDs `0x0101/0x0103`, not to ID `1` being a possible
cancel or choice result.

Executable audit v68 separately narrows P3-01's retained-surface gap. It binds
logical surface 1 as 2688x864 and attributes the two exact native literal
surface-1 activations to RTTI-checked `CBGSelect` and `CNormalSelect`
selection-presentation paths. No checked caller frame connects either object
lifetime to EVENTB14 routine 21, so this is producer-family evidence rather
than native ownership of the projected world-map frame.

Executable audit v69 maps `banked_u16[0][1]` to native active-surface state
`+0x20BA`. Combined with authoritative EVENTB02/EVENTB14 command order and
event trace v65, this closes the AN-MMO-to-surface-8 producer for those two AX
routes. Generic surface lifetime and native cadence remain P3-02 work.

Executable audit v70 closes only the fresh-state side of the DENSHA
routine-40 gate. The original runtime zero-fills the newly allocated state
buffer through offset `0x318F`; `global_u8[2461]` maps to offset `0x0A1D` and
therefore starts at zero. Serialized reload may replace the value, so the
runtime bridge still preserves the current validated 0/1 state rather than
resetting it. Post-load/reset lifetime remains P2-07 work.

Executable audit v81 and the authoritative archive bind the sole complete
mode-13 surface candidate to `LIBLARY.LIB` routine 20. Content Core 0.192
therefore reports its exact six records as `surface_display_refresh` and emits
only `surface_display_refresh_omitted`; the archive-wide core audit v4 retains
11,315 pixel operations, one display refresh, and one empty unresolved
candidate. This closes classification, not the attached backing-content,
lifetime, or final-composition gaps.
