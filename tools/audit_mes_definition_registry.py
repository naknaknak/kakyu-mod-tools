"""Audit archive-wide DEF context registrations, choice bodies, and calls.

Command 0x14 manager-context registrations and command 0x10 choice-definition
bodies are reported separately. The report is structural evidence only. It
does not execute registered bodies, infer registration lifetime, or emit MES
payload bytes or dialogue.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v6
from extract_kakyu_arc import read_entries
from payload_values import sha256_file as _sha256_file


SCHEMA = "kakyu_mes_definition_registry_audit/v2"
DEF26 = 26
RAW_DEF26_DEFINITION_BODY_RECORD = bytes.fromhex("10021aff00")
MAX_REJECTED_SAMPLES = 128


def _unique_instructions(document: dict[str, Any]) -> dict[int, dict[str, Any]]:
    result: dict[int, dict[str, Any]] = {}
    for node in document.get("nodes", []):
        for instruction in node.get("instructions", []):
            offset = int(instruction["sourceOffset"])
            result.setdefault(offset, instruction)
    return result


def _literal_record(instruction: dict[str, Any]) -> int | None:
    operands = instruction.get("operands", [])
    if not operands or operands[0].get("type") != "record_list":
        return None
    records = operands[0].get("records", [])
    if len(records) != 1 or records[0].get("type") != "expression_record":
        return None
    value = records[0].get("value", {})
    ast = value.get("ast", {})
    if not value.get("valid", False) or ast.get("type") != "literal":
        return None
    return int(ast["value"])


def _definition_body_target(instruction: dict[str, Any]) -> int | None:
    operands = instruction.get("operands", [])
    if len(operands) != 2 or operands[1].get("type") != "u8_array":
        return None
    raw = operands[1].get("value", [])
    if len(raw) != 4:
        return None
    return int.from_bytes(bytes(int(value) for value in raw), "little")


def _literal_context_selector(instruction: dict[str, Any]) -> int | None:
    operands = instruction.get("operands", [])
    if not operands or operands[0].get("type") != "expression":
        return None
    value = operands[0].get("value", {})
    ast = value.get("ast", {})
    if not value.get("valid", False) or ast.get("type") != "literal":
        return None
    return int(ast["value"])


def _context_target(instruction: dict[str, Any]) -> int | None:
    operands = instruction.get("operands", [])
    if len(operands) != 2 or operands[1].get("type") != "code_offset":
        return None
    return int(operands[1]["value"])


def _definition_body_rejection_reason(
    instruction: dict[str, Any], code_size: int, boundaries: set[int]
) -> tuple[str, str]:
    operands = instruction.get("operands", [])
    if not operands or operands[0].get("type") != "record_list":
        return "selector_operand_shape", ""
    records = operands[0].get("records", [])
    if len(records) != 1:
        return "selector_record_count", ""
    if records[0].get("type") != "expression_record":
        return "selector_record_type", str(records[0].get("type", "unknown"))
    value = records[0].get("value", {})
    ast = value.get("ast", {})
    if not value.get("valid", False):
        return "selector_expression_invalid", str(ast.get("type", "unknown"))
    if ast.get("type") != "literal":
        return "selector_expression_nonliteral", str(ast.get("type", "unknown"))
    target = _definition_body_target(instruction)
    if target is None:
        return "target_operand_shape", ""
    if target <= int(instruction["endOffset"]):
        return "target_not_forward", ""
    if target > code_size:
        return "target_out_of_bounds", ""
    if target != code_size and target not in boundaries:
        return "target_not_instruction_boundary", ""
    return "accepted", "literal"


def _selector_record_shapes(instruction: dict[str, Any]) -> list[str]:
    operands = instruction.get("operands", [])
    if not operands or operands[0].get("type") != "record_list":
        return []
    shapes: list[str] = []
    for record in operands[0].get("records", []):
        record_type = str(record.get("type", "unknown"))
        tag = int(record.get("tag", -1))
        tag_text = f"tag_0x{tag:02X}" if tag >= 0 else "tag_unknown"
        if record_type != "expression_record":
            shapes.append(f"{tag_text}:{record_type}")
            continue
        value = record.get("value", {})
        ast = value.get("ast", {})
        ast_type = str(ast.get("type", "unknown"))
        validity = "valid" if value.get("valid", False) else "invalid"
        literal_suffix = f":{int(ast['value'])}" if ast_type == "literal" else ""
        shapes.append(
            f"{tag_text}:expression_record:{validity}:{ast_type}{literal_suffix}"
        )
    return shapes


def _target_status(instruction: dict[str, Any], code_size: int, boundaries: set[int]) -> str:
    target = _definition_body_target(instruction)
    if target is None:
        return "operand_shape"
    if target <= int(instruction["endOffset"]):
        return "not_forward"
    if target > code_size:
        return "out_of_bounds"
    if target != code_size and target not in boundaries:
        return "not_instruction_boundary"
    return "valid_forward_boundary"


def scan_payload(entry_name: str, data: bytes) -> dict[str, Any]:
    if len(data) < 4:
        return {"ok": False, "entry": entry_name, "error": "truncated MES header"}
    entry_count = int.from_bytes(data[:4], "little")
    code_start = 4 + entry_count * 4
    if code_start > len(data):
        return {"ok": False, "entry": entry_name, "error": "address table exceeds entry"}
    code = data[code_start:]
    try:
        document = mes_basic_block_ir_v6.decode_mes(data, {"entry": entry_name})
    except (IndexError, ValueError) as error:
        return {"ok": False, "entry": entry_name, "error": str(error)}
    by_offset = _unique_instructions(document)
    boundaries = set(by_offset)
    context_registration_counts: Counter[int] = Counter()
    definition_body_value_counts: Counter[int] = Counter()
    invocation_counts: Counter[int] = Counter()
    def26_context_registrations: list[dict[str, int]] = []
    def26_definition_body_offsets: list[int] = []
    def26_invocation_offsets: list[int] = []
    command_14_candidates = 0
    rejected_context_registrations = 0
    command_10_candidates = 0
    rejected_definition_bodies = 0
    rejected_reason_counts: Counter[str] = Counter()
    rejected_target_status_counts: Counter[str] = Counter()
    rejected_samples: list[dict[str, Any]] = []
    for offset, instruction in sorted(by_offset.items()):
        command_id = int(instruction["commandId"])
        if command_id == 0x14:
            command_14_candidates += 1
            selector = _literal_context_selector(instruction)
            target = _context_target(instruction)
            if (
                selector is None
                or target is None
                or target <= int(instruction["endOffset"])
                or target > len(code)
                or (target != len(code) and target not in boundaries)
            ):
                rejected_context_registrations += 1
                continue
            context_registration_counts[selector] += 1
            if selector == DEF26:
                def26_context_registrations.append(
                    {
                        "source_offset": offset,
                        "body_offset": int(instruction["endOffset"]),
                        "skip_target": target,
                    }
                )
        elif command_id == 0x10:
            command_10_candidates += 1
            selector = _literal_record(instruction)
            target = _definition_body_target(instruction)
            reason, selector_ast_type = _definition_body_rejection_reason(
                instruction, len(code), boundaries
            )
            if reason != "accepted":
                rejected_definition_bodies += 1
                rejected_reason_counts[reason] += 1
                target_status = _target_status(instruction, len(code), boundaries)
                rejected_target_status_counts[target_status] += 1
                if len(rejected_samples) < MAX_REJECTED_SAMPLES:
                    rejected_samples.append(
                        {
                            "source_offset": offset,
                            "reason": reason,
                            "selector_ast_type": selector_ast_type,
                            "selector_record_shapes": _selector_record_shapes(instruction),
                            "instruction_end_offset": int(instruction["endOffset"]),
                            "target": target,
                            "target_status": target_status,
                        }
                    )
                continue
            definition_body_value_counts[selector] += 1
            if selector == DEF26:
                def26_definition_body_offsets.append(offset)
        elif command_id == 0x11:
            selector = _literal_record(instruction)
            if selector is None:
                continue
            invocation_counts[selector] += 1
            if selector == DEF26:
                def26_invocation_offsets.append(offset)
    return {
        "ok": True,
        "entry": entry_name,
        "command_14_candidates": command_14_candidates,
        "literal_context_registration_count": sum(context_registration_counts.values()),
        "rejected_context_registration_count": rejected_context_registrations,
        "literal_context_registration_id_counts": dict(
            sorted(context_registration_counts.items())
        ),
        "command_10_candidates": command_10_candidates,
        "canonical_definition_body_count": sum(definition_body_value_counts.values()),
        "rejected_definition_body_count": rejected_definition_bodies,
        "definition_body_record_value_counts": dict(
            sorted(definition_body_value_counts.items())
        ),
        "rejected_definition_body_reason_counts": dict(sorted(rejected_reason_counts.items())),
        "rejected_definition_body_target_status_counts": dict(
            sorted(rejected_target_status_counts.items())
        ),
        "rejected_definition_body_samples": rejected_samples,
        "literal_invocation_count": sum(invocation_counts.values()),
        "literal_invocation_id_counts": dict(sorted(invocation_counts.items())),
        "def26_context_registrations": def26_context_registrations,
        "def26_definition_body_offsets": def26_definition_body_offsets,
        "def26_invocation_offsets": def26_invocation_offsets,
        "raw_def26_definition_body_pattern_count": code.count(
            RAW_DEF26_DEFINITION_BODY_RECORD
        ),
    }


def audit_archive(archive: Path) -> dict[str, Any]:
    archive = archive.resolve()
    context_registration_counts: Counter[int] = Counter()
    definition_body_value_counts: Counter[int] = Counter()
    invocation_counts: Counter[int] = Counter()
    def26_context_registrations: list[dict[str, Any]] = []
    def26_definition_bodies: list[dict[str, Any]] = []
    def26_invocations: list[dict[str, Any]] = []
    rejected_samples: list[dict[str, Any]] = []
    rejected_reason_counts: Counter[str] = Counter()
    rejected_target_status_counts: Counter[str] = Counter()
    summary = {
        "script_entries": 0,
        "decoded_entries": 0,
        "decode_failures": 0,
        "command_14_candidates": 0,
        "literal_context_registration_count": 0,
        "rejected_context_registration_count": 0,
        "command_10_candidates": 0,
        "canonical_definition_body_count": 0,
        "rejected_definition_body_count": 0,
        "literal_invocation_count": 0,
        "raw_def26_definition_body_pattern_count": 0,
    }
    with archive.open("rb") as source:
        for entry_name, archive_offset, size in read_entries(archive):
            if Path(entry_name).suffix.lower() not in {".mes", ".lib"}:
                continue
            summary["script_entries"] += 1
            source.seek(archive_offset)
            data = source.read(size)
            if len(data) != size:
                raise ValueError(f"truncated archive entry: {entry_name}")
            scanned = scan_payload(entry_name, data)
            if not scanned["ok"]:
                summary["decode_failures"] += 1
                continue
            summary["decoded_entries"] += 1
            for key in (
                "command_14_candidates",
                "literal_context_registration_count",
                "rejected_context_registration_count",
                "command_10_candidates",
                "canonical_definition_body_count",
                "rejected_definition_body_count",
                "literal_invocation_count",
                "raw_def26_definition_body_pattern_count",
            ):
                summary[key] += int(scanned[key])
            context_registration_counts.update(
                {
                    int(key): int(value)
                    for key, value in scanned["literal_context_registration_id_counts"].items()
                }
            )
            definition_body_value_counts.update(
                {
                    int(key): int(value)
                    for key, value in scanned["definition_body_record_value_counts"].items()
                }
            )
            invocation_counts.update(
                {int(key): int(value) for key, value in scanned["literal_invocation_id_counts"].items()}
            )
            rejected_reason_counts.update(scanned["rejected_definition_body_reason_counts"])
            rejected_target_status_counts.update(
                scanned["rejected_definition_body_target_status_counts"]
            )
            for sample in scanned["rejected_definition_body_samples"]:
                if len(rejected_samples) >= MAX_REJECTED_SAMPLES:
                    break
                rejected_samples.append({"entry": entry_name, **sample})
            def26_context_registrations.extend(
                {"entry": entry_name, **registration}
                for registration in scanned["def26_context_registrations"]
            )
            def26_definition_bodies.extend(
                {"entry": entry_name, "source_offset": int(offset)}
                for offset in scanned["def26_definition_body_offsets"]
            )
            def26_invocations.extend(
                {"entry": entry_name, "source_offset": int(offset)}
                for offset in scanned["def26_invocation_offsets"]
            )
    return {
        "schema": SCHEMA,
        "archive_sha256": _sha256_file(archive),
        "summary": summary,
        "literal_context_registration_id_counts": {
            str(key): value for key, value in sorted(context_registration_counts.items())
        },
        "definition_body_record_value_counts": {
            str(key): value for key, value in sorted(definition_body_value_counts.items())
        },
        "literal_invocation_id_counts": {
            str(key): value for key, value in sorted(invocation_counts.items())
        },
        "rejected_definition_body_reason_counts": dict(sorted(rejected_reason_counts.items())),
        "rejected_definition_body_target_status_counts": dict(
            sorted(rejected_target_status_counts.items())
        ),
        "rejected_definition_body_samples": rejected_samples,
        "def26_context_registrations": def26_context_registrations,
        "def26_definition_bodies": def26_definition_bodies,
        "def26_invocations": def26_invocations,
        "scope": "reachable_structural_context_registrations_definition_bodies_and_invocations",
        "execution_semantics": "not_executed_registration_lifetime_unresolved",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result = audit_archive(args.archive)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return
    summary = result["summary"]
    print(
        "MES DEF registry audit: "
        f"entries={summary['decoded_entries']}/{summary['script_entries']} "
        f"context_registrations={summary['literal_context_registration_count']} "
        f"DEF26 context registrations={len(result['def26_context_registrations'])} "
        f"definition_bodies={summary['canonical_definition_body_count']} "
        f"DEF26 invocations={len(result['def26_invocations'])}"
    )
    for invocation in result["def26_invocations"]:
        print(f"  call {invocation['entry']}@0x{invocation['source_offset']:X}")


if __name__ == "__main__":
    main()
