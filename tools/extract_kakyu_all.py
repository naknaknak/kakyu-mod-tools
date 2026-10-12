from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from extract_kakyu_arc import extract_arc


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "assets"
DEFAULT_ELFIMAGE = ASSET_ROOT / "_source" / "kakyu" / "ELFIMAGE"
DEFAULT_WORK_DIR = ASSET_ROOT / "_extracted" / "kakyu" / "raw"
DEFAULT_PNG_DIR = ASSET_ROOT / "_extracted" / "kakyu" / "png"


def run_py(args: list[str]) -> None:
    subprocess.run([sys.executable, *args], cwd=ROOT, check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Rebuild Kakyu image extraction from ARC files.")
    parser.add_argument(
        "--elfimage-dir",
        type=Path,
        default=DEFAULT_ELFIMAGE,
        help="Read-only directory containing mmo.arc, data.arc, and optionally mes.arc.",
    )
    parser.add_argument(
        "--work-dir",
        type=Path,
        default=DEFAULT_WORK_DIR,
        help="Directory for extracted ARC contents.",
    )
    parser.add_argument(
        "--png-dir",
        type=Path,
        default=DEFAULT_PNG_DIR,
        help="Directory for converted PNG files.",
    )
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument(
        "--include-mes",
        action="store_true",
        help="Also extract mes.arc. Image conversion does not use it.",
    )
    args = parser.parse_args()

    elfimage_dir = args.elfimage_dir.resolve()
    image_dir = args.work_dir.resolve() / "image"
    mes_dir = args.work_dir.resolve() / "mes"
    png_dir = args.png_dir.resolve()

    tasks = [
        (elfimage_dir / "mmo.arc", image_dir),
        (elfimage_dir / "data.arc", image_dir),
    ]
    if args.include_mes:
        tasks.append((elfimage_dir / "mes.arc", mes_dir))

    for arc_path, out_dir in tasks:
        written, skipped = extract_arc(arc_path, out_dir, args.overwrite)
        print(f"{arc_path}: written={written} skipped={skipped} out={out_dir}")

    run_py(
        [
            "tools/convert_mmo_best.py",
            str(image_dir),
            "-o",
            str(png_dir / "mmo_best"),
            "--skip-existing",
        ]
    )
    run_py(["tools/convert_dat_pal.py", str(image_dir), "-o", str(png_dir / "dat_pal")])


if __name__ == "__main__":
    main()
