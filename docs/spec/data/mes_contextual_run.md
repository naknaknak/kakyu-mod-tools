# MES contextual analysis Run

Scope update 2026-09-08: Event Player is original-only. The edited-Run UI
behavior documented below is historical; EP-08 owns its removal from the app.
Authoring bundles, semantic/coordinate proofs and headless package validation
remain supported by their owning tools. This decision changes no data schema
and does not claim that existing executable entry points have already changed.

`kakyu_mes_contextual_run_binding/v1` records a bounded execution of an authored
catalog callee. The existing editor Run request remains v1. It binds the named
workspace generation, original and effective entry identities, and the complete
Phase 6 semantic proof. The editor's Authoring tab offers catalog presets for
the selected entry; the receiver validates the selection before executing it.

The first supported change is a same-width literal state write with semantic
diff v2. The receiver independently checks original and output container headers,
instruction boundaries, literal values and expression hashes. Every byte outside
that expression must equal the original. The start, choice and terminal
coordinates therefore have an identity mapping. The message-relocation extension below adds changed coordinates; other edit
families and modified shared dependencies remain unsupported.

The original caller entry, dispatch command, target and resume coordinate are
audited directly. Caller execution is explicitly omitted. Shared MES membership
comes from `EventCatalog.source_members_for_events`; each effective member is
resolved without fallback and checked against the catalog or the callee proof.
The shared `MesRouteProbe` runs the selected preset and first catalog choice in
a disposable sandbox, retaining its existing bounded native omission policy.
The binding records this scope, preset/proof fingerprints and every mapped point.

Completion requires an empty driver stop reason and a full catalog terminal
match: owner, runtime status, offset, target and required state. Caller-owned
completion remains unresolved when outside the bounded execution. The receiver
refreshes and verifies the workspace generation before committing its state and
results to Analysis view. UTF-8 text overlays use the message's source entry and
raw hash. Ordinary original-only Catalog Play retains its own source guards.

The original regression uses EVENTB03.MES, caller 01M.MES at `0x788F`, preset
`captured-result3-original`, and an authored change at `0x76`. It exercises
Python handoff, editor translation/state controls, workspace publication,
semantic reopening, preset selection and strict MACHI.MES completion. The
selected first-choice result is a tool decision, not the captured result-3 input.
Original evidence remains in the existing EVENTB03 MES documents. No new native
meaning or manual visual verification is claimed by this workflow.

## Relocated messages in Core 0.304.0

Binding v2 supports authoring-bundle v2 message/control-target compilation with
semantic diff v4. The original/output proof is reproduced in Python, not accepted
from asserted summary hashes alone. Every catalog start, choice and callee
terminal must match an exact mapped record start. Terminal resume coordinates
map through record starts/ends; a `callee_return_only` terminal resumes its
unchanged original caller, so that coordinate is not relocated with the callee.
`resume_points` records the owner and original/effective coordinate explicitly.

The route probe executes the mapped descriptor. Its effective terminal offset
is mapped back to the original before the existing catalog checks status, owner,
target and required state. The result preserves both terminal observations and
the coordinate-binding hash; the original catalog is unchanged. An absent or
ambiguous coordinate fails before UI/state publication. Existing translations
are mapped and validated before committing displayed results.

The original regression edits a message at EVENTB03 code offset `0x302`, growing
it by six bytes. It maps choice `4818 -> 4824` and root-replacement terminals
`15686 -> 15692`, `7094 -> 7100`, `9972 -> 9978`, including their resume points.
It retains caller 01M.MES `0x788F` and the existing first-choice tool policy.
These are authored compiler/instrument results over the existing MES evidence,
not a new original-engine semantic claim. The first state-edit path still
emits binding v1 with identity coordinates.
