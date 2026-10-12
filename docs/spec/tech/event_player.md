# Event Player Product Goal

This document defines the final product goal and completion contract for the
standalone Event Player. The detailed ARC, overlay, MES, codec, and tool-shell
contracts remain in [Content Core and Independent Tools](content_tools.md).
The editors and shared workspace that produce original-derived inputs are
defined in [Content Suite Product Goals](content_suite_product_goals.md).
Original-event evidence remains organized under the
[MES Analysis Index](../mes/index.md).

## Mission

Event Player is the original-event playback and analysis instrument of this
repository. The owner closed its scope to originals on 2026-09-08; see
[Product roles](product_roles.md#event-player-scope-closed-to-originals-2026-09-08).
A user selects an original event and a supported starting state and follows its
source-qualified dialogue, choices, presentation, state changes and terminal.
Analysis retains source coordinates, traces and explicit unresolved boundaries.

Scope closure does not mean that the instrument or whole event corpus is
complete. Playback and Analysis share the interpreter and isolated sandbox.
Preset experiments over unchanged original bytes remain analysis instruments;
an assumed state is never represented as proven natural scheduler eligibility.

## Content Scope

Both views consume user-owned read-only original content. Archive/entry hashes
and source coordinates bind playback claims to evidence; a byte-identical copy
may retain that identity. Original dialogue and media are the playback inputs.
Added/removed mod events, edited MES, UTF-8 replacement dialogue, authored media
overlays and changed materialized ARCs are outside this application's scope.
Analysis view is not an alternate entry point for modified-content playback.

The original analysis catalog remains the source-derived inventory regardless
of how many events a mod adds or removes. Mod authoring, compiler/semantic
validation, editor previews and package production stay with the suite's
authoring tools. The mod player is the separately maintained `kakyu-remake`,
which consumes playback packages and never original archives.

Core 0.321.0 (2026-09-15, EP-08) enforces this scope at every public entry
point. The MES Editor Run request contract accepts only `original_arc` content
with an `exact_original` interface and identical source/effective entry
hashes; the Event Player rejects any other request before touching the
session, never activates a workspace overlay or a derived ARC layer at
startup, refuses a positional overlay root, applies no UTF-8 replacement
projection when loading an entry (the versioned UTF-8 cache, a decoding of the
original CP932 text bound to the archive fingerprint and entry hash, stays),
and refuses to play or analyse a document whose resolved source is not the
original archive. The Overlay, Hot Reload, Clear Overlay and Derived
affordances and the Derived ARC Layers window are gone from the scene, and the
MES Editor's contextual "Run with catalog preset" route and semantic-proof
dialog are gone with them; its Run action opens original entries only. The
contextual run engine, the authoring binding, the overlay package loader, the
provenance loader and the shared resolver remain with their owning tools.
Versioned implementation narratives below retain earlier evidence; their
edited-content behavior is historical.

## Event Corpus

The completion corpus is derived from the authoritative `mes.arc` caller graph,
not merely from filenames beginning with `EVENT`. Every reachable event-like
callee must be classified as one of:

- playable event;
- duplicate route owned by another catalog entry;
- shared system, map, library, or presentation script rather than an event;
- unreachable stored route with the evidence for that classification; or
- unresolved route that keeps the product incomplete.

The catalog records the original caller, callee, entry coordinate, required
state, principal branches and choices, presentation resources, normal and early
termination paths, caller resume, evidence level, and current support status.
The catalog contains references and fingerprints, not original dialogue or
payload data.

**A row's `resources` (WD-21 U2, catalog revision 41, 2026-10-08).** Every
generated row's `resources` lists the media its **measured route** reaches: the
`presentation.resources` of the row's event definition
(`kakyu_event_definition/v7`, [Event Definition v7](../data/event_definition_v7.md)),
taken from the runs whose dialogue the definition already carries. Each entry is
a `kakyu_event_player_catalog/v8` resource item with exactly four fields, the
shape `content_core/event_catalog.gd` validates (no Core change):

| Field | Meaning |
|---|---|
| `resource_id` | `res-<four-digit ordinal in the row's list, from 0001>`; a slug, unique within the row |
| `request_entry` | the package member whose record requests the medium: an `mes.arc` entry, `DEF_MAIN.MES` among them (`LIBLARY.LIB` is a valid entry, listed since TD-56, see below); a safe leaf |
| `request_offset` | the code-relative offset of that record in the member, an integer >= 0 |
| `entry` | the medium's name as the package inventory normalizes it: upper-case, a safe leaf (`payload_values.is_safe_leaf`) |

The list is sorted by `(request_entry, request_offset, kind, name)`, so **the
ordinal ids shift whenever a row's list changes, and nothing references them**
(only a branch could, and no row has branches). The item has no `kind`, no
`original_entry_sha256` and no `branch_ids`: adding a kind is a catalog schema
change, and a medium's identity (a Tina name has two inventory rows) lives in the
package's `media_inventory`; a consumer that needs the kind joins
`(request_entry, request_offset, entry)` to the definition item or to the
inventory. The list is the union over every measured variant of the row's routes
(a site's prefix, callee, resume, reentry and visits; a flow's every hop), not a
static scan: a medium in the member scripts that no measured run reaches is not
listed. Today: 18,113 items in the 681 rows (2 to 349 per row, median 16), the
file 18.7 MB at revision 40, 21.6 MB at 41 and 21.7 MB at 43. **`LIBLARY.LIB` occurrences were
not listed from 2026-10-08 (owner ruling) until TD-56 restored them at revision 43**: the generic runner
fed every library media ladder selector 0, which would have entered `BLACK.MMO` in 272 rows as a tool
artifact; Core 0.377.0 models the one storage behind command `0x09` and token `0xF6`, and 293 rows now list
1,093 library items (251 distinct: `mmo` 106, `se` 25, `unclassified` 120; the sound effects are the first
`se` items any row declares), beside the genuine `DEF_MAIN.MES` items (12 distinct, 124 listed in 59 rows).
The Playback pass of
`original catalog group routes` fails the shard on any medium its timeline plays
that the row does not declare (gate 3,
[Validation checks](../data/validation_checks.md)).

**Library-executed media are presented since Core 0.378.0 (EP-14).** The Playback pass presents the
pictures and sound effects a shared `LIBLARY.LIB` routine executes, at the line where the script calls the
routine: routine 27's pictures are base pictures (the EP-13 surface rule classifies a surface-2 load from
`LIBLARY.LIB` as the base picture), and routine 9's sound effects fire and forget through the effect channel
EP-10 unit 4 built. Each medium keeps the library's own coordinate and names the MES-anchored caller
coordinate of the shared call that ran it (`library_call`). Two limits are the instrument's, not claims about
the original: the original's screen refresh and surface lifetime are unresolved (PR-01), so a background may
show earlier than the original redraws it; and the player has one effect channel that every request
restarts, so several effects in one step are heard as the last one (the validator still resolves each
separately). Overlap, queues and caller capture and restore stay PR-04's
(`todo/presentation_audio.md`). The default-preset Playback pass played 694 library media (556 pictures,
138 sound effects) in 271 rows with library pictures and 80 rows with library sound effects.

Gate 3 sees them twice: the name-level compare includes them (15,705 names compared, 0 undeclared), and a
compare at each library medium's exact `(request_entry, request_offset, entry)` against the row's declared
items (694 compared, 0 undeclared; the same name declared at another offset, or at the same offset under
another member, fails the shard). A coverage report beside it never fails: of the 1,093 declared library
items the pass presents 497 (401 pictures, 96 sound effects). The other 596 are 508 `unclassified` loader
and dispatch strings, which have no presented form, and 88 declared only through other measured variants,
because a row's declaration is the union over every measured variant while the pass plays one preset per row
([Validation checks](../data/validation_checks.md); the evidence in
[Media references](../mes/media_references.md), "Presented by the instrument (EP-14)").

Completeness does not require exhaustively running every mathematically possible
sandbox state. It does require coverage of every confirmed event start, every
stored user choice, every materially different date/time/location/resource
branch, and every normal or early termination path represented in the original
event corpus.

## Playback Contract

For a supported event, ordinary playback must be able to perform all applicable
parts of the original route:

1. establish a validated caller and starting state;
2. enter the callee at the confirmed coordinate;
3. evaluate original expressions, conditions, and state transfers;
4. execute shared-library, DEF, and nested MES calls with caller restoration;
5. present original dialogue, including dynamic-name insertion;
6. present choices and return the selected result through the confirmed caller
   interface;
7. select, decode, place, compose, and animate background and foreground media;
8. request, play, retain, replace, and stop voice, sound, and BGM as directed;
9. apply event state and completion writes only to the isolated session;
10. execute confirmed caller-owned post-event dialogue, audio, and presentation;
11. distinguish normal completion, early return, rejection, and unresolved
    outer-host handoff; and
12. display an unambiguous event-ended result only at the confirmed terminal.

The nested-call foundation is now split from route-specific playback.
Content Core `0.154.0` can stop on a dialogue inside an explicit command-`0x0F`
callee, return a source-bound continuation, and later restore the LIFO caller
coordinate plus temporary argument/evaluator context after callee return.
Content Core `0.156.0` adds `kakyu_event_player_caller_frame/v1`. Event Player
now uses that common source-bound frame for EVENTB01, EVENTB02, EVENTB14,
EVENTB15, EVENTD01, EVENTD02, EVENTD03, EVENTD08, and EVENTD14. Before Start mutates presentation
or sandbox state, the controller rereads the exact caller, verifies the command-
`0x0F` target and physical resume, and binds both caller and callee fingerprints.
The frame survives dialogue, choice, native/DEF adapters, callee return, optional
caller BGM, and final handoff while retaining temporary argument/evaluator
context. EVENTB15 exercises the direct 11M.MES-to-MACHI.MES form with no caller
BGM stage. EVENTD08 retains the same frame through its source-bound 12C.MES
restore prefix, audited D_PIC.MES presentation adapter, caller dialogue, and
final MACHI.MES handoff. A changed frame or source fails closed and cannot fall
through to an older event-specific continuation. Frame-less postlude/handoff
continuation kinds no longer exist: an exact return offset may be inspected in
Analysis, but it cannot reconstruct discarded caller identity, temporary
arguments, or evaluator state. EVENTB14 keeps the 44M frame
active across its explicit cloned projections, but does not invent a live
return: exact caller resume `0xC925` requests BGM and reaches another caller-
owned routine-40 choice at `0xFFBA`. That choice stays blocked under P2-07.
Unresolved host
activation, and generalized shared-library/DEF frames remain separate work.

Content Core `0.157.0` begins the latter work with
`kakyu_mes_registered_definition_continuation/v1`. A user-visible dialogue
inside an explicitly mapped DEF can now retain source-bound root and nested DEF
frames, command-`0x11` call/resume coordinates, and temporary context for a
later safe resume. Changed root or registered body bytes, missing definitions,
and shifted body/caller coordinates fail closed. Content Core `0.158.0` adds
the equivalent source-bound continuation for a dialogue reached directly in a
root or nested `LIBLARY.LIB` routine. It retains the exact command-`0x1D` call
chain and skips other bounded native presentation records without skipping a
confirmed dialogue trailer. Event Player now maps that library boundary to its
normal `Continue` control. Before resuming it revalidates the low-level library
frame and a controller-level binding to the selected MES entry bytes, code
size, and physical caller resume; a changed library or MES caller fails closed
without executing the remaining library body or caller. Registered-DEF
invocations backed by the audited startup registry now use the same UI model:
the first `Continue` enters the explicitly selected command-`0x11` body, a
dialogue inside that body creates the source-bound v1 continuation, and the
next `Continue` finishes the active DEF frames before restoring the exact root
MES coordinate. The controller binds the root MES bytes, code range, address
table, and registry snapshot; changed root or DEF bytes fail closed before
restoration. Native streams inside the generic DEF path remain stop boundaries
rather than being consumed as dialogue. Content Core `0.159.0` composes a
dialogue inside a registered DEF called from a library routine: library
continuation v2 embeds the active DEF continuation and restores DEF, current
routine, outer routine frames, then the selected MES caller in order. Event
Player consumes the mixed frame through the same source-bound `Continue` path.
These generic controller foundations complete P2-06 but do not by themselves
promote a catalog route.

During development, an unknown opcode or native boundary continues to fail
closed. Final supported playback may cross that boundary only through a generic
interpreter implementation, an executable- and archive-backed native
compatibility adapter, or a versioned event-family adapter that has equivalent
evidence and regression coverage. A normal route that still requires the user
to enter an offset, choose a debug continuation, or accept an unsupported-op
stop is not complete.

## Fidelity Target

The target is behavioral and presentation equivalence, not a binary-compatible
reimplementation of the original executable.

The following must agree with the supported source contract:

- dialogue order and text source;
- choice availability, selection, and branch result;
- state conditions, writes, completion, and caller restoration;
- resource selection and layer role;
- visible image placement, transparency, crop, and composition result;
- animation frame order and perceptually equivalent cadence;
- voice and BGM selection, ordering, retention, and stopping; and
- normal versus early event termination.

Godot may use different rendering, scheduling, audio-device, and decoding
internals from DirectDraw, DirectSound, and the original native runtime. Small
timing differences are acceptable when they do not change event behavior or the
perceived presentation. Original bugs may be preserved, corrected, or exposed
as a compatibility option only after the choice is documented.

## Playback and Analysis Views

### Playback view

Playback view is the default event-watching experience. The fixed logical
`640x400` game frame contains only event presentation and game-facing input.
Debug status, hashes, offsets, native-boundary explanations, and trace tables
must not cover that frame. A user can browse the event catalog, choose a preset
or edit supported starting state, play, make choices, and reach a clear ending.

### Analysis view

Analysis view retains explicit entry/coordinate starts, step and continuation
controls, trace, calls, messages, state diff, resource evidence, unsupported
boundaries, and source-confidence labels. It may expose narrower detached or
tool-seeded projections that are not promoted to ordinary playback. Analysis
actions remain visibly distinct from original caller input.

Both views use the same runtime objects. Analysis view must not become a second
format implementation or a way to bypass playback validation.

The current standalone UI implements this as one session-preserving view-mode
selector. It starts in **Playback**, where the MES source/address panes,
explicit intro coordinate, bounded-run and fragment controls, resource
diagnostics, sandbox editor, result tables, and debug status line are hidden.
The Event Catalog, fixed game frame, confirmed Start/Continue actions, and BGM
control remain available. **Analysis** restores those exact controls without
reopening content or replacing the resolver, MES runner, sandbox, selected
document, continuation, or current presentation. Selecting **Select MES source
in Analysis** from the catalog intentionally changes to Analysis after choosing
the source.

For a playable catalog record, **Play catalog preset** validates the
catalog's source profile against the open content set, resolves the exact
effective MES callee, creates a fresh isolated sandbox, applies the selected
`original_branch` preset, and begins at the confirmed start coordinate. The
`kakyu_event_catalog_play_request/v4` request declares its execution model.
Existing `nested_call` requests carry the original caller entry fingerprint,
command-`0x0F` dispatch coordinate, and physical resume coordinate plus a deep-copied
`kakyu_event_catalog_terminal_contract/v1`. The terminal contract orders exact
callee-return, caller-postlude, completion, early-end, rejection, and unresolved
host stages. Content Core can also issue a caller-free `root_replacement`
request from an exact command-`0x0E` activation and confirmed callee-owned
replacement terminal. Event Player now resolves that request against the open
content set, checks the cataloged `mes.arc` fingerprint, rereads and decodes the
exact command-`0x0E` `[dispatch,end)` source record, checks its zero-coordinate
target and target hash, and resolves every required-entry hash. It then stops at
an exact product adapter. The current adapter accepts only EVENTB03, starts a
caller-free zero-coordinate session, crosses its hash- and record-bound setup,
and reaches the first original dialogue at `0x039F`. Ordinary catalog Play stays
blocked until the confirmed result-3 suffix and root terminal lifecycle are
connected. Malformed or changed sources are rejected before changing the
sandbox or current presentation. The caller/root activation records are
metadata only and contain no MES payload. The Playback controller
then crosses only already-confirmed internal library,
native-omission, and caller-continuation boundaries until it reaches dialogue,
a choice, or a confirmed terminal. It never exposes the debug Continue action
for those internal transitions. A boundary that is unknown, makes no progress,
or exceeds the bounded transition limit stops fail-closed and directs the user
to Analysis. Switching to Analysis preserves the live catalog session;
switching back resumes the same safe automatic traversal.

A runtime `script_return` is never sufficient to declare an event complete.
The catalog terminal matcher also requires the owning entry, code-relative
offset, runtime status, required isolated-state assertions, and named handoff
target. Reaching a confirmed caller-owned `MACHI.MES` marker can close the event
while still recording that the outer native host consumer was not executed.
Playback matches the terminal copy carried by its play request only after
checking that it is byte-for-byte equivalent to the contract derived from the
still-loaded catalog. An altered request therefore cannot redefine completion.
The controller treats matched callee-return and caller-postlude stages as
internal continuation points and uses the catalog's generic **Event complete**,
**Event ended early**, or **Event rejected** presentation only for an exact
route-ending stage. From Content Core `0.165.0`, ordinary Playback no longer
consults a route-specific completion predicate; those predicates and their
offset-rich strings remain Analysis evidence only. An unmatched result with no
safe continuation still stops unresolved, and a mismatch at a cataloged
terminal coordinate stops before executing its continuation.

### World-map presentation phases

Event Player distinguishes a world map used as an event background from an
interactive movement-map session. During a `world_map_monologue`, the effective
HHMM-selected map is rebuilt from the effective `MACHI.MPC` base/overlay tile
grid and DAT/PAL atlas, then frozen as a 640x400 camera viewport. Existing
character and AX layers are cleared when the audited route requires it, and all
map, destination, and movement input remains locked. Dialogue advance is the
only game-frame input accepted. Reaching a later `MACHI.MES` terminal proves the
stored handoff target; it does not retroactively make the already-visible frame
interactive.

EVENTB14's source-qualified phase is more specific: post-return dialogues one
through three restore the HHMM-selected `18M` children's-park location behind
the B_PIC standing/expression layers and clear the earlier B14 event CG. After
the exact routine-21 boundary, dialogues four and five switch to MACHI event /
entrance preset 4: camera cell `(80,32)`, actor cell `(95,40)`, original CHARA
frame 1 at viewport pixel `(240,128)`. Exact original and edited effective map
inputs both use the shared ARC-backed MPC compositor with the same crop and
actor contract; extracted full-map PNG files are not accepted as presentation inputs.

An interactive `return_to_world_map` requires a separate, source-bound host
activation contract: effective map resources, player/camera position, pending
state effects, and the confirmed native receiver or equivalent remake
transition must all validate before control is enabled. Until that contract is
implemented, Event Player retains the frozen world-map frame at completion and
labels the exact handoff as reached but not executed. Effective MPC and DAT/PAL input
still follows overlay, validated derived ARC, original ELFIMAGE, then fallback
priority, so Image ARC Editor changes can be previewed without weakening this
input boundary.

Command-`0x0E` is no longer a generic unresolved host-activation boundary.
The target-qualified runtime-trace v3 binds retained target, archive lookup,
stream installation, code-relative coordinate zero, same-owner execution, and
first target consumption. Its final EVENTB03 replay records one-based choice
result `3` and then follows `MACHI.MES` through the complete same-owner
command-`0x0E` load/install/coordinate/flag chain. The source-bound terminal
audit classifies that chain as `target_root_replacement` and completes all seven
P2-05 obligations. The authoritative target has matching successor envelopes
at `0x1BB6`, `0x26F4`, and `0x3D46`. Terminal-audit schema v3 joins the
captured one-based result to the authoritative `state_u16[21]` dispatch chain
at `0x12DC`, `0x1BD2`, and `0x2710`, fixing row 3 to the exact
`EVENTB03.MES:0x3D46..0x3D53` successor envelope and common return `0x3D5D`.

This does not make every command-`0x0E` route playable. EVENTB03 begins at the
confirmed zero coordinate and its corrected source-unqualified zero-state
analysis reaches routines `28/21/28`, 28 dialogue boundaries beginning at
`0x039F`, another routine 21, and a three-definition routine-40 choice at
`0x12D2`. The earlier `0x01C5` no-dialogue return was caused by applying the
generic native-stream skip policy to ordinary statement-separated commands;
it is rejected as a tool artifact. The result-3 deletion matrix now narrows the
outer structural state to `state_u16[4]=6` and `state_u16[19]=1825`;
removing either changes both later routine-25 traces, while removing observed
`[7]` or entry-overwritten `[8]` does not. Event Player still keeps the route
Deferred until the seven bounded native character spans have a playable
product contract. The source-qualified `captured-result3-original` catalog
preset transactionally applies `[4]=6`, `[7]=413`, and `[19]=1825` to a fresh
isolated startup state and reproduces the exact result-3 terminal. Exact nested
replay adds MMDD `state_u16[7]=413` to the presentation minimum, reaches
`B_PIC.MES:0x035B/0x0360` routine 22, composes original `B1.MMO` with
`BAN.MMO`/`B.AX` low-affection column 1, and returns at `0x0759`. The root-
replacement terminal and row-3 source offset are confirmed. The choice result
itself is source-bound to the first routine-40 native record
`LIBLARY.LIB:0x1C95..0x1CA0`; the static result dispatch binds it onward to
`EVENTB03.MES:0x3D46`. The transactional preset does not execute the seven
earlier omitted native character spans. The
zero coordinate is recorded in the catalog but is not exposed as an ordinary
Start anchor by itself.

Ordinary Playback may cross a host handoff only after those native obligations
and the route-specific state, caller continuation, terminal, and presentation
contracts revalidate against the effective ContentSet. A confirmed activation
does not erase independent blockers, and a source filename never authorizes an
invented state preset or caller frame.

This increment promotes six routes to `complete_playback`. EVENTB02,
EVENTB14, and EVENTD02 remain `partial_playback` because their independent AX
animation, routine-40 native presentation/effects, and native-command gaps are still tracked
separately. Their catalog Play actions remain useful but do not imply those
limitations are resolved.

Since 2026-09-21 (EP-10 unit 5, Core 0.356.0) those statuses no longer exist:
every catalog row is generated from its analysis group and carries
`minimal_playback` (its default option reaches a game-vocabulary ending) or
`analysis_only` (a dependency stop or an undeclared continuation), and the
caller-frame, root-replacement and nested-call paths described above are
retired in favour of the one shared call frame. The paragraphs above are the
record of how the hand-authored rows were qualified.

Routine-40 input evidence is narrower than full native UI support. EXE audit
v66 confirms Return/Numpad Enter as the shared confirm callback and binds
Escape plus the four DirectInput direction scan codes through the installed
modal vtable to concrete functions. Escape reaches the same mode-gated
finalizer used by a confirmed Enter path; the direction wrappers forward four
exact integer pairs to a parent virtual method. Its bound mode-1 control proves
that Up/Down move the selected row and recenter the native cursor through the
original `SetCursorPos` path; Left/Right remain on the parent
update/notification path. Event Player may mirror those confirmed keyboard
affordances. The same audit now follows `GetCursorPos` through window-coordinate
conversion into an ordered 10-byte inclusive-rectangle hit table and stores the
first matching word ID for confirm. IDs `0x0100` and `0x0102` are now fixed as
`-1/+1` navigation of a visible-window start clamped to `0..count-1`; they do
not select a choice record. Actual choice rows use the selected control's
dynamic hit table: a zero high byte and low-byte visible-row ordinal combine
with the window start, pass total-count bounds, map through the mode-0 host row
lookup, and become one-based. V62 additionally binds `WM_LBUTTONDOWN` to the
application key object's left-button latch and proves that modal `AREA` ID `0`
dispatches the same confirm callback, copies the selected control's one-based
result, and stops the modal; `WM_LBUTTONUP` clears the latch. Event Player may
therefore mirror left-click confirmation for its remake bridge without calling
the modal ID a choice row. ID `1` is conditional: with bytes `+0x3DF`,
`+0x3E0`, and `+0x3E1` all zero, it calls helper `0x00435850` and returns
without directly copying a modal result or stopping the modal; otherwise it
falls through to the selected-control confirm path. Event Player must not
flatten those two paths into cancel or a separate choice row. V64 also fixes
the complete primary-table `0x0101` and `0x0103` callback branches. They run
native control/presentation-state calls and return without directly copying a
modal result or stopping the modal. `0x0101` conditionally updates bytes
`+0x3DC/+0x3E0`; `0x0103` clears `+0x3DC` before its helper sequence. Event
Player may classify these as auxiliary actions. Their common exact helpers
prepare a document region at `0x00434950`, run the `0x00435730` update sequence,
and tail-dispatch current-document virtual slot `+0x3C` through `0x0043FFC0`.
The update temporarily sets/restores document byte `+0xB7A`, clears then sets
flag `0x10` at `+0x20BC`, and forwards a rectangle derived from document words
`+0x20C2/+0x20C4/+0x20C6/+0x20C8`. It must not assign a visible
meaning. It must still not infer Escape's result, ID `1`'s visible label,
`0x0101/0x0103` user-facing meanings or other callback effects until
those paths are separately source-bound. V65 fixes the selected-control list
itself as exactly three visible rows. Up and Down scroll the `+0x30` window
start one row only at visible ordinal 0 or 2 and only while another row exists;
the absolute ends remain selected and never wrap. The chosen row's dynamic
10-byte rectangle is looked up by ID through `0x00411450`, and its midpoint is
used for the existing keyboard-to-mouse cursor synchronization. Event Player
may mirror this three-row, clamped, non-wrapping behavior in the remake bridge,
and v66 fixes held directions as level-triggered once per completed modal
iteration. The active-window host pump uses `Sleep(0)` and contains no local
first-repeat delay or fixed interval; an inactive window uses `Sleep(30)`.
Event Player may therefore preserve the original per-iteration policy, but it
must not advertise an invented fixed millisecond repeat rate because the
wall-clock cadence remains message-pump and scheduler dependent.
V67 closes AREA ID `1`'s source-level effect without inventing its label. The
complete 1,339-byte helper toggles mode byte `+0x43D`, switches the document to
rectangle `(34,316)-(578,376)` or restores the rectangle saved at `+0x414`,
and refreshes the 640x400 surface/document state. It does not copy a modal
result or stop the modal. Event Player may therefore classify it as a
nonterminal presentation-region toggle, but must not expose it as cancel,
back, or a choice row; the original visible label remains Analysis-only
unknown.

Content Core `0.194.0` and Event Player now expose a source-bound disposable
analysis path for an exact multi-group routine-40 registry. It is deliberately
separate from the remake result bridge. Group 0 is the first stage; its
one-based row opens the same-numbered retained group, and a second-stage row
may be inspected only through the cloned DEF-body runner. An explicitly empty
group reports the confirmed native `0xFFFF` list result and stops. The path
revalidates the bytecode, every body fingerprint, ordered selectors, counts,
and source identity before either step. It uses clamped non-wrapping movement,
never writes slots 21/13, never resumes the stored result consumer or caller,
and cannot be started as a playable 43C event while command-`0x0E` host
activation remains unresolved.

Content Core `0.195.0` / grouped contract v2 additionally shows the exact
stored post-result coordinate for the currently highlighted second-stage row.
An explicit branch is displayed as `consumer 0x...`; an available row with no
explicit secondary comparison is displayed as an unresolved common fallback.
This is graph evidence outside the 640x400 frame, not a Continue action. The
tool revalidates it against the effective MES bytes, does not write result
slots, and does not enter the consumer or restore a caller. In authoritative
`43C.MES`, group 4's second row therefore reports the shared backward fallback
to `0x399F` rather than being mislabeled cancel/back.

Content Core `0.271.0` adds the first product-side promotion boundary for that
analysis. `kakyu_event_player_routine40_consumer_plan/v1` revalidates the exact
grouped contract and MA-06 reachability report, then binds one reachable
numeric `(first_result, second_result)` pair to its stored consumer coordinate,
stored fallback, or empty-list terminal. Executable plans write only the
confirmed `state_u16[21]` and `state_u16[13]` values immediately before the
exact decoded destination. They remain `remake_only`, carry no choice text or
native effects, and forbid caller resume without a separately source-bound
frame. This closes the reusable data handoff for EP-01 but does not yet make
43C ordinary playback or expose a grouped Continue action. The existing
grouped Analysis view now derives both its consumer/fallback hint and its
empty-list acceptance from this plan instead of reading consumer fields
directly. Selection still inspects only a cloned DEF body and leaves the live
sandbox unchanged. EP-01 is complete at this fail-closed boundary: a known
numeric route alone never authorizes grouped consumer execution or caller
restoration.

Content Core `0.172.0` removes one presentation-only part of the EVENTB02 and
EVENTB14 gap. Their already source-bound AN atlases, AX frame rectangles, and
destinations now render into the shared logical compositor rather than as a
separate shader overlay. Every frame begins from a retained static-background
checkpoint and applies one exact RGB-key copy, so atlas strips and earlier
frames cannot accumulate. This does not promote either route: the 60 Hz clock
is still tool timing, generic surface-8 production and native cadence remain
unresolved. EXE audit v41 now fixes EVENTB14's routine-40 numeric result as a
one-based selected-record index, while its native UI/effects and 43C's dynamic
second-stage list remain incomplete.
Content Core `0.178.0` subsequently makes that clock a shared versioned
scheduler. EVENTB02 and EVENTB14 now use it for sub-tick accumulation, bounded
catch-up, exact dispatch order, and reset-requested cycle wrap; Event Player
keeps only route-specific frame extraction and compositor application. This is
still an explicit 60 Hz tool preview and does not claim the native host cadence.

## Starting State and Saves

Core 0.277.0 adds `kakyu_mes_station_background_plan/v1`, a pure selection
proof built from the exact original `LIBLARY.LIB` payload. Its JSON-shaped
result retains the numeric date/time inputs, source-relative guard decisions,
MMO marker, active-surface writes, explicit RGB-key copy coordinates and the
unexecuted routine-8 boundary. Validation rebuilds the complete plan from the
source bytes; no serialized plan may authorize execution merely by claiming a
hash or producer version. This is not a renderer, calendar validator or
event-eligibility check, and it never accepts or mutates a live game state.
Direct build inputs are integers in `0..65535`; JSON reopen additionally
accepts exactly integral numbers in that range, without truncating fractions
or coercing booleans/strings. These are raw numeric slots, not necessarily
valid calendar dates or clock times.

EVENTB03 now requires that proof before resolving its already supported
`01MA_3.MMO` station background. All four existing presets retain their exact
date 413 / time 1825 guards, B_PIC contracts and map terminals. Other numeric
dates/times can be audited by the standalone plan but cannot start a new
ordinary-playback route. Effective media still uses the normal resolver and
640x400 size check. The existing background projection is not upgraded to full
native equivalence: the original mode-1 copy depends on an RGB key and prior
destination pixels whose complete native lifetime remains unresolved. See
[Station Background Selection](../mes/station_background_selection.md).

Core 0.278.0 adds `kakyu_mes_mahoko_standing_plan/v1`, a separate read-only
proof for the original `B_PIC.MES` date-selection slice with fixed
`global_u8[206]=1`. It identifies B1/B2/B3/B4 and preserves both source copy
records with their unevaluated banked-state expressions. It stops before
routine 22; dates outside the four numeric intervals return a face-join
boundary with no selected standing. That absence does not establish whether
native pixels are blank or retained. Bootstrap, BGM, expression selection and
surface lifetime are not simulated by this plan.

The public builder accepts only an exact original payload and an integer
unsigned-word date. Revalidation rebuilds from those bytes and compares the
whole plan, allowing only lossless integral JSON numeric transport. EVENTB03
requires the B1 marker and routine-22 boundary to match its existing probe,
then still verifies the complete executed B_PIC trace, media identities and
clone-only state diff before publication. The four presets, 413/1825 guards,
face contracts, B14 behavior and rendering are unchanged. See
[Mahoko Standing Selection](../mes/mahoko_standing_selection.md).

Event Player owns a versioned, isolated event-session state. Event catalog
entries may provide evidence-backed presets for date, time, location, affection,
flags, and other required inputs. Advanced users may edit numeric state and see
which original branch that state selects.

Gameplay saves are never changed. A future original-save import may be offered
only as an explicit read-only operation that copies supported fields into a new
event session. Event results remain inside the Event Player session unless a
separate, versioned export is deliberately implemented.

## Evidence and Compatibility Labels

Played original routes expose source identity and support level outside the
game frame: exact original source, analysis-only scope, or unsupported with a
specific unresolved boundary. Source identity alone does not prove complete
playback. Tool-seeded states and omitted native effects are labelled separately.
Authored compatibility labels remain in editor/package reports, not a second
Event Player content mode.

## Safety Invariants

- Original inputs are read-only and source identity is checked before use.
- Event Player never modifies a gameplay save.
- Source selection/reload failure preserves the prior valid session.
- Modified content cannot enter execution through Playback, Analysis, editor
  Run requests, overlays, derived layers or fallback resources.
- Paths remain traversal-safe; source/content identity cannot change unnoticed.
- Unsupported execution fails closed and cannot silently mutate the session.
- Original payloads, dialogue and machine paths remain local and untracked.

## Definition of Done

**Final deliverable target, ruled 2026-09-20 (option 1 of two, approved as
stated):** the original player becomes a *minimal-presentation event player*.
Every catalog site plays from its start to its ending through the one shared
call frame (`content_core/mes_route_probe.gd`), with no per-event code; the
starting state comes from a guard-derived input form or a saved preset; what
plays is text (the original lines and speakers, routine-40 menus as they are),
voice (a line's voice file), BGM (the selector's track, kept across lines)
and still pictures (backgrounds, standing pictures and CGs as stills, an
oversized picture shown whole by enlarging or scaling the window); the
ending is named in the game vocabulary. Not in the target: AX/AN animation
playback, camera motion, fades, shakes, transitions and waits, timing or
pixel equivalence, maps, place menus, the calendar, saves, titles and
endings, original-engine execution. Sound effects play fire-and-forget where
a file resolves. Playback shows no omission labels; Analysis keeps the
omitted records as evidence. EVENTB03's event-specific camera, AX and
background code is deleted once the shared path plays B03 as stills (done
2026-09-21, with every other per-event path). PR-02
and PR-03 stay deferred; PR-01 reopens only as far as stills need it; PR-04
only as the minimal BGM/voice/SE state. The remake is unaffected and keeps
reading v4 and the package; projecting presentation as data is not part of
this target. Acceptance: the first representatives by the owner's eyes, then
golden-frame comparison.

Revision 2026-09-24 (EP-13, owner findings): two rules from a census over
every analysis-group row's default run refine what "shown as stills" and
"a line" mean for the target above, without changing its scope. A still is
classified by its confirmed `native_active_surface_value`, not by the
loading script's file name: surface 8 (277 loads, `*an.mmo` animation
atlases) and every `ax_resource_marker` (277 loads) are animation sources,
never drawn; surface 2 from a `*_PIC.MES` script (139 of surface 2's 332
loads) is a standing picture; surface 1 (58 loads), surface 9 (1 load) or
surface 2 from any other script (193 loads) is the base picture. A step
(one navigable line in Playback) is the run of message records between two
`dialogue_boundary` rows (the click waits) - protagonist-name inserts: 2,653
over all 142 rows, 2,614 are exactly `text record, name insert, text record,
click wait`, one step. See `docs/spec/tech/content_tools.md`'s 2026-09-24
revision for the implementation, EVENTB03's step counts (89 message records
in 90 steps before, 51 `dialogue_boundary` rows in 52 steps after) and the
validated `original catalog group routes` counts.

Event Player reaches its final product goal when all of the following hold
(5 and 6 restated on 2026-09-20 to the target above):

1. The authoritative caller-derived event catalog is complete and every entry
   has a documented classification.
2. Every playable original event can run from a catalog start through each
   material branch to its confirmed terminal without manual debug coordinates
   or unsupported-boundary actions.
3. All stored user choices in the playable corpus are selectable and deliver
   their confirmed caller-visible results.
4. Date, time, location, affection, and flag branches select the correct
   dialogue, media, audio, completion state, and return path for the cataloged
   representative states.
5. Backgrounds, standing pictures and CGs are shown as stills at the right
   lines, an oversized picture whole; animation, camera motion and screen
   effects are not played and are not claimed.
6. A line's voice plays with the line, BGM follows the selector and is kept
   across lines, sound effects play where a file resolves; no timing
   equivalence is claimed.
7. Every ending is reported in the game's own vocabulary - back to a world
   map (with whose lines came first, the event's or the place's), back to the
   place menu, straight into another script, not triggered, or unresolved -
   with the code-level terminal (callee return, caller postlude, handoff,
   prefix end, rejection, analysis boundary) beside it as evidence
   (`docs/spec/data/event_outcome_vocabulary.md`, 2026-09-20).
8. Playback view completes supported events without trace/debug information
   covering the logical game frame.
9. Analysis view retains reproducible source evidence and fail-closed behavior.
10. Original media dependencies resolve to their validated source identities.
11. Modified MES, authored dialogue/media and mod-event requests are rejected
    before execution, including through Analysis and editor launch paths.
12. Source changes/reloads are transactional and leave original data unchanged.
13. Supported original routes have headless regression coverage, and
    visual/audio behavior that cannot be automated has a batched, documented
    verification procedure.
14. No unresolved route is presented as complete, and its remaining blocker is
    visible in the catalog and evidence documentation.

The common audio runtime is being separated from presentation playback.
Content Core `0.188.0` introduces `kakyu_event_audio_state/v1`, a pure
effective-identity transition model. Each audio identity contains the logical
ARC and entry, resolver source (`original_arc`, `overlay`, `materialized_arc`,
or fallback), and effective SHA-256. The model distinguishes BGM start,
identity-preserving retain, replacement, stop, bounded caller-frame capture,
and caller restore. Voice submission uses an explicit `replace`, `queue`, or
`overlap` policy and deterministic completion/promotion rules. Snapshots are
detached copies and invalid identities or stack operations fail closed.

This v1 contract does not claim native audio-device timing or prove a new MES
opcode meaning. Event Player mirrors each successfully resolved BGM or voice
marker into the model using the effective Content Identity SHA. A same-name
overlay or verified materialized-ARC revision therefore replaces the prior
state instead of inheriting a name-only retain result. Preview clearing resets
the model, and failed overlay activation preserves the previous detached audio
snapshot with the rest of the active session. Event Player still uses the
existing single BGM and single voice preview players; caller restoration and
actual queue/overlap transport remain unwired and cannot be presented as
current playback support.

## Delivery Sequence

Work proceeds toward the final goal in these stages:

1. build the authoritative caller-derived event catalog and coverage matrix;
2. generalize proven event-family paths into the interpreter, call stack, state,
   choice, and completion runtime;
3. complete the common MMO/surface/AX/A6 presentation and audio pipeline;
4. enforce original-only content at all public app entry points (EP-08);
5. validate original media identities and source-preserving reload behavior;
6. separate playback and analysis UI while keeping one runtime;
7. remove debug-only actions from every cataloged normal route; and
8. finish original-corpus regression and the accumulated visual/audio
   verification within existing deferrals. Native-engine execution remains
   outside the product gate.

Adding more isolated previews is useful only when it closes a catalog blocker,
proves a reusable runtime contract, or supplies evidence required by one of
these stages.

Ordered implementation work and current status are maintained in the
repository-root [TODO](../../../TODO.md).
