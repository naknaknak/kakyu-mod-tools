extends Node

const EventAudioStateScript := preload("res://content_core/event_audio_state.gd")

var _failed := false


func _ready() -> void:
	var audio := EventAudioStateScript.new()
	var bgm_a := _identity("bgm.arc", "MAKI.WAV", "original_arc", "a")
	var bgm_b := _identity("bgm.arc", "MAHOKO.WAV", "overlay", "b")
	var voice_a := _identity("voice.arc", "B0796.OGG", "original_arc", "c")
	var voice_b := _identity("tina1.arc", "B0797.OGG", "materialized_arc", "d")
	var voice_c := _identity("tina2.arc", "B0798.OGG", "fallback", "e")

	var first_bgm := audio.request_bgm(bgm_a)
	var retained_bgm := audio.request_bgm(bgm_a.duplicate(true))
	var replaced_bgm := audio.request_bgm(bgm_b)
	_check(first_bgm.ok and first_bgm.action == "start_bgm", "audio state starts the first source-bound BGM")
	_check(retained_bgm.ok and retained_bgm.action == "retain_bgm" and retained_bgm.state.revision == first_bgm.state.revision, "an identical BGM request retains playback without a state revision")
	_check(replaced_bgm.ok and replaced_bgm.action == "replace_bgm" and replaced_bgm.previous.entry == "MAKI.WAV", "a different effective BGM identity replaces the active track")

	_check(audio.push_caller_bgm("caller").ok, "audio state captures the caller BGM before a nested route")
	audio.request_bgm(bgm_a)
	var restored := audio.restore_caller_bgm()
	_check(restored.ok and restored.action == "restore_bgm" and restored.resource.entry == "MAHOKO.WAV" and restored.depth == 0, "caller return restores the exact captured effective BGM identity")
	var stopped := audio.stop_bgm()
	_check(stopped.ok and stopped.action == "stop_bgm" and audio.snapshot().bgm.is_empty(), "BGM stop clears the active resource")
	_check(audio.stop_bgm().action == "retain_bgm_stopped", "repeated BGM stop is idempotent")
	_check(not audio.restore_caller_bgm().ok, "caller restore fails closed when no captured frame exists")

	var first_voice := audio.submit_voice(voice_a)
	var retained_voice := audio.submit_voice(voice_a.duplicate(true))
	var replaced_voice := audio.submit_voice(voice_b)
	_check(first_voice.action == "start_voice" and retained_voice.action == "retain_voice" and replaced_voice.action == "replace_voice", "the default voice policy retains an identical marker and replaces a changed one-player identity")
	_check(replaced_voice.replaced.size() == 1 and replaced_voice.replaced[0].entry == "B0796.OGG", "voice replacement reports the displaced active resource")

	audio.clear_voices()
	audio.set_voice_policy("queue")
	_check(audio.submit_voice(voice_a).action == "start_voice", "queue policy starts immediately while idle")
	_check(audio.submit_voice(voice_b).action == "queue_voice" and audio.submit_voice(voice_c).queue_position == 1, "queue policy retains source order behind the active voice")
	var promoted := audio.finish_voice(voice_a)
	_check(promoted.action == "finish_and_start_voice" and promoted.resource.entry == "B0797.OGG", "voice completion promotes the next queued identity deterministically")
	var queued_snapshot := audio.snapshot()
	queued_snapshot.active_voices[0].entry = "MUTATED.OGG"
	_check(audio.snapshot().active_voices[0].entry == "B0797.OGG", "audio snapshots are detached from caller mutation")

	audio.clear_voices()
	audio.set_voice_policy("overlap")
	audio.submit_voice(voice_a)
	var overlapped := audio.submit_voice(voice_b)
	_check(overlapped.action == "overlap_voice" and overlapped.active_count == 2, "overlap policy tracks simultaneous effective voice identities")
	_check(audio.finish_voice(voice_a).action == "finish_voice" and audio.snapshot().active_voices[0].entry == "B0797.OGG", "overlap completion removes only the addressed active voice")

	var reset := audio.reset()
	_check(reset.action == "reset" and reset.state.bgm.is_empty() and reset.state.active_voices.is_empty() and reset.state.voice_policy == "replace", "reset returns the versioned audio state to the deterministic default")
	_check(not audio.request_bgm({}).ok and not audio.submit_voice(_identity("not-arc", "BAD.OGG", "original_arc", "f")).ok, "invalid or incomplete audio identities fail closed")
	_check(not audio.set_voice_policy("mix").ok, "unknown voice overlap policies fail closed")

	if _failed:
		get_tree().quit(1)
	else:
		print("Event audio state tests passed")
		get_tree().quit(0)


func _identity(archive: String, entry: String, source: String, hex_digit: String) -> Dictionary:
	return {
		"archive": archive,
		"entry": entry,
		"source": source,
		"sha256": hex_digit.repeat(64),
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failed = true
		push_error("FAIL: %s" % message)
