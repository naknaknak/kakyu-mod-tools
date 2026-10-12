# MES Analysis: Audio Routing

This document records the shared BGM selector table and the confirmed scene
call sites. It does not contain any audio data.

## Shared Call Convention

At confirmed call sites, command `0x09` writes a track selector to argument slot
1 and command `0x1D` invokes shared routine `23`. `LIBLARY.LIB` compares that
selector with its BGM table, calls the filename-bearing playback command, and
retains the selected value so requesting the same track does not restart it.

Content Core `0.29.0` executes only the constrained runtime subset needed to
represent this confirmed route: literal argument-slot-1 assignment form
`09 01 00 <literal expression> 00`, followed by a single-literal routine-23
record list. The trace records the selector and filename from the table below.
Every other command `0x09` context remains unsupported. A literal command
`0x1D` context stops at an explicit shared-routine boundary; this classification
does not execute the body or establish general call, return, or argument
semantics.

Content Core `0.190.0` exposes the same evidence boundary as a reusable audio
reference index. A BGM reference is emitted only when the strict decoder finds
the slot-1 literal assignment and literal routine-23 invocation as immediately
adjacent instructions in one address region. Voice references are emitted only
from the confirmed subcommand-7 Ogg envelope. The index retains the authoritative
MES entry and code-relative offsets, but does not infer references from plain
filenames, non-adjacent data flow, dynamic expressions, or unknown selectors.
This is a tooling search projection; it neither executes the route nor claims
that static presence makes the referenced branch reachable in a particular
game state.

Since WD-21 unit 1 (2026-10-06, Core 0.373.0) the playback package's media
inventory classifies a BGM reference by the same pair, applied to the package's
own records, and looks each named `.WAV` up in `bgm.arc`: 5,157 occurrences,
45 names, all shipped, equal to this index over the 869 packaged entries. The
rule, its region test and the six table names that `bgm.arc` does not hold are in
[Media Reference Classification](media_references.md).

## BGM Selector Table

The table was scanned directly from the authoritative `LIBLARY.LIB` code.

| Selector | WAV | Condition offset | Filename offset |
|---:|---|---:|---:|
| 1 | `idou.wav` | `0x5be` | `0x5d0` |
| 2 | `staff.wav` | `0x5e2` | `0x5f4` |
| 3 | `mizuho2.wav` | `0x607` | `0x619` |
| 4 | `h_h_h.wav` | `0x62e` | `0x640` |
| 5 | `my_room.wav` | `0x653` | `0x665` |
| 6 | `kokuhaku.wav` | `0x67a` | `0x68c` |
| 7 | `mayumi.wav` | `0x6a2` | `0x6b4` |
| 8 | `opn2.wav` | `0x6c8` | `0x6da` |
| 9 | `wakare.wav` | `0x6ec` | `0x6fe` |
| 10 | `comical.wav` | `0x712` | `0x724` |
| 11 | `tina2.wav` | `0x739` | `0x74b` |
| 12 | `ai.wav` | `0x75e` | `0x770` |
| 13 | `ryoko.wav` | `0x780` | `0x792` |
| 14 | `mahoko.wav` | `0x7a5` | `0x7b7` |
| 15 | `ido_dwn.wav` | `0x7cb` | `0x7dd` |
| 16 | `nana.wav` | `0x7f2` | `0x804` |
| 17 | `sizuka.wav` | `0x816` | `0x828` |
| 18 | `minoru.wav` | `0x83c` | `0x84e` |
| 19 | `shock.wav` | `0x862` | `0x874` |
| 20 | `stay.wav` | `0x887` | `0x899` |
| 21 | `nana2.wav` | `0x8ab` | `0x8bd` |
| 22 | `haruhiko.wav` | `0x8d0` | `0x8e2` |
| 23 | `tina.wav` | `0x8f8` | `0x90a` |
| 24 | `miyuki.wav` | `0x91c` | `0x92e` |
| 25 | `aquazone.wav` | `0x942` | `0x954` |
| 26 | `x_mas.wav` | `0x96a` | `0x97c` |
| 27 | `concert.wav` | `0x98f` | `0x9a1` |
| 28 | `hhhh.wav` | `0x9b6` | `0x9c8` |
| 29 | `bijutu.wav` | `0x9da` | `0x9ec` |
| 30 | `sinji.wav` | `0xa00` | `0xa12` |
| 31 | `orgoal.wav` | `0xa25` | `0xa37` |
| 32 | `kyaba.wav` | `0xa4b` | `0xa5d` |
| 33 | `maki.wav` | `0xa70` | `0xa82` |
| 34 | `mitui.wav` | `0xa94` | `0xaa6` |
| 35 | `minatu.wav` | `0xab9` | `0xacb` |
| 36 | `reiko.wav` | `0xadf` | `0xaf1` |
| 37 | `happy.wav` | `0xb04` | `0xb16` |
| 38 | `hppy_1.wav` | `0xb29` | `0xb3b` |
| 39 | `u_enchi.wav` | `0xb4f` | `0xb61` |
| 40 | `tosho.wav` | `0xb76` | `0xb88` |
| 41 | `jinja.wav` | `0xb9b` | `0xbad` |
| 42 | `shogatu.wav` | `0xbc0` | `0xbd2` |
| 43 | `miko.wav` | `0xbe7` | `0xbf9` |
| 44 | `furare.wav` | `0xc0b` | `0xc1d` |
| 45 | `furare_1.wav` | `0xc31` | `0xc43` |
| 46 | `tim.wav` | `0xc59` | `0xc6b` |
| 47 | `ya9.wav` | `0xc7c` | `0xc8e` |
| 48 | `uranai.wav` | `0xc9f` | `0xcb1` |
| 49 | `game.wav` | `0xcc5` | `0xcd7` |
| 50 | `pb.wav` | `0xce9` | `0xcfb` |
| 51 | `boaling.wav` | `0xd0b` | `0xd1d` |
| 52 | `hppy_2.wav` | `0xd32` | `0xd44` |
| 53 | `sweet.wav` | `0xd58` | `0xd6a` |
| 54 | `comic.wav` | `0xd7d` | `0xd8f` |
| 133 | `kse0069.wav` | `0xda2` | `0xdb6` |
| 134 | `zoo.wav` | `0xdcb` | `0xddf` |

Selectors 133 and 134 use the expression token `0xF1` with a 16-bit literal;
they are not sequential selectors 55 and 56.

## Native CSlot Fixed-Audio Cross-Check

Executable audit v147 binds native handler `0x00441160` to RTTI-qualified
`CSlot` virtual slot `+0x0C`. On its bounded initial-state branch, exact bytes
request fixed literal `comical.wav` through the application document/archive
adapter with selector zero, pass a nonzero returned resource into the native
audio vectors, and close the stack-local `CFile` at compact call
`0x004413AF`. A read-only index scan of the authoritative `bgm.arc` finds one
case-insensitive `COMICAL.WAV` entry with stored size 7,436,112 bytes.

This cross-check confirms that the native literal has a corresponding source
resource and that the compact call is file cleanup rather than script
execution. It does not connect the CSlot initial-state branch to the selector-10
`LIBLARY.LIB` row or establish reachability from any particular MES entry.
Evidence type: authoritative `bgm.arc` index, authoritative `LIBLARY.LIB`
static selector table, configured-original launcher extraction at its checked
embedded-PE boundary, byte-identical embedded runtime, and exact
RTTI/vtable/local-object blocks; confidence: **Confirmed** for resource
presence and bounded native ownership, **Unresolved** for MES route
reachability and gameplay meaning.

## Startup Effect Evidence

The authoritative `mes.arc` entry `START.MES` begins at archive offset
`0x11c3305`. Its code section begins at entry-relative offset `0x8`; the
`kse0031.wav` filename begins at code-relative `0x470` (entry-relative
`0x478`) inside a filename-bearing sequence that begins at code-relative
`0x468`.

This source reference was correlated with an isolated original-engine playback
test on 2026-07-31. All 87 `se.arc` WAV payloads were replaced with the same
1.000-second PCM probe, music and voice were disabled, and effects remained
enabled. The original `KSE0031.WAV` is 11.035 seconds. When the startup path ran,
the engine child process changed from a zero audio baseline to a 1,091 ms active
signal and remained responsive. Confidence is high that this startup path
requests `KSE0031.WAV` and that the original engine played the replacement from
the rebuilt `se.arc`.

The repository's Windows automation subsequently repeated the test while
replacing only `KSE0031.WAV`. That run produced a 1,092 ms effect-only active
interval and peak `0.1137618`, with a responsive titled game window, unchanged
source hashes, and successful temporary-data cleanup. A second run reproduced
the same archive hash and peak; across three runs the active interval ranged
from 1,076 to 1,092 ms. This removes the all-entry probe as a possible ambiguity
for the confirmed startup request.

The surrounding bytes are runtime-correlated evidence for this one startup
effect request. The separator at `START.MES:0x0469` is command `0x0D`; the
filename-bearing command `0x06` begins separately at `0x046A`. The complete
native numeric command `0x06` is now confirmed as a banked-byte write run, as
documented in [Format and Method](format_and_method.md). This filename-bearing
shape is not a valid instance of that numeric grammar, however, and its native
consumer remains unresolved. The runtime audio correlation therefore applies
only to this bounded startup envelope and must not be used to assign every
filename-like `0x06` sequence globally.

## Confirmed Current Scene Routes

| Remake route | Original evidence |
|---|---|
| town map | selector 1 maps to `idou.wav` |
| EVENTB01 callee/caller route | `13C:0xf93..0xfa3` names EVENTB01; EXE v37 supplies callee coordinate zero; `EVENTB01:0x288` assigns 14 and `0x28e` calls routine 23 for `MAHOKO.WAV`; B0796/B0797 accompany seven dialogues before return `0x6a0`; restored `13C:0xfa3..0x1017` selects `X_MAS.WAV` for date 1224, `SHOGATU.WAV` for 1301, or default `IDOU.WAV` before the bounded MACHI handoff |
| EVENTB02 callee/caller route | `13C:0x10cd..0x10dd` names EVENTB02; EXE v37 supplies callee coordinate zero; `EVENTB02:0x3e6` assigns 14 and `0x3ec` calls routine 23 for `MAHOKO.WAV`; bounded markers B0798..B0800 accompany eight dialogues before return `0x8c9`; restored `13C:0x10dd..0x1151` selects `X_MAS.WAV` for date 1224, `SHOGATU.WAV` for 1301, or default `IDOU.WAV` before the bounded MACHI handoff |
| EVENTB03 result-3 route | `EVENTB03:0x02C8/0x02CE` selects 10 / `COMICAL.WAV`; result 3 later reaches selector 4 / `H_H_H.WAV` at `0x2FC4` and selector 133 / `KSE0069.WAV` at `0x3C7E`. The latter two source entries live in `bgm.arc`, but user-confirmed original playback identifies them as event-timed effects. Event Player therefore validates them through the same archive-aware WAV resolver and plays them on an independent effect channel without replacing the retained scene BGM. This is an exact EVENTB03 projection, not a global reclassification of routine 23. |
| EVENTB14 read-only choice route | `44M:0xc8f8..0xc925` first updates the inherited `B_PIC.MES` presentation and then names EVENTB14; EXE v37 supplies callee coordinate zero. Before the first choice, the callee adds no BGM/MMO marker and the caller-owned picture route supplies `MAHOKO.WAV`, `B.MMO`, and `BAN.MMO`/`B.AX`; markers B0829..B0832 accompany seven dialogues before routine-40 DEF boundary `0x4cf`. In explicit cloned outcome 2, the ordinary-date forced move requests selector 1 / `IDOU.WAV` at `0xb07`; after the `B14.MMO` park setup, selector 44 / `FURARE.WAV` is requested at `0xe99` before dialogue `0xed9`. The EXE-confirmed one-based result is projected explicitly; native selection UI/effects remain disabled |
| EVENTB15 callee/caller route | `11M:0x347b..0x348b` names EVENTB15 and EXE v37 supplies callee coordinate zero; `EVENTB15:0x2ff` assigns 14 and `0x305` calls routine 23 for `MAHOKO.WAV`; no voice marker occurs across nine dialogues before return `0x778`; restored `11M:0x348b..0x34bb` contains no BGM request and stops at the bounded MACHI handoff |
| EVENTD01 | `12C:0x7cd` calls coordinate zero; bounded presentation then `EVENTD01:0x3e6` assigns 33 and `0x3ec` calls routine 23 |
| EVENTD02 | `12C:0x98d` names EVENTD02 and resumes at `0x99d`; the EXE handler starts the callee at zero, then bounded presentation reaches `EVENTD02:0x3e6` selector 33 / `0x3ec` routine 23 |
| EVENTD03 | `EVENTD03:0x22e` assigns 33; `0x234` calls routine 23 |
| EVENTD03 caller BGM prefix | `12C:0xdee..0xe62` selects 26, 42, or 1 by date, then stops before native postlude effects |
| EVENTD08 | preceding `D_PIC:0x9a` assigns 33; `0xa0` calls routine 23 |
| Maki date | `D_DATE3:0x5e35` assigns 33; `0x5e3b` calls routine 23 |

The selector-33 pattern repeats throughout `MAKI_H.MES` and multiple
`SCENE_D*.MES` files, confirming that it is the shared Maki route rather than an
event-local coincidence.

The EVENTB03 effect-channel exception is deliberately narrow. Original
`H_H_H.WAV` and `KSE0069.WAV` have SHA-256
`a71c3f7aef559b553daeeb08bdfe044a459763064148fe77220e8b756108269d`
and `703d6d05c7a9b6e46441eb8fceeb8a68a58a8551ad9bd7fb7e584ad38c23b500`.
Both exact routine-23 requests, selectors, source identities, and playback
order are **Confirmed** by the authoritative route and headless replay. Their
event-effect role is **User-confirmed native observation**; the native mixer
bus and the meaning of those selectors outside EVENTB03 remain **Unresolved**.

For the hash-bound EVENTD01 tool start, the authoritative
`12C.MES:0x07CD..0x07DD` command-`0x0F` envelope names the callee and fixes the
physical resume. Configured-original executable audit v38 separately confirms
that its handler enters the callee at coordinate zero and restores the caller
coordinate. Event Player therefore begins at `EVENTD01.MES:0x0000`, crosses
only the exact bounded record and presentation omissions, then reaches the selector-33
argument-slot assignment at `0x03E6` and routine-23 request at `0x03EC`. The
isolated trace must resolve exactly one `MAKI.WAV` request before the first
dialogue boundary at `0x043E`; a request reached without that full source-bound
prefix does not satisfy the confirmed start contract. Event Player loads the
resource through the shared overlay-aware `bgm.arc` validation/playback path,
while the original ARC remains read-only. Configured-original executable audit
v37 reconfirms command `0x0F`'s zero-coordinate call/restore path and command
`0x09`'s indexed argument-slot writer. The routine-23 selector catalog remains
archive-derived evidence, so no generic native audio opcode or physical-device
playback claim is added.

For the hash-bound EVENTD02 start, the authoritative
`12C.MES:0x098D..0x099D` command-`0x0F` envelope names the callee and fixes the
physical caller resume, but contains no coordinate operand. Configured-original
executable audit v38 separately confirms that the command handler saves the
caller coordinate, starts EVENTD02 at coordinate zero, and restores the caller
after return. Event Player therefore starts at `EVENTD02.MES:0x0000`, crosses
the exact routine-28, paired command-`0x12`, normalized surface-branch, and
foreground/AX boundaries, then reaches the selector-33 assignment at `0x03E6`
and routine-23 request at `0x03EC`. The isolated prefix must resolve exactly one
`MAKI.WAV` request before the first EVENTD02 dialogue boundary at `0x0456`; a
request reached from the former `0x03E6` shortcut does not satisfy the confirmed
start contract. Event Player retains that validated BGM while explicitly
continuing the existing bounded route to the native presentation pause at
`0x0BAD`, through the effect-omitting continuation, and to the confirmed
`0x18C6` return. The pause itself is not event completion. BGM lookup remains
overlay-aware and read-only; any source/hash/coordinate mismatch fails closed
before replacing the active presentation or audio state.

After the confirmed EVENTD03 return, the authoritative `12C.MES` caller prefix
at `0x0DEE..0x0E62` requests `X_MAS.WAV` for raw date `1224`, `SHOGATU.WAV`
for `1301`, and `IDOU.WAV` otherwise. Event Player validates all three paths
against the exact 116-byte slice, but runs only the branch selected by sandbox
`state_u16[7]` when the user explicitly requests the caller BGM preview. It
stops before command `0x03` at `0x0E62`, performs no state write, and does not
claim the Christmas/New Year branches are reachable through EVENTD03's
April-to-June availability gate.

The EVENTD03 one-click route begins at the original command-`0x0F` callee
coordinate `0x0000`. It requires authoritative entry SHA-256
`3c189313411fdbe151819fae44b809e1395ee08a76d5325f1b5f4f92e3d9e6fb`,
dispatches entry zero at `0x0008`, and follows routine 28, the two exact
three-record command-`0x12` lists, the naturally reached `D03.MMO` marker at
`0x01A4`, the independent `banked_u16[0][1] = 7` write, the native surface
record, and the fresh-state `global_u8[4000] == 0` branch. It then continues
through routines 21 and 28 to authoritative `EVENTD03.MES:0x022E`, whose bytes
`09 01 00 21 ff 00` assign selector 33. The immediately following instruction
at `0x0234` contains `1d 02 17 ff 00` and requests `MAKI.WAV` through routine
23 before the three-row first dialogue boundary at `0x0284` (resume `0x0288`). Evidence
is direct archive bytes, strict GDScript decode and trace replay, and the
configured-original executable audit v38; confidence is **Confirmed** for the
stored selector/routine request and coordinate-zero path to it.

The validator requires `MAKI.WAV` to exist in user-owned `bgm.arc` and pass
bounded PCM WAV validation. The original `mmo.arc` base layer must retain its
334,171-byte `D03.MMO` entry with SHA-256
`aa04ef0c8b4452c660ba7c4afb8581c35c7b45755edd775bbd720490d7507313`
as the evidence binding. The effective bytes may still come from the loaded
overlay and must strictly decode as 640x400. Event Player reaches this marker
in control-flow order rather than preloading it as detached context. Its
explicit omission is limited to the two hash-bound native record lists and
native surface pixels; the tool does not claim an original active-surface
identity, placement, or composition. Any source hash, coordinate, record
count, marker, branch, base-media, or request mismatch fails closed, and no
original archive is written.

The hash-bound EVENTD08 one-click start now carries its separately confirmed
inherited BGM context as well. Before loading audio, Event Player reopens
authoritative `D_PIC.MES` SHA-256
`72473432ce3dd6e0fc1e994a737dbecd5494eaf4477efc24368d3b3160d7fecd`
from `original_arc` and runs an isolated trace from `0x009A`. The first two
rows must remain selector `33` and the routine-23 request at `0x00A0`, resolving
to `MAKI.WAV`; later D_PIC presentation effects are neither consumed nor
claimed by this check. The resolved `bgm.arc` WAV then uses the same bounded
validation/playback path as EVENTD03 and remains loaded across the explicit
EVENTD08-to-12C caller transition. Evidence type: direct authoritative MES
bytes, original Event Player integration, and unchanged `mes.arc`, `mmo.arc`,
and `bgm.arc`; confidence: **Confirmed** for this tool preview route and
**Unresolved** for a generic D_PIC native presentation interpreter.
After the request, source-line markers `21..25` and the bounded write at
`0x0248` now execute without leaving the sandbox. The first original CP932
message at `0x0258` is exposed, command `0x0D` at `0x025C` is retained as a
statement separator, and the exact protagonist-name insertion at `0x025D`
joins the following original text fragment. Exact `13 FF` at `0x0282` then
falls through without changing sandbox state. The exact `02 02 FF 00` trailer
at `0x0284` is returned as a supported dialogue boundary with physical
continuation `0x0288`. Event Player can explicitly resume that retained
coordinate by button or focused-frame input and preserves temporary argument
slots across the boundary. At `0x0288`, slot 1 receives message record ID
`47181`; shared routine `0` at `0x0290` retains that value as presentation
metadata, then the trace reaches the next original dialogue boundary at
`0x02E2` with physical continuation `0x02E6`. When invoked directly at
`0x022E`, this remains a partial BGM-and-dialogue inspection anchor. The normal
**Start Event Dialogue** path instead reaches it from the confirmed
coordinate-zero EVENTD03 intro described above.

Four filename-bearing voice presentation records begin at code-relative outer
control offsets `0x0305`, `0x03FD`, `0x0534`, and `0x0610`; their nested
subcommand/name records begin one byte later at `0x0306`, `0x03FE`, `0x0535`,
and `0x0611`. Each uses the exact audited marker envelope, has the required
surrounding bit set/clear writes, and resolves to
an entry in the user-owned `voice.arc`. The bytes after the leading `0x0D` are
not an ordinary command-`0x07` word-state write: the original interpreter
consumes `0x0D` as native presentation control and dispatches nested
presentation subcommand `7`. Its typed record list carries selector `2`, the
NUL-terminated Ogg name, and value `0`; the native bridge queues that name.
Event Player still labels its decoded playback as a tool projection because
Godot does not execute the original engine path. Executable audit v7 resolves
that native path through `Cai5OggWaveThread` to an
`IDirectSoundBuffer::Play` dispatch while keeping physical device output a
separate, unobserved runtime condition.

Instruction schema v30 recognizes the first native presentation record at
`0x0305` while retaining the nested subcommand coordinate `0x0306`. Starting
from the second continuation
`0x02E6`, trace schema v45 retains `D0977.OGG` with native playback semantics
bounded to the confirmed queue/stream/DirectSound Play route, then reaches the
next original dialogue boundary at
`0x0378` with physical continuation `0x037C`. The authoritative validator also
requires `D0977.OGG` to exist in the sibling `voice.arc` and validates it as
44.1 kHz mono Vorbis. This confirms the bounded tool projection, resource, and
native Play dispatch; it does not prove that a host audio device emitted
sound.

Continuing the same authoritative path reaches the remaining markers
`D0978.OGG`, `D0979.OGG`, and `D0980.OGG`; all four resolve in `voice.arc` and
pass bounded 44.1 kHz mono Vorbis validation. The 12 dialogue segments end at
the confirmed command-`0x00` return boundary `0x07FF` after the isolated
completion write. This validates the callee's bounded media route, not native
host-device output or caller execution.

For interactive inspection, Event Player may decode and play that validated
payload as an explicitly labeled tool projection. Voice uses a separate audio
player so it does not replace the current BGM stream. Resolution prefers
`voice.arc`, then the Tina archives; a name present in both Tina banks remains
an explicit bank-selection ambiguity. This tool behavior is not evidence of
the native playback path.

## Deferred Ogg Replacement Candidate

The isolated playback batch uses authoritative `voice.arc` target
`D0977.OGG` and donor `D1033.OGG`. Their source payloads are respectively
43,642 and 9,446 bytes, with SHA-256
`b786db11f1f544be14f80601c71d98c4712163bc04c00502bbfe5463d07b4c9b`
and `c1daaa55f94dd64d77cc31a459ad64ab07336974bec0d0183c193828ce727b6e`;
both validate as 44.1 kHz mono Ogg Vorbis. The source archive SHA-256 is
`12278db46895d35ddc73a489dd82857be560406ba83c5a7fdfac3ba415545322`.
The headless swap preparer copied the donor payload without re-encoding,
rebuilt and reopened `voice.arc`, verified both target and donor reads against
the donor bytes, and produced candidate archive SHA-256
`5875035d373f62b13b7d991734ef405b1c11378947e7e20838a734959dd78401`.
The source archive remained unchanged.

Executable audio audit v7 independently confirms that the checked original
launcher contains `OggS` and `vorbis`
signatures at raw offsets `0x8F914` and `0x8F91C`, the labels `Ogg Class` and
`Voice Archive Class` at `0x95054` and `0x95658`, an
`ogg_sync_pageout()` diagnostic at `0x95B18`, and the configured
`.\\ELFIMAGE\\Voice.Arc` path at `0x98C0C`. The audit binds those raw launcher
positions to embedded runtime virtual addresses `0x00474914`, `0x0047491C`,
`0x0047A054`, `0x0047A658`, `0x0047AB18`, and `0x0047DC0C`, and reports the
voice archive key at `0x0047DC24`. This confirms that the hashed
executable embeds an Ogg/Vorbis voice-archive implementation.

The same v7 audit locks the bounded native archive route instead of relying
on strings alone. Initialization at `0x0043C45C` reads the Voice ARC path/key,
constructs the common CAI5Arc object at `0x0043C4B2`, appends it to document
collection `+0x60` at `0x0043C55B`, and opens it at `0x0043C574`. Four document
vtables point slot `+0x34` to the same loader `0x0043E3E0`. That loader indexes
the archive vector beginning at document offset `+0x64`, calls the common
named-entry stream setup `0x00402BC0`, and reads its virtual metadata slots
`+0x24`, `+0x2C`, and `+0x28`. The selector-zero case at `0x0042A0C7` invokes a
host `+0x34` method with four arguments and forwards accepted stream metadata
through a second object's `+0x78` slot; guarded override `0x0043F940` can rejoin
that bridge at `0x0043FA86`.

A separate literal route provides a stronger bounded Ogg cross-check, but its
owner is now narrowed to the original settings UI rather than an event/MES
consumer. Function `0x0041F200` switches exactly among selectors `0`, `1`, and
`2`; its sibling sample literals are `kokuhaku.wav`, `kse0006.wav`, and
`e0820.ogg`. The containing object forwards an active one-of-three settings row
at `0x0041DD22` through adjustment function `0x0041ED00`, whose two change paths
call the sample function at `0x0041EE71` and `0x0041F15A`. The same subsystem
references settings keys `IsVoice` and `AutoMesSpeed`.

On selector `2`, at
`0x0041F2BC`, the original executable passes the string `e0820.ogg` from
`0x0047B8A0` to a host/document virtual method at slot `+0x34`. On its accepted
path, calls at `0x0041F2D2` and `0x0041F2F5` obtain the same class of object from
`0x004070C0`; the returned object receives the loaded values through virtual
slot `+0x78` and then virtual slot `+0x28`. The audit locks the exact bounded
instruction bytes, literal, and direct-call targets. RTTI identifies the
receiving implementation as `Cai5OggWaveThread`: its vtable at `0x0047AE3C`
maps slot `+0x78` to Ogg stream handoff `0x0040D2A0` and slot `+0x28` to shared
audio start method `0x0040E730`.

When the authoritative `voice.arc` is supplied to audit v7, the shared Python
ARC index reader case-folds that executable literal to entry `E0820.OGG` at
index 5,455. The audit streams only that indexed range and confirms 8,270 bytes,
SHA-256 `c3d5f5e59ff8ae737bc12d74794e66283125dd86fe3a6442863bf2c977c7feb7`,
an Ogg container, and a Vorbis identification packet reporting mono 44.1 kHz.
This binds the static filename-bearing route to a real user-owned Voice ARC
resource without extracting it or placing payload data in the repository.

Audit v7 also closes the bounded native MES consumer route. The interpreter
peek at `0x0043F0A0` recognizes presentation control `0x0D`; after consuming
it, call site `0x0043F177` enters dispatcher `0x00428120`. The dispatcher
evaluates nested subcommand `7`, calls typed-record parser `0x0043E800`, and
reaches its table case at `0x0042824F`. The record parser assigns tag `2` to an
expression value and tag `1` to a NUL-terminated script string, so the marker's
record sequence is value `2`, Ogg filename, value `0`.

Presentation case `7` forwards those records through public-context virtual
slot `+0x28` to the bridge at `0x0042A070`. Bridge selector `2`, table case
`0x0042A1D3`, appends the filename with helper `0x0042C8A0` and arms the queue.
Selector `3`, case `0x0042A258`, gates advancement on `IsVoice`, passes the
queued filename through host loader slot `+0x34`, and forwards an accepted
stream through object slots `+0x78` and `+0x28`.

The shared `+0x28` method locks the streaming buffer through interface slot
`+0x2C` at `0x0040E7A8`, unlocks it through `+0x4C` at `0x0040E833`, then
invokes slots `+0x3C`, `+0x34`, and `+0x40` with the DirectSound-compatible
SetVolume, SetCurrentPosition, and SetPan argument shapes. Finally,
`0x0040E8B1` invokes buffer slot `+0x30` with arguments `(0, 0, 1)`, matching
`IDirectSoundBuffer::Play(0, 0, DSBPLAY_LOOPING)`. This resolves the native
audible-output dispatch. Because the audit remains static and launches no
audio, device initialization, mixer acceptance, and physical speaker output
remain unobserved.

MES executable audit v130 additionally binds compact call `0x0040B366` inside
the same native codec family. RTTI identifies its owner as
`Cai5OggVorbisDecodeBase` and member `+0x308` as
`Cai5OggVorbisFileUser`. After the checked Ogg page-header EOS-bit test, the
call invokes the file-user's slot `+0x10`; that method seeks to the stored
stream origin through slot `+0x14` and resets its internal cursor. This is a
native logical-stream rewind, not a MES script runner or evidence that device
output was observed. Evidence type: exact original-executable EOS branch,
RTTI, member installation, vtable, and rewind/seek bodies; confidence:
**Confirmed** for the bounded rewind role; **Unobserved** for physical output.

MES executable audit v132 binds four additional compact calls in the same
native audio family. `Cai5OggWaveThread` teardown calls at `0x0040D14F` and
`0x0040D176` release its `+0xD4/+0xD8` and `+0xB8/+0xC0` pointer/size pairs
through a `VirtualFree` wrapper. Named-stream handoff call `0x0040D38C`
queries the current underlying file position through the RTTI-bound
`Cai5OggVorbisDecodeUser` and `Cai5OggVorbisFileUser` chain. Shared stream
handler call `0x0040D401` invokes `IDirectSoundBuffer` slot `+0x10` with
play/write-cursor output pointers after the same field is created through the
checked DirectSound buffer-creation path. No authoritative MES entry is read
by these native service bodies, and none is a script runner. Evidence type:
hash-bound original embedded-runtime bytes, RTTI/vtable ownership, exact
forwarding bodies, import-table identities, and the v7 DirectSound buffer
method family; confidence: **Confirmed** for bounded buffer release, native
file-position capture, and DirectSound cursor-query roles; **Unobserved** for
device acceptance and physical output.

MES executable audit v133 binds the next four compact calls to the native
Wave/DirectSound family. `0x0040DFC8` is reached after the checked
`CoCreateInstance`/DirectSound initialization route, loads the global
`IDirectSound` interface, sets a `0x60`-byte capability structure size, and
invokes interface slot `+0x10`, matching `IDirectSound::GetCaps`.
`0x0040E4D4` lies in RTTI-bound `Cai5WaveThread` teardown slot `+0x1C` and
passes its `+0xCC/+0xD0` pointer/size pair to the same slot-`+0x10`
`VirtualFree` wrapper already fixed for Ogg teardown. `0x0040F358` lies in
handler `0x0040F300`, shared by the `Cai5WaveThread` and `Cai5WaveNotify`
slot-`+0x6C` cells. It invokes member `+0x30` slot `+0x10` with play/write
cursor outputs immediately after the same field's slot-`+0x24` status query,
fixing the call as `IDirectSoundBuffer::GetCurrentPosition`.
`0x0040FEF9` lies in `Cai5WaveNotify` slot-`+0x78`; the body first locks the
same buffer through slot `+0x2C`, fills the returned regions, and passes both
pointer/size pairs to slot `+0x4C`, matching `IDirectSoundBuffer::Unlock`.
No authoritative MES entry is read by these native service bodies. Evidence
type: hash-bound original launcher/embedded-runtime agreement, exact native
call blocks, RTTI/vtable cells, DirectSound construction, and the independently
checked v7 interface family; confidence: **Confirmed** for the bounded device-
caps, buffer-release, cursor-query, and unlock roles; **Unobserved** for device
acceptance and physical speaker output.

MES executable audit v191 extends the same bounded Wave evidence to a
320-byte one-hop search. Its sole addition begins at the already confirmed
`0x0040F355..0x0040F358` `IDirectSoundBuffer::GetCurrentPosition` load/call
inside shared Wave handler `0x0040F300`. That function pointer is consumed
immediately and replaced by its HRESULT. The apparent later EAX-to-EDX
transfer comes from a fresh Wave-owner slot-`+0x60` result at `0x0040F43E`,
EDX is overwritten at `0x0040F460`, and final call `0x0040F48B` independently
reloads buffer slot `+0x4C` and passes the pointer/size pairs produced by the
earlier Lock. The final call is therefore `IDirectSoundBuffer::Unlock`, not a
script runner. Evidence type: hash-bound original launcher/embedded-runtime
agreement, exact shared-handler blocks, RTTI/vtable ownership, and the v7
DirectSound family; confidence: **Confirmed** for the bounded dataflow and
method identities; **Unobserved** for device acceptance and physical output.

MES executable audit v192 also excludes same-register call `0x0040F2DE` from
script execution coverage. The earlier candidate belongs to a returned native
stack-result owner; the actual caller independently reloads the RTTI-bound
`Cai5OggWaveThread` or `Cai5WaveThread` receiver and its slot `+0x6C`. The two
concrete handlers are native stream cursor queries, so this is another audio
service dispatch rather than `CScript::run`. Evidence type: hash-bound
original launcher/embedded-runtime agreement, exact owner/caller blocks, and
RTTI/vtable ownership; confidence: **Confirmed** for the receiver family and
false-positive boundary; **Unobserved** for device acceptance and physical
output.

The same v7 audit scans the authoritative `mes.arc` without extracting it. All
26,069 presentation-subcommand-7 selector-2 records match the exact typed
record grammar and carry an ASCII `.ogg` name; they occur across 788 of 1,016
entries. The only other observed selector is one selector-1 record. Evidence
type: direct hash-bound authoritative MES/Voice ARC reads plus exact original-
executable byte, pointer, call, jump-table, and string cross-check; confidence:
**Confirmed** for MES marker parsing, filename queueing, Voice ARC named-stream
loading, Ogg stream handoff, and the terminal DirectSound Play dispatch;
**Unobserved** for host-device and physical speaker output.

The Godot tool presentation for this bounded anchor was checked interactively
on 2026-08-02. Both an entered tool-only preview name and the explicit empty
placeholder were composed into the Japanese preview line, and execution stopped
at the then-current `0x0282` boundary. This visual check predates the separately
headless-verified cursor and dialogue-boundary increments and adds no claim
about the newer continuation path.

The runtime uses stable IDs (`town_map`, `maki`) and resolves local assets by
quality tier. Missing assets fall back to silence. Original WAV files are local
inputs and are not part of this analysis document.

## EVENTB03 result-3 SE occurrences and interleaved polling

The result-3 route uses shared routine 9, not routine 23's previously audited
selectors 4 and 133. Direct reads of authoritative `mes.arc` identify
`EVENTB03.MES` SHA-256
`558532a9b034522db857d009132b6a89aa488e577277857cc90ce337c95ee230`
and `LIBLARY.LIB` SHA-256
`d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d`.
The result-3 condition is at `EVENTB03.MES:0x2710..0x271A`; routine 9 is
registered at `LIBLARY.LIB:0x0EA6` with body `0x0EAD..0x1B4E`.

| Routine-9 argument 1 | Library condition | Effect record | Source resource |
| --- | --- | --- | --- |
| 68 | `0x10CE..0x10D9` | `0x10D9..0x10F3` | `se.arc:KSE00130.WAV` |
| 69 | `0x10F8..0x1103` | `0x1103..0x111D` | `se.arc:KSE00131.WAV` |

These are distinct PCM streams, not alternate names for `KSE0069.WAV`.
Both are mono, 22,050 Hz, signed 16-bit PCM. `KSE00130.WAV` contains
40,933 frames (about 1.85637 seconds), with PCM SHA-256
`0680f993e8b8c474caf132c8748a9f67583ac7024fcfa1e3db8558a58f877c77`.
`KSE00131.WAV` contains 44,276 frames (about 2.00798 seconds), with PCM
SHA-256 `17fc2e1dc07f9d90a5f8eb98b724745729af5a1f95e25ada86ba5d9e7c863439`.
The audit does not play the source files; a particular audible timbre or a
count of perceived impacts is not established by these metadata checks.

Every caller first writes argument 1 to the listed selector and argument 2
to zero. The six calls and intervening presentation-subcommand-12 records
are source ordered as follows; each call ends five bytes after its offset.

| Group | First call | First poll | Second call | Second poll | Next text record |
| --- | --- | --- | --- | --- | --- |
| 1 | `0x2A4A`, selector 69 | `0x2A74`, argument 20 | `0x2AA4`, selector 68 | `0x2ACE`, argument 40 | `0x2B31` |
| 2 | `0x2BEB`, selector 69 | `0x2C15`, argument 20 | `0x2C4A`, selector 68 | `0x2C74`, argument 40 | `0x2CBE` |
| 3 | `0x2D22`, selector 68 | `0x2D4C`, argument 20 | `0x2D7C`, selector 69 | `0x2DA6`, argument 20 | `0x2DB7` |

There is no dialogue boundary between the two calls in any group. Group 1
is followed by registered DEF21 at `0x2AE9` and a voice marker at `0x2B05`;
group 2 is followed by the voice marker at `0x2C92`. An aligned structural
scan of `0x2710..0x2EA4` independently enumerates all six routine-9 calls,
so repeated filenames must not be deduplicated into one resource identity.

Before group 1, DEF22 is invoked at `0x295D`. Active surface 2 is selected at
`0x2994`, `BLL.MMO` is loaded at `0x299C..0x29A8` (corrected 2026-09-14: since
Core 0.316.0 the marker is the system call that starts at its `0x0D` byte,
`0x299B..0x29A8`, which is what `tools/audit_eventb03_sound.py`'s timeline
reads; the original claim is kept beside it), and the rectangle-copy
record at `0x29AF..0x29D2` copies surface 2 to surface 1. `BLL.MMO` decodes
to 640 by 400 pixels whose RGB channels are all zero; its SHA-256 is
`aa6ff07374778fbc24b8665fd39862a7428e8c034eec873783d8b524a104cc53`.
The following state-dependent presentation branch either copies surface 1
or invokes routine 21 before continuing. This interval contains one black
resource load, not two independently confirmed blackout transitions. DEF22
and DEF21 follow the registered `DEF_MAIN.MES` bodies
`0x1109..0x116E` and `0x10C4..0x1102`; their shared presentation calls must
not be described as a newly proven background restore or flash effect.

### Native SE, argument storage, and polling evidence

Presentation subcommand 6 dispatches through `0x0042823C`, adapter
`0x00429D70`, and handler `0x00429E00`. Routine 9 begins with a selector-1
record at `0x0EAD..0x0EB9`, containing the selector and a channel expression
reading `global_i32[2]`. Each selector-0 record contains exactly three typed
records: the selector, a literal filename, and the same channel expression.
The final record-list terminator belongs to the compound instruction.
Instruction schema v45 preserves that whole envelope as `effect_dispatch`
or, for the confirmed literal named request, `effect_request`; filename and
expression payload bytes cannot execute as numeric-write shadows.

Native selector 0 stops the selected receiver at `0x00429E66`, loads the
named archive entry at `0x00429E7F`, installs the stream at `0x00429EA0`,
and starts it at `0x00429EB4`. Loader `0x0043E220` uses the collection
configured from `ArcEffectName` / `se.Arc` at `0x0043C307..0x0043C41A`.
The WaveThread and WaveNotify vtables at `0x0047AF94` and `0x0047B014`
share start slot `+0x28 = 0x0040E730` and stop slot
`+0x34 = 0x0040EAB0`. Start rewinds the stream with `SetFilePointer` at
`0x0040E770`, resets DirectSound position at `0x0040E887`, and invokes
DirectSound Play at `0x0040E8B1`. Selector 1 invokes the same stop slot at
`0x00429F14`; its downstream handler stops the buffer and closes the stream.
There is no same-filename suppression in this wrapper: a successful load
starts again, including when the next call replaces an unfinished clip.
Device acceptance and physical speaker output remain unobserved.

Command 09 writes at `0x00418CBD/0x00418D05` and expression-token F6 reads
at `0x004060A6` address the same original storage,
`common_state + 0x3000 + index * 4`. The differing receiver displacements
reduce to the same common virtual-base field after their respective `this`
adjustments. Thus temporary arguments and `global_i32` are not separate
original storage domains. **Modelled since Core 0.377.0 (TD-56):** the generic
interpreter writes a command `0x09` run into `global_i32` and reads routine 0's
message id and routine 23's selector from `global_i32[1]`; its `argument_slots`
dictionary is provenance only ([Format and Method](format_and_method.md),
"Command `0x09` and token `0xF6` address one storage", which also records the
unwritten-value assumption and that command `0x16` stays argument-slot only and
unresolved). The bounded EVENTB03 adapter projects the source-qualified
caller's argument slots 1 and 2 into a disposable cloned sandbox before running
routine 9, captures the post-projection baseline, and rejects any subsequent
state diff. It does not change shared gameplay state; since 0.377.0 its
projection writes values the runner already holds in `global_i32`, so it is a
no-op projection of equal values, and its retirement is a separate decision.

The interleaved presentation subcommand 12 routes through `0x0042B040` to
`0x0042B070`. For a nonzero argument, `0x0042B0C7..0x0042B0D4` computes
unsigned `floor(argument / 3)` and passes that threshold to `0x0043E910`.
The latter resets and polls a document counter. Background service
`0x0043EA00` increments the counter with a nominal 15 ms tick. Therefore
arguments 20 and 40 correspond to thresholds 6 and 13, not literal
milliseconds. Input, control flags, tick phase, and scheduling can change
the original elapsed time or end the loop early.

The tool preserves each call followed by its exact source poll boundary,
uses nominal tool-clock delays `[90, 195, 90, 195, 90, 90]` milliseconds,
then resumes MES order. A later occurrence stops/reloads/restarts the same
effect channel. Input and autodrive are blocked during these bounded tool
delays; native early-interruption behavior is not reproduced. The wait is
not derived from WAV duration. This is an explicit deterministic transport
policy, not a measurement or claim of native wall-clock equivalence.

Reproduction: `tools/audit_eventb03_sound.py` reads the original MES, SE,
MMO, and executable inputs, checks exact source envelopes against the current
GDScript decoder, verifies source-ordered call and text coordinates, checks
Wave/PCM and native-helper fingerprints, and confirms original inputs remain
unchanged. `tests/test_audit_eventb03_sound.py` covers synthetic byte
mutations, truncation, unanchored decoys, payload-shadow receipts, wrong
filenames/channels, deduplicated occurrences, and false inserted text
boundaries. No original dialogue, bytecode dump, or media is tracked.
Confidence: **Confirmed** for the bounded source order, compound boundaries,
SE archive routing, same-channel restart, storage alias, and polling
threshold calculation; **Tool policy** for deterministic delays and the
scoped argument projection; **Unresolved** for audible timbre, physical
output, exact native timing, and a count of visible blackout transitions.

User-controlled Event Player listening accepted the first-blackout pair from
merged `main` commit `a88ecc33`. This is tool-output acceptance, not a new
original-engine observation or proof of native device timing; other manual
presentation and cross-session checks remain separately tracked.
