"""Reproduce a relocation proof from exact local source/output bytes.

This tool belongs to authoring instruments. Playback packages do not require it.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import mes_authoring_workflow as workflow

SCHEMA = "kakyu_mes_authoring_binding/v1"


def bind(source: bytes, output: bytes, proof: dict) -> dict:
    workflow.message_diff.validate(proof)
    identity = proof["source_identity"]
    files = workflow.analyze(source, identity)
    output_files = workflow.analyze(output, identity)
    offset = proof["semantic_changes"]["message"]["source_instruction_start"]
    before = {row["operation"]["source_offset"]: row for row in
              workflow.message_controls(json.loads(files["editable.json"]))}
    after = {row["operation"]["source_offset"]: row for row in
             workflow.message_controls(json.loads(output_files["editable.json"]))}
    if offset not in before or offset not in after:
        raise ValueError("Relocated message is not a unique typed source/output message")
    operation = dict(before[offset]["operation"], text=after[offset]["operation"]["text"])
    rebuilt = workflow.compile_edit(files, operation)
    if rebuilt["output.mes"] != output or json.loads(rebuilt["semantic.diff.json"]) != proof:
        raise ValueError("Relocation output or proof differs from authoritative reconstruction")
    original_nodes = json.loads(files["editable.json"])["source_ir"]["nodes"]
    output_nodes = json.loads(output_files["editable.json"])["source_ir"]["nodes"]
    points = [{"source": a["source"]["start"], "output": b["source"]["start"],
               "source_end": a["source"]["end"], "output_end": b["source"]["end"]}
              for a, b in zip(original_nodes, output_nodes, strict=True)]
    messages = []
    for point in points:
        if point["source"] in before:
            old = before[point["source"]]["operation"]
            new = after[point["output"]]["operation"]
            messages.append({"source": point["source"], "output": point["output"],
                             "source_raw_sha256": old["raw_sha256"], "output_raw_sha256": new["raw_sha256"]})
    result = {"ok": True, "schema": SCHEMA, "source_entry_sha256": workflow._sha(source),
              "output_entry_sha256": workflow._sha(output), "semantic_diff_sha256": proof["payload_sha256"],
              "points": points, "messages": messages}
    result["payload_sha256"] = workflow.editable.fingerprint(result)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("proof", type=Path)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    try:
        result = bind(args.source.read_bytes(), args.output.read_bytes(), json.loads(args.proof.read_bytes()))
    except (ValueError, OSError, KeyError, TypeError) as error:
        result = {"ok": False, "schema": SCHEMA, "error": str(error)}
    workflow.editable.publish_new(args.report, workflow._json(result))
    print(json.dumps({key: value for key, value in result.items() if key not in ("points", "messages")}))
    if not result["ok"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
