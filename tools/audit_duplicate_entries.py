"""Audit archive entries whose message records are byte-identical.

Two entries can carry the same scene without being the same file: the shipped
archive holds a replay gallery whose entries repeat event content with the
event-specific logic stripped, and it holds at least one pre-voice build kept
beside its replacement.

This tool finds those relationships without retaining any message text. Each
entry is reduced to the digest of its per-message record hashes, entries sharing
a digest are grouped, and each group is reported with the structural figures
that tell a gallery copy apart from an abandoned build: record counts, entry
sizes and voice-marker counts.

It also reports where the gallery is dispatched from, because that is the part
the strict aligned decoder cannot see: every gallery dispatch lives in an opaque
tail, which is why the corpus inventory counted those entries as never
dispatched.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import defaultdict
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v6
from build_event_analysis_inventory import fingerprint
from extract_kakyu_arc import read_entries

SCHEMA = "kakyu_duplicate_entries_audit/v1"
NAMING_SCHEMA = "kakyu_mes_dispatch_naming_audit/v1"
ARCHIVE_SHA = "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
DEFAULT_NAMING = Path("config/event_catalog/dispatch_naming_v1.json")

# Measured 2026-09-10 over the authoritative archive; the gallery naming rows
# re-measured 2026-09-13 under Core 0.316.0, when command 0x0D became one system
# call and the strict decode reached every envelope the opaque tails had held.
EXPECTED_ENTRIES_WITH_MESSAGES = 954
EXPECTED_DISTINCT_DIGESTS = 903
EXPECTED_SHARED_DIGESTS = 49
EXPECTED_GALLERY_ENTRIES = 365
EXPECTED_GALLERY_MENUS = 13
EXPECTED_GALLERY_STRICT_DISPATCHES = 365
EXPECTED_GALLERY_WITHOUT_ENVELOPE = 0
EXPECTED_NEWLY_NAMED_ENTRIES = 0
EXPECTED_EVENT_TWINS = 29
EXPECTED_EVENT_GALLERY_TWINS = 27
EXPECTED_GROUP_KINDS = {
    "gallery_copy_of_event": 27,
    "gallery_copy_of_other": 13,
    "gallery_internal": 4,
    "event_only": 1,
    "non_gallery": 4,
}
EXPECTED_GALLERY_COPY_MEMBERS = 42
EXPECTED_GALLERY_COPY_MEMBERS_NOT_LARGER_THAN_SOURCE = 42
EXPECTED_GALLERY_COPY_MEMBERS_WITH_EQUAL_VOICE_MARKERS = 42
EXPECTED_GALLERY_ENTRIES_BY_ENVELOPE_COUNT = {"1": 365}


def profile(payload: bytes) -> dict[str, Any]:
    document = mes_basic_block_ir_v6.decode_mes(payload, {"entry": "scanned"})
    seen: dict[int, dict[str, Any]] = {}
    for node in document.get("nodes", []):
        for row in node.get("instructions", []):
            seen.setdefault(int(row["sourceOffset"]), row)
    hashes, voice = [], 0
    for offset in sorted(seen):
        op = str(seen[offset].get("op", ""))
        if op == "text":
            hashes.append(hashlib.sha256(bytes.fromhex(str(seen[offset].get("rawHex", "")))).hexdigest())
        elif op == "voice_marker":
            voice += 1
    return {
        "entry_size": len(payload),
        "record_count": len(seen),
        "message_records": len(hashes),
        "voice_markers": voice,
        "message_digest": hashlib.sha256("".join(hashes).encode("ascii")).hexdigest() if hashes else "",
    }


def classify_group(names: list[str]) -> str:
    """Classify a shared-digest group by SCENE_/EVENT filename prefix only.

    The prefixes are used strictly as an index into the group's membership;
    the relation the group itself records is byte-identical message content.
    """
    scene = [name for name in names if name.startswith("SCENE_")]
    event = [name for name in names if name.startswith("EVENT")]
    other = [name for name in names if name not in scene and name not in event]
    total = len(names)
    if len(event) == 1 and len(other) == 0:
        return "gallery_copy_of_event"
    if len(other) == 1 and len(event) == 0:
        return "gallery_copy_of_other"
    if len(scene) == total:
        return "gallery_internal"
    if len(event) == total:
        return "event_only"
    if len(scene) == 0 and len(event) == 0:
        return "non_gallery"
    raise ValueError(f"Group composition fits no known kind: {names}")


def audit(arc: Path, naming: dict) -> dict[str, Any]:
    if naming.get("schema") != NAMING_SCHEMA or naming.get("archive_sha256") != ARCHIVE_SHA:
        raise ValueError("Unsupported or foreign dispatch naming audit")
    blob = arc.read_bytes()
    if hashlib.sha256(blob).hexdigest() != ARCHIVE_SHA:
        raise ValueError("Original archive identity differs")
    entries = [row for row in read_entries(arc) if row[0].lower().endswith((".mes", ".lib"))]
    profiles = {name.upper(): profile(blob[offset:offset + size])
                for name, offset, size in entries}

    grouped: dict[str, list[str]] = defaultdict(list)
    for name, row in profiles.items():
        if row["message_records"]:
            grouped[row["message_digest"]].append(name)
    with_messages = sum(1 for row in profiles.values() if row["message_records"])
    shared = {digest: sorted(names) for digest, names in grouped.items() if len(names) > 1}
    if with_messages != EXPECTED_ENTRIES_WITH_MESSAGES or len(grouped) != EXPECTED_DISTINCT_DIGESTS:
        raise ValueError("Message-bearing entry or digest counts changed")
    if len(shared) != EXPECTED_SHARED_DIGESTS:
        raise ValueError("The number of shared message digests changed")

    newly_named = naming.get("newly_named_entries", [])
    newly_named_set = set(newly_named)

    envelope_callers: dict[str, set[str]] = defaultdict(set)
    for row in naming.get("gallery_envelopes", []):
        envelope_callers[row["target"]].add(row["caller"])
    gallery = sorted(name for name in profiles if name.startswith("SCENE_"))
    menus = sorted({caller for name in gallery for caller in envelope_callers.get(name, set())})
    strict_gallery = [name for name in gallery if name not in newly_named_set]
    gallery_without_envelope = [name for name in gallery if name not in envelope_callers]
    if len(gallery) != EXPECTED_GALLERY_ENTRIES or len(menus) != EXPECTED_GALLERY_MENUS:
        raise ValueError("The gallery entry or menu count changed")
    if len(strict_gallery) != EXPECTED_GALLERY_STRICT_DISPATCHES:
        raise ValueError("The gallery entries named by strictly decoded dispatch records changed")
    if len(gallery_without_envelope) != EXPECTED_GALLERY_WITHOUT_ENVELOPE:
        raise ValueError("A gallery entry is not named by any dispatch envelope")
    if len(newly_named) != EXPECTED_NEWLY_NAMED_ENTRIES:
        raise ValueError("The set of entries named only in opaque tails changed")

    event_twins = []
    for name in sorted(n for n in profiles if n.startswith("EVENT")):
        digest = profiles[name]["message_digest"]
        twins = [t for t in grouped.get(digest, []) if t != name]
        if twins:
            event_twins.append({"entry": name, "twins": twins,
                                "gallery_twin": all(t.startswith("SCENE_") for t in twins)})
    if len(event_twins) != EXPECTED_EVENT_TWINS:
        raise ValueError("The number of EVENT entries with an identical twin changed")
    event_gallery_twins = sum(1 for row in event_twins if row["gallery_twin"])
    if event_gallery_twins != EXPECTED_EVENT_GALLERY_TWINS:
        raise ValueError("The number of EVENT entries whose twin is entirely gallery entries changed")

    ordered_groups = sorted(shared.items(),
                            key=lambda kv: (-profiles[kv[1][0]]["message_records"], kv[1][0]))
    groups: list[dict[str, Any]] = []
    kind_counts: dict[str, int] = defaultdict(int)
    gallery_copy_members = 0
    gallery_copy_not_larger = 0
    gallery_copy_equal_voice = 0
    for digest, names in ordered_groups:
        kind = classify_group(names)
        kind_counts[kind] += 1
        group: dict[str, Any] = {"message_digest": digest, "entries": names, "kind": kind,
                                 "profiles": {name: profiles[name] for name in names}}
        if kind in ("gallery_copy_of_event", "gallery_copy_of_other"):
            source = next(name for name in names if not name.startswith("SCENE_"))
            gallery_members = [name for name in names if name.startswith("SCENE_")]
            group["source"] = source
            group["gallery_members"] = gallery_members
            source_profile = profiles[source]
            for member in gallery_members:
                member_profile = profiles[member]
                gallery_copy_members += 1
                if (member_profile["record_count"] <= source_profile["record_count"]
                        and member_profile["entry_size"] <= source_profile["entry_size"]):
                    gallery_copy_not_larger += 1
                if member_profile["voice_markers"] == source_profile["voice_markers"]:
                    gallery_copy_equal_voice += 1
        groups.append(group)
    group_kinds = dict(kind_counts)
    if group_kinds != EXPECTED_GROUP_KINDS:
        raise ValueError("The group composition kinds changed")
    if (gallery_copy_members != EXPECTED_GALLERY_COPY_MEMBERS
            or gallery_copy_not_larger != EXPECTED_GALLERY_COPY_MEMBERS_NOT_LARGER_THAN_SOURCE
            or gallery_copy_equal_voice != EXPECTED_GALLERY_COPY_MEMBERS_WITH_EQUAL_VOICE_MARKERS):
        raise ValueError("The gallery-copy structural comparison against its source changed")

    gallery_set = set(gallery)
    gallery_rows = [row for row in naming.get("gallery_envelopes", [])
                    if row["target"] in gallery_set]
    dispatch_counts: dict[str, int] = defaultdict(int)
    envelopes_per_entry: dict[str, int] = defaultdict(int)
    for row in gallery_rows:
        dispatch_counts[str(row["command"])] += 1
        envelopes_per_entry[row["target"]] += 1
    gallery_dispatch_commands = dict(dispatch_counts)
    if gallery_dispatch_commands != {"15": len(gallery_rows)}:
        raise ValueError("A gallery dispatch uses a command other than 15")
    entries_by_envelope_count: dict[str, int] = defaultdict(int)
    for name in gallery:
        entries_by_envelope_count[str(envelopes_per_entry.get(name, 0))] += 1
    gallery_entries_by_envelope_count = dict(entries_by_envelope_count)
    if gallery_entries_by_envelope_count != EXPECTED_GALLERY_ENTRIES_BY_ENVELOPE_COUNT:
        raise ValueError("The distribution of envelope counts per gallery entry changed")

    report = {
        "schema": SCHEMA,
        "archive_sha256": ARCHIVE_SHA,
        "entries_with_messages": with_messages,
        "distinct_message_digests": len(grouped),
        "shared_message_digests": len(shared),
        "gallery_entries": len(gallery),
        "gallery_menus": menus,
        "gallery_dispatches_in_strict_decode": len(strict_gallery),
        "gallery_entries_without_envelope": len(gallery_without_envelope),
        "event_entries_with_twin": len(event_twins),
        "event_entries_with_gallery_twin": event_gallery_twins,
        "group_kinds": group_kinds,
        "gallery_copy_members": gallery_copy_members,
        "gallery_copy_members_not_larger_than_source": gallery_copy_not_larger,
        "gallery_copy_members_with_equal_voice_markers": gallery_copy_equal_voice,
        "gallery_dispatch_commands": gallery_dispatch_commands,
        "gallery_entries_by_envelope_count": gallery_entries_by_envelope_count,
        "event_twins": event_twins,
        "groups": groups,
        "evidence_boundary": (
            "identical message records are identical content, not a claim about which"
            " entry the product treats as the owning route; the SCENE_/EVENT filename"
            " prefixes are used only as an index to label a group's composition, and the"
            " measured relation a group records is byte-identical message records"
        ),
    }
    report["payload_sha256"] = fingerprint(report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--naming", type=Path, default=DEFAULT_NAMING)
    parser.add_argument("--check", type=Path)
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    report = audit(arguments.archive, json.loads(arguments.naming.read_text(encoding="utf-8")))
    if arguments.check and json.loads(arguments.check.read_text(encoding="utf-8")) != report:
        raise ValueError("Tracked duplicate-entry report does not reproduce")
    if arguments.output:
        arguments.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                                    encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items()
                      if key not in ("groups", "event_twins")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
