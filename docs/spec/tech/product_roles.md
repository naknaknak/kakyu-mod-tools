# Product roles: the analyzer, its instruments, and the mod player

This document fixes what this repository is for, what it produces, and which of
its parts are bound to the Godot engine. It is a decision record, taken by the
owner on 2026-09-05. It follows from
[Stance Toward the Original Game](original_source_stance.md) and narrows the
role this repository was given by the modding tools repository split plan, which
is recorded in `kakyu-remake/docs/spec/tech/modtools_split_plan.md`.

Product scope stays in [Content Suite Product Goals](content_suite_product_goals.md)
and [Event Player Product Goal](event_player.md); this document reclassifies what
those two are *for* without restating what they contain. Ordered work stays in
the repository-root [TODO](../../../TODO.md).

## The decision

There are **three roles**, not two products sharing one repository.

| Role | Where | Engine |
|---|---|---|
| **The original analyzer** | this repository | target: none |
| **The original ARC/MES player** | this repository | Godot, permanently |
| **The mod player** | `kakyu-remake` | Godot |

1. **The original analyzer** reads user-owned original archives, establishes
   what the original does, records the evidence, and authors changed content
   from it. This is the repository's product.

2. **The original ARC/MES player is an instrument of that analysis**, not a
   product. It exists because executing an entry is how a claim about it gets
   checked. It is produced *by* the analysis process, it serves the analysis,
   and it is finished when the analysis it supports is finished. It is not a
   runtime anyone ships and it is not the thing that plays mods.

3. **The mod player is `kakyu-remake`.** It consumes the playback package this
   repository exports. It is out of scope here except as the consumer of that
   output, and it is maintained separately.

### What this withdraws

The split plan said of `tools/content_suite/apps/event_player.gd`:

> Its analysis half belongs to A and its playback half becomes B's game runtime.

**That expectation is withdrawn.** The playback half does not become the mod
player. The mod player is built on the playback package, from records, and never
reads an original entry — which is already structurally true in the remake,
because the code to read one is absent there. An interpreter of original
bytecode therefore cannot grow into it; the two consume different inputs by
design.

This makes `event_player.gd` cheaper to reason about, not more expensive. Its
size is still a problem, but its future is settled: it is an analysis instrument
that may be decomposed for the analyzer's convenience, and no product runtime is
waiting downstream of that decomposition.

**Revision 2026-09-20.** The owner set the instrument's own final form: a
minimal-presentation event player that plays every catalog site - text,
voice, BGM and still pictures through the one shared call frame, no
animation, no maps, menus, calendar or saves - so that a claim about any
route can be checked by a person watching it, not only by a validator
(`docs/spec/tech/event_player.md`, "Final deliverable target"). Roles 1 and
3 are unchanged: the analyzer is the product and the mod player is the
remake. Role 2 gains a floor, not a ceiling: the instrument is finished when
every site plays at that minimum, and it still ships to no one as a game.

## Event Player scope closed to originals, 2026-09-08

The owner fixes the current Event Player's final scope to **original-event
playback and analysis only**. This settles scope, not implementation completion:
the full original caller/branch/choice/terminal corpus still has to be analyzed
and verified. Original-derived MES, translated dialogue, replacement media,
added/removed mod events and mixed authored content are not Event Player targets.
Both Playback and Analysis obey this boundary; tool-seeded state experiments
over original bytes remain valid when their assumptions are labelled.

This supersedes the former equal-priority edited-content mode and contextual
edited-event Run requirements in the suite and Event Player goal documents.
The Core 0.302.0-0.306.0 edited-Run and derived-media UI paths were transition
debt until Core 0.321.0 (2026-09-15), when EP-08 removed them and made
every public Event Player entry point reject non-original content. The
compiler, editor previews, semantic proofs, headless authoring checks and
package exporter remain analyzer/authoring capabilities; shared helpers are
not removed merely because Event Player stops exposing them.

The separately maintained `kakyu-remake` remains the mod player and consumes
playback packages only. No work in that repository is scheduled by this decision.
An arbitrary mod event count does not enlarge Event Player's original corpus
or its definition of done. Full original-event analysis remains the priority.

## Consequence: Phase 1-4 authority moves to Python

The analyzer's target is no engine dependency. The container, record-framing and
IR authority is what makes that possible or impossible, so it moves.

**The destination was reversed on 2026-09-05.** At that decision,
`AGENTS.md` and `todo/mes_pipeline.md` kept the verified GDScript Content Core
as the Phase 1-4 authority and required Python to consume its language-neutral
handoff. The decision makes Python the authority once the corpus measurement
is re-established; GDScript analysis then consumes it or remains a verified
reference for the Godot instruments until those paths retire.

### Why this is feasible

Measured in this repository on 2026-09-05:

| Observation | Value |
|---|---:|
| `content_core` scripts that are plain `RefCounted` | 102 of 105 |
| `content_core` scripts that construct `Image` or `AudioStream` | 5 |
| `tools/content_suite` scripts that are actual GUI | 8 of 138 |
| `tools/content_suite` scripts that are headless `SceneTree` CLIs | 123 |
| `tools/*.py` with no Godot involvement at all | 111 of 122 |
| Python tools that read the authoritative archive directly | 36 |

The analysis core is not entangled with the engine. It holds no scene tree, no
nodes and no UI; its Godot dependency is almost entirely standard-library shaped
— `FileAccess` 185 uses, `HashingContext` 114, `ProjectSettings` 40, `JSON` 36 —
each of which has a direct Python equivalent. A Python path already exists and is
already load-bearing: `tools/mes_archive_ir.py` reads the archive and parses the
MES container itself, and 36 tools call it directly rather than consuming a
handoff.

### Why this is not a port

`MA-09` froze the Phase 1-4 completion report over 1,016 MES/LIB entries,
**with GDScript as the producer**. Its original instruction-v43 corpus handoff
fingerprint `2d182d27...b911807` is historical. On 2026-09-06 the owner approved
the current instruction-v45 baseline `fae349f9...eab6f5`; TD-15 verified it
over the complete archive and through the Python completion consumer. The baseline reconciles the
already documented v44/v45 corrections and does not change the producer.
Authority is that measurement, not the code that happens to compute
it. Moving the authority means re-establishing it on the Python side against the
same corpus, so the obligation is a re-verification with a recorded result, not a
translation exercise. The operating authority stayed with GDScript until that
measurement existed. The older Python basic-block projection must still not
override newer record framing — changing the destination or the authority does
not make that projection current.

**The initial distance was measured** (TD-12, 2026-09-05). Comparing the two decoders
on the authoritative archive over 2,386,774 records: Python reproduces the whole
framing of **0 of 1,016 entries**, and frames **58.2%** of individual records
identically. Sequentially, 1,015 entries stop at command `0x1B`. By volume the
gap is elsewhere — eight command grammars cover 95.6% of the disagreeing
records, and thirteen cover all of them. The sequential blocker and the volume
blockers are different commands, which is why the audit reports both.

The owner initially separated the destination decision from its implementation.
MA-10 records the subsequent implementation and its measurements.

### Authority re-established, 2026-09-06

**Python is now the Phase 1-4 container, framing and typed/opaque IR
authority.** MA-10 built and verified complete
`kakyu_mes_analyzer_handoff/v1` payloads from all 1,016 authoritative MES/LIB
entries. The full-payload audit passed `--require-full-equivalent`, including
all nine component targets, source identity and every ordered payload hash.

Actual payloads identify `python_phase1_4`; their ordered corpus fingerprint is
`3eb9afe776657b120346ca880608e95b069ceb9e2ced3d5d97b803b80b3628f9`.
The producer name is signed data. The explicit
`producer_implementation_only/v1` policy therefore verifies the actual payload,
changes only `producer.implementation` in a separate comparison object and
recomputes its hash. Every projected payload agrees with the frozen GDScript
producer, and its corpus fingerprint is the unchanged approved v45 value
`fae349f9affbaf244f44fe61f3afc380cb980f058950fe85fcb1f7d097eab6f5`.
Actual and projected fingerprints are separate results; exported Python
payloads retain their real producer identity. The full report is
`analysis/ma10-full-handoff-equivalence.json`; reproduction and transport
evidence are recorded in [Format and Method](../mes/format_and_method.md).

This fulfills the measurement condition for the operating rule. It does not
claim that all 35 GDScript analysis files or every Godot CLI have been removed.
The existing GDScript completion-v1 audit retains the approved baseline as a
reference check. Godot instruments, runtime validators and CFG-spool exporters
remain available. Python retains and validates supplied CFG/call/trace evidence;
the corpus baseline has empty attachment arrays, and nonempty attachments are
covered by independent authored oracles and focused original-entry comparisons.
The existing Python consumer and Phase 5 lifter accept actual Python handoffs.
The older basic-block projection remains supporting evidence rather than an
alternate current authority.

## What targets engine-freedom, and what does not

`content_core`, classified by role and measured on 2026-09-05:

| Role | Files | Lines | Under this decision |
|---|---:|---:|---|
| analysis | 35 | 10,244 | **moves to Python** with the authority |
| authoring | 31 | 13,127 | open — see below |
| execution (the instrument) | 12 | 5,951 | **keeps Godot**; it is the instrument |
| presentation / audio | 12 | 2,670 | **serves the instrument here**; corrected below |
| workspace / content | 10 | 3,027 | open — see below |
| codec | 5 | 1,139 | decode moves; producing `Image`/`AudioStream` does not |

**Correction, 2026-09-05.** An earlier revision of this table said the
presentation and audio modules "belong to the player role". Measured, they do
not leave: `logical_surface_compositor.gd` and `a6_layout.gd` have four
consumers here each, `ax_playback_plan.gd` and `ax_tool_scheduler.gd` three,
`oversized_cg_camera.gd` and `event_audio_state.gd` two. Every one of those
consumers is the original ARC/MES player or a headless validator driving it.
They are dual-purpose: the mod player needs presentation, and so does the
instrument, because an instrument that cannot show what it decoded cannot be
checked by a person. They stay, and the remake keeps its own copies.

Measured on the same day, the analysis role is further from the engine than the
role table suggests. Of `content_core`'s 105 scripts only **five** touch a real
engine object at all — `content_service.gd`, `logical_surface_compositor.gd` and
the three codecs — and **none of the 35 analysis scripts is among them**. The
`Callable` parameters in `arc_reader.stream_entry` and
`mes_noop_corpus_reopen` are deliberate injection points with direct Python
equivalents, not engine coupling.

Three things keep Godot permanently and are not defects:

- the 8 GUI applications, which need a window;
- the original ARC/MES player, which is the instrument the engine hosts; and
- the code that turns decoded bytes into `Image` and `AudioStream`, which is
  presentation, not analysis. A codec has two halves and only the first is
  analysis: decoding MMO to pixels is analysis, handing back a `Texture2D` is
  not.

### Left open deliberately

- **Authoring.** 31 files and 13,127 lines produce changed MES and mod content.
  Authoring is not analysis and its consumer is the mod player, but the remake
  structurally cannot author — it cannot read an original entry — and authoring
  shares the analyzer's decode core. It stays in this repository; whether it
  targets engine-freedom with the analyzer or keeps Godot with the editors is not
  decided here.
- **Workspace and content resolution.** 10 files serving both the GUI apps and
  the headless tools. Its classification follows authoring's.
- **The 123 headless `SceneTree` validators.** They are GDScript wrappers around
  `content_core`. Whatever happens to their subject decides them, so they are a
  consequence of the migration rather than an input to it.

## What does not change

- The original remains a **specification, not an execution target**. Running an
  original entry is how analysis is checked, never a product gate. That the
  player is now named an instrument makes this sharper rather than weaker.
- The remake never reads an original ARC or MES entry, and everything it plays
  arrives through the playback package.
- The playback package schema stays the contract between the repositories, is
  checked fail-closed on both sides, and changes by version bump.
- This repository keeps producing the package and the evidence. Naming the mod
  player as the remake does not move that work.
