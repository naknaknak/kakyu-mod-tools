# Materialized ARC Provenance Contract

## Purpose

`kakyu_materialized_arc_provenance/v1` is the portable lineage record for a
new ARC copy produced by the Content Suite. It lets another app distinguish
the exact user-selected original ARC, a verified original-derived ARC, and an
unknown raw ARC that must not inherit original-evidence labels.

The sidecar is named `<output>.arc.kakyu-provenance.json`. It contains hashes
and portable identities only. It never contains an ELFIMAGE path, an output
path, a replacement source path, original payload bytes, or dialogue.

## Versioned document

The strict top-level fields are:

- `schema`: `kakyu_materialized_arc_provenance/v1`;
- `core_version`: the publishing Content Core version;
- `archive`: canonical lower-case ARC identity;
- `declared_compatibility`: `remake_only`,
  `original_engine_compatible`, `original_engine_unverified`, or `mixed`;
- `source`: archive identity, SHA-256, byte length, and entry count;
- `materialized`: output filename, SHA-256, byte length, entry count, and
  verified writer layout;
- `replacements`: one record per changed entry in source ARC index order;
- `workspace`: optional portable project/workspace generation identity.

Each replacement binds the safe ARC entry name, original entry SHA-256,
replacement SHA-256, original size, and replacement size. Duplicate names are
rejected case-insensitively. Source and output entry counts must be equal; this
contract does not authorize add, remove, or reorder operations.

When present, `workspace` binds project ID/version/revision, compatibility
objective, source content-set fingerprint, project SHA-256, manifest SHA-256,
and immutable workspace generation SHA-256. It is accepted only when that
snapshot contains the same source ARC identity and hash.

Unknown fields, unsafe names, malformed hashes, unsupported compatibility
values, unbounded JSON, and invalid numeric values fail closed.

## Publication

`KakyuArcProvenance` requires the SHA-256 captured when the source ARC was
opened and, for file-backed replacements, every staged payload SHA-256. It:

1. acquires a sibling materialization lock;
2. refuses source overwrite or an existing ARC/sidecar destination;
3. delegates to the shared streaming `ArcWriter`;
4. reopens the staged ARC and records exact replacement bindings;
5. writes and rehashes a sibling sidecar temporary;
6. publishes only while both final paths remain absent;
7. verifies complete lineage against the still-open original reader; and
8. removes only its exact output bytes if final verification fails.

The original ARC is always opened read-only and remains byte-identical.

## Classification

`classify()` returns one of:

- `exact_original`: selected ARC hash equals the supplied original reader;
- `verified_original_derived`: sidecar/output hashes, entry order, every
  unchanged entry, and every replacement verify against that reader;
- `declared_original_derived`: sidecar and derived ARC verify internally, but
  no original reader was supplied, so lineage remains unverified; or
- `unknown_raw`: sidecar is absent/invalid, the output was changed, the wrong
  original was selected, or any entry-level proof fails.

Compatibility is a declaration carried end to end; it is not promoted by
classification. Verified lineage does not prove original-engine behavior.

## Resolver consumption

Content Core `0.160.0` can attach one `verified_original_derived` ARC as an
effective layer above its separately registered authoritative original ARC.
The original reader remains the evidence source. The derived reader supplies
effective bytes and cannot be registered without the matching original.

The resolver builds a path-free entry snapshot only after full provenance
classification succeeds. Changed entries retain the sidecar compatibility;
unchanged entries retain exact-original compatibility. Resolution order is
`overlay -> materialized ARC -> original ARC -> fallback`. Failed activation
preserves the previous valid derived layer, re-registering the original
invalidates that layer, and archive/entry bytes are rechecked before a derived
descriptor is returned or extracted.
