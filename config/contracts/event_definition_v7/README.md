# `kakyu_event_definition/v7` conformance fixture set

This directory is the conformance fixture set for the
`kakyu_event_definition/v7` document shape described in
`docs/spec/data/event_definition_v7.md` (the contract; v7 is v6 plus exactly
one rule, the shape of `presentation.resources` - see the base shape in
`docs/spec/data/event_definition_v4_design.md`, the `visits` addition in
`docs/spec/data/event_definition_v5.md` and the `flow` addition in
`docs/spec/data/event_definition_v6.md`). It is built the same way
`config/contracts/event_definition_v6/` was: a fixture set with a
`contract_fingerprint`, a validator that accepts every valid fixture and
rejects every invalid one for the recorded reason, computed by
`tools/contract_fingerprint.py`. It does not replace v6: `event_definition_v6/`
stays byte-identical, unedited by this unit. This unit (WD-21 U2, checkpoint
C3) lands the contract only - design document, fixture set, validator, tests.
The projector and the tracked v7 documents are later checkpoints of the same
unit; no v7 document exists yet.

- `valid/` holds v6's own eight fixtures re-versioned (the `schema_version`
  line only; each carries `presentation: {"status": "deferred", "resources":
  []}`, which v7 allows: a route that reaches no medium) plus
  `flow_resources.json`: `flow_event.json` with six `resources` items across
  the flow's two entries and the shared library -
  - `CALLEE` 70 `voice` `V0001.OGG`, 80 `ax` `ANIM1.AX`, 80 `mmo` `PIC1.MMO`
    (two items at one offset: the order falls to `kind`);
  - `CALLER` 30 `bgm` `THEME.WAV`;
  - `LIBLARY.LIB` 1481 `unclassified` `IDOU.WAV`, 2210 `se` `BELL.WAV`
    (`LIBLARY.LIB` is a package entry that is not in `evidence.members`).

  Every item is an occurrence of `package/`'s `media_inventory`, which also
  holds occurrences the document does not list (the inventory is a superset of
  what a route reaches). The `[]` case is carried by the eight re-versioned
  fixtures, three of which (`flow_event.json`, `package_resolved.json`,
  `visit_chain_event.json`) are bound to `package/` and so are checked as "an
  empty list against an inventory that holds occurrences for the document's own
  members".
- `invalid/` holds every v6 invalid fixture re-versioned to v7 (same reason
  codes, `event_definition_v6/README.md`'s own list; `wrong_schema.json` is
  byte-identical to v6's, it carries `kakyu_event_definition/v2`) plus one
  fixture per v7-only failure, each a mutation of `valid/flow_resources.json`:
  - `resource_missing_key.json` - an item without `kind` (`bad_resource_item`).
  - `resource_extra_key.json` - an item with a fifth key (`bad_resource_item`).
  - `resource_negative_offset.json` - `source_offset` is `-1`
    (`bad_resource_offset`).
  - `resource_unknown_kind.json` - `kind` is `music` (`bad_resource_kind`).
  - `resource_lower_case_name.json` - `name` is `v0001.ogg`
    (`bad_resource_name`).
  - `resource_empty_name.json` - `name` is `""` (`bad_resource_name`).
  - `resource_unsafe_name.json` - `name` is `SUB/V0001.OGG`, not a safe leaf
    (`bad_resource_name`; the promoter maps a name to a catalog item's `entry`).
  - `resource_unsafe_entry.json` - `entry` is `../CALLEE`
    (`bad_resource_entry`).
  - `resources_unsorted.json` - the first two items swapped
    (`unsorted_resources`).
  - `resources_duplicate.json` - the first item repeated
    (`duplicate_resource`).
  - `presentation_status_extracted.json` - `presentation.status` is
    `extracted` (`bad_presentation`).
  - `presentation_extra_key.json` - `presentation` carries a third key
    (`bad_presentation`: exactly `status` and `resources`).

  These twelve are shape rules and are checked with no package. Four more fail
  only against the package they bind (`PACKAGE_BOUND_FIXTURES` in
  `tests/test_event_definition_contract.py`):
  - `resource_not_in_inventory.json` - the first item at offset 71, where
    `CALLEE` has no `voice` `V0001.OGG` occurrence
    (`resource_not_in_inventory`).
  - `resource_member_without_row.json` - an item in `DEF_MAIN.MES`, a package
    entry that has no row in the inventory's `members` (a member with no row
    has no occurrence; `resource_not_in_inventory`).
  - `resource_entry_not_in_package.json` - an item in `NOPE.MES`, which is not
    an entry of the package (`resource_entry_not_in_package`).
  - `resource_unknown_inventory_schema.json` - the same document as
    `valid/flow_resources.json`, checked against `package_unknown_inventory/`,
    whose `media_inventory.schema` is `kakyu_media_inventory/v2`, an id the
    validator does not know (`unknown_media_inventory`).

  `expected.json` maps every relative path under `valid/` and `invalid/` to
  `{"ok": bool, "reason": code}`; an entry that names a `package` (a directory of
  this set, here `package_unknown_inventory` for
  `resource_unknown_inventory_schema.json`) is checked against that package, and
  the other package-bound fixtures against `package/`.
- `package/` is v6's own minimal, invented `kakyu_playback_package/v7` package
  plus two package entries (`LIBLARY.LIB`, `DEF_MAIN.MES`) and a minimal
  `media_inventory` block in the shape of a real package's: `schema`
  (`kakyu_media_inventory/v1`), `normalization` (`upper_case`) and `members`, a
  list of `{entry, occurrences: [{at, kind, name, evidence?}]}` rows, only for
  members that have any. It carries none of the block's other keys (the rule
  tables, the identity table, the counts): the validator reads these three, and
  the block is not loadable by the Core reader. `package_unknown_inventory/` is
  the same package with `media_inventory.schema` `kakyu_media_inventory/v2`.

Fixtures here are hand-built and carry no original dialogue text, no machine
paths and no original data beyond synthetic coordinates, invented media names
and synthetic 64-hex-character hashes, exactly as in v6's own set.

## Fingerprint

`contract_fingerprint` is the SHA-256 over the concatenation of
`"<relative path>\t<sha256 of the file bytes>\n"` for every file under this
directory except `contract_fingerprint` itself, paths relative to this
directory with `/` separators, sorted, LF line endings - computed by
`tools/contract_fingerprint.py`. A later revision of the shape is a new
directory beside this one, never an edit of `v7` in place, following the same
rule v4/v5/v6 follow.

## The `"self"` convention

As in v3 to v6: every hand-written fixture's own `contract_fingerprint` and
`names_fingerprint` are the literal string `"self"`, accepted by
`tools/validate_event_definition.py` as equal to the value passed with
`--fingerprint`/`--names` (without `--fingerprint`, the validator reads this
directory's own `contract_fingerprint` for a v7 document). The `invalid/`
fixtures that exercise the fingerprint and names rules do not use `"self"`.

## See also

`docs/spec/data/event_definition_v7.md` is the contract this set implements.
