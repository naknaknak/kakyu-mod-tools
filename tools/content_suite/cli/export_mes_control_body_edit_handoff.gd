extends "res://tools/content_suite/cli_script.gd"

const ReopenScript := preload("res://content_core/mes_control_body_edit_compile_reopen.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const MAX_MES_BYTES := 64 * 1024 * 1024
const MAX_AUDIT_BYTES := 32 * 1024 * 1024


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 3:
		_fail("Usage: export_mes_control_body_edit_handoff.gd <output.mes> <compile-audit.json> <output-handoff.json>", 2)
		return
	var mes_path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var audit_path := ProjectSettings.globalize_path(str(arguments[1])).simplify_path()
	var output_path := ProjectSettings.globalize_path(str(arguments[2])).simplify_path()
	if output_path in [mes_path, audit_path] or FileAccess.file_exists(output_path):
		_fail("MES control-body handoff output must be a new distinct file.", 2)
		return
	var payload := _read_bounded(mes_path, MAX_MES_BYTES)
	var audit_bytes := _read_bounded(audit_path, MAX_AUDIT_BYTES)
	if payload.is_empty() or audit_bytes.is_empty():
		_fail("MES control-body handoff inputs cannot be read within their size limits.", 2)
		return
	var compile_audit = JSON.parse_string(audit_bytes.get_string_from_utf8())
	if not compile_audit is Dictionary:
		_fail("MES control-body compile audit is not a JSON object.", 2)
		return
	var reopen := ReopenScript.new().audit(payload, compile_audit)
	if not reopen.ok:
		_fail(str(reopen.error), 1)
		return
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		_fail("MES control-body output did not reopen for handoff export.", 1)
		return
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		_fail("MES control-body output analysis failed for handoff export.", 1)
		return
	var builder := AnalyzerHandoffScript.new()
	var handoff := builder.build(document, analysis)
	var verified: Dictionary = builder.verify(handoff)
	if not verified.get("ok", false):
		_fail("MES control-body output handoff failed verification: %s" % verified.get("error", "failed"), 1)
		return
	var encoded := builder.to_json(handoff)
	if encoded.is_empty() or not _write_new_text(output_path, encoded + "\n"):
		_fail("MES control-body output handoff could not be published.", 1)
		return
	var reopened_bytes := _read_bounded(output_path, MAX_AUDIT_BYTES)
	var reopened = JSON.parse_string(reopened_bytes.get_string_from_utf8())
	if (
		not reopened is Dictionary
		or reopened_bytes.get_string_from_utf8() != encoded + "\n"
		or str(reopened.get("payload_sha256", "")) != str(handoff.payload_sha256)
	):
		DirAccess.remove_absolute(output_path)
		_fail("Published MES control-body handoff failed exact reread verification.", 1)
		return
	if str(reopened.payload_sha256) != str(handoff.payload_sha256) or ContractValues.sha256(_read_bounded(mes_path, MAX_MES_BYTES)) != str(compile_audit.output.entry_sha256):
		DirAccess.remove_absolute(output_path)
		_fail("MES control-body handoff or source output changed during publication.", 1)
		return
	print(
		"MES_CONTROL_BODY_EDIT_HANDOFF_PASS ",
		"schema=", handoff.schema,
		" entry=", source_identity.entry,
		" kind=", compile_audit.operation.kind,
		" typed=", handoff.typed_ir.instructions.size(),
		" opaque=", handoff.typed_ir.opaque_boundaries.size(),
		" payload_sha256=", handoff.payload_sha256,
		" source_output_unchanged=true"
	)
	quit(0)


func _write_new_text(path: String, text: String) -> bool:
	if FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK
