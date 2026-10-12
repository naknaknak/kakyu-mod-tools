from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_control_target_relocation as control_compiler
import compile_mes_message_relocation as message_compiler
import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import prepare_mes_editable_ir as editable_ir
import validate_mes_analyzer_handoff as handoff_validator
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


DIFF_SCHEMA = "kakyu_mes_semantic_diff/v4"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "operation", "container_diff", "semantic_changes", "node_diff",
    "preservation", "output_binding", "invariants", "payload_sha256",
}
COMPATIBILITY = {
    "policy": "variable_length_message_with_exact_relocation_mapping",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_compile_audit_schemas": [
        message_compiler.AUDIT_SCHEMA, control_compiler.AUDIT_SCHEMA,
    ],
    "input_handoff_schema": handoff_validator.HANDOFF_SCHEMA,
    "output_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "supported_families": ["message_relocation"],
    "unknown_diff_schema": "reject",
    "unknown_v4_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "compile_audit_validated": True,
    "output_handoff_validated": True,
    "output_decompiler_ir_validated": True,
    "expected_output_bytes_exact": True,
    "message_payload_change_exact": True,
    "address_relocation_exact": True,
    "target_relocation_exact": True,
    "all_nodes_mapped_once": True,
    "all_references_mapped_once": True,
    "unrelated_node_bytes_preserved": True,
    "opaque_nodes_preserved_exactly": True,
}
COORDINATE_FIELDS = {
    "source_offset", "end_offset", "probe_end_offset", "start_offset",
    "stop_offset", "target_offset",
}


class MesMessageRelocationSemanticDiffError(ValueError):
    pass


def build(editable_document: dict[str, Any], audit: dict[str, Any], handoff: dict[str, Any]) -> dict[str, Any]:
    result = _build(editable_document, audit, handoff)
    result["payload_sha256"] = fingerprint(result)
    validate(result, editable_document, audit, handoff)
    return result


def validate(
    document: dict[str, Any], editable_document: dict[str, Any] | None = None,
    audit: dict[str, Any] | None = None, handoff: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if document.get("ok") is not True or document.get("schema") != DIFF_SCHEMA or set(document) != TOP_LEVEL_KEYS:
        raise MesMessageRelocationSemanticDiffError("MES message relocation semantic diff schema or fields changed")
    if document.get("producer") != {
        "implementation": "python_phase6_message_relocation_semantic_diff",
        "contract": DIFF_SCHEMA,
    } or document.get("compatibility") != COMPATIBILITY:
        raise MesMessageRelocationSemanticDiffError("MES message relocation semantic diff producer changed")
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise MesMessageRelocationSemanticDiffError("MES message relocation semantic diff fingerprint changed")
    _validate_shape(document)
    supplied = (editable_document, audit, handoff)
    if any(value is not None for value in supplied):
        if any(value is None for value in supplied):
            raise MesMessageRelocationSemanticDiffError("MES message relocation semantic diff inputs are incomplete")
        expected = _build(editable_document, audit, handoff)  # type: ignore[arg-type]
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise MesMessageRelocationSemanticDiffError("MES message relocation semantic diff differs from its inputs")
    return {"ok": True, "schema": DIFF_SCHEMA, "payload_sha256": retained}


def _build(editable_document: dict[str, Any], audit: dict[str, Any], handoff: dict[str, Any]) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    module, compile_family = _audit_module(audit)
    module.validate_audit(audit)
    handoff_validator.validate(handoff)
    source_ir = editable_document["source_ir"]
    output_ir = decompiler.lift(handoff)
    if (
        source_ir["source_identity"] != audit["source_identity"]
        or source_ir["source_identity"] != output_ir["source_identity"]
        or audit["inputs"]["editable_ir_sha256"] != editable_document["payload_sha256"]
        or audit["inputs"]["decompiler_ir_sha256"] != source_ir["payload_sha256"]
    ):
        raise MesMessageRelocationSemanticDiffError("MES message relocation source binding changed")
    source_container = decompiler.reconstruct_container(source_ir)
    output_container = decompiler.reconstruct_container(output_ir)
    if hashlib.sha256(source_container).hexdigest() != audit["source"]["entry_sha256"]:
        raise MesMessageRelocationSemanticDiffError("MES message relocation source container changed")
    if hashlib.sha256(output_container).hexdigest() != audit["output"]["entry_sha256"]:
        raise MesMessageRelocationSemanticDiffError("MES message relocation output container changed")
    source_header = noop_compiler.reopen_container(source_container)
    output_header = noop_compiler.reopen_container(output_container)
    if not _summary_matches(source_container, source_header, audit["source"]):
        raise MesMessageRelocationSemanticDiffError("MES message relocation source geometry changed")
    if not _summary_matches(output_container, output_header, audit["output"]):
        raise MesMessageRelocationSemanticDiffError("MES message relocation output geometry changed")

    relocation = audit["relocation"]
    operation = audit["operation"]
    delta = int(relocation["delta"])
    source_start = int(relocation["source_instruction_start"])
    source_end = int(relocation["source_instruction_end"])
    output_end = int(relocation["output_instruction_end"])
    source_nodes = _unique_nodes(source_ir["nodes"], "source")
    output_nodes = _unique_nodes(output_ir["nodes"], "output")
    source_target = source_nodes.get(source_start)
    output_target = output_nodes.get(source_start)
    source_payload = _message_payload(source_target, int(operation["source_offset"]))
    output_payload = _message_payload(output_target, int(operation["source_offset"]))
    if (
        source_target is None or output_target is None
        or int(source_target["source"]["end"]) != source_end
        or int(output_target["source"]["end"]) != output_end
        or output_end - source_end != delta
        or source_payload["sha256"] != operation["source_raw_sha256"]
        or output_payload["sha256"] != operation["replacement_raw_sha256"]
        or source_payload["length"] != int(operation["source_byte_length"])
        or output_payload["length"] != int(operation["replacement_byte_length"])
        or source_target["statement"]["op"] != output_target["statement"]["op"]
        or source_target["statement"]["command_id"] != output_target["statement"]["command_id"]
        or source_target["reference_ids"] != output_target["reference_ids"]
    ):
        raise MesMessageRelocationSemanticDiffError("MES message relocation target message changed")

    target_patches = audit.get("target_patches", [])
    expected_output, address_changes = _expected_output(
        source_container, output_target, audit, target_patches
    )
    if expected_output != output_container:
        raise MesMessageRelocationSemanticDiffError("MES message relocation output bytes exceed the intended edit")

    patches_by_owner: dict[int, list[dict[str, Any]]] = {}
    for patch in target_patches:
        patches_by_owner.setdefault(int(patch["source_instruction_start"]), []).append(patch)
    mapping = []
    matched_output_ids = set()
    exact_count = patched_count = opaque_count = 0
    for start, source_node in sorted(source_nodes.items()):
        if start == source_start:
            output_node = output_target
            status = "message_replaced"
        else:
            output_node = output_nodes.get(_relocate(start, source_end, delta))
            status = "target_patched" if start in patches_by_owner else "exact"
        if output_node is None:
            raise MesMessageRelocationSemanticDiffError("MES message relocation lost an output node")
        expected_start = start if start < source_end else start + delta
        expected_end = int(source_node["source"]["end"]) if start < source_end else int(source_node["source"]["end"]) + delta
        if start == source_start:
            expected_start, expected_end = source_start, output_end
        if (
            int(output_node["source"]["start"]) != expected_start
            or int(output_node["source"]["end"]) != expected_end
            or source_node["kind"] != output_node["kind"]
            or source_node["statement"]["op"] != output_node["statement"]["op"]
            or source_node["statement"]["command_id"] != output_node["statement"]["command_id"]
            or source_node["reference_ids"] != output_node["reference_ids"]
        ):
            raise MesMessageRelocationSemanticDiffError("MES message relocation node boundary or type changed")
        if start != source_start:
            expected_raw = bytearray(bytes.fromhex(source_node["source"]["raw_hex"]))
            for patch in patches_by_owner.get(start, []):
                relative = int(patch["source_operand_start"]) - start
                source_raw = bytes.fromhex(patch["source_raw_hex"])
                if bytes(expected_raw[relative:relative + 4]) != source_raw:
                    raise MesMessageRelocationSemanticDiffError("MES message relocation source target operand changed")
                expected_raw[relative:relative + 4] = bytes.fromhex(patch["output_raw_hex"])
            if bytes(expected_raw) != bytes.fromhex(output_node["source"]["raw_hex"]):
                raise MesMessageRelocationSemanticDiffError("MES message relocation unrelated node bytes changed")
            if status == "exact":
                exact_count += 1
            else:
                patched_count += 1
        if source_node["kind"] == "opaque":
            opaque_count += 1
            if status != "exact":
                raise MesMessageRelocationSemanticDiffError("MES message relocation shifted or patched an opaque node")
        matched_output_ids.add(output_node["id"])
        mapping.append({
            "source_id": source_node["id"], "output_id": output_node["id"],
            "source_start": start, "output_start": expected_start,
            "source_end": int(source_node["source"]["end"]), "output_end": expected_end,
            "status": status,
        })
    if len(matched_output_ids) != len(output_nodes):
        raise MesMessageRelocationSemanticDiffError("MES message relocation output node accounting changed")

    reference_mapping = _map_references(
        source_ir["references"], output_ir["references"], source_target,
        output_target, source_end, delta,
    )
    target_changes = _target_changes(output_ir, target_patches)
    if (
        len(address_changes) != int(relocation["address_table_update_count"])
        or len(reference_mapping) != len(source_ir["references"])
        or len(target_changes) != int(relocation.get("target_patch_count", 0))
    ):
        raise MesMessageRelocationSemanticDiffError("MES message relocation change accounting changed")

    return {
        "ok": True, "schema": DIFF_SCHEMA,
        "producer": {
            "implementation": "python_phase6_message_relocation_semantic_diff",
            "contract": DIFF_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "source_decompiler_ir_sha256": source_ir["payload_sha256"],
            "compile_audit_sha256": audit["payload_sha256"],
            "output_analyzer_handoff_sha256": handoff["payload_sha256"],
        },
        "operation": {
            "family": "message_relocation", "kind": "replace_message",
            "compile_family": compile_family,
        },
        "container_diff": {
            "source_size": len(source_container), "output_size": len(output_container),
            "byte_delta": len(output_container) - len(source_container),
            "source_code_size": int(audit["source"]["code_size"]),
            "output_code_size": int(audit["output"]["code_size"]),
            "code_delta": delta, "entry_count": int(audit["output"]["entry_count"]),
            "code_offset": int(audit["output"]["code_offset"]),
        },
        "semantic_changes": {
            "message": {
                "source_offset": int(operation["source_offset"]),
                "source_instruction_start": source_start,
                "source_instruction_end": source_end,
                "output_instruction_end": output_end,
                "source_payload_sha256": source_payload["sha256"],
                "output_payload_sha256": output_payload["sha256"],
                "source_payload_length": source_payload["length"],
                "output_payload_length": output_payload["length"],
                "source_owner_sha256": source_target["source"]["raw_sha256"],
                "output_owner_sha256": output_target["source"]["raw_sha256"],
                "owner_op": source_target["statement"]["op"],
                "target_verified": True,
            },
            "address_changes_sha256": _json_sha256(address_changes),
            "target_changes_sha256": _json_sha256(target_changes),
            "reference_mapping_sha256": _json_sha256(reference_mapping),
        },
        "node_diff": {
            "source_node_count": len(source_nodes), "output_node_count": len(output_nodes),
            "mapped_node_count": len(mapping), "message_replaced_node_count": 1,
            "target_patched_node_count": patched_count,
            "exact_unrelated_node_count": exact_count,
            "mapping_sha256": _json_sha256(mapping),
        },
        "preservation": {
            "source_opaque_node_count": opaque_count,
            "output_opaque_node_count": sum(node["kind"] == "opaque" for node in output_nodes.values()),
            "exact_opaque_node_count": opaque_count,
            "all_reference_count": len(reference_mapping),
            "address_change_count": len(address_changes),
            "target_change_count": len(target_changes),
            "unrelated_node_bytes_exact": True,
            "reference_coordinates_relocated_exactly": True,
        },
        "output_binding": {
            "analyzer_handoff_sha256": handoff["payload_sha256"],
            "decompiler_ir_sha256": output_ir["payload_sha256"],
            "entry_sha256": output_ir["container"]["entry_sha256"],
            "bytecode_sha256": output_ir["container"]["bytecode_sha256"],
        },
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _audit_module(audit: dict[str, Any]) -> tuple[Any, str]:
    schema = audit.get("schema")
    if schema == message_compiler.AUDIT_SCHEMA:
        return message_compiler, "message_only"
    if schema == control_compiler.AUDIT_SCHEMA:
        return control_compiler, "message_with_control_targets"
    raise MesMessageRelocationSemanticDiffError("unsupported MES message relocation compile audit")


def _expected_output(
    source_container: bytes, output_target: dict[str, Any], audit: dict[str, Any],
    patches: list[dict[str, Any]],
) -> tuple[bytes, list[dict[str, int]]]:
    header = noop_compiler.reopen_container(source_container)
    code_offset = int(header["code_offset"])
    source_code = source_container[code_offset:]
    relocation = audit["relocation"]
    start = int(relocation["source_instruction_start"])
    end = int(relocation["source_instruction_end"])
    delta = int(relocation["delta"])
    replacement = bytes.fromhex(output_target["source"]["raw_hex"])
    output_code = bytearray(source_code[:start] + replacement + source_code[end:])
    for patch in patches:
        output_start = int(patch["output_operand_start"])
        output_end = int(patch["output_operand_end"])
        source_raw = bytes.fromhex(patch["source_raw_hex"])
        if bytes(output_code[output_start:output_end]) != source_raw:
            raise MesMessageRelocationSemanticDiffError("MES message relocation expected target source bytes changed")
        output_code[output_start:output_end] = bytes.fromhex(patch["output_raw_hex"])
    preamble = bytearray(source_container[:code_offset])
    changes = []
    for index, source_offset in enumerate(header["entry_offsets"]):
        if int(source_offset) < end:
            continue
        output_offset = int(source_offset) + delta
        preamble[4 + index * 4:8 + index * 4] = output_offset.to_bytes(4, "little")
        changes.append({"index": index, "source_offset": int(source_offset), "output_offset": output_offset})
    return bytes(preamble) + bytes(output_code), changes


def _message_payload(node: dict[str, Any] | None, source_offset: int) -> dict[str, Any]:
    if node is None or node.get("kind") != "statement" or node.get("statement", {}).get("op") not in {"text", "dispatcher_character_text"}:
        raise MesMessageRelocationSemanticDiffError("MES message relocation owner is not typed text")
    matches = []
    for operand in node["statement"].get("operands", []):
        if operand.get("type") == "cp932_bytes" and int(operand.get("source_offset", -1)) >= source_offset:
            raw = bytes.fromhex(str(operand.get("raw_hex", "")))
            matches.append({"sha256": hashlib.sha256(raw).hexdigest(), "length": len(raw)})
    if len(matches) != 1:
        raise MesMessageRelocationSemanticDiffError("MES message relocation payload is not unique")
    return matches[0]


def _map_references(
    source_rows: list[dict[str, Any]], output_rows: list[dict[str, Any]],
    source_target: dict[str, Any], output_target: dict[str, Any], pivot: int, delta: int,
) -> list[dict[str, Any]]:
    output_by_id = {row["id"]: row for row in output_rows}
    if len(output_by_id) != len(output_rows) or len(source_rows) != len(output_rows):
        raise MesMessageRelocationSemanticDiffError("MES message relocation reference count changed")
    target_ids = set(source_target["reference_ids"])
    if target_ids != set(output_target["reference_ids"]) or len(target_ids) != 1:
        raise MesMessageRelocationSemanticDiffError("MES message relocation message reference changed")
    mapping = []
    for source in source_rows:
        output = output_by_id.get(source["id"])
        if output is None or source["kind"] != output["kind"]:
            raise MesMessageRelocationSemanticDiffError("MES message relocation reference identity changed")
        if source["id"] in target_ids:
            if not _message_reference_matches(source, source_target) or not _message_reference_matches(output, output_target):
                raise MesMessageRelocationSemanticDiffError("MES message relocation message reference payload changed")
        else:
            expected = _relocate_coordinates(copy.deepcopy(source), pivot, delta)
            if expected != output:
                raise MesMessageRelocationSemanticDiffError("MES message relocation reference coordinate changed")
        mapping.append({
            "reference_id": source["id"], "kind": source["kind"],
            "source_offset": int(source["source_offset"]),
            "output_source_offset": int(output["source_offset"]),
            "status": "message_replaced" if source["id"] in target_ids else "relocated_or_exact",
        })
    return mapping


def _message_reference_matches(reference: dict[str, Any], node: dict[str, Any]) -> bool:
    if reference.get("kind") != "message" or int(reference.get("source_offset", -1)) != int(node["source"]["start"]):
        return False
    operands = [
        row for row in node["statement"].get("operands", [])
        if row.get("type") == "cp932_bytes"
    ]
    if len(operands) != 1:
        return False
    raw_hex = operands[0].get("raw_hex")
    try:
        raw = bytes.fromhex(str(raw_hex))
    except ValueError:
        return False
    value = reference.get("value", {})
    return (
        value.get("raw_hex") == raw_hex
        and value.get("raw_sha256") == hashlib.sha256(raw).hexdigest()
        and int(value.get("end_offset", -1)) == int(node["source"]["end"])
        and value.get("native_stream_projection_match") is True
    )


def _relocate_coordinates(value: Any, pivot: int, delta: int, key: str = "") -> Any:
    if isinstance(value, dict):
        return {name: _relocate_coordinates(child, pivot, delta, name) for name, child in value.items()}
    if isinstance(value, list):
        return [_relocate_coordinates(child, pivot, delta, key) for child in value]
    if key in COORDINATE_FIELDS and isinstance(value, int) and not isinstance(value, bool):
        return _relocate(value, pivot, delta)
    return value


def _target_changes(output_ir: dict[str, Any], patches: list[dict[str, Any]]) -> list[dict[str, Any]]:
    changes = []
    for patch in patches:
        verified = patch["reference_kind"] == "definition_skip_target"
        if not verified:
            matches = [
                row for row in output_ir["references"]
                if row["kind"] == "code"
                and int(row["source_offset"]) == int(patch["output_instruction_start"])
                and row["value"].get("kind") == patch["reference_kind"]
                and int(row["value"].get("target_offset", -1)) == int(patch["output_target_offset"])
                and row["value"].get("aligned") is True and row["value"].get("in_code") is True
            ]
            verified = len(matches) == 1
        if not verified:
            raise MesMessageRelocationSemanticDiffError("MES message relocation output target reference changed")
        changes.append({
            "reference_id": patch["reference_id"], "kind": patch["reference_kind"],
            "source_owner": int(patch["source_instruction_start"]),
            "output_owner": int(patch["output_instruction_start"]),
            "source_target": int(patch["source_target_offset"]),
            "output_target": int(patch["output_target_offset"]),
            "source_raw_sha256": hashlib.sha256(bytes.fromhex(patch["source_raw_hex"])).hexdigest(),
            "output_raw_sha256": hashlib.sha256(bytes.fromhex(patch["output_raw_hex"])).hexdigest(),
            "verified": True,
        })
    return changes


def _unique_nodes(rows: list[dict[str, Any]], label: str) -> dict[int, dict[str, Any]]:
    result = {int(row["source"]["start"]): row for row in rows}
    if len(result) != len(rows):
        raise MesMessageRelocationSemanticDiffError(f"MES message relocation {label} node start is not unique")
    return result


def _summary_matches(payload: bytes, header: dict[str, Any], row: dict[str, Any]) -> bool:
    code_offset = int(header["code_offset"])
    code = payload[code_offset:]
    return (
        len(payload) == int(row["size"])
        and int(header["entry_count"]) == int(row["entry_count"])
        and code_offset == int(row["code_offset"])
        and len(code) == int(row["code_size"])
        and hashlib.sha256(payload).hexdigest() == row["entry_sha256"]
        and hashlib.sha256(code).hexdigest() == row["bytecode_sha256"]
        and hashlib.sha256(payload[:code_offset]).hexdigest() == row["preamble_sha256"]
    )


def _relocate(value: int, pivot: int, delta: int) -> int:
    return value + delta if value >= pivot else value


def _validate_shape(document: dict[str, Any]) -> None:
    expected = {
        "inputs": {"editable_ir_sha256", "source_decompiler_ir_sha256", "compile_audit_sha256", "output_analyzer_handoff_sha256"},
        "operation": {"family", "kind", "compile_family"},
        "container_diff": {"source_size", "output_size", "byte_delta", "source_code_size", "output_code_size", "code_delta", "entry_count", "code_offset"},
        "semantic_changes": {"message", "address_changes_sha256", "target_changes_sha256", "reference_mapping_sha256"},
        "node_diff": {"source_node_count", "output_node_count", "mapped_node_count", "message_replaced_node_count", "target_patched_node_count", "exact_unrelated_node_count", "mapping_sha256"},
        "preservation": {"source_opaque_node_count", "output_opaque_node_count", "exact_opaque_node_count", "all_reference_count", "address_change_count", "target_change_count", "unrelated_node_bytes_exact", "reference_coordinates_relocated_exactly"},
        "output_binding": {"analyzer_handoff_sha256", "decompiler_ir_sha256", "entry_sha256", "bytecode_sha256"},
    }
    for name, keys in expected.items():
        if not isinstance(document.get(name), dict) or set(document[name]) != keys:
            raise MesMessageRelocationSemanticDiffError(f"MES message relocation semantic diff {name} fields changed")
    message = document["semantic_changes"].get("message")
    if not isinstance(message, dict) or set(message) != {
        "source_offset", "source_instruction_start", "source_instruction_end", "output_instruction_end",
        "source_payload_sha256", "output_payload_sha256", "source_payload_length", "output_payload_length",
        "source_owner_sha256", "output_owner_sha256", "owner_op", "target_verified",
    }:
        raise MesMessageRelocationSemanticDiffError("MES message relocation semantic assertion fields changed")
    operation = document["operation"]
    container = document["container_diff"]
    nodes = document["node_diff"]
    preservation = document["preservation"]
    if (
        operation["family"] != "message_relocation" or operation["kind"] != "replace_message"
        or operation["compile_family"] not in {"message_only", "message_with_control_targets"}
        or not _integer_fields(container, set(container) - {"byte_delta", "code_delta"})
        or not _signed_integer_fields(container, {"byte_delta", "code_delta"})
        or container["output_size"] - container["source_size"] != container["byte_delta"]
        or container["output_code_size"] - container["source_code_size"] != container["code_delta"]
        or container["byte_delta"] != container["code_delta"] or container["code_delta"] == 0
        or not _integer_fields(nodes, set(nodes) - {"mapping_sha256"})
        or nodes["source_node_count"] != nodes["output_node_count"]
        or nodes["mapped_node_count"] != nodes["source_node_count"]
        or nodes["message_replaced_node_count"] != 1
        or nodes["message_replaced_node_count"] + nodes["target_patched_node_count"] + nodes["exact_unrelated_node_count"] != nodes["source_node_count"]
        or not _integer_fields(preservation, {"source_opaque_node_count", "output_opaque_node_count", "exact_opaque_node_count", "all_reference_count", "address_change_count", "target_change_count"})
        or preservation["source_opaque_node_count"] != preservation["output_opaque_node_count"]
        or preservation["source_opaque_node_count"] != preservation["exact_opaque_node_count"]
        or preservation["unrelated_node_bytes_exact"] is not True
        or preservation["reference_coordinates_relocated_exactly"] is not True
        or message["target_verified"] is not True
        or document.get("invariants") != INVARIANTS
    ):
        raise MesMessageRelocationSemanticDiffError("MES message relocation semantic diff accounting changed")
    integers = {"source_offset", "source_instruction_start", "source_instruction_end", "output_instruction_end", "source_payload_length", "output_payload_length"}
    if (
        not _integer_fields(message, integers)
        or message["source_instruction_end"] <= message["source_instruction_start"]
        or message["output_instruction_end"] <= message["source_instruction_start"]
        or message["output_payload_length"] - message["source_payload_length"] != container["code_delta"]
        or message["output_instruction_end"] - message["source_instruction_end"] != container["code_delta"]
        or not message["owner_op"]
    ):
        raise MesMessageRelocationSemanticDiffError("MES message relocation semantic assertion changed")
    hashes = [document["payload_sha256"], *document["inputs"].values(), *document["output_binding"].values(), nodes["mapping_sha256"], message["source_payload_sha256"], message["output_payload_sha256"], message["source_owner_sha256"], message["output_owner_sha256"], document["semantic_changes"]["address_changes_sha256"], document["semantic_changes"]["target_changes_sha256"], document["semantic_changes"]["reference_mapping_sha256"]]
    if not all(_is_sha256(value) for value in hashes):
        raise MesMessageRelocationSemanticDiffError("MES message relocation semantic diff hash changed")


def _integer_fields(document: dict[str, Any], keys: set[str]) -> bool:
    return all(isinstance(document.get(key), int) and not isinstance(document[key], bool) and document[key] >= 0 for key in keys)


def _signed_integer_fields(document: dict[str, Any], keys: set[str]) -> bool:
    return all(isinstance(document.get(key), int) and not isinstance(document[key], bool) for key in keys)


def _json_sha256(value: Any) -> str:
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, allow_nan=False, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description="Build an exact semantic diff for one variable-length MES message relocation.")
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("compile_audit", type=Path)
    parser.add_argument("output_handoff", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    paths = [args.editable_ir, args.compile_audit, args.output_handoff, args.output]
    if len({path.resolve() for path in paths}) != 4 or args.output.exists():
        raise MesMessageRelocationSemanticDiffError("MES message relocation semantic diff output must be new and distinct")
    documents = [json.loads(path.read_text("utf-8")) for path in paths[:3]]
    result = build(*documents)
    editable_ir.publish_new(args.output, editable_ir.canonical_json_bytes(result) + b"\n")
    print(
        "MES_MESSAGE_RELOCATION_SEMANTIC_DIFF_PASS "
        f"schema={DIFF_SCHEMA} entry={result['source_identity']['entry']} "
        f"family={result['operation']['compile_family']} delta={result['container_diff']['code_delta']} "
        f"nodes={result['node_diff']['mapped_node_count']} payload_sha256={result['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
