extends "res://tests/test_case.gd"

const ContextIndexScript := preload("res://content_core/mes_context_index.gd")


func _ready() -> void:
	var code := PackedByteArray([0x14, 0x1A, 0xFF, 8, 0, 0, 0, 0x00, 0x00])
	var document := {
		"ok": true,
		"bytecode": code,
		"bootstrap": {"size": 0},
		"entries": [{"id": "entry_0000", "index": 0, "offset": 0, "end_offset": code.size()}],
	}
	var index := ContextIndexScript.new().build(document, [0])
	_check(index.ok and index.schema == "kakyu_mes_context_index/v1", "context index uses a versioned shared-core schema")
	if index.ok:
		var registration: Dictionary = index.by_id[26][0]
		_check(
			index.complete
			and index.registration_count == 1
			and registration.registration_offset == 0
			and registration.body_offset == 7
			and registration.skip_target == 8
			and registration.body_size == 1,
			"context index retains literal selector and exact body/skip bounds"
		)

	var invalid_code := PackedByteArray([0x14, 0x1A, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00])
	var invalid_document := {
		"ok": true,
		"bytecode": invalid_code,
		"bootstrap": {"size": 0},
		"entries": [{"id": "entry_0000", "index": 0, "offset": 0, "end_offset": invalid_code.size()}],
	}
	var invalid := ContextIndexScript.new().build(invalid_document, [0])
	_check(
		invalid.ok and not invalid.complete and invalid.registration_count == 0
		and invalid.rejected[0].reason == "target_out_of_bounds",
		"context index rejects an out-of-bounds registration without inventing a body"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
