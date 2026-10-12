from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path
from typing import Any

from extract_kakyu_arc import read_entries


DEFAULT_MAPS = (
    "MACHI",
    "TRAIN",
    "GROUND",
    "FLOOR1",
    "FLOOR2",
    "FLOOR3",
    "FLOOR4",
    "FLOOR5",
)


def read_archive(archive: Path) -> tuple[bytes, dict[str, tuple[int, int]]]:
    data = archive.read_bytes()
    entries = {name.upper(): (offset, size) for name, offset, size in read_entries(archive)}
    return data, entries


def entry_bytes(data: bytes, entries: dict[str, tuple[int, int]], name: str) -> bytes:
    offset, size = entries[name.upper()]
    return data[offset : offset + size]


def parse_eve(data: bytes) -> list[dict[str, int]]:
    records: list[dict[str, int]] = []
    offset = 0
    while offset + 2 <= len(data):
        event_id = struct.unpack_from("<H", data, offset)[0]
        if event_id == 0xFFFF:
            offset += 2
            break
        if offset + 12 > len(data):
            raise ValueError(f"truncated EVE record at 0x{offset:04X}")
        values = struct.unpack_from("<6H", data, offset)
        records.append(
            {
                "source_offset": offset,
                "event_id": values[0],
                "x1": values[1],
                "y1": values[2],
                "x2": values[3],
                "y2": values[4],
                "direction_mask": values[5],
            }
        )
        offset += 12
    if offset != len(data):
        raise ValueError(f"unexpected EVE tail: parsed={offset} size={len(data)}")
    return records


def parse_ccd(data: bytes) -> dict[str, Any]:
    if len(data) < 8:
        raise ValueError("CCD is shorter than its four-offset header")
    section_offsets = list(struct.unpack_from("<4H", data, 0))
    if section_offsets != sorted(section_offsets) or section_offsets[0] < 8:
        raise ValueError(f"invalid CCD section offsets: {section_offsets}")
    if section_offsets[-1] > len(data):
        raise ValueError(f"CCD section exceeds file size: {section_offsets[-1]} > {len(data)}")

    control_data = data[section_offsets[0] : section_offsets[1]]
    if not control_data or control_data[-1] != 0xFF or (len(control_data) - 1) % 14:
        raise ValueError("CCD control-record section is not 14-byte records plus FF")
    control_records = []
    for index in range(0, len(control_data) - 1, 14):
        record = control_data[index : index + 14]
        control_records.append(
            {
                "record_index": index // 14,
                "source_offset": section_offsets[0] + index,
                "flags": record[0],
                "sprite_index": record[1],
                "collision_width_cells": record[2],
                "collision_height_cells": record[3],
                "initial_x": struct.unpack_from("<H", record, 4)[0],
                "initial_y": struct.unpack_from("<H", record, 6)[0],
                "direction_state": record[8],
                "movement_program_index": record[9],
                "raw_hex": record.hex(),
            }
        )

    preset_offset = section_offsets[2]
    sprite_offset = section_offsets[3]
    preset_data = data[preset_offset:sprite_offset]
    if len(preset_data) % 4:
        raise ValueError(f"CCD entrance-preset section is not divisible by four: {len(preset_data)}")
    entrance_presets = []
    for index in range(0, len(preset_data), 4):
        camera_x, camera_y, actor_x, actor_y = preset_data[index : index + 4]
        entrance_presets.append(
            {
                "preset_index": index // 4,
                "source_offset": preset_offset + index,
                "camera_x": camera_x,
                "camera_y": camera_y,
                "actor_x": actor_x,
                "actor_y": actor_y,
            }
        )
    return {
        "section_offsets": section_offsets,
        "section_sizes": [
            section_offsets[1] - section_offsets[0],
            section_offsets[2] - section_offsets[1],
            section_offsets[3] - section_offsets[2],
            len(data) - section_offsets[3],
        ],
        "control_record_count": len(control_records),
        "control_records": control_records,
        "primary_actor": control_records[0] if control_records else None,
        "entrance_preset_count": len(entrance_presets),
        "entrance_presets": entrance_presets,
    }


def parse_mpc(data: bytes) -> dict[str, Any]:
    if len(data) < 4:
        raise ValueError("MPC is shorter than its width/height header")
    width, height = struct.unpack_from("<2H", data, 0)
    expected_size = 4 + width * height * 3
    cells = data[4:expected_size]
    blocked = []
    open_cells = []
    if expected_size == len(data):
        for index in range(width * height):
            cell = (index % width, index // width)
            if cells[index * 3 + 2] & 0x80:
                blocked.append(cell)
            else:
                open_cells.append(cell)

    def bounds(points: list[tuple[int, int]]) -> dict[str, int] | None:
        if not points:
            return None
        xs = [point[0] for point in points]
        ys = [point[1] for point in points]
        return {"x1": min(xs), "y1": min(ys), "x2": max(xs), "y2": max(ys)}

    open_set = set(open_cells)
    components = []
    while open_set:
        seed = open_set.pop()
        pending = [seed]
        component = [seed]
        while pending:
            x, y = pending.pop()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in open_set:
                    open_set.remove(neighbor)
                    pending.append(neighbor)
                    component.append(neighbor)
        components.append({"cell_count": len(component), "bounds": bounds(component)})
    components.sort(key=lambda item: item["cell_count"], reverse=True)

    row_spans = []
    open_lookup = set(open_cells)
    for y in range(height):
        spans = []
        start = None
        for x in range(width + 1):
            is_open = x < width and (x, y) in open_lookup
            if is_open and start is None:
                start = x
            elif not is_open and start is not None:
                spans.append([start, x - 1])
                start = None
        row_spans.append({"y": y, "x_spans_inclusive": spans})

    return {
        "width_cells": width,
        "height_cells": height,
        "record_size": 3,
        "expected_size": expected_size,
        "size_matches": expected_size == len(data),
        "movement_collision_flag": {"record_byte": 2, "mask": "0x80"},
        "open_cell_count": len(open_cells),
        "blocked_cell_count": len(blocked),
        "open_cell_bounds": bounds(open_cells),
        "open_components_4_way": components,
        "open_row_spans": row_spans,
    }


def derive_actor_navigation(
    data: bytes,
    width: int,
    height: int,
    actor_width: int,
    actor_height: int,
    entrance_presets: list[dict[str, int]],
) -> dict[str, Any]:
    def cell_is_open(x: int, y: int) -> bool:
        return not (data[4 + (y * width + x) * 3 + 2] & 0x80)

    anchors = []
    for y in range(height - actor_height + 1):
        for x in range(width - actor_width + 1):
            foot_cells = (
                (foot_x, foot_y)
                for foot_y in range(y + 1, y + actor_height)
                for foot_x in range(x, x + actor_width)
            )
            if all(cell_is_open(foot_x, foot_y) for foot_x, foot_y in foot_cells):
                anchors.append((x, y))

    anchor_set = set(anchors)
    component_records = []
    component_by_anchor = {}
    while anchor_set:
        seed = anchor_set.pop()
        pending = [seed]
        component = [seed]
        while pending:
            x, y = pending.pop()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in anchor_set:
                    anchor_set.remove(neighbor)
                    pending.append(neighbor)
                    component.append(neighbor)
        component_records.append(component)
    component_records.sort(key=len, reverse=True)
    for component_index, component in enumerate(component_records):
        for anchor in component:
            component_by_anchor[anchor] = component_index

    def point_bounds(points: list[tuple[int, int]]) -> dict[str, int] | None:
        if not points:
            return None
        return {
            "x1": min(point[0] for point in points),
            "y1": min(point[1] for point in points),
            "x2": max(point[0] for point in points),
            "y2": max(point[1] for point in points),
        }

    components = []
    for component_index, component in enumerate(component_records):
        preset_indices = [
            preset["preset_index"]
            for preset in entrance_presets
            if component_by_anchor.get((preset["actor_x"], preset["actor_y"])) == component_index
        ]
        components.append(
            {
                "component_index": component_index,
                "anchor_count": len(component),
                "bounds": point_bounds(component),
                "entrance_preset_indices": preset_indices,
            }
        )

    anchor_lookup = set(anchors)
    row_spans = []
    for y in range(height - actor_height + 1):
        spans = []
        start = None
        for x in range(width - actor_width + 2):
            is_open = x <= width - actor_width and (x, y) in anchor_lookup
            if is_open and start is None:
                start = x
            elif not is_open and start is not None:
                spans.append([start, x - 1])
                start = None
        row_spans.append({"y": y, "x_spans_inclusive": spans})

    return {
        "actor_width_cells": actor_width,
        "actor_height_cells": actor_height,
        "collision_foot_row_range_relative": [1, actor_height - 1],
        "anchor_count": len(anchors),
        "anchor_bounds": point_bounds(anchors),
        "components_4_way": components,
        "clear_foot_entrance_preset_count": sum(
            (preset["actor_x"], preset["actor_y"]) in anchor_lookup
            for preset in entrance_presets
        ),
        "anchor_row_spans": row_spans,
    }


def audit_map(
    archive_data: bytes,
    entries: dict[str, tuple[int, int]],
    map_name: str,
) -> dict[str, Any]:
    source_files: dict[str, Any] = {}
    blobs: dict[str, bytes] = {}
    for extension in ("EVE", "CCD", "MPC"):
        name = f"{map_name}.{extension}"
        blob = entry_bytes(archive_data, entries, name)
        blobs[extension] = blob
        archive_offset, size = entries[name]
        source_files[extension.lower()] = {
            "entry": name,
            "archive_offset": archive_offset,
            "size": size,
            "sha256": hashlib.sha256(blob).hexdigest(),
        }

    events = parse_eve(blobs["EVE"])
    ccd = parse_ccd(blobs["CCD"])
    mpc = parse_mpc(blobs["MPC"])
    primary_actor = ccd["primary_actor"]
    if primary_actor and mpc["size_matches"]:
        mpc["primary_actor_navigation"] = derive_actor_navigation(
            blobs["MPC"],
            mpc["width_cells"],
            mpc["height_cells"],
            primary_actor["collision_width_cells"],
            primary_actor["collision_height_cells"],
            ccd["entrance_presets"],
        )

    return {
        "map": map_name,
        "source_files": source_files,
        "mpc": mpc,
        "ccd": ccd,
        "events": events,
    }


def render_collision_maps(maps: list[dict[str, Any]], output_dir: Path) -> None:
    from PIL import Image, ImageDraw

    output_dir.mkdir(parents=True, exist_ok=True)
    scale = 8
    panels = []
    for map_data in maps:
        mpc = map_data["mpc"]
        width = mpc["width_cells"]
        height = mpc["height_cells"]
        image = Image.new("RGB", (width * scale, height * scale), (35, 39, 46))
        draw = ImageDraw.Draw(image)
        for row in mpc["open_row_spans"]:
            y = row["y"]
            for x1, x2 in row["x_spans_inclusive"]:
                draw.rectangle(
                    (x1 * scale, y * scale, (x2 + 1) * scale - 1, (y + 1) * scale - 1),
                    fill=(214, 229, 207),
                )
        for event in map_data["events"]:
            draw.rectangle(
                (
                    event["x1"] * scale,
                    event["y1"] * scale,
                    (event["x2"] + 1) * scale - 1,
                    (event["y2"] + 1) * scale - 1,
                ),
                outline=(239, 68, 68),
                width=2,
            )
        actor = map_data["ccd"]["primary_actor"]
        actor_width = actor["collision_width_cells"] if actor else 1
        actor_height = actor["collision_height_cells"] if actor else 1
        for preset in map_data["ccd"]["entrance_presets"]:
            x = preset["actor_x"]
            y = preset["actor_y"]
            draw.rectangle(
                (
                    x * scale,
                    y * scale,
                    (x + actor_width) * scale - 1,
                    (y + actor_height) * scale - 1,
                ),
                outline=(48, 198, 222),
                width=2,
            )
        path = output_dir / f"{map_data['map'].lower()}_collision.png"
        image.save(path)
        panels.append((map_data["map"], image))

    label_height = 18
    overview_width = max(image.width for _, image in panels)
    overview_height = sum(image.height + label_height for _, image in panels)
    overview = Image.new("RGB", (overview_width, overview_height), (18, 20, 24))
    draw = ImageDraw.Draw(overview)
    y = 0
    for name, image in panels:
        draw.text((4, y + 2), name, fill=(245, 245, 245))
        y += label_height
        overview.paste(image, (0, y))
        y += image.height
    overview.save(output_dir / "map_collision_overview.png")


def render_mpc_world_texture(
    archive_data: bytes,
    entries: dict[str, tuple[int, int]],
    map_name: str,
    atlas_name: str,
    output_path: Path,
) -> None:
    """Rebuild a native 16-pixel-cell map from its packed MPC tile layers."""
    from PIL import Image

    mpc_name = f"{map_name.upper()}.MPC"
    dat_name = f"{atlas_name.upper()}.DAT"
    pal_name = f"{atlas_name.upper()}.PAL"
    mpc = entry_bytes(archive_data, entries, mpc_name)
    atlas = entry_bytes(archive_data, entries, dat_name)
    palette = entry_bytes(archive_data, entries, pal_name)
    width, height = struct.unpack_from("<2H", mpc, 0)
    expected_mpc_size = 4 + width * height * 3
    if len(mpc) != expected_mpc_size:
        raise ValueError(f"unexpected {mpc_name} size: {len(mpc)} != {expected_mpc_size}")
    if len(atlas) != 640 * 400:
        raise ValueError(f"unexpected {dat_name} size: {len(atlas)}")
    if len(palette) != 256 * 3:
        raise ValueError(f"unexpected {pal_name} size: {len(palette)}")

    tile_size = 16
    atlas_width = 640
    atlas_height = 400
    atlas_columns = atlas_width // tile_size
    atlas_rows = atlas_height // tile_size
    no_overlay_tile = 0x3FF
    world_width = width * tile_size
    world_height = height * tile_size
    pixels = bytearray(world_width * world_height)

    def blit(tile_id: int, destination_x: int, destination_y: int, transparent: bool) -> None:
        if tile_id < 0 or tile_id >= atlas_columns * atlas_rows:
            raise ValueError(f"tile id outside {atlas_name} atlas: {tile_id}")
        source_x = (tile_id % atlas_columns) * tile_size
        # Native tile pointers enumerate the bottom row first in the top-down
        # DAT byte stream, so atlas row zero begins at source y=384.
        source_y = atlas_height - tile_size - (tile_id // atlas_columns) * tile_size
        for row in range(tile_size):
            source = (source_y + row) * atlas_width + source_x
            destination = (destination_y + row) * world_width + destination_x
            if not transparent:
                pixels[destination : destination + tile_size] = atlas[source : source + tile_size]
                continue
            for column in range(tile_size):
                color_index = atlas[source + column]
                if color_index != 0:
                    pixels[destination + column] = color_index

    for cell_index in range(width * height):
        packed = int.from_bytes(mpc[4 + cell_index * 3 : 7 + cell_index * 3], "little")
        base_tile = packed & 0x3FF
        overlay_tile = (packed >> 10) & 0x3FF
        destination_x = (cell_index % width) * tile_size
        destination_y = (cell_index // width) * tile_size
        blit(base_tile, destination_x, destination_y, transparent=False)
        if overlay_tile != no_overlay_tile:
            blit(overlay_tile, destination_x, destination_y, transparent=True)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.frombytes("P", (world_width, world_height), bytes(pixels))
    # AI5 PAL entries store channels as BGR.  Saving the indexed image with an
    # RGB palette swaps red and blue and can make the evening atlas look like a
    # plausible-but-broken night map, so convert through the native BGR order.
    image.putpalette(list(palette), rawmode="BGR")
    image.convert("RGB").save(output_path)
    print(
        f"map_texture={map_name.upper()} atlas={atlas_name.upper()} "
        f"size={world_width}x{world_height} output={output_path}"
    )


def render_map_actor_sprite(
    archive_data: bytes,
    entries: dict[str, tuple[int, int]],
    actor_name: str,
    output_path: Path,
) -> None:
    """Extract the original 12-frame, 32-pixel map actor strip as RGBA."""
    from PIL import Image

    dat_name = f"{actor_name.upper()}.DAT"
    pal_name = f"{actor_name.upper()}.PAL"
    pixels = entry_bytes(archive_data, entries, dat_name)
    palette = entry_bytes(archive_data, entries, pal_name)
    if len(pixels) != 640 * 32:
        raise ValueError(f"unexpected {dat_name} size: {len(pixels)}")
    if len(palette) != 256 * 3:
        raise ValueError(f"unexpected {pal_name} size: {len(palette)}")

    indexed = Image.frombytes("P", (640, 32), pixels)
    indexed.putpalette(list(palette), rawmode="BGR")
    indexed = indexed.transpose(Image.Transpose.FLIP_TOP_BOTTOM).crop((0, 0, 384, 32))
    alpha_source = Image.frombytes("L", (640, 32), pixels)
    alpha_source = alpha_source.transpose(Image.Transpose.FLIP_TOP_BOTTOM).crop((0, 0, 384, 32))
    alpha = alpha_source.point(lambda value: 0 if value == 0 else 255)
    image = indexed.convert("RGBA")
    image.putalpha(alpha)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path)
    print(f"map_actor={actor_name.upper()} frames=12 size=384x32 output={output_path}")


def write_runtime_projections(
    maps: list[dict[str, Any]],
    archive_sha256: str,
    output_dir: Path,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for map_data in maps:
        mpc = map_data["mpc"]
        ccd = map_data["ccd"]
        actor = ccd["primary_actor"]
        source_files = map_data["source_files"]
        projection = {
            "schema_version": "kakyu_original_map_collision/v1",
            "map_id": map_data["map"],
            "source": {
                "archive": "data.arc",
                "archive_sha256": archive_sha256,
                "mpc_entry": source_files["mpc"]["entry"],
                "mpc_sha256": source_files["mpc"]["sha256"],
                "ccd_entry": source_files["ccd"]["entry"],
                "ccd_sha256": source_files["ccd"]["sha256"],
                "eve_entry": source_files["eve"]["entry"],
                "eve_sha256": source_files["eve"]["sha256"],
            },
            "cell_size_logical": 16,
            "camera": {
                "width_cells": 40,
                "height_cells": 25,
            },
            "grid": {
                "width": mpc["width_cells"],
                "height": mpc["height_cells"],
                "clear_row_spans": mpc["open_row_spans"],
            },
            "primary_actor": {
                "width_cells": actor["collision_width_cells"],
                "height_cells": actor["collision_height_cells"],
                "foot_row_start_relative": 1,
                "foot_row_end_relative": actor["collision_height_cells"] - 1,
            },
            "events": map_data["events"],
            "entrance_presets": ccd["entrance_presets"],
        }
        path = output_dir / f"{map_data['map'].lower()}_collision.json"
        path.write_text(
            json.dumps(projection, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


def simplify_operand(value: Any) -> Any:
    if isinstance(value, dict):
        preferred = {}
        for key in ("type", "value", "records", "ast", "storage", "index"):
            if key in value:
                preferred[key] = simplify_operand(value[key])
        return preferred
    if isinstance(value, list):
        return [simplify_operand(item) for item in value]
    return value


def dump_mes_range(path: Path, start: int, end: int) -> None:
    document = json.loads(path.read_text(encoding="utf-8"))
    print(f"MES {document['source']['entry']} code range 0x{start:04X}..0x{end:04X}")
    seen: set[int] = set()
    for node in document["nodes"]:
        for instruction in node.get("instructions", []):
            offset = instruction["sourceOffset"]
            if not start <= offset < end or offset in seen:
                continue
            seen.add(offset)
            operands = simplify_operand(instruction.get("operands", []))
            print(
                f"0x{offset:04X} {instruction['op']:<30} "
                f"{instruction['rawHex']} {json.dumps(operands, ensure_ascii=False, separators=(',', ':'))}"
            )


def list_resource_ops(path: Path) -> None:
    document = json.loads(path.read_text(encoding="utf-8"))
    print(f"MES {document['source']['entry']} resource-bearing instructions")
    seen: set[int] = set()
    for node in document["nodes"]:
        for instruction in node.get("instructions", []):
            offset = instruction["sourceOffset"]
            if offset in seen:
                continue
            raw = bytes.fromhex(instruction["rawHex"])
            strings = []
            start = None
            for index, value in enumerate(raw + b"\0"):
                if 0x20 <= value < 0x7F:
                    if start is None:
                        start = index
                elif start is not None:
                    if index - start >= 4:
                        strings.append(raw[start:index].decode("ascii"))
                    start = None
            if not any("." in value for value in strings):
                continue
            seen.add(offset)
            print(f"0x{offset:04X} {instruction['op']:<24} {', '.join(strings)}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit Kakyu map EVE/CCD/MPC records directly from data.arc."
    )
    parser.add_argument("data_arc", type=Path, nargs="?")
    parser.add_argument("--maps", nargs="+", default=list(DEFAULT_MAPS))
    parser.add_argument("-o", "--output", type=Path)
    parser.add_argument("--render-dir", type=Path)
    parser.add_argument("--runtime-dir", type=Path)
    parser.add_argument("--machi-world", type=Path)
    parser.add_argument("--machi-atlas", default="MACHIN_3")
    parser.add_argument("--protagonist-sprite", type=Path)
    parser.add_argument("--dump-mes-ir", type=Path)
    parser.add_argument("--list-resource-ops", type=Path)
    parser.add_argument("--range", nargs=2, type=lambda value: int(value, 0), metavar=("START", "END"))
    args = parser.parse_args()

    if args.dump_mes_ir:
        if not args.range:
            parser.error("--dump-mes-ir requires --range START END")
        dump_mes_range(args.dump_mes_ir, args.range[0], args.range[1])
        return
    if args.list_resource_ops:
        list_resource_ops(args.list_resource_ops)
        return

    if args.data_arc is None:
        parser.error("data_arc is required unless --dump-mes-ir is used")
    archive_data, entries = read_archive(args.data_arc)
    maps = [audit_map(archive_data, entries, name.upper()) for name in args.maps]
    archive_sha256 = hashlib.sha256(archive_data).hexdigest()
    if args.render_dir:
        render_collision_maps(maps, args.render_dir)
    if args.runtime_dir:
        write_runtime_projections(maps, archive_sha256, args.runtime_dir)
    if args.machi_world:
        render_mpc_world_texture(
            archive_data,
            entries,
            "MACHI",
            args.machi_atlas,
            args.machi_world,
        )
    if args.protagonist_sprite:
        render_map_actor_sprite(
            archive_data,
            entries,
            "CHARA",
            args.protagonist_sprite,
        )
    result = {
        "schema": "kakyu_map_source_audit/v2",
        "source": {
            "archive": str(args.data_arc),
            "size": len(archive_data),
            "sha256": archive_sha256,
        },
        "maps": maps,
    }
    text = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
        print(f"maps={len(maps)} output={args.output}")
    else:
        print(text, end="")


if __name__ == "__main__":
    main()
