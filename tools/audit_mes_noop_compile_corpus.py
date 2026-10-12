from __future__ import annotations

import argparse
import concurrent.futures
import copy
import json
import os
from pathlib import Path
from typing import Any, Callable

import audit_mes_decompiler_corpus as decompiler_corpus
import compile_mes_noop as compiler
import decompile_mes_handoff as decompiler
import prepare_mes_editable_ir as editable_ir
import validate_mes_analyzer_handoff as handoff_validator
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


COMPILE_SPOOL_SCHEMA = "kakyu_mes_noop_compile_spool/v1"
MANIFEST_NAME = "noop-compile-spool-manifest.json"
MAX_JOBS = 4
DEFAULT_JOBS = min(MAX_JOBS, os.cpu_count() or 1)
TOP_LEVEL_KEYS = {
    "ok",
    "schema",
    "producer",
    "compatibility",
    "source_identity",
    "source_spool",
    "entry_count",
    "source_entry_count",
    "complete_archive",
    "entries",
    "coverage",
    "invariants",
    "payload_sha256",
}
ENTRY_KEYS = {
    "position",
    "archive_index",
    "entry",
    "mes_file",
    "audit_file",
    "handoff_sha256",
    "decompiler_ir_sha256",
    "editable_ir_sha256",
    "compile_audit_sha256",
    "entry_sha256",
    "bytecode_sha256",
    "size",
    "code_size",
    "region_count",
    "node_count",
    "typed_node_count",
    "opaque_node_count",
}
COVERAGE_KEYS = {
    "container_bytes",
    "code_bytes",
    "region_count",
    "node_count",
    "typed_node_count",
    "opaque_node_count",
}
INVARIANTS = {
    "all_compile_audits_valid": True,
    "all_outputs_byte_identical": True,
    "all_outputs_reopened": True,
    "all_operations_empty": True,
    "ordered_archive_scope_preserved": True,
    "manifest_published_last": True,
}

_WORKER_MANIFEST: dict[str, Any] | None = None
_WORKER_SPOOL_DIRECTORY: Path | None = None


class NoopCorpusError(ValueError):
    pass


def build(
    source_manifest: dict[str, Any],
    spool_directory: Path,
    output_directory: Path,
    jobs: int = 1,
    progress: Callable[[int, int, str], None] | None = None,
) -> dict[str, Any]:
    decompiler_corpus.validate_manifest(source_manifest)
    jobs = _validate_jobs(jobs)
    spool_directory = spool_directory.resolve()
    output_directory = output_directory.resolve()
    if spool_directory == output_directory:
        raise NoopCorpusError("MES no-op output directory must differ from its input spool")
    _create_new_directory(output_directory)
    rows = _compile_entries(
        source_manifest, spool_directory, jobs, progress
    )
    manifest_rows: list[dict[str, Any]] = []
    for row in rows:
        manifest_rows.append(_publish_entry(output_directory, row))
    document = _build_manifest(source_manifest, manifest_rows)
    document["payload_sha256"] = fingerprint(document)
    validate(document)
    manifest_path = output_directory / MANIFEST_NAME
    editable_ir.publish_new(
        manifest_path,
        editable_ir.canonical_json_bytes(document) + b"\n",
    )
    reopened = _load_json(manifest_path, "MES no-op compile-spool manifest")
    validate(reopened)
    if reopened != document:
        raise NoopCorpusError("MES no-op compile-spool manifest changed after publication")
    return document


def validate(document: dict[str, Any]) -> dict[str, Any]:
    if (
        document.get("schema") != COMPILE_SPOOL_SCHEMA
        or document.get("ok") is not True
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise NoopCorpusError("MES no-op compile-spool schema or fields changed")
    if document.get("producer") != {
        "implementation": "python_phase6_noop_corpus_compiler",
        "contract": COMPILE_SPOOL_SCHEMA,
    }:
        raise NoopCorpusError("MES no-op compile-spool producer changed")
    if document.get("compatibility") != {
        "policy": "exact_phase1_5_handoff_and_noop_compile_contracts",
        "input_spool_schema": decompiler_corpus.HANDOFF_SPOOL_SCHEMA,
        "input_handoff_schema": handoff_validator.HANDOFF_SCHEMA,
        "decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
        "editable_ir_schema": editable_ir.EDITABLE_IR_SCHEMA,
        "compile_audit_schema": compiler.NOOP_AUDIT_SCHEMA,
        "unknown_spool_schema": "reject",
        "unknown_v1_field": "reject",
        "payload_policy": "compiled_mes_and_compact_audit_only",
    }:
        raise NoopCorpusError("MES no-op compile-spool compatibility changed")
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise NoopCorpusError("MES no-op compile-spool fingerprint changed")
    source_identity = document.get("source_identity")
    source_spool = document.get("source_spool")
    if (
        not isinstance(source_identity, dict)
        or not isinstance(source_identity.get("archive"), str)
        or not source_identity["archive"]
        or not _is_sha256(source_identity.get("archive_sha256"))
        or not isinstance(source_spool, dict)
        or source_spool != {
            "schema": decompiler_corpus.HANDOFF_SPOOL_SCHEMA,
            "payload_sha256": source_spool.get("payload_sha256"),
        }
        or not _is_sha256(source_spool.get("payload_sha256"))
    ):
        raise NoopCorpusError("MES no-op compile-spool source identity changed")
    entries = document.get("entries")
    if not isinstance(entries, list) or not entries:
        raise NoopCorpusError("MES no-op compile-spool entries are missing")
    previous_archive_index = -1
    names: set[str] = set()
    files: set[str] = set()
    for position, row in enumerate(entries):
        if not isinstance(row, dict) or set(row) != ENTRY_KEYS:
            raise NoopCorpusError("MES no-op compile-spool entry fields changed")
        if int(row.get("position", -1)) != position:
            raise NoopCorpusError("MES no-op compile-spool order changed")
        archive_index = int(row.get("archive_index", -1))
        if archive_index <= previous_archive_index:
            raise NoopCorpusError("MES no-op compile archive order changed")
        previous_archive_index = archive_index
        entry = str(row.get("entry", ""))
        if not entry or entry.casefold() in names:
            raise NoopCorpusError("MES no-op compile entry identity changed")
        names.add(entry.casefold())
        for key in ("mes_file", "audit_file"):
            file_name = str(row.get(key, ""))
            if (
                not file_name
                or Path(file_name).name != file_name
                or "/" in file_name
                or "\\" in file_name
                or file_name.casefold() in files
            ):
                raise NoopCorpusError("MES no-op compile output file changed")
            files.add(file_name.casefold())
        for key in (
            "handoff_sha256",
            "decompiler_ir_sha256",
            "editable_ir_sha256",
            "compile_audit_sha256",
            "entry_sha256",
            "bytecode_sha256",
        ):
            if not _is_sha256(row.get(key)):
                raise NoopCorpusError("MES no-op compile entry hash changed")
        for key in (
            "size",
            "code_size",
            "region_count",
            "node_count",
            "typed_node_count",
            "opaque_node_count",
        ):
            if not _is_nonnegative_int(row.get(key)):
                raise NoopCorpusError("MES no-op compile entry count changed")
        if int(row["node_count"]) != int(row["typed_node_count"]) + int(
            row["opaque_node_count"]
        ):
            raise NoopCorpusError("MES no-op compile node partition changed")
    entry_count = int(document.get("entry_count", -1))
    source_entry_count = int(document.get("source_entry_count", -1))
    if entry_count != len(entries) or source_entry_count < entry_count:
        raise NoopCorpusError("MES no-op compile-spool count changed")
    if bool(document.get("complete_archive", False)) != (
        entry_count == source_entry_count
    ):
        raise NoopCorpusError("MES no-op compile-spool scope changed")
    coverage = document.get("coverage")
    if not isinstance(coverage, dict) or set(coverage) != COVERAGE_KEYS:
        raise NoopCorpusError("MES no-op compile-spool coverage fields changed")
    expected_coverage = _coverage(entries)
    if coverage != expected_coverage:
        raise NoopCorpusError("MES no-op compile-spool coverage changed")
    if document.get("invariants") != INVARIANTS:
        raise NoopCorpusError("MES no-op compile-spool invariants changed")
    return {
        "ok": True,
        "schema": COMPILE_SPOOL_SCHEMA,
        "entry_count": entry_count,
        "complete_archive": bool(document["complete_archive"]),
        "payload_sha256": retained,
    }


def _compile_entries(
    manifest: dict[str, Any],
    spool_directory: Path,
    jobs: int,
    progress: Callable[[int, int, str], None] | None,
) -> list[dict[str, Any]]:
    total = len(manifest["entries"])
    if jobs == 1 or total == 1:
        rows = []
        for position, manifest_row in enumerate(manifest["entries"]):
            rows.append(_load_and_compile_entry(manifest, spool_directory, manifest_row))
            if progress is not None:
                progress(position + 1, total, str(manifest_row["entry"]))
        return rows
    ordered: list[dict[str, Any] | None] = [None] * total
    executor = concurrent.futures.ProcessPoolExecutor(
        max_workers=min(jobs, total),
        initializer=_initialize_worker,
        initargs=(manifest, spool_directory),
    )
    futures: dict[concurrent.futures.Future[dict[str, Any]], dict[str, Any]] = {}
    try:
        futures = {
            executor.submit(_worker, row): row for row in manifest["entries"]
        }
        completed = 0
        for future in concurrent.futures.as_completed(futures):
            row = future.result()
            position = int(row["position"])
            if not 0 <= position < total or ordered[position] is not None:
                raise NoopCorpusError("MES no-op corpus worker order changed")
            ordered[position] = row
            completed += 1
            if progress is not None:
                progress(completed, total, str(row["entry"]))
    except BaseException:
        for future in futures:
            future.cancel()
        executor.shutdown(wait=True, cancel_futures=True)
        raise
    else:
        executor.shutdown(wait=True)
    if any(row is None for row in ordered):
        raise NoopCorpusError("MES no-op corpus worker result is missing")
    return [row for row in ordered if row is not None]


def _initialize_worker(manifest: dict[str, Any], spool_directory: Path) -> None:
    global _WORKER_MANIFEST
    global _WORKER_SPOOL_DIRECTORY
    decompiler_corpus.validate_manifest(manifest)
    _WORKER_MANIFEST = manifest
    _WORKER_SPOOL_DIRECTORY = spool_directory


def _worker(manifest_row: dict[str, Any]) -> dict[str, Any]:
    if _WORKER_MANIFEST is None or _WORKER_SPOOL_DIRECTORY is None:
        raise NoopCorpusError("MES no-op corpus worker was not initialized")
    return _load_and_compile_entry(
        _WORKER_MANIFEST, _WORKER_SPOOL_DIRECTORY, manifest_row
    )


def _load_and_compile_entry(
    manifest: dict[str, Any],
    spool_directory: Path,
    manifest_row: dict[str, Any],
) -> dict[str, Any]:
    handoff_path = spool_directory / str(manifest_row["file"])
    if not handoff_path.is_file():
        raise NoopCorpusError(
            f"MES no-op handoff file is missing: {manifest_row['entry']}"
        )
    handoff = _load_json(handoff_path, "MES analyzer handoff")
    handoff_validator.validate(handoff)
    if (
        str(handoff.get("payload_sha256", ""))
        != str(manifest_row["handoff_sha256"])
        or str(handoff.get("source_identity", {}).get("entry", ""))
        != str(manifest_row["entry"])
        or str(handoff.get("source_identity", {}).get("archive_sha256", ""))
        != str(manifest["source_identity"]["archive_sha256"])
    ):
        raise NoopCorpusError("MES no-op handoff source identity changed")
    linear = decompiler.lift(handoff)
    editable = editable_ir.prepare(linear)
    output, audit = compiler.compile_noop(editable)
    return {
        "position": int(manifest_row["position"]),
        "archive_index": int(manifest_row["archive_index"]),
        "entry": str(manifest_row["entry"]),
        "handoff_sha256": str(handoff["payload_sha256"]),
        "decompiler_ir_sha256": str(linear["payload_sha256"]),
        "editable_ir_sha256": str(editable["payload_sha256"]),
        "compile_audit_sha256": str(audit["payload_sha256"]),
        "output": output,
        "audit": audit,
    }


def _publish_entry(output_directory: Path, row: dict[str, Any]) -> dict[str, Any]:
    stem = (
        f"{int(row['position']):04d}-{_safe_name(str(row['entry']))}-"
        f"{str(row['compile_audit_sha256'])[:12]}"
    )
    mes_name = f"{stem}.mes"
    audit_name = f"{stem}.audit.json"
    mes_path = output_directory / mes_name
    audit_path = output_directory / audit_name
    output = row["output"]
    audit = row["audit"]
    published_mes = False
    try:
        editable_ir.publish_new(mes_path, output)
        published_mes = True
        editable_ir.publish_new(
            audit_path, editable_ir.canonical_json_bytes(audit) + b"\n"
        )
    except BaseException:
        if published_mes:
            mes_path.unlink(missing_ok=True)
        raise
    coverage = audit["coverage"]
    return {
        "position": int(row["position"]),
        "archive_index": int(row["archive_index"]),
        "entry": str(row["entry"]),
        "mes_file": mes_name,
        "audit_file": audit_name,
        "handoff_sha256": str(row["handoff_sha256"]),
        "decompiler_ir_sha256": str(row["decompiler_ir_sha256"]),
        "editable_ir_sha256": str(row["editable_ir_sha256"]),
        "compile_audit_sha256": str(row["compile_audit_sha256"]),
        "entry_sha256": str(audit["output"]["entry_sha256"]),
        "bytecode_sha256": str(audit["output"]["bytecode_sha256"]),
        "size": int(audit["output"]["size"]),
        "code_size": int(audit["output"]["code_size"]),
        "region_count": int(coverage["region_count"]),
        "node_count": int(coverage["node_count"]),
        "typed_node_count": int(coverage["typed_node_count"]),
        "opaque_node_count": int(coverage["opaque_node_count"]),
    }


def _build_manifest(
    source_manifest: dict[str, Any], entries: list[dict[str, Any]]
) -> dict[str, Any]:
    return {
        "ok": True,
        "schema": COMPILE_SPOOL_SCHEMA,
        "producer": {
            "implementation": "python_phase6_noop_corpus_compiler",
            "contract": COMPILE_SPOOL_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_phase1_5_handoff_and_noop_compile_contracts",
            "input_spool_schema": decompiler_corpus.HANDOFF_SPOOL_SCHEMA,
            "input_handoff_schema": handoff_validator.HANDOFF_SCHEMA,
            "decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "editable_ir_schema": editable_ir.EDITABLE_IR_SCHEMA,
            "compile_audit_schema": compiler.NOOP_AUDIT_SCHEMA,
            "unknown_spool_schema": "reject",
            "unknown_v1_field": "reject",
            "payload_policy": "compiled_mes_and_compact_audit_only",
        },
        "source_identity": copy.deepcopy(source_manifest["source_identity"]),
        "source_spool": {
            "schema": decompiler_corpus.HANDOFF_SPOOL_SCHEMA,
            "payload_sha256": str(source_manifest["payload_sha256"]),
        },
        "entry_count": len(entries),
        "source_entry_count": int(source_manifest["source_entry_count"]),
        "complete_archive": bool(source_manifest["complete_archive"]),
        "entries": entries,
        "coverage": _coverage(entries),
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _coverage(entries: list[dict[str, Any]]) -> dict[str, int]:
    return {
        "container_bytes": sum(int(row["size"]) for row in entries),
        "code_bytes": sum(int(row["code_size"]) for row in entries),
        "region_count": sum(int(row["region_count"]) for row in entries),
        "node_count": sum(int(row["node_count"]) for row in entries),
        "typed_node_count": sum(int(row["typed_node_count"]) for row in entries),
        "opaque_node_count": sum(int(row["opaque_node_count"]) for row in entries),
    }


def _validate_jobs(jobs: int) -> int:
    if isinstance(jobs, bool) or not isinstance(jobs, int) or not 1 <= jobs <= MAX_JOBS:
        raise NoopCorpusError(f"MES no-op corpus jobs must be between 1 and {MAX_JOBS}")
    return jobs


def _create_new_directory(path: Path) -> None:
    if path.exists():
        raise NoopCorpusError("MES no-op output directory already exists")
    if not path.parent.is_dir():
        raise NoopCorpusError("MES no-op output parent directory does not exist")
    path.mkdir()


def _safe_name(value: str) -> str:
    output = "".join(
        character.lower() if character.isascii() and character.isalnum() else "_"
        for character in value
    )
    return output or "entry"


def _load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise NoopCorpusError(f"{label} could not be read") from error
    if not isinstance(value, dict):
        raise NoopCorpusError(f"{label} is not an object")
    return value


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compile every source-bound MES analyzer handoff through the Phase 6 "
            "zero-operation compiler and publish a compact output spool."
        )
    )
    parser.add_argument("handoff_spool", type=Path)
    parser.add_argument("output_directory", type=Path)
    parser.add_argument("--jobs", type=int, default=DEFAULT_JOBS)
    args = parser.parse_args()
    manifest_path = args.handoff_spool / "handoff-spool-manifest.json"
    manifest = _load_json(manifest_path, "MES decompiler handoff-spool manifest")

    def print_progress(completed: int, total: int, entry: str) -> None:
        if completed % 25 == 0 or completed == total:
            print(
                f"MES_NOOP_CORPUS_PROGRESS {completed}/{total} entry={entry}",
                flush=True,
            )

    document = build(
        manifest,
        args.handoff_spool,
        args.output_directory,
        jobs=args.jobs,
        progress=print_progress,
    )
    print(
        "MES_NOOP_COMPILE_CORPUS_PASS "
        f"schema={document['schema']} "
        f"entries={document['entry_count']}/{document['source_entry_count']} "
        f"complete={str(document['complete_archive']).lower()} "
        f"bytes={document['coverage']['container_bytes']} "
        f"nodes={document['coverage']['node_count']} "
        f"opaque={document['coverage']['opaque_node_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
