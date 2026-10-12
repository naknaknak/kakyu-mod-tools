from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import plan_mes_shared_routine_call_edit as call_planner
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


AUDIT_SCHEMA = "kakyu_mes_shared_routine_call_compile_audit/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity",
    "library_identity", "inputs", "source", "output", "operation", "target",
    "coverage", "invariants", "payload_sha256",
}
SUMMARY_KEYS = {
    "size", "entry_count", "code_offset", "code_size", "entry_sha256",
    "bytecode_sha256", "preamble_sha256", "address_table_sha256",
}
OPERATION_KEYS = {
    "kind", "source_offset", "source_routine_id", "replacement_routine_id",
    "width", "physical_resume_offset",
}
TARGET_KEYS = {
    "node_id", "region_id", "instruction_start", "instruction_end",
    "literal_start", "literal_end", "resume_node_id", "resume_region_id",
    "resume_start", "resume_end", "resume_raw_sha256",
    "source_instruction_sha256", "replacement_instruction_sha256",
    "source_expression_sha256", "replacement_expression_sha256",
    "source_literal_sha256", "replacement_literal_sha256", "source_callee",
    "replacement_callee",
}
COVERAGE_KEYS = {
    "region_count", "node_count", "typed_node_count", "opaque_node_count",
    "code_bytes",
}
INVARIANT_KEYS = {
    "plan_ready", "output_reopened", "container_size_preserved",
    "entry_count_preserved", "code_offset_preserved", "code_size_preserved",
    "address_table_preserved", "preamble_preserved", "code_prefix_preserved",
    "replacement_instruction_exact", "code_suffix_preserved",
    "only_literal_range_changed", "physical_resume_bytes_preserved",
    "source_callee_certificate_retained",
    "replacement_callee_certificate_retained", "source_container_not_modified",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}
COMPATIBILITY = {
    "policy": "exact_same_width_literal_shared_routine_call_plan_only",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_plan_schema": call_planner.PLAN_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "input_shared_call_proof_schema": "kakyu_mes_shared_call_return_proof/v2",
    "input_library_audit_schema": "kakyu_mes_library_audit/v17",
    "unknown_audit_schema": "reject",
    "unknown_v1_field": "reject",
    "output_policy": "new_file_only",
    "relocation": "forbidden",
    "tool_execution": "not_performed",
    "native_engine_compatibility": "unverified",
}


class SharedRoutineCallCompileError(ValueError):
    pass


def compile_shared_routine_call(
    editable_document: dict[str, Any],
    shared_call_proof: dict[str, Any],
    library_audit: dict[str, Any],
    plan_document: dict[str, Any],
) -> tuple[bytes, dict[str, Any]]:
    editable_ir.validate(editable_document)
    call_planner.validate(
        plan_document, editable_document, shared_call_proof, library_audit
    )
    if plan_document.get("assembly_ready") is not True:
        raise SharedRoutineCallCompileError(
            "MES shared-routine call edit plan is not assembly ready"
        )
    source_ir = editable_document["source_ir"]
    source = decompiler.reconstruct_container(source_ir)
    source_before = bytes(source)
    source_header = noop_compiler.reopen_container(source)
    code_offset = int(source_header["code_offset"])
    source_code = source[code_offset:]
    target = plan_document["target"]
    replacement = plan_document["replacement"]
    instruction_start = int(target["instruction_start"])
    instruction_end = int(target["instruction_end"])
    literal_start = int(target["literal_start"])
    literal_end = int(target["literal_end"])
    source_instruction = _hex_bytes(target["instruction_raw_hex"], "source instruction")
    replacement_instruction = _hex_bytes(
        replacement["instruction_raw_hex"], "replacement instruction"
    )
    if (
        instruction_start < 0
        or instruction_end <= instruction_start
        or instruction_end > len(source_code)
        or len(source_instruction) != instruction_end - instruction_start
        or len(replacement_instruction) != len(source_instruction)
        or source_code[instruction_start:instruction_end] != source_instruction
        or not instruction_start <= literal_start < literal_end <= instruction_end
        or literal_end - literal_start != 1
    ):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile target boundary changed"
        )
    output_code = (
        source_code[:instruction_start]
        + replacement_instruction
        + source_code[instruction_end:]
    )
    output = source[:code_offset] + output_code
    reopened = noop_compiler.reopen_container(output)
    if (
        reopened["entry_count"] != source_header["entry_count"]
        or reopened["entry_offsets"] != source_header["entry_offsets"]
        or reopened["code_offset"] != source_header["code_offset"]
        or reopened["code_size"] != source_header["code_size"]
    ):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile changed container layout"
        )
    changed = [
        index for index, (before, after) in enumerate(zip(source_code, output_code))
        if before != after
    ]
    if changed != list(range(literal_start, literal_end)):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile changed bytes outside the literal"
        )
    call_proof = target["call_proof"]
    resume_node = _resume_node(source_ir, call_proof)
    resume_start = int(resume_node["source"]["start"])
    resume_end = int(resume_node["source"]["end"])
    resume_raw = _hex_bytes(resume_node["source"]["raw_hex"], "physical resume")
    if (
        resume_start != int(call_proof["physical_resume_offset"])
        or source_code[resume_start:resume_end] != resume_raw
        or output_code[resume_start:resume_end] != resume_raw
    ):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call physical resume bytes changed"
        )
    if source != source_before:
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile changed its source buffer"
        )
    coverage = source_ir["coverage"]
    operation = plan_document["operation"]
    audit = {
        "ok": True,
        "schema": AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_shared_routine_call_compiler",
            "contract": AUDIT_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "library_identity": copy.deepcopy(plan_document["library_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "shared_call_return_proof_sha256": shared_call_proof["payload_sha256"],
            "library_audit_sha256": plan_document["inputs"]["library_audit_sha256"],
            "shared_routine_call_plan_sha256": plan_document["payload_sha256"],
        },
        "source": _container_summary(source, source_header),
        "output": _container_summary(output, reopened),
        "operation": {
            "kind": "replace_shared_routine_literal",
            "source_offset": int(operation["source_offset"]),
            "source_routine_id": int(target["routine_id"]),
            "replacement_routine_id": int(replacement["routine_id"]),
            "width": int(target["width"]),
            "physical_resume_offset": int(call_proof["physical_resume_offset"]),
        },
        "target": {
            "node_id": str(target["node_id"]),
            "region_id": str(target["region_id"]),
            "instruction_start": instruction_start,
            "instruction_end": instruction_end,
            "literal_start": literal_start,
            "literal_end": literal_end,
            "resume_node_id": str(resume_node["id"]),
            "resume_region_id": str(resume_node["source"]["region"]),
            "resume_start": resume_start,
            "resume_end": resume_end,
            "resume_raw_sha256": hashlib.sha256(resume_raw).hexdigest(),
            "source_instruction_sha256": str(target["instruction_raw_sha256"]),
            "replacement_instruction_sha256": str(
                replacement["instruction_raw_sha256"]
            ),
            "source_expression_sha256": str(target["expression_raw_sha256"]),
            "replacement_expression_sha256": str(
                replacement["expression_raw_sha256"]
            ),
            "source_literal_sha256": str(target["literal_raw_sha256"]),
            "replacement_literal_sha256": str(replacement["literal_raw_sha256"]),
            "source_callee": copy.deepcopy(call_proof),
            "replacement_callee": copy.deepcopy(replacement["callee_proof"]),
        },
        "coverage": {
            "region_count": int(coverage["region_count"]),
            "node_count": int(coverage["node_count"]),
            "typed_node_count": int(coverage["typed_node_count"]),
            "opaque_node_count": int(coverage["opaque_node_count"]),
            "code_bytes": int(coverage["code_bytes"]),
        },
        "invariants": {
            "plan_ready": True,
            "output_reopened": True,
            "container_size_preserved": len(output) == len(source),
            "entry_count_preserved": reopened["entry_count"] == source_header["entry_count"],
            "code_offset_preserved": reopened["code_offset"] == source_header["code_offset"],
            "code_size_preserved": reopened["code_size"] == source_header["code_size"],
            "address_table_preserved": reopened["entry_offsets"] == source_header["entry_offsets"],
            "preamble_preserved": output[:code_offset] == source[:code_offset],
            "code_prefix_preserved": output_code[:instruction_start] == source_code[:instruction_start],
            "replacement_instruction_exact": output_code[instruction_start:instruction_end] == replacement_instruction,
            "code_suffix_preserved": output_code[instruction_end:] == source_code[instruction_end:],
            "only_literal_range_changed": changed == list(range(literal_start, literal_end)),
            "physical_resume_bytes_preserved": output_code[resume_start:resume_end] == resume_raw,
            "source_callee_certificate_retained": call_proof == target["call_proof"],
            "replacement_callee_certificate_retained": replacement["callee_proof"] == plan_document["replacement"]["callee_proof"],
            "source_container_not_modified": source == source_before,
        },
    }
    if not all(audit["invariants"].values()):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile invariant failed"
        )
    audit["payload_sha256"] = fingerprint(audit)
    validate_audit(audit)
    return output, audit


def validate_audit(
    audit: dict[str, Any],
    editable_document: dict[str, Any] | None = None,
    shared_call_proof: dict[str, Any] | None = None,
    library_audit: dict[str, Any] | None = None,
    plan_document: dict[str, Any] | None = None,
    output: bytes | None = None,
) -> dict[str, Any]:
    if (
        audit.get("ok") is not True
        or audit.get("schema") != AUDIT_SCHEMA
        or set(audit) != TOP_LEVEL_KEYS
    ):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile audit schema or fields changed"
        )
    if audit.get("producer") != {
        "implementation": "python_phase6_shared_routine_call_compiler",
        "contract": AUDIT_SCHEMA,
    }:
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile audit producer changed"
        )
    if audit.get("compatibility") != COMPATIBILITY:
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile compatibility changed"
        )
    retained = audit.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(audit) != retained:
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile audit fingerprint changed"
        )
    source_identity = audit.get("source_identity")
    library_identity = audit.get("library_identity")
    inputs = audit.get("inputs")
    if (
        not isinstance(source_identity, dict)
        or not set(source_identity).issubset(SOURCE_IDENTITY_KEYS)
        or not isinstance(source_identity.get("entry"), str)
        or not source_identity["entry"]
        or not isinstance(library_identity, dict)
        or set(library_identity) != call_planner.LIBRARY_IDENTITY_KEYS
        or library_identity.get("entry") != "LIBLARY.LIB"
        or not isinstance(inputs, dict)
        or set(inputs) != {
            "editable_ir_sha256", "decompiler_ir_sha256",
            "shared_call_return_proof_sha256", "library_audit_sha256",
            "shared_routine_call_plan_sha256",
        }
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile input identity changed"
        )
    for key in ("source", "output"):
        row = audit.get(key)
        if not _valid_summary(row):
            raise SharedRoutineCallCompileError(
                "MES shared-routine call compile container summary changed"
            )
    operation = audit.get("operation")
    if (
        not isinstance(operation, dict)
        or set(operation) != OPERATION_KEYS
        or operation.get("kind") != "replace_shared_routine_literal"
        or any(not _is_nonnegative_int(operation.get(key)) for key in OPERATION_KEYS - {"kind"})
        or operation.get("width") != 8
        or operation.get("source_routine_id") == operation.get("replacement_routine_id")
    ):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile operation changed"
        )
    target = audit.get("target")
    if (
        not isinstance(target, dict)
        or set(target) != TARGET_KEYS
        or not isinstance(target.get("node_id"), str)
        or not target["node_id"]
        or not isinstance(target.get("region_id"), str)
        or not target["region_id"]
        or not isinstance(target.get("resume_node_id"), str)
        or not target["resume_node_id"]
        or not isinstance(target.get("resume_region_id"), str)
        or not target["resume_region_id"]
        or any(not _is_nonnegative_int(target.get(key)) for key in (
            "instruction_start", "instruction_end", "literal_start", "literal_end",
            "resume_start", "resume_end",
        ))
        or any(not _is_sha256(target.get(key)) for key in (
            "resume_raw_sha256", "source_instruction_sha256",
            "replacement_instruction_sha256", "source_expression_sha256",
            "replacement_expression_sha256", "source_literal_sha256",
            "replacement_literal_sha256",
        ))
        or not isinstance(target.get("source_callee"), dict)
        or set(target["source_callee"]) != call_planner.CALL_PROOF_KEYS
        or not isinstance(target.get("replacement_callee"), dict)
        or set(target["replacement_callee"]) != call_planner.CALLEE_PROOF_KEYS
        or target["instruction_start"] != operation["source_offset"]
        or target["instruction_end"] != operation["physical_resume_offset"]
        or target["resume_start"] != operation["physical_resume_offset"]
        or target["literal_end"] != target["literal_start"] + 1
        or target["resume_end"] <= target["resume_start"]
        or target["source_callee"].get("routine_id") != operation["source_routine_id"]
        or target["replacement_callee"].get("routine_id") != operation["replacement_routine_id"]
    ):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile target changed"
        )
    coverage = audit.get("coverage")
    if (
        not isinstance(coverage, dict)
        or set(coverage) != COVERAGE_KEYS
        or any(not _is_nonnegative_int(value) for value in coverage.values())
        or coverage["node_count"] != coverage["typed_node_count"] + coverage["opaque_node_count"]
        or coverage["code_bytes"] != audit["source"]["code_size"]
    ):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile coverage changed"
        )
    invariants = audit.get("invariants")
    if (
        not isinstance(invariants, dict)
        or set(invariants) != INVARIANT_KEYS
        or not all(value is True for value in invariants.values())
    ):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile invariants changed"
        )
    source = audit["source"]
    output_row = audit["output"]
    if (
        output_row["size"] != source["size"]
        or output_row["entry_count"] != source["entry_count"]
        or output_row["code_offset"] != source["code_offset"]
        or output_row["code_size"] != source["code_size"]
        or output_row["preamble_sha256"] != source["preamble_sha256"]
        or output_row["address_table_sha256"] != source["address_table_sha256"]
    ):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile layout identity changed"
        )
    supplied = (
        editable_document, shared_call_proof, library_audit, plan_document, output
    )
    if any(value is not None for value in supplied):
        if any(value is None for value in supplied):
            raise SharedRoutineCallCompileError(
                "MES shared-routine call compile validation inputs are incomplete"
            )
        expected_output, expected_audit = compile_shared_routine_call(
            editable_document, shared_call_proof, library_audit, plan_document
        )
        if expected_output != output or expected_audit != audit:
            raise SharedRoutineCallCompileError(
                "MES shared-routine call compile audit differs from its source"
            )
    return {"ok": True, "schema": AUDIT_SCHEMA, "payload_sha256": retained}


def _resume_node(source_ir: dict[str, Any], call_proof: dict[str, Any]) -> dict[str, Any]:
    matches = [
        node for node in source_ir["nodes"]
        if node.get("id") == call_proof.get("physical_resume_node_id")
        and node.get("source", {}).get("start") == call_proof.get("physical_resume_offset")
        and node.get("source", {}).get("raw_sha256") == call_proof.get("physical_resume_raw_sha256")
    ]
    if len(matches) != 1:
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile physical resume node changed"
        )
    return matches[0]


def _container_summary(raw: bytes, header: dict[str, Any]) -> dict[str, Any]:
    code_offset = int(header["code_offset"])
    code = raw[code_offset:]
    return {
        "size": len(raw),
        "entry_count": int(header["entry_count"]),
        "code_offset": code_offset,
        "code_size": len(code),
        "entry_sha256": hashlib.sha256(raw).hexdigest(),
        "bytecode_sha256": hashlib.sha256(code).hexdigest(),
        "preamble_sha256": hashlib.sha256(raw[:code_offset]).hexdigest(),
        "address_table_sha256": hashlib.sha256(raw[4:code_offset]).hexdigest(),
    }


def _valid_summary(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == SUMMARY_KEYS
        and all(_is_nonnegative_int(value.get(key)) for key in (
            "size", "entry_count", "code_offset", "code_size",
        ))
        and all(_is_sha256(value.get(key)) for key in (
            "entry_sha256", "bytecode_sha256", "preamble_sha256",
            "address_table_sha256",
        ))
        and value["size"] == value["code_offset"] + value["code_size"]
    )


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str) or not value or len(value) % 2 != 0:
        raise SharedRoutineCallCompileError(
            f"MES shared-routine call compile {label} is invalid"
        )
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise SharedRoutineCallCompileError(
            f"MES shared-routine call compile {label} is invalid"
        ) from error


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compile one validated same-width command-0x1D shared-routine "
            "literal edit into a new MES container and compact audit."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("shared_call_proof", type=Path)
    parser.add_argument("library_audit", type=Path)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output_mes", type=Path)
    parser.add_argument("audit_output", type=Path)
    args = parser.parse_args()
    paths = [
        args.editable_ir.resolve(), args.shared_call_proof.resolve(),
        args.library_audit.resolve(), args.plan.resolve(),
        args.output_mes.resolve(), args.audit_output.resolve(),
    ]
    if len(set(paths)) != len(paths):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile paths must differ"
        )
    if args.output_mes.exists() or args.audit_output.exists():
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile output already exists"
        )
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        shared_call_proof = json.loads(args.shared_call_proof.read_text(encoding="utf-8"))
        library_audit = json.loads(args.library_audit.read_text(encoding="utf-8"))
        plan_document = json.loads(args.plan.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile input JSON could not be read"
        ) from error
    if not all(isinstance(value, dict) for value in (
        editable_document, shared_call_proof, library_audit, plan_document,
    )):
        raise SharedRoutineCallCompileError(
            "MES shared-routine call compile inputs must be JSON objects"
        )
    output, audit = compile_shared_routine_call(
        editable_document, shared_call_proof, library_audit, plan_document
    )
    audit_bytes = editable_ir.canonical_json_bytes(audit) + b"\n"
    published_mes = False
    published_audit = False
    try:
        editable_ir.publish_new(args.output_mes, output)
        published_mes = True
        editable_ir.publish_new(args.audit_output, audit_bytes)
        published_audit = True
        reopened_audit = json.loads(args.audit_output.read_text(encoding="utf-8"))
        validate_audit(
            reopened_audit, editable_document, shared_call_proof,
            library_audit, plan_document, args.output_mes.read_bytes(),
        )
    except BaseException:
        if published_audit and args.audit_output.is_file():
            args.audit_output.unlink()
        if published_mes and args.output_mes.is_file():
            args.output_mes.unlink()
        raise
    print(
        "MES_SHARED_ROUTINE_CALL_COMPILE_PASS "
        f"schema={audit['schema']} "
        f"entry={audit['source_identity'].get('entry', '')} "
        f"offset={audit['target']['instruction_start']} "
        f"source_routine={audit['operation']['source_routine_id']} "
        f"replacement_routine={audit['operation']['replacement_routine_id']} "
        f"resume={audit['operation']['physical_resume_offset']} "
        f"bytes={audit['output']['size']} "
        f"payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
