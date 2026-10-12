# GROUND event analysis: H17 and K09

This first GROUND group was measured on 2026-09-08. All coordinates below are
code-relative, with exclusive ends. The [analysis frontier](event_analysis_inventory.md)
identifies 16 EVENT intro sites in GROUND; the present group examines two.
Neither route is promoted to a complete catalog entry by this measurement.
The v1 measurements below are historical. The [v2 continuation](#v2-calendar-backed-continuation-and-completed-reentry)
now qualifies caller-to-callee-to-caller execution for explicit witness states.

## Original evidence and reproducibility

The source is the read-only authoritative `mes.arc`, SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
`config/event_catalog/analysis_groups/ground_h17_k09_v1.json` records exact
source hashes for GROUND, both callees, `DEF_MAIN.MES` and `LIBLARY.LIB`, as
well as the caller-prefix hashes and all witness states. This is a versioned
analysis profile (`kakyu_event_analysis_group/v1`), separate from a qualified
playback-catalog request. The event-specific data lives in the catalog directory;
the source auditor and runtime validator contain no event-ID branches.

| Entry | SHA-256 |
| --- | --- |
| `EVENTH17.MES` | `c9f8d43454eba2bf94036021b9ca02be4fc99433b1c9f5178d25970a0195f03c` |
| `EVENTK09.MES` | `d905231e056dfc1bb35122b031e907ec9261476032b336c36d751f89dcd1d590` |
| `DEF_MAIN.MES` | `f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0` |

`tools/audit_event_analysis_group.py` rebuilds actual Python Phase 1–4 handoffs
and verifies typed starts, exact ends, dispatch targets, conditions, prefix
hashes and declared terminal/boundary instructions. It certifies **source
records only**. `validate_event_analysis_group.gd` then executes the witnesses
using the shared bounded probe. Native presentation effects are omitted.

The profile hash is
`d5c7214a0567383ab9c1f605d101e1b3f590f3ddea1116893e87b6b809b98c48`.
The runtime report uses `kakyu_event_analysis_group_runtime/v1`, the shared
`mes_payload_fingerprint.gd` canonical hash and no dialogue or instruction bytes.
Its first report hash is
`707d3a34498daf0513e4ffbbf02da234420b45d6ae66789f7f689af3979570b3`.

## H17: condition confirmed, caller composition still bounded

The original `GROUND.MES:31450..31570` conditional has false target 32520;
the nested command-`0F` intro is `31600..31616 -> EVENTH17.MES`. Its local
predicate requires all of the following numeric state relations:

- `state_u16[21] = 0`, `1115 < state_u16[7] < 1511`,
  `1229 < state_u16[19] < 1501`;
- bank-zero `banked_u16[207] > 80` and `[208] > 80`;
- `global_u8[2284] = 1` and `[2098] = 1`;
- global fields 170, 174, 180, 184, 2278, 2332, 2225, 2124 and 2333 equal zero.

Twenty-five one-condition acceptance/rejection and boundary-value witnesses
pass, including both date/time boundaries and the 80/81 threshold. This proves
the local conditional, not eligibility from the outer scheduler.

The true arm writes `state_u16[2] = 10` at `31580..31585`, then invokes
registered definition 11 at `31585..31590`. DEF 11 in turn invokes DEF 12 at
`DEF_MAIN.MES:1167..1172`. With this group's fresh isolated state, the composed
prefix reaches the existing calendar-data dependency: the condition at
`1244..1256` reads `banked_u8[25][state_u16[1]] != 15`; `1256..1264`
increments slot 1 and `1264..1269` jumps back to 1244. The 10,000-command bound,
excluding inert provenance records, ends at 1244. The already-audited relative-byte/calendar backing needed by this
loop is described in [format and method](format_and_method.md); this group
does not yet initialize that backing. It does **not** establish an infinite
loop or broken behavior in the original engine.

Consequently the H17 callee runs are explicitly labelled
`isolated_callee_caller_unresolved`. They do not inherit the partially executed
prefix state and are not presented as end-to-end GROUND replay. Starting from
callee coordinate 0, sixteen combinations of initial slot 8 (0–3), flag 4000
(0/1) and flag 3006 (0/1) all produce 34 message observations and return at
`4042..4043`. Final global fields 3608 and 3635 equal 1; slot 2 equals 0.
The tested states cover both outcomes at conditional 651; conditional 229
and 271 are observed true, 500 false, while 326 and 381 are not reached.
Sixteen input combinations therefore do not imply sixteen distinct paths or
complete coverage of H17's six conditional sites.

Confidence is **confirmed** for the exact caller/guard records, witness
condition results and the isolated callee observations. Calendar-backed
caller-to-callee state, the completed-flag callee path, remaining branch states,
caller resume and native presentation remain unqualified.

## K09: carried state reaches the choice boundary

The local conditional is `GROUND.MES:64142..64167`, false target 64214;
its nested intro is `64177..64193 -> EVENTK09.MES`. It tests
`915 < state_u16[7] < 1511` and `global_u8[2326] = 0`.
Six positive/negative/boundary witnesses pass. The profile additionally supplies
slot 21 = 1, but starting at this local guard does not execute or qualify the
outer conditional at 63923 or the wider scheduler.

The accepted baseline runs the caller's two intervening source markers and
reaches the exact nested intro. The actual resulting state is passed into the
callee at coordinate 0. Execution observes 41 messages and stops at the
routine-40 selection instruction `EVENTK09.MES:3463..3468` (`0xD87`). The
tool has no declared choice contract here; no option is fabricated or selected.
The runtime report records `def_selection_boundary`, not a terminal or
completed route. Six of 22 conditional sites are reached before the boundary.

Confidence is **confirmed** for the local guard, exact prefix, carried-state
execution and choice stop. Choice results, later state effects, return and
caller resume remain unqualified. This is the next K09 analysis boundary.

## Instrument change and checks

Core 0.307.0 lets the shared route probe follow a registered definition into
another registered definition, then return to the exact outer resume with
argument slots and the persistent expression stack preserved. It retains
source order in signature rows and exposes structured stop details. Missing
definitions and unsupported outcomes still stop. Depth 8 and 128 total
definition invocations are **tool limits**, not native stack claims.

The registered-definition probe excludes commands `1F` and `17` from
its step budget through the explicit `exclude_provenance_steps` runner context.
Ordinary runner calls keep their existing record-count limit. This gives the
same bounded trace and final state with original bytes and with a package that
omits those inert provenance records. The existing D06 analysis-only route now
reaches DEF 12's bounded dependency on both sides, retaining its support status.

Synthetic checks cover nested order, suffix execution, temporary contexts,
missing definitions, recursion, total-call bounds and exact loop-stop evidence.
Python mutation checks reject altered schemas, identities, coordinates, ends,
outcome claims and witness data. The original group passes **155 assertions**:
31 local guard cases and 17 callee runs, with the H17 caller boundary retained.
The final focused batch passes **7/7**: project parsing, the existing event
runner and definition-call tests, the new nested-definition tests, this original
group, existing catalog analysis and all 13 seeds' original/package playback
equivalence. The full native-executable batch was not rerun for this unit.

```powershell
py tools/content_suite/run_headless_validation.py --elfimage <ELFIMAGE-directory> `
  --check "Godot project parse check" `
  --check "Godot test_mes_route_probe_definitions.tscn" `
  --check "original event analysis GROUND group"
```

## V2: calendar-backed continuation and completed reentry

The same authoritative archive was rechecked on 2026-09-08. The default profile
is now `config/event_catalog/analysis_groups/ground_h17_k09_v2.json`, schema
`kakyu_event_analysis_group/v2`, hash
`8eab42ca58f47ad9749aae5152290eafcfbc778df2e680e49c76faedcfc0c37c`.
V1 remains explicitly readable and reproduces its original 155 assertions and
report hash above. Upgrading requires supplying and auditing the new evidence;
no automatic migration invents a calendar context, choice or completion.

Core 0.308.0 allows the route probe to clone a supplied runtime state. Presets
overlay that private clone. Calendar bytes, alias policy and the bank-zero
native word baseline survive prefix, callee and suffix transitions without
entering authored state records. The caller's input state is never mutated.
The unbroken route is also executed from the original local guard: its written-value
state snapshot, ordered signature rows and message observations must equal the
three inspected segments. This rules out an apparent completion caused by
losing temporary contexts when segmenting the run.

### H17 caller continuation

The existing `mes_calendar_state.gd` projection uses `START.MES` SHA-256
`ba57bf666fbd9db9b3110f2bf1c70e80e11a35de00e82256aaaf35921c77038f`.
Its twelve rows, base `0x24A0` and sentinel 15 have table hash
`f21ee0fcb09e960046878e35ad0410aed88680f849ace471b713ef7a12525b4a`;
the original calendar and DEF12 validators independently pass. The profile
adds explicit initial slots 0 = 0 and 1 = 13 alongside the existing date/time
witnesses. These are controlled starting states, not proof of natural scheduler
eligibility. The actual `31585..31590` DEF11 call now returns through DEF12 and
reaches the confirmed `31600..31616` H17 intro. Slot 19 changes 1300 to 1310
in that executed prefix.

All sixteen input combinations now inherit actual caller state. Each observes
34 callee messages, returns at `4042..4043`, then resumes GROUND at 31616.
The caller adds 12 message observations. Its typed writes at `32123..32129`,
`32134..32140`, `32145..32151` and `32156..32162` set global fields 2278,
2332, 2333 and 2167 to 1 respectively. Thus the tested completion flags are
caller effects, not writes inferred from the callee's return alone.
The contextual runtime reaches `GROUND:32497..32510 -> MACHI.MES`.

With each final state, the original local intro condition rejects reentry.
Direct callee reentry takes the false arm at `EVENTH17:229..240` to 4048,
sets slot 2 = 1, observes no messages and returns at `4073..4074`.
Coverage including these reentries reaches four of six callee condition sites;
326 and 381 remain unvisited, and 271/500 remain one-sided observations.

### K09 choices and caller completion

The actual routine-40 boundary at `3463..3468` registers three definitions:
declarations `3261..3270`, `3314..3323`, `3387..3396`, with bodies ending at
3309, 3382 and 3453. V2 binds each body hash without storing its text or bytes.
The existing `kakyu_mes_routine40_choice_contract/v3` verifies the result
consumer and explicit values 1, 2 and 3 in slot 21. Comparisons at 3473 and 4729
select the first two arms; coordinate 6381 additionally checks result 3.
Choosing a value is an **analysis tool decision**. Native input, cadence and
the contract's omitted native effects remain unresolved.

Seven witnesses exercise all three options and result 3 with initial bank-zero
field 208 equal to 0, 1, 2, 3 and 4. All return at `7752..7753` and resume
GROUND at 64193. With field 208 initially zero:

| Explicit result | Callee message observations | Field 208 after callee | Field 208 after caller |
| --- | ---: | ---: | ---: |
| 1 | 60 | 1 | 2 |
| 2 | 72 | 2 | 3 |
| 3 | 61 | 0 | 1 |

Result 2 also sets global fields 2327 and 5250 to 1 at `5281..5287` and
`5450..5456`. Results 1 and 2 add 1 and 2 to field 208 at `4704..4719` and
`6356..6371`, respectively. Result 3 tests field 208
at `7656..7677`: the true arm subtracts **2** at `7677..7692`; the false
arm writes zero at `7697..7706`. The 0/1/2/3/4 witnesses cover both arms and
the threshold. This is a numeric storage observation, not a character-stat
interpretation.

The caller adds no messages and increments field 208 at `64247..64262`. Typed writes
at `GROUND:64203..64209`, `64214..64220`, `64225..64231`, and
`64236..64242` set global fields 2326, 2267, 2268 and 2209 to 1. The runtime
then reaches `64597..64610 -> MACHI.MES`. Every final state rejects the local
intro guard. Direct callee reentry sets slot 2 = 1, observes no messages and
returns at `7783..7784`. Sixteen of 22 conditional sites have at least one
observed outcome, including both outcomes at 7656. The six unvisited sites
and untested outcomes are explicit in the runtime report.

### Strict opaque tails and confidence

The actual Python Phase 1–4 handoffs retain GROUND tails `32433..32659` and
`64533..64635` as byte-preserving opaque boundaries (strict decoding reports
an empty command-08 destination expression). Their hashes are respectively
`e6f4695ecbcc9b7b896229d7a5d867061ecf58b5dff0a3ba48b928e9af4c7f55` and
`07276691f2322d2dde5626c9a7e09142594634c33b14e1fc05bb3ed23a2d3530`.
V2 binds each observed handoff span to its enclosing opaque tail and checks the
declared record's bytes with the current Python decoder. That does **not**
promote the tail to typed IR or permit execution starting at arbitrary bytes
inside it. The GDScript instrument must reach the exact handoff by executing
the complete caller path from the confirmed guard, under its bounded native
omission policy. The source audit labels those bytes as runtime observations
pending execution; the runtime report preserves that qualification.

Confidence is **confirmed for the controlled runtime observations and typed
source records described above**. Python strict-tail refinement, outer
scheduler eligibility, remaining branch states and native presentation remain
open. Neither route is a complete catalog entry or a playback-package claim.

V2 runtime report `kakyu_event_analysis_group_runtime/v2` hash:
`7f920ddc456fddb2736a81955b1d10301a1566cf5e53c1c451ec5347dd70e6fa`.
It passes **630 assertions**, 31 local guard cases and 23 variants, each with
segmented execution, an unbroken comparison and completed reentry checks.
The focused batch passes **11/11** in 56.136 s: parsing, five affected Core
tests, original calendar/DEF12 checks, this group, existing catalog analysis
and all 13 catalog seeds' original/package equivalence. Five analysis-group
Python tests, five inventory tests and 23 batch-runner tests also pass. The
historical V1 report reproduces exactly. No GUI or full native-executable
batch was run. EP-07 owns the remaining route work.

## 2026-09-09: branch qualification from caller state

The same authoritative archive and member hashes were reread for
`config/event_catalog/analysis_groups/ground_h17_k09_branches_v2.json`.
This additional `kakyu_event_analysis_group/v2` profile preserves the historical
profiles. Its hash is
`e67ced4aceded3a01d0f0827d5b42f3750b706737d8f3ec934a14269ad7f5432`;
the `kakyu_event_analysis_group_runtime/v2` report hash is
`869a0d87851c85e3db99527bfc0efb3d73f71bbbc89f33869c9396eb06afe9f8`.
The existing validator passes **1,317 assertions**, 31 local guard cases and
44 variants: H17's 16 earlier states, K09's 24 combinations of bank-zero
field 204 = 40/41/100/101, global field 3006 = 0/1 and choice result 1/2/3,
plus the four earlier choice-3 field-208 boundary states 1/2/3/4.
Each variant retains segmented execution, the unbroken comparison and
completed reentry checks. The 24 new combinations also seed slot 8 = 2 and
global field 4000 = 1 and assert their normalization to zero in the callee.

### Newly observed condition outcomes

The current Python instruction-v45 handoffs confirm these exact records in
`EVENTK09.MES`; the source-bound runtime witnesses establish their outcomes:

| Code-relative span | Condition or state effect |
| --- | --- |
| `224..245` | `40 < banked_u16[0][204] < 101`; both outcomes and both thresholds are exercised. |
| `245..255` | The true arm increments `global_u8[148]`. |
| `677..688`, `5380..5391` | `global_u8[3006] == 0`; both outcomes are now observed. |
| `617..623`, `5320..5326` | Write `global_u8[3005] = 15`. |
| `726..732`, `5429..5435` | The corresponding true condition arm writes `global_u8[3005] = 0`. |

Choice results 1/2/3 still observe 60/72/61 callee messages. All 28 K09
variants return at `7752..7753` and reach the previously bound GROUND handoff
`64597..64610`. These numeric storage results do not assign a character-stat
meaning to field 204 or counter 148.

The counter increment precedes the completed-state condition at `255..266`.
Consequently direct callee reentry with field 204 = 41 or 100 observes counter
148 changing **1 to 2**, then slot 2 = 1 and the no-message return at
`7783..7784`. The completed local caller guard still rejects dispatch. A
no-message early return must therefore not be described as having no state
effects.

### Why some branches remain one-sided or unvisited

H17 writes slot 8 = 0 at `266..271`, immediately before the condition at
`271..281`. K09 does the same at `292..297`, `3786..3791` and
`6709..6714`, immediately before conditions 297, 3791 and 6714.
Those conditions take their true arm in the qualified paths; H17's conditions
326/381 and K09's 352/407, 3846/3901 and 6769/6824 are not reached.
Changing the caller's initial slot 8 cannot undo these intervening literal
writes. This is a statement about the confirmed entry paths under the
instrument's bounded native-omission policy, not global unreachability in the
original program.

The initial shared routine 28 also reaches `LIBLARY.LIB:756..762`, which writes
global field 4000 = 0. Its original bytes were checked with the current Python
decoder, and the caller-origin trace records the reset of the seeded value 1.
However, the full Python library handoff retains this coordinate inside its
opaque tail beginning at 26. The reset is a source-checked contextual runtime
observation, **not a newly typed library handoff region**. The field-4000
conditions remain observed false within the qualified execution policy;
omitted native effects are not thereby established.

Finally, K09 condition `6381..6391` tests result 3 after results 1 and 2 have
selected their earlier arms. The existing choice contract admits only 1/2/3;
injecting result 4 to force a false outcome would not be a valid choice witness.
Confidence is **confirmed for the exact source records and controlled
observations above**, with the library opaque qualification preserved. Outer
GROUND choice and scheduler eligibility remain next work, and neither route
is promoted to a complete catalog entry.

## 2026-09-09: K09 outer choice and bypass paths

The authoritative archive was reread for
`config/event_catalog/analysis_groups/ground_k09_outer_v4.json`, schema
`kakyu_event_analysis_group/v4`. Its profile hash is
`683b98edaedf00f172206f35e6d63a4ea95e56ebb7dd0391589877f69d8f612b`.
The refreshed `kakyu_event_analysis_group_source_audit/v4` passes with hash
`59d29dbca6f2b0e0b5194aeac9cd40991bb23bd080723f79bdffdf9d54d8fbda`.
This is source-binding evidence; runtime assertions remain a separate check.
Earlier v1/v2 profiles and measurements above remain historical references.

The permanent profile contains **55 variants**: the existing 28 successful
K09 states, 24 alternatives selecting outer result 2, and three outer-result-1
states rejected by the local K09 guard. Exploration ran 58 states; the three
additional accepted local-guard witnesses duplicate successful coverage and
are not additional permanent variants. The six one-step local guard cases
remain separate from the 55 route variants.

All four handoffs are rebuilt with the actual `python_phase1_4` producer and
instruction-v45 schema. No producer-normalized comparison hash replaces them:

| Original entry | Actual Python handoff SHA-256 |
| --- | --- |
| `GROUND.MES` | `12ef35192a66806dc97b9c983c972969f31958fd1ff3c8b0878bca7ef0ef5dfb` |
| `EVENTK09.MES` | `2b221aa1a1b94b948515c201ff1c82e41c603d5120b527b984fecc733fdc6f92` |
| `LIBLARY.LIB` | `7675c0d1270957c1a144135f10db058a3ef534d10a035fc51b0612ed66f96728` |
| `DEF_MAIN.MES` | `e5af49a366a927542b24e9d14a961298399bbe28026b1aa744a21247a21a221e` |

### Origin, definitions and selection consumer

The route now starts at the typed GROUND preparation record `63807..63812`,
before the two choice definitions and routine 40 at `63908..63913`. The
preparation span `63807..63913` has SHA-256
`056ef5b005ab1cc1c994373524ed12f096b77d46261eded0dffc003f582a248b`.
The profile's prefix fingerprint covers the entire origin-to-dispatch span
`63807..64193`, SHA-256
`22ea095dcaf5b18fafdb6daee07c400b78c9adaf67f185ecf3dc33db8c9e4454`.
The nested K09 call remains the exact typed `64177..64193` record, SHA-256
`36396bb097c7c3b516363a9ddb765ecdb4625913f05f6076d3f956c4b37c8680`.

| Definition ID | Declaration | Body span | Body SHA-256 |
| --- | --- | --- | --- |
| 0 | `63817..63826` | `63826..63845` | `832f39763923347b342d21acee86e26d427d4533e0dda364f8938c6c1a04f76f` |
| 1 | `63850..63859` | `63859..63878` | `db77b0763e760bae748565442837203cffd4dddc5ba0d56efd15731c673ff0ba` |

The source-bound routine-40 contract admits results **1 and 2** in
`state_u16[21]`, resuming at 63913. Its first comparison is the typed
`GROUND:63923..63933` predicate `state_u16[21] == 1`, with false target
64620; its first option's executable entry after provenance is 63938.
Result 2 reaches the contextual `64620..64630` comparison against 2, with
false target 65733. That second comparison is inside an existing Python
opaque tail, as qualified below. Both definitions and their exact bodies are
fingerprinted without retaining their text in the profile.

The original local K09 guard remains `64142..64167`, false target 64214:
`915 < state_u16[7] < 1511` and `global_u8[2326] == 0`. The profile separately
declares the inner `EVENTK09:3463..3468` choice contract established above.
Selections identify both owner entry and boundary, so the two uses of slot 21
are applied at their own original calls. Explicit result selection remains an
analysis tool decision; this does not establish native input semantics.

### Carried state and the meaning of bypass

The profile uses a fresh sandbox, with the existing K09 baseline: slot 7 =
1201, slot 21 = 1 and global field 2326 = 0, plus each variant's writes. It
does not require H17's START calendar projection. Executing outer result 1
actually selects slot 21 = 1, observes four caller messages, then evaluates
the local guard and dispatches K09. Exploration also started slot 21 at 9 to
verify that the choice writes 1 or 2 before its consumer runs. The permanent
profile retains the historical baseline rather than relying on that extra
initial value.

Successful paths carry the actual prefix state into K09 and retain the earlier
28-state matrix. Their inner results 1/2/3 observe 60/72/61 callee messages;
the entire path from 63807 observes **64/76/65** respectively. The callee
returns at `7752..7753`, the caller resumes at 64193, and the path reaches
`GROUND:64597..64610 -> MACHI.MES`. Exploratory comparisons found identical
ordered trace rows, message observations and written-value snapshots for the
unbroken path and the inspected prefix/callee/suffix composition. Splitting
at outer choice preparation and resuming after its explicit result write also
reproduced the unbroken path, including bypasses.

Outer result 1 with slot 7 = 915, slot 7 = 1511, or global field 2326 = 1
takes the local guard's false edge to 64214. These three paths **never invoke
K09**, observe four caller messages and still reach the same MACHI handoff.
The writes at `64214..64220`, `64225..64231`, `64236..64242` and
`64247..64262` therefore still set global fields 2267, 2268 and 2209 to 1 and
increment bank-zero field 208. The separate write to global field 2326 at
`64203..64209` is skipped. In the two date-rejection witnesses field 2326
remains zero; the already-set witness retains 1. **The shared suffix flags or
field-208 increment alone do not prove that K09 ran or completed.**

Outer result 2 bypasses the local K09 guard and the callee entirely. Its 24
permanent witnesses combine bank-zero field 208 = 0/1/2, global field 2847 =
0/1 and slot 19 = 599/600/1600/1800. All observe 16 messages and reach
`GROUND:65715..65728 -> MACHI.MES`. The typed condition at `65330..65351`
tests field 208 greater than 1 and nonzero. The true write at `65351..65366`
subtracts 1; the false write at `65371..65380` writes zero. Thus these inputs
produce 0/0/1 respectively. The witnesses exercise both outcomes at 64901
and 65330 and the time branches at 65399, 65466 and 65533. These remain
numeric state observations without an inferred gameplay label.

### Opaque observations and remaining coverage

The earlier GROUND opaque tail `64533..64635`, SHA-256
`07276691f2322d2dde5626c9a7e09142594634c33b14e1fc05bb3ed23a2d3530`,
contains both the result-1 handoff and the result-2 comparison at 64620.
The result-2 handoff belongs to the separate tail `65651..66724`, SHA-256
`af84a1c8683b91ddf7f4d7801a4501b35e40079267da5763c64124e81398f2cd`.
Both handoff records have SHA-256
`496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047`.
They are exact original spans reached by the bounded contextual instrument;
neither tail is promoted to typed Python IR. The alternative comparison was
also checked directly with the current Python decoder during exploration,
including its numeric predicate and false target. That source check does not
make it an independently accepted execution entry or a typed handoff record.

Confidence is **confirmed for the exact typed records and controlled
source-bound observations described here**. The origin is an earlier confirmed
preparation coordinate, but the scheduler path before 63807 remains unresolved.
Other branch states, the strict opaque-tail refinements and native input,
presentation and timing remain open. The v4 qualification is
`caller_continuation_observation`; these paths neither promote K09 to a
complete catalog entry nor establish playback-package equivalence.

The permanent V4 runtime group passes **1,354 assertions**, all 55 route
variants and six local guard witnesses. Its report hash is
`117639c3f5d30527dd703b1e27f30e2a6768da7cec38a3866cab79779c135832`.
Successful routes enforce segmented/unbroken trace, message and written-state
equivalence; every bypass requires the exact handoff and no K09 dispatch or
execution. The batch entry is `original event analysis GROUND K09 outer choice`.
The combined 12-check regression and legacy identities are recorded with the
[K01/K_PIC continuation evidence](ground_k01_kpic_analysis.md).

## 2026-09-15: location 0 is the gate; its exit belongs to the location

The owner's reading of the grounds, measured with the arrival groups: the walk
loop at `5860..6044` polls the player's location once, and the cascade that
follows is one branch chain per location - `0` is the way out to the town map,
`1` the school building (`FLOOR1.MES` at `66535`), `2` the scene `25C.MES`,
`3` `26M.MES`, `4` `24M.MES`, `5` `23M.MES`. Location `0` holds 29 branches:
K01 (twice), K_PIC, C07, C12, two C_TALK stages, K02, G_TALK, two G_PIC
afternoons, G08, F02, H17, H15, B_PIC, two P_PIC, A07, N_PIC, F_PIC, A_PIC,
E_PIC, I_PIC, G_PIC, C_PIC, H_PIC, the K_PIC/K09 evening, and last the bare
exit `65738..66146`, which tests the location and nothing else. Every one of
those branches that ends in the grounds ends in an inline copy of the exit
sequence (clear `banked_u16[242]`, the town background by clock band,
`machi.mpc`/`machi.ccd`, definition `15`, the entrance preset `state_u16[16] =
13`, `jump` to `MACHI.MES`; 37 such doors in the file, one 13-byte handoff
record repeated), and the three root handoffs (G08, F02, A07) carry it inside
the callee. The entry path has two more pieces of the map's own behaviour:
past `17:59` the grounds are closing and the player is sent to the town at
`1554..1567` before any location is polled (`[533] = 1`), and the first
Saturday plays a two-line narration (`[2275] = 1`) before the poll.

The map change after an event is therefore the location's exit, not the
event's completion, and it is declared separately from the events: each
location-0 arrival group carries bypass variants - walks the guard turns away
that leave by a door of the map's own, replayed by the validator from the
grounds' entry with location `0` and checked never to dispatch the callee (see
[GROUND C07 and
C12](ground_c07_c12_analysis.md#the-gate-location-0s-exit-belongs-to-the-location-2026-09-15);
16 bypasses across the eight groups). The deliberate witness in each is a
no-event state - Monday for the Saturday-gated events, a date or clock outside
the window for H15 - which leaves by the gate with the preset and the event's
flags untouched. The historical groups (H17/K09, H01/H02, K01, K_PIC) keep
their origins; K09 outer's 27 bypasses already bound this exit's record from
`64597`.

## 2026-09-15: H17 and K09 declared from the arrival, beside the v2/v4 groups

The groups above start at H17's guard (`31450`), at K09's local guard
(`64142`) or, for the outer choice, at `63807` after K_PIC. Read from the
grounds' entry with location `0` - the way the player reaches them, as
leaving-school events - each sits behind a branch of the location-0 cascade.
H17's branch is its own guard, `31450..31570`: location `0`, `11/16..3/10`,
`12:30..15:00`, the H and K words above `80`, `[2284] = 1`, `[2098] = 1`, nine
flags clear, and no weekday conjunct. K09's is the evening branch
`62874..62959`: location `0`, Saturday, `14:31..15:00`, the K word above `80`,
`[351] = 8` and seven flags clear; its body runs K_PIC, asks the grounds' own
question at `63908`, tests the local guard `64142..64167` (`9/16..3/10`,
`[2326]` clear) and calls K09 at `64177`. `[351]` is the entry path's draw -
`rand(10)` at `218`, forced to `8` at `315` when the K word is above `90` with
`[2284] = 1` and `[180]`, `[184]`, `[187]`, `[2228]`, `[2266]`, `[2326]`,
`[2225]` clear - so the K word above `90` is what makes K09's evening certain;
below that the evening belongs to the draw (the sandbox's seeded draw gives
`7`, H_PIC's slot).

`ground_h17_arrival_v12.json` (859 checks) is declared beside the v2 groups:
origin at the grounds' entry `0`, location `0` at the poll `5969`, one
rejecting witness per conjunct, Monday `12/01` `13:00` as the baseline so no
Saturday branch of the cascade comes first, the branches group's 16 variants
ported, the same return and the same `MACHI` door at `32497` (12 messages
after the return). Bypasses: 2 by the gate.

`ground_k09_arrival_v12.json` (1743 checks) is declared beside the v2 route
and the v4 outer group: one route per K09 answer
(`ground-k09-arrival-result1`, `ground-k09-arrival-result2`,
`ground-k09-arrival-result3`), the grounds' question answered `1`, Saturday
`12/01` `14:40` with the K word at `91` as the baseline, K_PIC executed inside
the prefix, the local guard passed, the same `MACHI` door at `64597`. The v4
group's variants are ported with their K09 answer pinned; they write the K
word to `0`, which the evening branch rejects, so from the arrival they are
the gate, not K09 chains - the v4 group keeps them as what they were from
`63807`. Its answer-2 bypasses (the grounds' question answered `2`, the exit
at `65715`) are not portable, the spec fixes one answer, and stay declared
there only. Own witnesses: the K word at `80` rejects the branch, at `90` the
branch depends on the draw, the callee's word arms at `100`/`101`, and the
local guard's witnesses: the dates `9/15` and `3/11` pass the branch, run
K_PIC and the question, fail `64142` and leave by K09's own exit at `64597`
without K09 - the v4 local-guard bypasses reached from the entry - while
`[2326] = 1` never reaches the evening branch at all, since the entry path's
override needs it clear: the draw decides and the walk is the gate. Bypasses:
`ground-k09-arrival-result1`: 13 by the gate after the first-Saturday
narration, 1 by the gate, 2 by K09's own branch exit at `64597` (the local
guard turned them away); `ground-k09-arrival-result2`: 8 by the gate after the
first-Saturday narration; `ground-k09-arrival-result3`: 12 by the gate after
the first-Saturday narration.
