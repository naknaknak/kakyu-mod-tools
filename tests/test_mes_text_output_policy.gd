extends "res://tests/test_case.gd"

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const PolicyScript := preload("res://content_core/mes_text_output_policy.gd")


func _ready() -> void:
	var policy := PolicyScript.new()
	var source := _source()
	var message := _message()
	var exact := policy.assess(source, message, _edit("あ"))
	_check(
		exact.get("ok", false)
		and exact.schema == ContentCoreVersionScript.MES_TEXT_OUTPUT_POLICY_SCHEMA
		and exact.targets.remake_utf8_overlay.status == "ready"
		and exact.targets.remake_utf8_overlay.compatibility == "remake_only"
		and exact.targets.original_cp932_candidate.status == "ready"
		and exact.targets.original_cp932_candidate.compatibility == "original_engine_unverified"
		and exact.targets.original_cp932_candidate.byte_delta == 0,
		"text output policy separates ready UTF-8 and equal-length CP932 candidate lanes"
	)
	_check(
		not JSON.stringify(exact).contains("あ")
		and not JSON.stringify(exact).contains("raw_bytes")
		and not JSON.stringify(exact).contains(":/")
		and not JSON.stringify(exact).contains(":\\"),
		"text output policy report contains no authored text, raw bytes, or machine path"
	)
	var transported = JSON.parse_string(JSON.stringify(exact))
	_check(
		transported is Dictionary and policy.validate(transported).get("ok", false),
		"text output policy report survives JSON number transport"
	)

	var emoji := policy.assess(source, message, _edit("😀"))
	_check(
		emoji.targets.remake_utf8_overlay.status == "ready"
		and emoji.targets.original_cp932_candidate.status == "blocked"
		and "unrepresentable_cp932" in emoji.targets.original_cp932_candidate.blockers,
		"unrepresentable Unicode remains remake-ready and blocks the CP932 candidate"
	)
	var overflow := policy.assess(source, message, _edit("あい"))
	_check(
		overflow.targets.remake_utf8_overlay.status == "ready"
		and overflow.targets.original_cp932_candidate.status == "blocked"
		and overflow.targets.original_cp932_candidate.byte_delta == 2
		and "byte_length_overflow" in overflow.targets.original_cp932_candidate.blockers,
		"CP932 byte overflow is reported before binary publication"
	)
	var underflow := policy.assess(source, message, _edit(""))
	_check(
		underflow.targets.remake_utf8_overlay.status == "ready"
		and underflow.targets.original_cp932_candidate.status == "blocked"
		and underflow.targets.original_cp932_candidate.byte_delta == -2
		and "byte_length_underflow" in underflow.targets.original_cp932_candidate.blockers,
		"CP932 byte underflow is distinct from unrestricted UTF-8 projection"
	)
	var ascii := policy.assess(source, message, _edit("A"))
	_check(
		ascii.targets.remake_utf8_overlay.status == "ready"
		and "native_projection_mismatch" in ascii.targets.original_cp932_candidate.blockers,
		"CP932 text outside the confirmed double-byte projection blocks the native candidate"
	)
	var boundary_message := message.duplicate(true)
	boundary_message.native_stream_projection_match = false
	var boundary := policy.assess(source, boundary_message, _edit("あ"))
	_check(
		boundary.targets.remake_utf8_overlay.status == "ready"
		and "native_boundary_mismatch" in boundary.targets.original_cp932_candidate.blockers,
		"native text-consumption mismatch blocks only the CP932 candidate"
	)
	var stale_edit := _edit("あ")
	stale_edit.source_archive_sha256 = "9".repeat(64)
	stale_edit.raw_sha256 = "8".repeat(64)
	var stale := policy.assess(source, message, stale_edit)
	_check(
		stale.targets.remake_utf8_overlay.status == "blocked"
		and stale.targets.original_cp932_candidate.status == "blocked"
		and "stale_source" in stale.targets.remake_utf8_overlay.blockers
		and "stale_message" in stale.targets.original_cp932_candidate.blockers,
		"changed source or message identity blocks both publication lanes"
	)
	var tampered := exact.duplicate(true)
	tampered.targets.original_cp932_candidate.compatibility = "original_engine_compatible"
	tampered.payload_sha256 = policy.fingerprint(tampered)
	_check(
		not policy.validate(tampered).get("ok", false),
		"policy report cannot promote an unverified CP932 candidate"
	)
	var unknown := exact.duplicate(true)
	unknown["ignored"] = true
	unknown.payload_sha256 = policy.fingerprint(unknown)
	_check(
		not policy.validate(unknown).get("ok", false),
		"text output policy rejects unknown fields"
	)
	var stale_fingerprint := exact.duplicate(true)
	stale_fingerprint.edit.text_utf8_byte_count = 999
	_check(
		not policy.validate(stale_fingerprint).get("ok", false),
		"text output policy rejects a stale fingerprint"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _source() -> Dictionary:
	return {
		"archive": "mes.arc", "entry": "TEST.MES",
		"archive_sha256": "a".repeat(64), "entry_sha256": "b".repeat(64),
	}


func _message() -> Dictionary:
	var raw := PackedByteArray([0x82, 0xA0])
	return {
		"source_offset": 0x20, "raw_bytes": raw, "raw_sha256": _sha256(raw),
		"native_stream_projection_match": true,
	}


func _edit(text: String) -> Dictionary:
	return {
		"source_archive_sha256": "a".repeat(64),
		"source_entry_sha256": "b".repeat(64), "source_offset": 0x20,
		"raw_sha256": str(_message().raw_sha256), "text": text,
	}


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
