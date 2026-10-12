# ARC Comparison Contract

## Purpose

`kakyu_arc_comparison/v1` is the portable, path-free statement of how one
opened ARC differs from another ARC or from the overlay loaded over it
(WD-01, Core 0.338.0). It compares indexes and whole-entry hashes; it does
not diff bytes inside an entry and it never contains a machine path or
payload bytes.

## Versioned document

The exact top-level fields are:

- `schema`: `kakyu_arc_comparison/v1`; `core_version`;
- `mode`: `archive` (ARC against ARC) or `overlay` (ARC against the overlay
  loaded over it);
- `left`: `name` (file name only), `sha256`, `bytes`, `entries`;
- `right`: in archive mode the same four fields; in overlay mode `name` is
  the archive name, `sha256` is empty, `bytes` is -1, `entries` counts the
  overlay's replacements for this archive, and `manifest_editor_version`
  names the overlay manifest's editor;
- `order_preserved`: whether the entries common to both sides keep the same
  relative order;
- `rows`: left entries in left index order, then right-only entries in
  right index order; names match case-insensitively. Each row carries
  `entry`, `status`, `left_index`, `right_index`, `left_size`,
  `right_size`, `left_sha256`, `right_sha256` (-1 / "" for an absent
  side) and, in overlay mode, `compatibility`. Statuses: `identical`,
  `changed`, `only_left`, `only_right`, and in overlay mode
  `overlay_identical` for a replacement whose bytes equal the original;
- `summary`: the per-status counts and `total`;
- `payload_sha256`: the fingerprint over the canonical document JSON.

`read_path` reads at most 8 MiB and validates the exact key sets, the value
sets, the integer and hash fields, `rows.size() == summary.total` and the
fingerprint; it does not reopen archives.

## Production

`tools/content_suite/arc_comparison.gd` (`KakyuArcComparison`) hashes whole
entries through the reader's streaming fingerprint; when both archives have
the same fingerprint each entry is hashed once. The overlay comparison
resolves every entry through the shared resolver and re-hashes each overlay
replacement, failing closed when a file no longer matches its descriptor.
The ARC Browser's **Compare with ARC...** and **Compare with overlay** show
the result in a panel (differences only by default) and export it; the
headless `tools/content_suite/cli/compare_arcs.gd` compares two ARC files.

## Verification

`tests/test_arc_comparison.tscn` covers changed, added, removed, reordered
and case-differing entries, identical archives, both overlay statuses, the
fail-closed changed blob, the path-free rule and the write/read refusals;
`tests/test_arc_browser.tscn` drives both comparisons through the browser;
the original ARC Browser archive check compares the real `mes.arc` with
itself (1,016 identical rows).
