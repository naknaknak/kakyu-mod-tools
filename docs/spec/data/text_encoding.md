# Text Encoding of Event Script Text

Status: **rule set agreed by the owner, 2026-09-18.** One place for what three
contracts already assume: the playback package's string tables
(`kakyu_playback_package/v7`), the projected event definitions (v3 today, v4
by its [design](event_definition_v4_design.md)) and the authored-definition
contract that follows v4. The rules below describe what the data already
does; nothing in the repository had to change to satisfy them. The checks
they imply enter the validators with the v4 fixture set (v4 work unit 2).

## The rule in one line

Event script text is **UTF-8 Unicode text**. The original CP932 bytes identify
a line; they never produce it.

## Where text lives

| Artifact | Carries text? | Encoding |
|---|---|---|
| `text/<STEM>.json` of a playback package | yes: `strings`, one string per message record, with `encoding: "utf-8"` | UTF-8 JSON |
| A tracked event definition (`config/event_definitions/`) | no: `text_ref` (`entry`, `at`, `s`, `raw_sha256`) and `name_insert` entries only | - |
| A resolved event definition (local, never tracked) | yes: `text` beside each `text_ref`, and the readable `script` block | UTF-8 JSON |
| A MES text projection in a workspace overlay | yes: the mod's replacement of one original message, always `remake_only` and `utf8` | UTF-8 JSON |
| An authored definition (the contract after v4) | yes: the mod's own lines, inline | UTF-8 JSON |

`raw_sha256` is the SHA-256 of the original message's CP932 bytes and the
retained `source_hex` is those bytes. They bind a string to the original line
it came from and are compared, never decoded again, by a consumer. Playback
text is never produced by encoding authored text to CP932
([Workspace Playback Export](workspace_playback_export.md)); writing text back
for the original engine is a separate, `original_engine_unverified` path with
its own CP932 length rules (`kakyu_mes_text_output_policy/v1`) and no part of
this document.

## From CP932 to Unicode

The producer decodes with the repository's own table,
`content_core/tables/cp932_decode.bin` (`KakyuCp932Codec`), not with the
operating system or the engine. Measured on 2026-09-18: all 9,604 double-byte
pairs the table defines agree with Microsoft code page 932, bytes `0x00..0x7F`
pass through as ASCII (`0x5C` stays the backslash and `0x7E` the tilde, not
the yen sign and the overline), and the 63 half-width
katakana bytes are defined. The mappings on which JIS and Microsoft tables
differ are therefore fixed as Microsoft's, and a consumer must not
"correct" them:

| CP932 bytes | Unicode | Not |
|---|---|---|
| `81 60` | U+FF5E FULLWIDTH TILDE | U+301C WAVE DASH |
| `81 7C` | U+FF0D FULLWIDTH HYPHEN-MINUS | U+2212 MINUS SIGN |
| `81 5C` | U+2015 HORIZONTAL BAR | U+2014 EM DASH |
| `81 61` | U+2225 PARALLEL TO | U+2016 DOUBLE VERTICAL LINE |
| `81 91`, `81 92`, `81 CA` | U+FFE0, U+FFE1, U+FFE2 | U+00A2, U+00A3, U+00AC |

Of these only U+FF5E (24 times) and U+FF0D (11 times) occur in the full
package. An undefined byte or pair fails the decode; nothing is replaced by
U+FFFD.

## The form of a string

Measured over the full package (228 tables, 24,590 strings, longest 78
characters): no byte-order mark, no carriage return, no string that NFC
would change, no control character, no private-use character, no U+FFFD, no
character outside the Basic Multilingual Plane, and no `{` or `}`. The rules
make that the contract:

1. Files are UTF-8 without a byte-order mark, with LF line endings.
2. Strings are in Unicode Normalization Form C. A producer normalizes; a
   validator refuses a string NFC would change.
3. A string holds no NUL, no C0 or C1 control character, no U+007F, no
   U+FEFF, no U+FFFD, no noncharacter, no unpaired surrogate and no
   private-use character (a private-use character has no meaning outside one
   font).
4. A projected string is exactly one original message and holds no line
   break: where a line breaks on screen is the player's layout, not the
   text's.
5. The protagonist's name is never inside a projected string. It is its own
   `name_insert` entry, resolved from the playthrough; the resolved
   document's `script` block shows it as `{name}` for reading only.
6. Half-width katakana and full-width Latin forms are kept as decoded; no
   width folding. A consumer that wants folded text does it at display time.

## Authored text

The same six rules apply to the lines a mod writes itself, with two
differences that the authored-definition contract will fix in its own
fixtures: an authored string may contain U+000A as an explicit line break
(and no other control character), and the placeholder that stands for the
protagonist's name is that contract's to define - projected text contains no
brace, so `{name}` is free for it. Authored text is not limited to what CP932
can represent: it is never encoded back.

## Checks this implies

- Package export and the definition producer: decode through
  `KakyuCp932Codec` only; write UTF-8 without BOM; refuse a string that
  breaks rules 2 to 4.
- `tools/validate_event_definition.py` with a package: every resolved string
  satisfies rules 2 to 4; a tracked document still carries no text at all.
- `tests/test_event_definitions_tracked.py` already refuses text and
  non-Latin strings in tracked documents; it keeps that role.
