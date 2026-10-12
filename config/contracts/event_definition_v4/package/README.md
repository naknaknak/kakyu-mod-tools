# v4 fixture package

This is a **contract fixture**, not game data: a minimal
`kakyu_playback_package/v7`-shaped package (`manifest.json`, `events/`,
`text/`) built for `valid/package_resolved.json` alone, so the validator's
text-encoding checks (`text_control_character`, `text_not_nfc`,
`text_line_break`) and its package-resolution checks can run against a
`--package` directory without touching the read-only archive or any real
playback package. Its shape copies `analysis/playback_package_0323/` (one
entry's `manifest.json` row, `events/<STEM>.json` record list and
`text/<STEM>.json` strings list) but every string, hash and offset here is
invented: no byte range in this directory is the hash or the text of any
original message.
