"""Build a kakyu_event_analysis_group/v14 flow profile from a hop spec and the original archive.

    py tools/build_event_flow_profile.py --arc "<mes.arc>" --spec analysis/foo_flow_spec.json \
        --out config/event_catalog/analysis_groups/foo_v14.json

EP-12 (2026-09-24, owner ruling): builds and proves the v14 flow shape; this
tool is not run against the authoritative archive by that task - a real
flow declaration is a later part, once the hotel-menu choice contract and
the train-leg map-location poll land (docs/spec/tech/content_tools.md's v14
entry). The spec names only each hop's own entry, its outcome's own
offset/status/target, message count, gates, answers, `poll_supplies` and
expected state, plus the origin's guard offsets and the route's
baseline/guard_cases/variants/choice_contracts: every record shape (`end`,
`op`, hash, source binding) is read from the original bytecode, and each
hop's own `entered_by` is derived from the hop before it by the same rule
`audit_event_analysis_group.py` checks (a nested-call/root-handoff hop's
record is the previous hop's own outcome; a resume hop's is the previous
hop's own return), never hand-supplied, so a shifted spec cannot silently
produce a mismatched chain.

EP-12 part 2 (2026-09-24): `--spec` accepts more than one spec file, each its
own route, merged into one profile - a group whose routes share a source-file
footprint but were each measured and built separately (the town route needed
no `poll_supplies`, the date5 route does). Every merged spec must declare the
same `group_id`; `source_members` is the union across specs, each entry's
document built once. A single `--spec` still produces the same single-route
profile as before.

EP-12 part 3 (2026-09-24): a spec may name `state_context` (the same object
v8/v6 routes carry, `{"kind": "fresh"}` or `{"kind": "original_calendar",
"entry": "START.MES", "table_sha256": ...}`), applied by the runtime flow
validator before `baseline`; a route with no `state_context` field defaults
to `{"kind": "fresh"}`. `"kind": "original_calendar"` needs no `entry`/
`table_sha256` in the spec - both default to `START.MES` and the audited
`CALENDAR_TABLE` fingerprint `build_event_route_profile.py` already computes
for the same archive (imported, not recomputed, so the two builders cannot
drift); a spec may still override either explicitly.

EP-12 (2026-10-04): a spec's `variants` are copied into the profile verbatim,
so a variant may carry the additive `answers` (`{hop_id, boundary_offset,
result_value}`) and `message_counts` (`{hop_id: n}`) fields the audit binds
(`docs/spec/tech/content_tools.md`, "Variant `answers` and `message_counts`").

EP-12 H (2026-10-04): a hop spec may name `segment_budget` (an integer, the
segments the route probe may spend running that hop; default 512 when absent),
copied into the hop verbatim and bound by the audit (`512 < n <= 4096`).
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from build_event_analysis_inventory import fingerprint
from build_event_route_profile import CALENDAR_TABLE
from extract_kakyu_arc import read_entries
from mes_analyzer_handoff import build_container, build_handoff

SCHEMA = "kakyu_event_analysis_group/v14"
TYPED = {"kind": "typed_record"}
STATUS_OP = {"script_return": "command_00", "script_handoff_boundary": "script_handoff_marker",
             "script_dispatch_boundary": "script_dispatch", "def_selection_boundary": "script_transfer"}


def _records(handoff: dict) -> dict:
    return {row["source_offset"]: row for row in handoff["typed_ir"]["instructions"]}


def _binding(handoff: dict, offset: int, end: int) -> dict:
    tail = next((t for t in handoff["typed_ir"]["opaque_boundaries"]
                 if t["source_offset"] <= offset < end <= t["end_offset"]), None)
    if tail is None:
        return dict(TYPED)
    return {"kind": "runtime_observation_in_opaque_tail", "offset": tail["source_offset"],
            "end": tail["end_offset"], "sha256": tail["raw_sha256"]}


def _outcome_record(entry: str, offset: int, status: str, target: str, handoffs: dict, codes: dict) -> dict:
    """Read the exact record at `offset` in `entry` and bind it as a hop's own
    `expected.outcome`, deriving `end`/`op`/the hash/the binding from the
    original bytecode - the spec names only the offset and the claimed status."""
    op = STATUS_OP.get(status)
    if op is None:
        raise SystemExit(f"unsupported hop outcome status: {status}")
    row = _records(handoffs[entry]).get(offset)
    if row is None or row["op"] != op:
        raise SystemExit(f"{entry}:{offset} is not a {status} record")
    end = row["end_offset"]
    out = {"offset": offset, "end": end, "op": op, "status": status,
           "source_binding": _binding(handoffs[entry], offset, end),
           "record_sha256": hashlib.sha256(codes[entry][offset:end]).hexdigest()}
    if status in ("script_handoff_boundary", "script_dispatch_boundary"):
        out["target"] = target.upper()
    return out


def _build_route(spec: dict, handoffs: dict, codes: dict) -> dict:
    origin_spec = spec["origin"]
    origin_entry = origin_spec["entry"]
    guard_offset, guard_end = origin_spec["guard_offset"], origin_spec["guard_end"]
    guard_row = _records(handoffs[origin_entry]).get(guard_offset)
    if guard_row is None or guard_row["op"] != "branch_if_not_true" or guard_row["end_offset"] != guard_end:
        raise SystemExit(f"{origin_entry}:{guard_offset} is not the declared branch")

    hops = []
    for hop_spec in spec["hops"]:
        hop_id, entry = hop_spec["hop_id"], hop_spec["entry"]
        outcome = _outcome_record(entry, hop_spec["outcome_offset"], hop_spec["outcome_status"],
                                   hop_spec.get("outcome_target", ""), handoffs, codes)
        if not hops:
            entered_by = {"kind": "origin"}
        else:
            kind = hop_spec["entered_by_kind"]
            record = hops[-1]["expected"]["outcome"]
            if kind == "resume" and hops[-1]["entered_by"].get("kind") != "nested_call":
                raise SystemExit(f"hop {hop_id} cannot resume after a {hops[-1]['entered_by'].get('kind')} hop")
            entered_by = {"kind": kind, "offset": record["offset"], "end": record["end"],
                          "op": record["op"], "record_sha256": record["record_sha256"],
                          "source_binding": record["source_binding"]}
        hop = {"hop_id": hop_id, "entry": entry, "entered_by": entered_by,
            "answers": hop_spec.get("answers", []), "gates": hop_spec.get("gates", []),
            "map_locations": hop_spec.get("map_locations", []),
            "poll_supplies": hop_spec.get("poll_supplies", []),
            "expected": {"message_count": hop_spec["message_count"], "outcome": outcome,
                         "expected_state": hop_spec.get("expected_state", [])}}
        # EP-12 H (2026-10-04): a hop spec's `segment_budget` is copied only when
        # present, so every profile built without one is byte-identical.
        if "segment_budget" in hop_spec:
            hop["segment_budget"] = hop_spec["segment_budget"]
        hops.append(hop)
    if not hops:
        raise SystemExit("a flow spec needs at least one hop")

    last_outcome = hops[-1]["expected"]["outcome"]
    origin_offset = origin_spec["offset"]
    state_context = spec.get("state_context", {"kind": "fresh"})
    if state_context.get("kind") == "original_calendar":
        state_context = {"kind": "original_calendar",
            "entry": state_context.get("entry", "START.MES"),
            "table_sha256": state_context.get("table_sha256", CALENDAR_TABLE)}
    return {
        "route_id": spec["route_id"],
        "state_context": state_context,
        "origin": {"entry": origin_entry, "offset": origin_offset,
            "guard": {"offset": guard_offset, "end": guard_end, "false_target": origin_spec["false_target"],
                "prefix_sha256": hashlib.sha256(
                    codes[origin_entry][origin_offset:hops[0]["expected"]["outcome"]["end"]]).hexdigest(),
                "record_sha256": hashlib.sha256(codes[origin_entry][guard_offset:guard_end]).hexdigest(),
                "source_binding": _binding(handoffs[origin_entry], guard_offset, guard_end)},
            "guard_cases": spec["guard_cases"]},
        "baseline": spec.get("baseline", []),
        "choice_contracts": spec.get("choice_contracts", []),
        "hops": hops,
        "terminal": {"entry": hops[-1]["entry"], **last_outcome},
        "variants": spec.get("variants", [{"variant_id": "default", "writes": [], "expected_state": []}]),
        "unresolved": spec.get("unresolved", []),
    }


def build_flow_profiles(arc: Path, specs: list[dict]) -> dict:
    group_ids = {spec["group_id"] for spec in specs}
    if len(group_ids) != 1:
        raise SystemExit("every spec merged into one profile must share a group_id")
    archive = arc.read_bytes()
    archive_sha256 = hashlib.sha256(archive).hexdigest()
    all_payloads = {name: archive[offset:offset + size] for name, offset, size in read_entries(arc)}
    members: list[str] = []
    for spec in specs:
        for name in spec["source_members"]:
            if name not in members:
                members.append(name)
    payloads, handoffs, codes = {}, {}, {}
    for name in members:
        payload = all_payloads[name]
        payloads[name] = payload
        handoffs[name] = build_handoff(payload, {"archive": "mes.arc", "entry": name,
            "source_kind": "original_arc", "archive_sha256": archive_sha256})
        codes[name] = build_container(payload)["_bytecode"]

    routes = [_build_route(spec, handoffs, codes) for spec in specs]
    route_ids = [route["route_id"] for route in routes]
    if len(set(route_ids)) != len(route_ids):
        raise SystemExit("merged specs must declare distinct route_id values")
    profile = {
        "schema": SCHEMA, "group_id": specs[0]["group_id"],
        "archive_sha256": archive_sha256,
        "source_members": [{"entry": name, "entry_sha256": hashlib.sha256(payloads[name]).hexdigest()}
                            for name in members],
        "routes": routes,
    }
    profile["payload_sha256"] = fingerprint(profile)
    return profile


def build_flow_profile(arc: Path, spec: dict) -> dict:
    return build_flow_profiles(arc, [spec])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arc", type=Path, required=True)
    parser.add_argument("--spec", type=Path, required=True, nargs="+",
                         help="one or more hop specs; more than one merges into a multi-route profile")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    specs = [json.loads(spec_path.read_text(encoding="utf-8")) for spec_path in args.spec]
    profile = build_flow_profiles(args.arc, specs)
    args.out.write_text(json.dumps(profile, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "out": str(args.out), "routes": len(profile["routes"]),
                       "hops": [len(route["hops"]) for route in profile["routes"]]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
