"""Record a path-free manual result for the deferred original-engine batch.

This tool validates the prepared manifest and every candidate archive before it
records an operator's isolated observation. It does not launch the original
engine, infer a pass, or promote any candidate's compatibility classification.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Mapping


BATCH_SCHEMA = "kakyu_original_engine_verification_batch/v1"
RESULT_SCHEMA = "kakyu_original_engine_verification_result/v1"
ATTESTATION = "isolated_user_observation"
OBSERVATION_STATUSES = ("pass", "fail", "not_observed")
EXPECTED_CANDIDATES = {
    "mes_equal_length_cp932": "candidates/mes.arc",
    "dat_pal_marker": "candidates/data.arc",
    "ogg_no_reencode_swap": "candidates/voice.arc",
}
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
ENTRY_NAME_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+$")


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _is_below(candidate: Path, parent: Path) -> bool:
    try:
        candidate.relative_to(parent)
    except ValueError:
        return False
    return True


def _require_sha256(value: object, field: str) -> str:
    text = str(value)
    if SHA256_PATTERN.fullmatch(text) is None:
        raise ValueError(f"{field} must be a lowercase SHA-256 value")
    return text


def _candidate_path(batch_root: Path, relative_value: object) -> tuple[str, Path]:
    relative = str(relative_value)
    pure = PurePosixPath(relative)
    if (
        pure.is_absolute()
        or "\\" in relative
        or pure.parts[:1] != ("candidates",)
        or any(part in ("", ".", "..") for part in pure.parts)
    ):
        raise ValueError(f"unsafe candidate path in batch manifest: {relative}")
    resolved = batch_root.joinpath(*pure.parts).resolve()
    candidates_root = (batch_root / "candidates").resolve()
    if not _is_below(resolved, candidates_root):
        raise ValueError(f"candidate path escapes the batch: {relative}")
    return relative, resolved


def _load_batch(batch_root: Path) -> tuple[dict[str, object], str, list[dict[str, object]]]:
    manifest_path = batch_root / "manifest.json"
    if not manifest_path.is_file():
        raise ValueError("prepared batch manifest is missing")
    manifest_bytes = manifest_path.read_bytes()
    try:
        manifest = json.loads(manifest_bytes)
    except json.JSONDecodeError as error:
        raise ValueError(f"prepared batch manifest is invalid JSON: {error}") from error
    if not isinstance(manifest, dict):
        raise ValueError("prepared batch manifest must be a JSON object")
    if manifest.get("schema") != BATCH_SCHEMA:
        raise ValueError("prepared batch schema does not match")
    if (
        manifest.get("status") != "prepared_unverified"
        or manifest.get("launches_original_engine") is not False
        or manifest.get("source_unchanged") is not True
    ):
        raise ValueError("prepared batch safety contract does not match")
    launcher_sha256 = _require_sha256(manifest.get("launcher_sha256"), "launcher_sha256")
    raw_candidates = manifest.get("candidates")
    if not isinstance(raw_candidates, list) or len(raw_candidates) != len(EXPECTED_CANDIDATES):
        raise ValueError("prepared batch must contain exactly three candidates")

    checked: list[dict[str, object]] = []
    seen_kinds: set[str] = set()
    for raw in raw_candidates:
        if not isinstance(raw, dict):
            raise ValueError("candidate descriptor must be a JSON object")
        kind = str(raw.get("kind"))
        if kind not in EXPECTED_CANDIDATES or kind in seen_kinds:
            raise ValueError(f"unexpected or duplicate candidate kind: {kind}")
        seen_kinds.add(kind)
        relative, candidate_path = _candidate_path(batch_root, raw.get("path"))
        if relative != EXPECTED_CANDIDATES[kind]:
            raise ValueError(f"candidate path does not match kind {kind}")
        if not candidate_path.is_file():
            raise ValueError(f"candidate archive is missing: {relative}")
        expected_size = raw.get("bytes")
        if not isinstance(expected_size, int) or expected_size <= 0:
            raise ValueError(f"candidate byte size is invalid: {kind}")
        if candidate_path.stat().st_size != expected_size:
            raise ValueError(f"candidate byte size changed: {kind}")
        source_sha256 = _require_sha256(raw.get("source_sha256"), f"{kind}.source_sha256")
        candidate_sha256 = _require_sha256(
            raw.get("candidate_sha256"), f"{kind}.candidate_sha256"
        )
        if _sha256_file(candidate_path) != candidate_sha256:
            raise ValueError(f"candidate archive hash changed: {kind}")
        if raw.get("compatibility") != "original_engine_unverified":
            raise ValueError(f"candidate compatibility was already promoted: {kind}")
        target_entries = raw.get("target_entries")
        if (
            not isinstance(target_entries, list)
            or not target_entries
            or any(
                not isinstance(entry, str)
                or entry in (".", "..")
                or ENTRY_NAME_PATTERN.fullmatch(entry) is None
                for entry in target_entries
            )
        ):
            raise ValueError(f"candidate target entries are invalid: {kind}")
        checked.append(
            {
                "kind": kind,
                "source_sha256": source_sha256,
                "candidate_sha256": candidate_sha256,
                "bytes": expected_size,
                "target_entries": target_entries,
            }
        )
    if seen_kinds != set(EXPECTED_CANDIDATES):
        raise ValueError("prepared batch candidate set is incomplete")
    return manifest, hashlib.sha256(manifest_bytes).hexdigest(), checked


def record_verification(
    batch_root: Path,
    output_path: Path,
    observations: Mapping[str, str],
    responsive: str,
    *,
    attested: bool,
) -> dict[str, object]:
    if not attested:
        raise ValueError("isolated-run attestation is required")
    expected_keys = set(EXPECTED_CANDIDATES)
    if set(observations) != expected_keys:
        raise ValueError("one observation is required for each prepared candidate")
    for kind, status in observations.items():
        if status not in OBSERVATION_STATUSES:
            raise ValueError(f"invalid observation status for {kind}: {status}")
    if responsive not in OBSERVATION_STATUSES:
        raise ValueError(f"invalid responsiveness status: {responsive}")

    resolved_batch = batch_root.resolve()
    if not resolved_batch.is_dir():
        raise ValueError("prepared batch root does not exist")
    resolved_output = output_path.resolve()
    if resolved_output.suffix.lower() != ".json":
        raise ValueError("result output must use a .json extension")
    if not resolved_output.parent.is_dir():
        raise ValueError("result output parent does not exist")
    if _is_below(resolved_output, resolved_batch):
        raise ValueError("result output must be outside the prepared batch")
    if resolved_output.exists():
        raise ValueError("result output already exists")

    manifest, manifest_sha256, checked_candidates = _load_batch(resolved_batch)
    if responsive == "fail" or "fail" in observations.values():
        overall = "failed"
    elif responsive == "pass" and all(value == "pass" for value in observations.values()):
        overall = "all_observations_passed"
    else:
        overall = "incomplete"

    result_candidates = []
    for candidate in checked_candidates:
        item = dict(candidate)
        item["observation"] = observations[str(candidate["kind"])]
        result_candidates.append(item)
    result: dict[str, object] = {
        "schema": RESULT_SCHEMA,
        "status": overall,
        "recorded_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "evidence_type": ATTESTATION,
        "batch_schema": BATCH_SCHEMA,
        "batch_manifest_sha256": manifest_sha256,
        "launcher_sha256": manifest["launcher_sha256"],
        "responsiveness": responsive,
        "candidates": result_candidates,
        "compatibility_promotion": "not_performed",
        "evidence_boundary": "manual_observation_only",
        "contains_original_game_data": False,
        "contains_machine_paths": False,
    }
    encoded = (json.dumps(result, ensure_ascii=True, sort_keys=True, indent=2) + "\n").encode(
        "utf-8"
    )
    temporary = resolved_output.parent / f".{resolved_output.name}.tmp-{uuid.uuid4().hex}"
    try:
        with temporary.open("xb") as target:
            target.write(encoded)
            target.flush()
            os.fsync(target.fileno())
        os.link(temporary, resolved_output)
    except FileExistsError as error:
        raise ValueError("result output already exists") from error
    finally:
        temporary.unlink(missing_ok=True)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate a prepared batch and record isolated manual observations."
    )
    parser.add_argument("--batch-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--mes", required=True, choices=OBSERVATION_STATUSES)
    parser.add_argument("--dat-pal", required=True, choices=OBSERVATION_STATUSES)
    parser.add_argument("--ogg", required=True, choices=OBSERVATION_STATUSES)
    parser.add_argument("--responsive", required=True, choices=OBSERVATION_STATUSES)
    parser.add_argument(
        "--attest-isolated-run",
        required=True,
        action="store_true",
        help="Attest that these are direct observations from the isolated copied engine.",
    )
    args = parser.parse_args()
    result = record_verification(
        args.batch_root,
        args.output,
        {
            "mes_equal_length_cp932": args.mes,
            "dat_pal_marker": args.dat_pal,
            "ogg_no_reencode_swap": args.ogg,
        },
        args.responsive,
        attested=args.attest_isolated_run,
    )
    print(
        "ORIGINAL_ENGINE_VERIFICATION_RECORD_PASS "
        f"schema={result['schema']} status={result['status']} "
        "compatibility_promotion=not_performed"
    )


if __name__ == "__main__":
    main()
