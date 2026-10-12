from __future__ import annotations

import argparse
import struct
from pathlib import Path

from PIL import Image

from ai5_lz import ai5_lz_decompress


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT_DIR = ROOT / "assets" / "_extracted" / "kakyu" / "png" / "mmo_best"


def read_mmo(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if data[:4] != b"MMO ":
        raise ValueError(f"{path} does not start with MMO header")

    width = struct.unpack_from("<I", data, 12)[0]
    height = struct.unpack_from("<I", data, 16)[0]
    decoded = ai5_lz_decompress(data[0x28:])
    expected = width * height * 3
    if len(decoded) < expected:
        raise ValueError(f"{path}: decoded {len(decoded)} bytes, expected {expected}")
    return width, height, decoded[:expected]


def read_mmo_loose(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if data[:4] != b"MMO ":
        raise ValueError(f"{path} does not start with MMO header")
    width = struct.unpack_from("<I", data, 12)[0]
    height = struct.unpack_from("<I", data, 16)[0]
    decoded = ai5_lz_decompress(data[0x28:])
    expected = width * height * 3
    if len(decoded) < expected:
        decoded += b"\0" * (expected - len(decoded))
    return width, height, decoded[:expected]


def restore_delta_image(decoded: bytes, width: int, height: int) -> bytearray:
    out = bytearray(decoded)
    stride = width * 3
    for x in range(3, stride):
        out[x] = (out[x] + out[x - 3]) & 0xFF
    for y in range(1, height):
        row = y * stride
        previous = row - stride
        for x in range(stride):
            out[row + x] = (out[row + x] + out[previous + x]) & 0xFF
    return out


def flip_vertical(data: bytearray, width: int, height: int) -> bytearray:
    stride = width * 3
    out = bytearray(len(data))
    for y in range(height):
        out[y * stride : (y + 1) * stride] = data[(height - 1 - y) * stride : (height - y) * stride]
    return out


def bgr_to_rgb(data: bytearray) -> bytearray:
    out = bytearray(len(data))
    out[0::3] = data[2::3]
    out[1::3] = data[1::3]
    out[2::3] = data[0::3]
    return out


def save_png(path: Path, width: int, height: int, rgb: bytes | bytearray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.frombytes("RGB", (width, height), bytes(rgb)).save(path)


def convert_one(src: Path, out_dir: Path, skip_existing: bool = False) -> Path:
    out = out_dir / f"{src.stem}.png"
    if skip_existing and out.exists():
        return out
    try:
        width, height, decoded = read_mmo(src)
    except ValueError:
        width, height, decoded = read_mmo_loose(src)
    image = restore_delta_image(decoded, width, height)
    image = bgr_to_rgb(image)
    image = flip_vertical(image, width, height)
    save_png(out, width, height, image)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert AI5 MMO images to PNG.")
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("-o", "--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--skip-existing", action="store_true")
    args = parser.parse_args()

    sources: list[Path] = []
    for src in args.inputs:
        if src.is_dir():
            sources.extend(sorted(src.glob("*.MMO")))
            sources.extend(sorted(src.glob("*.mmo")))
        else:
            sources.append(src)

    failures: list[tuple[Path, str]] = []
    for src in sources:
        try:
            print(convert_one(src, args.out_dir, args.skip_existing))
        except Exception as exc:
            failures.append((src, str(exc)))
            print(f"SKIP {src}: {exc}")

    if failures:
        print(f"\nfailed={len(failures)}")
        for src, message in failures:
            print(f"{src}\t{message}")


if __name__ == "__main__":
    main()
