"""Build six Windows apps with release templates and an isolated Python runtime.

Inputs are pre-downloaded upstream archives whose hashes are pinned in config.
Only a new analysis/ directory is published; the project and installed runtimes
are never edited. Run --verify DIRECTORY to recheck a published file inventory.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

from windows_distribution_common import ROOT, run
from windows_pe_version import read_version_info

SCHEMA = "kakyu_windows_distribution/v1"
RUNTIME_SCHEMA = "kakyu_python_runtime/v1"


def native_version(core: str) -> str:
    """The four-part Windows version resource value for a Core version."""
    if not re.fullmatch(r"\d+\.\d+\.\d+", core):
        raise ValueError("Core version is not three dotted numbers")
    return core + ".0"


def preset_identities(presets: str) -> dict[str, dict[str, str]]:
    """Map each export preset name to the product name and description it declares."""
    names = {index: name for index, name in re.findall(r'^\[preset\.(\d+)\]\s*\nname="([^"]*)"', presets, re.M)}
    identities: dict[str, dict[str, str]] = {}
    for index, body in re.findall(r"^\[preset\.(\d+)\.options\]\s*\n(.*?)(?=^\[|\Z)", presets, re.M | re.S):
        fields = dict(re.findall(r'^application/(product_name|file_description)="([^"]*)"', body, re.M))
        if index in names:
            identities[names[index]] = fields
    return identities


def check_identity(identity: dict, expected_version: str, declared: dict[str, str]) -> None:
    """Require the exported executable to carry the suite's identity, not the template's."""
    strings = identity.get("strings", {})
    if identity.get("file_version") != expected_version or identity.get("product_version") != expected_version:
        raise ValueError("Exported app version resource differs from the Core version")
    if not declared.get("product_name") or not declared.get("file_description"):
        raise ValueError("Export preset declares no product name or description")
    if strings.get("ProductName") != declared["product_name"] or strings.get("FileDescription") != declared["file_description"]:
        raise ValueError("Exported app identity strings differ from the export preset")

def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def fingerprint(value: dict) -> str:
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def write_manifest(path: Path, value: dict) -> dict:
    value = {**value, "payload_sha256": fingerprint(value)}
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    return value


def relative_name(name: str) -> bool:
    return bool(name) and not any(c in name for c in "\\:") and all(p not in ("", ".", "..") for p in name.split("/"))


def inventory(root: Path) -> list[dict]:
    return [{"path": path.relative_to(root).as_posix(), "size": path.stat().st_size, "sha256": digest(path)}
            for path in sorted(root.rglob("*")) if path.is_file()]


def verify_distribution(root: Path) -> dict:
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    claimed = manifest.pop("payload_sha256", None)
    if manifest.get("schema") != SCHEMA or claimed != fingerprint(manifest):
        raise ValueError("Distribution schema or fingerprint changed")
    seen = set()
    for row in manifest["files"]:
        name = row["path"]
        if not relative_name(name) or name.lower() in seen:
            raise ValueError("Invalid or duplicate distribution path")
        seen.add(name.lower())
        path = root / name
        if not path.resolve().is_relative_to(root.resolve()) or path.stat().st_size != row["size"] or digest(path) != row["sha256"]:
            raise ValueError(f"Distribution file changed: {name}")
    actual = {p.relative_to(root).as_posix().lower() for p in root.rglob("*") if p.is_file() and p != root / "manifest.json"}
    if seen != actual:
        raise ValueError("Distribution file inventory changed")
    return {"ok": True, "schema": SCHEMA, "payload_sha256": claimed, "files": len(seen)}


def unpack(archive: Path, root: Path) -> None:
    with zipfile.ZipFile(archive) as zip_file:
        for item in zip_file.infolist():
            if item.is_dir():
                continue
            if not relative_name(item.filename):
                raise ValueError("Archive contains an unsafe path")
            target = root / item.filename
            target.parent.mkdir(parents=True, exist_ok=True)
            with zip_file.open(item) as source, target.open("xb") as destination:
                shutil.copyfileobj(source, destination)


def build(godot: Path, dependencies: Path, output: Path) -> dict:
    output = output.resolve()
    if not output.is_relative_to(ROOT / "analysis") or output.exists():
        raise ValueError("Output must be a new directory under project analysis/")
    lock = json.loads((ROOT / "config/distribution/windows_runtime_v1.json").read_text(encoding="utf-8"))
    claimed = lock.pop("payload_sha256", None)
    if lock.get("schema") != "kakyu_windows_runtime_sources/v1" or fingerprint(lock) != claimed:
        raise ValueError("Runtime source lock changed")
    for row in lock["downloads"]:
        if not relative_name(row["name"]) or digest(dependencies / row["name"]) != row["sha256"]:
            raise ValueError("Downloaded runtime does not match its upstream hash")
    apps = json.loads((ROOT / "config/distribution/applications_v1.json").read_text(encoding="utf-8"))
    app_hash = apps.pop("payload_sha256", None)
    if apps.get("schema") != "kakyu_windows_applications/v1" or app_hash != fingerprint(apps):
        raise ValueError("Application catalog changed")
    version = run([str(godot), "--version"], ROOT).strip()
    if not version.startswith("4.7.stable"):
        raise ValueError("Godot 4.7 stable is required")
    output.parent.mkdir(parents=True, exist_ok=True)
    build_root = Path(tempfile.mkdtemp(prefix=".windows-release-", dir=output.parent))
    project, stage = build_root / "project", build_root / "distribution"
    project.mkdir()
    stage.mkdir()
    # Export from a source-only copy, so no local data or machine paths can enter
    # the resource scanner. Failed staging is retained for diagnosis.
    tracked = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=ROOT, text=True).splitlines()
    for name in tracked:
        path = Path(name)
        if name not in ("project.godot", "export_presets.cfg") and path.parts[0] not in ("content_core", "tools", "config", "shaders"):
            continue
        target = project / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / path, target)
    core = re.search(r'const CORE_VERSION := "([^"]+)"', (ROOT / "content_core/content_core_version.gd").read_text()).group(1)
    template = build_root / "windows_release_x86_64.exe"
    with zipfile.ZipFile(dependencies / lock["godot_archive"]) as archive:
        template.write_bytes(archive.read("templates/windows_release_x86_64.exe"))
    if not run([str(template), "--version"], build_root).startswith("4.7.stable"):
        raise ValueError("Release template version differs")
    presets = (project / "export_presets.cfg").read_text(encoding="utf-8")
    # Godot 4.7 rewrites the template's version resource itself (no rcedit); without
    # it every app would present itself as "Godot Engine 4.7".
    identities = preset_identities(presets)
    version_resource = native_version(core)
    presets = re.sub(r'(\[preset\.\d+\.options\])', lambda match: match[0] + '\ncustom_template/release="' + template.as_posix()
        + '"\napplication/modify_resources=true\napplication/file_version="' + version_resource
        + '"\napplication/product_version="' + version_resource + '"', presets)
    (project / "export_presets.cfg").write_text(presets, encoding="utf-8")
    settings = project / "project.godot"
    settings.write_text(settings.read_text(encoding="utf-8") + '\n[autoload]\nDistributionBootstrap="*res://tools/content_suite/distribution_bootstrap.gd"\n', encoding="utf-8")
    run([str(godot), "--headless", "--path", str(project), "--editor", "--import"], project)
    runtime = stage / "runtime"
    unpack(dependencies / lock["python_archive"], runtime / "python")
    unpack(dependencies / lock["pillow_archive"], runtime / "python")
    # Python reads Core version metadata as text. An extracted distribution
    # inside another Godot project must not register its copied global class.
    with (runtime / ".gdignore").open("x", encoding="utf-8"):
        pass
    (runtime / "python/python314._pth").write_text("python314.zip\n.\n../tools\n", encoding="utf-8")
    for name in tracked:
        path = Path(name)
        if not (path.parts[0] == "tools" and len(path.parts) == 2 and path.suffix == ".py") and path.parts[0] != "config" and name != "content_core/content_core_version.gd":
            continue
        target = runtime / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / path, target)
    # Explicitly exercise Pillow's native extension and compiler imports before
    # signing the runtime. The embedded _pth ignores user site/PYTHONPATH.
    python = runtime / "python/python.exe"
    python_smoke = run([str(python), "-B", "-c", "import sys,json,PIL; from PIL import Image; import mes_authoring_workflow,mes_authoring_binding,authored_mod_delta; assert Image.new('RGB',(2,2)).resize((4,4)).size==(4,4); print(json.dumps({'python':sys.version.split()[0],'pillow':PIL.__version__,'isolated':sys.flags.isolated,'sys_path':sys.path}))"], build_root, isolated=True)
    python_result = json.loads(python_smoke)
    if python_result["python"] != lock["python_version"] or python_result["pillow"] != lock["pillow_version"] or python_result["isolated"] != 1:
        raise ValueError("Bundled runtime identity or isolation changed")
    runtime_manifest = write_manifest(runtime / "manifest.json", {"schema": RUNTIME_SCHEMA, "core_version": core,
        "python_version": lock["python_version"], "pillow_version": lock["pillow_version"], "files": inventory(runtime)})
    reports = []
    for app in apps["applications"]:
        name = Path(app["executable"]).stem
        preset, scene = app["preset"], Path(app["scene"]).stem
        executable = stage / (name + ".exe")
        exported = run([str(godot), "--headless", "--path", str(project), "--export-release", preset, str(executable)], project)
        (build_root / (name + ".export.log")).write_text(exported, encoding="utf-8")
        identity = read_version_info(executable)
        check_identity(identity, version_resource, identities.get(preset, {}))
        run([str(executable), "--headless", "--quit-after", "3"], build_root, isolated=True)
        audit = run([str(executable), "--headless", "--", "--distribution-audit",
                     str(stage / (name + ".licenses.json")), scene, "--require-python"], build_root, isolated=True)
        rows = [json.loads(line) for line in audit.splitlines() if line.startswith('{"')]
        if not rows or not rows[-1].get("ok"):
            raise ValueError("Exported app audit did not report success")
        reports.append({"application": name, "audit": rows[-1], "identity": identity})
        print("VERIFIED", name, flush=True)
    (stage / "README.txt").write_text(
        "Kakyu Content Tool Suite " + core + "\n\nOpen ContentSuite.exe or any named app executable.\n"
        "Keep the shared runtime directory beside the applications. No Python installation or PATH changes are needed.\n"
        "Supply your own source archives read-only and a named workspace. No original game data is included.\n"
        "This build uses Godot 4.7 release templates and an isolated Python/Pillow runtime.\n"
        "Per-app Godot licenses and runtime Python/Pillow licenses are included.\n"
        "Headless tests ran with host Python removed from PATH, from outside the project checkout.\n"
        "Each executable carries the suite's version, product name and description; the build reads them back.\n"
        "Clean-Windows, GUI/DPI/audio checks and executable icons remain unverified.\n"
        "The developer validation runner is not shipped; saved validation reports remain readable.\n", encoding="utf-8")
    write_manifest(stage / "manifest.json", {"schema": SCHEMA, "core_version": core, "godot_version": version,
        "runtime_kind": "release_template", "runtime_payload_sha256": runtime_manifest["payload_sha256"],
        "source_lock_sha256": claimed, "clean_machine_verified": False, "native_identity_metadata": False,
        "native_version_metadata": True,
        "applications": reports, "files": inventory(stage)})
    verified = verify_distribution(stage)
    if output.exists():
        raise ValueError("Distribution output appeared during publication")
    stage.rename(output)
    return {**verified, "applications": len(reports), "runtime_kind": "release_template"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--dependencies", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--verify", type=Path)
    args = parser.parse_args()
    if args.verify:
        result = verify_distribution(args.verify.resolve())
    elif args.godot and args.dependencies and args.output:
        result = build(args.godot.resolve(), args.dependencies.resolve(), args.output)
    else:
        parser.error("Pass --godot, --dependencies and --output, or --verify")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
