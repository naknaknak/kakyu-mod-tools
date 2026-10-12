extends SceneTree

# TD-32 part 2 (2026-09-21): runs every named analysis-group profile in one
# Godot process, with `mes.arc` opened once, instead of one Godot process per
# profile. `run_headless_validation.py`'s `collapse_families()` builds the
# command this script receives from every selected `analysis_group` member
# check; each member still becomes its own row in the v4 report (parsed from
# the `GROUPS_SUMMARY` line this script prints at the end). What each group
# verifies does not change - this is `KakyuEventAnalysisGroupValidation.validate()`
# called once per profile, with the reader shared - and the single-profile
# CLI (`validate_event_analysis_group.gd`) is still the byte-identical
# reference for what one profile's canonical report looks like. See
# analysis/_docs/td32_part2_groups_spec.md.
#
# TD-32 part 2b (2026-09-21): the per-group cost was the Python audit
# subprocess, not Godot - `mes_analyzer_handoff.build_handoff` rebuilt for
# every profile even when profiles share source members. This runs the audit
# once for every planned profile in a single Python process ahead of the
# loop (a per-entry handoff cache), and passes each profile's own report into
# `validate()` instead of letting it spawn its own subprocess. See
# analysis/_docs/td32_part2b_audit_cache_spec.md.
#
# TD-32 part 2c (2026-09-21): the pre-commit review found `_audit_all()`
# silently dropped the raw Python audit output on a non-zero exit or a
# malformed line, leaving only a generic per-profile placeholder error; it
# now surfaces the raw output once (bounded) and names the failing profile's
# own reason inside its group block. The `--profiles-file` fallback now
# writes under the project's own `analysis/` directory and is exercised by a
# hidden `--profiles-arg-limit` argument. The archive-changed check moved to
# hashing the file once after the last profile against the shared reader's
# fingerprint (opened once, per profile the module already checks against
# it) instead of every profile hashing the file itself. See
# analysis/_docs/td32_part2c_review_spec.md.

const Module := preload("res://tools/content_suite/event_analysis_group_validation.gd")
const FlowModule := preload("res://tools/content_suite/event_analysis_group_flow_validation.gd")
# Windows' command-line limit is about 32,000 characters; 149 profile paths at
# about 55 characters each is about 8 KB, well inside it. This guard exists
# for a much larger profile set than the repository currently has; the
# hidden `--profiles-arg-limit` argument overrides it so the `--profiles-file`
# fallback path can be exercised without an unreasonably large profile set.
const PROFILES_ARGV_LENGTH_LIMIT := 30000
# The raw audit subprocess output, when surfaced, is bounded the same way a
# failing check's own output tail is elsewhere in this batch.
const AUDIT_OUTPUT_LIMIT := 4000


# Runs the Python audit for every named profile in one subprocess, sharing its
# handoff/archive caches (TD-32 part 2b). Returns
# `{"by_profile": {<profile>: <report>}, "audit_output": <string>}`: every
# profile is guaranteed a `by_profile` entry (a placeholder failure when the
# subprocess did not account for it); `audit_output` is the raw subprocess
# output, bounded to `AUDIT_OUTPUT_LIMIT` characters, only when the process
# exited non-zero or a printed line was not JSON or lacked a `report` key -
# otherwise empty.
func _audit_all(elfimage_path: String, profiles: Array, argv_limit: int = PROFILES_ARGV_LENGTH_LIMIT) -> Dictionary:
	var joined_length := 0
	for profile in profiles:
		joined_length += String(profile).length() + 1
	var cli_args: Array = ["tools/audit_event_analysis_group.py", elfimage_path]
	var list_path := ""
	if joined_length > argv_limit:
		var analysis_dir := ProjectSettings.globalize_path("res://analysis")
		if not DirAccess.dir_exists_absolute(analysis_dir):
			DirAccess.make_dir_recursive_absolute(analysis_dir)
		list_path = analysis_dir.path_join("event_analysis_groups_profiles_%d.txt" % Time.get_ticks_usec())
		var file := FileAccess.open(list_path, FileAccess.WRITE)
		if file == null:
			var reason := "could not create the --profiles-file fallback list: %s" % list_path
			var failed := {}
			for profile in profiles:
				failed[profile] = {"ok": false, "error": reason}
			return {"by_profile": failed, "audit_output": reason}
		for profile in profiles:
			file.store_line(String(profile))
		file.close()
		cli_args.append("--profiles-file")
		cli_args.append(list_path)
	else:
		cli_args.append("--profiles")
		for profile in profiles:
			cli_args.append(profile)

	var output: Array = []
	var exit_code := OS.execute("py", cli_args, output, true)
	if list_path != "":
		DirAccess.remove_absolute(list_path)

	var raw_output := "".join(output)
	var by_profile := {}
	var malformed := false
	for line in raw_output.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(trimmed)
		if not (parsed is Dictionary) or not parsed.has("profile") or not parsed.has("report") or not (parsed.get("report") is Dictionary):
			malformed = true
			continue
		by_profile[parsed.get("profile")] = parsed.get("report")

	var audit_output := ""
	if exit_code != 0 or malformed:
		audit_output = raw_output
		if audit_output.length() > AUDIT_OUTPUT_LIMIT:
			audit_output = audit_output.substr(audit_output.length() - AUDIT_OUTPUT_LIMIT)

	for profile in profiles:
		if not by_profile.has(profile):
			by_profile[profile] = {"ok": false, "error": "audit result missing or unparsable for this profile"}
	return {"by_profile": by_profile, "audit_output": audit_output}


# A profile's own `schema` field, read without loading it through the Python
# audit - just enough to route its own row to the right validator.
func _profile_schema(profile_path: String) -> String:
	var file := FileAccess.open(profile_path, FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return str((parsed as Dictionary).get("schema", "")) if parsed is Dictionary else ""


func _init() -> void:
	var raw_args := OS.get_cmdline_user_args()
	var argv_limit := PROFILES_ARGV_LENGTH_LIMIT
	var args: Array = []
	var index := 0
	while index < raw_args.size():
		if raw_args[index] == "--profiles-arg-limit" and index + 1 < raw_args.size():
			argv_limit = int(raw_args[index + 1])
			index += 2
			continue
		args.append(raw_args[index])
		index += 1
	if args.size() < 2:
		quit(2)
		return
	var elfimage_path: String = args[0]
	var profiles: Array = []
	for i in range(1, args.size()):
		profiles.append(args[i])

	var audit_result := _audit_all(elfimage_path, profiles, argv_limit)
	var audited_by_profile: Dictionary = audit_result.by_profile
	var audit_output: String = audit_result.audit_output
	if not audit_output.is_empty():
		print("AUDIT_OUTPUT")
		print(audit_output)

	var reader: KakyuArcReader = preload("res://content_core/arc_reader.gd").new()
	var reader_open := reader.open(elfimage_path.path_join("mes.arc"))

	var groups: Array = []
	var passed_count := 0
	var failed_count := 0
	for profile in profiles:
		print("=== GROUP %s ===" % profile)
		var profile_audit: Dictionary = audited_by_profile.get(profile, {"ok": false, "error": "missing audit result"})
		if profile_audit.get("ok", true) == false and profile_audit.has("error"):
			print("AUDIT_ERROR %s: %s" % [profile, profile_audit.get("error")])
		var started := Time.get_ticks_usec()
		var group_result: Dictionary
		if _profile_schema(profile) == FlowModule.PROFILE_SCHEMA:
			# EP-12 part 2 (2026-09-24): a v14 flow profile has no per-route
			# caller/callee pair for the shared module's checks; it runs
			# through its own sibling validator, wrapped into this row's own
			# shape (it does not share the shared module's `identity`/`report`
			# fields, which stay empty here as they do when the archive could
			# not be opened at all).
			var flow_result: Dictionary = FlowModule.new().validate(elfimage_path, profile)
			group_result = {
				"ok": flow_result.get("ok", false), "checks": flow_result.get("checks", 0),
				"failures": flow_result.get("failures", []),
				"runtime_schema": flow_result.get("runtime_schema", FlowModule.RUNTIME_SCHEMA),
				"identity": {}, "routes": [], "report": {}, "report_json": "",
				"duration_seconds": flow_result.get("duration_seconds", (Time.get_ticks_usec() - started) / 1000000.0),
			}
		elif reader_open:
			var module := Module.new()
			group_result = module.validate(elfimage_path, profile, reader, "", profile_audit)
		else:
			group_result = {
				"ok": false, "checks": 0,
				"failures": ["original archive identity: mes.arc could not be opened"],
				"runtime_schema": "kakyu_event_analysis_group_runtime/v1",
				"identity": {}, "routes": [],
				"report": {}, "report_json": "",
				"duration_seconds": (Time.get_ticks_usec() - started) / 1000000.0,
			}
		if not group_result.report_json.is_empty():
			print(group_result.report_json)
		var status := "passed" if group_result.ok else "failed"
		if group_result.ok:
			passed_count += 1
		else:
			failed_count += 1
		print("--- GROUP %s (%.3fs) ---" % [status.to_upper(), group_result.duration_seconds])
		groups.append({
			"profile": profile,
			"status": status,
			"duration_seconds": group_result.duration_seconds,
			"checks": group_result.checks,
			"failures": group_result.failures,
		})

	# TD-32 part 2c: the file is hashed once, here, after the last profile,
	# and compared with the shared reader's `get_archive_fingerprint()`. That
	# method hashes the whole file again on every call - the reader does not
	# record a digest at open time - so both hashes are taken here, back to
	# back, and this check can notice a change only inside that window.
	# TD-57 left it alone on purpose: it is a change-detection call, so it
	# stays a full hash and never reads the reader's identity memo.
	var archive_changed := false
	if reader_open:
		var final_hash := FileAccess.get_sha256(elfimage_path.path_join("mes.arc"))
		archive_changed = final_hash != reader.get_archive_fingerprint()
		reader.close()
	if archive_changed:
		print("ARCHIVE_CHANGED")
		passed_count = 0
		failed_count = groups.size()
		for group in groups:
			var mutable_group: Dictionary = group
			mutable_group.status = "failed"
			mutable_group.archive_changed = true

	var summary := {
		"schema": "kakyu_event_analysis_groups_run/v1",
		"profiles": profiles.size(),
		"passed": passed_count,
		"failed": failed_count,
		"groups": groups,
	}
	if archive_changed:
		summary["archive_changed"] = true
	print("GROUPS_SUMMARY " + JSON.stringify(summary))
	quit(0 if failed_count == 0 else 1)
