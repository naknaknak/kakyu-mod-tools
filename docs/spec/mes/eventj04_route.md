# EVENTJ04 caller-qualified analysis

Confirmed on 2026-09-08 against the configured original `mes.arc`, SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
Coordinates below are code-relative. Python Phase 1-4 instruction-v45 handoffs
establish record boundaries; the shared bounded route probe supplies execution
evidence. Native rendering, sound, cadence and whole-scheduler eligibility are
unresolved and omitted by the tool. No character identity is inferred from J04.

| Source entry | SHA-256 | Role |
|---|---|---|
| `01M.MES` | `a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5` | Caller guard and literal handoff |
| `EVENTJ04.MES` | `991b79a543bd8527b2bf94f83aa9b19381391eee2d24dd342bc2ae3a43bace84` | 1,886-byte callee; zero-start analysis |
| `LIBLARY.LIB` | `d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d` | Shared routines 0, 21, 23 and 28 |

## Intro and starting state

The complete literal caller inventory has one caller for this entry:
`01M.MES:[0x9B85,0x9B95)` is command `0x0E`, targeting `EVENTJ04.MES`.
The bounded qualification begins at the enclosing guard `[0x9A8C,0x9AC2)`
(decimal 39564..39618). Its false destination is 39839. The guard requires:

- `state_u16[4] == 0` and `1800 < state_u16[19] < 2200`;
- `global_u8[401] == 1`;
- `global_u8[210]`, `[212]`, `[905]` and `[955]` all equal zero.

The prefix through the dispatch has SHA-256
`6795ed94441a979d5ad28382db3f815aa74284a576c8c6dfc707c6f17777fdf1`.
It contains routine 23 with selector 133, then routine 0 with selectors 137
and 138, with intervening source message records. The probe reaches precisely
the declared handoff and changes no sandbox state cells. It does not emulate
the native effects of those routines.

Four catalog presets use time 1900, the guard values above, and all combinations
of `global_u8[854]` and `[823]` in `{0,1}`. Other sandbox cells start at zero;
that fresh-state policy is a tool decision, not a claim about arbitrary saves.
For each preset, running the caller prefix then carrying its state into J04
produces the same callee trace and final state as starting J04 directly with
that preset. The UI and playback package use the latter bounded callee scope.
The caller guard has no date test; no wider eligibility claim follows.

## Callee branches and terminal

| J04 range, decimal | Confirmed record/effect |
|---|---|
| 219..230 | `global_u8[905] == 0`; false goes to return at 1841 |
| 256..261 | Sets `state_u16[8] = 0`; the following 0/1/2 branches therefore select zero in this scope |
| 616..627 and 724..735 | Tests flag 854 against zero and one; the one branch sets `global_u8[2605] = 1` at 843..849 |
| 1066..1077 and 1271..1282 | Tests flag 823 against one and zero; writes `global_u8[3030] = 1` at 1260..1266 or zero at 1471..1477 |
| 1697..1703, 1713..1719, 1724..1730, 1735..1741 | Sets flags 3714, 927, 905 and 854 respectively to one |
| 1798..1807 and 1812..1818 | Sets `banked_u16[0,242] = 1` and `global_u8[286] = 1` |
| 1823..1836 (`0x71F..0x72C`) | Callee-owned command-`0x0E` handoff to `MACHI.MES`; supported terminal |
| 1841..1842 (`0x731..0x732`) | Return when the completed flag rejects callee reentry |

Each supported preset produces 21 message observations, including name inserts;
this is not a count of dialogue boundaries. Each reaches the exact handoff with
the five cataloged completion flags set. The two branch flags retain distinct
2605/3030 outcomes. Reentering the callee with its final state returns at 1841
without messages. It is a negative regression case, not another eligible
caller preset. The numeric flags' broader game meanings remain unresolved.

The package includes the callee and shared library and stops before executing
MACHI. Native media dependencies are explicitly omitted. This closes one
bounded qualification under EP-07 and adds EP-05 coverage; it does not close
either complete-corpus item or claim full native playback.

## Reproduction

Run `py tools/audit_catalog_analysis_routes.py <ELFIMAGE>` from the project
root for actual Python handoff identities, source hashes and exact boundaries.
The normal headless batch includes `original catalog bounded analysis routes`,
which checks the caller-to-callee equivalence, all four presets, state outcomes,
completed reentry, transactional request rejection and Analysis UI at 640x400,
1920x1080 and 2560x1440. The package playback validator also includes J04.
Reports contain coordinates and counts, never source dialogue.
