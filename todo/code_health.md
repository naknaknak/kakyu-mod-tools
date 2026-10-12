# Code Health and Split Integrity TODO

This tracker owns repository-level defects, structural debt, and the integrity
of the 2026-09-05 split from `kakyu-remake`. It is the **first** tracker in the
navigation order because its items decide whether the official validation batch
can run and be believed — TD-00 restored it and TD-14 established the
`--elfimage` group's state — and because the rest records a SOLID review whose
measurements would otherwise have to be redone.

It does not own feature work. An item here is a defect, a missing repository
mechanism, or a structural violation with a named cost. Product capability
stays in the domain trackers listed in [TODO.md](../TODO.md).

## Current authoring verification scope

Core 0.309.0 fixes a route-probe control-flow defect found while extending event
analysis: a child script handoff previously returned success without signalling
root replacement, so pending caller suffixes ran and could overwrite its
terminal. Handoffs now propagate through all script-call frames. Six synthetic
checks cover direct/transitive replacement, omitted suffix/target execution and
ordinary nested returns. Existing H17/K09 returning callees are unaffected.

Core 0.308.0 fixes routine-40 contract revalidation after JSON transport:
nested integer fields become whole floats and previously compared unequal to
rebuilt definition dictionaries. Validation now uses the existing canonical
JSON helper; synthetic round-trip and fractional-coordinate rejection checks
pass. The V3 contract meaning and source-bound rejection policy are unchanged.
EP-07/EP-05 own the GROUND continuation capability and its regression scope.

Core 0.306.0 Windows delivery passes five Python packaging regressions and
five focused parse/launcher/runtime/state/message checks in 8.436 s
(`analysis/windows-release-entry-validation.json`). The runtime test also
passes after extending it to all six companion EXE mappings. All six real
release applications pass default-scene/resource/bundled-Python audits twice,
including from another working directory after publication with host Python
removed from PATH. File inventory and ZIP CRC verification pass. WD-13/14 own
the capability and remaining delivery limits; no full corpus or GUI claim is
added by these focused checks.

Core 0.305.0 route qualification runs all 99 local checks: 98 pass initially
(1,321 Python tests), with the remaining Event Player scene failing only its
three old twelve-entry assertions. Those are corrected to thirteen and pass
in `analysis/j04-final-ui-validation-r2.json`: five final checks in 140.158 s,
including 90 original J04 assertions and all ten existing ordinary Play routes.
`analysis/j04-original-package-validation.json` passes four checks in 43.806 s,
including 82 package-equivalence assertions across all 13 catalog seeds.
The classification generator rechecks all 10,474 source dispatches. These
focused checks do not replace the earlier full original/native batch.

Core 0.304.0 message-authoring work passes 98/98 local checks in 171.505 seconds,
including 1,316 Python tests. `analysis/message-authoring-final-validation.json`
records six passing parse/synthetic/original-event/package checks (240.993 s);
`analysis/message-authoring-final-ui-validation.json` records five final checks
(9.544 s), including changed-draft rejection and default Analysis translation
mapping. These do not replace the earlier 188-check original/native baseline.
The capability and remaining work stay in MW-11, EP-04, WD-10 and WD-21.

## Measurement Baseline

Everything below was measured on 2026-09-05 in this repository, at commit
`9275d12`. Re-measure before closing an item; do not trust these numbers after
the code changes.

| Property | Value |
|---|---|
| GDScript | 118,625 lines, 334 files |
| Python | 127,204 lines, 216 files |
| Godot test scenes | **90 of 90 pass** |
| Python regression | 997 tests, **1 failure**, and only with `--jobs 8` |
| `content_core` references into `tools/` | **0** |
| `tools/` references into `content_core` | 513 |
| Broken `res://` paths | **0** |

The two clean results are load-bearing and worth keeping that way: the domain
core does not know about the applications, and no scene or script path was
broken by the split.

After TD-00's two defects, TD-01, TD-02 and TD-03 were closed on 2026-09-05:
**91 of 91 Godot scenes pass** — 90 plus the new code-source contract scene —
and the Python regression passes **1,007 tests at its default job count**, with
no `--jobs` override and no remaining failure.

52 source files also exist in `kakyu-remake` because the split copied rather
than moved what both sides needed — 26 in `content_core`, 10 test scenes, 16
under `config/`. They were byte-identical on 2026-09-05. This is recorded as
context, not as work: the copies here are the ones this repository tests and
ships, and the sibling repository is maintained separately.

## Open Work

**Batch speed order (owner ruling, 2026-10-08).** Measured on the WD-21 U1 closing batch
(`analysis/_undoc/wd21_u1/closing.json`, run `7513c6ad`): 5,254 s wall, 24,788 check-seconds at
`--jobs 6` (efficiency 0.79). The 20 group-route shards take **15,328 s, 62%** of the check-seconds
(681 rows, ~22.5 s per row). Next come the transfer-direction corpus (1,004 s), the analyzer handoff
corpus (997 s), package playback (745 s), the full handoff equivalence (582 s) and the four
contextual-authoring checks (~1,030 s together). The 327 checks under 10 s sum to 723 s (3%). The
batch's floor is the analysis-group process, 227 members in one Godot process (3,691 s). Random
sampling was considered and rejected for closing proofs: the claims are per row, and a 10% sample
misses a one-row defect about 90% of the time and a ten-row defect about 35% of the time. Most
defects found so far sat on rare paths. The owner set this order, right after WD-21 U2 (where U3
falls relative to it is not ruled):
measure TD-57's batch share (below), then **TD-57**, **TD-58**, **TD-47** (the design of
2026-10-08), **TD-59** (iteration only), **TD-60**; **TD-61** is decided after those. Closing
proofs stay exhaustive. *2026-10-09: the measurement is done (TD-57). Hashing was 91.9% of a
group-route shard; with a memo the shard took 65.6 s instead of 797.7 s.* *2026-10-09, later: TD-57
closed. The batch went from 4,770 s to 3,226 s wall and from 21,975 to 10,007 check-seconds (the shards
from 13,473 to 1,394 s). The floor is now the analysis-group process (3,193 s, 99% of the wall time), so
TD-58 is next. TD-47 and TD-59 lost their premise (see each).* *2026-10-09, evening, owner ruling: TD-58
proceeds. The other speed items - TD-47, TD-59, TD-60 and TD-63 - leave this order. Each is taken up only
when the batch's speed gets in the way of the work at hand. TD-61 stays deferred. (U3 no longer
competes: the owner withdrew it the same evening, `todo/workspace_distribution.md` WD-21.)*
*2026-10-10: TD-58 is closed and TD-64 part 1 is closed, both by one uncached whole batch: 477 of 477 in
3,364.4 s and 10,727 check-seconds (run `d2144d74`; TD-57: 3,225.7 s, 10,007). The wall time is not below
TD-58's ~2,300 s model: the exclusive package playback check runs ~560 s alone at the tail (TD-64), and the
worker gate has no reservation (TD-65). Owner rulings of the same day: TD-64 part 2 right after TD-58, and
the gate fix rides with part 2's uncached batch. The next speed work is therefore TD-64 part 2 with TD-65.*
*2026-10-10, later: TD-64 part 2 and TD-65 are closed, both by one uncached whole batch: 477 of 477 in
2,452.2 s and 10,874.6 check-seconds (run `72b516cc`), against 3,364.4 s for TD-58's batch and TD-57's 3,225.7 s.
The batch is below TD-57's wall time. TD-58's ~2,300 s was a model on TD-57-era shard estimates; the measured
shards (1,802 and 1,822 s here) put the floor higher, as TD-64 part 2's spec said. The remaining speed items
(TD-47, TD-59, TD-60, TD-63) stay on demand by the owner's ruling of 2026-10-09, and TD-61 stays deferred.*
*2026-10-11: TD-56 is closed by one uncached whole batch: 477 of 477 in 2,742.9 s and 10,277.9 check-seconds (run `bcd678df`),
against TD-64 part 2's 2,452.2 s and 10,874.6. The 290.7 s rise is not a slower check (the check-seconds fell by 596.7): it is the
worker gate's idling trade firing once on an ordering tie, three slots idle for 839 s (TD-67, new). TD-60's `--jobs 6` question is
answered (the projector's maximum on this machine is 4). The remaining speed items (TD-47, TD-59, TD-60, TD-63) stay on demand,
TD-61 stays deferred, and TD-67 rides with the next unit's uncached batch.*
*2026-10-11, later: TD-67 is closed, with WD-10, by one uncached whole batch: 479 of 479 in 2,546.4 s and 10,715.5 check-seconds
(run `e6cb6108`), 196.5 s under TD-56's 2,742.9 s. The ordering rule keeps the multi-slot checks back to back: the Python suite
started at +583 s, within a second of the full handoff equivalence's end (+1,426 s in TD-56's batch). The wall time is 46 s above
the unit's 2,500 s because the new archive check had no cache entry and ran nearly alone at the tail, not because of the gate.
The remaining speed items (TD-47, TD-59, TD-60, TD-63) stay on demand, and TD-61 stays deferred.*

- [x] **TD-65 - The worker gate has no reservation, so a weight-4 check waits until the queue drains.**
  **Closed 2026-10-10** (Core 0.376.0 by TD-64 part 2; the closing record is the last bullet below). Found 2026-10-10 by the TD-58/TD-64 closing batch (run `d2144d74`, `analysis/_undoc/td58/closing2.json`,
  sampler `closing2_mem.csv` + `_procs.csv`). The batch was expected at 2,760-2,825 s (TD-64 spec; TD-58's
  own model said ~2,300 s) and took 3,364.4 s, past TD-64 spec D6's ~3,000 s stop.
  - **The mechanism.** `_WorkerGate.acquire` (`tools/content_suite/run_headless_validation.py`, class
    `_WorkerGate`) holds no reservation. A worker that needs four slots waits on the gate's condition, and
    every waiter wakes on `notify_all`; whichever fits first takes the slots. When the full handoff
    equivalence freed its 4 slots at ~711 s, single-slot waiters took them. The Python regression suite
    (weight 4) started only at +2,545 s, when the queue had drained, and ran 247.4 s. About one worker of six
    sat idle for ~1,800 s while the suite's worker was parked.
  - **Why the models missed it.** TD-58 C0's scheduler model assumed first-fit among the waiters in queue
    order, which the gate does not do. TD-58 D9's ordering (duration x slots) is right, but it cannot take
    effect without a reservation.
  - **Fix.** A reservation, FIFO by the scheduler's order: while the head waiter cannot fit, later waiters
    do not take slots. With a test that a multi-slot waiter ahead of single-slot waiters gets the freed
    slots first.
  - **Expected effect** (an estimate, not measured): back toward the ~2,300 s model, together with part 2,
    which lifts the playback check's exclusivity.
  - **By owner ruling of 2026-10-10 it lands with TD-64 part 2's uncached batch**, not in a batch of its own.
  - **2026-10-10, closing record** (spec `analysis/_docs/td64_p2_spec.md`, v2, D4 and D5; C3 `f75ef9da`; closed
    together with TD-64 part 2 by one batch, whose full record is under TD-64 below). The advisor accepted C3
    with no change.
    - **The fix.** `_WorkerGate.acquire` serves waiters strictly in arrival order. A waiter takes its slots only
      when every earlier waiter has been served and enough slots are free for it. At a release the head waiter is
      served if it fits, and nobody is otherwise, so a later waiter never takes slots while an earlier one waits.
      Arrival follows D9's order, because the worker threads pop that queue. Slot-id handout and `release()` are
      unchanged.
    - **The idling trade is a stated cost, not a defect.** A weight-4 head that cannot fit idles the slots it
      cannot use, up to three of six, and a single-slot waiter behind it does not take one. An exclusive head
      drains the machine, so no later waiter starts until it has run. D9's order bounds the cost: the weight-4
      checks head the queue early, while the two shards hold two slots and few single-slot checks run beside them,
      and the exclusive checks sort last. *2026-10-11: the bound failed once, on an ordering tie, in TD-56's closing batch (TD-67); TD-67's ordering rule, closed the same day, restores it.*
    - **Exception safety.** A ticket leaves the queue in a `finally`, so a waiter that dies in `wait()` cannot
      block the waiters behind it. A test pins it.
    - **`original playback package playback` lost `"exclusive": true`** in the same commit (D5; no registry
      revision bump), once the lazy reader and the streaming exporter took its working set to about 2.0 GB. No
      registry entry sets the per-entry `exclusive` boolean now, so the field has no user. It stays in the
      vocabulary, and the family entry's `exclusive_scenes` still marks three scenes, which sort last.
    - **Tests.** Scheduler 41, of which `WorkerGateFifoTests` are 7 (a head before later singles, the idling
      trade, an exclusive head drains, arrival order, no starvation, a mixed 60-waiter load, an abandoned
      ticket); 5 of those 7 fail against a first-fit gate. They drive the gate with a counting `Condition` and
      no sleeps. Registry 46 (the playback check is pinned not exclusive), runner 77, local tier 140 of 140. The
      D9 ordering tests are unchanged.
    - **The proof is the process census of the closing batch.** The Python regression suite started at **+616 s,
      the moment the full handoff equivalence freed its four slots** (+8 s start, 608.0 s), against +2,545 s in
      the TD-58 batch. `original playback package playback` started at +869 s beside the two corpora, not
      exclusive, and the export at +1,231 s. The whole batch took 2,452.2 s against 3,364.4 s.
    - **The decomposition, labelled** (`analysis/_undoc/td64p2/predict_c3.py` over `sim.py`, untracked; part 1's
      durations, the shards as units, playback at C2's solo 548.6 s, wall including the 37 s start-up part 1
      showed):

      | Gate | Playback | Wall |
      |---|---|---|
      | Old | exclusive | 3,364 s |
      | Old | not exclusive | 2,914 s |
      | FIFO | exclusive | 2,965 s |
      | FIFO | not exclusive | 2,508 s |

      **The two old-gate rows are a post-hoc replay under an assumption**, not a measurement: the old gate's
      `notify_all` lets whichever woken waiter reaches the lock first take the slots, and the model's
      `self_first` scan (a thread that has just popped its next check and fits takes its slots before any waiter
      that still has to wake) is the one that reproduces part 1's 3,364 s and its suite start at +2,545 s. An
      arrival-order wake would give 2,976 s, a newest-first wake 3,535 s. **The FIFO rows are the prediction**
      the closing batch was measured against, and it came in at 2,452.2 s (TD-64 below). In the model, either
      change alone recovers about half of the gap and the two together about 856 s of the model's 3,364.
    - **Left open:** nothing; the gate has no remaining item.

- [x] **TD-64 - `original playback package playback` alone fills the machine's memory.**
  **Closed 2026-10-10** (part 1 by Core 0.375.0 and part 2 by Core 0.376.0; the closing records are the
  "Part 1 closed" bullet and the last bullet below). Found 2026-10-10 by TD-58's closing batch
  (`analysis/_undoc/td58/closing_mem.csv`, sampler at 10 s).
  - **The aborted batch.** It started from an idle of 43.2%. About 600 s in, the check started beside
    the two analysis-group shards and the two corpora. Its Godot process reached 9.1 GB private memory
    and was still growing. System RAM reached 96-99% with heavy page-ins, and the commit charge passed
    90% of its limit. The batch was stopped at about 1,000 s, before commit exhaustion.
  - **Solo, it fails the same way** (`--check` alone, `--jobs 1`; `playback_solo.json`,
    `playback_solo_mem.csv` at 5 s).
    - It **passed in 555.7 s**.
    - From an idle of 30.7%, its working set grew about **1.6 GB a minute, linearly**, to **10.6 GB**.
    - RAM peaked at **97.6%**, and the commit charge at 84% of its limit.
  - The linear growth points to state that accumulates per event. `_compare_all()`
    (`tools/content_suite/cli/validate_playback_package_playback.gd:214`) keeps only small row
    summaries, and every per-event object is `RefCounted`. So the suspects are:
    - reference cycles among the probe, runner and state objects, which `RefCounted` never frees;
    - caches inside the two run contexts that grow with every entry touched.

    Diagnosed the same day (see "Part 1 closed" below).
  - **Why it matters now.** No whole batch on this 16 GB machine can stay under TD-58's 90% guard
    while this check runs: it passes 90% on its own. A peak beside other checks risks commit
    exhaustion, which would fail checks or crash other applications. The TD-57 batch passed with it
    unsampled.
  - **AGENTS.md routing:** a defect that stops the batch precedes feature work. TD-58's closing batch
    waits for this fix, and then one uncached batch closes both.
  - **Part 1 closed 2026-10-10** (spec `analysis/_docs/td64_p1_spec.md`; the advisor's rulings D1-D5; owner
    ruling: part 1 now). Core 0.375.0.
    - **The diagnosis** (not a leak: `OBJECT_COUNT` stayed flat):
      - *Double residency.* `tools/content_suite/cli/validate_playback_package_playback.gd` held `built`,
        `serialized` and `written`, then the loaded package, all at once. `write()` reopens the staged
        package (`playback_package_export.gd:765`) while the first two are alive; that reopen is the 10.6 GB
        peak.
      - *One CP932 codec per entry.* `playback_package_code_source.gd:34` created a codec for each of the
        869 packaged entries, and each built a 0.88 MB `_encode_map` on its first `encode()`, about 0.76 GB.
      - The probe `analysis/_undoc/td64/probe.gd` emulated both fixes: it passed in 525 s, its 683 EVENT,
        SUMMARY and PASS lines md5-identical to the solo baseline, working set 8,856 MB, RAM 83.0% from a
        ~31% idle, commit 66.7%.
    - **C1 `6486646d`.**
      - D1: build, serialize and write moved into a helper in the validator that returns only
        `{package_sha256, event_count}`; `built` is emptied right after `serialize()`. Every `_check` call and
        printed line is unchanged.
      - D2: `KakyuPlaybackPackageCodeSource._init(document, strings, codec)` takes the codec by injection,
        and `playback_package.gd` passes one codec per package (no `static var`: a static field would share
        `last_error` across 869 sources). The `codec = null` default (a fresh codec) is kept for the
        two-argument caller in `tests/test_mes_code_source.gd`. That is a tool decision; part 2 may make the
        codec required.
      - Tests: one package's sources share one codec, two packages do not, and a shared codec encodes the same
        bytes as a fresh one.
    - **C2, solo, no commit** (`analysis/_undoc/td64/c2_*`): PASS in **560.4 s**. The 682 EVENT and SUMMARY
      lines are identical to `baseline_solo.verdict.txt`; the PASS line differs only in its Core string
      (md5 `8c1ce42c...` once that is mapped back). Working set peaked at 8,788 MB, RAM at 92.1% from a ~44.6%
      first sample, commit at 71.8% of the 31,157 MB limit (about 22.4 GB used).
    - **C3 `ef429f5f`.** `"exclusive": true` on `original playback package playback` (no registry revision
      bump) and `_order_checks_for_run()` sorts exclusive checks after every non-exclusive one, longest first
      among them (TD-58 D9 amended). The three exclusive scenes (1.4-9.5 s) also sort last.
    - **C4 `d367b5bd`.** The Core 0.375.0 binding export `analysis/playback_package_td64/`, package
      `ede69366cca16ba85eec73fc0fa918521543c4809d46339c26c2d6627eb72a16`. Its manifest differs from
      `analysis/playback_package_td57/` in `package_sha256` and `content_core_version` only, and the other
      1,738 files are byte-identical. The v7 set was rebound with `--pair core-version`: 681 valid.
    - **In the closing batch** (run `d2144d74`, below TD-58): the check ran **alone and last, 2,802-3,364 s
      (559.9 s)**, with a RAM peak of **94.3%** and a commit peak of **73.0%**. It is safe alone, but it is not
      under 90% RAM: the loop itself holds ~8.8 GB (the 319 MB package becomes about 5.9 GB of Variants), and
      at the batch's idle it fits only alone. The commit charge never reached TD-58 D5(b)'s ~85%. The export
      check's window (1,074-1,420 s) peaked at 89.6% RAM and 71.1% commit.
  - **Part 2, by owner ruling of 2026-10-10 (right after TD-58); closed the same day, the record is the last
    bullet below.** A Core design unit with its own spec:
    - a lighter `KakyuPlaybackPackage`: hash every file at load, parse the entries on demand (StringName key
      interning measured 0.69x in `analysis/_undoc/td64/json_bench.gd`);
    - the export CLI's `--out` double residency: `tools/content_suite/cli/export_playback_package.gd` keeps
      `built` and `serialized` through `write()`. C4's export peaked at RAM 97.9%, commit 90.5%, working set
      8,678 MB (`analysis/_undoc/td64/c4_export_mem.csv`); the batch's export check runs without `--out` and
      is unaffected;
    - the codec-required option (D2 above);
    - lifting the playback check's exclusivity, and with it TD-65's gate reservation, in one uncached batch.
  - **Part 2 closed 2026-10-10** (spec `analysis/_docs/td64_p2_spec.md`, v2, after the advisor's design
    pre-review, which returned "proceed with corrections" and whose ten corrections v2 folded in; owner rulings:
    part 2 right after TD-58, "close now, fix the gate together next" for TD-65, and the owner's go-ahead on
    2026-10-10). Core 0.376.0 (0.375.0 before). Four commits: C1 `d4ee0990`, C2 `10013ddc`, C3 `f75ef9da`
    (TD-65, recorded under TD-65 above) and C4 `1daa69ee`. The advisor accepted C1, C2 and C3 with no change.
    - **C1 `d4ee0990`: the lazy reader (D1, D2).** `KakyuPlaybackPackage.load_directory()` held the whole package
      as parsed documents, about 5.5 GB for the 869 entries, 18.6 times their 296 MB on disk.
      - *One streaming pass* over the manifest's entries. Per entry it reads both files, checks size and SHA-256
        against the manifest and **keeps the verified bytes**; parses transiently and runs `document_error`;
        builds the code source transiently; feeds the inventory accumulator; records `code_size`,
        `address_table`, the entry fingerprint and role; and lets the parse go. The event and terminal
        coordinate checks read the recorded metadata. The candidate swaps in only after the whole pass, so a
        failed reload still leaves the last verified snapshot, its code sources and its cache untouched. The
        reader never reads a file after the load, so a file rewritten on disk afterwards cannot alter a decode.
      - *The reader's shape.* The retained bytes are about 300 MB and replace the Variants. The manifest stays
        resident, about 233 MiB parsed (`manifest()` and `events()` return deep copies), so the resident floor
        is about 0.55 GB plus the cache. `code_source(entry)` returns one lazy shell per entry for the life of a
        snapshot (`content_core/playback_package_lazy_code_source.gd`, a subclass of the eager source, which is
        unchanged: its two-argument constructor and the shared codec stay). A shell answers `entry`, `size` and
        `address_table` from the metadata and parses from the kept bytes, through the snapshot's cache of parsed
        sources (`content_core/playback_package_source_store.gd`), on the first call that needs records.
      - **`DEFAULT_SOURCE_CACHE` is 32, a tool decision**, with a floor of 1; `source_cache_limit` sets it and
        `source_cache_stats()` reports limit, resident, parses, evictions and bytes. The per-event maximum, 15,
        is a performance floor, not a safety one: the 32 largest entries parse to about 0.54 GB, and the
        prototype's 16 and 64 gave 1.4 and 1.9 GB of working set. A shell fetches its parsed source once per
        call and never holds it, and no source calls another or the package, so eviction is safe at any limit
        of 1 or more. The bytes and the cache belong to the snapshot, reference no shell and swap with it.
      - *The transient source build costs about +15 s per load.* It is kept so that a document the source cannot
        index still fails the load, as before, instead of surfacing in mid-playback.
      - **The two-fault error order.** A file that fails now fails at its own entry instead of in a separate
        whole-file pass, so a package with two faults reports the one that comes first in entry order. Every
        single-fault message is unchanged.
      - **The inventory accumulator.** `KakyuPlaybackPackageInventory` gains `begin(entries)`, then
        `add(entry, document, strings)` per member and `finish()`, which sorts the members and requires every
        declared entry to have been fed. `inventory_error()` and `build_blocks()` are thin wrappers over it with
        the same messages, so `tests/test_playback_media_inventory.gd` kept its assertions.
        `accumulated_error(manifest, expected)` runs the checks over a finished accumulation, and
        `carries_blocks(manifest)` and `manifest_entries(manifest)` are the shared helpers. The load feeds the
        accumulator in the same pass that runs `document_error`: one parse per entry, not two.
      - *Tests.* `tests/test_playback_package.gd` went from 109 to 210 checks, no existing assertion changed: a
        source's first use parses and its second does not; with a cache of 2 a third source evicts the oldest
        and the re-parse decodes byte-identically; identity across eviction; a cache of 1 with two sources used
        alternately; a package file rewritten after the load changes nothing; every shell answer and
        `code_size`, `address_table`, `library_index`, `container_document` and `text_strings` equal a source
        built from the same documents; a failed reload leaves the cache, the shells and the manifest.
      - *Notes.* `text_strings()` re-parses per call; its only caller is a test. The "Parse JSON failed" print
        from `event_player.gd:1700` on the authoring-workflow refusal path is pre-existing engine noise.
      - **The solo run** (`analysis/_undoc/td64p2/c1_*`; the lazy reader with the still-eager exporter, so that
        a regression in C2 is attributable to D3 alone): `original playback package playback` **passed in
        545.5 s** with 4,749 checks, its EVENT and SUMMARY lines and its PASS line (once the Core string is
        mapped back) identical to the part-1 baseline. Idle was 37.9% RAM and 38.5% commit; the peaks were 80.3%
        RAM and 61.0% commit. The working set peaked at 7.1 GB in the exporter, ran 0.85-1.0 GB through the
        load and 1.8-2.0 GB through the compare loop.
    - **C2 `10013ddc`: the streaming exporter (D3).** `build()` held every member's events and text documents
      until `serialize()`, about 3.8 GB of its 4.0-4.9 GB of static memory.
      - *The streaming build result.* Each member is serialized as it is built (`_payload()`: the JSON bytes,
        size and SHA-256), fed to the media-identity and inventory accumulators, and dropped with the loop's
        next turn. `built` now holds `payloads[entry] = {events, text}` and `inventory_evidence` beside
        `media_identity` and `media_scan`, **and no `documents` or `texts`**. `serialize()` consumes only
        those, in the order the build made them, with shallow copies, and refuses a build result with no
        payloads, a malformed or unserializable payload, no evidence or evidence that does not cover exactly
        the members its `entry_reports` name. There is one production path and no eager fallback.
      - *The accumulators and wrappers.* `KakyuPlaybackMediaIdentity.begin(source_root)` returns an
        accumulator fed per entry (`collect()` is its wrapper; the rows and failures join in entry order, so
        any feed order gives what `collect()` always gave). `KakyuPlaybackPackageInventory.build_blocks_from(
        expected, identity, scan)` is what `build_blocks()` now wraps, with the same messages in the same
        order. The exporter's `payloads_for(documents, texts)` runs the same per-entry function for a build
        result that did not come from `build()`: it is the fixture path of `tests/test_playback_package.gd` and
        `tests/test_playback_media_inventory.gd`, and **no fail-closed assertion changed**. New checks: the
        package scene 210 to 229 (payload bytes, size, SHA-256 and file order, the copy semantics, nine
        refusals of a streamed build result), the inventory scene 206 to 210 (the media-identity accumulator
        against `collect()` in three feed orders, for a clean scan and for two strict misses).
      - *Left alone:* `integrity.bind` and `fingerprint` still deep-copy the 233 MiB manifest, because
        erase-and-restore would move a manifest key (D3 made it conditional on a local change and low
        priority).
      - **Byte-identity, checked by the advisor itself.** `analysis/playback_package_td64p2/` (`47b1ee8d...`)
        against `analysis/playback_package_td64/`: the 1,738 non-manifest files (316,254,550 bytes) are
        byte-identical; `manifest.json` has the same size and key order and differs only in
        `/content_core_version` and `/package_sha256`; every one of the 1,738 file records in it matches its
        file. The export's printed lines differ only in the hash, the output path and the Core string.
      - **The export CLI's `--out` residency is closed by this commit, as a consequence.** Part 2's bullet
        above listed it as a separate item. `cli/export_playback_package.gd` calls `build()` and then
        `serialize()`, both stream now, and it never read `built.documents` or `built.texts` afterwards, so no
        CLI change was needed.
      - **Memory** (`analysis/_undoc/td64p2/c2_*`, sampler at 5 s; the idle probe read 37.9-38.1% RAM, the first
        sampled rows 40.7% and 40.9%):

        | | Working set | RAM peak | Commit peak | Duration |
        |---|---|---|---|---|
        | Export, now | 1,614 MB | 47.8% | 43.3% | 5 min 59 s |
        | Export, part 1 | 8,678 MB | 97.9% | 90.5% | |
        | Solo playback, now | 2,016 MB | 62.9% | 53.0% | 548.6 s |
        | Solo playback, after C1 | 7,124 MB | 80.3% | 61.0% | 545.5 s |
        | Solo playback, part 1 | 8,788 MB | 92.1% | 71.8% | 560.4 s |

        The solo playback check passed with 4,749 checks, its EVENT and SUMMARY lines (md5
        `1ac85feb4840d652835e7613b0712bef`) identical to `analysis/_undoc/td64/baseline_solo.verdict.txt` and
        its PASS line identical once the Core string is mapped back.
      - **The contextual-authoring durations.** C2's run of the two checks that publish a workspace export took
        335.8 s (edited event) and 356.7 s (relocated message), against 216.4 and 239.3 s in C1. The advisor
        asked for a solo re-run on an idle machine before the batch: `original relocated message contextual
        authoring` alone took **233.3 s** (`analysis/_undoc/td64p2/c4_contextual_solo.json`), against C1's 239.3
        s. **The slowdown was machine state, not a cost of C2.** In the closing batch the four contextual checks
        took 263.1 s (relocated), 276.9 s (edited), 274.3 s (resource) and 362.8 s (sequence, 0.30 of its
        1,200 s).
    - **C3 `f75ef9da`: the gate and the registry** (D4, D5), recorded under TD-65 above.
    - **C4 `1daa69ee`: the binding export and the rebind (D6).** The Core 0.376.0 export
      `analysis/playback_package_td64p2/` (machine-local, produced at `10013ddc`: C3 touches neither the Core
      nor the exporter, so it was not repeated), package
      `47b1ee8de1d91558a428a11fb3e3a1f6f5acd8a5775212ff76c1c49a3d9324cd`, was `ede69366...`. The v7 set was
      rebound with `tools/rebind_event_definitions.py --pair core-version` (dry run first): **681 valid**
      against the new package and 0 against part 1's (every document refused on the binding).
    - **The closing batch** (`analysis/_undoc/td64p2/closing.json`). The whole `full` tier, uncached with
      `--cache-store` (the Core, the runner and the registry changed), `--jobs 6`, `--elfimage --exe --godot`,
      detached, solo, on the committed tree `1daa69ee` (Core 0.376.0), the sampler at 10 s. Idle, the sampler's
      first rows: 42.7% RAM and 42.4% commit (Discord open), inside the ~50% guard. **477 checks, 477 passed,
      0 failed, 2,452.2 s** (run `72b516cc`, `cached: 0`) and **10,874.6 check-seconds**. TD-58's batch took
      3,364.4 s and 10,727 check-seconds; TD-57's 3,225.7 s and 10,007.
      - *The shards.* `shard plan: 1/2, 114 member(s), 1223.035s known, 0 unknown` and
        `process: original event analysis groups [1/2] completed in 1822.391s (114 member(s), timeout 8000s)`;
        `shard plan: 2/2, 113 member(s), 1222.510s known, 0 unknown` and `... [2/2] completed in 1802.125s (113
        member(s), ...)`. 0.23 of the 8,000 s timeout; the members' own durations sum 2,479.8 s.
      - *The weight-4 and the memory-heavy checks* (process creation minus the runner's 10:54:50):

        | Check | Start | Duration |
        |---|---|---|
        | The two shards | +8 s | 1,822.4 s and 1,802.1 s |
        | The full handoff equivalence (weight 4) | +8 s, in the first wave as D9 orders it | 608.0 s |
        | **The Python regression suite (weight 4)** | **+616 s**, the moment the equivalence freed its slots | 252.7 s |
        | `original playback package playback` (not exclusive) | +869 s, beside the transfer-direction and analyzer handoff corpora | 619.8 s |
        | `original playback package export` | +1,231 s | 334.0 s |

        The suite started at +616 s against +2,545 s in the TD-58 batch (TD-65's proof). The 20 group-route
        shards took 1,444 s in all (66.1-85.8 s each). The playback check ran 71 s longer than solo (548.6 s)
        beside other work; the model's own sensitivity run at 640 s moved its wall by about 15 s.
      - *Memory,* by window (RAM peak / commit peak):

        | Window | RAM | Commit |
        |---|---|---|
        | pre-pass + equivalence, 0-711 s (the batch's peak) | 72.0% | 56.9% |
        | 711-1,000 s | 53.6% | 47.4% |
        | 1,000-1,900 s (shard loops, corpora, playback, export) | 64.8% | 53.3% |
        | the tail | 65.8% | 53.8% |

        **0 sample rows with page-ins over 1,000/s** (TD-58's batch: 14 of 395). The stop conditions (RAM above
        90%, commit above ~85%, sustained page-ins) never came near. The expected 70-75% RAM in the +958 to
        +1,666 s window was an upper estimate; the measured window peaked at 64.8%. The batch's own peak, 72.0%,
        came in the pre-pass window, which is TD-58's phase, not the playback window. For comparison the TD-58
        batch's playback window alone reached 94.3% RAM and 73.0% commit.
      - *The highest timeout ratios:* the transfer-direction corpus 945.5 s of 2,400 (0.39), the export 334.0 s of
        900 (0.37), playback 619.8 s of 1,800 (0.34), `original Audio Editor original integration` 96.4 s of 300
        (0.32), the analyzer handoff corpus 937.2 s of 3,000 (0.31); the two shards 0.23 of 8,000. **None passed
        0.5.**
      - **The wall time against the model.** The expected range was 2,500-2,650 s (`duration_seconds`; the
        strict-FIFO model's 2,508 s including its 37 s start-up, with a stop at about 2,750 s). The batch took
        **2,452.2 s: 48 s below the range's lower end and 56 s (2.2%) under the model**, where TD-58 C0's
        validation had the model under-predicting by 0.6-3.5%. The inputs that moved are measured, not fitted:
        the first checks started at +8 s where the model carries 37 s, the equivalence took 608.0 s against
        673.7 s, and the shards 1,802-1,822 s against 1,861-1,867 s. The model was not re-run on the new
        durations. The batch is 912 s (27%) below TD-58's 3,364.4 s and 774 s (24%) below TD-57's 3,225.7 s.
      - Then `--cached --jobs 6` on the same tree: **477 of 477, all cached, 8.8 s** (run `d15a5def`).
      - Reports: `analysis/_undoc/td64p2/closing.json` and `closing_cached.json`; the log
        `analysis/_undoc/detached/20261010T015450Z_td64p2-closing-full-jobs6.log`; the sampler
        `closing_mem.csv` and `closing_mem_procs.csv`.
    - **Left open:** D7's three items, now TD-66. Nothing else.

- [x] **TD-67 - The strict-FIFO gate idles slots when a single-slot check's ordering key ties a weight-4 check's.**
  **Closed 2026-10-11** (WD-10's unit, C4 `48541898`, Core 0.377.0 unchanged; closed by WD-10's uncached whole batch, run
  `e6cb6108`, 479 of 479; the closing record is the last bullet below). Found 2026-10-11 by TD-56's closing batch (run `bcd678df`, `analysis/_undoc/td56/c6/closing.json`, sampler `closing_mem.csv` +
  `closing_mem_procs.csv`), in the advisor's analysis of the wall time. The batch took 2,742.9 s against TD-64 part 2's 2,452.2 s
  although its check-seconds fell from 10,874.6 to 10,277.9. TD-56 has no wall-time stop, so the batch closed that unit; this item
  records the cause.
  - **The mechanism: TD-65's idling trade, triggered by an ordering tie.** The run's report path was new, so
    `_order_checks_for_run` read the cache's durations only, and two keys came out equal within noise:

    | Check | Slots | Cached duration | Ordering key |
    |---|---|---|---|
    | the transfer-direction corpus | 1 | 945.5 s (run `72b516cc`) | 945.5 |
    | the Python regression suite | 4 | 236.33 s (a local-tier run, 2026-10-10 10:53) | duration x 4 = 945.3 |

    D9 therefore ordered `equivalence, shard, shard, transfer corpus, suite, analyzer handoff corpus, ...`. At +586 s the
    equivalence freed four slots; the head, the transfer corpus, took one; the new head, the suite, needed four and three were
    free, so strict FIFO let nothing behind it start. **Three slots idled for 839 s, 2,517 slot-seconds**, until the corpus ended
    at +1,426 s and the suite started. In `72b516cc` the suite's key (255.3 x 4 = 1,021) led, so no slot idled. The effect is
    deterministic given the cache state. **TD-65's bound "D9's order keeps the idling small" fails whenever a long single-slot
    check's key lands within noise of a weight-4 check's.**
  - **Two candidate fixes**, each to be modelled in `analysis/_undoc/td58/sim.py` (untracked) before any code:
    1. an ordering rule that keeps the weight-4 checks back to back while the two longest single-slot checks (the shards) hold the
       other slots. "Multi-slot first" is wrong under FIFO: it would hold the shards, the critical path, behind a check that
       cannot fit;
    2. gate backfill: a later waiter may take a free slot only if its recorded duration ends before the head could start.
  - **Test:** a single-slot check whose key falls between two weight-4 checks does not idle slots (a scheduler test, driven with a
    counting `Condition` and no sleeps, like `WorkerGateFifoTests`).
  - **Landed with WD-10's uncached batch**, as TD-65 did with TD-64 part 2's, not in a batch of its own.
  - **Cache hygiene:** done in the closing record below (D13).
  - **2026-10-11, closing record** (spec `analysis/_docs/wd10_spec.md` D12, machine-local; C4 `48541898`; closed together with
    WD-10 by one batch).
    - **The model** (`analysis/_docs/wd10_td67_model.py`, machine-local, on the untracked `analysis/_undoc/td64p2/sim.py`)
      reproduces TD-56's batch: 2,744 s and 2,519 idle slot-seconds against the measured 2,742.9 s and 2,517. Walls in seconds
      (including the +8 s start) and idle slot-seconds in brackets, today (D9 plus strict FIFO) against the two fixes:

      | Durations / keys | `--jobs` | Today | Fix 1 (ordering) | Fix 2 (backfill) |
      |---|---|---|---|---|
      | TD-56, the cache's tie keys | 6 | 2,744 (2,519) | **2,324 (1)** | 2,639 (1,890) |
      | TD-56, own keys | 6 | 2,324 (1) | 2,324 (1) | 2,324 (1) |
      | TD-56, own keys | 5 | 3,433 (3,239) | **2,785 (0)** | 3,433 (3,239) |
      | TD-56, own keys | 4 | 4,332 (3,425) | **3,476 (0)** | 4,099 (2,493) |
      | TD-64 part 2, own keys | 6 | 2,452 (0) | 2,452 (0) | 2,452 (0) |
      | TD-64 part 2, own keys | 5 | 3,667 (3,643) | **2,938 (0)** | 3,667 (3,643) |
      | TD-64 part 2, adversarial tie | 6 | 2,925 (2,837) | **2,452 (0)** | 2,925 (2,837) |

    - **The decision: fix 1, an ordering rule; the gate (TD-65) is unchanged.** Fix 1 reaches the work bound at every `--jobs` from
      3 to 6 on every key set and changes nothing where today's order is already right. Fix 2 (a later waiter backfills a free
      slot) recovered only 105 of the tie's 420 s, nothing at `--jobs` 5, and would make the gate depend on recorded durations.
    - **The rule** (`_order_checks_for_run`, `tools/content_suite/run_headless_validation.py`; at every `--jobs`): D9's duration
      x slots sort is unchanged and the exclusive checks stay last. M0 is the first non-exclusive check that occupies more than
      one slot (a check with `members` counts one), at index i0 of the sorted order; the window is the next
      `max(0, jobs - slots(M0) - i0)` non-exclusive single-slot checks after it; the later multi-slot checks follow M0 and the
      window in sorted order, so the next one is the head at the moment the previous one frees its slots. With fewer than two
      multi-slot checks, and at `--jobs 1`, the order is D9's. "Multi-slot first" is wrong: it would put the suite ahead of the
      shards, and the suite cannot fit beside the equivalence. The orders on the tie's checks (the equivalence, two shards, the
      suite, the transfer-direction corpus, the analyzer handoff corpus, playback):

      | `--jobs` | Order |
      |---|---|
      | 6 | equivalence, shard, shard, suite, transfer, analyzer, playback |
      | 5 | equivalence, shard, suite, shard, transfer, analyzer, playback |
      | 4 and 3 | equivalence, suite, shard, shard, transfer, analyzer, playback |
      | 2 | shard, shard, equivalence, suite, transfer, analyzer, playback |

    - **The `--jobs 4`/`5` finding.** Today's order idled slots at those two settings without any tie: the equivalence takes four
      slots and one shard takes the fifth, the second shard then heads the queue and takes the equivalence's freed slot, and the
      suite cannot fit beside the first shard (TD-56's own keys, 3,433 s with 3,239 idle slot-seconds at `--jobs 5` and 4,332 s
      with 3,425 at `--jobs 4`; fix 1: 2,785 s and 3,476 s with none; TD-64 part 2's keys at `--jobs 5`: 3,667 s with 3,643 idle
      slot-seconds, fix 1: 2,938 s with none). TD-65's strict FIFO made those two worse than the old gate. No recorded batch shows
      it, because the owner runs `--jobs 6` and the Launcher `--jobs 1`; the rule applies at every `--jobs`, so it is fixed too.
    - **Tests** (`tests/test_validation_scheduler.py`, 41 -> 48): the tie at `--jobs` 6, 5, 4, 3 and 2; TD-56's own keys; a
      single-slot check ahead of M0 shrinking the window; fewer than two multi-slot checks and `--jobs 1`; the exclusive checks;
      the order being a permutation; and, at the gate, `OrderedGateIdlenessTests`. That test builds the tie's checks, calls
      `_order_checks_for_run(..., jobs=6)`, starts waiters on a `_WorkerGate(6)` with the counting `Condition` in the returned
      order, finishes the equivalence and asserts that the fourth waiter (the suite) is served and no slot is free. The seven
      `WorkerGateFifoTests` and the D9 ordering tests are unchanged. **On `f7a19049`'s runner the new tests fail:** 14 failures
      (subtests counted) in 5 of the 7, the gate-level one with "slots stayed idle after the equivalence ended: the fourth check
      in the returned order, 'transfer', took 1 slot(s)"; the two that pass there (fewer than two multi-slot checks, the
      permutation) hold under either rule.
    - **The proof.** The discriminating proof is at the gate and in the model, not in the batch. The closing batch's census is
      consistent with fix 1 and does not discriminate by itself: on its keys (the full handoff equivalence 579.3 s x 4 = 2,317, the
      shards' member sums ~1,138 each, the suite 249.4 s x 4 = 998, the analyzer handoff corpus 931.8, the transfer-direction
      corpus 839.3, playback 628.9; reconstructed from the cache at the launch) there was no tie, so D9 alone already ordered
      `equivalence, shard, shard, suite, analyzer, transfer, playback` and the old runner would also have passed. What the census
      shows: the suite's runner process started at **+583 s, within a second of the equivalence's end** (+7 s plus 576.3 s;
      +1,426 s in TD-56's batch), and the three single-slot checks behind it started at +841 s, when the suite ended.
    - **The residual risk is in the keys, not the rule.** A single-slot check whose key exceeds a shard's member sum would
      displace that shard from the window, and the shard would then start after the suite. A shard's member sum under-estimates
      its wall time: TD-56's shards ran 1,659 and 1,694 s against sums of 1,240 s; WD-10's batch ran them 1,722.2 and 1,755.0 s
      against 1,137.4 and 1,138.0 s (the sum 34-35% short of the wall time). The margin was ~295 s at TD-56's launch (1,240 s
      against the transfer-direction corpus's ~945 s) and is ~206 s now (~1,138 s against the analyzer handoff corpus's 931.8 s). It
      is a question of the ordering keys (TD-58 D9), not of the rule; `docs/spec/data/validation_checks.md` records it.
    - **The closing batch** (`docs/spec/data/validation_checks.md`): 479 of 479 in 2,546.4 s and 10,715.5 check-seconds, `--cached`
      479 of 479, all cached, 9.5 s. The excess over the unit's 2,500 s is the unkeyed tail: the new archive check had no cache
      entry, sorted after every keyed check, started at +2,355 s and ran nearly alone to +2,534 s. Not TD-67; the 2,650 s stop
      was not reached. The cache holds its key now.
    - **Cache hygiene (D13).** Before the batch exactly 16 entries named `original catalog group routes [k/4]` (the retired
      four-shard names, four each) were deleted: 10,321 -> 10,305 entries, no `--cache-clear` (the ordering reads durations by
      name). None remains.
    - **Left open:** nothing scheduled. The key question above is recorded here and in `validation_checks.md`; watch the margin if
      a single-slot check grows toward the shards' sums.

- [ ] **TD-68 - The BGM route validator fails at its baseline.**
  Found 2026-10-12 by WD-25 item 1b (C0). `tools/content_suite/cli/validate_mes_bgm_route.gd` exits 1 on the
  original: "Confirmed route did not reach the first dialogue boundary", at the `result.trace.size() < 14` step
  after the prelude compare (the prelude compare passes, so item 1b's change of that compare to a length and
  SHA-256 is exercised and gives the same failure; a mutated digest fails at the prelude step instead). The
  validator is a manual CLI (`docs/spec/tech/tooling.md`), not in the batch, so nothing noticed. Re-derive its
  expected route against the current runner, or retire it. Unscheduled; on demand.

- [ ] **TD-69 - The drafter's `Archive.code()` returns None.**
  Found 2026-10-12 by WD-25 item 1b. `tools/draft_event_route_spec.py` `map_location_polls` takes an entry's code
  from `mes_route_decode.Archive.code(entry)`, which returns None for every entry, and the `if not code` guard
  returns an empty list: on the original archive the drafter finds no map-location poll although 14 entries
  hold the record (33 occurrences). Its unit test uses a fake archive that returns bytes, so it passes. Fix the
  accessor (or the call) and add a test on a real container. Unscheduled; on demand.

- [ ] **TD-70 - The calendar test dereferences an error dictionary.**
  Found 2026-10-12 by WD-25 item 1b. `tests/test_mes_calendar_state.gd` reads `projection.table_bytes` (about
  :27) from the projection `build()` returned without first stopping when it is an error dictionary, so a
  START document whose fill record no longer matches hangs the scene until the runner's timeout instead of
  failing a check. Guard the reads and fail fast. Unscheduled; on demand.

- [ ] **TD-71 - The runner matches a map-location contract by offset alone.**
  Found 2026-10-12 by WD-25 item 1b. `content_core/mes_event_runner.gd` `_supplied_map_location` (about
  :1497-1509) matches a declared contract to the native record at `poll_offset` and does not check the
  record's module and function, so a contract declared at an offset where the record is not `Util(6,13)` is
  "supplied". `test_mes_event_runner.gd` and `test_mes_route_probe_definitions.gd` therefore do not pin the
  poll's function byte (13 -> 14 passed); only the Python consumers do. Decide whether the runner should check
  the record (a Core change, with a version bump) or the contract should name it. Unscheduled; on demand.

- [ ] **TD-72 - No parity test between the two grammar builders.**
  Found 2026-10-12 by WD-25 item 1b. `tests/mes_record_grammar.gd` and `tools/payload_values.py` build the
  map-location poll from separate constants; each is decoded by its own test
  (`test_mes_record_grammar.gd`, `test_payload_values.py`), but nothing asserts that the two build the same
  record. A parity test must not quote the bytes (that is the problem the builders solve): compare the decoded
  signatures, or have the Python test print the record's hash and the scene compare it. Unscheduled; on demand.

- [ ] **TD-73 - A changed fixture file's other scenes are not selected automatically.**
  Found 2026-10-12 by WD-25 item 1b. The first merged batch (at `150b6cf7`) failed two scenes,
  `test_mes_registered_call_authoring` and `test_mes_choice_authoring`, that extend
  `tests/test_mes_authoring_workflow.gd`: two fixture edits broke modes the base scene does not run, and the
  implementer's scene list (the files the byte oracle named) did not include them. The batch itself was right -
  the validation fingerprints follow `extends` and `preload`, so those scenes re-ran - and `ca094c20` fixed
  the fixtures. The gap is the selection step: a helper that lists the scenes whose inputs include a changed
  file (the reverse of `--fingerprint-inputs`) would close it; until then, run every scene that shares a
  changed fixture file (`AGENTS.md`). Unscheduled; on demand.

- [ ] **TD-66 - Small leftovers of TD-58, TD-64, TD-56 and WD-10, deferred.**
  Opened 2026-10-10 at TD-64's closing-record review, so that deferred work has an open home rather
  than a mention inside two closed records; TD-56's closing record added the fourth item on 2026-10-11 and WD-10's the fifth.
  Unscheduled; on demand.
  - **The codec stays optional.** `KakyuPlaybackPackageCodeSource._init(document, strings, codec = null)`
    keeps a fresh-codec default for the two-argument test caller (`tests/test_mes_code_source.gd`). A
    future caller could silently fall back to one 0.88 MB encode map per source. Making the codec
    required means changing that test.
  - **`address_table` lives only in the events documents.** The lazy reader therefore parses every entry
    once at load to learn it. Carrying it in the manifest's entry reports would be a schema change: a new
    versioned contract directory, not an in-place edit.
  - **The `--profiles-file` name** in `validate_event_analysis_groups.gd` (`:42`, `:62-66`) is tick-based,
    so two process shards could collide on it. The fallback is reached only above 30,000 argv characters,
    and all 227 profiles take 12,781. The fix is a PID in the name (TD-58 D8).
  - **Two stale documentation claims about command `0x0A`** (TD-56 C1 corrected only the count paragraph, which now points here):
    `docs/spec/mes/format_and_method.md` (around :14030, `08C.MES`'s 57-byte opaque tail, which "stops at a command-`0x0A`
    destination expression stack underflow") and `docs/spec/mes/character_events.md:2623-2631` (the routine-28 boundary at `0x02EE`,
    "command `0x0A` has an empty-stack destination"). Both describe the retired v18 reading. Settle each with the typed-IR method:
    build `mes_analyzer_handoff.build_typed_ir` (`ai5_mes_instruction/v45`) for the entry and count `command_id` 10 records
    regardless of `op` (the v45 IR has none in any of the 1,016 entries; `LIBLARY.LIB`'s 13 `0A FF` byte pairs sit inside other
    commands' records), then rewrite the claim to the typed record that owns those bytes.
  - **Two canonical-JSON conventions coexist** (WD-10, correction 2 of its spec, 2026-10-11).
    `mes_authoring_workflow._json` (`tools/mes_authoring_workflow.py`: sorted keys, `(",", ":")` separators, UTF-8 without
    `ensure_ascii`, **one trailing LF**) is what the authored delta, the definition set, the authoring bundles and, since WD-10,
    the mod bundle hash. `payload_values.canonical_payload_bytes` and `fingerprint` (`tools/payload_values.py`) use the same
    settings **without** the LF, and the TD-05 tools hash those. They are not interchangeable: a document hashed by one never
    verifies under the other. The mod bundle states its form once (`docs/spec/data/mod_bundle.md`, "Canonical form") and
    `tests/test_mod_bundle.py` (`test_the_canonical_form_is_the_delta_and_set_form`) pins that its `payload_sha256` differs from
    `payload_values.fingerprint`. Unifying them would move every delta, set and authoring-bundle hash (a new contract version for
    each); until then a new hashed document states its form, as the bundle does.

- [ ] **TD-63 - Whole-archive hashes that remain per run after TD-57.**
  Found 2026-10-09 by TD-57's reviews; they are change-detection sites, which D2 of
  `analysis/_docs/td57_spec.md` kept full on purpose. Converting either needs a design decision, not a
  mechanical swap.
  - **The content-set open pair:** `event_player.gd:2040` (baseline) and `:2240` ("changed before
    resolver activation") hash each media archive twice in full. That is about 9 s per process, about
    180 s over the 20 shards, and part of the owner's open latency. A later design could take the
    baseline from the reader's first identity hash.
  - **The readiness pair:** `tools/content_suite/catalog_analysis_run.gd:61` (`readiness_group`), run twice
    per group-route run (inside `run_group_route`, :341, and again at `event_player.gd:1390`, "resolve
    again after computation"), hashes `mes.arc`. About 175 of shard 1's 196 remaining full hashes,
    about 12 s per shard, about 240 s over 20 shards. The split is inferred from the code path, not
    labelled.

  Neither moves the batch's wall time while the analysis-group process is the floor (TD-58). Unscheduled;
  on demand by the owner's ruling of 2026-10-09 (the order paragraph under "Open Work").

- [ ] **TD-62 - Nothing before the archive tier notices a route classification bound to an older catalog.**
  Found 2026-10-08 by WD-21 U2's closing batch (run `4d0be71d`). `config/event_catalog/route_classification_v1.json`
  binds `catalog_sha256`. That value is the SHA-256 of the catalog's **canonical JSON** (`canonical()` in
  `tools/classify_event_routes.py`: sorted keys, compact separators, UTF-8), not of the file bytes.
  Earlier catalog revisions refreshed it with `tools/refresh_route_classification.py`: revisions 35-40 in the
  same commit, 32-34 in a later checkpoint before their closing batch. U2's C5 bumped the catalog to revision 41
  without it. Neither the local tier, nor the C5.5 pre-run's selection, nor the C6 batch-readiness review
  caught it, and two archive checks failed after about 80 minutes of batch (fixed in `425d9b0d`: only the hash lines
  moved).
  **Fix:**
  - a Python test in the local tier checking that the classification's `catalog_sha256` equals the canonical-JSON
    SHA-256 of the tracked catalog, computed with the classifier's own `canonical()` (cheap, no archive);
  - the promoter could also print a reminder, or refuse `--write` while the binding is stale.
  - The refresh rewrites the file with CRLF (TD-45), so U2 patched the two lines by hand. The guard's message should
    say so until TD-45 lands.
  Small; can ride with any later catalog unit.

- [ ] **TD-61 - Revisit "uncached at every Core/contract change" once the per-check input closure has earned trust.**
  Raised 2026-10-08 with the batch speed order. Today a Core, contract, analyzer or runner change
  forces the whole batch uncached (AGENTS.md "Verification", owner ruling of 2026-10-03, TD-40). TD-32's
  input closure could, in principle, re-run only the checks whose inputs moved. But TD-53 showed the
  closure can miss an input (three media archives were not fingerprinted), which is why the uncached
  rule stands. **Deferred:** decide after TD-57, TD-58 and TD-47 have landed. The question then is
  whether a closure audit (for example a mutation of each declared input class) makes `--cached`
  sufficient for some of those changes, with the weekly uncached run kept. Owner decision; nothing to do now.

- [ ] **TD-60 - A presentation-only regeneration path for event definitions.**
  Raised 2026-10-08. WD-21 U2 C4's v7 projection took 70 min 22 s (`--jobs 4`). Nearly all of that is
  v6's own projection, re-run although C4 then proved v7 equals v6 outside `presentation` in 681/681.
  When a change touches only `presentation.resources` (TD-56's library restoration is the next one),
  a guarded path could inject the new lists into the existing documents in minutes. The guard: the
  same replays, the same package hash and the same v6-part inputs, refused otherwise (the pattern of
  U2's D10 rebind). Also measure whether the projection runs at `--jobs 6` within memory. After TD-59.
  **2026-10-09, owner ruling: on demand**, with TD-47 and TD-59 (the order paragraph under "Open Work");
  TD-56's regeneration is where it would first pay.
  **2026-10-11, after TD-56:** TD-56's regeneration did not qualify: the Core, the runs and the profile hashes all changed, so v6's
  inputs changed and it was a full re-projection (twice: 64 min 38 s and 64 min 52 s at `--jobs 4`). The `--jobs 6` question is
  answered: the projector's maximum on this machine is 4 (99.1% RAM within 90 s at 6; 86.2% at 4). The next change that touches
  only `resources` is where this would first pay.

- [ ] **TD-59 - A seeded, stratified sample mode for iteration runs (never for closing proofs).**
  Raised 2026-10-08. Pre-runs (WD-21 U2's C5.5 kind) and an implementer's checkpoint checks could run
  a deterministic sample instead of every catalog row. The seed is recorded in the report, so a sample
  is reproducible. It is stratified so every shape is present: site with resume/reentry, visit
  ladder, v14 flow, TALK, `43C` recollection, album menu, `duplicate_route`. One row per analysis
  group gives 227 of 681, about 3x faster. A sampled report must say so and must never satisfy a
  closing proof or close a tracker item; the closing batch stays exhaustive (see the order above). After TD-47.
  **2026-10-09, re-assessment due (TD-57):** the whole group-route family now takes 1,394 check-seconds
  (63-83 s per shard), so a 3x sample would save about 15 minutes of CPU per pre-run, not an hour. Whether
  it is still worth building is the owner's call when its turn comes.
  **2026-10-09, owner ruling: on demand**, with TD-47 and TD-60 (the order paragraph under "Open Work").

- [x] **TD-58 - Split the analysis-group process: it is the batch's critical path.**
  **Closed 2026-10-10** (Core 0.375.0 by TD-64 part 1; the closing record is the last bullet below). Raised 2026-10-08. The 227 analysis-group members run sequentially in one Godot process, which took
  3,691.5 s of the 5,254 s WD-21 U1 closing batch (`process:` line; their own durations sum to
  about 2,425 s). No arrangement of the other checks gets the batch below that, while the
  check-seconds divided by 6 is about 4,130 s. Shard the family into 2-4 processes, as TD-33 did for the group
  routes (longest-first by member duration, TD-42's ordering). Measure the memory peak at `--jobs 6`
  first: TD-40/TD-42 recorded 77-85% of 16 GB. Close on an uncached whole batch with the process
  lines recorded. After TD-57.
  **2026-10-09, after TD-57: now the whole floor.** TD-57's closing batch ran 3,225.7 s wall. The
  process took 3,192.9 s of that, 99%, while the other 250 checks (477 less the 227 members) summed about 7,800 check-seconds,
  about 1,300 s of work per worker at `--jobs 6`. Split into four, it would leave a floor near 800-900 s
  plus scheduling, so the batch could approach about 1,700-2,000 s wall. That is an estimate, not
  measured.
  **2026-10-09, spec v2** (`analysis/_docs/td58_spec.md`, after an advisor pre-review that returned
  "proceed with corrections"). **Not TD-33's mechanism.** The members are cache-filtered one by one
  before the collapse, so static registry shards would leave a `--cached` run unbalanced. Instead:
  - an optional family field `process_shards` (registry revision 5);
  - `collapse_families()` partitions the selected members by recorded duration (LPT, no empty shard),
    capped by `--jobs` and the member count. `--jobs 1` keeps one process;
  - each shard keeps the 8,000 s timeout and prints its own `shard plan:` and `process:` lines;
  - member rows, fingerprints and the cache do not change.

  **N comes from C0's measurement, provisionally 3.** C0 measures the ~958 s that lies outside the
  members' own durations (the Python pre-pass is the suspect), the per-shard pre-pass overlap, and a
  memory estimate. The overlap bound by entry count: 869 distinct entries over 227 profiles, 756 used
  by one profile only, LPT shards 1.11x / 1.16x / 1.20x the single pre-pass for N = 2 / 3 / 4.
  **2026-10-10: C1 landed, the closing batch was stopped.**
  - **C1 `a3754575` + `f2289975`:**
    - `process_shards: 2`, registry revision 5, LPT at collapse time.
    - **D9**, a planner decision the owner may overrule: the order key is duration x
      `min(weight, jobs)`; exclusive checks and member checks count at weight 1.
    - Tests: runner 77, scheduler 34, registry 45.
    - Local tier 140/140.
    - C2 smoke: two shards of three members.
    - The advisor accepted it, and its fuzz reproduces C0's partition.
  - **The closing batch was stopped at about 1,000 s** (memory guard; TD-64). Its early phase was
    fine: the two shard pre-passes peaked the machine at 75.9% (5.5 GB of Python). The breach came from
    `original playback package playback`, which fails the guard even alone. The closing batch reruns
    after TD-64.
  - **2026-10-10, closing record** (spec `analysis/_docs/td58_spec.md`, v3; closed together with TD-64 part 1
    by one batch, below).
    - **The mechanism differs from TD-33, and why.** TD-33 part 2 split the group routes into static registry
      shards (`shards`, revision 4). That does not fit here: the 227 members are cache-filtered one by one
      before the collapse, so a static partition would leave a `--cached` run unbalanced or empty, and it
      would repeat 227 memberships in the registry. Instead the family block gains `process_shards: 2`
      (registry revision 5, which the loader requires: a revision-4 document is refused), and
      `collapse_families()` partitions the cache-filtered selection **at run time**, longest-processing-time
      first by each member's recorded duration (the report's, else the cache's, read once in `main()` and
      shared with the scheduler). The tie-break is (known seconds, member count, shard index), no shard is
      empty, and the count is capped by `min(process_shards, jobs, members)`: `--jobs 1`, which is a Launcher
      background run, keeps one process under today's name. Member rows, fingerprints and the cache are
      unchanged. **N is 2**, fixed after C0: under D9 the model ties N = 2 and N = 3 within its error
      (2,287 against 2,298 s), N = 2 has the lowest overlap and the smallest pre-pass memory, and its two
      shards plus the equivalence's four slots fill all six.
    - **D9 is a planner decision the owner may overrule.** The scheduler's order key is the recorded duration
      x `min(weight, jobs)`; a check with `members` counts at weight 1. It was folded into this unit because
      the goal could not be met without it: the model gained about 10% instead of about 29%, it touches the
      same function, and one uncached batch proves both. If the owner overrules it, N = 3 applies (2,907
      against 3,102 s in the model). TD-64 C3 amended it: exclusive checks sort after every non-exclusive one
      (`ef429f5f`).
    - **C0's measurements** (`analysis/_undoc/td58/`; the advisor accepted them):
      - *The overhead is the Python pre-pass.* The full pre-pass over the 227 profiles, solo, took **1,011.6 s**
        at a peak working set of 4,579 MB. The batch implied 956.6 s outside the members' durations; the two
        agree within 6%. Godot startup takes 0.7-1.5 s, the loop's work outside member durations 0.3 s over
        76 members, and the end hash about 0.1 s.
      - *The overlap.* Three solo N = 3 pre-passes summed **1.264x** the single pre-pass (the run started at
        60.0% RAM); run concurrently they summed 1.158x (started at 49.7%). By entry count the overlap is
        1.11 / 1.16 / 1.20 for N = 2 / 3 / 4. The size-weighted figures 1.17 / 1.22 / 1.32 were computed from
        entry sizes and are kept in no file.
      - *One N = 3 shard end to end:* 1,070.4 s, the first `=== GROUP` line at 363.5 s, 76 of 76 passed,
        a 2,105 MB process-tree peak.
      - *The scheduler model* (`sim.py`, `predict*.py`) replays TD-57's durations under the runner's rules. It
        gave 3,206 s for TD-57 at N = 1 against 3,225.7 s actual. Its TD-42 validation (2,894-2,939 s
        against 3,021.4 s) **assumed** a 1,500-1,700 s analysis-group process, because TD-42 recorded no
        `process:` line, so it is weaker than it looks. The model under-predicted by 0.6-3.5%. It predicted
        3,102 / 2,907 / 2,925 s for N = 2 / 3 / 4 with the old order and 2,287 / 2,298 / 2,307 s with D9. Its
        assumption that waiters take slots first-fit in queue order is what the closing batch refuted
        (TD-65).
      - *Memory.* C0's machine sat at **60.2% idle** (other applications open; TD-42's was 44%). The solo
        pre-pass alone reached 86.6% with page-ins over 1,000/s in 42 of 101 samples, and three concurrent
        pre-passes reached 80.6% from 49.7%. Those absolute RAM figures are C0's machine state, not the
        batch's, which is why the closing batch waited for an idle at or below ~50%.
    - **D8's boundary.** The validator's `--profiles-file` fallback name is tick-based
      (`validate_event_analysis_groups.gd:42`, `:62-66`), so two shards could collide on it. It is reached only
      above 30,000 argv characters, and all 227 profiles take 12,781. The fix, a PID in the name, is
      **deferred** (TD-66); the validator did not change.
    - **The overlap count bound.** 869 distinct entries over 227 profiles with 2,074 references: 756 entries
      belong to one profile only and 113 to several; `DEF_MAIN.MES` and `LIBLARY.LIB` appear in all 227. Every
      shard rebuilds those universal entries under any partition, so entry-affinity partitioning was dropped.
      The count bounds N = 2 at 1.11x the single pre-pass (entries, not their sizes).
    - **The memory goal line is withdrawn.** The unit's goal line "the peak stays at 77-85% (TD-40/TD-42)"
      was never true of `original playback package playback` (TD-64). TD-64 spec D5 replaced the guard:
      (a) TD-58's own phase, the shard pre-passes, peaks at or below ~85% with no sustained page-ins; (b) the
      batch-wide hazard, stop when the commit charge passes ~85% of its limit or page-ins stay in the
      thousands for more than a few consecutive samples. The playback window's peak is recorded against
      TD-64. D6 moved the wall-time stop from ~2,500 s to "not below ~3,000 s" for the same reason.
    - **The closing batch.** The whole `full` tier, uncached with `--cache-store` (Core, the runner and the
      registry changed), `--jobs 6`, `--elfimage --exe --godot`, detached, solo, on the committed tree
      `d367b5bd` (Core 0.375.0), the sampler at 10 s. Idle before the start, the sampler's first row 15 s before
      the runner: 35.8% RAM, 42.0% commit (limit 31,157 MB), inside the ~50% guard. **477 checks, 477 passed, 0 failed, 3,364.4 s** (run `d2144d74`,
      `cached: 0`) and **10,727 check-seconds**, against TD-57's 3,225.7 s and 10,007.
      - *The shards.* Both started at +37 s.
        - `shard plan: 1/2, 113 member(s), 1117.295s known, 0 unknown`, then `process: original event analysis
          groups [1/2] completed in 1861.469s (113 member(s), timeout 8000s)`.
        - `shard plan: 2/2, 114 member(s), 1117.733s known, 0 unknown`, then `... [2/2] completed in 1867.391s
          (114 member(s), timeout 8000s)`.

        The walls differ by 0.3% (the stop was 30%), 0.23 of the 8,000 s timeout. The former single process took
        3,192.9 s. The members' own durations sum 2,445.5 s (TD-57: 2,235.0). The model had expected the
        shards at ~1,640-1,700 s.
      - *The weight-4 and exclusive checks.* The full handoff equivalence started at +37 s, in the first wave as
        D9 intends, and took 673.7 s. The Python regression suite started only at +2,545 s and took 247.4 s
        (see D6 below). The exclusive `original playback package playback` started at +2,802 s and took 559.9 s.
        The 20 group-route shards took 1,428 s in all (62.6-86.9 s each).
      - *Memory,* by window (RAM peak / commit peak):

        | Window | RAM | Commit |
        |---|---|---|
        | pre-pass + equivalence, 0-711 s | 72.5% | 60.8% |
        | corpora + contextual authoring, 711-1,074 s | 53.9% | 51.2% |
        | the export check, 1,074-1,420 s | 89.6% | 71.1% |
        | the rest, 1,420-2,802 s | 69.5% | 59.4% |
        | the playback check alone, 2,802-3,364 s (TD-64) | 94.3% | 73.0% |

        **D5 (a) holds** (the pre-pass window at 72.5%, at or below ~85%). **D5 (b) never fired:** the commit
        charge stayed at or below 73.0%, and page-ins above 1,000/s showed in at most 6 of 135 samples per
        window, never sustained.
      - *The highest timeout ratios:* `original Audio Editor original integration` 125.8 s of 300 (0.42), the
        transfer-direction corpus 942.9 s of 2,400 (0.39), `original playback package export` 344.5 s of 900
        (0.38), the analyzer handoff corpus 935.0 s of 3,000 (0.31), package playback 559.9 s of 1,800 (0.31);
        the two shards 0.23 of 8,000. **None passed 0.5.**
      - Then `--cached --jobs 6` on the same tree: **477 of 477, all cached, 9.9 s** (run `68be8eb1`).
      - Reports: `analysis/_undoc/td58/closing2.json` and `closing2_cached.json`; the log
        `analysis/_undoc/detached/20261009T221659Z_td58-td64-closing-full-jobs6.log`; the sampler
        `closing2_mem.csv` and `closing2_mem_procs.csv`. The first attempt, on `f2289975` the same day, was
        stopped at ~1,000 s by the TD-64 memory breach (`closing_mem.csv`).
    - **D6 fired: the wall time is not below ~3,000 s.** The batch took 3,364.4 s, 4% **more** than TD-57's,
      although the analysis-group process fell from 3,192.9 s to 1,861-1,867 s and is no longer the floor.
      The model's 2,300-2,370 s was not met. Two causes:
      1. The exclusive playback check ran ~560 s alone at the tail. That is TD-64's safety cost; part 2 removes
         it.
      2. `_WorkerGate.acquire` (`tools/content_suite/run_headless_validation.py`, class `_WorkerGate`) has
         **no reservation**. When the equivalence freed its four slots at ~711 s, single-slot waiters took them
         (all waiters wake on `notify_all` and the first that fits wins), so the suite's worker stayed parked
         until ~2,545 s: about one worker of six sat idle for ~1,800 s. C0's model had assumed first-fit among
         the waiters in queue order, which the gate does not do. D9's ordering is right, but cannot take
         effect without a reservation. That is **TD-65**.

      Expected after TD-65 and TD-64 part 2: back toward the ~2,300 s model (an estimate, not measured).
    - **Owner ruling, 2026-10-10: "close now, fix the gate together next."** TD-58 and TD-64 part 1 close on
      this batch. The gate reservation (TD-65) rides with TD-64 part 2's uncached batch, and no extra batch
      runs for it.
    - **Left open:** TD-65; TD-64 part 2; D8's PID fix (TD-66). `TODO.md`'s Validation row now points its unscheduled
      speed items at TD-65.

- [x] **TD-57 - The Event Player re-hashes a whole media archive twice for every voice line, BGM change and new picture.**
  **Closed 2026-10-09** (Core 0.374.0; the closing record is the last bullet below). Found 2026-10-08 (owner: voice playback is slow). `_present_voice_resource` -> `_resolve_audio_payload`
  -> `_classify_effective_media` (`tools/content_suite/apps/event_player.gd:6527`) calls
  `KakyuArcReader.get_archive_fingerprint()`, and `KakyuContentIdentity._validate_inputs`
  (`content_core/content_identity.gd:88`) calls it again; the reader keeps no result and runs
  `FileAccess.get_sha256(archive_path)` over the whole file each time (`content_core/arc_reader.gd:110-113`).
  Measured on this machine (Godot 4.7.2 headless, scratch project): **1.63-1.80 s per pass over
  `voice.arc` (497 MB)**, so about 3.5 s per voice line on the main thread (Python's hashlib: 0.40 s
  per pass). The same path serves BGM (`bgm.arc`, 471 MB, `:6668`), pictures (`mmo.arc`, 400 MB,
  `:6485`) and AX (`data.arc`, `:6599`). The batch does not see it: the group-route Playback pass
  checks voices with `find_entry` only (`validators/validate_catalog_group_routes.gd:289-296`).
  **Fix (owner ruling 2026-10-08: after WD-21 U2, as its own Core unit):** keep the identity
  guarantee but memoize the archive SHA-256 per open reader, re-hashing when the file's size or
  modified time changes (so "ARC changed after it was opened" checks in `arc_writer.gd`/
  `arc_provenance.gd` still fail closed on a real change); a Core bump, tests for the guard, and a
  timing check on a voice-heavy row. Not during U2: a Core bump moves the package manifest's
  `content_core_version` and would turn U2's C6 rebind into a full re-projection.
  **Batch impact (hypothesis, not measured yet).** The headless paths hash too:
  `_present_bgm_resource` -> `_resolve_audio_payload` hashes before its headless guard, and
  `_resolve_mmo_image` -> `_classify_effective_media` hashes for every picture
  (`event_player.gd:6485, 6668`). The group-route validator calls `play_catalog_request` and
  `analyze_catalog_request` several times per row (`validators/validate_catalog_group_routes.gd:152,
  229, 372, 419, 481, 532`). So a large share of the shards' ~22.5 s per row (62% of the batch's
  check-seconds, see the order above) may be this hashing. **First step, before the fix:** on one
  shard, count the `get_archive_fingerprint()` calls and their time, solo, after U2's heavy runs. The
  result decides how much TD-58 and TD-47 still need to win.
  **Measured 2026-10-09 (the hypothesis holds).** Setup:
  - A scratch git worktree at `14372781`, since removed. Only `content_core/arc_reader.gd` was
    instrumented: a timed print per `get_archive_fingerprint()` and `get_entry_fingerprint()` call,
    and with `TD57_MEMO=1` each archive path hashed once.
  - `original catalog group routes [1/20]` (35 rows) run solo at `--jobs 1`, twice.

  Results:

  | | A: as committed | B: memo on |
  |---|---|---|
  | shard duration | **797.7 s** | **65.6 s** (12.2x faster) |
  | archive-hash time | 733.3 s, **91.9% of the check** | 4.8 s |
  | calls (both runs) | 774 | 774 |

  Run A's hash time by archive: `bgm.arc` 166 calls / 263.8 s (1.59 s each), `voice.arc` 138 / 234.0 s
  (1.70), `mmo.arc` 162 / 219.4 s (1.35), `mes.arc` 222 / 13.6 s, `data.arc` 84 / 2.3 s, `tina1.arc`
  2 / 0.2 s. Entry fingerprints: 4,388 calls, 5.9 s. Both runs printed the identical shard JSON line
  (the same pass, gates and counts); the logs differ only in the run id. Logs:
  `analysis/_undoc/td57/td57_A.log` and `td57_B.log` (copied out of the session scratchpad), with the
  baseline shard line in `baseline_shard1_line.json`.

  Extrapolation at the time (the measured result is in the closing record below): the 20 shards took 13,473 s of WD-21 U2's 21,975 check-seconds
  and would drop to about 1,100-1,500 s. Package playback/export, the contextual-authoring checks
  and the Event Player checks open the same paths and may gain too. The batch's wall-time floor
  would then be the analysis-group process (3,180 s), which makes TD-58 the next lever.
  **TD-47 and TD-59 are re-assessed after TD-57 lands**, because their premise (~22.5 s per row) was
  mostly this hashing.
  **2026-10-09, spec and owner ruling.** The spec is `analysis/_docs/td57_spec.md` (v2, after the advisor's
  design pre-review). The design:
  - **Memo:** each open reader keeps its archive's SHA-256, guarded by the file's size and modified time,
    cleared by `open()`/`close()`.
  - **API:** `get_archive_identity_fingerprint()` serves identity lookups only. `get_archive_fingerprint()`
    keeps hashing in full for every change-detection check.
  - **Core** 0.374.0.
  - **Definitions:** the rebind tool gains a Core-version pair, so the live v7 set is rebound rather than
    re-projected.

  The owner **accepted the residual risk** the same day: an identity lookup cannot see a same-size rewrite of
  the archive within the same second as that reader's last full hash.
  - **2026-10-09, closing record.** Each checkpoint had an advisor review, all "accept".
    - **The code.**
      - **C1 `8c4dcd76`:** `KakyuArcReader` gains a per-open identity memo. It stores `{size, modified_time,
        sha256}` only when the stat pair is stable across a full hash, and `open()`/`close()` clear it.
        `get_archive_identity_fingerprint()` serves identity lookups; `get_archive_fingerprint()` still
        hashes in full. Exactly eight identity sites were converted: `event_player.gd:6527, 1071, 2081,
        2581, 3374, 4685`, `content_identity.gd:88` and `event_player_evidence.gd:208`. Every
        remaining site, the change-detection ones, is unchanged.
      - **Tests:** 27 memo checks and two `content_identity.gd:88` refusals; reverting line 88 fails the
        residual check. All six mutation fixtures pass unmodified.
      - **C1 follow-up `d3b74b4a`:** a check that fails if the memo were static (another reader's lookup
        must leave this reader's memo warm), and a `size < 0` guard.
      - **C3 `b838dd53` + `ab96502a`:** the rebind tool's `--pair core-version`.
    - **C2, measured.** Shard 1/20 solo took **77.2 s against 797.7 s**, with the shard JSON line
      byte-identical to the baseline (`analysis/_undoc/td57/c2_shard1.log`; duration in `c2_shard1.json`).
      Each media archive is now hashed once per process.
    - **Owner GUI check:** voice playback confirmed, the per-line delay is gone.
    - **C4 `8784044c`:** the Core 0.374.0 binding export `5ae6aabe...` (`analysis/playback_package_td57/`;
      log `analysis/_undoc/detached/td57-c4-export.log`, 6 min 27 s). Its manifest differs from U2's
      `874f53ca...` in `content_core_version` and `package_sha256` only, and the other 1,738 files are
      byte-identical (re-verified by the C4 review). The live v7 set was rebound with `--pair
      core-version`, one line per file: 681/681 valid.
    - **C5:** `7331ea26` (records).
    - **Closing proof.** The whole `full` tier, uncached with `--cache-store`, `--jobs 6`, detached, on
      `7331ea26` (run `37a06f05`): **477 of 477 in 3,225.7 s** (U2: 4,770.3 s) and **10,007
      check-seconds** (U2: 21,975).

      | Family | U2 | TD-57 |
      |---|---|---|
      | the 20 group-route shards | 13,473 s | **1,394 s (-90%)**, 63.2-83.1 s each |
      | the Event Player checks | 217 s | 124 s |
      | package export + playback | 933 s | 941 s |
      | contextual authoring | 993 s | 1,024 s |
      | the analysis-group members | 2,260 s | 2,235 s |

      - The analysis-group process took 3,192.9 s of 8,000. It is now the floor: 99% of the wall time.
      - No check passed 0.38 of its timeout. The highest were the transfer-direction corpus at 0.37 and
        package playback at 0.35.
      - The export check printed `package_sha256=5ae6aabe...`, the same as C4's export.
      - Gate 3: 15,011 names, 0 undeclared. Gate 2: 184 registered, 0 unregistered.
      - Then `--cached`: 477 of 477, all cached, 61.9 s (run `523b0a4b`).
      - Reports: `analysis/_undoc/td57/closing.json` and `closing_cached.json`.
    - **Left open:** the remaining whole-archive hashes are TD-63. TD-47 and TD-59 are re-assessed (their
      premise is gone), and TD-58 is next.

- [x] **TD-56 - The generic runner does not feed command-`0x09` writes into `global_i32`, so shared media ladders always see selector 0.**
  **Closed 2026-10-10/11** (Core 0.377.0; the closing record follows the list of pins below, and TD-55 closed inside it). Found 2026-10-08 (WD-21 U2 C2 review, `analysis/_undoc/wd21_u2/c2_report.json`): command `0x09`
  writes `argument_slots` only (`content_core/mes_event_runner.gd:1077-1095`; `global_i32` is written
  only by `0x0A`, :717), while `LIBLARY.LIB` routines 9 (effect dispatch, rungs from 3769) and 27
  (pictures, rungs from 13640) branch on `global_i32[1]` (token `0xF6`). In the original both address
  the same storage (`docs/spec/mes/audio.md:604-614`, which records the runner's ABI as deliberately
  uncorrected; the EVENTB03 adapter stages the slots in a disposable sandbox only). Over the 227
  analysis-group profiles routine 9 runs 468 times and reaches 0 of 78 SE; routine 27 runs 3,839
  times and always takes its selector-0 `BLACK.MMO` arm. By owner ruling of 2026-10-08 (WD-21) the
  live v7 definitions and the catalog therefore list no `LIBLARY.LIB` item. **The fix is a Core unit
  after WD-21 U2:** model the write as a tool decision (one line near :1084 and a Core bump), then
  the `state_diff` of every run with a `0x09` write moves - all 227 replays regenerate, profiles whose
  `expected_state`/`message_count` move are re-derived, the B03 audits' pinned signatures re-pin,
  the package manifest's `content_core_version` moves (a full re-projection rather than a rebind),
  the EVENTB03 adapter and the `0x09` documents are revised - and v7 and the catalog regenerate in
  the same shape with library items restored. Scheduled by the owner 2026-10-10 ("1부터"); done, the record below.
  The pins that regeneration flips on purpose (WD-21 U2 C5 review):
  - `tests/test_event_definitions_tracked.py`'s "no `LIBLARY.LIB` item while TD-56 is open";
  - the 17,020-item counts in `tests/test_event_catalog.gd` (~237-238) and
    `tests/test_promote_analysis_groups.py` (~63);
  - `EXCLUDED_ENTRIES` in `tools/project_event_definition_v7.py`;
  - the counts in `docs/spec/tech/event_player.md` (~101-105) and in the measured-route section
    of `docs/spec/mes/media_references.md`.
  **Closing record, 2026-10-10/11** (spec `analysis/_docs/td56_spec.md`: v2 after the advisor's pre-review of v1, which returned "proceed with corrections" and whose ten corrections v2 folded in, then amended on 2026-10-10 and 2026-10-11; Core 0.377.0, 0.376.0 before). Owner rulings: 2026-10-10 ("1부터": TD-56 is the next unit, after TD-64 part 2 and TD-65) and 2026-10-11 ("플래그 반영", option 2 of the C4 stop: the library-set flags are declared in the definitions, and D11 excludes the argument storage). **TD-55 was folded in as a bounded prerequisite by a planner decision told to the owner.** The advisor reviewed C0 (the model stays (b); seven absent names, not three; a third fidelity class), then C1, C2, C3, the C4 commits and both C5 commits, and accepted each of them.
  - **The commits.**

    | Checkpoint | Commit | Content |
    |---|---|---|
    | C1 | `f5e61701` | Core 0.377.0: the alias model, TD-55's fix, the pins, 10 archive audits re-pinned, the rule and the `0x0A` correction in `format_and_method.md` |
    | C2 | none (artifacts) | the 227 v3 replays regenerated and diffed against a before-copy |
    | C3 | `0bd10c8e` | 13 profiles cell-patched, 86 cells |
    | Bridge | `56b77d7a` | catalog revision 42 |
    | C4a | `0b6f8155` | D11 and its tests; the library exclusion seam emptied |
    | C4b | `9e14a56e` | the first v7 re-projection against export A; the delta-class walker |
    | Driver | `cffa258b` | the batch driver's `--only` merge and its failure recording |
    | C4c | `f546569a` | the v7 set re-projected on a witness corpus regenerated from the v3 replays |
    | C5 | `7b1aa579`, `210162c4` | catalog revision 43; export B, the v7 set rebound from A to B, the live-binding lines and the count docs |
    | C6 | the commit of this record | the closing batch and the records |

  - **The rule (D1, D2) is confirmed and modelled as one storage.** Command `0x09`'s dword stores (`0x00418CBD`, `0x00418D05`) and expression token `0xF6`'s read (`0x004060A6`) address the same original storage, `common_state + 0x3000 + index * 4`. Evidence type: a configured-original executable audit (first recorded in `docs/spec/mes/audio.md`, with audit v37's reconfirmation of the indexed writer); confidence **Confirmed**. It is recorded in `docs/spec/mes/format_and_method.md` ("Command `0x09` and token `0xF6` address one storage (Core 0.377.0)"), and `audio.md`'s note that the runner's ABI was deliberately uncorrected now reads "modelled since Core 0.377.0". The runner models it as an **alias, option (b)** (the advisor's ruling; the two-line mirror, option (a), was only C0's prototype), in three steps, each diffed against the corpus replays:
    1. `0x09` writes `global_i32` through the sandbox (the trace row carries `write_storage = "global_i32"`, `write_start`, `write_count` and `write_bank` beside the `argument_slot_*` fields);
    2. the semantic readers (routine 0's message id, routine 23's selector, the EVENTB03 projection) read `global_i32[n]` from the state, and the old "slot 1 unwritten" gate is gone;
    3. `argument_slots` survives only as per-run provenance for the traces, the previews and the continuations, and is never read for meaning.

    **Tool decisions, named (not original facts):** the runner's representation (provenance slots beside the storage values); the unwritten value (the sandbox's 0); the EVENTB03 adapter stays (a no-op projection of equal values; its retirement and its audits' re-pin are a separate decision, not taken); command `0x16` stays out (below); the reference index is unchanged (it still emits no write row for argument-slot runs, so the frozen v45 digest does not move; extending it is deferred).
  - **Why the alias and not the mirror.** C0's mirror and the alias are identical on the corpus: 243,455 slot-1 reads by routines 0 and 23, equal in both views, and 0 executed `0x0A` writes; they differ only by the mirror's `0x16` artefact (39 index-9 rows). The alias is the original's rule, and the runner also executes authored and edited routes, where the mirror diverges in three classes: a routine 0/23 read after a `0x0A` write or a seeded index 1; the `has(1)` gate, which the native storage always satisfies; a continuation restore that re-imposes a slot snapshot over the storage.
  - **Found consequences of the alias** (C1; no refusal assertion changed):
    - the BGM prefix's old rule, that a prefix route leaves an **empty** state diff, is replaced by `_diff_is_own_argument_storage` (`content_core/mes_caller_route.gd:673-696`): the prefix may change only the `global_i32` cells its own command-`0x09` rows wrote, with the values they wrote (8 refusal tests). The BGM-prefix routes' profiles did not fail the family run, so the guard adds nothing to the 13 below;
    - the replay attribution (`tools/content_suite/replay_run_media.gd:84-105`) now labels in two ways, because TD-55's fix re-keys library-invoked DEF rows. After C2 every replay carries the new labelling, and the legacy branch serves only old replays.
  - **Command `0x16` stays unresolved.** The claim that its handler stores at native state base `+0x20EC + slot * 4` comes from the handler audit already recorded in `format_and_method.md` (the command-`0x16` paragraph near :1377: jump-table slot, wrapper `0x00418231`, handler `0x00418BC0`, the store through `0x00405F10`); no audit relates that base to `common_state + 0x3000`, and nothing reads the index it writes in the corpus (in the replays its one slot-9 run executes 78 times at `LIBLARY.LIB:61115`, and nothing reads `global_i32[9]`). It stays argument-slot only. Fold it in only if its write site is audited with addresses.
  - **The `0x0A` correction.** `format_and_method.md` carried "50 aligned command-`0x0A` rows" (the v18 reading). It does not reproduce. Method: the v45 typed IR (`mes_analyzer_handoff.build_typed_ir`, `ai5_mes_instruction/v45`) over all 1,016 entries has **0 `command_id` 10 records, counted regardless of `op`**, and no opaque tail either; `audit_mes_command_0a.py` reports 0 rows. The 13 `0A FF` byte pairs of `LIBLARY.LIB` sit inside other commands' records (`0x12` 3, `0x0D` 4, `0x05` 3, `0x04`, `0x1B`, `0x1C`), and routine 28's former row sits inside the v42 subcommand-10 envelope. The paragraph keeps the old reading as history with this re-measurement; the runner's `0x0A` branch is unaffected (it writes `global_i32`, and authored or edited routes reach it). **Two stale documentation claims describe the same retired reading and are left to TD-66** (the typed-IR method settles each).
  - **C0 (2026-10-10, measurement only, `analysis/_undoc/td56/`).** The mirror prototype, then the tree restored (clean at `ca6d48ca`); regeneration 1,213 s at `--jobs 4`. **9,527 of 12,871 replay runs changed**, in every one of the 227 profiles (minimum 3, median 36, maximum 368 per profile); messages, message counts, terminals, stops and `resource_rows` changed in none. `state_diff` moved in 8,321 runs, `executed` in 6,112 and `final_state` in 931; the new `global_i32` rows were index 1 (8,316 runs), 2 (138) and 9 (39, the mirror's `0x16` artefact). Cells outside `global_i32` (`global_u8[4000]`, `[4090]`, `[4091]`, `[3020]`, `[3041..3046]`, `state_u16[8]`, from routines 28, 33, 34 and 39) moved only with a changed library path, and a negative control held: the 6,040 runs whose library path did not change moved in `global_i32` rows alone. **13 of the 227 analysis-group checks failed, all on pinned cells.** The validator's signature movements (161 `payload_sha256`, 2,394 variant `trace_sha256`) are pinned by no tracked file except the B03 audits that C1 re-pinned, so they are not blast radius.
  - **What the library now reaches.** Routine 9 reaches 25 of 78 sound-effect rungs (all shipped) and routine 27 44 of 74; the distinct `LIBLARY.LIB` occurrences go from 2 to 251 (`mmo` 106, `se` 25, `unclassified` 120; the first `se` items any row declares). The five offsets no longer reached are the selector-0 losses: routine 9 at 6912, routine 33 at 57557, routine 39 at 61175, 61186 and 61194. Routine 27's reached rungs name **seven** registered absent `.MMO` names (`01CA_3`, `01CM_3`, `01CS_3`, `19M_3`, `20CA_3`, `20CM_3`, `20CS_3`), and the replays execute occurrences of three of them (`01CS_3`, `19M_3`, `20CA_3`). All seven are already in the known-absent register, so D9 added no row.
  - **C2 (artifacts only).** The 227 v3 replays regenerated in place on `f5e61701` (860.8 s at `--jobs 6`; exit 1 from exactly the 13 profiles), after the machine-local pre-TD-56 set was copied to `analysis/_undoc/td56/replays_before/` (hash-verified). **9,527 of 12,871 runs changed, 0 unexplained**; messages, counts, terminals and `resource_rows` never change. By D10's classes:
    - **Class 1, a `0x09` write seen through `global_i32`, accounts for all 9,527 runs.** Every `global_i32` row (index 1 or 2; no index 9) matches a covering `0x09` literal, and every other cell has a writer among the gained or lost records.
    - **Class 2, a routine 0/23 read that now resolves, is empty**: library routines 0 and 23 execute in 0 runs, because the runner intercepts those calls.
    - **Class 3, a row re-keyed by TD-55 (added by C0's review), is empty in the replays**: `replay_run_media.gd`'s tool-level rule (WD-21 U2 R1) already re-keyed library-invoked DEF rows, and reverting TD-55's fix alone regenerates the 161 route replays byte-identically. The re-key shows only in the validator's row signatures, which no tracked file pins. The experiment's `with_lib_def` counters are unpopulated, so this rests on the byte-identity result and on the mechanism.
    - **Media:** `LIBLARY.LIB` occurrences 14,712 -> 14,961 (+249, 0 lost); route and DEF occurrences unchanged; the DEF offsets stay at 375, so no gained library occurrence is a DEF row. Per-profile regeneration time rose 10% (the mirror's 4%).
  - **C1 `f5e61701`, verified.** Local tier 140/140; `archive_quick` 217/217; the analysis-group family 214 pass and exactly C0's 13 fail; the other 26 full-tier runner-reaching checks pass; the package playback check solo PASS, its messages, terminals and stops identical across 681 EVENT lines (`rows` moved in 678 and `library`/`segments` in 497). **10 archive audits were re-pinned**, each moved value a `global_i32` row from a `0x09` or a library-path change from the selector the library now sees: 10M entry 59 diff; PROMIS caller reachability (3,747 -> 3,877 and 12,457 -> 12,587 rows); PROMIS nested routes (the diff gains `global_i32[1]`); startup definition calls (`global_i32`: 13); EVENTD08 composed choices (routine 28's selector-1 arm, routine 27's 46 rows); the four EVENTB03 audits (picture and final diffs, outer traces, shared-call sequence); the Event Player fragment catalogs (state counts, the second declared EVENTD06 terminal). The unit scenes whose pins moved by design are `test_event_player`, `test_mes_caller_route`, `test_mes_event_runner` and `test_mes_script_call_runner`. The EVENTB03 camera and sound audits pass untouched, which is the adapter's staging. The pins the spec listed as flipping on purpose (the "no `LIBLARY.LIB` item" test, the 17,020-item counts, `EXCLUDED_ENTRIES`, the counts in `docs/spec/tech/event_player.md` and `media_references.md`) were flipped at C4 and C5.
  - **C3 `0bd10c8e`: the 13 profiles.** None of their writers' inputs exist on this machine, so each profile was **cell-patched**: exactly the cells its own check reported (declared -> measured, read from the validator on the C1 tree), nothing else, with `payload_sha256` recomputed by `audit_event_analysis_group.py`'s `fingerprint()`. 86 cells in all, every one D10 class 1; a deep diff of each file against its parent shows only those cells and the hash. The family check passed uncached, 227/227 (1,614 s at `--jobs 6`; `analysis/_undoc/td56/c3_family_report.json`). The 13 replays were regenerated after C2 to bind the new hashes and differ from C2's only in `payload_sha256`. The frozen v3-v6 sets keep the old hashes (`tools/validate_event_definition.py` checks `profile_sha256` for presence and type only), while the catalog side resolves hashes against the live profiles, so the catalog was stale until the bridge.

    | Profiles | Cells, declared -> measured | Cause |
    |---|---|---|
    | `01m_j04_v6`, `17m_a02_v6`, `23m_c17_v6`, `27c1a_c03_v6`, `27c_ev_m14_v5`, `h_date3_h19_v5`, `k_date3_k15_v5`, `ground_h17_k09_branches_v2`, `ground_k09_outer_v4`, `ground_f02_v11` (10; two bypass variants for `ground_f02_v11`) | `global_u8[4000]` 0 -> 1 | routine 28's selector-1 arm is reached: its **record 910** sets `[4000] = 1`, behind `global_i32[1] == 1` at 889 |
    | `ground_g08_arrival_v11` (1; the `clock-1900` bypass variant) | `global_u8[4090]` and `[4091]` 0 -> 1 | the same arm: **records 866 and 883** |
    | `15c_c06_v10`, `15c_e11_v10` (2) | `global_u8[3041]` 1 -> 6, `[3042]` 255 -> 7, `state_u16[8]` 1 -> 5 | routine 39 takes its **selector-3 arm at 61307** (writes 61318..61394 and 61329..61405) and no longer its selector-0 arm |
  - **The catalog chain 41 -> 42 -> 43.**
    - **Revision 42 `56b77d7a` is a bridge.** Export A was refused ("Manifest membership is inconsistent with its entries"): the full export keeps only the profiles whose `payload_sha256` the catalog rows reference, C3 had moved 13 of them, and three catalog members (`GROUND.INC.MES`, `CHOKO.MES`, `END1.MES`) were left unbound. That is a cycle: the promoter needs v7, v7 needs export A, and export A needs the catalog's profile hashes. The promoter produced 42 from a scratch v7 copy with the 13 old hashes substituted. Its diff against 41 is exactly `catalog_revision`, **14 `profile_sha256` values and 234 preset `notes` lines** that embed the 12-hex prefix (a deep diff asserts it; no row, resource or other field moved), and the route classification's hash lines were refreshed (TD-62; LF kept, TD-45). The promoter's `--check` and `test_promote_analysis_groups.py` were red at that commit by design and green again at C5. Revisions 42 and 43 are recorded in the promoter's revision comment, in `docs/spec/data/event_definition_v7.md` and in `docs/spec/data/workspace_playback_export.md`.
    - **Revision 43 `7b1aa579`** is the promotion of the C4c set. Only the `resources` of **293 rows** change, **17,020 -> 18,113 items (+1,093 `LIBLARY.LIB` items)**; every earlier item is still there, 0 rows have another difference, and the promoter's `--check` is byte for byte. The classification's `catalog_sha256` (`ea81ab36...` -> `6fe9a6b5...`) and its payload hash were refreshed; no entry, class or confidence moved. No test or validator compares the catalog revision with a package's `source.catalog_revision`.
  - **The second stop and D11 (owner ruling 2026-10-11, "플래그 반영", option 2).** The first re-projection (against export A at `--jobs 4`) showed three classes of drift: the library-set flags (`global_u8[4000]`, `[4090]`, `[4091]` = 1) declared by the v4 flag pattern; 2,086 `unresolved` lines for the argument storage (`global_i32[1|2]`, "no matching shift witness"); and 166 unwitnessed flag lines in 35 flow documents. The owner ruled that the flags enter the definitions, because the original sets them, and that the argument storage is excluded. **D11 (`0b6f8155`; a projection tool decision, not a native claim).** In the shared `tools/project_event_definition.py` (`ArgumentStorage`, `command_09_writes`, `merge_unresolved`, so the v4, v5 and v6 paths and therefore v7 agree), a run's `global_i32` net change is **argument storage** when the run executed a command-`0x09` record whose write range covers the index and whose literal equals the change's final value (in a flow variant a covering `0x09` of an earlier hop of the same variant also counts). It leaves the effect derivation (no `after` row, no witness row) and is listed once per `(index, value)` in `unresolved` ("argument storage: global_i32[n] = v written by command 0x09 at <entry>:<offset>; not an event effect (TD-56 D11)"). A change with no covering literal keeps the ordinary path. The rule reads the v3 replays' `executed` offsets, so it is inert on a v2 replay and the frozen v4-v6 producers are unchanged. It rests on C2's read-coverage evidence: every library-ladder read of an index follows a `0x09` that wrote it in the same run (6,681 reads) or in an earlier hop of the same variant (134). **Measured: 1,261 cells excluded (`global_i32[1]` 1,210, `[2]` 51), 0 uncovered**, in 679 documents with writers in 713 entries. It is documented in `docs/spec/data/event_definition_v4.md`'s effect rules and in `format_and_method.md`'s TD-56 section (item 6); `EXCLUDED_ENTRIES` in `tools/project_event_definition_v7.py` is now the empty set (the seam stays).
  - **The witness corpus** (the projector refuses a projection without one, TD-37). The C4b set rested on a corpus planned from the pre-TD-56 `replays_v2` for 148 of the 161 profiles, so **C4c regenerated it from the v3 replays for all 161** (`tools/plan_event_effect_witnesses.py`, answered by `validate_event_analysis_group.gd --witness`: 148 profiles in 815 s at 4 parallel, 0 errors, every `payload_sha256` the profile's; untracked and machine-local; the old corpus is kept in `corpus_before/`). Requests by kind, before -> after:

    | Kind | Before | After |
    |---|---|---|
    | `shift:banked_u16` | 2,003 | 2,003 |
    | `shift:global_u8` | 1,108 | 1,117 |
    | `shift:state_u16` | 1,690 | 1,688 |
    | `shift:global_i32` | 0 | 491 (29 in the 13 re-derived profiles; D11 ignores every `global_i32` cell) |
    | `done_probe` | 363 | 363 |

    Over the 4,778 shift outcomes both corpora answer, **61 changed, in 46 profiles** (115 profiles unchanged): 51 `global_u8[4000]` `other` -> `set` (entry 1, final 0) and, in the two 15c profiles, 6 `[3042]` and 4 `state_u16[8]` `set` -> `set` with another final. **The 363 done-probe outcomes, the gate lists that the projection reads, did not change.** The 12 `01m_*_date_v14` flows have no corpus (the planner skips flow replays and the flow projector reads none), so their 166 flag lines stay `unresolved` (class 3b below).
  - **The v7 set against the frozen v6 set.** The test "v7 equals v6 outside `presentation`" became a **delta-class walker** in `tests/test_event_definitions_tracked.py` (anything outside the classes fails; its own mutation tests; a listed exception for the 13 ids). **13 definitions changed content** (class 4); v6 stays frozen, and its README records that v7 supersedes it in these classes. Over all 681 documents (C4c):

    | Class | What | Rows | Documents |
    |---|---|---|---|
    | 1 | library-set flag writes (`global_u8[4000]`, `[4090]`, `[4091]` = 1) added to `after`, `flow.hops[].after`, `results[*].after` | 2,406 | 419 |
    | 2 | the same cells' `flag_pattern` `effect_witnesses` rows | 2,406 | 419 |
    | 3a | D11 argument-storage lines added to `unresolved` | 1,261 | 679 |
    | 3b | flow flag lines (`entry=1`, `final=0`) that no witness decides | 166 | 35 |
    | 3c | retired `[4000]` "witness outcome other" lines removed | 58 removed | 51 |
    | 4 | the 13 re-derived documents: 14 group `profile_sha256` values and 44 rows of their cells | | 13 |
    | 5 | `presentation` and `package_binding.package_sha256` | | 681 |
    | 6 | a selector-0 flag clear that the witnesses decide (added) or the library no longer performs (removed); after rows + witness rows | 42 + 42 added, 3 + 2 removed | 43 |

    **Class 6 runs in both directions.** Routine 28's record 756 sets `[4000] = 0` (the selector-0 clear) and record 910 sets `[4000] = 1` (the selector-1 set). A caller that sets slot 1 = 1 and later slot 1 = 0 (`EVENTK01.MES` offsets 265 and 578) executes both, so the event shows a picture and then clears it: **39 documents declare `write 0` (entry 1, final 0), while 419 end with the flag set.** Classes 6 and 3b are two beyond the five the C4 brief listed; both are measured consequences of the same ruling. Against the C4b set only 39 documents changed in C4c: 40 `[4000] = 0` `after` rows and their 40 `shift_witness` rows added and 45 "witness outcome other" lines removed.
  - **The resources.** The lists sum to **18,113 items (17,020 before), 14,961 distinct (14,710)**. The growth is exactly the library items: **1,093 in 293 documents, 251 distinct** (`mmo` 106, `se` 25, `unclassified` 120), each a `LIBLARY.LIB` record start and an inventory occurrence. Route and `DEF_MAIN.MES` items are unchanged (16,896 and 124). An independent re-join from the v3 replays equals the lists in 681 of 681 documents.
  - **The exports and the binding.** The Core change moves runs and the package hash covers `source.catalog_revision`, so two binding exports were made with the same invocation (machine-local; 681 events from 869 member entries, 987,386 records each; export B took about 5 min 50 s detached, at a 1.6 GB peak working set):
    - **Export A** `analysis/playback_package_td56a`, `3af3779f6b7ff599e397cdbeaae30ee16e44be2bc88ff1562a9f42b27bb13cdd` (Core 0.377.0, catalog 42). Against TD-64 part 2's package only `manifest.json` differs, in 250 fields: the Core version, the hash, `source.catalog_revision` 41 -> 42, the 13 re-derived groups' `payload_sha256` and 234 preset `notes` strings. The runner change moves replays, not package records.
    - **Export B** `analysis/playback_package_td56b`, **`0e47e063e8fd9a80621e48e180b89fcb2547f966fc7fc8e59550ab92cab9ab96`** (catalog 43), the live package. Against A only `package_sha256` and `source.catalog_revision` (42 -> 43) differ.
    - The v7 set was **re-projected** against A, not rebound, because a rebind is refused by design when a Core change moves runs (C4b `9e14a56e`, then C4c `f546569a`: 681 valid against A, 0 against the previous package; the full projection took **64 min 38 s** and **64 min 52 s** at `--jobs 4`, 681 valid, no failure in C4c), then **rebound** to B with `tools/rebind_event_definitions.py --pair catalog-revision` (dry run first: `differing_manifest_fields` `package_sha256` and `source.catalog_revision`; 681 valid against B and 0 against A, one line changed per document). The v7 contract under `config/contracts/` did not change.
  - **The projector runs at most `--jobs 4` on this machine** (TD-60's question about `--jobs 6`, answered): the peak RAM was 85.3% (C4b) and 86.2% (C4c) at 4, and **99.1% within 90 s at 6**.
  - **C4b's one-time failure.** The first batch refused `ai.special.ai_m.h02.1` once; it projects clean on its own, byte-identical to the standalone projection, and was merged with its index row. **The cause is unrecoverable** (the old `detail` field kept only the last 2,000 characters). `cffa258b` fixed the two defects the failure exposed: `--only` now **merges** into the existing `index.json` (rows replaced by id, the summary recomputed, a mismatched package, contract, names or cells fingerprint refused untouched; resuming with `--only` used to overwrite the tracked index with a one-row one), and a failed projection **records its cause** (`exit_code` and the last six non-empty stdout and stderr lines). 10 new tests (13 -> 23); **the recording is tested only synthetically**, because no real failure reproduced.
  - **Gate 3 does not see the library items; this corrects v2's D10 line "gate 3 stays at 0 undeclared, now with library items", which was an assumption.** Gate 3 compares the names the *played timeline* uses with the row's declared `resources`. The timeline is built from the probe's route trace (`tools/content_suite/apps/event_player.gd:1444`), and the route probe never puts library runner rows into that trace: `_collect_library` appends them to the signature rows (`content_core/mes_route_probe.gd:106-112`, `:430-481`, `:535-542`), and the timeline maps only `voice_marker`, `bgm_request` and `mmo_resource_marker` (`content_core/event_presentation_timeline.gd:242-252`). So routine 27's pictures and routine 9's sound effects are never presented. The compared names stay **15,011, 0 undeclared**, as on 2026-10-08, and gate 2 stays at 184 registered misses (70 picture and 114 animation-source), 0 unregistered (the C5 pre-run `analysis/_undoc/td56/c5/prerun_report.json`, 22/22; the closing batch's 20 shards sum to the same over 681 runs, with voices 8,621, BGM 1,801 and **sound effects 0**). **The 1,093 restored library items are verified by the projector's join, by the independent re-join (681 of 681 documents) and by the tracked-set validator against the package inventory, not by playback.** This is not a regression: it was invisible before TD-56, because the selector-0 `BLACK.MMO` arm was not presented either. Opened as **EP-14** (`todo/event_player.md`, unscheduled, for the owner).
  - **Cross-repository note (no action here).** The package's records do not change, but the remake's copied runner keeps the old argument ABI until it adopts the rule; its adoption is its own backlog. `analysis/replays_v2` (machine-local) is pre-TD-56 and is read only by the frozen v4-v6 producers.
  - **TD-55 closed inside TD-56** (below, with the pointer to C1).
  - **Documents updated** (with the commits that changed behaviour or a contract): `docs/spec/mes/format_and_method.md` (the rule, the `0x0A` correction, the TD-56 section), `docs/spec/mes/audio.md`, `docs/spec/mes/media_references.md` (the re-measured counts), `docs/spec/data/event_definition_v4.md` (the effect rules) and `event_definition_v7.md`, `docs/spec/data/workspace_playback_export.md` (a section for exports A and B), `docs/spec/tech/event_player.md` (18,113 items), `config/event_definitions/v7/README.md` and `v6/README.md`, and `docs/spec/data/validation_checks.md` (the closing proof).
  - **The closing batch** (`analysis/_undoc/td56/c6/closing.json`). The whole `full` tier, uncached with `--cache-store` (the Core changed), `--jobs 6`, `--elfimage --exe --godot`, detached, solo, on the committed tree `210162c4` (Core 0.377.0), the sampler at 10 s. Idle, the sampler's first rows: 44.0% RAM and 43.1% commit, inside the ~50% guard. **477 checks, 477 passed, 0 failed, 2,742.9 s** (run `bcd678df`, `cached: 0`) and **10,277.9 check-seconds**. TD-64 part 2's batch (`72b516cc`) took 2,452.2 s and 10,874.6, so **the check-seconds fell by 596.7 s and the wall time rose by 290.7 s** (below).
    - *The shards.* `shard plan: 1/2, 114 member(s), 1240.140s known, 0 unknown` and `process: original event analysis groups [1/2] completed in 1658.875s (114 member(s), timeout 8000s)`; `shard plan: 2/2, 113 member(s), 1239.696s known, 0 unknown` and `... [2/2] completed in 1694.438s`. About 0.21 of the 8,000 s timeout; the members' own durations sum 2,275.4 s (2,479.8 s in `72b516cc`).
    - *The starts* (offsets from the runner's start):

      | Check | Start | Duration |
      |---|---|---|
      | The full handoff equivalence (weight 4) and the two shards | +7 s | 579.2 s (equivalence); 1,658.9 s and 1,694.4 s (shards) |
      | The transfer-direction corpus | +587 s | 839.3 s |
      | **The Python regression suite (weight 4)** | **+1,426 s** | 246.3 s |
      | The analyzer handoff corpus | +1,666 s | 931.8 s |
      | `original playback package export` and `original playback package playback` | +1,672 s | 317.8 s and 628.9 s |

    - *Memory:* the batch's **peak RAM 79.1% and commit 61.9%**; the pre-pass window 77.1% / 60.9%; **no sample row with page-ins over 1,000/s**.
    - *Results:* the export check printed `package_sha256=0e47e063...` (681 events from 869 member entries), the live package, and the playback check `4749 checks over 681 catalog events`, its count unchanged.
    - *The slowest checks as fractions of their timeouts:* `original Audio Editor original integration` 125.7 s of 300 (0.42), the export 317.8 s of 900 (0.35), the transfer-direction corpus 839.3 s of 2,400 (0.35), playback 628.9 s of 1,800 (0.35), the analyzer handoff corpus 931.8 s of 3,000 (0.31). **None passed 0.5.** The 20 group-route shards took 64.5-116.8 s each; their summed gate 3 (15,011 names compared over 681 runs, 0 undeclared) and gate 2 (184 registered misses, 0 unregistered) read as in the C5 pre-run.
    - **The wall time (advisor's analysis).** The extra ~290 s is TD-65's idling trade, triggered by an ordering tie. The run's report path was new, so `_order_checks_for_run` read the cache's durations only. The transfer-direction corpus (945.5 s, from `72b516cc`) took the ordering key 945.5. The Python regression suite (236.33 s, from a local-tier run on 2026-10-10 at 10:53) took its duration x 4 slots, 945.3. D9 therefore ordered `equivalence, shard, shard, transfer corpus, suite, handoff corpus, ...`. At +586 s the equivalence freed four slots; the head, the transfer corpus, took one; the new head, the suite (four slots, three free), could not fit, and strict FIFO let nothing behind it start. **Three slots idled for 839 s, 2,517 slot-seconds**, until the transfer corpus ended at +1,426 s. In `72b516cc` the suite's key (255.3 x 4 = 1,021) led, so no slot idled. The effect is deterministic given the cache state; TD-65's bound "D9's order keeps the idling small" fails whenever a long single-slot check's key lands within noise of a weight-4 check's. **TD-56 has no wall-time stop**, and the cause is recorded as **TD-67** (above).
    - Then `--cached --jobs 6` on the same tree: **477 of 477, all cached, 8.8 s** (run `e60a071d`, `closing_cached.json`).
    - Reports (machine-local): `analysis/_undoc/td56/c6/closing.json` and `closing_cached.json`; the log `analysis/_undoc/detached/20261011T001346Z_td56-closing-full-jobs6.log`; the sampler `closing_mem.csv` and `closing_mem_procs.csv`.
  - **Left open (as of that closing):** **EP-14** (`todo/event_player.md`: the Playback timeline presented no library-executed media; closed 2026-10-11, Core 0.378.0); **TD-67** (the gate's idling on an ordering tie; closed 2026-10-11 with WD-10); the two stale `0x0A` documentation claims (TD-66); and the decisions the unit named and did not take: the EVENTB03 adapter's retirement with its audits' re-pin, command `0x16`'s storage, and the reference index's write row for `0x09`. The remake's adoption of the rule is its own backlog.

- [x] **TD-55 - The route probe labels a DEF invoked from a library routine as library rows.**
  **Closed 2026-10-11 inside TD-56** (C1 `f5e61701`, Core 0.377.0; closed with TD-56's closing batch, run `bcd678df`, 477 of 477; the record is under TD-56 above). Found 2026-10-08 (WD-21 U2 C1, `analysis/_undoc/wd21_u2/c1_report.json`): when a `LIBLARY.LIB`
  routine invokes a registered DEF definition, `content_core/mes_library_runner.gd` (~297-344)
  appends the DEF's rows to the library trace and `content_core/mes_route_probe.gd`
  `_collect_library` (~555-562) keys them `LIBLARY.LIB:<routine>` although their `at` is
  `DEF_MAIN.MES`-relative; the `definition` field it adds reads `registered_definition_id`
  (~561), which nothing sets (the raw rows carry `external_definition_id`). 4,752 of 34,413
  library-labelled rows in the C1 sample (144 invocations). Nothing consumes the label today
  beyond the signature; WD-21 U2 re-keys the rows tool-side (spec R1, an order rule with a
  structural basis and two fail-closed guards). **Not fixed:** the one-token fix moves `rows` and
  so the signature measured output records as `trace_sha256`
  (`tools/content_suite/event_analysis_group_validation.gd` ~235, ~667) and the B03 audits pin
  (`tools/content_suite/cli/audit_eventb03_*.gd`) - a Core bump plus a regeneration of the
  analysis-group evidence. Unscheduled.
  **Fixed in TD-56 C1 (Core 0.377.0, 2026-10-10):** `_collect_library` keys a row that bears
  `external_definition_id` by its own entry (`DEF_MAIN.MES:<id>`, DEF-relative `at`) and reads the
  definition id from that field; `tools/content_suite/replay_run_media.gd` accepts both labellings under
  its two fail-closed guards. Closed with the unit's closing batch (run `bcd678df`). **The fix moved no replay:**
  C2 showed that reverting it alone regenerates the 161 route replays byte-identically, because `replay_run_media.gd`'s tool-level
  re-key already covered them. It shows only in the validator's row signatures, which no tracked file pins apart from the B03
  audits that C1 re-pinned.

- [x] **TD-54 - Three contextual-authoring checks sit at 0.39-0.49 of their 600 s timeouts in a loaded batch.**
  Closed 2026-10-07 (WD-21 U1 C5, owner ruling; commit `cdd5b5f`). Found 2026-10-07 (WD-21 U1 C3.5 pre-run, `analysis/_undoc/wd21_u1/c35_report.json`, run `0dd818e6`):
  the three `contextual authoring` checks that publish a workspace export through `build()` took, loaded, **290.8 s for
  `original relocated message contextual authoring` (0.485 of 600), 267.1 s for `original edited event contextual authoring` (0.445) and 233.5 s for
  `original resource contextual authoring` (0.389)**, against 245.9, 221.3 and 220.4 s in the TD-52 closing batch. WD-21 U1 adds about 8-10 s per
  `build()` (the whole-archive hashing of the seven media archives, `KakyuPlaybackMediaIdentity`); the rest is batch noise. The advisor estimated a
  55-65% risk that one of them passes 0.5 in the loaded closing batch, which would fail the unit's own acceptance (a check at half its timeout is a
  stop condition). **Ruling (owner, 2026-10-07):** the three move from `"tier": "archive_quick"` at `"timeout": 600` to `"tier": "full"` at
  `"timeout": 900` in `config/validation/checks_v1.json` - the TD-50 form, because `test_tier_ordering` caps every `archive_quick` check at 600 s, so a
  larger timeout means the larger tier. 900 s satisfies TD-46's rule (a timeout of at least twice the loaded duration) up to a loaded duration of 450 s
  (1.5 times today's slowest, 290.8 s). **The cost the owner accepted:** `--tier archive_quick` iteration no longer runs these three
  (`original sequence contextual authoring` was already `full`, 1,200 s, and is unchanged). Nothing pinned the three to the quick tier or to 600 s
  (`tests/test_validation_registry.py` and `tests/test_run_headless_validation.py` pass unchanged: 40 and 60 tests); the registry's `revision` is
  unchanged (a value change, not a shape change). `docs/spec/data/validation_checks.md` carries the tier row and the TD-54 paragraph. **Confirmed by the closing
  batch of WD-21 U1 (C5, run `7513c6ad`, 475 of 475 in 5,253.6 s):** `original edited event contextual authoring` 221.8 s (0.25 of 900),
  `original relocated message contextual authoring` 242.5 s (0.27) and `original resource contextual authoring` 231.0 s (0.26), no check of the run past 0.45.

- [x] **TD-53 - The validation cache does not fingerprint `bgm.arc`, `tina1.arc` or `tina2.arc`.**
  Closed 2026-10-07 (WD-21 U1 closing batch; the closing record is the last sub-bullet below).
  Found 2026-10-06 (WD-21 U1 C3, read-only `--fingerprint-inputs` query):
  `tools/content_suite/validation_inputs.py` `_ARCHIVE_CONTEXT_NAMES` (~93) is
  `mes_arc, mmo_arc, data_arc, voice_arc, se_arc`, and the runner's placeholder
  context (`run_headless_validation.py` `_registry_placeholder_context`, ~600-615)
  defines no `bgm_arc`, `tina1_arc` or `tina2_arc`. So a check that receives
  `{source_root}` has only those five archives in its input fingerprint, and a
  `--cached` run would not notice a change of the other three. Among the checks
  that read them, the group-routes playback pass has done so for longer (the
  defect predates WD-21); since WD-21 U1 C2a the playback package export also
  opens and pins all seven media archives in `build()`; others are the Audio
  Editor original integration, `original content set`, the ARC and audio corpus
  checks, the unreferenced-entries audit and the station/Mahoko plan
  validators. Fix: add the three archives to
  the context and the closure's archive names. It changes every `{source_root}`
  check's fingerprint, so it needs an uncached whole batch - scheduled inside
  WD-21 U1 after C3 and before C3.5, whose closing batch (C5) is uncached anyway
  because Core moved.
  - **Fix landed 2026-10-06 (`b67e65c`, `TD-53: fingerprint bgm.arc and the Tina banks in the validation cache`; the checkbox stays open).**
    `run_headless_validation.py` `_registry_placeholder_context()` now puts `bgm_arc`, `tina1_arc` and `tina2_arc` into the context beside
    `voice_arc`/`se_arc`, and `validation_inputs.py` `_ARCHIVE_CONTEXT_NAMES` lists all eight, so a `{source_root}` check's input set holds
    eight archives. The three stay **context only**: not added to `KNOWN_CHECK_PLACEHOLDERS`/`PLACEHOLDER_REQUIREMENT` (that set is pinned to the
    placeholders the registry uses and each of its members needs a `requires` condition, a registry vocabulary change no command needs) and not
    required - `check_inputs()` skips a name whose file is absent, exactly as for `voice.arc`/`se.arc`, so a root without them still plans and
    fingerprints. **Method:** an external archive is fingerprinted by its full SHA-256 over the whole file (`Path.read_bytes()`), memoized per
    process run (`external_memo`) and never persisted, so each `--cached`/`--cache-store`/`--fingerprints` run reads each archive once. **Cost,
    measured warm on this machine (`analysis/_undoc/td53/`):** the three added archives are 556,488,106 bytes (`bgm.arc` 493,788,716 +
    `tina1.arc` 32,439,192 + `tina2.arc` 30,260,198) and hash in 0.42 s (about 1.3 GB/s); all eight are 1,547,787,713 bytes in 1.17 s; a whole
    `--fingerprints` pass over the 475 checks of the `full` tier took 5.34 s before and 5.72-5.78 s after (three runs). A cold read is not
    measured (the files were in the page cache); the peak transient allocation is one archive (`read_bytes()`), `voice.arc`'s 521 MB, so the
    added archives do not raise it. **Tests:** `tests/test_validation_inputs.py` (26 tests) and `tests/test_run_headless_validation.py` (60,
    the new `ArchiveInputFingerprintTests`) assert the eight-archive input set of a `{source_root}` check, the fingerprint change per archive,
    the optional/absent behaviour and that the runner's context names equal the library's; they fail on `12ec4c5` (a clean worktree of it) and
    pass now. **Query:** `--fingerprint-inputs` for `original playback package export` and `original catalog group routes [1/20]` and
    `[20/20]` list `bgm_arc`, `data_arc`, `mes_arc`, `mmo_arc`, `se_arc`, `tina1_arc`, `tina2_arc`, `voice_arc` (before: five).
    **Verification:** `--tier local --cached --jobs 6` (run `8d8e24c6`; the runner moved every fingerprint, so nothing was served from the
    cache): 138 of 138 passed in 267.7 s, `cached: 0`, the Python regression 2,180 tests. **This item closes with the WD-21 U1 closing batch
    (C5)** - the uncached whole `--jobs 6 --cache-store` batch that re-seeds every fingerprint; until it runs, the cache holds no entry
    that includes the three archives and the next `--cached` whole run re-runs every `{source_root}` check.
  - **Follow-up 2026-10-06 (advisor review of `b67e65c`): one check read archives its command did not name.**
    `original ARC Browser original integration` (`archive_quick`) took `{mes_arc}` only, but
    `tools/content_suite/validators/validate_arc_browser_original.gd` derived the root with `get_base_dir()` and its WD-16 large-ARC block
    opened `voice.arc` and `bgm.arc` beside it, so its input set was `mes_arc` alone and a change of `bgm.arc` or `voice.arc` kept a
    cached pass. The registry entry now passes `{source_root}` and the script takes `mes.arc` from that root with `path_join`
    (`validate_audio_arc_editor_original.gd` does the same); the usage string is `<ELFIMAGE>`, and the `large_archives=absent` skip is
    unchanged. **Sweep:** every registry check that names a single-archive placeholder was read for a sibling-archive derivation
    (`get_base_dir()`, `.parent`, an `.arc` literal, an `ELFIMAGE` path): none besides this one (the two analyzers that call
    `get_base_dir()` on their output path do so only to refuse writing beside the source). `docs/spec/data/validation_checks.md` now states
    the rule - a check's external inputs are the archives its command names, or all eight with `{source_root}`. `checks_v1.json` is a
    baseline input, so this moves every fingerprint again; the closing batch (C5) is uncached anyway.
    **Verification:** `tests/test_run_headless_validation.py` (60), `tests/test_validation_registry.py` (40) and
    `tests/test_validation_inputs.py` (26) pass; `--fingerprint-inputs "original ARC Browser original integration"` now lists `bgm_arc`,
    `data_arc`, `mes_arc`, `mmo_arc`, `se_arc`, `tina1_arc`, `tina2_arc`, `voice_arc` (before: `mes_arc` alone); the check itself
    (`--check`, `--jobs 1`, run `2cda7091`) passes in 25.75 s and its line shows the large-ARC block ran (`large_cancel_removed=304
    large_extract=52 large_peak_mib=29`); the Godot parse check is clean (`analysis/_undoc/td53/followup_*`).
  - **Closed 2026-10-07 (WD-21 U1 closing batch).** The uncached whole `full` tier at `--jobs 6 --cache-store` (run `7513c6ad`, committed tree `dc99e46`,
    Core 0.373.0): **475 of 475 passed in 5,253.6 s**, `cached: 0`, so every `{source_root}` check's fingerprint - now over eight archives - was re-seeded;
    `--fingerprint-inputs` for `original playback package export` and for `original catalog group routes [1/20]` list `bgm_arc`, `data_arc`, `mes_arc`,
    `mmo_arc`, `se_arc`, `tina1_arc`, `tina2_arc` and `voice_arc`. The same command with `--cached` (run `3b0a2572`) served all 475 from the cache in 8.5 s. The hashing
    cost the follow-up measured (0.42 s for the three added archives) is inside the batch noise: the whole-batch wall time was 5,253.6 s against 5,282.4 s in the TD-52
    batch. `docs/spec/data/validation_checks.md` carries the closing record.

- [x] **TD-52 - `Godot project parse check` passes half of its 120 s timeout in a loaded whole batch.**
  Closed 2026-10-06 (TD-52 unit, `analysis/_docs/td52_spec.md`; closing record below). Found 2026-10-05 (TD-51 closing batch, run `97d1723b`, uncached `--jobs 6`, 473 of 473 passed): the one check of the run past 0.5
  of its timeout, **79.9 s of 120 s (0.67)**. It is the `godot_editor` check of the `local` tier in `config/validation/checks_v1.json`
  (the editor opened headless with `--quit-after 2`; its cache inputs are the `.gd`/`.tscn` files under `content_core/`, `tools/` and
  `tests/` plus `project.godot` - `validation_inputs.py` `EDITOR_TREE_ROOTS` - while the editor's first scan walks every non-ignored
  directory under the project root, tracked or not, so the scanned tree can grow with the cache fingerprint unchanged and a cached pass
  carries no signal about it), and TD-46's rule (a timeout of at least twice the duration in a loaded whole batch) asks for 160 s or more.
  Its duration in the uncached whole batches at `--jobs 6` since TD-40, oldest first: 23.9 s (`5351ac5c`), 23.6 (`ebedba7f`), 30.7
  (`e280b8c4`), 35.2 (`eab1a1e1`), 30.3 (`4f1ae99f`), 40.8 (`2395516c`), 44.6 (`375b8653`), 42.1 (`4194a2d8`, a batch in which one other
  check failed) and then 79.9 here, so 0.20 to 0.37 of 120 s before this batch. The batches `5865c21a` and `f02e7da7` served the check
  from the cache, so they carry no duration of their own; the cached row comes from the local-tier run `f79b1aa8`, where it took **67.8 s of
  120 (0.57)**, and the local-tier run `6556d3db` (EP-12 TALK rest) took 59.4 s (0.49), so the 0.67 is the highest of three recorded
  readings above 0.45 and not an isolated one (reports under `analysis/_undoc/ep12_talk_followups/` and `ep12_talk_rest/`). The same
  check also **timed out once at 120 s in the TD-51 unit's A2 `--tier local --jobs 6` run**; that run was not recorded in a report (the
  same gap TD-51 states), so the miss has no run id of its own; the uncached local-tier run that followed it in the same window,
  `d27a6a21` (its rows survive only in the validation cache), passed the check in 53.5 s (0.45). No profile was taken and no run of the
  check alone was measured in this unit. **Advisor diagnosis, 2026-10-05 (read-only; the cause is inferred, not profiled): growth of the
  scanned tree, with load as a multiplier.** The check's whole output is the editor's `first_scan_filesystem`, then the quit aborts the
  threaded scan, so the editor's filesystem cache never completes and every run re-walks the tree; the untracked `analysis/` (22,393
  files, no `.gdignore`) is about 87% of what that scan walks, and the editor has written `.gd.uid` sidecars and CSV imports into it.
  Across four uncached whole batches (`4f1ae99f`, `2395516c`, `375b8653`, `97d1723b`) the check's duration tracked the size of `analysis/`
  (about 12.1k, 15.0k, 18.0k and 22.2k files -> 30.3, 40.8, 44.6 and 79.9 s) while the tracked tree went 3,007 -> 3,155 files and did not change at all between the
  last two; `analysis/` grew by 4.6k-12.3k files a day on 2026-10-03..05. Nothing on the Godot side loads `analysis/` through the editor
  filesystem (the one `res://analysis` use, `validate_event_analysis_groups.gd`, globalizes it to an OS path). Nothing in the TD-51 unit
  changed GDScript or the registry's parse-check entry. Options for a ruling: leave the timeout at 120 s (the check passed in every
  recorded run; the one miss is an unrecorded transient - but the diagnosis says the duration keeps growing); raise it by TD-46's rule
  (160 s is the minimum, 240 s is three times today's loaded duration; a registry edit with no `revision` bump, and no test pins this
  check's 120 s - `test_tier_ordering` caps only `archive_quick` checks; at 2.5-3.6 ms per scanned file the rule is crossed again near
  33k files); measure the check alone (`--check "Godot project parse check"`, `--jobs 1`) first to separate load from growth; or reduce
  what the scan walks: **the advisor's recommendation** is a tool decision in which the runner writes an empty `analysis/.gdignore`
  (only when `analysis/` exists and the marker is absent, before any check runs), as `tools/build_windows_distribution.py` does for a
  staged tree, with the timeout left at 120 s; a tracked marker instead would need `.gitignore` and AGENTS.md "Assets" changed (an owner
  rule). Either change to the runner or registry needs an uncached `--cache-store` closing batch. Not changed here: the TD-51 unit's
  stop condition is to report a check past 0.5 of its timeout, not to change it.
  **Fixed 2026-10-06 (TD-52 unit, `analysis/_docs/td52_spec.md`, checkpoint A; owner ruling: option (a), the timeout stays 120 s).**
  `tools/content_suite/run_headless_validation.py` `ensure_editor_ignore()` (a tool decision) writes an empty `analysis/.gdignore`; `main()` calls it at the
  point the cache directory is resolved, so it precedes both `run_checks()` and `run_checks_scheduled()` in every tier. It writes only when `analysis/`
  exists and the marker is absent (an exclusive create: it never makes the directory, never rewrites a marker, and two racing runs cannot clobber each
  other); any other `OSError` from the create (a read-only or ACL-restricted `analysis/`) is treated as "not written" and the batch runs as before TD-52, because the
  marker only saves scan time (review finding of 2026-10-06; the call in `main()` sits outside the configuration `try`). `tools/build_windows_distribution.py` keeps its own `runtime/.gdignore` write unchanged and the two are not shared: the builder's is an
  unconditional create that fails closed (`open("x")` raises) on a staged tree it has just made, the runner's is an idempotent ensure that skips an
  absent directory or an existing marker; sharing would either weaken the builder's failure or give a helper whose only content is the policy flag, and
  the runner (`tools/content_suite/`) imports nothing from `tools/` today, so a shared home (`payload_values.py`, `windows_distribution_common.py`)
  would add a `sys.path` entry for one `open` call. `tests/test_run_headless_validation.py` pins the helper (creates the marker; does nothing for an
  absent directory; leaves an existing marker's bytes and mtime; returns False with no file when the create raises `PermissionError`) and `main()` (called with the project's `analysis` before the first check, `--jobs 1` and
  `--jobs 2`), and patches the helper in the three classes that run `main()` against the real project root, so the suite never writes into the
  checkout (56 tests, +5). Stop condition checked: no GDScript, scene or test loads `res://analysis/` through the editor filesystem
  (`--script res://analysis/...` still runs under the marker, probed).
  **Measured** (22,395 files in `analysis/`, `--check "Godot project parse check" --jobs 1`, nothing else running, reports under `analysis/_undoc/td52/`):
  without the marker **40.3 s and 38.6 s** (the first scan alone; the closing batch's 79.9 s read about twice that under `--jobs 6` load), with it
  **6.5 s (0.05 of 120 s)**, the output still the editor's `first_scan_filesystem` and `--- PASSED` (read on the console; a passed row records no output tail, so the reports do not show it); the editor still re-walks the tracked tree every run (the quit
  still aborts its scan), so the floor is the tracked tree's size, not zero. The uncached `--tier local --jobs 6 --cache-store` run `f1676b1e` (the
  runner changed, so nothing was cached): 136 of 136 passed in 269.6 s and the check took **7.95 s (0.07)**, against 53.5-67.8 s in the earlier local-tier runs.
  **Closing proof (2026-10-06, Core 0.372.0 unchanged, no contract or analyzer change; checkpoint B, committed tree `ebd440a`: the fix `274fd97` plus
  the review fixes `5209dcd`, `56c10ce`, `6097dd2`, `ebd440a`):** the whole `full` tier at `--jobs 6` with `--elfimage`, `--exe` and `--godot`, uncached with
  `--cache-store` (the runner changed, and it is an input of every check), detached through `launch_detached.py` (marker `20261005T205804Z_td52-full-jobs6`,
  run `a171a199`): **473 checks, 473 passed, 0 failed, `cached: 0`, 5,282.4 s**. **`Godot project parse check`: 8.86 s of 120 s (0.07)** in the loaded run,
  against 79.9 s (0.67) in the TD-51 closing batch `97d1723b`, so the acceptance bound of 60 s (0.5) holds with a ninth of the old reading; the other
  readings of this unit: solo 40.3 and 38.6 s before the marker and 6.5 s after, the local-tier run `f1676b1e` 7.95 s. The detached log's block for the
  check shows the editor's `first_scan_filesystem` through `DONE` and `--- PASSED (8.860s) ---` (a console reading; a passed row stores no output tail).
  **The runner writes the marker:** `analysis/.gdignore` was deleted before the launch and was there again after the run, its modification time
  (2026-10-05 20:58:04Z) 0.5 s after the process start recorded in the launch's own record (20:58:04.28Z), so what is present is the runner's file and not an
  earlier one; it is untracked (`/analysis/` is in `.gitignore`). **The analysis-group process** read `process: original event analysis groups completed in
  3664.250s (227 member(s), timeout 8000s)`: **3,664.3 s, 0.46 of its 8,000 s** (2.18 times its loaded duration against TD-46's 2), under TD-51's 4,000 s
  re-application trigger (0.92 of it; 3,614.5 s in `97d1723b`, 49.7 s less), so the raise of TD-51 stands and nothing is re-applied. **Slowest checks, as ratios of
  their timeouts:** the transfer-direction corpus 1,015.5 s of 2,400 (0.42), `original relocated message contextual authoring` 245.9 of 600 (0.41),
  `original edited event contextual authoring` 221.3 and `original resource contextual authoring` 220.4 of 600 (0.37), the playback package playback 621.4 of 1,800 (0.35), the playback package export 306.2
  of 900 (0.34), the analyzer handoff corpus 1,012.6 of 3,000 (0.34) and the 20 group-route shards 623-919 s of 3,000 (0.31 at most); **no check passed 0.5 of
  its timeout** (the highest is 0.42), where the TD-51 batch had one. Then `--cached --jobs 6` with the same arguments (run `0a056ef6`): **473 of 473 passed, all
  473 cached, 7.7 s**. Reports kept under `analysis/_undoc/td52/` (`closing.json`, `closing_cached.json`, `local.json`, `solo_before.json`,
  `solo_before2.json`, `solo_after.json`); the detached run's console log is the record of the check's output.

- [x] **TD-51 - The analysis-group process sits at its 3,600 s timeout in a loaded whole batch.**
  Closed 2026-10-05 (TD-51 unit, `analysis/_docs/td51_spec.md`; closing record below). Found 2026-10-05 (EP-12 TALK follow-ups, closing proof on `faa917f`, run `5865c21a`, `--cached --jobs 6` with every
  archive and full check re-run): the one process check of the `analysis_group` family
  (`families.analysis_group.process_timeout` in `config/validation/checks_v1.json`, 227 members, 2,447 s of group time summed over the
  219 groups it finished) **timed out at 3,600 s with eight groups left** (the last, `27c_ev_l_talk`, was running), so its 227 members
  failed and the other 246 checks passed. The same command re-run with only the process left (`--cached`, run `f02e7da7`, the 246 passes
  served from the cache) passed 473 of 473: the 227 groups summed 2,172 s and the process took 3,084 s alone (about 900 s of it outside the
  groups' own durations). The previous whole batch (`375b8653`, 2,387 s of group time, so about 3,300 s of wall time at the same overhead - the
  process's own wall time is not in the report) passed under the same timeout: the family has never met TD-46's rule (a timeout of at least twice the
  loaded duration). This run was slower per group (the 58 groups of its log tail ran a median 1.05 times their durations of the previous batch, the
  group-route shards 620-976 s against 599-867 s), which was enough to cross it. Not caused by the unit (its one changed group validated in 15 s); no
  profile or check of the unit is involved. Options for a ruling: raise `process_timeout` to 7,200 s (twice a loaded duration of about 3,600 s;
  `tests/test_validation_registry.py` does not pin it), or split the family into shards like `catalog group routes` (TD-33 part 2) so a
  growing family does not grow one process; each new group adds 15-60 s. Not changed here.
  **Fix 2026-10-05 (advisor ruling: raise, do not shard; unit `analysis/_docs/td51_spec.md`):**
  `families.analysis_group.process_timeout` **3,600 -> 8,000 s**. Sizing by TD-46's rule against a loaded process of about
  3,750 s (the 3,600 s elapsed plus the eight unfinished groups, about 130 s loaded, plus the end hash): twice that is 7,500 s,
  7,200 s is 1.92 times and fails the rule, 8,000 s is 2.13 times and keeps it up to a 4,000 s loaded process. Sharding was not
  chosen: the whole batch is slot-floor-bound (about 27,600 slot-seconds over six slots, a floor near 4,600 s against 4,973 s
  measured), the process starts at +5 s (TD-42) and ends well inside the batch, the members are already fingerprinted
  individually (`collapse_families` runs over the cache misses only), so shards would gain no cache granularity and each would
  repeat the process's roughly 900 s of overhead. **Re-apply when the loaded process passes 4,000 s; the fallback is sharding,
  when it approaches the batch's slot floor** (about 4,600 s today), where one indivisible block becomes the critical path. The
  runner now prints one `process: <check> <completed|timeout|error> in <s>s (<n> member(s), timeout <t>s)` line after the member
  lines (`_run_process_check`), so the loaded duration is visible rather than derivable only from a timeout; no report schema
  change; `tests/test_run_headless_validation.py` pins the three outcomes. No registry `revision` bump (a value, not a vocabulary
  change; TD-50 changed a timeout the same way). `docs/spec/data/validation_checks.md`, "The analysis-group family". The A2 commit
  recorded the unit tests only: the `--tier local` run the unit asked for there ran but was not recorded in a report (the parse check
  timed out once in it, TD-52), and the closing batch (the whole `full` tier, uncached) covers every check it ran.
  **Closing proof (2026-10-05, Core 0.372.0 unchanged, no contract or analyzer change, committed tree `ce65d78`: the fix `eb8b09e` plus
  the review fixes):** the whole `full` tier at `--jobs 6` with `--elfimage` and `--exe`, uncached with `--cache-store` (the registry
  and the runner, inputs of every check, changed), detached through `launch_detached.py` (run `97d1723b`): **473 checks, 473 passed, 0
  failed, `cached: 0`, 5,177.3 s**. The runner's new line in the log read `process: original event analysis groups completed in
  3614.516s (227 member(s), timeout 8000s)`: **3,614.5 s, 0.45 of its 8,000 s** (2.21 times its loaded duration against TD-46's 2; the
  estimate before the fix was about 3,750 s), so the acceptance bound of 4,000 s or less holds (0.90 of it) and **the process would have
  run past the old 3,600 s timeout** by 14.5 s: the raise was needed, not merely a margin. The 227 members' own durations sum 2,425 s (the
  longest, `original event analysis 01M J talk`, 56.4 s), so about 1,189 s of the process's wall time lies outside them in a loaded run
  (about 910 s in the solo run of `f02e7da7`). Among the slowest checks, as ratios of their timeouts: the transfer-direction corpus 1,117 s of
  2,400 (0.47), `original relocated message contextual authoring` 228 of 600 (0.38), the analyzer handoff corpus 1,119 of 3,000 (0.37),
  the resource and edited-event contextual authoring 206 and 205 of 600 (0.34), the 20 group-route shards 574-986 s of 3,000 (0.33 at
  most), the playback package playback 557 of 1,800 (0.31), the playback package export 274 of 900 (0.30), and the four TD-46 checks 0.21-0.25. **One check passed 0.5 of its timeout:
  `Godot project parse check`, 79.9 s of 120 s (0.67), reported here and not changed (TD-52, opened).** Then `--cached --jobs 6` with the
  same arguments (run `6527acea`): **473 of 473 passed, all 473 cached, 7.7 s**. Reports kept under `analysis/_undoc/td51/`
  (`closing.json`, `closing_cached.json`). **Re-apply when the loaded process passes 4,000 s** (TD-46's rule, 2 times 4,000 s, is 8,000 s
  exactly); **the fallback is sharding, when it approaches the batch's slot floor** (about 4,600 s at `--jobs 6`).

- [x] **TD-50 - `original playback package export` passes half of its quick-tier timeout in a loaded run.**
  Closed 2026-10-05 (EP-12 TALK follow-ups, advisor ruling). Found 2026-10-05 (EP-12 TALK rest, run `375b8653`): 326 s of its 600 s
  timeout at `--jobs 6` (0.54; 269 s solo), up from under 0.41 at 576 events; it grows with the package (681 events from 869
  member entries). TD-46's rule asks for at least twice the loaded duration (652 s or more), but `tests/test_validation_registry.py`
  (`test_tier_ordering`) caps every `archive_quick` check at 600 s, so raising it to 900 s in place failed that test (tried and
  reverted 2026-10-05). **Fix:** the tier is defined by the registered timeout (`docs/spec/data/validation_checks.md`: `archive_quick`
  is 600 s or less, `full` is every check above it), so the check moved to the `full` tier at 900 s in
  `config/validation/checks_v1.json` (`tests/test_run_headless_validation.py` pins 900); the quick tier's cap and
  `test_tier_ordering` are unchanged. 900 s satisfies the TD-46 rule up to a loaded duration of 450 s (1.4x today's 326 s); the
  next 100 rows will need the rule re-applied. Verified: the registry and validation-registry tests (90), `--tier local --cached
  --jobs 6` 136 of 136, and the check alone (`--check "original playback package export"`) passed in 268 s of its 900 s (0.30).
  In the whole batch of the same unit (`--jobs 6`, run `5865c21a`) it took 315 s of 900 s (0.35).

- [ ] **TD-49 - Catalog-side tools still assume the EVENT-era shape.**
  Found 2026-10-04 (EP-12 TALK study): `tools/build_event_names.py` caps the
  site ordinal at one digit (`[1-9]`, ~95) and carries hand-edited expected
  counts (~97, ~111); `tools/build_event_analysis_inventory.py` (~179-183) and
  `tools/classify_event_routes.py` accept only an EVENT-only classification
  input. Blocks only per-site rows or a (caller, callee) pair with ten or more
  sites. Unscheduled.

- [ ] **TD-48 - `measure_event_route.gd` hangs (no CPU, no error) on a routine-40 it cannot name.**
  Second occurrence 2026-10-04 (EP-12 TALK study, `K_TALK30` spec); first
  recorded in `docs/spec/mes/promise_groups.md` (~302-316). The wrapper
  `tools/qualify_event_route.py` (~47) kills it at 900 s. The defect is the
  missing fail-fast. Unscheduled - the TALK units use an H-style static
  drafter, not this pair.

- [ ] **TD-47 - The group-routes playback check costs ~23.5 CPU-s per catalog row and re-runs whole on any catalog change.**
  Measured 2026-10-04 (EP-12 H closing run `4f1ae99f`): the 20 shards of
  `original catalog group routes` summed 13,350 CPU-s over 567 rows; any
  catalog change invalidates all 20. Whole-batch wall time went 3,021 ->
  4,251 -> 5,155 s as the catalog grew 214 -> 554 -> 567 rows (the last step
  mostly machine speed). TALK (142 scripts, 4,905 sites) would add +550 s of
  wall time at one row per script and ~32 CPU-hours at one row per site.
  Structural options: a per-row result cache keyed by the row's profile
  `payload_sha256` + Core, or a "changed groups only" replay mode. Not
  scheduled; the TALK spec must consult it when it chooses row granularity.
  2026-10-04: the TALK recommendation (one row per called script, ~114) needs
  no cache - the catalog stops near ~681 rows.
  **2026-10-08, scheduled by the owner's batch speed order (third, after TD-57 and TD-58).** At 681 rows
  the shards took 15,328 s, 62% of the WD-21 U1 closing batch's check-seconds. The agreed design
  separates the expensive part from the cheap part:
  - Cache each row's playback output (the played timeline, messages, terminal match, played media
    names) keyed by everything that can change it: the row minus its `resources`, its profiles'
    `payload_sha256`, the Core version and the playback code closure.
  - Re-run the assertions (gate 2's registry check, gate 3's declared-media check, message and step
    counts) on every row in every run.

  A unit that touches a few rows then replays only those, and the report is still a per-row proof.
  A change that only edits `resources` (WD-21 U2, TD-56) replays nothing. A Core change replays
  everything, as it should. Re-measure the per-row cost after TD-57 before designing the cache
  boundary.
  **2026-10-09, re-measured by TD-57's closing batch:**
  - The 20 shards now take 1,394 check-seconds in all, **about 2.0 s per row** instead of about 20-22.5 s
    (U2 13,473 s, U1 15,328 s over 681 rows), and 63-83 s per shard.
  - The item's premise, that the shards dominate and a catalog change costs about 4 CPU-hours, no longer
    holds. Caching every row would now save at most about 23 minutes of CPU per catalog change, and no wall
    time while the analysis-group process is the floor (TD-58).
  - Re-assessment is due before it is built: close it as not worth its complexity, or keep it for a later
    catalog much larger than 681 rows. That is the owner's call when its turn in the order comes.
  - **2026-10-09, owner ruling: on demand.** Kept open but out of the speed order. It is built only if
    the batch's speed gets in the way of the work (the order paragraph under "Open Work").

- [x] **TD-46 - Four archive-tier checks sit at 0.43-0.49 of their small timeouts solo, and past 0.5 under a loaded batch.**
  Closed 2026-10-04 (EP-12 TALK K, checkpoint A). Found 2026-10-04 (EP-12 H closing proof, run `4f1ae99f`, 445 of 445
  passed in 5,155 s at `--jobs 6`, about 14% slower per check than the previous whole batch). `original dispatch
  naming beyond the strict decode` (191 s of its 300 s: 0.64), `original playback op profile`
  (163 s of 300: 0.54), `original event corpus literal dispatch inventory` (157 s of 300:
  0.52) and `original Event Catalog source bindings` (60 s of 120: 0.50) exceeded the 0.5
  bound the unit set; run alone at `--jobs 1` they take 146 s, 148 s, 143 s and 52 s (0.49,
  0.49, 0.48, 0.43). None runs code the recollection unit changed (the last reads the catalog,
  13 rows larger), and the margin was already thin before it (135, 140, 150 and 41 s in the
  previous whole batch). **Fix:** the timeouts are 600/600/600/240 s in
  `config/validation/checks_v1.json`, and the rule is recorded
  (`docs/spec/tech/content_tools.md`, "EP-12 TALK tools"): **a check's timeout is at least twice its
  duration in a loaded whole-batch run (`--jobs 6`)**, not twice its solo duration. **Confirmed** by the uncached
  whole batch of checkpoint B (447 of 447 in 4,538 s, run `2395516c`): the four checks took 158, 159, 161 and 50 s of
  600/600/600/240 s (0.26, 0.27, 0.27, 0.21), and no check of the run passed 0.41 of its timeout. **Applied again 2026-10-05
  (EP-12 TALK rest, Core 0.372.0, run `375b8653`, 473 of 473 in 5,156 s):** the four checks took 142, 154, 144 and 53 s (0.22-0.26);
  the one check over 0.5 is another (`original playback package export`, TD-50).

- [ ] **TD-45 - Python tools write CRLF on Windows, so a fresh working tree misses the validation cache.**
  Found 2026-10-04 (EP-12 all menus): `tools/build_event_flow_profile.py:200`
  (and the other `write_text` calls in `tools/*.py`, none passing `newline=`)
  writes CRLF on Windows. Tracked content is safe - profile and
  classification hashes are over canonical JSON (`tools/payload_values.py`)
  and `.gitattributes` normalizes to LF on commit - but
  `tools/content_suite/validation_inputs.py` hashes raw bytes, so a CRLF
  working tree misses a cache an LF tree filled (the unit normalized its
  files by hand). Fix: write tracked text through one shared helper with
  `newline="
"`. Unscheduled.

- [ ] **TD-44 - The runner orders a check with a new shard name last.**
  Found 2026-10-04 (EP-12 all menus, group routes 4 -> 20 shards):
  `tools/content_suite/run_headless_validation.py` (~1494-1503) gives a name
  with no recorded duration 0, so new `<name> [K/N]` shards sort last; the
  unit seeded the order by planting a report at the `--report` path. Fix: for
  an unknown `<name> [K/N]`, use the mean of recorded siblings `<name> [k/M]`
  scaled by M/N, else the unsharded record / N. Unscheduled; matters on the
  next shard re-size.

- [x] **TD-43 - The v6 date flow documents' first `unresolved` line is heroine A's guard text.**
  Closed 2026-10-04 (EP-12 H unit, checkpoint A: `flow_done_flag_line` in
  `tools/project_event_definition_v6.py` spells the line from the guard conjuncts the
  producer already reads, tests in `tests/test_project_event_definition_v6_gallery.py`;
  the 35 date documents' changed first line is an expected diff of checkpoint B's
  regeneration, which also covers the 13 new recollection documents). Found 2026-10-04 (EP-12 v14 variant fields unit; the gallery branch of
  `tools/project_event_definition_v6.py:build_flow_document` replaced the line
  for album scenes and showed the other branch's constant). For every
  non-gallery flow the producer writes one fixed first `unresolved` line,
  "no done flag identified in the guard: the flow's own origin guard
  (banked_u16[215] promise day, clock >= [216], global_u8[110]==1, [117]==2,
  place [119] in 9..13) names no cleared completion flag" - the cells of
  heroine A's town-date guard (`docs/spec/mes/a_date_flow.md`). All 35 tracked
  date flow documents (A..L, three routes each, J two) carry it verbatim, so
  B..L's documents name A's cells rather than their own guard's; the 25 album
  documents carry their own text. Pre-existing since the C..L batch
  (2026-09-25), not introduced or changed by the variant unit. Fix, when taken
  up: derive the line from the route's own guard (the `conjuncts` the
  producer already reads from the origin guard) or state only the
  heroine-independent fact; regenerating the 35 documents moves the v6 set, so
  it rides a regeneration unit (the 12-menu unit regenerates it anyway) and
  needs no contract change (`unresolved` is free text). Not scheduled; a
  documents-only truthfulness defect, no product behaviour depends on the line.

- [x] **TD-42 - The longest-first order starts `original event analysis groups` last, so the whole batch idles in its tail.**
  Closed 2026-10-03 (fix `7c50cdd`; measured run `ebedba7f`, 402/402, **3,021 s
  against 3,980 s**, below). Found 2026-10-03 (TD-40 d). The analysis-group process check
  (`families.analysis_group`; its members are the report's rows) has no
  duration under its own name in the report or in the cache, so
  `_order_checks_for_run` gives it 0 and it starts after every check with a
  known duration. In both whole batches (`5351ac5c` at `--jobs 6`, `f20c55b6`
  at `--jobs 5`) it started about 42-44 min in and ran about 24 min (its 173
  members sum to 1,034 s at `--jobs 6` and 1,008 s at `--jobs 5`; the process
  itself is longer, its real wall time ~1,440 s), alone beside a few
  small checks: total CPU 9% for the last ~25 min, parallel efficiency 0.46-0.48
  against 0.83 at `b9fa356`. The batch holds 14,293 slot-seconds (the handoff
  equivalence and the regression suite hold 4 slots each): six slots need at
  least ~2,380 s, so a schedule that started the process first is bounded by
  that floor, not by the measured 3,980 s; the expected gain is 3,980 s ->
  ~2,500-2,700 s (an estimate, not a measurement). Fix (a runner change,
  so it needs an uncached `--cache-store` rerun): order a check that has
  `members` by the sum of its members' recorded durations (report first, else
  cache), test it in `tests/test_validation_scheduler.py`, then re-measure
  `--jobs 4`-`6`; the documented `--jobs` value may move again.
  **Fix landed (part 2):** `_order_checks_for_run`'s `duration_of` gives a
  check with `members` the sum of its members' known durations (each found
  report-first, else cache, as for any check); one test in
  `tests/test_validation_scheduler.py`; no report or cache schema change. The
  member sum (~1,034 s) underestimates the process (~1,440 s), so it sorts
  third by the `--jobs 6` report's durations (second by the cache's `--jobs 5`
  ones, 1,008 s), behind only the two ~1,050 s checks and still in the first
  wave at `--jobs 4`-`6` - enough; the process's own time is not recorded.
  Verified: the scheduler tests (25) and `--tier local` (135/135, 267 s).
  **Measurement** (part 3; tree `7c50cdd`, 6 cores / 12 threads, 15.9 GB;
  `--jobs 6`, uncached with `--cache-store`, detached, sampled every 30 s with
  CPU, RAM, the Godot/Python working sets and `Memory\Pages Input/sec` through
  PDH's English counter name - the counter behind
  `Win32_PerfFormattedData_PerfOS_Memory.PagesInputPersec`; each process's
  creation time was logged for the start order; an idle baseline of five
  samples before the run read 44-47% RAM and 0.7-717 pages/s):

  | Whole batch, tree | `--jobs 6`, `7c50cdd` (`ebedba7f`) | `--jobs 6`, `41ff67a` (`5351ac5c`) |
  |---|---|---|
  | Result | 402/402 passed | 402/402 passed |
  | Wall time | **3,021 s** | 3,980 s |
  | Sum of check time / parallel efficiency | 11,462 s / 0.63 | 10,935 s / 0.46 |
  | Group routes shards 1-4 | 760 / 1,122 / 1,220 / 936 s | 771 / 971 / 1,053 / 753 s |
  | Transfer-direction / analyzer handoff corpus | 1,062 / 1,059 s | 1,021 / 1,037 s |
  | Full handoff equivalence / regression suite | 582 / 228 s | 722 s / not listed |
  | Peak RAM used (of 16,309 MB) | 12,558 MB = **77.0%** | 13,868 MB = 85.0% |
  | Mean RAM / mean CPU / peak CPU | 49.0% / 45% / 69% | 47.7% / 36% / 67% |

  Start order (seconds after the runner started): at +5 s the first wave -
  group routes shards 3, 2 and 4, **the analysis-group process**, the
  transfer-direction corpus and the analyzer handoff corpus (the process,
  whose 173 members sum to 1,189 s in this run, was done by ~1,200 s, no
  longer the last check); shard 1 at +941 s; the contextual authoring and
  audit checks from +1,067 s to +2,331 s; the full handoff equivalence only at
  +2,199 s and the regression suite at +2,782 s. The 24% gain is real but the
  ~2,500-2,700 s estimate was not reached (the floor is ~2,380 s): the two
  weight-4 checks are ordered by duration alone (#8 and #10) and each worker
  thread pops one and then blocks in `_WorkerGate.acquire` until four slots
  are free at once, while single-slot checks keep taking the slots a
  finishing check frees - so by the code those threads sit idle from ~+1,100 s
  (CPU 36-45% instead of ~60%), and the equivalence and the suite then run one
  after the other in the tail (+2,199 s to the end, 822 s, CPU 36%, two slots
  idle). That residue is an **unscheduled speed item, not fixed here**:
  ordering by duration times weight (or a fair gate) would start the 582 s
  equivalence first; its gain is bounded by the ~2,380 s floor (up to ~640 s).
  Memory and paging: the RAM peak is one 30 s sample at 77.0% (+1,457 s) with
  eight Godot processes at 7.4 GB of working set; RAM was above 70% in five
  samples and above 75% in two. Page-ins: median 4.4 pages/s, mean 160, 92 of
  100 samples above 0 (so is the idle baseline); above the baseline's 717
  pages/s in five samples (7,255 at +1,397 s, 2,077, 1,635, 1,243, 843),
  never more than two consecutive and none at the RAM peak - about 1.7 GB of
  reads in all (the counter also counts file reads), transient bursts rather
  than sustained paging.
  **Decision:** the rule's two triggers (peak RAM above 85%, sustained
  page-ins) are not met, so `--jobs 6` stays the documented value and
  `AGENTS.md`, `README.md` and `tools/README.md` are unchanged; the memory
  edge TD-40 d recorded (85.0%) moved to 77.0% once the overlap changed, as
  it expected. `--jobs 5` was not re-measured (not needed by the rule).
  **Closing proof:** `--cached --jobs 6` on the same tree (run `329d4a19`):
  402/402 passed, 402 cached, 5.7 s.

- [x] **TD-41 - The v6 projection batch runs its 189 sites serially (~33 min).**
  Closed 2026-10-03 (`68fa403`). `tools/project_event_definitions_batch.py
  --jobs N` (default 1): `main()` is split into plan / run / assemble. The
  witness preflight, the fingerprint and manifest reads, the shared-line index
  and its write, the dispatch decisions and any Godot catalog replay stay
  serial; each site's producer subprocess and Python validator
  (`validate_event_definition.py`) run on a thread pool; `index.json`, the
  table and the witness summary are assembled in registry-row order. (The
  description above said "a Godot validation each": per-site validation is
  Python, and Godot runs only for a catalog row no analysis group covers, none
  in the v6 set.) **Proof:** `--contract v6 --jobs 4` into a scratch directory
  (witnesses `analysis/witnesses`, package `a4880971...`) printed
  `projected=189 valid=189 invalid=0` and the TD-37 witness line
  (`shift_witness_rows=1718 reentry_probe_documents=46`) in 692 s against ~33
  min serial (2.9x), and all 190 files (189 documents and `index.json`) are
  byte-identical to `config/event_definitions/v6`, as is
  `analysis/shared_lines_v4.json`. `tests/test_project_event_definitions_batch_jobs.py`
  (synthetic registry, no original data) compares a serial and a `--jobs 4`
  run of the real `main()` for v3 and v6 under a scrambled completion order -
  index, table, witness summary and every file identical - plus the failed
  replay, projection and validation slots, pool ordering and exception
  propagation.

- [x] **TD-40 - The whole batch takes 63-77 min; most of it is avoidable.**
  Closed 2026-10-03 for its four parts; the ordering defect that part (d)
  exposed is TD-42. Context: the `b9fa356` whole batch took 4,564 s for 15,195 s
  of check time at `--jobs 4`; the 2,968 s `original Python Phase 1-4 full
  handoff equivalence` started in registry order because the runs used a new
  report path and no `--cache-store`; two runs were lost to agent-session
  exits. Owner ruling 2026-10-03: a unit's closing proof may be a cached whole
  batch (`AGENTS.md`, "Verification"); parallelize the handoff equivalence
  and measure a higher `--jobs`. **(a) `d3aeccc`:** the policy makes every run
  engage the cache, which keeps each passed check's `duration_seconds`, so no
  durations file was added; the defect was `_order_checks_for_run`, where one
  run row in a reused `--report` discarded the whole cache. The sources now
  merge per check (report, else cache, else registry order); three tests in
  `tests/test_validation_scheduler.py`. **(b) `35e3523`:**
  `tools/content_suite/launch_detached.py -- <command...>` starts a command
  through `Win32_Process.Create` (parent `WmiPrvSE`, window hidden, project
  root as working directory, `cmd.exe /c "... > log 2>&1"` built from an
  argument list, no temporary script), writes a marker under
  `analysis/_undoc/detached/` and prints it; `--status` lists markers with
  liveness (pid and creation time), the log's first and last line and
  parentless `*_console.exe`/Python processes mentioning the project. The
  launched process gets WMI's default environment, so the batch is launched
  with `--godot` explicit. Every run below was launched this way. 26 tests
  cover the quoting, command line, marker, stamp, create-output and status
  logic; the WMI call itself is exercised by the runs. **(c) `41ff67a`:**
  `tools/audit_mes_handoff_equivalence.py --jobs N` compares entries on a
  process pool; the parent applies `--limit`, keeps the archive re-hash and
  folds the worker results in digest order (the corpus results are ordered
  folds, so shards would have made each report `scope=partial`); entries
  start largest first, results are collected by digest position. The registry
  entry carries `--jobs {python_jobs}` (weight and slots follow from the
  placeholder; no runner change). **Proof:** the committed pre-change script
  and the new script at `--jobs 4`, both `--require-full-equivalent` over
  1,016 entries: JSON reports byte-identical (SHA-256 `4cdc9696...`), printed
  lines identical (projected corpus `74f14088...`, 1,016 equal, 0 errors);
  2,301.7 s serial alone, 576.2 s at four processes (4.0x); 10 new tests in
  `tests/test_mes_full_handoff_equivalence.py` (jobs 2 report equals jobs 1,
  digest order, limits, failures, CLI, worker failure propagation, start
  order). **(d) measurement** (6 cores / 12 threads, 15.9 GB, sampled every
  30 s with RAM, commit and the Godot/Python working sets):

  | Whole batch, uncached `--cache-store`, tree `41ff67a` | `--jobs 6` (`5351ac5c`) | `--jobs 5` (`f20c55b6`) | `b9fa356`, `--jobs 4` |
  |---|---|---|---|
  | Result | 402/402 passed | 402/402 passed | 402/402 passed |
  | Wall time | 3,980 s | 4,143 s | 4,564 s |
  | Sum of check time | 10,935 s | 10,001 s | 15,195 s |
  | Parallel efficiency | 0.46 | 0.48 | 0.83 |
  | Full handoff equivalence | 722 s (0.24x) | 551 s (0.19x) | 2,968 s |
  | Group routes shards 1-4 | 771 / 971 / 1,053 / 753 s | 719 / 923 / 1,014 / 757 s | 1,481 / 1,369 / 1,055 / 1,024 s |
  | Transfer-direction corpus | 1,021 s (0.99x) | 856 s (0.83x) | 1,032 s |
  | Analyzer handoff corpus | 1,037 s (1.01x) | 848 s (0.82x) | 1,029 s |
  | Peak RAM used (of 16,309 MB) | 13,868 MB = 85.0% | 13,951 MB = 85.5% | not sampled |
  | Mean RAM used / peak commit | 47.7% / 107.5% of RAM | 41.1% / 107.0% | |
  | Mean / peak CPU | 36% / 67% | 27% / 51% | |

  No heavy check passed 1.01x of its `b9fa356` time (the 1.3x trigger for
  trying `--jobs 5` was not met) and none passed 0.43 of its timeout (limit
  0.7). Memory is not set by the job count: the ~85% peak is one 30 s sample
  at which three heavy Godot checks (six processes, 8.7 GB of working set)
  coincided on top of ~7 GB the machine's other applications already held;
  it recurs at 5 and at 6, 2.4 GB of RAM stayed free, and Pages Input/sec was
  not sampled (the counter names are localized on this machine), so "no
  paging" is not proven. Because 5 was no better on memory and 4% slower,
  `--jobs 6` is the documented value (`AGENTS.md`, `README.md`,
  `tools/README.md`); the memory criterion (below ~85%) was met only at its
  edge, which is a reason to re-check it after TD-42 changes which checks
  overlap. The `--jobs 6` batch was the first run with the new ordering, the
  parallel handoff equivalence and `--jobs 6` together (its purpose was to
  choose the documented value, not a clean A/B), and its ordering used
  durations from older cache entries. **Cached closing run** (run `2248f2c0`,
  `--cached --jobs 6`, right after the `--jobs 5` batch on the same tree):
  402/402 passed, 402 cached, 5.6 s. **Closing run on the committed tree
  `2a1283f`** (run `47c62764`, `--cached --jobs 6`): 402/402 passed, 401
  cached; the python regression suite re-ran (247 s) because the commit
  changed `tools/README.md` and `tools/` is in that check's input tree
  (`tools/content_suite/validation_inputs.py:51`, `477-479`) - intended, not a
  defect.

- [x] **TD-39 - The heavy full-tier checks run within 1.2-1.4x of their runner timeouts.**
  Closed 2026-10-03 (timeouts rebased at `3837088`). **Verification:** the two
  whole batches of TD-40 d (402/402 each) put every heavy check at 0.43 of its
  timeout or less - transfer-direction 1,021 s of 2,400, group routes worst
  shard 1,053 s of 3,000, analyzer handoff corpus 1,037 s of 3,000, full
  handoff equivalence 722 s of 6,000 - margins of 2.3x and up against the 1.5x
  floor, so no timeout moved. Residue found on the way:
  `tests/test_run_headless_validation.py` still pinned the analyzer handoff
  corpus's old 1,800 s (3,000 s since `3837088`); fixed in `b8959f9`, before
  the Python regression suite could fail on it. Original finding, kept:
  found 2026-10-03 (TD-37's whole batch, run `591c41a5`, 401/402): `original
  MES transfer-direction corpus` timed out at its 1,200 s limit after 700-799
  of 1,016 entries, no content failure; alone it passes in 838 s with the
  same `payload_sha256` (`b09f9773...`). Under `--jobs 4` the heavy checks
  grow run to run (leftovers `e34ae6c6` -> `b9fa356` `43cee30e` -> `591c41a5`):
  transfer-direction 889 -> 1,032 -> >1,200 s (limit 1,200); Python Phase 1-4
  full handoff equivalence 2,293 -> 2,968 -> 3,088 s (limit 3,600, 1.17x);
  `original catalog group routes` worst shard 1,028 -> 1,481 -> 1,398 s
  (limit 1,800, 1.22x); `original MES analyzer handoff corpus` 883 -> 1,029
  -> 1,286 s (limit 1,800, 1.40x). Whole-batch wall time 3,781 -> 4,564 ->
  4,633 s on 12 cores with 4 processes (not oversubscription; thermal, power
  or memory contention not established - recorded, not chased). Fix (advisor,
  2026-10-03): rebase each on at least 2x its worst `--jobs 4` observation -
  transfer-direction 1,200 -> 2,400 s, `PYTHON_HANDOFF_TIMEOUT_SECONDS`
  (`tools/content_suite/run_headless_validation.py`) 3,600 -> 6,000 s, group
  routes and analyzer handoff corpus 1,800 -> 3,000 s (all `full` tier
  already). Sharding the transfer-direction corpus is the next step if it
  grows again. Verification: one whole batch.

- [x] **TD-38 - `original sequence contextual authoring` fails its fixed 60 s test deadline.**
  Closed 2026-10-03. **Reproduction (recorded, checkpoint A):** the check
  failed 2/2 on `7a0a91c` (tree `ba1dc17`, 112.1 s and 112.8 s) and 2/2 on
  `06c9d72` (tree `94bc156`, detached worktree, 111.5 s and 109.7 s), all four
  with the same signature - the first authoring wait passes, the sequence
  compile's wait hits the fixed 60 s. The compile run alone (the test's own
  `mes_authoring_workflow.py compile` command with the test's bundle and its
  two staged operations, idle machine, three runs each) took 57.8-62.1 s on
  `7a0a91c` and 58.4-60.9 s on `06c9d72`: the compile costs the same on both
  trees and sits on the 60 s literal itself, so the pass/fail is a margin of
  about zero, not a regression of the EP-12 unit. The morning pass (run
  `e34ae6c6`) is consistent with the same coin falling the other way (inferred;
  its compile time was not recorded). **Fix (checkpoint B, `812f871`):** one named
  constant `AUTHORING_HANG_GUARD_SECONDS := 240` and a static
  `authoring_wait_note` in `tests/test_case.gd` (the TD-05 shared home), used
  by both copies of the literal (`tests/test_mes_authoring_workflow.gd`
  `_wait_authoring`, which reaches it through a `TestCaseScript` preload
  because it extends `test_mes_editor.gd`, and `tests/test_mes_semantic_diff_chain.gd`
  `_wait`). Both now print `AUTHORING_WAIT <n> s elapsed, hang guard 240 s`
  when the process finishes and carry the same note in the deadline failure,
  so compile-time drift shows in batch logs. The constant is a hang guard,
  not a performance budget; the runner's 600 s bound still limits the whole
  check. No Core bump (tests only). **Results:** the three affected checks
  (`original sequence contextual authoring`, `Godot test_mes_authoring_workflow.tscn`,
  `Godot test_mes_semantic_diff_chain.tscn`) passed on both of two runs at
  `--jobs 1` (the sequence check 339.5 s and 332.1 s - the rest of the check
  that the deadline had cut off adds about 220 s beyond the 112 s failing
  runs); `--tier local --jobs 4` 135/135 (358 s); `--tier archive_quick --jobs 4`
  with the archive and executable 217/217 (1,198 s). **Residue:** the sequence
  check took 442 s inside that `--jobs 4` run against its 600 s runner bound
  (margin 1.36x), and the standalone compile itself (about 60 s) is a
  measurement item not chased here; the whole batch is the planner's run.
  Residue closed the same day (advisor): the check's runner timeout raised
  600 -> 1200 s in `config/validation/checks_v1.json` (the value the corpus
  checks use; 2.7x the worst observed 442 s - this check alone already varies
  337-442 s under `--jobs 4`); the other three checks of the family (1.8-2.0x)
  keep 600 s. A check registered above 600 s belongs to the `full` tier
  (`docs/spec/data/validation_checks.md`, `tier`), so it moved from
  `archive_quick` to `full` (`--tier archive_quick` now plans 216 checks;
  the whole batch still runs it). Whole batch on `b9fa356` with the archive and executable,
  `--jobs 4`: **402/402**, 4,564 s (run `43cee30e`; this check 391 s).
  Original finding (found 2026-10-03, EP-12 date profiles v5 checkpoint B): the whole batch
  with the archive and executable came out 401/402; the one failure stops at
  `_wait_authoring`'s fixed 60 s deadline (`tests/test_mes_authoring_workflow.gd:617`)
  while `tools/mes_authoring_workflow.py compile` runs the EVENTB03 two-step
  sequence. It passed in the leftovers batch the same morning (run
  `e34ae6c6`); the failing unit changed nothing the check reads. A claimed
  reproduction on `06c9d72` and a ~62 s standalone compile were not recorded,
  so the first step is a recorded reproduction (detached worktree of
  `06c9d72`, tree hash in the report) and a timed standalone compile. Fix
  shape (advisor, 2026-10-03): the runner already bounds the check (600 s,
  `config/validation/checks_v1.json`), so the in-test literal duplicates its
  role with a margin that fits only an idle machine - replace the literal in
  both copies (`tests/test_mes_authoring_workflow.gd:617`,
  `tests/test_mes_semantic_diff_chain.gd:96`) with one shared hang-guard
  constant in `tests/test_case.gd` (240 s) and print the elapsed seconds so
  compile-time drift stays visible. Speeding up the compile is a separate
  measurement item. The `py -B` launch (`tools/content_suite/mes_authoring_session.gd:134`)
  rules out bytecode caching as the cause. Batch-trust item: precedes
  EP-12's next family.

- [x] **TD-37 - The v6 projection silently drops its witness-derived rows.**
  Found 2026-10-03 (EP-12 leftovers resume); closed the same day (owner:
  "push and proceed with TD-37"; spec `analysis/_docs/td37_witness_rows_spec.md`).
  The projected v4 documents carry 1,270 `shift_witness`-basis rows; every v6
  document since `f9a2454` carried 0 (and 0 `reentry_probe` done cells), and
  `97382f2` (the run before it) had them. Cause: the producer reads effect
  witnesses from `--witnesses-dir`, and when a profile's
  `witness_requests/<stem>.json` / `witnesses/<stem>.json` pair is absent
  `tools/project_event_definition_v4.py` `load_witness_index` returned empty
  indexes without a warning, so a regeneration without the witness corpus
  (untracked, under `analysis/`) degraded silently instead of failing; the
  README's "1,997 fewer unresolved lines" and the EP-12 tracker overstated what
  the committed documents carried. **Decision:** the corpus stays untracked
  (derived, deterministic from the archive, the tracked profiles and the
  replays); reproducibility is the recipe in `config/event_definitions/v6/README.md`
  plus a fail-closed producer.
  **Checkpoint A (`fc5e88b`, producer and tests):** the v6 producer and
  `--contract v6` batch refuse a site when any profile it matches (every
  non-v14 profile is witness-capable, 161 of 173; the loader merges all
  matches) has no request file, has requests but no witness file, or carries a
  `payload_sha256` that is not the profile's, and the batch refuses before its
  first site when `--witnesses-dir` or its sibling `witness_requests` is
  absent; `--allow-missing-witnesses` (v6 only) is the opt-out (per-site
  warning, summary count; stale evidence is refused either way). v4/v5 keep
  their silent legacy loader (frozen). `plan_event_effect_witnesses.py` skips
  the 12 v14 flow replays (it crashed on them) and prints the count. New tests:
  `tests/test_project_event_definition_witness_guard.py` (24) and one in
  `tests/test_plan_event_effect_witnesses.py`; Python suite 1,963 OK, local
  tier 135/135.
  **Checkpoint B (untracked evidence, `analysis/_undoc/td37/runs.md`):** 161
  request files (4,801 shift + 363 done-probe requests, 12 flow replays
  skipped), 161 witness files answering all 5,164 (4,409 `set`, 111 `add`, 192
  `path_changes`, 89 `other`, 363 probes; 0 errors; every `payload_sha256`
  equal to its profile's), 1,258 s at 4 in parallel, 0 failed.
  **Checkpoint C (v6 re-projected):** `projected=189 valid=189 invalid=0`;
  `shift_witness` 0 -> 1,718, `reentry_probe` done cells 0 -> 46, `variants`
  179 -> 129 (50 shared rows hoisted to the body with the better basis),
  `unresolved` lines 5,405 -> 1,580 (154 ordinary documents; all 189: 7,683 -> 3,858, the 35 flow documents unchanged at 2,278). Proved monotonic per document against the
  committed set (flow documents byte-identical; no decided row changed or
  removed; no other field moved; no `cell_class` moved) and reproduced from
  `97382f2` in full (all 1,251 `shift_witness` rows and 34 `reentry_probe`
  cells, same values, none missing or differing). Catalog (revision 34) and
  registry unchanged. Guard: `tests/test_event_definitions_tracked.py` asserts
  at least those 1,251 and 34 (and that the index agrees); it fails on the
  previous set. The README's 1,997 passages now say which state carried them
  (`97382f2`: 3,381 -> 1,384 on the 142 v5 sites; the committed set from
  `f9a2454`: 3,381; now 1,357). Verification on the C tree: parse check OK; whole batch with
  `--elfimage`, `--exe`, `--jobs 4` (it includes the local tier and the Python
  suite, 1,964 tests OK): 402 checks, 401 passed, 4,633 s. The one non-pass is
  `original MES transfer-direction corpus` at its 1,200 s runner limit
  (`timeout`, no content failure): it reads only `mes.arc`, passes alone in 838 s
  with the same `payload_sha256` (`b09f9773...`) it printed in the previous
  whole batch, where it took 1,032 s under `--jobs 4` (889 s in the leftovers
  batch, run `e34ae6c6`) - a margin problem like TD-38's, tracked as TD-39. Also fixed: the stale `--witness` comment in
  `validate_event_analysis_group.gd` (it accepts every non-v14 profile schema,
  not v6/v13 only). Residue: `--witness` does no schema check of its own, so
  passing it a v14 profile is unsupported (the planner never requests one);
  that path was not exercised here.

- [x] **TD-36 — Three whole-batch failures on `main` (batch trust).**
  Found 2026-10-02: whole batch at `9baa1f7`, `--jobs 4` with `--elfimage`
  and `--exe`, 401 checks, 398 passed. Failing: (1) `unreferenced archive
  entries` - the report embedded machine-local facts (the executable's file
  name, `AI5WIN.original.exe` there and `AI5WIN.exe` here, same bytes; and
  `AI5WIN.INI`'s size, 759 vs 761, a file the game rewrites); (2) `original
  event corpus literal dispatch inventory` and (3) `original event analysis
  frontier` - the route classification was last refreshed 2026-09-24 and
  catalog revision 32 (`0cf38bd`, `f9a2454`, `090ef03`, `14b7157`) changed the
  catalog without a refresh. Fix: checkpoint A (`93282c4`) made the report
  schema `kakyu_unreferenced_entries_audit/v2`, regenerated in place -
  executable under the label `<executable>` plus a pinned `executable_sha256`
  (`ORIGINAL_EXECUTABLE_SHA256`, new in `tools/payload_values.py`; a different
  executable is refused), `AI5WIN.INI` marked `mutable` with no size pin,
  counts unchanged - and a Python test (`tests/test_audit_unreferenced_entries.py`)
  that the scan is invariant under renaming the executable and resizing the
  INI. Checkpoint B refreshed the classification for revision 32: 12 class
  moves `system_script` -> `playable_event` (`A..J,L_PIC.MES`, `G_PROMIS.MES`),
  `class_counts` 131/35/1 -> 143/23/1, confidence unchanged, 166 bound; the
  refresher's default inventory is now
  `analysis/event-corpus-inventory-2026-10-02.json` and it also prints class
  moves and the catalog-hash rebind. Blind spot: the refresher printed only
  confidence moves, so "classification unmoved" at `0cf38bd`
  (`todo/event_player.md`) was true of confidence and false of class.
  Process gap: catalog revisions landed with neither a classification refresh
  nor an archive-tier run; the last whole batch before this was 2026-09-23.
  Recommendation: a catalog-revision unit runs `--tier archive_quick` (with
  `--elfimage` and `--exe`) and the classification refresh before landing.
  Residue: four other tools still carry their own copy of the executable
  sha256 (`audit_eventb03_camera.py:26`, `audit_eventb03_sound.py:28`,
  `audit_mes_logical_truth.py:22`, `audit_eventb03_station_native.py:21`);
  the EP-12 wip branch needs its own refresh at revision 33.
- [x] **TD-35 — A choice-contract schema bump refused every stored contract.**
  Found and fixed 2026-09-24: the redirect consumer shape (Core 0.363.0)
  bumped `kakyu_mes_routine40_choice_contract` to v4 and `validate()`
  accepted only the current string, so the 182 v3 contracts embedded in the
  committed profiles failed "schema is unsupported" - 63 of 149 `original
  event analysis` checks red at `1861e36`, found by the next agent's batch,
  not by the unit's own validation (which ran the catalog group routes but
  not the analysis groups). Fix: `validate()` accepts the prior v3 schema
  when the contract carries no redirect field (compared as -1) and refuses a
  v3 contract that does; two scene checks; the 149 checks green again.
  Rule for the spec writer: a change to anything the profiles embed
  (contract schemas, record bindings) runs `--check "original event analysis
  groups"` before it merges.
- [x] **TD-33 — Run independent validation checks in parallel.**
  Closed 2026-09-23: both tiers passed repeatedly at `--jobs 4` with the
  sequential pass set, the whole `full` tier was measured (375 of 375 in
  2,897 s against 7,638 s), and the owner chose the default - the runner
  keeps `1` (the Launcher's background run stays on one core) and the
  documented batch command in `AGENTS.md` and `tools/README.md` passes
  `--jobs 4`.
  Scheduled by the owner on 2026-09-23 (the batch-efficiency question, all
  three measures in the recommended order: the TD-32 cache first - seeded by
  the whole Core 0.360.0 run with `--cache-store` - then this, then TD-34).
  The runner runs every check one after another; only the Python regression
  is sharded (at most 4 jobs), so a 12-CPU machine sits at one busy core for
  most of the 7,989 s of the last whole batch. Target: `--jobs N` with a
  longest-first schedule, each Godot child isolated in its own user data
  directory, output printed per check without interleaving, report rows in
  registry order, and an `exclusive` mark for checks that must run alone.
  Done when the `local` and `archive_quick` tiers pass twice in a row at
  `--jobs 4` with the same pass set as a sequential run, and a whole run's
  wall time is measured. Spec: `analysis/_docs/td33_parallel_batch_spec.md`.
  - **Part 1 landed 2026-09-23** (`1e9d104`, `5d6021a`; no Core change):
    `--jobs N` (default 1), longest-first order from the last report or the
    cache, slots by weight (the Python suite takes its shard count), the
    three sibling-process scenes exclusive (registry revision 3:
    `exclusive`, `exclusive_scenes`), a per-slot `APPDATA`/`TEMP` for every
    Godot child (47 distinct `user://` prefixes measured; a probe confirmed
    `APPDATA` moves `user://`) and an outside-the-project `TEMP` for Python
    children, one output block per check, report rows in plan order, report
    schema v6 (`jobs`). The review found one fail-open defect before merge -
    a worker-thread exception dropped its check's row and the run could pass
    without it - fixed in the second commit: the exception becomes an
    `error` row, and any planned check without a row becomes one on both
    paths. Verified 2026-09-23 while a whole batch and an agent shared the
    machine: the Python suite (1,861 tests), `--tier local` 134 of 134 at
    `--jobs 1` (270 s) and three times at `--jobs 4` (190-197 s, one pass
    set), `--tier archive_quick` 214 of 214 twice at `--jobs 4` (718 s,
    710 s), all uncached. Contract: `docs/spec/data/validation_checks.md`,
    "Parallel checks".
  - **Part 2 landed 2026-09-23** (`42dff74`): `original catalog group
    routes` runs as four shards (registry revision 4, `shards`; the
    validator's `shard=K/N`; guard-form and forged checks in shard 1), 628 s
    at `--jobs 4` against ~1,500 s unsharded, sums equal to the unsharded
    run; the Playback pass names every resource it cannot find. Verified:
    `test_validation_registry.py` (40), `test_run_headless_validation.py`
    (50), `--tier local --jobs 4` 134 of 134 (180 s), the four shards 4 of
    4 with the archive. The whole `full` tier at `--jobs 4` on `db59f4b`,
    2026-09-23: 375 of 375 in 2,897 s against 7,638 s sequential (efficiency
    3.0 of 4; the full Python handoff equivalence, 1,581 s beside three
    others, is now the longest single check). The same run showed the cache
    keyed the project root into every fingerprint, so a worktree run seeded
    nothing the main checkout could reuse; the root is now normalised to
    `<PROJECT>` (`validation_inputs.normalize_command`, test in
    `tests/test_validation_inputs.py`). The owner kept the default at `1`
    and put `--jobs 4` in the documented batch command.
- [x] **TD-34 — Build the playback package once for the package checks.**
  Closed 2026-09-23 by the owner without a change, on the measurement below:
  the shared build is ~0.8% of the batch, the whole run is 2,897 s at
  `--jobs 4`, and the cache skips an unchanged check.
  - **Measured 2026-09-23, before any change:** in the sequential whole
    batch the export check took 65 s and the playback check 112 s, the
    shared build being ~60 s of that - about 0.8% of the batch's 7,454
    check-seconds and ~15 s of wall time at `--jobs 4`. Put to the owner:
    close it as not worth a change, or re-scope it to the check that now
    bounds a parallel run, the full Python handoff equivalence.
  Scheduled with TD-33 (2026-09-23). `original playback package export` and
  `original playback package playback` each build the full 142-event package,
  and the playback check runs all 142 rows twice (bytecode reference and
  package) while `original catalog group routes` runs the same rows again.
  Share one package build between the two package checks and measure what the
  row runs share with the group-routes check before merging anything; the
  equivalence each check proves must not weaken. Taken after the EP-03
  next-event unit lands, since that unit edits the playback check.

- [x] **TD-32 — The validation checks as data: a registry, tiers and input-fingerprint caching.**
  Closed 2026-09-21 in three parts (Core 0.357.0-0.359.0; the parts below).
  Scheduled by the owner on 2026-09-20 as the unit after EP-10 (the architecture
  note of the same day, item 6). Today `tools/content_suite/run_headless_validation.py`
  carries the 372 checks as tuples in `build_checks()`, every check runs
  every time, and the whole batch takes 7,989 s at Core 0.350.0 (the full
  Python handoff equivalence 1,196 s, the MES corpora 686 + 674 s, the
  EVENTB03 presets 814 s, the 140 group checks 1,570 s mostly in process
  start-up). The unit:
  - A tracked registry file (`config/validation/checks_v1.json` or the like)
    naming each check: script, arguments, timeout, tier (`local`,
    `archive_quick`, `full`), and the inputs whose fingerprints decide
    whether a cached green result still holds (tracked source files,
    profiles, catalog, contracts, the archive hash). The runner reads it;
    `build_checks()` becomes a loader; a test proves the registry and the
    runner agree with the tracked files.
  - Tiers as runner flags (`--tier local|archive_quick|full`) with the
    existing `--check` selection kept.
  - A content-addressed cache of green results keyed by the check's input
    fingerprints and the Core version, stored under `analysis/` (never
    tracked), consulted only when asked (`--cached`), reported in the
    report as `cached: true`; a red result is never cached.
  - The 140 group checks run inside one Godot process (one archive open)
    as a single registry check with per-group rows in its report, keeping
    the per-group names for `--check`.
  Not in the unit: changing what any check verifies.
  - [x] Part 1, 2026-09-21 (Core 0.357.0): the registry `config/validation/checks_v1.json`
    (`kakyu_validation_checks/v1`: name, kind, script, arguments with
    placeholders, timeout, groups, `requires`, `tier`, the scene family and
    the per-profile `analysis_group` entries) and `build_checks()` as its
    loader, behaviour-neutral - the baseline dump of every argument
    combination is identical before and after; `--tier local|archive_quick|full`
    (default `full`), composed with `--check`; the report schema is v4 (the
    tier in the context). Contract: `docs/spec/data/validation_checks.md`.
    242 registry entries (221 `godot_script`, 19 `python`, one `godot_editor`, one scene family; 149 `analysis_group` entries) planning 134 checks locally, 361 with the archive, 373 with the archive and the executable (372 without `se.arc` or with `--skip-event-corpus`); tiers `local` 3 entries (the 134 local checks), `archive_quick` 81, `full` 158 (the nine long checks and the 149 analysis-group entries, whose runs are the long part of the batch). Verified 2026-09-21: the baseline dump of six argument combinations identical before and after the change; `tests/test_run_headless_validation.py` (24) and the new `tests/test_validation_registry.py` (12: load and validation, script and profile existence, the scene family, the placeholder set, the tier ordering, five malformed registries failing closed by entry name); the Godot parse check; `--tier local` 134 of 134 (255 s); `--tier archive_quick` on `original Event Catalog source bindings`, `original playback package export` and `original Event Player fragment catalogs` (3 of 3); the pre-commit review's findings fixed.
  - [x] Part 2, 2026-09-21 (Core 0.358.0): the 149 `analysis_group` entries run
    in one Godot process. The per-profile validation moved out of
    `validate_event_analysis_group.gd` into
    `tools/content_suite/event_analysis_group_validation.gd`
    (`KakyuEventAnalysisGroupValidation.validate`, byte-identical canonical
    reports; the single CLI and its `--replay` / `--witness` modes keep
    their behaviour), `validators/validate_event_analysis_groups.gd` runs
    a list of profiles on one open archive and prints a `GROUPS_SUMMARY`,
    and the runner collapses the selected member checks - after `--check`
    - into one process check declared by the registry's `families` block
    (revision 2), reporting one v4 row per group (`--check "original event
    analysis groups"` names them all). The measured cost was the Python
    exact-source audit, not Godot (6-10 s per profile, nearly all of it
    rebuilding the same member entries' handoffs), so the multi-profile
    CLI audits every selected profile in one Python process
    (`audit_event_analysis_group.py --profiles ...`, a per-entry handoff
    cache, one JSON line per profile) and hands each result to the module.
    Verified 2026-09-21: the single validator's canonical report JSON for five profiles (GROUND H01 H02, 01M B03, 12C D14, 44C M10A, 01M H07) byte-identical between the HEAD script, the refactored single CLI and the multi-profile process, with the Python audit's own reports byte-identical between `--profile` and `--profiles`; `--check "original event analysis groups"` over all 149 profiles: 149 of 149 in 614 s on an otherwise idle machine (part 2 alone, before the batched audit: 1,415 s; the 140 separate processes of 2026-09-19: 1,570 s; the 488 s of the first batched-audit run was measured before the review's fixes), median member 2.2 s (8.6 s before; the archive hash costs 42 ms, the rest is the route runs); one member alone 0.8 s; the Python suite (1,786) with `tests/test_run_headless_validation.py` (36: the collapse, the per-member parse with a script error isolated to its member, the family name refused when no member is planned, `main` end to end), `tests/test_validation_registry.py` (29) and `tests/test_event_analysis_group.py` (69: the cache equal to the uncached audit, the cache reused across profiles and never across archives, the `--profiles` lines); the `--profiles-file` fallback byte-identical to the direct form; the parse check; `--tier local` 134 of 134; the pre-commit review's findings fixed.
  - [x] Part 3, 2026-09-21 (Core 0.359.0): each check's inputs are found by a
    static scan (`tools/content_suite/validation_inputs.py`: `res://`
    literals, class-name references, `.tscn` resources, Python imports and
    path literals, followed to a closure; a directory literal brings every
    file under it; a non-literal `load(` widens the closure to every
    script of `content_core/` and `tools/content_suite/`; the project
    parse check and the Python suite cover the whole tree by design) and
    fingerprinted with the Core version, the normalised command and the
    archives' and executable's hashes (`--fingerprints`,
    `--fingerprint-inputs`). `tools/content_suite/validation_cache.py`
    keeps green results under `analysis/validation_cache/` by that
    fingerprint - never a red one - engaged only when asked: `--cached`
    reads and writes, reporting a hit as a `cached: true` row without
    running it (the analysis-group process runs only the misses),
    `--cache-store` writes without reading, nothing otherwise; report
    schema v5 (`cached` count, `cache` and `cache_dir` in the context; v4
    and v3 still load); `--cache-dir`, `--cache-clear`. Verified 2026-09-21: the full plan (361 checks with the archive) fingerprints in 3.7 s (inputs min 8 / median 35 / max 2,288 - the Python suite and the project parse check by design; one unresolved reference, a deliberately absent scene in a fixture; one dynamic load, the window-size scene iterating every app scene); `--tier local --cache-store` 134 of 134 in 249 s, then `--tier local --cached` 134 hits in 1.1 s; after touching one shared script (`content_core/event_presentation_timeline.gd`, restored byte-identical) 112 hits and 22 re-runs (the parse check and the 21 scenes whose closure reaches it) in 58 s; `--cached --check "original event analysis groups"` 149 of 149 stored in 493 s, then 149 hits in 0.9 s with no process run; `tests/test_validation_inputs.py`, `test_validation_cache.py`, `test_run_headless_validation.py` and `test_validation_report.py` (83) and `test_validation_report.tscn` (64, the panel included); the Python suite; the parse check; the pre-commit review's findings fixed.
  TD-32 is complete: the checks are data, tiers select them, the group
  checks run in one process, and a green result is reused while its inputs
  are unchanged. The pre-commit batch may run `--cached` when the changes
  since the last full run are code or data the scan sees; a change to a
  path built at runtime, or to anything outside the scanned trees, calls
  for a run without it.
- [x] **TD-28 — Prevent unpacked Python runtime metadata from shadowing Godot classes.**
  - Closed 2026-09-08. A distribution unpacked beneath this checkout exposed
    `runtime/content_core/content_core_version.gd` to the editor scanner and
    shadowed the real `ContentCoreVersion`, breaking launcher compilation even
    though Godot exited zero. Generated analysis runtimes have the same risk.
  - The distribution builder now includes `runtime/.gdignore` before hashing
    its inventory. Existing local analysis/output parent folders receive the
    same scanner exclusion outside published bundles, preserving bundle hashes
    and user content. No interpreter or data contract changes.
  - The reproduced script/compile errors disappear on the headless project
    import; all five Python packaging regressions pass. Published Core 0.306.0
    artifacts predate the marker and are not silently rewritten or rehashed.

- [x] **TD-00 — Restore split integrity.**
  Defects and open decisions the repository split introduced or exposed here.
  The first two were why `run_headless_validation.py` could not complete; the
  last two were ownership questions the split left unanswered. **All four closed
  2026-09-05.** What `kakyu-remake` does with its own half is out of scope for
  this tracker.
  - [x] Fix `tools/content_suite/run_python_regression.py`. At its default job
    count it crashes before running anything. It passes every test ID on the
    child command line, and with `--jobs 4` one shard's command line measures
    **35,343 characters against the Windows limit of 32,767**, so
    `CreateProcess` fails with `WinError 206`. Measured shard maxima: 35,343 at
    4 jobs, 18,146 at 8, 8,327 at 16. Two separate fixes are needed. Shard by
    command-line length as well as by weight, or pass test IDs through a file;
    and widen `_run_shard`'s `except subprocess.TimeoutExpired` at
    `run_python_regression.py:93-133` to also catch `OSError`, so a launch
    failure becomes a named diagnostic instead of an unhandled traceback out of
    the thread pool.
    **Closed 2026-09-05.** A shard is now the unit of parallelism and a *batch*
    the unit a process can be launched with; `command_batches` splits a shard by
    the length `subprocess.list2cmdline` actually produces, and batches run
    sequentially inside the shard against one shared deadline, so `--timeout`
    keeps meaning per shard. `_run_batch` catches `OSError` and reports
    `PYTHON_REGRESSION_LAUNCH_ERROR` with the measured length. Five new
    `command_batches` cases and two launch-failure cases cover it, including one
    that asserts the discovered suite fits at `DEFAULT_MAX_JOBS`. Verified: the
    full suite runs at the default job count and passes, 1,007 tests.
  - [x] Fix the scene list in `tools/content_suite/run_headless_validation.py`.
    `GODOT_SCENES` at line 27 declares 78 scenes; `test_content_service.tscn`
    at line 31 does not exist here — it was deliberately not carried in commit
    `9275d12` — and Godot returns exit 1 for it, failing the batch. Thirteen
    scenes on disk are also absent from the list and therefore never run in the
    official batch: `test_ai5_lz`, `test_mes_address_entry_insert_plan`,
    `test_mes_address_entry_insert_compile_reopen`,
    `test_mes_control_body_edit_plan`, `test_mes_control_body_edit_compile_reopen`,
    `test_mes_control_target_edit_plan`, `test_mes_control_target_edit_compile_reopen`,
    `test_mes_editor_run_request`, `test_mes_library_runner`,
    `test_mes_registered_definition_call_edit_plan`,
    `test_mes_registered_definition_call_compile_reopen`, `test_mes_semantic_diff`,
    and `test_mes_translation_catalog`.
    **Closed 2026-09-05.** The 78-entry `GODOT_SCENES` tuple is gone and
    `discover_scene_names()` reads `tests/*.tscn` instead, so the second copy no
    longer exists to drift; an empty directory fails closed. Three new cases
    assert the batch and the directory agree in both directions. Verified: 91 of
    91 scenes pass, the batch now covering all of them.
  - [x] Decide what happens to `content_core/content_service.gd`. It arrived in
    commit `9275d12` with no test, and it had **no consumer here either**:
    nothing referenced `ContentService` or the file path, and `project.godot`
    has no `[autoload]` section at all. `tools/README.md:1133` documented it as
    "the gameplay autoload" and pointed at the absent
    `res://tests/test_content_service.tscn`.
    **Removed, 2026-09-05, by the owner's ruling.** The README paragraph named
    its consumers — AudioService and the legacy event, encounter and town-map
    adapters — and all four went with the prototype in step 6. It was a
    game-shaped API (`load_mmo_texture`, `load_audio_stream(loop)`) over the same
    `ContentResolver` that all five Content Suite applications already use
    directly, so nothing here was going to adopt it. It was also the only file
    in `content_core` holding `Texture2D`, `AudioStream` and `Node`, so its
    removal takes the largest engine coupling out of the analyzer's core.
    `CONTENT_SERVICE_SCHEMA` went with it. Recoverable from `9275d12`.
  - [x] Resolve the 12 specification documents this repository references but
    did not contain.
    **Moved here, 2026-09-05, by the owner's ruling**, on the rule that a
    document lives where its producer lives. `docs/spec/` now holds all 24
    `mes/` analysis documents, `tech/content_tools.md`, `tech/tooling.md`,
    `tech/content_suite_gap_matrix.md`, and the four `data/` contracts
    `content_core/` implements — `content_project`, `content_workspace`,
    `content_identity` and `materialized_arc_provenance`. A new
    `docs/spec/index.md` indexes them and records what stays behind.

    The set was decided by producer, not by reference count. All 24 `mes/`
    documents are MES analysis — `town_map.md` records "the source flow consumed
    by the remake town-map", not the remake's implementation — so the twelve
    that nothing here referenced came too, and `mes/index.md` indexes a complete
    tree rather than a subset.

    Deliberately left in the remake and referenced by path:
    `tech/playback_package_schema.md`, because copying the contract between the
    repositories is the drift this tracker exists to prevent;
    `tech/modtools_split_plan.md`, the remake's record of its own
    transformation; `tech/architecture.md` and the `systems/` and `scenes/`
    trees, which are the mod player's game shell; and the `data/` documents with
    no implementation here, including `runtime_content_service.md`, which
    describes the file removed above. Nine links point into that set and are
    expected to be unresolvable from this checkout.

- [x] **TD-01 — Fix the wall-clock coupling in the runtime-trace collector.**
  The single Python failure, present since the split:
  ```
  FAIL: test_collect_mes_runtime_trace.MesRuntimeTraceCollectorTests
        .test_external_stop_cleans_breakpoints_and_detaches
  AssertionError: Lists differ: [30] != [29]      tests/test_collect_mes_runtime_trace.py:260
  ```
  The cause is `tools/collect_mes_runtime_trace.py:1221-1225`:
  ```python
  remaining = idle_timeout - (time.monotonic() - last_activity)
  wait_timeout = max(1, int(remaining))
  ```
  `int()` truncates, so any measurable elapsed time turns 30 into 29 and the
  test's exact `[30]` fails. This is a test coupled to the wall clock, not a
  product defect.
  **Closed 2026-09-05.** `collect_live` takes a `clock` parameter defaulting to
  `time.monotonic`, and all four call sites in the wait loop use it. The
  assertion was not loosened: the test injects a frozen clock and still requires
  exactly `[30]`. Verified: `test_collect_mes_runtime_trace` passes, 28 of 28.

- [x] **TD-02 — Make `KakyuMesCodeSource` refuse what it cannot answer (LSP).**
  `content_core/mes_code_source.gd:12-15` states the contract: *"a source that
  does not implement one refuses rather than guessing."* The implementation
  does not keep it. Only `decode_at` and `decode_at_structural` refuse through
  `_unsupported()`. Four others return a plausible answer:
  `is_dialogue_boundary_pattern` → `false` (`:46`), `byte_at` → `-1` (`:50`),
  `hex_range` → `""` (`:54`), `sha256_range` → `""` (`:58`).
  `KakyuPlaybackPackageCodeSource` inherits that, and its `hex_range`
  (`playback_package_code_source.gd:116`) ignores both arguments and returns
  `""`.
  The consequence is that those values reach places that treat them as
  evidence: `mes_library_runner.gd:377` and
  `mes_registered_definition_runner.gd:370` emit
  `"code_sha256": source.sha256_range(0, source.size())`;
  `mes_routine40_choice_contract.gd:61,81` builds `body_sha256` and
  `bytecode_sha256` into a contract; `mes_event_runner.gd:112,135` writes
  `trace_record["raw_hex"]`. An empty hash compared against another empty hash
  passes. `event_player_routine40_consumer_plan.gd:88` does guard with
  `_is_sha256()` and fails closed, but that is one consumer's defence, not the
  base class's contract.

  **Closed 2026-09-05.** The harm was not hypothetical.
  `mes_routine40_choice_contract.gd` compared `source.sha256_range(body, target)`
  against the definition's recorded `body_sha256`; when the source could not
  answer and the record carried no fingerprint, `"" == ""` **passed the
  fingerprint guard**. The seam now returns a named `RANGE_UNAVAILABLE` sentinel
  that is neither empty, valid hex, nor 64 characters, so it cannot equal a
  recorded fingerprint; `KakyuPlaybackPackageCodeSource` returns it for every hex
  range and for any byte range the package did not record; and the contract
  rejects it explicitly with its own message rather than reporting a changed
  fingerprint. `byte_at` already answered `-1`, which is out of band for a byte.
  A new `tests/test_mes_code_source.tscn` covers the contract in 15 checks, and
  was confirmed to fail against the previous behaviour before being accepted.

- [x] **TD-03 — Guard the null return of `KakyuMesCodeSource.for_bytecode()`.**
  `mes_code_source.gd:24-28` returns `null` when the bytecode implementation is
  absent. None of the 13 call sites check it, and two call `.size()` on the
  result immediately: `mes_event_runner.gd:28-30` and
  `mes_library_runner.gd:66-68`. It is unreachable today because
  `mes_bytecode_code_source.gd` is present and `ResourceLoader.exists()` finds
  it, so this is a contract defect rather than a live crash: the factory
  declares a failure mode that no caller handles.
  **Closed 2026-09-05.** The three entry points that dereferenced the result
  immediately — `mes_event_runner.gd`, `mes_library_runner.gd` and
  `mes_registered_definition_runner.gd` — now return a `missing_code_source`
  result through their existing `_result` helpers, which is the repository's own
  fail-closed idiom. The factory keeps returning `null`, because "no
  implementation is present" is an honest answer that a caller should handle;
  the remaining call sites return it onward to callers that already check.

- [x] **TD-04 — Replace `event_player.gd`'s hardcoded event data with catalog
  lookups (OCP).**
  `tools/content_suite/apps/event_player.gd` runs two mechanisms over the same
  events. It loads the catalog — `EVENT_CATALOG_PATH` at `:54`,
  `_event_catalog.load_file` at `:1540`, `build_play_request` at `:1787`,
  `build_terminal_contract` at `:1843` — and it also carries 638 per-event
  constants out of 723 total, and 194 per-event functions out of 455.
  Every count and line reference in this paragraph and the four that follow
  is the 2026-09-05 measurement that opened the item; the dated units below
  record what has moved since, and are the current state.

  **Scope corrected on 2026-09-05 by measurement.** The original entry said
  "639 constants" as though all of them were catalog duplicates. They are not.
  Of the 638, **113 duplicate a value the catalog already carries for that
  event** — counting only strings and integers at or above 256, so coincidental
  matches are excluded; 17 more match only as small integers and may be
  coincidence. The remaining ~508 are internal MES coordinates — routine
  boundaries, resume points, native record offsets — that the catalog schema
  does not hold at all. Removing duplication reaches 113; the rest is not
  duplication.

  The 113 were real. `EVENTB01_ENTRY_SHA256` equalled the catalog's
  `callee.entry_sha256` and was compared at ten sites; the catalog was at
  revision 16 while the constants were frozen in code, so the two could
  diverge silently. That constant and its eleven siblings are gone — see the
  callee-identity unit below — and the line numbers this paragraph carried are
  no longer reproducible, so they are dropped rather than left to rot.

  Adding an event costs a file edit rather than a data edit:
  `_confirmed_caller_route_specification` (`:9961`, 192 lines) is an
  `if event_id.to_upper() == "EVENTxx"` chain of hand-written dictionaries, and
  the EVENTB01 and EVENTB02 arms are identical down to `bgm_routes` and
  `state_writes`. Event-ID mentions in the file: EVENTB14 851, EVENTB03 391,
  EVENTB02 259, EVENTD01 254, EVENTB01 232, EVENTB15 195, EVENTD08 182,
  EVENTD02 182, EVENTD03 155, EVENTD05 127, EVENTD14 75, EVENTD06 15.
  `tools/content_suite/` repeats the pattern with 17 per-event
  `validate_event_player_event*.gd` files of 8 to 52 KB.

  **This is not pure duplicate removal.** The pre-migration B01/B02
  specifications each held seventeen fields besides their short event ID, and
  catalog v2 supplied ten of them: `caller_entry`, `caller_entry_sha256`,
  `callee_entry`, `callee_entry_sha256`, `dispatch_offset`, `resume_offset`, and
  four derived from terminal rows — `return_offset` from `callee_return_only`,
  `bgm_boundary` from `caller_postlude`, `handoff_offset` and `handoff_target`
  from `caller_handoff`. The other seven — `bgm_sha256`, `bgm_routes`,
  `handoff_end`, `handoff_sha256`, `handoff_trace_commands`, `date_index` and
  `state_writes` — had no place in v2. `state_writes` is an execution
  postcondition/diff assertion, distinct from `presets[].writes` initial seeds;
  both already support the relevant storage classes. The caller assertion
  does not carry the preset's `evidence_level` field. Other event adapters have
  different shapes, so this B01/B02 measurement is not their common contract.

  The first migration therefore required **extending the event catalog
  schema**, bumping its version and revision, updating
  `content_core/event_catalog.gd`'s validator and its tests, and then migrating
  the consumer. The remaining work still does not require the decomposition
  deferred by the owner, and it precedes TD-10.

  **B01/B02 catalog unit, 2026-09-06.** Core `0.289.0` introduces catalog
  v3/revision 17 and the optional `bgm_then_handoff` caller route. It combines
  source metadata and explicit terminal IDs with the seven new execution
  evidence fields, preserving the two original 18-field typed specifications.
  Event Player now looks them up from the catalog; both handwritten dictionary
  arms and six unused slice-hash/end constants are removed. Play-request v4
  and terminal-contract v1 are unchanged. Explicit v2 migration preserves
  data/revision without inferring routes; unsupported legacy versions fail
  closed. Loaded input and returned nested dictionaries are detached, and
  invalid browser filters preserve the loaded catalog.

  The shared original catalog audit now verifies every supplied caller route
  through `MesCallerRoute`, including dispatch bytes, BGM/suffix hashes,
  representative dates, handoff commands and final state. The three related
  synthetic scenes pass 255 assertions, including 171 new caller-route checks.
  The full local batch passes **95/95 checks**: **1,288 Python tests**, project
  parsing and **93 Godot scenes**, in 180.466 seconds. The focused original
  batch passes **4/4** in 216.796 seconds: catalog source/route bindings,
  ordinary catalog playback and B01/B02 integration. It verifies 12 catalog
  events, 26 unique source entries and both new caller routes; ordinary Play
  still reaches the existing boundaries for 10 routes. Source archives remain
  unchanged. Reports are `analysis/td04-b01-b02-local-validation.json` and
  `analysis/td04-b01-b02-original-validation.json`. This is a focused original
  pass, not a new 80/80 claim for the entire original group.

  **D01/D02/D03/D14 catalog unit, 2026-09-06.** Core `0.290.0` extends
  catalog v4/revision 18 with `completion_bgm_then_handoff`. It derives each
  route's existing `completion_state_index` from the same singleton
  `global_u8 == 1` condition on the return, BGM and handoff terminal rows.
  D01/D02/D03 gain explicit return rows at their already verified coordinates;
  D14 retains its existing row. All four complete typed 19-field execution
  specifications move to the catalog, removing the common dictionary, four
  handwritten arms and twelve unused slice-hash/end constants. B01/B02 keep
  their original unconditional contract. Explicit v2/v3 migration preserves
  data and revision while rejecting metadata outside the source schema.
  The original catalog audit also checks each callee's hash and aligned
  command-`0x00` return, without claiming full-callee execution from that
  one-record probe. Its versioned diagnostic records retain the intro anchor,
  representative BGM state, handoff boundary and the limits of that probe.

  The three focused synthetic scenes pass **431 assertions**, including
  **347** caller-catalog checks. The complete local batch passes **95/95**
  (**1,288 Python tests**, project parse and **93 Godot scenes**) in 173.742
  seconds. The focused original batch passes **6/6** in 499.212 seconds:
  source/caller bindings, ordinary Play for ten routes, D01/D02/D03 integration
  and fragment catalogs with D14 caller continuation. The final diagnostic
  logging also passes a standalone source audit over all six cataloged caller
  routes. A separate playback-package check passes **1/1** (76 assertions over
  all twelve events) in 4.199 seconds; segments, trace, messages, final state
  and terminal match the bytecode reference with the new return rows.
  Source archives remain unchanged. Reports are
  `analysis/td04-completion-local-validation.json`,
  `analysis/td04-completion-original-validation.json` and
  `analysis/td04-completion-package-validation.json`. This is a focused original
  pass, not a new aggregate measurement of the entire original group.

  **B15 direct-caller catalog unit, 2026-09-06.** Core `0.291.0` introduces
  catalog v5/revision 19 and the seven-field `direct_handoff` metadata kind,
  projecting B15's unchanged 15-field execution specification from its existing
  two terminal rows. The handwritten route arm and two unused constants are
  removed. `MesCallerRoute.validate_direct()` and `direct_result_matches()`
  replace the player's bytecode probe and matcher; the player retains original
  source provenance, callee completion guards, frame arguments/expression stack,
  zero preconditions and rollback. The shared matcher compares exact changed
  state keys/values against the live snapshot. The original catalog audit now
  checks seven caller routes and emits kind-specific diagnostic v2 records.
  Explicit v2/v3/v4 migration preserves data/revision and rejects route kinds
  newer than the source schema.

  The three focused scenes pass **569 assertions**: 412 caller-catalog, 73
  catalog and 84 shared caller-route checks, including 73 new direct-helper
  checks. The full local batch passes **95/95** in 170.144 seconds, including
  **1,288 Python tests**, project parsing and **93 Godot scenes**. The two
  existing call-edit audit shutdown resource warnings recur unchanged from
  the preceding local report. The focused original batch passes **4/4** in
  152.776 seconds: source/caller bindings, ordinary Play for ten routes,
  twelve-event playback-package equivalence (76 assertions), and B15's nine
  dialogue boundaries, media branches, return and direct handoff. Source
  archives remain unchanged. Reports:
  `analysis/td04-b15-local-validation.json` and
  `analysis/td04-b15-original-validation.json`. This does not remeasure the
  entire original group.

  **Direct-caller review correction, 2026-09-06.** Core `0.291.1` requires
  the catalog dispatch coordinate to match a structurally indexed instruction
  in its complete source container region. It no longer accepts a dispatch
  envelope decoded from inside native-record or message payload. Source-derived
  address-table offsets must satisfy the container's strictly increasing,
  unique and in-range rules. Separately indexed regions and an opaque tail
  after a proven dispatch retain their existing boundary meaning. No original
  opcode claim, catalog data or schema changes in this correction.

  Twelve new synthetic assertions cover payload rejection, valid preceding
  records, separate/late opaque regions and invalid address tables; eight
  rejection assertions failed before the fix. Project parsing and the three
  focused scenes pass **4/4** checks and **581 assertions** (96 shared
  caller-route, 412 caller-catalog, 73 catalog). Report:
  `analysis/direct-dispatch-boundary-focused-validation.json`.
  The focused original batch passes **3/3** in 140.892 seconds: all seven
  catalog caller routes, ordinary Play for ten routes and B15 integration.
  Source archives remain unchanged. Report:
  `analysis/direct-dispatch-boundary-original-validation.json`.

  **Terminal-source prerequisite, 2026-09-06.** While measuring the next
  adapter migration, two source-boundary defects took priority. Core
  `0.291.2` / catalog v5 revision 20 fixes B14's `0x230C` handoff owner from
  `44M.MES` to `EVENTB14.MES`; the old caller coordinate was inside a different
  record. Its options 1/3 now name their own callee returns and the unresolved
  caller choice; option 2 names the callee handoff. The original catalog audit
  now checks all confirmed return/handoff terminal owners and indexed records,
  including events without caller-route metadata. Its versioned diagnostics
  distinguish boundary proof from branch/state reachability.

  That audit exposed D05's supposed `0x1380` early return inside a name-insertion
  payload. The D05-only native continuation retained a stream-skip policy after
  the one audited omitted span, skipping into a later record. Restoring the
  default stop policy preserves the remaining dialogue and reaches the same
  `0x173B` MACHI handoff and completion flag 753 for all three choices. The
  catalog, player completion logic and original evidence retract the false
  early return. Shared runner semantics and the analyzer handoff are unchanged.
  D05 stays analysis-only because native entry activation remains unresolved;
  B14 stays partial because its caller choice is unresolved.

  Thirteen added catalog assertions cover the corrected owners, branch
  terminals and completion condition; five Event Player assertions preserve
  the post-native name/text record and reject shadow commands. The pre-fix
  B14 catalog fails eight assertions, and the new original guard independently
  rejects both the old B14 owner and old D05 return. B14's complete original
  integration and twelve-event package equivalence pass **2/2** in 220.513
  seconds (`analysis/b14-terminal-original-validation.json`). The corrected
  original source audit passes all **22 terminal boundaries** and the existing
  seven caller routes (`analysis/terminal-boundary-source-validation.json`).
  Final local verification passes **95/95** in 171.041 seconds: **1,288 Python
  tests**, project parsing and **93 Godot scenes**. The two previously recorded
  call-edit audit shutdown resource warnings recur. The final focused original
  batch passes **4/4** in 235.104 seconds: terminal/source and caller bindings,
  ordinary Play for ten routes, twelve-event package equivalence, and all three
  corrected D05 routes through final dialogue, completion state and catalog
  terminal matching. Source archives remain unchanged. Reports:
  `analysis/terminal-integrity-local-validation.json` and
  `analysis/terminal-integrity-original-validation.json`. This is focused
  original verification, not a new aggregate result for the whole archive group.

  **B14 caller-choice catalog unit, 2026-09-06.** Core `0.292.0` introduces
  catalog v6/revision 21 with seven-field `caller_choice_projection` metadata.
  Source identities and the two existing callee-return/caller-choice terminal
  witnesses reproduce B14's thirteen-field specification; the old validator's
  allowed BGM list becomes the fourteenth field. The handwritten route arm and
  four unused constants are removed. The player keeps its callee-start and
  original resolver/hash checks while delegating the stored-suffix proof to
  `MesCallerRoute.validate_choice_projection()`.

  The shared validator verifies the exact dispatch and suffix hash, then probes
  the declared BGM, DEF registrations and unresolved routine-40 boundary in a
  fresh default sandbox. Every executed trace row must match its actual
  container region's indexed source/end/command. An independent review
  reproduced jumps into BGM and intermediate state-write payloads before this
  guard; both now reject, while an aligned jump over unexecuted native payload
  remains valid. This does not transfer cloned callee state or execute the
  caller choice. A separate versioned original audit records this limited
  proof and both callee return records. Explicit v2-v5 migration preserves
  existing data/revision and rejects route kinds absent from the source schema.

  The complete local batch passes **95/95** in 154.911 seconds: **1,288 Python
  tests**, project parsing and **93 Godot scenes**. After the review's trace
  guard and final diagnostic changes, the focused batch passes **6/6** in
  13.139 seconds: project parsing, catalog, caller-catalog, shared caller-route
  and Event Player scenes, plus the original source audit. This includes
  **626 caller-catalog** and **165 shared caller-route assertions**, eight
  caller routes, 22 terminal boundaries, and 26 structurally matched B14 caller
  trace records. The original integration batch passes **3/3** in 310.163
  seconds: ordinary Play for ten routes, complete B14 outcome/nested-choice
  playback, and package equivalence for twelve events (76 assertions).
  Source archives remain unchanged. Reports:
  `analysis/td04-b14-choice-local-validation.json`,
  `analysis/td04-b14-choice-focused-validation.json` and
  `analysis/td04-b14-choice-original-validation.json`. This is focused original
  verification, not a new aggregate result for the whole archive group.

  **D08 restore-followup catalog unit, 2026-09-06.** Core `0.293.0` introduces
  catalog v7/revision 22 with seven-field `restore_followup` metadata. Source
  identities and the callee-return/caller-handoff witnesses reproduce the
  existing fifteen-field specification; the sixteenth field binds the entire
  restore prefix, including the existing selector-reset record. D_PIC's hash
  is derived from its new required-entry binding. A sequence-zero callee return
  precedes the existing caller dialogues and handoff. Explicit v2-v6 migration
  preserves data and revision without admitting kinds outside the source schema.

  All nine caller specifications now come directly from the catalog. D08's
  final handwritten specification arm and two unused coordinate constants are
  removed; the live adapter also uses the catalog's restore/followup coordinates.
  Shared `MesCallerRoute.validate_restore_followup()` verifies both indexed
  dispatches, the full prefix hash, every executed trace record, and the
  followup/handoff structural boundaries. The separate versioned original audit
  limits that proof to the fresh default-state prefix and indexed terminal
  records. The player retains original resolver/hash checks, the one-based
  choice guard, saved arguments/expression stack, presentation policy and
  rollback. No D_PIC body or outer host execution is implied by the prefix proof.

  The full local batch passes **95/95** in 172.476 seconds: **1,288 Python
  tests**, project parsing and **93 Godot scenes**, including **765
  caller-catalog** and **240 shared caller-route assertions**. The focused
  original batch passes **4/4** in 256.165 seconds: nine caller routes and 23
  terminal boundaries across 26 source entries, ordinary Play for ten routes,
  package equivalence for twelve events (76 assertions), and all three D08
  choices through caller restoration, followup dialogue and final handoff.
  D08's source diagnostic records five structurally matched prefix records.
  Source archives remain unchanged. Independent review found no introduced
  defect; a synthetic check also confirms the default structural cache does
  not leak between calls. The previously recorded call-edit audit shutdown
  warnings recur in the local batch. Reports:
  `analysis/td04-d08-restore-local-validation.json` and
  `analysis/td04-d08-restore-original-validation.json`. This is focused original
  verification, not a new aggregate result for the whole archive group.

  **BGM-route boundary correction, 2026-09-06.** Core `0.293.1` applies the
  structural dispatch boundary to `MesCallerRoute.validate()`, the last route
  path without it. The direct route was corrected in `0.291.1`, and the choice
  and restore routes were built with it, but the BGM-then-handoff path — which
  **six of the nine cataloged routes take**, B01, B02, D01, D02, D03 and D14 —
  still decoded its dispatch at the catalog coordinate. That cannot establish a
  command boundary, because payload bytes can decode as a dispatch-shaped
  envelope. The asymmetry was in the guarantee, not in the recorded results.

  `validate()` now takes the caller's source-derived address table, resolves the
  dispatch through the analysis index's framing of its container region, and
  checks that every executed BGM-prefix and handoff trace record keeps its
  region's indexed source, end and command. The table is forwarded to the runner
  so its framing and the check's cannot disagree; an absent table keeps the
  previous runner behaviour, so a caller that supplies none is unchanged. Both
  callers — the player and the original catalog audit — now supply
  `header.entry_offsets`. No result schema, catalog datum or recorded original
  claim changes: this is a guard the six routes already satisfied.

  Ten synthetic assertions cover it, and **six of them fail when the guard is
  reverted** to the previous inline decode: both dispatch-shaped payload
  rejections, the opaque-prefix fail-closed case, and three invalid
  address-table rejections. The four that still pass under that mutant are
  positive and bounds cases the specification validation already covered, which
  is why the mutation was run rather than assumed. `test_mes_caller_route.tscn`
  goes from 240 to 250 assertions.

  The full local batch passes **95/95** in 166.863 seconds — **1,288 Python
  tests**, project parsing and **93 Godot scenes**. The focused original batch
  passes **9/9** in 556.288 seconds, covering every route the change touches:
  catalog source bindings over all nine caller routes and 23 terminal
  boundaries, ordinary Play for ten routes, B01, B02, D01, D02 and D03
  integration, fragment catalogs with D14's caller BGM and handoff, and
  twelve-event package equivalence. Source archives unchanged. Reports:
  `analysis/bgm-boundary-local-validation.json` and
  `analysis/bgm-boundary-original-validation.json`. This is focused original
  verification, not a new aggregate result for the whole archive group.

  **Per-event caller entry points removed, 2026-09-06.** The nine catalog-backed
  routes still reached the player through **19 per-event wrapper methods** and
  six `EVENT*_CALLER_POSTLUDE_BOUNDARY` constants. Those constants repeated
  catalog data: `EVENTB01_CALLER_POSTLUDE_BOUNDARY` was `0x1017`, the same 4119
  its `caller_postlude` terminal declares, and `MesCallerRoute.validate()` has
  returned that number as `boundary_offset` since the B01/B02 unit. Six of the
  wrapper pairs were byte-identical: `_validate_eventXX_caller_return` and
  `_validate_eventXX_caller_postlude` had the same body, so two names described
  one lookup.

  Three evidence-API methods replace all nineteen —
  `catalog_caller_route_evidence(event_id)`,
  `catalog_caller_handoff_evidence(event_id)` and
  `catalog_direct_caller_evidence(event_id)`. This is the surface TD-13
  deferred: its entry records that the per-event entry points "close with
  TD-04's move of per-event data into the catalog rather than with a generic
  surface", and with every coordinate now in the catalog the generic surface is
  what was left to write. Thirteen validator call sites and six internal ones
  moved to them, and the D02/D03 validators no longer call the same lookup
  twice under two names while asserting different fields of it. A cataloged
  event now needs no method, constant or arm in the player.

  Dead code the earlier units left behind is removed in the same unit: seven
  per-event predicates that the generic `_is_confirmed_caller_return` and
  `_is_confirmed_caller_prefix` had already replaced but which were still
  defined and called by nothing, and nineteen constants — the six postlude
  boundaries plus thirteen already unreferenced before this work. A
  repository-wide scan over every `.gd`, `.tscn`, `.py`, `.json` and `.md`
  now finds **no unreferenced function or constant** in `event_player.gd`,
  including its signal handlers.

  | `event_player.gd` | Before | After |
  |---|---:|---:|
  | Lines | 18,645 | **18,505** |
  | Functions | 472 | **449** |
  | Constants | 696 | **677** |
  | `"EVENTxx"` literals | 61 | **41** |

  No `content_core` file, catalog datum or schema changes, so Core stays at
  `0.293.0` and catalog v7/revision 22 is untouched; this unit moves consumers
  onto data that was already there.

  The substitution is proved by checks that already existed rather than by new
  ones: the B01, D01 and D03 validators assert `caller_handoff.start_offset`
  against their own `0x1017`, `0x0851` and `0x0E62` expectations, so a
  `boundary_offset` that did not reproduce the deleted constant fails them.

  The full local batch passes **95/95** in 162.063 seconds — **1,288 Python
  tests**, project parsing and **93 Godot scenes**, including **765
  caller-catalog** and **240 shared caller-route** assertions. The focused
  original batch passes **10/10** in 559.186 seconds against the authoritative
  archive: source/caller bindings over 12 events, 26 unique entries, 9 caller
  routes and 23 terminal boundaries; ordinary Play for ten routes; B01, B02,
  B15, D01, D02 and D03 integration; fragment catalogs with EVENTD14's caller
  BGM and handoff; and twelve-event package equivalence (76 checks, 244
  dialogue boundaries, 488 message payloads). Source archives remain unchanged.
  Reports: `analysis/td04-caller-entry-points-local-validation.json` and
  `analysis/td04-caller-entry-points-original-validation.json`. This is focused
  original verification, not a new aggregate result for the whole archive
  group.

  **Callee source identity moved into the catalog, 2026-09-07.** The player
  kept its own copy of every cataloged event's callee identity: twelve
  `EVENT*_ENTRY_SHA256` constants and ten `EVENT*_EVENT_ANCHOR` constants, read
  at 176 sites. Measured immediately before removal, all 22 equalled that
  event's `source.callee.entry_sha256` and `source.callee.start_coordinate`,
  including `EVENTD05_EVENT_ANCHOR`'s `0x03F0`, the only nonzero one. None of
  them could follow a catalog revision.

  Core `0.295.0` adds `build_callee_source(event_id)` and
  `find_callee_source(callee_entry)` to `content_core/event_catalog.gd`. They
  project the callee entry, its hash and its start coordinate, and nothing
  else. `find_` applies the same uniqueness rule as
  `find_caller_route_specification`: a callee entry that two events claim
  resolves to neither. A callee with no `start_coordinate` — which the schema
  permits for `unresolved_route` — projects nothing rather than half an
  identity. No catalog datum and no schema change: v7/revision 22 is untouched.

  The player reads that projection through `_document_is_catalog_callee` at 88
  sites, `_catalog_callee_entry_sha256` at 12 and
  `_catalog_callee_start_coordinate` at 31. The ten cataloged
  `CONFIRMED_PREVIEW_ANCHORS` entries and both `CONFIRMED_ADDRESS_CATALOGS`
  entries now declare `CATALOG_SOURCED_ENTRY` instead of carrying a hash and a
  start offset of their own, and five functions that read
  `CONFIRMED_ADDRESS_CATALOGS` directly and repeated its hash comparison
  themselves now go through `_confirmed_address_catalog`, which already makes
  it. Every one of these paths fails closed: with the catalog unloaded there is
  no anchor, no address catalog and no callee match, where a frozen constant
  could not fail but could go stale. `EVENTD06`'s and `EVENTD14`'s
  `setup_start_coordinate` equals the same catalog number and was deliberately
  left alone: for D14 it describes the catalog-setup preview rather than the
  event start, so the two being equal does not make them one datum.

  New assertions take `test_event_catalog.tscn` from 86 to **116** and
  `test_event_player.tscn` from 1,081 to **1,148**. Four mutants were run
  against them and each was killed: the predicate without its empty-hash guard
  loses the no-hash document case; the anchor lookup without its catalog hash
  comparison loses all ten rejection assertions; the address catalog that does
  not take the catalog's hash loses both of its own; and an anchor that keeps
  whatever offset the table held loses all ten start-coordinate assertions.
  Two of the four are the guards this unit added rather than moved, which is
  why the mutation was run instead of assumed.

  The full local batch passes **95/95** in 165.774 seconds: **1,288 Python
  tests**, project parsing and **93 Godot scenes**. The two call-edit audit
  shutdown resource warnings recur unchanged. The focused original batch passes
  **14/14** in 1033.488 seconds against the authoritative archive: catalog
  source bindings over 12 events, 26 unique entries, 9 caller routes and 23
  terminal boundaries; ordinary Play for ten routes; B01, B02, B03, B14, B15,
  D01, D02, D03, D05 and D08 integration; fragment catalogs for EVENTD06's 66
  and EVENTD14's 65 fragments; and twelve-event package equivalence (76 checks,
  244 dialogue boundaries, 488 message payloads). Source archives remain
  unchanged. Reports: `analysis/td04-callee-identity-local-validation.json` and
  `analysis/td04-callee-identity-original-validation.json`. This is focused
  original verification, not a new aggregate result for the whole archive
  group.

  Recorded honestly: quoted `"EVENTxx"` literals rise from 41 to 172, because
  131 event ids moved out of constant names and into call arguments. That is a
  change of form, not of duplication — total event-id mentions in the file fall
  from 2,661 to 2,616 — and factoring the per-event code itself is TD-11's
  deferred decomposition rather than this item's work.

  | `event_player.gd` | Before | After |
  |---|---:|---:|
  | Constants | 677 | **656** |
  | Per-event constants | 592 | **570** |
  | Event-ID mentions | 2,661 | **2,616** |

  **Caller source identity moved into the catalog, 2026-09-07.** The player
  kept the caller half of the same `source` block: twelve `EVENT*_CALLER_ENTRY`,
  eight `EVENT*_CALLER_ENTRY_SHA256` plus the shared `AUDITED_12C_ENTRY_SHA256`
  that one of them aliased, nine `EVENT*_CALLER_DISPATCH_OFFSET` and eleven
  `EVENT*_CALLER_RESUME_OFFSET`. Measured immediately before removal, all 44
  equalled that event's `source.caller` field, including the four that B03, D05
  and D06 name `CALLER_HANDOFF_OFFSET`/`CALLER_HANDOFF_END` while holding the
  dispatch and resume coordinates.

  **The scope paragraph this unit replaces understated it by sixteen
  constants.** It named the dispatch and resume offsets and stopped. The other
  eight `EVENT*_CALLER_HANDOFF_OFFSET` and eight `EVENT*_CALLER_HANDOFF_TARGET`
  are not `source.caller` at all: they duplicate the catalog's own
  `caller_handoff` terminal, its `offset` and its `next_target`, which
  `build_caller_route_specification` has projected as `handoff_offset` and
  `handoff_target` since the B01/B02 unit. All sixteen matched, and they are
  removed here as well, so the measured scope was 60 constants at 161 read
  sites rather than 44.

  Core `0.296.0` adds `build_caller_source(event_id)` and
  `find_caller_source(callee_entry)` to `content_core/event_catalog.gd`. They
  project the caller entry, its hash, the dispatch and resume coordinates and
  the dispatch command, and nothing else. `find_` applies the same uniqueness
  rule as `find_callee_source`. An event whose `source` names no caller — which
  the schema permits for an `unresolved_route` or an `analysis_only` route —
  projects nothing rather than half an identity. No catalog datum and no schema
  change: v7/revision 22 is untouched.

  The player reads that projection through `_catalog_caller_source` and four
  field helpers, and `_is_catalog_caller_handoff(result, event_id)` replaces the
  eight per-event blocks in `_is_confirmed_preview_event_complete` that spelled
  out the same eight conditions eight times over. Both
  `CONFIRMED_ADDRESS_CATALOGS` entries now take their whole caller envelope —
  entry, hash, dispatch, resume and command — from the `CATALOG_SOURCED_ENTRY`
  resolution that already supplied their callee hash, so `caller_command` stops
  being a hand-written `0x0E`/`0x0F` beside the catalog's own `command`.

  One fail-open risk the move introduced was closed rather than accepted. Nine
  start validators build a `required_entries` map keyed by the caller entry
  name, and an unavailable catalog would have keyed it with an empty string,
  which the fingerprint loop satisfies with anything. Each now returns an
  explicit unavailable-caller error before building the map. The same reasoning
  gives `_is_catalog_caller_handoff` and `_is_catalog_caller_handoff_offset` an
  explicit absent-terminal guard: with no terminal the boundary reads `-1`, and
  a result carrying no offset would otherwise have compared equal to it.

  New assertions take `test_event_catalog.tscn` from 116 to **146** and
  `test_event_player.tscn` from 1,148 to **1,290**. **Eight mutants were run
  against them and each was killed**, named by the assertions that died: the
  projection that hands out half an identity instead of none loses the
  no-caller case; `find_caller_source` without its uniqueness rule loses the
  two-events-one-callee case; `_document_is_catalog_caller` without its
  empty-hash guard loses the no-hash document; both handoff predicates without
  their absent-terminal guard lose all three of B03, D05 and D06; the boundary
  taken from the dispatch instead of the terminal loses 28 assertions; and the
  address catalog that takes the callee hash, or the resume coordinate, for its
  caller loses its own two and four. A ninth mutant — deleting the address
  catalog's caller envelope outright — hangs rather than fails, because an empty
  caller entry reaches the parser; that shape is unreachable in the real code,
  since `_confirmed_address_catalog` returns nothing at all when the catalog
  cannot answer.

  | `event_player.gd` | Before | After |
  |---|---:|---:|
  | Lines | 18,530 | **18,503** |
  | Constants | 656 | **595** |
  | Per-event constants | 570 | **510** |
  | Event-ID mentions | 2,616 | **2,432** |

  Quoted `"EVENTxx"` literals rise from 172 to 209 for the same reason as the
  callee unit: 37 more event ids moved out of constant names and into call
  arguments. Total event-id mentions still fall by 184.

  Three helper wrappers the migration left with no caller were removed before
  the final runs, so a repository-wide scan over every `.gd`, `.tscn`, `.py`,
  `.json` and `.md` again finds no unreferenced function or constant in
  `event_player.gd` beyond its engine callbacks.

  The full local batch passes **95/95** in 161.161 seconds: **1,288 Python
  tests** in 125.505 seconds, project parsing and **93 Godot scenes**. The
  focused original batch passes **15/15** in 999.622 seconds against the
  authoritative archive, covering every route the change touches: catalog source
  bindings, ordinary Play, B01, B02, B03, B14, B15, D01, D02, D03, D05 and D08
  integration, fragment catalogs for D06 and D14 — the two address catalogs
  whose caller envelope moved — and twelve-event package export and playback
  equivalence. Source archives remain unchanged. Reports:
  `analysis/td04-caller-identity-local-validation.json` and
  `analysis/td04-caller-identity-original-validation.json`. This is focused
  original verification, not a new aggregate result for the whole archive group.

  **Required-entry identity moved into the catalog, 2026-09-07.** The third
  part of the same `source` block was thirteen frozen hashes of shared original
  entries. Measured before removal, each equalled the catalog's own
  `source.required_entries` record for that entry, and each of the catalog's
  eight required entries carries exactly **one** archive identity across all
  twelve events, which is what makes a lookup by entry name well founded.

  | Catalog entry | Player constants it was frozen in | Read sites |
  |---|---|---:|
  | `LIBLARY.LIB` | `AUDITED_LIBRARY_ENTRY_SHA256` | 32 |
  | `MAHOKO.WAV` | four `EVENT*_BGM_ENTRY_SHA256` | 9 |
  | `B_PIC.MES` | `EVENTB03_PICTURE_ENTRY_SHA256`, `EVENTB14_PICTURE_ENTRY_SHA256` | 7 |
  | `D_PIC.MES` | `EVENTD05_D_PIC_ENTRY_SHA256`, `EVENTD08_CALLER_RESTORE_ENTRY_SHA256` | 4 |
  | `DEF_MAIN.MES` | `AUDITED_DEF26_ENTRY_SHA256` | 5 |
  | `BAN.MMO` | `EVENTB14_FACE_MMO_ENTRY_SHA256` | 3 |
  | `B.AX` | `EVENTB14_AX_ENTRY_SHA256` | 3 |
  | `B1.MMO` | `EVENTB03_PICTURE_BASE_MMO_ENTRY_SHA256` | 1 |

  Core `0.297.0` adds `find_source_entry(entry)`. It answers **identity, not
  requirement** — which archive holds an entry and what it hashes to, never
  which events need it. That distinction is the whole design: the player uses
  `MAHOKO.WAV` in B01, B02, B14 and B15 and `B_PIC.MES` in B14, while the
  catalog records both only under B03, so a lookup keyed by (event, role) would
  have made the code assert a dependency the catalog has not measured. An entry
  two events record differently resolves to neither, and a callee entry is not
  a required entry and answers nothing here.

  `_is_catalog_source_entry(entry_sha256, entry)` carries every comparison and
  fails closed, because an unloaded catalog leaves no expected hash and an empty
  expected hash would otherwise have matched an empty document hash. Two
  `CONFIRMED_PREVIEW_ANCHORS` members are `const` data and cannot call a
  function, so `DEF_MAIN.MES` declares `CATALOG_SOURCED_ENTRY` as its source and
  EVENTD08's prelude anchor declares it as its `prelude_bgm_entry_sha256`; both
  resolve when the anchors are handed out, and an unresolvable name yields no
  anchor rather than one carrying the marker.

  **The entry names stay, and the reason is measured rather than assumed.**
  `MAHOKO.WAV` is spelled by four constants under four event prefixes,
  `B_PIC.MES` by three under two, `D_PIC.MES` by two. They are the lookup keys,
  not the looked-up data, so replacing them with a catalog call would take the
  name as its own key. Consolidating them is possible only if the catalog first
  records those events' use of the shared files, which is a data claim needing
  evidence rather than a refactor — **left for the owner** and noted below.

  New assertions take `test_event_catalog.tscn` from 146 to **181** and
  `test_event_player.tscn` from 1,290 to **1,315**. Five mutants were run and
  each was killed: `find_source_entry` without its disagreement guard loses the
  two-events-one-entry case; the same lookup widened to match callee entries
  loses the callee exclusion; `_is_catalog_source_entry` without its empty-hash
  guard loses the unloaded-catalog case; the anchor that keeps the marker
  instead of resolving it loses both of EVENTD08's; and the non-callee table
  entry that skips its identity check loses four, including one existing EVENTB03
  playback assertion.

  | `event_player.gd` | Before | After |
  |---|---:|---:|
  | Lines | 18,503 | **18,529** |
  | Constants | 595 | **582** |

  Lines rise by 26 because thirteen one-line constants became call expressions
  in fail-closed conditions plus one twelve-line resolver; the duplication they
  removed is 64 read sites, not lines.

  The full local batch passes **95/95** in 142.275 seconds: **1,288 Python
  tests** in 106.756 seconds, project parsing and **93 Godot scenes**. The
  focused original batch passes **16/16** in 1009.285 seconds against the
  authoritative archive: catalog source bindings, ordinary Play, all twelve
  events' integration, the DEF26 isolated body that `DEF_MAIN.MES`'s hash
  guards, fragment catalogs, and twelve-event package export and playback
  equivalence. Source archives remain unchanged. Reports:
  `analysis/td04-required-entries-local-validation.json` and
  `analysis/td04-required-entries-original-validation.json`. This is focused
  original verification, not a new aggregate result for the whole archive group.

  **Closed 2026-09-08 after scope reconciliation.** The committed and
  verified work above removed every measured duplicate of catalog source data.
  The owner-approved review order separates two feature requirements from that
  completed refactor: declaring additional shared-entry use and filling the
  currently empty media dependency arrays. `workspace_distribution.md` WD-21
  now owns both requirements and their source-audit/package-completeness gates.
  Existing identifier constants are not newly claimed to be catalog duplicates.
  No runtime behavior changed in this closure.

- [x] **TD-05 — Extract the copied infrastructure helpers (DIP/DRY).**
  Closed 2026-09-21 by the owner (option 1 of three): the Python command-line
  boilerplate is an accepted pattern, recorded below; the five units'
  extractions stand and the residue is measured and explained.
  Bounded progress on 2026-09-08: the package validator's route executor is now
  `content_core/mes_route_probe.gd`, available to contextual edited-event
  verification without copying its library/definition/choice handling. Original
  twelve-event bytecode/package equivalence and parsing pass (2/2,
  `analysis/route-probe-extraction-validation.json`). The wider item stays open.
  Measured by comparing normalized function bodies; only exact matches counted,
  so the real duplication is larger.

  | | Duplicate groups | Redundant copies |
  |---|---:|---:|
  | Python (`tools/`) | 14 | **99** |
  | GDScript (all) | 112 | **484** |

  Most-copied: `canonical_payload_bytes()` ×54 and `_sha256_file()` ×21 in
  Python; `_sha256()` ×44 plus a second variant ×38, `_is_sha256()` ×33,
  `_has_only_keys()` ×17 and `_read_bounded()` ×14 in GDScript. The
  `fingerprint()` body is character-identical across `plan_mes_*`,
  `compile_mes_*` and `diff_mes_*`.

  The CLI harness is copied whole as well: 123 `extends SceneTree` scripts, 132
  calling `OS.get_cmdline_user_args()`, 87 defining `_fail()` — of which 31
  share one identical body and 13 another. On the Python side, 121 tools build
  their own `argparse` parser and 107 print `json.dumps` output, with no shared
  module: `tools/` has no `__init__.py` and no `pyproject.toml`, so every test
  reaches it through `sys.path.insert(0, ROOT / "tools")`.

  One shared module per language plus one CLI entry helper removes most of it.

  **Scope split by the migration decision, 2026-09-06.** The GDScript half is
  not one job any more. Extract the authoring and instrument copies now; leave
  the 35 analysis files to `mes_analyzer.md` MA-10, because those files are the
  ones moving to Python and a GDScript helper written for them is discarded
  when they go. The Python half is unaffected and can be done at any time.

  **Authority measurement completed, 2026-09-06.** MA-10 is closed and Python
  now produces the authoritative complete handoff. The GDScript reference and
  instrument paths still exist; their files were not all retired by that
  measurement. MA-10 is no longer a pending dependency of this item. Keep the
  extraction focused on remaining consumers and avoid creating GDScript
  abstractions solely for the already established Python authority.

  **Unit 1, 2026-09-17, Core 0.341.0: the pure value checks.** Re-measured
  first, with the same exact-body method over functions of three lines or
  more: the day's eight authoring families and five report contracts had
  raised the GDScript figure to 149 groups and 678 redundant copies (418 of
  them in `content_core` and `tools/content_suite`, 2,311 lines).
  `content_core/contract_values.gd` (`KakyuContractValues`, static functions
  only) now holds `sha256`, `sha256_lenient`, `sha256_or_empty_digest`,
  `is_sha256`, `hash_values`, `all_hash_values`, `has_only_keys`,
  `has_exact_keys`, `has_only_key_set`, `has_exact_key_set`, `json_integer`,
  `nonnegative_json_integer`, `nonnegative_integer_values`, `all_true` and
  `decode_hex`. A one-shot tool removed a private copy only when its body
  normalized to a listed variant, its private callees resolved to listed
  variants too, no bare reference to it remained and no script extends the
  file. Two passes (the second caught the one-line bodies the first pass
  left once their callees were shared) removed 258 definitions from 82
  production scripts (43 `_is_sha256`, 37 checked, 23 unchecked and 4
  empty-tolerant `_sha256`, 25 `_has_only_keys`, 28 `_hash_values`, 33
  `_has_exact_keys`, 17 `_json_integer`, 17 `_nonnegative_json_integer`, 9
  `_integer_values`, 11 `_all_true`, 6 `_decode_hex`, 5 Dictionary key-set
  checks), 1,795 lines, every call site rewritten to the shared function.
  Production redundant copies fall from 418 to 226 and redundant lines from
  2,311 to 1,259; with the tests, 678 to 483.

  Variants that differ in meaning were kept apart rather than merged: the
  checked `sha256` returns "" for empty input because Godot refuses an empty
  chunk, the unchecked one returns the empty-message digest, so both exist
  under their own names, beside the empty-tolerant form three modules
  spelled three ways; the bounded `_json_integer` and
  `_nonnegative_json_integer` variants and the typed-key `_has_exact_keys`
  stay private, and so do the `_integer_values` copies and the
  `_valid_summary` bodies that sit on them. The `_is_sha256`
  spellings are one function (the extra `to_lower` comparison can never
  decide, the character set already refuses upper case). One behaviour
  changes on purpose: the copies of `_all_true` compared `value != true`,
  which raises a script error for a non-boolean value; the shared function
  refuses such a value cleanly. Tests keep their own hashers, so a test
  never checks the shared helper with itself.

  What the parse check cannot see, recorded because it cost a run: two
  callers outside the file - `tests/test_event_player.gd` and
  `validators/validate_event_player_eventb14.gd` - called the Event Player's
  private `_sha256` on the instance. GDScript resolves that at run time, so
  the scripts parsed and the scene then stopped on the missing method until
  its timeout. Both now call the shared function; a repository-wide search
  for member calls and quoted names of the removed helpers finds no other.
  Verified 2026-09-17: every changed script loads and instantiates (86 checked), `tests/test_contract_values.tscn` (46 checks), the local batch (119 checks, Python 1,542), and the whole original run with `--elfimage` and `--exe` - 358 of 358 checks in 7,428 seconds: 119 local, 228 original-archive, 12 native-executable, 8 native-with-archive and the voice payload check; only the exhaustive MES entry audit was skipped.

  **Unit 2, 2026-09-17, Core 0.342.0: the headless scripts' base.**
  `tools/content_suite/cli_script.gd` extends `SceneTree` and holds
  `_fail(message, code := 1)` and `_read_bounded(path, limit)`; a script
  extends it by path, the way the `audit_eventb03_*` chain already extends
  its root. `_fail` cannot be a static function because it calls `quit`, and
  GDScript refuses an override with a different signature, so the one-shot
  tool converted a script only when every copy it held was a listed variant:
  81 scripts under `cli/` and `validators/` now inherit the base, 81 `_fail`
  (the `(message)`, `(message, code)` and defaulted spellings, one function
  once the default exists) and 17 `_read_bounded` definitions are gone, 566
  lines. Twelve scripts keep `extends SceneTree` and their own `_fail`
  because it closes a reader, prints a JSON error line or is extended by
  another script. Converted scripts run without arguments still exit with
  their own codes (1 and 2 checked). Production redundant copies stand at
  133 (845 lines), from 418 (2,311) before unit 1; what remains is small
  and specific to a family (`_valid_summary`, `_same_plan_value`, the
  validators' `_archive_hashes`). Verified: all 82 changed scripts load and instantiate, the local batch (119 checks, Python 1,542), and the whole original run with `--elfimage` and `--exe` - 358 of 358 checks in 7,362 seconds, the exhaustive MES entry audit skipped as before.

  **Unit 3, 2026-09-18: the Python payload helpers.** Re-measured by exact
  AST over top-level functions of three lines or more: 22 groups, 134
  redundant copies, 1,044 lines, of which `canonical_payload_bytes` (54),
  `_is_sha256` (35 over three spellings) and `_sha256_file` (21) were almost
  all. `tools/payload_values.py` holds `canonical_payload_bytes`,
  `fingerprint`, `is_sha256` and `sha256_file` with the copied bodies
  unchanged - the JSON settings of `canonical_payload_bytes` are part of
  every contract that stores a `payload_sha256`. A one-shot tool replaced a
  definition only when its AST, with annotations dropped and bound names
  renamed, equalled a listed variant, and replaced it with an import under
  the same name (`from payload_values import is_sha256 as _is_sha256`), so
  every reference from another module or a test keeps resolving: 164
  definitions in 71 tools, 1,232 lines; `import hashlib` or `import json`
  left only where the file still uses it. `validate_mes_analyzer_handoff.py`
  keeps its `fingerprint` because its canonical form goes through
  `canonical_json_bytes`. The distribution copies every tracked `tools/*.py`
  and its isolated runtime already lists `../tools` on the path, so the new
  module ships without a packaging change. Python redundant copies fall
  from 134 to 35 (1,044 to 238 lines). No Core change: nothing under
  `content_core` or the Godot tools moved. Verified 2026-09-18: all 71 changed tools import, `tests/test_payload_values.py` (6 tests, including that two tools now share the very same function objects), the local batch (119 checks, Python 1,548), and the 29 original checks that execute Python tools - the full Phase 1-4 handoff equivalence, the four contextual authoring checks, package export and playback, the event analysis frontier and four analysis groups, the catalog analysis routes, the corpus inventory and every direct Python audit including the native ARC, MES and Ogg contracts - 29 of 29 in 2,159 seconds. The whole original run was last made for unit 2 (358 of 358).

  **Unit 4, 2026-09-18: the test scenes' base.** `tests/test_case.gd`
  extends `Node` with the `_failed` flag, `_check(condition, label)` and
  `_remove_tree(path)`; 81 test scripts extend it by path and lose their
  copies (81 `_check`, 81 flag declarations, 12 `_remove_tree`; 1,044 lines
  removed, 81 added). A test is converted only when its `_check` is the
  plain variant and `var _failed := false` is its only flag; 26 tests that
  count checks or failures keep `extends Node` and their own `_check`, and
  so does the one test another test extends. Tests keep their own hashers
  on purpose. GDScript redundant copies over production and tests stand at
  299 (2,043 lines), from 678 (4,124) before unit 1. Verified: the local
  batch passes 119 of 119 and prints the same 6,374 PASS lines as before
  the conversion. No Core change.

  **Unit 5, 2026-09-21, Core 0.360.0: the tests' synthetic ARC builders and
  the residue.** `tests/synthetic_arc.gd` (static: `write_arc`, `encode_name`, `append_u32`, `append_u16`, `write_ascii`, `append_registration`, the archive keys) replaces all 22 `_create_synthetic_arc` copies and `test_event_player_run_request.gd`'s `_create_arc` (six spellings and the two single-entry forms proven byte-identical on the same entries by a probe), 12 `_encode_name`, 13 `_append_u32`, 1 `_append_u16`, 8 `_write_ascii` and 5 `_append_registration`; `tests/test_helpers.gd` holds `color_close` and a delegate for `intify`; `content_core/contract_values.gd` gains `u32_hex`, `is_identifier`, `workspace_binding`, `checked_bytes` and `intify` (the last shared with `mod_definition_form.gd` and `mod_definition_panel.gd`; 14 definitions out of twelve modules). Kept private with reasons: the `_fail` / `_error` bodies that set their own instance's `last_error`, the 32-bit-bounded `_json_integer` and the typed-key `_has_exact_keys` variants of unit 1, `_valid_summary` (each closes over its file's `SUMMARY_KEYS`), `_same_plan_value`, the tests' own hashers. The conversion tool lacked unit 4's extended-by-another-script guard: `test_mes_editor.gd` is the base of the eight authoring scenes, whose inherited call site was fixed by hand. Measured by `analysis/_td05/measure_gd_duplicates.py` (exact bodies of three lines or more): groups 129 -> 112, redundant copies 297 -> 238, redundant lines 2,067 -> 1,540; the Python side unchanged since unit 3. Verified 2026-09-21: the equivalence probe (`ALL_PASS`), the parse check, `--tier local --cache-store` 134 of 134 (289 s), `--tier archive_quick --cached` 202 of 203 (the one timeout was `original EVENTB03 preset reduction matrix`, a validator calling a player function EP-10 unit 5c had deleted - retired the same day), `original event analysis groups` 149 of 149; the pre-commit review's findings fixed.

  **Ruling, 2026-09-21, by the owner (option 1 of three): the Python
  command-line boilerplate is an accepted pattern.** Of the 139 `main()`
  functions under `tools/`, 65 print one JSON line with no `try`, 24 print
  text lines under a `try`, 18 print JSON under a `try` (a
  `{"ok": false, "error": ...}` line and exit 1 on failure), 17 print
  text lines with no `try`, and 15 differ again (always 0, exit 2, an
  `indent=2` file). Each tool's standard output and exit code are its
  contract - Godot validators parse the JSON lines, the batch reads the
  codes, the README documents the command lines and the tests drive
  `main()` - so a shared entry helper would have to reproduce every
  variant exactly for a saving of three or four skeleton lines per tool,
  and the exact-body duplicate measurement does not count the skeleton
  (it is interleaved with each tool's own lines). The convention: a tool
  owns its `argparse` parser and prints its own JSON or lines; the shared
  helpers are the values (`tools/payload_values.py`), not the entry.

- [x] **TD-06 — Give `fingerprint()` a home that matches its name (ISP).**
  41 modules preload `content_core/mes_noop_compile_reopen.gd`, 37 of them
  aliased `FingerprintScript`, 3 `ReopenAuditScript`, 1 `EntryReopenScript`.
  That file is a 326-line no-op compile-reopen auditor with `audit()` and
  `validate_compile_audit()`; it became the repository's fingerprint utility
  only because `fingerprint()` happens to live in it. Every one of those 41
  modules is coupled to a class whose real subject it does not use. Move
  `fingerprint()` and `canonical_payload_json()` into a module named for what
  they are, and let the auditor depend on it like everything else.

  **Closed 2026-09-06.** Core `0.294.0` adds
  `content_core/mes_payload_fingerprint.gd`, 48 lines holding `fingerprint()`,
  `canonical_payload_json()` and the two private helpers they need. The
  measurement the entry predicted holds exactly: of the 41 modules, **37 called
  nothing but `fingerprint()`** and all 37 were the ones aliasing it
  `FingerprintScript`. Those 37 now preload the new module. The remaining four
  are the auditor's real clients — `mes_noop_corpus_reopen.gd`,
  `validate_mes_noop_compile.gd` and two of its test scenes — and they keep
  preloading the auditor, which now delegates rather than duplicating, so their
  `fingerprint()` calls resolve to the same code. Coupling to a class whose
  subject the caller does not use falls from **41 modules to 4**.

  The extraction cannot change a single stored hash, because every versioned
  audit, plan and report in the repository names itself by this function: the
  moved bodies are byte-identical and the auditor delegates to them. That is
  what the batch checks, not the file layout.

  **One number moves the wrong way and is recorded rather than hidden.** Exact
  duplicate GDScript function bodies go from 483 to **484**, because the new
  module needs its own `_sha256()` and the repository still has no shared
  hashing helper — the 38-copy checked variant becomes 39. TD-06 could not fix
  that without doing TD-05's job; it is the same debt seen from the other side,
  and it is why TD-05 remains the larger lever.

  Verified: the full local batch passes **95/95** in 167.681 seconds — **1,288
  Python tests**, project parsing and **93 Godot scenes**. The focused original
  batch passes **4/4** in 670.133 seconds, chosen for the checks that recompute
  fingerprints rather than merely read them: the **whole-corpus analyzer handoff
  audit** over all 1,016 entries, catalog source bindings, MES Editor
  integration, and twelve-event package equivalence. Source archives unchanged.
  `content_core` still has zero references into `tools/` and every `class_name`
  remains unique. Reports: `analysis/td06-fingerprint-local-validation.json` and
  `analysis/td06-fingerprint-original-validation.json`.

- [ ] **TD-07 — Replace the Dictionary context blobs with typed parameters (ISP).**
  Deferred by the owner on 2026-09-18 (option 1 of three): the six runners
  are the original player's path, the original player is an analysis
  instrument, and the change is one unit per runner with the event runner
  referenced by 38 files. It reopens when a runner's context is touched for
  another reason. The measurements below stand.
  `mes_event_runner.gd` reads 8 keys out of `preview_context`
  (`address_table_offsets`, `argument_slots`, `code_source`,
  `native_record_policy`, `native_record_stop_offsets`, `native_stream_policy`,
  `persistent_expression_stack`, `protagonist_name`). A caller cannot discover
  the shape, nothing type-checks it, and a misspelled key silently becomes a
  default. The `{ok, error}` result convention is good and should stay; it is
  the input side that needs a declared shape.

  **Measured 2026-09-07, and it is worse and more structured than the entry
  said.** The eight keys of `preview_context` reproduce exactly.
  `mes_registered_definition_runner.gd` reads **13**, not 10. And every one of
  the **ten** context parameters across the six files is declared `:= {}`, with
  no `Dictionary` annotation at all, so the type is not merely unhelpful — it is
  absent:

  | File | Parameters | Keys read |
  |---|---|---:|
  | `mes_event_runner.gd` | `run(preview_context)` | 8 |
  | `mes_library_runner.gd` | `run`, `resume`, `_make_continuation` | 8 + 3 |
  | `mes_registered_definition_runner.gd` | `run`, `resume` | 13 |
  | `mes_registered_definition_call.gd` | `run` | 4 |
  | `mes_script_call_runner.gd` | `run`, `resume` | 11 |
  | `mes_detached_definition_preview.gd` | `run` | 8 |

  **The six are not one shape, which decides the remedy.** Only
  `argument_slots` and `persistent_expression_stack` are read by all six.
  `start`, `update` and `finish` — the progress callbacks — appear in four;
  `code_source` in three; `address_table_offsets`, `protagonist_name` and
  `registered_definitions` in three each. The rest are per-runner:
  `native_record_stop_offsets` only in the event runner, `dialogue_policy` and
  `local_definition_choices` only in the script-call runner, the two
  `registered_definition_native_*_policy` keys only in the registered-DEF
  runner. One nineteen-field context class would recreate the interface-
  segregation problem this item is about, so the shape to write is a small
  shared base and one declared type per runner.

  **Sizing, measured the same day.** `mes_event_runner.gd` is referenced by 38
  files, `mes_library_runner.gd` by 12, and the other four by 5, 5, 3 and 2. So
  this is one unit per runner rather than one change, and the event runner —
  the entry's own example — is the largest of the six.

- [x] **TD-08 — Give the parallel plan and reopen families a shared contract.**
  Closed 2026-09-18 by owner ruling (option 1 of three) on the re-measurement
  below: the copied helper block was the debt and TD-05 unit 1 removed it;
  the large functions are each family's contract, and no base class is
  built. A new family uses `content_core/contract_values.gd` and writes its
  own `validate`, `audit` and `validate_compile_audit`.
  `content_core` holds 9 `*_edit_plan.gd` and 13 `*_compile_reopen.gd` modules
  with no common base class or interface.
  `mes_state_literal_edit_plan.gd` and `mes_condition_literal_edit_plan.gd` are
  **both exactly 356 lines** with the same constant blocks
  (`PLAN_KEYS`/`OPERATION_KEYS`/`TARGET_KEYS`/`COMPATIBILITY`/`INVARIANTS`), the
  same `validate()` and `_validate_bytes()` shape, and their own private copies
  of `_has_exact_keys`, `_has_only_keys`, `_hash_values`, `_json_integer`,
  `_nonnegative_json_integer`, `_is_sha256`, `_sha256` and `_decode_hex`.
  Adding a twenty-third family means writing all of that again. Depends on
  TD-05 for the shared helpers.

  **Re-measured 2026-09-18, after TD-05 unit 1 took the helpers.** The copied
  helper block this entry describes is gone: the nine plans and thirteen
  reopen modules now call `content_core/contract_values.gd`, and what they
  still share by name is two-line glue (`_error` in all 22, the delegating
  `fingerprint` in 12) and six identical 12-line `_valid_summary` bodies. The
  large functions are not one shape spelled many times:

  | Function | Files | Lines each | Pairwise line similarity (mean, min-max) | Lines common to all |
  |---|---:|---:|---|---:|
  | `audit` (reopen) | 13 | 80-112 | 0.59 (0.28-0.86) | 26 |
  | `validate_compile_audit` (reopen) | 13 | 59-147 | 0.33 (0.12-0.70) | 4 |
  | `validate` (plan) | 9 | 69-146 | 0.38 (0.21-0.63) | 18 |

  A base class would hold the 26 common lines of `audit` behind a template
  method and nothing of the two validators, whose bodies are the contract of
  each family. The key constants (`PLAN_KEYS`, `OPERATION_KEYS`,
  `TARGET_KEYS`, `COMPATIBILITY`, `INVARIANTS`) have the same names and
  different contents in every file. The owner closed the item on that the
  same day, as resolved by TD-05.

- [x] **TD-09 — Separate the GUI applications from the headless CLI scripts.**
  `tools/content_suite/` held 144 GDScript files in one directory. Splitting it
  makes TD-05's harness extraction obvious rather than exploratory.

  **The entry's dependency claim does not survive checking, measured
  2026-09-06.** It said the two kinds "share no run mode, no lifecycle and no
  dependencies". The first two hold. The third does not:

  | Group | Files |
  |---|---:|
  | GUI applications, launcher and panels | 10 |
  | Helpers (neither `SceneTree` nor a node) | 5 |
  | **CLI scripts that instantiate a GUI application** | **23** |
  | Pure headless CLI | 106 |

  **Re-measured 2026-09-07.** The load-bearing number reproduces exactly: 144
  files, 23 CLI scripts instantiating a GUI scene, 19 of them
  `event_player.tscn` and one each for the ARC Browser, MES Editor, Image
  Editor and Audio Editor. Two rows moved. `audit_eventb03_affection.gd`,
  `audit_eventb03_preset_choices.gd` and `audit_eventb03_face_flags.gd` are not
  helpers: each `extends` another script in this directory, and the chain roots
  in `audit_eventb03_state12.gd`, which is a `SceneTree` CLI script. A classifier
  that reads only the immediate `extends` line counts them as helpers; they are
  headless CLI, and they are the only script-inheritance chain in the directory,
  so any split must move all four together.

  Two more facts the split needs, measured the same day. The validation runner
  invokes **77 of the 144**; the other 67 are run by hand or by another script,
  so "validator" is a real grouping but not the same as "everything that is not
  an app". And the shared helpers are few and named for it:
  `tool_path_history.gd` (7 referents) and `tool_window_profile.gd` (6) are the
  only files more than two others reach, which is what makes TD-05's harness
  extraction cheap once this line is drawn.

  Nineteen of the 23 drive `event_player.tscn`; the other four drive the ARC
  Browser, MES Editor, Image Editor and Audio Editor. A two-way `gui/` and
  `cli/` split would therefore put 23 files on the CLI side that reach across
  the boundary, and the directory structure would assert an independence the
  code does not have — worse than the flat directory, which at least claims
  nothing.

  That dependency is not accidental. It is the one TD-13 recorded as what it did
  not deliver: the instrument's evidence is reachable only by instantiating its
  UI, which TD-11 owns and the owner deferred. Splitting the directory does not
  remove the edge, it only makes it cross a directory.

  **So the split's shape is a decision, not a mechanical step.** Three-way —
  `apps/`, `validators/`, `cli/` — is honest about the 23. Two-way, with the 23
  grouped beside the applications they drive, is honest too and smaller. Doing
  the naive `gui`/`cli` split is the one option the measurement rules out.

  **Split done three ways, 2026-09-08, on the owner's ruling.** The owner chose
  the three-way shape. `tools/content_suite/` now holds three directories and
  the shared harness:

  | Directory | Files | What it holds |
  |---|---:|---|
  | `apps/` | 10 scripts + 7 scenes | The GUI applications, the launcher and the panels |
  | `validators/` | 23 | The CLI scripts that instantiate a GUI application |
  | `cli/` | 106 | The headless CLI scripts |
  | (root) | 5 scripts and the harness | `tool_path_history`, `tool_window_profile`, `playback_package_export`, `validation_report`, `validation_session`, plus the Python and PowerShell runners |

  The five shared scripts stay at the root deliberately. `tool_path_history.gd`
  and `tool_window_profile.gd` are reached from both `apps/` and `cli/`, so
  filing them under either would make one directory depend on the other's
  internals. Leaving them where both can see them keeps the structure honest and
  marks exactly what TD-05 extracts.

  `validators/` is the row that earned the three-way shape. Those 23 run
  headless and are invoked like any other CLI check, but each instantiates a GUI
  application — 19 of them `event_player.tscn`, one each the ARC Browser, MES
  Editor, Image Editor and Audio Editor. A two-way `gui`/`cli` split would have
  filed them as CLI and had the structure assert an independence the code does
  not have. Naming the row says the dependency out loud instead.

  The move is mechanical and complete: 146 files moved with their `.uid`
  siblings (285 `git mv` operations) and **317 path references rewritten across
  99 files** — scenes, tests, the launcher, the specifications, the event
  catalog's producer references and `project.godot`'s main scene.
  `run_headless_validation.py` builds its Godot invocation from a script name,
  so its 78 script names are now group-qualified; nothing else constructs a
  `content_suite` path dynamically. A repository-wide scan finds **no
  unqualified reference to a moved file and no reference pointing at a file that
  does not exist**.

  Verification is the whole batch rather than a focused subset, because the
  change is precisely whether every script can still be found and run. Godot
  re-imports and parses the project with no error. The complete run passes
  **174/174** in 3803.0 seconds — 95 local checks including **1,288 Python
  tests** and **93 Godot scenes**, and the entire `--elfimage` group at
  **79/79**. The exhaustive MES entry audit, skipped in that run, passes
  separately as **1/1** in 22.1 seconds, so all **80** original checks pass over
  the moved tree. Source archives remain unchanged. Reports:
  `analysis/td09-split-local-validation.json`,
  `analysis/td09-split-original-validation.json` and
  `analysis/td09-split-event-corpus-validation.json`. The native-executable
  checks still need `--exe` and remain unrun.

- [x] **TD-10 — Move `audit_ai5_mes_exe.py`'s address tables out of code.**
  Closed 2026-09-18 by owner ruling (option 1 of three): `EXPECTED_BYTES`
  moved to data on 2026-09-08, `EXPECTED_U32` keeps its symbolic relations in
  code by the earlier ruling, and the last half does not survive the
  2026-09-18 measurement at the end of this entry - the repeated checks stay
  spelled out.
  39,161 lines, of which **`_audit_payload()` alone is 20,512** starting at
  `:18626`, with 951 distinct local assignments, 822 `if` statements, 945
  comparisons and a single `return`. Another 15,598 lines are 2,233 top-level
  constant assignments. The content is reverse-engineering evidence and belongs
  in the repository; it does not belong in a function body.

  **The remedy this entry proposed does not survive checking, measured
  2026-09-07.** It said moving "the tables" to data files would leave roughly a
  thousand lines. The three tables are not one kind of thing:

  | Table | Lines | Entries | Keys naming a constant | Values naming a constant |
  |---|---:|---:|---:|---:|
  | `EXPECTED_BYTES` | 3,796 | 991 | 286 | 45 |
  | `EXPECTED_U32` | 1,019 | 292 | 281 | 269 |
  | `EXPECTED_CALLS` | 260 | 145 | 43 | 75 |

  `EXPECTED_BYTES` is mostly literal — a plain address-to-bytes table, and a
  genuine data-file candidate. `EXPECTED_U32` is the opposite: 281 of its 292
  keys and 269 of its values are expressions over named constants, such as
  `CAI5DOC_VIRTUAL_BASE_VTABLE - 4: CAI5DOC_VIRTUAL_BASE_RTTI_LOCATOR`. Flattening
  that to numbers would delete the relation the entry states and leave a column
  of addresses, which is **less** reviewable by diff, not more — the opposite of
  this item's stated purpose. The tables also carry 100 `**` unpackings of other
  constants, so extraction is not a copy of the literal text either.

  So the item splits in two, and only one half is mechanical:

  1. **`_audit_payload`'s repetition, which needs no decision.** 519 of its 732
     direct `if` statements are exactly `local != CONSTANT` with a single
     `failures.append(label)` body, and 730 of 732 have a single-append body.
     781 of its 837 direct assignments are calls, concentrated in eight probe
     helpers — `_site_inventory_sha256` (207), `_bounded_virtual_slot_load_call_sites`
     (67), `_sites_in_extents` (50), `_literal_u32_sites` (32) and the rest. That
     is a check descriptor — probe, arguments, expected constant, label — and a
     table of descriptors iterated once would keep every name and every label.
  2. **How far to flatten the tables, which is a decision.** It trades the
     symbolic relations in `EXPECTED_U32` against file size, and it is a
     judgement about what form this repository wants its evidence in.

  **Twelve constants are loaded nowhere**, measured the same day, in the file or
  anywhere else in the repository: `ASYNC_OUTPUT_PIN_FILE_SIZE_CALL_SITE_SHA256`,
  four `COMMAND_0E_*` boundaries, `COMMAND_0E_APPLICATION_VIEW_SCREEN_TO_CLIENT_*`,
  `PRESENTATION_SUBCOMMAND_0_HANDLER_END` and four `SCRIPT_FILE_*_LOCAL_OFFSET`
  offsets. They are dead as code but they are recorded measurements.

  **Retained, 2026-09-08, by the owner's ruling:** a constant that was obtained
  as evidence stays even when nothing references it. Being unreferenced makes it
  dead code; it does not make it wrong, and this repository's value is in the
  measurements it can still show. So "unreferenced" is not a reason to delete
  here, and a future unreferenced-symbol sweep of this file must exempt them.

  Verification for any of this is strong and cheap: `audit_ai5_mes_exe.py --json`
  against `AI5WIN.original.exe` emits a 1,147,913-byte report, so a faithful
  restructuring reproduces it byte for byte.

  **`EXPECTED_BYTES` extracted, 2026-09-08, on the owner's ruling.** The owner
  chose to move that table only and leave `EXPECTED_U32`'s symbolic relations in
  code. The split inside the table follows the same rule: an entry is data only
  when **both** its address and its payload are plain literals, because an entry
  whose key names a constant would lose its name to a bare address. That is 699
  of the 1,000 syntactic entries; the other 301 — 241 named keys, 45 named
  values, 9 `**` unpackings and 6 readable byte-string literals such as
  `b"kokuhaku.wav\x00"` — stay exactly where they were.

  **Three addresses were declared twice with different payloads**, found while
  extracting: `0x0044C770`, `0x00438D73` and `0x00406D43`. Python dict
  semantics keep the last, so three earlier expectations were dead and the audit
  has been checking 997 distinct addresses while the file listed 1,000. The
  extraction preserves that exactly — the table is built from the winning
  payload and 696 distinct addresses — so this records the defect rather than
  changing what is audited.

  **The same ruling applies to those three, 2026-09-08.** The first extraction
  dropped the overwritten payloads, which was a deletion of measured evidence.
  They are restored as `shadowed_entries` in the data file: address, the
  superseded payload, the payload that superseded it, and why it is not audited.
  They are 43, 68 and 30 bytes against live expectations of 18, 46 and 103. The
  loader validates them — each must name a live expectation, must differ from
  it, and must name the right winner — but does not return them, so what the
  audit checks is unchanged and the evidence can no longer rot unnoticed.
  Restoring them *as expectations* would change what the table has always
  checked and is a separate question.

  `config/ai5_exe_audit/expected_bytes_v1.json` holds those 696 pairs sorted by
  address, 115,414 bytes, under `kakyu_ai5_mes_exe_expected_bytes/v1`.
  `_load_expected_bytes()` reads it and **fails closed**: an unknown schema, a
  header count disagreeing with the audit, an entry list of a different length,
  a repeated address or a missing file all raise rather than let the audit check
  fewer addresses than it claims to. Six tampered inputs were run against those
  guards and every one was rejected, including the two different count
  mismatches and a payload zeroed in place. Six more were run against the
  shadowed-evidence guards and all six were rejected too — a record dropped with
  or without its header, one naming no live expectation, one whose payload does
  not differ from the winner, one naming the wrong winner, and the evidence
  deleted outright.

  | `audit_ai5_mes_exe.py` | Before | After |
  |---|---:|---:|
  | Lines | 39,161 | **36,676** |
  | `EXPECTED_BYTES` in code | 3,796 lines | **1,274** |

  The audit reproduces its report **byte for byte**: 1,147,913 bytes,
  `3b094b9b7bae6cd6d82491b9a29cbf9b45449c969780cea8dc92f30853b4eb71` before and
  after. The batch passes **99/99** in 166.4 seconds — the 95 local checks
  including **1,288 Python tests**, and the four native-executable checks, which
  `TODO.md` had recorded as unrun and which run here for the first time because
  they need `--exe`. Among them is `original executable native MES contract`,
  which is this audit. Report:
  `analysis/td10-expected-bytes-local-validation.json`. The original-archive
  group needs `--elfimage` and was not part of this run; nothing in this change
  reaches it.

  **TD-10 remains open** for the half that needs no decision: `_audit_payload`'s
  519 repeated `local != CONSTANT` checks are still spelled out one at a time.

  **That half does not survive measurement either, 2026-09-18.** The count
  reproduces: 519 checks of exactly that shape with a literal label, 2,598
  lines of the function's 20,512. But a descriptor table cannot replace them:
  417 follow their assignment directly, and only 10 of the 519 locals are
  used by the check alone - the other 509 also feed the report, so every
  assignment stays where it is. What is left is a one-call spelling,
  `_expect(failures, local, CONSTANT, "label")`, and with this file's names
  none of the 519 calls fits in 88 columns; wrapped one argument per line
  they take 3,114 lines, 516 more than the `if` statements they would
  replace. The mechanical half would lengthen the file and change nothing the
  audit reports. The owner closed the item on that the same day.

- [x] **TD-11 — `tools/content_suite/apps/event_player.gd` decomposition.**
  **Closed 2026-09-19 by owner ruling (option 1 of two)** after units 1, 2 and
  2b: the mechanical half is done - 18,344 -> 15,348 lines, 458 -> 357
  functions, fourteen modules, no module referencing the player - and the
  UI-touching half (B14 27 functions / 2,351 lines, B03 17 / 1,265, plus
  17 non-UI writers of AX and camera fields) stays in the scene script,
  because splitting each into a computation and a presentation is a
  judgment per function whose value to an analysis instrument does not
  justify the cost. The record below is the measurement and the three
  units.
  18,894 lines, 455 functions, 723 constants, 51 preloads, 70 `@onready` node
  references, `extends Control`. One UI class performs archive reading, MES
  decoding, event execution, audio state, camera control, validation and
  presentation. Largest functions: `_show_result()` 770 lines,
  `_capture_continuation()` 553, `_validate_eventb14_start()` 323,
  `_present_preview_result()` 290.

  **The owner ruled on 2026-09-05 that this file is not decomposed in this
  phase**, and the split plan names it the largest single cost it deferred.
  The item is recorded, not scheduled. TD-04 removes a large share of the volume
  without touching the structure and should happen first either way.

  Two things changed the shape of this item on 2026-09-05 without scheduling it.
  The remake deleted its copy, so this repository is the file's only owner. And
  [Product roles](../docs/spec/tech/product_roles.md) settled what the file is:
  an **instrument of the analysis**, not a product runtime. The split plan had
  expected its playback half to become the mod player's game runtime, which made
  the decomposition a prerequisite for someone else's product; that expectation
  is withdrawn, because the mod player consumes the playback package and cannot
  be grown from an interpreter of original bytecode. The decomposition is now
  worth exactly what it is worth to the analyzer, and nothing is waiting on it.

  **Feasibility measured 2026-09-08, at the owner's request.** The question was
  whether this class can be split at all. It can, but not along the axis the
  entry implies. `extends Control` suggests a UI/logic line; the code does not
  fall that way.

  | Group | Functions | Lines |
  |---|---:|---:|
  | Touch a UI node or the scene tree | 134 | 6,656 |
  | Touch no UI at all | **335** | **10,563** |
  | — of those, touching no instance state either | 128 | 1,424 |
  | — touching exactly one state cluster | 83 | 2,750 |
  | — straddling two or more | 98 | 5,808 |

  Fifty-seven percent of the body by line touches no UI, so a decomposition is
  not blocked by the `Control` base. Three state clusters account for almost all
  of it: a **source** cluster (`_reader`, `_parser`, `_resolver`, `_content_set`,
  `_document`, `_selected_entry`, `_library_index`, `_library_document`), a
  **run** cluster (`_state`, `_runner`, `_preview_event_session`, the choice and
  result fields) and a small **catalog** cluster. Fifty-five functions and 2,188
  lines touch only source, 16 and 358 only run, 12 and 204 only catalog.

  **The block that does not partition is the largest one:** 87 functions and
  5,321 lines need both source and run. They are the per-event validators and
  probes — `_validate_eventb14_start` at 326 lines, `_eventb14_picture_route_probe`
  at 195, `_validate_eventd01_start` at 194 — and no state boundary separates
  them, because establishing an event's evidence means reading its source *and*
  executing it.

  **They partition on a different axis: the event.** Of the 335 UI-free
  functions, **144 carry an event id in their name and account for 6,301 lines**,
  against 191 generic functions and 4,262 lines. The distribution is very uneven,
  and that is the useful part:

  | Event | Functions | Lines | | Event | Functions | Lines |
  |---|---:|---:|---|---|---:|---:|
  | EVENTB14 | 44 | 2,232 | | EVENTD01 | 7 | 322 |
  | EVENTB03 | 31 | 1,525 | | EVENTB15 | 8 | 308 |
  | EVENTB02 | 12 | 440 | | EVENTD02 | 7 | 266 |
  | EVENTB01 | 12 | 366 | | EVENTD08 | 6 | 262 |
  | | | | | EVENTD03 | 5 | 237 |
  | | | | | EVENTD05 | 6 | 204 |
  | | | | | EVENTD14 | 6 | 139 |

  B14 and B03 alone are 3,757 lines, 36% of the UI-free body. Only 24 of the 134
  UI-touching functions carry an event id, so the presentation half is already
  generic — the per-event mass is entirely in the evidence half, which is
  precisely what TD-04 has been thinning as coordinates moved into the catalog.

  **So the shape is two axes, not one.** Per concern for the generic 4,262 lines
  — pure helpers, source, run, catalog — and per event for the 6,301 that name an
  event. The first step that needs no decision and carries no behavioural risk is
  the **128 functions and 1,424 lines that touch neither UI nor instance state**:
  they are already free functions in all but syntax, and the existing scene
  assertions cover them. The source cluster's 55 functions and 2,188 lines are
  the natural second step.

  This is a measurement, not a plan to execute: the decomposition itself stays
  deferred until the owner says otherwise.

  **Scheduled 2026-09-19** by the owner ("1부터": TD-11 first among the remaining
  lines), which supersedes the 2026-09-05 deferral. The plan follows the
  two axes above, one behaviour-neutral unit at a time, with the scene
  test (1,288 checks) and the ten original Event Player checks as the
  gate; the state stays on the player throughout, because tests and
  validators reach 99 of its members by name.

  - **Unit 1, 2026-09-19: the pure rules.** Re-measured as the closure of
    functions that read no instance member, touch no node or tree and call
    only such functions: 41 functions, 652 lines, 29 constants (the
    2026-09-08 count of 128 admitted functions that read instance state).
    They moved into three static modules - `tools/content_suite/event_player_rules.gd`
    (`KakyuEventPlayerRules`, 24 generic functions, the two PROMISE tables),
    `event_player_eventb03.gd` (`KakyuEventPlayerEventB03`, 7 functions, 15
    constants including `EVENTB03_BRANCH_ROUTES` and the four constants its
    literal embeds) and `event_player_eventb14.gd` (`KakyuEventPlayerEventB14`,
    10 functions, 12 constants) - bodies byte-identical except the module
    and constant references, no wrapper left behind, the dependency running
    one way (the player references the modules, never the reverse). The
    scene test called 13 of them and read one constant directly on the
    player; those 58 sites now call the modules with the same arguments.
    `event_player.gd`: 18,344 -> 17,617 lines, 458 -> 417 functions.
    Verified: `tests/test_event_player_rules.tscn` (46 synthetic checks),
    the scene test 1,288/1,288, the run-request scene 18/18, the ten
    original Event Player checks (PROMIS, catalog playback, B01, B02, B14,
    B03 zero-state, B03 presets, D01, D05, fragment catalogs), the local
    batch 128/128.
  - **Unit 2, 2026-09-19: the read-only evidence functions.** Measured the same
    day: 61 per-event functions (1,506 lines) and 11 generic source helpers
    (122 lines) read only the source and run clusters (`_document`,
    `_selected_entry`, `_library_index`, `_library_document`, `_state`,
    `_runner`, `_preview_event_session`, `_preview_definitions`,
    `_event_catalog`, `_catalog_playback_request`, `_startup_context`,
    `_reader`, `_resolver`, `_content_set`, `_parser`) and write nothing.
    `tools/content_suite/event_player_evidence.gd` (`KakyuEventPlayerEvidence`)
    holds those fifteen references, built by the player's `_evidence()` per
    call, and carries the eleven helpers as its methods
    (`document_is_catalog_callee`, `is_catalog_source_entry`,
    `indexed_routine_boundary`, ...); the player keeps a one-line delegate
    for each, since its UI and run code call them from 88, 51, 23, ...
    sites. The 61 functions became statics with `evidence` as their first
    parameter in `event_player_eventb03.gd` (+10) and `_eventb14.gd` (+7)
    and nine new modules (`_eventb01` 10, `_eventb02` 5, `_eventb15` 6,
    `_eventd01` 4, `_eventd02` 6, `_eventd03` 4, `_eventd05` 3, `_eventd08`
    2, `_eventd14` 4), no wrapper left; the scene test's 58 direct calls
    into 13 of them call the modules with `player._evidence()`.
    `event_player.gd`: 17,617 -> 16,054 lines, 417 -> 357 functions.
    Verified: `tests/test_event_player_evidence.tscn` (45 checks, the
    catalog read from the tracked `original_events_v1.json`, which holds
    no original data), the scene test 1,288/1,288, run-request 18/18,
    rules 46/46, fourteen original Event Player checks (B01, B02, B14,
    B15, D01, D02, D03, D05, D08, B03 zero-state, B03 presets, catalog
    playback, fragment catalogs, DEF26 body), the local batch 129/129.
    The moved functions read 145 event-specific and 4 shared player
    constants, which the unit qualified as `KakyuEventPlayer.X` - a
    reference back into the scene script, undone the same day:
  - **Unit 2b, 2026-09-19: the event constants follow their functions.** Every
    event constant of the player (472 of its 555, plus
    `D_PIC_DEFAULT_STANDING_MMO`, which EVENTD05's block references) moved
    into its event module, literal byte-identical with its comment, and
    the four shared evidence constants (`CONFIRMED_ADDRESS_CATALOGS`,
    `CATALOG_SOURCED_ENTRY`, `AUDITED_MES_ARCHIVE_SHA256`,
    `AUDITED_STARTUP_CONTEXT_SELECTORS`) into the evidence module; the
    player's 868 remaining references and the scene test's five
    `player.EVENTB03_SE_*` reads are module-qualified. No module references
    `KakyuEventPlayer` any more (`grep -c "KakyuEventPlayer\."` is 0 in all
    thirteen); the one cross-reference left is the evidence module's
    address catalog reading two D14 constants. `event_player.gd`: 16,054
    -> 15,348 lines, 357 functions. Verified: the four scenes (evidence 45,
    rules 68, scene test 1,288, run-request 18), the fourteen original
    checks, the local batch 129/129.

  **Where the file stands after units 1 to 2b, 2026-09-19:** 15,348 lines and
  357 functions, from 18,344 and 458 - 3,000 lines and 101 functions moved
  into fourteen modules. What remains per event is the UI-touching half:
  EVENTB14 27 functions / 2,351 lines and EVENTB03 17 / 1,265 (the
  `_validate_*_start` readiness checks, the `_advance_*` continuation
  writers, the picture and AX presenters), plus 9 B14 and 8 B03 non-UI
  writers of per-event AX and camera fields. Those do not move
  mechanically: each must be split into a computation the module returns
  and a presentation the player applies, function by function under the
  scene test and the original checks - a different kind of unit, with a
  judgment per function; the owner ruled on 2026-09-19 that TD-11 closes here.
  - **Units 3+: the writers.** B14 (43 state-touching functions, 2,901
    lines) and B03 (35, 1,801) write the continuation, preview and
    per-event AX fields; they move once they return what the player
    applies. The UI half (134 functions) stays the scene script.

- [x] **TD-12 — Measure the Python decoder against the authoritative framing.**
  Opened by [Product roles](../docs/spec/tech/product_roles.md): Phase 1-4
  authority moves to Python, and authority is MA-09's measurement rather than
  the language that computes it, so the move needs the measurement repeated
  rather than the code translated. **No tool crossed the language line.**
  `validate_mes_analyzer_handoff.py` checks the *schema* of the GDScript
  handoff; `audit_mes_decompiler_equivalence.py` compares one Python renderer
  against another, downstream of it.

  **Closed 2026-09-05.** `tools/content_suite/cli/export_mes_framing_digest.gd`
  emits the authoritative record framing per entry and
  `tools/audit_mes_framing_equivalence.py` measures Python against it. What is
  compared is the framing itself — the exact `[start, end)` of every instruction
  and every byte-preserving opaque remainder — because that is what the Phase 2
  gate requires. Both sides emit one canonical line list, so a mismatch reduces
  to a single coordinate and the opcode there.

  The audit reports two measures, because one alone cannot plan the work.
  Sequential equivalence is the real gate and is unforgiving: decoding stops at
  the first command with no grammar, so one gap reports a whole entry as
  divergent and hides everything after it. Per-record agreement starts from each
  authoritative offset instead, so it sees past the first failure and ranks the
  missing commands by how much of the corpus each blocks.

  **Result, measured over the authoritative `mes.arc`**
  (`31a95b31cb0f1051…`, 1,016 entries, 0 export failures):

  | | |
  |---|---:|
  | Authoritative records | **2,386,774** |
  | Authoritative opaque boundaries | 1,180 |
  | Sequential equivalence | **0 of 1,016 entries** |
  | Per-record agreement | **1,389,478 of 2,386,774 — 58.2%** |
  | Distinct commands in the framing | 50 |
  | Framed by Python in full / in part / never | 11 / 3 / 36 |

  The two measures disagree in a way that is the whole point of running both.
  Sequentially, **1,015 of 1,016 entries stop at command `0x1B`** and one at
  `0xFF` — `0x1B` is early in nearly every entry but is only 20,049 records, so
  it is the *sequential* blocker and not the *volume* one. By volume the gap is
  concentrated elsewhere, and thirteen commands account for all of it:

  | Command | Records Python cannot frame | Cumulative |
  |---|---:|---:|
  | `0x01` | 220,549 of 220,549 | 22.1% |
  | `0x1D` | 156,041 of 156,041 | 37.8% |
  | `0x09` | 151,034 of 151,034 | 52.9% |
  | `0xFF` | 133,389 of 133,389 | 66.3% |
  | `0x07` | 82,114 of 82,477 | 74.5% |
  | `0x0E` | 81,173 of 81,173 | 82.7% |
  | `0x0B` | 71,165 of 71,165 | 89.8% |
  | `0x0D` | 58,123 of 278,155 | 95.6% |
  | `0x1B` | 20,049 of 20,049 | 97.6% |
  | `0x0F`, `0x12`, `0x11`, `0x10` | 23,176 combined | 100.0% |

  Two of these are already partly right — `0x0D` frames 79% of its records and
  `0x07` all but 363 — so they are corrections rather than new grammars, and
  `0x03` misses only 270 of 54,407.

  **What the number means.** It is not "the Python decoder is 58% finished". It
  is that eight command grammars stand between the current state and 95.6% of
  the corpus records, that `0x1B` alone stands between it and sequential
  decoding of 1,015 entries, and that the two are different pieces of work. The
  earlier reading of this gap was unmeasured in both directions: counting fixed
  grammars in `mes_partial_decoder.py` gave 15 of 36 and counting opcode
  mentions across the 18-file chain gave 34 of 36, and neither is what the
  authority requires.

  Verified: 18 new synthetic cases run with no archive, and the corpus run is
  reproducible from the two commands in the tool's own docstring.

  **This does not close the gap and does not schedule closing it.** How the
  migration happens is the owner's separate question; this item existed to
  replace an estimate with a measurement.

  Closing it is `mes_analyzer.md` **MA-10**, opened by the owner's go on
  2026-09-06. The numbers above are that item's starting baseline and are not
  re-measured here; MA-10 owns the current ones.

- [x] **TD-13 — Give the analysis instrument a callable evidence API.**
  Twenty-one headless scripts, **12,192 lines**, obtain analysis evidence by
  instantiating `event_player.tscn` — a `Control` with 70 `@onready` node
  references — adding it to a live `SceneTree`, and then calling **82 distinct
  private methods by string, 412 times**. Only two of the called methods are
  public. `_on_continue_pressed` is called 85 times: advancing an analysis is
  literally simulating a button press.

  Under the goal this repository had before 2026-09-05 that was a large UI file.
  Under [Product roles](../docs/spec/tech/product_roles.md) it is the thing the
  file *is for* — the instrument exists to produce evidence — and the instrument
  has no callable interface. Its interface is its UI.

  It is also the analyzer's real engine coupling. `FileAccess` at 185 uses is a
  standard-library shim with a direct Python equivalent; 12,192 lines of
  headless evidence that must build a `Control` tree is not.

  As a defect it is ISP and DIP at once: no segregated interface exists, so
  clients reach through the whole implementation and depend on its private
  detail. The compiler checks none of the 412 calls, so a rename fails at run
  time. Repository-wide there are 1,344 such calls — 897 in `tests`, 443 in
  `tools/content_suite` — while `content_core` has 4, so the domain core is
  clean and the coupling is localized, which is what makes it fixable.

  **Closed 2026-09-05 for the API it names.** The cause was one line shorter
  than the symptom: `event_player.gd` had **no `class_name`**, so a client could
  only hold a `Control`, and on a `Control` the only way to reach any of those
  methods is `.call("name")`. The string surface was not a choice anyone made;
  it was the only thing the type system left.

  `class_name KakyuEventPlayer` fixes that, and **18 public methods** now declare
  the session protocol an analysis uses — `open_content_set`, `load_entry`,
  `start_event`, `advance`, `step_preview_message`, `confirm_choice`,
  `reset_state`, `confirmed_event_start`, `resolve_mmo_image` and the rest. They
  are named for what they mean to an analysis rather than for the control that
  used to invoke them: `advance()` was `_on_continue_pressed`, which 85 call
  sites used to press.

  | | Before | After |
  |---|---:|---:|
  | Calls on the player | 889 | 889 |
  | ...by string, dispatched dynamically | **889** | **1** |
  | ...through the declared API | 0 | **337** |
  | ...direct to a private method | 0 | 551 |
  | Client variables and parameters typed as the player | 0 | 56 |

  All 21 headless scripts in `tools/content_suite` and both driving test scenes
  moved. The one remaining string call is `player.call(method, ...)` in a loop
  over method names, a genuine dynamic dispatch that stays.

  **A claim in the original entry does not survive checking, and is corrected
  here.** It said the compiler checks none of the 412 calls and that giving the
  instrument an API would put them under the compiler. The first half was right;
  the second is not available. Godot 4.7 reports an unknown method on a typed
  value at **run time**, not at parse time — verified against a `Control`, a
  `class_name` type from `instantiate()`, and a directly constructed one, and the
  `--editor --quit-after` parse check does not report it either. Typing the
  clients therefore buys intent and editor completion, not static rejection.

  What the change does buy is the interface itself: a caller now reads a
  declared protocol instead of guessing a private name, and a rename is a
  greppable identifier rather than a string literal. Every one of these clients
  is a validator or a test that runs, so a break still surfaces.

  **What TD-13 did not deliver.** The clients still instantiate
  `event_player.tscn` into a live `SceneTree`; the API delegates to the same
  instance. Taking evidence-gathering out of UI instantiation needs the
  decomposition, which is TD-11. And the 551 private-direct calls remain
  implementation reach-through — closed for the generic protocol, open for the
  per-event entry points like `_validate_eventb01_start`, 41 methods and 92 call
  sites, which are per-event by nature and close with TD-04's move of per-event
  data into the catalog rather than with a generic surface.

  Verified: 91 of 91 Godot scenes, and the rewritten validators re-run against
  the authoritative archive, which the scene batch does not cover.

- [x] **TD-14 — `validate_event_player_event_catalogs.gd` fails against the
  authoritative archive, and nothing noticed.** Closed 2026-09-06: the validator
  was stale, and the whole `--elfimage` group now passes.
  Found on 2026-09-05 while re-running the rewritten validators for TD-13, which
  is the first time this one had been run here.

  ```
  ERROR: Event Player catalog integration failed:
    EVENTD06.MES catalog setup completion changed: status=shared_routine_boundary
      offset=0xC0E ... stopped safely before shared routine 21
    EVENTD14.MES catalog setup completion changed: status=def_selection_boundary
      offset=0x942 ... choice@0x942
  ```

  **It is not TD-13's doing.** The same script exits 1 with the same assertion on
  the pre-change tree, checked by stashing the whole change and re-running, and
  the failure is a content claim about where two events stop — offsets and route
  paths a call-form rewrite cannot produce. Re-measured cleanly on the committed
  tree with nothing else touching it, the event validators are **17 of 18
  passing**, and this is the one failure. Commit `288cd47`'s message says "16 of
  17"; that count came from two ad-hoc batches, one of which overlapped a
  `git stash` cycle, and it is wrong in both numbers. The substance is unchanged
  — one failure, pre-existing, this one.

  Why nothing caught it is the more useful half. It lives in
  `run_headless_validation.py`'s `--elfimage` group, **79** checks that need the
  user-owned archive — not the 75 first counted — and **the 91-scene batch does
  not cover any of them**. That group also could not complete at all until
  TD-00's two defects were fixed earlier the same day.

  **The events do not stop anywhere new; the validator was stale.** Status,
  offset and the complete continuation path matched the catalog in the failing
  run. The only mismatch was the sandbox record count: 23 against an expected 26
  for EVENTD06 and 22 against 25 for EVENTD14, both short by exactly three, and
  the three EVENTD14 choice routes likewise 42/43/42 against 45/46/45.

  The cause is `kakyu-remake` commit `1243093a`, "Preserve AX selected-cell
  envelopes without shadow state writes" (2026-09-03), which deliberately stopped
  selector-1 AX envelopes from performing three phantom writes. Measured, not
  inferred: the pre-commit tree, exported and run against the same archive,
  **passes** this validator at 11/26 and 12/25; and the record-set diff between
  the two trees is identical in both events and in all three choice routes, and
  is exactly `global_u8[767]=1`, `[768]=0`, `[769]=0` — no other cell, no changed
  value. `[767]` is the same cell that commit corrected in
  `validate_event_player_eventd02.gd` from 1 to 0. It updated the validators it
  could run and the spec's rule, and missed this one and the count sentences that
  quoted the old behavior, precisely because the `--elfimage` group could not run.

  Closed by correcting the six stale counts in
  `validate_event_player_event_catalogs.gd` and the three claims in
  `docs/spec/mes/character_events.md`. The validator now exits 0 at
  `setup_state_changes=11/23` and `12/22`.

  **The `--elfimage` group's state is now known rather than assumed: 79 of 79
  pass**, measured 2026-09-06 in one run of about 58 minutes against the
  authoritative archive, without `--exe`. The group's native-executable checks
  are additional and remain unrun here.

- [x] **TD-15 — Reconcile the frozen Phase 1-4 authority fingerprint.**
  The missing batch guard is restored. The owner approved the v45 baseline on
  2026-09-06; the complete re-freeze audit and Python consumer both pass.
  Found on 2026-09-06 while building MA-10's handoff measurement, when a new
  exporter produced a corpus fingerprint that did not match the frozen one.

  **It is not the new exporter.** `audit_mes_analyzer_handoff_corpus.gd` — the
  authority's own audit, which carries the constant — produces the identical
  value and then failed on the historical v43 check at discovery:

  ```
  corpus_sha256=fae349f9affbaf244f44fe61f3afc380cb980f058950fe85fcb1f7d097eab6f5
  source_unchanged=true failures=1
  ERROR: Archive-wide analyzer handoff fingerprint changed.
  ```

  The historical `EXPECTED_CORPUS_FINGERPRINT` was `2d182d27...b911807`, frozen in
  `kakyu-remake` `064f89c5` on 2026-08-30. Instruction **v44** landed on
  2026-09-03 in `1243093a` and **v45** after it, and both deliberately changed
  what a handoff contains — MA-07 records that each rejects the previous
  handoffs and requires regenerating them. The constant was never regenerated
  with them, so it was stale by two intended corrections rather than wrong.

  Every count moved the way those corrections predict, and `mes_analyzer.md`
  MA-08 already carried the new ones while the completion and migration
  references still named the old baseline at discovery:

  | | Historical frozen baseline (v43) | Approved baseline (v45) |
  |---|---:|---:|
  | Typed instructions | 2,389,424 | 2,386,774 |
  | Owned messages | 220,491 | 220,493 |
  | Code references | 185,674 | 186,030 |
  | State references | 521,125 | 517,612 |
  | Opaque boundaries | 1,251 | 1,180 |
  | Alignment instructions | 2,478,500 | 2,473,574 |
  | Compound records | 358,924 | 363,850 |

  Resource references are 36,149 on both sides.

  **Why nothing caught it is again the more useful half.** At discovery this
  audit was in no batch: the 91-scene batch did not cover it, and
  `run_headless_validation.py` did not list it in the `--elfimage` group, which TD-14 established is
  otherwise the only thing that touches the authoritative archive. So the one
  check that guards the Phase 1-4 authority has been failing unobserved since
  2026-09-03.

  **Batch guard restored, 2026-09-06.** The `--elfimage` group now includes
  `audit_mes_analyzer_handoff_corpus.gd` with a bounded 1,800-second budget and
  only the read-only MES archive argument. It does not join the synthetic-only
  batch. A failed audit keeps exit code 1 and a failed batch result; its console
  summary no longer claims `phase1_4=closed` when the checks failed.

  Verified: 11 batch regression tests and the Godot 4.7 project parse check
  pass. The newly registered check, run through the batch's own `run_check`,
  covers 1,016 entries in 677 seconds and reproduces `fae349f9...eab6f5`,
  `source_unchanged=true`, and exactly the known fingerprint failure. The
  process returns 1, the batch result is `failed`, and the completion log makes
  no closure claim. The remaining 79 original checks were not rerun for this
  routing change; their last passing measurement is TD-14's.

  **Owner-approved re-freeze completed, 2026-09-06.** The approved
  Phase 1-4 corpus fingerprint is
  `fae349f9affbaf244f44fe61f3afc380cb980f058950fe85fcb1f7d097eab6f5`.
  The instruction-v45 measurement retains 18,079,488 code bytes, 1,180
  strict-analysis diagnostic/opaque boundaries totaling 719,650 bytes, and one
  57-byte structural-alignment opaque boundary. Current baseline and migration
  references now name v45; v43 counts and hashes remain explicitly historical.
  The complete audit against the approved constant returns 0 with no failures
  and an unchanged source archive. Its completion payload is
  `a0883d4ffcd4f6c0831818ad2187dcfc3e81dc1002f54c9bfc19f35e134ea828`.
  `validate_mes_analyzer_completion.py` now checks the same v45 corpus hash and
  counts and accepts that exact report; its four synthetic regressions pass.
  The earlier 677-second failed run independently proves failure propagation.

  MA-10's equivalence audit compares against a
  freshly exported digest of what the authority produces now, so it never reads
  the historical constant. Re-freezing this GDScript-produced measurement does
  not transfer Phase 1-4 authority to Python.

- [x] **TD-16 — Make the documentation's unresolvable references honest.**
  A link checker over every tracked `.md` found **20 broken relative links**,
  and `docs/spec/index.md` accounted for nine of them. The gap was three
  separate problems wearing one appearance.

  `tools/README.md` linked `../docs/spec/tech/playback_package_schema.md` three
  times, at `:310`, `:331` and `:351`. That is a local path to the contract
  document the split deliberately left in `kakyu-remake`, so it could never
  resolve, and the index's exemption does not cover it — that clause says "the
  documents above", meaning the documents under `docs/spec/`. Rewritten as
  `kakyu-remake/docs/spec/tech/playback_package_schema.md`, the convention
  `AGENTS.md` and `tech/product_roles.md` already use.

  `docs/spec/tech/tooling.md` carried a section headed **Existing Outputs**
  listing five Git-ignored `analysis/` artifacts as markdown links whose text
  was the raw path. None of the five exists, and none can: `analysis/` is
  Git-ignored, so they are absent from every fresh checkout by design. Calling
  an absent generated file an existing output and linking it states something
  untrue about the repository. The section is now **Output Paths**, says where
  the tools write and that the paths are reproduced by re-running the tool, and
  names them as paths. `docs/spec/mes/map_movement_sources.md` had the sixth
  such link and now matches the backtick convention its own neighbouring
  sentence already used for the same audit's JSON.

  The count itself was wrong: **ten** links point into the cross-repository set,
  not nine. The sentence now says ten, records the date, states how to recount
  it, and adds the property that makes it useful — that nothing else under
  `docs/spec/` is expected to be unresolvable, so any other broken link is a
  defect rather than an exemption.

  Measured after the fix: **10 broken relative links repo-wide**, all ten under
  `docs/spec/`, all ten in the documented cross-repository set, and **zero
  anywhere else**. Documentation only; no code, schema or catalog data changes.

  A first reading of this suggested the Measurement Baseline's "Broken `res://`
  paths: **0**" was also wrong. Measured properly, it is not: see TD-17, which
  records what the number covers and the one decision it exposes.

- [x] **TD-17 — Decide what `config/maps/` and `config/slices/` are for here.**
  **The Measurement Baseline's "Broken `res://` paths: 0" holds.** Re-measured
  2026-09-06 over all 1,004 tracked files, resolving all 1,469 `res://`
  references:

  | Holder | References | Unresolved |
  |---|---:|---:|
  | `.gd` | 1,143 | **0** |
  | `.tscn` | 102 | **0** |
  | `.py` | 23 | **0** |
  | `project.godot` | 1 | **0** |
  | `.md` | 155 | 6 |
  | `.json` | 40 | 15 |
  | **Total** | **1,469** | **21** |

  Every executable path still resolves, which is what the original number was
  about and what makes it load-bearing. What it did not say is that it was
  scoped to those; state the scope when re-measuring rather than restating a
  bare zero.

  Of the 21 that do not resolve, six are documentation prose naming
  deliberately absent paths — this file's own `res://scenes/`,
  `res://data/maps/`, `res://assets/original/maps/` and
  `res://tests/test_content_service.tscn`, and two in
  `tech/content_tools.md` — and twelve point into the Git-ignored `data/` and
  `assets/` trees, absent by design and reproducible. Neither is a defect.

  **The remaining three are, and they are the item.**
  `config/slices/saturday_eventd08.json` names `res://scenes/town_map.tscn`,
  `res://scenes/school_floor5.tscn` and `res://scenes/room_screen.tscn`. Those
  scenes exist in **neither repository**: the split's step 6 removed the
  prototype, and `kakyu-remake/scenes/` now holds only `main.tscn`.

  The thirteen files under `config/maps/` and `config/slices/` arrived in the
  split commit `be0cbba` and have not been touched since. **No code in either
  repository reads any of them** — the only references anywhere are two
  specification documents. `kakyu-remake` holds the same thirteen, last touched
  by pre-split feature commits.

  The decision is not mechanical, because the files are two things at once.
  `saturday_eventd08.json` carries a `source` block of caller entries and
  code-relative offsets — analysis evidence this repository owns, documented by
  `docs/spec/mes/saturday_start.md` — wrapped in `start_profiles`, `scenes` and
  `schedule` that are mod-player runtime configuration.
  `config/maps/protagonist_sprite.json` has the same shape: a real
  `data.arc`/`CHARA.DAT`/`CHARA.PAL`/CCD source block inside sprite
  presentation config. The eight `source_maps/*.json` are prototype stubs with
  empty `edges`, `destinations` and `source_event_bindings`.

  So `product_roles.md` points one way and the producer rule the other, and the
  precedent cuts both ways: `content_service.gd` was removed on 2026-09-05 for
  arriving in the split with no consumer here, but it held no source evidence.

  **Removed, 2026-09-06, by the owner's ruling**, on the same reading that
  removed `content_service.gd`: they arrived in the split, nothing here consumes
  them, and projecting confirmed handoffs into start profiles, map nodes and
  scene paths is mod-player work. All thirteen are recoverable from `be0cbba`
  and `kakyu-remake` holds its own copies.

  **The source evidence was checked out before deleting, not assumed.** Each of
  the twelve code-relative offsets in `saturday_eventd08.json`'s `source` block
  was resolved against the specifications. Eleven were already recorded in
  `mes/saturday_start.md` or `mes/character_events.md`. One was not — the
  `12C.MES:0x0E97` condition guarding the EVENTD08 call — and it is now in
  `character_events.md` beside the `0x0FA6` envelope it guards, so the deletion
  costs no evidence. `mes/saturday_start.md` keeps every offset it documented
  and no longer claims to own a projection that is not here.

  Re-measured after the removal: **1,452 `res://` references, 12 unresolved, and
  every one of the twelve is documentation prose** — nine in this file, two in
  `tech/content_tools.md`, one in `TODO.md`, all naming deliberately absent
  paths in order to explain them. `.json` went from 40 references with 15
  unresolved to **17 with none**, so the tally is now zero unresolved in every
  file type that is executed, loaded or parsed:

  | Holder | References | Unresolved |
  |---|---:|---:|
  | `.gd` | 1,143 | 0 |
  | `.tscn` | 102 | 0 |
  | `.py` | 23 | 0 |
  | `.json` | 17 | 0 |
  | `.ps1` | 5 | 0 |
  | `project.godot` | 1 | 0 |
  | `.md` | 161 | 12 |

  `config/` now holds only `event_catalog/original_events_v1.json`, which every
  consumer names by explicit path; nothing globs the directory. Re-measure this
  the same way, and state the scope — the bare zero this tracker started with
  was true and unreadable at the same time.

  Verified: the full local batch passes **95/95** in 166.416 seconds after the
  removal — **1,288 Python tests**, project parsing and **93 Godot scenes** —
  so nothing loaded, parsed or tested depended on the thirteen files. All
  thirteen were confirmed byte-identical to their `be0cbba` blobs before
  deletion. No original-archive check is implicated: no removed file names an
  archive, and the `--elfimage` group reads none of them.

- [x] **TD-18 — Prove the generic catalog source guard rejects, not only accepts.**
  A review of EVENTD14's coverage started from the wrong premise — that it
  lacked a validator — and measurement corrected it into a real finding.

  Nine events carry a `_validate_eventXX_start(anchor)` source contract, and
  each of their validators feeds it a shifted anchor, a changed MES hash and an
  overlay-shadowed source to prove it **refuses** them. EVENTD06 and EVENTD14
  have no such method. They are served by the generic catalog path, whose guard
  `_validate_address_catalog_source()` is stronger than the per-event ones — it
  checks the archive fingerprint, the entry and caller hashes against both the
  loaded document and the reader, the address-table count, original-ARC
  resolution for both entries, the resolved bytes, and every entry label. The
  fragment validator compared over forty of its fields.

  **Every one of those comparisons was a positive assertion.** Nothing anywhere
  fed this guard a tampered source, so nothing showed it would refuse one. That
  is the gap, and it is not EVENTD14's: it belongs to the path TD-04 is moving
  every event onto, so it would have been inherited rather than found later.

  Writing a tenth `_validate_eventd14_start` would have closed it the wrong way,
  by adding to the per-event surface TD-04 exists to remove and AGENTS.md
  forbids growing. `_rejected_source_contracts()` in
  `validate_event_player_event_catalogs.gd` closes it once for the generic path:
  a changed document hash, a changed address-table count, a changed declared
  caller hash and a changed declared entry hash must each be refused, and the
  restored original must still be accepted. Every catalog entry gets all five,
  and an event that migrates to this path inherits them. The guard is reached
  through `catalog_source_contract_evidence()` and
  `confirmed_address_catalog()`, two more evidence-API methods rather than two
  more private-direct calls.

  **The coverage was mutation-tested rather than assumed.** Disabling the hash
  comparison inside `_validate_address_catalog_source` makes the check fail with
  exit 1 on both EVENTD06 and EVENTD14 — "catalog source contract accepted a
  changed entry hash" — and disabling the address-table count comparison fails
  only the count assertion, so the two are independent and neither passes
  vacuously. Both mutants were reverted and the guard is unchanged; the fix is
  test-side only.

  Verified with the guard intact: the full local batch passes **95/95** in
  164.568 seconds — **1,288 Python tests**, project parsing and **93 Godot
  scenes** — and the focused original batch passes **3/3** in 215.458 seconds:
  catalog source bindings over nine caller routes and 23 terminal boundaries,
  ordinary Play for ten routes, and the fragment catalogs with EVENTD06 at 66
  fragments and EVENTD14 at 65 plus its caller BGM and handoff. `mes.arc`
  unchanged. Reports: `analysis/td18-reject-local-validation.json` and
  `analysis/td18-reject-original-validation.json`. This is focused original
  verification, not a new aggregate result for the whole archive group.

- [x] **TD-19 — Reject zero-exit Godot script failures in validation.**
  The 2026-09-08 review reproduced an autoload parse failure with exit code zero
  being recorded as passed. Direct Godot checks now reject fatal script/load
  diagnostics and retain the reason in the bounded report. Regression coverage
  includes colored/long output, expected application errors, Python negative
  tests, and a real isolated invalid Godot project. Closed 2026-09-08: 21 focused
  tests pass, including the actual engine rejection, and the local batch passes
  95/95 checks (1,291 Python tests, project parsing, 93 Godot scenes) in 162.366
  seconds. Report: `analysis/r1-validation.json`. Original checks were not part
  of this validation-runner-only work unit.

- [x] **TD-20 — Restore the PROMIS location-route corpus audit.**
  Closed 2026-09-08. The audit now consumes verified Python Phase 1-4 handoffs,
  rejects incomplete typed entries, uses `continuation_transfer`, and checks
  the full u32 retry/success targets against instruction boundaries. Report v4
  records actual handoff provenance; the MES evidence table supersedes v3's
  low-byte addresses. All twelve source entries and 120 option routes pass
  against the original archive/native executable; nine synthetic tests include
  a current-handoff collector and opaque rejection. Official focused batch:
  `analysis/r2-validation.json` (PROMIS audit and project parse).
  The old-op consumers in `export_map_location_entries.py` and
  `inspect_normal_talk.py` are separate supporting projections; their migration
  remains an explicit follow-up rather than evidence for this closure.

- [x] **TD-21 — Bind package playback metadata and replace reader state atomically.**
  Closed 2026-09-08 (review R3/R6). Producer/reader v4 binds the entire canonical
  manifest and exact event/text inventory, rejects invalid identities/ranges,
  and replaces all reader state only after verification. Old v3 packages need
  re-export; this does not change the separately maintained remake. A dedicated
  synthetic scene checks metadata tampering, invalid manifests, document
  mutation, and successful/failed reload snapshots. Project parse and the scene
  pass (`analysis/r3-focused.json`); all twelve original catalog events pass
  the packaged-vs-bytecode comparison (`analysis/r3-original-recheck.json`).
  The first original run exposed the library's deliberately absent address
  table; validation now preserves that contract. Safe publication is a separate
  R4 work unit, and media/caller-terminal completeness remains deferred.

- [x] **TD-22 — Publish playback packages without damaging existing output.**
  Closed 2026-09-08 (review R4). New-destination-only publication validates the
  serialized inventory, uses the existing shared publication lock, stages and
  checks each file, reopens the complete package, then renames its directory.
  Failed staging cleanup is bounded to files owned by this operation. Regressions
  cover existing output preservation, path/payload tampering, injected write
  failure, staged corruption, and lock contention. Project parse, package tests,
  and all twelve original catalog playback comparisons pass in
  `analysis/r4-final-validation.json`.

- [x] **TD-23 — Preserve opaque ownership and caller limits in package decoding.**
  Closed 2026-09-08 (review R5). Package v5 retains exact dropped-provenance
  boundaries; opaque-interior forwarding requires a proven contiguous marker
  path. Exact linear and transfer-owned records may overlap an opaque path,
  and records crossing the caller's end are rejected before runner effects.
  Prefix maximum opaque ends avoid missing a broad interval behind shorter
  records. Initial rejection exposed legitimate marker gaps in the corpus;
  the producer now records their ownership instead of relaxing the guard.
  Parse, package/bytecode boundary regressions, package integrity/publication
  tests and all twelve catalog comparisons pass (`analysis/r5-v5-validation.json`).
  This does not change the analyzer handoff or unresolved native meanings.

- [x] **TD-24 — Fail closed when loading native byte evidence.**
  Closed 2026-09-08 (review R7). Live/shadowed/winner payloads require nonempty
  canonical hex and bounded integer addresses; shadowed evidence must preserve
  its three distinct addresses. Four existing anonymous/symbolic aliases retain
  both measured values under explicit fingerprint guards and their historical
  winners. Other collisions and changed merged counts fail before auditing.
  Nine formal tests pass; all 1,043 actual sites retain the pre-change table
  fingerprint. Project parsing and the original native MES audit pass in
  `analysis/r7-validation.json`. The data file and native audit schema are unchanged.

- [x] **TD-25 — Include authoritative Python full-corpus handoffs in the batch.**
  The normal `--elfimage` group now invokes the full-payload equivalence gate
  against the tracked 1,016-entry fingerprint-only frozen GD digest, alongside
  the historical GD completion check. Actual and producer-only projected
  hashes stay separate; no machine-local generated input or entry limit is
  accepted by the default check. Routing and frozen-baseline regressions pass.
  Closed 2026-09-08: the official check passed all 1,016/1,016 payloads and
  all nine component targets in 1,164.741 seconds, with zero Python errors.
  Actual Python `3eb9afe7...b3628f9` and projected GD `fae349f9...eab6f5`
  reproduce MA-10. The separate GD check passed in 624.759 seconds. The combined
  original/native batch completed with **188/188 checks passing** in 5,018.748
  seconds across all six coverage groups. Evidence:
  `analysis/review-fixes-full-validation.json`. Features added after that batch
  started have their own subsequent focused and local regression reports.

- [x] **TD-26 — Preserve empty bootstrap regions in compiler reopening.**
  Closed 2026-09-08. The actual Python decompiler includes an empty bootstrap
  in its region count; eight reopen validators incorrectly compared that count
  with nonempty framing regions. Core 0.301.0 shares the two-count check without
  changing either schema or any analyzer fingerprint. Eight family fixtures
  now use their producer's count, and an omitted-bootstrap audit is rejected.
  The actual Python editor-flow regression, project parse and all eight family
  scenes pass (10/10, `analysis/compile-regions-validation.json`). The full
  Python regression passes 1,308 tests. A read-only EVENTB01 source-derived
  edit at code offset `0x8F` independently reopens all 269 typed nodes in Godot
  (`analysis/authoring-eventb01-reopen.log`). This is compiler evidence, not a
  new original scene semantic claim. Contract detail:
  [compiler region counts](../docs/spec/tech/mes_compile_region_counts.md).

- [x] **TD-27 — Persist zero-exit script diagnostics as valid failure reports.**
  Closed 2026-09-08. TD-19 detected the script failure but retained the child
  exit code zero with check status `failed`, which the v3 report writer rightly
  rejects. A zero-exit script diagnostic now uses the existing `error`/null-code
  representation; its bounded diagnostic retains the actual process exit code.
  Nonzero child failures remain `failed` with their actual exit code. The report
  schema and reader rules do not change. All 23 runner regressions pass,
  including report publication through `main`. An actual malformed Godot project
  produces a persisted failed report which the Godot viewer reader reopens
  (`analysis/td27-real-report.json`, `analysis/td27-real-report.log`).

- [x] **TD-31 — Let the choice-option family build its proof from a real authoring model.**
  Found 2026-09-16 while exposing choice options in the Authoring tab (MW-11).
  `tools/diff_mes_byte_patch_semantics.py` compared the audit's source
  identity with the editable model's including `source_kind`, which the
  choice-group proof (and so the choice compile audit) never carries, so the
  family's semantic proof failed with "source identities changed" for every
  real authoring model; its own test used a proof-shaped identity and never
  saw it. Closed 2026-09-16: the comparison drops `source_kind` beside
  `entry_sha256`, with a test whose editable identity carries `source_kind`
  (and the same normalization in `content_core/mes_semantic_diff.gd` where
  it compared strictly). Beside it, the candidate lister calls the
  grouped-route decoder only for an entry whose model holds a group clear:
  that decoder requires the five-byte `0x17` prologue on every address entry,
  which real entries have and the other families' synthetic fixtures do not.
- [x] **TD-30 — Move the resource-name planner's MMO form to the 0x0D framing.**
  Found 2026-09-16 while exposing resource names in the Authoring tab (MW-11):
  `tools/plan_mes_resource_name_edit.py` and `content_core/mes_resource_name_edit_plan.gd`
  still described the MMO marker as command `0x09` with prefix `09ff01`, the
  separator-plus-record framing Core 0.316.0 replaced, while the AX and voice
  forms had moved to their `0x0D` prefixes. Against real analyzer output every
  MMO marker decodes as one `0x0D` record (`0d09ff01` + name + `0000`), so the
  planner refused every real MMO edit with "command identity changed"; only its
  own synthetic fixtures still passed, and no batch check re-derives the
  original-derived `03C.MES` plan the method document records. Closed 2026-09-16:
  both tables carry `command_id 0x0D`, prefix `0d09ff01`, suffix `0000`; the
  plan/compile fixtures and the Godot plan scene follow; the `03C.MES` evidence
  in `docs/spec/mes/format_and_method.md` is re-derived with a dated
  correction. `validate_mes_bgm_route.gd` keeps its own expected prelude bytes
  (a different instrument, unchanged).
- [x] **TD-29 — Exclude generated release output from version control.**
  Measured 2026-09-09: `output/` held 701 MB of WD-13 release artifacts (six
  app EXE/PCK pairs under `KakyuContentTools-0.306.0`) as untracked files that
  no `.gitignore` rule covered, while `assets/`, `data/`, `analysis/` and
  `reverse_engineering/` were already excluded. Nothing is tracked under it and
  no tool hardcodes the path, so it is a build destination, not repository
  content.

  **Excluded, 2026-09-09, by the owner's ruling** on two presented options, on
  the existing rule that generated output never enters Git and never returns to
  an original installation. `/output/` now sits with the other exclusions,
  removing a standing risk of committing the build tree and the `git status`
  noise that hid it.

## What the review found working

Recorded so a later change does not quietly undo it.

- `content_core` has **zero** references into `tools/`. The domain core does
  not know the applications exist.
- `KakyuMesCodeSource` is a deliberate, documented abstraction with two real
  implementations, introduced to decouple the runners from bytecode. TD-02
  repairs its contract; it does not question the design.
- The decode codecs are small and single-purpose: `cp932_codec.gd` 151 lines
  with no dependencies, `ai5_lz.gd` 141 with none, `mpc_map_codec.gd` 188 with
  none.
- `content_core` module sizes are healthy — median about 320 lines, largest
  1,695. The structural problems are concentrated in `tools/`.
- The `{ok, error}` result convention is applied consistently and fails closed.

## Boundaries

- Feature capability and its gates belong to the domain trackers.
- A defect found here that turns out to be a capability gap moves to the owning
  domain tracker rather than growing an item here.
- Manual GUI and original-engine checks belong to `manual_verification.md`,
  including any that a fix in this tracker makes necessary.
