class_name KakyuMesStartupContext
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const MesContextIndexScript := preload("res://content_core/mes_context_index.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const ALLOWED_EFFECTS := {
	"bootstrap_transfer": true,
	"fallthrough": true,
	"internal_vector_clear": true,
	"script_return": true,
	"source_line_marker": true,
}


func build(document: Dictionary) -> Dictionary:
	if not document.get("ok", false):
		return _error("A valid MES container document is required.")
	var source := _document_source(document)
	if source == null:
		return _error("The startup definition document has no bytecode.")
	var result := MesEventRunnerScript.new().run(
		PackedByteArray(),
		0,
		SandboxStateScript.new(1),
		source.size(),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{"code_source": source}
	)
	if not result.get("ok", false) or str(result.get("status", "")) != "script_return":
		return _error("The zero-start context path did not reach a confirmed script return.")
	if not (result.get("messages", []) as Array).is_empty():
		return _error("The zero-start context path reached dialogue instead of a registration-only return.")
	if not (result.get("state_diff", []) as Array).is_empty():
		return _error("The zero-start context path changed gameplay sandbox state.")

	var registration_offsets: Array[int] = []
	var registration_trace: Array[Dictionary] = []
	var effect_counts := {}
	for untyped_record in result.get("trace", []):
		var record: Dictionary = untyped_record
		var effect := str(record.get("effect", ""))
		if not ALLOWED_EFFECTS.has(effect):
			return _error("The zero-start context path reached an unsupported effect: %s." % effect)
		effect_counts[effect] = int(effect_counts.get(effect, 0)) + 1
		if effect != "bootstrap_transfer":
			continue
		if (
			not record.get("native_context_map_changed", false)
			or str(record.get("state_scope", "")) != "native_script_manager_internal"
			or record.get("gameplay_sandbox_changed", true)
		):
			return _error("A context transfer lacks the isolated native-map contract.")
		registration_offsets.append(int(record.get("source_offset", -1)))
		registration_trace.append(record)
	if registration_offsets.is_empty():
		return _error("The zero-start context path exposed no registrations.")

	var context_index := MesContextIndexScript.new().build(document, registration_offsets)
	if not context_index.get("ok", false) or not context_index.get("complete", false):
		return _error("The reached registration coordinates did not build a complete context index.")
	var registrations: Array = context_index.get("registrations", [])
	if registrations.size() != registration_trace.size():
		return _error("The reached registration count changed during bounded indexing.")

	var source_identity: Dictionary = document.get("source", {})
	var source_entry := str(source_identity.get("entry", "unknown.MES"))
	var registered_definitions := {}
	var registration_records: Array[Dictionary] = []
	var selector_order: Array[int] = []
	for index in range(registrations.size()):
		var registration: Dictionary = registrations[index]
		var trace_record: Dictionary = registration_trace[index]
		var selector := int(registration.selector)
		if (
			int(trace_record.get("bootstrap_selector", -1)) != selector
			or int(trace_record.get("source_offset", -1)) != int(registration.registration_offset)
			or int(trace_record.get("next_offset", -1)) != int(registration.skip_target)
		):
			return _error("A traced context transfer does not match its bounded registration.")
		if registered_definitions.has(selector):
			return _error("Duplicate startup context selector %d is not accepted." % selector)
		var source_label := "%s:0x%X" % [source_entry, int(registration.registration_offset)]
		registered_definitions[selector] = {
			"code": document.get("bytecode", PackedByteArray()),
			"code_source": source,
			"body_offset": int(registration.body_offset),
			"end_offset": int(registration.skip_target),
			"source": source_label,
			"source_entry": source_entry,
		}
		registration_records.append({
			"selector": selector,
			"registration_offset": int(registration.registration_offset),
			"body_offset": int(registration.body_offset),
			"skip_target": int(registration.skip_target),
			"body_size": int(registration.body_size),
			"source": source_label,
			"source_entry": source_entry,
		})
		selector_order.append(selector)

	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_STARTUP_CONTEXT_SCHEMA,
		"scope": "zero_start_registration_path",
		"serialization_policy": "runtime_only_contains_source_bytecode",
		"source_entry": source_entry,
		"source_entry_sha256": str(document.get("entry_sha256", "")),
		"registration_count": registration_records.size(),
		"selector_order": selector_order,
		"registrations": registration_records,
		"registered_definitions": registered_definitions,
		"trace_count": (result.trace as Array).size(),
		"trace_effect_counts": effect_counts,
		"message_count": 0,
		"gameplay_state_diff_count": 0,
		"body_execution_semantics": "not_executed_during_projection",
	}



# A container document normally carries its bytecode. A document assembled from
# a playback package carries a code source instead; both answer the same
# questions. See mes_code_source.gd.
func _document_source(document: Dictionary) -> KakyuMesCodeSource:
	var supplied = document.get("code_source", null)
	if supplied is KakyuMesCodeSource:
		return supplied
	var code = document.get("bytecode", null)
	if code is PackedByteArray and not (code as PackedByteArray).is_empty():
		return KakyuMesCodeSource.for_bytecode(code)
	return null


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"schema": ContentCoreVersionScript.MES_STARTUP_CONTEXT_SCHEMA,
		"error": message,
	}
