extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const DetachedDefinitionPreviewScript := preload("res://content_core/mes_detached_definition_preview.gd")
const MesStartupContextScript := preload("res://content_core/mes_startup_context.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_detached_definition_corpus_audit/v3"
const CALLER_MAX_STEPS := 2000
const BODY_MAX_STEPS := 10000
const SAMPLE_LIMIT := 24
const AUDITED_ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const STARTUP_ENTRY := "DEF_MAIN.MES"
const STARTUP_ENTRY_SHA256 := "f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0"
const AUDITED_COUNTS := {
	"entries": 1015,
	"anchors": 133459,
	"selection_boundaries": 797,
	"grouped_selection_boundaries": 797,
	"multi_group_selection_boundaries": 268,
	"nonpresented_group_boundaries": 1,
	"nonpresented_group_definitions": 9,
	"previews": 2622,
	"unique_bodies": 2614,
	"complete": 2622,
	"message_previews": 2622,
	"messages": 2624,
	"traced_steps": 5250,
	"source_entries": 277,
	"registered_definition_calls": 1,
}
const AUDITED_TERMINALS := {"script_return": 2622}


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_detached_definition_previews.gd <mes.arc>")
		quit(2)
		return
	var archive_path := str(arguments[0])
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		push_error(reader.last_error)
		quit(1)
		return
	var source_sha_before := reader.get_archive_fingerprint()
	var parser := MesContainerScript.new()
	var startup_document := parser.parse(
		reader.read_entry(STARTUP_ENTRY),
		{"archive": "mes.arc", "entry": STARTUP_ENTRY}
	)
	var startup_context := MesStartupContextScript.new().build(startup_document)
	var registered_definitions: Dictionary = startup_context.get("registered_definitions", {})
	if (
		reader.get_entry_fingerprint(STARTUP_ENTRY) != STARTUP_ENTRY_SHA256
		or not startup_context.get("ok", false)
		or registered_definitions.size() != 14
	):
		push_error("The audited DEF_MAIN startup registry is unavailable.")
		quit(1)
		return
	var caller_runner := MesEventRunnerScript.new()
	var preview_runner := DetachedDefinitionPreviewScript.new()
	var failures: Array[String] = []
	var terminal_counts := {}
	var entry_names := {}
	var unique_bodies := {}
	var samples: Array[String] = []
	var boundary_samples: Array[String] = []
	var entry_count := 0
	var anchor_count := 0
	var selection_boundary_count := 0
	var grouped_selection_boundary_count := 0
	var multi_group_selection_boundary_count := 0
	var nonpresented_group_boundary_count := 0
	var nonpresented_group_definition_count := 0
	var preview_count := 0
	var complete_count := 0
	var previews_with_messages := 0
	var message_count := 0
	var traced_steps := 0
	var registered_definition_call_count := 0

	for entry in reader.get_entries():
		if str(entry.name).get_extension().to_lower() != "mes":
			continue
		var document := parser.parse(reader.read_entry(str(entry.name)), {
			"archive": reader.archive_path.replace("\\", "/").get_file(),
			"entry": str(entry.name),
		})
		if not document.get("ok", false):
			failures.append("%s container: %s" % [str(entry.name), str(document.get("error", "unknown"))])
			continue
		entry_count += 1
		for anchor in document.get("entries", []):
			anchor_count += 1
			var state := SandboxStateScript.new(1)
			var caller_result := caller_runner.run(
				document.bytecode,
				int(anchor.offset),
				state,
				int(document.header.code_size),
				CALLER_MAX_STEPS,
				{"address_table_offsets": document.header.entry_offsets}
			)
			if str(caller_result.get("status", "")) != "def_selection_boundary":
				continue
			selection_boundary_count += 1
			var presented_definitions: Array = caller_result.get("definitions", [])
			var definitions := _registered_definitions_for_audit(caller_result)
			var definition_groups: Dictionary = caller_result.get("definition_groups", {})
			if not definition_groups.is_empty():
				grouped_selection_boundary_count += 1
				if definition_groups.size() > 1:
					multi_group_selection_boundary_count += 1
				var nonpresented_count := definitions.size() - presented_definitions.size()
				if nonpresented_count > 0:
					nonpresented_group_boundary_count += 1
				nonpresented_group_definition_count += nonpresented_count
				if definitions.size() != int(caller_result.get("registered_definition_count", -1)):
					failures.append("%s#%04d grouped routine-40 registry count mismatch" % [
						str(entry.name), int(anchor.index),
					])
			if definitions.is_empty():
				failures.append("%s#%04d routine-40 boundary exposed no bounded DEF bodies" % [
					str(entry.name), int(anchor.index),
				])
				continue
			for untyped_definition in definitions:
				var definition: Dictionary = untyped_definition
				var state_before := state.snapshot()
				var result := preview_runner.run(
					document.bytecode,
					definition,
					state,
					BODY_MAX_STEPS,
					{
						"address_table_offsets": document.header.entry_offsets,
						"registered_definitions": registered_definitions,
					}
				)
				preview_count += 1
				entry_names[str(entry.name)] = true
				var body_key := "%s:%d:%d:%d:%s" % [
					str(entry.name),
					int(definition.get("definition_id", -1)),
					int(definition.get("body_offset", -1)),
					int(definition.get("target_offset", -1)),
					str(definition.get("body_sha256", "")),
				]
				unique_bodies[body_key] = true
				var terminal_status := str(result.get("terminal_status", result.get("status", "unknown")))
				terminal_counts[terminal_status] = int(terminal_counts.get(terminal_status, 0)) + 1
				traced_steps += (result.get("trace", []) as Array).size()
				registered_definition_call_count += (result.get("registered_definition_calls", []) as Array).size()
				var messages: Array = result.get("messages", [])
				if not messages.is_empty():
					previews_with_messages += 1
					message_count += messages.size()
				if result.get("ok", false):
					complete_count += 1
				elif boundary_samples.size() < SAMPLE_LIMIT:
					var terminal_trace: Array = result.get("trace", [])
					var terminal_definition_id := -1
					if not terminal_trace.is_empty():
						terminal_definition_id = int(terminal_trace[-1].get("definition_id", -1))
					boundary_samples.append("%s#%04d DEF%d body=0x%X..0x%X terminal=%s stop=0x%X nested_def=%d resume=0x%X" % [
						str(entry.name),
						int(anchor.index),
						int(definition.get("definition_id", -1)),
						int(definition.get("body_offset", -1)),
						int(definition.get("target_offset", -1)),
						terminal_status,
						int(result.get("offset", -1)),
						terminal_definition_id,
						int(result.get("resume_offset", -1)),
					])
				var metadata: Dictionary = result.get("detached_definition_preview", {})
				if (
					str(result.get("schema", "")) != "kakyu_mes_detached_definition_preview/v5"
					or metadata.get("caller_resume_executed", true)
					or metadata.get("native_result_mapping_executed", true)
					or metadata.get("sandbox_persisted", true)
				):
					failures.append("%s#%04d DEF%d violated detached preview provenance" % [
						str(entry.name), int(anchor.index), int(definition.get("definition_id", -1)),
					])
				if state.snapshot() != state_before:
					failures.append("%s#%04d DEF%d changed the caller sandbox" % [
						str(entry.name), int(anchor.index), int(definition.get("definition_id", -1)),
					])
				if str(result.get("status", "")) == "invalid_definition":
					failures.append("%s#%04d DEF%d failed its bounded-body hash contract" % [
						str(entry.name), int(anchor.index), int(definition.get("definition_id", -1)),
					])
				if samples.size() < SAMPLE_LIMIT:
					samples.append("%s#%04d DEF%d body=0x%X..0x%X terminal=%s messages=%d" % [
						str(entry.name),
						int(anchor.index),
						int(definition.get("definition_id", -1)),
						int(definition.get("body_offset", -1)),
						int(definition.get("target_offset", -1)),
						terminal_status,
						messages.size(),
					])

	var verification_reader := ArcReaderScript.new()
	if not verification_reader.open(archive_path):
		failures.append("source archive could not be reopened after the read-only audit")
	elif verification_reader.get_archive_fingerprint() != source_sha_before:
		failures.append("source archive fingerprint changed during the read-only audit")
	var actual_counts := {
		"entries": entry_count,
		"anchors": anchor_count,
		"selection_boundaries": selection_boundary_count,
		"grouped_selection_boundaries": grouped_selection_boundary_count,
		"multi_group_selection_boundaries": multi_group_selection_boundary_count,
		"nonpresented_group_boundaries": nonpresented_group_boundary_count,
		"nonpresented_group_definitions": nonpresented_group_definition_count,
		"previews": preview_count,
		"unique_bodies": unique_bodies.size(),
		"complete": complete_count,
		"message_previews": previews_with_messages,
		"messages": message_count,
		"traced_steps": traced_steps,
		"source_entries": entry_names.size(),
		"registered_definition_calls": registered_definition_call_count,
	}
	if source_sha_before != AUDITED_ARCHIVE_SHA256:
		failures.append("archive fingerprint is not the audited original mes.arc")
	if actual_counts != AUDITED_COUNTS:
		failures.append("detached DEF corpus counts changed: %s" % str(actual_counts))
	if terminal_counts != AUDITED_TERMINALS:
		failures.append("detached DEF terminal counts changed: %s" % str(terminal_counts))
	print("MES_DETACHED_DEFINITION_CORPUS schema=%s source_sha256=%s entries=%d anchors=%d boundaries=%d grouped_boundaries=%d multi_group_boundaries=%d nonpresented_group_boundaries=%d nonpresented_group_definitions=%d previews=%d unique_bodies=%d complete=%d message_previews=%d messages=%d registered_calls=%d traced_steps=%d terminals=%s" % [
		SCHEMA,
		source_sha_before,
		entry_count,
		anchor_count,
		selection_boundary_count,
		grouped_selection_boundary_count,
		multi_group_selection_boundary_count,
		nonpresented_group_boundary_count,
		nonpresented_group_definition_count,
		preview_count,
		unique_bodies.size(),
		complete_count,
		previews_with_messages,
		message_count,
		registered_definition_call_count,
		traced_steps,
		_format_counts(terminal_counts),
	])
	print("MES_DETACHED_DEFINITION_ENTRIES count=%d" % entry_names.size())
	for sample in samples:
		print("MES_DETACHED_DEFINITION_SAMPLE ", sample)
	for sample in boundary_samples:
		print("MES_DETACHED_DEFINITION_BOUNDARY_SAMPLE ", sample)
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)


func _registered_definitions_for_audit(result: Dictionary) -> Array:
	var definition_groups: Dictionary = result.get("definition_groups", {})
	if definition_groups.is_empty():
		return (result.get("definitions", []) as Array).duplicate(true)
	var definitions: Array = []
	var visited_selectors := {}
	for untyped_selector in result.get("definition_group_order", []):
		var selector := int(untyped_selector)
		if visited_selectors.has(selector) or not definition_groups.has(selector):
			continue
		visited_selectors[selector] = true
		definitions.append_array((definition_groups[selector] as Array).duplicate(true))
	var remaining_selectors: Array = definition_groups.keys()
	remaining_selectors.sort()
	for untyped_selector in remaining_selectors:
		var remaining_selector := int(untyped_selector)
		if visited_selectors.has(remaining_selector):
			continue
		definitions.append_array((definition_groups[remaining_selector] as Array).duplicate(true))
	return definitions


func _format_counts(counts: Dictionary) -> String:
	var labels: Array[String] = []
	var keys: Array = counts.keys()
	keys.sort()
	for key in keys:
		labels.append("%s:%d" % [str(key), int(counts[key])])
	return ",".join(labels) if not labels.is_empty() else "none"
