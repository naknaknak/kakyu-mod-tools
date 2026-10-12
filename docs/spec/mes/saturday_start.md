# Saturday Start Routing

This document records the original-source anchors used to choose the first
free-action map for the Saturday slice. The configured raw `mes.arc` entries
were decoded again for this check; generated IR was used only to inspect the
authoritative bytes.

## Term Saturday

`27C_EV.MES` owns the school-day Saturday handoff:

| Evidence | Code-relative offset | Finding | Confidence |
|---|---:|---|---|
| weekday condition | `0x13EE4` | `state_u16[4] == 6` selects the Saturday continuation | Confirmed |
| time write | `0x13EF8` | `state_u16[19]` is written as `1230` | Confirmed |
| intro entry | `0x14198` | address-table entry for the Saturday-after-school presentation | Confirmed |
| entrance write | `0x144C9` | `state_u16[16]` is written as `5` | Confirmed |
| script dispatch | `0x144CE` | dispatches `floor5.mes` | Confirmed |

`FLOOR5.MES` tests `state_u16[16] == 5` at `0x01E3` and selects entrance
record 5 at `0x01ED`. The paired `FLOOR5.CCD` projection identifies preset 5
as camera cell `(33, 0)` and actor cell `(47, 10)`. The remake therefore starts
a term Saturday at 12:30 on `FLOOR5`, CCD preset 5.

## Vacation Saturday

`11C_EV.MES` owns the vacation part-time-work route. Its summer branches test
`720 < state_u16[7] < 900` at `0x2FAE`, `0x344C`, `0x3605`, and `0x3725`.
The corresponding winter branches begin at `0x3E28`, `0x4181`, `0x4395`, and
`0x44DF`. The shared library also repeats the school-closed ranges as
`720 < date < 900` and `1220 < date < 1308`, including at `LIBLARY.LIB`
`0xE10D`. With the original date encoding, those bounds resolve to 7/21--8/31
and 12/21--1/7.

| Evidence | Code-relative offset | Finding | Confidence |
|---|---:|---|---|
| vacation work start | `0x2F7F` | summer route writes the morning start time as `0800` | Confirmed |
| work-completion time guard | `0x49EE` | the completion path explicitly tests `state_u16[19] != 1900` | Confirmed |
| Saturday condition | `0x58AA` | `state_u16[4] == 6` selects the weekly work-completion branch | Confirmed |
| intro entry | `0x59C7` | address-table entry for the Dogeza master completion presentation | Confirmed |
| entrance write | `0x5DC1` | `state_u16[16]` is written as `1` | Confirmed |
| script dispatch | `0x5DCB` | dispatches `machi.mes` | Confirmed |

`MACHI.MES` tests entrance selector 1 at `0x038E`. Its location dispatch proves
that legacy location 1 is Cafe Dogeza: the `state_u16[21] == 1` New Year's Day
branch begins at `0x5303` and reaches the Dogeza-specific closed-day result at
`0x53FE`; the same location's normal opening-hour branches follow. The paired
`MACHI.CCD` projection places preset 1 at camera cell `(42, 18)` and actor cell
`(57, 27)`.

The slice enters free action at 19:00 for this route. The authoritative path
confirms the 08:00 work start, the explicit 19:00 completion guard, and the
Dogeza-to-MACHI handoff. The high-level meaning of every shared routine inside
the work interval remains unresolved and is not emulated as dialogue or work
gameplay.

## Runtime Projection

Projecting the handoffs above into start profiles is mod-player work, so the
projection lives with the player rather than here — this document owns the
source evidence it is derived from. The projection recorded before the split
selected between two profiles:

- `vacation_dogeza` for 7/21--8/31 and 12/21--1/7, using MACHI preset 1;
- `school_floor5` otherwise, using FLOOR5 preset 5.

That 8/1 slice therefore starts at 19:00 outside Cafe Dogeza. Spring
opening-week routing is not covered by this projection. Its owning path and any
opening-completion predicate remain **Unresolved**; the repeated summer/winter
vacation path checked here does not prove either one.
