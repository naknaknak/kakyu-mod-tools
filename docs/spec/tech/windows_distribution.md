# Windows application distribution

Core 0.306.0 ships six independent Windows x64 release applications: ARC Browser,
MES Editor, Image Editor, Audio Editor, Event Player and Content Suite. Each has
its own EXE/PCK pair and default scene. `ContentSuite.exe` opens the launcher;
the named executables also work directly. The shared `runtime/` directory must
stay beside them. This is the analyzer/tool suite; it includes no original game
archives and does not change the separately maintained mod player.

## Reproducible build inputs

`config/distribution/applications_v1.json` is the versioned, fingerprinted
application catalog (`kakyu_windows_applications/v1`). Its rows bind executable
name, export preset and scene. Both the builder and release app launcher consume
it. `config/distribution/windows_runtime_v1.json` pins the source URLs, SHA256
hashes and sizes under `kakyu_windows_runtime_sources/v1`:

- [Godot 4.7 stable export templates](https://github.com/godotengine/godot-builds/releases/tag/4.7-stable),
  selecting only the Windows x64 release executable.
- [Python 3.14.5 Windows embedded distribution](https://www.python.org/downloads/release/python-3145/).
- [Pillow 12.2.0 Windows CPython 3.14 wheel](https://pypi.org/pypi/pillow/12.2.0/json).

These are pinned tested versions, not an assertion that each is the newest
available version. Download the locked files to a local dependency directory;
the builder verifies their hashes and does not fetch anything at runtime.
From the project root:

```powershell
py tools/build_windows_distribution.py --godot "<Godot 4.7 console executable>" --dependencies analysis/windows-dependencies-20260908 --output analysis/windows-suite-0306-20260908
py tools/build_windows_distribution.py --verify analysis/windows-suite-0306-20260908
```

The destination must be a new directory under `analysis/`. A temporary source
copy contains only project/export configuration, `content_core/`, `tools/`,
`config/` and `shaders/` from the Git file inventory. Original/local-only data,
tests and documentation are excluded. Export settings and the audit autoload
are changed only in that copy; the repository launcher main scene is preserved.
Each release app is launched and audited headlessly before a complete file
inventory is hashed and the distribution directory is published by rename.
Failed staging stays local for diagnosis; existing destinations are preserved.

## Runtime and launch contracts

`runtime/manifest.json` uses `kakyu_python_runtime/v1` with exactly `schema`,
`core_version`, `python_version`, `pillow_version`, `files` and `payload_sha256`.
File rows contain a relative `path`, byte `size` and `sha256`. The runtime reader
checks schema, current Core version, manifest hash, safe unique paths, every
file's size/hash and the complete recursive file inventory. Missing, changed or
extra files fail closed. There is no release fallback to installed Python.

The embedded Python `_pth` contains only `python314.zip`, its own directory and
`../tools`. It does not import `site`; all application worker calls use `-B`,
so the immutable runtime does not accumulate bytecode caches. This follows the
[embedded distribution isolation model](https://docs.python.org/3.14/using/windows.html#the-embeddable-package).
The authoring session, original-to-authored binding verifier and delta importer
all resolve their workers through `python_runtime.gd`. Python/Pillow licenses
are retained with the runtime and each app has its Godot license report.

The builder also writes `runtime/.gdignore` before inventory hashing, so Python's
copied Core version metadata cannot register a duplicate global class if the
distribution is unpacked inside a Godot project. The retained Core 0.306.0
artifact below predates this correction. Keep that artifact outside an active
Godot project or put `.gdignore` in its containing output directory, outside
the signed bundle; adding files inside that existing bundle would invalidate
its inventory. This correction is tracked as TD-28.

Godot's release templates disable engine path overrides, including `--path`
and `--script`; see the availability legend in the
[command-line reference](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).
`application_process.gd` therefore selects a named companion executable for
launcher handoff and MES Editor Run. Existing source/workspace/request/proof
arguments remain application arguments after `--`. Development runs retain the
editor executable and scene-path convention. Missing companions and unlisted
scenes produce errors instead of reopening the current application.

Only the export copy enables `distribution_bootstrap.gd`. The headless user
argument `--distribution-audit` invokes the same audit helper as the development
CLI. It verifies the configured and actual default scene, scans resource paths,
runs the bundled synthetic analyzer/compiler/Pillow diagnostic and writes a
license report to the explicitly supplied output path.

The root `manifest.json` uses `kakyu_windows_distribution/v1`. It binds the Core
and Godot versions, release runtime kind, runtime/source-lock hashes, application
audits, explicit clean-machine/native-identity status and full file inventory.
`--verify` rejects changed schema/hash, unsafe or duplicate paths, file changes
and extra files. These JSON hashes omit only `payload_sha256` and use sorted
compact UTF-8 JSON. Runtime/application metadata uses integer counts, with
Godot's existing whole-float-normalizing fingerprint helper. The root
distribution manifest is written and checked in Python, preserving its embedded
audit values. This is separate from the Python analyzer handoff's exact numeric
serialization policy.
Hashes detect inconsistent artifacts; they are not publisher signatures.
Incompatible manifest versions are rejected and require rebuilding the bundle.

## Verified artifact and limits

`analysis/windows-suite-0306-20260908/` contains 329 inventoried files plus the
root manifest. Distribution fingerprint:
`bc6e095ee6eeb6f7a936f742599875bbc96e670173411686d225fdee6d683874`.
The ZIP is `analysis/KakyuContentTools-0.306.0-win-x64.zip`, 277,235,550 bytes,
SHA256 `debbee4130e596fedb160985a02c659ecddc65d9fa07b87b4ae578dd1d892468`.

All six release apps report their correct scene, 561 exported resources, zero
original/local-only payload paths and `editor_feature=false`. Each passes the
synthetic Python Phase 1-4/state-edit/reopen diagnostic, binding/delta imports
and Pillow native image resizing. After publication to the final directory,
the six audits pass again from a separate empty working directory with host
Python removed from PATH. The distribution remains unchanged after execution
and the ZIP passes CRC verification. Evidence is in
`analysis/windows-suite-build-r3.log`, `analysis/windows-portable-verification.log`
and `analysis/windows-portable-probe-20260908/report.json`.

Repository checks pass: five Python packaging tests; five focused Godot
parse/launcher/runtime/state/message checks in
`analysis/windows-release-entry-validation.json`; and the extended runtime
test covering all six companion executable mappings. This does not rerun or
replace the earlier full original/native corpus baseline.

This is development-machine headless evidence. GUI/DPI, audio,
memory/cancellation and crash-recovery verification retain their domain owners.
The clean-Windows check (WD-20) was closed unverified by owner ruling on
2026-10-09, and `clean_machine_verified` stays `false`. The executable icons are
Godot's default by owner ruling of the same day (WD-14 closed); neither
`project.godot` nor `export_presets.cfg` sets one. Since 2026-09-18 the build enables PE resource
modification (Godot 4.7 rewrites the version resource itself, without rcedit),
sets the file and product version of every app to the Core version plus a zero
build number, and reads each exported executable back with
`tools/windows_pe_version.py`: the fixed versions must equal the Core version
and the product name and description must equal the export preset's, or the
build fails. Each application report in the manifest carries that `identity`
and the manifest states `native_version_metadata: true`;
`native_identity_metadata` stays false until the icons are the suite's own.
Before this change every app identified itself as `Godot Engine`, file version
`4.7`. Verified 2026-09-18 by a complete build at Core 0.344.0 (`analysis/windows-suite-0344-20260918/`, 667 inventoried files, distribution fingerprint `6033edf76ed2823a7fe9422da94b35561fe0de81e696ca153acd19a026a5b9c6`): all six apps export, carry `0.344.0.0` with their own description, run and pass the distribution audit with host Python off the PATH, `--verify` reopens the inventory, and rereading each executable reproduces the identity the manifest records; `tests/test_windows_pe_version.py` (6 tests, a synthetic PE), the local batch (121 checks, Python 1,554). Rebuilt 2026-09-19 at Core 0.350.0 for the manual batch of `todo/manual_verification.md` (WD-19): `analysis/windows-suite-0350-20260919/` (931 inventoried files, distribution fingerprint `fd9085a06370021e8e0ae89e0adb2b74d6d720918398de8df669911d1e1fc16e`, all six apps verified at `0.350.0.0`, built in 49 s from the pinned 2026-09-08 dependencies; the 264 files added since the 0.344.0 build are the v4 event definitions, the contract fixtures and the definition tools). The development validation batch is not
shipped, although saved validation reports remain readable. Optional native
executable-audit dependencies such as Capstone/LIEF are not included. Broader
MES edit families and portable authored delta features retain their existing
scope; bundling their Python backend does not close those capabilities.

Rebuilt 2026-09-21 at Core 0.356.0 (`analysis/windows-suite-0356-20260921/`,
942 inventoried files, distribution fingerprint `7f3d4113a31c344d60522d07ec0a290b53b75e54a2cedeff8996033e5c8d5388`, all six apps verified
from the pinned 2026-09-08 dependencies) after EP-10 unit 5 retired the
per-event Event Player code; this is the build the WD-19 run sheet targets.
