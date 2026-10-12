extends "res://tests/test_case.gd"

## MW-11 operation sequences: the independent Godot validator for the chain
## proof (`kakyu_mes_semantic_diff_chain/v1`) over a real stepped bundle
## published by the actual Python pipeline through the Authoring session.

const SessionScript := preload("res://tools/content_suite/mes_authoring_session.gd")
const ChainScript := preload("res://content_core/mes_semantic_diff_chain.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://mes_semantic_diff_chain_test"


func _ready() -> void:
	_cleanup()
	var root := ProjectSettings.globalize_path(TEST_ROOT)
	var archive_root := root.path_join("archive")
	DirAccess.make_dir_recursive_absolute(archive_root)
	var archive_path := archive_root.path_join("mes.arc")
	# MW-11 sequence spec's synthetic entry: nodes at 0 global_u8_write_run, 6
	# continuation_transfer (target 0x10), 11 text "あ", 15/16 command_00
	# (analysis/mw11_sequence_synthetic_probe.py). Sequence S = [state
	# literal value 2, retarget 16 -> 11, replace_message "変更確認"].
	var source := "0100000000000000031e0101ff000c100000000182a0000000".hex_decode()
	SyntheticArc.write_arc(archive_path, [{"name": "TEST.MES", "data": source}])

	var session := SessionScript.new()
	var workspace := root.path_join("workspace")
	DirAccess.make_dir_recursive_absolute(workspace)
	var started := session.inspect(archive_path, "TEST.MES", _sha256(source), workspace)
	_check(started.get("ok", false), "Authoring session starts analyzing the synthetic entry: %s" % str(started.get("error", "ok")))
	var inspected := await _wait(session)
	_check(inspected.get("ok", false), "Authoring session analyzes the synthetic entry: %s" % str(inspected.get("error", "ok")))
	if not inspected.get("ok", false):
		_cleanup()
		get_tree().quit(1)
		return

	var summary: Dictionary = inspected.manifest.summary
	var state_op: Dictionary = (summary.state_controls[0] as Dictionary).operation.duplicate(true)
	state_op.value = 2
	var control_op: Dictionary = (summary.control_target_controls[0] as Dictionary).operation.duplicate(true)
	control_op.replacement_target_offset = 11
	var message_op: Dictionary = (summary.message_controls[0] as Dictionary).operation.duplicate(true)
	message_op.text = "変更確認"

	var compile_started := session.compile_sequence(inspected.directory, [state_op, control_op, message_op], workspace)
	_check(compile_started.get("ok", false), "Authoring session starts compiling the staged three-step sequence: %s" % str(compile_started.get("error", "ok")))
	var compiled := await _wait(session)
	_check(compiled.get("ok", false), "Authoring session compiles and publishes the stepped bundle: %s" % str(compiled.get("error", "ok")))
	if not compiled.get("ok", false):
		_cleanup()
		get_tree().quit(1)
		return
	_check(int(compiled.manifest.summary.step_count) == 3, "The published bundle summary reports three chained steps")

	var proof: Dictionary = compiled.proof
	var validator := ChainScript.new()
	var result := validator.validate(proof)
	_check(result.get("ok", false) and str(result.get("schema", "")) == "kakyu_mes_semantic_diff_chain/v1", "The chain validator accepts the real published chain proof: %s" % str(result.get("error", "ok")))

	var rehashed := proof.duplicate(true)
	rehashed.source_binding.entry_sha256 = "f".repeat(64)
	_rehash(rehashed)
	_check(not validator.validate(rehashed).get("ok", false), "The chain validator rejects a rehashed source-binding field")

	var reordered := proof.duplicate(true)
	var steps: Array = reordered.steps
	var swapped: Array = [steps[1], steps[0], steps[2]]
	for index in range(swapped.size()):
		swapped[index] = (swapped[index] as Dictionary).duplicate(true)
		swapped[index].index = index + 1
	reordered.steps = swapped
	_rehash(reordered)
	_check(not validator.validate(reordered).get("ok", false), "The chain validator rejects a reordered step")

	var forged := proof.duplicate(true)
	forged.composition = (forged.composition as Dictionary).duplicate(true)
	forged.composition.relocation_step_index = 1
	_rehash(forged)
	_check(not validator.validate(forged).get("ok", false), "The chain validator rejects a relocation-not-last forgery")

	_check(not ChainScript.new().validate({"ok": true, "schema": "kakyu_mes_semantic_diff/v2"}).get("ok", false), "The chain validator rejects a single-step v2 proof")

	_cleanup()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _rehash(document: Dictionary) -> void:
	document.payload_sha256 = FingerprintScript.new().fingerprint(document)


func _wait(session: SessionScript) -> Dictionary:
	var started := Time.get_ticks_msec()
	var deadline := started + AUTHORING_HANG_GUARD_SECONDS * 1000
	while session.is_running() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not session.is_running():
			break
		var completed = session.poll()
		if completed.get("finished", false):
			print("AUTHORING_WAIT ", authoring_wait_note(started))
			return completed.result
	if session.is_running():
		return {"ok": false, "error": "Authoring background process did not finish within its test deadline (%s)." % authoring_wait_note(started)}
	return {"ok": false, "error": "Authoring background process reported no result."}


func _sha256(payload: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish().hex_encode()


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
