extends Node

const AuditScript := preload("res://content_core/mes_active_surface_ax_audit.gd")
const RuntimeChainScript := preload("res://content_core/mes_ax_runtime_chain.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

var _failed := false


func _ready() -> void:
	var code := PackedByteArray()
	var select_offset := code.size()
	_append_surface_write(code, 8)
	code.append(0x0D)
	var mmo_offset := code.size()
	code.append_array(PackedByteArray([0x09, 0xFF, 0x01]))
	code.append_array("testan.mmo".to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x00]))
	var restore_offset := code.size()
	_append_surface_write(code, 7)
	var ax_offset := code.size()
	code.append_array(PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x00, 0xFF, 0x01]))
	code.append_array("test.ax".to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00]))
	var binding_offset := code.size()
	code.append_array(PackedByteArray([
		0x0D, 0x03, 0xFF,
		0x02, 0x00, 0xFF,
		0x02, 0x00, 0xFF,
		0x02, 0x02, 0xFF,
		0x02, 0x02, 0xF9, 0x00, 0xFF,
		0x00,
	]))
	var unmatched_write_offset := code.size()
	_append_surface_write(code, 8)
	code.append(0x00)
	var document := {
		"ok": true,
		"bytecode": code,
		"header": {"code_size": code.size()},
	}
	var result := AuditScript.new().scan_document(document, "TEST.MES")
	_check(result.ok, "active-surface AX structural scan succeeds")
	_check(result.schema == ContentCoreVersionScript.MES_ACTIVE_SURFACE_AX_AUDIT_SCHEMA, "active-surface AX audit is versioned")
	_check(result.surface8_writes == [select_offset, unmatched_write_offset], "all literal surface-8 writes remain visible")
	_check(result.canonical_chain_count == 1, "only a complete ordered MMO/restore/AX chain is promoted")
	var chain: Dictionary = result.chains[0]
	_check(
		chain.entry == "TEST.MES"
		and chain.boundary == "ordered_structural_bytes"
		and chain.reachability == "not_proven_by_scan"
		and chain.select_offset == select_offset
		and chain.mmo_outer_offset == mmo_offset - 1
		and chain.mmo_marker_offset == mmo_offset - 1
		and chain.mmo_name == "testan.mmo"
		and chain.restore_offset == restore_offset
		and chain.ax_marker_offset == ax_offset
		and chain.ax_name == "TEST.AX"
		and chain.binding_offset == binding_offset,
		"canonical chain retains every exact structural coordinate and resource"
	)
	_check(
		chain.active_surface_storage == "banked_u16"
		and chain.active_surface_bank == 0
		and chain.active_surface_storage_index == 1
		and chain.selected_surface == 8
		and chain.restored_surface == 7,
		"canonical chain binds the audited active-surface storage and values"
	)
	_check(
		not result.chains[0].has("active_surface_value_at_runtime"),
		"static structural scan does not invent a live runtime surface value"
	)
	_check(
		not AuditScript.new().scan_document({"ok": false}, "BAD.MES").ok,
		"invalid MES documents fail closed"
	)
	var runtime := RuntimeChainScript.new()
	var mmo_trace := {
		"effect": "mmo_resource_marker",
		"resource_name": "TESTAN.MMO",
		"source_offset": mmo_offset - 1,
		"outer_command_source_offset": mmo_offset - 1,
		"native_playback_semantics": "named_mmo_load_into_active_surface_confirmed",
		"native_active_surface_state_offset": 0x20BA,
		"native_active_surface_storage": "banked_u16",
		"native_active_surface_bank": 0,
		"native_active_surface_storage_index": 1,
		"native_active_surface_value": 8,
	}
	var pending := runtime.begin(result, mmo_trace, Vector2i(48, 168))
	_check(
		pending.ok
		and pending.schema == ContentCoreVersionScript.MES_AX_RUNTIME_CHAIN_SCHEMA
		and pending.status == "pending_exact_ax_trace",
		"runtime qualification starts only from the exact audited MMO surface-8 trace"
	)
	var completed := runtime.finalize(pending, [
		{"effect": "ax_resource_marker", "resource_name": "test.ax", "source_offset": ax_offset},
		{
			"effect": "ax_presentation_binding",
			"source_offset": binding_offset,
			"cell_row": int(chain.binding_row),
			"cell_column": int(chain.binding_column),
		},
	])
	_check(
		completed.ok
		and completed.status == "runtime_trace_confirmed"
		and completed.ax_marker_offset == ax_offset
		and completed.binding_offset == binding_offset,
		"exact runtime AX marker and binding finalize the structural chain"
	)
	var shifted_trace := mmo_trace.duplicate(true)
	shifted_trace["source_offset"] = mmo_offset
	_check(not runtime.begin(result, shifted_trace, Vector2i(48, 168)).ok, "shifted MMO trace fails closed")
	_check(not runtime.finalize(pending, [
		{"effect": "ax_resource_marker", "resource_name": "test.ax", "source_offset": ax_offset + 1},
		{
			"effect": "ax_presentation_binding",
			"source_offset": binding_offset,
			"cell_row": int(chain.binding_row),
			"cell_column": int(chain.binding_column),
		},
	]).ok, "shifted AX trace fails closed")
	_check(not runtime.finalize(pending, [
		{"effect": "ax_resource_marker", "resource_name": "test.ax", "source_offset": ax_offset},
		{
			"effect": "ax_presentation_binding",
			"source_offset": binding_offset,
			"cell_row": int(chain.binding_row),
			"cell_column": int(chain.binding_column) + 1,
		},
	]).ok, "wrong AX cell fails closed")
	if _failed:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _append_surface_write(code: PackedByteArray, value: int) -> void:
	code.append_array(PackedByteArray([0x07, 0x01, 0xFF, 0x00, value, 0xFF, 0x00]))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
