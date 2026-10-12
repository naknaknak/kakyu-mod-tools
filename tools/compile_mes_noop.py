from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


NOOP_AUDIT_SCHEMA = "kakyu_mes_noop_compile_audit/v1"
AUDIT_TOP_LEVEL_KEYS = {
    "ok",
    "schema",
    "producer",
    "compatibility",
    "source_identity",
    "inputs",
    "source",
    "output",
    "operations",
    "coverage",
    "invariants",
    "payload_sha256",
}
AUDIT_INVARIANT_KEYS = {
    "output_reopened",
    "source_container_byte_identical",
    "source_bytecode_byte_identical",
    "preamble_byte_identical",
    "region_partition_preserved",
    "node_partition_preserved",
    "opaque_records_preserved",
}


class NoopCompileError(ValueError):
    pass


def compile_noop(document: dict[str, Any]) -> tuple[bytes, dict[str, Any]]:
    editable_ir.validate(document)
    source_ir = document["source_ir"]
    output = decompiler.reconstruct_container(source_ir)
    reopened = reopen_container(output)
    container = source_ir["container"]
    coverage = source_ir["coverage"]
    audit = {
        "ok": True,
        "schema": NOOP_AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_noop_compiler",
            "contract": NOOP_AUDIT_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_editable_ir_v1_no_operations",
            "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "unknown_audit_schema": "reject",
            "unknown_v1_field": "reject",
            "output_policy": "new_file_only",
        },
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
        },
        "source": {
            "entry_sha256": container["entry_sha256"],
            "bytecode_sha256": container["bytecode_sha256"],
            "preamble_sha256": container["preamble_sha256"],
        },
        "output": {
            "size": len(output),
            "entry_count": reopened["entry_count"],
            "entry_sha256": hashlib.sha256(output).hexdigest(),
            "code_offset": reopened["code_offset"],
            "code_size": reopened["code_size"],
            "bytecode_sha256": hashlib.sha256(
                output[reopened["code_offset"] :]
            ).hexdigest(),
            "preamble_sha256": hashlib.sha256(
                output[: reopened["code_offset"]]
            ).hexdigest(),
        },
        "operations": {"count": 0, "relocation_count": 0},
        "coverage": {
            "region_count": int(coverage["region_count"]),
            "node_count": int(coverage["node_count"]),
            "typed_node_count": int(coverage["typed_node_count"]),
            "opaque_node_count": int(coverage["opaque_node_count"]),
            "code_bytes": int(coverage["code_bytes"]),
        },
        "invariants": {
            "output_reopened": True,
            "source_container_byte_identical": output
            == decompiler.reconstruct_container(source_ir),
            "source_bytecode_byte_identical": True,
            "preamble_byte_identical": True,
            "region_partition_preserved": True,
            "node_partition_preserved": True,
            "opaque_records_preserved": True,
        },
    }
    audit["payload_sha256"] = fingerprint(audit)
    validate_audit(audit, document, output)
    return output, audit


def reopen_container(payload: bytes) -> dict[str, Any]:
    if len(payload) < 4:
        raise NoopCompileError("compiled MES is smaller than its entry count")
    entry_count = int.from_bytes(payload[:4], "little")
    code_offset = 4 + entry_count * 4
    if code_offset > len(payload):
        raise NoopCompileError("compiled MES address table exceeds its payload")
    code_size = len(payload) - code_offset
    offsets = [
        int.from_bytes(payload[4 + index * 4 : 8 + index * 4], "little")
        for index in range(entry_count)
    ]
    for index, offset in enumerate(offsets):
        if offset >= code_size:
            raise NoopCompileError("compiled MES address is outside its bytecode")
        if index > 0 and offset <= offsets[index - 1]:
            raise NoopCompileError("compiled MES addresses are not increasing")
    return {
        "entry_count": entry_count,
        "entry_offsets": offsets,
        "code_offset": code_offset,
        "code_size": code_size,
    }


def validate_audit(
    audit: dict[str, Any],
    document: dict[str, Any] | None = None,
    output: bytes | None = None,
) -> dict[str, Any]:
    if audit.get("schema") != NOOP_AUDIT_SCHEMA:
        raise NoopCompileError("unsupported MES no-op compile audit schema")
    if set(audit) != AUDIT_TOP_LEVEL_KEYS or audit.get("ok") is not True:
        raise NoopCompileError("MES no-op compile audit fields changed")
    producer = audit.get("producer")
    if producer != {
        "implementation": "python_phase6_noop_compiler",
        "contract": NOOP_AUDIT_SCHEMA,
    }:
        raise NoopCompileError("MES no-op compile audit producer changed")
    if audit.get("compatibility") != {
        "policy": "exact_editable_ir_v1_no_operations",
        "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
        "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
        "unknown_audit_schema": "reject",
        "unknown_v1_field": "reject",
        "output_policy": "new_file_only",
    }:
        raise NoopCompileError("MES no-op compile compatibility changed")
    retained = audit.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(audit) != retained
    ):
        raise NoopCompileError("MES no-op compile audit fingerprint changed")
    if audit.get("operations") != {"count": 0, "relocation_count": 0}:
        raise NoopCompileError("MES no-op compile audit operations changed")
    invariants = audit.get("invariants")
    if (
        not isinstance(invariants, dict)
        or set(invariants) != AUDIT_INVARIANT_KEYS
        or not all(value is True for value in invariants.values())
    ):
        raise NoopCompileError("MES no-op compile invariants are incomplete")
    inputs = audit.get("inputs")
    source_identity = audit.get("source_identity")
    if (
        not isinstance(source_identity, dict)
        or not isinstance(source_identity.get("entry"), str)
        or not source_identity["entry"]
        or not isinstance(inputs, dict)
        or set(inputs) != {"editable_ir_sha256", "decompiler_ir_sha256"}
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise NoopCompileError("MES no-op compile input hashes are incomplete")
    source_hashes = audit.get("source")
    output_row = audit.get("output")
    if (
        not isinstance(source_hashes, dict)
        or set(source_hashes)
        != {"entry_sha256", "bytecode_sha256", "preamble_sha256"}
        or not all(_is_sha256(value) for value in source_hashes.values())
        or not isinstance(output_row, dict)
        or set(output_row)
        != {
            "size",
            "entry_count",
            "entry_sha256",
            "code_offset",
            "code_size",
            "bytecode_sha256",
            "preamble_sha256",
        }
        or any(not _is_nonnegative_int(output_row[key]) for key in (
            "size", "entry_count", "code_offset", "code_size"
        ))
        or not all(
            _is_sha256(output_row[key])
            for key in ("entry_sha256", "bytecode_sha256", "preamble_sha256")
        )
    ):
        raise NoopCompileError("MES no-op compile source or output is incomplete")
    if int(output_row["size"]) != int(output_row["code_offset"]) + int(
        output_row["code_size"]
    ):
        raise NoopCompileError("MES no-op compile output size changed")
    coverage = audit.get("coverage")
    if (
        not isinstance(coverage, dict)
        or set(coverage)
        != {
            "region_count",
            "node_count",
            "typed_node_count",
            "opaque_node_count",
            "code_bytes",
        }
        or any(not _is_nonnegative_int(value) for value in coverage.values())
    ):
        raise NoopCompileError("MES no-op compile coverage changed")
    if int(coverage["code_bytes"]) != int(output_row["code_size"]):
        raise NoopCompileError("MES no-op compile byte coverage changed")
    if audit.get("source") != {
        "entry_sha256": audit.get("output", {}).get("entry_sha256"),
        "bytecode_sha256": audit.get("output", {}).get("bytecode_sha256"),
        "preamble_sha256": audit.get("output", {}).get("preamble_sha256"),
    }:
        raise NoopCompileError("MES no-op output differs from its source hashes")
    if document is not None:
        editable_ir.validate(document)
        source_ir = document["source_ir"]
        if source_identity != source_ir["source_identity"]:
            raise NoopCompileError("MES no-op compile source identity changed")
        if audit.get("inputs") != {
            "editable_ir_sha256": document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
        }:
            raise NoopCompileError("MES no-op compile input identity changed")
        source_container = source_ir["container"]
        if source_hashes != {
            "entry_sha256": source_container["entry_sha256"],
            "bytecode_sha256": source_container["bytecode_sha256"],
            "preamble_sha256": source_container["preamble_sha256"],
        }:
            raise NoopCompileError("MES no-op compile source identity changed")
        source_coverage = source_ir["coverage"]
        if coverage != {
            "region_count": int(source_coverage["region_count"]),
            "node_count": int(source_coverage["node_count"]),
            "typed_node_count": int(source_coverage["typed_node_count"]),
            "opaque_node_count": int(source_coverage["opaque_node_count"]),
            "code_bytes": int(source_coverage["code_bytes"]),
        }:
            raise NoopCompileError("MES no-op compile source coverage changed")
        if output is None:
            raise NoopCompileError("MES no-op compile output bytes are missing")
        source = decompiler.reconstruct_container(source_ir)
        if output != source:
            raise NoopCompileError("MES no-op output is not byte identical")
        reopened = reopen_container(output)
        if audit.get("output") != {
            "size": len(output),
            "entry_count": reopened["entry_count"],
            "entry_sha256": hashlib.sha256(output).hexdigest(),
            "code_offset": reopened["code_offset"],
            "code_size": reopened["code_size"],
            "bytecode_sha256": hashlib.sha256(
                output[reopened["code_offset"] :]
            ).hexdigest(),
            "preamble_sha256": hashlib.sha256(
                output[: reopened["code_offset"]]
            ).hexdigest(),
        }:
            raise NoopCompileError("MES no-op compile output audit changed")
    return {
        "ok": True,
        "schema": NOOP_AUDIT_SCHEMA,
        "payload_sha256": retained,
    }


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compile a Phase 6 MES editable IR with zero operations and emit "
            "a byte-identical MES plus compact audit JSON."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("output_mes", type=Path)
    parser.add_argument("audit_output", type=Path)
    args = parser.parse_args()
    resolved = {
        args.editable_ir.resolve(),
        args.output_mes.resolve(),
        args.audit_output.resolve(),
    }
    if len(resolved) != 3:
        raise NoopCompileError("MES no-op input and outputs must be distinct")
    if args.output_mes.exists() or args.audit_output.exists():
        raise NoopCompileError("MES no-op output already exists")
    try:
        document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise NoopCompileError("MES editable IR could not be read") from error
    if not isinstance(document, dict):
        raise NoopCompileError("MES editable IR is not an object")
    output, audit = compile_noop(document)
    audit_bytes = editable_ir.canonical_json_bytes(audit) + b"\n"
    published_mes = False
    published_audit = False
    try:
        editable_ir.publish_new(args.output_mes, output)
        published_mes = True
        if args.output_mes.read_bytes() != output:
            raise NoopCompileError("published MES no-op output changed")
        editable_ir.publish_new(args.audit_output, audit_bytes)
        published_audit = True
        reopened_audit = json.loads(args.audit_output.read_text(encoding="utf-8"))
        validate_audit(reopened_audit, document, args.output_mes.read_bytes())
    except BaseException:
        if published_audit and args.audit_output.is_file():
            args.audit_output.unlink()
        if published_mes and args.output_mes.is_file():
            args.output_mes.unlink()
        raise
    print(
        "MES_NOOP_COMPILE_PASS "
        f"schema={audit['schema']} "
        f"entry={audit['source_identity'].get('entry', '')} "
        f"bytes={audit['output']['size']} "
        f"payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
