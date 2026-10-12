class_name KakyuMesNoopCorpusReopen
extends RefCounted

const ReopenAuditScript := preload("res://content_core/mes_noop_compile_reopen.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const MANIFEST_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity",
	"source_spool", "entry_count", "source_entry_count", "complete_archive",
	"entries", "coverage", "invariants", "payload_sha256",
]
const ENTRY_KEYS := [
	"position", "archive_index", "entry", "mes_file", "audit_file",
	"handoff_sha256", "decompiler_ir_sha256", "editable_ir_sha256",
	"compile_audit_sha256", "entry_sha256", "bytecode_sha256", "size",
	"code_size", "region_count", "node_count", "typed_node_count",
	"opaque_node_count",
]
const COVERAGE_KEYS := [
	"container_bytes", "code_bytes", "region_count", "node_count",
	"typed_node_count", "opaque_node_count",
]
const MANIFEST_INVARIANTS := {
	"all_compile_audits_valid": true,
	"all_outputs_byte_identical": true,
	"all_outputs_reopened": true,
	"all_operations_empty": true,
	"ordered_archive_scope_preserved": true,
	"manifest_published_last": true,
}


func audit(
	manifest: Dictionary,
	entry_loader: Callable,
	source_fingerprint: Callable,
	progress := Callable()
) -> Dictionary:
	var validation := validate_manifest(manifest)
	if not validation.get("ok", false):
		return validation
	if not entry_loader.is_valid() or not source_fingerprint.is_valid():
		return _error("MES no-op corpus loaders are missing.")
	var expected_archive_sha := str(manifest.source_identity.archive_sha256)
	var source_before := str(source_fingerprint.call())
	if source_before != expected_archive_sha:
		return _error("MES no-op corpus source archive fingerprint changed before reopen.")
	var aggregate := _empty_coverage()
	var stream := PackedByteArray()
	for position in range((manifest.entries as Array).size()):
		var row: Dictionary = manifest.entries[position]
		var loaded = entry_loader.call(row)
		if not loaded is Dictionary or not loaded.get("ok", false):
			return _error("MES no-op corpus output could not be loaded: %s" % row.entry)
		if (
			not loaded.get("payload", null) is PackedByteArray
			or not loaded.get("compile_audit", null) is Dictionary
		):
			return _error("MES no-op corpus loader returned invalid data: %s" % row.entry)
		var report: Dictionary = ReopenAuditScript.new().audit(
			loaded.payload, loaded.compile_audit
		)
		if not report.get("ok", false):
			return _error("MES no-op corpus reopen failed for %s: %s" % [
				row.entry, report.get("error", "failed"),
			])
		if not _entry_matches(row, report):
			return _error("MES no-op corpus entry differs from its manifest: %s" % row.entry)
		_accumulate(aggregate, report)
		stream.append_array(("%s\t%s\t%s\n" % [
			str(row.entry),
			str(row.compile_audit_sha256),
			str(report.payload_sha256),
		]).to_utf8_buffer())
		if progress is Callable and progress.is_valid():
			progress.call(position + 1, (manifest.entries as Array).size(), str(row.entry))
	var source_after := str(source_fingerprint.call())
	if source_after != source_before:
		return _error("MES no-op corpus source archive changed during reopen.")
	if aggregate != _integer_dictionary(manifest.coverage, COVERAGE_KEYS):
		return _error("MES no-op corpus GDScript coverage differs from its manifest.")
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_NOOP_REOPEN_CORPUS_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_noop_corpus_reopen",
			"contract": ContentCoreVersionScript.MES_NOOP_REOPEN_CORPUS_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_compile_spool_and_current_phase1_4_schemas",
			"input_compile_spool_schema": ContentCoreVersionScript.MES_NOOP_COMPILE_SPOOL_SCHEMA,
			"input_compile_audit_schema": ContentCoreVersionScript.MES_NOOP_COMPILE_AUDIT_SCHEMA,
			"entry_reopen_schema": ContentCoreVersionScript.MES_NOOP_REOPEN_AUDIT_SCHEMA,
			"unknown_corpus_schema": "reject",
			"unknown_v1_field": "reject",
		},
		"source_identity": manifest.source_identity.duplicate(true),
		"input_compile_spool_sha256": str(manifest.payload_sha256),
		"entry_count": int(manifest.entry_count),
		"source_entry_count": int(manifest.source_entry_count),
		"complete_archive": bool(manifest.complete_archive),
		"coverage": aggregate,
		"reopen_stream_sha256": ContractValues.sha256(stream),
		"invariants": {
			"compile_spool_fingerprint_valid": true,
			"every_entry_reopened": true,
			"every_compile_audit_valid": true,
			"every_phase1_4_handoff_verified": true,
			"aggregate_coverage_matches": true,
			"source_archive_unchanged": true,
		},
	}
	result["payload_sha256"] = ReopenAuditScript.new().fingerprint(result)
	return result


func validate_manifest(document: Dictionary) -> Dictionary:
	if (
		str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_NOOP_COMPILE_SPOOL_SCHEMA
		or not document.get("ok", false)
		or not ContractValues.has_exact_keys(document, MANIFEST_KEYS)
	):
		return _error("MES no-op compile-spool schema or fields changed.")
	if document.get("producer", {}) != {
		"implementation": "python_phase6_noop_corpus_compiler",
		"contract": ContentCoreVersionScript.MES_NOOP_COMPILE_SPOOL_SCHEMA,
	}:
		return _error("MES no-op compile-spool producer changed.")
	if document.get("compatibility", {}) != {
		"policy": "exact_phase1_5_handoff_and_noop_compile_contracts",
		"input_spool_schema": ContentCoreVersionScript.MES_DECOMPILER_HANDOFF_SPOOL_SCHEMA,
		"input_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		"decompiler_schema": ContentCoreVersionScript.MES_DECOMPILER_IR_SCHEMA,
		"editable_ir_schema": ContentCoreVersionScript.MES_EDITABLE_IR_SCHEMA,
		"compile_audit_schema": ContentCoreVersionScript.MES_NOOP_COMPILE_AUDIT_SCHEMA,
		"unknown_spool_schema": "reject",
		"unknown_v1_field": "reject",
		"payload_policy": "compiled_mes_and_compact_audit_only",
	}:
		return _error("MES no-op compile-spool compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if (
		not ContractValues.is_sha256(retained_hash)
		or ReopenAuditScript.new().fingerprint(document) != retained_hash
	):
		return _error("MES no-op compile-spool fingerprint changed.")
	var source_identity = document.get("source_identity", null)
	if (
		not source_identity is Dictionary
		or str(source_identity.get("archive", "")).is_empty()
		or not ContractValues.is_sha256(str(source_identity.get("archive_sha256", "")))
	):
		return _error("MES no-op compile-spool source identity changed.")
	var source_spool = document.get("source_spool", null)
	if (
		not source_spool is Dictionary
		or not ContractValues.has_exact_keys(source_spool, ["schema", "payload_sha256"])
		or str(source_spool.schema)
		!= ContentCoreVersionScript.MES_DECOMPILER_HANDOFF_SPOOL_SCHEMA
		or not ContractValues.is_sha256(str(source_spool.payload_sha256))
	):
		return _error("MES no-op compile source-spool identity changed.")
	if document.get("invariants", {}) != MANIFEST_INVARIANTS:
		return _error("MES no-op compile-spool invariants changed.")
	var entries = document.get("entries", null)
	if not entries is Array or entries.is_empty():
		return _error("MES no-op compile-spool entries are missing.")
	var previous_archive_index := -1
	var names := {}
	var files := {}
	for position in range(entries.size()):
		var row = entries[position]
		if not row is Dictionary or not ContractValues.has_exact_keys(row, ENTRY_KEYS):
			return _error("MES no-op compile-spool entry fields changed.")
		if int(row.position) != position or int(row.archive_index) <= previous_archive_index:
			return _error("MES no-op compile-spool order changed.")
		previous_archive_index = int(row.archive_index)
		var entry := str(row.entry)
		if entry.is_empty() or names.has(entry.to_lower()):
			return _error("MES no-op compile-spool entry identity changed.")
		names[entry.to_lower()] = true
		for key in ["mes_file", "audit_file"]:
			var file_name := str(row[key])
			if not _safe_file_name(file_name) or files.has(file_name.to_lower()):
				return _error("MES no-op compile-spool output file changed.")
			files[file_name.to_lower()] = true
		for key in [
			"handoff_sha256", "decompiler_ir_sha256", "editable_ir_sha256",
			"compile_audit_sha256", "entry_sha256", "bytecode_sha256",
		]:
			if not ContractValues.is_sha256(str(row[key])):
				return _error("MES no-op compile-spool entry hash changed.")
		for key in [
			"size", "code_size", "region_count", "node_count",
			"typed_node_count", "opaque_node_count",
		]:
			if not _is_nonnegative_json_integer(row[key]):
				return _error("MES no-op compile-spool entry count changed.")
		if int(row.node_count) != int(row.typed_node_count) + int(row.opaque_node_count):
			return _error("MES no-op compile-spool node partition changed.")
	if (
		not _is_nonnegative_json_integer(document.get("entry_count", -1))
		or not _is_nonnegative_json_integer(document.get("source_entry_count", -1))
		or int(document.entry_count) != entries.size()
		or int(document.source_entry_count) < entries.size()
		or bool(document.complete_archive)
		!= (int(document.entry_count) == int(document.source_entry_count))
	):
		return _error("MES no-op compile-spool scope changed.")
	var coverage = document.get("coverage", null)
	if not coverage is Dictionary or not ContractValues.has_exact_keys(coverage, COVERAGE_KEYS):
		return _error("MES no-op compile-spool coverage fields changed.")
	for key in COVERAGE_KEYS:
		if not _is_nonnegative_json_integer(coverage[key]):
			return _error("MES no-op compile-spool coverage changed.")
	if _coverage_from_rows(entries) != _integer_dictionary(coverage, COVERAGE_KEYS):
		return _error("MES no-op compile-spool aggregate changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_NOOP_COMPILE_SPOOL_SCHEMA,
		"entry_count": entries.size(),
		"complete_archive": bool(document.complete_archive),
		"payload_sha256": retained_hash,
	}


func _entry_matches(row: Dictionary, report: Dictionary) -> bool:
	return (
		str(report.source_identity.entry) == str(row.entry)
		and str(report.compile_audit_sha256) == str(row.compile_audit_sha256)
		and int(report.output.size) == int(row.size)
		and int(report.output.code_size) == int(row.code_size)
		and str(report.output.entry_sha256) == str(row.entry_sha256)
		and str(report.output.bytecode_sha256) == str(row.bytecode_sha256)
		and int(report.coverage.region_count) == int(row.region_count)
		and int(report.coverage.node_count) == int(row.node_count)
		and int(report.coverage.typed_node_count) == int(row.typed_node_count)
		and int(report.coverage.opaque_node_count) == int(row.opaque_node_count)
	)


func _accumulate(coverage: Dictionary, report: Dictionary) -> void:
	coverage.container_bytes += int(report.output.size)
	coverage.code_bytes += int(report.output.code_size)
	coverage.region_count += int(report.coverage.region_count)
	coverage.node_count += int(report.coverage.node_count)
	coverage.typed_node_count += int(report.coverage.typed_node_count)
	coverage.opaque_node_count += int(report.coverage.opaque_node_count)


func _coverage_from_rows(rows: Array) -> Dictionary:
	var output := _empty_coverage()
	for untyped_row in rows:
		var row: Dictionary = untyped_row
		output.container_bytes += int(row.size)
		output.code_bytes += int(row.code_size)
		output.region_count += int(row.region_count)
		output.node_count += int(row.node_count)
		output.typed_node_count += int(row.typed_node_count)
		output.opaque_node_count += int(row.opaque_node_count)
	return output


func _empty_coverage() -> Dictionary:
	return {
		"container_bytes": 0,
		"code_bytes": 0,
		"region_count": 0,
		"node_count": 0,
		"typed_node_count": 0,
		"opaque_node_count": 0,
	}


func _integer_dictionary(document: Dictionary, keys: Array) -> Dictionary:
	var output := {}
	for key in keys:
		output[key] = int(document[key])
	return output


func _safe_file_name(value: String) -> bool:
	return (
		not value.is_empty()
		and value.get_file() == value
		and not value.contains("/")
		and not value.contains("\\")
		and not value.contains(":")
	)


func _is_nonnegative_json_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 0
	if typeof(value) == TYPE_FLOAT:
		return float(value) >= 0.0 and float(value) == floor(float(value))
	return false


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
