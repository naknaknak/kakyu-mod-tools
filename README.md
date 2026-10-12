# Kakyu Mod Tools

Kakyu Mod Tools is an unofficial, non-commercial fan project. It is not affiliated with,
endorsed by, or sponsored by the rights holders of *Kakyūsei* or its engine. All product names
and trademarks belong to their respective owners.

- **You need your own copy.** The tools read the original archives of a legally obtained copy of
  the game that you own, and never modify them.
- **No game data is included.** This repository and its builds contain no original game data: no
  images, audio, scripts, text or program code from the original. Analysis output that could
  contain original content stays on your machine and is excluded from version control.
- **All rights reserved.** The source is published for viewing only. No license is granted to
  use, copy, modify or redistribute it, beyond what GitHub's Terms of Service allow for viewing
  and forking on GitHub. Third-party components in the builds (Godot Engine, Python, Pillow) keep
  their own licenses, which ship with the builds.
- **No warranty.** The software is provided as is, without warranty of any kind.
- **Removal requests.** If you hold rights in the original and want any part of this project
  changed or removed, please open an issue on this repository. Requests are answered promptly.

Commit ids cited in the documents (the trackers under `todo/` and the pages under `docs/`) refer to this project's development history, which is not public; they do not resolve in this repository.

The original analyzer for *Kakyusei* (AI5WIN): it reads the user-owned
original archives, establishes what the original does, records the
evidence under `docs/spec/`, and authors changed content from it. The mod
player is the separate `kakyu-remake` repository, which consumes the
playback package and the fingerprinted contracts this repository exports
and never reads an original archive. `docs/spec/tech/product_roles.md`
fixes that boundary; `AGENTS.md` holds the working rules every contributor
and agent follows; `TODO.md` is the priority summary and `todo/` the
domain trackers.

This file is the **new-machine guide**: what to install, what to create
locally, how to verify the checkout, and what only exists on a machine
that has already done the work.

## Requirements

- Windows 11. Paths and the launcher below are Windows-specific; the
  Content Suite is also exported as Windows applications
  (`docs/spec/tech/windows_distribution.md`).
- **Python 3.12 or newer with the `py` launcher** (the tools are run as
  `py tools\...` from the project root; the current development machine
  runs 3.14). Do not use a bare `python`: on a machine with the Microsoft
  Store stub it exits without running anything. Pillow is required by the
  image tools and by parts of the validation batch:
  `py -m pip install Pillow`, then `py -c "from PIL import Image; print(Image.__version__)"`.
- **Godot 4.7 stable, the console executable** (`Godot_v4.7-stable_win64_console.exe`).
  `winget install GodotEngine.GodotEngine` places it under
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\`,
  where `tools\content_suite\run_headless_validation.py` finds it on its
  own; any other location is passed with `--godot`. Godot scripts are run
  as `<console exe> --headless --path . --script res://<path>.gd -- <args>`
  - never with a bare positional path, which opens the launcher scene in an
  idle headless loop that never exits.
- Git. The default branch is `main`; direct commits to it are the rule
  (`AGENTS.md`, "Git Workflow").
- The **user-owned original game**: the `ELFIMAGE` directory (with
  `mes.arc` and the other archives) and the original `AI5WIN.exe` (the
  audits take the unpatched executable; on the development machine it is
  kept as `AI5WIN.original.exe`). Both are read-only inputs and are never
  copied into the repository.

## Setting up a new machine

1. Clone the repository and, beside it if you use the mod player too,
   `kakyu-remake` (this repository never edits it and no tracked tool or
   test reads it; the specifications cross-reference its documents by
   path).
2. Create the gitignored local source-path file `.agents/local/source_paths.md`:

   ```markdown
   # Local Reverse-Engineering Source Paths

   - `ELFIMAGE`: `<absolute path to the original ELFIMAGE directory>`

   These paths are machine-local, read-only inputs. Do not copy original game data into tracked project files.
   ```

   Agents read this file before making any claim about the original; the
   validation batch takes the same directory as `--elfimage` and the
   executable as `--exe` on the command line.
3. Import the Godot project once (creates the gitignored `.godot/` cache;
   required before any headless script or scene runs):

   ```powershell
   <console exe> --headless --path . --import
   ```

4. Parse-check the project and run the local validation tier - no
   original data needed, about three minutes with four jobs:

   ```powershell
   <console exe> --headless --path . --check-only --quit
   py tools\content_suite\run_headless_validation.py --tier local --jobs 4
   ```

   Expect every check to pass (135 checks at the time of writing; the
   report JSON the run writes is the record). The Python suite alone is
   `py -m unittest discover -s tests -p "test_*.py"` (about five minutes).
5. Run the full batch once with the original data to confirm the archive
   is the one the repository was built against (its SHA-256 is pinned in
   the tools and the profiles):

   ```powershell
   py tools\content_suite\run_headless_validation.py `
     --elfimage "<user-owned-ELFIMAGE>" `
     --exe "<user-owned-AI5WIN.exe>" `
     --jobs 6 --cache-store
   ```

   About an hour with six jobs (66 minutes measured on a 6-core, 16 GB
   machine, 2026-10-03); `--cache-store` also stores each green result, so
   the same command with `--cached` in place of it re-verifies an unchanged
   tree in seconds. A run this long should be started detached from the
   shell (`tools/content_suite/launch_detached.py`). `--tier archive_quick`
   and `--cached` exist for iteration; `--check "<name>"` runs one
   registered check (`config/validation/checks_v1.json` lists them).

## Machine-local evidence that does not travel

Everything under `assets/`, `data/`, `analysis/`, `reverse_engineering/`
and `output/` is gitignored (`.gitignore`). `analysis/` is the working
scratch space and, on a machine that has done the work, holds evidence
some regeneration tools read **by default**:

| Path | Read by | If missing |
|---|---|---|
| `analysis/replays_v2/<profile stem>.json` | the event-definition producers (`tools/project_event_definition_v4/v5/v6.py`, `project_event_definitions_batch.py`) | regenerated per profile by the group validator's `--replay` mode (`tools/content_suite/validators/validate_event_analysis_group.gd`); the batch regenerates catalog replays it lacks when given `--elfimage` |
| `analysis/witnesses/`, `analysis/witness_requests/` | the same producers (effect witnesses; without them more effects are `unresolved` by name, never wrong) | `tools/plan_event_effect_witnesses.py` and the witness runner |
| `analysis/event-corpus-inventory-<date>.json`, `analysis/event-analysis.json` | `tools/refresh_route_classification.py` (default `--inventory`) and the classifier | written by `tools/content_suite/cli/audit_mes_event_corpus_inventory.gd`'s optional JSON argument (`tools/README.md`, that section) and by `tools/build_event_analysis_inventory.py` |
| `analysis/<caller>_group_measure.json`, `analysis/*_spec.json` | the route toolchain (`draft_event_route_spec.py`, `qualify_event_route.py`, `draft_date_flow_specs.py`) | rebuilt by `analysis/build_<caller>_group_measure.py` (itself under `analysis/`) or re-drafted |
| `analysis/_docs/*.md` | the unit specifications handed to implementer agents | only needed to re-read a unit's intent; the landed result is in the tracked docs and trackers |
| `analysis/_undoc/` | measurement reports the tracked documents cite as "untracked" | evidence for the claims in `docs/spec/mes/`; re-measure if a claim must be re-checked |
| `analysis/playback_package_*` | the exported playback packages the definitions bind by hash | re-exported by the package exporter (`--check "original playback package export"` writes one) |
| `analysis/replays_v3/<profile stem>.json` (227 files, about 121 MB, `kakyu_event_analysis_group_replay/v3`: v2 plus per-run `executed` and `resource_rows`) | `tools/project_event_definition_v7.py` and `project_event_definitions_batch.py --contract v7` (the measured `resources` of each v7 document), beside `analysis/replays_v2/` for the v4-v6 producers | regenerated by `tools/regenerate_group_replays.py <ELFIMAGE> --out analysis/replays_v3 --jobs N` (about 20 minutes at `--jobs 4`, one validator process per profile) |
| `analysis/playback_package_ep14/` (package `fe9bb6bd...`, Core 0.378.0, catalog revision 43; the one the live v7 set is bound to; `td56b`, `0e47e063...`, is the Core 0.377.0 export it replaces, equal to it outside the manifest's `package_sha256` and `content_core_version`, and `td56a`, `3af3779f...`, the revision-42 export the set was projected against) | `tools/validate_event_definition.py --package`, the v7 projector and the rebind | re-exported by the package exporter to a new directory, then `tools/rebind_event_definitions.py` (`--pair core-version` when only the Core version moved, `--pair catalog-revision` when only the catalog revision moved; `config/event_definitions/v7/README.md`) |
| `analysis/event_definitions_v7_resolved/` (the v7 documents with their dialogue text) | nothing reads it; the local record of what the tracked documents reference | written by the batch's `--resolved-out`; never tracked |

To continue analysis work on another machine either copy these
directories from the machine that has them (the whole `analysis/` is
several gigabytes because of decoder digests and batch logs; the
directories above are a few hundred megabytes) or regenerate them with
the tools named. The tracked state - `config/`, `docs/`, the tests - is
complete without them: validation and playback read no evidence from
`analysis/` (the batch writes its cache and worker directories there,
`analysis/validation_cache` and `analysis/validation_workers/<run>`,
creating them as needed).
The batch runner also keeps an empty, untracked `analysis/.gdignore`
(written before any check, only when `analysis/` exists and has none,
never rewritten) so the Godot editor's project scan skips the directory
(TD-52).

## How the project is developed

The project is developed with AI agents; `AGENTS.md` holds the rules they and every contributor follow.

## Where the work is

- `AGENTS.md` - rules: runtime, source of truth, routing, boundaries,
  verification.
- `TODO.md` -> `todo/mes_pipeline.md` (phase gates and execution order)
  -> the domain tracker of the current item (`todo/event_player.md`,
  `todo/code_health.md`, ...). Each item's dated bullets say what landed,
  in which commit, and what is next.
- `docs/spec/index.md` - every specification this repository owns; the
  MES evidence is under `docs/spec/mes/`, the contracts the remake reads
  under `config/contracts/` (each directory's README records its
  revision and fingerprint).
- `tools/README.md` - every tool's purpose and usage line.
