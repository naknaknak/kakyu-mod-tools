#!/usr/bin/env python3
"""Extract reusable world-map UI sprites from the original atlas PNGs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", type=Path)
    return parser.parse_args()


def keyed_crop(
    atlas: Image.Image, rect: tuple[int, int, int, int], *, trim: bool = False
) -> Image.Image:
    x, y, width, height = rect
    image = atlas.crop((x, y, x + width, y + height)).convert("RGBA")
    pixels = []
    source_pixels = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    for red, green, blue, alpha in source_pixels:
        if green >= 240 and red <= 24 and blue <= 24:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((red, green, blue, alpha))
    image.putdata(pixels)
    if trim:
        bounds = image.getchannel("A").getbbox()
        if bounds:
            image = image.crop(bounds)
    return image


def add_item(
    records: list[dict],
    atlas_name: str,
    item_id: str,
    rect: tuple[int, int, int, int],
    group: str,
    *,
    trim: bool = False,
) -> None:
    records.append(
        {
            "atlas": atlas_name,
            "id": item_id,
            "rect": list(rect),
            "group": group,
            "trim": trim,
        }
    )


def build_parts_records(records: list[dict]) -> None:
    atlas = "PARTS.png"
    month_cells = {
        1: (0, 0, 64),
        2: (0, 40, 64),
        3: (0, 80, 64),
        4: (0, 120, 64),
        5: (0, 160, 64),
        6: (0, 200, 64),
        7: (0, 240, 64),
        8: (0, 280, 64),
        9: (0, 320, 64),
        10: (0, 360, 64),
        11: (64, 0, 80),
        12: (64, 40, 80),
    }
    for month, (x, y, width) in month_cells.items():
        add_item(records, atlas, f"month_{month:02d}", (x, y, width, 40), "date", trim=True)

    weekdays = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
    for index, weekday in enumerate(weekdays):
        add_item(records, atlas, f"weekday_{weekday}", (64, 80 + index * 40, 84, 40), "date", trim=True)

    add_item(records, atlas, "period_am", (160, 0, 48, 40), "time", trim=True)
    add_item(records, atlas, "period_pm", (160, 40, 48, 40), "time", trim=True)

    for day in range(1, 32):
        column = (day - 1) // 8
        row = (day - 1) % 8
        add_item(
            records,
            atlas,
            f"day_{day:02d}",
            (208 + column * 72, row * 48, 72, 48),
            "date",
        )

    add_item(records, atlas, "money_yen", (160, 80, 20, 20), "money", trim=True)
    for digit in range(10):
        add_item(records, atlas, f"money_digit_{digit}", (168, 100 + digit * 20, 12, 20), "money", trim=True)
    add_item(records, atlas, "money_glyph_strip", (160, 80, 20, 220), "money")

    add_item(records, atlas, "hud_month_panel", (520, 272, 120, 40), "hud")
    add_item(records, atlas, "hud_day_panel", (520, 312, 120, 48), "hud")
    add_item(records, atlas, "hud_weekday_panel", (520, 360, 120, 40), "hud")


def build_frame_records(records: list[dict]) -> None:
    atlas = "FRAME.png"
    items = (
        ("speaker_portrait_frame", (0, 0, 104, 104), "dialogue"),
        ("speaker_message_frame", (96, 0, 512, 80), "dialogue"),
        ("message_frame", (0, 128, 608, 80), "dialogue"),
        ("message_log_controls", (456, 104, 152, 24), "controls"),
        ("dialogue_controls_primary", (0, 208, 144, 32), "controls"),
        ("dialogue_controls_yellow_a", (144, 208, 144, 32), "controls"),
        ("dialogue_controls_pink", (288, 208, 144, 32), "controls"),
        ("dialogue_controls_yellow_b", (432, 208, 144, 32), "controls"),
        ("dialogue_controls_tail", (576, 208, 48, 32), "controls"),
        ("choice_bar_left", (0, 240, 224, 24), "choice"),
        ("choice_bar_center", (224, 240, 224, 24), "choice"),
        ("choice_arrows", (448, 240, 176, 24), "choice"),
        ("log_controls_bottom", (0, 264, 144, 32), "controls"),
    )
    for item_id, rect, group in items:
        add_item(records, atlas, item_id, rect, group)


def build_calface_records(records: list[dict]) -> None:
    atlas = "CALFACE.png"
    for index in range(13):
        add_item(records, atlas, f"calendar_face_{index:02d}", (0, index * 24, 24, 24), "calendar_face")


def main() -> int:
    args = parse_args()
    project = args.project.resolve()
    source_root = project / "assets" / "original" / "ui_system"
    output_root = project / "assets" / "derived" / "world_map_ui"
    output_root.mkdir(parents=True, exist_ok=True)

    records: list[dict] = []
    build_parts_records(records)
    build_frame_records(records)
    build_calface_records(records)

    atlases: dict[str, Image.Image] = {}
    for record in records:
        atlas_name = record["atlas"]
        if atlas_name not in atlases:
            atlases[atlas_name] = Image.open(source_root / atlas_name).convert("RGBA")
        image = keyed_crop(atlases[atlas_name], tuple(record["rect"]), trim=record["trim"])
        group_root = output_root / record["group"]
        group_root.mkdir(parents=True, exist_ok=True)
        destination = group_root / f"{record['id']}.png"
        image.save(destination)
        record["output"] = destination.relative_to(project).as_posix()
        record["output_size"] = list(image.size)

    manifest = {
        "source_root": source_root.relative_to(project).as_posix(),
        "output_root": output_root.relative_to(project).as_posix(),
        "count": len(records),
        "records": records,
    }
    (output_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"extracted {len(records)} world-map UI sprites to {output_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
