# Event Definition Projection (`kakyu_event_definition/v3`, draft)

Status: **agreed, 2026-09-15** (design confirmed by the owner the same day).
This is the producer side of WD-22: how this repository projects a qualified
original route into the remake's event definition, raised from the remake's
`kakyu_event_definition/v2` to a v3 agreed by both repositories. The agreement
is the pair of fingerprints recorded in both trackers on 2026-09-15:
`contract_fingerprint`
`7545e37e08d3dacac8eafb4757ec3ca68305af8afb9278001cce3932a272fb55` over the
conformance fixture set `config/contracts/event_definition_v3/` (6 valid and
26 invalid documents) and `names_fingerprint`
`b7ffcea3abac019a78f8ac19e98d5259fc778a0eb3c7123424f257b435163e1a` over the
event name registry `config/contracts/event_names_v1/` (142 sites), both
mirrored byte-identically in the remake, each side testing its own copy with
its own validator. **The registry was regenerated on 2026-09-19** (owner's
choice 1 of that day): the 44M B14 group gave `mahoko.town.44m.14.1` its
group alias, the 142 ids are unchanged, and `names_fingerprint` is now
`149ccc398689f2b02598af5919411290fac4c96ea42b0cfd49328571633727bb` (since 2026-09-24, EP-12 catalog part, 145 sites - three promoted `01m-a-date` flow rows; `4a04c35a1897b968cd7d9357b316be282516acf3eea9a8cadf461fcc8c1cc66a` from 2026-09-21, EP-10 unit 5b/c part 2; `dbad4b00f9e9725b29a5f84e6b7de576d30a5ae373f007801aad27cd09d9df63` from the same day, EP-10 unit 5a; `7721269a1613e1b37220a4879de387f65bf6d12969c4a5b220e3b2919d828b75` from 2026-09-19); v3's documents and fixture set stay frozen and validate against
the fingerprint they recorded, `b7ffcea3abac019a78f8ac19e98d5259fc778a0eb3c7123424f257b435163e1a` (`tests/test_event_definitions_tracked.py`,
`tests/test_event_definition_contract.py`). The first projected event is `minatu.town.station.04.1`
(EVENTJ04 from the station), whose text references and member hashes resolve
against the local playback package. The remake's consumer semantics live in
its `docs/spec/data/event_definition_v3.md`; this document says how each
field is produced and what stays unresolved.

**Superseded by v4 on 2026-09-18** for new documents: see
[Event Definition v4](event_definition_v4.md). This v3 contract, its fixture
set, its producer path and its tracked documents stay frozen and valid.

**Sharing since 2026-09-16, by the owner's decision:** the contract
artifacts under `config/contracts/` are changed in this repository only - a
revision is an `event_definition_v4/` directory beside v3, or a new
`names_fingerprint` for the registry - and the remake reads the shared
conventions from this repository; nothing there is edited from here, the
2026-09-14 exception being closed. The READMEs inside the two directories
describe the 2026-09-15 mirrored landing and are part of the fingerprinted
bytes, so they keep that wording.

## Why v3 exists

The remake's v2 definitions were hand-written prototypes: a trigger, a list
of runtime conditions, inline dialogue and a list of completion effects. The
qualified routes here are measured, not written - each is an analysis-group
profile (a caller, a typed guard with witnesses, the callee's return or
handoff, per-variant state effects, a reentry, sometimes a map-location
contract) or a catalog event row (presets, branches, choices, terminals with
their evidence). v3 carries what those declarations already prove, in the
remake's vocabulary where one exists, separates the event from its results,
names every event in a way a person can read, and binds every document to
the archive, the profile or catalog revision and the playback package it
references. Text is referenced in every tracked artifact and resolved only
in a local document: original dialogue never enters a tracked file here, so
a projection of an original event is trackable evidence and the package
remains the only carrier of text.

## Inputs

A v3 document is produced from exactly one **event site** - one callee
dispatched from one place in one caller - whose evidence is either:

- a **catalog event row** of `config/event_catalog/original_events_v1.json`
  (`evidence.kind: "catalog_event"`): the 13 events the playback package
  already carries; the row's `source`, `activation`, `presets`, `branches`,
  `choices` and `terminals` are the evidence;
- one or more **analysis-group profiles** under
  `config/event_catalog/analysis_groups/` (`evidence.kind:
  "analysis_group"`, schemas v4..v12) that declare the site: a profile's
  routes (one per callee answer) become the site's results, and two groups
  declared beside each other for the same site (a window group and an
  arrival group) both enter the evidence of one document;

plus the **event name registry** (below), the **playback package**
(`kakyu_playback_package/v7`) whose manifest lists the member entries with
their `entry_sha256` and whose per-entry `events/<STEM>.json` records and
`text/<STEM>.json` strings resolve every `text_ref`, and the read-only
archive for the record hashes the producer verifies (the consumer never
sees the archive).

The producer refuses a site whose members are not all carried by the
package: the first proof is EVENTJ04 from the station, carried today. Since
Core 0.323.0 (WD-21's membership rule, owner ruling (a) of 2026-09-16) the
full package carries every source member of every committed profile, so the
members of all 118 qualified routes are carried and the widening is a
producer question only (TODO.md step 3).

## Event names

Every site has a fixed five-segment id from the shared **event name
registry**, `config/contracts/event_names_v1/event_names.json`, mirrored in
both repositories and fingerprinted on its own (`names_fingerprint`, the
rule below) so that renaming a title never moves the contract fingerprint:

```
<heroine>.<category>.<place>.<number>.<site>
nana.school.gate.07.1        EVENTC07 from the grounds' gate
ai.school.gate.09.1          EVENTK09 from the gate; its three answers are results
ai.school.gate.pic.1         K_PIC from the gate
miyuki.town.station.07.1     EVENTH07 from the station, with a train ride
minatu.town.station.04.1     EVENTJ04 from the station, the first proof
```

- `heroine`: the callee's letter family resolved through the gallery-menu
  table measured in `docs/spec/mes/duplicate_entries.md` (A miko, B mahoko,
  C nana, D maki, E mizuho, F reiko, G ryoko, H miyuki, I mayumi, J minatu,
  K ai, L sizuka, M tina).
- `category`: the caller's family - `school` (GROUND, FLOOR1..FLOOR5),
  `town` (MACHI, the station 01M and the numbered town scripts), `date`
  (`*_DATE*` callers), `special` (a caller of no family; REIKO42 today).
- `place`: within `school`, `gate` (GROUND location 0) or `floor1`..`floor5`;
  within `town`, `station` for 01M, `machi` for MACHI, otherwise the caller
  stem in lower case (`44m`) until the registry names it; within `date` and
  `special`, the caller stem.
- `number`: the callee's stem without the `EVENT` prefix and the heroine
  letter (`EVENTC07` -> `07`, `K_PIC` -> `pic`).
- `site`: the 1-based order of the callee's dispatch sites within the
  caller, by dispatch offset; 108 of the 119 declared sites are `.1`, eleven
  sites (C12, K01, H01, H02 from the grounds, E15, I04, A08, A20, G01, J14,
  M10) carry `.2` or `.3`.

A registry row is keyed by (callee entry, caller entry, site ordinal) and
carries `id`, `title_ko`, `title_en` (provisional, generated as "<heroine>
at <place> (<CALLEE>)" until the owner names the event), `heroine`,
`category`, `place`, `scene_kinds`, `aliases` (the catalog `event_id`, the
group and route ids) and `evidence` (the caller's dispatch offset and end,
the callee entry). The registry is generated by
`tools/build_event_names.py` from the profiles and the catalog; the owner
edits titles in place, and the id is stable unless a place is renamed.
Offsets never enter an id.

## Document shape

```
schema_version        "kakyu_event_definition/v3"
contract_fingerprint  SHA-256 of the conformance fixture set
names_fingerprint     SHA-256 of the event name registry the id comes from
id                    the registry id
kind                  "event" | "choice_event"
display               {title_ko, title_en, heroine, category, place}   (from the registry)
evidence              {kind, archive_sha256, catalog_id?, catalog_revision?, groups: [{group_id,
                       profile_sha256, route_ids}], members: [{entry, entry_sha256}],
                       document_refs: []}
package_binding       {schema: "kakyu_playback_package/v7", package_sha256}
trigger               {type: "caller_dispatch", caller: {entry, entry_sha256, offset, end,
                       command, kind}, callee: {entry, entry_sha256, start_coordinate},
                       origin: {kind, offset, contracts?: [...]}}
scenes                [{kind, map, poll_offset, locations, spent_by}]   (from map contracts)
guard                 {offset, end, false_target, record_sha256, conjuncts: [...],
                       witnesses: [{case_id, writes, expected}]}
conditions            v2-vocabulary runtime gates (one `mes_expression` with the guard's
                      AST, plus `event_not_completed` when the route declares a done gate)
presets               [{preset_id, label, writes: [absolute rows]}]
dialogue              route-ordered text references shared by every result (the body)
after                 route-level effects shared by every result: absolute rows
choice                {owner, boundary, position, prompt_ref?, options: [{value, label_ref?,
                       result}]}                                   (choice_event only)
results               {<result_id>: {selected_by, event_played, dialogue, after, terminal,
                       reentry?, choice?, results?}}
terminals             {<terminal_id>: {kind, owner_entry, offset, end, next_target?,
                       required_state, resume?}}
dependencies          [{entry, entry_sha256, role}]
presentation          {status: "deferred", resources: [{name, source_offset, kind}]}
unresolved            [strings copied from the profiles or the catalog blockers]
```

*Note, 2026-10-08 (WD-21 U2):* the `presentation.resources` item above is the v3 shape, and
the v3 to v6 documents carry `[]`. `kakyu_event_definition/v7` fixes the item as `{entry,
source_offset, kind, name}` and fills it from the row's measured route
([Event Definition v7](event_definition_v7.md)).

Every field is required except `scenes`, `guard.witnesses`, `presets`,
`choice`, `dependencies`, `results[].reentry`, `results[].choice` and
`results[].results`, which are present when the source declares them.
`results` holds at least one entry. A consumer fails closed on an unknown
`schema_version`, a `contract_fingerprint` or `names_fingerprint` other than
the ones it recorded, an `id` the registry does not carry, a
`package_binding` whose `package_sha256` is not the loaded package, a member
whose `entry_sha256` is not the package manifest's, a `text_ref` that does
not resolve, an inline `text` anywhere in a tracked document, an effect kind
other than the absolute rows below, an option whose `result` is not in
`results`, and a result whose `terminal` is not in `terminals`.

### Event and results

`kind` is `choice_event` when the site asks a routine-40 question the
player answers - the callee's own (`choice.owner` is the callee, `position:
"in_event"`) or the caller's before the event (the grounds' question before
K09: `owner` is the caller, `position: "before_event"`); otherwise `event`.
The body (`dialogue`, `after`) is what every result shares. Each result is
one distinct outcome:

- `selected_by`: `{kind: "choice", value}` for a question's answer,
  `{kind: "condition", conditions: [cell comparisons]}` for a branch the
  state selects (the catalog's `branches`, a profile variant group), or
  `{kind: "default"}` for the single outcome of a plain event;
- `event_played`: `false` for a result that skips the event (a caller
  question answered away from it), else `true`;
- `dialogue`: the result's own text references, in order (replay);
- `after`: the result's own absolute effects;
- `terminal`: the id of the terminal the result reaches;
- `reentry`: the second visit's outcome, message count and effects when the
  source declares one;
- `choice` and `results`: a second question inside the result (the v2
  `next_choices` precedent), with the same shapes, when the source declares
  one.

A result is a distinct replayed outcome. From a profile, each route (one
per callee answer) becomes one result, and inside a route the variants are
grouped by outcome signature - the message sequence, the `expected_state`
rows and the terminal - so that witnesses of one and the same outcome
collapse into one result (C07's 44 variants are one result) while an
affection threshold that changes the outcome yields two, each selected by
the conditions the variants wrote. From a catalog row, `choices[].options[]`
become answers and the preset runs are grouped by the same signature; when
an event holds several independent branch points (EVENTJ04 tests two flags
in sequence), a result is one combination of arms - one per distinct
replayed sequence - and its `selected_by.conditions` is the conjunction of
the catalog branch rows the run satisfied. `terminals` are shared by id;
two options or two runs that reach the same outcome share one result. A
result's `dialogue` is its complete sequence after the body, so a segment
that several results share after they diverged appears in each of them:
every result reproduces one replayed run, and nothing is listed that no run
emitted.

### Field mapping from a catalog event row

| v3 field | catalog row |
|---|---|
| `id`, `display` | the registry row whose `aliases` carry `event_id` |
| `evidence` | `kind: "catalog_event"`, the catalog's `catalog_id`/`catalog_revision`, `source.callee` and `source.required_entries` as `members`, `activation.document_refs` |
| `trigger.caller` | `source.caller` (`dispatch_offset` as `offset`, `resume_offset` as `end`, `command` 14 = `root_handoff`, 15 = `nested_call`) |
| `trigger.callee` | `source.callee` |
| `trigger.origin` | `analysis_route.caller_start_coordinate` when present (`kind: "caller_prefix"`), else absent |
| `guard` | absent (the row records activation evidence, not a typed guard) |
| `conditions` | `event_not_completed` when a terminal's `required_state` names a done flag, carrying `done_cell` (the first row whose cell the completed reentry returns on; EVENTJ04: `global_u8[905] = 1`) |
| `presets` | `presets` (writes copied as absolute rows; `evidence_level` dropped) |
| `choice`, `results` | `choices` -> `choice.options` (value, result id per option); the preset runs grouped by outcome signature -> results, each `selected_by` the conjunction of the `branches` rows its run satisfied; an effect row every result shares moves to the body `after` (the terminal's `required_state` rows, for EVENTJ04) and the rest stays per result |
| `terminals` | `terminals` (`kind` by the table below, `next_target`, `required_state`) |
| `dialogue`, `results[].dialogue` | replay (below) |
| `unresolved` | `blockers[].summary` |

### Field mapping from analysis-group profiles

| v3 field | profile route(s) |
|---|---|
| `id`, `display` | the registry row keyed by the callee, the caller and the site ordinal |
| `evidence` | `kind: "analysis_group"`, one `groups[]` entry per profile declaring the site (`group_id`, `payload_sha256`, `route_ids`), `source_members` as `members` |
| `trigger.caller` | `caller` (`offset`, `end`, `command`; `caller_outcome.kind` gives `dispatch` -> `nested_call`, `root_handoff`, `nested_root_handoff`) |
| `trigger.callee` | `callee` with the member hash |
| `trigger.origin` | `origin_offset` with `kind: "typed_guard"` when it equals `guard.offset`, `kind: "map_arrival"` with the `map_location_contracts` when the route declares them, else `kind: "caller_prefix"`; when two groups declare the site, the arrival group's origin is the trigger and the other group's is listed in `evidence` |
| `scenes` | one per map-location contract: `kind` by map (`train_ride` for TRAIN, `school_gate` for GROUND location 0, `school_floor` for FLOOR1..5, `town` for MACHI), `map`, `poll_offset`, `locations`, `spent_by` |
| `guard` | `guard` (offset, end, false_target, record_sha256) with `conjuncts` derived from the handoff's typed condition (the vocabulary below) and `witnesses` from `guard_cases` |
| `conditions` | `[{type: "mes_expression", ast, source_offset, failure_reason: "guard_rejected"}]`; a route whose callee gate is a done flag adds `event_not_completed` |
| `presets` | the `baseline` rows (`preset_id: "baseline"`) and one preset per variant whose writes are non-empty |
| `choice` | `choice_contracts` (owner, boundary, `result_values` as option values); the caller's contract when the caller asks |
| `results` | one per route (answer), variants grouped by outcome signature within it; `after` from the variant group's `expected_state` rows; `terminal` from `outcome` (and the resume for a nested call); `reentry` from `reentry` |
| `after` | the route's `expected_state` rows shared by every result |
| `terminals` | from `outcome` (kind by the table below); a nested route adds the `resume` outcome with its policy |
| `dependencies` | `source_members` other than the caller, callee, START, DEF_MAIN and LIBLARY, with `role: "nested_presentation"` |
| `dialogue`, `results[].dialogue` | replay (below) |
| `unresolved` | `unresolved` verbatim (including "Measured and not declared" notes) |

`bypass_variants` are not projected: they prove what the caller does without
the event and belong to the map, not to the event definition. A caller
question whose answer skips the event is the exception: that answer is a
result with `event_played: false` and the door it leaves by as its terminal.

### Terminal kinds

| v3 `terminals[].kind` | profile `outcome.status` / resume policy | catalog `terminals[].kind` |
|---|---|---|
| `root_handoff` | `script_handoff_boundary` on a root handoff route | `root_replacement`; `normal_completion` (the callee's own handoff) |
| `callee_return` | `script_return` (nested call) | `callee_return_only` |
| `natural_handoff` | resume policy `natural_handoff` | `caller_handoff` (the caller hands the root on, with `next_target`); `caller_postlude` (the caller continues, no target) |
| `def_selection_boundary` | resume policy `def_selection_boundary` | `analysis_boundary` with runtime status `def_selection_boundary` |
| `caller_menu_loop` | resume policy `caller_menu_loop` (with the loop's period and cycle) | - |
| `dependency_stop` | resume policy `stop_before_unprovided_dependency` | `analysis_boundary` with any other runtime status (a shared-routine boundary) |

The catalog column was completed on 2026-09-16 when the catalog path was
run over every catalog row; a document lists the mappings it used in
`unresolved`, and the catalog's `terminal_id`s stay the v3 terminal ids.

A terminal carries `owner_entry`, `offset`, `end`, `next_target` when it
hands the root to a script, and `required_state` rows when the source
declares them. The consumer treats `root_handoff` and `natural_handoff` with
`next_target` as the event's `return_to_map`; the other kinds are recorded
so that a consumer can refuse to present a route it cannot complete.

### Guard conjunct vocabulary

Each conjunct of a typed guard is projected as one row. Named cells are the
ones the documents already name; everything else stays an expression:

| Row | Produced for |
|---|---|
| `{kind: "weekday", op, value}` | `state_u16[4]` |
| `{kind: "date", op, value}` (MMDD) | `state_u16[7]` |
| `{kind: "clock", op, value}` (HHMM) | `state_u16[19]` |
| `{kind: "choice", op, value}` | `state_u16[21]` (the routine-40 result, also the map arm) |
| `{kind: "affection", heroine, op, value}` | `banked_u16[201..211]` by the heroine letters |
| `{kind: "cell", storage, bank, index, op, value}` | any other single-cell comparison |
| `{kind: "mes_expression", ast}` | a conjunct that is not a single-cell comparison |

`op` is one of `equal`, `not_equal`, `less_than`, `greater_than`; a
disjunction such as "before 6/16 or after 9/15" stays a `mes_expression`.
The rows are evidence for readers and for the local validator; the consumer
evaluates the `conditions` entry, which carries the complete AST, under the
remake's exact-one truth semantics.

### Effects

Effects are absolute writes only: `{type: "write_legacy_value", storage,
bank, index, value}`, the profile's `expected_state` rows and the catalog's
`required_state` rows verbatim. Only the `after` lists (the body's and every
result's) carry `type`; `presets[].writes`, `terminals[].required_state`,
`guard.witnesses[].writes` and `selected_by.conditions` are plain cell rows
(`{storage, bank, index, value}`, conditions with an `operator` instead of a
bare value). `add_legacy_value` and `consume_time` are
never produced for an original route: the profiles declare final values, not
deltas, and the clock advance is the route's own writes. The consumer
derives `complete_event` and `return_to_map` from the result's terminal;
`set_flag`, `learn_character_info` and the other v2 remake-owned effects are
not produced here.

### Text: referenced in tracked documents, resolved locally

A dialogue entry of a tracked document has a `kind`. A `text` entry is
`{kind: "text", text_ref: {entry, at, s, raw_sha256}, voice?}`: `entry` the
package member, `at` the code-relative offset of the text record in the
package's `events/<STEM>.json`, `s` the string index that record carries,
`raw_sha256` the SHA-256 of the original CP932 message bytes (the producer
verifies it against the archive; the consumer verifies `at` and `s` against
the package). A `name_insert` entry is `{kind: "name_insert", entry, at,
raw_sha256}`: the protagonist's name inserted by the script's command
`0x0E` record at `at`, resolved by the consumer from the playthrough's name,
never from the package (EVENTJ04 inserts it seven times in 21 messages).
`voice` is the resource name the route's voice marker names, with `status:
"deferred"`. Inline `text` is an error in a tracked document. The strings a
`text_ref` resolves to are UTF-8 under [Text Encoding](text_encoding.md).

Beside the tracked projection the producer writes a local, untracked
**resolved document** (`<id>.resolved.json`, next to the package it was
resolved against, never under `config/`): the same document with every
`text_ref` accompanied by `text` from the package's strings, and one
`script` field per dialogue list - a single readable block, one line per
message as its text, a name insert shown as `{name}`, with `[result <id>]`,
`[choice <owner> <value>]` and `[terminal <id>]` marker lines between the
parts. The remake consumes
the resolved document; the fixture sets and the registry carry only the
tracked form.

### Dialogue by replay

`dialogue` and `results[].dialogue` are the message records the site emits,
in order, captured by replaying it in the sandbox the validators use (the
repository's own bounded MES interpreter, `KakyuMesSandboxState` and the
route probe - not an operating-system feature): the body is the sequence
shared by every result, each result's list is what its answer or branch
adds. Replay is the same bounded execution the analysis groups and the
catalog validators already perform; it produces offsets, never text, and
each offset becomes a `text_ref` through the package.

### Presentation

`presentation.status` is `deferred` until media extraction lands (WD-21);
`resources` lists the resource names the site's records reference (MMO, AX,
voice, BGM) with their marker offsets and kinds, copied from the catalog
row's `resources` or the profile's member records, so that the consumer can
report what it cannot show.

*Note, 2026-10-08 (WD-21 U2):* the paragraph above is the v3 design, a static source the owner
ruled out on 2026-10-06; no v3 to v6 document ever carried an item. Since
`kakyu_event_definition/v7` the list is **measured**: the package inventory's occurrences whose
record a measured run of the row executed, `{entry, source_offset, kind, name}`, produced by
`tools/project_event_definition_v7.py` and promoted into the catalog rows' `resources`
([Event Definition v7](event_definition_v7.md), "What the list means";
[Media Reference Classification](../mes/media_references.md), "The measured route"). The v3
paragraph stays as the record of the original design.

## Conformance fixture set and fingerprints

`config/contracts/event_definition_v3/` holds (mirrored byte-identically in
both repositories on 2026-09-15; later revisions are made here only, see the
sharing note above):

```
README.md                what the set is and how the fingerprint is computed
contract_fingerprint     one line, the SHA-256 below
valid/                   documents every validator must accept
invalid/                 documents every validator must reject
expected.json            {"<relative path>": {"ok": true|false, "reason": "<code>"}}
```

`contract_fingerprint` is the SHA-256 over the concatenation of
`"<relative path>\t<sha256 of the file bytes>\n"` for every file under the
directory except `contract_fingerprint` itself, paths sorted, LF line
endings. `config/contracts/event_names_v1/` holds `event_names.json` and
`names_fingerprint`, computed by the same rule. Each repository's fixture
test recomputes both, compares them with the values its tracker records,
and runs its validator over every fixture against `expected.json`. A change
to the contract is a `event_definition_v4/` directory beside v3, never an
edit of v3 in place; a change to the registry is a new `names_fingerprint`
recorded in both trackers.

The valid set holds the first proof (EVENTJ04's projection, text referenced)
and one minimal hand-written document per `kind`, trigger origin and
terminal kind. The invalid set holds one document per fail-closed rule:
wrong schema, missing or foreign `contract_fingerprint` or
`names_fingerprint`, an id the registry does not carry, a package binding
for another package, a member hash that is not the package's, an
unresolvable `text_ref`, inline `text`, a delta effect, an unknown terminal
kind, an unknown conjunct kind, a `mes_expression` without an AST, a witness
that contradicts its guard, an option naming a missing result, a result
naming a missing terminal, a `choice_event` without a `choice`.

## Validators and tools

- Here: `tools/build_event_names.py` generates the registry;
  `tools/project_event_definition.py` projects a site - `--event` from a
  catalog row, `--site <registry id>` from the analysis-group profiles that
  declare it (Core 0.323.0) - and, given the package, writes the tracked
  projection and the resolved document; `tools/content_suite/cli/replay_event_dialogue.gd`
  captures the message records per catalog preset, and the analysis-group
  validator's `--replay` output (`tools/content_suite/validators/validate_event_analysis_group.gd`)
  captures them per profile variant from the same runs the batch checks
  perform; `tools/project_event_definitions_batch.py` projects every registry
  row and validates each document, writing an index;
  `tools/validate_event_definition.py` validates a document against this
  contract and, given a package directory, resolves every `text_ref` and
  member hash; `tests/test_event_definition_contract.py` runs the fixture set
  and checks both recorded fingerprints, and `tests/test_project_event_definition.py`
  the profile-path mapping rules.
- In the remake, under the owner's 2026-09-14 ruling: its contract document
  raised to v3, the mirrored fixture set and registry, a GDScript validator
  and a fixture test recording the same fingerprints, and its TODO entry for
  the adoption. Executing the new condition, effect and terminal kinds in
  its game shell stays the remake's own backlog. Landed there on
  2026-09-15; the ruling is closed and the remake is not edited from here
  again.

## Projection of every registry site, 2026-09-16

With the package carrying every analysis-group source member (Core 0.323.0)
the batch driver projected the 142 registry sites - 13
from catalog rows, 129 from profiles - against package
`bf3d1f6e...`: 138 documents written, 138 valid under the
recorded fingerprints with every `text_ref` and member hash resolved,
4 invalid. The four invalid sites are catalog rows whose replay the bounded route probe cannot finish: EVENTB14, EVENTD05 and EVENTD06 stop inside shared routine 25 at a library definition invoke, and EVENTD14 needs definition 21, registered by a caller prefix that no recorded analysis route replays; the Event Player proves those four with its own runner, and the follow-up is to record their analysis routes as EVENTJ04's or to declare them as analysis groups so the profile path covers them. The documents are tracked under
`config/event_definitions/v3/` with the index, by the owner's decision (A)
of 2026-09-16; the mod player reads them from this repository and resolves
the text against its own package copy. The resolved twins with text are
written to a local directory through `--resolved-out`, never tracked, and
`tests/test_event_definitions_tracked.py` checks every tracked document
against the contract and the recorded fingerprints, refuses text and
non-Latin strings outside the registry titles, and ties the index to the
files present.

The profile path follows the mapping table above with these recorded
choices: the preferred profile of a site declared by several is the one with
map-location contracts, else the highest schema version; results are the
preferred profile's routes, variants grouped by outcome signature (message
sequence and callee terminal; an effect whose final value depends on the
entry state - a counter, a clock - is reported in `unresolved` rather than
multiplied into results, since v3 has no delta effect); a caller's
question is the top-level `choice` (`before_event`) and the callee's answers
nest under it; the body `after` is the route's `expected_state`; a
continuation route's result points at the resume terminal and the callee
return stays listed; `event_not_completed` names the guard's cleared flag
that the event sets to 1 when there is one (73 of the 129 profile sites),
and is omitted with a note when the reentry is gated inside the callee (the
done cell of those sites is a probe follow-up); the caller's messages after the event (the
resume) are counted in `unresolved`, not projected - v3 carries the callee's
dialogue only, which a definitions-only mod player will need revised (a v4
candidate: resume dialogue).

## What stays unresolved

Native presentation and media (deferred with the package), the caller-owned
completion terminals outside the package (`12C.MES` / `13C.MES`), the
resume's own messages after a nested-call event, bypass variants other than
a caller question's skipping answer, the historical v1-v4 GROUND groups'
origins, and every "Measured and not declared" note - all copied into
`unresolved` so that no document claims more than its evidence.
