# EVENTB03 face-flag routes (audit only)

This note extends the [affection audit](eventb03_affection_routes.md) and
[existing-preset choice audit](eventb03_preset_choice_routes.md) with explicit
`global_u8[204]`, `[207]`, and `[628]` inputs. Their numerical effect on the
original face guard is confirmed under the stated sandbox conditions. Their
gameplay names, setters, meaning in saved games and event eligibility remain
unconfirmed. **No new Event Player starting states are enabled.**

## Source and execution boundary

The machine-local source configuration was reread, and the authoritative
`ELFIMAGE` archives and original executable were checked directly, read-only.
No generated Python MES projection substitutes for the current GDScript
Content Core `0.275.0` / instruction schema `ai5_mes_instruction/v45`.

Source SHA-256 identities remain:

| Source | SHA-256 |
| --- | --- |
| `mes.arc` | `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6` |
| `EVENTB03.MES` | `558532a9b034522db857d009132b6a89aa488e577277857cc90ce337c95ee230` |
| `B_PIC.MES` | `d72612395e8571848a7782ff48d8c63604a09a983ae2c564f2ee5bd5ac2b4ada` |
| `LIBLARY.LIB` | `d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d` |
| `DEF_MAIN.MES` | `f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0` |

`audit_eventb03_face_flags.gd` inherits the already source-bound zero-entry
walker and exact DEF/native omission allowlists without changing them.
It checks `01M.MES:0x788F..0x789F -> EVENTB03.MES`, starts that target at
code offset zero, follows the prefix and the routine-40 choice at
`0x12D2..0x12D7`, then follows the selected suffix, nested B_PIC and MACHI
replacement. It does not inject flags only after reaching the picture script.

Each sandbox sets `state_u16[4]=6`, `[7]=413`, `[12]=100`, `[19]=1825`,
the selected bank-0 `[210]` value, and the three explicit flags. Other ordinary
slots start at zero. The raw input values 2/255 are retained as such; they are
not coerced to one. This does not claim that ordinary original-game setters
produce those noncanonical values.

The original executable passed audit `kakyu_ai5_mes_exe_audit/v317` again:
input SHA-256
`3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5`,
embedded offset `0x1B000`, runtime SHA-256
`5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da`.
The previously documented native comparison, word-store and terminal rules
are reused. This is not a new original-engine capture or a general audit of
arbitrary logical-operator operands.

## Exact guard and precedence

`B_PIC.MES:0x0568..0x0597` tests the following expression, where `A` is the
post-choice bank-0 `banked_u16[210]` value:

```text
(A < 31)
or (global[204] == 1)
or ((global[207] == 1) and (A < 81))
or ((global[628] == 1) and (A < 71))
```

The whole guard envelope SHA-256 is
`99225c4ef202a59916b295d2ae7016c0a6576d7723a2f7147981ef9a420206cd`.
False branches to `0x0626`; true takes the low-face block. The auditor
compares the decoded AST's ordered OR terms, each AND subtree, storage/bank/
index, exact equality-to-one constants, comparison operators and thresholds.
It does not flatten AND into OR or replace `==1` with a nonzero test.

Every AND/OR child here is a comparison or a logical combination of comparison
results, so its input is normalized to 0/1 before logical combination. The
evidence is confined to that boolean-normalized AST. The subsequent
[Core 0.276.0 logical truth correction](format_and_method.md#logical-expressions-use-exact-one-truth-core-02760)
separately closes the discovered E6/E7 nonboolean-operand mismatch. Its native
proof is not inferred from this face matrix.
In particular, an injected raw flag of 255 is first compared with 1 rather
than consumed directly as an AND/OR operand.

If the low guard is false, `0x0626..0x0633` tests `A < 71` (false target
`0x06C2`), then `0x06C2..0x06CF` tests `A > 70` (false target `0x0759`).
Their existing hashes are respectively
`6cf3462a3011c23d41a8c08876ef414a24b18a2afcc9321d65cbef76dcb9275d`
and `07b3b36a44729cd3569d0c6c408fb4718f2fad933ac8815f154a9806a34398d1`.
Each replay also checks the exact reached guard offsets, numeric condition
values and branch/fallthrough effects, not just the eventual face.

## Discriminating matrix and observations

There are **72 complete zero-entry routes**, 24 per visible choice:

- Initial `[210]=76`, all eight 0/1 combinations of the three flags, for
  choices 1/2/3: 24 cases. Post-choice affection is 78/71/79 respectively.
- Post-choice `A=70,71,80,81`, pairing zero flags with the relevant 628 or
  207 override for every choice: 22 additional unique cases.
- Each flag individually set to 2 or 255 at initial `[210]=76`: 18 cases.
- Flag 628 set to 2 or 255 at post-choice `A=70`: six additional cases,
  using initial 68/75/67 for choices 1/2/3. These make an erroneous `!=0`
  interpretation observable; the high-affection cases alone would hide it.
- Result 2 at initial `[210]=86` (`A=81`) with 204 alone or all three flags
  set to one: two cases, checking the 204 override beyond the 207 threshold.

| Explicit condition; unlisted flags zero | Observed row-0 face column |
| --- | --- |
| All flags zero, `A=70` | 0 (middle) |
| All flags zero, `A=71,78,79,80,81` | 2 (high) |
| 204 = 1 at the tested high values, including 81 | 1 (low) |
| 207 = 1, `A=80` / `A=81` | 1 / 2 |
| 628 = 1, `A=70` / `A=71` | 1 / 2 |
| 204 or 207 = 2 or 255 at initial 76 | Same high face as zero flags |
| 628 = 2 or 255 at `A=70` | Same middle face as zero flags, not low |

For the initial-76 boolean matrix, 204=1 or 207=1 selects column 1;
otherwise column 2 is selected, regardless of 628. This is because all three
post-choice values lie in `[71,81)`, not because 628 is ignored generally.
All three flags remain exactly at their injected values on B_PIC entry and
at the final MACHI boundary. The complete executed write-run inventory,
including storage/bank/start/count/index-mask validation, contains **no write
touching 204, 207 or 628**. Unchanged final values are not mistaken for a
possible write-and-restore sequence.

The matrix checks each flag at the same discriminating input with values
0/1/2/255. The expected columns are `[2,1,2,2]` for flags 204 and 207 at
initial 76, and `[0,1,0,0]` for flag 628 at post-choice 70. Thus equality to
one is supported by both the exact source AST and paired full-route results.

## Whole-route comparison, picture and state

All 72 cases reached the original MACHI replacement with no new unsupported
boundary. A future unrecognized boundary fails the audit and reports its
last source coordinate and partial state difference; it is not silently
skipped or counted as complete.

For each choice, the normalized outer trace and root boundary/argument list
equal the independently run zero-flag baseline. The normalization is the
same as the preset-choice audit: it excludes B_PIC-entry rows while retaining
nested LIB rows, including the library-22 rows inside B_PIC.

| Choice | Outer rows / trace SHA-256 | B_PIC call | MACHI replacement |
| --- | --- | --- | --- |
| 1 | 893 / `a00ae5d6fd1323d0d61ab43816ada013a51913217753f35e64ab5a2b4869cd62` | `0x1615..0x1622` | `0x1BB6..0x1BC3` |
| 2 | 894 / `80f5523fbc531842395862be0b8ab9e06904607fb462245b8192df8210c34e70` | `0x2238..0x2245` | `0x26F4..0x2701` |
| 3 | 1801 / `e2de15dbe5f6809da4afdd0868c299c1d191ca0ab41964ab7baff9c070aa0dae` | `0x37B9..0x37C6` | `0x3D46..0x3D53` |

> Core 0.316.0 (2026-09-13). The outer-trace row counts and fingerprints in
> this table were taken under the separator framing of command `0x0D`. Under
> the system-call framing the same routes - every boundary, write, media row
> and picture return - reproduce with 854 / 857 / 1,732 rows for choices 1 /
> 2 / 3 and fingerprints `0156d2c6...`, `521ac84a...`, `d75bca42...`; the root
> "native streams" at `0x2A74..0x2E9D` are `System.function[12]` calls that
> the runtime omits and runs past rather than stops on, and the B_PIC picture
> trace signatures are `166f2b6c...` (column 1), `0626c326...` (column 0) and
> `b7f9d331...` (column 2). The audits carry the new figures.
>
> Core 0.377.0 (2026-10-10, TD-56). Command `0x09` writes `global_i32` and the
> shared routines read the real selector, so the outer traces are 899 / 902 /
> 1,446 rows for choices 1 / 2 / 3 with fingerprints `c7ff76ac...`,
> `ca4638b8...`, `3e626e47...`. Routine 28's selector-1 arm sets
> `global_u8[4000]`, the root skips the routine-21 call at `0x0225`, and routine 9's
> calls reach their SE rungs instead of walking the selector-0 ladder; the
> dialogue, media, picture signatures and face columns are unchanged. B_PIC's
> own change is the `global_i32[1]` cell it overwrites (46,665 / 46,691 / none
> before, `0` after) beside the unchanged `global_u8[3005]`, and each route's
> final diff gains `global_i32[1]` = 46,677 / 46,701 / 46,741.

The 28-dialogue prefix and respective 19/18/40-dialogue suffixes, shared
calls and resources, bounded DEF/native records, and result-3 camera/SE
sequence remain unchanged. The matched trace proves this for the tested
paths; it is not a whole-corpus inventory of every flag reader or writer.

The exact B_PIC face bindings and complete callee-plus-library trace hashes
remain the previously qualified ones:

| Column | Binding / activation envelope | Trace SHA-256 | Complete nested final diff |
| --- | --- | --- | --- |
| 1 | `0x05F2..0x0604` / `0x0604..0x0611` | `8d7771311ed65536362f71d2c758a97e219c217dfbd149fe272f04ab6fe86518` | global 3005: 0 -> 1 |
| 0 | `0x068E..0x06A0` / `0x06A0..0x06AD` | `05c03a5ad3d6cc1103506fdcc522b16c6374af0569f5abf74e67e697de7408c1` | Empty |
| 2 | `0x072A..0x073C` / `0x073C..0x0749` | `785567faf521981453bc41001a51a766c942cf7b96390c741b525ed3feef4eaa` | global 3005: 0 -> 2 |

The exact `MAHOKO.WAV`, `B1.MMO`, `BAN.MMO`, `B.AX` source markers and
return `0x0759..0x075A` are checked too. Compared with the explicitly
initialized sandbox, the **entire final diff** equals the already audited
per-choice numeric diff, substituting only the input-specific affection
output and selected global-3005 value. Choices 1/3 add 2/3; choice 2
subtracts 5 for these inputs, temporarily changes `[12]` to zero and restores
100 while retaining bank-0 `[251]=100`. Choices 1/3 retain `[12]=100` and
bank-0 `[251]=0`. No additional final state changes are accepted.

## Product, confidence and reproduction

This is a source-audit-only unit. The four existing product presets retain
their exact zero starting values for globals 204/207/628. Values 1, 2 and
255 remain rejected by the fresh-choice witness and B_PIC integration; the
fact that 2/255 select the same source face as zero is not permission to
loosen those contracts. There is no new preset, runtime behavior or UI
verification request. The already deferred manual verification remains
separate from this analysis.

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_eventb03_face_flags.gd -- `
  <ELFIMAGE-directory>
```

The audit passed **1,161 checks / 72 routes**. The original EXE audit v317
also passed. All six source archives (`mes`, `mmo`, `data`, `bgm`, `se`,
`voice`) retained their before/after hashes.

The Event Player suite passed **996 checks**, including 188 new negative
checks across all four presets: nonzero flag values cannot become canonical
preset writes, pass a refreshed choice witness, or enter any of the three
picture routes. Rejection preserves the input requests and sandbox state.
The validation-runner tests passed **7 checks**, the preceding preset-choice
source audit retained **260 checks**, and the project parse passed. These
are automated checks, not manual playback acceptance.

Confidence: **Confirmed** for the stated original AST/boundaries, explicit
boolean-normalized guard evaluations, full-route numerical results and trace
comparisons. Native glyph/pixel/audio cadence, general nonboolean logical
semantics, original scheduler reachability, flag naming/setters and arbitrary
saved-game compatibility are not established by this audit.
