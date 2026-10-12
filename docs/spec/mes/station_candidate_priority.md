# Station candidate source priority

## Scope and evidence boundary

Content Core `0.280.0` exposes
`kakyu_mes_station_candidate_priority_plan/v1`, a source-bound, read-only
projection of the fifteen `01M.MES` candidate predicates that precede the
EVENTB03-local guard at `0x7691`. The plan evaluates those predicates in their
original source order against one complete frozen input. It stops at the first
true predicate's body boundary. If all fifteen predicates are false, it stops
at the `0x7691` join and identifies the existing EVENTB03 candidate-plan schema,
but does not invoke or delegate to that plan.

The plan never executes a candidate body, shared routine, registered
definition, native record, presentation effect, terminal, or target script.
It does not mutate the supplied dictionary or its isolated MES state. It is
therefore a priority/preemption proof for one fully supplied numeric snapshot,
not a new Event Player preset and not proof that EVENTB03 naturally occurs in
an arbitrary saved game.

All MES intervals below are code-relative, half-open `[start,end)`. Machine-
specific paths, original dialogue and lossless source payloads are not retained
in this document.

## Authoritative identities

| Source | SHA-256 |
|---|---|
| `mes.arc` | `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6` |
| `01M.MES` entry | `a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5` |
| `01M.MES` bytecode | `f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b` |
| `01M.MES:0x0000..0x0008` coordinate-zero bootstrap | `1d5fcfa66928c2bd712394fcd5e001e48b41b60f943039c72d06687224953e5c` |
| candidate-priority slice `0x026D..0x7691` | `34ae9a590921cf5e4ac5f4a5921c2d5b1a779ae6d868d7b4ead456bcb1671c29` |
| `data.arc` | `b069c4dbb67d67eaf9252babc02f100fbc16c0740a189b007ff31535305727e4` |
| `MACHI.EVE` entry | `9f56d74f8c53fc3ee2ad17918519f677e3ebf9070097921190e3ea6de2833d62` |
| `MACHI.EVE:0x00C0..0x00CC` event-16 record | `538fe2444347fb43fb1c0c93bfb7297b589835cc2b1ef1e99a875d4b035edb0a` |
| `MACHI.MES` entry | `56b0f4243f3c0944624ea0ef11b369391761ff394816775264c144bb76391488` |
| `MACHI.MES` bytecode | `34aea9b95996997a4657c89e848b59c0d04c1ba1fdeb26794252017b1d1a84cf` |
| `MACHI.MES:0xACA2..0xACAC` event-16 guard | `e388389b8096d854a52c12203969a7b73cfc2369bb5f6267b3d1b4d1266893fd` |
| `MACHI.MES:0xACB1..0xACBC` `01M.MES` handoff | `7d254587b79c85522f184d95301f986a3f72510128d8920dc163d7868c81c612` |
| original EXE wrapper | `3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5` |
| embedded runtime at wrapper `0x1B000` | `5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da` |

The plan also requires the original 426-cell `01M.MES` address-table layout.
In particular, it binds entry 0 to `0x0008..0x03AF` and entries 59--65 to the
source intervals that own the later cascade and its final join. A matching
predicate hash without that address ownership is rejected.

## Fifteen guards in source order

Each row is one complete `branch_if_not_true` instruction. `true boundary` is
the instruction end and therefore the first byte of the candidate body. The
plan stops there when the predicate is true. A false result follows the stored
destination to the next row.

| Order | Guard interval | True boundary | False destination | Guard SHA-256 |
|---:|---:|---:|---:|---|
| 0 | `0x026D..0x02A3` | `0x02A3` | `0x247E` | `0d0e009000726fe0f17548178304c4c6e86b71f2ac575d2f6437bd10c82eef57` |
| 1 | `0x247E..0x24D7` | `0x24D7` | `0x2AF7` | `dc89fca3c2c7a529c34c5ee8063a8974d2ddaed4e6e2cc697c211007e4f28b61` |
| 2 | `0x2AF7..0x2B50` | `0x2B50` | `0x3170` | `b7314844e929563792746672a74858c66aa4c6adb20880c7a1928ec5b95949ae` |
| 3 | `0x3170..0x31C9` | `0x31C9` | `0x37E9` | `af269a8ec3cdd5d8d2c05bb4ce63c64981e550ec78b363b7d1722d2490a3eabb` |
| 4 | `0x37E9..0x3842` | `0x3842` | `0x3E62` | `759c90777fecd03bc76b37627e4b639cf2c3caa01bdacd9c088f0cdec291f3e1` |
| 5 | `0x3E62..0x3EBB` | `0x3EBB` | `0x44DB` | `728f5cecff49a64f35a7bb39cb9434cceb213727eb6203e54ea9e8393e9fa86b` |
| 6 | `0x44DB..0x4534` | `0x4534` | `0x4B54` | `f6cb89285e40075b7520511300e16cb24aad36638775e1b941280b8602d53c88` |
| 7 | `0x4B54..0x4BAD` | `0x4BAD` | `0x51CD` | `86fe3d853c62a02e8498e2c7e59be95ac102305d42476e0a4e626ff69c07e931` |
| 8 | `0x51CD..0x5226` | `0x5226` | `0x5846` | `dfa883381166c690755794263524fed545f8c175cb89871a47745047df484530` |
| 9 | `0x5846..0x589F` | `0x589F` | `0x5EBF` | `285f1ed60093062ceaf35777b4a875f5825c9c190195be5dc11a6a35fd3e5482` |
| 10 | `0x5EBF..0x5F18` | `0x5F18` | `0x6538` | `4d11b77ddf881fc8b1d1f42c736c5717c93d1a74acc3aa373047221bba3a7550` |
| 11 | `0x6538..0x6591` | `0x6591` | `0x6BB1` | `70dd239bdc7caf40e80a53d732c085d39d409608b48b8817c41c2ec595510b86` |
| 12 | `0x6BB1..0x6C0A` | `0x6C0A` | `0x722A` | `67e133c45363e595f4c08ac5a25643865d7fb67b7b29bbeb2051a45fe8ca330a` |
| 13 | `0x722A..0x725D` | `0x725D` | `0x73F5` | `2ca7c628287f9a65b90969240f1dbab5a19cae41c05f89811d124300a08753b0` |
| 14 | `0x73F5..0x7425` | `0x7425` | `0x7691` | `a97d3d398e663593eb01b85e1ce4892cd69ca38696a7089f51ec25c53928144b` |

Guard 0 is the exact left-associated AND chain:

```text
banked_u16[0][268] + 1 == state_u16[7]
AND state_u16[19] > 930
AND state_u16[19] < 1100
AND global_u8[2300] == 1
AND global_u8[2304] == 0
AND global_u8[2305] == 0
AND global_u8[2301] == 1
```

Guards 1--12 repeat one exact schedule shape. Each predicate is a logical OR
of two complete left-associated AND chains. The chains are identical except
that the first compares `state_u16[19] == banked_u16[0][time cell]` and the
second compares `state_u16[19] > banked_u16[0][time cell]`. Both retain these
additional source tests:

```text
state_u16[7] == banked_u16[0][date cell]
global_u8[base] == 1
global_u8[base + 7] == 2
global_u8[base + 9] > 8
global_u8[base + 9] != 14
```

The source validator compares that duplicated AST shape directly; it does not
replace it with an algebraically shortened `>=` predicate.

| Order | Date cell | Time cell | Global-byte base |
|---:|---:|---:|---:|
| 1 | 213 | 214 | 100 |
| 2 | 215 | 216 | 110 |
| 3 | 217 | 218 | 120 |
| 4 | 219 | 220 | 130 |
| 5 | 221 | 222 | 140 |
| 6 | 225 | 226 | 160 |
| 7 | 227 | 228 | 170 |
| 8 | 229 | 230 | 180 |
| 9 | 231 | 232 | 190 |
| 10 | 233 | 234 | 200 |
| 11 | 235 | 236 | 210 |
| 12 | 237 | 238 | 220 |

Guard 13 is a left-associated AND chain requiring
`state_u16[7] != 1301`, `1800 < state_u16[19] < 2100`, the same
`state_u16[7] != 1301` test a second time, `global_u8[160] == 1`,
`global_u8[1750] == 1`, and `global_u8[1751] == 0`. The duplicate date test is
part of the original AST and remains mandatory.

Guard 14 requires `state_u16[4] == 0`,
`1100 < state_u16[19] < 1700`, `global_u8[110] == 1`,
`global_u8[117] == 0`, `global_u8[1188] == 1`, and
`global_u8[1189] == 0`.

Original-EXE expression audits establish unsigned word/byte reads, normalized
comparison results, and exact-`1` logical AND/OR truth. Since every child here
is a comparison that produces `0` or `1`, the source-order projection evaluates
the stored AST without substituting generic nonzero truthiness.

## Complete frozen input contract

`build(source_payload, input)` requires exactly three nested dictionaries with
string-form numeric keys. Every source-read cell must be present, including
cells belonging only to guards after the first true result. Unknown groups,
unknown indices, missing cells and extra cells fail closed.

- `state_u16`, unsigned `0..65535`: `4, 7, 19`
- `banked_u16_0`, unsigned `0..65535`: `213, 214, 215, 216, 217, 218, 219,
  220, 221, 222, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236,
  237, 238, 268`
- `global_u8`, unsigned `0..255`: `100, 107, 109, 110, 117, 119, 120, 127,
  129, 130, 137, 139, 140, 147, 149, 160, 167, 169, 170, 177, 179, 180, 187,
  189, 190, 197, 199, 200, 207, 209, 210, 217, 219, 220, 227, 229, 1188,
  1189, 1750, 1751, 2300, 2301, 2304, 2305`

This is 72 unique cells. Direct builds accept only integer values; booleans,
strings, fractions, non-finite values and out-of-width integers are rejected.
`validate(source_payload, plan)` rebuilds the entire plan and recursively
compares its exact dictionary/array shape. It permits a finite integral JSON
number to match an integer plan field, but does not relax input widths or type
checks for booleans and strings.

Evaluation emits only the guards actually visited through the first true row.
For each row it records `order`, source `offset`, normalized value, and selected
next offset. A true result returns `selected_boundary.kind =
stop_before_true_body`, with both boundary offsets fixed to that guard's end;
`tool_execution` remains false and true-body interpretation unresolved. All
false results return `selected_boundary.kind = candidate_cascade_join` at
`0x7691`, with `delegated = false` and the next plan schema recorded only as
metadata.

## Conditional source prefix from entry 0

Content Core `0.281.0` now publishes this interval as the separate, static
[station candidate prefix plan](station_candidate_prefix.md). That plan makes
the record partition and caller-local CFG reproducible, but deliberately does
not turn the conditional evidence below into an external-completion or native
host-start claim.

The separate authoritative prefix `01M.MES:0x0008..0x026D` has SHA-256
`4a669e767c925e7a988c0b7c169be9a250095a3091d4d20bb1d4e7b0cde24289`.
Current GDScript structural decoding yields exactly 103 records, zero
diagnostics, and zero opaque boundaries:

| Record family | Count |
|---|---:|
| source-line marker | 42 |
| command-`0x1B` manager-vector clear | 17 |
| global-byte write | 18 |
| state-word write | 4 |
| banked-word write | 3 |
| argument-slot write | 1 |
| shared-routine call | 5 |
| registered-definition call | 1 |
| AX presentation control | 3 |
| command-`0x12` native record | 3 |
| conditional branch | 2 |
| continuation | 2 |
| surface operation | 1 |
| entry label | 1 |

The first caller-local loop resets `state_u16[2]` to zero, tests
`state_u16[2] < 16` at `0x016E..0x0178`, copies one banked word, increments the
counter, and returns through `0x0191..0x0196`; it exits to `0x0196` after 16
iterations. The only later local branch, `0x01EF..0x01FA`, tests
`global_u8[2847] == 1`. Its true arm performs the stored surface operation at
`0x01FA..0x021F` and jumps to `0x0229`; its false arm calls routine 21 at
`0x0224..0x0229` and reaches the same join. There is no caller-local command-
`0x00`, command-`0x0E`, or command-`0x0F` before the first priority guard.

Important nonlocal checkpoints are registered DEF 11 at `0x0143..0x0148`;
shared routine 32 at `0x0152..0x0157`; routine 25 at `0x019C..0x01A1` and
`0x01EA..0x01EF`; three command-`0x12` records at `0x01A1..0x01B9`; argument
slot 1 = 11 and routine 27 at `0x01D8..0x01E3`; and routine 21 on the false
surface arm at `0x0224..0x0229`. Existing native-CFG certificates establish
total return for routines 21, 27 and 32. Routine 25 retains a cyclic CFG and is
not total-return certified. DEF 11 proceeds into DEF 12 and the still bounded
routine-26 boundary; command-`0x12` effects and AX selector 8's native wait are
also not executed here.

Consequently, caller-local CFG reaches `0x026D` if those nonlocal operations
complete, but this plan does not claim that an arbitrary native session must do
so. The prefix remains a **conditional source prefix**, not an unconditional
entry-zero execution certificate.

## Station host relationship and unresolved boundary

`MACHI.EVE:0x00C0..0x00CC` associates station trigger coordinates with event
16. `MACHI.MES:0xACA2..0xACAC` tests that event result and
`0xACB1..0xACBC` is the complete command-`0x0E` record naming `01M.MES`.
This proves the location-to-script-name relationship, but neither source record
contains an `01M.MES` address-row selector.

Executable audit `kakyu_ai5_mes_exe_audit/v317` was rerun against the original
wrapper and embedded runtime. Command `0x0E` routes through wrapper
`0x004182EE` to handler `0x00419210`. The bounded handler stores the target name
and presentation signal, but has no confirmed active-coordinate write,
synchronous script call, or caller-coordinate restoration. Its generic callee
start coordinate remains unresolved. A separate EVENTB03-qualified native
capture confirms zero-coordinate execution of the EVENTB03 target after the
later `01M.MES:0x788F` handoff; that observation cannot be generalized backward
to prove how the native host enters `01M.MES` from MACHI.

The following therefore remain explicitly unresolved:

- whether the MACHI-to-`01M.MES` host transition starts at coordinate zero;
- whether a native or external selector can start an `01M.MES` address-table
  row directly;
- completion and effects of prefix DEF 11/DEF 12/routine 26, routine 25,
  command `0x12`, and AX selector 8 in the relevant native session;
- native candidate-body effects, terminal resolution and presentation cadence;
- full natural scheduler eligibility for EVENTB03.

The minimum native observation that could close the first two items is one
owner-qualified trace beginning at `MACHI.MES:0xACB1`, followed by the matching
`01M.MES` archive load and stream installation, installed code coordinate, and
first stream-relative execution coordinate. Until that exists, neither entry 0
nor rows 65/69 should be presented as the native MACHI-selected start.

The independent source validator does confirm the `01M.MES:0x0000..0x0008`
bootstrap structurally: if an external host has already selected coordinate
zero, command `0x14` transfers to entry 0 at `0x0008`. This conditional source
fact is not evidence that the MACHI handoff chooses coordinate zero.

## Reproduction

Run the metadata-only validator with the configured original source directory
as its sole argument:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_station_candidate_priority_plan.gd -- `
  <ELFIMAGE-directory>
```

The authoritative run passed **806 checks**. It covered all fifteen exact
guards, fifteen independent first-true witnesses, the all-false EVENTB03 join,
four multiple-true earliest-wins cases, deterministic rebuild and JSON replay,
the MACHI event-16 and `01M.MES` handoff metadata, and the conditional
coordinate-zero bootstrap. The hashes of `mes.arc`, `mmo.arc`, `data.arc`,
`bgm.arc`, `se.arc`, and `voice.arc` were unchanged after validation.

## Evidence and confidence

Evidence consists of direct read-only authoritative archive decoding through
the current GDScript container, instruction and expression implementations;
exact address ownership, record boundaries, AST signatures, source hashes and
state-reference coverage; original-EXE expression and command-`0x0E` audits;
and the separately qualified EVENTB03 runtime capture. No original executable,
archive, save state, media, dialogue or UI was modified or executed for this
source-plan unit.

Confidence is **Confirmed** for the fifteen guard intervals, ASTs, false edges,
source order, complete 72-cell input domain, first-true stop, all-false join,
read-only evaluation, source identities, and the conditional caller-local
prefix CFG. Confidence remains **Unresolved / unqualified** for every native
host, external-call completion, address-row selection and natural-eligibility
boundary listed above.

See [EVENTB03 station candidate route](eventb03_candidate_entry.md) for the
separate predicate beginning at `0x7691` and its source-local fallthrough to the
EVENTB03 handoff.

Content Core `0.282.0` keeps both child receipts intact and joins them only in
the read-only [Station-to-EVENTB03 Decision](station_eventb03_decision.md),
using one caller-supplied frozen snapshot at the assumed `0x026D` entry.
