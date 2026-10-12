extends "res://tests/test_mes_editor.gd"

const EventPlayerScene := preload("res://tools/content_suite/apps/event_player.tscn")
const ProvenanceReportScript := preload("res://tools/content_suite/provenance_report.gd")
const TestCaseScript := preload("res://tests/test_case.gd")

var original_source_root := ""
var retained_output_root := ""
var message_relocation := false
var condition_literal := false
var resource_name := false
var choice_option := false
var registered_call := false
var shared_call := false
var control_target := false
var sequence := false


func _ready() -> void:
	_cleanup()
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT if retained_output_root.is_empty() else retained_output_root)
	var source_root := absolute_root.path_join("source") if original_source_root.is_empty() else original_source_root
	var entry := "TEST.MES" if original_source_root.is_empty() else "EVENTB03.MES"
	var workspace_root := absolute_root.path_join("authoring_workspace")
	DirAccess.make_dir_recursive_absolute(source_root)
	var arc_path := source_root.path_join("mes.arc")
	var source := "0100000000000000031e0101ff000182a00000".hex_decode()
	if message_relocation:
		source = "0100000000000000031e0101ff000182a0000182a20000".hex_decode()
	elif condition_literal:
		source = "01000000000000000bf3010001efff0f0000000182a00000".hex_decode()
	elif resource_name:
		source = "01000000000000000d09ff017a2e6d6d6f00000182a00000".hex_decode()
	elif choice_option:
		# tests.test_prove_mes_choice_group_authoring._fixture() (two routine-40
		# groups: group 0 definition 0 "FIRST", group 1 definition 0 "SECOND02") as
		# address entry 0, plus a second address entry (five-byte 0x17 label
		# prologue, one CP932 message "あ" = 82a0, one return) so message
		# translation has a candidate outside the choice family.
		source = (
			"02000000000000005000000017000000001b0200ff00100200ff001b0000000146"
			+ "4952535400001b0201ff00100200ff0034000000015345434f4e44303200001d0228ff"
			+ "000b801501ef800d01efe6ff49000000000c4f000000000017010000000182a000"
			+ "00"
		).hex_decode()
	elif registered_call:
		# A registered-definition call (selector 3, command 0x11) over the
		# DEF_MAIN.MES registry payload from
		# tests/test_plan_mes_registered_definition_call_edit.py's
		# MesRegisteredDefinitionCallEditPlanTests.registry_payload(3, 4)
		# (registrations for selectors 3 and 4); one CP932 message; a return.
		source = "0100000000000000110203ff000182a00000".hex_decode()
	elif shared_call:
		# A shared-routine call (routine 3, command 0x1D) over a synthetic
		# LIBLARY.LIB with two return-only routines (3 and 4); one CP932
		# message; a return. Same caller hex as
		# tests/test_mes_authoring_workflow.py's shared_call_fixture().
		source = ("0100000000000000" + "1d0203ff00" + "0182a000" + "00").hex_decode()
	elif control_target:
		# A continuation transfer (command 0x0C) retargeting to the message
		# start; one CP932 message; two returns. Same caller hex as
		# tests/test_mes_authoring_workflow.py's control_target_fixture()'s
		# continuation entry (analysis/mw11_control_target_synthetic_probe.py).
		source = ("0100000000000000" + "0c0a000000" + "0182a000" + "00" + "00").hex_decode()
	elif sequence:
		# MW-11 sequence spec's synthetic entry: nodes at 0
		# global_u8_write_run, 6 continuation_transfer (target 0x10), 11 text
		# "あ", 15/16 command_00 (analysis/mw11_sequence_synthetic_probe.py).
		# Sequence S = [state literal value 2, retarget 16 -> 11,
		# replace_message "変更確認"].
		source = "0100000000000000031e0101ff000c100000000182a0000000".hex_decode()
	if original_source_root.is_empty():
		var entries: Array[Dictionary] = [{"name": entry, "data": source}]
		if registered_call:
			# tests/test_plan_mes_registered_definition_call_edit.py's
			# MesRegisteredDefinitionCallEditPlanTests.registry_payload(3, 4), behind one
			# five-byte source-line marker (so the address entry and both registration
			# targets sit five bytes later than that payload's, and no 8-byte window of
			# the container header is an original one).
			entries.append({"name": "DEF_MAIN.MES", "data": "010000000d0000001f214365071403ff0d0000000017000000001404ff1a0000000000".hex_decode()})
		if shared_call:
			# Two return-only routines (3 and 4): `1C <id> FF <skip u32>` then
			# a one-byte `00` (command 0x00, return) body, the way
			# tests/test_mes_library_index.gd's `_append_registration` builds
			# one; verified empirically (Godot G0 helper audits it with `ok`
			# and Python's shared-call prover proves both routines
			# total-return: tests/test_mes_library_audit_report.gd and this
			# scene's own checks below).
			entries.append({"name": "LIBLARY.LIB", "data": "000000001c03ff08000000001c04ff100000000000".hex_decode()})
		SyntheticArc.write_arc(arc_path, entries)
	else:
		var reader := ArcReaderScript.new()
		_check(reader.open(arc_path), "Open the authoritative MES original read-only")
		source = reader.read_entry(entry)
		reader.close()
	var archive_sha := FileAccess.get_sha256(arc_path)
	var workspace := ContentWorkspaceScript.new()
	var project := _run_workspace_project(archive_sha)
	if not original_source_root.is_empty():
		var content_set := preload("res://content_core/content_set.gd").new()
		_check(content_set.open(source_root), "Inventory the original content set")
		var archives: Array = []
		for archive in content_set.get_archive_names():
			archives.append({"archive": archive, "sha256": content_set.get_reader(archive).get_archive_fingerprint(), "required": true})
		content_set.close()
		archives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.archive) < str(b.archive))
		project.source_content_set.archives = archives
		project.source_content_set.fingerprint_sha256 = ContentProjectScript.compute_content_set_fingerprint(archives)
	var created := workspace.create(workspace_root, source_root, project)
	_check(created.get("ok", false), "Authoring fixture creates a named workspace")
	if not created.get("ok", false):
		print("AUTHORING_WORKSPACE_FAILURE ", created)
		get_tree().quit(1)
		return
	workspace.close()
	var editor: Control = MesEditorScene.instantiate()
	add_child(editor)
	await get_tree().process_frame
	editor._apply_startup_arguments(PackedStringArray(["--content-set", source_root, "--workspace", workspace_root]))
	editor._load_entry(entry)
	var sequence_with_original_root := sequence and not original_source_root.is_empty()
	var first_message: Dictionary = editor._analysis.messages[
		2 if choice_option else (1 if (message_relocation or sequence_with_original_root) else 0)
	]
	var message_offset := int(first_message.source_offset)
	# The synthetic sequence entry's only message is the last step's
	# relocation target, so it stays untranslated here (a translation on it
	# would overlap the structural replacement in `_check_delta_flow`); the
	# original-root sequence mode translates a different message than the
	# one it relocates, so it publishes like every other mode.
	if not sequence or sequence_with_original_root:
		editor._selected_message_offset = message_offset
		editor._populate_message_edit()
		editor.message_edit.text = "편집 흐름 확인"
		editor._on_stage_text_pressed()
		editor._on_overlay_save_selected(workspace_root)
		_check(editor._pending_count_total() == 0, "Authored UTF-8 text is published through editor controls")
		_check(editor._launch_context.get_snapshot().manifest_sha256 == FileAccess.get_sha256(workspace_root.path_join("manifest.json")), "Editor publication refreshes the named workspace generation")
	var panel = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Authoring")
	panel._inspect_button.pressed.emit()
	await _wait_authoring(panel)
	_check(not panel._source_bundle.is_empty() and panel._controls.size() >= 1, "Authoring tab consumes actual Python source handoff and lists a state literal")
	if panel._source_bundle.is_empty():
		print("AUTHORING_DIAGNOSTIC ", panel._summary.text)
		editor.queue_free()
		await get_tree().process_frame
		_cleanup()
		get_tree().quit(1)
		return
	if sequence and not sequence_with_original_root:
		await _run_sequence_flow(editor, panel, source, absolute_root, source_root, workspace_root, first_message)
		editor.queue_free()
		await get_tree().process_frame
		if retained_output_root.is_empty():
			_cleanup()
		get_tree().quit(1 if _failed else 0)
		return
	if sequence_with_original_root:
		await _stage_original_sequence(panel)
		_check(not panel._compiled_bundle.is_empty(), "Original-root sequence preview compiles, reanalyzes and independently reopens actual Python output")
		if panel._compiled_bundle.is_empty():
			print("AUTHORING_DIAGNOSTIC ", panel._summary.text)
			editor.queue_free()
			await get_tree().process_frame
			_cleanup()
			get_tree().quit(1)
			return
	else:
		var selected_item = panel._tree.get_root().get_first_child()
		if message_relocation:
			while selected_item != null and str(panel._controls[int(selected_item.get_metadata(0))].operation.kind) != "replace_message":
				selected_item = selected_item.get_next()
		elif condition_literal:
			while selected_item != null and str(panel._controls[int(selected_item.get_metadata(0))].operation.kind) != "replace_condition_literal":
				selected_item = selected_item.get_next()
		elif resource_name:
			while selected_item != null and str(panel._controls[int(selected_item.get_metadata(0))].operation.kind) != "replace_resource_name":
				selected_item = selected_item.get_next()
		elif choice_option:
			while selected_item != null and str(panel._controls[int(selected_item.get_metadata(0))].operation.kind) != "replace_choice_option_cp932_same_length":
				selected_item = selected_item.get_next()
		elif registered_call:
			while selected_item != null and str(panel._controls[int(selected_item.get_metadata(0))].operation.kind) != "replace_registered_definition_literal":
				selected_item = selected_item.get_next()
		elif shared_call:
			while selected_item != null and str(panel._controls[int(selected_item.get_metadata(0))].operation.kind) != "replace_shared_routine_literal":
				selected_item = selected_item.get_next()
		elif control_target:
			while selected_item != null and str(panel._controls[int(selected_item.get_metadata(0))].operation.kind) != "retarget_control_flow":
				selected_item = selected_item.get_next()
		selected_item.select(0)
		if message_relocation:
			panel._text.text = "変更確認"
		elif resource_name:
			panel._text.text = "b04.mmo" if not original_source_root.is_empty() else "x.mmo"
		elif choice_option:
			panel._text.text = "OTHER"
		elif registered_call:
			panel._value.value = 4
		elif shared_call:
			panel._value.value = 4
		elif control_target:
			panel._value.value = 5
		else:
			panel._value.value = 2
		if message_relocation and original_source_root.is_empty():
			panel._compile_button.pressed.emit()
			panel._text.text = "別変更確認"
			await _wait_authoring(panel)
			_check(panel._compiled_bundle.is_empty() and panel._publish_button.disabled, "A draft changed during background compilation cannot publish the old preview")
			panel._text.text = "変更確認"
		panel._compile_button.pressed.emit()
		await _wait_authoring(panel)
		_check(not panel._compiled_bundle.is_empty(), "State preview compiles, reanalyzes and independently reopens actual Python output")
		if panel._compiled_bundle.is_empty():
			print("AUTHORING_DIAGNOSTIC ", panel._summary.text)
			editor.queue_free()
			await get_tree().process_frame
			_cleanup()
			get_tree().quit(1)
			return
		if condition_literal:
			_check(str(panel._compiled_bundle.audit.get("schema", "")) == "kakyu_mes_condition_literal_compile_audit/v1", "Condition literal compile audit uses the condition compile-audit schema")
			var condition_validated: Dictionary = panel.SessionScript.validate_source(panel._compiled_bundle, source)
			_check(condition_validated.get("ok", false), "Condition literal source validates against the compile audit")
			var literal_start := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.target.literal_start)
			var literal_end := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.target.literal_end)
			_check(_sha256(source.slice(literal_start, literal_end)) == str(panel._compiled_bundle.audit.target.source_literal_sha256), "Source slice named by the literal bounds hashes to the audit's source literal hash")
			var condition_output: PackedByteArray = panel._compiled_bundle.files["output.mes"]
			var condition_diff_count := 0
			for byte_index in range(source.size()):
				if source[byte_index] != condition_output[byte_index]:
					condition_diff_count += 1
			_check(condition_diff_count == 1, "The compiled output differs from the source in exactly one byte")
		elif resource_name:
			_check(str(panel._compiled_bundle.audit.get("schema", "")) == "kakyu_mes_resource_name_compile_audit/v1", "Resource name compile audit uses the resource compile-audit schema")
			var resource_validated: Dictionary = panel.SessionScript.validate_source(panel._compiled_bundle, source)
			_check(resource_validated.get("ok", false), "Resource name source validates against the compile audit")
			var name_start := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.target.name_start)
			var name_end := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.target.name_end)
			_check(_sha256(source.slice(name_start, name_end)) == str(panel._compiled_bundle.audit.target.source_name_sha256), "Source slice named by the name bounds hashes to the audit's source name hash")
			var resource_output: PackedByteArray = panel._compiled_bundle.files["output.mes"]
			var resource_diff_count := 0
			for byte_index in range(source.size()):
				if source[byte_index] != resource_output[byte_index]:
					resource_diff_count += 1
			_check(resource_diff_count == 1, "The compiled output differs from the source in exactly one byte")
		elif choice_option:
			_check(str(panel._compiled_bundle.audit.get("schema", "")) == "kakyu_mes_choice_option_compile_audit/v1", "Choice option compile audit uses the choice compile-audit schema")
			var choice_validated: Dictionary = panel.SessionScript.validate_source(panel._compiled_bundle, source)
			_check(choice_validated.get("ok", false), "Choice option source validates against the compile audit")
			var patch_start := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.patch.code_start)
			var patch_end := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.patch.code_end)
			_check(_sha256(source.slice(patch_start, patch_end)) == str(panel._compiled_bundle.audit.patch.source_payload_sha256), "Source slice named by the patch bounds hashes to the audit's source payload hash")
			var choice_output: PackedByteArray = panel._compiled_bundle.files["output.mes"]
			var choice_diff_count := 0
			var choice_diff_in_range := true
			for byte_index in range(source.size()):
				if source[byte_index] != choice_output[byte_index]:
					choice_diff_count += 1
					if byte_index < patch_start or byte_index >= patch_end:
						choice_diff_in_range = false
			_check(choice_diff_count > 0 and choice_diff_in_range, "Every differing byte between output and source lies inside the patched payload range")
		elif registered_call:
			_check(str(panel._compiled_bundle.audit.get("schema", "")) == "kakyu_mes_registered_definition_call_compile_audit/v1", "Registered-definition call compile audit uses the registered-call compile-audit schema")
			var call_validated: Dictionary = panel.SessionScript.validate_source(panel._compiled_bundle, source)
			_check(call_validated.get("ok", false), "Registered-definition call source validates against the compile audit")
			var call_literal_start := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.target.literal_start)
			var call_literal_end := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.target.literal_end)
			_check(_sha256(source.slice(call_literal_start, call_literal_end)) == str(panel._compiled_bundle.audit.target.source_literal_sha256), "Source slice named by the literal bounds hashes to the audit's source literal hash")
			var call_output: PackedByteArray = panel._compiled_bundle.files["output.mes"]
			var call_diff_count := 0
			for byte_index in range(source.size()):
				if source[byte_index] != call_output[byte_index]:
					call_diff_count += 1
			_check(call_diff_count == 1, "The compiled output differs from the source in exactly one byte")
		elif shared_call:
			_check(str(panel._compiled_bundle.audit.get("schema", "")) == "kakyu_mes_shared_routine_call_compile_audit/v1", "Shared-routine call compile audit uses the shared-routine-call compile-audit schema")
			var shared_validated: Dictionary = panel.SessionScript.validate_source(panel._compiled_bundle, source)
			_check(shared_validated.get("ok", false), "Shared-routine call source validates against the compile audit")
			var shared_literal_start := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.target.literal_start)
			var shared_literal_end := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.target.literal_end)
			_check(_sha256(source.slice(shared_literal_start, shared_literal_end)) == str(panel._compiled_bundle.audit.target.source_literal_sha256), "Source slice named by the literal bounds hashes to the audit's source literal hash")
			var shared_output: PackedByteArray = panel._compiled_bundle.files["output.mes"]
			var shared_diff_count := 0
			for byte_index in range(source.size()):
				if source[byte_index] != shared_output[byte_index]:
					shared_diff_count += 1
			_check(shared_diff_count == 1, "The compiled output differs from the source in exactly one byte")
		elif control_target:
			_check(str(panel._compiled_bundle.audit.get("schema", "")) == "kakyu_mes_control_target_edit_compile_audit/v1", "Control-target edit compile audit uses the control-target compile-audit schema")
			var control_target_validated: Dictionary = panel.SessionScript.validate_source(panel._compiled_bundle, source)
			_check(control_target_validated.get("ok", false), "Control-target edit source validates against the compile audit")
			var control_target_start := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.source_control.instruction_start)
			var control_target_end := int(panel._compiled_bundle.audit.source.code_offset) + int(panel._compiled_bundle.audit.source_control.instruction_end)
			_check(_sha256(source.slice(control_target_start, control_target_end)) == str(panel._compiled_bundle.audit.source_control.source_instruction_sha256), "Source slice named by the instruction bounds hashes to the audit's source instruction hash")
			var control_target_output: PackedByteArray = panel._compiled_bundle.files["output.mes"]
			var control_target_diff_count := 0
			for byte_index in range(source.size()):
				if source[byte_index] != control_target_output[byte_index]:
					control_target_diff_count += 1
			_check(control_target_diff_count == 1, "The compiled output differs from the source in exactly one byte")
	var original_context: Dictionary = panel._context.duplicate(true)
	var bundle: Dictionary = panel._compiled_bundle.duplicate(true)
	var altered: Dictionary = bundle.duplicate(true)
	altered.files["output.mes"][altered.files["output.mes"].size() - 1] = 0xFF
	if altered.has("steps"):
		var altered_last_step: Dictionary = altered.steps[altered.steps.size() - 1]
		altered_last_step.output[altered_last_step.output.size() - 1] = 0xFF
	_check(not panel.SessionScript.validate_source(altered, source).get("ok", false), "Authored publication rejects unrelated output-byte changes")
	var coordinate_binding := {}
	var output_message_offset := message_offset
	if message_relocation:
		coordinate_binding = panel.SessionScript.validate_source(bundle, source)
		if not coordinate_binding.get("ok", false):
			print("COORDINATE_BINDING_FAILURE ", coordinate_binding)
		output_message_offset = panel.SessionScript.BindingScript.mapped_offset(coordinate_binding, message_offset)
		_check(coordinate_binding.get("ok", false) and output_message_offset == message_offset + 6, "Relocation maps the later translation by the exact six-byte delta")
		var overlap := {int(bundle.audit.operation.source_offset): {"raw_sha256": str(bundle.audit.operation.source_raw_sha256), "text": "겹침"}}
		_check(not panel.SessionScript.BindingScript.map_text(overlap, coordinate_binding).get("ok", false), "Relocation rejects an existing translation over the replaced message")
	elif sequence_with_original_root:
		coordinate_binding = panel.SessionScript.validate_source(bundle, source)
		if not coordinate_binding.get("ok", false):
			print("COORDINATE_BINDING_FAILURE ", coordinate_binding)
		output_message_offset = panel.SessionScript.BindingScript.mapped_offset(coordinate_binding, message_offset)
		_check(coordinate_binding.get("ok", false) and output_message_offset == message_offset + 6, "Sequence relocation maps the later translation by the exact six-byte delta")
	panel._publish_button.pressed.emit()
	if editor._document.entry_sha256 != bundle.audit.output.entry_sha256:
		print("AUTHORING_PUBLICATION_FAILURE ", panel._summary.text)
	_check(editor._document.entry_sha256 == bundle.audit.output.entry_sha256, "Publish activates the exact compiled MES")
	_check_provenance_report_links_bundle(workspace_root, source_root, bundle)
	_check(editor._authoring_proof_path == str(bundle.directory).path_join("semantic.diff.json"), "Publish retains the proof for automatic Run")
	_check(editor._projection_for_message(editor._message_record_at(output_message_offset)).get("text") == "편집 흐름 확인", "Structural publication preserves the UTF-8 translation at its effective coordinate")
	if message_relocation or sequence_with_original_root:
		editor._load_entry(entry)
		_check(editor._projection_for_message(editor._message_record_at(output_message_offset)).get("text") == "편집 흐름 확인", "Reopening discovers exact local evidence and restores translated coordinates")
	_check(not editor._publish_authored_bundle(bundle, original_context).get("ok", false), "Stale structural publication is refused after workspace generation advances")
	var request_path := workspace_root.path_join("changed.run.json")
	var launch := {}
	if not original_source_root.is_empty():
		var options: Array[Dictionary] = editor._contextual_run_options()
		# EP-10 unit 5bc: the row count is whatever the catalog names for this
		# callee now (17 presets on the generated row, not the four the old
		# hand row carried), so re-pin against the catalog instead of a literal.
		var expected_preset_count := 0
		var preset_catalog := preload("res://content_core/event_catalog.gd").new()
		if preset_catalog.load_file("res://config/event_catalog/original_events_v1.json").get("ok", false):
			for event in preset_catalog.get_events():
				if str(event.source.callee.entry).to_upper() == entry.to_upper():
					expected_preset_count += (event.get("presets", []) as Array).size()
		_check(
			expected_preset_count > 0 and options.size() == expected_preset_count,
			"The original event exposes every catalog preset of its rows"
		)
		if not options.is_empty():
			launch = options[0]
	var prepared: Dictionary = editor._publish_run_request(request_path, "code_offset", 0, bundle.proof, launch)
	_check(not prepared.get("ok", false), "Editor Run refuses to publish a changed entry; Run opens original entries only")
	var player: KakyuEventPlayer = EventPlayerScene.instantiate()
	add_child(player)
	await get_tree().process_frame
	player._apply_startup_arguments(PackedStringArray(["--content-set", source_root, "--workspace", workspace_root]))
	var run: Dictionary = player._consume_run_request(request_path, editor._authoring_proof_path)
	_check(not run.get("ok", false), "Event Player refuses to consume a changed-entry Run request; Run opens original entries only")
	if not original_source_root.is_empty():
		var binder := preload("res://tools/content_suite/mes_contextual_run.gd").new()
		_check(not binder.bind_state_edit(source, altered.files["output.mes"], bundle.proof).get("ok", false), "Contextual Run rejects unrelated output changes")
		# EP-08: Event Player no longer hosts the contextual-run engine, so this
		# proof now drives content_core/event_catalog.gd + mes_contextual_run.gd
		# directly on the editor's own reader/resolver (which retain the
		# workspace overlay), the way the deleted _consume_contextual_run and
		# _build_catalog_run_play_request(request, snapshot, true) did.
		var catalog: KakyuEventCatalog = player._event_catalog
		var catalog_play := catalog.build_play_request(str(launch.event_id), str(launch.preset_id))
		_check(
			catalog_play.get("ok", false)
			and str(catalog_play.get("callee", {}).get("entry_sha256", "")) == _sha256(source),
			"Event Catalog binds the edited entry's callee to its exact original hash"
		)
		var proof_value = JSON.parse_string(FileAccess.get_file_as_string(editor._authoring_proof_path))
		var expected_state_632 := 1 if (message_relocation or resource_name) else 2
		var verified: Dictionary = binder.run(editor._reader, editor._resolver, catalog, catalog_play, proof_value, bundle if sequence_with_original_root else {})
		_check(verified.get("ok", false), "Contextual Run engine verifies the edited EVENTB03 route on the editor's own reader and resolver")
		if verified.get("ok", false):
			_check(verified.get("complete", false), "Changed original EVENTB03 reaches a catalog terminal with its exact required state")
			_check(verified.probe.state_object.read_value("global_u8", 632) == expected_state_632, "Original EVENTB03 contextual execution retains the expected state value")
			_check(str(verified.get("terminal_match", {}).get("next_target", "")) == "MACHI.MES", "Original completion target comes from the confirmed catalog terminal")
			_check(verified.binding.get("caller_executed") == false and (verified.binding.get("points", []) as Array).size() == 5, "Contextual Run audits the original caller and binds all five relevant control points")
			if message_relocation:
				_check(str(verified.binding.get("schema", "")) == "kakyu_mes_contextual_run_binding/v2", "Relocation uses the versioned contextual coordinate policy")
				for point in verified.binding.points:
					_check(int(point.output) == int(point.source) + (0 if str(point.role) == "start" else 6), "Every callee choice and terminal is relocated")
			elif sequence_with_original_root:
				_check(str(verified.binding.get("schema", "")) == "kakyu_mes_contextual_run_binding/v3", "Sequence relocation uses the versioned chained contextual coordinate policy")
				_check(str(verified.binding.get("coordinate_policy", "")) == "chained_same_size_then_relocation", "Sequence binding records the chained-then-relocated coordinate policy")
				_check(int(verified.binding.get("step_count", -1)) == 2, "Sequence binding records the two-step chain length")
				_check(str(verified.binding.get("chain_proof_sha256", "")) == str(bundle.proof.payload_sha256), "Sequence binding's chain proof hash matches the bundle's chain proof")
				for point in verified.binding.points:
					_check(int(point.output) == int(point.source) + (0 if str(point.role) == "start" else 6), "Every callee choice and terminal is relocated by the sequence")
			var projection := OverlayPackageScript.new().load_mes_text_projection(workspace_root, "mes.arc", entry, archive_sha, _sha256(source))
			var mapped_text: Dictionary = projection
			var verified_coordinate_binding: Dictionary = verified.get("coordinate_binding", {})
			if projection.get("ok", false) and not verified_coordinate_binding.is_empty():
				mapped_text = preload("res://tools/content_suite/mes_authoring_binding.gd").map_text(projection.messages, verified_coordinate_binding)
			_check(
				mapped_text.get("ok", false) and str(mapped_text.get("messages", {}).get(output_message_offset, {}).get("text", "")) == "편집 흐름 확인",
				"Contextual Run resolves authored UTF-8 message text"
			)
			print("CONTEXTUAL_AUTHORING_RESULT ", JSON.stringify({
				"ok": verified.get("ok", false),
				"complete": verified.get("complete", false),
				"status": "contextual_complete" if verified.get("complete", false) else "contextual_boundary",
				"message_count": (verified.get("probe", {}).get("messages", []) as Array).size(),
				"terminal_next_target": str(verified.get("terminal_match", {}).get("next_target", "")),
			}))
		var exporter := preload("res://tools/content_suite/workspace_playback_export.gd").new()
		var built := exporter.build_workspace(source_root, workspace_root, [launch.event_id], {entry: (bundle if sequence_with_original_root else bundle.proof)})
		_check(built.get("ok", false), "Workspace export consumes the changed MES and UTF-8 overlay")
		if resource_name:
			var packaged_effective: PackedByteArray = exporter._effective.get(entry, PackedByteArray())
			var name_patch_start := int(bundle.audit.source.code_offset) + int(bundle.audit.target.name_start)
			var name_patch_end := int(bundle.audit.source.code_offset) + int(bundle.audit.target.name_end)
			var resource_byte_diff_count := 0
			var resource_diff_in_range := true
			for byte_index in range(min(source.size(), packaged_effective.size())):
				if source[byte_index] != packaged_effective[byte_index]:
					resource_byte_diff_count += 1
					if byte_index < name_patch_start or byte_index >= name_patch_end:
						resource_diff_in_range = false
			_check(
				source.size() == packaged_effective.size() and resource_byte_diff_count > 0
				and resource_diff_in_range and (name_patch_end - name_patch_start) == 7,
				"The packaged callee bytes differ from the original only within the seven-byte name field"
			)
		if not built.get("ok", false):
			print("WORKSPACE_EXPORT_FAILURE ", built)
		else:
			var serialized := exporter.serialize(built)
			var output_root := absolute_root.path_join("authored_playback")
			var written := exporter.write(output_root, serialized)
			_check(written.get("ok", false), "Authored workspace package stages, reopens and publishes")
			if not written.get("ok", false):
				print("WORKSPACE_EXPORT_FAILURE ", written, " serialized=", serialized)
			else:
				var package := preload("res://content_core/playback_package.gd").new()
				_check(package.load_directory(output_root).get("ok", false), "Authored package reopens without an original ARC input")
				_check(package.text_strings(entry).has("편집 흐름 확인"), "Package stores authored Korean as UTF-8 without CP932 conversion loss")
				var probe := preload("res://content_core/mes_route_probe.gd").new()
				var packaged := probe.run_route(probe.context_from_package(package), package.manifest().events[0])
				_check(packaged.state_object.read_value("global_u8", 632) == expected_state_632 and packaged.terminal.target == "MACHI.MES", "Archive-free package execution retains expected state and terminal")
				if message_relocation or sequence_with_original_root:
					_check(int(packaged.terminal.offset) == 7100, "Archive-free package reaches the relocated terminal at 7100")
				if message_relocation:
					var bad_coordinates: Dictionary = serialized.manifest.duplicate(true)
					bad_coordinates.events[0].choices[0].boundary_offset -= 6
					var coordinate_integrity := preload("res://content_core/playback_package_integrity.gd").new()
					bad_coordinates.package_sha256 = coordinate_integrity.fingerprint(bad_coordinates)
					_check(not coordinate_integrity.manifest_error(bad_coordinates).is_empty(), "Rehashed package rejects original coordinates attached to relocated records")
				elif sequence_with_original_root:
					var altered_policy_manifest: Dictionary = serialized.manifest.duplicate(true)
					altered_policy_manifest.workspace_binding.contextual_runs[0].coordinate_policy = "chained_bogus_policy"
					altered_policy_manifest.workspace_binding.contextual_runs[0].payload_sha256 = preload("res://content_core/mes_payload_fingerprint.gd").new().fingerprint(altered_policy_manifest.workspace_binding.contextual_runs[0])
					var policy_integrity := preload("res://content_core/playback_package_integrity.gd").new()
					altered_policy_manifest.package_sha256 = policy_integrity.fingerprint(altered_policy_manifest)
					_check(not policy_integrity.manifest_error(altered_policy_manifest).is_empty(), "Rehashed package rejects an altered v3 coordinate policy")
					var altered_chain_manifest: Dictionary = serialized.manifest.duplicate(true)
					altered_chain_manifest.workspace_binding.contextual_runs[0].chain_proof_sha256 = "not-a-sha256"
					altered_chain_manifest.workspace_binding.contextual_runs[0].payload_sha256 = preload("res://content_core/mes_payload_fingerprint.gd").new().fingerprint(altered_chain_manifest.workspace_binding.contextual_runs[0])
					var chain_integrity := preload("res://content_core/playback_package_integrity.gd").new()
					altered_chain_manifest.package_sha256 = chain_integrity.fingerprint(altered_chain_manifest)
					_check(not chain_integrity.manifest_error(altered_chain_manifest).is_empty(), "Rehashed package rejects an altered v3 chain proof hash")
				_check(not package.manifest().workspace_binding.standalone_complete and package.manifest().workspace_binding.incompleteness.media_extraction == "deferred", "Script/text export declares deferred media and local-only content")
				var changed_manifest: Dictionary = serialized.manifest.duplicate(true)
				changed_manifest.workspace_binding.members[0].effective_entry_sha256 = "0".repeat(64)
				var integrity := preload("res://content_core/playback_package_integrity.gd").new()
				changed_manifest.package_sha256 = integrity.fingerprint(changed_manifest)
				_check(not integrity.manifest_error(changed_manifest).is_empty(), "Rehashed workspace package still rejects mismatched effective member bindings")
	if not original_source_root.is_empty() or registered_call or shared_call or control_target:
		_check_delta_flow(absolute_root, source_root, workspace_root, bundle, first_message)
	_check(FileAccess.get_sha256(arc_path) == archive_sha, "The complete authoring flow leaves the original ARC unchanged")
	for size in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		get_window().size = size
		await get_tree().process_frame
		_check(_controls_fit(editor), "Authoring controls fit %dx%d" % [size.x, size.y])
	player.queue_free()
	editor.queue_free()
	await get_tree().process_frame
	if retained_output_root.is_empty():
		_cleanup()
	get_tree().quit(1 if _failed else 0)


func _select_candidate_kind(panel: Node, kind: String) -> void:
	var item = panel._tree.get_root().get_first_child()
	while item != null and str(panel._controls[int(item.get_metadata(0))].operation.kind) != kind:
		item = item.get_next()
	_check(item != null, "A %s candidate exists to stage" % kind)
	if item != null:
		item.select(0)


func _run_sequence_flow(editor: Control, panel: Node, source: PackedByteArray, root: String, source_root: String, workspace_root: String, first_message: Dictionary) -> void:
	_select_candidate_kind(panel, "replace_state_write_literal")
	panel._value.value = 2
	panel._add_button.pressed.emit()
	_select_candidate_kind(panel, "retarget_control_flow")
	panel._value.value = 11
	panel._add_button.pressed.emit()
	_select_candidate_kind(panel, "replace_message")
	panel._text.text = "変更確認"
	panel._add_button.pressed.emit()
	_check(panel._staged.size() == 3, "Three operations are staged in order")
	_check(panel._sequence_items.size() == 3, "The proposed-operation tree lists three rows")
	if panel._sequence_items.size() == 3:
		_check(panel._sequence_items[0].get_text(1) == "0x0" and panel._sequence_items[0].get_text(2) == "State literal", "Row 1 names the state literal's offset and kind")
		_check(panel._sequence_items[1].get_text(1) == "0x6" and panel._sequence_items[1].get_text(2) == "Control target", "Row 2 names the control target's offset and kind")
		_check(panel._sequence_items[2].get_text(1) == "0xB" and panel._sequence_items[2].get_text(2) == "CP932 message", "Row 3 names the message's offset and kind")
	panel._compile_button.pressed.emit()
	await _wait_authoring(panel)
	_check(not panel._compiled_bundle.is_empty(), "Sequence preview compiles, reanalyzes and independently reopens actual Python output")
	if panel._compiled_bundle.is_empty():
		print("AUTHORING_DIAGNOSTIC ", panel._summary.text)
		return
	_check(int(panel._compiled_bundle.manifest.summary.step_count) == 3, "The compiled bundle summary reports three chained steps")
	_check(str(panel._compiled_bundle.proof.get("schema", "")) == "kakyu_mes_semantic_diff_chain/v1", "The bundle's top-level proof is the chain schema")
	var validated: Dictionary = panel.SessionScript.validate_source(panel._compiled_bundle, source)
	_check(validated.get("ok", false) and validated.has("points"), "validate_source returns a relocation binding for the staged sequence")
	var output: PackedByteArray = panel._compiled_bundle.files["output.mes"]
	_check(output.size() == source.size() + 6, "The final output is six bytes longer than the source")
	var bundle: Dictionary = panel._compiled_bundle.duplicate(true)
	panel._publish_button.pressed.emit()
	_check(editor._document.entry_sha256 == bundle.audit.output.entry_sha256, "Publish activates the exact compiled MES")
	_check_provenance_report_links_bundle(workspace_root, source_root, bundle)
	_check_delta_flow(root, source_root, workspace_root, bundle, first_message)


func _stage_original_sequence(panel: Node) -> void:
	_select_candidate_kind(panel, "replace_state_write_literal")
	panel._value.value = 2
	panel._add_button.pressed.emit()
	_select_candidate_kind(panel, "replace_message")
	panel._text.text = "変更確認"
	panel._add_button.pressed.emit()
	_check(panel._staged.size() == 2, "Two operations are staged for the original-root sequence")
	panel._compile_button.pressed.emit()
	await _wait_authoring(panel)


func _check_provenance_report_links_bundle(workspace_root: String, source_root: String, bundle: Dictionary) -> void:
	var built := ProvenanceReportScript.build(workspace_root, source_root)
	_check(built.get("ok", false), "Provenance report builds after the structural publication")
	if not built.get("ok", false):
		return
	var linked := {}
	for untyped_row in built.report.replacements:
		var row: Dictionary = untyped_row
		if str(row.replacement_sha256) == str(bundle.audit.output.entry_sha256):
			linked = row
			break
	_check(
		not linked.is_empty() and linked.authoring != null
		and int(linked.authoring.step_count) == int(bundle.manifest.summary.step_count)
		and str(linked.authoring.proof_schema) == str(bundle.proof.schema),
		"Provenance report links the published authoring bundle to its replacement"
	)


func _check_delta_flow(root: String, source_root: String, workspace_root: String, bundle: Dictionary, message: Dictionary) -> void:
	# The sequence entry's only message is structurally relocated by the
	# staged sequence itself, so its delta carries no overlapping translation.
	var edits: Array = [] if sequence else [{"source_offset": int(message.source_offset), "raw_sha256": OverlayPackageScript.sha256_bytes(message.raw_bytes), "text": "편집 흐름 확인"}]
	var edits_path := root.path_join("authored-text-edits.json")
	var edits_file := FileAccess.open(edits_path, FileAccess.WRITE)
	edits_file.store_string(JSON.stringify(edits))
	edits_file.close()
	var delta_path := root.path_join("authored-event.delta.json")
	var output: Array = []
	var python := preload("res://tools/content_suite/validation_session.gd").find_python()
	var exit_code := OS.execute(python, PackedStringArray([
		ProjectSettings.globalize_path("res://tools/authored_mod_delta.py"), "build",
		source_root.path_join("mes.arc"), bundle.directory, edits_path, delta_path]), output, true, false)
	_check(exit_code == 0, "Distributable delta contains only authored operations/text and source hashes")
	if exit_code != 0:
		print("DELTA_BUILD_FAILURE ", output)
		return
	if sequence:
		var built_delta = JSON.parse_string(FileAccess.get_file_as_string(delta_path))
		var expected_operation_count := 3 if original_source_root.is_empty() else 2
		_check(built_delta is Dictionary and (built_delta.get("operations", []) as Array).size() == expected_operation_count, "The sequence delta carries all %d ordered operations" % expected_operation_count)
	var imported_root := root.path_join("delta_workspace")
	var importer := preload("res://tools/content_suite/authored_delta_import.gd").new()
	var imported := importer.import_delta(source_root, workspace_root, delta_path, imported_root)
	_check(imported.get("ok", false), "Delta reconstructs the exact state edit and translation in a new named workspace")
	if not imported.get("ok", false):
		print("DELTA_IMPORT_FAILURE ", imported)
		return
	_check(not importer.import_delta(source_root, workspace_root, delta_path, imported_root).get("ok", false), "Delta import preserves an existing destination")
	var workspace := ContentWorkspaceScript.new()
	_check(workspace.open(imported_root, source_root).get("ok", false), "Published delta workspace reopens with matching originals")
	workspace.close()
	var resolver := preload("res://content_core/content_resolver.gd").new()
	resolver.register_original_archive("mes.arc", source_root.path_join("mes.arc"))
	resolver.configure_overlay(imported_root)
	var entry := str(bundle.proof.source_identity.entry)
	_check(OverlayPackageScript.sha256_bytes(resolver.read_resolved(resolver.resolve("mes.arc", entry))) == str(bundle.proof.output_binding.entry_sha256), "Imported delta reproduces the authored effective MES hash")
	resolver.close()
	if not sequence:
		var projection := OverlayPackageScript.new().load_mes_text_projection(imported_root, "mes.arc", entry,
			str(bundle.proof.source_identity.archive_sha256), str(bundle.manifest.summary.source_entry_sha256))
		_check(projection.get("ok", false) and projection.get("messages", {}).get(int(message.source_offset), {}).get("text") == "편집 흐름 확인", "Imported delta reproduces the authored UTF-8 translation")
	if message_relocation:
		var reopened_editor: Control = MesEditorScene.instantiate()
		add_child(reopened_editor)
		reopened_editor._apply_startup_arguments(PackedStringArray(["--content-set", source_root, "--workspace", imported_root]))
		reopened_editor._load_entry(entry)
		_check(reopened_editor._projection_for_message(reopened_editor._message_record_at(int(message.source_offset) + 6)).get("text") == "편집 흐름 확인", "A fresh editor maps imported translations from the reconstructed local proof")
		reopened_editor.queue_free()


func _wait_authoring(panel: Node) -> void:
	var started := Time.get_ticks_msec()
	var deadline := started + TestCaseScript.AUTHORING_HANG_GUARD_SECONDS * 1000
	while panel.session.is_running() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().process_frame
	var note: String = TestCaseScript.authoring_wait_note(started)
	var label := "Authoring background process completes within its test deadline"
	if panel.session.is_running():
		_check(false, "%s (still running: %s)" % [label, note])
		return
	print("AUTHORING_WAIT ", note)
	_check(true, label)
