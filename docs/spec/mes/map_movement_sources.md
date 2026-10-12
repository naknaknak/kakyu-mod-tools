# MES Analysis: Map Movement Sources

This document records the original map-movement data used by the town, train,
school grounds, and school-floor maps. The findings were checked against the configured
authoritative `data.arc` and `mes.arc` entries and against the embedded payload
of the original `AI5WIN.exe`.

The checked `data.arc` SHA-256 is
`b069c4dbb67d67eaf9252babc02f100fbc16c0740a189b007ff31535305727e4`;
the checked `mes.arc` SHA-256 is
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All statements labeled as roles, record contracts, offsets, or counts below are
**Confirmed**. The friendly interpretation of a numeric event ID remains
unresolved until its owning MES branch is traced.

## Confirmed Source Split

The original does not use one authored road graph. Four source layers have
separate jobs:

| Source | Confirmed role |
|---|---|
| `*.MPC` | map width/height and three-byte cells; bit `0x80` of cell byte 2 is the static movement-collision flag |
| `*.EVE` | 12-byte entrance/event trigger records, terminated by event ID `0xFFFF` |
| `*.CCD` | actor control records, movement programs, four-byte entrance presets, and sprite data |
| map `*.MES` | loads the three resources, starts map control, dispatches the returned entrance/event ID, and selects the next map or location script |

`CCD` entrance presets are not collision rectangles. Each four-byte preset is
`(camera_x, camera_y, actor_x, actor_y)`. `EVE` trigger geometry is also not a
walkability mask. Static walkability comes from `MPC`.

## Native Runtime Evidence

The embedded executable payload has SHA-256
`5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da`.
The following virtual addresses establish the format and behavior:

- `0x00421110..0x0042116A` reads the two `MPC` header words as map width and
  height. It configures a 40-by-25-cell view.
- `0x00421797..0x004217A0` shifts camera cell coordinates left by four before
  drawing. One map cell is therefore 16 logical pixels, and 40 by 25 cells is
  the 640-by-400 gameplay viewport.
- `0x00421324..0x00421359` reads each three-byte `MPC` cell as one packed
  24-bit value. Bits 0--9 select the base tile, bits 10--19 select the overlay
  tile, and the high four bits contain flags. Overlay tile `0x3FF` means none.
- `0x00420B8C..0x00420BFD` builds two 1,000-entry tile-pointer tables as 40
  columns by 25 rows of 16-by-16 tiles. Its row order starts at DAT byte offset
  `0x3E580` and steps upward by `0x2800`, establishing the bottom-first atlas
  enumeration used by the renderer.
- `0x00421780..0x0042180A` renders the 40-by-25-cell camera and calls the
  two-layer tile routine at `0x004234F0`. The second layer treats palette index
  zero as transparent.
- The four directional movement handlers test `MPC` cell byte 2 with mask
  `0x80`: up at `0x00421FB6`, down at `0x004220E6`, left at `0x00422238`, and
  right at `0x00422396`. A set bit takes the collision/adjustment path.
- `0x004211F0..0x00421280` selects `CCD header[2] + preset_index * 4`, copies
  bytes 0/1 to the camera origin, copies bytes 2/3 to the primary actor
  position, and applies the requested facing.
- `0x00421A50..0x00421AE8` scans 12-byte `EVE` records until ID `0xFFFF`.
  It tests the actor's foot region against record words 1--4, tests the current
  facing against word 5, and returns word 0 as the event ID.

For the 120-by-80 `MACHI` grid this establishes a 1920-by-1280 logical world
viewed through a 640-by-400 window. `SMP1` is a separate overview image; it is
not a linearly scaled rendering of that world. The source-aligned movement
background must instead be assembled from `MACHI.MPC` and the selected
`MACHI{N,P,T}_{1,2,3}.DAT/.PAL` tile atlas. A visual comparison with the supplied
original-game capture aligns its client-area map crop to native camera cell
`(80,55)`; this is supporting presentation evidence, while the packed format
and scale above come from the executable and archive entries.

The primary actor control record begins at `CCD:0x0008` on all eight maps. Its
collision width and height are both two cells. For this 2-by-2 actor, the
movement handlers test the two-cell foot row: horizontal movement tests rows
`actor_y + 1` through `actor_y + height - 1`, while vertical movement tests the
new leading foot row. The actor control footprint spans 32 by 32 logical
pixels, but entrance overlap is evaluated at the feet.

The MACHI primary control record uses sprite index 0. The source `data.arc`
also contains the shared `CHARA.DAT` map-actor strip at `0x0AA654` (20,480
bytes, SHA-256
`7f3e0e25322ffea1755a02b23505644c0e3b7d224cfa2c7c013dc132c17a4e54`)
and its palette at `0x0AF654` (SHA-256
`02bc805c2f97fdc344ced8daf99ca999b90f3840121881a2a19b6a976e643bc0`).
It is a bottom-up 640-by-32 indexed strip whose first twelve 32-by-32 cells are
the four three-frame directions. Palette index zero is transparent. The remake
projects this strip as the protagonist presentation for primary sprite index 0;
the record geometry and source bytes are Confirmed, while the friendly
“protagonist” label is a Projected role supported by the primary-record use and
the visible character art.

## EVE Record Contract

Each `EVE` record is six little-endian words:

| Offset | Meaning |
|---:|---|
| `+0x00` | event ID returned to the map script |
| `+0x02` | trigger minimum X cell |
| `+0x04` | trigger minimum Y cell |
| `+0x06` | trigger maximum X cell |
| `+0x08` | trigger maximum Y cell |
| `+0x0A` | allowed-facing bit mask |

The bounds are inclusive. Native overlap uses the actor X span and foot Y span.
The final word is not an event-kind enum: the engine computes
`1 << (actor_direction_state >> 2)` and requires that bit in the record mask.

## Map Corpus

The exact clear-cell spans, primary-actor anchor spans, events, and entrance
presets are reproducibly exported by `tools/inspect_map_sources.py` to the
Git-ignored `analysis/map_source_audit_v2.json`. Bounds below are inclusive cell
coordinates and are only envelopes; holes inside them remain blocked according
to the exported row spans.

The same audit can render an eight-map collision overview to Git-ignored
`analysis/map_source_audit_v2_masks/map_collision_overview.png`:
light cells have a clear `MPC` collision bit, dark cells have `0x80` set, red
outlines are `EVE` trigger bounds, and cyan outlines are `CCD` actor entrance
presets. The PNG is a local audit projection, not a replacement source asset.

| Map | `MPC` grid / logical world | clear / blocked cells | 2x2 clear-foot anchors (entry component) | entry-component bounds | `EVE` records | `CCD` entrance presets |
|---|---|---:|---:|---|---:|---:|
| `MACHI` | 120x80 / 1920x1280 | 7,177 / 2,423 | 6,263 (4,254) | `(1,0)..(117,78)` | 43 | 43 |
| `TRAIN` | 120x80 / 1920x1280 | 7,271 / 2,329 | 6,372 (238) | `(0,18)..(118,19)` | 2 | 1 |
| `GROUND` | 40x35 / 640x560 | 666 / 734 | 620 (620) | `(2,0)..(36,29)` | 6 | 6 |
| `FLOOR1` | 85x25 / 1360x400 | 813 / 1,312 | 753 (745) | `(1,0)..(82,22)` | 10 | 8 |
| `FLOOR2` | 85x25 / 1360x400 | 845 / 1,280 | 796 (796) | `(1,0)..(82,17)` | 10 | 7 |
| `FLOOR3` | 85x25 / 1360x400 | 851 / 1,274 | 801 (797) | `(1,0)..(82,17)` | 10 | 7 |
| `FLOOR4` | 85x25 / 1360x400 | 839 / 1,286 | 791 (791) | `(1,0)..(82,17)` | 10 | 7 |
| `FLOOR5` | 85x25 / 1360x400 | 835 / 1,290 | 788 (788) | `(1,0)..(82,17)` | 10 | 8 |

The parenthesized count and bounds identify the entrance-bearing component,
not necessarily the largest clear component. `TRAIN` reuses a large grid but
places its only entrance preset in the isolated two-row train strip. Several
`GROUND` presets deliberately begin on boundary positions just outside the
ordinary clear-foot anchor set. They enter the same single walkable component
on the first inward movement. Other disconnected clear regions in `MACHI`,
`TRAIN`, `FLOOR1`, and `FLOOR3` contain no entrance preset and must not be
joined to the player component by an authored shortcut.

## Data-Entry Offsets

All offsets in this table are relative to the named `data.arc` entry.

| Map | `CCD` section offsets | entrance-preset range | `EVE` record range / terminator |
|---|---|---|---|
| `MACHI` | `0008,028D,0344,03F0` | `0x0344..0x03EF` (43) | `0x0000..0x0203` / `0x0204` |
| `TRAIN` | `0008,01C9,01F7,01FB` | `0x01F7..0x01FA` (1) | `0x0000..0x0017` / `0x0018` |
| `GROUND` | `0008,0017,001B,0033` | `0x001B..0x0032` (6) | `0x0000..0x0047` / `0x0048` |
| `FLOOR1` | `0008,0017,001B,003B` | `0x001B..0x003A` (8) | `0x0000..0x0077` / `0x0078` |
| `FLOOR2` | `0008,0017,001B,0037` | `0x001B..0x0036` (7) | `0x0000..0x0077` / `0x0078` |
| `FLOOR3` | `0008,0017,001B,0037` | `0x001B..0x0036` (7) | `0x0000..0x0077` / `0x0078` |
| `FLOOR4` | `0008,0017,001B,0037` | `0x001B..0x0036` (7) | `0x0000..0x0077` / `0x0078` |
| `FLOOR5` | `0008,0017,001B,003B` | `0x001B..0x003A` (8) | `0x0000..0x0077` / `0x0078` |

The `CCD` header is four little-endian section offsets. Section 0 contains
14-byte actor control records plus an `0xFF` terminator, section 1 contains
movement-program data, section 2 contains the entrance presets above, and
section 3 contains sprite data.

## MES Load and Transition Chain

The following code-relative offsets are direct resource or script operations in
the authoritative `mes.arc` entries:

| Owner | Evidence |
|---|---|
| `MACHI.MES` | loads `machi.mpc` at `0x028F`, `machi.ccd` at `0x02A6`, and `machi.eve` at `0x0AC0`; loads `ground.mpc/ccd` at `0xA28E/0xA2A6` and dispatches `ground.mes` at `0xA2DA` |
| `TRAIN.MES` | loads `train.mpc` at `0x01FB`, `train.ccd` at `0x0212`, and `train.eve` at `0x02E7`; restores `machi.mpc/ccd/eve` at `0x052F/0x0546/0x0742` before returning |
| `GROUND.MES` | loads `ground.eve` at `0x0282`; loads `floor1.mpc/ccd` at `0x1039B/0x103B3` and dispatches `floor1.mes` at `0x103E7` |
| `FLOOR1.MES` | loads `floor1.eve` at `0x0226`; transitions to `MACHI` at `0x0A12/0x0A29/0x0A62`, `GROUND` at `0x0E7F/0x0E97/0x0EEE`, and `FLOOR2` at `0x17AA/0x17C2/0x1841` |
| `FLOOR2.MES` | loads `floor2.eve` at `0x0206`; transitions to `MACHI` at `0x081A/0x0831/0x0875`, `FLOOR1` at `0x0B4C/0x0B64/0x0BC0`, and `FLOOR3` at `0x0D08/0x0D20/0x0D7C` |
| `FLOOR3.MES` | loads `floor3.eve` at `0x0206`; transitions to `MACHI`, `FLOOR2`, and `FLOOR4` at the same three offset groups as `FLOOR2` |
| `FLOOR4.MES` | loads `floor4.eve` at `0x0206`; transitions to `MACHI`, `FLOOR3`, and `FLOOR5` at the same three offset groups as `FLOOR2` |
| `FLOOR5.MES` | loads `floor5.eve` at `0x0235`; transitions to `MACHI` at `0x0890/0x08A7/0x08EB` and `FLOOR4` at `0x127A/0x1292/0x12EE` |

In each three-offset transition group, the first two operations load the target
`MPC` and `CCD`; the third dispatches the target map script. This establishes
the original topology `MACHI <-> GROUND <-> FLOOR1 <-> FLOOR2 <-> FLOOR3 <->
FLOOR4 <-> FLOOR5`, while floors may also return directly to `MACHI`.

`TRAIN.MES` is a special event sub-map rather than another node in the school
chain. It is directly called by `DENSHA.MES:0x00AA`,
`EVENTH07.MES:0x0122`, and `EVENTM06.MES`/`EVENTM09.MES:0x00FF`.

The fresh MES decodes are complete for `MACHI`, `TRAIN`, `GROUND`, the four
confirmed `TRAIN` callers, and `FLOOR1` through `FLOOR4`. `FLOOR5` decodes
10,113 of 10,126 code bytes; its resource loads and
the transition ranges cited here are decoded, while the unrelated 13-byte
boundary remains unresolved.

## Remake Boundary

- Import `MPC` cells and derive navigation from the confirmed collision bit.
- Preserve original cell coordinates and convert to the 640-by-400 logical
  space with a factor of 16 only at presentation/input boundaries.
- Import `EVE` trigger records separately from `CCD` camera/actor presets.
- Resolve the returned event ID through the owning MES path before assigning a
  friendly destination name or behavior.
- A generated navigation graph may optimize pathfinding, but it must be derived
  from the collision mask. Manual road nodes and manual entrance picks are
  remake-only fallback data and are not original-source evidence.

The mask is the confirmed static range. Script-controlled actor state and map
transitions can still restrict what is reachable at a particular moment; the
static mask alone must not be used to invent a schedule or event branch.
