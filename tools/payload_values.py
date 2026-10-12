"""Payload helpers shared by the versioned Python tools (TD-05).

Every tool that names a document by its fingerprint used to carry its own copy
of these functions.  The bodies here are the copied ones, unchanged: a stored
``payload_sha256`` depends on ``canonical_payload_bytes`` byte for byte, so its
JSON settings are part of every contract that uses it and must not change.
A tool with a different canonical form keeps its own function.

``is_gallery_registry_row`` is the one predicate for an album-scene row of the
name registry, shared by the catalog promoter and the v6 projector (EP-12);
``is_talk_registry_row`` is the one for a conversation script (EP-12 TALK), shared
by the same two tools and the registry builder's ``TALK_STEM``.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path
from typing import Any, Callable


# The package inventory's vocabulary (WD-21 U1, `content_core/playback_media_classifier.gd`
# `KINDS` and `content_core/content_core_version.gd` `PLAYBACK_MEDIA_INVENTORY_SCHEMA`),
# read by the known-absent register writer, the event-definition validator and the v7
# projector: one definition here, not one per reader.
MEDIA_KINDS = ("mmo", "ax", "voice", "se", "a6", "bgm", "unclassified")
MEDIA_INVENTORY_SCHEMA = "kakyu_media_inventory/v1"


def canonical_payload_bytes(document: dict[str, Any]) -> bytes:
    """Canonical UTF-8 JSON of ``document`` without its ``payload_sha256``."""
    payload = dict(document)
    payload.pop("payload_sha256", None)
    return json.dumps(
        payload,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def fingerprint(document: dict[str, Any]) -> str:
    """SHA-256 of the canonical payload, the value stored as ``payload_sha256``."""
    return hashlib.sha256(canonical_payload_bytes(document)).hexdigest()


# SHA-256 of the unpatched original AI5WIN.exe, whatever the file is named.
ORIGINAL_EXECUTABLE_SHA256 = "3fef4e2f6dde28c8aaa754a01accca4acadedb0dc67b25d298a303ad350a82f5"


def is_sha256(value: Any) -> bool:
    """True for a 64-character lower-case hexadecimal string."""
    return (
        isinstance(value, str)
        and len(value) == 64
        and all(character in "0123456789abcdef" for character in value)
    )


def is_safe_leaf(value: Any) -> bool:
    """The playback catalog's ``_safe_leaf`` rule (``content_core/event_catalog.gd``,
    WD-21 U2): a non-empty string with none of ``/``, ``\\``, ``..`` or ``:``. A
    v7 resource's ``entry`` and ``name`` become a catalog item's ``request_entry``
    and ``entry``, so the event-definition validator and the catalog promoter
    apply this one predicate."""
    return (
        isinstance(value, str)
        and value != ""
        and "/" not in value
        and "\\" not in value
        and ".." not in value
        and ":" not in value
    )


def is_gallery_registry_row(registry_row: Any) -> bool:
    """A name-registry row for an album scene (EP-12 gallery, 2026-10-04): its
    first dispatch is a ``SCENE_*`` call (``tools/build_event_names.py`` accepts
    one only from an album menu). The id keeps the ``special`` category
    fall-through; the catalog row carries ``gallery`` in ``display.categories``
    and the v6 flow document is a two-hop scene flow, not a date chain."""
    if not isinstance(registry_row, dict):
        return False
    callee = str(registry_row.get("evidence", {}).get("callee", ""))
    return str(registry_row.get("category", "")) == "special" and callee.upper().startswith("SCENE_")


# EP-12 TALK (2026-10-04, extended 2026-10-05): the conversation scripts a row can
# be declared for. `<letter A..L>_TALK<band>` (the eight affection-banded rungs
# `30`..`90`, `00`), the once-only plain `<letter>_TALK`, Tina's `M_TALK` and the
# non-heroine characters' `<letter N..Q>_TALK[<digit>]` (`N_TALK1`..`N_TALK3`,
# `Q_TALK1`). The follow-on `<letter>_TALKXX` / `<letter>_TALK<nn>` of a rung are
# not rows (members of their parent rung's route) and `TALK_STEM` does not match
# the `XX` form; the follow-on numbers `01`, `61`, ... are band-shaped and are
# kept out by the declared groups, not by this pattern.
TALK_STEM = re.compile(r"^(?:(?P<heroine>[A-L])_TALK(?P<band>\d\d)?|(?P<tina>M)_TALK|(?P<other>[N-Q])_TALK(?P<digit>\d)?)$")


def talk_script_parts(stem: str) -> tuple[str, str] | None:
    """`(letter, band)` of a TALK script stem (`band` is `""` for a band-less script:
    the plain `<letter>_TALK`, `M_TALK`, `N_TALK`), `None` for any other stem."""
    match = TALK_STEM.match(stem)
    if match is None:
        return None
    letter = match.group("heroine") or match.group("tina") or match.group("other")
    return letter, (match.group("band") or match.group("digit") or "")


def is_talk_registry_row(registry_row: Any) -> bool:
    """A name-registry row for a conversation script (EP-12 TALK, 2026-10-04): its
    number is ``talk-<band>`` (``talk-plain`` for a band-less heroine script,
    ``talk-<letter><digit>`` for a non-heroine character's;
    ``tools/build_event_names.py`` numbers a TALK flow route that way) and its callee
    a ``TALK_STEM`` script. The catalog row is tagged ``conversation`` and the v6
    flow document lists only the entries its own route runs."""
    if not isinstance(registry_row, dict):
        return False
    callee = str(registry_row.get("evidence", {}).get("callee", "")).upper()
    stem = callee[:-4] if callee.endswith(".MES") else callee
    return str(registry_row.get("number", "")).startswith("talk-") and TALK_STEM.match(stem) is not None


def publish_new_document(
    path: Path,
    payload: bytes,
    temporary: Path,
    verify: Callable[[Path], None],
    *,
    descriptor: int | None = None,
) -> None:
    """Publish ``payload`` at ``path`` without ever replacing a name (WD-10).

    The one hard-link publication rule the versioned document writers share:
    write the payload to ``temporary``, flush and fsync it, run the caller's
    ``verify(temporary)`` (which raises on a mismatch), then ``os.link`` it to
    ``path`` - which fails with ``FileExistsError`` rather than replace an
    existing name, a race included - and always remove ``temporary``.

    Once the link exists the publication has succeeded, and ``temporary`` is
    only a second name for the published file: failing to remove it then is
    clutter, not a failed publication, so that one ``OSError`` is swallowed.
    Before the link, a failed removal still propagates as it always did.

    What stays with the caller: the temporary's name, whether a missing
    parent is created or refused, and any exception mapping. ``temporary``
    is created exclusively here (``"xb"``); a caller that already created it
    with ``tempfile.mkstemp`` passes that file's ``descriptor`` instead and
    the helper takes it over.
    """
    published = False
    try:
        stream = temporary.open("xb") if descriptor is None else os.fdopen(descriptor, "wb")
        with stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        verify(temporary)
        os.link(temporary, path)
        published = True
    finally:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            if not published:
                raise


def sha256_file(path: Path) -> str:
    """SHA-256 of a file, read in one-mebibyte chunks."""
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


# Typed-record grammar for the few synthetic MES records whose exact encoding is the
# subject of a test or of a tool's search (WD-25 item 1b, treatment G). A record built
# here has no free operand: changing any byte names a different engine function or
# breaks the record's decoding, so a fixture cannot be made synthetic by an operand
# change. Each such record is built once, from these constants, and every site takes
# it from here; the byte guard cannot see bytes built this way, so each record is
# listed in the closure of the unit with its consumer and its sites. The names and
# values are the typed-record grammar of `docs/spec/mes/format_and_method.md`:
# command `0x12` is the native typed-record dispatch ingress, an expression record is
# tag `0x02` + an expression + `0xFF`, token `0x80` is `state_u16[u8_index]`, and the
# record list ends with `0x00`.
COMMAND_NATIVE_RECORD_DISPATCH = 0x12
EXPRESSION_RECORD_TAG = 0x02
EXPRESSION_END = 0xFF
RECORD_LIST_END = 0x00
TOKEN_STATE_U16_BY_U8_INDEX = 0x80
MAP_MODULE = 6  # `Util(6,n)`, "The map module behind `Util(6,n)`"
MAP_GET_LOCATION = 13  # `Util(6,13)` = map_get_location
ROUTINE_40_SELECTION_GROUP = 1  # `Util(1,21,x)`, the routine-40 selection record
ROUTINE_40_SELECTION_FUNCTION = 21


def state_u16_expression(index: int) -> bytes:
    """The expression `state_u16[index]` for a byte index."""
    return bytes([TOKEN_STATE_U16_BY_U8_INDEX, index])


def expression_record(expression: int | bytes) -> bytes:
    """One expression record: an inline literal (below `0x40`) or an expression's bytes."""
    body = bytes([expression]) if isinstance(expression, int) else bytes(expression)
    return bytes([EXPRESSION_RECORD_TAG]) + body + bytes([EXPRESSION_END])


def native_record_dispatch(*expressions: int | bytes) -> bytes:
    """A command-`0x12` dispatch: one expression record per argument, then the list end."""
    return (
        bytes([COMMAND_NATIVE_RECORD_DISPATCH])
        + b"".join(expression_record(expression) for expression in expressions)
        + bytes([RECORD_LIST_END])
    )


def map_location_poll() -> bytes:
    """The map module's location poll, `Util(6,13)`."""
    return native_record_dispatch(MAP_MODULE, MAP_GET_LOCATION)


def routine_40_selection(argument: int | bytes) -> bytes:
    """The routine-40 selection record, `Util(1,21,argument)`: the first selection passes
    the literal `0`, the second `state_u16[21]` (`state_u16_expression(21)`)."""
    return native_record_dispatch(ROUTINE_40_SELECTION_GROUP, ROUTINE_40_SELECTION_FUNCTION, argument)
