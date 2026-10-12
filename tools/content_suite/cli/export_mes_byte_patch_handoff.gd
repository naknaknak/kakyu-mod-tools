extends "res://tools/content_suite/cli_script.gd"

const StateReopenScript := preload("res://content_core/mes_state_literal_compile_reopen.gd")
const ConditionReopenScript := preload("res://content_core/mes_condition_literal_compile_reopen.gd")
const ResourceReopenScript := preload("res://content_core/mes_resource_name_compile_reopen.gd")
const InlineReopenScript := preload("res://content_core/mes_inline_script_name_compile_reopen.gd")
const SharedCallReopenScript := preload("res://content_core/mes_shared_routine_call_compile_reopen.gd")
const RegisteredCallReopenScript := preload("res://content_core/mes_registered_definition_call_compile_reopen.gd")
const ControlTargetReopenScript := preload("res://content_core/mes_control_target_edit_compile_reopen.gd")
const ChoiceOptionReopenScript := preload("res://content_core/mes_choice_option_compile_reopen.gd")
const AddressEntryReopenScript := preload("res://content_core/mes_address_entry_insert_compile_reopen.gd")
const MessageReopenScript := preload("res://content_core/mes_message_compile_reopen.gd")
const ControlRelocationReopenScript := preload("res://content_core/mes_control_target_compile_reopen.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const MAX_MES_BYTES := 64 * 1024 * 1024
const MAX_JSON_BYTES := 32 * 1024 * 1024
const REOPEN_BY_SCHEMA := {
	"kakyu_mes_state_literal_compile_audit/v1": StateReopenScript,
	"kakyu_mes_condition_literal_compile_audit/v1": ConditionReopenScript,
	"kakyu_mes_resource_name_compile_audit/v1": ResourceReopenScript,
	"kakyu_mes_inline_script_name_compile_audit/v1": InlineReopenScript,
	"kakyu_mes_shared_routine_call_compile_audit/v1": SharedCallReopenScript,
	"kakyu_mes_registered_definition_call_compile_audit/v1": RegisteredCallReopenScript,
	"kakyu_mes_control_target_edit_compile_audit/v1": ControlTargetReopenScript,
	"kakyu_mes_choice_option_compile_audit/v1": ChoiceOptionReopenScript,
	"kakyu_mes_address_entry_insert_compile_audit/v1": AddressEntryReopenScript,
	"kakyu_mes_message_compile_audit/v1": MessageReopenScript,
	"kakyu_mes_control_target_compile_audit/v1": ControlRelocationReopenScript,
}


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 3:
		_fail("Usage: export_mes_byte_patch_handoff.gd <output.mes> <compile-audit.json> <new-handoff.json>", 2)
		return
	var mes_path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var audit_path := ProjectSettings.globalize_path(str(arguments[1])).simplify_path()
	var output_path := ProjectSettings.globalize_path(str(arguments[2])).simplify_path()
	if output_path in [mes_path, audit_path] or FileAccess.file_exists(output_path):
		_fail("MES byte-patch handoff output must be a new distinct file.", 2)
		return
	var payload := _read_bounded(mes_path, MAX_MES_BYTES)
	var audit_bytes := _read_bounded(audit_path, MAX_JSON_BYTES)
	var compile_audit = JSON.parse_string(audit_bytes.get_string_from_utf8())
	if payload.is_empty() or not compile_audit is Dictionary:
		_fail("MES byte-patch handoff inputs could not be read.", 2)
		return
	var schema := str(compile_audit.get("schema", ""))
	if not REOPEN_BY_SCHEMA.has(schema):
		_fail("MES byte-patch compile audit schema is unsupported.", 2)
		return
	var reopen = (REOPEN_BY_SCHEMA[schema] as GDScript).new().audit(payload, compile_audit)
	if not reopen.get("ok", false):
		_fail(str(reopen.get("error", "MES byte-patch reopen failed.")), 1)
		return
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	source_identity.erase("entry_sha256")
	var document := MesContainerScript.new().parse(payload, source_identity)
	var analysis_builder := MesAnalysisScript.new()
	var analysis := analysis_builder.build(document) if document.get("ok", false) else {}
	if (
		reopen.get("phase1_4", {}).get("analysis_mode", "strict") == "structural_relocation"
		and document.get("ok", false)
	):
		analysis = analysis_builder.build_structural(document)
	if not analysis.get("ok", false):
		_fail("MES byte-patch output analysis failed for handoff export.", 1)
		return
	var builder := AnalyzerHandoffScript.new()
	var handoff := builder.build(document, analysis)
	var verified: Dictionary = builder.verify(handoff)
	if not verified.get("ok", false):
		_fail("MES byte-patch output handoff failed verification.", 1)
		return
	var encoded := builder.to_json(handoff) + "\n"
	if not _write_new_text(output_path, encoded):
		_fail("MES byte-patch output handoff could not be published.", 1)
		return
	var reopened_bytes := _read_bounded(output_path, MAX_JSON_BYTES)
	var source_after := _read_bounded(mes_path, MAX_MES_BYTES)
	if (
		reopened_bytes.get_string_from_utf8() != encoded
		or ContractValues.sha256(source_after) != str(compile_audit.output.entry_sha256)
		or ContractValues.sha256(reopened_bytes) != ContractValues.sha256(encoded.to_utf8_buffer())
	):
		DirAccess.remove_absolute(output_path)
		_fail("Published MES byte-patch handoff failed exact reread verification.", 1)
		return
	print(
		"MES_BYTE_PATCH_HANDOFF_PASS schema=", handoff.schema,
		" audit_schema=", schema, " entry=", source_identity.entry,
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
