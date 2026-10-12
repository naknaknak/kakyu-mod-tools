"""Read mes.arc entries through libai5's grammar (a second, complete decoder).

    py tools/libai5_bridge/mes_libai5.py --arc "<mes.arc>" ENTRY [lo hi]   list statements (code-relative)
    py tools/libai5_bridge/mes_libai5.py --arc "<mes.arc>" --coverage       parse every entry; histogram
    py tools/libai5_bridge/mes_libai5.py --arc "<mes.arc>" --reconcile      map the repo's opaque tails to
                                                                             libai5 statements (slow: builds
                                                                             every handoff)

Needs analysis/ext/mesdump.exe (tools/libai5_bridge/build_mesdump.py). The
entry bytes travel through a pipe; nothing from the archive is written to disk.
The grammar name defaults to "nonomura", the libai5 game whose statement table
(address table, 0x0B..0x1F numbering, DEF_SUB / CALL_SUB) matches this archive.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from extract_kakyu_arc import read_entries  # noqa: E402

MESDUMP = ROOT / "analysis" / "ext" / "mesdump.exe"
DEFAULT_GAME = "nonomura"
# libai5's internal statement enum (mes.h) -> the vocabulary this repo uses.
OP_NAMES = {0: "END (script_return)", 1: "ZENKAKU text", 2: "HANKAKU text", 3: "SET_FLAG_CONST (global_u8 write run)",
            4: "SET_VAR16 (state_u16 write run)", 5: "SET_FLAG_EXPR", 6: "PTR16_SET8 (banked_u8 write)",
            7: "PTR16_SET16 (banked_u16 write)", 8: "PTR32_SET32", 9: "PTR32_SET16", 10: "PTR32_SET8",
            11: "JZ (branch_if_not_true)", 12: "JMP", 13: "SYS (system call)", 14: "JMP_MES (root handoff)",
            15: "CALL_MES (nested call)", 16: "DEF_MENU (choice definition)", 17: "CALL_PROC (definition invoke)",
            18: "UTIL", 19: "LINE", 20: "DEF_PROC", 21: "MENU_EXEC (selection loop)", 22: "SET_VAR32",
            23: "OP_0x17 (entry prologue)", 24: "OP_0x18", 25: "OP_0x19", 26: "OP_0x1A", 27: "OP_0x1B",
            28: "DEF_SUB (library routine registration)", 29: "CALL_SUB (shared routine transfer)",
            30: "OP_0x1E", 31: "OP_0x1F (source-line marker)", 32: "SET_ARG_CONST (argument slot write)",
            33: "SET_ARG_EXPR"}
STMT_RE = re.compile(r"STMT (\d+) (\d+) (\d+) ?(.*)")


@dataclass(frozen=True)
class Statement:
    address: int
    end: int
    op: int
    text: str

    @property
    def op_name(self) -> str:
        return OP_NAMES.get(self.op, f"op {self.op}")

    @property
    def sys_function(self) -> int | None:
        match = re.match(r"System\.function\[(\d+)\]", self.text)
        return int(match.group(1)) if match else None


def parse_output(text: str) -> tuple[list[Statement], str]:
    """Statements and the trailing OK/FAIL line from mesdump's `parse` output."""
    statements = []
    status = ""
    for line in text.splitlines():
        match = STMT_RE.match(line)
        if match:
            statements.append(Statement(int(match.group(1)), int(match.group(2)), int(match.group(3)), match.group(4).strip()))
        elif line.startswith(("OK", "FAIL")):
            status = line.strip()
    return statements, status


def parse_payload(payload: bytes, game: str = DEFAULT_GAME, mesdump: Path = MESDUMP) -> tuple[list[Statement], str, str]:
    if not mesdump.exists():
        raise SystemExit(f"{mesdump} is missing - run tools/libai5_bridge/build_mesdump.py")
    completed = subprocess.run([str(mesdump), game, "parse"], input=payload, capture_output=True, timeout=300)
    statements, status = parse_output(completed.stdout.decode("utf-8", "replace"))
    return statements, status, completed.stderr.decode("utf-8", "replace")


def entries(arc: Path):
    blob = arc.read_bytes()
    for name, offset, size in read_entries(arc):
        yield name, blob[offset:offset + size]


def entry_payload(arc: Path, entry: str) -> bytes:
    for name, payload in entries(arc):
        if name.upper() == entry.upper():
            return payload
    raise SystemExit(f"{entry} is not in {arc}")


def listing(arc: Path, entry: str, lo: int, hi: int, game: str) -> int:
    statements, status, err = parse_payload(entry_payload(arc, entry), game)
    for s in statements:
        if lo <= s.address < hi:
            print(f"{s.address:6d}..{s.end:<6d} {s.op:2d} {s.text}")
    print(status, err.strip()[:300])
    return 0


def coverage(arc: Path, game: str) -> int:
    ops = collections.Counter()
    sys_functions = collections.Counter()
    full, partial = 0, []
    for name, payload in entries(arc):
        statements, status, _ = parse_payload(payload, game)
        if status.startswith("OK"):
            full += 1
        else:
            partial.append((name, status))
        for s in statements:
            ops[s.op] += 1
            if s.sys_function is not None:
                sys_functions[s.sys_function] += 1
    print(f"{game}: {full} entries fully parsed, {len(partial)} stop early")
    for name, status in partial[:30]:
        print("  ", name, status)
    print("statements by op:")
    for op, count in sorted(ops.items()):
        print(f"  {op:2d} {OP_NAMES.get(op, ''):45s} {count}")
    print("system functions:", sys_functions.most_common(30))
    return 0


def reconcile(arc: Path, game: str, limit: int | None) -> int:
    from mes_analyzer_handoff import build_handoff
    blob = arc.read_bytes()
    archive_sha = hashlib.sha256(blob).hexdigest()
    by_op, by_delta, examples, tails_total, seen = collections.Counter(), collections.Counter(), [], 0, 0
    for name, payload in entries(arc):
        seen += 1
        handoff = build_handoff(payload, {"archive": "mes.arc", "entry": name, "source_kind": "original_arc",
                                          "archive_sha256": archive_sha})
        tails = handoff["typed_ir"].get("opaque_boundaries", [])
        if tails:
            statements, _, _ = parse_payload(payload, game)
            for tail in tails:
                tails_total += 1
                start = int(tail["source_offset"])
                covering = next((s for s in statements if s.address <= start < s.end), None)
                by_op[covering.op if covering else -1] += 1
                if covering:
                    by_delta[start - covering.address] += 1
                    if len(examples) < 20:
                        examples.append((name, start, int(tail["end_offset"]), covering.address, covering.text[:80]))
        if limit and seen >= limit:
            break
    print(f"entries {seen}, opaque tails {tails_total}")
    print("covering libai5 statement op:", {OP_NAMES.get(k, k): v for k, v in by_op.items()})
    print("tail start minus statement start:", dict(sorted(by_delta.items())))
    for example in examples:
        print("  ", example)
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--arc", required=True)
    parser.add_argument("--game", default=DEFAULT_GAME)
    parser.add_argument("--coverage", action="store_true")
    parser.add_argument("--reconcile", action="store_true")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("entry", nargs="?")
    parser.add_argument("lo", nargs="?", type=int, default=0)
    parser.add_argument("hi", nargs="?", type=int, default=1 << 31)
    args = parser.parse_args(argv)
    arc = Path(args.arc)
    if args.coverage:
        return coverage(arc, args.game)
    if args.reconcile:
        return reconcile(arc, args.game, args.limit)
    if not args.entry:
        parser.error("an entry name, --coverage or --reconcile is required")
    return listing(arc, args.entry, args.lo, args.hi, args.game)


if __name__ == "__main__":
    sys.exit(main())
