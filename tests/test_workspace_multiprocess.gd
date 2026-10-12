extends "res://tests/test_case.gd"

## WD-17: crash recovery and true multi-process publication of a workspace.
##
## Verifies the composed workspace lock chain (workspace lock + project lock +
## manifest lock + manifest revision + content-addressed payloads) from
## several real OS processes, including recovery after a really killed
## publisher and respect for a still-live one. Production code is not
## expected to change; a real defect here should stop the unit and be
## reported, not patched around.

const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://workspace_multiprocess_test"
const WORKER_SCRIPT := "res://tests/helpers/workspace_publication_worker.gd"
const PHASE_TIMEOUT_SECONDS := 60.0
const POLL_INTERVAL_SECONDS := 0.05

const MMO_ENTRIES := [
	"ENT1.MMO", "ENT2.MMO", "ENT3.MMO", "ENT4.MMO",
	"ENT5.MMO", "ENT6.MMO", "ENT7.MMO", "ENT8.MMO",
]


func _ready() -> void:
	_cleanup()
	var root_absolute := ProjectSettings.globalize_path(TEST_ROOT)
	var source_root := root_absolute.path_join("ELFIMAGE")
	var project_root := root_absolute.path_join("my_mod")
	DirAccess.make_dir_recursive_absolute(source_root)
	SyntheticArc.write_arc(source_root.path_join("mes.arc"), [
		{"name": "TEST.MES", "data": PackedByteArray([1, 2, 3])},
	])
	var mmo_entries: Array = []
	for index in range(MMO_ENTRIES.size()):
		mmo_entries.append({"name": MMO_ENTRIES[index], "data": _seeded_bytes(index + 1)})
	SyntheticArc.write_arc(source_root.path_join("mmo.arc"), mmo_entries)
	var source_mes_sha := FileAccess.get_sha256(source_root.path_join("mes.arc"))
	var source_mmo_sha := FileAccess.get_sha256(source_root.path_join("mmo.arc"))

	var project_document := _project_document(source_mes_sha, source_mmo_sha)
	var setup_workspace := ContentWorkspaceScript.new()
	var created := setup_workspace.create(project_root, source_root, project_document)
	_check(created.get("ok", false), "multiprocess fixture creates a named workspace project and empty overlay")
	setup_workspace.close()

	# A workspace object opened in the test process before phase 1, kept open
	# through phases 1 and 2, then used to stage a sixth entry in phase 3.
	var early_workspace := ContentWorkspaceScript.new()
	var early_opened := early_workspace.open(project_root, source_root)
	_check(early_opened.get("ok", false), "phase 3 fixture opens a workspace object before phase 1 and keeps it open")

	# --- Phase 1: four concurrent publishers, four entries. ---
	var phase1_entries := [MMO_ENTRIES[0], MMO_ENTRIES[1], MMO_ENTRIES[2], MMO_ENTRIES[3]]
	var phase1_payloads: Array[PackedByteArray] = [
		_payload_bytes(1), _payload_bytes(2), _payload_bytes(3), _payload_bytes(4),
	]
	var phase1_pids: Array[int] = []
	var phase1_result_paths: Array[String] = []
	for index in range(phase1_entries.size()):
		var result_path := root_absolute.path_join("phase1_result_%d.json" % index)
		phase1_result_paths.append(result_path)
		var pid := _spawn_stage_worker(
			project_root, source_root, "mmo.arc", phase1_entries[index],
			phase1_payloads[index], result_path
		)
		_check(pid > 0, "phase 1 publisher %d starts" % index)
		phase1_pids.append(pid)
	var phase1_finished := await _await_all_processes(phase1_pids, PHASE_TIMEOUT_SECONDS)
	_check(phase1_finished, "phase 1 publishers all exit within the phase timeout")

	var phase1_total_attempts := 0
	var phase1_all_ok := phase1_finished
	for index in range(phase1_pids.size()):
		var exit_code := OS.get_process_exit_code(phase1_pids[index])
		var result := _read_result(phase1_result_paths[index])
		phase1_total_attempts += int(result.get("attempts", 0))
		phase1_all_ok = phase1_all_ok and exit_code == 0 and result.get("ok", false)
		if exit_code != 0 or not result.get("ok", false):
			print("phase 1 publisher %d: exit %d attempts %d error '%s'" % [
				index, exit_code, int(result.get("attempts", 0)), str(result.get("error", "")),
			])
	_check(
		phase1_all_ok,
		"phase 1: four concurrent publishers on distinct entries all exit 0 with ok:true (sum of attempts = %d)" % phase1_total_attempts
	)

	var phase1_reopen_workspace := ContentWorkspaceScript.new()
	var phase1_reopen := phase1_reopen_workspace.open(project_root, source_root)
	_check(
		phase1_reopen.get("ok", false) and int(phase1_reopen.snapshot.replacement_count) == 4,
		"phase 1: reopening the workspace succeeds and the manifest holds exactly four replacements"
	)
	phase1_reopen_workspace.close()

	var phase1_manifest := OverlayPackageScript.new().load_manifest(project_root)
	_check(phase1_manifest.get("ok", false), "phase 1 manifest reloads after the four publishers finish")
	var phase1_records_ok := true
	for index in range(phase1_entries.size()):
		if not _verify_replacement(phase1_manifest.manifest, project_root, phase1_entries[index], phase1_payloads[index]):
			phase1_records_ok = false
	_check(phase1_records_ok, "phase 1: each entry's manifest record and payload file match that worker's payload hash")
	_check(
		_scan_for_lock_artifacts(project_root).is_empty(),
		"phase 1: no lock, stale, or temporary artifact remains anywhere under the workspace"
	)
	_check(
		FileAccess.get_sha256(source_root.path_join("mmo.arc")) == source_mmo_sha,
		"phase 1: the source ARC hash is unchanged"
	)

	# --- Phase 2: two publishers, one entry. ---
	var phase2_entry := MMO_ENTRIES[4]
	var phase2_payload_a := _payload_bytes(5)
	var phase2_payload_b := _payload_bytes(6)
	var phase2_result_path_a := root_absolute.path_join("phase2_result_a.json")
	var phase2_result_path_b := root_absolute.path_join("phase2_result_b.json")
	var phase2_pid_a := _spawn_stage_worker(project_root, source_root, "mmo.arc", phase2_entry, phase2_payload_a, phase2_result_path_a)
	var phase2_pid_b := _spawn_stage_worker(project_root, source_root, "mmo.arc", phase2_entry, phase2_payload_b, phase2_result_path_b)
	_check(phase2_pid_a > 0 and phase2_pid_b > 0, "phase 2 publishers start for the same entry")
	var phase2_finished := await _await_all_processes([phase2_pid_a, phase2_pid_b], PHASE_TIMEOUT_SECONDS)
	_check(phase2_finished, "phase 2 publishers both exit within the phase timeout")
	var phase2_result_a := _read_result(phase2_result_path_a)
	var phase2_result_b := _read_result(phase2_result_path_b)
	var phase2_exit_a := OS.get_process_exit_code(phase2_pid_a)
	var phase2_exit_b := OS.get_process_exit_code(phase2_pid_b)
	_check(
		phase2_exit_a == 0 and phase2_exit_b == 0 and phase2_result_a.get("ok", false) and phase2_result_b.get("ok", false),
		"phase 2: two publishers competing for the same entry both exit 0 with ok:true (a: exit %d attempts %d error '%s'; b: exit %d attempts %d error '%s')" % [
			phase2_exit_a, int(phase2_result_a.get("attempts", 0)), str(phase2_result_a.get("error", "")),
			phase2_exit_b, int(phase2_result_b.get("attempts", 0)), str(phase2_result_b.get("error", "")),
		]
	)

	var phase2_manifest := OverlayPackageScript.new().load_manifest(project_root)
	_check(phase2_manifest.get("ok", false), "phase 2 manifest reloads after the competing publishers finish")
	var phase2_record := OverlayPackageScript.new().find_replacement(phase2_manifest.manifest, "mmo.arc", phase2_entry)
	var phase2_sha_a := OverlayPackageScript.sha256_bytes(phase2_payload_a)
	var phase2_sha_b := OverlayPackageScript.sha256_bytes(phase2_payload_b)
	_check(
		not phase2_record.is_empty() and str(phase2_record.get("replacement_sha256", "")) in [phase2_sha_a, phase2_sha_b],
		"phase 2: the manifest holds exactly one replacement for the contested entry, matching one of the two payload hashes"
	)
	_check(
		int(phase2_manifest.manifest.replacements.size()) == 5,
		"phase 2: the manifest holds five replacements in total"
	)
	var phase2_all_untouched := true
	for index in range(phase1_entries.size()):
		if not _verify_replacement(phase2_manifest.manifest, project_root, phase1_entries[index], phase1_payloads[index]):
			phase2_all_untouched = false
	_check(phase2_all_untouched, "phase 2: the four phase 1 records are untouched")

	# --- Phase 3: a stale in-process workspace cannot lose others' work. ---
	var phase3_entry := MMO_ENTRIES[5]
	var phase3_payload := _payload_bytes(7)
	var phase3_stage := early_workspace.stage_replacements("mmo.arc", {phase3_entry: phase3_payload}, "remake_only", "not_applicable")
	_check(
		true,
		"phase 3: stale in-process workspace stage returned ok=%s error=%s" % [str(phase3_stage.get("ok", false)), str(phase3_stage.get("error", ""))]
	)

	var phase3_manifest := OverlayPackageScript.new().load_manifest(project_root)
	_check(phase3_manifest.get("ok", false), "phase 3 manifest reloads after the stale workspace attempt")
	if phase3_stage.get("ok", false):
		_check(
			int(phase3_manifest.manifest.replacements.size()) == 6,
			"phase 3: the manifest holds all six records after the stale workspace succeeds"
		)
		_check(
			_verify_replacement(phase3_manifest.manifest, project_root, phase3_entry, phase3_payload),
			"phase 3: the sixth record matches the stale workspace's payload"
		)
	else:
		var phase3_error := str(phase3_stage.get("error", ""))
		_check(phase3_error.contains("changed"), "phase 3: the refusal names a changed workspace or manifest")
	var phase3_earlier_ok := true
	for index in range(phase1_entries.size()):
		if not _verify_replacement(phase3_manifest.manifest, project_root, phase1_entries[index], phase1_payloads[index]):
			phase3_earlier_ok = false
	var phase2_winning_payload := phase2_payload_a if str(phase2_record.get("replacement_sha256", "")) == phase2_sha_a else phase2_payload_b
	if not _verify_replacement(phase3_manifest.manifest, project_root, phase2_entry, phase2_winning_payload):
		phase3_earlier_ok = false
	_check(phase3_earlier_ok, "phase 3: the five earlier records remain present regardless of the stale workspace's outcome")
	_check(
		int(phase3_manifest.manifest.replacements.size()) >= 5,
		"phase 3: the manifest never drops below the five earlier records"
	)

	# --- Phase 4: a really killed publisher. ---
	var phase4_ready_path := root_absolute.path_join("phase4_holder.ready")
	var phase4_hold_pid := _spawn_hold_worker(project_root, source_root, "mmo.arc", phase4_ready_path)
	_check(phase4_hold_pid > 0, "phase 4 holder process starts")
	var phase4_ready := await _await_file(phase4_ready_path, PHASE_TIMEOUT_SECONDS)
	_check(phase4_ready and OS.is_process_running(phase4_hold_pid), "phase 4 holder signals ready while still running")

	var phase4_workspace_lock_path := project_root.path_join(".workspace.lock")
	var phase4_manifest_lock_path := project_root.path_join(".manifest.lock")
	var phase4_manifest_temp_path := project_root.path_join("manifest.json.tmp-%d-1" % phase4_hold_pid)
	var phase4_payload_temp_path := project_root.path_join("replacements/mmo.arc/orphan.bin.tmp-%d-2" % phase4_hold_pid)
	_check(
		_lock_owner_pid(phase4_workspace_lock_path) == phase4_hold_pid and _lock_owner_pid(phase4_manifest_lock_path) == phase4_hold_pid,
		"phase 4: both lock directories carry an owner record naming the worker's pid"
	)
	_check(
		FileAccess.file_exists(phase4_manifest_temp_path) and FileAccess.file_exists(phase4_payload_temp_path),
		"phase 4: both abandoned temporaries exist on disk before the kill"
	)

	OS.kill(phase4_hold_pid)
	var phase4_dead := await _await_process_exit(phase4_hold_pid, PHASE_TIMEOUT_SECONDS)
	_check(phase4_dead, "phase 4: the killed publisher process is no longer running")

	var phase4_baseline_records: Array = phase3_manifest.manifest.replacements.duplicate(true)
	var phase4_new_entry := MMO_ENTRIES[6]
	var phase4_new_payload := _payload_bytes(8)
	var phase4_stage_result_path := root_absolute.path_join("phase4_stage_result.json")
	var phase4_stage_pid := _spawn_stage_worker(project_root, source_root, "mmo.arc", phase4_new_entry, phase4_new_payload, phase4_stage_result_path)
	_check(phase4_stage_pid > 0, "phase 4 recovery publisher starts after the kill")
	var phase4_stage_finished := await _await_process_exit(phase4_stage_pid, PHASE_TIMEOUT_SECONDS)
	_check(phase4_stage_finished, "phase 4 recovery publisher exits within the phase timeout")
	var phase4_stage_exit := OS.get_process_exit_code(phase4_stage_pid)
	var phase4_stage_result := _read_result(phase4_stage_result_path)
	_check(
		phase4_stage_exit == 0 and phase4_stage_result.get("ok", false),
		"phase 4: the recovery publisher succeeds after the crash-recovered locks"
	)

	_check(
		_scan_for_lock_artifacts(project_root).is_empty(),
		"phase 4: no lock, stale, or temporary artifact remains after recovery"
	)
	var phase4_manifest := OverlayPackageScript.new().load_manifest(project_root)
	_check(phase4_manifest.get("ok", false), "phase 4 manifest reloads after recovery")
	_check(
		int(phase4_manifest.manifest.replacements.size()) == phase4_baseline_records.size() + 1,
		"phase 4: exactly one record was added on top of the pre-existing baseline"
	)
	var phase4_baseline_ok := true
	for value in phase4_baseline_records:
		var baseline_record: Dictionary = value
		var current := OverlayPackageScript.new().find_replacement(phase4_manifest.manifest, "mmo.arc", str(baseline_record.target_entry))
		if current.is_empty() or str(current.replacement_sha256) != str(baseline_record.replacement_sha256):
			phase4_baseline_ok = false
	_check(phase4_baseline_ok, "phase 4: every pre-existing record from phases 1-3 is unchanged")
	_check(
		_verify_replacement(phase4_manifest.manifest, project_root, phase4_new_entry, phase4_new_payload),
		"phase 4: the new record was added after recovery"
	)

	# --- Phase 5: a live holder is respected. ---
	var phase5_ready_path := root_absolute.path_join("phase5_holder.ready")
	# The fresh workspace object opens before the holder claims the lock, so
	# the in-process stage attempt below is the operation actually contended
	# against the live holder (open() itself briefly takes and releases the
	# workspace lock too, so opening it after the holder is ready would just
	# make open() itself the contended call instead).
	var phase5_fresh_workspace := ContentWorkspaceScript.new()
	var phase5_fresh_opened := phase5_fresh_workspace.open(project_root, source_root)
	_check(phase5_fresh_opened.get("ok", false), "phase 5 fresh workspace object opens before the holder claims the lock")

	var phase5_hold_pid := _spawn_hold_worker(project_root, source_root, "mmo.arc", phase5_ready_path)
	_check(phase5_hold_pid > 0, "phase 5 holder process starts")
	var phase5_ready := await _await_file(phase5_ready_path, PHASE_TIMEOUT_SECONDS)
	_check(phase5_ready and OS.is_process_running(phase5_hold_pid), "phase 5 holder signals ready while still running")

	var phase5_manifest_bytes_before := FileAccess.get_file_as_bytes(project_root.path_join("manifest.json"))
	var phase5_entry := MMO_ENTRIES[7]
	var phase5_payload := _payload_bytes(9)
	var phase5_stage := phase5_fresh_workspace.stage_replacements("mmo.arc", {phase5_entry: phase5_payload}, "remake_only", "not_applicable")
	_check(
		not phase5_stage.get("ok", false) and str(phase5_stage.get("error", "")).contains(str(phase5_hold_pid)),
		"phase 5: an in-process stage from a fresh workspace fails with an error naming the live holder's pid"
	)
	var phase5_manifest_bytes_after := FileAccess.get_file_as_bytes(project_root.path_join("manifest.json"))
	_check(
		phase5_manifest_bytes_before == phase5_manifest_bytes_after,
		"phase 5: the manifest bytes are identical before and after the rejected attempt"
	)
	phase5_fresh_workspace.close()

	OS.kill(phase5_hold_pid)
	var phase5_dead := await _await_process_exit(phase5_hold_pid, PHASE_TIMEOUT_SECONDS)
	_check(phase5_dead, "phase 5: the live holder is killed and stops running")
	_remove_tree(project_root.path_join(".workspace.lock"))
	_remove_tree(project_root.path_join(".manifest.lock"))
	_remove_if_present(project_root.path_join("manifest.json.tmp-%d-1" % phase5_hold_pid))
	_remove_if_present(project_root.path_join("replacements/mmo.arc/orphan.bin.tmp-%d-2" % phase5_hold_pid))

	# --- Phase 6: a sibling process respects a live holder it did not start. ---
	# The engine's own liveness call answers only for children of the caller.
	# Both processes here are children of this test and strangers to each
	# other, which is how two tools meet in practice: the publisher must wait
	# for the live holder instead of stealing its locks, and recover them once
	# the holder is really gone.
	var phase6_ready_path := root_absolute.path_join("phase6_holder.ready")
	var phase6_result_path := root_absolute.path_join("phase6_result.json")
	var phase6_hold_pid := _spawn_hold_worker(project_root, source_root, "mmo.arc", phase6_ready_path)
	var phase6_ready := await _await_file(phase6_ready_path, PHASE_TIMEOUT_SECONDS)
	_check(phase6_hold_pid > 0 and phase6_ready, "phase 6 holder process owns both locks")
	var phase6_manifest_before := FileAccess.get_file_as_bytes(project_root.path_join("manifest.json"))
	var phase6_entry := MMO_ENTRIES[7]
	var phase6_payload := _payload_bytes(10)
	var phase6_stage_pid := _spawn_stage_worker(project_root, source_root, "mmo.arc", phase6_entry, phase6_payload, phase6_result_path)
	_check(phase6_stage_pid > 0, "phase 6 sibling publisher starts while the holder lives")
	await get_tree().create_timer(2.0).timeout
	_check(
		OS.is_process_running(phase6_stage_pid)
		and not FileAccess.file_exists(phase6_result_path)
		and _lock_owner_pid(project_root.path_join(".workspace.lock")) == phase6_hold_pid
		and _lock_owner_pid(project_root.path_join(".manifest.lock")) == phase6_hold_pid
		and FileAccess.get_file_as_bytes(project_root.path_join("manifest.json")) == phase6_manifest_before,
		"phase 6: after two seconds the sibling publisher is still waiting, both locks still name the live holder and the manifest is untouched"
	)
	OS.kill(phase6_hold_pid)
	var phase6_holder_dead := await _await_process_exit(phase6_hold_pid, PHASE_TIMEOUT_SECONDS)
	var phase6_stage_finished := await _await_process_exit(phase6_stage_pid, PHASE_TIMEOUT_SECONDS)
	var phase6_result := _read_result(phase6_result_path)
	_check(
		phase6_holder_dead and phase6_stage_finished and phase6_result.get("ok", false),
		"phase 6: once the holder is killed the waiting publisher recovers the locks and succeeds (attempts = %d)" % int(phase6_result.get("attempts", 0))
	)
	var phase6_manifest := OverlayPackageScript.new().load_manifest(project_root)
	_check(
		phase6_manifest.get("ok", false)
		and _verify_replacement(phase6_manifest.manifest, project_root, phase6_entry, phase6_payload)
		and _scan_for_lock_artifacts(project_root).is_empty(),
		"phase 6: the waiting publisher's record is published and no lock, stale or temporary artifact remains"
	)

	early_workspace.close()
	_check(
		FileAccess.get_sha256(source_root.path_join("mes.arc")) == source_mes_sha
		and FileAccess.get_sha256(source_root.path_join("mmo.arc")) == source_mmo_sha,
		"the multiprocess run leaves every source ARC unchanged"
	)
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _spawn_stage_worker(
	workspace_root: String,
	content_set_root: String,
	archive: String,
	entry: String,
	payload: PackedByteArray,
	result_path: String
) -> int:
	# Godot's Windows process spawning drops empty-string arguments outright
	# (verified with analysis/wd17_probe_spawn.gd), so unused positional
	# arguments use a non-empty placeholder instead of "".
	return _spawn_worker(workspace_root, content_set_root, archive, entry, payload.hex_encode(), "stage", "-", result_path)


func _spawn_hold_worker(
	workspace_root: String,
	content_set_root: String,
	archive: String,
	ready_path: String
) -> int:
	return _spawn_worker(workspace_root, content_set_root, archive, "UNUSED.MMO", "-", "hold", ready_path, "-")


func _spawn_worker(
	workspace_root: String,
	content_set_root: String,
	archive: String,
	entry: String,
	payload_hex: String,
	mode: String,
	ready_path: String,
	result_path: String
) -> int:
	var arguments := PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		WORKER_SCRIPT,
		"--",
		workspace_root,
		content_set_root,
		archive,
		entry,
		payload_hex,
		mode,
		ready_path,
		result_path,
	])
	return OS.create_process(OS.get_executable_path(), arguments)


func _await_process_exit(pid: int, timeout_seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if float(Time.get_ticks_msec() - start) / 1000.0 >= timeout_seconds:
			return false
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
	return true


func _await_all_processes(pids: Array[int], timeout_seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while true:
		var any_running := false
		for pid in pids:
			if OS.is_process_running(pid):
				any_running = true
				break
		if not any_running:
			return true
		if float(Time.get_ticks_msec() - start) / 1000.0 >= timeout_seconds:
			return false
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
	return false


func _await_file(path: String, timeout_seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while not FileAccess.file_exists(path):
		if float(Time.get_ticks_msec() - start) / 1000.0 >= timeout_seconds:
			return false
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
	return true


func _read_result(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


func _lock_owner_pid(lock_dir_path: String) -> int:
	var owner_path := lock_dir_path.path_join("owner.json")
	if not FileAccess.file_exists(owner_path):
		return -1
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(owner_path))
	if not parsed is Dictionary:
		return -1
	return int(parsed.get("pid", -1))


func _verify_replacement(manifest: Dictionary, project_root_absolute: String, entry_name: String, payload: PackedByteArray) -> bool:
	var record := OverlayPackageScript.new().find_replacement(manifest, "mmo.arc", entry_name)
	if record.is_empty():
		return false
	var expected_sha := OverlayPackageScript.sha256_bytes(payload)
	if str(record.replacement_sha256) != expected_sha:
		return false
	var payload_path := project_root_absolute.path_join(str(record.replacement_path))
	return FileAccess.file_exists(payload_path) and FileAccess.get_sha256(payload_path) == expected_sha


func _scan_for_lock_artifacts(root_path: String) -> Array[String]:
	var found: Array[String] = []
	_scan_for_lock_artifacts_into(root_path, found)
	return found


func _scan_for_lock_artifacts_into(path: String, found: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir():
			if name in [".workspace.lock", ".project.lock", ".manifest.lock"] or name.contains(".stale-") or name.contains(".released-"):
				found.append(child)
			else:
				_scan_for_lock_artifacts_into(child, found)
		elif name.contains(".tmp-"):
			found.append(child)
		name = directory.get_next()
	directory.list_dir_end()


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _payload_bytes(tag: int) -> PackedByteArray:
	return PackedByteArray([100 + tag, 101 + tag, 102 + tag, 103 + tag, 104 + tag])


func _seeded_bytes(seed: int) -> PackedByteArray:
	return PackedByteArray([seed, seed + 1, seed + 2, seed + 3])


func _project_document(mes_sha: String, mmo_sha: String) -> Dictionary:
	var archives: Array = [
		{"archive": "mes.arc", "sha256": mes_sha, "required": true},
		{"archive": "mmo.arc", "sha256": mmo_sha, "required": true},
	]
	return {
		"schema": "kakyu_content_project/v1",
		"project_id": "workspace.multiprocess.test",
		"project_version": "0.1.0",
		"display_name": "Workspace Multiprocess Test",
		"project_revision": 1,
		"content_core": {"minimum_version": "0.147.0", "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mmo.arc"],
		"compatibility_objective": "mixed",
		"dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []},
		"overlay_manifest": "manifest.json",
	}


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	_remove_tree(absolute)
