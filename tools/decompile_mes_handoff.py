from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import validate_mes_analyzer_handoff as analyzer_handoff
from payload_values import canonical_payload_bytes, fingerprint


DECOMPILER_IR_SCHEMA = "kakyu_mes_decompiler_ir/v1"
TYPED_EVIDENCE_STATUS = "typed_phase1_4"
OPAQUE_EVIDENCE_STATUS = "byte_preserving_fail_closed"

_INSTRUCTION_SOURCE_KEYS = {
    "schema",
    "ok",
    "source_offset",
    "end_offset",
    "byte_length",
    "raw_hex",
    "region",
    "op",
    "command_id",
    "operands",
}
_OPAQUE_SOURCE_KEYS = {
    "source_offset",
    "end_offset",
    "raw_hex",
    "raw_sha256",
    "region",
    "boundary",
}


class DecompilerIrError(ValueError):
    pass


def lift(handoff: dict[str, Any]) -> dict[str, Any]:
    analyzer_handoff.validate(handoff)
    container = _validated_container(handoff)
    code = container["code"]
    region_specs = _validated_regions(handoff, len(code))
    graph_index = _graph_node_index(handoff.get("cfg", []))
    references, reference_index = _reference_index(handoff.get("references", {}))

    records: list[tuple[int, int, str, dict[str, Any]]] = []
    typed_ir = handoff.get("typed_ir")
    if not isinstance(typed_ir, dict):
        raise DecompilerIrError("missing typed IR")
    instructions = typed_ir.get("instructions")
    opaque_boundaries = typed_ir.get("opaque_boundaries")
    if not isinstance(instructions, list) or not isinstance(opaque_boundaries, list):
        raise DecompilerIrError("typed IR record arrays are missing")
    for instruction in instructions:
        if not isinstance(instruction, dict):
            raise DecompilerIrError("typed instruction is not an object")
        records.append(_validated_record(instruction, "statement", code, region_specs))
    for boundary in opaque_boundaries:
        if not isinstance(boundary, dict):
            raise DecompilerIrError("opaque boundary is not an object")
        records.append(_validated_record(boundary, "opaque", code, region_specs))
    records.sort(key=lambda row: (row[0], row[1], row[2]))
    _validate_record_partition(records, len(code))

    nodes: list[dict[str, Any]] = []
    for start, end, kind, source_record in records:
        node_id = f"linear_{start:08x}"
        raw = code[start:end]
        source = {
            "entry": str(handoff.get("source_identity", {}).get("entry", "")),
            "region": str(source_record["region"]),
            "start": start,
            "end": end,
            "raw_hex": raw.hex(),
            "raw_sha256": hashlib.sha256(raw).hexdigest(),
        }
        if kind == "statement":
            statement = {
                "kind": "instruction",
                "op": str(source_record.get("op", "")),
                "command_id": int(source_record.get("command_id", -1)),
                "operands": copy.deepcopy(source_record.get("operands", [])),
                "metadata": {
                    key: copy.deepcopy(value)
                    for key, value in source_record.items()
                    if key not in _INSTRUCTION_SOURCE_KEYS
                },
            }
            evidence_status = TYPED_EVIDENCE_STATUS
        else:
            statement = {
                "kind": "opaque",
                "boundary": str(source_record.get("boundary", "")),
                "details": {
                    key: copy.deepcopy(value)
                    for key, value in source_record.items()
                    if key not in _OPAQUE_SOURCE_KEYS
                },
            }
            evidence_status = OPAQUE_EVIDENCE_STATUS
        node = {
            "id": node_id,
            "kind": kind,
            "source": source,
            "evidence_status": evidence_status,
            "statement": statement,
            "cfg_nodes": copy.deepcopy(graph_index.get(start, [])),
            "reference_ids": _references_in_range(reference_index, start, end),
        }
        nodes.append(node)

    regions: list[dict[str, Any]] = []
    for region in region_specs:
        start = int(region["start"])
        end = int(region["end"])
        node_ids = [node["id"] for node in nodes if start <= node["source"]["start"] < end]
        regions.append(
            {
                "id": region["id"],
                "kind": region["kind"],
                "index": region["index"],
                "source_start": start,
                "source_end": end,
                "raw_sha256": hashlib.sha256(code[start:end]).hexdigest(),
                "node_ids": node_ids,
            }
        )

    raw_container = container["raw"]
    code_offset = int(container["code_offset"])
    document = {
        "ok": True,
        "schema": DECOMPILER_IR_SCHEMA,
        "producer": {
            "implementation": "python_phase5_linear_lifter",
            "contract": DECOMPILER_IR_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_input_schema_match",
            "input_handoff_schema": analyzer_handoff.HANDOFF_SCHEMA,
            "input_component_schemas": copy.deepcopy(
                handoff["compatibility"]["component_schemas"]
            ),
            "unknown_decompiler_schema": "reject",
            "unknown_v1_field": "ignore",
            "source_reversal": "preamble_plus_ordered_node_bytes",
        },
        "input_handoff": {
            "schema": analyzer_handoff.HANDOFF_SCHEMA,
            "payload_sha256": handoff["payload_sha256"],
        },
        "source_identity": copy.deepcopy(handoff.get("source_identity", {})),
        "container": {
            "schema": str(handoff["container"].get("schema", "")),
            "entry_sha256": str(handoff["container"].get("entry_sha256", "")),
            "bytecode_sha256": str(handoff["container"].get("bytecode_sha256", "")),
            "code_offset": code_offset,
            "code_size": len(code),
            "preamble_raw_hex": raw_container[:code_offset].hex(),
            "preamble_sha256": hashlib.sha256(raw_container[:code_offset]).hexdigest(),
        },
        "regions": regions,
        "nodes": nodes,
        "references": references,
        "analysis_evidence": {
            "diagnostics": copy.deepcopy(typed_ir.get("diagnostics", [])),
            "control_flow": copy.deepcopy(handoff.get("cfg", [])),
            "calls": copy.deepcopy(handoff.get("calls", [])),
            "traces": copy.deepcopy(handoff.get("traces", [])),
        },
        "coverage": {
            "region_count": len(regions),
            "node_count": len(nodes),
            "typed_node_count": len(instructions),
            "opaque_node_count": len(opaque_boundaries),
            "code_bytes": len(code),
            "covered_bytes": sum(int(node["source"]["end"]) - int(node["source"]["start"]) for node in nodes),
            "complete": True,
        },
    }
    document["payload_sha256"] = fingerprint(document)
    validate(document)
    return document


def reconstruct_container(document: dict[str, Any]) -> bytes:
    container = document.get("container")
    nodes = document.get("nodes")
    if not isinstance(container, dict) or not isinstance(nodes, list):
        raise DecompilerIrError("decompiler IR container or nodes are missing")
    try:
        preamble = bytes.fromhex(str(container.get("preamble_raw_hex", "")))
        body = b"".join(bytes.fromhex(str(node["source"]["raw_hex"])) for node in nodes)
    except (KeyError, TypeError, ValueError) as error:
        raise DecompilerIrError("decompiler IR raw source encoding is invalid") from error
    return preamble + body


def validate(document: dict[str, Any]) -> dict[str, Any]:
    if document.get("schema") != DECOMPILER_IR_SCHEMA:
        raise DecompilerIrError("unsupported MES decompiler IR schema")
    compatibility = document.get("compatibility")
    if not isinstance(compatibility, dict):
        raise DecompilerIrError("missing decompiler compatibility contract")
    if compatibility.get("input_handoff_schema") != analyzer_handoff.HANDOFF_SCHEMA:
        raise DecompilerIrError("unsupported decompiler input handoff schema")
    if compatibility.get("input_component_schemas") != {
        **analyzer_handoff.COMPONENT_SCHEMAS,
        "accepted_call_evidence": analyzer_handoff.CALL_EVIDENCE_SCHEMAS,
        "accepted_trace_evidence": analyzer_handoff.TRACE_EVIDENCE_SCHEMAS,
    }:
        raise DecompilerIrError("unsupported decompiler input component schemas")
    retained = document.get("payload_sha256")
    if not isinstance(retained, str) or len(retained) != 64:
        raise DecompilerIrError("missing MES decompiler IR fingerprint")
    if fingerprint(document) != retained:
        raise DecompilerIrError("MES decompiler IR fingerprint changed")
    input_handoff = document.get("input_handoff")
    if (
        not isinstance(input_handoff, dict)
        or input_handoff.get("schema") != analyzer_handoff.HANDOFF_SCHEMA
        or not isinstance(input_handoff.get("payload_sha256"), str)
        or len(input_handoff["payload_sha256"]) != 64
    ):
        raise DecompilerIrError("decompiler input handoff identity is missing")

    container = document.get("container")
    regions = document.get("regions")
    nodes = document.get("nodes")
    if not isinstance(container, dict) or not isinstance(regions, list) or not isinstance(nodes, list):
        raise DecompilerIrError("decompiler IR structural arrays are missing")
    raw = reconstruct_container(document)
    code_offset = int(container.get("code_offset", -1))
    code_size = int(container.get("code_size", -1))
    if code_offset < 0 or code_size < 0 or len(raw) != code_offset + code_size:
        raise DecompilerIrError("decompiler IR reconstructed size changed")
    if hashlib.sha256(raw).hexdigest() != container.get("entry_sha256"):
        raise DecompilerIrError("decompiler IR does not reconstruct the source container")
    code = raw[code_offset:]
    if hashlib.sha256(code).hexdigest() != container.get("bytecode_sha256"):
        raise DecompilerIrError("decompiler IR does not reconstruct the source bytecode")
    preamble = raw[:code_offset]
    if hashlib.sha256(preamble).hexdigest() != container.get("preamble_sha256"):
        raise DecompilerIrError("decompiler IR preamble fingerprint changed")

    node_ids: set[str] = set()
    ranges: list[tuple[int, int, str]] = []
    cfg_graphs = document.get("analysis_evidence", {}).get("control_flow", [])
    cfg_nodes_by_id = {
        (graph_index, str(node.get("id", ""))): int(node.get("offset", -1))
        for graph_index, graph in enumerate(cfg_graphs)
        if isinstance(graph, dict)
        for node in graph.get("nodes", [])
        if isinstance(node, dict)
    }
    all_reference_ids = {
        str(reference.get("id", ""))
        for reference in document.get("references", [])
        if isinstance(reference, dict)
    }
    reference_offsets = {
        str(reference.get("id", "")): int(reference.get("source_offset", -1))
        for reference in document.get("references", [])
        if isinstance(reference, dict)
    }
    if len(reference_offsets) != len(document.get("references", [])) or "" in reference_offsets:
        raise DecompilerIrError("decompiler reference identity changed")
    assigned_reference_ids: list[str] = []
    for node in nodes:
        if not isinstance(node, dict):
            raise DecompilerIrError("decompiler IR node is not an object")
        node_id = str(node.get("id", ""))
        if not node_id or node_id in node_ids:
            raise DecompilerIrError("decompiler IR node identity changed")
        node_ids.add(node_id)
        source = node.get("source")
        statement = node.get("statement")
        if not isinstance(source, dict) or not isinstance(statement, dict):
            raise DecompilerIrError("decompiler IR node provenance is missing")
        start = int(source.get("start", -1))
        end = int(source.get("end", -1))
        try:
            raw_node = bytes.fromhex(str(source.get("raw_hex", "")))
        except ValueError as error:
            raise DecompilerIrError("decompiler IR node raw bytes are invalid") from error
        if start < 0 or end <= start or end > code_size or len(raw_node) != end - start:
            raise DecompilerIrError("decompiler IR node boundary changed")
        if hashlib.sha256(raw_node).hexdigest() != source.get("raw_sha256"):
            raise DecompilerIrError("decompiler IR node raw identity changed")
        kind = str(node.get("kind", ""))
        if kind == "statement":
            if node.get("evidence_status") != TYPED_EVIDENCE_STATUS or statement.get("kind") != "instruction":
                raise DecompilerIrError("typed decompiler node evidence changed")
            if not isinstance(statement.get("operands"), list) or not isinstance(statement.get("metadata"), dict):
                raise DecompilerIrError("typed decompiler statement is incomplete")
        elif kind == "opaque":
            if node.get("evidence_status") != OPAQUE_EVIDENCE_STATUS or statement.get("kind") != "opaque":
                raise DecompilerIrError("opaque decompiler node evidence changed")
        else:
            raise DecompilerIrError("unsupported decompiler node kind")
        for cfg_node in node.get("cfg_nodes", []):
            key = (int(cfg_node.get("graph_index", -1)), str(cfg_node.get("node_id", "")))
            if key not in cfg_nodes_by_id:
                raise DecompilerIrError("decompiler node references an unknown CFG node")
            if not start <= cfg_nodes_by_id[key] < end:
                raise DecompilerIrError("decompiler CFG source mapping changed")
        reference_ids = node.get("reference_ids")
        if not isinstance(reference_ids, list) or any(str(ref) not in all_reference_ids for ref in reference_ids):
            raise DecompilerIrError("decompiler node references unknown source evidence")
        if any(not start <= reference_offsets[str(ref)] < end for ref in reference_ids):
            raise DecompilerIrError("decompiler reference source mapping changed")
        assigned_reference_ids.extend(str(ref) for ref in reference_ids)
        ranges.append((start, end, kind))
    _validate_record_partition(ranges, code_size)
    if sorted(assigned_reference_ids) != sorted(all_reference_ids):
        raise DecompilerIrError("decompiler reference source mapping is incomplete")

    expected_region_ids: list[str] = []
    region_node_ids: list[str] = []
    nodes_by_id = {str(node["id"]): node for node in nodes}
    region_cursor = 0
    for region in regions:
        if not isinstance(region, dict):
            raise DecompilerIrError("decompiler IR region is not an object")
        region_id = str(region.get("id", ""))
        start = int(region.get("source_start", -1))
        end = int(region.get("source_end", -1))
        if not region_id or region_id in expected_region_ids or start != region_cursor or end < start:
            raise DecompilerIrError("decompiler IR region partition changed")
        if hashlib.sha256(code[start:end]).hexdigest() != region.get("raw_sha256"):
            raise DecompilerIrError("decompiler IR region raw identity changed")
        ids = region.get("node_ids")
        if not isinstance(ids, list) or any(str(node_id) not in node_ids for node_id in ids):
            raise DecompilerIrError("decompiler IR region node mapping changed")
        if any(
            nodes_by_id[str(node_id)]["source"].get("region") != region_id
            or not start <= int(nodes_by_id[str(node_id)]["source"].get("start", -1)) < end
            for node_id in ids
        ):
            raise DecompilerIrError("decompiler IR node belongs to the wrong region")
        expected_region_ids.append(region_id)
        region_node_ids.extend(str(node_id) for node_id in ids)
        region_cursor = end
    if region_cursor != code_size or region_node_ids != [str(node["id"]) for node in nodes]:
        raise DecompilerIrError("decompiler IR region coverage is incomplete")

    coverage = document.get("coverage")
    if not isinstance(coverage, dict) or coverage.get("complete") is not True:
        raise DecompilerIrError("decompiler IR coverage is not complete")
    if (
        int(coverage.get("region_count", -1)) != len(regions)
        or int(coverage.get("node_count", -1)) != len(nodes)
        or int(coverage.get("typed_node_count", -1)) != sum(node["kind"] == "statement" for node in nodes)
        or int(coverage.get("opaque_node_count", -1)) != sum(node["kind"] == "opaque" for node in nodes)
        or int(coverage.get("covered_bytes", -1)) != code_size
        or int(coverage.get("code_bytes", -1)) != code_size
    ):
        raise DecompilerIrError("decompiler IR coverage counts changed")
    return {"ok": True, "schema": DECOMPILER_IR_SCHEMA, "payload_sha256": retained}


def _validated_container(handoff: dict[str, Any]) -> dict[str, Any]:
    container = handoff.get("container")
    if not isinstance(container, dict):
        raise DecompilerIrError("missing handoff container")
    try:
        raw = bytes.fromhex(str(container.get("raw_hex", "")))
    except ValueError as error:
        raise DecompilerIrError("handoff container raw bytes are invalid") from error
    header = container.get("header")
    if not isinstance(header, dict):
        raise DecompilerIrError("missing handoff container header")
    code_offset = int(header.get("code_offset", -1))
    code_size = int(header.get("code_size", -1))
    if code_offset < 0 or code_size < 0 or len(raw) != code_offset + code_size:
        raise DecompilerIrError("handoff container size changed")
    if hashlib.sha256(raw).hexdigest() != container.get("entry_sha256"):
        raise DecompilerIrError("handoff container source fingerprint changed")
    code = raw[code_offset:]
    if hashlib.sha256(code).hexdigest() != container.get("bytecode_sha256"):
        raise DecompilerIrError("handoff bytecode fingerprint changed")
    return {"raw": raw, "code": code, "code_offset": code_offset}


def _validated_regions(handoff: dict[str, Any], code_size: int) -> list[dict[str, Any]]:
    container = handoff["container"]
    rows: list[dict[str, Any]] = []
    bootstrap = container.get("bootstrap")
    if not isinstance(bootstrap, dict):
        raise DecompilerIrError("missing bootstrap region")
    rows.append(
        {
            "id": "bootstrap",
            "kind": "bootstrap",
            "index": None,
            "start": int(bootstrap.get("offset", -1)),
            "end": int(bootstrap.get("end_offset", -1)),
        }
    )
    entries = container.get("entries")
    if not isinstance(entries, list):
        raise DecompilerIrError("missing address-table regions")
    for ordinal, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise DecompilerIrError("address-table region is not an object")
        rows.append(
            {
                "id": str(entry.get("id", "")),
                "kind": "entry",
                "index": int(entry.get("index", ordinal)),
                "start": int(entry.get("offset", -1)),
                "end": int(entry.get("end_offset", -1)),
            }
        )
    cursor = 0
    ids: set[str] = set()
    for row in rows:
        if not row["id"] or row["id"] in ids or row["start"] != cursor or row["end"] < row["start"]:
            raise DecompilerIrError("handoff regions do not partition the bytecode")
        ids.add(row["id"])
        cursor = row["end"]
    if cursor != code_size:
        raise DecompilerIrError("handoff regions do not cover the bytecode")
    return rows


def _validated_record(
    record: dict[str, Any],
    kind: str,
    code: bytes,
    regions: list[dict[str, Any]],
) -> tuple[int, int, str, dict[str, Any]]:
    start = int(record.get("source_offset", -1))
    end = int(record.get("end_offset", -1))
    if start < 0 or end <= start or end > len(code):
        raise DecompilerIrError("handoff record boundary changed")
    raw = code[start:end]
    if record.get("raw_hex") != raw.hex():
        raise DecompilerIrError("handoff record raw bytes changed")
    region_id = str(record.get("region", ""))
    owner = next((region for region in regions if region["start"] <= start and end <= region["end"]), None)
    if owner is None or region_id != owner["id"]:
        raise DecompilerIrError("handoff record region changed")
    if kind == "statement":
        if record.get("schema") != analyzer_handoff.COMPONENT_SCHEMAS["instruction"]:
            raise DecompilerIrError("handoff instruction schema changed")
        if int(record.get("byte_length", -1)) != end - start:
            raise DecompilerIrError("handoff instruction length changed")
        if not isinstance(record.get("operands"), list):
            raise DecompilerIrError("handoff instruction operands are missing")
    else:
        if record.get("boundary") != OPAQUE_EVIDENCE_STATUS:
            raise DecompilerIrError("handoff opaque boundary policy changed")
        if record.get("raw_sha256") != hashlib.sha256(raw).hexdigest():
            raise DecompilerIrError("handoff opaque boundary raw identity changed")
    return start, end, kind, record


def _validate_record_partition(records: list[tuple[int, int, Any]], code_size: int) -> None:
    cursor = 0
    for record in records:
        start = int(record[0])
        end = int(record[1])
        if start != cursor or end <= start:
            raise DecompilerIrError("linear source records do not partition the bytecode")
        cursor = end
    if cursor != code_size:
        raise DecompilerIrError("linear source records do not cover the bytecode")


def _graph_node_index(graphs: Any) -> dict[int, list[dict[str, Any]]]:
    if not isinstance(graphs, list):
        raise DecompilerIrError("handoff CFG collection is not an array")
    result: dict[int, list[dict[str, Any]]] = {}
    for graph_index, graph in enumerate(graphs):
        if not isinstance(graph, dict) or graph.get("schema") != analyzer_handoff.COMPONENT_SCHEMAS["reference_graph"]:
            raise DecompilerIrError("handoff CFG schema changed")
        graph_node_ids: set[str] = set()
        for node in graph.get("nodes", []):
            if not isinstance(node, dict):
                raise DecompilerIrError("handoff CFG node is not an object")
            offset = int(node.get("offset", -1))
            node_id = str(node.get("id", ""))
            if offset < 0 or not node_id or node_id in graph_node_ids:
                raise DecompilerIrError("handoff CFG node identity changed")
            graph_node_ids.add(node_id)
            result.setdefault(offset, []).append(
                {"graph_index": graph_index, "node_id": node_id}
            )
        for edge in graph.get("edges", []):
            if (
                not isinstance(edge, dict)
                or str(edge.get("from_id", "")) not in graph_node_ids
                or str(edge.get("to_id", "")) not in graph_node_ids
            ):
                raise DecompilerIrError("handoff CFG contains a dangling edge")
    return result


def _reference_index(raw_references: Any) -> tuple[list[dict[str, Any]], list[tuple[int, str]]]:
    if not isinstance(raw_references, dict):
        raise DecompilerIrError("handoff references are missing")
    references: list[dict[str, Any]] = []
    index: list[tuple[int, str]] = []
    for kind in ("messages", "code", "state", "resources"):
        rows = raw_references.get(kind)
        if not isinstance(rows, list):
            raise DecompilerIrError(f"handoff reference array is missing: {kind}")
        singular = "message" if kind == "messages" else kind.rstrip("s")
        for ordinal, row in enumerate(rows):
            if not isinstance(row, dict):
                raise DecompilerIrError("handoff reference is not an object")
            source_offset = int(row.get("source_offset", -1))
            reference_id = f"{singular}_{ordinal:08d}"
            references.append(
                {
                    "id": reference_id,
                    "kind": singular,
                    "source_offset": source_offset,
                    "value": copy.deepcopy(row),
                }
            )
            index.append((source_offset, reference_id))
    references.sort(key=lambda row: (int(row["source_offset"]), str(row["kind"]), str(row["id"])))
    index.sort()
    return references, index


def _references_in_range(index: list[tuple[int, str]], start: int, end: int) -> list[str]:
    return [reference_id for offset, reference_id in index if start <= offset < end]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Lift a verified Kakyu MES Phase 1-4 handoff into lossless linear decompiler IR."
    )
    parser.add_argument("handoff", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    with args.handoff.open("r", encoding="utf-8") as stream:
        handoff = json.load(stream)
    document = lift(handoff)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        if args.output.resolve() == args.handoff.resolve():
            raise DecompilerIrError("decompiler output must not replace its input handoff")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_DECOMPILER_LINEAR_IR_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"nodes={document['coverage']['node_count']} opaque={document['coverage']['opaque_node_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
