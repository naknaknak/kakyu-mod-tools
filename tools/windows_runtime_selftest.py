"""Small source-free runtime diagnostic shipped with Windows applications."""
import json
import sys

import PIL
from PIL import Image
import mes_authoring_workflow as workflow
import mes_authoring_binding
import authored_mod_delta


def main() -> None:
    # Entirely authored fixture: one literal write, one short message and return.
    raw = bytes.fromhex("0100000000000000031e0101ff000182a00000")
    source = {"archive": "mes.arc", "entry": "SYNTHETIC.MES", "archive_sha256": "a" * 64, "source_kind": "original_arc"}
    files = workflow.analyze(raw, source)
    model = json.loads(files["editable.json"])
    state_edit = workflow.state_controls(model)[0]["operation"]
    state_edit["value"] = 2
    built = workflow.compile_edit(files, state_edit)
    assert built["output.mes"] == raw[:11] + b"\x02" + raw[12:]
    proof = json.loads(built["semantic.diff.json"])
    assert proof["operation"]["family"] == "state_literal_edit"
    assert Image.new("RGB", (2, 2)).resize((4, 4)).size == (4, 4)
    print(json.dumps({"ok": True, "schema": "kakyu_windows_runtime_selftest/v1", "python": sys.version.split()[0],
                      "pillow": PIL.__version__, "isolated": sys.flags.isolated,
                      "producer": json.loads(files["handoff.json"])["producer"]["implementation"],
                      "state_edit": True, "image_codec": True, "delta_and_binding_imports": True}))


if __name__ == "__main__":
    main()
