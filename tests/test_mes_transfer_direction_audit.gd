extends Node

const AuditScript := preload("res://content_core/mes_transfer_direction_audit.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

var _failed := false


func _ready() -> void:
	var document := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
		"source": {"entry": "SYNTH.MES"},
		"entry_sha256": "synthetic",
		"header": {"code_size": 100},
		"bootstrap": {"offset": 0, "end_offset": 0},
		"entries": [
			{"id": "entry_0000", "offset": 0, "end_offset": 50},
			{"id": "entry_0001", "offset": 50, "end_offset": 100},
		],
	}
	var analysis := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
		"instructions": [
			_instruction("branch_if_not_true", 20, "entry_0000", 10),
			_instruction("continuation_transfer", 30, "entry_0000", 60),
			_instruction("continuation_transfer", 70, "entry_0001", 50),
			_instruction("branch_if_not_true", 80, "entry_0001", 110),
			{"op": "text", "source_offset": 90, "region": "entry_0001", "operands": []},
		],
		"opaque_boundary_count": 1,
		"opaque_boundaries": [{"byte_length": 5}],
	}
	var audit := AuditScript.new().audit(document, analysis)
	_check(audit.ok, "transfer-direction audit accepts current typed MES inputs")
	_check(
		audit.schema == ContentCoreVersionScript.MES_TRANSFER_DIRECTION_AUDIT_SCHEMA,
		"transfer-direction audit emits its versioned schema"
	)
	_check(audit.transfer_count == 4, "only typed branch and continuation transfers are counted")
	_check(
		int(audit.counts.branch_if_not_true_backward_same_region) == 1
		and int(audit.counts.continuation_transfer_forward_cross_region) == 1
		and int(audit.counts.continuation_transfer_backward_same_region) == 1
		and int(audit.counts.branch_if_not_true_invalid) == 1,
		"direction and address-table-region relations are classified independently"
	)
	_check(
		audit.same_region_backward_candidates.size() == 2
		and int(audit.same_region_backward_candidates[0].source_offset) == 20
		and int(audit.same_region_backward_candidates[1].source_offset) == 70,
		"same-region backward candidates are retained in deterministic source order"
	)
	_check(
		audit.invalid_targets.size() == 1
		and int(audit.invalid_targets[0].target_offset) == 110,
		"out-of-code transfer targets fail closed instead of acquiring a direction"
	)
	_check(
		audit.opaque_boundary_count == 1
		and audit.opaque_bytes == 5
		and audit.opaque_policy == "unresolved_not_scanned_as_transfer",
		"opaque bytes remain explicitly outside the typed-transfer absence claim"
	)
	_check(
		not AuditScript.new().audit({"ok": false}, analysis).ok,
		"invalid MES inputs fail closed"
	)
	get_tree().quit(1 if _failed else 0)


func _instruction(op: String, source_offset: int, region: String, target: int) -> Dictionary:
	return {
		"op": op,
		"source_offset": source_offset,
		"region": region,
		"operands": [{"type": "code_offset", "value": target}],
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
