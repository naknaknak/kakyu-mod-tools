extends SceneTree

# Command line front end for the playback package exporter.
#
# The export itself lives in playback_package_export.gd so the playback
# validation can build the same package without shelling out. This script only
# parses arguments, optionally writes the result, and reports the measurement.
#
# A written package carries original dialogue. Without --out nothing is
# written, and this script never prints message text.

const ExportScript := preload("res://tools/content_suite/playback_package_export.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const MediaIdentityScript := preload("res://tools/content_suite/playback_media_identity.gd")
const KnownAbsentMediaScript := preload("res://tools/content_suite/known_absent_media.gd")

# A source root without its media archives leaves hundreds of names undecided;
# the first few say which archives are missing and the count says the rest.
const UNDECIDED_ROWS_LISTED := 20

# A register that disagrees with a package lists its first rows by category and
# counts the rest.
const GATE_ROWS_LISTED := 20


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error(
			"Usage: export_playback_package.gd <ELFIMAGE-directory> [--out <directory>] [--event <id> ...] [--no-analysis-groups] [--include-unbound-groups]"
		)
		quit(2)
		return
	var source_root := str(arguments[0]).replace("\\", "/")
	while source_root.ends_with("/"):
		source_root = source_root.substr(0, source_root.length() - 1)
	var output_root := ""
	var event_ids: Array[String] = []
	var include_analysis_groups := true
	var include_unbound_groups := false
	var index := 1
	while index < arguments.size():
		var flag := str(arguments[index])
		if flag == "--no-analysis-groups":
			include_analysis_groups = false
			index += 1
			continue
		if flag == "--include-unbound-groups":
			# Scratch/bootstrap only (EP-12 PROMIS checkpoint C): every
			# tracked analysis-group's own members, whether or not any
			# catalog row references the group yet. No existing caller
			# passes this; a plain export is unaffected.
			include_unbound_groups = true
			index += 1
			continue
		if index + 1 >= arguments.size():
			push_error("Missing value for %s." % flag)
			quit(2)
			return
		match flag:
			"--out":
				output_root = str(arguments[index + 1])
			"--event":
				event_ids.append(str(arguments[index + 1]))
			_:
				push_error("Unknown argument %s." % flag)
				quit(2)
				return
		index += 2

	var exporter := ExportScript.new()
	# No --event exports every catalog event into one package, which is the
	# shape the split plan wants: shared members are stored once.
	var build_options := {} if include_analysis_groups else {"analysis_groups": false}
	if include_unbound_groups:
		build_options["include_unbound_groups"] = true
	var built := exporter.build(source_root, event_ids, build_options)
	if not built.get("ok", false):
		for failure in built.get("failures", []):
			print("FAILURE %s" % str(failure))
		quit(1)
		return
	# This CLI reads the original source root, so an original media archive that
	# is missing leaves names undecided and the export stops. A synthetic or
	# workspace build tolerates undecided rows (`shipped: null`); this one does not.
	var undecided := MediaIdentityScript.unavailable_rows(built.media_identity)
	if not undecided.is_empty():
		for row in undecided.slice(0, UNDECIDED_ROWS_LISTED):
			print("FAILURE media identity undecided: %s" % row)
		print("FAILURE %d referenced media names are undecided because an original media archive is not in the source root" % undecided.size())
		quit(1)
		return
	var serialized := exporter.serialize(built)
	if not serialized.get("ok", false):
		for failure in serialized.get("failures", []):
			print("FAILURE %s" % str(failure))
		quit(1)
		return
	# Gate 1 (WD-21 U1 D8, a tool decision over an original-data fact): the
	# package's absent media names against the known-absent register, before
	# anything is written. It lives here and not in build()/serialize() so a
	# synthetic or workspace build is never gated.
	#
	# The default full build - no --event, analysis groups on, no
	# --include-unbound-groups (this CLI has no workspace binding) - has the one
	# static absent set the register records, so it must equal the register
	# exactly: a new absence or a stale row fails. Every other variant (--event,
	# --no-analysis-groups, --include-unbound-groups) holds a subset or a
	# superset of that set, so it is only held to "no unregistered absence".
	var exact_register := event_ids.is_empty() and include_analysis_groups and not include_unbound_groups
	if not _known_absent_gate(serialized.manifest.get("media_inventory"), exact_register):
		quit(1)
		return
	if not output_root.is_empty():
		var written := exporter.write(output_root, serialized)
		if not written.get("ok", false):
			for failure in written.get("failures", []):
				print("FAILURE %s" % str(failure))
			quit(1)
			return

	var entry_reports: Array = built.entry_reports
	print("events=%d" % built.events.size())
	for untyped_event in built.events:
		print("  %s" % str((untyped_event as Dictionary).event_id))
	print("output=%s" % (output_root if not output_root.is_empty() else "<not written>"))
	var membership: Dictionary = built.get("membership", {})
	var external_terminals: Array = serialized.manifest.get("incompleteness", {}).get("external_terminals", [])
	print("membership=%s catalog_members=%d analysis_group_members=%d analysis_groups=%d external_terminals=%d" % [
		str(membership.get("rule", "")),
		int(membership.get("catalog_members", 0)),
		int(membership.get("analysis_group_members", 0)),
		int(membership.get("analysis_groups", []).size()),
		external_terminals.size(),
	])
	print("")
	print("entry            role                  bytecode   instr  records dropped   texts  opaque")
	for untyped_report in entry_reports:
		var report: Dictionary = untyped_report
		print("%-15s %-20s %9d %7d %8d %7d %7d %7d" % [
			str(report.entry),
			str(report.role),
			int(report.bytecode_bytes),
			int(report.instruction_count),
			int(report.record_count),
			int(report.provenance_dropped),
			int(report.text_count),
			int(report.opaque_region_count),
		])
	print("")
	for untyped_report in entry_reports:
		var report: Dictionary = untyped_report
		var targets: Dictionary = report.control_targets
		print("%-15s targets=%d on_record=%d resolves_forward=%d unresolved=%d" % [
			str(report.entry),
			int(targets.total),
			int(targets.on_kept_record),
			int(targets.resolves_forward),
			int(targets.unresolved),
		])
	print("")
	var total_bytes := 0
	for untyped_file in serialized.files:
		var file: Dictionary = untyped_file
		total_bytes += int(file.size)
		print("%-30s %9d bytes" % [str(file.name), int(file.size)])
	var total_bytecode := 0
	var total_records := 0
	var total_dropped := 0
	for untyped_report in entry_reports:
		var report: Dictionary = untyped_report
		total_bytecode += int(report.bytecode_bytes)
		total_records += int(report.record_count)
		total_dropped += int(report.provenance_dropped)
	print("")
	print("package_bytes=%d bytecode_bytes=%d expansion=%.2fx" % [
		total_bytes,
		total_bytecode,
		(float(total_bytes) / float(total_bytecode)) if total_bytecode > 0 else 0.0,
	])
	print("records=%d provenance_dropped=%d" % [total_records, total_dropped])
	print("dropped_operand_field_kinds=%d undecodable_text=%d unresolved_expressions=%d" % [
		int(built.dropped_operand_fields.size()),
		int(built.undecodable_text_payloads),
		int(built.unresolved_expression_boundaries),
	])
	for line in MediaIdentityScript.summary_lines(serialized.manifest.media_inventory):
		print(line)
	print("package_sha256=%s" % str(serialized.manifest.package_sha256))
	print(
		"PASS: playback package export: %d events from %d member entries (%d catalog-verified, %d bound by %d analysis groups); "
		% [
			built.events.size(),
			entry_reports.size(),
			int(membership.get("catalog_members", 0)),
			int(membership.get("analysis_group_members", 0)),
			int(membership.get("analysis_groups", []).size()),
		]
		+ "%d records, %d provenance instructions dropped, %d analysis fields dropped by rule, "
		% [
			total_records,
			total_dropped,
			int(built.dropped_operand_fields.size()) + int(built.dropped_instruction_fields.size()),
		]
		+ "%d bytes over %d bytes of bytecode; archive unchanged. Core %s / %s. "
		% [
			total_bytes,
			total_bytecode,
			ContentCoreVersionScript.CORE_VERSION,
			ContentCoreVersionScript.PLAYBACK_PACKAGE_SCHEMA,
		]
		+ "Media extraction, package-scope sharing of the library and playback itself are not included."
	)
	quit(0)


# Runs gate 1 and prints its outcome; false stops the export. A register that
# cannot be read or trusted stops it too: the gate never passes on a register it
# could not check.
func _known_absent_gate(media_inventory: Variant, exact: bool) -> bool:
	var loaded: Dictionary = KnownAbsentMediaScript.load_register()
	if not loaded.get("ok", false):
		print("FAILURE %s" % str(loaded.get("error", "")))
		return false
	var compared: Dictionary = KnownAbsentMediaScript.compare_export(loaded.register, media_inventory, exact)
	var failures: Array = compared.failures
	for failure in failures.slice(0, GATE_ROWS_LISTED):
		print("FAILURE known-absent media: %s" % str(failure))
	if failures.size() > GATE_ROWS_LISTED:
		print("FAILURE known-absent media: %d more rows not listed" % (failures.size() - GATE_ROWS_LISTED))
	if not failures.is_empty():
		print("FAILURE the package's absent media names disagree with %s (%s): %d unregistered, %d stale, %d searched differently, %d archive headers" % [
			KnownAbsentMediaScript.REGISTER_PATH, "exact" if exact else "no unregistered absence",
			(compared.unregistered as Array).size(), (compared.stale as Array).size(),
			(compared.changed as Array).size(), (compared.header as Array).size(),
		])
		return false
	print("known_absent_media register_rows=%d package_absent=%d compare=%s" % [
		int(compared.registered), int(compared.absent), "exact" if exact else "no_unregistered_absence",
	])
	return true
