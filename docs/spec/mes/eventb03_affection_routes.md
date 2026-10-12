# EVENTB03 result-2 affection and face routes

This note extends the [ordinary choice audit](eventb03_choice_routes.md) and
[state12 audit](eventb03_state12_routes.md) with nonzero bank-0
`banked_u16[210]` inputs. It confirms bounded source execution and the selected
face record, not original-engine capture, host eligibility, or arbitrary
saved-game compatibility.

## Sources and method

The authoritative `ELFIMAGE/mes.arc` is opened read-only. Identities remain:

| Source | SHA-256 |
| --- | --- |
| `mes.arc` | `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6` |
| `EVENTB03.MES` | `558532a9b034522db857d009132b6a89aa488e577277857cc90ce337c95ee230` |
| `B_PIC.MES` | `d72612395e8571848a7782ff48d8c63604a09a983ae2c564f2ee5bd5ac2b4ada` |
| `LIBLARY.LIB` | `d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d` |
| `DEF_MAIN.MES` | `f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0` |

`tools/content_suite/cli/audit_eventb03_affection.gd` inherits the existing
original-Core zero-entry result-2 walker, not Event Player or an older Python
projection. It checks `01M.MES:0x788F..0x789F` targeting `EVENTB03.MES`, then
starts that target at code-relative zero. Its fresh sandbox sets
`state_u16[4]=6`, `[7]=413`, `[19]=1825`, `[12]` to 0 or 100, and bank-0
`[210]` to one of `0,5,6,35,36,75,76,65535`. All other ordinary slots begin
at zero. Each of the 16 cases follows the real prefix, builds the routine-40
choice contract at `0x12D2..0x12D7`, selects result 2, follows nested original
library and B_PIC calls, and stops at the root-replacement MACHI envelope.
It does not jump directly into an affection or face block.

The configured original executable was reread through executable audit v317:
input SHA-256
`3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5`,
embedded runtime offset `0x1B000`. The already documented unsigned comparison,
subtraction, word read/store and command-0x0B rules in the state12 and choice
notes supply shared native support. This task does not claim a new
disassembly interpretation or a new original-engine run. In particular, the
meaning of unrelated global flags is not inferred from these operations.

## Result-2 affection clamp

The exact `EVENTB03.MES:0x2083..0x20B5` envelope has SHA-256
`76832232e1c731536ac40ed11f91996a0757380f0b8191a722f9b71acff06266`.
The current decoder preserves the following records:

| Code-relative interval | Confirmed operation |
| --- | --- |
| `0x2083..0x2098` | Test bank-0 `[210] > 5` **and** `[210] != 0`; false target `0x20AC` |
| `0x2098..0x20A7` | Store `[210] - 5` into bank-0 `[210]` |
| `0x20AC..0x20B5` | Store zero into bank-0 `[210]` |

For the tested word inputs this gives `max(initial - 5, 0)`. There is exactly
one `[210]` write in each complete replay, and no later affection restoration.
This differs from the independent `[12]` temporary subtraction and restoration.
The selected root still dispatches `B_PIC.MES` at `0x2238..0x2245`; after the
picture return it ends at `0x26F4..0x2701 -> MACHI.MES`.

## Fresh-flag face selection

The picture script applies affection **after** the result-2 subtraction. Its
low-face guard `B_PIC.MES:0x0568..0x0597` is not a bare affection test:

```text
affection < 31
or global[204] == 1
or (global[207] == 1 and affection < 81)
or (global[628] == 1 and affection < 71)
```

Its false target is `0x0626`. The exact envelope hash is
`99225c4ef202a59916b295d2ae7016c0a6576d7723a2f7147981ef9a420206cd`.
Under the audited zero values of these override flags, the remaining guards
are `0x0626..0x0633` (`[210] < 71`, false target `0x06C2`) and
`0x06C2..0x06CF` (`[210] > 70`, false target `0x0759`). Their hashes are
`6cf3462a3011c23d41a8c08876ef414a24b18a2afcc9321d65cbef76dcb9275d`
and `07b3b36a44729cd3569d0c6c408fb4718f2fad933ac8815f154a9806a34398d1`.
These are conditional face bands, not a promise that all nonzero-flag states
select their face using affection alone.

The later [face-flag matrix](eventb03_face_flag_routes.md) checks this complete
predicate, its equality and threshold neighbors, and nonzero-flag zero-entry
routes. That is source-only qualification; the product still requires these
three globals to be zero, including rejection of values 2 and 255 even where
their original expression result matches zero.

All tested cases load `MAHOKO.WAV` at `0x00A0` and `B1.MMO` at `0x02E5`,
reach shared routine 22 at `0x035B..0x0360` with argument 1 = 14, and return
at `0x0759..0x075A`. The row-zero face differences are:

| Initial `[210]` | Result-2 output | Face column | Binding / following selector-1 interval |
| --- | --- | --- | --- |
| 0, 5 | 0 | 1 | `0x05F2..0x0604` / `0x0604..0x0611` |
| 6, 35 | 1, 30 | 1 | Same low-face intervals |
| 36, 75 | 31, 70 | 0 | `0x068E..0x06A0` / `0x06A0..0x06AD` |
| 76, 65535 | 71, 65530 | 2 | `0x072A..0x073C` / `0x073C..0x0749` |

`BAN.MMO` / `B.AX` marker offsets are respectively `0x05B6` / `0x05C9`
for column 1, `0x0652` / `0x0665` for column 0, and `0x06EE` / `0x0701`
for column 2. These use the existing media, not three new image sets.

Combined B_PIC and nested-library trace signatures use the existing Event
Player normalization (offset, end, effect, resource, routine, row, column):

| Face | Trace SHA-256 | Complete nested final state difference |
| --- | --- | --- |
| Column 1 | `8d7771311ed65536362f71d2c758a97e219c217dfbd149fe272f04ab6fe86518` | `global_u8[3005]: 0 -> 1` |
| Column 0 | `05c03a5ad3d6cc1103506fdcc522b16c6374af0569f5abf74e67e697de7408c1` | Empty; `[3005]` remains zero |
| Column 2 | `785567faf521981453bc41001a51a766c942cf7b96390c741b525ed3feef4eaa` | `global_u8[3005]: 0 -> 2` |

An empty middle-face final diff does not mean no original commands ran. The
auditor also checks the exact trace, binding and selector-1 record. No face
payload executes as a shadow command or writes global `[769]`.

## Unchanged outer route and state

All affection cases retain the 28-dialogue prefix. Initial `[12]=0` retains
the same 20-dialogue result-2 suffix; initial `[12]=100` retains the same
18-dialogue suffix. Both retain all nine root shared calls, existing
`B0811.OGG` through `B0814.OGG`, selector-133 `KSE0069.WAV`, and the same
MACHI terminal. No root-level routine-9 effect, camera, or new registered-DEF
boundary is introduced. Existing nested shared DEF26 presentation omissions
remain explicitly bounded; this is not native-pixel/cadence completeness.

The full final diff from the explicitly initialized sandbox is checked,
including the absence of unlisted final changes:

- Bank-0 `[1]: 0 -> 7`; `[210]` changes to the clamped output when different;
  `[251]: 0 -> 100` only for the initial-100 cases.
- `global_u8[206,286,3688,5306,626,631,632]: 0 -> 1`, `[627]: 0 -> 2`.
- `global_u8[3005]` changes only as listed in the face table.
- `state_u16[21]: 0 -> 2`; `[12]` ends at its initial value.

These are numeric state facts; names or gameplay meanings for the additional
global slots are not newly assigned here.

## Product representative boundary and reproduction

The following records the initial result-2 integration. The subsequent
[existing-preset choice audit](eventb03_preset_choice_routes.md) supersedes
only its result-2-only restriction: the same two exact representatives now
also qualify results 1/3. Other audited values and arbitrary states remain
outside the product boundary; the result-2 acceptance below is not extended
to the new choices.

The initial integration selected two narrow source representatives,
`source-state12-100-affection36` and `source-state12-100-affection76`, both
for result 2 only at that stage. They added only initial bank-0 `[210]=36` or
76 to the previously qualified initial-100 state and finished with affection 31 or 71 and face
column 0 or 2. These are the nearest initial values that reach the next face
band after subtracting 5. Initial 6 tests the subtraction branch but still
selects the low face, so it adds no new face coverage. The raw upper-word
case 65535 is an arithmetic regression input, not a normal gameplay value.

The other audited inputs did not authorize product presets, other choice
results, arbitrary calendar/flag combinations, or ordinary host reachability.
The later linked audit independently qualifies results 1/3 only for the
already named representatives; it does not promote the other audited inputs.
No source capture establishes that the proposed high-affection starting
states naturally trigger B03 on the retained date. Their purpose is isolated
source-backed Event Player coverage, explicitly separate from eligibility.
Native visual/audio timing and user-facing acceptance remain separate gates.

That Event Player increment implemented only those two additional
representatives for result 2. Its starting-state profile, allowed result,
frozen choice snapshot and canonical catalog request bound the initial value;
the B_PIC adapter checked the exact post-subtraction value, marker/binding
offsets, whole trace and nested diff. The current expanded choice contracts
are recorded in the linked preset-choice note.
Face-override globals 204/207/628 and incoming 3005 must remain zero. (Since Core
0.377.0, TD-56, the audited diffs also carry `global_i32[1]`: B_PIC overwrites
46,691 with `0` and the route ends at 46,701, command `0x09` arguments the runner
now writes to the shared storage.) The
adapter runs on a disposable cloned state and publishes the snapshot only
after all source, trace, state and media checks succeed, so an unexpected
late return/trace/media failure cannot leave rejected writes in the live state.

The live regression for that increment selected all five then-supported
result-1/2 preset routes through the real catalog selector and ran each from
zero to its terminal. For the new profiles it verified the original
18-dialogue suffix, temporary/restored
state12, 31/71 affection, column 0/2, independent source face rectangles and
the composed station/standing/face pixels. Separate negative fixtures reject
neighboring values, cross-preset requests, face overrides and late probe
failure without supplying any continuation to the successful route. Preset
controls retain the existing 640x400 logical layout at 1080p/1440p. Automated
pixels are not a claim of physical audio or native timing.

On 2026-09-03, after integration in main `eb8f956c` and the catalog preset
selection instructions, the user confirmed both the initial-36 and initial-76
result-2 checks. MV-10 therefore records acceptance of their distinct standing
expressions, station-background composition and final station map/protagonist.
This is Event Player visual/flow acceptance for the two stated profiles, not
a new original-engine capture or proof of native timing/host eligibility.
MV-09's separate preset-reset and active-session-isolation controls remain
pending; those actions are not inferred from the two-preset confirmation.
The former unsupported result-1/3 rows are superseded by the revision-15
source qualification, not marked accepted; their newly enabled playback has
its own MV-11 check.

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_eventb03_affection.gd -- `
  <ELFIMAGE-directory>
```

The focused audit passed **339 checks** for the 16 cases. The final genuine
five-route Event Player integration passed **749 checks**, including
post-execution media rejection with unchanged caller snapshots. Event Player
synthetic/layout tests passed **804**, Event Catalog **69**, and validation
batch Python tests **7**. The original result-3 camera/SE/station regression,
12-event catalog source bindings, executable audit v317 and project parse
also passed. All six source
archives (`mes`, `mmo`, `data`, `bgm`, `se`, `voice`) retain their before/after
hashes. Confidence is **Confirmed** for the stated original-Core record
boundaries, guarded numerical effects and source-selected face traces under
the explicit sandbox conditions. Original native cadence, original gameplay
eligibility, and arbitrary-state compatibility remain unconfirmed.
