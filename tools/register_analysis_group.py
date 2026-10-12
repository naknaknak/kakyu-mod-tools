"""Register an analysis-group profile in the original batch and run its focused check.

    py tools/register_analysis_group.py --name "19C L05" --profile 19c_l05_v6.json --after "FLOOR4 F03" \
        --elfimage "<ELFIMAGE dir>"

Since TD-32 part 1 (Core 0.357.0, 2026-09-21) the checks are data:
`config/validation/checks_v1.json` (`kakyu_validation_checks/v1`) carries one
`analysis_group`-family entry per tracked profile directly in its `checks`
array (`tools/README.md`, "Since 2026-09-21 (TD-32 part 1)... each analysis
profile has its own `analysis_group` entry"; `tools/content_suite/run_headless_validation.py`'s
`build_checks()` loads it and does not expand this family at runtime, unlike
the Godot test scenes). This tool inserts one such entry right after the
entry named `--after` (matching the existing 01M B03/date entries' shape:
`kind: godot_script`, `script:
res://tools/content_suite/validators/validate_event_analysis_group.gd`,
`arguments: ["{source_root}", "config/event_catalog/analysis_groups/<profile>"]`,
`timeout: 300`, `groups: ["original_corpus"]`, `requires: ["elfimage"]`,
`tier: "full"`, `family: "analysis_group"`, `profile: "config/event_catalog/analysis_groups/<profile>"`),
refusing a duplicate name, then runs `run_headless_validation.py --check
"original event analysis <name>"` and prints ok / checks / failures from the
report. Use --no-check to only register. (Before TD-32 part 1 this inserted a
literal Python tuple into `run_headless_validation.py` itself; that file no
longer carries per-group tuples, so the old form silently found no anchor.)
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "tools" / "content_suite" / "run_headless_validation.py"
REGISTRY = ROOT / "config" / "validation" / "checks_v1.json"


def register(name: str, profile: str, after: str) -> bool:
    document = json.loads(REGISTRY.read_text(encoding="utf-8"))
    checks = document["checks"]
    full_name = f"original event analysis {name}"
    if any(c.get("name") == full_name for c in checks):
        print("already registered:", name)
        return False
    after_name = f"original event analysis {after}"
    anchor = next((i for i, c in enumerate(checks) if c.get("name") == after_name), None)
    if anchor is None:
        raise SystemExit(f"anchor not found: {after_name}")
    profile_path = f"config/event_catalog/analysis_groups/{profile}"
    entry = {
        "name": full_name,
        "kind": "godot_script",
        "script": "res://tools/content_suite/validators/validate_event_analysis_group.gd",
        "arguments": ["{source_root}", profile_path],
        "timeout": 300,
        "groups": ["original_corpus"],
        "requires": ["elfimage"],
        "tier": "full",
        "family": "analysis_group",
        "profile": profile_path,
    }
    checks.insert(anchor + 1, entry)
    REGISTRY.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("registered", name, "after", after)
    return True


def check(name: str, elfimage: str, report: Path) -> int:
    cmd = [sys.executable, str(RUNNER), "--elfimage", elfimage, "--check", f"original event analysis {name}",
           "--report", str(report)]
    completed = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    payload = json.loads(report.read_text(encoding="utf-8"))
    inner = json.loads(payload["payload_json"]) if "payload_json" in payload else payload
    checks = inner.get("checks", [])
    print("batch:", inner.get("status"), "passed", inner.get("passed"), "failed", inner.get("failed"))
    match = re.search(r'"checks":(\d+),"failures":(\[[^\]]*\]).*?"ok":(true|false)', completed.stdout + completed.stderr)
    if match:
        print(f'validator: ok={match.group(3)} checks={match.group(1)} failures={match.group(2)}')
    else:
        print("validator line not found in output; tail:", (completed.stdout + completed.stderr)[-600:])
    return 0 if inner.get("status") == "passed" and all(c.get("status") == "passed" for c in checks) else 1


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--name", required=True, help='e.g. "19C L05"')
    parser.add_argument("--profile", required=True, help="file name under config/event_catalog/analysis_groups")
    parser.add_argument("--after", required=True, help='name of the entry to insert after, e.g. "FLOOR4 F03"')
    parser.add_argument("--elfimage", default=None)
    parser.add_argument("--no-check", action="store_true")
    parser.add_argument("--report", default=None)
    args = parser.parse_args(argv)
    if not (ROOT / "config/event_catalog/analysis_groups" / args.profile).exists():
        raise SystemExit(f"profile not on disk: {args.profile}")
    register(args.name, args.profile, args.after)
    if args.no_check:
        return 0
    if not args.elfimage:
        raise SystemExit("--elfimage is required to run the check")
    report = Path(args.report) if args.report else ROOT / "analysis" / (args.profile.replace(".json", "") + "_check_report.json")
    return check(args.name, args.elfimage, report)


if __name__ == "__main__":
    raise SystemExit(main())
