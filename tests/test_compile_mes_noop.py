from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import compile_mes_noop as compiler  # noqa: E402
import decompile_mes_handoff as decompiler  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
from tests import test_decompile_mes_handoff as decompiler_tests  # noqa: E402


class MesNoopCompilerTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, bytes]:
        handoff, raw = decompiler_tests.MesDecompilerLinearIrTests().fixture()
        linear = decompiler.lift(handoff)
        return editable_ir.prepare(linear), raw

    def test_prepares_deterministic_empty_operation_document(self) -> None:
        first, _raw = self.fixture()
        second, _raw = self.fixture()

        self.assertEqual(editable_ir.EDITABLE_IR_SCHEMA, first["schema"])
        self.assertEqual([], first["operations"])
        self.assertEqual(first, second)
        self.assertEqual(first["payload_sha256"], editable_ir.fingerprint(first))
        self.assertEqual(1, first["capability_report"]["opaque_node_count"])

    def test_compiles_byte_identical_container_and_audit(self) -> None:
        document, raw = self.fixture()
        output, audit = compiler.compile_noop(document)

        self.assertEqual(raw, output)
        self.assertEqual(compiler.NOOP_AUDIT_SCHEMA, audit["schema"])
        self.assertEqual(hashlib.sha256(raw).hexdigest(), audit["output"]["entry_sha256"])
        self.assertEqual(1, audit["coverage"]["opaque_node_count"])
        self.assertTrue(all(audit["invariants"].values()))
        self.assertEqual(
            audit["payload_sha256"], compiler.fingerprint(audit)
        )

    def test_rejects_rehashed_operation_before_compilation(self) -> None:
        document, _raw = self.fixture()
        document["operations"].append(
            {"kind": "replace_message", "source_offset": 0, "text": "test"}
        )
        document["payload_sha256"] = editable_ir.fingerprint(document)

        with self.assertRaisesRegex(
            editable_ir.EditableIrError, "operation is not supported"
        ):
            compiler.compile_noop(document)

    def test_rejects_mutated_embedded_source_even_when_wrapper_is_rehashed(self) -> None:
        document, _raw = self.fixture()
        document["source_ir"]["nodes"][0]["statement"]["op"] = "guessed"
        document["payload_sha256"] = editable_ir.fingerprint(document)

        with self.assertRaisesRegex(
            decompiler.DecompilerIrError, "fingerprint changed"
        ):
            editable_ir.validate(document)

    def test_rejects_rehashed_audit_with_changed_output_hash(self) -> None:
        document, raw = self.fixture()
        _output, audit = compiler.compile_noop(document)
        audit["output"]["entry_sha256"] = "0" * 64
        audit["payload_sha256"] = compiler.fingerprint(audit)

        with self.assertRaisesRegex(compiler.NoopCompileError, "differs"):
            compiler.validate_audit(audit, document, raw)

    def test_rejects_rehashed_audit_with_unknown_field(self) -> None:
        document, raw = self.fixture()
        _output, audit = compiler.compile_noop(document)
        audit["ignored_edit"] = {"kind": "replace"}
        audit["payload_sha256"] = compiler.fingerprint(audit)

        with self.assertRaisesRegex(compiler.NoopCompileError, "fields changed"):
            compiler.validate_audit(audit, document, raw)

    def test_reopen_rejects_nonincreasing_address_table(self) -> None:
        payload = bytearray(12)
        payload[:4] = (2).to_bytes(4, "little")
        payload[4:8] = (0).to_bytes(4, "little")
        payload[8:12] = (0).to_bytes(4, "little")
        payload.extend(b"\x00")

        with self.assertRaisesRegex(compiler.NoopCompileError, "not increasing"):
            compiler.reopen_container(bytes(payload))

    def test_new_file_publication_refuses_existing_output_without_temp(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            output = directory / "editable.json"
            output.write_text("existing", encoding="utf-8")
            with self.assertRaisesRegex(editable_ir.EditableIrError, "already exists"):
                editable_ir.publish_new(output, b"replacement")

            self.assertEqual("existing", output.read_text(encoding="utf-8"))
            self.assertEqual([output], list(directory.iterdir()))

    def test_json_round_trip_preserves_editable_and_audit_documents(self) -> None:
        document, _raw = self.fixture()
        output, audit = compiler.compile_noop(document)
        loaded_document = json.loads(
            editable_ir.canonical_json_bytes(document).decode("utf-8")
        )
        loaded_audit = json.loads(
            editable_ir.canonical_json_bytes(audit).decode("utf-8")
        )

        editable_ir.validate(loaded_document)
        compiler.validate_audit(loaded_audit, loaded_document, output)


if __name__ == "__main__":
    unittest.main()
