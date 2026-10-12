"""Write the known-absent media register from a full original playback package.

WD-21 U1 (D7, C3). The package's `media_inventory` block says, for every media
and loader name its records reference, which original archive ships it or that
every archive of its kind was searched and holds none. This tool takes the
`shipped: false` rows of that block from a **full** export of the original
catalog and writes them as `config/event_catalog/known_absent_media_v1.json`
(`kakyu_known_absent_media/v1`): the register the batch gates compare against
(`tools/content_suite/known_absent_media.gd`).

The register holds the name-level fact only - `(kind, normalized name)` and the
archives that were searched - and the SHA-256 of every archive the inventory
opened. The evidence (the occurrences, the entry and offset of each use) stays in
the package manifest. There is no "reached" set: the gate is name-level, which is
a tool decision over an original-data fact, not a claim about what the original
engine does with a missing file.

The tool refuses, rather than guesses, when the manifest is visibly not the
default full export: a manifest without `media_inventory`, a block whose schema
id this tool does not know, a selected-event export, an export without
analysis-group members, a row that is undecided (`shipped: null`), or a row that
disagrees with the block's own header. It cannot tell an `--include-unbound-groups`
superset from the default full export (the manifest does not record that flag),
so it does not refuse one; gate 1's exact compare against the written register
catches a register made from such a package, as stale rows.
It reads no archive and writes with LF line endings whatever the platform (TD-45).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from payload_values import MEDIA_INVENTORY_SCHEMA as INVENTORY_SCHEMA
from payload_values import MEDIA_KINDS as KINDS
from payload_values import fingerprint, is_sha256

SCHEMA = "kakyu_known_absent_media/v1"
NORMALIZATION = "upper_case"
MEMBERSHIP_RULE_FULL = "catalog_events_and_analysis_group_members"
EVIDENCE_BOUNDARY = (
    "every archive of the kind was opened (its SHA-256 is in the header) and none holds "
    "the name; the occurrences and their entry/offset evidence are in the package "
    "manifest's media_inventory. This bounds what the original archives ship, not what "
    "the native host can construct at runtime; the gate that compares against it is a "
    "tool decision over that original-data fact"
)
DEFAULT_OUT = Path("config/event_catalog/known_absent_media_v1.json")


class RegisterError(ValueError):
    """The package cannot yield a register; the message says why."""


def load_manifest(package_dir: Path) -> dict[str, Any]:
    path = Path(package_dir) / "manifest.json"
    if not path.is_file():
        raise RegisterError(f"{path} is not a file; pass a playback package directory")
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise RegisterError(f"{path} could not be read as JSON: {error}") from error
    if not isinstance(manifest, dict):
        raise RegisterError(f"{path} is not a JSON object")
    return manifest


def build_register(manifest: dict[str, Any]) -> dict[str, Any]:
    """The register document for a full original package manifest, with its
    fingerprint. Raises `RegisterError` for anything that is not one."""
    inventory = manifest.get("media_inventory")
    if inventory is None:
        raise RegisterError("the manifest has no media_inventory block (a package from before WD-21 U1)")
    if not isinstance(inventory, dict):
        raise RegisterError("media_inventory is not an object")
    if inventory.get("schema") != INVENTORY_SCHEMA:
        raise RegisterError(
            f"media_inventory schema {inventory.get('schema')!r} is not {INVENTORY_SCHEMA!r}; "
            "this tool only knows that block"
        )
    if inventory.get("normalization") != NORMALIZATION:
        raise RegisterError(f"media_inventory normalization {inventory.get('normalization')!r} is not {NORMALIZATION!r}")
    _require_full_export(manifest)
    archives = _archives_header(inventory)
    names = inventory.get("names")
    if not isinstance(names, list):
        raise RegisterError("media_inventory.names is not an array")
    rows: dict[tuple[str, str], dict[str, Any]] = {}
    for position, row in enumerate(names):
        if not isinstance(row, dict):
            raise RegisterError(f"media_inventory.names[{position}] is not an object")
        shipped = row.get("shipped")
        kind, name = row.get("kind"), row.get("name")
        if shipped is None:
            raise RegisterError(
                f"{kind} {name} is undecided (shipped: null): an archive of its kind was not in the source root, "
                "so the export is not a full original export"
            )
        if shipped is True:
            continue
        if shipped is not False:
            raise RegisterError(f"media_inventory.names[{position}] has a shipped state that is not true, false or null")
        if kind not in KINDS:
            raise RegisterError(f"media_inventory.names[{position}] has the unknown kind {kind!r}")
        if not isinstance(name, str) or not name or name != name.upper():
            raise RegisterError(f"{kind} name {name!r} is not a non-empty upper-case name")
        searched = row.get("searched")
        if not isinstance(searched, list) or not searched or not all(isinstance(item, str) for item in searched):
            raise RegisterError(f"{kind} {name} is absent but has no searched archives")
        if len(set(searched)) != len(searched):
            raise RegisterError(f"{kind} {name} lists a searched archive twice")
        for archive in searched:
            if archive not in archives:
                raise RegisterError(f"{kind} {name} was searched in {archive}, which the header holds no SHA-256 for")
        if (kind, name) in rows:
            raise RegisterError(f"{kind} {name} has two absent rows")
        rows[(kind, name)] = {"kind": kind, "name": name, "searched": sorted(searched)}
    register: dict[str, Any] = {
        "schema": SCHEMA,
        "inventory_schema": INVENTORY_SCHEMA,
        "normalization": NORMALIZATION,
        "archives": archives,
        "rows": [rows[key] for key in sorted(rows)],
        "evidence_boundary": EVIDENCE_BOUNDARY,
    }
    register["payload_sha256"] = fingerprint(register)
    return register


def _require_full_export(manifest: dict[str, Any]) -> None:
    membership = manifest.get("membership")
    if not isinstance(membership, dict) or membership.get("rule") != MEMBERSHIP_RULE_FULL:
        rule = membership.get("rule") if isinstance(membership, dict) else None
        raise RegisterError(
            f"membership rule {rule!r} is not {MEMBERSHIP_RULE_FULL!r}: the register comes from a full export of "
            "the original catalog, never from a selected-event export"
        )
    # The rule is the full one for any export without --event, including one run
    # with --no-analysis-groups, whose absent set is a subset; refuse it too.
    groups = membership.get("analysis_groups")
    if not isinstance(groups, list) or not groups or not membership.get("analysis_group_members"):
        raise RegisterError("the export carries no analysis-group members: the register comes from the default full export")


def _archives_header(inventory: dict[str, Any]) -> dict[str, str]:
    archives = inventory.get("archives")
    if not isinstance(archives, dict) or not archives:
        raise RegisterError("media_inventory.archives is not a non-empty object")
    for archive, sha in archives.items():
        if not isinstance(archive, str) or not archive or not is_sha256(sha):
            raise RegisterError(f"media_inventory.archives[{archive!r}] is not a SHA-256")
    return {archive: archives[archive] for archive in sorted(archives)}


def serialize(register: dict[str, Any]) -> bytes:
    """Deterministic UTF-8 JSON, two-space indented, LF line endings, one
    trailing newline. Bytes, so no platform newline translation applies."""
    text = json.dumps(register, ensure_ascii=False, indent=2, allow_nan=False)
    return (text + "\n").encode("utf-8")


def write_register(path: Path, register: dict[str, Any]) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(serialize(register))


def counts_by_kind(register: dict[str, Any]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for row in register["rows"]:
        counts[row["kind"]] = counts.get(row["kind"], 0) + 1
    return {kind: counts[kind] for kind in sorted(counts)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("package", type=Path, help="a full original playback package directory (holds manifest.json)")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help=f"register path (default {DEFAULT_OUT})")
    arguments = parser.parse_args(argv)
    try:
        register = build_register(load_manifest(arguments.package))
    except RegisterError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    write_register(arguments.out, register)
    print(json.dumps({
        "out": str(arguments.out),
        "rows": len(register["rows"]),
        "rows_by_kind": counts_by_kind(register),
        "archives": list(register["archives"]),
        "payload_sha256": register["payload_sha256"],
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
