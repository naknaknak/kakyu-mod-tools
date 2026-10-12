"""Build an early ARC Browser Windows artifact from the installed Godot runtime.

This explicitly uses the installed editor-capable engine, not a release export
template. It verifies the resource pack in isolation and includes runtime licenses.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

from windows_distribution_common import ROOT, run

def build(godot: Path, output: Path) -> dict:
    output = output.resolve()
    if not output.is_relative_to(ROOT / "analysis") or output.exists():
        raise ValueError("Prototype output must be a new directory under project analysis/")
    version = run([str(godot), "--version"], ROOT).strip()
    if not version.startswith("4.7.stable"):
        raise ValueError("The repository requires Godot 4.7 stable")
    runtime = godot.with_name(godot.name.replace("_console.exe", ".exe"))
    if not runtime.is_file():
        raise ValueError("The installed Windows engine executable is missing")
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".windows-prototype-", dir=output.parent)).resolve()
    # Failed staging is retained for diagnosis; no recursive cleanup touches inputs.
    pack = stage / "ArcBrowser.pck"
    log = run([str(godot), "--headless", "--path", str(ROOT), "--export-pack", "Windows ARC Browser", str(pack)], ROOT)
    (stage / "export.log").write_text(log, encoding="utf-8")
    shutil.copy2(runtime, stage / "ArcBrowser.exe")
    startup = run([str(stage / "ArcBrowser.exe"), "--headless", "--quit-after", "3"], stage)
    (stage / "startup.log").write_text(startup, encoding="utf-8")
    audit = run([str(stage / "ArcBrowser.exe"), "--headless", "--main-pack", str(pack),
                 "--script", "res://tools/content_suite/cli/audit_windows_distribution.gd", "--", str(stage / "LICENSES.json")], stage)
    (stage / "smoke.log").write_text(audit, encoding="utf-8")
    rows = [json.loads(line) for line in audit.splitlines() if line.startswith('{"')]
    if not rows or rows[-1].get("ok") is not True or rows[-1].get("original_payload_files") != 0:
        raise ValueError("Exported application audit did not establish a clean resource inventory")
    (stage / "Open-ARC-Browser.cmd").write_text(
        '@echo off\r\n"%~dp0ArcBrowser.exe" %*\r\n', encoding="utf-8")
    (stage / "README.txt").write_text(
        "Kakyu ARC Browser prototype\nOpen-ARC-Browser.cmd starts the independent ARC Browser.\n"
        "No original game files are included. Supply your own content set or named workspace.\n"
        "Runtime: installed Godot 4.7 stable editor-capable engine, with licenses in LICENSES.json.\n"
        "This is an early development-machine artifact, not a clean-machine release.\n"
        "Python/Pillow are not bundled; this ARC Browser smoke does not certify Python authoring tools.\n"
        "Native Windows export templates, app icons, DPI/GUI checks and clean-machine verification remain open.\n", encoding="utf-8")
    files = [{"name": path.name, "size": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
             for path in sorted(stage.iterdir()) if path.is_file()]
    manifest = {"schema": "kakyu_windows_prototype/v1", "application": "arc_browser", "godot_version": version,
                "runtime_kind": "installed_editor_binary", "release_template": False, "python_bundled": False,
                "clean_machine_verified": False, "headless_resource_audit": rows[-1], "files": files}
    manifest["payload_sha256"] = hashlib.sha256(json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    (stage / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if output.exists():
        raise ValueError("Prototype output appeared during publication")
    stage.rename(output)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = build(args.godot.resolve(), args.output)
    print(json.dumps({"ok": True, "schema": result["schema"], "payload_sha256": result["payload_sha256"],
                      "files": len(result["files"]), "runtime_kind": result["runtime_kind"]}))


if __name__ == "__main__":
    main()
