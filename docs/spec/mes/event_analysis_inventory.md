# Event analysis frontier

Measured on 2026-09-08 from the read-only authoritative `mes.arc`, SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
This extends the [literal caller inventory](event_corpus_inventory.md) with
current Python Phase 1–4 handoffs. It is an analysis work inventory, not a
certificate that every event or branch can already be replayed.

## Measurement and evidence

`tools/build_event_analysis_inventory.py` consumes the source-bound
`config/event_catalog/route_classification_v1.json` and catalog v8 revision 23.
It builds one actual `python_phase1_4` handoff per indexed entry or incoming
caller, preserving instruction-v45 boundaries and recording the actual handoff
hash. It rechecks every listed intro against the caller's typed instruction:
entry hash, code-relative start, exclusive end, command and target must match.
The existing full literal-inventory validator independently checks completeness
of the classification input across all 1,016 archive entries; this new pass does
not claim to independently rediscover callers outside that input.

| Measurement | Count |
| --- | ---: |
| Indexed entries | 169 |
| Indexed entries plus incoming callers analyzed | 326 |
| EVENT-named literal targets | 129 |
| EVENT intro sites | 150 |
| Targets with multiple intro sites | 17 |
| Catalogued EVENT targets, retaining existing support status | 13 |
| Static conditional instruction sites inside the 129 targets | 2,716 |
| Static return/handoff candidates inside those targets | 6,379 |

Terminal candidates count command `00` and root-handoff instructions. Many
returns belong to local message/definition paths; this count is **not** the
number of event completions. Execution must establish the owner and context.
Likewise, write sites are typed write instructions, not an exhaustive proof of
state effects. Since Core 0.320.0 (MA-11) every write run whose destination is
a state storage carries its destination in the state references, so a write
site names what it writes; the two argument-slot runs do not. Opaque spans and
unaligned references remain explicit.

The versioned report schema is `kakyu_event_analysis_inventory/v1`. Its own
fingerprint uses sorted compact UTF-8 JSON excluding root `payload_sha256`;
actual analyzer hashes keep their existing handoff convention unchanged.
The report contains coordinates, counts and hashes, not dialogue or raw bytes.
Unsupported schemas, stale catalog/archive identities, duplicate evidence,
missing EVENT entries and mismatched exact intro records fail closed.

The first report fingerprint was
`80b3d59b572147ffe2e6d43b2f332d072164348ce1dd9fb72d1bc549abaad9d3`. It is now
`f52e6f88fda7eff772ae60501eb0a3021ef4f28a129b0040667e96377194e154`, measured
2026-09-09: the report embeds each entry's class and the classification's
fingerprint, and
[Caller-derived route classification](event_route_classification.md) changed
that day. Every count above is unchanged by it.

One count was added, `tail_named_event_targets`, currently 1. `EVENTA13.MES` is
named by a dispatch record inside an opaque tail
([Dispatch Naming Reachability](dispatch_naming_reachability.md)), so it is an
EVENT entry the classification covers, but it carries **no frontier intro**.
That is deliberate and measured: the record decodes point-wise under
instruction-v45, yet neither Content Core's strict aligned decoder nor this
inventory's own Phase 1-4 handoff frames it in sequence — `FLOOR4.MES` yields 39
handoff calls and none at `0x0E4C`. There is therefore no handoff dispatch to
match an intro against, which is the same reason the entry is not treated as
executable. The `event_targets` and `event_intro_sites` counts stay scoped to
what the handoff frames.

## Caller groups and next evidence

| Caller | EVENT intro sites |
| --- | ---: |
| `GROUND.MES` | 16 |
| `44M.MES` | 11 |
| `01M.MES` | 9 |
| `FLOOR5.MES` | 7 |
| `18M.MES`, `44C.MES` | 6 each |

For example, the report preserves both `GROUND.MES:2612..2628` and
`3513..3529` calls to `EVENTH01.MES`, and both `4319..4335` and
`5285..5301` calls to `EVENTH02.MES`. These are confirmed exact dispatch
coordinates, not evidence that the routes are duplicates. Existing
`01M.MES:39813..39829 -> EVENTJ04.MES` also remains in the same inventory.

A preceding conditional whose false target is beyond a dispatch is recorded as
a **lexical guard candidate** only. That source interval proves neither
dominance nor actual scheduler eligibility: intervening transfers, definitions,
state writes and shared routines must be traced. In particular, GROUND has a
large constant-true enclosing interval at 5860; assigning it as the event guard
would hide the conditions on the real path. The report deliberately leaves
`guard_qualification: not_proven` and runtime coverage unmeasured.

The next unit qualifies source-bound caller groups with witness states and
negative/boundary cases, then follows the callee to an exact terminal or a
recorded unresolved boundary. Shared routines, definitions, choices and caller
resume belong to that trace. Native presentation remains separately labelled.
The two undispatched EVENT entries remain unqualified, not unreachable.
Detailed progress belongs only to EP-07 in `todo/event_player.md`.

## Reproduction

Run from the project root; generated reports remain local under `analysis/`:

```powershell
py tools/build_event_analysis_inventory.py <ELFIMAGE-directory> --jobs 4 > analysis/event-analysis.json
py tools/build_event_analysis_inventory.py <ELFIMAGE-directory> --verify analysis/event-analysis.json
```

`--verify` recomputes every handoff from the original archive and requires an
exact report match, including schema and fingerprint. `--summary` performs the
same analysis but prints only counts and report identity. The headless batch
registers this as `original event analysis frontier`; pair it with
`original event corpus literal dispatch inventory` to check the input's full
caller coverage. Synthetic tests cover payload-coordinate rejection, exact ends,
source identity, omissions/duplicates and serial/process-pool reproducibility.
