"""Read the user's own original executable for the native-audit tests.

WD-25 item 1: no tracked file holds a copy of the original executable, so the
tests that need a byte-faithful replica of audited regions read the content
from the user's executable at run time and use it only after its SHA-256
matches the expectation (`ByteSpan`).

This is not a `test_*` module, so test discovery skips it. It imports with the
native audits absent: the module level uses only the standard library, and the
audit modules are imported lazily inside `runtime_image()` and
`launcher_image()`. The executable is named by the environment variable alone;
there is deliberately no fallback to `.agents/local/source_paths.md`, because
the validation cache fingerprints the executable only when the batch passes it.
"""

from __future__ import annotations

import hashlib
import importlib
import os
import sys
import unittest
from pathlib import Path
from typing import Any

ENVIRONMENT_VARIABLE = "KAKYU_ORIGINAL_EXE"
SKIP_REASON = (
    f"{ENVIRONMENT_VARIABLE} is not set; the native-audit fixtures are read from "
    "the user's own executable"
)

_TOOLS = Path(__file__).resolve().parents[1] / "tools"
_RAW: dict[str, bytes] = {}
_IMAGES: dict[str, Any] = {}


class OriginalExecutableError(RuntimeError):
    """The variable is set but names something other than the original executable."""


def environment_path() -> Path | None:
    """The executable named by the environment variable, or None when unset or empty."""
    value = os.environ.get(ENVIRONMENT_VARIABLE, "")
    if not value.strip():
        return None
    return Path(value)


def raw_bytes() -> bytes:
    """The executable's bytes, read once per process; no audit module is imported."""
    path = environment_path()
    if path is None:
        raise OriginalExecutableError(SKIP_REASON)
    key = str(path)
    if key not in _RAW:
        try:
            _RAW[key] = path.read_bytes()
        except OSError as error:
            raise OriginalExecutableError(
                f"{ENVIRONMENT_VARIABLE} does not name a readable file: {error.strerror}"
            ) from error
    return _RAW[key]


requires_original_executable = unittest.skipUnless(environment_path() is not None, SKIP_REASON)


def _audit(name: str) -> Any:
    """Import one audit module on demand; the guard never calls this."""
    if str(_TOOLS) not in sys.path:
        sys.path.insert(0, str(_TOOLS))
    return importlib.import_module(name)


def _image(kind: str) -> Any:
    data = raw_bytes()
    key = f"{environment_path()}|{kind}"
    if key not in _IMAGES:
        mes = _audit("audit_ai5_mes_exe")
        offset = mes.OUTER_LAUNCHER_PAYLOAD_OFFSET
        if hashlib.sha256(data[offset:]).hexdigest() != mes.ORIGINAL_RUNTIME_PAYLOAD_SHA256:
            raise OriginalExecutableError(
                f"{ENVIRONMENT_VARIABLE} does not name the original executable: the runtime payload "
                "hash differs from the one the audits pin"
            )
        part = data[offset:] if kind == "runtime" else data[:offset]
        _IMAGES[key] = _audit("audit_ai5_arc_exe").PeImage(part)
    return _IMAGES[key]


def runtime_image() -> Any:
    """The original runtime PE (the payload inside the launcher), hash-checked."""
    return _image("runtime")


def launcher_image() -> Any:
    """The original outer launcher PE (the bytes before the runtime), hash-checked."""
    return _image("launcher")


def span_content(image: Any, address: int, span: Any) -> bytes:
    """The span's bytes at `address`, read from `image`, or a named error on a hash mismatch."""
    content = _audit("audit_ai5_arc_exe").span_bytes(image, address, span)
    if content is None:
        raise OriginalExecutableError(
            f"the executable differs from the audited original at 0x{address:08X} "
            f"({span.length} bytes)"
        )
    return content
