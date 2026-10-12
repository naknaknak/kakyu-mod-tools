# Presentation and Audio Runtime TODO

This tracker owns execution of confirmed visual, animation, input, and audio
effects. Analyzer classification is an input; actual native-equivalent pixels,
cadence, lifetime, and transport are product work here.

**This is the one tracker whose ownership straddles the repository split.**
The split plan (`kakyu-remake/docs/spec/tech/modtools_split_plan.md`) assigns
the playback modules — `ax_playback_plan.gd`, `ax_tool_scheduler.gd`,
`ax_surface_binding.gd`, `logical_surface_compositor.gd`, `oversized_cg_camera.gd`,
`event_audio_state.gd` and `a6_layout.gd` — to the remake, and all seven are
among the files copied to both repositories. Every open item below is currently
implemented and exercised through `tools/content_suite/apps/event_player.gd`, which
exists only here, so the work is done here and the remake consumes the result.
If the remake later builds its own runtime on the playback package, PR ownership
may move there; that is the sibling repository's decision, not work tracked here.
Until then the seven modules are ordinary files of this repository and the open
items below are this repository's to close.

## Implemented Baseline

- [x] Shared 640x400 logical-surface compositor with detached checkpoints,
  transactional batches, opaque copy, RGB-key copy, fill, and preview binding.
- [x] Shared deterministic AX tool scheduler used by Image Editor and confirmed
  EVENTB02/EVENTB14 paths; timing is explicitly tool-clock, not native cadence.
- [x] Source-bound AX playback plan and confirmed MMO-to-surface-8 bindings for
  representative EVENTB02/EVENTB14 routes.
- [x] Versioned event-audio state model distinguishes BGM start/retain/replace/
  stop and voice replace/queue/overlap policy at the pure-state layer.

## Open Work

**Deferred by stance, owner ruling 2026-09-17 (option 1 of three).** Every
open item below concerns the native-equivalent presentation, input and audio
transport of the original player, which the product roles define as an
instrument of analysis rather than a product runtime; mods run in the
remake. PR-01 and the rest of PR-02 need original-engine observation
(surface lifetime, graceful-stop/redraw overlap, host cadence, x87
intermediate pixels), PR-03 would add A6 input to a player that consumes no
A6 table today (the one hit-test lives in `content_core/a6_layout.gd` and the
image editor uses it), and PR-04's generalisation is gated on wider
regressions by its own bullet. They stay listed with their measured status
and are not scheduled; the step-7 sequence continues with WD-09, WD-07,
WD-01, WD-03/05/06/12. Reopening any of them is the owner's call.

**2026-09-20, the final deliverable target (`todo/event_player.md` EP-10):**
the owner set the player's final form as a minimal-presentation event
player - text, voice, BGM and still pictures, no animation. PR-02 and PR-03
stay deferred as above. PR-01 reopens only as far as stills need it (which
surface a background, a standing picture or a CG occupies at a line, and
that an oversized picture is shown whole); PR-04 only as the minimal state
machine (BGM start/retain/replace, one voice per line, sound effects
fire-and-forget). EVENTB03's camera, AX and background-matrix code is
deleted once the shared path plays B03 as stills; its measured records stay
in the docs as evidence.

- [ ] *(deferred by stance)* **PR-01 — Complete common logical-surface ownership and restoration.**
  - Resolve generic active/background/foreground roles, layer lifetime, caller
    checkpoint ownership, and restoration.
  - Identify and bind the producer/lifetime of EVENTB14 routine-21 surface 1;
    keep the current world-map frame labeled as a source-qualified projection.
  - Legacy: P3-01.
- [ ] *(deferred by stance)* **PR-02 — Generalize AX source and destination interpretation.**
  - Extend confirmed surface binding, crop, destination, loop, delay, and
    termination contracts beyond representative event adapters.
  - Resolve native source lifetime and cadence separately from structural plans.
  - [x] Audit EVENTB03's explicit primary-127 camera commands at
    `0x32F9`/`0x3316` against original MES/EXE and current GDScript boundaries:
    mode 7 is automatic round trip; mode 8 is interactive pan and restore.
    Keep rational sample projections distinct from native pixel/timing proof.
  - [x] Replace the legacy B05SS load-time pan with source-ordered mode-7/mode-8
    tool-clock execution: automatic round trip, manual input, bounded animated
    return before MES resumption, source-9 crops and post-camera AX rebind.
    Source guards and deterministic pixel/input regressions are automated;
    user-visible acceptance remains in MV-04.
  - [ ] Qualify native AX graceful-stop/redraw overlap, host cadence and x87
    intermediate pixels during camera control. The current source-only crop
    with paused AX is an explicit tool policy, not native lifetime proof.
  - Legacy: P3-02.
- [ ] *(deferred by stance)* **PR-03 — Share A6 first-match input behavior.**
  - Use one logical-coordinate ordered hit-test in editor and playback.
  - Legacy: P3-04.
- [ ] *(deferred by stance)* **PR-04 — Complete the common event audio state machine.**
  - Wire caller capture/restore and actual queued/overlapping playback while
    retaining effective-content identity and failure rollback.
  - [x] Restore EVENTB03 result-3 routine-9 SE requests, including the first
    blackout pair, with six source-bound occurrence receipts, original/effective
    audio identity checks, full headless WAV decoding, same-channel restart,
    and source-counter-derived tool waits. Keep BGM and other event sessions
    isolated; source writes and generic argument ABI changes are forbidden.
  - Generalize routine-9 argument/state alias handling and effect transport only
    after wider call/state regressions; the B03 projection is deliberately local.
    Native wait interruption and device timing remain separate follow-ups.
    The minimal fire-and-forget form for every row is EP-14's (`todo/event_player.md`);
    caller capture and restore, queues and overlap stay here.
  - Legacy: P3-05.

## Boundaries

- Native record framing and typed/opaque semantics belong to
  `mes_analyzer.md`.
- Event selection, catalogs, continuation, and terminal UX belong to
  `event_player.md`.
- Editor mutations and media writers belong to `media_editors.md`.
