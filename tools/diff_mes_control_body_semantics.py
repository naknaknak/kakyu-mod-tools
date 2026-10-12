from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_control_body_edit as body_compiler
import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import prepare_mes_editable_ir as editable_ir
import validate_mes_analyzer_handoff as handoff_validator
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


DIFF_SCHEMA = "kakyu_mes_semantic_diff/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "operation", "container_diff", "semantic_changes", "node_diff", "preservation",
    "output_binding", "invariants", "payload_sha256",
}
OPERATION_KEYS = {"family", "kind"}
INPUT_KEYS = {
    "editable_ir_sha256", "source_decompiler_ir_sha256", "compile_audit_sha256",
    "output_analyzer_handoff_sha256",
}
CONTAINER_DIFF_KEYS = {
    "source_size", "output_size", "byte_delta", "source_code_size",
    "output_code_size", "code_delta", "entry_count", "code_offset",
}
SEMANTIC_CHANGES_KEYS = {"body", "address_changes", "target_changes"}
BODY_KEYS = {
    "kind", "source_start", "source_end", "output_start", "output_end",
    "byte_length", "raw_sha256", "source_node_count",
}
ADDRESS_KEYS = {"index", "source_offset", "output_offset"}
TARGET_KEYS = {
    "reference_id", "reference_kind", "source_owner_offset", "output_owner_offset",
    "source_target_offset", "output_target_offset", "source_operand_sha256",
    "output_operand_sha256", "output_reference_verified",
}
NODE_DIFF_KEYS = {
    "source_node_count", "output_node_count", "retained_node_count",
    "inserted_node_count", "removed_node_count", "patched_node_count",
    "mapping_sha256", "inserted_nodes", "removed_nodes", "patched_nodes",
}
NODE_CHANGE_KEYS = {
    "source_node_id", "source_start", "source_end", "output_node_id",
    "output_start", "output_end", "source_raw_sha256", "output_raw_sha256",
}
PRESERVATION_KEYS = {
    "source_opaque_node_count", "output_opaque_node_count",
    "exact_opaque_node_count", "retained_raw_exact_node_count",
    "patched_retained_node_count", "unrelated_typed_exact_node_count",
}
OUTPUT_BINDING_KEYS = {
    "analyzer_handoff_sha256", "decompiler_ir_sha256", "entry_sha256",
    "bytecode_sha256",
}
COMPATIBILITY = {
    "policy": "source_output_semantic_diff_with_exact_node_mapping",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_compile_audit_schemas": [body_compiler.AUDIT_SCHEMA],
    "input_handoff_schema": handoff_validator.HANDOFF_SCHEMA,
    "output_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "supported_families": ["control_body_edit"],
    "opaque_policy": "every_source_opaque_node_maps_once_with_identical_raw_bytes",
    "unrelated_node_policy": "every_retained_unpatched_node_maps_once_with_identical_raw_bytes",
    "unknown_diff_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "compile_audit_validated": True,
    "output_handoff_validated": True,
    "output_decompiler_ir_validated": True,
    "expected_output_bytes_exact": True,
    "address_changes_exact": True,
    "all_source_nodes_accounted_once": True,
    "all_output_nodes_accounted_once": True,
    "intended_body_change_exact": True,
    "intended_target_changes_exact": True,
    "unrelated_typed_nodes_preserved": True,
    "opaque_nodes_preserved_exactly": True,
}


class MesSemanticDiffError(ValueError):
    pass


def build(
    editable_document: dict[str, Any], compile_audit: dict[str, Any],
    output_handoff: dict[str, Any],
) -> dict[str, Any]:
    result = _build(editable_document, compile_audit, output_handoff)
    result["payload_sha256"] = fingerprint(result)
    validate(result, editable_document, compile_audit, output_handoff)
    return result


def validate(
    document: dict[str, Any], editable_document: dict[str, Any] | None = None,
    compile_audit: dict[str, Any] | None = None,
    output_handoff: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if (
        document.get("ok") is not True
        or document.get("schema") != DIFF_SCHEMA
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise MesSemanticDiffError("MES semantic diff schema or fields changed")
    if document.get("producer") != {
        "implementation": "python_phase6_mes_semantic_diff",
        "contract": DIFF_SCHEMA,
    } or document.get("compatibility") != COMPATIBILITY:
        raise MesSemanticDiffError("MES semantic diff producer or compatibility changed")
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise MesSemanticDiffError("MES semantic diff fingerprint changed")
    _require_dict_keys(document, "operation", OPERATION_KEYS)
    _require_dict_keys(document, "inputs", INPUT_KEYS)
    _require_dict_keys(document, "container_diff", CONTAINER_DIFF_KEYS)
    _require_dict_keys(document, "semantic_changes", SEMANTIC_CHANGES_KEYS)
    _require_dict_keys(document["semantic_changes"], "body", BODY_KEYS)
    _require_rows(document["semantic_changes"], "address_changes", ADDRESS_KEYS)
    _require_rows(document["semantic_changes"], "target_changes", TARGET_KEYS)
    _require_dict_keys(document, "node_diff", NODE_DIFF_KEYS)
    for key in ("inserted_nodes", "removed_nodes", "patched_nodes"):
        _require_rows(document["node_diff"], key, NODE_CHANGE_KEYS)
    _require_dict_keys(document, "preservation", PRESERVATION_KEYS)
    _require_dict_keys(document, "output_binding", OUTPUT_BINDING_KEYS)
    if document.get("invariants") != INVARIANTS:
        raise MesSemanticDiffError("MES semantic diff invariants changed")
    _validate_shape_semantics(document)
    if any(value is None for value in (editable_document, compile_audit, output_handoff)):
        if any(value is not None for value in (editable_document, compile_audit, output_handoff)):
            raise MesSemanticDiffError("MES semantic diff validation inputs are incomplete")
    else:
        expected = _build(editable_document, compile_audit, output_handoff)  # type: ignore[arg-type]
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise MesSemanticDiffError("MES semantic diff differs from its source and output")
    return {"ok": True, "schema": DIFF_SCHEMA, "payload_sha256": retained}


def _build(
    editable_document: dict[str, Any], compile_audit: dict[str, Any],
    output_handoff: dict[str, Any],
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    body_compiler.validate_audit(compile_audit)
    handoff_validator.validate(output_handoff)
    source_ir = editable_document["source_ir"]
    output_ir = decompiler.lift(output_handoff)
    if source_ir["source_identity"] != output_ir["source_identity"] or source_ir["source_identity"] != compile_audit["source_identity"]:
        raise MesSemanticDiffError("MES semantic diff source identities changed")
    source_container = decompiler.reconstruct_container(source_ir)
    output_container = decompiler.reconstruct_container(output_ir)
    if hashlib.sha256(source_container).hexdigest() != compile_audit["source"]["entry_sha256"]:
        raise MesSemanticDiffError("MES semantic diff source container changed")
    if hashlib.sha256(output_container).hexdigest() != compile_audit["output"]["entry_sha256"]:
        raise MesSemanticDiffError("MES semantic diff output container changed")
    expected_output, address_changes = _expected_output(source_container, compile_audit)
    if expected_output != output_container:
        raise MesSemanticDiffError("MES semantic diff output bytes exceed the intended edit")

    source_nodes = source_ir["nodes"]
    output_nodes = output_ir["nodes"]
    output_by_start = _unique_nodes_by_start(output_nodes, "output")
    operation = compile_audit["operation"]
    body = compile_audit["body"]
    kind = str(operation["kind"])
    source_start, source_end = int(operation["source_start"]), int(operation["source_end"])
    output_start, output_end = int(operation["output_start"]), int(operation["output_end"])
    pivot, delta = int(compile_audit["relocation"]["pivot"]), int(compile_audit["relocation"]["delta"])
    patches_by_owner: dict[int, list[dict[str, Any]]] = {}
    for patch in compile_audit["target_patches"]:
        patches_by_owner.setdefault(int(patch["source_instruction_start"]), []).append(patch)

    mapping_rows: list[dict[str, Any]] = []
    inserted_rows: list[dict[str, Any]] = []
    removed_rows: list[dict[str, Any]] = []
    patched_rows: list[dict[str, Any]] = []
    matched_output_ids: set[str] = set()
    retained_raw_exact = 0
    patched_retained = 0
    unrelated_typed_exact = 0
    exact_opaque = 0
    retained_count = 0
    for source_node in source_nodes:
        source = source_node["source"]
        node_start, node_end = int(source["start"]), int(source["end"])
        removed = kind == "remove_typed_body" and source_start <= node_start < source_end
        if removed:
            row = _node_change_row(source_node, None)
            removed_rows.append(row)
            mapping_rows.append({**row, "status": "removed", "patch_count": 0})
            continue
        relocated_start = node_start + (delta if node_start >= pivot else 0)
        relocated_end = node_end + (delta if node_start >= pivot else 0)
        output_node = output_by_start.get(relocated_start)
        if output_node is None or int(output_node["source"]["end"]) != relocated_end:
            raise MesSemanticDiffError("MES semantic diff retained node boundary changed")
        expected_raw = bytearray(bytes.fromhex(str(source["raw_hex"])))
        owner_patches = patches_by_owner.get(node_start, [])
        for patch in owner_patches:
            relative = int(patch["source_operand_start"]) - node_start
            if bytes(expected_raw[relative:relative + 4]) != bytes.fromhex(str(patch["source_raw_hex"])):
                raise MesSemanticDiffError("MES semantic diff source target operand changed")
            expected_raw[relative:relative + 4] = bytes.fromhex(str(patch["output_raw_hex"]))
        output_raw = bytes.fromhex(str(output_node["source"]["raw_hex"]))
        if output_raw != bytes(expected_raw):
            raise MesSemanticDiffError("MES semantic diff retained node bytes changed")
        row = _node_change_row(source_node, output_node)
        mapping_rows.append({**row, "status": "retained", "patch_count": len(owner_patches)})
        matched_output_ids.add(str(output_node["id"]))
        retained_count += 1
        if owner_patches:
            patched_rows.append(row)
            patched_retained += 1
        else:
            retained_raw_exact += 1
            if source_node["kind"] == "opaque":
                exact_opaque += 1
            else:
                unrelated_typed_exact += 1

    if kind == "insert_typed_body_copy":
        donor_nodes = [
            row for row in source_nodes
            if source_start <= int(row["source"]["start"]) < source_end
        ]
        donor_nodes.sort(key=lambda row: int(row["source"]["start"]))
        for donor in donor_nodes:
            relative_start = int(donor["source"]["start"]) - source_start
            relative_end = int(donor["source"]["end"]) - source_start
            inserted = output_by_start.get(output_start + relative_start)
            if (
                inserted is None
                or int(inserted["source"]["end"]) != output_start + relative_end
                or inserted["source"]["raw_sha256"] != donor["source"]["raw_sha256"]
                or inserted["kind"] != donor["kind"]
            ):
                raise MesSemanticDiffError("MES semantic diff inserted body node changed")
            inserted_rows.append(_node_change_row(donor, inserted))
            matched_output_ids.add(str(inserted["id"]))

    if len(matched_output_ids) != len(output_nodes) or matched_output_ids != {str(row["id"]) for row in output_nodes}:
        raise MesSemanticDiffError("MES semantic diff output node coverage changed")
    source_opaque = sum(row["kind"] == "opaque" for row in source_nodes)
    output_opaque = sum(row["kind"] == "opaque" for row in output_nodes)
    if source_opaque != output_opaque or exact_opaque != source_opaque:
        raise MesSemanticDiffError("MES semantic diff opaque node preservation changed")

    target_changes = _target_changes(output_ir, compile_audit)
    if len(address_changes) != int(compile_audit["relocation"]["address_update_count"]):
        raise MesSemanticDiffError("MES semantic diff address change count changed")
    if len(target_changes) != int(compile_audit["relocation"]["target_patch_count"]):
        raise MesSemanticDiffError("MES semantic diff target change count changed")
    return {
        "ok": True,
        "schema": DIFF_SCHEMA,
        "producer": {
            "implementation": "python_phase6_mes_semantic_diff",
            "contract": DIFF_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "source_decompiler_ir_sha256": source_ir["payload_sha256"],
            "compile_audit_sha256": compile_audit["payload_sha256"],
            "output_analyzer_handoff_sha256": output_handoff["payload_sha256"],
        },
        "operation": {"family": "control_body_edit", "kind": kind},
        "container_diff": {
            "source_size": len(source_container),
            "output_size": len(output_container),
            "byte_delta": len(output_container) - len(source_container),
            "source_code_size": int(compile_audit["source"]["code_size"]),
            "output_code_size": int(compile_audit["output"]["code_size"]),
            "code_delta": delta,
            "entry_count": int(compile_audit["output"]["entry_count"]),
            "code_offset": int(compile_audit["output"]["code_offset"]),
        },
        "semantic_changes": {
            "body": {
                "kind": kind,
                "source_start": source_start,
                "source_end": source_end,
                "output_start": output_start,
                "output_end": output_end,
                "byte_length": int(body["byte_length"]),
                "raw_sha256": str(body["source_raw_sha256"]),
                "source_node_count": int(body["source_node_count"]),
            },
            "address_changes": address_changes,
            "target_changes": target_changes,
        },
        "node_diff": {
            "source_node_count": len(source_nodes),
            "output_node_count": len(output_nodes),
            "retained_node_count": retained_count,
            "inserted_node_count": len(inserted_rows),
            "removed_node_count": len(removed_rows),
            "patched_node_count": len(patched_rows),
            "mapping_sha256": _json_sha256(mapping_rows),
            "inserted_nodes": inserted_rows,
            "removed_nodes": removed_rows,
            "patched_nodes": patched_rows,
        },
        "preservation": {
            "source_opaque_node_count": source_opaque,
            "output_opaque_node_count": output_opaque,
            "exact_opaque_node_count": exact_opaque,
            "retained_raw_exact_node_count": retained_raw_exact,
            "patched_retained_node_count": patched_retained,
            "unrelated_typed_exact_node_count": unrelated_typed_exact,
        },
        "output_binding": {
            "analyzer_handoff_sha256": output_handoff["payload_sha256"],
            "decompiler_ir_sha256": output_ir["payload_sha256"],
            "entry_sha256": output_ir["container"]["entry_sha256"],
            "bytecode_sha256": output_ir["container"]["bytecode_sha256"],
        },
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _expected_output(
    source_container: bytes, audit: dict[str, Any]
) -> tuple[bytes, list[dict[str, int]]]:
    header = noop_compiler.reopen_container(source_container)
    code_offset = int(header["code_offset"])
    source_code = source_container[code_offset:]
    operation = audit["operation"]
    start, end = int(operation["source_start"]), int(operation["source_end"])
    body = source_code[start:end]
    if hashlib.sha256(body).hexdigest() != audit["body"]["source_raw_sha256"]:
        raise MesSemanticDiffError("MES semantic diff body source hash changed")
    if operation["kind"] == "insert_typed_body_copy":
        anchor = int(operation["output_start"])
        output_code = bytearray(source_code[:anchor] + body + source_code[anchor:])
    else:
        output_code = bytearray(source_code[:start] + source_code[end:])
    for patch in audit["target_patches"]:
        patch_start, patch_end = int(patch["output_operand_start"]), int(patch["output_operand_end"])
        if bytes(output_code[patch_start:patch_end]) != bytes.fromhex(str(patch["source_raw_hex"])):
            raise MesSemanticDiffError("MES semantic diff expected target source bytes changed")
        output_code[patch_start:patch_end] = bytes.fromhex(str(patch["output_raw_hex"]))
    pivot, delta = int(audit["relocation"]["pivot"]), int(audit["relocation"]["delta"])
    preamble = bytearray(source_container[:code_offset])
    changes = []
    for index, source_offset in enumerate(header["entry_offsets"]):
        if int(source_offset) < pivot:
            continue
        output_offset = int(source_offset) + delta
        preamble[4 + index * 4:8 + index * 4] = output_offset.to_bytes(4, "little")
        changes.append({"index": index, "source_offset": int(source_offset), "output_offset": output_offset})
    return bytes(preamble) + bytes(output_code), changes


def _target_changes(output_ir: dict[str, Any], audit: dict[str, Any]) -> list[dict[str, Any]]:
    output_refs = output_ir["references"]
    rows = []
    for patch in audit["target_patches"]:
        kind = str(patch["reference_kind"])
        verified = kind == "definition_skip_target"
        if not verified:
            matches = [
                row for row in output_refs
                if row["kind"] == "code"
                and int(row["source_offset"]) == int(patch["output_instruction_start"])
                and row["value"].get("kind") == kind
                and int(row["value"].get("target_offset", -1)) == int(patch["output_target_offset"])
                and row["value"].get("aligned") is True
                and row["value"].get("in_code") is True
            ]
            verified = len(matches) == 1
        if not verified:
            raise MesSemanticDiffError("MES semantic diff output code reference changed")
        source_raw = bytes.fromhex(str(patch["source_raw_hex"]))
        output_raw = bytes.fromhex(str(patch["output_raw_hex"]))
        rows.append({
            "reference_id": str(patch["reference_id"]),
            "reference_kind": kind,
            "source_owner_offset": int(patch["source_instruction_start"]),
            "output_owner_offset": int(patch["output_instruction_start"]),
            "source_target_offset": int(patch["source_target_offset"]),
            "output_target_offset": int(patch["output_target_offset"]),
            "source_operand_sha256": hashlib.sha256(source_raw).hexdigest(),
            "output_operand_sha256": hashlib.sha256(output_raw).hexdigest(),
            "output_reference_verified": True,
        })
    return rows


def _unique_nodes_by_start(nodes: list[dict[str, Any]], label: str) -> dict[int, dict[str, Any]]:
    output: dict[int, dict[str, Any]] = {}
    for node in nodes:
        start = int(node["source"]["start"])
        if start in output:
            raise MesSemanticDiffError(f"MES semantic diff {label} node start is not unique")
        output[start] = node
    return output


def _node_change_row(
    source_node: dict[str, Any], output_node: dict[str, Any] | None
) -> dict[str, Any]:
    source = source_node["source"]
    output = output_node["source"] if output_node is not None else None
    return {
        "source_node_id": str(source_node["id"]),
        "source_start": int(source["start"]),
        "source_end": int(source["end"]),
        "output_node_id": "" if output_node is None else str(output_node["id"]),
        "output_start": -1 if output is None else int(output["start"]),
        "output_end": -1 if output is None else int(output["end"]),
        "source_raw_sha256": str(source["raw_sha256"]),
        "output_raw_sha256": "" if output is None else str(output["raw_sha256"]),
    }


def _json_sha256(value: Any) -> str:
    return hashlib.sha256(json.dumps(
        value, ensure_ascii=False, allow_nan=False, sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")).hexdigest()


def _validate_shape_semantics(document: dict[str, Any]) -> None:
    if any(not _is_sha256(value) for value in document["inputs"].values()):
        raise MesSemanticDiffError("MES semantic diff input hashes changed")
    identity = document.get("source_identity")
    if not isinstance(identity, dict) or not isinstance(identity.get("entry"), str) or not identity["entry"]:
        raise MesSemanticDiffError("MES semantic diff source identity changed")
    operation = document["operation"]
    if operation != {
        "family": "control_body_edit", "kind": operation.get("kind"),
    } or operation["kind"] not in {"insert_typed_body_copy", "remove_typed_body"}:
        raise MesSemanticDiffError("MES semantic diff operation changed")
    container = document["container_diff"]
    if any(not _is_integer(value) or value < 0 for key, value in container.items() if key not in {"byte_delta", "code_delta"}):
        raise MesSemanticDiffError("MES semantic diff container coordinate changed")
    if any(not _is_integer(container[key]) for key in ("byte_delta", "code_delta")):
        raise MesSemanticDiffError("MES semantic diff container delta changed")
    if (
        container["output_size"] - container["source_size"] != container["byte_delta"]
        or container["output_code_size"] - container["source_code_size"] != container["code_delta"]
        or container["byte_delta"] != container["code_delta"]
    ):
        raise MesSemanticDiffError("MES semantic diff container arithmetic changed")
    changes = document["semantic_changes"]
    body = changes["body"]
    integer_body_keys = {
        "source_start", "source_end", "output_start", "output_end",
        "byte_length", "source_node_count",
    }
    if (
        body["kind"] != operation["kind"]
        or any(not _is_integer(body[key]) or body[key] < 0 for key in integer_body_keys)
        or not _is_sha256(body["raw_sha256"])
        or body["source_end"] - body["source_start"] != body["byte_length"]
        or body["source_node_count"] <= 0
        or abs(container["code_delta"]) != body["byte_length"]
    ):
        raise MesSemanticDiffError("MES semantic diff body summary changed")
    if operation["kind"] == "insert_typed_body_copy":
        if body["output_end"] - body["output_start"] != body["byte_length"] or container["code_delta"] <= 0:
            raise MesSemanticDiffError("MES semantic diff insertion body changed")
    elif body["output_start"] != body["output_end"] or container["code_delta"] >= 0:
        raise MesSemanticDiffError("MES semantic diff removal body changed")
    for row in changes["address_changes"]:
        if (
            any(not _is_integer(row[key]) or row[key] < 0 for key in ADDRESS_KEYS)
            or row["output_offset"] - row["source_offset"] != container["code_delta"]
        ):
            raise MesSemanticDiffError("MES semantic diff address change changed")
    for row in changes["target_changes"]:
        integer_keys = {
            "source_owner_offset", "output_owner_offset", "source_target_offset",
            "output_target_offset",
        }
        if (
            not row["reference_id"] or not row["reference_kind"]
            or any(not _is_integer(row[key]) or row[key] < 0 for key in integer_keys)
            or not _is_sha256(row["source_operand_sha256"])
            or not _is_sha256(row["output_operand_sha256"])
            or row["output_reference_verified"] is not True
        ):
            raise MesSemanticDiffError("MES semantic diff target change changed")
    node_diff = document["node_diff"]
    count_keys = {
        "source_node_count", "output_node_count", "retained_node_count",
        "inserted_node_count", "removed_node_count", "patched_node_count",
    }
    if (
        any(not _is_integer(node_diff[key]) or node_diff[key] < 0 for key in count_keys)
        or not _is_sha256(node_diff["mapping_sha256"])
        or node_diff["retained_node_count"] + node_diff["removed_node_count"] != node_diff["source_node_count"]
        or node_diff["retained_node_count"] + node_diff["inserted_node_count"] != node_diff["output_node_count"]
        or len(node_diff["inserted_nodes"]) != node_diff["inserted_node_count"]
        or len(node_diff["removed_nodes"]) != node_diff["removed_node_count"]
        or len(node_diff["patched_nodes"]) != node_diff["patched_node_count"]
    ):
        raise MesSemanticDiffError("MES semantic diff node accounting changed")
    for key in ("inserted_nodes", "removed_nodes", "patched_nodes"):
        for row in node_diff[key]:
            if (
                not row["source_node_id"]
                or any(not _is_integer(row[field]) for field in (
                    "source_start", "source_end", "output_start", "output_end",
                ))
                or not _is_sha256(row["source_raw_sha256"])
                or row["source_start"] < 0 or row["source_end"] <= row["source_start"]
            ):
                raise MesSemanticDiffError("MES semantic diff node change changed")
            removed = key == "removed_nodes"
            if removed != (row["output_node_id"] == "" and row["output_start"] == -1 and row["output_end"] == -1 and row["output_raw_sha256"] == ""):
                raise MesSemanticDiffError("MES semantic diff removed-node sentinel changed")
            if not removed and (
                not row["output_node_id"] or row["output_start"] < 0
                or row["output_end"] <= row["output_start"]
                or not _is_sha256(row["output_raw_sha256"])
            ):
                raise MesSemanticDiffError("MES semantic diff output-node change changed")
    preservation = document["preservation"]
    if (
        any(not _is_integer(value) or value < 0 for value in preservation.values())
        or preservation["source_opaque_node_count"] != preservation["output_opaque_node_count"]
        or preservation["source_opaque_node_count"] != preservation["exact_opaque_node_count"]
        or preservation["retained_raw_exact_node_count"]
        != preservation["exact_opaque_node_count"] + preservation["unrelated_typed_exact_node_count"]
        or preservation["patched_retained_node_count"] != node_diff["patched_node_count"]
        or preservation["retained_raw_exact_node_count"] + preservation["patched_retained_node_count"]
        != node_diff["retained_node_count"]
    ):
        raise MesSemanticDiffError("MES semantic diff preservation accounting changed")
    if any(not _is_sha256(value) for value in document["output_binding"].values()):
        raise MesSemanticDiffError("MES semantic diff output binding changed")


def _is_integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _require_dict_keys(document: dict[str, Any], key: str, expected: set[str]) -> None:
    value = document.get(key)
    if not isinstance(value, dict) or set(value) != expected:
        raise MesSemanticDiffError(f"MES semantic diff {key} fields changed")


def _require_rows(document: dict[str, Any], key: str, expected: set[str]) -> None:
    value = document.get(key)
    if not isinstance(value, list) or any(not isinstance(row, dict) or set(row) != expected for row in value):
        raise MesSemanticDiffError(f"MES semantic diff {key} fields changed")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build an exact semantic source/output diff for one validated MES "
            "control-body compile and its Godot analyzer handoff."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("compile_audit", type=Path)
    parser.add_argument("output_handoff", type=Path)
    parser.add_argument("output_diff", type=Path)
    args = parser.parse_args()
    paths = [args.editable_ir, args.compile_audit, args.output_handoff, args.output_diff]
    if len({path.resolve() for path in paths}) != 4 or args.output_diff.exists():
        raise MesSemanticDiffError("MES semantic diff output must be a new distinct file")
    try:
        values = [json.loads(path.read_text(encoding="utf-8")) for path in paths[:3]]
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise MesSemanticDiffError("MES semantic diff input JSON could not be read") from error
    if any(not isinstance(value, dict) for value in values):
        raise MesSemanticDiffError("MES semantic diff inputs must be JSON objects")
    document = build(values[0], values[1], values[2])
    editable_ir.publish_new(args.output_diff, editable_ir.canonical_json_bytes(document) + b"\n")
    print(
        "MES_SEMANTIC_DIFF_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_identity'].get('entry', '')} "
        f"kind={document['operation']['kind']} "
        f"inserted={document['node_diff']['inserted_node_count']} "
        f"removed={document['node_diff']['removed_node_count']} "
        f"patched={document['node_diff']['patched_node_count']} "
        f"opaque={document['preservation']['exact_opaque_node_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
