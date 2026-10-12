# Frozen Phase 1-4 comparison evidence

`frozen_gd_instruction_v45.jsonl` is the verified 1,016-entry GDScript digest
whose ordered payload fingerprint is
`74f1408836440b7194ffb25aaa498aa8b61bda695326ed148ccd35a562a1dff8`.
It was regenerated on 2026-09-15 for Core 0.320.0 (MA-11), which gives every
state-storage write run a write row in `references.state`; 667 payloads
changed in that component only. It supersedes the Core 0.316.0 fingerprint
`617111b9e4987976301774604ccef51ee4d589b9c53976c4191f851d5d94277b` (regenerated
2026-09-13 for the command-`0x0D` system-call framing, approved by the owner
on 2026-09-14), which in turn superseded the fingerprint approved on
2026-09-06, `fae349f9affbaf244f44fe61f3afc380cb980f058950fe85fcb1f7d097eab6f5`.
The owner approved the 0.320.0 fingerprint on 2026-09-15; the record is the
tracker item in `todo/mes_analyzer.md` ("Current Verification Gate").
It contains entry identities, component/payload hashes and structural counts;
it contains no dialogue, bytecode, raw archive data, or machine-specific paths.
The JSONL header/footer use `kakyu_mes_handoff_digest/v1`.

The authoritative Python producer reads the original archive and compares full
handoffs against this historical evidence under the explicitly labelled
`producer_implementation_only/v1` policy. Actual Python hashes are separate
from the projected comparison hashes. The normal `--elfimage` validation batch
runs this complete comparison without a limit and also keeps the historical
GDScript completion audit. It does not need an untracked generated digest to
exist on the user's machine.

Reproduction uses `tools/content_suite/cli/export_mes_handoff_digest.gd` on the
read-only authoritative `mes.arc`, followed by
`tools/audit_mes_handoff_equivalence.py --require-full-equivalent`. A changed
baseline must be deliberately reconciled with the MES evidence and approved
authority fingerprint; do not regenerate this fixture merely to make a test
pass. See `docs/spec/mes/format_and_method.md` and `todo/mes_pipeline.md`.
