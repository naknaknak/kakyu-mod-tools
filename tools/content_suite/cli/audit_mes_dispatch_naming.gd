extends SceneTree

# Read-only archive-wide audit of where an archive entry is NAMED.
#
# The literal dispatch inventory in cli/audit_mes_event_corpus_inventory.gd
# counts dispatch records that the strict aligned decoder reaches. That decoder
# stops at the first opaque boundary in every address-table region and preserves
# the rest of the region as undecoded bytes, so its "never dispatched" set is
# scope-bound: it means "not named in a strictly decoded region", not "not named
# in the archive".
#
# This audit closes that gap without weakening the decoder. It scans the raw
# bytecode for the exact dispatch envelope
#
#     00 | <0x0F|0x0E> 01 <archive entry name> 00 00
#
# validates the scanner against the decoder everywhere the decoder looked, and
# then reports what the scanner finds where the decoder stopped. It also decodes
# the command-0x0D inline script execution sites, which name an archive entry
# without using a dispatch record at all.
#
# The audit is structural only. Being named by a record inside an opaque tail is
# evidence that the entry is dispatched somewhere in the archive; it is not
# evidence that the naming record executes. It bounds the unreachability claim,
# which is what the Event Player corpus goal needs before any stored entry is
# called unreachable.

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"

const EXPECTED_ENTRY_COUNT := 1016

# Reproduced from the literal dispatch inventory, so a decoder change that moves
# either instrument shows up here as a disagreement instead of a silent redraw.
const EXPECTED_STRICT_DISPATCHES := 11124
const EXPECTED_STRICT_TARGETS := 1005
const EXPECTED_STRICT_UNNAMED := 11

# The strict decoder's blind spot, measured from its opaque boundaries. Since
# Core 0.316.0 frames command 0x0D as one system call the archive decodes
# without an opaque boundary, so the scan below finds nothing past the decoder;
# it stays as the independent cross-check of every strict row.
const EXPECTED_OPAQUE_ENTRIES := 0
const EXPECTED_OPAQUE_REGIONS := 0
const EXPECTED_OPAQUE_BYTES := 0

# The byte scan.
const EXPECTED_ENVELOPES := 11124
const EXPECTED_ENVELOPES_0F := 9875
const EXPECTED_ENVELOPES_0E := 1249
const EXPECTED_TAIL_ENVELOPES := 0
const EXPECTED_TAIL_ENVELOPES_0F := 0
const EXPECTED_TAIL_ENVELOPES_0E := 0
const EXPECTED_TAIL_CALLERS := 0
const EXPECTED_TAIL_TARGETS := 0
const EXPECTED_TAIL_TARGETS_ALREADY_STRICT := 0
const EXPECTED_TAIL_TARGETS_NEWLY_NAMED := 0
const EXPECTED_NAMED_TARGETS := 1005
const EXPECTED_UNNAMED_BY_ENVELOPE := 11

# Command-0x0D inline script execution, the one naming form that is not a
# dispatch record at all.
const EXPECTED_INLINE_SITES := 2
const EXPECTED_INLINE_CALLER := "START.MES"
const EXPECTED_INLINE_NAMES := {"LIBLARY.LIB": 2, "DEF_MAIN.MES": 3}

# What is left after every naming form this archive can express. START.MES is
# excluded here because it is named by the native host, not by the archive; the
# executable-side evidence is audit_ai5_mes_exe.py and audit_mes_startup_bootstrap.py.
const EXPECTED_HOST_NAMED := "START.MES"
const EXPECTED_UNNAMED_ENTRIES := [
	"DATETIME.MES",
	"EVENTL09.MES",
	"FLAGINI.MES",
	"FLAG_INC.MES",
	"M_TIME.MES",
	"OMAKE.MES",
	"SIZUKA44.MES",
	"_TEST.MES",
]

# The literal dispatch inventory once named EVENTA13.MES and EVENTL09.MES as the
# two strongest unreachable candidates in the archive. This coordinate refutes
# the first of them - it sat in an opaque tail until Core 0.316.0 and is a
# strict row since - so it is bound exactly rather than counted.
const EXPECTED_A13_CALLER := "FLOOR4.MES"
const EXPECTED_A13_OFFSET := 0x0E4C
const EXPECTED_A13_COMMAND := 0x0E

const TRACKED_REPORT := "res://config/event_catalog/dispatch_naming_v1.json"

const STATEMENT_SEPARATOR := 0x00
const INLINE_HEADER := [0x0D, 0x08, 0xFF, 0x02]
const MAX_ENTRY_NAME_BYTES := 32

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty() or arguments.size() > 2:
		push_error("Usage: audit_mes_dispatch_naming.gd <ELFIMAGE-directory> [out.json]")
		quit(2)
		return
	var source_root := str(arguments[0]).replace("\\", "/")
	while source_root.ends_with("/"):
		source_root = source_root.substr(0, source_root.length() - 1)
	var reader := ArcReaderScript.new()
	if not reader.open(source_root + "/mes.arc"):
		push_error(reader.last_error)
		quit(1)
		return
	_check("authoritative mes.arc fingerprint", reader.get_archive_fingerprint() == ARCHIVE_SHA256)

	var parser := MesContainerScript.new()
	var analysis_builder := MesAnalysisScript.new()
	var archive_entries := {}
	for untyped_entry in reader.get_entries():
		var listed: Dictionary = untyped_entry
		var listed_name := str(listed.name)
		if listed_name.get_extension().to_lower() in ["mes", "lib"]:
			archive_entries[listed_name.to_upper()] = true

	var entry_count := 0
	var strict_rows := {}            # "CALLER@offset" -> target
	var strict_targets := {}
	var opaque_entries := 0
	var opaque_regions := 0
	var opaque_bytes := 0
	var envelopes: Array[Dictionary] = []
	var inline_sites: Array[Dictionary] = []
	var separator_prefixed := 0

	for untyped_entry in reader.get_entries():
		var entry: Dictionary = untyped_entry
		var name := str(entry.name)
		if name.get_extension().to_lower() not in ["mes", "lib"]:
			continue
		entry_count += 1
		var upper := name.to_upper()
		var document := parser.parse(reader.read_entry(name), {"entry": name})
		if not document.get("ok", false):
			_failures.append("%s container: %s" % [name, document.get("error", "failed")])
			continue
		var analysis := analysis_builder.build(document)
		if not analysis.get("ok", false):
			_failures.append("%s analysis: %s" % [name, analysis.get("error", "failed")])
			continue
		var code: PackedByteArray = document.bytecode

		for untyped_instruction in analysis.get("instructions", []):
			var instruction: Dictionary = untyped_instruction
			var target := str(instruction.get("script_target", ""))
			if target.is_empty():
				continue
			var offset := int(instruction.source_offset)
			strict_rows["%s@%d" % [upper, offset]] = target.to_upper()
			strict_targets[target.to_upper()] = true

		var tails: Array[Vector2i] = []
		for untyped_boundary in analysis.get("opaque_boundaries", []):
			var boundary: Dictionary = untyped_boundary
			tails.append(Vector2i(int(boundary.source_offset), int(boundary.end_offset)))
			opaque_regions += 1
			opaque_bytes += int(boundary.byte_length)
		if not tails.is_empty():
			opaque_entries += 1

		for row in _scan_envelopes(code, upper, archive_entries):
			row["in_opaque_tail"] = _inside(tails, int(row.offset))
			if int(row.offset) > 0 and code[int(row.offset) - 1] == STATEMENT_SEPARATOR:
				separator_prefixed += 1
			envelopes.append(row)
		for row in _scan_inline(code, upper, archive_entries):
			inline_sites.append(row)

	reader.close()

	# --- the scanner is validated against the decoder before it is trusted past it
	var matched := 0
	var mismatched := 0
	var outside_tail_extras: Array[String] = []
	var tail_rows: Array[Dictionary] = []
	var tail_callers := {}
	var tail_targets := {}
	var named_targets := {}
	var envelopes_0f := 0
	var envelopes_0e := 0
	for untyped_row in envelopes:
		var row: Dictionary = untyped_row
		var key := "%s@%d" % [str(row.caller), int(row.offset)]
		named_targets[str(row.target)] = true
		if int(row.command) == 0x0F:
			envelopes_0f += 1
		else:
			envelopes_0e += 1
		if strict_rows.has(key):
			matched += 1
			if str(strict_rows[key]) != str(row.target):
				mismatched += 1
			continue
		if not bool(row.in_opaque_tail):
			outside_tail_extras.append(key)
			continue
		tail_rows.append(row)
		tail_callers[str(row.caller)] = true
		tail_targets[str(row.target)] = true

	var tail_0f := 0
	var tail_0e := 0
	for untyped_row in tail_rows:
		var row: Dictionary = untyped_row
		if int(row.command) == 0x0F:
			tail_0f += 1
		else:
			tail_0e += 1

	var already_strict := 0
	var newly_named: Array[String] = []
	for target in tail_targets.keys():
		if strict_targets.has(str(target)):
			already_strict += 1
		else:
			newly_named.append(str(target))
	newly_named.sort()

	var strict_unnamed: Array[String] = []
	var unnamed_by_envelope: Array[String] = []
	for stored in archive_entries.keys():
		if not strict_targets.has(str(stored)):
			strict_unnamed.append(str(stored))
		if not named_targets.has(str(stored)):
			unnamed_by_envelope.append(str(stored))
	strict_unnamed.sort()
	unnamed_by_envelope.sort()

	var inline_named := {}
	for untyped_row in inline_sites:
		var row: Dictionary = untyped_row
		inline_named[str(row.target)] = int(row.selector)

	var unnamed_after_archive: Array[String] = []
	for stored in unnamed_by_envelope:
		if inline_named.has(stored) or stored == EXPECTED_HOST_NAMED:
			continue
		unnamed_after_archive.append(stored)
	unnamed_after_archive.sort()

	var event_named_unreached: Array[String] = []
	for stored in unnamed_after_archive:
		if stored.begins_with("EVENT"):
			event_named_unreached.append(stored)

	var a13_key := "%s@%d" % [EXPECTED_A13_CALLER, EXPECTED_A13_OFFSET]
	var a13_bound := false
	for untyped_row in envelopes:
		var row: Dictionary = untyped_row
		if "%s@%d" % [str(row.caller), int(row.offset)] != a13_key:
			continue
		a13_bound = (
			str(row.target) == "EVENTA13.MES"
			and int(row.command) == EXPECTED_A13_COMMAND
			and str(strict_rows.get(a13_key, "")) == "EVENTA13.MES"
		)

	_check("no decode failure", _failures.is_empty())
	_check("MES/LIB entry count", entry_count == EXPECTED_ENTRY_COUNT)
	_check("strict decoder dispatch rows", strict_rows.size() == EXPECTED_STRICT_DISPATCHES)
	_check("strict decoder distinct targets", strict_targets.size() == EXPECTED_STRICT_TARGETS)
	_check("strict decoder never-named set", strict_unnamed.size() == EXPECTED_STRICT_UNNAMED)
	_check("entries carrying an opaque tail", opaque_entries == EXPECTED_OPAQUE_ENTRIES)
	_check("opaque regions", opaque_regions == EXPECTED_OPAQUE_REGIONS)
	_check("opaque bytes", opaque_bytes == EXPECTED_OPAQUE_BYTES)
	_check("byte-scanned dispatch envelopes", envelopes.size() == EXPECTED_ENVELOPES)
	_check("envelope command-0x0F count", envelopes_0f == EXPECTED_ENVELOPES_0F)
	_check("envelope command-0x0E count", envelopes_0e == EXPECTED_ENVELOPES_0E)
	_check("every envelope follows a statement separator", separator_prefixed == envelopes.size())
	# The scanner must find every decoded row and must find nothing the decoder
	# missed inside a region the decoder actually read. Without this the extra
	# rows below would be indistinguishable from a misaligned scan.
	_check("scanner reproduces every strict decoder row", matched == EXPECTED_STRICT_DISPATCHES)
	_check("scanner agrees with the decoder on every target", mismatched == 0)
	_check("scanner finds nothing extra outside an opaque tail", outside_tail_extras.is_empty())
	_check("opaque-tail envelopes", tail_rows.size() == EXPECTED_TAIL_ENVELOPES)
	_check("opaque-tail command-0x0F count", tail_0f == EXPECTED_TAIL_ENVELOPES_0F)
	_check("opaque-tail command-0x0E count", tail_0e == EXPECTED_TAIL_ENVELOPES_0E)
	_check("opaque-tail caller count", tail_callers.size() == EXPECTED_TAIL_CALLERS)
	_check("opaque-tail target count", tail_targets.size() == EXPECTED_TAIL_TARGETS)
	_check("opaque-tail targets already strictly named", already_strict == EXPECTED_TAIL_TARGETS_ALREADY_STRICT)
	_check("never-named entries the tails name", newly_named.size() == EXPECTED_TAIL_TARGETS_NEWLY_NAMED)
	_check("distinct entries named by an envelope", named_targets.size() == EXPECTED_NAMED_TARGETS)
	_check("entries no envelope names", unnamed_by_envelope.size() == EXPECTED_UNNAMED_BY_ENVELOPE)
	_check("named and unnamed sets partition the archive",
		named_targets.size() + unnamed_by_envelope.size() == entry_count)
	_check("inline script execution sites", inline_sites.size() == EXPECTED_INLINE_SITES)
	_check("inline script execution names",
		JSON.stringify(inline_named, "", true) == JSON.stringify(EXPECTED_INLINE_NAMES, "", true))
	_check("every inline site is in the startup entry", _all_callers_are(inline_sites, EXPECTED_INLINE_CALLER))
	_check("entries no archive naming form reaches",
		JSON.stringify(unnamed_after_archive) == JSON.stringify(EXPECTED_UNNAMED_ENTRIES))
	_check("EVENTL09.MES is the only EVENT-named entry left",
		JSON.stringify(event_named_unreached) == "[\"EVENTL09.MES\"]")
	_check("EVENTA13.MES is named by a strictly decoded root handoff", a13_bound)

	# The replay gallery's naming rows, kept as tracked evidence for
	# tools/audit_duplicate_entries.py now that no envelope sits past the decoder.
	var gallery_rows: Array[Dictionary] = []
	for untyped_row in envelopes:
		var row: Dictionary = untyped_row
		if str(row.target).begins_with("SCENE_"):
			gallery_rows.append(row)

	var report := {
		"schema": "kakyu_mes_dispatch_naming_audit/v1",
		"content_core_version": ContentCoreVersionScript.CORE_VERSION,
		"archive_sha256": ARCHIVE_SHA256,
		"entry_count": entry_count,
		"strict_dispatch_count": strict_rows.size(),
		"strict_target_count": strict_targets.size(),
		"strict_unnamed_count": strict_unnamed.size(),
		"opaque_entries": opaque_entries,
		"opaque_regions": opaque_regions,
		"opaque_bytes": opaque_bytes,
		"envelope_count": envelopes.size(),
		"envelope_command_0f": envelopes_0f,
		"envelope_command_0e": envelopes_0e,
		"strict_rows_reproduced": matched,
		"opaque_tail_envelope_count": tail_rows.size(),
		"opaque_tail_callers": tail_callers.keys().size(),
		"opaque_tail_targets": tail_targets.keys().size(),
		"newly_named_entries": newly_named,
		"named_target_count": named_targets.size(),
		"unnamed_by_envelope": unnamed_by_envelope,
		"inline_script_execution": inline_sites,
		"host_named_entry": EXPECTED_HOST_NAMED,
		"unnamed_after_archive_forms": unnamed_after_archive,
		"opaque_tail_envelopes": tail_rows,
		"gallery_envelopes": gallery_rows,
	}
	var fingerprint := JSON.stringify(report, "", false, true).sha256_text()
	_check("tracked naming report reproduces", _matches_tracked(report))

	print("checks=%d failures=%d" % [_checks, _failures.size()])
	print("entries=%d strict_rows=%d strict_targets=%d strict_unnamed=%d" % [
		entry_count, strict_rows.size(), strict_targets.size(), strict_unnamed.size()])
	print("opaque entries=%d regions=%d bytes=%d" % [opaque_entries, opaque_regions, opaque_bytes])
	print("envelopes=%d (0x0F=%d 0x0E=%d) reproduced_strict=%d tail=%d" % [
		envelopes.size(), envelopes_0f, envelopes_0e, matched, tail_rows.size()])
	print("tail callers=%d targets=%d newly_named=%d" % [
		tail_callers.size(), tail_targets.size(), newly_named.size()])
	print("named=%d unnamed_by_envelope=%s" % [named_targets.size(), JSON.stringify(unnamed_by_envelope)])
	print("inline=%s" % JSON.stringify(inline_named))
	print("unnamed_after_archive_forms=%s" % JSON.stringify(unnamed_after_archive))
	print("report_sha256=%s" % fingerprint)
	for failure in _failures:
		print("FAILURE %s" % failure)

	if arguments.size() >= 2:
		report["report_sha256"] = fingerprint
		var file := FileAccess.open(str(arguments[1]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  ", false, true))
			file.close()
			print("wrote=%s" % arguments[1])
	quit(0 if _failures.is_empty() else 1)


func _scan_envelopes(
	code: PackedByteArray, caller: String, archive_entries: Dictionary
) -> Array[Dictionary]:
	# 0x0F 01 <name> 00 00 and 0x0E 01 <name> 00 00, with the name required to be
	# an entry the archive actually stores. The statement separator before the
	# command is measured, not required, so a misaligned hit stays visible.
	var rows: Array[Dictionary] = []
	var size := code.size()
	var index := 0
	while index + 4 < size:
		var command := code[index]
		if (command != 0x0F and command != 0x0E) or code[index + 1] != 0x01:
			index += 1
			continue
		var cursor := index + 2
		var limit := mini(size, cursor + MAX_ENTRY_NAME_BYTES)
		while cursor < limit and code[cursor] != 0:
			cursor += 1
		if cursor >= limit or cursor + 1 >= size or code[cursor + 1] != 0:
			index += 1
			continue
		var raw := code.slice(index + 2, cursor)
		var name := raw.get_string_from_ascii().to_upper()
		if name.is_empty() or not archive_entries.has(name):
			index += 1
			continue
		rows.append({
			"caller": caller,
			"offset": index,
			"end_offset": cursor + 2,
			"command": command,
			"target": name,
		})
		index = cursor + 2
	return rows


func _scan_inline(
	code: PackedByteArray, caller: String, archive_entries: Dictionary
) -> Array[Dictionary]:
	# 0x0D 08 FF 02 <selector 2|3> FF 01 <name> 00 00, the command-0x0D form that
	# loads and runs a named archive entry without a dispatch record.
	var rows: Array[Dictionary] = []
	var size := code.size()
	var index := 0
	while index + 8 < size:
		if (
			code[index] != INLINE_HEADER[0]
			or code[index + 1] != INLINE_HEADER[1]
			or code[index + 2] != INLINE_HEADER[2]
			or code[index + 3] != INLINE_HEADER[3]
		):
			index += 1
			continue
		var selector := code[index + 4]
		if (selector != 2 and selector != 3) or code[index + 5] != 0xFF or code[index + 6] != 0x01:
			index += 1
			continue
		var cursor := index + 7
		var limit := mini(size, cursor + MAX_ENTRY_NAME_BYTES)
		while cursor < limit and code[cursor] != 0:
			cursor += 1
		if cursor >= limit or cursor + 1 >= size or code[cursor + 1] != 0:
			index += 1
			continue
		var name := code.slice(index + 7, cursor).get_string_from_ascii().to_upper()
		if name.is_empty() or not archive_entries.has(name):
			index += 1
			continue
		rows.append({
			"caller": caller,
			"offset": index,
			"selector": selector,
			"role": "library_bootstrap" if selector == 2 else "definition_bootstrap",
			"target": name,
		})
		index = cursor + 2
	return rows


func _matches_tracked(report: Dictionary) -> bool:
	# The tracked report is the classification tool's tail evidence, so it is
	# compared here rather than only fingerprinted. `content_core_version` and the
	# fingerprint over it are excluded: they move on every Core bump and would
	# make this check stale for a reason unrelated to the archive or the decode.
	var file := FileAccess.open(TRACKED_REPORT, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	var tracked: Dictionary = parsed
	# Round-trip the fresh report so both sides carry JSON's numeric types.
	var reparsed = JSON.parse_string(JSON.stringify(report))
	if not reparsed is Dictionary:
		return false
	return _structure(tracked) == _structure(reparsed)


func _structure(report: Dictionary) -> String:
	var copy := report.duplicate(true)
	copy.erase("content_core_version")
	copy.erase("report_sha256")
	return JSON.stringify(copy, "", true, true)


func _inside(tails: Array[Vector2i], offset: int) -> bool:
	for tail in tails:
		if offset >= tail.x and offset < tail.y:
			return true
	return false


func _all_callers_are(rows: Array[Dictionary], caller: String) -> bool:
	for row in rows:
		if str(row.caller) != caller:
			return false
	return true


func _check(label: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures.append(label)
