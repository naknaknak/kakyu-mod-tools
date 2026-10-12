# GROUND F02 event analysis

Measured on 2026-09-09 against the configured original `ELFIMAGE/mes.arc`.
All coordinates are code-relative with exclusive end offsets. The archive
SHA256 is `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
These are controlled original-event observations, with Python Phase 1-4
instruction-v45 handoffs as the structural authority and GDScript as the
execution instrument. They do not promote Event Player catalog entries and do
not establish the outer scheduler that selects this caller region.

## Source and caller condition

`config/event_catalog/analysis_groups/ground_f02_v6.json` binds GROUND,
EVENTF02, START, DEF_MAIN and LIBLARY. The START calendar projection keeps its
existing table hash
`f21ee0fcb09e960046878e35ad0410aed88680f849ace471b713ef7a12525b4a`, and
calendar backing bytes and aliases stay in cloned runtime state throughout the
caller and target.

| Entry | Original entry SHA256 | Actual Python handoff SHA256 |
| --- | --- | --- |
| GROUND.MES | `b5dd1b444d1dbb4327e46a853e881c5ff46890a0b01b7ed7e9b92f2fdbc8b282` | `12ef35192a66806dc97b9c983c972969f31958fd1ff3c8b0878bca7ef0ef5dfb` |
| EVENTF02.MES | `4d96e96df62aa45a76cb4ec689a693bae1bfe5047a1b751815a1853604a65ca5` | `949a320b12a6e53e0560c96c2fc3e83223dac223ea5e2dca4e53818e34146c02` |

EVENTF02 has no literal script dispatch of its own: unlike H15's H_PIC and
A07's N_PIC, this target calls no nested event or picture entry. It carries one
Python opaque boundary, the region tail `2577..2685`.

Unlike the A07 group, F02's local guard is a **typed record**, not a runtime
observation inside an opaque tail. The measured origin is that guard itself,
`GROUND:31082..31160`, whose false target is 31450 - the H17 guard that the H15
and A07 groups use as their own origin. F02 is therefore the first condition of
the same guard chain those groups continue.

The guard is a twelve-term conjunction and requires all of:

- state_u16 slots 21=0 and 4=6;
- `400 < slot7 < 616` and `slot19 > 1559`;
- globals 100, 104, 107, 1504, 1545, 1620 and 1621 = 0.

It reads no banked word. Its profile has **19** acceptance and rejection
witnesses: the baseline, both adjacent values at each numeric bound
(400/401, 615/616, 1559/1560), an unbounded high clock at 9999, three rejecting
slot4 values, the slot21 rejection and one rejection for each of the seven
zero-valued globals. Five witnesses accept and fourteen reject.

The baseline uses slots 0=0, 1=13, 4=6, 7=501, 19=1600 and 21=0. Other writable
state starts fresh, so every global the guard reads is already zero.

## Root replacement and finite execution matrix

GROUND's typed record `31419..31435` is command `0x0E`, a root replacement. The
v6 profile therefore records `root_replacement_observation` and carries no
caller-resume section: Core's exact root-handoff follow policy executes the
selected replacement once, from EVENTF02 entry 0, and GROUND's instructions
after 31435 are not resumed.

The **20** full cases comprise:

- entry clock in {1600, 1700, 1800}, global3006 in {0,1} and global4000 in
  {0,1}: 12 combinations, each also seeding slot8=2;
- two counter cases with global264 at 14 and 15;
- two date cases at slot7=401 and 615;
- three clock-overflow cases at 1560, 1590 and 1790;
- one date-overflow case at slot7=500.

Every case has the same boundaries and message counts:

| Segment | Boundary | Message observations |
| --- | --- | --- |
| GROUND from 31082 | 31419..31435 replaces root with EVENTF02.MES | 4 |
| F02 from 0 | 2641..2654 replaces root with MACHI.MES | 16 |
| Complete measured chain | same F02 MACHI replacement | 20 |
| Direct completed F02 reentry | 2684..2685 return | 0 |

The segmented caller/target inspection matches the unbroken replacement chain's
signature rows, message observations and written-value snapshots in all 20
cases.

### Date and clock normalization at the observed DEF11 call

GROUND's observed DEF11 invocation inside `31160..31419` advances the clock
before the replacement, and the measured entry values show that the advance
normalizes an out-of-range minute or day field first:

| Caller slot19 | F02 entry slot19 | Caller slot7 | F02 entry slot7 |
| ---: | ---: | ---: | ---: |
| 1600 | 1610 | 501 | 501 |
| 1700 | 1710 | 401 | 401 |
| 1800 | 1810 | 615 | 615 |
| 1560 | 1610 | 500 | 15294 |
| 1590 | 1640 | | |
| 1790 | 1840 | | |

Canonical HHMM and MMDD inputs advance by ten minutes and keep their date.
A minute field of 60 or 90 carries into the hour before that advance
(15:60 to 16:00 to 16:10; 15:90 to 16:30 to 16:40; 17:90 to 18:30 to 18:40),
and the day-zero input 500 leaves slot7 at a value this group does not
interpret. These are numeric observations of the existing DEF11/DEF12
execution; no calendar meaning beyond the measured values is claimed.

## Target branches and state effects

F02's completion predicate `229..246` tests `global1621 = 0 && global1620 = 0`.
Its accepted body writes slot8 at `375..380` before the appearance branch at
380, so the alternative arms at 435 and 490 are never entered - the same
normalization the H15 and A07 groups record at their own sites.

Four time ladders on slot19 (`256..348`, `554..678`, `803..1019` and
`2325..2526`) select the greeting variant and write global3246. The measured
result is **2** for every entry clock below 1800 and **4** at 1810 and 1840;
only the `< 1800` step of each ladder is exercised on both edges.

The body sets global3401 and global5001, and the display condition `1068..1079`
tests global3006 = 0. The resulting global3005 is 0 when global3006 = 0 and 15
when it is 1. Site `699..710` tests global4000 = 1 and stays one-sided: the
shared library normalizes global4000 to 0 before that site, so seeding 1 does
not reach the alternative edge. These numeric observations assign no unverified
visual or narrative meaning.

The counter increment on global264 is command `0x03` and uses the confirmed
`0..15` clamp in [Format and Method](format_and_method.md). The witnesses show
0 to 1 for the ordinary cases, 14 to 15, and saturation at 15.

F02 writes global1620 = 1 and global1621 = 1 before its MACHI replacement, so
the GROUND guard rejects afterwards. All 20 cases finish with slot2=1, slot8=0,
slot16=13, banked word 1 = 7 and globals 4000 and 4001 at 0.

Direct completed reentry is **inert**. With the final state, F02's completion
predicate at 229 is false, execution reaches the return at `2684..2685` with
zero message observations and no state change at all. This differs from A07,
whose counter increment lies after its completed-state branch target and
therefore still runs on reentry.

## Evidence limits and reproducibility

| Observation | Source binding |
| --- | --- |
| Guard 31082..31160 | typed record `07d42d8ef6e43dcbf31702ab9bc084695fe7327d3686f4aa376a0371915d9479` |
| Dispatch 31419..31435 | typed record `a8210fbc5a1ece15e170270def8c26b405d14504cd4f455442bdc911e8dbec79` |
| F02 handoff 2641..2654 | opaque tail 2577..2685, `b57c924517d6b2dec6bf8d8fd4110b278c10bc991b483de158e38d27981b3ac0` |
| F02 return 2684..2685 | same opaque tail |

The complete source prefix `[31082,31435)` hashes to
`18073e17a2a8432ee2feb9139afc95a90d5195fc74dbd0f4760b2937d26300a1`. The
outgoing MACHI record hash is
`496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047`, the same
exact bytes as the H15 and A07 groups' MACHI records; its source owner and
coordinates are separately bound. The completed-reentry return record hash is
`6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d`.

The v6 audit checks the original root-replacement record, the typed guard, the
source-bound target outcome and the reentry boundary. The runtime independently
requires the accepting guard edge from the typed origin, the actual carried
state, the exact final handoff, the final guard rejection and direct reentry.
It retains Python's opaque boundary; neither the incoming nor the outgoing
target permits fallback execution of an invented caller suffix. MACHI itself is
not executed after the replacement.

The target and direct reentry visit **19 of 21** F02 conditional sites, with
both outcomes at **5** sites (325, 647, 965, 1068 and 2459). Sites 435 and 490
remain unvisited after the slot8 normalization. Earlier time bands below the
guard's own lower clock bound, one-sided conditions, other input states,
natural scheduling before 31082 and native presentation remain open.

| F02 identity | SHA256 |
| --- | --- |
| V6 profile | `870467689a3c808e24a4bf6f79e625b3e1e4a7a0c17cff80ea849405b7fb1f3e` |
| Python source audit | `1c0fda6873059eda9826d4c058e2e28b4649cc169f745d9b498afd26fa850273` |
| Runtime report | `ebdb9b46407b77b9a9d381d909937f55ce286c62a6a0408ed91247e2d9a4ff9e` |

The original group passes **607 assertions**, including the 19 guard witnesses
and 20 full replacement chains. This records a bounded original route; Event
Player catalog promotion and broader event qualification remain separate work.

## Arrival: the grounds' own poll, declared (2026-09-14, Core 0.319.0)

F02 was declared from its guard `31082` with `state_u16[21] = 0` seeded; it
now starts at the grounds' entry `0` and supplies location `0` at the poll
`5969` (`{GROUND.MES, 5969, [0]}`, spent by the prefix), with the arrival
mode `0`, no pending request and the earlier declaration's calendar, and
walks the cascade down to its guard. `ground_f02_v11.json` (592
checks) replaces the v6 profile with the same target boundary and the
earlier declaration's variants carried over; location `1` instead is
rejected. The loop and the cascade are read in
[GROUND C07 and C12](ground_c07_c12_analysis.md).

## The gate's exit is the location's (2026-09-15)

Read in [GROUND C07 and
C12](ground_c07_c12_analysis.md#the-gate-location-0s-exit-belongs-to-the-location-2026-09-15):
F02's own `MACHI` door is inside the callee, but a walk that never hands the
root to F02 leaves the grounds by a door of the map's own.
`ground_f02_v11.json` (750 checks) declares those walks as bypass variants,
replayed from the grounds' entry with location `0` and checked never to hand
the root to F02: `no-event-weekday-1` - the gate after 0 messages;
`clock-1800-global3006-0-global4000-0`,
`clock-1800-global3006-0-global4000-1`,
`clock-1800-global3006-1-global4000-0`,
`clock-1800-global3006-1-global4000-1`, `clock-overflow-1790` - the closing
exit at `1554..1567` (9 messages, `[533] = 1`, before the location is polled).
The `18:00` chains the 2026-09-14 arrival had recorded as measured and not
declared are therefore not the gate at all: arriving at `18:00` (or with the
overflowed clock `1790`) the grounds are closing, and the entry path sends the
player to the town before the location is ever polled - which is why the
declared location is not consumed on those walks.

## G08, the remaining GROUND intro

`GROUND:31051..31067` is the third and last command `0x0E` in the entry, and it
replaces the root with EVENTG08.MES. It is measurable - a run from the typed
coordinate 30603 reaches `EVENTG08.MES:6869..6882 -> MACHI.MES` - but it does
not have the shape the other eleven GROUND groups share: there is no local
eligibility guard on its dispatch at all.

That group was qualified separately, under a profile shape that states an
unconditional dispatch instead of a guard. See
[GROUND G08 Analysis](ground_g08_analysis.md).
