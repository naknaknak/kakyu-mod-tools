"""Audit exact filename-bearing voice marker envelopes in an original MES ARC.

The marker is deliberately not called a command: native command 0x07 executes
banked-u16 writes, while this strict-invalid expression form carries a readable
voice filename between two separately valid bit-toggle writes.  This tool keeps
the structural observation distinct from an engine-playback claim.
"""

from __future__ import annotations

import argparse
import re
import struct
from collections import Counter
from pathlib import Path

from extract_kakyu_arc import read_entries


MARKER = re.compile(
    rb"\x07\xff\x02\x02\xff\x01"
    rb"(?P<name>[A-Za-z][0-9]{3,4}\.[Oo][Gg][Gg]?)"
    rb"\x00\x02\x00\xff\x00"
)
VOICE_TOKEN = re.compile(rb"(?i)[A-Za-z][0-9]{3,4}\.ogg?")
SET_VOICE_BIT = bytes.fromhex("0702ff0002a000f18000e9ff000d")
CLEAR_VOICE_BIT = bytes.fromhex("0702ff0002a000f17fffe8ff00")


def normalize_voice_name(raw_name: bytes) -> str:
    token = raw_name.decode("ascii")
    stem = token.rsplit(".", 1)[0]
    return f"{stem[0].upper()}{int(stem[1:]):04d}.OGG"


def audit_archive(mes_arc: Path, elfimage: Path | None = None) -> dict[str, object]:
    entries = read_entries(mes_arc)
    archive_names = _archive_name_sets(elfimage) if elfimage is not None else {}
    rows: list[dict[str, object]] = []
    token_count = 0

    with mes_arc.open("rb") as archive:
        for entry_name, archive_offset, size in entries:
            archive.seek(archive_offset)
            data = archive.read(size)
            if len(data) != size:
                raise ValueError(f"{entry_name} payload read was truncated")
            if len(data) < 4:
                continue
            entry_count = struct.unpack_from("<I", data, 0)[0]
            code_offset = 4 + entry_count * 4
            if code_offset > len(data):
                raise ValueError(f"{entry_name} has an invalid MES address table")
            code = data[code_offset:]
            token_count += len(VOICE_TOKEN.findall(code))
            for match in MARKER.finditer(code):
                raw_name = match.group("name")
                normalized = normalize_voice_name(raw_name)
                prefix = normalized[0]
                candidates = ("tina1.arc", "tina2.arc") if prefix == "M" else ("voice.arc",)
                resolved = [name for name in candidates if normalized.casefold() in archive_names.get(name, set())]
                rows.append(
                    {
                        "entry": entry_name,
                        "offset": match.start(),
                        "token": raw_name.decode("ascii"),
                        "normalized": normalized,
                        "set_bit_prefix": code[max(0, match.start() - len(SET_VOICE_BIT)) : match.start()] == SET_VOICE_BIT,
                        "clear_bit_suffix": code[match.end() : match.end() + len(CLEAR_VOICE_BIT)] == CLEAR_VOICE_BIT,
                        "candidate_archives": candidates,
                        "resolved_archives": tuple(resolved),
                    }
                )

    return {
        "entries": len(entries),
        "voice_tokens": token_count,
        "markers": len(rows),
        "marker_entries": len({str(row["entry"]) for row in rows}),
        "set_bit_prefixes": sum(bool(row["set_bit_prefix"]) for row in rows),
        "clear_bit_suffixes": sum(bool(row["clear_bit_suffix"]) for row in rows),
        "fully_wrapped": sum(bool(row["set_bit_prefix"]) and bool(row["clear_bit_suffix"]) for row in rows),
        "resolved_markers": sum(bool(row["resolved_archives"]) for row in rows),
        "prefix_counts": Counter(str(row["normalized"])[0] for row in rows),
        "rows": rows,
    }


def _archive_name_sets(elfimage: Path | None) -> dict[str, set[str]]:
    if elfimage is None:
        return {}
    result: dict[str, set[str]] = {}
    for archive_name in ("voice.arc", "tina1.arc", "tina2.arc"):
        archive_path = elfimage / archive_name
        if archive_path.is_file():
            result[archive_name] = {name.casefold() for name, _, _ in read_entries(archive_path)}
    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit exact filename-bearing voice marker envelopes in mes.arc."
    )
    parser.add_argument("mes_arc", type=Path)
    parser.add_argument("--elfimage", type=Path, help="Optional directory containing voice/tina ARC files.")
    parser.add_argument("--entry", help="Print marker rows for one MES entry.")
    args = parser.parse_args()

    result = audit_archive(args.mes_arc, args.elfimage)
    print(
        "entries={entries} voice_tokens={voice_tokens} markers={markers} "
        "marker_entries={marker_entries} wrapped={fully_wrapped} resolved={resolved_markers}".format(**result)
    )
    prefixes: Counter[str] = result["prefix_counts"]  # type: ignore[assignment]
    print("prefixes=" + ",".join(f"{name}:{prefixes[name]}" for name in sorted(prefixes)))
    if args.entry:
        for row in result["rows"]:  # type: ignore[assignment]
            if str(row["entry"]).casefold() != args.entry.casefold():
                continue
            resolved = ",".join(row["resolved_archives"]) or "unresolved"
            print(
                f"{row['entry']} code+0x{int(row['offset']):X} {row['token']} -> "
                f"{row['normalized']} [{resolved}] set={row['set_bit_prefix']} clear={row['clear_bit_suffix']}"
            )


if __name__ == "__main__":
    main()
