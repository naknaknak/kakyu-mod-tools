# Event Definition v7 (`kakyu_event_definition/v7`)

Status: **contract landed 2026-10-08** (WD-21 U2, checkpoint C3: this design
document, the conformance fixture set `config/contracts/event_definition_v7/`, the
validator `tools/validate_event_definition.py` and its tests) and **producer and
set landed the same day** (C4: `tools/project_event_definition_v7.py` and the 681
tracked documents of `config/event_definitions/v7/`, "The producer" below).
**The catalog is promoted from this set** since C5 (2026-10-08, catalog revision 41:
`tools/promote_analysis_groups.py` reads `config/event_definitions/v7/` and refuses a
set that is not v7; the row item is described in `docs/spec/tech/event_player.md`);
the set was **rebound** (C6, 2026-10-08) to the package that carries the revised
catalog, `874f53ca...` (catalog revision 41; was `b638bd7d...`), and again (TD-57
C4, 2026-10-09, `tools/rebind_event_definitions.py --pair core-version`) to the
Core 0.374.0 export `5ae6aabe...`, a third time (TD-64 C4, 2026-10-10, the same
tool and pair) to the Core 0.375.0 export `ede69366...`, and a fourth time (TD-64
part 2 C4, 2026-10-10, the same tool and pair) to the Core 0.376.0 export
`47b1ee8de1d91558a428a11fb3e3a1f6f5acd8a5775212ff76c1c49a3d9324cd`, which differs from
it in `package_sha256` and `content_core_version` alone; **TD-56 C4b (2026-10-11) re-projected the whole set**
(a rebind is refused by design when a Core change moves runs) against the Core 0.377.0 export
`3af3779f...` (catalog revision 42), with the `LIBLARY.LIB` items restored (below), and **rebound** (TD-56 C5,
2026-10-11, `--pair catalog-revision`) to the export of the catalog promoted from it (revision 43),
`0e47e063e8fd9a80621e48e180b89fcb2547f966fc7fc8e59550ab92cab9ab96`, which differs from it in `package_sha256` and
`source.catalog_revision` alone, and again (EP-14 C4, 2026-10-11, `--pair core-version`) to the Core 0.378.0 export
`fe9bb6bd3256189ab9dd1ff91d75f95d378d8b625aae7e011ba16ccbb849f288`, the **live binding**, which differs from it in
`package_sha256` and `content_core_version` alone;
`config/event_definitions/v6/` is frozen at the earlier package. The sharing rule of 2026-09-16 stands:
`config/contracts/event_definition_v7/` changes here only, a revision of its
shape is a new directory beside it, and the remake reads it from this
repository. `event_definition_v3/` to `event_definition_v6/` are frozen:
untouched by this contract.

## Why v7 exists

Every document of v3 to v6 carries `presentation: {"status": "deferred",
"resources": []}`; no tracked document in any revision ever held an item, and no
validator looked inside the field. The owner ruled on 2026-10-06 (WD-21) that
each row's `resources` are to be taken from the **measured route**, not from a
static over-approximation of the member scripts: the media the instrument's own
runs of the row actually reach, in the vocabulary of the package's
`media_inventory` (`docs/spec/data/workspace_playback_export.md`, WD-21 U1), so
that the mod player can tell what an event needs, and report what it cannot
show, without the archive.

The item the earlier contracts describe, `{name, source_offset, kind}`
(`docs/spec/data/event_definition_projection.md`, "Presentation"), cannot carry
that. A flow document's hops run in different entries, a site document runs a
caller prefix and a callee, and a route also loads what the shared `LIBLARY.LIB`
routines and the `DEF_MAIN.MES` definitions it calls request; a `source_offset`
without the entry it is relative to is ambiguous. Adding the entry and fixing and
checking the vocabulary is a change of the document's shape, and the rule of
`AGENTS.md` ("Boundary With `kakyu-remake`") makes a change of shape a new
directory beside the old, as v5 (`visits`) and v6 (`flow`) were. v7 is that new
directory: v6 plus exactly one rule. The owner's 2026-10-06 wording named "v6
`presentation.resources`"; this is a tool decision under that rule, confirmed by
the owner on 2026-10-08 (`todo/workspace_distribution.md`, WD-21).

## The document

A v7 document is a v6 document (`docs/spec/data/event_definition_v6.md`, and
through it v5 and v4) with these changes; every v6 rule not listed here holds
unchanged, a `flow` and `visits` included:

| Field | v7 |
|---|---|
| `schema_version` | `"kakyu_event_definition/v7"` |
| `contract_fingerprint` | the v7 fixture set's own fingerprint |
| `presentation` | exactly `{"status": "deferred", "resources": [...]}` with the item rule below; v6 never checked more than that the field exists |

`presentation.status` stays the literal `"deferred"` (`bad_presentation`
otherwise): media extraction stays deferred, v7 names media and extracts none.
`presentation` has exactly the keys `status` and `resources`: v7 fixes this field,
so a missing or an extra key fails the same way (`bad_presentation`).

### A resource item

`presentation.resources` is a list of items, each exactly these four keys
(`bad_resource_item` for a missing or an extra key, or an item that is not an
object):

| Field | Rule |
|---|---|
| `entry` | the package member the record is in: a **safe leaf** name, the catalog's rule (`content_core/event_catalog.gd`; `payload_values.is_safe_leaf`): non-empty, none of `/`, `\`, `..`, `:` (`bad_resource_entry`). With `--package`, one of the bound package's `entries[]`. `LIBLARY.LIB` and `DEF_MAIN.MES` are package entries although a document's `evidence.members` does not list them, and are valid here |
| `source_offset` | the code-relative offset of the record, an integer >= 0 (`bad_resource_offset`; a boolean is not an integer). For `LIBLARY.LIB` it is library-code-relative and for `DEF_MAIN.MES` definition-code-relative, the base the package's inventory uses for the same member |
| `kind` | one of `mmo`, `ax`, `voice`, `se`, `a6`, `bgm`, `unclassified` (`bad_resource_kind`): the inventory's vocabulary, with the rules of `docs/spec/mes/media_references.md` |
| `name` | the inventory's normalized name: **upper-case, non-empty and a safe leaf** (`bad_resource_name`). The catalog item the promoter derives from the item carries the name as its `entry`, which the catalog refuses unless it is a safe leaf; the one predicate is `payload_values.is_safe_leaf` |

The list is **sorted** by the tuple `(entry, source_offset, kind, name)` -
`entry`, `kind` and `name` by Unicode code point, `source_offset` as a number
(`unsorted_resources` for a descent) - and has **no duplicate**, an item equal to
the one before it (`duplicate_resource`). `[]` is allowed: a route that reaches
no medium.

### With a package

`validate_event_definition.py <document> --package <dir>` additionally checks a
document that has items against the bound package (the existing
`package_binding.package_sha256` check runs first):

1. the manifest must carry a `media_inventory` block with a **known schema id**
   (`kakyu_media_inventory/v1`, the id `tools/build_known_absent_media.py`
   reads) and a `members` list of `{entry, occurrences}` rows; a package without
   the block, or with another id, or a malformed one, is refused
   (`unknown_media_inventory`). A document with `resources: []` needs none of
   this and is accepted against any package;
2. every item's `entry` is one of the manifest's `entries[]`
   (`resource_entry_not_in_package`);
3. every item is an **occurrence of the inventory**: the `members` row whose
   `entry` is the item's holds an occurrence `{at: source_offset, kind, name}`
   (an occurrence may carry an `evidence` label, which is not compared); a member
   with no row has no occurrence (`resource_not_in_inventory`).

So an item is never a claim of its own: it is a pointer into the package's
classified occurrences, and the identity of the name (which original archive
ships it, or that every archive of its kind was searched and none does) stays in
the inventory's `names` and in the known-absent register
(`config/event_catalog/known_absent_media_v1.json`) rather than being repeated in
every document. Without `--package` only the shape rules run, as for the text
references.

## What the list means

**The measured route** is the producer's rule (WD-21 U2, decisions D1 and D6 of
its spec): a row's resources are the package's classified occurrences whose
record a measured run of the row **executed**, unioned over every replayed
variant of the routes the document's `evidence.groups[].route_ids` name - for a
site variant its caller prefix, callee, resume, reentry and visit runs, for a
flow every hop - including the `LIBLARY.LIB` routines and the `DEF_MAIN.MES`
definitions those runs called. The offsets come from the group replay's
`executed` field (`kakyu_event_analysis_group_replay/v3`, `tools/README.md`,
`tools/content_suite/replay_run_media.gd`), joined with the inventory, which keeps
one classification (what a record is) for every kind. A medium in a member
script that no measured run reaches is not listed.

Three limits of that list are part of the contract:

- **One list per document.** It is the union over the document's routes and all
  their replayed variants: a consumer gets "everything this event can need".
  There is no attribution to a result, a variant or a hop, and no field for one;
  a later contract can add it if asked. A `duplicate_route` document has its own
  document's list.
- **What the instrument reaches, not what the native host loads.** The list
  says what the measured runs executed. A medium behind a mechanism the
  instrument does not model is absent from it, and a medium the host would
  construct at runtime without a record is not an occurrence at all.
- **Nothing is extracted.** `status` stays `deferred`; a listed name may be one
  the original archives do not ship (the inventory says so).

**Library occurrences were held back from 2026-10-08 until TD-56 (owner ruling, WD-21), and are
listed since 2026-10-11.** The live v7 documents and the catalog listed **no `LIBLARY.LIB`
occurrence**, although the contract kept `LIBLARY.LIB` a valid `entry` and the group replays kept
the library offsets. The reason was a measurement limit, not a property of the route: the shared
library's media ladders (routine 9, the sound effects; routine 27, the place backgrounds) select
on `global_i32[1]`, while the generic runner kept command-`0x09` writes in the argument slots
only, although the original reads and writes one storage (`docs/spec/mes/audio.md:604-614`), so
every measured library entry saw selector 0: routine 9 (468 runs) reached 0 of the 78 sound
effects, and routine 27 (3,839 runs) always took its selector-0 `BLACK.MMO` arm, which would have
entered 272 of the 681 rows as a tool artifact. **TD-56 (Core 0.377.0, `todo/code_health.md`)
models the one storage** (`docs/spec/mes/format_and_method.md`, "Command `0x09` and token `0xF6`
address one storage"), the replays regenerated, and the C4b re-projection lists the library
items: 1,093 items in 293 documents, 251 distinct (`mmo` 106, `se` 25, `unclassified` 120), every
one a record start of the library and an inventory occurrence of its kind and name (a
library-relative coordinate, never a `DEF_MAIN.MES`-relative one: TD-55). The 12 `DEF_MAIN.MES`
items are unchanged (that member reads no `global_i32`). The catalog's rows follow at TD-56 C5. The
record of the 2026-10-08 ruling is `todo/workspace_distribution.md`, WD-21.

## The producer (WD-21 U2 C4)

`tools/project_event_definition_v7.py` wraps `tools/project_event_definition_v6.py`'s
whole pipeline for the v6 body (the schema string and the fingerprint only) and then
fills `presentation.resources`, the way v5's `inject_visits` fills `visits`; `py
tools/project_event_definitions_batch.py --contract v7 --replays-dir analysis/replays_v3
...` projects and validates the whole set (the argument list is in
`config/event_definitions/v7/README.md`). The list of one document is the D1 join
described above, computed from the group replays' per-run `executed` offsets and the
bound package's `media_inventory`. The producer fails closed (exit 1, the written
document removed) on any of:

- a replay that is not `kakyu_event_analysis_group_replay/v3` or not the profile's
  (`group_id`, `payload_sha256`); a document whose `profile_sha256` matches no or more
  than one profile of its group; a route, or a variant the profile declares, without a
  replay;
- a run that exists - a site variant's callee, resume, reentry and each visit, its
  prefix when `reached`, a flow's each hop - without an `executed` set or with an empty
  one (an unreached prefix, `reached: false` with `{}`/`[]`, is not a run);
- an `executed` member that is not an entry of the package, or an `executed` offset
  that is not a record start of that member in the package's own records (a
  coordinate-base sanity check, library and definition offsets included);
- a joined occurrence with an empty name;
- a `resource_rows` row - the media effects of the run's own entries - that the
  inventory does not confirm: a marker effect (`mmo_resource_marker`,
  `ax_resource_marker`, `voice_marker`, `effect_request`) without an occurrence of the
  mapped kind (`mmo`, `ax`, `voice`, `se`) and the same name at its `(entry, at)`; a
  `bgm_request` whose name is not the name of a `bgm` occurrence joined from the same run
  (the BGM occurrence sits at the slot write, not at the request).

A catalog-event projection (`--event`) is refused: it has no measured replay. Each
projected site prints one `RESOURCES_STATUS` line and the batch sums them.

**Measured on the 681 rows (2026-10-08).** Every document lists at least one item
(smallest 1, median 15, largest 345); 17,020 items in all, 14,710 distinct: `voice`
9,422 (9,113 distinct), `mmo` 3,514 (2,972), `bgm` 1,755 (1,288), `ax` 1,307 (1,022),
`unclassified` 1,022 (315), no `se` and no `a6`; 16,896 in route entries and 124 in
`DEF_MAIN.MES` (12 distinct). Each document equals its v6 document in every other
field. `config/event_definitions/v7/README.md` records the run.

**Measured on the 681 rows after TD-56 (2026-10-11, Core 0.377.0, export A).** The same rules over the
regenerated replays: 18,113 items in all (17,020 before), 14,961 distinct (14,710): `voice` 9,422 (9,113
distinct), `mmo` 3,997 (3,078), `bgm` 1,755 (1,288), `ax` 1,307 (1,022), `unclassified` 1,530 (435), `se`
102 (25), no `a6`; 16,896 in route entries (14,698 distinct), 124 in `DEF_MAIN.MES` (12) and 1,093 in
`LIBLARY.LIB` (251 distinct, in 293 documents); smallest list 2, median 16, largest 349. The growth
is exactly the library items. **v7 no longer equals v6 outside `presentation`:** all 681 documents differ
from the frozen v6 document in the delta classes of `tests/test_event_definitions_tracked.py`
(`v7_delta_violations`) and nowhere else: the library-set flag effects (`global_u8[4000]`, `[4090]`,
`[4091]` = 1 in `after`, `flow.hops[].after`, `results[*].after` and `evidence.effect_witnesses`, in 419
documents, 2,406 rows each), the labelled call-argument-storage `unresolved` records of D11
(`event_definition_v4.md`, "Effects"; 1,261 lines in 679 documents), the flow flag lines the witnesses
cannot decide (166 in 35), the `[4000]` "witness outcome 'other'" lines that leave `unresolved` (58 in 51
documents), the selector-0 flag clears as the witness corpus decides them (`after` `write [4000] = 0`
with its `shift_witness` row: 42 added in 41 documents, 3 removed in 2), and the 13 documents whose profile
TD-56 C3 re-derived (their group hashes and the rows of the cells their pins moved on). The witness corpus the
set rests on is regenerated for all 161 profiles from the v3 replays (the C4b projection used one planned from
the pre-TD-56 replays and differed from this set in 39 documents, all of them the clears above).
`config/event_definitions/v7/README.md` ("2026-10-11 (TD-56 C4b ...)") has the counts per class.

## Fail-closed reasons added by v7

Each has an invalid fixture in `config/contracts/event_definition_v7/invalid/`
(a mutation of `valid/flow_resources.json`, one change per fixture):
`bad_presentation`, `bad_resource_item`, `bad_resource_entry`,
`bad_resource_offset`, `bad_resource_kind`, `bad_resource_name`,
`unsorted_resources`, `duplicate_resource`, and, with the fixture package,
`resource_not_in_inventory`, `resource_entry_not_in_package` and
`unknown_media_inventory` (this one against a second package whose inventory
carries another schema id; its `expected.json` entry names that package in a
`package` key). Every v3 to v6 reason applies unchanged where the rule
is the same. The checks run in this order: `presentation`, each item in turn (its
keys, then `entry`, `source_offset`, `kind`, `name`), the list's order and
duplicates, and only then the package. A document that breaks a shape rule
therefore fails the same way with or without `--package`.

## The fixture set and the validator

`config/contracts/event_definition_v7/` holds v6's valid and invalid fixtures
re-versioned (the `schema_version` line only), `valid/flow_resources.json` (six
items across a flow's two entries and `LIBLARY.LIB`, every one an occurrence of
the fixture package's inventory), the sixteen invalid fixtures above, a `package/`
whose manifest carries a minimal `media_inventory`, `package_unknown_inventory/`,
`expected.json`, the README and `contract_fingerprint` (computed by
`tools/contract_fingerprint.py`). The validator dispatches on `schema_version`,
as for v4 to v6, and without `--fingerprint` reads the v7 directory's own value
for a v7 document. `tests/test_event_definition_contract.py` runs the whole set
and exercises every rule above by mutation.

*Note, 2026-10-08:* the fixture set's own README (`config/contracts/event_definition_v7/README.md`) says
"no v7 document exists yet". That is the dated record of the C3 landing and is kept as written, because
the README is part of the fingerprinted contract bytes that all 681 documents embed (changing it would
move the fingerprint and re-stamp the set); the live status is this page and
`config/event_definitions/v7/README.md`.

## What stays open

Every v6 open item stays open (`docs/spec/data/event_definition_v6.md`, "What
stays open"). For the field itself: the catalog's per-row `resources` derived from
the set and the instrument's check that it plays no medium a row does not declare
(gate 3, `docs/spec/data/validation_checks.md`) landed in C5, and the rebind of the documents to
the package that carries the revised catalog in C6 (WD-21 U2, `todo/workspace_distribution.md`;
U2 closed 2026-10-09 with its closing batch, 477 of 477); the library items were restored by TD-56 (the
documents at C4b, the catalog's rows at C5, `todo/code_health.md`); the remake's adoption of v7 is its own
backlog.
