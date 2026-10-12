# Dispatch naming beyond the strict decode

Measured on 2026-09-09 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative. This document answers one question that the
Event Player corpus goal has to settle before it may call any stored entry
unreachable: **where in the archive is an entry named at all?**

[Event Corpus Inventory](event_corpus_inventory.md) partitions the 1,016 entries
into 587 literal dispatch targets and 429 entries "never named by a literal
dispatch record". That inventory is correct within its scope, and this document
does not withdraw any of its counts — all 10,474 of its rows reproduce here
byte for byte. What it corrects is the scope, which the inventory's own wording
did not carry: the partition is over the bytes the **strict aligned decoder
reads**, not over the archive.

**418 of those 429 entries are named by a byte-exact dispatch record after all.**
The records sit in the opaque tails that the strict decoder preserves rather
than reads.

## Why the strict decode has a blind spot

`content_core/mes_analysis_index.gd` decodes each address-table region linearly
and stops at the first byte it cannot frame, recording the remainder as an
`opaque_region_tail` with its exact bounds and hash. This is the fail-closed
behaviour the whole repository depends on, and it is not a defect. But it means
every byte after an opaque boundary is unread, and any instrument built on the
index inherits that horizon.

Measured over the archive:

| Strict decoder blind spot | Measured |
|---|---:|
| entries with at least one opaque tail | 496 of 1,016 |
| opaque regions | 1,180 |
| opaque bytes | 719,650 |
| share of the 18,079,488 bytecode bytes | 3.98% |

## The envelope scan

Both script-bearing commands frame a literal target identically:

```
00 | <0x0F|0x0E> 01 <archive entry name> 00 00
```

`cli/audit_mes_dispatch_naming.gd` scans the raw bytecode for that envelope with
the name required to be an entry the archive actually stores. It is a byte
scan, so no decoder horizon applies to it.

A byte scan is only worth as much as its agreement with the decoder where both
can see, so that agreement is a check rather than an assumption:

| Scanner versus strict decoder | Measured |
|---|---:|
| envelopes found archive-wide | 11,124 |
| strict decoder rows reproduced at the same offset and target | 10,474 of 10,474 |
| target disagreements | 0 |
| envelopes the decoder missed **inside a region it read** | 0 |
| envelopes the decoder missed inside an opaque tail | 650 |
| envelopes not preceded by the `0x00` statement separator | 0 |

The fourth row is the load-bearing one. The scanner finds nothing extra
anywhere the decoder actually looked; every one of its 650 additional records
lies inside a preserved opaque tail. Together with zero dangling targets across
1,005 distinct names, that is what separates these records from a misaligned
scan.

A second instrument agrees. `tools/classify_event_routes.py` re-decodes each of
the 650 tail records from the original caller bytes with Python
instruction-v45, requiring the command, target and exact end offset to match:
**650 of 650 decode cleanly**. The byte scanner, the GDScript strict decoder
(where it reaches) and the Python decoder are three independent readings of the
same records.

## What the opaque tails name

| Opaque-tail envelopes | Measured |
|---|---:|
| records | 650 (409 command-`0x0F`, 241 command-`0x0E`) |
| distinct callers | 62 |
| distinct targets | 466 |
| targets the strict decode already named | 48 |
| **targets the strict decode called never-dispatched** | **418** |

The heaviest callers are `GROUND.MES` (63), `44C_END.MES` (52) and the
per-character `*_M.MES` entries (31-36 each) — entries whose strict decode stops
early and leaves a long tail.

### EVENTA13.MES is dispatched

The inventory named `EVENTA13.MES` and `EVENTL09.MES` as "the strongest
`unreachable_stored_route` candidates in the archive". The first does not
survive measurement. `FLOOR4.MES:0x0E4C` carries a command-`0x0E` root handoff
naming it, framed exactly like every confirmed handoff and bracketed by the
entry's ordinary `1F` markers:

```
… ff 66 0e 00 00 | 1f b7 00 00 00 | 0e 01 "eventa13.mes" 00 00 | 1f b8 00 00 00 | 0c bf 0f 00 00 …
```

The audit binds that coordinate exactly rather than counting it.

`EVENTL09.MES` survives: it is named by nothing measured here, and is the only
`EVENT*.MES` entry in that position.

## The naming form that is not a dispatch record

Command `0x0D` subcommand `08` carries an inline script execution envelope,
`0D 08 FF 02 <selector> FF 01 <name> 00 00`, whose native semantics
`mes_presentation_ir.py` records as
`archive_entry_load_inline_execute_restore_confirmed`. Archive-wide there are
exactly two sites, both in `START.MES`:

| Site | Selector | Role | Names |
|---|---:|---|---|
| `START.MES:0x014C` | 2 | `library_bootstrap` | `LIBLARY.LIB` |
| `START.MES:0x0165` | 3 | `definition_bootstrap` | `DEF_MAIN.MES` |

The inventory cited `LIBLARY.LIB` and `DEF_MAIN.MES` as its example of
never-dispatched but known-reachable entries. This measures the mechanism that
makes them reachable instead of asserting it.

## The remaining partition

| After every naming form | Entries |
|---|---:|
| named by a dispatch envelope | 1,005 |
| named only by inline script execution | 2 (`LIBLARY.LIB`, `DEF_MAIN.MES`) |
| named by the native host | 1 (`START.MES`) |
| **named by nothing measured** | **8** |

The eight are `DATETIME.MES`, `EVENTL09.MES`, `FLAGINI.MES`, `FLAG_INC.MES`,
`M_TIME.MES`, `OMAKE.MES`, `SIZUKA44.MES` and `_TEST.MES`. `START.MES` is
counted as host-named on the existing executable evidence: the CAI5Doc
initializer loads the configured startup MES from `mes.arc`
(`audit_ai5_mes_exe.py`), the entry itself is bound by
`audit_mes_startup_bootstrap.py`, and the literal string `start.mes` appears in
`AI5WIN.original.exe` at file offset `0x954F0`.

## Command `0x0F` is still fully literal

The tolerant Python basic-block decoder reports 24 command-`0x0F` records with
expression operands rather than a name, which would be dynamic dispatch if they
were real. All 24 are preceded by byte `0x0D`: they are the operand tail of a
`0D 0F` presentation command, misaligned by one byte. The inventory's claim
that every command-`0x0F` record carries a literal target survives.

## What this does not establish

Being **named** by a record inside an opaque tail is not evidence that the
record executes. The tail is preserved precisely because its framing is not
proven, so a naming record there proves the archive dispatches the entry
somewhere, not that the dispatch is live. That is exactly the bound the corpus
goal needs — it forbids an unreachability claim — and nothing more:

- no entry is promoted to `playable_event`, `duplicate_route` or
  `unreachable_stored_route` by this audit;
- the 650 tail records are not qualified routes, and no guard, state or
  terminal is claimed for any of them;
- shared-routine and registered-definition entry, and native address-table row
  selection **within** an already-named entry, remain unqualified. Neither can
  name a different archive entry — the archive expresses cross-entry naming only
  through the three forms measured above — so neither can widen this partition,
  but which row of a named entry the host selects is still open; and
- natural scheduler eligibility is unchanged from
  [Station-to-EVENTB03 Decision](station_eventb03_decision.md).

## Evidence boundary

Confidence is **Confirmed** for the envelope partition, the decoder-agreement
control, the opaque-tail measurements, the two inline sites, the
`EVENTA13.MES` coordinate and the eight-entry remainder.

**Unresolved / unqualified**: whether any tail record executes; the semantic
class of every entry named only in a tail; whether the eight remaining entries
are unreachable, which needs the native host examined for a naming path this
audit does not model.

## The blind spot is closed (2026-09-13)

Core 0.316.0 frames command `0x0D` as one system call, and the 1,180 opaque
regions this document measured were the record lists of those calls read as
pseudo-commands. Under that framing the strict decoder reaches all 11,124
envelopes the byte scan finds (9,875 command `0x0F`, 1,249 command `0x0E`): the
scan reproduces every strict row, no envelope sits past the decoder, and the
418 entries this document promoted from "never named" are strict dispatch
targets now, `EVENTA13.MES` at `FLOOR4.MES:0x0E4C` among them. What the scan
established stands - the two partitions were always over the same bytes - and
it stays in the batch as the decoder's independent cross-check. The remaining
partition is unchanged: 11 entries no envelope names, of which the two inline
script executions and the host-named `START.MES` account for three, leaving
the same eight entries no archive naming form reaches. The tracked report
`config/event_catalog/dispatch_naming_v1.json` was regenerated with an empty
opaque-tail list and a new `gallery_envelopes` list, the 365 strict rows that
name the replay gallery, which `tools/audit_duplicate_entries.py` reads in
place of the tail rows.

## Reproduction

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/audit_mes_dispatch_naming.gd -- `
  <ELFIMAGE-directory> [out.json]
```

The authoritative run passes **33 checks** with zero failures. Every expected
count is a fail-closed constant. The printed `report_sha256` covers
`content_core_version` and so moves on every Core bump; it was
`4a4d3f8069dfb315a337798026cbb4132516e7b2d6226b5e5806110d4b2c90cc` at Core
0.312.0, when the tracked report below was produced. The audit's own
comparison does not use it.

The report is tracked as `config/event_catalog/dispatch_naming_v1.json`, because
[Caller-derived route classification](event_route_classification.md) consumes
its tail and inline rows as intro evidence. The audit's last check compares the
tracked file against the run, ignoring `content_core_version` and the
fingerprint over it — the staleness this document records at the end for the
inventory's own hash is designed out of this comparison rather than repeated.

Seven mutations were run to confirm the checks are not vacuous:

| Mutation | Result |
|---|---|
| move the bound `EVENTA13.MES` offset by one byte | 1 failure |
| treat no region as an opaque tail | 9 failures, including the decoder-agreement control |
| accept any ASCII name instead of an archive entry | 13 failures |
| expect a separator other than `0x00` | 1 failure |
| cap entry names at 9 bytes | 18 failures, including the decoder-agreement control |
| change one count in the tracked report | 1 failure |
| require one trailing `0x00` instead of two | **no failure** |

The last is a measurement, not a gap: every
`<0x0F|0x0E> 01 <archive name> 00` in the archive is followed by a second
`0x00`, so the second byte is redundant given the name constraint. Relaxing the
inline selector from `{2, 3}` to any value likewise changes nothing, because no
other selector occurs in that envelope shape.

## Note on the inventory's recorded fingerprint

[Event Corpus Inventory](event_corpus_inventory.md) records report SHA256
`5b3a041f283a…`, which does not reproduce at HEAD. The report is unchanged: its
fingerprint covers `content_core_version`, and substituting the Core version
that was current when the document was written, `0.282.0`, reproduces
`5b3a041f283a…` exactly from today's run. Both inventory report fingerprints
therefore move on every Core bump regardless of whether the archive or the
decode changed.
