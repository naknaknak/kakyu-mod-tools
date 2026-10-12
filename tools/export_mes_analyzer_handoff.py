"""Export a signed Python analyzer handoff from a read-only original entry."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

from export_mes_text_cache import sha256_file, write_json_atomic
from mes_analyzer_handoff import HandoffError, build_handoff, verify
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]


def export_handoff(arc: Path, entry: str, output: Path) -> dict:
    arc, output = arc.resolve(), output.resolve()
    temporary = output.with_name(output.name + ".tmp").resolve()
    for target in (output, temporary):
        if (not target.is_relative_to(ROOT) or target.is_relative_to(arc.parent)
                or (target.exists() and arc.exists() and target.samefile(arc))):
            raise HandoffError("Handoff output must be inside this project and outside the source archive directory.")
    if Path(entry).suffix.lower() not in (".mes", ".lib"):
        raise HandoffError("Handoff export requires a MES or LIB entry.")
    archive_hash = sha256_file(arc)
    payload, source = load_archive_entry(arc, entry)
    handoff = build_handoff(payload, {
        "archive": arc.name, "entry": source["entry"], "archive_sha256": archive_hash,
    })
    verify(handoff)
    if sha256_file(arc) != archive_hash:
        raise HandoffError("Source archive changed during handoff export.")
    write_json_atomic(output, handoff)
    return {
        "schema": handoff["schema"], "entry": source["entry"],
        "producer": handoff["producer"]["implementation"],
        "payload_sha256": handoff["payload_sha256"], "source_unchanged": True,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arc", type=Path, required=True)
    parser.add_argument("--entry", required=True)
    parser.add_argument("--json", type=Path, required=True, help="output inside the project, outside the source directory")
    args = parser.parse_args(argv)
    try:
        result = export_handoff(args.arc, args.entry, args.json)
    except (ValueError, OSError) as failure:
        print(f"MES_ANALYZER_HANDOFF_PYTHON_EXPORT_ERROR: {failure}", file=sys.stderr)
        return 2
    print("MES_ANALYZER_HANDOFF_PYTHON_EXPORT " + " ".join(f"{key}={value}" for key, value in result.items()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
