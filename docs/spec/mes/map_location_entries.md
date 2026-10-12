# MES Analysis: Map Location Entries

This document records the owning-MES dispatch used when an `EVE` trigger
returns a numeric location ID. It covers every source movement map consumed by
the location-entry prototype. Original dialogue remains only in the ignored
runtime projection and is not reproduced here.

## Confirmed Dispatch Contract

The paired `EVE` record returns a numeric ID. The owning map MES compares that
value as `state_u16[21]`, often together with date, weekday, time, and numeric
flags. Command `0x0b` enters the inline body when the complete expression is
exactly `1`; otherwise it jumps to the next location/schedule branch.

`tools/export_map_location_entries.py` preserves, in source order:

- the complete condition AST and expression bytes;
- condition, true-body start, and false-target offsets;
- inline CP932 text records with per-record hashes;
- called MES filenames and call offsets, plus map-dispatch target records;
- inline duration operands and their code-relative offsets;
- the normal interior-location transfer selected by a map-dispatch target;
- every numeric location ID present in the paired `EVE` map.

The generated `data/mes_location_entries/all_maps.json` and lazy
`scenes/*.json` companions are local-only. Runtime selection executes their
ASTs against `LegacyState`; it does not substitute a friendly schedule or
event rule.

## Authoritative Map Inventory

All entries below were read directly from the configured `ELFIMAGE/mes.arc`.
Offsets are code-relative condition offsets. The location counts are the unique
numeric IDs exposed by the paired authoritative `EVE` entries.

| Map MES | Archive entry offset | SHA-256 | First location condition | IDs |
|---|---:|---|---:|---:|
| `MACHI.MES` | `0xED45E5` | `56b0f4243f3c0944624ea0ef11b369391761ff394816775264c144bb76391488` | `0x51E5` | 43 |
| `TRAIN.MES` | `0x11F860B` | `1bb4331668682679732a105027372ab013364739c7a324e6ba977fba4ceb6df9` | `0x039A` | 2 |
| `GROUND.MES` | `0x93C6E1` | `b5dd1b444d1dbb4327e46a853e881c5ff46890a0b01b7ed7e9b92f2fdbc8b282` | `0x179C` | 6 |
| `FLOOR1.MES` | `0x82808E` | `eabe989ba47913ec285e842086f343e2ab37f75155c2e024ae16a9861078b3cb` | `0x0D66` | 8 |
| `FLOOR2.MES` | `0x82BE5E` | `501f85fb00aff2ddcbcc018b475b5a75fb5bd25ebf86af353f987627bdec6f8c` | `0x0A1C` | 7 |
| `FLOOR3.MES` | `0x82F62F` | `83228dc94e3901d99fb5abb7135d575132f4a6588173a0a835371bb5efe9815e` | `0x0A1C` | 7 |
| `FLOOR4.MES` | `0x832E0A` | `306a9b01cfa4151fdb8835f11595e9046a5e7b0aacbbd19a18f87a7db4409be3` | `0x0A1C` | 7 |
| `FLOOR5.MES` | `0x836ABE` | `d460ef7a3e58bb4f59b9a2da91afb1887eaef4ecb3c76c6c5c3d5231852fd15a` | `0x0A92` | 8 |

The prototype therefore exposes 88 numeric locations and 230 ordered MES
branches. This is a numeric source inventory, not a claim that every ID has a
confirmed friendly place name.

Forty-seven distinct normal interior-location MES entries are reached by the
map-dispatch target records. Each has at least one matching original MMO
background family in `mmo.arc`. Movement-map transfers and the `TIME_C` helper
remain map/system transitions rather than being mislabeled as interiors.

## Called Location Intro Playback

For a normal branch with no inline map text, runtime starts at the called
location MES bootstrap coordinate and follows valid `0x0B` conditions and
confirmed `0x0C` continuation targets. It preserves selected CP932 records and
stops at the first called or transferred MES. This boundary shows the place introduction without executing a
character encounter or fixed event as an entrance message.

The fish-shop path is the audited reference case:

| Role | Authoritative coordinate |
|---|---:|
| MACHI normal EVE 10 condition | `MACHI.MES:0x863F` |
| Target record | `MACHI.MES:0x864E` -> `12C.MES` |
| Called intro anchor | `12C.MES:0x0000` |
| First two source text records | `12C.MES:0x021F`, `0x0234` |
| Following named-speaker record | `12C.MES:0x0306` |
| Supported boundary | `12C.MES:0x035E` -> `D_PIC.MES` |

`12C.MES` was read at archive offset `0x0F4025`, has SHA-256
`c71563238cd4e14a06125b8cd139f7e6a304024dbd7c32ed5a3619ca425726eb`,
and decodes with complete byte coverage and no missing actionable target. The
coordinates, called entry, and text records are **Confirmed**. Skipping a
backward bootstrap initializer loop without replaying its state writes is a
**Projected** presentation-only rule; runtime does not mutate persistent state
while showing an entrance intro.

## Location Background Selection

The called location basename identifies its original `mmo.arc` family. For
example, the confirmed fish-shop family is:

| MMO entry | Archive offset |
|---|---:|
| `12C_1.MMO` | `0x17312F6` |
| `12C_2.MMO` | `0x1773036` |
| `12C_3.MMO` | `0x17B7D67` |

The same inventory rule finds the `44M` dormitory exterior/front family
reached by `MACHI.MES` location ID zero:

| MMO entry | Archive offset |
|---|---:|
| `44M_1.MMO` | `0x422AA3B` |
| `44M_2.MMO` | `0x4264D4F` |
| `44M_3.MMO` | `0x429FEB2` |

The location-zero dispatch and `44M.MES` handoff at `MACHI.MES:0x52EE` are
confirmed MES evidence. The filename family exists in the authoritative
`mmo.arc`; applying the numbered time variant remains the projection described
below. Direct decode of authoritative `44M_3.MMO` shows the nighttime exterior
and front gate. Evidence type: original ARC decode plus MES dispatch;
confidence: **Confirmed** for the pixels and dispatch, **Descriptive** for the
friendly dormitory-front label.

`TIME_C.MES` supplies the directly observed time dispatch used for source
palette families:

| HHMM range | Variant | Code-relative evidence |
|---|---:|---:|
| before `0600` | `3` | condition `0x02BD` |
| `0600` through `1559` | `1` | condition `0x0300` |
| `1600` through `1759` | `2` | condition `0x0343` |
| `1800` onward | `3` | fallback `0x0386` |

The `TIME_C` comparisons and `machine_1/2/3` resource dispatch are
**Confirmed**. Applying the same numeric suffix to a called location's matched
MMO family is **Projected** and retained as such in runtime evidence. Families
with `M`, `S`, and `A` population variants use the spring, summer, and
autumn/winter presentation projection. Original filenames and archive offsets
are confirmed; friendly seasonal labels remain projected. Missing image tiers
show a visible placeholder without blocking dialogue or time advancement.

The EVENTB03 station route is now a source-confirmed exception to that generic
filename projection: `01M.MES:0x01D1..0x01E3` and
`EVENTB03.MES:0x3715..0x3727` both call shared routine 27 with selector 11.
For MMDD 413 / HHMM 1825, the numeric branches reach
`LIBLARY.LIB:0x3CC2..0x3CD1`, loading `01MA_3.MMO`, then copy surface 2 to
surface 1 at `0x3CD8..0x3CFB`. The earlier provisional `01MM_3.MMO` choice is
superseded. See [Character Events](character_events.md) for the exact
date/time branches and native checks; this does not promote other families'
friendly seasonal labels or their full restoration lifetime.

Core 0.277.0 separates the selector-11 selection into a read-only
[station background plan](station_background_selection.md). It follows the
original numeric date/time guards across all three resource families, retains
the explicit mode-1 surface-2-to-1 copy, and stops before executing routine 8.
The existing EVENTB03 consumer still accepts only date 413 / time 1825; the
additional plans are not broader event-start or native-pixel qualification.

## Location Time Cost

The map dispatch bodies repeatedly pair the same duration operand with entry
results. The runtime projection retains the inline operand when present and
uses the owning map's recurring value for a normal target-dispatch branch whose
called interior script owns the detailed flow.

| Owning map | Projected entry cost | Representative duration operand |
|---|---:|---:|
| `MACHI.MES` | 15 minutes | fish-shop late branch `0x84A2` (condition `0x8487`) |
| `TRAIN.MES` | 0 minutes | no matching duration operand in either location branch |
| `GROUND.MES` | 10 minutes | `0x17DC` (condition `0x179C`) |
| `FLOOR1.MES` | 10 minutes | `0x0F86` (condition `0x0F4E`) |
| `FLOOR2.MES` | 10 minutes | `0x0A30` (condition `0x0A1C`) |
| `FLOOR3.MES` | 10 minutes | `0x0A30` (condition `0x0A1C`) |
| `FLOOR4.MES` | 10 minutes | `0x0A30` (condition `0x0A1C`) |
| `FLOOR5.MES` | 10 minutes | `0x0AB2` (condition `0x0A92`) |

The operand-to-minutes role is the runtime projection already used by the
confirmed 15-minute town action grid. `command 0x04` itself remains numerically
named because its complete engine-wide semantic role is not yet proven. A map
default is therefore **Projected**, while the operand value and offset are
**Confirmed** archive evidence.

## Entrance Choice Audit

`MACHI.MES` EVE 6 dispatches to `41M.MES` from condition `0x632C`. In the
authoritative `41M.MES`, two action labels are associated with `command_10` at
`0x0EDB` and `0x0EFA`; the following control flow tests choice result
`state_u16[21] == 1` at `0x0F4B` and result `2` at `0x0FB9`. The actions are a
request interaction and leaving for another place. The scene returns to
`MACHI.MES` through the transfer at `0x103C`.

The archive entry starts at `mes.arc` offset `0x1E134C` and has SHA-256
`517ad8fba1258b9617dcc9aefb6f5890694248546cbb6075bd9c5f3439345780`.
The dispatch, instruction coordinates, label association, and result branches
are **Confirmed**. The complete native semantics of `command_10` remain
**Unresolved**, so this evidence identifies the observed choice construction
without redefining the opcode globally.

The entrance projection preserves a recognized `command_10` whose structured
operand is a non-negative literal index and whose next source record is its
label. Runtime exposes consecutive recognized records as buttons, writes the
projected one-based result to `state_u16[21]`, and resumes the same scene at the
first instruction after that choice group. Conditions, jumps, dialogue, and
the return transfer then remain in original control-flow order. For the
audited EVE 6 case, selecting result 2 resumes at the branch record beginning
at `0x0FD3` and reaches the `0x103C` return.

This support is **Projected** from the confirmed zero-based operand/result
relationship in this scene. Records without that recognized literal/label
shape remain excluded, and the complete native semantics of `command_10`
remain unresolved. The runtime projection does not claim that every use of
the opcode is a choice insertion.

## Runtime Boundary

Location entry and event occurrence are separate layers:

1. collision/facing selects an `EVE` record;
2. the map writes its numeric ID to `state_u16[21]`;
3. `MesLocationEntryResolver` selects the first true owning-MES branch;
4. inline map messages stay over the movement map; a normal interior transfer
   selects its original location background and follows the called MES intro;
5. a recognized entrance choice pauses playback, records its result, and
   resumes the same called location MES;
6. called-location playback stops before its first event/character call;
7. after playback, the projected map cost advances the clock;
8. an independently authored event binding runs instead when present, using
   that cost as its fallback while an event with its own time effect retains
   ownership.

A missing or ineligible event cannot make the entrance disappear. Conversely,
the location projection does not make an unconfirmed event eligible.

The standalone source-map prototype exposes `MACHI`, `TRAIN`, `GROUND`, and
`FLOOR1` through `FLOOR5`, plus a selector that can replay every numeric entry
branch. Free movement still uses the original `MPC` collision and `EVE` facing
records.

## Unresolved Boundary

`MACHI`, `TRAIN`, `GROUND`, and `FLOOR1` through `FLOOR4` have full production-IR
byte coverage. `FLOOR5.MES` covers 10,113 of 10,126 code bytes (99.87%); the
remaining 13 bytes have no missing executable branch target or decoder error.
The eight `FLOOR5` location IDs and their projected branches are decoded, but
the unhandled bytes remain explicitly unresolved.

Called interior MES bootstrap and intro control flow is interpreted only to the
documented first-call/transfer boundary. Recognized choices owned directly by
that path can pause and resume it, but called character scripts, called event
choices, and completion scripts are not recursively executed by this entrance
layer. If no source text or recognized choice is reached before that boundary,
runtime keeps the exact source coordinate instead of inventing dialogue. Its
time cost still uses the owning-map recurring projection and is labeled as such
in runtime data.
