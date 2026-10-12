class_name KakyuEventAudioState
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const VOICE_POLICIES := ["replace", "queue", "overlap"]

var _bgm: Dictionary = {}
var _caller_bgm_stack: Array[Dictionary] = []
var _active_voices: Array[Dictionary] = []
var _voice_queue: Array[Dictionary] = []
var _voice_policy := "replace"
var _revision := 0


func reset() -> Dictionary:
	_bgm.clear()
	_caller_bgm_stack.clear()
	_active_voices.clear()
	_voice_queue.clear()
	_voice_policy = "replace"
	_revision += 1
	return _transition("reset")


func snapshot() -> Dictionary:
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.EVENT_AUDIO_STATE_SCHEMA,
		"revision": _revision,
		"bgm": _bgm.duplicate(true),
		"caller_bgm_stack": _caller_bgm_stack.duplicate(true),
		"active_voices": _active_voices.duplicate(true),
		"voice_queue": _voice_queue.duplicate(true),
		"voice_policy": _voice_policy,
	}


func set_voice_policy(policy: String) -> Dictionary:
	if policy not in VOICE_POLICIES:
		return _error("Voice policy must be replace, queue, or overlap.")
	if policy == _voice_policy:
		return _transition("retain_voice_policy")
	_voice_policy = policy
	_revision += 1
	return _transition("set_voice_policy")


func request_bgm(identity: Dictionary) -> Dictionary:
	var checked := _validated_identity(identity)
	if not checked.ok:
		return checked
	var next: Dictionary = checked.identity
	if _same_identity(_bgm, next):
		return _transition("retain_bgm", {"resource": next.duplicate(true)})
	var previous := _bgm.duplicate(true)
	_bgm = next.duplicate(true)
	_revision += 1
	return _transition("start_bgm" if previous.is_empty() else "replace_bgm", {
		"previous": previous,
		"resource": _bgm.duplicate(true),
	})


func stop_bgm() -> Dictionary:
	if _bgm.is_empty():
		return _transition("retain_bgm_stopped")
	var previous := _bgm.duplicate(true)
	_bgm.clear()
	_revision += 1
	return _transition("stop_bgm", {"previous": previous})


func push_caller_bgm(label: String = "") -> Dictionary:
	if _caller_bgm_stack.size() >= 64:
		return _error("Caller BGM stack exceeds the bounded depth.")
	_caller_bgm_stack.append({"label": label, "bgm": _bgm.duplicate(true)})
	_revision += 1
	return _transition("push_caller_bgm", {"depth": _caller_bgm_stack.size()})


func restore_caller_bgm() -> Dictionary:
	if _caller_bgm_stack.is_empty():
		return _error("Caller BGM stack is empty.")
	var frame: Dictionary = _caller_bgm_stack.pop_back()
	var restored: Dictionary = frame.get("bgm", {}).duplicate(true)
	var previous := _bgm.duplicate(true)
	_bgm = restored
	_revision += 1
	var action := "restore_bgm"
	if _same_identity(previous, restored):
		action = "retain_restored_bgm"
	elif restored.is_empty():
		action = "restore_bgm_stopped"
	return _transition(action, {
		"label": str(frame.get("label", "")),
		"previous": previous,
		"resource": restored.duplicate(true),
		"depth": _caller_bgm_stack.size(),
	})


func submit_voice(identity: Dictionary, policy: String = "") -> Dictionary:
	var checked := _validated_identity(identity)
	if not checked.ok:
		return checked
	var effective_policy := _voice_policy if policy.is_empty() else policy
	if effective_policy not in VOICE_POLICIES:
		return _error("Voice policy must be replace, queue, or overlap.")
	var resource: Dictionary = checked.identity
	match effective_policy:
		"replace":
			if _active_voices.size() == 1 and _voice_queue.is_empty() and _same_identity(_active_voices[0], resource):
				return _transition("retain_voice", {"resource": resource.duplicate(true)})
			var replaced := _active_voices.duplicate(true)
			_active_voices.assign([resource.duplicate(true)])
			_voice_queue.clear()
			_revision += 1
			return _transition("start_voice" if replaced.is_empty() else "replace_voice", {
				"resource": resource.duplicate(true),
				"replaced": replaced,
			})
		"queue":
			if _active_voices.is_empty():
				_active_voices.append(resource.duplicate(true))
				_revision += 1
				return _transition("start_voice", {"resource": resource.duplicate(true)})
			_voice_queue.append(resource.duplicate(true))
			_revision += 1
			return _transition("queue_voice", {
				"resource": resource.duplicate(true),
				"queue_position": _voice_queue.size() - 1,
			})
		"overlap":
			_active_voices.append(resource.duplicate(true))
			_revision += 1
			return _transition("start_voice" if _active_voices.size() == 1 else "overlap_voice", {
				"resource": resource.duplicate(true),
				"active_count": _active_voices.size(),
			})
	return _error("Unsupported voice policy.")


func finish_voice(identity: Dictionary = {}) -> Dictionary:
	if _active_voices.is_empty():
		return _transition("retain_voices_stopped")
	var finished_index := 0
	if not identity.is_empty():
		var checked := _validated_identity(identity)
		if not checked.ok:
			return checked
		finished_index = _find_identity(_active_voices, checked.identity)
		if finished_index < 0:
			return _error("Finished voice is not active.")
	var finished: Dictionary = _active_voices[finished_index]
	_active_voices.remove_at(finished_index)
	var promoted: Dictionary = {}
	if _voice_policy == "queue" and _active_voices.is_empty() and not _voice_queue.is_empty():
		promoted = _voice_queue.pop_front()
		_active_voices.append(promoted.duplicate(true))
	_revision += 1
	return _transition("finish_and_start_voice" if not promoted.is_empty() else "finish_voice", {
		"finished": finished.duplicate(true),
		"resource": promoted.duplicate(true),
	})


func clear_voices() -> Dictionary:
	if _active_voices.is_empty() and _voice_queue.is_empty():
		return _transition("retain_voices_stopped")
	var active := _active_voices.duplicate(true)
	var queued := _voice_queue.duplicate(true)
	_active_voices.clear()
	_voice_queue.clear()
	_revision += 1
	return _transition("clear_voices", {"active": active, "queued": queued})


func _validated_identity(value: Dictionary) -> Dictionary:
	for key in ["archive", "entry", "source", "sha256"]:
		if not value.has(key) or str(value.get(key, "")).is_empty():
			return _error("Audio identity is incomplete: %s" % key)
	var archive := str(value.archive).to_lower()
	var entry := str(value.entry)
	var source := str(value.source)
	var sha := str(value.sha256)
	if archive.get_extension().to_lower() != "arc" or archive.contains("/") or archive.contains("\\"):
		return _error("Audio archive identity is invalid.")
	if entry.contains("/") or entry.contains("\\") or entry == "." or entry == "..":
		return _error("Audio entry identity is invalid.")
	if source not in ["original_arc", "overlay", "materialized_arc", "fallback"]:
		return _error("Audio source identity is unsupported.")
	if not ContractValues.is_sha256(sha):
		return _error("Audio identity SHA-256 is invalid.")
	return {"ok": true, "identity": {
		"archive": archive,
		"entry": entry,
		"source": source,
		"sha256": sha,
	}}


func _same_identity(left: Dictionary, right: Dictionary) -> bool:
	return (
		left.size() == 4
		and right.size() == 4
		and str(left.get("archive", "")) == str(right.get("archive", ""))
		and str(left.get("entry", "")).to_upper() == str(right.get("entry", "")).to_upper()
		and str(left.get("source", "")) == str(right.get("source", ""))
		and str(left.get("sha256", "")) == str(right.get("sha256", ""))
	)


func _find_identity(values: Array[Dictionary], identity: Dictionary) -> int:
	for index in values.size():
		if _same_identity(values[index], identity):
			return index
	return -1


func _transition(action: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.EVENT_AUDIO_STATE_SCHEMA,
		"action": action,
		"state": snapshot(),
	}
	for key in extra:
		result[key] = extra[key]
	return result


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"schema": ContentCoreVersionScript.EVENT_AUDIO_STATE_SCHEMA,
		"error": message,
	}
