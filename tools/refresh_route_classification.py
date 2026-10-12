"""Regenerate the route classification, report the delta against HEAD, optionally install it.

    py tools/refresh_route_classification.py --arc "<mes.arc>" [--install] [--manifest analysis/x.json]

Runs tools/classify_event_routes.py into a scratch file, prints bound entries,
the confidence split and which rows became bound or moved since the committed
classification, and with --install copies it over
config/event_catalog/route_classification_v1.json and re-runs the checker.
With --manifest it fills that manifest's expect_bound / expect_split /
expect_newly / expect_moved fields for a fold script.
"""
from __future__ import annotations

import argparse
import collections
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLASSIFIER = ROOT / "tools" / "classify_event_routes.py"
INVENTORY = ROOT / "analysis" / "event-corpus-inventory-2026-10-02.json"
INSTALLED = ROOT / "config" / "event_catalog" / "route_classification_v1.json"


# The three analysis-group confidences of the 2026-09-14 ruling, in the order
# the detail column prints them: a route of its own, a measured part in another
# entry's route, membership only.
GROUP_CONFIDENCES = ("analysis_group_qualified_route", "analysis_group_measured_participant",
                     "analysis_group_member_unmeasured")


def summary(document: dict) -> tuple[int, str, str]:
    """Bound entries, the catalog/group/structural split, and the group detail."""
    counts = collections.Counter(r["confidence"] for r in document["rows"])
    grouped = sum(counts[name] for name in GROUP_CONFIDENCES)
    split = "%d/%d/%d" % (counts["qualified_catalog_scope"], grouped,
                          counts["structural_confirmed_semantics_unresolved"])
    detail = "/".join(str(counts[name]) for name in GROUP_CONFIDENCES)
    return int(document["analysis_group_bound_entries"]), split, detail


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--arc", required=True)
    parser.add_argument("--inventory", default=str(INVENTORY))
    parser.add_argument("--scratch", default=str(ROOT / "analysis" / "route_classification_regen.json"))
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--manifest", default=None)
    args = parser.parse_args(argv)
    scratch = Path(args.scratch)
    if scratch.exists():
        scratch.unlink()
    subprocess.run([sys.executable, str(CLASSIFIER), args.arc, args.inventory, "--output", str(scratch)],
                   cwd=ROOT, check=True, capture_output=True)
    new = json.loads(scratch.read_text(encoding="utf-8"))
    old = json.loads(subprocess.run(["git", "show", "HEAD:config/event_catalog/route_classification_v1.json"],
                                    cwd=ROOT, capture_output=True, text=True, encoding="utf-8").stdout)
    bound = lambda d: {x["entry"] for x in d["rows"] if x.get("analysis_group_evidence")}
    newly = sorted(bound(new) - bound(old))
    moved = sorted(r["entry"] for r, o in zip(new["rows"], old["rows"]) if r["confidence"] != o["confidence"])
    new_bound, new_split, new_detail = summary(new)
    old_bound, old_split, old_detail = summary(old)
    print(f"HEAD: bound {old_bound} split {old_split} (groups {old_detail})")
    print(f"regen: bound {new_bound} split {new_split} (groups {new_detail})")
    print("newly bound:", newly)
    print("moved:", moved)
    # Confidence moves are not the whole delta: also report class moves and the catalog rebind.
    old_class = {row["entry"]: row["class"] for row in old["rows"]}
    class_moves = sorted((r["entry"], old_class.get(r["entry"]), r["class"])
                         for r in new["rows"] if r["class"] != old_class.get(r["entry"]))
    print("class moves:", class_moves)
    print("catalog rebind:", {k: [old.get(k), new.get(k)] for k in sorted(set(old) | set(new))
                              if "catalog" in k and old.get(k) != new.get(k)})
    if args.manifest:
        path = Path(args.manifest)
        manifest = json.loads(path.read_text(encoding="utf-8"))
        manifest.update({"old_bound": old_bound, "old_split": old_split, "expect_bound": new_bound,
                         "expect_split": new_split, "expect_newly": newly, "expect_moved": moved})
        path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        print("manifest updated:", path)
    if args.install:
        INSTALLED.write_bytes(scratch.read_bytes())
        completed = subprocess.run([sys.executable, str(CLASSIFIER), args.arc, args.inventory, "--check", str(INSTALLED)],
                                   cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
        print("installed and checked:", "ok" if completed.returncode == 0 else completed.stdout[-400:])
        return completed.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
