# FLOOR4 caller group

Inventoried on 2026-09-13 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`FLOOR4.MES` is the fourth-floor map, a small root that seven scripts
hand off to (`27C3A`, `27C3B`, `29C`, `EVENTA01`, `EVENTA05`, `EVENTA13`
and its own `EVENTL18`) and that asks no question of its own: its menu
at `4036..5673` branches on `state_u16[21]`, the destination the map
that handed off to it already selected - the MACHI E04 / E10 shape. Its
two unresolved EVENT intro sites differ in kind. `EVENTF03` is a nested
call (command `0x0F`) behind a typed guard on the menu's arm `6`, whose
callee returns and closes its own gate. `EVENTL18` is a root handoff
(command `0x0E`) at `3984..4000` on the floor's straight path from its
entry - no guard, no branch between the script's head and the handoff -
whose callee plays once behind its own `[2075]` gate, asks a
three-answer question, and hands the root back to `FLOOR4.MES` at
`9138`; the site has no typed origin the current schemas can name.

(Re-inventoried 2026-09-14 under Core 0.316.0: three intro sites for three
targets, `EVENTA13` and `EVENTL18` both behind typed guards in the map's
arm `4`, and nine scripts hand off to the floor once the tails are read,
`FLOOR3` and `FLOOR5` among them - see the correction below and "The
map's arm 4". The paragraph above is the 2026-09-13 reading.)

## The caller

| Property | `FLOOR4.MES` |
|---|---|
| framing-opaque bytes | **0 of 5,955** (the message region `2074..3814` is an opaque tail of 1,740 bytes) |
| instructions / branches / calls | 669 / 50 / 65 (447 / 17 / 39 with the 2026-09-13 tails opaque) |
| address-table entries | 16 |
| EVENT intro sites | 3, for three targets (2 before the 2026-09-14 re-inventory) |
| intros with a typed guard candidate | **all three** (one before 2026-09-14) |
| dispatch form | F03 a nested call whose callee returns; A13 and L18 root handoffs in arm 4 |
| framing-opaque bytes in the callees | 0 |

No target has another caller anywhere in the archive. `EVENTF03.MES` is
one body behind its own `global_u8[1624]` gate at `229` with no question
and no dispatch; it sets `[1624]` and `[1620]` and clears `[100]` - the
guard's prerequisite - at `4510..4532` before returning. `EVENTL18.MES`
is one body behind `[2075]` at `225`, with a three-definition question
whose answers move the L word, and one door `9138..9152 -> FLOOR4.MES`
after writing `[2042]`, the stamp `banked_u16[242]` and `[286]`.

## The two intros

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---|---|---|
| `EVENTF03` | `5078..5094` | nested call | `4654..4716` | 4,606 | 10 | 32 |
| `EVENTL18` | `3984..4000` | root handoff on the entry path | **none** | 9,158 | 34 | 87 |

## One guard, closed by the callee; one site with no guard

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---|---|---:|:-:|---:|---:|---:|
| `EVENTF03` | `4654..4716` | `5421` | 9 | - | 362 | 66 | **0** | **0** | 0 |
| `EVENTL18` | - | - | - | - | - | - | - | - | - |

After F03's return the caller writes `[12] = 1` and `[11] = 4`,
dispatches a script at `5371`, and transfers through `5929` back to the
floor's message loop at `2198`, which - as the measurement showed -
hands the root to `FLOOR3.MES` at `3008..3022`, a record inside the floor's
opaque tail `2074..3814`, before L18's handoff at `3984` is reached. L18's site therefore lies past the floor's own exit, behind the
address-table entries 3 and 4 at `3814` / `3877`, and no measured walk
of FLOOR4 passes it.

**Corrected 2026-09-14 (Core 0.316.0).** L18's site has a typed guard after
all; the 2026-09-13 reading missed it because the guard sits inside the opaque
tail `2074..3814` of the old framing. Decoded whole, the block after the
message loop is the floor's arm switch on the map's selection `state_u16[21]`:
arm `0` at `2588` walks down to `FLOOR3.MES` (`3008`), arm `1` up to
`FLOOR5.MES` (`3452`), arms `2` and `3` hand off to `27C3B` and `27C3A`, and
arm `4` at `3552` is a guard cascade. `3567..3655` is `EVENTA13`'s guard
(`10/00 < date < 12/31`, clock `< 16:30`, `banked_u16[201] > 80`, `[110]`,
`[112]`, `[114]`, `[117]`, `[260]`, `[1059]`, `[1034]`, `[1151]`, `[994]`
clear) with its handoff at `3660..3676`, and its false edge `3686..3769` is
`EVENTL18`'s guard: `11/15 < date < 1511` (the same unexplained upper bound
`EVENTI16`'s guard carries), `12:29 < clock < 16:01`, the L word
`banked_u16[209] > 60`, and `[190]`, `[194]`, `[197]`, `[2042]`, `[2075]`,
`[1966]`, `[1925]` clear. Its true path runs the palette setup at
`3779..3804`, the address-table prologues `3` and `4` at `3814` and `3877` -
labels the flow falls through, not entries anything selects - one message and
the handoff at `3984..4000`; its false edge lands at `4010`, the arm's
`29C.MES` handoff. Both intros in arm `4` therefore have F03's shape, a menu
arm plus a typed guard, and need no new origin kind; the F03 walk never passed
here because it ran with `state_u16[21] = 6`. `FLOOR1.MES` reads the same way:
`EVENTI04`'s two sites sit behind arm-`3` guards at `3918` (`4/00 < date <
6/16`, the I word `banked_u16[203] > 55`, stamp `banked_u16[242] != 28`,
`[1320]` clear) and `4244` (the same window and word, `date ==
banked_u16[260]`, `[1320]` set, `[1321]` clear). The table below and the
paragraph after it are the 2026-09-13 reading.

## The guards, read as scene conditions

The date is `state_u16[7]` as MMDD, the clock `state_u16[19]` as HHMM,
`banked_u16[263]` a stored date, `banked_u16[209]` the L family's
affection word. Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites (`== 1`) | Must be clear (`== 0`) |
|---|---|---|---|---|
| `EVENTF03` | menu arm `6`, `date == banked_u16[263]`, clock `< 16:01` | - | `[100]`, `[1623]` | `[1620]`, `[1624]`, `[107]`, `[1504]` |
| `EVENTL18` | - | - | (callee's own `[2075] == 0`) | - |

Read, not yet measured. F03 is the F family's fourth-floor appointment:
the date must equal the stored word `[263]` and the visit must come
before 16:01 with `[100]` and `[1623]` set; its callee reads the L word
in `41..100` for a `[198]` write and closes itself. L18 is the L family's
fourth-floor scene that the floor itself opens on entry while `[2075]`
is clear; the site has no guard because the callee carries the gate.

## EVENTF03: the F family's appointment on the stored date, closed by the callee, the floor walking down to FLOOR3

Measured 2026-09-13. `FLOOR4.MES:4654..4716` (false `5421`) wants the
map's selection `state_u16[21] = 6`, the date equal to the stored word
`banked_u16[263]`, the clock before `16:01`, `[100]` and `[1623]` set,
and `[1620]`, `[1624]`, `[107]`, `[1504]` clear; fourteen witnesses pin
the selection, the date pair, the clock edge and every flag, every
rejection walking the floor's menu and message loop to the same
`FLOOR3.MES` handoff the accepted route ends at. The prefix runs 12
messages to the nested call at `5078..5094`. `EVENTF03.MES` asks
nothing: behind its `[1624]` gate it writes `[5002]`, `[3402]`, `[198]`
when the L word is in `41..100`, copies `banked_u16[168 + state_u16[2]]`
into `[31 + state_u16[2]]` at `4419`, then closes itself - `[1624]` and
`[1620]` set, the prerequisite `[100]` cleared at `4510..4532` - and
returns at `4574..4575` after 36 messages; its `state_u16[5]` arms
cannot be witnessed from a seed because it clears bit 128 of
`banked_u16[2]` before recomputing them. The caller writes `[12] = 1`
and `[11] = 4`, calls `TIME_C.MES`, transfers back into its message
loop, clears `state_u16[21]` at `2331`, and after 6 messages hands the
root to `FLOOR3.MES` at `3008..3022` - a record inside the floor's opaque
tail `2074..3814`, bound as a runtime observation the way FLOOR5's v5
profiles bind theirs - a `natural_handoff` resume that never reaches
`EVENTL18`'s site at `3984`. The guard rejects on the resumed
state by four conjuncts at once, and a completed reentry returns
through the done-gate at `229` to `4605..4606` with **0 messages**.
Segmented and unbroken runs agree. `state_u16[8]` is rewritten at `266`
before it is read and the callee writes `global_u8[4000] = 1` at `545`
whatever is seeded; `[3006]` flips two arms.

Declared as `floor4_f03_v5.json` with no contract, `TIME_C` and
`EVENTL18` among the members, one caller-continuation route
`floor4-f03` with 11 variants on the `natural_handoff` resume to
`FLOOR3`, `post_guard_expected` 0, the reentry the done-gate return.
Audit accepted; `original event analysis FLOOR4 F03` passes 809
checks; a wrong resume message count and the call record shifted one
byte are rejected.

One FLOOR4 intro is measured and declared: F03 as one v5 route. The
other, L18, sits past the floor's own `FLOOR3` exit behind address-table
entries with no typed origin, and stays unqualified until the owner
rules on a script-entry origin. Read together, the fourth floor is a
corridor: the map hands the player down to the third floor unless the
selection picks a door, and F03's appointment is one of those doors.
(Superseded 2026-09-14: all three intros are declared - see the next
section.)

## The map's arm 4: two scenes behind one selection

Re-inventoried 2026-09-14 under Core 0.316.0, which reads the floor's
arm switch inside the former opaque tail `2074..3814`: arm `4` at
`3552..3562` (`state_u16[21] == 4`, false `4036`) holds two EVENT intros
in a cascade, `EVENTA13` behind the guard at `3567..3655` (false `3686`)
and `EVENTL18` behind the guard at `3686..3769` (false `4010`, the arm's
`29C.MES` handoff). The A13 site was not in the 2026-09-13 inventory
at all - its record lay in the tail - and the L18 site was read as
guardless. Both are root handoffs into callees that ask their own
three-answer question and hand the root back to `FLOOR4.MES` by one
door, so each is a root-replacement group with one route per answer,
measured with the route toolchain (`analysis/floor4_a13_spec.json`,
`analysis/floor4_l18_spec.json`). Both specs put the origin at the arm
test `3552` and select arm `4` in the baseline, so the declared prefix
carries the arm and, for L18, the rejecting A13 guard.

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---:|---:|---:|
| `EVENTA13` | `3660..3676` | root handoff | `3567..3655` | 12,252 | 33 | 134 |
| `EVENTL18` | `3984..4000` | root handoff | `3686..3769` | 9,382 | 34 | 87 |

| Intro | Calendar window | Affection | Must be clear (`== 0`) |
|---|---|---|---|
| `EVENTA13` | arm `4`, `10/00 < date < 12/31`, clock `< 16:30` | `[201] > 80` | `[110]`, `[112]`, `[114]`, `[117]`, `[260]`, `[1059]`, `[1034]`, `[1151]`, `[994]` |
| `EVENTL18` | arm `4`, `11/15 < date < 1511`, `12:29 < clock < 16:01` | `[209] > 60` | `[190]`, `[194]`, `[197]`, `[2042]`, `[2075]`, `[1966]`, `[1925]` |

`banked_u16[201]` is the A family's affection word and `[209]` the L
family's; L18's upper date bound `1511` is the unexplained value
`EVENTI16`'s guard also carries. The two windows overlap from November
16 to December 30, where A13 is tested first.

**EVENTA13** - `floor4_a13_v6.json`, routes `floor4-a13-result1`
(12 variants), `-result2` and `-result3` (one each), 542 checks,
`P_PIC` and `A_PIC` among the members. Behind its `[1151]` gate the
callee asks three answers, each leaving by the one door `11880..11894 ->
FLOOR4.MES` - after 63, 68 or 84 messages - closing itself (`[1151]` at
`11811`), stamping `29` and writing `[286]`; only the third answer moves
the A word, `+3` at `11591`, and counts `[244]`. The guard rejects
afterwards (`post_guard_expected` 0) and a direct reentry returns through
the done-gate with 0 messages.

**EVENTL18** - `floor4_l18_v6.json`, routes `floor4-l18-result1`
(14 variants), `-result2` and `-result3` (one each), 568 checks,
`L_PIC` among the members. The callee closes its gate `[2075]` at `747`,
before its scene, reads `banked_u16[200]` in `31..80` at `118` for a
`[108]` count, asks three answers - the first moves the L word by `-2`
at `6774`, the second by `+1` at `7641`, the third by `+2` at `8444` -
and leaves by the one door `9138..9152 -> FLOOR4.MES` after 89, 85 or 85
messages, stamping `29` and writing `[2042]` (a clear-flag of its own
guard and of 44M's L10 guard) and `[286]`; the guard rejects afterwards
(`post_guard_expected` 0) and a direct reentry returns through the
done-gate with 0 messages. The
`word209-*-direct` rows (the callee's own reads of the L word at `6753`)
are measured and listed under `unresolved`, not declared.

Audit accepted for both; `original event analysis FLOOR4 A13` and
`FLOOR4 L18` pass; a wrong callee message count and the door shifted
one byte are rejected. The floor's three intros are now measured and
declared, and the 2026-09-13 reading of L18 as a site with no typed
origin is withdrawn (see the correction above).

## Arrival: the floor's own poll, declared (2026-09-14, Core 0.319.0)

The declaration above put both origins at the arm-4 test `3552` and selected
the arm in the baseline. Under Core 0.319.0 both groups start at the floor's
entry `0` and supply the player's location at the floor's own `Util(6,13)`
poll, so the arm is the location the player walked to, not a seeded cell:
`floor4_a13_v11.json` (528 checks) and `floor4_l18_v11.json` (584) replace
the v6 profiles, and the contract is declared as spent by the prefix and the
unbroken run.

The entry path, read whole: `0..2198` is the floor's setup - the manager
vectors cleared, `global_u8[10..20]` zeroed, BGM `call_sub(23)` with slot
`11`, the map loaded (`Util(6,7,0,123)`, `System.function[8](0,"floor4.eve",...)`,
`Util(6,12,2)`), the sprite placed by `state_u16[16]`'s arm
(`Util(6,1,n,0,1)`), and the arrival mode read from `global_u8[3001]`,
`[3009]` and `System.var16[198]`. The walk loop at `2198..2588` then reaches
one of three polls. With `[3001] == 0` and a menu request pending
(`state_u16[17] == 65534` after `[17] = [18]`) it calls `FLOOR4.INC.MES` and
polls at `2304`; with `[3001] == 0` and no request it polls at `2323`, copies
`[21] = [18]`, waits (`System.function[12]`) and leaves the loop unless both
`[21]` and `[17]` are `0xFFFF`; with `[3001] == 2` it runs the mode-2 init
(`Util(6,14,0,0)`, `6,2`, `6,6`, `6,11`) and polls at `2497`. The arm switch
at `2588` follows.

Declared: `global_u8[3001] = 0` and `[3009] = 0`, `state_u16[17] = [18] =
0xFFFF` (no request, no location yet) in the baseline, and the contract
`{FLOOR4.MES, 2323, [4]}`. The walk spends the location in the prefix,
copies it to `state_u16[21]`, passes the arm-4 test and reaches A13's guard
at `3567` - or, on L18's rejecting calendar, L18's guard at `3686` - with the
same doors, effects and reentries as before; the floor's setup and loop emit
no message. The setup also writes what the arm-test origin could not see,
now constant in every route: `global_u8[3000] = 0` joins the constant effects (the setup clears it), while `banked_u16[1]` and `global_u8[4000]`, which the arm-test declaration had carried, lie outside the arrival measurement's watched cells.

F03 followed the same day, and it needs two locations. Its callee returns,
so the floor walks on: the F03 branch's tail (two messages and `TIME_C`),
the cascade's tail at `5929`, the arm switch again, and - `state_u16[21]`
still `6` - arm 6's second branch (`5421`, `global_u8[12] == 0`: a message,
`[12] = 1`, `TIME_C`), then back to the walk loop, whose poll asks where the
player goes next. The old declaration took that poll as omitted, which left
`state_u16[18]` at its seeded `0` and sent the floor down to `FLOOR3` by
accident of the seed. Declared now as `{FLOOR4.MES, 2323, [6, 0]}`: location
`6` at the arrival, spent by the prefix, and location `0` after the callee,
spent by the resume - the player choosing to go down - reaching the same
`FLOOR3` handoff at `3008` with the same 6 resume messages
(`floor4_f03_v12.json`, 604 checks, replacing the v5 profile with its
two `[209]` arm variants restored; the resume's
effects gain `state_u16[17] = 6` and `[18] = 0`, the map cells as the
walk leaves them). Supplying `7` and `0` instead is rejected. The segmented
chain carries one queue for this: the callee run inherits what the prefix
left, the resume what the callee left, as the unbroken run does.

Not declared: the menu path (`2304`, the floor's own menu script) and the
mode-2 arrival (`2497`); which mode each of the nine callers leaves in
`[3001]` and `[3009]` (their resumes carry it, not this group); locations
`1..3` and `5` on arrival (`FLOOR5`, `27C3B`, `27C3A`, the `TIME_C`
branches), and any way out other than `0`.

## Not measured here

What sets `[100]`, `[1623]` and the date word `[263]` before F03's
appointment; what A13's and L18's questions
offer as native input; the menu and mode-2 arrivals; and `TIME_C.MES`,
`FLOOR3.MES` and `29C.MES` past their handoffs. What selects arm `4` is
answered above: the location the player walks to.
