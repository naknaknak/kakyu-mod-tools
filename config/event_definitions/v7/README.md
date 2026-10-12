# Projected event definitions (`kakyu_event_definition/v7`)

One document per event site of the name registry `config/contracts/event_names_v1/`
(681 rows): the v6 set (`config/event_definitions/v6/`) re-projected by
`tools/project_event_definition_v7.py`, which wraps `tools/project_event_definition_v6.py`'s
whole pipeline (v6's, v5's and v4's code, no copy of any) and adds the one field v7 fills,
`presentation.resources` - the media each row's **measured route** reaches, `{entry,
source_offset, kind, name}` items in the package inventory's vocabulary
(`docs/spec/data/event_definition_v7.md`, fixture set `config/contracts/event_definition_v7/`).
Under the unit WD-21 U2 (`todo/workspace_distribution.md`). v3 to v6 and their documents are
untouched; `config/event_definitions/v4/` and `v5/` stay frozen, and v6 is not edited by this set.

## Status

- **The live set**, bound to `fe9bb6bd3256189ab9dd1ff91d75f95d378d8b625aae7e011ba16ccbb849f288`, EP-14's
  export (Core 0.378.0, catalog revision 43), by the Core-version rebind of "2026-10-11 (EP-14 C4, the
  Core-version rebind to the Core 0.378.0 package)" below. It was bound before to TD-56's export B
  `0e47e063...` (Core 0.377.0, catalog revision 43; "2026-10-11 (TD-56 C5, the catalog-revision rebind to
  export B)" below), and projected against TD-56's export A `3af3779f...` (Core
  0.377.0, catalog revision 42), by a **re-projection**, not a rebind, because the Core change moves runs
  ("2026-10-11 (TD-56 C4b, the Core 0.377.0 re-projection)" below), and was bound before to TD-64 part 2's
  export `47b1ee8d...` (Core 0.376.0, catalog revision 41; "2026-10-10 (TD-64 part 2 C4, the
  Core-version rebind to the Core 0.376.0 package)" below), before that to TD-64 part 1's export
  `ede69366...` (Core 0.375.0; "2026-10-10 (TD-64 C4, ...)" below), before that to TD-57's export
  `5ae6aabe...` (Core 0.374.0; "2026-10-09 (TD-57 Core-version rebind)" below), to WD-21 U2's export
  `874f53ca...` (Core 0.373.0; "2026-10-08 (WD-21 U2 C6)" below) and the first projection (the measured
  result below) to WD-21 U1's package `b638bd7d...`, which the frozen v6 set stays at.
- **Read by the promoter since C5 (2026-10-08)**: `tools/promote_analysis_groups.py` reads this set
  and promotes each row's `presentation.resources` to the catalog's `resources` (catalog revision
  41 at C5; revision 42 was TD-56's bridge, whose rows still carried the pre-TD-56 lists, and revision 43, TD-56 C5 of
  2026-10-11, is the promotion of this set's lists, the restored `LIBLARY.LIB` items included).
  `config/event_definitions/v6/` is frozen (its README, same date).

## What v7 adds over v6

`presentation.resources` (and the version fields). **Until TD-56 every other field of all 681 documents was
v6's own** - measured by comparing each v7 document, without `schema_version`,
`contract_fingerprint` and `presentation`, with its v6 document: equal in 681 of 681 (key order
included), and `index.json` equal to v6's but for `contract_fingerprint`. **Since the TD-56 C4b re-projection
(2026-10-11) the set differs from v6 in 680 of 681 documents** in the delta classes of
`tests/test_event_definitions_tracked.py` (`v7_delta_violations`), listed in the TD-56 section below, and
nowhere else.

`presentation.resources` is the union, over every route `evidence.groups[].route_ids` names and
every replayed variant of it, of the package `media_inventory` occurrences whose record a measured
run executed (a site's caller prefix when reached, callee, resume, reentry and each visit; a flow's
every hop): `tools/content_suite/replay_run_media.gd` writes the executed offsets per run into the
group replays (`kakyu_event_analysis_group_replay/v3`, `analysis/replays_v3`, machine-local), and
the projector joins them with the manifest's `media_inventory`. It fails closed on a replay that is
not v3 or not the profile's, a route or declared variant without a replay, a run without an
`executed` set (an unreached prefix is not a run), an executed member that is not a package entry,
an executed offset that is not a record start of that member, an empty joined name, and a
`resource_rows` row (the media effects of the run's own entries) that the inventory does not
confirm (a marker without an occurrence of its kind and name at its coordinate; a BGM request
whose name is not a `bgm` occurrence joined from the same run).

**The `LIBLARY.LIB` items were left out from 2026-10-08 until TD-56 (owner ruling, WD-21).** The shared
library's media ladders (routine 9 sound effects, routine 27 character pictures) select on `global_i32[1]`,
which the generic runner did not feed from command-`0x09` writes, so every measured library entry saw
selector 0: the sound effects were unreached and routine 27 would have put its selector-0 `BLACK.MMO` arm
in 272 of the 681 rows as a tool artifact. The projector joined and checked the library occurrences like the
others and then left them out (`EXCLUDED_ENTRIES` in `tools/project_event_definition_v7.py`). **TD-56
(Core 0.377.0) models the one storage, so the library items are listed since the 2026-10-11 re-projection**
(1,093 items, 251 distinct, in 293 documents; "2026-10-11 (TD-56 C4b ...)" below) and `EXCLUDED_ENTRIES` is
the empty set, kept as the one reviewed place an exclusion would be ruled again. The contract has always kept
`LIBLARY.LIB` a valid `entry`.

## Measured result of the first projection (2026-10-08)

(The figures of this section are the first projection's, before TD-56; the current ones are in "2026-10-11
(TD-56 C4b ...)" below.)

`projected=681 valid=681 invalid=0` (each document validated with
`tools/validate_event_definition.py --package` against the bound package, so every item is a
confirmed occurrence of the inventory), 70 min 22 s at `--jobs 4`; the witness line is v6's
(`sites_with_results=154 requests=5434 results_used=5434 shift_witness_rows=1718
reentry_probe_documents=46`).

| | items (summed over the 681 documents) | distinct |
|---|---|---|
| all | 17,020 | 14,710 |
| route entries | 16,896 | 14,698 |
| `DEF_MAIN.MES` | 124 | 12 |
| `LIBLARY.LIB` (joined and left out) | 544 | 2 |
| by kind | `voice` 9,422, `mmo` 3,514, `bgm` 1,755, `ax` 1,307, `unclassified` 1,022 | `voice` 9,113, `mmo` 2,972, `bgm` 1,288, `ax` 1,022, `unclassified` 315 |

No document has an empty list (smallest 1, median 15, largest 345 - `miyuki.town.43c.h.1`, a
recollection ladder); no `se` or `a6` item appears in any list. The set is 43.59 MB against
v6's 41.32 MB (all `*.json` files, the index included: +2.27 MB, 5.5 %).

## Reproduce

From the project root, with the v3 group replays (`tools/regenerate_group_replays.py`, about 20
minutes at `--jobs 4`, written under `analysis/replays_v3`), the witness corpus the v6 projection
needs (TD-37, `config/event_definitions/v6/README.md`, "Reproduce") and the bound package:

```powershell
py tools\project_event_definitions_batch.py `
  --names config\contracts\event_names_v1 `
  --catalog config\event_catalog\original_events_v1.json `
  --profiles-dir config\event_catalog\analysis_groups `
  --replays-dir analysis\replays_v3 `
  --witnesses-dir analysis\witnesses `
  --package <playback package directory> --arc <mes.arc> `
  --elfimage <ELFIMAGE directory> `
  --contract v7 --jobs 4 `
  --out config\event_definitions\v7 --resolved-out analysis\event_definitions_v7_resolved
```

The batch ends with a `resources: documents=... items=... route=... def=... lib_excluded=...
kinds={...} largest=...` line beside the v6 witness line (`lib_excluded` is 0 since TD-56, and the library
count is `items - route - def`). **Use `--jobs 4` on a 16 GB machine:** the projector's workers each load
their replays, and `--jobs 6` reached 99.1% RAM (commit 145% of RAM) within 90 seconds, against a peak of
80-86% at 4. A site that fails is named in the index row and under its line of the table (`exit_code`,
`stdout_tail`, `stderr_tail`), and `--only <id> ...` re-projects just those sites and **merges** their rows into
the `index.json` already in `--out` (same contract, names, package and cells fingerprints required; summary
recomputed), so a failed site is recovered with one more command (`tools/README.md`, TD-56 C4c). A long run
belongs under `tools/content_suite/launch_detached.py`. That command, with U1's package, is the first projection;
the live binding is produced by the rebind below, which needs no second projection.

## 2026-10-08 (WD-21 U2 C6, the rebind to the revision-41 package)

The catalog moved to revision 41 (C5), and the package hash covers `source.catalog_revision`, so the set
was rebound to the package exported from the revised catalog: `analysis/playback_package_wd21_u2`
(machine-local; the same exporter invocation as WD-21 U1's binding export, Core 0.373.0, 681 events from
869 member entries, 987,386 records), `package_sha256`
`874f53cab4f433accddf54e69db891ae9584a06cb3cc37e22bb2be46c8a462ef`, was `b638bd7d...`. Against the U1
package **only `manifest.json` differs** (1,739 files in each, 329,674,548 bytes, the other 1,738
byte-identical), and in it only `package_sha256` and `source.catalog_revision` (40 -> 41). That is the
condition the unit (decision D10) set for a rebind instead of a second projection of about 70 minutes: the
projector's package inputs (members, records, text, inventory) are the same, so the documents differ in the
hash alone.

```powershell
py tools\rebind_event_definitions.py config\event_definitions\v7 `
  --from-package <the previous package directory> --to-package <the re-exported package directory> [--dry-run]
```

`tools/rebind_event_definitions.py` refuses unless the two manifests are canonically equal outside those
two fields, every document and `index.json` are bound to the old hash, and the set is one known contract
(`tools/README.md`); it rewrites `package_binding.package_sha256` in the 681 documents and
`package_sha256` in `index.json` as a byte-level substitution. Measured as a diff against `HEAD`: **682
files, one line changed in each** (the hash); `summary`, the 681 rows, `names_fingerprint`,
`contract_fingerprint` `a48267ac...` and `cells_fingerprint` are unchanged. The validator over the whole set
with `--package analysis/playback_package_wd21_u2`: 681 valid; against the previous package every
document is refused on the binding. To regenerate the set for a later export, run the batch above (or
the rebind, when the manifests differ in the catalog revision alone) with the new package.

## 2026-10-09 (TD-57 C4, the Core-version rebind to the Core 0.374.0 package)

TD-57 changed the Core (0.373.0 to 0.374.0: the archive reader's identity memo), and the manifest records
`content_core_version`, so the package hash moved. The binding export was repeated:
`analysis/playback_package_td57` (machine-local; the same exporter invocation, Core 0.374.0, 681 events
from 869 member entries, 987,386 records; the export took about 6 min 27 s detached), `package_sha256`
`5ae6aabe6732826922efac38be628635fdf457b3e995aaf5fd647075bf8e94ad`, was `874f53ca...`. Against WD-21
U2's package **only `manifest.json` differs** (1,739 files in each; the other 1,738 byte-identical, all
pairs compared), and in it only `package_sha256` and `content_core_version` (`0.373.0` to `0.374.0`): the
catalog revision stays 41 and the rest of the manifest is canonically equal. The projectors never read
`content_core_version` (`tools/project_event_definition_v7.py` reads `media_inventory`, `entries`,
`package_sha256`, `schema` and `source.archive_sha256`), so the documents differ in the hash alone and a
second projection of about 70 minutes would write what the rebind writes.

```powershell
py tools\rebind_event_definitions.py config\event_definitions\v7 `
  --from-package analysis\playback_package_wd21_u2 --to-package analysis\playback_package_td57 `
  --pair core-version [--dry-run]
```

The tool's new Core pair (`--pair core-version`, `tools/README.md`) accepts exactly this difference. Its
summary line: `{"ok": true, "contract": "kakyu_event_definition/v7", "documents": 681, "index": 1,
"from": "874f53ca...", "to": "5ae6aabe...", "differing_manifest_fields": ["package_sha256",
"content_core_version"], "content_core_version": ["0.373.0", "0.374.0"]}`. Measured as a diff against
`HEAD`: **682 files, one line changed in each** (the hash); `summary`, the 681 rows,
`names_fingerprint`, `contract_fingerprint` `a48267ac...` and `cells_fingerprint` are unchanged. The
validator over the whole set with `--package analysis/playback_package_td57`: 681 valid (the same set
against the previous package: 0 valid, every document refused on the binding).

The Core pair is valid only because this Core change cannot move a run: it changes how often an open
reader hashes its archive, not what any definition holds. A Core change that can move a run needs a
re-projection, not a rebind. To regenerate the set for a later export, run the batch above (or the
rebind, with `--pair core-version` when the manifests differ in the Core version alone) with the new
package.

## 2026-10-10 (TD-64 C4, the Core-version rebind to the Core 0.375.0 package)

TD-64 changed the Core (0.374.0 to 0.375.0: the playback package hands one CP932 codec to all of its code
sources, `content_core/playback_package.gd`), and the manifest records `content_core_version`, so the
package hash moved. The binding export was repeated: `analysis/playback_package_td64` (machine-local; the
same exporter invocation as TD-57's, Core 0.375.0, 681 events from 869 member entries, 987,386 records;
the export took about 6 min 16 s detached), `package_sha256`
`ede69366cca16ba85eec73fc0fa918521543c4809d46339c26c2d6627eb72a16`, was `5ae6aabe...`. Against
TD-57's package **only `manifest.json` differs** (1,739 files in each; the other 1,738 byte-identical,
all pairs compared), and in it only `package_sha256` and `content_core_version` (`0.374.0` to `0.375.0`):
the catalog revision stays 41 and the rest of the manifest is canonically equal. As in TD-57's rebind,
the projectors never read `content_core_version`, so the documents differ in the hash alone.

```powershell
py tools\rebind_event_definitions.py config\event_definitions\v7 `
  --from-package analysis\playback_package_td57 --to-package analysis\playback_package_td64 `
  --pair core-version [--dry-run]
```

The tool's summary line: `{"ok": true, "contract": "kakyu_event_definition/v7", "documents": 681,
"index": 1, "from": "5ae6aabe...", "to": "ede69366...", "differing_manifest_fields": ["package_sha256",
"content_core_version"], "content_core_version": ["0.374.0", "0.375.0"]}`. Measured as a diff against
`HEAD`: **682 files, one line changed in each** (the hash); `summary`, the 681 rows,
`names_fingerprint`, `contract_fingerprint` `a48267ac...` and `cells_fingerprint` are unchanged. The
validator over the whole set with `--package analysis/playback_package_td64`: 681 valid (the same set
against the previous package: 0 valid, every document refused on the binding).

The Core pair is valid here for the reason it was valid for TD-57: the change cannot move a run. It
shares an encoder between sources that each held an identical one, and the package playback check
proves the packaged runs equal the archive's (EVENT, SUMMARY and PASS lines identical to the Core 0.374.0
run's, apart from the Core version the PASS line prints). A Core change that can move a run needs a
re-projection, not a rebind. To regenerate the set for a later export, run the batch above (or the
rebind, with `--pair core-version` when the manifests differ in the Core version alone) with the new
package.

## 2026-10-10 (TD-64 part 2 C4, the Core-version rebind to the Core 0.376.0 package)

TD-64 part 2 changed the Core again (0.375.0 to 0.376.0: the package reader parses a source lazily
through a bounded cache instead of holding every parsed document, and the exporter serializes each
member as it is built, `content_core/playback_package*.gd`), and the manifest records
`content_core_version`, so the package hash moved. The binding export was repeated:
`analysis/playback_package_td64p2` (machine-local; produced by the C2 streaming exporter at `10013ddc`,
the same exporter invocation as part 1's, Core 0.376.0, 681 events from 869 member entries, 987,386
records; the export took 5 min 59 s detached, against part 1's 6 min 16 s), `package_sha256`
`47b1ee8de1d91558a428a11fb3e3a1f6f5acd8a5775212ff76c1c49a3d9324cd`, was `ede69366...`. Against part
1's package **only `manifest.json` differs** (1,739 files and 329,674,548 bytes in each; the other
1,738 files, 316,254,550 bytes, byte-identical, every pair compared), and in it only `package_sha256` and
`content_core_version` (`0.375.0` to `0.376.0`): the catalog revision stays 41, the key order is the
same and the rest of the manifest is canonically equal. As in the earlier rebinds, the projectors never
read `content_core_version`, so the documents differ in the hash alone.

```powershell
py tools\rebind_event_definitions.py config\event_definitions\v7 `
  --from-package analysis\playback_package_td64 --to-package analysis\playback_package_td64p2 `
  --pair core-version [--dry-run]
```

The tool's summary line: `{"ok": true, "contract": "kakyu_event_definition/v7", "documents": 681,
"index": 1, "from": "ede69366...", "to": "47b1ee8d...", "differing_manifest_fields": ["package_sha256",
"content_core_version"], "content_core_version": ["0.375.0", "0.376.0"]}`. Measured as a diff against
`HEAD`: **682 files, one line changed in each** (the hash); `summary`, the 681 rows,
`names_fingerprint`, `contract_fingerprint` `a48267ac...` and `cells_fingerprint` are unchanged. The
validator over the whole set with `--package analysis/playback_package_td64p2`: 681 valid (the same set
against the previous package: 0 valid, every document refused on the binding).

The Core pair is valid here for the reason it was valid for TD-57 and part 1: the change cannot move a
run. It changes when a package source is parsed and how long a build result is held, not what a package
or a definition holds: the new package equals the part 1 package byte for byte outside its manifest,
and the package playback check, run solo against the lazy reader, printed EVENT and SUMMARY lines
identical to the part 1 baseline (the PASS line differs in the Core version it prints alone). A Core
change that can move a run needs a re-projection, not a rebind. To regenerate the set for a later
export, run the batch above (or the rebind, with `--pair core-version` when the manifests differ in the
Core version alone) with the new package.

## 2026-10-11 (TD-56 C4b, the Core 0.377.0 re-projection)

TD-56 (Core 0.377.0) makes the runner treat command `0x09` and token `0xF6` as one storage
(`docs/spec/mes/format_and_method.md`), which moves runs, so the Core-version rebind of the earlier sections is
not valid here: the set was **re-projected** in full (C4b, then again in C4c on a consistent witness corpus; the
figures below are C4c's, the final set). Inputs: the Core 0.377.0 export `analysis/playback_package_td56a`
(machine-local; catalog revision 42, the TD-56 bridge that rebinds the 13 re-derived profiles; 681 events from
869 member entries, 987,386 records; `package_sha256`
`3af3779f6b7ff599e397cdbeaae30ee16e44be2bc88ff1562a9f42b27bb13cdd`, was `47b1ee8d...`; against TD-64
part 2's package only `manifest.json` differs, in 250 fields: the Core version, `source.catalog_revision` 41 to
42, the 13 re-derived groups' `payload_sha256` and 234 preset `notes` strings that embed their 12-hex prefix;
the other 1,738 files are byte-identical), the v3 group replays regenerated on the Core 0.377.0 tree
(`analysis/replays_v3`), and the witness corpus **regenerated for all 161 profiles from the v3 replays**
(`tools/plan_event_effect_witnesses.py --replays analysis/replays_v3`, then `validate_event_analysis_group.gd
--witness` per profile: 0 errors, every `payload_sha256` the profile's). The corpus the C4b run used was
planned from the pre-TD-56 `replays_v2`, which no longer matches the replays' state changes.

*The witness corpus, before and after.* Requests by kind, before (pre-TD-56) and after: `shift:banked_u16`
2,003 and 2,003, `shift:global_u8` 1,108 and 1,117, `shift:state_u16` 1,690 and 1,688, `shift:global_i32` 0 and 491
(29 of them in the 13 re-derived profiles; D11 ignores every `global_i32` cell), `done_probe` 363 and 363
(115 profiles' done-probe cell lists differ, seeds that gained cells; the 12 `01m_*_date_v14` flows have no
corpus, the planner skips flow replays). Compared by cell outcome, not file bytes (the new files carry the extra
`global_i32` cells), over the 4,778 shift outcomes both corpora answer: **61 changed, in 46 profiles** (115
profiles unchanged) - 51 `global_u8[4000]` from `other` to `set` (entry 1, final 0), and, in the two `15c`
profiles of the 13, 6 `[3042]` and 4 `state_u16[8]` that stay `set` with another final value (routine 39's
selector-3 arm); the 363 done-probe outcomes (their gate lists, which are all the projection reads): **0 changed**.
23 requests exist only in the old corpus (the 13's replaced cells) and 30 non-`global_i32` requests only in the
new. Only the `[4000]` outcomes move a document (class 6 below).

**Result.** `projected=681 valid=681 invalid=0` (each document validated with
`tools/validate_event_definition.py --package` against export A: every item is a confirmed occurrence of its
inventory; 681 valid, 0 against the previous package's binding), no site failed. 64 min 52 s at `--jobs 4`, peak
RAM 86.2% (in the first minute). **`--jobs 6` is not viable on this 16 GB machine:** it reached 99.1% RAM (commit
145% of RAM) within 90 seconds, so 4 is the projector's maximum here. Witness line: `sites_with_results=154
requests=5964 results_used=5964 shift_witness_rows=1768 reentry_probe_documents=46` (the first projection's
was 5,434 / 1,718).

| | items (summed over the 681 documents) | distinct |
|---|---|---|
| all | 18,113 (was 17,020) | 14,961 (was 14,710) |
| route entries | 16,896 | 14,698 |
| `DEF_MAIN.MES` | 124 | 12 |
| `LIBLARY.LIB` (listed) | 1,093 (was 544 joined and left out) | 251 (`mmo` 106, `se` 25, `unclassified` 120; 136 names) |
| by kind | `voice` 9,422, `mmo` 3,997, `bgm` 1,755, `ax` 1,307, `unclassified` 1,530, `se` 102 | `voice` 9,113, `mmo` 3,078, `bgm` 1,288, `ax` 1,022, `unclassified` 435, `se` 25 |

The route and `DEF_MAIN.MES` items are exactly the earlier ones; the whole growth is the 1,093 library items in
293 documents. No document has an empty list (smallest 2, median 16, largest 349 - `miyuki.town.43c.h.1`);
the routine-9 sound effects, unreached before, are 25 distinct `se` items. Every library item is a record
start of the library (a library-relative coordinate, never a `DEF_MAIN.MES` one: TD-55) and an inventory
occurrence of its kind and name, and an independent re-join from `replays_v3` and the manifest equals the
listed items in 681 of 681 documents (878 routes). The set is 45.01 MB against 43.59 MB (all `*.json`
files, the index included: +1.42 MB) and v6's 41.32 MB. The absent `.MMO` names the library's routine 27 can
reach (seven, three of them executed by the replays) were already in the known-absent register: no new row.

**What else moved outside `presentation` (the delta classes, against the frozen v6 set).** All 681
documents differ from v6, and each difference is one of these (`tests/test_event_definitions_tracked.py`,
`v7_delta_violations`; anything else fails):

| class | what | documents | rows |
|---|---|---|---|
| 1 | a library-set flag write (`global_u8[4000]`, `[4090]`, `[4091]` = 1) added to `after` (top level 1,141 rows in 382 documents; `flow.hops[].after` 1,261 in 400; `results[*].after` 4 in 2) | 419 | 2,406 |
| 2 | the same cells' `flag_pattern` `effect_witnesses` rows | 419 | 2,406 |
| 3a | an `unresolved` line recording call-argument storage (D11) | 679 | 1,261 |
| 3b | a flow `unresolved` flag line "no matching shift witness (entry=1 final=0)" (a hop clears the flags; flows never read witnesses) | 35 | 166 |
| 3c | a "witness outcome 'other'" `[4000]` `unresolved` line removed (the cell is now a flag write, or the regenerated witness answers `set`) | 51 | 58 |
| 4 | the 13 re-derived documents: `evidence.groups[].profile_sha256` (14 values), and rows of the cells their pins moved on (16 `after` and 16 evidence rows added, 6 and 6 removed, in 2 documents) | 13 | 14 hashes, 44 rows |
| 6 | a selector-0 clear of a library flag as the witnesses decide it: `after` `write [4000]` = 0 with its `shift_witness` row (entry 1, final 0), added 42 and 42 (41 documents), removed 3 and 2 (2 documents) | 43 | 89 |

Class 4's rows are the 13 documents' own (`config/event_definitions/v6/README.md` carries the supersession
sentence): nine differ in the profile hash and the general classes alone, flag rows and argument-storage
lines (`ai.date.k_date3.15.1`, `miko.town.17m.02.1`, `minatu.town.station.04.1`, `miyuki.school.gate.17.1`,
`nana.town.23m.17.1`, `nana.town.27c1a.03.1`, `reiko.school.gate.02.1`, `ryoko.school.gate.08.1`,
`tina.town.27c_ev.14.1`); `ai.school.gate.09.1` (two group hashes) loses its `[4000]` = 0 rows;
`miyuki.date.h_date3.19.1` gains a `[4000]` = 0 row decided by its regenerated witness; `mizuho.town.15c.11.1` and
`nana.town.15c.06.1` take routine 39's selector-3 arm, so `[3041]` 1 to 6, `[3042]` 255 to 7 and `state_u16[8]` 1 to 5
replace the old rows and `[3020]` = 1 and `[3043]` to `[3046]` are added. Class 6's removals are in
`ai.school.gate.09.1` and `nana.town.26m.04.1` (the selector-0 clear the flag write 1 replaced); its 42
additions are documents whose old witness said `other` for `[4000]` and the regenerated one says `set` (entry 1,
final 0). Against the C4b set (witnesses planned from the pre-TD-56 replays) **only these 39 documents changed**: 40
`[4000]` = 0 `after` rows and their 40 evidence rows added and 45 `unresolved` lines removed, nothing else.
`index.json` differs from the previous one in `package_sha256` and the derived per-document effect counts
(`effect_rows_by_basis`: flag pattern 3,865 to 6,271, shift witness 1,718 to 1,768).

The argument storage (class 3a, **D11**, owner ruling 2026-10-11, `docs/spec/data/event_definition_v4.md`
"Effects"): a `global_i32` net change that the run's own command-`0x09` literal wrote is left out of the effect
derivation and listed once per `(index, value)` in `unresolved`. D11 excluded 1,261 cells (`global_i32[1]` 1,210,
`[2]` 51) in 679 documents, written by records in 713 entries (`DENSHA.MES` 96 lines, `01M.MES` 52 and others);
no `global_i32` change took the ordinary path (0 uncovered lines). The remaining `unresolved` lines are 12,593
in all, in the kinds the v6 set already carried, apart from classes 3a and 3b: "no matching shift witness" lines
for banked and state cells (7,361), for global cells (984), the two per-document seed and guard notes (365
each), `path_changes` and `other` witness outcomes (189 and 14 lines), and the 1,261 argument-storage records.

The tracked-set test now asserts the delta classes (replacing "v7 equals v6 outside `presentation`"), the
restored library items (at least 251 distinct items in at least 293 documents, `se` and `mmo` kinds present, one
name under one kind per coordinate) and that the 13 documents are exactly the ones whose group hash moved.
`tools/promote_analysis_groups.py --check` and three tests of `tests/test_promote_analysis_groups.py` are red
until TD-56 C5 promotes this set's lists to the catalog (regenerating the catalog from this set changes only the
`resources` of 293 rows, 17,020 to 18,113 items).

## 2026-10-11 (TD-56 C5, the catalog-revision rebind to export B)

TD-56 C5 promoted the catalog from this set's lists (revision 43: the `resources` of 293 rows gain the 1,093
restored `LIBLARY.LIB` items, 17,020 to 18,113 items; nothing else in the catalog moved), and the package hash
covers `source.catalog_revision`, so the binding export was repeated: `analysis/playback_package_td56b`
(machine-local; the same exporter invocation, Core 0.377.0, 681 events from 869 member entries, 987,386 records;
the export took about 5 min 50 s detached, at a 1.6 GB peak working set), `package_sha256`
`0e47e063e8fd9a80621e48e180b89fcb2547f966fc7fc8e59550ab92cab9ab96`, was export A's `3af3779f...`. Against export A **only `manifest.json`
differs** (1,739 files and 329,674,548 bytes in each, the other 1,738 byte-identical, every pair compared), and
in it only `package_sha256` and `source.catalog_revision` (`42` to `43`) with the same key order: the Core
version stays 0.377.0, and the 234 preset `notes` strings and the 13 re-derived groups' hashes that moved
between the TD-64 part 2 package and export A did not move again. That is the condition for a rebind
instead of a second projection of about 65 minutes: the projector's package inputs (members, records, text,
inventory) are the same.

```powershell
py tools\rebind_event_definitions.py config\event_definitions\v7 `
  --from-package analysis\playback_package_td56a --to-package analysis\playback_package_td56b `
  --pair catalog-revision [--dry-run]
```

The tool's summary line: `{"ok": true, "contract": "kakyu_event_definition/v7", "documents": 681, "index": 1,
"from": "3af3779f...", "to": "0e47e063...", "differing_manifest_fields": ["package_sha256",
"source.catalog_revision"], "catalog_revision": [42, 43]}`. Measured as a diff against `HEAD`: **682 files, one
line changed in each** (the hash); `summary`, the 681 rows, `names_fingerprint`, `contract_fingerprint`
`a48267ac...` and `cells_fingerprint` are unchanged. The validator over the whole set with `--package
analysis/playback_package_td56b`: 681 valid (the same set against export A: 0 valid, every document refused on the
binding). To regenerate the set for a later export, run the batch above with the new package, or the rebind
with the pair that matches the manifests' difference.

## 2026-10-11 (EP-14 C4, the Core-version rebind to the Core 0.378.0 package)

EP-14 changed the Core (0.377.0 to 0.378.0: the route probe returns the media rows a shared `LIBLARY.LIB`
routine executed in a separate `library_media` list, and the Playback timeline presents them,
`content_core/mes_route_probe.gd`, `content_core/event_presentation_timeline.gd`), and the manifest
records `content_core_version`, so the package hash moved. The binding export was repeated:
`analysis/playback_package_ep14` (machine-local; the same exporter invocation, Core 0.378.0, 681 events
from 869 member entries, 987,386 records; the export took about 5 min 40 s detached, at a 1.6 GB peak working
set), `package_sha256` `fe9bb6bd3256189ab9dd1ff91d75f95d378d8b625aae7e011ba16ccbb849f288`, was export B's
`0e47e063...`. Against export B **only `manifest.json` differs** (1,739 files and 329,674,548 bytes in each; the
other 1,738 files byte-identical, every pair compared), and in it only `package_sha256` and
`content_core_version` (`0.377.0` to `0.378.0`): the catalog revision stays 43, the `files[]` rows are equal
and the rest of the manifest is unchanged. As in the earlier rebinds, the projectors never read
`content_core_version`, so the documents differ in the hash alone.

```powershell
py tools\rebind_event_definitions.py config\event_definitions\v7 `
  --from-package analysis\playback_package_td56b --to-package analysis\playback_package_ep14 `
  --pair core-version [--dry-run]
```

The tool's summary line: `{"ok": true, "contract": "kakyu_event_definition/v7", "documents": 681,
"index": 1, "from": "0e47e063...", "to": "fe9bb6bd...", "differing_manifest_fields": ["package_sha256",
"content_core_version"], "content_core_version": ["0.377.0", "0.378.0"]}`. Measured as a diff against
`HEAD`: **682 files, one line changed in each** (the hash); `summary`, the 681 rows,
`names_fingerprint`, `contract_fingerprint` `a48267ac...` and `cells_fingerprint` are unchanged. The
validator over the whole set with `--package analysis/playback_package_ep14`, loading the package and the
names registry once in one process: 681 valid, 0 invalid, 9.9 s.

The Core pair is valid here because the change cannot move a run. The new probe key and the timeline's
merge are read by the Playback pass alone; `trace`, `rows`, `signature`, the messages and the carried state
are what they were, and no exporter or projector uses the probe. The proof is the replays: all 227 analysis-group
replays regenerated at Core 0.378.0 are byte-identical to the ones written before the change (227 of 227
by sha256), and the package playback check, run solo at 0.378.0, printed `EVENT` and `SUMMARY:` lines
byte-identical to the 0.377.0 baseline (md5 `610063410a6c52ba410829f18ab0c0d9`; its PASS line differs in the
Core version it prints alone). A Core change that can move a run needs a re-projection, not a rebind. To
regenerate the set for a later export, run the batch above (or the rebind, with `--pair core-version` when
the manifests differ in the Core version alone) with the new package.
