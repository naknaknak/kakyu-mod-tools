from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


PLAN_SCHEMA = "kakyu_mes_inline_script_name_edit_plan/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "operation", "target", "replacement", "assembly_ready", "invariants",
    "payload_sha256",
}
OPERATION_KEYS = {
    "kind", "source_offset", "owner_raw_sha256", "reference_id", "name",
}
TARGET_KEYS = {
    "node_id", "region_id", "owner_kind", "owner_start", "owner_end",
    "owner_raw_sha256", "op", "command_id", "envelope_start", "envelope_end",
    "envelope_raw_hex", "envelope_raw_sha256", "reference_id",
    "reference_boundary", "resource_kind", "archive_candidates", "source_name",
    "normalized_name", "extension", "execution_selector", "execution_role",
    "native_context_restore", "tool_execution_semantics", "name_start",
    "name_end", "name_raw_hex", "name_raw_sha256", "prefix_raw_hex",
    "prefix_raw_sha256", "suffix_raw_hex", "suffix_raw_sha256",
}
REPLACEMENT_KEYS = {
    "source_name", "normalized_name", "extension", "name_raw_hex",
    "name_raw_sha256", "envelope_raw_hex", "envelope_raw_sha256",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}
NATIVE_SEMANTICS = "archive_entry_load_inline_execute_restore_confirmed"
SUPPORTED_SELECTORS = {
    2: {"extension": "lib", "role": "library_bootstrap"},
    3: {"extension": "mes", "role": "definition_bootstrap"},
}
COMPATIBILITY = {
    "policy": "planning_only_same_length_bounded_inline_script_name_replacement",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
    "supported_operation": "replace_inline_script_name",
    "supported_selectors": {
        str(selector): copy.deepcopy(row)
        for selector, row in SUPPORTED_SELECTORS.items()
    },
    "selection_policy": "one_exact_indexed_inline_script_reference",
    "boundary_policy": "typed_instruction_or_bounded_envelope_inside_one_opaque_owner",
    "name_policy": "printable_ascii_safe_entry_name_and_selector_extension",
    "length_policy": "replacement_name_must_match_source_byte_length",
    "context_policy": "preserve_selector_role_restore_and_all_non_name_bytes",
    "resource_existence": "not_checked",
    "binary_publication": "forbidden",
    "native_engine_compatibility": "unverified",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "target_owner_unique_and_source_bound": True,
    "indexed_reference_exact": True,
    "inline_envelope_exact_and_bounded": True,
    "selector_role_and_extension_matched": True,
    "replacement_name_same_length": True,
    "owner_bytes_outside_name_unchanged": True,
    "opaque_owner_boundary_preserved": True,
    "binary_not_published": True,
}


class InlineScriptNameEditPlanError(ValueError):
    pass


def plan(
    editable_document: dict[str, Any], operation: dict[str, Any]
) -> dict[str, Any]:
    result = _build_plan(editable_document, operation)
    result["payload_sha256"] = fingerprint(result)
    validate(result, editable_document)
    return result


def validate(
    document: dict[str, Any], editable_document: dict[str, Any] | None = None
) -> dict[str, Any]:
    if (
        document.get("ok") is not True
        or document.get("schema") != PLAN_SCHEMA
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit plan schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_inline_script_name_edit_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit plan producer changed"
        )
    if document.get("compatibility") != COMPATIBILITY:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit compatibility changed"
        )
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit plan fingerprint changed"
        )
    operation = document.get("operation")
    if not isinstance(operation, dict) or set(operation) != OPERATION_KEYS:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit operation fields changed"
        )
    operation = _validate_operation(operation)
    source_identity = document.get("source_identity")
    if (
        not isinstance(source_identity, dict)
        or not set(source_identity).issubset(SOURCE_IDENTITY_KEYS)
        or not _is_safe_entry_name(source_identity.get("archive"))
        or not _is_safe_entry_name(source_identity.get("entry"))
        or (
            "archive_sha256" in source_identity
            and not _is_sha256(source_identity["archive_sha256"])
        )
    ):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit source identity changed"
        )
    inputs = document.get("inputs")
    if (
        not isinstance(inputs, dict)
        or set(inputs) != {"editable_ir_sha256", "decompiler_ir_sha256"}
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit input identity changed"
        )
    target = document.get("target")
    replacement = document.get("replacement")
    if not isinstance(target, dict) or set(target) != TARGET_KEYS:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit target fields changed"
        )
    if not isinstance(replacement, dict) or set(replacement) != REPLACEMENT_KEYS:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit replacement fields changed"
        )
    if (
        target.get("node_id") == ""
        or target.get("region_id") == ""
        or target.get("op") != "inline_script_execution"
        or target.get("command_id") != 0x0D
        or target.get("owner_raw_sha256") != operation["owner_raw_sha256"]
        or target.get("reference_id") != operation["reference_id"]
        or target.get("envelope_start") != operation["source_offset"]
        or replacement.get("source_name") != operation["name"]
    ):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit target identity changed"
        )
    _validate_plan_bytes(target, replacement)
    if document.get("assembly_ready") is not True:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit plan is not assembly ready"
        )
    if document.get("invariants") != INVARIANTS:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit invariants changed"
        )
    if editable_document is not None:
        expected = _build_plan(editable_document, copy.deepcopy(operation))
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise InlineScriptNameEditPlanError(
                "MES inline script name edit plan differs from its source"
            )
    return {"ok": True, "schema": PLAN_SCHEMA, "payload_sha256": retained}


def _build_plan(
    editable_document: dict[str, Any], raw_operation: dict[str, Any]
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    operation = _validate_operation(raw_operation)
    source_ir = editable_document["source_ir"]
    reference = _indexed_reference(source_ir, operation)
    owner = _unique_owner(source_ir, operation)
    source = owner["source"]
    owner_raw = _hex_bytes(source.get("raw_hex"), "owner source")
    if hashlib.sha256(owner_raw).hexdigest() != operation["owner_raw_sha256"]:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit owner source hash is stale"
        )
    owner_start = int(source["start"])
    owner_end = int(source["end"])
    if owner_end - owner_start != len(owner_raw):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit owner boundary changed"
        )
    parsed = _parse_envelope(owner_raw, owner_start, operation["source_offset"])
    selector = int(parsed["execution_selector"])
    form = SUPPORTED_SELECTORS[selector]
    source_name = str(parsed["source_name"])
    normalized_name = source_name.upper()
    if (
        reference.get("boundary")
        != ("strict_indexed" if owner["kind"] == "statement" else "bounded_envelope_scan")
        or reference.get("source_name") != source_name
        or reference.get("name") != normalized_name
        or reference.get("execution_selector") != selector
        or reference.get("execution_role") != form["role"]
    ):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit reference and owner boundary differ"
        )
    if owner["kind"] == "statement":
        statement = owner.get("statement", {})
        if (
            statement.get("kind") != "instruction"
            or statement.get("op") != "inline_script_execution"
            or statement.get("command_id") != 0x0D
            or owner_start != operation["source_offset"]
            or owner_end != parsed["envelope_end"]
        ):
            raise InlineScriptNameEditPlanError(
                "MES inline script name edit typed owner changed"
            )
    elif owner["kind"] != "opaque":
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit owner kind is unsupported"
        )
    replacement_raw = _encode_replacement(
        operation["name"], form["extension"], len(parsed["name_raw"])
    )
    replacement_envelope = parsed["prefix"] + replacement_raw + parsed["suffix"]
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_inline_script_name_edit_planner",
            "contract": PLAN_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
        },
        "operation": copy.deepcopy(operation),
        "target": {
            "node_id": str(owner["id"]),
            "region_id": str(source["region"]),
            "owner_kind": str(owner["kind"]),
            "owner_start": owner_start,
            "owner_end": owner_end,
            "owner_raw_sha256": hashlib.sha256(owner_raw).hexdigest(),
            "op": "inline_script_execution",
            "command_id": 0x0D,
            "envelope_start": int(parsed["envelope_start"]),
            "envelope_end": int(parsed["envelope_end"]),
            "envelope_raw_hex": parsed["envelope"].hex(),
            "envelope_raw_sha256": hashlib.sha256(parsed["envelope"]).hexdigest(),
            "reference_id": operation["reference_id"],
            "reference_boundary": str(reference["boundary"]),
            "resource_kind": "mes_script",
            "archive_candidates": ["mes.arc"],
            "source_name": source_name,
            "normalized_name": normalized_name,
            "extension": form["extension"],
            "execution_selector": selector,
            "execution_role": form["role"],
            "native_context_restore": "confirmed",
            "tool_execution_semantics": "not_executed",
            "name_start": int(parsed["name_start"]),
            "name_end": int(parsed["name_end"]),
            "name_raw_hex": parsed["name_raw"].hex(),
            "name_raw_sha256": hashlib.sha256(parsed["name_raw"]).hexdigest(),
            "prefix_raw_hex": parsed["prefix"].hex(),
            "prefix_raw_sha256": hashlib.sha256(parsed["prefix"]).hexdigest(),
            "suffix_raw_hex": parsed["suffix"].hex(),
            "suffix_raw_sha256": hashlib.sha256(parsed["suffix"]).hexdigest(),
        },
        "replacement": {
            "source_name": operation["name"],
            "normalized_name": operation["name"].upper(),
            "extension": form["extension"],
            "name_raw_hex": replacement_raw.hex(),
            "name_raw_sha256": hashlib.sha256(replacement_raw).hexdigest(),
            "envelope_raw_hex": replacement_envelope.hex(),
            "envelope_raw_sha256": hashlib.sha256(replacement_envelope).hexdigest(),
        },
        "assembly_ready": True,
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _indexed_reference(
    source_ir: dict[str, Any], operation: dict[str, Any]
) -> dict[str, Any]:
    references = source_ir.get("references")
    if not isinstance(references, list):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit reference index changed"
        )
    matches = [
        row for row in references
        if isinstance(row, dict)
        and row.get("id") == operation["reference_id"]
        and row.get("kind") == "resource"
    ]
    if len(matches) != 1:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit has no unique indexed reference"
        )
    value = matches[0].get("value")
    if (
        matches[0].get("source_offset") != operation["source_offset"]
        or not isinstance(value, dict)
        or value.get("source_offset") != operation["source_offset"]
        or value.get("op") != "inline_script_execution"
        or value.get("resource_kind") != "mes_script"
        or value.get("archive_candidates") != ["mes.arc"]
        or value.get("boundary") not in ["strict_indexed", "bounded_envelope_scan"]
        or value.get("presentation_subcommand") != 8
        or value.get("native_semantics") != NATIVE_SEMANTICS
        or value.get("native_context_restore") != "confirmed"
        or value.get("tool_execution_semantics") != "not_executed"
    ):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit indexed reference changed"
        )
    selector = value.get("execution_selector")
    if not _is_int(selector) or selector not in SUPPORTED_SELECTORS:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit selector changed"
        )
    return value


def _unique_owner(
    source_ir: dict[str, Any], operation: dict[str, Any]
) -> dict[str, Any]:
    nodes = source_ir.get("nodes")
    if not isinstance(nodes, list):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit node index changed"
        )
    matches = []
    for node in nodes:
        if not isinstance(node, dict):
            continue
        source = node.get("source")
        if (
            not isinstance(source, dict)
            or operation["reference_id"] not in node.get("reference_ids", [])
            or not _is_int(source.get("start"))
            or not _is_int(source.get("end"))
            or not int(source["start"]) <= operation["source_offset"] < int(source["end"])
        ):
            continue
        matches.append(node)
    if len(matches) != 1:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit target has no unique owner"
        )
    return matches[0]


def _parse_envelope(owner: bytes, owner_start: int, envelope_start: int) -> dict[str, Any]:
    relative = envelope_start - owner_start
    if relative < 0 or relative + 9 > len(owner):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit envelope is outside its owner"
        )
    if owner[relative:relative + 4] != bytes.fromhex("0d08ff02"):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit envelope prefix changed"
        )
    selector = owner[relative + 4]
    if selector not in SUPPORTED_SELECTORS or owner[relative + 5:relative + 7] != b"\xff\x01":
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit selector envelope changed"
        )
    name_relative_start = relative + 7
    cursor = name_relative_start
    while cursor < len(owner) and cursor - name_relative_start <= 255 and owner[cursor] != 0:
        if owner[cursor] < 0x20 or owner[cursor] > 0x7E:
            raise InlineScriptNameEditPlanError(
                "MES inline script name edit source name is not printable ASCII"
            )
        cursor += 1
    if cursor + 1 >= len(owner) or owner[cursor:cursor + 2] != b"\x00\x00":
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit envelope terminator changed"
        )
    name_raw = owner[name_relative_start:cursor]
    source_name = _ascii_name(name_raw, "source")
    form = SUPPORTED_SELECTORS[selector]
    if _extension(source_name) != form["extension"]:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit source extension does not match selector"
        )
    envelope_relative_end = cursor + 2
    prefix = owner[relative:name_relative_start]
    suffix = owner[cursor:envelope_relative_end]
    return {
        "execution_selector": selector,
        "source_name": source_name,
        "envelope_start": envelope_start,
        "envelope_end": owner_start + envelope_relative_end,
        "name_start": owner_start + name_relative_start,
        "name_end": owner_start + cursor,
        "name_raw": name_raw,
        "prefix": prefix,
        "suffix": suffix,
        "envelope": owner[relative:envelope_relative_end],
    }


def _validate_plan_bytes(
    target: dict[str, Any], replacement: dict[str, Any]
) -> None:
    for key in (
        "owner_start", "owner_end", "envelope_start", "envelope_end",
        "name_start", "name_end", "command_id", "execution_selector",
    ):
        if not _is_int(target.get(key)) or int(target[key]) < 0:
            raise InlineScriptNameEditPlanError(
                "MES inline script name edit target coordinate changed"
            )
    selector = int(target["execution_selector"])
    form = SUPPORTED_SELECTORS.get(selector)
    expected_boundary = (
        "strict_indexed" if target.get("owner_kind") == "statement"
        else "bounded_envelope_scan" if target.get("owner_kind") == "opaque"
        else ""
    )
    if (
        form is None
        or target.get("reference_boundary") != expected_boundary
        or target.get("resource_kind") != "mes_script"
        or target.get("archive_candidates") != ["mes.arc"]
        or target.get("execution_role") != form["role"]
        or target.get("extension") != form["extension"]
        or target.get("native_context_restore") != "confirmed"
        or target.get("tool_execution_semantics") != "not_executed"
    ):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit selector or boundary changed"
        )
    envelope = _hex_bytes(target.get("envelope_raw_hex"), "source envelope")
    name = _hex_bytes(target.get("name_raw_hex"), "source name")
    prefix = _hex_bytes(target.get("prefix_raw_hex"), "source prefix")
    suffix = _hex_bytes(target.get("suffix_raw_hex"), "source suffix")
    replacement_name = _hex_bytes(replacement.get("name_raw_hex"), "replacement name")
    replacement_envelope = _hex_bytes(
        replacement.get("envelope_raw_hex"), "replacement envelope"
    )
    for row, raw, key in (
        (target, envelope, "envelope_raw_sha256"),
        (target, name, "name_raw_sha256"),
        (target, prefix, "prefix_raw_sha256"),
        (target, suffix, "suffix_raw_sha256"),
        (replacement, replacement_name, "name_raw_sha256"),
        (replacement, replacement_envelope, "envelope_raw_sha256"),
    ):
        if row.get(key) != hashlib.sha256(raw).hexdigest():
            raise InlineScriptNameEditPlanError(
                "MES inline script name edit planned hash changed"
            )
    envelope_start = int(target["envelope_start"])
    envelope_end = int(target["envelope_end"])
    name_start = int(target["name_start"])
    name_end = int(target["name_end"])
    expected_prefix = bytes.fromhex(f"0d08ff02{selector:02x}ff01")
    if (
        int(target["owner_end"]) <= int(target["owner_start"])
        or envelope_start < int(target["owner_start"])
        or envelope_end > int(target["owner_end"])
        or envelope_end <= envelope_start
        or name_start != envelope_start + len(prefix)
        or name_end != name_start + len(name)
        or envelope_end != name_end + len(suffix)
        or envelope != prefix + name + suffix
        or replacement_envelope != prefix + replacement_name + suffix
        or len(name) != len(replacement_name)
        or len(envelope) != len(replacement_envelope)
        or prefix != expected_prefix
        or suffix != b"\x00\x00"
    ):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit planned envelope boundary changed"
        )
    source_name = _ascii_name(name, "source")
    output_name = _ascii_name(replacement_name, "replacement")
    if (
        source_name != target.get("source_name")
        or source_name.upper() != target.get("normalized_name")
        or output_name != replacement.get("source_name")
        or output_name.upper() != replacement.get("normalized_name")
        or _extension(source_name) != form["extension"]
        or _extension(output_name) != form["extension"]
        or replacement.get("extension") != form["extension"]
    ):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit planned name changed"
        )


def _validate_operation(raw: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(raw, dict) or set(raw) != OPERATION_KEYS:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit operation fields changed"
        )
    if raw.get("kind") != "replace_inline_script_name":
        raise InlineScriptNameEditPlanError(
            "unsupported MES inline script name edit operation"
        )
    if not _is_int(raw.get("source_offset")) or int(raw["source_offset"]) < 0:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit source offset is invalid"
        )
    if not _is_sha256(raw.get("owner_raw_sha256")):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit owner hash is invalid"
        )
    if not isinstance(raw.get("reference_id"), str) or not raw["reference_id"]:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit reference id is invalid"
        )
    if not _is_safe_entry_name(raw.get("name")):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit replacement name is invalid"
        )
    return copy.deepcopy(raw)


def _encode_replacement(name: str, extension: str, source_length: int) -> bytes:
    if not _is_safe_entry_name(name) or _extension(name) != extension:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit replacement extension or name is invalid"
        )
    raw = name.encode("ascii")
    if len(raw) != source_length:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit replacement changes name length"
        )
    return raw


def _extension(name: str) -> str:
    return name.rsplit(".", 1)[1].lower() if "." in name else ""


def _ascii_name(raw: bytes, label: str) -> str:
    try:
        value = raw.decode("ascii")
    except UnicodeDecodeError as error:
        raise InlineScriptNameEditPlanError(
            f"MES inline script name edit {label} name is not ASCII"
        ) from error
    if not _is_safe_entry_name(value):
        raise InlineScriptNameEditPlanError(
            f"MES inline script name edit {label} name is unsafe"
        )
    return value


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str) or not value or len(value) % 2 != 0:
        raise InlineScriptNameEditPlanError(
            f"MES inline script name edit {label} bytes are invalid"
        )
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise InlineScriptNameEditPlanError(
            f"MES inline script name edit {label} bytes are invalid"
        ) from error


def _is_safe_entry_name(value: Any) -> bool:
    return (
        isinstance(value, str)
        and bool(value)
        and value not in {".", ".."}
        and "/" not in value
        and "\\" not in value
        and ":" not in value
        and len(value.encode("ascii", errors="ignore")) == len(value)
        and all(0x20 <= byte <= 0x7E for byte in value.encode("ascii"))
    )


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build a fail-closed JSON plan for one same-length name inside an "
            "indexed MES inline script execution envelope. This tool never "
            "publishes MES bytes."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if len({args.editable_ir.resolve(), args.operation.resolve(), args.output.resolve()}) != 3:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit paths must be distinct"
        )
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        operation = json.loads(args.operation.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit input could not be read"
        ) from error
    if not isinstance(editable_document, dict) or not isinstance(operation, dict):
        raise InlineScriptNameEditPlanError(
            "MES inline script name edit input is not an object"
        )
    document = plan(editable_document, operation)
    payload = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8") + b"\n"
    editable_ir.publish_new(args.output, payload)
    print(
        "MES_INLINE_SCRIPT_NAME_EDIT_PLAN_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_identity'].get('entry', '')} "
        f"offset={document['target']['envelope_start']} "
        f"selector={document['target']['execution_selector']} "
        f"boundary={document['target']['reference_boundary']} "
        f"name={document['target']['source_name']} "
        f"replacement={document['replacement']['source_name']} "
        "mes_bytes=false "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
