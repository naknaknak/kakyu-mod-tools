# Station candidate conditional prefix

## Scope and evidence boundary

Content Core `0.281.0` exposes
`kakyu_mes_station_candidate_prefix_plan/v1`, a source-bound, read-only
structural projection of `01M.MES:0x0008..0x026D`. This is the code interval
between the conditional coordinate-zero bootstrap's entry-0 path and the first
station candidate guard. The plan preserves every typed record, the caller-local
control-flow relationships and the external/native checkpoints in source
order. It does not execute the interval or accept an initial game-state input.

That distinction is required. Several calls in the interval are not certified
to return with known effects, and one native presentation operation contains a
wait. The plan therefore does not calculate a post-prefix state and does not
claim that a native host reaches `0x026D`. Its join is conditional on every
external boundary reached along the selected arm completing. It adds no Event
Player preset and does not qualify EVENTB03's natural scheduler eligibility.

All MES intervals below are code-relative, half-open `[start,end)`. No original
dialogue, lossless bytecode, archive payload or machine-specific path is
retained in this document or in the plan.

## Authoritative identities

| Source | SHA-256 |
|---|---|
| `mes.arc` | `31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6` |
| `01M.MES` entry | `a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5` |
| `01M.MES` bytecode | `f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b` |
| coordinate-zero bootstrap `0x0000..0x0008` | `1d5fcfa66928c2bd712394fcd5e001e48b41b60f943039c72d06687224953e5c` |
| conditional prefix `0x0008..0x026D` | `4a669e767c925e7a988c0b7c169be9a250095a3091d4d20bb1d4e7b0cde24289` |
| `data.arc` | `b069c4dbb67d67eaf9252babc02f100fbc16c0740a189b007ff31535305727e4` |
| `MACHI.EVE` entry | `9f56d74f8c53fc3ee2ad17918519f677e3ebf9070097921190e3ea6de2833d62` |
| `MACHI.EVE:0x00C0..0x00CC` event-16 record | `538fe2444347fb43fb1c0c93bfb7297b589835cc2b1ef1e99a875d4b035edb0a` |
| `MACHI.MES` entry | `56b0f4243f3c0944624ea0ef11b369391761ff394816775264c144bb76391488` |
| `MACHI.MES` bytecode | `34aea9b95996997a4657c89e848b59c0d04c1ba1fdeb26794252017b1d1a84cf` |
| `MACHI.MES:0xACB1..0xACBC` `01M.MES` handoff | `7d254587b79c85522f184d95301f986a3f72510128d8920dc163d7868c81c612` |
| `MACHI.MES:0xACBC..0xACC1` post-handoff source marker | `df6bcfedc4d229399c926e15ae84f4f67237f2122c06ce9c4f73385bf445adb6` |
| `MACHI.MES:0xACC1..0xACC6` caller-local continuation | `6d6a16f278741ca272be6d6092ce6e28c54f9b0b7fbf61e4043a7acbe23f0c19` |
| original EXE wrapper | `3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5` |
| embedded runtime at wrapper `0x1B000` | `5b49d5e2162b07420aaa1c9298677150e0a33d9c84ee8be09f1c719aad8597da` |

The plan additionally requires the original 426-cell `01M.MES` address table,
including entry 0 ownership of `0x0008..0x03AF`. The prefix hash alone cannot
substitute for that address ownership.

## Exact record partition

Current structural decoding partitions all 613 prefix bytes into exactly 103
typed records and zero opaque boundaries:

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

Each plan row retains only its source offset, end offset, typed operation and
record SHA-256. The full bytes and decoder-internal expression payloads are not
published. Revalidation decodes the unchanged source again and compares the
entire plan shape.

## Caller-local control flow

The plan records two local control-flow regions without executing them.

The first region initializes `state_u16[2]` to zero before the guard at
`0x016E..0x0178`. The true edge enters `0x0178`; the false edge exits at
`0x0196`. One iteration symbolically copies
`banked_u16[0][168 + state_u16[2]]` to
`banked_u16[0][31 + state_u16[2]]`, increments `state_u16[2]`, and follows
`0x0191..0x0196` back to `0x016E`. Under the local writes and unsigned-word
expression rules this loop has exactly 16 iterations, covering indices 0
through 15. This is a local structural proof, not a post-prefix state receipt.

The second region tests `global_u8[2847] == 1` at `0x01EF..0x01FA`. The true
edge executes the stored surface operation at `0x01FA..0x021F` and continues
at `0x0229`; the false edge calls shared routine 21 at `0x0224..0x0229` and
reaches the same join. The plan retains both edges and the common join while
omitting native pixels and refusing to treat routine completion as a local
fact.

## Ordered nonlocal boundaries

The following checkpoints interrupt a purely caller-local execution proof:

| Interval | Typed boundary | Qualification |
|---:|---|---|
| `0x0143..0x0148` | registered DEF 11 | target is exact; complete effects are unresolved |
| `0x0152..0x0157` | shared routine 32 | existing native CFG total-return certificate |
| `0x015C..0x0163` | AX selector 7 | typed metadata; native cell invalidation omitted |
| `0x019C..0x01A1` | shared routine 25 | cyclic CFG; total return not certified |
| `0x01A1..0x01B9` | three command-`0x12` records | exact records; native results/effects unresolved |
| `0x01C3..0x01CA` | AX selector 6 | typed metadata; native update omitted |
| `0x01CA..0x01D1` | AX selector 8 | typed activation/wait; cadence and completion omitted |
| `0x01DE..0x01E3` | shared routine 27, argument 1 = 11 | existing native CFG total-return certificate |
| `0x01EA..0x01EF` | shared routine 25 | same unresolved cyclic boundary |
| `0x0224..0x0229` | conditional shared routine 21 | existing native CFG total-return certificate |

DEF 11 proceeds through registered DEF 12 toward a bounded routine-26
boundary. Routine 25 can invoke that registered family. Command `0x12` also
retains native state-result uncertainty. These relationships explain why a
tool that simply skips the calls and evaluates the surrounding writes would
produce an unjustified state.

The plan consequently reports `post_prefix_state = not_computed`, external
completion as unresolved, native execution as false and `0x026D` only as a
conditional join. It does not expose a boolean switch that pretends the
external boundaries returned.

## MACHI host adjacency

`MACHI.EVE:0x00C0..0x00CC` associates station trigger coordinates with event
16. `MACHI.MES:0xACA2..0xACAC` checks event result 16, and the exact command-
`0x0E` record at `0xACB1..0xACBC` names `01M.MES`. The next MACHI records are
a source marker at `0xACBC..0xACC1` and command `0x0C` at
`0xACC1..0xACC6`, whose stored target is MACHI-local `0xEC21`. That adjacent
coordinate is therefore a caller continuation, not an encoded `01M.MES`
starting coordinate.

Executable audit `kakyu_ai5_mes_exe_audit/v317` was rerun against the original
wrapper and embedded runtime. Command `0x0E` reaches wrapper `0x004182EE` and
handler `0x00419210`; the checked handler path has no confirmed active-code
coordinate write, caller-coordinate restore, synchronous target call or fixed
callee start coordinate. The bounded evidence strengthens the negative claim
that the source handoff does not encode a row, but it cannot establish whether
the external native host starts `01M.MES` at coordinate zero.

The following remain explicitly unresolved:

- MACHI-to-`01M.MES` target stream installation and initial code coordinate;
- native address-table row selection;
- completion and state effects of DEF 11/12/26, routine 25, command `0x12`
  and AX selector 8 in this session;
- the resulting state at `0x026D` and full natural scheduler eligibility.

The minimum observation for the host-start questions remains one owner-
qualified trace from `MACHI.MES:0xACB1` through archive lookup, stream/context
installation and the first same-owner `01M.MES` target execution coordinate.
Full event-terminal replay is not required merely to identify that start.

## Reproduction

Run the read-only validator with the configured original source directory:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . `
  --script res://tools/content_suite/cli/validate_mes_station_candidate_prefix_plan.gd -- `
  <ELFIMAGE-directory>
```

The authoritative run passes **314 checks** covering the exact record
partition, local flow, ordered external checkpoints, deterministic rebuild and
JSON replay, the conditional coordinate-zero bootstrap, MACHI host adjacency
and unchanged source archives. The focused synthetic regression passes **246
checks**. These counts are reproducibility markers, not semantic guarantees.

## Evidence and confidence

Evidence consists of direct read-only decoding from authoritative `mes.arc`
and `data.arc`, current GDScript record framing and expression ASTs, existing
source-bound shared/registered call audits, the original-EXE v317 static audit,
and exact source identities and record hashes. No original executable, archive,
save, media or UI is modified or executed by this plan.

Confidence is **Confirmed** for the prefix interval and hash, its complete
typed record partition, local loop and branch CFG, ordered typed checkpoints,
conditional join, MACHI source adjacency and read-only behavior. Confidence is
**Unresolved / unqualified** for every external-completion, post-state, native
host-start, address-row and scheduler boundary listed above.

See [Station candidate source priority](station_candidate_priority.md) for the
fifteen guards beginning at `0x026D`, and
[EVENTB03 station candidate route](eventb03_candidate_entry.md) for the
separate local candidate guard at `0x7691`.
