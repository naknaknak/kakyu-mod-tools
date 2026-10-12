# Caller-derived route classification

`config/event_catalog/route_classification_v1.json` adds a source-bound index
beside the playable catalog. Its 169 entries cover all 130 EVENT-named literal
targets (one of them, `EVENTA13`, named only inside an opaque tail until Core
0.316.0 read that tail), one EVENT entry nothing names, and 38 non-EVENT direct dependencies or catalog-declared shared
members. This is an evidence index, not 169 playable routes.

| Scope | Playable event | System script | Unreachable stored route | Unresolved route |
|---|---:|---:|---:|---:|
| 129 EVENT-named strictly decoded targets | 11 | 0 | 0 | 118 |
| One EVENT target named only in an opaque tail | 0 | 0 | 0 | 1 |
| One EVENT entry nothing names | 0 | 0 | **1** | 0 |
| 38 non-EVENT dependencies | 0 | 37 | 0 | 1 |

The eleven playable entries retain six complete/five partial playback statuses.
(The table and this paragraph are the 2026-09 state before EP-10 unit 5; since
2026-09-21 the classifier reads the generated catalog's `minimal_playback` rows as
playable events, giving 129 playable events / 34 shared system scripts / 1 unreachable stored route / 3 unresolved routes over 167 rows - see the 2026-09-21 paragraph at the end; the current split, at catalog revision 39, is 151 / 15 / 1 over the same 167 rows, see the 2026-10-05 paragraph.)
Core 0.305.0 qualifies EVENTJ04 with four caller-qualified presets and a
callee-owned MACHI terminal. Its partial support is a bounded analysis run,
with native presentation omitted; see [J04 evidence](eventj04_route.md).
EVENTD05 and EVENTD06 remain analysis-only. Others retain an unresolved reason.
No duplicate-route or unreachable-route meaning is confirmed; 17 EVENT targets
carry multiple intro sites and remain candidates.

## Shared scripts, by measurement rather than by name

Updated 2026-09-09. Four entries were system scripts because the catalog
declared them a shared library, definition registry or nested presentation
dependency: LIBLARY.LIB, DEF_MAIN.MES, B_PIC.MES and D_PIC.MES. That left 34
non-EVENT dependencies unresolved even though the archive says plainly what
they are.

The product goal's third class is a "shared system, map, library, or
presentation script rather than an event", and **shared** is measurable. Over
all 130 EVENT-named targets, the distinct-caller count is 1 for 126 of them and
2 for the remaining four (`EVENTL10`, `EVENTM03`, `EVENTM10`, `EVENTM17`).
**Two is the archive-wide maximum for anything the archive dispatches as an
event.** The classifier derives that maximum at run time and fails closed if it
moves, so the threshold is a measurement rather than a chosen number.

A non-EVENT dependency dispatched from more distinct callers than that maximum
is therefore shared in a way no event in this archive is. 33 rows qualify, and
each records its dispatch form, which is uniform per entry:

| Form | Rows | Meaning | Examples |
|---|---:|---|---|
| `nested_call_only` | 26 | command-`0x0F` only, so the caller resumes: a shared presentation or conversation callee | `A_PIC`-`Q_PIC`, `G_TALK00`-`G_TALK90`, `G_PROMIS`, `A_INTRO` |
| `root_handoff_only` | 7 | command-`0x0E` only, so it replaces the root: a shared destination or map | `MACHI` (147 callers), `GROUND`, `FLOOR1/2/4/5`, `44C` |

The two entries the catalog already called nested presentation dependencies,
`B_PIC.MES` (31 callers) and `D_PIC.MES` (38), sit inside the same band, which
is the control for the rule. `05C.MES` has exactly two distinct callers — the
EVENT maximum — so the rule does not reach it and it stays unresolved. That is
the boundary working, not a gap. (Superseded 2026-09-23 by owner ruling: a
non-EVENT script that is the measured caller of an analysis group is a system
script, which classes `05C.MES` as the place script hosting EVENTI21; see the
2026-09-23 paragraphs below.)

This promotes no entry to playable and claims nothing about what any of these
scripts does. It records that the archive uses them as shared parts.

## Naming evidence and its scope

Updated 2026-09-09. Every row now records **where** its intro evidence was
found, because the two are not the same kind of claim:

| `intro_scope` | Rows | Meaning |
|---|---:|---|
| `strict_decode` | 150 | named by a record the strict aligned decoder reads |
| `strict_decode_and_opaque_tail` | 15 | both; the tail records are additional caller sites |
| `inline_script_execution` | 2 | named by a command-`0x0D` inline execution site, not a dispatch record |
| `opaque_tail` | 1 | named only inside a preserved opaque tail |
| `none` | 1 | nothing in the archive names it |

This replaced two rows whose previous reason was factually wrong.
`EVENTA13.MES` and `EVENTL09.MES` both read "No literal caller exists;
shared-routine, definition, address-table and host reachability remain
unaudited." That audit has since been run —
[Dispatch Naming Reachability](dispatch_naming_reachability.md) — and:

- **`EVENTA13.MES` has a caller.** `FLOOR4.MES:0x0E4C..0x0E5C` is a
  command-`0x0E` root handoff naming it, inside an opaque tail. Its scope is
  now `event_named_tail_target`. It stays `unresolved_route`: the record is
  byte-exact and independently decoded, but the strict decoder does not read
  it, so the dispatch is not shown to execute.
- **`EVENTL09.MES` is the only entry with no naming evidence at all**, and its
  reason now says what was checked rather than what was not.
- **`LIBLARY.LIB` and `DEF_MAIN.MES`** carry the two `START.MES` inline
  execution sites as intro evidence instead of an empty list.

The `event_target_count` field keeps its meaning — strictly decoded EVENT
targets, 129 then and 130 since Core 0.316.0 — and `event_named_tail_target_count`, `opaque_tail_dispatches` and
`inline_script_executions` are new fields beside it. The 650 opaque-tail
records add no non-EVENT dependency and no new multi-intro candidate; the
classified pool is the same 169 entries it was.

## What the analysis groups already measured

The committed profiles under `config/event_catalog/analysis_groups/` (one
hundred and twenty-eight when this section was written; one hundred and
thirty-eight counted on 2026-09-16, the ten arrival groups added beside
existing groups on 2026-09-14/15 binding no new entry)
bind 156 of the index's entries, and the index now carries that as per-row
evidence — group id, schema, payload hash and the role the profile gives the
entry (`measured_caller`, `measured_callee`, `measured_terminal`,
`source_member`). Every profile's archive identity and every member hash is
re-checked against the original before it is used.

One hundred and nineteen EVENT entries are affected: `EVENTA01`, `EVENTA02`, `EVENTA03`, `EVENTA04`, `EVENTA05`, `EVENTA07`, `EVENTA08`, `EVENTA10`, `EVENTA13`, `EVENTA17`, `EVENTA19`, `EVENTA20`, `EVENTA22`, `EVENTC01`, `EVENTC02`, `EVENTC03`, `EVENTC04`, `EVENTC05`, `EVENTC06`, `EVENTC07`, `EVENTC08`,
`EVENTC10`, `EVENTC11`, `EVENTC12`, `EVENTC17`, `EVENTC18`, `EVENTC21`, `EVENTD05`, `EVENTD06`, `EVENTE01`, `EVENTE03`, `EVENTE04`, `EVENTE05`, `EVENTE10`, `EVENTE11`, `EVENTE15`, `EVENTE18`, `EVENTF01`, `EVENTF02`, `EVENTF03`,
`EVENTF06`, `EVENTF07`, `EVENTF17`, `EVENTF20`, `EVENTF22`, `EVENTG01`, `EVENTG02`, `EVENTG04`, `EVENTG08`, `EVENTG11`, `EVENTG14`, `EVENTG21`, `EVENTH01`, `EVENTH02`, `EVENTH04`, `EVENTH06`, `EVENTH07`, `EVENTH10`,
`EVENTH11`, `EVENTH15`, `EVENTH16`, `EVENTH17`, `EVENTH18`, `EVENTH19`, `EVENTI04`, `EVENTI05`, `EVENTI09`,
`EVENTI10`, `EVENTI13`, `EVENTI14`, `EVENTI16`, `EVENTI21`, `EVENTI23`, `EVENTI24`, `EVENTJ01`, `EVENTJ07`, `EVENTJ09`, `EVENTJ11`, `EVENTJ14`, `EVENTJ15`, `EVENTJ18`, `EVENTJ19`, `EVENTK01`, `EVENTK02`, `EVENTK06`, `EVENTK09`, `EVENTK13`, `EVENTK14`, `EVENTK15`,
`EVENTL02`, `EVENTL03`, `EVENTL04`, `EVENTL05`, `EVENTL06`, `EVENTL07`, `EVENTL08`, `EVENTL10`, `EVENTL11`, `EVENTL13`, `EVENTL16`, `EVENTL18`, `EVENTL20`, `EVENTL25`, `EVENTM01`, `EVENTM03`, `EVENTM04`, `EVENTM05`, `EVENTM06`, `EVENTM08`, `EVENTM09`, `EVENTM10`,
`EVENTM11`, `EVENTM14`, `EVENTM15`, `EVENTM16`, `EVENTM17`, `EVENTM18`, `EVENTM20` and `EVENTQ01` (`EVENTM11` as a member
of the M10 groups only: it is the callee's static dependency and no measured
path reaches it; `EVENTL18` as a member of the FLOOR4 F03 group only: the
floor names it past its own exit, no measured path reaches it, and its site
stays unqualified - corrected 2026-09-14: the site is behind a typed guard in
map arm 4 and is declared as `floor4_l18_v6`, see the FLOOR4 group doc). They stay `unresolved_route` — an
analysis group is a bounded observation and does not promote catalog playback —
but their confidence is now `analysis_group_measured_semantics_unresolved`
rather than `structural_confirmed_semantics_unresolved`, and their reason names
the group. The distinction the index could not previously make is between an
entry that is unresolved and unmeasured and one that is unresolved but measured.

Confidence across the 169 rows: 49 `qualified_catalog_scope`, 113
`analysis_group_measured_semantics_unresolved`, 7
`structural_confirmed_semantics_unresolved`. Those counts move whenever a group
lands: each of the nine 44M profiles promoted its own event, and they also
promoted the presentation callees and roots they bind - `A_PIC`, `F_PIC`,
`H_PIC`, `I_PIC`, `44C` and `MACHI`. That is the point of consuming the profiles
rather than restating them. The `EVENTL09` classification on 2026-09-10 had
already moved one row into `qualified_catalog_scope`, so the split was
49/21/99 before the first 01M group landed, not the 48/21/100 recorded then;
the 01M I16 group then moved `EVENTI16` to measured, giving 49/22/98, and
the 01M G11 group moved `EVENTG11`, giving 49/23/97, and the 01M D05 group
moved `EVENTD05` and bound `D_PIC`, giving 49/24/96 over 39 bound entries;
the 01M L03 group moved `EVENTL03` and bound `L_PIC`, giving 49/25/95 over 41;
the three FLOOR5 chain groups moved `EVENTM18`, `EVENTH10` and `EVENTH16` and
bound `FLOOR5` and `FLOOR4`, giving 49/28/92 over 46; the FLOOR5 G21 group
moved `EVENTG21`, giving 49/29/91 over 47; the FLOOR5 F01, E15A and E15B
groups moved `EVENTF01` and `EVENTE15`, giving 49/31/89 over 49; the 18M C11
and I05 groups moved their events, giving 49/33/87 over 51; the 18M K13 and
L04 groups moved theirs and bound `H_PIC` and `K_PIC` again, giving 49/35/85
over 53; the 18M I09 and M16 groups moved theirs and bound `I_PIC` and
`M_PIC`, giving 49/37/83 over 56; the 44C I24 and L25 groups moved theirs and
bound `44C` for the first time, giving 49/39/81 over 58; the 44C M03 group
moved its event, giving 49/40/80 over 59; the 44C M17, M10A and M10B groups
moved `EVENTM17`, `EVENTM10` and the member `EVENTM11` and bound `O_PIC`
again, giving 49/43/77 over 62; the 17M C10 group moved its event and bound
`A_INTRO` for the first time, giving 49/44/76 over 64; the 17M A10 group moved its
event, giving 49/45/75 over 65; the 17M A02 group moved its event, giving
49/46/74 over 66; the 17M A20A and A20B groups moved theirs, giving 49/47/73 over
67; the five 23M groups moved their five events and bound `E_PIC` and `P_PIC`
for the first time, giving 49/52/68 over 74; the three 21C groups moved their
three events, giving 49/55/65 over 77; the four 26M groups moved their four
events, giving 49/59/61 over 81; the four MACHI groups moved theirs, giving
49/63/57 over 85; the three 03C groups moved their two events and bound
`J_PIC` for the first time, giving 49/65/55 over 88; the three 07M groups moved
their three events, giving 49/68/52 over 91; the three 11M groups moved their
three events, giving 49/71/49 over 94; the 15C I10 group (answer 2 only, by the
2026-09-12 ruling) moved its one event, giving 49/72/48 over 95; the three 25C
groups moved their three events, giving 49/75/45 over 98; the three 30C groups
moved their one event and bound `FLOOR2`, `G_PROMIS`, `G_TALK00`, `G_TALK30`, `G_TALK40`, `G_TALK50`, `G_TALK60`, `G_TALK70`, `G_TALK80`, `G_TALK90` for the first time, giving 49/76/44
over 109; the three 35M groups moved their three events, giving 49/79/41 over
112; the two 05M groups moved their two events and, as L06's measured door,
`05C.MES` - the first non-EVENT entry to become analysis-group measured -
giving 49/82/38 over 115; the two 06C groups moved their two events, giving
49/84/36 over 117; the two 09M groups moved their two events, giving 49/86/34
over 119; the two 27C_EV groups and the FLOOR4 F03 group moved their three
events - and `EVENTL18` by membership only - and bound `Q_PIC` for the first
time, giving 49/90/30 over 124; the 19C L05, 27C1A C03 and 29C A05 groups - the first one-intro
callers - moved their three events and bound `FLOOR1` for the first time,
giving 49/93/27 over 128; the 34C L20, 33C A04, 32C I23 and 10C D06 groups moved their four
events, giving 49/97/23 over 132; the 20C L16 and 28C L13 groups moved their two events, giving 49/99/21
over 134; the 05C I21, 27C3B A01, REIKO42 F07, 06M K06 and 16M Q01 groups - the first
qualified with the route toolchain - moved their five events, giving 49/104/16
over 139; the eight nested calls - 10M M04, 19M M15, 21M M08, 43C M05, 46M J09, A_DATE5
A17, H_DATE3 H19 and K_DATE3 K15, the toolchain's first caller-continuation
routes - moved their eight events, giving 49/112/8 over 147; the 44M J11 group,
qualified once Core 0.316.0 could read its callee's second body, moved its one
event, giving 49/113/7 over 148; the 15C C06 and E11 groups, the first declared on the v10
caller-menu-loop resume (Core 0.317.0), moved their two events, giving 49/115/5 over 150; the
FLOOR4 A13 and L18 and FLOOR1 I04A, I04B and I04C groups - the sites Core 0.316.0 uncovered in the
floors' arm switches - moved `EVENTA13` and `EVENTI04` (L18 was already measured by membership),
giving 49/117/3 over 152, with 01M's H07, M06 and M09 the three structural rows left; the 01M H07,
M06 and M09 groups, the first declared through Core 0.318.0's map-location contract (the train's
boarding), moved their three events and bound `TRAIN` for the first time, giving 49/120/0 over 156 - no
structural row is left.

Re-derived on 2026-09-13 under Core 0.316.0: the strict decode now carries
every dispatch the opaque tails held, so the 169 rows keep their classes and
confidences (49/112/8 over 147 bound) while sixteen rows lose the
`opaque_tail` half of their intro scope, nine absorb their former tail targets
into `literal_targets`, and `EVENTA13.MES` moves from `event_named_tail_target`
to `event_named_target` with `structural_confirmed_semantics_unresolved`
unchanged; `event_target_count` is 130 and `opaque_tail_dispatches` 0.

Refreshed on 2026-09-19 after the 44M B14 group: 158 bound entries, the same
49/120/0 split; `EVENTB14.MES` and `B_PIC.MES` newly bound by the group
(EVENTB14 keeps its `qualified_catalog_scope` class), no row moved.

Refreshed on 2026-10-02 for catalog revision 32 (TD-36, `todo/code_health.md`).
The classification had last been refreshed on 2026-09-24; the EP-12 rows landed
at `0cf38bd`..`14b7157` (the twelve date flows and twelve promise groups)
without a refresh, so the tracked file no longer matched revision 32. The
refresher printed `moved: []` (it reports confidence moves only), but the
class split changed: `A_PIC.MES` .. `J_PIC.MES`, `L_PIC.MES` (11 entries) and
`G_PROMIS.MES` move `system_script` -> `playable_event`, because a
`minimal_playback` row now reaches each (the `if playable:` rule comes first;
`K_PIC.MES` is the precedent). The split is now **143 playable events / 23
shared system scripts / 1 unreachable stored route** over 167 rows, confidence
unchanged (167 `qualified_catalog_scope`), 166 bound. Besides the 12 class moves (and their `reason`), the
delta is the catalog hash rebind, `catalog_routes` for the new rows (K_PIC.MES
gains three), the `analysis_group_evidence` of the same 13 entries gaining the
new date and promise groups, and `unreferenced_structure_sha256` (the
machine-independent v2 report of the same date). `G_PROMIS.MES` is the only
`*_PROMIS.MES` with a classification row; the other eleven are neither
EVENT-named nor reached from an EVENT caller, so the classifier has no row for
them. The refresh started from the 131/35/1 state committed at `4873dc7`
(EVENTM11 had left `unresolved_route` after the record above without this
document recording the step); the 130/35/1 splits quoted above are the
historical records of their dates.

Brought to catalog revision 39 on 2026-10-05 (EP-12 TALK follow-ups). This page
stopped at revision 32 while the installed file did not: each later unit
regenerated `config/event_catalog/route_classification_v1.json` with its catalog
(revisions 33-39, `d4295fd`, `ab41d16`, `6f96c56`, `eca7725`, `2eb1127`, `7fff4af`,
`19a3853`) and only the class split of the last moved, so the file was current and
this page was not. Nothing is regenerated by this entry: a regeneration into scratch
(`tools/refresh_route_classification.py`, no `--install`) on 2026-10-05 reproduced the installed
file exactly, with no class, confidence or binding move against `HEAD`. The split is now
**151 playable events / 15 shared system scripts / 1 unreachable stored route**
over the same 167 rows (confidence unchanged: 167 `qualified_catalog_scope`;
166 bound; `event_target_count` 130). What each revision did to the file:

| Revision | Unit | Change to the 167 rows |
|---|---|---|
| 33, 34 | EP-12 leftovers, date profiles v5 | `analysis_group_evidence` payload hashes re-bound (`D_PIC`, `L_PIC`, `TRAIN`; then the nine `?_PIC` of the v5 date profiles and `TRAIN`), `catalog_routes` of `D_PIC` and `L_PIC`; no class or membership change |
| 35 | heroine J's album | none (the catalog hash rebinds) |
| 36 | the other twelve album menus | `H_PIC`, `M_PIC`, `O_PIC` and `P_PIC` gain the `source_member` bindings `miyuki-m-scene`, `tina-m-scene`, `nana-m-scene` and `miko-m-scene` |
| 37 | the 13 recollection ladders | `O_PIC` gains `43c-nana-h` |
| 38 | heroine K's conversation scripts | `K_PIC` gains `01m-k-talk` and `27c-ev-k-talk` |
| 39 | the other conversation scripts | **8 class moves and 37 new `source_member` bindings** (below) |

Revision 39's move: the eight `G_TALK` scripts (`G_TALK00` and `G_TALK30` .. `G_TALK90`)
go `system_script` -> `playable_event`, because a `minimal_playback` catalog row now
reaches each to its ending (the `if playable:` rule comes first, the rule that moved
`A_PIC.MES` .. `J_PIC.MES`, `L_PIC.MES` and `G_PROMIS.MES` on 2026-10-02, with `K_PIC.MES` the
precedent); each gains one
`catalog_routes` row and its `reason` changes from the shared-callee text to the
minimal-playback text. They were `source_member`s of the three `30C` EVENTG01 groups
before and remain so; they also become `source_member`s of `01m-g-talk`. The same
bindings land on 16 more entries - `A_INTRO.MES`, the `?_PIC.MES` scripts the TALK groups
hold as members (`A_PIC` .. `L_PIC` and `N_PIC` .. `Q_PIC`; Tina's `01m-m-talk` holds
`O_PIC.MES`, so `M_PIC.MES` gains none) - and re-hash `K_PIC.MES`'s `01m-k-talk` binding of
revision 38 (the group's contracts moved to schema v6): 17 entries' evidence changed, 25
with the eight scripts. All 37 new bindings are `source_member`; no entry's confidence or
bound status moved (the bound count stays 166). `catalog_sha256` and `payload_sha256` are the
only top-level fields besides `class_counts` that changed.

**The other 106 TALK callees stay unclassified.** The catalog has 114 TALK rows (one per
called script, 9 of heroine K's and 105 of the rest; 8 of the 114 are the `G_TALK` scripts
above), but the index's row set is the EVENT-named targets, the EVENT entry nothing names and
the non-EVENT scripts those EVENT-named entries dispatch
(`tools/classify_event_routes.py`), and `EVENTG01.MES` is the only EVENT-named caller of a
TALK script. The 106 are called at their anchors from `01M.MES`, `27C_EV.MES` and `11M.MES`,
so they are outside the 167 entries (no row, no class), as the other eleven `*_PROMIS.MES` are;
the 28 numbered follow-on scripts are members of their rung's route and not catalog rows. The
catalog, the registry and the package carry all 114; this index is not their register
(`todo/code_health.md` TD-49 records the classifier's EVENT-only input).

## What a measured row's confidence says, since the 2026-09-14 ruling

Every one of the 120 `unresolved_route` rows is bound by a committed analysis
group, and the value `analysis_group_measured_semantics_unresolved` had stopped
being true of them: a group declares the route's intro guard as a scene
condition, its branch and choice states, its state effects and its terminal,
and the audit and the validator re-derive all of that from the original on
every batch. The owner ruled on 2026-09-14 (option (b) of the three put in
`TODO.md`: promote to `analysis_only` catalog rows, say what is measured, or
require playback) that the index says what the evidence establishes and that
this closes EP-07's classification item. The class stays `unresolved_route`,
because promotion to catalog playback is a separate decision, and the
confidence now takes one of three values by the role the profiles give the
entry:

| Confidence | Role that selects it | Rows | What it establishes | What it leaves open |
|---|---|---:|---|---|
| `analysis_group_qualified_route` | `measured_callee` in any group | 118 | The entry's own route: origin, guard, variants, effects, terminal, reentry - declared and re-verified | Catalog playback; how the host reaches the origin, unless the group declares it (the 0.318.0 map-location contract) |
| `analysis_group_measured_participant` | `measured_caller` or `measured_terminal`, no `measured_callee` | 1 (`05C.MES`, the door of 05M's L06 and the caller of its own I21) | The entry's part in another entry's measured route | A route of its own |
| `analysis_group_member_unmeasured` | `source_member` only | 1 (`EVENTM11.MES`, the M10 callee's static dependency) | Membership | Everything: no measured path reaches it |

`structural_confirmed_semantics_unresolved` keeps its meaning for a row no
group binds; there are none. Counts on the day of the ruling: 49
`qualified_catalog_scope`, 118 / 1 / 1 on the three group values, 0
structural, over 156 bound entries - the same 49/120/0 split when the three
group values are read together, which is how the chronology above and
`tools/refresh_route_classification.py` continue to quote it. The reason text
of each row names the establishing groups and their roles and says plainly
that playback is not promoted. The chronology above keeps the retired value's
name as history.

## The first unreachable stored route

Updated 2026-09-10. `EVENTL09.MES` is classified `unreachable_stored_route`,
the first row that class has ever carried. The rule is not a label but an
input: `tools/audit_unreferenced_entries.py` scans every shipped file - eight
archives, the configuration and the executable, about 1.5 GB - for the entry
name, and the classifier promotes an EVENT-named entry only when the naming
audit leaves it unnamed **and** that scan finds it nowhere.

The control that makes the scan meaningful is `EVENTL10.MES`, whose name occurs
exactly twice in `mes.arc` - precisely its two measured dispatch records.

The row's reason also carries why the entry exists: its 53 message records are
byte-identical to `EVENTL10.MES`, which is dispatched, and the twin carries
seven voice markers where `EVENTL09.MES` carries none. It is a stored pre-voice
build of the same scene, not an orphan. That is recorded as the reason for the
classification rather than as a separate `duplicate_route` claim, which would
assert an ownership relation the catalog does not yet have.

`unreachable_claims` in the report is now derived from the rows rather than
asserted as zero.

## Evidence

Evidence is the authoritative `mes.arc`, SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
The whole-archive literal inventory establishes the framed caller set,
`config/event_catalog/dispatch_naming_v1.json` supplies the opaque-tail and
inline naming evidence, and `config/event_catalog/unreferenced_entries_v1.json`
supplies the shipped-file scan behind the unreachable classification.
`tools/classify_event_routes.py` independently checks all 11,124 dispatch records
with Python instruction-v45 decoding against original caller bytes: command,
target, source offset and exact end must agree. The 650 tail records and the two
inline sites are held to that same standard rather than trusted from the audit
report, and all 650 decode cleanly. Each row retains the callee hash and
incoming caller coordinates/hashes. Payloads and dialogue are excluded.
The inventory-structure and naming-structure hashes exclude only producer
version and derived report hash; this format's policy does not change analyzer
handoff hashing.

Two complete runs reproduce exactly. Duplicate evidence, substituted targets,
shifted offsets and missing records are rejected. Thirteen mutations of the
naming evidence were run against the classifier and all thirteen were rejected:
shifted tail offset, substituted tail target, shifted tail end, flipped tail
command, dropped tail row, a strict coordinate replayed as a tail row, a
duplicated tail row, changed inline selector, changed inline target, dropped
inline site, foreign archive hash, and a strict-count disagreement with the
inventory. Six further mutations of the shared-script rule and the analysis-group
inputs are also rejected: expecting an EVENT-caller maximum of 3 or of 1, a
profile binding a foreign archive, a profile member hash that no longer matches
the original, a profile naming a missing entry, and a file that is not an
analysis profile. The original inventory validator invokes Python to reproduce the
tracked classification. Project parsing and the combined audit passed at 2/2
when this index was first tracked
(`analysis/route-classification-batch-validation.json`) and at 3/3 on
2026-09-09, the third check being the dispatch naming audit.
Semantic qualification remains EP-07. Direct dependencies are not transitive
reachability through routines, definitions, address-table rows or native hosts.

**2026-09-20 (EP-10 unit 1):** every measured site is now also an `analysis_only`
row of the Event Catalog, generated from its v4 document and profile by
`tools/promote_analysis_groups.py`. The classifier reads those rows as it
read D05's and D06's: an analysis-only row qualifies no playable scope, and
the generated rows' `required_entries` (their profiles' members, which the
classifier already reads from the profiles directory) are not folded into
the dependency rows - only the hand-authored rows' are - so the index keeps
its 169 rows, the class counts stay 11/37/1/120 and the confidence split is
unchanged; `catalog_routes` now names the row of each measured entry and
`catalog_sha256` follows the regenerated catalog. On 2026-09-21 (EP-10 unit
5a) the ten sites that only a hand-authored catalog row had qualified -
EVENTB01, EVENTB02, EVENTB03, EVENTB15, EVENTD01, EVENTD02, EVENTD03,
EVENTD08, EVENTD14, EVENTJ04 - were measured as analysis groups with the
route toolchain; the classifier now binds 168 entries (the ten newly
bound), keeps their `qualified_catalog_scope` confidence beside the group
evidence, and the class counts stay 11/37/1/120. Later on 2026-09-21 (EP-10
units 5b/5c) the catalog became 142 generated rows and the classifier's
notion of a playable row followed the new vocabulary: a `minimal_playback`
row (one whose default option ends in a map return, a place menu or a chain)
qualifies its site as a playable event, and no hand-authored dependency rows
remain to fold, so the split is 129 playable events / 34 shared system scripts / 1 unreachable stored route / 3 unresolved routes over 167 rows over the same 169 rows, confidence
164 `qualified_catalog_scope` / 1 `analysis_group_qualified_route` / 1 `analysis_group_measured_participant` / 1 `analysis_group_member_unmeasured`, 166 bound. The 3 `analysis_only` rows stay unresolved
routes. Two rows left the index: `LIBLARY.LIB` and `DEF_MAIN.MES` were
present only as shared members the hand-authored rows declared by role
(`shared_library`, `definition_registry`); a generated row lists its package
members under the one role `analysis_group_member`, which the classifier
does not fold (the profiles already give it the measured members), so the
two entries are no longer catalog-declared dependencies - they remain
members of every event's package. `K_PIC.MES` moved from system script to
playable event: its arrival row plays. The 167 rows by scope:

| Scope | Playable event | System script | Unreachable stored route | Unresolved route |
|---|---:|---:|---:|---:|
| 129 EVENT-named strictly decoded targets | 127 | 0 | 0 | 2 |
| One EVENT target named only in an opaque tail | 1 | 0 | 0 | 0 |
| One EVENT entry nothing names | 0 | 0 | **1** | 0 |
| 36 non-EVENT dependencies | 1 | 34 | 0 | 1 |

On 2026-09-23 (EP-03 step 2, owner ruling) the three GROUND rows whose run
stops in front of the next event's intro dispatch - H01 first (`6308`, the
intro of `original/eventk01/ground-000018a4`), H01 repeat (`16859`,
`original/eventk01/ground-000041db`) and H02 first (`7227`,
`original/k_pic/ground-00001c3b`) - end by continuing into that event
(`chain`, `docs/spec/data/event_outcome_vocabulary.md`) and became
`minimal_playback` rows in catalog revision 26. The classification is per
entry, not per row: EVENTH02 and K_PIC were already playable through other
rows, so only `EVENTH01.MES` moves, and the split is 130 playable events /
34 shared system scripts / 1 unreachable stored route / 2 unresolved routes
over 167 rows, confidence 165 `qualified_catalog_scope` / 1
`analysis_group_measured_participant` / 1 `analysis_group_member_unmeasured`,
166 bound:

| Scope | Playable event | System script | Unreachable stored route | Unresolved route |
|---|---:|---:|---:|---:|
| 129 EVENT-named strictly decoded targets | 128 | 0 | 0 | 1 |
| One EVENT target named only in an opaque tail | 1 | 0 | 0 | 0 |
| One EVENT entry nothing names | 0 | 0 | **1** | 0 |
| 36 non-EVENT dependencies | 1 | 34 | 0 | 1 |

The two unresolved entries are `EVENTM11.MES`, which `EVENTM10.MES` calls
from three sites (`9545`, `13274`, `16586`) that no measured `44c-m10a` /
`44c-m10b` state reaches, so it is bound only as a source member; and
`05C.MES`, a place script measured only as the caller of `05c-i21` and the
handoff terminal of `05m-l06`, with no route of its own.

The same day the owner ruled on `05C.MES` (tool decision): a non-EVENT
script that is the measured caller of a committed analysis group hosts an
EVENT intro, so it is a system script even when no more distinct callers
reach it than reach an EVENT target - the caller-count rule classes a
shared script by measurement, and 05C, reached from exactly two callers
(`05M.MES:23549`, `EVENTL06.MES:13753`, both root handoffs), is the one
place script it could not separate. `tools/classify_event_routes.py` applies
the rule after the caller-count rule; only `05C.MES` moves, and the split is
130 playable events / 35 system scripts / 1 unreachable stored route / 1
unresolved route (`EVENTM11.MES`), confidence 166 `qualified_catalog_scope`
/ 1 `analysis_group_member_unmeasured`, 166 bound. Verified by `original
event corpus literal dispatch inventory` (which re-derives and checks the
installed index) and `original dispatch naming beyond the strict decode`.

Verified 2026-09-20: `tests/test_promote_analysis_groups.py` (6 tests: the byte-for-byte reproduction, the hand rows equal to HEAD's, the counts, the terminal mapping, `--check` both ways), `tests/test_event_catalog.tscn` (the new counts - 142 rows, 131 `analysis_only`, 129 generated - a generated row validates, a malformed `analysis_group` fails closed, the by-name precedence), `tests/test_playback_package.tscn` (a full build selects the 13 hand rows), the Event Player scene (1,289 checks, its catalog-shape loops over the hand rows), the Python suite (1,738 tests, with the outcome censuses over 142 and 13 rows and the names registry untouched because `tools/build_event_names.py` now counts hand rows only), the classification refresh (169 rows, 11/37/1/120, nothing newly bound or moved), and the original checks: Event Catalog source bindings, playback package export and playback (13 events from 228 member entries, unchanged), catalog bounded analysis routes, Event Player catalog ordinary playback and fragment catalogs.
