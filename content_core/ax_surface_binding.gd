class_name KakyuAxSurfaceBinding
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const NATIVE_SOURCE_SURFACE_INDEX := 8
const ACTIVE_SURFACE_STATE_OFFSET := 0x20BA
const ACTIVE_SURFACE_STORAGE := "banked_u16"
const ACTIVE_SURFACE_BANK := 0
const ACTIVE_SURFACE_STORAGE_INDEX := 1


func from_mmo_trace(trace_record: Dictionary, source_size: Vector2i) -> Dictionary:
	if source_size.x <= 0 or source_size.y <= 0:
		return _error("AX source binding dimensions must be positive.")
	if (
		str(trace_record.get("effect", "")) != "mmo_resource_marker"
		or str(trace_record.get("resource_name", "")).is_empty()
		or int(trace_record.get("source_offset", -1)) < 0
		or int(trace_record.get("outer_command_source_offset", -1)) < 0
		or str(trace_record.get("native_playback_semantics", "")) != "named_mmo_load_into_active_surface_confirmed"
	):
		return _error("AX source binding requires one confirmed MMO active-surface trace.")
	if (
		int(trace_record.get("native_active_surface_state_offset", -1)) != ACTIVE_SURFACE_STATE_OFFSET
		or str(trace_record.get("native_active_surface_storage", "")) != ACTIVE_SURFACE_STORAGE
		or int(trace_record.get("native_active_surface_bank", -1)) != ACTIVE_SURFACE_BANK
		or int(trace_record.get("native_active_surface_storage_index", -1)) != ACTIVE_SURFACE_STORAGE_INDEX
		or int(trace_record.get("native_active_surface_value", -1)) != NATIVE_SOURCE_SURFACE_INDEX
	):
		return _error("MMO trace does not select the native AX source surface.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AX_SURFACE_BINDING_SCHEMA,
		"producer_kind": "mes_mmo_active_surface_load",
		"resource_name": str(trace_record.resource_name),
		"native_surface_index": NATIVE_SOURCE_SURFACE_INDEX,
		"native_state_offset": ACTIVE_SURFACE_STATE_OFFSET,
		"state_storage": ACTIVE_SURFACE_STORAGE,
		"state_bank": ACTIVE_SURFACE_BANK,
		"state_index": ACTIVE_SURFACE_STORAGE_INDEX,
		"state_value": NATIVE_SOURCE_SURFACE_INDEX,
		"source_width": source_size.x,
		"source_height": source_size.y,
		"source_offset": int(trace_record.get("source_offset", -1)),
		"outer_command_source_offset": int(trace_record.get("outer_command_source_offset", -1)),
	}


func validate(binding: Dictionary, source_size: Vector2i) -> Dictionary:
	if str(binding.get("schema", "")) != ContentCoreVersionScript.AX_SURFACE_BINDING_SCHEMA:
		return _error("AX source binding schema is not supported.")
	if (
		str(binding.get("producer_kind", "")) != "mes_mmo_active_surface_load"
		or str(binding.get("resource_name", "")).is_empty()
		or int(binding.get("native_surface_index", -1)) != NATIVE_SOURCE_SURFACE_INDEX
		or int(binding.get("native_state_offset", -1)) != ACTIVE_SURFACE_STATE_OFFSET
		or str(binding.get("state_storage", "")) != ACTIVE_SURFACE_STORAGE
		or int(binding.get("state_bank", -1)) != ACTIVE_SURFACE_BANK
		or int(binding.get("state_index", -1)) != ACTIVE_SURFACE_STORAGE_INDEX
		or int(binding.get("state_value", -1)) != NATIVE_SOURCE_SURFACE_INDEX
		or int(binding.get("source_width", -1)) != source_size.x
		or int(binding.get("source_height", -1)) != source_size.y
		or int(binding.get("source_offset", -1)) < 0
		or int(binding.get("outer_command_source_offset", -1)) < 0
	):
		return _error("AX source binding does not match the confirmed surface-8 MMO producer.")
	return {"ok": true}


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
