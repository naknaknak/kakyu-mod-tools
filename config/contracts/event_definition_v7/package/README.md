# v7 fixture package

This is a **contract fixture**, not game data: a minimal
`kakyu_playback_package/v7`-shaped package (`manifest.json`, `events/`,
`text/`) built so the validator's package-dependent checks - text resolution
and the text-encoding rules, as in v4 to v6, and for v7 the
`presentation.resources` checks (every item's `entry` is one of the manifest's
`entries[]`, and every item is an occurrence of the manifest's
`media_inventory`) - can run against a `--package` directory without touching
the read-only archive or any real playback package. Its shape copies
`analysis/playback_package_0323/` (one entry's `manifest.json` row,
`events/<STEM>.json` record list and `text/<STEM>.json` strings list) but every
string, hash, offset and media name here is invented: no byte range in this
directory is the hash or the text of any original message, and no media name
is an original one.

Against v6's copy, `manifest.json` gains two entries - `LIBLARY.LIB` and
`DEF_MAIN.MES`, which a real package carries as entries although a document's
`evidence.members` does not list them - and a `media_inventory` block
(`kakyu_media_inventory/v1`) with only the keys the validator reads: `schema`,
`normalization` and `members`. `members` is a list of `{entry, occurrences}`
rows for `CALLEE`, `CALLER` and `LIBLARY.LIB`; `DEF_MAIN.MES` has no row, which
means it has no occurrence. The block is not complete (no rule tables, identity
table or counts) and does not match the `events/` records, which hold text
only; the validator does not compare the two.

`../package_unknown_inventory/` is this package with `media_inventory.schema`
set to `kakyu_media_inventory/v2`, an id the validator does not know.
