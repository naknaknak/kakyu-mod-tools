from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from validate_mes_analyzer_handoff import (
    COMPONENT_SCHEMAS,
    HandoffValidationError,
    _find_product_ui_key,
    fingerprint,
)


COMPLETION_SCHEMA = "kakyu_mes_analyzer_completion/v1"
HANDOFF_SCHEMA = "kakyu_mes_analyzer_handoff/v1"
CORPUS_HANDOFF_SHA256 = "74f1408836440b7194ffb25aaa498aa8b61bda695326ed148ccd35a562a1dff8"
EXPECTED_COUNTS = {
    "entries": 1016,
    "code_bytes": 18079488,
    "analysis_instructions": 1708940,
    "messages": 221000,
    "code_references": 209063,
    "state_references": 561522,
    "resource_references": 36149,
    "analysis_diagnostics": 0,
    "analysis_opaque_boundaries": 0,
    "analysis_opaque_bytes": 0,
    "alignment_instructions": 1708940,
    "alignment_compound_records": 500677,
    "alignment_opaque_boundaries": 0,
    "alignment_opaque_bytes": 0,
}


def validate(document: dict[str, Any]) -> dict[str, Any]:
    if document.get("schema") != COMPLETION_SCHEMA:
        raise HandoffValidationError("unsupported MES analyzer completion schema")
    if document.get("handoff_schema") != HANDOFF_SCHEMA:
        raise HandoffValidationError("unsupported MES analyzer handoff dependency")
    if document.get("component_schemas") != COMPONENT_SCHEMAS:
        raise HandoffValidationError("MES analyzer completion component schemas changed")
    if document.get("corpus_handoff_sha256") != CORPUS_HANDOFF_SHA256:
        raise HandoffValidationError("MES analyzer corpus handoff fingerprint changed")
    if document.get("phase_status") != {str(phase): "closed" for phase in range(1, 5)}:
        raise HandoffValidationError("MES analyzer Phase 1-4 status is not closed")
    if document.get("counts") != EXPECTED_COUNTS:
        raise HandoffValidationError("MES analyzer completion counts changed")
    if not document.get("supported_typed_forms"):
        raise HandoffValidationError("MES analyzer typed-form inventory is empty")
    if not document.get("explicit_native_boundaries"):
        raise HandoffValidationError("MES analyzer native-boundary inventory is empty")
    if not document.get("explicit_opaque_boundaries"):
        raise HandoffValidationError("MES analyzer opaque-boundary inventory is empty")
    if not document.get("remaining_numeric_or_unresolved_meanings"):
        raise HandoffValidationError("MES analyzer unresolved-meaning inventory is empty")
    ui_key = _find_product_ui_key(document)
    if ui_key is not None:
        raise HandoffValidationError(f"product UI field is forbidden: {ui_key}")
    retained = document.get("payload_sha256")
    if not isinstance(retained, str) or fingerprint(document) != retained:
        raise HandoffValidationError("MES analyzer completion fingerprint changed")
    return {
        "ok": True,
        "schema": COMPLETION_SCHEMA,
        "payload_sha256": retained,
        "corpus_handoff_sha256": CORPUS_HANDOFF_SHA256,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate the Kakyu MES Phase 1-4 completion report."
    )
    parser.add_argument("completion", type=Path)
    args = parser.parse_args()
    with args.completion.open("r", encoding="utf-8") as stream:
        document = json.load(stream)
    result = validate(document)
    print(
        "MES_ANALYZER_COMPLETION_PYTHON_PASS "
        f"schema={result['schema']} payload_sha256={result['payload_sha256']} "
        f"corpus_sha256={result['corpus_handoff_sha256']}"
    )


if __name__ == "__main__":
    main()
