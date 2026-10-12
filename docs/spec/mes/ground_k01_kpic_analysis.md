# GROUND continuations through K01 and K_PIC

Measured on 2026-09-09 against the configured original `ELFIMAGE/mes.arc`.
All ranges are code-relative `[start, end)`. These V4 analysis groups extend
the [H01/H02 observations](ground_h01_h02_analysis.md) with actual carried
caller state. They do not change that historical V3 profile or promote an
Event Player catalog entry.

## Source and execution policy

The archive SHA256 is
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
Both profiles bind each source member and freshly rebuild the authoritative
Python Phase 1-4 instruction-v45 handoff. Actual handoff identities are:

| Entry | Entry SHA256 | Python handoff SHA256 |
| --- | --- | --- |
| GROUND.MES | `b5dd1b444d1dbb4327e46a853e881c5ff46890a0b01b7ed7e9b92f2fdbc8b282` | `12ef35192a66806dc97b9c983c972969f31958fd1ff3c8b0878bca7ef0ef5dfb` |
| EVENTK01.MES | `2db961a2f700de8e26d13772ab4da70a8e6e59c9dc2880eb8a37cf2cef5de5b3` | `a7804bfc838f3b4b552347b7ad5ce0b2eae7ecc3f0bb3a145a9f795248a29fff` |
| K_PIC.MES | `99b2cb3612de31c5817c03834bfa56db80e647bd8120c01b9352896e2d240ea2` | `977113fda81b578e5200d3ad2a73beab6384cd47a4e68fbfe190cf36add2a62e` |

H01/H02, START, DEF_MAIN and LIBLARY identities remain those recorded by the
earlier group and are repeated in each profile's source inventory. Neither
K01 nor K_PIC has a Python opaque boundary. GROUND retains its opaque tails.

Execution starts at the original H01/H02 guard, using the earlier calendar
context and baseline. It runs the earlier event and intervening caller code
before observing the next dispatch. The inherited guard witnesses therefore
describe the origin event's entry predicate, not a substitute K01/K_PIC
eligibility predicate. V4 binds the entire source prefix from that origin to
the new dispatch. Full sandbox objects carry the calendar and aliases.

The instrument compares prefix/callee/suffix execution with an unbroken run:
signature rows, message observations and final written-value snapshots must
match. Native pixels, audio and cadence remain omitted. It stops on GROUND's
MACHI replacement without executing MACHI.

## K01 after the two H01 phases

`config/event_catalog/analysis_groups/ground_k01_continuation_v4.json` contains
two full paths and 32 inherited origin-guard witnesses.

| Origin in GROUND | H01 dispatch | K01 dispatch | K01 return | Final GROUND handoff | Prefix / K01 / suffix messages |
| --- | --- | --- | --- | --- | --- |
| 1914 | 2612..2628 | 6308..6324 | 1389..1390 | 6982..6995 → MACHI | 60 / 15 / 6 |
| 3271 | 3513..3529 | 16859..16875 | 2367..2368 | 17547..17560 → MACHI | 56 / 9 / 6 |

Both K01 dispatches are exact typed records. In the first path the local
GROUND predicate `6044..6098`, false target 7005, checks slot21=0,
date slot7 outside 616..915 inclusive, time slot19<1600, location slot4=6,
global2276=1 and globals2277/2279=0. This is source evidence for that local
predicate; exhaustive witnesses of it and the second dispatch's local
eligibility remain open.

K01 increments global244 at `118..128` before testing its phase. Its typed
predicate `244..255` tests global2277=0; otherwise `1395..1406` tests
global2277=1. H01's carried state leaves global2277 at 0 for the first
path and 1 for the repeat path. The observed callee returns match those
two phases. Both clear globals3000/3005 and slots2/8. The first also sets
globals3628/5242 in this tested state.

GROUND writes global2277=1 at `6630..6636` on the first suffix and =2 at
`17195..17201` on the repeat suffix. It writes global2279=1 at
`6641..6647` and `17206..17212` respectively. Both final states have
slot16=13 and slot8=46. These are exact source writes with matching runtime
observations; names or native narrative meanings are not inferred.

Both final states reject their original H01 origin guard. Direct K01
reentry is a separate experiment:

- After the first path: nine messages, return `2367..2368`, global244 1→2.
- After the repeat path: no messages, return `2398..2399`, global244 1→2
  and slot2 16→1. This zero-message return is not inert.

The first path plus direct reentry visits 10 of 14 conditional sites; the
repeat path plus reentry visits 6. Each observes both outcomes at one site.
These sets overlap and are not complete K01 branch coverage.

## K_PIC after H02 first

`config/event_catalog/analysis_groups/ground_kpic_continuation_v4.json` keeps
the original H02-first origin `GROUND:4092`, dispatch `4319..4335`, and
17 origin-guard witnesses. The carried path reaches `7227..7240 → K_PIC`.
K_PIC returns at the typed `2411..2412` without message observations.
GROUND resumes at 7240 and reaches `9604..9617 → MACHI`. Message counts
are 58 before K_PIC, zero inside it and 37 afterward: 95 for the full path.
Caller write `9252..9258` sets global2286=1.

Twenty origin-state variants cross bank-zero word208 in {0,20,21,80,81}
with globals3006 and 2633 in {0,1}. Each reaches the same terminal with
the same message counts. Other relevant flags retain the profile baseline.
Final global3005 depends on those selected inputs:

| Condition | Final global3005 |
| --- | --- |
| global3006=1 | 15 |
| global3006=0 and global2633=1 | 2 |
| Both zero, word208=0 or 20 | 1 |
| Both zero, word208=21 or 80 | 0 |
| Both zero, word208=81 | 2 |

These are bounded runtime state observations, not native rendering claims.
For example, K_PIC's typed threshold predicate `1894..1961` includes
word208<21 along with other flag alternatives; predicate `2034..2045`
tests global3006=0 before the global3005=1 write at `2083..2089`.
The full expression and other alternatives must not be reduced to this
matrix outside its declared baseline.

All 20 final states reject the original H02 guard. Direct K_PIC reentry
returns at `2411..2412` with zero messages and no net state difference
in these cases. Thirteen of 20 conditional sites are visited, seven with
both results. Other flag186-dependent presentation branches, date ranges
and remaining one-sided conditions are unresolved.

## Opaque limits and reproducibility

The following original GROUND tails remain opaque in Python. Each observed
dispatch/handoff span is separately decoded and record-hashed, and only its
arrival from the typed origin is runtime-qualified:

| Observation | Containing opaque range | Opaque SHA256 |
| --- | --- | --- |
| K01 first handoff 6982..6995; K_PIC dispatch 7227..7240 | 6918..7302 | `20aade91599b83383c9fdd3dde5aaaca55d944f6377c270672adfbde1ed6cfd8` |
| K01 repeat handoff 17547..17560 | 17483..17669 | `16cfd552d9c85f7885bf58fedce80f81e3432b9fb59dee90f66d0bd274ee94a3` |
| K_PIC suffix handoff 9604..9617 | 9540..9888 | `2c43797ffbc702e49b4488d9dac5c10ffecab02d6154aa3981b09d3657eef0df` |

The three MACHI handoff records share SHA256
`496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047`.
Their source coordinates and containing tails still differ. No tail is
promoted to typed IR, and no payload coordinate becomes an arbitrary origin.

| V4 identity | K01 continuation | K_PIC continuation |
| --- | --- | --- |
| Profile | `0d068edf50363ebfdd87ebd525b06fc74787c240629fc1a1468fc8a0f59cec96` | `e1fb3fb04b3844d5e6bbe16f5b4504397510ef3c2622cf116582e55ad2c452c7` |
| Python source audit | `88deec70a0021e582d99d5f3f1331409bc3883e0733021b9c1e3e3d6c779a7af` | `4b5c294009f5b2ad87f9742f20bb87dc7f82a80f930549f33d21d3d56537fdd1` |
| Runtime report | `e8306552d77a3e630d528629da1168ec90d35aaea5c743b93efac2198f9d49a4` | `de83bdb9977a652915d7b1717369da5d324972c56b527febb14254a7a96dc5b5` |
| Runtime assertions | 132 | 485 |

The headless batch names are `original event analysis GROUND K01 continuation`
and `original event analysis GROUND K_PIC continuation`. Source records and
the stated controlled observations are confirmed; outer scheduling, untested
states, downstream MACHI execution and native presentation remain open.
EP-07 owns those remaining qualifications and EP-05 owns regression coverage.

The combined regression batch passes 12 focused checks in 88.349 s, including
the three V4 groups, existing V2/V3 groups, project parsing, affected Core tests,
calendar context, catalog analysis and all thirteen seeds' package equivalence.
The separate historical V1 run also reproduces its 155-assertion report hash.
Twenty-four Python profile tests and 23 batch-runner tests pass. This does not
claim the full original/native-executable batch or GUI verification.

## Arrival: K01's two sites and K_PIC from the gate (2026-09-15)

The v4 groups above reach K01 through H01 and K_PIC through H02 - the
entry-path events that set the flags the gate's branches test - and start at
those events' guards. Declared from the arrival beside them, as leaving-school
events: origin at the grounds' entry `0`, location `0` at the poll `5969`, the
cascade branch as the typed guard with one rejecting witness per conjunct,
Saturday `5/01` `15:30` as the baseline, the entrance preset `[16] = 0` and
`[397] = 0`. H01's first phase needs the entrance `[16] = 1` and H02's `[397]
= 1`, so neither fires before the first site or K_PIC; H01's second phase
(guard `3271`, no entrance conjunct: `[2276] = 1`, `[2277]` not `0` or `3`,
`[2280] = 0`) does fire before the second site - 62 messages and 20 minutes on
the entry path, the shape the v4 route measured from `3271` - which is why
that site's `15:59` witness misses K01: by `16:19` the branch is closed and
the walk leaves by F02's handoff, measured and not declared.
`ground_k01a_arrival_v12.json` (344 checks) takes the cascade's first branch
`6044..6098` (before `6/16` or after `9/15`, before `16:00`, `[2276] = 1`,
`[2277] = 0`, `[2279] = 0`) to K01's first call at `6308` and the door at
`6982`; `ground_k01b_arrival_v12.json` (265 checks) the branch `16583..16637`
(`[2277] = 1`, the second stage) to the call at `16859` and the door at
`17547`; `ground_kpic_arrival_v12.json` (569 checks) the branch `7005..7039`
(Saturday, before `17:00`, `[2283] = 1`, `[2286] = 0`) to K_PIC's call at
`7227` and the door at `9604`, with the v4 group's 20 variants ported.
Bypasses - the gate without the event, replayed from the entry and checked
never to dispatch the callee: K01 first site 1 by the gate; second site 1 by
the gate; K_PIC 1 by the gate.
