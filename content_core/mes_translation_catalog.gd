class_name KakyuMesTranslationCatalog
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const TOP_LEVEL_KEYS := [
	"ok", "schema", "producer", "catalog", "source", "rows", "coverage",
	"payload_sha256",
]
const CATALOG_KEYS := [
	"catalog_id", "catalog_revision", "source_locale", "target_locale",
]
const SOURCE_KEYS := [
	"archive", "archive_sha256", "source_content_set_sha256",
]
const ROW_KEYS := [
	"message_id", "entry", "source_entry_sha256", "source_offset",
	"end_offset", "raw_sha256", "source_byte_count", "kind", "region",
	"native_stream_projection_match", "translation",
]
const TRANSLATION_KEYS := ["state", "text", "translator_id", "revision"]
const UPDATE_KEYS := ["message_id", "state", "text", "translator_id", "revision"]
const COVERAGE_KEYS := [
	"row_count", "untranslated_count", "draft_count", "reviewed_count",
	"approved_count",
]
const TRANSLATION_STATES := ["untranslated", "draft", "reviewed", "approved"]
const MESSAGE_KINDS := ["text", "dispatcher_character_text"]

var _cp932 := Cp932CodecScript.new()


func build(
	catalog_metadata: Dictionary,
	source_binding: Dictionary,
	analyzed_entries: Array
) -> Dictionary:
	if not _validate_catalog(catalog_metadata):
		return _error("MES translation catalog metadata is invalid.")
	if not _validate_source(source_binding):
		return _error("MES translation catalog source binding is invalid.")
	var exported := _export_rows(source_binding, analyzed_entries)
	if not exported.get("ok", false):
		return exported
	var document := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_TRANSLATION_CATALOG_SCHEMA,
		"producer": {
			"implementation": "content_core_mes_translation_catalog",
			"contract": ContentCoreVersionScript.MES_TRANSLATION_CATALOG_SCHEMA,
		},
		"catalog": catalog_metadata.duplicate(true),
		"source": source_binding.duplicate(true),
		"rows": exported.rows,
		"coverage": _coverage(exported.rows),
	}
	document["payload_sha256"] = fingerprint(document)
	var checked := validate(document)
	return document if checked.get("ok", false) else checked


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_TRANSLATION_CATALOG_SCHEMA
		or not ContractValues.has_exact_keys(document, TOP_LEVEL_KEYS)
		or document.get("producer") != {
			"implementation": "content_core_mes_translation_catalog",
			"contract": ContentCoreVersionScript.MES_TRANSLATION_CATALOG_SCHEMA,
		}
	):
		return _error("MES translation catalog schema or producer changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES translation catalog fingerprint changed.")
	if not _validate_catalog(document.get("catalog", null)):
		return _error("MES translation catalog metadata changed.")
	if not _validate_source(document.get("source", null)):
		return _error("MES translation catalog source binding changed.")
	var rows = document.get("rows")
	if not rows is Array:
		return _error("MES translation catalog rows must be an array.")
	var ids := {}
	var locators := {}
	for index in range(rows.size()):
		var value = rows[index]
		if not value is Dictionary or not _validate_row(value, document.source):
			return _error("MES translation catalog row %d is invalid." % index)
		var row: Dictionary = value
		var message_id := str(row.message_id)
		var locator := _locator(str(row.entry), int(row.source_offset))
		if ids.has(message_id) or locators.has(locator):
			return _error_with_diagnostic(
				"MES translation catalog contains conflicting rows.",
				"conflicting_row", str(row.entry), int(row.source_offset), message_id
			)
		ids[message_id] = true
		locators[locator] = true
	if not document.get("coverage") is Dictionary:
		return _error("MES translation catalog coverage is invalid.")
	if not _coverage_matches(document.coverage, _coverage(rows)):
		return _error("MES translation catalog coverage changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_TRANSLATION_CATALOG_SCHEMA,
		"payload_sha256": retained_hash,
		"row_count": rows.size(),
		"coverage": document.coverage.duplicate(true),
	}


func apply_updates(
	document: Dictionary,
	updates: Array,
	new_catalog_revision: Variant
) -> Dictionary:
	var checked := validate(document)
	if not checked.get("ok", false):
		return checked
	if (
		not _positive_json_integer(new_catalog_revision)
		or int(new_catalog_revision) <= int(document.catalog.catalog_revision)
	):
		return _error("MES translation catalog revision must increase.")
	var row_index_by_id := {}
	for index in range(document.rows.size()):
		row_index_by_id[str(document.rows[index].message_id)] = index
	var seen_updates := {}
	var diagnostics: Array[Dictionary] = []
	for value in updates:
		if not value is Dictionary or not ContractValues.has_exact_keys(value, UPDATE_KEYS):
			return _error("MES translation catalog update fields are invalid.")
		var update: Dictionary = value
		var message_id := str(update.message_id)
		if seen_updates.has(message_id):
			diagnostics.append(_diagnostic(
				"conflicting_row", "", -1, message_id,
				"The import updates one message more than once."
			))
			continue
		seen_updates[message_id] = true
		if not row_index_by_id.has(message_id):
			diagnostics.append(_diagnostic(
				"missing_catalog_row", "", -1, message_id,
				"The imported message ID is absent from this catalog."
			))
			continue
		var candidate_translation := {
			"state": update.state, "text": update.text,
			"translator_id": update.translator_id, "revision": update.revision,
		}
		if not _validate_translation(candidate_translation):
			return _error("MES translation catalog update is invalid: %s" % message_id)
		var current_translation: Dictionary = document.rows[
			int(row_index_by_id[message_id])
		].translation
		if (
			str(current_translation.state) != "untranslated"
			and str(candidate_translation.state) == "untranslated"
		):
			return _error("MES translation update cannot erase row provenance: %s" % message_id)
		if (
			str(candidate_translation.state) != "untranslated"
			and int(candidate_translation.revision) <= int(current_translation.revision)
		):
			return _error("MES translation row revision must increase: %s" % message_id)
	if not diagnostics.is_empty():
		return _diagnostic_error("MES translation catalog updates conflict with the catalog.", diagnostics)
	var output := document.duplicate(true)
	for value in updates:
		var update: Dictionary = value
		var row_index: int = int(row_index_by_id[str(update.message_id)])
		output.rows[row_index].translation = {
			"state": str(update.state), "text": str(update.text),
			"translator_id": str(update.translator_id), "revision": int(update.revision),
		}
	output.catalog.catalog_revision = int(new_catalog_revision)
	output.coverage = _coverage(output.rows)
	output.payload_sha256 = fingerprint(output)
	var reopened := validate(output)
	return output if reopened.get("ok", false) else reopened


func reconcile(
	document: Dictionary,
	current_source: Dictionary,
	current_analyzed_entries: Array
) -> Dictionary:
	var checked := validate(document)
	if not checked.get("ok", false):
		return checked
	if not _validate_source(current_source):
		return _error("Current MES translation source binding is invalid.")
	var exported := _export_rows(current_source, current_analyzed_entries)
	if not exported.get("ok", false):
		return exported
	var current_rows: Array = exported.rows
	var current_by_locator := {}
	for value in current_rows:
		var row: Dictionary = value
		current_by_locator[_locator(str(row.entry), int(row.source_offset))] = row
	var catalog_locators := {}
	var diagnostics: Array[Dictionary] = []
	var edits_by_entry := {}
	var source_generation_matches := (
		str(document.source.archive_sha256) == str(current_source.archive_sha256)
		and str(document.source.source_content_set_sha256)
		== str(current_source.source_content_set_sha256)
	)
	if not source_generation_matches:
		diagnostics.append(_diagnostic(
			"stale_source", "", -1, "",
			"The catalog and current content-set/archive fingerprints differ."
		))
	for value in document.rows:
		var row: Dictionary = value
		var locator := _locator(str(row.entry), int(row.source_offset))
		catalog_locators[locator] = true
		if not current_by_locator.has(locator):
			diagnostics.append(_diagnostic(
				"missing_source_row", str(row.entry), int(row.source_offset),
				str(row.message_id), "The catalog message is absent from the current MES index."
			))
			continue
		var current: Dictionary = current_by_locator[locator]
		if str(row.raw_sha256) != str(current.raw_sha256):
			diagnostics.append(_diagnostic(
				"stale_message", str(row.entry), int(row.source_offset),
				str(row.message_id), "The source message bytes changed at this locator."
			))
			continue
		if str(row.source_entry_sha256) != str(current.source_entry_sha256):
			diagnostics.append(_diagnostic(
				"stale_entry", str(row.entry), int(row.source_offset),
				str(row.message_id), "The owning MES entry changed even though these message bytes match."
			))
			continue
		var translation: Dictionary = row.translation
		if source_generation_matches and str(translation.state) != "untranslated":
			var entry_key := str(row.entry).to_upper()
			var edits: Array = edits_by_entry.get(entry_key, [])
			edits.append({
				"source_offset": int(row.source_offset),
				"raw_sha256": str(row.raw_sha256),
				"text": str(translation.text),
				"translation_state": str(translation.state),
				"translator_id": str(translation.translator_id),
				"translation_revision": int(translation.revision),
			})
			edits_by_entry[entry_key] = edits
	for value in current_rows:
		var row: Dictionary = value
		var locator := _locator(str(row.entry), int(row.source_offset))
		if not catalog_locators.has(locator):
			diagnostics.append(_diagnostic(
				"missing_catalog_row", str(row.entry), int(row.source_offset),
				str(row.message_id), "The current MES message is absent from the catalog."
			))
	var counts := {
		"stale_source": 0, "stale_entry": 0, "stale_message": 0,
		"missing_source_row": 0, "missing_catalog_row": 0,
		"conflicting_row": 0,
	}
	for diagnostic in diagnostics:
		var code := str(diagnostic.code)
		if counts.has(code):
			counts[code] = int(counts[code]) + 1
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_TRANSLATION_CATALOG_SCHEMA,
		"catalog_sha256": str(document.payload_sha256),
		"source_generation_matches": source_generation_matches,
		"ready": diagnostics.is_empty(),
		"edits_by_entry": edits_by_entry,
		"diagnostics": diagnostics,
		"diagnostic_counts": counts,
		"applicable_entry_count": edits_by_entry.size(),
		"applicable_edit_count": _edit_count(edits_by_entry),
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _export_rows(source: Dictionary, analyzed_entries: Array) -> Dictionary:
	var rows: Array[Dictionary] = []
	var seen_entries := {}
	for value in analyzed_entries:
		if not value is Dictionary:
			return _error("MES translation export entry is not an object.")
		var entry_record: Dictionary = value
		var entry_name := str(entry_record.get("entry", ""))
		var entry_key := entry_name.to_upper()
		var entry_sha := str(entry_record.get("entry_sha256", ""))
		var messages = entry_record.get("messages")
		if (
			not ArcReaderScript.is_safe_entry_name(entry_name)
			or entry_name.get_extension().to_lower() not in ["mes", "lib"]
			or not ContractValues.is_sha256(entry_sha) or not messages is Array
			or seen_entries.has(entry_key)
		):
			return _error("MES translation export entry binding is invalid: %s" % entry_name)
		seen_entries[entry_key] = true
		var seen_offsets := {}
		for untyped_message in messages:
			if not untyped_message is Dictionary:
				return _error("MES translation export message is not an object: %s" % entry_name)
			var message: Dictionary = untyped_message
			var raw_value = message.get("raw_bytes")
			if not raw_value is PackedByteArray or not _cp932.decode(raw_value).get("ok", false):
				continue
			var raw: PackedByteArray = raw_value
			var source_offset = message.get("source_offset", -1)
			var end_offset = message.get("end_offset", -1)
			var kind := str(message.get("kind", ""))
			var raw_sha := str(message.get("raw_sha256", ""))
			if (
				not _nonnegative_json_integer(source_offset)
				or not _positive_json_integer(end_offset)
				or int(end_offset) <= int(source_offset)
				or kind not in MESSAGE_KINDS
				or not ContractValues.is_sha256(raw_sha) or raw_sha != ContractValues.sha256(raw)
				or seen_offsets.has(int(source_offset))
			):
				return _error("MES translation export message boundary is invalid: %s" % entry_name)
			seen_offsets[int(source_offset)] = true
			rows.append({
				"message_id": _message_id(str(source.archive), entry_name, int(source_offset), raw_sha),
				"entry": entry_name,
				"source_entry_sha256": entry_sha,
				"source_offset": int(source_offset),
				"end_offset": int(end_offset),
				"raw_sha256": raw_sha,
				"source_byte_count": raw.size(),
				"kind": kind,
				"region": str(message.get("region", "")),
				"native_stream_projection_match": bool(
					message.get("native_stream_projection_match", false)
				),
				"translation": {
					"state": "untranslated", "text": "",
					"translator_id": "", "revision": 0,
				},
			})
	rows.sort_custom(_row_less)
	return {"ok": true, "rows": rows}


func _validate_catalog(value: Variant) -> bool:
	return (
		value is Dictionary and ContractValues.has_exact_keys(value, CATALOG_KEYS)
		and ContractValues.is_identifier(str(value.catalog_id))
		and _positive_json_integer(value.catalog_revision)
		and _is_locale(str(value.source_locale))
		and _is_locale(str(value.target_locale))
		and str(value.source_locale).to_lower() != str(value.target_locale).to_lower()
	)


func _validate_source(value: Variant) -> bool:
	return (
		value is Dictionary and ContractValues.has_exact_keys(value, SOURCE_KEYS)
		and str(value.archive).to_lower() == "mes.arc"
		and ContractValues.is_sha256(str(value.archive_sha256))
		and ContractValues.is_sha256(str(value.source_content_set_sha256))
	)


func _validate_row(row: Dictionary, source: Dictionary) -> bool:
	if not ContractValues.has_exact_keys(row, ROW_KEYS):
		return false
	var entry := str(row.entry)
	var offset = row.source_offset
	return (
		ArcReaderScript.is_safe_entry_name(entry)
		and entry.get_extension().to_lower() in ["mes", "lib"]
		and ContractValues.is_sha256(str(row.source_entry_sha256))
		and _nonnegative_json_integer(offset)
		and _positive_json_integer(row.end_offset) and int(row.end_offset) > int(offset)
		and ContractValues.is_sha256(str(row.raw_sha256))
		and _positive_json_integer(row.source_byte_count)
		and str(row.kind) in MESSAGE_KINDS
		and row.region is String and str(row.region).length() <= 128
		and row.native_stream_projection_match is bool
		and str(row.message_id) == _message_id(
			str(source.archive), entry, int(offset), str(row.raw_sha256)
		)
		and _validate_translation(row.translation)
	)


func _validate_translation(value: Variant) -> bool:
	if not value is Dictionary or not ContractValues.has_exact_keys(value, TRANSLATION_KEYS):
		return false
	var state := str(value.state)
	if state not in TRANSLATION_STATES or not value.text is String:
		return false
	if str(value.text).to_utf8_buffer().has(0) or str(value.text).length() > 65535:
		return false
	if not _nonnegative_json_integer(value.revision):
		return false
	if state == "untranslated":
		return str(value.text).is_empty() and str(value.translator_id).is_empty() and int(value.revision) == 0
	return (
		not str(value.text).is_empty() and ContractValues.is_identifier(str(value.translator_id))
		and int(value.revision) > 0
	)


func _coverage(rows: Array) -> Dictionary:
	var result := {
		"row_count": rows.size(), "untranslated_count": 0, "draft_count": 0,
		"reviewed_count": 0, "approved_count": 0,
	}
	for value in rows:
		var state := str(value.get("translation", {}).get("state", ""))
		var key := "%s_count" % state
		if result.has(key):
			result[key] = int(result[key]) + 1
	return result


func _coverage_matches(value: Dictionary, expected: Dictionary) -> bool:
	if not ContractValues.has_exact_keys(value, COVERAGE_KEYS):
		return false
	for key in COVERAGE_KEYS:
		if not _nonnegative_json_integer(value.get(key, -1)) or int(value[key]) != int(expected[key]):
			return false
	return true


func _message_id(archive: String, entry: String, offset: int, raw_sha256: String) -> String:
	return FingerprintScript.new().fingerprint({
		"archive": archive.to_lower(), "entry": entry.to_upper(),
		"source_offset": offset, "raw_sha256": raw_sha256,
	})


func _row_less(left: Dictionary, right: Dictionary) -> bool:
	var left_entry := str(left.entry).to_upper()
	var right_entry := str(right.entry).to_upper()
	return (
		left_entry < right_entry
		or (left_entry == right_entry and int(left.source_offset) < int(right.source_offset))
	)


func _locator(entry: String, offset: int) -> String:
	return "%s:%08x" % [entry.to_upper(), offset]


func _edit_count(edits_by_entry: Dictionary) -> int:
	var count := 0
	for value in edits_by_entry.values():
		count += value.size() if value is Array else 0
	return count


func _diagnostic(
	code: String, entry: String, source_offset: int, message_id: String, message: String
) -> Dictionary:
	return {
		"code": code, "entry": entry, "source_offset": source_offset,
		"message_id": message_id, "message": message,
	}


func _error_with_diagnostic(
	message: String, code: String, entry: String, source_offset: int, message_id: String
) -> Dictionary:
	return _diagnostic_error(message, [
		_diagnostic(code, entry, source_offset, message_id, message),
	])


func _diagnostic_error(message: String, diagnostics: Array) -> Dictionary:
	return {
		"ok": false, "schema": ContentCoreVersionScript.MES_TRANSLATION_CATALOG_SCHEMA,
		"error": message, "diagnostics": diagnostics,
	}


func _nonnegative_json_integer(value: Variant) -> bool:
	return (
		(value is int or value is float) and is_finite(float(value))
		and float(value) == floor(float(value)) and float(value) >= 0.0
		and float(value) <= 4294967295.0
	)


func _positive_json_integer(value: Variant) -> bool:
	return _nonnegative_json_integer(value) and int(value) > 0


func _is_locale(value: String) -> bool:
	if value.is_empty() or value.length() > 35:
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-":
			return false
	return true


func _error(message: String) -> Dictionary:
	return {
		"ok": false, "schema": ContentCoreVersionScript.MES_TRANSLATION_CATALOG_SCHEMA,
		"error": message,
	}
