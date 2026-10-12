"""Portable transport of a mod's own event definitions: one JSON file per
mod, ``kakyu_mod_definition_set/v1``, built from a workspace's
``definitions/`` records and published beside the mod's deltas (mod event
definition unit C, the transport ruling of 2026-09-19). See
``docs/spec/data/mod_event_definition_design.md`` (the transport ruling)
and ``docs/spec/data/mod_event_definition.md`` for the document shape this
file's ``definitions[].document`` rows carry.

    py tools/mod_definition_set.py build <workspace root> <out.json>
        [--names <dir>] [--definitions-dir <dir>]
    py tools/mod_definition_set.py validate <set.json>
        [--names <dir>] [--definitions-dir <dir>] [--extract <dir>]

``main`` prints one JSON line ``{"ok", "schema", "mod_id", "mod_revision",
"definition_count", "payload_sha256"}`` on success or ``{"ok": false,
"error"}`` otherwise, exit 0/1 - the same convention
``tools/authored_mod_delta.py`` uses. ``build`` refuses (raising
``ValueError``, like the delta) unless every one of the workspace's
definitions passes ``tools/validate_workspace_definitions.check_workspace``
first; no file is written until the whole assembled document validates.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
import tempfile
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mes_authoring_workflow as workflow  # noqa: E402
import payload_values  # noqa: E402
import validate_mod_event_definition as moddef  # noqa: E402
import validate_workspace_definitions as workspace_definitions  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]

SCHEMA = "kakyu_mod_definition_set/v1"
DEFAULT_NAMES_DIR = ROOT / "config" / "contracts" / "event_names_v1"
DEFAULT_DEFINITIONS_DIR = ROOT / "config" / "event_definitions" / "v4"
MAX_BYTES = 16 * 1024 * 1024

MOD_ID_RE = moddef.MOD_ID_RE
DOC_ID_RE = moddef.DOC_ID_RE
TARGET_ID_RE = moddef.ID_RE
PROJECT_ID_RE = re.compile(r"^[a-z0-9._-]+$")

HEADER_KEYS = {
    "schema", "mod", "source_project_id", "contract_fingerprint", "cells_fingerprint",
    "names_fingerprint", "definitions", "compatibility", "payload_sha256",
}
ROW_KEYS = {"definition_id", "definition_kind", "target_id", "definition_sha256", "document"}
DEFINITION_KIND_VALUES = {"new_event", "override"}
COMPATIBILITY = {"target": "remake_only", "minimum_core": "0.347.0", "maximum_exclusive": "1.0.0"}


def fingerprint(document: dict[str, Any]) -> str:
    return workflow._sha(workflow._json({k: v for k, v in document.items() if k != "payload_sha256"}))


def _hash(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value)


def _is_project_id(value: Any) -> bool:
    return (
        isinstance(value, str) and bool(PROJECT_ID_RE.match(value))
        and not value.startswith(".") and not value.endswith(".")
    )


def _default_contract_fingerprint() -> str:
    path = ROOT / "config" / "contracts" / "mod_event_definition_v1" / "contract_fingerprint"
    return path.read_text(encoding="utf-8").strip() if path.is_file() else ""


def _default_cells_fingerprint() -> str:
    path = ROOT / "config" / "contracts" / "state_cells_v1" / "cells_fingerprint"
    return path.read_text(encoding="utf-8").strip() if path.is_file() else ""


def _names_fingerprint(names_dir: Path | str) -> str:
    path = Path(names_dir) / "names_fingerprint"
    return path.read_text(encoding="utf-8").strip() if path.is_file() else ""


def _check_document_row(
    row: Any, *, set_mod: dict, contract_fingerprint: str, cells_fingerprint: str
) -> dict:
    if not isinstance(row, dict) or set(row) != ROW_KEYS:
        raise ValueError("Definition set row fields changed")
    definition_id = row["definition_id"]
    if not isinstance(definition_id, str) or not DOC_ID_RE.match(definition_id):
        raise ValueError(f"Definition set row has an invalid definition_id: {definition_id!r}")
    definition_kind = row["definition_kind"]
    if definition_kind not in DEFINITION_KIND_VALUES:
        raise ValueError(f"{definition_id}: definition_kind {definition_kind!r} not in {sorted(DEFINITION_KIND_VALUES)}")
    target_id = row["target_id"]
    if not isinstance(target_id, str):
        raise ValueError(f"{definition_id}: target_id is not a string")
    if definition_kind == "new_event":
        if target_id != "":
            raise ValueError(f"{definition_id}: target_id must be empty for a new_event")
    elif not TARGET_ID_RE.match(target_id):
        raise ValueError(f"{definition_id}: target_id {target_id!r} does not match the registry id pattern")
    definition_sha256 = row["definition_sha256"]
    if not _hash(definition_sha256):
        raise ValueError(f"{definition_id}: definition_sha256 is not 64 lowercase hex characters")
    document = row["document"]
    if not isinstance(document, dict):
        raise ValueError(f"{definition_id}: document is not an object")
    if workflow._sha(workflow._json(document)) != definition_sha256:
        raise ValueError(f"{definition_id}: definition_sha256 does not match the document")
    if document.get("id") != definition_id:
        raise ValueError(f"{definition_id}: document.id disagrees with the row's definition_id")
    if document.get("kind") != definition_kind:
        raise ValueError(f"{definition_id}: document.kind disagrees with the row's definition_kind")
    if document.get("schema_version") != moddef.SCHEMA_VERSION:
        raise ValueError(f"{definition_id}: document.schema_version != {moddef.SCHEMA_VERSION!r}")
    doc_mod = document.get("mod")
    if not isinstance(doc_mod, dict) or doc_mod.get("id") != set_mod["id"] or doc_mod.get("revision") != set_mod["revision"]:
        raise ValueError(f"{definition_id}: document.mod disagrees with the set header's mod")
    if document.get("contract_fingerprint") != contract_fingerprint:
        raise ValueError(f"{definition_id}: document.contract_fingerprint is not the set's real fingerprint")
    if document.get("cells_fingerprint") != cells_fingerprint:
        raise ValueError(f"{definition_id}: document.cells_fingerprint is not the set's real fingerprint")
    if definition_kind == "override":
        target = document.get("target")
        if not isinstance(target, dict) or target.get("id") != target_id:
            raise ValueError(f"{definition_id}: document.target.id disagrees with the row's target_id")
    return document


def validate(document: Any, *, names_dir: Path | str | None = None, definitions_dir: Path | str | None = None) -> None:
    """Raise ``ValueError`` with a message on the first offending field,
    like ``tools/authored_mod_delta.py``'s ``validate``. The full
    ``kakyu_mod_event_definition/v1`` contract check of every embedded
    document only runs when ``names_dir``/``definitions_dir`` are given (the
    CLI always gives them, defaulting to the tracked directories)."""
    if not isinstance(document, dict) or set(document) != HEADER_KEYS:
        raise ValueError("Definition set schema or fields changed")
    if document["schema"] != SCHEMA:
        raise ValueError(f"Definition set schema {document['schema']!r} != {SCHEMA!r}")
    mod = document["mod"]
    if not isinstance(mod, dict) or set(mod) != {"id", "revision"}:
        raise ValueError("Definition set mod fields changed")
    mod_id = mod["id"]
    if not isinstance(mod_id, str) or not MOD_ID_RE.match(mod_id):
        raise ValueError(f"Definition set mod.id {mod_id!r} does not match the mod id pattern")
    revision = mod["revision"]
    if not isinstance(revision, int) or isinstance(revision, bool) or revision < 1:
        raise ValueError("Definition set mod.revision must be an integer >= 1")
    source_project_id = document["source_project_id"]
    if not _is_project_id(source_project_id):
        raise ValueError(f"Definition set source_project_id {source_project_id!r} is not a project id")
    contract_fingerprint = document["contract_fingerprint"]
    cells_fingerprint = document["cells_fingerprint"]
    names_fingerprint = document["names_fingerprint"]
    for label, value in (
        ("contract_fingerprint", contract_fingerprint),
        ("cells_fingerprint", cells_fingerprint),
        ("names_fingerprint", names_fingerprint),
    ):
        if not _hash(value):
            raise ValueError(f"Definition set {label} is not 64 lowercase hex characters")
    definitions = document["definitions"]
    if not isinstance(definitions, list) or not definitions:
        raise ValueError("Definition set definitions must be a non-empty array")
    previous_id = ""
    parsed_documents: dict[str, dict] = {}
    for row in definitions:
        if not isinstance(row, dict) or not isinstance(row.get("definition_id"), str):
            raise ValueError("Definition set row is not an object with a definition_id")
        definition_id = row["definition_id"]
        if definition_id <= previous_id:
            raise ValueError("Definition set rows must be sorted by definition_id with no duplicate")
        previous_id = definition_id
        parsed_documents[definition_id] = _check_document_row(
            row, set_mod=mod, contract_fingerprint=contract_fingerprint, cells_fingerprint=cells_fingerprint
        )
    if document["compatibility"] != COMPATIBILITY:
        raise ValueError("Definition set compatibility requirement is unsupported")
    if fingerprint(document) != document["payload_sha256"]:
        raise ValueError("Definition set payload changed")

    if names_dir is not None or definitions_dir is not None:
        names_registry = moddef.load_names_registry(Path(names_dir)) if names_dir is not None else None
        for row in definitions:
            definition_id = row["definition_id"]
            result = moddef.validate(
                parsed_documents[definition_id],
                fingerprint=contract_fingerprint,
                cells_fingerprint=cells_fingerprint,
                names_registry=names_registry,
                base_documents=definitions_dir,
            )
            if not result.get("ok", False):
                raise ValueError(f"{definition_id}: {result.get('reason')}: {result.get('detail')}")


def build(workspace_root: Path | str, names_dir: Path | str, definitions_dir: Path | str) -> dict[str, Any]:
    root = Path(workspace_root)
    project_path = root / "project.json"
    manifest_path = root / "manifest.json"
    if not project_path.is_file():
        raise ValueError("Workspace project.json is missing")
    project = json.loads(project_path.read_text(encoding="utf-8"))
    source_project_id = project.get("project_id") if isinstance(project, dict) else None
    if not _is_project_id(source_project_id):
        raise ValueError("Workspace project_id is not a valid project id")
    if not manifest_path.is_file():
        raise ValueError("Workspace manifest.json is missing")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    checked = workspace_definitions.check_workspace(root, names_dir, definitions_dir)
    if not checked.get("ok", False):
        failures = checked.get("failures", [])
        detail = failures[0] if failures else {"definition_id": "", "stage": "manifest", "reason": "invalid", "detail": ""}
        raise ValueError(
            f"Workspace definitions failed validation: {detail.get('definition_id')!r} "
            f"({detail.get('stage')}/{detail.get('reason')}): {detail.get('detail')}"
        )

    records = manifest.get("definitions", []) if isinstance(manifest, dict) else []
    if not records:
        raise ValueError("Workspace has no definitions to build a set from")

    contract_fingerprint = _default_contract_fingerprint()
    cells_fingerprint = _default_cells_fingerprint()
    names_fp = _names_fingerprint(names_dir)
    for label, value in (
        ("contract_fingerprint", contract_fingerprint),
        ("cells_fingerprint", cells_fingerprint),
        ("names_fingerprint", names_fp),
    ):
        if not _hash(value):
            raise ValueError(f"Tracked {label} is unavailable")

    mod_id: str | None = None
    mod_revision: int | None = None
    rows: list[dict[str, Any]] = []
    for record in records:
        definition_path = root / str(record.get("definition_path", ""))
        document = json.loads(definition_path.read_text(encoding="utf-8"))
        doc_mod = document.get("mod") if isinstance(document, dict) else None
        row_mod_id = doc_mod.get("id") if isinstance(doc_mod, dict) else None
        row_revision = doc_mod.get("revision") if isinstance(doc_mod, dict) else None
        if mod_id is None:
            mod_id = row_mod_id
        elif mod_id != row_mod_id:
            raise ValueError("Workspace definitions do not share one mod id")
        if mod_revision is None:
            mod_revision = row_revision
        elif mod_revision != row_revision:
            raise ValueError("Workspace definitions do not share one mod revision")
        if document.get("contract_fingerprint") != contract_fingerprint:
            raise ValueError(f"{document.get('id')}: contract_fingerprint does not match the tracked value")
        if document.get("cells_fingerprint") != cells_fingerprint:
            raise ValueError(f"{document.get('id')}: cells_fingerprint does not match the tracked value")
        definition_id = document.get("id")
        definition_kind = document.get("kind")
        target_id = ""
        if definition_kind == "override":
            target = document.get("target")
            target_id = target.get("id") if isinstance(target, dict) else None
        definition_sha256 = workflow._sha(workflow._json(document))
        rows.append({
            "definition_id": definition_id,
            "definition_kind": definition_kind,
            "target_id": target_id,
            "definition_sha256": definition_sha256,
            "document": document,
        })

    ids = [row["definition_id"] for row in rows]
    if len(ids) != len(set(ids)):
        raise ValueError("Workspace definitions contain a duplicate definition id")
    rows.sort(key=lambda row: row["definition_id"])

    assembled = {
        "schema": SCHEMA,
        "mod": {"id": mod_id, "revision": mod_revision},
        "source_project_id": source_project_id,
        "contract_fingerprint": contract_fingerprint,
        "cells_fingerprint": cells_fingerprint,
        "names_fingerprint": names_fp,
        "definitions": rows,
        "compatibility": COMPATIBILITY.copy(),
    }
    assembled["payload_sha256"] = fingerprint(assembled)
    validate(assembled, names_dir=names_dir, definitions_dir=definitions_dir)
    return assembled


def read(path: Path, names_dir: Path | str | None = None, definitions_dir: Path | str | None = None) -> dict[str, Any]:
    if path.stat().st_size > MAX_BYTES:
        raise ValueError("Definition set exceeds the bounded import size")
    document = json.loads(path.read_text(encoding="utf-8"))
    validate(document, names_dir=names_dir, definitions_dir=definitions_dir)
    return document


def publish(path: Path, document: dict[str, Any]) -> None:
    validate(document)
    payload = workflow._json(document)
    if len(payload) > MAX_BYTES:
        raise ValueError("Definition set exceeds the bounded import size")
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".mod-definition-set-", dir=path.parent)

    def verify(staged: Path) -> None:
        if read(staged) != document:
            raise ValueError("Staged definition set could not be reopened exactly")

    # Atomic publication without replacing an existing name, including races.
    payload_values.publish_new_document(path, payload, Path(temporary), verify, descriptor=descriptor)


def _refuse_inside(path: Path, *boundaries: Path) -> None:
    resolved = path.resolve()
    for boundary in boundaries:
        try:
            resolved_boundary = boundary.resolve()
        except OSError:
            continue
        if resolved == resolved_boundary or resolved_boundary in resolved.parents:
            raise ValueError("Definition set output must be outside the workspace and the original content set")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    build_parser = commands.add_parser("build")
    build_parser.add_argument("workspace_root", type=Path)
    build_parser.add_argument("out", type=Path)
    build_parser.add_argument("--names", type=Path, default=DEFAULT_NAMES_DIR)
    build_parser.add_argument("--definitions-dir", type=Path, default=DEFAULT_DEFINITIONS_DIR)

    validate_parser = commands.add_parser("validate")
    validate_parser.add_argument("set_path", type=Path)
    validate_parser.add_argument("--names", type=Path, default=DEFAULT_NAMES_DIR)
    validate_parser.add_argument("--definitions-dir", type=Path, default=DEFAULT_DEFINITIONS_DIR)
    validate_parser.add_argument("--extract", type=Path, default=None)

    args = parser.parse_args()
    try:
        if args.command == "build":
            _refuse_inside(args.out, args.workspace_root, args.definitions_dir)
            document = build(args.workspace_root, args.names, args.definitions_dir)
            publish(args.out, document)
        else:
            document = read(args.set_path, args.names, args.definitions_dir)
            if args.extract is not None:
                args.extract.mkdir(parents=True, exist_ok=True)
                for row in document["definitions"]:
                    target = args.extract / f"{row['definition_id']}.json"
                    target.write_bytes(workflow._json(row["document"]))
        print(json.dumps({
            "ok": True, "schema": document["schema"], "mod_id": document["mod"]["id"],
            "mod_revision": document["mod"]["revision"], "definition_count": len(document["definitions"]),
            "payload_sha256": document["payload_sha256"],
        }))
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
