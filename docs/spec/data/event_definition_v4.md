# Event Definition v4 (`kakyu_event_definition/v4`)

Status: **frozen 2026-09-18** in this repository, by the owner's rulings of
the same day recorded in [the design document](event_definition_v4_design.md).
The contract is the fixture set `config/contracts/event_definition_v4/`
(`contract_fingerprint`
`26625a93b191b11e0325d68d85a5c7fa028d9e208f5404b289f301e1c16f9f25`, six valid
and 41 invalid documents plus a minimal invented fixture package), the
cell-class table `config/contracts/state_cells_v1/` (`cells_fingerprint`
`de21246988e7cb517ed04eda8a6c92625ba286a89f5f5e7db7441184d086cc73`) and the
event name registry `config/contracts/event_names_v1/`
(`names_fingerprint`
`149ccc398689f2b02598af5919411290fac4c96ea42b0cfd49328571633727bb` since 2026-09-24, EP-12 catalog part, when the three `01m-a-date` flow routes were promoted to their own catalog rows (145 sites; `4a04c35a1897b968cd7d9357b316be282516acf3eea9a8cadf461fcc8c1cc66a` from 2026-09-21, when every catalog row became EP-10 generated (EP-10 unit 5b/c part 2; `dbad4b00f9e9725b29a5f84e6b7de576d30a5ae373f007801aad27cd09d9df63` from the same day, when the ten formerly hand-qualified sites gained groups, EP-10 unit 5a; `7721269a1613e1b37220a4879de387f65bf6d12969c4a5b220e3b2919d828b75` from 2026-09-19, when the 44M B14 group gave its row a group
alias - the same 142 ids); `b7ffcea3abac019a78f8ac19e98d5259fc778a0eb3c7123424f257b435163e1a` before, which v3 keeps). The
sharing rule of 2026-09-16 stands: these directories change here only, a
revision is a `v5/` directory beside them, and the remake reads them from
this repository and tests its own copy with its own validator. v3
([Event Definition Projection](event_definition_projection.md)) is frozen:
its directory, fingerprint, producer path, tracked documents and tests are
untouched.

## Why v4 exists

v3 said which callee a caller dispatches, under which guard, with which
answers and terminals, and what the callee says. It could not say what a
visit does to the game state beyond the cells a profile happened to declare,
whether an effect sets a cell or adds to it, what the caller says before
and after the scene, or - for a site whose guard holds no done flag - which
cell says the event was seen. Measured on the 138 tracked v3 documents and
the stored replays (both measurement sections of the design document): 45%
of the cells a visit changes were undeclared and not scratch, sixteen
affection effects were measured finals written as absolutes, the caller's
1,226 continuation and 3,284 lead-in lines were counted and dropped, and
55 sites had no done cell. v4 carries what a definitions-only player needs
to keep the state right. Presentation stays deferred; a mod's own
definitions are the separate [Mod Event Definition](mod_event_definition.md)
contract, frozen the same day.

## The document

A v4 document is a v3 document with these changes; every v3 rule not
listed here holds unchanged.

| Field | v4 |
|---|---|
| `schema_version` | `"kakyu_event_definition/v4"` |
| `after` (body and per result) | rows of three types: `write_legacy_value {storage, bank, index, value, cell_class}`, `add_legacy_value {storage, bank, index, delta, cell_class}` (`delta` non-zero), `consume_time {minutes, cell_class: "clock"}` (`minutes` positive, at most one per list); one row per cell per list; the clock cells (`state_u16` 0, 1, 19) never as `write` or `add` |
| `cell_class` | the class the cell-class table gives the cell: `weekday`, `date`, `clock`, `clock_part`, `choice_result`, `map_poll_result`, `affection` (with the heroine the table names), `flag` (a `global_u8` observed only as 0 to 1), `counter` (any other `global_u8`), `unnamed` |
| `evidence.effect_witnesses` | one row per decided effect: `{result, cell, basis, entry, final, declared, step?, shifted_entry?, shifted_final?}`; `basis` is `variants` (the profile's own variants decided it), `shift_witness` (the step fields are present and agree with the row: `shifted_final - final == step` for an `add`, `shifted_final == final` for a `write`), `flag_pattern` or `clock`; `declared` says whether the profile's `expected_state` names the cell |
| dialogue lists | the v3 entries plus `{kind: "choice_point", choice: "top" or a result id}` where a question is asked and `{kind: "scene_end"}` where the callee's scene ends and the `after` rows and the done state apply; a line entry may carry `location_line: true`; a flow through one result holds at most one `scene_end`, none for a result with `event_played: false` |
| `conditions[]` of type `event_not_completed` | `done_cell` plus `source: "guard_flag"` or `"reentry_probe"` |
| `trigger.order_hint` (optional) | `{scope: <caller entry>, rank, of, basis: "guard_offset", chain_confirmed}`; absent for a site without a typed guard |
| text | with a package, every resolved string satisfies [Text Encoding](text_encoding.md): NFC, no control character, no line break; a tracked document still carries no `text` |

A consumer fails closed on everything v3 failed on and on: a zero delta, two
rows for one cell in one list, a class the table does not give, a clock
cell as a `write`/`add`, a malformed `consume_time`, a witness row that
contradicts its effect, a `choice_point` naming no choice, a second
`scene_end` in one flow or one in a skipped result, `location_line` on a
marker, a `done_cell.source` outside the two values, an `order_hint` whose
`rank` exceeds `of` or whose `scope` is not the caller, and a resolved
string that breaks the text rules.

## How the producer decides

`tools/project_event_definition_v4.py`, from the same evidence v3 used plus
the v2 replays (`kakyu_event_analysis_group_replay/v2`: the probe's state
diff of the lead-in, the scene and the continuation of every variant) and
the witnesses (`kakyu_event_effect_witness/v1`, answered by the validator's
`--witness` mode from the requests `tools/plan_event_effect_witnesses.py`
plans):

- **The flow.** A candidate's messages are the lead-in, the scene and the
  continuation in order; `scene_end` follows the last scene message of a
  played result; a `choice_point` sits before the first message of the
  boundary's owner whose offset exceeds the boundary offset. The outcome
  signature is (messages with markers, the last terminal, the effect rows);
  the body is the longest common prefix, a result's `dialogue` the rest.
- **Effects, per net-changed cell of a result's group, in this order:** the
  clock becomes one `consume_time` in minutes (a wrap past midnight is a
  positive advance); a `global_u8` observed only as 0 to 1 is `write 1` by
  the flag pattern; when the group's variants entered the cell with
  different values, one final value is a `write`, one delta an `add`, else
  `unresolved`; otherwise the shift witness decides (`set` -> `write`,
  `add` -> `add`, `other` or `path_changes` -> `unresolved` naming the
  outcome). Rows every result shares move to the body.
  **Call-argument storage is not an effect (TD-56 D11, owner ruling
  2026-10-11; a projection tool decision, not a native claim).** Since Core
  0.377.0 a replay's `state_changes` carry `global_i32` rows, the arguments a
  caller hands a routine. A `global_i32` net change is left out of this
  derivation (no row, no witness) when the run executed a command-`0x09`
  record whose write range covers the index and whose literal equals the
  change's final value (in a flow variant a covering record of an earlier hop
  also counts), and is recorded once per `(index, value)` in `unresolved` as
  `argument storage: global_i32[n] = v written by command 0x09 at <entry>:<offset>;
  not an event effect (TD-56 D11)`. A `global_i32` change with no covering
  literal keeps the path above. The rule needs the v3 replay's `executed`
  offsets and so does nothing on a v2 replay. The library-set flags
  (`global_u8[4000]`, `[4090]`, `[4091]`) are ordinary 0-to-1 flag-pattern
  effects. See `docs/spec/mes/format_and_method.md`, "Command `0x09` and token
  `0xF6` address one storage".
- **Done cell.** The guard's cleared flag as in v3 (`guard_flag`), else the
  witness done-cell probe's single gate (`reentry_probe`), else
  `unresolved`.
- **Location lines.** A lead-in line below the route's guard offset, or one
  the batch driver's shared-line index lists as preceding more than one
  event site of the same caller.
- **Order hint.** The sites of one caller ranked by guard offset;
  `chain_confirmed` when the guard's `false_target` leads into the
  next-ranked site's guard.
- **Catalog rows.** The catalog replay carries the scene only, so a catalog
  document's flow stays scene-only, it has no typed guard and therefore no
  `order_hint` or `location_line`, and its effects come from the presets'
  own state diffs or stay `unresolved`; every such gap is a line in
  `unresolved`.

## The projection of every registry site, 2026-09-18

`tools/project_event_definitions_batch.py --contract v4` projected the 142
registry sites into `config/event_definitions/v4/` (index
`kakyu_event_definition_index/v2`, which adds `cells_fingerprint` and the
per-document counts below): 138 documents, all valid under the recorded
fingerprints with every `text_ref` and member hash resolved against the
full playback package; the same four catalog sites as in v3 (EVENTB14,
EVENTD05, EVENTD06, EVENTD14) had no document because the bounded route
probe could not finish their replay. **Re-measured 2026-09-19:** the catalog
replay had never given the probe the startup definition registry
(`DEF_MAIN.MES`), so definition 26, which shared routine 25 invokes, and
definition 21 were "not registered" - the tracker's premise that a caller
prefix registers definition 21 was wrong. With the registry, the audited
calendar projection of `START.MES` (definition 12 scans the calendar table
and needs a valid date in the date cell), nested presentation scripts
loaded from the archive on demand, and a declared analysis boundary
matched against the event's own call-site row, EVENTD05
(`maki.town.station.05.1`) and EVENTD14 (`maki.town.12c.14.1`) replay to
completion, the other 138 documents byte-identical to the previous
projection (the calendar seeding changes no message, terminal or reentry
of the nine catalog documents). The same day a second cause surfaced:
EVENTD05 and EVENTD06 both have declared analysis groups (`01m_d05_v6`,
`10c_d06_v6`, with v2 replays and witnesses), but the batch driver sent
every registry row that carries a catalog alias down the catalog path,
so their groups were never used. Under v4 the driver now projects a row
through the profile path whenever a declared group covers the site and
keeps the catalog path for a row no profile declares (v3's dispatch is
frozen): EVENTD06 (`maki.town.10c.06.1`) is tracked from its group (a
typed guard, a `guard_flag` done cell, an order hint, three
condition-selected results of 116 lines with the caller's own lines,
thirteen shift-witness effects), and EVENTD05 (`maki.town.station.05.1`)
moved from its scene-only catalog document to its group's (two answers
now carry an affection `add` by shift witness where the catalog path had
projected an absolute `write` from its one preset). **141 documents**
(131 from groups, 10 from catalog rows). The last site, EVENTB14
(`mahoko.town.44m.14.1`), was declared as a 44M group the same day
(`44m_b14_v8.json`, `docs/spec/mes/44m_caller_group.md`: results 1 and 3,
result 2's second selection at `0x133F` measured and not declared), the
driver resolving the row to its profile by site evidence since the
registry's aliases are regenerated only with a new `names_fingerprint`:
**142 documents, every registry site** (132 from groups, 10 from catalog
rows).

| Over the 138 documents | Count |
|---|---:|
| Effect rows: `write_legacy_value` / `add_legacy_value` / `consume_time` | 2,274 / 149 / 63 |
| Effect rows by basis: shift witness / flag pattern / variants / clock | 1,185 / 989 / 142 / 62 |
| Effect rows on cells no profile declared | 1,983 |
| `location_line` entries / `choice_point` / `scene_end` | 397 / 132 / 289 |
| `order_hint` rows, of which `chain_confirmed` | 132 / 84 |
| `done_cell` by source: guard flag / reentry probe | 77 / 41 |

(Over the 142 documents since 2026-09-19 - the 44M B14 group also re-ranked the
other ten 44M documents' `order_hint`, now `of` 11; the 138-document totals of 2026-09-18
were 2,208 / 143 / 62, 1,160 / 961 / 123 / 61, 1,932, 397 / 127 / 278,
129 / 82 and 74 / 40.)

Three documents stand as the proof of the three new answers: the station's
G11 (`ryoko.town.station.11.1`) adds 1 to ryoko's affection by a shift
witness where v3 had no affection effect at all; 15C's I10
(`mayumi.town.15c.10.1`) sets mayumi's affection to 25 in its third answer;
01M's M06 (`tina.town.station.06.1`) carries the full flow of 32 lead-in,
105 scene and 17 continuation lines with its one `scene_end`, and its done
cell `global_u8[2438]` from the reentry probe, where v3 knew no done flag.

## What stays open

The 24 documents whose guard holds no done flag and whose probe found none
or was not run; the H07 and K06 affection increments that depend on the
entry value (`other`) and the G01 and G08 cells the guard itself tests
(`path_changes`), all `unresolved`; the catalog rows' scene-only flows
and their single-preset affection writes (a catalog row has no shift
witness, so an affection cell that moves from 0 to 2 in the one preset is
projected as `write 2` with `basis: "variants"`, where the script may add);
presentation. The remake's consumer for
v4 is its own backlog: it reads the fixture set, the cell-class table and
the tracked documents from this repository.
