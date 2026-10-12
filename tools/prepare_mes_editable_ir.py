from __future__ import annotations

import argparse
import copy
import json
import os
import uuid
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
from payload_values import canonical_payload_bytes, fingerprint, publish_new_document


EDITABLE_IR_SCHEMA = "kakyu_mes_editable_ir/v1"
TOP_LEVEL_KEYS = {
    "ok",
    "schema",
    "producer",
    "compatibility",
    "source_ir",
    "operations",
    "capability_report",
    "payload_sha256",
}


class EditableIrError(ValueError):
    pass


def prepare(linear_ir: dict[str, Any]) -> dict[str, Any]:
    decompiler.validate(linear_ir)
    coverage = linear_ir["coverage"]
    document = {
        "ok": True,
        "schema": EDITABLE_IR_SCHEMA,
        "producer": {
            "implementation": "python_phase6_editable_ir",
            "contract": EDITABLE_IR_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_embedded_decompiler_source_and_ordered_operations",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "unknown_editable_schema": "reject",
            "unknown_v1_field": "reject",
            "unknown_operation": "reject",
            "supported_operations": [],
            "source_document_policy": "embedded_immutable_fingerprinted",
            "opaque_record_policy": "preserve_source_bytes",
        },
        "source_ir": copy.deepcopy(linear_ir),
        "operations": [],
        "capability_report": {
            "phase": 6,
            "scope": "byte_identical_no_op_compiler_baseline",
            "operation_count": 0,
            "relocation": "not_performed",
            "region_count": int(coverage["region_count"]),
            "node_count": int(coverage["node_count"]),
            "opaque_node_count": int(coverage["opaque_node_count"]),
            "code_bytes": int(coverage["code_bytes"]),
        },
    }
    document["payload_sha256"] = fingerprint(document)
    validate(document)
    return document


def validate(document: dict[str, Any]) -> dict[str, Any]:
    if document.get("schema") != EDITABLE_IR_SCHEMA:
        raise EditableIrError("unsupported MES editable IR schema")
    if set(document) != TOP_LEVEL_KEYS:
        raise EditableIrError("MES editable IR top-level fields changed")
    if document.get("ok") is not True:
        raise EditableIrError("MES editable IR is not complete")
    producer = document.get("producer")
    if producer != {
        "implementation": "python_phase6_editable_ir",
        "contract": EDITABLE_IR_SCHEMA,
    }:
        raise EditableIrError("MES editable IR producer contract changed")
    compatibility = document.get("compatibility")
    if not isinstance(compatibility, dict) or compatibility != {
        "policy": "exact_embedded_decompiler_source_and_ordered_operations",
        "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
        "unknown_editable_schema": "reject",
        "unknown_v1_field": "reject",
        "unknown_operation": "reject",
        "supported_operations": [],
        "source_document_policy": "embedded_immutable_fingerprinted",
        "opaque_record_policy": "preserve_source_bytes",
    }:
        raise EditableIrError("MES editable IR compatibility contract changed")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise EditableIrError("MES editable IR fingerprint changed")
    source_ir = document.get("source_ir")
    if not isinstance(source_ir, dict):
        raise EditableIrError("MES editable IR source document is missing")
    decompiler.validate(source_ir)
    operations = document.get("operations")
    if not isinstance(operations, list):
        raise EditableIrError("MES editable IR operations are not an array")
    if operations:
        raise EditableIrError("MES editable IR operation is not supported yet")
    coverage = source_ir["coverage"]
    if document.get("capability_report") != {
        "phase": 6,
        "scope": "byte_identical_no_op_compiler_baseline",
        "operation_count": 0,
        "relocation": "not_performed",
        "region_count": int(coverage["region_count"]),
        "node_count": int(coverage["node_count"]),
        "opaque_node_count": int(coverage["opaque_node_count"]),
        "code_bytes": int(coverage["code_bytes"]),
    }:
        raise EditableIrError("MES editable IR capability report changed")
    return {
        "ok": True,
        "schema": EDITABLE_IR_SCHEMA,
        "payload_sha256": retained,
    }


def publish_new(path: Path, payload: bytes) -> None:
    destination = path.resolve()
    parent = destination.parent
    if not parent.is_dir():
        raise EditableIrError("MES editable IR output directory does not exist")
    if destination.exists():
        raise EditableIrError("MES editable IR output already exists")
    temporary = parent / (
        f".{destination.name}.tmp-{os.getpid()}-{uuid.uuid4().hex}"
    )

    def verify(staged: Path) -> None:
        if staged.read_bytes() != payload:
            raise EditableIrError("MES editable IR temporary verification failed")

    try:
        publish_new_document(destination, payload, temporary, verify)
    except FileExistsError as error:
        raise EditableIrError("MES editable IR output already exists") from error
    except OSError as error:
        raise EditableIrError("MES editable IR output could not be published") from error


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Wrap a validated lossless MES decompiler JSON document in the "
            "Phase 6 editable-IR contract."
        )
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.linear_ir.resolve() == args.output.resolve():
        raise EditableIrError("MES editable IR output must not replace its input")
    try:
        linear_ir = json.loads(args.linear_ir.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise EditableIrError("MES decompiler IR could not be read") from error
    if not isinstance(linear_ir, dict):
        raise EditableIrError("MES decompiler IR is not an object")
    document = prepare(linear_ir)
    encoded = canonical_json_bytes(document) + b"\n"
    publish_new(args.output, encoded)
    print(
        "MES_EDITABLE_IR_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_ir']['source_identity'].get('entry', '')} "
        f"nodes={document['capability_report']['node_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


def canonical_json_bytes(document: dict[str, Any]) -> bytes:
    return json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


if __name__ == "__main__":
    main()
