# GROUND H01/H02 caller continuations

Measured from the read-only original archive on 2026-09-09. All coordinates
are code-relative and ends are exclusive. This group qualifies four intro
sites and their controlled continuations, not complete event or scheduler
coverage. [H17/K09](ground_event_analysis.md) remains a separate group.

## Source identity and contract

The authoritative `mes.arc` SHA-256 is
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
`config/event_catalog/analysis_groups/ground_h01_h02_v3.json` binds GROUND,
both callees, DEF_MAIN, LIBLARY and START, and all caller-prefix hashes.

| Original entry | SHA-256 |
| --- | --- |
| EVENTH01.MES | `030f9857181f0fe0865abf56c25c18e80e9d3bc5f97232d39aa82bf09b0aa9f8` |
| EVENTH02.MES | `328a6a9d76b8935237be5993a46c05938753aca409bf70584fd9b37bbd97f04b` |

The profile uses `kakyu_event_analysis_group/v3`, hash
`d78be4cb66c3bb9839fd206e62365c5838dc48dc0bf5c24b9a69e907ff095270`.
The auditor rebuilds actual Python Phase 1–4 handoffs and certifies exact
records, identities and declared opaque observation spans. Runtime execution
then checks conditions, effects, choices and the exact observed boundary.
Native presentation remains omitted. Source audits alone do not certify those
runtime outcomes.

V3 explicitly labels every route `caller_continuation_observation`. Its
`stop_before_unprovided_dependency` policy stops at a declared original call
whose target is deliberately excluded from this group. Those targets exist in
the archive; they are not missing source files. The auditor rejects this policy
if the target is included in the group. A bounded dispatch is reported as a
boundary with an empty terminal, never as a successful game completion.
`natural_handoff` instead requires the actual root-replacement instruction.
Direct callee reentry may return or reach a choice, with a complete per-variant
expectation. Existing V1/V2 profiles retain their previous contracts and hashes;
migration to V3 requires new explicit policies and evidence.

## Local intro conditions

The profile has 72 one-field acceptance/rejection and numeric-boundary witnesses.
Each is evaluated at the exact original conditional. The six full path cases
use the existing source-bound START calendar and slots 0 = 30, 1 = 15,
7 = 501, 4 = 6, 16 = 1 and 19 = 1530. These are numeric test states, not proof
that the outer scheduler naturally produces them.

| Route | GROUND guard; false target | Nested intro | Additional local predicate |
| --- | --- | --- | --- |
| H01 first | 1914..1961; 3271 | 2612..2628 | slot16=1, slot7>419, slot4=6, slot19<1700; globals397/2278/2276=0 |
| H01 repeat | 3271..3331; 4092 | 3513..3529 | slot7>419, slot4=6, slot19<1700; globals397/2278/2280=0, global2276=1, global2277 neither 0 nor 3 |
| H02 first | 4092..4145; 4888 | 4319..4335 | slot16=1, slot7>419, slot4=6, slot19<1700; globals397/2282=1, globals2278/2283=0 |
| H02 later | 4888..4977; 5845 | 5285..5301 | slot16=1, slot4=6, 1529<slot19<1700; globals397/2286/2627=1, globals170/174/177/2278/2292/2124/2167=0 |

H01 repeat additionally seeds global2277=1. H02 later seeds global2283=1
to exercise its later callee phase; the caller guard itself does not require
that flag. Conflating a witness with the caller's entire predicate would hide
the first/later callee distinction.

## Execution and continuation

Every case starts at its guard, reaches the exact nested intro with actual
caller state, returns from the callee and resumes immediately after the call.
An unbroken run must match the inspected prefix/callee/suffix signature rows,
message observations and written-value state snapshot. Runtime-only calendar
backing remains in cloned state objects; it is not serialized into the profile.

| Case | Prefix / callee / suffix message observations | Callee return | Observed GROUND continuation |
| --- | --- | --- | --- |
| H01 first | 16 / 21 / 23 | 2509..2510 | 6308..6324 → EVENTK01.MES, before execution |
| H01 repeat | 6 / 32 / 18 | 5359..5360 | 16859..16875 → EVENTK01.MES, before execution |
| H02 first | 6 / 40 / 12 | 3484..3485 | 7227..7240 → K_PIC.MES, before execution |
| H02 later, choice 1 | 6 / 36 / 6 | 10253..10254 | 66123..66136 → MACHI.MES |
| H02 later, choice 2 | 6 / 32 / 6 | 10253..10254 | 66123..66136 → MACHI.MES |
| H02 later, choice 3 | 6 / 44 / 6 | 10253..10254 | 66123..66136 → MACHI.MES |

Suffix observations include subsequent GROUND scheduling up to the declared
boundary. They are not all attributed to the event just returned from. In
particular, the two H01 intros reach different K01 callers despite naming the
same target. Neither K01 nor K_PIC is executed by this group.

**Ending, 2026-09-23 (owner ruling, EP-03 step 2).** Each of the three
"before execution" stops is exactly the intro dispatch of another catalog
row: `6308..6324` is `original/eventk01/ground-000018a4`'s, `16859..16875`
is `original/eventk01/ground-000041db`'s, and `7227..7240` is
`original/k_pic/ground-00001c3b`'s, each already measured from its own
arrival (`ground_k01_kpic_analysis.md`). The rows of H01 first, H01 repeat
and H02 first therefore end by continuing into that event (game outcome
`chain`), which plays as its own row; this group still executes neither
callee. Evidence type: the profile's typed dispatch records against the
rows' `source.caller` coordinates (catalog revision 26). Tool decision:
the ending names the dispatch record the run reaches in the measured state;
whether the next event's own body then plays is that row's evidence, not
this group's.

Typed caller writes distinguish the phases:

- H01 first: globals2276/2278/2333 become 1 at `3238..3244`, `3249..3255`,
  `3260..3266`; repeat instead sets global2280 at `4059..4065`, then
  global2278 at `4070..4076` and global2333 at `4081..4087`.
- H02 first: globals2283/2278/2285/2333 become 1 at `4833..4839`,
  `4844..4850`, `4855..4861`, `4866..4872`; the global170 write at
  `4877..4883` also participates in the subsequent eligibility state.
- H02 later: caller globals2291/2167 become 1 at `5823..5829` and
  `5834..5840`. Those writes do not by themselves imply every callee branch
  has completed or that direct callee invocation must be inert.

The H02 routine-40 contract binds definitions at `6774..6783`, `6841..6850`
and `6920..6929`, with bodies ending at 6836, 6915 and 6988. Selection occurs
at `6998..7003`. The existing one-based slot21 consumer tests results 1 and 2
at 7008 and 7739; the remaining valid result is 3. Explicit selection is an
analysis tool decision, with native input semantics unresolved.
Choice 3 adds 2 to bank-zero word207 at `10159..10174` and sets global2292
at `10179..10185`. The tested choices 1/2 leave that completion flag zero.

## Reentry is a separate observation

All six post-continuation states reject their original local intro guards.
Direct invocation of the callee with the same state has different behavior:

| Case | Direct reentry observation |
| --- | --- |
| H01 first | 32 messages; next callee phase returns at 5359..5360 |
| H01 repeat | No messages; return at 5365..5366 |
| H02 first | No messages; return at 10259..10260 |
| H02 later, choices 1/2 | 12 messages; stops at routine40 6998..7003 with no selection supplied |
| H02 later, choice 3 | No messages; return at 10259..10260 |

H01's phase tests are `229..240` (global2276=0) and `2515..2526`
(global2280=0). H02 tests global2283 at `229..240`, then its later state
predicate at `3490..3562`. That latter predicate excludes caller flag2167,
which explains why a rejected caller intro does not imply a rejected direct
callee call. The reentry report retains state changes, rather than claiming
zero-message returns have no side effects.

## Confidence, opaque boundary and remaining work

The two K01 dependency-stop instructions are exact typed Python records.
The K_PIC dispatch lies within GROUND's strict opaque tail `6918..7302`,
hash `20aade91599b83383c9fdd3dde5aaaca55d944f6377c270672adfbde1ed6cfd8`.
The MACHI handoff lies within the strict opaque tail `65651..66724`,
hash `af84a1c8683b91ddf7f4d7801a4501b35e40079267da5763c64124e81398f2cd`.
Both declared opaque observation spans are independently decoded and hash-bound;
only the caller-origin runtime trace qualifies arrival there. No opaque tail is promoted
to typed IR, and no arbitrary payload coordinate becomes an execution start.

Confidence is confirmed for these source records and controlled runtime
observations under the stated policy. H01 first/repeat witness sets reach
23/32 and 11/32 conditional sites respectively; H02 first/later reach 19/64
and 33/64. These sets overlap and include direct reentry. Unvisited or one-sided
branches, outer scheduler eligibility, downstream K01/K_PIC execution and native
presentation remain open. No Event Player catalog entry is promoted.

Runtime report `kakyu_event_analysis_group_runtime/v3` passes **327 assertions**,
72 guard witnesses and six full path cases. Its hash is
`e2d5b29eceaf5dbcb068e3385db370ed64055539535f6bdd2b8bfdeaba11fa7f`.
The group runs in the headless batch as `original event analysis GROUND H01 H02`.
Nine focused checks pass in 68.589 s, including parsing, affected Core tests,
calendar, all three GROUND profiles, existing catalog analysis and thirteen
seeds' original/package equivalence. Fourteen Python profile tests and 23 batch
runner tests pass. No GUI or full native-executable batch was run.
EP-07 owns further route qualification; EP-05 owns regression scope.

The subsequent [K01/K_PIC continuation groups](ground_k01_kpic_analysis.md)
execute the three dependency paths from the same original H01/H02 origins
through their observed MACHI handoffs. The historical V3 profile and results
above remain unchanged. Wider scheduling and untested branch states remain open.

## Entry-path events, not location events (2026-09-15)

H01 and H02 are dispatched from the grounds' entry path - the guards at
`1914`, `3271`, `4092` and `4888` sit before the walk loop and the location
poll at `5969` - so the owner's reading of location `0` as the gate (see
[GROUND
overview](ground_event_analysis.md#2026-09-15-location-0-is-the-gate-its-exit-belongs-to-the-location))
does not apply to them: they play on arrival whatever the player's location,
and this group keeps its origins. The gate events they lead into, K01 and
K_PIC, are declared from the arrival in [K01 and
K_PIC](ground_k01_kpic_analysis.md#arrival-k01s-two-sites-and-k_pic-from-the-gate-2026-09-15).
