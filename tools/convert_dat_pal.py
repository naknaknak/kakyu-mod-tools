from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_IMAGE_DIR = ROOT / "assets" / "_extracted" / "kakyu" / "raw" / "image"
DEFAULT_OUT_DIR = ROOT / "assets" / "_extracted" / "kakyu" / "png" / "dat_pal"

DIMENSIONS_BY_SIZE = {
    20480: (640, 32),
    40960: (640, 64),
    184320: (640, 288),
    256000: (640, 400),
}


def load_palette(path: Path) -> list[int]:
    raw = path.read_bytes()
    if len(raw) != 768:
        raise ValueError(f"unexpected palette size for {path}: {len(raw)}")
    return list(raw)


def convert_one(dat_path: Path, out_dir: Path) -> str:
    pal_path = dat_path.with_suffix(".PAL")
    if not pal_path.exists():
        return "missing-palette"

    data = dat_path.read_bytes()
    dimensions = DIMENSIONS_BY_SIZE.get(len(data))
    if not dimensions:
        return f"unknown-size:{len(data)}"

    width, height = dimensions
    image = Image.frombytes("P", (width, height), data)
    image.putpalette(load_palette(pal_path), rawmode="BGR")
    image = image.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    if len(data) == 20480:
        alpha = Image.frombytes("L", (width, height), data)
        alpha = alpha.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        alpha = alpha.point(lambda value: 0 if value == 0 else 255)
        rgba = image.convert("RGBA")
        rgba.putalpha(alpha)
        rgba.save(out_dir / f"{dat_path.stem}.png")
    else:
        image.convert("RGB").save(out_dir / f"{dat_path.stem}.png")
    return "ok"


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert Kakyu DAT/PAL indexed images to PNG.")
    parser.add_argument("image_dir", nargs="?", type=Path, default=DEFAULT_IMAGE_DIR)
    parser.add_argument("-o", "--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    counts: dict[str, int] = {}
    for dat_path in sorted(args.image_dir.glob("*.DAT")):
        status = convert_one(dat_path, args.out_dir)
        counts[status] = counts.get(status, 0) + 1
        print(f"{dat_path.name}: {status}")
    print("summary:", counts)


if __name__ == "__main__":
    main()
