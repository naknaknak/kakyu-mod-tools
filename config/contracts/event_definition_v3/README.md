# `kakyu_event_definition/v3` conformance fixture set

This directory is the WD-22 conformance fixture set for the
`kakyu_event_definition/v3` document shape described in
`docs/spec/data/event_definition_projection.md`. It is mirrored
byte-identically in `kakyu-remake` under the same path, so that both
repositories' validators are exercised against exactly the same documents.

- `valid/` holds one minimal hand-written document per `kind`, trigger
  origin and terminal kind that a validator must accept: `plain_event.json`
  (kind `event`, `typed_guard` origin, a `natural_handoff` terminal, a
  `name_insert` dialogue entry), `choice_event.json` (a callee-owned choice,
  `callee_return` and `root_handoff` terminals, a `reentry`),
  `caller_question_skip.json` (a caller-owned question with an
  `event_played: false` result and a `root_handoff` terminal),
  `map_arrival_train.json` (`map_arrival` origin, a `train_ride` scene,
  `caller_menu_loop` and `def_selection_boundary` terminals) and
  `catalog_event.json` (`evidence.kind: "catalog_event"`, `caller_prefix`
  origin, no guard, an `event_not_completed` condition with `done_cell`,
  condition-selected results, a `dependency_stop` terminal declared but
  unused). It also holds `minatu.town.station.04.1.json`, the real
  first-proof projection copied verbatim from `analysis/event_definitions/`
  (with `contract_fingerprint` replaced by `"self"`): every `text_ref` and
  member hash it carries resolves against the real playback package
  (`analysis/playback_package_all/`), verified with `--names
  config/contracts/event_names_v1 --package analysis/playback_package_all`.
- `invalid/` holds one document per fail-closed rule the validator enforces,
  each the minimal mutation of a valid fixture. `expected.json` maps every
  relative path under `valid/` and `invalid/` to `{"ok": bool, "reason":
  code}`; the reason codes are the ones `tools/validate_event_definition.py`
  prints (see that module and the projection document for the exact rule
  each code enforces).

Fixtures here are hand-written and carry no original dialogue text, no
machine paths and no original data beyond synthetic coordinates and
synthetic 64-hex-character hashes (`raw_sha256`, `entry_sha256`, `package_sha256`,
`profile_sha256`, `archive_sha256`, `record_sha256`), none of which are the
hash of any real original byte range.

## Fingerprint

`contract_fingerprint` is the SHA-256 over the concatenation of
`"<relative path>\t<sha256 of the file bytes>\n"` for every file under this
directory except `contract_fingerprint` itself, paths relative to this
directory with `/` separators, sorted, LF line endings - computed by
`tools/contract_fingerprint.py`. A change to the contract is a new
`event_definition_v4/` directory beside this one, never an edit of `v3` in
place.

## The `"self"` convention

Every fixture's own `contract_fingerprint` field is the literal string
`"self"`: a fixture cannot contain the fingerprint of the directory it is
part of (writing the real value would change the value it needs to record).
`tools/validate_event_definition.py` treats `"self"` as equal to whatever
value is passed with `--fingerprint` - it does not compute the directory's
fingerprint itself. `tests/test_event_definition_contract.py` passes
`--fingerprint compute(this directory)`, so a fixture whose
`contract_fingerprint` is `"self"` passes the fingerprint check exactly when
the directory's stored `contract_fingerprint` file matches what
`tools/contract_fingerprint.py` computes today. The `invalid/` fixtures that
exercise the fingerprint rule (`missing_contract_fingerprint.json`,
`foreign_contract_fingerprint.json`) do not use `"self"`: they omit the
field or carry a fingerprint belonging to another directory.

The same convention applies to `names_fingerprint`: every hand-written valid
fixture's own `names_fingerprint` field is also the literal string `"self"`,
never a dummy value and never the real registry fingerprint embedded
directly (a fixture that hard-coded the registry's `names_fingerprint` would
have to change every time a title in the registry is renamed, even though
renaming a title must not move the contract fingerprint). With `--names
<registry dir>` given, `tools/validate_event_definition.py` treats a
document's `"self"` `names_fingerprint` as equal to the registry's own
`names_fingerprint`; any other value must equal the registry's fingerprint
exactly, and the document's `id` must be a row the registry carries. Without
`--names`, `names_fingerprint` need only be present and non-empty - "self"
still satisfies that. `valid/minatu.town.station.04.1.json`, the real
projection, is not hand-written: it keeps the real registry fingerprint it
was produced with (`b7ffcea3abac019a78f8ac19e98d5259fc778a0eb3c7123424f257b435163e1a`),
which is also allowed, since it equals the registry's. The `invalid/`
fixtures that exercise the names rule (`missing_names_fingerprint.json`,
`foreign_names_fingerprint.json`, `id_not_in_registry.json`) either omit the
field, carry a fingerprint belonging to no registry, or name an id the
registry does not carry; every other `invalid/` fixture keeps `"self"` so
that it fails for its own reason and not for `names`.
