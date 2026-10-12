# EVENTB03 existing presets: results 1 and 3

This note extends the [ordinary choices](eventb03_choice_routes.md),
[state12 branches](eventb03_state12_routes.md), and
[result-2 affection audit](eventb03_affection_routes.md). It supersedes their
initial result-2-only product restriction for exactly the three already named
initial-100 representatives. It does not qualify arbitrary states, new host
entry conditions, or native visual/audio equivalence.

## Authoritative inputs and method

Evidence type: read-only authoritative ARC decoding and zero-entry execution
through GDScript Content Core `0.275.0`, instruction schema
`ai5_mes_instruction/v45`; independent original executable identity audit.
The input paths come only from the local source-path configuration.

The `mes.arc` SHA-256 remains
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
`EVENTB03.MES` remains
`558532a9b034522db857d009132b6a89aa488e577277857cc90ce337c95ee230`,
and `B_PIC.MES` remains
`d72612395e8571848a7782ff48d8c63604a09a983ae2c564f2ee5bd5ac2b4ada`.
The complete `LIBLARY.LIB` and `DEF_MAIN.MES` identities in the linked
affection audit are also checked before replay. All six input archives
(`mes`, `mmo`, `data`, `bgm`, `se`, `voice`) are hashed before and after.

`tools/content_suite/cli/audit_eventb03_preset_choices.gd` reuses the existing
original-Core walker, not Event Player or an older Python MES projection. It
checks `01M.MES:0x788F..0x789F -> EVENTB03.MES`, starts that target at code
offset zero, and follows the prefix before choosing result 1 or 3 at the
source-qualified routine-40 boundary `0x12D2..0x12D7`. It never jumps directly
to the affection writer or B_PIC binding.

Every sandbox starts with `state_u16[4]=6`, `[7]=413`, `[19]=1825`; all
other ordinary fields are zero except the two explicit inputs below. The
auditor independently runs a `[12]=0`, bank-0 `[210]=0` baseline for each
choice, then `[12]=100` with bank-0 `[210]=0`, 36, or 76: eight complete
routes, of which six are new preset/choice combinations.

The original executable was reread with audit
`kakyu_ai5_mes_exe_audit/v317`: input SHA-256
`3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5`,
embedded runtime offset `0x1B000`, runtime SHA-256
`5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da`.
The previously documented expression/word-store, selected-result, and
root-replacement rules supply shared native support. This unit adds no new
native disassembly interpretation or original-engine capture.

## Exact numerical outcomes

| Initial bank-0 `[210]` with `[12]=100` | Result 1 output | Result 3 output | B.AX row / column |
| --- | --- | --- | --- |
| 0 | 2 | 3 | 0 / 1 |
| 36 | 38 | 39 | 0 / 0 |
| 76 | 78 | 79 | 0 / 2 |

Result 1 executes one bank-0 `[210] + 2` write at
`EVENTB03.MES:0x15F1..0x1600`, envelope SHA-256
`3847eccd37c7064447cde181d1729ab42e832d971396dadf8a62e0721d1e9e98`.
Result 3 executes one `[210] + 3` write at `0x36CE..0x36DD`, hash
`0736985e0a02bedc7864bb1b01f946331e16e1af33c5ae574d6ff2b12b8da0f8`.
The auditor checks exact decoded destinations, bank, single-expression run,
addition operator and literal; no later `[210]` writer is reached.

In both choices, `[12]` stays at its supplied value and bank-0 `[251]` stays
zero. This is stronger than comparing initial/final values: **no executed
write run touches either field**, including a run starting at a neighboring
index or a wrapping state-slot run. The auditor checks storage, bank, start,
count and index-mask metadata before making that absence assertion. Every
root boundary also retains the initial `[12]` and zero `[251]`.
Thus these paths do not temporarily subtract and later restore `[12]` as
result 2 does. This numeric observation does not promote the
[B03 money hypothesis](eventb03_state12_routes.md#h-b03-money-01-money-in-100-yen-units-hypothesis)
to a new confirmed symbolic meaning.

## Unchanged dialogue, calls and presentation records

Both choices retain the same 28 prefix dialogues and four root shared calls.
Result 1 retains the 19-dialogue suffix listed in the ordinary-choice note,
nine suffix shared calls, voices `B0806.OGG` through `B0810.OGG`, and the
routine-23 `KSE0069.WAV` request at `0x1AF0`. It introduces no root registered
DEF, native character-stream boundary, routine-9 SE, or camera mode 7/8.

Result 3 retains 40 suffix dialogues, first `0x276C`, last `0x3D15`, and
20 suffix shared calls. The complete ordered offset lists and argument /
omission-count oracles are in the auditor. The notable original boundaries
remain:

| Consumer | Code-relative source interval / sequence |
| --- | --- |
| Root DEF 22 | `EVENTB03.MES:0x295D..0x2962`; `DEF_MAIN.MES` body `0x1109..0x116E`, routine 3 at `0x1163..0x1168`, return `0x116D` |
| Root DEF 21 | `EVENTB03.MES:0x2AE9..0x2AEE`; `DEF_MAIN.MES` body `0x10C4..0x1102`, routine 3 at `0x10F7..0x10FC`, return `0x1101` |
| Native character streams | `0x2A74..0x2A7B`, `0x2ACE..0x2AD5`, `0x2C15..0x2C1C`, `0x2C74..0x2C7B`, `0x2D4C..0x2D53`, `0x2DA6..0x2DAD`, `0x2E9D..0x2EA4` |
| Routine-9 selectors | `0x2A4A:69`, `0x2AA4:68`, `0x2BEB:69`, `0x2C4A:68`, `0x2D22:68`, `0x2D7C:69`; argument 2 remains zero |
| Large-CG records | `0x32F9..0x3311` and `0x3316..0x332E`, the existing mode-7/8 envelopes |
| Root voice markers | `B0815.OGG` through `B0828.OGG`, in that order |
| Other named effects | `H_H_H.WAV` at `0x2FC4`; `KSE0069.WAV` at `0x3C7E` |

Selectors 68/69 retain the existing library resource branches
`LIBLARY.LIB:0x10D9..0x10F3 -> KSE00130.WAV` and
`0x1103..0x111D -> KSE00131.WAV`. The result-3 camera/SE implementation and
native evidence in [character events](character_events.md) are reused, not
newly inferred from a similar picture or sound. The source audit records
bounded omissions, without executing native pixels/audio.

The base walker still rejects every unspecified extra boundary. Only this
derived audit admits the two exact, hash-bound DEF call/body pairs and seven
hash-bound character-stream envelopes. Each stream must match the original
opcode family, one-byte opcode boundary and six-byte consumption ending in
the exact NUL position. A matching NUL elsewhere does not authorize a skip.
Wrong entry/result/offset/end/DEF identity probes are rejected without state
changes. Native payload is not interpreted as shadow MES commands.

For each choice the complete normalized outer trace is identical to the
independently executed baseline, not merely to its terminal. This projection
retains ordered entry, offset, end, typed effect, and any resource, routine,
cell, write destination/storage and surface-mode fields. It excludes rows
whose entry is `B_PIC.MES` but **includes nested LIB rows**, including the
library-22 rows reached inside B_PIC. Picture-specific complete traces are
checked separately below.

| Result | Outer rows | SHA-256 of normalized trace JSON |
| --- | --- | --- |
| 1 | 893 | `a00ae5d6fd1323d0d61ab43816ada013a51913217753f35e64ab5a2b4869cd62` |
| 3 | 1801 | `e2de15dbe5f6809da4afdd0868c299c1d191ca0ab41964ab7baff9c070aa0dae` |

> Core 0.316.0 (2026-09-13). The outer-trace row counts and fingerprints in
> this table were taken under the separator framing of command `0x0D`. Under
> the system-call framing the same routes - every boundary, write, media row
> and picture return - reproduce with 854 / 1,732 rows for results 1 / 3
> and fingerprints `0156d2c6...`, `d75bca42...`; the root
> "native streams" at `0x2A74..0x2E9D` are `System.function[12]` calls that
> the runtime omits and runs past rather than stops on, and the B_PIC picture
> trace signatures are `166f2b6c...` (column 1), `0626c326...` (column 0) and
> `b7f9d331...` (column 2). The audits carry the new figures.
>
> Core 0.377.0 (2026-10-10, TD-56). Command `0x09` writes `global_i32` and the
> shared routines read the real selector, so the outer traces are 899 / 1,446
> rows for results 1 / 3 with fingerprints `c7ff76ac...`, `3e626e47...`.
> Routine 28's selector-1 arm sets `global_u8[4000]` and the root skips the
> routine-21 call at `0x0225`; the shared-call omission counts change (each
> routine-28 call with argument 1 omits 3 native records instead of 0; routine 32
> omits 2 instead of 4; the final argument-0 routine 28 omits 2 instead of 0;
> the audits carry the exact sequence); the
> dialogue, media, picture signatures and face columns are unchanged. B_PIC's
> own change gains the `global_i32[1]` cell it overwrites (46,665 before for
> result 1, none for result 3), and each route's final diff gains
> `global_i32[1]` = 46,677 / 46,741.

## B_PIC and complete final state

Result 1 calls `B_PIC.MES` at `0x1615..0x1622`; result 3 at
`0x37B9..0x37C6`. Both retain the supplied `[12]` and zero `[251]` at entry.
Under the fresh zero override flags 204/207/628 and incoming 3005, each uses
the same source face band and complete B_PIC/nested-library trace as result 2:

| Face column | Binding / following selector-1 interval | Trace SHA-256 | Complete nested diff |
| --- | --- | --- | --- |
| 1 | `0x05F2..0x0604` / `0x0604..0x0611` | `8d7771311ed65536362f71d2c758a97e219c217dfbd149fe272f04ab6fe86518` | global 3005: 0 -> 1 |
| 0 | `0x068E..0x06A0` / `0x06A0..0x06AD` | `05c03a5ad3d6cc1103506fdcc522b16c6374af0569f5abf74e67e697de7408c1` | Empty |
| 2 | `0x072A..0x073C` / `0x073C..0x0749` | `785567faf521981453bc41001a51a766c942cf7b96390c741b525ed3feef4eaa` | global 3005: 0 -> 2 |

The existing `MAHOKO.WAV`, `B1.MMO`, `BAN.MMO` and `B.AX` offsets, routine
22 at `B_PIC.MES:0x035B..0x0360` with argument 1 = 14, and return at
`0x0759..0x075A` are all rechecked. The empty middle-face final diff does not
mean its binding/activation commands were skipped.

The complete final diff, relative to the explicitly initialized sandbox, is:

- Both: bank-0 `[1]:0->7`, `[210]:initial->the tabled output`;
  globals 206/286/3688/5306/626/631/632: `0->1`.
- Result 1: `state_u16[21]:0->1`, global 627: `0->1`.
- Result 3: `state_u16[21]:0->3`, global 627: **`0->2`, not 3**;
  globals 3002/5307/638: `0->1`.
- Global 3005 changes only as in the face table. No other final changes occur.

These are numeric facts; no new gameplay names are assigned to the global
slots. Root replacement ends result 1 at `0x1BB6..0x1BC3 -> MACHI.MES`
and result 3 at `0x3D46..0x3D53 -> MACHI.MES`, without running the later
common return. Both envelope hashes remain
`496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047`.

## Product and verification boundary

The existing IDs `source-state12-100`, `source-state12-100-affection36`, and
`source-state12-100-affection76` now admit results 1/2/3 with their own exact
starting requests, snapshots, branch-local caller/output values and terminals.
Together with the unchanged captured-start baseline, current product scope is:

| Preset ID | Initial `[12]` / bank-0 `[210]` | Final `[210]` for results 1 / 2 / 3 | B.AX face column for all three |
| --- | --- | --- | --- |
| `captured-result3-original` | 0 / 0 | 2 / 0 / 3 | 1 |
| `source-state12-100` | 100 / 0 | 2 / 0 / 3 | 1 |
| `source-state12-100-affection36` | 100 / 36 | 38 / 31 / 39 | 0 |
| `source-state12-100-affection76` | 100 / 76 | 78 / 71 / 79 | 2 |

No neighboring affection, alternative dates, inherited flags or unnamed
starting presets are enabled. Result 2 keeps its earlier subtraction/clamp
and restoration behavior; it is not made identical to result 1/3.

The earlier MV-09/MV-10 result-2 acceptance does not establish acceptance of
these six new combinations. The grouped result-1/3 UI check is MV-11; separate
preset-reset/session-isolation checks remain in MV-09. The three numeric
representatives are isolated source-backed playback, not captured starting states or proof
that the original scheduler naturally triggers B03 at the retained date with
those affection values. Original native cadence and full effect equivalence
remain outside this unit.

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_eventb03_preset_choices.gd -- `
  <ELFIMAGE-directory>
```

The source audit passed **260 checks** over eight complete routes. The shared
walker regressions also passed: state12 audit **139 checks / six cases** and
affection audit **339 checks / 16 cases**. Executable audit v317 passed with
the identities above. Each source audit verified all six archives unchanged.

The final live Event Player regression passed **2,168 checks / 11 genuine
catalog zero-start routes** in 690 seconds: all nine initial-100 preset/choice
combinations and baseline results 1/2. The separate baseline result-3
camera/SE/station regression also passed, covering all twelve currently
supported preset/choice combinations. Live checks include complete final
state differences, branch-specific dialogue and library order, exact face
source rectangles and composed station pixels, six result-3 SE occurrences,
real camera callbacks and the post-camera AX rebind. Negative fixtures run
only after the positive terminal; they cannot supply its state or continuation.
Unexpected effect names, altered requests/states and rejected late B_PIC media
checks remain fail-closed. All six input archives remained unchanged.

Event Player synthetic/layout tests passed **808**, Event Catalog **73**, and
the headless-validation runner's Python tests **7**. Project parse, the
12-event/25-entry catalog source bindings and EVENTB14 regression also passed.
These automatic results prepare MV-11; they are not user-controlled acceptance
or a new original-engine run.

Confidence is **Confirmed** for the exact source boundaries, explicit-state
numerical outcomes, complete normalized trace comparisons and final diffs;
not for uncaptured native timing, physical audio, arbitrary-state compatibility,
or original host eligibility.
