# MES Analysis: Date Scene

This document consolidates the Maki date analysis used by DateScene. It records
rules and offsets, not original dialogue.

## Source Flow

| Phase | Principal script | Confirmed responsibility |
|---|---|---|
| promise/reservation | `D_PROMIS.MES` | writes selected location ID |
| duration and expense | `D_DATE2.MES` | duration, affection gain, location cost, payment flag |
| post-date result | `D_DATE3.MES` | Maki payment penalty, primary menu, escort/alone branches |
| doorstep follow-up | `D_DATE5.MES` | nested home-front choices and attempt flags |
| map gating | `MACHI.MES` | loads Maki follow-up scripts from date/time/map state |
| recurring conversation | `D_TALK00/50/60/70/80/90.MES` | establishes Maki's home-known flag |

## Reservation, Duration, and Location

- `D_PROMIS.MES:0x0FFC` writes the selected location to `global_u8[229]`.
- `D_DATE2.MES` uses `global_u8[620]` as the selected duration in hours.
- Ordinary-location duration bands at `0xC69B`--`0xC718` give affection `+1`
  for 1--4 hours, `+2` for 5--6, and `+3` for 7--10.
- Children's-park location IDs 5--7 use a separate flat `+1` path.
- The local free park maps to source ID 5. The paid world park maps to source
  ID 3.

`D_DATE2.MES:0xC916`--`0xCA79` computes cost in 100-yen units. With `h` equal
to duration hours, the recovered formula table is:

| Location ID | Cost units |
|---:|---:|
| 0 | `5h` |
| 1 | `10 + 3h` |
| 2 | `5h` |
| 3 | `20 + 3h` |
| 4 | `30 + 2h` |
| 5 | `0` |
| 6 | `0` |
| 7 | `0` |
| 8 | `6 + 2h` |
| 9 | `30 + 5h` |
| 10 | `24 + 3h` |
| 11 | `120 + h` |
| 12 | `36 + 3h` |
| 13 | `140 + h` |
| 14 | `0` |

Names for IDs other than the currently used local variants are not promoted
here until their CP932 labels are normalized and independently checked.

## Expense Shortfall

- `D_DATE2.MES:0xCA82` clears the heroine-payment flag.
- `D_DATE2.MES:0xCAC4` sets it when the computed cost exceeds player money.
- `D_DATE3.MES:0x02B8` consumes the flag before normal post-date handling.
- No separate Maki eligibility gate for covering the shortfall has been found.

Maki's confirmed affection penalties after covering a shortfall are:

- below 21: `-5`;
- 21--30: `-4`;
- 31--40: `-3`;
- 41--50: `-2`;
- 51--80: `-1`;
- 81 or above: no penalty.

These penalties are separate from the later love-hotel money check.

## Initial Post-Date Menu

The Maki affection-band branches from `D_DATE3.MES:0x04A6` through `0x1C7D`
converge at `0x22E8`. The initial three-choice menu starts at `0x2373`, so no
Maki affection gate is projected onto the existence of that menu.

`global_u8[15] == 0` at `0x23F5` is a retry guard for the third choice after an
unavailable alone-location attempt, not a menu affection gate.

## Escort Home

`D_DATE3.MES` begins the escort result checks at `0x3211`:

- affection 0--50 rejects, split into five 10-point presentation bands;
- affection 51--60 succeeds only when `global_u8[709] == 1`;
- affection 61+ succeeds independently of that flag;
- success presentation is split into 61--70, 71--80, 81--90, and 91+ bands.

Important branch offsets are `0x350A` for the 51--60 auxiliary flag and
`0x3789`, `0x3B76`, `0x3FC2`, and `0x44F9` for later bands.

`global_u8[709]` is confirmed as Maki's *home known* flag:

- `MACHI.MES` requires it when loading `maki12.mes` at `0x79B0`, `0x7BFE`,
  `0x7E58`, `0x8043`, `0x81D3`, `0x8419`, and `0x85D1`;
- recurring Maki talk scripts write it immediately after the conversation in
  which her home location becomes known: `D_TALK00:0xC1D7`,
  `D_TALK50:0x8569`, `D_TALK60:0x91FD`, `D_TALK70:0xA831`,
  `D_TALK80:0xB7CC`, and `D_TALK90:0xB664`.

## Doorstep State Machine

After a successful escort, `D_DATE5.MES` builds a nested menu at `0x0ACD`.

| Action | Acceptance | Success | Rejection | Attempt flag |
|---|---:|---:|---:|---:|
| hug | affection `>= 70` at `0x0FE0` | `+1` | `-5` at `0x124D` | `global_u8[10]` |
| kiss | affection `>= 65` at `0x1581` | `+1` | `-6` near `0x17E6`/`0x17FB` | `global_u8[11]` |
| action 3 | affection `>= 80` | projected state change | `-7` at `0x205D` | `global_u8[12]` |
| action 4 | affection `>= 90` | projected state change | `-8` at `0x2A2E` | `global_u8[13]` |

A successful attempt hides only that action and returns to the remaining menu.
A rejected hug or kiss ends the escort sequence after its result dialogue. The
source replaces the initial parting entry with a stop-and-part entry after an
attempt. Action 4 gains an additional `+1` when flags 10, 11, and 12 were
already set (`0x2E26`).

## Be Alone and Location Choice

- Maki accepts the primary be-alone choice from affection 51; `0x4EF5` handles
  the below-51 rejection.
- The location question begins at `0x5D86`; the secondary menu begins at
  `0x5E65`.
- Its three labels begin at `0x5E79`, `0x5EB8`, and `0x5EF3`.
- Retry guards are `global_u8[11]`, `[12]`, and `[15]`.
- Maki's home and the protagonist's dorm room are unconditional source-authored
  rejections in this branch.
- The love-hotel branch at `0x62DD` requires `state_u16[12] >= 150`, representing
  15,000 yen.
- Time checks at `0x642E` and `0x654D` allow through 21:30 on normal dates and
  only through 18:30 on December 24. The next minute takes the failure branch.

## Music

`D_DATE3.MES:0x5e35` assigns selector `33` and `0x5e3b` invokes shared BGM
routine `23`. The current Maki date therefore selects the same character track
as her encounter scenes.

Related runtime documents:

- [Date Scene](../scenes/date_scene.md)
- [Dating System](../systems/dating.md)
- [Dating Data Examples](../data/dating_data_examples.md)
