"""Rebinds a tracked event-definition set to a re-exported playback package
(WD-21 U2 C6, decision D10; the Core-version pair, TD-57 D5).

    py tools/rebind_event_definitions.py <defs-dir> --from-package <old package dir> \\
        --to-package <new package dir> [--pair {catalog-revision,core-version}] [--dry-run]

A definition set is bound to the package it was projected against: every document
carries `package_binding.package_sha256` and `index.json` carries `package_sha256`
(`docs/spec/data/event_definition_v6.md`). The package hash covers the whole manifest, so
a re-export that changes only what the definitions do not read - WD-21 U2's binding
export moves `source.catalog_revision` (the catalog was revised) and nothing else - still
moves it. Re-projecting the 681 documents for that costs about 70 minutes and changes
nothing but the hash; this tool rewrites the hash instead, under conditions strict enough
that the result is what the re-projection would have written.

It **refuses**, writing nothing, unless all of these hold (shown for the default
`--pair catalog-revision`; the Core pair is described below):

- the two packages' `manifest.json` are canonically equal (sorted keys, compact JSON)
  outside `package_sha256` and `source.catalog_revision`, and differ in exactly those two
  (the hash covers the whole manifest, so a pair that differs in the hash alone is not a
  package pair); each hash is a SHA-256; the manifests name the same package schema;
- the set is a known contract: every document is `kakyu_event_definition/v6` or all are
  `v7` (one of them throughout), named for its own `id`; `index.json` is
  `kakyu_event_definition_index/v2` and lists exactly the set's documents as valid;
  there is no `*.resolved.json` (a resolved twin carries dialogue and is not a tracked
  document);
- every document's `package_binding` names the manifest's package schema and the **old**
  hash, and `index.json` carries the old hash - a document bound to a third hash, or
  already bound to the new one, stops the whole rebind;
- the old hash occurs exactly once in each file and the new one not at all.

It rewrites only that one hash in each document and in `index.json`, as a byte-level
substitution, so the files keep their layout (LF, indent, key order, non-ASCII text) and
the whole set is verified in memory - each result must parse to its original with only
the hash changed - before the first file is replaced. `--dry-run` does all of that and
writes nothing. It prints one JSON line (`ok`, the counts, both hashes and the two
manifest fields that differ) and exits 0, or `{"ok": false, "reason": ...}` and exits 1.

`--pair core-version` (TD-57 D5) takes the other pair: a re-export whose manifest differs
from the old one in `package_sha256` and `content_core_version` only. It is accepted when
the manifests are canonically equal outside those two fields, each carries a non-empty
`content_core_version` string, the two strings differ, and `source.catalog_revision` is
equal. A pair that differs in the catalog revision too is refused with that one reason (the
two pairs are never mixed), and every refusal names the selected pair's fields. The summary
line reports `content_core_version: [old, new]` instead of `catalog_revision`. Everything
about the set (the checks above, the byte-level substitution, the verification, `--dry-run`)
is the same.

Use the Core pair only when the Core change cannot move a run. Manifest equality outside the
two fields proves every other package file identical (`files[]` carries each SHA-256), and
the projectors never read `content_core_version` (they read `media_inventory`, `entries`,
`package_sha256`, `schema` and `source.archive_sha256`), so the rebind writes what a
re-projection would. A Core change that can move a run - one that changes what a definition
holds - needs a re-projection, not a rebind.
"""
from __future__ import annotations

import argparse
import copy
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from payload_values import is_sha256  # noqa: E402

KNOWN_DOCUMENT_SCHEMAS = frozenset({"kakyu_event_definition/v6", "kakyu_event_definition/v7"})
INDEX_SCHEMA = "kakyu_event_definition_index/v2"
# The two kinds of package pair (TD-57 D5) and, for each, the manifest fields a rebind may find
# different, as paths into the manifest.
CATALOG_REVISION_PAIR = "catalog-revision"
CORE_VERSION_PAIR = "core-version"
PAIRS = (CATALOG_REVISION_PAIR, CORE_VERSION_PAIR)
REBINDABLE_FIELDS = ("package_sha256", "source.catalog_revision")
CORE_PAIR_FIELDS = ("package_sha256", "content_core_version")
DIFFERENCE_LIMIT = 12


class RebindError(ValueError):
    """The rebind is refused; the message says why."""


def load_manifest(package_dir):
    path = Path(package_dir) / "manifest.json"
    if not path.is_file():
        raise RebindError("%s is not a file; pass a playback package directory" % path)
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise RebindError("%s could not be read as JSON: %s" % (path, error)) from error
    if not isinstance(manifest, dict):
        raise RebindError("%s is not a JSON object" % path)
    return manifest


def _canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"), allow_nan=False)


def _outside_rebindable(manifest, pair=CATALOG_REVISION_PAIR):
    """The manifest without the two fields a rebind of this pair may change."""
    stripped = copy.deepcopy(manifest)
    stripped.pop("package_sha256", None)
    if pair == CORE_VERSION_PAIR:
        stripped.pop("content_core_version", None)
        return stripped
    source = stripped.get("source")
    if isinstance(source, dict):
        source.pop("catalog_revision", None)
    return stripped


def differing_paths(left, right, prefix="", limit=DIFFERENCE_LIMIT):
    """Dotted paths at which two JSON values differ (a list that differs in length, or a value of
    another type, is reported at its own path), at most `limit` of them."""
    found = []

    def walk(a, b, path):
        if len(found) >= limit:
            return
        if isinstance(a, dict) and isinstance(b, dict):
            for key in sorted(set(a) | set(b)):
                if key not in a or key not in b:
                    found.append("%s.%s" % (path, key) if path else key)
                else:
                    walk(a[key], b[key], "%s.%s" % (path, key) if path else key)
                if len(found) >= limit:
                    return
        elif isinstance(a, list) and isinstance(b, list) and len(a) == len(b):
            for index, (x, y) in enumerate(zip(a, b)):
                walk(x, y, "%s[%d]" % (path, index))
                if len(found) >= limit:
                    return
        elif _canonical(a) != _canonical(b):
            found.append(path or "<root>")

    walk(left, right, prefix)
    return found


def _core_version(manifest):
    value = manifest.get("content_core_version")
    return value if isinstance(value, str) and value else None


def _is_core_pair(old, new):
    """Whether two manifests (already known to have one schema, integer catalog revisions and
    different hashes) are a Core-version pair: equal outside `CORE_PAIR_FIELDS`, with different
    non-empty Core version strings and one catalog revision."""
    old_core, new_core = _core_version(old), _core_version(new)
    return (
        old_core is not None and new_core is not None and old_core != new_core
        and old["source"]["catalog_revision"] == new["source"]["catalog_revision"]
        and _canonical(_outside_rebindable(old, CORE_VERSION_PAIR)) == _canonical(_outside_rebindable(new, CORE_VERSION_PAIR)))


def _check_core_pair(old, new, old_hash, new_hash, schema):
    """The `--pair core-version` checks, one refusal reason at a time: the Core version strings
    first, then a catalog-revision difference (the default pair's field), then the Core versions
    being equal, then everything else."""
    for label, manifest in (("old", old), ("new", new)):
        if _core_version(manifest) is None:
            raise RebindError("the %s manifest has no non-empty content_core_version string" % label)
    old_revision, new_revision = old["source"]["catalog_revision"], new["source"]["catalog_revision"]
    if old_revision != new_revision:
        raise RebindError(
            "the manifests differ in source.catalog_revision (%d, %d): that is the catalog-revision pair, the default; "
            "--pair core-version rebinds a %s difference only and the two are never mixed"
            % (old_revision, new_revision, " and ".join(CORE_PAIR_FIELDS)))
    if _core_version(old) == _core_version(new):
        raise RebindError(
            "the manifests have the same content_core_version (%s) and differ in the hash alone, which covers the "
            "whole manifest: not a Core-version pair" % _core_version(old))
    stripped_old = _outside_rebindable(old, CORE_VERSION_PAIR)
    stripped_new = _outside_rebindable(new, CORE_VERSION_PAIR)
    if _canonical(stripped_old) != _canonical(stripped_new):
        raise RebindError(
            "the manifests differ outside %s (a re-projection is needed): %s"
            % (" and ".join(CORE_PAIR_FIELDS), ", ".join(differing_paths(stripped_old, stripped_new))))
    return old_hash, new_hash, schema


def check_manifests(old, new, pair=CATALOG_REVISION_PAIR):
    """Raises `RebindError` unless the pair is a rebindable package pair of the selected kind
    (`PAIRS`); returns `(old_hash, new_hash, package_schema)`."""
    if pair not in PAIRS:
        raise RebindError("unknown pair %r: expected one of %s" % (pair, ", ".join(PAIRS)))
    old_hash, new_hash = old.get("package_sha256"), new.get("package_sha256")
    if not is_sha256(old_hash) or not is_sha256(new_hash):
        raise RebindError("a manifest has no package_sha256 SHA-256")
    if old_hash == new_hash:
        raise RebindError("both packages have the hash %s...: nothing to rebind" % old_hash[:8])
    schema = old.get("schema")
    if not isinstance(schema, str) or schema != new.get("schema"):
        raise RebindError("the manifests do not name one package schema (%r, %r)" % (schema, new.get("schema")))
    for label, manifest in (("old", old), ("new", new)):
        source = manifest.get("source")
        revision = source.get("catalog_revision") if isinstance(source, dict) else None
        if not isinstance(revision, int) or isinstance(revision, bool):
            raise RebindError("the %s manifest has no integer source.catalog_revision" % label)
    if pair == CORE_VERSION_PAIR:
        return _check_core_pair(old, new, old_hash, new_hash, schema)
    if _canonical(_outside_rebindable(old)) != _canonical(_outside_rebindable(new)):
        paths = differing_paths(_outside_rebindable(old), _outside_rebindable(new))
        hint = ""
        if _is_core_pair(old, new):
            hint = ("; the manifests are a Core-version pair (only content_core_version differs): pass "
                    "--pair core-version if the Core change cannot move a run, otherwise re-project")
        raise RebindError(
            "the manifests differ outside %s (a re-projection is needed): %s%s"
            % (" and ".join(REBINDABLE_FIELDS), ", ".join(paths), hint))
    if old["source"]["catalog_revision"] == new["source"]["catalog_revision"]:
        raise RebindError(
            "the manifests differ in the hash alone, which covers the whole manifest: not a catalog-revision pair")
    return old_hash, new_hash, schema


def _substitute(text, old_hash, new_hash, where):
    if text.count(old_hash) != 1:
        raise RebindError("%s: the old hash occurs %d times, not once" % (where, text.count(old_hash)))
    if new_hash in text:
        raise RebindError("%s: already mentions the new hash" % where)
    return text.replace(old_hash, new_hash)


def _expected_after(document, new_hash, where):
    """The document with only its bound hash changed (a document, or `index.json`)."""
    expected = copy.deepcopy(document)
    if "package_binding" in expected:
        expected["package_binding"]["package_sha256"] = new_hash
    else:
        expected["package_sha256"] = new_hash
    return expected


def plan_rebind(defs_dir, old_hash, new_hash, package_schema):
    """`[(path, new_text_bytes)]` for the index and every document of the set, after every check;
    raises `RebindError` (listing up to 10 of the problems) otherwise."""
    defs_dir = Path(defs_dir)
    if not defs_dir.is_dir():
        raise RebindError("%s is not a directory" % defs_dir)
    index_path = defs_dir / "index.json"
    if not index_path.is_file():
        raise RebindError("%s has no index.json" % defs_dir)
    resolved = sorted(path.name for path in defs_dir.glob("*.resolved.json"))
    if resolved:
        raise RebindError("%d resolved twin(s) in the set (they carry dialogue): %s" % (len(resolved), ", ".join(resolved[:5])))
    problems = []
    plan = []
    schemas = set()
    document_ids = set()

    def read(path):
        raw = path.read_bytes().decode("utf-8")
        return raw, json.loads(raw)

    for path in sorted(defs_dir.glob("*.json")):
        if path.name == "index.json":
            continue
        try:
            raw, document = read(path)
        except (ValueError, UnicodeDecodeError) as error:
            problems.append("%s: not JSON (%s)" % (path.name, error))
            continue
        if not isinstance(document, dict):
            problems.append("%s: not an object" % path.name)
            continue
        schema = document.get("schema_version")
        schemas.add(schema)
        if schema not in KNOWN_DOCUMENT_SCHEMAS:
            problems.append("%s: schema_version %r is not a known contract" % (path.name, schema))
            continue
        if document.get("id") != path.stem:
            problems.append("%s: id %r differs from the file name" % (path.name, document.get("id")))
        binding = document.get("package_binding")
        if not isinstance(binding, dict) or binding.get("schema") != package_schema:
            problems.append("%s: package_binding does not name the package schema %s" % (path.name, package_schema))
            continue
        if binding.get("package_sha256") != old_hash:
            problems.append("%s: bound to %s, not to the old package %s..." % (
                path.name, str(binding.get("package_sha256"))[:8], old_hash[:8]))
            continue
        document_ids.add(path.stem)
        try:
            text = _substitute(raw, old_hash, new_hash, path.name)
            if json.loads(text) != _expected_after(document, new_hash, path.name):
                raise RebindError("%s: the substitution changed more than the bound hash" % path.name)
        except RebindError as error:
            problems.append(str(error))
            continue
        plan.append((path, text.encode("utf-8")))
    if len(schemas) > 1:
        problems.append("the set mixes contracts: %s" % sorted(str(s) for s in schemas))
    try:
        raw, index = read(index_path)
        if not isinstance(index, dict) or index.get("schema") != INDEX_SCHEMA:
            problems.append("index.json: schema is not %s" % INDEX_SCHEMA)
        elif index.get("package_sha256") != old_hash:
            problems.append("index.json: bound to %s, not to the old package %s..." % (str(index.get("package_sha256"))[:8], old_hash[:8]))
        else:
            rows = index.get("documents")
            valid_ids = {row.get("id") for row in rows if isinstance(row, dict) and row.get("ok")} if isinstance(rows, list) else None
            if valid_ids != document_ids:
                problems.append("index.json: the valid rows (%s) are not the set's documents (%s)" % (
                    "?" if valid_ids is None else len(valid_ids), len(document_ids)))
            else:
                text = _substitute(raw, old_hash, new_hash, "index.json")
                if json.loads(text) != _expected_after(index, new_hash, "index.json"):
                    raise RebindError("index.json: the substitution changed more than the bound hash")
                plan.append((index_path, text.encode("utf-8")))
    except (ValueError, UnicodeDecodeError, RebindError) as error:
        problems.append("index.json: %s" % error)
    if not document_ids and not problems:
        problems.append("the set has no document")
    if problems:
        raise RebindError("%d problem(s): %s" % (len(problems), "; ".join(problems[:10])))
    return plan


def apply_plan(plan):
    """Replaces every planned file: all new contents are written beside their targets first, so a
    failure while writing them leaves every original in place; a failure while moving them into place
    removes the leftovers and is reported (a file already moved stays moved)."""
    temporary = []
    try:
        for path, content in plan:
            temp_path = path.with_name(path.name + ".rebind-tmp")
            temp_path.write_bytes(content)
            temporary.append((temp_path, path))
        for temp_path, path in temporary:
            os.replace(temp_path, path)
        temporary = []
    finally:
        for temp_path, _path in temporary:
            if temp_path.exists():
                temp_path.unlink()


def rebind(defs_dir, old_package, new_package, dry_run=False, pair=CATALOG_REVISION_PAIR):
    old_manifest, new_manifest = load_manifest(old_package), load_manifest(new_package)
    old_hash, new_hash, schema = check_manifests(old_manifest, new_manifest, pair)
    plan = plan_rebind(defs_dir, old_hash, new_hash, schema)
    if not dry_run:
        apply_plan(plan)
    documents = [item for item in plan if item[0].name != "index.json"]
    contract = json.loads(documents[0][1].decode("utf-8"))["schema_version"] if documents else None
    summary = {
        "ok": True, "dry_run": bool(dry_run), "contract": contract,
        "documents": len(documents), "index": len(plan) - len(documents),
        "from": old_hash, "to": new_hash,
    }
    if pair == CORE_VERSION_PAIR:
        summary["differing_manifest_fields"] = list(CORE_PAIR_FIELDS)
        summary["content_core_version"] = [old_manifest["content_core_version"], new_manifest["content_core_version"]]
    else:
        summary["differing_manifest_fields"] = list(REBINDABLE_FIELDS)
        summary["catalog_revision"] = [old_manifest["source"]["catalog_revision"], new_manifest["source"]["catalog_revision"]]
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("defs_dir", type=Path, help="the tracked definition set (documents and index.json)")
    parser.add_argument("--from-package", type=Path, required=True, help="the package the set is bound to now")
    parser.add_argument("--to-package", type=Path, required=True, help="the re-exported package to bind it to")
    parser.add_argument(
        "--pair", choices=PAIRS, default=CATALOG_REVISION_PAIR,
        help="the manifest difference the rebind accepts: the catalog revision (default) or, when the Core "
             "change cannot move a run, the Core version")
    parser.add_argument("--dry-run", action="store_true", help="check everything and write nothing")
    args = parser.parse_args(argv)
    try:
        summary = rebind(args.defs_dir, args.from_package, args.to_package, dry_run=args.dry_run, pair=args.pair)
    except RebindError as error:
        print(json.dumps({"ok": False, "reason": str(error)}))
        return 1
    print(json.dumps(summary))
    return 0


if __name__ == "__main__":
    sys.exit(main())
