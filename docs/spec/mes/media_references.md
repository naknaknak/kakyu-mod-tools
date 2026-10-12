# MES Analysis: Media Reference Classification

Which records of a packaged MES entry name a media file, how the playback
package's media inventory classifies them, and what each rule rests on. The
consumer is `content_core/playback_media_classifier.gd`'s
`KakyuPlaybackMediaClassifier`, shared by the exporter and the package reader
(`docs/spec/data/workspace_playback_export.md`, "Media inventory and script
references"). This document records rules, offsets and counts; it contains no
dialogue, bytecode or archive payload.

Measured 2026-10-06 on the full original export (Core 0.373.0, package
`b638bd7d...`, 869 member entries, 987,386 records; `mes.arc` as pinned in
`content_core/original_archive_identity.gd`). *Note, 2026-10-08:* WD-21 U2's binding export
(`874f53ca...`) differs from that package in `manifest.json` alone, and there only in
`source.catalog_revision` (40 to 41) and the hash it moves; the members, records and inventory, and so
every count in this document, are the same. *Note, 2026-10-09:* TD-57's Core
0.374.0 export (`5ae6aabe...`) differs from U2's in `manifest.json`'s `package_sha256` and
`content_core_version` alone, so the same holds for it. *Note, 2026-10-10:* TD-64's Core 0.375.0 export (`ede69366...`) differs from TD-57's in the same two fields,
and TD-64 part 2's Core 0.376.0 export (`47b1ee8d...`) differs from that one in the same
two fields. *Note, 2026-10-11:* TD-56's Core 0.377.0 exports differ from it in the Core version, the catalog
revision, 13 group hashes and the hash-prefixed preset notes (export A, `3af3779f...`), and export B
(`0e47e063...`, catalog revision 43) from A in the catalog revision and the hash alone, and EP-14's Core 0.378.0 export C
(`fe9bb6bd...`), the live package, from B in the Core version and the hash alone;
the members, records and inventory are the same. An offset below is the code-relative
offset of the record's first byte (`at`), which for an original export is the
entry's code-relative offset. A record starts at its `0x0D`/`0x12` command byte, so
an offset older documents quote inside the record can be later than `at`
(`map_movement_sources.md` quotes the `MACHI.MPC` load at `0x028F`, one byte into
the record at 654, `0x28E`; `audio.md` quotes the `KSE0031.WAV` file name at
`0x470` inside the request record at 1129, `0x469`).

Labels follow the [index](index.md): **Confirmed**, **Observed** (a repeatable
shape whose native meaning is not proven), **Unresolved**. **Tool decision** marks
a choice this repository made over a measured observation; it is not a claim
about the original engine, and it is part of the inventory schema id
(`kakyu_media_inventory/v1`): changing it is a `v2`.

## Summary

| Kind | Record-backed occurrences | Names | Absent from every searched archive | Status |
|---|---:|---:|---:|---|
| `mmo` | 6,738 | 1,577 | 161 | Confirmed marker envelope |
| `ax` | 2,316 | 465 | 66 | Confirmed marker envelope |
| `voice` | 23,027 | 14,187 | 0 | Confirmed marker envelope |
| `se` | 79 | 78 | 0 | Confirmed effect envelope |
| `a6` | 13 | 1 | 0 | Observed exact shape, tool decision |
| `bgm` | 5,157 | 45 | 0 | Confirmed pair, tool-decision region rule |
| `unclassified` | 1,460 | 547 | 19 | Observed strings, native meaning unresolved |

The identity of each name (which original archive holds it, with entry size and
SHA-256, or that every archive of its kind was searched and holds none) is the
package's claim, computed by the producer from the original archives. The
reader never recomputes it. Every scan reference the analysis index finds in the
`mmo`, `ax`, `voice` and `mes_script` kinds is a package record
(`strict_indexed` 6,738 / 2,316 / 23,027 / 2; `bounded_envelope_scan` 0; hits in
no record, `scan_only`, 0).

## Marker kinds: `mmo`, `ax`, `voice`

Rule: the records `mmo_resource_marker`, `ax_resource_marker` and `voice_marker`,
with the name in the first operand (`resource_name`). The envelopes are the
confirmed markers of [Format and Method](format_and_method.md) (the
presentation-9 MMO marker is system function 9 with one safe `.MMO` name; the AX
and voice markers have their own audited envelopes). Representative records:
`01M.MES` at 713 (`R.MMO`), `01M.MES` at 75552 (`B19.AX`, the `0x12720` the AX
audit names), `01M.MES` at 1868 (`H0001.OGG`). Searched: `mmo` in `mmo.arc`, `ax`
in `data.arc`, `voice` in `voice.arc`, `tina1.arc` and `tina2.arc`.

Absent names (all measured in the exported package's identity table): 161 `.MMO`
and 66 `.AX` marker names, no voice name. They are 227 of the 16,229 marker-kind
names. The 163 names the group-route Playback pass reports missing (61 pictures,
102 animation sources, from 17 events) are all inside this set; no absent name
exists in another archive.

The voice bank set is a **tool decision** that follows the original's own
setting: `tina1.arc` and `tina2.arc` are alternative banks the original chooses
between with its `[Voice] TINA=1|2` entry, so a name may be in both and neither is
preferred. 878 Tina names are in both banks and in nothing else, 13,309 names are
in `voice.arc` only. A name in a bank and in another archive of the same kind
would stop the export; none exists.

## Sound effects: `se`

Rule: an `effect_request` record whose operand names `resource_kind effect`,
`resource_archive se.arc` and a name. Confirmed (the startup effect evidence in
[Audio](audio.md)). 79 records, 78 names, all in `se.arc`: 78 in `LIBLARY.LIB`
(library routine 9, from 3780 on) and one in `START.MES` at 1129 (`KSE0031.WAV`).

## A6 tables: `a6`

Rule (tool decision over an observed shape): a `system_call` of function 8 whose
record list is exactly three records - a literal `0`, the string `<name>.a6`, and
the state reference `banked_i32[bank 0][index 3]` - is an A6 reference. A function-8
`.a6` string in any other shape would be `unclassified` (none exists: every
function-8 `.a6` record in the corpus has the exact shape).

Evidence: 13 records, all `ALBUM.A6`, one in each of the 13 `?_M.MES` album menus at
offset 113 (`AI_M.MES`, `MAHOKO_M.MES`, `MAKI_M.MES`, `MAYUMI_M.MES`, `MIKO_M.MES`,
`MINATU_M.MES`, `MIYUKI_M.MES`, `MIZUHO_M.MES`, `NANA_M.MES`, `REIKO_M.MES`,
`RYOKO_M.MES`, `SIZUKA_M.MES`, `TINA_M.MES`); the entry is `ALBUM.A6` in `data.arc`.
[Gallery Families](gallery_families.md) records what the album table is and how
the menus read it. Searched in `data.arc`; shipped.

## Music: `bgm`

Rule: two adjacent records, sorted by `at`:

1. an `argument_slot_write_run` (command `0x09`) writing one literal to argument
   slot 1 (operand 1 `u16_index` 1; one expression pair, continuation 0);
2. a `script_transfer` (command `0x1D`) whose single record is the literal routine
   `23`;

with the first record's `end` equal to the second's `at`, and both offsets in one
row of the document's `regions` (in a library, a routine is its own region). The
selector names its `.WAV` through `KakyuMesBgmCatalog`, the table recorded in
[Audio](audio.md) ("BGM Selector Table"). A selector that is not a literal, or that
the table does not map, is an `unclassified` row with the evidence
`bgm_selector_not_literal` / `bgm_selector_unmapped`; the full corpus has none.

The pair and the routine are confirmed (Audio, "Shared Call Convention"). The region
requirement is the tool decision: it is the adjacency rule of
`KakyuMesAudioReferenceIndex` (assignment, then transfer, `end == next.at`, one
region) applied to the package's projected records instead of a strict decode of the
original, with the region test read from the document's own `regions` rows, so a record
outside every row can never pass; the inventory's rule may therefore be stricter than the
index's and is never looser. They agree today: over all 869
members the inventory holds 5,157 `bgm` occurrences and the audio index finds the same
5,157 (same offsets, same names, no difference), and none of the 980,797 packaged
records of the non-library members lies outside a region (the library's 6,589 records
are inside routine regions). Representative record: `EVENTD01.MES` at 998 (selector
33, `MAKI.WAV`), the transfer at 1004. The catalog is part of the rule: a change to
`mes_bgm_catalog.gd` or to this rule is a `kakyu_media_inventory/v2`.

45 `.WAV` names are selected by the corpus, all in `bgm.arc`. **Six names of the
table are not in `bgm.arc` - `BOALING`, `IDO_DWN`, `NANA2`, `PB`, `SHOCK`, `STAY` -
and no packaged record selects them, so they are not `bgm`-kind absences.** They
appear only as the function-5 `.wav` loader strings of the table itself (below), where
they are the six absent `.wav` rows of the `unclassified` kind.

## Other loader strings: `unclassified`

The package keeps two record shapes that carry a media file name no kind above
claims. Each is inventoried by its string alone, looked up by extension in the
plausible archives as present-with-identity or absent, and gated like every other
kind. The inventory makes no claim of what they are (**tool decision**: the goal is
that every absence is known).

### `system_call` loader strings

A `system_call` (command `0x0D`, [the system-call section of Format and
Method](format_and_method.md)) whose `system_function` and the extension of the first
string record are in the loader table. The rule takes the **first string record** of
the record list and then checks its extension; a non-matching first string yields no
row.

| Function | Extension | Records / names | Members | Representative records (authoritative entry, offset) | Status |
|---:|---|---:|---:|---|---|
| 8 | `.ccd` | 58 / 8 | 12 | `MACHI.MES` at 677 (`MACHI.CCD`), `TRAIN.MES` at 529 | Observed |
| 8 | `.mpc` | 58 / 8 | 12 | `MACHI.MES` at 654 (`MACHI.MPC`), `TRAIN.MES` at 506 | Observed |
| 8 | `.eve` | 8 / 7 | 7 | `MACHI.MES` at 2751 (`MACHI.EVE`), `FLOOR1.MES` at 549 | Observed |
| 9 | `.gp8` | 6 / 2 | 6 | `EVENTD14.MES` at 576 (`D15SS.GP8`), `EVENTG04.MES` at 4766 (`G05SS.GP8`) | Observed |
| 24 | `.mmo` | 592 / 332 | 111 | `LIBLARY.LIB` routine 27 at 13871, 14204, 14798, 15131; `AI_H.MES` at 60943 | Observed |
| 5 | `.wav` | 56 / 56 | 1 | `LIBLARY.LIB` routine 23 (the BGM table), `IDOU.WAV` at 1481 ... `BOALING.WAV` at 3350 | Observed |

(`A6`: function 8 with `.a6` is kind `a6` when it has the exact shape above, so it
does not appear here.) The `.mpc`, `.ccd` and `.eve` loads are the map module's data
([Map Movement Sources](map_movement_sources.md) records them by file); the map
module itself is the `Util(6,n)` table of Format and Method. Function 24 loading
`.mmo` and function 5 loading `.wav` are measured shapes with no native
confirmation: their meaning stays **unresolved**, and the inventory needs only the
string.

The loader table is a tool decision over this measurement and equals it: function 8
with `.a6/.ccd/.eve/.mpc`, function 9 `.gp8`, function 24 `.mmo`, function 5 `.wav`.
Core 0.373.0's review (2026-10-06) removed function-8 `.dat`, `.pal` and `.gp8`
entries because the corpus holds **0** records of those shapes; the `.dat` and `.pal`
names arrive through the dispatch shape below, `.gp8` through function 9.

### `native_record_dispatch` loader strings

A `native_record_dispatch` record (command `0x12`, "native typed-record dispatch
ingress" in Format and Method) whose record list holds a string whose extension is in
the extension table. The rule is: **the first string record whose extension is in
`EXTENSION_ARCHIVES`**; earlier strings with another extension are skipped (none occur
in the corpus). This differs in form from the `system_call` rule above, which takes
the first string record and then checks its extension; the two give the same rows on
today's corpus, and a corpus with a non-matching string ahead of a matching one would
tell them apart. It is **not** the loader table: after the correction above that
table has no `.dat` or `.pal`.

Three fixed shapes carry all 682 records (21 distinct member entries):

| Shape (record list) | Records / names | Members | Representative records (authoritative entry, offset) | Native meaning |
|---|---:|---:|---|---|
| `[literal 6, literal 25, string '*.dat', literal N]` | 341 / 98 | 17 | `06C.MES` at 779 (`MACHIN_3.DAT`), `GROUND.MES` at 1234, `MACHI.MES` at 259 | `Util(6,25)` unresolved |
| `[literal 6, literal 24, string '*.pal', literal N]` | 239 / 19 | 13 | `27C_EV.MES` at 82812 (`FLOOR_3.PAL`), `GROUND.MES` at 1259, `TRAIN.MES` at 292 | `Util(6,24)` unresolved |
| `[literal 1, literal 12, string '*.mmo']` | 102 / 17 | 4 | `05C.MES` at 6545 (`KAO14.MMO`), `REIKO42.MES` at 3037 | `Util(1,12)` unresolved |

Evidence type: **observed** on the package's own typed records (the Phase 1-4
structural decode, `record_consumption typed_record_list_until_zero`), checked
across all 869 members; the analysis scan has no counterpart for these strings, so
there is no scan cross-check. Confidence: the shapes and strings are observed and
repeatable; the **native meaning is unresolved**. `Util(6,24)` and `Util(6,25)` are in
the `Util(6,n)` numbering of [Format and Method](format_and_method.md) ("The map
module behind `Util(6,n)`") but are not in its table, and `Util(1,12)` is outside it.
The `MACHI{N,P,T}_{1,2,3}.DAT/.PAL` names are the tile atlases
[Map Movement Sources](map_movement_sources.md) describes; that is a naming
observation, not a native-meaning claim. No reading of the dispatch's behaviour may
be taken from this document.

### Where the names are searched (tool decisions)

`EXTENSION_ARCHIVES` maps each extension to the archives its names are looked up in:
`.a6`, `.ccd`, `.dat`, `.eve`, `.mpc`, `.pal` and `.gp8` in `data.arc`; `.mmo` in
`mmo.arc`; `.wav` in `bgm.arc` **and** `se.arc` (both sound banks hold `.wav`
entries; a name in both stops the export - none is). `.gp8` has no member in any of
the seven media archives, so searching it in `data.arc` is a convention; the two
`.gp8` names are absent from every archive. Measured shipped names: 140 in `data.arc`
(8 `.ccd`, 8 `.mpc`, 7 `.eve`, 98 `.dat`, 19 `.pal`), 338 in `mmo.arc`, 50 in `bgm.arc`
(none in `se.arc`).

Absent names (19): the eleven function-24 `.MMO` names (`01CA_3`, `01CM_3`, `01CS_3`,
`19M_3`, `20CA_3`, `20CM_3`, `20CS_3`, `20M_3`, `36CA_3`, `36CM_3`, `36CS_3`; records
in `LIBLARY.LIB` routine 27, for example at 13871 (`01CA_3.MMO`), 31575 (`19M_3.MMO`)
and 32055 (`20CA_3.MMO`)), the two `.gp8` names, and the six function-5 `.wav` names
named above.

## The measured route: which occurrences a row reaches (WD-21 U2, 2026-10-08)

The rules above say what a record **is**. The per-row `resources` of the event definitions and of
the catalog say which of those occurrences a row's **measured route** reaches, and are the
join of the two ([Event Definition v7](../data/event_definition_v7.md), `kakyu_event_definition/v7`;
the catalog item in [Event Player](../tech/event_player.md), "A row's `resources`"). The evidence
is the instrument's own runs, not a scan of the member scripts: a medium in a script that no
measured run reaches is not listed. The counts below were measured 2026-10-08 on the 227
analysis-group replays (`analysis/replays_v3`, machine-local, regenerated by
`tools/regenerate_group_replays.py`) and the package `b638bd7d...`; the revision-41 export
`874f53ca...` (`workspace_playback_export.md`) has the same members, records and inventory, so
every count is the same against it, and against TD-57's Core 0.374.0 export `5ae6aabe...`, TD-64's
Core 0.375.0 export `ede69366...` and TD-64 part 2's Core 0.376.0 export `47b1ee8d...`, each of which
differs from the one before in the Core version and the hash alone, and against TD-56's Core 0.377.0 exports
(`3af3779f...` and `0e47e063...`) and EP-14's Core 0.378.0 export (the live `fe9bb6bd...`; the 14,712 below become 14,961 there).

**What a row's resources are (tool decision).** The package's `media_inventory` occurrences whose
record **a measured run executed**, unioned over every route the definition's
`evidence.groups[].route_ids` names and every replayed variant, run and hop of it: a site variant's
caller prefix (when it was reached), callee, resume, reentry and each visit run, and every hop of a
flow. The group replay (`kakyu_event_analysis_group_replay/v3`) records, per run, `executed`: the
sorted offsets of every row of the run's probe result, keyed by the package member the offset is
relative to (`tools/content_suite/replay_run_media.gd`). `tools/project_event_definition_v7.py`
joins them with the inventory, so every kind - an executed `a6` or `unclassified` loader string the
runner omits as a row included - has the inventory's vocabulary, normalization and identity. One
list per document: there is no attribution to a result, a variant or a hop. 3,437 variants,
**12,152 runs** (2,336 hops, 2,702 prefixes, 2,718 callees, 1,398 resumes, 2,701 reentries, 297
visits; the 16 variants whose prefix was not reached have none).

**Library and definition rows count; the attribution of a library-invoked definition (R1, tool
decision).** A picture, sound effect or loader string requested by a shared `LIBLARY.LIB`
routine, or by a `DEF_MAIN.MES` definition, while the route runs is part of what the route loads, so
those rows are keyed by the member they are relative to (`LIBLARY.LIB`, library-code-relative;
`DEF_MAIN.MES`, definition-code-relative). Observed: every executed offset of the 12,152 runs is a
record start of its member (0 exceptions), and the executed library and definition rows agree
with the inventory's occurrences in `(at, op)` (0 mismatches in the 1,087 library and 496 definition
rows of the sample that proved the base). One label is wrong in the probe's rows (TD-55): a
registered definition invoked from *inside* a library routine arrives labelled
`LIBLARY.LIB:<routine>` with a `DEF_MAIN.MES`-relative `at`. The writer re-keys, within a run of
consecutive library-labelled rows, the rows after a `definition_invoke_boundary` row up to and
including the next `script_return` as `DEF_MAIN.MES`, and refuses the replay when that span is not
terminated (basis: such a definition reaches the probe only as the invoke row, its own rows and its
`script_return`; a nested call makes the probe refuse the route). It re-keyed 95,832 rows of 2,904
invocations in 2,150 runs, with 0 refusals. The rule matters: five `DEF_MAIN.MES` record starts
(1517, 2458, 2868, 3903, 4397) equal `LIBLARY.LIB` inventory offsets, two of them sound effects, so
a naive keying could join a library occurrence that no run reached.

**Skipped native spans (boundary 0).** The probe jumps over a native presentation span and the
runner skips bounded streams, so a record strictly inside a skipped span is never a row. Measured
over all 227 profiles: none of the 38,790 inventory occurrences lies strictly inside the `(at, end)`
of an executed row or of a skipped span, so no occurrence is hidden that way. An occurrence in code
a route jumps over (an untaken branch, a continuation target) is not a boundary: it is exactly what a
measured route does not reach.

**The BGM coordinate.** A `bgm` occurrence's `at` is the `argument_slot_write_run` that writes the
selector, whose `end` is the `script_transfer` to routine 23 (the pair rule above); the runner
reports the request on the transfer row (`bgm_request`). A run that executes the pair therefore
executes the occurrence's own offset, and the projector cross-checks every `bgm_request` row's name
against a `bgm` occurrence joined from the same run (11,999 rows, 0 failures). The same check holds
for the marker effects at their own `(entry, at)`: 17,626 `mmo`, 7,045 `ax` and 43,792 `voice`
markers, 0 failures (80,462 rows in all).

**What the 227 replays reach.** (Before TD-56 - re-measured below.) 14,712 distinct occurrences: 14,698 in route entries, 12 in
`DEF_MAIN.MES` and 2 in `LIBLARY.LIB`. Of the inventory's route occurrences: `voice` 9,113 of
23,027, `mmo` 2,972 of 6,355, `ax` 1,022 of 2,316, `bgm` 1,288 of 5,157, `unclassified` 303 of 943;
all 12 `DEF_MAIN.MES` strings; no `se` and no `a6` (the 13 `ALBUM.A6` records and the
`START.MES` effect are on no measured route).

**A finding: the library ladders see selector 0 (R7, observed; owner ruling 2026-10-08).** The
shared library's media ladders select on `global_i32[1]` - routine 9 (sound effects) from 3769 on
with rungs `== 55`, `== 56` ..., routine 27 (place backgrounds: each rung loads its picture into surface 2 and copies it to surface 1) from 13640 on with rungs `== 0`,
`== 10` ... (expression token `0xF6`, `content_core/mes_expression.gd`) - while the generic runner
keeps a command-`0x09` write in the argument slots only (`content_core/mes_event_runner.gd`; only
command `0x0A` writes `global_i32`) and no profile seeds `global_i32`. In the original both address the
same storage ([Audio](audio.md), "Native SE, argument storage, and polling evidence"; the runner's argument ABI is recorded
there as deliberately uncorrected). So every measured library entry sees selector 0: routine 9
(entered in 468 runs, 392 variants, 53 profiles) has no rung 0 and reaches **0 of the 78** sound
effects, and routine 27 (3,839 runs, 2,319 variants, 169 profiles) always takes its selector-0
`BLACK.MMO` arm (the picture at 13658 and its loader string at 13720), which are the **two**
library occurrences the replays join. Listed per row, that arm would put `BLACK.MMO` into **272 of
the 681 rows** as a tool artifact, and the 85 rows that enter routine 9 would declare no sound
effect. The owner ruled (2026-10-08, option a) that the live v7 documents and the catalog list **no
`LIBLARY.LIB` occurrence** until the feed is modelled (TD-56, `todo/code_health.md`): the replays
keep the library offsets, `tools/project_event_definition_v7.py` joins and checks them and then leaves
them out (`EXCLUDED_ENTRIES`), and the contract keeps `LIBLARY.LIB` a valid `entry`. The 12
`DEF_MAIN.MES` items are genuine: that member reads no `global_i32`, its `CHARA*.DAT/.PAL` arms are
keyed on `state_u16[7]`.

Routine 27's pictures are place backgrounds, not character pictures (corrected 2026-10-11, EP-14). One rung is
confirmed as a place background: selector 11, `01MA_3.MMO`, the station interior (`character_events.md`,
"Deferred EVENTB03 Start"). The other 378 are read from their names and the shared surface shape (observed, an
inference, not individually confirmed): the census is 379 of 379 markers in `LIBLARY.LIB` routine 27,
code-relative 13640..57532, from the typed IR of the package member, each with the same shape. The picture
role (base) is the EP-13 tool rule.

*Status 2026-10-10 (TD-56 C1, Core 0.377.0).* The runner now models the feed: a command-`0x09` write
lands in `global_i32` and the two argument readers read it ([Format and Method](format_and_method.md),
"Command `0x09` and token `0xF6` address one storage"). The paragraph above, and the counts of
"What the 227 replays reach", are the measurement **before** the feed.

**Re-measured with the feed (TD-56 C2, C4c, C5; 2026-10-11).** The replays regenerated and the library
ladders now select by the caller's real selector. **Routine 9 reaches 25 of the 78 sound-effect rungs** (0
before; all 25 are shipped) and **routine 27 reaches 44 of its 74 rungs** (1 before); five offsets the
selector-0 reading reached are no longer reached (routine 9 at 6912, routine 33 at 57557, routine 39 at 61175,
61186 and 61194). **The replays reach 14,961 distinct occurrences**: 14,698 in route entries, 12 in
`DEF_MAIN.MES` and **251 in `LIBLARY.LIB`** (`mmo` 106, `se` 25, `unclassified` 120; 136 names), 249 more than
the two `BLACK.MMO` ones before; route and `DEF_MAIN.MES` occurrences are exactly the same. None of the library
occurrences is a `DEF_MAIN.MES`-relative offset under the library's name (TD-55: the library-relative coordinate
is a record start of the library and an inventory occurrence of its kind and name, checked in 1,093 of 1,093
listed items). **The absent `.MMO` names**: routine 27's reached rungs name seven names the archives lack
(`01CA_3`, `01CM_3`, `01CS_3`, `19M_3`, `20CA_3`, `20CM_3`, `20CS_3`), all already in the known-absent register
with the library rung as evidence, and the replays execute the occurrences of three of them (`01CS_3`, `19M_3`,
`20CA_3`): no new row. The library items are listed in the v7 documents (the C4c re-projection: 1,093 items
in 293 documents) and in the catalog's rows (revision 43: the `resources` of the same 293 rows), so **the owner's
2026-10-08 ruling is closed**; `EXCLUDED_ENTRIES` is the empty set and the contract kept `LIBLARY.LIB` a valid
`entry` throughout.

**The lists (C4c, C5).** 681 documents, 18,113 items summed over them and 14,961 distinct (route
entries 16,896 / 14,698, `DEF_MAIN.MES` 124 / 12, `LIBLARY.LIB` 1,093 / 251 in 293 documents; before TD-56
17,020 / 14,710, with the 544 / 2 library joins left out). Summed and distinct by kind: `voice` 9,422 / 9,113,
`mmo` 3,997 / 3,078, `bgm` 1,755 / 1,288, `ax` 1,307 / 1,022, `unclassified` 1,530 / 435, `se` 102 / 25; no `a6`.
No list is empty (2 to 349 items, median 16; the largest is a recollection ladder). The catalog carries the
same lists as its rows' `resources` (18.7 MB at revision 40, 21.6 MB at 41, 21.7 MB at 43).

**The instrument against the declaration (gate 3).** The group-route Playback pass compares every
medium name its played timeline uses with the row's declared `resources`
([Validation checks](../data/validation_checks.md)). Measured 2026-10-08 (the C5.5 pre-run, 22 of 22
checks passed): 15,011 played names compared, **0 undeclared**; gate 2 (the registered absences) 184
registered misses, 0 unregistered. At that measurement the timeline was built from the
probe's route trace and so never saw a library row, and the effect category compared 0 names (no replay's own
trace has an `effect_request`); since Core 0.378.0 it presents the library-executed media (below). The list
proves the converse by construction: everything declared was reached by a measured run.

**Presented by the instrument (EP-14, Core 0.378.0, 2026-10-11).** The route probe returns the media rows a
shared library routine executed in a separate `library_media` list, anchored to the route row that called the
routine, and the Playback timeline presents them in call order
([Content tools](../tech/content_tools.md), "Library media in the Playback timeline revision"). Measured by the
20 group-route shards (the default preset of each of the 681 rows):

- **694 library media played** (556 pictures from routine 27, 138 sound effects from routine 9), all from
  `LIBLARY.LIB`, in 271 rows with library pictures and 80 rows with library sound effects. Every picture is a
  base picture, found; no absent library picture is executed by a default run; the 138 effects resolve and the
  Playback pass finds no unclassified presentation effect. Gate 3: 15,705 names compared at the name level,
  0 undeclared; each library medium compared at its exact `(entry, offset, name)` against the row's items, 694
  compared, 0 undeclared.
- **497 of the 1,093 declared library items are presented** (401 `mmo`, 96 `se`). The other 596 are **508 with no
  presented form** (the `unclassified` kinds: 483 function-24 `.mmo` loader strings, the twin of each rung's marker,
  and 25 routine-33 dispatch strings, whose native meaning is unresolved) and **88 reached only through
  non-default variants** (82 `mmo`, 6 `se`): a row's declaration is the union over every measured variant, and the
  pass plays one preset per row. The 497 is the default runs' occurrences counted from the replays' `executed`,
  `prefix_executed`, `resume.executed` and hop `executed` offsets joined to the inventory; the first estimate
  of 481 left out `resume.executed`, the caller's continuation after the callee returns, which the unbroken
  caller path the pass runs includes (16 items in 16 rows).
- **Routine 27's census and what is confirmed.** 379 `mmo_resource_marker` records in routine 27 (13640..57532);
  each is immediately preceded by a literal write `banked_u16[0][1] = 2` (the active surface the marker reads)
  and followed by a write of surface 7 and a mode-1 subcommand-11 copy; all 106 distinct declared library
  markers are routine-27 markers on surface 2. Routines 42 and 43 hold four more markers (surfaces 1 and 3) that
  no measured run reaches and no row declares. Evidence types: *confirmed or established* - the shared-call
  record at the caller coordinate (a typed record of the authoritative entry), the rung selection (TD-56), the
  marker and `effect_request` envelopes (`effect_request` names `se.arc`), the active-surface cell the marker
  reads (EP-13), and routine 27's selector-11 rung as a base-surface producer (`character_events.md`,
  "Deferred EVENTB03 Start"); *observed* - the other 378 markers share that rung's typed shape; *tool decisions* -
  a library picture is shown as a still at the step of the call and a library sound effect fires at the step of the
  call, with no cadence, so a background may show before the original's screen refresh (PR-01), and the player's
  one effect channel is restarted by every request.

**What the list does not say.** It says what the instrument's measured runs executed, not what
the native host loads: a medium behind a mechanism the instrument does not model (the library ladders
above) is absent from it, and a name the host would construct at runtime without a record is not an
occurrence at all.

## What changes the schema id

A change of the kind rules above, of `mes_bgm_catalog.gd`, of the loader table or of
`EXTENSION_ARCHIVES` is a new `kakyu_media_inventory` version. The reader recomputes
only the version it knows and compares the rules the package carries with its own, so a
package written under other rules is refused, not silently reinterpreted.
