#!/usr/bin/env python3
"""Generate the compact CP932 decode table consumed by Content Core."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


MAGIC = b"KCP932V1"
SINGLE_COUNT = 256
LEADS = tuple(range(0x81, 0xA0)) + tuple(range(0xE0, 0xFD))
TRAILS = tuple(range(0x40, 0x7F)) + tuple(range(0x80, 0xFD))


def decode_codepoint(data: bytes) -> int:
    try:
        text = data.decode("cp932")
    except UnicodeDecodeError:
        return 0
    if len(text) != 1:
        return 0
    codepoint = ord(text)
    if codepoint > 0xFFFF:
        raise ValueError(f"CP932 mapping exceeds the BMP: {data.hex()} -> U+{codepoint:06X}")
    return codepoint


def build_table() -> bytes:
    header = struct.pack("<8sHHHH", MAGIC, SINGLE_COUNT, len(LEADS), len(TRAILS), 0)
    single = b"".join(struct.pack("<H", decode_codepoint(bytes((value,)))) for value in range(256))
    double = b"".join(
        struct.pack("<H", decode_codepoint(bytes((lead, trail))))
        for lead in LEADS
        for trail in TRAILS
    )
    return header + single + double


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    payload = build_table()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(payload)
    if bytes((0x82, 0xA0)).decode("cp932") != "あ":
        raise RuntimeError("Host CP932 codec failed its known mapping check")
    print(
        f"CP932_TABLE_WRITTEN path={args.output} bytes={len(payload)} "
        f"single={SINGLE_COUNT} leads={len(LEADS)} trails={len(TRAILS)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
