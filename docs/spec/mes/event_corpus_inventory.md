# Event corpus literal dispatch inventory

## Scope

`kakyu_mes_event_corpus_inventory/v1` is a read-only, archive-wide inventory of
every literal script dispatch in the authoritative `mes.arc`. It exists to
bound Event Player catalog completeness: the
[Event Player Product Goal](../tech/event_player.md) requires a caller-derived
event corpus rather than a filename scan, and this inventory supplies the
caller graph that corpus is derived from.

The inventory is **structural only**. It reports which entries are literal
dispatch targets and which are never dispatched by a literal record. It does
not classify any callee as a playable event, system script, duplicate route or
unreachable route. Those classifications require per-entry evidence and remain
open.

## Authoritative identity

| Source | SHA-256 |
|---|---|
| `mes.arc` | `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6` |
| inventory report | `5b3a041f283a7ac1e62b7389ba0f7f67479b78fceac0a49968226bf82f0f64ef` |

The report fingerprint covers the complete canonical inventory document,
including every dispatch row. Two consecutive runs produce the identical
fingerprint. Evidence type is direct read-only `mes.arc` container parsing plus
the current Content Core record framing and instruction decoding. No original
dialogue, payload bytes or machine-specific path is retained.

The fingerprint also covers `content_core_version`, so it moves on every Core
bump even when nothing about the archive or the decode changed, and a run at
HEAD will not print the value above. That value is the one this document was
written with, at Core 0.282.0. Measured 2026-09-09: a run at Core 0.312.0
produced `fae8a0f66f9d8e43882a9093a207b98ba8365a18a75eb036d065d4e940a8b72c`,
and substituting `0.282.0` back into that report reproduced the value above
exactly, so the report's content has not changed since it was recorded.

## Complete dispatch partition

All 1,016 MES/LIB entries decode with no container or analysis failure. The two
script-bearing commands partition exactly:

| Command | Records | Literal target | Decoded op |
|---|---:|---:|---|
| `0x0F` nested call | 9,466 | 9,466 | `script_dispatch` |
| `0x0E` | 81,173 | 1,008 | `script_handoff_marker` |
| `0x0E` | — | 0 | `protagonist_name_insert` (80,165) |

Two properties make the graph complete rather than merely sampled:

- every command-`0x0F` record in the archive carries a literal `.MES` target,
  so no nested call is unresolved; and
- command-`0x0E` partitions into exactly two decoded ops with no residue, so
  the 80,165 non-dispatch records are accounted for as name insertion rather
  than left as unclassified dispatch candidates.

Totals: **10,474 literal dispatch records**, **312 distinct callers**,
**587 distinct targets**. Every dispatch target resolves to an entry that
exists in the archive; there are zero dangling targets.

## Archive partition

The 1,016 entries partition exactly into 587 dispatch targets and 429 entries
never named by a literal dispatch record **in a strictly decoded region**.

That scope qualifier was measured on 2026-09-09 and added then; the counts
below are unchanged. Every count in this document is over the bytes the strict
aligned decoder reads, and it stops at the first opaque boundary in each
address-table region. 418 of the 429 are in fact named by a byte-exact dispatch
record inside one of those preserved opaque tails, so the never-dispatched set
is smaller than it looks here and cannot carry an unreachability claim at all.
See [Dispatch Naming Reachability](dispatch_naming_reachability.md), whose
audit reproduces all 10,474 rows below before scanning past them.

**"Never dispatched" is not "unreachable."** Entries entered through shared
routines, registered definitions or the native host do not appear as literal
targets. `LIBLARY.LIB` and `DEF_MAIN.MES` are both in the never-dispatched set
and are both known-reachable; both are named by the two command-`0x0D` inline
script execution sites in `START.MES`, measured in the document linked
above. The set
is therefore a candidate pool for the product goal's
`unreachable_stored_route` classification, not the classification itself.

## Event-named subset

Of the 587 targets, 129 are `EVENT*.MES`. Two further `EVENT*.MES` entries,
`EVENTA13.MES` and `EVENTL09.MES`, are never dispatched by a literal record in
a strictly decoded region. This document called them the strongest
`unreachable_stored_route` candidates in the archive; measurement on 2026-09-09
retired `EVENTA13.MES` from that role, because `FLOOR4.MES:0x0E4C` carries a
command-`0x0E` root handoff naming it inside an opaque tail. `EVENTL09.MES`
remains the only `EVENT*.MES` entry that nothing measured names. Neither is
confirmed unreachable here.

Each of the 129 reachable EVENT-named targets is dispatched by exactly one kind
of record: 62 are reached only through command-`0x0E` root handoff, 67 only
through command-`0x0F` nested call. No EVENT-named target mixes the two forms.
17 of them have more than one dispatch site, which makes them the candidate
pool for the product goal's `duplicate_route` and multi-entry-point cases.

Filename family versus current Event Player catalog coverage:

| Family | Reachable targets | In catalog |
|---|---:|---:|
| EVENTA | 12 | 0 |
| EVENTB | 5 | 5 |
| EVENTC | 14 | 0 |
| EVENTD | 7 | 7 |
| EVENTE | 8 | 0 |
| EVENTF | 8 | 0 |
| EVENTG | 7 | 0 |
| EVENTH | 12 | 0 |
| EVENTI | 10 | 0 |
| EVENTJ | 9 | 0 |
| EVENTK | 7 | 0 |
| EVENTL | 14 | 0 |
| EVENTM | 15 | 0 |
| EVENTQ | 1 | 0 |
| **Total** | **129** | **12** |

The catalog covers the EVENTB and EVENTD families completely and none of the
other twelve. The filename family is an index for reading this table, not
evidence of event identity; the product goal explicitly rejects a filename-only
corpus, and non-`EVENT` entries such as `01M.MES` and `B_PIC.MES` already
participate in confirmed event routes.

## Cross-checks against existing evidence

The archive-wide scan reproduces coordinates that four earlier per-route audits
established independently, which is the inventory's main correctness evidence:

- `01M.MES` has exactly one literal dispatch site, and it is the command-`0x0E`
  record at `MACHI.MES:0xACB1..0xACBC` recorded in
  [Station candidate conditional prefix](station_candidate_prefix.md);
- `EVENTB03.MES` has exactly one literal dispatch site, and it is the
  command-`0x0E` record at `01M.MES:0x788F`, matching both the handoff record
  in [Station-to-EVENTB03 Decision](station_eventb03_decision.md) and the
  existing catalog event identifier `original/eventb03/01m-0000788f`; and
- `MACHI.MES` is the most-dispatched target in the archive at 666 sites, which
  matches its role as the town-map hub and root-replacement terminal in
  [B03 Choice Routes](eventb03_choice_routes.md).

None of these coordinates was supplied to the scan. They were derived from the
archive by the same decoder pass that produced every other row.

## Evidence boundary

Confidence is **Confirmed** for the exact record partition, the 10,474-row
literal dispatch inventory, the 587/429 archive partition, the EVENT-named
counts and dispatch-form split, the absence of dangling targets, and
deterministic reproduction.

The following remain **Unresolved / unqualified**:

- whether any specific callee is a playable event, a duplicate route, a shared
  system script or an unreachable stored route;
- reachability through shared routines, registered definitions, address-table
  rows and the native host, which this inventory does not model. Cross-entry
  naming is now measured in
  [Dispatch Naming Reachability](dispatch_naming_reachability.md); host row
  selection within an already-named entry stays open;
- natural scheduler eligibility for any route, unchanged from
  [Station-to-EVENTB03 Decision](station_eventb03_decision.md); and
- every per-entry required state, branch, choice, resource, terminal and caller
  resume required by the full catalog contract.

This inventory therefore bounds the remaining event corpus. It does not add a
playable route, a catalog entry or a playback preset.

## Re-measured under Core 0.316.0 (2026-09-13)

With command `0x0D` framed as one system call (`format_and_method.md`,
"Command `0x0D` is one system call") the strict aligned decoder reads the
whole archive - no opaque boundary remains - so the partition above, which
was scoped to the bytes the decoder reached, now covers every byte. The
literal dispatch inventory reproduces at 11,124 rows: 9,875 command-`0x0F`
nested calls and 1,249 command-`0x0E` root handoffs, from 360 callers to
1,005 targets; 11 entries are never named by a dispatch record, and of the
EVENT entries only `EVENTL09.MES` is never named (130 EVENT targets). Command
`0x0E` is the root handoff alone: the protagonist-name insert it used to share
the command with is `System.function[14]` under command `0x0D`, 80,272
of them across the archive. The 10,474-row partition recorded above is the
2026-09-08 measurement of the same bytes under the separator framing and is
kept as history; every one of its rows is among the 11,124.

## Reproduction

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_event_corpus_inventory.gd -- `
  <ELFIMAGE-directory> [out.json]
```

The authoritative run passes **19 checks** with zero decode failures and prints
the report fingerprint above. Every expected count is a fail-closed constant, so
a changed archive or changed record framing fails the audit instead of silently
reporting a new corpus. No UI verification is required.
