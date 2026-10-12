"""Build the libai5 bridge binary (analysis/ext/mesdump.exe) with gcc.

    py tools/libai5_bridge/build_mesdump.py [--libai5 analysis/ext/libai5] [--gcc gcc]

libai5 (nunuhara, GPL-2.0) is cloned shallowly into analysis/ext/ when the
checkout is missing - never into the tracked tree. The build needs gcc, libpng
and zlib on the compiler's search path (Strawberry Perl's mingw toolchain has
all three); meson is not required because the sources are compiled directly.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BRIDGE = Path(__file__).resolve().parent
LIBAI5_URL = "https://github.com/nunuhara/libai5"
CFLAGS = ["-std=c11", "-D_DEFAULT_SOURCE", "-O1", "-w"]


def sources(libai5: Path) -> list[Path]:
    found = sorted((libai5 / "nulib" / "src").glob("*.c"))
    found += sorted((libai5 / "src").glob("*.c"))
    for sub in ("mes", "arc", "cg"):
        found += sorted((libai5 / "src" / sub).glob("*.c"))
    return found


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--libai5", default=str(ROOT / "analysis" / "ext" / "libai5"))
    parser.add_argument("--out", default=str(ROOT / "analysis" / "ext" / "mesdump.exe"))
    parser.add_argument("--gcc", default="gcc")
    args = parser.parse_args(argv)
    libai5 = Path(args.libai5)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    if not (libai5 / "meson.build").exists():
        print("cloning", LIBAI5_URL, "->", libai5)
        subprocess.run(["git", "clone", "-q", "--depth", "1", "--recurse-submodules", "--shallow-submodules",
                        LIBAI5_URL, str(libai5)], check=True)
    include = ["-I", str(libai5 / "include"), "-I", str(libai5 / "nulib" / "include")]
    obj_dir = out.parent / "obj"
    obj_dir.mkdir(exist_ok=True)
    objects = []
    for source in sources(libai5) + [BRIDGE / "mesdump.c"]:
        relative = source.relative_to(libai5) if source.is_relative_to(libai5) else Path("bridge") / source.name
        obj = obj_dir / (str(relative).replace("/", "_").replace("\\", "_")[:-2] + ".o")
        if not obj.exists() or obj.stat().st_mtime < source.stat().st_mtime:
            subprocess.run([args.gcc, *CFLAGS, *include, "-c", str(source), "-o", str(obj)], check=True)
        objects.append(str(obj))
    subprocess.run([args.gcc, "-o", str(out), *objects, "-lpng", "-lz"], check=True)
    print("built", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
