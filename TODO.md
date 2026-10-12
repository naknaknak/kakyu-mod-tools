# Kakyu Mod Tools TODO Index

This file is the repository-wide priority summary and navigation index. The
final product goal is **the original analyzer**: the extraction, analysis and
authoring side of the project, delivered as the Kakyu Content Tool Suite.

```
This repository: kakyu-mod-tools            Sibling: kakyu-remake
  in : user ELFIMAGE ARCs (read-only)         in : playback package
  do : extract, analyse, author               do : interpret, present, input, audio
  out: playback package + evidence            out: the mod player
```

[Product roles](docs/spec/tech/product_roles.md), decided 2026-09-05, fixes three
things. This repository is the **original analyzer**, and it targets no Godot
engine dependency. The **original ARC/MES player is an instrument of that
analysis**, not a product runtime — it exists so a claim about an entry can be
checked by executing it, and the earlier expectation that its playback half would
become a game runtime is withdrawn. The **mod player is `kakyu-remake`**.
On 2026-09-20 the owner set the instrument's own final form: a
*minimal-presentation event player* that plays every catalog site with text,
voice, BGM and still pictures through the one shared call frame, no
animation, no game runtime (`docs/spec/tech/event_player.md`, "Final
deliverable target"; `todo/event_player.md` EP-10). The mod player is still
the remake.

The suite serves modding the original game. The original is a **specification,
not an execution target**: mods run in the mod player, so original-engine
execution is not a product gate and unresolved native host mechanisms do not
block work.

The owner closed Event Player's scope to **original-event playback and analysis
only** on 2026-09-08. Mod event counts and authored MES/dialogue/media playback
do not extend that app's completion gate. Existing mixed-content UI is EP-08
transition debt; full original-event analysis remains the primary work.

## Progress Toward the Final Goal

Updated 2026-10-11 at Core 0.378.0 (the WD-19 release suite rebuilt at it, `analysis/windows-suite-0378-20261011/`; HEAD `a9de5086` plus the closing record: EP-14, the Playback timeline presents the pictures and sound effects the shared `LIBLARY.LIB` routines execute (routine 27's place backgrounds as base pictures, routine 9's sound effects fire-and-forget), carried in a separate anchored `library_media` list so that no run moved (227 of 227 replays byte-identical) and the v7 set was rebound with the Core pair to the export `fe9bb6bd...`; gate 3 now compares them by name and at their exact library coordinates (694 played, 497 of the 1,093 declared library items presented by the default runs) - closed by its uncached whole batch, 479 of 479 in 2,401 s and 10,723 check-seconds (2,546 s and 10,716 before); before it, the same day, at Core 0.377.0, HEAD `8f81d232` plus the closing record: WD-10, the portable mod bundle (`kakyu_mod_bundle/v1`: a workspace's authored v9 deltas, its translation-only entries and its definition set in one file; `tools/mod_bundle.py` builds and validates it, and one staged-import engine reconstructs it into a fresh workspace and reopens every effective identity; no Core change, so no re-export), and TD-67, the multi-slot checks run back to back at every `--jobs`, closed by their uncached whole batch, 479 of 479 in 2,546 s and 10,716 check-seconds (2,743 s and 10,278 before; the Python suite started within a second of the equivalence's end); before it, the same day, HEAD `210162c4` plus the closing record: TD-56, the generic runner's command `0x09` and token `0xF6` as one storage (the original's rule, confirmed by an executable audit), so the shared `LIBLARY.LIB` media ladders select by the caller's real selector - 13 analysis-group profiles re-derived, the catalog 41 -> 42 -> 43 with 1,093 library items restored to 293 rows (17,020 -> 18,113 items), the 681 v7 definitions re-projected and rebound to export `0e47e063...`, TD-55's relabel closed inside it - closed by its uncached whole batch, 477 of 477 in 2,743 s and 10,278 check-seconds (2,452 s and 10,875 before; the worker gate idled three slots for 839 s on an ordering tie, TD-67); before it, 2026-10-10 at Core 0.376.0, HEAD `1daa69ee` plus the closing record: TD-64 part 2, the package reader that keeps each member's verified bytes and parses a code source on demand under a bounded cache and the exporter that serializes each member as it is built (export working set 8.7 -> 1.6 GB, solo playback 8.8 -> 2.0 GB), and TD-65, the worker gate that serves waiters in arrival order, so the Python suite starts the moment the equivalence frees its slots (+616 s against +2,545 s), closed by their uncached whole batch, 477 of 477 in 2,452 s (3,364 s before); before it, the same day at Core 0.375.0, HEAD `d367b5bd` plus the closing record: the TD-58 unit, the analysis-group process split into two shards (3,193 -> 1,861 and 1,867 s), and TD-64 part 1, the package playback check's memory (the exporter's build released before the reload, one CP932 codec per loaded package; the check now runs alone, last), closed by their uncached whole batch, 477 of 477 in 3,364 s; before it, 2026-10-09 at Core 0.374.0, HEAD `7331ea26` plus the closing record: the TD-57 unit, the archive reader's per-open identity memo - voice playback without the per-line stall, the batch 4,770 -> 3,226 s wall and 21,975 -> 10,007 check-seconds - closed by its uncached whole batch, 477 of 477; before it, the same day at Core 0.373.0, HEAD `425d9b0d` plus the closing record: the WD-21 U2 unit, each row's `resources` from its measured route as `kakyu_event_definition/v7` and catalog revision 41 with gate 3, closed by its whole batch, 477 of 477 - uncached 475 of 477 with two classification checks failing on a missed refresh, fixed in `425d9b0d`, then `--cached` 477 of 477; before it, 2026-10-07, at HEAD `dc99e46` plus the closing record: the WD-21 U1 unit, the package's media inventory and script references, the known-absent register and the manifest's catalog binding, closed by its uncached whole batch, 475 of 475; TD-53 and TD-54 closed with it; before it, 2026-10-06, Core 0.372.0, `ebd440a` plus the closing record: the TD-52 unit, TD-52 closed by the runner's `analysis/.gdignore` (`274fd97`) and its uncached whole batch, 473 of 473; before it, 2026-10-05, `ce65d78` plus the closing records: the EP-12 TALK follow-ups unit, catalog revision 40; EP-12 closed by the owner the same day; the TD-51 closing record, TD-51 closed by the fix `eb8b09e` and its uncached whole batch, 473 of 473). Completion is measured
by capability and reproducible evidence, not a percentage of unequal
checkboxes. The goal has three deliverables, in this order of weight: the
**analysis evidence**, the **artifacts the mod player consumes** (the playback
package and the projected event definitions), and the **instrument** that lets
a person check a claim by watching it (EP-10). The tools' own distribution
polish serves all three and comes after them.

| Capability | Current result | Remaining product work |
|---|---|---|
| Phase 1-4 analyzer | Closed; authoritative Python handoff over all 1,016 entries, zero opaque tails since Core 0.316.0 framed command `0x0D` as one system call; corpus fingerprint `74f14088...2a1dff8` approved 2026-09-15 (MA-11) | Keep the full-corpus gate on schema/boundary changes |
| Phase 5 decompiler | Closed; deterministic provenance-preserving output | Consumed by the authoring UI |
| Phase 6 compiler backend | Closed; seven edit families and operation sequences in the Authoring tab (MW-11, 2026-09-17) | None scheduled; the address entry is closed without exposure by owner ruling |
| Event coverage (evidence) | Every EVENT intro of every caller measured and declared (EP-10 unit 5a); **EP-12 (owner 2026-09-24: every scene family becomes catalog content):** the twelve heroines' promise dates as `kakyu_event_analysis_group/v14` flows (33 routes: town / DATE5 / hotel, `docs/spec/mes/heroine_date_flows.md`) and the twelve promises at the station site (117 routes, `docs/spec/mes/promise_groups.md`); catalog revision 43 (2026-10-11; revision 41 of 2026-10-08 was revision 40 of 2026-10-05 plus every row's measured `resources`, WD-21 U2; revision 42, TD-56's bridge, rebinds the 13 re-derived profiles' hashes, and 43 adds the restored `LIBLARY.LIB` items to 293 rows' `resources`, 17,020 -> 18,113 items) is **681 generated rows, all `minimal_playback`** (D hotel and L DATE5 declared, A promise options 8-10 declared; nine date profiles regenerated at routine-40 contract v5, A's hand-authored profile stays v4 by design; **all 365 album scenes** as the 13 `<menu>-scene` flow groups with 91 variants (a question's other options and a recap's hotel path), `docs/spec/mes/gallery_families.md`; 33 twins are `duplicate_route` rows; **the 13 `?_H.MES` recollection ladders of the protagonist's room as 13 ordinary `43C.MES` sites** (`<name>.town.43c.h.1`, one v14 flow group each, default variant the full recollection, 330 gates, `docs/spec/mes/43c_caller_group.md`); **heroine K's nine `?_TALK*.MES` conversation scripts** (the eight affection-banded rung scripts as three-hop flows at the `01M.MES` ladder block, ending at the town handoff, and the plain `K_TALK` as a two-hop flow at `27C_EV.MES`; the natural state, option 1 by default; `ai.town.station.talk-<band>.1`, display category `conversation`, the 49 K ladder blocks recorded as equivalents, `docs/spec/mes/talk_family.md`); **the other eleven heroines' 96 conversation scripts (88 rung scripts at their ladder blocks, 8 plain scripts at `27C_EV.MES`), Tina's `M_TALK` and the characters' eight `N_TALK`..`Q_TALK1`** (105 rows, 114 TALK rows in all, 28 groups, 88 variants; the other ladder blocks recorded as equivalents; routine-40 contract schema v6; `N_TALK1`'s resume measured 2026-10-05 to reach the `FLOOR5.MES` handoff, so its row is three hops and `map_return`, the revision-40 change)); 227 analysis groups (13 profiles re-derived by TD-56 C3); classification refreshed (167 entries: 151 playable / 15 system / 1 unreachable, 0 unresolved) | **EP-12 closed by the owner 2026-10-05** (`todo/event_player.md`); three items stay deferred as recorded boundaries or options (the fourth, CG with WD-21 as the flag -> picture table, was withdrawn by the owner 2026-10-09: the pictures suffice, and 556 of the 572 the viewers load are package inventory names): the DATE5/HOTEL -> TALK extension (37 blocks, owner option), the hotel return-visit variant (a fourth route per heroine, or a per-variant hop-outcome override, which v14 does not have; only heroine A measured) and J's hotel (measured, not declared); the unshipped pictures and animation sources are now a registered, gated fact (WD-21 U1: 161 `.mmo` and 66 `.AX` names the original archives do not hold, `config/event_catalog/known_absent_media_v1.json`) |
| Instrument (EP-10) | Every catalog row plays through the one shared call frame and presentation timeline (text, voice, BGM, stills, SE; since Core 0.378.0 also the pictures and sound effects the shared library routines execute, EP-14), per-event code deleted (16,054 -> 7,654 player lines), endings in the game vocabulary (EP-09) | Owner acceptance of the first representatives (WD-19 sheet), then golden-frame comparison |
| Playback package and event definitions | Package v7 carries every row (681 events from 869 member entries, 227 groups bound; **`fe9bb6bd...`** since EP-14, 2026-10-11: Core 0.378.0, the manifest differing from TD-56's `0e47e063...` in `package_sha256` and `content_core_version` alone, rebound with `--pair core-version`; `0e47e063...` since TD-56, 2026-10-11: Core 0.377.0, catalog revision 43 (export B; export A, `3af3779f...` at catalog revision 42, differed from TD-64 part 2's package in the Core version, the catalog revision, 13 group hashes and 234 preset notes, and B differs from A in `package_sha256` and `source.catalog_revision` alone, rebound with `--pair catalog-revision`); `47b1ee8d...` since TD-64 part 2, 2026-10-10: Core 0.376.0, the manifest differing from part 1's `ede69366...` in `package_sha256` and `content_core_version` alone, rebound with `--pair core-version`; `ede69366...` since TD-64 part 1, 2026-10-10: Core 0.375.0, differing from TD-57's `5ae6aabe...` in the same two fields; `5ae6aabe...` since TD-57, 2026-10-09: Core 0.374.0, the manifest differing from WD-21 U2's `874f53ca...` in the same two fields; `874f53ca...` since WD-21 U2, 2026-10-08: catalog revision 41, the manifest differing from U1's `b638bd7d...` in `package_sha256` and `source.catalog_revision` alone) and, since WD-21 U1 (closed 2026-10-07), the manifest's catalog binding, a media inventory (16,900 `(kind, name)` rows: 16,654 shipped with archive and entry identity, 246 known absent, registered in `config/event_catalog/known_absent_media_v1.json` and gated in the batch) and the script references (959 targets, 106 outside the membership as a report); 142 `kakyu_event_definition/v4`, 142 v5 and 681 v6 documents frozen (v6 at `b638bd7d...`; fingerprint carry only); **681 `kakyu_event_definition/v7` documents** (WD-21 U2, 2026-10-08: v6 plus each document's `presentation.resources`, the package `media_inventory` occurrences its measured route executes, unioned over every route, variant, run and hop - 17,020 items, 14,710 distinct, none empty; the `LIBLARY.LIB` items held back by owner ruling until TD-56 were restored on 2026-10-11 by a re-projection at Core 0.377.0, 18,113 items, 14,961 distinct, 1,093 library items in 293 documents, with the library-set flags declared and the argument storage excluded (TD-56 D11); `config/contracts/event_definition_v7/`) are the live set the promoter reads, bound to `fe9bb6bd...` (v6 is a `flow` block over v5, owner 2026-09-25; witness-derived rows restored 2026-10-03: 1,718 `shift_witness`, 46 `reentry_probe`; the producer refuses a projection without the witness corpus, TD-37), and every catalog row (revision 43) carries the same list, with gate 3 failing a shard when the instrument plays a medium its row does not declare (15,705 names, 0 undeclared in EP-14's closing batch, 15,011 route-own and 694 library-executed; the library media are also compared at their exact library coordinates, 694 compared, 0 undeclared); mod event definitions v1 with the set file, workspace storage and the Definitions tab (MW-13) | WD-21's remaining unit (U2 closed 2026-10-09; U3, the CG table, withdrawn by the owner the same day): U4 (deferred) modified shared entries in an authored export; TD-56 closed 2026-10-11 (the library items restored to v7 and the catalog); EP-14 closed 2026-10-11 (the Playback pass presents the library-executed pictures and sound effects: 497 of the 1,093 library items by the default runs, the other 596 being 508 with no presented form and 88 reached only through non-default variants); the portable mod bundle (WD-10) closed 2026-10-11 (`kakyu_mod_bundle/v1`, `docs/spec/data/mod_bundle.md`; its Launcher export and import is WD-24, unscheduled) |
| Validation | Checks are data (`config/validation/checks_v1.json`, 322 entries) with tiers and input-fingerprint caching (TD-32); `--jobs N` and a group-routes check split into shards (TD-33; four, twenty since the album rows, 2026-10-04); reports reproduce on any machine holding the originals (TD-36); 2026-10-11, the EP-14 closing batch (Core 0.378.0, uncached because Core changed; committed tree `a9de5086`): **479 of 479 in 2,401 s at `--jobs 6`** (run `8b534111`), **10,723 check-seconds** (WD-10's batch: 2,546 s and 10,716) - no check added; the wall time is inside the unit's 2,330-2,500 s because `original mod bundle round trip` (213.5 s of 900, 0.24) is keyed now and ran beside the corpora from +1,736 s instead of alone at the tail; the Python suite started at **+581 s, within a second of the full handoff equivalence's end**; the two analysis-group shards **1,772.0 s and 1,741.8 s of their 8,000 s (0.22)**; the 20 group-route shards' check-seconds rose 69.7 s, placement inside the batch rather than the library media (four shards that ran beside heavier work; the unit's own re-run of all 20 summed 1,407.2 s against WD-10's 1,403.7 s); the batch's RAM peak **81.7%** (three samples at or above 80%, +508 to +528 s, the equivalence-and-shards phase; WD-10's 78.8%) and commit peak 62.4%, one 10-second interval with `pgin_avg` over 1,000/s (a process turnover with a 0.5/s 2-second reading, not sustained); no check past 0.41 of its timeout (`original Audio Editor original integration`, 122.8 s of 300, inside its 0.29-0.42 band); gate 3 15,705 names and the library compare 694, 0 undeclared, library coverage 497 of 1,093, gate 2 184 registered, 0 unregistered; then `--cached`: 479 of 479, all cached, 9.5 s (run `e9db1622`); before it, the same day, the WD-10 and TD-67 closing batch (Core 0.377.0 unchanged, uncached because the runner changed; committed tree `8f81d232`): **479 of 479 in 2,546 s at `--jobs 6`** (run `e6cb6108`), **10,716 check-seconds** (TD-56's batch: 2,743 s and 10,278 with 477 checks) - the two checks added are `Godot test_mod_bundle_import.tscn` (11.9 s of 180) and `original mod bundle round trip` (179.5 s of 900, 0.20, tier `full`); the multi-slot checks run back to back (TD-67, fix 1), so the Python suite started at **+583 s, within a second of the full handoff equivalence's end** (+1,426 s before) and the three single-slot checks behind it at +841 s, when it ended; the wall time is 46 s above the unit's 2,330-2,500 s because the new check had no cache entry, sorted after every keyed check and ran nearly alone at the tail (+2,355 to +2,534 s), not because of the gate; the two analysis-group shards **1,755.0 s and 1,722.2 s of their 8,000 s (0.22)**; the batch's RAM peak 78.8% and commit peak 61.7%, no sample with `pgin_avg` over 1,000/s; no check past 0.38 of its timeout (the transfer-direction corpus); then `--cached`: 479 of 479, all cached, 9.5 s (run `aef4b99e`); before it, the same day, the TD-56 closing batch (Core 0.377.0, uncached because Core changed; committed tree `210162c4`): **477 of 477 in 2,743 s at `--jobs 6`** (run `bcd678df`), **10,278 check-seconds** (TD-64 part 2's batch: 2,452 s and 10,875) - the check-seconds fell by 597 s and the wall time rose by 291 s, because the strict-FIFO gate held three slots idle for 839 s: the run's report path was new, so the ordering read cache durations only, and the transfer-direction corpus (key 945.5) and the Python suite (236.33 s x 4 slots, key 945.3) tied, so when the equivalence freed its four slots the corpus took one and the suite, the new head, could not fit (the Python suite started at +1,426 s, against +616 s; TD-67, closed by the next batch); the two analysis-group shards **1,658.9 s and 1,694.4 s of their 8,000 s (0.21)**; the batch's RAM peak 79.1% and commit peak 61.9%, no sample with page-ins over 1,000/s; no check past 0.42 of its timeout; gate 3 15,011 names, 0 undeclared, gate 2 184 registered, 0 unregistered (the library items were outside that comparison until EP-14); then `--cached`: 477 of 477, all cached, 8.8 s (run `e60a071d`); before it, 2026-10-10, the TD-64 part 2 and TD-65 closing batch (Core 0.376.0, uncached because Core, the runner and the registry changed; committed tree `1daa69ee`): **477 of 477 in 2,452 s at `--jobs 6`** (run `72b516cc`), **10,875 check-seconds** (TD-58's batch: 3,364 s and 10,727; TD-57's: 3,226 s and 10,007) - the worker gate serves waiters in arrival order (TD-65), so the Python suite started at **+616 s, the moment the full handoff equivalence freed its slots** (+2,545 s before), and `original playback package playback`, no longer exclusive, ran beside the two corpora from +869 s in 619.8 s (it had run alone at the tail, 559.9 s), the export check from +1,231 s in 334.0 s; the batch's RAM peak **72.0%** (the pre-pass and equivalence window) and commit peak 56.9%, with the playback window alone no longer at 94.3% / 73.0% and **no sample with page-ins over 1,000/s**; the two analysis-group shards **1,822.4 s and 1,802.1 s of their 8,000 s (0.23)**; the wall time was 56 s under the strict-FIFO model's 2,508 s and 48 s under its expected 2,500-2,650 s range; no check past 0.39 of its timeout, then `--cached`: 477 of 477, all cached, 8.8 s (run `d15a5def`); before it, the same day, the TD-58 and TD-64 part 1 closing batch (Core 0.375.0, uncached because Core, the runner and the registry changed; committed tree `d367b5bd`): **477 of 477 in 3,364 s at `--jobs 6`** (run `d2144d74`), **10,727 check-seconds** (TD-57: 3,226 s, 10,007) - the analysis-group process split into two shards (`process_shards: 2`, registry revision 5), **1,861.5 s and 1,867.4 s of their 8,000 s (0.23)** against 3,193 s, so it is no longer the floor; the exclusive `original playback package playback` ran alone at the tail, 560 s (RAM peak 94.3%, commit 73.0%, TD-64); the wall time missed the ~3,000 s bound and the model's ~2,300 s because the worker gate holds no reservation, so the Python suite's worker was parked from ~711 s to ~2,545 s (TD-65); no check past 0.42 of its timeout, then `--cached`: 477 of 477, all cached, 9.9 s (run `68be8eb1`); before it, 2026-10-09, the TD-57 closing batch (Core 0.374.0, uncached because Core changed; committed tree `7331ea26`): **477 of 477 in 3,226 s at `--jobs 6`** (run `37a06f05`), **10,007 check-seconds** against U2's 21,975 - the 20 group-route shards **13,473 -> 1,394 s** (TD-57's archive identity memo), the rest within a few percent in aggregate (8,502 -> 8,614 s; the Event Player checks 217 -> 124 s; the frontier's +108 s is U2's early failure, not a regression) - the analysis-group process **3,193 s of its 8,000 s, now 99% of the wall time** (TD-58 next), no check past 0.38 of its timeout, then `--cached`: 477 of 477, all cached, 62 s (run `523b0a4b`); before it, 2026-10-08/09, the WD-21 U2 closing batch (Core 0.373.0 unchanged; uncached because a contract and the catalog changed; committed tree `d5fa4395`): whole `full` tier **475 of 477 in 4,770 s at `--jobs 6`** (run `4d0be71d`), the two failures `original event analysis frontier` and `original event corpus literal dispatch inventory` - the route classification still bound to catalog revision 40 (C5 had not refreshed it; TD-62) - fixed in `425d9b0d` (only `catalog_sha256` and the payload hash moved) and passing again (128.2 s, 168.8 s), then `--cached`: **477 of 477, 474 cached, 243 s** (run `94a6094d`); the analysis-group process **3,180 s of its 8,000 s**, no check past 0.37 of its timeout (the highest 0.365), gate 3 **15,011 names, 0 undeclared**; before it, 2026-10-07, the WD-21 U1 closing batch (Core 0.373.0, committed tree `dc99e46`; uncached because Core, the package contract and the registry changed): whole `full` tier **475 of 475 in 5,254 s at `--jobs 6`** (run `7513c6ad`), the analysis-group process **3,691 s of its 8,000 s**, `Godot project parse check` 17.0 s of 120 s, no check past 0.45 of its timeout (the highest 0.42), the three contextual-authoring checks that moved to 900 s (TD-54) at 0.25-0.27, then `--cached`: **475 of 475, all cached, 8.5 s**; before it, 2026-10-06, the TD-52 closing batch (Core 0.372.0 unchanged, committed tree `ebd440a`; uncached because the runner changed): whole `full` tier **473 of 473 in 5,282 s at `--jobs 6`**, `Godot project parse check` **8.86 s of 120 s (was 79.9 s)**, the analysis-group process **3,664 s of its 8,000 s**, no check past 0.5 of its timeout, then `--cached`: **473 of 473, all cached, 7.7 s**; before it, 2026-10-05, the TD-51 closing batch (Core 0.372.0 unchanged, committed tree `ce65d78`; uncached because the registry and the runner changed): **473 of 473 in 5,177 s at `--jobs 6`**, the analysis-group process **3,614.5 s of its 8,000 s** (it would have exceeded the old 3,600 s), then `--cached`: **473 of 473, all cached, 7.7 s**; before it, 2026-10-05, the TALK follow-ups unit (no Core change, `faa917f`): `--cached --jobs 6` run `5865c21a` **246 of 473 and the analysis-group process timed out at its 3,600 s**, the same command again (run `f02e7da7`, the process alone) **473 of 473 in 3,084 s**; whole `full` tier on 2026-10-05 at Core 0.372.0: **473 of 473 in 5,156 s at `--jobs 6`**, uncached (`19a3853`, the 105 other TALK rows, 26 new checks), then `--cached`: **473 of 473, all cached, 8.2 s**; 2026-10-04: 447 of 447 in 4,538 s at Core 0.371.0 (`7fff4af`, heroine K's nine TALK rows, 2 new checks), then `--cached`: 447 of 447, all cached, 7.1 s; before it 445 of 445 in 5,155 s at Core 0.370.0 (`2eb1127`, the 13 recollection ladders, 13 new checks), and 432 of 432 in 4,251 s at Core 0.369.0 (`0d03d1e`, the 13 album menus and 20 group-route shards) and 403 of 403 in 3,006 s (`46f8eff`); 2026-10-03: 402 of 402 in 3,021 s (`7c50cdd`, TD-42; 3,980 s on `41ff67a`, 4,564 s at `--jobs 4` on `b9fa356`), then `--cached`: **402 of 402, all cached, 5.7 s**; the full handoff equivalence and the v6 projection run in parallel (TD-40, TD-41); `launch_detached.py` starts a run that survives the session | **TD-53 closed 2026-10-07** (the validation cache now fingerprints `bgm.arc`, `tina1.arc` and `tina2.arc` beside the five it had; the uncached batch re-seeded every fingerprint); **TD-54 closed 2026-10-07** (the three contextual-authoring checks that sat at 0.39-0.49 of 600 s in the pre-run moved to the `full` tier at 900 s by owner ruling, `--tier archive_quick` no longer runs them; 0.25-0.27 in the closing batch); **TD-51 closed 2026-10-05** (the analysis-group process timeout raised 3,600 -> 8,000 s, the runner prints the process's own duration, and the closing batch read 3,614.5 s, 0.45 of the timeout, `todo/code_health.md`); **TD-52 closed 2026-10-06** (`Godot project parse check` took 79.9 s of its 120 s in the TD-51 batch, 0.67, the only check past 0.5; the owner ruled the timeout stays and the runner now writes an empty `analysis/.gdignore` before any check, so the editor's scan skips the untracked tree: solo 40.3 and 38.6 s before, 6.5 s after, 7.95 s in the local-tier run `f1676b1e`, and **8.86 s (0.07) in the closing batch `a171a199`, 473 of 473**; `todo/code_health.md`); TD-38, TD-39, TD-40, TD-41, TD-42 closed (the analysis-group process now starts in the first wave; parallel efficiency 0.63, RAM peak 77%); **TD-58 closed 2026-10-10**, **TD-64 closed 2026-10-10** (part 1, then part 2: the lazy package reader and the streaming exporter, which took the playback check's working set from 8.8 to 2.0 GB and lifted its exclusivity) and **TD-65 closed 2026-10-10** (the worker gate serves waiters in arrival order: the Python suite, which started only at +2,545 s in TD-58's batch because the gate had no reservation, started at +616 s) (`todo/code_health.md`); **TD-67 opened and closed 2026-10-11** (the worker gate's strict FIFO idled slots when a single-slot check's ordering key tied a weight-4 check's; the ordering rule that keeps the multi-slot checks back to back, at every `--jobs`, closed it with WD-10's uncached batch, `todo/code_health.md`); unscheduled speed items: the ~60 s sequence compile (TD-47, TD-59, TD-60 and TD-63 are on demand by the owner's ruling of 2026-10-09; TD-60's `--jobs 6` question is answered: the projector's maximum on this machine is 4) |
| Distribution | Six release apps with isolated Python/Pillow and native version metadata; 0.378.0 build for the WD-19 sheet (rebuilt 2026-10-11) | Public release preparation (WD-25, opened 2026-10-11; the repository is private meanwhile): no original executable bytes (item 1) and no original MES archive content (item 1b) in tracked files (both done 2026-10-12), the public snapshot built and proven and awaiting the owner's approval (item 7a, done 2026-10-12), a rebuild without the executable data, a license, a README notice, the history, the author e-mail and the public scope, decided by the owner. The icons are Godot's default (WD-14 closed) and the clean-Windows check was closed unverified (WD-20, MV-07), both by owner ruling 2026-10-09 |

Phase 6 completion does not imply that the general authoring GUI is complete.
Unresolved native meanings remain labelled; original-engine execution is not
a product gate. The product definitions remain in
[Content Suite Product Goals](docs/spec/tech/content_suite_product_goals.md)
and [Event Player Product Goal](docs/spec/tech/event_player.md); the
[gap matrix](docs/spec/tech/content_suite_gap_matrix.md) maps them to current
domain items.

Historical MA-10 evidence: 1,016/1,016 payloads and all nine component targets
match the frozen GDScript baseline under `producer_implementation_only/v1`.
The actual Python corpus fingerprint is
`3eb9afe776657b120346ca880608e95b069ceb9e2ced3d5d97b803b80b3628f9`;
the projected historical fingerprint is
`fae349f9affbaf244f44fe61f3afc380cb980f058950fe85fcb1f7d097eab6f5`.
These are different producer identities, not interchangeable hashes.
Recent check scopes and results belong with their verified work units in
`todo/code_health.md`; an expanded batch does not inherit an older pass count.

## Current Phase Gate

The [MES pipeline](todo/mes_pipeline.md) keeps Phases 1-6 closed and Phase 7
current. The current core is **0.377.0** (2026-10-11). What each core version
added is recorded with its work unit in the owning domain tracker and in Git;
the milestones since the Core 0.360.0 whole batch are EP-11 part 1a
(0.361.0, visit ladders as v13), EP-13 (0.362.0, stills from the surface
trace) and EP-12 (0.363.0-0.372.0: the redirect choice shape, the v14 flow
shape, `poll_supplies`, the sparse routine-40 catalog, the gate-hash degrade,
the route probe's live stop detail and, in 0.369.0, the Event Player's phrase
for a callee return, with the v14 variant `answers`/`message_counts` fields, in 0.370.0 the v14 hop `segment_budget` the recollection ladders need, in 0.371.0 the routine-40 scratch-split consumer shape the TALK topic hubs need, and in 0.372.0 the routine-40 contract schema v6 that shape belongs to; WD-21 U1, 0.373.0, which added the package manifest's `media_inventory` and `script_references` blocks; TD-57, 0.374.0, the reader's per-open archive identity memo that ends the whole-archive re-hash per voice line, BGM change and picture; TD-64 part 1, 0.375.0, one CP932 codec per loaded package; TD-64 part 2, 0.376.0, the lazy package reader, which keeps each member's verified bytes and parses a code source on demand, and the exporter that serializes each member as it is built; and TD-56, 0.377.0, command `0x09` and token `0xF6` as one storage, so the shared media ladders select by the caller's real selector),
with the dates, promises and their leftovers landed as catalog revisions
30-34, the first album menu as revision 35, the other twelve as revision 36, the 13 recollection ladders as revision 37, heroine K's conversation scripts as revision 38, the other conversation scripts as revision 39, `N_TALK1`'s third hop as revision 40, and every row's measured `resources` as revision 41 (WD-21 U2, 2026-10-08; no row added or changed otherwise), the 13 re-derived profiles' hashes as revision 42 (TD-56's bridge, 2026-10-10; no row, resource or other field changed) and the restored `LIBLARY.LIB` items in the `resources` of 293 rows as revision 43 (TD-56, 2026-10-11; 17,020 -> 18,113 items).

Closing proof of EP-14 (2026-10-11, Core 0.378.0, uncached because Core changed; `analysis/_docs/ep14_spec.md`): the whole `full` tier,
uncached with `--cache-store`, `--jobs 6` with `--elfimage`, `--exe` and `--godot`, detached through `launch_detached.py`, run solo, on the committed tree `a9de5086`, from an idle of 47.7% RAM. Last uncached whole batch: **479 checks, 479 passed, 0 failed, 2,400.5 s** (run `8b534111`, `cached: 0`; WD-10's batch took 2,546.4 s with the same 479 checks), **10,723.2 check-seconds against 10,715.5**; no check was added or removed, and the Core version moved every fingerprint. The analysis-group process, in two shards, read `shard plan: 1/2, 114 member(s), 1209.067s known, 0 unknown` and `process: ... [1/2] completed in 1771.984s`, and `shard plan: 2/2, 113 member(s), 1208.460s known, 0 unknown` and `... [2/2] completed in 1741.797s`: both started at +7 s and ran at about 0.22 of the 8,000 s timeout. Starts (offsets from the runner's start): the full handoff equivalence at +7 s, 574.4 s; **the Python regression suite at +581 s, within a second of the equivalence's end** (252.7 s); the analyzer handoff corpus, the transfer-direction corpus and `original playback package playback` at +834 s, 895.9 s, 905.8 s and 590.8 s; the export at +1,183 s, 317.2 s; `original mod bundle round trip` at +1,736 s, 213.5 s (keyed now, so it ran beside the corpora instead of alone at the tail, which is why the wall time is inside the unit's 2,330-2,500 s and 146 s under WD-10's). The 20 group-route shards' check-seconds rose 69.7 s (1,403.7 to 1,473.4), placement inside the batch rather than the library media (four shards that ran beside heavier work; the unit's own re-run of all 20 summed 1,407.2 s against WD-10's 1,403.7 s); the 227 analysis-group members and `original event analysis frontier` (228 rows by that prefix) did not move (2,550.9 s against 2,551.0 s). Memory: peak RAM **81.7%** (at +528 s, the equivalence-and-shards phase; WD-10's was 78.8%) and commit 62.4%, RAM at or above 70% in 43 of 236 samples and at or above 80% in three (+508, +518 and +528 s), never at 85%; one 10-second interval with `pgin_avg` over 1,000/s (5,400/s at +1,504 s, with a 0.5/s 2-second reading and a Godot working-set drop: a process turnover, not sustained). The highest timeout ratios: `original Audio Editor original integration` 122.8 s of 300 (0.409, inside its 0.29-0.42 band over 14 runs, not a trend), the transfer-direction corpus 905.8 s of 2,400 (0.377), the export 317.2 s of 900 (0.352), package playback 590.8 s of 1,800 (0.328), relocated message contextual authoring 270.5 s of 900 (0.301); **no check passed 0.5**. The 20 group-route shards inside the batch equal the unit's own re-run line by line: 681 / 839 / 58,186, pictures 2,573 of 2,643, effects 138 of 138, gate 2 184 / 0, gate 3 15,705 names and the library compare 694, 0 undeclared, coverage 497 of 1,093 (401 + 96). The export check printed `package_sha256=fe9bb6bd...` and the playback check `4749 checks over 681 catalog events` (Core 0.378.0). One Godot validator process crashed at start in the unit's replay regeneration (exit `0xC06D007F` after 3.2 s, no output, byte-identical when run alone) and did not recur: an observed, unreproduced start-up failure under six-way launch. Then `--cached --jobs 6` on the same tree: 479 of 479, all cached, 9.5 s (run `e9db1622`). Reports kept under `analysis/_undoc/ep14/c6/` (`closing.json`, `closing_cached.json`, the sampler `closing_mem.csv`).

Before it, the closing proof of WD-10 and TD-67 (2026-10-11, Core 0.377.0 unchanged, uncached because the runner changed; `analysis/_docs/wd10_spec.md`): the whole `full` tier,
uncached with `--cache-store`, `--jobs 6` with `--elfimage`, `--exe` and `--godot`, detached through `launch_detached.py`, run solo, on the committed tree `8f81d232`, from an idle of 46.5% RAM. Last uncached whole batch: **479 checks, 479 passed, 0 failed, 2,546.4 s** (run `e6cb6108`, `cached: 0`; TD-56's batch took 2,742.9 s with 477 checks), **10,715.5 check-seconds against 10,277.9**; the two checks added are `Godot test_mod_bundle_import.tscn` (11.9 s of 180) and `original mod bundle round trip` (179.5 s of 900, 0.20, tier `full`). Before the launch exactly 16 retired `original catalog group routes [k/4]` cache entries were deleted (10,321 -> 10,305), without `--cache-clear`. The analysis-group process, in two shards, read `shard plan: 1/2, 114 member(s), 1137.964s known, 0 unknown` and `process: ... [1/2] completed in 1755.032s`, and `shard plan: 2/2, 113 member(s), 1137.445s known, 0 unknown` and `... [2/2] completed in 1722.188s`: both started at +7 s and ran at about 0.22 of the 8,000 s timeout. Starts (offsets from the runner's start): the full handoff equivalence at +7 s, 576.3 s; **the Python regression suite at +583 s, within a second of the equivalence's end** (257.8 s; +1,426 s in TD-56's batch); the analyzer handoff corpus, the transfer-direction corpus and `original playback package playback` at +841 s, 892.4 s, 909.5 s and 596.5 s; the export at +1,192 s, 317.9 s; `original mod bundle round trip` at +2,355 s, 179.5 s. **The census is consistent with TD-67's fix 1 and does not discriminate by itself:** on this run's keys there was no tie, so the old runner would also have passed. The discriminating proof is the gate-level test `OrderedGateIdlenessTests` (`tests/test_validation_scheduler.py`, 48 tests; on `f7a19049`'s runner the new tests fail, 14 failures in 5 of them) and the model (2,744 s and 2,519 idle slot-seconds today against 2,324 s and 1 with fix 1, on TD-56's tie keys at `--jobs 6`). Memory: peak RAM 78.8% (at +519 s) and commit 61.7%, RAM at or above 70% in 37 of 250 samples and never at 80%, no sample with `pgin_avg` over 1,000/s. The highest timeout ratios: the transfer-direction corpus 909.5 s of 2,400 (0.379), the export 317.9 s of 900 (0.353), package playback 596.5 s of 1,800 (0.331), `original Audio Editor original integration` 91.0 s of 300 (0.303); **no check passed 0.4**. **The wall time is 46 s above the unit's 2,330-2,500 s:** the new check had no cache entry (its solo runs stored none), sorted after every keyed check and ran nearly alone at the tail, about 150 s over the work bound; that is not TD-67, and the 2,650 s stop was not reached. The export check printed `package_sha256=0e47e063...` and the playback check `4749 checks over 681 catalog events`, both unchanged. Then `--cached --jobs 6` on the same tree: 479 of 479, all cached, 9.5 s (run `aef4b99e`). Reports kept under `analysis/_undoc/wd10/` (`closing.json`, `closing_cached.json`, the sampler `closing_mem.csv`).

Before it, the closing proof of TD-56 (2026-10-11, Core 0.377.0, uncached because Core changed; `analysis/_docs/td56_spec.md`): the whole `full` tier,
uncached with `--cache-store`, `--jobs 6` with `--elfimage`, `--exe` and `--godot`, detached through `launch_detached.py`, run solo, on the committed tree `210162c4`, from an idle of 44.0% RAM and 43.1% commit (the sampler's first rows). Last uncached whole batch: **477 checks, 477 passed, 0 failed, 2,742.9 s** (run `bcd678df`, `cached: 0`; TD-64 part 2's batch took 2,452.2 s), **10,277.9 check-seconds against 10,874.6**. The analysis-group process, in two shards, read `shard plan: 1/2, 114 member(s), 1240.140s known, 0 unknown` and `process: ... [1/2] completed in 1658.875s`, and `shard plan: 2/2, 113 member(s), 1239.696s known, 0 unknown` and `... [2/2] completed in 1694.438s`: both started at +7 s and ran at about 0.21 of the 8,000 s timeout; the members' own durations sum 2,275.4 s. Starts (offsets from the runner's start): the full handoff equivalence at +7 s, 579.2 s; the transfer-direction corpus at +587 s, 839.3 s; **the Python regression suite at +1,426 s** (246.3 s; +616 s in the previous batch); the analyzer handoff corpus at +1,666 s, 931.8 s; `original playback package export` and `original playback package playback` at +1,672 s, 317.8 s and 628.9 s; the 20 group-route shards took 64.5-116.8 s each. Memory: peak RAM 79.1% and commit 61.9% (the pre-pass window 77.1% / 60.9%), **no sample row with page-ins over 1,000/s**. The slowest checks as fractions of their timeouts: `original Audio Editor original integration` 125.7 s of 300 (0.42), the export 317.8 s of 900 (0.35), the transfer-direction corpus 839.3 s of 2,400 (0.35), package playback 628.9 s of 1,800 (0.35), the analyzer handoff corpus 931.8 s of 3,000 (0.31); **no check passed 0.5**. **The wall time is 290.7 s above the previous batch's although the check-seconds fell by 596.7 s: the extra is idle slots.** The run's report path was new, so the ordering read cache durations only, and the transfer-direction corpus (key 945.5) and the Python suite (236.33 s x 4 slots, key 945.3) tied; when the equivalence freed its four slots the corpus took one and the suite, now the head, could not fit, so the strict-FIFO gate held three slots idle for 839 s, 2,517 slot-seconds, until the corpus ended (TD-67, since closed by WD-10's batch; TD-56 had no wall-time stop). Gate 3 compared 15,011 names with 0 undeclared and gate 2 had 184 registered misses, 0 unregistered, over 681 runs; **the library items TD-56 restored are outside that comparison**, because the Playback timeline presented no library-executed media at that Core (EP-14, closed 2026-10-11). The export check printed `package_sha256=0e47e063...` (the live v7 set is bound to it, 681 valid) and the playback check `4749 checks over 681 catalog events`. What the unit changed: Core 0.377.0 models the original's one storage behind command `0x09` and token `0xF6`; 9,527 of 12,871 replay runs moved, every one explained by a `0x09` write seen through `global_i32`; 13 analysis-group profiles were re-derived; the catalog went 41 -> 42 -> 43 (the 1,093 library items in 293 rows, 17,020 -> 18,113 items); the 681 v7 documents were re-projected with the library-set flags declared and the argument storage excluded (D11). Then `--cached --jobs 6` on the same tree: 477 of 477, all cached, 8.8 s (run `e60a071d`). Reports kept under `analysis/_undoc/td56/c6/` (`closing.json`, `closing_cached.json`, the sampler `closing_mem.csv`).

Before it, the closing proof of TD-64 part 2 and TD-65 (2026-10-10, Core 0.376.0, uncached because Core, the runner and the registry changed; `analysis/_docs/td64_p2_spec.md`): the whole `full` tier,
uncached with `--cache-store`, `--jobs 6` with `--elfimage`, `--exe` and `--godot`, detached through `launch_detached.py`, run solo, on the committed tree `1daa69ee`, from an idle of 42.7% RAM and 42.4% commit (the sampler's first rows). Last uncached whole batch: **477 checks, 477 passed, 0 failed, 2,452.2 s** (run `72b516cc`, `cached: 0`; TD-58's batch took 3,364.4 s and TD-57's 3,225.7 s), **10,874.6 check-seconds against 10,727**. The analysis-group process, in two shards, read `shard plan: 1/2, 114 member(s), 1223.035s known, 0 unknown` and `process: ... [1/2] completed in 1822.391s`, and `shard plan: 2/2, 113 member(s), 1222.510s known, 0 unknown` and `... [2/2] completed in 1802.125s`: both started at +8 s and ran at 0.23 of the 8,000 s timeout; the members' own durations sum 2,479.8 s. Starts (process creation minus the runner's): the full handoff equivalence at +8 s, 608.0 s; **the Python regression suite at +616 s, the moment the equivalence freed its slots** (252.7 s; +2,545 s in the previous batch, TD-65's proof); `original playback package playback`, no longer exclusive, at +869 s beside the transfer-direction and analyzer handoff corpora, 619.8 s; `original playback package export` at +1,231 s, 334.0 s; the 20 group-route shards took 1,444 s in all (66.1-85.8 s). Memory (RAM / commit peak): the pre-pass and equivalence window 72.0% / 56.9% (the batch's peak); 711-1,000 s 53.6% / 47.4%; 1,000-1,900 s (the shard loops, the corpora, playback and export) 64.8% / 53.3%; the tail 65.8% / 53.8%; **no sample row with page-ins over 1,000/s**. The slowest checks as fractions of their timeouts: the transfer-direction corpus 945.5 s of 2,400 (0.39), `original playback package export` 334.0 s of 900 (0.37), package playback 619.8 s of 1,800 (0.34), `original Audio Editor original integration` 96.4 s of 300 (0.32), the analyzer handoff corpus 937.2 s of 3,000 (0.31); **no check passed 0.5**. **The wall time is under the model:** the strict-FIFO model predicted 2,508 s (2,500-2,650 s expected, a stop at ~2,750 s) and the batch took 2,452.2 s; the first checks started at +8 s where the model carries 37 s, and the equivalence took 608.0 s against 673.7 s. TD-64 part 2 took the playback check's working set from 8.8 to 2.0 GB and the export's from 8.7 to 1.6 GB in their solo runs, byte-identical packages (the manifest differs in `package_sha256` and `content_core_version` alone; the live v7 set is rebound to `47b1ee8d...`, 681 valid). Then `--cached --jobs 6` on the same tree: 477 of 477, all cached, 8.8 s (run `d15a5def`). Reports kept under `analysis/_undoc/td64p2/` (`closing.json`, `closing_cached.json`, the sampler `closing_mem.csv`).

Before it, the closing proof of TD-58 and TD-64 part 1 (2026-10-10, Core 0.375.0, uncached because Core, the runner and the registry changed; `analysis/_docs/td58_spec.md`, `analysis/_docs/td64_p1_spec.md`): the whole `full` tier,
uncached with `--cache-store`, `--jobs 6` with `--elfimage`, `--exe` and `--godot`, detached through `launch_detached.py`, run solo, on the committed tree `d367b5bd`, from an idle of 35.8% RAM and 42.0% commit (the sampler's first row). Last uncached whole batch: **477 checks, 477 passed, 0 failed, 3,364.4 s** (run `d2144d74`, `cached: 0`; TD-57's batch took 3,225.7 s), **10,727 check-seconds against 10,007**. The analysis-group process, split into two shards, read `shard plan: 1/2, 113 member(s), 1117.295s known, 0 unknown` and `process: ... [1/2] completed in 1861.469s`, and `shard plan: 2/2, 114 member(s), 1117.733s known, 0 unknown` and `... [2/2] completed in 1867.391s`: both started at +37 s, 0.3% apart, 0.23 of the 8,000 s timeout (the single process took 3,192.9 s); the members' own durations sum 2,445.5 s (2,235.0). The full handoff equivalence started in the first wave (+37 s, 673.7 s); the Python regression suite started only at +2,545 s (247.4 s); the exclusive `original playback package playback` ran alone from +2,802 s, 559.9 s; the 20 group-route shards took 1,428 s in all (62.6-86.9 s). Memory (RAM / commit peak): the pre-pass and equivalence window 72.5% / 60.8% (TD-58's guard, at or below ~85%, holds); the export check's window 89.6% / 71.1%; the playback check alone 94.3% / 73.0% (TD-64); page-ins over 1,000/s in at most 6 of 135 samples per window, never sustained, and the commit charge never neared ~85%. The slowest checks as fractions of their timeouts: `original Audio Editor original integration` 125.8 s of 300 (0.42), the transfer-direction corpus 942.9 s of 2,400 (0.39), `original playback package export` 344.5 s of 900 (0.38), the analyzer handoff corpus 935.0 s of 3,000 (0.31), package playback 559.9 s of 1,800 (0.31); **no check passed 0.5**. **The wall time did not fall below ~3,000 s** (TD-64 spec D6; the model said ~2,300 s): the exclusive playback check costs ~560 s alone at the tail (TD-64 part 2 removes it), and the worker gate holds no reservation, so single-slot waiters took the equivalence's four slots when it ended at ~711 s and the suite's worker stayed parked until ~2,545 s, about one worker of six idle for ~1,800 s (TD-65). By owner ruling of 2026-10-10 ("close now, fix the gate together next") both units close on this batch and the gate rides with TD-64 part 2's uncached batch. Then `--cached --jobs 6` on the same tree: 477 of 477, all cached, 9.9 s (run `68be8eb1`). Reports kept under `analysis/_undoc/td58/` (`closing2.json`, `closing2_cached.json`, the sampler `closing2_mem.csv`).

Before it, the closing proof of TD-57 (2026-10-09, Core 0.374.0, uncached because Core changed; `analysis/_docs/td57_spec.md`): the whole `full` tier,
uncached with `--cache-store`, `--jobs 6` with `--elfimage`, `--exe` and `--godot`, detached through `launch_detached.py`, run solo, on the committed
tree `7331ea26`. Last uncached whole batch: **477 checks, 477 passed, 0 failed, 3,225.7 s** (run `37a06f05`, `cached: 0`; U2's batch took 4,770.3 s),
**10,007 check-seconds against 21,975**: the 20 group-route shards **1,394 s against 13,473 s** (63.2-83.1 s each; shard 1 solo 77.2 s against
797.7 s in C2, its JSON line byte-identical), the Event Player checks 124 s (217), package export and playback 941 s (933), the four
contextual-authoring checks 1,024 s (993), the 227 analysis-group members 2,235 s (2,260). The `process:` line read **3,192.9 s for the
analysis-group process, 0.40 of its 8,000 s - 99% of the wall time**, the batch's floor (TD-58). The slowest checks as fractions of their timeouts:
the transfer-direction corpus 898.0 s of 2,400 (0.37), `original playback package playback` 636.7 s of 1,800 (0.35), `original playback package
export` 304.3 s of 900 (0.34); **no check passed 0.38**. The export check printed `package_sha256=5ae6aabe...`, the package C4 exported and rebound
the live v7 set to; gate 3 15,011 names, 0 undeclared; gate 2 184 registered, 0 unregistered. Then `--cached --jobs 6` on the same tree: 477 of 477,
all cached, 61.9 s (run `523b0a4b`). Reports kept under `analysis/_undoc/td57/` (`closing.json`, `closing_cached.json`).

Before it, the closing proof of WD-21 U2 (2026-10-08/09, Core 0.373.0 unchanged, uncached because the v7 contract and the catalog revision changed;
`analysis/_docs/wd21_u2_spec.md`): the whole `full` tier, uncached with `--cache-store`, `--jobs 6` with `--elfimage`, `--exe` and `--godot`, detached
through `launch_detached.py`, run solo, on the committed tree `d5fa4395`. Last uncached whole batch: **477 checks, 475 passed, 2 failed, 4,770.3 s**
(run `4d0be71d`, `cached: 0`; the 475 of U1 plus `test_replay_run_media.tscn` and `test_declared_media.tscn`). The two failures had one cause:
`config/event_catalog/route_classification_v1.json` binds the SHA-256 of the catalog's canonical JSON, and C5 bumped the catalog to revision 41 without refreshing it
(`original event analysis frontier`: "Classification is not bound to this catalog revision"; `original event corpus literal dispatch inventory`: the
classification does not reproduce). `tools/refresh_route_classification.py` showed `catalog_sha256` as the only delta (no row, class or confidence
moved); the two hash lines were patched in place (`425d9b0d`), the classifier's `--check` passed, and the two checks passed solo with `--cache-store`
(128.2 s and 168.8 s of 600). Then `--cached --cache-store --jobs 6` on `425d9b0d`: **477 of 477, 474 cached, 242.6 s** (run `94a6094d`; re-run: the
`python regression suite` 236.1 s, `original duplicate archive entries` 21.8 s, `unreferenced archive entries` 5.0 s). In the uncached run the
`process:` line read **3,180.4 s for the analysis-group process, 0.40 of its 8,000 s** (3,691.5 s in U1's batch), `Godot project parse check` 14.8 s
of 120 s; the slowest checks as fractions of their timeouts: the transfer-direction corpus 875.2 s of 2,400 (0.36), `original playback package
playback` 634.6 s of 1,800 (0.35), `original playback package export` 298.4 s of 900 (0.33), `original Audio Editor original integration` 86.8 s of
300 (0.29), the analyzer handoff corpus 866.5 s of 3,000 (0.29), the 20 group-route shards at most 793.9 s (0.26); **no check passed 0.37** (the highest is 0.365). The
five checks whose input closure names the classification (`--fingerprint-inputs`) are exactly the two fixed ones and the three the cached run
re-ran, so its 474 cached results cover the fix. The
shards passed with **gate 3: 15,011 played names compared over 681 Playback runs, 0 undeclared**, gate 2: 70 picture and 114 animation-source misses,
all 184 registered, 0 unregistered, voices 8,621 and BGM 1,801 found; the export check printed `681 events from 869 member entries (188
catalog-verified, 681 bound by 227 analysis groups)` (package `874f53ca...`) and the playback check `4749 checks over 681 catalog events`. Reports
kept under `analysis/_undoc/wd21_u2/` (`closing.json`, `closing_fix_targeted.json`, `closing_cached.json`).

Before it, the closing proof of WD-21 U1 (2026-10-07, Core 0.373.0, uncached because Core, the package contract and the registry changed; `analysis/_docs/wd21_u1_spec.md`): the
whole `full` tier, uncached with `--cache-store`, `--jobs 6` with `--elfimage`, `--exe` and `--godot`, detached through `launch_detached.py`, run solo, on the committed
tree `dc99e46` (the unit's code and contract commits, the TD-53 cache fix, the TD-54 registry change `cdd5b5f` and the stale-record rewrite). Last uncached whole batch:
**475 checks, 475 passed, 0 failed, 5,253.6 s** (run `7513c6ad`, `cached: 0`; the 473 of TD-52 plus the two new scenes `test_known_absent_media.tscn` and `test_playback_media_inventory.tscn`):
the `process:` line read **3,691.5 s for the analysis-group process, 0.46 of its 8,000 s** (3,664.3 s in the TD-52 batch), `Godot project parse check` took 17.0 s of 120 s (0.14); the slowest
checks as fractions of their timeouts were the transfer-direction corpus 1,004.5 s of 2,400 (0.42), `original playback package playback` 745.1 s of 1,800 (0.41; 621.4 s in the
TD-52 batch - the reader's inventory recompute adds about 11 s to each load and the manifest is 5.8 MB larger; the rest of the growth is not isolated), the analyzer handoff corpus 997.3 s of 3,000 (0.33),
`original playback package export` 309.1 s of 900 (0.34), `original Audio Editor original integration` 95.4 s of 300 (0.32) and the 20 group-route shards 582-906 s of 3,000 (0.30 at most); **no check
passed 0.45 of its timeout** (the highest is 0.42). The three contextual-authoring checks that TD-54 moved to the `full` tier at 900 s took 221.8 s (`edited event`, 0.25), 242.5 s (`relocated message`, 0.27)
and 231.0 s (`resource`, 0.26); `sequence`, unchanged at 1,200 s, 338.8 s (0.28). The 20 shards passed (`PASS shard`, none `FAIL shard`): 681 playback runs, 70 picture and 114 animation-source misses,
**all 184 registered in the known-absent register, 0 unregistered**, voices 8,621 of 8,621 and BGM 1,801 of 1,801 found; the export check printed `681 events from 869 member entries (188 catalog-verified, 681 bound by 227 analysis groups)`
and the playback check `4749 checks over 681 catalog events`. Then `--cached --jobs 6` on the same tree: 475 of 475, all cached, 8.5 s (run `3b0a2572`); reports kept under `analysis/_undoc/wd21_u1/`
(`closing.json`, `closing_cached.json`).

Before it, the closing proof of TD-52 (2026-10-06, Core 0.372.0 unchanged, no contract or analyzer change; `analysis/_docs/td52_spec.md`): the whole `full` tier,
uncached with `--cache-store` (the runner changed, and it is an input of every check), `--jobs 6` with `--elfimage`, `--exe` and `--godot`, detached
through `launch_detached.py`, on the committed tree `ebd440a` (the fix `274fd97`, which makes the runner write an empty, untracked `analysis/.gdignore`
before any check so the editor's first scan skips the working directory, plus the review fixes). Last uncached whole batch: **473 checks, 473 passed,
0 failed, 5,282.4 s** (run `a171a199`, `cached: 0`): **`Godot project parse check` 8.86 s of 120 s, 0.07, against 79.9 s, 0.67, in the TD-51 batch** (solo
40.3 and 38.6 s before the marker, 6.5 s after; the local tier 7.95 s; the log block shows `first_scan_filesystem` and `--- PASSED`); the runner wrote the
marker at the batch start (it had been deleted before the launch); the `process:` line read **3,664.3 s for the analysis-group process, 0.46 of its
8,000 s**, under TD-51's 4,000 s re-application trigger (3,614.5 s then); the slowest other checks were the transfer-direction corpus (1,015.5 s, 0.42 of
2,400), `original relocated message contextual authoring` (245.9 s, 0.41 of 600), `original edited event contextual authoring` (221.3 s, 0.37 of 600) and
`original resource contextual authoring` (220.4 s, 0.37 of 600), and **no check passed 0.5 of its timeout** (`todo/code_health.md` TD-52, closed). Then `--cached --jobs 6` on the same tree: 473 of 473, all
cached, 7.7 s (run `0a056ef6`); reports kept under `analysis/_undoc/td52/`.

Before it, the closing proof of TD-51 (2026-10-05, Core 0.372.0 unchanged, no contract or analyzer change; `analysis/_docs/td51_spec.md`): the whole `full` tier,
uncached with `--cache-store` (the registry and the runner changed, and both are inputs of every check), `--jobs 6` with `--elfimage` and `--exe`,
detached through `launch_detached.py`, on the committed tree `ce65d78` (the fix `eb8b09e`, which raised `families.analysis_group.process_timeout`
3,600 -> 8,000 s and made the runner print the process's own `process:` line, plus the review fixes). The uncached whole batch of that unit:
**473 checks, 473 passed, 0 failed, 5,177.3 s** (run `97d1723b`, `cached: 0`): the `process:` line read **3,614.5 s for the analysis-group
process (227 members; their own durations sum 2,425 s), 0.45 of its 8,000 s** (it would have exceeded the old 3,600 s; the acceptance bound
was 4,000 s), and the slowest other checks were the transfer-direction corpus (1,117 s, 0.47 of 2,400), the analyzer handoff corpus (1,119 s,
0.37 of 3,000) and the 20 group-route shards (574-986 s, 0.33 of 3,000 at most); **one check passed half of its timeout: `Godot project parse
check`, 79.9 s of 120 s, 0.67 (`todo/code_health.md` TD-52, open then and closed by the batch above; reported, not changed)**, and the four TD-46 checks ran 0.21-0.25. Then
`--cached --jobs 6` on the same tree: 473 of 473, all cached, 7.7 s (run `6527acea`); reports kept under `analysis/_undoc/td51/`.

Before it, the closing proof of the EP-12 TALK follow-ups unit (2026-10-05, no Core or contract change, committed tree `faa917f`): `--cached --jobs 6`
with `--elfimage` and `--exe`, detached; every archive and full check re-ran (the registry and the catalog changed). Run `5865c21a`:
**246 of 473 passed, 136 of them cached (4,973 s), and the analysis-group process timed out at 3,600 s with eight of its 227 groups left**
(`todo/code_health.md` TD-51, open then and closed by the batch above: the family had never had twice its loaded duration; the unit's own group validated in 15 s); the playback
package export took 315 s of its 900 s (0.35, TD-50) and no other check passed 0.45 of its timeout (the transfer-direction corpus 1,091 s
of 2,400, the 20 group-route shards 620-976 s of 3,000). The same command again (run `f02e7da7`, the 246 passes cached, the process alone): **473 of 473
passed, 3,084 s**. Reports kept under `analysis/_undoc/ep12_talk_followups/`. The last uncached whole batch before these two runs: Core 0.372.0 on 2026-10-05, `--tier full --jobs 6
--cache-store` (uncached: 26 new checks and a Core change), with `--elfimage` and
`--exe`, detached through `launch_detached.py --godot`, on the committed tree
`19a3853` (the EP-12 TALK rest unit, `analysis/_docs/ep12_talk_rest_spec.md`: the other eleven
heroines', Tina's and the characters' 105 conversation scripts, 681 catalog rows, 20 group-route
shards): **473 checks, 473 passed, 5,156 s** (run `375b8653`, `cached: 0`; the slowest are the
transfer-direction corpus, 1,001 s, 0.42 of its 2,400 s timeout, the analyzer handoff corpus, 991 s, and
the 20 group-route shards, 599-867 s, 0.29 of their 3,000 s timeout at most; the 28 TALK checks 13.9-59.5 s;
**one check passed half of its timeout: the playback package export, 326 s of 600 s, 0.54, moved to the `full` tier at 900 s
(`todo/code_health.md` TD-50, closed 2026-10-05); every other check under 0.42, the four TD-46 checks at 0.22-0.26**), then
`--cached --jobs 6` on the same tree: 473 of 473, all cached, 8.2 s (run `30ddba75`); reports kept under
`analysis/_undoc/ep12_talk_rest/`. Before it: Core 0.371.0 on 2026-10-04, `--tier full --jobs 6
--cache-store` (uncached: 2 new checks and a Core change), with `--elfimage` and
`--exe`, detached through `launch_detached.py --godot`, on the committed tree
`7fff4af` (the EP-12 TALK K unit, `analysis/_docs/ep12_talk_k_spec.md`: heroine K's nine
conversation scripts, 576 catalog rows, 20 group-route shards): **447 checks, 447 passed,
4,538 s** (run `2395516c`, `cached: 0`; the slowest are the transfer-direction corpus, 958 s,
0.40 of its 2,400 s timeout, the analyzer handoff corpus, 951 s, and the 20 group-route shards,
538-665 s, 0.22 of their 3,000 s timeout at most; the two new TALK checks 39.5 s and 14.3 s;
**every check under 0.41 of its timeout, and the four TD-46 checks at 0.21-0.27 of their raised
timeouts**), then `--cached --jobs 6` on the same tree: 447 of 447, all cached, 7.1 s (run
`d71d0bf7`); reports kept under `analysis/_undoc/ep12_talk_k/`. Before it: Core 0.370.0 on 2026-10-04,
`--tier full --jobs 6
--cache-store` (uncached: 13 new checks and a Core change), with `--elfimage` and
`--exe`, detached through `launch_detached.py --godot`, on the committed tree
`2eb1127` (the EP-12 H unit, `analysis/_docs/ep12_h_43c_spec.md`: 13 recollection
ladders, 567 catalog rows, 20 group-route shards): **445 checks, 445 passed, 5,155 s**
(run `4f1ae99f`, `cached: 0`; the machine ran about 14% slower per check than in the
previous whole batch, median ratio over the 69 checks above 20 s; the slowest are the transfer-direction
corpus, 1,062 s, 0.44 of its 2,400 s timeout, the analyzer handoff corpus, 1,049 s, and the 20
group-route shards, 587-769 s, 0.26 of their 3,000 s timeout at most; the 13 new ladder checks
17.7-22.7 s each; **four small-timeout checks reached 0.50-0.64 of their 120/300 s timeouts in
the loaded run and 0.43-0.49 solo - none is touched by this unit, `todo/code_health.md` TD-46**),
then `--cached --jobs 6` on the same tree: 445 of 445, all cached, 8.5 s (run `8fee3d9b`);
reports kept under `analysis/_undoc/ep12_h_43c/`. Before it: Core 0.369.0 on 2026-10-04,
`--tier full --jobs 6
--cache-store` (uncached: the registry's shard count and 12 new checks change
the plan and the timing baseline) with `--elfimage` and `--exe`, detached through
`launch_detached.py --godot`, on the committed tree `0d03d1e` (the EP-12 all-menus
unit, `analysis/_docs/ep12_scene_all_menus_spec.md`: 13 album menus, 554 catalog
rows, 20 group-route shards): **432 checks, 432 passed, 4,251 s** (run `eab1a1e1`,
`cached: 0`, parallel efficiency 0.74; the slowest checks are the transfer-direction
corpus, 941 s, 0.39 of its 2,400 s timeout, the analyzer handoff corpus, 875 s, and
the 20 group-route shards, 507-695 s, 0.23 of their 3,000 s timeout at most; every
check under 0.5 of its timeout), then `--cached --jobs 6` on the same tree: 432 of
432, all cached, 6.7 s (run `50c1b014`); reports kept under
`analysis/_undoc/ep12_all_menus/`. Before it: Core 0.369.0 on `46f8eff` (the EP-12
v14 variant fields unit): 403 checks, 403 passed, 3,006 s (run `e280b8c4`; the four
group-route shards 977-1,238 s). Before that: Core
0.368.0 on 2026-10-03, `--tier full --jobs 6
--cache-store` with `--elfimage` and `--exe`, detached, on the committed tree
`7c50cdd` (TD-42's member-sum ordering): **402 checks, 402 passed, 3,021 s**
(run `ebedba7f`; parallel efficiency 0.63, RAM peak 77.0%, no sustained
page-ins), then `--cached --jobs 6` on the same tree: 402 of 402, all cached,
5.7 s (run `329d4a19`); reports kept under `analysis/_undoc/td42/`;
`todo/code_health.md` TD-42. Before it: the same day's batch on `41ff67a`,
402 passed, 3,980 s (run `5351ac5c`; a `--jobs 5` run `f20c55b6` took
4,143 s; on `2a1283f` a `--cached --jobs 6` run `47c62764` passed 402 of 402,
401 cached, the regression suite re-running 247 s because `tools/` is in its
input tree; `todo/code_health.md` TD-40), and the `--jobs 4` batch on
`b9fa356`, 402 passed, 4,564 s (run `43cee30e`), whose batches found and
closed the three reproducibility failures of TD-36 and the authoring
deadline of TD-38.
Previous whole batch: Core 0.360.0 on 2026-09-23, `--tier full --jobs 4` with
`--elfimage` and `--exe`, uncached, on a detached worktree of the committed
tree `db59f4b`: **375 checks, 375 passed, 2,897 s** (report
`kakyu_content_tools_validation/v6`, kept under `analysis/_undoc/`; the
three extra checks are the four shards of `original catalog group routes`
replacing the one check). Earlier the same day (step 1), sequentially, on
`5fb4337`: 372 checks, 371 passed, 1 timed out, 7,638 s
(report `kakyu_content_tools_validation/v5`, kept under `analysis/_undoc/`).
The non-pass is `original catalog group routes` at its 1,800 s limit while
two agents shared the machine; it takes ~1,500 s alone and passed in 1,537 s
on the next tree the same day. Every other check passed - the 227 archive
checks (the full Python handoff equivalence 1,212 s, the transfer-direction
corpus 793 s, the handoff corpus audit 622 s), the 12 native executable
checks, the event corpus and the voice payload. The
previous whole batch was Core 0.350.0 on 2026-09-19 (WD-18: 372 of 372,
7,989 s, run `5d44ef6a`); the Core 0.318.0 run and the earlier review
baselines remain historical evidence in `todo/code_health.md`.

## Execution Order

Re-sorted 2026-09-23 against the final goal above: trust in the batch first,
then the analysis evidence the goal is judged by, then the owner's
acceptance of the instrument, then what the mod player consumes, then the
tools' own identity and distribution. The owner's numbered choice overrides
this order; a bounded prerequisite of an item may be taken early.

1. **Whole batch at Core 0.360.0 (EP-05, validation trust) - done
   2026-09-23: 375 of 375 at `db59f4b`** (the gate above), after a
   sequential 371 of 372 at `5fb4337` whose one non-pass, a timeout under
   shared load, TD-33's shards removed. EP-05 closed by the owner on that
   evidence the same day.
2. **Close the analysis gaps the goal is judged by (EP-03, `todo/event_player.md`).**
   Done 2026-09-23: 20 of the 23 package-playback stops were declared
   place-menu endings and are counted as such; the three GROUND H01/H02 rows
   end by continuing into the next event (owner ruling; catalog revision 26,
   all 142 rows `minimal_playback`, 0 stopped); the EVENT entry nothing names
   keeps its evidenced class. Measured the same day and still open, each to
   be measured again before it is acted on:
   - `EVENTM11.MES` - measured 2026-09-23: EVENTM10 calls it once on each
     of its second to fourth visits behind a 23-flag gate; replays with a
     seeded visit counter reach it; site B's flag is cleared by the
     day-change definition (12) whenever the clock crosses midnight, so the
     later visits come one day at a time. Owner ruling the same day:
     census first - 9 entries, 84 rungs, 74 undeclared (EVENTM03 alone has
     a 15-visit ladder no route reaches) - then one representation for all
     of them: EP-11 (a route's `visits`, played by the Event Player) and
     WD-23 (`kakyu_event_definition/v5` for the remake), both approved.
   - Done the same day: `05C.MES` - it has exactly two callers, the most
     any EVENT target has, so the caller-count rule did not make it a system
     script; by owner ruling a non-EVENT script that is the measured caller
     of an analysis group (it hosts an EVENT intro) is now a system script
     (classification 130 / 35 / 1 / 1).
   - Done the same day: EVENTC06 and EVENTE11 at `15C.MES` - the catalog-side
     vocabulary now reads their `loop_boundary` (menu-loop) ending as
     `place_menu`, as the v4 and profile rules do.
   - 10 of 668 pictures the playback pass does not resolve - named
     2026-09-23: six pictures (`b01z`, `b02z`, `b02zan`, `d01z`, `d01zan`,
     `d02z` `.mmo`) the B01/B02/D01/D02 scripts name and no shipped archive
     contains, an original-data fact recorded in the 12C/13C docs; the check
     still only counts them - making it accept exactly these and fail on a
     new miss belongs with WD-21's honest media report (step 4).
     *Annotation 2026-10-07: done by WD-21 U1 C3 (2026-10-06). The figure above is the
     142-row catalog's; at 681 rows the playback pass misses 61 picture names and 102
     animation sources, all of them in the known-absent register (161 `.mmo` and 66
     `.AX` names in all, 19 loader strings besides), and the group-route shard now
     fails on a miss the register does not list (C3.5 pre-run `0dd818e6`, 20 shards:
     184 registered misses, 0 unregistered).*
   **Batch efficiency (owner, 2026-09-23), done the same day:** the TD-32
   cache now keys the project root as `<PROJECT>`, so a worktree run seeds
   the main checkout; parallel checks with a four-shard group-routes check
   (TD-33, closed: 375 of 375 in 2,897 s at `--jobs 4` against 7,638 s);
   one shared package build (TD-34) closed without a change after
   measuring ~0.8% of the batch (`todo/code_health.md`).
   **Owner findings from playback (2026-09-24), before step 3:** EP-13 -
   the still pictures come from the surface trace (a surface-8 load is an
   animation source, never a still; event CG replaces background; standing
   pictures keyed on top), and one playback step per spoken line so
   `[<name>]line` reads as one line (`todo/event_player.md`) - done the
   same day (Core 0.362.0), and the WD-19 build rebuilt at it
   (`analysis/windows-suite-0362-20260924`).
   **Owner ruling (2026-10-05): EP-12 is closed** (`todo/event_player.md`, which
   records its four deferred items). Step 3 still waits on the owner's WD-19
   report, and **WD-21 (step 4) is the next work** by owner ruling, after TD-51
   (batch trust, `todo/code_health.md`; closed 2026-10-05, its closing batch
   passed 473 of 473, and TD-52, opened beside it, was closed 2026-10-06 by its own batch, 473 of 473).
3. **Owner acceptance of the instrument (WD-19 run sheet, owner action).**
   The sheet on the Core 0.378.0 build (`analysis/windows-suite-0378-20261011/`)
   covers EP-10's first representatives (items 4-6), EP-06's frame check,
   WD-15's monitor/DPI part and MV-06, and the later items 7-9 (the catalog
   run-settings layout, EP-13's stills and lines, EP-14's library pictures
   and sound effects).
   Nothing is requested again until the owner reports; on the report, EP-10
   takes golden-frame comparison for what was accepted and closes, and EP-06
   and WD-15 close or return with findings. If step 1 or 2 changes what
   plays, rebuild the release suite before the sheet is run.
4. **The package's dependency report and its remaining units (WD-21).** The
   package carries every row and, since U1 (Core 0.373.0, 2026-10-06), the
   inventory of every media and script reference with source evidence, which
   media the original archives ship and which they do not (the known-absent
   register the batch gates on), and the manifest's catalog binding; the
   caller-owned completion terminals are inside the full export
   (`external_terminals` is empty) and the media extraction stays deferred.
   What remains, by owner ruling: U2 (the per-row `resources` taken from the
   measured route), U3 (the CG table exported from the original `?_CG.MES`,
   with the page layout) and U4 (modified shared entries in an authored
   export; deferred). This is what lets the mod player rely on a package
   without the archive. **Status 2026-10-07: U1 is done** (the uncached whole
   batch, 475 of 475, `dc99e46`; `todo/workspace_distribution.md` WD-21); WD-21
   stays open, with U2 next by owner ruling, then U3, and U4 deferred.
   **Status 2026-10-09: U2 is done** (each row's `resources` from its measured
   route, `kakyu_event_definition/v7` bound to `874f53ca...` (rebound by
   TD-57, 2026-10-09, to the Core 0.374.0 export `5ae6aabe...`, by TD-64,
   2026-10-10, to the Core 0.375.0 export `ede69366...`, and by TD-64 part 2,
   2026-10-10, to the Core 0.376.0 export `47b1ee8d...`, and by TD-56, 2026-10-11, re-projected and rebound to the Core 0.377.0 export `0e47e063...` at catalog revision 43), catalog
   revision 41, gate 3; closing batch 477 of 477, `425d9b0d`;
   `todo/workspace_distribution.md` WD-21). WD-21 stays open with U3 and U4
   (deferred); TD-56 restores the library items later.
   **Owner ruling 2026-10-08: right after U2, the batch speed items** in the
   order `todo/code_health.md` records ("Batch speed order"): measure
   TD-57's share of the batch, then TD-57 (the Event Player's whole-archive
   re-hash, which also makes voice playback slow), TD-58 (split the
   analysis-group process), TD-47 (cache each row's playback output, re-run
   the assertions), TD-59 (a seeded sample mode for iteration only) and
   TD-60 (presentation-only regeneration); TD-61 later. Closing proofs stay
   exhaustive. Where U3 falls relative to these is not ruled.
   **Status 2026-10-09: the measurement and TD-57 are done** (Core 0.374.0;
   the batch 4,770 -> 3,226 s wall, 21,975 -> 10,007 check-seconds; the owner
   confirmed voice playback without the per-line stall). **TD-58 is next**: the
   analysis-group process is now 99% of the wall time. TD-47 and TD-59 lost
   their premise (about 2 s per catalog row now) and are re-assessed when
   their turn comes (`todo/code_health.md`).
   **Owner rulings 2026-10-09, evening:**
   - **U3 is withdrawn.** No CG table is written as long as the pictures themselves are there.
     Of the 572 pictures the 13 viewers load, all ship in `mmo.arc` and 556 are package inventory
     names; the other 16 are recorded in WD-21.
   - **TD-58 proceeds.**
   - TD-47, TD-59, TD-60 and TD-63 leave the order; each is taken up only when the batch's speed
     gets in the way of the work.
   - WD-21 stays open with U4 (deferred) and TD-56's library items.
   **Status 2026-10-10: TD-58 is done and TD-64 part 1 is done** (Core 0.375.0; the analysis-group process split into two shards, 3,193 -> 1,861 and 1,867 s; the package playback check no longer holds the package twice or keeps a codec per entry, and runs alone, last; the closing batch 477 of 477 in 3,364 s and 10,727 check-seconds, `todo/code_health.md`).
   **Owner rulings 2026-10-10:**
   - TD-64 part 1 now, on the advisor's recommendation, and TD-64 part 2 (the lighter `KakyuPlaybackPackage`) right after TD-58.
   - After the closing batch missed the wall-time bound: "close now, fix the gate together next". TD-58 and TD-64 part 1 close on that batch; the worker gate's missing reservation (TD-65) rides with part 2's uncached batch, with no extra batch now.
   - **TD-64 part 2 with TD-65 is the next batch speed work.**
   **Status 2026-10-10, later: TD-64 part 2 and TD-65 are done** (Core 0.376.0; the package reader keeps each member's verified bytes and parses a code source on demand under a bounded cache, the exporter serializes each member as it is built, and the worker gate serves waiters in arrival order; the playback check no longer runs exclusive and its working set fell from 8.8 to 2.0 GB, the export's from 8.7 to 1.6 GB; the closing batch 477 of 477 in 2,452 s and 10,875 check-seconds, the Python suite starting at +616 s instead of +2,545 s, `todo/code_health.md`). The batch is now below TD-57's wall time (3,226 s). The remaining speed items (TD-47, TD-59, TD-60, TD-63) are on demand by the owner's ruling of 2026-10-09, and TD-61 stays deferred.
   **Status 2026-10-11: TD-56 is done** (Core 0.377.0; command `0x09` and token `0xF6` address one storage and the runner models it, so the shared `LIBLARY.LIB` media ladders select by the caller's real selector; 13 analysis-group profiles re-derived, the catalog at revision 43 with the 1,093 library items restored and the 681 v7 definitions re-projected, rebound to export `0e47e063...`; TD-55 closed inside it; the closing batch 477 of 477 in 2,743 s and 10,278 check-seconds, `todo/code_health.md`). The batch's wall time rose by 291 s because the worker gate idled three slots on an ordering tie (TD-67, closed 2026-10-11 with WD-10). At that Core the Playback timeline presented no library-executed media, so those items were verified by the join, not by playback (EP-14, closed 2026-10-11, below). WD-21 stays open with U4 (deferred) alone.
5. **The portable mod bundle (WD-10).** One mod artifact carrying the
   authored deltas (v9) and the mod definition set
   (`kakyu_mod_definition_set/v1`), built, validated and reopened against a
   matching source. Import conflicts stay deferred with WD-12 (no merge of
   two mods is requested); clean-machine delivery was WD-20 (closed
   unverified by the owner, 2026-10-09).
   **Status 2026-10-11: WD-10 is done** (Core 0.377.0 unchanged; `kakyu_mod_bundle/v1` carries a workspace's authored deltas, its translation-only entries and its definition set in one file, `tools/mod_bundle.py` builds and validates it, and one staged-import engine reconstructs it into a fresh workspace and reopens every effective identity; a deltas-only bundle's mod identity is verified and not persisted, because a workspace derives `mod_id` from its definitions; the closing batch 479 of 479 in 2,546 s and 10,716 check-seconds, `todo/workspace_distribution.md`). TD-67 closed with it: the multi-slot checks run back to back at every `--jobs`, and the Python suite started within a second of the equivalence's end (`todo/code_health.md`). The Launcher's export and import of the bundle is WD-24, unscheduled. The owner's queue of 2026-10-11 was WD-10, TD-67, EP-14, then WD-19; EP-14 is done (below).
   **Status 2026-10-11: EP-14 is done** (Core 0.378.0; the Playback pass presents the pictures and sound effects the shared `LIBLARY.LIB` routines execute - routine 27's place backgrounds as base pictures by the EP-13 surface rule, routine 9's sound effects fire-and-forget on the EP-10 channel - through a separate anchored `library_media` list, so that no run moved: 227 of 227 replays byte-identical, and the v7 set was rebound with `--pair core-version` to the export `fe9bb6bd...`; gate 3 compares them by name and at their exact library coordinates, and the coverage report shows 497 of the 1,093 declared library items presented by the default runs - the other 596 are 508 with no presented form and 88 reached only through non-default variants; the closing batch 479 of 479 in 2,401 s and 10,723 check-seconds, `todo/event_player.md`). Sound effects share one effect channel that every request restarts, and the original's screen refresh is unresolved; overlap and queues stay PR-04's and the surface lifetime PR-01's. **Next: WD-19**, the owner's acceptance of the first representatives; because EP-14 changes what plays, the release suite was rebuilt at Core 0.378.0 before the sheet is run (the rule of step 3, written for steps 1 and 2, applies for the same reason): `analysis/windows-suite-0378-20261011/`, 2,788 inventoried files, fingerprint `0740e55e...`, all six apps verified at `0.378.0.0`, and the sheet (items 1-9, item 9 being EP-14's) is ready for the owner.
6. **Application identity and delivery.** WD-14 closed 2026-10-09: the
   icons are Godot's default by owner ruling. WD-11 (ARC-set materialization) has no scoped content yet
   and needs a definition from the gap matrix's S-05 before it is worked.
   WD-20 was closed unverified by the owner on 2026-10-09 (no clean environment; reopen
   when one exists).
   **Opened 2026-10-11: WD-25, public release preparation** (`todo/workspace_distribution.md`).
   The native executable audits' data derived from the user-owned original executable, so the
   owner made the repository private while it is prepared for a public, source-only snapshot.
   Items 1 and 1b (no original executable or archive content in tracked files) closed
   2026-10-12; the public snapshot (7a) is built and proven, awaiting the owner's approval,
   and its first push waits for it. The license, the README notice, the history, the author e-mail, the public scope
   and the timing were ruled by the owner (D1-D6).

Closed since the 2026-09-16 sort, recorded in the domain trackers: the
whole-tree batch at 0.350.0 (WD-18), package membership by analysis-group
binding (WD-21 first unit), the WD-22 widening to 142 v4 documents, MW-11's
edit families and sequences, their carriage through export and delta, the
tools' extraction/media/browser/launcher features (WD-01/02/03/04/05/07/09,
ME-02/03/05/06), the Definitions tab and its structured form (MW-13), TD-05,
TD-08, TD-10, TD-11, TD-32, EP-07, EP-09 and EP-10 units 1-5.

The [Python analysis frontier](docs/spec/mes/event_analysis_inventory.md)
and the [route classification](docs/spec/mes/event_route_classification.md)
are the source-bound inventories; the route toolchain (`tools/README.md`)
qualifies a root-replacement or nested-call group from a spec. Analysis
witnesses do not automatically promote catalog playback coverage.

This sequence does not claim to close every product requirement, and the
owner's numbered choice overrides it.

### Deferred, and therefore not newly scheduled

- Delta import conflicts and their UI (WD-12) until a
  second mod has to be merged into one workspace (owner, 2026-09-17,
  reaffirmed 2026-09-20); WD-10 itself closed 2026-10-11, and the Launcher's
  export and import of the bundle is WD-24, unscheduled. Clean-machine delivery (WD-20) is no longer
  deferred but closed unverified (owner, 2026-10-09).
- The original player's presentation and audio runtime (PR-01..PR-04) by
  stance (2026-09-17); EP-10 reopened PR-01 only as far as stills need it
  and PR-04 only as the minimal BGM/voice/SE state. PR-02 (AX) and PR-03
  (A6 input) stay deferred: the instrument plays no animation and takes no
  game input beyond menus.
- Original-engine replacement checks (ME-01, ME-04, MV-01..03) by stance.
- TD-07 (typed parameters in place of the Dictionary context blobs) by the
  instrument stance; the UI-touching half of TD-11 by the owner's closure.
- An animation timeline contract (PNG frames plus a JSON timeline in place of
  AX playback in the mod player), raised 2026-09-16 and skipped by the owner.
- A drawn train map for the H07/M06/M09 rides: the contract's supplied
  locations are visible in the trace and the rides are measured groups.
- Previously deferred GUI/audio/original-engine verification remains in
  `todo/manual_verification.md`; do not re-request it as a routine coding gate.
- No implementation work in `kakyu-remake` is scheduled from this repository,
  and nothing there is edited from here. The shared conventions it consumes
  (the JSON contracts under `config/contracts/`) change here only; its v4
  consumer and its adoption of a revision are its own backlog.

## Repository State

This repository was split from `kakyu-remake` on 2026-09-05. Its copies of
shared files are ordinary tested/shipped files here; the other repository is
maintained independently. `tools/content_suite/apps/event_player.gd` belongs
only here. Specifications produced here live under `docs/spec/`, indexed by
`docs/spec/index.md`; the playback package schema and split plan remain
cross-repository references.

## Domain Trackers

0. **Code Health and Split Integrity:** [todo/code_health.md](todo/code_health.md)
1. **MES Analyzer and Decompiler, Phases 1-5:**
   [todo/mes_analyzer.md](todo/mes_analyzer.md)
2. **MES Compiler and Authoring, Phases 6-7:**
   [todo/mes_authoring.md](todo/mes_authoring.md)
3. **Event Player, Phase 7 consumer:**
   [todo/event_player.md](todo/event_player.md)
4. **Presentation and Audio:**
   [todo/presentation_audio.md](todo/presentation_audio.md) — the one tracker
   whose ownership straddles the repository split; see its header.
5. **Media Editors:** [todo/media_editors.md](todo/media_editors.md)
6. **Workspace and Distribution:**
   [todo/workspace_distribution.md](todo/workspace_distribution.md)
7. **Manual Verification:**
   [todo/manual_verification.md](todo/manual_verification.md)

## Tracker Rules

- Work priorities follow **Execution Order** above. Validation trust defects
  precede feature closure; otherwise complete the approved edited-content flow
  before broad feature expansion or unrelated refactoring. The phase roadmap
  owns capability gates; explicit user requests and bounded prerequisites can
  change the next work unit.
- The phase roadmap owns maturity definitions and order, but no live
  checkboxes. Domain trackers remain the single owners of implementation work.
- Use `[ ]` for open work and `[x]` only after implementation, proportionate
  verification, related specification updates, and a coherent commit exist.
- `IN PROGRESS` may appear on at most one live primary item across `todo/*.md`.
- A work item and its checkbox have one live owner. Other trackers link to that
  owner as a dependency instead of repeating its progress history.
- Keep long investigation chronology out of live trackers. Record reproducible
  technical evidence in the specifications, concise work status in the owning
  tracker, and completed implementation in Git commits.
- `todo/code_health.md` owns defects and structural debt, not capability. A
  finding there that turns out to be a missing feature moves to the owning
  domain tracker.
- GUI and original-engine checks accumulate in `todo/manual_verification.md`.
  Routine validation remains headless and non-focus-stealing.
- Original data, extracted payloads, dialogue, and machine-specific paths never
  belong in tracked TODO files.

## Boundary With `kakyu-remake`

- The load-bearing invariant is that **the remake never reads an original ARC or
  MES entry.** Everything it plays arrives through the playback package. The
  remake enforces this structurally: the code to read an original entry is
  absent there.
- This repository produces that package. `tools/content_suite/cli/export_playback_package.gd`
  builds one for all twelve catalog events and
  `validate_playback_package_playback.gd` plays every one of them against the
  bytecode reference. Recorded before the split and not re-measured here: 7.43 MB
  and 27,262 records over sixteen entries, matching the bytecode reference on 371
  segments, 5,261 trace rows, 488 message payloads, final state and terminal;
  eleven of the twelve reach a catalog-declared terminal and `EVENTD06` stops
  identically on both sides at a definition invoke boundary.
- This producer now emits `kakyu_playback_package/v7`: v4 binds every manifest
  field and packaged file; v5 preserves omitted inert marker boundaries;
  v6/v7 carry authored state/message edits and mapped control points. The
  separately maintained remake contract remains at its declared version; this
  repository makes no claim that an older consumer accepts v7. Versions are
  checked fail-closed, and
  both sides check schema version and package hash fail-closed, so an
  incompatible package is rejected rather than silently misread. A schema change
  therefore needs a version bump, not an in-place edit.
- The split sequence, its gates, and the reasoning behind the copy-based
  partition are recorded in `kakyu-remake/docs/spec/tech/modtools_split_plan.md`.
  That is the remake's history of its own transformation and is not duplicated
  here.
- Shared conventions are owned here and read from here. By the owner's
  decision of 2026-09-16, a JSON contract the remake consumes - today the
  event-definition fixture set and the event name registry under
  `config/contracts/`, each fingerprinted - is changed only in this
  repository, as a new directory beside the old, never in place; the remake
  reads the current set from this repository, and how it reads it is its own
  arrangement. The copies it received on 2026-09-15 are its own files; the
  agreement is the pair of fingerprints both trackers record. The registry's
  first revision landed 2026-09-19 (owner's choice 1: `names_fingerprint`
  `7721269a1613e1b37220a4879de387f65bf6d12969c4a5b220e3b2919d828b75`, the same 142 ids, one row's group alias; and again on 2026-09-21, `dbad4b00f9e9725b29a5f84e6b7de576d30a5ae373f007801aad27cd09d9df63`, ten more group aliases, EP-10 unit 5a; and again the same day, `4a04c35a1897b968cd7d9357b316be282516acf3eea9a8cadf461fcc8c1cc66a`, every row's catalog-event alias, EP-10 unit 5b/c part 2); v3 keeps validating
  against the pair it recorded, v4 carries the new value. The projected
  event definitions under `config/event_definitions/v3/` are read the same
  way (decision A, 2026-09-16); they reference dialogue and never embed it.

## Legacy Crosswalk

| Former roadmap area | Live owner |
|---|---|
| P0-04 and MES-analysis parts of P2-04..P2-08 | `todo/mes_analyzer.md` |
| P0-02/03, P2 playback, choices, terminals, P2-10 | `todo/event_player.md` |
| P3 | `todo/presentation_audio.md` |
| P4 | `todo/mes_authoring.md` |
| P5 and P6 | `todo/media_editors.md` |
| P1, P7, P8, P9 | `todo/workspace_distribution.md` |
| Manual Verification Queue | `todo/manual_verification.md` |

The frozen former tracker, including the full P2-05 investigation chronology, is
retained in the remake at `todo/archive/legacy_todo_2026-08-30.md`.
