# 44M caller group: every intro measured

Measured on 2026-09-09 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches the measured origin.

`44M.MES` is the second-largest EVENT caller in the archive after `GROUND.MES`.
This document inventories its group and qualifies its routes as they land.
Nine of the ten uncatalogued intros are qualified: **EVENTC18**, **EVENTH11**,
**EVENTF22**, **EVENTF17**, **EVENTF06**, **EVENTL10**, **EVENTH18**,
**EVENTI14** and **EVENTA22**. `EVENTJ11` is measured and deliberately not
qualified; `EVENTB14` was already catalogued. They share a caller, a guard shape and a resume boundary, and
differ in who owns the completion write, which is why they are worth reading
together. F17 and F22 additionally form a chain: F17's false edge is F22's
guard. F06 is the first of them with a player choice.

## Why this group is better evidence terrain than GROUND

| Property | `GROUND.MES` | `44M.MES` |
|---|---|---|
| opaque bytes in the caller | present, and several guards are opaque-tail observations | **0 of 66,047** |
| EVENT intro sites | 16 | 11 |
| intros with a typed guard candidate | not all | **all 11** |
| opaque bytes in the eleven callees | — | **0** |

Every intro below has exactly one lexical guard candidate except `EVENTL10`,
which has three. Nothing here is an opaque-tail observation.

| Intro | Site | Form | Callee size | Callee branches |
|---|---|---|---:|---:|
| **`EVENTF06`** | **`2040..2056`** | **nested call** | **7,685** | **36** |
| **`EVENTH11`** | **`8627..8643`** | **nested call** | **2,354** | **7** |
| **`EVENTF17`** | **`13894..13910`** | **nested call** | **5,508** | **11** |
| **`EVENTF22`** | **`14202..14218`** | **nested call** | **2,954** | **8** |
| `EVENTI14` | `18342..18358` | nested call | 2,169 | 6 |
| **`EVENTC18`** | **`25032..25048`** | **nested call** | **1,881** | **8** |
| `EVENTH18` | `27347..27363` | nested call | 2,589 | 6 |
| `EVENTA22` | `51193..51209` | nested call | 9,531 | 30 |
| `EVENTB14` | `51477..51493` | nested call | 10,533 | 37 |
| `EVENTJ11` | `52900..52916` | root handoff | 26,768 | 37 |
| **`EVENTL10`** | **`65699..65715`** | **root handoff** | **4,977** | **12** |

`EVENTB14` is already a catalogued playable event; the other ten are not.

## The EVENTC18 guard is fully typed

`44M.MES:24767..24837` is a `branch_if_not_true` whose false edge is `25498`.
Its predicate is ten conjuncts, all typed, with no opaque term:

| # | Conjunct |
|---:|---|
| 1 | `state_u16[7] == 1224` |
| 2 | `state_u16[19] > 1800` |
| 3 | `state_u16[19] < 2100` |
| 4 | `banked_u16[206] > 80` |
| 5 | `global_u8[160] == 0` |
| 6 | `global_u8[164] == 0` |
| 7 | `global_u8[1694] == 0` |
| 8 | `global_u8[167] == 0` |
| 9 | `global_u8[1784] == 0` |
| 10 | `global_u8[1653] == 0` |

Between the guard's true fallthrough at `24837` and the dispatch at `25032`
there is **no conditional structure at all** — two message blocks with their
`script_transfer` records and nothing else — so the guard is the only local
eligibility condition on this dispatch.

### Twenty witnesses pin all three inequalities exactly

| Case | Value | Guard |
|---|---|---|
| baseline | — | **accept** (falls through to `24837`) |
| `state_u16[7]` | 1223 / 1225 / 1201 / 101 | reject → `25498` |
| `state_u16[19]` | 1800 | reject |
| `state_u16[19]` | **1801** | **accept** |
| `state_u16[19]` | **2099** | **accept** |
| `state_u16[19]` | 2100 / 1200 | reject |
| `banked_u16[206]` | 0 / 80 | reject |
| `banked_u16[206]` | **81** / **255** | **accept** |
| each of `global_u8[160,164,167,1653,1694,1784]` | 1 | reject |

Five accepting and fifteen rejecting witnesses. The window is the evening of
one exact date: `12/24`, after `18:00` and before `21:00`.

## The route

With the guard accepted, the caller emits 4 messages and reaches the dispatch.
`EVENTC18.MES` runs 13 messages and ends at an exact `command_00` return,
`1849..1850`, so this is a returning callee and the caller resumes at `25048`.

The callee's measured effects are `global_u8[3582] = 1`, `global_u8[5196] = 1`
and `banked_u16[1] = 7`.

Six of the callee's eight branches are exercised. Branches `321` and `376`,
which test `state_u16[8]` for 1 and 2, are unreachable from a seeded value:
the callee writes `state_u16` at `261`, immediately before the `266` test, so
the entry value is overwritten before it is read. That is the same
entry-overwritten pattern already recorded for EVENTB03's slot 8.

Eighteen variants across the clock window, `banked_u16[206]`, `global_u8[3006]`,
`global_u8[4000]`, `state_u16[8]` and `global_u8[2847]` produce **one** route:
the same 13 messages, the same return record, the same effects. Only branches
`646` and `1695` change arm, and neither changes the outcome.

## The completion predicate is caller-owned

This is the finding this route contributes. Evaluated against the state left by
the callee, the guard is **still true** in all 18 variants — nothing the callee
writes appears among its ten conjuncts, so re-entering the callee directly
replays it identically, with no state difference at all.

Evaluated against the state after the **caller** finishes its post-event
sequence, the guard is **false** in all 18. The caller's resume writes
`global_u8[1784] = 1`, which is conjunct 9, along with `global_u8[350] = 1` and
`banked_u16[242] = 44`.

So the event closes itself, but the closing write belongs to the caller, not the
event. Of the measured groups so far this is a fourth reentry shape:
A07 increments a callee counter, F02 is completely inert, G08 has no completion
predicate at all, and C18's predicate is owned by its caller.

## The caller resume boundary

Resuming at `25048` the caller emits 9 more messages across three dialogue
boundaries — `25255`, `25318`, `25435` — then transfers to `44M.MES:65466` and
stops at a **routine-40 registered-definition selection** with no catalog choice
supplied (`0xFFBA`). That is an exact, bounded unresolved boundary: the caller
reaches a player choice and this analysis does not answer it.

## What this does not establish

- No catalog entry, preset or playback support is added.
- Natural scheduler eligibility for the `12/24` evening window is not
  established; the guard is a local condition, not proof that execution arrives
  at `24767`.
- The route beyond the routine-40 selection at `44M.MES:65466` is unqualified.
- The other ten `44M.MES` intros are inventoried above, not measured.
- Native presentation remains separately labelled and omitted.

## Evidence boundary

Confidence is **Confirmed** for the ten-conjunct predicate and its exact
coordinates, the twenty guard witnesses and all three inequality boundaries, the
13-message callee run to the exact `1849..1850` return, the three measured
effects, the invariance across eighteen variants, the caller-owned completion
write, and the resume boundary coordinate.

**Unresolved / unqualified**: everything past the routine-40 selection; the
meaning of `global_u8[350]` and `banked_u16[242]`; whether branches `321` and
`376` are reachable by any caller-supplied state; and scheduler eligibility.

## The completed reentry uses the flag the caller wrote

The callee's first branch, `224`, tests `global_u8[1784]` — the same conjunct
the caller writes when it finishes. So the callee reads the completion flag even
though it never sets it.

Re-entering the callee **after the caller's post-event sequence** therefore does
not replay the event: it emits **0 messages** and returns at a different record,
`1880..1881`, instead of the first run's `1849..1850`, writing only
`state_u16[2] = 1`. Re-entering it directly, before the caller has finished,
replays all 13 messages with no state difference at all. Both are measured; the
committed group declares the completed one, which is the boundary the validator
checks.

## Runtime group: Core 0.313.0 adds `v8`

The `kakyu_event_analysis_group` schema accepted two caller-resume boundary
policies, `stop_before_unprovided_dependency` (command `0x0F`) and
`natural_handoff` (command `0x0E`). C18's resume ends at a command-`0x1D`
routine-40 selection, which the schema already understood for callee outcomes
and for reentry observations but not as a caller-resume policy. Declaring either
existing policy would have asserted a boundary this route does not have, so
`v8` adds `def_selection_boundary` as a third policy, bound to an exact
command-`0x1D` record whose routine is 40 and which names no script target. The
policy is v8-only, so no existing profile widens its contract.

The runtime validator needed no new check: it already read this boundary shape
for callee outcomes and reentry observations. v8 changes what may be declared,
not what is executed.

| Verification | Result |
|---|---|
| Python source audit | `ok:true`, `kakyu_event_analysis_group_source_audit/v8` |
| runtime group validator | `ok:true`, **571 checks**, no failures |
| runtime report | `dcc5e94139c337f907e9d967f846d81298f45ec4147b0a4468662d7c8603ea33` |
| profile | `config/event_catalog/analysis_groups/44m_c18_v8.json` |

Ten mutations of the new policy were rejected: claiming either existing policy
for this record, using the new policy on a v5 profile, shifting the stop offset
or end by one byte, naming a script target on it, pointing it at a non-routine-40
record and at a real command-`0x1D` record whose routine is not 40, claiming a
handoff op, and dropping the caller-continuation qualification. Five synthetic
tests cover the same ground in the committed suite.

## EVENTH11: the same shape with a callee-owned completion

`44M.MES:8280..8367` is a `branch_if_not_true` whose false edge is `9272`. Its
predicate is thirteen typed conjuncts, and between its true edge and the
dispatch `8627..8643` there is again **no conditional structure** — 45 records,
none of them a branch or a dispatch.

| # | Conjunct |
|---:|---|
| 1 | `state_u16[4] == 0` |
| 2 | `state_u16[7] > 915` |
| 3 | `state_u16[7] < 1116` |
| 4 | `state_u16[19] > 1759` |
| 5 | `banked_u16[207] > 70` |
| 6 | `global_u8[170] == 0` |
| 7 | `global_u8[174] == 0` |
| 8 | `global_u8[177] == 0` |
| 9 | **`global_u8[2284] == 1`** |
| 10 | `global_u8[2127] == 0` |
| 11 | `global_u8[2325] == 0` |
| 12 | `global_u8[2124] == 0` |
| 13 | `global_u8[2083] == 0` |

Conjunct 9 is the one C18 has no equivalent of: a flag that must already be
**set**. This event has a prerequisite, not only a set of things that must not
have happened yet. What sets `global_u8[2284]` is not established here.

Twenty-two witnesses, seven accepting and fifteen rejecting, pin every boundary:
`state_u16[7]` rejects 915 and accepts 916, accepts 1115 and rejects 1116;
`state_u16[19]` rejects 1759 and accepts 1760; `banked_u16[207]` rejects 70 and
accepts 71; `global_u8[2284] = 0` rejects; and each of the seven
must-be-zero flags rejects when set. The window is an autumn evening between
`09/16` and `11/15`, from `18:00` with no upper bound.

The route is invariant across nineteen variants: 25 callee messages, the exact
`command_00` return `2322..2323`, then 18 caller messages to the **same**
routine-40 stop at `44M.MES:65466` that C18 reaches. Measured effects are
`global_u8[2325] = 1`, `global_u8[3605] = 1`, `global_u8[5221] = 1`,
`banked_u16[1] = 7`, and an increment of `global_u8[264]`.

### The completion predicate is callee-owned here

`global_u8[2325]` is conjunct 11, and the **callee** writes it. So unlike C18
the guard is already false against the state the callee leaves, in all nineteen
variants, and the caller's resume adds only `global_u8[350] = 1`. The callee's
first branch `229` tests that same cell, so the completed reentry emits **0
messages** and returns at `2353..2354` instead of `2322..2323`, writing only
`state_u16[2] = 1`.

Two routes of the same caller therefore close themselves through opposite
owners: C18's flag is written by the caller after the event returns, H11's by
the event itself. Both callees read the flag; only one sets it.

### The 0..15 counter clamp reproduces

`global_u8[264]` is the counter [GROUND F02](ground_f02_analysis.md) measured as
clamped to `0..15`. Seeded at 0 it becomes 1; seeded at 14 it becomes 15; seeded
at 15 it stays 15. That is an independent reproduction of the clamp from a
different caller and a different event.

### Verification

| Check | Result |
|---|---|
| Python source audit | `ok:true`, `kakyu_event_analysis_group_source_audit/v8` |
| runtime group validator | `ok:true`, **756 checks**, no failures |
| runtime report | `1230dd68e37284750792437d944b94e3dbf4174f94fcc8104c108e3bd7c7271c` |
| profile | `config/event_catalog/analysis_groups/44m_h11_v8.json` |

Both routes use the `v8` `def_selection_boundary` resume policy, so no contract
change was needed for this one.

## Which intros are cleanly guarded

Measured over all eleven intros: the number of conjuncts, whether the predicate
contains a disjunction, and what stands between the guard's true edge and the
dispatch. An intervening branch or dispatch means the guard does not solely
decide that call, which is why the qualified routes were chosen from the clean
rows rather than by size.

| Intro | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches |
|---|---:|:---:|---:|---:|---:|---:|
| **`EVENTF06`** | 12 | - | 207 | 31 | **0** | **0** |
| **`EVENTH11`** | 13 | - | 260 | 45 | **0** | **0** |
| **`EVENTF17`** | 14 | - | 129 | 27 | **0** | **0** |
| **`EVENTF22`** | 13 | - | 153 | 27 | **0** | **0** |
| `EVENTI14` | 14 | **yes** | 1,140 | 183 | 0 | **1** |
| **`EVENTC18`** | 10 | - | 195 | 45 | **0** | **0** |
| `EVENTH18` | 13 | - | 1,761 | 263 | **1** | **1** |
| `EVENTA22` | 14 | - | 194 | 36 | 0 | **1** |
| `EVENTJ11` | 16 | - | 204 | 35 | **2** | 0 |
| **`EVENTL10`** | 12 | - | 10 | 2 | **0** | **0** |

`EVENTI14` is the only intro whose predicate is not a pure conjunction: its
second term is a disjunction of two date ranges. It and `EVENTH18`, `EVENTA22`
and `EVENTJ11` also have a branch or another dispatch between guard and call,
so describing their eligibility needs more than one record.

## Correction: all eleven intros are cleanly guarded

The gap table above was first read as saying four intros were not cleanly
guarded, because a branch or another dispatch stands between their guard and
their call. Measuring what those records actually are retires that reading:

| Intro | What is in the gap | Effect on eligibility |
|---|---|---|
| `EVENTH18` | `H_PIC.MES` nested call at `25607`; branch `27086` false→`27139` | none: the call resumes, and the false edge lands **before** the dispatch |
| `EVENTA22` | `A_PIC.MES` nested call at `51175` | none: the call resumes |
| `EVENTI14` | `I_PIC.MES` nested call at `17498` | none: the call resumes |
| `EVENTJ11` | branches `52701` false→`52718` and `52718` false→`52735` | none: both land **before** the dispatch |

And no edge anywhere in `44M.MES` enters any of those four gaps from outside
it — measured, zero in every case. So once the guard is true, control runs
through the gap to the dispatch, and the intervening records are a shared
presentation callee and local skips. The guard is the only record deciding
every one of the eleven calls.

What actually distinguishes the remaining four is what happens **after** the
dispatch, not before it.

## EVENTF22: a third route, and a second caller-owned completion

`44M.MES:13961..14049` is a `branch_if_not_true` whose false edge is `14269`,
thirteen typed conjuncts with nothing conditional before the dispatch
`14202..14218`.

| # | Conjunct |
|---:|---|
| 1 | `state_u16[4] == 0` |
| 2 | `state_u16[7] > 1115` |
| 3 | `state_u16[7] < 1511` |
| 4 | `state_u16[19] > 1000` |
| 5 | `state_u16[19] < 2001` |
| 6 | `banked_u16[200] > 110` |
| 7 | **`global_u8[1502] == 1`** |
| 8 | `global_u8[100] == 0` |
| 9 | `global_u8[104] == 0` |
| 10 | `global_u8[107] == 0` |
| 11 | `global_u8[1545] == 0` |
| 12 | `global_u8[1650] == 0` |
| 13 | `global_u8[1504] == 0` |

Conjunct 7 is a prerequisite, as H11's conjunct 9 is. Twenty-two witnesses,
seven accepting and fifteen rejecting, pin every boundary: `state_u16[7]`
rejects 1115 and accepts 1116, accepts 1510 and rejects 1511; `state_u16[19]`
rejects 1000 and accepts 1001, accepts 2000 and rejects 2001;
`banked_u16[200]` rejects 110 and accepts 111; `global_u8[1502] = 0` rejects.

Fifteen variants give one message count — 47 callee messages to the exact
`command_00` return `2947..2948` — but **four distinct branch maps**, because
the callee tests the date itself: `2297` takes its true arm at `state_u16[7] =
1224`, `2330` at `1301`, and `2363` otherwise, while `2174` responds to
`global_u8[2847]`. Measured effects are `global_u8[106] = 1`,
`global_u8[3415] = 1`, `global_u8[5016] = 1` and `banked_u16[1] = 7`, with
`state_u16[8]` clock-dependent (46 below 20:00, 0 at 2000).

The callee makes one nested call of its own, `F_PIC.MES` at `261..274`, so
`F_PIC.MES` is a source member of this group.

Its completion predicate is **caller-owned**, like C18: nothing the callee
writes appears among the thirteen conjuncts, and the caller's resume writes
`global_u8[1650] = 1`, conjunct 12, along with `global_u8[350] = 1` and
`banked_u16[242] = 44`. Unlike C18 and H11 the resume emits **no message of its
own** before reaching the same routine-40 stop at `44M.MES:65466`. The completed
reentry emits 0 messages and returns at `2953..2954`.

| Check | Result |
|---|---|
| Python source audit | `ok:true`, `kakyu_event_analysis_group_source_audit/v8` |
| runtime group validator | `ok:true`, **669 checks**, no failures |
| runtime report | `8b067d80ee653b1391d64af3367026a989c50106741bd4015dec9f5196a55833` |
| profile | `config/event_catalog/analysis_groups/44m_f22_v8.json` |

## EVENTF17: the other arm of one prerequisite flag

Measured 2026-09-10. `44M.MES:13671..13765` is a `branch_if_not_true` whose
false edge is **`13961`** — the EVENTF22 guard measured above. The two are
consecutive links of one chain, and their seventh conjunct is the same cell with
opposite polarity:

| | EVENTF17 | EVENTF22 |
|---|---|---|
| guard | `13671..13765` | `13961..14049` |
| false edge | `13961` (F22's guard) | `14269` |
| the shared conjunct | `global_u8[1502] == 0` | `global_u8[1502] == 1` |
| clock window | `1759 < x < 2300` | `1000 < x < 2001` |
| `banked_u16[200]` | `> 100` | `> 110` |

Both accept the same date range `1115 < state_u16[7] < 1511`, so at a given
moment at most one of them is eligible, decided by `global_u8[1502]`. What sets
that flag between them is not established here; neither callee writes it.

Its fourteen conjuncts are otherwise the familiar shape, and twenty-two
witnesses — seven accepting, fifteen rejecting — pin every boundary:
`state_u16[7]` rejects 1115 and accepts 1116, accepts 1510 and rejects 1511;
`state_u16[19]` rejects 1759 and accepts 1760, accepts 2299 and rejects 2300;
`banked_u16[200]` rejects 100 and accepts 101. Every rejection lands on
`13961`, which is what makes the chain visible in the witnesses rather than only
in the source.

Fifteen variants give one message count, 89 callee messages to the exact
`command_00` return `5501..5502`, and **five** distinct branch maps — one more
than F22, because this callee reacts to `global_u8[3006]` and `global_u8[2847]`
as well as to the date at `5053` (1224), `5086` (1301) and `5119` otherwise.
Constant effects are `global_u8[106] = 1`, `global_u8[3413] = 1`,
`global_u8[5014] = 1` and `banked_u16[1] = 7`, with `global_u8[3005]` varying by
arm. The callee makes **two** nested `F_PIC.MES` calls, at `409..422` and
`4573..4586`.

Completion is caller-owned as in C18 and F22: the resume writes conjunct 13,
`global_u8[1646] = 1`, with `global_u8[350] = 1` and `banked_u16[242] = 44`, and
emits no message of its own before the same routine-40 stop. The completed
reentry emits 0 messages and returns at `5507..5508`.

| Check | Result |
|---|---|
| Python source audit | `ok:true`, `kakyu_event_analysis_group_source_audit/v8` |
| runtime group validator | `ok:true`, **669 checks**, no failures |
| runtime report | `208d1d34caf4f522169f6cba88d1c28576be6bba86a84a2d3c17b6ab0c3d5381` |
| profile | `config/event_catalog/analysis_groups/44m_f17_v8.json` |

## EVENTF06: the first route here with a player choice

Measured 2026-09-10. `44M.MES:1753..1833` is twelve typed conjuncts with false
edge `2107` and nothing conditional before the dispatch `2040..2056`. Its ninth
conjunct is a prerequisite, `global_u8[1626] == 1`, and its window is a spring
evening: `400 < state_u16[7] < 616` with `1000 < state_u16[19] < 2001`.

Seventeen witnesses, five accepting and twelve rejecting, pin every boundary:
`state_u16[7]` rejects 400 and accepts 401, accepts 615 and rejects 616;
`state_u16[19]` rejects 1000 and accepts 1001, accepts 2000 and rejects 2001;
`global_u8[1626] = 0` rejects; and each of the six must-be-zero flags rejects
when set.

Unlike the four routes above, this callee asks the player a question. It stops
at a routine-40 registered-definition selection at `EVENTF06.MES:1815`, resuming
at `1820`, with three definitions and result values `1, 2, 3` consumed through
the `one_based_state_u16_21_branch_chain`. The profile therefore carries that
choice contract and every variant answers it exactly once — the first 44M group
that needs either.

The three answers are three different runs to one ending:

| Result | Callee messages | Terminal |
|---:|---:|---|
| 1 | 32 | `7653..7654` |
| 2 | 48 | `7653..7654` |
| 3 | 66 | `7653..7654` |

Twenty-one variants across the three results, the clock and `banked_u16[200]`
produce **eight** distinct branch maps, the widest coverage in this group. The
callee also branches on the clock at `7550..7619` and on `banked_u16[200]` at
`3071` and `7421`.

Completion is **callee-owned**, as in H11: `global_u8[1628]` is conjunct 11 and
the callee writes it, so the guard is already false against the state the callee
leaves. The caller's resume emits no message and writes only `global_u8[350] = 1`
and `banked_u16[242] = 44` before the same routine-40 stop at `44M.MES:65466`.
The completed reentry emits 0 messages and returns at `7684..7685`.

### Six callee branches this intro cannot reach

At `2745`, `2778`, `4898`, `4931`, `6051` and `6084` the callee tests
`state_u16[7]` against `1224` and `1301` — the same December dates F22 and F17
select on. This guard's window is `400..616`, so no state that passes it can
reach those arms. They are recorded as unreachable **from this intro**, which is
not the same as dead source: the entry has other callers to account for before
anything stronger could be said.

| Check | Result |
|---|---|
| Python source audit | `ok:true`, `kakyu_event_analysis_group_source_audit/v8` |
| runtime group validator | `ok:true`, **1,136 checks**, no failures |
| runtime report | `c0a10cfd14b7c7e41db79c9603d4fd77a96e39704fb555ee2d21c1be5ecff97d` |
| profile | `config/event_catalog/analysis_groups/44m_f06_v8.json` |

## EVENTL10: what is on the other side of the stop

Measured 2026-09-10. Every route above ends the same way — the caller runs into
a routine-40 selection at `44M.MES:65466` and stops because no answer is
supplied. EVENTL10 is what lies past it.

Three records stand before its dispatch, and only one of them is its guard:

| Candidate | Predicate | Role |
|---|---|---|
| `65342..65349` | the literal `1` | **constant true**, measured as such; kept inside the prefix and never declared as a guard |
| `65481..65491` | `state_u16[21] == 1` | the result gate: the caller's own selection must have been answered **1** |
| `65606..65689` | twelve typed conjuncts | the event guard, false edge `65725` |

The first is the same trap the frontier records for GROUND's `5860`: declaring a
constant-true interval as the event guard would hide the real condition. It is
measured (`condition_value = 1`), reported, and left in the hashed prefix.

The twelve conjuncts are a late-summer late-evening window,
`615 < state_u16[7] < 916` with `2059 < state_u16[19] < 2201`,
`banked_u16[209] > 35`, the prerequisite `global_u8[399] == 1` and six flags
clear. Twenty witnesses — seven accepting, thirteen rejecting — pin every
boundary: `state_u16[7]` rejects 615 and accepts 616, accepts 915 and rejects
916; `state_u16[19]` rejects 2059 and accepts 2060, accepts 2200 and rejects
2201; `banked_u16[209]` rejects 35 and accepts 36.

### Two routes, because the callee asks its own question

This is a command-`0x0E` root replacement, so there is no caller resume. The
callee runs to a routine-40 selection of its own at `EVENTL10.MES:4461`, and its
two results reach **two different roots**:

| Callee result | Callee messages | Terminal |
|---:|---:|---|
| 1 | 65 | `4659..4670 -> 44C.MES` |
| 2 | 62 | `4815..4828 -> MACHI.MES` |

The two options read, in the original, "go back into the dormitory" and "go
somewhere else", and the two roots are the dormitory corridor and the town map,
so the choice text and the measured terminals agree.

### The refusal arm is a curfew flag, not the clock

Extended 2026-09-10. A third arm stands beside those two, and it is gated by a
single flag:

| Branch | Predicate | Arm |
|---|---|---|
| `4476` | choice result `== 1` | dormitory root |
| `4680` | choice result `== 2` **and** `global_u8[532] == 0` | town root |
| `4838` | choice result `== 2` **and** `global_u8[532] == 1` | refusal text at `4864` |

The refusal reads as a curfew - the protagonist is told to look at the clock -
but the branch does not read the clock or the weekday. Both are already fixed by
the event's own guard, which requires the time between 21:00 and 22:00
(`2059 < HHMM < 2201`). What decides the refusal is `global_u8[532]` alone, a
flag this route does not set and whose owner is not established here.

Measured with the flag set and result 2, the scene emits the refusal and then
**re-asks the same selection**. Answering it the same way does not terminate:
761 messages to the segment limit, with no branch offset the terminating runs
do not also visit. That arm is therefore recorded and deliberately not declared
as a route - it has no ending to bind. With the flag set and result 1 the
dormitory root is reached exactly as before, so the flag gates result 2 only.

The group now carries twelve and eleven variants across its two routes and
passes 647 runtime checks.

A v6 route binds one exact terminal, which is the right constraint: these are
two routes of one group rather than one route with a variable ending. Each
declares both choice contracts — the caller's at `65466` and the callee's at
`4461` — and every variant answers both, ten variants each. The segmented and
unbroken root replacements are identical in trace, messages and state for all
twenty.

Completion is callee-owned: `global_u8[2050]` is conjunct 11 and the callee
writes it, so the guard is false afterwards in every variant, and the completed
reentry emits 0 messages, returning at `4976..4977`.

### The second caller is not measured here

`EVENTL10.MES` is one of only four EVENT entries in the archive with two
distinct callers. The other is `EVENTM20.MES:9867`, also a root handoff, with
four lexical guard candidates of its own. This group measures the 44M intro
only. Nothing here says the two intros are duplicates of one route, which is the
question the `duplicate_route` class still has open.

| Check | Result |
|---|---|
| Python source audit | `ok:true`, `kakyu_event_analysis_group_source_audit/v6` |
| runtime group validator | `ok:true`, **647 checks**, no failures |
| runtime report | `f49d79119cf8844a2ffbaf90d3e9466e8f135f90cec29e0441ccaf8b42908821` |
| profile | `config/event_catalog/analysis_groups/44m_l10_v6.json` |

## EVENTH18 and EVENTI14: the shape, twice more

Measured 2026-09-10, both on the existing v8 contract.

`EVENTH18`'s guard `25498..25586` is thirteen conjuncts with **two**
prerequisites rather than one — `global_u8[2081]` and `global_u8[2332]` must
both already be 1. Twenty-one witnesses pin 1115/1116, 1510/1511, 1800/1801 and
90/91. The route is invariant across sixteen variants: 32 callee messages to the
exact return `2557..2558`, then 15 caller messages to the shared routine-40 stop.
Completion is caller-owned through conjunct 11, `global_u8[2334]`. 660 runtime
checks pass.

`EVENTI14` carries this caller's only disjunction, and the witnesses pin it
completely. Conjunct 2 is
`(915 < state_u16[7] < 1221) or (1307 < state_u16[7] < 1511)`, and twenty-nine
witnesses — nine accepting, twenty rejecting — cover both ends of both windows
**and the gap between them**: 915 rejects, 916 accepts, 1220 accepts, 1221
rejects, **1250 rejects**, 1307 rejects, 1308 accepts, 1510 accepts, 1511
rejects. Twenty-one callee messages reach the exact return `2137..2138`, the
resume runs 24 messages to the same stop, and completion is callee-owned through
conjunct 13, `global_u8[1340]`. 660 runtime checks pass.

## EVENTA22: one selection decides the shape of the route

`EVENTA22`'s guard `50906..50999` is fourteen conjuncts, pinned by twenty-two
witnesses at 1301/1302, 1800/1801, 2199/2200 and 90/91. What makes it different
is that its callee opens with a routine-40 selection at `1354`, and the answer
decides what kind of route this is at all:

| Result | Callee messages | Ends at | Shape |
|---:|---:|---|---|
| 1 | 26 | `command_00` return `1839..1840` | returning callee, **v8** |
| 2 | 108 | `0x0E` root handoff `8453..8466 -> MACHI.MES` | **no current shape** |
| 3 | 41 | `command_00` return `9524..9525` | returning callee, **v8** |

Results 1 and 3 are declared here as two routes, ten variants between them, 510
runtime checks. `banked_u16[201]` falls from 100 to 98 on result 1 and is
unchanged on result 3.

Result 2 is measured and deliberately left undeclared. A nested command-`0x0F`
call whose callee replaces the root suspends a caller that never resumes: the
v5/v8 continuation contract requires the callee to return, and the v6/v7
replacement contract requires the **caller** record to be a command-`0x0E`. This
route is neither, so declaring it under either would assert something the route
does not do. It also reaches a second selection at `5376` whose three results
share the same terminal and message count and differ only in end state.

The completed reentry for both declared routes is run without answers, so it
stops at the callee's own selection `1354..1359` after 20 messages rather than
replaying a result.

## EVENTJ11: qualified on 2026-09-13, once the second body could be read

`EVENTJ11`'s guard `52591..52696` is the caller's largest, sixteen conjuncts
with two prerequisites, `global_u8[802]` and `global_u8[401]`: a weekday
after `9/15` between `19:59` and `22:00`, the J word `banked_u16[211]` above
`80`, and `[210]`, `[212]`, `[215]`, `[217]`, `[214]`, `[812]`, `[912]`,
`[793]`, `[784]` clear. Twenty witnesses pin the date, both clock edges
and the word and flip every flag; every rejection stops at the map's own
question at `65466`. In the gap the map reads `[907]` and `[910]` and writes
`[908]`, `[911]` and `[866]` before the handoff at `52900..52916`. The prefix
runs 6 messages.

Under the separator framing this callee did not terminate: the bounded
runtime read the selector byte of `System.function[24](4,0,"bll.mmo",0,0)` at
`15362` as a command `0x18` and dispatched back into the first body (the
history above). With command `0x0D` framed as one system call (Core 0.316.0,
`docs/spec/tech/libai5_bridge.md`) the callee reads plainly. `EVENTJ11.MES`
counts `[234]` at `118`, then selects its body at `234` on `[912]` and at
`3837` on the M word `banked_u16[205]` above `50` with `[150]`, `[154]`,
`[157]`, `[913]` clear: the first body writes `[5341]`, `[5342]`, `[854]`,
`[3031]`, closes `[912]` at `3805`, writes `[3720]` and `[5343]`, calls
`M_PIC.MES` at `8810`, and at its door writes `[915]`, `[210]` - a clear
conjunct of the caller's guard - closes `[913]` at `10176`, clears `[286]`
and hands the root to `MACHI.MES` at `10208..10221` after 143 messages. The
guard rejects every post-replacement state by `[210]` and `[912]`. A direct
reentry now takes the second body - `[912]` set at `234`, `[913]` set at
`3837` - which loads `bll.mmo`, plays voice `j0093.ogg`, reads `[820]` at
`16189` and leaves by the door at `18898..18911 -> MACHI.MES` after **78
messages**, counting `[234]` once more (the seeded-count and out-of-band
date rows override it). With the M word at `50` the callee takes that
second body on the first visit and leaves by `18898` after 125 messages: a
route of its own, measured and not declared. Segmented and unbroken runs
agree. `state_u16[8]` is rewritten at `271` before it is read and
`global_u8[4000]` reads `0` at the callee's entry whatever is seeded;
`[2847]` flips arms at `7701` and `9669`.

Declared as `44m_j11_v6.json` with no contract, `M_PIC` and `MACHI` among
the members, one root-replacement route `44m-j11` with thirteen variants -
the count varying per row - `post_guard_expected` 0, the reentry the second
body's door with its 78-message replay. Audit accepted; `original event
analysis 44M J11` passes 469 checks; a wrong callee message count and the
door shifted one byte are rejected. The two remaining open items of this
caller are the nested-call contract for a callee that replaces the root
(A22's second answer) and the M-word-at-50 route.

## EVENTB14: the catalogued intro, qualified as a group on 2026-09-19

`EVENTB14` was the one 44M intro left to the catalog row alone. Its guard
`51224..51303` (false `51503`) is eleven conjuncts - weekday 0, a date
above `9/15` and below `11/16` equal to the stamp `banked_u16[233]`, the
clock above `18:00` and below `22:00`, `global_u8[205]` and `[200]` set,
`[628]` and `[642]` clear, and the B word `banked_u16[210]` above 80 -
pinned by sixteen witnesses at 915/916, 1115/1116, 1800/1801, 2199/2200
and 80/81. The callee opens with a routine-40 selection at `1231`, three
rows, and the answer decides the shape, as EVENTA22's does:

| Result | Callee messages | Ends at | Shape |
|---:|---:|---|---|
| 1 | 27 | `command_00` return `2298..2299` | returning callee, **v8** (nine variants) |
| 2 | 48 to a second selection | stops at `0x133F` (`4927`), three rows | **measured and not declared** |
| 3 | 39 | `command_00` return `10526..10527` | returning callee, **v8** (one variant) |

Results 1 and 3 are declared (`44m_b14_v8.json`, 357 runtime checks, the
three mutations refused). Result 1 lowers the B word by 2 (`banked_u16[210]`
90 to 88) and sets `global_u8[642]`, `[4090]`, `[4091]` and `state_u16[8]`;
result 3 leaves the word alone. The caller's resume stops at the map's own
selection `65466..65471` (`def_selection_boundary`, 0 messages), and the
guard is false after the continuation because the callee wrote its own
conjunct `global_u8[642]`. The completed reentry is replayed without an
answer and stops at the callee's selection `1231..1236` after 13
messages, exactly as A22's does. Result 2 reaches a second selection at
`4927` whose three rows lead to the `0x0E` handoff `8972..8985 ->
MACHI.MES`, the `B_PIC.MES` dispatch at `8128` and the returns at `10526`
and `10532`; a nested question inside an answer is not a shape the route
spec declares, so the answer is listed under `unresolved`.

Two toolchain corrections came with this group. The measurer replayed a
nested route's reentry with the answer supplied, so a callee that asks
again was declared as returning (27 messages) where the validator's
post-continuation check, which supplies no answer, stops at the question
(13) - the measurer now replays a nested reentry without an answer and
records a stop at an undeclared selection as a `def_selection_boundary`
record. The builder asserted on an answer whose run reached no terminal;
it now leaves such an answer undeclared and names it under `unresolved`.

## Reproduction

The measurement scripts are local under the gitignored `analysis/`:
`probe_44m_group.py`, `probe_44m_guards.py`, `probe_c18_predicate.py`,
`probe_c18_region.py`, `probe_h11_i14.py`, `measure_c18.gd`, `measure_h11.gd`,
`probe_c18_resume.gd`, `probe_44m_gaps.py`, `probe_f22.py`, `probe_f17.py`,
`measure_f22.gd`, `measure_f17.gd`, `probe_f06.py`, `measure_f06.gd`,
`probe_f06_contract.gd`, `probe_l10.py`, `probe_l10_diag.gd`, `measure_l10.gd`,
`probe_44m_gap_detail.py`, `probe_44m_rest.py`, `measure_h18.gd`,
`measure_i14.gd`, `measure_a22.gd`, `measure_j11.gd` and the nine
`build_*_profile.py` generators. The caller graph comes from
`tools/build_event_analysis_inventory.py`. EVENTB14 was drafted and
qualified by the route toolchain from `analysis/_undoc/b14/44m_b14_spec.json`
(`draft_event_route_spec.py`, one manual seed `banked_u16[233] = 1016`,
then `qualify_event_route.py`).
