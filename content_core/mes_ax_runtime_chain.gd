class_name KakyuMesAxRuntimeChain
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const AxSurfaceBindingScript := preload("res://content_core/ax_surface_binding.gd")

var _surface_binding := AxSurfaceBindingScript.new()


func begin(audit: Dictionary, trace_record: Dictionary, source_size: Vector2i) -> Dictionary:
	if (
		not audit.get("ok", false)
		or str(audit.get("schema", "")) != ContentCoreVersionScript.MES_ACTIVE_SURFACE_AX_AUDIT_SCHEMA
	):
		return _error("A versioned MES active-surface AX audit is required.")
	var surface_binding := _surface_binding.from_mmo_trace(trace_record, source_size)
	if not surface_binding.get("ok", false):
		return _error(str(surface_binding.get("error", "MMO surface binding was rejected.")))
	var matches: Array[Dictionary] = []
	for value in audit.get("chains", []):
		if not value is Dictionary:
			continue
		var chain: Dictionary = value
		if (
			int(chain.get("mmo_marker_offset", -1)) == int(trace_record.get("source_offset", -1))
			and int(chain.get("mmo_outer_offset", -1)) == int(trace_record.get("outer_command_source_offset", -1))
			and str(chain.get("mmo_name", "")).to_upper() == str(trace_record.get("resource_name", "")).to_upper()
			and str(chain.get("boundary", "")) == "ordered_structural_bytes"
			and str(chain.get("reachability", "")) == "not_proven_by_scan"
		):
			matches.append(chain)
	if matches.size() != 1:
		return _error("MMO trace does not identify exactly one audited surface-8/AX chain.")
	var selected: Dictionary = matches[0]
	if (
		int(selected.get("selected_surface", -1)) != 8
		or int(selected.get("restored_surface", -1)) != 7
		or int(selected.get("ax_marker_offset", -1)) < int(selected.get("mmo_end_offset", -1))
		or int(selected.get("binding_offset", -1)) < int(selected.get("ax_end_offset", -1))
		or int(selected.get("binding_row", -1)) < 0
		or int(selected.get("binding_column", -1)) < 0
	):
		return _error("Audited MES chain is incomplete or out of order.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_AX_RUNTIME_CHAIN_SCHEMA,
		"status": "pending_exact_ax_trace",
		"entry": str(audit.get("entry", "")),
		"chain": selected.duplicate(true),
		"source_binding": surface_binding.duplicate(true),
	}


func finalize(pending: Dictionary, trace: Array) -> Dictionary:
	if (
		not pending.get("ok", false)
		or str(pending.get("schema", "")) != ContentCoreVersionScript.MES_AX_RUNTIME_CHAIN_SCHEMA
		or str(pending.get("status", "")) != "pending_exact_ax_trace"
	):
		return _error("A pending MES/AX runtime chain is required.")
	var chain: Dictionary = pending.get("chain", {})
	var exact_ax_count := 0
	var exact_binding_count := 0
	for value in trace:
		if not value is Dictionary:
			continue
		var record: Dictionary = value
		if (
			str(record.get("effect", "")) == "ax_resource_marker"
			and int(record.get("source_offset", -1)) == int(chain.get("ax_marker_offset", -1))
			and str(record.get("resource_name", "")).to_upper() == str(chain.get("ax_name", "")).to_upper()
		):
			exact_ax_count += 1
		if (
			str(record.get("effect", "")) == "ax_presentation_binding"
			and int(record.get("source_offset", -1)) == int(chain.get("binding_offset", -1))
			and int(record.get("cell_row", -1)) == int(chain.get("binding_row", -1))
			and int(record.get("cell_column", -1)) == int(chain.get("binding_column", -1))
		):
			exact_binding_count += 1
	if exact_ax_count != 1 or exact_binding_count != 1:
		return _error("Runtime trace does not complete the exact audited AX marker and binding.")
	var source_binding: Dictionary = pending.get("source_binding", {})
	var source_size := Vector2i(
		int(source_binding.get("source_width", -1)),
		int(source_binding.get("source_height", -1))
	)
	var validated := _surface_binding.validate(source_binding, source_size)
	if not validated.get("ok", false):
		return _error(str(validated.get("error", "AX source binding changed.")))
	var result := pending.duplicate(true)
	result["status"] = "runtime_trace_confirmed"
	result["ax_marker_offset"] = int(chain.get("ax_marker_offset", -1))
	result["binding_offset"] = int(chain.get("binding_offset", -1))
	result["binding_row"] = int(chain.get("binding_row", -1))
	result["binding_column"] = int(chain.get("binding_column", -1))
	return result


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"schema": ContentCoreVersionScript.MES_AX_RUNTIME_CHAIN_SCHEMA,
		"error": message,
	}
