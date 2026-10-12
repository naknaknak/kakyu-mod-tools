# Normal Conversation

## Scope and Source Boundary

This note starts from the exact menu label of the normal-conversation command
(6 characters; the tool recognises it by the length and SHA-256 of its CP932
bytes, see `tools/README.md` `inspect_normal_talk.py`) and traces the
original control flow around that entry point. The authoritative input is the
configured raw `ELFIMAGE/mes.arc`; generated IR is only an audit aid.

The investigation covers the 96 exact-label owners in `A_TALK*.MES` through
`L_TALK*.MES`, the directly observed Maki caller in `12C.MES`, and the reset
sites in `DEF_MAIN.MES`. `START.MES` is used only to establish that the
original startup executes `LIBLARY.LIB` and then `DEF_MAIN.MES`, allowing the
latter's command-`0x14` registrations to populate the manager-owned map. It
does not yet assign gameplay names to every numeric flag inside the talk
scripts. Dialogue text is intentionally omitted.

All offsets below are code-relative hexadecimal offsets in the named archive
entry.

## Corpus Inventory

An exact CP932-label scan finds the entry point in 96 scripts:

- character prefixes `A` through `L`;
- eight files per prefix: `TALK30`, `TALK40`, `TALK50`, `TALK60`, `TALK70`,
  `TALK80`, `TALK90`, and `TALK00`;
- every one of those 96 entries decodes at 100 percent with the v4 basic-block
  decoder.

Other archive entries can contain the same character sequence inside longer
text. They are not counted as menu-label owners. This distinction is
**Confirmed** by exact decoded text equality, not a raw substring alone.

In every exact-label owner, the label is associated with the first observed
talk-choice construction and a later branch on `state_u16[21] == 1`. The true
fallthrough of that branch enters the normal-conversation body; the false edge
continues to handling for another selected choice. This repeated structure is
**Observed** across all 96 scripts. The complete native semantics of
`command_10` remain **Unresolved**, so the command itself must not yet be used
as the sole definition of a menu insertion operation.

## Maki Caller and Affection Bands

`12C.MES` selects the Maki talk script from confirmed affection
`banked_u16[0][212]`. At the first directly traced selector, the outer gate at
`0x0389` requires affection greater than 20 and `global_u8[224] == 0`.
Otherwise this selector bypasses the `D_TALK*.MES` call.

| Affection at this caller | Called entry | Condition / call offset |
|---|---|---|
| 21--30 | `D_TALK30.MES` | `0x03A1` / `0x03B3` |
| 31--40 | `D_TALK40.MES` | `0x03CD` / `0x03DF` |
| 41--50 | `D_TALK50.MES` | `0x03F9` / `0x040B` |
| 51--60 | `D_TALK60.MES` | `0x0425` / `0x0437` |
| 61--70 | `D_TALK70.MES` | `0x0451` / `0x0463` |
| 71--80 | `D_TALK80.MES` | `0x047D` / `0x048F` |
| 81--90 | `D_TALK90.MES` | `0x04A9` / `0x04BB` |
| 91+ | `D_TALK00.MES` | `0x04D5` / `0x04E7` |

This proves that `TALK00` is the top affection band on this path, rather than
the lowest band. The thresholds, calls, and outer bypass are **Confirmed**.
Whether every caller of every heroine uses the same outer gate is
**Unresolved**.

## Encounter Opening, TALK, and Farewell

The normal Maki encounter path in `12C.MES` separates meeting presentation,
the command menu, and farewell:

| Phase | `12C.MES` evidence |
|---|---:|
| character presentation | `D_PIC.MES` call at `0x035E` |
| meeting/opening dialogue | `D_INTRO.MES` call at `0x0370` |
| affection-banded command menu | `D_TALK30` through `D_TALK00` calls at `0x03B3`--`0x04E7` |
| conditional reservation handling | `D_PROMIS.MES` call at `0x050C` |
| parting/farewell dialogue | `D_OUTRO.MES` call at `0x0637` |

`D_INTRO.MES` contains event-specific positive and negative affection writes,
but it has no common unconditional meeting gain. For Maki these include
several penalty or correction branches and are not ordinary-conversation
rewards.

`D_OUTRO.MES`, by contrast, contains 48 direct Maki affection writes and every
one computes `+1`. They are duplicated across
presentation, random
dialogue variant, and encounter-mode branches. On the ordinary Maki paths the
gain is available only while the starting affection is below 51, and is
suppressed by branches where `global_u8[224] != 0`. Thus a start value of 50
can become 51, while a start value of 51 does not use this basic farewell
gain. These offsets and conditions are **Confirmed**; the broad gameplay name
of flag 224 remains **Projected** as an encounter-gain suppression state.

The same placement is **Observed** across the full character corpus. All 12
`A_OUTRO.MES` through `L_OUTRO.MES` entries contain direct `+1` assignments
for their own affection index, and no other such delta. Their site counts
and caps differ by character. The paired `*_INTRO.MES` files contain
character/event-specific positive and negative effects instead.

No `D_OUTRO.MES` `+1` site is enclosed by a `state_u16` date condition, and
`D_OUTRO.MES` neither reads the ordinary-topic cycle gate nor writes a
once-per-day completion flag. `MACHI.MES:0x864E` selects `12C.MES` through the
location-command dispatcher, and `12C.MES` calls the farewell without a local
date guard. Therefore the original location of the basic gain is confirmed as
the farewell phase, but a global “only the first encounter of the day” rule is
**not implemented by TALK or OUTRO themselves**. Any such limit must be
confirmed in the wider encounter scheduler or represented explicitly in the
remake encounter state.

## Menu Entry and Dispatch

The eight `D_TALK*.MES` entries share the same offsets for the entry-point
scaffold:

| Role | Offset | Direct evidence |
|---|---:|---|
| numeric visibility guard | `0x0262` | `global_u8[686] == 0` |
| associated `command_10` | `0x026D` | command immediately before label |
| exact menu label | `0x0276` | decoded CP932 text equality |
| selected-choice dispatch | `0x05B5` | `state_u16[21] == 1` |
| normal-conversation fallthrough | `0x05BF` | true successor of dispatch |

The role of `global_u8[686]` is **Projected** as visibility for this choice
from its placement and repeated scaffold. Its broader gameplay name is still
**Unresolved**.

The normal-conversation body's false-edge boundary differs by affection band,
because the bodies have different sizes:

| Entry | End of normal-conversation dispatch span |
|---|---:|
| `D_TALK30.MES` | `0x5AFF` |
| `D_TALK40.MES` | `0x5C19` |
| `D_TALK50.MES` | `0x7599` |
| `D_TALK60.MES` | `0x8046` |
| `D_TALK70.MES` | `0x967A` |
| `D_TALK80.MES` | `0xB0D6` |
| `D_TALK90.MES` | `0xAF62` |
| `D_TALK00.MES` | `0xBA6C` |

These bounds identify the selection-dispatch span. They do not by themselves
prove that every nested block is reachable from the normal-conversation
fallthrough.

## Conversation Exit and Menu Return

Command `0x0C` carries a little-endian four-byte code-relative continuation
target at the TALK sites examined here. It resumes execution at that target
rather than falling through linearly. The shared format evidence is recorded
in [Format and Method](format_and_method.md).

In `D_TALK00.MES`, the normal-conversation branches converge on `0xBA5D`,
whose continuation target is `0xF6FC`. The other selectable conversation
commands converge on `0xBA67`, whose target is `0xF6F7`; `0xF6F7` then
continues to the menu scaffold at `0x024C`. `0xF6FC` contains only the script
end sequence.

Therefore selecting the normal-conversation command ends the TALK script, while the other
selectable commands return to the conversation menu. This control-flow
distinction is **Confirmed** for `D_TALK00.MES` and agrees with the repeated
TALK-script structure. It does not imply that a caller cannot start a new
encounter later on the same game day.

## Source-Order Priority in `D_TALK00.MES`

The top-band body begins with the following source order:

| Order | Condition offset | Numeric condition | Observed transition |
|---:|---:|---|---|
| 1 | `0x05D3` | `global_u8[227] == 2` and `global_u8[690] == 0` | writes `global_u8[690] = 1` at `0x0824` |
| 2 | `0x0834` | `global_u8[227] == 2` and `global_u8[690] == 1` | writes `global_u8[690] = 2` at `0x09BD` |
| 3 | `0x09CD` | `global_u8[227] == 1` | later clears `global_u8[227]` at `0x0EEA` |
| 4 | `0x0F30` | `global_u8[678] == 1` | clears `global_u8[678]` at `0x13F7` |
| 5 | `0x1407` | `global_u8[687] == 1` | clears `global_u8[687]` at `0x2104` |
| 6 | `0x2114` | `global_u8[225] == 1` and `global_u8[728] == 0` | post-date state transition |
| 7 | `0x241C` | `global_u8[225] == 1` and `global_u8[728] == 1` | post-date state transition |
| 8 | `0x26EF` | `global_u8[729] == 1` | writes `global_u8[729] = 2` |
| 9 | `0x28DE` | `banked_u16[0][242] == 13` | event reaction, including a direct `-5` affection path |
| 10--25 | `0x2B91` onward | topic counter `global_u8[691] == 0..13`, cycle gate `global_u8[688] == 0` | one fresh topic attempt |
| 26 | `0xA605` | `global_u8[688] == 1` | same-cycle generic conversation |
| 27--30 | `0xA81F` onward | parting-state combinations using `global_u8[226]` and `global_u8[684]` | ending presentation |

The source order and writes are **Confirmed**. The first two conditions are
the two reservation-anticipation variants described below. The `678`, `687`,
`225`, `729`, and banked-242 conditions are event or date aftermath paths by
their local state transitions and dialogue context, but their complete
cross-script symbolic names remain **Projected**.

Notably, the original top-band source order checks reservation anticipation
before the `678` and `687` event-follow-up branches. This differs from the
remake priority chosen in the current design discussion. It is still
**Unresolved** whether those states can coexist at this caller, so source
order alone is not enough to prove a player-visible conflict.

## Persistent Topic Progress and Conversation-Cycle Gate

Ten character prefixes have the same two-variable pattern in their TALK
scripts: a persistent topic counter with values `0..13`, and a separate gate
that prevents a second fresh topic within the current `DEF_MAIN` reset cycle.

| Prefix | Affection index | Cycle gate | Topic counter |
|---|---:|---:|---:|
| A | 201 | 1004 | 1006 |
| B | 210 | 601 | 548 |
| C | 206 | 1663 | 1665 |
| D | 212 | 688 | 691 |
| E | 202 | 1802 | 1804 |
| F | 200 | 1514 | 1516 |
| G | 204 | 1375 | 1377 |
| I | 203 | 1229 | 1231 |
| J | 211 | 796 | 798 |
| L | 209 | 1935 | 1937 |

For these ten prefixes, counter values `0..12` identify progressing topics.
When the current affection-band script does not unlock the pending topic, the
script sets the cycle gate but does not advance the counter. The same topic is
therefore tried again after the next reset cycle. Counter value `13` is a
terminal, repeatable fresh-cycle fallback: it sets the cycle gate without
advancing the counter. If the gate is already `1`, a separate same-cycle
generic branch is used. These state transitions are **Confirmed**.

`H_TALK*.MES` and `K_TALK*.MES` do not contain an analogous `0..13`
topic-counter/cycle-gate sequence. They do contain the reservation-anticipation
paths described below. Their ordinary-topic model remains **Unresolved** and
must not be forced into the ten-prefix schema.

### Maki (`D_TALK*.MES`) topic unlocks

The persistent Maki topic counter is `global_u8[691]`; the cycle gate is
`global_u8[688]`.

| Topic value | First band that advances it | Affection writes in the progressing topic |
|---:|---|---|
| 0 | `D_TALK50` | possible `-5`, `-3`, or `+2` response |
| 1 | `D_TALK50` | none observed |
| 2--3 | `D_TALK60` | topic 2: possible `-2` or `+3`; topic 3: possible `+1` or `+2` |
| 4--6 | `D_TALK70` | topic 4: possible `-5`; topics 5--6: none observed |
| 7--9 | `D_TALK80` | topic 8: possible `-5`, `-3`, or `+3`; topic 9: possible `-5` or `+5` |
| 10--11 | `D_TALK90` | none observed |
| 12 | `D_TALK00` | possible `+1`, `+2`, or `+5` response |
| 13 | never advances | terminal repeatable fallback; no affection write |

The unlock bands, counter writes, and affection writes are
**Confirmed**. The wording “response” describes a branch-local selectable or
conditional outcome; it is not an unconditional reward for entering normal
conversation.

The same-cycle generic branch at `D_TALK00.MES:0xA605` contains an additional
subdialogue guarded by `global_u8[724] == 0` at `0xA6C6`. It writes
`global_u8[724] = 1` at `0xA7B7`. This flag is also used in `D_TALK90.MES`, and
no reset site was found elsewhere in the audited MES archive. The numeric
guard/write and absence of an MES reset are **Confirmed**. Persistence across
save/load or a native-host reset remains **Unresolved**, so the broader
"persistent one-time" gameplay label is only a hypothesis.

## Reservation-Anticipation Conversation

Every one of the 96 `*_TALK*.MES` entries has two branches for an active date
state (`date state == 2`) and an anticipation-progress value of `0` or `1`.
The first conversation writes progress `1`. In 94 of the 96 scripts, the
second writes progress `2`.

The offsets below are the representative top-band `TALK00` sites:

| Prefix | Date-state flag | Anticipation progress | First/second condition offsets |
|---|---:|---:|---|
| A | 117 | 1005 | `0x0582` / `0x07B8` |
| B | 207 | 547 | `0x07DB` / `0x0994` |
| C | 167 | 1664 | `0x0595` / `0x0857` |
| D | 227 | 690 | `0x05D3` / `0x0834` |
| E | 127 | 1803 | `0x0573` / `0x080E` |
| F | 107 | 1515 | `0x058C` / `0x0B93` |
| G | 147 | 1376 | `0x0585` / `0x0771` |
| H | 177 | 2094 | `0x058C` / `0x0A41` |
| I | 137 | 1230 | `0x058D` / `0x076F` |
| J | 217 | 797 | `0x0595` / `0x0880` |
| K | 187 | 2195 | `0x0585` / `0x07DF` |
| L | 197 | 1936 | `0x058C` / `0x089C` |

Both anticipation variants end the normal-conversation path. Where an
ordinary-topic cycle gate exists, they do not set it. None of the 192
anticipation branches contains an affection write. Thus anticipation
progress and ordinary-topic progress are independent in the original data.
The branch structure and absence of affection changes are
**Confirmed** across all 12 prefixes and all eight affection bands.

`I_TALK30.MES:0x0901` and `I_TALK40.MES:0x0901` are the two progress-write
exceptions: their second anticipation branch leaves `global_u8[1230] == 1`
instead of writing `2`. The second variant can consequently be selected again
within that reset cycle. This is recorded as a **Confirmed original-script
exception**, not normalized away as an assumed typo.

## Reset Boundary

`DEF_MAIN.MES` resets the ten ordinary-topic cycle gates to zero. Representative
and complete reset offsets are: B `0x0611`, D `0x06CE`, J `0x0708`, A
`0x07CE`, I `0x07F2`, G `0x0838`, F `0x088E`, C `0x08D4`, E `0x0926`, and L
`0x0966`. It does not reset the corresponding persistent topic counters.

The same script resets all 12 anticipation-progress flags: B `0x060B`, D
`0x06D4`, J `0x076C`, A `0x0772`, I `0x080E`, G `0x084E`, F `0x0894`, C
`0x08DA`, E `0x092C`, L `0x096C`, H `0x09D4`, and K `0x0A14`.

These reset writes are guarded by `state_u16[2] != 0` and
`global_u8[534] == 0`. `START.MES:0x014C` executes `LIBLARY.LIB` through
presentation subcommand 8 selector 2, then `START.MES:0x0165` executes
`DEF_MAIN.MES` through selector 3. Executable audit v21 confirms the ARC load,
temporary stream install, synchronous execution, context restore, and the
owning native script-manager lifetime of command-`0x14` registrations. The
exact later invocation cadence of the default-main script has not yet been
traced. Calling this a daily reset is
therefore only **Projected**. The
confirmed rule is narrower: the gates reset on a qualifying `DEF_MAIN.MES`
execution, while topic counters persist.

## Affection Effects Are Branch-Authored

Within the normal-conversation dispatch spans, the corpus contains command
`0x07` assignments of the form
`banked_u16[0][character_affection] = banked_u16[0][character_affection] + or - integer`.
For Maki, the destination is the confirmed affection index 212. Representative
top-band positive writes include `+1` at `D_TALK00.MES:0x509A` and
`D_TALK00.MES:0xA3FD`; other branches and bands contain different positive and
negative magnitudes.

Native opcode-table and vtable evidence confirms that `0x07` calls handler
`0x00418F50`, which writes the same 16-bit storage read by expression token
`0xA0`. The next slot, command `0x08`, calls the dword handler at `0x00419020`
and corresponds to token `0xF9`. These sites are therefore immediate direct
affection writes; no later commit is required.

There is no shared unconditional affection assignment after
the normal-talk
selection inside the TALK body. Across all ten topic-counter characters, both
the terminal fresh-cycle fallback and the same-cycle generic branch have no
affection delta. Across all 12 characters and all 96 TALK scripts,
none of the 192 reservation-anticipation branches has such an affection
delta. Positive and negative assignments occur inside particular topic-response
branches instead. The separate basic `+1` found in the encounter corpus is
written directly later by `*_OUTRO.MES`, as described above.

Consequently the original evidence does **not** support “the ordinary-talk
choice itself adds affection” or “reservation anticipation adds affection.”
It does support a separate character-specific farewell gain. The exact
system-level daily limiter and the non-Maki cap rules remain outside the
confirmed scope of this pass.

## Random Encounter Prototype Consumption

The remake random-encounter prototype consumes only the confirmed Maki portion
of this result: the `D_OUTRO.MES` `+1` gain, its starting-value boundary, and the
observed suppression branch involving `global_u8[224]`. The authoritative archive
was re-audited with `inspect_encounter_affection.py`; all 24 `A`--`L`
`INTRO/OUTRO` outputs matched the existing audit byte-for-byte, including the 48
Maki `D_OUTRO.MES` direct-gain sites and its recorded SHA-256.

The fish-shop Maki prototype treats the schedule as guaranteed repeatable
presence rather than a random candidate. Candidate weights and a no-encounter
bucket apply only to separately authored random encounters. Completing a Maki
conversation may update conversation-cycle state, but it does not remove her
from a schedule that still passes. This runtime rule does not assign a newly
proven gameplay name to unresolved flags, and non-Maki gain caps remain excluded
until their caller contexts are traced.

The vertical-slice presentation preserves the confirmed `12C.MES` call order:
`D_PIC.MES` at `0x035E`, `D_INTRO.MES` at `0x0370`, the affection-banded TALK
call, and `D_OUTRO.MES` at `0x0637`. It composes the local `12C_2` background
with the local chroma-key `D` standing sheet and retains that resolved work
outfit through outro. The previous prototype-only `D1` outro swap was incorrect
and has been removed. The encounter table no longer owns authored phase text.
The supported affection-50 slice loads a Git-ignored projection generated
directly from authoritative `D_INTRO.MES`, `D_TALK50.MES`, and `D_OUTRO.MES`
CP932 records. The selected numeric trace, record offsets, and runtime boundary
are documented in [Encounter Dialogue Projection](encounter_dialogue_projection.md).

## Open Questions for the Next Pass

1. Trace the default-main invocation path far enough to prove or reject a
   once-per-game-day interpretation of the reset cycle.
2. Determine whether reservation anticipation and the event-follow-up flags
   can coexist, so source order can be converted into a player-visible
   priority rule.
3. Resolve the ordinary-topic state model for prefixes H and K.
4. Trace affection caps and any affection changes outside the TALK bodies.
5. Repeat caller analysis for prefixes A through L, including low-affection
   bypass/contempt paths and alternate encounter callers.

## Reproduction

The corpus inventory and entry-point offsets can be regenerated without
exporting dialogue text:

```powershell
py tools\inspect_normal_talk.py <ELFIMAGE\mes.arc> `
  -o analysis\mes_ir\normal_talk_analysis_v1.json
```

Primary evidence checked in this pass:

- `D_TALK00.MES`, SHA-256
  `856e19cefa928a7f1e57fd39cd017860434eced5fd4e81589918c9f2145f5090`;
- `D_INTRO.MES`, SHA-256
  `d2b20eb1d4343d98947b6c699ccc6d1e31ac41584d84a9cdcabe8b06b0a93337`;
- `D_OUTRO.MES`, SHA-256
  `7900463ea3eebecae1157bebbea637e0a2f4acacc6062242f73150e624f594c8`;
- `12C.MES`, SHA-256
  `c71563238cd4e14a06125b8cd139f7e6a304024dbd7c32ed5a3619ca425726eb`;
- `DEF_MAIN.MES`, SHA-256
  `f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0`;
- `START.MES`, SHA-256
  `ba57bf666fbd9db9b3110f2bf1c70e80e11a35de00e82256aaaf35921c77038f`;
- exact-label corpus `A_TALK*.MES` through `L_TALK*.MES`, recorded in the
  Git-ignored analysis artifact with per-entry hashes.
- encounter boundary corpus `A_INTRO.MES`--`L_INTRO.MES` and
  `A_OUTRO.MES`--`L_OUTRO.MES`, recorded in the Git-ignored affection audit.
