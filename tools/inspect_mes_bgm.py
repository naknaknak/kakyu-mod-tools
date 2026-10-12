from __future__ import annotations

import argparse
import re
from bisect import bisect_right
from pathlib import Path

from extract_kakyu_arc import read_entries
from mes_archive_ir import load_archive_entry, parse_mes_container
from mes_basic_block_ir_v6 import decode_mes


WAV_REFERENCE = re.compile(rb"(?i)([A-Za-z0-9_]+\.wav)")
BGM_BRANCH = re.compile(
    rb"\x0b\xf6\x01\x00(?P<selector>[\x00-\x7f]|\xf1.{2})\xef\xff"
    rb"(?P<next_branch>.{4})\x0d\x05\xff\x02\x00\xff\x01"
    rb"(?P<filename>[A-Za-z0-9_]+\.wav)\x00",
    re.IGNORECASE | re.DOTALL,
)
LIBRARY_COMMAND_BRANCH = re.compile(
    rb"\x0b\xf6\x00\x00(?P<command>[\x00-\x7f])\xef\xff(?P<target>.{4})"
)


def decode_selector(raw: bytes) -> int:
    if raw[0] == 0xF1:
        return int.from_bytes(raw[1:3], "little")
    return raw[0]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Report which MES address-table entry owns each WAV reference."
    )
    parser.add_argument("archive", type=Path)
    parser.add_argument("entry", nargs="?", default="LIBLARY.LIB")
    parser.add_argument(
        "--script",
        action="append",
        default=[],
        help="Also print authoritative byte contexts that reference global_i32[1].",
    )
    parser.add_argument(
        "--labels",
        action="store_true",
        help="Print small LIB entry labels and the WAV names inside each label region.",
    )
    parser.add_argument(
        "--scan-call",
        action="append",
        type=int,
        default=[],
        help="Scan every mes.arc entry for a literal script-transfer call id.",
    )
    parser.add_argument(
        "--transfers",
        action="store_true",
        help="Decode and print command 0x1d record lists for each --script entry.",
    )
    parser.add_argument(
        "--dump-range",
        help="Print a LIB code range as grouped hex, for example 0x500:0x600.",
    )
    parser.add_argument(
        "--dump-script-range",
        help="Print the selected --script code range as grouped hex.",
    )
    parser.add_argument(
        "--scan-argument",
        action="append",
        type=int,
        default=[],
        help="Scan every archive entry for argument-1 assignments and the next literal transfer.",
    )
    args = parser.parse_args()

    data, source = load_archive_entry(args.archive, args.entry)
    container = parse_mes_container(data, source)
    code_offset = int(container["header"]["codeOffset"])
    code = data[code_offset:]
    entry_offsets = [int(value) for value in container["header"]["entryOffsets"]]

    print(
        f"{source['entry']}: archiveOffset={source['archiveOffset']} "
        f"entries={len(entry_offsets)} codeSize={len(code)}"
    )
    if args.dump_range:
        start_text, end_text = args.dump_range.split(":", 1)
        start = int(start_text, 0)
        end = int(end_text, 0)
        for offset in range(start, min(end, len(code)), 16):
            chunk = code[offset:min(offset + 16, end)]
            print(f"dump 0x{offset:06x}: {chunk.hex(' ')}")
    for branch in BGM_BRANCH.finditer(code):
        print(
            f"bgmSelector={decode_selector(branch.group('selector'))} "
            f"conditionOffset=0x{branch.start():x} "
            f"wavOffset=0x{branch.start('filename'):x} "
            f"name={branch.group('filename').decode('ascii')}"
        )
    for branch in LIBRARY_COMMAND_BRANCH.finditer(code):
        print(
            f"libraryCommand={branch.group('command')[0]} "
            f"conditionOffset=0x{branch.start():x} "
            f"falseTarget=0x{int.from_bytes(branch.group('target'), 'little'):x}"
        )
    for match in WAV_REFERENCE.finditer(code):
        entry_index = bisect_right(entry_offsets, match.start()) - 1
        entry_start = entry_offsets[entry_index] if entry_index >= 0 else 0
        entry_end = (
            entry_offsets[entry_index + 1]
            if entry_index + 1 < len(entry_offsets)
            else len(code)
        )

    if args.labels:
        labels: list[tuple[int, int]] = []
        for offset in range(len(code) - 4):
            if code[offset] != 0x17:
                continue
            label = int.from_bytes(code[offset + 1:offset + 5], "little")
            if label <= 255:
                labels.append((offset, label))
        for index, (offset, label) in enumerate(labels):
            end = labels[index + 1][0] if index + 1 < len(labels) else len(code)
            wav_names = [
                match.group(1).decode("ascii")
                for match in WAV_REFERENCE.finditer(code, offset, end)
            ]
            print(
                f"libraryLabel={label} offset=0x{offset:x} end=0x{end:x} "
                f"wav={','.join(wav_names) if wav_names else '-'}"
            )
        print(
            f"entry={entry_index} range=0x{entry_start:x}-0x{entry_end:x} "
            f"wavOffset=0x{match.start():x} name={match.group(1).decode('ascii')} "
            f"contextHex={code[max(0, match.start() - 40):match.end() + 24].hex()}"
        )

    for script_name in args.script:
        script_data, script_source = load_archive_entry(args.archive, script_name)
        script_container = parse_mes_container(script_data, script_source)
        script_code_offset = int(script_container["header"]["codeOffset"])
        script_code = script_data[script_code_offset:]
        print(
            f"{script_source['entry']}: archiveOffset={script_source['archiveOffset']} "
            f"codeSize={len(script_code)} global_i32[1] references"
        )
        if args.dump_script_range:
            start_text, end_text = args.dump_script_range.split(":", 1)
            start = int(start_text, 0)
            end = int(end_text, 0)
            for offset in range(start, min(end, len(script_code)), 16):
                chunk = script_code[offset:min(offset + 16, end)]
                print(f"scriptDump 0x{offset:06x}: {chunk.hex(' ')}")
        cursor = 0
        while True:
            cursor = script_code.find(b"\xf6\x01\x00", cursor)
            if cursor < 0:
                break
            context = script_code[max(0, cursor - 24):cursor + 32]
            print(f"codeOffset=0x{cursor:x} contextHex={context.hex()}")
            cursor += 3
        if args.transfers:
            document = decode_mes(script_data, script_source)
            seen_offsets: set[int] = set()
            for node in document.get("nodes", []):
                for instruction in node.get("instructions", []):
                    if int(instruction.get("commandId", -1)) != 0x1D:
                        continue
                    source_offset = int(instruction["sourceOffset"])
                    if source_offset in seen_offsets:
                        continue
                    seen_offsets.add(source_offset)
                    values: list[str] = []
                    for operand in instruction.get("operands", []):
                        for record in operand.get("records", []):
                            value = record.get("value", {})
                            if record.get("type") == "expression_record":
                                ast = value.get("ast", {})
                                values.append(str(ast.get("value", ast.get("type", "?"))))
                            elif record.get("type") == "string_record":
                                values.append(str(value.get("value", "")))
                    print(
                        f"transfer mes={script_name} codeOffset=0x{source_offset:x} "
                        f"records={','.join(values)} raw={instruction.get('rawHex', '')}"
                    )

    if args.scan_call:
        archive = args.archive.read_bytes()
        for call_id in args.scan_call:
            pattern = b"\x1d\x02" + bytes([call_id]) + b"\xff\x00"
            for name, archive_offset, size in read_entries(args.archive):
                entry_data = archive[archive_offset:archive_offset + size]
                entry_container = parse_mes_container(entry_data)
                entry_code_offset = int(entry_container["header"]["codeOffset"])
                entry_code = entry_data[entry_code_offset:]
                cursor = 0
                while True:
                    cursor = entry_code.find(pattern, cursor)
                    if cursor < 0:
                        break
                    context = entry_code[max(0, cursor - 32):cursor + len(pattern) + 16]
                    print(
                        f"call={call_id} mes={name} codeOffset=0x{cursor:x} "
                        f"contextHex={context.hex()}"
                    )
                    cursor += len(pattern)

    if args.scan_argument:
        archive = args.archive.read_bytes()
        for argument in args.scan_argument:
            assignment = b"\x09\x01\x00" + bytes([argument]) + b"\xff\x00"
            transfer_pattern = re.compile(rb"\x1d\x02(?P<call>[\x00-\x7f])\xff\x00")
            for name, archive_offset, size in read_entries(args.archive):
                entry_data = archive[archive_offset:archive_offset + size]
                entry_container = parse_mes_container(entry_data)
                entry_code_offset = int(entry_container["header"]["codeOffset"])
                entry_code = entry_data[entry_code_offset:]
                cursor = 0
                while True:
                    cursor = entry_code.find(assignment, cursor)
                    if cursor < 0:
                        break
                    transfer = transfer_pattern.search(
                        entry_code,
                        cursor + len(assignment),
                        min(len(entry_code), cursor + len(assignment) + 64),
                    )
                    context_end = transfer.end() + 16 if transfer else cursor + len(assignment) + 32
                    context = entry_code[max(0, cursor - 16):context_end]
                    print(
                        f"argument={argument} mes={name} codeOffset=0x{cursor:x} "
                        f"nextCall={transfer.group('call')[0] if transfer else '-'} "
                        f"contextHex={context.hex()}"
                    )
                    cursor += len(assignment)


if __name__ == "__main__":
    main()
