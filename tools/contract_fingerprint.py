"""Fingerprint of a mirrored contract directory (WD-22).

    py tools/contract_fingerprint.py config/contracts/event_definition_v3 [--check] [--write]

The fingerprint is the SHA-256 over the concatenation of
``"<relative path>\\t<sha256 of the file bytes>\\n"`` for every regular file
under the directory except the fingerprint file itself, paths relative to the
directory with ``/`` separators, sorted, LF line endings. Both repositories
recompute it the same way, so a mirrored copy cannot drift silently.

``--write`` stores the value in ``<directory>/<fingerprint file>`` (one line);
``--check`` exits 1 when the stored value differs. The fingerprint file is
``contract_fingerprint`` unless ``--name`` says otherwise (the event name
registry uses ``names_fingerprint``).
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

DEFAULT_NAME = "contract_fingerprint"


def file_rows(directory: Path, fingerprint_name: str = DEFAULT_NAME) -> list[tuple[str, str]]:
    rows = []
    for path in sorted(p for p in directory.rglob("*") if p.is_file()):
        relative = path.relative_to(directory).as_posix()
        if relative == fingerprint_name:
            continue
        rows.append((relative, hashlib.sha256(path.read_bytes()).hexdigest()))
    rows.sort()
    return rows


def compute(directory: Path, fingerprint_name: str = DEFAULT_NAME) -> str:
    digest = hashlib.sha256()
    for relative, sha in file_rows(directory, fingerprint_name):
        digest.update(f"{relative}\t{sha}\n".encode("utf-8"))
    return digest.hexdigest()


def stored(directory: Path, fingerprint_name: str = DEFAULT_NAME) -> str:
    path = directory / fingerprint_name
    return path.read_text(encoding="utf-8").strip() if path.is_file() else ""


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--name", default=DEFAULT_NAME, help="fingerprint file name inside the directory")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    if not args.directory.is_dir():
        print(f"not a directory: {args.directory}")
        return 2
    value = compute(args.directory, args.name)
    if args.write:
        (args.directory / args.name).write_bytes((value + "\n").encode("utf-8"))
    if args.check and stored(args.directory, args.name) != value:
        print(f"MISMATCH stored={stored(args.directory, args.name) or '(none)'} computed={value}")
        return 1
    print(value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
