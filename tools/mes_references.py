"""Reference lists derived from the verified strict instruction-v45 view.

Order is part of this contract: operands are walked in producer insertion order,
not in the sorted-key order used to serialize the final handoff fingerprint.
Resource envelopes have a separate bounded scan and do not promote opaque bytes
into executable instructions or indexed dialogue.
"""

from __future__ import annotations

from copy import deepcopy
import hashlib
from typing import Any, Iterator

from mes_analysis_common import ANALYSIS_SCHEMA, analysis_regions, find_region


TARGET_KINDS = {
    "branch_if_not_true": "condition_false_target",
    "continuation_transfer": "continuation_target",
    "bootstrap_transfer": "bootstrap_transfer_target",
    "library_register_skip": "library_body_skip_target",
}


def _dictionaries(value: Any, stop_at_type: str = "") -> Iterator[dict[str, Any]]:
    """Preorder DFS without imposing Python's recursion limit on expression ASTs."""
    pending = [value]
    while pending:
        child = pending.pop()
        if isinstance(child, dict):
            yield child
            if not stop_at_type or child.get("type") != stop_at_type:
                pending.extend(reversed(list(child.values())))
        elif isinstance(child, list):
            pending.extend(reversed(child))


def _append_message(instruction: dict[str, Any], output: list[dict[str, Any]]) -> None:
    if instruction["op"] not in ("text", "dispatcher_character_text"):
        return
    operands = instruction["operands"]
    if not operands or not isinstance(operands[0], dict):
        return
    raw = operands[0].get("raw_bytes")
    if not isinstance(raw, bytes):
        return
    message = {
        "source_offset": instruction["source_offset"], "end_offset": instruction["end_offset"],
        "region": instruction["region"], "kind": instruction["op"],
        "raw_bytes": raw, "raw_hex": raw.hex(), "raw_sha256": hashlib.sha256(raw).hexdigest(),
    }
    if "native_stream_consumption" in instruction:
        message.update(
            native_handler_family=instruction["native_handler_family"],
            native_stream_consumption=instruction["native_stream_consumption"],
            native_stream_probe=deepcopy(instruction["native_stream_probe"]),
            native_stream_projection_match=instruction.get("native_stream_projection_match", False),
        )
    output.append(message)


def _expression_summary(ast: dict[str, Any]) -> str:
    return str(ast.get("value", 0)) if ast.get("type") == "literal" else "expression"


def _append_state_references(instruction: dict[str, Any], output: list[dict[str, Any]]) -> None:
    operands = instruction.get("operands", [])
    op, offset = instruction["op"], instruction["source_offset"]
    if op == "global_u8_write_run" and len(operands) >= 2:
        output.append({
            "source_offset": offset, "access": "write", "storage": "global_u8", "bank": 0,
            "index": str(operands[0].get("value", "?")), "count": len(operands[1].get("pairs", [])),
        })
    elif op == "state_u16_write_run" and len(operands) >= 2:
        # MA-11 (Core 0.320.0): the run's destination is its u8 index operand.
        output.append({
            "source_offset": offset, "access": "write", "storage": "state_u16", "bank": 0,
            "index": str(operands[0].get("value", "?")), "count": len(operands[1].get("pairs", [])),
        })
    elif op == "dynamic_global_u8_write_run" and operands:
        # MA-11: an expression destination is summarised like a banked one.
        # Command 0x05 keeps its older flat operand shape - the destination
        # expression, then one expression_byte_pair operand per pair.
        output.append({
            "source_offset": offset, "access": "write", "storage": "global_u8", "bank": 0,
            "index": _expression_summary(operands[0].get("value", {}).get("ast", {})),
            "count": sum(1 for operand in operands[1:] if operand.get("type") == "expression_byte_pair"),
        })
    elif op == "global_i32_write_run" and len(operands) >= 2:
        output.append({
            "source_offset": offset, "access": "write", "storage": "global_i32", "bank": 0,
            "index": _expression_summary(operands[0].get("value", {}).get("ast", {})),
            "count": len(operands[1].get("pairs", [])),
        })
    elif op in ("banked_u8_write_run", "banked_u16_write_run", "banked_i32_write_run") and len(operands) >= 3:
        output.append({
            "source_offset": offset, "access": "write",
            "storage": {"banked_u8_write_run": "banked_u8", "banked_u16_write_run": "banked_u16",
                        "banked_i32_write_run": "banked_i32"}[op],
            "bank": operands[1].get("value", 0),
            "index": _expression_summary(operands[0].get("value", {}).get("ast", {})),
            "count": len(operands[2].get("pairs", [])),
        })
    # A parent state_ref is emitted first, then its dynamic index may itself
    # contain state reads. Repeated references are not deduplicated.
    for node in _dictionaries(operands):
        if node.get("type") == "state_ref":
            output.append({
                "source_offset": offset, "access": "read", "storage": node.get("storage", "unknown"),
                "bank": node.get("bank", 0), "index": _expression_summary(node.get("index", {})), "count": 1,
            })


def _append_code_references(
    instruction: dict[str, Any], code_size: int, starts: set[int],
    ranges: list[dict[str, Any]], output: list[dict[str, Any]],
) -> None:
    op = instruction["op"]
    targets = [
        (node.get("value", -1), TARGET_KINDS.get(op, "code_target"))
        for node in _dictionaries(instruction.get("operands", []), "code_offset")
        if node.get("type") == "code_offset"
    ]
    if op == "branch_if_not_true":
        targets.append((instruction["end_offset"], "condition_true_fallthrough"))
    for target, kind in targets:
        in_code = 0 <= target < code_size
        output.append({
            "source_offset": instruction["source_offset"], "op": op, "kind": kind,
            "target_offset": target, "in_code": in_code, "aligned": in_code and target in starts,
            "target_region": find_region(target, ranges) if in_code else "outside",
        })


def build_references(container: dict[str, Any], typed_ir: dict[str, Any]) -> dict[str, Any]:
    """Build the handoff's four lists from a canonical container and strict IR."""
    from mes_resource_references import scan_resource_references

    if container.get("schema") != "ai5_mes_container/v1" or not isinstance(container.get("_bytecode"), bytes):
        raise ValueError("A current canonical MES container is required for references.")
    if typed_ir.get("schema") != ANALYSIS_SCHEMA or not isinstance(typed_ir.get("instructions"), list):
        raise ValueError("A current MES typed IR is required for references.")
    code = container["_bytecode"]
    ranges = analysis_regions(container)
    instructions = typed_ir["instructions"]
    starts = {instruction["source_offset"] for instruction in instructions}
    messages: list[dict[str, Any]] = []
    code_references: list[dict[str, Any]] = []
    state_references: list[dict[str, Any]] = []
    for instruction in instructions:
        _append_message(instruction, messages)
        _append_code_references(instruction, len(code), starts, ranges, code_references)
        _append_state_references(instruction, state_references)
    return {
        "messages": messages, "code": code_references, "state": state_references,
        "resources": scan_resource_references(code, starts, ranges),
    }
