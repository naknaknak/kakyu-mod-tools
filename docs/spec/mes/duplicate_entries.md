# Entries whose message records are byte-identical

Measured on 2026-09-10 against the configured original `mes.arc`, SHA256
`31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6`, together
with the tracked dispatch naming audit `config/event_catalog/dispatch_naming_v1.json`.

[Unreferenced Entries](unreferenced_entries.md) found that `EVENTL09.MES`
carries the same 53 message records as `EVENTL10.MES`. This document asks the
archive-wide form of that question: **which entries carry the same messages as
another entry, and what kind of relationship is each pair?**

## Method

`tools/audit_duplicate_entries.py` reduces every `.MES`/`.LIB` entry to the
SHA256 of the concatenated per-message record hashes, in source order, plus four
structural figures: entry size, typed record count, message record count and
voice-marker count. No message text is retained. Entries sharing a digest form a
group. The `SCENE_` and `EVENT` filename prefixes are then used **as an index**
to label each group's composition; the measured relation is the byte identity
of the message records, not the name.

| Figure | Value |
|---|---:|
| Entries with at least one message record | 954 |
| Distinct message digests | 903 |
| Digests shared by more than one entry | 49 |

## The replay gallery

365 entries are named `SCENE_<letter><nn>.MES`. The strict aligned decoder sees
**no** dispatch of any of them, which is why the corpus inventory counted them
among the 429 entries "never dispatched": all 365 are among the 418 entries the
naming audit names only after its opaque-tail scan. Each is named by exactly
one envelope, and every one of the 365 is a command-`0x0F` nested call, so the
caller resumes after the scene. The callers are exactly thirteen `*_M.MES`
entries, and each dispatches one letter's scenes and no other's:

| Menu | Letter | Scenes |
|---|:-:|---:|
| `MIKO_M.MES` | A | 30 |
| `MAHOKO_M.MES` | B | 26 |
| `NANA_M.MES` | C | 30 |
| `MAKI_M.MES` | D | 28 |
| `MIZUHO_M.MES` | E | 33 |
| `REIKO_M.MES` | F | 30 |
| `RYOKO_M.MES` | G | 26 |
| `MIYUKI_M.MES` | H | 30 |
| `MAYUMI_M.MES` | I | 33 |
| `MINATU_M.MES` | J | 25 |
| `AI_M.MES` | K | 25 |
| `SIZUKA_M.MES` | L | 33 |
| `TINA_M.MES` | M | 16 |

The menu names index the heroines; the letter-to-menu binding is the measured
part. This is the same letter family the `EVENT<letter>nn` entries use.

## The 49 groups

| Kind | Groups | Composition | Examples |
|---|---:|---|---|
| `gallery_copy_of_event` | 27 | one `EVENT*` entry plus one or two `SCENE_*` entries | `EVENTJ04` / `SCENE_J03`; `EVENTH16` / `SCENE_H10` + `SCENE_K07` |
| `gallery_copy_of_other` | 13 | one `?_END.MES` entry plus one `SCENE_*` entry | `I_END` / `SCENE_I24`, one per letter A-M |
| `gallery_internal` | 4 | `SCENE_*` entries only | `SCENE_H09` / `SCENE_K06` |
| `event_only` | 1 | `EVENT*` entries only | `EVENTL09` / `EVENTL10` |
| `non_gallery` | 4 | neither prefix | `G_TIME` / `I_TIME`, `B_TIME` / `D_TIME`, `I_TALK71` / `I_TALK81`, `C_TALK01` / `C_TALK81` |

### Gallery copies are the source with logic stripped

In the 40 gallery-copy groups the non-`SCENE_` member is the source and the
42 `SCENE_*` members are its copies. All 42 copies have no more typed records
and no more bytes than their source, and all 42 carry exactly the source's
voice-marker count. The copies therefore repeat the scene's messages and voice
with the event-specific records removed, which is what a replay gallery needs.

Every heroine's ending script (`A_END.MES` … `M_END.MES`) has a gallery copy,
and 27 of the 129 strictly decoded EVENT targets have one. Two of those
(`EVENTH16.MES`, `EVENTH17.MES`) have a copy in **both** the H and the K
gallery, and the four `gallery_internal` groups are also all H/K pairs
(`SCENE_H06`/`SCENE_K03`, `SCENE_H09`/`SCENE_K06`, `SCENE_H12`/`SCENE_K09`,
`SCENE_H13`/`SCENE_K10`): the Miyuki and Ai galleries share six scenes
byte-for-byte.

### The one stored build

`EVENTL09.MES` / `EVENTL10.MES` is the only group made of two `EVENT` entries
and the only group in which voice-marker counts differ (0 against 7). It is the
pre-voice build already classified in [Unreferenced Entries](unreferenced_entries.md).

### Shared scripts stored twice

The four `non_gallery` groups are pairs of large non-event scripts - two
`*_TIME` pairs of 684 and 644 messages and two `*_TALK` pairs of 556 and 477.
`G_TIME`/`I_TIME`, `B_TIME`/`D_TIME` and `C_TALK01`/`C_TALK81` are identical in
size and record count as well; `I_TALK71`/`I_TALK81` share every message but
differ by 1,696 bytes and 152 records. Nothing here says which member is
executed for which heroine; that is a question for their callers.

## EVENT entries with a twin

29 `EVENT*` entries share their messages with another entry: the 27 with a
gallery copy above, plus `EVENTL09.MES` and `EVENTL10.MES`. The full list, with
each twin, is the `event_twins` array of the tracked report.

## Evidence boundary

Confidence is **Confirmed** for every count and every structural figure above.

Identical message records are identical **content**, not a claim about which
entry the product treats as the owning route. In particular this document does
not file any `duplicate_route` classification: the route classification's
`duplicate_route` pool is defined by multiple intro sites, and whether a gallery
copy should be recorded there is a catalog-ownership decision that is still
open. The prefixes are an index, and a group kind says only how the group is
composed. The owner ruled on 2026-09-10 to leave that decision open and to
treat every shared-message group other than the pre-voice L09/L10 pair as a
replay route for planning purposes; that is a working presumption recorded in
`todo/event_player.md`, not a measurement made here.

## Re-measured under Core 0.316.0 (2026-09-13)

The gallery's 365 dispatch records sat in opaque tails when this was measured;
with command `0x0D` framed as one system call they are strict rows, so the
report's `gallery_dispatches_in_strict_decode` is 365 and the field that
counted gallery entries without a tail envelope is now
`gallery_entries_without_envelope`, still 0. The audit reads the naming
report's `gallery_envelopes` list instead of its (now empty) opaque-tail list;
the 13 menus, the 49 groups and every structural figure above reproduce.

## Reproduction

```powershell
py tools/audit_duplicate_entries.py <ELFIMAGE-directory>/mes.arc `
  --check config/event_catalog/duplicate_entries_v1.json
```

The tracked report is `config/event_catalog/duplicate_entries_v1.json`. The
audit fails closed if the entry, digest or group counts change, if the group
kinds change, if a gallery entry gains a strictly decoded dispatch or a
dispatch by any command other than `0x0F`, if the gallery-copy structure
claims above stop holding, if the EVENT twin counts change, or if the tracked
report does not reproduce. It runs in about 13 seconds and joins the headless
batch as `original duplicate archive entries` whenever `ELFIMAGE` is supplied.
