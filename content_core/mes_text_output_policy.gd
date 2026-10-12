class_name KakyuMesTextOutputPolicy
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const MesTextPatcherScript := preload("res://content_core/mes_text_patcher.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const REPORT_KEYS := [
	"ok", "schema", "producer", "source", "edit", "targets", "diagnostics",
	"payload_sha256",
]
const SOURCE_KEYS := ["archive", "entry", "archive_sha256", "entry_sha256"]
const EDIT_KEYS := [
	"source_archive_sha256", "source_entry_sha256", "source_offset",
	"raw_sha256", "text_utf8_sha256", "text_utf8_byte_count",
]
const TARGET_KEYS := [
	"policy", "status", "compatibility", "encoding", "publication",
	"representable", "source_byte_count", "output_byte_count", "byte_delta",
	"output_sha256", "blockers",
]
const DIAGNOSTIC_KEYS := ["code", "target", "blocking", "detail"]
const TARGET_ORDER := ["remake_utf8_overlay", "original_cp932_candidate"]
const DIAGNOSTIC_CODES := {
	"stale_source": true,
	"stale_entry": true,
	"stale_message": true,
	"embedded_nul": true,
	"unrepresentable_cp932": true,
	"native_byte_range": true,
	"native_projection_mismatch": true,
	"native_boundary_mismatch": true,
	"byte_length_overflow": true,
	"byte_length_underflow": true,
}

var _cp932 := Cp932CodecScript.new()
var _patcher := MesTextPatcherScript.new()


func assess(source: Dictionary, message: Dictionary, edit: Dictionary) -> Dictionary:
	var checked := _validate_inputs(source, message, edit)
	if not checked.get("ok", false):
		return checked
	var text := str(edit.text)
	var source_bytes: PackedByteArray = message.raw_bytes
	var utf8_bytes := text.to_utf8_buffer()
	var common_blockers: Array[String] = []
	var original_blockers: Array[String] = []
	var diagnostics: Array[Dictionary] = []
	if str(edit.source_archive_sha256) != str(source.archive_sha256):
		_add_diagnostic(diagnostics, common_blockers, "stale_source", "both", "Source archive identity changed.")
	if str(edit.source_entry_sha256) != str(source.entry_sha256):
		_add_diagnostic(diagnostics, common_blockers, "stale_entry", "both", "Source MES entry identity changed.")
	if (
		int(edit.source_offset) != int(message.source_offset)
		or str(edit.raw_sha256) != str(message.raw_sha256)
	):
		_add_diagnostic(diagnostics, common_blockers, "stale_message", "both", "Source message locator or byte identity changed.")
	if utf8_bytes.has(0):
		_add_diagnostic(diagnostics, common_blockers, "embedded_nul", "both", "Authored text contains an embedded NUL.")

	var encoded := _cp932.encode(text)
	var cp932_bytes := PackedByteArray()
	if not encoded.get("ok", false):
		_add_diagnostic(
			diagnostics, original_blockers, "unrepresentable_cp932",
			"original_cp932_candidate", str(encoded.error)
		)
	else:
		cp932_bytes = encoded.data
		var native_validation := _patcher.validate_replacement_text(text)
		if (
			not native_validation.get("ok", false)
			and str(native_validation.get("error_code", "")) == "native_byte_range"
		):
			_add_diagnostic(
				diagnostics, original_blockers, "native_byte_range",
				"original_cp932_candidate", str(native_validation.error)
			)
		var projection_validation := _patcher.validate_native_double_byte_replacement(text)
		if (
			not projection_validation.get("ok", false)
			and str(projection_validation.get("error_code", "")) == "native_projection"
		):
			_add_diagnostic(
				diagnostics, original_blockers, "native_projection_mismatch",
				"original_cp932_candidate", str(projection_validation.error)
			)
		if not bool(message.get("native_stream_projection_match", false)):
			_add_diagnostic(
				diagnostics, original_blockers, "native_boundary_mismatch",
				"original_cp932_candidate",
				"Message does not match the confirmed native text-consumption boundary."
			)
		var delta := cp932_bytes.size() - source_bytes.size()
		if delta > 0:
			_add_diagnostic(
				diagnostics, original_blockers, "byte_length_overflow",
				"original_cp932_candidate",
				"CP932 output exceeds the current native payload by %d byte(s)." % delta
			)
		elif delta < 0:
			_add_diagnostic(
				diagnostics, original_blockers, "byte_length_underflow",
				"original_cp932_candidate",
				"CP932 output is shorter than the current native payload by %d byte(s)." % -delta
			)

	var remake_blockers := common_blockers.duplicate()
	var cp932_blockers := common_blockers.duplicate()
	for code in original_blockers:
		if code not in cp932_blockers:
			cp932_blockers.append(code)
	var cp932_representable := bool(encoded.get("ok", false))
	var report := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_TEXT_OUTPUT_POLICY_SCHEMA,
		"producer": {
			"implementation": "content_core_mes_text_output_policy",
			"contract": ContentCoreVersionScript.MES_TEXT_OUTPUT_POLICY_SCHEMA,
		},
		"source": {
			"archive": str(source.archive).to_lower(),
			"entry": str(source.entry).to_upper(),
			"archive_sha256": str(source.archive_sha256),
			"entry_sha256": str(source.entry_sha256),
		},
		"edit": {
			"source_archive_sha256": str(edit.source_archive_sha256),
			"source_entry_sha256": str(edit.source_entry_sha256),
			"source_offset": int(edit.source_offset),
			"raw_sha256": str(edit.raw_sha256),
			"text_utf8_sha256": ContractValues.sha256_or_empty_digest(utf8_bytes),
			"text_utf8_byte_count": utf8_bytes.size(),
		},
		"targets": {
			"remake_utf8_overlay": _target(
				"remake_utf8_overlay", "remake_only", "utf8", "mes_text_projection",
				true, source_bytes.size(), utf8_bytes.size(), ContractValues.sha256_or_empty_digest(utf8_bytes), remake_blockers
			),
			"original_cp932_candidate": _target(
				"original_cp932_equal_length_candidate", "original_engine_unverified",
				"cp932", "binary_mes_candidate", cp932_representable,
				source_bytes.size(), cp932_bytes.size() if cp932_representable else -1,
				ContractValues.sha256_or_empty_digest(cp932_bytes) if cp932_representable else "", cp932_blockers
			),
		},
		"diagnostics": diagnostics,
	}
	report["payload_sha256"] = fingerprint(report)
	var reopened := validate(report)
	return report if reopened.get("ok", false) else reopened


func validate(report: Dictionary) -> Dictionary:
	if (
		report.get("ok") != true
		or str(report.get("schema", "")) != ContentCoreVersionScript.MES_TEXT_OUTPUT_POLICY_SCHEMA
		or not ContractValues.has_exact_keys(report, REPORT_KEYS)
	):
		return _error("MES text output-policy schema or fields changed.")
	if report.get("producer") != {
		"implementation": "content_core_mes_text_output_policy",
		"contract": ContentCoreVersionScript.MES_TEXT_OUTPUT_POLICY_SCHEMA,
	}:
		return _error("MES text output-policy producer changed.")
	var source = report.get("source")
	if (
		not source is Dictionary or not ContractValues.has_exact_keys(source, SOURCE_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(source.get("entry", "")))
		or not ContractValues.is_sha256(str(source.get("archive_sha256", "")))
		or not ContractValues.is_sha256(str(source.get("entry_sha256", "")))
	):
		return _error("MES text output-policy source identity is invalid.")
	var edit = report.get("edit")
	if (
		not edit is Dictionary or not ContractValues.has_exact_keys(edit, EDIT_KEYS)
		or not ContractValues.is_sha256(str(edit.get("source_archive_sha256", "")))
		or not ContractValues.is_sha256(str(edit.get("source_entry_sha256", "")))
		or not ContractValues.nonnegative_json_integer(edit.get("source_offset", -1))
		or not ContractValues.is_sha256(str(edit.get("raw_sha256", "")))
		or not ContractValues.is_sha256(str(edit.get("text_utf8_sha256", "")))
		or not ContractValues.nonnegative_json_integer(edit.get("text_utf8_byte_count", -1))
	):
		return _error("MES text output-policy edit identity is invalid.")
	var diagnostics = report.get("diagnostics")
	if not diagnostics is Array:
		return _error("MES text output-policy diagnostics are invalid.")
	var diagnostic_codes_by_target := {
		"remake_utf8_overlay": [], "original_cp932_candidate": [],
	}
	for value in diagnostics:
		if not value is Dictionary or not ContractValues.has_exact_keys(value, DIAGNOSTIC_KEYS):
			return _error("MES text output-policy diagnostic fields changed.")
		var code := str(value.get("code", ""))
		var diagnostic_target := str(value.get("target", ""))
		if (
			not DIAGNOSTIC_CODES.has(code) or diagnostic_target not in ["both"] + TARGET_ORDER
			or value.get("blocking") != true or str(value.get("detail", "")).is_empty()
		):
			return _error("MES text output-policy diagnostic is invalid.")
		for target_name in TARGET_ORDER:
			if diagnostic_target == "both" or diagnostic_target == target_name:
				if code in diagnostic_codes_by_target[target_name]:
					return _error("MES text output-policy diagnostic is duplicated.")
				diagnostic_codes_by_target[target_name].append(code)
	var targets = report.get("targets")
	if not targets is Dictionary or not ContractValues.has_exact_keys(targets, TARGET_ORDER):
		return _error("MES text output-policy targets changed.")
	for target_name in TARGET_ORDER:
		var target_value = targets.get(target_name)
		if (
			not target_value is Dictionary
			or not _validate_target(target_name, target_value, diagnostic_codes_by_target[target_name])
		):
			return _error("MES text output-policy target is invalid: %s." % target_name)
	var retained_hash := str(report.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or retained_hash != fingerprint(report):
		return _error("MES text output-policy fingerprint changed.")
	return {
		"ok": true, "schema": ContentCoreVersionScript.MES_TEXT_OUTPUT_POLICY_SCHEMA,
		"payload_sha256": retained_hash,
		"targets": targets.duplicate(true), "diagnostics": diagnostics.duplicate(true),
	}


func fingerprint(report: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(report)


func _validate_inputs(source: Dictionary, message: Dictionary, edit: Dictionary) -> Dictionary:
	if (
		not ContractValues.has_exact_keys(source, SOURCE_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(source.get("entry", "")))
		or not ContractValues.is_sha256(str(source.get("archive_sha256", "")))
		or not ContractValues.is_sha256(str(source.get("entry_sha256", "")))
	):
		return _error("Current MES source identity is invalid.")
	if (
		not edit.has_all([
			"source_archive_sha256", "source_entry_sha256", "source_offset",
			"raw_sha256", "text",
		])
		or not ContractValues.is_sha256(str(edit.get("source_archive_sha256", "")))
		or not ContractValues.is_sha256(str(edit.get("source_entry_sha256", "")))
		or not ContractValues.nonnegative_json_integer(edit.get("source_offset", -1))
		or not ContractValues.is_sha256(str(edit.get("raw_sha256", "")))
		or not edit.get("text") is String
	):
		return _error("Pending MES text edit identity is invalid.")
	var raw = message.get("raw_bytes")
	if (
		not raw is PackedByteArray
		or not ContractValues.nonnegative_json_integer(message.get("source_offset", -1))
		or not ContractValues.is_sha256(str(message.get("raw_sha256", "")))
		or ContractValues.sha256_or_empty_digest(raw) != str(message.raw_sha256)
	):
		return _error("Current MES message evidence is invalid.")
	return {"ok": true}


func _target(
	policy: String, compatibility: String, encoding: String, publication: String,
	representable: bool, source_count: int, output_count: int, output_sha256: String,
	blockers: Array
) -> Dictionary:
	return {
		"policy": policy, "status": "ready" if blockers.is_empty() else "blocked",
		"compatibility": compatibility, "encoding": encoding,
		"publication": publication, "representable": representable,
		"source_byte_count": source_count, "output_byte_count": output_count,
		"byte_delta": output_count - source_count if representable else 0,
		"output_sha256": output_sha256, "blockers": blockers.duplicate(),
	}


func _validate_target(target_name: String, target: Dictionary, expected_blockers: Array) -> bool:
	if not ContractValues.has_exact_keys(target, TARGET_KEYS):
		return false
	var expected := (
		{
			"policy": "remake_utf8_overlay", "compatibility": "remake_only",
			"encoding": "utf8", "publication": "mes_text_projection",
		}
		if target_name == "remake_utf8_overlay"
		else {
			"policy": "original_cp932_equal_length_candidate",
			"compatibility": "original_engine_unverified", "encoding": "cp932",
			"publication": "binary_mes_candidate",
		}
	)
	if (
		str(target.get("policy", "")) != str(expected.policy)
		or str(target.get("compatibility", "")) != str(expected.compatibility)
		or str(target.get("encoding", "")) != str(expected.encoding)
		or str(target.get("publication", "")) != str(expected.publication)
		or not target.get("representable") is bool
		or not ContractValues.nonnegative_json_integer(target.get("source_byte_count", -1))
		or not ContractValues.json_integer(target.get("output_byte_count", -2))
		or not ContractValues.json_integer(target.get("byte_delta", 0.5))
		or not target.get("blockers") is Array
	):
		return false
	var blockers: Array = target.blockers
	if blockers != expected_blockers:
		return false
	if str(target.status) != ("ready" if blockers.is_empty() else "blocked"):
		return false
	if bool(target.representable):
		return (
			int(target.output_byte_count) >= 0
			and int(target.byte_delta) == int(target.output_byte_count) - int(target.source_byte_count)
			and ContractValues.is_sha256(str(target.output_sha256))
		)
	return (
		target_name == "original_cp932_candidate"
		and int(target.output_byte_count) == -1 and int(target.byte_delta) == 0
		and str(target.output_sha256).is_empty()
		and "unrepresentable_cp932" in blockers
	)


func _add_diagnostic(
	diagnostics: Array[Dictionary], blockers: Array[String], code: String,
	target: String, detail: String
) -> void:
	if code in blockers:
		return
	blockers.append(code)
	diagnostics.append({
		"code": code, "target": target, "blocking": true, "detail": detail,
	})


func _error(message: String) -> Dictionary:
	return {
		"ok": false, "schema": ContentCoreVersionScript.MES_TEXT_OUTPUT_POLICY_SCHEMA,
		"error": message,
	}
