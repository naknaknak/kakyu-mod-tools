#!/usr/bin/env python3
"""Classify extracted Kakyu PNG assets and copy them into a Godot project."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import shutil
from collections import Counter
from pathlib import Path

from PIL import Image


CATEGORIES = (
    "maps",
    "location_backgrounds",
    "event_scenes",
    "expression_animation_deltas",
    "standing_cg",
    "ui_system",
    "unclassified",
)

UI_NAMES = re.compile(
    r"^(?:ALBUM|ATTENTION|BLACK|BLK|BLL|CG|CL|DIALOG|END|GIRLS|LOGO|"
    r"MENU|MUSIC|NAME|OP|PARTS|ROLL|SC|SLOT|TITLE|WORDBACK|YEAR|MARKER)"
)
EVENT_NAMES = re.compile(
    r"^(?:[A-Q](?:H|L)?\d{2}|[A-M]_(?:END|WORD)|BAD\d|INTRO|KADO\d)"
)
STANDING_NAMES = re.compile(r"^[A-X](?:[1-9]A?|A)?$")
LOCATION_NAMES = re.compile(r"^\d{2}[A-Z0-9_]*$")
NAMED_STANDING = {
    "KUMIKO", "KURUMI", "MAI", "MAIJIMA", "MISA",
    "NANA_M", "SAKURAKO", "TOMOMI", "YUI",
}
SPECIAL_STANDING = NAMED_STANDING | {"U", "V", "VA"}
SPECIAL_UI = {"ALL", "CALFACE", "FRAME", "FRAME_M", "OKAIPART", "VOL", "VOL_M"}


def image_facts(path: Path) -> dict:
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        width, height = rgb.size
        pixels = rgb.get_flattened_data() if hasattr(rgb, "get_flattened_data") else rgb.getdata()
        colors = Counter(pixels)
        dominant_color, dominant_count = colors.most_common(1)[0]
        return {
            "width": width,
            "height": height,
            "mode": image.mode,
            "dominant_color": list(dominant_color),
            "dominant_ratio": round(dominant_count / (width * height), 6),
        }


def classify(path: Path, facts: dict) -> tuple[str, str, float]:
    stem = path.stem.upper()
    size = (facts["width"], facts["height"])
    green_key = facts["dominant_color"] == [0, 255, 0]
    green_ratio = facts["dominant_ratio"]

    if stem.startswith("SMP"):
        return "maps", "SMP map or map sprite sheet", 1.0

    if stem.endswith("AN"):
        return (
            "expression_animation_deltas",
            "AN animation/delta naming convention",
            0.94,
        )

    if re.fullmatch(r"KAO\d+", stem):
        return (
            "expression_animation_deltas",
            "KAO face portrait naming convention",
            0.95,
        )

    if (
        LOCATION_NAMES.fullmatch(stem)
        and "GATU" not in stem
        and size == (640, 400)
    ):
        return "location_backgrounds", "numbered 640x400 location variant", 0.91

    if (
        STANDING_NAMES.fullmatch(stem)
        and green_key
        and green_ratio >= 0.40
        and size == (640, 400)
    ):
        return "standing_cg", "single-character chroma-key standing sprite", 0.93

    if stem in SPECIAL_STANDING:
        return "standing_cg", "named or special character standing/composite sheet", 0.82

    if EVENT_NAMES.match(stem):
        return "event_scenes", "character/event scene naming convention", 0.88

    if stem in SPECIAL_UI:
        return "ui_system", "special system or UI asset", 0.88

    if UI_NAMES.match(stem) or "GATU" in stem:
        return "ui_system", "system, menu, or UI naming convention", 0.90

    return "unclassified", "no high-confidence naming rule", 0.0


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("project", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source = args.source.resolve()
    asset_root = args.project.resolve() / "assets" / "original"
    files = sorted(source.glob("*.png"), key=lambda item: item.name.casefold())
    if not files:
        raise SystemExit(f"No PNG files found in {source}")

    records = []
    counts: Counter[str] = Counter()
    for path in files:
        facts = image_facts(path)
        category, reason, confidence = classify(path, facts)
        counts[category] += 1
        destination = asset_root / category / path.name
        record = {
            "filename": path.name,
            "category": category,
            "relative_path": destination.relative_to(args.project.resolve()).as_posix(),
            "reason": reason,
            "confidence": confidence,
            **facts,
            "size_bytes": path.stat().st_size,
            "sha256": sha256(path),
        }
        records.append(record)
        if not args.dry_run:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)

    print(f"source files: {len(files)}")
    for category in CATEGORIES:
        print(f"{category}: {counts[category]}")

    if args.dry_run:
        return 0

    catalog = asset_root / "_catalog"
    catalog.mkdir(parents=True, exist_ok=True)
    manifest = {
        "source": str(source),
        "total": len(records),
        "counts": {category: counts[category] for category in CATEGORIES},
        "records": records,
    }
    (catalog / "asset_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    with (catalog / "asset_manifest.csv").open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=records[0].keys())
        writer.writeheader()
        writer.writerows(records)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
