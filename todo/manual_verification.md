# Manual Verification TODO

This tracker contains only checks that require user-controlled GUI, audio, or
original-engine interaction. Automated preparation, source hashing, and
headless validation must be complete and merged to `main` before a request is
made. Accumulate related checks into one meaningful batch.

No license-specific optional OS virtualization feature is part of the
verification options. Original-engine replacement checks use a disposable
local copy and remain user-launched so the original window cannot unexpectedly
take focus.

## Pending Batch

On 2026-09-03 the user deferred manual verification and requested continued
implementation. Keep these checks pending without treating them as accepted;
continue source audits, implementation and headless regression that do not
require their outcome. Do not re-request the same UI batch during this work.

### Batch of 2026-09-19 (WD-19)

Assembled 2026-09-19 after the whole-tree batch passed at Core 0.350.0 (WD-18)
and the six release apps were rebuilt at the same core: `analysis/windows-suite-0350-20260919/` (931 inventoried files, distribution fingerprint `fd9085a06370021e8e0ae89e0adb2b74d6d720918398de8df669911d1e1fc16e`, all six apps verified at `0.350.0.0`, built in 49 s from the pinned 2026-09-08 dependencies; the 264 files added since the 0.344.0 build are the v4 event definitions, the contract fixtures and the definition tools). It is one
run sheet over the open items below (MV-04, MV-05, MV-06, MV-09's remaining
controls, MV-11); the owner runs it at a time of their choosing and reports
per number. MV-01 through MV-03 stay deferred by stance and MV-07 is WD-20.

**Rebuilt 2026-09-24 at Core 0.362.0 for this same sheet:**
`analysis/windows-suite-0362-20260924/` (1,151 inventoried files,
distribution fingerprint
`f76591368d0661abac1492384eeee7b367c801f94ab335c4defb9577ca3225a6`, all six
apps verified from the pinned 2026-09-08 dependencies). It carries every
change since the 0.356.0 build of 2026-09-21: the H01/H02 and 15C endings,
EVENTM10's and EVENTM03's visit options, the catalog run-settings layout
(item 7), the still-picture rule and one step per spoken line (item 8).
The 0.356.0 build is superseded by it, and it is superseded by the build
below.

**Rebuilt 2026-10-11 at Core 0.378.0 for this same sheet:**
`analysis/windows-suite-0378-20261011/` (2,788 inventoried files,
distribution fingerprint
`0740e55ece8b65e842417af0c9d939e5c5d2459ecea46f67c6f3e37e4c05bd24`, all six
apps verified at `0.378.0.0` from the pinned 2026-09-08 dependencies; the
build command took 143.6 s). The release used a separately obtained Godot
4.7-stable editor with the 4.7-stable release templates. The file count
rose from 1,151 by 1,366 files under `runtime/config/event_definitions`
(the v6 and v7 sets), 181 under `runtime/config/contracts` (the v6 and v7
fixtures), 79 under `runtime/config/event_catalog` (78 more analysis groups
and the known-absent media register) and 11 Python tools under
`runtime/tools`; the executables and the Python runtime are the same in
number. It carries every change since the 0.362.0 build:

- EP-12: the date, hotel, promise, album, recollection and conversation
  scripts are catalog rows (681 rows at catalog revision 40; Core 0.363.0
  to 0.372.0).
- WD-21: the package's media inventory and each row's `resources` (catalog
  revision 41; Core 0.373.0).
- TD-57: voice, BGM and picture loads no longer re-hash a whole archive
  each time (Core 0.374.0).
- TD-64: the package reader and exporter use far less memory (Core 0.375.0
  and 0.376.0).
- TD-56: the shared library media ladders select by the caller's real
  selector (catalog revision 43; 1,093 library items restored to 293 rows;
  Core 0.377.0).
- WD-10: `tools/mod_bundle.py`, the portable mod bundle, ships in the
  runtime; no Launcher control exists for it yet (WD-24).
- EP-14: the library's place backgrounds and sound effects reach the
  Playback timeline (item 9; Core 0.378.0).

Run the sheet on this build; the 0.362.0 build is superseded.
Everything uses the user-owned ELFIMAGE content set with no overlay; nothing
below launches the original engine. Labels are the build's own.

1. **Launch and remembered paths (MV-06).** Start `ContentSuite.exe` from
   the build directory. Set **ELFIMAGE...** to the ELFIMAGE directory and a
   workspace directory, open **ARC Browser**, **MES Editor**, **Image ARC
   Editor**, **Audio ARC Editor** and **Event Player** from the launcher,
   close everything and start the launcher again: the ELFIMAGE path and the
   workspace directory come back. The five editors and the player open as
   separate windows and none needs a Python on PATH.
2. **Sizing and DPI (MV-06, the part WD-15 left to a monitor).** With the
   Windows display scale at 100%: an app cannot be dragged below 1024x640,
   fills 1920x1080 and 2560x1440 with no control cut off. Set the scale of
   one monitor to 125% or 150% (Settings > System > Display), start the
   launcher and two editors again: the editors reflow larger by the
   factor, the Event Player keeps its 1280x800 canvas. Set the scale back.
3. **Event Player display modes (MV-05, MV-06).** In the Event Player,
   **F11** and **Alt+Enter** switch between the window and borderless
   fullscreen; the choice is remembered on the next start. Windowed keeps
   16:10 with black bars; fullscreen stretches to the screen without
   keeping the aspect (the 2026-09-18 ruling). View mode **Playback** shows
   the 640x400 frame with no debug panel over it.
4. **B03 played the minimal way (MV-05; replaces the animation and camera
   items, superseded 2026-09-21).** View mode **Playback**, **Event Catalog...**,
   Mahoko at the station (EVENTB03), the default preset and **Result**
   option-3, **Play**. Confirm: the lines advance with click / Space / the
   arrow keys and show the original text and speaker; a line's voice plays
   with the line; the scene BGM starts on its selector and keeps playing
   across lines; the station interior stands behind the standing picture
   as a still and the large CG is shown whole, scaled to fit the frame, with
   no motion; no animation plays and no omission label appears; the ending
   reads "Back to the town map" in the terminal message and footer. Nothing
   covers the 640x400 frame. Compare at 1080p and 1440p.
5. **B03 results 1 and 2 through the Result selector and the guard form.**
   Change **Result** to option-1: the preset re-picks itself to one that
   measured that answer, Play reaches "Back to the town map" with result
   1's lines; option-2 the same. Then the guard form: with the archive
   open, set Mahoko's affection to 60 and the clock to 18:30; "Guard:
   passes"; switch **Use this state** on and Play: the status line says
   "tool-seeded state"; set the clock to 08:00: "Guard: fails" and the
   toggle disables. Selecting event B14 resets the preset and the result to
   that row's own; the selector is readable at the normal output
   resolution.
6. **Cross-session isolation.** Right after a B03 session, Play B14: no
   B03 picture, BGM or voice carries into it, the old sounds stop when the
   row changes, and rapid **Continue** presses do not break the flow.

7. **Catalog run settings fit the window (added 2026-09-24).** In
   **Event Catalog...**, select a row with a long starting-state form (for
   example EVENTI24 at 44C, seventeen guard cells) and one with visit
   presets (EVENTM10 at 44C site B, EVENTM03): the settings scroll, the
   **Play** and **Select MES source** buttons stay visible below them, and
   nothing is cut off at the window's minimum size, 1080p and 1440p. Needs
   a build at or after `0914968`.
8. **Stills and lines (EP-13, added 2026-09-24).** Play EVENTB03 (result
   3) again: at the scene CG lines (4, 17) the CG itself is shown, not the
   animation strip, and no green surround appears; at the station lines
   (39 on) the standing picture stands on the station background and stays
   when the background changes; a line with the protagonist's name reads
   as one line, `[<name>]line`, not three steps; stepping back restores the
   earlier picture. Then one dormitory row (EVENTM10 at 44C site B, a
   visit option) for the same checks.
9. **Library pictures and sound effects (EP-14, added 2026-10-11).** In
   **Playback**, **Event Catalog...**: type `eventb03` in the search box,
   select **Mahoko at the station (EVENTB03)** (the details show Event ID
   `original/eventb03/01m-0000788f`), keep the preset the catalog selects
   (`01m-b03-result1-baseline`) and **Play**. The library's place background
   `01ma_3.mmo` is loaded twice during the event. The validator places the
   two loads at its own steps 37 and 49, and the player's step counter may
   number them differently, so look for that background to appear as a
   base picture twice during the event; it is a plain background, not a
   standing picture or an animation strip. If you do not see it, report
   the Result you played, because the loads were measured on the default
   run only. Then type `a-date-date5` and select the row whose details show
   Event ID `original/a-date-date5/01m-00002af7` ("Miko at the station
   (A_PIC)"; two other rows share that title), keep its preset `a-date-date5-default`
   and **Play**: the place backgrounds its train and station scripts load
   (for example `01ca_1.mmo`) should appear as base pictures, and the sound
   effects they request (for example `KSE0067.WAV`) should be heard. Known
   limits, not defects: the player has one effect channel that every
   request restarts, so several effects requested in one step are heard as
   the last one; the original's screen-refresh timing is unresolved
   (PR-01), so a background may appear earlier than the original would
   redraw it; library items with no presented form (loader and dispatch
   strings) show nothing. Report a missing or wrong picture or sound by its
   resource name and the line it should belong to.

What the batch accepts is the tools' presentation only. Native cadence,
x87 pixel equivalence, AX overlap, other starting states and original-engine
timing are not acceptance claims of any number above.

MV-01 through MV-03 are **deferred by stance**, not open work. Mods target the
remake runtime, so original-engine execution is no longer a product gate. See
[Stance Toward the Original Game](../docs/spec/tech/original_source_stance.md).
Their implementations and labels are retained so a future audience change can
revive them.

- [ ] *(deferred by stance)* **MV-01 — DAT/PAL replacement display in the original engine.**
- [ ] *(deferred by stance)* **MV-02 — OGG replacement playback in the original engine.**
- [ ] *(deferred by stance)* **MV-03 — Equal-length CP932 MES candidate playback in the original engine.**
- [x] **MV-04 — Event Player shared AX placement and tool-clock cadence across representative routes.**
  Superseded 2026-09-21 (EP-10 unit 5): the player no longer plays AX animation,
  camera motion or source-timed effect cadence; every catalog row plays
  through the presentation timeline as stills with voice, BGM and sound
  effects. The checks below are historical; the minimal-spec check of B03 is
  item 4 of the batch above.
  - This validates tool presentation, not unresolved native cadence.
  - Current EVENTB03 batch: use the original content set without overlays,
    select Mahoko event B03 in Event Catalog and its
    `captured-result3-original` preset, and play from the beginning with result 3.
    Confirm that B03/B03A/B05SS show composed animation rather than source
    strips, the two later routine-23 effect cues are audible without replacing the scene BGM,
    and the terminal shows the night station map with the protagonist.
    Compare these observations at 1080p/1440p while retaining the 640x400 logical
    frame. Then start EVENTB14 and confirm no B03 animation or sound carries
    into the new session. Record visual/audible results separately from native
    timing equivalence, which remains unresolved.
  - The first-blackout SE listening check is accepted in MV-C07. Remaining
    cross-session checks cover BGM retention, rapid Continue during the short
    source-derived waits, and stopping old sounds when changing events.
    Nominal tool waits follow the source counters, not full WAV length;
    native device timing and input-interrupted waits remain unverified.
  - User reported two remaining defects: B05SS animation rectangles stayed
    fixed while the CG moved, and B_PIC standing dialogue retained the event CG
    instead of the station background. The source audit now distinguishes AX
    draws from camera source-9 copies. The prepared follow-up suppresses stale
    AX rectangles during camera ownership and resets the retained animation
    at the later native rebind. Check for stray fixed rectangles and correct
    animation after the camera sequence, then the station interior behind
    standing dialogue (not the later MACHI map).
  - Follow-up source correction: the user identified the terminal as Rising
    Mansion. The station is EVE/CCD preset 16, not preset 0. Check the station
    entrance and protagonist in the terminal frame, and the source-selected
    `01MA_3.MMO` interior behind B_PIC (superseding provisional `01MM_3.MMO`).
  - Camera follow-up, after automated checks and main integration: the large
    CG must initially remain still. Advancing the preceding dialogue starts
    the automatic out-and-back motion (nominal tool clock about 6.2 seconds),
    followed by manual inspection. Drag or use arrows to move; click/Space
    must not advance the dialogue. Enter or **Finish CG inspection** returns
    the crop to its origin, then resumes dialogue. A far-edge return takes
    about 2.6 seconds on the tool clock. During automatic/return motion,
    repeated input must not skip the stage. Esc releases focus without leaving
    a stuck drag. Confirm the resumed animation, station background and station
    map terminal in the same batch. Native cadence/x87 pixel equivalence and
    AX overlap remain unresolved and are not acceptance claims for this build.
- [ ] **MV-05 — Playback-view event flow without debug UI covering the 640x400 frame.**
- [ ] **MV-06 — Independent exported app launch, sizing, DPI, and remembered paths.**
- [x] **MV-07 — Portable package launch in a clean Windows environment.**
  Closed 2026-10-09 by owner ruling with WD-20, unverified: no clean-Windows launch was made or is
  claimed.
- [x] **MV-09 — EVENTB03 explicit numeric preset and result-2 route.**
  Superseded 2026-09-21 (EP-10 unit 5): the hand-authored numeric presets are
  gone; B03's starting states are its group's measured variants and the
  guard form. Result 2 is item 5 of the batch above. The 2026-09-03
  acceptance of the result-2 route stays on record.
  - [x] Result-2 playback from the explicit initial-100 representative: the
    user confirmed choice 2 on 2026-09-03 after main `84580f64` integration.
    This accepts that Event Player route only, not original-engine equivalence
    or other starting values. The separate money interpretation remains a
    hypothesis, not a prerequisite or a result of this UI check.
  - [ ] Confirm the remaining selector/reset and active-session isolation controls
    below in a later grouped UI batch; the choice-2 report alone does not
    claim these interactions were exercised.
  - After automated verification and integration in main, open Event Catalog,
    select Mahoko event B03, and choose **State[12]=100 (04/13 Sat 18:25;
    choices 1-3)** in the Preset selector. This is a numeric source
    representative, not a captured state or a confirmed money label.
  - The former unqualified-row 1/3 check is superseded, not accepted: revision
    15 source-qualifies those rows for the same preset. New result-1/3 playback
    is checked in MV-11. The row-2 branch dialogue, standing/station presentation and map-completion
    check is accepted above; no repeat is needed for unchanged playback.
  - Switch the catalog preset back to **Captured starting state** and confirm
    its label/notes show baseline choices 1-3. Selecting another event must
    reset to that event's recommended preset without leaking state12=100.
    Preset selection alone must not interrupt a running event. Check selector
    readability at the normal output resolution; logical gameplay stays 640x400.
  - Record only Event Player visual/audio acceptance. Original-engine timing,
    other starting states and native pixel equivalence remain unverified.
- [x] **MV-11 — EVENTB03 existing presets with results 1/3.**
  Superseded 2026-09-21 (EP-10 unit 5), as MV-09; results 1 and 3 are items 4
  and 5 of the batch above.
  - After automated verification and main integration, use the original
    content set and Event Catalog -> Mahoko event B03. No new preset is needed.
  - With **Mahoko 36 / State[12]=100**, choose row 1. Confirm it is no longer
    marked unqualified, follows its own dialogue, shows the middle standing
    expression over the station interior, and completes on the station map.
  - With **Mahoko 76 / State[12]=100**, choose row 3. Confirm the two first
    blackout impact cues, CG automatic/manual movement and resumed animation,
    then the high standing expression over the station interior and station
    map/protagonist completion. Finish the manual CG stage using Enter or
    **Finish CG inspection**, as in MV-04.
  - These two representatives exercise the newly enabled shared result-1/3
    presentation. The six added numerical routes are independently headless
    tested; neither that matrix nor this batch proves arbitrary starting
    states, original-engine scheduling or native timing. Previously accepted
    result-2 playback does not need repeating. Include MV-09's remaining
    selector/reset and no-interruption checks in the same batch.

## Completed

- [x] **MV-10 — EVENTB03 result-2 middle/high expression representatives.**
  - On 2026-09-03 the user confirmed both **Mahoko 36 / State[12]=100** and
    **Mahoko 76 / State[12]=100** after main `eb8f956c` integration and the
    catalog Preset selection instructions. This accepts both requested
    result-2 checks: the distinct standing expressions, station-background
    composition and final station map/protagonist.
  - Acceptance is limited to these two isolated source representatives. It
    does not establish original-engine timing, native scheduler eligibility,
    other starting values, or other choices. MV-09's selector-reset and
    active-session isolation checks remain separately pending; they are
    not inferred from confirmation of the two presets.
- [x] **MV-08 — EVENTB03 choices 1/2 with the qualified starting preset.**
  - The user confirmed the grouped check from merged `main` commit
    `55c7ed19`: branch dialogue/voice/effect playback, station interior behind
    the standing animation, and the final station map with the protagonist.
  - Acceptance applies to the existing three-field fresh preset
    `captured-result3-original`, including initial `[12]=0` and affection 0.
    It does not qualify other starting states or establish original-engine
    timing, pixel equivalence, or complete native presentation support.
- [x] **MV-C07 — EVENTB03 result-3 first-blackout effect pair.**
  - The user confirmed the requested two audible impact cues after result 3
    from merged `main` commit `a88ecc33`. This accepts that Event Player
    listening check only; it does not certify all later pairs, cross-session
    behavior, camera presentation, or exact original-engine audio timing.
- [x] **MV-C01 — Image Editor shared AX controls and selected-cell placement.**
  - User-controlled verification accepted Play/Pause/Restart and tool-clock
    presentation after Content Core `0.178.0`.
- [x] **MV-C02 — Event Player verified-derived manager layout and rollback.**
  - The 2560x1440 manager layout and session-preserving missing-provenance
    rejection were accepted from merged `main`.
- [x] **MV-C03 — Routine-40 grouped analysis presentation.**
  - First/second-stage analysis and clamped navigation were accepted; this did
    not promote unresolved gameplay semantics.
- [x] **MV-C04 — MES Editor selected-address Run handoff to Event Player.**
  - User-controlled verification from merged `main` confirmed that an
    unstaged message draft disables Run and that the selected
    `01M.MES:0x0008` address opens in an independent Event Player Analysis
    session. The non-executing trace stopped safely at the registered DEF-11
    native boundary after 61 instructions without changing the original ARC or
    gameplay saves.
  - The changed-overlay semantic-proof chooser remains an automated contract;
    its GUI path is deferred until a matching Phase 6 proof fixture exists.
- [x] **MV-C05 — MES Editor selected-entry translation catalog workflow.**
  - User-controlled verification from merged `main` confirmed the complete
    original-entry workflow: export a revision-one catalog, stage a translated
    message with translator provenance, publish a distinct revision-two file,
    revert and import that catalog, publish the pending UTF-8 projection with
    `Save all...`, and restore the original dialogue with `Clear Overlay`.
  - This confirms the tool transaction and presentation workflow only. It does
    not promote the UTF-8 projection to original-engine CP932 compatibility.
- [x] **MV-C06 — MES Editor separated text-output policy workflow.**
  - User-controlled verification confirmed the complete staged-output UI:
    remake-only UTF-8 readiness remains independent of CP932 representation or
    exact-length blockers, compatible equal-length CP932 text is labeled
    `original_engine_unverified`, blocked publications retain pending edits,
    and both successful output paths reopen normally.
  - This validates the editor policy and publication workflow only. It does not
    close MV-03 or promote any changed MES payload to
    `original_engine_compatible`.
