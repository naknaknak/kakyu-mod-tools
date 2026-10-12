"""Python check over a mod workspace's `definitions/` records (mod event
definition unit B, section D): a mirror of the manifest header checks
`content_core/overlay_package.gd`'s `_validate_manifest` applies to a
`kakyu_content_overlay/v1` manifest's `definitions` array, followed by the
full `kakyu_mod_event_definition/v1` contract check
(`tools/validate_mod_event_definition.py`) on each stored document.

    py tools/validate_workspace_definitions.py <workspace root>
        [--names config/contracts/event_names_v1]
        [--definitions-dir config/event_definitions/v4]

Prints one JSON summary
``{"ok", "workspace", "definitions": n, "failures": [{"definition_id",
"stage": "manifest" | "contract", "reason", "detail"}]}`` and exits 0 when
``ok`` is true, 1 otherwise. Importable as
``check_workspace(root, names_dir, definitions_dir) -> dict``.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import validate_mod_event_definition as moddef  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
DEFINITION_ID_RE = re.compile(r"^mod\.([a-z][a-z0-9_]{1,31})\.[a-z][a-z0-9_]{0,63}$")
MOD_ID_RE = re.compile(r"^[a-z][a-z0-9_]{1,31}$")
TARGET_ID_RE = re.compile(r"^[a-z]+\.(school|town|date|special)\.[a-z0-9_]+\.[a-z0-9]+\.[1-9]$")

STRING_FIELDS = (
    "kind", "schema", "definition_id", "definition_kind", "mod_id", "target_id",
    "definition_sha256", "definition_path", "contract_fingerprint", "cells_fingerprint",
    "compatibility", "text_encoding",
)


def _default_fingerprint() -> str:
    path = ROOT / "config" / "contracts" / "mod_event_definition_v1" / "contract_fingerprint"
    return path.read_text(encoding="utf-8").strip() if path.is_file() else ""


def _default_cells_fingerprint() -> str:
    path = ROOT / "config" / "contracts" / "state_cells_v1" / "cells_fingerprint"
    return path.read_text(encoding="utf-8").strip() if path.is_file() else ""


def _is_safe_definition_path(value: str) -> bool:
    if not value or value.startswith("/") or "\\" in value or ":" in value:
        return False
    parts = value.split("/")
    if len(parts) != 2 or parts[0] != "definitions":
        return False
    for part in parts:
        if part in ("", ".", ".."):
            return False
    return True


def _record_header_error(record: dict, where: str) -> str | None:
    if not isinstance(record, dict):
        return f"{where}: not an object"
    for field in STRING_FIELDS:
        value = record.get(field)
        if not isinstance(value, str):
            return f"{where}: {field} missing or not a string"
        if field != "target_id" and value == "":
            return f"{where}: {field} is empty"
    mod_revision = record.get("mod_revision")
    if not isinstance(mod_revision, int) or isinstance(mod_revision, bool) or mod_revision < 1:
        return f"{where}: mod_revision must be an integer >= 1"
    if record.get("kind") != "mod_event_definition":
        return f"{where}: kind must be mod_event_definition"
    if record.get("schema") != moddef.SCHEMA_VERSION:
        return f"{where}: schema must be {moddef.SCHEMA_VERSION!r}"
    if record.get("compatibility") != "remake_only":
        return f"{where}: compatibility must be remake_only"
    if record.get("text_encoding") != "utf8":
        return f"{where}: text_encoding must be utf8"
    definition_id = record.get("definition_id", "")
    match = DEFINITION_ID_RE.match(definition_id)
    if not match:
        return f"{where}: definition_id {definition_id!r} does not match the pattern"
    mod_id = record.get("mod_id", "")
    if not MOD_ID_RE.match(mod_id):
        return f"{where}: mod_id {mod_id!r} does not match the pattern"
    if match.group(1) != mod_id:
        return f"{where}: mod_id {mod_id!r} does not match the definition id"
    definition_kind = record.get("definition_kind")
    if definition_kind not in ("new_event", "override"):
        return f"{where}: definition_kind {definition_kind!r} not in ('new_event', 'override')"
    target_id = record.get("target_id", "")
    if definition_kind == "new_event":
        if target_id != "":
            return f"{where}: target_id must be empty for a new_event"
    else:
        if not TARGET_ID_RE.match(target_id):
            return f"{where}: target_id {target_id!r} does not match the registry id pattern"
    for hash_field in ("definition_sha256", "contract_fingerprint", "cells_fingerprint"):
        if not SHA256_RE.match(record.get(hash_field, "")):
            return f"{where}: {hash_field} is not a SHA-256 hex string"
    expected_path = f"definitions/{record.get('definition_sha256')}-{record.get('definition_id')}.json"
    definition_path = record.get("definition_path", "")
    if not _is_safe_definition_path(definition_path) or definition_path != expected_path:
        return f"{where}: definition_path {definition_path!r} != {expected_path!r}"
    return None


def check_workspace(root: str | Path, names_dir: str | Path | None = None, definitions_dir: str | Path | None = None) -> dict:
    root = Path(root)
    manifest_path = root / "manifest.json"
    failures: list[dict] = []
    if not manifest_path.is_file():
        return {"ok": False, "workspace": str(root), "definitions": 0, "failures": [
            {"definition_id": "", "stage": "manifest", "reason": "missing_manifest", "detail": "manifest.json does not exist"}
        ]}
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    definitions = manifest.get("definitions", []) if isinstance(manifest, dict) else []
    if not isinstance(definitions, list):
        return {"ok": False, "workspace": str(root), "definitions": 0, "failures": [
            {"definition_id": "", "stage": "manifest", "reason": "bad_manifest", "detail": "definitions is not a list"}
        ]}

    names_registry = None
    if names_dir is not None:
        names_path = Path(names_dir)
        if names_path.is_dir():
            names_registry = moddef.load_names_registry(names_path)

    fingerprint = _default_fingerprint()
    cells_fingerprint = _default_cells_fingerprint()

    seen_ids: set = set()
    shared_mod_id: str | None = None
    verified: list[tuple[dict, Path]] = []

    for index, record in enumerate(definitions):
        definition_id = record.get("definition_id", "") if isinstance(record, dict) else ""
        where = f"definitions[{index}]"
        error = _record_header_error(record, where)
        if error is not None:
            failures.append({"definition_id": definition_id, "stage": "manifest", "reason": "header", "detail": error})
            continue
        if definition_id in seen_ids:
            failures.append({"definition_id": definition_id, "stage": "manifest", "reason": "duplicate_id", "detail": f"{where}: duplicate definition_id"})
            continue
        seen_ids.add(definition_id)
        mod_id = record.get("mod_id", "")
        if shared_mod_id is None:
            shared_mod_id = mod_id
        elif shared_mod_id != mod_id:
            failures.append({"definition_id": definition_id, "stage": "manifest", "reason": "mixed_mod_id", "detail": f"{where}: mod_id {mod_id!r} != {shared_mod_id!r}"})
            continue
        definition_path = root / record.get("definition_path", "")
        if not definition_path.is_file():
            failures.append({"definition_id": definition_id, "stage": "manifest", "reason": "missing_file", "detail": f"{where}: file missing: {record.get('definition_path')}"})
            continue
        data = definition_path.read_bytes()
        actual_sha = hashlib.sha256(data).hexdigest()
        if actual_sha != record.get("definition_sha256"):
            failures.append({"definition_id": definition_id, "stage": "manifest", "reason": "hash_mismatch", "detail": f"{where}: {actual_sha} != {record.get('definition_sha256')}"})
            continue
        verified.append((record, definition_path))

    for record, definition_path in verified:
        definition_id = record.get("definition_id", "")
        try:
            document = json.loads(definition_path.read_text(encoding="utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            failures.append({"definition_id": definition_id, "stage": "contract", "reason": "schema", "detail": str(error)})
            continue
        result = moddef.validate(
            document,
            fingerprint=fingerprint,
            cells_fingerprint=cells_fingerprint,
            names_registry=names_registry,
            base_documents=definitions_dir,
        )
        if not result.get("ok", False):
            failures.append({
                "definition_id": definition_id,
                "stage": "contract",
                "reason": result.get("reason", ""),
                "detail": result.get("detail", ""),
            })

    return {
        "ok": not failures,
        "workspace": str(root),
        "definitions": len(definitions),
        "failures": failures,
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("workspace_root", type=Path)
    parser.add_argument("--names", type=Path, default=None, help="event name registry directory")
    parser.add_argument("--definitions-dir", type=Path, default=None, help="tracked v4 definitions directory")
    args = parser.parse_args(argv)

    result = check_workspace(args.workspace_root, args.names, args.definitions_dir)
    print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
