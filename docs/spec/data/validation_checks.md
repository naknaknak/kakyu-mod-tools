# Validation Checks Registry

`config/validation/checks_v1.json` is the tracked list of every check the
headless validation batch can run (`tools/content_suite/run_headless_validation.py`,
TD-32 part 1, 2026-09-21, Core 0.357.0). The runner's `build_checks()` loads
and validates it and plans a run from it; nothing in the runner names a
check any more. Schema string `kakyu_validation_checks/v1`; `revision` 2
since 2026-09-21 (TD-32 part 2: the `families` block), 3 since 2026-09-23
(TD-33: the `exclusive` and `exclusive_scenes` fields), 4 the same day
(TD-33 part 2: the `shards` field), 5 since 2026-10-09 (TD-58: the `families`
block's optional `process_shards` field; a revision-4 document is refused).

## Document

| Field | Meaning |
|---|---|
| `schema` | `kakyu_validation_checks/v1` |
| `revision` | Integer; raised when the entry vocabulary changes, not when an entry is added |
| `checks` | Array of entries in the order the batch runs them |
| `families` | Since revision 2 (2026-09-21): `analysis_group` -> `{check, script, process_timeout, groups, tier}` plus, since revision 5 (TD-58), the optional `process_shards` - the process check that runs every selected `analysis_group` member (`validators/validate_event_analysis_groups.gd`), split across up to `process_shards` processes under `--jobs` (an integer >= 2, never a boolean; 2 today; see "The analysis-group family"). The key set is the five required keys plus that one; any other key fails the load. The members stay the report's rows |

## Entry

| Field | Meaning |
|---|---|
| `name` | The check's full name as the batch prints and reports it (with its `original ` prefix where it has one); unique |
| `kind` | `python` (a `sys.executable` command), `godot_editor` (the project parse check: the editor opened headless with `--quit-after 2`; its output is the editor's first filesystem scan of every directory under the project root that carries no `.gdignore`, tracked or not, and the quit aborts that scan, so every run walks the tree again. **Tool decision (TD-52):** the runner writes an empty, untracked `analysis/.gdignore` before any check, only when `analysis/` exists and the marker is absent, so the scan skips the 22,400-file working directory), `godot_script` (`--headless --path <project> --script <script> -- <arguments>`), `godot_scene` (a test scene run; only the scene family) |
| `script` | `tools/....py` for `python`, `res://tools/....gd` for `godot_script`; empty for `godot_editor` and the scene family |
| `arguments` | The command's arguments after the script, with placeholders |
| `timeout` | Seconds, an integer, or the placeholder `"{python_timeout}"` / `"{python_handoff_timeout}"` |
| `groups` | Coverage groups the report counts the check under: `synthetic`, `original_corpus`, `event_corpus`, `native_executable`, `native_corpus`, `voice_payload` |
| `requires` | What must be available for the entry to be planned: `elfimage`, `exe`, `voice_arc`, `se_arc`, `mmo_arc`, `event_corpus` (planned only without `--skip-event-corpus`) |
| `tier` | `local` (needs neither the archive nor the executable), `archive_quick` (archive or executable checks registered at 600 s or less, except the analysis-group entries), `full` (the corpora, the handoff equivalence, `catalog group routes`, `playback package export` (900 s since 2026-10-05, TD-50) and `playback package playback`, the three message/event/resource `contextual authoring` checks (900 s since 2026-10-07, TD-54), the exhaustive runner corpus, every check above 600 s, and the analysis-group entries) |
| `family` | Optional. `godot_scenes` on the one entry that stands for every `tests/*.tscn` scene (expanded from disk at plan time; name template `Godot {scene}`); `analysis_group` on each per-profile `event analysis ...` entry, with `profile` naming the tracked profile |
| `profile` | `analysis_group` entries only: the profile path under `config/event_catalog/analysis_groups/` |
| `optional_groups` | Optional. `[[requirement, group], ...]`: a coverage group the check also counts under when the requirement is available (the executable audits that also read the archive or `voice.arc`) |
| `optional_arguments` | Optional. `[[requirement, [arguments...]], ...]`: arguments appended only when the requirement is available |
| `exclusive` | Optional boolean, since revision 3 (TD-33): under `--jobs N` the check runs with no other check in flight. Any other type fails the load. **Set by no entry since 2026-10-10.** TD-64 D3 had set it on `original playback package playback` (the check held about 8.9 GB, so it ran alone); TD-64 part 2 D5 cleared it once the lazy package reader and the streaming exporter took that check's working set from about 8.9 GB to about 2.0 GB at its peak (a solo run, 548.6 s; setting or clearing an existing optional field needs no revision bump, so `revision` stays 5). The field stays in the vocabulary and is still accepted; the exclusive scenes below reach the same behaviour through `exclusive_scenes` |
| `shards` | Optional integer >= 2, since revision 4 (TD-33 part 2), only on a `godot_script` entry: the entry becomes that many checks named `<name> [K/N]`, each given the extra argument `shard=K/N` and the entry's own timeout, groups, tier and requirements; `--check "<name>"` selects every shard and `--check "<name> [K/N]"` one. Set on `original catalog group routes` (20 since 2026-10-04; 4 before) |
| `exclusive_scenes` | Optional, since revision 3, only on the `godot_scenes` family entry: the distinct, existing `tests/*.tscn` scenes that run exclusively - `test_overlay_publication_lock.tscn`, `test_process_liveness.tscn`, `test_workspace_multiprocess.tscn`, the three that spawn and time real sibling processes |

Placeholders: `{project}`, `{python}`, `{godot}`, `{source_root}`,
`{mes_arc}`, `{mmo_arc}`, `{data_arc}`, `{voice_arc}`, `{se_arc}`, `{exe}`,
`{frozen_handoff_digest}`, `{python_jobs}`, `{python_child_timeout}`,
`{python_timeout}`, `{python_handoff_timeout}`. A placeholder implies a
requirement (`{source_root}`, `{mes_arc}`, `{mmo_arc}`, `{data_arc}` need
`elfimage`; `{voice_arc}` needs `voice_arc`; `{se_arc}` needs `se_arc`;
`{exe}` needs `exe`) and an entry may use one only under that requirement
or inside an optional clause keyed by it.

## Validation

The loader fails closed, naming the entry: an unknown schema or revision, a
duplicate name, an unknown kind, group, requirement, tier, family or
placeholder, a placeholder without its requirement, a `godot_scene` kind
outside the scene family or a scene family of another kind, an
`analysis_group` entry without an existing profile, a `script` that does
not exist. `tests/test_validation_registry.py` proves the tracked registry
loads, that every profile on disk has exactly one entry, that the scene
family expands to every scene on disk, that every documented placeholder is
used and no other, and the tier ordering (`local` plans no archive check;
`archive_quick` plans nothing registered above 600 s; `full` plans
everything available). The plan a registry produces for every argument
combination was pinned against the hand-written table it replaced when the
registry was introduced (the baseline dump was identical).

## The analysis-group family

The `analysis_group` entries selected for a run (after `--check`) execute
in one Godot process - or, with `--jobs` above 1 since revision 5 (TD-58),
in up to `process_shards` of them (below): the runner replaces them, at the
first member's position, by the process check the `families.analysis_group`
block names
(`validators/validate_event_analysis_groups.gd` with the source root and
every member's profile; `process_timeout`; the block's groups and tier).
Each process opens `mes.arc` once, runs the Python exact-source audit once
for all its profiles (`tools/audit_event_analysis_group.py --profiles`,
or `--profiles-file` past the argument-length limit), prints one block per
group (`=== GROUP <profile> ===`, the group's canonical report JSON,
`--- GROUP PASSED|FAILED (N s) ---`) and ends with a `GROUPS_SUMMARY`
line (`kakyu_event_analysis_groups_run/v1`: per-group status, duration,
checks and failures; `archive_changed` when the archive's hash moved
during the run). The report keeps one row per member: `passed` or
`failed` from the summary with the member's own block as the failure tail,
`error` for a member whose block carries a script error, `timeout` or
`error` for members the process never reached. `--check "original event
analysis <name>"` selects one member; `--check "original event analysis
groups"` selects every planned member and is a configuration error when
none is planned.

**Process shards (revision 5, TD-58).** With `process_shards` P, `--jobs` J
and M selected members the runner makes `min(P, J, M)` process checks, named
`original event analysis groups [K/S]`; at `--jobs 1` (the runner's own
default, so a Launcher background run too) or with one member it keeps the
single process under the plain name, with no `[1/1]`. The split is made at
run time, after the cache filter, so a `--cached` run partitions only the
members that missed (the reason this is not a static `shards` split like
`catalog group routes`, whose members the cache would leave unbalanced). It is
longest-processing-time-first on each member's recorded duration - the
previous report at `--report` (a run row), else the cache entries, the
scheduler's own sources, read once by `main()` and handed to both the
partition and the scheduler: members go in by known seconds, descending, each
to the shard with the smallest (known seconds, member count, shard index). A
member with no recorded duration counts 0 s and keeps registry order; with no
durations at all the shards differ by at most one member; no shard is ever
empty; each shard lists its members in registry order. A shard runs the
unchanged validator over its own profiles with the family's `process_timeout`.
Its block opens with its `===` header and one line
`shard plan: K/S, <n> member(s), <s>s known, <u> unknown`, then its member
lines and its own `process:` line; a timeout, a launch error or a scheduler
exception in one shard marks only that shard's members. The report keeps one
row per member and its schema is unchanged (`check_count` counts members), so
the log is the only record of how a run was composed. Fingerprints and the
cache stay per member, and `--fingerprints` lists members. `--check "original
event analysis groups"` still selects every member; a name that starts
`original event analysis groups [` is a configuration error naming that
all-members name, because a shard exists only at run time. Each shard repeats
the Python audit's work for the entries its profiles share (by entry count the
two shards build 1.11 times the single process's entries), which is what the
split costs.

`process_timeout` is **8,000 s since 2026-10-05** (`todo/code_health.md` TD-51;
it was 3,600 s). TD-46's rule (a timeout of at least twice the loaded duration)
against a loaded process of about 3,750 s asks for 7,500 s (measured 3,614.5 s,
0.45 of 8,000 s, in the uncached closing batch of 2026-10-05, run `97d1723b`;
3,664.3 s, 0.46 of 8,000 s and 0.92 of the 4,000 s re-application point below,
in the TD-52 closing batch of 2026-10-06, run `a171a199`),
and 8,000 s is 2.13 times that 3,750 s; the rule holds up to a loaded process
of 4,000 s, which is where the value is re-applied. That paragraph's earlier
argument against splitting the family (a shard would only repeat the process's
roughly 900 s of overhead, until the process approached the batch's slot floor
of about 4,600 s at `--jobs 6`) is superseded by TD-57 (2026-10-09): the process
had become the floor itself, 3,192.9 s of a 3,225.7 s batch, and most of its
overhead is the Python pre-pass over every profile, which a split divides
instead of repeating. TD-46's rule now applies **per shard**: with two shards
a loaded shard took 1,861.5 s and 1,867.4 s in the TD-58 closing batch
(2026-10-10, run `d2144d74`, `--jobs 6`; the model had expected about
1,640-1,700 s), 0.23 of 8,000 s, so the timeout stays and the 4,000 s
re-application point is per shard too. The value is a registry edit, not a vocabulary
change, so the registry `revision` does not move. After the member lines the
runner prints one line for the process itself, for every outcome:
`process: <check name> <completed|timeout|error> in <seconds>s (<n> member(s),
timeout <seconds>s)`. It is the one place the process's own loaded duration
shows (a member's `duration_seconds` is its in-process time, and a timeout or
error stamps every member with the process's elapsed time); it lands in the
console and in a detached run's log, and the report schema is unchanged.
`completed` means only that the process ended by itself: its exit code is
not on the line, and the verdicts are the member lines and the report's
per-member statuses (a completed process can carry failed members).

## Inputs, fingerprints and the cache

`tools/content_suite/validation_inputs.py` finds a check's inputs by a
static scan from its script (or scene, or the whole tracked tree for the
project parse check and the Python suite): every `res://` literal, every
class-name identifier resolved through the `class_name` index, a scene's
resources, a Python tool's bare-module imports from `tools/` and its
`config/`, `tests/`, `tools/`, `content_core/` path literals, followed to
a closure; a directory literal brings every file under it; a bare
top-level directory literal (`res://tools`) is ignored as an assertion;
a `load(` whose argument is neither a string literal nor a `const` of
the same file widens the closure to every script of `content_core/` and
`tools/content_suite/`. Every check also depends on `project.godot`, the
Core version file, the runner, the scanner and the registry; a check that
requires the archive or the executable depends on their hashes. The
fingerprint (`kakyu_validation_fingerprint/v1`) is the SHA-256 of the
canonical JSON of the Core version, the command with the install paths
normalised (`<ELFIMAGE>`, `<EXE>`, `<PYTHON>`, `<GODOT>`, and since
2026-09-23 `<PROJECT>` for the project root in either slash form), the
sorted `[path, sha256]` pairs and the external hashes. Since WD-25 item 1
(2026-10-11) the `python regression suite` entry also carries an optional `exe`
clause (`optional_arguments` `--exe {exe}`, `optional_groups`
`native_executable`; the registry revision stays 5): with an executable
available the runner passes it to the suite, which hands it to every shard as
`KAKYU_ORIGINAL_EXE` (and removes any inherited value when `--exe` is absent),
the native-audit tests rebuild their fixtures from it instead of from tracked
bytes, and the suite's effective `requires` holds `exe`, so its fingerprint
includes the executable's hash. Without the executable those tests skip.
`tests/test_no_original_executable_bytes.py` Part B also scans `docs/`,
`content_core/` and the root `*.md` files, which lie outside the suite's
fingerprint roots (`tools`, `tests`, `config`), so a cached suite result does not
see a paste into them until the next uncached run or a change under `tools/`,
`tests/` or `config/`; the roots are not widened, because that would invalidate
the suite on every document edit.

Since WD-25 item 1b (2026-10-12) the same entry carries a second optional clause
keyed by `elfimage` (`optional_arguments` `--mes-arc {mes_arc} --data-arc {data_arc}`,
`optional_groups` `original_corpus`; the registry revision stays 5): with an
ELFIMAGE the runner passes the pair to the suite, which hands the two archives to
every shard as `KAKYU_MES_ARC` and `KAKYU_DATA_ARC` (the two are given together
or not at all, a missing file is a configuration error with return code 2, and
inherited values are removed when the pair is absent). The command names the two
archive placeholders and never `{source_root}`, so the suite's fingerprint hashes
exactly `mes.arc` and `data.arc` (plus `exe` when given) and not every archive
under the ELFIMAGE. `tests/test_no_original_archive_bytes.py` Part B reads them
and refuses a tracked 8-byte window (4 Japanese characters) that fewer than 100
of their entries hold; without the pair Part B skips. It scans `tools/`,
`tests/`, `content_core/`, `docs/`, `config/` and the root `*.md` files and does
not scan base64 strings or tracked binary files (the author's companion
inventory covers them); `docs/` and the root `*.md` files lie outside the
suite's fingerprint roots, as for the executable guard. The top-level
`original_corpus` and `native_executable_audit` flags of a report record whether
the tier planned those checks; the coverage rows count the checks that carry the
group. The Python suite carries `original_corpus` when handed the archives and
`native_executable` when handed the executable, so a local-tier run with an
ELFIMAGE reads `original_corpus` as "included (1 check)" while the flag stays
false. Normalising the
project root lets a whole batch run on a detached worktree - the way whole
batches are run - store green results the main checkout reuses; before it,
the first `--cache-store` whole run (Core 0.360.0, 2026-09-23) seeded
nothing the main checkout could hit. Every fingerprint moved with the
change, so the cache starts empty for it.

`tools/content_suite/validation_cache.py` keeps one entry per fingerprint
under `analysis/validation_cache/<fp[:2]>/<fp>.json`
(`kakyu_validation_cache_entry/v1`: name, fingerprint, `passed`, duration,
`recorded_at`, `run_id`, `core_version`). Only a passed result with exit
code zero is stored; a lookup that finds a different name, a malformed
entry or no entry is a miss. Nothing is read or written unless asked:
`--cached` reads and writes, reporting a hit as a `cached: true` row
(return code 0, duration 0, `cached_at`, `cached_run_id`) and running the
rest - the analysis-group process over the misses only; `--cache-store`
writes without reading. A `python` check's inputs include the project
paths among its arguments. **A check's external inputs are the archives its
command names - or all eight when it receives `{source_root}`.** Report schema v5 adds the `cached` count and the
`cache` (`consulted` / `not_consulted`) and `cache_dir` context.

**The archives a `{source_root}` check fingerprints (TD-53, 2026-10-06).** Eight: `mes.arc`,
`mmo.arc`, `data.arc`, `voice.arc`, `se.arc` and, since TD-53, `bgm.arc`, `tina1.arc` and
`tina2.arc` - the runner's placeholder context carries one entry per archive
(`_registry_placeholder_context()`; `validation_inputs._ARCHIVE_CONTEXT_NAMES` lists the
same eight and a test pins the two lists equal). Until TD-53 the last three were in neither, so a
check that names `{source_root}` kept its cached pass after a change of one of them - among such
checks the playback package export and the group-routes playback pass, the Audio Editor original
integration, `original content set`, the ARC and audio corpus checks, the unreferenced-entries
audit and the station/Mahoko plan validators. The three are **context
only**: not registry placeholders (`KNOWN_CHECK_PLACEHOLDERS` stays the placeholders the registry
uses) and not `requires` conditions, because no command names them. An archive whose file is
absent from the ELFIMAGE root is left out of the check's input set, as `voice.arc` and `se.arc`
always were, so a root without them still plans, runs and fingerprints (the fingerprint differs
from the one with the archive, so adding it later is a miss). An archive is fingerprinted by
its **full SHA-256 over the whole file** (`fingerprint()`, `Path.read_bytes()`), memoized per
run in the process and never stored between runs, so every `--cached`/`--cache-store`/`--fingerprints`
run reads each archive once: measured on the development machine, warm, the eight archives
(1,547,787,713 bytes) take 1.17 s, of which the three added ones (556,488,106 bytes) take 0.42 s;
a whole `--fingerprints` pass over 475 checks took 5.3 s before and 5.7-5.8 s after
(`analysis/_undoc/td53/`). The change moves every `{source_root}` check's fingerprint, so the
first run after it re-runs them.

**A check must receive `{source_root}` when its script reads any archive its arguments do not name
(TD-53 follow-up, 2026-10-06).** The premise above - external inputs are the archives the command
names - holds only if no script derives a sibling archive from a single-archive argument. One did:
`original ARC Browser original integration` took `{mes_arc}` and, in its WD-16 large-ARC block,
opened `voice.arc` and `bgm.arc` from `mes.arc`'s directory, so a change of either kept its cached
pass. Its registry argument is now `{source_root}` and the script takes `mes.arc` from that root
with `path_join` (the way `validate_audio_arc_editor_original.gd` does); behaviour is otherwise
unchanged, including the `large_archives=absent` skip. A sweep of the checks that name a
single-archive placeholder (`{mes_arc}`, `{mmo_arc}`, `{data_arc}`, `{se_arc}`, `{exe}`) found no
other script that reads `get_base_dir()` of its argument, an `ELFIMAGE` path or a second archive
literal. `validate_image_arc_editor_original.gd` names both `{mmo_arc}` and `{data_arc}` itself.

## Parallel checks (`--jobs N`)

Since 2026-09-23 (TD-33) `--jobs N` runs up to N checks at once; the
default `1` keeps the sequential path, its order and its output unchanged.
With N > 1 the planned checks (after the tier, `--check`, the cache and the
analysis-group collapse) are ordered longest first by the duration last
recorded for each - the previous report at `--report`'s path (a run row, not
a cached one), else the cache entries, else registry order; the two sources
merge per check (TD-40, 2026-10-03: before it, one run row in a reused report
discarded the whole cache, so every check the report lacked or held only as a
cached row was ordered last) - **times the slots the check occupies**
(`min(weight, N)`, TD-58 D9, 2026-10-09: a weight-4 check parks a worker
thread until four slots are free, so by its duration alone it started behind
shorter single-slot checks and ran late; the closing batch of 2026-10-10
measured the full handoff equivalence in the first wave, at +37 s, but the
Python suite only at +2,545 s, because the gate then reserved nothing; since
TD-65 it serves in arrival order, see below). An `exclusive` check is
ordered after every non-exclusive check, longest first among the exclusive
ones (TD-64 D4, 2026-10-10: an exclusive check takes every slot, so ordered
earlier it would drain the machine at its turn and hold back every check
behind it; TD-65's gate keeps that reason);
a process check or shard (`members`) is ordered by the sum of its members'
durations at one slot. The runner reads these durations once in `main()` and
hands them to the scheduler and to the analysis-group partition alike. The
ordered checks are handed to N worker threads. A
check occupies one slot; the Python regression suite and the full handoff
equivalence each occupy `--python-jobs` slots (any entry whose arguments carry
`{python_jobs}` does: both parallelize themselves, the suite in subprocess
shards and, since TD-40, the equivalence on a process pool of that size); an
`exclusive` check or scene occupies every slot. **The slot gate serves
waiters strictly in arrival order** (TD-65, 2026-10-10, `_WorkerGate.acquire`):
a waiter takes its slots only when every earlier waiter has been served and
enough slots are free for it. At a release the head waiter is served if it
fits and otherwise nobody is, so a later waiter never takes slots while an
earlier one waits, and arrival follows the order above because the worker
threads pop that queue. **The trade is idle slots:** a multi-slot head waiter
that needs more slots than are free leaves the free ones unused (up to
`weight - 1` of them) until enough running checks end - a single-slot waiter
behind it does not take one - and an `exclusive` head drains the machine, so
no later waiter starts until it has run. That is why the weight-4 checks are
ordered early, while few single-slot checks run beside them, and the
exclusive ones last. A waiter that leaves the queue by an exception never
blocks those behind it. Before TD-65 the gate made no reservation: when slots
freed up every waiting worker woke and the first to take the lock whose weight
fit won, so a weight-4 check early in the order was overtaken by single-slot
checks and waited until the queue drained (the 2026-10-10 closing batch lost
about one worker of six for ~1,800 s that way). Each Godot child runs with its own `APPDATA` (which moves
`user://`), `TEMP` and `TMP` under `analysis/validation_workers/<run>/<slot>`;
a Python child keeps `APPDATA` there but gets `TEMP`/`TMP` under the system
temporary directory, outside the project, because tools such as
`collect_mes_runtime_trace.py` refuse an output inside it. A check's output
is printed as one block when it ends, the report's rows stay in plan order
whatever the completion order, and a planned check that yields no row - a
worker exception included - becomes an `error` row, so the run cannot pass
with a check missing. The scratch trees are removed after a green run and
kept after a red one. Each check keeps its own timeout, so heavy checks run
side by side reach theirs sooner. Report schema v6 adds `jobs` to the
context (v5, v4 and v3 still load; a v5 or older report normalises to
`jobs: 1`).

**The multi-slot checks run back to back (TD-67, 2026-10-11, at every `--jobs`).** The sort above leaves one
failure open: a single-slot check whose key lands between two multi-slot ones puts one of them behind it, and a
strict-FIFO head idles exactly when it reaches the head with fewer slots free than it needs (TD-56's batch: the
transfer-direction corpus, key 945.5, against the Python suite, 236.33 s x 4 = 945.3; three slots idled for 839 s).
After the sort, `_order_checks_for_run` therefore applies one more rule:
- **M0** is the first non-exclusive check that occupies more than one slot (`min(weight, N)`; a check with `members`
  counts one), at index `i0` of the sorted order.
- **The window** is the next `max(0, N - slots(M0) - i0)` non-exclusive single-slot checks after M0, taken from the
  sorted order. They are M0's fillers: the two shards and the critical path run beside it.
- **The later multi-slot checks** follow M0 and its window, in sorted order, so the next one is the head at the moment
  the previous one frees its slots. Everything else keeps the sorted order, and the exclusive checks stay last.
- With fewer than two multi-slot checks, and at `--jobs 1`, the result is the sorted order unchanged. The gate
  (`_WorkerGate`, TD-65) is not changed. "Multi-slot first" would be wrong: it puts the suite ahead of the shards, and
  the suite cannot fit beside the equivalence.

On the model of `analysis/_docs/wd10_td67_model.py` (the strict-FIFO simulation of TD-64 part 2, which reproduces
TD-56's batch at 2,744 s and 2,519 idle slot-seconds against the measured 2,742.9 s and 2,517), the rule gives 2,324 s
and 1 idle slot-second on TD-56's tie keys at `--jobs 6` (the work bound), and reaches the work bound at every `--jobs`
from 3 to 6 on TD-56's own keys, TD-64 part 2's and an adversarial tie. A gate that lets a later waiter backfill was
modelled too and rejected: it recovered 105 of the tie's 420 s, nothing at `--jobs 5`, and it makes the gate depend on
recorded durations. **`--jobs 5` and `4` idled slots without any tie** (TD-56's own keys: 3,433 s with 3,239 idle
slot-seconds at `--jobs 5`, 4,332 s with 3,425 at `--jobs 4`, against 2,785 s and 3,476 s with the rule): the
equivalence takes four slots and one shard takes the fifth, the second shard then heads the queue and takes the
equivalence's freed slot, so the suite cannot fit beside the first shard. TD-65's strict FIFO made those two worse than
the old gate; no recorded batch shows it, because the owner runs `--jobs 6` and the Launcher `--jobs 1`.
**The residual risk** is in the keys, not the rule: a single-slot check whose key exceeds a shard's member sum
displaces that shard from the window, and the shard then starts after the suite. A shard's member sum under-estimates
its wall time: TD-56's shards ran 1,659 and 1,694 s against member sums of 1,240 s, and WD-10's closing batch ran them
1,722 and 1,755 s against 1,137.4 and 1,138.0 s, so the sum fell 25-27% and then 34-35% short of the wall time. The margin
is a shard's member sum minus the largest other single-slot key, and it has moved: at TD-56's launch it was 1,240 s against
~945 s (the transfer-direction corpus), about 295 s; at WD-10's closing batch it was ~1,138 s against 931.8 s (the analyzer
handoff corpus), about 206 s. It is a question of the ordering keys (TD-58 D9), not of the rule.
`tests/test_validation_scheduler.py` pins the order on the tie and on the batch's own keys at `--jobs` 6 to 2, the window, the exclusive checks, and, at the gate, that the order the function returns leaves no slot idle when a
single-slot check is keyed between two weight-4 checks.

Measured 2026-09-23 on the development machine while a whole batch and an
agent shared it (so indicative): `--tier local` 134 of 134 in 270-279 s at
`--jobs 1` and 190-197 s at `--jobs 4` (four runs, one pass set);
`--tier archive_quick` 214 of 214 in 718 s and 710 s at `--jobs 4`.

`original catalog group routes` takes ~1,500 s alone against its 1,800 s
limit and timed out twice under shared load on 2026-09-23, so since
revision 4 it runs as four shards
(`validators/validate_catalog_group_routes.gd` `shard=K/N`: a row belongs to
shard K when its index among the catalog's analysis-group rows modulo N is
K-1; the guard-form and forged-request checks run in shard 1 only; the
archive-unchanged check in every shard). At `--jobs 4` the four shards took
538, 624, 628 and 588 s, 628 s in all, and their sums equal the unsharded
run (221 runs, 17 unmeasured options, 3/3 guard-form runs, outcomes chain 15
/ map_return 172 / place_menu 28 / unresolved 6, 142 Playback runs,
pictures 658/668, voices 1,667/1,667, BGM 528/528); only the raw check tally
differs, +12, because four end-of-pass sanity checks run once per shard. The
Playback pass now names every picture, voice, BGM or effect it cannot find
(`PLAYBACK_<KIND>_MISSING` lines and `playback_*_missing_names`). *That was a report
only on 2026-09-23 - a miss counted and printed, and the shard printed `PASS shard`
whatever it found; since WD-21 U1 C3 (2026-10-06) a miss the known-absent register
does not list fails the shard, as the next paragraph says.*

**Known-absent media gates (WD-21 U1 C3, 2026-10-06).** `original playback package export`
compares the package's absent media names with `config/event_catalog/known_absent_media_v1.json`
before it writes anything - equal for the default full build, "no unregistered absence" for
`--event` or any other variant, and the package's `archives` header must equal the register's -
and each `original catalog group routes` shard fails, printing `FAIL shard` where it used to
print `PASS shard` unconditionally, on a Playback-pass miss the register does not list (the
`PLAYBACK_<KIND>_MISSING` lines and `playback_*_missing_names` now carry `registered`); both
gates are a tool decision over an original-data fact (the original archives lack those names),
recorded on the [package contract page](workspace_playback_export.md).

**Gate 3, declared media (WD-21 U2 C5, 2026-10-08).** The same Playback pass now also
compares the instrument with the declaration: every medium name the played timeline uses
must be the `entry` of one of the row's catalog `resources`
([`docs/spec/tech/event_player.md`](../tech/event_player.md), "A row's `resources`"). The
categories are the five gate 2 reads, one per step field - `PICTURE` (`pictures`),
`ANIMATION_SOURCE` (`animations`, both the `mmo` and `ax` resource kinds), `VOICE`
(`voice`), `BGM` (`bgm`) and `EFFECT` (`effects`) - and the compare is by upper-cased name
only, because the timeline keeps no offset and the catalog item no kind (a name declared
under any entry, offset or kind declares the played one; an empty name is not a medium
name). A medium the row does not declare prints `PLAYBACK_UNDECLARED_<CATEGORY>` with its
event id, step and name, fails the shard and counts in the summary line ("N played media
names compared with the declared resources, M undeclared") and in the JSON report
(`playback_media_compared`, `playback_undeclared`, `playback_undeclared_by_category`,
`playback_undeclared_names`). It proves the declared list covers the default playback; the
converse (everything declared was reached by a measured run) holds by construction of the
list. The pure compare is `tools/content_suite/declared_media.gd`, tested by
`tests/test_declared_media.tscn`; it reads only the catalog row and the played steps, so the
check's TD-32 input closure gains nothing beyond the new script the validator preloads.

**Gate 3 sees the library media (EP-14, Core 0.378.0, 2026-10-11).** Until Core 0.377.0 the
timeline was built from the probe's route trace and never saw a `LIBLARY.LIB` row. Since Core
0.378.0 it also presents the media a shared library routine executes - routine 27's pictures
and routine 9's sound effects, from the probe's `library_media` list - so the name-level
compare above includes them and its "played media names compared" number rises. Two additions
sit beside it, both reading only the catalog row and the played steps:

- **The library-coordinate compare** (`compare_library`). A name-level match cannot see a wrong
  `(entry, offset)`, the labelling TD-55 repaired, so each played medium that carries a
  `library_call` must match a declared item at `(request_entry, request_offset, entry) ==
  (source entry, source offset, name)`, both names through the one
  `ClassifierScript.normalize_name`. A mismatch prints
  `PLAYBACK_UNDECLARED_LIBRARY_<CATEGORY>` with the event id, step, name, the library coordinate
  and the `library_call` that ran it, **fails the shard**, and counts in the summary line
  ("N library media presented (P pictures, E effects), compared at their library coordinates, U
  undeclared") and in `playback_library_media_compared`, `playback_library_undeclared` and
  `playback_library_undeclared_names`. The medium's entry is its timeline entry's own
  `source_entry` (pictures, animations and effects all carry it since the EP-14 follow-up); an
  entry without one matches no item, so the compare fails closed. Route-own media (no
  `library_call`) are not in this compare. It adds no per-row passing `_check`, so the shard's
  check count does not move.
- **The coverage report** (`library_coverage`), **never a failure**. It counts the row's
  `LIBLARY.LIB` items (`playback_library_items_declared`) and those a played library medium
  matches at its coordinate (`playback_library_items_presented`, each item once, split by
  category in `playback_library_presented_by_category`); the summary line states them ("D
  declared library items, K presented"). It is not a failure because a row's declaration is the
  union over every measured variant while the Playback pass plays one preset per row, and
  because the `unclassified` kinds (the function-24 loader strings and routine 33's dispatch
  strings) have no presented form. `playback_library_media_rows` is the validator's own record
  of each played library medium - `{event_id, step, category, name, at, routine, caller_entry,
  caller_offset}` - and so of the MES-anchored coordinate of the shared call that ran it.

A declared-but-not-played report over every item is not taken: the Playback pass plays one
preset per row, so such a count would measure variant coverage, not a defect.

**Twenty shards since the EP-12 all-menus unit (2026-10-04).** The catalog grew
from 214 to 554 rows and the 340 new rows are album scenes, each a two-hop flow
of one to over a hundred messages whose Playback pass resolves every picture,
voice and effect. One solo run of `shard=1/8` on the new catalog (70 rows, 47 of
them album rows; 95 group-route runs, 5,304 checks, no failure) took 1,470 s,
about 21 s a row against roughly 10 to 14 s for the non-album rows of the earlier
sizing, so the whole set is about 11,800 s of shard work - four shards would have
been about 2,950 s each alone, past the 3,000 s timeout once loaded. The shard
count is set so that each shard is expected to run about 1,000 s at `--jobs 6`
(a shard of 27 or 28 rows: roughly 590 s alone, times the 1.3 to 1.85 that a
loaded `--jobs 6` batch has cost these shards so far), inside half of the
unchanged 3,000 s timeout. Measured in the whole batch that followed
(`--jobs 6`, uncached, 432 of 432 passed in 4,251 s): the twenty shards took
507-695 s (mean 585 s; 554 rows, 42,412 checks over the twenty) - the loaded batch
cost them about 0.9 to 1.2 times their solo estimate, so fewer shards (twelve)
would have sufficed; the sizing is kept. `gallery_rows_checked` in each shard's
JSON counts the album rows whose status line it asserted (the shards sum to 365,
as measured).

**The recollection ladders (EP-12 H unit, 2026-10-04).** 13 more analysis-group checks
(`original event analysis 43C <NAME> H`, 280 -> 293 entries, 300 s timeout each; 15-17 s
alone) and 13 more rows (567; shards of 28 or 29 rows). A ladder row plays 570-911
lines, so the expectation was a cost many times an album row's (the unit's own note: 5-10x); one solo run of the shard
that holds two of them with the most album rows (`shard=18/20`: 28 rows - two ladders,
eighteen album rows and eight others; 34 group-route runs, 3,464 checks, no failure,
`gallery_rows_checked` 18) took 574 s against the typical shard's 590 s: the two ladders did not raise it
measurably (the cause is not isolated here; a ladder's profile is small, 11-14 KB against
70-190 KB for an album menu, and a route is two hops). The ladders land in eleven shards (3, 4, 5, 10, 11, 12,
15, 16, 17, 18, 19); no shard is expected past the ~1,200 s bound the unit set for a
re-size, so the count stays 20. Measured in the whole batch that followed (`--jobs 6`,
uncached, 445 of 445 passed in 5,155 s): the twenty shards took 587-769 s (mean 667 s; 567
rows) and the 13 ladder checks 17.7-22.7 s each, none near its 300 s timeout; the batch ran
about 14% slower per check than the previous one, which put four small-timeout checks past
half their timeouts (`todo/code_health.md` TD-46).

**The TALK scripts of heroine K (EP-12 TALK K unit, 2026-10-04).** 2 more analysis-group checks
(`original event analysis 01M K talk`, `original event analysis 27C_EV K talk`, 293 -> 295 entries, 300 s timeout
each) and 9 more rows (576; shards of 28 or 29 rows). Measured in the whole batch that followed (`--jobs 6`, uncached,
447 of 447 passed in 4,538 s, Core 0.371.0): the twenty shards took 538-665 s (mean 606 s; 12,129 s over 576 rows,
21.1 CPU-s per row against 23.5 for the 567 rows of the recollection unit's batch: the K rows - up to 25 messages
in a route's hop 2, three hops - did not raise the cost), the two checks 39.5 s (eight routes) and 14.3 s. The
longest checks stayed at 0.41 of their timeouts or less, and the four small-timeout checks of TD-46 ran 0.21-0.27
of their raised timeouts (`todo/code_health.md` TD-46, closed).

**The TALK scripts of the other heroines, Tina and the characters (EP-12 TALK rest unit, 2026-10-05).** 26 more analysis-group
checks (`original event analysis 01M <letter> talk`, `original event analysis 27C_EV <letter> talk`, `01M M`, `01M Q`, `11M N`, 295 -> 321
entries, 300 s timeout each) and 105 more rows (681; shards of 34 or 35 rows). Measured in the whole batch that followed (`--jobs 6`, uncached,
473 of 473 passed in 5,156 s, Core 0.372.0): the twenty shards took 599-867 s (mean 721 s; 14,427 s over 681 rows, 21.2 CPU-s per row against 21.1 for
the 576 rows of the K unit's batch: the 105 rows - up to 49 messages in a route's hop 2, three hops - did not raise the cost), the 28 TALK checks
13.9-59.5 s (the twelve ladder groups 38-60 s, `original event analysis 01M J talk` the slowest at 0.20 of its timeout), and the longest checks stayed
at 0.42 of their timeouts or less - except `original playback package export`, 326 s of its 600 s timeout (0.54: the package carries 681 events from 869
member entries; 269 s solo), which `todo/code_health.md` TD-50 closed on 2026-10-05: the tier is defined by the registered timeout (`archive_quick` is 600 s or
less), and TD-46's rule (a timeout of at least twice the loaded duration) asks for 652 s or more, so the check moved to the `full` tier at 900 s rather than
the quick tier's cap rising. The four TD-46 checks ran 0.22-0.26 of their raised timeouts.

**The TALK follow-ups unit (2026-10-05, Core 0.372.0 unchanged).** `original playback package export` moved to the `full` tier at 900 s and took
315 s of it in the next whole batch (`--jobs 6`, 0.35; 268 s alone). That batch (`--cached --jobs 6` on the committed tree `faa917f`, every archive and
full check re-run because the registry and the catalog changed) passed 246 of 473 checks and **timed out the one analysis-group process at its
`families.analysis_group.process_timeout` of 3,600 s with eight of its 227 groups left** (the 227 members failed together); the same command run again
with only that process left passed 473 of 473 in 3,084 s (its groups summed 2,172 s alone, 2,447 s for the 219 it finished loaded). The slowest other checks
were the transfer-direction corpus (1,091 s, 0.45 of 2,400), the analyzer handoff corpus (1,084 s, 0.36) and the 20 group-route shards (620-976 s, 0.33 of 3,000
at most); the four TD-46 checks ran 0.23-0.29 of their timeouts. The process's timeout had never had TD-46's margin: `todo/code_health.md` TD-51 (closed 2026-10-05). **TD-51 (2026-10-05, advisor ruling):** the timeout was raised to
8,000 s and the runner prints the process's own `process:` line (see "The analysis-group family"). Measured in the uncached closing batch (`--jobs 6`, committed tree
`ce65d78`, Core 0.372.0 unchanged, uncached because the registry and the runner changed; run `97d1723b`): 473 of 473 passed in 5,177 s, and the line read
`process: original event analysis groups completed in 3614.516s (227 member(s), timeout 8000s)` - **3,614.5 s, 0.45 of 8,000 s** (2.21 times the loaded
duration), inside the 4,000 s the raise was sized for and **past the old 3,600 s timeout by 14.5 s**; the 227 members' own durations sum 2,425 s, so about
1,189 s of the process's wall time lies outside them when loaded (about 910 s in the solo run above). Among the slowest other checks were the transfer-direction corpus
(1,117 s, 0.47 of 2,400), the analyzer handoff corpus (1,119 s, 0.37 of 3,000) and the 20 group-route shards (574-986 s, 0.33 of 3,000 at most); the four TD-46
checks ran 0.21-0.25 of their timeouts, `original playback package playback` 557 s of 1,800 s (0.31) and `original playback package export` 274 s of 900 s (0.30). The same command with `--cached` served all 473 from the
cache in 7.7 s (run `6527acea`). **One check passed half of its timeout, and it is not a TD-46 check:** `Godot project parse check` (the `local`-tier
`godot_editor` entry, 120 s) took 79.9 s (0.67), against 30.3-44.6 s in the four uncached whole batches before it (`4f1ae99f`, `2395516c`,
`375b8653`, `4194a2d8`); it also timed out once at 120 s in an unrecorded `--tier local --jobs 6` run of the unit. The timeout is unchanged and
`todo/code_health.md` TD-52 (opened there, closed 2026-10-06) holds the diagnosis (the editor's first scan walks the untracked `analysis/`) and the options for a ruling.
**TD-52 fix (2026-10-06, owner ruling: option (a), the timeout stays 120 s):** `run_headless_validation.py` `ensure_editor_ignore()` writes an empty `analysis/.gdignore` from `main()` before either scheduler runs, in every tier (a tool decision; only when `analysis/` exists and the marker is absent, never rewritten; a create that fails with any other `OSError` is skipped, not fatal, since the marker only saves scan time; `tools/build_windows_distribution.py` keeps its own fail-closed `runtime/.gdignore` write - a different operation, not shared). Measured solo (`--check "Godot project parse check" --jobs 1`, 22,395 files in `analysis/`, nothing else running): **40.3 s and 38.6 s without the marker, 6.5 s with it** (0.05 of 120 s; reports `solo_before.json`, `solo_before2.json`, `solo_after.json` under `analysis/_undoc/td52/`), the output still the editor's `first_scan_filesystem` and `--- PASSED` (read on the console; a passed row records no output tail, so the reports do not show it). In the `--tier local --jobs 6 --cache-store` run `f1676b1e` (uncached: the runner changed) 136 of 136 passed in 269.6 s and the check took **7.95 s (0.07)**, against 53.5-67.8 s in the earlier local-tier runs and 79.9 s in the TD-51 closing batch.
**TD-52 closing proof (2026-10-06, Core 0.372.0 unchanged, uncached because the runner changed; committed tree `ebd440a`, the fix `274fd97` plus its review fixes):** the whole `full` tier at `--jobs 6` with `--elfimage`, `--exe` and `--godot`, `--cache-store`, detached (run `a171a199`): **473 of 473 passed in 5,282.4 s**, `cached: 0`. `Godot project parse check` took **8.86 s of 120 s (0.07)** loaded, against 79.9 s (0.67) in the TD-51 batch, the acceptance bound being 60 s (0.5); the detached log's block for it shows `first_scan_filesystem` through `DONE` and `--- PASSED` (a console reading; a passed row records no output tail). `analysis/.gdignore` was deleted before the launch and the runner wrote it again at the batch start (its modification time is 0.5 s after the process start the launch recorded), so the marker's presence is the runner's doing; it stays untracked. The analysis-group process line read `process: original event analysis groups completed in 3664.250s (227 member(s), timeout 8000s)` - **3,664.3 s, 0.46 of 8,000 s** (2.18 times the loaded duration), under the 4,000 s at which TD-51 re-applies its rule (3,614.5 s in `97d1723b`). The slowest other checks, as ratios of their timeouts: the transfer-direction corpus 1,015.5 s of 2,400 (0.42), `original relocated message contextual authoring` 245.9 of 600 (0.41), `original edited event contextual authoring` 221.3 and `original resource contextual authoring` 220.4 of 600 (0.37), `original playback package playback` 621.4 of 1,800 (0.35), `original playback package export` 306.2 of 900 (0.34), the analyzer handoff corpus 1,012.6 of 3,000 (0.34) and the 20 group-route shards 623-919 s of 3,000 (0.31 at most): **no check passed 0.5 of its timeout** (the highest is 0.42). The same command with `--cached` served all 473 from the cache in 7.7 s (run `0a056ef6`).

**TD-54 (2026-10-07, owner ruling):** `original edited event contextual authoring`, `original relocated message contextual authoring` and `original resource contextual authoring` moved from the `archive_quick` tier at 600 s to the `full` tier at 900 s in `config/validation/checks_v1.json` (the TD-50 form: `archive_quick` is capped at 600 s by `test_tier_ordering`, so the larger timeout means the larger tier). The C3.5 pre-run of WD-21 U1 measured them loaded at 290.8 s (0.485 of 600), 267.1 s (0.445) and 233.5 s (0.389), against 245.9, 221.3 and 220.4 s in the TD-52 batch; U1 adds about 8-10 s per build (whole-archive hashing of the seven media archives in `build()`), the rest is batch noise. The advisor put the risk that one of them passes 0.5 in the loaded whole batch at 55-65%, and the owner accepted the cost: `--tier archive_quick` iteration no longer runs these three. 900 s satisfies TD-46's rule up to a loaded duration of 450 s. `original sequence contextual authoring` is unchanged (`full`, 1,200 s). `todo/code_health.md` TD-54.

**WD-21 U1 closing proof (2026-10-07, Core 0.373.0, uncached because Core, the package contract and the registry changed; committed tree `dc99e46`):** the whole `full` tier at `--jobs 6` with `--elfimage`, `--exe` and `--godot`, `--cache-store`, detached and solo (run `7513c6ad`): **475 of 475 passed in 5,253.6 s**, `cached: 0` (the 473 of TD-52 plus the scenes `test_known_absent_media.tscn` and `test_playback_media_inventory.tscn`). The analysis-group process line read `process: original event analysis groups completed in 3691.453s (227 member(s), timeout 8000s)` - **3,691.5 s, 0.46 of 8,000 s** (2.17 times the loaded duration), under the 4,000 s at which TD-51 re-applies its rule. `Godot project parse check` took 17.0 s of 120 s (0.14; the detached log's block shows `first_scan_filesystem` and `--- PASSED`). The slowest checks, as ratios of their timeouts: the transfer-direction corpus 1,004.5 s of 2,400 (0.42), `original playback package playback` 745.1 of 1,800 (0.41; 621.4 s in the TD-52 batch), the analyzer handoff corpus 997.3 of 3,000 (0.33), `original playback package export` 309.1 of 900 (0.34), `original Audio Editor original integration` 95.4 of 300 (0.32) and the 20 group-route shards 582-906 s of 3,000 (0.30 at most). **The three checks TD-54 moved to the `full` tier at 900 s** took `original edited event contextual authoring` 221.8 s (0.25), `original relocated message contextual authoring` 242.5 s (0.27) and `original resource contextual authoring` 231.0 s (0.26) - against 290.8, 267.1 and 233.5 s in the C3.5 pre-run - and `original sequence contextual authoring` (1,200 s, unchanged) 338.8 s (0.28). **No check passed 0.45 of its timeout** (the highest is 0.42). The 20 shards printed `PASS shard` (none `FAIL shard`): over them 681 playback runs, 70 picture and 114 animation-source misses (`playback_misses_registered` 184, `playback_misses_unregistered` 0), voices 8,621 of 8,621 and BGM 1,801 of 1,801 found. The same command with `--cached` served all 475 from the cache in 8.5 s (run `3b0a2572`). The batch also re-seeded every fingerprint of the eight-archive input set (`todo/code_health.md` TD-53, closed): `--fingerprint-inputs` for `original playback package export` and for a group-route shard lists `bgm_arc`, `data_arc`, `mes_arc`, `mmo_arc`, `se_arc`, `tina1_arc`, `tina2_arc` and `voice_arc`.

**WD-21 U2 closing proof (2026-10-08/09, Core 0.373.0 unchanged; uncached because the `kakyu_event_definition/v7` contract and the catalog revision changed; committed tree `d5fa4395`):**

*Uncached run.* The whole `full` tier at `--jobs 6` with `--elfimage`, `--exe` and `--godot`, `--cache-store`, detached (run `4d0be71d`): **477 checks, 475 passed, 2 failed, 4,770.3 s**, `cached: 0`. The 477 are U1's 475 plus `test_replay_run_media.tscn` and `test_declared_media.tscn`.

*The two failures and their fix.* Both had one cause: `config/event_catalog/route_classification_v1.json` binds `catalog_sha256`, the SHA-256 of the catalog's canonical JSON (`canonical()` in `tools/classify_event_routes.py`). U2's C5 bumped the catalog to revision 41 without refreshing it.
- `original event analysis frontier` (0.4 s) printed "Classification is not bound to this catalog revision".
- `original event corpus literal dispatch inventory` (134.2 s) reported that the classification does not reproduce.

`tools/refresh_route_classification.py` showed `catalog_sha256` and the payload hash as the only delta: no row, class or confidence moved. The two lines were patched in place, LF kept (`425d9b0d`), and the classifier's `--check` passed. The two checks then passed solo with `--cache-store` (128.2 s and 168.8 s of 600).

*Cached run.* `--cached --cache-store --jobs 6` on `425d9b0d` (run `94a6094d`): **477 of 477, 474 cached, 242.6 s**. It re-ran the `python regression suite` (236.1 s), `original duplicate archive entries` (21.8 s) and `unreferenced archive entries` (5.0 s). `--fingerprint-inputs` shows that those three plus the two fixed checks are exactly the five checks whose input closure names the classification, so the 474 cached results cover the fix. The other catalog readers (the export, the group-route shards, the Event Catalog source bindings, `test_event_catalog.tscn`) carry `original_events_v1.json` but not the classification.

*Timings in the uncached run.*
- The analysis-group process: `process: original event analysis groups completed in 3180.375s (227 member(s), timeout 8000s)`, **0.40 of 8,000 s** (3,691.5 s in U1's batch).
- `Godot project parse check`: 14.8 s of 120 s.
- The slowest checks as ratios of their timeouts:

  | Check | Time | Ratio |
  |---|---|---|
  | transfer-direction corpus | 875.2 of 2,400 s | 0.365 |
  | `original playback package playback` | 634.6 of 1,800 s | 0.35 |
  | `original playback package export` | 298.4 of 900 s | 0.33 |
  | `original Audio Editor original integration` | 86.8 of 300 s | 0.29 |
  | analyzer handoff corpus | 866.5 of 3,000 s | 0.29 |
  | the 20 group-route shards | at most 793.9 of 3,000 s | 0.26 |

- No check passed 0.37 of its timeout.

*Gate results.* Over the 20 shards, 681 Playback runs:
- **gate 3:** 15,011 played names compared with the rows' declared `resources`, 0 undeclared;
- gate 2: 70 picture and 114 animation-source misses, all 184 registered, 0 unregistered;
- voices 8,621 and BGM 1,801 found.

Reports: `analysis/_undoc/wd21_u2/closing.json`, `closing_fix_targeted.json` and `closing_cached.json`.

**TD-57 closing proof (2026-10-09, Core 0.374.0; uncached because Core changed; committed tree `7331ea26`):**

*Uncached run.* The whole `full` tier at `--jobs 6` with `--elfimage`, `--exe` and `--godot`, `--cache-store`, detached (run `37a06f05`): **477 of 477 passed in 3,225.7 s**, `cached: 0`, against U2's 4,770.3 s. The unit gave the archive reader a per-open identity memo (`content_core/arc_reader.gd`, `get_archive_identity_fingerprint()`), and its effect is almost entirely in one family:

| Family | U2 | TD-57 |
|---|---|---|
| all 477 checks | 21,975 check-seconds | **10,007** |
| the 20 group-route shards | 13,473 s | **1,394 s** (63.2-83.1 s each) |
| the Event Player checks | 217 s | 124 s |
| package export and playback | 933 s | 941 s |
| the contextual-authoring checks | 993 s | 1,024 s |
| the analysis-group members | 2,260 s | 2,235 s |

*The floor.* `process: original event analysis groups completed in 3192.907s (227 member(s), timeout 8000s)`: **0.40 of 8,000 s and 99% of the batch's wall time**, so it is now the floor (`todo/code_health.md` TD-58).

*Timeouts.* The slowest checks as ratios of their timeouts:

| Check | Time | Ratio |
|---|---|---|
| transfer-direction corpus | 898.0 of 2,400 s | 0.37 |
| `original playback package playback` | 636.7 of 1,800 s | 0.35 |
| `original playback package export` | 304.3 of 900 s | 0.34 |

No check passed 0.38 of its timeout.

*Results.*
- The export check printed `package_sha256=5ae6aabe...`, the package the live v7 set was bound to from TD-57's C4 until TD-64's C4 (2026-10-10).
- Gate 3: 15,011 played names compared, 0 undeclared.
- Gate 2: 184 registered misses, 0 unregistered.

*Cached run.* `--cached --jobs 6` on the same tree (run `523b0a4b`): 477 of 477, all cached, 61.9 s.

Reports: `analysis/_undoc/td57/closing.json` and `closing_cached.json`.

**TD-58 and TD-64 part 1 closing proof** (2026-10-10, Core 0.375.0; uncached because Core, the runner
and the registry changed; committed tree `d367b5bd`):

*Uncached run.*
- **Command:** the whole `full` tier at `--jobs 6` with `--elfimage`, `--exe` and `--godot`, `--cache-store`,
  detached, solo (run `d2144d74`).
- **Sampler:** at 10 s for the first time in a closing batch. Its first row, 15 s before the runner,
  reads 35.8% RAM and 42.0% commit, against a limit of 31,157 MB.
- **Result:** **477 of 477 passed in 3,364.4 s**, `cached: 0`, and 10,727 check-seconds, against
  TD-57's 3,225.7 s and 10,007.

*The family's processes.* Both shards started at +37 s and ran at 0.23 of their 8,000 s timeout:

| Shard | `shard plan:` | `process:` |
|---|---|---|
| 1/2 | 113 member(s), 1117.295s known, 0 unknown | completed in 1861.469s |
| 2/2 | 114 member(s), 1117.733s known, 0 unknown | completed in 1867.391s |

The single process they replace took 3,192.9 s.

*Starts* (process creation minus the runner's):

| Check | Start | Duration |
|---|---|---|
| The full handoff equivalence (weight 4) | +37 s, in the first wave as D9 orders it | 673.7 s |
| The transfer-direction and analyzer handoff corpora | +711 s, the second the equivalence freed its slots | |
| The Python regression suite (weight 4) | +2,545 s | |
| `original playback package playback` (exclusive, last) | +2,802 s | 559.9 s |

The suite started only when the queue had drained: the gate has no reservation (TD-65).

*Memory, by window* (RAM peak / commit peak):

| Window | RAM | Commit |
|---|---|---|
| The pre-passes and the equivalence, 0-711 s | 72.5% | 60.8% |
| The export check, 1,074-1,420 s | 89.6% | 71.1% |
| The exclusive playback, 2,802-3,364 s | 94.3% | 73.0% |

Page-ins passed 1,000/s in 14 of 395 samples, never more than 2 in a row. D5 of
`analysis/_docs/td64_p1_spec.md` did not fire: (a) the pre-pass phase stayed at or below ~85%, and (b)
the commit charge stayed below ~85% of its limit.

*Timeouts.* The slowest checks as ratios of their timeouts:

| Check | Time | Ratio |
|---|---|---|
| `original Audio Editor original integration` | 125.8 of 300 s | 0.42 |
| transfer-direction corpus | 942.9 of 2,400 s | 0.39 |
| `original playback package export` | 344.5 of 900 s | 0.38 |
| analyzer handoff corpus | 935.0 of 3,000 s | 0.31 |
| `original playback package playback` | 559.9 of 1,800 s | 0.31 |

No check passed 0.5 of its timeout.

*The wall time missed its bound.* TD-64 spec D6 set "below ~3,000 s"; two causes explain the
difference:
- the exclusive playback check's ~560 s alone at the tail, which is TD-64's safety cost, removed by
  part 2;
- the suite's parked worker, about one worker of six idle for ~1,800 s (TD-65).

By owner ruling of 2026-10-10, the two units close on this batch. TD-65 lands with TD-64 part 2's
uncached batch.

*Cached run.* `--cached --jobs 6` on the same tree (run `68be8eb1`): 477 of 477, all cached, 9.9 s.

*The first attempt.* It ran on `f2289975` and was stopped at about 1,000 s, when the playback check took
RAM to 96-99% and commit to 90% of its limit (TD-64).

Reports: `analysis/_undoc/td58/closing2.json`, `closing2_cached.json` and `closing2_mem.csv` (with
`closing2_mem_procs.csv`). The stopped attempt's samples are in `closing_mem.csv`.

**TD-64 part 2 and TD-65 closing proof** (2026-10-10, Core 0.376.0; uncached because Core, the runner
and the registry changed; committed tree `1daa69ee`):

*Uncached run.*
- **Command:** the whole `full` tier at `--jobs 6` with `--elfimage`, `--exe` and `--godot`, `--cache-store`,
  detached, solo (run `72b516cc`).
- **Sampler:** at 10 s. Its first rows, before the runner, read 42.7% RAM and 42.4% commit (limit 31,157 MB;
  another application was open), inside the ~50% idle guard.
- **Result:** **477 of 477 passed in 2,452.2 s**, `cached: 0`, and 10,874.6 check-seconds, against the
  TD-58 batch's 3,364.4 s and 10,727 and TD-57's 3,225.7 s and 10,007.

*The family's processes.* Both shards started at +8 s and ran at 0.23 of their 8,000 s timeout:

| Shard | `shard plan:` | `process:` |
|---|---|---|
| 1/2 | 114 member(s), 1223.035s known, 0 unknown | completed in 1822.391s |
| 2/2 | 113 member(s), 1222.510s known, 0 unknown | completed in 1802.125s |

The members' own durations sum 2,479.8 s.

*Starts* (process creation minus the runner's, which began at 10:54:50):

| Check | Start | Duration |
|---|---|---|
| The two shards | +8 s | 1,822.4 s and 1,802.1 s |
| The full handoff equivalence (weight 4) | +8 s, in the first wave as D9 orders it | 608.0 s |
| The Python regression suite (weight 4) | **+616 s**, the moment the equivalence freed its slots | 252.7 s |
| `original playback package playback` (not exclusive) | +869 s, beside the transfer-direction and analyzer handoff corpora | 619.8 s |
| `original playback package export` | +1,231 s | 334.0 s |

The suite started at +616 s against +2,545 s in the TD-58 batch: that is TD-65's proof, the gate now serving
waiters in arrival order. The playback check ran beside other checks and no longer alone at the tail (it was
exclusive, +2,802 s, 559.9 s). The 20 group-route shards took 1,444 s in all (66.1-85.8 s each).

*Memory, by window* (RAM peak / commit peak):

| Window | RAM | Commit |
|---|---|---|
| The pre-passes and the equivalence, 0-711 s (the batch's peak) | 72.0% | 56.9% |
| 711-1,000 s | 53.6% | 47.4% |
| 1,000-1,900 s (the shard loops, the corpora, playback and export) | 64.8% | 53.3% |
| The tail | 65.8% | 53.8% |

**No sample row had page-ins over 1,000/s** (the TD-58 batch: 14 of 395). The playback window peaked at
64.8% RAM, below the 70-75% the C3 estimate allowed. The stop conditions of
`analysis/_docs/td64_p2_spec.md` (RAM above 90%, commit above ~85%, sustained page-ins) did not fire.

*Timeouts.* The slowest checks as ratios of their timeouts:

| Check | Time | Ratio |
|---|---|---|
| transfer-direction corpus | 945.5 of 2,400 s | 0.39 |
| `original playback package export` | 334.0 of 900 s | 0.37 |
| `original playback package playback` | 619.8 of 1,800 s | 0.34 |
| `original Audio Editor original integration` | 96.4 of 300 s | 0.32 |
| analyzer handoff corpus | 937.2 of 3,000 s | 0.31 |
| the two shards | at most 1,822.4 of 8,000 s | 0.23 |

No check passed 0.5 of its timeout. The four contextual-authoring checks took 263.1 to 362.8 s (0.29-0.31).

*The wall time against the model.*
- **Expected:** 2,500-2,650 s, from the strict-FIFO scheduler model's 2,508 s (part 1's durations, the playback
  check at its solo 548.6 s and not exclusive, the 37 s start-up part 1 showed); stop at about 2,750 s.
- **Measured:** 2,452.2 s, 56 s (2.2%) under the model and 48 s under the range. The first checks started at
  +8 s where the model carries 37 s, the equivalence took 608.0 s against 673.7 s, and the shards 1,802-1,822 s
  against 1,861-1,867 s. The model was not re-run on the new durations.
- **The decomposition** (a model; the two old-gate rows are a post-hoc replay of part 1's batch under an
  assumption about which waiter the old gate woke first, the FIFO rows are the prediction):

  | Gate | Playback | Wall |
  |---|---|---|
  | Old | exclusive | 3,364 s |
  | Old | not exclusive | 2,914 s |
  | FIFO | exclusive | 2,965 s |
  | FIFO | not exclusive | 2,508 s |

*Results.* The export check printed `package_sha256=47b1ee8d...`, the package the live v7 set was bound to from
TD-64 part 2's C4 until TD-56's C5 (the live package is `fe9bb6bd...` since EP-14's C4, 2026-10-11; `0e47e063...` was it from TD-56's C5 until then); it is
byte-identical to part 1's outside the manifest's `package_sha256` and `content_core_version`. The playback check printed its PASS line with 4,749 checks over 681 catalog events
(Core 0.376.0), the count unchanged.

*Cached run.* `--cached --jobs 6` on the same tree (run `d15a5def`): 477 of 477, all cached, 8.8 s.

Reports: `analysis/_undoc/td64p2/closing.json`, `closing_cached.json` and `closing_mem.csv` (with
`closing_mem_procs.csv`).

**TD-56 closing proof** (2026-10-11, Core 0.377.0; uncached because Core changed; committed tree `210162c4`):

*Uncached run.*
- **Command:** the whole `full` tier at `--jobs 6` with `--elfimage`, `--exe` and `--godot`, `--cache-store`,
  detached, solo (run `bcd678df`).
- **Sampler:** at 10 s. Its first rows read 44.0% RAM and 43.1% commit, inside the ~50% idle guard.
- **Result:** **477 of 477 passed in 2,742.9 s**, `cached: 0`, and 10,277.9 check-seconds, against the TD-64 part 2
  batch's 2,452.2 s and 10,874.6 (run `72b516cc`).

*The family's processes.* Both shards started at +7 s and ran at about 0.21 of their 8,000 s timeout:

| Shard | `shard plan:` | `process:` |
|---|---|---|
| 1/2 | 114 member(s), 1240.140s known, 0 unknown | completed in 1658.875s |
| 2/2 | 113 member(s), 1239.696s known, 0 unknown | completed in 1694.438s |

The members' own durations sum 2,275.4 s (2,479.8 s in the TD-64 part 2 batch).

*Starts* (offsets from the runner's start):

| Check | Start | Duration |
|---|---|---|
| The full handoff equivalence (weight 4) and the two shards | +7 s | 579.2 s (equivalence); 1,658.9 s and 1,694.4 s (shards) |
| The transfer-direction corpus | +587 s | 839.3 s |
| The Python regression suite (weight 4) | **+1,426 s** | 246.3 s |
| The analyzer handoff corpus | +1,666 s | 931.8 s |
| `original playback package export` and `original playback package playback` | +1,672 s | 317.8 s and 628.9 s |

The suite started at +1,426 s against +616 s in the TD-64 part 2 batch: see the wall time below.

*Memory* (RAM peak / commit peak):

| Window | RAM | Commit |
|---|---|---|
| The whole batch | 79.1% | 61.9% |
| The pre-passes window | 77.1% | 60.9% |

**No sample row had page-ins over 1,000/s.**

*Timeouts.* The slowest checks as ratios of their timeouts:

| Check | Time | Ratio |
|---|---|---|
| `original Audio Editor original integration` | 125.7 of 300 s | 0.42 |
| `original playback package export` | 317.8 of 900 s | 0.35 |
| transfer-direction corpus | 839.3 of 2,400 s | 0.35 |
| `original playback package playback` | 628.9 of 1,800 s | 0.35 |
| analyzer handoff corpus | 931.8 of 3,000 s | 0.31 |
| the two shards | at most 1,694.4 of 8,000 s | 0.21 |

No check passed 0.5 of its timeout. The 20 group-route shards took 64.5-116.8 s each.

*Gates 2 and 3.* The 20 shards, summed over 681 Playback runs: gate 3 compared **15,011** names, **0 undeclared**; gate 2
had 184 registered misses (70 picture and 114 animation-source), **0 unregistered**; voices 8,621 and BGM 1,801 found,
**0 sound effects**. They equal the C5 pre-run's figures (`analysis/_undoc/td56/c5/prerun_report.json`, 22/22). **The
comparison does not include the library items TD-56 restored:** the timeline is built from the route trace, which carries no
library runner rows, so routine 27's pictures and routine 9's sound effects are never presented (`todo/event_player.md`
EP-14). They are verified by the projector's join, the independent re-join and the tracked-set validator, not by playback.

*The wall time.* TD-56 had no wall-time stop. The batch took 290.7 s more than the TD-64 part 2 batch although its
check-seconds fell by 596.7 s: the extra is idle slots, not slower checks.
- **Cause:** TD-65's idling trade, triggered by an ordering tie. The run's report path was new, so `_order_checks_for_run`
  read the cache's durations only. The transfer-direction corpus (945.5 s, from `72b516cc`) took the ordering key 945.5; the
  Python regression suite (236.33 s, from a local-tier run on 2026-10-10) took its duration x 4 slots, 945.3. D9 therefore
  ordered `equivalence, shard, shard, transfer corpus, suite, analyzer handoff corpus, ...`.
- **Effect:** at +586 s the equivalence freed four slots, the head (the transfer corpus) took one, and the new head, the suite
  (four slots, three free), could not fit; strict FIFO let nothing behind it start. **Three slots idled for 839 s, 2,517
  slot-seconds**, until the corpus ended at +1,426 s. In `72b516cc` the suite's key (255.3 x 4 = 1,021) led, so no slot
  idled.
- **What it means:** the effect is deterministic given the cache state, and the bound "D9's order keeps the idling small"
  fails whenever a long single-slot check's key lands within noise of a weight-4 check's. Recorded as TD-67
  (`todo/code_health.md`); closed by WD-10's batch, below.

*Results.* The export check printed `package_sha256=0e47e063...`, TD-56's export B, the package the live v7 set has been
bound to since 2026-10-11 (catalog revision 43; it differs from export A in `package_sha256` and `source.catalog_revision`
alone). The playback check printed its PASS line with 4,749 checks over 681 catalog events (Core 0.377.0), the count
unchanged.

*Cached run.* `--cached --jobs 6` on the same tree (run `e60a071d`): 477 of 477, all cached, 8.8 s.

Reports: `analysis/_undoc/td56/c6/closing.json`, `closing_cached.json` and `closing_mem.csv` (with
`closing_mem_procs.csv`).

**WD-10 and TD-67 closing proof** (2026-10-11, Core 0.377.0 unchanged; uncached because the runner changed; committed tree
`8f81d232`):

*Uncached run.*
- **Command:** the whole `full` tier at `--jobs 6` with `--elfimage`, `--exe` and `--godot`, `--cache-store`, detached, solo
  (run `e6cb6108`), started 2026-10-11 16:17:19 local and finished 16:59:45.
- **Idle guard:** RAM was 46.5% before the launch (measured by the main session), inside the ~50% guard. The sampler's first
  row, 10 s into the run with the first wave started, read 51.4% RAM and 46.7% commit.
- **Cache hygiene (WD-10 D13):** before the launch exactly 16 entries named `original catalog group routes [k/4]` (four each,
  the retired four-shard names) were deleted, 10,321 -> 10,305 entries; no `--cache-clear`, because the ordering reads the
  cache's durations by name. None of those names remains.
- **Result:** **479 of 479 passed in 2,546.4 s**, `cached: 0`, and 10,715.5 check-seconds, against TD-56's batch (477
  checks, 2,742.9 s, 10,277.9; run `bcd678df`). The two checks added are `Godot test_mod_bundle_import.tscn` and `original mod
  bundle round trip`. The check-seconds rose 437.6 s, of which the two new checks are 191.4 s; the rest is spread over loaded
  checks (the family's 227 member rows +142.1 s, the transfer-direction corpus +70.2 s), consistent with more work running beside them now
  that no slot idled (an inference, not measured).

*The family's processes.* Both shards started at +7 s and ran at about 0.22 of their 8,000 s timeout:

| Shard | `shard plan:` | `process:` |
|---|---|---|
| 1/2 | 114 member(s), 1137.964s known, 0 unknown | completed in 1755.032s |
| 2/2 | 113 member(s), 1137.445s known, 0 unknown | completed in 1722.188s |

*Starts* (offsets from the runner's start, from the process census):

| Check | Start | Duration |
|---|---|---|
| The full handoff equivalence (weight 4) and the two shards | +7 s | 576.3 s (equivalence); 1,755.0 s and 1,722.2 s (shards) |
| The Python regression suite (weight 4) | **+583 s** | 257.8 s |
| The analyzer handoff corpus, the transfer-direction corpus and `original playback package playback` | +841 s | 892.4 s, 909.5 s and 596.5 s |
| `original playback package export` | +1,192 s | 317.9 s |
| `original mod bundle round trip` | +2,355 s | 179.5 s |

*TD-67's proof.*
- **The census is consistent with fix 1 and does not discriminate by itself.** On this run's keys there was no tie: the full
  handoff equivalence 579.3 s x 4 = 2,317, the shards' member sums 1,137.4 and 1,138.0, the Python suite 249.4 s x 4 = 998, the
  analyzer handoff corpus 931.8, the transfer-direction corpus 839.3 and playback 628.9 (the cache's durations at the launch,
  reconstructed). D9's sort alone already gave `equivalence, shard, shard, suite, analyzer, transfer, playback`, and the old
  runner would also have passed.
- **What the census shows.** The suite's runner process started at +583 s, within a second of the equivalence's end (+7 s plus
  576.3 s), against +1,426 s in TD-56's batch. The suite ended at +841 s, and the analyzer corpus, the transfer-direction
  corpus and playback started in that second.
- **The discriminating proof is at the gate:** `OrderedGateIdlenessTests` in `tests/test_validation_scheduler.py` (48 tests)
  drives a `_WorkerGate(6)` in the order `_order_checks_for_run` returns. On `f7a19049`'s runner it fails ("slots stayed idle
  after the equivalence ended: the fourth check in the returned order, 'transfer', took 1 slot(s)"): 14 failures (subtests
  counted) in 5 of the 7 new tests. The model (`analysis/_docs/wd10_td67_model.py`, machine-local) reproduces TD-56's batch at
  2,744 s and 2,519 idle slot-seconds against the measured 2,742.9 s and 2,517, and gives fix 1 on the tie keys at `--jobs 6`
  2,324 s with 1 idle slot-second. The orders at `--jobs` 6 to 2 and the `--jobs 4`/`5` finding are in `todo/code_health.md`
  (TD-67) and the paragraph above.

*The wall time.* The unit expected 2,330-2,500 s (the model's work bound 2,324 s on TD-56's durations and 2,452 s on TD-64
part 2's, plus the two new checks); the batch took 2,546.4 s, 46 s above the upper end and 196.5 s under TD-56's. **The excess
is the unkeyed tail, not TD-67:** the new archive check had no cache entry (its solo runs in C3 did not store one), so
`_order_checks_for_run` sorted it after every keyed check; it started at +2,355 s and ran 179.5 s nearly alone, and the three
exclusive scenes (12.2 s in all) ran after it, from +2,534 s. Keyed, it would have run beside the other work, so the tail
added about 150 s over the work bound; the advisor's pre-batch review found the check unkeyed and revised the expectation to
2,450-2,550 s. The 2,650 s stop was not reached. The cache holds the check's key now.

*Memory* (250 samples at 10 s within the run; RAM peak / commit peak):

| Window | RAM | Commit |
|---|---|---|
| The whole batch (peak at +519 s) | 78.8% | 61.7% |
| RAM at or above 70%: +366 to +519 s (16 samples) | 78.8% | 61.7% |
| +1,292 to +1,302 s (2 samples), +1,322 to +1,434 s (12) | 73.1% | 58.6% |
| four single samples at +2,034, +2,055, +2,106 and +2,126 s | 71.2% | 57.4% |
| +2,217 to +2,238 s (3 samples) | 76.1% | 60.1% |

RAM was at or above 70% in 37 samples, at or above 75% in 8 and at or above 80% in none. **No sample row had `pgin_avg` over
1,000/s in the run** (maximum 258.1); the rows above it - one at 17:00:42 and four at 17:07, under the later local-tier run -
are all after the batch ended. One 2-second reading
(`pgin_2s`) of 1,831/s at +1,994 s is a burst, not sustained: that row's interval average was 0.4/s and RAM 66.9%.

*Timeouts.* The checks above 0.3 of their timeouts, and the new ones:

| Check | Time | Ratio |
|---|---|---|
| transfer-direction corpus | 909.5 of 2,400 s | 0.379 |
| `original playback package export` | 317.9 of 900 s | 0.353 |
| `original playback package playback` | 596.5 of 1,800 s | 0.331 |
| `original Audio Editor original integration` | 91.0 of 300 s | 0.303 |
| `original edited event contextual authoring` | 270.9 of 900 s | 0.301 |
| `original resource contextual authoring` | 270.8 of 900 s | 0.301 |
| `original mod bundle round trip` (new) | 179.5 of 900 s | 0.199 |
| `Godot test_mod_bundle_import.tscn` (new) | 11.9 of 180 s | 0.066 |

No check passed 0.4 of its timeout. The new archive check is in the `full` tier at 900 s (C3's choice: solo 179.5 s and
179.0 s, above `archive_quick`'s ~100 s by TD-46's rule); at 600 s its loaded estimate (about 1.5 times solo) would have been
about 0.45.

*Results.* The export check printed `package_sha256=0e47e063...`, unchanged (no Core change), and the playback check its PASS
line with 4,749 checks over 681 catalog events. The new archive check printed its PASS line (entries, offsets and counts, the
bundle's `payload_sha256`; no dialogue) with the solo runs' bundle hash and assertion count.

*Cached run.* `--cached --jobs 6` on the same tree (run `aef4b99e`): 479 of 479, all cached, 9.5 s.

*Reading the log.* A `MES_ANALYZER_COMPLETION status=failed failures=1` line followed by `--- FAILED (0.000s) ---` under the
header `=== original MES analyzer handoff corpus ===` appears inside the Python regression suite's block. It is the captured
output of `test_audit_failure_remains_failed_in_the_batch_result` (`tests/test_run_headless_validation.py`), which feeds the
runner a fabricated failing child to prove the failure stays a failure, not a failure of the batch.

Reports: `analysis/_undoc/wd10/closing.json`, `closing_cached.json` and `closing_mem.csv` (with `closing_mem_procs.csv`).

**EP-14 closing proof** (2026-10-11, Core 0.378.0; uncached because Core changed; committed tree `a9de5086`):

*Uncached run.*
- **Command:** the whole `full` tier at `--jobs 6` with `--elfimage`, `--exe` and `--godot`, `--cache-store`, detached, solo
  (run `8b534111`), started 2026-10-11 19:55:29 local (10:55:29Z) and finished at +2,400.5 s.
- **Idle guard:** RAM was 47.7% before the launch (measured by the main session), inside the ~50% guard. The sampler's first row,
  10 s into the run, read 52.2% RAM and 46.8% commit.
- **Result:** **479 of 479 passed in 2,400.5 s**, `cached: 0`, and 10,723.2 check-seconds, against WD-10's batch (479 checks,
  2,546.4 s, 10,715.5; run `e6cb6108`). No check was added or removed, so the registry stays at 322 entries and revision 5; the
  Core version moved every fingerprint, which is why nothing was cached. The wall time is inside the unit's expected 2,330-2,500 s
  and 146 s under WD-10's: WD-10's tail was the then-unkeyed archive check (`original mod bundle round trip` started at
  +2,355 s and ran nearly alone), which has a key now.
- **Where the check-seconds moved** (+7.7 s in all): the 20 group-route shards sum 1,473.4 s against 1,403.7 s (+69.7 s,
  placement inside the batch, not the library media: the rise sits in four shards that ran beside heavier work - 1/20 78.3 to
  100.0 s, 2/20 83.2 to 105.9 s, 9/20 76.3 to 94.3 s, 10/20 74.9 to 80.2 s - while the other 16 are within a second of WD-10's,
  and the unit's own six-wide re-run of all 20 on the final tree summed 1,407.2 s, every shard within 3 s of WD-10's), the 227
  analysis-group members and `original event analysis frontier` (228 rows by that prefix) 2,550.9 s against 2,551.0 s (no
  change: EP-14 adds work to none of them), and the rest is
  spread over loaded checks both ways (largest: edited event contextual authoring -37.0 s, event corpus literal dispatch
  inventory -36.9 s, resource contextual authoring -35.4 s, `original mod bundle round trip` +34.0 s because it runs beside other
  work now, `original Audio Editor original integration` +31.8 s, MES analysis corpus +29.7 s).

*The family's processes.* Both shards started at +7 s and ran at about 0.22 of their 8,000 s timeout:

| Shard | `shard plan:` | `process:` |
|---|---|---|
| 1/2 | 114 member(s), 1209.067s known, 0 unknown | completed in 1771.984s |
| 2/2 | 113 member(s), 1208.460s known, 0 unknown | completed in 1741.797s |

*Starts* (offsets from the runner's start, from the process census):

| Check | Start | Duration |
|---|---|---|
| The full handoff equivalence (weight 4) and the two shards | +7 s | 574.4 s (equivalence); 1,772.0 s and 1,741.8 s (shards) |
| The Python regression suite (weight 4) | **+581 s** | 252.7 s |
| The analyzer handoff corpus, the transfer-direction corpus and `original playback package playback` | +834 s | 895.9 s, 905.8 s and 590.8 s |
| `original playback package export` | +1,183 s | 317.2 s |
| `original mod bundle round trip` | +1,736 s | 213.5 s |

The Python suite started within a second of the equivalence's end (+7 s plus 574.4 s), as under TD-67's fix 1 in WD-10's batch;
there was no ordering tie on these keys. The mod bundle check is keyed now and ran from +1,736 s beside the corpora, 213.5 of
900 s (0.237; 179.5 s nearly alone at the tail in WD-10's batch).

*The gate figures.* The 20 `original catalog group routes` shards inside this batch printed the same `PASS shard` lines,
summed figures and `playback_library_media_rows` as the unit's own re-run on the final tree (C3), compared line by line and row by
row, all 20 PASS:

| Figure | WD-10's batch | This batch |
|---|---|---|
| Rows / runs / checks | 681 / 839 / 58,186 | identical |
| Pictures found / total | 2,017 / 2,087 | 2,573 / 2,643 (+556, all `base`, `LIBLARY.LIB`; the 70 misses unchanged) |
| Animation sources / voices / BGM | 2,388 / 2,502; 8,621; 1,801 | identical |
| Effects | 0 / 0 | 138 / 138 found, 0 unknown effects |
| Gate 2 | 184 registered, 0 unregistered | identical |
| Gate 3, name-level | 15,011 compared, 0 undeclared | 15,705 compared (15,011 + 556 + 138), 0 undeclared |
| Library compare | none | 694 compared, 0 undeclared |
| Library coverage | none | 1,093 declared, **497 presented** (401 pictures, 96 effects) |

694 library media were played (556 pictures from routine 27, 138 sound effects from routine 9) in 271 rows with library pictures
and 80 with library sound effects. The unit's first expectation was 481 presented (386 + 95): the planner's estimate left out the
replays' `resume.executed`, and the 16 rows that differed were all instances of it (`todo/event_player.md`, EP-14, "the stop").

*Memory* (236 samples at 10 s inside the 2,400.5 s window; RAM peak / commit peak):

| Window | RAM | Commit |
|---|---|---|
| The whole batch (peak at +528 s) | 81.7% | 62.4% |
| RAM at or above 70%: +335 to +528 s (20 samples; the equivalence and the shards) | 81.7% | 62.4% |
| +1,169 s (1 sample) | 70.9% | 56.3% |
| +1,271 to +1,423 s (16 samples) | 75.5% | 59.3% |
| +2,064 to +2,074 s (2), +2,145 s (1), +2,206 s (1) | 71.3% | 57.1% |
| +2,257 to +2,267 s (2 samples) | 78.3% | 60.9% |

RAM was at or above 70% in 43 samples, at or above 75% in 14 and at or above 80% in 3 (+508, +518 and +528 s, 80.4%, 80.7% and
81.7%); none at or above 85%. WD-10's peak was 78.8% and TD-56's 79.1%; the 2.9-point rise is in the equivalence-and-shards phase
(the peak Godot working set across processes was 5.5 GB). The stop line (90%) was not approached. **One row had `pgin_avg` over
1,000/s** (5,400/s at +1,504 s), with that row's 2-second reading (`pgin_2s`) at 0.5/s, RAM at 60.9% and a drop in the Godot
working set: a process turnover counted in one 10-second interval, not sustained (the neighbouring rows are near zero; the
largest `pgin_2s` in the run is 427.9/s).

*Timeouts.* The checks above 0.3 of their timeouts:

| Check | Time | Ratio |
|---|---|---|
| `original Audio Editor original integration` | 122.8 of 300 s | 0.409 |
| transfer-direction corpus | 905.8 of 2,400 s | 0.377 |
| `original playback package export` | 317.2 of 900 s | 0.352 |
| `original playback package playback` | 590.8 of 1,800 s | 0.328 |
| `original relocated message contextual authoring` | 270.5 of 900 s | 0.301 |

No check passed 0.5 of its timeout, the unit's stop line. **`original Audio Editor original integration` is above 0.4 (0.409),
as it was in TD-58's and TD-56's batches (0.42 each), but it is not a trend:** its last 14 recorded runs in the cache, from
0.371.0 to 0.378.0, lie between 86.8 s and 125.8 s (0.29 to 0.42), including 125.8 s at TD-58 and TD-64 part 1, 125.7 s at TD-56
and 91.0 s in WD-10's batch (0.303); the swings follow what runs beside it. It has 59% of its timeout in reserve.

*Results.* The export check printed `package_sha256=fe9bb6bd3256...`, the unit's new export (C4), and the playback check its PASS
line with 4,749 checks over 681 catalog events (`Core 0.378.0 / kakyu_playback_package/v7`). The start-up failure the unit's replay
regeneration saw once under six-way launch (one Godot validator process, exit `0xC06D007F` after 3.2 s with no output; byte-identical
when run alone) did not recur in the shards, the export, the export check, the playback check or this batch: an observed,
unreproduced failure, recorded here so a recurrence is recognized.

*Cached run.* `--cached --jobs 6` on the same tree (run `e9db1622`): 479 of 479, all cached, 9.5 s.

Reports: `analysis/_undoc/ep14/c6/closing.json`, `closing_cached.json` and `closing_mem.csv` (with `closing_mem_procs.csv`).

The whole `full` tier at `--jobs 4`, 2026-09-23, on a detached worktree of
`db59f4b` with `--elfimage` and `--exe`, uncached: 375 of 375 passed in
2,897 s, against 7,638 s for the sequential whole batch of the same morning
(`5fb4337`). The checks' own durations sum to 8,695 s (each ran slower
beside three others; a local image-generation server was also running), a
parallel efficiency of 3.0 of 4. The longest-first order started the four
group-route shards and the three corpus checks first; the full Python
handoff equivalence (1,581 s here) is now the longest single check and so
bounds any further gain from more jobs. The duration seed for that first
ordering was written by hand from the two earlier reports, because the
shard names had no recorded durations yet; later runs read their own.

Since 2026-10-03 (TD-40) that check is parallel itself: `tools/audit_mes_handoff_equivalence.py
--jobs {python_jobs}` compares the 1,016 entries on a process pool and folds
the results in digest order in the parent, so its report is byte-identical to
the serial run's (report file SHA-256 `4cdc9696...`, same printed lines). Alone on
the development machine it took 2,301.7 s serial and 576.2 s at four
processes. The registry entry carries `--jobs` and `{python_jobs}`, so the
scheduler gives it `--python-jobs` slots like the regression suite.

## Tiers on the command line

`--tier local|archive_quick|full` (default `full`). Availability still
applies; `--check` composes with the tier (a name outside the tier is a
configuration error that names the tier). The report
(`kakyu_content_tools_validation/v4`) records the tier in its context,
sets `original_corpus` / `native_executable_audit` only when the tier
planned such checks, and gives a group excluded by the tier the coverage
reason `Excluded by --tier <tier>.`.
