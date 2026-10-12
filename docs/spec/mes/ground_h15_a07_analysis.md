# GROUND H15 and A07 event analysis

Measured on 2026-09-09 against the configured original `ELFIMAGE/mes.arc`.
All coordinates are code-relative with exclusive end offsets. The archive
SHA256 is `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
These are controlled original-event observations, with Python Phase 1-4
instruction-v45 handoffs as the structural authority and GDScript as the
execution instrument. They do not promote Event Player catalog entries or
establish all states produced by the outer scheduler.

## H15 source and caller condition

`config/event_catalog/analysis_groups/ground_h15_v5.json` binds GROUND,
EVENTH15, H_PIC, START, DEF_MAIN and LIBLARY. The START calendar projection
has its existing table hash
`f21ee0fcb09e960046878e35ad0410aed88680f849ace471b713ef7a12525b4a`.
Calendar backing bytes and aliases remain in cloned runtime state throughout
the caller, nested event, dependency and continuation.

| Entry | Original entry SHA256 | Actual Python handoff SHA256 |
| --- | --- | --- |
| GROUND.MES | `b5dd1b444d1dbb4327e46a853e881c5ff46890a0b01b7ed7e9b92f2fdbc8b282` | `12ef35192a66806dc97b9c983c972969f31958fd1ff3c8b0878bca7ef0ef5dfb` |
| EVENTH15.MES | `15fff22a8c3e5d022eaf79576b1db3540a24df9ea646d402c1d5e2db902c56c6` | `f3d3f9b7e994a1dd9fb5e6629d662de4b6f93ce28578b818a4a64fd467441220` |
| H_PIC.MES | `466f9f654079d6c0b6999817de6ad84e7e03c67584176cae7429cd01c2651687` | `451fb9e038209bcb54e0ddeaf08521325309f64f6ad0d4f45286f17cd86b3ad1` |

H15 and H_PIC have no Python opaque boundaries. This does not imply complete
semantic or branch coverage of either entry. Shared dependency identities
remain explicit in the profile.

The measured caller starts at the typed H17 guard `GROUND:31450`. That
condition rejects the chosen state and takes its false edge to the observed
H15 guard `32520..32614`, whose false target is33234. The H15 guard accepts
and the caller reaches typed command0x0F at `32822..32838 -> EVENTH15.MES`.
The callee starts at entry0 with the actual prefix-produced state.

The H15 local condition requires all of:

- state_u16 slot21=0;
- `1115 < slot7 < 1511` and `1229 < slot19 < 1530`;
- bank-zero word207>100;
- global2284=1;
- globals170, 174, 2278, 2329, 2124, 2083 and2333=0.

There is no slot4 predicate in this local guard. Its profile has **27**
acceptance/rejection and threshold witnesses, including adjacent date and
time limits, word207 values99/100/101/102, and equality rejections.

The baseline uses slots0=0, 1=13, 7=1201, 19=1300 and21=0, bank-zero
word207=101 and global2284=1. Other writable state starts fresh. In
particular, the earlier H17 predicate is false; this does not require
executing H17 first. GROUND's observed DEF11 invocation `32629..32634`
advances the clock before dispatch. The baseline enters H15 with slot19=1310;
the lower and upper full-path clock witnesses enter at1240 and1539 after
starting at1230 and1529. Source-bound calendar state supplies the date work
inside the existing DEF11/DEF12 execution.

## H15 full paths and state effects

The **37** full cases comprise:

- word203 in {40,41,80,81}, global138 in {0,15}, and globals3006 and2847
  each in {0,1}: 32 combinations;
- two runs with date slot7=1116 and1510;
- two runs with origin time1230 and1529 and matching hour/minute components;
- one run with word203=41 and global138=14.

The 32-case matrix additionally seeds global4000=1 and slot8=2 to retain
evidence of normalization along the actual caller path. Every case has the
same source boundaries and message counts:

| Segment | Boundary | Message observations |
| --- | --- | --- |
| GROUND prefix from31450 | 32822..32838 -> EVENTH15.MES | 6 |
| H15 from0, including H_PIC | return7168..7169 | 82 |
| GROUND continuation from32838 | 33211..33224 -> MACHI.MES | 0 |
| Complete measured path | same MACHI replacement | 88 |

The nested H_PIC call is H15 `6313..6326`; H_PIC starts at0 and returns
at `2381..2382`. The instrument executes it before continuing H15's own
dialogue and completion. The profile's H15 message count includes any nested
dependency observations; it does not claim complete H_PIC coverage.

H15's completion predicate `229..240` tests global2329=0. The slot8 write
`266..271` sets zero before branch271, selecting the first appearance arm.
The tested paths never execute the alternative sites326 and381. The event
sets global5228 at `753..759` and global3611 at `5911..5917`, clears slot2
at `6097..6102`, then checks bank-zero word203
at `7126..7147`. The predicate is `40 < word203 < 81`; only its accepting
edge increments global138 at `7147..7157`.

That increment is command0x03 and uses the confirmed `0..15` clamp in
[Format and Method](format_and_method.md). The witnesses confirm unchanged
counters for word203=40/81, 0->1 for accepted values41/80, 14->15, and
saturation at15. Globals3006 and2847 exercise both outcomes of their
respective H15 display-condition sites. The resulting global3005 is2 when
global3006=0 and15 when it is1. These numeric observations do not assign
unverified visual or narrative meaning to the state.

H15 itself writes global2329=1 at `7157..7163` before returning. The caller
then writes global2278=1 at `32848..32854`, repeats global2329=1 at
`32859..32865`, and assigns global264=2 at `32870..32876`. The last write
is a constant assignment, not a counter increment. The final state has
slot16=13 and slot8=46 and rejects the H15 local predicate.

Direct H15 reentry is tested separately with that final state. Global2329
rejects the body at229 and reaches return `7174..7175` with zero message
observations and no observed state diff in these cases. No caller suffix is
executed by this isolated reentry check.

## H15 evidence limits and reproducibility

The observed local guard and final GROUND handoff remain inside Python
opaque tails:

| Observation | Containing opaque span | Opaque SHA256 |
| --- | --- | --- |
| Guard32520..32614 | 32433..32659 | `e6f4695ecbcc9b7b896229d7a5d867061ecf58b5dff0a3ba48b928e9af4c7f55` |
| Handoff33211..33224 | 33147..33948 | `5384c3a4114ecb87bd10ad846140a83ed395e15484e86b73581bc64a298dfaf5` |

The guard record hash is
`97b35f61ec3f8553db04eba5882b15c01ab1258e12c6028cfa4cb8e7de2a5352`.
The complete source prefix `[31450,32838)` hashes to
`026f03770a2ef037294aa60715f3ba8d5d9cf4205101a49f13f91eaa99aefebb`.
The typed dispatch record hash is
`69fea5e967a15d30886647a39ae77e9069c92e276c788e1551f5975e32c7a351`;
the MACHI handoff record hash is
`496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047`.

The v5 source audit binds exact records and opaque spans without promoting
them to typed instructions. Runtime independently requires the accepting
local-guard edge from the typed origin. Inspected prefix/callee/suffix
execution matches the unbroken run's signature rows, message observations
and written-value snapshots. MACHI is not executed after the replacement.

The callee and direct reentry cover **9 of11** H15 conditional sites, with
both outcomes at **6** sites. Sites326 and381 are skipped by the preceding
slot8 normalization. Global4000 tests remain one-sided after the shared
library behavior. Other input states, untested H_PIC branches, natural
scheduling before31450 and native pixels/audio/input cadence remain open.

| H15 identity | SHA256 |
| --- | --- |
| V5 profile | `696a26802458715a98792e8abf87f9953b687dfa59e7e02f508ea022d0d48efa` |
| Python source audit | `f8497b4dd8b0d20e7547f7a87175dc481763b2ecba9e2b2feb6890aa8f52f27b` |
| Runtime report | `713770975127811ed35430acb9835da466ab93ffc3c4e997155116720d9dfd87` |

The original group passes **1,655 assertions**, including the 27 local
guard witnesses and37 full paths. This records a bounded original route;
Event Player catalog promotion and broader event qualification remain
separate work.

## A07 root replacement and local condition

`config/event_catalog/analysis_groups/ground_a07_v6.json` binds GROUND,
EVENTA07, N_PIC, START, DEF_MAIN and LIBLARY. Its original calendar and
shared dependencies retain the identities and policies above.

| Entry | Original entry SHA256 | Actual Python handoff SHA256 |
| --- | --- | --- |
| EVENTA07.MES | `2b78ce9e538d13afe51d29c48403abb47f85b637cdee3daecd2a187361da0072` | `45d11354d34673cb65a557fce0307d50952491c9697fa2e9328b04c3a8f3a8d8` |
| N_PIC.MES | `b4fac3ca304f4784fbf6f96ff8ef6adc8f1c53dfbb4102bab48244cf28e750b4` | `4477505ac5a0bf36435625a2780ede5403e5c657eb9d24f0773b7e076fdaf9e1` |

N_PIC has no Python opaque boundaries. A07 has one opaque span,
`6532..6625`, containing its final MACHI replacement observation.

The caller starts at typed GROUND:31450 and follows false edges at
31450, 32520, 33234, 36544 and 38658 before accepting the local A07 guard
`40430..40553`. That guard's false target is40934. It requires all of:

- slots21=0 and4=6;
- `615 < slot7 < 916` and `1229 < slot19 < 1631`;
- bank-zero word201>50 and global392=1;
- globals110, 112, 114, 117, 1059, 1034, 1112, 240, 243, 1117 and994=0.

There are **33** guard witnesses, including equality rejections, adjacent
date/time bounds and word201 values49/50/51/52. The baseline uses slots0=0,
1=13, 4=6, 7=701, 19=1300 and21=0, word201=51 and global392=1.
These are selected numeric starting states; no earlier event or complete
scheduler history is inferred.

GROUND's original typed record `40908..40924 -> EVENTA07.MES` is command
0x0E, a root replacement. The v6 profile therefore records
`root_replacement_observation` and carries no caller-resume section.
Core's exact root-handoff follow policy executes the selected replacement
once, from A07 entry0, then stops at A07's outgoing replacement. GROUND's
instructions after40924 are not resumed. The segmented caller/target
inspection matches that unbroken replacement chain's signature rows,
messages and written-value snapshots.

## A07 finite execution matrix

The **54** full cases comprise:

- word201 in {51,80,81}, globals3006, 955 and2847 each in {0,1}, and origin
  clock in {1549,1550}: 48 combinations;
- two counter264 cases at14 and15;
- two date cases at616 and915;
- two clock cases at1230 and1630 with matching hour/minute components.

The 48-case matrix also seeds global4000=1 and slot8=2 before the actual
caller prefix. These inputs do not force their corresponding display
branches to stay selected after runtime state writes.

GROUND's observed DEF11 call `40568..40573` advances time before replacing
the root. The baseline enters A07 at1310; the matrix clocks1549/1550 enter
at1559/1600. The boundary clock cases1230/1630 enter at1240/1640. The local
guard is evaluated before the advance, so the accepted origin1630 need not
satisfy the same bound after the event begins.

All cases have the following boundaries and message counts:

| Segment | Boundary | Message observations |
| --- | --- | --- |
| GROUND from31450 | 40908..40924 replaces root with EVENTA07.MES | 6 |
| A07 from0, including N_PIC | 6596..6609 replaces root with MACHI.MES | 64 |
| Complete measured chain | same A07 MACHI replacement | 70 |
| Direct completed A07 reentry | same A07 MACHI replacement | 0 |

A07 invokes N_PIC at `3423..3436`; that nested dependency starts at0 and
returns at `2312..2313` before A07 continues. The measured target count
includes dependency observations and does not imply full N_PIC coverage.

A07's initial predicate `219..230` tests global1117=0. Its accepted body
writes slot8=0 at `235..240`, so the subsequent appearance branch240 takes
the first arm. The tested paths do not visit alternative sites295 and350.
The body sets global5034 at `1040..1046` and global3435 at `3190..3196`.
It tests word201>80 at `3851..3864`, exercising both the low and high paths
with values80 and81. The low path's `4988..4999` display condition and the
later `5498..5509` condition both test global3006=0. The final branch
`5884..5895` tests global955=1. Both outcomes of these eligible sites are
measured without assigning unverified narrative meanings.

The body writes global1117=1 at `6126..6132` and global1112=1 at
`6137..6143`. The time ladder beginning at6148 records global3202=1 for
the selected pre1600 entry states and2 for entry1600 or later. Final
global3005 is0 for global3006=0 and15 for global3006=1. The whole chain
finishes with slot16=13 and slot8=46 and rejects the local GROUND guard.

The global264 increment at `6251..6261` lies after the completed-state
branch target. It executes both after the full body and when global1117
already rejects that body. Command0x03 clamps this increment to0..15:
the ordinary full cases produce0->1 and completed reentry produces1->2;
initial14 and15 finish at15 and stay there on reentry. Consequently the
zero-message reentry is still an active counter update and MACHI root
replacement, not a rejected or inert invocation.

## A07 opaque boundaries and reproducibility

| Observation | Containing opaque span | Opaque SHA256 |
| --- | --- | --- |
| GROUND guard40430..40553 | 40343..40730 | `3ce9fbb6c6db025bd8a35092c92532166d0bec4f47aa52038ed5e183f6fc6e8a` |
| A07 handoff6596..6609 | 6532..6625 | `bfae09ad37b8bf1c0b5f3e0a21f1c1064380c4d4322c269c22359cb0d50081f1` |

The local guard record hash is
`79a48017efa9fbcacdb37edd2f7be9b337bdcbd2371cd0e45cc08733ca6820d5`.
The source prefix `[31450,40924)` hashes to
`2356213868cef6611ae5213c6bb08aae50e493d8cbaf98d2dc25097804a90d12`.
The GROUND-to-A07 command0x0E record hash is
`3c937fa64a9d05ee5438ab9f6946321a9039dc84b829a88b46a99c07c59f856f`.
The outgoing MACHI record has the same exact byte hash as the H15 caller's
MACHI record above. Its source owner and coordinates are separately bound.

The v6 audit checks the original root-replacement record, source-bound
target outcome and reentry boundary. The runtime verifies the accepting
local guard, the actual carried state, the exact final handoff, the final
guard rejection and direct reentry. It retains Python's opaque boundaries;
neither the incoming nor outgoing target permits fallback execution of an
invented caller suffix. MACHI itself remains outside the measured chain.

The target and direct reentry visit **25 of27** A07 conditional sites,
with both outcomes at **12** sites. Sites295 and350 remain unvisited after
slot8 normalization. Earlier/later time bands, one-sided conditions, other
N_PIC branches, natural scheduling and native presentation remain open.

| A07 identity | SHA256 |
| --- | --- |
| V6 profile | `f889fb75bcdf6e0fe9d72266ee0b5ed690b288fc5caf9da14216c5a9510b5b62` |
| Python source audit | `67650c34e5fa10515ad8ee61ce847570e55b182e84d13934ca6356b25e238768` |
| Runtime report | `c4a6f9a56dfacd210f62a5e738f6c280b3b78502e41ccc66d8fc2d71cb14046b` |

The original A07 group passes **1,912 assertions**, including33 guard
witnesses and54 full replacement chains. It is separate from the H15
returning-callee group and does not change Event Player's original-only scope.

## Arrival: the grounds' own poll, declared (2026-09-14, Core 0.319.0)

H15 and A07 were declared from the typed origin `31450` with `state_u16[21]
= 0` seeded. Both now also start at the grounds' entry `0` and supply
location `0` at the poll `5969` (`{GROUND.MES, 5969, [0]}`, spent by the
prefix), with the arrival mode `0`, no pending request and the earlier
declarations' calendars, and walk the cascade down to their guards.

H15's arrival replaces its group: `ground_h15_v12.json` (1631 checks)
carries every variant of the earlier declaration, the same resume
(`MACHI.MES` at `33211` after 0 messages), and rejects location `1`.

A07's arrival is declared **beside** its group, not in its place:
`ground_a07_arrival_v11.json` (409 checks) reaches A07's guard and its
`MACHI` door from the arrival for 13 of the earlier declaration's 54 chains
and its own witnesses, but 50 of those chains never reach A07 when the walk
starts at the grounds' entry: with the clock at `16:30` or `15:49`/`15:50`,
or the `[955]`, display and scene cells the earlier matrix varied, the
cascade dispatches `EVENTG08` first (the walk stops at `G_PIC.MES`, outside
this package). That is a reading the `31450` origin could not give - from
there those states are A07 chains, from the grounds' entry they are G08's
afternoon - so the 2026-09-09 group `ground_a07_v6.json` stays as the
measurement of the cascade from `31450`, and the arrival group records the
50 diverted chains as measured and not declared.

## The gate's exit is the location's (2026-09-15)

Read in [GROUND C07 and
C12](ground_c07_c12_analysis.md#the-gate-location-0s-exit-belongs-to-the-location-2026-09-15):
the map change after H15 is location `0`'s own exit, copied inline at the end
of H15's branch (`33211`); A07's door is inside the callee; and a walk that
reaches neither leaves the grounds by the cascade's last branch. Both arrival
groups declare such walks as bypass variants, replayed from the grounds' entry
with location `0` and checked never to dispatch the callee. H15 has no weekday
conjunct, so its witnesses step outside the date and clock windows on the
baseline's Saturday, and the entry path's first-Saturday narration plays
before the empty cascade: `ground_h15_v12.json` (1685 checks) declares
`no-event-date-1115`, `no-event-clock-1600` - the gate after the entry path's
first-Saturday narration (6 messages, `[2275] = 1`).
`ground_a07_arrival_v11.json` (434 checks) declares `no-event-weekday-1` - the
gate after 0 messages; the 50 chains G08's branch takes first still stop at
`G_PIC.MES` and stay measured and not declared - they leave by no door of the
grounds.
