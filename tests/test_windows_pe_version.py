from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build_windows_distribution as builder  # noqa: E402
import windows_pe_version as pe_version  # noqa: E402


def _align(data: bytearray) -> None:
    while len(data) % 4:
        data.append(0)


def _node(key: str, value: bytes, kind: int, children: bytes = b"", value_length: int | None = None) -> bytes:
    body = bytearray(6)
    body += key.encode("utf-16-le") + b"\0\0"
    _align(body)
    body += value
    _align(body)
    body += children
    declared = value_length if value_length is not None else len(value)
    struct.pack_into("<HHH", body, 0, len(body), declared, kind)
    return bytes(body)


def _string(name: str, text: str) -> bytes:
    encoded = (text + "\0").encode("utf-16-le")
    node = bytearray(_node(name, encoded, 1, value_length=len(text) + 1))
    _align(node)
    return bytes(node)


def version_resource(file_version: tuple[int, int, int, int], strings: dict[str, str]) -> bytes:
    fixed = struct.pack(
        "<IIIIIIIIIIIII",
        pe_version.FIXED_SIGNATURE, 0x00010000,
        (file_version[0] << 16) | file_version[1], (file_version[2] << 16) | file_version[3],
        (file_version[0] << 16) | file_version[1], (file_version[2] << 16) | file_version[3],
        0x3F, 0, 0x40004, 1, 0, 0, 0,
    )
    table = _node("040904b0", b"", 1, b"".join(_string(k, v) for k, v in strings.items()))
    string_info = _node("StringFileInfo", b"", 1, table)
    return _node("VS_VERSION_INFO", fixed, 0, string_info)


def synthetic_pe(resource: bytes) -> bytes:
    section_rva, raw_offset = 0x1000, 0x400
    # resource tree: type 16 -> id 1 -> language 0x409 -> data entry
    tree = bytearray()
    tree += struct.pack("<IIHHHH", 0, 0, 0, 0, 0, 1) + struct.pack("<II", 16, 0x80000000 | 0x18)
    tree += struct.pack("<IIHHHH", 0, 0, 0, 0, 0, 1) + struct.pack("<II", 1, 0x80000000 | 0x30)
    tree += struct.pack("<IIHHHH", 0, 0, 0, 0, 0, 1) + struct.pack("<II", 0x409, 0x48)
    data_offset = 0x58
    tree += struct.pack("<IIII", section_rva + data_offset, len(resource), 0, 0)
    assert len(tree) == data_offset
    section = bytes(tree) + resource
    image = bytearray(raw_offset + len(section))
    image[:2] = b"MZ"
    struct.pack_into("<I", image, 0x3C, 0x80)
    image[0x80:0x84] = b"PE\0\0"
    coff = 0x84
    struct.pack_into("<HH", image, coff, 0x8664, 1)
    struct.pack_into("<H", image, coff + 16, 0xF0)
    optional = coff + 20
    struct.pack_into("<H", image, optional, 0x20B)
    struct.pack_into("<II", image, optional + 112 + 2 * 8, section_rva, len(section))
    row = optional + 0xF0
    image[row : row + 8] = b".rsrc\0\0\0"
    struct.pack_into("<IIII", image, row + 8, len(section), section_rva, len(section), raw_offset)
    image[raw_offset:] = section
    return bytes(image)


class WindowsPeVersionTests(unittest.TestCase):
    STRINGS = {
        "FileDescription": "Kakyu ARC Browser",
        "FileVersion": "0.344.0.0",
        "ProductName": "Kakyu Mod Tools",
        "ProductVersion": "0.344.0.0",
    }

    def test_reads_fixed_versions_and_strings_from_a_pe(self) -> None:
        image = synthetic_pe(version_resource((0, 344, 0, 0), self.STRINGS))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.exe"
            path.write_bytes(image)
            info = pe_version.read_version_info(path)
        self.assertEqual("0.344.0.0", info["file_version"])
        self.assertEqual("0.344.0.0", info["product_version"])
        self.assertEqual(self.STRINGS, info["strings"])

    def test_rejects_files_without_a_version_resource(self) -> None:
        with self.assertRaises(pe_version.PeVersionError):
            pe_version.parse_pe(b"not an executable")
        image = bytearray(synthetic_pe(version_resource((1, 2, 3, 4), self.STRINGS)))
        struct.pack_into("<I", image, 0x84 + 20 + 112 + 16, 0)
        with self.assertRaises(pe_version.PeVersionError):
            pe_version.parse_pe(bytes(image))
        other_type = bytearray(synthetic_pe(version_resource((1, 2, 3, 4), self.STRINGS)))
        struct.pack_into("<I", other_type, 0x400 + 16, 3)
        with self.assertRaises(pe_version.PeVersionError):
            pe_version.parse_pe(bytes(other_type))

    def test_rejects_a_malformed_version_blob(self) -> None:
        blob = bytearray(version_resource((1, 2, 3, 4), self.STRINGS))
        fixed_offset = blob.index(struct.pack("<I", pe_version.FIXED_SIGNATURE))
        blob[fixed_offset] ^= 1
        with self.assertRaises(pe_version.PeVersionError):
            pe_version.parse_version_resource(bytes(blob))

    def test_native_version_is_the_core_version_plus_a_zero_build(self) -> None:
        self.assertEqual("0.344.0.0", builder.native_version("0.344.0"))
        for bad in ("0.344", "0.344.0.1", "v0.344.0", ""):
            with self.assertRaises(ValueError):
                builder.native_version(bad)

    def test_preset_identities_follow_the_tracked_export_presets(self) -> None:
        presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        identities = builder.preset_identities(presets)
        self.assertEqual(6, len(identities))
        self.assertEqual(
            {"product_name": "Kakyu Mod Tools", "file_description": "Kakyu ARC Browser"},
            identities["Windows ARC Browser"],
        )
        self.assertEqual({"Kakyu Mod Tools"}, {row["product_name"] for row in identities.values()})
        self.assertEqual(6, len({row["file_description"] for row in identities.values()}))

    def test_identity_check_refuses_the_engine_templates_identity(self) -> None:
        declared = {"product_name": "Kakyu Mod Tools", "file_description": "Kakyu ARC Browser"}
        good = {"file_version": "0.344.0.0", "product_version": "0.344.0.0", "strings": dict(self.STRINGS)}
        builder.check_identity(good, "0.344.0.0", declared)
        template = {"file_version": "4.7.0.0", "product_version": "4.7.0.0", "strings": {"FileDescription": "Godot Engine"}}
        with self.assertRaises(ValueError):
            builder.check_identity(template, "0.344.0.0", declared)
        with self.assertRaises(ValueError):
            builder.check_identity(good, "0.345.0.0", declared)
        wrong_app = {**good, "strings": {**self.STRINGS, "FileDescription": "Kakyu MES Editor"}}
        with self.assertRaises(ValueError):
            builder.check_identity(wrong_app, "0.344.0.0", declared)
        with self.assertRaises(ValueError):
            builder.check_identity(good, "0.344.0.0", {})


if __name__ == "__main__":
    unittest.main()
