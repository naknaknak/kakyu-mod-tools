# EVENTB03 station candidate route

## Scope and evidence boundary

Content Core `0.279.0` exposes
`kakyu_mes_eventb03_candidate_plan/v1`, a source-bound, read-only description
of the `01M.MES` candidate guard at `0x7691` and its true arm through the
`EVENTB03.MES` script-handoff boundary at `0x788F`. It answers whether one
exact numeric input set satisfies this local guard and records the source
checkpoints that follow.
It does not run dialogue, audio, state writes, shared routines, presentation,
or the nested script.

This is deliberately **not** an Event Player preset or a proof that the event
must occur in an arbitrary saved game. Earlier candidates in `01M.MES` can
preempt this guard, and the native/host mechanism that selects a particular
01M address-table row is not statically identified. Existing catalog replays
remain captured, isolated target replays with their current date and state.

Evidence type: direct read-only authoritative `mes.arc` decoding through the
current GDScript container, instruction and expression implementations;
original-EXE comparison/logical-truth audits; and the existing
EVENTB03-qualified native runtime capture. Confidence is **Confirmed** for
the local guard AST, numeric intervals, record boundaries, true-arm source
order and named handoff. Upstream natural eligibility, address-row selection,
native presentation/cadence and arbitrary saved-state behavior remain
**Unresolved / unqualified**.

All intervals are code-relative half-open `[start,end)`. Machine-specific
paths remain in `.agents/local/source_paths.md`; no original dialogue, payload,
lossless bytecode, decoded media or absolute path is tracked.

| Authoritative source | SHA-256 |
|---|---|
| `mes.arc` | `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6` |
| `01M.MES` entry | `a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5` |
| `01M.MES` bytecode | `f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b` |
| `EVENTB03.MES` entry | `558532a9b034522db857d009132b6a89aa488e577277857cc90ce337c95ee230` |
| Original EXE wrapper | `3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5` |
| Embedded runtime at wrapper `0x1B000` | `5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da` |

## Exact local predicate

The guard envelope is `01M.MES:0x7691..0x76F1`, with SHA-256
`7f8da510f2f3b0e7d3714812605da35f9f249321044f60e7dcb321b9c4c3c9d4`.
Its false target is `0x78A9`. The decoded expression is a left-associated
logical-AND chain of these exact predicates:

| Numeric source reference | Required value |
|---|---|
| `state_u16[7]` | greater than 400 and less than 616 (`401..615`) |
| `state_u16[19]` | greater than 1800 and less than 2001 (`1801..2000`) |
| `banked_u16[0][210]` | greater than 40 and less than 80 (`41..79`) |
| `global_u8[207]` | not equal to 2 |
| `global_u8[333]` | equal to 0 |
| `global_u8[200]` | equal to 0 |
| `global_u8[400]` | equal to 1 |
| `global_u8[205]` | equal to 0 |
| `global_u8[631]` | equal to 0 |
| `state_u16[12]` | not equal to 0 |
| `global_u8[628]` | equal to 0 |

`state_u16[4]`, currently used as the weekday word by the product preset, is
not read by this local guard. That absence does not remove the preset's
weekday qualification: prefix/shared/native processing and other scheduling
layers are outside this slice.

The affection interval uses the already-confirmed Mahoko cell
`banked_u16[0][210]`. The other state references remain numeric here; the plan
does not assign them inferred gameplay names. In particular, the user's
money interpretation for `state_u16[12]` remains a separately recorded
hypothesis and is not converted into a confirmed semantic label by this
nonzero test.

Native and GDScript expression audits agree that logical AND/OR accepts only
the exact numeric value `1` as true and still evaluates both operands. Every
comparison in this guard produces normalized `0` or `1`, so the full chain is
true exactly when all rows in the table hold.

## True-arm source checkpoints and stop boundary

When the local predicate is true, source-linear decoding continues at
`0x76F1`. The qualified prefix through the exclusive handoff end is
`0x76F1..0x789F`, SHA-256
`da17019f9f71d69723776c60f867741fef82be605149a995cd22da5a7d95cfc0`.
The read-only plan verifies these checkpoints without executing them:

| Coordinate | Structural witness |
|---|---|
| `0x76FB` / `0x7703..0x7708` | argument slot 1 receives 133, then routine 23 is requested |
| `0x7712` | address entry 66 begins |
| `0x775A` / `0x7760..0x7765` | argument 66, then routine 0 |
| `0x776A` | banked word 2 is ORed with 128 |
| `0x7777..0x778C` | one bounded `B0001.OGG` voice marker |
| `0x778C` | banked word 2 is ANDed with `0xFF7F` |
| `0x779E` | address entry 67 begins; its routine-0 message ID is 67 |
| `0x77E6` | address entry 68 begins; its routine-0 message ID is 68 |
| `0x7834` | address entry 69 begins; its routine-0 message ID is 69 |
| `0x788F..0x789F` | complete command-`0x0E` record naming `EVENTB03.MES` |

The source-local plan reports a **script-handoff stop**. It never resumes
at bytes after `0x789F`, never turns those bytes into EVENTB03 commands, and
does not synthesize a start coordinate or caller-frame value. The existing
target-qualified native capture separately confirms host consumption of the
retained `EVENTB03.MES` name, archive loading, stream installation,
zero-coordinate execution and root replacement. Those host facts must not be
attributed to parameters encoded in the `0x788F` record itself; native behavior
after the handoff remains outside this plan.

The excluded local bytes `0x789F..0x7940` have SHA-256
`43badccb2bb2fa04c16634da1bd42a60196ca1260800ea0bad25c1233b64a8d0`.
The plan preserves that identity but marks only the tool policy (not executed)
and leaves native post-handoff behavior unresolved.

Address-table row 69 has declared interval `0x7834..0x7940`; its local bytes
through the handoff hash to
`ca226e1542dc983b40ab32fbb298f2224ec1aa3d11d64089e0104f21d200e6d6`.
Starting row 69 directly bypasses the `0x7691` guard. `01M.MES` contains no
command-`0x18` address-table dispatch and no static branch/continuation target
to `0x7834`. Therefore this row is a true-arm fallthrough witness, not a
source-static natural-entry selector.

## Upstream cascade and natural-entry limit

The station script's main candidate cascade begins after setup at guard
`0x026D`. Its successive false destinations leading to the B03 guard are:

```text
0x026D -> 0x247E -> 0x2AF7 -> 0x3170 -> 0x37E9 -> 0x3E62
       -> 0x44DB -> 0x4B54 -> 0x51CD -> 0x5846 -> 0x5EBF
       -> 0x6538 -> 0x6BB1 -> 0x722A -> 0x73F5 -> 0x7691
```

The bounded source slice `0x026D..0x78A9` has SHA-256
`f537624206b90bb337372f390f9731ed0b23b0e6d45a6e26a9d7246ea99d0fd1`.

An isolated representative (`date=413`, `time=1825`, affection `76`,
`state_u16[12]=100`, `global_u8[400]=1`, and zero for the other relevant
candidate cells) makes those decoded guards false and the B03 guard true.
This is a reproducible source-expression witness, not a complete entry-0
simulation. The entry prefix contains registered definitions, shared calls
and native presentation whose scheduling effects are not established by the
candidate plan. Earlier event candidates may also be selected in real state.

`MACHI.EVE` event 16 and `MACHI.MES:0xACA2..0xACBC` establish entry into
`01M.MES` from the station location, but neither identifies row 69 nor directly
selects EVENTB03. The caller/native prefix and host row selection must still be
qualified before the catalog can claim natural scheduler eligibility or widen
its date/state presets.

The subsequent [station candidate priority audit](station_candidate_priority.md)
now qualifies the exact source order and first-match stop behavior of all 15
preceding guards. It still accepts only an explicitly supplied frozen state
after the unresolved shared/native prefix, so the natural scheduler and host
address-row limits in this section remain in force.

Content Core `0.282.0` composes that priority receipt with this local guard in
the read-only [Station-to-EVENTB03 Decision](station_eventb03_decision.md).
The wrapper qualifies frozen-snapshot preemption only; it does not qualify the
prefix, host entry, native row selection or natural scheduler eligibility.

## Plan contract and reproduction

`build(payload, input)` accepts only the exact original `01M.MES` entry and a
dictionary containing the eleven numeric keys represented above. Direct
inputs must be strict unsigned-word or unsigned-byte integers for their
storage. It returns the source identity, complete local predicate result,
guard and checkpoint boundaries, and either the false boundary or the
script-handoff stop. Its execution receipt remains read-only, with no state
mutation and unqualified upstream eligibility.

`validate(payload, plan)` rebuilds the complete plan and rejects changed
source bytes, fields, order-sensitive checkpoint lists, extra/missing keys,
booleans, strings, fractions and non-finite JSON numbers. JSON round-tripped
integral numbers may match exact integer plan fields. Neither operation edits
the input dictionary or source payload.

Run the source audit with the configured ELFIMAGE directory:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_eventb03_candidate_plan.gd -- `
  <ELFIMAGE-directory>
```

The audit checks all six source archives before and after, the exact guard and
true-arm records, a true representative, every single-field boundary failure,
deterministic rebuild and JSON validation, and the upstream source-expression
witness. It exports no original content and performs no audio, presentation,
state write, shared-routine or nested-script execution. No UI verification is
required for this analysis-only unit. The final source run passed **270
checks**: one qualifying candidate, 14 independent false boundaries and 15
upstream false-chain guards, with all six archives unchanged. The independent
synthetic suite passed **100 checks**, and the original-EXE logical-truth audit
passed **42 checks**. The known local missing-calendar-data autoload warning is
separate from these successful assertions.
