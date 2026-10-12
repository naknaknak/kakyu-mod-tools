# Station-to-EVENTB03 frozen-state decision

## Scope

Content Core `0.282.0` exposes
`kakyu_mes_station_eventb03_decision_plan/v1`, a source-bound, read-only
composition of the fifteen station candidate guards and the immediately
following EVENTB03 candidate guard. The input is one caller-supplied frozen
snapshot at the assumed `01M.MES:0x026D` cascade entry. It is not a save-state
preset and is not claimed to be the result of executing the earlier station
prefix.

The plan evaluates the confirmed source order only. The first true upstream
guard stops before its body and leaves the EVENTB03 guard unevaluated. Only an
all-false upstream result reaches `0x7691`, where the existing source-bound B03
candidate plan is evaluated against cells projected from the same snapshot.
No upstream body, dialogue, native operation, script handoff or false suffix is
executed.

## Authoritative identities and intervals

All MES offsets are code-relative, half-open `[start,end)`. The authoritative
archive was read directly from the configured local source; machine-specific
paths, original dialogue and payload bytes are not tracked.

| Source | SHA-256 |
|---|---|
| `mes.arc` | `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6` |
| `01M.MES` entry | `a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5` |
| `01M.MES` bytecode | `f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b` |
| priority slice `0x026D..0x7691` | `34ae9a590921cf5e4ac5f4a5921c2d5b1a779ae6d868d7b4ead456bcb1671c29` |
| B03 guard `0x7691..0x76F1` | `7f8da510f2f3b0e7d3714812605da35f9f249321044f60e7dcb321b9c4c3c9d4` |
| B03 true prefix `0x76F1..0x789F` | `da17019f9f71d69723776c60f867741fef82be605149a995cd22da5a7d95cfc0` |
| B03 handoff record `0x788F..0x789F` | `31be24c8ca3ec0e0613e2bced44ff4d9edcf70e7f4c4bfc821e2c4a407b6fde4` |
| combined bounded window `0x026D..0x78A9` | `f537624206b90bb337372f390f9731ed0b23b0e6d45a6e26a9d7246ea99d0fd1` |

The priority plan already proves that every false edge leads to the next guard
and that guard 14's false edge reaches `0x7691`. The B03 plan independently
binds that same coordinate as its guard start, its true boundary to `0x76F1`,
its source-local script-handoff stop to `0x788F..0x789F`, and its false boundary
to `0x78A9`. Composition therefore adds no inferred edge or native meaning.

Evidence type is authoritative `mes.arc` container parsing plus structural
instruction/expression decoding, exact slice hashes, and deterministic replay
of the two existing child plans. Existing original-EXE expression audits
remain the basis for unsigned storage widths and exact-one logical truth; this
composition introduces no new executable-semantic claim.

## Exact 79-cell snapshot

`build(source_payload, input)` requires exactly three dictionaries with
decimal string keys. Direct builds accept exact integers only. JSON validation
may normalize finite integral numbers back to integers, but booleans, strings,
fractions, negative values, values beyond their storage width, unknown keys
and missing keys fail closed.

- `state_u16` (`0..65535`): `4, 7, 12, 19`
- `banked_u16_0` (`0..65535`): `210, 213, 214, 215, 216, 217, 218,
  219, 220, 221, 222, 225, 226, 227, 228, 229, 230, 231, 232, 233,
  234, 235, 236, 237, 238, 268`
- `global_u8` (`0..255`): `100, 107, 109, 110, 117, 119, 120, 127,
  129, 130, 137, 139, 140, 147, 149, 160, 167, 169, 170, 177, 179,
  180, 187, 189, 190, 197, 199, 200, 205, 207, 209, 210, 217, 219,
  220, 227, 229, 333, 400, 628, 631, 1188, 1189, 1750, 1751, 2300,
  2301, 2304, 2305`

The priority child receives its exact 72-cell subset. The B03 child receives
its eleven flat bindings projected from the same dictionary. The two children
share exactly `state_u16[7]`, `state_u16[19]`, `global_u8[200]`, and
`global_u8[207]`; deriving both views from one input eliminates a contradictory
shared-cell state. Only `banked_u16[0][210]` has a confirmed gameplay label
(Mahoko affection) here. Other numeric cells retain numeric names; in
particular, the user's money interpretation of `state_u16[12]` remains a
separate hypothesis.

## Three outcomes

The decision has exactly three outcomes:

1. `eventb03_preempted_by_upstream_guard`: one of the fifteen guards is the
   first true result. The selected boundary is copied from the priority plan,
   its body remains unresolved and the B03 stage is not evaluated.
2. `eventb03_guard_matched`: all upstream guards are false and the B03
   guard evaluates to exact numeric one. The selected boundary is the
   source-local handoff stop; the handoff is not executed.
3. `eventb03_guard_rejected`: all upstream guards are false and the B03
   guard evaluates to zero. The selected boundary is `0x78A9`; no meaning is
   assigned to the later suffix.

The wrapper always rebuilds and validates the priority child. It rebuilds and
validates the B03 child only after the all-upstream-false join, then retains the
reached children's schema, deterministic plan fingerprint, projected-input
fingerprint and selected-boundary receipt. It leaves the child contracts
themselves unchanged, including the B03 child's local statement that upstream
preemption is unresolved in isolation. The wrapper execution receipt records
only frozen-snapshot preemption as `qualified` and product preset widening as
`false`; it does not reinterpret either child's execution receipt.

## Evidence boundary

Confidence is **Confirmed** for the exact source identities and intervals, the
fifteen first-match guards, the all-false join, the B03 predicate and its two
source-local boundaries, the exact 79-cell union, shared-cell projection, and
read-only deterministic composition.

The following remain **Unresolved / unqualified**:

- completion and state effects of the conditional prefix
  `01M.MES:0x0008..0x026D`;
- whether a native host enters coordinate zero, another address-table row, or
  reaches `0x026D` at all;
- MACHI-to-`01M.MES` stream installation and native row selection;
- every upstream true body, B03 nonlocal/native effect, post-handoff behavior,
  and the meaning of the B03 false suffix;
- natural scheduler eligibility, correspondence to an arbitrary save, native
  cadence, and any product preset widening.

Consequently, a true B03 decision is a source-expression witness at an assumed
cascade entry, not proof that EVENTB03 naturally triggers in a saved game.

## Reproduction

Run the read-only original-source validator:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_station_eventb03_decision_plan.gd -- `
  <ELFIMAGE-directory>
```

The focused synthetic scene passes **230 checks**, and the authoritative run
passes **951 checks**. Together they cover the exact input union, all fifteen
first-true stops, multiple-true earliest-wins cases, an all-false B03 match,
every single-condition B03 false boundary, shared-cell projection, malformed
input, child-receipt and wrapper tampering, deterministic JSON replay, input
immutability, and unchanged source archives. No UI verification is required
for this analysis-only plan.

See [Station candidate source priority](station_candidate_priority.md),
[B03 station candidate route](eventb03_candidate_entry.md), and
[Station candidate conditional prefix](station_candidate_prefix.md) for the
three source contracts kept distinct by this composition.
