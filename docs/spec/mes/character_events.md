# MES Analysis: Maki Character Events

This document records the current EVENTB01, EVENTB02, EVENTB14, EVENTB15, EVENTD01, EVENTD02,
EVENTD03, EVENTD05, EVENTD06, EVENTD08, and EVENTD14 projections without reproducing
their dialogue.

> Coordinates, 2026-09-13. Every dialogue boundary below was recorded at the
> `02` byte of the message wait's trailer, where the separator framing stopped.
> Since Core 0.316.0 frames command `0x0D` as one system call
> (`format_and_method.md`, "Command `0x0D` is one system call") the same
> boundary is reported at the wait call `0D 13 FF 02 02 FF 00`, three bytes
> earlier; resume offsets are unchanged. The Event Player and its validators
> carry the new coordinates; the figures in this document stay as measured and
> read three bytes high.

## EVENTB01 Callee And Caller Route

**Scene role:** Mahoko event whose current tool projection covers the original
caller, coordinate-zero setup, time-routed background, all seven dialogue
boundaries, the callee return, and the bounded original 13C BGM/MACHI suffix.

**Container and caller binding:** authoritative `mes.arc` SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`,
`EVENTB01.MES` SHA-256
`3c4ba17751eb362130fef821e00bb7b1d2f7f909652a9a6c876bf6da0f8efadf`,
and `13C.MES` SHA-256
`f138846e397154a56f91b44462f90633ad15978ee1eba4e6399d50a247fbb216`.
The `13C.MES:0x0F93..0x0FA3` command-`0x0F` envelope names
`EVENTB01.MES`, ends at physical caller resume `0x0FA3`, and has SHA-256
`e3d9193f89fe88527b97b78001eae47c3070d90bbe190cfd7706e5e6af9c1894`.
The envelope contains no coordinate operand. Configured-original executable
audit v38 independently confirms that command `0x0F` enters the named callee at
coordinate zero, saves the caller coordinate, and restores it after return.
Evidence type: direct authoritative ARC entries plus original executable
handler audit; confidence: **Confirmed** for target, physical resume, and
zero-coordinate entry.

Confirmed bounded prefix:

- `EVENTB01.MES` contains seven address-table entries; entry zero is `0x0008`.
  Its exact `0x0000..0x0008` bootstrap transfers to that entry. The original
  route stops at shared routine `28` at `0x00E6` (resume `0x00EB`), then at two
  adjacent three-record command-`0x12` lists `0x0105..0x0110` and
  `0x0110..0x011B`. Event Player permits one explicit record-only omission
  action for this exact pair and fails closed on shifted or changed extents.
- After the bounded native records, the normalized path reaches shared routine
  `21` at `0x0269` (resume `0x026E`) and routine `28` at `0x0279` (resume
  `0x027E`). A seeded `global_u8[4000] = 1` becomes zero in the initial routine
  `28`, matching the previously audited shared prefix behavior.
- At `0x0288` the stored route assigns selector `14`; shared routine `23` at
  `0x028E` resolves `MAHOKO.WAV`. The voice marker begins at `0x02BF` and
  resolves `B0796.OGG`. Original-entry SHA-256 bindings are
  `5cb732ef0e7da00eefc657833de7679935d8ccbbbf6681d1c50dfffc8a0f4ee8`
  and `c6b91e2f24c10720b7580e2f168f5efb2831d001c69ef6a60e96496c80628667`
  respectively. Audio payloads are validated through the shared read-only
  resolver; native device output is not claimed by headless tests.
- The first original dialogue boundary is `0x031D`, with physical resume
  `0x0321`. The complete zero-to-resume slice SHA-256 is
  `5a5a6d032e6c8c2f7bae8491ba722aa0d405dafb7cbde05c04328340ac276248`.
  Event Player continues through dialogue boundaries `0x038A`, `0x0402`,
  `0x0445`, `0x0496`, `0x04D9`, and `0x0542`; their physical resumes are
  `0x038E`, `0x0406`, `0x0449`, `0x049A`, `0x04DD`, and `0x0546`.
- The post-dialogue route crosses routine 28 at `0x0578`, routine 32 at
  `0x059D`, routine 25 at `0x05EC`, and the exact three-record command-`0x12`
  span `0x05F1..0x0609`. That native span has SHA-256
  `bf879df6003bde083e4b7840799e9c83d940aa116d948f6dd3baae64e3101bae`
  and receives one explicit record-only omission. Routine 28 at `0x0614`
  precedes return `0x06A0`. The exact zero-through-return slice SHA-256 is
  `2f605475d4ccb184532c8023457c8ca924230d7fdf8784546404b81fbd3df260`.
  The later dialogue voice is `B0797.OGG`, original-entry SHA-256
  `8a7d7028ae473a6c9046dc8f1427fca34776fee6b018470bd6f83c4c12c52175`.

After return, the saved `13C.MES` caller resumes at `0x0FA3`. Its exact
date-selected BGM prefix ends at common boundary `0x1017`, with slice SHA-256
`119f00e6cafdd34982486d8442ecf968ecaae23926019a70f37bc32cc6fe996c`.
`state_u16[7]` value 1224 selects selector 26 `X_MAS.WAV`, 1301 selects
selector 42 `SHOGATU.WAV`, and other tested values use selector 1 `IDOU.WAV`.
The exact `0x1017..0x102F` suffix SHA-256 is
`fa13bb05b7d3a7ca2e993752c3498a3a22a83a49ddd64d8edae04c5328e62a19`;
it writes `global_u8[286] = 1` and stops at the `MACHI.MES` command-`0x0E`
marker `0x1022`. The native consumer after that marker is not executed.

The time branch reaches `B01Z.MMO` marker `0x01B0` before `0600`,
`B01X.MMO` markers `0x01CF` and `0x01EE` for the daytime bands,
`B01Y.MMO` marker `0x020D` for `1600..1759`, and the second `B01Z.MMO`
marker `0x0220` at `1800` and later. The authoritative X/Y entry SHA-256 values are
`7f1db8404795365782a5f4128cc7a1a21c6367dfd17d352eb505fe822e175a36`
and `11fdb49bc7f19bd4476fbba278a63a1497b73a7d50aae448b29d8021fb83c6d6`.
The default/night branch names `B01Z.MMO`, which is absent from the original
`mmo.arc`; the tool retains an explicit missing-resource frame instead of
substituting X or Y. Original integration rehashes `mes.arc`, `mmo.arc`,
`bgm.arc`, and `voice.arc` after all three branches. Configured-original EXE
audit v38 independently confirms command-`0x0F` zero-coordinate call/restore,
selector-23 BGM dispatch, command-`0x12` record ingress, and command-`0x0E`
active-string storage. Confidence: **Confirmed** through the caller handoff;
**Unresolved** for omitted native record effects, MMO composition, audible
device output, and the host consumer after `MACHI.MES`.

**Catalog preservation check, 2026-09-06.** Content Core `0.289.0` moves
the B01/B02 caller specifications into Event Catalog v3, revision 17. The
catalog combines the existing source identities and explicit return/postlude/
handoff terminal references with the already audited BGM and suffix metadata.
Direct read-only rechecks match the original `13C.MES`, `EVENTB01.MES` and
`EVENTB02.MES` entry hashes and all four caller slice hashes: B01 BGM
`[0x0FA3, 0x1017)` and suffix `[0x1017, 0x102F)`, B02 BGM
`[0x10DD, 0x1151)` and suffix `[0x1151, 0x1169)`. The respective intro
anchors remain `13C.MES:0x0F93` and `13C.MES:0x10CD`, with their original
zero-start callees. The three BGM representatives remain dates 1224, 1301
and default 500; the post-handoff assertion remains `global_u8[286]=1`.

Event Player obtains the same typed 18-field specifications from the catalog,
including integer date/selector/trace/state values after JSON loading. The
shared `MesCallerRoute` validator still checks source bytes, executes all
three BGM representatives and verifies the handoff trace and state diff.
Evidence type: direct original entry/slice hashes, catalog projection parity
and read-only replay. Confidence is **Confirmed** for preservation of these
existing bounded routes. No additional native effect or host behavior is
confirmed, and the outer `MACHI.MES` host remains unexecuted.

## EVENTB02 Callee And Caller Route

**Scene role:** Mahoko event whose current projection follows the original
coordinate-zero caller through time-routed background/AN-source/AX setup,
all eight dialogue boundaries, the callee return, and the bounded original
`13C.MES` BGM/MACHI handoff suffix.

The authoritative `EVENTB02.MES` SHA-256 is
`fb389f8cd72afb8b5f8f3b6b9c00255c00fce95312cb91f9fbdfb5499f515d89`.
The original `13C.MES:0x10CD..0x10DD` command-`0x0F` envelope names the
callee, ends at physical resume `0x10DD`, and has SHA-256
`6d4fcad9288ba902067455f731d1414c71e16a23efb44970cba44bbc197ef634`.
It contains no coordinate operand; original executable audit v38 separately
confirms that the command-`0x0F` handler enters the named callee at coordinate
zero and restores the saved caller coordinate. Evidence: authoritative ARC
entries plus original executable handler audit; confidence: **Confirmed**.

The exact bounded sequence is entry zero `0x0008`, routine 28 at `0x00E6`
(resume `0x00EB`), adjacent three-record command-`0x12` lists
`0x0105..0x0110` and `0x0110..0x011B`, routine 21 at `0x0269` (resume
`0x026E`), and routine 28 at `0x0279` (resume `0x027E`). Only the exact native
pair receives the explicit record-omission action. The traced presentation then
reaches the selected B02 background, B02 `AN` source-surface marker at the daytime
`0x02DF` path, its AX record at `0x02EE`, AX binding `0x03B7`, selector 14 at
`0x03E6`, routine 23 at `0x03EC` for `MAHOKO.WAV`, voice `B0798.OGG` at
`0x041D`, and first dialogue boundary `0x0469` (resume `0x046D`). The complete
zero-to-resume slice SHA-256 is
`263961710d7a1043510e88fa20c99bce743e07dfa6c3c78b894162308bbf509c`.
Immediately before the time-routed `AN` marker, command `0x07` at
`0x0295..0x029C` writes `banked_u16[0][1] = 8`. Executable audit v69 binds
that storage cell to native active-surface state `+0x20BA`; presentation
subcommand 9 then decodes the selected B02XAN/B02YAN MMO into surface 8.
This is the confirmed producer for the following B02 AX source rectangles,
not a detached-image guess. Evidence type: authoritative MES command order,
sandbox trace of the active-surface value at the MMO marker, and original
executable state-pointer/consumer disassembly; confidence: **Confirmed** for
the selected B02 route's source surface, **Unresolved** for native tick cadence
and the general lifetime of surface 8 outside this bounded route.
The confirmed dialogue boundaries/resumes are `0x0469/0x046D`,
`0x04DC/0x04E0`, `0x0572/0x0576`, `0x05E1/0x05E5`, `0x0653/0x0657`,
`0x06C4/0x06C8`, `0x0707/0x070B`, and `0x0770/0x0774`. The post-dialogue
route stops only at routine 28 `0x07A6`, routine 32 `0x07CB`, routine 25
`0x0815`, the exact two-record command-`0x12` envelope `0x081A..0x0822`,
and routine 28 `0x083D` before command-`0x00` return `0x08C9`. Its complete
zero-through-return SHA-256 is
`94618ab20c9c54878fb5106a252c77fd34c0668485d9c581efb538f9cc5f1386`.
At the callee return the tool exposes the exact saved caller resume instead of
declaring the outer event complete. The authoritative `13C.MES` SHA-256 is
`f138846e397154a56f91b44462f90633ad15978ee1eba4e6399d50a247fbb216`.
From resume `0x10DD`, the hash-bound prefix reaches the common post-BGM boundary
`0x1151`: `state_u16[7] == 1224` requests selector 26 `X_MAS.WAV`, value 1301
requests selector 42 `SHOGATU.WAV`, and every other tested value uses selector
1 `IDOU.WAV`. The exact `0x10DD..0x1151` slice SHA-256 is
`c6a4812dc69869fd7ebf173cba6ba874d541bca726fa3e2e4be38a47550d1772`.
This prefix changes no sandbox state.

The exact caller suffix `0x1151..0x1169`, SHA-256
`6d1dc4a142081f52483fce4d58477904b5b24ca78ec83651b8bf5cecf151862c`,
writes `global_u8[286] = 1`, crosses the source-line marker at `0x1157`, and
stops at the `MACHI.MES` command-`0x0E` envelope `0x115C..0x1169`. The tool
does not execute the native host consumer after that handoff. Original
executable audit v38 independently confirms command-`0x0F` caller-coordinate
restore, the selector-23 BGM request path, and command-`0x0E` active-string
storage; the subsequent host use remains **Unresolved**. Evidence type:
authoritative `mes.arc` slices, sandbox runner replay for the three date routes,
and configured-original executable audit. Confidence: **Confirmed** through
the handoff boundary; **Unresolved** after the native handoff consumer.

Original-entry fingerprints are B02X/B02Y MMO
`dc6e415b17029df82cd79dbf1ed9f0ea9771414be5bbab2c755a536ec7590a9e` /
`8484896b5b9a8e0a17f087a01d0d589ccaaa8fb9469507827aff14825eadf279`,
B02XAN/B02YAN
`8ed5b4fa85ec3e24517298ce3f04a35bbb5e8379893be2d194de3bc593e9fc36` /
`a17e16da94100e2c406855be4ab543fb0fd56c11d6c659074ecb48caf889fb60`,
and B02X/B02Y AX
`8443fb964acd4e747d3826785848b72e19492a12c9bce3f83533c15be6de746d` /
`e8c4d2756ec333c2ebf3511bb563822e98ff1b2fbfc59c6742ff80318585c7b0`.
The original B02Z, B02ZAN, and B02Z.AX entries are absent; the tool reports
those missing references without substituting X/Y media. Direct strict
decoding gives a 104x336 B02XAN source strip and a 128x336 B02YAN source
strip. The authoritative B02X/B02Y AX entries each expose exactly three
type-0 shared records in cell `(0,0)`, stream `0x0554..0x0652`. X divides the
strip into `(0,0,104,112)`, `(0,112,104,112)`, and
`(0,224,104,112)` and copies each record to destination `(216,48)`; Y uses
the corresponding 128x112 source rectangles and destination `(216,56)`.
The stored dispatch order is `0,1,2,1,0,1,2,1,0,1,2,1,0`, with two
control-`0x05`/`0x06` count-10 loops between blink groups. Configured-original
executable audit v38 independently reaches step function `0x00410D60`, the
per-cell countdown fields, the `0x05`/`0x06` loop state, renderer
`0x00411330`, and the RGB-`0x00FF00` three-byte keyed copy into surface 0.

Event Player now crops those three source records and displays one keyed frame
at the exact AX destination over the retained 640x400 B02 background. It
expands the original command and loop order with a 60 Hz **tool clock**. The
native host's wall-clock call cadence remains **Unresolved**, so the UI labels
that limitation and does not claim timing equivalence with the original
engine. Any changed pair, dimensions, record geometry, cell, stream extent,
loop expansion, or dispatch order stops animation fail-closed. Evidence type:
direct authoritative `mmo.arc`/`data.arc` inspection plus configured-original
consumer disassembly; confidence: **Confirmed** for frame slicing,
destination coordinates, keyed renderer, and command order; **Tool policy**
for 60 Hz scheduling; **Unresolved** for native wall-clock cadence.

## EVENTB14 Caller To Read-Only Choice Boundary

**Scene role:** Mahoko event whose tool projection follows the original route
through its outer and nested routine-40 DEF boundaries, explicit cloned branch
previews, and confirmed stored terminals. The one-based numeric result is
EXE-confirmed; native UI/effects and live caller restoration remain disabled.

The authoritative `mes.arc` SHA-256 is
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
`EVENTB14.MES` has SHA-256
`62f2ad10d02d595d2d4a7dc2a55fd575b53a99b0b9bba8aeae25dce4ad25a4ea`;
its 74-entry address table points entry zero to `0x0008`, and its exact
bootstrap is the standard command-`0x14` transfer to that coordinate.
The original `44M.MES` entry has SHA-256
`730e98edcd7ee49d7076c45876f114d02aa98454f744e473fc03f14a5b410b75`.
Its command-`0x0F` envelope `0xC915..0xC925` names `EVENTB14.MES`, ends at
physical caller resume `0xC925`, and has SHA-256
`7abac8409be21e94385e35403aa130d819b58f5492ad8a406131486ed2e68b7c`.
The envelope contains no coordinate operand. Configured-original executable
audit v38 independently confirms that this command handler enters the named
callee at coordinate zero, saves the caller coordinate, and restores it after
return. Evidence: authoritative ARC entries plus original executable handler
audit; confidence: **Confirmed** for target, physical resume, and zero entry.

The stored caller eligibility branch immediately before the presentation is
`44M.MES:0xC818..0xC867`. Its decoded condition is valid and includes
`banked_u16[0][210] > 80` at `0xC848..0xC84F`, together with weekday zero,
date `0916..1115`, the same date in `banked_u16[0][233]`, HHMM strictly between
1800 and 2200, `global_u8[205] == 1`, `global_u8[628] == 0`,
`global_u8[642] == 0`, and `global_u8[200] == 1`. Evidence: authoritative
`44M.MES` condition IR checked against the configured original archive;
confidence: **Confirmed** for the stored eligibility expression. The tool still
starts the confirmed callee directly and does not claim to execute the wider
44M scheduler.

The representative original caller context is therefore nighttime; HHMM
`1900` is the source-authentic preset value, with Mahoko affection above 80.
Direct authoritative `B_PIC.MES` replay under that state selects original
`B3.MMO`, reaches shared routine 22 at `0x04AF`, and resumes at `0x04B4`.
The exact stored night segment `0x0427..0x04B4` has SHA-256
`d2bbceb22dc28a7e1065cd2b0718c749901c23f1d5bf497f77f0c6da41879aa0`.
After that bounded return, the stored date test joins the existing Mahoko
affection route; value 81 selects `BAN.MMO`/`B.AX` row-zero column 2 and the
picture script returns at `0x0759`. Event Catalog therefore uses the complete
source-qualified state (`MMDD=1001`, HHMM `1900`, weekday zero, matching
banked date, affection 81, and the four exact eligibility flags) as its default
EVENTB14 preset. HHMM `0600` remains a compatibility/debug regression for the
separately audited daytime `B.MMO` route. Evidence: authoritative
`B_PIC.MES` replay against the configured original archive and the already
audited shared-library routine contract; confidence: **Confirmed** through
`0x04B4`, the high-affection face selection, and picture-script return.

Event Player now binds that envelope to the common
`kakyu_event_player_caller_frame/v1` before starting the callee and retains the
frame through every explicit cloned outcome. Direct authoritative replay from
physical caller resume `44M.MES:0xC925` follows the stored continuation to an
`IDOU.WAV`-family routine-23 request at `0xFF34`, registers two caller-owned
DEF rows at `0xFF59` and `0xFF78`, and stops at routine 40 `0xFFBA`. The exact
stored slice `0xC925..0xFFBA` has SHA-256
`ef4c1827fdc3fb5cd999c2e78499bb1917e967951d0e902dc0bfd7337d23f04e`.
Because this is a second unresolved native choice interface, the tool validates
and records the boundary but does not resume it or apply the cloned EVENTB14
result to the live sandbox. Evidence: authoritative `mes.arc` replay and
original executable v37 command-`0x0F` restore evidence; confidence:
**Confirmed** for frame identity, physical resume, BGM request, DEF registration,
and fail-closed caller boundary; **Unresolved** for the caller routine-40 result.

**Catalog terminal ownership correction, 2026-09-06.** Catalog v5/revision 20
binds the option-2 completion to `EVENTB14.MES:0x230C..0x2319`, the aligned
command-`0x0E` handoff naming `MACHI.MES`. The old catalog attributed that
numeric coordinate to `44M.MES`, where it lies inside an argument-slot write
record at `0x2306..0x230E`, not a handoff. Options 1 and 3 instead return at
`EVENTB14.MES:0x08FA` and `0x291E`, respectively, with physical caller resume
`44M.MES:0xC925`; both retain the unresolved caller choice at `0xFFBA`.
The catalog now gives those options separate return/choice terminal references.
The option-2 handoff carries no `state_u16[21] == 2` final-state assertion,
because its nested choice reuses that slot. The entry remains a nested call
with partial playback; the correction does not establish a caller choice
result or execute the host handoff. Evidence: current Python Phase 1-4 typed
IR over the hash-bound authoritative entries above, catalog owner-matching
regressions and the existing three-choice B14 integration. Confidence:
**Confirmed** for source ownership and structural coordinates; **Unresolved**
for the caller choice and outer host execution as before.

**Catalog caller-choice projection, 2026-09-06.** Core `0.292.0` / catalog
v6 revision 21 moves the existing B14 caller-frame specification and accepted
BGM names into catalog metadata. The shared original-source validator binds
the command-`0x0F` dispatch at `44M.MES:0xC915` to its actual structural record,
checks the stored suffix hash above, and repeats the fresh default sandbox
probe from `0xC925` through routine 23 at `0xFF34`, DEF registrations at
`0xFF59`/`0xFF78`, and routine 40 at `0xFFBA`. The catalog's two callee-return
witnesses retain their separately indexed command-`0x00` boundaries.
Every executed caller trace record also retains the exact source/end/command
of its container's structural index, so a jump into record payload cannot
supply a BGM request, intermediate state write or terminal witness.
Evidence: hash-bound authoritative `mes.arc` records and shared headless replay;
confidence remains **Confirmed** for these stored structural coordinates and
the default-state probe, **Unresolved** for the caller choice result. This
consumer migration neither applies the cloned callee state to the live caller
nor proves all BGM date branches or native choice effects.

The callee does not load its own picture or BGM before the choice. Its caller
does, however, inherit a normal conversation presentation. In `13C.MES`, the
audited `0x033A..0x0352` setup clears `global_u8[206]` and dispatches
`B_PIC.MES`; the slice SHA-256 is
`bc6e2ad444ce1b913f31770242a4c2186c49169cad87f57252b5b53b3d562060`.
Immediately before the event call, `44M.MES:0xC8F8..0xC925` sets that byte to
one, dispatches `B_PIC.MES` at `0xC903`, and then dispatches `EVENTB14.MES` at
`0xC915`; the combined slice SHA-256 is
`b5e35635626fb201083422865f17306ca7fef112261a72646ff1063ea108cb0f`.
The original `B_PIC.MES` entry SHA-256 is
`d72612395e8571848a7782ff48d8c63604a09a983ae2c564f2ee5bd5ac2b4ada`.
Its daytime-compatibility setup reaches shared routine 22 at
`0x0141/0x0146`. Its caller-qualified night setup reaches the same routine ID
at `0x04AF/0x04B4`; both paths then select the date/affection-dependent face
route and return at `0x0759`. The expression update also returns there.

The source-qualified presentation binds original `B3.MMO` (640x400,
SHA-256
`54c70478e72da6e8a5ba32b6a65c6d24eaaeb2470c6c949fbef418a31f54fffe`)
as the nighttime green-key Mahoko standing layer. The compatibility replay
uses original `B.MMO` (640x400, SHA-256
`d3dca1a1d3cfb370075fea081cfafc6073f1b6fdefe97bc0588b17594951e4ba`).
Original `BAN.MMO` (640x400, SHA-256
`2396f5b441ccaa4a6cda7312445bebc5757658bc90ea78d1af691d16d1f46127`)
is a 3-column by 4-row face source. Original `B.AX` (SHA-256
`df838dcd6d12af49469053e392e01292eccacce3efc7d9ef17c0fd87388af474`)
contains twelve 96x80 shared draw records, all targeting `(264,72)`. The
confirmed row-zero binding selects one of three cell streams and repeats the
local-frame order `1,2,3,2,1,0` three times. Event Player overlays these four
green-key frames on the standing layer with its explicitly labeled 60 Hz tool
clock; native host cadence remains unresolved.

`B_PIC.MES` reads the same Mahoko affection slot. Direct original-entry replay
confirms the row-zero B.AX face columns as `0..30 -> column 1`,
`31..70 -> column 0`, and `71+ -> column 2`; the two threshold decisions occur
at the expression route around `0x0568` and `0x06C2`. Event Player exposes
Mahoko `banked_u16[0][210]` separately from Maki
`banked_u16[0][212]`, and the catalog-qualified value 81 selects column 2.
Evidence: authoritative `B_PIC.MES` replay at the exact threshold neighbors;
confidence: **Confirmed** for these ordinary fresh-flag face bands.

The outer location layer is not loaded inside the `44M` event address row.
Authoritative `MACHI.MES` location ID zero instead reaches the `44M.MES`
handoff at `0x52EE` after its `state_u16[21] == 0` dispatch. Direct original
`mmo.arc` reads find the matching `44M_1.MMO`, `44M_2.MMO`, and `44M_3.MMO`
family; all three decode to 640x400 and have SHA-256 values
`3bd7ad2828d6502fe018c123d439d9e6d08d3ce53c1fe7857c9da2ab4d73c21c`,
`5970a0d7f875837f52ca1c7731033d7b8d0e289a7e5934367844a1e16b5f5654`,
and `9b07d722ec47f3101165bb51bde125a04b400510936be986552c7c4fdf5cbe75`.
Direct decode of the authoritative `44M_3.MMO` shows the nighttime dormitory
exterior/front gate. This is the original visual start location for the
caller-qualified route, not an interior room. Evidence: original `mmo.arc`
decode plus the `MACHI.MES:0x52EE` location-zero handoff; confidence:
**Confirmed** for the stored pixels and dispatch, and **Descriptive** for the
friendly location label.
`TIME_C.MES` SHA-256
`010d75fcfa434832cc4a4bc48e37aecf7bf8250cc55fad146f3b25d61629e26e`
confirms the shared palette bands: variant 3 before 0600, variant 1 through
1559, variant 2 through 1759, and variant 3 afterward. Applying those bands to
the called `44M` basename remains the documented location-family
**Projection**, not a claim that the EVENTB14 callee contains an MMO load.
Event Player labels that evidence level and composes the selected 44M frame,
then the date-qualified `B3.MMO` or compatibility `B.MMO`, then the
`BAN.MMO`/`B.AX` face overlay.

The direct zero-start runner reaches voice marker `B0829.OGG` at `0x0102`,
then the first dialogue boundary at `0x0166` with physical resume `0x016A`. The
zero-through-resume slice SHA-256 is
`7f9b2e510b2239132593102f8b8d956f91be997e6a00514a4699425c2c85f3fb`.
The exact dialogue boundaries/resumes are `0x0166/0x016A`,
`0x01C3/0x01C7`, `0x0251/0x0255`, `0x028E/0x0292`, `0x031C/0x0320`,
`0x035B/0x035F`, and `0x03E5/0x03E9`. Voice markers B0829..B0832 occur at
`0x0102`, `0x01F0`, `0x02B1`, and `0x0388`. Their original-entry SHA-256
values, in order, are
`d24b3b3a05c221910f42fd1e1578ce0645839db77f4e2007907bc4f335217c1c`,
`e8e6130b8e77580c8137c8751f13505315ca418e25369560b99a14bee8a90778`,
`a265a03b2d077c8a7e51fa6a79209486928109af99545d1b8d513fdab3ebd318`,
and `f72bff3337f3487f6e45b02e892a7590ad159915e3096006902d6f623b261198`.

After dialogue seven the route registers DEF rows at `0x040F`, `0x044E`, and
`0x0491`, with bodies `0x0418..0x0449`, `0x0457..0x048C`, and
`0x049A..0x04C5`. Their body SHA-256 values are respectively
`90bca436c78e89c79ea9bfbdf99450ae51bf0bc1e6900ca4bd23d9627ac19c6d`,
`6b6861f295b22a8e04b18e8da42897787a7cb6eea72586c826c3e9e7ca2395a5`,
and `437bb53644d7d67407240bc71945db5f71d7bc7b45e1cc38bcdb5baa28e2231a`.
Routine 40 is reached at `0x04CF`; its physical end is `0x04D4`. The exact
zero-through-`0x04D4` SHA-256 is
`2de2f33dff4a82217003bc1cb1906d5508d792cfd3024b30fa56629613f22075`.
Event Player shows these rows as read-only original DEF options and permits
detached body inspection. The stored suffix first tests `state_u16[21] == 1`
at `0x04D9`, then `state_u16[21] == 2` at `0x0905`, with the remaining path
forming the third branch. EXE audit v41 confirms that the selected zero-based
row is stored as one-based result 1, 2, or 3. Because native UI/cadence and
effects are not executed, an explicit tool action clones the current
sandbox, set `state_u16[21]` to 1, 2, or 3, and resume at `0x04D4`. The first
resulting dialogue boundaries are `0x053A/0x053E`, `0x0965/0x0969`, and
`0x2383/0x2387`. Explicit tool continuation can replay the same cloned route
through four, four, or ten dialogue boundaries respectively:

After this explicit selection, Event Player clears the active choice
projection and locks that stored branch until it ends or reaches the distinct
nested choice at `0x133F`. Pointer, number-key, and arrow input therefore cannot
reselect one of the outer DEF rows while outcome dialogue is displayed. The
same lock applies after a nested row is selected and through its B_PIC return
and post-picture dialogue. This is a tool input-safety rule; inspecting another
outcome requires returning to the corresponding choice boundary.

- value 1: `0x053A/0x053E`, `0x05A4/0x05A8`, `0x05FB/0x05FF`, and
  `0x068D/0x0691`; then routine 27 at `0x0701/0x0706`, routine 25 at
  `0x070D/0x0712`, routine 21 at `0x0747/0x074C`, and the exact three-record
  command-`0x12` envelope `0x07AF..0x07BA` are processed only in the clone.
  Two final dialogues at `0x088F/0x0893` and `0x08E4/0x08E8` lead to callee
  return `0x08FA`;
- value 2: `0x0965/0x0969`, `0x09D1/0x09D5`, `0x0A22/0x0A26`, and
  `0x0A8C/0x0A90`. With an explicit valid legacy MMDD and the hash-bound
  `START.MES` calendar projection retained in the clone, the selected DEF body
  identifies the children’s park destination. After the four acceptance
  dialogues, the stored route does not reopen the town map or ask for another
  destination. It requests a date-dependent movement cue: the ordinary-date
  branch assigns routine-23 selector 1 at `0x0B01` and invokes it at `0x0B07`,
  resolving to original `IDOU.WAV` (SHA-256
  `70124bbd530722ded5a5e046e1fd17505e541f4b1ee0fa75380c7c4f024fcc2f`);
  the exact `EVENTB14.MES:0x0B01..0x0B11` assignment, request, and following
  source marker have SHA-256
  `dbd886a4e52e5464d614494992a4c6bb639916f004583d9a65bc971c8a38d040`.
  The two calendar-special branches use selectors 26 and 42 instead. It then
  increments Mahoko affection
  `banked_u16[0][210]` by one at `0x0B11`, runs routine 33 at
  `0x0B30/0x0B35`, routine 25 at `0x0B7F/0x0B84`, omits only
  the exact two-record command-`0x12` envelope `0x0B84..0x0B8C`, and invokes
  registered DEF17 at `0x0BCD` and DEF11 at `0x0BE1`. DEF17 returns through
  shared routine 3; nested DEF12 scans the projected calendar row, returns
  through routine 26, and DEF11 returns. On the source-authentic nighttime
  preset, routine 33 has five rows and changes cloned `banked_u16[0][1]` from
  0 to 7; routine 25 has 70 rows and changes cloned `global_u8[3000]` from 0
  to 4; routine 26 has 136 rows and projects the legacy date through cloned
  `state_u16[0]` 0 to 27, `state_u16[9]` 0 to 27, and `state_u16[10]` 1001 to
  1028. A later nested DEF12 replay sees the already projected index 9 and
  therefore repeats only the exact index-0 and index-10 changes. These are
  replay contracts in the discarded branch clone, not live game-state writes. Shared
  routine 32 at `0x0BF0/0x0BF5` then leads to dialogues
  `0x0C2C/0x0C30` and `0x0C83/0x0C87`. The clone omits only the exact
  four-record command-`0x12` span `0x0C9E..0x0CAC`, returns through routine
  28 at `0x0CBC/0x0CC1`, then omits the exact three-record span
  `0x0CE5..0x0CF0`. The stored route loads `B14.MMO` at `0x0D7A`, crosses
  routine 21 at `0x0DE5/0x0DEA` and routine 28 at `0x0DF5/0x0DFA`, then
  writes `banked_u16[0][1] = 8` at `0x0E0C..0x0E13`, loads `B14AN.MMO`
  through the exact outer record `0x0E13..0x0E22`, restores
  `banked_u16[0][1] = 7` at `0x0E22..0x0E29`, loads `B14.AX` at `0x0E29`,
  and binds AX cell
  `(0,0)` at `0x0E54`. Original `B14.MMO` is a 640x400 background with
  SHA-256 `b6bf38283744daf728ca93b5f141e98cb186a127b31a2e7c8d118919a592e9e8`.
  `B14AN.MMO` is a 240x384 source atlas with SHA-256
  `6d45560026e0b8f9c8123c17b2e11caa323e7a6b2ab388a8ff27ff85602c2115`;
  original `B14.AX` SHA-256
  `1557e12fd54f25cbf6084e3c371c06a47d08562dfcb52cc1aaad0a7bcd7545e6`
  selects four 120x128 records placed at `(400,8)`. Event Player retains the
  background and cycles those keyed frames with its labeled 60 Hz tool clock;
  the exact native cadence is not claimed. Executable audit v69 maps
  `banked_u16[0][1]` to active-surface state `+0x20BA`, so the original command
  order confirms that `B14AN.MMO` is decoded into native surface 8 before
  `B14.AX` consumes it; the following write restores surface 7. This closes
  the source producer for this exact event route without generalizing its
  lifetime or timing to unrelated AX entries. Direct decode of `B14.MMO` confirms
  the children’s-park event image named by the selected branch. After that
  scene setup, selector 44 is requested through routine 23 at
  `EVENTB14.MES:0x0E99`, replacing the movement cue with original
  `FURARE.WAV` (SHA-256
  `fe653c356570fb8ebf43ea96f32734983fe6ede1cf2c0f54cd40ce4ec99b090b`)
  before the first park dialogue at `0x0ED9`.

  Event Player represents this as one forced, noninteractive accompanying
  move. From acceptance through the first park dialogue it locks map,
  destination, and choice input while leaving normal stored-dialogue advance
  as the only navigation; plays the reached date-specific movement audio;
  applies only the audited sandbox state and shared-routine effects; retains the
  nighttime dormitory-front frame until the `B14.MMO` marker; and atomically
  replaces it with the park background plus B14AN/B14.AX overlay. It must not
  insert a town-map destination choice, invent a walk cycle, or infer a
  different location from filenames. A short fade or transition card is an
  allowed remake/tool presentation policy only when labeled separately from
  the original MES effects. Any missing marker, resource, state delta, or
  continuation tuple stops fail-closed before the frame swap. Evidence:
  authoritative EVENTB14 instruction order, original MMO decode, and
  configured-original audio/presentation consumer audit; confidence:
  **Confirmed** for sequencing, state, audio selection, and target pixels;
  **Tool policy** for transition duration.

  Eleven further dialogues occur at
  `0x0ED9/0x0EDD`, `0x0F18/0x0F1C`, `0x0F8C/0x0F90`,
  `0x0FCB/0x0FCF`, `0x103F/0x1043`, `0x107C/0x1080`,
  `0x10AE/0x10B2`, `0x110F/0x1113`, `0x1185/0x1189`,
  `0x11C2/0x11C6`, and `0x124E/0x1252`. One final explicit continuation reaches
  a second three-row routine-40 choice at `0x133F`. Its DEF registrations are
  `0x128D`, `0x12C6`, and `0x1307`, with targets `0x12C1`, `0x1302`, and
  `0x1335`; their body SHA-256 values are
  `2024b7aa8d420c0f747971ae033c3a8b99bff6d9af3e9100524f584af21a869c`,
  `8545930dd1a69c2b23f5d71cfe7a953448acadaba1ad3b33f3377ed1d3bbbe61`,
  and `9a018b64890ea1704e16e1bd9d33922bde013d71a773766b59cb0aa3e4d439cc`.
  The routine ends at `0x1344`. The stored suffix then tests
  `state_u16[21] == 1` at `0x1349`, `== 2` at `0x169E`, and `== 3` at
  `0x193A`. EXE audit v41 confirms that the selected zero-based row is stored
  as one-based result 1, 2, or 3. Event Player's explicit row action clones the
  exact choice state, writes
  only `state_u16[21] = 1..3`, and replays the corresponding stored dialogue
  branch from `0x1344`:

  - value 1 has eight boundaries/resumes: `0x13A4/0x13A8`,
    `0x1410/0x1414`, `0x1465/0x1469`, `0x14E1/0x14E5`,
    `0x1520/0x1524`, `0x15AC/0x15B0`, `0x15FB/0x15FF`, and
    `0x1665/0x1669`;
  - value 2 has six: `0x1700/0x1704`, `0x1732/0x1736`,
    `0x17B1/0x17B5`, `0x1825/0x1829`, `0x1862/0x1866`, and
    `0x18DE/0x18E2`;
  - value 3 has thirteen: `0x198C/0x1990`, `0x19F0/0x19F4`,
    `0x1A5F/0x1A63`, `0x1ADF/0x1AE3`, `0x1B1E/0x1B22`,
    `0x1B50/0x1B54`, `0x1B99/0x1B9D`, `0x1C11/0x1C15`,
    `0x1C82/0x1C86`, `0x1D0C/0x1D10`, `0x1D4D/0x1D51`,
    `0x1E19/0x1E1D`, and `0x1E7C/0x1E80`.

  These branches converge on routine 28 at `0x1ED9/0x1EDE`. **Finish Nested
  Outcome** executes that common suffix only in the clone: registered DEF80 at
  `0x1EEE/0x1EF3`, routines 27 at `0x1F1A/0x1F1F`, 25 at
  `0x1F26/0x1F2B`, and 21 at `0x1F60/0x1F65`, registered DEF11 at
  `0x1F81/0x1F86`, routine 32 at `0x1F96/0x1F9B`, and routine 28 at
  `0x1FA6/0x1FAB`. DEF80 is the original `DEF_MAIN.MES:0x1335`
  registration with body `0x133C..0x1518` and SHA-256
  `c5c7de68beea51c81b02b0067e777666fbb287d38bfd8fe8d8739429cedab4aa`.
  The caller segment `0x1EF3..0x1F1F` contains complete selector-6
  `0x1EFD..0x1F04` and selector-8 `0x1F04..0x1F0B` native AX controls before
  the routine-27 boundary. Exact one-record consumption yields seven caller
  trace rows; the former nine-row expectation counted one shadow MES command
  inside each native payload. This correction does not change routine 27's
  separate four-row library trace or its one omitted native effect.
  The suffix reaches the stored `B_PIC.MES` command-`0x0F` dispatch
  `0x1FC0..0x1FCD`. **Run B_PIC Return** executes that original target at
  coordinate zero in the clone. All three stored branches carry
  `global_u8[206] = 1`, selecting the exact `MAHOKO.WAV`, `BAN.MMO`, and
  `B.AX` expression route; it returns at `B_PIC.MES:0x0759`. The last
  authoritative EVENTB14 MMO records before that nested dispatch are
  `B14.MMO` at `0x0D79..0x0D86` and `B14AN.MMO` at `0x0E13..0x0E22`; no later
  EVENTB14 MMO record occurs through the `B_PIC.MES` dispatch. The target
  `B_PIC.MES` route loads `B3.MMO` and `BAN.MMO` layers but never loads a
  location background. Direct `MACHI.EVE`/`MACHI.CCD` evidence associates
  event 4 and entrance preset 4 with the `18M.MES` location family, and the
  decoded original `18M_3.MMO` is the night children's-park background. The
  tool therefore resumes EVENTB14 at `0x1FCD` by restoring the HHMM-selected
  `18M_1/2/3.MMO` location background and keying `B3.MMO` plus
  `BAN.MMO`/`B.AX` over it. `B14.MMO` remains the earlier event CG and is
  deliberately absent from the post-return frame. It also does not recreate
  the pre-move 44M dormitory-front frame. Evidence: authoritative MES marker
  audit v2, direct EVE/CCD/location-family reads, decoded original MMO media,
  user-confirmed native presentation, and original-executable subcommand-9 and
  RGB-key copy audit v41; confidence: **Confirmed** for stored marker order and
  media identities, **Source-qualified projection** for the unobserved native
  host surface lifetime. Five final dialogue boundaries
  `0x204D/0x2051`, `0x20B8/0x20BC`, `0x214C/0x2150`,
  `0x227E/0x2282`, and `0x22EB/0x22EF` include the original
  `B0856.OGG` marker at `0x1FEE`; routines 27, 25, and 21 are bounded at
  `0x2184/0x2189`, `0x2190/0x2195`, and `0x21CA/0x21CF`.
  The later caller segment `0x2150..0x2189` likewise contains selector 6 at
  `0x2167..0x216E` and selector 8 at `0x216E..0x2175`; its exact caller trace
  has nine rows rather than the former eleven shadow-split rows. Evidence type:
  read-only authoritative `EVENTB14.MES` byte scan, exact Content Core trace,
  and source-hash recheck. Confidence: **Confirmed** for both `[start,end)`
  boundaries and non-executing tool traces; native AX cadence and pixels remain
  **Unresolved**.
  Routine 21 lies between the third and final two dialogue boundaries and
  contains two native presentation spans that the tool currently omits. The
  exact authoritative routine body is `LIBLARY.LIB:0x03F2..0x0431`
  (slice SHA-256
  `db11e9ddcab29212cd8d27d2bb132c0be0f09b1c5b3fabe9c755d154a1e8aaa7`).
  It decodes as a confirmed mode-0 opaque copy of the full inclusive
  `0,0..639,399` rectangle from logical surface `1` to `(0,0)` on the surface
  selected by `banked_u16[0][23]`. Original-executable audit v41 independently
  confirms the subcommand-11 adapter and opaque-copy helper. This proves the
  full-frame switch operation, but not which earlier host action populated
  surface `1` or the value/lifetime of the destination selector at this event
  boundary. The expected original presentation places the last protagonist
  monologue over the town/world map. Event Player now projects that frame from
  the separately confirmed `MACHI.MES` HHMM table: before 06:00 and from 18:00
  onward use `MACHIN_3`, 06:00..15:59 uses `MACHIN_1`, and 16:00..17:59 uses
  `MACHIN_2`. The 19:00 catalog preset therefore combines the effective
  `MACHI.MPC` 120x80-cell layout with the original `MACHIN_3.DAT/.PAL` tile
  atlas. Event 4 and `MACHI.CCD` entrance preset 4 bind the children's park to
  camera cell `(80,32)` and actor cell `(95,40)`. Event Player takes a 640x400
  native-1:1 crop at that camera and composites original `CHARA.DAT/PAL` frame
  1 at viewport pixel `(240,128)`. This replaces the park dialogue frame only
  after routine 21, before dialogues four and five. Dialogues one through
  three retain `18M_3.MMO` at the 19:00 preset; they never combine the B14 event
  CG with standing art. Showing the raw 640x400 atlas as a frame is invalid.
  Original and edited effective MPC/DAT/PAL inputs both use the shared
  ARC-backed compositor; an extracted or local full-map PNG is never a runtime
  input. This is a source-qualified tool projection, not a claim
  that the exact native surface producer has been proven. The
  configured-original executable audit v68 narrows that producer family. The
  complete engine surface-dimension table makes logical surface 1 a 2688x864
  buffer. Exact native writes of value 1 to the active-surface state at runtime
  addresses `0x00413323` and `0x00439217` belong respectively to RTTI-bound
  `CBGSelect` and `CNormalSelect` selection-presentation render paths. Their
  constructors, secondary vtables, entry virtuals, and renderer calls are all
  checked by the audit. This proves that native selection screens can target
  surface 1, but no checked call frame connects either object lifetime to
  `LIBLARY.LIB:0x03F2` in EVENTB14. The ARC-backed MACHI frame therefore
  remains a source-qualified projection rather than a native-surface
  attribution. The
  authoritative `MACHI.MES` entry SHA-256 is
  `56b0f4243f3c0944624ea0ef11b369391761ff394816775264c144bb76391488`;
  its time-selection region `0x00E0..0x0190` has SHA-256
  `7766434061b6c712ae33566cf8f653266ceaa8d660d8021d42c4053d758d2c42`.
  All three original DAT index planes share SHA-256
  `3a4111f6ff91c477e41689cc2ba83a7e2cc1000744c2c9f9d68d560cdbd334e4`,
  while the `_1`, `_2`, and `_3` PAL SHA-256 values are respectively
  `18379d87b5e4d9ae17c33ba92caee59fb5d3f8145b38c0ad33cc0d6b594bef70`,
  `d2ed22d3efda4533714af37dd110ce6b4966116674769097c3c9f43c71e31c86`,
  and `f13d98d2a08f46cba1de3e79b3cfb943f6d08c9289afc2f0312899cf3553a07b`.
  Original `CHARA.DAT` and `CHARA.PAL` are bound by SHA-256
  `7f3e0e25322ffea1755a02b23505644c0e3b7d224cfa2c7c013dc132c17a4e54`
  and `02bc805c2f97fdc344ced8daf99ca999b90f3840121881a2a19b6a976e643bc0`.
  The later command-`0x0E` handoff naming `MACHI.MES` occurs only after
  those final dialogues at `0x230C`; configured-original EXE audit v41 confirms
  that command as a host-consumed active-string/presentation handoff, not a
  synchronous nested script call. Accordingly the projected world-map pixels
  are attributed to the independent MACHI HHMM resource table and the
  routine-21 presentation boundary, never to command `0x0E`. Routine 21's exact
  native source-surface ownership remains unresolved and is labeled as such in
  the tool. During those last two messages Event Player classifies the frame as
  `world_map_monologue`: the decoded map is presentation-only, map/destination/
  movement input is locked, and only dialogue advance is accepted. The later
  handoff does not silently promote the frozen frame to an interactive map.
  **Finish EVENTB14** stops at the exact `MACHI.MES` handoff `0x230C`
  without executing that handoff target. The same world-map frame remains
  visible while the tool reports that interactive MACHI activation is outside
  the bounded preview. Invalid date `0000` is rejected
  before the calendar scan;
- value 3: `0x2383/0x2387`, `0x240B/0x240F`, `0x2456/0x245A`,
  `0x2488/0x248C`, `0x24C7/0x24CB`, `0x253B/0x253F`, `0x2578/0x257C`,
  `0x25FE/0x2602`, `0x2653/0x2657`, and `0x26EB/0x26EF`; then routine 27 at
  `0x2723/0x2728`, routine 25 at `0x272F/0x2734`, routine 21 at
  `0x2769/0x276E`, and the exact three-record command-`0x12` envelope
  `0x27D1..0x27DC` are processed only in the clone. Two final dialogues at
  `0x28B1/0x28B5` and `0x2908/0x290C` lead to callee return `0x291E`.

The stored records at those boundaries alternate between three raw CP932
fragments and one fragment; the frame presents every boundary as one dialogue.
Each continuation reconstructs the route in a fresh clone. On the two complete
routes, routine 27 has four rows and one omitted native presentation. With the
source-authentic nighttime caller state, routine 25 has 70 rows and changes
cloned `global_u8[3000]` from 0 to 4; routine 21 has five rows and two omitted
native presentations. A retained daytime-compatibility probe remains separately
guarded at 145 routine-25 rows with cloned `global_u8[3000]` 0 to 1 and
`state_u16[8]` 0 to 46, but it is not substituted for the confirmed nighttime
catalog route. These effects and the bounded command-`0x12` lists are never
applied to the live sandbox. The cloned state is discarded after presentation.
Values 1 and 3 have confirmed callee returns, but the live `44M.MES` caller is
not resumed because its next confirmed boundary is the unresolved caller-owned
routine-40 choice above. Value 2 instead reaches the bounded in-callee
`MACHI.MES` handoff.

No MMO marker or BGM request occurs inside the EVENTB14 callee before this
choice boundary. The caller presentation above supplies `MAHOKO.WAV` (SHA-256
`5cb732ef0e7da00eefc657833de7679935d8ccbbbf6681d1c50dfffc8a0f4ee8`)
and remains visible while the callee advances. The sandbox trace reaches
`global_u8[642] = 1`; its gameplay meaning is not assigned here.

Headless original-content replay rehashes `mes.arc`, `mmo.arc`, `data.arc`,
`bgm.arc`, and `voice.arc` after the bounded run. Evidence: authoritative ARC
entries, runner replay, AX structural/timeline inspection, and original EXE
audit v41 for command-`0x0F`, MMO, AX load/bind, green-key copy, and BGM
dispatch. Confidence: **Confirmed** through `0x04D4`, for the three stored
suffix branch tests and first-dialogue boundaries, and for the stored caller
presentation resources/coordinates; **Projected** for applying the confirmed
`TIME_C` bands to the original 44M location MMO family; **Tool policy** for the
60 Hz animation clock and explicit cloned-sandbox outcome selection;
**Confirmed** for the nested stored `state_u16[21]` branch tests, dialogue
boundaries, exact `B_PIC.MES` expression route and return, five final dialogues,
and `MACHI.MES` handoff; **Source-qualified projection** for selecting the
effective MACHI HHMM DAT/PAL pair after the confirmed routine-21 boundary;
**Unresolved** for native location-surface ownership
and composition, native animation cadence, routine-40 native UI and dynamic
second-stage records, native presentation effects omitted inside the cloned suffixes, the
meaning of the observed pre-choice state write, audible native-device output,
and execution after the `MACHI.MES` handoff.

## EVENTB15 Callee And Caller Route

**Catalog preservation, 2026-09-06.** Catalog v5/revision 19 now supplies
the existing direct-caller specification. The shared original catalog audit
rechecks `11M.MES:0x347B` dispatch, physical resume `0x348B`, the complete
suffix hash through `0x34BB`, and the aligned `EVENTB15.MES:0x0778` return.
Its fresh-sandbox suffix probe reproduces commands
`0x1F, 0x1F, 0x07, 0x1F, 0x03, 0x1F, 0x0E`, the two writes
`banked_u16[0][242] = 11` and `global_u8[286] = 1`, and the
`MACHI.MES` boundary at `0x34AE`. The player and audit now share this bytecode
validation. Existing callee-completion conditions, frame arguments, expression
stack, pre-suffix zero checks and failure rollback remain in the player.
Evidence type: unchanged authoritative entry/suffix hashes, exact indexed
return and bounded headless replay. This confirms preservation of the existing
route; the original outer host and omitted native effects retain the scope
and confidence described below.

**Scene role:** Mahoko event whose current projection starts from its original
`11M.MES` caller, follows the complete coordinate-zero callee, and resumes the
bounded original caller through its `MACHI.MES` handoff.

**Container and caller binding:** authoritative `mes.arc` SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`,
`EVENTB15.MES` SHA-256
`476f345fbbb6a5d12ab1bac78d797750b189dd9994e1be14d097981b838a6340`,
and `11M.MES` SHA-256
`51b596753c68c66cad7cf9a4d1b58e5dec0e16d801bf1e4432c819773bbda5d6`.
The exact `11M.MES:0x347B..0x348B` command-`0x0F` envelope names
`EVENTB15.MES`, ends at physical caller resume `0x348B`, and has SHA-256
`5494c179444ccbc88e52d129450c072bf45184130f3f585b4d339ff0ddc53db3`.
The envelope stores no coordinate operand. Configured-original executable
audit v38 independently confirms that the handler starts the named callee at
coordinate zero, saves the caller coordinate, and restores it after return.

The confirmed bounded sequence is entry zero `0x0008`, shared routine 28 at
`0x00F6` (resume `0x00FB`), adjacent three-record command-`0x12` lists
`0x0115..0x0120` and `0x0120..0x012B`, shared routine 21 at `0x02E0`
(resume `0x02E5`), and routine 28 at `0x02F0` (resume `0x02F5`). The paired
native-record slice has SHA-256
`933fba657726df053a842f8783286d3cc7baf56d82ba641ded08810b62df2303`.
Event Player allows one explicit record-only omission for that exact pair and
fails closed on shifted boundaries, changed bytes, source mismatch, or an
unexpected shared-routine stop.

The time branch reaches `B15X.MMO` for the daytime X bands and `B15Y.MMO`
for `1600..1759`; their authoritative original-entry SHA-256 values are
`5a439a7fd9183ede1a4eb7885ceee686ed2687eb11bad89f4262ed56d640c84a`
and `77c36bffeb9a4f7bfe5679ab3127a8799a6c87d2c3785a75ebf6672754384649`.
Both decode as 640x400 tool-preview frames. The stored night branch names
`B15Z.MMO`, which is absent from the original `mmo.arc`; no X/Y substitution
is allowed. Selector 14 at `0x02FF` and shared routine 23 at `0x0305` resolve
`MAHOKO.WAV`, bound to original-entry SHA-256
`5cb732ef0e7da00eefc657833de7679935d8ccbbbf6681d1c50dfffc8a0f4ee8`.
No voice marker occurs anywhere in the confirmed callee route, so the tool does
not synthesize one.

The first dialogue boundary is `0x035D`, with physical resume `0x0361`; the
exact zero-to-resume slice SHA-256 is
`823d2e5c1c9b467d8b6f25f07f5cd44987270610d84d401f0b1b18ee5b0142fe`.
The remaining dialogue boundaries/resumes are `0x03A0/0x03A4`,
`0x047C/0x0480`, `0x04BF/0x04C3`, `0x0528/0x052C`, `0x056B/0x056F`,
`0x05D6/0x05DA`, `0x0619/0x061D`, and `0x0672/0x0676`. The exact suffix then
crosses routines 28, 32, and 25 at `0x06A8`, `0x06CD`, and `0x071C`; permits
one bounded omission for three adjacent two-record command-`0x12` lists at
`0x0721..0x0739` (SHA-256
`bf879df6003bde083e4b7840799e9c83d940aa116d948f6dd3baae64e3101bae`);
crosses routine 28 at `0x0744`; and returns at `0x0778`. The complete
zero-through-return slice SHA-256 is
`ebe7b6f8b872992fed6c86903c7a35912741a89ee661200b186fb0109a073c0a`.

The restored `11M.MES` caller resumes at `0x348B`. Its exact
`0x348B..0x34BB` suffix has SHA-256
`3ae1bbba99ce3b77a6811e4c022cd170621ee8e12911b886594df4e4fd810fa9`,
writes `banked_u16[0][242] = 11` and `global_u8[286] = 1` only to the
isolated sandbox, and stops at the `MACHI.MES` command-`0x0E` marker
`0x34AE` (physical end `0x34BB`). It contains no caller BGM request. The
native consumer after the handoff is not executed.

Headless original-content replay covers X, Y, and missing-Z branches, all nine
dialogues, both native-record omissions, the callee return, and caller handoff,
then rehashes `mes.arc`, `mmo.arc`, `bgm.arc`, and `voice.arc`. Evidence type:
direct authoritative ARC entries, sandbox runner replay, and
configured-original executable audit v38. Confidence: **Confirmed** through
the caller handoff; **Unresolved** for omitted native-record effects, native
MMO composition, audible device output, and the host consumer after
`MACHI.MES`.

### Deferred EVENTB03 Start

The authoritative `mes.arc` has SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`;
its `01M.MES` entry has SHA-256
`a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5`
and `EVENTB03.MES` has SHA-256
`558532a9b034522db857d009132b6a89aa488e577277857cc90ce337c95ee230`.
The exact `01M.MES:0x788F..0x789F` command-`0x0E` envelope has SHA-256
`31be24c8ca3ec0e0613e2bced44ff4d9edcf70e7f4c4bfc821e2c4a407b6fde4`
and stores `EVENTB03.MES` as the active script name. Direct original MES
inspection and configured-original executable audit v56 agree on that stored
target. The complete bounded command handler at `0x00419210` parses the record,
copies its result into the native active string, invokes public-context receiver
slots `+0x20` and `+0x58`, and sets presentation flag `+0x20BC & 8`. Audit v53
resolves all three receiver vtables and all 15 readers/three writers of that
flag bit. The first receiver sees the string pointer as a `0..5` switch input
and takes its default path; the second receives the parsed selector as a
notification. The stream loop later clears the flag and resets its own stream
coordinate before continuing byte dispatch. No checked path writes an active
MES coordinate, synchronously runs a script, or restores a caller. The state
buffer's `+0x3190` owner backpointer is also confirmed, but its only direct
callback-helper caller is a serialized-state reload case that rebinds storage
pointers and replays bounded notification with the reloaded state pointer.
That case still writes no MES coordinate, invokes no script runner, and
restores no caller. Audit v53 also fixes five unique public-context slot-`+0x44`
call shapes in two caller extents. They pass caller stack-context pointers, and
neither extent directly references the command-`0x0E` active-string field.
These public zero-coordinate context calls therefore do not provide the
missing direct string-consumer edge. A separate higher-level host
consumer that would activate the target remains unresolved. No callee
coordinate is encoded or otherwise proven here.
Audit v53 also partitions all 22 literal active-buffer references as four
lifecycle, nine diagnostic-context, two destination-buffer, and seven
control/flag uses across five checked native method vtables. None is a direct
script-runner handoff. RTTI maps the tables to adjusted `CAI5Doc`, `CCommon`,
`CFunc`, `CScript`, and `CScriptManager` subobjects, so EVENTB03 remains blocked on an indirect or separate
higher-level host consumer rather than an unclassified direct field access.
The unique executable construction path also confirms that one application
document slot owns a composed `CAI5Doc` containing those script-family
subobjects. Construction still supplies neither an EVENTB03 start coordinate
nor a caller-restore frame, so it does not promote the deferred route.

Audit v87 further excludes a post-run application-lifecycle consumer. Nested
command-`0x0F` runners retain flag 8 while unwinding; their flag-set exits
restore the temporary script context but skip the normal active-name and
caller-coordinate restoration. At nesting depth one the runner clears the
flag and reinstalls the configured `START.MES` root. The authoritative root
stores one terminal command `0x0E` naming `OPEN.MES`, but neither that record
nor the original executable audit supplies a target activation coordinate.
The remaining consumer must therefore act inside the native run/step cycle
before the outer runner returns. EVENTB03 remains deferred.
Audit v88 further follows the flag-8 branch for `CAI5View` mode `0x80` through
composed `CScript` slot `+0x44`, view slot `+0x0C`, and `CPopUpMenu` visibility
and presentation handling. Mode `0x80` falls back to view mode 1. None of the
four bounded adapters directly reads the retained target, loads an archive
entry, establishes an activation coordinate/context, or restores a caller;
this presentation/lifecycle route also cannot promote EVENTB03.
Audit v89 follows the adjacent mode `0x100` branch through composed `CScript`
slot `+0x48`, `CAI5View` slot `+0x10`, two popup visibility checks, and popup
slot `+0x24`. Its visible path invokes `ShowWindow(..., 0)`, while a hidden
popup returns unchanged. The bounded adapters contain no retained target read,
archive lookup/load, activation coordinate/context, or caller restore, so this
popup-dismiss lifecycle also cannot promote EVENTB03.
Audit v90 follows mode `0x40` through `CAI5Doc` slot `+0x54`. The only checked
MES-load edges overwrite the active name with fixed `main.mes` or `open.mes`
before invoking the existing archive loader and root-stream installer; a
separate UI-success edge performs no load. The authoritative archive contains
`OPEN.MES` but no `MAIN.MES`, while its six stored `43C.MES` command-`0x0E`
handoffs remain unchanged. This fixed host transition therefore cannot activate
EVENTB03 or any other arbitrary retained handoff target, and supplies neither
EVENTB03's start coordinate nor its caller restoration. EVENTB03 remains
deferred.
Audit v91 follows mode `0x10` through composed `CScript` slot `+0x4C`.
`CAI5Doc`'s bounded override references only the fixed `Dialog04.mmo` resource
and a document presentation dispatch; the other four script-family handlers
only select an application view mode. Exact scans find no retained handoff
target, MES archive-loader, stream installer, script runner, activation
coordinate/context, or caller restoration. The authoritative `mmo.arc`
contains `DIALOG04.MMO`, but a fixed image presentation cannot activate
EVENTB03 or supply its missing start coordinate. EVENTB03 remains deferred.
Audit v92 follows mode `0x20` through composed `CScript` slot `+0x50`.
`CAI5Doc`'s bounded override uses fixed menu command `0x9C53`, the imported
menu redraw functions, and `DispEffect/IsPlay` profile state to update native
menu/presentation state; the other four script-family handlers only select
application view mode 1. Exact scans find no retained handoff target, MES
archive-loader, stream installer, script runner, activation
coordinate/context, or caller restoration. This fixed menu/presentation
lifecycle cannot activate EVENTB03 or supply its missing start coordinate.
EVENTB03 remains deferred.
Audit v93 follows mode `0x08` from sparse table byte 1 to the complete
`0x0043D795..0x0043D79D` branch. It restores the bounded frame and returns
zero without a virtual or native dispatch. Exact scans find no retained
handoff target, MES archive-loader, stream installer, script runner,
activation coordinate/context, or caller restoration. This immediate-return
path cannot activate EVENTB03 or supply its missing start coordinate;
EVENTB03 remains deferred.
Audit v94 follows modes `0x02` and `0x04` through their shared
`0x0043D71C..0x0043D76D` branch. The route pumps native messages until the
view-mode wait ends, refreshes the full 640x400 attached display rectangle,
and drains selector-0 Return/Numpad Enter state through composed `CScript`
slot `+0x3C`. Its only checked active-state reference tests presentation flag
8; the message pump's slot-`+0x10` receiver is `CAI5View`, not the script
runner. No retained handoff target, MES loader/installer, activation
coordinate/context, script run, or caller restoration is present. This
wait/input lifecycle cannot activate EVENTB03 or supply its missing start
coordinate; EVENTB03 remains deferred.
Audit v95 follows application view mode `1` through the unsigned
`view_mode - 2` out-of-table gate and direct return at
`0x0043D6A1..0x0043D6BF`. It returns one because the current mode is not `8`,
without consulting the sparse table or issuing a virtual/native dispatch.
Exact scans find no retained handoff target, MES loader/installer, activation
coordinate/context, script run, or caller restoration. This normal-step
continue return cannot activate EVENTB03 or supply its missing start
coordinate; EVENTB03 remains deferred.
Audit v96 follows the byte that actually carries command `0x0E` back through
`CAI5Doc` slot `+0x70`. The remap selects generic dispatcher
`0x00418180`; its command wrapper calls the confirmed handler, discards the
handler result, and returns one to `CScript::run`. Because the runner tests
flag 8 before fetching this byte, the new flag is seen only on the next
successful step when the message pump continues, or is retained across the
current unwind when it does not. The bounded dispatch/return glue contains no
retained target read, MES load/install/run, activation coordinate/context, or
caller restoration. It therefore cannot supply EVENTB03's missing activation
coordinate; EVENTB03 remains deferred.
Audit v97 follows the complete public-context slot-`+0x58` notification family
reached by the hash-bound `43C.MES` command-`0x0E` envelopes, including the
stored `EVENTB03.MES` target. Primary selector 6 returns zero; common selectors
0 through 5 at `0x0042B5F0..0x0042B836` only reset, reserve, finalize, find,
and query a 66-record internal store. Their five adjusted shared-state reads
all begin at control word `+0x20BC`, not the active target string, and the sole
direct call is a zero-fill helper. No MES load/install/run, activation
coordinate/context, or caller restoration occurs in the complete checked
notification extents. This selector family therefore cannot activate
`EVENTB03.MES` or supply its missing start coordinate; EVENTB03 remains
deferred. Evidence type: direct authoritative `mes.arc` handoff envelope plus
exact original-launcher embedded-runtime vtable/table/selector bytes and
bounded negative scans; confidence: **Confirmed** for the bounded notification
contract and exclusion, **Unresolved** for the separate host activation edge.
Audit v98 follows the other command-`0x0E` public-context call, slot `+0x20`,
through its complete `0x00429A70..0x00429D54` dispatcher. Although the handler
passes `EVENTB03.MES`'s retained active-string pointer as the first argument,
the dispatcher treats that position as an unsigned selector with domain
0 through 5. The valid string address takes the default edge to cleanup and a
zero return, without entering a selector body or dereferencing the name. Its
bounded command path contains no MES load/install/run, activation coordinate,
context write, or caller restore. This receiver call therefore also cannot
activate `EVENTB03.MES` or supply its missing start coordinate. Evidence type:
the same authoritative `43C.MES` handoff plus exact original-launcher
embedded-runtime dispatcher bytes/table/calls and bounded negative scans;
confidence: **Confirmed** for this receiver exclusion, **Unresolved** for the
remaining indirect host activation edge.
The later target-qualified runtime-trace v2 supersedes that historical native
boundary. In one original-engine first-room-entry session, the host named and
looked up the target, installed its stream twice, wrote context, code
coordinate, and cursor, resumed the same owner with presentation flag 8, read
the retained target, and entered its execution envelope. The installed
coordinate value is the first code byte, so `EVENTB03.MES` starts at
code-relative `0x0000`; its command-`0x14` bootstrap transfers to address entry
zero at `0x0008`. The v2 report also claimed a matching target-run return, but
the stream-aware v3 correction below supersedes that terminal classification.

A corrected headless replay from that confirmed coordinate reaches shared
routine 28 at `0x00FC` (resume `0x0101`) and consumes the complete native list
at `0x011B..0x0126` only through the explicit record-effect omission policy.
It then follows structurally decoded MES instructions without the generic
native-stream skip policy. The earlier reported `0x01C5` zero-state return was
a tool artifact: generic skipping began at statement separators, crossed
ordinary write instructions, and misread an MMO resource-name terminator as
command `0x00`. It is superseded and must not be used as route evidence.

The corrected source-unqualified zero-state analysis reaches shared routines
`28/21/28` at `0x00FC/0x0225/0x0235`, the first dialogue boundary at `0x039F`,
and 28 dialogue boundaries in total. After another routine-21 boundary at
`0x08DF`, it reaches routine-40 selection at `0x12D2` with exactly three
registered definitions in one group. This proves a viable coordinate-zero
analysis path to dialogue and choice; it does not prove that an all-zero state
matches the original caller state, nor does it establish the post-choice result
mapping or event terminal. The separately observed dormitory first-entry flow
is a `44C.MES` to `43C.MES` room transition and must not be treated as visible
EVENTB03 route evidence.

A later target-qualified original-engine replay supplied a bounded real caller
state for EVENTB03 itself. Other station visits and events
occurred after attach but before activation; none entered the evidence set
until the retained target matched `EVENTB03.MES`. The 79 retained events then
completed all seven v2 obligations and stopped at `target_run_return`. At
`target_execution_start`, the native state had weekday `6`, date `0413`, and
HHMM `1825`; the exact local-only `0x3000`-byte snapshot has SHA-256
`12eaf8b506342c0f8e5dae0d1e7eda7eb261895dbb0eea98e58acb8a8024ee0f`.
The matching return snapshot has SHA-256
`063f002de69a8c54ed6cb516f8cf66de1056323e3d4df8cbdbd17ceb733a1aa5`.
Their MES-visible state delta is limited to `global_u8[631]`, `[632]`,
`[4000]`, `[4090]`, and `[4091]`, each `0 -> 1`; `state_u16` is unchanged.
The target-local command-`0x03` audit independently binds `[632] = 1` at
`0x0076`, `[631] = 1` at `0x0081`, and the `[4090]/[4091]` zero/one writers at
`0x0131/0x0137`, `0x0168/0x016E`, and `0x0183/0x0189`. Index 4000 has no
target-local command-`0x03` writer and remains a shared-routine effect in this
capture. Native control bytes at `+0x20BC` and `+0x2174` also changed but are
not promoted as portable gameplay state.

The operator selected the third visible row, but the pre-store result was not
captured by this generation. Both snapshots retain `state_u16[18] = 0` and
`state_u16[21] = 16`, proving only that the selected result is transiently
consumed or overwritten before target return. The raw snapshots remain in the
untracked local analysis cache and are not a catalog preset. Choice row 3 is
therefore still an operator observation, not yet a source-bound result mapping;
the next trace must sample the audited native one-based result store before it
writes `state_u16[18]`.

A second source-qualified replay used that specific `0x00414DC5` probe while
the operator again selected visible row 3. It independently reached the same
79-event `target_run_return` boundary and completed all seven obligations, but
the probe never fired. This excludes the command-`0x12`
primary-1/secondary-21 slot-18 writer as the return path for this observed
choice; it does not identify the result value. The executable's already
audited common modal result-copy site is broader: immediately before
`mov [esi+8], eax` at `0x0043532E`, `ESI` owns the modal result and `EAX` is the
one-based selected-record result. The next target-qualified trace observes
this common site and records its active stream coordinate. Confidence:
**Confirmed** for the negative `0x00414DC5` path result and common modal store
contract; **Unresolved** for the EVENTB03 row/result binding until that common
probe fires in the same operator-observed replay.

The next complete row-3 replay also did not hit `0x0043532E`. This confirms the
observed UI does not return through either downstream store, while preserving
the same qualified EVENTB03 return. The presentation-helper audit exposes the
earlier selected-control confirmation store at `0x00401CF7`: after the
zero-based host row is mapped and incremented, `ECX` is the one-based result
immediately before `mov [esi+8], ecx`. Keyboard, pointer, and modal confirmation
converge on that selected-control value. The next trace targets this earlier
store. Confidence: **Confirmed** for both negative downstream paths and the
selected-control store contract; **Unresolved** only for its dynamic EVENTB03
row/result binding.

A fourth target-qualified replay again selected visible row 3, completed all
seven obligations, and reached the same 79-event matching return without
hitting `0x00401CF7`. This rules out the entire probed command-`0x12`
`CAdvSelect`/common-modal chain as an explanation for the observed standard
message choice. Executable audit v313 separates the RTTI-bound `CNormalSelect`
control as the next bounded candidate for that presentation class. Its confirm
function `0x00438CC0` maps the current
zero-based host row through virtual slot `+0x4C`, increments it at
`0x00438DAA`, and stores one-based `ECX` at `0x00438DAD` before clearing the
control's active field. Runtime-trace plan v2 now probes that store while the
same EVENTB03 owner-thread run and active-state pointer remain qualified. A
coordinate below the retained context is labeled `nested_stream_unresolved`;
it is not reported as an EVENTB03-relative offset. Evidence type: authoritative
`EVENTB03.MES` target-qualified runtime capture plus exact original-runtime
vtable/confirm bytes; confidence: **Confirmed** for the three negative advanced
selection paths and the distinct normal-selection one-based store contract,
**Unresolved** for the dynamic row/result binding until this fourth path fires.

A fifth target-qualified row-3 replay completed the same seven obligations and
79-event matching return without executing `0x00438DAD`. The observed choice
therefore uses none of the four bounded result sites at `0x00414DC5`,
`0x0043532E`, `0x00401CF7`, or `0x00438DAD`. Its start and return snapshots have
SHA-256 `c4b049b4241289fd96241c3d14db2fdc70e3b6579b8b6f2f1fa218240da05142`
and `be6ec7939e5a519f226408f907c4277fc0feaac9e77cfe5090560c5aa60e0027`.
They differ at only byte offsets `0x02F7`, `0x02F8`, `0x1020`, `0x107A`,
`0x107B`, `0x20BC`, and `0x2174`, the same positions retained by all five
row-3 captures; `state_u16[13] = 0xFFFF`, `[18] = 0`, and `[21] = 16` are
unchanged. Two nested `CScript::Run` entries return through runtime RVA
`0x1A535`, the audited instruction immediately after the command-`0x1D`
shared-script call, and through RVA `0x1842B`, the virtual script dispatcher.
The next dynamic boundary is therefore the upstream command-`0x1D` call and
command-`0x12` ingress, not another inferred result store.

The authoritative archive still independently places three command-`0x10`
definitions at code-relative `0x1220`, `0x1255`, and `0x1284`, followed by a
literal routine-40 transfer at `0x12D2` and a `state_u16[21] == 1` comparison at
`0x12DC`. No retained runtime coordinate yet joins the operator-observed choice
to this exact static boundary, so those archive facts do not by themselves
label the visible row or its result. Evidence type: authoritative
`EVENTB03.MES` instruction reread, target-qualified original-engine capture,
and exact original-runtime call-site audit. Confidence: **Confirmed** for all
four negative result paths and the repeated state delta; **Unresolved** for the
executed choice boundary and row/result binding.

Executable audit `kakyu_ai5_mes_exe_audit/v314` made that next boundary
executable. It exposed command-`0x1D` selected-script call `0x0041A533`, the
adjusted receiver's active-state field `+0x4B558`, and stream fields
`+0x4B58C/+0x4B590`. Runtime-trace plan v2 added this call and the already
audited command-`0x12` byte ingress `0x0043F2ED` as its twenty-third and
twenty-fourth software breakpoints. This corrected older captures that read
the two stream fields four bytes late from the adjusted receiver.

A sixth complete operator row-3 replay retained 84 events, completed all seven
host obligations, and stopped at the matching target return. It executed
command-`0x1D` with selected cursors `0x02D0` and `0x1B8B`, and command-`0x12`
ingress with cursors `0x034C`, `0x0357`, and `0x0368`; all five used the same
nested code base. Sixteen-byte read-only live-memory windows at base plus cursor
match the authoritative `LIBLARY.LIB` windows at code-relative
`0x02D0/0x034C/0x0357/0x0368/0x1B8B`, whose SHA-256 values are respectively
`ab4d022a8218249cf817b0df4538aa9475784b6568bd5bd0cd53fb880808e974`,
`bafab45dec99719d5f4f68c57106fbc3854d685bc88886ae709c038b51327b41`,
`437049963f86d7ec9160cfdb6b9ba4bea26c4612e90ef04e173cf4adf6c9c416`,
`0e8705f8a8a3d24b877881972014abffa890134e408eafcfc97b31974186e284`,
and `262a1c69549dea377ae1f6e1b5d82f8db64fd0b18206571136f2058a2144445d`.
The same windows do not occur in authoritative `EVENTB03.MES`. The library
index independently identifies routine 28 body `0x02D0..0x03EB`, containing
the three executed command-`0x12` starts, and routine 29 body
`0x1B8B..0x1B96`. This proves the observed target run enters those shared
library paths; it does not yet identify the EVENTB03 caller instruction or the
selected row's stored result.

Executable audit `kakyu_ai5_mes_exe_audit/v315` resolves the stream-field
semantics. Exact opcode-fetch handler `0x0043D540` reads cursor `+0x4B58C` and
code base `+0x4B590`, fetches from their sum, then advances the cursor. The
collector now retains `active_stream_offset` and `active_instruction_pointer`,
and emits a target `code_offset` only when the active base equals the base saved
from the matched stream installation. The command-`0x1D` probe also captures
the caller resume cursor and code base saved at `ESP+0x10/+0x18`; a future hit
whose caller base matches EVENTB03 can therefore bind the exact caller resume
without projecting a library cursor onto the target. The seven host-activation
obligations and promotion status do not change. Evidence type: authoritative
`mes.arc` entry reads, target-qualified original-engine capture, read-only live
memory comparison, and exact original-runtime instruction audit. Confidence:
**Confirmed** for the two executed library routines and three native-record
ingresses; **Unresolved** for their EVENTB03 caller coordinate and row/result
binding.

The following source-qualified capture closes that caller-coordinate boundary
and corrects the earlier terminal interpretation. Its first command-`0x1D` hit
uses target code base plus cursor `0x00FC`, saves target-relative resume
`0x0101`, and selects shared routine 28 at `LIBLARY.LIB:0x02D0`. Routine 28
executes command-`0x12` at `0x034C/0x0357/0x0368`; its nested command-`0x1D` at
`0x1B8B` saves library-relative resume `0x0399` for routine 29. This dynamically
confirms the same `EVENTB03.MES:0x00FC -> LIBLARY.LIB:0x02D0` caller chain that
the archive decode exposes.

It also proves that every v2 replay stopped too early. The old terminal probe at
runtime `0x0043D62F` captured only a return address and stack, so the first
`CScript::run` epilogue after target start was labeled `target_run_return`
without identifying its active stream. In the latest 84-event report that
epilogue is routine 29 returning into routine 28; the operator's later visible
row-3 selection occurred after the collector had detached. Consequently the
earlier 7/7 promotion, full-return snapshots, full-route state deltas, and all
four negative choice-store exclusions are superseded. They remain historical
probe attempts, not evidence that those result stores were bypassed.

Exact original-runtime audit `kakyu_ai5_mes_exe_audit/v316` moves the return
probe to `0x0043D629`, immediately after nesting decrement and before `ESI`,
`EBP`, and the frame are restored. The checked bytes preserve the script
receiver in `ESI` and the caller return address at `[EBP+4]`. Runtime plan and
capture v3 therefore record receiver, active state, cursor, code base, nesting,
and return address. Only a return whose receiver/state match the qualified owner
and whose code base equals the installed target base becomes
`target_run_return`; matching-owner library returns become
`target_nested_run_return`. The collector can continue after a target-stream
return so the operator-driven choice and later terminal can be observed in one
session. Evidence type: authoritative `EVENTB03.MES` and `LIBLARY.LIB` reads,
target-qualified original-engine capture, and exact original-runtime epilogue
bytes; confidence: **Confirmed** for the target-to-routine-28 caller/resume and
the nested-return misclassification, **Unresolved** for the full target return,
visible row/result store, post-choice continuation, and route terminal.

The first correctly target-bound v3 follow-up again qualifies the one
authoritative `EVENTB03.MES` producer and completes the first six obligations:
name consumption, archive load and lookup, stream installation, coordinate-zero
execution, and owner/context continuity. It retains 512 events before reaching
its event limit, including 390 non-evidence run-flag tests, 29 run entries, 47
native-path observations, and 28 correctly classified nested returns. No
stream-qualified target return or process terminal occurs inside that retained
prefix, so the report remains 6/7 and the operator's later visible row-3 choice
and world-map return are not trace evidence. The start snapshot has SHA-256
`7a3f8f4154e581bd69cafa9863e4a47f54a7e5f06c63ad8444f073bcde868fc7`
and retains `state_u16[13/18/21] = 0xFFFF/0/16`; no return snapshot exists.
Capture v3 now bounds repeated software diagnostics per normalized event ID,
counts suppressed hits, never drops an ID's first evidence hit, and suppresses
the debugger's console-only breakpoint chatter. This changes collection
capacity only and does not promote the missing seventh obligation. Evidence
type: target-qualified hash-bound original-runtime replay and guarded local
capture; confidence: **Confirmed** for the six-obligation prefix and nested
return classification, **Unresolved** for the target return and all later UI.

The subsequent source-qualified row-3 replay retains the post-choice route and
closes the terminal alternative that the older plan omitted. Its selected-
control store records one-based result `3`; command-`0x12` then mirrors `3` to
state slot 18 and resets that slot to `0xFFFF`. After target execution, runtime
sequences `179..186` carry `MACHI.MES` through command-`0x0E`, archive load and
lookup, stream installation, coordinate write, and the matching flag writer on
the qualified owner thread. The earlier `B_PIC.MES` nested load lacks this
producer chain and is not terminal evidence. Direct authoritative
`EVENTB03.MES` inspection binds the successor to three possible command-`0x0E`
envelopes at code-relative offsets `0x1BB6`, `0x26F4`, and `0x3D46`; their
identical envelope SHA-256 is
`496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047`.
The runtime envelope alone cannot distinguish those identical bytes. Terminal-
audit schema v3 closes that finer boundary by joining the captured result to
the authoritative post-routine-40 CFG. Starting at `0x12DC`, stored guards
compare `state_u16[21]` with 1, 2, and 3 at `0x12DC`, `0x1BD2`, and `0x2710`;
their false targets are respectively the next guard, the next guard, and the
common return at `0x3D5D`. Conservative CFG walks bind results 1, 2, and 3 to
the sole reachable `MACHI.MES` envelopes at `0x1BB6`, `0x26F4`, and `0x3D46`.
The captured result `3` therefore selects the exact source envelope
`EVENTB03.MES:0x3D46..0x3D53`. The three walks visit 29, 39, and 71 resolved
blocks and converge at `0x3D5D`; out-of-range decoder edges are counted but
discarded, while any unresolved in-range edge fails the audit.

Terminal-audit schema v2 independently binds the result stream itself. The
selected-control and slot-18 mirror events share runtime offset `0x1CA0`; the
sentinel reset uses `0x1CD0`. Their common runtime base is corroborated by six
distinct command-`0x1D` dword matches against authoritative `LIBLARY.LIB`,
including a target-linked anchor and a library-self-linked anchor. The first
routine-40 record `0x1C95..0x1CA0` has exact signature `[1, 21, 0]` and envelope
SHA-256
`42defc3c26f59a332a72c375f583cfdff83eacc367d7ab9d5a982d73e4e4d687`;
the second `0x1CC4..0x1CD0` has signature `[1, 21, state_u16[21]]` and SHA-256
`160604bc42109543ac70c5b0addd47b8e707bf17d0adc649e978195cfc6d0a60`.
Thus visible result `3` is source-bound to
`LIBLARY.LIB:0x1C95..0x1CA0`, followed by the observed `0xFFFF` reset at the
second record's end. It is deliberately not labeled as an EVENTB03-relative
coordinate.

This complete same-owner successor chain is a `target_root_replacement`, the
host-owned alternative to a callee return or process exit. A path-free offline
audit of the unchanged local capture and authoritative archive completes all
seven P2-05 obligations and promotes only `command_0e_host_activation`.
Evidence type: authoritative archive read and post-read hash check,
target-qualified original-engine capture, exact embedded-runtime anchors, and
operator-confirmed third-row/world-map completion. Confidence: **Confirmed**
for one-based choice result `3`, the `EVENTB03.MES -> MACHI.MES` root
replacement at `0x3D46`, and host activation; **Unresolved** for portable
caller state, complete playable reconstruction, and native presentation.

Preset-reduction audit v4 compares nine target-qualified start snapshots from
the same original archive and executable without retaining their raw
`0x3000`-byte state buffers. Direct authoritative `EVENTB03.MES` decoding
exposes ten literal condition fields across 32 distinct valid condition
coordinates. Six are zero in every capture: `global_u8[626]`, `[627]`,
`[2847]`, `[3006]`, `[4000]`, and `state_u16[5]`. The choice destination
`state_u16[21]` starts at 16 in every sample but is runtime-owned: routine 40
overwrites it with the selected one-based result before the confirmed guards
at `0x12DC`, `0x1BD2`, and `0x2710`. Neither class justifies a nonzero preset
record.

Across the same nine successful row-3 replays, `state_u16[12]` varies between
224 and 254 and `banked_u16[0][210]` varies from 49 through 52 while the
qualified target, selection result, and terminal remain the same. Exact values
for those fields therefore are not invariants of the observed route.
`state_u16[8]=3` is stable at target entry but is not an incoming requirement:
the authoritative entry writes `[8]=0` at `0x0106..0x010B`, immediately before
its first `[8] == 0` condition at `0x010B`. Preset-reduction v4 verifies that
exact literal write and classifies `[8]` as precondition-overwritten. The
source-qualified surrounding context remains stable at weekday
`state_u16[4]=6`, date `state_u16[7]=0413`, and HHMM
`state_u16[19]=1825`. Audit v4 scans every operand in the 100%-aligned target:
2,237 instruction identities contain 174 references across 14 captured-
storage fields, but none names `[4]`, `[7]`, or `[19]`. It therefore publishes
those values only as surrounding-host context observations and emits no
target-local candidate fields; it explicitly does not claim a minimal or
sufficient playable preset. Python structured IR v4 now retains the complete
MMO and surface presentation envelopes that formerly produced ten empty-stack shadow branches;
the authoritative entry has 32 valid and zero unresolved condition
coordinates. Shared-routine state dependencies and other native presentation
state remain outside the preset claim. Evidence type: read-only authoritative
`EVENTB03.MES` decode, original executable audit v317, nine hash-bound
target-start snapshots, and before/after source hash checks. Confidence:
**Confirmed** for the observed stability/variation and native storage mapping;
**Confirmed** for the entry-local `[8]` overwrite; **Confirmed surrounding-host
observation** for the three stable context records and their lack of a
target-local operand consumer; **Unresolved**
for causal minimality and complete playback sufficiency.

The two entry-local native setup records are no longer an unknown consumer of
the retained weekday/date/HHMM values. Authoritative records
`0x011B..0x0126` and `0x0126..0x0131` carry typed tuples `(1, 3, 0)` and
`(1, 4, 0)`. Preset audit v4 joins exact executable audit v317 and maps them
through primary-1 native dispatch to `CSpriteDays` at owner member `+0x1F0` and
`CSpriteTimeMoney` at `+0x254`. Both invoke vtable slot `+0x24` and shared
handler `0x00436750`, which stores the third expression as the sprite-visible
flag at `+0x08` and refreshes its rectangle. The literal zero hides the two
top status panels. These routes contain no read of candidate
`state_u16[4]`, `[7]`, or `[19]`; they are display visibility commands, not
date/time setters. Evidence type: authoritative archive record decode plus
original-executable dispatch, vtable, RTTI, and handler inspection.
Confidence: **Confirmed** for the two setup-record effects; **Unresolved** for
native presentation inside the target and shared routines.

The companion Godot deletion matrix separates the four observed nonzero start
records from the implemented MES logic. Starting at authoritative
code-relative zero, the four-record observation, an empty sandbox, and each
one-record deletion all retain the exact seven-condition signature at
`0x010B/0x01F0/0x0287/0x02F2/0x08AA/0x0933/0x09BB`, the two omitted native
records `0x011B/0x0126`, the same shared-routine and 28 dialogue boundaries,
and the three-definition choice `0x12D2`. All six cases observe `[8]=0` after
the entry-local write. Thus none of weekday, date, incoming `[8]`, or HHMM is
causally required by the currently supported prefix. Preset audit v4 now also
removes the three context values from the target-local candidate after scanning
every decoded operand and ruling out the two exact entry visibility records as
consumers. This does not prove the values irrelevant to the outer host or to
called shared routines; those remain the actual sufficiency boundary.
Evidence type: six isolated headless executions against the unchanged
authoritative entry. Confidence: **Confirmed** for bounded-prefix equivalence;
**Unresolved** for native presentation and full-route equivalence.

The same six-case audit retains exact library internals for the four calls
before choice `0x12D2`. EVENTB03 `0x00FC/0x0225/0x0235/0x08DF` call routines
`28/21/28/21` with argument slot 1 values `1/1/0/46635`. The corresponding
LIBLARY paths contain `8/5/6/5` rows, preserve empty expression stacks and
their arguments, make no nested call, and produce no sandbox state diff.
Observed-record, empty, and every one-record deletion have identical
coordinate and effect hashes. Thus the implemented shared-script state path
does not consume the three surrounding-host observations. Six bounded native
presentation spans are deliberately omitted, so their original display
effects and complete playback sufficiency remain **Unresolved**.

Result-3 audit now continues those same sandboxes through the source-qualified
routine-40 consumer instead of stopping at `0x12D2`. The observed four-record
state and the reduced state containing only `state_u16[4]=6` and
`state_u16[19]=1825` reach the same 40 post-choice dialogue boundaries from
`0x276C` through `0x3D15`, the same 24 root shared-routine calls, registered
DEF22 at `EVENTB03.MES:0x295D` and DEF21 at `0x2AE9`, and the same seven
bounded native character streams at
`0x2A74/0x2ACE/0x2C15/0x2C74/0x2D4C/0x2DA6/0x2E9D`. (Since Core 0.316.0, 2026-09-13,
those seven records are `System.function[12](20/40/100)` calls that the
runtime omits and runs past inside their segment, not bounded stops; the
audits check them as omitted-call rows at the same coordinates.) DEF22 is bound to
`DEF_MAIN.MES:0x1109..0x116E`, DEF21 to `0x10C4..0x1102`; both cross their
exact routine-3 calls and return to the retained root caller. The route then
reaches the original `B_PIC.MES` nested dispatch at
`EVENTB03.MES:0x37B9..0x37C6` and continues to the exact `MACHI.MES` root
replacement at `0x3D46..0x3D53`.

Deleting `[7]` or the already overwritten `[8]` retains that outer structural
signature. Empty state, deleting `[4]`, or deleting `[19]` changes the
source-bound routine-25 traces at `0x372E` and `0x3C1B`; those cases are
rejected even before nested presentation. This establishes `[4]=6, [19]=1825`
as the minimal outer-script state, not the complete presentation state.

Executing the exact nested target exposes the additional boundary. With MMDD
`state_u16[7]=413`, `B_PIC.MES` reaches shared routine 22 at `0x035B`, resumes
at `0x0360`, requests `MAHOKO.WAV`, loads `B1.MMO`, and applies
`BAN.MMO`/`B.AX` row 0 column 1 for the captured Mahoko affection value 3. It
returns at `0x0759` after changing only `global_u8[3005]` from zero
to one. `B_PIC.MES:0x0604..0x0611` is selector 1, cell `(0,1)`, after the
binding at `0x05F2..0x0604`; the real `[3005]` write is `0x0611..0x0617`.
The former `[769]` write was that selector-1 payload shadow, corrected by
instruction v44; it is not a gameplay flag. The reduced three-field state
`[4]=6, [7]=413, [19]=1825` and deletion
of overwritten `[8]` retain combined trace SHA-256
`8d7771311ed65536362f71d2c758a97e219c217dfbd149fe272f04ab6fe86518`
after that boundary correction.
Deleting `[7]` instead takes a different expression-only route and cannot
qualify as the same presentation. Original `B1.MMO` SHA-256 is
`f6c910b31296b0f97394eba78b34bcc6bf287df995b62bbd8c5c12258bb3343c`.
Evidence type: direct read-only execution of the unchanged authoritative MES
and library entries plus fingerprinted original media and target-qualified
runtime observations. Confidence: **Confirmed** for structural and nested
presentation flow, selected resources, AX binding, and state writes;
**Unresolved** for the seven earlier streams' native glyph pixels/cadence and
choice results 1 and 2.

The ordinary route's event-local presentation is now bound separately from
that later `B_PIC` standing layer. The authoritative entry loads `B03.MMO` at
`0x01BA`, `B03AN.MMO` at `0x0259`, `B03.AX` at `0x026E`, and installs row 0,
column 0 at `0x0299`; the second scene uses `B03A.MMO` at `0x0873`,
`B03AAN.MMO` at `0x0903`, `B03A.AX` at `0x0919`, and the same cell at
`0x0945`. Their original AN dimensions are respectively `112x504` and
`112x624`. Each AX owns nine bounded green-key draw records, while cell
`(0,0)` dispatches only records 0/1/2 over an exact 215-tool-tick stream.
Event Player therefore retains each 640x400 event CG as the background, hides
the AN strip, and composites only the AX-selected rectangles. It no longer
shows the source strip as a display-ready image. Evidence type: direct
authoritative `EVENTB03.MES`, `mmo.arc`, and `data.arc` read plus exact AX
record/timeline inspection and headless playback; confidence: **Confirmed**
for resources, dimensions, cell, rectangles, ordering, and composition;
**Unresolved** for native wall-clock cadence.

The large result-3 scene loads `B05SS.MMO` (`988x588`) at `0x2EB1`, copies its
initial source rectangle `(0,0)..(639,399)` at `0x2EC4`, then loads
`B05SSAN.MMO` (`768x224`) at `0x2F4B`, `B05SS.AX` at `0x2F62`, and binds cell
`(0,0)` at `0x2F8F`. That cell drives four `192x224` rectangles at destination
`(64,0)` over an exact 217-tool-tick stream. The original bytes confirm the
first crop and the maximum remaining source extent `(348,188)`. The earlier
resource-only inspection did not identify the native camera commands; the
following MES/EXE audit supersedes that missing-trajectory conclusion.

**Source-commanded camera sequence.** After the dialogue at `0x32CC`, two
command-`0x12` records explicitly supply `[127,0,0,988,588,7]` at
`0x32F9..0x3311` and `[127,0,0,988,588,8]` at `0x3316..0x332E`.
These are not animation flags inferred from an MMO filename or image size.
The native primary-127 remap at `0x414BC0+127` selects adapter `0x4147DF`,
which calls `0x416790`. That helper subtracts the logical `640x400` viewport
from the supplied extent and selects the following source-surface-9 to
destination-surface-0 operations:

- Mode 7, `0x4168D0..0x416EE3`: automatic movement from `(0,0)` toward
  `(348,188)`, an explicit endpoint copy and 1000-ms hold, then a return to
  `(0,0)`. The outbound loop uses indices `1..173`, the return `173..0`,
  horizontal step 2 and vertical step `376/348`, with truncation to integers.
  Sample deadlines are 15 ms; the uninterrupted nominal deadline sum is
  6205 ms, **not a measured playback duration**. Rendering, input polling,
  and the native interruption guard affect elapsed time.
- Mode 8, `0x416EF0..0x417A9F`: interactive panning by pointer drag and
  direction-key codes `C8/D0/CB/CD`, clamped to `(0,0)..(348,188)`; key
  movement uses one-pixel steps. Exit tests include key codes `1C/9C`, native
  input-owner field `0x1C`, and a host guard. The crop is restored to `(0,0)`
  on completion. The friendly mouse-button meaning of the owner field is
  not established here. The Enter route `0x416F3B/0x416F4B -> 0x41776C`
  does not immediately return to MES: `0x4177AD..0x4177FF` derives a return
  loop from the displacement, and `0x417810..0x4179AB` copies samples with
  15-ms deadlines before the final origin copy at `0x4179B1..0x417A93`.
  For displacement `(x,y)` from this command's origin, let `m=max(x,y)`;
  the rational projection uses indices `floor(m/2)-1..0` and crop
  `floor(2*(x,y)*i/m)`. Displacements below two pixels bypass the loop.
  Returning from `(348,188)` has 174 samples / 2610-ms nominal deadlines;
  the preceding manual interaction has no fixed duration. These are loop
  operands, not measured host timings or bit-exact x87 sample claims.

**AX boundary correction:** the complete outer records are
`0x32E7..0x32F4` (subcommand 3, selector 2, row 0, column 0) and
`0x3357..0x3364` (selector 1, row 0, column 0); the same selector-1 form
occurs at `0x2FA1..0x2FAE`. They are not `global_u8[767..769]` writes.
The earlier inner-offset interpretation was a payload-shadow error and is
superseded by instruction v44. Native selector 2 requests cell state 1 via
`0x4290DD -> 0x410C10`; the cell can keep ticking until the wait/command-zero
boundary changes it to `0xFF`. It is not an immediate freeze. Selector 1
sets state 0 via `0x42909F -> 0x410BF0` after the AX rebind at
`0x3345..0x3357`. Source 9 holds the large CG while AX draws from source 8
to destination 0; the camera's source-9 copies are distinct from AX draws.
Exact temporal overlap during the native input loop remains unresolved.
Evidence type: direct read-only authoritative EVENTB03 entry and original
EXE disassembly, exact native-span fingerprints, and current GDScript
structural-decoder parity. Confidence: **Confirmed** for command boundaries,
order, dispatch, loop bounds, endpoints, input tests, and deadline operands;
**Unresolved** for observed host cadence, interruptions, overlay lifetime,
and inherited x87 precision/rounding control needed for bit-exact intermediate
pixels. `tools/audit_eventb03_camera.py` reproduces both record identities,
fourteen native spans, selected-cell controls and GDScript parity. Audit v3
separately fingerprints the mode-8 return subset `0x4177AD..0x417A9F` as
`69955c2a05040851c76ea373e976b6b805464ace60bb0dc4732b084a4bedcdc1`.
Its generated samples are explicitly
an exact-rational geometry/deadline projection, not a native pixel oracle.
Synthetic tests cover record mutations, truncation, decoys, parity and
projection invariants; the original-source audit also verifies unchanged files.

**Source-qualified runtime projection.** Event Player keeps the initial crop
stationary until `0x32F9`, then stops the runner at that complete native record
and starts mode 7 on a deterministic tool clock. After the round trip it
resumes at `0x3311` and stops separately at mode 8's `0x3316`. Logical pointer
drag and arrow-key events move the crop; Enter or **Finish CG inspection**
starts the bounded return. Only after origin restoration does MES resume at
`0x332E`. Click/Space cannot advance dialogue in either camera phase; automatic
and return phases consume movement/finish input without skipping. Esc releases
preview focus and cancels dragging. The exact source entry, command bytes,
record extent and source-9 image identity are required; this does not enable
arbitrary edited commands or other events by filename alone.

During camera ownership the tool copies only source 9, suppressing the stale
screen-space AX layer and pausing its tool scheduler. This suppression is an
explicit conservative tool policy: selector 2's graceful-stop transient and
native message-driven AX redraw overlap remain unresolved. The confirmed
post-camera binding at `0x3345` and activation at `0x3357` reset the retained
B05SS plan before later dialogue; it must not resume a pre-camera scheduler
cursor. Direct `data.arc/B05SS.AX` inspection places that cell's stream at
AX-relative `0x570`, with its first draw at `0x575` / tool tick 1. Reset has
tick 0 and no scheduler dispatch yet; the preview's initial frame-0 display
is tool presentation, not a claim of a native draw at tick 0. The frame delta
consumed by camera completion is not applied again to the newly rebound AX.
Synthetic/source regressions verify source-only crops, both return
phases, input ownership and restoration. PR-02 retains exact native cadence,
x87 intermediate pixels and AX overlap as separate open work.

The later station standing scene must not reuse that event-CG checkpoint.
Direct structural rereading of `EVENTB03.MES` locates routine 28 at
`0x36ED..0x36F2`, AX selectors 6/8 at `0x3707..0x3715`, routine 27 at
`0x3722..0x3727`, routine 25 at `0x372E..0x3733`, and the
`global_u8[2847]` branch at `0x3733..0x373E`. The two arms copy source surface
1's `(0,0)..(639,399)` rectangle at `0x373E..0x3763` or call routine 21 at
`0x3768..0x376D`. Routine 21 in `LIBLARY.LIB:0x03F2..0x0431` contains that
surface copy, selector 8, a `global_u8[4000]` condition, and mode-1 composition.
The route reaches routine 28 again at `0x379F..0x37A4`, writes
`global_u8[206]=1` at `0x37AE..0x37B4`, then dispatches `B_PIC.MES` at
`0x37B9..0x37C6`. The original EXE surface adapter
`0x42A860..0x42A8A9`, handler `0x42A8B0..0x42ABA0`, mode-1 arm
`0x42AA49..0x42AB63`, and copy helper `0x4254D0` were crosschecked with
`audit_eventb03_native_presentation` v3. Those facts confirm the restoration
operations, not the producer or lifetime of the native host-owned surface.

The station-entry audit supersedes the provisional `01MM_3.MMO` choice.
`01M.MES:0x01D1..0x01E3` sets `banked_u16[0][1]=1`, writes argument slot 1
to 11, and calls routine 27. The event itself repeats the same setup at
`EVENTB03.MES:0x3715..0x3727`; preserving a pre-event checkpoint is therefore
not needed to establish this background producer. Routine 27's selector-11
branch is `LIBLARY.LIB:0x3B3C`. Its `0x3B47..0x3B61` date condition is
`MMDD < 616 || (MMDD > 915 && MMDD < 1116)`. For `413`, the time conditions
at `0x3B61`, `0x3BD4`, and `0x3C47` reject `<600`, `<1600`, and `<1800` at
HHMM `1825`, reaching `0x3CBA`. The source sets active surface 2 at
`0x3CBA..0x3CC1`, loads **`01MA_3.MMO`** at `0x3CC2..0x3CD1`, sets active
surface 7 at `0x3CD1..0x3CD8`, then RGB-key copies `(0,0)..(639,399)` from
surface 2 to surface 1 at `0x3CD8..0x3CFB`. Routine 8 at `0x0299`, routine 21
at `0x03F2`, and the event's direct restoration arm at `0x373E` read surface 1.

The selected original MMO is `640x400`, SHA-256
`a523cf5d07fb3987800bb50764e010781d6b996e2495d354d2aeb946048a2bef`.
Direct decoding shows the station interior. The named-MMO adapter
`0x42A640/0x42A6DA -> 0x425190` and rectangle mode-1 arm
`0x42ACA5 -> 0x4255D0` were rechecked against the original EXE. Confidence:
**Confirmed** for this numeric date/time selection, resource, source-1 producer
and restoration reads; **Unresolved** for complete host refresh, surface
lifetime through every native operation, and cadence. The envelope beginning
at `LIBLARY.LIB:0x3D00` remains bounded without inventing a pixel effect.
`validate_eventb03_station_source.gd` checks 119 assertions including both
callers, date-boundary cases and source-copy operands;
`audit_eventb03_station_native.py` rechecks 26 central native byte/call facts.
Event Player now uses that confirmed resource before compositing `B1.MMO` and
the selected `BAN.MMO`/`B.AX` frame. The adapter requires the original EVENTB03
and background hashes, exact event session and captured date/time; it rejects
unsupported contexts rather than generalizing the location/season contract.
Effective media overlays still follow the normal resolver, with a `640x400`
size check. Scene transition clears the old pan/image, stops its AX plan, and
replaces its checkpoint before standing composition. Original-source regression
compares the resulting pixels with station + standing + selected face, separate
from the later MACHI terminal projection.
Verification: `test_event_player.tscn` passes 480 checks, including camera
pixels, input/source guards and 1080p/1440p logical-coordinate invariance;
the pure camera test passes 76 checks of deterministic samples, deadline
boundaries and partitioned elapsed time;
`test_logical_surface_compositor.tscn` passes 25 checks. The authoritative-source
`validate_event_player_eventb03.gd` run (retired 2026-09-21, EP-10 unit 5c, with
`validate_event_player_eventb14.gd`; both events are covered by `original
catalog group routes`) checks the complete accepted route,
off-context station rejection, and unchanged MES/MMO archives;
`validate_event_player_eventb14.gd` retains its existing original-content
composition and branch contracts. These automated results do not replace the
pending user-visible follow-up in MV-04.

At the accepted `0x3D46..0x3D53` `MACHI.MES` root replacement, Event Player
uses station preset **16**, not the previously misidentified preset 0.
`MACHI.MES:0xACA2..0xACAC` checks EVE result 16 and the target record at
`0xACB1..0xACBC` names `01M.MES`. `MACHI.CCD:0x0384..0x0388` supplies camera
cell `(45,14)` and actor cell `(60,22)`; `MACHI.EVE:0x00C0..0x00CC` associates
event 16 with `(60..61,22)`. The separate map-start condition
`MACHI.MES:0x056E..0x0578` checks `state_u16[16]==16`, then its native record
at `0x0578..0x0589` supplies `[6,1,16,0,1]`. This proves the location-to-preset
connection. The old `(88,60)/(110,68)` record was real source data but was
incorrectly labeled as the station; it belongs to EVE 0, not EVE 16.
The corrected camera stays inside the map, so no edge wrapping is applied.
Event Player selects the authoritative
HHMM night atlas and composes `MACHI.MPC`, the DAT/PAL pair, and `CHARA`
directly from the source archives, placing the actor at pixel `(240,128)`.
Evidence type: direct
authoritative CCD/MPC/DAT/PAL read, exact terminal match, and deterministic
headless composition, plus original EXE CCD initialization
`0x4211F0..0x421280` and EVE scan `0x421A50..0x421AE8`; confidence:
**Confirmed** for station mapping, preset bytes, terminal, and source identities;
**Source-qualified projection** for using an entrance preset in this static
terminal preview rather than resuming the native host's retained camera/input.

Event Player reports host activation, zero start, and this bounded analysis
route as confirmed. Catalog preset `captured-result3-original` binds the exact
three writes and all required MES/media hashes; Event Player reapplies it to a
fresh isolated state, emits the versioned preset receipt, and reruns the exact
B_PIC plus MACHI terminal route before accepting the contract. Event Player now
also rereads the exact `01M.MES:0x788F..0x789F` activation and required sources,
starts a caller-free EVENTB03 zero-coordinate session internally, consumes only
the byte-checked `0x011B..0x0131` setup pair through its bounded omit policy,
and stops at the first original dialogue `0x039F`. The same live session now
advances through all 28 prefix dialogue boundaries to the three original
routine-40 rows at `0x12D2`. At the original EP-02 promotion the controller
rejected results 1/2; the subsequent branch-qualified extension is documented
in [B03 Choice Routes](eventb03_choice_routes.md). Result 3 writes
`state_u16[21]=3` and resumes the original consumer at the first suffix dialogue
`0x276C`; a focused read-only regression verifies both the rejected no-mutation
path and the accepted coordinate. Ordinary catalog Play now continues that
same live root session through the source-qualified shared-routine calls,
registered DEF 22 at `0x295D` and DEF 21 at `0x2AE9`, all seven exact native
character-stream omissions, and the exact `B_PIC.MES` return. It presents
`B1.MMO`, applies `BAN.MMO`/`B.AX` column 1, and reaches the callee-owned
`MACHI.MES` root replacement at `0x3D46`. During the event-local sections it
retains the exact B03/B03A/B05SS event backgrounds beneath their AX layers;
before `B_PIC` it restores the bounded station projection above, and at the
terminal it replaces that presentation with the source-qualified
preset-16 MACHI station projection described above.
The catalog exposed EVENTB03 as `partial_playback` until 2026-09-21; since EP-10
unit 5 it is a generated `minimal_playback` row of its 01M group (`01m_b03_v6`)
played through the shared call frame as stills. Revision 10 additionally
executes choices 1/2 within the same fresh three-field preset, with branch-local
B_PIC calls and distinct MACHI terminals as recorded in the linked audit.
Other starting states still fail closed, and native effect equivalence remains
unresolved. **Start Event (Deferred)** remains disabled only for direct
address-row starts, which do not carry the required catalog preset. The two-field
structural and three-field presentation
candidates are causally supported, and the choice
continuation is source-bound to
`LIBLARY.LIB:0x1C95..0x1CA0` and `EVENTB03.MES:0x3D46`.
Root-replacement terminal behavior is confirmed but is not sufficient to
recreate the original caller-owned route. Address-table rows remain explicit
Analysis input. Evidence type:
direct authoritative `01M.MES`, `EVENTB03.MES`, and `LIBLARY.LIB` reads;
hash-bound original-runtime capture; and isolated headless replay. Confidence:
**Confirmed** for host consumption, zero coordinate, the four shared-routine
boundaries, 28 dialogue boundaries, three-definition choice, the dynamic
target-to-routine-28 caller, choice result 3, and root replacement;
**Confirmed** for the choice's library source record, result-3 successor
source coordinate, minimal two-field structural replay candidate, and
three-field nested-presentation candidate and transactional catalog preset;
**Unresolved** for native glyph pixels/cadence, choice-result 1/2 consumers,
and any direct-start state inference outside the catalog preset.

The later [station candidate audit](eventb03_candidate_entry.md) binds the
source-local `01M.MES:0x7691` predicate and its fallthrough through rows 66--69
to the same `0x788F` target record. It does not replace the target-qualified
host capture above: the command record contains the name, while zero-coordinate
host activation and root replacement were confirmed separately. Nor does the
local predicate prove full natural eligibility, because earlier 01M candidates
and native/external address-row selection remain unqualified. No catalog
preset is widened by that analysis-only plan.

The later [existing-preset choice audit](eventb03_preset_choice_routes.md)
extends the qualified numeric state12/affection representatives to results
1/3 with exact per-result state and B_PIC contracts. It supersedes the earlier
result-2-only product restriction, not the native-equivalence or host-entry
confidence boundary. Its new result-1/3 UI acceptance is tracked separately
from the already accepted result-2 representatives.

The [face-flag source audit](eventb03_face_flag_routes.md) separately covers
nonzero globals 204/207/628 through zero-entry routes and exact B_PIC predicate
boundaries. These numeric source findings do not enable new product presets
or assign gameplay meanings to those flags. In particular, source equality
with 1 is distinct from the product policy that rejects all nonzero values.

Focused native-presentation audit v3 now closes the structural and product-
consumption question for those seven spans without claiming their pixels. The
authoritative records are exactly `0x2A74..0x2A7B`, `0x2ACE..0x2AD5`,
`0x2C15..0x2C1C`, `0x2C74..0x2C7B`, `0x2D4C..0x2D53`,
`0x2DA6..0x2DAD`, and `0x2E9D..0x2EA4`. Each command-`0x0D` record owns five
single-byte renderer inputs and its terminal NUL. The hash-bound native handler
at `0x004187C0..0x00418A53` consumes the complete run, invokes the character
renderer, advances and wraps its presentation cursor, and conditionally
refreshes the attached display rectangle without a mapped gameplay-state
write. Event Player now consumes each exact record as explicit metadata-only
omitted native FX only when the active session is `EVENTB03`, the resolved
entry is the hash-bound original, the physical seven-byte record matches its
allowlist row, and the decoder reports the matching command end, probe
start/end, six-byte NUL-terminated payload consumption, and character-stream
handler family. An accepted boundary exposes **Continue (Omit Native FX)**
by resuming at that exact end and restoring `native_stream_policy=stop`; this
prevents the omission policy from swallowing a following MMO/AX marker
envelope. A changed byte, coordinate, hash, source, or probe cannot
fall through to the generic native continuation. The three varying literal
values (20, 40, and 100) are retained but their user-facing meaning and cadence
remain **Unresolved** under presentation ownership. (Corrected under Core 0.316.0
on 2026-09-13: each record is `System.function[12](N)`, one system call the
runtime omits and runs past, so the **Continue (Omit Native FX)** stop no
longer exists; after a routine-9 SE the Event Player finds the omitted wait
call in the caller segment's trace and projects the source-timed wait onto
that segment's real continuation instead of pausing at the call.) Evidence type:
authoritative archive/EXE audit plus headless Event Player acceptance and
mutation rejection; confidence: **Confirmed** for exact metadata-only product
consumption, **Unresolved** for native pixels and cadence.

## EVENTD01

**Conditional caller catalog migration (2026-09-06).** Catalog v4/revision 18
now supplies the existing D01/D02/D03/D14 caller specifications. Direct
read-only rechecks of authoritative `mes.arc` reproduce these code-relative
anchors and boundaries:

| Callee | `12C.MES` dispatch → resume | Callee return | Completion flag (`global_u8 == 1`) | BGM end → handoff → suffix end |
|---|---|---|---|---|
| `EVENTD01.MES` | `0x07CD` → `0x07DD` | `0x1114` | 749 | `0x0851` → `0x086A` → `0x0877` |
| `EVENTD02.MES` | `0x098D` → `0x099D` | `0x18C6` | 750 | `0x0A11` → `0x0A2A` → `0x0A37` |
| `EVENTD03.MES` | `0x0DDE` → `0x0DEE` | `0x07FF` | 751 | `0x0E62` → `0x0E7B` → `0x0E88` |
| `EVENTD14.MES` | `0x1C23` → `0x1C33` | `0x256D` | 763 | `0x1CA7` → `0x1CC0` → `0x1CCD` |

Evidence: unchanged source entry and caller slice hashes, exact aligned
command-`0x00` callee returns, three-date BGM replay and the existing
command sequence `0x03, 0x1F, 0x07, 0x1F, 0x0E` through the caller suffix.
The date slot remains `state_u16[7]`: 1224 selects `X_MAS.WAV`/26, 1301
selects `SHOGATU.WAV`/42, and the default representative 500 selects
`IDOU.WAV`/1. Caller postconditions remain `global_u8[286] = 1` and
`banked_u16[0][242] = 12`, followed by the `MACHI.MES` handoff boundary.
The completion flag is required at return, BGM and handoff stages; the first
three callee-return rows are newly explicit metadata for existing verified
coordinates. Confidence and supported scope remain those of the event
sections below. The migration confirms preservation of these bounded routes,
and makes no new claim about the unresolved outer host or native presentation.

**Scene role:** earlier fish-shop Maki encounter with a three-way choice; the
current tool projection reaches the callee return on all three paths.

**Container and source binding:** authoritative `mes.arc` SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`,
`EVENTD01.MES` SHA-256
`7aa158cb5a363d18dc9ad41e53a1e57f2361533e3079c49a9d58ef93f06af029`,
and `12C.MES` SHA-256
`c71563238cd4e14a06125b8cd139f7e6a304024dbd7c32ed5a3619ca425726eb`.
The `12C.MES` command-`0x0F` envelope at `0x07CD` names `EVENTD01.MES` and
ends at physical caller resume `0x07DD`; the exact 16-byte envelope SHA-256 is
`7bbfeb7e4b17cbf913aa9689075a671a9b3bb6c327d777891adaae6afa9111cd`.
Event Player requires these hashes, original-ARC resolver source, decoded
target/end, and the exact caller envelope before enabling the
confirmed start. Configured-original executable audit v38 independently
confirms command `0x0F` routing through manager slot `+0x38` to handler
`0x004192A0`, entering the selected MES at coordinate zero and restoring the
saved caller coordinate after return. Evidence type:
direct authoritative archive bytes plus configured-original executable handler
audit; confidence: **Confirmed** for the dispatch, zero coordinate, and
physical resume.

Confirmed bounded prefix:

- The exact `EVENTD01.MES:0x0000..0x0008` bootstrap has SHA-256
  `1d5fcfa66928c2bd712394fcd5e001e48b41b60f943039c72d06687224953e5c`.
  Its command `0x14` dispatches address-table entry zero at `0x0008`. From
  there the confirmed sandbox route first reaches shared routine `28` at
  `0x00E6` (resume `0x00EB`). Two adjacent three-record command-`0x12` lists
  occupy `0x0105..0x0110` and `0x0110..0x011B`; their combined slice SHA-256
  is `933fba657726df053a842f8783286d3cc7baf56d82ba641ded08810b62df2303`.
  Event Player consumes each complete list through its NUL terminator, records
  the native record effects as omitted, and resumes at the exact physical
  boundary. It does not reinterpret the stored records as MES opcodes.
- With explicit sandbox `HHMM=0600`, the original branch reaches the
  `D01X.MMO` outer envelope `0x01CE..0x01DC` and filename marker `0x01CF`.
  The marker slice SHA-256 is
  `dc58e5e2814cf674dbff7396b62094f3d40cf50529bd4fcd5b1e31575ce72426`.
  It then reaches the independent `banked_u16` write `0x022D..0x0234`.
  The initial shared routine `28` has normalized a seeded
  `global_u8[4000] = 1` to zero, so the branch at `0x0234` bypasses the stored
  mode-0 surface envelope `0x023F..0x0264` and goes directly to routine `21`
  at `0x0269` (resume `0x026E`), followed by routine `28` at `0x0279` (resume
  `0x027E`). The bypassed surface envelope remains an exact source guard with
  SHA-256
  `cd042deb56aa5eb5bf2df3ecbfb658219aebb1943add07301d239357f353b2f3`,
  but Event Player does not report it as reached or execute its native pixels
  on this normalized route.
- The same daytime path reaches the `D01XAN.MMO` envelope
  `0x02DE..0x02EE` (marker `0x02DF`, slice SHA-256
  `8b537d53dcc5bfa9c38d03165f7ed4331c6e456ac07504fda4ca97544a7a1d54`),
  the `D01X.AX` load `0x02EE..0x0303` (slice SHA-256
  `f6262d7fa9963cb91ef1552adc0e2edabb71ca83fb21b2b4a6fcfa20b1184017`),
  and its binding envelope `0x03B7..0x03C9` (slice SHA-256
  `b8214ec570ae5b2f66ebc41cf7225d618f743e782c274dfb1fb0d1369569d649`).
  The original `D01XAN.MMO` decodes to 120x168. Event Player may present that
  decoded foreground as an overlay-aware tool preview, but the native AX
  consumer, foreground placement, surface ownership, and composition order
  remain unresolved.
- `EVENTD01.MES:0x03E6` assigns argument slot 1 to selector `33`; `0x03EC`
  invokes shared routine `23` and resolves the catalog request `MAKI.WAV`.
  The complete coordinate-zero-to-first-dialogue slice SHA-256 is
  `f1231332a41c13883409b7bc9ee18a6f447f1c6b4c09f1f560f3943673b4b9c7`.
  The configured-original executable audit v38 separately reconfirms command
  `0x09` as the continuation-controlled indexed argument-slot write family;
  routine-23 resource selection remains archive-derived evidence.
- The first original dialogue boundary is `0x043E`, with physical resume
  `0x0442`. Explicit continuation reaches six dialogue boundaries in total,
  with resumes `0x0442`, `0x04BC`, `0x050B`, `0x0593`, `0x05F2`, and
  `0x06C0`. Three resolved voice markers appear in order: `D0946.OGG`,
  `D0947.OGG`, and `D0948.OGG`.
- The prefix writes isolated `global_u8[5361] = 1`,
  `banked_u16[0][2] = 0`, and `global_u8[3737] = 1`, then stops at
  `def_selection_boundary` coordinate `0x07AB`. These writes are tool sandbox
  state only and do not modify a gameplay save.
- The three bounded option definitions have literal IDs `0,1,2`, source
  offsets `0x06FB`, `0x072E`, `0x0775`, and aligned targets `0x0729`,
  `0x0770`, `0x07A1`. Literal routine `40` stops at `0x07AB`, and the physical
  post-transfer coordinate is `0x07B0`. Conditions immediately after that
  coordinate consume `state_u16[21] == 1`, `2`, or `3`. The exact native
  routine-40 input mechanism remains unresolved, but Event Player now offers
  an independently hash- and coordinate-bound sandbox projection: keyboard or
  pointer selection writes only the matching one-based value to
  `state_u16[21]` and resumes at `0x07B0`. A mismatch keeps the definitions
  read-only and exposes no resume.
- Choices 1, 2, and 3 reach respectively 7, 9, and 7 additional dialogue
  boundaries after the selection. Their newly reached voice sequences are
  `D0949/D0950/D0956`, `D0951/D0952/D0953/D0956`, and
  `D0954/D0955/D0956` (all `.OGG`). All three paths then reach the exact
  command-`0x00` script return at `0x1114`, with common sandbox writes
  `global_u8[749] = 1`, `global_u8[682] = 1`, and `global_u8[3228] = 1` in
  the complete prefix-plus-choice session. Event Player identifies
  `global_u8[749]` as this bounded route's completion condition and shows an
  explicit completion screen naming the confirmed `12C.MES:0x07DD` caller
  resume. The caller remains a separate explicit action rather than an
  automatic transition.
- **Preview Caller BGM** runs only the exact 116-byte caller prefix
  `12C.MES:0x07DD..0x0851`. Sandbox date `1224` selects selector `26` /
  `X_MAS.WAV`, date `1301` selects `42` / `SHOGATU.WAV`, and all other dates
  select `1` / `IDOU.WAV`; all three hash-bound probes make no state change.
- **Continue Caller Handoff** then runs the separately hash-bound 38-byte
  suffix `0x0851..0x0877`. Command `0x03` writes `global_u8[286] = 1`,
  command `0x07` writes `banked_u16[0][242] = 12`, and command `0x0E` reaches
  the `MACHI.MES` handoff marker at `0x086A`. The tool marks EVENTD01 plus its
  confirmed caller complete there and does not execute the unresolved host
  consumer. Configured-original executable audit v19 independently locks the
  `0x03`/`0x07` storage handlers and command-`0x0E` active-string handler.
  Evidence type: direct authoritative `12C.MES` slices and hashes, three-date
  headless route replay, UI-controller continuation, and configured-original
  executable handler audit; confidence: **Confirmed** for the BGM selection,
  state writes, target, and physical boundaries, **Unresolved** for the host
  consumer.

The coordinate-zero pre-dialogue block contains time-routed full-frame
references: before `0600` it reaches `D01Z.MMO` at envelope `0x01B0`;
`0600..0899` uses `D01X.MMO` at `0x01CF`; `0900..1559` uses the second
`D01X.MMO` envelope at `0x01EE`; `1600..1759` uses `D01Y.MMO` at `0x020D`;
and `1800` onward reaches `D01Z.MMO` at `0x0220`. Direct reads of the
user-owned archives find `D01X.MMO` and `D01Y.MMO` in `mmo.arc`, both decoding
to 640x400. The original-entry fingerprints additionally bind `D01Y.MMO` to
SHA-256 `4f29f4b130b0a702450326f3a29381b379a5bfa6417e80e46929fb4755218cd0`,
`D01YAN.MMO` to
`a7a017ebd6dc0a3fbea006aa16d75ff793fe3796bf5d21f4c8e4a4bc44e97402`,
and `D01Y.AX` to
`2cdaa8a87771cef44b9303f659d09c612213941be3b60b1521b52e1897873539`.
Strict original replay decodes `D01YAN.MMO` as 112x192, distinct from the
120x168 `D01XAN.MMO`; the tool does not normalize either foreground's size.
Direct index reads find no `D01Z.MMO`, `D01ZAN.MMO`, or `D01Z.AX` in the
corresponding original archives. A fresh/default `HHMM=0000` preview therefore
retains explicit missing-original-resource diagnostics instead of substituting
daytime content, while the bounded MES route may still continue to dialogue.
The daytime `0600` route above is the confirmed presentation path used for
complete media-backed replay. Overlay-resolved
MMO/AX replacements may change only the tool presentation layer; they do not
relax any base-entry fingerprint or coordinate check and are not evidence of
original-engine compatibility.

Evidence type: direct authoritative `EVENTD01.MES`, `12C.MES`, and
`LIBLARY.LIB` reads; all-archive resource lookup; strict MMO decode; exact-slice
hashes; headless Event Player replay; and configured-original executable audit
v37. Confidence: **Confirmed** for the zero-coordinate call, bootstrap,
stored records, daytime resource/control sequence, time bands, resource
presence/dimensions, BGM, dialogue boundaries, DEF coordinates, three projected
routes, return, completion write, and caller BGM/handoff suffix; **Tool
omission policy** for typed-record effects and native pixels; **Unresolved**
for native AX placement/compositing, native selection input mechanics, and the
final handoff consumer.

## EVENTD02

**Scene role:** a subsequent Maki dialogue event. The current tool route reaches
the callee return and exact caller MACHI handoff, with one exact native display
stream deliberately omitted.

**Container and caller binding:** authoritative `mes.arc` SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`,
`EVENTD02.MES` SHA-256
`d0be4a811e9e1e6859ddbaf41473e2e734ad750f0c2d8e8ad626630ecffe925e`,
`12C.MES` SHA-256
`c71563238cd4e14a06125b8cd139f7e6a304024dbd7c32ed5a3619ca425726eb`,
and `LIBLARY.LIB` SHA-256
`d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d`.
The exact `12C.MES:0x098D..0x099D` command-`0x0F` envelope names
`EVENTD02.MES`, ends at physical caller resume `0x099D`, and has SHA-256
`7558bf2443b4ff32791be269248189c7a2ac93001cb92ce1fdb5d3afe9ef1da3`.
That stored envelope contains no callee-coordinate operand. Configured-original
executable audit v38 independently confirms that command `0x0F` reaches handler
`0x004192A0`, saves the caller coordinate, starts the selected callee at
coordinate zero, and restores the saved coordinate after return. Event Player
requires the original-ARC resolver source, all four hashes, decoded target/end,
and exact caller envelope before enabling the confirmed start. Evidence type:
direct authoritative archive bytes plus configured-original executable handler
audit; confidence: **Confirmed** for the dispatch, zero coordinate, and physical
caller resume.

Confirmed coordinate-zero prefix:

- The code-relative `EVENTD02.MES:0x0000..0x03FB` prefix is byte-identical to
  `EVENTD01.MES` and has SHA-256
  `59907b63e368ded9183ce9e28f302a0f3638b419df1881d4084720751ebd2352`.
  This comparison applies to bytecode only: EVENTD01 and EVENTD02 retain their
  distinct 25-entry and 41-entry container address tables. The exact
  `0x0000..0x0008` bootstrap has SHA-256
  `1d5fcfa66928c2bd712394fcd5e001e48b41b60f943039c72d06687224953e5c`
  and dispatches address-table entry zero at `0x0008`.
- The confirmed sandbox route first stops at shared routine `28` at `0x00E6`
  (resume `0x00EB`). It then consumes two complete adjacent command-`0x12`
  three-record lists at `0x0105..0x0110` and `0x0110..0x011B`; their combined
  slice SHA-256 is
  `933fba657726df053a842f8783286d3cc7baf56d82ba641ded08810b62df2303`.
  These native record effects are explicitly omitted, and bytes after either
  NUL are never reinterpreted as MES opcodes.
- With sandbox `HHMM=0600`, the bounded route reaches the `D01X.MMO` background
  envelope `0x01CE..0x01DC` (filename marker `0x01CF`) and the independent
  `banked_u16` write `0x022D..0x0234`. Initial routine `28` normalizes seeded
  `global_u8[4000] = 1` to zero, so the branch at `0x0234` bypasses the stored
  prefix surface envelope `0x023F..0x0264` and reaches routine `21` at `0x0269`
  (resume `0x026E`), followed by routine `28` at `0x0279` (resume `0x027E`).
  The bypassed envelope remains an exact source guard with SHA-256
  `cd042deb56aa5eb5bf2df3ecbfb658219aebb1943add07301d239357f353b2f3`;
  it is not reported as reached and its native pixels are not executed.
- The same route reaches the `D01XAN.MMO` foreground envelope
  `0x02DE..0x02EE`, `D01X.AX` load `0x02EE..0x0303`, and binding envelope
  `0x03B7..0x03C9`. Their respective slice SHA-256 values are
  `8b537d53dcc5bfa9c38d03165f7ed4331c6e456ac07504fda4ca97544a7a1d54`,
  `f6262d7fa9963cb91ef1552adc0e2edabb71ca83fb21b2b4a6fcfa20b1184017`,
  and `b8214ec570ae5b2f66ebc41cf7225d618f743e782c274dfb1fb0d1369569d649`.
  Event Player may decode the 120x168 foreground as a tool preview, but native
  AX consumption, placement, surface ownership, and composition remain
  unresolved.
- `EVENTD02.MES:0x03E6` assigns argument slot 1 to selector `33`, and `0x03EC`
  invokes routine `23`, resolving `MAKI.WAV`. The shared code first diverges at
  `0x03FB`; the EVENTD02-specific `0x03FB..0x0456` slice has SHA-256
  `c65dd233a3e41504dd8a1984736e8ac033fabe026369caeabf3e639386440845`
  and includes the first `D0957.OGG` marker before dialogue boundary `0x0456`
  (physical resume `0x045A`). The complete coordinate-zero-to-boundary slice
  has SHA-256
  `221ca3fc98229d42eaffb0cffb24a116182e4a111a39d3846840b0226196d8a2`.

Confirmed subsequent route:

- Explicit continuation reaches eleven dialogue boundaries before the first
  shared-library stop: `0x0456`, `0x04A5`, `0x0531`, `0x0596`, `0x062A`,
  `0x0669`, `0x06DD`, `0x0722`, `0x07B4`, `0x0815`, and `0x08A1`. The
  distinct validated voice markers across the complete bounded preview are
  `D0957.OGG` through `D0965.OGG` in numeric order.
- The direct event bytes call shared routine `27` at `0x08D7`, routine `25`
  at `0x08E3`, and routine `21` at `0x091D`. In the default sandbox
  `HHMM=0000` route, bounded routine-25 continuation also reaches registered
  DEF `26` at library coordinate `0x1E22`; Event Player composes only the
  separately hash-audited DEF26 body before returning to the caller. There is
  no additional routine-28 call between the first dialogue and the `0x0BAD`
  native-stream pause; the coordinate-zero prefix has already crossed routine
  28 at `0x00E6` and `0x0279`. Routine 27 and 25 do not contain dialogue, so a
  no-dialogue result for either is expected rather than a failed event preview.
  A separately replayed `HHMM=0600` route bypasses the registered-DEF26 stop but
  reaches the same 40 dialogue boundaries, completion write, and return.
  (41 since Core 0.316.0, 2026-09-13: the dialogue at `0x0BBC` that the
  skip-bounded resume after the former `0x0BAD` pause used to hide.)
- After routine 21, six more dialogue boundaries are reached at `0x0973`,
  `0x09E1`, `0x0A38`, `0x0A9E`, `0x0AE3`, and `0x0B5D`. Continuing from
  `0x0B61` retains three message fragments, then stops at command `0x0D` at
  `0x0BAD`. Its native character-stream payload begins with byte `0x0C`; that
  byte is consumed by the native stream and is not reinterpreted as the
  separately confirmed four-byte continuation command. The configured-original
  `0x0D` handler audit confirms that this six-byte payload is consumed through
  its NUL, making `0x0BB4` the exact next script coordinate. Event Player
  pauses here as **EVENTD02 PAUSED / EVENT NOT COMPLETE** and offers an
  explicit **Continue (Omit Native FX)** action. It does not claim to reproduce
  the omitted display/cursor effect.
  (Corrected under Core 0.316.0 on 2026-09-13: that six-byte payload is
  `System.function[12](30)`, one system call the runtime omits and runs past,
  so there is no pause at `0x0BAD`; the seventh suffix dialogue at `0x0BBC` -
  which the skip-bounded resume used to hide - is a boundary of its own, and
  its segment reaches routine 28 at `0x0BE0` with no message; the later
  routine-28/21 boundaries and dialogues are unchanged.)
- The default bounded run ends with isolated values `banked_u16[0][1] = 7`,
  `banked_u16[0][2] = 0`, and zero at `global_u8[767]`, `[2836]`, `[2841]`,
  and `[3000]`. Both earlier projected values 8 and 1 at `[767]` were analysis
  artifacts. The v42 correction covered seven-byte selectors 6/8 but missed
  the 13-byte selector-1 record `EVENTD02.MES:0x03C9..0x03D6`. Instruction
  v44 consumes that complete AX record without a gameplay write. The next
  real write at `0x03D6..0x03DC` targets `global_u8[3005]`, not `[767]`.
- The exact `0x0BB4` resume reaches a message-bearing segment followed by
  routine `28` at `0x0BE0`. Exact presentation-subcommand-11 mode-0 surface
  envelope `0x0C9B..0x0CC0` then remains one bounded instruction; the
  following control path reaches routine `21` at `0x0CC5` and the second
  routine `28` at `0x0CD5`. Fourteen dialogue boundaries follow at `0x0D4F`,
  `0x0D98`, `0x0E04`, `0x0E61`,
  `0x0EE1`, `0x0F30`, `0x0FB4`, `0x1027`, `0x1091`, `0x10DC`, `0x1142`,
  `0x117F`, `0x1207`, and `0x1250`.
- Routine `28` at `0x1271` is followed by a second exact mode-0 surface
  envelope `0x132C..0x1351`, routine `21` at `0x1356`, and the final
  routine-28 boundary at `0x1366`. The final nine dialogue boundaries are
  `0x1539`, `0x1580`, `0x15FC`, `0x1661`, `0x16D5`,
  `0x1714`, `0x1744`, `0x1793`, and `0x1811`. The additional distinct voice
  markers are `D0966.OGG` through `D0976.OGG`, making 40 dialogue boundaries
  (41 since Core 0.316.0, with `0x0BBC`) and 20 ordered distinct voice targets
  across the complete bounded session.
- Advancing the final dialogue from physical resume `0x1815` reaches the exact
  command-`0x00` script return at `0x18C6`, with completion
  `global_u8[750] = 1` and common route value `global_u8[3229] = 4` in the
  isolated sandbox. Event Player then shows an explicit EVENTD02 completion
  screen naming `12C.MES:0x099D` as the physical caller resume. Caller
  execution remains a separate explicit action.
- **Preview Caller BGM** runs only the exact 116-byte caller prefix
  `12C.MES:0x099D..0x0A11`. Sandbox date `1224` selects selector `26` /
  `X_MAS.WAV`, date `1301` selects `42` / `SHOGATU.WAV`, and all other dates
  select `1` / `IDOU.WAV`. The action is offered only after three hash-bound
  route probes reproduce those requests without a state change.
- **Continue Caller Handoff** runs the separately hash-bound 38-byte suffix
  `0x0A11..0x0A37`. Command `0x03` writes `global_u8[286] = 1`, command
  `0x07` writes `banked_u16[0][242] = 12`, and command `0x0E` reaches the
  `MACHI.MES` handoff marker at `0x0A2A`. Event Player marks EVENTD02 plus its
  confirmed caller complete there without executing the unresolved host
  consumer. Configured-original executable audit v38 independently locks the
  `0x03`/`0x07` storage handlers and command-`0x0E` active-string handler.

The coordinate-zero block uses the same four time bands as EVENTD01: before
`0600` it references `D01Z.MMO` at `0x01B0`; `0600..0899` uses `D01X.MMO` at
`0x01CF`; `0900..1559` uses the second X envelope at `0x01EE`;
`1600..1759` uses `D01Y.MMO` at `0x020D`; and `1800` onward references Z at
`0x0220`. The checked original `mmo.arc` SHA-256 is
`b7623d1e8bdf5d153e2194989d9df46535026f37a5680939ea559e322ee03aea` and
`data.arc` SHA-256 is
`b069c4dbb67d67eaf9252babc02f100fbc16c0740a189b007ff31535305727e4`.
Direct original reads bind the X family to `D01X.MMO` SHA-256
`126811cc8383154f2d9fa67c81bbb0dac574704b58cc005148a5454fb0dbf196`,
`D01XAN.MMO`
`47a723b94717f348f1d857a8f15c0183a6d472478b501aba6ae3d883ee9aec95`,
and `D01X.AX`
`5935051506a30b98e7eae08cd5ba596638a05e59c02cce2a58536bf08ee03f79`;
the Y family is `D01Y.MMO`
`4f29f4b130b0a702450326f3a29381b379a5bfa6417e80e46929fb4755218cd0`,
`D01YAN.MMO`
`a7a017ebd6dc0a3fbea006aa16d75ff793fe3796bf5d21f4c8e4a4bc44e97402`,
and `D01Y.AX`
`2cdaa8a87771cef44b9303f659d09c612213941be3b60b1521b52e1897873539`.
`D01X/Y.MMO` decode to 640x400; the corresponding foreground MMOs decode to
120x168 and 112x192. Direct original index reads require `D01Z.MMO`,
`D01ZAN.MMO`, and `D01Z.AX` to remain absent. Default `HHMM=0000` therefore
shows an expected missing-original-resource diagnostic and may continue to
dialogue without substituting daytime media.

The later reached mode-0 surface envelopes `0x0C9B..0x0CC0` and
`0x132C..0x1351` are separate EVENTD02 paths; they must not be conflated with
the normalized prefix branch that bypasses `0x023F..0x0264`. The full-session
original-content guard separately binds later `D02X.MMO` to SHA-256
`b9852c0b70dc0cb3cd2004367659117d17d76ab3f5fdbc68d551418345ce4039`,
`D02Y.MMO` to
`173682b430708ad41e4de4fa5efd9fd60a594a266ce0b605d4e6c0c5c103be74`,
and requires `D02Z.MMO` to remain absent. Those are later EVENTD02 surface-path
resources, not replacements for the coordinate-zero D01 time-band family.
Reached foreground records and surfaces remain metadata/overlay-aware tool
previews, not proof of native placement or blitting. All original ARCs remain
read-only. Any source,
hash, coordinate, expected-presence/absence, or bounded-resume mismatch disables
the confirmed start before the current presentation is cleared instead of
falling back to `0x03E6`; overlay resolution may change presentation bytes but
cannot weaken the original-source guards.
Evidence type: direct authoritative `EVENTD02.MES`, `12C.MES`, and
`LIBLARY.LIB` bytes; exact transfer and surface-envelope scans;
configured-original executable audit v38; strict original MMO decode; all-ARC
resource lookup; hash-bound Event Player controller replay; and unchanged
archive hashes. Confidence: **Confirmed** for the coordinate-zero call and
prefix, stored stream extent, exact `0x0BB4` resume, 40-dialogue bounded route,
completion write, return, and caller BGM/handoff boundaries, request selection,
state writes, and target; **Tool omission policy** for native record, surface,
AX, and display/cursor effects; **Unresolved** for native foreground placement,
composition, those omitted effects, and the final handoff consumer.

## EVENTD03

**Scene role:** fish-shop Maki encounter presented as a full event scene.

**Container and coverage:** 12 address-table entries, 2,099 code bytes, 100%
structurally covered by the current basic-block decoder. The authoritative
binding is `mes.arc` SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`,
`EVENTD03.MES` SHA-256
`3c189313411fdbe151819fae44b809e1395ee08a76d5325f1b5f4f92e3d9e6fb`,
and `12C.MES` SHA-256
`c71563238cd4e14a06125b8cd139f7e6a304024dbd7c32ed5a3619ca425726eb`.
The reached `D03.MMO` entry is 334,171 bytes with SHA-256
`aa04ef0c8b4452c660ba7c4afb8581c35c7b45755edd775bbd720490d7507313`.

Confirmed flow:

- `12C.MES` calls `eventd03.mes` through the command-`0x0F` envelope at
  `0x0DDE` (decimal 3550). The exact 16-byte envelope ends at physical caller
  resume `0x0DEE` and names the callee; its slice SHA-256 is
  `c8437d0d76696f154c9351c111bceca41b06d9c0bbde54356c0f30b5b2fa951c`.
  Configured-original executable audit v38 independently confirms command
  `0x0F` routing through manager slot `+0x38` to handler `0x004192A0`, entering
  the selected MES at coordinate zero, and restoring the saved caller
  coordinate after return. The checked launcher SHA-256 is
  `3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5`;
  its embedded runtime SHA-256 is
  `5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da`.
- The hash-bound one-click route therefore begins at code-relative coordinate
  `0x0000`, not at the later BGM assignment. The exact bootstrap
  `0x0000..0x0008` has SHA-256
  `1d5fcfa66928c2bd712394fcd5e001e48b41b60f943039c72d06687224953e5c`
  and its command `0x14` dispatches address-table entry zero at `0x0008`. From
  there the confirmed default-state chain reaches shared routine 28 at
  `0x00E6` (resume `0x00EB`),
  then two adjacent command-`0x12` typed-record lists at
  `0x0105..0x0110` and `0x0110..0x011B`. Each list contains exactly three
  records and its consumed NUL terminator; their combined slice SHA-256 is
  `933fba657726df053a842f8783286d3cc7baf56d82ba641ded08810b62df2303`.
- After that explicitly bounded omission, the original path reaches the outer
  MMO presentation command at `0x01A3`, its `D03.MMO` marker at `0x01A4`,
  and physical end `0x01B0`; the outer slice SHA-256 is
  `5b85990ab1eb91336b8cb0f080057f3f404de55790d12dd04611833a55815c86`.
  The independent command immediately following it writes
  `banked_u16[0][1] = 7` at `0x01B0..0x01B7` (slice SHA-256
  `ae67de6b76e2d443778d2e8b71b62163a36802ab9e9f6f6a43071ec096047fd9`).
  The surface operation at `0x01B7..0x01DA` has slice SHA-256
  `c10e66167a2b9544b386f809d18d1a281432565d9cadd3d0e7888c67783504fd`.
  With fresh sandbox `global_u8[4000] == 0`, control reaches routine 21 at
  `0x020F` (resume `0x0214`), routine 28 at `0x021F` (resume `0x0224`), BGM
  selector `33` at `0x022E`, and routine 23 at `0x0234`, which resolves
  `MAKI.WAV`. The first supported dialogue boundary is then `0x0284`, with
  three message rows and physical resume `0x0288`.
- The first supported dialogue boundary at `0x284` resumes at `0x288`, records
  post-message ID `47181` through shared routine `0` at `0x290`, and reaches
  the next dialogue boundary at `0x2e2`. Continuing at `0x2e6` retains the
  bounded `D0977.OGG` voice presentation control at `0x305` (nested
  subcommand/name record `0x306`) and reaches the following
  dialogue boundary at `0x378` (resume `0x37c`). This is a bounded physical
  continuation, not a reconstructed caller stack or a claim that the host
  audio device actually emitted sound.
- The runtime projection contains 11 dialogue records and four exact
  filename-bearing voice markers. Their ARC targets and native presentation-
  subcommand-7 queue/stream route resolve. Executable audio audit v7 further
  resolves the Ogg consumer's terminal call to
  `IDirectSoundBuffer::Play(0, 0, DSBPLAY_LOOPING)`; physical device output is
  not observed by the static audit.
- The event writes completion flag `global_u8[751] = 1` at offset `1918`.
- Explicit continuation from coordinate zero traverses the prefix above and 12
  bounded dialogue trailers with sequential message-record IDs `47181..47192`,
  validates all four voice targets, applies the completion flag only to sandbox
  state, and reaches the confirmed script-return byte at `0x7ff`. Event Player marks
  that exact hash-bound return as EVENTD03 completion and displays the confirmed
  `12C.MES:0x0DEE` caller resume without entering it automatically. Only the
  separately bounded BGM prefix below is available as an explicit next action.
- The first 116 caller bytes at `12C.MES:0x0DEE..0x0E62` form a separable BGM
  prefix before command `0x03` at `0x0E62`. Two valid date branches test
  `state_u16[7] == 1224` and `== 1301`, selecting routine-23 BGM requests
  `26 / X_MAS.WAV` and `42 / SHOGATU.WAV`; all other dates select
  `1 / IDOU.WAV`. Hash-bound probe runs for dates `1224`, `1301`, and `500`
  each reach `0x0E62`, emit exactly one expected request, and make no sandbox
  state change. Event Player exposes this prefix only as an explicit
  post-completion **Preview Caller BGM** action and stops before `0x0E62`.
  The Christmas/New Year branches are structural caller evidence, not
  EVENTD03 availability: the confirmed EVENTD03 gate restricts its ordinary
  route to dates `401..615`. Evidence type: direct authoritative `12C.MES`
  decode, exact-slice hash, shared BGM catalog, and headless three-date route
  replay; confidence: **Confirmed** for the bounded BGM selection.
- The exact 38-byte caller suffix `0x0E62..0x0E88` is separately hash-bound.
  Command `0x03` at `0x0E62` writes `global_u8[286] = 1`, command `0x07` at
  `0x0E6D` writes `banked_u16[0][242] = 12`, and command `0x0E` at `0x0E7B`
  names `MACHI.MES`. Event Player exposes this only after the confirmed caller
  BGM prefix as **Continue Caller Handoff**, then marks the route complete at
  that handoff and does not execute its unresolved host consumer. The native
  storage mappings are independently established by native-handler analysis.
  Configured-original executable audit v19 locks their wrappers, all three
  manager vtables, handlers `0x00418A60`/`0x00418F50`, and evaluator calls,
  then reconfirms command `0x0E` wrapper `0x004182EE` and handler
  `0x00419210`.
  Evidence type: direct authoritative `12C.MES` bytes, exact-slice SHA-256,
  headless UI-controller execution, and configured-original executable
  handler audit; confidence: **Confirmed** for both sandbox writes, target,
  and boundary, **Unresolved** for the host consumer of the active string.
- The configured-original executable audit confirms command `0x12` typed-
  record ingress and the command-`0x0D` presentation stream's subcommand-9
  named-MMO and subcommand-11 surface handler families. It does **not** prove
  the concrete effects of the two typed-record lists, the active surface
  selected by the scene, or native placement/composition. Event Player
  therefore offers **Continue (Omit Native Records)** only for the two exact
  hash-bound lists, decodes the naturally reached `D03.MMO` as a 640x400 tool
  preview, records the reached surface operation, and omits native pixels.
  Shared-routine stops use only bounded library execution and explicit
  continuation; the three pre-dialogue stops are fail-closed to exact
  `28@0x00E6/0x00EB`, `21@0x020F/0x0214`, and
  `28@0x021F/0x0224` tuples. The first routine 28 normalizes a sandbox seed
  `global_u8[4000] = 1` back to `0`, so the subsequent tested path still takes
  the documented default branch. No native call frame or presentation effect
  is invented.
- This route fails closed if the archive or entry hash, bootstrap/caller/slice
  hash, offsets, record counts/terminators, MMO name/end, default branch, or
  requested BGM differs. The original `mmo.arc` base layer must retain the
  recorded `D03.MMO` entry hash even when the resolver presents an overlay
  replacement at runtime. Original `mes.arc`, `mmo.arc`, `bgm.arc`, and
  `voice.arc` are opened read-only and their hashes are rechecked unchanged.
  Evidence type: direct authoritative ARC bytes and media lookup, exact slice
  hashes, headless Event Player replay, and configured-original executable
  audit v38. Confidence: **Confirmed** for the original coordinate-zero caller,
  stored prefix order and coordinates, independent banked write, default
  branch, BGM request, and first dialogue boundary; **Tool omission policy**
  for typed-record effects and native surface pixels; **Unresolved** for active
  surface identity, placement, composition, and the caller handoff consumer.

Internal branches, which are not availability conditions:

- `state_u16[8] == 0`, `1`, or `2` at offsets `245`, `300`, and `355` selects
  unresolved internal dispatch paths;
- `global_u8[4000] == 0` selects the documented zero-start default branch;
  the value-one alternative at offset `474` remains unresolved;
- HHMM presentation bands test `< 0600`, `< 0900`, `< 1600`, and `< 1800` at
  offsets `1944`, `1967`, `1990`, and `2013`.

One apparent branch at offset `486` is not executable in the current decoder;
its expression stack is empty and is retained only as a diagnostic.

## EVENTD05

**Scene role:** Maki fish-shop event with a three-way choice. All three choices
reach the normal completion handoff and write its completion flag. The former
choice-3 early-return claim is corrected below.

**Container and source binding:** authoritative `EVENTD05.MES` SHA-256
`525dbd286ea252232dbda6511c0fa3091315a77b20a838c0ec0576a33717b335`.
Unlike the nested command-`0x0F` callers above, the authoritative `01M.MES`
entry (SHA-256
`a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5`)
contains command `0x0E` at `0x9E52`; instruction v28 decodes its safe ASCII
target as `EVENTD05.MES` and its physical end as `0x9E62`. The configured
original-executable audit binds command `0x0E` to wrapper `0x004182EE` and
handler `0x00419210`, which copies the record result into the native active
string and raises presentation flag mask `8`. Which host layer consumes that
string remains unresolved, so Event Player calls this a handoff marker rather
than claiming a nested call or caller stack. Evidence type: direct hash-bound
authoritative entries plus configured-original executable dispatcher,
vtable, and handler audit; confidence: **Confirmed** for the record, target,
physical end, and native active-string update; **High-confidence contextual**
for the handoff role; **Unresolved** for its host consumer.

Confirmed bounded route:

- `EVENTD05.MES:0x03F0` assigns BGM selector `33`; `0x03F6` invokes shared
  routine `23` and resolves `MAKI.WAV`. The first dialogue boundary is
  `0x0469`, with physical resume `0x046D`.
- Before the choice, explicit continuation reaches boundaries `0x0469`,
  `0x04BE`, `0x0554`, `0x05A6`, `0x0601`, `0x0645`, `0x06DF`, `0x072B`,
  then shared routines `28`, `27`, `25` with the separately audited DEF-26
  composition, `21`, `32`, and `28`. The exact command-`0x0F` envelope at
  `0x0822..0x082F` targets hash-bound `D_PIC.MES`. Event Player does not
  execute its native nested-script context; its explicit continuation instead
  retains the current D05 background and previews the separately confirmed
  `D_PIC.MES:0x00CC` `D.MMO` green-key standing layer. The original placement
  and compositor remain unresolved. Four more dialogue boundaries at
  `0x086A`, `0x08EC`, `0x0953`, and `0x0A27` lead to the choice. Ordered
  prefix voice markers are `D0981.OGG` through `D0985.OGG`.
- The three option definitions have IDs `0,1,2`, source offsets `0x0A51`,
  `0x0A94`, `0x0ACD`, and targets `0x0A8F`, `0x0AC8`, `0x0B0D`. Routine
  `40` stops at `0x0B17`, with physical resume `0x0B1C`. The hash-bound tool
  projection writes only the one-based choice to isolated `state_u16[21]`.
  Native routine-40 input remains unresolved.
- Choice 1 reaches `0x0B7A`, `0x0BDE`, `0x0C1B`, `0x0C95`, `0x0CDC`,
  `0x0D56`, and `0x0DA3`; choice 2 reaches `0x0E53`, `0x0EB7`, `0x0EF4`,
  `0x0F7A`, `0x0FD7`, `0x1061`, and `0x10C4`. Both converge at `0x142D`,
  cross exact command-`0x12` typed-record boundary `0x1494` whose three
  expression records plus list terminator end at `0x149F`, run
  routines `27`, `25` with DEF-26, and `21`, and reach common dialogue
  boundaries `0x159E`, `0x1607`, `0x1646`, and `0x169D`. Their final route
  writes `global_u8[753] = 1` and stops at command-`0x0E`
  `EVENTD05.MES:0x173B`, whose target is `MACHI.MES`. Event Player marks this
  exact target and flag combination as normal completion while leaving the
  unresolved host handoff unexecuted. The last distinct route voice is
  `D0995.OGG`.
- Choice 3 instead reaches dialogue boundaries `0x1155`, `0x11B9`, `0x11F6`,
  and `0x126E`, then the exact command-`0x0D` stream at `0x12AC..0x12B3`.
  The tool offers an explicit bounded omission of that stream's unresolved
  display/cursor effects. A second outer presentation control at `0x1301`
  contains the now-confirmed subcommand-7 voice record beginning at `0x1302`;
  it queues and previews `D0994.OGG` without an additional native omission.
  The continuation then reaches the remaining dialogue boundaries `0x12CE`,
  `0x135A` and `0x13A1`, joins the common path at `0x142D`, and reaches the
  same `0x173B` MACHI handoff with `global_u8[753] = 1`. It also traverses the
  shared `0x1494` native record, routines `27`, `25` and `21`, and final
  dialogues `0x159E`, `0x1607`, `0x1646` and `0x169D`. Its route-specific voice
  markers are `D0992.OGG`, `D0993.OGG` and `D0994.OGG`, followed by common
  `D0995.OGG` after the retained prefix.

**Choice-3 boundary correction, 2026-09-06.** The previous claimed early return
at `0x1380` was a tool interpretation defect. That coordinate belongs to the
original `protagonist_name_insert` record `0x137A..0x138A`; it is not a
command-`0x00` boundary. After the explicitly omitted `0x12AC..0x12B3` native
span, the tool accidentally retained a global bounded-native-skip policy.
The later separator at `0x1379` then advanced into the name record's payload,
eventually exposing its internal zero as a false return. The D05 continuation
now restores the default stop policy after that one audited omission, preserving
the subsequent name/text records and the complete choice-3 route above.
Catalog v5/revision 20 removes the false early-return terminal and maps all
three choices to the callee-owned `0x173B` handoff, still requiring completion
flag 753. Evidence: hash-bound authoritative `EVENTD05.MES` structural IR,
bounded runner traces and all-three-choice Event Player integration. Confidence:
**Confirmed** for record ownership and corrected tool control flow; the native
effects omitted at `0x12AC` and the native entry activation remain unresolved.

The pre-anchor full-frame route tests sandbox HHMM at the stored envelopes:
before `0600` uses `D05Z.MMO` at `0x01BD`; `0600..0899` uses `D05X.MMO` at
`0x01DC`; `0900..1559` uses its second envelope at `0x01FB`; `1600..1759`
uses `D05Y.MMO` at `0x021A`; and `1800` onward uses `D05Z.MMO` at `0x022D`.
This is labeled pre-anchor context rather than executed native presentation.
The integration validator reopens original `mes.arc`, `mmo.arc`, `bgm.arc`,
and `voice.arc`, checks the source hashes or bounded media fingerprints before
and after, exercises all three choices, and never opens a GUI or gameplay save.
Confidence: **Confirmed** for entry hashes, offsets, branch-specific terminal
states, completion flag, BGM/voice resource resolution, and bounded native
probe ends; **Tool omission policy** for skipped display/cursor effects and
D_PIC composition; **Unresolved** for native selection input, image placement,
and command-`0x0E` host transitions.

## EVENTD06 Fragment Catalog and EVENTD14 Confirmed Bootstrap

Both entries contain address-table catalogs, and their native host-side
selection rule for nonzero rows remains unresolved. Event Player therefore
keeps entries 1 and above as independent, read-only **Fragment** previews and
does not concatenate them into a native order. Their entry-zero paths now have
different status. EVENTD06 remains conservative source-table analysis with
**Preview Setup** and disabled **Start Event**. EVENTD14 has an original
command-`0x0F` zero-coordinate caller, exact command-`0x14` bootstrap, and a
continuous decoded path from entry zero to original dialogue and a three-way
choice. It therefore exposes **Start Confirmed Event** without claiming an
order for the separate nonzero fragment rows.

From a fresh all-zero sandbox, EVENTD06 starts at verified entry zero `0x0008`,
reaches shared routine 28 at `0x00E6` with 11 state records, and resumes at
`0x00EB`. Command `0x12` is one typed-record list spanning
`0x0105..0x0110`; the explicit omission action skips its three records and
terminator. Corrected MMO presentation boundaries expose the following
command-`0x07` at `0x022D` as an independent
`banked_u16[0][1]=7` write. The all-zero route consequently continues through
routines 21/28, four dialogue boundaries, routines 27/25, the audited DEF26
body, routine 21, and seven more dialogue boundaries. It stops fail-closed at
native presentation boundary `0x0B52` with three retained message records and
23 isolated state records. (Since Core 0.316.0, 2026-09-13, `0x0B52` is
`System.function[12](30)`, an omitted call: the setup runs on through an
eighth dialogue at `0x0B5F` to the extension terminal, routine 21 at
`0x0C0E`, and the catalog records that terminal with no message of its own.) The count was 26 before the selector-1 AX
payload-shadow correction recorded above, which removed the
`global_u8[767..769]` writes; the route, its stops, and their coordinates are
unchanged, and the count holds at 23 through the extension terminal at
`0x0C0E`. At that exact hash-bound stop, **Continue (Omit Setup FX)** may skip
only the six-byte command-`0x0D` stream through its NUL at
`0x0B59`. That single continuation collects one further message ending at
`0x0B7F` and stops at shared routine 28 `0x0B83` (resume `0x0B88`); it does not
create an intermediate dialogue stop. After that routine returns, the stored
suffix reaches the `D07.MMO` record at
`0x0BA2..0x0BAF`, executes the independent following write
`0x0BAF..0x0BB6`, and decodes the surface operation at `0x0BB6..0x0BD9`.
With isolated `global_u8[4000] == 0`, the controller stops at routine 21
`0x0C0E`; its stored resume is `0x0C13`, before routine 28 at `0x0C1E`.
Routine 28 normally initializes this flag to zero. A separate isolated probe
from its stored caller resume `0x0B88` with value `1` crosses the alternate
surface record `0x0BE4..0x0C09` and stops at routine 28 `0x0C1E` (resume
`0x0C23`). Neither terminal routine offers a continuation in this bounded
unit. This remains a sandbox-only setup-derived route; neither branch
establishes that the unresolved native host selected a fragment.

EVENTD14 starts at code coordinate zero and transfers to entry zero `0x0008`.
It reaches routine 28 at `0x014D` with 12 state records, resumes at `0x0152`,
and reaches command `0x12` at `0x016C`. **Continue (Omit Setup Records)**
skips exactly three typed records and their terminator through `0x0177`.
Continuation then crosses a second routine-28 boundary at `0x0288` and invokes
registered DEF 21 at `0x032E..0x0333`. The runtime-only registry maps this
selector to `DEF_MAIN.MES` registration `0x10BD` and body
`0x10C4..0x1102`; the body is composed read-only and returns to EVENTD14.
Fourteen original dialogue boundaries follow at `0x037D`, `0x03ED`, `0x044E`,
`0x04C8`, `0x0507`, `0x0537`, `0x0576`, `0x05EA`, `0x064F`, `0x06CD`,
`0x0734`, `0x079E`, `0x07E7`, and `0x0861`. Routine 40 then stops at the
three-way DEF selection boundary `0x0942`. The decoded DEF rows are IDs
`0/1/2`, source coordinates `0x08A0/0x08CF/0x0902`, and targets
`0x08CA/0x08FD/0x0938`. Keyboard or pointer confirmation writes only isolated
`state_u16[21]`, preserves evaluator carry, and resumes at `0x0947`. The
choice boundary has 22 sandbox state records, 25 before the same selector-1 AX
payload-shadow correction.

All three explicit sandbox choices now continue through their complete stored
EVENTD14 branches to the common script return at `0x256D`. Choices 1 and 3 end
with 42 authored sandbox records; choice 2 ends with 43 — 45 and 46 before the
same correction, which removes those three cells from every route. Their
reached dialogue boundary counts after selection are 22, 20, and 10. The controller composes
only hash-bound registered calls: selector 21 uses
`DEF_MAIN.MES:0x10C4..0x1102`, selector 22 uses
`DEF_MAIN.MES:0x1109..0x116E`, and selector 26 is supplied only when routine
25 reaches its audited `LIBLARY.LIB:0x1E22` invocation. The three routes cross
original `D_PIC.MES` dispatches at `0x0ED4..0x0EE1`,
`0x1963..0x1970`, and `0x21CA..0x21D7`, respectively. The tool previews the
confirmed `D.MMO` resource and resumes without executing unresolved native
placement effects. (Since Core 0.316.0, 2026-09-13, the `D.MMO` standing
layer is retained to completion on choice 1 only: choices 2 and 3 cross a
second routine 27/25/21 group after their `D_PIC.MES` dispatch, and routine 27
- which the separator framing cut after four rows at the `00` of a message
wait read as command `0x00` - now runs its nineteen rows, whose decoded
surface operations clear the keyed foreground.) Choice 2 additionally omits the exact six-record command-
`0x12` list at `0x13E1..0x13F9`. The final selector-22 call at
`0x254E..0x2553` is common to all routes. When the exact original entry hash,
choice state, final trace row, and terminal coordinate all match, Event Player
shows **Event complete** and records that confirmed caller `12C.MES` resumes at
`0x1C33`. The route-common completion write is `global_u8[763] = 1`; choice 2
also writes `global_u8[764] = 1`. Event Player requires the common write before
offering the caller route, so a coincidental return at the same coordinate is
not promoted to a completed event.

The first 116 caller bytes at `12C.MES:0x1C33..0x1CA7` are a separable BGM
prefix. They have SHA-256
`a54ea9d00cb70b0d56f73f1696396cfbfb18ab0aecd7acb472a071e5c5f09e37`.
The branch at `0x1C3D` selects `26 / X_MAS.WAV` when isolated
`state_u16[7] == 1224`; the branch at `0x1C5E` selects
`42 / SHOGATU.WAV` when it equals `1301`; all other dates take the explicit
`1 / IDOU.WAV` default at `0x1C97`. Hash-bound probes for dates `1224`, `1301`,
and `500` each reach `0x1CA7`, emit exactly one expected routine-23 BGM
request, and make no sandbox state change. **Preview Caller BGM** executes only
this bounded prefix.

The following `12C.MES:0x1CA7..0x1CCD` suffix has SHA-256
`bd635b269519a2fc24140e20e8d727ebdcef11e255e78ebcd3bb29d8cf0e5ea2`.
Its isolated command sequence writes `global_u8[286] = 1`, writes
`banked_u16[0][242] = 12`, and reaches the command-`0x0E` `MACHI.MES`
handoff at `0x1CC0`. **Continue Caller Handoff** stops at that marker without
executing its unresolved host consumer. Neither caller action changes a
gameplay save.
Configured-original executable audit `kakyu_ai5_mes_exe_audit/v34` retains
v28's command-`0x0F` zero-start/caller-coordinate restore,
command-`0x11` registered-pair call/restore, shared-routine call/restore, and
command-`0x12` typed-record ingress used by this composition. It also confirms
the command-`0x03`/`0x07` storage handlers and command-`0x0E` active-string
behavior used by the caller suffix. The branch coordinates, resource selectors,
terminal counts, and filenames come from direct authoritative ARC execution
and media validation; the EXE audit does not itself prove those resources,
native presentation placement, the original input producer, or the final host
consumer. Evidence type: direct hash-bound original ARC bytes, bounded
controller execution, original-ARC media lookup, and original-EXE handler
audit; confidence: **Confirmed** for stored control flow, terminal coordinate,
completion state, bounded caller BGM selection, and handoff marker, **Tool
omission policy** for record/presentation effects, and **Unresolved** for
native input, placement, pre-event BGM inheritance, and the handoff consumer.

`EVENTD06.MES` has authoritative SHA-256
`ce90c77ca8ca6dae38b236eb5dfc19ef1848083b433d86d9f49331968769c142`,
inside authoritative `mes.arc` SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`,
67 address-table entries, and code size `0x26A4`. Its hash-bound caller is
`10C.MES` SHA-256
`b7768ecb57e2df01408c3d8fa49e9ecb1e67b1e01dbd6c7e643520d4240068db`:
command `0x0E` at `0x5F77..0x5F87` names `EVENTD06.MES`. Entry zero begins at
`0x0008`, reaches shared routine 28 at `0x00E6` (resume `0x00EB`), reaches a
native command-`0x12` typed-record boundary at `0x0105` (three records plus
terminator; resume `0x0110`). Outer MMO record `0x021F..0x022D` names
`D06Z.MMO`; the immediately following exact command `0x07` at
`0x022D..0x0234` writes literal 7 to `banked_u16[0][1]`. Audit v38's command-
`0x07` handler and presentation-subcommand-9 route confirm that these are
separate native operations. The verified fresh-state route then follows the
routine/dialogue/DEF26 sequence above and stops at `0x0B52`; a second
`D07.MMO` record at `0x0BA2..0x0BAF` is followed by the same independent write
at `0x0BAF..0x0BB6`. The exact command-`0x0D` bytes at `0x0B52..0x0B59`
contain six native-stream payload bytes including the consumed NUL. Explicit
bounded omission collects one message ending at `0x0B7F` and stops at routine
28 at `0x0B83/0x0B88`, the
`D07.MMO` marker at `0x0BA3`, and the command-`0x0B` surface record
`0x0BB6..0x0BD9`. The original branch reads `global_u8[4000]`: zero reaches
routine 21 at `0x0C0E` with stored resume `0x0C13`. A separate isolated
`0x0B88` branch probe with value one selects the alternate surface record
`0x0BE4..0x0C09` and reaches routine 28 at `0x0C1E`.
Its stored resume is `0x0C23`. The controller treats both as terminal without a
continuation in this unit and does not infer which branch or fragment the
unresolved native host selects. Entries 1 through 66 are short dialogue
fragments. They contain 32 voice markers,
`D0996` through `D1027`,
all resolved in `voice.arc`. The `D06Z.MMO` marker at `0x0220` is absent from
the original ARC indexes, while the `D07.MMO` marker at `0x0BA3` resolves.
No local selector-33/routine-23 BGM request was found; any inherited music or
presentation context remains unresolved. Configured-original executable audit
v37 was rerun against launcher SHA-256
`3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5`
and embedded runtime SHA-256
`5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da`.
It retains command-`0x0E` wrapper `0x004182EE`, dispatcher slot `+0x34`, and
handler `0x00419210`. It also confirms command-`0x0D`'s NUL-consuming native
character stream, presentation subcommand 9's named MMO load, and subcommand
11's surface-record family. The handler copies the evaluated record string and
sets the presentation flag; it does not itself invoke `EVENTD06.MES`, which is
why the setup preview remains source-table analysis rather than an
original-event start claim.

`EVENTD14.MES` has authoritative SHA-256
`4279a51fc9510d2442b537b9cf28613074da000d35c3c72ba9758dae63e1b24f`,
66 address-table entries, and code size `0x257E`. Its hash-bound caller is
`12C.MES` SHA-256
`c71563238cd4e14a06125b8cd139f7e6a304024dbd7c32ed5a3619ca425726eb`:
command `0x0F` at `0x1C23..0x1C33` names `EVENTD14.MES`. Entry zero begins at
`0x0008`, reaches shared routine 28 at `0x014D` (resume `0x0152`), reaches a
native command-`0x12` typed-record boundary at `0x016C` (three records plus
terminator; resume `0x0177`), and continues through the confirmed DEF-21 and
dialogue path described above. Entries 1 through 65 remain separately
inspectable short dialogue fragments; their native host selection is
unresolved and is not used as evidence for the zero-start event order.
The `D15SSAN.MMO` marker at `0x02B1` resolves in `mmo.arc`; 28 voice markers,
`D1035` through `D1062`, all resolve in `voice.arc`. No event-local BGM request
was found before the return; the inherited pre-event music remains unresolved.
The confirmed caller-owned post-return BGM prefix is documented above.
Configured-original executable audit v34 retains v28's confirmation that command `0x0F`
saves the caller coordinate, sets the selected script's code coordinate to
zero, invokes it, and restores the caller coordinate afterward. At
`EVENTD14.MES` code coordinate `0`, exact bootstrap command `0x14` transfers to
address-table entry zero at `0x0008`. This establishes the continuous entry-zero
route to the choice, but not a nonzero fragment order. The same audit checks a
separate shared public zero-start context-call method at `0x0042B2C0`; its
bounded body contains no address-table lookup and does not close the remaining
fragment-selector gap.

The original-content validator reopens `mes.arc` read-only, requires both
target and caller hashes, validates every command-`0x17` entry label against
its table index, checks the exact caller envelope, and starts all 131 nonzero
fragments in fresh isolated states with the active address table supplied.
It also replays both entry-zero sequences. EVENTD14 checks the exact routine,
record, registered-DEF, fourteen-dialogue, and three-choice coordinates through
`0x0942`, requiring 12 records at the first routine boundary and 25 at the
choice. It then confirms that all three options write `state_u16[21] = 1..3`,
resume from `0x0947`, cross their exact DEF, shared-routine, typed-record, and
`D_PIC.MES` boundaries, and return at `0x256D` with 45, 46, and 45 sandbox
records. The expected post-choice stop-type counts and completion-state
candidates are locked per route without storing dialogue text. Each controller
route invokes the shared source validator, which replays all three date-selected
`12C.MES:0x1C33..0x1CA7` BGM branches; the controller then previews its current
sandbox-date branch and executes the exact `0x1CA7..0x1CCD` `MACHI.MES` handoff
suffix.
EVENTD06 follows
`0x0008 -> 0x00E6/0x00EB -> 0x0105/0x0110 -> 0x022D -> 0x0B52/0x0B59`,
requiring 11 records at the first routine boundary and 26 at the fail-closed
native-presentation boundary while retaining the unresolved host-activation
label. The exact bounded continuation then reaches
`0x0B59 -> 0x0B83/0x0B88 -> 0x0BA2..0x0BD9 -> 0x0C0E` for the fresh zero-state
branch, retaining stored routine-21 resume `0x0C13` without executing it. The
isolated `0x0B88` value-one branch probe substitutes `0x0BE4..0x0C09` and
stops at routine 28 `0x0C1E` (stored resume `0x0C23`).
Native command-`0x12` record effects and registered DEF26 presentation effects
are explicitly omitted rather than simulated; the command-`0x07` write is
executed because its storage grammar and separation from the MMO record are
confirmed.
EVENTD06 reaches 65 dialogue boundaries and one native-presentation boundary,
retaining 136 message records; EVENTD14 reaches 64 dialogue boundaries and one
DEF-selection boundary, retaining 130 message records. No fragment changes
sandbox state or stops at a decode, expression, address, write, step-limit, or
unsupported-command failure. The controller-level sample additionally
previews fragment 1 of each catalog; both reach one dialogue boundary with no
sandbox state change. Executable audit v38 independently confirms the command-
`0x0F` zero-coordinate nested start plus command-`0x17` entry-label and command-
`0x18` address-table-dispatch machinery, but no isolated catalog entry reaches
`0x18`, so it does not resolve the host selector.
Evidence type:
direct hash-bound authoritative entries, caller envelopes, original ARC media
lookup, and configured-original executable handler audit at `0x004192A0`;
confidence: **Confirmed** for catalog shape, labels, caller records, EVENTD14's
zero-start route through DEF 21, fourteen dialogue boundaries, choice
coordinates, all three post-choice script-return paths, completion state, and
bounded post-return BGM/handoff route, EVENTD06's all-zero entry-zero analysis
path, exact post-`0x0B52` branch coordinates and safe terminal routines, sample
fragment execution, and resource existence; **Tool omission policy** for
command-`0x12` record effects, the exact command-`0x0D` setup stream, and
registered DEF26 and surface presentation;
**Unresolved** for EVENTD06 host activation, both catalogs' nonzero fragment
selection and ordering, EVENTD14 pre-event BGM inheritance, final handoff
consumer execution, and native presentation placement.

## EVENTD08

**Scene role:** later fish-shop Maki encounter with a three-way choice and a
caller-owned follow-up after the world-map presentation is restored.

**Container and source binding:** authoritative `mes.arc` SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`;
`EVENTD08.MES` SHA-256
`add5a481c407c863b646799d961033c5ce62da1b1874c227fd41d5685e7fd31c`;
`12C.MES` SHA-256
`c71563238cd4e14a06125b8cd139f7e6a304024dbd7c32ed5a3619ca425726eb`;
and `D_PIC.MES` SHA-256
`72473432ce3dd6e0fc1e994a737dbecd5494eaf4477efc24368d3b3160d7fecd`.
The event has 17 address-table entries and 2,807 code bytes, all structurally
covered. Event Player enables the complete route only when all four hashes
still match and every entry resolves directly from the original ARC.

Confirmed flow:

- `12C.MES` calls `D_PIC.MES`, `EVENTD08.MES`, and `D_PIC.MES` in that order.
  The condition guarding that call is at `12C.MES:0x0E97`, and the exact
  command-`0x0F` envelope at `12C.MES:0x0FA6..0x0FB6` names `eventd08.mes`. Configured-original executable audit
  `kakyu_ai5_mes_exe_audit/v67` was rerun against launcher SHA-256
  `3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5`
  and embedded runtime SHA-256
  `5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da`.
  It retains the command-`0x0F` route through manager slot `+0x38` to handler
  `0x004192A0`, which saves the caller coordinate/context, enters the selected
  MES at coordinate zero, and restores the caller pair after return. The first
  EVENTD08 address-table entry remains `0x0008`; the tool starts at the native
  zero coordinate rather than treating that entry offset as an inferred host
  selector.
- `D_PIC.MES:0x9a` assigns selector `33` and `0xa0` invokes routine `23`, so
  EVENTD08 inherits Maki's BGM on entry.
- The event-local background is `D08.MMO`. Its exact outer statement separator
  is at `0x045A`; the presentation-subcommand-9 marker starts at `0x045B` and
  ends at `0x0467`. The filename bytes occupy `0x045E..0x0464` inclusive; its
  C string ends with its own NUL at `0x0465`, the common-record argument list
  ends with a second NUL at `0x0466`, and the following independent
  command-`0x07` begins at `0x0467`. The recorded native one-name adapter
  origin remains `(-1,-1)`; active-surface identity and native placement/
  composition are unresolved, so the decoded MMO is a tool preview.
  Immediately before it, selector 6 at `0x0445..0x044C` and selector 2 at
  `0x044C..0x0453` are complete native AX controls. Exact selector-2
  consumption removes the former shadow command-3 interpretation of payload
  bytes as `global_u8[767] = 2`; the zero-coordinate prefix now has five
  sandbox changes rather than six and preserves the incoming `[767]` value.
  Evidence type: read-only authoritative `EVENTD08.MES` byte scan, original-EXE
  selector-2 dispatch/handler audit v139, and repeated exact Event Player
  traces for the initial route plus choices 2 and 3. Confidence:
  **Confirmed** for `[start,end)` framing and absence of the gameplay-state
  write; native selected-cell rendering remains **Unresolved**.
- Event Player's hash-bound start also validates the inherited Maki BGM through
  the preceding `D_PIC.MES:0x009A` selector-33 / `0x00A0` routine-23 request
  and loads `MAKI.WAV` from `bgm.arc`. This audio remains loaded across the
  later D.MMO caller restoration; it is not attributed to an EVENTD08-local
  request.
- From coordinate zero, the common prefix reaches nine dialogue boundaries at
  `0x013F`, `0x01A4`, `0x0240`, `0x02A9`, `0x0315`, `0x052B`, `0x059D`,
  `0x05E4`, and `0x0648`, with physical resumes `0x0143`, `0x01A8`,
  `0x0244`, `0x02AD`, `0x0319`, `0x052F`, `0x05A1`, `0x05E8`, and
  `0x064C`. These boundaries contain 17 decoded message fragments in counts
  `1,3,1,3,1,3,1,3,1`; reached voice markers are, in order,
  `D1028.OGG`, `D1029.OGG`, `D1030.OGG`, `D1031.OGG`, and `D1032.OGG`.
  Corresponding fragment-source groups are `0x0114`; `0x015A,0x015F,0x016F`;
  `0x01F3`; `0x025B,0x0260,0x0270`; `0x02F8`;
  `0x04FF,0x0504,0x0514`; `0x057A`; `0x05B8,0x05BD,0x05CD`; and `0x0633`.
  The prefix then reaches the existing three choices and branch dialogue.
  Follow-up records after the EVENTD08 return belong to `12C.MES`.
- The exact non-dialogue route between those groups is shared routine `28` at
  `0x039D` (resume `0x03A2`), two adjacent command-`0x12` typed-record lists
  at `0x03BC..0x03C7` and `0x03C7..0x03D2` with three records each, shared
  routine `21` at `0x04C6` (resume `0x04CB`), and shared routine `28` at
  `0x04D6` (resume `0x04DB`). Event Player may restart only the exact
  `0x03BC` boundary with `native_record_policy=omit_bounded`; this records two
  `native_record_effects_omitted` rows and applies none of their native side
  effects. It deliberately does not carry
  `native_stream_policy=skip_bounded` into that continuation. Record omission
  and character-stream presentation omission are independent authorities;
  conflating them can consume the MMO envelope incorrectly at its two-NUL
  boundary. Native record effects, surface writes, cursor/display effects, and
  final native placement remain unresolved.
- The three option definitions are the bounded command-`0x10` records at
  `0x0687`, `0x06C2`, and `0x06EB`, with literal DEF values `0`, `1`, and `2`
  and aligned skip targets `0x06BD`, `0x06E6`, and `0x072B`. Each skipped body
  contains one option label and returns before its target. Routine `40` follows
  at `0x0735`; the original EXE confirms command `0x10` as DEF registration and
  command `0x11` as selected-DEF invocation. Generic routine `40` input remains
  unresolved, but Event Player now exposes a deliberately narrower hash-bound
  projection for this exact route: keyboard or pointer selection writes only
  isolated `state_u16[21] = 1..3` and resumes at the physical post-transfer
  coordinate `0x073A`. The three projected paths reach their first original
  dialogue boundaries at `0x0780`, `0x0835`, and `0x09A7`; each contains three
  decoded message fragments and makes no further state change before that
  boundary. (Reported at the wait call since Core 0.316.0, 2026-09-13:
  `0x077D`, `0x0832`, `0x09A4`, same resume offsets.) Explicit continuation reaches `2`, `4`, and `2` total dialogue
  boundaries and `4`, `8`, and `4` decoded message fragments for choices
  `1`, `2`, and `3`. Their single voice markers are `D1033.OGG`, `D1034.OGG`,
  and `D1033.OGG`. All three routes then stop at command-`0x1D` offset
  `0x0A25`, which names shared routine `28`; the authoritative `LIBLARY.LIB`
  index locates that routine body at `0x02D0..0x03EB`. The strict decoder keeps
  its five-instruction execution boundary and stops explicitly at `0x02EE`,
  where command `0x0A` has an empty-stack destination. A separate read-only
  structural pass uses the EXE-confirmed `0x0A` extent `0x02EE..0x02F4` and
  reaches the indexed end `0x03EB`, exposing 71 top-level instructions. Eleven
  rows contain a terminated but non-singleton expression and are labeled
  structural-only. The native evaluator's stack persists across expression
  calls; the `0x02EE` command's local depths `[0, 2]` consume one incoming
  carried item and restore the same depth. Event Player labels that row
  `persistent stack min 1, delta +0`. A detached intro at the old
  `0x0687` choice coordinate does not reconstruct that carried value. The
  hash-bound zero-coordinate route now carries its temporary argument slots
  and persistent expression stack through every bounded continuation and into
  the choice projection, so its later routine-28 continuation no longer relies
  on an arbitrary-intro substitute. Native cross-checking also shows that the
  literal `1..17` command-`0x1B` run inside routine `40` clears one internally
  selected vector per record; it is not, on its own, evidence for a key-reading
  or result-write operation. A hash, DEF coordinate, target, or boundary
  mismatch leaves the options read-only.
- The standalone choice-coordinate validator continues the exact three
  EVENTD08 projected routes without changing their selection semantics. With
  that validator's intentionally empty temporary caller context, routine `28`
  takes the same eight-coordinate path, omits one EXE-bounded native
  presentation span, makes no nested call or gameplay write, preserves an
  empty evaluator stack, and returns to caller coordinate `0x0A2A`. The
  complete zero-coordinate Event Player route instead preserves the prefix's
  temporary arguments and evaluator carry through the choice; its first
  post-choice routine-28 run takes the corresponding six-row path, with the
  same one omitted presentation span, no nested call, and no routine-local
  sandbox diff. Both bounded tool paths then reach routine `27` at
  `EVENTD08.MES:0x0A5A`; the selected
  routine-27 path has four traced coordinates, one omitted presentation span,
  no nested call, and the single sandbox write `banked_u16[0][1] = 2` (observed
  as `1 -> 2` on this caller path). After
  that return, `EVENTD08.MES:0x0A66` calls routine `25`. Its bounded run reaches
  a command-`0x11` registered-DEF-`26` invocation at library coordinate
  `0x1E22` after three coordinates and stops
  before choosing or executing the native DEF body; it adds no state diff by
  default. With a second explicit Continue, and only while the authoritative
  `mes.arc`, `LIBLARY.LIB`, and `DEF_MAIN.MES` hashes still match, Event Player
  supplies the shared context index's selector-26 body
  `DEF_MAIN.MES:0x0203..0x042D`. The composed routine-25 run has 69 rows,
  including 54 externally labeled body rows, zero omitted character-stream
  presentation spans, and 36 omitted typed-record dispatches. It returns at
  `LIBLARY.LIB:0x2018` and changes only
  sandbox `global_u8[3000]` from `0` to `4`.
  Before that next call, the resumed main-script command at
  `EVENTD08.MES:0x0A5F` writes `banked_u16[0][1] = 7`, so Event Player reports
  the routine-27-local `1 -> 2` separately from the composed `1 -> 7` result.
  After the explicit composition, the resumed main script reaches routine `21`
  at `EVENTD08.MES:0x0AA0` (resume `0x0AA5`). Its 13-row bounded run omits all
  eleven presentation spans and returns without a local diff. The apparent
  `LIBLARY.LIB:0x0405` text row is the native pair `8F 01`, which is not valid
  CP932 and is therefore retained as presentation evidence rather than shown
  as dialogue. The caller restores `global_u8[3000]` from `4` to `0` and reaches
  routine `32` at `0x0AC7` (resume `0x0ACC`). Routine 32 executes 11 rows,
  including one nested routine-31 call and four omitted presentation spans,
  without another sandbox diff. The caller then reaches routine `28` at
  `0x0AD7` (resume `0x0ADC`); its eight-row, one-omission path returns and the
  main EVENTD08 callee returns at `0x0AE6` (since Core 0.377.0, TD-56, routine
  28 reads the route's `global_i32[1]=1` selector and runs its 21-row selector-1
  arm, [Format and Method](format_and_method.md)). These identical completion paths
  were reproduced for choices 1, 2, and 3 against the unchanged authoritative
  archive. Evidence type: hash-bound EVENTD08 route
  validator, indexed original `LIBLARY.LIB`, bounded library call runner, and
  executable-confirmed native span/call mechanics; confidence: **Confirmed**
  through the explicit DEF26 composition and main-script return,
  **Tool analysis policy** for omitted native presentation and typed-record
  dispatch effects, **Confirmed** for
  the registration map's owning-manager lifetime, and **Unresolved** for
  whether the isolated preview replayed or inherited the confirmed original
  startup registration,
  native rendering, and the original caller after that return.
- Event Player now offers a separate, explicit caller-follow-up Continue only
  after that exact hash-bound `EVENTD08.MES:0x0AE6` return and a confirmed
  one-based choice. It rechecks authoritative `12C.MES` SHA-256
  `c71563238cd4e14a06125b8cd139f7e6a304024dbd7c32ed5a3619ca425726eb`
  and `D_PIC.MES` SHA-256
  `72473432ce3dd6e0fc1e994a737dbecd5494eaf4477efc24368d3b3160d7fecd`.
  The audited caller dispatch at `12C.MES:0x0FA6` returns at `0x0FB6`, resets
  `global_u8[226]` at `0x0FC0`, and reaches the `D_PIC.MES` restore dispatch at
  `0x0FCB`; the tool omits that nested native body, applies only its separately
  confirmed `D.MMO` presentation for selector zero, and resumes caller bytecode
  at `0x0FD8`. Choices 1, 2, and 3 then reach their first caller-owned original
  dialogue rows at `0x102A`, `0x12CC`, and `0x147D`, respectively. Evidence
  type: direct authoritative `12C.MES` disassembly, hash-bound Event Player
  integration across all three choices, and original-executable MES audit v38
  confirming command `0x0F` routes through manager slot `+0x38` to
  `0x004192A0`. Confidence: **Confirmed** for the caller envelopes, selector
  reset, branch-specific first dialogue coordinates, and native save/call/
  restore role; **Tool analysis policy** for substituting the audited `D.MMO`
  preview while omitting all other `D_PIC.MES` effects; **Unresolved** for a
  general cross-script interpreter and the caller above `12C.MES`.
- The caller preview now keeps background and standing resources in separate
  layers. It selects `12C_3.MMO`, `12C_1.MMO`, `12C_2.MMO`, and `12C_3.MMO`
  for sandbox HHMM ranges before `0600`, `0600..1559`, `1600..1759`, and
  `1800` onward, respectively, using the directly observed `TIME_C.MES`
  bands, then renders the confirmed selector-zero `D.MMO` as a green-keyed
  foreground. A direct strict decode of the authoritative `mmo.arc` entry
  finds a `640x400` RGB image, exact `#00FF00` in all four corners, and 186,408
  exact-green pixels out of 256,000. The original-executable MES audit v38 was
  rerun against the configured original executable and reconfirmed command
  `0x09` at wrapper `0x00418246`, manager slot `+0x14`, handler `0x00418C60`;
  that route does not establish the native compositor. Evidence type: direct
  authoritative `TIME_C.MES`/`mmo.arc` reads, hash-bound three-route Event
  Player validation, and original-executable handler audit. Confidence:
  **Confirmed** for time bands, source pixels, layer roles, and selected
  resources; **Tool analysis policy** for the shared soft green-key shader;
  **Unresolved** for the original engine's key tolerance and draw compositor.
- Continuing those caller-owned dialogue boundaries to completion requires
  8, 6, and 14 additional Continue actions for choices 1, 2, and 3. The exact
  resume sequences are respectively `0x1051, 0x10AA, 0x113E, 0x117B, 0x11EF,
  0x125E, 0x1984, 0x19D7`; `0x12F9, 0x133C, 0x13BA, 0x1423, 0x1984,
  0x19D7`; and `0x1496, 0x14D3, 0x1543, 0x1586, 0x15EE, 0x1645, 0x16CD,
  0x1722, 0x17A4, 0x17E1, 0x185D, 0x18C6, 0x1984, 0x19D7`. All three
  then execute the confirmed completion write `global_u8[756] = 1` at
  `0x19E9` and stop at the exact command-`0x0E` `MACHI.MES` handoff marker at
  `0x1A18`. Event Player marks that boundary complete only when the original
  `12C.MES` hash, EVENTD08 caller session, target, offset, and completion flag
  all match; it does not execute the unresolved native host consumer or claim a
  later script return. Evidence type: three-route headless Event Player
  UI-controller integration against unchanged authoritative `mes.arc` and
  `mmo.arc`, plus configured-original executable command-`0x0E` handler audit;
  confidence: **Confirmed** for the explicit sandbox projection and active-
  string handoff boundary, **Unresolved** for its host consumer.
- Event Player binds this composition to the versioned common caller frame
  `kakyu_event_player_caller_frame/v1` before starting EVENTD08. The frame names
  the authoritative `12C.MES` caller and `EVENTD08.MES` callee, dispatch
  `0x0FA6`, physical caller resume `0x0FB6`, callee coordinate zero, and the
  temporary argument/evaluator context. On the exact callee return `0x0AE6`,
  the source-bound restore-follow-up adapter verifies `D_PIC.MES` at `0x0FCB`,
  resumes the caller-owned path at `0x0FD8`, and retains the frame through the
  final `MACHI.MES` handoff. A changed frame, physical resume, caller/callee
  hash, or D_PIC source fails closed before presentation or caller execution.
  Evidence type: authoritative `mes.arc` read and three-choice headless Event
  Player integration; confidence: **Confirmed** for tool frame continuity and
  fail-closed identity binding, with native D_PIC composition still governed by
  the tool analysis policy above.
- **Catalog restore-followup projection, 2026-09-06.** Core `0.293.0` /
  catalog v7 revision 22 derives this caller specification from source and
  terminal bindings, including the newly explicit `EVENTD08.MES:0x0AE6` return
  and required `D_PIC.MES` hash. The exact 34-byte caller prefix
  `12C.MES:[0x0FB6,0x0FD8)` has SHA-256
  `2062f25a097c71b33cd8050b7c1f9c699cfec2e00a06c95c5ad554b53832911c`.
  It includes the reset at `0x0FC0..0x0FC6` and the restore call at
  `0x0FCB..0x0FD8`. Both calls, the `0x0FD8` followup start and the handoff at
  `0x1A18..0x1A25` must match their structural records. A fresh default-state
  replay executes five indexed records from `0x0FB6` and stops at the restore
  dispatch; every trace source/end/command is checked to reject payload entry.
  Evidence: current Python Phase 1-4 IR over the hash-bound authoritative
  entries and shared headless prefix replay; confidence: **Confirmed** for
  these stored boundaries and prefix bytes. This proof does not execute
  D_PIC's body, traverse the complete followup or execute the host. Those
  presentation policies and the existing three-choice integration remain
  distinct, as above.
- Twenty filename-bearing voice markers reference nineteen unique voice
  resources. This document records the count only; it does not promote the
  markers to a confirmed native playback opcode.
- `12C.MES` writes completion flag `global_u8[756] = 1` at offset `6633`
  (`0x19E9`) after the EVENTD08 path; the complete caller projection above
  reaches this write and the following `MACHI.MES` marker at `0x1A18` for all
  three choices.

Confirmed internal dispatch:

- HHMM presentation bands test `< 0600`, `< 0900`, `< 1600`, and `< 1800` at
  offsets `816`, `839`, `862`, and `885`;
- `state_u16[8] == 0`, `1`, or `2` at `940`, `995`, and `1050` selects
  unresolved presentation paths;
- choice result `state_u16[21] == 1`, `2`, or `3` dispatches the three branches
  at `1855`, `2045`, and `2371`;
- `global_u8[4000] == 1` at `1169` and `global_u8[2847] == 1` at `2667` remain
  unresolved internal flags.

The apparent branches immediately following the two unresolved flag checks are
invalid empty-stack expressions in the current decoder and are not projected
as gameplay conditions.

## Scene Transition Contract

- Event-local presentation may select a BGM ID and background.
- EVENTD08 can restore a caller presentation before follow-up dialogue.
- Choice-specific effects remain pending until the complete follow-up finishes.
- Event Player choice projection is sandbox-only and does not write a gameplay
  save or claim the original routine-`40` key-reading implementation.
- Shared routine continuations use bounded original library paths and omit
  native presentation effects explicitly; they are not synthesized gameplay
  transitions. The game frame and desktop Continue button invoke the same
  sandbox-only action.
- Returning to the map selects the town-map music and restores the authored
  approach position.

Related runtime data:

- `data/events/eventd03_map_event.json`
- `data/events/eventd08_map_event.json`
- `data/mes_conditions/eventd03_caller_condition.json`
- `data/mes_conditions/eventd08_caller_condition.json`
