"""Shared authored-text rules (`text_encoding.md`, rules 2 to 4), factored
out of `tools/validate_event_definition.py`'s v4 `_check_resolved_text` so
the mod event definition contract (`kakyu_mod_event_definition/v1`, mod
event definition unit A) can use the same rules with its own switches.

    from tools.text_rules import check_text
    result = check_text(text, allow_line_break=True, placeholder="name")
    if result is not None:
        reason, detail = result

`check_text` implements exactly what `_check_resolved_text` checks today
(same reason codes `text_not_nfc`, `text_line_break`, `text_control_character`,
same detail wording, same check order: NFC first, then a whole-string line
break check, then a per-character sweep for control characters, U+FEFF,
U+FFFD, a noncharacter and a private-use character), plus two switches an
authored (mod) document needs and a resolved projection does not:

- `allow_line_break=True`: U+000A passes (it is an authored line break, not
  a violation); U+000D still fails as a control character, exactly as any
  other C0 control character does.
- `placeholder="name"`: `{name}` is the only allowed brace sequence in the
  text; any other `{...}` content, or an unbalanced `{`/`}`, fails
  `bad_placeholder`. Without `placeholder`, no brace is checked at all -
  the resolved-projection path (which never had a placeholder rule) is
  unaffected.
"""
from __future__ import annotations

import unicodedata

_CONTROL_RANGES = ((0x0000, 0x001F), (0x007F, 0x009F))


def _check_placeholders(text: str, placeholder: str) -> tuple[str, str] | None:
    """Scans `text` left to right for `{...}` sequences: `{<placeholder>}`
    passes; any other brace content, or an unbalanced `{` or `}`, fails
    `bad_placeholder`."""
    allowed = "{" + placeholder + "}"
    i = 0
    length = len(text)
    while i < length:
        ch = text[i]
        if ch == "{":
            end = text.find("}", i)
            if end == -1:
                return "bad_placeholder", f"unbalanced brace at offset {i}"
            token = text[i:end + 1]
            if token != allowed:
                return "bad_placeholder", f"{token!r} is not the {allowed!r} placeholder"
            i = end + 1
        elif ch == "}":
            return "bad_placeholder", f"unbalanced brace at offset {i}"
        else:
            i += 1
    return None


def check_text(
    text: str,
    *,
    allow_line_break: bool = False,
    placeholder: str | None = None,
) -> tuple[str, str] | None:
    """Rules 2 to 4 of `text_encoding.md` for authored text. Returns
    `(reason, detail)` on the first violation found, or `None` when `text`
    satisfies every rule."""
    if unicodedata.normalize("NFC", text) != text:
        return "text_not_nfc", "string is not NFC-stable"
    if not allow_line_break:
        if "\n" in text or "\r" in text:
            return "text_line_break", "string holds a line break"
    for ch in text:
        code = ord(ch)
        if allow_line_break and code == 0x000A:
            continue
        if any(lo <= code <= hi for lo, hi in _CONTROL_RANGES):
            return "text_control_character", f"U+{code:04X} is a control character"
        if code == 0xFEFF or code == 0xFFFD:
            return "text_control_character", f"U+{code:04X} is not allowed"
        if 0xFDD0 <= code <= 0xFDEF or (code & 0xFFFE) == 0xFFFE:
            return "text_control_character", f"U+{code:04X} is a noncharacter"
        category = unicodedata.category(ch)
        if category == "Co":
            return "text_control_character", f"U+{code:04X} is a private-use character"
    if placeholder is not None:
        result = _check_placeholders(text, placeholder)
        if result is not None:
            return result
    return None
