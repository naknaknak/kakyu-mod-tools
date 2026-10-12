# MES Analysis: Room and Dormitory Corridor

This document records the original protagonist-room and dormitory-corridor
round trip without reproducing its dialogue or menu text.

## Confirmed 43C/44C Round Trip

The configured authoritative `mes.arc` has SHA-256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
The checked entries are:

- `43C.MES`, 42,678 bytes, SHA-256
  `446259e1c34b15de0dbab97c815d83b654fbeb7cca5cd29d4e2498a86706391b`;
- `44C.MES`, 69,719 bytes, SHA-256
  `49b5ae569923d6b0e58bf6bf64786f2e96fe9de00c9bad56cd450cb4a487d0ce`.

An operator-observed original-engine sequence on July 27 (Saturday) fixes the
following route:

1. At 20:15, `43C` presents the protagonist room and its room-action menu.
   The selected semantic action is **leave the room for the corridor**. It is
   not the adjacent end-activity action.
2. A short room-side reaction is followed by the dormitory corridor at 20:30.
   The corridor presents a separate destination menu.
3. Selecting **return to the protagonist's room** leaves the corridor after a
   short corridor reaction.
4. The room is restored at 20:45, a short room-return reaction is presented,
   and the room-action menu is shown again.

Direct CP932 decode of the authoritative entries binds the visible sequence to
source coordinates without retaining the text:

| Role | Authoritative coordinate | Evidence |
|---|---|---|
| Room-return reaction | `43C.MES` address entry 36, code `0x1397` | exact short-text match to the 20:45 room frame |
| Room action row for leaving | `43C.MES` address entry 148, code `0x4846` | exact menu-row match to the selected 20:15 action |
| Room-side pre-corridor reaction | `43C.MES` address entry 230, code `0x9CA2` | exact short-text match immediately before the 20:30 corridor frame |
| Corridor return reaction | `44C.MES` address entry 340, code `0xB484` | exact short-text match to the final 20:30 corridor frame |
| Handoff back to the room script | `44C.MES` address entry 340, command `0x0E` at code `0xB4F3` | stored ASCII target `43C.MES` plus the target-qualified native trace |

The original UI times establish two observed 15-minute transitions for this
specific round trip. They are visual runtime evidence, not yet a generalized
rule for every room or corridor action.

## The Room-Action Menu Is the Question at 20161

Added 2026-10-04 (EP-12 H). The room-action menu above is the routine-40 question
at `43C.MES` `20161`: its selection definition group registers six rows at
`18345`, `18382`, `18419`, `18456`, `18493` and `18530`, and definition `18493` is
the leave row of the table above (its body at `18502` is address entry 148, code
`0x4846`). By meaning the rows are: phone someone, check belongings, recall a
girl's memories, end the day's activity (the adjacent end-activity action), leave
the room for the corridor, and the other commands. The third row leads to the 13
recollection ladders; see [43C caller group](43c_caller_group.md). Confidence:
**Confirmed** for the offsets and the registered rows (instrumented route probe),
**High** for the row meanings (read from the row text).

## First-Room-Entry Variation

A second operator-observed run on July 13 (Saturday) covered the protagonist's
first room entry in that save. A reproduced transition shows the selected
first-row reaction in the dormitory corridor at 18:50, then the protagonist's
room and its room-return reaction at 19:05, followed immediately by the normal
three-row room-action menu. The room-return reaction exactly matches the
entry-36 reaction already bound above. An earlier standalone capture showed
the same corridor menu at 19:05; because it came from a separate attempt, that
clock is retained only as menu-availability evidence and is not combined with
the reproduced 18:50-to-19:05 transition.

The three-row corridor destination menu is `44C.MES` address entry 338, intro
`0xB2B6`; its three displayed rows begin at code `0xB2CE`, `0xB2EF`, and
`0xB31D`. Selecting the first row, **return to the protagonist's room**, reached
the room and its room-action menu. No character-event presentation appeared
between the corridor confirmation and the room reaction; this observed flow is
`44C.MES` to `43C.MES` evidence and must not be attributed to EVENTB03.

A target-qualified capture attached before that selection recorded the native
command-`0x0E` receiver naming `43C.MES`, archive lookup, both stream-installer
passes, context/coordinate/cursor installation, a same-owner flag-8 execution
resume, the first retained-target consumption, and the matching target-run
return. All seven host-activation proof obligations completed in one session.
This establishes that the first-entry variation uses the same host-owned
`43C.MES` activation lifecycle, but it does not equate its room-side dialogue
branch with the July 27 entry-36 reaction above.

The capture starts at the native command receiver and therefore does not retain
the source `44C.MES` code coordinate. The exact command-`0x0E` producer for this
first-entry occurrence remains unresolved among the source-audited producers;
no one producer is assigned from timing or adjacency alone.

## Presentation Ownership Boundary

The archive-wide filename-bearing MMO audit finds no direct MMO presentation
record in `43C.MES`. `44C.MES` has one `I24A.MMO` record at code `0x8455`,
well outside address entry 340. The checked room/corridor frames therefore
must not be attributed to a local MMO marker at the coordinates above. The
original engine visibly changes from corridor to room while activating
`43C.MES`, but the native surface/resource owner remains external to this
local MES slice.

Evidence type: read-only authoritative `mes.arc` decode, direct MMO-marker
audit against the original `mmo.arc`, hash-bound original EXE/runtime trace,
and operator visual validation of the original engine. The archive hash was
identical before and after the focused decode. Confidence: **Confirmed** for
the ordered 43C/44C route, selected actions, source coordinates, and visible
20:15/20:30/20:45 frames; **Confirmed** for entry 338's first-entry corridor
menu, the reproduced 18:50/19:05 transition, the matching entry-36 room
reaction, and the complete native 43C activation/return lifecycle after its
first row; **Unresolved** for the exact first-entry command-`0x0E` producer,
the host-owned room/corridor image composition, and generalizing the observed
time advances.
