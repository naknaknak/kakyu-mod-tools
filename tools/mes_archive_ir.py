from __future__ import annotations

import argparse
import base64
import hashlib
import json
import struct
from pathlib import Path
from typing import Any

from extract_kakyu_arc import read_entries


ROOT = Path(__file__).resolve().parents[1]


class MesContainerError(ValueError):
    pass


def load_archive_entry(arc_path: Path, entry_name: str) -> tuple[bytes, dict[str, Any]]:
    archive = arc_path.read_bytes()
    wanted = entry_name.casefold()
    matches = [row for row in read_entries(arc_path) if row[0].casefold() == wanted]
    if not matches:
        raise MesContainerError(f"{entry_name!r} was not found in {arc_path}")
    if len(matches) != 1:
        raise MesContainerError(f"{entry_name!r} is ambiguous in {arc_path}")

    stored_name, archive_offset, size = matches[0]
    data = archive[archive_offset : archive_offset + size]
    return data, {
        "archive": str(arc_path),
        "entry": stored_name,
        "archiveOffset": archive_offset,
        "size": size,
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def parse_mes_container(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    if len(data) < 4:
        raise MesContainerError("MES entry is smaller than the 4-byte entry count")

    entry_count = struct.unpack_from("<I", data, 0)[0]
    code_offset = 4 + entry_count * 4
    if code_offset > len(data):
        raise MesContainerError(
            f"entry table exceeds MES data: count={entry_count} tableEnd={code_offset} size={len(data)}"
        )

    entry_offsets = list(struct.unpack_from(f"<{entry_count}I", data, 4)) if entry_count else []
    code = data[code_offset:]
    diagnostics: list[dict[str, Any]] = []

    for index, offset in enumerate(entry_offsets):
        if offset >= len(code):
            raise MesContainerError(
                f"entry {index} offset 0x{offset:x} is outside code size 0x{len(code):x}"
            )
        if index and offset <= entry_offsets[index - 1]:
            raise MesContainerError(
                f"entry offsets are not strictly increasing at index {index}: "
                f"0x{entry_offsets[index - 1]:x}, 0x{offset:x}"
            )

    first_entry = entry_offsets[0] if entry_offsets else len(code)
    entries: list[dict[str, Any]] = []
    for index, offset in enumerate(entry_offsets):
        end_offset = entry_offsets[index + 1] if index + 1 < entry_count else len(code)
        entries.append(
            {
                "id": f"entry_{index:04d}",
                "index": index,
                "offset": offset,
                "fileOffset": code_offset + offset,
                "endOffset": end_offset,
                "size": end_offset - offset,
            }
        )

    if entry_offsets and first_entry:
        diagnostics.append(
            {
                "level": "info",
                "code": "bootstrap_prefix",
                "message": f"{first_entry} code bytes precede the first address-table entry",
            }
        )

    return {
        "schema": "ai5_mes_container/v1",
        "source": source or {"size": len(data), "sha256": hashlib.sha256(data).hexdigest()},
        "header": {
            "entryCount": entry_count,
            "tableOffset": 4,
            "tableSize": entry_count * 4,
            "codeOffset": code_offset,
            "codeSize": len(code),
            "entryOffsets": entry_offsets,
            "offsetBasis": "code_start",
        },
        "bootstrap": {
            "offset": 0,
            "fileOffset": code_offset,
            "endOffset": first_entry,
            "size": first_entry,
        },
        "entries": entries,
        "bytecode": {
            "encoding": "base64",
            "sha256": hashlib.sha256(code).hexdigest(),
            "data": base64.b64encode(code).decode("ascii"),
        },
        "diagnostics": diagnostics,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert one raw MES.ARC entry into a lossless Godot-friendly JSON container."
    )
    parser.add_argument("archive", type=Path)
    parser.add_argument("entry", help="Archive entry name, for example START.MES")
    parser.add_argument("-o", "--output", type=Path)
    args = parser.parse_args()

    archive = args.archive if args.archive.is_absolute() else ROOT / args.archive
    data, source = load_archive_entry(archive, args.entry)
    document = parse_mes_container(data, source)
    encoded = json.dumps(document, ensure_ascii=False, indent=2)

    if args.output:
        output = args.output if args.output.is_absolute() else ROOT / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(encoded + "\n", encoding="utf-8")
        print(
            f"{source['entry']}: entries={document['header']['entryCount']} "
            f"code=0x{document['header']['codeSize']:x} output={output}"
        )
    else:
        print(encoded)


if __name__ == "__main__":
    main()
