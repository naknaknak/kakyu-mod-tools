# Early Windows application artifact

Historical first artifact. The six-app release delivery and bundled
Python runtime are now described in [Windows Application Distribution](windows_distribution.md).
The limitations below describe this retained prototype, not the current build.

Six presets in `export_presets.cfg` select ARC Browser, MES Editor, Image Editor,
Audio Editor, Event Player or Content Suite. Custom features choose the relevant
main scene; normal repository startup remains Content Suite. Export excludes
local-only assets, extracted data, analysis, reverse-engineering data, tests,
documentation and local agent configuration.

`tools/build_windows_prototype.py` builds the first ARC Browser artifact with the
installed Godot 4.7 stable engine and `ArcBrowser.pck`. The executable and pack
share a basename, so direct launch opens ARC Browser without a checkout or extra
arguments. An optional command wrapper forwards arguments. Runtime licenses,
file hashes, dependency limits and verification logs accompany the output.
Publication requires a fresh directory under local `analysis/`.

The export-template directory is empty, so the runtime is explicitly the installed
editor-capable engine. This is not a release-template or clean-machine claim.
Python/Pillow are not bundled. The present smoke certifies ARC Browser, not Python
authoring in an exported editor. Release templates, icons/native metadata,
runtime dependencies, other app builds, DPI/GUI checks and clean-machine testing
remain open.

`analysis/windows-arc-browser-20260908/` retains the verified artifact. Its default
scene, direct executable startup and 545 exported resources pass in the isolated
output directory with zero original/local-only payload paths. The resource pack
is about 5.54 MB; the engine dominates the approximately 184 MB directory.
`LICENSES.json` records Godot and third-party licenses. No manual GUI or original
engine verification ran.
