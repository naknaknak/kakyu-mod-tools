# GROUND C07 and C12 event analysis

Measured on 2026-09-09 against the configured original `ELFIMAGE/mes.arc`.
All coordinates are code-relative, with exclusive end offsets. These are
controlled original-event observations; they neither promote an Event Player
catalog entry nor establish every state the outer scheduler can produce.

## Source and execution policy

The authoritative archive SHA256 is
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
The source auditor rebuilds actual Python Phase 1-4 instruction-v45 handoffs.
GDScript remains the runtime instrument. Original calendar state comes from
the existing source-bound START projection and is carried in cloned sandbox
objects, including its runtime-only backing bytes and aliases.

The `kakyu_event_analysis_group/v5` contract can qualify an observed local
guard inside an existing Python opaque tail. It binds that tail and the exact
guard record hash, requires a typed earlier execution origin, and checks that
the caller-origin trace actually executes the guard with a true result before
reaching the exact dispatch. A standalone guard witness checks its expression;
it does not certify that the original scheduler naturally reaches that state.
No opaque tail is promoted to typed IR and no arbitrary payload coordinate
becomes an execution origin.

The runtime compares inspected prefix/callee/suffix execution with an unbroken
run. Signature rows, message observations and written-value snapshots must
match. Native pixels, audio, input timing and cadence remain omitted. Reaching
a MACHI replacement ends the measurement without executing MACHI.

## C07: local condition and confirmed origin

`config/event_catalog/analysis_groups/ground_c07_v5.json` binds seven original
members: GROUND, EVENTC07, C_PIC, O_PIC, START, DEF_MAIN and LIBLARY.

| Entry | Entry SHA256 | Actual Python handoff SHA256 |
| --- | --- | --- |
| GROUND.MES | `b5dd1b444d1dbb4327e46a853e881c5ff46890a0b01b7ed7e9b92f2fdbc8b282` | `12ef35192a66806dc97b9c983c972969f31958fd1ff3c8b0878bca7ef0ef5dfb` |
| EVENTC07.MES | `227dbdb7c1457cb1a975811494d572f300604825f7117f7be519950d8421cb63` | `dc2e08fdddfb7cce3392bdac0a08fba1726ce5a900a573431b03f13dc5ec9fec` |
| C_PIC.MES | `15e56d8ba218de1a0a3819cc6571e03a6ea08fbeb931940286bc59d92f866add` | `ca07f4f46a0ddb2e39594b3584fb1f673d20b1b8385811fc6e7457fd9dae8020` |
| O_PIC.MES | `d1b02b0deafa9c1ad97d4641c31c79dd4606897476e6e2f00b376b8a3273f7fe` | `9b06606253b660658e45ac97a9fdd6a879998429e6a7173aae08f2c3aea28e95` |

C07, C_PIC and O_PIC have no Python opaque boundaries. The profile repeats
START, DEF_MAIN and LIBLARY entry fingerprints and the existing calendar table
hash `f21ee0fcb09e960046878e35ad0410aed88680f849ace471b713ef7a12525b4a`.
These dependencies are executed only along the selected C07 continuations;
their complete branch coverage is not claimed.

Every full case begins at the earlier typed K01 guard `GROUND:6044`.
Its false branch enters the K_PIC guard at 7005;
that observed condition is false and enters the C07 guard at 9627. The C07
guard is true and the caller reaches the typed nested dispatch
`10051..10067 -> EVENTC07.MES`, starting the callee at 0. The measured route
therefore has an earlier typed anchor even though its local guard is opaque
in the authoritative structural handoff.

The local guard `9627..9711`, false target 12184, requires all of:

- state_u16 slots21=0 and 4=6;
- `615 < slot7 < 916` and `slot19 < 1630`;
- global396=1;
- globals230, 160, 1694, 164, 167, 1728 and 1653=0.

The profile contains **22** one-field acceptance/rejection and numeric-boundary
witnesses. Its baseline uses slots0=30, 1=15, 4=6, 7=701, 19=1530 and 21=0,
with global396=1 and otherwise fresh writable state. These are controlled
numeric states, not claims about natural outer scheduling. No H01/H02 event
must run first on this selected route.

The actual prefix advances the clock before entering C07. Origin slots19=1530,
1=15 and 0=30 produce entry slot19=1540. The other clock witness starts at
1550 with slots1=15 and 0=50 and enters C07 at 1600. Thus the selected callee
time branches are checked using the caller's produced state, not the initial
clock value.

## C07 execution, counters and caller completion

The **35** full cases comprise:

- bank-zero word203 in {40,41,80,81}, global138 in {0,15}, origin clock in
  {1530,1550}, and global3006 in {0,1}: 32 combinations;
- two further complete runs with date slot7=616 and 915;
- one run with word203=41 and global138=14 to check the final increment
  before saturation.

All 35 cases have the same source boundaries and message counts:

| Segment | Confirmed boundary | Message observations |
| --- | --- | --- |
| GROUND prefix from 6044 | 10051..10067 -> EVENTC07.MES | 6 |
| EVENTC07.MES from 0 | return 2221..2222 | 12 |
| GROUND suffix from 10067 | 12161..12174 -> MACHI.MES | 30 |
| Complete measured path | same MACHI replacement | 48 |

The suffix executes two additional typed nested calls. GROUND `10088..10101`
invokes C_PIC, whose observed return is `2832..2833`. GROUND `10793..10806`
then invokes O_PIC, whose observed return is `2602..2603`. Both start at 0.
The 30 suffix messages include the caller's continued sequence; they are not
attributed solely to C07 or to either picture dependency.

C07's completion test `224..235` requires global1728=0. Its slot8 write at
`261..266` sets 0 before the phase-dependent display tests. In the measured
first-entry paths, the event sets global5186 at `1045..1051` and global3574
at `1865..1871`, clears slot2 at `2051..2056`, and reaches the return.
The callee's time tests select global3219=1 at `2145..2151` for the 1540
entry state and global3219=2 at `2168..2174` for the 1600 entry state.
These state values are recorded without assigning unverified narrative or
native presentation meanings.

The typed gate `2190..2211` requires `40 < bank-zero word203 < 81`.
Only that branch increments global138 at `2211..2221`. This is command
`0x03`, whose write clamps to `0..15` under the shared rule in
[format and method](format_and_method.md). The matrix checks both endpoints
and confirms 0→1, 14→15 and saturation at 15 for accepted word203 values.
Values40 and 81 leave the counter unchanged. Changing global3006
also exercises both outcomes of its `954..965` gate; the profile records the
resulting state without treating omitted display effects as reproduced pixels.

The caller records completion after C07 and both dependencies:

| GROUND source range | Verified effect |
| --- | --- |
| 11746..11752 | global160 = 1 |
| 11757..11767 | global234 += 1 |
| 11772..11782 | global264 += 1 |
| 11787..11793 | global1728 = 1 |
| 11798..11804 | global1775 = 1 |

The two counters begin at 0 in these witnesses and finish at 1. They are
increments, rather than unconditional assignments of 1. The final states
have slot16=13 and slot8=46 and reject the original C07 local guard.

Direct C07 reentry is checked separately with the post-continuation state.
Global1728 now makes `224..235` false. The event writes slot2=1 at
`2227..2232`, executes its existing shared routine, and returns at
`2252..2253` with zero message observations. The state change is retained
in the report; this return is not described as inert.

## C07 opaque limits and reproducibility

| Observation | Containing Python opaque range | Opaque SHA256 |
| --- | --- | --- |
| Guard 9627..9711 | 9540..9888 | `2c43797ffbc702e49b4488d9dac5c10ffecab02d6154aa3981b09d3657eef0df` |
| MACHI handoff 12161..12174 | 12097..12444 | `3b09e10872c62d46e56053164794c4adbc83e584575e647766b6678f59139746` |

The exact guard record SHA256 is
`6269d3c47e6250b8851e54808f4f07314a5cf59f751b864a32b00075626b18d1`.
The source prefix `[6044,10067)` SHA256 is
`3ad8888ada11f3645314517fb773592b22627f49196095015ccc0fd36fdf5f00`.
The typed C07 dispatch record SHA256 is
`3a8a6d2ca998407dea599e5d586a57bd38df6981e0098f9caf3a4eccee85d222`;
the final MACHI record SHA256 is
`496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047`.

Runtime traces visit **18 of 20** C07 conditional sites, with both results
at six sites. Sites321 and 376 are unvisited because the preceding slot8=0
write selects the earlier arm on the tested entry paths. Other time ranges,
one-sided conditions, untested dependency branches and natural scheduler
eligibility remain open. Source-bound opaque observations establish these
controlled paths without changing Python's structural interpretation.

| C07 identity | SHA256 |
| --- | --- |
| V5 profile | `4271598b5e5e2898dc2e838ebe7889545b93080efe5c3faf3995d16b602f7947` |
| Python source audit | `44a3adc4b534b6e3f8f9b629a318d8186a3cfc4c7d7acb5b3f48cb27bfa1e58e` |
| Runtime report | `956dc30cee55db454efa14c9efe67c4a91a1a471de5670ea20b7529db29a65a5` |

The runtime group passes **1,086 assertions**, including the 22 local guard
witnesses and 35 full paths. It is registered in the headless batch as
`original event analysis GROUND C07` and can also be run directly with
`validate_event_analysis_group.gd` and the profile path above. EP-07 owns
remaining route qualifications and EP-05 owns regression coverage.

## C12: two sequential calls under one condition

`config/event_catalog/analysis_groups/ground_c12_v5.json` binds GROUND,
EVENTC12, O_PIC, START, DEF_MAIN and LIBLARY. Their shared identities remain
those above. EVENTC12's entry SHA256 is
`d599a6c98136531e94304dbf9d1f6c329746fd1f9d15b7ce9d92bc55c09569cf`;
its actual Python handoff is
`065c65e7fa9296bd2a627a1dcbdb1ab0936afca337316dab696c744c13507249`.
The callee has no Python opaque boundary.

The typed origin is again GROUND:6044. The C12 baseline sets globals2276
and 2283 to zero, so the earlier K01 and K_PIC predicates are false. Date
slot7=1201 and global1728=1 reject C07, then the local C12 guard accepts.
These are selected starting states; no uninterrupted C07-to-C12 playthrough
or complete scheduler history is inferred.

The shared local guard `12184..12267`, false target 14586, requires:

- slots21=0 and 4=6, slot7>915 and slot19<1630;
- globals396=1 and 1728=1;
- globals230, 160, 164, 167, 1729, 1694 and 1653=0.

The profile checks 23 unique guard witnesses at each inspection point,
46 evaluations in total. These include equality rejections, date915/916,
time1629/1630/1631 and global1729 values1/2/255. The latter values are local
predicate witnesses; they do not claim full caller paths or natural states.
The complete runs use date1201, the START calendar, and matching hour/minute
components for the chosen clock value.

Both C12 intros execute on the same path. GROUND first dispatches at
`12803..12819`; after return, it writes global1729=1 at `12819..12825`,
writes global235=0 at `12835..12841`, calls O_PIC at `12846..12859`, then
dispatches C12 again at `13935..13951`. Both C12 calls start at entry0.
The second inspection must therefore execute the first call and carry its
state. Core 0.310's exact dispatch stop preserves the complete provider and
stops only at the selected owner and call coordinate.

| Inspection point | Prefix messages | Selected C12 return / messages | Remaining caller messages | Whole path |
| --- | --- | --- | --- | --- |
| First call, 12803..12819 | 12 | 3025..3026 / 17 | 54 | 83 messages; GROUND14563..14576 → MACHI |
| Second call, 13935..13951 | 54 | 4651..4652 / 23 | 6 | Same 83 messages and handoff |

The first suffix includes O_PIC and the second C12 call. The second prefix
includes the first C12 call and O_PIC. The two profile routes inspect the
same original execution at different boundaries; their counts are not two
disjoint sets of original event paths.

## C12 phase, clock and state witnesses

Each inspection point has 34 variants: eight origin clocks
{549,550,849,850,1549,1550,1600,1629} crossed with globals3006 and 2847
in {0,1}, followed by two counter264 cases at 14 and 15 with clock1550
and both flags zero. Thus 34 starting-state cases are inspected at two
calls, producing 68 route variants. Every variant also seeds global4000=1
and slot8=2 to observe their normalization along the selected path.

GROUND's registered DEF11 call `12282..12287` advances time before either
event call. The eight clock values become 559/600/859/900/1559/1600/1610/1639.
The entry condition is evaluated before that advance; origin1629 can pass
the `<1630` guard and enter the callee at1639. Source-bound calendar backing
and actual hour/minute components are retained through the calls.

C12's typed `224..235` predicate tests global1729=0 and selects phase0.
Phase0 sets global5191 at `1045..1051` and global3578 at `2700..2706`,
then returns at `3025..3026`. It leaves global1729=0. The caller's write
between the calls supplies the phase transition.

The alternate predicate `3036..3047` tests global1729=1 and selects phase1.
It sets global5192 at `3507..3513` and global3578 at `4414..4420`,
increments global264 at `4636..4646`, and returns at `4651..4652`.
Other phase values have a typed return at `4657..4658`; that structural
fact is not a measured full caller route in this profile.

The counter write is command0x03 with the existing 0..15 clamp described in
[Format and Method](format_and_method.md). Counter0 becomes1 in phase1;
14 and15 both finish at15. It is not byte-wrap arithmetic. Phase0's final
global3005 is0/15 for the two global3006 values and is carried through phase1.
For the eight entry times above, phase0's observed global3221 values are
4/1/1/1/1/2/2/2. These retain numeric meanings without assigning an unverified
native visual or narrative interpretation.

Both phases normalize slot8 before their appearance branches: writes
`261..266` and `3073..3078` set zero. Global4000 also becomes zero through
the existing shared-library behavior; its opaque-library qualification
remains as recorded in [GROUND Event Analysis](ground_event_analysis.md).

After the second call, typed GROUND writes set globals160, 230 and1775 to1
at offsets14156, 14167 and14178. It clears globals1730, 1774, 1662 and1677
at14189, 14200, 14211 and14222. Both full paths reach the same MACHI
replacement with slot16=13 and slot8=46 and reject the original local guard.

Direct C12 reentry with that final state still executes phase1, observes
23 messages and returns at `4651..4652`. Counter264 changes from1 to2
in the ordinary cases and remains15 in the saturation cases. Local caller
rejection does not imply a rejected or inert direct callee invocation.

## C12 source limits and reproducibility

Both C12 dispatch records are typed and share SHA256
`f7e39cafea9b5837a9b34ff3a833260b10c1244bca5e484b3e56929bd51c3b19`.
The source prefix hashes remain tied to the selected coordinate:

| Span | SHA256 |
| --- | --- |
| [6044,12819) | `6f28000bdab490ba24b350ec4e08595d5cfb98129ba4848d0d6012cbbb615422` |
| [6044,13951) | `ee66fcac5578a4585e9965cb02611afed33daeea4a0ad8458c9ca691bd73baef` |

Guard12184..12267 has record hash
`df8fab809780620226f23cc2661d91e47db8994248f73896518bddaa365d3cd0`
inside opaque12097..12444, hash
`3b09e10872c62d46e56053164794c4adbc83e584575e647766b6678f59139746`.
Handoff14563..14576 has the same MACHI record hash documented above, inside
opaque14499..14996, hash
`7a7f48141238a8a5a504aad0dd08990a1581f46721ec42458633f6721f8dc959`.
The isolated byte checks and accepting-origin traces preserve these opaque
classifications and do not introduce new typed Phase1-4 records.

The first inspection's callee plus direct reentry visits30 of34 conditional
sites, with both outcomes at19. The second inspection visits9, with both
outcomes at4. That second metric excludes its prefix, which already executed
phase0; its other sites must not be called absent from the whole path.
Sites321, 376, 3133 and3188 are skipped by preceding slot8 normalization in
these zero-start runs. Other states, dependency branches, natural scheduling
and native presentation remain unresolved.

| C12 identity | SHA256 |
| --- | --- |
| V5 profile | `22c55d1a374995ebc19995ce9bbc9bcd118ac1d3bece846561ac0cba56bab54e` |
| Python source audit | `f71dd9d2bdbff58c8d89e7441526506577a1825117277b8fe4ae815483f9e07f` |
| Runtime report | `ed987806b332935d25ab133f634803211132228a94f7907be098f93aaf9551f8` |

The runtime group passes **3,502 assertions** and is registered in the normal
batch as `original event analysis GROUND C12`. Its 68 route variants bind
both original intro coordinates while keeping their shared control flow clear.

## Arrival: the grounds' own poll, declared (2026-09-14, Core 0.319.0)

C07 and both C12 calls were declared from the cascade's head `6044` with
`state_u16[21] = 0` seeded. Under Core 0.319.0 they start at the grounds'
entry `0` and supply the player's location `0` at the grounds' own
`Util(6,13)` poll, so the cascade is reached by walking there.
The grounds' walk loop at `5860..6044` has the floors' shape: with the
arrival mode `global_u8[3001] == 0` it runs `Util(6,8)`, copies `[17] =
[18]`, calls `GROUND.INC.MES` and polls at `5950` on a menu request
(`[17] == 65534`), otherwise polls at `5969`, copies `[21] = [18]`, waits
and leaves the loop unless both cells are `0xFFFF`; the location cascade
begins at `6044`, and location `0` - the grounds themselves - holds every
EVENT intro of this caller in one long cascade whose branches hand the root
to `MACHI.MES` on their own, so no route polls a second time.

Declared as `{GROUND.MES, 5969, [0]}`, spent by the prefix and the unbroken
run, with `global_u8[3001] = 0` and `[3009] = 0`, `state_u16[17] = [18] =
0xFFFF` in the baseline and the calendars of the earlier declarations:
`ground_c07_v12.json` (1620 checks), `ground_c12_v12.json` (the first
call, 1668) and `ground_c12_second_v12.json` (the second call at
`13935`, whose prefix executes the first, 1272) replace the v5
profiles with the same resumes - `MACHI.MES` at `12161` after 30 messages,
at `14563` after 54 and 6 - and with every variant of the earlier
declarations carried over (the drafter derives its own witnesses from the
guard's cells; the earlier matrices over the C word, the counter `[138]`,
the clock and `[3006]` are ported into the specs so no measured witness is
dropped). Supplying location `1` instead is rejected in each.

## The gate: location 0's exit belongs to the location (2026-09-15)

The owner's reading, measured: location `0` of the grounds is the way out to
the town map, and the map change after any of its events is the location's
exit, not the event's completion - the player who walks to the gate changes
map whether or not an event played. The cascade's last branch, `65738..66146`,
tests `state_u16[21] == 0` and nothing else: it clears `banked_u16[242]`,
loads the town's background for the clock band (`machin_3` before `6:00` and
from `18:00`, `machin_1` before `16:00`, `machin_2` before `18:00`), loads
`machi.mpc` and `machi.ccd`, invokes the registered definition `15`, presets
the entrance `state_u16[16] = 13` and hands the root to `MACHI.MES` at
`66123..66136`. Every event branch of location `0` ends in an inline copy of
that sequence - `GROUND.MES` carries 37 `MACHI` doors, each behind the same
ten-record tail and the same 13-byte handoff record (SHA-256 `496ee6fc…`, the
record the K09 outer bypasses already bind) - so a walk that sees no event and
a walk that sees C07 leave by the same door shape with the same preset.

The grounds have two more pieces of behaviour that belong to the map, not to
an event, both on the entry path before the location is polled: past `17:59`
(`825..837`) the grounds are closing - a two-line narration, `global_u8[533] =
1`, the same background and town loads, shared routine `28` and the handoff at
`1554..1567` - and on the first Saturday (`1650..1666`, `[4] == 6` and
`[2275]` clear) a two-line narration sets `[2275] = 1` and the walk goes on to
the poll.

That is declared separately from the events, as bypass variants of the arrival
groups: the V4 shape, accepted under the map schemas since Core 0.319.0, which
the builder now derives from a turned-away walk that leaves the caller by a
handoff to a script the spec names in `bypass_targets` (`MACHI.MES` here), and
which the validator replays from the grounds' entry with location `0`,
checking the exact handoff, the message count, the declared cells - the
profile cells' values and every cell the walk changed - and that the callee is
never dispatched; the qualifier adds a mutation, a wrong bypass count must
fail on "bypass message observation count". The deliberate witness is
`no-event-weekday-1` - Monday, otherwise the baseline - which passes no branch
of the cascade and leaves by the gate after 0 messages with the entrance
preset `[16] = 13` and every flag of the event untouched:
`ground_c07_v12.json` (1648 checks) declares `no-event-weekday-1` - the gate
after 0 messages; `ground_c12_v12.json` (1696 checks) declares
`no-event-weekday-1` - the gate after 0 messages; `ground_c12_second_v12.json`
(1296 checks) declares `no-event-weekday-1` - the gate after 0 messages.

## Regression scope

The final two original groups pass together in 27.520 s: 1,086 C07 and
3,502 C12 assertions. Project parsing and the repeated-call Core regression
pass. Compatibility checks reproduce the existing V2/V3 and all three V4
group runtime fingerprints and verify all thirteen catalog seeds' original/
package equivalence. Twenty-nine Python source-profile tests and 23 batch
runner tests pass; the profile tests preserve the V1-V4 source-report hashes.

A negative original-corpus check substitutes the exact typed K01 predicate
at6044 as C07's declared guard, with valid standalone acceptance/rejection
witnesses. Source audit succeeds, but the C07 execution traverses that
predicate's false edge. The runtime fails only the required accepting-guard
proof. This checks that a source-valid unrelated condition cannot qualify
the event's arrival.

These are focused automated checks with native presentation omitted. No full
original/native-executable batch or GUI verification is claimed. The new
observations preserve the original archive and Python's typed/opaque boundary.
