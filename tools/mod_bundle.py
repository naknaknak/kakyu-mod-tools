"""Portable mod bundle: ``kakyu_mod_bundle/v1`` (WD-10).

One canonical JSON file holds everything a workspace authored for the
original ``mes.arc`` - every authored delta (``kakyu_authored_mod_delta/v9``,
one per authored MES entry), the UTF-8 translations of entries with no
structural edit (``text_projections``) and the workspace's definition set
(``kakyu_mod_definition_set/v1``). It never carries an original payload, an
absolute path or a local evidence bundle. See ``docs/spec/data/mod_bundle.md``
for the contract and its fail-closed rules.

    py tools/mod_bundle.py build <mes.arc> <workspace root> <out.json>
        [--mod-id ID] [--mod-revision N] [--names <dir>] [--definitions-dir <dir>]
    py tools/mod_bundle.py validate <bundle.json> [--arc <mes.arc>]
        [--names <dir>] [--definitions-dir <dir>] [--extract <dir>]

``main`` prints one JSON line ``{"ok", "schema", "mod_id", "mod_revision",
"delta_count", "text_projection_count", "definition_count", "payload_sha256"}``
on success or ``{"ok": false, "error"}`` otherwise, exit 0/1, like
``tools/authored_mod_delta.py`` and ``tools/mod_definition_set.py``.

Every hash in a bundle is a SHA-256 of ``mes_authoring_workflow._json`` bytes
(sorted keys, no spaces, UTF-8, one trailing LF) - the delta and set form,
never ``payload_values.fingerprint``, whose bytes carry no LF.

The core functions take an entry reader (``read_entry(name) -> bytes``) and the
archive's SHA-256; only ``main`` binds them to an ARC file.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import authored_mod_delta as delta  # noqa: E402
import mes_authoring_workflow as workflow  # noqa: E402
import mod_definition_set as modset  # noqa: E402
import payload_values  # noqa: E402

SCHEMA = "kakyu_mod_bundle/v1"
MAX_BYTES = 64 * 1024 * 1024
MEMBER_MAX_BYTES = 16 * 1024 * 1024
OVERLAY_SCHEMA = "kakyu_content_overlay/v1"
PROJECTION_SCHEMA = "kakyu_mes_text_overlay_entry/v1"

HEADER_KEYS = {
    "schema", "mod", "source_project_id", "source", "dependencies", "deltas",
    "text_projections", "definition_set", "compatibility", "payload_sha256",
}
SOURCE_KEYS = {"archive", "archive_sha256", "source_kind"}
DELTA_ROW_KEYS = {"entry", "source_entry_sha256", "output_entry_sha256", "delta_sha256", "document"}
TEXT_ROW_KEYS = {"entry", "source_entry_sha256", "text_edits"}
SET_KEYS = {"set_sha256", "definition_count", "document"}
COMPATIBILITY = {"target": "remake_only", "minimum_core": "0.377.0", "maximum_exclusive": "1.0.0"}

DEFAULT_NAMES_DIR = modset.DEFAULT_NAMES_DIR
DEFAULT_DEFINITIONS_DIR = modset.DEFAULT_DEFINITIONS_DIR

ReadEntry = Callable[[str], bytes]


def fingerprint(document: dict[str, Any]) -> str:
    """The delta/set convention: ``authored_mod_delta.fingerprint`` over `_json` bytes."""
    return delta.fingerprint(document)


def _canonical_sha(document: Any) -> str:
    return workflow._sha(workflow._json(document))


def _run(label: str, call: Callable[..., Any], *args: Any, **kwargs: Any) -> Any:
    """Call a member validator, naming the member in any refusal and folding a
    malformed-shape failure into the same `ValueError`."""
    try:
        return call(*args, **kwargs)
    except ValueError as error:
        raise ValueError(f"{label}: {error}") from error
    except (KeyError, TypeError, AttributeError, IndexError) as error:
        raise ValueError(f"{label}: the member is malformed") from error


def _check_entry(entry: Any, label: str) -> None:
    try:
        workflow._source({"archive": "mes.arc", "entry": entry, "source_kind": "original_arc",
                          "archive_sha256": "0" * 64})
    except ValueError as error:
        raise ValueError(f"{label} has an unsafe or non-MES entry name") from error


def _is_int(value: Any) -> bool:
    return type(value) is int


# --------------------------------------------------------------------- validate


def validate(document: Any, *, names_dir: Path | str | None = None,
             definitions_dir: Path | str | None = None) -> None:
    """Raise ``ValueError`` on the first offending field. The full
    ``kakyu_mod_event_definition/v1`` contract check of the embedded set only
    runs when ``names_dir``/``definitions_dir`` are given (the CLI always gives
    them, defaulting to the tracked directories)."""
    if not isinstance(document, dict):
        raise ValueError("Mod bundle schema or fields changed")
    schema = document.get("schema")
    if schema != SCHEMA:
        raise ValueError(f"Mod bundle schema version is unsupported: {str(schema)[:64]!r}")
    if set(document) != HEADER_KEYS:
        raise ValueError("Mod bundle schema or fields changed")
    mod = document["mod"]
    if not isinstance(mod, dict) or set(mod) != {"id", "revision"}:
        raise ValueError("Mod bundle mod fields changed")
    if not isinstance(mod["id"], str) or not modset.MOD_ID_RE.match(mod["id"]):
        raise ValueError("Mod bundle mod.id does not match the mod id pattern")
    if not _is_int(mod["revision"]) or mod["revision"] < 1:
        raise ValueError("Mod bundle mod.revision must be an integer >= 1")
    if not modset._is_project_id(document["source_project_id"]):
        raise ValueError("Mod bundle source_project_id is not a project id")
    source = document["source"]
    if (not isinstance(source, dict) or set(source) != SOURCE_KEYS or source["archive"] != "mes.arc"
            or source["source_kind"] != "original_arc"
            or not payload_values.is_sha256(source["archive_sha256"])):
        raise ValueError("Mod bundle source must name the original mes.arc by SHA-256")
    archive_sha256 = source["archive_sha256"]
    if document["compatibility"] != COMPATIBILITY:
        raise ValueError("Mod bundle compatibility requirement is unsupported")
    if not payload_values.is_sha256(document["payload_sha256"]):
        raise ValueError("Mod bundle payload_sha256 is invalid")
    if fingerprint(document) != document["payload_sha256"]:
        raise ValueError("Mod bundle payload changed")

    entries: set[str] = set()
    union: dict[str, str] = {}
    delta_rows = document["deltas"]
    if not isinstance(delta_rows, list):
        raise ValueError("Mod bundle deltas must be an array")
    previous = ""
    for row in delta_rows:
        if not isinstance(row, dict) or set(row) != DELTA_ROW_KEYS:
            raise ValueError("Mod bundle delta row fields changed")
        entry = row["entry"]
        _check_entry(entry, "Mod bundle delta row")
        if entry <= previous:
            raise ValueError("Mod bundle deltas must be sorted by entry with no duplicate")
        previous = entry
        if entry.casefold() in entries:
            raise ValueError(f"Mod bundle names entry {entry} more than once")
        entries.add(entry.casefold())
        label = f"Mod bundle delta {entry}"
        member = row["document"]
        if not isinstance(member, dict) or member.get("schema") != delta.SCHEMA:
            raise ValueError(f"{label} is not a {delta.SCHEMA} delta")
        _run(label, delta.validate, member)
        if member["source"]["archive_sha256"] != archive_sha256:
            raise ValueError(f"{label} belongs to another archive")
        if member["source"]["entry"] != entry:
            raise ValueError(f"{label} is bound to another entry")
        if (not payload_values.is_sha256(row["source_entry_sha256"])
                or not payload_values.is_sha256(row["output_entry_sha256"])
                or row["source_entry_sha256"] != member["source_entry_sha256"]
                or row["output_entry_sha256"] != member["output_entry_sha256"]):
            raise ValueError(f"{label}: the row disagrees with its document")
        canonical = workflow._json(member)
        if len(canonical) > MEMBER_MAX_BYTES:
            raise ValueError(f"{label} exceeds the bounded member size")
        if row["delta_sha256"] != workflow._sha(canonical):
            raise ValueError(f"{label}: delta_sha256 does not match the document")
        for dependency in member["dependencies"]:
            known = union.get(dependency["entry"])
            if known is not None and known != dependency["entry_sha256"]:
                raise ValueError(f"{label}: dependency {dependency['entry']} disagrees with another delta")
            union[dependency["entry"]] = dependency["entry_sha256"]

    text_rows = document["text_projections"]
    if not isinstance(text_rows, list):
        raise ValueError("Mod bundle text_projections must be an array")
    previous = ""
    for row in text_rows:
        if not isinstance(row, dict) or set(row) != TEXT_ROW_KEYS:
            raise ValueError("Mod bundle text projection row fields changed")
        entry = row["entry"]
        _check_entry(entry, "Mod bundle text projection row")
        if entry <= previous:
            raise ValueError("Mod bundle text projections must be sorted by entry with no duplicate")
        previous = entry
        if entry.casefold() in entries:
            raise ValueError(f"Mod bundle names entry {entry} more than once")
        entries.add(entry.casefold())
        label = f"Mod bundle text projection {entry}"
        if not payload_values.is_sha256(row["source_entry_sha256"]):
            raise ValueError(f"{label}: source_entry_sha256 is invalid")
        if not isinstance(row["text_edits"], list) or not row["text_edits"]:
            raise ValueError(f"{label}: text edits must be a non-empty array")
        _run(label, delta.validate_text_edits, row["text_edits"])

    dependencies = document["dependencies"]
    if not isinstance(dependencies, list):
        raise ValueError("Mod bundle dependencies must be an array")
    previous = ""
    for row in dependencies:
        if (not isinstance(row, dict) or set(row) != delta.DEPENDENCY_KEYS
                or not workflow.resource_planner._is_safe_entry_name(row.get("entry"))
                or not payload_values.is_sha256(row.get("entry_sha256")) or row["entry"] <= previous):
            raise ValueError("Mod bundle dependency is invalid or unsorted")
        previous = row["entry"]
    if dependencies != [{"entry": name, "entry_sha256": union[name]} for name in sorted(union)]:
        raise ValueError("Mod bundle dependencies differ from its deltas' union")

    definition_set = document["definition_set"]
    if definition_set is not None:
        if not isinstance(definition_set, dict) or set(definition_set) != SET_KEYS:
            raise ValueError("Mod bundle definition_set fields changed")
        member = definition_set["document"]
        _run("Mod bundle definition set", modset.validate, member,
             names_dir=names_dir, definitions_dir=definitions_dir)
        canonical = workflow._json(member)
        if len(canonical) > modset.MAX_BYTES:
            raise ValueError("Mod bundle definition set exceeds the bounded member size")
        if (not payload_values.is_sha256(definition_set["set_sha256"])
                or definition_set["set_sha256"] != workflow._sha(canonical)):
            raise ValueError("Mod bundle definition set: set_sha256 does not match the document")
        if (not _is_int(definition_set["definition_count"])
                or definition_set["definition_count"] != len(member["definitions"])):
            raise ValueError("Mod bundle definition set: definition_count does not match the document")
        if member["mod"] != mod:
            raise ValueError("Mod bundle definition set is for another mod than the bundle's")
        if member["source_project_id"] != document["source_project_id"]:
            raise ValueError("Mod bundle definition set was built from another project than the bundle's")
    if not delta_rows and not text_rows and definition_set is None:
        raise ValueError("Mod bundle has no member")


def _read_entry(read_entry: ReadEntry, name: str) -> bytes:
    try:
        payload = read_entry(name)
    except KeyError as error:
        raise ValueError(f"Mod bundle entry {name} is missing from the archive") from error
    if not isinstance(payload, bytes):
        raise ValueError(f"Mod bundle entry {name} could not be read")
    return payload


def check_source(document: dict[str, Any], read_entry: ReadEntry, archive_sha256: str) -> None:
    """The bundle's source rules against the matching original: the archive's
    SHA-256, every dependency and member entry's hash, and every text edit
    bound to an exact source message. Reconstruction is the importer's job."""
    if document["source"]["archive_sha256"] != archive_sha256:
        raise ValueError("Mod bundle belongs to another archive than the one supplied")
    for row in document["dependencies"]:
        if workflow._sha(_read_entry(read_entry, row["entry"])) != row["entry_sha256"]:
            raise ValueError(f"Mod bundle dependency {row['entry']} is missing or changed")
    members = [(row["entry"], row["source_entry_sha256"], row["document"]["source"],
                row["document"]["text_edits"]) for row in document["deltas"]]
    identity_of = {"archive": "mes.arc", "source_kind": "original_arc", "archive_sha256": archive_sha256}
    members += [(row["entry"], row["source_entry_sha256"], dict(identity_of, entry=row["entry"]),
                 row["text_edits"]) for row in document["text_projections"]]
    for entry, source_sha256, identity, edits in members:
        source = _read_entry(read_entry, entry)
        if workflow._sha(source) != source_sha256:
            raise ValueError(f"Mod bundle source entry {entry} differs from the supplied archive")
        _run(f"Mod bundle entry {entry}", delta._check_text, workflow.analyze(source, identity), edits)


# ------------------------------------------------------------------ read / publish


def read(path: Path, names_dir: Path | str | None = None,
         definitions_dir: Path | str | None = None) -> dict[str, Any]:
    """The size is checked on `st_size` before anything is read or parsed."""
    if path.stat().st_size > MAX_BYTES:
        raise ValueError("Mod bundle exceeds the bounded import size")
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except RecursionError as error:
        raise ValueError("Mod bundle is nested too deeply") from error
    validate(document, names_dir=names_dir, definitions_dir=definitions_dir)
    return document


def publish(path: Path, document: dict[str, Any]) -> None:
    validate(document)
    payload = workflow._json(document)
    if len(payload) > MAX_BYTES:
        raise ValueError("Mod bundle exceeds the bounded import size")
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".mod-bundle-", dir=path.parent)

    def verify(staged: Path) -> None:
        if read(staged) != document:
            raise ValueError("Staged mod bundle could not be reopened exactly")

    # Atomic publication without replacing an existing name, including races.
    payload_values.publish_new_document(path, payload, Path(temporary), verify, descriptor=descriptor)


def extract(document: dict[str, Any], directory: Path) -> None:
    """Write `deltas/<ENTRY>.json` and `definition_set.json`: the exact `_json`
    bytes the rows' `delta_sha256` / `set_sha256` name."""
    (directory / "deltas").mkdir(parents=True, exist_ok=True)
    for row in document["deltas"]:
        (directory / "deltas" / f"{row['entry']}.json").write_bytes(workflow._json(row["document"]))
    if document["definition_set"] is not None:
        (directory / "definition_set.json").write_bytes(workflow._json(document["definition_set"]["document"]))


# ------------------------------------------------------------------------ build


def assemble(*, mod: dict[str, Any], source_project_id: str, archive_sha256: str,
             delta_documents: list[dict[str, Any]], text_rows: list[dict[str, Any]],
             set_document: dict[str, Any] | None) -> dict[str, Any]:
    """The header around already-built members, deterministic and unvalidated."""
    union: dict[str, str] = {}
    delta_rows = []
    for member in delta_documents:
        for dependency in member["dependencies"]:
            union[dependency["entry"]] = dependency["entry_sha256"]
        delta_rows.append({
            "entry": member["source"]["entry"], "source_entry_sha256": member["source_entry_sha256"],
            "output_entry_sha256": member["output_entry_sha256"], "delta_sha256": _canonical_sha(member),
            "document": member,
        })
    delta_rows.sort(key=lambda row: row["entry"])
    document = {
        "schema": SCHEMA,
        "mod": {"id": mod["id"], "revision": mod["revision"]},
        "source_project_id": source_project_id,
        "source": {"archive": "mes.arc", "archive_sha256": archive_sha256, "source_kind": "original_arc"},
        "dependencies": [{"entry": name, "entry_sha256": union[name]} for name in sorted(union)],
        "deltas": delta_rows,
        "text_projections": sorted(text_rows, key=lambda row: row["entry"]),
        "definition_set": None if set_document is None else {
            "set_sha256": _canonical_sha(set_document), "definition_count": len(set_document["definitions"]),
            "document": set_document,
        },
        "compatibility": COMPATIBILITY.copy(),
    }
    document["payload_sha256"] = fingerprint(document)
    return document


def _read_json_file(path: Path, label: str) -> Any:
    try:
        if path.stat().st_size > MEMBER_MAX_BYTES:
            raise ValueError(f"{label} exceeds the bounded size")
        return json.loads(path.read_bytes())
    except OSError as error:
        raise ValueError(f"{label} could not be read") from error
    except RecursionError as error:
        raise ValueError(f"{label} is nested too deeply") from error


def _record_text(record: dict[str, Any], field: str, label: str) -> str:
    value = record.get(field)
    if not isinstance(value, str) or not value:
        raise ValueError(f"{label} has an invalid {field}")
    return value


def _safe_relative(path: str, *, prefix: tuple[str, ...], parts: int | None) -> bool:
    if not path or path.startswith("/") or "\\" in path or ":" in path:
        return False
    pieces = [piece for piece in path.split("/") if piece]
    if parts is not None and len(pieces) != parts:
        return False
    if len(pieces) < len(prefix) + 1 or tuple(pieces[:len(prefix)]) != prefix:
        return False
    return all(piece not in (".", "..") for piece in pieces)


def _read_workspace_file(root: Path, relative: str, expected_sha256: str, label: str) -> bytes:
    path = root / relative
    try:
        payload = path.read_bytes()
    except OSError as error:
        raise ValueError(f"{label} file is missing: {relative}") from error
    if workflow._sha(payload) != expected_sha256:
        raise ValueError(f"{label} file hash mismatch: {relative}")
    return payload


def _check_project_binding(project: dict[str, Any], archive_sha256: str) -> str:
    project_id = project.get("project_id")
    if not modset._is_project_id(project_id):
        raise ValueError("Workspace project_id is not a valid project id")
    content_set = project.get("source_content_set")
    archives = content_set.get("archives") if isinstance(content_set, dict) else None
    rows = [row for row in archives if isinstance(row, dict) and row.get("archive") == "mes.arc"] \
        if isinstance(archives, list) else []
    if len(rows) != 1 or rows[0].get("sha256") != archive_sha256:
        raise ValueError("Workspace project does not bind this mes.arc")
    return project_id


def _link_authoring(root: Path, entry: str, original_sha256: str, replacement_sha256: str) -> dict[str, bytes] | None:
    """The first readable authoring bundle, in sorted order over `.authoring/delta`
    and `authoring/*`, whose manifest summary binds the entry and both hashes -
    the rule of `provenance_report.gd` `_link_authoring` and
    `mes_authoring_binding.gd` `find_proof`. Matches that name different
    operations are ambiguous and refused."""
    candidates = []
    if (root / ".authoring" / "delta").is_dir():
        candidates.append(".authoring/delta")
    authoring = root / "authoring"
    if authoring.is_dir():
        candidates += [f"authoring/{child.name}" for child in authoring.iterdir() if child.is_dir()]
    candidates.sort()
    matches = []
    for relative in candidates:
        try:
            manifest = json.loads((root / relative / "manifest.json").read_bytes())
        except (OSError, ValueError, RecursionError):
            continue
        summary = manifest.get("summary") if isinstance(manifest, dict) else None
        if not isinstance(summary, dict):
            continue
        identity = summary.get("source_identity")
        if (summary.get("source_entry_sha256") != original_sha256
                or summary.get("output_entry_sha256") != replacement_sha256
                or not isinstance(identity, dict) or str(identity.get("entry", "")).upper() != entry.upper()):
            continue
        matches.append((relative, summary))
    if any(summary.get("operations") != matches[0][1].get("operations") for _, summary in matches[1:]):
        raise ValueError(f"Replacement {entry} matches authoring bundles that name different operations")
    last_error: Exception | None = None
    for relative, _summary in matches:
        try:
            return workflow.read_bundle(root / relative)[1]
        except (ValueError, OSError, KeyError, TypeError) as error:
            last_error = error
    if last_error is not None:
        raise ValueError(f"Replacement {entry}: the matching authoring bundle could not be read: {last_error}")
    return None


def _load_projection(root: Path, record: dict[str, Any], archive_sha256: str, read_entry: ReadEntry) -> dict[str, Any]:
    label = "Workspace projection"
    if not isinstance(record, dict):
        raise ValueError(f"{label} record is not an object")
    archive = _record_text(record, "target_archive", label)
    entry = _record_text(record, "target_entry", label)
    label = f"Workspace projection {archive}/{entry}"
    if archive.casefold() != "mes.arc":
        raise ValueError(f"{label} is outside mes.arc and is not carried")
    if record.get("kind") != "mes_text" or record.get("schema") != PROJECTION_SCHEMA:
        raise ValueError(f"{label} has an unsupported kind or schema")
    _check_entry(entry, label)
    if record.get("base_archive_sha256") != archive_sha256:
        raise ValueError(f"{label} belongs to another archive")
    original = _record_text(record, "original_entry_sha256", label)
    if workflow._sha(_read_entry(read_entry, entry)) != original:
        raise ValueError(f"{label}: the original entry differs from the archive")
    relative = _record_text(record, "projection_path", label)
    if not _safe_relative(relative, prefix=("projections", "mes"), parts=3):
        raise ValueError(f"{label} has an unsafe projection path")
    payload = _read_workspace_file(root, relative, _record_text(record, "projection_sha256", label), label)
    try:
        projection = json.loads(payload)
    except (ValueError, RecursionError) as error:
        raise ValueError(f"{label} file is not JSON") from error
    if (not isinstance(projection, dict) or projection.get("schema") != PROJECTION_SCHEMA
            or projection.get("base_archive_sha256") != archive_sha256
            or projection.get("entry_sha256") != original
            or projection.get("target_archive") != archive or projection.get("target_entry") != entry
            or not isinstance(projection.get("edits"), list) or not projection["edits"]):
        raise ValueError(f"{label} file does not match its record")
    _run(label, delta.validate_text_edits, projection["edits"])
    return {"entry": entry, "original": original, "edits": projection["edits"]}


def _operations(files: dict[str, bytes]) -> list[dict[str, Any]]:
    if workflow.SEQUENCE_MEMBER in files:
        return [row["operation"] for row in json.loads(files[workflow.SEQUENCE_MEMBER])["steps"]]
    return [json.loads(files["plan.json"])["operation"]]


def _build_delta(root: Path, record: Any, archive_sha256: str, read_entry: ReadEntry,
                 projection: dict[str, Any] | None) -> dict[str, Any]:
    label = "Workspace replacement"
    if not isinstance(record, dict):
        raise ValueError(f"{label} record is not an object")
    archive = _record_text(record, "target_archive", label)
    entry = _record_text(record, "target_entry", label)
    label = f"Workspace replacement {archive}/{entry}"
    if archive.casefold() != "mes.arc":
        raise ValueError(f"{label} is outside mes.arc; a raw replacement is payload and is not carried")
    _check_entry(entry, label)
    if record.get("base_archive_sha256") != archive_sha256:
        raise ValueError(f"{label} belongs to another archive")
    original = _record_text(record, "original_entry_sha256", label)
    replacement = _record_text(record, "replacement_sha256", label)
    source = _read_entry(read_entry, entry)
    if workflow._sha(source) != original:
        raise ValueError(f"{label}: the original entry differs from the archive")
    relative = _record_text(record, "replacement_path", label)
    if not _safe_relative(relative, prefix=("replacements",), parts=None):
        raise ValueError(f"{label} has an unsafe replacement path")
    _read_workspace_file(root, relative, replacement, label)
    files = _link_authoring(root, entry, original, replacement)
    if files is None:
        raise ValueError(f"{label} has no linked authoring bundle; a raw staged MES is payload and is not carried")
    identity = json.loads(files["handoff.json"])["source_identity"]
    if identity["archive_sha256"] != archive_sha256:
        raise ValueError(f"{label}: the authoring bundle belongs to another archive")
    edits: list[dict[str, Any]] = []
    if projection is not None:
        if projection["original"] != original:
            raise ValueError(f"{label}: its projection binds another original entry")
        edits = projection["edits"]
        relocated = {op["source_offset"] for op in _operations(files)
                     if op.get("kind") == "replace_message" and _is_int(op.get("source_offset"))}
        for edit in edits:
            if edit["source_offset"] in relocated:
                raise ValueError(
                    f"{label}: the projection edits the message at 0x{edit['source_offset']:X} "
                    "that the replacement relocates")
    built = _run(label, delta.build, files, source, edits)
    # The linked bundle was chosen by its hashes; the delta must reproduce the
    # workspace's replacement whatever the bundle readers verified.
    if built.get("output_entry_sha256") != replacement:
        raise ValueError(f"{label}: the built delta does not reproduce the workspace replacement")
    return built


def build(workspace_root: Path | str, read_entry: ReadEntry, archive_sha256: str, *,
          mod_id: str | None = None, mod_revision: int | None = None,
          names_dir: Path | str = DEFAULT_NAMES_DIR,
          definitions_dir: Path | str = DEFAULT_DEFINITIONS_DIR) -> dict[str, Any]:
    """Carry the whole workspace or nothing: every `mes.arc` replacement with a
    linked authoring bundle becomes a delta (its projection's edits the delta's
    text edits), every other `mes.arc` projection a text row, and the
    definitions the set. Any other record is refused, naming it."""
    root = Path(workspace_root)
    project_path, manifest_path = root / "project.json", root / "manifest.json"
    if not project_path.is_file():
        raise ValueError("Workspace project.json is missing")
    if not manifest_path.is_file():
        raise ValueError("Workspace manifest.json is missing")
    before = (workflow._sha(project_path.read_bytes()), workflow._sha(manifest_path.read_bytes()))
    project = _read_json_file(project_path, "Workspace project.json")
    manifest = _read_json_file(manifest_path, "Workspace manifest.json")
    if not isinstance(project, dict):
        raise ValueError("Workspace project.json is not an object")
    source_project_id = _check_project_binding(project, archive_sha256)
    if not isinstance(manifest, dict) or manifest.get("schema") != OVERLAY_SCHEMA:
        raise ValueError("Workspace manifest schema is unsupported")
    replacements, projections, definitions = (manifest.get(name, []) for name in
                                              ("replacements", "projections", "definitions"))
    if not all(isinstance(rows, list) for rows in (replacements, projections, definitions)):
        raise ValueError("Workspace manifest records must be arrays")
    if not (replacements or projections or definitions):
        raise ValueError("Workspace has nothing to carry")

    projection_by_entry: dict[str, dict[str, Any]] = {}
    for record in projections:
        loaded = _load_projection(root, record, archive_sha256, read_entry)
        if loaded["entry"].casefold() in projection_by_entry:
            raise ValueError(f"Workspace has two projections for {loaded['entry']}")
        projection_by_entry[loaded["entry"].casefold()] = loaded

    delta_documents = []
    for record in replacements:
        entry = record.get("target_entry") if isinstance(record, dict) else None
        projection = projection_by_entry.pop(entry.casefold(), None) if isinstance(entry, str) else None
        delta_documents.append(_build_delta(root, record, archive_sha256, read_entry, projection))

    text_rows = []
    for loaded in projection_by_entry.values():
        entry = loaded["entry"]
        source = _read_entry(read_entry, entry)
        identity = {"archive": "mes.arc", "entry": entry, "archive_sha256": archive_sha256,
                    "source_kind": "original_arc"}
        _run(f"Workspace projection mes.arc/{entry}", delta._check_text, workflow.analyze(source, identity),
             loaded["edits"])
        text_rows.append({"entry": entry, "source_entry_sha256": loaded["original"], "text_edits": loaded["edits"]})

    set_document = modset.build(root, names_dir, definitions_dir) if definitions else None
    if set_document is not None:
        mod = set_document["mod"]
        if (mod_id is not None and mod_id != mod["id"]) or (mod_revision is not None and mod_revision != mod["revision"]):
            raise ValueError("The requested mod identity disagrees with the workspace definitions' mod")
    else:
        if mod_id is None:
            raise ValueError("A bundle without definitions needs a mod id (--mod-id)")
        mod = {"id": mod_id, "revision": 1 if mod_revision is None else mod_revision}

    document = assemble(mod=mod, source_project_id=source_project_id, archive_sha256=archive_sha256,
                        delta_documents=delta_documents, text_rows=text_rows, set_document=set_document)
    validate(document, names_dir=names_dir, definitions_dir=definitions_dir)
    check_source(document, read_entry, archive_sha256)
    after = (workflow._sha(project_path.read_bytes()), workflow._sha(manifest_path.read_bytes()))
    if after != before:
        raise ValueError("Workspace changed during the build")
    return document


# ------------------------------------------------------------------------- CLI


def _open_archive(arc: Path) -> tuple[str, ReadEntry]:
    data = arc.read_bytes()
    rows = {name.casefold(): (offset, size) for name, offset, size in workflow.archive_reader.read_entries(arc)}

    def read_entry(name: str) -> bytes:
        row = rows.get(str(name).casefold())
        if row is None:
            raise KeyError(name)
        return data[row[0]:row[0] + row[1]]

    return workflow._sha(data), read_entry


def _assert_archive_unchanged(arc: Path, archive_sha256: str) -> None:
    if workflow._sha(arc.read_bytes()) != archive_sha256:
        raise ValueError("Local archive changed during the operation")


def _refuse_inside(path: Path, *boundaries: Path) -> None:
    resolved = path.resolve()
    for boundary in boundaries:
        try:
            resolved_boundary = boundary.resolve()
        except OSError:
            continue
        if resolved == resolved_boundary or resolved_boundary in resolved.parents:
            raise ValueError(
                "Mod bundle output must be outside the workspace, the original content set and the tracked definitions")


def _summary(document: dict[str, Any]) -> dict[str, Any]:
    definition_set = document["definition_set"]
    return {
        "ok": True, "schema": document["schema"], "mod_id": document["mod"]["id"],
        "mod_revision": document["mod"]["revision"], "delta_count": len(document["deltas"]),
        "text_projection_count": len(document["text_projections"]),
        "definition_count": 0 if definition_set is None else definition_set["definition_count"],
        "payload_sha256": document["payload_sha256"],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    build_parser = commands.add_parser("build")
    build_parser.add_argument("arc", type=Path)
    build_parser.add_argument("workspace_root", type=Path)
    build_parser.add_argument("out", type=Path)
    build_parser.add_argument("--mod-id", default=None)
    build_parser.add_argument("--mod-revision", type=int, default=None)
    build_parser.add_argument("--names", type=Path, default=DEFAULT_NAMES_DIR)
    build_parser.add_argument("--definitions-dir", type=Path, default=DEFAULT_DEFINITIONS_DIR)

    validate_parser = commands.add_parser("validate")
    validate_parser.add_argument("bundle", type=Path)
    validate_parser.add_argument("--arc", type=Path, default=None)
    validate_parser.add_argument("--names", type=Path, default=DEFAULT_NAMES_DIR)
    validate_parser.add_argument("--definitions-dir", type=Path, default=DEFAULT_DEFINITIONS_DIR)
    validate_parser.add_argument("--extract", type=Path, default=None)

    args = parser.parse_args()
    try:
        if args.command == "build":
            _refuse_inside(args.out, args.workspace_root, args.arc.parent, args.definitions_dir)
            archive_sha256, read_entry = _open_archive(args.arc)
            document = build(args.workspace_root, read_entry, archive_sha256, mod_id=args.mod_id,
                             mod_revision=args.mod_revision, names_dir=args.names,
                             definitions_dir=args.definitions_dir)
            _assert_archive_unchanged(args.arc, archive_sha256)
            publish(args.out, document)
        else:
            if args.extract is not None:
                boundaries = [args.definitions_dir] + ([args.arc.parent] if args.arc is not None else [])
                _refuse_inside(args.extract, *boundaries)
            document = read(args.bundle, args.names, args.definitions_dir)
            if args.arc is not None:
                archive_sha256, read_entry = _open_archive(args.arc)
                check_source(document, read_entry, archive_sha256)
                _assert_archive_unchanged(args.arc, archive_sha256)
            if args.extract is not None:
                extract(document, args.extract)
        print(json.dumps(_summary(document)))
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
