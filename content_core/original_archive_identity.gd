class_name KakyuOriginalArchiveIdentity
extends RefCounted

## The pinned SHA-256 of every original archive this repository reads, in one
## place (WD-21 U1). Three station-plan validators and the playback package
## exporter each carried their own copy of the same six literals; this is the
## shared home, and a new copy is a defect.
##
## The six archives below are the long-standing pins. `tina1.arc` and
## `tina2.arc` (the two alternative voice banks the original chooses between
## with its `[Voice] TINA=1|2` setting) had no pin before WD-21 U1; theirs were
## measured live from the user-owned ELFIMAGE on 2026-10-06 and are recorded
## here once.

const MES_ARC_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const MMO_ARC_SHA256 := "b7623d1e8bdf5d153e2194989d9df46535026f37a5680939ea559e322ee03aea"
const DATA_ARC_SHA256 := "b069c4dbb67d67eaf9252babc02f100fbc16c0740a189b007ff31535305727e4"
const BGM_ARC_SHA256 := "80bdabcffff7f70c53591b8bfaa4ef0affb8582348d210d8b05e542a5741a278"
const SE_ARC_SHA256 := "4f428516b1582798faccd7ef0e44e271c70211eea1aab5209d60178860ee649a"
const VOICE_ARC_SHA256 := "12278db46895d35ddc73a489dd82857be560406ba83c5a7fdfac3ba415545322"
const TINA1_ARC_SHA256 := "6466e02bfe492e1a0820b12e4e942e907e866c45eaded81f46f4c3cb11e1aead"
const TINA2_ARC_SHA256 := "9cc5e7259ad6e308d0cf5d2ed3ca0d069de89b1474315a8e3c12995184cfc203"

## The six archives the station-plan validators pin, in their original order.
const SIX_ARCHIVE_SHA256 := {
	"mes.arc": MES_ARC_SHA256,
	"mmo.arc": MMO_ARC_SHA256,
	"data.arc": DATA_ARC_SHA256,
	"bgm.arc": BGM_ARC_SHA256,
	"se.arc": SE_ARC_SHA256,
	"voice.arc": VOICE_ARC_SHA256,
}

## Every original archive with a pin.
const ARCHIVE_SHA256 := {
	"mes.arc": MES_ARC_SHA256,
	"mmo.arc": MMO_ARC_SHA256,
	"data.arc": DATA_ARC_SHA256,
	"bgm.arc": BGM_ARC_SHA256,
	"se.arc": SE_ARC_SHA256,
	"voice.arc": VOICE_ARC_SHA256,
	"tina1.arc": TINA1_ARC_SHA256,
	"tina2.arc": TINA2_ARC_SHA256,
}

## The seven media archives (everything but `mes.arc`), in the order a media
## inventory searches them.
const MEDIA_ARCHIVES := ["mmo.arc", "data.arc", "bgm.arc", "se.arc", "voice.arc", "tina1.arc", "tina2.arc"]


## The pinned SHA-256 of `archive`, or "" when the archive has no pin.
static func expected(archive: String) -> String:
	return str(ARCHIVE_SHA256.get(archive, ""))


## Hashes the file at `path` and compares it with `archive`'s pin (or with
## `pinned`, a table a test substitutes for the original pins). Returns
## `{ok, sha256, error}`; a missing pin, an unreadable file or a different hash
## is not ok. This is a read-only operation.
static func verify_file(path: String, archive: String, pinned: Dictionary = ARCHIVE_SHA256) -> Dictionary:
	var pin := str(pinned.get(archive, ""))
	if pin.is_empty():
		return {"ok": false, "sha256": "", "error": "%s has no pinned identity." % archive}
	var live := FileAccess.get_sha256(path)
	if live.is_empty():
		return {"ok": false, "sha256": "", "error": "%s could not be hashed." % archive}
	if live != pin:
		return {"ok": false, "sha256": live, "error": "Original %s fingerprint changed." % archive}
	return {"ok": true, "sha256": live, "error": ""}
