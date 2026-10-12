# Station background selection: routine 27, selector 11

## Scope and confidence

Content Core `0.277.0` adds a **read-only selection plan** for the original
`LIBLARY.LIB` routine 27 selector 11. It records which original station MMO is
selected, the explicit rectangle-copy operands, and the following routine 8
call boundary. It does not execute the load, copy, routine 8, or the native
records after that call. This is a bounded prerequisite for later date/time
work, not general event playback or original-engine presentation parity.

Evidence type: direct authoritative `mes.arc`/`mmo.arc` reads using current
GDScript container/decoder/codec, isolated evaluation of the decoded branch
ASTs, and read-only original-EXE instruction/hash cross-checks. Confidence is
**Confirmed** for the bounded record selection and operands below. Native
cadence, refresh/lifetime, complete pixel composition, calendar validity and
event eligibility remain **Unqualified / unresolved**.

The existing four EVENTB03 presets still require weekday `6`, date word `413`
and time word `1825`. This plan does not qualify a new date/time preset. B_PIC
date-dependent standing selection, shared-routine weekday/time effects and
MACHI terminal projection require separate route audits before that scope can
expand. See [character event evidence](character_events.md) and the live
[Event Player tracker](../../../todo/event_player.md).

## Authoritative identities and anchors

All MES offsets in this document are code-relative half-open `[start,end)`
intervals, not container/file offsets. Original paths stay in
`.agents/local/source_paths.md`; no original payload or decoded image is added
to Git.

| Source | SHA-256 |
|---|---|
| `mes.arc` | `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6` |
| `LIBLARY.LIB` entry | `d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d` |
| Original EXE wrapper | `3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5` |
| Embedded runtime at wrapper `0x1B000` | `5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da` |

The existing caller proof is `01M.MES:0x01D1..0x01E3`; the EVENTB03 tail repeats
the selector-11 setup at `EVENTB03.MES:0x3715..0x3727`. Both write banked
surface selector 1 and argument 1 = 11 before calling routine 27. The plan
starts at the already-qualified selector guard `LIBLARY.LIB:0x3B3C`, not at an
arbitrary resource marker. It stages `global_i32[1]=11` in an isolated sandbox
for guard evaluation; it does not simulate the live argument/caller frame.

The source selector block is `0x3B3C..0x40C0`. Its first guard
`0x3B3C..0x3B47` requires `global_i32[1] == 11`; its false target is `0x40C0`,
outside the qualified selector. The full library-entry hash remains mandatory,
including bytes that this plan deliberately does not interpret.

## Source date/time decision tree

Let `D = state_u16[7]` and `T = state_u16[19]`. Names `mmdd` and `hhmm` retain
the existing calendar-state convention, but this helper accepts numeric words,
not a calendar-validity or clock-validity proof. In particular `0` and `65535`
are useful structural tests, not claimed playable dates or times.

| Date guard interval | Exact decoded predicate | True family | False target |
|---|---|---|---|
| `0x3B47..0x3B61` | `D < 616 OR (D > 915 AND D < 1116)` | `01MA` | `0x3D21` |
| `0x3D21..0x3D34` | `D > 615 AND D < 916` | `01MS` | `0x3EF4` |
| `0x3EF4..0x3F00` | `D > 1115` | `01MM` | `0x40BB` |

The parentheses are decoded AST structure, not inferred operator precedence.
The earlier guard has priority. Thus date words `615/616`, `915/916` and
`1115/1116` switch families exactly at those boundaries. The three families
cover every unsigned-word input; no real calendar interpretation is needed
to establish that numeric property. Family letters are resource identifiers,
not independently established season names.

Each family tests `T < 600`, then `T < 1600`, then `T < 1800`. The selected
suffix is respectively `_3`, `_1`, `_2`, or `_3` for the final else arm. There
are therefore twelve distinct source load arms but nine distinct MMO assets.

| Family | `<600` guard | `<1600` guard | `<1800` guard |
|---|---|---|---|
| `01MA` | `0x3B61..0x3B6D` | `0x3BD4..0x3BE0` | `0x3C47..0x3C53` |
| `01MS` | `0x3D34..0x3D40` | `0x3DA7..0x3DB3` | `0x3E1A..0x3E26` |
| `01MM` | `0x3F00..0x3F0C` | `0x3F73..0x3F7F` | `0x3FE6..0x3FF2` |

## Load/copy witnesses and stop boundary

| Selected MMO / time arm | MMO marker | Mode-1 copy | Routine-8 boundary |
|---|---|---|---|
| `01MA_3`, `T<600` | `0x3B75..0x3B84` | `0x3B8B..0x3BAE` | `0x3BAE..0x3BB3` |
| `01MA_1`, `600<=T<1600` | `0x3BE8..0x3BF7` | `0x3BFE..0x3C21` | `0x3C21..0x3C26` |
| `01MA_2`, `1600<=T<1800` | `0x3C5B..0x3C6A` | `0x3C71..0x3C94` | `0x3C94..0x3C99` |
| `01MA_3`, `T>=1800` | `0x3CC2..0x3CD1` | `0x3CD8..0x3CFB` | `0x3CFB..0x3D00` |
| `01MS_3`, `T<600` | `0x3D48..0x3D57` | `0x3D5E..0x3D81` | `0x3D81..0x3D86` |
| `01MS_1`, `600<=T<1600` | `0x3DBB..0x3DCA` | `0x3DD1..0x3DF4` | `0x3DF4..0x3DF9` |
| `01MS_2`, `1600<=T<1800` | `0x3E2E..0x3E3D` | `0x3E44..0x3E67` | `0x3E67..0x3E6C` |
| `01MS_3`, `T>=1800` | `0x3E95..0x3EA4` | `0x3EAB..0x3ECE` | `0x3ECE..0x3ED3` |
| `01MM_3`, `T<600` | `0x3F14..0x3F23` | `0x3F2A..0x3F4D` | `0x3F4D..0x3F52` |
| `01MM_1`, `600<=T<1600` | `0x3F87..0x3F96` | `0x3F9D..0x3FC0` | `0x3FC0..0x3FC5` |
| `01MM_2`, `1600<=T<1800` | `0x3FFA..0x4009` | `0x4010..0x4033` | `0x4033..0x4038` |
| `01MM_3`, `T>=1800` | `0x4061..0x4070` | `0x4077..0x409A` | `0x409A..0x409F` |

For every marker starting at `M`, `M-8..M-1` writes
`banked_u16[0][1]=2`; the MMO outer command is at `M-1`. The marker occupies
`M..M+15`, followed by the active-surface write `banked_u16[0][1]=7` at
`M+15..M+22`. The source copy operands are exactly
`[1,0,0,639,399,2,0,0,1]`: mode 1, inclusive source endpoints `(0,0)..(639,399)`,
source surface 2, destination `(0,0)` on surface 1. The plan's
`source_rect=[0,0,640,400]` is **x/y/width/height**, not endpoint notation.
Active surface 7 does not replace either explicit copy surface.

The routine-8 record is decoded only to verify its call target and boundary.
The plan stops **before executing that call**. It neither follows routine 8
nor decodes or skips the native envelope immediately after it. For captured
`413/1825`, this is the call `0x3CFB..0x3D00`, with the following native record
beginning at `0x3D00` outside the plan's interpretation. Other arms have the
same explicit copy/call contract; equivalent native follow-up behavior is
**not** claimed.

## Native cross-check and limitations

The original embedded EXE was re-read, never run or patched. Existing
`audit_eventb03_station_native.py` confirms 26 MMO/copy byte/call facts against
central executable evidence `kakyu_ai5_mes_exe_audit/v317`.
`audit_mes_logical_truth.py` rechecks 42 E6/E7 facts: both operands are consumed,
truth is exactly `==1`, and results are normalized `0/1`. These guards feed
comparisons into their logical nodes; they do not rely on generic nonzero
truthiness.

Additional direct executable-window hash and instruction checks bound the
readers/comparisons used here; the EB/EC/EF windows are not represented as new
central-v317 dedicated checks:

| Native role / VA interval | Decisive instruction fact | SHA-256 |
|---|---|---|
| state-u16 token `0x80`, `0x40600E..0x406040` | `MOVZX` at `0x406026`, state base + `0x2084` + index*2 | `b566fbd744c3d4ccef9831b2fd270d04774558ed21b15ba9700fcbb298677172` |
| unsigned `<`, `0x406321..0x406349` | `CMP EAX,EBX` / `SBB` / `NEG` at `0x406331` produces `0/1` | `3a45bc56aac6b94199f9ac689c8703f76c4fab34c928b8e0a1dd307840740a4f` |
| unsigned `>`, `0x406349..0x406371` | `CMP EBX,EAX` / `SBB` / `NEG` at `0x406359` produces `0/1` | `c22c0870316fdc3ae98c807a8b06e6704bc338c9d8981ff3d4d5e2e5e0dabebe` |
| equality, `0x4063AE..0x4063D9` | zero ECX, compare, `SETZ CL` at `0x4063BE..0x4063C5` | `064ead155e7e26c8b55c4c382eaab8943f9ac775165c3a4e91479eeea6e1d070` |
| global-i32 token `0xF6`, `0x406071..0x4060BF` | load at `0x4060A6`, state base + `0x3000` + index*4 | `c581cb30789919eaee256f52c3687abb95c55287f7feebf3120fec333940de1c` |

The MMO adapter `0x42A640` / consumer `0x42A6A0` loads a named MMO through
`0x42A78C -> 0x425190`, using active surface state `+0x20BA` and single-name
default origin `(-1,-1)`. The subcommand-11 mode-1 copy consumer at
`0x42ACA5..0x42AD1B` uses the RGB key read at `0x42ACB2`, explicit surface
lookups and `0x42AD05 -> 0x4255D0`. This is separate from subcommand-10 mode 1.
The copy keeps destination pixels whose source RGB matches the key and uses
inclusive endpoints. The actual key value and existing destination-surface-1
contents are not established by this plan. Decoding the selected 640x400 MMO
therefore does not prove that a standalone opaque image is pixel-identical to
the original composed surface.

## Original MMO witnesses

All nine entries are directly decoded from authoritative `mmo.arc`, with
size `640x400`. Full entry hashes are pinned in the source validator:

| Entry | SHA-256 |
|---|---|
| `01MA_1.MMO` | `5227c6bacb4470b0de537fbed41c2c3c26485b0dc457b781c7bac6c55a66d168` |
| `01MA_2.MMO` | `5e9511f7b362e2bd4daf70a0ff35266f55f9b49b450005eab03943f3fd399515` |
| `01MA_3.MMO` | `a523cf5d07fb3987800bb50764e010781d6b996e2495d354d2aeb946048a2bef` |
| `01MS_1.MMO` | `8c900338563012f90f14b0fc19c62b5406f18aa922078fe451b29c4c820d2b16` |
| `01MS_2.MMO` | `a2ca53209ff624c6e7dada6b30f2da7ce8aebf923cf33940ea4ff9a3ea18bd07` |
| `01MS_3.MMO` | `8dac3d056f869abbadb4a4d6c75373e40e84656b11833a01326555e259f39890` |
| `01MM_1.MMO` | `bba7c18f0dd9261f68560d5db2a9e8c3ef0b2843c57a6f6449ec43b0ebb2547d` |
| `01MM_2.MMO` | `363b918b832ec98067497f90e1ff3237a6fb884a6360dcd017a557e792f31881` |
| `01MM_3.MMO` | `45a5e7c272997b13d9fdcb0e2509e93baec26f7897f1286f0e42b19ebb6c7b82` |

## Reproduction and acceptance boundary

Run `tools/content_suite/cli/validate_mes_station_background_plan.gd` headlessly
with the configured ELFIMAGE directory as its single argument. It reads the
original archives in place, exports no source data, and checks all six
`mes/mmo/data/bgm/se/voice.arc` hashes before and after the audit.

The matrix is `D={0,413,615,616,915,916,1115,1116,65535}` crossed with
`T={0,599,600,1559,1600,1759,1800,1825,65535}`: **81 input pairs**, reaching all
twelve load arms and nine assets. Independent expected ASTs, false targets,
selected entry/offsets, active-surface writes, copy operands, stop boundaries
and complete plan metadata are asserted. Rebuild and JSON round-trip
validation must succeed; changed source payloads, changed proof fields,
fractional/string/bool/null inputs and out-of-word direct inputs must fail.
JSON integral numeric inputs are normalized only during plan validation;
direct `build` inputs remain strict integers.

Final source validation passed **1332 checks**, including all 81 JSON
round-trips and nested proof-field numeric-type rejection. Original-EXE station
and logical audits passed **26** and **42** checks respectively; the five
additional reader/comparison window hashes and three short comparison
instruction shapes also matched. Six source archives and the original EXE
remained unchanged. The known local missing calendar-rules autoload warning is
separate from these headless source assertions.

The independent synthetic plan suite passed **241 checks**, covering bounded
record selection, malformed producers, source-hash rejection and JSON proof
comparison. Existing Event Player **996**, catalog **73**, instruction decoder
**205** and prior station-source **119** checks passed, together with **7**
validation-runner tests and the project parse. The original EVENTB03 controller
regression also retained its station/standing pixel oracle and MACHI terminal,
and now checks the attached source-selection proof without changing live state.

No original-engine UI capture, new date/time eligibility, new playback preset,
native pixels/audio/cadence, or user acceptance is claimed by this unit.
