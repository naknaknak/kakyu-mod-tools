"""Portable authored operations; reconstruct local evidence from matching originals.

No ARC, complete MES, original text, handoff, or opaque payload enters a delta.
Version 9 carries an ORDERED SEQUENCE of one or more state, condition-literal,
resource-name, choice-option, registered-definition call, shared-routine
call, control-target retarget or relocated message edits (a relocation only
last) plus UTF-8 overrides, and names the original entries a reconstruction
needs beside the source. `build`/`reconstruct` need no new inputs for a
control-target edit; it has no dependency.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import tempfile
from typing import Any

import mes_authoring_workflow as workflow
import payload_values

SCHEMA = "kakyu_authored_mod_delta/v9"
LEGACY_SCHEMA = "kakyu_authored_mod_delta/v1"
LEGACY_SCHEMA_V2 = "kakyu_authored_mod_delta/v2"
LEGACY_SCHEMA_V3 = "kakyu_authored_mod_delta/v3"
LEGACY_SCHEMA_V4 = "kakyu_authored_mod_delta/v4"
LEGACY_SCHEMA_V5 = "kakyu_authored_mod_delta/v5"
LEGACY_SCHEMA_V6 = "kakyu_authored_mod_delta/v6"
LEGACY_SCHEMA_V7 = "kakyu_authored_mod_delta/v7"
LEGACY_SCHEMA_V8 = "kakyu_authored_mod_delta/v8"
KEYS = {"schema", "source", "source_entry_sha256", "operation", "output_entry_sha256",
        "semantic_diff_sha256", "text_edits", "compatibility", "payload_sha256"}
KEYS_V6 = KEYS | {"dependencies"}
KEYS_V9 = (KEYS_V6 - {"operation"}) | {"operations"}
SCHEMAS_WITH_DEPENDENCIES = (SCHEMA, LEGACY_SCHEMA_V8, LEGACY_SCHEMA_V7, LEGACY_SCHEMA_V6)
OP_KEYS = {"kind", "source_offset", "instruction_raw_sha256", "pair_index", "value"}
CONDITION_OP_KEYS = {"kind", "source_offset", "instruction_raw_sha256", "literal_offset", "value"}
RESOURCE_OP_KEYS = {"kind", "source_offset", "instruction_raw_sha256", "reference_id", "name"}
CHOICE_OP_KEYS = {"kind", "group_selector", "definition_id", "source_payload_sha256", "text", "encoding"}
CALL_OP_KEYS = {"kind", "source_offset", "instruction_raw_sha256", "selector"}
SHARED_CALL_OP_KEYS = {"kind", "source_offset", "instruction_raw_sha256", "routine_id"}
CONTROL_TARGET_OP_KEYS = {"kind", "source_offset", "reference_kind", "source_instruction_raw_sha256",
                          "replacement_target_offset", "replacement_target_instruction_raw_sha256"}
DEPENDENCY_KEYS = {"entry", "entry_sha256"}
COMPATIBILITY = {"target": "remake_only", "minimum_core": "0.329.0", "maximum_exclusive": "1.0.0"}
LEGACY_COMPATIBILITY = dict(COMPATIBILITY, minimum_core="0.303.0")
LEGACY_COMPATIBILITY_V2 = dict(COMPATIBILITY, minimum_core="0.304.0")
LEGACY_COMPATIBILITY_V3 = dict(COMPATIBILITY, minimum_core="0.322.0")
LEGACY_COMPATIBILITY_V4 = dict(COMPATIBILITY, minimum_core="0.324.0")
LEGACY_COMPATIBILITY_V5 = dict(COMPATIBILITY, minimum_core="0.325.0")
LEGACY_COMPATIBILITY_V6 = dict(COMPATIBILITY, minimum_core="0.326.0")
LEGACY_COMPATIBILITY_V7 = dict(COMPATIBILITY, minimum_core="0.327.0")
LEGACY_COMPATIBILITY_V8 = dict(COMPATIBILITY, minimum_core="0.328.0")
LEGACY = {LEGACY_SCHEMA: LEGACY_COMPATIBILITY, LEGACY_SCHEMA_V2: LEGACY_COMPATIBILITY_V2,
          LEGACY_SCHEMA_V3: LEGACY_COMPATIBILITY_V3, LEGACY_SCHEMA_V4: LEGACY_COMPATIBILITY_V4,
          LEGACY_SCHEMA_V5: LEGACY_COMPATIBILITY_V5, LEGACY_SCHEMA_V6: LEGACY_COMPATIBILITY_V6,
          LEGACY_SCHEMA_V7: LEGACY_COMPATIBILITY_V7, LEGACY_SCHEMA_V8: LEGACY_COMPATIBILITY_V8}
_V8_KINDS = {
    "replace_state_write_literal", "replace_message", "replace_condition_literal",
    "replace_resource_name", "replace_choice_option_cp932_same_length",
    "replace_registered_definition_literal", "replace_shared_routine_literal",
    "retarget_control_flow",
}
ALLOWED_KINDS = {
    LEGACY_SCHEMA: {"replace_state_write_literal"},
    LEGACY_SCHEMA_V2: {"replace_state_write_literal", "replace_message"},
    LEGACY_SCHEMA_V3: {
        "replace_state_write_literal", "replace_message", "replace_condition_literal",
    },
    LEGACY_SCHEMA_V4: {
        "replace_state_write_literal", "replace_message", "replace_condition_literal",
        "replace_resource_name",
    },
    LEGACY_SCHEMA_V5: {
        "replace_state_write_literal", "replace_message", "replace_condition_literal",
        "replace_resource_name", "replace_choice_option_cp932_same_length",
    },
    LEGACY_SCHEMA_V6: {
        "replace_state_write_literal", "replace_message", "replace_condition_literal",
        "replace_resource_name", "replace_choice_option_cp932_same_length",
        "replace_registered_definition_literal",
    },
    LEGACY_SCHEMA_V7: {
        "replace_state_write_literal", "replace_message", "replace_condition_literal",
        "replace_resource_name", "replace_choice_option_cp932_same_length",
        "replace_registered_definition_literal", "replace_shared_routine_literal",
    },
    LEGACY_SCHEMA_V8: _V8_KINDS,
    SCHEMA: _V8_KINDS,
}


def fingerprint(document: dict[str, Any]) -> str:
    return workflow._sha(workflow._json({k: v for k, v in document.items() if k != "payload_sha256"}))


def _hash(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value)


def _validate_operation(op: Any, schema: str) -> None:
    kind = op.get("kind") if isinstance(op, dict) else None
    if kind not in ALLOWED_KINDS.get(schema, frozenset()):
        raise ValueError("Delta operation is unsupported or invalid")
    if kind == "replace_message":
        workflow.message_planner._validate_operation(op)
        workflow.message_planner._validate_native_double_byte_stream(workflow.message_planner._encode_replacement(op["text"]))
    elif kind == "replace_condition_literal":
        if (set(op) != CONDITION_OP_KEYS or not _hash(op["instruction_raw_sha256"])
                or any(type(op[k]) is not int for k in ("source_offset", "literal_offset", "value"))
                or min(op["source_offset"], op["literal_offset"], op["value"]) < 0):
            raise ValueError("Delta operation is unsupported or invalid")
    elif kind == "replace_resource_name":
        if (set(op) != RESOURCE_OP_KEYS or not _hash(op["instruction_raw_sha256"])
                or type(op["source_offset"]) is not int or op["source_offset"] < 0
                or not isinstance(op["reference_id"], str) or not op["reference_id"]
                or not workflow.resource_planner._is_safe_entry_name(op.get("name"))):
            raise ValueError("Delta operation is unsupported or invalid")
    elif kind == "replace_choice_option_cp932_same_length":
        if (set(op) != CHOICE_OP_KEYS or not _hash(op["source_payload_sha256"])
                or any(type(op[k]) is not int or op[k] < 0 for k in ("group_selector", "definition_id"))
                or not isinstance(op["text"], str) or not op["text"]
                or op["encoding"] != "cp932"):
            raise ValueError("Delta operation is unsupported or invalid")
    elif kind == "replace_registered_definition_literal":
        if (set(op) != CALL_OP_KEYS or not _hash(op["instruction_raw_sha256"])
                or type(op["source_offset"]) is not int or op["source_offset"] < 0
                or type(op["selector"]) is not int or not 0 <= op["selector"] < 256):
            raise ValueError("Delta operation is unsupported or invalid")
    elif kind == "replace_shared_routine_literal":
        if (set(op) != SHARED_CALL_OP_KEYS or not _hash(op["instruction_raw_sha256"])
                or type(op["source_offset"]) is not int or op["source_offset"] < 0
                or type(op["routine_id"]) is not int or not 0 <= op["routine_id"] < 256):
            raise ValueError("Delta operation is unsupported or invalid")
    elif kind == "retarget_control_flow":
        if (set(op) != CONTROL_TARGET_OP_KEYS
                or not _hash(op["source_instruction_raw_sha256"])
                or not _hash(op["replacement_target_instruction_raw_sha256"])
                or type(op["source_offset"]) is not int or op["source_offset"] < 0
                or type(op["replacement_target_offset"]) is not int or op["replacement_target_offset"] < 0
                or op["reference_kind"] not in workflow.target_edit_planner.SUPPORTED_FORMS):
            raise ValueError("Delta operation is unsupported or invalid")
    elif (not isinstance(op, dict) or set(op) != OP_KEYS or op["kind"] != "replace_state_write_literal"
            or not _hash(op["instruction_raw_sha256"])
            or any(type(op[k]) is not int for k in ("source_offset", "pair_index", "value"))
            or min(op["source_offset"], op["pair_index"]) < 0):
        raise ValueError("Delta operation is unsupported or invalid")


def _required_dependency_entries(operations: list[Any]) -> set[str]:
    entries: set[str] = set()
    for op in operations:
        kind = op.get("kind") if isinstance(op, dict) else None
        if kind == "replace_registered_definition_literal":
            entries.add("DEF_MAIN.MES")
        elif kind == "replace_shared_routine_literal":
            entries.add("LIBLARY.LIB")
    return entries


def validate(document: dict[str, Any]) -> None:
    if not isinstance(document, dict) or document.get("schema") not in (SCHEMA,) + tuple(LEGACY):
        raise ValueError("Delta schema or fields changed")
    schema = document["schema"]
    is_v9 = schema == SCHEMA
    if is_v9:
        expected_keys = KEYS_V9
    elif schema in SCHEMAS_WITH_DEPENDENCIES:
        expected_keys = KEYS_V6
    else:
        expected_keys = KEYS
    if set(document) != expected_keys:
        raise ValueError("Delta schema or fields changed")
    workflow._source(document["source"])
    if document["compatibility"] != LEGACY.get(schema, COMPATIBILITY):
        raise ValueError("Delta compatibility requirement is unsupported")
    for key in ("source_entry_sha256", "output_entry_sha256", "semantic_diff_sha256", "payload_sha256"):
        if not _hash(document[key]):
            raise ValueError("Delta fingerprint is invalid")
    if fingerprint(document) != document["payload_sha256"]:
        raise ValueError("Delta payload changed")
    if is_v9:
        operations = document["operations"]
        if not isinstance(operations, list) or not operations:
            raise ValueError("Delta operations must be a non-empty array")
        for index, op in enumerate(operations, start=1):
            _validate_operation(op, schema)
            kind = op.get("kind") if isinstance(op, dict) else None
            if kind == "replace_message" and index != len(operations):
                raise ValueError("A message relocation must be the last operation of a sequence")
    else:
        operations = [document["operation"]]
        _validate_operation(operations[0], schema)
    if schema in SCHEMAS_WITH_DEPENDENCIES:
        dependencies = document["dependencies"]
        if not isinstance(dependencies, list):
            raise ValueError("Delta dependencies must be an array")
        previous_entry = ""
        for row in dependencies:
            if (not isinstance(row, dict) or set(row) != DEPENDENCY_KEYS
                    or not workflow.resource_planner._is_safe_entry_name(row.get("entry"))
                    or not _hash(row.get("entry_sha256"))
                    or row["entry"] <= previous_entry):
                raise ValueError("Delta dependency is invalid")
            previous_entry = row["entry"]
        expected_dependency_count = len(_required_dependency_entries(operations))
        if len(dependencies) != expected_dependency_count:
            raise ValueError("Delta dependency count does not match its operation kind")
    message_offsets = {
        op["source_offset"] for op in operations
        if isinstance(op, dict) and op.get("kind") == "replace_message" and "source_offset" in op
    }
    validate_text_edits(document["text_edits"], message_offsets)


def validate_text_edits(edits: Any, message_offsets: Any = frozenset()) -> None:
    """The text-edit rules of a delta, shared with the mod bundle's translation-only
    rows (WD-10): an array of `{source_offset, raw_sha256, text}` with strictly
    increasing offsets, no NUL, UTF-8 text, and no offset equal to one of
    `message_offsets` (the source offsets of the delta's relocated messages)."""
    if not isinstance(edits, list):
        raise ValueError("Delta text edits must be an array")
    previous = -1
    for edit in edits:
        if (not isinstance(edit, dict) or set(edit) != {"source_offset", "raw_sha256", "text"}
                or type(edit["source_offset"]) is not int or edit["source_offset"] <= previous
                or not _hash(edit["raw_sha256"]) or not isinstance(edit["text"], str)
                or "\0" in edit["text"]):
            raise ValueError("Delta text edit is invalid, duplicated or unsorted")
        edit["text"].encode("utf-8")
        if edit["source_offset"] in message_offsets:
            raise ValueError("Translation overlaps the structurally replaced message")
        previous = edit["source_offset"]


def _check_text(files: dict[str, bytes], edits: list[dict[str, Any]]) -> None:
    model = json.loads(files["editable.json"])
    messages = {}
    for node in model["source_ir"]["nodes"]:
        operands = node.get("statement", {}).get("operands", [])
        if len(operands) == 1 and operands[0].get("type") == "cp932_bytes":
            messages[node["source"]["start"]] = workflow._sha(bytes.fromhex(operands[0]["raw_hex"]))
    for edit in edits:
        if messages.get(edit["source_offset"]) != edit["raw_sha256"]:
            raise ValueError("Authored text does not bind an exact source message")


def build(files: dict[str, bytes], source: bytes, edits: list[dict[str, Any]]) -> dict[str, Any]:
    workflow._validate_files(files)
    identity = json.loads(files["handoff.json"])["source_identity"]
    registry_proof = json.loads(files[workflow.REGISTRY_MEMBER]) if workflow.REGISTRY_MEMBER in files else None
    library_audit = json.loads(files[workflow.LIBRARY_MEMBER]) if workflow.LIBRARY_MEMBER in files else None
    source_files = workflow.analyze(source, identity, registry_proof, library_audit)
    if any(files[name] != source_files[name] for name in workflow.SOURCE_FILES):
        raise ValueError("Delta bundle differs from the supplied original")
    if workflow.SEQUENCE_MEMBER in files:
        sequence = json.loads(files[workflow.SEQUENCE_MEMBER])
        operations = [row["operation"] for row in sequence["steps"]]
    else:
        operations = [json.loads(files["plan.json"])["operation"]]
    required_entries = _required_dependency_entries(operations)
    dependencies: list[dict[str, Any]] = []
    if "DEF_MAIN.MES" in required_entries:
        registry_source = registry_proof["source_identity"]
        dependencies.append({"entry": registry_source["entry"], "entry_sha256": registry_source["entry_sha256"]})
    if "LIBLARY.LIB" in required_entries:
        dependencies.append({"entry": library_audit["entry"], "entry_sha256": library_audit["entry_sha256"]})
    dependencies.sort(key=lambda row: row["entry"])
    proof = json.loads(files["semantic.diff.json"])
    document = {"schema": SCHEMA, "source": identity, "source_entry_sha256": workflow._sha(source),
                "operations": operations, "dependencies": dependencies,
                "output_entry_sha256": workflow._sha(files["output.mes"]),
                "semantic_diff_sha256": proof["payload_sha256"], "text_edits": edits,
                "compatibility": COMPATIBILITY.copy()}
    document["payload_sha256"] = fingerprint(document)
    validate(document)
    _check_text(source_files, edits)
    return document


def reconstruct(document: dict[str, Any], source: bytes, identity: dict[str, Any],
                 dependency_payloads: dict[str, bytes] | None = None,
                 library_audit: dict[str, Any] | None = None) -> dict[str, bytes]:
    validate(document)
    if identity != document["source"] or workflow._sha(source) != document["source_entry_sha256"]:
        raise ValueError("Delta original source identity differs")
    dependency_payloads = dependency_payloads or {}
    operations = document["operations"] if document["schema"] == SCHEMA else [document["operation"]]
    required_entries = _required_dependency_entries(operations)
    registry_proof = None
    for row in document.get("dependencies", []):
        payload = dependency_payloads.get(row["entry"])
        if payload is None or workflow._sha(payload) != row["entry_sha256"]:
            raise ValueError(f"Delta dependency {row['entry']} is missing or changed")
        if row["entry"] == "DEF_MAIN.MES" and "DEF_MAIN.MES" in required_entries:
            registry_proof = workflow.registry_prover.prove_entry(payload, {
                "archive": identity["archive"], "archive_sha256": identity["archive_sha256"],
                "entry": row["entry"], "entry_sha256": row["entry_sha256"]})
        elif row["entry"] == "LIBLARY.LIB" and "LIBLARY.LIB" in required_entries:
            if (library_audit is None or library_audit.get("entry_sha256") != row["entry_sha256"]
                    or workflow._sha(payload) != library_audit.get("entry_sha256")):
                raise ValueError("Delta reconstruction needs the Godot-built library audit of LIBLARY.LIB")
    if "LIBLARY.LIB" in required_entries and library_audit is None:
        raise ValueError("Delta reconstruction needs the Godot-built library audit of LIBLARY.LIB")
    source_files = workflow.analyze(source, identity, registry_proof,
                                     library_audit if "LIBLARY.LIB" in required_entries else None)
    _check_text(source_files, document["text_edits"])
    files = workflow.compile_sequence(source_files, operations)
    if (workflow._sha(files["output.mes"]) != document["output_entry_sha256"]
            or json.loads(files["semantic.diff.json"])["payload_sha256"] != document["semantic_diff_sha256"]):
        raise ValueError("Reconstructed output or semantic proof differs from the delta")
    return files


def read(path: Path) -> dict[str, Any]:
    if path.stat().st_size > 16 * 1024 * 1024:
        raise ValueError("Delta exceeds the bounded import size")
    document = json.loads(path.read_text(encoding="utf-8"))
    validate(document)
    return document


def publish(path: Path, document: dict[str, Any]) -> None:
    validate(document)
    payload = workflow._json(document)
    if len(payload) > 16 * 1024 * 1024:
        raise ValueError("Delta exceeds the bounded import size")
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".authored-delta-", dir=path.parent)

    def verify(staged: Path) -> None:
        if read(staged) != document:
            raise ValueError("Staged delta could not be reopened exactly")

    # Atomic publication without replacing an existing name, including races.
    payload_values.publish_new_document(path, payload, Path(temporary), verify, descriptor=descriptor)


def _local_source(arc: Path, identity: dict[str, Any]) -> bytes:
    if workflow._sha(arc.read_bytes()) != identity["archive_sha256"]:
        raise ValueError("Local archive does not match the delta")
    payload, entry = workflow.archive_reader.load_archive_entry(arc, identity["entry"])
    if entry["entry"] != identity["entry"] or workflow._sha(arc.read_bytes()) != identity["archive_sha256"]:
        raise ValueError("Local archive changed during reconstruction")
    return payload


def _local_entry(arc: Path, name: str) -> bytes:
    payload, entry = workflow.archive_reader.load_archive_entry(arc, name)
    if entry["entry"] != name:
        raise ValueError("Local archive dependency changed")
    return payload


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("build")
    create.add_argument("arc", type=Path)
    create.add_argument("bundle", type=Path)
    create.add_argument("text_edits", type=Path, help="Authored edit array; source offset, raw hash and UTF-8 text only")
    create.add_argument("output", type=Path)
    apply = commands.add_parser("reconstruct")
    apply.add_argument("arc", type=Path)
    apply.add_argument("delta", type=Path)
    apply.add_argument("output", type=Path, help="New local authoring bundle; text edits remain in the delta")
    apply.add_argument("--library-audit", type=Path)
    args = parser.parse_args()
    try:
        if args.output.resolve().is_relative_to(args.arc.resolve().parent):
            raise ValueError("Generated output must be outside the original archive directory")
        if args.command == "build":
            _, files = workflow.read_bundle(args.bundle)
            identity = json.loads(files["handoff.json"])["source_identity"]
            document = build(files, _local_source(args.arc, identity), json.loads(args.text_edits.read_text(encoding="utf-8")))
            publish(args.output, document)
        else:
            document = read(args.delta)
            dependency_payloads = {row["entry"]: _local_entry(args.arc, row["entry"])
                                    for row in document.get("dependencies", [])}
            library_audit = (json.loads(args.library_audit.read_text(encoding="utf-8"))
                              if args.library_audit is not None else None)
            files = reconstruct(document, _local_source(args.arc, document["source"]), document["source"],
                                 dependency_payloads, library_audit)
            workflow.publish(args.output, files)
        print(json.dumps({"ok": True, "schema": document["schema"], "payload_sha256": document["payload_sha256"],
                          "output_entry_sha256": document["output_entry_sha256"], "authored_text_count": len(document["text_edits"])}))
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(json.dumps({"ok": False, "schema": SCHEMA, "error": str(error)}))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
