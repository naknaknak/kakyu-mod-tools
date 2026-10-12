from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from mes_handoff_transport import canonical_json_bytes


HANDOFF_SCHEMA = "kakyu_mes_analyzer_handoff/v1"
COMPONENT_SCHEMAS = {
    "container": "ai5_mes_container/v1",
    "instruction": "ai5_mes_instruction/v45",
    "analysis": "kakyu_mes_analysis/v19",
    "record_alignment": "kakyu_mes_record_alignment_audit/v1",
    "reference_graph": "kakyu_mes_reference_graph/v1",
}
CALL_EVIDENCE_SCHEMAS = [
    "kakyu_mes_registered_definition_call/v5",
    "kakyu_mes_caller_route/v1",
    "kakyu_mes_routine40_reachability/v1",
]
TRACE_EVIDENCE_SCHEMAS = [
    "kakyu_mes_event_trace/v68",
    "kakyu_mes_script_call_trace/v3",
    "kakyu_mes_registered_definition_trace/v7",
    "kakyu_mes_library_trace/v10",
]
PRODUCT_UI_KEYS = {
    "ui",
    "ui_state",
    "ui_label",
    "footer_label",
    "status_label",
    "event_catalog",
    "event_player",
    "preview_footer",
    "preview_message",
}


class HandoffValidationError(ValueError):
    pass


def canonical_payload_bytes(document: dict[str, Any]) -> bytes:
    payload = dict(document)
    payload.pop("payload_sha256", None)
    return canonical_json_bytes(payload)


def fingerprint(document: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_payload_bytes(document)).hexdigest()


def validate(document: dict[str, Any]) -> dict[str, Any]:
    if document.get("schema") != HANDOFF_SCHEMA:
        raise HandoffValidationError("unsupported MES analyzer handoff schema")
    compatibility = document.get("compatibility")
    if not isinstance(compatibility, dict):
        raise HandoffValidationError("missing MES analyzer compatibility contract")
    schemas = compatibility.get("component_schemas")
    if not isinstance(schemas, dict):
        raise HandoffValidationError("missing MES analyzer component schemas")
    for key, expected in COMPONENT_SCHEMAS.items():
        if schemas.get(key) != expected:
            raise HandoffValidationError(f"unsupported MES analyzer component schema: {key}")
    if schemas.get("accepted_call_evidence") != CALL_EVIDENCE_SCHEMAS:
        raise HandoffValidationError("unsupported MES analyzer call evidence schemas")
    if schemas.get("accepted_trace_evidence") != TRACE_EVIDENCE_SCHEMAS:
        raise HandoffValidationError("unsupported MES analyzer trace evidence schemas")
    ui_key = _find_product_ui_key(document)
    if ui_key is not None:
        raise HandoffValidationError(f"product UI field is forbidden: {ui_key}")
    retained = document.get("payload_sha256")
    if not isinstance(retained, str) or len(retained) != 64:
        raise HandoffValidationError("missing MES analyzer handoff fingerprint")
    actual = fingerprint(document)
    if actual != retained:
        raise HandoffValidationError("MES analyzer handoff fingerprint changed")
    return {
        "ok": True,
        "schema": HANDOFF_SCHEMA,
        "payload_sha256": retained,
    }


def _find_product_ui_key(value: Any) -> str | None:
    if isinstance(value, dict):
        for key, child in value.items():
            if key in PRODUCT_UI_KEYS:
                return key
            nested = _find_product_ui_key(child)
            if nested is not None:
                return nested
    elif isinstance(value, list):
        for child in value:
            nested = _find_product_ui_key(child)
            if nested is not None:
                return nested
    return None


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate a language-neutral Kakyu MES Phase 1-4 handoff."
    )
    parser.add_argument("handoff", type=Path)
    args = parser.parse_args()
    with args.handoff.open("r", encoding="utf-8") as stream:
        document = json.load(stream)
    result = validate(document)
    print(
        "MES_ANALYZER_HANDOFF_PYTHON_PASS "
        f"schema={result['schema']} payload_sha256={result['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
