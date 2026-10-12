# EVENTB03 result-2 state12 branches

This note extends [the ordinary choice routes](eventb03_choice_routes.md) with
a bounded source audit of the numeric `state_u16[12] > 99` branch. It does not
assign a confirmed original user-facing meaning to slot 12 and does not
promote all audited inputs to ordinary Event Player support. The user's
reported choice meaning now supports the B03 money-check hypothesis below;
this note does not supersede the existing dating analysis of monetary units.

## Sources and execution boundary

The authoritative `ELFIMAGE/mes.arc` and original executable were reread
without modification. Source paths are supplied locally at invocation.

| Source | SHA-256 |
| --- | --- |
| `mes.arc` | `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6` |
| `EVENTB03.MES` | `558532a9b034522db857d009132b6a89aa488e577277857cc90ce337c95ee230` |
| `LIBLARY.LIB` | `d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d` |
| `B_PIC.MES` | `d72612395e8571848a7782ff48d8c63604a09a983ae2c564f2ee5bd5ac2b4ada` |
| `DEF_MAIN.MES` | `f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0` |
| Original executable | `3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5` |
| Embedded runtime at executable file offset `0x1B000` | `5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da` |

Content Core `0.275.0`, instruction schema `ai5_mes_instruction/v45`, is the
MES boundary authority. The standalone audit reads the ARC directly through
the GDScript container/decoder and uses its event, library, startup-DEF and
routine-40 contract implementations. It does not instantiate Event Player,
invoke a native effect, play audio, or run the original game. Executable audit
v317 and direct native instruction inspection provide the arithmetic evidence
below, not an alternative Python interpretation of MES boundaries.

The anchor remains `01M.MES:0x788F..0x789F`, command `0x0E` activating
`EVENTB03.MES` at code-relative zero. Each case starts in a fresh sandbox with
`state_u16[4]=6`, `[7]=413`, `[19]=1825`, bank-0 `banked_u16[210]=0`, and one
of the six slot-12 values below. The same 28 prefix dialogue boundaries lead
to the three-definition routine-40 call at `0x12D2..0x12D7`. Only result 2 is
selected, through the current source-qualified consumer, and execution stops
at its `MACHI.MES` root replacement, not the later common script return.

## Exact numeric writes and restoration

The result-2 guard is `0x1BD2..0x1BDC`, `state_u16[21] == 2`. Its local
threshold guard at `0x1C90..0x1C9A` is `state_u16[12] > 99`, with false target
`0x1E2D`.

| Selected path | Exact original write |
| --- | --- |
| True | `0x1CF5..0x1CFF`: bank-0 `banked_u16[251] = state_u16[12]` |
| True | `0x1D04..0x1D0C`: `state_u16[12] = state_u16[12] - 100` |
| False | `0x1F49..0x1F53`: bank-0 `banked_u16[251] = state_u16[12]` |
| False | `0x1F58..0x1F5D`: `state_u16[12] = 0` |
| Both | `0x239D..0x23A6`: `state_u16[12] = banked_u16[0][251]` |

The shared restoration envelope has SHA-256
`9f02426ea66178a7f6681a748cd2940a32a43790c595d79db12b5006bc219f4a`.
The temporary value is visible at the following dialogue boundary (`0x1D54`
on the true path, `0x1FB5` on the false path), at the B_PIC caller, and at
`0x2382` immediately before restoration. By `0x2403`, the original slot-12
value has been restored. No later write changes
either slot 12 or bank-0 slot 251 before the terminal.

| Initial `[12]` | `>99` | Temporary `[12]` | Restored/final `[12]` | Final bank-0 `[251]` | Suffix dialogues |
| ---: | --- | ---: | ---: | ---: | ---: |
| 0 | false | 0 | 0 | 0 | 20 |
| 1 | false | 0 | 1 | 1 | 20 |
| 99 | false | 0 | 99 | 99 | 20 |
| 100 | true | 0 | 100 | 100 | 18 |
| 101 | true | 1 | 101 | 101 | 18 |
| 65535 | true | 65435 | 65535 | 65535 | 18 |

The zero case still executes all three assignment records although its
snapshot differences are empty. A regression must check source record order
as well as final state; otherwise it cannot distinguish the temporary writes
and restoration from doing nothing.

## Dialogue and shared presentation paths

The false-path 20 dialogue offsets are:

```text
1C1E 1C7A 1E6B 1EE1 1F2E 1FB5 200F 206D 21B3 2212
22B5 2308 2382 2403 2475 24B4 253A 2589 2666 26C3
```

The true-path 18 dialogue offsets are:

```text
1C1E 1C7A 1CDA 1D54 1DAE 1E12 21B3 2212 22B5
2308 2382 2403 2475 24B4 253A 2589 2666 26C3
```

All six inputs have the same nine root shared-library boundaries:
`0x20C5 -> 28`, `0x20FA -> 27`, `0x2106 -> 25`, `0x2140 -> 21`,
`0x2167 -> 32`, `0x2177 -> 28`, `0x25BF -> 27`, `0x25CB -> 25`, and
`0x2605 -> 21`. Routine 27 receives argument 1 = 11. Existing routine 25
executes the qualified registered DEF 26 and omits 33 native records per
invocation under its existing bounded policy. There is no new root-level DEF
invocation, native character stream, routine-9 SE request, or camera sequence.

The four existing root AX omissions also remain unchanged: selector 6 at
`0x20DF..0x20E6` and `0x25A4..0x25AB`, followed by selector 8 at
`0x20E6..0x20ED` and `0x25AB..0x25B2`.

The affection guard at `0x2083` takes its zeroing path at
`0x20AC..0x20B5`, leaving initial affection zero. The B_PIC dispatch at
`0x2238..0x2245` retains result 2, affection zero and `global_u8[206]=1`.
Every case reaches its shared routine 22 at `B_PIC.MES:0x035B..0x0360`, then
returns at `0x0759`. The normalized combined trace SHA-256 is unchanged:
`8d7771311ed65536362f71d2c758a97e219c217dfbd149fe272f04ab6fe86518`.
It retains `MAHOKO.WAV`, `B1.MMO`, `BAN.MMO`, `B.AX`, and face cell `(0,1)`;
the only nested net state change is `global_u8[3005]: 0 -> 1`.

There are no branch-local media additions. The shared suffix voice markers
remain `B0811.OGG` at `0x225C`, `B0812.OGG` at `0x232B`, `B0813.OGG` at
`0x2426`, and `B0814.OGG` at `0x24D7`. Routine 23 at `0x262E` selects the
existing selector-133 `KSE0069.WAV` cue; it is not a routine-9 SE occurrence.

All six cases end at `EVENTB03.MES:0x26F4..0x2701 -> MACHI.MES`, envelope
SHA-256 `496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047`.
The final result is `[21]=2`, bank-0 affection remains zero,
`global_u8[627]=2`, and `[286]=1`. Slot 12 is restored; bank-0 slot 251 retains
the initial slot-12 value. This is a root replacement, not a caller return.

## H-B03-MONEY-01: money in 100-yen units (hypothesis)

**Evidence type: user report, 2026-09-03; supporting ARC/EXE numeric evidence.**
The user identifies visible choice 2 as giving 10,000 yen and reports that
the internal value 100 corresponds to 10,000 yen. This is recorded as the
user's gameplay knowledge, not as a newly captured HUD/memory measurement
or a confirmed symbolic state name.

The proposed interpretation is that `state_u16[12]` represents the player's
available money in units of 100 yen (`displayed yen = raw value * 100`). Under
that hypothesis, the confirmed `EVENTB03.MES:0x1C90..0x1C9A` comparison
`[12] > 99` checks whether at least 10,000 yen is available, and the confirmed
`0x1D04..0x1D0C` subtraction of 100 is the corresponding temporary payment.
The agreement between the reported choice amount, numeric threshold and
subtraction supports this hypothesis; it does not by itself prove the field's
meaning or display conversion throughout the game.

Related existing documentation provides supporting context: [Date Scene](date_scene.md)
describes the `D_DATE2.MES:0xC916..0xCA79` cost calculation in 100-yen units
and `D_DATE3.MES:0x62DD`'s `[12] >= 150` guard as a 15,000-yen requirement.
These previously recorded interpretations agree with the user's report. This
documentation update does not re-audit those date paths or extend their
confidence to the purpose of B03's temporary subtraction/restoration.

The confirmed restoration at `0x239D..0x23A6` must remain part of the account:
the audited route restores the initial numeric value from bank-0 slot 251.
Consequently this event must not be documented as permanently spending
10,000 yen. Whether the story depicts a return of the money, and the
scene-level reason for restoration, are not confirmed by the user's present
report or the numeric audit. Slot 251 is confirmed here
only as the saved value used by this branch, not as a universally named money
field.

**Confidence: hypothesis for this B03 money-check interpretation, supported by
user observation, existing date documentation and matching numeric operations;
not a new Confirmed rule.** Confirmation would require a source-bound link
from slot 12 to the original money display/conversion, plus original-runtime
before/after balance observations for this choice and its later restoration.
The numeric IR, preset label, supported routes and execution behavior remain
unchanged. This hypothesis report itself did not constitute MV-09 acceptance;
the user's later choice-2 playback confirmation is recorded separately below.

## Native arithmetic evidence and numerical bounds

The original interpreter reads token `0x80` through `0x40600E..0x406040`.
`MOVZX` at `0x406026` reads a word at the state base plus `0x2084 + index*2`,
so slot 12 enters expression evaluation as a value from 0 through 65535.
Token `0xEC` reaches `0x406349..0x406371`: the right operand is popped into
EBX and the left into EAX; `CMP EBX,EAX` at `0x406359`, `SBB EAX,EAX` at
`0x40635B`, then `NEG EAX` at `0x40635D` implement unsigned left-greater-than
as exactly 0 or 1. Command `0x0B` checks for exactly 1 at `0x4190F5`.

Token `0xE1` reaches the subtraction at `0x406201`. Command `0x04` stores
only AX at `0x418B5E`, with the state-word base established at `0x418B3F`.
Command `0x07` loads the bank-0 pointer at `0x418F8E`, computes the index-times-2
destination at `0x418FB7`, and stores AX at `0x418FBF`. The precise native
description is therefore **u16 read, unsigned 32-bit comparison/subtraction,
then low-16-bit storage**.

The threshold partitions valid u16 input into `0..99` and `100..65535`.
The guarded subtraction only produces `0..65435`, so no underflow or overflow
occurs in this branch. Current GDScript general subtraction does not reproduce
every native 32-bit wrapping case; this audit confirms parity for the bounded
nonnegative operation here, not all interpreter arithmetic. The numeric
partition does not itself prove all host/presentation contexts safe.

## Reproduction and product scope

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_eventb03_state12.gd -- `
  <ELFIMAGE-directory>
py tools/audit_ai5_mes_exe.py <configured-original-executable> --json
```

The standalone audit passes 139 checks. It verifies the original source
identities and host envelope, builds the startup registry and choice consumer,
executes every case from zero in a separate sandbox, checks exact assignment
offsets and intermediate values, validates both dialogue lists, library order,
shared B_PIC trace/media, and terminal state, then checks all six source archive
hashes again. Output is metadata-only and any failed check exits nonzero.
The executable audit separately passes v317. Neither command requires a GUI
or a run of the original game.

The initial product extension was an explicit initial-`[12]=100` representative
preset with the other captured date/time and fresh-state conditions unchanged,
and only choice 2 enabled at that stage. Its integration regression observes
temporary zero at `0x1D54` and B_PIC entry, restoration to 100 by
`0x2403`, final `[12]=100` and bank-0 `[251]=100`, and the exact 18-dialogue
path. Values 1, 99, 101 and 65535 remain source-audit cases, not automatically
supported UI presets. Existing zero-preset choice acceptance is separate.
The later [affection audit](eventb03_affection_routes.md) adds only two
separately bound initial-100/result-2 representatives with bank-0 `[210]=36`
or 76. It does not broaden this numeric six-value audit into universal support.
The subsequent [existing-preset choice audit](eventb03_preset_choice_routes.md)
independently qualifies results 1/3 for those same three exact initial-100
profiles. It supersedes the initial row restriction, not the numeric/host
confidence boundary of this audit.

Event Player implements that representative as `source-state12-100` beside
the unchanged default `captured-result3-original`. The catalog Preset selector
issues an explicit ID-bound request. Root preflight checks both the canonical
catalog request and the exact private profile before reading/replacing the
active source. At the choice, the profile, allowed results and complete state
snapshot are checked again. Results 1/3 were initially visible but labeled
unqualified; revision 15 now binds them to the separately audited per-result
contracts instead of reusing baseline permission. A failed B03
activation remains read-only rather than becoming a generic routine-40
result bridge. This is an integration guard, not a newly discovered native rule.

The initial `validate_event_player_eventb03_choices.gd` regression exercised
baseline results 1/2 and the representative result 2 through genuine UI-selected requests, full prefix
execution and each exact terminal. It checks station composite pixels,
independent effect/BGM and voice identities, temporary/restored values and
per-preset restrictions. Only after the positive representative completes does
it run separate negative source-block fixtures for changed state or request
at choice activation; these fixtures never supply the positive route's
continuation context. Synthetic UI tests cover selection reset, missing/stale
IDs, no live mutation and 640x400 logical coordinates at widescreen sizes.
The grouped user-controlled acceptance check is tracked separately as MV-09.
On 2026-09-03, after main `84580f64` integration, the user confirmed choice-2
playback of the explicit initial-100 representative. This is scoped Event
Player route acceptance, not a capture of original-engine behavior. Remaining
preset switching/reset and session-isolation checks stay in MV-09;
they are not inferred from the route confirmation. The old unqualified-row
check is superseded, not accepted; newly enabled result-1/3 presentation is
tracked in MV-11.
That increment's focused live validator passed 417 checks; Event Player
synthetic tests passed 746, Event Catalog 65, and the validation-batch Python
tests 7. The existing result-3 camera/SE/station integration and project parse
also passed. These historical automated counts do not close MV-09.

Confidence is confirmed for the six source replays, exact writes and
restoration, shared resource/call order, and cited native arithmetic. The
application of the money interpretation and unit scale to this B03 branch is
retained as hypothesis H-B03-MONEY-01, distinct from the prior dating notes.
Other affection/date/host states,
native glyph/effect cadence, physical audio output, and GUI behavior beyond
the separately reported route confirmation are not established by this source
audit.
