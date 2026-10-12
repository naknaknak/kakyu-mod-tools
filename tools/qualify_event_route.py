"""Measure, declare, audit, validate and mutation-test one EVENT route from its spec.

    py tools/qualify_event_route.py --elfimage "<ELFIMAGE dir>" --spec analysis/19c_l05_spec.json
        [--godot <exe>] [--register --after "FLOOR4 F03"] [--unresolved analysis/19c_l05_unresolved.txt]

Steps (each writes under analysis/<route>_*; the profile goes to
config/event_catalog/analysis_groups/<route>_v6.json for a root handoff,
<route>_v5.json / _v8.json / _v10.json for a nested call by the measured resume policy,
_v11.json / _v12.json when the spec supplies map locations):
  1. probe   - tools/content_suite/cli/measure_event_route.gd -> <route>_measure.json
               (a script the walk reaches outside the package is added to
               spec.members and the probe rerun, up to three times)
  2. build   - tools/build_event_route_profile.py -> the profile
  3. audit   - tools/audit_event_analysis_group.py -> <route>_audit.json (must be ok)
  4. validate- validators/validate_event_analysis_group.gd -> <route>_validator_raw.log (ok, failures [])
  5. mutate  - baseline message_count + 1 must fail the validator on the callee
               message-count check; outcome.offset + 1 (and, for a nested call,
               resume.outcome.offset + 1) must fail the audit; with map locations,
               the next location instead must fail the validator; with bypass
               variants, a bypass's message_count + 1 must fail the validator
  6. register (optional) - tools/register_analysis_group.py + the focused batch check
Stops at the first failing step and prints the raw line. Godot runs in the
foreground; nothing is left running.
"""
from __future__ import annotations

import argparse
import copy
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_event_analysis_inventory import fingerprint  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft/WinGet/Packages" / \
    "GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe"
PROBE = "res://tools/content_suite/cli/measure_event_route.gd"
VALIDATOR = "res://tools/content_suite/validators/validate_event_analysis_group.gd"


def run(cmd: list[str], log: Path | None = None, timeout: int = 900) -> subprocess.CompletedProcess:
    completed = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                               errors="replace", timeout=timeout)
    if log is not None:
        log.write_text(completed.stdout + completed.stderr, encoding="utf-8")
    return completed


def godot(exe: Path, script: str, *args: str, log: Path | None = None) -> subprocess.CompletedProcess:
    return run([str(exe), "--headless", "--path", ".", "--script", script, "--", *args], log)


def validator_line(text: str) -> tuple[str, str, str]:
    ok = re.search(r'"ok":(true|false)', text)
    checks = re.search(r'"checks":(\d+)', text)
    failures = re.search(r'"failures":(\[[^\]]*\])', text)
    return (ok.group(1) if ok else "?", checks.group(1) if checks else "?", failures.group(1) if failures else "?")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--elfimage", required=True)
    parser.add_argument("--spec", required=True)
    parser.add_argument("--godot", default=str(DEFAULT_GODOT))
    parser.add_argument("--arc", default=None, help="defaults to <elfimage>/mes.arc")
    parser.add_argument("--unresolved", default=None)
    parser.add_argument("--profile-out", default=None)
    parser.add_argument("--skip-probe", action="store_true", help="reuse an existing <route>_measure.json")
    parser.add_argument("--only-mutations", action="store_true", help="rerun step 5 on the existing profile")
    parser.add_argument("--register", action="store_true")
    parser.add_argument("--after", default=None)
    args = parser.parse_args(argv)

    spec_path = Path(args.spec)
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    route = spec["route"]
    arc = args.arc or str(Path(args.elfimage) / "mes.arc")
    godot_exe = Path(args.godot)
    analysis = ROOT / "analysis"
    measure = analysis / f"{route}_measure.json"

    if args.only_mutations:
        profile = Path(args.profile_out) if args.profile_out else ROOT / "config/event_catalog/analysis_groups" / f"{route}_v6.json"
        return mutations(args, route, profile, godot_exe, analysis)
    for attempt in range(4):
        if not args.skip_probe:
            print(f"[1/5] probe {spec_path.name}" + (f" (round {attempt + 1})" if attempt else ""))
            completed = godot(godot_exe, PROBE, args.elfimage, str(spec_path), str(measure), log=analysis / f"{route}_measure_raw.log")
            if "MEASURED_OK" not in completed.stdout:
                print(completed.stdout[-1500:], completed.stderr[-1500:])
                return 1
        measured = json.loads(measure.read_text(encoding="utf-8"))
        missing = missing_members(measured.get("not_a_package_member", []), spec["members"])
        if not missing:
            break
        if args.skip_probe or attempt == 3:
            print("STOP: not a package member:", measured["not_a_package_member"], "- add them to spec.members and rerun")
            return 1
        # The walk reached a script the spec did not list (a resume-path dispatch,
        # a picture script): add it as a source member and measure again.
        core = [m for m in spec["members"] if m in ("START.MES", "DEF_MAIN.MES", "LIBLARY.LIB")]
        spec["members"] = [m for m in spec["members"] if m not in core] + missing + core
        spec_path.write_text(json.dumps(spec, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        print("  added members", missing, "- measuring again")
    if not measured.get("prefix_reached_dispatch", True):
        print("STOP: the baseline prefix did not reach the dispatch; check the seed:", measured.get("prefix", {}).get("stop"))
        return 1
    profile = Path(args.profile_out) if args.profile_out else \
        ROOT / "config/event_catalog/analysis_groups" / f"{route}_{profile_suffix(spec, measured)}.json"

    print(f"[2/5] build {profile.name}")
    build_cmd = [sys.executable, "tools/build_event_route_profile.py", "--arc", arc, "--spec", str(spec_path),
                 "--measure", str(measure), "--out", str(profile)]
    if args.unresolved:
        build_cmd += ["--unresolved", args.unresolved]
    completed = run(build_cmd)
    print(completed.stdout.rstrip()[-2500:])
    if completed.returncode != 0:
        print(completed.stderr[-2000:])
        return 1

    print("[3/5] audit")
    completed = run([sys.executable, "tools/audit_event_analysis_group.py", args.elfimage, "--profile", str(profile)],
                    log=analysis / f"{route}_audit.json")
    if '"ok":true' not in completed.stdout.replace(" ", ""):
        print("AUDIT REJECTED:", completed.stdout[:400], completed.stderr[-400:])
        return 1
    print("  audit ok")

    print("[4/5] validate")
    completed = godot(godot_exe, VALIDATOR, args.elfimage, str(profile), log=analysis / f"{route}_validator_raw.log")
    ok, checks, failures = validator_line(completed.stdout + completed.stderr)
    print(f"  validator ok={ok} checks={checks} failures={failures}")
    if ok != "true" or failures != "[]":
        return 1

    if mutations(args, route, profile, godot_exe, analysis) != 0:
        return 1

    if args.register:
        if not args.after:
            print("--register needs --after")
            return 1
        completed = run([sys.executable, "tools/register_analysis_group.py", "--name", spec["check_name"],
                         "--profile", profile.name, "--after", args.after, "--elfimage", args.elfimage])
        print(completed.stdout.rstrip(), completed.stderr.rstrip()[-400:])
        if completed.returncode != 0:
            return 1
    print(f"DONE {route}: checks={checks} profile={profile}")
    return 0


def missing_members(reports: list, members: list) -> list:
    """Entry names the probe reported as outside the package, not yet listed."""
    found = []
    for text in reports:
        match = re.search(r"entry (\S+) is not a package member", str(text))
        if match and match.group(1).upper() not in [m.upper() for m in members] and match.group(1).upper() not in found:
            found.append(match.group(1).upper())
    return found


def profile_suffix(spec: dict, measured: dict) -> str:
    """v6 for a root handoff; v10 when the nested call's resume ends in the
    caller's own loop, v8 when it stops at the caller's own routine-40, v5
    otherwise (a natural handoff or a dependency stop)."""
    nested = spec.get("form") == "nested_call" or int(spec.get("call", {}).get("command", 14)) == 15
    contracts = bool(spec.get("map_location_contracts"))
    if not nested:
        return "v11" if contracts else "v6"
    if contracts:
        return "v12"
    blocks = measured["results"].values() if "results" in measured else [measured]
    kinds = {str(b.get("resume", {}).get("stop", {}).get("kind", "")) for b in blocks}
    if "loop_boundary" in kinds:
        return "v10"
    return "v8" if "def_selection_boundary" in kinds else "v5"


def mutations(args, route: str, profile: Path, godot_exe: Path, analysis: Path) -> int:
    print("[5/5] mutations")
    document = json.loads(profile.read_text(encoding="utf-8"))
    mutated = copy.deepcopy(document)
    first_route = mutated["routes"][0]
    first_route["variants"][0]["message_count"] += 1
    mutation_a = analysis / f"{route}_mutation_message_count.json"
    mutated["payload_sha256"] = fingerprint({k: v for k, v in mutated.items() if k != "payload_sha256"})
    mutation_a.write_text(json.dumps(mutated, ensure_ascii=False, indent=2), encoding="utf-8")
    completed = godot(godot_exe, VALIDATOR, args.elfimage, str(mutation_a), log=analysis / f"{route}_mutation_validator_raw.log")
    ok_a, _, failures_a = validator_line(completed.stdout + completed.stderr)
    print(f"  message_count+1: ok={ok_a} failures={failures_a}")
    if ok_a != "false" or "callee message observation count" not in failures_a:
        return 1
    mutated = copy.deepcopy(document)
    mutated["routes"][-1]["outcome"]["offset"] += 1
    mutation_b = analysis / f"{route}_mutation_outcome_offset.json"
    mutated["payload_sha256"] = fingerprint({k: v for k, v in mutated.items() if k != "payload_sha256"})
    mutation_b.write_text(json.dumps(mutated, ensure_ascii=False, indent=2), encoding="utf-8")
    completed = run([sys.executable, "tools/audit_event_analysis_group.py", args.elfimage, "--profile", str(mutation_b)],
                    log=analysis / f"{route}_mutation_audit_raw.log")
    print(f"  outcome.offset+1: {completed.stdout.strip()[:160]}")
    if '"ok": false' not in completed.stdout and '"ok":false' not in completed.stdout:
        return 1
    if "resume" in document["routes"][-1]:
        mutated = copy.deepcopy(document)
        mutated["routes"][-1]["resume"]["outcome"]["offset"] += 1
        mutation_c = analysis / f"{route}_mutation_resume_offset.json"
        mutated["payload_sha256"] = fingerprint({k: v for k, v in mutated.items() if k != "payload_sha256"})
        mutation_c.write_text(json.dumps(mutated, ensure_ascii=False, indent=2), encoding="utf-8")
        completed = run([sys.executable, "tools/audit_event_analysis_group.py", args.elfimage, "--profile", str(mutation_c)],
                        log=analysis / f"{route}_mutation_resume_audit_raw.log")
        print(f"  resume.outcome.offset+1: {completed.stdout.strip()[:160]}")
        if '"ok": false' not in completed.stdout and '"ok":false' not in completed.stdout:
            return 1
    if document["routes"][0].get("map_location_contracts"):
        # 0.319.0: the location must be what selects the route. Supplying the
        # next location instead must send the walk elsewhere, so the prefix
        # no longer reaches the intro or the named run no longer spends it.
        mutated = copy.deepcopy(document)
        contract = mutated["routes"][0]["map_location_contracts"][0]
        contract["locations"] = [contract["locations"][0] + 1] + contract["locations"][1:]
        mutation_d = analysis / f"{route}_mutation_map_location.json"
        mutated["payload_sha256"] = fingerprint({k: v for k, v in mutated.items() if k != "payload_sha256"})
        mutation_d.write_text(json.dumps(mutated, ensure_ascii=False, indent=2), encoding="utf-8")
        completed = godot(godot_exe, VALIDATOR, args.elfimage, str(mutation_d), log=analysis / f"{route}_mutation_map_location_raw.log")
        ok_d, _, failures_d = validator_line(completed.stdout + completed.stderr)
        print(f"  map location+1: ok={ok_d} failures={failures_d[:200]}")
        if ok_d != "false" or not any(marker in failures_d for marker in
                                      ("reaches exact intro", "spends map locations", "callee message observation count",
                                       "map location declared at", "bypass reaches exact caller handoff")):
            return 1
    if document["routes"][0].get("bypass_variants"):
        # A bypass is replayed like a variant: its message count must be exact.
        mutated = copy.deepcopy(document)
        mutated["routes"][0]["bypass_variants"][0]["message_count"] += 1
        mutation_e = analysis / f"{route}_mutation_bypass_message_count.json"
        mutated["payload_sha256"] = fingerprint({k: v for k, v in mutated.items() if k != "payload_sha256"})
        mutation_e.write_text(json.dumps(mutated, ensure_ascii=False, indent=2), encoding="utf-8")
        completed = godot(godot_exe, VALIDATOR, args.elfimage, str(mutation_e), log=analysis / f"{route}_mutation_bypass_raw.log")
        ok_e, _, failures_e = validator_line(completed.stdout + completed.stderr)
        print(f"  bypass message_count+1: ok={ok_e} failures={failures_e[:200]}")
        if ok_e != "false" or "bypass message observation count" not in failures_e:
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
