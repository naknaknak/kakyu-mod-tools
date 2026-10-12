# libai5 bridge: a second, complete MES grammar

Added 2026-09-13 after a search for existing AI5WIN tooling. Nunuhara's
`libai5` (https://github.com/nunuhara/libai5, GPL-2.0) is the parser and
printer behind `elf-tools` (`elf mes decompile`) and `ai5-sdl2`, a
cross-platform reimplementation of elf's AI5WIN engine that lists 下級生
(1998) among its supported games. The library carries one statement grammar
per engine generation; the generation whose table has the address-table
header, the `0x0B..0x1F` statement numbering and `DEF_SUB` / `CALL_SUB` -
libai5's `nonomura` id (野々村病院の人々, 2003) - is the one this archive
uses. Against `ELFIMAGE/mes.arc` (SHA256 `31a95b31…86aa6`) it parses **all
1,016 entries completely, with no warning**, in nine seconds; the repo's
Phase 1-4 decoder leaves 1,251 fail-closed opaque tails (734,485 bytes) in
the same archive.

The bridge keeps libai5 outside the tracked tree (it is GPL-2.0 and this
repository has not adopted a licence): `tools/libai5_bridge/build_mesdump.py`
clones it shallowly into `analysis/ext/libai5`, compiles it and the one
bridge source `tools/libai5_bridge/mesdump.c` with gcc (Strawberry's mingw
toolchain, libpng and zlib; no meson, flex or bison), and writes
`analysis/ext/mesdump.exe`. `tools/libai5_bridge/mes_libai5.py` feeds entry
bytes through a pipe - nothing from the archive is written to disk - and
prints code-relative listings, a corpus histogram (`--coverage`) or the
reconciliation of every repo opaque tail against libai5's statements
(`--reconcile`). `tests/test_libai5_bridge.py` covers the output parser.

    py tools/libai5_bridge/build_mesdump.py
    py tools/libai5_bridge/mes_libai5.py --arc "<ELFIMAGE>\mes.arc" EVENTJ11.MES 15280 15480

A second external checkout joined on 2026-09-14: nunuhara's `ai5-sdl2`
(https://github.com/nunuhara/ai5-sdl2, GPL-2.0), the engine
reimplementation, cloned shallowly by hand into `analysis/ext/ai5-sdl2` and
neither built nor linked. Its `src/kakyuusei.c` and `src/map.c` are the
reading behind the map module's utility numbering (`Util(6,8)` runs the
sprites, `Util(6,13)` writes the player's location into `state_u16[18]`) that
Core 0.318.0's map-location contracts model; the repository copies nothing
from it.

## What the two decoders disagree about

The statement numbering agrees with the repo's command table: `0x0B` branch,
`0x0C` jump, `0x0E` root handoff (`jump("machi.mes")`), `0x0F` nested call,
`0x10` choice definition, `0x11` definition invoke, `0x12` util record,
`0x14`, `0x15` selection loop, `0x17` entry prologue, `0x1B`, `0x1C` / `0x1D`
library routine registration and transfer (`call_sub(40)` is the repo's
"routine 40"), `0x1F` source-line marker; the expression encoding agrees as
well, and every coordinate libai5 prints matches the typed IR's.

The disagreement is command `0x0D`. The repo frames it as an operand-free
"statement separator" (278,155 records) whose following bytes are read as
further commands - the "protagonist name insert" `0x0E FF 02 … 00`, the
"cursor control" `0x13 FF`, the filename-bearing `0x09`, and the rare
`0x05` / `0x08` / `0x15` / `0x16` / `0x1A` shapes - and its native audit
describes the handler as a bounded presentation stream. libai5 reads `0x0D`
as **one system call**: an expression selecting the function, then a typed
parameter list (`02 <expression> FF`, `01 <string> 00`, `00` end). Under
that grammar the repo's pseudo-commands are the system functions:

| repo reading | libai5 reading | corpus count |
|---|---|---|
| `0x13` with operand `FF` (133,045) | `System.function[19](2)` | 133,454 |
| `0x0E` protagonist-name insert (80,272 by libai5) | `System.function[14](System.memory + System.heap + 2880)` | 80,272 |
| `0x09` filename form / argument writes | `System.function[9]("bll.mmo")`, `System.function[8](0,"machi.mpc",System.ccd_offset)` | 7,672 / 2,609 |
| `0x0D` subcommand `0x0B`, a "typed surface-operation record" | `System.function[11](1,0,0,639,399,2,0,0,1)` | 11,316 |
| `0x0D` subcommand `7`, the audio / voice record | `System.function[7](2,"j0093.ogg",0)` | 26,070 |
| `0x05` "global_u8 writes from an expression index" (45) | `System.function[5](2)` | 932 |
| unreconciled `0x18` | `System.function[24](4,0,"bll.mmo",0,0)` | 673 |

Every opaque tail examined so far starts one byte after a `0x0D` the repo
consumed as a separator: `EVENTJ11.MES:15363` is the body of
`System.function[24](4,0,"bll.mmo",0,0)` at `15362..15387`, followed by the
voice call `System.function[7](2,"j0093.ogg",0)`; `EVENTJ11.MES:21691` is
`System.function[5](2)`; `FLOOR4.MES:2074` is `System.function[8](0,"machi.mpc",
System.ccd_offset)` after `Util(6,24,"machin_3.pal",0)`; `27C_EV.MES:83020`
is `System.function[8](0,"floor5.mpc",System.ccd_offset)` before the
`jump("floor5.mes")` at `83150`.

The full reconciliation (`--reconcile`, 2026-09-13): the current handoff
build leaves **1,180** opaque tails in the 1,016 entries, and libai5 covers
**every one of them with a `0x0D` system-call statement** - 1,168 tails
begin exactly one byte after the statement's `0x0D`, the other twelve a few
bytes in, where the repo's grammar consumed part of the selector expression
before failing. By function: `System.function[5](2)` 840 tails (the repo's
"command `0x05`" failure), `System.function[24](4,0,…)` 214 (the "`0x18`"
failure), `System.function[8](0,"<name>.mpc"/".ccd",…)` 81 (the "`0x08`"
failure), `System.function[5](1)` 9, `System.function[1](…)` 9,
`System.function[10](1,0)` 6, `System.function[9]("…")` 5 and
`System.function[4](…)` 5 (the "`0x0A`" / "`0x04` expression pair"
failures). No tail is anything else.

Consequences the owner has to rule on, none of them applied here:

- The 44M J11 finding of this morning is corrected: there is no command
  `0x18` at `EVENTJ11.MES:15363`. The byte is the function selector of a
  system call; the bounded runtime's "address-table dispatch back into the
  first body" is its `jump_table` reading of that misframed byte. Natively
  the second body loads a picture, plays voice `j0093.ogg` and continues to
  the doors at `18898` or `26749`. The group can be re-qualified once the
  runtime frames `0x0D` as a call.
- The 1,251 opaque tails and the runtime's `native_presentation_boundary`
  stops for `0x0D` are one grammar gap, not native opacity. Fixing the
  decoder's `0x0D` rule (expression + parameter list) is a contract change
  to the structural authority; libai5's `parse.c` is a reference
  implementation, and `ai5-sdl2`'s `vm.c` / per-game `sys` tables give the
  runtime semantics of each system function.
- Until then the bridge is a reading aid and a cross-check: it names the
  system call behind every presentation record in a route, which the
  caller-group docs can cite, and it is the tool to consult before calling
  any record "unreconciled".

## Decision and outcome (2026-09-13)

The owner ruled for option (c): the bridge stays as the cross-check, and the
decoder change landed in Core 0.316.0. A survey of all 292,502 `0x0D` records
under both framings (`sys_call_survey.py`, scratch) showed that the separator
reading had also manufactured records inside calls it did frame - a fake
command-`0x00` return inside each of the 133,454 message waits, 1,313 fake
`global_u8` writes inside function-2 calls, about a thousand fake continuation
transfers inside function-12 calls - so the grammar was adopted whole rather
than as a fallback. Both decoders now read one call; the runner keeps the
message counts and dialogue boundaries of the committed groups; the archive
decodes with no opaque tail. `format_and_method.md`, "Command `0x0D` is one
system call", is the record; the corpus-record counts in its command table
still describe the 2026-09-06 framing.

## Other tools found

- `elf-tools` (same author): `elf arc extract`, `elf mes decompile` /
  `compile` with a text-substitution workflow; needs flex and bison to build,
  which this machine lacks - the bridge links libai5 directly instead.
- `ai5-sdl2`: the engine reimplementation (kakyuusei 1998, doukyuusei,
  YU-NO classics, …); not runnable against this archive's generation as is,
  but `src/vm.c`, `src/kakyuusei.c` and `include/vm.h` document the
  statement and system-function semantics.
- `mnakamura1337/engine_ai5v`: the older AI5V / DOS-era format (different
  opcodes); not applicable.
- GARbro: archive extraction only, which `tools/extract_kakyu_arc.py`
  already covers.
