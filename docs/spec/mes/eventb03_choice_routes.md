# EVENTB03 ordinary choice routes

This note records the branch-local source evidence for choices 1 and 2 of
`EVENTB03.MES`. It extends the shared entry, station presentation, choice, and
result-3 evidence in [character events](character_events.md); it does not
replace the original-engine acceptance boundary described there.

## Sources and method

The authoritative input is the user-owned `ELFIMAGE/mes.arc`, read without
modification. The relevant complete-entry SHA-256 values are:

| Source | SHA-256 |
| --- | --- |
| `mes.arc` | `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6` |
| `EVENTB03.MES` | `558532a9b034522db857d009132b6a89aa488e577277857cc90ce337c95ee230` |
| `LIBLARY.LIB` | `d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d` |
| `B_PIC.MES` | `d72612395e8571848a7782ff48d8c63604a09a983ae2c564f2ee5bd5ac2b4ada` |

The investigation starts at the confirmed `01M.MES:0x788F..0x789F` host
activation and its `EVENTB03.MES` zero-coordinate target. Current GDScript
Content Core instruction v45 is the structural authority. A disposable
sandbox follows the same 28 prefix dialogue boundaries and four shared
library calls as result 3, builds the source-qualified routine-40 consumer,
then executes the selected original suffix and its nested library/MES calls.
The probe retains offsets, typed effects, resource names, state differences,
and hashes, not dialogue or original bytecode. Original archive fingerprints
are checked again after execution.

The qualified starting state remains a fresh sandbox with
`state_u16[4]=6`, `[7]=413`, and `[19]=1825`; all other ordinary slots initially
remain zero. In particular `[12]=0` and bank-0 `banked_u16[210]=0` are the
bounded starting conditions for this playback unit. The existing preset ID
`captured-result3-original` and internal projection kind `eventb03_result3`
remain compatibility identifiers, not a claim that only the third visible
choice exists. The user-facing preset label may describe the captured start.

## Shared one-based consumer and terminal meaning

The three definitions start at `EVENTB03.MES:0x1220`, `0x1255`, and `0x1284`.
Routine 40 is called at `0x12D2..0x12D7`; source-marker skipping reaches the
first result comparison at `0x12DC`. Result 1 enters the branch at `0x12EB`
after that true comparison. The false edge leads to `0x1BD2`, where result 2
is compared and enters at `0x1BE1`; the next comparison is `0x2710` for result
3. The three root-replacement envelopes are:

| Result | `MACHI.MES` envelope | Later common script return |
| --- | --- | --- |
| 1 | `0x1BB6..0x1BC3` | `0x3D5D` |
| 2 | `0x26F4..0x2701` | `0x3D5D` |
| 3 | `0x3D46..0x3D53` | `0x3D5D` |

All three envelopes have SHA-256
`496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047`.
Execution stops at the selected root replacement. It must not continue into
the common return or restore the prior EVENTB03 caller after replacing the
root script with `MACHI.MES`.

The original executable was reread through executable audit v317. Its SHA-256
is `3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5`;
the embedded runtime begins at file offset `0x1B000` and has SHA-256
`5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da`.
Native selected-row conversion adds one at `0x401CBA`, stores the control
result at `0x401CF7`, and copies the modal result at `0x43532E`. Command 12's
store at `0x414DC5` writes `state_u16[18]`, not `[21]` directly. The original
`LIBLARY.LIB:0x1CA0..0x1CA6` then copies `[18]` into `[21]`, following the
`0x1C95..0x1CA0` primary-1/secondary-21 record. The next such record is
`0x1CC4..0x1CD0`.

Native command 0 reaches `0x4181D4`, decreases nesting at `0x4181DA`, returns
zero at `0x4181EC`, and returns at `0x4181EF`. Command `0x0E` instead follows
`0x4182EE -> 0x419210`, calls the receiver at `0x41926E`, notifies at
`0x419286`, and sets flag 8 at `0x419295`. The existing same-owner original
result-3 capture supplies the host installation chain that distinguishes root
replacement from a nested return. These native facts support the shared
consumer/terminal interpretation; they are not a new original-engine capture
of choices 1 or 2.

## Result 1

The exact 19 post-choice dialogue boundaries are:

```text
1339 1377 13C9 1414 1476 1581 15D6 1692 1703 176D
17C4 1846 18A9 1933 1970 19FC 1A4B 1B28 1B85
```

The root shared-library boundary sequence, excluding the runner's already
typed routine-0 dialogue and routine-23 audio records, is:

| Caller offset | Routine |
| --- | --- |
| `0x1497` | 28 |
| `0x14CC` | 27, argument 1 = 11 |
| `0x14D8` | 25 |
| `0x1512` | 21 |
| `0x1539` | 32 |
| `0x1549` | 28 |
| `0x1A81` | 27, argument 1 = 11 |
| `0x1A8D` | 25 |
| `0x1AC7` | 21 |

`0x15F1..0x1600` adds 2 to bank-0 `banked_u16[210]`, producing 2 from the
qualified zero initial affection. `0x160A..0x1610` writes `global_u8[206]=1`.
The nested `B_PIC.MES` dispatch is `0x1615..0x1622`. Its qualified caller has
the three starting fields unchanged, `state_u16[21]=1`, affection 2, and
`global_u8[206]=1`.

The suffix introduces no new root-level registered DEF invocation, routine-9 SE call, camera
mode 7/8 record, command-12 presentation boundary, or native character-stream
boundary. Four already typed seven-byte AX controls remain metadata-only:
selector 6 at `0x14B1..0x14B8` and `0x1A66..0x1A6D`, followed by selector 8 at
`0x14B8..0x14BF` and `0x1A6D..0x1A74`. Existing bounded library presentation
effects are still subject to their shared omission policy.

Routine 23 at `0x1AF0..0x1AF5` requests selector 133, `KSE0069.WAV`, through
the existing independent effect cue. The branch-specific voice markers are
`B0806.OGG` at `0x1639`, `B0807.OGG` at `0x1726`, `B0808.OGG` at `0x17E7`,
`B0809.OGG` at `0x18CC`, and `B0810.OGG` at `0x1993`; they use the existing
voice resolver, not the new routine-9 SE path. The final real writes are
`global_u8[627]=1` at `0x1B9B..0x1BA1` and `[286]=1` at `0x1BAB..0x1BB1`.
The next boundary is the result-1 MACHI envelope above.

## Result 2 with state_u16[12] = 0

The exact 20 post-choice dialogue boundaries of the qualified branch are:

```text
1C1E 1C7A 1E6B 1EE1 1F2E 1FB5 200F 206D 21B3 2212
22B5 2308 2382 2403 2475 24B4 253A 2589 2666 26C3
```

Its nine root shared-library boundaries are `0x20C5 -> 28`,
`0x20FA -> 27` with argument 1 = 11, `0x2106 -> 25`, `0x2140 -> 21`,
`0x2167 -> 32`, `0x2177 -> 28`, `0x25BF -> 27` with argument 1 = 11,
`0x25CB -> 25`, and `0x2605 -> 21`. There is no new root-level registered DEF,
routine-9 SE, native character-stream boundary, or camera sequence on this
qualified path. Routine 23 at `0x262E` requests the existing selector-133
`KSE0069.WAV` cue. Its branch-specific voice resources are `B0811.OGG`
through `B0814.OGG`, handled by the existing voice resolver.

Both choices reuse the already qualified registered DEF 26 inside shared
routine 25 and its bounded native-record omission policy. Absence of a new
root-level DEF call does not mean that the nested library route contains no
DEF execution or omitted presentation records.

The affection guard at `0x2083` tests bank-0 `banked_u16[210] > 5` and
`!= 0`. Its true write at `0x2098..0x20A7` subtracts 5; its false write at
`0x20AC..0x20B5` sets the field to zero. The qualified zero initial value
therefore remains zero. The nested `B_PIC.MES` call at `0x2238..0x2245`
has `state_u16[21]=2`, affection 0, and `global_u8[206]=1`. It returns to the
same root suffix, which ends at `0x26F4..0x2701`.

The complete branch interval `0x1BDC..0x2710` has SHA-256
`3164748472378ca3094c107e7d97eb259c13f0221261fd9f29aeefd46065b91b`.
The exact B_PIC call envelope has SHA-256
`f2af895ae4d8c000b0bf6bb97a6bc0766adc33950316773bb81828d3d3f569da`.

The separate guard at `0x1C90..0x1C9A` tests the numeric condition
`state_u16[12] > 99`; its false target is `0x1E2D`. The true branch copies
the current value into bank-0 `banked_u16[251]` at `0x1CF5..0x1CFF` and
subtracts 100 from `[12]` at `0x1D04..0x1D0C`. In the false branch,
`0x1F49..0x1F53` copies `[12]` into bank-0 `[251]`, then
`0x1F58..0x1F5D` sets `[12]=0`.

These numerical reads/writes are source-confirmed. The field's original
user-facing/native meaning is not inferred here. This initial audit did not
execute the `>99` path. The subsequent [state12 audit](eventb03_state12_routes.md)
follows six boundary inputs and also confirms the later restoration at
`0x239D..0x23A6`; the temporary subtraction must not be mistaken for the final
value. Product playback now additionally qualifies the explicit initial-100
preset for result 2 only. Other audited values are not automatically enabled.

## Shared B_PIC presentation

For result 1's affection 2 and result 2's affection 0, both nested replays
reach routine 22 at `B_PIC.MES:0x035B..0x0360` and return at `0x0759`.
Their combined traces use the same normalization as Event Player's existing
result-3 picture probe and have exactly the same SHA-256:
`8d7771311ed65536362f71d2c758a97e219c217dfbd149fe272f04ab6fe86518`.

It selects `MAHOKO.WAV` at `0x00A0`, `B1.MMO` at `0x02E5`, `BAN.MMO` at
`0x05B6`, and `B.AX` at `0x05C9`. The binding at `0x05F2..0x0604` is row 0,
column 1, followed by the complete selector-1 envelope at `0x0604..0x0611`.
The only final nested sandbox difference is `global_u8[3005]: 0 -> 1`;
there is no payload-shadow write to `[769]`. Both ordinary choices therefore
reuse the existing qualified low-affection standing presentation, not a new
media set.

## Reproduction

Use the current standalone original-source validator and executable audit:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventb03_choices.gd -- `
  <ELFIMAGE-directory>
py tools/audit_ai5_mes_exe.py <configured-original-executable> --json
```

The choice validator covers the branch-local dialogue sequence, B_PIC return,
shared media, and terminal in a headless live Event Player session. The EXE
audit checks native byte anchors independently; it does not synthesize an
original-engine interactive run. Source roots are supplied at invocation and
are never part of the tracked artifact.

The live snapshot at `EVENTB03.MES:0x12D2` has `global_u8[626]=1` after the prefix;
it is not a zero starting-field requirement at the choice boundary. The
source-qualified baseline choice check retains that value, the exact date/time
fields, zero `[12]` and affection, and zero globals 206/627/2847/3005/3006/4000.
Confirmation also binds the complete snapshot, rejecting any pending-state
change before writing the chosen result. The initial focused validator passed 272
checks, including the 19/20 suffix lists, distinct terminal/state assertions,
station composite pixels, branch voice resources, independent KSE0069/BGM,
and rejection of a forged cross-branch B_PIC continuation. Six source archive
hashes remain unchanged. This is tool integration evidence, not physical audio
or original-engine visual acceptance.

The numeric representative also binds the explicit preset ID, exact
catalog writes and allowed result list to that snapshot. Its initial result-2-only
profile could not inherit the baseline's result-1/3 permissions. The later
[existing-preset audit](eventb03_preset_choice_routes.md) independently qualifies
results 1/3 for the three exact initial-100 profiles with per-result state and
picture contracts, without enabling arbitrary initial values. The extended
integration validator and UI acceptance boundary are documented in the
state12 note; this does not change the already accepted baseline.

## Scope and remaining confidence boundary

The result-1 baseline, the same baseline with initial `[8]=3`, an empty
sandbox, and one-field deletions of `[4]`, `[7]`, or `[19]` were followed to
the same outer dialogue/call coordinates and MACHI envelope. Only the baseline
and overwritten-`[8]` case retained the same complete internal trace. Deleting
the other fields changes library or nested presentation paths even when the
terminal is unchanged. This supports keeping the three-field qualified
starting preset; it does not establish universal minimal state or authorize
arbitrary affection, date, or surrounding-host values.

The smallest integration is a branch-local caller/terminal contract with the
shared choice consumer, B_PIC renderer, station restoration, and MACHI preset.
Do not loosen the result-3-only checks without replacing them with exact
per-result coordinates and caller-state requirements. The historical
`_eventb03_start_readiness` failure at result 1 was its explicit `0x37B9`
picture-dispatch allowlist, not a new low-level decoder failure.

Confidence is **Confirmed** for the current GDScript boundaries, qualified
result-1 and `[12]=0` result-2 replays, unchanged source hashes, native result
storage chain, and shared picture trace. Original native glyph pixels,
cadence and physical output cannot be established by this headless
investigation. Following integration in `main` commit `55c7ed19`, the user
separately accepted choices 1/2 dialogue, voice/effect output, standing/station
presentation and map completion (MV-08). This is Event Player acceptance of
the qualified fresh preset, not a new original-engine capture or qualification
of other initial values. The earlier result-3 first-blackout sound acceptance
remains an independent check.
