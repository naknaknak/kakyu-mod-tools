"""Chain proof over an MW-11 operation sequence: ordered same-size steps then
at most one trailing message relocation, each step's own already-validated
semantic proof (v2 byte-patch or v4 message relocation) combined into one
chain proof whose same-size-step coordinates are already original
coordinates (every step before a relocation preserves every byte offset)."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
import diff_mes_byte_patch_semantics as byte_patch_diff
import diff_mes_message_relocation_semantics as relocation_diff
import prepare_mes_editable_ir as editable_ir
import validate_mes_analyzer_handoff as handoff_validator
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256

DIFF_SCHEMA = "kakyu_mes_semantic_diff_chain/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity",
    "source_binding", "output_binding", "steps", "composition",
    "invariants", "payload_sha256",
}
COMPATIBILITY = {
    "policy": "ordered_same_size_steps_then_at_most_one_relocation",
    "step_proof_schemas": [byte_patch_diff.DIFF_SCHEMA, relocation_diff.DIFF_SCHEMA],
    "unknown_diff_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "steps_chained": True,
    "relocation_last_or_absent": True,
    "every_step_proof_validated": True,
    "every_step_audit_validated": True,
}
STEP_KEYS = {
    "index", "kind", "family", "proof_schema", "proof_sha256",
    "audit_schema", "audit_sha256", "source_entry_sha256",
    "output_entry_sha256", "byte_delta",
}
PATCH_KEYS = {
    "step", "family", "source_start", "source_end", "output_start",
    "output_end", "source_raw_sha256", "output_raw_sha256",
}
STEP_PROOF_MODULES = {byte_patch_diff.DIFF_SCHEMA: byte_patch_diff, relocation_diff.DIFF_SCHEMA: relocation_diff}


class MesSequenceSemanticDiffError(ValueError):
    pass


def build(source_files: dict[str, bytes], steps: list[dict[str, bytes]]) -> dict[str, Any]:
    result = _build(source_files, steps)
    result["payload_sha256"] = fingerprint(result)
    validate(result, source_files, steps)
    return result


def validate(
    document: dict[str, Any], source_files: dict[str, bytes] | None = None,
    steps: list[dict[str, bytes]] | None = None,
) -> dict[str, Any]:
    if document.get("ok") is not True or document.get("schema") != DIFF_SCHEMA or set(document) != TOP_LEVEL_KEYS:
        raise MesSequenceSemanticDiffError("MES sequence semantic diff schema or fields changed")
    if document.get("producer") != {
        "implementation": "python_phase6_sequence_semantic_diff", "contract": DIFF_SCHEMA,
    }:
        raise MesSequenceSemanticDiffError("MES sequence semantic diff producer changed")
    if document.get("compatibility") != COMPATIBILITY:
        raise MesSequenceSemanticDiffError("MES sequence semantic diff compatibility changed")
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise MesSequenceSemanticDiffError("MES sequence semantic diff fingerprint changed")
    _validate_shape(document)
    inputs = (source_files, steps)
    if any(value is not None for value in inputs):
        if any(value is None for value in inputs):
            raise MesSequenceSemanticDiffError("MES sequence semantic diff validation inputs are incomplete")
        expected = _build(source_files, steps)  # type: ignore[arg-type]
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise MesSequenceSemanticDiffError("MES sequence semantic diff differs from its inputs")
    return {"ok": True, "schema": DIFF_SCHEMA, "payload_sha256": retained}


def _build(source_files: dict[str, bytes], steps: list[dict[str, bytes]]) -> dict[str, Any]:
    if not isinstance(steps, list) or len(steps) < 2:
        raise MesSequenceSemanticDiffError("MES sequence semantic diff needs at least two chained steps")
    source_handoff = json.loads(source_files["handoff.json"])
    handoff_validator.validate(source_handoff)
    source_editable = json.loads(source_files["editable.json"])
    editable_ir.validate(source_editable)
    if source_editable["source_ir"]["source_identity"] != source_handoff["source_identity"]:
        raise MesSequenceSemanticDiffError("MES sequence source identity changed")
    source_container = decompiler.reconstruct_container(source_editable["source_ir"])
    source_entry_sha256 = hashlib.sha256(source_container).hexdigest()

    step_rows: list[dict[str, Any]] = []
    patches: list[dict[str, Any]] = []
    same_size_count = 0
    relocation_index = -1
    previous_output_handoff = source_handoff
    previous_output_entry_sha256 = source_entry_sha256
    final_output_handoff = source_handoff

    for index, step in enumerate(steps, start=1):
        step_handoff = json.loads(step["handoff.json"])
        step_editable = json.loads(step["editable.json"])
        audit = json.loads(step["compile.audit.json"])
        proof = json.loads(step["semantic.diff.json"])
        output_handoff = json.loads(step["output.handoff.json"])
        if step_handoff != previous_output_handoff:
            raise MesSequenceSemanticDiffError(f"MES sequence step {index} source handoff is not the previous step's output")
        if step_editable != editable_ir.prepare(decompiler.lift(step_handoff)):
            raise MesSequenceSemanticDiffError(f"MES sequence step {index} source editable model differs from its handoff")
        schema = proof.get("schema")
        module = STEP_PROOF_MODULES.get(schema)
        if module is None:
            raise MesSequenceSemanticDiffError(f"MES sequence step {index} proof schema is unsupported")
        module.validate(proof, step_editable, audit, output_handoff)
        is_relocation = schema == relocation_diff.DIFF_SCHEMA
        if is_relocation:
            if index != len(steps):
                raise MesSequenceSemanticDiffError("A message relocation must be the last operation of a sequence")
            relocation_index = index
        else:
            same_size_count += 1
            patch = proof["semantic_changes"]["patch"]
            patches.append({
                "step": index, "family": str(proof["operation"]["family"]),
                "source_start": int(patch["source_start"]), "source_end": int(patch["source_end"]),
                "output_start": int(patch["output_start"]), "output_end": int(patch["output_end"]),
                "source_raw_sha256": str(patch["source_raw_sha256"]), "output_raw_sha256": str(patch["output_raw_sha256"]),
            })
        step_source_entry_sha256 = str(audit["source"]["entry_sha256"])
        step_output_entry_sha256 = str(audit["output"]["entry_sha256"])
        if step_source_entry_sha256 != previous_output_entry_sha256:
            raise MesSequenceSemanticDiffError(f"MES sequence step {index} is not chained to the previous step's output")
        step_rows.append({
            "index": index, "kind": str(proof["operation"]["kind"]), "family": str(proof["operation"]["family"]),
            "proof_schema": schema, "proof_sha256": str(proof["payload_sha256"]),
            "audit_schema": str(audit["schema"]), "audit_sha256": str(audit["payload_sha256"]),
            "source_entry_sha256": step_source_entry_sha256, "output_entry_sha256": step_output_entry_sha256,
            "byte_delta": int(proof["container_diff"]["byte_delta"]),
        })
        previous_output_handoff = output_handoff
        previous_output_entry_sha256 = step_output_entry_sha256
        final_output_handoff = output_handoff

    final_proof = json.loads(steps[-1]["semantic.diff.json"])
    return {
        "ok": True, "schema": DIFF_SCHEMA,
        "producer": {"implementation": "python_phase6_sequence_semantic_diff", "contract": DIFF_SCHEMA},
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_handoff["source_identity"]),
        "source_binding": {
            "entry_sha256": source_entry_sha256,
            "analyzer_handoff_sha256": str(source_handoff["payload_sha256"]),
        },
        "output_binding": {
            "entry_sha256": str(final_proof["output_binding"]["entry_sha256"]),
            "analyzer_handoff_sha256": str(final_output_handoff["payload_sha256"]),
            "bytecode_sha256": str(final_proof["output_binding"]["bytecode_sha256"]),
        },
        "steps": step_rows,
        "composition": {
            "step_count": len(steps), "same_size_step_count": same_size_count,
            "relocation_step_index": relocation_index, "original_coordinate_patches": patches,
        },
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _validate_shape(document: dict[str, Any]) -> None:
    source_identity = document.get("source_identity")
    if not isinstance(source_identity, dict) or not source_identity.get("entry"):
        raise MesSequenceSemanticDiffError("MES sequence semantic diff source identity changed")
    for name, keys in (
        ("source_binding", {"entry_sha256", "analyzer_handoff_sha256"}),
        ("output_binding", {"entry_sha256", "analyzer_handoff_sha256", "bytecode_sha256"}),
        ("composition", {"step_count", "same_size_step_count", "relocation_step_index", "original_coordinate_patches"}),
    ):
        if not isinstance(document.get(name), dict) or set(document[name]) != keys:
            raise MesSequenceSemanticDiffError(f"MES sequence semantic diff {name} fields changed")
    if not all(_is_sha256(document["source_binding"][key]) for key in ("entry_sha256", "analyzer_handoff_sha256")):
        raise MesSequenceSemanticDiffError("MES sequence semantic diff source binding hash changed")
    if not all(_is_sha256(document["output_binding"][key]) for key in ("entry_sha256", "analyzer_handoff_sha256", "bytecode_sha256")):
        raise MesSequenceSemanticDiffError("MES sequence semantic diff output binding hash changed")
    if document.get("invariants") != INVARIANTS:
        raise MesSequenceSemanticDiffError("MES sequence semantic diff invariants changed")
    composition = document["composition"]
    steps = document.get("steps")
    step_count = composition["step_count"]
    if (
        not isinstance(steps, list) or len(steps) != step_count or step_count < 2
        or not isinstance(composition["same_size_step_count"], int) or isinstance(composition["same_size_step_count"], bool)
        or not isinstance(composition["relocation_step_index"], int) or isinstance(composition["relocation_step_index"], bool)
        or composition["relocation_step_index"] not in (-1, step_count)
        or not isinstance(composition["original_coordinate_patches"], list)
    ):
        raise MesSequenceSemanticDiffError("MES sequence semantic diff composition accounting changed")
    relocation_index = composition["relocation_step_index"]
    same_size_expected = step_count - (1 if relocation_index != -1 else 0)
    if composition["same_size_step_count"] != same_size_expected or len(composition["original_coordinate_patches"]) != same_size_expected:
        raise MesSequenceSemanticDiffError("MES sequence semantic diff composition accounting changed")
    previous_output = document["source_binding"]["entry_sha256"]
    for position, row in enumerate(steps, start=1):
        if not isinstance(row, dict) or set(row) != STEP_KEYS:
            raise MesSequenceSemanticDiffError("MES sequence semantic diff step fields changed")
        if (
            row["index"] != position or row["proof_schema"] not in COMPATIBILITY["step_proof_schemas"]
            or not row["kind"] or not row["family"]
            or not all(_is_sha256(row[key]) for key in ("proof_sha256", "audit_sha256", "source_entry_sha256", "output_entry_sha256"))
            or not isinstance(row["byte_delta"], int) or isinstance(row["byte_delta"], bool)
            or row["source_entry_sha256"] != previous_output
        ):
            raise MesSequenceSemanticDiffError("MES sequence semantic diff step accounting changed")
        is_relocation = position == relocation_index
        if is_relocation != (row["proof_schema"] == relocation_diff.DIFF_SCHEMA):
            raise MesSequenceSemanticDiffError("MES sequence semantic diff relocation placement changed")
        if is_relocation != (row["byte_delta"] != 0):
            raise MesSequenceSemanticDiffError("MES sequence semantic diff byte delta accounting changed")
        previous_output = row["output_entry_sha256"]
    if previous_output != document["output_binding"]["entry_sha256"]:
        raise MesSequenceSemanticDiffError("MES sequence semantic diff output binding does not match the last step")
    same_size_positions = [row["index"] for row in steps if row["proof_schema"] == byte_patch_diff.DIFF_SCHEMA]
    for patch in composition["original_coordinate_patches"]:
        if (
            not isinstance(patch, dict) or set(patch) != PATCH_KEYS
            or patch["step"] not in same_size_positions
            or not isinstance(patch["source_start"], int) or isinstance(patch["source_start"], bool)
            or not isinstance(patch["source_end"], int) or isinstance(patch["source_end"], bool)
            or not isinstance(patch["output_start"], int) or isinstance(patch["output_start"], bool)
            or not isinstance(patch["output_end"], int) or isinstance(patch["output_end"], bool)
            or patch["source_end"] <= patch["source_start"] or patch["output_end"] <= patch["output_start"]
            or not _is_sha256(patch["source_raw_sha256"]) or not _is_sha256(patch["output_raw_sha256"])
        ):
            raise MesSequenceSemanticDiffError("MES sequence semantic diff original-coordinate patch changed")
    if [patch["step"] for patch in composition["original_coordinate_patches"]] != same_size_positions:
        raise MesSequenceSemanticDiffError("MES sequence semantic diff original-coordinate patch order changed")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build a chain proof over an MW-11 operation sequence's per-step proofs.")
    parser.add_argument("source_dir", type=Path, help="Directory holding the sequence source's handoff.json/editable.json")
    parser.add_argument("step_dir", type=Path, nargs="+", help="One directory per step holding that step's compile_edit files")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    source_files = {"handoff.json": (args.source_dir / "handoff.json").read_bytes(),
                     "editable.json": (args.source_dir / "editable.json").read_bytes()}
    steps = []
    names = ("handoff.json", "editable.json", "compile.audit.json", "semantic.diff.json", "output.handoff.json", "output.mes")
    for directory in args.step_dir:
        steps.append({name: (directory / name).read_bytes() for name in names})
    result = build(source_files, steps)
    editable_ir.publish_new(args.output, editable_ir.canonical_json_bytes(result) + b"\n")
    print(
        "MES_SEQUENCE_SEMANTIC_DIFF_PASS "
        f"schema={DIFF_SCHEMA} steps={result['composition']['step_count']} "
        f"relocation_step_index={result['composition']['relocation_step_index']} "
        f"payload_sha256={result['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
