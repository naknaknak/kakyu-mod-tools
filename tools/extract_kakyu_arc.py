from __future__ import annotations

import argparse
import struct
from pathlib import Path
from typing import BinaryIO


ENTRY_SIZE = 264
NAME_KEY = 0x72
SIZE_KEY = 0xF97FD0EC
OFFSET_KEY = 0xA2C947FC
COPY_CHUNK_SIZE = 1024 * 1024


def decode_name(raw: bytes) -> str:
    decoded = bytes(value ^ NAME_KEY for value in raw)
    decoded = decoded.split(b"\0", 1)[0]
    name = decoded.decode("ascii")
    if (
        not name
        or name in {".", ".."}
        or "/" in name
        or "\\" in name
        or ":" in name
        or any(ord(character) < 0x20 or ord(character) > 0x7E for character in name)
    ):
        raise ValueError("unsafe or invalid ARC entry name")
    return name


def read_entries(arc_path: Path) -> list[tuple[str, int, int]]:
    archive_size = arc_path.stat().st_size
    if archive_size < 4:
        raise ValueError(f"{arc_path} is too small")

    with arc_path.open("rb") as archive:
        count_data = archive.read(4)
        count = struct.unpack("<I", count_data)[0]
        header_size = 4 + (count * ENTRY_SIZE)
        if header_size > archive_size:
            raise ValueError(
                f"{arc_path} has an invalid header size: {header_size} > {archive_size}"
            )
        index_data = archive.read(count * ENTRY_SIZE)
        if len(index_data) != count * ENTRY_SIZE:
            raise ValueError(f"{arc_path} index read was truncated")

    entries: list[tuple[str, int, int]] = []
    names: set[str] = set()
    for index in range(count):
        base = index * ENTRY_SIZE
        entry = index_data[base : base + ENTRY_SIZE]
        try:
            name = decode_name(entry[:256])
        except (UnicodeDecodeError, ValueError) as error:
            raise ValueError(f"{arc_path} entry {index}: {error}") from error
        folded_name = name.casefold()
        if folded_name in names:
            raise ValueError(f"{arc_path} has a duplicate entry name: {name}")
        names.add(folded_name)
        size = struct.unpack_from("<I", entry, 256)[0] ^ SIZE_KEY
        offset = struct.unpack_from("<I", entry, 260)[0] ^ OFFSET_KEY
        if offset < header_size or offset > archive_size or size > archive_size - offset:
            raise ValueError(
                f"{arc_path} entry {index} {name} points outside archive: "
                f"offset={offset} size={size} archive_size={archive_size}"
            )
        entries.append((name, offset, size))
    return entries


def extract_arc(arc_path: Path, out_dir: Path, overwrite: bool = False) -> tuple[int, int]:
    out_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    skipped = 0

    entries = read_entries(arc_path)
    source_path = arc_path.resolve()
    with arc_path.open("rb") as archive:
        for name, offset, size in entries:
            out_path = out_dir / name
            if out_path.resolve() == source_path:
                raise ValueError(f"refusing to overwrite source archive: {arc_path}")
            if out_path.exists() and not overwrite:
                skipped += 1
                continue
            mode = "wb" if overwrite else "xb"
            with out_path.open(mode) as output:
                _copy_entry(archive, output, offset, size)
            written += 1
    return written, skipped


def _copy_entry(archive: BinaryIO, output: BinaryIO, offset: int, size: int) -> None:
    archive.seek(offset)
    remaining = size
    while remaining:
        chunk = archive.read(min(COPY_CHUNK_SIZE, remaining))
        if not chunk:
            raise ValueError("ARC entry read was truncated")
        output.write(chunk)
        remaining -= len(chunk)


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract ELF Kakyu AI5 ARC archives.")
    parser.add_argument("arc", type=Path)
    parser.add_argument("-o", "--out-dir", type=Path, required=True)
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--list", action="store_true", help="List entries without extracting.")
    args = parser.parse_args()

    if args.list:
        for name, offset, size in read_entries(args.arc):
            print(f"{name}\t{offset}\t{size}")
        return

    written, skipped = extract_arc(args.arc, args.out_dir, args.overwrite)
    print(f"{args.arc}: written={written} skipped={skipped} out={args.out_dir}")


if __name__ == "__main__":
    main()
