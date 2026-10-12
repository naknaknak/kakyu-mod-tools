extends "res://tests/test_case.gd"

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const CatalogScript := preload("res://content_core/mes_translation_catalog.gd")


func _ready() -> void:
	var catalog_builder := CatalogScript.new()
	var source := _source("a", "b")
	var analyzed := [
		_entry("B.MES", "c", [
			_message(0x30, "SECOND", true),
		]),
		_entry("A.MES", "d", [
			_message(0x20, "FIRST", false),
			_invalid_message(0x40),
		]),
	]
	var catalog := catalog_builder.build(_metadata(1), source, analyzed)
	_check(catalog.get("ok", false), "translation catalog exports strict CP932 message identities")
	_check(
		str(catalog.schema) == ContentCoreVersionScript.MES_TRANSLATION_CATALOG_SCHEMA
		and catalog.rows.size() == 2
		and str(catalog.rows[0].entry) == "A.MES"
		and int(catalog.rows[0].source_offset) == 0x20
		and str(catalog.rows[1].entry) == "B.MES",
		"translation catalog orders stable rows by entry and code-relative offset"
	)
	var encoded := JSON.stringify(catalog)
	_check(
		not encoded.contains("FIRST") and not encoded.contains("SECOND")
		and not encoded.contains("raw_bytes") and not encoded.contains("raw_hex")
		and not encoded.contains("source_text"),
		"translation catalog contains no original text or raw payload bytes"
	)
	_check(
		catalog_builder.validate(catalog).get("ok", false)
		and int(catalog.coverage.untranslated_count) == 2,
		"translation catalog validates its fingerprint and derived coverage"
	)

	var first_id := str(catalog.rows[0].message_id)
	var translated := catalog_builder.apply_updates(catalog, [{
		"message_id": first_id, "state": "reviewed", "text": "번역문",
		"translator_id": "translator.one", "revision": 1,
	}], 2)
	_check(
		translated.get("ok", false)
		and int(translated.catalog.catalog_revision) == 2
		and int(translated.coverage.reviewed_count) == 1
		and int(translated.coverage.untranslated_count) == 1,
		"translation updates advance catalog and row provenance revisions"
	)
	_check(
		str(catalog.rows[0].translation.state) == "untranslated",
		"translation update leaves the immutable input catalog unchanged"
	)
	_check(
		not catalog_builder.apply_updates(translated, [{
			"message_id": first_id, "state": "approved", "text": "번역문",
			"translator_id": "translator.one", "revision": 1,
		}], 3).get("ok", false),
		"translation updates reject a non-increasing per-row provenance revision"
	)
	_check(
		not catalog_builder.apply_updates(translated, [{
			"message_id": first_id, "state": "untranslated", "text": "",
			"translator_id": "", "revision": 0,
		}], 3).get("ok", false),
		"translation updates cannot erase existing row provenance"
	)
	var exact := catalog_builder.reconcile(translated, source, analyzed)
	_check(
		exact.get("ok", false) and exact.ready
		and int(exact.applicable_edit_count) == 1
		and str(exact.edits_by_entry["A.MES"][0].text) == "번역문"
		and str(exact.edits_by_entry["A.MES"][0].raw_sha256) == str(catalog.rows[0].raw_sha256),
		"exact-source import produces hash-bound UTF-8 overlay edit inputs"
	)

	var duplicate_updates := catalog_builder.apply_updates(catalog, [
		_update(first_id, "ONE"), _update(first_id, "TWO"),
	], 2)
	_check(
		not duplicate_updates.get("ok", false)
		and str(duplicate_updates.diagnostics[0].code) == "conflicting_row",
		"translation import reports conflicting duplicate updates"
	)
	var unknown_update := catalog_builder.apply_updates(catalog, [
		_update("e".repeat(64), "UNKNOWN"),
	], 2)
	_check(
		not unknown_update.get("ok", false)
		and str(unknown_update.diagnostics[0].code) == "missing_catalog_row",
		"translation import reports update IDs missing from the catalog"
	)

	var stale_entries := analyzed.duplicate(true)
	stale_entries[0] = _entry("B.MES", "c", [_message(0x30, "CHANGED", true)])
	var stale := catalog_builder.reconcile(translated, source, stale_entries)
	_check(
		stale.get("ok", false) and not stale.ready
		and int(stale.diagnostic_counts.stale_message) == 1,
		"translation reconcile reports a changed source message at the same locator"
	)
	var missing_entries := [_entry("A.MES", "d", [
		_message(0x20, "FIRST", false), _message(0x60, "NEWROW", true),
	])]
	var missing := catalog_builder.reconcile(translated, source, missing_entries)
	_check(
		missing.get("ok", false) and not missing.ready
		and int(missing.diagnostic_counts.missing_source_row) == 1
		and int(missing.diagnostic_counts.missing_catalog_row) == 1,
		"translation reconcile distinguishes missing source and missing catalog rows"
	)
	var stale_source := catalog_builder.reconcile(translated, _source("f", "b"), analyzed)
	_check(
		stale_source.get("ok", false) and not stale_source.ready
		and int(stale_source.diagnostic_counts.stale_source) == 1
		and int(stale_source.applicable_edit_count) == 0,
		"translation reconcile blocks edits from another source archive generation"
	)

	var conflicting_catalog := catalog.duplicate(true)
	conflicting_catalog.rows.append(conflicting_catalog.rows[0].duplicate(true))
	conflicting_catalog.coverage = _coverage_for(conflicting_catalog.rows)
	conflicting_catalog.payload_sha256 = catalog_builder.fingerprint(conflicting_catalog)
	var conflict_check := catalog_builder.validate(conflicting_catalog)
	_check(
		not conflict_check.get("ok", false)
		and str(conflict_check.diagnostics[0].code) == "conflicting_row",
		"translation catalog reports duplicate message identities and locators"
	)
	var tampered := translated.duplicate(true)
	tampered.rows[0].translation.text = "tampered"
	_check(
		not catalog_builder.validate(tampered).get("ok", false),
		"translation catalog rejects a translation changed without fingerprint renewal"
	)
	_check(
		not JSON.stringify(translated).contains("C:\\"),
		"translation catalog is path-free"
	)
	get_tree().quit(1 if _failed else 0)


func _metadata(revision: int) -> Dictionary:
	return {
		"catalog_id": "ko.translation", "catalog_revision": revision,
		"source_locale": "ja-JP", "target_locale": "ko-KR",
	}


func _source(archive_digit: String, content_digit: String) -> Dictionary:
	return {
		"archive": "mes.arc", "archive_sha256": archive_digit.repeat(64),
		"source_content_set_sha256": content_digit.repeat(64),
	}


func _entry(name: String, hash_digit: String, messages: Array) -> Dictionary:
	return {
		"entry": name, "entry_sha256": hash_digit.repeat(64), "messages": messages,
	}


func _message(offset: int, text: String, native_match: bool) -> Dictionary:
	var raw := text.to_ascii_buffer()
	return {
		"source_offset": offset, "end_offset": offset + raw.size() + 2,
		"region": "entry_0", "kind": "text", "raw_bytes": raw,
		"raw_sha256": _sha256(raw),
		"native_stream_projection_match": native_match,
	}


func _invalid_message(offset: int) -> Dictionary:
	var raw := PackedByteArray([0x8F, 0x01])
	return {
		"source_offset": offset, "end_offset": offset + 3,
		"region": "entry_0", "kind": "text", "raw_bytes": raw,
		"raw_sha256": _sha256(raw),
		"native_stream_projection_match": false,
	}


func _update(message_id: String, text: String) -> Dictionary:
	return {
		"message_id": message_id, "state": "draft", "text": text,
		"translator_id": "translator.one", "revision": 1,
	}


func _coverage_for(rows: Array) -> Dictionary:
	var result := {
		"row_count": rows.size(), "untranslated_count": 0, "draft_count": 0,
		"reviewed_count": 0, "approved_count": 0,
	}
	for row in rows:
		var key := "%s_count" % str(row.translation.state)
		result[key] = int(result[key]) + 1
	return result


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
