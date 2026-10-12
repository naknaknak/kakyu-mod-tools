"""Read the version resource of a Windows executable without any Windows API.

The distribution builder uses this to prove that every exported application
carries the suite's own identity (version numbers, product name, description)
instead of the engine template's.  Only the fields the builder checks are
decoded: the fixed file and product versions and the first string table.
"""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path

RT_VERSION = 16
FIXED_SIGNATURE = 0xFEEF04BD


class PeVersionError(ValueError):
    pass


def read_version_info(path: Path) -> dict[str, object]:
    """Return ``{"file_version", "product_version", "strings"}`` of ``path``."""
    return parse_pe(Path(path).read_bytes())


def parse_pe(data: bytes) -> dict[str, object]:
    if len(data) < 0x40 or data[:2] != b"MZ":
        raise PeVersionError("not a PE file")
    pe = _u32(data, 0x3C)
    if data[pe : pe + 4] != b"PE\0\0":
        raise PeVersionError("missing PE signature")
    section_count = _u16(data, pe + 6)
    optional_size = _u16(data, pe + 20)
    optional = pe + 24
    magic = _u16(data, optional)
    if magic == 0x20B:
        directories = optional + 112
    elif magic == 0x10B:
        directories = optional + 96
    else:
        raise PeVersionError("unknown optional header")
    resource_rva = _u32(data, directories + 2 * 8)
    if resource_rva == 0:
        raise PeVersionError("no resource directory")
    sections = []
    table = optional + optional_size
    for index in range(section_count):
        row = table + index * 40
        virtual_size, virtual_address, raw_size, raw_offset = struct.unpack_from("<IIII", data, row + 8)
        sections.append((virtual_address, max(virtual_size, raw_size), raw_offset))

    def offset_of(rva: int) -> int:
        for virtual_address, size, raw_offset in sections:
            if virtual_address <= rva < virtual_address + size:
                return raw_offset + rva - virtual_address
        raise PeVersionError("resource address outside every section")

    root = offset_of(resource_rva)

    def entries(directory: int) -> list[tuple[int, int]]:
        named, by_id = struct.unpack_from("<HH", data, directory + 12)
        return [struct.unpack_from("<II", data, directory + 16 + index * 8) for index in range(named + by_id)]

    def descend(directory: int, wanted: int | None) -> int:
        for name, target in entries(directory):
            if wanted is None or name == wanted:
                return target
        raise PeVersionError("version resource not found")

    type_target = descend(root, RT_VERSION)
    if not type_target & 0x80000000:
        raise PeVersionError("malformed resource tree")
    name_target = descend(root + (type_target & 0x7FFFFFFF), None)
    if not name_target & 0x80000000:
        raise PeVersionError("malformed resource tree")
    language_target = descend(root + (name_target & 0x7FFFFFFF), None)
    if language_target & 0x80000000:
        raise PeVersionError("malformed resource tree")
    data_rva, data_size = struct.unpack_from("<II", data, root + language_target)
    start = offset_of(data_rva)
    return parse_version_resource(data[start : start + data_size])


def parse_version_resource(blob: bytes) -> dict[str, object]:
    key, value, children_start, end = _node(blob, 0)
    if key != "VS_VERSION_INFO" or len(value) < 52 or _u32(value, 0) != FIXED_SIGNATURE:
        raise PeVersionError("malformed version resource")
    file_ms, file_ls, product_ms, product_ls = struct.unpack_from("<IIII", value, 8)
    strings: dict[str, str] = {}
    position = children_start
    while position + 6 <= end:
        child_key, _child_value, grand_start, child_end = _node(blob, position)
        if child_key == "StringFileInfo":
            table = grand_start
            if table + 6 <= child_end:
                _table_key, _table_value, string_start, table_end = _node(blob, table)
                cursor = string_start
                while cursor + 6 <= table_end:
                    name, text, _unused, string_end = _node(blob, cursor)
                    strings[name] = text.decode("utf-16-le").rstrip("\0")
                    cursor = _align(string_end)
        position = _align(child_end)
    return {
        "file_version": _dotted(file_ms, file_ls),
        "product_version": _dotted(product_ms, product_ls),
        "strings": strings,
    }


def _node(blob: bytes, start: int) -> tuple[str, bytes, int, int]:
    length, value_length, kind = struct.unpack_from("<HHH", blob, start)
    if length < 6 or start + length > len(blob):
        raise PeVersionError("malformed version node")
    cursor = start + 6
    key_end = cursor
    while key_end + 1 < start + length and blob[key_end : key_end + 2] != b"\0\0":
        key_end += 2
    key = blob[cursor:key_end].decode("utf-16-le")
    value_start = _align(key_end + 2)
    value_bytes = value_length * 2 if kind == 1 else value_length
    value_end = min(value_start + value_bytes, start + length)
    return key, blob[value_start:value_end], _align(value_end), start + length


def _align(value: int) -> int:
    return (value + 3) & ~3


def _dotted(most: int, least: int) -> str:
    return f"{most >> 16}.{most & 0xFFFF}.{least >> 16}.{least & 0xFFFF}"


def _u16(data: bytes, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def _u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    args = parser.parse_args()
    print(json.dumps(read_version_info(args.executable), ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
