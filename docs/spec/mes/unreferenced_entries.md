# Entries the shipped product never names

Measured on 2026-09-10 against the configured original `ELFIMAGE` and
`AI5WIN.original.exe`. The archive SHA256 is
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.

[Dispatch Naming Reachability](dispatch_naming_reachability.md) established
which entries no dispatch record, inline script execution or host reference
names. Eight entries were left. This document asks the wider question of the
shipped data: does the name occur **at all**?

## Zero occurrences across every shipped file

`tools/audit_unreferenced_entries.py` scans each file byte-exactly and
case-insensitively for the full entry name.

| File | Size | Occurrences of any of the eight names |
|---|---:|---:|
| `bgm.arc` | 493,788,716 | 0 |
| `voice.arc` | 521,097,594 | 0 |
| `mmo.arc` | 419,962,992 | 0 |
| `tina1.arc` / `tina2.arc` | 32,439,192 / 30,260,198 | 0 |
| `se.arc` | 22,946,714 | 0 |
| `mes.arc` | 18,885,616 | 0 |
| `data.arc` | 8,406,691 | 0 |
| `AI5WIN.INI` (mutable; the game rewrites it, so its size is not pinned) | - | 0 |
| the executable (recorded as `<executable>`, identified by sha256) | 720,896 | 0 |

About 1.5 GB of shipped data, and the names `DATETIME.MES`, `EVENTL09.MES`,
`FLAGINI.MES`, `FLAG_INC.MES`, `M_TIME.MES`, `OMAKE.MES`, `SIZUKA44.MES` and
`_TEST.MES` occur **zero times** in all of it.

The control is `EVENTL10.MES`, which occurs exactly twice in `mes.arc` — and
those two occurrences are exactly the two dispatch records already measured,
`44M.MES:65699` and `EVENTM20.MES:9867`. A name that is dispatched shows up; a
name that is not does not.

Two near-misses are worth recording because they look like hits until the
extension is included. `omake` occurs three times in `mes.arc`, all inside
`OMAKE.MES` itself and all resource names — `omake.a6` and `omake.mmo` twice.
`_test` occurs once in the executable, inside the DirectDraw error string
`DDERR_TESTFINISHED`. Neither is a script name.

## EVENTL09 is a stored earlier build of EVENTL10

`EVENTL09.MES` is the only `EVENT*.MES` entry in that set, and it is not an
orphan. Compared with `EVENTL10.MES`, which is dispatched from two callers:

| Property | `EVENTL09.MES` | `EVENTL10.MES` |
|---|---:|---:|
| message records | 53 | 53 |
| digest of the per-message record hashes | `d6d8f40c7295ea79…` | `d6d8f40c7295ea79…` |
| address-table entries | 31 | 31 |
| typed records | 620 | 703 |
| entry size | 4,393 | 5,105 |
| **`voice_marker`** | **0** | **7** |
| `banked_u16_write_run` | 10 | 28 |
| `branch_if_not_true` | 12 | 16 |
| `definition_invoke` | 0 | 1 |

Corrected 2026-09-14 under Core 0.316.0, which frames command `0x0D` as one
system call: the typed-record rows above read 442 and 524 - the 31 and 32
separator-framed pseudo-command groups became 31 and 32 `system_call`
records each - while message records, their digest, the address-table
entries, the entry sizes and the voice-marker difference are unchanged. The
tracked report was regenerated the same day (payload `68c6c7a537e86cc3…`)
and the original rows are kept as the 2026-09-10 reading.

Every message record is byte-identical, in the same order. The differences are
all additions on the L10 side, and the largest is voice: L09 carries none. The
reading this supports is that L09 is the pre-voice build of the same scene, kept
in the archive when the dispatches moved to the fuller L10.

The scene itself is qualified in [44M Caller Group](44m_caller_group.md): a
late-evening collision on the dormitory stairs whose choice reaches either the
dormitory corridor or the town map.

## Why this is the `unreachable_stored_route` evidence

The Event Player product goal requires an unreachable stored route to carry
"the evidence for that classification". `EVENTL09.MES` now does, and it is the
first row in that class:

- no dispatch record names it, in a strictly decoded region or an opaque tail;
- no inline script execution names it;
- the name occurs zero times in every shipped file, executable included; and
- command `0x0F` is fully literal and command `0x0E` partitions into exactly two
  decoded ops with no residue, so the archive has no mechanism that could
  compute the name instead of writing it.

## Evidence boundary

Confidence is **Confirmed** for the zero-occurrence scan, the file set and
sizes, the near-miss explanations, and every structural figure in the comparison
above.

This bounds **naming**, not the native host's ability to construct a name at
runtime. Nothing here proves the engine could not be made to load the entry; it
establishes that nothing in the shipped product asks it to. The other seven
entries in the set are recorded with the same evidence but are not `EVENT`-named
and are not classified by this document.

## Reproduction

```powershell
py tools/audit_unreferenced_entries.py <ELFIMAGE-directory> `
  --exe <unpatched-AI5WIN.exe> `
  --check config/event_catalog/unreferenced_entries_v1.json
```

The tracked report is `config/event_catalog/unreferenced_entries_v1.json`, and
`tools/classify_event_routes.py` consumes it: an EVENT-named entry that the
naming audit leaves unnamed and this audit finds nowhere becomes
`unreachable_stored_route`, with the twin comparison as its reason. The audit
fails closed if the set of unnamed entries changes, if a declared duplicate
stops sharing its message identity, or if the tracked report does not reproduce.
It joins the headless batch whenever the original executable is supplied.

Report schema `kakyu_unreferenced_entries_audit/v2` (revised 2026-10-02, TD-36)
carries no machine-local fact: the executable is recorded under the fixed label
`<executable>` with its `executable_sha256` (the pinned unpatched original,
`ORIGINAL_EXECUTABLE_SHA256` in `tools/payload_values.py`; any other executable
is refused), and `AI5WIN.INI` - the only scanned file the game itself rewrites; the `.arc` files are read-only originals - is marked `mutable` with its occurrences scanned
but no size pin. The report was regenerated in place, as the other
`config/event_catalog/` reports are; all occurrence counts are unchanged.
