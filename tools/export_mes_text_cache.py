from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import time
from typing import Any, Iterable

import mes_basic_block_ir_v6
from extract_kakyu_arc import read_entries
from mes_archive_ir import load_archive_entry, parse_mes_container


CACHE_SCHEMA = "kakyu_mes_text_cache/v1"
ENTRY_SCHEMA = "kakyu_mes_text_entry/v1"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


@contextmanager
def cache_write_lock(root: Path, stale_seconds: int) -> Iterable[None]:
    root.mkdir(parents=True, exist_ok=True)
    lock_path = root / ".write.lock"
    if lock_path.exists():
        age = time.time() - lock_path.stat().st_mtime
        if age <= stale_seconds:
            raise RuntimeError(f"cache is already locked: {lock_path}")
        lock_path.unlink()
    try:
        descriptor = os.open(lock_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    except FileExistsError as error:
        raise RuntimeError(f"cache is already locked: {lock_path}") from error
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as lock:
            json.dump({"pid": os.getpid(), "created_unix": int(time.time())}, lock)
        yield
    finally:
        lock_path.unlink(missing_ok=True)


def text_messages(data: bytes, document: dict[str, Any]) -> list[dict[str, Any]]:
    container = parse_mes_container(data)
    code_offset = int(container["header"]["codeOffset"])
    code = data[code_offset:]
    candidates: dict[int, tuple[int, int, str]] = {}
    for node in document["nodes"]:
        for instruction in node["instructions"]:
            operation = str(instruction["op"])
            if operation not in {"text", "dispatcher_character_text"}:
                continue
            offset = int(instruction["sourceOffset"])
            end_offset = int(instruction["endOffset"])
            operands = instruction.get("operands", [])
            raw_hex = ""
            if len(operands) == 1 and operands[0].get("type") == "cp932_string":
                raw_hex = str(operands[0].get("rawHex", ""))
            candidates[offset] = (end_offset, int(instruction["commandId"]), raw_hex)

    messages: list[dict[str, Any]] = []
    for offset, (end_offset, command_id, operand_raw_hex) in sorted(candidates.items()):
        if operand_raw_hex:
            raw = bytes.fromhex(operand_raw_hex)
        else:
            raw = code[offset + 1 : end_offset - 1] if command_id == 0x01 else code[offset : end_offset - 1]
        try:
            text = raw.decode("cp932")
        except UnicodeDecodeError:
            continue
        messages.append(
            {
                "source_offset": offset,
                "text": text,
                "raw_sha256": hashlib.sha256(raw).hexdigest(),
            }
        )
    return messages


def selected_names(archive: Path, requested: list[str] | None, include_all: bool) -> Iterable[str]:
    available = [name for name, _, _ in read_entries(archive) if Path(name).suffix.lower() in {".mes", ".lib"}]
    if include_all:
        return available
    wanted = requested or ["START.MES", "MACHI.MES", "EVENTD03.MES", "D_TALK00.MES", "D_DATE3.MES"]
    lookup = {name.casefold(): name for name in available}
    missing = [name for name in wanted if name.casefold() not in lookup]
    if missing:
        raise ValueError(f"archive entries not found: {', '.join(missing)}")
    return [lookup[name.casefold()] for name in wanted]


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a disposable UTF-8 MES text cache for the Godot Event Player.")
    parser.add_argument("archive", type=Path)
    parser.add_argument("-o", "--output-root", type=Path, required=True)
    parser.add_argument("--entry", action="append", dest="entries")
    parser.add_argument("--all", action="store_true", help="Generate projections for every MES/LIB entry.")
    parser.add_argument("--stale-lock-seconds", type=int, default=3600)
    args = parser.parse_args()
    if args.all and args.entries:
        parser.error("--all and --entry cannot be combined")
    if args.stale_lock_seconds < 1:
        parser.error("--stale-lock-seconds must be positive")
    archive_path = args.archive.resolve()
    archive_root = archive_path.parent
    output_root = args.output_root.resolve()
    if output_root == archive_root or archive_root in output_root.parents:
        parser.error("output root must be outside the source archive directory")

    with cache_write_lock(output_root, args.stale_lock_seconds):
        archive_sha = sha256_file(archive_path)
        records: list[dict[str, Any]] = []
        for entry_name in selected_names(archive_path, args.entries, args.all):
            data, source = load_archive_entry(archive_path, entry_name)
            document = mes_basic_block_ir_v6.decode_mes(data, {"entry": source["entry"], "sha256": source["sha256"]})
            messages = text_messages(data, document)
            entry_document = {
                "schema": ENTRY_SCHEMA,
                "entry": source["entry"],
                "entry_sha256": source["sha256"],
                "messages": messages,
            }
            filename = f"{source['sha256']}-{source['entry']}.json"
            relative_path = f"entries/{filename}"
            output_path = output_root / relative_path
            write_json_atomic(output_path, entry_document)
            records.append(
                {
                    "entry": source["entry"],
                    "entry_sha256": source["sha256"],
                    "path": relative_path,
                    "file_sha256": sha256_file(output_path),
                    "message_count": len(messages),
                }
            )
            print(f"{source['entry']}: messages={len(messages)} decoded={document['decodedRatio']:.1%}")

        manifest = {
            "schema": CACHE_SCHEMA,
            "generator": "tools/export_mes_text_cache.py",
            "archive": archive_path.name,
            "archive_sha256": archive_sha,
            "entries": records,
        }
        write_json_atomic(output_root / "manifest.json", manifest)
        print(f"output={output_root} entries={len(records)}")


if __name__ == "__main__":
    main()
