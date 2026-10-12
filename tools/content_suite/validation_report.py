"""Build and atomically write the versioned repository-validation report."""

from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import tempfile
from typing import Any
import uuid


SCHEMA = "kakyu_content_tools_validation/v6"
SCHEMA_V5 = "kakyu_content_tools_validation/v5"
SCHEMA_V4 = "kakyu_content_tools_validation/v4"
SCHEMA_V3 = "kakyu_content_tools_validation/v3"
ACCEPTED_SCHEMAS = (SCHEMA, SCHEMA_V5, SCHEMA_V4, SCHEMA_V3)
TIERS = ("local", "archive_quick", "full")
CACHE_STATES = ("consulted", "not_consulted")
OUTPUT_TAIL_LIMIT = 4096
COVERAGE_TITLES = {
    "synthetic": "Local synthetic checks",
    "original_corpus": "Original archive checks",
    "event_corpus": "Exhaustive MES entry audit",
    "native_executable": "Native executable checks",
    "native_corpus": "Native checks with archives",
    "voice_payload": "Native voice payload check",
}
# TD-32 part 3b: `v5` adds the top-level `cached` count; `v4`/`v3` keep their
# own shorter set (read, never written, by `normalize_report()`). TD-33: `v6`
# keeps the same top-level shape as `v5` - it only adds `context.jobs`, so
# `PAYLOAD_KEYS` (the top-level field set) is unchanged between the two.
PAYLOAD_KEYS_V4 = {
    "schema", "status", "check_count", "passed", "failed", "duration_seconds",
    "original_corpus", "native_executable_audit", "checks", "run_id", "coverage",
    "context", "configuration_error",
}
PAYLOAD_KEYS = PAYLOAD_KEYS_V4 | {"cached"}


def make_report(
    checks: list[dict[str, object]], *, duration_seconds: float, run_id: str,
    coverage: list[dict[str, object]], context: dict[str, str],
    original_corpus: bool, native_executable_audit: bool, configuration_error: str = "",
) -> dict[str, object]:
    failed = sum(check["status"] != "passed" for check in checks)
    cached = sum(bool(check.get("cached")) for check in checks)
    report: dict[str, object] = {
        "schema": SCHEMA,
        "status": "configuration_error" if configuration_error else "failed" if failed else "passed",
        "check_count": len(checks),
        "passed": len(checks) - failed,
        "failed": failed,
        "duration_seconds": duration_seconds,
        "original_corpus": original_corpus,
        "native_executable_audit": native_executable_audit,
        "checks": checks,
        "run_id": run_id,
        "coverage": coverage,
        "context": context,
        "configuration_error": configuration_error,
        "cached": cached,
    }
    validate_payload(report)
    return report


def _count(value: Any) -> bool:
    return type(value) is int and value >= 0


def _duration(value: Any) -> bool:
    return type(value) in (int, float) and math.isfinite(value) and value >= 0


def validate_payload(report: dict[str, Any]) -> None:
    """Reject foreign schemas and inconsistent results before writing a file.

    Accepts the current `v6` schema (adds `context.jobs`), and reads the
    earlier `v5` (adds the cache), `v4` (tiered, no cache) and `v3` (always
    `tier: full`, no `context.tier` key) schemas as complete prior forms; a
    `v5`/`v4`/`v3` document validated here still needs `normalize_report()`
    before a consumer that expects `context.tier`/`cached`/`context.cache`/
    `context.cache_dir`/`context.jobs` to be present reads it.
    """
    schema = report.get("schema") if isinstance(report, dict) else None
    if schema in (SCHEMA, SCHEMA_V5):
        expected_keys = PAYLOAD_KEYS
    elif schema in (SCHEMA_V4, SCHEMA_V3):
        expected_keys = PAYLOAD_KEYS_V4
    else:
        expected_keys = None
    if not isinstance(report, dict) or expected_keys is None or set(report) != expected_keys:
        raise ValueError("Unsupported validation report schema or fields.")
    try:
        if str(uuid.UUID(report["run_id"])) != report["run_id"]:
            raise ValueError
    except (ValueError, TypeError, AttributeError) as error:
        raise ValueError("Validation report run_id must be a canonical UUID.") from error
    if not _duration(report["duration_seconds"]) or not isinstance(report["configuration_error"], str):
        raise ValueError("Validation report duration or configuration error is invalid.")
    if type(report["original_corpus"]) is not bool or type(report["native_executable_audit"]) is not bool:
        raise ValueError("Validation report source flags must be booleans.")
    context = report["context"]
    if schema in (SCHEMA, SCHEMA_V5, SCHEMA_V4):
        context_fields = {"kind", "elfimage", "executable", "workspace_validation", "tier"}
        if schema in (SCHEMA, SCHEMA_V5):
            context_fields = context_fields | {"cache", "cache_dir"}
        if schema == SCHEMA:
            context_fields = context_fields | {"jobs"}
        if (
            not isinstance(context, dict)
            or set(context) != context_fields
            or context.get("kind") != "repository_suite"
            or context.get("workspace_validation") != "not_performed"
            or not isinstance(context.get("elfimage"), str)
            or not isinstance(context.get("executable"), str)
            or context.get("tier") not in TIERS
            or (schema in (SCHEMA, SCHEMA_V5) and (
                context.get("cache") not in CACHE_STATES or not isinstance(context.get("cache_dir"), str)
            ))
            or (schema == SCHEMA and (
                type(context.get("jobs")) is not int or context.get("jobs") <= 0
            ))
        ):
            raise ValueError("Validation report context is invalid.")
        tier_is_local = context["tier"] == "local"
        if (
            report["original_corpus"] != (bool(context["elfimage"]) and not tier_is_local)
            or report["native_executable_audit"] != (bool(context["executable"]) and not tier_is_local)
        ):
            raise ValueError("Validation report source flags do not match its context.")
    else:
        if (
            not isinstance(context, dict)
            or set(context) != {"kind", "elfimage", "executable", "workspace_validation"}
            or context.get("kind") != "repository_suite"
            or context.get("workspace_validation") != "not_performed"
            or not isinstance(context.get("elfimage"), str)
            or not isinstance(context.get("executable"), str)
        ):
            raise ValueError("Validation report context is invalid.")
        if (
            report["original_corpus"] != bool(context["elfimage"])
            or report["native_executable_audit"] != bool(context["executable"])
        ):
            raise ValueError("Validation report source flags do not match its context.")
    checks = report["checks"]
    if not isinstance(checks, list):
        raise ValueError("Validation report checks must be an array.")
    names = set()
    cached_rows = 0
    cache_fields = {"cached", "cached_at", "cached_run_id"}
    for check in checks:
        required = {"name", "status", "return_code", "duration_seconds"}
        optional = {"output_tail"} | (cache_fields if schema in (SCHEMA, SCHEMA_V5) else set())
        if (
            not isinstance(check, dict) or not required <= set(check)
            or set(check) - required - optional
            or not isinstance(check["name"], str) or not check["name"] or check["name"] in names
            or check["status"] not in ("passed", "failed", "timeout", "error")
            or not _duration(check["duration_seconds"])
            or (check["return_code"] is not None and type(check["return_code"]) is not int)
            or (check["status"] == "passed" and check["return_code"] != 0)
            or (check["status"] == "failed" and check["return_code"] in (None, 0))
            or (check["status"] in ("timeout", "error") and check["return_code"] is not None)
            or ("output_tail" in check and (
                not isinstance(check["output_tail"], str) or len(check["output_tail"]) > OUTPUT_TAIL_LIMIT
            ))
        ):
            raise ValueError("Validation report contains an invalid check result.")
        present_cache_fields = cache_fields & set(check)
        if present_cache_fields and present_cache_fields != cache_fields:
            raise ValueError("A cached check result must carry cached, cached_at and cached_run_id together.")
        if "cached" in check:
            if (
                check["cached"] is not True
                or check["status"] != "passed" or check["return_code"] != 0 or check["duration_seconds"] != 0
                or not isinstance(check["cached_at"], str) or not check["cached_at"]
                or not isinstance(check["cached_run_id"], str) or not check["cached_run_id"]
            ):
                raise ValueError("Validation report contains an invalid cached check result.")
            cached_rows += 1
        names.add(check["name"])
    passed = sum(check["status"] == "passed" for check in checks)
    if (
        not all(_count(report[key]) for key in ("check_count", "passed", "failed"))
        or report["check_count"] != len(checks) or report["passed"] != passed
        or report["failed"] != len(checks) - passed
    ):
        raise ValueError("Validation report counts do not match its check results.")
    if schema in (SCHEMA, SCHEMA_V5):
        if not _count(report.get("cached")) or report["cached"] != cached_rows:
            raise ValueError("Validation report cached count disagrees with its checks.")
        if context.get("cache") == "not_consulted" and report["cached"] != 0:
            raise ValueError("Validation report with cache not_consulted cannot report cached checks.")
    expected_status = (
        "configuration_error" if report["configuration_error"]
        else "failed" if report["failed"] else "passed"
    )
    if (
        report["status"] != expected_status or (report["configuration_error"] and checks)
        or (report["status"] == "passed" and not checks)
    ):
        raise ValueError("Validation report status does not match its results.")
    coverage = report["coverage"]
    if not isinstance(coverage, list) or len(coverage) != len(COVERAGE_TITLES):
        raise ValueError("Validation report must describe every coverage group.")
    seen = set()
    for group in coverage:
        if (
            not isinstance(group, dict) or set(group) != {"id", "title", "status", "reason", "check_count"}
            or not isinstance(group.get("id"), str) or group["id"] not in COVERAGE_TITLES or group["id"] in seen
            or not isinstance(group["title"], str) or not group["title"]
            or not isinstance(group["reason"], str) or not group["reason"]
            or not _count(group["check_count"]) or group["check_count"] > len(checks)
            or group["status"] != ("included" if group["check_count"] else "not_run")
        ):
            raise ValueError("Validation report coverage does not match its check results.")
        seen.add(group["id"])


def normalize_report(report: dict[str, Any]) -> dict[str, Any]:
    """A validated payload with `context.tier`, `cached`, `context.cache`,
    `context.cache_dir` and `context.jobs` present for every accepted schema
    (TD-32 part 3b; TD-33 adds `jobs`).

    A `v6` payload already carries all five. A `v5` payload already carries
    the cache but predates `--jobs`, so it reports `context.jobs: 1` here (it
    ran the same single-worker way `--jobs 1` runs today). A `v4` payload
    already carries its own tier but predates the cache, so it additionally
    reports `cached: 0`, `context.cache: "not_consulted"`,
    `context.cache_dir: ""`. A `v3` payload predates the tier, the cache and
    `--jobs` and ran the (then-only) full batch, so it additionally reports
    `tier: "full"`. `report["schema"]` is left as recorded; only the
    synthesized fields are added.
    """
    validate_payload(report)
    if report["schema"] == SCHEMA:
        return report
    normalized = dict(report)
    context = dict(report["context"])
    if report["schema"] == SCHEMA_V3:
        context["tier"] = "full"
    if report["schema"] in (SCHEMA_V3, SCHEMA_V4):
        context["cache"] = "not_consulted"
        context["cache_dir"] = ""
        normalized["cached"] = 0
    context["jobs"] = 1
    normalized["context"] = context
    return normalized


def report_envelope(report: dict[str, Any]) -> dict[str, str]:
    validate_payload(report)
    payload_json = json.dumps(report, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return {
        "schema": report["schema"],
        "payload_json": payload_json,
        "payload_sha256": hashlib.sha256(payload_json.encode("utf-8")).hexdigest(),
    }


def write_report(path: Path, report: dict[str, Any]) -> None:
    """Replace a report only after validating and serializing its versioned envelope."""
    encoded = json.dumps(report_envelope(report), ensure_ascii=False, indent=2) + "\n"
    target = path.expanduser().resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", newline="\n", prefix=target.name + ".tmp-",
            dir=target.parent, delete=False,
        ) as handle:
            temporary = Path(handle.name)
            handle.write(encoded)
        os.replace(temporary, target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
