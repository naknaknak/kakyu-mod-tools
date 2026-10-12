"""Measure Python analyzer components or complete handoffs against a GD digest.

Phase 1-4 authority is MA-09's frozen corpus fingerprint: a SHA-256 over one
``<name>\\t<entry_sha256>\\t<payload_sha256>`` line per MES/LIB entry. Moving that
authority to Python means reproducing it, and reproducing it is one boolean --
which is exactly the estimate TD-12 existed to replace. A single wrong field in
one instruction of one entry reports the same failure as having no producer.

So this compares component fingerprints from
``export_mes_handoff_digest.gd`` against the same components built in Python,
and reports three states per component rather than two:

``equal``        the Python component reproduces the authoritative fingerprint
``diverged``     Python produces it and it differs
``not_produced`` Python has no producer for it yet

The third state is the one that matters while this work is unfinished. A
component nobody has written must never score as agreement, and an audit that
reported only equal/diverged would let an absent producer read as a pass on an
entry where the authority also produced nothing.

The exit code reflects whether the audit ran, not whether the two sides agree;
``--require-equivalent`` requires all compared components to agree over the
entire source archive's MES/LIB corpus. That gate does not compare complete Python
handoff payloads or authorize an authority transfer. The report's
``corpus_handoff_sha256`` is the authoritative digest footer value, not a hash
computed from Python payloads.
``--require-components container typed_ir`` instead checks the named components
over every row of a valid digest, including a selected-entry export. Neither gate
accepts unmeasured digest rows, a failed export, or a mismatched source identity.

``--full-payload`` adds the v2 report's ``full_payload`` object while retaining
the v1 component fields and their meaning. Actual Python handoffs always name
``python_phase1_4``. Comparison uses the explicitly labelled
``producer_implementation_only/v1`` projection: validate the actual payload,
change only ``producer.implementation`` to the frozen GD value, and rehash.
Entry reports separate the authoritative, actual Python and projected Python
payload hashes. Corpus hashes use the same three-way distinction and digest row
order. ``measured_authoritative_corpus_sha256`` and both Python corpus hashes
cover only compared entries (``hash_scope``); ``scope=partial`` never certifies
the whole corpus. Python corpus hashes are null if any compared payload failed
validation, rather than silently hashing only successful entries.
``--require-full-equivalent`` implies full mode and requires every source entry,
no explicit limit, no producer/source errors, all component and projected entry
hashes equal, and the projected corpus hash equal to the authoritative footer.
The top-level ``equivalent`` remains the component gate; the complete-payload
gate is ``full_payload.equivalent``. Neither mode changes the frozen GD digest.

``--jobs N`` (TD-40) compares the entries on a pool of N worker processes. The
parent assembles every aggregate exactly as the serial run does - it hands each
worker one entry's bytes, digest row and source identity, collects the verdicts in
digest order and folds them unchanged - so the report, the printed lines and the
exit code are identical to ``--jobs 1`` (the default, which keeps the in-process
path); entries are only *started* largest first to balance the pool.

Usage:
    py tools/audit_mes_handoff_equivalence.py --digest <handoff.jsonl> \\
        --arc <mes.arc> [--json report.json] [--limit N] [--jobs N]

Produce the digest first with Godot:
    Godot_v4.7-stable_win64_console.exe --headless --path . \\
      --script res://tools/content_suite/cli/export_mes_handoff_digest.gd -- \\
      <mes.arc> <handoff.jsonl>
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from typing import Any, Iterable, Iterator

sys.path.insert(0, str(Path(__file__).resolve().parent))

from extract_kakyu_arc import read_entries
from export_mes_text_cache import sha256_file, write_json_atomic
from mes_analyzer_handoff import (
    BASELINE_PROJECTION_POLICY, COMPONENTS, PYTHON_PRODUCER, HandoffError,
    baseline_projection, build_components, build_handoff, fingerprint,
)


SCHEMA = "kakyu_mes_handoff_equivalence/v1"
FULL_PAYLOAD_SCHEMA = "kakyu_mes_handoff_equivalence/v2"
DIGEST_SCHEMA = "kakyu_mes_handoff_digest/v1"
HANDOFF_SCHEMA = "kakyu_mes_analyzer_handoff/v1"
REFERENCE_COMPONENTS = tuple(f"references.{name}" for name in ("messages", "code", "state", "resources"))
COMPARISON_COMPONENTS = (*COMPONENTS, *REFERENCE_COMPONENTS)


class HandoffAuditError(ValueError):
    pass


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise HandoffAuditError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _require_hash(value: Any, field: str) -> None:
    if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None:
        raise HandoffAuditError(f"invalid SHA-256 in {field}")


def _corpus_line(name: str, entry_sha256: str, payload_sha256: str) -> bytes:
    return f"{name}\t{entry_sha256}\t{payload_sha256}\n".encode("utf-8")


def read_digest(path: Path) -> tuple[dict[str, Any], dict[str, dict[str, Any]], dict[str, Any]]:
    header: dict[str, Any] | None = None
    footer: dict[str, Any] | None = None
    rows: dict[str, dict[str, Any]] = {}
    corpus_hash = hashlib.sha256()
    with path.open(encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            row = json.loads(line, object_pairs_hook=_unique_object)
            if not isinstance(row, dict):
                raise HandoffAuditError(f"digest line {line_number} is not an object")
            kind = row.get("kind")
            if footer is not None:
                raise HandoffAuditError("digest has data after its footer")
            if header is None and kind != "header":
                raise HandoffAuditError("digest must begin with its header")
            if kind == "header":
                if header is not None:
                    raise HandoffAuditError("digest has more than one header")
                if row.get("schema") != DIGEST_SCHEMA:
                    raise HandoffAuditError(f"unsupported digest schema: {row.get('schema')!r}")
                if row.get("handoff_schema") != HANDOFF_SCHEMA:
                    raise HandoffAuditError(f"unsupported handoff schema: {row.get('handoff_schema')!r}")
                declared = row.get("components")
                if (
                    not isinstance(declared, list)
                    or not all(isinstance(name, str) for name in declared)
                    or len(declared) != len(COMPONENTS)
                    or set(declared) != set(COMPONENTS)
                ):
                    raise HandoffAuditError("digest declares an incomplete or unsupported component set")
                _require_hash(row.get("archive_sha256"), "header.archive_sha256")
                header = row
            elif kind == "entry":
                name = row.get("entry")
                if (
                    not isinstance(name, str)
                    or re.fullmatch(r"[\x20-\x7e]+", name) is None
                    or any(character in name for character in "/\\:")
                    or Path(name).suffix.lower() not in (".mes", ".lib")
                ):
                    raise HandoffAuditError("digest entry has an invalid MES/LIB name")
                if name.upper() in rows:
                    raise HandoffAuditError(f"duplicate digest entry: {name}")
                if row.get("ok") is not True:
                    raise HandoffAuditError(f"authoritative handoff failed for {name}")
                components = row.get("components")
                if not isinstance(components, dict) or set(components) != set(COMPARISON_COMPONENTS):
                    raise HandoffAuditError(f"{name} has an incomplete or unsupported component fingerprint set")
                for component, value in components.items():
                    _require_hash(value, f"{name}.components.{component}")
                for field in ("entry_sha256", "payload_sha256"):
                    _require_hash(row.get(field), f"{name}.{field}")
                rows[name.upper()] = row
                corpus_hash.update(_corpus_line(name, row["entry_sha256"], row["payload_sha256"]))
            elif kind == "footer":
                if type(row.get("failed")) is not int or row["failed"] != 0:
                    raise HandoffAuditError("digest footer reports missing or failed handoffs")
                if type(row.get("entry_count")) is not int or row["entry_count"] != len(rows):
                    raise HandoffAuditError("digest footer entry count does not match its rows")
                _require_hash(row.get("corpus_handoff_sha256"), "footer.corpus_handoff_sha256")
                if row["corpus_handoff_sha256"] != corpus_hash.hexdigest():
                    raise HandoffAuditError("digest corpus fingerprint does not match its ordered rows")
                footer = row
            else:
                raise HandoffAuditError(f"unsupported digest row kind: {kind!r}")
    if header is None:
        raise HandoffAuditError("digest has no header line")
    if footer is None:
        raise HandoffAuditError("digest has no footer line")
    return header, rows, footer


def _compare_components(
    produced: dict[str, Any], digest_row: dict[str, Any], error: str | None,
) -> dict[str, Any]:
    authoritative: dict[str, Any] = digest_row.get("components", {})
    verdicts: dict[str, str] = {}
    # Expanding dotted aliases must not mutate a signed full handoff.
    produced = dict(produced)

    # A producer may publish the reference lists as the handoff's nested object
    # or independently while that component is being implemented.
    for name in REFERENCE_COMPONENTS:
        key = name.split(".", 1)[1]
        references = produced.get("references", {})
        if name not in produced and isinstance(references, dict) and key in references:
            produced[name] = references[key]
    for name in authoritative:
        if name not in produced:
            verdicts[name] = "not_produced"
            continue
        verdicts[name] = (
            "equal" if fingerprint(produced[name]) == authoritative[name] else "diverged"
        )
    return {
        "entry": digest_row["entry"],
        "verdicts": verdicts,
        "python_error": error,
        "entry_sha256_equal": (
            error is None
            and "container" in produced
            and produced["container"].get("entry_sha256") == digest_row.get("entry_sha256")
        ),
    }


def compare_entry(payload: bytes, digest_row: dict[str, Any]) -> dict[str, Any]:
    """One entry's per-component verdicts, retaining the v1 producer API."""
    try:
        produced = build_components(payload)
        error = None
    except HandoffError as failure:
        produced = {}
        error = str(failure)
    return _compare_components(produced, digest_row, error)


def compare_full_entry(
    payload: bytes, digest_row: dict[str, Any], source: dict[str, str],
) -> dict[str, Any]:
    """Decode once; compare components and a validated producer-only projection."""
    produced: dict[str, Any] = {}
    details: dict[str, Any] = {
        "authoritative_payload_sha256": digest_row["payload_sha256"],
        "actual_python_payload_sha256": None,
        "baseline_projected_python_payload_sha256": None,
        "actual_entry_sha256": hashlib.sha256(payload).hexdigest(),
        "archive_entry": source["entry"],
        "producer_implementation": None,
        "source_identity_equal": False,
        "payload_equal": False,
    }
    try:
        handoff = build_handoff(payload, source)
        if not isinstance(handoff, dict):
            raise HandoffError("Full-payload producer did not return a handoff dictionary.")
        producer = handoff.get("producer")
        details["producer_implementation"] = producer.get("implementation") if isinstance(producer, dict) else None
        if details["producer_implementation"] != PYTHON_PRODUCER:
            raise HandoffError("Full-payload audit requires an actual Python producer.")
        projected = baseline_projection(handoff)
        produced = {name: handoff[name] for name in COMPONENTS if name in handoff}
        # The projection validates the actual signature before either hash is
        # reported as a verified Python fingerprint.
        details["actual_python_payload_sha256"] = handoff["payload_sha256"]
        details["baseline_projected_python_payload_sha256"] = projected["payload_sha256"]
        details["source_identity_equal"] = (
            handoff.get("source_identity") == source
            and digest_row["entry"] == source["entry"]
        )
        if not details["source_identity_equal"]:
            raise HandoffError("Full-payload source identity does not match the exact archive entry.")
        details["payload_equal"] = projected["payload_sha256"] == digest_row["payload_sha256"]
        error = None
    except HandoffError as failure:
        error = str(failure)
    result = _compare_components(produced, digest_row, error)
    result["entry_sha256_equal"] = (
        result["entry_sha256_equal"]
        and details["actual_entry_sha256"] == digest_row["entry_sha256"]
    )
    result["full_payload"] = details
    return result


def _full_payload_summary(
    entries: list[dict[str, Any]], rows: dict[str, dict[str, Any]],
    footer: dict[str, Any], source_entry_count: int, limit: int | None,
    components_equal: bool,
) -> dict[str, Any]:
    compared = len(entries)
    complete_scope = limit is None and compared == len(rows) == source_entry_count and compared > 0
    hashes = {name: hashlib.sha256() for name in ("authoritative", "actual", "projected")}
    verified = 0
    for entry in entries:
        authoritative = rows[entry["entry"].upper()]
        full = entry["full_payload"]
        hashes["authoritative"].update(_corpus_line(
            authoritative["entry"], authoritative["entry_sha256"], authoritative["payload_sha256"],
        ))
        if (
            full["actual_python_payload_sha256"] is not None
            and full["baseline_projected_python_payload_sha256"] is not None
        ):
            verified += 1
            for name, field in (
                ("actual", "actual_python_payload_sha256"),
                ("projected", "baseline_projected_python_payload_sha256"),
            ):
                hashes[name].update(_corpus_line(
                    full["archive_entry"], full["actual_entry_sha256"], full[field],
                ))
    all_verified = compared > 0 and verified == compared
    actual_hash = hashes["actual"].hexdigest() if all_verified else None
    projected_hash = hashes["projected"].hexdigest() if all_verified else None
    payload_equal = sum(entry["full_payload"]["payload_equal"] for entry in entries)
    errors = sum(entry["python_error"] is not None for entry in entries)
    return {
        "policy": BASELINE_PROJECTION_POLICY,
        "scope": "complete_corpus" if complete_scope else "partial",
        "hash_scope": "compared_entries_in_digest_order",
        "source_entry_count": source_entry_count,
        "compared": compared,
        "verified_payloads": verified,
        "payload_equal": payload_equal,
        "python_errors": errors,
        "authoritative_corpus_sha256": footer["corpus_handoff_sha256"],
        "measured_authoritative_corpus_sha256": hashes["authoritative"].hexdigest() if entries else None,
        "actual_python_corpus_sha256": actual_hash,
        "baseline_projected_python_corpus_sha256": projected_hash,
        "equivalent": (
            components_equal and complete_scope and errors == 0 and all_verified
            and payload_equal == compared and projected_hash == footer["corpus_handoff_sha256"]
        ),
    }


ComparisonTask = tuple[bool, bytes, dict[str, Any], "dict[str, str] | None"]


def _compare_task(task: ComparisonTask) -> dict[str, Any]:
    """One entry's comparison from `(full_payload, payload, digest row, source)`.
    Module level so a process pool can pickle it; it touches no global state."""
    full_payload, payload, digest_row, source = task
    if full_payload:
        return compare_full_entry(payload, digest_row, source)
    return compare_entry(payload, digest_row)


def start_order(tasks: list[ComparisonTask]) -> list[int]:
    """The order a pool starts the tasks in: largest payload first (the biggest
    entries dominate the run), ties by digest position. A pure function of the
    tasks, so the schedule is reproducible; results are always collected by
    digest position, never by this order."""
    return sorted(range(len(tasks)), key=lambda index: (-len(tasks[index][1]), index))


def run_comparisons(tasks: Iterable[ComparisonTask], jobs: int) -> Iterator[dict[str, Any]]:
    """Every task's result in task order. `jobs` 1 compares lazily in this
    process; more compares on a process pool and still yields in task order, so
    the caller's ordered folds see the same sequence either way. A worker
    exception propagates (a dead pool is a `BrokenProcessPool`), after the
    unstarted tasks are dropped."""
    if jobs <= 1:
        yield from map(_compare_task, tasks)
        return
    task_list = list(tasks)
    if not task_list:
        return
    pool = ProcessPoolExecutor(max_workers=min(jobs, len(task_list)))
    try:
        futures = {index: pool.submit(_compare_task, task_list[index]) for index in start_order(task_list)}
        for index in range(len(task_list)):
            yield futures[index].result()
    finally:
        pool.shutdown(wait=True, cancel_futures=True)


def audit(
    digest_path: Path, arc_path: Path, limit: int | None = None, *, full_payload: bool = False,
    jobs: int = 1,
) -> dict[str, Any]:
    if limit is not None and (type(limit) is not int or limit <= 0):
        raise HandoffAuditError("--limit must be positive")
    if type(jobs) is not int or jobs <= 0:
        raise HandoffAuditError("--jobs must be positive")
    header, rows, footer = read_digest(digest_path)
    archive = arc_path.read_bytes()
    archive_sha256 = hashlib.sha256(archive).hexdigest()
    if archive_sha256 != header["archive_sha256"]:
        raise HandoffAuditError("source archive SHA-256 does not match the digest")
    try:
        archive_rows = read_entries(arc_path)
    except ValueError as failure:
        raise HandoffAuditError(f"invalid source archive: {failure}") from failure
    eligible_rows = [row for row in archive_rows if Path(row[0]).suffix.lower() in (".mes", ".lib")]
    archive_names = {row[0].upper() for row in eligible_rows}

    per_component: dict[str, Counter] = {}
    entries: list[dict[str, Any]] = []
    compared = 0
    missing_from_archive = sorted(set(rows) - archive_names)
    entry_sha_mismatches: list[str] = []

    # Full-payload corpus lines follow the authoritative digest's order, which
    # can differ from archive index order in selected or reordered exports.
    if full_payload:
        archive_by_name = {row[0].upper(): row for row in eligible_rows}
        selected_rows = [archive_by_name[key] for key in rows if key in archive_by_name]
    else:
        selected_rows = eligible_rows
    def comparison_tasks() -> Iterator[ComparisonTask]:
        # The entries to compare, `limit` applied here (before any dispatch), in
        # digest order for full payloads and archive order otherwise.
        nonlocal compared
        for name, offset, size in selected_rows:
            key = name.upper()
            if key not in rows:
                continue
            if limit is not None and compared >= limit:
                break
            compared += 1
            source = {
                "archive": arc_path.name, "entry": name, "archive_sha256": header["archive_sha256"],
            } if full_payload else None
            yield full_payload, archive[offset : offset + size], rows[key], source

    # The aggregates below are ordered folds over the results in task order, in
    # this process, whatever the number of workers.
    for result in run_comparisons(comparison_tasks(), jobs):
        for component, verdict in result["verdicts"].items():
            per_component.setdefault(component, Counter())[verdict] += 1
        if not result["entry_sha256_equal"]:
            entry_sha_mismatches.append(result["entry"])
        entries.append(result)

    if sha256_file(arc_path) != archive_sha256:
        raise HandoffAuditError("source archive changed during the audit")

    produced_components = sorted(
        name for name, counts in per_component.items() if counts["not_produced"] == 0
    )
    equivalent = (
        limit is None
        and bool(entries)
        and compared == len(rows) == len(eligible_rows)
        and not missing_from_archive
        and not entry_sha_mismatches
        and all(per_component.get(name, {}).get("equal", 0) == compared for name in COMPARISON_COMPONENTS)
    )
    report = {
        "schema": FULL_PAYLOAD_SCHEMA if full_payload else SCHEMA,
        "archive_sha256": header.get("archive_sha256", ""),
        "digest_entries": len(rows),
        "compared": compared,
        "missing_from_archive": missing_from_archive,
        "entry_sha256_mismatches": entry_sha_mismatches,
        "corpus_handoff_sha256": footer.get("corpus_handoff_sha256", ""),
        "components_declared": list(COMPONENTS),
        "components_produced": produced_components,
        "per_component": {
            name: dict(sorted(counts.items())) for name, counts in sorted(per_component.items())
        },
        "equivalent": equivalent,
        "entries": entries,
    }
    if full_payload:
        report["full_payload"] = _full_payload_summary(
            entries, rows, footer, len(eligible_rows), limit, equivalent,
        )
    return report


def required_components_equal(report: dict[str, Any], components: list[str]) -> bool:
    """A component gate covers every row in a source-bound, complete digest.

    A selected-entry export can satisfy this gate, but cannot make the report's
    whole-corpus ``equivalent`` true. A limit that leaves digest rows unmeasured
    cannot satisfy either gate.
    """
    compared = report["compared"]
    return (
        bool(components)
        and compared > 0
        and compared == report["digest_entries"]
        and not report["missing_from_archive"]
        and not report["entry_sha256_mismatches"]
        and all(report["per_component"].get(name, {}).get("equal", 0) == compared for name in components)
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--digest", type=Path, required=True, help="handoff digest JSONL")
    parser.add_argument("--arc", type=Path, required=True, help="the same MES archive")
    parser.add_argument("--json", type=Path, help="write the full report here")
    parser.add_argument("--limit", type=int, help="compare at most N entries")
    parser.add_argument(
        "--require-components",
        nargs="+",
        choices=COMPARISON_COMPONENTS,
        help="require these components to agree on every digest entry (selected-entry digests are allowed)",
    )
    parser.add_argument(
        "--require-equivalent",
        action="store_true",
        help="require all compared components over the whole corpus; does not verify complete handoff payloads",
    )
    parser.add_argument(
        "--full-payload", action="store_true",
        help="write a v2 report comparing verified full payloads under the labelled producer-only projection",
    )
    parser.add_argument(
        "--require-full-equivalent", action="store_true",
        help="imply --full-payload and require all source entries, no limit, and all projected payload/corpus hashes equal",
    )
    parser.add_argument(
        "--jobs", type=int, default=1,
        help="compare entries on this many worker processes (default 1, in-process); the report is identical",
    )
    arguments = parser.parse_args(argv)

    if arguments.limit is not None and arguments.limit <= 0:
        print("MES_HANDOFF_EQUIVALENCE_ERROR: --limit must be positive", file=sys.stderr)
        return 2
    if arguments.jobs <= 0:
        print("MES_HANDOFF_EQUIVALENCE_ERROR: --jobs must be positive", file=sys.stderr)
        return 2
    try:
        if arguments.json is not None:
            output = arguments.json.resolve()
            inputs = {arguments.digest.resolve(), arguments.arc.resolve()}
            if output in inputs or output.with_name(output.name + ".tmp").resolve() in inputs:
                raise HandoffAuditError("JSON report must not overwrite a source input")
        full_payload = arguments.full_payload or arguments.require_full_equivalent
        report = audit(
            arguments.digest, arguments.arc, arguments.limit, full_payload=full_payload, jobs=arguments.jobs,
        )
        if arguments.json is not None:
            write_json_atomic(arguments.json, report)
    except (HandoffAuditError, OSError, UnicodeError, json.JSONDecodeError) as failure:
        print(f"MES_HANDOFF_EQUIVALENCE_ERROR: {failure}", file=sys.stderr)
        return 2

    print(
        f"MES_HANDOFF_EQUIVALENCE schema={report['schema']}"
        f" archive_sha256={report['archive_sha256'][:16]}"
        f" compared={report['compared']}"
        f" produced={len(report['components_produced'])}/{len(report['per_component'])}"
        f" equivalent={str(report['equivalent']).lower()}"
        " scope=component_fingerprints"
        f" full_payload={'compared' if full_payload else 'not_compared'}"
    )
    if full_payload:
        full = report["full_payload"]
        print(
            f"MES_FULL_HANDOFF_EQUIVALENCE policy={full['policy']} scope={full['scope']}"
            f" equivalent={str(full['equivalent']).lower()}"
            f" verified={full['verified_payloads']}/{full['compared']}"
            f" payload_equal={full['payload_equal']} python_errors={full['python_errors']}"
        )
        for field in (
            "hash_scope", "authoritative_corpus_sha256", "measured_authoritative_corpus_sha256",
            "actual_python_corpus_sha256", "baseline_projected_python_corpus_sha256",
        ):
            print(f"  {field}={full[field]}")
    for name, counts in report["per_component"].items():
        summary = " ".join(f"{verdict}={count}" for verdict, count in counts.items())
        print(f"  {name:<24} {summary}")
    if report["entry_sha256_mismatches"]:
        print(f"  entry hash mismatches: {len(report['entry_sha256_mismatches'])}")
    if report["missing_from_archive"]:
        print(f"  digest entries absent from archive: {len(report['missing_from_archive'])}")
    if report["compared"] != report["digest_entries"]:
        print(f"  digest scope incomplete: compared={report['compared']} available={report['digest_entries']}")
    if arguments.json is not None:
        print(f"Report: {arguments.json.resolve()}")
    if arguments.require_equivalent and not report["equivalent"]:
        return 1
    if arguments.require_full_equivalent and not report["full_payload"]["equivalent"]:
        return 1
    if arguments.require_components:
        equal = required_components_equal(report, arguments.require_components)
        print(f"  required components: {','.join(arguments.require_components)} equal={str(equal).lower()}")
        if not equal:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
