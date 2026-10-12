# Encounter Dialogue Projection

The random-encounter vertical slice reads dialogue exported from the configured
authoritative `ELFIMAGE/mes.arc`. Original text remains in a Git-ignored local
projection and is never copied into tracked specifications or gameplay tables.

The first supported projection is deliberately narrow: Maki at the fish shop,
starting affection 50, ordinary topic state zero, and deterministic selector
variant zero. It preserves the `12C.MES` phase calls and selected records but is
not a general MES interpreter.

All offsets below are hexadecimal and code-relative within the named archive
entry. Dialogue wording is intentionally omitted.

## Selected Trace

| Phase | Caller | Selected source path | Exported text records |
|---|---|---|---|
| intro | `12C.MES:0x0370` | `D_INTRO.MES`, fish-shop context `global_u8[226] == 0`; affection `< 51`; numeric selector `global_u8[682] == 0`; known-name branch `global_u8[402] == 1` | `0x6C07`, `0x6C2C`, `0x6C72`, `0x6C87` |
| talk | `12C.MES:0x040B` | `D_TALK50.MES`; topic `global_u8[691] == 0`; cycle gate `global_u8[688] == 0`; nested selector `global_u8[689] == 0` | `0x2F3A`, `0x2F4F`, `0x2FF1`, `0x304D`, `0x3062`, `0x30B6`, `0x313C`, `0x3151`, `0x318F` |
| outro | `12C.MES:0x0637` | `D_OUTRO.MES`, fish-shop context `global_u8[226] == 0`; affection `< 51`; numeric selector `global_u8[350] == 0` | `0x0AD1`, `0x0AE6`, `0x0B10`, `0x0B25` |

The caller offsets, numeric branch conditions, CP932 text instruction types, and
record offsets are **Confirmed** against the raw archive. The broader gameplay
names of selectors 350, 682, and 689 remain **Unresolved**. Calling their chosen
value "variant zero" is only a projection label.

## Local Export Contract

`tools/export_encounter_mes_dialogue.py` verifies the expected SHA-256 for all
three source entries and requires 100 percent decoder coverage. It then reads
the selected CP932 text instructions directly from the raw entries and writes:

`data/mes_dialogue/maki_fish_shop_affection_50.json`

The output uses `kakyu_mes_dialogue_projection/v1` and declares
`source_kind = authoritative_mes_arc_projection`. Each line contains:

- decoded `speaker` and `text`;
- original phase and `12C.MES` caller offsets;
- every contributing code-relative text-record offset;
- a SHA-256 of each contributing CP932 payload;
- `fidelity = verbatim_cp932_text_records`.

The runtime rejects missing files, a schema/source mismatch, empty phases,
non-verbatim fidelity, missing record evidence, or an affection/context mismatch.
No authored fallback dialogue is allowed for this vertical slice. A missing
projection leaves the prototype runnable and shows a generation diagnostic
without starting playback.

Original text, raw bytecode, archive paths, and lossless projections remain
local-only. The generated JSON is ignored by Git together with the rest of
`data/`.

## Supported Boundary

This trace demonstrates original-text ingestion and source evidence through
intro, talk, and outro. It does not yet emulate arbitrary flags, random draws,
choice input, every affection band, or MES-side state mutations. Extending the
prototype to another trace requires confirming its branch and adding an exporter
definition; implementing general playback requires a separate interpreter task.

## Reproduction

```powershell
py tools\export_encounter_mes_dialogue.py <ELFIMAGE\mes.arc>
```

Authoritative entries checked:

- `D_INTRO.MES`, SHA-256
  `d2b20eb1d4343d98947b6c699ccc6d1e31ac41584d84a9cdcabe8b06b0a93337`;
- `D_TALK50.MES`, SHA-256
  `8ad2ced46e2a43bac62999c564dcc981b1bfb71d31059fa85c899de23355e1bd`;
- `D_OUTRO.MES`, SHA-256
  `7900463ea3eebecae1157bebbea637e0a2f4acacc6062242f73150e624f594c8`.
