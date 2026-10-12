# GROUND G08 unguarded event analysis

Measured on 2026-09-09 against the configured original `ELFIMAGE/mes.arc`.
All coordinates are code-relative with exclusive end offsets. The archive
SHA256 is `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
These are controlled original-event observations, with Python Phase 1-4
instruction-v45 handoffs as the structural authority and GDScript as the
execution instrument. They do not promote Event Player catalog entries and do
not establish how the outer scheduler reaches the measured origin.

G08 is the last of GROUND's sixteen EVENT intro sites, and the only one of the
twelve measured groups whose dispatch has **no local eligibility guard**. That
is the finding this document records; the route itself is ordinary.

## Why this group has no guard

Every other GROUND group is anchored on a `branch_if_not_true` whose false
target skips its dispatch. G08 has none. Measured over the whole entry: of every
branch false target and every transfer target in GROUND, exactly one edge
originating before the dispatch `31051..31067` lands beyond it - the constant-
true interval `5860..5867 -> 66723` that
[Event Analysis Frontier](event_analysis_inventory.md) already records as a
lexical guard candidate that must not be assigned as an event guard.

The only conditional structure before the dispatch is a three-way selector on
banked word 204:

| Selector | Predicate | False target |
| --- | --- | ---: |
| `30603..30616` | word204 = 71 | 30754 |
| `30754..30767` | word204 = 81 | 30893 |
| `30893..30906` | word204 = 80 | 31035 |

Each arm ends by transferring to 31035, and the third arm's false edge lands
there as well, so all four paths converge. At 31035 the caller writes global1475
and reaches the root replacement at 31051. Twelve selector witnesses - 0, 2, 3,
50, 70, 71, 72, 79, 80, 81, 82 and 90 - all reach the same dispatch record with
one caller message observation each. The arms differ in message content, not in
count.

Declaring one of those selectors as a `guard` would assert an eligibility
condition the original does not have, so this group uses the
`kakyu_event_analysis_group/v7` shape instead.

## The window proof

V7 replaces guard witnesses with a source-bound statement about the interval
from the typed origin `30603` to the dispatch. The Python audit re-derives it
from the original bytecode and requires the declaration to match exactly:

| Window property | Measured |
| --- | ---: |
| Typed records in `[30603, 31051)` | 56 |
| Code-offset edges in those records | 5 |
| Edge targets outside `[30603, 31051]` | 0 |
| Other command-0E/0F dispatches inside | 0 |
| Opaque-tail overlap | none |
| Return candidate records | 30728, 30867, 31014 |

The five edges target only 30754, 30893 and 31035. The audit fails closed if any
count, the return candidate list or the prefix hash differs, if an edge targets
past the dispatch offset, if another dispatch sits inside the window, or if the
window overlaps an opaque tail. Widening the origin to include the 5860 interval
is rejected for exactly that reason.

Correction, 2026-09-13 (Core 0.316.0): the three "return candidates" were
never returns. Each is the `00` that ends the record list of a message wait,
`0D 13 FF 02 02 FF 00`, which the separator framing read as a command-`0x00`
record. With command `0x0D` framed as one system call the same window holds
41 typed records, the same five edges to the same three targets, no return
candidate and no opaque overlap, and the profile's declaration was
re-measured to those values (`record_count` 41, `return_candidate_offsets`
empty, prefix hash unchanged). The "inertness of the three return
candidates" listed among the open items below is closed by that reading.

**This is a structural statement about one interval, not a reachability claim.**
It says nothing about how execution arrives at 30603, and the three return
candidate records are reported rather than proven inert - only the executed
witnesses rule them out for the states actually measured. G08's eligibility
remains an address-table row question owned by EP-07's reachability item.

## Source and measured chain

`config/event_catalog/analysis_groups/ground_g08_v7.json` binds GROUND,
EVENTG08, G_PIC, START, DEF_MAIN and LIBLARY, and keeps the START calendar
projection's existing table hash
`f21ee0fcb09e960046878e35ad0410aed88680f849ace471b713ef7a12525b4a`.

| Entry | Original entry SHA256 | Actual Python handoff SHA256 |
| --- | --- | --- |
| EVENTG08.MES | `e5339b0dd4f2504b86ddb291960788da978b9e920c91756140958a2054961365` | `7ee6ee1d667f1cffbafd54f4ae02bb97c3ab22a96e38c0ad7dd2c863d98bd32a` |
| G_PIC.MES | `80b91250f0c466ca15b5617ca6979fe43789259493e818dd6e4686ccb0f8131f` | `2b77c0d9f742caf7b01cef23c8ab47d0754cb79f73c50bf3f95071131e0f6ff7` |

GROUND's typed record `31051..31067` is command `0x0E`, a root replacement, so
no caller suffix is resumed. G08 invokes G_PIC at `4994..5007` and ends at
`6869..6882`, replacing the root with MACHI.MES.

The **19** full cases comprise word204 in {0, 50, 71, 80, 81, 90} crossed with
global2847 in {0,1} and seeding slot8=2, three entry clocks at 1000, 1700 and
1900, both global4000 seeds, and two counter cases at 14 and 15. All 19 produce
identical segmented and unbroken runs.

| Segment | Boundary | Message observations |
| --- | --- | --- |
| GROUND from 30603 | 31051..31067 replaces root with EVENTG08.MES | 1 |
| G08 from 0, including G_PIC | 6869..6882 replaces root with MACHI.MES | 66 or 71 |
| Complete measured chain | same G08 MACHI replacement | 67 or 72 |
| Direct reentry | same G08 MACHI replacement | 66 or 71 |

The message split follows G08's own word-204 tests, not the caller's: site
`1774..1787` compares word204 with 71, and the low arm produces 66 target
messages against 71 for the rest.

## Branches, state effects and the absent completion predicate

G08 has **no completion predicate**. Unlike F02, whose `229..246` tests
global1620/1621, and unlike A07, whose counter increment survives its
completed-state branch, G08 begins at a slot8 appearance branch and writes no
completion flag. Direct reentry with the event's own final state therefore
replays the entire body: the same message count, the same G_PIC call and the
same MACHI replacement. This group states that as a measured property, not as a
claim about what the outer host would do.

G08 also never touches global264: the counter witnesses at 14 and 15 finish
unchanged at 14 and 15, where F02 and A07 both increment under the confirmed
`0..15` clamp.

The caller's write of global1475 at `31035..31041` is present in every case.
Word204 selects the content branch through `1774..1787` (< 71), `2650..2663`
(< 81) and `3712..3725` (> 80), and the nested test `2590..2611`
(`word204 > 2 && word204 != 0`) splits the low arm further. The resulting
global3005 is 1 for word204 = 0, 0 for word204 = 50 and 2 for 71 and above.
Sites `4860..4871` and `5796..5807` test global2847 = 1 and both outcomes are
measured. These are numeric observations and assign no visual or narrative
meaning.

All 19 cases finish with global1475 = 1, global3246 = 0, globals 4000 and 4001
at 0, slot2 = 0, slot8 = 1, slot16 = 13 and banked word 1 = 7.

## Evidence limits and reproducibility

| Observation | Source binding |
| --- | --- |
| Selectors 30603, 30754, 30893 | typed records inside the audited window |
| Dispatch 31051..31067 | typed record `762a06be56ee36497c5f6291c7eaa95e35fb5da5cd32acbb489c369d5eac4b5a` |
| G08 handoff 6869..6882 | opaque tail 6805..6898, `2df492a24466ac638f05c7a0595a86871fcdcae3faa1b061568e34e158601f89` |

The window prefix `[30603,31067)` hashes to
`540b3ebcfe62622b881df5c539b7f0797ed167e51a314ae67ed87f34b74b8e90`. The outgoing
MACHI record hash is
`496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047`, the same
exact bytes as the F02, H15 and A07 groups' MACHI records; its source owner and
coordinates are separately bound.

The target and its reentry visit **18 of 23** G08 conditional sites, with both
outcomes at **9** sites (1418, 1441, 1774, 2590, 2650, 4860, 5796, 6620 and
6687). The five unvisited sites are the slot8 alternative arms at 325, 380, 483,
538 and 5992, skipped after the event's own normalization. Site `647..658`
(global4000 = 1) stays one-sided because the shared library normalizes that flag
first, as in the F02 and A07 groups.

| G08 identity | SHA256 |
| --- | --- |
| V7 profile | `c1cb32794d3ba8d573b3a5c6d89d420cefcd3f467f6dfa443c2ac7d05e4c8fec` |
| Python source audit | `82e08396e00b4883b9ba45ab680fd27ea08e2410980f6f514e398a6168353f63` |
| Runtime report | `3286d831ff8824d41c9248b76ba11aadc7d254fd6d25f7ff23a8668905df6347` |

The original group passes **495 assertions**, including the 12 selector
witnesses and 19 full replacement chains. Seventeen synthetic audit mutations
and one runtime mutation were checked to fail closed, so the new window proof is
not a vacuous assertion.

Natural scheduling before 30603, the inertness of the three return candidates
in the window, other input states, other G_PIC branches and native pixels,
audio, input cadence and timing all remain open.

## Arrival: the cascade branch is the guard (2026-09-15, Core 0.319.0)

The window proof above says nothing about how the grounds reach `30603`.
Read from the arrival, that is answered by the location cascade: G08's
window sits inside the branch at `27661..27740`, a typed twelve-conjunct
guard - location `0` (`state_u16[21] == 0`), Saturday, `6/16..9/15`,
`15:01..17:29`, and `global_u8[140]`, `[144]`, `[147]`, `[1406]`, `[1475]`
and `[1364]` clear - whose false edge is F02's branch at `31082`. The v7
group's `5/01` baseline lies outside that window, which is why its origin
had to be the window start.

`ground_g08_arrival_v11.json` (751 checks) is declared beside the v7
group, not in its place: origin at the grounds' entry `0`, location `0`
supplied at the poll `5969` (`{GROUND.MES, 5969, [0]}`, spent by the
prefix), the branch at `27661` as the guard with one rejecting witness per
conjunct, Saturday `7/01` `16:00` as the baseline, the v7 group's variants
ported, and the same `MACHI` door at `6869`. Location `1` instead is
rejected. The v7 group keeps the window proof - no edge in
`30603..31051` skips the dispatch - and this group the way in.

## The gate's exit is the location's (2026-09-15)

Read in [GROUND C07 and
C12](ground_c07_c12_analysis.md#the-gate-location-0s-exit-belongs-to-the-location-2026-09-15):
G08's `MACHI` door at `6869` is inside the callee, and a walk that never hands
the root to G08 leaves the grounds by a door of the map's own.
`ground_g08_arrival_v11.json` (833 checks) declares those walks as bypass
variants, replayed from the grounds' entry with location `0` and checked never
to hand the root to G08: `no-event-weekday-1` - the gate after 0 messages;
`clock-1000` - the gate after the entry path's first-Saturday narration (6
messages, `[2275] = 1`); `clock-1900` - the closing exit at `1554..1567` (9
messages, `[533] = 1`, before the location is polled). The two `[204] = 50`
chains enter the afternoon picture branch at `19921` instead and stop at the
grounds' own question at `21845` (no choice supplied); they stay measured and
not declared.
