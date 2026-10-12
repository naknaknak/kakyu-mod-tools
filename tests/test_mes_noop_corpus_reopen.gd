extends "res://tests/test_case.gd"

const CorpusReopenScript := preload("res://content_core/mes_noop_corpus_reopen.gd")
const EntryReopenScript := preload("res://content_core/mes_noop_compile_reopen.gd")
const EntryFixtureScript := preload("res://tests/test_mes_noop_compile_reopen.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")


func _ready() -> void:
	var fixture := EntryFixtureScript.new()
	var payload: PackedByteArray = fixture.call("_framed_mes")
	var entry_validator := EntryReopenScript.new()
	var compile_audit: Dictionary = fixture.call(
		"_compile_audit", payload, entry_validator
	)
	fixture.free()
	var entry_report: Dictionary = entry_validator.audit(payload, compile_audit)
	var manifest := _manifest(entry_report, compile_audit, entry_validator)
	var validator := CorpusReopenScript.new()
	var loader := func(row: Dictionary) -> Dictionary:
		return {
			"ok": str(row.entry) == "SYNTHETIC.MES",
			"payload": payload,
			"compile_audit": compile_audit,
		}
	var source_fingerprint := func() -> String:
		return "3".repeat(64)
	var report: Dictionary = validator.audit(manifest, loader, source_fingerprint)
	var repeated: Dictionary = validator.audit(manifest, loader, source_fingerprint)
	_check(
		report.get("ok", false)
		and report.schema
		== ContentCoreVersionScript.MES_NOOP_REOPEN_CORPUS_AUDIT_SCHEMA
		and report.entry_count == 1
		and report.complete_archive
		and report.coverage.container_bytes == payload.size()
		and report.coverage.node_count == 3
		and report.coverage.opaque_node_count == 1
		and report.invariants.source_archive_unchanged,
		"GDScript corpus audit reopens every no-op output through Phase 1-4"
	)
	_check(
		report == repeated
		and report.payload_sha256 == entry_validator.fingerprint(report),
		"GDScript no-op corpus audit is deterministic and fingerprinted"
	)
	var transported = JSON.parse_string(JSON.stringify(manifest))
	_check(
		validator.audit(transported, loader, source_fingerprint).get("ok", false),
		"GDScript no-op corpus audit retains the Python manifest fingerprint across JSON transport"
	)
	_check(
		not validator.audit(
			manifest, loader, func() -> String: return "4".repeat(64)
		).get("ok", false),
		"GDScript no-op corpus audit rejects a different source archive"
	)
	var changed_coverage: Dictionary = manifest.duplicate(true)
	changed_coverage.entries[0].node_count = 2
	changed_coverage.entries[0].typed_node_count = 1
	changed_coverage.coverage.node_count = 2
	changed_coverage.coverage.typed_node_count = 1
	changed_coverage.payload_sha256 = entry_validator.fingerprint(changed_coverage)
	_check(
		not validator.audit(changed_coverage, loader, source_fingerprint).get("ok", false),
		"GDScript no-op corpus audit rejects rehashed per-entry coverage changes"
	)
	var unknown_field: Dictionary = manifest.duplicate(true)
	unknown_field["ignored_entry"] = true
	unknown_field.payload_sha256 = entry_validator.fingerprint(unknown_field)
	_check(
		not validator.audit(unknown_field, loader, source_fingerprint).get("ok", false),
		"GDScript no-op corpus audit rejects rehashed unknown manifest fields"
	)
	var unsafe_path: Dictionary = manifest.duplicate(true)
	unsafe_path.entries[0].mes_file = "../escape.mes"
	unsafe_path.payload_sha256 = entry_validator.fingerprint(unsafe_path)
	_check(
		not validator.audit(unsafe_path, loader, source_fingerprint).get("ok", false),
		"GDScript no-op corpus audit rejects manifest path traversal"
	)
	get_tree().quit(1 if _failed else 0)


func _manifest(
	report: Dictionary,
	compile_audit: Dictionary,
	fingerprinter: RefCounted
) -> Dictionary:
	var row := {
		"position": 0,
		"archive_index": 7,
		"entry": "SYNTHETIC.MES",
		"mes_file": "0000-synthetic.mes",
		"audit_file": "0000-synthetic.audit.json",
		"handoff_sha256": "4".repeat(64),
		"decompiler_ir_sha256": "5".repeat(64),
		"editable_ir_sha256": "6".repeat(64),
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"entry_sha256": str(report.output.entry_sha256),
		"bytecode_sha256": str(report.output.bytecode_sha256),
		"size": int(report.output.size),
		"code_size": int(report.output.code_size),
		"region_count": int(report.coverage.region_count),
		"node_count": int(report.coverage.node_count),
		"typed_node_count": int(report.coverage.typed_node_count),
		"opaque_node_count": int(report.coverage.opaque_node_count),
	}
	var document := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_NOOP_COMPILE_SPOOL_SCHEMA,
		"producer": {
			"implementation": "python_phase6_noop_corpus_compiler",
			"contract": ContentCoreVersionScript.MES_NOOP_COMPILE_SPOOL_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_phase1_5_handoff_and_noop_compile_contracts",
			"input_spool_schema": ContentCoreVersionScript.MES_DECOMPILER_HANDOFF_SPOOL_SCHEMA,
			"input_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
			"decompiler_schema": ContentCoreVersionScript.MES_DECOMPILER_IR_SCHEMA,
			"editable_ir_schema": ContentCoreVersionScript.MES_EDITABLE_IR_SCHEMA,
			"compile_audit_schema": ContentCoreVersionScript.MES_NOOP_COMPILE_AUDIT_SCHEMA,
			"unknown_spool_schema": "reject",
			"unknown_v1_field": "reject",
			"payload_policy": "compiled_mes_and_compact_audit_only",
		},
		"source_identity": {
			"archive": "mes.arc",
			"archive_sha256": "3".repeat(64),
		},
		"source_spool": {
			"schema": ContentCoreVersionScript.MES_DECOMPILER_HANDOFF_SPOOL_SCHEMA,
			"payload_sha256": "7".repeat(64),
		},
		"entry_count": 1,
		"source_entry_count": 1,
		"complete_archive": true,
		"entries": [row],
		"coverage": {
			"container_bytes": int(row.size),
			"code_bytes": int(row.code_size),
			"region_count": int(row.region_count),
			"node_count": int(row.node_count),
			"typed_node_count": int(row.typed_node_count),
			"opaque_node_count": int(row.opaque_node_count),
		},
		"invariants": {
			"all_compile_audits_valid": true,
			"all_outputs_byte_identical": true,
			"all_outputs_reopened": true,
			"all_operations_empty": true,
			"ordered_archive_scope_preserved": true,
			"manifest_published_last": true,
		},
	}
	document["payload_sha256"] = fingerprinter.call("fingerprint", document)
	return document
