# Event Definition v4 (design draft)

Status: **implemented and frozen on 2026-09-18** - the contract statement is
[Event Definition v4](event_definition_v4.md); this document keeps the
design, its measurements and the rulings behind it. Scope by the owner's
rulings of the same day: v4 carries what a
definitions-only player needs to keep the game state right (relative effects,
the caller's lines in one dialogue flow, the done flag, a candidate order
hint); the effect cells are every cell a visit changes, not only the declared
ones; the v3 directory stays frozen; definitions a mod writes itself (new
events, edited conditions) become a **separate contract**, outlined at the
end; presentation stays deferred until media extraction and the animation
format are decided. The agreed v3 is described in
[Event Definition Projection](event_definition_projection.md) and is not
edited: a revision is `config/contracts/event_definition_v4/` beside v3,
made in this repository only, and the remake reads it from here. The text a
document refers to follows [Text Encoding](text_encoding.md): UTF-8, with
the original CP932 bytes kept only as a line's identity.

The remake validates v3 and does not execute it yet (its EP-08 is open), so
no running consumer breaks when the producer moves to v4.

## What v3 cannot say, measured on the 138 tracked documents

| Gap | Documents | Size | What a definitions-only player gets wrong |
|---|---:|---:|---|
| Effects whose final value depends on the entry state | 98 | 272 rows, 58 of them affection | the change is not applied at all |
| Counters that every measured variant entered with the same value | 13 | 16 absolute affection writes | v3 writes the measured FINAL value as an absolute effect: `ai.school.gate.09.1` sets affection to 92 whatever the player had |
| Changes the profile does not declare in `expected_state` | not yet counted | - | omitted: the station's G11 route raises affection from 80 to 81 in every stored variant and its document carries no affection effect |
| The caller's lines after the event (resume) | 63 | 1,226 messages in the stored replays | the scene ends one speaker early |
| The caller's lines before the dispatch (prefix) | 197 routes | 3,284 messages in the stored replays | arrival narration and the caller's own question text are missing |
| No done flag in the guard | 55 | - | the event repeats on every visit |
| Natural scheduling into the origin unknown | 77 | - | not a v4 matter: the map, not the event, owns it |
| Presentation | 138 | every `resources` list is empty, no voice marker | deferred by ruling |

*Note, 2026-10-08 (WD-21 U2):* the Presentation row is true of v3 to v6, whose `resources` lists
are empty by ruling. `kakyu_event_definition/v7` fills them from each row's measured route
(`event_definition_v7.md`); the 138 documents counted here are the draft's, not the live set.

The second and third rows were found while preparing this draft. When every
variant of a result entered with the same value, v3 cannot tell a set from an
add and writes the measured final value; a cell is only known to be set
rather than added to when a run that entered with another value ends on the
same value. And v3 projects only the cells a profile declares, so a change
the profile never named is not in the document at all.

## 1. Relative effects

### Vocabulary

`after` lists (the body's and each result's) accept a second row type:

```
{type: "add_legacy_value", storage, bank, index, delta}     delta: non-zero integer
```

`write_legacy_value` keeps its meaning. One list never carries both types
for the same cell. The remake's v2 vocabulary already names
`add_legacy_value`; v3 only refused to produce it.

### How the producer decides: the shift witness

The replay (the analysis-group validator's `--replay` and the catalog replay
CLI) gains, per variant, `entry_state`: the value of every cell of
`final_state` immediately before the dispatch. The effect cells of a result
are every cell its visit changed (`final != entry`), not only the ones the
profile declares in `expected_state`; a declared cell keeps `declared: true`
in its witness row so the two sources stay distinguishable. For each effect
cell the producer asks for a **shift witness**: the variant is replayed once
more with that one cell's entry value moved by a fixed step (default +7; the
step is recorded, and a step that changes the path is replaced as below).

| Witness outcome | Same messages and terminal? | Projected as |
|---|---|---|
| final moved by exactly the step | yes | `add_legacy_value`, `delta = final - entry` |
| final unchanged | yes | `write_legacy_value`, the final value |
| anything else | yes | `unresolved` (names the cell, both entries, both finals) |
| - | no: the shifted cell is a guard input and the path changed | retried with step -7, then +1, -1; if every step changes the path the row is `unresolved` |

The witness is evidence, so it is recorded in the document:
`evidence.effect_witnesses: [{result, cell, step, entry, final, shifted_entry, shifted_final, kind}]`.
A static cross-check - the typed write run that wrote the cell reads the same
cell - is added when the decoder names the instruction; it may only agree
with the witness, and a disagreement is an `unresolved` row, never a silent
choice.

### Results grouped by what they do, not by where they ended

v3's outcome signature is (message sequence, terminal); final values were
kept out of it because counters multiplied results. With effects projected as
`set` or `add` rows that objection is gone, so v4's signature is (message
sequence, terminal, effect rows). Two variants that say the same lines and
differ only in `add affection +3` versus `+5` (the station's H07 at clock
0931) become two results, each `selected_by` the conditions the existing
distinguishing-writes rule finds. A counter that climbs by the same delta in
every variant collapses into one row.

The clock is not linear (HHMM) and is projected as `consume_time` in minutes
(see the measurement below); a date or weekday change stays `unresolved`
unless the variants show a plain set.

### Unit 1a measurement, 2026-09-18: what a visit really changes

Replay v2 (`kakyu_event_analysis_group_replay/v2`) records the probe's state
diff of the lead-in, the scene and the continuation of every variant. Over
all 138 profiles (211 routes, 2,313 reached variants, regenerated in 22
minutes; the fields v1 and v2 share are identical in all 2,329 variants and
three v3 projections from v2 replays are byte-identical):

| Measure | Value |
|---|---:|
| State-change rows: lead-in / scene / continuation | 15,004 / 22,952 / 6,058 |
| Net changed cells per variant | 17.4 on average, 36 at most |
| Changed cells the profile declares | 22,055 |
| Changed cells it does not declare | 18,113 (45%) in 168 distinct cells |

The undeclared changes are not scratch, so the rule "every cell a visit
changes" stands:

- **Flags.** 128 distinct `global_u8` cells, 101 of which only ever go from 0
  to 1, 65 of them written only in the caller's lead-in.
- **Affection.** 20 sites change an affection cell their profile never names,
  by -10, -3, -2, -1, +1, +2, +3, +10 and +50.
- **Time.** 104 routes move the clock (`state_u16[19]`, with its parts
  `state_u16[0]` and `[1]`); 99 of them by the same number of minutes in
  every variant - 10, 15, 20, 30, 45, 60, 120, 195, 240 or 300 - and the five
  others differ only by a wrap past midnight. v4 therefore projects
  `{type: "consume_time", minutes}` (the remake's v2 vocabulary already names
  it) instead of leaving the clock unresolved; the three clock cells are not
  listed again, and the day change is the consumer's calendar.
- **Working registers.** The routine-40 result `state_u16[21]`, the map poll
  result `state_u16[18]`, `banked_u16[1]` (always +7) and `state_u16[25]`
  and `[10]` change in most visits. They are state, so they are listed, but
  each effect row carries a `cell_class` from one tracked table
  (`weekday`, `date`, `clock`, `choice_result`, `map_poll_result`,
  `affection.<heroine>`, `flag`, `unnamed`) so a consumer that owns its own
  choice and map mechanics can leave them out by class.

What the variants already decide, by result group (messages and terminal,
299 groups): 84 cells are a set (entries vary, one final value), 122 an add
(entries vary, one delta), 96 vary inside the group and either split it by a
condition or stay unresolved, and 5,068 are ambiguous because every variant
entered alike. Only the ambiguous ones need a shift witness, and 2,866 of
them are flags: a `global_u8` cell observed only as 0 to 1 is projected as
`write 1` with `basis: "flag_pattern"` and no witness, which leaves about
2,200 witness runs - roughly one more pass of the 2,329 variant runs.

### Unit 1b measurement, 2026-09-18: set or add, and the done cell

`tools/plan_event_effect_witnesses.py` turns the v2 replays into requests
(`kakyu_event_effect_witness_request/v1`) and the validator's `--witness`
mode answers them without a single check (`kakyu_event_effect_witness/v1`,
run order, one control row per done probe: the reentry on the unmodified
post-visit state). Over the 138 profiles, 299 result groups:

| Planned | Count |
|---|---:|
| Shift requests (every variant entered alike, not a flag, not the clock) | 2,671 |
| Skipped: clock cells / entries vary / flag pattern | 363 / 215 / 2,121 |
| Done-cell probes (groups whose reentry emits nothing) | 194 |

| Shift result | Other cells | Affection cells |
|---|---:|---:|
| `set` (the shifted entry ends on the same final value) | 2,462 | 5 |
| `add` (the final moves by the step) | 25 | 70 |
| `other` (same path, neither) | 74 | 8 |
| `path_changes` (every step changes the messages or the terminal) | 21 | 6 |

| Done-cell probe | Groups |
|---|---:|
| exactly one gate cell - every one a `global_u8` flag | 191 |
| several | 0 |
| none (GROUND F02, K_PIC arrival and continuation) | 3 |

What the witnesses say that the variants could not: four sites SET affection
rather than add to it (15C's I10 puts it at 25 whatever it was; MACHI's E04,
E10 and E18 put it at 50), the station's H07 and K06 add +3 at 0 but +1 at
7 (entry-dependent, kept as `other`), and G01's three sites and G08's
arrival guard on the affection they change, so no step keeps the path
(`unresolved` with the tried steps recorded). The 191 gates are the cells
`event_not_completed` names for the callee-gated sites.

A first run of this unit reported 286 `add` and 31 groups with several
gates. Its control row exposed the cause: the witness mode had not set the
validator's `runtime_schema`, which decides the owner of a selection, so
caller-side selections went unmatched and the unbroken run stopped early at
a definition-selection boundary (01M's M06: 28 messages instead of 154, and
every restored cell "replayed" a scene the baseline itself replayed). With
the field set as the normal path sets it, 257 of those `add`s became `set`
and M06 has one gate, `global_u8[2438]`. A quiet re-run mode must reproduce
every member the normal path sets, and it always carries a control run.

### The affection cells, fixed on 2026-09-18

No document fixed which `banked_u16` cell is which heroine's affection; the
v3 producer therefore never emitted an `affection` conjunct in production.
Three measurements agree and fix it. Over the v2 replays, the cell an
`EVENT<letter>xx` callee changes most (variant counts): A 201 (129), C 206
(37), D 212 (32), E 202 (19; E's events also raise L's 209), F 200 (17),
G 204 (109), H 207 (21), I 203 (51), J 211 (119), K 208 (91), L 209 (146).
Over the tracked v3 documents, the cell an `EVENT<letter>xx` guard tests:
A 201 (11), C 206 (9), E 202 (3), F 200 (3), G 204 (3), H 207 (8), I 203
(9), J 211 (6), K 208 (3), L 209 (13). The documents fix the rest: B is
`[210]` (`01m_caller_group.md`, the EVENTB03 route documents), D `[212]`
(`normal_conversation.md`), E `[202]` (`machi_caller_group.md`), M `[205]`
(`44m_caller_group.md`). No measured route changes `[213]`.

| Cell | Heroine | Letter | Cell | Heroine | Letter |
|---|---|---|---|---|---|
| `banked_u16[200]` | reiko | F | `banked_u16[207]` | miyuki | H |
| `banked_u16[201]` | miko | A | `banked_u16[208]` | ai | K |
| `banked_u16[202]` | mizuho | E | `banked_u16[209]` | sizuka | L |
| `banked_u16[203]` | mayumi | I | `banked_u16[210]` | mahoko | B |
| `banked_u16[204]` | ryoko | G | `banked_u16[211]` | minatu | J |
| `banked_u16[205]` | tina | M | `banked_u16[212]` | maki | D |
| `banked_u16[206]` | nana | C | `banked_u16[213]` | unassigned | - |

The cell-class table carries this with each row's evidence, and `[213]`
stays `unnamed` until a measurement names it.

## 2. One dialogue flow per result

Decided by the owner on 2026-09-18 after the measurement below: the split
between the caller's lines and the callee's is how the original files are cut,
not how the event reads, and the remake is free to arrange its script. So v4
adds no `prelude` and no `resume` list. `dialogue` (the part every result
shares) and `results[<id>].dialogue` (the rest of one result, to its end)
simply stop filtering the caller's messages out: a flow runs from
`trigger.origin` through the caller's lead-in, the callee's scene and the
caller's continuation to the result's terminal. Every entry keeps its
`text_ref` (`entry`, `at`, `s`, `raw_sha256`), so a line's source script stays
traceable without a role field.

Measured on the stored replays (131 sites): 2,212 caller lines precede the
dispatch and 1,226 follow the return; 86% of the lead-in lines belong to one
event only and no two sites share a whole lead-in. In the 97 sites whose
origin is the typed guard every lead-in line lies after the guard, so the
original already skips lead-in, scene and continuation together once the
guard's done flag is set - a whole-chunk "seen" state reproduces it.

Three things stay marked inside a flow, as entries of their own kind:

| Entry | Meaning |
|---|---|
| `{kind: "choice_point", choice: <key>}` | where a question is asked; the caller's question before the event keeps `position: "before_event"` in `choice` |
| `{kind: "scene_end"}` | the callee's scene is over: the point where `after` effects and the done state apply; a result with `event_played: false` has none |
| a `text` or `name_insert` entry with `location_line: true` | a line that is the location's, not the event's: it lies before the guard (150 lines, all in the 32 sites that start at a map arrival or a caller prefix) or also precedes another event site of the same caller (318 lines). The consumer may play it from the location instead; nothing else distinguishes it |

Known and accepted difference from the original: at the 55 sites whose guard
holds no done flag the original repeats the lead-in on a revisit and skips
only the scene; a consumer that keeps a whole-chunk seen state skips all of
it. The owner prefers that.

### Candidate order hint

When several unseen events are possible at one place the original takes the
one its caller script tests first. v4 carries that as a hint, not as a rule:

```
trigger.order_hint   {scope: <caller entry>, rank: <1-based>, of: <sites in scope>,
                      basis: "guard_offset", chain_confirmed: true|false}
```

`rank` orders the sites of one caller by the offset of their typed guard.
`chain_confirmed` is true when the guard's `false_target` leads to the next
ranked site's guard with no other site's guard between them, which is what
makes offset order the evaluation order; otherwise the rank is positional
only. Sites without a typed guard (the catalog rows) carry no hint. What
schedules the caller itself stays outside the event definition.

## 3. The done flag when the guard does not hold it

For the 55 sites whose reentry is gated inside the callee the producer runs a
**done-cell probe**: after the first visit, each cell the visit changed is
restored alone to its entry value and the reentry is replayed. A cell whose
restoration makes the event play again (the first visit's message signature)
is a done gate.

| Probe result | Projected as |
|---|---|
| exactly one gate cell | `event_not_completed` with `done_cell` and `source: "reentry_probe"` |
| several | the first by cell order, all listed in `evidence.done_probe`, and an `unresolved` note |
| none | `unresolved`, as today |

The 74 sites whose guard holds the flag keep theirs with `source: "guard_flag"`.

## Contract mechanics

- `schema_version: "kakyu_event_definition/v4"`; fixture set
  `config/contracts/event_definition_v4/` with its own `contract_fingerprint`
  by the v3 rule; the name registry and `names_fingerprint` are unchanged.
- New fail-closed rules, one invalid fixture each: a zero or non-integer
  `delta`; `add` and `write` rows for one cell in one list; a `choice_point`
  naming no `choice`; more than one `scene_end` in a flow, or one in a result
  with `event_played: false`; a `location_line` on an entry that is not a
  line; an `order_hint` whose `rank` exceeds `of` or whose `scope` is not the
  caller; a `done_cell.source` outside the two values; an `effect_witnesses`
  row whose numbers contradict the effect it supports.
- Replay output becomes `kakyu_event_replay/v2` (`entry_state`, the shift
  witnesses, the done probe). Stored v1 replays are regenerated, not migrated.
- Documents go to `config/event_definitions/v4/` with their own index. The v3
  directory stays frozen until the owner retires it: the remake's fixture
  test pins v3 today.
- `tools/validate_event_definition.py` accepts both versions by
  `schema_version`; the remake's validator is its own backlog.

## Work units, in order

1. (1a and 1b done 2026-09-18: replay v2, the witness planner and the
   validator's witness mode; both measurements are recorded above.) Replay v2 in the analysis-group validator and the catalog replay CLI, then
   a measurement run over all 142 sites: how many effect rows become `add`,
   `set` or stay unresolved, how many changed cells no profile declares, how
   many done cells the probe finds. The numbers are recorded before the
   contract is frozen; if undeclared changes turn out to be mostly scratch
   cells, the draft is revised before unit 2.
2. The v4 fixture set, the validator and the producer; project every site;
   track the documents; `tests/test_event_definitions_tracked.py` for v4.
3. Documents and trackers; a note for the remake's backlog, written here.

The four sites without a v3 document (EVENTB14, EVENTD05, EVENTD06, EVENTD14)
are a separate follow-up and do not block v4.

## Authored definitions - the separate contract, outline only

Working name `kakyu_mod_event_definition/v1`. A projected document is bound
to evidence and may not carry text; a mod's own document has no original
evidence and carries its own text, so the two do not share a schema.

- `new_event`: an id in the mod's namespace (`mod.<mod id>.<name>`), a
  trigger by scene kind and place with `conditions` in the v4 vocabulary,
  inline `text` dialogue, `choice` and `results` in the v4 shapes, effects
  `write`/`add` and the remake-owned kinds (`set_flag` and the rest).
- `override`: names one registry id and the `payload_sha256` of the projected
  document it was written against, and replaces `conditions`, effects or
  whole results, or disables the event. A changed base document fails closed.
- It lives in the mod workspace and travels with the mod, never under
  `config/` here; this repository supplies the validator and the editor.

Its design is the next draft after v4's first unit has produced numbers.
