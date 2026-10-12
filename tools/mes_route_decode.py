"""Compact, faithful decode of MES script ranges for route work.

Library and CLI. Renders every branch (with its condition and false target),
every state write (literal or expression, for `global_u8`, `state_u16` and
`banked_u16` including expression indices), every script dispatch, handoff,
return, routine-40 record and choice definition, so a route sheet can be
drafted from facts instead of from a filtered view.

    py tools/mes_route_decode.py --arc "<mes.arc>" 27C3B.MES:1492:1720 EVENTA01.MES
    py tools/mes_route_decode.py --arc "<mes.arc>" --summary EVENTA01.MES

Offsets are code-relative (the container header is already subtracted by
the handoff builder); never compare them with raw entry-file offsets.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract_kakyu_arc import read_entries  # noqa: E402
from mes_analyzer_handoff import build_handoff  # noqa: E402

AFFECTION_RANGE = range(200, 216)
PRESENTATION_CELLS = {("global_u8", 4001), ("global_u8", 4090), ("global_u8", 4091),
                      ("global_u8", 2836), ("global_u8", 3000), ("global_u8", 2841)}


class Archive:
    def __init__(self, arc: Path):
        self.arc = Path(arc)
        self.blob = self.arc.read_bytes()
        self.sha = hashlib.sha256(self.blob).hexdigest()
        self.entries = {n: self.blob[o:o + s] for n, o, s in read_entries(self.arc)}
        self._handoffs: dict[str, dict] = {}

    def names(self) -> list[str]:
        return sorted(self.entries)

    def handoff(self, entry: str) -> dict:
        if entry not in self._handoffs:
            self._handoffs[entry] = build_handoff(
                self.entries[entry],
                {"archive": self.arc.name, "entry": entry, "source_kind": "original_arc",
                 "archive_sha256": self.sha})
        return self._handoffs[entry]

    def instructions(self, entry: str) -> list[dict]:
        return self.handoff(entry)["typed_ir"]["instructions"]

    def code(self, entry: str) -> bytes:
        return self.handoff(entry)["container"]["_bytecode"] if "_bytecode" in self.handoff(entry)["container"] else None

    def opaque_tails(self, entry: str) -> list[dict]:
        return self.handoff(entry)["typed_ir"].get("opaque_boundaries", [])


def render(node) -> str:
    if not isinstance(node, dict):
        return str(node)
    kind = node.get("type")
    if kind == "literal":
        return str(node.get("value"))
    if kind == "state_ref":
        index = node.get("index")
        index_text = render(index) if isinstance(index, dict) else str(index)
        return f"{node.get('storage')}[{index_text}]"
    if kind == "binary":
        return f"({render(node.get('lhs'))} {node.get('op')} {render(node.get('rhs'))})"
    if kind == "unary":
        return f"{node.get('op')}({render(node.get('operand'))})"
    if kind == "call":
        args = ",".join(render(a) for a in node.get("args", []))
        return f"{node.get('name')}({args})"
    if "ast" in node:
        return render(node["ast"])
    return json.dumps(node)[:60]


def _write_parts(instruction: dict) -> tuple[str, str, list[str]] | None:
    """Return (storage, index_text, [value_text...]) for a *_write_run."""
    op = instruction.get("op", "")
    if not op.endswith("_write_run"):
        return None
    storage = op[: -len("_write_run")]
    operands = instruction.get("operands") or []
    index_text = "?"
    values: list[str] = []
    for operand in operands:
        if not isinstance(operand, dict):
            continue
        kind = operand.get("type")
        if kind in ("u16_index", "u8_index"):
            index_text = str(operand.get("value"))
        elif kind == "expression_index":
            index_text = render(operand.get("value"))
        elif kind == "expression_byte_pairs":
            for pair in operand.get("pairs", []):
                values.append(render(pair.get("expression")))
    return storage, index_text, values


def _string_target(instruction: dict) -> str:
    text = json.dumps(instruction.get("operands") or [])
    match = re.search(r'"\$packed_byte_array_hex": "([0-9a-f]+)"', text)
    if not match:
        return ""
    return bytes.fromhex(match.group(1)).decode("latin1").strip("\x00").upper()


def _routine(instruction: dict) -> int | None:
    for record in (instruction.get("operands") or [{}])[0].get("records", []) if instruction.get("operands") else []:
        value = record.get("value", {})
        if isinstance(value, dict) and value.get("ast", {}).get("type") == "literal":
            return int(value["ast"]["value"])
    return None


def facts(archive: Archive, entry: str, lo: int = 0, hi: int | None = None) -> list[dict]:
    """Typed facts in [lo, hi): branches, writes, dispatches, handoffs, returns, routines, definitions."""
    out: list[dict] = []
    for instruction in archive.instructions(entry):
        offset = int(instruction["source_offset"])
        end = int(instruction["end_offset"])
        if offset < lo or (hi is not None and offset >= hi):
            continue
        op = instruction.get("op", "")
        base = {"offset": offset, "end": end, "op": op}
        if op == "branch_if_not_true":
            operands = instruction.get("operands") or []
            condition = next((o["value"] for o in operands if o.get("type") == "condition"), {})
            false_target = next((o["value"] for o in operands if o.get("type") == "code_offset"), None)
            out.append({**base, "kind": "branch", "condition": render(condition.get("ast", condition)),
                        "false_target": false_target, "cells": _condition_cells(condition.get("ast", condition))})
        elif op.endswith("_write_run"):
            parts = _write_parts(instruction)
            if parts:
                storage, index_text, values = parts
                literal_index = int(index_text) if index_text.isdigit() else None
                out.append({**base, "kind": "write", "storage": storage, "index": literal_index,
                            "index_text": index_text, "values": values})
        elif op == "script_dispatch":
            out.append({**base, "kind": "dispatch", "target": _string_target(instruction)})
        elif op == "script_handoff_marker":
            out.append({**base, "kind": "handoff", "target": _string_target(instruction)})
        elif op == "script_transfer":
            routine = _routine(instruction)
            out.append({**base, "kind": "routine", "routine": routine})
        elif op == "command_10":
            out.append({**base, "kind": "definition"})
        elif op == "command_00":
            out.append({**base, "kind": "return"})
        elif op == "continuation_transfer":
            target = (instruction.get("operands") or [{}])[0].get("value")
            out.append({**base, "kind": "jump", "target": target})
        elif op == "entry_label":
            out.append({**base, "kind": "label", "index": (instruction.get("operands") or [{}])[0].get("value")})
        elif op == "command_1b":
            out.append({**base, "kind": "command_1b"})
    return out


def _condition_cells(ast) -> list[list]:
    cells: list[list] = []

    def walk(node):
        if not isinstance(node, dict):
            return
        if node.get("type") == "state_ref":
            index = node.get("index")
            if isinstance(index, dict) and index.get("type") == "literal":
                index = index.get("value")
            if not isinstance(index, dict):
                cell = [node.get("storage"), int(index)]
                if cell not in cells:
                    cells.append(cell)
        for key in ("lhs", "rhs", "operand"):
            if key in node:
                walk(node[key])
        for arg in node.get("args", []) or []:
            walk(arg)
    walk(ast)
    return cells


def conjuncts(archive: Archive, entry: str, branch_offset: int) -> list[dict]:
    """Top-level `and` conjuncts of the branch at branch_offset, each with its cells and text."""
    for instruction in archive.instructions(entry):
        if int(instruction["source_offset"]) != branch_offset or instruction.get("op") != "branch_if_not_true":
            continue
        operands = instruction.get("operands") or []
        condition = next((o["value"] for o in operands if o.get("type") == "condition"), {})
        ast = condition.get("ast", condition)
        parts: list[dict] = []

        def split(node):
            if isinstance(node, dict) and node.get("type") == "binary" and node.get("op") == "logical_and":
                split(node["lhs"]); split(node["rhs"])
            else:
                parts.append(node)
        split(ast)
        return [{"text": render(p), "cells": _condition_cells(p), "ast": p} for p in parts]
    raise KeyError(f"no branch at {entry}:{branch_offset}")


def format_fact(fact: dict) -> str:
    kind = fact["kind"]
    if kind == "branch":
        return f"BR {fact['offset']}..{fact['end']} false={fact['false_target']} {fact['condition']}"
    if kind == "write":
        return f"W {fact['offset']} {fact['storage']}[{fact['index_text']}] = {' / '.join(fact['values'])}"
    if kind == "dispatch":
        return f"DISPATCH {fact['offset']}..{fact['end']} -> {fact['target']}"
    if kind == "handoff":
        return f"HANDOFF {fact['offset']}..{fact['end']} -> {fact['target']}"
    if kind == "routine":
        return f"ROUTINE{fact['routine']} {fact['offset']}"
    if kind == "definition":
        return f"DEFINITION {fact['offset']}"
    if kind == "return":
        return f"RETURN {fact['offset']}"
    if kind == "jump":
        return f"JUMP {fact['offset']} -> {fact['target']}"
    if kind == "label":
        return f"LABEL {fact['offset']} entry {fact['index']}"
    return f"{fact['op']} {fact['offset']}"


def summarize_callee(archive: Archive, entry: str) -> dict:
    """What a route sheet needs to know about an EVENT callee."""
    all_facts = facts(archive, entry)
    size = len(archive.entries[entry])
    code_end = max(f["end"] for f in all_facts) if all_facts else 0
    branches = [f for f in all_facts if f["kind"] == "branch"]
    writes = [f for f in all_facts if f["kind"] == "write"]
    gate = None
    for b in branches:
        if (b["false_target"] is not None and b["false_target"] >= 0.9 * code_end and b["offset"] < 500
                and b["cells"] and all(c[0] == "global_u8" for c in b["cells"])):
            gate = b
            break
    gate_cells = gate["cells"] if gate else []
    own_gate_writes = [w for w in writes if w["storage"] == "global_u8" and [w["storage"], w["index"]] in gate_cells]
    routines = [f for f in all_facts if f["kind"] == "routine" and f["routine"] == 40]
    definitions = [f for f in all_facts if f["kind"] == "definition"]
    handoffs = [f for f in all_facts if f["kind"] == "handoff"]
    dispatches = [f for f in all_facts if f["kind"] == "dispatch"]
    returns = [f for f in all_facts if f["kind"] == "return" and f["offset"] > 200]
    affection = [w for w in writes if w["storage"] == "banked_u16" and w["index"] in AFFECTION_RANGE]
    stamps = [w for w in writes if w["storage"] == "banked_u16" and w["index"] == 242]
    other_banked = [w for w in writes if w["storage"] == "banked_u16" and w["index"] not in (1, 2, 242)
                    and w["index"] not in AFFECTION_RANGE]
    counters = [w for w in writes if w["values"] and "add" in w["values"][0] and f"{w['storage']}[{w['index']}]" in w["values"][0]]
    presentation = [b for b in branches if b["cells"] and tuple(b["cells"][0]) in {("global_u8", 4000), ("global_u8", 3006), ("global_u8", 2847)}]
    free_branches = [b for b in branches if b is not gate and b["cells"] and not any(
        c[0] == "state_u16" and c[1] in (8, 21, 2, 5, 19, 7, 4) for c in b["cells"]) and b not in presentation]
    return {
        "entry": entry, "code_size": size, "branches": len(branches), "message_records": sum(
            1 for i in archive.instructions(entry) if str(i.get("op", "")).startswith("message_record")),
        "opaque_tails": archive.opaque_tails(entry),
        "gate": gate, "own_gate_writes": own_gate_writes,
        "question": {"routine40": routines, "definitions": [d["offset"] for d in definitions]},
        "doors": handoffs, "dispatches": dispatches, "returns": returns,
        "affection_writes": affection, "stamp_writes": stamps, "other_banked_writes": other_banked,
        "counters": counters, "presentation_branches": presentation, "free_branches": free_branches,
        "global_u8_writes": [w for w in writes if w["storage"] == "global_u8" and w["index"] is not None
                             and w["index"] > 20 and ("global_u8", w["index"]) not in PRESENTATION_CELLS
                             and w["index"] not in (3005,)],
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--arc", required=True)
    parser.add_argument("ranges", nargs="+", help="ENTRY or ENTRY:lo:hi")
    parser.add_argument("--summary", action="store_true", help="print the callee summary instead of facts")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--all", action="store_true", help="include labels, returns and command_1b lines")
    args = parser.parse_args(argv)
    archive = Archive(Path(args.arc))
    for spec in args.ranges:
        parts = spec.split(":")
        entry = parts[0].upper()
        lo = int(parts[1]) if len(parts) > 1 else 0
        hi = int(parts[2]) if len(parts) > 2 else None
        if args.summary:
            summary = summarize_callee(archive, entry)
            print(json.dumps(summary, indent=1, ensure_ascii=False) if args.json else _format_summary(summary))
            continue
        rows = facts(archive, entry, lo, hi)
        if not args.all:
            rows = [r for r in rows if r["kind"] not in ("label", "return", "command_1b")
                    and not (r["kind"] == "write" and (r["storage"], r["index"]) in PRESENTATION_CELLS)
                    and not (r["kind"] == "write" and r["storage"] == "global_u8" and r["index"] is not None and r["index"] <= 20)
                    and not (r["kind"] == "write" and r["storage"] == "banked_u16" and r["index"] in (1, 2))]
        if args.json:
            print(json.dumps(rows, ensure_ascii=False))
        else:
            tails = archive.opaque_tails(entry)
            print(f"=== {entry} {lo}..{hi if hi is not None else 'end'} ({len(archive.instructions(entry))} instructions,"
                  f" opaque tails {[(t['source_offset'], t['end_offset']) for t in tails]})")
            for row in rows:
                print("  " + format_fact(row))
    return 0


def _format_summary(s: dict) -> str:
    lines = [f"=== {s['entry']}: {s['code_size']} bytes, {s['branches']} branches, {s['message_records']} message records,"
             f" opaque tails {[(t['source_offset'], t['end_offset']) for t in s['opaque_tails']]}"]
    if s["gate"]:
        lines.append(f"  gate: {format_fact(s['gate'])}")
        lines.append("  own gate writes: " + ", ".join(format_fact(w) for w in s["own_gate_writes"]))
    else:
        lines.append("  gate: NONE FOUND")
    q = s["question"]
    if q["routine40"]:
        lines.append(f"  question: routine-40 at {[r['offset'] for r in q['routine40']]} with definitions at {q['definitions']}")
    lines.append("  doors: " + ", ".join(format_fact(h) for h in s["doors"]))
    lines.append("  dispatches: " + ", ".join(format_fact(d) for d in s["dispatches"]))
    lines.append("  returns: " + ", ".join(str(r["offset"]) for r in s["returns"]))
    lines.append("  affection writes: " + ", ".join(format_fact(w) for w in s["affection_writes"]))
    lines.append("  stamp writes: " + ", ".join(format_fact(w) for w in s["stamp_writes"]))
    lines.append("  other banked writes: " + ", ".join(format_fact(w) for w in s["other_banked_writes"]))
    lines.append("  counters: " + ", ".join(format_fact(w) for w in s["counters"]))
    lines.append("  presentation branches: " + ", ".join(f"{b['offset']} {b['condition']}" for b in s["presentation_branches"]))
    lines.append("  free branches: " + ", ".join(f"{b['offset']} {b['condition']}" for b in s["free_branches"]))
    lines.append("  global_u8 writes: " + ", ".join(format_fact(w) for w in s["global_u8_writes"]))
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
