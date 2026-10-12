# Content Identity Contract

`kakyu_content_identity/v1` is the runtime projection that keeps original
route evidence separate from the bytes currently presented by the remake.
It is produced by `KakyuContentIdentity`; it is not an authored manifest and
must not be used as a substitute for an overlay, workspace, or materialized
ARC provenance record.

## Purpose

An original MES route can remain proven even when one of its referenced image,
animation, or audio entries is replaced. The changed payload must not inherit
an exact-original label merely because its logical archive and entry name are
unchanged. Conversely, a media-only replacement must not invalidate the MES
caller, branch, state, choice, or terminal evidence that selected it.

MES control-flow replacements use a stricter rule. Changed MES bytes may alter
addresses, branches, calls, state effects, or completion. They preserve route
evidence only when a versioned interface validator explicitly reports
`control_flow_compatible`.

## Inputs

Classification requires all of the following at the same time:

- an evidence identity containing the logical archive and entry, the audited
  original archive and entry SHA-256, and one of `image`, `animation`, `audio`,
  or `mes_control_flow`;
- the still-open selected original ARC reader, whose live archive and entry
  fingerprints must match the evidence identity;
- a resolver descriptor for the same case-insensitive logical entry;
- the exact effective payload bytes; and
- a successful, non-empty versioned interface validation, such as the MMO
  image, AX animation, or audio-stream structural contract.

Overlay descriptors additionally bind `base_archive_sha256`,
`original_entry_sha256`, replacement SHA-256, and compatibility. A
`materialized_arc` descriptor is accepted only when its provenance was already
classified as `verified_original_derived` and carries the same source and
entry lineage. Fallback content is structurally usable but has no
original-derived payload proof.

## Output

The path-free projection contains:

- `schema`: `kakyu_content_identity/v1`;
- `relationship`: `exact_original`, `original_derived_compatible`,
  `remake_only`, or `unsupported`;
- `label`, `verified`, `changed`, `compatibility`, and an explanatory reason;
- `route_evidence_preserved`;
- the immutable original evidence identity;
- the effective source, logical name, SHA-256, and byte count; and
- the versioned interface-validation result.

`exact_original` means the effective bytes equal the audited original entry.
`original_derived_compatible` means changed bytes are source-bound and carry a
validated compatible declaration. `remake_only` is playable by the remake but
does not claim original-engine compatibility. `unsupported` means the changed
payload cannot reuse the supplied route evidence; the caller must stop rather
than silently downgrade the label.

## Event Player Boundary

Event Player classifies every resolved MMO image, AX animation, BGM, and voice
payload that it presents. The analysis header reports the effective label while
the existing MES trace and route validator retain their original evidence.
Active overlays therefore exercise this contract now.

The classifier and Content Resolver accept verified materialized-ARC lineage.
Content Core `0.160.0` keeps its authoritative original reader separate from
the effective derived reader and produces the required `materialized_arc`
descriptor. Event Player can transactionally activate a map of verified
media-only derived archives while retaining the original ContentSet for
evidence. Its ordinary file-selection UI and changed-MES interface remain
P2-10 work. This contract does not by itself
authorize a changed MES route, invent an original source, or weaken exact-hash
route gates.

## Safety and Verification

The projection never stores filesystem paths or payload data. Hash or logical
name mismatches fail closed. Ordinary resolver reads continue their own live
payload checks; this projection is not an integrity cache. Synthetic tests
cover exact originals, compatible and remake-only overlays, materialized
lineage, wrong bindings, versioned interfaces, and changed MES rejection.
