# GROUND K02 event analysis

Measured on 2026-09-09 against the configured original `ELFIMAGE/mes.arc`.
All coordinates are code-relative, with exclusive end offsets. This analysis
qualifies the selected original caller path and its state effects; it does not
promote an Event Player catalog entry or certify every outer scheduler state.

## Source identity and runtime policy

The original archive SHA256 is
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`.
`config/event_catalog/analysis_groups/ground_k02_v5.json` binds GROUND,
EVENTK02, START, DEF_MAIN and LIBLARY. The source auditor freshly rebuilds
actual Python Phase 1-4 instruction-v45 handoffs.

| Entry | Entry SHA256 | Python handoff SHA256 |
| --- | --- | --- |
| GROUND.MES | `b5dd1b444d1dbb4327e46a853e881c5ff46890a0b01b7ed7e9b92f2fdbc8b282` | `12ef35192a66806dc97b9c983c972969f31958fd1ff3c8b0878bca7ef0ef5dfb` |
| EVENTK02.MES | `89fc1edfa4fcbee42c5e53a30f64e65c54be148805125d4c644661bdc411bf4e` | `9f1ef76f7618317e5f1bfd2d724cc479877aca1e540dfa63d7dd3509aea435f4` |

EVENTK02 has no Python opaque boundaries. GROUND retains its opaque tails.
The existing START calendar table hash is
`f21ee0fcb09e960046878e35ad0410aed88680f849ace471b713ef7a12525b4a`.
Full sandbox objects carry its runtime backing and aliases between segments.
Native pixels, audio, input timing and cadence remain omitted; MACHI itself
is not executed after its replacement boundary.

The profile uses the V5 source-bound opaque-guard contract described in
[C07/C12 analysis](ground_c07_c12_analysis.md). The instrument starts at a
typed origin, verifies that the actual trace evaluates the declared local
guard to true, and stops immediately before the exact dispatch for state
inspection. Segmented execution must reproduce an unbroken run's signature
rows, message observations and written-value snapshot. Independently decoding
and hashing an opaque guard does not promote the containing tail to typed IR.

## Original origin and local predicate

The baseline starts at the earlier typed K01 guard `GROUND:6044`, with
state_u16 slots0=30, 1=15, 4=6, 7=501, 19=1530 and 21=0,
global2276=1 and global2277=2. Other writable state starts fresh.

The original runtime trace evaluates the guards at 6044, 7005, 9627, 12184,
14586, 15532 and 16583 to false, then evaluates the K02 guard at 17570 to
true. No earlier event is invoked on this selected prefix. The baseline is
a controlled caller state, not proof that the outer scheduler naturally
produces those values.

The K02 guard `17570..17624`, false target 18749, requires all of:

- slot21=0 and slot4=6;
- date slot7 below 616 or above 915;
- time slot19 below 1600;
- global2276=1, global2277=2 and global2279=0.

There are **18** one-field acceptance/rejection and numeric-boundary witnesses.
Each checks the exact original conditional expression. The complete route
then reaches the typed call `17832..17848 -> EVENTK02.MES`, starting at 0.

The caller advances its clock before the nested event. The normal origin
1530 enters K02 at 1540. Additional complete cases start at 0550 and 1550
with matching hour/minute slots and enter at 0600 and 1600 respectively.
The local condition applies before that advance, so the 1550 case legitimately
enters the callee at 1600 even though the entry guard requires a value below
1600 when evaluated.

## Full paths and state effects

The **21** complete cases comprise:

- bank-zero word2 in {0,128,255,65535}, global4000 in {0,1} and global3006
  in {0,1}: 16 combinations;
- two clock cases at 0550 and 1550;
- two seasonal date boundary cases at 615 and 916;
- one caller copy case with distinct source/destination endpoint values and
  a nonzero word242 value.

All cases reach the same boundaries and message counts:

| Segment | Original boundary | Message observations |
| --- | --- | --- |
| GROUND prefix from 6044 | 17832..17848 -> EVENTK02.MES | 6 |
| EVENTK02.MES from 0 | return 2705..2706 | 27 |
| GROUND suffix from 17848 | 18726..18739 -> MACHI.MES | 12 |
| Unbroken path | same MACHI replacement | 45 |

No routine-40 choice is encountered. The callee's phase test `229..240`
requires global2277=2. It writes slot8=0 at `266..271` before its display
state branches. In these cases it sets global2558 at `1476..1482`,
global5243 at `1666..1672` and global3629 at `2621..2627`, and clears
slot2 at `2680..2685` before returning.

The global3006 gates at `651..662` and `1575..1586` both receive zero and
one in the matrix. The callee's final global3005 is 0 when global3006=0,
and 15 when it is 1. Those are observed state effects, not claims that the
omitted native presentation was reproduced. Seeding global4000=1 does not
make the tested conditions at 500, 884 or 1418 true on these caller-origin
runs; they remain one-sided observations.

The event repeatedly sets and clears mask128 in bank-zero word2 around
bounded presentation records. Its final word2 is the input with that bit
cleared: 0→0, 128→0, 255→127 and 65535→65407. The last clear is
`2530..2543`. These cases check preservation of the other bits. The separate
slot5 test at `1153..1163` remains false in the measured instrument; original
native activity that could affect such state is not reconstructed here.

The caller suffix performs a 16-word copy. It resets slot2 at `17871..17876`,
checks `slot2 < 16` at `17876..17886`, copies bank-zero word `168+slot2`
to `31+slot2` at `17886..17903`, and increments slot2 at `17903..17911`.
The endpoint witness confirms word168=12345 reaches word31 and
word183=54321 reaches word46, replacing initial values111 and 222.
Slot2 finishes at 16.

Caller completion writes are separate from the callee return:

| GROUND range | Confirmed write |
| --- | --- |
| 18374..18380 | global2277 = 3 |
| 18385..18391 | global2279 = 1 |
| 18396..18405 | bank-zero word242 = 0 |

The endpoint witness also checks word242 resetting from 65535 to 0. Final
states have slot16=13 and slot8=46, and reject the original K02 local guard.
The global assignments above are literal writes, not inferred counters or
native narrative meanings.

## Direct reentry and coverage limits

Each completed state is used for a separate direct K02 invocation. Global2277
is now 3, so `229..240` is false. The event writes slot2=1 at `2711..2716`,
executes its existing shared routine and returns at `2736..2737` with no
message observations. The report preserves the slot2 change from 16 to 1;
this zero-message return is not treated as inert.

The measured paths and reentries visit **8 of 10** K02 conditional sites,
with both outcomes at three sites. The unvisited sites326 and 381 follow the
slot8 reset and are not reached on these paths. Other one-sided predicates,
untested caller states, outer scheduling and native presentation remain open.
A matching trace under the stated policy is not proof of every native effect.

## Opaque source binding and reproduction

| Observation | Containing opaque tail | Tail SHA256 |
| --- | --- | --- |
| K02 guard 17570..17624 | 17483..17669 | `16cfd552d9c85f7885bf58fedce80f81e3432b9fb59dee90f66d0bd274ee94a3` |
| MACHI handoff 18726..18739 | 18662..19165 | `4deb6fabed11f174e288607ed1fa81621bbcbdc512749914fdb003653326e731` |

The exact guard record SHA256 is
`93c8c3cbb63c10ff013b4451dcb9bb678a41fa36cb2e4d9aa0ec43f3347bde58`.
The prefix `[6044,17848)` SHA256 is
`216eca99024c364f5b2a75fe7290339458273782d11f6a5d9999a3cd9651426b`.
The typed dispatch record SHA256 is
`e576101f26cf0e4b4aa8c12b3cbdc269f03972b1ccab642452e686f4c2a62f81`;
the MACHI replacement record SHA256 is
`496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047`.

| V5 identity | SHA256 |
| --- | --- |
| Profile | `917d1e29c84009a57661f48bf05858790efbd2572c54d5237561d8670d7daedc` |
| Python source audit | `528de4e4725131126cb18876c15086ae001015a52547c0b23be84dc1eeec9511` |
| Runtime report | `d47fea1eb8a6b6b3ce51ec3e3ca0e8b558859e0259e80e15b52bff8df5038141` |

The group passes **693 assertions**, including the 18 local guard witnesses
and 21 full paths. Reproduce it with `validate_event_analysis_group.gd`,
the configured original archive directory and
`config/event_catalog/analysis_groups/ground_k02_v5.json`. EP-07 owns remaining
route qualification; EP-05 owns regression coverage.

## Arrival: the grounds' own poll, declared (2026-09-14, Core 0.319.0)

K02 was declared from the cascade's head `6044` with `state_u16[21] = 0`
seeded; it now starts at the grounds' entry `0` and supplies location `0`
at the poll `5969` (`{GROUND.MES, 5969, [0]}`, spent by the prefix), with
the arrival mode `0`, no pending request and the earlier declaration's
calendar. `ground_k02_v12.json` (910 checks) replaces the v5 profile
with the same resume (`MACHI.MES` at `18726` after 12 messages) and the
earlier declaration's 21 variants carried over. Location `1` instead is
rejected. The loop and the cascade are read in
[GROUND C07 and C12](ground_c07_c12_analysis.md).

## The gate's exit is the location's (2026-09-15)

Read in [GROUND C07 and
C12](ground_c07_c12_analysis.md#the-gate-location-0s-exit-belongs-to-the-location-2026-09-15):
the map change after K02 is location `0`'s own exit, copied inline at the end
of K02's branch (`18726`), and a walk that sees no event leaves by the
cascade's last branch. `ground_k02_v12.json` (935 checks) declares it as a
bypass variant, replayed from the grounds' entry with location `0` and checked
never to dispatch the callee: `no-event-weekday-1` - the gate after 0
messages. The two chains at `15:50` and `15:59` that the 2026-09-14 arrival
listed as never reaching the dispatch are now listed with their door: they
pass K02's guard, skip its call inside the branch and leave by F02's root
handoff at `31419..31435` after 60 messages - the next event's way out, not
the gate's, so they stay measured and not declared.
