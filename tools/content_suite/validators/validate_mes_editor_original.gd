extends "res://tools/content_suite/cli_script.gd"

const MesEditorScene := preload("res://tools/content_suite/apps/mes_editor.tscn")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const DEFAULT_ENTRY := "EVENTD03.MES"
const MAX_VALIDATION_MESSAGE_BYTES := 64


func _initialize() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 1 or arguments.size() > 2:
		_fail("Usage: <mes.arc> [entry.MES]")
		return
	var archive_path := ProjectSettings.globalize_path(str(arguments[0]))
	var entry_name := str(arguments[1]).to_upper() if arguments.size() == 2 else DEFAULT_ENTRY
	if not FileAccess.file_exists(archive_path):
		_fail("mes.arc is unavailable.")
		return
	var source_archive_sha := FileAccess.get_sha256(archive_path)
	if source_archive_sha.is_empty():
		_fail("Could not fingerprint mes.arc.")
		return

	var editor: Control = MesEditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	editor.call("_open_archive", archive_path)
	editor.call("_load_entry", entry_name)
	var document: Dictionary = editor.get("_document")
	var analysis: Dictionary = editor.get("_analysis")
	if not document.get("ok", false) or not analysis.get("ok", false):
		editor.queue_free()
		_fail("MES Editor did not parse and analyze the requested original entry.")
		return
	if str(document.get("source", {}).get("resolved_source", "")) != "original_arc":
		editor.queue_free()
		_fail("MES Editor did not resolve the requested entry from the original ARC.")
		return

	var cp932 := Cp932CodecScript.new()
	var selected_message: Dictionary = {}
	var replacement_text := ""
	for untyped_message in analysis.messages:
		var message: Dictionary = untyped_message
		var raw_bytes: PackedByteArray = message.raw_bytes
		if (
			raw_bytes.is_empty()
			or raw_bytes.size() > MAX_VALIDATION_MESSAGE_BYTES
			or raw_bytes.size() % 2 != 0
			or not bool(message.get("native_stream_projection_match", false))
		):
			continue
		var decoded := cp932.decode(raw_bytes)
		if not decoded.ok:
			continue
		for candidate_character in [String.chr(0x3044), String.chr(0x3046), String.chr(0x3048)]:
			var candidate: String = str(candidate_character).repeat(int(raw_bytes.size() / 2))
			if cp932.encode(candidate).data == raw_bytes:
				continue
			var eligibility: Dictionary = editor.get("_mes_text_patcher").validate_native_double_byte_replacement(candidate, raw_bytes.size())
			if eligibility.ok:
				selected_message = message
				replacement_text = candidate
				break
		if not selected_message.is_empty():
			break
	if selected_message.is_empty():
		editor.queue_free()
		_fail("No bounded strict-CP932 message was suitable for UI validation.")
		return

	var message_tree: Tree = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageTree")
	var message_item := _find_message_item(message_tree, int(selected_message.source_offset))
	if message_item == null:
		editor.queue_free()
		_fail("MES Editor did not expose the selected strict message in its Messages table.")
		return
	message_item.select(0)
	editor.call("_on_message_selected")
	var message_edit: LineEdit = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageAuthoring/MessageEdit")
	var binary_label: Label = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/BinaryPatchBar/BinaryPatchLabel")
	var decoded_selected := cp932.decode(selected_message.raw_bytes)
	if message_edit.text != str(decoded_selected.text) or message_item.get_text(2) != str(decoded_selected.text):
		var edit_matches := message_edit.text == str(decoded_selected.text)
		var table_matches := message_item.get_text(2) == str(decoded_selected.text)
		editor.queue_free()
		_fail(
			"MES Editor did not present the selected original message as decoded CP932 text "
			+ "(edit_matches=%s table_matches=%s expected_chars=%d edit_chars=%d table_chars=%d)."
			% [edit_matches, table_matches, str(decoded_selected.text).length(), message_edit.text.length(), message_item.get_text(2).length()]
		)
		return

	message_edit.text = replacement_text + "A"
	editor.call("_on_message_text_changed", message_edit.text)
	var expected_bytes := int(selected_message.raw_bytes.size())
	if not binary_label.text.contains("%d/%d bytes" % [expected_bytes + 1, expected_bytes]) or not binary_label.text.contains("exact length"):
		editor.queue_free()
		_fail("MES Editor live validation did not reject a changed CP932 byte length.")
		return
	message_edit.text = replacement_text
	editor.call("_on_message_text_changed", message_edit.text)
	if not binary_label.text.contains("eligible %d/%d bytes" % [expected_bytes, expected_bytes]):
		editor.queue_free()
		_fail("MES Editor live validation did not accept the equal-length CP932 replacement.")
		return
	editor.call("_on_stage_text_pressed")
	if int(editor.call("_pending_count_total")) != 1:
		editor.queue_free()
		_fail("MES Editor did not retain the selected edit in its in-memory session.")
		return
	var prepared: Dictionary = editor.call("_prepare_binary_patch_batch", true)
	if not prepared.get("ok", false) or int(prepared.get("edit_count", 0)) != 1:
		editor.queue_free()
		_fail("MES Editor did not prepare the equal-length binary patch batch: %s" % str(prepared.get("error", "unknown error")))
		return
	var replacements: Dictionary = prepared.replacements
	var patched: PackedByteArray = replacements.get(entry_name, PackedByteArray())
	if patched.size() != int(document.get("source", {}).get("size", -1)) or str(document.entry_sha256) == ContractValues.sha256(patched):
		editor.queue_free()
		_fail("MES Editor prepared batch did not contain one changed, equal-size entry payload.")
		return

	editor.call("_load_entry", "START.MES")
	var startup_analysis: Dictionary = editor.get("_analysis")
	var resource_tree: Tree = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/References/ResourceReferenceTree")
	if (
		not startup_analysis.get("ok", false)
		or not _has_script_reference_item(resource_tree, startup_analysis, "LIBLARY.LIB", 2, "library_bootstrap")
		or not _has_script_reference_item(resource_tree, startup_analysis, "DEF_MAIN.MES", 3, "definition_bootstrap")
	):
		editor.queue_free()
		_fail("MES Editor did not expose both confirmed START.MES inline script targets.")
		return
	if FileAccess.get_sha256(archive_path) != source_archive_sha:
		editor.queue_free()
		_fail("Source mes.arc changed during MES Editor validation.")
		return

	var message_offset := int(selected_message.source_offset)
	editor.queue_free()
	print(
		"PASS: MES Editor original integration entry=%s message_offset=0x%X bytes=%d display=decoded_cp932 native_boundary=matched live_validation=ok patch=memory_only startup_targets=LIBLARY.LIB,DEF_MAIN.MES source_archive_unchanged"
		% [entry_name, message_offset, expected_bytes]
	)
	quit(0)


func _find_message_item(tree: Tree, source_offset: int) -> TreeItem:
	var root_item := tree.get_root()
	if root_item == null:
		return null
	var item := root_item.get_first_child()
	while item != null:
		if int(item.get_metadata(0)) == source_offset:
			return item
		item = item.get_next()
	return null


func _has_script_reference_item(
	tree: Tree,
	analysis: Dictionary,
	target: String,
	selector: int,
	role: String
) -> bool:
	var root_item := tree.get_root()
	if root_item == null:
		return false
	var item := root_item.get_first_child()
	while item != null:
		if (
			item.get_text(1) == "mes_script"
			and item.get_text(2) == target
			and item.get_text(3).contains("mes.arc")
			and item.get_text(3).contains("archive_entry_load_inline_execute_restore_confirmed")
		):
			# Selector and role are asserted through the row's source reference below;
			# the visible columns keep the target and native execution contract compact.
			for reference in analysis.get("resource_references", []):
				if (
					int(reference.get("source_offset", -1)) == int(item.get_metadata(0))
					and str(reference.get("name", "")) == target
					and int(reference.get("execution_selector", -1)) == selector
					and str(reference.get("execution_role", "")) == role
				):
					return true
		item = item.get_next()
	return false
