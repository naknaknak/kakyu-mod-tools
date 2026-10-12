from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path
from typing import Any

from mes_archive_ir import MesContainerError, load_archive_entry, parse_mes_container
from mes_expression import ExpressionError, parse_expression


ROOT = Path(__file__).resolve().parents[1]


class MesCfgError(ValueError):
    pass


def seed_cfg(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    container = parse_mes_container(data, source)
    header = container["header"]
    code_offset = header["codeOffset"]
    code = data[code_offset:]
    offsets: list[int] = header["entryOffsets"]
    offset_to_index = {offset: index for index, offset in enumerate(offsets)}
    diagnostics: list[dict[str, Any]] = []
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []

    bootstrap_end = offsets[0] if offsets else len(code)
    bootstrap: dict[str, Any] = {
        "id": "bootstrap",
        "offset": 0,
        "endOffset": bootstrap_end,
        "size": bootstrap_end,
        "rawHex": code[:bootstrap_end].hex(),
    }

    if code and code[0] == 0x14:
        try:
            expression = parse_expression(code, 1, max_bytes=bootstrap_end - 1)
        except ExpressionError as exc:
            raise MesCfgError(f"invalid 0x14 bootstrap expression: {exc}") from exc
        operand_offset = expression["end_offset"]
        if operand_offset + 4 > bootstrap_end:
            raise MesCfgError("truncated 0x14 bootstrap target")
        target = struct.unpack_from("<I", code, operand_offset)[0]
        instruction_end = operand_offset + 4
        if instruction_end != bootstrap_end:
            diagnostics.append(
                {
                    "level": "warning",
                    "code": "bootstrap_trailing_bytes",
                    "message": f"{bootstrap_end - instruction_end} bytes follow the 0x14 transfer",
                }
            )
        bootstrap["instruction"] = {
            "op": "bootstrap_transfer",
            "commandId": 0x14,
            "expression": expression,
            "targetOffset": target,
            "sourceOffset": 0,
            "byteLength": instruction_end,
            "rawHex": code[:instruction_end].hex(),
        }
        target_index = offset_to_index.get(target)
        if target_index is None:
            diagnostics.append(
                {
                    "level": "error",
                    "code": "bootstrap_target_not_in_address_table",
                    "message": f"bootstrap target 0x{target:x} is not an address-table offset",
                }
            )
        else:
            edges.append(
                {
                    "type": "transfer",
                    "source": "bootstrap",
                    "target": f"entry_{target_index:04d}",
                    "targetOffset": target,
                    "commandId": 0x14,
                }
            )
    elif code:
        bootstrap["instruction"] = {
            "op": "unknown_bootstrap",
            "commandId": code[0],
            "sourceOffset": 0,
        }

    nodes.append(bootstrap)

    for index, offset in enumerate(offsets):
        end_offset = offsets[index + 1] if index + 1 < len(offsets) else len(code)
        if offset + 5 > end_offset:
            raise MesCfgError(f"entry {index} is too small for its five-byte prologue")
        command_id = code[offset]
        label_index = struct.unpack_from("<I", code, offset + 1)[0]
        if command_id != 0x17:
            raise MesCfgError(
                f"entry {index} at 0x{offset:x} starts with 0x{command_id:02x}, expected 0x17"
            )
        if label_index != index:
            raise MesCfgError(
                f"entry {index} at 0x{offset:x} declares label {label_index}"
            )
        nodes.append(
            {
                "id": f"entry_{index:04d}",
                "index": index,
                "offset": offset,
                "fileOffset": code_offset + offset,
                "endOffset": end_offset,
                "size": end_offset - offset,
                "prologue": {
                    "op": "entry_label",
                    "commandId": 0x17,
                    "labelIndex": label_index,
                    "sourceOffset": offset,
                    "byteLength": 5,
                    "rawHex": code[offset : offset + 5].hex(),
                },
                "bodyOffset": offset + 5,
            }
        )

    return {
        "schema": "ai5_mes_cfg_seed/v1",
        "source": container["source"],
        "bytecodeSha256": hashlib.sha256(code).hexdigest(),
        "nodeCount": len(nodes),
        "nodes": nodes,
        "edges": edges,
        "diagnostics": diagnostics,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Lift the confirmed MES bootstrap and address-table entry prologues into CFG seed JSON."
    )
    parser.add_argument("archive", type=Path)
    parser.add_argument("entry")
    parser.add_argument("-o", "--output", type=Path)
    args = parser.parse_args()

    archive = args.archive if args.archive.is_absolute() else ROOT / args.archive
    data, source = load_archive_entry(archive, args.entry)
    document = seed_cfg(data, source)
    encoded = json.dumps(document, ensure_ascii=False, indent=2)
    if args.output:
        output = args.output if args.output.is_absolute() else ROOT / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(encoded + "\n", encoding="utf-8")
        print(
            f"{source['entry']}: nodes={document['nodeCount']} edges={len(document['edges'])} "
            f"output={output}"
        )
    else:
        print(encoded)


if __name__ == "__main__":
    main()
