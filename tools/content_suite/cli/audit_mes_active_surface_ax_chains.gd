extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const AuditScript := preload("res://content_core/mes_active_surface_ax_audit.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const EXPECTED_SCRIPT_COUNT := 1016
const EXPECTED_SURFACE8_WRITES := 1570
const EXPECTED_CANONICAL_CHAINS := 1352
const EXPECTED_CHAIN_SCRIPT_COUNT := 398
const EXPECTED_BOUND_CHAINS := 1351
const EXPECTED_UNBOUND_CHAIN := "MUSIC.MES:0xA2"


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_active_surface_ax_chains.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader, reader.last_error)
		return
	var archive_before := reader.get_archive_fingerprint()
	if archive_before != ARCHIVE_SHA256:
		_fail(reader, "Active-surface AX audit archive hash does not match the audited original set.")
		return
	var parser := MesContainerScript.new()
	var audit := AuditScript.new()
	var script_count := 0
	var surface8_writes := 0
	var canonical_chains := 0
	var bound_chains := 0
	var chain_scripts: Dictionary = {}
	var unbound_chains: Array[String] = []
	var eventb02_writes: Array = []
	var eventb02_chains: Array = []
	var eventb14_chain: Dictionary = {}
	var failures: Array[String] = []
	for entry in reader.get_entries():
		var entry_name := str(entry.name)
		if entry_name.get_extension().to_lower() not in ["mes", "lib"]:
			continue
		script_count += 1
		var document := parser.parse(
			reader.read_entry(entry_name),
			{"archive": "mes.arc", "entry": entry_name}
		)
		if not document.get("ok", false):
			failures.append("%s container parse failed" % entry_name)
			continue
		var result := audit.scan_document(document, entry_name)
		if (
			not result.get("ok", false)
			or str(result.get("schema", "")) != ContentCoreVersionScript.MES_ACTIVE_SURFACE_AX_AUDIT_SCHEMA
		):
			failures.append("%s active-surface scan failed" % entry_name)
			continue
		surface8_writes += int(result.surface8_write_count)
		canonical_chains += int(result.canonical_chain_count)
		if entry_name == "EVENTB02.MES":
			eventb02_writes = result.surface8_writes.duplicate()
			eventb02_chains = result.chains.duplicate(true)
		for chain in result.chains:
			chain_scripts[entry_name] = true
			var key := "%s:0x%X" % [entry_name, int(chain.select_offset)]
			if int(chain.binding_offset) >= 0:
				bound_chains += 1
			else:
				unbound_chains.append(key)
			if entry_name == "EVENTB14.MES" and int(chain.select_offset) == 0x0E0C:
				eventb14_chain = chain
	var archive_after := reader.get_archive_fingerprint()
	reader.close()
	if script_count != EXPECTED_SCRIPT_COUNT:
		failures.append("script count changed: %d" % script_count)
	if surface8_writes != EXPECTED_SURFACE8_WRITES:
		failures.append("surface-8 write count changed: %d" % surface8_writes)
	if canonical_chains != EXPECTED_CANONICAL_CHAINS:
		failures.append("canonical chain count changed: %d" % canonical_chains)
	if chain_scripts.size() != EXPECTED_CHAIN_SCRIPT_COUNT:
		failures.append("canonical chain script count changed: %d" % chain_scripts.size())
	if bound_chains != EXPECTED_BOUND_CHAINS:
		failures.append("bound chain count changed: %d" % bound_chains)
	unbound_chains.sort()
	if unbound_chains != [EXPECTED_UNBOUND_CHAIN]:
		failures.append("unbound chain set changed: %s" % ",".join(unbound_chains))
	if 0x0295 not in eventb02_writes or not eventb02_chains.is_empty():
		failures.append("EVENTB02 branch-family exclusion changed.")
	if not _matches_eventb14(eventb14_chain):
		failures.append("EVENTB14 canonical chain changed.")
	if archive_after != archive_before:
		failures.append("Original mes.arc changed during active-surface AX audit.")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print(
		"MES_ACTIVE_SURFACE_AX_CHAINS schema=%s scripts=%d surface8_writes=%d canonical=%d chain_scripts=%d bound=%d unbound=%s eventb02=branch_family eventb14=canonical source_unchanged=true"
		% [
			ContentCoreVersionScript.MES_ACTIVE_SURFACE_AX_AUDIT_SCHEMA,
			script_count,
			surface8_writes,
			canonical_chains,
			chain_scripts.size(),
			bound_chains,
			EXPECTED_UNBOUND_CHAIN,
		]
	)
	quit(0)


func _matches_eventb14(chain: Dictionary) -> bool:
	return (
		int(chain.get("select_offset", -1)) == 0x0E0C
		# Core 0.316.0 (2026-09-13): the MMO marker is the whole System.function[9]
		# call, so its offset is the 0x0D byte before the 09.
		and int(chain.get("mmo_marker_offset", -1)) == 0x0E13
		and str(chain.get("mmo_name", "")).to_upper() == "B14AN.MMO"
		and int(chain.get("restore_offset", -1)) == 0x0E22
		and int(chain.get("ax_marker_offset", -1)) == 0x0E29
		and str(chain.get("ax_name", "")) == "B14.AX"
		and int(chain.get("binding_offset", -1)) == 0x0E54
		and str(chain.get("active_surface_storage", "")) == "banked_u16"
		and int(chain.get("active_surface_bank", -1)) == 0
		and int(chain.get("active_surface_storage_index", -1)) == 1
		and str(chain.get("reachability", "")) == "not_proven_by_scan"
	)


func _fail(reader, message: String) -> void:
	reader.close()
	push_error(message)
	quit(1)
