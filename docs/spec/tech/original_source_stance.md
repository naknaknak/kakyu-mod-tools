# Stance toward the original game

This document fixes the project's stance toward the original ELFIMAGE game:
what the original is used for, what it is not used for, and which claims the
project does and does not try to establish. It is a decision record. Product
scope stays in [Content Suite Product Goals](content_suite_product_goals.md)
and [Event Player Product Goal](event_player.md); ordered work stays in the
repository-root [TODO](../../../TODO.md).

## The goal this stance serves

The final goal is **modding the existing game** — adding events and other
content. Two constraints were confirmed with the project owner:

1. mods do not need to run inside the original AI5WIN engine, and their
   audience is the remake runtime, not third parties running the original
   game; and
2. original game behavior must nevertheless be reproduced faithfully, which is
   why original script analysis is being done at all.

Those two constraints are not in tension. They separate cleanly once the
original stops being treated as an execution target.

## The stance

**The original is a specification, not an execution target.**

- Original `mes.arc`, the other ARCs, and the original executable are
  **read-only sources of truth** about intended behavior.
- The **remake runtime is the execution environment** for both original and
  modded content.
- Equivalence is judged by **observable behavior against the source-derived
  specification**, not by proving what the original executable does
  internally.
- Where the original's internal mechanism cannot be established from the
  source, the remake **defines** its own mechanism and documents it as a
  remake decision, instead of blocking on the unresolved original.

## Why: what the execution-target stance actually cost

The project previously carried an implicit "the original engine is also an
execution target" stance. Its measured results:

| Observation | Value |
|---|---|
| Payloads that reached `original_engine_compatible` across the project history | **0** |
| Original-EXE audit generations spent on command-`0x0E` host activation alone | **v56 through v156** |
| Status of that question after those generations | unresolved: no proven arbitrary retained-target activation coordinate, context, or caller restore |
| Ability to add a new entry to an ARC | absent; add/delete/reorder is deliberately excluded |

The last row is decisive for the stated goal. Adding an event to the original
engine requires a new `mes.arc` entry, address-table relocation, and caller
modification that the original engine accepts. The add capability does not
exist, and the mechanism by which the original engine activates a script by
retained name was not resolved by a hundred audit generations. Under the
execution-target stance the project's own final goal therefore had no
reachable path.

The same wall was reached independently from the event side: the natural
scheduler eligibility of EVENTB03 is blocked on whether a native host enters
`01M.MES` at coordinate zero, recorded as unresolved in
[Station candidate conditional prefix](../mes/station_candidate_prefix.md) and
[Station-to-EVENTB03 Decision](../mes/station_eventb03_decision.md). Two
different lines of work converged on the same unresolved native host boundary.

## What the stance resolves

Questions that static source analysis cannot settle stop being blockers,
because the remake owns the answer:

| Previously an unresolved blocker | Under this stance |
|---|---|
| Where does the native host start `01M.MES`? | The remake is the host; it chooses and documents its entry, validated by behavior |
| What is the arbitrary script activation coordinate? | Not required; the remake activates scripts through its own runtime |
| Native cadence and x87 intermediate pixels | Replaced by observable-behavior equivalence at the documented tool-clock boundary |
| Natural scheduler eligibility | Source guards are the specification; the remake implements a scheduler against them |

This is stronger than deferring those questions. They are removed from the
critical path rather than parked.

## What this does not license

The stance narrows what must be proven; it does not weaken evidence rules.

- Original archives, saves, and executables remain read-only. No tool writes
  to them.
- A claim that a remake route reproduces an original route still requires the
  source-derived evidence described in `docs/spec/mes/`.
- Unknown original meaning still stays numeric, native, or opaque. The remake
  may choose a behavior where the original is unresolved, but it must be
  labeled a remake decision, not an original-source finding.
- Original dialogue, payloads, and machine-specific paths still never enter
  version control or distributed packages.

## Consequences for existing work

### Released from the critical path

These retain their existing implementation and labels but stop gating product
progress. They are deferred, not deleted, and can be revived if the
distribution audience ever changes.

- `manual_verification.md` MV-01, MV-02, MV-03 — original-engine display,
  playback, and CP932 MES candidate checks.
- `media_editors.md` ME-01 and ME-04 — original-engine DAT/PAL and OGG
  verification.
- The equal-length CP932 authoring constraint as a *goal*. Variable-length
  UTF-8 remake output becomes the normal authoring path rather than a
  fallback, which removes the principal restriction on translation and new
  dialogue.
- `original_engine_compatible` as a target label. It remains defined and
  reported so a future audience change is not blocked, but nothing waits on
  reaching it.

### Promoted to the critical path

- **Event Player runtime completeness.** The remake is now the engine, so the
  Event Player definition-of-done items become required product work rather
  than one consumer among several.
- **Event corpus coverage.** The scope of "original functionality works
  perfectly" is measured by
  [Event Corpus Inventory](../mes/event_corpus_inventory.md): 129 reachable
  EVENT-named dispatch targets, of which the catalog currently covers 12. That
  129 is the strict-decode count;
  [Dispatch Naming Reachability](../mes/dispatch_naming_reachability.md) adds
  418 entries named only inside preserved opaque tails, and leaves exactly one
  `EVENT*.MES` entry that nothing in the archive names.
- **A remake-native authoring path for new events.** A new modded event does
  not have to be MES at all, because no original engine has to read it. The
  Phase 6 relocating compiler remains the right tool for *editing existing*
  MES, but new content should not be forced through original container
  constraints.

## Confidence

The stance itself is a project decision, not a source finding. The
observations that motivate it — the zero-compatible-payload history, the
command-`0x0E` activation audit range, the absent ARC add capability, and the
unresolved native host entry — are each recorded in the documents linked
above.
