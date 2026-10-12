# FLOOR1 caller group

Inventoried on 2026-09-14 against the configured original `ELFIMAGE/mes.arc`,
SHA256 `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`,
under Core 0.316.0, which reads the floor's whole switch as typed records.
All coordinates are code-relative with exclusive end offsets. Python Phase 1-4
instruction-v45 handoffs are the structural authority and GDScript is the
execution instrument. This is a bounded original-event observation. It promotes
no Event Player catalog entry, and it does not establish how the outer scheduler
reaches any measured origin.

`FLOOR1.MES` is the first-floor map, a root that eleven scripts hand off to
at fourteen sites (`27C1A`, `28C` at three, `31C`, `32C`, `EVENTC03`,
`EVENTI23`, `EVENTL13`, `FLOOR2`, `GROUND`, and its own `EVENTI04` by each
of its three doors) and that asks no question of its own: after its
message loop it branches on `state_u16[21]`, the destination the map that
handed off to it already selected - the MACHI E04 / FLOOR4 shape. Arm `0`
walks out to `GROUND.MES` (`3822`), arms `1` and `2` hand off to `31C.MES`
(`3861`) and `32C.MES` (`3897`), arm `4` to `27C1A.MES` (`4597`), and arm
`3` is a guard cascade for one target: `EVENTI04` at two sites, `4218`
behind the guard at `3918` and `4520` behind the guard at `4244`, with
`28C.MES` (`4561`) when neither holds. Every one of the floor's exits -
to the town at `2251`, to the grounds at `3782`, to the second floor at
`6158` - first asks whether the eavesdropping is in progress (`[1320]`
set, `[1321]` clear) and, if so, closes it: `[1321] = 1`, `[190]` and
`[130]` cleared.

## The caller

| Property | `FLOOR1.MES` |
|---|---|
| framing-opaque bytes | **0 of 6,254** |
| instructions / branches / calls | 720 / 64 / 61 |
| address-table entries | 17 |
| EVENT intro sites | 2, for one target |
| intros with a typed guard candidate | **both** |
| dispatch form | root handoffs |
| framing-opaque bytes in the callee | 0 |

`EVENTI04.MES` has no other caller. It is one script in three stages
behind no done-gate of the usual kind: `219` reads `[1320]`, and the
stages select on `[1320]` and `[1323]`, each leaving by its own door back
to `FLOOR1.MES` - `2610..2624`, `4427..4441` and `5469..5483`.

## The two sites

| Intro | Site | Form | Guard | Callee size | Callee branches | Callee messages |
|---|---|---|---|---:|---:|---:|
| `EVENTI04` (first) | `4218..4234` | root handoff | `3918..3964` | 5,585 | 22 | 28 |
| `EVENTI04` (again) | `4520..4536` | root handoff | `4244..4297` | 5,585 | 22 | 28 |

| Intro | Guard | False target | Conjuncts | `or` | Gap bytes | Records | Branches | Dispatches | Edges in |
|---|---|---|---|---|---:|:-:|---:|---:|---:|
| first | `3918..3964` | `4244` | 6 | - | 254 | - | **0** | **0** | 0 |
| again | `4244..4297` | `4546` | 7 | - | 223 | - | **0** | **0** | 0 |

The first guard's false edge is the second guard: a visit that is not the
first of the day is tested for being a later one of the same day.

## The guards, read as scene conditions

The date is `state_u16[7]` as MMDD, the clock `state_u16[19]` as HHMM,
`banked_u16[203]` the I family's affection word, `banked_u16[242]` the
day's last stamp and `banked_u16[260]` the date the first visit stored.
Flags are `global_u8`.

| Intro | Calendar window | Affection | Prerequisites | Must be clear (`== 0`) |
|---|---|---|---|---|
| first | arm `3`, `4/00 < date < 6/16` | `[203] > 55` | stamp `[242] != 28` | `[1320]` |
| again | arm `3`, `4/00 < date < 6/16`, `date == [260]` | `[203] > 55` | `[1320] == 1` | `[1321]` |

The first site opens the eavesdropping: the floor sets `[130]` and
`[190]`, stores the date in `[260]` at `4203`, and hands off. The
callee's first stage sets `[1320]` at `2497`, counts `[264]`, stamps
`28` and writes `[286]` and `[3495]` before its first door. A later visit
the same day - the stamp now `28`, so the first guard rejects - passes the
second guard while `[1321]` is still clear, and the callee's second stage
(`[1320]` set, `[1323]` clear) sets `[1323]` at `4329` and leaves by its
second door; a third visit finds `[1323]` set and runs the last stage to
the third door. Leaving the floor by any exit closes the day.

## EVENTI04: the I family's spring eavesdropping in three stages

Measured 2026-09-14 with the route toolchain (`analysis/floor1_i04a_spec.json`,
`floor1_i04b_spec.json`, `floor1_i04c_spec.json`), one group per stage,
since each stage is a root replacement that leaves by a different door.

**First stage** - `floor1_i04a_v6.json`, one route `floor1-i04a` with 11
variants, 293 checks. From the guard at `3918` the floor emits
6 messages and hands off; the callee leaves by `2610..2624 ->
FLOOR1.MES` after 18 messages with `[1320]`, `[264]`, the stamp
and its two flags written; the guard rejects afterwards
(`post_guard_expected` 0) and a direct reentry - `[1320]` now set - runs the
second stage to `4427..4441` with 10 messages, which is what a
reentry of a script with no done-gate does.

**Second stage** - `floor1_i04b_v6.json`, one route `floor1-i04b` with 10
variants, 231 checks, seeded with the stored date equal to the day and
`[1320]` set. The callee leaves by `4427..4441` after 10 messages
with `[1323]` and the stamp written; the guard still accepts on the
resumed state (`post_guard_expected` 1) and a direct reentry runs
the third stage to `5469..5483` with 5 messages. The
`global_u8_1323-1` row is measured and listed under `unresolved`: it
leaves by the third door and is the third group's baseline.

**Third stage** - `floor1_i04c_v6.json`, one route `floor1-i04c` with 10
variants, 221 checks, seeded with `[1323]` set as the second stage
leaves it. The callee leaves by `5469..5483` after 5 messages;
the guard still accepts (`post_guard_expected` 1) on the resumed state and a direct reentry runs
the same stage again with 5 messages, since nothing in the
callee closes it - the floor's exits do.

Audit accepted for all three; `original event analysis FLOOR1 I04A`,
`I04B` and `I04C` pass; a wrong callee message count and the door
shifted one byte are rejected in each.

## Arrival: the floor's own poll, declared (2026-09-14, Core 0.319.0)

The three stages above were declared from their guards with
`state_u16[21] = 3` seeded. Under Core 0.319.0 they start at the floor's
entry `0` and supply the player's location at the floor's own
`Util(6,13)` poll, so arm `3` is where the player walked, not a seeded
cell: `floor1_i04a_v11.json` (271 checks), `floor1_i04b_v11.json` (211)
and `floor1_i04c_v11.json` (201) replace the v6 profiles, each contract
spent by the prefix and the unbroken run, and supplying location `4`
instead sends every walk elsewhere (rejected in all three).

The floor's walk loop at `2681..3430` has the shape of the other floors':
with `global_u8[3001] == 0` it runs `Util(6,8)`, copies `[17] = [18]` and,
on a menu request (`[17] == 65534`), calls `FLOOR1.INC.MES` and polls at
`2797`; otherwise it polls at `2816`, copies `[21] = [18]`, waits
(`System.function[12]`) and leaves the loop unless both `[21]` and `[17]`
are `0xFFFF`. The other arrival modes (`[3001]` of `2` or `3`, with the
scroll and camera calls `Util(6,15..17)`) poll at `3074`, `3214` and
`3339`. The arm switch at `3430` follows.

Declared: `global_u8[3001] = 0` and `[3009] = 0`, `state_u16[17] = [18] =
0xFFFF` in the baseline, the contract `{FLOOR1.MES, 2816, [3]}`; the guard
records test `state_u16[21] == 3` themselves, so the baseline still carries
`3` for the guard witnesses while the walk overwrites the cell from the
poll before it reaches them. The prefix reaches the first site's handoff
at `4218` with six caller messages on the way, and the floor's setup writes
the map word `banked_u16[242] = 28`, now constant in every route.

Not declared: the menu path and the mode-2 and mode-3 arrivals; which mode
each of the ten callers leaves in `[3001]` (their resumes carry it); the
floor's other seven locations.

## Not measured here

What moves the I word; the floor's other arms and its message loop as
scenes; the menu and mode-2/3 arrivals; and `28C.MES`, `GROUND.MES`,
`31C.MES`, `32C.MES` and `27C1A.MES` past their handoffs. What selects
`state_u16[21] = 3` is answered above: the location the player walks to.
