from __future__ import annotations

import argparse
import copy
import hashlib
import json
import struct
from pathlib import Path
from typing import Any

import mes_archive_ir
import mes_basic_block_ir_v6
from payload_values import (
    canonical_payload_bytes,
    fingerprint,
    is_sha256 as _is_sha256,
    sha256_file as _sha256_file,
)


SCHEMA = "kakyu_mes_registered_definition_registry_proof/v1"
ALLOWED_ZERO_START_FALLTHROUGH_COMMANDS = {0x17, 0x1B, 0x1F}
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity",
    "container", "zero_start_path", "registrations", "coverage",
    "invariants", "payload_sha256",
}
SOURCE_IDENTITY_KEYS = {"archive", "archive_sha256", "entry", "entry_sha256"}
CONTAINER_KEYS = {
    "size", "entry_count", "code_offset", "code_size", "entry_sha256",
    "bytecode_sha256", "address_table_sha256",
}
PATH_KEYS = {
    "start", "return_offset", "instruction_count", "instructions", "proof_status",
}
PATH_INSTRUCTION_KEYS = {"start", "end", "command_id", "role", "raw_sha256"}
REGISTRATION_KEYS = {
    "selector", "registration_start", "registration_end",
    "registration_raw_sha256", "selector_start", "selector_end",
    "selector_raw_sha256", "expression_start", "expression_end",
    "expression_raw_sha256", "body_start", "body_end", "body_size",
    "body_raw_sha256", "skip_target", "body_execution", "proof_status",
}
COVERAGE_KEYS = {
    "registration_count", "unique_selector_count", "path_instruction_count",
    "decoded_instruction_count", "excluded_command_10_count",
}
COMPATIBILITY = {
    "policy": "exact_zero_start_command14_registration_path",
    "input_container_schema": "ai5_mes_container/v1",
    "registration_command_id": 20,
    "registration_selector_policy": "one_unambiguous_u8_literal",
    "body_boundary_policy": "instruction_end_through_exclusive_skip_target",
    "body_execution": "not_performed",
    "command_10_policy": "excluded_choice_definition_body_family",
    "registration_lifetime": "unresolved",
    "native_engine_compatibility": "unverified",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_container_hash_bound": True,
    "zero_start_path_instruction_aligned": True,
    "zero_start_path_acyclic": True,
    "zero_start_path_reaches_return": True,
    "selectors_literal_and_unique": True,
    "registration_instruction_hashes_bound": True,
    "body_ranges_nonempty_and_instruction_aligned": True,
    "body_bytes_hash_bound": True,
    "command_10_not_classified_as_registry": True,
    "registered_bodies_not_executed": True,
}


class RegisteredDefinitionRegistryProofError(ValueError):
    pass


def prove_entry(
    payload: bytes,
    source_identity: dict[str, Any],
) -> dict[str, Any]:
    document = _build(payload, source_identity)
    document["payload_sha256"] = fingerprint(document)
    validate(document, payload, source_identity)
    return document


def validate(
    document: dict[str, Any],
    payload: bytes,
    source_identity: dict[str, Any],
) -> dict[str, Any]:
    result = validate_document(document)
    expected = _build(payload, source_identity)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registry projection changed"
        )
    return result


def validate_document(document: dict[str, Any]) -> dict[str, Any]:
    if (
        document.get("ok") is not True
        or document.get("schema") != SCHEMA
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registry proof schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_registered_definition_registry_prover",
        "contract": SCHEMA,
    }:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registry proof producer changed"
        )
    if document.get("compatibility") != COMPATIBILITY:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registry proof compatibility changed"
        )
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registry proof fingerprint changed"
        )
    source = document.get("source_identity")
    if (
        not isinstance(source, dict)
        or set(source) != SOURCE_IDENTITY_KEYS
        or not isinstance(source.get("archive"), str)
        or Path(source["archive"]).name != source["archive"]
        or not isinstance(source.get("entry"), str)
        or Path(source["entry"]).name != source["entry"]
        or not _is_sha256(source.get("archive_sha256"))
        or not _is_sha256(source.get("entry_sha256"))
    ):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registry source identity changed"
        )
    container = document.get("container")
    if (
        not isinstance(container, dict)
        or set(container) != CONTAINER_KEYS
        or any(
            not _is_int(container.get(key)) or int(container[key]) < 0
            for key in ("size", "entry_count", "code_offset", "code_size")
        )
        or any(
            not _is_sha256(container.get(key))
            for key in ("entry_sha256", "bytecode_sha256", "address_table_sha256")
        )
        or container["size"] != container["code_offset"] + container["code_size"]
        or container["entry_sha256"] != source["entry_sha256"]
    ):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registry container changed"
        )
    zero_path = document.get("zero_start_path")
    registrations = document.get("registrations")
    coverage = document.get("coverage")
    if (
        not isinstance(zero_path, dict)
        or set(zero_path) != PATH_KEYS
        or zero_path.get("proof_status")
        != "zero_start_command14_registry_path_reaches_return"
        or not _is_nonnegative_int(zero_path.get("start"))
        or zero_path["start"] != 0
        or not _is_nonnegative_int(zero_path.get("return_offset"))
        or not _is_nonnegative_int(zero_path.get("instruction_count"))
        or not isinstance(zero_path.get("instructions"), list)
        or zero_path["instruction_count"] != len(zero_path["instructions"])
        or not isinstance(registrations, list)
        or not registrations
        or not isinstance(coverage, dict)
        or set(coverage) != COVERAGE_KEYS
        or any(not _is_nonnegative_int(coverage.get(key)) for key in COVERAGE_KEYS)
    ):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registry path or coverage changed"
        )
    by_start: dict[int, dict[str, Any]] = {}
    selectors: list[int] = []
    for row in registrations:
        if not isinstance(row, dict) or set(row) != REGISTRATION_KEYS:
            raise RegisteredDefinitionRegistryProofError(
                "registered-definition registry row fields changed"
            )
        integer_keys = {
            "selector", "registration_start", "registration_end",
            "selector_start", "selector_end", "expression_start",
            "expression_end", "body_start", "body_end", "body_size",
            "skip_target",
        }
        if any(not _is_nonnegative_int(row.get(key)) for key in integer_keys):
            raise RegisteredDefinitionRegistryProofError(
                "registered-definition registry row coordinate changed"
            )
        if (
            row["selector"] > 0x7F
            or row["registration_start"] in by_start
            or row["registration_end"] != row["body_start"]
            or row["body_end"] != row["skip_target"]
            or row["body_size"] != row["body_end"] - row["body_start"]
            or row["body_size"] <= 0
            or not (
                row["registration_start"] < row["selector_start"]
                < row["selector_end"] <= row["expression_end"]
                <= row["registration_end"]
            )
            or row["selector_end"] != row["selector_start"] + 1
            or row["expression_start"] != row["selector_start"]
            or row["expression_end"] != row["selector_end"] + 1
            or any(
                not _is_sha256(row.get(key))
                for key in (
                    "registration_raw_sha256", "selector_raw_sha256",
                    "expression_raw_sha256", "body_raw_sha256",
                )
            )
            or row.get("body_execution") != "not_performed"
            or row.get("proof_status")
            != "literal_command14_registration_with_exact_body_boundary"
        ):
            raise RegisteredDefinitionRegistryProofError(
                "registered-definition registry row boundary changed"
            )
        by_start[row["registration_start"]] = row
        selectors.append(row["selector"])
    if len(selectors) != len(set(selectors)):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registry selectors are not unique"
        )
    path_rows = zero_path["instructions"]
    registration_path_count = 0
    previous: dict[str, Any] | None = None
    for row_index, row in enumerate(path_rows):
        if not isinstance(row, dict) or set(row) != PATH_INSTRUCTION_KEYS:
            raise RegisteredDefinitionRegistryProofError(
                "registered-definition registry path row fields changed"
            )
        if (
            not _is_nonnegative_int(row.get("start"))
            or not _is_nonnegative_int(row.get("end"))
            or not _is_nonnegative_int(row.get("command_id"))
            or row["end"] <= row["start"]
            or not _is_sha256(row.get("raw_sha256"))
        ):
            raise RegisteredDefinitionRegistryProofError(
                "registered-definition registry path row changed"
            )
        if previous is not None:
            expected_start = previous["end"]
            if previous["role"] == "registration":
                expected_start = by_start[previous["start"]]["skip_target"]
            if row["start"] != expected_start:
                raise RegisteredDefinitionRegistryProofError(
                    "registered-definition registry path continuity changed"
                )
        if row["role"] == "registration":
            if row["command_id"] != 0x14 or row["start"] not in by_start:
                raise RegisteredDefinitionRegistryProofError(
                    "registered-definition registry path registration changed"
                )
            registration_path_count += 1
        elif row["role"] == "return":
            if row["command_id"] != 0x00 or row_index != len(path_rows) - 1:
                raise RegisteredDefinitionRegistryProofError(
                    "registered-definition registry path return changed"
                )
        elif (
            row["role"] != "fallthrough"
            or row["command_id"] not in ALLOWED_ZERO_START_FALLTHROUGH_COMMANDS
        ):
            raise RegisteredDefinitionRegistryProofError(
                "registered-definition registry path role changed"
            )
        previous = row
    if (
        not path_rows
        or path_rows[0]["start"] != 0
        or path_rows[-1]["role"] != "return"
        or path_rows[-1]["start"] != zero_path["return_offset"]
        or registration_path_count != len(registrations)
        or coverage["registration_count"] != len(registrations)
        or coverage["unique_selector_count"] != len(set(selectors))
        or coverage["path_instruction_count"] != len(path_rows)
        or coverage["decoded_instruction_count"] < len(path_rows)
    ):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registry aggregate changed"
        )
    if document.get("invariants") != INVARIANTS:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registry invariants changed"
        )
    return {"ok": True, "schema": SCHEMA, "payload_sha256": retained}


def prove_archive(
    archive: Path,
    entry_name: str,
) -> dict[str, Any]:
    archive = archive.resolve()
    payload, loaded = mes_archive_ir.load_archive_entry(archive, entry_name)
    source_identity = {
        "archive": archive.name,
        "archive_sha256": _sha256_file(archive),
        "entry": str(loaded["entry"]),
        "entry_sha256": hashlib.sha256(payload).hexdigest(),
    }
    return prove_entry(payload, source_identity)


def _build(payload: bytes, source_identity: dict[str, Any]) -> dict[str, Any]:
    normalized_source = _source_identity(source_identity, payload)
    if len(payload) < 4:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition source container is truncated"
        )
    entry_count = struct.unpack_from("<I", payload, 0)[0]
    code_offset = 4 + entry_count * 4
    if code_offset > len(payload):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition source address table is truncated"
        )
    code = payload[code_offset:]
    decoded = mes_basic_block_ir_v6.decode_mes(
        payload,
        {
            "archive": normalized_source["archive"],
            "entry": normalized_source["entry"],
            "archive_sha256": normalized_source["archive_sha256"],
        },
    )
    if float(decoded.get("decodedRatio", 0.0)) != 1.0:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition source is not completely decoded"
        )
    instructions = _unique_instructions(decoded)
    registrations: list[dict[str, Any]] = []
    path: list[dict[str, Any]] = []
    seen: set[int] = set()
    cursor = 0
    return_offset = -1
    while True:
        if cursor in seen:
            raise RegisteredDefinitionRegistryProofError(
                "registered-definition zero-start path is cyclic"
            )
        seen.add(cursor)
        instruction = instructions.get(cursor)
        if instruction is None:
            raise RegisteredDefinitionRegistryProofError(
                "registered-definition zero-start path is not instruction aligned"
            )
        command_id = int(instruction.get("commandId", -1))
        start = int(instruction.get("sourceOffset", -1))
        end = int(instruction.get("endOffset", -1))
        raw = _instruction_bytes(code, instruction)
        role = "registration" if command_id == 0x14 else "fallthrough"
        if command_id == 0x00:
            role = "return"
        path.append(
            {
                "start": start,
                "end": end,
                "command_id": command_id,
                "role": role,
                "raw_sha256": hashlib.sha256(raw).hexdigest(),
            }
        )
        if command_id == 0x00:
            return_offset = start
            break
        if command_id == 0x14:
            registration = _registration(code, instruction, instructions)
            registrations.append(registration)
            cursor = int(registration["skip_target"])
            continue
        if command_id not in ALLOWED_ZERO_START_FALLTHROUGH_COMMANDS:
            raise RegisteredDefinitionRegistryProofError(
                "registered-definition zero-start path reached unsupported command "
                f"0x{command_id:02X}"
            )
        cursor = end
    if not registrations:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition zero-start path has no registrations"
        )
    selectors = [int(row["selector"]) for row in registrations]
    if len(selectors) != len(set(selectors)):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition zero-start selectors are not unique"
        )
    command_10_count = sum(
        int(instruction.get("commandId", -1)) == 0x10
        for instruction in instructions.values()
    )
    return {
        "ok": True,
        "schema": SCHEMA,
        "producer": {
            "implementation": "python_phase6_registered_definition_registry_prover",
            "contract": SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": normalized_source,
        "container": {
            "size": len(payload),
            "entry_count": entry_count,
            "code_offset": code_offset,
            "code_size": len(code),
            "entry_sha256": hashlib.sha256(payload).hexdigest(),
            "bytecode_sha256": hashlib.sha256(code).hexdigest(),
            "address_table_sha256": hashlib.sha256(
                payload[4:code_offset]
            ).hexdigest(),
        },
        "zero_start_path": {
            "start": 0,
            "return_offset": return_offset,
            "instruction_count": len(path),
            "instructions": path,
            "proof_status": "zero_start_command14_registry_path_reaches_return",
        },
        "registrations": registrations,
        "coverage": {
            "registration_count": len(registrations),
            "unique_selector_count": len(set(selectors)),
            "path_instruction_count": len(path),
            "decoded_instruction_count": len(instructions),
            "excluded_command_10_count": command_10_count,
        },
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _registration(
    code: bytes,
    instruction: dict[str, Any],
    instructions: dict[int, dict[str, Any]],
) -> dict[str, Any]:
    operands = instruction.get("operands")
    if not isinstance(operands, list) or len(operands) != 2:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition command 0x14 operand shape changed"
        )
    expression_operand, target_operand = operands
    if (
        not isinstance(expression_operand, dict)
        or expression_operand.get("type") != "expression"
        or not isinstance(target_operand, dict)
        or target_operand.get("type") != "code_offset"
    ):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition command 0x14 operand kinds changed"
        )
    expression = expression_operand.get("value")
    ast = expression.get("ast") if isinstance(expression, dict) else None
    if (
        not isinstance(ast, dict)
        or ast.get("type") != "literal"
        or int(ast.get("width", -1)) != 8
        or not isinstance(ast.get("value"), int)
        or not 0 <= int(ast["value"]) <= 0x7F
    ):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition selector is not an unambiguous u8 literal"
        )
    start = int(instruction["sourceOffset"])
    end = int(instruction["endOffset"])
    selector_start = int(ast.get("source", {}).get("offset", -1))
    selector_end = selector_start + 1
    target = int(target_operand.get("value", -1))
    if (
        selector_start < start + 1
        or selector_end > end
        or end >= target
        or target > len(code)
        or end not in instructions
        or (target != len(code) and target not in instructions)
    ):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition body boundary is invalid"
        )
    raw = _instruction_bytes(code, instruction)
    selector_raw = code[selector_start:selector_end]
    expression_start = int(expression.get("offset", -1))
    expression_end = int(expression.get("end_offset", -1))
    expression_raw = code[expression_start:expression_end]
    body = code[end:target]
    if (
        not body
        or selector_raw != bytes([int(ast["value"])])
        or expression_raw != selector_raw + b"\xFF"
        or raw != code[start:end]
    ):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition registration bytes changed"
        )
    return {
        "selector": int(ast["value"]),
        "registration_start": start,
        "registration_end": end,
        "registration_raw_sha256": hashlib.sha256(raw).hexdigest(),
        "selector_start": selector_start,
        "selector_end": selector_end,
        "selector_raw_sha256": hashlib.sha256(selector_raw).hexdigest(),
        "expression_start": expression_start,
        "expression_end": expression_end,
        "expression_raw_sha256": hashlib.sha256(expression_raw).hexdigest(),
        "body_start": end,
        "body_end": target,
        "body_size": len(body),
        "body_raw_sha256": hashlib.sha256(body).hexdigest(),
        "skip_target": target,
        "body_execution": "not_performed",
        "proof_status": "literal_command14_registration_with_exact_body_boundary",
    }


def _unique_instructions(document: dict[str, Any]) -> dict[int, dict[str, Any]]:
    retained: dict[int, dict[str, Any]] = {}
    for node in document.get("nodes", []):
        if not isinstance(node, dict):
            continue
        for instruction in node.get("instructions", []):
            if not isinstance(instruction, dict):
                continue
            offset = int(instruction.get("sourceOffset", -1))
            if offset < 0:
                continue
            previous = retained.get(offset)
            if previous is not None and previous != instruction:
                raise RegisteredDefinitionRegistryProofError(
                    "registered-definition source has conflicting instruction decodes"
                )
            retained[offset] = instruction
    if not retained:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition source has no decoded instructions"
        )
    return retained


def _instruction_bytes(code: bytes, instruction: dict[str, Any]) -> bytes:
    start = int(instruction.get("sourceOffset", -1))
    end = int(instruction.get("endOffset", -1))
    raw_hex = instruction.get("rawHex")
    if start < 0 or end <= start or end > len(code) or not isinstance(raw_hex, str):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition instruction boundary changed"
        )
    try:
        raw = bytes.fromhex(raw_hex)
    except ValueError as error:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition instruction bytes are invalid"
        ) from error
    if raw != code[start:end]:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition instruction bytes disagree with source"
        )
    return raw


def _source_identity(
    source_identity: dict[str, Any],
    payload: bytes,
) -> dict[str, Any]:
    required = {"archive", "archive_sha256", "entry", "entry_sha256"}
    if set(source_identity) != required:
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition source identity fields changed"
        )
    normalized = {key: str(source_identity[key]) for key in required}
    if (
        not normalized["archive"]
        or Path(normalized["archive"]).name != normalized["archive"]
        or not normalized["entry"]
        or Path(normalized["entry"]).name != normalized["entry"]
        or not _is_sha256(normalized["archive_sha256"])
        or not _is_sha256(normalized["entry_sha256"])
        or hashlib.sha256(payload).hexdigest() != normalized["entry_sha256"]
    ):
        raise RegisteredDefinitionRegistryProofError(
            "registered-definition source identity changed"
        )
    return normalized


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _is_nonnegative_int(value: Any) -> bool:
    return _is_int(value) and value >= 0


def _write_new_json(path: Path, document: dict[str, Any]) -> None:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as target:
        json.dump(
            document,
            target,
            ensure_ascii=False,
            allow_nan=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        target.write("\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Prove the literal command-0x14 registered-definition registry and "
            "exact body boundaries reached by one MES zero-start path."
        )
    )
    parser.add_argument("archive", type=Path)
    parser.add_argument("entry")
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    document = prove_archive(arguments.archive, arguments.entry)
    _write_new_json(arguments.output, document)
    print(
        "MES_REGISTERED_DEFINITION_REGISTRY_PROOF_PASS "
        f"schema={SCHEMA} entry={document['source_identity']['entry']} "
        f"registrations={document['coverage']['registration_count']} "
        f"selectors={','.join(str(row['selector']) for row in document['registrations'])} "
        f"return=0x{document['zero_start_path']['return_offset']:X} "
        f"payload_sha256={document['payload_sha256']} source_unchanged=true"
    )


if __name__ == "__main__":
    main()
