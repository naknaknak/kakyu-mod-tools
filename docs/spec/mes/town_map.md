# MES Analysis: Town Map

This document covers the source flow consumed by the remake town-map and
encounter resolver.

## Script Ownership

- `MACHI.MES` is the large town-level dispatcher. It combines date/time,
  location, presentation, and follow-up script decisions.
- `12C.MES` is the confirmed caller context for the current Edo-mae fish-shop
  Maki events.
- `D_PIC.MES` restores the Maki/location presentation around EVENTD08 and
  selects her character BGM.
- `EVENTD03.MES` and `EVENTD08.MES` own the event-local dialogue flow; their
  details are in [Character Events](character_events.md).

## MACHI Decoder Closure

**Confirmed structural result.** The earlier `MACHI.MES` IR covered 58,291 of
60,475 code bytes. Its remaining 2,184 bytes formed eight gaps, but they were
not eight independent unknown grammars. A trace stopped at the first byte that
used a native non-opcode dispatcher route, leaving the rest of that entry
region uncovered as a cascade.

The original interpreter dispatch and the authoritative `MACHI.MES` entry
identify twelve such route selectors. Ten are operand-free generic values; two
select the zero-terminated character-stream handler:

| Address-table region | Generic route | Character-lead route |
|---|---|---|
| entry 0 | `0x02E8=0x50`, `0x030B=0x7B`, `0x0AB7=0x50` | none |
| entry 25 | `0x203D=0xF1`, `0x203E=0x7F`, `0x2042=0xF1` | `0x2043=0x8F` |
| entry 29 | `0x22D2=0xF1`, `0x22D3=0x7F`, `0x22D7=0xF1` | `0x22D8=0x8F` |
| entry 179 | `0xA2CD=0x50` | none |

The selector values are not forwarded to the shared handlers, so `0x50`,
`0x7B`, `0x7F`, and `0xF1` have no per-value difference on this route. What is
confirmed is the interpreter boundary: generic values invoke the shared
operand-free handler, while the character selectors invoke the shared text
handler and own the following zero-terminated operand. With those boundaries
represented explicitly, `MACHI.MES` has 60,475 of 60,475 code bytes covered,
zero uncovered ranges, and zero decoder errors.

## Time-of-day Map Resources

**Confirmed.** The authoritative `MACHI.MES` entry selects the `MACHIN` map
atlas from `state_u16[19]`:

| Condition / command offset | Result |
|---:|---|
| `0x00F7` / `0x0105` | before 06:00, `MACHIN_3.DAT` |
| `0x0121` / `0x012F` | before 16:00, `MACHIN_1.DAT` |
| `0x014B` / `0x0159` | before 18:00, `MACHIN_2.DAT` |
| `0x0177` | 18:00 or later, `MACHIN_3.DAT` |
| `0x025E` / `0x0277` | paired fallback load of `MACHIN_3.DAT/.PAL` |

The vacation Saturday start at 19:00 therefore consumes the `_3` night atlas,
not `_2`. In `data.arc`, `MACHIN_3.DAT` is at `0x3DE391` and
`MACHIN_3.PAL` at `0x41CB91`. The PAL stores BGR triples; treating them as RGB
swaps the red and blue channels and produces a false night-looking `_2` image.
That channel-order statement is archive-format evidence from the paired asset,
while the time thresholds and resource names are direct MES evidence.

The 640x400 DAT plane is a **40x25 tile atlas**, not a display-ready world-map
frame. The authoritative `MACHI.MPC` entry (SHA-256
`a2d163613273aba294904f86977e72db645e96c1fdd4186b5760074d06b360b0`)
stores a 120x80 grid of three-byte packed cells. Bits `0..9` select the opaque
base tile; bits `10..19` select an index-zero-transparent overlay tile, with
`0x3ff` meaning no overlay. Native tile numbering starts at the atlas's bottom
row. Rebuilding those layers produces a 1920x1280 movement surface. The
authoritative `MACHI.CCD` entry (SHA-256
`af27d8a5c9142337813bf3c9a556ee9b471719b9079360f1b1df7e2d160d2707`)
stores entrance preset 4 at camera cell `(80,32)` and actor cell `(95,40)`.
`MACHI.EVE` event 4 covers `(95..96,40)` and the ordinary map dispatcher sends
that location to `18M.MES`; the decoded original `18M_3.MMO` is the night
children's park. EVENTB14 therefore uses the preset-4 40x25-cell crop and
places original `CHARA.DAT/PAL` frame 1 at pixel `(240,128)` for its final
world-map monologues. Original and edited effective inputs use deterministic
tile reconstruction directly from those ARC entries; an extracted or local
full-map PNG is not a runtime input. Evidence type:
direct authoritative MPC/CCD/EVE/DAT/PAL read, deterministic tile
reconstruction, decoded original location media, and user-confirmed native
presentation; confidence: **Confirmed** for layout, event/preset coordinates,
actor placement, and source identities, **Source-qualified projection** for
using that native camera frame at the EVENTB14 routine-21 boundary.

**EVENTB03 station terminal projection (corrected).** Station preset 16 begins
at `MACHI.CCD:0x0384` and stores camera cell `(45,14)` plus actor cell
`(60,22)`. `MACHI.EVE:0x00C0..0x00CC` returns event 16 for the trigger
`(60..61,22)`, facing mask 1. `MACHI.MES:0xACA2..0xACAC` checks that event
result, and `0xACB1..0xACBC` selects `01M.MES`. The map-start branch at
`0x056E..0x0578` checks `state_u16[16]==16`; its native initialization record
at `0x0578..0x0589` supplies `[6,1,16,0,1]`. The original native handler
`0x4211F0..0x421280` indexes `CCD header[2] + preset*4`, copies the camera and
actor pair, and clamps the camera to the map extent. This span has SHA-256
`d6d8b541e3fa12d3181fd1990911f37b790ce3d5bef4f7e13fdd88be3357fcbb`;
the original EVE scanner at `0x421A50..0x421AE8` was also reread directly.

The old preset-0 `(88,60)/(110,68)` values were valid bytes but their station
label was wrong. They associate with EVE 0 and the `44M.MES` dispatch, not the
station; the user's screenshot identified the resulting wrong location as
Rising Mansion. That mistaken location mapping and its artificial edge-wrap
policy are superseded. The corrected station crop is in bounds.
The exact result-3 terminal is
`EVENTB03.MES:0x3D46..0x3D53 -> MACHI.MES`; at the captured HHMM 18:25 it
therefore selects `MACHIN_3`. Event Player composes the original MPC/DAT/PAL
and `CHARA` entries rather than loading an extracted full-map PNG, placing the
actor at `(240,128)` in the 640x400 frame. Preset bytes, station mapping, archive
identities and terminal target are **Confirmed**. Using the entrance-preset
camera instead of resuming the native retained camera/input remains a
**Source-qualified projection**. No native movement resumption is claimed.

The deferred original-engine marker candidate is bound to those exact paired
entries. The checked source `data.arc` SHA-256 is
`b069c4dbb67d67eaf9252babc02f100fbc16c0740a189b007ff31535305727e4`;
`MACHIN_3.DAT` is 256,000 bytes with SHA-256
`3a4111f6ff91c477e41689cc2ba83a7e2cc1000744c2c9f9d68d560cdbd334e4`,
and `MACHIN_3.PAL` is 768 bytes with SHA-256
`f13d98d2a08f46cba1de3e79b3cfb943f6d08c9289afc2f0312899cf3553a07b`.
The headless preparer decoded the 640x400 pair, wrote a two-color repeating
tile marker, encoded and decoded it again, rebuilt and reopened a new archive,
and produced candidate archive SHA-256
`d93d615aa0146991603c640d928c7b2d0b528e5272f5592e20f3f3c3d5ebc581`.
The source archive remained unchanged. Executable ARC audit v3 separately
reconfirmed the hashed launcher's native `Data.arc` registration and streaming
route. Evidence type: direct authoritative MES/ARC read, Content Core codec and
writer reopen, and original-executable static audit; confidence: **Confirmed**
for target selection, source/candidate bytes, and native Data ARC reachability,
**Unresolved** for original-engine DAT/PAL decode acceptance until the isolated
visual batch is run.

## EVENTD03 Direct Caller Gate

**Confirmed direct caller gate.** `12C.MES` condition offset `2630` reaches
command `0x0F` at offset `3550` with target `eventd03.mes`. These conditions
are necessary for this immediate branch; they are not by themselves a proof of
the complete natural-occurrence schedule or sufficient caller state.

All of these raw-state conditions must be true:

- `400 < state_u16[7] < 616`;
- `40 < banked_u16[0][212] < 70`;
- `state_u16[7] != banked_u16[0][253]`;
- `global_u8[402] == 1`;
- `global_u8[220]`, `[224]`, `[225]`, `[751]`, `[778]`, and `[678]` are `0`;
- `global_u8[227] != 1`.

`banked_u16[0][212]` is confirmed as Maki affection. The numeric
`global_u8[402] == 1` gate is confirmed, while its friendly interpretation as
the protagonist knowing Maki's name remains a **Hypothesis** pending
a producer/consumer proof. `banked_u16[0][253]` and the other numeric flags
remain unresolved. The remake retains their numeric identities.

## EVENTD08 Availability

**Confirmed direct caller.** `12C.MES` condition offset `3735` reaches command
`0x0F` at offset `4006` with target `eventd08.mes`.

Its direct gate is:

- `700 < state_u16[7] < 916`;
- `banked_u16[0][212] > 70`;
- `global_u8[402] == 1`;
- `global_u8[220]`, `[224]`, `[225]`, `[756]`, `[778]`, and `[678]` are `0`;
- `global_u8[227] != 1`.

The caller does not require EVENTD03 completion. The earlier prototype-only
dependency was removed.

## Effective Schedule Context

The EVENTD08 caller expression contains no `state_u16[19]` HHMM reference, and
the decoded `12C.MES` contains no HHMM reference. Time availability therefore
comes from the outer location schedule rather than the direct event caller.

The currently confirmed effective context is:

- Saturday;
- Edo-mae fish shop;
- appearance begins at 12:30;
- a normal action consumes 15 minutes;
- pre-action times above 16:44 use the closed result;
- therefore 16:30 is the last regular grid start and arrives at 16:45.

This separation is important: the `12C` caller AST selects the relationship and
date window, while `MACHI` and the location schedule select whether the caller
can be reached at that time and place.

## Call and Restore Flow

The authoritative `12C.MES` bytecode contains this sequence around the
EVENTD08 dispatch:

1. dispatch `d_pic.mes`;
2. dispatch `eventd08.mes`;
3. dispatch `d_pic.mes` again;
4. continue with caller-owned follow-up dialogue.

The event projection records the EVENTD08 call at `4006`, presentation restore
at `4044`, and follow-up dispatch at `4066`. The restored presentation keeps
the Maki track rather than restarting it.

## Maki Standing Selection

**Confirmed numeric behavior.** A fresh 100-percent decode of the authoritative
`D_PIC.MES` entry (SHA-256
`72473432ce3dd6e0fc1e994a737dbecd5494eaf4477efc24368d3b3160d7fecd`)
shows the following resource selection:

| Condition offset | Condition | Resource marker offset | Resource |
|---:|---|---:|---|
| `0x00AF` | `global_u8[226] == 0` | `0x00CC` | `D.MMO` |
| `0x0155` | `global_u8[226] == 4` | `0x0172` | `D5.MMO` |
| `0x0217` | context 1/3 and `0400 < date < 0616` | `0x023C` | `D1.MMO` |
| `0x02C1` | context 1/3 and `0615 < date < 0916` | `0x02E6` | `D2.MMO` |
| `0x036B` | context 1/3 and `0915 < date < 1116` | `0x0390` | `D3.MMO` |
| `0x0415` | context 1/3 and `1115 < date < 1511` | `0x043A` | `D4.MMO` |

All six resource offsets use filename-bearing command `0x09` envelopes, not script-dispatch command
`0x0F`. Each uses the same constrained filename-slot byte shape documented in
[Format and Method](format_and_method.md). Content Core recognizes only that
exact safe `.MMO` marker and retains all other `0x09` forms as unresolved.
Direct strict reads through the shared MMO codec against the authoritative
`mmo.arc` confirm that all six referenced entries decode as `640x400` images.
Evidence type: direct authoritative `mes.arc` resource record plus referenced
`mmo.arc` entry decode plus the original executable's non-playback `0x09`
handler; confidence: **Confirmed** for bytes and dimensions, **High** for the
resolved presentation binding, while the native marker consumer and subsequent
compositing/draw command remain unresolved.

Event Player exposes these six offsets as `Confirmed` preview rows only when
the resolved `D_PIC.MES` SHA-256 is
`72473432ce3dd6e0fc1e994a737dbecd5494eaf4477efc24368d3b3160d7fecd`.
They are resource-inspection anchors, not claims that each offset is a complete
event intro or that centered placement reproduces the original composition.

Caller checks confirm that the selector is authored before presentation:

- `12C.MES:0x0348` writes `0`, then `0x035E` calls `D_PIC.MES` for the
  fish-shop flow.
- `01M.MES:0x6C3B` writes `1`, then `0x6C46` calls `D_PIC.MES` for a
  station-family seasonal presentation example.
- `21C.MES:0x7CB1` writes `4`, then `0x7CBC` calls `D_PIC.MES`; the paired
  local `21C` background is the indoor-pool scene and `D5` is the swimsuit
  standing resource.

The writes, call offsets, date comparisons, command IDs, constrained filename
records, and resource names are Confirmed.
Friendly context labels in the debug UI are presentation projections derived
from the paired local backgrounds; they are not new symbolic names for flag
226. Most importantly, the `12C` normal encounter does not select `D1` on
outro. The standing resource remains `D` until another authored presentation
selection occurs.

## Runtime Projection

- The fixed encounter destination references a priority-ordered event set.
- EVENTD03 and EVENTD08 each use their confirmed `12C` caller AST.
- Unknown condition types and invalid ASTs fail closed.
- Completion IDs prevent repeats, while the original numeric completion writes
  are preserved separately.
- A no-match result remains a normal town-map outcome rather than fabricating
  an encounter.

The integrated Saturday slice consumes this existing evidence by binding MACHI
EVE event ID 10 to the fish-shop event set and starting at CCD preset 10. It
does not introduce friendly mappings for the other MACHI EVE IDs. The slice
definition records the confirmed `12C.MES` condition offset `3735` and
`EVENTD08.MES` call offset `4006` as its intro anchor.

Related runtime documents:

- [Town Map Screen](../scenes/town_map_screen.md)
- [MES Condition Projection](../data/mes_condition_projection.md)
- [Event Definition Contract](../data/event_definition_contract.md)
