from __future__ import annotations

import argparse
import concurrent.futures
import copy
import json
import os
from pathlib import Path
from typing import Any, Callable

import annotate_mes_decompiler as semantic_annotations
import audit_mes_decompiler_equivalence as equivalence_audit
import compose_mes_renderer_loops as loop_composer
import compose_mes_renderer_input as core_composer
import compose_mes_renderer_overlays as overlay_composer
import decompile_mes_handoff as decompiler
import prove_mes_call_families as call_families
import prove_mes_control_flow as control_flow
import prove_mes_cross_region_joins as cross_region_joins
import prove_mes_execution_fallthroughs as execution_fallthroughs
import prove_mes_guard_chains as guard_chains
import prove_mes_if_regions as if_regions
import prove_mes_natural_loops as natural_loops
import prove_mes_predicate_dispatches as predicate_dispatches
import prove_mes_shared_call_returns as shared_call_returns
import prove_mes_value_dispatches as value_dispatches
import render_mes_pseudocode as pseudocode_renderer
import validate_mes_analyzer_handoff as handoff_validator
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


HANDOFF_SPOOL_SCHEMA = "kakyu_mes_decompiler_handoff_spool/v1"
CORPUS_AUDIT_SCHEMA = "kakyu_mes_decompiler_corpus_audit/v1"
MAX_CORPUS_JOBS = 4
DEFAULT_CORPUS_JOBS = min(MAX_CORPUS_JOBS, os.cpu_count() or 1)

_WORKER_MANIFEST: dict[str, Any] | None = None
_WORKER_SPOOL_DIRECTORY: Path | None = None
_WORKER_LIBRARY_AUDIT: dict[str, Any] | None = None


class CorpusAuditError(ValueError):
    pass


def validate_manifest(manifest: dict[str, Any]) -> dict[str, Any]:
    if manifest.get("schema") != HANDOFF_SPOOL_SCHEMA:
        raise CorpusAuditError("unsupported MES decompiler handoff-spool schema")
    if manifest.get("handoff_schema") != handoff_validator.HANDOFF_SCHEMA:
        raise CorpusAuditError("unsupported MES analyzer handoff dependency")
    retained = manifest.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(manifest) != retained
    ):
        raise CorpusAuditError("MES decompiler handoff-spool fingerprint changed")
    source_identity = manifest.get("source_identity")
    if (
        not isinstance(source_identity, dict)
        or not isinstance(source_identity.get("archive"), str)
        or not source_identity["archive"]
        or not _is_sha256(source_identity.get("archive_sha256"))
    ):
        raise CorpusAuditError("MES decompiler handoff-spool source is missing")
    entries = manifest.get("entries")
    if not isinstance(entries, list) or not entries:
        raise CorpusAuditError("MES decompiler handoff-spool entries are missing")
    names: set[str] = set()
    files: set[str] = set()
    previous_archive_index = -1
    for position, row in enumerate(entries):
        if not isinstance(row, dict) or int(row.get("position", -1)) != position:
            raise CorpusAuditError("MES decompiler handoff-spool order changed")
        archive_index = int(row.get("archive_index", -1))
        if archive_index <= previous_archive_index:
            raise CorpusAuditError("MES decompiler archive order changed")
        previous_archive_index = archive_index
        entry = str(row.get("entry", ""))
        folded = entry.casefold()
        if not entry or folded in names:
            raise CorpusAuditError("MES decompiler handoff-spool entry changed")
        names.add(folded)
        file_name = str(row.get("file", ""))
        if (
            not file_name
            or Path(file_name).name != file_name
            or "/" in file_name
            or "\\" in file_name
            or file_name.casefold() in files
        ):
            raise CorpusAuditError("MES decompiler handoff-spool file changed")
        files.add(file_name.casefold())
        if not _is_sha256(row.get("handoff_sha256")):
            raise CorpusAuditError("MES decompiler handoff identity is missing")
    if int(manifest.get("entry_count", -1)) != len(entries):
        raise CorpusAuditError("MES decompiler handoff-spool count changed")
    source_entry_count = int(manifest.get("source_entry_count", -1))
    complete_archive = bool(manifest.get("complete_archive", False))
    if source_entry_count < len(entries) or complete_archive != (
        source_entry_count == len(entries)
    ):
        raise CorpusAuditError("MES decompiler handoff-spool scope changed")
    library_identity = manifest.get("library_audit")
    if (
        not isinstance(library_identity, dict)
        or library_identity.get("schema")
        != shared_call_returns.LIBRARY_AUDIT_SCHEMA
        or not _is_sha256(library_identity.get("input_sha256"))
    ):
        raise CorpusAuditError("MES decompiler library-audit identity is missing")
    return {
        "ok": True,
        "schema": HANDOFF_SPOOL_SCHEMA,
        "entry_count": len(entries),
        "complete_archive": complete_archive,
        "payload_sha256": retained,
    }


def audit(
    manifest: dict[str, Any],
    spool_directory: Path,
    library_audit: dict[str, Any],
    progress: Callable[[int, int, str], None] | None = None,
    jobs: int = 1,
) -> dict[str, Any]:
    validate_manifest(manifest)
    _validate_library_identity(manifest, library_audit)
    jobs = _validate_jobs(jobs)
    total = len(manifest["entries"])
    if jobs == 1 or total == 1:
        entry_rows = []
        for position, manifest_row in enumerate(manifest["entries"]):
            entry_rows.append(
                _load_and_audit_entry(
                    manifest, spool_directory, manifest_row, library_audit
                )
            )
            if progress is not None:
                progress(position + 1, total, str(manifest_row["entry"]))
    else:
        entry_rows = _audit_entries_parallel(
            manifest,
            spool_directory,
            library_audit,
            min(jobs, total),
            progress,
        )
    document = _build_report(manifest, library_audit, entry_rows)
    document["payload_sha256"] = fingerprint(document)
    validate(document)
    return document


def _validate_jobs(jobs: int) -> int:
    if isinstance(jobs, bool) or not isinstance(jobs, int):
        raise CorpusAuditError("MES corpus jobs must be an integer")
    if not 1 <= jobs <= MAX_CORPUS_JOBS:
        raise CorpusAuditError(
            f"MES corpus jobs must be between 1 and {MAX_CORPUS_JOBS}"
        )
    return jobs


def _load_and_audit_entry(
    manifest: dict[str, Any],
    spool_directory: Path,
    manifest_row: dict[str, Any],
    library_audit: dict[str, Any],
) -> dict[str, Any]:
    entry_name = str(manifest_row["entry"])
    handoff_path = spool_directory / str(manifest_row["file"])
    if not handoff_path.is_file():
        raise CorpusAuditError(f"MES handoff spool file is missing: {entry_name}")
    handoff = _load_json(handoff_path, "MES analyzer handoff")
    _validate_handoff_identity(manifest, manifest_row, handoff)
    return _audit_entry(manifest_row, handoff, library_audit)


def _initialize_entry_worker(
    manifest: dict[str, Any],
    spool_directory: Path,
    library_audit: dict[str, Any],
) -> None:
    global _WORKER_MANIFEST
    global _WORKER_SPOOL_DIRECTORY
    global _WORKER_LIBRARY_AUDIT
    _validate_library_identity(manifest, library_audit)
    _WORKER_MANIFEST = manifest
    _WORKER_SPOOL_DIRECTORY = spool_directory
    _WORKER_LIBRARY_AUDIT = library_audit


def _audit_entry_worker(manifest_row: dict[str, Any]) -> dict[str, Any]:
    if (
        _WORKER_MANIFEST is None
        or _WORKER_SPOOL_DIRECTORY is None
        or _WORKER_LIBRARY_AUDIT is None
    ):
        raise CorpusAuditError("MES corpus worker was not initialized")
    return _load_and_audit_entry(
        _WORKER_MANIFEST,
        _WORKER_SPOOL_DIRECTORY,
        manifest_row,
        _WORKER_LIBRARY_AUDIT,
    )


def _audit_entries_parallel(
    manifest: dict[str, Any],
    spool_directory: Path,
    library_audit: dict[str, Any],
    jobs: int,
    progress: Callable[[int, int, str], None] | None,
) -> list[dict[str, Any]]:
    total = len(manifest["entries"])
    ordered: list[dict[str, Any] | None] = [None] * total
    executor = concurrent.futures.ProcessPoolExecutor(
        max_workers=jobs,
        initializer=_initialize_entry_worker,
        initargs=(manifest, spool_directory, library_audit),
    )
    futures: dict[
        concurrent.futures.Future[dict[str, Any]], dict[str, Any]
    ] = {}
    try:
        futures = {
            executor.submit(_audit_entry_worker, manifest_row): manifest_row
            for manifest_row in manifest["entries"]
        }
        completed = 0
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            position = int(result["position"])
            if not 0 <= position < total or ordered[position] is not None:
                raise CorpusAuditError("MES corpus worker result order changed")
            ordered[position] = result
            completed += 1
            if progress is not None:
                progress(completed, total, str(result["entry"]))
    except BaseException:
        for future in futures:
            future.cancel()
        executor.shutdown(wait=True, cancel_futures=True)
        raise
    else:
        executor.shutdown(wait=True)
    if any(row is None for row in ordered):
        raise CorpusAuditError("MES corpus worker result is missing")
    return [row for row in ordered if row is not None]


def validate(document: dict[str, Any]) -> dict[str, Any]:
    if document.get("schema") != CORPUS_AUDIT_SCHEMA:
        raise CorpusAuditError("unsupported MES decompiler corpus-audit schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise CorpusAuditError("MES decompiler corpus-audit fingerprint changed")
    entries = document.get("entries")
    totals = document.get("coverage")
    if not isinstance(entries, list) or not entries or not isinstance(totals, dict):
        raise CorpusAuditError("MES decompiler corpus-audit coverage is missing")
    for position, row in enumerate(entries):
        if not isinstance(row, dict) or int(row.get("position", -1)) != position:
            raise CorpusAuditError("MES decompiler corpus-audit order changed")
        if not row.get("equivalent", False):
            raise CorpusAuditError("MES decompiler corpus entry is not equivalent")
    expected_totals = _coverage_totals(entries)
    if totals != expected_totals:
        raise CorpusAuditError("MES decompiler corpus aggregate changed")
    invariants = document.get("invariants")
    if invariants != _aggregate_invariants(entries):
        raise CorpusAuditError("MES decompiler corpus invariants changed")
    if int(document.get("entry_count", -1)) != len(entries):
        raise CorpusAuditError("MES decompiler corpus entry count changed")
    source_entry_count = int(document.get("source_entry_count", -1))
    if (
        source_entry_count < len(entries)
        or bool(document.get("complete_archive", False))
        != (source_entry_count == len(entries))
    ):
        raise CorpusAuditError("MES decompiler corpus scope changed")
    if not document.get("equivalent", False) or not all(invariants.values()):
        raise CorpusAuditError("MES decompiler corpus equivalence is incomplete")
    return {
        "ok": True,
        "schema": CORPUS_AUDIT_SCHEMA,
        "entry_count": len(entries),
        "payload_sha256": retained,
    }


def _audit_entry(
    manifest_row: dict[str, Any],
    handoff: dict[str, Any],
    library_audit: dict[str, Any],
    reuse_validations: bool = True,
) -> dict[str, Any]:
    with _EntryValidationReuse(reuse_validations):
        return _audit_entry_in_session(manifest_row, handoff, library_audit)


def _audit_entry_in_session(
    manifest_row: dict[str, Any],
    handoff: dict[str, Any],
    library_audit: dict[str, Any],
) -> dict[str, Any]:
    linear = decompiler.lift(handoff)
    annotations = semantic_annotations.annotate(linear)
    flow = control_flow.prove(linear)
    conditionals = if_regions.prove(linear, flow)
    guards = guard_chains.prove(linear, flow, conditionals)
    values = value_dispatches.prove(linear, flow, conditionals, guards)
    predicates = predicate_dispatches.prove(
        linear, flow, conditionals, guards, values
    )
    joins = cross_region_joins.prove(linear, flow, conditionals)
    calls = call_families.prove(linear)
    shared = shared_call_returns.prove(linear, library_audit)
    execution = execution_fallthroughs.prove(
        linear, flow, shared, library_audit
    )
    loops = natural_loops.prove(
        linear, flow, conditionals, execution, shared, library_audit
    )
    renderer = loop_composer.compose(
        linear,
        annotations,
        flow,
        conditionals,
        guards,
        values,
        predicates,
        joins,
        calls,
        library_audit,
        shared,
        execution,
        loops,
    )
    pseudocode = pseudocode_renderer.render(renderer)
    equivalence = equivalence_audit.audit(renderer, pseudocode)
    coverage = copy.deepcopy(equivalence["coverage"])
    coverage.update(
        {
            "flow_graph_count": int(flow["coverage"]["graph_count"]),
            "flow_graph_node_count": int(flow["coverage"]["graph_node_count"]),
            "flow_graph_edge_count": int(flow["coverage"]["graph_edge_count"]),
            "flow_proven_edge_count": int(flow["coverage"]["proven_edge_count"]),
            "flow_unresolved_construct_count": int(
                flow["coverage"]["unresolved_construct_count"]
            ),
            "proved_if_then_count": int(
                conditionals["coverage"]["if_then_region_count"]
            ),
            "proved_if_else_count": int(
                conditionals["coverage"]["if_else_region_count"]
            ),
            "proved_natural_loop_count": int(
                renderer["coverage"]["natural_loop_overlay_count"]
            ),
            "proved_shared_call_return_count": int(
                renderer["coverage"]["proved_shared_call_return_count"]
            ),
            "unresolved_shared_call_count": int(
                renderer["coverage"]["unresolved_shared_call_count"]
            ),
        }
    )
    invariants = {
        "source_partition_complete": bool(coverage["source_partition_complete"]),
        "region_node_ownership_complete": bool(
            coverage["region_node_ownership_complete"]
        ),
        "all_flow_edges_accounted": bool(
            flow["coverage"]["all_graph_edges_accounted"]
        ),
        "all_linear_nodes_rendered_once": bool(
            coverage["all_linear_nodes_rendered_once"]
        ),
        "all_structures_rendered_once": bool(
            coverage["all_structures_rendered_once"]
        ),
        "all_overlays_rendered_once": bool(
            coverage["all_overlays_rendered_once"]
        ),
        "all_rendered_sources_reverse": bool(
            coverage["all_rendered_sources_reverse"]
        ),
    }
    return {
        "position": int(manifest_row["position"]),
        "archive_index": int(manifest_row["archive_index"]),
        "entry": str(manifest_row["entry"]),
        "equivalent": bool(equivalence["equivalent"] and all(invariants.values())),
        "inputs": {
            "handoff_sha256": handoff["payload_sha256"],
            "linear_ir_sha256": linear["payload_sha256"],
            "renderer_input_sha256": renderer["payload_sha256"],
            "pseudocode_sha256": pseudocode["payload_sha256"],
            "equivalence_audit_sha256": equivalence["payload_sha256"],
        },
        "coverage": coverage,
        "invariants": invariants,
        "unresolved_semantic_categories": copy.deepcopy(
            equivalence["unresolved_inventory"]["semantic_categories"]
        ),
    }


class _EntryValidationReuse:
    """Reuse exact immutable documents only during one entry's pipeline."""

    def __init__(self, enabled: bool) -> None:
        self.enabled = enabled
        self._restores: list[tuple[Any, str, Any]] = []

    def __enter__(self) -> _EntryValidationReuse:
        if not self.enabled:
            return self
        validation_modules = (
            decompiler,
            semantic_annotations,
            control_flow,
            if_regions,
            guard_chains,
            value_dispatches,
            predicate_dispatches,
            cross_region_joins,
            call_families,
            shared_call_returns,
            execution_fallthroughs,
            natural_loops,
            core_composer,
            overlay_composer,
            loop_composer,
            pseudocode_renderer,
            equivalence_audit,
        )
        for module in validation_modules:
            self._patch(module, "validate")
        self._patch(core_composer, "compose")
        self._patch(overlay_composer, "compose")
        self._patch(shared_call_returns, "input_fingerprint")
        return self

    def __exit__(self, *_error: Any) -> None:
        for module, name, original in reversed(self._restores):
            setattr(module, name, original)
        self._restores.clear()

    def _patch(self, module: Any, name: str) -> None:
        original = getattr(module, name)
        cache: dict[tuple[Any, ...], Any] = {}

        def cached(*args: Any, **kwargs: Any) -> Any:
            key = tuple(_validation_identity(value) for value in args) + tuple(
                (key, _validation_identity(value))
                for key, value in sorted(kwargs.items())
            )
            if key not in cache:
                cache[key] = original(*args, **kwargs)
            return cache[key]

        self._restores.append((module, name, original))
        setattr(module, name, cached)


def _validation_identity(value: Any) -> Any:
    if isinstance(value, dict):
        return (
            "dict",
            id(value),
            value.get("schema"),
            value.get("payload_sha256"),
        )
    if isinstance(value, (str, int, bool, type(None))):
        return (type(value).__name__, value)
    return (type(value).__name__, id(value))


def _build_report(
    manifest: dict[str, Any],
    library_audit: dict[str, Any],
    entries: list[dict[str, Any]],
) -> dict[str, Any]:
    semantic_categories = sorted(
        {
            str(category)
            for row in entries
            for category in row["unresolved_semantic_categories"]
        }
    )
    invariants = _aggregate_invariants(entries)
    return {
        "ok": True,
        "schema": CORPUS_AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase5_bounded_spool_corpus_auditor",
            "contract": CORPUS_AUDIT_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_handoff_spool_and_phase5_contract_chain",
            "input_spool_schema": HANDOFF_SPOOL_SCHEMA,
            "input_handoff_schema": handoff_validator.HANDOFF_SCHEMA,
            "input_equivalence_schema": equivalence_audit.EQUIVALENCE_AUDIT_SCHEMA,
            "unknown_corpus_schema": "reject",
            "unknown_v1_field": "reject",
            "intermediate_policy": "one_entry_in_memory_compact_rows_only",
            "payload_policy": "no_original_bytes_or_pseudocode_text",
        },
        "source_identity": copy.deepcopy(manifest["source_identity"]),
        "inputs": {
            "handoff_spool_sha256": manifest["payload_sha256"],
            "library_audit_sha256": shared_call_returns.input_fingerprint(
                library_audit
            ),
        },
        "entry_count": len(entries),
        "source_entry_count": int(manifest["source_entry_count"]),
        "complete_archive": bool(manifest["complete_archive"]),
        "equivalent": all(row["equivalent"] for row in entries),
        "invariants": invariants,
        "coverage": _coverage_totals(entries),
        "unresolved_semantic_categories": semantic_categories,
        "entries": entries,
    }


def _coverage_totals(entries: list[dict[str, Any]]) -> dict[str, int]:
    numeric_keys = sorted(
        {
            key
            for row in entries
            for key, value in row["coverage"].items()
            if isinstance(value, int) and not isinstance(value, bool)
        }
    )
    return {
        key: sum(int(row["coverage"].get(key, 0)) for row in entries)
        for key in numeric_keys
    }


def _aggregate_invariants(entries: list[dict[str, Any]]) -> dict[str, bool]:
    keys = sorted(
        {key for row in entries for key in row.get("invariants", {})}
    )
    return {
        key: all(bool(row["invariants"].get(key, False)) for row in entries)
        for key in keys
    }


def _validate_library_identity(
    manifest: dict[str, Any], library_audit: dict[str, Any]
) -> None:
    if library_audit.get("schema") != shared_call_returns.LIBRARY_AUDIT_SCHEMA:
        raise CorpusAuditError("unsupported MES library-audit dependency")
    source = manifest["source_identity"]
    if (
        str(library_audit.get("archive_name", "")).casefold()
        != str(source["archive"]).casefold()
        or library_audit.get("archive_sha256") != source["archive_sha256"]
        or not library_audit.get("source_archive_unchanged", False)
    ):
        raise CorpusAuditError("MES library audit does not match the handoff spool")
    if (
        shared_call_returns.input_fingerprint(library_audit)
        != manifest["library_audit"]["input_sha256"]
    ):
        raise CorpusAuditError("MES library audit payload identity changed")
    shared_call_returns._validate_library_audit(library_audit)


def _validate_handoff_identity(
    manifest: dict[str, Any],
    manifest_row: dict[str, Any],
    handoff: dict[str, Any],
) -> None:
    handoff_validator.validate(handoff)
    if handoff.get("payload_sha256") != manifest_row["handoff_sha256"]:
        raise CorpusAuditError("MES handoff spool payload identity changed")
    identity = handoff.get("source_identity", {})
    source = manifest["source_identity"]
    if (
        str(identity.get("entry", "")) != str(manifest_row["entry"])
        or str(identity.get("archive", "")).casefold()
        != str(source["archive"]).casefold()
        or identity.get("archive_sha256") != source["archive_sha256"]
    ):
        raise CorpusAuditError("MES handoff spool source identity changed")


def _load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise CorpusAuditError(f"{label} could not be read") from error
    if not isinstance(value, dict):
        raise CorpusAuditError(f"{label} is not an object")
    return value


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Run the complete provenance-preserving MES Phase 5 chain over "
            "a bounded handoff spool and emit compact corpus equivalence JSON."
        )
    )
    parser.add_argument("manifest", type=Path)
    parser.add_argument("library_audit", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--jobs",
        type=int,
        default=DEFAULT_CORPUS_JOBS,
        help=(
            "Independent entry processes "
            f"(default: {DEFAULT_CORPUS_JOBS}, maximum: {MAX_CORPUS_JOBS})."
        ),
    )
    args = parser.parse_args()
    manifest = _load_json(args.manifest, "MES handoff spool manifest")
    library_audit = _load_json(args.library_audit, "MES library audit")

    def print_progress(done: int, total: int, entry: str) -> None:
        if done == total or done % 25 == 0:
            print(
                f"MES_DECOMPILER_CORPUS_PROGRESS entries={done}/{total} "
                f"last={entry}",
                flush=True,
            )

    document = audit(
        manifest,
        args.manifest.parent,
        library_audit,
        print_progress,
        args.jobs,
    )
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    input_paths = {
        args.manifest.resolve(),
        args.library_audit.resolve(),
        *(
            args.manifest.parent / str(row["file"])
            for row in manifest["entries"]
        ),
    }
    if args.output.resolve() in input_paths:
        raise CorpusAuditError("corpus audit output must not replace an input")
    args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_DECOMPILER_CORPUS_AUDIT_PASS "
        f"schema={document['schema']} entries={document['entry_count']} "
        f"nodes={document['coverage']['linear_node_count']} "
        f"payload_sha256={document['payload_sha256']}",
        flush=True,
    )


if __name__ == "__main__":
    main()
