# Compiler and framing region counts

The Phase 5 linear IR retains one bootstrap region, including an empty region
when address entry zero starts at code offset zero. Its region count is the
address-table entry count plus one. Phase 6 compile audits copy that source IR
coverage and keep the same meaning.

The Phase 1-4 record-alignment audit instead counts nonempty byte regions. An
empty bootstrap owns no bytes and adds nothing to that framing count. These
counts are intentionally different; neither format or fingerprint is changed.

Content Core 0.301.0 uses `mes_compile_coverage.gd` to check the two meanings
independently in the no-op, state literal, condition literal, resource name,
inline script name, registered call, shared routine call and control-target
edit reopen validators. Their compile/reopen coverage keeps the compiler's
region count. Comparing it directly with framing count previously rejected
valid output from a source whose first address entry was zero.

The regression includes an authored entry with an empty bootstrap, one state
write, a message and a return. Python handoff → actual Phase 5/6 compilation →
Godot reopening now succeeds; an audit omitting the bootstrap is rejected.
The existing eight family fixtures now use the count their real Python producer
emits. No original instruction meaning or native execution claim is added.
