# Mahoko date-dependent standing selection

## Scope and source identity

Content Core `0.278.0` provides `kakyu_mes_mahoko_standing_plan/v1`, a read-only
projection of the `B_PIC.MES` date-selector slice `0x02A5..0x0568` under the
fixed caller condition `global_u8[206]=1`. It selects B1/B2/B3/B4, preserves
the two copy expressions symbolically, and stops before executing routine 22.
It is not a B_PIC interpreter or a new Event Player date/time preset.

Evidence type: direct authoritative ARC reads through current GDScript
Container/Decoder/Expression, original-EXE reader/copy instruction and hash
cross-checks, and isolated source/synthetic regression. Confidence is
**Confirmed** for the bounded selection, record intervals and symbolic
operands; actual rectangle values, destination pixels, refresh/lifetime,
cadence and natural event eligibility remain **unresolved / unqualified**.

All MES intervals below are code-relative half-open `[start,end)`. Absolute
source paths remain in `.agents/local/source_paths.md`; no payload, source
dialogue, bytecode dump or decoded image is tracked.

| Authoritative source | SHA-256 |
|---|---|
| `mes.arc` | `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6` |
| `B_PIC.MES` | `d72612395e8571848a7782ff48d8c63604a09a983ae2c564f2ee5bd5ac2b4ada` |
| `LIBLARY.LIB` | `d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d` |
| Original EXE wrapper | `3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5` |
| Embedded runtime at wrapper `0x1B000` | `5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da` |

The public builder verifies the entire B_PIC entry hash, including bytes
outside the interpreted slice. It stages only `g206=1` and date word
`state_u16[7]` in an isolated state to evaluate conditions; no original write,
copy, resource load, AX operation or shared routine is executed.

## Entry context and exact date predicates

B_PIC's bootstrap `0x0000..0x0007` targets entry `0x0008`. Earlier code can
request BGM through `global_u8[2599]==0` at `0x0085..0x0090`, argument 1 = 14
at `0x009A..0x00A0`, and routine 23 at `0x00A0..0x00A5`. Other g206 values
select B.MMO, B16A.MMO or B5.MMO before this slice. These prefix paths are
**outside this plan**, not silently simulated or claimed to have run.

At `0x02A5..0x02B6`, the decoded condition is
`global_u8[206]==1 OR global_u8[206]==3`; false target `0x0568`. The plan
qualifies only caller value **1**, not value 3 or other values. Its guard
evidence retains source offsets, result and chosen next offset. Source-line
markers between guards and loads are decoded at their complete five-byte
boundaries without execution or presentation meaning.

Let `D=state_u16[7]`. The following guards are sequential tests, with exact
parentheses supplied by the decoded AST:

| Guard | Predicate | MMO marker | False target |
|---|---|---|---|
| `0x02C0..0x02D3` | `D>400 AND D<616` | `B1.MMO:0x02E5..0x02F0` | `0x036A` |
| `0x036A..0x037D` | `D>615 AND D<916` | `B2.MMO:0x038F..0x039A` | `0x0414` |
| `0x0414..0x0427` | `D>915 AND D<1116` | `B3.MMO:0x0439..0x0444` | `0x04BE` |
| `0x04BE..0x04D1` | `D>1115 AND D<1511` | `B4.MMO:0x04E3..0x04EE` | `0x0568` |

These yield disjoint numeric intervals `401..615`, `616..915`, `916..1115`,
and `1116..1510`. No time-word read controls this selection. In particular
B3 is not established as a generic nighttime variant by these guards.
The helper accepts a strict unsigned-word integer, not a calendar-validated
date; values such as 0, 400, 1511 and 65535 are structural probes only.

If `D<=400` or `D>=1511`, all date predicates fail. The plan returns
`selection={}`, `copies=[]`, and
`boundary={kind:face_join, offset:0x0568, end_offset:0x0568, routine_id:-1}`.
This zero-length interval is a **join pointer**, not a decoded record. It
proves no standing load was selected in this slice. It does not prove a blank
screen, retention of a previous standing image, or any face display.

## Symbolic copies and unexecuted boundary

| MMO | Active-surface 2 write | Mode-0 copy | Mode-1 copy | g4000=1 write | Routine-22 call |
|---|---|---|---|---|---|
| B1 | `0x02DD..0x02E4` | `0x02F7..0x031C` | `0x031C..0x0355` | `0x0355..0x035B` | `0x035B..0x0360` |
| B2 | `0x0387..0x038E` | `0x03A1..0x03C6` | `0x03C6..0x03FF` | `0x03FF..0x0405` | `0x0405..0x040A` |
| B3 | `0x0431..0x0438` | `0x044B..0x0470` | `0x0470..0x04A9` | `0x04A9..0x04AF` | `0x04AF..0x04B4` |
| B4 | `0x04DB..0x04E2` | `0x04F5..0x051A` | `0x051A..0x0553` | `0x0553..0x0559` | `0x0559..0x055E` |

The MMO outer command occupies the byte immediately before its marker; the
load targets surface 2. Each marker is followed by a seven-byte
`banked_u16[0][1]=7` write. Both explicit copies then use active surface 7,
but their source/destination operands are separate from that active selector.
All writes are structurally verified, **not applied** by this helper.

Write `R(i)=banked_u16[0][i]`. The exact ordered copy-expression signatures are:

```text
mode 0: [0, 0, 0, 639, 399, 1, 0, 0, R(23)]
mode 1: [1, R(17), R(18), (R(17)+R(19))-1, (R(18)+R(20))-1,
         2, R(17), R(18), R(23)]
```

Mode 0 copies the inclusive source-1 rectangle `(0,0)..(639,399)` to `(0,0)`
on the destination selected by R(23). Mode 1 reads source surface 2, uses
R(17)/R(18) and R(19)/R(20) to form inclusive endpoints, and uses R(23) as
destination surface. These are not constant native coordinates, a guaranteed
640x400 standing rectangle, or reads of the distinct `state_u16[19]` time word.
The plan retains each original AST with its source metadata and marks it
`symbolic_not_evaluated`; no zero defaults, inferred geometry or pixel copy
results are substituted.

The helper checks g4000=1 and the exact single-expression call to routine 22,
then reports `kind:shared_routine` with that call's interval. It stops **before
executing routine 22**. The directly checked library body is
`LIBLARY.LIB:0x0438..0x0444`: argument 1 = 0 at `0x0438..0x043E`, routine 28
at `0x043E..0x0443`, then return `0x0443..0x0444`. Native routine-28 effects
and subsequent B_PIC face processing are not part of this plan.

The later face region starts at `0x0568` and uses the existing BAN.MMO/B.AX
affection/flag paths, returning at `0x0759..0x075A`. See
[face-route evidence](eventb03_face_flag_routes.md); the standing helper
does not reproduce or qualify those operations for a new starting date.

Direct `mmo.arc` reads and image decoding identify four `640x400` assets:

| Entry | SHA-256 |
|---|---|
| `B1.MMO` | `f6c910b31296b0f97394eba78b34bcc6bf287df995b62bbd8c5c12258bb3343c` |
| `B2.MMO` | `c33b01d3321d1ef51bd2601343085c93dfb45fe12b395c4e7ebdb002f145e004` |
| `B3.MMO` | `54c70478e72da6e8a5ba32b6a65c6d24eaaeb2470c6c949fbef418a31f54fffe` |
| `B4.MMO` | `b4a5dc06c678005b950ea8e0a33269a2f227d659f5adcd2e3d009b4d5bde510e` |

## Native cross-check

Original-EXE reads confirm the relevant storage spaces are distinct:
global-u8 token F3 reads g206 at `0x405FD3` from state `+0x80+206`;
state-u16 token 80 reads date index 7 at `0x406026` from
state `+0x2084+7*2`. Banked-u16 token A0 uses `0x4060E1 -> 0x406780` to pop
the index, reads the bank byte at `0x4060FF`, obtains the bank-0 pointer at
`0x406106`, and zero-extends the addressed word at `0x40611C`. This establishes
the symbolic references, not their current values or valid rectangles.

| Native interval | Role / checked call | SHA-256 |
|---|---|---|
| `0x4060DF..0x406132` | banked-u16 reader; `0x4060E1 -> 0x406780` | `9c2c02deea47f6038c5a553c2d7754bab85c60887ec0c0eb91ec0d061ac280fe` |
| `0x42AC4A..0x42ACA5` | subcommand-11 mode 0; `0x42AC8D -> 0x4254D0` | `b9c771f17b06cda792430a17db2a52bd6deda54eec0f414e5c397d74666e9c5d` |
| `0x42ACA5..0x42AD1B` | subcommand-11 mode 1; `0x42AD05 -> 0x4255D0` | `bb66ead0b8d4b65c5c8233bca82cf3019f3e840992c55eff08fb0e783a4efa9a` |

Mode 0 is opaque rectangle copy; mode 1 uses the RGB key read at `0x42ACB2`
from state `+0x2178`. Coordinates use inclusive endpoints. The current RGB
key, R(17..20)/R(23) values, prior destination pixels, surface lifetime and
host refresh cadence are not confirmed here. Subcommand-10 mode 1 is a
different operation and is not substituted.

Unsigned comparisons at `0x406321`/`0x406349`, equality at `0x4063AE` and
exact-one E6/E7 logic supply the numeric branch semantics, as cross-checked in
[station selection evidence](station_background_selection.md). Every tested
guard's logical operands are normalized comparison results. Shared native
audit v317, 42 logical checks and 26 MMO/copy checks passed; this increment
also rechecks the three reader/copy window hashes and three call targets
above against the unchanged configured EXE.

## Contract and verification

`build(payload, mmdd)` requires the original full entry hash and an actual
integer in `0..65535`. Its fixed input receipt is `{mmdd, g206:1}`. The result
contains versioned source/producer provenance, exact guard steps, a selected
MMO or empty selection, two symbolic copies or none, and the explicit stop
boundary. `execution` states read-only projection, no state mutation,
remake-only compatibility, unresolved native cadence and unqualified event
eligibility. Non-forward/out-of-slice branches, unknown record kinds,
unexpected producer/copy signatures and wrong routine targets fail closed.

`validate(payload, plan)` rebuilds from the same source and compares the
entire shape. JSON's finite integral numbers may match expected integer
fields; strings, booleans, fractions, missing/extra keys and changed AST or
source metadata do not. Direct build inputs remain strict integers.

The standalone source audit is
`tools/content_suite/cli/validate_mes_mahoko_standing_plan.gd`, supplied the
configured ELFIMAGE directory. It reads original media/records without
exporting them and checks archive hashes before and after. Final result:
**65,931 checks passed**, including 65,536 unsigned-word dates evaluated
against the four decoded original predicates, 14 complete boundary plans with
JSON round-trips, four MMO identities/dimensions, symbolic ASTs and tamper
rejection. The 14 dates are `0,399,400,401,413,615,616,915,916,1115,1116,1510,1511,65535`.
This is not 65,536 full event replays. All six archives remained unchanged.
The synthetic suite `tests/test_mes_mahoko_standing_plan.tscn` passed **381
checks**; isolated source-condition evaluation preserved state and RNG.

The existing four EVENTB03 presets remain at date `413` / time `1825` and
retain their previous full-route, face, media and transactional checks.
This unit adds a standing-selection proof, not new UI acceptance, date/time
eligibility or native presentation reproduction.
