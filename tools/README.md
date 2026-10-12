# Project Tools

MES Editor's **Authoring** tab connects the authoritative Python handoff to
state-literal preview, compilation, semantic diff, named-workspace publication
and automatic proof selection for Analysis Run. The first control edits one
same-width state literal; other structural editor families remain open.
See [MES authoring bundle](../docs/spec/data/mes_authoring_bundle.md) for the
local evidence contract and verification scope. Bundles include source evidence
and are not distributable mod packages.

The native executable audits and the tools that depend on them (WD-25 item 7;
listed in `config/public_snapshot/exclusions_v1.json` in the development
repository) are not part of the public source snapshot; their sections below
describe them for reference.

Run Python tools from the project root with the Windows `py` launcher. Each
tool owns its `argparse` parser and prints its own JSON line or text lines;
its standard output and exit code are its contract (validators parse the
JSON, the batch reads the codes) - an accepted pattern by the owner's
ruling of 2026-09-21 (TD-05), with the shared code being the value
helpers (`payload_values.py`), not the entry. Python image tools require Pillow:

```powershell
py -c "from PIL import Image; print(Image.__version__)"
```

The entire `assets/` directory is local-only and excluded from Git. Keep source archives and generated images under `assets/`, or pass an external source path only as read-only input. Never direct generated output back into an original game installation.

## Windows application delivery

`build_windows_distribution.py` exports all six release applications with a
shared isolated Python/Pillow runtime. Its pinned input archives, build command,
manifest checks and verification limits are documented in
[Windows Application Distribution](../docs/spec/tech/windows_distribution.md).
Exported authoring does not require a system Python installation. The developer
validation batch below remains a repository tool; saved reports can still be
opened in the exported launcher.

## Content Suite validation

Retired on 2026-09-21 (EP-10 unit 5c): the per-event validators
`validate_event_player_event{b01,b02,b03,b03_choices,b14,b15,d01,d02,d03,d05,d06,d08}.gd`,
`validate_event_player_catalog_playback.gd`, `validate_catalog_analysis_routes.gd`
and `audit_catalog_analysis_routes.py`, with their registered checks. The
run instructions for them further down this file are historical; every
catalog row is covered by `original catalog group routes`.

Run the full non-focus-stealing validation batch from the project root with:

```powershell
py tools\content_suite\run_headless_validation.py `
  --elfimage "<user-owned-ELFIMAGE>" `
  --exe "<user-owned-AI5WIN.exe>" `
  --jobs 6 --cache-store
```

Use `--cached` in place of `--cache-store` for a unit's closing proof once
this machine's cache is seeded (owner ruling 2026-10-03, `AGENTS.md`
"Verification").

`--jobs 6` is the documented batch setting (parallel batch: owner, 2026-09-23;
the value 4 -> 6: TD-40, 2026-10-03, measured against 5 as well); the runner's
own default is `1`, which the Launcher's background validation keeps.

The Python regression child process has a finite 3,600-second default budget.
Use `--python-timeout <seconds>` when a slower or faster validation host needs
an explicit local override; a timeout still fails the batch. The regression
runner balances independent unittest cases over at most four subprocess
shards by default. Use `--python-jobs <count>` to reduce CPU/memory pressure or
to select a measured host-specific concurrency level; every discovered case
still runs exactly once.

Validation report schema `kakyu_content_tools_validation/v6` (since 2026-09-23:
v5 - the run's tier, the cached rows and the cache context - plus `jobs` in
the context; v5, v4 and v3 reports still load) records the
executed scope, omissions, run identity, summary, and bounded failure output.
Add `--report analysis/validation.json` to save an atomic SHA256 envelope.
The Launcher **Validation results and coverage...** panel runs the same suite
in the background and
can reopen reports; v2 reports display as historical unsigned evidence with
unknown coverage. These are repository checks, not validation of active
workspace modifications or a mod package. Reports may contain local source
paths and must stay untracked. For a focused run, use for example
`--check "Godot project parse check"`; omitted checks remain visible in the
coverage report.

Since 2026-09-21 (TD-32 part 1) the checks are data: `config/validation/checks_v1.json`
(`kakyu_validation_checks/v1`) lists every check with its kind, script,
arguments (placeholders such as `{source_root}`, `{mes_arc}`, `{exe}`,
`{godot}`, `{python}`), timeout, coverage groups, what it `requires`
(`elfimage`, `exe`, `voice_arc`, `se_arc`, `event_corpus`) and its `tier`;
the Godot scenes are one family entry expanded from `tests/*.tscn` and each
analysis profile has its own `analysis_group` entry. `build_checks()` loads
and validates it (unknown kinds, missing scripts or profiles, duplicate
names and unknown placeholders fail closed). `--tier local` runs the
synthetic batch, `--tier archive_quick` adds the archive and executable
checks registered at 600 s or less except the analysis-group entries,
`--tier full` (the default) everything available - the nine long checks
and the 227 analysis-group runs; `--check` composes with it. Since 2026-09-21
(TD-32 part 2) the analysis-group entries selected for a run execute in
one Godot process (`validators/validate_event_analysis_groups.gd`, the
archive opened once, the registry's `families.analysis_group` block naming
the process check and its timeout); the report still carries one row per
group and `--check "original event analysis <name>"` still selects one -
`--check "original event analysis groups"` selects them all. The process
runs the Python exact-source audit once for all its profiles
(`tools/audit_event_analysis_group.py --profiles <p>...`, or
`--profiles-file` for a long list; one JSON line per profile, a
per-entry handoff cache), which is where the per-group seconds went.

**Since 2026-10-09 (TD-58, registry revision 5)**, the selected members are
split into up to `families.analysis_group.process_shards` processes (2),
never more than `--jobs` or the member count. Each process is named
`original event analysis groups [K/N]`, keeps the family's timeout, and
prints a `shard plan:` line. The split is LPT by each member's recorded
duration (report first, else cache). `--jobs 1` keeps the single process.
A shard name is not a `--check` name, because the split exists only at
run time.

Since 2026-09-21 (TD-32 part 3) a green result is reusable while its inputs
are unchanged. `--fingerprints` prints every planned check's fingerprint
(a static scan of the check's script and everything it references -
`res://` literals, class names, scene resources, Python imports and path
literals - plus the Core version, the normalised command and the archives'
and executable's hashes) and `--fingerprint-inputs "<name>"` lists one
check's inputs. The cache under `analysis/validation_cache/` is engaged
only when asked: `--cached` reads it - a stored green result is reported
as `cached: true` instead of running the check, and the analysis-group
process runs only the misses - and stores this run's green results;
`--cache-store` stores without reading (a clean full run that seeds the
cache); a red result is never stored; `--cache-dir <path>` and
`--cache-clear` manage the store. The report is
`kakyu_content_tools_validation/v6` (a `cached` count, `cache`,
`cache_dir` and `jobs` in the context).

`--jobs N` (default 1, since 2026-09-23, TD-33) runs up to N checks at once,
longest first by their last recorded duration; the Python suite takes its
shard count of slots, the three sibling-process scenes run alone, every
Godot child gets its own `APPDATA`/`TEMP` (so its own `user://`) under
`analysis/validation_workers/`, output stays one block per check and report
rows stay in plan order. A check's timeout still applies per check, so a
heavy check beside others reaches it sooner. `--tier local --jobs 4` took
about 190 s against about 275 s at `--jobs 1` on the development machine. Use `--cached` for iteration and for a
pre-commit batch whose changes the scan sees (code and tracked data); a
path built at runtime, or a change outside `content_core/`, `tools/`,
`tests/` and `config/`, is a reason to run without it.

**A run that must outlive its session (TD-40, 2026-10-03).** A background
process an agent's shell starts dies when that session exits. `launch_detached.py`
starts a command through WMI (`Win32_Process.Create`, so the WMI provider host is
its parent), with the project root as its working directory, its window hidden
and stdout+stderr redirected to a log, and writes a marker under
`analysis/_undoc/detached/` (untracked) holding the command, pid, log path and
start time:

```powershell
py tools\content_suite\launch_detached.py --name full-jobs6 -- `
  py tools\content_suite\run_headless_validation.py --elfimage "<ELFIMAGE>" --exe "<AI5WIN.exe>" `
  --godot "<Godot console exe>" --jobs 6 --cache-store --report analysis\_undoc\td40\full.json
py tools\content_suite\launch_detached.py --status          # running runs, log first/last line
py tools\content_suite\launch_detached.py --status --all    # finished ones too
```

The launched process gets WMI's default environment, not the calling shell's:
pass every executable and path as an argument (`--godot` for the batch; the
first word of the command is resolved to an absolute path in the caller's
environment). Arguments cannot contain a double quote, `%` or a newline (they
would be reinterpreted by `cmd.exe`). A child that timed out may leave its own
children behind; `--status` lists `*_console.exe` and Python processes that
mention the project and have lost their parent, and `Stop-Process -Id <pid>`
stops one.

Direct Godot checks fail on script/parse diagnostics even when Godot returns
exit code zero. The bounded failure report retains the diagnostic independently
of its position in the log. Ordinary application errors used by rejection tests
are not treated as script failures; Python negative tests own their subprocess
verdicts.

With `--elfimage`, the batch also runs the complete authoritative Python
handoff comparison against the tracked fingerprint-only frozen v45 digest.
`--require-full-equivalent` checks all 1,016 entries without a limit and keeps
actual Python hashes separate from the producer-only comparison hashes. The
historical Godot completion audit remains in the batch. A focused invocation
can select `--check "original Python Phase 1-4 full handoff equivalence"`.

The original-content batch includes the
bounded shared-library runner, the routine-25 external-DEF boundary audit, and
the composed EVENTD08 zero-start dialogue/choice routes in the original-content
batch. Passing
`--exe` runs the native ARC, MES, and bounded Ogg/voice executable audits. When
`--elfimage` is also present and contains optional `voice.arc`, the Ogg audit
binds the executable's literal filename to that indexed payload and validates
its bounded Vorbis metadata. A missing optional Voice ARC leaves the EXE-only
audit active. No check opens a Godot window or launches the original engine.
The original-content batch also exhaustively validates the shared detached DEF
preview contract. To run that read-only audit alone:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_detached_definition_previews.gd -- `
  <ELFIMAGE-directory>\mes.arc
```

It prints only entry names, coordinates, hashes, status/message counts, and
bounded samples; it never exports dialogue or changes the source archive.
The exact nested-DEF exception can be cross-checked separately:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_f_date2_nested_def.gd -- `
  <ELFIMAGE-directory>\mes.arc
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_f_date2.gd -- `
  <ELFIMAGE-directory>
```

These checks bind both `F_DATE2.MES` and the startup `DEF_MAIN.MES` registry,
compose selector 99 in a disposable sandbox, and report only coordinates and
aggregate counts.
The original-content batch instantiates all five independent app controllers:
ARC Browser reproduces the 1,016-row `mes.arc` index and hash-checks one streamed
extraction; Image Editor loads representative MMO and DAT/PAL pixels into its
embedded game frame; Audio Editor validates representative WAV and Ogg metadata
with playback kept stopped; MES Editor and Event Player run their bounded
original integrations. These checks stage no authored replacements and rehash
their sources.
The Event Player batch includes the focused EVENTD05 three-choice controller
replay. It validates the original `01M.MES` handoff, time-routed D05 frame,
Maki BGM and voices, bounded `D_PIC.MES` standing preview, two normal
`MACHI.MES` completion handoffs, and the distinct choice-3 early return. Run
that no-window check by itself with:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventd05.gd -- `
  <ELFIMAGE-directory>
```

`EVENTB03.MES` direct address-row Start deliberately remains fail-closed, while
Event Catalog Play supports the source-qualified choices 1-3 as partial
playback.
The original archive contains an exact `01M.MES:0x788F..0x789F`
command-`0x0E` target marker, and the source-qualified runtime trace now
confirms native host activation at callee coordinate zero. Catalog preset
`captured-result3-original` supplies the three proven state writes; ordinary
Play follows each selected original suffix and its B_PIC return to the
state-bound MACHI terminals `0x1BB6`, `0x26F4`, or `0x3D46`. The catalog's
**Preset** selector also offers `source-state12-100`: the same baseline plus
numeric `state_u16[12]=100`, with choices 1-3 qualified. Its 18-dialogue result-2
suffix temporarily writes zero and restores 100 before the terminal. This
is a source-audited representative, not a captured state or a confirmed
user-facing meaning for slot 12. Two further profiles,
`source-state12-100-affection36` and `source-state12-100-affection76`, retain
that state12 value and seed Mahoko affection 36/76. Choices 1/2/3 yield
38/31/39 for initial 36 and 78/71/79 for initial 76, with B.AX middle/high
column 0/2. Choices 1/3 leave state12 unchanged at 100. Other numeric, affection and date states
remain unqualified for product playback. The direct Start action remains
disabled because an address row supplies no catalog preset context.

The independent choice validator selects the exact catalog UI preset and
follows eleven genuine zero-start routes: baseline choices 1/2 and all three
choices for each initial-100 preset. It checks 19/20 baseline, 18 result-2
numeric-preset and 40 result-3 suffix dialogues,
shared-library calls, B_PIC/voice/effect media and station map terminals;
it checks temporary/restored state, exact affection/expression profiles,
rejects altered starting profiles and forged cross-branch continuations,
checks result-3 camera/DEF/native/effect boundaries, and checks source hashes again.
The separate baseline result-3 validator retains the detailed camera-input
and frame-composition regression:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventb03_choices.gd -- `
  <ELFIMAGE-directory>
```

The separate metadata-only state12 audit follows inputs 0, 1, 99, 100, 101
and 65535 directly through current Content Core, without Event Player or
audio. It checks both numeric branches and the original restoration at
`0x239D..0x23A6`. Auditing six values does not enable six UI presets:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_eventb03_state12.gd -- `
  <ELFIMAGE-directory>
```

The metadata-only `audit_eventb03_affection.gd` accepts the same source-root
argument and audits result-2 affection boundaries with state12 0/100 through
the authoritative Core. It checks the clamp/subtract writes, all three exact
B_PIC traces/cells and final restoration/terminal; audit coverage does not
qualify arbitrary initial values or prove native scheduler eligibility.

`audit_eventb03_preset_choices.gd` independently follows baseline results 1/3
and all six initial-100 result-1/3 routes through current Content Core. It
checks the exact +2/+3 affection writes, no state12 writes, complete final
diffs and unchanged branch-local controls/media, including result-3 camera,
six timed effects and the registered DEF/native boundaries. Reproduction and
the product boundary are in `docs/spec/mes/eventb03_preset_choice_routes.md`.

The B03 camera audit checks original MES/EXE identities, full command framing,
AX selected-cell controls, source-9 ownership and nominal mode-7/mode-8 return
samples. Run it read-only alongside the focused playback regression:

```powershell
py tools\audit_eventb03_camera.py "<ELFIMAGE-directory>\mes.arc" `
  "<user-owned-AI5WIN.original.exe>" --godot-console "<Godot-console-executable>"
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventb03.gd -- `
  <ELFIMAGE-directory>
```

Audit v3 labels generated samples as rational tool-clock projections, not a
native pixel/timing oracle. The reusable camera's synthetic check is
`res://tests/test_oversized_cg_camera.tscn`; Event Player tests additionally
cover logical drag/arrow/Enter input, source guards and source-only crops.
Both checks are included in the normal validation batch (the source audit
requires both `--elfimage` and `--exe`).
Core `0.278.0` uses instruction v45 and Event Runner trace v68. Regenerate older
analyzer handoffs after the AX/effect boundary corrections; do not relabel
their schemas manually.

Core 0.276.0 also corrects MES logical AND/OR to treat only the exact numeric
value 1 as true. Both operands are still evaluated. Instruction boundaries
and AST/trace shapes are unchanged; re-run cached execution results that used
nonboolean logical operands. The native proof is headless and read-only:

```powershell
py tools\audit_mes_logical_truth.py --exe "<user-owned-AI5WIN.original.exe>"
```

This audit joins the standard batch when `--exe` is supplied and does not
launch the original executable. The predicate and regression evidence is in
[MES Format and Method](../docs/spec/mes/format_and_method.md#logical-expressions-use-exact-one-truth-core-02760).

Core 0.277.0 adds the read-only station background plan, consuming the exact
original shared-library payload through the current GDScript decoder. The
source matrix checks numeric date/time boundary neighbors, all 12 producer
arms and nine MMO identities; the plan stops at routine 8 without executing
native refresh or qualifying additional EVENTB03 presets:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_station_background_plan.gd -- `
  <ELFIMAGE-directory>
```

The synthetic plan test and this `--elfimage` source check join the normal
headless batch. See [Station Background Selection](../docs/spec/mes/station_background_selection.md).

Core 0.278.0 adds a separate read-only Mahoko standing plan. With fixed
`global_u8[206]=1`, it selects B1/B2/B3/B4 from the original B_PIC date guards
and preserves dynamic copy expressions without evaluating or rendering them.
It stops before routine 22 (or at the face join for no-standing dates).
The synthetic test and this source audit are part of the normal headless batch:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_mahoko_standing_plan.gd -- `
  <ELFIMAGE-directory>
```

This does not add Event Player dates or presets. See
[Mahoko Standing Selection](../docs/spec/mes/mahoko_standing_selection.md).

Core 0.279.0 adds an analysis-only EVENTB03 candidate plan for the original
`01M.MES:0x7691` guard. It verifies the exact numeric predicate and the
source-linear routine/message/voice checkpoints, then stops at the complete
`EVENTB03.MES` script-handoff record. It does not execute those effects or
qualify the preceding station candidate cascade, native address-row selector,
natural event eligibility, or another Event Player preset:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_eventb03_candidate_plan.gd -- `
  <ELFIMAGE-directory>
```

The validator checks exact original identities and boundaries, true and
single-field-false inputs, deterministic/JSON validation, a separate upstream
expression witness, and all six source archives before and after. See
[B03 Station Candidate Route](../docs/spec/mes/eventb03_candidate_entry.md).

Core 0.280.0 adds the source-only station candidate priority plan. It requires
every numeric cell read by the 15 exact `01M.MES` guards, evaluates them in
source order, and stops before the first matching body. Only an all-false
result reaches the existing B03 local guard at `0x7691`; the plan executes no
candidate body, shared routine, native effect, dialogue, or handoff:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_station_candidate_priority_plan.gd -- `
  <ELFIMAGE-directory>
```

The validator also retains the conditional coordinate-zero prefix evidence
without promoting MACHI-to-01M host activation, address-row selection, or
natural scheduler eligibility. The synthetic test and original-source audit
join the normal headless batch. See
[Station Candidate Priority](../docs/spec/mes/station_candidate_priority.md).

Core 0.281.0 adds the static station candidate-prefix plan. It decodes the
exact `01M.MES:0x0008..0x026D` interval into 103 sanitized typed records,
retains the finite caller-local loop and surface-branch join, and orders every
external/native checkpoint without executing any of them or computing a
post-prefix state:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_station_candidate_prefix_plan.gd -- `
  <ELFIMAGE-directory>
```

The source validator also binds the adjacent MACHI event-16 handoff and its
caller-local continuation, while leaving the target start coordinate, native
address-row selection and natural scheduler eligibility unresolved. The
synthetic test and original-source audit join the normal headless batch. See
[Station Candidate Prefix](../docs/spec/mes/station_candidate_prefix.md).

Core 0.282.0 adds the source-bound station-to-EVENTB03 frozen decision plan.
It projects one exact 79-cell snapshot into the existing priority and B03
candidate contracts, evaluates B03 only after all fifteen upstream guards are
false, and returns one of three non-executing boundary outcomes:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_station_eventb03_decision_plan.gd -- `
  <ELFIMAGE-directory>
```

The input is explicitly caller-supplied at the assumed cascade entry. The plan
does not execute the conditional prefix, candidate bodies or B03 handoff and
does not qualify host entry, native row selection, natural scheduler
eligibility or a new playback preset. The focused synthetic and original-
source checks join the normal headless batch. See
[Station-to-EVENTB03 Decision](../docs/spec/mes/station_eventb03_decision.md).

### `audit_mes_playback_op_profile.gd`

Read-only command-frequency profile that grounds the playback package schema in
measurement rather than guesswork:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_playback_op_profile.gd -- `
  <ELFIMAGE-directory> [out.json]
```

It counts decoded commands over all 1,016 MES/LIB entries and over the 131
EVENT-named entries separately, and reports which commands the event runner
dispatches, which occur without dispatch, and which are dispatched but never
occur. It assigns no playback semantics. Its counts are bounded by the strict
analysis path, which decodes almost none of a `.LIB` entry; use
`export_playback_package.gd` for library content. See
`kakyu-remake/docs/spec/tech/playback_package_schema.md`.

### `export_playback_package.gd`

Command line front end for `playback_package_export.gd`, which builds the
playback package - the artifact the remake will consume after the modding tools
move to their own repository. Without `--event` it exports every catalog event
into one package, so shared members such as `LIBLARY.LIB` are stored once:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/export_playback_package.gd -- `
  <ELFIMAGE-directory> [--out <directory>] [--event <event_id> ...] [--no-analysis-groups] [--include-unbound-groups]
```

Membership and fingerprints come from `config/event_catalog/original_events_v1.json`
and, since Core 0.323.0, from every committed analysis-group profile under
`config/event_catalog/analysis_groups/` (their `source_members`, role
`analysis_group_member`, listed per entry as `bound_by`); every member is
verified against the archive. `--no-analysis-groups` narrows a full export
back to the catalog members, as `--event` does, and the manifest's
`membership.rule` records which rule produced it. `--include-unbound-groups`
(checkpoint C, 2026-09-25) is a scratch, explicitly opt-in bootstrap: every
tracked analysis-group's own members, whether or not any catalog row
references the group yet, for producing a brand-new ordinary site's own v6
document before its catalog row exists (the row needs the document, the
document's own projector needs the callee's package member, membership
normally needs the row - `config/event_definitions/v6/README.md`, "2026-09-25
(EP-12 PROMIS checkpoint C)"). No existing caller passes it; a plain export
is unaffected (`tests/test_playback_package.gd`, unchanged). Records drop the provenance commands and
the analyzer per-node fields, and the projection is fail-closed: an operand type
or field matching no explicit rule aborts the export. Without `--out` the
package is built, validated and measured but never written, because a written
package contains original dialogue and must stay outside version control. See
`kakyu-remake/docs/spec/tech/playback_package_schema.md`.

The current producer emits v5 with the complete manifest and exact event/text
file inventory bound into its hash, plus exact boundaries for dropped source
markers so opaque interiors cannot be skipped by an arbitrary offset.
Older packages must be re-exported; consumers supporting only v3/v4 reject v5.
This repository's reader checks the
new integrity contract and commits a replacement package only after all
validation succeeds. The producer revision is recorded in
`docs/spec/tech/content_tools.md`; the separately maintained remake was not
changed by this integrity repair.

`--out` must name a new directory. Publication stages and reopens the complete
package before its final rename, under the shared publication lock. Re-export
to a new versioned directory; replacement attempts are refused and failed
writes preserve existing packages.

### `export_provenance_report.gd`

Command line front end for `tools/content_suite/provenance_report.gd`
(`KakyuProvenanceReport`, Core 0.332.0), which builds one portable,
path-free, fingerprinted `kakyu_content_provenance_report/v1` JSON document
stating a content workspace's lineage, its replacements/projections, and its
declared compatibility, re-verifying every claim against the workspace files
before writing it:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/export_provenance_report.gd -- `
  <ELFIMAGE-directory> <workspace-directory> <output.json>
```

It prints one JSON line
(`{ok, path, sha256, replacements, projections, declared}` or
`{ok: false, error}`) and exits 1 on failure. `write` refuses an existing
output; `KakyuProvenanceReport.read_path` reopens and validates a published
report's shape and fingerprint without re-verifying the workspace files. The
Content Suite Launcher exposes the same builder as "Export report..." next
to "Open..." in the workspace row. See
`docs/spec/data/content_workspace.md` and
`docs/spec/data/materialized_arc_provenance.md` for the contracts this
report mirrors.

### `validate_playback_package_playback.gd`

Plays a playback package and compares it to the authoritative bytecode:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_playback_package_playback.gd -- `
  <ELFIMAGE-directory>
```

It builds the package under `user://`, loads it through
`content_core/playback_package.gd`, and runs every catalog event twice through
the same runners: once from the archive, once from the package alone with no
archive access. Segments, trace rows, message payloads, final state and the
terminal or stop reason must match, ignoring the provenance commands the package
deliberately drops. The route driver takes its preset, choice and terminals from
the catalog data the package carries. The package is removed again, and no
message text is printed. See
`kakyu-remake/docs/spec/tech/playback_package_schema.md`.

### `validators/validate_event_analysis_group.gd`

Re-runs one committed analysis-group profile against the archive: the Python
exact source audit first, then every route's guard witnesses, caller prefix,
callee run, continuation or replacement and reentry, as the batch's
`original event analysis <group>` checks do:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_analysis_group.gd -- `
  <ELFIMAGE-directory> [config/event_catalog/analysis_groups/<profile>.json] [--replay <out.json>]
```

`--replay` (Core 0.323.0, WD-22) writes what those runs emitted, for the
event-definition producer, without running any route a second time: one
record per variant of every route with the caller prefix's and the callee's
message rows (`entry`, `offset`, `end`, `raw_sha256` of the CP932 bytes),
the callee terminal, the final values of the cells the route and the variant
declare, and for a continuation the resume's rows and terminal and the
reentry's message count. No dialogue text leaves the script; the rows are
offsets and hashes that the playback package resolves. Without the flag the
validator's output is unchanged.

Since WD-21 U2 C2 (2026-10-08) `--replay` writes
`kakyu_event_analysis_group_replay/v3`: v2 plus, per run, `executed` (the
sorted offsets of every row the run's probe result executed, `{<package
member>: [at, ...]}`) and `resource_rows` (the media effects - the MMO, AX and
voice markers, `effect_request`, `bgm_request` - that the run's own entries
requested, `{entry, at, effect, name}`). A site variant carries them as
`prefix_executed`/`prefix_resource_rows` (beside `prefix_messages`),
`executed`/`resource_rows` at its top level (the callee run, beside `messages`)
and inside `resume`, `reentry` and every `visits` entry; a v14 flow carries
them in each hop. `tools/content_suite/replay_run_media.gd` is the one place
that derives them. A registered definition invoked from inside a library
routine reached the probe's rows labelled `LIBLARY.LIB:<n>` with a
`DEF_MAIN.MES`-relative offset until Core 0.377.0 (TD-55); since then the probe
keys those rows `DEF_MAIN.MES:<id>` itself. The shared helper accepts both
labellings: it keys the rows from a `definition_invoke_boundary` row to its
`script_return` as `DEF_MAIN.MES` and refuses the replay (a validator failure)
when that run is not terminated.
The `REPLAY_WRITTEN` line ends with `runs`, `definition_runs`,
`definition_invokes` and `definition_rows` counters. See
`analysis/_docs/wd21_u2_spec.md` D2 (the contract text lands with that unit's
documents).

### `regenerate_group_replays.py`

Regenerates every analysis-group replay, one validator process per profile
(the command above with `--replay`), `--jobs` at a time; the ELFIMAGE directory
and the Godot executable are arguments only:

```powershell
py tools\regenerate_group_replays.py "<ELFIMAGE directory>" `
  --profiles-dir config\event_catalog\analysis_groups --out analysis\replays_v3 `
  --jobs 4 [--godot "<Godot 4.7 console executable>"] [--only <profile stem> ...] [--timeout SECONDS]
```

It writes `<stem>.json`, `_run_log.txt` (one line per profile in completion order,
tab-separated `<stem>`, `exit=<code>` and `<seconds>s`, the format of the v2
directory's log) and `_logs/<stem>.log` under `--out`, prints one JSON summary line
and exits 1 when a profile exits non-zero, times out, or leaves no parseable v3
replay of its own profile. A stale replay is deleted before its profile runs. A
whole run is long (about 25 minutes at `--jobs 4`): launch it with
`tools\content_suite\launch_detached.py`. `--out` inside the original game
directory is refused.

### `build_event_flow_profile.py`

Builds a `kakyu_event_analysis_group/v14` flow profile from one or more
hand-authored hop specs plus the original archive; every record shape (`end`,
`op`, hash, source binding) is read from the bytecode, and each hop's own
`entered_by` is derived from the hop before it, never hand-supplied:

```powershell
py tools/build_event_flow_profile.py --arc "<mes.arc>" `
  --spec analysis/foo_town_spec.json analysis/foo_date5_spec.json `
  --out config/event_catalog/analysis_groups/foo_v14.json
```

`--spec` accepts more than one file (EP-12 part 2, 2026-09-24): each is its
own route, built from its own fresh measurement, merged into one profile -
`source_members` becomes the union across specs (each entry's document built
once) and every merged spec must declare the same `group_id` and a distinct
`route_id`. A single `--spec` still produces the same single-route profile as
before. A hop's own `poll_supplies` (also additive, same date) passes through
unchanged into the built hop; see `docs/spec/tech/content_tools.md`'s v14
entry for its shape and what the audit binds it to.

A spec's own top-level `state_context` (EP-12 part 3, 2026-09-24, additive)
is the same object v8/v6 routes carry, applied by the runtime flow validator
before `baseline`; a spec that omits it defaults to `{"kind": "fresh"}`.
`{"kind": "original_calendar"}` alone is enough - `entry` defaults to
`START.MES` and `table_sha256` to the audited `CALENDAR_TABLE` fingerprint
`build_event_route_profile.py` already computes for the same archive
(imported here, not recomputed); a spec may still override either.
`config/event_catalog/analysis_groups/01m_a_date_v14.json` (EP-12 part 3) is
the first real profile built this way - the calendar projection its
`DENSHA.MES` hop needs past its own definition-12 branch (see
`docs/spec/mes/a_date_flow.md`).

### `draft_date_flow_specs.py`, `content_suite/cli/measure_date_flow.gd`

EP-12 B date template unit (2026-09-25): the measuring-tool pair for a
heroine's promise-date flow (`docs/spec/mes/a_date_flow.md`'s family),
reusable letter to letter. `draft_date_flow_specs.py` is pure static
discovery (no execution): given `--letter` it finds the heroine's own date
guard in `01M.MES` (the conjunct on `banked_u16[<promise_field>]`, promise
field/location field cited from `validate_event_player_promise_dates.gd`'s
`CASES`), the ten shared-prefix dispatch coordinates that follow it, and
`?_DATE3.MES`'s own two routine-40 sites, case chains, affection ladders,
money gate, definition-17/11 invocations and the `?_HOTEL*.MES` chain -
stopping with a named error when a search does not find exactly the one
candidate it expects, rather than guessing:

```powershell
py tools/draft_date_flow_specs.py --arc "<mes.arc>" --letter B `
  --out analysis/_undoc/ep12_b_flow_recipe.json
```

`measure_date_flow.gd` reads that recipe, supplies the seeds/choices/`poll_supplies`
each gate needs, runs every hop through the shared call frame
(`content_core/mes_route_probe.gd`, one fresh top-level `probe.run_route`
call per hop), and writes the three `build_event_flow_profile.py` spec files
plus a measurement report - the exact-record `choice_contracts` (built the
same way `measure_event_route.gd`'s own `_contract()` does, including
DENSHA/TRAIN's real `kakyu_mes_map_location_contract/v1` binding) and the
seeded `baseline` writes are part of what it emits, not left to a human to
fill in:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/measure_date_flow.gd -- `
  "<ELFIMAGE-directory>" analysis/_undoc/ep12_b_flow_recipe.json `
  analysis/_undoc/ep12b_specs analysis/_undoc/ep12_b_flow_measure_report.json
```

`draft_date_flow_specs.py`'s own `HEROINE_TABLE` carries all twelve heroines
as of the EP-12 C..L date batch (2026-09-25): C..L's own rows needed no new
discovery function, since the guard/dispatch/gate searches were already
letter-parameterized. That batch did extend three of the searches to cover
shapes A/B never showed: `_town_terminal` follows a case-1 jump whose target
falls a few bytes short of the `script_return` record itself (D/E/F/K);
`_second_question`'s own money-threshold field is `null` when a heroine's
hotel case body carries no `state_u16[12]` check at all (E/G/I/J/L), and
`measure_date_flow.gd` skips seeding it when so; `_hotel_chain` finds the
`?_HOTEL.MES` site-selector routine-40 by its own position inside the
`global_u8[3004]` gate's true branch rather than by requiring exactly two
routine-40 sites in the whole file (E/I's own file carries a third, unrelated
one). The same batch also added a generic "no route policy" retry to
`measure_date_flow.gd`: when a poll-supplied route walk stops on an
unresolved choice instead of its terminal, it parses the boundary out of
the route probe's own `"no catalog choice at 0x.."` message and answers
value 1 once, rather than needing every such site named in advance (E/I's
own `?_HOTEL2.MES` ending, L's own `?_DATE5.MES` ending). See
`docs/spec/mes/heroine_date_flows.md` for the per-heroine numbers.

EP-12 leftovers unit (2026-09-26, Core 0.368.0): D's own hotel route and
L's own date5 route, left out above because the shared single-resume-point
contract-rebuild technique diverged before reaching their own boundary, are
now measured and declared - `content_core/mes_route_probe.gd`'s own
`_select_choice` carries the live boundary forward instead of discarding it
on an unanswered choice, and both `_build_contract` (here) and
`measure_event_route.gd`'s own `_contract()` build the contract directly
from it (see `docs/spec/tech/content_tools.md`'s own Core 0.368.0 entry).
`_build_contract` also gained a `poll_supplies` parameter (threaded the same
way `map_locations` already threads DENSHA.MES's train poll), needed for
L's own `?_DATE5.MES` open-choice contract specifically - a second,
independent gap this unit found, not the same one the stop-detail fix
closed. J's own hotel route is still not declared, for an unrelated,
structural reason (a positional re-entry into a mid-file address-table
label on a later invocation, not a route-toolchain limitation) -
see `docs/spec/mes/heroine_date_flows.md`'s own J entry. That measurement, and
the `A_PROMIS.MES` picker's position-1 re-ask
(`docs/spec/mes/promise_groups.md`), are kept re-runnable as the archive-tier
check "original EP-12 re-entry probes"
(`content_suite/validators/validate_ep12_reentry_probes.gd`, registered in
`config/validation/checks_v1.json`); neither is declared as a route.

### `draft_menu_flow_specs.py`, `content_suite/cli/measure_menu_flow.gd`

EP-12 gallery (2026-10-04): the measuring-tool pair for an album menu's
`SCENE_*` flows (`docs/spec/mes/gallery_families.md`), reusable menu to menu.
`draft_menu_flow_specs.py` is static (no execution): given `--letter` it finds,
for every nested `CALL SCENE_*` of `<NAME>_M.MES`, the page test, slot test,
unlock test and dispatch record, each scene's routine-40 sites and a recap
scene's state cells, and stops with a named `menu shape mismatch` error when
the menu is not the template. `measure_menu_flow.gd` seeds the menu selection
(a tool decision: the menu's native selection record cannot run), runs the two
hops of each route through the shared call frame and writes one
`build_event_flow_profile.py` spec per scene plus a report. Since the EP-12
all-menus unit (2026-10-04) the measurer **declares** what a scene can
otherwise do as route variants - every other answered combination of the
scene's questions that ends at the route's own return (`option-2`,
`option-2-1`) and a recap scene's second path (`hotel-path`) - and names in
the route's `unresolved` list any path that cannot be one (the stop rule);
the drafter lists the helper entries a scene nests (`nested_members`, the
`*_PIC.MES` scripts). The rules live in
`content_suite/menu_flow_variants.gd`.

```powershell
py tools/draft_menu_flow_specs.py --arc "<mes.arc>" --letter J `
  --out analysis/_undoc/ep12_j_menu_recipe.json
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/measure_menu_flow.gd -- `
  "<ELFIMAGE-directory>" analysis/_undoc/ep12_j_menu_recipe.json `
  analysis/_undoc/ep12j_menu_specs analysis/_undoc/ep12_j_menu_report.json
py tools/build_event_flow_profile.py --arc "<mes.arc>" `
  --spec analysis/_undoc/ep12j_menu_specs/*_spec.json `
  --out config/event_catalog/analysis_groups/minatu_m_scene_v14.json
```

The profile file stem is the recipe's `profile_stem` (`<menu stem>_scene_v14`).
`build_event_names.py` accepts the `SCENE_*` callees of an album menu;
`promote_analysis_groups.py` gives the rows `gallery` in `display.categories`,
the callee-return and menu-loop terminals and the `duplicate_route` rule (its
`--duplicates` census), all documented in `docs/spec/tech/content_tools.md`
("EP-12 gallery SCENE tools").

### `draft_recollection_flow_specs.py`, `content_suite/cli/measure_recollection_flow.gd`

EP-12 H (2026-10-04): the measuring-tool pair for the 13 `?_H.MES` recollection
ladders the protagonist's room calls (`docs/spec/mes/43c_caller_group.md`).
`draft_recollection_flow_specs.py` is static: it finds the room's 13 id tests and
calls, the clock save a route starts at, the answer-3 chain and the return chain,
and each ladder's gates by the structural rule documented in its header (and in
`docs/spec/tech/content_tools.md`, "EP-12 H tools"), with every other branch cell
reported under its reason; it stops with a named `recollection shape mismatch`
error when the room or a ladder is not that shape. `measure_recollection_flow.gd`
seeds the room's selection (a tool decision), runs the two hops of each route and
writes one `build_event_flow_profile.py` spec per ladder - the default variant the
full recollection (every gate cell 1), `no-recollection` every gate cell 0 - with
hop 2's `segment_budget` 1024 (a ladder plays up to 911 messages, one segment each).

```powershell
py tools/draft_recollection_flow_specs.py --arc "<mes.arc>" `
  --out analysis/_undoc/ep12_h_recipe.json
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/measure_recollection_flow.gd -- `
  "<ELFIMAGE-directory>" analysis/_undoc/ep12_h_recipe.json `
  analysis/_undoc/ep12h_specs analysis/_undoc/ep12_h_report.json
py tools/build_event_flow_profile.py --arc "<mes.arc>" `
  --spec analysis/_undoc/ep12h_specs/a_h_spec.json `
  --out config/event_catalog/analysis_groups/43c_miko_h_v14.json
```

One profile per ladder, the file stem the recipe's `profile_stem`
(`43c_<name>_h_v14`).

### `draft_talk_flow_specs.py`, `content_suite/cli/measure_talk_flow.gd`

EP-12 TALK (2026-10-04): the measuring-tool pair for the heroines' `?_TALK*.MES`
conversation scripts at their confirmed callers (`docs/spec/mes/talk_family.md`).
`draft_talk_flow_specs.py` is static: for each heroine letter it finds the
`01M.MES` ladder block (the block guard - the route's origin, the picture and intro
calls, the gate, the eight rung tests and calls, the PROMIS and outro calls), each
rung script's return records and follow-on calls with their enclosing conditions, and
for a band-less script (a heroine's plain `<letter>_TALK.MES`, Tina's `M_TALK`, the characters' `N_TALK`..`Q_TALK1`) its anchor caller (`PLAIN_ANCHORS`), and
seeds the natural state at the anchor (tool decisions, labelled in each route's
`unresolved`); it stops with a named `talk shape mismatch` error when a block is not
that template. `measure_talk_flow.gd` runs the hops of each route (a rung: the caller
to the call, the script to its return, the caller resuming to the town handoff; the
plain script: the first two) answering option 1 at every question, walks every other
answered combination and declares the paths that end at the route's own outcomes as
variants (`option-<values>`, `flag-<cell>` for a follow-on behind a flag), and writes
one `build_event_flow_profile.py` spec per route.

```powershell
py tools/draft_talk_flow_specs.py --arc "<mes.arc>" --letters K `
  --out analysis/_undoc/ep12_talk_k/recipe.json
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/measure_talk_flow.gd -- `
  "<ELFIMAGE-directory>" analysis/_undoc/ep12_talk_k/recipe.json `
  analysis/_undoc/ep12_talk_k/specs analysis/_undoc/ep12_talk_k/report.json
py tools/build_event_flow_profile.py --arc "<mes.arc>" `
  --spec analysis/_undoc/ep12_talk_k/specs/k_talk_30_spec.json `
         analysis/_undoc/ep12_talk_k/specs/k_talk_40_spec.json ... `
  --out config/event_catalog/analysis_groups/01m_k_talk_v14.json
```

One group per heroine's ladder (the eight rung specs merged, `01m_<letter>_talk_v14`),
one small group per caller and letter for the band-less scripts (`27c_ev_k_talk_v14`,
`01m_m_talk_v14`, `11m_n_talk_v14`). `--letters` takes the heroines `A`..`L`, Tina `M` and the
characters `N`..`Q` (`--letters A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q` drafts all 114 routes); the recipe's
`resume_hop` is `false` for the twelve anchors measured to stop in the `27C_EV.MES` day loop
(`DAY_LOOP_ANCHORS`) and `"auto"` otherwise (the measurer runs hop 3 once and keeps it when the caller
reaches a handoff: `N_TALK1`'s, the `27C_EV.MES` entry's last block, ends at `FLOOR5.MES`). Since 2026-10-05 (Core 0.372.0) the pair
reads all twelve ladders (the further gate conjuncts of C and J, J's `J_MINORU` call, C's intro cap on the
date), numbered follow-ons (`A_TALK51`) and the band-less anchors; `docs/spec/tech/content_tools.md`,
"EP-12 TALK tools, the other heroines".

### `build_event_names.py`, `project_event_definition.py`, `project_event_definitions_batch.py`, `validate_event_definition.py`

The `kakyu_event_definition/v3` producer side (WD-22; contract in
`docs/spec/data/event_definition_projection.md`). `build_event_names.py`
generates the event name registry `config/contracts/event_names_v1/` from
the profiles and the catalog (the owner edits titles in place; ids are
stable). A `kakyu_event_analysis_group/v14` flow profile's route is one
registry site of its own (its `hops[0]`'s own outcome, keyed additionally by
route id since a flow's own routes share that first dispatch); its `number`
is `date-<route id tail>` rather than a callee-stem suffix (EP-12 catalog
part, 2026-09-24 - see `config/contracts/event_names_v1/README.md`).
`project_event_definition.py` projects one registry site into a
tracked document (text referenced, never embedded) and a local
`.resolved.json` beside it with the text and a readable `script` block:

```powershell
py tools/project_event_definition.py --event <catalog event_id> --catalog config/event_catalog/original_events_v1.json `
  --replay <replay json from replay_event_dialogue.gd> --names config/contracts/event_names_v1 `
  --package <playback package directory> --arc <mes.arc> --out <directory>
py tools/project_event_definition.py --site <registry id> --profiles-dir config/event_catalognalysis_groups `
  --replays-dir analysis
eplays --names config/contracts/event_names_v1 `
  --package <playback package directory> --arc <mes.arc> --out <directory>
```

`--site` takes the profiles that declare the site (the one with map-location
contracts, else the newest schema, supplies the trigger, guard, presets,
results and terminals; every declaring profile enters `evidence.groups`),
the replay records the analysis-group validator wrote with `--replay`, and
the package the text references resolve against; results are the routes'
distinct replayed outcomes (message sequence and terminal), and everything
the mapping cannot state - a seed-dependent effect, an unidentified done
flag, the caller's post-event messages - is written into `unresolved`.
`project_event_definitions_batch.py` runs the producer for every registry
row (catalog rows through the catalog path, replaying them through Godot
when no replay exists; under `--contract v4`, since 2026-09-19, a row that a
declared analysis group covers goes through the profile path even when
it also carries a catalog alias), validates each document with
`validate_event_definition.py --package`, and writes `<out>/index.json`
(`kakyu_event_definition_index/v1`) with a verdict per site; it exits 1 when
any site fails. A failed projection is recorded as `projection_failed` with its
subprocess `exit_code` and the last lines of its `stdout_tail` and `stderr_tail`
(the producers print their refusals on stdout), in its index row and under its line
of the summary table (TD-56 C4c). `--only <id> ...` projects just those sites and
**merges** their rows into the `index.json` already in `--out` (rows replaced by id,
`summary` recomputed, fingerprints kept); an existing index bound to another
contract, names registry, package or cells fingerprint is refused before anything is
projected, and an id the registry does not hold is refused. `validate_event_definition.py <document> --names <registry
dir> [--package <dir>] [--fingerprint <recorded>]` prints one JSON verdict.
It also accepts a `kakyu_event_definition/v6` document (EP-12 / WD,
2026-09-25; contract in `docs/spec/data/event_definition_v6.md`, fixture set
`config/contracts/event_definition_v6/`) - v5 plus an optional top-level
`flow` block carrying a v14 analysis-group route's own hop chain for a date
site; a document without `flow` behaves exactly as a v5 document, `visits`
included. `--fingerprint` auto-resolves against the v6 directory the same
way it does for v4/v5.
It also accepts a `kakyu_event_definition/v7` document (WD-21 U2, 2026-10-08;
contract in `docs/spec/data/event_definition_v7.md`, fixture set
`config/contracts/event_definition_v7/`) - v6 plus the shape of
`presentation.resources`, items `{entry, source_offset, kind, name}` sorted by
that tuple with no duplicate. With `--package` every item must also be an entry
of the package and an occurrence of its `media_inventory` (a document with items
bound to a package without a known `kakyu_media_inventory` schema id is refused);
`--fingerprint` auto-resolves against the v7 directory. There is no `--contract`
option: the validator dispatches on `schema_version`.

`project_event_definition_v7.py` (WD-21 U2 C4, 2026-10-08; same `--site` command line as
`project_event_definition_v6.py`, whose parser it reuses, with `--replays-dir` defaulting to
`analysis/replays_v3`) wraps the v6 pipeline and fills `presentation.resources` from the
group replays' per-run `executed` offsets joined with the bound package's `media_inventory`:
the media a row's measured route reaches (`docs/spec/data/event_definition_v7.md`, "The
producer"). It fails closed on a replay that is not v3, a run without an `executed` set, an
`executed` offset that is not a record start, an empty joined name and a `resource_rows` row the
inventory does not confirm, and prints one `RESOURCES_STATUS` line per site. The `LIBLARY.LIB`
occurrences are joined, checked and listed like the others since TD-56 (the C4b re-projection, 2026-10-11);
`EXCLUDED_ENTRIES`, the seam through which the owner's ruling of 2026-10-08 left them out, is now
the empty set and stays as the one reviewed place an exclusion would be ruled again (the
`lib_excluded` field of the status line is therefore 0, and a library count is `items - route -
def`). `project_event_definitions_batch.py --contract
v7 --replays-dir analysis/replays_v3 ...` projects and validates the whole set (the arguments
are in `config/event_definitions/v7/README.md`) and ends with a `resources: documents=...
items=... route=... def=... lib_excluded=... kinds={...} largest=...` line beside the witness
line. The kinds vocabulary and the inventory schema id the validator, the register writer and
the projector read live once in `payload_values.py` (`MEDIA_KINDS`, `MEDIA_INVENTORY_SCHEMA`).

`rebind_event_definitions.py <defs-dir> --from-package <old package> --to-package <new package>
[--pair {catalog-revision,core-version}] [--dry-run]` (WD-21 U2 C6, decision D10) moves a tracked definition set (v6 or v7)
from the package it is bound to onto a re-export whose only change is the catalog revision (or, with
`--pair core-version`, the Core version), without the 70-minute
re-projection: it rewrites `package_binding.package_sha256` in every document and `package_sha256` in
`index.json` and nothing else, as a byte-level substitution that keeps the files' layout (LF, indent,
key order, non-ASCII text). It **refuses**, writing nothing, unless the two `manifest.json` are
canonically equal outside `package_sha256` and `source.catalog_revision` and differ in exactly those
two (the refusal names up to twelve differing paths), every document and the index are bound to the
old hash (a document bound to a third hash, or already to the new one, stops the whole rebind) and
the manifests' package schema, the set is one known contract (`kakyu_event_definition/v6` or `v7`,
`index.json` `kakyu_event_definition_index/v2` listing exactly the documents as valid, no `*.resolved.json`),
and each file mentions the old hash once and the new one not at all. Every result is parsed back in
memory (it must equal the original but for the hash) before the first file is replaced; the new
contents are written beside their targets first. It prints one JSON line with the counts, both hashes
and the two manifest fields that differ (`{"ok": false, "reason": ...}` and exit 1 on a refusal).
`--pair core-version` (TD-57 D5) takes the other pair, a re-export whose manifest differs in
`package_sha256` and `content_core_version` only: it is accepted when the manifests are canonically
equal outside those two fields, both carry a non-empty `content_core_version` string, the strings
differ and `source.catalog_revision` is equal. A catalog-revision difference under the flag, and
a Core-only difference without it (the refusal then points at the flag), are refused, mixing both
is refused with one reason, and each refusal names the selected pair's fields; the summary reports
`content_core_version: [old, new]` in place of `catalog_revision`. **Use the Core pair only when
the Core change cannot move a run.** Manifest equality outside the two fields proves every other
package file identical (`files[]` carries each SHA-256) and the projectors never read
`content_core_version` (they read `media_inventory`, `entries`, `package_sha256`, `schema` and
`source.archive_sha256`), so the rebind writes what a re-projection would; a Core change that can
move a run needs a re-projection, not a rebind.
`tests/test_rebind_event_definitions.py` covers it (an equal pair, pairs differing elsewhere, a
document and an index bound to other hashes, mixed or unknown contracts, the byte layout, a failure
while writing, the Core pair accepted and refused, and a dry run of the tracked v7 set, once per
pair, against a revised copy of the manifest of the machine-local package it is bound to).

`project_event_definition_v4.py`, `_v5.py` and `_v6.py` (same `--site`/
`--event` command line as `project_event_definition.py`, plus
`--witnesses-dir`/`--shared-lines`) each wrap the one before for every field
their own contract does not change: v4 adds relative effects, dialogue
flow and `order_hint` over v3's own candidate/effect machinery; v5
monkeypatches v4's schema and adds `visits` for the two WD-23 sites only;
v6 (EP-12 / WD unit 2, 2026-09-25) monkeypatches v5's schema for every
non-flow site and adds its own `build_flow_document` for the three
`01m-a-date` sites, reading each hop straight from the v14 profile and its
own v2 flow replay (`validate_event_analysis_group.gd --replay`, now wired
for a `kakyu_event_analysis_group/v14` profile too, through the same
`_shared` per-message/per-terminal helpers the v6/v13 replay path already
used). `project_event_definitions_batch.py --contract v4|v5|v6` selects the
matching producer and contract-fingerprint directory; under `v6` a row
whose group names a v14 flow route always takes the site path (never the
v3/v4/v5 site-evidence resolver, which cannot resolve a route with no
`caller`/`callee` pair). `config/event_definitions/v6/README.md` records
the first `--contract v6` run's measured result.

`--resolved-out <dir>` (both tools) sends the resolved documents, which hold
original dialogue, to a local directory so that `--out` can be the tracked
`config/event_definitions/v3/`; the README there gives the reproduction
command.

**`--jobs N` (TD-41, 2026-10-03).** The batch projects and validates sites
one at a time by default; `--jobs N` runs up to N sites at once on a thread
pool (each site is a producer subprocess plus a Python validator subprocess).
Everything shared is prepared serially before the first site starts - the
witness preflight, the fingerprint and manifest reads, the shared-line index
and its write, the dispatch decisions, and any Godot catalog replay - and
`index.json`, the table and the summary are assembled in registry-row order,
so the output is byte-identical to a `--jobs 1` run (measured 2026-10-03: the
189-site v6 set in 692 s at `--jobs 4` against ~33 min serial, all 190 files
byte-identical to the committed set). Only one batch may run
at a time per `--shared-lines-out` (default `analysis/shared_lines_v4.json`):
that file is rewritten at the start of every v4/v5/v6 run.

**Witness corpus, fail closed (TD-37, 2026-10-03).** v4/v5 (frozen) read the
shift-witness and done-cell-probe corpus silently: an absent or stale file
meant no `shift_witness` rows and no `reentry_probe` done cells, with no
warning - which is how the v6 set lost them between `f9a2454` and TD-37.
The v6 producer and `--contract v6` batch refuse instead. The corpus is
untracked and reproducible: `py tools\plan_event_effect_witnesses.py
--replays analysis\replays_v2 --out analysis\witness_requests` (skips the
12 v14 flow replays and prints the count; one request file per other
profile, 161 in all), then per profile `validate_event_analysis_group.gd --
<ELFIMAGE> <profile> --witness analysis\witness_requests\<stem>.json
analysis\witnesses\<stem>.json` (every non-v14 profile schema). A site is
refused when any profile it matches (not only the preferred one) has no
request file, has requests but no witness file, or carries a
`payload_sha256` that is not the profile's; the batch also refuses before
the first site when `--witnesses-dir` or its sibling `witness_requests` is
absent. `--allow-missing-witnesses` (v6 producer and batch only) projects
absent evidence without it, prints a `WARNING` per site and a count - stale
evidence is refused either way. Each projected site prints one
`WITNESS_STATUS site=... stems=N requests=N results_used=N missing=N` line,
and the v6 batch ends with a `witnesses: sites_with_results=... requests=...
results_used=... shift_witness_rows=... reentry_probe_documents=...` line
computed from them and the index entries; the index schema gains no field.

### `validate_mod_event_definition.py`, `text_rules.py`

The `kakyu_mod_event_definition/v1` validator (contract in
`docs/spec/data/mod_event_definition.md`; fixture set
`config/contracts/mod_event_definition_v1/`): a document a mod writes
itself, a `new_event` at a registry place or an `override` of one tracked
v4 document bound by that document's LF-normalized SHA-256.

```powershell
py tools/validate_mod_event_definition.py <document.json> --names config/contracts/event_names_v1 `
  [--definitions-dir config/event_definitions/v4] [--fingerprint <recorded>] [--cells-fingerprint <recorded>]
```

One JSON verdict line, exit 0 or 1, the v4 validator's convention; without
the fingerprint options the tracked values are read. `text_rules.py` holds
the authored-text rules of `docs/spec/data/text_encoding.md` that both
validators call (`check_text`, with the line-break and `{name}` placeholder
switches only the mod contract enables).

### `validate_workspace_definitions.py`

```powershell
py tools/validate_workspace_definitions.py <workspace root> [--names config/contracts/event_names_v1] `
  [--definitions-dir config/event_definitions/v4]
```

Rechecks a workspace's `definitions` records (`docs/spec/data/content_workspace.md`,
"Mod Definitions") from Python: every record's file hash and header
against its document, then the full `kakyu_mod_event_definition/v1`
contract on each document. One JSON summary with a failure list, exit 0
or 1.

### `mod_definition_set.py`, `content_suite/cli/import_mod_definition_set.gd`

The `kakyu_mod_definition_set/v1` transport
(`docs/spec/data/mod_definition_set.md`): one JSON file carrying a mod's
definitions between workspaces, beside its deltas.

```powershell
py tools/mod_definition_set.py build <workspace root> <out.json> [--names <dir>] [--definitions-dir <dir>]
py tools/mod_definition_set.py validate <set.json> [--names <dir>] [--definitions-dir <dir>] [--extract <dir>]
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/import_mod_definition_set.gd -- SOURCE_ROOT WORKSPACE SET_JSON [--replace]
```

`build` refuses unless every definition of the workspace passes the
workspace check; `validate --extract` writes each document's canonical
bytes for an importer; the Godot CLI stages a validated set into an open
workspace under its locks, adding new definitions, skipping unchanged
ones and replacing changed ones only with `--replace`.

### `mod_bundle.py`, `content_suite/cli/import_mod_bundle.gd`

The `kakyu_mod_bundle/v1` portable mod artifact (WD-10,
`docs/spec/data/mod_bundle.md`): one canonical JSON file carrying every
authored delta of a workspace, the UTF-8 translations of entries with no
structural edit (`text_projections`) and its definition set.

```powershell
py tools/mod_bundle.py build <mes.arc> <workspace root> <out.json> [--mod-id ID --mod-revision N] [--names <dir>] [--definitions-dir <dir>]
py tools/mod_bundle.py validate <bundle.json> [--arc <mes.arc>] [--names <dir>] [--definitions-dir <dir>] [--extract <dir>]
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/import_mod_bundle.gd -- SOURCE_ROOT TEMPLATE_WORKSPACE BUNDLE_JSON NEW_WORKSPACE
```

`build` carries the whole workspace or nothing: each `mes.arc` replacement
needs a linked authoring bundle and becomes a delta (its projection's edits
the delta's text edits), every other `mes.arc` projection becomes a text row,
the definitions become the set; a raw replacement, a record outside
`mes.arc`, an empty workspace or a projection on a relocated message is
refused naming the record. Without definitions `--mod-id` is required
(`--mod-revision` defaults to 1); the output must lie outside the workspace,
the original archive directory and the tracked definitions directory.
`validate` checks the structure and every member (the size first, before any
parse), with `--arc` the source rules against the matching original, and with
`--extract` writes each delta's and the set's canonical bytes. Both print one
JSON line and exit 0 or 1.

The Godot CLI is the bundle front door of the staged-import engine
(`content_suite/authored_delta_import.gd`, shared with
`import_authored_mod_delta.gd`): it validates the bundle against the original
`mes.arc`, reconstructs every delta, stages the translation-only entries and the
definition set into one new workspace built from the template workspace's
project, reopens it and checks every effective identity, then publishes it under
the lock-and-rename rule. It refuses an existing destination, a template on
another archive and an oversize file, and prints one JSON line (exit 0 or 1)
whose `mod_persisted` is true only for a bundle that carries a definition set:
a deltas-only bundle's declared mod is verified but not persisted.

### `promote_analysis_groups.py`

Regenerates the whole Event Catalog from the live event definitions and the
analysis-group profiles (EP-10 unit 1; every row since unit 5, 2026-09-21): each
ordinary document becomes a row with the group's presets, its choices bound to
the results' terminals and its `playback_status` - `minimal_playback` when the
default option's route ends in a map return, a place menu or a chain,
`analysis_only` when it ends in a dependency stop or an undeclared
continuation. `--check` exits 0 only when the tracked catalog equals a fresh
regeneration byte for byte; `--out` writes elsewhere. A `kakyu_event_analysis_group/v14`
flow profile has no v4/v5/v6 document of the ordinary shape, so its own routes
are promoted directly (`build_flow_row`, `--registry` names the event name
registry it reads a flow row's own title from, default
`config/contracts/event_names_v1/event_names.json`; EP-12 catalog part,
2026-09-24). `--definitions-dir` (alias `--v4-dir`) defaults to
`config/event_definitions/v7`, the live set (WD-21 U2 C5, 2026-10-08), and refuses a directory that
is not v7, because a v6 set would silently promote empty `resources` lists: each row's `resources` is its
document's measured `presentation.resources`, mapped to the catalog's resource item (catalog revision 41,
`docs/spec/tech/event_player.md`). *History:* until then the default was `config/event_definitions/v6`,
the live set, not the frozen v4 (checkpoint C, 2026-09-25): v6 is a superset of v4's shape and this
tool reads only v4-shape fields (a v6 document's own `flow` block, present only on a flow route's
document, is read by `generate_flow_rows` instead and skipped here), so the 175 pre-checkpoint-C rows
promote byte-identical from either directory; pointing at v6 lets a v6-only site (no v4/v5 document of
its own) be promoted too. v7 is v6 plus `presentation.resources`, so the same holds for it.

```powershell
py tools\promote_analysis_groups.py --check
py tools\promote_analysis_groups.py
```

`tests/test_promote_analysis_groups.py` pins the reproduction, the row
counts and the terminal mapping.

### `event_outcome_vocabulary.py`

The game-outcome vocabulary of `docs/spec/data/event_outcome_vocabulary.md`:
`v4_result_outcome` / `v4_reentry_outcome` over a v4 event definition,
`catalog_route_outcome` / `catalog_terminal_outcome` over a catalog row's
terminals, `profile_route_outcome` / `profile_reentry_outcome` over an
analysis-group profile route, each returning
`{outcome, postlude, next_target, map, reason}` with `outcome` one of
`map_return`, `place_menu`, `chain`, `not_triggered`, `unresolved`, and
`phrase` for the English label. The CLI counts outcomes over the tracked
data:

```powershell
py tools\event_outcome_vocabulary.py --v4-dir config\event_definitions\v4 --profiles-dir config\event_catalog\analysis_groups --catalog config\event_catalog\original_events_v1.json [--json]
```

`tests/test_event_outcome_vocabulary.py` pins the rules and the census;
`content_core/event_outcome_vocabulary.gd` is the GDScript port the Event
Player uses.

### `replay_event_dialogue.gd`

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/replay_event_dialogue.gd -- <ELFIMAGE> config/event_catalog/original_events_v1.json <event_id> <out.json>
```

Replays a catalog row's presets and answers in the bounded route probe
(`content_core/mes_route_probe.gd`) and writes a
`kakyu_event_dialogue_replay/v2` file of offsets and hashes only - never
dialogue text - for the event-definition producers. Since 2026-09-19 it gives
the probe the startup definition registry (`DEF_MAIN.MES`) beside the
row's declared members, seeds the audited calendar projection of
`START.MES` (`KakyuMesCalendarState`, table hash checked) into every
run's sandbox so definition 12's calendar scan can end when the preset
supplies a date, loads a nested script the route asks for from the
archive on demand (at most eight per run, reported as `extra_members`),
and matches a row's declared `analysis_boundary` terminal against the
event's own last trace row, not a row inside a shared routine or a
definition. A stop it cannot match fails the replay with the stop and the
event's last offset.

### `audit_mes_event_corpus_inventory.gd`

Read-only archive-wide inventory of every literal script dispatch, used to
bound Event Player catalog completeness from the caller graph instead of a
filename scan:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_event_corpus_inventory.gd -- `
  <ELFIMAGE-directory> [out.json]
```

It walks all 1,016 MES/LIB entries, collects command-`0x0F` nested calls and
command-`0x0E` root handoffs, and fails closed on every expected count. It
reports dispatch targets and never-dispatched entries only; it does not
classify a callee as an event, system script, duplicate or unreachable route.
The optional JSON argument writes the full inventory. This joins the normal
headless batch when an ELFIMAGE directory is supplied. See
[Event Corpus Inventory](../docs/spec/mes/event_corpus_inventory.md).

Its counts are over the bytes the strict aligned decoder reads. For what lies
past that horizon, see `audit_mes_dispatch_naming.gd` below.

### `audit_mes_dispatch_naming.gd`

Read-only archive-wide audit of where an entry is *named*, used to bound any
unreachability claim before an entry is called an unreachable stored route:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_dispatch_naming.gd -- `
  <ELFIMAGE-directory> [out.json]
```

The strict decoder stops at the first opaque boundary in each address-table
region, so the inventory above cannot see 719,650 bytes across 1,180 preserved
tails. This audit byte-scans the exact `00 | <0x0F|0x0E> 01 <name> 00 00`
dispatch envelope with the name required to be a stored entry, first proving
the scanner reproduces all 10,474 decoded rows and finds nothing extra where
the decoder read, then reporting the 650 records in the tails. It also decodes
the two command-`0x0D` inline script execution sites in `START.MES`. 33
fail-closed checks, the last comparing the tracked report
`config/event_catalog/dispatch_naming_v1.json` against the run; the optional
JSON argument writes the full report. `classify_event_routes.py` consumes that
tracked report as intro evidence and re-decodes every record in it. This
joins the normal headless batch when an ELFIMAGE directory is supplied. See
[Dispatch Naming Reachability](../docs/spec/mes/dispatch_naming_reachability.md).

The B03 sound audit checks six routine-9 calls (including the first blackout
pair), original SE/WAV identities, the native stop/load/restart chain, and
source-derived poll thresholds. It runs in the normal validation batch when
`--elfimage` includes MES/SE/MMO and `--exe` is supplied. It does not play audio:

```powershell
py tools\audit_eventb03_sound.py --mes-arc "<ELFIMAGE-directory>\mes.arc" `
  --se-arc "<ELFIMAGE-directory>\se.arc" --mmo-arc "<ELFIMAGE-directory>\mmo.arc" `
  --executable "<user-owned-AI5WIN.original.exe>" `
  --godot-console "<Godot-console-executable>"
```

The shared B03 playback check above verifies WAV decoding, six separate
occurrences, 90/195-ms source-counter tool waits, unchanged BGM and source
archives. Actual audible output and native timing equivalence remain separate
manual observations.

Executable audit v56 retains the active-string copy, corrects
the direct buffer identity,
and resolves receiver slots
`+0x20`/`+0x58` across all three public-context vtables plus all known
flag-bit-8 readers/writers. The first receiver takes the string pointer's
bounded default path, the second is a selector notification, and the stream
loop clears the flag without writing the MES coordinate. No checked path runs
a script or restores a caller. It also binds the state buffer's `+0x3190`
owner backpointer and proves that its sole direct callback-helper caller belongs
to a serialized-state reload case. That case rebinds pointers and replays the
same bounded receiver/notification/flag path with the reloaded state pointer,
but does not write a MES coordinate, invoke a script runner, or restore a
caller. Audit v56 also binds five public slot-`+0x44` stack-context
caller shapes and proves that neither checked caller extent directly references
the active-string field. At that audit stage, a different higher-level host
consumer remained unresolved. V54 also partitions every literal active-buffer reference into
four lifecycle, nine diagnostic-context, two destination-buffer, and seven
control/flag uses across five native method vtables; none directly calls the
script runner. V73 resolves the two destination cases as the bounded
MES/Data ARC loaders at `0x0043DC50` and `0x0043DDA0`. Their nonzero
`MesType`/`DataType` paths dereference state slot `+0x2158` only as an ARC-read
scratch destination before AI5 LZ; the lookup helper receives a separate
caller filename argument. Neither path forwards the active-string bytes,
writes a MES coordinate, calls the script runner, or restores a caller. RTTI
maps those tables to adjusted `CAI5Doc`, `CCommon`,
`CFunc`, `CScript`, and `CScriptManager` subobjects. Their exact RTTI base
arrays show `CAI5Doc -> CScriptManager -> CFunc/CCommon`, with the latter
branches converging through virtual `CScript`/`CThread` bases. The unique
constructor path publishes one composed `CAI5Doc` through application member
`+0xE8` and constructs its nested script-family subobjects; this ownership
evidence still supplies no deferred target coordinate. When the
hash-bound original entries are selected, the GUI shows a
non-selectable
**Deferred: direct start** evidence row and a disabled **Start Event
(Deferred)** button. This does not disable the separate catalog Play action.

The same v64 audit also fixes routine 40's bounded keyboard loop and installed
modal-control vtable. It confirms Return and Numpad Enter as the shared confirm
callback, maps Escape directly to the mode-gated native result finalizer, and
binds up/down/left/right to four concrete wrappers. The parent dispatch and
installed mode-1 control prove that Up/Down move the selected row and recenter
the native cursor through the original `SetCursorPos` path; Left/Right remain
on the parent update/notification path. It also samples `GetCursorPos`, converts
to window coordinates, and classifies the pointer through the first matching
inclusive rectangle in the selected 10-byte hit table. Hit IDs `0x0100/0x0102` are now fixed as
`-1/+1` changes to a visible-window start clamped to `0..count-1`; they are
not choice-row selection. V59 additionally binds the complete tables to the
original EXE's custom `AREA` resources 142/143: their ID domains are exactly
`{0x0000,0x0001}` and `{0x0100,0x0101,0x0102,0x0103}`. The pointers belong to
the modal control/parent object, not `PARTS.MMO`; no external image metadata is
invented. V60 separates those modal IDs from the selected control's dynamic
choice-row table. In that table, a zero high byte marks a selectable row and
the low byte is its visible-row ordinal. Confirm combines it with the current
window start, rejects rows outside the total count, resolves the mode-0 host
row mapping, and adds one for the script-visible result. The modal `AREA` IDs
therefore are not choice rows. V61 follows `WM_LBUTTONDOWN` into the
application key object's left-button latch and proves that modal ID `0`
dispatches confirm, calls the selected control's `+4` confirm slot, copies its
one-based result, and stops the modal; `WM_LBUTTONUP` clears the latch. V62
separates modal ID `1`'s gated helper-return path from its ordinary
selected-control-confirm fallthrough. V64 additionally locks the complete
`0x0101` and `0x0103` callback branches. Both perform native control or
presentation-state work and return without directly copying the modal result
or stopping the modal; `0x0101` conditionally updates control bytes `+0x3DC`
and `+0x3E0`, while `0x0103` clears `+0x3DC` before its helper calls. Their
shared exact path prepares a document region, temporarily sets and restores a
document latch, clears then sets update flag `0x10`, forwards a stored document
rectangle, and tail-dispatches the current document embedded object's virtual
slot `+0x3C`. Their user-facing meanings remain unlabeled. V65 fixes an exact
three-row selected-control window: Up/Down scroll one row at visible ordinal
0/2 when more records exist, absolute ends remain clamped without wrap, and
the matching dynamic 10-byte row rectangle is used to center the native
cursor. V66 binds held directions as level-triggered once per completed modal
iteration, with no local first-repeat delay or fixed interval. The active
message pump uses `Sleep(0)` and the inactive path uses `Sleep(30)`, so the
wall-clock rate remains host-scheduler dependent. V67 binds modal ID `1` as a
nonterminal presentation-region toggle: it switches
document mode `+0x43D`, activates fixed rectangle `(34,316)-(578,376)` or
restores the saved rectangle, and refreshes the 640x400 surface without
copying a modal result or stopping the modal. Its visible label and the
`0x0101/0x0103` user-facing meanings, other
native callback effects, and Escape's caller-visible result remain unresolved;
the tool therefore keeps using the source-bound remake bridge or detached
preview instead of executing that native modal UI.
Validate that diagnostic without opening a window with:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventb03.gd -- `
  <ELFIMAGE-directory>
```

The focused validator hashes `mes.arc` fully and compares size plus first/last
64-KiB SHA-256 samples for the much larger media archives before and after the
run. The aggregate ARC corpora remain responsible for full-archive media
fingerprints and rebuild validation.

In the graphical Event Player, **Choose Overlay...**, **Hot Reload**, and
**Clear Overlay** first
build an isolated candidate resolver for the currently open standalone
`mes.arc` or ELFIMAGE content set. Every targeted ARC is checked against the
fingerprint captured with its open index before any binary replacement is
accepted, all targeted MES/LIB payloads are parsed, MES text projections are
checked against the pinned MES/entry hashes, and the selected entry is
preflighted before the candidate becomes active. A wrong-base record in any
opened media ARC or a malformed MES replacement rejects the whole candidate
and preserves the existing document, Results, continuation/choice, preview
audio/image state, and sandbox. If another tool is publishing the package,
retry Hot Reload after that atomic update completes. Source ARCs are never
written. Clear Overlay rechecks every open source fingerprint and the selected
original MES before swapping to an original-only resolver. A rejected clear
keeps the active overlay, Results, continuation, and preview intact; a successful
clear keeps the configured generated UTF-8 cache above original CP932.

The read-only EVENTD06/EVENTD14 fragment-catalog check can be run separately:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_event_catalogs.gd -- `
  <ELFIMAGE-directory>
```

It executes every nonzero address-table fragment to its first safe boundary in
a fresh sandbox, rejects decoder/address/write/unsupported failures, drives
fragment 1 of each catalog through the actual Event Player controller, and
rehashes `mes.arc`. It also drives all three hash-bound EVENTD14 choices to
their common `0x256D` return, validates both special-date caller BGM branches
and the explicit default, previews the current sandbox-date branch, and
continues through the exact caller suffix to the `MACHI.MES` marker. It locks
each route's boundary-type counts, sandbox-record count, decoded `D.MMO`
foreground, completion state, caller writes, and completion screen. Its report
contains only status/message counts, not the original dialogue.

The product-level Event Catalog seed has a separate payload-free validation:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  res://tests/test_event_catalog.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_event_catalog_original.gd -- `
  "<ELFIMAGE>"
```

The first command checks schema, classification, references, deep-copy access,
and fail-closed malformed cases. The second reopens the user's original content
set, verifies all twelve EVENTB/EVENTD caller/callee/library bindings plus any
cataloged cross-archive presentation dependencies, and confirms every opened
source ARC is unchanged. It does not extract or commit any original payload.

The focused EVENTD06 setup-extension check additionally locks the exact
`0x0B52..0x0B59` omission, `D07.MMO`, the independent following write and
surface record, the default `0x0C0E` terminal, and the isolated `0x0B88`
value-one branch probe to `0x0C1E`. It keeps **Start Event** disabled and
rehashes both source archives:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventd06.gd -- `
  <ELFIMAGE-directory>
```

In the graphical Event Player, filter for `eventd`, select `EVENTD06.MES` or
`EVENTD14.MES`, then select a numbered **Fragment** and click **Preview
Fragment** (or double-click the row). These nonzero rows remain independent
source-table previews because their native host selection/order is unresolved.

For `EVENTD14.MES`, click **Start Confirmed Event** in the top run bar, or
select **Catalog setup #0000** and click the same action in the source pane.
The configured-original executable audit and original ARC hashes bind this to
the `12C.MES` zero-coordinate caller and exact entry-zero bootstrap. Press
**Continue** at routine 28, **Continue (Omit Setup Records)** at the exact
command-`0x12` typed-record list, and **Continue** at the next routine. At the
registered DEF-21 boundary, choose **Continue (Run Setup DEF 21)**. Thereafter,
click the game frame or use Space/Enter/right arrow to advance fourteen
original dialogue boundaries. The frame then shows the original three-way
choice; use Up/Down plus Enter, number keys 1-3, or pointer input. Choice state
is written only to the sandbox and resumes at the audited `0x0947` coordinate.
Continue through the visible registered-DEF and shared-routine stops. At a
`D_PIC.MES` boundary use **Continue (Preview D_PIC)**; choice 2 also offers
**Continue (Omit Event Records)** for the exact six-record list. The three
routes retain 22, 20, and 10 post-choice dialogue boundaries and all finish at
the exact `EVENTD14.MES` script return `0x256D`. The game frame then shows
**Event complete** and the footer identifies confirmed `12C.MES` caller resume
`0x1C33`. Click **Preview Caller BGM** to execute the bounded caller prefix.
Dates `1224` and `1301` select the confirmed holiday tracks; other dates use
the confirmed `IDOU.WAV` default. Then click **Continue Caller Handoff** to
apply the two confirmed caller sandbox writes and stop at the exact
`MACHI.MES` marker. This is a sandbox-only bounded route: native placement,
the final handoff consumer, and any order for separate Fragment rows are not
executed.

For `EVENTD06.MES`, **Start Event** intentionally stays disabled. Select
**Catalog setup #0000**, click **Preview Setup**, then continue through routine
28 and the exact command-`0x12` record omission. The corrected MMO boundary
leaves the following `banked_u16[0][1]=7` command active, so the fresh all-zero
source-table analysis continues through the visible routine and dialogue
boundaries. At the registered DEF-26 stop, use **Continue with audited DEF
body**; presentation effects remain explicitly omitted. The setup-derived route
stops fail-closed at native presentation boundary `0x0B52` with 26 isolated
state records. At that exact stop, click **Continue (Omit Setup FX)** to skip
only its six-byte payload and NUL through `0x0B59`. That run displays one
additional message ending at `0x0B7F` and stops directly at routine 28
`0x0B83` (resume `0x0B88`). Click **Continue** there. The next bounded suffix
resolves and previews `D07.MMO`, preserves the independent following write,
and reports the surface operation outside the game frame without rendering
native pixels. In the fresh zero sandbox it next
stops at routine 21 `0x0C0E` (stored resume `0x0C13`). Routine 28 normally
initializes `global_u8[4000]` to zero. The focused validator separately probes
its stored caller resume `0x0B88` with value `1`; that isolated branch follows
the alternate surface record `0x0BE4..0x0C09` and stops at routine 28
`0x0C1E` (stored resume `0x0C23`).
Neither terminal offers another continuation in this bounded unit. This
exposes more original content but still does not prove native host activation
or fragment identity, so it is not labeled event complete.

For the complete bounded `EVENTD08.MES` inspection, filter for `eventd`, select
the entry, and click **Start Event Dialogue**. The tool verifies the original
`12C.MES:0x0FA6..0x0FB6` dispatch and begins at coordinate zero while retaining
the inherited `MAKI.WAV` request. Click the frame or use Space/Enter/right to
advance nine common dialogue boundaries containing 17 message fragments and
voice markers `D1028.OGG` through `D1032.OGG`. At `0x03BC`, click **Continue
(Omit Native Records)**; this omits only the two exact three-record lists
through `0x03D2`. It does not enable native-stream skipping. The route reaches
and previews `D08.MMO` from its original `0x045B..0x0467` envelope, then stops
at the three-way choice. Use Up/Down plus Enter, number keys 1-3, or the
pointer, and continue through the existing branch, shared-routine, caller BGM,
and caller handoff screens. The decoded image is a tool preview: native typed-
record effects, active-surface identity, placement/composition, cursor/display
effects, and the final host consumer remain unresolved.

The **Prev row**/**Next row** buttons below the Address list preview adjacent
source-table rows only. The **Bytes / first stop** column summarizes the first
isolated stop without caching dialogue text. A returned row is marked
**FRAGMENT END**, not event complete.

For an ordinary non-catalog MES entry, select any numbered address row and
click **Preview Row #xxxx**, or double-click the row. This runs that displayed
source-table coordinate in the isolated sandbox and retains the row identity
above the game frame. It is explicit tool input, not a claim about native host
selection or event order. **Prev row**/**Next row** immediately previews adjacent
ordinary rows in displayed source-table order and does not cross into another
row kind. **Content stops** provides **Prev hit**/**Next hit**, which skip empty
returns, state-only rows, and failure-only stops to find the nearest row containing
dialogue, DEF choices, or an exact native-FX boundary. This is still table
search, not original event order. Selecting or scanning a row lazily adds its
first isolated stop to the **Bytes / first stop** column using a fresh
disposable sandbox; this summary stores counts and status only, not dialogue
text, and does not change the active sandbox. The chosen hit then uses the
normal isolated preview behavior. Each click scans at most 16 rows; when no hit
is found in that batch, the selected cursor advances and the status asks you to
click the same button again. For the audited F_DATE2 nested-DEF sample, filter `f_dat`, select
`F_DATE2.MES`, and choose row `#0187`; its summary reads `3 DEF`. **Next row**
moves to `#0188`, and **Prev hit** returns to the DEF row `#0187`. Double-click
the row to reach the original detached choices without manually typing `0x6768`.

For the registered-body diagnostic, filter for `DEF_MAIN.MES` and click **Start
Isolated DEF Body**. At the exact `0x0208` typed-record boundary, **Continue
(Omit Body Records)** resumes at `0x0216` and audits the remaining bounded body through its
return. Entering `0x0203` manually in the Intro field does not open that
continuation; the dedicated action is required so a stale or arbitrary run
cannot inherit presentation-omission authority.
At routine 25, the Results panel also separates two facts: the original
`START.MES` runs `LIBLARY.LIB` and `DEF_MAIN.MES`, and the EXE keeps the
resulting DEF registry for the owning script-manager object's lifetime. Event
Player reconstructs that registry as a read-only, runtime-only projection only
when all four original archive/entry hashes match and no overlay replaces a
startup component. The existing EVENTD08 continuation may give the projection
to the library runner; routine 25 then requests DEF 26. Manual intros and other
routes do not inherit it, and no registered body runs while the projection is
built.

For the bounded EVENTB01 inspection, filter for `eventb01`,
select `EVENTB01.MES`, set **HHMM [19]** to `0600`, apply the quick state, and
click **Start Event Dialogue**. The Results trace follows the original
`13C.MES` caller's EXE-confirmed callee coordinate zero through routine 28,
the one explicit paired-record omission, and routines 21/28. The frame then
shows `B01X.MMO`, validates `MAHOKO.WAV` and B0796/B0797, and displays seven
original dialogue boundaries. Continue then crosses the exact routines and
three-record omission to callee return `0x06A0`. **Preview Caller BGM** runs
the original `13C.MES` date-selected prefix, and **Continue Caller Handoff**
stops at `MACHI.MES:0x1022` after the confirmed `global_u8[286] = 1` write.
`HHMM=1600` selects `B01Y.MMO`; the default night value
reports the original absence of `B01Z.MMO` without substituting a daytime
frame. The native MACHI consumer is not executed. The matching headless command is
`validate_event_player_eventb01.gd -- <ELFIMAGE-directory>`.

For EVENTB02, filter for `eventb02`, select `EVENTB02.MES`, set **HHMM [19]**
to `0600`, and click **Start Event Dialogue**. The frame follows the original
zero-coordinate caller through the same exact paired-record omission and
shared-routine stops, then retains `B02X.MMO` as background and reports
`B02XAN.MMO` plus `B02X.AX` as a three-frame keyed compositor layer before
`MAHOKO.WAV`,
B0798..B0800, and eight dialogues. The X frames are 104x112 at `(216,48)`;
`1600` selects three 128x112 Y frames at `(216,56)`. The tool follows the
original AX dispatch and counted-loop order on a labeled 60 Hz tool clock.
Each dispatch restores the background before copying one frame, so the three
stored source frames never appear as a vertical strip. The original host
cadence remains unresolved. `1600`
selects the Y family; the night branch reports the absent Z family without
substitution. The final confirmed suffix returns from EVENTB02 at `0x08C9`;
the UI then offers **Preview Caller BGM** for the original `13C.MES`
date-selected prefix. Sandbox date `1224` selects `X_MAS.WAV`, `1301` selects
`SHOGATU.WAV`, and other values select `IDOU.WAV`. **Continue Caller Handoff**
applies the confirmed `global_u8[286] = 1` write and stops at the exact
`MACHI.MES` marker without executing its native host consumer. Headless verification uses
`validate_event_player_eventb02.gd -- <ELFIMAGE-directory>`.

For the complete bounded EVENTB15 route, filter for `eventb15`, select
`EVENTB15.MES`, set **HHMM [19]** to `0600`, and click **Start Event
Dialogue**. The source-bound route starts from the original
`11M.MES:0x347B..0x348B` caller at callee coordinate zero, crosses exact
routine stops `0x00F6`, `0x02E0`, and `0x02F0`, and grants one bounded
omission for the paired command-`0x12` lists at `0x0115..0x012B`. The frame
then shows `B15X.MMO`, validates `MAHOKO.WAV`, and reaches first dialogue
`0x035D`. Continue through all nine dialogues, routines 28/32/25, the exact
three-list omission at `0x0721`, and routine 28 to callee return `0x0778`.
No voice marker is expected in this route. `1600` selects
`B15Y.MMO`; the night branch reports the original absence of `B15Z.MMO`
without substitution. **Continue Caller Handoff** resumes the exact original
`11M.MES` suffix, applies `banked_u16[0][242] = 11` and
`global_u8[286] = 1` only to the sandbox, and stops at
`MACHI.MES:0x34AE`; the native host consumer is not executed and no caller BGM
is invented. Headless verification uses
`validate_event_player_eventb15.gd -- <ELFIMAGE-directory>`.

For the bounded EVENTB14 choice inspection, filter for `eventb14`, select
`EVENTB14.MES`, and click **Start Event Dialogue**. The source-bound route
starts at coordinate zero from the original `44M.MES:0xC915..0xC925` caller,
reconstructs the immediately preceding caller presentation, plays through seven
original dialogue boundaries with B0829..B0832, and stops at the three original
DEF options at `0x04CF`. The frame selects original `44M_1/2/3.MMO` by sandbox
HHMM using the labeled `TIME_C` location-family projection, shows original
`B3.MMO` Mahoko art plus the composited `BAN.MMO`/`B.AX` 96x80 face animation
at `(264,72)`, and plays `MAHOKO.WAV`. Native location-surface composition
remains unresolved; the callee itself reaches no MMO/BGM request. **Play
catalog preset** applies the source-authentic original night gate: MMDD `1001`,
HHMM `1900`, weekday zero, its matching banked date, Mahoko
`banked_u16[0][210] = 81`, and the exact eligibility flags. Authoritative
B_PIC replay selects B3.MMO, reaches routine 22 at `0x04AF`, resumes at
`0x04B4`, and joins the high-affection face route. HHMM `0600` with `B.MMO`
is retained as a compatibility/debug preview only. Direct Analysis starts can set the separate
**Mahoko b0[210]** Sandbox field before **Apply slots**. Original B_PIC replay
maps values `0..30`, `31..70`, and `71+` to B.AX columns 1, 0, and 2. The options may be inspected as
detached read-only bodies. Press Up/Down or `1`-`3`, then Enter, to preview the
selected option's stored outcome dialogue route. Use **Continue Outcome
Preview** or the normal frame continuation input to advance through 6, 17, or 12
exact dialogues. This sets `state_u16[21]` only in a cloned sandbox and
reconstructs the clone for every step; it does not assert routine 40's native
result mapping. Once confirmed, that choice is locked and dialogue input cannot
switch to another option. Options 1 and 3 finish at confirmed callee returns without
resuming the original caller. For option 2, set a valid legacy MMDD in the
Sandbox Date field first. Its clone preserves the START-derived calendar
layout, returns through DEF17 and DEF11/DEF12 plus shared routines 3/26/32,
omits two exact native-record spans, and crosses routines 28/21/28. Before
those routines the stored ordinary-date path requests `IDOU.WAV`, increments
Mahoko affection by one, and performs a forced scripted move without reopening
the town map. The two following stored dialogues retain the 44M/B3 dormitory
frame and explicitly label map/destination/choice input as locked; normal
dialogue advance remains available. On the first park dialogue the frame
switches to original `B14.MMO` and overlays four 120x128 frames selected
from `B14AN.MMO` by `B14.AX` at `(400,8)`; the reached selector-44 request also
changes the preview from movement audio to `FURARE.WAV`. After eleven more dialogues, use
**Show Nested Choice** to display the exact three-row routine-40 boundary at
`0x133F`. Selecting one of these nested rows explicitly projects
`state_u16[21] = 1/2/3` in the cloned nested state and starts the corresponding
stored 8/6/13-dialogue branch at `0x1344`. Use **Continue Nested Outcome** to
advance it. The nested selection also stays locked through the subsequent
B_PIC return and post-event dialogue. This is not presented as the native routine-40 result mapping, and
**Finish Nested Outcome** crosses the exact cloned common suffix to the
`B_PIC.MES` dispatch `0x1FC0`. Use **Run B_PIC Return** to restore the effective
HHMM-selected `18M_1/2/3.MMO` children's-park location background, key the
B3/BAN/B.AX expression over it, and start the five stored post-event
dialogues. The B14 event CG and pre-move 44M dormitory-front frame must not
reappear here. The last two
messages follow routine 21 and switch to the effective MACHI HHMM map. The
19:00 catalog preset composes `MACHI.MPC` with the `MACHIN_3.DAT/.PAL` tile
atlas, then shows event/entrance preset 4 at camera cell `(80,32)` with original
CHARA frame 1 at actor cell `(95,40)` / viewport pixel `(240,128)`. Exact
original and edited effective inputs both stay on the shared ARC-backed MPC
compositor; extracted or local full-map PNG files are not presentation inputs.
The raw DAT/PAL atlas is not a screen image. The footer labels this as a
source-qualified projection because routine 21's exact native surface-1
producer remains unresolved. This is a presentation-only world-map monologue:
map/destination/movement input stays locked and only dialogue advance is
accepted. Then
**Finish EVENTB14** to reach the bounded `MACHI.MES` handoff at `0x230C`.
The handoff target is not executed, so the retained map frame does not become
an interactive movement map. Date `0000` is rejected instead of entering
the scan. The source-bound common caller frame remains active, but values 1 and
3 do not resume live `44M.MES`: its exact `0xC925` suffix reaches a second
caller-owned routine-40 boundary at `0xFFBA`. Its one-based numeric result is
EXE-confirmed, but the dynamic list, native UI/cadence, and effects remain
unresolved. To inspect another outcome, return to or restart from the
corresponding choice boundary; outcome dialogue never reopens the old list.
Caller continuation requires the common frame created by confirmed Start.
Directly probing a return or postlude offset in Analysis remains read-only
evidence and cannot reconstruct a discarded caller frame.
Headless verification uses
`validate_event_player_eventb14.gd -- <ELFIMAGE-directory>`.

For the complete bounded EVENTD01 inspection, select `EVENTD01.MES`, open the
**Sandbox** tab, set **HHMM [19]** to `0600`, click **Apply Quick State**, and
then click **Start Event Dialogue**. The route
begins at callee coordinate zero reached from the original caller: the Results trace first shows
the bootstrap, routine 28, and two explicit native-record omissions, then the
game frame shows the original `D01X.MMO` background and the decoded
`D01XAN.MMO` foreground tool preview before `MAKI.WAV` and the first dialogue.
The initial routine 28 normalizes `global_u8[4000]` to zero, so this replay
bypasses the stored mode-0 surface envelope at `0x023F..0x0264`; the validator
checks its exact source bytes without presenting it as an executed operation.
Native `D01X.AX` placement and composition are not reproduced, so the frame
labels the foreground as a tool preview. With fresh/default `HHMM=0000`, the
stored night branch instead reports missing original `D01Z` assets; this is an
expected source diagnostic, not an event failure, and the tool does not replace
it with daytime content. Starting the route again clears the prior frame,
foreground, AX metadata, BGM, and voice before the new session reaches its own
markers, so changing the sandbox time cannot leave a stale daytime preview.
The automated `HHMM=1600` route also locks the original `D01Y.MMO` 640x400
background, `D01YAN.MMO` 112x192 foreground, and `D01Y.AX` metadata.

Continue the dialogue, choose any of the three options, and advance to the
event completion screen. **Preview Caller BGM** follows the exact date-selected
`12C.MES` prefix without changing state. **Continue Caller Handoff** then
applies the two confirmed caller sandbox writes and stops at `MACHI.MES`.
All source ARCs remain read-only. An overlay may replace the displayed MMO/AX
resource through Content Core resolution, but does not weaken the original
base-entry fingerprint/coordinate checks or establish original-engine compatibility. No
action changes a gameplay save or executes the final host consumer.

For a routine-40 DEF list with an exact Content Core 0.176 one-based slot-21
consumer, Event Player shows **Routine 40 remake bridge**. Select with Up/Down,
Enter, number keys, or the pointer. Confirmation revalidates the current
bytecode, writes the explicit one-based choice to caller-visible
`state_u16[21]`, and resumes the original stored branch chain. A complete
result-by-global-gate matrix additionally shows and snapshots the current gate;
confirmation rejects a changed/unsupported gate and never writes it. EXE audit
v41 confirms that mode 1 materializes its selectable record list, converts the
zero-based selected row to a one-based value, and returns that value unchanged
through its modal loop; an empty list yields `0xFFFF`. The second one-based
result is copied to slot 13 by the routine script. The UI and Summary state
that native input bindings/cadence, presentation effects, routine-20, and
vector effects remain unresolved. Audit v42 additionally proves that the
third expression indexes a 16-byte native group whose 8-byte records are
copied into the active 4-byte choice vector with an exact count. In 43C's
second pass the key is the first one-based result in slot 21. Audit v43
identifies command `0x10` as the group-record producer and fixes each
materialized first dword as active context pointer plus code coordinate. Audit
v44 corrects the group selector: command `0x1B` uses the first parsed
expression's evaluated result after the parser-object `+4` adjustment, so the
authoritative literals select groups `0..6` instead of all selecting group
zero. The exact 43C natural gameplay eligibility and gameplay use remain
unresolved. Content Core 0.194 therefore exposes an exact multi-group
registry only as **Routine 40 grouped analysis**. A first-stage row opens the
same-numbered retained group; a second-stage row runs only that fingerprinted
DEF body in a cloned sandbox. Empty groups stop at the native `0xFFFF`
boundary. Movement is clamped without wrapping, slots 21/13 are not written,
and neither the post-result consumer nor caller is resumed. This remains an
inspection workflow, not normal event playback. The v3 reusable bridge also
accepts a source-bound single-row
shape only when the original bytes contain the exact result-1 branch. It is
displayed as option 1 even when its stored DEF identifier is non-zero; the
separate false destination is preserved as unlabeled evidence, not called
cancel/back. A list without an exact contract or a dedicated confirmed route
stays **Explicit detached DEF
preview**: only one hash-checked body runs in a duplicated sandbox, all state
is discarded, Continue stays disabled, and the caller is not resumed. The
original EVENTD01 validator uses body `0x0704..0x0729` as a direct read-only
regression before restarting its separately confirmed full route.

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_routine40_gated_contract.gd -- `
  <ELFIMAGE\mes.arc>
```

This focused validator reopens the authoritative DENSHA route and checks all
three results under both stored gate values without modifying the archive.
`validate_mes_routine40_single_contract.gd` separately reopens one
authoritative `A_DATE3.MES` route and verifies its non-zero stored DEF ID,
result-1 branch, option destination, and unlabeled false destination.
`validate_mes_routine40_group_registry.gd` reopens the authoritative `43C.MES`
address-entry-148 route with fresh and fully eligible isolated states. It
verifies that trace v64 retains the seven command-`0x1B` registries
independently, reproduces the conditional group counts, and exposes group 0's
six rows as the fixed-key first-stage list. It also validates the disposable
grouped-analysis contract for both states. Contract v2 also reproduces the
stored secondary consumer counts and group-4 common fallback coordinate while
keeping slot-13 writes, consumer execution, and gameplay meaning outside the
generic choice bridge. Content Core 0.271 adds a path-free remake-only consumer
plan for one reachable numeric pair. Event Player now uses that plan, rather
than raw grouped-contract fields, to display the exact consumer/fallback hint
and to accept the `0xFFFF` empty-list terminal. Analysis still does not commit
slots 21/13, enter the consumer, or resume a caller.

The EVENTB02, EVENTD01, EVENTD02, and EVENTD03 caller continuations are backed by one
versioned Content Core route validator. It rechecks exact caller dispatch,
date-selected BGM prefix, isolated two-write suffix, and `MACHI.MES` handoff
contracts; a hash, coordinate, request, state, or target mismatch disables the
continuation instead of falling back to generic execution.

For the complete bounded EVENTD02 inspection, select `EVENTD02.MES`, open
**Sandbox**, set **HHMM [19]** to `0600`, click **Apply Quick State**, and then
click **Start Event Dialogue**. The action starts at callee coordinate zero from
the original `12C.MES` caller contract. The Results trace first shows the
bootstrap, routine 28, two explicit native-record omissions, the normalized
surface-branch bypass, and routines 21/28. The game frame then shows original
`D01X.MMO` with the decoded `D01XAN.MMO` foreground tool preview and
`D01X.AX` metadata before `MAKI.WAV` and the first dialogue. Native AX placement
is not reproduced. A fresh/default `HHMM=0000` run instead reports the expected
missing original D01Z background/foreground/AX family and continues without
substituting daytime media. The automated `HHMM=1600` route binds the original
D01Y background, foreground, and AX entries. The stored prefix surface at
`0x023F..0x0264` is checked but bypassed on the normalized route; do not confuse
it with the later reached EVENTD02 surfaces near `0x0CC5` and `0x1356`.
Those later paths are independently guarded by the original `D02X.MMO` and
`D02Y.MMO` fingerprints and expected `D02Z.MMO` absence.

Continue through the explicitly labeled native-FX omission and remaining
dialogue. The later route stops visibly at routine 21 after those exact surface
envelopes; **Continue** executes only the isolated library metadata path and
omits native pixels. The event retains its existing `0x0BAD` **EVENT NOT
COMPLETE** pause, exact `0x0BB4` omission resume, 40-dialogue total, completion
screen, and caller controls. A daytime route can finish on the separately
reached post-event `D01XAN.MMO` record. At the completion screen, **Preview
Caller BGM** follows the exact date-selected `12C.MES` prefix without changing
state. **Continue Caller Handoff** then applies the two confirmed caller sandbox
writes and stops at the exact `MACHI.MES` marker. The unresolved host consumer
is not executed. All source ARCs remain read-only. A source/hash/coordinate,
expected-presence/absence, or bounded-stop mismatch disables the start without
clearing the last valid preview or falling back to the former `0x03E6` start.

For the complete bounded EVENTD03 inspection, select `EVENTD03.MES`, click
**Start Event Dialogue**, and begin at the original caller's coordinate-zero
entry. **Continue** crosses the first routine-28 boundary; at the next exact
pause, **Continue (Omit Native Records)** omits only the two adjacent three-
record command-`0x12` lists. The resumed path reaches and decodes `D03.MMO`,
records the independent state write and native surface operation without
executing native pixels, follows the default branch and routines 21/28, starts
`MAKI.WAV`, and reaches the first dialogue.
The pre-dialogue shared-routine continuations accept only their exact three
routine/boundary/resume tuples, and initial routine 28 normalizes a seeded
`global_u8[4000] = 1` to the tested zero branch. The original `D03.MMO` base
entry hash must match; overlay resolution can still replace its presented
bytes. Advance the remaining dialogue until the explicit event completion
screen. **Preview Caller BGM** follows the confirmed date-selected
`12C.MES` prefix without a state change. **Continue Caller Handoff** then
applies the exact two caller sandbox writes and stops at the confirmed
`MACHI.MES` marker. The tool does not execute or infer that marker's native
host consumer. A source/hash/coordinate/record/base-media mismatch disables this
route, and the original ARC files remain read-only.

The batch always runs the Python regression suite, a Godot parse check, and the
synthetic Content Core, MES, codec, preview, launcher, and four independent app
tests. With `--elfimage`, it additionally reopens the original ARC set and runs
the ARC writer no-op corpus, audio/image/MES validators, original MES Editor and
Event Player integrations, the exact surface-operation corpus/reachability audits, and the
exhaustive Event Runner anchor audit. With
`--exe`, it cross-checks the bounded native ARC, MES, and Ogg/Voice ARC stream
contracts in the original launcher. Every child process is headless, failures
do not prevent later checks from running, and the final versioned summary lists
all failures. Use
`--report <local-path.json>` for an atomic machine-local JSON report, and
`--skip-event-corpus` only for a shorter interim run.

Launch the graphical suite index from the project root with Godot 4.7. It can
forward one optional existing ARC path while keeping every app independently
executable:

```powershell
Godot_v4.7-stable_win64.exe --path . `
  res://tools/content_suite/apps/content_suite_launcher.tscn
```

ARC Browser can attach an existing package with **Load overlay**, reopen an
external update with **Hot Reload**, or return to the original index with
**Clear overlay**. Its table keeps the original stored offset while showing the
effective byte count and `Original`/`Overlay` source. **Extract selected** uses
the shared resolver and bounded extractor, refuses an existing output, and
never opens the source ARC for writing. It writes a unique sibling temporary
file, closes and reopens it for size/SHA-256 verification, and atomically
publishes it only while the destination remains absent. A changed source or
failed copy leaves neither a final nor temporary output. The browser is
format-neutral. **Export overlay ARC...** writes all targets from the active
validated snapshot into a new ARC copy. It binds the operation to the source
SHA captured when the browser opened the archive and to every manifest payload
SHA; a changed source or content-addressed blob fails without output, and the
original ARC is never modified. A successful export also publishes
`<output>.arc.kakyu-provenance.json`, binding source/output and every changed
entry without recording machine paths or payload bytes. MES, Image, and Audio
ARC exports use the same publisher. Another suite app can verify the sidecar
against the selected original; missing, changed, or mismatched proof is treated
as unknown raw input rather than exact original. Type any part of an entry name in **Filter ARC entry names...**;
matching is case-insensitive and status shows `visible / total` rows. The filter
remains active when an overlay is loaded, Hot Reloaded, or cleared. A selected
row is restored through those rebuilds only while it still matches. Hiding it
clears the selection, so **Extract selected** requires a newly visible selection
and cannot silently extract the previously selected entry. Displayed overlay
metadata and resolved extraction use the same validated manifest snapshot; a
failed reload preserves the previous read layer. Candidate activation uses the
shared archive-binding transaction, which fingerprints the open ARC once and
returns manifest-ordered records plus descriptors keyed by canonical uppercase
entry name.

Every Content Core overlay save or MES projection detach also remembers the
SHA-256 of the exact manifest bytes it loaded. If another tool publishes a new
revision before this operation's final rename, the stale update is rejected,
the newer manifest is preserved, and the temporary manifest is removed. The
published file is reopened and matched to the intended SHA before success is
reported. Content-addressed payloads prepared before a conflict may remain
unreferenced; they do not retarget the active package.

Content Core 0.145 wraps that optimistic revision check in a shared
cross-process directory lock. The lock covers initial manifest read, payload
preparation, the one manifest publication, and reopen verification. A live
owner makes another app fail with a retry message; a dead owner is atomically
quarantined, and abandoned sibling manifest/payload/projection temporaries from
dead processes are removed before retry. Token verification prevents one
publisher from releasing another publisher's lock. Run
`res://tests/test_overlay_publication_lock.tscn` headlessly to launch two real
Godot processes, preserve both writers' records, exercise dead-owner recovery,
and confirm the source ARC remains unchanged.

Content Core 0.146 adds portable `project.json` v1 metadata for one shared mod
workspace. It binds mod/core versions, the canonical source content-set
fingerprint, target archives, compatibility objective, dependencies, and
Event Player presets without embedding original payloads or an ELFIMAGE path.
`KakyuContentProject` rejects unknown/nonportable data and publishes exact
revision/SHA updates under `.project.lock` through a verified sibling temporary
and reopen check. Run `res://tests/test_content_project.tscn` headlessly to
verify the schema and publisher. `manifest.json` remains the replacement
authority composed by the workspace service below.

Content Core 0.147 provides that composition through
`KakyuContentWorkspace`. It creates or opens an exact project + manifest +
read-only ContentSet generation, exposes only portable snapshot metadata, and
retains the last valid generation when refresh fails. Workspace staging is
limited to declared target archives, freezes the project revision, and lets the
locked OverlayPackage publisher merge only the requested records over the
latest manifest. Run `res://tests/test_content_workspace.tscn` headlessly to
exercise cross-tool record preservation, stale-project rejection, source hash
rejection, and snapshot rollback. The Content Suite Launcher now provides
minimal ELFIMAGE-bound **Create Workspace** and **Open Workspace** controls,
remembers only the chooser directory in machine-local user data, and never puts
that source path in `project.json`. Content Core 0.151 adds the strict named
process handoff. Every launched app independently revalidates the content set,
project, and manifest before opening its compatible ARC and overlay layer.

Content Core 0.148 adds `KakyuArcProvenance` and the strict
`kakyu_materialized_arc_provenance/v1` sidecar. Run
`res://tests/test_arc_provenance.tscn` headlessly to exercise locked
non-overwriting materialization, reopen verification, workspace generation
binding, tamper rejection, and exact-original/original-derived/unknown
classification. Lineage proof remains independent of declared engine
compatibility and never promotes it.

Content Core 0.152 adds a path-free `kakyu_event_catalog_browser/v1`
projection with composable discovery/support filters, recommended preset,
branch/choice/terminal counts, compatibility, and bounded blocker summaries.
Run `res://tests/test_event_catalog.tscn` headlessly for projection and catalog
immutability checks. Event Player's **Event Catalog...** window adds composable
discovery/support fields, bounded compatibility/blocker details, and a source
handoff that enables only for a callee present in the open `mes.arc`.

Content Core 0.153 adds `kakyu_event_catalog_play_request/v1`: confirmed
playable records with no blocking blocker can select their first
`original_branch` preset and expose the exact callee binding/start coordinate
plus isolated sandbox writes. Blocked, analysis-only, unresolved, host-owned,
and unknown event/preset requests fail closed; building the request never reads
or changes a source ARC.

Content Core 0.154 adds `kakyu_mes_script_call_continuation/v1`. The shared
MES script-call runner can pause at a visible dialogue inside an explicit
command-`0x0F` callee and later resume through its return to the exact LIFO
caller coordinate. The token contains source hashes/address tables, frames,
call records, and temporary argument/evaluator context rather than MES bytes;
changed scripts or malformed coordinates are rejected. Run the focused check
without opening a window:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  res://tests/test_mes_script_call_runner.tscn
```

Content Core 0.272 changes the Event Catalog Play request to
`kakyu_event_catalog_play_request/v4`. A `nested_call` request binds the
original command-`0x0F` caller entry, dispatch coordinate, and physical resume
as well as the callee start, and carries the versioned terminal lifecycle. A callee
return, caller post-event presentation, normal completion, early end,
rejection, and unresolved outer-host handoff are separate stages matched by
entry, offset, runtime status, state assertions, and target. The metadata is
copied from the validated catalog and contains no MES bytes. A caller-free
`root_replacement` variant binds an exact command-`0x0E` activation and
callee-owned replacement terminal. Event Player rereads the exact activation
record, target, and required-entry hashes from the open content set before it
enters an event-specific executor. The EVENTB03 adapter starts its caller-free
zero-coordinate sandbox, reaches the first original dialogue through the exact
`0x011B..0x0131` setup records, and carries each qualified choice through
its own exact suffix to the callee-owned root terminal. Its catalog status is
partial because wider starting states and native presentation remain unqualified.

Content Core 0.156 adds `kakyu_event_player_caller_frame/v1`. EVENTB01,
EVENTB02, EVENTB14, EVENTB15, EVENTD01, EVENTD02, EVENTD03, EVENTD08, and EVENTD14 now validate the
exact caller dispatch again before Start changes the isolated session, retain
one common caller/callee frame through the event, and restore its temporary
argument/evaluator context for optional caller BGM and final handoff. EVENTB15
uses the direct 11M.MES suffix form without a caller BGM stage. Source or frame
drift stops fail-closed instead of falling through to an event-specific route.
EVENTD08 now retains that frame through its audited 12C/D_PIC restoration
adapter and final caller handoff. EVENTB14 retains its 44M frame but stops
before the caller-owned routine-40 boundary at `0xFFBA`; its native result
mapping remains intentionally disabled.

In the Event Catalog, **Play catalog preset** binds that request to the open
source profile and effective MES entry, starts a fresh isolated sandbox, and
automatically traverses controller-confirmed internal continuations until the
next dialogue, choice, or confirmed ending. It stops fail-closed on an unknown,
non-progressing, or over-limit boundary. The original-content playback batch
checks all ten playable seeded routes without opening a GUI. It also replays
EVENTB01 from its first dialogue through the final caller-owned handoff, where
Playback shows the generic completion only after the issued terminal contract
still matches the loaded catalog and the runtime owner/status/offset/target.
The footer explicitly states that the outer host was not executed. This direct
Playback integration is Content Core 0.164; persisted schema IDs are unchanged.

Content Core 0.165 removes the remaining route-specific completion gate from
ordinary Playback. After source-bound startup, the catalog terminal contract
alone decides continue/end/reject. Analysis still retains route-specific
offsets and diagnostics.

Run the headless original-content check with:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_catalog_playback.gd -- `
  "<ELFIMAGE>"
```

Event Player now starts in **Playback** mode: the 640x400 event frame,
catalog, confirmed Start/Continue actions, and BGM control remain visible while
MES offsets, manual boundary controls, resource diagnostics, sandbox fields,
trace tables, and the debug status line are hidden. Select **Analysis** in the
toolbar to restore the existing evidence workflow without reopening content or
resetting the runner, sandbox, current result, continuation, or media. The
catalog's **Select MES source in Analysis** action selects the available callee
and performs the same mode switch.

Content Core 0.149 adds `KakyuContentIdentity`. Event Player now reports
original route evidence separately from the effective MMO, AX, BGM, and voice
payload selected through the resolver. A source-bound media overlay can keep a
confirmed route playable without being mislabeled as exact original. Changed
MES control flow remains unsupported unless a versioned interface validation
proves compatibility. Run `res://tests/test_content_identity.tscn` headlessly
for the exact-original, overlay, materialized-lineage, and MES fail-closed
contract.


Content Core 0.160 adds a verified materialized-ARC layer to the shared
resolver. Register the authoritative original ARC first, then attach a derived
ARC carrying a valid `.kakyu-provenance.json` sidecar. Resolution becomes
`overlay -> materialized ARC -> original ARC -> fallback`; failed attachment
keeps the last valid layer, and replacing the original evidence registration
clears derived lineage. Event Player consumes the same contract through its
ordinary **Derived...** manager.

Event Player's headless P2-10 activation now accepts a complete dictionary of
verified media-only materialized ARC paths, prepares a new resolver containing
the still-selected original ContentSet plus those layers and any active
overlay, and swaps only after all provenance, source, overlay, and selected-MES
checks pass. Clearing the overlay retains derived media; clearing the derived
map restores originals. `mes.arc` is intentionally rejected from this path.
In the GUI, open an ELFIMAGE content set, choose **Derived...**, then use
**Add or replace...** to select a provenance-bearing ARC. The manager infers
the logical archive from the sidecar, lists filename/compatibility/replacement
count, and provides **Remove selected** and **Clear all**. A failed change keeps
the previous document, Results, continuation, preview, audio, and sandbox.

Replacement and MES-projection blobs are content-addressed. The publisher
checks the destination immediately before rename and does not replace a
different file already present there. An identical competing blob is safely
reused after SHA-256 verification; a different blob is preserved and the
operation fails. A newly renamed blob is reopened and rehashed before its
manifest record can be published. This narrows but does not eliminate the final
filesystem check-to-rename race described above.

MES Editor's References tab contains full-height Code, State, and Resources
subtabs. Resources lists only shared-decoder exact MMO/AX/voice envelopes,
shows their candidate ARC names, and distinguishes strict instruction starts
from bounded envelope matches found after an earlier decoder stop. The latter
is metadata inspection, not recovered control flow or a native playback claim.

The optional generated MES UTF-8 cache is disposable presentation data, not
authored source. Its manifest and each entry JSON are limited to 16 MiB, and an
entry's configured SHA-256 is rechecked over the exact bytes parsed on every
load. If another process changes, truncates, or grows that file after cache
selection, MES Editor and Event Player reject the cached entry and continue
with decoded effective CP932 text.

After **Load overlay...**, use **Hot Reload** to revalidate an externally
changed manifest and reopen the selected MES entry through the shared resolver.
Both UTF-8 projections and binary replacements are rebound and reanalyzed.
**Clear Overlay** detaches the package and reopens the selected entry from the
read-only original ARC; a matching generated cache can again provide its text
presentation. Hot Reload and Clear Overlay are both blocked while any entry has
pending edits or while the current message field contains an unstaged draft,
so neither can discard unsaved text or change the active manifest behind an
edit session. A candidate package replaces the active resolver only after its
manifest, source hashes, targeted MES payloads, and selected-entry reopen all
validate; a failed reload retains the last valid overlay and analysis. MES
entry and ARC navigation is guarded by the same unstaged-draft check. If
necessary, a filter is cleared to restore the draft-bearing entry's visible
row. Save, CP932 export, and projection detach actions are also disabled while
the field differs from the staged/presented text. Payload lookup remains
`overlay -> original ARC -> res:// fallback`, and none of these actions writes
to the source archive.

The corresponding no-window original-corpus check is:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_analysis_corpus.gd -- `
  <ELFIMAGE\mes.arc>
```

`tools/content_suite/cli/prepare_mes_smoke_copy.gd` creates a new isolated
`mes.arc` candidate containing one same-byte-length CP932 marker edit. It
requires a strict message offset that also matches the EXE-derived native text
boundary, reopens the rebuilt archive, and verifies that the source hash stayed
unchanged. Preparation is headless and does not launch the original engine;
the result remains an unverified test candidate until the deferred interactive
batch is run.

The standalone Audio ARC Editor can queue multiple OGG/WAV replacements in one
session, preview the pending file for the selected entry, and save the complete
validated batch to an overlay package or a new ARC copy. It keeps only source
paths and fingerprints while idle, validates a bounded header, streams files
through the shared writer during save, and never
overwrites the opened archive or an existing output.

Use **Load overlay** to validate and attach an existing package to Audio ARC
Editor. **Hot Reload overlay** reopens externally changed payloads and **Clear
overlay** returns resolution to the original ARC. Details, Preview, and Extract
selected follow `Pending -> Overlay -> original ARC`; the tree labels the
active authored source. Detail inspection remains header-bounded, and
file-backed extraction is chunked into a hash-bound sibling temporary file and
published atomically after reopen verification. Overlay switching is blocked
while pending replacements exist. Saving a session attaches the published
package, so removing pending rows exposes the saved audio layer. Load and Hot
Reload validate the current ARC binding through a separate resolver and use its
single manifest snapshot for both entry labels and reads. A failed or wrong-base
reload keeps the last valid overlay, details, and preview stream active. The
shared archive-binding transaction fingerprints the open ARC once and checks
all its records, including non-audio entries; only OGG/WAV records become audio
tree labels. Its fingerprint must still match the one captured with the
displayed index.

Use **Analyze timeline** after selecting an entry. The shared
`kakyu_audio_timeline_summary/v1` analyzer derives exact PCM
WAV duration and a bounded min/max/RMS waveform (up to 256 buckets and 262,144
sampled frames). For Ogg Vorbis it walks one logical stream to the final granule
to report duration, but explicitly leaves waveform unavailable until decoded
PCM exists. It never visualizes compressed packet bytes as amplitude. Details
show total/analyzed frames and complete-versus-sampled provenance. Selection
still reads only the validation header; WAV analysis uses one bounded source
range per bucket, and Ogg analysis reads at most a 128 KiB tail. File-backed
pending/overlay content is hash-checked before and after analysis. Preview
remains the separate action that loads the selected complete stream.

Use **Load MES references...** to scan a read-only original or verified
materialized `mes.arc`. The chooser begins beside the opened audio ARC. The
scan yields after each 16 MES sources so the tool remains responsive, rejects
any parse/read failure without replacing the last valid index, and verifies
the MES archive fingerprint again before activation. Once loaded, selecting an
OGG/WAV shows confirmed MES entry names and code-relative offsets. Only exact
subcommand-7 Ogg voice envelopes and adjacent literal slot-1 selector plus
shared-routine-23 BGM calls are included; a filename-like byte sequence or a
dynamic/non-adjacent assignment is not presented as a reference.

Content Core also exposes `kakyu_audio_conversion/v1` deterministic presets.
SE WAV targets use PCM16 mono at 22.05 kHz, BGM WAV targets use PCM16 stereo at
44.1 kHz, and voice-bank Ogg targets use a preserve-only mono 44.1 kHz Vorbis
profile. Matching input is returned byte-identically. Explicit WAV conversion
uses fixed integer channel conversion and linear resampling, then validates the
canonical result and reports both fingerprints. Nonmatching Ogg is rejected
because there is no verified Vorbis encoder.

For a selected WAV entry, **Convert WAV to target...** fingerprints a chosen
PCM WAV, asks for a new `.wav` output, runs the shared preset, and publishes
through a reopen-verified sibling temporary file and atomic rename. The final
verified path/hash plus conversion audit is staged in the normal pending
session. An existing output, changed source, changed target, invalid result, or
failed reopen is rejected. Ogg rows keep this action disabled; use
**Add/update replacement...** to retain already-valid Ogg or WAV input without
re-encoding.

`tools/content_suite/cli/prepare_audio_swap_smoke_copy.gd` prepares a headless,
no-reencode playback candidate by replacing one OGG/WAV entry with a different
same-format entry from the same ARC. It verifies both full payloads, rebuilds
and reopens a new archive, and proves the source hash stayed unchanged. The
candidate remains `remake_only` until the deferred original-engine batch
confirms its target route.
ArcWriter rechecks the destination immediately after the temporary rebuild has
been reopened and verified. If another process created that destination during
the rebuild, the existing file is preserved, the verified temporary ARC is
removed, and publication fails instead of overwriting it.
Content Core 0.142 also exposes source-bound writer variants: they require the
SHA-256 captured when a tool opened the source ARC, check it before building,
and check it again after verifying the temporary result. A same-size external
source change therefore fails without publishing an output. Audio ARC Editor,
Image ARC Editor, and MES Editor use these variants for new-ARC export and keep
their pending sessions when the source check fails. Low-level no-op corpus
helpers may continue to use the unbound API while independently checking source
hashes.

Content Core 0.143 adds `write_repacked_copy_from_bound_files()`. Replacement
descriptors carry both a path and the SHA-256 from the validated overlay
snapshot. The writer rejects a missing, changed, or same-size-mutated payload
before publication and rechecks that digest while streaming. This prevents a
manifest-selected blob from being replaced between overlay validation and ARC
materialization; persisted ARC and overlay schemas do not change.
Audio and Image Editor use the same descriptors for their pending-session ARC
exports, carrying every revalidated cache-file SHA directly into the writer.

`tools/audit_ai5_audio_exe.py` statically locks the embedded runtime's OggS,
Vorbis, decoder-diagnostic, Voice ARC configuration/registration, common named-
entry loader, native MES presentation-subcommand-7 voice queue, document
vtable slots, bounded Ogg stream handoff, terminal DirectSound Play dispatch,
and the three-selector settings sample route (`kokuhaku.wav`, `kse0006.wav`,
and `e0820.ogg`). Its byte expectations are spans, not copies of the executable (see
`audit_ai5_arc_exe.py`); its tests need `KAKYU_ORIGINAL_EXE` and skip without it.
It is included in the
`--exe` headless batch; pass
`--voice-arc <ELFIMAGE>\voice.arc` to case-fold the literal
against the shared ARC index and validate that bounded Ogg/Vorbis entry. Pass
`--mes-arc <ELFIMAGE>\mes.arc` to validate every native selector-2 typed record
as value 2, NUL-terminated ASCII Ogg name, value 0. The audit classifies
`e0820.ogg` as selector 2 of the separate settings path, reports the MES
voice-marker queue/stream consumer and
`IDirectSoundBuffer::Play(0, 0, DSBPLAY_LOOPING)` dispatch as bounded; it never
launches or decodes audio, so host-device and physical speaker output remain
unobserved.

`tools/content_suite/test_original_engine_audio.ps1` performs the Windows-only
end-to-end writer/playback smoke test against a user-owned installation. It
creates and removes an isolated temporary copy, replaces only the startup
`KSE0031.WAV` through the shared Content Core writer, measures the original
engine child process through Core Audio, and verifies that source hashes did not
change:

```powershell
.\tools\content_suite\test_original_engine_audio.ps1 `
  -GameRoot "<user-owned-game-root>"
```

Pass `-GodotConsole <path>` when the Godot 4.7 console executable is not on
`PATH`. The test briefly starts the original game window but sends no foreground
input and never writes to the source installation.

`tools/content_suite/prepare_original_engine_verification_batch.ps1` groups
the deferred MES, DAT/PAL, and Ogg candidates into one atomically published
local directory. It first locks the checked original hashes, refuses source or
existing destinations, and supports `-PlanOnly`. The default action invokes
only headless candidate preparers and emits a path-free versioned manifest; it
does not launch the original engine or a Godot window. Keep this generated
directory local and use it only with the disposable local-copy validation step.

`tools/content_suite/prepare_local_verification_copy.ps1` turns that candidate
directory into a new disposable game copy without opening it. It requires the
checked launcher, eight source ARC files, and all three candidate hashes;
copies only into a guarded sibling staging directory; replaces only copied
`mes.arc`, `data.arc`, and `voice.arc`; rehashes the complete copied archive
set; rechecks every input; then publishes with one rename. `-PlanOnly` performs
only source, destination, and free-space checks. No optional OS virtualization
feature is required. The copied engine may take keyboard focus when
the user explicitly launches it, so preparation never launches it implicitly.

After the isolated run, record the four direct observations into a new local
JSON file. The recorder requires an explicit attestation, rehashes the batch
manifest and all candidate archives, refuses an existing or in-batch output,
and records `pass`, `fail`, or `not_observed` without changing any candidate's
`original_engine_unverified` compatibility:

```powershell
py tools\content_suite\record_original_engine_verification.py `
  --batch-root "<prepared-batch-root>" `
  --output "<new-local-result.json>" `
  --mes pass --dat-pal pass --ogg pass --responsive pass `
  --attest-isolated-run
```

Result schema `kakyu_original_engine_verification_result/v1` is path-free and
contains no original payload. `all_observations_passed` means only that all
four manually reported checks passed; `compatibility_promotion` remains
`not_performed` until a separate reviewed decision changes a contract.

## Kakyu image extraction

Kakyu2/GCC extraction is intentionally not included.

### `ai5_lz.py`

Library module implementing the AI5 4 KiB sliding-window LZ decompressor. It is imported by the MMO converter and is not normally run directly.

### `extract_kakyu_arc.py`

Decodes the 264-byte Kakyu AI5 ARC index and streams entries from archives such
as `mmo.arc`, `data.arc`, and `mes.arc`. The index is bounds-checked, unsafe or
duplicate entry names are rejected, sources are opened read-only, and existing
outputs are skipped unless `--overwrite` is explicitly supplied.

```powershell
py tools\extract_kakyu_arc.py assets\_source\kakyu\ELFIMAGE\mmo.arc -o assets\_extracted\kakyu\raw\image
py tools\extract_kakyu_arc.py assets\_source\kakyu\ELFIMAGE\mmo.arc -o NUL --list
```

### `extract_arc_entries.gd`

Command-line front end for `KakyuArcBatchExtraction`
(`tools/content_suite/arc_batch_extraction.gd`), the multi-entry and
complete-archive extraction the ARC Browser's **Extract selected to
folder...** and **Extract archive...** toolbar actions use. It opens one ARC
read-only through the shared resolver, optionally binds an overlay read
layer, then extracts either the listed entries or, when none are listed,
every index entry into a fresh output directory:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/extract_arc_entries.gd -- `
  <archive.arc> <output_dir> [--overlay <package_root>] [ENTRY ...]
```

Every requested name is checked against the archive (or overlay) before any
file is written, and an existing destination is refused instead of
overwritten. If one entry fails partway through a batch, every file that call
already created is removed before the tool reports the failure; a
pre-existing file or directory it did not create is never touched. The tool
prints exactly one JSON line (`{ok, count, bytes, overlay_count,
original_count, directory}` or `{ok: false, error}`) and exits 1 on failure.
This Godot tool reads through the same resolver and overlay contract as the
independent apps; `extract_kakyu_arc.py` remains the separate Python analysis
adapter used by the image/audio conversion pipelines below.

### `compare_arcs.gd`

Command-line front end for `KakyuArcComparison.compare_archives`
(`tools/content_suite/arc_comparison.gd`), the same entry-by-entry ARC-to-ARC
comparison behind the ARC Browser's **Compare with ARC...** toolbar action.
It opens both ARCs read-only (they may be the same file), compares every
entry by name (case-insensitive), and optionally writes the path-free
comparison report:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/compare_arcs.gd -- `
  <left.arc> <right.arc> [<output.json>]
```

Neither archive is modified. When the two archives share the same whole-file
SHA-256, each entry is hashed once and the hash is reused for both sides
instead of streamed twice. The tool prints exactly one JSON line (`{ok,
identical, changed, only_left, only_right, total, order_preserved, path}` or
`{ok: false, error}`) and exits 1 on failure.

### `convert_mmo_best.py`

Converts extracted `.MMO` images to PNG using AI5 LZ decompression, horizontal/vertical delta restoration, BGR-to-RGB conversion, and vertical flipping.

```powershell
py tools\convert_mmo_best.py assets\_extracted\kakyu\raw\image --skip-existing
```

Default output: `assets/_extracted/kakyu/png/mmo_best`.

### `convert_dat_pal.py`

Pairs indexed-color `.DAT` files with matching 768-byte `.PAL` palettes,
decodes their BGR channels and bottom-up scanlines, and converts supported
image sizes to PNG. The 640-by-32 character strips retain palette-index-zero
transparency.

```powershell
py tools\convert_dat_pal.py assets\_extracted\kakyu\raw\image
```

Default output: `assets/_extracted/kakyu/png/dat_pal`.

The standalone Godot Image ARC Editor uses the equivalent shared GDScript
codec in `content_core/dat_pal_codec.gd` for lazy previews. The codec now also
provides deterministic palette quantization and DAT/PAL encoding with strict
alpha validation. Content Core `0.185.0` adds
`kakyu_ai5_dat_pal_diagnostics/v1`: decoded pairs report palette-index use and
reserved index-zero transparency, while PNG imports report source/palette
colors, changed pixels, RGB mean absolute/RMS error, and maximum channel error.
Exact imports retain those diagnostics in the paired pending session. A lossy
candidate remains outside that session while a modal before/after panel shows
the imported PNG and deterministic decoded result. Reject removes its
transient files; Accept rechecks the open ARC, both cache descriptors, and the
reviewed pixels before creating one remake-only paired pending item. Hidden RGB
beneath alpha zero is excluded.
Content Core `0.186.0` adds `kakyu_ai5_dat_pal_palette/v1`, which enumerates all
256 RGB/BGR entries with use counts and provides one-entry detached mutation.
Image Editor's palette row stages a selected opaque RGB change into the normal
paired DAT/PAL session and reopens it before activation. The 640x32 transparent
index zero is labeled reserved and cannot be staged; entry zero remains normal
for opaque layouts. Original-engine compatibility remains unverified. The
shared `content_core/mmo_codec.gd` and `content_core/ai5_lz.gd` likewise power
MMO previews without requiring files to be extracted first. The shared MMO
codec also provides template-bound encoding for same-dimension replacements;
the standard mirrored-dimension target profile is original-engine compatible
after the isolated `LOGOBKC.MMO` marker smoke test. Content Core `0.184.0`
classifies all 1,727 original headers under
`kakyu_ai5_mmo_header_profile/v1`: 1,718 standard, eight nonzero-trailer, and
one flagged secondary-dimension profile (`CALFACE.MMO`). Special templates are
preserved only as remake-compatible output; generated canonical headers also
remain remake-only. Image Editor shows this profile and provenance alongside
the decoded image, and Event Player shows the structural header profile beside
the effective overlay/materialized/original compatibility.
The same editor lists AX aligned-dword streams and A6 input-region tables
through shared bounded readers. A6 rows are shown as the EXE-confirmed
`ID, left, top, right, bottom` inclusive rectangles with first-match and
duplicate-ID diagnostics. The shared A6 encoder now validates authored u16
fields and rectangles, preserves order and duplicate IDs, and byte-identically
rebuilds all 12 original tables. Select an A6 row in the editor to choose an
existing record, edit its ID or inclusive rectangle, and stage the reopened
payload into the same overlay/new-ARC session used by image replacements.
The Game Frame tab draws every bounded region at its stored 640x400 logical
coordinates. Hovering reports the native first match, and clicking a contained
coordinate selects that record using the same inclusive-edge/first-record rule
as the shared reader. Regions beyond the frame are clipped for display only.
Content Core `0.187.0` advances the A6 contract to
`kakyu_ai5_a6_input_regions/v4`: exact first-match union coverage reports
partial and fully unreachable rows, while insert/duplicate/remove/move helpers
encode and reopen the ordered table. The original 12-table corpus fixes 153
records, 21 overlapping pairs, 19 partially occluded records, zero unreachable
records, and byte-identical no-op rebuilds. Image Editor exposes these helpers
as **Add after**, **Duplicate**, **Remove**, **Move up**, and **Move down** and
shows the recomputed overlap/partial/unreachable result after every operation.
Changing record order is an explicit authored action because A6 first-match
input behavior is order-sensitive. A6 contains no standalone pixels or PNG
import path. AX remains read-only: the editor
shows the EXE-confirmed 10-by-32 table of 320 entry-relative targets from the
first `0x500` bytes, the cell control streams, shared source/destination
rectangle records, opcode counts, and the neutral aligned dword boundary. The
EXE-confirmed renderer copies three-byte pixels from native surface 8
(2688x864) to surface 0 (640x400) with transparent RGB key `0x00FF00`; all
6,332 original source and destination rectangles fit those respective bounds.
The AX Game Frame lists non-`0xFF` cells and outlines only the confirmed
destination records directly referenced by the selected cell's stored command
stream as a labeled structural overview. **Play/Pause** compiles the confirmed
bounded control subset and advances it through the shared AX scheduler;
**Restart** returns to tick zero and the structural overview. After a dispatch,
only its current confirmed destination is outlined. AX contains no standalone
pixel surface, so a detached editor selection has no inferred source image.
Executable audit v69 plus exact MES traces confirm that EVENTB02 and EVENTB14
load their selected AN MMO into surface 8 before the following AX load, but
that route binding is not invented for a standalone AX entry. The 60 Hz value
is explicit tool timing; native host cadence remains unresolved.

Content Core 0.166 adds the shared
`kakyu_logical_surface_compositor/v1` foundation used by the next Event Player
and Image Editor composition work. It keeps detached RGB8 surfaces, fixes
surface 0 at 640x400, tracks explicit roles and the active surface, expands
inclusive rectangles, and executes only the confirmed mode-0 opaque copy,
mode-1 quantized 24-bit RGB-key copy, and mode-2 active-surface fill. All source
and destination bounds are checked before pixels change. It deliberately does
not fabricate surface-8 pixels, lifetime, layer order, or AX timing.

Content Core 0.167 adds a fail-closed adapter for the MES runner's exact
non-executing surface trace. It rechecks subcommand 11, the mode/helper pair,
inclusive endpoint tag, argument shape, and unchanged sandbox before applying
the operation. RGB key and fill color must be supplied explicitly by the
presentation context. No missing surface or color is inferred, and Event
Player still leaves the native effect omitted.

Content Core 0.168 adds deterministic operation sequence numbers and the
in-memory `kakyu_logical_surface_checkpoint/v1` caller-restoration foundation.
Detached RGB8 payloads carry individual SHA-256 values, while a whole-state
binding covers ordered surface metadata, roles, active index, and sequence.
Restore validates every candidate before an atomic swap, so malformed or
tampered checkpoints cannot partially change the visible state. Event Player
caller frames have not adopted this contract yet.

Content Core 0.169 applies an explicit operation list in stored order as one
transaction. Later layers define overlap order; any failed step restores the
entire pre-batch checkpoint and sequence and reports the failing index. The
core does not use this API to infer which resources or native ticks belong in
that list.

Content Core 0.170 connects logical surface 0 to the shared Game Preview used
by Event Player and Image Editor through
`kakyu_tool_game_preview_compositor_binding/v1`. It publishes a detached
640x400 snapshot with role and sequence metadata, clears stale separate
foreground content, updates only on explicit refresh, and preserves the last
valid frame on binding errors. Producer migration remains explicit and
source-bound.

Content Core 0.171 moves Image Editor's decoded MMO and DAT/PAL Game Frame to
the compositor path. Asset View remains the untouched decoded source. Game
Frame builds a detached black 640x400 surface, applies the preview X/Y placement
with exact clipping, and displays the resulting surface-0 snapshot. Negative
coordinates crop the source and a fully offscreen source yields an empty black
frame. This tool-only placement neither changes pending/output bytes nor claims
native surface-8, key-color, or AX timing behavior.

Content Core 0.172 moves the already source-bound EVENTB02 and EVENTB14 AN/AX
regression paths into the same compositor. The static MMO frame is captured as
a checkpoint; every animation dispatch restores it, copies exactly one AN
source rectangle with the confirmed green RGB key, and republishes surface 0.
The original-content validators compare the complete destination rectangle
against the selected source frame and the restored background. Thus neither a
three-/four-frame atlas strip nor the previous frame can remain visible. The
60 Hz scheduler is still labeled tool timing; native cadence, generic
surface-8 production, and routes without proven placement remain unresolved.

Content Core 0.173 keeps an EVENTB14 choice locked while its outcome dialogue
is advancing, preventing messages from sibling outcomes from being appended.
Its B_PIC return chooses the source-confirmed B.AX face column from the separate
Mahoko-affection Quick Sandbox value. The catalog preset intentionally uses a
source-qualified 19:00 caller state and the original B3.MMO route. The daytime
high-affection B.MMO composition remains compatibility/debug coverage.
The option-2 route additionally validates `IDOU.WAV` at `0x0B07`, retains the
dormitory frame during the forced accompanying-move interval, and marks the
atomic `B14.MMO` park arrival plus the subsequent `FURARE.WAV` request at
`0x0E99`. Reconstructed park dialogue keeps that later BGM instead of reverting
to the movement cue.

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  res://tests/test_logical_surface_compositor.tscn
```

**Load Overlay** attaches a validated package to the Image ARC Editor without
extracting or changing the original archive. **Hot Reload Overlay** reopens an
externally updated package and **Clear Overlay** returns to original bytes.
The tree distinguishes loaded `Overlay` entries from unsaved `Pending` edits;
the latter always win. DAT and PAL are resolved separately, so partial paired
replacements remain visible and diagnosable. Overlay switching is deliberately
blocked while edits are pending. After **Save Overlay**, the published package
becomes the loaded layer and removing pending items reveals the saved result.
Load, Hot Reload, and the post-save attach validate through a separate resolver
registered to the current ARC. They configure one manifest snapshot, then the
shared archive-binding transaction fingerprints the ARC once and verifies
every record for it, including non-image entries, against its base-ARC hash,
existing entry, and original-entry hash. Tree labels come from that same result.
The candidate fingerprint must still match the one captured with the displayed
index, preventing an external path replacement from mixing snapshots.
Only a fully valid candidate replaces the active resolver, overlay directory,
labels, details, and decoded preview. A malformed, changed, wrong-base,
missing-entry, or resolver-mismatched reload leaves the last valid layer and
visible preview unchanged. This package validation remains entry-based: an
existing overlay may replace only the DAT or only the PAL half, with the other
half resolved normally. PNG authoring continues to stage, remove, and publish
both halves as one pending DAT/PAL session item.
Filtering the image/layout entry list is selection-safe. When a filter hides
the current row, the editor clears that row as the active target, removes its
pixel/A6/AX preview, and disables **Import PNG**, **Remove pending**, and PNG
**Export**. Clearing the filter does not silently reselect it; choose a visible
row explicitly. Pending session files remain intact and become available again
when their row is selected.

### `extract_kakyu_all.py`

Runs the complete Kakyu pipeline: extract `mmo.arc` and `data.arc`, convert MMO images, then convert DAT/PAL pairs. By default it reads archives from `assets/_source/kakyu/ELFIMAGE` and writes all generated files below `assets/_extracted/kakyu`.

```powershell
py tools\extract_kakyu_all.py
py tools\extract_kakyu_all.py --elfimage-dir "<ELFIMAGE>"
py tools\extract_kakyu_all.py --include-mes
py tools\extract_kakyu_all.py --overwrite
```

`--elfimage-dir` is read-only input. `--work-dir` and `--png-dir` can override the generated-output locations.

## MES extraction

The authoritative MES input is each raw entry in `mes.arc`. The transformed files historically found under `ELFIMAGE/mes/*.MES` do not preserve the runtime container header and are not used by this pipeline.

### `inspect_map_sources.py`

Audits the original `MACHI`, `TRAIN`, `GROUND`, and `FLOOR1`--`FLOOR5` map sources
directly from `data.arc`. It decodes `MPC` collision cells, `EVE` trigger
records, `CCD` actor records and entrance presets, derives the primary 2-by-2
actor's clear-foot navigation spans, and records file-relative offsets and
hashes. Optional PNGs use light cells for clear terrain, dark cells for the
`0x80` collision flag, red outlines for `EVE` triggers, and cyan outlines for
`CCD` actor entrance presets.

```powershell
py tools\inspect_map_sources.py <ELFIMAGE\data.arc> `
  -o analysis\map_source_audit_v2.json `
  --render-dir analysis\map_source_audit_v2_masks `
  --runtime-dir data\maps\original `
  --machi-world assets\original\maps\MACHI_NATIVE_NIGHT.png `
  --protagonist-sprite assets\original\map_actors\CHARA.png
```

The JSON and masks are source-derived local analysis products and remain under
the Git-ignored `analysis/` directory. `--runtime-dir` emits compact
`kakyu_original_map_collision/v1` JSON with source hashes, clear row spans,
the 16-pixel cell/40-by-25-cell camera contract, the primary actor footprint,
`EVE` records, and `CCD` entrance presets. The
runtime projection contains no machine-specific path and remains under the
Git-ignored local `data/` directory.

`--machi-world` reconstructs the native 1920-by-1280 movement background from
the packed base/overlay tile IDs in `MACHI.MPC`. The default `--machi-atlas
MACHIN_3` is the atlas selected by `MACHI.MES` from 18:00 onward. The converter
reverses the native bottom-first 40-by-25 atlas row enumeration, reads PAL
channels as BGR, and applies palette index zero transparency to the overlay
layer. `--protagonist-sprite` extracts the first twelve 32-by-32 frames from
`CHARA.DAT/.PAL`, vertically flips them, and makes palette index zero
transparent. Generated textures belong under the Git-ignored local `assets/`
directory.

### `mes_archive_ir.py`

Extracts one `mes.arc` entry into lossless `ai5_mes_container/v1` JSON. It preserves archive metadata, the address table, bootstrap bytes, complete bytecode as base64, and SHA-256 hashes.

```powershell
py tools\mes_archive_ir.py assets\_source\kakyu\ELFIMAGE\mes.arc START.MES `
  -o analysis\mes_ir\start_container.json
```

Omit `-o` to print JSON without creating a file.

### `mes_basic_block_ir_v6.py`

Production MES converter. It decodes a raw archive entry into Godot-compatible
`ai5_mes_basic_block_ir/v6` JSON containing instructions, expressions,
control-flow nodes and edges, overlapping paths, actionable basic-block
targets, complete command `0x03` consecutive `global_u8` write runs, command
`0x07` destination/bank/consecutive `banked_u16` writes, and command `0x08`
`banked_i32` writes with the same operand grammar.

```powershell
py tools\mes_basic_block_ir_v6.py assets\_source\kakyu\ELFIMAGE\mes.arc B_TIME.MES `
  -o analysis\mes_ir\b_time_basic_blocks_v6.json
```

Omit `-o` to print JSON without creating a file. Generated analysis JSON belongs under the Git-ignored `analysis/` directory.

### Event Player generated caches

`export_mes_instruction_oracle.py` emits a disposable, archive-hash-bound set
of strict-valid instruction boundaries from the mature Python IR. It is used
to regression-check the GDScript structural decoder and is not runtime data.
`export_mes_text_cache.py` emits versioned per-entry UTF-8 text projections for
the standalone Event Player. The Event Player consumes the cache without a
Python dependency and falls back to the shared runtime CP932 decoder when a
projection is missing or stale. Both generators defer `0xFF` after the
embedded executable's double-byte character-stream handler instead of treating
it as part of a NUL-terminated string. Raw hex remains available for
diagnostics.

`generate_cp932_table.py` reproducibly builds the compact, versioned decode
table used by the GDScript Content Core. It uses only Python's standard `cp932`
codec and emits no original game data:

```powershell
py tools\generate_cp932_table.py content_core\tables\cp932_decode.bin
```

```powershell
py tools\export_mes_instruction_oracle.py <ELFIMAGE\mes.arc> `
  -o analysis\mes_instruction_oracle.json
py tools\export_mes_text_cache.py <ELFIMAGE\mes.arc> `
  -o analysis\mes_text_cache
py tools\audit_mes_command03.py <ELFIMAGE\mes.arc> `
  -o analysis\mes_command03_audit.json
py tools\audit_mes_command03.py <ELFIMAGE\mes.arc> --focus-index 2461 `
  -o analysis\mes_command03_index2461_audit.json
py tools\audit_mes_command03.py <ELFIMAGE\mes.arc> `
  --focus-index 376 --focus-index 377 --focus-index 403 `
  -o analysis\mes_command03_group_guard_producers.json
py tools\audit_mes_command04.py <ELFIMAGE\mes.arc> --focus-index 25 `
  -o analysis\mes_command04_index25_audit.json
py tools\audit_mes_command07.py <ELFIMAGE\mes.arc> --command-id 6 `
  -o analysis\mes_command06_audit.json
py tools\audit_mes_command07.py <ELFIMAGE\mes.arc> `
  -o analysis\mes_command07_audit.json
py tools\audit_mes_command07.py <ELFIMAGE\mes.arc> --focus-start-index 200 `
  --focus-end-index 237 --focus-bank 0 --focus-record-limit 256 `
  -o analysis\mes_command07_fields_200_237.json
py tools\audit_mes_command07.py <ELFIMAGE\mes.arc> --command-id 8 `
  -o analysis\mes_command08_audit.json
py tools\audit_mes_def_routes.py <ELFIMAGE\mes.arc> `
  -o analysis\mes_def_route_audit.json
py tools\audit_mes_routine40_groups.py <ELFIMAGE\mes.arc> `
  --entry 43C.MES --address-entry 148 `
  -o analysis\mes_routine40_groups_43c.json
```

These outputs contain source-derived local data and must remain under an ignored
directory. Use `--all` on the text exporter only when a full local cache is
needed. The write-run and DEF audit scripts perform archive-wide structural
checks without emitting MES payloads or dialogue. Command-`0x03` audit v3
accepts repeated 16-bit `--focus-index` options and retains the source
identity, coordinate, covering pair, continuation, and decoded expression AST
for the complete requested set in one archive pass. It preserves request
order, removes duplicate indices, and reports requested indices with no writer
explicitly. One requested index also retains the v2 compatibility field.
Command-`0x04` audit v2 also
counts every written `state_u16` index; `--focus-index` retains only decoded
ASTs and coordinates for writes covering that index. Banked-write audit v3
similarly accepts a focus interval and optional bank. It keeps complete
per-index and per-entry counts while bounding detailed literal and
possible-dynamic records with `--focus-record-limit`; use zero for
aggregate-only output. These modes are useful for auditing the relative
bank-offset slots consumed by native banked expressions.

### `audit_mes_def_routes.py`

Audits the strict Content Core DEF envelope across the complete archive: one
literal command-`0x10` record, a forward target, a non-empty CP932 text-only
body ending in command `0x00` exactly at that target, and a marker-separated
chain ending at literal shared routine `40`. The report contains only entry
names, code-relative coordinates, IDs, counts, rejection reasons, and archive
fingerprints; it never emits option text. Use `--entry EVENTD08.MES` for a
single source check or `-o` for an atomic local JSON report.

Schema v3 also checks the script immediately after routine 40. It reports an
exact one-based result consumer only when every branch is a sequential
`state_u16[21] == 1..N-1` chain and retains the option entry coordinates without
dialogue. It separately recognizes a complete result-by-state gate matrix and
reports its gate storage, index, literal values, branches, and fallback without
promoting that matrix to playback. A mixed consumer that depends on native
secondary `state_u16[13]` is labeled explicitly and remains unresolved. EXE
audit v41 fixes that value as the one-based selected row of a second dynamic
record list. Audit v42 further fixes the first result as the key of a 16-byte
group descriptor and the engine's 8-byte-record to 4-byte-active-vector copy
and count update. Audit v44 identifies command `0x10` as the producer of those
8-byte records and fixes their first dword as active context pointer plus code
coordinate. It also fixes command `0x1B` as the evaluated-expression selector
and clear for groups `0..6`; its raw `+0x4B6D5` load is parser-relative
`+0x4B6D1` after the handler's `+4` object adjustment. The focused group audit
below establishes the stored 43C registrations and guard shapes, while live
guard provenance, native interaction, and gameplay use remain unresolved.
Single-definition paths receive no invented result value. Conditional or
nonliteral DEF construction and other noncanonical consumers remain rejected.
This is still a structural audit, not a generic native choice interpreter: the
native input producer, gate ownership, second-stage record list, and native
presentation effects remain unresolved.

### `audit_mes_routine40_groups.py`

Audits one address-table entry that constructs native routine-40 record
groups. Schema `kakyu_mes_routine40_group_route_audit/v4` records literal
command-`0x1B` group clears, command-`0x10` definition IDs and targets,
bounded command-`0x0B` state guards, empty groups, and the unique routine-40
terminal. It also joins the stored post-routine one-based slot-21/slot-13
dispatch to those group counts. It fails closed on nonliteral or duplicate group selectors,
registrations outside a group, invalid bodies, guard-target mismatches, or an
ambiguous terminal route. The output contains no option text or raw payload.

The authoritative `43C.MES` address entry 148 reports groups `0..6` with
registration counts `6,15,0,14,2,0,7`; groups 2 and 5 are explicitly empty.
Groups 1/3/6 have complete secondary dispatches of 15/14/7 values. Group 4
registers two rows but explicitly branches only for secondary result 1.
Result 2 reaches the common stored command-`0x0C` fallback at `0xA304`, whose
backward coordinate destination is `0x399F`. V4 identifies that coordinate as
address-table entry 127's constant-true fallthrough into the earlier
dispatcher. It also records the six exact command-`0x0E` target envelopes in
`43C_ASA.MES`, `44C.MES`, and `L_HOTEL2.MES`. Because the current EXE audit
confirms that command `0x0E` itself provides no callee coordinate or caller
restoration, these records remain host-activation evidence rather than a
playable entry-148 caller. The source-bound grouped-analysis contract validates
both the default `6,0,0,0,2,0,7` registry and the fully eligible registry.
Version 2 retains the exact explicit consumer entry for every available
secondary row and labels group-4 result 2 only as the common `0x399F` fallback;
it does not enter those coordinates. The contract still does not execute
native input, prove which state guards are true in a gameplay
session, or invent a meaning for the fallback; Event Player therefore keeps
normal playback fail-closed.

Content Core 0.199 additionally publishes a numeric reachability report for
the evaluated registry. The default/fully eligible 43C profiles produce 13/40
rows: 8/37 exact consumer coordinates, one shared stored fallback each, and
four/two empty-list `0xFFFF` boundaries. Group-4 result 2 is retained as
`0xA304 -> 0x399F`; no destination is executed. This closes the analyzer's
conditional second-stage coordinate gap while leaving native input, labels,
natural caller eligibility, and playback unresolved.

### `prove_mes_choice_group_authoring.py`

Builds the source-bound MW-05 prerequisite for choice-option editing:

```powershell
py tools\prove_mes_choice_group_authoring.py `
  <mes.arc> 43C.MES 148 <new-choice-proof.json>
```

Schema `kakyu_mes_choice_group_authoring_proof/v1` binds the exact container
and address-entry hashes, every command-`0x1B` clear and command-`0x10`
registration/body/return boundary, strict CP932 option-payload hashes, bounded
guards, the routine-40 terminal and physical resume, and the stored numeric
slot-21/slot-13 result matrix. It retains incomplete group-4 result 2 as the
stored default continuation rather than inventing a consumer. The proof is
JSON only and exports neither dialogue nor raw payload bytes. It does not run
native input, assign gameplay labels, or publish a changed MES.

### `plan_mes_choice_option_edit.py`

Builds a JSON-only MW-05 plan for one source-proved choice option:

```powershell
py tools\plan_mes_choice_option_edit.py `
  <mes.arc> 43C.MES <choice-proof.json> <operation.json> `
  <new-choice-option-plan.json>
```

Operation `replace_choice_option_cp932_same_length` selects the exact group and
zero-based definition ID, repeats the source payload SHA-256, and supplies
strict CP932 replacement text. V1 requires the replacement payload to have the
same byte length and binds the resulting instruction/body/entry hashes. The
choice-proof fingerprint, group topology, numeric result mapping, registration
target, return, routine-40 terminal, physical resume, and all bytes outside the
payload remain unchanged. The planner emits no MES bytes and rejects a stale
source hash, ambiguous row, unchanged text, NUL, unrepresentable text, length
change, unknown field, or changed proof/source pairing.

Content Core 0.251 independently consumes that JSON through
`mes_choice_option_edit_plan.gd`. Validate a generated plan headlessly with:

```powershell
godot --headless --path . --script `
  tools/content_suite/cli/validate_mes_choice_option_edit_plan.gd -- `
  <choice-option-plan.json>
```

The GDScript consumer rechecks JSON integer coordinates, all embedded byte
hashes and message/body assembly relationships, zero delta, the grouped-proof
fingerprint, numeric-result topology hash, routine-40 terminal, and physical
resume. It reads no source ARC and emits no MES bytes.

### `compile_mes_choice_option_edit.py`

Applies one validated same-length option plan to a new MES and publishes a
compact audit:

```powershell
py tools\compile_mes_choice_option_edit.py `
  <mes.arc> 43C.MES <choice-proof.json> <choice-option-plan.json> `
  <new-output.mes> <new-compile-audit.json>
```

The compiler changes only the selected payload range, preserves the complete
container/address table, and then rebuilds
`kakyu_mes_choice_group_authoring_proof/v1` from the output. Publication fails
unless every group/definition coordinate, result mapping, registration,
return, routine-40 terminal, and physical resume remains exact. Both outputs
must be new paths outside the source ARC directory; the source archive and
entry buffer are never modified.

Content Core 0.252 reopens the compiled output through the current GDScript
Phase 1-4 path:

```powershell
godot --headless --path . --script `
  tools/content_suite/cli/validate_mes_choice_option_compile.gd -- `
  <compiled.mes> <compile-audit.json>
```

The validator checks the output container and audit fingerprints, rebuilds the
analysis/alignment/handoff, redecodes the changed text instruction and exact
return, and requires the stored routine-40 terminal and physical resume bytes
to remain unique partitions. The grouped structure and result-mapping hashes
remain certificates from the Python output-proof rebuild; the GDScript path
does not execute native selection.

### `export_mes_framing_digest.gd` and `audit_mes_framing_equivalence.py`

Measure a decoder written in another language against the authoritative record
framing. Phase 1-4 authority is MA-09's measurement over the corpus rather than
the language that computes it, so moving that authority needs the measurement
repeated, not the code translated. Nothing else crosses the language line:
`validate_mes_analyzer_handoff.py` checks the handoff's schema, and
`audit_mes_decompiler_equivalence.py` compares one Python renderer against
another downstream of it.

Emit the authoritative framing first, one JSON object per entry:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/export_mes_framing_digest.gd -- `
  <ELFIMAGE-directory>\mes.arc <framing.jsonl>
```

Then measure Python against it:

```powershell
py tools\audit_mes_framing_equivalence.py --digest <framing.jsonl> `
  --arc <ELFIMAGE-directory>\mes.arc --json <report.json>
```

Both sides emit the same canonical line list - `i <start> <end>` per instruction
and `o <start> <end>` for a byte-preserving opaque remainder - so a mismatch
reduces to one coordinate and the opcode there. Regions are the container's own:
a non-empty bootstrap prefix, then the address-table entries in index order.

The report carries two measures. Sequential equivalence is the real gate and
stops at the first command with no grammar, so one gap marks a whole entry
divergent. Per-record agreement starts from each authoritative offset instead,
sees past that first failure, and ranks the missing commands by how many corpus
records each one blocks. `--require-equivalent` makes a divergence a non-zero
exit once the gap is expected to be closed; by default a divergence is reported
as a measurement, because the Python decoder documents itself as partial.

Neither tool writes to the archive, and the report holds coordinates and counts
only - no payload, dialogue or machine path.


### `validate_mes_analyzer_handoff.py`

Validates the language-neutral `kakyu_mes_analyzer_handoff/v1` emitted by
the Python analyzer or the GDScript reference producer. The handoff contains
reconstructable container bytes,
typed/opaque IR, references, CFGs, and optional analyzer call/trace evidence;
it excludes product UI fields. The Python validator checks the exact component
schemas and deterministic payload SHA-256 without reopening or reparsing the
source MES. Generate a focused handoff with the paired headless GDScript tool:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_analyzer_handoff.gd -- `
  <mes.arc> D_TALK00.MES offset:0x82f <handoff.json>
py tools\validate_mes_analyzer_handoff.py <handoff.json>
```

The output path must be outside the source archive directory. Older Python
MES projections remain supporting audit evidence and must establish exact
boundary/schema parity before replacing the current versioned handoff.

### `export_mes_analyzer_handoff.py`

Produces a complete signed v1 handoff directly from a read-only MES/LIB archive
entry, using Python without Godot. The actual producer is `python_phase1_4`.
Source-bound typed/opaque records, component schemas, compatibility metadata
and canonical transport are validated before atomic publication inside the
project. The source archive directory and source-file aliases cannot be output
targets; archive identity is rechecked before publication.

```powershell
py tools\export_mes_analyzer_handoff.py --arc <mes.arc> --entry D_TALK00.MES `
  --json analysis/python-dtalk-handoff.json
py tools\validate_mes_analyzer_handoff.py analysis/python-dtalk-handoff.json
```

This CLI exports empty CFG/call/trace arrays. The `build_handoff()` Python API
can retain supplied evidence after checking its schemas and CFG edge endpoints;
it does not generate that evidence. Use the GDScript focused exporter above when
an existing Godot-generated CFG is needed.

### `audit_mes_handoff_equivalence.py`

Compares the Python producer against a source-bound GDScript digest. The
default v1 report compares nine component targets. Complete comparison uses
report v2 and `--require-full-equivalent`, which requires every archive entry,
verified actual Python payloads and no explicit limit:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/export_mes_handoff_digest.gd -- `
  <mes.arc> analysis/handoff-digest.jsonl
py tools\audit_mes_handoff_equivalence.py --digest analysis/handoff-digest.jsonl `
  --arc <mes.arc> --json analysis/full-handoff-equivalence.json `
  --require-full-equivalent
```

The signed producer identity differs by language. Under the explicit
`producer_implementation_only/v1` policy, comparison changes only that field
in a verified copy and recomputes its hash. The report records the actual Python,
projected Python and reference GDScript payload/corpus hashes separately. The
exported Python artifact keeps its own producer identity and actual hash.

`--jobs N` (TD-40, 2026-10-03; default 1, the in-process path) compares the
entries on a pool of N worker processes. A worker receives one entry's bytes,
its digest row and its source identity and returns that entry's verdicts
(`compare_full_entry`/`compare_entry`, no shared state); the parent applies
`--limit` before dispatch, keeps the archive re-hash, collects the results in
digest order and folds every aggregate (per-component counters, the entry-hash
mismatches, the three corpus hashes, `full_payload.equivalent`) exactly as the
serial run does, so the JSON report, the printed lines and the exit code are
identical to `--jobs 1`; only the order entries *start* in is by payload size,
largest first. The validation registry runs the check with `--jobs
{python_jobs}` and gives it that many scheduler slots. Measured on this
machine: 2,301.7 s serial, 576.2 s at `--jobs 4`, with a byte-identical report
(file SHA-256 `4cdc9696...`).

### `validate_mes_analyzer_completion.py`

Validates the compact `kakyu_mes_analyzer_completion/v1` report emitted by
`audit_mes_analyzer_handoff_corpus.gd`. The GDScript audit builds and verifies
all 1,016 per-entry handoffs, fixes their ordered corpus fingerprint, and emits
only schemas, aggregate counts, supported typed forms, explicit native/opaque
boundaries, reference kinds, and unresolved-meaning policy. Python checks the
same corpus and completion fingerprints without reopening `mes.arc`:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_analyzer_handoff_corpus.gd -- `
  <mes.arc> <completion.json>
py tools\validate_mes_analyzer_completion.py <completion.json>
```

### `decompile_mes_handoff.py`

Consumes a verified `kakyu_mes_analyzer_handoff/v1` and emits deterministic
`kakyu_mes_decompiler_ir/v1` without reopening or reparsing the source MES.
Every typed instruction becomes a statement that retains its expression AST,
metadata, exact source range, raw identity, reference IDs, and any supplied CFG
node. Fail-closed tails remain explicit opaque statements. The output validator
requires the regions and nodes to partition all code bytes and reconstructs the
original container from its retained preamble plus ordered nodes:

```powershell
py tools\decompile_mes_handoff.py <handoff.json> <linear-ir.json>
```

The source form is the MD-01 baseline for later structuring. It deliberately
does not infer `if`, loop, dispatch, native meaning, or product UI data.

### `annotate_mes_decompiler.py`

Consumes a validated `kakyu_mes_decompiler_ir/v1` and emits deterministic
`kakyu_mes_semantic_annotation/v1` JSON. Every linear node retains its entry,
region, `[start,end)`, raw SHA-256, evidence status, and typed operation or
opaque-boundary token. Every source reference receives one canonical identity:
numeric code/state coordinates, raw-message coordinates, or literal resource
names. No dialogue is decoded and no character, place, event-role, or state
meaning is guessed:

```powershell
py tools\annotate_mes_decompiler.py `
  <linear-ir.json> <semantic-annotations.json>
```

The validator regenerates the complete annotation projection from the exact
linear input. Rehashed alias injection, unknown reference kinds, duplicate or
missing owners, and input fingerprint drift fail closed. This JSON is the first
MD-03 renderer input; human-readable pseudocode remains a separate output.

### `compose_mes_renderer_input.py`

Composes the validated linear IR, semantic annotations, control-flow proof, and
reducible-region proof into deterministic `kakyu_mes_renderer_input/v1` JSON:

```powershell
py tools\compose_mes_renderer_input.py `
  <linear-ir.json> <semantic-annotations.json> `
  <flow-proof.json> <region-proof.json> <renderer-input.json>
```

The result is standalone for the first renderer stage: it retains the complete
ordered linear nodes and references, annotation nodes and symbols, the entire
low-level label/goto fallback, proved reducible conditional structures, and a
source-map row for every linear node. Validation exactly regenerates the
composition and rejects input-family mismatch or rehashed output mutation.
Dispatch, natural-loop, cross-region-join, and call overlays are not promoted
by this core schema yet.

### `compose_mes_renderer_overlays.py`

Builds `kakyu_mes_renderer_input/v2` from the v1 source family plus validated
guard-chain, value-dispatch, predicate-dispatch, cross-region-join, and
call-family proofs:

```powershell
py tools\compose_mes_renderer_overlays.py `
  <linear-ir.json> <semantic-annotations.json> `
  <flow-proof.json> <region-proof.json> `
  <guard-proof.json> <value-proof.json> <predicate-proof.json> `
  <cross-region-join-proof.json> <call-family-proof.json> `
  <renderer-input-v2.json>
```

Every complete proof and rejection is embedded. Only accepted rows receive
overlay records, and each overlay must reverse to at least one retained linear
node through an exact fallback label or direct node ID. The v1 low-level
fallback remains unchanged. Natural-loop overlays and pseudocode are later
MD-03 layers.

### `compose_mes_renderer_loops.py`

Builds `kakyu_mes_renderer_input/v3` by adding the validated library audit,
shared-call return proof, execution-fallthrough proof, and natural-loop proof
to the complete v2 renderer family:

```powershell
py tools\compose_mes_renderer_loops.py `
  <linear-ir.json> <semantic-annotations.json> `
  <flow-proof.json> <region-proof.json> `
  <guard-proof.json> <value-proof.json> <predicate-proof.json> `
  <cross-region-join-proof.json> <call-family-proof.json> `
  <library-audit.json> <shared-call-proof.json> `
  <execution-fallthrough-proof.json> <natural-loop-proof.json> `
  <renderer-input-v3.json>
```

Every proved natural loop receives one overlay owning its retained linear
envelope. Supporting total-return and execution proofs, all rejections, exits,
and the complete label/goto fallback remain embedded. The schema never guesses
`while`/`for`; a text renderer may display the proven `natural_loop` token and
must preserve the fallback coordinates.

### `render_mes_pseudocode.py`

Consumes `kakyu_mes_renderer_input/v3` and emits deterministic
`kakyu_mes_pseudocode/v1` JSON. An optional text file projects the exact same
ordered lines:

```powershell
py tools\render_mes_pseudocode.py `
  <renderer-input-v3.json> <pseudocode.json> `
  --text-output <optional-pseudocode.txt>
```

Every node line owns one original linear node and exact source range. Proved
structures and overlays have multi-node source rows; entry/region headings are
the only intentionally source-free lines. Messages remain `message@offset`,
semantic aliases remain null, and the renderer uses explicit branch/goto,
boundary, and proved-overlay tokens without inventing high-level loop or
dispatch syntax. The JSON records both payload and derived-text SHA-256 values.

### `audit_mes_decompiler_equivalence.py`

Consumes a matching `kakyu_mes_renderer_input/v3` and
`kakyu_mes_pseudocode/v1` pair and emits a deterministic
`kakyu_mes_decompiler_equivalence_audit/v1`:

```powershell
py tools\audit_mes_decompiler_equivalence.py `
  <renderer-input-v3.json> <pseudocode.json> <equivalence-audit.json>
```

The audit requires a complete contiguous source partition, unique region-node
ownership, one node line per source node, one marker per proved structure and
overlay, and reversible source rows. It publishes opaque nodes, unresolved
control/surface constructs, and proof-rejection evidence paths without
inventing meanings. V1 audits one entry; a separate aggregate runner owns
corpus closure.

### `audit_mes_decompiler_corpus.py`

Consumes an ordered, hash-bound `kakyu_mes_decompiler_handoff_spool/v1`
manifest and matching `kakyu_mes_library_audit/v17`, runs the complete Phase 5
chain one handoff at a time, and emits compact
`kakyu_mes_decompiler_corpus_audit/v1` JSON:

```powershell
py tools\audit_mes_decompiler_corpus.py `
  <handoff-spool-manifest.json> <library-audit.json> <corpus-audit.json> `
  --jobs 4
```

The spool manifest may name only sibling files and binds archive order, entry
name, source archive SHA-256, and every handoff fingerprint. The aggregate
retains no raw MES, renderer document, pseudocode text, or absolute path. It
records the five major intermediate fingerprints per entry, summed structural
and unresolved coverage, and corpus-wide source/CFG/rendering invariants. The
source-bound spool must be generated outside Git before an authoritative run.

The runner validates each newly produced document once, then reuses that result
only when nested proof/composer layers receive the same immutable Python object,
schema, and retained hash during the same entry. The cache is destroyed between
entries. Standalone validators and mutation diagnostics remain uncached, and a
focused regression requires cached and uncached entry rows to be identical.
Independent entries may run in one to four worker processes. Each worker owns
its validation-reuse scope, the parent restores manifest order before hashing,
and the worker count is intentionally absent from the report so serial and
parallel runs produce byte-identical JSON. The command-line default uses at
most four logical CPUs; pass `--jobs 1` on a memory-constrained host. Progress
is flushed every 25 completed entries and at corpus completion so a redirected
headless run remains observable.

Generate that spool with the matching headless Content Core producer:

```powershell
godot --headless --path . `
  --script res://tools/content_suite/cli/export_mes_decompiler_handoff_spool.gd -- `
  <mes.arc> <new-output-directory> <max-entries-or-0>
```

The output directory must not already exist and cannot be inside the project or
the source ARC directory. The producer emits one whole-entry confirmed-flow CFG
handoff per selected MES/LIB entry, audits every registered library routine,
rehashes the source, then writes the path-free manifest last. A positive limit
creates an explicitly partial spool; `0` selects all eligible entries. Keep the
generated handoffs and library audit outside Git.

### `prepare_mes_editable_ir.py`

Wraps one validated `kakyu_mes_decompiler_ir/v1` JSON document in the strict
`kakyu_mes_editable_ir/v1` Phase 6 boundary:

```powershell
py tools\prepare_mes_editable_ir.py <linear-ir.json> <editable-ir.json>
```

The complete decompiler source remains embedded, immutable, and fingerprinted.
The ordered operation array is empty in this baseline. Unknown fields or any
operation fail closed even when the wrapper is rehashed. Output publication is
exclusive and never replaces an existing file.

### `plan_mes_inline_script_name_edit.py`

Builds the JSON-only first MW-05 nested-call plan for one same-length inline
script target:

```powershell
py tools\plan_mes_inline_script_name_edit.py `
  <editable-ir.json> <operation.json> <new-plan.json>
```

The operation kind is `replace_inline_script_name` and supplies the exact
envelope coordinate, containing-node SHA-256, indexed resource-reference ID,
and replacement name. Selector 2 remains `.LIB`; selector 3 remains `.MES`.
The planner accepts a strict typed instruction or its exact indexed bounded
envelope inside one opaque owner, freezes all bytes outside the name, checks no
replacement resource, and never publishes MES bytes.

### `compile_mes_inline_script_name_edit.py`

Consumes one matching inline-script-name plan and exclusively publishes a new
same-size MES plus compact audit:

```powershell
py tools\compile_mes_inline_script_name_edit.py `
  <editable-ir.json> <plan.json> <new-output.mes> <new-audit.json>
```

It changes only the planned name bytes, preserves the parent typed/opaque node
extent, selector prefix, double-NUL suffix, preamble, and address table, and
reopens the output container. The tool does not relocate records, look up the
replacement entry, execute the nested script, or claim native compatibility.

### Inline script name Godot validators

Validate a Python plan, then independently reopen a compiled output through the
current Phase 1-4 Content Core contracts:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_inline_script_name_edit_plan.gd -- `
  <plan.json>

& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_inline_script_name_compile.gd -- `
  <compiled.mes> <compile-audit.json>
```

The reopen must retain the source typed/opaque partition and reproduce one
exact inline execution envelope plus its strict or bounded resource reference
with the replacement name. Neither validator executes the nested target.

### `plan_mes_shared_routine_call_edit.py`

Builds a JSON-only MW-05 preflight for one exact typed command-`0x1D` call:

```powershell
py tools\plan_mes_shared_routine_call_edit.py `
  <editable-ir.json> <shared-call-return-proof.json> <library-audit.json> `
  <operation.json> <plan.json>
```

The operation selects the call by code-relative `source_offset` and exact
`instruction_raw_sha256`, then supplies a replacement `routine_id`. V1 accepts
only an unambiguous one-byte literal (`0..127`). The source call must have a
unique physical resume node and a source-bound total-return certificate; the
replacement routine must have its own total-return certificate in the same
`LIBLARY.LIB` audit. The result binds both callee extents and every instruction
byte but publishes no MES file and makes no original-engine compatibility
claim.

Compile a validated plan into a new same-size MES and compact JSON audit:

```powershell
py tools\compile_mes_shared_routine_call_edit.py `
  <editable-ir.json> <shared-call-return-proof.json> <library-audit.json> `
  <plan.json> <new-output.mes> <compile-audit.json>
```

The assembler refuses existing outputs, relocation, or any byte change outside
the selected literal. It reopens the container, preserves the address table and
the exact physical-resume node bytes, and carries both callee certificates into
the audit. It does not execute either routine or claim original-engine
compatibility.

Validate the JSON plan independently, then reopen the compiled MES through the
current GDScript Phase 1-4 contracts:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_shared_routine_call_edit_plan.gd -- `
  <plan.json>

& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_shared_routine_call_compile.gd -- `
  <compiled.mes> <compile-audit.json>
```

The reopen does not execute either library routine. It requires the edited
command-`0x1D` literal to redecode exactly and preserves the unique physical
resume node plus both total-return certificates.

### `prove_mes_registered_definition_registry.py`

Builds the source-bound registry input for the next MW-05 registered-DEF edit:

```powershell
py tools\prove_mes_registered_definition_registry.py `
  <mes.arc> <definition-entry.mes> <new-registry-proof.json>
```

The proof follows only the instruction-aligned zero-start path, treats each
literal command-`0x14` skip as an unexecuted registered body, and binds the
registration bytes plus exact `[body_start, skip_target)` bytes. It stops at
the path's command-`0x00` return. Command-`0x10` remains a separate
choice-definition-body family and is never promoted into this registry. The
output is JSON only, contains no absolute path, and is published exclusively.

### `plan_mes_registered_definition_call_edit.py`

Builds a JSON-only plan for one exact typed command-`0x11` invocation:

```powershell
py tools\plan_mes_registered_definition_call_edit.py `
  <editable-ir.json> <call-family-proof.json> <registry-proof.json> `
  <operation.json> <new-plan.json>
```

The operation selects the call by code-relative `source_offset` and exact
instruction SHA-256, then supplies a replacement `selector`. V1 accepts only
an unambiguous one-byte literal. The caller must have one exact physical resume
in the call-family proof, and both selectors must have unique command-`0x14`
body boundaries in the same source-archive registry proof. The planner executes
neither body, emits no return edge, treats command-`0x10` as a separate choice
family, and publishes no MES bytes.

### `compile_mes_registered_definition_call_edit.py`

Assembles one validated registered-DEF invocation plan into a new MES and a
compact audit:

```powershell
py tools\compile_mes_registered_definition_call_edit.py `
  <editable-ir.json> <call-family-proof.json> <registry-proof.json> `
  <plan.json> <new-output.mes> <new-compile-audit.json>
```

The compiler revalidates every source input, changes only the one-byte
command-`0x11` selector, and reopens the output container before publication.
The audit binds the unchanged address table, exact physical resume bytes, and
both command-`0x14` registry body certificates without executing either body
or inferring a return edge. Existing output paths and relocation are refused.

### `content_suite/validate_mes_registered_definition_call_edit_plan.gd`

Validates the Python JSON plan through an independent GDScript consumer:

```powershell
godot --headless --path . --script `
  tools/content_suite/cli/validate_mes_registered_definition_call_edit_plan.gd -- `
  <plan.json>
```

It rechecks the fingerprint, literal envelope, physical resume, and both exact
registry body certificates. It does not read or publish MES bytes.

### `content_suite/validate_mes_registered_definition_call_compile.gd`

Reopens the changed MES and compile audit through the current GDScript Phase
1-4 path:

```powershell
godot --headless --path . --script `
  tools/content_suite/cli/validate_mes_registered_definition_call_compile.gd -- `
  <compiled.mes> <compile-audit.json>
```

The validator rebuilds the container, analysis, record alignment, and analyzer
handoff; requires the replacement command-`0x11` literal to redecode exactly;
and retains the caller/resume partition plus both unexecuted command-`0x14`
registry certificates.

### `compile_mes_noop.py`

Compiles the operation-free editable IR to a byte-identical new MES and
publishes its compact audit last:

```powershell
py tools\compile_mes_noop.py `
  <editable-ir.json> <new-output.mes> <new-compile-audit.json>
```

The compiler reconstructs the exact preamble and ordered node bytes, reopens
the container/address table, compares container, bytecode, and preamble hashes,
and retains typed, region, node, and opaque coverage in
`kakyu_mes_noop_compile_audit/v1`. Inputs and both outputs must be distinct;
existing outputs are refused. No edit or relocation is accepted yet.

### `content_suite/validate_mes_noop_compile.gd`

Independently reopens a Python no-op compiler output through the current
GDScript Phase 1-4 parser, analysis index, record-alignment audit, and analyzer
handoff:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_noop_compile.gd -- `
  <new-output.mes> <new-compile-audit.json>
```

The validator requires the exact `kakyu_mes_noop_compile_audit/v1` contract,
cross-language fingerprint agreement, identical container/bytecode/preamble
hashes, and matching region and typed/opaque node coverage. It emits the
deterministic `kakyu_mes_noop_reopen_audit/v1` fingerprint to stdout and never
modifies either input.

### `audit_mes_noop_compile_corpus.py`

Consumes a completed `kakyu_mes_decompiler_handoff_spool/v1`, validates and
lifts one source-bound entry at a time, and publishes byte-identical MES/audit
pairs plus a completion manifest written last:

```powershell
py tools\audit_mes_noop_compile_corpus.py `
  <handoff-spool-directory> <new-compile-spool-directory> --jobs 4
```

The output directory must not exist. Worker completion order does not change
archive-order output, and process counts are bounded to 1–4. A failed partial
run has no completion manifest.

### `content_suite/audit_mes_noop_reopen_corpus.gd`

Reopens every completed corpus output through the current GDScript Phase 1–4
contract and rehashes the authoritative archive before and after:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/audit_mes_noop_reopen_corpus.gd -- `
  <compile-spool-directory> <mes.arc>
```

It rejects unknown manifest fields, unsafe filenames, changed per-entry hashes
or coverage, failed compile audits, and any source-archive change. Generated
spools are disposable local evidence and must stay outside Git.

### `plan_mes_message_relocation.py`

Consumes a validated `kakyu_mes_editable_ir/v1` plus one strict
`replace_message` operation and publishes a new JSON relocation plan:

```powershell
py tools\plan_mes_message_relocation.py `
  <editable-ir.json> <operation.json> <new-plan.json>
```

The operation binds the code-relative message offset to its exact source byte
hash and requests variable-length CP932 text with the native double-byte
projection preserved. The planner computes the node delta, following
node/region counts, every changed address-table cell, and old/new coordinates
for affected references. It never publishes MES bytes. Shifted opaque records
and encoded code targets become explicit blockers, so only a blocker-free plan
can advance to MW-02 assembly.

### `compile_mes_message_relocation.py`

Consumes the editable source and one matching blocker-free relocation plan,
then publishes a new changed MES and compact audit:

```powershell
py tools\compile_mes_message_relocation.py `
  <editable-ir.json> <plan.json> <new-output.mes> <new-audit.json>
```

It rewrites the planned typed message node and exact address-table cells,
preserves all code bytes before and after that node, reopens the output
container, and refuses existing outputs. Native-engine compatibility remains
unverified.

### `content_suite/validate_mes_message_compile.gd`

Validates the Python audit and independently reopens the changed MES through
the current GDScript Phase 1–4 contracts:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_message_compile.gd -- `
  <compiled.mes> <compile-audit.json>
```

The replacement message must reindex at its planned start/end with the exact
replacement byte hash, and the output region/node/opaque partition must match
the compile audit.

### `plan_mes_utf8_overlay.py`

Consumes the editable source and one explicit remake-only UTF-8 operation:

```powershell
py tools\plan_mes_utf8_overlay.py `
  <editable-ir.json> <utf8-overlay-operation.json> <new-plan.json>
```

The operation kind is `replace_message_utf8_overlay`, encoding is `utf8`,
compatibility is `remake_only`, and container policy is
`do_not_assemble_mes`. The output contains one source-hash-bound
`kakyu_mes_text_overlay_entry/v1` document. It never emits MES bytes and rejects
an original-compatible label or assembly request.

### `content_suite/validate_mes_utf8_overlay_plan.gd`

Validates the Python plan and optionally rechecks its source ARC and entry:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_utf8_overlay_plan.gd -- `
  <plan.json> [<mes.arc>]
```

The same validated plan can be passed to
`KakyuOverlayPackage.stage_mes_utf8_overlay_plan()`, which routes it through the
existing atomic remake-projection publication and reopen path without
assembling a changed MES container.

### `plan_mes_control_target_relocation.py`

Consumes an editable IR and its exact message-relocation plan, resolves
confirmed command-`0x0B` and command-`0x0C` target operands plus the exact
trailing command-`0x10` definition-skip `u32`, and publishes a JSON-only patch
plan. Schema v2 requires the command-`0x10` scan even when no such target moves:

```powershell
py tools\plan_mes_control_target_relocation.py `
  <editable-ir.json> <message-plan.json> <new-control-plan.json>
```

Unsupported blockers remain fail closed. The plan never publishes MES bytes.

### `compile_mes_control_target_relocation.py`

Applies one validated message relocation and all exact target patches, then
reopens and exclusively publishes a new MES plus compact audit:

```powershell
py tools\compile_mes_control_target_relocation.py `
  <editable-ir.json> <message-plan.json> <control-plan.json> `
  <new-output.mes> <new-audit.json>
```

It rejects stale or overlapping operands, out-of-range targets, remaining
blockers, and existing outputs. Original-engine compatibility is not claimed.

### `content_suite/validate_mes_control_target_compile.gd`

Validates the Python audit and independently reopens the output through the
current GDScript Phase 1-4 contracts:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_control_target_compile.gd -- `
  <compiled.mes> <compile-audit.json>
```

Every relocated operand must reappear at one aligned, in-code typed instruction
start, and the edited message must retain its planned range and byte hash.
Branch and continuation targets are rechecked through the reference index;
command-`0x10` definition skips are independently decoded from the instruction's
trailing four bytes. The normal strict analyzer remains the default. Reopen may
use the explicitly labeled `structural_relocation` analysis mode only when its
typed/opaque partition exactly matches the compile audit; that mode preserves
record boundaries without claiming semantics for an expression rejected by the
strict decoder.

### `plan_mes_address_entry_insert.py`

Consumes a validated editable IR and one `insert_address_entry` operation. The
operation binds the owning address-table entry, one code-relative target, and
the exact target-instruction SHA-256. V1 accepts only a unique non-structural
typed instruction start strictly inside that existing entry:

```powershell
py tools\plan_mes_address_entry_insert.py `
  <editable-ir.json> <operation.json> <new-plan.json>
```

The plan inserts one sorted four-byte table cell, increases the future physical
code offset by four, and leaves the bytecode and every code-relative coordinate
unchanged. It reports the nodes and references whose region ownership would
move to the new entry, but publishes no MES bytes and does not claim that a
native host selects the new entry.

### `content_suite/validate_mes_address_entry_insert_plan.gd`

Validates the transported JSON contract independently through Godot 4.7:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_address_entry_insert_plan.gd -- `
  <address-entry-insert-plan.json>
```

The validator rejects fractional coordinates, an existing/edge boundary,
non-strict evidence, changed little-endian cell bytes, stale fingerprints, and
unknown fields. It validates a plan only; compilation and changed-MES reopen
remain a separate MW-06 step.

### `compile_mes_address_entry_insert.py`

Consumes one matching editable IR and address-entry insertion plan, reconstructs
the source container, inserts exactly one table cell, and exclusively publishes
a new MES plus compact audit:

```powershell
py tools\compile_mes_address_entry_insert.py `
  <editable-ir.json> <address-entry-plan.json> `
  <new-output.mes> <new-audit.json>
```

The entry count and physical code offset each increase once, by one cell and
four bytes respectively. The bytecode hash, code size, code-relative targets,
and source buffer remain unchanged. Existing output paths, stale plans, changed
table geometry, and audit-first or partial publication are rejected.

### `content_suite/validate_mes_address_entry_insert_compile.gd`

Reopens the Python output through the current Godot Phase 1-4 contracts:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_address_entry_insert_compile.gd -- `
  <compiled.mes> <compile-audit.json>
```

The validator rehashes the container/table/bytecode, checks the previous and
new regions meet at the inserted coordinate, requires that coordinate to decode
as one typed intro in the new entry, and preserves the complete source node
partition. This proves remake structural reopen, not original-engine selection
or compatibility.

### `plan_mes_control_target_edit.py`

Consumes one validated editable IR and one `retarget_control_flow` operation.
The operation selects either an indexed command-`0x0B` false target or a
command-`0x0C` continuation by source coordinate, full instruction hash, and
reference kind, then binds a different unique typed instruction start and its
hash:

```powershell
py tools\plan_mes_control_target_edit.py `
  <editable-ir.json> <operation.json> <new-plan.json>
```

The plan preserves the source instruction length and every byte except the
four-byte little-endian target operand. Conditional plans also hash the exact
expression bytes before that trailing operand; continuation plans require the
fixed five-byte command-plus-`u32` form. Unaligned, opaque, structural-only,
unchanged, stale, multiply indexed, or out-of-code targets are rejected. The
planner emits JSON only and does not claim native execution compatibility.

### `content_suite/validate_mes_control_target_edit_plan.gd`

Validates the transported plan independently through Godot 4.7:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_control_target_edit_plan.gd -- `
  <control-target-edit-plan.json>
```

The validator reconstructs both target operands and the complete source/output
instruction slices, requires identical prefix and suffix bytes, rehashes the
conditional expression when present, and rejects fractional coordinates,
unknown fields, or stale fingerprints. Compilation and changed-MES reopen are
the next MW-06 subgate.

### `compile_mes_control_target_edit.py`

Consumes the matching editable IR and target-edit plan, reconstructs the exact
source container, replaces only the planned four-byte operand, and exclusively
publishes a new MES plus compact audit:

```powershell
py tools\compile_mes_control_target_edit.py `
  <editable-ir.json> <control-target-plan.json> `
  <new-output.mes> <new-audit.json>
```

The compiler requires a nonempty exact diff wholly inside that operand. It
preserves file size, entry table, code offset, instruction length, condition or
transfer prefix, all following code, and the source buffer. Stale plans,
existing outputs, or any unplanned changed byte fail closed.

### `content_suite/validate_mes_control_target_edit_compile.gd`

Validates the compact audit and independently rebuilds the changed MES through
the current Godot Phase 1-4 contracts:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_control_target_edit_compile.gd -- `
  <compiled.mes> <compile-audit.json>
```

The edited command, unchanged conditional expression when present, replacement
typed target, and exactly one indexed branch/continuation reference must all
reappear at their audited coordinates. This proves current-remake structural
reopen, not original-engine execution or gameplay correctness.

### `plan_mes_state_literal_edit.py`

Consumes a validated editable IR plus one exact
`replace_state_write_literal` operation and publishes a JSON-only plan:

```powershell
py tools\plan_mes_state_literal_edit.py `
  <editable-ir.json> <operation.json> <new-plan.json>
```

The operation supplies the code-relative typed instruction start, its source
SHA-256, a write-run pair index, and the replacement numeric value. V1 accepts
only one canonical literal expression of the same 8-, 16-, or 32-bit width;
8-bit values are deliberately limited to unambiguous `0x00..0x7F` literal
tokens. The plan retains the numeric storage/destination, continuation byte,
and exact replacement instruction bytes. It never publishes an MES container,
does not assign a semantic name to a numeric state slot, and does not claim
original-engine compatibility.

### `content_suite/validate_mes_state_literal_edit_plan.gd`

Validates the Python JSON plan independently through Godot 4.7 without reading
or publishing MES bytes:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_state_literal_edit_plan.gd -- `
  <state-literal-plan.json>
```

It rejects fractional JSON coordinates, unknown fields, ambiguous 8-bit
tokens, changed destination or continuation data, mismatched literal hashes,
and any replacement that touches bytes outside the selected expression.

### `compile_mes_state_literal_edit.py`

Consumes an editable IR and its exact validated state-literal plan, then
publishes a new MES plus compact audit:

```powershell
py tools\compile_mes_state_literal_edit.py `
  <editable-ir.json> <state-plan.json> <new-output.mes> <new-audit.json>
```

The assembler replaces only the planned same-length instruction bytes. It
requires the source slice to match, preserves the container size, entry count,
address table, preamble, code prefix, and code suffix, reopens the output, and
refuses existing output paths. The source container is never modified and
original-engine compatibility remains unverified.

### `content_suite/validate_mes_state_literal_compile.gd`

Validates the Python compile audit and independently reopens the changed MES
through the current GDScript Phase 1-4 contracts:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_state_literal_compile.gd -- `
  <compiled.mes> <compile-audit.json>
```

The output hash and layout must match the audit, the typed write must reappear
at the same boundary, and its selected pair must decode as the planned literal
value and width. Unknown/fractional audit data and any mismatched output bytes
are rejected.

### `plan_mes_condition_literal_edit.py`

Consumes a validated editable IR plus one exact
`replace_condition_literal` operation and publishes a JSON-only plan:

```powershell
py tools\plan_mes_condition_literal_edit.py `
  <editable-ir.json> <operation.json> <new-plan.json>
```

The operation supplies the code-relative start and SHA-256 of a typed
command-`0x0B` branch, the exact AST literal token offset, and its replacement
numeric value. V1 accepts canonical 8-, 16-, or 32-bit tokens only, preserves
the token width and instruction length, and binds both the condition `0xFF`
terminator and the indexed trailing little-endian false-target operand. It
rejects ambiguous 8-bit tokens, missing or duplicate false-target evidence,
and any replacement that changes another byte. The tool emits no MES bytes,
does not name numeric state coordinates, and does not claim native-engine
compatibility.

### `content_suite/validate_mes_condition_literal_edit_plan.gd`

Validates the Python JSON plan independently through Godot 4.7 without reading
or publishing MES bytes:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_condition_literal_edit_plan.gd -- `
  <condition-literal-plan.json>
```

It rejects fractional JSON coordinates, unknown fields, stale hashes,
noncanonical or width-changing literal tokens, changed condition slices or
terminators, mismatched false-target values, and any replacement instruction
that changes bytes outside the selected literal.

### `compile_mes_condition_literal_edit.py`

Consumes an editable IR and its exact validated condition-literal plan, then
publishes a new MES plus compact audit:

```powershell
py tools\compile_mes_condition_literal_edit.py `
  <editable-ir.json> <condition-plan.json> `
  <new-output.mes> <new-audit.json>
```

The assembler replaces only the planned same-length instruction bytes. It
rebinds the source slice, preserves container size, entry count, address table,
preamble, code prefix/suffix, condition terminator, and false-target operand,
then reopens the output and refuses existing output paths. The source container
is never modified and original-engine compatibility remains unverified.

### `content_suite/validate_mes_condition_literal_compile.gd`

Validates the Python compile audit and independently reopens the changed MES
through the current GDScript Phase 1-4 contracts:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_condition_literal_compile.gd -- `
  <compiled.mes> <compile-audit.json>
```

The output hash and layout must match the audit. The typed command-`0x0B`
branch, selected AST literal value/width, condition hash and terminator,
four-byte false-target operand, and unique indexed false-target reference must
all reappear at their retained boundaries. Unknown/fractional audit data and
any changed output bytes are rejected.

### Control-body edit planning, compilation, and semantic diff

Plan one exact strict-typed body copy or removal, then compile the blocker-free
plan into a new MES and compact audit:

```powershell
py tools\plan_mes_control_body_edit.py `
  <editable-ir.json> <operation.json> <new-plan.json>

py tools\compile_mes_control_body_edit.py `
  <editable-ir.json> <plan.json> <new-output.mes> <new-compile-audit.json>
```

The plan inventories every affected address cell, region, node, reference,
encoded control target, CFG coordinate, call/trace row, and opaque boundary.
V1 fails closed on semantic target ambiguity, shifted opaque content, or
call/trace evidence it cannot relocate exactly. The compiler accepts only an
assembly-ready plan, rewrites only the enumerated cells/operands, publishes new
files exclusively, and does not claim original-engine compatibility.

Reopen the compiled file through the current Godot Phase 1-4 analyzer and
export the ordinary language-neutral handoff:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/export_mes_control_body_edit_handoff.gd -- `
  <compiled.mes> <compile-audit.json> <new-output-handoff.json>
```

The exporter first validates the compile audit and complete changed output,
then writes JSON to a new path and verifies the exact serialized bytes after
reread. It never modifies the compiled MES.

Build the MW-07 exact semantic source/output comparison and validate its
cross-language transport contract:

```powershell
py tools\diff_mes_control_body_semantics.py `
  <editable-ir.json> <compile-audit.json> <output-handoff.json> `
  <new-semantic-diff.json>

& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/validate_mes_semantic_diff.gd -- `
  <semantic-diff.json>
```

`kakyu_mes_semantic_diff/v1` independently reconstructs expected output bytes,
maps every source and output IR node, verifies rebuilt target references, and
requires every unrelated typed node and every opaque node to survive exactly.
The initial v1 family is `control_body_edit`; the contract intentionally stays
open for the other Phase 6 compile-audit families.

For same-layout state-literal, condition-literal, resource-name,
inline-script-name, shared-routine-call, registered-definition-call, and
explicit-control-target outputs, plus same-length choice-option outputs, export
and compare with the v2 path:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/export_mes_byte_patch_handoff.gd -- `
  <compiled.mes> <compile-audit.json> <new-output-handoff.json>

py tools\diff_mes_byte_patch_semantics.py `
  <editable-ir.json> <compile-audit.json> <output-handoff.json> `
  <new-semantic-diff.json>
```

The exporter selects the family-specific compile/reopen contract before
emitting the standard analyzer handoff. `kakyu_mes_semantic_diff/v2` requires
identical layout and node boundaries, one exact same-length patch, a rebuilt
literal, resource-reference, or code-reference-target assertion, and complete
unrelated-node preservation. Choice options use a typed CP932 payload-hash
assertion without copying option text into the diff. Each family is bound to
one patch role and assertion kind. A bounded inline edit may explicitly patch
one opaque owner; every other opaque node must remain exact.

For a compiled MW-06 address-entry insertion, use the same generic changed-file
handoff exporter and the dedicated v3 diff producer:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/export_mes_byte_patch_handoff.gd -- `
  <compiled.mes> <address-entry-compile-audit.json> `
  <new-output-handoff.json>

py tools\diff_mes_address_entry_semantics.py `
  <editable-ir.json> <address-entry-compile-audit.json> `
  <output-handoff.json> <new-semantic-diff.json>
```

`kakyu_mes_semantic_diff/v3` permits exactly one inserted four-byte address
cell and the resulting region repartition. The code stream, node boundaries,
raw node bytes, typed statements, and numeric reference coordinates must stay
exact. Node `region`, resource/message `region`, and code-reference
`target_region` are derived ownership metadata, so v3 validates them against
the new output regions and records their deterministic hashes instead of
mistaking the expected reassignment for a semantic code change. Validate v3
with the same `validate_mes_semantic_diff.gd` command shown above.

For variable-length typed messages, the generic exporter also accepts either
`kakyu_mes_message_compile_audit/v1` or
`kakyu_mes_control_target_compile_audit/v1`. Produce and validate v4 with:

```powershell
& <godot-console> --headless --path . --script `
  res://tools/content_suite/cli/export_mes_byte_patch_handoff.gd -- `
  <compiled.mes> <message-or-control-compile-audit.json> `
  <new-output-handoff.json>

py tools\diff_mes_message_relocation_semantics.py `
  <editable-ir.json> <message-or-control-compile-audit.json> `
  <output-handoff.json> <new-semantic-diff.json>
```

`kakyu_mes_semantic_diff/v4` verifies the old/new CP932 payload by typed owner,
length, and SHA-256 only; it does not retain either text. It independently
reconstructs the complete output from the replacement owner exposed by the
hash-bound handoff, every audited target operand, and every relocated address
cell. All other nodes must map once with exact bytes, and every non-target
reference must equal the deterministic coordinate relocation. This covers
ordinary variable-length messages and typed choice owners structurally. The
source-bound 43C.MES choice regression must use its explicitly labeled
`structural_relocation` analyzer handoff, reach zero relocation blockers, and
retain the independent grouped-choice proof; no native input or execution
compatibility is implied.

### `prove_mes_control_flow.py`

Consumes validated `kakyu_mes_decompiler_ir/v1` and emits
`kakyu_mes_control_flow_proof/v1`. It promotes conditional and continuation
transfers only when the retained statement operands and confirmed graph targets
agree exactly. Every supplied edge is owned once. Unconfirmed or mismatched
shapes remain `unresolved_transfer`; bounded-graph leaves remain
`unexpanded_transfer_anchor`; opaque stops remain `boundary_anchor`:

```powershell
py tools\prove_mes_control_flow.py <linear-ir.json> <flow-proof.json>
```

The proof is the MD-02 transfer foundation, not a claim that `if` bodies,
loops, dispatch, or call/return regions are already recovered.

### `emit_mes_low_level_control.py`

Consumes `kakyu_mes_control_flow_proof/v1` and emits the deterministic fallback
`kakyu_mes_low_level_control_ir/v1`. Every graph node receives one stable
code-offset label and one statement. Proved conditionals and continuations use
explicit labels; boundaries, unresolved transfers, and expansion leaves retain
separate statement kinds and cannot disappear during later structuring:

```powershell
py tools\emit_mes_low_level_control.py <flow-proof.json> <control-ir.json>
```

The output groups labels by source region and graph depth, but deliberately
does not call those groups reducible `if` or loop regions.

### `prove_mes_if_regions.py`

Consumes a matching linear IR and control-flow proof, regenerates the labeled
fallback, and emits `kakyu_mes_reducible_region_proof/v2`. A forward
same-region conditional becomes `if_then` or two-arm `if_else` only after exact
intervening-byte, per-arm single-entry, acyclic reachability, complete-body,
and single-join checks. Rejected and cross-region conditions retain their
label/goto representation:

```powershell
py tools\prove_mes_if_regions.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json>
```

This is a bounded MD-02 promotion; it does not yet infer cross-region
conditions, loops, dispatch, or call/return regions.

### `prove_mes_cross_region_joins.py`

Consumes matching linear, transfer, and reducible-condition proofs and emits
`kakyu_mes_cross_region_join_proof/v1`. It considers only conditional gotos
whose source/targets cross source regions. A relationship is recorded only
when both arms reach one unique nearest join on every bounded path and neither
arm has an external graph or confirmed code-reference entry. It binds the
complete fallback fingerprint, references the participating statement IDs,
and does not promote the relationship to `if` syntax:

```powershell
py tools\prove_mes_cross_region_joins.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json> `
  <cross-region-joins.json>
```

Non-converging, cyclic, incomplete, ambiguous, or externally entered paths
remain explicit rejected conditionals. The authoritative focused
`D_TALK00.MES` graph has eight cross-region candidates and no total join, so
all eight correctly remain low-level fallback.

### `prove_mes_natural_loops.py`

Consumes matching linear, transfer, reducible-condition, execution-fallthrough,
shared-call, and library-audit proofs and emits
`kakyu_mes_natural_loop_proof/v2`. It considers only same-region backward
gotos in a bounded-complete graph, computes dominance on the bounded-root
reachable subgraph, groups multiple latches by header, excludes non-header
entries, and requires an exact non-opaque linear envelope. Exit edges and the
complete label/goto fallback remain explicit; the proof does not guess
`while`, `do`, or `for` surface syntax:

```powershell
py tools\prove_mes_natural_loops.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json> `
  <execution-fallthroughs.json> <shared-call-returns.json> `
  <library-audit.json> <natural-loops.json>
```

Focused authoritative checks prove the `08C.MES` single-latch loop at
`0x0BC6..0x0C1C` and the larger `GIVEME.MES` loop at `0x008F..0x0314`.
V2 also proves `GROUND.MES:0x16E4..0x179C` after the exact execution
fallthrough reconnects its bounded caller CFG. Both latches, two exits, and the
complete label/goto fallback remain explicit.

### `prove_mes_shared_call_returns.py`

Consumes a validated linear decompiler IR plus a source-fingerprinted
`kakyu_mes_library_audit/v17` report and emits
`kakyu_mes_shared_call_return_proof/v2`. Only literal command-`0x1D`
shared-routine calls are eligible. The callee's native CFG must be complete,
entry-reachable, acyclic, free of unresolved boundaries and exits, and have
only explicit command-`0x00` returns as terminals. An incomplete strict or
structural diagnostic decode may be superseded only by that complete native
flow. Nested literal calls are resolved by a deterministic fixed point and
must themselves have a total-return certificate; missing, invalid, or cyclic
dependencies remain unresolved. Dynamic selectors and all registered/external
call families retain their numeric linear fallback:

```powershell
py tools\prove_mes_shared_call_returns.py `
  <linear-ir.json> <library-audit.json> <shared-call-returns.json>
```

This certificate establishes the exact callee, transitive literal callees, and
physical resume coordinate. It does not itself splice the return edge into the
caller CFG or promote a surrounding loop.

### `prove_mes_call_families.py`

Consumes a validated linear decompiler IR and emits
`kakyu_mes_call_family_proof/v1`. External command-`0x0F` calls are accepted
only when their safe `.MES` target metadata agrees case-insensitively with the
retained ASCII string record. Registered command-`0x11` calls are accepted
only when their selector remains one exact expression record. Both families require
one unambiguous linear node beginning at the physical resume coordinate:

```powershell
py tools\prove_mes_call_families.py `
  <linear-ir.json> <call-families.json>
```

The result is a typed call-site proof, not a total-return certificate. External
callee CFGs and the live registered-body binding are not part of the linear
input, so v1 emits no return edge and retains the original linear node as the
authoritative fallback. Missing or ambiguous resume nodes, unsafe targets,
metadata/record disagreements, and changed registered-selector shapes reject
the site deterministically.

### `prove_mes_execution_fallthroughs.py`

Consumes matching linear IR, bounded transfer proof, shared-call return
certificate, and its source-bound library audit. It emits
`kakyu_mes_execution_fallthrough_proof/v2` for next-anchor fallthroughs only
when the complete intervening span is accounted for. Ordinary typed nodes
advance linearly; an exact character-stream probe may mask its fully
partitioned NUL-terminated payload; and command-`0x1D` advances only with a
matching return certificate. Opaque bytes, branch/return commands, changed
terminators, dynamic calls, and missing certificates reject the span:

```powershell
py tools\prove_mes_execution_fallthroughs.py `
  <linear-ir.json> <flow-proof.json> <shared-call-returns.json> `
  <library-audit.json> <execution-fallthroughs.json>
```

V2 also projects every certified literal shared call as an explicit linear-CFG
edge from its exact call node to the same-region node beginning at its physical
resume. Unproved calls remain numeric fallbacks with their rejection reason;
missing or ambiguous resume nodes fail closed. The proof retains every
stored-order node under its native payload owner and does not alter Phase 2
record ownership.

### `prove_mes_guard_chains.py`

Consumes matching linear, transfer, and reducible-condition proofs and emits
`kakyu_mes_guard_chain_proof/v1`. It records maximal sequences where one proved
condition's false edge reaches the next proved condition. Conditions already
structured as `if_then` or `if_else` are excluded. Every case/default label is
retained, external entries and cyclic/merged components remain explicit, and
the output does not claim `if`/`elif` or semantic dispatch:

```powershell
py tools\prove_mes_guard_chains.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json> <guard-chains.json>
```

### `prove_mes_value_dispatches.py`

Consumes matching linear, transfer, reducible-condition, and guard-chain
proofs and emits `kakyu_mes_value_dispatch_proof/v1`. A chain is promoted only
when every guard is equality between the same numeric state coordinate and a
unique integer literal. Operand order may be reversed. Labels and external
entry metadata remain intact; compound conditions, changed discriminators,
duplicate literals, semantic state names, and case-body extent remain
unresolved:

```powershell
py tools\prove_mes_value_dispatches.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json> `
  <guard-chains.json> <value-dispatches.json>
```

### `prove_mes_predicate_dispatches.py`

Consumes the matching linear, transfer, reducible-condition, guard-chain, and
simple value-dispatch proofs. It revisits only guard chains rejected by the
simple value layer and emits `kakyu_mes_predicate_dispatch_proof/v1` when every
condition is a bounded Boolean expression made entirely from numeric state
equalities and `logical_and`/`logical_or`:

```powershell
py tools\prove_mes_predicate_dispatches.py `
  <linear-ir.json> <flow-proof.json> <if-regions.json> `
  <guard-chains.json> <value-dispatches.json> `
  <predicate-dispatches.json>
```

The proof retains the original AST and ordered guard labels while adding an
exact bounded DNF projection. It keeps first-true selection order explicit;
mutual exclusivity, case-body extent, semantic state names, and `switch`/`if`
surface syntax remain unresolved. Expansion limits fail closed instead of
allowing an exponential output.

### `export_encounter_mes_dialogue.py`

Exports the supported Maki fish-shop encounter trace directly from CP932 text
records in the authoritative archive. It verifies the expected source-entry
hashes and decoder coverage, and writes a source-offset-audited local runtime
projection under the Git-ignored `data/mes_dialogue/` directory.

```powershell
py tools\export_encounter_mes_dialogue.py <ELFIMAGE\mes.arc>
```

This exporter covers one explicit affection-50 trace. It is not a general MES
interpreter and does not project alternate flags, choices, or random variants.

### `export_map_location_entries.py`

Exports ordered `state_u16[21]` entry branches, inline message records,
duration operands, and called/selected MES entries for every EVE location ID on
`MACHI`, `TRAIN`, `GROUND`, and `FLOOR1` through `FLOOR5`. It also projects the
called interior MES intro program up to the first event/character-call boundary
and inventories matching location background families from the sibling
authoritative `mmo.arc`. The compact map index and lazy per-scene JSON files are
written under the Git-ignored `data/` directory.

```powershell
py tools\export_map_location_entries.py <ELFIMAGE\mes.arc>
```

This exporter covers the owning map dispatcher. It does not recursively
interpret the called interior or event scripts.

### `mes_gap_report.py`

Audits the production IR against the complete bytecode range. It reports
uncovered ranges, decoder errors, and top-level bytes routed through the
native character/default dispatcher instead of the `0x00..0x1F` opcode table.

```powershell
py tools\mes_gap_report.py assets\_source\kakyu\ELFIMAGE\mes.arc MACHI.MES
```

### `audit_mes_mmo_markers.py`

Counts exact outer-command-`0x0D`, presentation-subcommand-9, one-filename MMO
records separately from native top-level command `0x09` write semantics. The
record ends at its argument-list terminator; the tool reports the following
byte as a separate MES command so adjacent command-`0x07` writes are not
swallowed. With `--mmo-arc`, it resolves normalized names against the
user-owned image archive without extracting payloads. Unresolved names remain
visible rather than being invented as archive entries.

```powershell
py tools\audit_mes_mmo_markers.py <ELFIMAGE\mes.arc> `
  --mmo-arc <ELFIMAGE\mmo.arc> --entry EVENTD03.MES
```

### `audit_mes_ax_markers.py`

Counts exact outer-`0x0D` presentation-subcommand-8 selector-0 AX records.
The original EXE routes this selector to its Data loader; the audit keeps that
load contract separate from native command `0x08` dword-write semantics and
from still-unresolved AX token/rendering semantics. With `--data-arc`, it
resolves normalized names against the user-owned data archive without
extracting payloads.

```powershell
py tools\audit_mes_ax_markers.py <ELFIMAGE\mes.arc> `
  --data-arc <ELFIMAGE\data.arc> --entry 01M.MES
```

### `audit_mes_ax_bindings.py`

Counts the separate exact outer-`0x0D`, presentation-subcommand-3 records
that bind the loaded `banked_i32[0][2]` AX buffer to consumer row 0 and column
0, 1, or 2. The original-runtime audit fixes the sole registered consumer and
its virtual `+0x08` binding method; this MES audit does not call that method or
claim that it draws pixels. Schema v2 also counts the exact no-argument
selector-7 envelope. The original-runtime audit binds selector 7 to the same
consumer's slot `+0x20`, which marks all 10 x 32 AX cells inactive through
slot `+0x14`; the archive audit remains read-only and reports code-relative
coordinates without exporting payload bytes.

```powershell
py tools\audit_mes_ax_bindings.py <ELFIMAGE\mes.arc> --entry 03C.MES
```

### `audit_mes_surface_operations.py`

Audits exact outer-command-`0x0D`, presentation-subcommand-11 expression
record lists. It reports complete mode and record-shape counts across the
archive and can list code-relative rows for one entry. The paired executable
audit v81 retains v38's confirmation of modes 0/1/2 as opaque copy, RGB-key
copy, and active-surface fill, plus the consumer's 0..7 switch,
greater-than-7 default edge, conditional common tail, and normal return. Audit
v4 separately classifies the one exact six-record mode-13 display refresh and
leaves only the empty `10M.MES` candidate unresolved. It reports 11,315 pixel
operations, one display refresh, and one unresolved candidate in the
authoritative archive.
This command reads `mes.arc` in place and neither executes native effects nor
writes an extraction.

```powershell
py tools\audit_mes_surface_operations.py <ELFIMAGE\mes.arc> --limit 0
py tools\audit_mes_surface_operations.py <ELFIMAGE\mes.arc> `
  --entry EVENTD02.MES --limit 20
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_surface_operations.gd -- `
  <ELFIMAGE\mes.arc>
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_surface_dispatch_reachability.gd -- `
  <ELFIMAGE\mes.arc>
```

The Godot core audit v4 is hash-bound to the configured authoritative input and
requires the shared decoder to reproduce the Python audit's complete counts.
It publishes the six-record `LIBLARY.LIB` form as
`surface_display_refresh`, locks the empty `10M.MES` candidate as the only
unresolved whole boundary, requires zero unmatched prefixes, and rechecks that
the source archive is unchanged. The reachability audit v3 proves the `10M`
candidate has no route from an indexed intro while library routine 20 reaches
the display refresh once with evaluated records `[13,34,316,577,375,0]`. The
runner emits a non-executing `surface_display_refresh_omitted` trace with the
EXE-confirmed conditional `(0,0) 544x60` rectangle. Neither command executes
native pixels or the display refresh; backing content, lifetime, and
composition remain unresolved.

`validate_mes_ax_resources.gd` is the matching Godot-side read-only integration
check. It decodes three documented original MES coordinates through the shared
instruction decoder, resolves their AX names in `data.arc`, validates the raw
dword-stream boundary, and confirms that both source hashes are unchanged:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_ax_resources.gd -- `
  <ELFIMAGE\mes.arc> <ELFIMAGE\data.arc>
```

`validate_ax_corpus.gd` additionally checks every user-owned `data.arc` AX
entry against all three shared read-only projections. It reports aggregate
dword, 10-by-32 table, control-stream, shared-record, and destination-rectangle
statistics without extracting payloads and verifies that the archive
fingerprint is unchanged:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_ax_corpus.gd -- `
  <ELFIMAGE\data.arc>
```

Event Player uses the same table projection after an AX load marker. When a
later confirmed binding selects a cell, the diagnostics show that cell's exact
entry-relative stream target and start opcode outside the 640x400 game frame.
It validates the shared draw record but does not provide a generic native host
source-surface producer. Content Core `0.178.0` adds the common
`kakyu_ax_tool_scheduler/v1` preview clock: validated timelines advance by
explicit tool ticks or a configured seconds-per-tick value, stop terminal
streams, preserve dispatch order across reset-requested cycle wrap, and retain
bounded catch-up backlog. This is deterministic tool timing only; it does not
claim the original host cadence. App-local code does not define the timing
contract: Event Player consumes this scheduler for its EVENTB02 and EVENTB14
projections, and Image Editor consumes it for selected-cell
Play/Pause/Restart. This completes P3-03's shared deterministic tool-clock
scope; native surface production and cadence remain separate work.

Content Core `0.179.0` adds `kakyu_ax_playback_plan/v1` ahead of that clock.
For the selected cell it converts referenced shared records to stable local
frames, keeps each original shared-record index for diagnostics, checks source
crops against the explicit detached source size, and checks destinations
against 640x400. Image Editor uses the plan for structural selected-cell
playback, while Event Player uses the same output for its validated EVENTB02
and EVENTB14 compositor layers. The source remains caller-supplied; the plan
does not claim native surface-8 ownership or host cadence.

Content Core `0.180.0` advances this contract to
`kakyu_ax_playback_plan/v2` and adds `kakyu_ax_surface_binding/v1`.
Instruction v40/event trace v65 retain `banked_u16[0][1]`, the EXE-v69-bound
active-surface word at `state+0x20BA`, and its value at a named MMO marker.
EVENTB02 and EVENTB14 select value 8 immediately before their AN MMO loads, so
Event Player attaches that exact producer binding to their common playback
plans. Image Editor's standalone AX view remains deliberately detached, and
the plan still makes no native timing claim.

Content Core `0.182.0` adds
`kakyu_mes_active_surface_ax_audit/v1`. Its configured-original headless audit
scans all MES/LIB entries and fixes 1,352 exact stored chains in which a
surface-8 selection is immediately followed by an AN MMO load, surface-7
restore, and AX load. It preserves 1,351 following AX bindings and reports the
single `MUSIC.MES` structural exception. Results are labeled structural rather
than reachable; EVENTB02 remains a separately validated branch-family route.

Content Core `0.183.0` adds `kakyu_mes_ax_runtime_chain/v1`. Event Player now
requires the exact audited MMO trace and live surface-8 state, followed by the
exact AX marker and cell-binding trace, before activating EVENTB14 option-2
animation. This is a fail-closed bridge from stored structure to observed
execution; it does not auto-play all structurally matching corpus rows.

Content Core `0.184.0` adds `kakyu_ai5_mmo_header_profile/v1`. The original
`mmo.arc` validator pins the three observed header families and 302 primary
dimension pairs, rechecks the source fingerprint, and keeps the eight
nonzero-trailer resources plus flagged `CALFACE.MMO` outside the isolated
standard-profile engine-compatibility claim. Exact special templates may still
be decoded and preserved for remake use; generated headers mirror dimensions
canonically but are never promoted by their structure alone.

Run the original corpus check without opening a GUI:

```powershell
godot --headless --path . -s res://tools/content_suite/cli/audit_mes_active_surface_ax_chains.gd -- <mes.arc>
```

### `audit_ai5_arc_exe.py`

Cross-checks the shared ARC container constants against fixed native evidence
in the original launcher or extracted 32-bit runtime PE. It verifies the
`CAI5Arc` object, the 264-byte record loop, all three XOR constants, the
separate Data/MMO archive registrations, and the named-entry lookup/seek/read
path. Audit v4 also verifies that the original title and name-input A6 callers
route through the Data archive loader, and pins the native A6 inclusive
hit-test and ID-to-rectangle helpers. Audit v5 pins the entry index
(`entry_index`): a name-keyed ordered map built by unique insert at open, a
released index buffer, an upper-cased request name and a `-1` miss - the index
order carries no meaning for the engine. It does not execute the engine, infer
higher-level A6 ID meanings, or infer AX semantics.

```powershell
py tools\audit_ai5_arc_exe.py <AI5WIN.exe> --json
```

The byte expectations of this audit and of `audit_ai5_mes_exe.py` and
`audit_ai5_audio_exe.py` are spans, not copies of the executable (WD-25 item 1):
an address plus a `ByteSpan(length, sha256)`, whose content is read from your own
executable at run time and used only after the hash matches. `ByteSpan`,
`span_matches`, `span_bytes` and `measure_spans` live in this file beside
`PeImage`. The tests of the three audits rebuild their synthetic PE fixtures from
your executable, which they find through the `KAKYU_ORIGINAL_EXE` environment
variable alone (they skip without it), and the headless batch passes `--exe` to
the Python suite so that they run. Details: `docs/spec/tech/tooling.md`.

The Python suite can also be run alone: `py tools\content_suite\run_python_regression.py --jobs 4`
with `--exe "<AI5WIN.exe>"` for the native-audit tests and with `--mes-arc "<ELFIMAGE>\mes.arc"
--data-arc "<ELFIMAGE>\data.arc"` for the archive-literal guard
(`tests/test_no_original_archive_bytes.py`, WD-25 item 1b). The two archive
arguments are given together or not at all; the runner hands them to every shard
as `KAKYU_MES_ARC` and `KAKYU_DATA_ARC` (the only way the guard finds them) and
removes inherited values otherwise, so without them the guard's scan skips. The
headless batch passes the pair whenever `--elfimage` is given.

### `audit_ai5_mes_exe.py` and `audit_mes_startup_bootstrap.py`

  The executable audit statically checks the embedded runtime's MES dispatcher,
  command-`0x0B`/`0x0C` branch-coordinate handlers, context-registry lifetime,
  presentation-subcommand-8 inline script loader, and the successful
  application-startup handoff from configured root-stream installation to
  `CScript::run`.
`--measure-span` is how a new byte expectation is added: it prints one JSON row
`{image, address, length, sha256}` per request (the runtime by default, the outer
launcher with `--image launcher`) and never a byte, after checking that the input
is the original executable the audits pin. The 696 anonymous expectations are data
in `config/ai5_exe_audit/expected_bytes_v2.json`, fingerprint-pinned in the audit.
The companion archive audit reads `START.MES` in place and requires the original
selector-2 `LIBLARY.LIB` record at code coordinate `0x014C`, followed by the
selector-3 `DEF_MAIN.MES` record at `0x0165`. It reports hashes and coordinates,
never payload bytes, and never writes the source archive.

```powershell
py tools\audit_ai5_mes_exe.py <AI5WIN.exe> --json
py tools\audit_ai5_mes_exe.py <AI5WIN.exe> --measure-span 0xADDR:LEN [--measure-span ...] [--image runtime|launcher]
py tools\audit_mes_startup_bootstrap.py <ELFIMAGE\mes.arc> --json
py tools\audit_mes_host_activation_slice.py <ELFIMAGE\mes.arc> <AI5WIN.exe> 43C.MES --expect-count 6 --json
py tools\audit_mes_promise_location_routes.py <ELFIMAGE\mes.arc> <AI5WIN.exe>
```

An optional Ghidra headless proof of concept adds recovered function/basic-
block boundaries and normalized p-code definition facts to P2-05's current
two-transfer route inventory:

```powershell
py tools\run_ghidra_mes_dataflow.py
```

Configure `Original executable`, `Ghidra root`, `Java home`, and optionally
`Ghidra analysis cache` in ignored `.agents/local/source_paths.md`, or provide
`--executable`, `--ghidra-root`, `--java-home`, and `--cache-root`. The wrapper
first runs the existing hash-bound executable audit, verifies that the source
did not change, extracts only the audited embedded runtime into the local
cache, and creates or reuses a Ghidra project there. Reuse runs the project
with `-readOnly`. `tools/ghidra/ExportMesRouteFacts.java` writes the JSON report
to the local cache; neither the extracted runtime, Ghidra project, report, nor
machine paths are tracked.

The route report schema is `kakyu_ghidra_mes_route_facts/v1`. Each route retains
the six byte-audit sites, recovered containing function and basic block,
normalized high p-code at those sites, and a bounded definition tree for the
indirect call target. The same run also writes
`kakyu_ghidra_mes_anchor_facts/v1` for the exact command-`0x0E`, flag-8,
startup, load, install, and run anchors. That report includes every call in the
nine containing functions, definition trees for every call input, and direct
references to each function entry. The wrapper fails closed unless run,
loader, and installer references converge on the same five script-family
vtable bases and the root re-entry `+0x58` call receives member `+0x70`.

These are triage and cross-check facts, not original-behavior proof: Ghidra
recovery may be incomplete, and a zero direct-call intersection does not
exclude an indirect virtual host edge. The exact-byte Python audit plus
authoritative MES/EXE cross-check remains the fail-closed evidence gate. Ghidra
is therefore an optional analysis accelerator and is not required for normal
project builds or the routine headless validation batch.

Prepare the source-audited dynamic follow-up without launching the original
runtime:

```powershell
py tools\build_mes_runtime_trace_plan.py
```

The generator reruns the authoritative `mes.arc` and exact-byte original-EXE
audits, checks the embedded x86 PE identity, probes the isolated Ghidra dbgeng
environment, and writes an untracked `kakyu_mes_runtime_trace_plan/v3` JSON
under the configured local analysis cache. The plan contains twenty-four
module-relative software breakpoints, four staged hardware watchpoints, capture
expressions, a normalized `target_execution_start`, four audited one-based
choice-result observations, two upstream native-path observations, and all
seven P2-05 proof obligations. The terminal obligation accepts a
stream-qualified target return, a complete same-owner command-`0x0E` root
replacement, or process exit. It
contains no absolute source paths or payloads, does not start
or attach to the game, and always
leaves promotion false until one target-qualified dynamic session supplies the
required observations.

Validate that plan without importing pybag or attaching to anything:

```powershell
py tools\collect_mes_runtime_trace.py
```

Use `--list-candidates` to report only PID and basename for full-file
size/SHA-256 matches without attaching. To collect later, invoke the same
normal `py` command with either an explicit `--pid` or `--auto-pid`; it
re-executes itself through the prepared isolated debugger Python without a
shell. Automatic selection fails unless exactly one hash-matching
process exists. Before installing any breakpoint it requires the attached
main module to expose an x86 effective-machine context, match the audited image
size, and pass four independent 16-byte code-window hashes. A 64-bit dbgeng
host is switched explicitly to the WOW64 x86 context first. The collector then
reads the DOS and PE32 headers at the audited fixed image base rather than
depending on debugger module-name decoding, so a non-UTF-8 original game path
cannot weaken or block identity verification. It never launches or terminates the target,
removes breakpoints and attempts detach in `finally`, and defaults its
`kakyu_mes_runtime_trace_capture/v3` output to the untracked local cache. The
state machine distinguishes the current caller's early return, a matching-owner
nested-stream return, and a return on the installed target stream after matching
target load, install, and execution. Execution may begin at a
fresh same-owner run entry or at the observed same-owner top-level flag-8
resume after stream installation; receiver, active-state, thread, flag, and
nesting constraints all fail closed. Hardware watchpoints retain the first
target-owner hit per ID and count later hits without consuming the event
budget. Unrelated startup activity, pre-activation returns, and shared-library
returns cannot complete the target-return proof. After target execution, a root
replacement is accepted only when one non-target MES name passes through
command-`0x0E`, the archive loader and lookup, stream installer, coordinate
write, and matching flag writer on the qualified owner thread. A nested
resource load without that chain is not terminal evidence.
For a user-driven replay, pass `--expect-target EVENTB03.MES` (or the intended
plain MES name) so a stale/default plan is rejected before attach. An optional
`--stop-file <local-cache-sentinel>` is checked between debugger events;
creating that regular file requests an ordinary collector exit, breakpoint
removal, and debugger detach without terminating the original process. The
sentinel and capture must remain outside the project and original-source trees,
and a pre-existing sentinel is rejected. The sentinel does not shorten dbgeng's
event wait: repeated one-second waits race pybag's worker-thread interrupt path
and can make the next continuation fail with `E_ACCESSDENIED`.
Software breakpoint events are sampled by their final normalized ID so repeated
interpreter diagnostics cannot consume the global event limit. The capture
reports each ID's configured limit and observed/recorded/suppressed hit counts;
an ID's first evidence-bearing hit is always retained even if non-evidence
examples already filled its sample. Dbgeng output is not altered: changing the
engine output mask before or after the initial attach break, and replacing
pybag's text callback in an EVENTB03-ready state, were all followed by a
first-continuation `E_ACCESSDENIED` with zero evidence. Breakpoint chatter is
therefore retained for debugger reliability; bounded event sampling keeps the
JSON report within its evidence budget.

For an operator-driven event replay, add `--capture-state-snapshots` and use a
long enough `--idle-timeout` for the manual lead-in. After all breakpoints are
installed, the collector emits `MES_RUNTIME_TRACE_ATTACHED`; do not begin the
game action before that line appears. The opt-in mode reads one exact `0x3000`-
byte active-state snapshot at the source-qualified `target_execution_start`
and one at the first stream-qualified `target_run_return` or
`target_root_replacement`, records hashes plus a
small `state_u16` summary,
and keeps the full bytes only in the local untracked capture JSON. The existing
output guard rejects project and configured original-source directories, so
these runtime bytes cannot be written into the repository or source tree.
The routine-40 observation is accepted only after matching target execution
has begun on the qualified owner thread and its active-state pointer still
matches. It records the low 16-bit result and code-relative stream coordinate
before the audited native store to `state_u16[18]`; unrelated choices before
the target start cannot become `target_choice_result` evidence.
If that selected command-`0x12` route is not used, the second observation
captures the common modal result copy at `0x0043532E` before
`mov [esi+8], eax`. The same owner-thread target-run gate applies, and the
report marks whether a result came from the command-`0x12` slot-18 store or the
common modal copy.
The third observation is the earlier selected-control store at `0x00401CF7`.
It captures `ECX` before `mov [esi+8], ecx`, after the original control has
mapped the zero-based host row and added one. This covers keyboard and pointer
confirmation even when both downstream stores are bypassed.
The fourth observation is the standard-message candidate `CNormalSelect` store at
`0x00438DAD`. It captures the independently mapped and incremented one-based
`ECX` result while the target owner thread and active-state pointer still
match. If a nested script has installed a non-relative stream pointer, the
report uses a null code offset and `nested_stream_unresolved` instead of
mislabeling an allocation delta as a MES coordinate.
The v2 reports showed no result hit before their early nested-return detach; that
is not evidence that the four stores were bypassed by the later visible choice.
If a configured result breakpoint does execute
after target start but fails qualification, the report retains it under
`target_choice_probe_diagnostics` with `probe_id`, result path, any available
normalized result, expected/observed active state, stream pointers, and explicit
`rejection_reasons`. Rejected hits never enter `target_choice_results`; an empty
diagnostic list means no configured result site executed. Further replay plans
should observe the audited command-`0x1D` shared-script call and command-`0x12`
ingress instead of adding another guessed result store.
The 24-breakpoint plan now includes those two upstream sites. At
`0x0041A533`, it records the selected shared-script cursor/code base, first
dword at base plus cursor, and saved caller resume cursor/code base immediately
before command-`0x1D` calls the nested runner. At
`0x0043F2ED`, it records command-`0x12` native-record ingress. Matching
owner-thread/active-state hits after target start are summarized under
`target_native_path_observations`. Exact executable audit v315 identifies the
adjusted receiver's `+0x4B58C/+0x4B590` fields as cursor and code base; the
opcode address is their sum. Reports retain `active_stream_offset` and
`active_instruction_pointer`, and only expose a target `code_offset` when the
base matches the matched stream installation. These adjusted fields correspond
to unadjusted script-base `+0x4B590/+0x4B594`.

Executable audit v316 moves the return probe from the bare `ret` at
`0x0043D62F` to pre-restore site `0x0043D629`, where `ESI` still holds the
script receiver and `EBP` still exposes the caller return address. The collector
records receiver, active state, cursor, code base, nesting, and return address;
it emits `target_nested_run_return` when the qualified owner is returning from a
different active code base. Use `--continue-after-matching-return` for an
operator-driven replay that must stay attached through the target-stream return
and later choice/terminal activity. Stop it with Ctrl+C after the observed route
finishes; the report is still written and the debugger is detached in `finally`.

An older capture can be audited without replay when it contains the complete
root-replacement chain but was produced by a plan that knew only return and
process-exit terminals:

```powershell
py tools\audit_mes_runtime_trace_terminal.py <local-capture.json> `
  <ELFIMAGE\mes.arc> --expect-target EVENTB03.MES --expect-choice 3
```

The audit reopens the authoritative archive read-only, checks the trace/source
hashes, requires the first six proof obligations, verifies the selected-control
result plus command-`0x12` mirror/reset, and matches the successor against the
target's command-`0x0E` records. Schema v2 binds the result stream to
`LIBLARY.LIB` using target-linked and library-self-linked command-`0x1D` dword
anchors. It validates the two exact routine-40 native-record envelopes and
reports result `3` at `0x1C95..0x1CA0` plus the sentinel reset at
`0x1CC4..0x1CD0`. Schema v3 additionally walks the authoritative EVENTB03 CFG,
fixes only the `state_u16[21]` result guards, and binds results 1/2/3 to the
sole reachable `MACHI.MES` handoffs at `0x1BB6`/`0x26F4`/`0x3D46`; captured
result 3 therefore selects `0x3D46`. Its output contains only filenames,
hashes, code-relative offsets, and bounded control metadata. Promotion is
scoped to `command_0e_host_activation`; portable caller state remains an
explicit boundary.

Qualified target-start snapshots can be reduced without copying their native
buffers into a tracked artifact:

```powershell
py tools\audit_mes_runtime_trace_preset.py <ELFIMAGE\mes.arc> `
  <AI5WIN.original.exe> <capture-1.json> <capture-2.json> ... `
  --expect-target EVENTB03.MES
```

The v4 reducer accepts only target-qualified v2/v3 captures whose archive,
executable, target-entry, snapshot-size, and snapshot hashes match the sources
reopened by the audit. It reruns executable audit v317 to bind native
`global_u8`, `state_u16`, and bank-zero `banked_u16` offsets, decodes literal
condition fields and preceding literal writes from the authoritative target
entry. It additionally requires a 100%-aligned target projection and scans all
decoded instruction operands for captured-storage references. It emits only
filenames, hashes, source offsets, and selected numeric values. Invalid or
unqualified replay attempts fail instead of joining the sample set. The output
is a `source_qualified_target_local_input_candidate`, never a runtime preset:
repeated
observations do not prove causal minimality, shared-routine dependencies, or
native presentation state. Raw snapshots, dialogue, archive payloads, and
absolute paths are never emitted.

For EVENTB03, v4 removes observed `state_u16[8]=3` from the portable candidate
because the authoritative entry unconditionally writes `[8]=0` at
`0x0106..0x010B` before its first condition read at `0x010B`. The remaining
weekday/date/HHMM records are stable surrounding-host observations, not
target-local candidate fields: none is referenced by the 2,237 decoded target
instructions (174 references across 14 captured-storage fields). The scan
lists `banked_i32` as an unmapped storage rather than pretending its values are
covered by the bounded snapshot layout.

Preset audit v4 additionally parses and joins the two omitted entry records to
executable audit v317:
`EVENTB03.MES:0x011B` selects the original `CSpriteDays` visibility route and
`0x0126` selects `CSpriteTimeMoney`. Their literal-zero third expressions call
the shared visibility handler and hide the corresponding status sprites.
Neither route reads the weekday/date/HHMM context fields. This narrows the
native boundary but does not promote the reduction candidate because native
presentation inside the target and shared routines remains unresolved.
The path-free `native_setup_records` output contains only source coordinates,
envelope hashes, native classes, and bounded effects; any record or EXE route
change fails closed.

The v4 companion matrix also binds the four pre-choice shared calls to exact
`LIBLARY.LIB` traces. EVENTB03 calls routine 28 at `0x00FC` with argument slot
1 equal to 1, routine 21 at `0x0225` with 1, routine 28 at `0x0235` with 0,
and routine 21 at `0x08DF` with 46635. Their library traces contain 8/5/6/5
rows and omit 1/2/1/2 bounded native presentation effects. Content Core
`0.196.0` classifies those exact rows as selector-7 AX invalidation,
selector-8 AX activation/wait, and subcommand-10 mode-1 guarded surface
composition; the aggregate count remains an execution-omission count. In the
observed, empty, and four one-record-deletion cases, all four calls retain
identical coordinate/effect hashes and typed-control lists, empty expression
stacks, unchanged argument slots, no nested call, and no sandbox state diff.
This rules out a dependency on the three observed context records in the
executed shared-script logic; it does not execute the classified native
effects.

Three operation classes inside those spans, plus the adjacent selector-2/6 AX
controls used by event routes, can be audited without another operator replay:

```powershell
py tools\audit_eventb03_native_presentation.py <ELFIMAGE\mes.arc> `
  <AI5WIN.original.exe>
```

Schema v2 requires the authoritative archive-wide counts and exact
`LIBLARY.LIB` coordinates for AX selectors 7/8 and presentation subcommand 10
mode 1. It reruns executable audit v317, then exact-checks selector 8's bounded
`10x32` cell activation/wait functions and mode 1's control-word guard plus
three opaque native-surface copy calls. The emitted JSON is path-free and
contains only names, hashes, coordinates, native addresses, and bounded
semantics. AX cadence, surface pixel content/lifetime, and complete EVENTB03
playback remain explicitly unresolved.

V2 also scans selectors 2 and 6 archive-wide. Selector 2 occurs 2,583 times in
568 entries and binds the selected-cell state-1 handler at slot `+0x10`;
selector 6 binds its consumer slot `+0x1C` and
nested-cell slot `+0x10` handlers. It marks active `10x32` AX cells for update;
it does not write mapped gameplay state. This corrects the former EVENTD02
`global_u8[767] = 8` projection, which came from splitting selector-6/8 native
payloads into shadow MES command-3 writes; exact consumption leaves the
ordinary bounded MES result 1. An exhaustive inventory of this exact literal
subcommand-3 shape contains no selectors other than 2/6/7/8.

Content Core `0.273.0` advances the instruction boundary contract to
`ai5_mes_instruction/v44`. AX subcommand-3 selectors 1/2 now retain their
complete literal typed-record envelopes, including the thirteen-byte
selector/row/column form and optional consumer argument. Their payloads must
not become separator-following shadow MES writes. The existing seven-byte
selector-2 form remains supported. That release required v44 exactly; an older
projection cannot silently substitute for a revised instruction boundary.

Core `0.275.0` advances instruction boundaries to `ai5_mes_instruction/v45`
and Event Runner traces to `kakyu_mes_event_trace/v68`. Native subcommand 6
now consumes its whole zero-terminated typed-record list. The three-record
literal selector-0, safe WAV filename, valid channel-expression form becomes
an `effect_request` for `se.arc`; other complete forms remain `effect_dispatch`
with native effects omitted. Truncation fails without exposing payload bytes
as shadow bank writes. The runner records every request occurrence and reads
the channel expression from sandbox state without playing audio or silently
aliasing the separate argument-slot projection. Python handoff validation
requires v45/v68 exactly.

Instruction schema `ai5_mes_instruction/v45` and Event Runner trace
`kakyu_mes_event_trace/v68` retain the existing five exact seven-byte literal
envelopes. For those shapes the runner emits `ax_selected_cell_state_1_omitted`,
`ax_cells_mark_active_omitted`,
`ax_cells_invalidate_omitted`,
`ax_cells_activate_wait_omitted`, or
`surface_composition_control_omitted`, marks the native effect omitted and the
gameplay sandbox unchanged, then advances to the following instruction. The
EVENTB03 matrix separately binds each call's typed-control list and full trace
hash; changed selector/mode bytes are not promoted.

The runner's optional `preview_context.native_record_stop_offsets` selects
whole command-`0x12` starts that remain native boundaries even under the
`omit_bounded` policy. Other bounded records may still be omitted. Offsets
inside a record or at another command family neither split its payload nor
create a new stop. Earlier writes and execution context are retained; no
generic resume authorization or native presentation effect is synthesized.

Static analysis schema `kakyu_mes_analysis/v19` additionally uses aligned
regional decoding for the narrow outer-`0x0D` native-stream case whose
handler-consumed run contains a control-looking `0x0B` or `0x0C`. The control
byte may be internal rather than the first payload byte.
Run `validate_mes_analysis_corpus.gd` to reproduce its path-free record and
negative-space summary. It verifies each fail-closed opaque tail against the
source bytes and rejects any extracted message that lacks a typed text owner
or begins inside native, expression, or opaque payload bytes.

Run `audit_mes_record_alignment_corpus.gd` for the independent Phase 2
partition audit. It requires every bootstrap/address-region byte to belong to
one exact typed instruction or one byte-preserving opaque tail, inventories all
compound families without printing payloads, and rechecks that the source
archive fingerprint is unchanged:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_record_alignment_corpus.gd -- `
  <ELFIMAGE\mes.arc>
```

Run `audit_mes_transfer_direction_corpus.gd` to classify only current-schema
typed conditional and continuation targets by direction and address-table
region. It builds and verifies every Phase 1--4 handoff, keeps invalid targets
explicit, and reports opaque tails outside the scanned-transfer scope. The
optional JSON must be outside the source archive directory:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_transfer_direction_corpus.gd -- `
  <ELFIMAGE\mes.arc> <transfer-direction.json>
```

The current authoritative v1 report covers 113,613 typed transfers, zero
invalid target, and 373 same-region backward continuation candidates. It is a
candidate inventory, not a claim that every candidate is a natural loop.

The reduction candidate was also tested against the bounded Godot MES prefix
by `validators/audit_eventb03_preset_reduction.gd` (retired 2026-09-21, EP-10
unit 5c, with the hand-authored EVENTB03 presets it reduced; the check
`original EVENTB03 preset reduction matrix` left the registry the same day
and the paragraph below is historical).
It executed the four observed nonzero start records, the reduced structural
and presentation candidates, an empty state, and four one-field deletions in
separate sandboxes. All eight cases retain the exact
condition signature at `0x010B/0x01F0/0x0287/0x02F2/0x08AA/0x0933/0x09BB`,
native-record boundaries `0x011B/0x0126`, 28 dialogue boundaries, and the
three-definition choice at `0x12D2`; `[8]` must be 0 by that point. Equality
through this prefix is deliberately negative evidence. Result-3 continuation
then proves a narrower positive outer boundary: observed state, the two-field
candidate, and deletion of `[7]` or `[8]` retain the same 40 further dialogue
boundaries, 24 shared calls, DEF22/DEF21 composition, seven bounded native
stream coordinates and `MACHI.MES` root replacement. Exact `B_PIC.MES`
execution then distinguishes the three-field presentation minimum: MMDD
`state_u16[7]=413` reaches routine 22, `B1.MMO`, and `BAN.MMO`/`B.AX` column 1;
the two-field state takes a different target route. Empty state or deletion of
`[4]` or `[19]` also changes the later routine-25 traces. The command reports
the exact route coordinates and rechecks that the source archive was unchanged.
It does not claim native pixel equivalence for the seven earlier bounded
character streams.

The same three-field presentation minimum is cataloged as
`captured-result3-original`. Event Player applies it to a fresh isolated
startup state, verifies the versioned preset receipt and every required source
hash, and reruns the exact result-3/B_PIC/MACHI route. Catalog playback now
consumes the seven bounded native character spans as explicit metadata-only
omissions; only direct address-row Start remains deferred. Choices 1/2 are
additionally qualified by the branch-local validator described above.

`audit_mes_host_activation_slice.py` is the fail-closed P2-05 cross-source
audit. It fingerprints authoritative command-`0x0E` producer coordinates and
the verified native loader/install/run anchors without claiming that the two
halves are connected. Its proof-obligation table keeps target identity
separate from host timing, archive lookup, stream installation, intro
coordinate, caller/context ownership, and return/terminal behavior. It reads
both sources in place, checks their hashes before and after, and emits neither
dialogue nor raw payload bytes. Schema v2 additionally records why the MES
loader's active-state scratch reference and the flag-8 configured-root resume
are excluded from retained-target activation. Schema v3 consumes executable
audit v269's complete compact virtual-slot-`+0x20` inventory, requires the
only locally owned direct `CScript` loader routes to be configured startup and
the fixed mode-`0x40` transition, and keeps the remaining nonlocal/indirect
receiver alias as an explicit unresolved boundary.
Schema v4 consumes executable audit v270's ownership refinement as a complete
2+6+3+25 partition: two direct `CScript` loader calls, six public-context
non-loader calls, three checked native non-loader candidates, and 25 generic
candidates. It verifies the public receiver handler and native call-slot
classifications before retaining the same fail-closed indirect-receiver edge.
Schema v5 consumes executable audit v271 and cross-links four more candidates
to the already checked paint, native-selection, DirectShow pin, and media-
sample allocator receiver contracts. The resulting 2+6+7+21 partition stays
fail-closed at the same nonlocal/indirect `CScript` receiver edge.
Schema v6 consumes executable audit v272 and verifies three display-transition
calls against the RTTI-bound `CAI5View` window-subobject vtable, slot-`+0x20`
handler, and `USER32.SetMenu` import thunk. It distinguishes two current-menu
applications from one null-menu detach and requires the resulting 2+6+10+18
partition before retaining the same fail-closed receiver edge.
Schema v7 consumes executable audit v273 and verifies two additional
owner-member-`+0x6C` selected-control routes against the checked
`CAdvSelect`/`CItemSelect` RTTI, vtables, and slot-`+0x20/+0x24` handlers. It
requires the resulting 2+6+12+16 partition before retaining the same
fail-closed receiver edge.
Schema v8 consumes executable audit v274 and verifies one additional compact
candidate as `IDirectDraw7::EnumDisplayModes`. It requires the checked
`DirectDrawCreateEx` factory sites and IID, slot-`+0x20` callback dispatch,
failure label, and slot-`+0x08` release cleanup. The resulting 2+6+13+15
partition remains fail-closed at the same nonlocal/indirect `CScript` receiver
edge.
Schema v9 consumes executable audit v275 and verifies compact call
`0x0041828E` against the command-`0x06` dispatcher wrapper, all three manager
vtables, slot `+0x20`, and native banked-u8 writer `0x00418E90`. It requires
the resulting 2+6+14+14 partition and preserves the same fail-closed edge.
Schema v10 consumes executable audit v276 and verifies compact call
`0x00429243` as presentation-subcommand-3 selector 7's `CAnimeManager`
all-cell invalidation. It requires the checked selector table, slot `+0x20`
10 x 32 traversal, nested slot `+0x14` state-`0xFF` writer, and resulting
2+6+15+13 partition before preserving the same fail-closed edge.
Schema v11 consumes executable audit v277 and verifies compact call
`0x0043FF75` as the checked choice modal's `DIK_RIGHT` dispatch. It requires
the modal runner and input-check block, modal-control vtable, slot `+0x20`
right-direction callback, and resulting 2+6+16+12 partition before preserving
the same fail-closed edge.
Schema v12 consumes executable audit v278 and verifies compact call
`0x004411DF` as a document-level `CAnimeManager` all-cell invalidation route.
It requires the checked document consumer vector at `+0x4B578`, its exact-one-
consumer guard, the first-element receiver, slot `+0x20` handler, nested
10 x 32 slot-`+0x14` state-`0xFF` writer, and resulting 2+6+17+11 partition
before preserving the same fail-closed edge.
Schema v13 consumes executable audit v279 and verifies compact call
`0x00405857` as application-shutdown cleanup for the keyboard DirectInput
device owned by `CAI5KeyManager`. It requires the RTTI-bound manager installed
at application member `+0xF0`, the `GUID_SysKeyboard` device factory into
manager member `+0x28`, the setup-time `SetDataFormat`,
`SetCooperativeLevel`, and `Acquire` calls, and the shutdown-time
`Unacquire`/`Release`/clear sequence. The resulting 2+6+18+10 partition keeps
the same fail-closed nonlocal/indirect `CScript` receiver edge.
Schema v14 consumes executable audit v280 and verifies compact call
`0x00407B93` as the deleting-destructor phase of `CAI5Doc`'s owned `CMesWnd`
shutdown. It requires the document constructor's member-zeroing, the
`CMesWnd` allocation/constructor/store route at document member `+0x225EC`,
both RTTI identities and vtable bindings, the preceding slot-`+0x1C` cleanup,
the slot-`+0x20` deleting destructor with flag 1, and the final member clear.
The resulting 2+6+19+9 partition keeps the same fail-closed nonlocal/indirect
`CScript` receiver edge.
Schema v15 consumes executable audit v281 and verifies compact call
`0x0040AE32` inside the RTTI-bound Ogg/Vorbis decoder open handler. It
requires both decoder-class vtables to map slot `+0x08` to `0x0040AE00`, the
member-`+0x308` `Cai5OggVorbisFileUser` backend and its slot-`+0x04`
configuration call, followed by decoder slot `+0x20` header processing and
slot `+0x24` stream priming. The resulting 2+6+20+8 partition keeps the same
fail-closed nonlocal/indirect `CScript` receiver edge.
Schema v16 consumes executable audit v282 and verifies compact call
`0x0040EDD0` as `IDirectSoundBuffer::GetFrequency`. It requires all four
RTTI-bound Ogg/Wave thread and notify vtables to share owner slot `+0x48`, the
member-`+0x30` buffer installation through `IDirectSound::CreateSoundBuffer`,
and the adjacent owner slot `+0x4C` route to buffer slot `+0x44`
`SetFrequency`. The resulting 2+6+21+7 partition keeps the same fail-closed
nonlocal/indirect `CScript` receiver edge.
Schema v17 consumes executable audit v283 and verifies compact call
`0x00410638` as the `WM_CREATE` callback dispatched by the shared
`CAI5View`/`CAI5Wnd` virtual slot `+0x04` window-message handler. It requires
the message-1 remap/jump-table entry, both RTTI-bound owner vtables, their
slot-`+0x20` mapping to `0x00410850`, and that callback's
`USER32.LoadAcceleratorsA` resource-7 initialization and member-`+0x9C`
handle store. The resulting 2+6+22+6 partition keeps the same fail-closed
nonlocal/indirect `CScript` receiver edge.
Schema v18 consumes executable audit v284 and verifies compact calls
`0x00447BB1` and `0x00447F2D` as the native DirectShow pin media-type checks
inside outbound `AttemptConnection` and inbound `ReceiveConnection`.
`CRendererInputPin` and the `CAsyncOutputPin` base pin subobject supply the two
RTTI-bound owner vtables and slot-`+0x20` handlers. Both callers accept only an
exact zero HRESULT before storing the peer and invoking slot `+0x24` to install
the media type. The resulting 2+6+24+4 partition retains the fail-closed
nonlocal/indirect `CScript` receiver edge.
Schema v19 consumes executable audit v285 and verifies compact call
`0x00448577` as the dynamic media-type acceptance step in the renderer's
media-sample properties helper. It requires the sole checked caller from the
RTTI-bound renderer receive handler, the properties-pointer-to-input-pin
adjustment `-0x98`, slot-`+0x38` preflight, flag `0x08`, media-type pointer
offset `+0x34`, and `CRendererInputPin` slot-`+0x20` handler. Exact HRESULT
zero continues reception. The resulting 2+6+25+3 partition retains the
fail-closed nonlocal/indirect `CScript` receiver edge.
Schema v20 consumes executable audit v286 and verifies compact call
`0x004486C8` as `IMemInputPin::ReceiveCanBlock` on connected output peers
enumerated by the RTTI-bound `CRendererInputPin` handler. It requires the
owner's `IMemInputPin` secondary-vtable locator and this offset `+0x98`, the
output-direction and connection tests, the exact `IMemInputPin` IID, queried
interface slot `+0x20`, release calls, and `S_OK`/`S_FALSE` result contract.
The resulting 2+6+26+2 partition retains the fail-closed nonlocal/indirect
`CScript` receiver edge.
Schema v21 consumes executable audit v287 and verifies the final compact calls
`0x0044987E`/`0x004498EE` as `IAMovieSetup::Register`/`Unregister` setup-data
queries. It requires four paired primary/secondary RTTI owners, exact interface
slots `+0x0C`/`+0x10`, the this adjustment `-0x10`, all four primary
slot-`+0x20` provider cells, and the provider's complete constant-null body.
The resulting 2+6+28+0 partition exhausts compact slot-`+0x20` candidates while
retaining the fail-closed nonlocal/indirect `CScript` receiver and activation
edge.
Schema v22 consumes executable audit v288 and verifies the five exact
script-family slot-`+0x20` archive-loader vtable cells. It requires a whole-text
instruction-boundary search to return no direct-memory `call`/`jmp` through
`[register+0x20]` and no absolute indirect transfer through those cells. The
cell inventory and empty transfer inventory are fingerprinted independently;
the remaining edge is a register-loaded or reloaded nonlocal `CScript` receiver
alias, not an unchecked compact or direct-memory call shape.
Schema v23 consumes executable audit v289 and fixes the loader-capable
script-family ownership root. It verifies all 11 literal references to the five
checked vtables as constructor/destructor lifecycle sites, plus the complete
five-edge direct-constructor graph from application document allocation through
`CAI5Doc`, `CScript`, `CScriptManager`, `CFunc`, and `CCommon`. Static call
counts do not assert a runtime instance count; they narrow the remaining edge
to a receiver derived from application document member `+0xE8`.
Schema v24 consumes executable audit v290 and fixes the complete seven-entry
`CAI5Base` application-root vtable, its RTTI ownership, cell/target
fingerprints, and non-code trailer. The root has no slot `+0x20`; its bounded
document routes are configured startup, teardown, and `CScript::run`. The next
static edge is therefore explicitly non-root: a receiver derived from
application document member `+0xE8` before a three-argument loader call.
Schema v25 consumes executable audit v291 and inventories every exact adjacent
load from the global application root through document member `+0xE8`. The
original runtime contains 269 such routes (123 accumulator `A1` forms and 146
absolute-ModRM forms); 84 continue locally through the canonical virtual-base
adjustment `[document+0x0C]`, `[vbtable+4]`, then
`document+adjustment+0x0C`. None of those 84 exact local chains continues to a
compact adjusted-receiver slot-`+0x20` call. Route sets and the empty compact
result are fingerprinted. This is a bounded negative result, not proof that a
nonlocal, spilled, reloaded, or non-global document alias cannot reach the
loader.
Schema v26 consumes executable audit v292 and checks the next whole-text call-
pointer shape. It requires every `MOV register,[memory+0x20]` candidate in the
checked runtime text extent to have no route through exactly one distinct
register-to-register `MOV` and `CALL` of that transferred register within 64
bytes. The empty ordered route inventory is fingerprinted and host-slice
mutation fails closed. This excludes only that one-transfer call-pointer
shape; stack/object spills and reloads, longer transfer chains, and indirect
receiver aliases remain outside the claim.
Schema v27 consumes executable audit v293 and partitions the checked text by
exact EBP frame prologues before searching slot-`+0x20` load, negative-local
spill, and call-through-local shapes. Its sole candidate is fixed as a false
association in `0x0044FD0A..0x0044FDDF`: `0x0044FD56` reads the stack argument
at `[EBP+0x20]`, copies it to another local, and is overwritten before the
separate native object-member-`+0x80` callback is spilled and called. The route
and owner bytes are fingerprinted; ESP-local, object-field, and longer alias
shapes remain unresolved.
Schema v28 consumes executable audit v294 and checks the first unpartitioned
ESP-local spill frontier for slot `+0x20`: load-to-store at most 128 bytes,
store-to-reload at most 512 bytes, and reload-to-call at most 128 bytes. The
original runtime has 13 ordered candidates, partitioned into six fail-closed
false-association groups with route counts `2, 1, 4, 3, 2, 1`. They are surface
width/stride numeric loops, coordinate locals, or a stack argument/HRESULT
cross-function collision; each either returns before the apparent call or has
its call register independently replaced by a document/native-interface
vtable method. The route set and decisive instruction bytes are fingerprinted.
This bounded result leaves object-field spills, longer ESP-local distances or
transfer chains, and indirect receiver aliases unresolved.
Schema v29 consumes executable audit v295 and checks the first same-base,
non-stack object-field spill frontier with the same `128 / 512 / 128` byte
bounds and EBP-prologue discovery partitions. The original runtime has six
ordered candidates, grouped `4, 1, 1`; all are false associations. Four join
archive-container list-sentinel self-links across function returns to a fresh
slot-`+0x08` call, one treats bytes inside a jump immediate as an unaligned
store after an already executed selected-control slot-`+0x20` call, and one
crosses a structure-copy return before a separate object's slot-`+0x04` call.
The bounded next edge is a transferred ESP local, longer distance/transfer
chain, cross-base object field, or other indirect receiver alias.
Schema v30 consumes executable audit v296 and checks the first one-register-
transfer ESP-local loader frontier with bounds `128 / 192 / 512 / 128` bytes.
Its three products share one false chain: a selected-control slot-`+0x20`
pointer is called immediately, EAX is replaced by a time API result before the
EDI transfer, that owner returns, and the next owner zeros EDI before storing
and reloading coordinate locals. It also returns before a third function loads
a fresh native-control slot-`+0x28` call pointer. Longer distances, two or more
transfers, cross-base object fields, and indirect receiver aliases remain.
Schema v31 consumes executable audit v297 and checks the first exact
two-register-transfer ESP-local loader frontier with ordered bounds
`32 / 32 / 128 / 512 / 128` bytes. The complete original runtime text has no
slot-`+0x20` route of that shape, so the empty ordered inventory and its SHA-256
are part of the fail-closed contract. A synthetic positive route keeps the
scanner's detection path covered. Longer distances, three or more transfers,
cross-base object fields, and indirect receiver aliases remain unresolved.
Schema v32 consumes executable audit v298 and widens that exact empty frontier
to `128 / 128 / 256 / 1024 / 256` bytes. A synthetic route beyond the v31
distances verifies the wider positive path. The next one-axis doubling of each
bound yields `4 / 1 / 1 / 1 / 1` unclassified products, so v32 stops before
those products and leaves their owner-flow classification explicit work.
Schema v33 consumes executable audit v299 and classifies the single product at
the 256-byte transfer-to-transfer threshold. It is an `[ESP+0x20]` local that
crosses three returns; the final function independently loads an application
member's vtable slot `+0x48`. The route is retained and fingerprinted as a
fail-closed false association rather than discarded from the inventory.
Schema v34 consumes executable audit v300 and widens only the second-transfer-
to-store threshold to 512 bytes. Its three fingerprinted products are retained
as two fail-closed groups: two reuse an `[ESP+0x20]` temporary across owner
boundaries before fresh slot-`+0x14` or slot-`+0x48` calls, while the third
turns a surface-width field into dimension math before a fresh object's slot-
`+0x1C` call. Load-to-first-transfer, store-to-reload, and reload-to-call
threshold products remain the next one-axis probes.
Schema v35 consumes executable audit v301 and widens only store-to-reload to
2048 bytes. Eight routes are retained in three fail-closed groups. Four new
products join a consumed stack argument and later HRESULT to unrelated stack
locals across multiple function returns before fresh COM slot-`+0x14` calls;
the surface-dimension group gains a second numeric path. Load-to-first-transfer
and reload-to-call remain the next one-axis distance probes.
Schema v36 consumes executable audit v302 and widens only reload-to-call to
512 bytes. Thirteen routes remain in the same three non-loader groups. The new
HRESULT products end at a freshly loaded interface slot-`+0x30` receiver; the
new surface products consume numeric reloads before fresh slot-`+0x18` or
slot-`+0x1C` calls. Load-to-first-transfer is the remaining one-axis distance
probe.
Schema v37 consumes executable audit v303 and advances load-to-first-transfer
to its first occupied threshold at 129 bytes. Four added products are surface-
dimension math that crosses an owner return before an independent constructor
loads application member `+0xE4`, subobject `+0x44`, and fresh vtable slot 0.
Wider load-to-first-transfer thresholds remain unresolved.
Schema v38 consumes executable audit v304 and advances the same axis to the
next occupied threshold at 151 bytes. Fourteen added combinations remain in
the same surface-dimension/independent-constructor group, for a 31-route
inventory partitioned `2 / 6 / 18 / 5`. Wider thresholds remain unresolved.
Schema v39 consumes executable audit v305 and advances the same axis to the
next occupied threshold at 162 bytes. Two added products cross a structure-
copy owner return, an independent constructor return, and later stack-slot
owners before fresh COM slot-`+0x08` or enumerator slot-`+0x1C` calls. The
33-route inventory is partitioned `2 / 6 / 18 / 5 / 2`; wider thresholds
remain unresolved.
Schema v40 consumes executable audit v306 and advances the same axis to the
next occupied threshold at 189 bytes. Nine added products cross a numeric
position-range owner return, the `CRendererPosPassThru` slot-`+0x50` HRESULT
method, and separate IUnknown forwarding thunks before a fresh media-seeking
Release call or unrelated runtime termination callback. The 42-route
inventory is partitioned `2 / 6 / 18 / 5 / 2 / 9`; wider thresholds remain
unresolved.
Schema v41 consumes executable audit v307 and advances the same axis to the
next occupied threshold at 205 bytes. Two added products consume an indexed
structure-table base before ECX becomes a stack copy destination, then cross
the prior owner/constructor boundaries to fresh COM or enumerator receivers.
The 44-route inventory is partitioned `2 / 6 / 18 / 5 / 2 / 2 / 9`; wider
thresholds remain unresolved.
Schema v42 consumes executable audit v308 and advances the same axis to the
next occupied threshold at 227 bytes. Nine added products accept the second
HRESULT update in the same `CRendererPosPassThru` slot-`+0x50` method already
classified at the 189-byte boundary. They still cross the method return and
IUnknown forwarding thunks before a fresh media-seeking Release receiver or
an unrelated runtime termination callback. The 53-route inventory is
partitioned `2 / 6 / 18 / 5 / 2 / 2 / 18`; wider thresholds remain
unresolved.
Schema v43 consumes executable audit v309 and advances the same axis to the
next occupied threshold at 234 bytes. Its one added product consumes an
`ESP+0x20` pixel-placement loop argument in a helper call, then crosses
unrelated dimension arithmetic, its owner return, and a separate this-copy
helper before a fresh document-subobject slot-`+0x28` receiver. The 54-route
inventory is partitioned `2 / 6 / 1 / 18 / 5 / 2 / 2 / 18`; wider thresholds
remain unresolved.
Schema v44 consumes executable audit v310 and advances the load-to-first-
transfer axis to 257 bytes. Its two added products start from a surface-width
load whose register is overwritten twice before the apparent first transfer;
later dimension arithmetic feeds a pixel-copy loop, while the final call uses
a fresh application-member receiver. The 56-route inventory is partitioned
`2 / 6 / 1 / 18 / 7 / 2 / 2 / 18`; wider thresholds remain unresolved.
Schema v45 consumes executable audit v311 and advances the same axis to 294
bytes. Its four added products start from a consumed-and-overwritten surface
width, cross later loop and word-dimension arithmetic, and end beyond an owner
return at a fresh constructor receiver. The 60-route inventory is partitioned
`2 / 6 / 1 / 22 / 7 / 2 / 2 / 18`; wider thresholds remain unresolved.
Schema v46 consumes executable audit v312 and advances the same axis to 308
bytes. Its fourteen added products start from another consumed-and-overwritten
surface width and cross clamped loop-count, pixel-presentation, owner-return,
and fresh-constructor boundaries. The 74-route inventory is partitioned
`2 / 6 / 1 / 36 / 7 / 2 / 2 / 18`; wider thresholds remain unresolved.

Executable audit v34 retains the subcommand-4/selector-13
`A..Z`/`_A.._Z` relative-offset copy loop and additionally fixes the shared
character-stream handler's peek-0 loop, consume-1 terminating-NUL path, and
return epilogue. It also reports selected native direct-write routes for
`state_u16[18]` without labeling the value as a choice result or claiming that
an Event Player intro executes those routes. It also pins the normal
script-manager byte-`0x12` remap through typed-record parsing and virtual slot
`+0x74` into the record dispatcher; stored result meaning remains unresolved.
Version 29 also pins presentation-subcommand-8 selector 0, its public-handler
case, the adjusted document Data-loader vtable slot `+0x24`, archive collection
index zero, and named-entry lookup. This confirms the native `.AX` load request
without assigning meaning to the loaded dwords or claiming rendering. Version
30 additionally proves that its `banked_i32[0][2]` argument is initialized from
an owner pointer and used as the direct-load or AI5-LZ output destination. It
still assigns no AX token, placement, or rendering meaning. Version 32 follows
the bound AX cell through its control stream, shared seven-dword rectangle
record, renderer adapter, and three-byte green-key pixel copy. It leaves host
source-surface lifetime and tick scheduling unresolved. Version 33 fixes the
surface initializer and dimension table: the renderer takes source pixels from
surface 8 (2688x864) and writes to surface 0 (640x400). It deliberately leaves
the MES operations that assemble surface 8's contents and tick scheduling
unresolved.
Version 34 additionally separates outer presentation subcommand 9 from native
top-level command `0x09`. It pins adapter `0x0042A640`, all three public vtable
`+0x30` routes to consumer `0x0042A6A0`, the one-name `(-1,-1)` origin
defaults, active-surface state offset `+0x20BA`, and the path through
`0x00425190` to MMO decoder `0x004329D0`. This confirms the named active-surface
load while leaving the selected surface and later composition state-dependent.
Version 35 additionally pins presentation-subcommand 11 at dispatcher call
`0x004282A1`, adapter `0x0042ABA0`, public-context slot `+0x38`, and active
consumer `0x0042AC30`. It confirms inclusive endpoint expansion and the three
pixel helpers `0x004254D0`, `0x004255D0`, and `0x00425B10` for opaque copy,
RGB-key copy, and active-surface fill. Surface contents and composition order
remain state-dependent, and the tools expose metadata without running those
helpers.
Version 69 closes the bounded producer alias needed by the current event
routes: the bank-zero word pointer initialized with `state+0x20B8` makes
`banked_u16[0][1]` the active-surface word at `state+0x20BA`. Original
EVENTB02 and EVENTB14 MES order writes value 8 before the selected AN MMO load,
so their following AX playback consumes a trace-bound surface-8 producer.
Other route lifetimes and native cadence remain unresolved.
Version 72 retains version 71's complete command-`0x1B` handler and vector erase
helper. It confirms that the evaluated selector's complete `[begin,end)`
record range is removed by setting end to begin while preserving allocation
capacity and leaving inactive backing bytes untouched. The paired
`validate_mes_library_routine40_dispatch.gd` check binds the original
`LIBLARY.LIB` order as routine 20, entry label 0, selector clears `1..17`, then
return. Version 72 also resolves routine 20's bounded mode-13 host action as a
conditional `(0,0) 544x60` attached-display rectangle refresh. The tool still
omits that refresh because its backing content/lifetime and final composition
remain unresolved.
The matching shared-decoder
audit confirms the exact original envelopes without executing them or writing
the archive:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_presentation_state_transfers.gd -- `
  <ELFIMAGE\mes.arc>
```

The current original set has five `HTE` mappings selected by
`state_u16[25]`. Event Runner reports these as a fail-closed host-state
boundary; it does not deserialize the native record or synthesize bank aliases.

The matching shared-core integration requires the same two envelopes to decode
as readable `mes_script` references, then verifies that the isolated Event
Runner stops before native execution and leaves its sandbox unchanged:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_startup_execution.gd -- `
  <ELFIMAGE\mes.arc>
```

The next read-only audit follows `DEF_MAIN.MES` from coordinate zero, indexes
only the command-`0x14` bodies reached in original control-flow order, and
requires the path to return without dialogue or gameplay-state changes. It is
paired with executable audit v22 when the optional original launcher is given
to the standard batch and does not invoke any registered body. The
implementation consumes the shared runtime-only
`kakyu_mes_startup_context/v2` projection rather than duplicating the
command-`0x14` traversal. Event Player accepts the projection only for the
exact original startup set and only its explicit EVENTD08 library continuation
can consume it; arbitrary intro inheritance remains disabled:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_startup_context.gd -- `
  <ELFIMAGE\mes.arc>
```

Startup context v2 carries the owning MES basename separately from the
human-readable registration label. Registered-DEF, shared-library, detached
preview, and Event Player trace rows therefore report `source_entry` directly
instead of parsing a label such as `DEF_MAIN.MES:0x1518`.

`audit_mes_startup_definition_calls.gd` then supplies that exact runtime-only
map to entry zero of every original MES entry through the shared bounded
registered-definition runner. It follows nested mapped DEF calls with explicit
call/depth/step limits and stops at shared-library or unresolved state
boundaries. Character-stream and typed-record omissions are separate explicit
analysis policies; both remain fail-closed by default. The current hash-bound
v3 contract covers 103 entries and 201 calls:
all 91 DEF11 paths enter DEF12 and reach the 2,000-row analysis limit, seven
DEF22 paths stop at shared routine 3, and five caller paths stop at root routine
28. The v3 report also identifies DEF12's exact bank-25 sentinel-15 scan.
DEF12 first rewrites `state_u16[25]` as an offset into a bank-zero row; the
fresh sandbox does not yet model that physical alias or provide its host
state, so the scan remains a bounded loop. It emits no dialogue and never
writes the source archive:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_startup_definition_calls.gd -- `
  <ELFIMAGE\mes.arc>
```

Content Core `0.157.0` also exposes an in-memory
`kakyu_mes_registered_definition_continuation/v1` when an explicitly mapped
DEF pauses on dialogue. Resume requires the same root and registered-body
hashes, source/bounds records, command-`0x11` caller sites, physical resumes,
and active LIFO frame stack. It restores temporary argument/evaluator context
only after validation; changed or missing bodies and shifted frames are
rejected before execution. This is a core/test foundation and is not yet an
ordinary Event Player control.

Content Core `0.158.0` adds the corresponding in-memory
`kakyu_mes_library_continuation/v1`. A dialogue reached in a root or nested
indexed shared routine pauses before its exact trailer continuation, preserves
command-`0x1D` caller frames plus temporary arguments/evaluator carry, and can
resume only against the same library bytes and index. Other bounded native
character streams remain omitted for tool execution. The focused
`test_mes_library_runner.tscn` covers root and two-level nested dialogue,
ordered caller restoration, and changed bytecode/call/resume rejection. Event
Player exposes the same boundary through `Continue`, resumes the source-bound
library frame before the selected MES caller, and additionally rejects a
changed MES caller bytecode/resume binding. Registered-DEF continuation remains
available through the same Event Player control when the root command-`0x11`
target is present in the audited startup registry. The first action enters the
explicit body; a body dialogue pauses with the v1 continuation; the next action
finishes the DEF stack before restoring the root MES caller. Root/DEF byte
changes and coordinate changes fail closed, and unresolved native streams are
not skipped merely to manufacture a dialogue.

Content Core `0.159.0` advances that in-memory library frame to
`kakyu_mes_library_continuation/v2` and the trace to v8. A dialogue inside a
registered DEF invoked by a root or nested shared routine now embeds the active
registered-DEF v1 frame. `Continue` revalidates both source/call graphs and
resumes the DEF body, current shared routine, outer shared routines, and MES
caller in order. Changed library/index, DEF body, or either caller coordinate
fails closed before restoration; unresolved native streams remain explicit
stops.

`python tools/audit_mes_calendar_rows.py <mes.arc> --exe
<AI5WIN.original.exe>` cross-checks that dependency without executing original
code. Audit v1 fixes the EXE-initialized `banked_u16[0][0] = 0x24A0` relative
base and reconstructs the identical 12-row, 384-byte sentinel-15 table authored
by `START.MES` and `FLAGINI.MES`. It reports only offsets, row lengths, and
hashes; it does not export original scripts or mutate either source file.

The shared-core equivalent rebuilds the table in memory through the Godot
instruction decoder, applies it to an isolated sandbox, and proves that all 12
DEF12-style scans reach the expected sentinel. It is hash-bound to the audited
original archive and emits no table payload:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_calendar_state.gd -- `
  <ELFIMAGE\mes.arc>
```

The execution companion applies that projection to the registered DEF12 body
for 12 explicit month inputs plus the native wrapped `1301` case. It requires
the exact sentinel counts, the `0x04F5` loop exit, and the later fail-closed
shared routine-26 boundary:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_def12_calendar_execution.gd -- `
  <ELFIMAGE\mes.arc>
```

The next read-only execution audit composes that exact boundary with indexed
shared routine 26 and the caller resume. It requires all thirteen projected
dates to take a 27-row library path with no nested call, presentation omission,
message, or state change, then requires DEF12 to return at `0xEFA`. Other
routine-26 branches remain outside this claim:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_def12_library26_execution.gd -- `
  <ELFIMAGE\mes.arc>
```

One additional audit deliberately seeds thirteen bounded banked-state cases to
reach every routine-24 call stored inside routine 26. It independently verifies
`0101 + 27 days = 0128`, calls spaced from `0x217D` by `0x1A0`, five-byte
caller resumes, and each exact isolated diff. The seeds are not presented as
naturally reached original-game states:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_library26_routine24_execution.gd -- `
  <ELFIMAGE\mes.arc>
```

The producer cross-audit then checks all thirteen static routine-26 field
blocks, twelve direct `*_PROMIS.MES` date/auxiliary writers, and the original
EXE's native 16-bit command-`0x07` handler contract. It emits no dialogue or
payload bytes, includes each writer's owning address-table intro without
claiming reachability, and leaves block 5's absent PROMIS producer unresolved:

```powershell
py tools\audit_mes_promise_calendar_fields.py `
  <ELFIMAGE\mes.arc> <AI5WIN.original.exe>
```

The location-route cross-audit then checks all fifteen literal location
writers in each of the twelve PROMIS entries and follows all ten time options
through the native `0x0B`/`0x0C` branch contract. It fixes the time-specific
rejected/accepted location sets, ordinary two-boundary retry bodies, success
flags `610..619`, HHMM writes `0900..1800`, and entry-specific control targets.
It reports the separate A-entry 16–18 latch gate without treating that gate as
a generic location rule. It emits no dialogue and modifies neither source:

```powershell
py tools\audit_mes_promise_location_routes.py `
  <ELFIMAGE\mes.arc> <AI5WIN.original.exe>
```

The owner-intro execution audit proves why those structural owners are not yet
safe Event Player start recommendations. It requires zero directly reached
writers, nine date shared-routine boundaries, three date returns, and twelve
auxiliary returns without source mutation:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_promise_writer_execution.gd -- `
  <ELFIMAGE\mes.arc>
```

For the nine date owners that stop at routine 24, the continuation audit
applies the hash-bound calendar projection, executes the shared routine, and
resumes the original caller. With explicit input `0401`, every route must
store `0402` and return; this still does not claim native outer-caller
reachability:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_promise_date_library_resume.gd -- `
  <ELFIMAGE\mes.arc>
```

`C/E/I_PROMIS.MES` place a dynamic-name dialogue boundary before routine 24,
so the older presentation-skipping owner probe returns too early. Their focused
audit resumes that exact boundary, executes the same hash-bound routine-24
calendar body, requires `0401 -> 0402`, and reaches each original ten-option
selector. With the untouched location value `0`, option 1 must take its
two-dialogue retry while options 2..10 take their three-dialogue accepted
prefixes and store `1000..1800` in paired fields `226/218/220`:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_promise_cei_date_routes.gd -- `
  <ELFIMAGE\mes.arc>
```

The graphical Event Player now exposes all twelve confirmed prefixes as
**Start PROMIS Schedule** for `A..L_PROMIS.MES`. Open the original
ELFIMAGE set, set **Legacy date** to a valid `MMDD` value such as `0401`, click
**Apply Quick State**, and choose the matching confirmed row. Continue the
original dialogue, then continue routine 24. The route writes the next date in
the isolated sandbox and proceeds to its original ten-option time choice.
Choices are paged three rows at a time inside the game frame; use Up/Down and
Enter, number keys `1..9`/`0`, or click a visible row. With otherwise empty
state, choice 1 plays two original rejection-dialogue boundaries and returns
to the choice. This is expected because each entry's selected-location field
remains zero. The audit confirms option 1 accepts location IDs
`2,3,5,6,7,9,10,12,14`. To inspect the accepted path, open the **Sandbox**
tab, set **PROMIS location g[...]** to one of those IDs (for example `2`), and
click **Set location** before restarting **Start PROMIS Schedule**. Choose
again: each visible time row now shows `[OK]` for location-allowed, `[NO]` for
location-rejected, or `[GATE]` for the separate A-entry 16:00–18:00 latch
condition. An `[OK]` route continues the original success dialogue to
**PROMIS PREFIX END**.
This control writes only the hash-bound entry's isolated selected-location
field; it never guesses or changes the original outer selection. Prefix end
is not labeled as whole-event completion because the native outer caller is
still unresolved.

The focused no-window controller validator covers all twelve entries, invalid-
date gating, all twelve month-end transitions (including original terminal
`1231 -> 1301`), exact routine-24 resumes and date writers, time choices, the
empty-sandbox rejection loop, and the accepted location-2 matrix. It snapshots
the exact selector state and executes all ten choices in all twelve entries. The
120 accepted paths must write flags `610..619`, transient HHMM `0900..1800`,
and the matching paired banked time, then resume all original dialogue to the
exact per-entry `script_return`. The check distinguishes that prefix return
from whole-event completion, rehashes the source, and retains the original
executable's separate command-`0x1D` call/restore contract:

For `A_PROMIS.MES`, the same pass also executes options 16:00, 17:00, and
18:00 with the separate gate still closed. Field 201 value `99` must return to
the selector after two dialogue boundaries without a latch; value `100` must
set latch 1060 after eight boundaries and return to the selector without a
success flag. Re-selecting the same time must then complete normally. The
`0824` plus location-14 precedence path is checked separately and must leave
the latch clear. These are isolated test inputs; the original field's gameplay
meaning remains unresolved.

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_promise_dates.gd -- `
  <ELFIMAGE-directory>
```

The separate read-only caller audit enumerates every exact command-`0x0F`
activation of `A..L_PROMIS.MES`, binds it to the owning caller address entry,
checks every target's common zero-start setup transfer, and cross-checks the
original executable's `0x0B` exact-one branch, zero-coordinate call/restore,
and command-`0x14` registration contracts. Its current hash-bound corpus has
500 calls in 66 caller entries; every call includes its target-specific
`global_u8[index] == 1` gate and false skip coordinate. This resolves the
immediate activation gates, not their producers or the host selector that later
chooses a nonzero scheduling entry:

```powershell
python tools/audit_mes_promise_callers.py `
  <ELFIMAGE\mes.arc> <original-executable>
```

The matching controller reachability audit starts all 146 stored caller owners
with a fresh all-zero sandbox and the real caller address table. Its locked
baseline reaches no PROMIS dispatch. It explicitly continues the two initial
routine-27 paths through routines 27, 25 plus registered DEF26, and 21; both
then dispatch `L_OUTRO.MES`. The final distribution is 140 returns, four other-
script dispatches, and two floor-script handoffs, with no dialogue. This is a
negative test for an explicit state, not evidence that the original calls are
dead:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_promise_caller_reachability.gd -- `
  <ELFIMAGE\mes.arc>
```

The same audit also runs 499 unique owner/target cases with only the confirmed
target flag set to `1`. Its locked result reaches no PROMIS dispatch or dialogue,
so the report treats that flag as an immediate necessary gate rather than a
standalone Event Player start recipe. This pass does not modify a gameplay save
or the source archive.

The focused nested-call audit supplies an explicit conversation
state for `44C.MES:#376` and `L_HOTEL2.MES:#142`, then opens only the explicit
`L_TALK30.MES` callee. It runs both local definition IDs as tool-selected input,
restores each original caller, and requires all four routes to stop at the exact
`L_PROMIS.MES` dispatch. Native routine-40 selection remains unresolved and the
PROMIS target itself is deliberately absent from the execution map:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_promise_nested_calls.gd -- `
  <ELFIMAGE\mes.arc>
```

The aggregate validation batch also runs the original executable MES audit,
which independently checks the command-`0x0F` zero-start call and caller-
coordinate restoration contract used by this tool composition.

In Event Player, open the exact original ELFIMAGE, select `44C.MES` or
`L_HOTEL2.MES`, then click **Start Nested Dialogue**. The button applies the
documented values only to the isolated sandbox and presents the two original
`L_TALK30.MES` local rows inside the game frame. Select with mouse or
Up/Down and Enter (number keys 1/2 also work). After the selected body returns,
the last message is labeled `L_PROMIS.MES BOUNDARY REACHED`; the PROMIS body is
not executed and native selection remains explicitly unresolved.

The **Trace** tab shows `MES entry · code offset` for every row. The
**Messages** tab likewise shows `MES entry · text source`, so rows from the
caller and `L_TALK30.MES` remain distinguishable after composition.
The **Script Calls** tab shows the caller call/resume coordinates and changes
the callee status from `not returned` to its exact return coordinate after a
choice, without implying that the following PROMIS target was executed.

Event Player automatically shows `calendar state active` after opening the
exact audited original ELFIMAGE set. To inspect the bounded path manually,
select `DEF_MAIN.MES`, set **Legacy date** to a valid `MMDD` value such as
`0801`, apply the quick state, enter intro `0x4A1`, and run. The scan exits and
the tool stops at shared routine 26 (`0xEF0`). Click **Continue** to run the
bounded shared body and resume DEF12; the audited state returns at `0xEFA`
without another sandbox change. Changing the source through an overlay
disables this startup-derived baseline.

### `audit_mes_library_routines.gd`

Audits selected routines in the authoritative `LIBLARY.LIB` entry without
executing them. It keeps strict and stored-order structural views, persistent
stack effects, and return-delimited segments, then builds a separate native-
dispatch CFG. That graph follows both branch edges, advances across both EXE-
confirmed character streams and complete command-`0x12` typed record lists,
and therefore does not report their payload bytes as reached MES commands.
`--summary` omits raw payloads and dialogue.

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_library_routines.gd -- `
  <ELFIMAGE\mes.arc> --summary --output <library-audit.json> 28
```

`--output` writes the same path-free JSON report used by downstream proof
tools and refuses to replace the source archive. It may be combined with
`--summary`; the latter controls console output only.

### `validate_mes_library_runner_routine28.gd`

Runs authoritative routine 28 in a fresh isolated sandbox with both observed
incoming evaluator-stack shapes, `[]` and `[2]`. It requires the bounded
library runner to return without a nested call or gameplay write in this
all-zero baseline, verifies one omitted native presentation span, and rechecks
the source archive fingerprint. It never opens a GUI or gameplay save.

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_library_runner_routine28.gd -- `
  <ELFIMAGE\mes.arc>
```

`validate_eventd08_choice_routes.gd` composes the same runner with all three
hash-bound EVENTD08 choices. It verifies routine-28 return, the isolated
routine-27 write, and the next fail-closed routine-25 DEF invocation boundary.

`validate_event_player_eventd08.gd` drives the complete Event Player controller
from the exact command-`0x0F` zero-start dispatch through nine common dialogue
boundaries, 17 message fragments, both adjacent typed-record lists, the
two-NUL `D08.MMO` envelope, all three choices, and the existing caller
completion routes. It rehashes the source archives and does not open a window:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/validators/validate_event_player_eventd08.gd -- `
  <ELFIMAGE-directory>
```

`validate_mes_library_def_routes.gd` audits original routine 25's complete
native-dispatch graph and bounded first execution. It locks the two DEF-26 call
coordinates, verifies that no matching registration coordinate exists inside
the routine, and requires execution to remain fail-closed at the first call.
It does not infer startup inheritance from another routine or execute a native
stored body. Executable audit v22 and the START.MES audit confirm that the
original startup runs `LIBLARY.LIB` and `DEF_MAIN.MES` and retains registrations
for the owning manager; they do not turn an isolated preview into a booted
original session.

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_library_def_routes.gd -- `
  <ELFIMAGE\mes.arc>
```

### `audit_mes_event_runner_corpus.gd`

Runs every MES address-table intro against a fresh all-zero sandbox state and
summarizes result statuses, unsupported command IDs, traced steps, and message
reachability. It also counts source-confirmed command-`0x1B` internal-vector
clears by literal selector and classifies the entry, predecessor, next command,
and latest sandbox write at command-`0x11` DEF invocation boundaries. Shared-
routine boundaries are grouped by routine ID and most recent argument-slot
assignment, plus persistent evaluator-stack depth and routine-28 top value.
Command-`0x0E` safe ASCII MES handoff boundaries are grouped by target, entry,
archive target resolution, and bounded samples; filenames are not counted as
dialogue and their unresolved host consumer is not executed. Command-`0x0F`
boundaries are grouped by safe ASCII target, record shape,
entry, following command, and authoritative ARC target resolution so native
call-boundary work remains reproducible. Each remaining unsupported command
also gets bounded entry/anchor/stop and operand-shape samples without raw
payload bytes or dialogue. Decoder failures are grouped separately by the
stopped command byte and an address-normalized error reason, with bounded
entry/anchor/stop samples. This keeps the next decoder target reproducible
without copying archive payloads into logs. It also counts structural
instructions, evaluated persistent-stack fragments, empty-stack zero
fallbacks, and maximum isolated stack depth.
Audit v38 additionally counts reached `surface_operation_omitted` and
`surface_dispatch_omitted` trace effects, with bounded entry/index/intro and
dispatch-coordinate samples for the unresolved form. This keeps raw candidate
counts separate from address-table execution coverage.
Branch-shaped bytes consumed by command `0x0D`'s confirmed native presentation
handler are reported as presentation boundaries instead of false MES branch
targets.
The optional anchor limit is `0` for the complete corpus. It rechecks the source
archive fingerprint and never opens a GUI or changes a gameplay save.

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_event_runner_corpus.gd -- `
  <ELFIMAGE\mes.arc> 0 2000
```

### `inspect_normal_talk.py`

Finds the owners of the normal-conversation menu label (6 characters, matched by
the length and SHA-256 of its CP932 bytes; the label itself is not stored) in the
raw archive and records
their visibility guard, menu command, selected-choice dispatch, leading branch
conditions, full false-edge branch spine, state writes, direct affection-delta
assignments, and
`0x0C` continuation targets. It deliberately omits dialogue text from its JSON
output. It decodes every entry (the label is recognised on decoded text, so there
is no raw-byte pre-filter; about 13 s for the whole archive).

```powershell
py tools\inspect_normal_talk.py assets\_source\kakyu\ELFIMAGE\mes.arc `
  -o analysis\mes_ir\normal_talk_analysis_v1.json
py tools\inspect_normal_talk.py assets\_source\kakyu\ELFIMAGE\mes.arc `
  --entry D_TALK00.MES
```

### `inspect_encounter_affection.py`

Audits direct affection-delta assignments and their enclosing conditions in all 12
character `INTRO` and `OUTRO` scripts. The output records offsets, numeric
state references, hashes, and decode coverage without exporting dialogue.

```powershell
py tools\inspect_encounter_affection.py assets\_source\kakyu\ELFIMAGE\mes.arc `
  -o analysis\mes_ir\encounter_affection_audit_v1.json
```

### MES decoder support modules

These modules form the dependency chain used by `mes_basic_block_ir_v6.py`. They remain separately named so the confirmed decoding stages can be audited and regression-tested.

- `mes_expression.py`: parses and serializes confirmed AI5 reverse-Polish expressions.
- `mes_cfg_seed.py`: discovers bootstrap and address-table control-flow seeds.
- `mes_partial_decoder.py`: decodes confirmed commands, retains operand-free
  `0x0D` statement separators and fixed `0x1F` source-line markers, and
  preserves incomplete/unknown regions.
- `mes_structured_ir.py`: v4 retains shared record lists, command `0x12` typed
  records, bounded `0x0D/0x09` MMO and `0x0D/0x0B` surface envelopes, and the
  exact confirmed command `0x0E` protagonist-name insertion. Complete native
  presentation effects remain outside this structural decoder.
- `mes_iterative_ir.py`: repeats decoding as newly discovered targets become available.
- `mes_corrected_ir.py`: applies corrected operand boundaries and command interpretations.
- `mes_tolerant_ir.py`: retains auditable candidates when operands cannot be fully confirmed.
- `mes_aligned_ir.py`: reconciles instruction alignment and overlapping candidate boundaries.
- `mes_loop_ir.py`: recognizes loop-aware control-flow paths.
- `mes_control_flow_ir.py`: emits explicit instruction nodes and control-flow edges.
- `mes_fixed_point_control_ir.py`: re-seeds condition targets until decoding reaches a fixed point.
- `mes_overlapping_control_ir.py`: decodes valid paths that enter another path's operand span.
- `mes_basic_block_ir.py`: builds the initial basic-block and block-edge representation.
- `mes_basic_block_ir_v3.py`: adds overlap-aware path and basic-block handling.
- `mes_basic_block_ir_v4.py`: classifies actionable block targets, so targets
  from invalid retained candidates are audited separately rather than reported
  as missing blocks. It is the last stage that leaves command `0x03` undecoded,
  which is why a caller that inspects raw `command_03` operands binds to it
  rather than to a later stage.
- `mes_basic_block_ir_v5.py`: decodes command `0x03` global_u8 write runs
  natively. `v6` reuses its instruction decoder as its own fallback.

## Asset preparation and analysis

### `import_godot_assets.py`

Classifies a flat directory of extracted Kakyu PNG files, copies them into `assets/original/<category>`, and generates JSON/CSV catalogs. Use `--dry-run` to inspect classification without copying files.

```powershell
py tools\import_godot_assets.py assets\_extracted\kakyu\png\mmo_best . --dry-run
```

### `extract_world_map_ui.py`

Builds derived HUD, calendar, money, and dialogue UI slices from local original assets for the world-map prototype.

```powershell
py tools\extract_world_map_ui.py .
```

### `extract_voice_mapping.py`

Scans extracted MES/voice source data for broad filename-bearing markers and
writes CSV/JSON mappings used to connect scenario records with voice files.

```powershell
py tools\extract_voice_mapping.py --source-root <source-directory> --output-dir data\voice
```

### `audit_mes_voice_markers.py`

Audits the exact `0x07 FF 02 02 FF 01 <name> 00 02 00 FF 00` marker envelope
directly in `mes.arc`, checks its surrounding bit-toggle writes, and optionally
resolves the normalized filename against `voice.arc`, `tina1.arc`, and
`tina2.arc`. The report intentionally calls this a marker rather than a voice
opcode because the original executable's native `0x07` handler performs word
state writes.

```powershell
py tools\audit_mes_voice_markers.py <ELFIMAGE>\mes.arc --elfimage <ELFIMAGE> --entry EVENTD03.MES
```

### `map_path_editor.gd`

Godot editor scene logic for viewing and editing the town-map path graph in `data/maps/machi_prototype.json`. Open `tools/map_path_editor.tscn` in Godot; the `.tscn` and `.uid` files support this tool.

### `audit_unreferenced_entries.py`

Read-only check of which archive entries the shipped product never names, used
to give the Event Player corpus an `unreachable_stored_route` classification
that carries its own evidence:

```powershell
py tools/audit_unreferenced_entries.py <ELFIMAGE-directory> `
  --exe <AI5WIN.original.exe> `
  --check config/event_catalog/unreferenced_entries_v1.json
```

It takes the entries `audit_mes_dispatch_naming.gd` leaves unnamed and scans
every shipped file for each name - eight archives, `AI5WIN.INI` and the
executable, about 1.5 GB - byte-exactly and case-insensitively. It also compares
a declared duplicate pair structurally without retaining any message text:
counts, the digest of the per-message record hashes, and the per-op record
counts. The audit fails closed if the unnamed set changes, if a declared
duplicate stops sharing its message identity, or if the tracked report does not
reproduce. `classify_event_routes.py` consumes the tracked report. This joins
the headless batch whenever the original executable is supplied. See
[Unreferenced Entries](../docs/spec/mes/unreferenced_entries.md).

### `audit_duplicate_entries.py`

Groups every `.MES`/`.LIB` entry of `mes.arc` by the digest of its per-message
record hashes, without retaining any message text, then classifies each shared
group by its `SCENE_`/`EVENT` filename composition - a gallery copy of an
EVENT entry, a gallery copy of some other entry, a gallery-internal group, the
one EVENT-only twin pair, or a group with neither prefix - and reports where
the gallery is dispatched from:

```powershell
py tools/audit_duplicate_entries.py <ELFIMAGE-directory>/mes.arc `
  --check config/event_catalog/duplicate_entries_v1.json
```

For the two gallery-copy kinds it compares every gallery member against its
source entry structurally (record count, entry size, voice-marker count), and
it tallies the dispatch command every gallery entry is invoked with over the
opaque-tail envelopes in `config/event_catalog/dispatch_naming_v1.json`. The
audit fails closed if any measured count, the group-kind distribution, the
gallery-copy structural comparison, the gallery dispatch command, or the
gallery envelope distribution changes, or if the tracked report does not
reproduce. This joins the headless batch whenever ELFIMAGE is supplied. See
[Duplicate Entries](../docs/spec/mes/duplicate_entries.md).
