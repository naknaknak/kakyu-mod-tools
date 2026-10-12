extends VBoxContainer

const SessionScript := preload("res://tools/content_suite/mes_authoring_session.gd")

var context_provider: Callable
var publish_output: Callable
var session := SessionScript.new()
var _context: Dictionary = {}
var _source_bundle: Dictionary = {}
var _compiled_bundle: Dictionary = {}
var _pending_operation: Dictionary = {}
var _pending_sequence: Array = []
var _staged: Array = []
var _sequence_items: Array = []
var _controls: Array = []
var _tree: Tree
var _sequence_tree: Tree
var _value: SpinBox
var _text: TextEdit
var _inspect_button: Button
var _compile_button: Button
var _publish_button: Button
var _add_button: Button
var _remove_button: Button
var _clear_button: Button
var _summary: RichTextLabel


func _ready() -> void:
	var toolbar := HFlowContainer.new()
	add_child(toolbar)
	_inspect_button = _button(toolbar, "Analyze selected entry", _inspect)
	_compile_button = _button(toolbar, "Preview change", _compile)
	_publish_button = _button(toolbar, "Publish to workspace", _publish)
	_tree = Tree.new()
	_tree.columns = 4
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size.y = 100
	for index in range(4):
		_tree.set_column_title(index, ["Code offset", "Edit kind", "Index / bytes", "Current value"][index])
	_tree.item_selected.connect(_select)
	add_child(_tree)
	var sequence_toolbar := HFlowContainer.new()
	add_child(sequence_toolbar)
	_add_button = _button(sequence_toolbar, "Add to list", _add_to_list)
	_remove_button = _button(sequence_toolbar, "Remove selected", _remove_selected_from_list)
	_clear_button = _button(sequence_toolbar, "Clear list", _clear_list)
	_sequence_tree = Tree.new()
	_sequence_tree.columns = 5
	_sequence_tree.column_titles_visible = true
	_sequence_tree.hide_root = true
	_sequence_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sequence_tree.custom_minimum_size.y = 90
	for index in range(5):
		_sequence_tree.set_column_title(index, ["Step", "Code offset", "Edit kind", "Change", "Status"][index])
	_sequence_tree.item_selected.connect(func() -> void: _sync())
	add_child(_sequence_tree)
	var row := HBoxContainer.new()
	add_child(row)
	var label := Label.new()
	label.text = "New value"
	row.add_child(label)
	_value = SpinBox.new()
	_value.min_value = -2147483648
	_value.max_value = 4294967295
	_value.allow_greater = false
	_value.allow_lesser = false
	_value.custom_minimum_size.x = 170
	_value.value_changed.connect(func(_number: float) -> void:
		_compiled_bundle.clear()
		_sync()
	)
	row.add_child(_value)
	_text = TextEdit.new()
	_text.custom_minimum_size.y = 75
	_text.placeholder_text = "Replacement CP932 message; use full-width characters and a different byte length."
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.text_changed.connect(func() -> void:
		_compiled_bundle.clear()
		_sync()
	)
	add_child(_text)
	_summary = RichTextLabel.new()
	_summary.custom_minimum_size.y = 105
	_summary.text = "Analyze the original entry, select a state literal, a same-width condition literal, a same-length resource name, a same-length grouped choice option, a same-width registered-definition call selector, a same-width shared routine call selector, a control target or a variable-length CP932 message, preview, then publish. Add several edits to the proposed-operations list below to compile them as one ordered sequence (a message relocation, if staged, must end the list). Korean and other Unicode translations use the message translation controls."
	_summary.selection_enabled = true
	add_child(_summary)
	_sync()


func _process(_delta: float) -> void:
	if not session.is_running():
		return
	var completed := session.poll()
	if not completed.get("finished", false):
		return
	var result: Dictionary = completed.result
	if not result.get("ok", false):
		var error_text := str(result.get("error", "Authoring failed."))
		_summary.text = error_text
		if not _pending_sequence.is_empty():
			_mark_failed_step(error_text)
	elif not _context_is_current():
		_summary.text = "The selected entry or workspace changed. Analyze again before publishing."
	elif str(completed.request.command) == "inspect":
		_source_bundle = result
		_controls = result.manifest.summary.get("state_controls", []).duplicate(true)
		_controls.append_array(result.manifest.summary.get("message_controls", []).duplicate(true))
		_controls.append_array(result.manifest.summary.get("condition_controls", []).duplicate(true))
		_controls.append_array(result.manifest.summary.get("resource_controls", []).duplicate(true))
		_controls.append_array(result.manifest.summary.get("choice_controls", []).duplicate(true))
		_controls.append_array(result.manifest.summary.get("call_controls", []).duplicate(true))
		_controls.append_array(result.manifest.summary.get("shared_call_controls", []).duplicate(true))
		_controls.append_array(result.manifest.summary.get("control_target_controls", []).duplicate(true))
		_tree.clear()
		var root := _tree.create_item()
		for index in range(_controls.size()):
			var control: Dictionary = _controls[index]
			var item := _tree.create_item(root)
			item.set_metadata(0, index)
			item.set_text(0, "0x%X" % (int(control.source_offset) if control.has("source_offset") else int(control.operation.source_offset)))
			if str(control.operation.kind) == "replace_message":
				item.set_text(1, "CP932 message")
				item.set_text(2, "%d bytes" % int(control.byte_length))
				item.set_text(3, str(control.operation.text))
			elif str(control.operation.kind) == "replace_condition_literal":
				item.set_text(1, "Condition literal")
				item.set_text(2, "0x%X / %d-bit" % [int(control.operation.literal_offset), int(control.width)])
				item.set_text(3, str(control.operation.value))
			elif str(control.operation.kind) == "replace_resource_name":
				item.set_text(1, "Resource name (%s)" % str(control.resource_kind))
				item.set_text(2, "%d bytes / %s" % [int(control.name_length), ", ".join(PackedStringArray(control.archive_candidates))])
				item.set_text(3, str(control.operation.name))
			elif str(control.operation.kind) == "replace_choice_option_cp932_same_length":
				item.set_text(1, "Choice option")
				item.set_text(2, "group %d / def %d (%d bytes)" % [int(control.operation.group_selector), int(control.operation.definition_id), int(control.payload_size)])
				item.set_text(3, str(control.operation.text))
			elif str(control.operation.kind) == "replace_registered_definition_literal":
				item.set_text(1, "Registered definition call")
				var registered_strings := PackedStringArray()
				for selector in control.registered_selectors:
					registered_strings.append(str(int(selector)))
				item.set_text(2, "selector %d / registry %s" % [int(control.operation.selector), " ".join(registered_strings)])
				item.set_text(3, str(int(control.operation.selector)))
			elif str(control.operation.kind) == "replace_shared_routine_literal":
				item.set_text(1, "Shared routine call")
				var replaceable_strings := PackedStringArray()
				for routine_id in control.replaceable_routine_ids:
					replaceable_strings.append(str(int(routine_id)))
				item.set_text(2, "routine %d / replaceable %s" % [int(control.operation.routine_id), " ".join(replaceable_strings)])
				item.set_text(3, str(int(control.operation.routine_id)))
			elif str(control.operation.kind) == "retarget_control_flow":
				item.set_text(1, "Control target")
				var reference_label := "false target" if str(control.operation.reference_kind) == "condition_false_target" else "continuation"
				item.set_text(2, "%s / current 0x%X (%s)" % [reference_label, int(control.current_target_offset), str(control.current_target_op)])
				item.set_text(3, str(int(control.current_target_offset)))
			else:
				item.set_text(1, str(control.storage))
				item.set_text(2, "%s / %d" % [str(control.destination.get("value", "expression")), int(control.operation.pair_index)])
				item.set_text(3, str(control.operation.value))
		_summary.text = "%d edit candidates. Source evidence verified; preview checks relocation blockers." % _controls.size()
	elif not _pending_sequence.is_empty() and _pending_sequence != _staged:
		_summary.text = "The staged list changed during compilation. Preview the current draft again."
	elif _pending_sequence.is_empty() and _pending_operation != _current_operation():
		_summary.text = "The selected edit changed during compilation. Preview the current draft again."
	else:
		_compiled_bundle = result
		if result.has("steps"):
			var steps: Array = result.steps
			for index in range(_sequence_items.size()):
				_sequence_items[index].set_text(4, "compiled" if index < steps.size() else "not compiled")
			var source_size := int(steps[0].audit.source.size) if steps[0].audit.has("source") else 0
			var final_size: int = (result.files["output.mes"] as PackedByteArray).size()
			var lines: PackedStringArray = PackedStringArray([
				"Preview: %d operations compiled in order; final output %d → %d bytes; Python chain proof and independent Godot reopening passed." % [steps.size(), source_size, final_size],
			])
			for step in steps:
				var step_operation: Dictionary = step.audit.get("operation", step.operation)
				lines.append(_preview_sentence(step_operation, step.audit))
			_summary.text = "\n".join(lines)
		else:
			# The choice compile audit has no top-level "operation" (only "patch");
			# _pending_operation is the exact submitted operation in every family.
			var single_pending: Dictionary = _pending_operation if not _pending_operation.is_empty() else (_staged[0] if not _staged.is_empty() else {})
			var operation: Dictionary = result.audit.get("operation", single_pending)
			_summary.text = _preview_sentence(operation, result.audit)
			if not _staged.is_empty():
				for item in _sequence_items:
					item.set_text(4, "compiled")
	_sync()


func _preview_sentence(operation: Dictionary, audit: Dictionary) -> String:
	if str(operation.kind) == "replace_message":
		return "Preview: message at 0x%X, %d → %d bytes. Addresses and supported branch targets relocate by %+d bytes. Python semantic proof and independent Godot reopening passed." % [int(operation.source_offset), int(operation.source_byte_length), int(operation.replacement_byte_length), int(audit.relocation.delta)]
	elif str(operation.kind) == "replace_condition_literal":
		return "Preview: condition literal at 0x%X in the branch at 0x%X, %d → %d (%d-bit). One literal changes; the branch's false target 0x%X and every other byte and coordinate are preserved. Python and Godot checks passed." % [int(operation.literal_offset), int(operation.source_offset), int(operation.source_value), int(operation.replacement_value), int(operation.width), int(operation.false_target)]
	elif str(operation.kind) == "replace_resource_name":
		return ("Preview: resource name at 0x%X (%s), %s → %s (%d bytes, same length and extension). "
			+ "One name changes; every other byte and coordinate are preserved. Python and Godot checks passed.") % [int(operation.source_offset), str(operation.resource_kind), str(operation.source_name), str(operation.replacement_name), str(operation.source_name).to_utf8_buffer().size()]
	elif str(operation.kind) == "replace_choice_option_cp932_same_length":
		var patch: Dictionary = audit.patch
		return ("Preview: choice option group %d, definition %d at 0x%X, %d bytes → same length. "
			+ "One option text changes; every group, result, terminal and resume coordinate is preserved. Python and Godot checks passed.") % [int(patch.group_selector), int(patch.definition_id), int(patch.absolute_start), int(patch.payload_size)]
	elif str(operation.kind) == "replace_registered_definition_literal":
		var binding: Dictionary = audit.target.replacement_registry_binding
		return ("Preview: registered definition call at 0x%X, selector %d → %d (registry body at 0x%X). "
			+ "One literal changes; the call's physical resume at 0x%X and every other byte and coordinate are preserved. Python and Godot checks passed.") % [int(operation.source_offset), int(operation.source_selector), int(operation.replacement_selector), int(binding.body_start), int(operation.physical_resume_offset)]
	elif str(operation.kind) == "replace_shared_routine_literal":
		var callee: Dictionary = audit.target.replacement_callee
		return ("Preview: shared routine call at 0x%X, routine %d → %d (library body at 0x%X). "
			+ "One literal changes; the call's physical resume at 0x%X and every other byte and coordinate are preserved. Python and Godot checks passed.") % [int(operation.source_offset), int(operation.source_routine_id), int(operation.replacement_routine_id), int(callee.body_start), int(operation.physical_resume_offset)]
	elif str(operation.kind) == "retarget_control_flow":
		var reference_label := "false target" if str(operation.reference_kind) == "condition_false_target" else "continuation"
		return ("Preview: control target at 0x%X (%s), target 0x%X → 0x%X (%s at the replacement). "
			+ "One u32 operand changes; the transfer's other bytes and every other coordinate are preserved. Python and Godot checks passed.") % [int(operation.source_offset), reference_label, int(operation.current_target_offset), int(operation.replacement_target_offset), str(audit.replacement_target.op)]
	else:
		return "Preview: %s at 0x%X, pair %d: %d → %d. One expression changes; other bytes and coordinates are preserved. Python and Godot checks passed." % [str(operation.storage), int(operation.source_offset), int(operation.pair_index), int(operation.source_value), int(operation.replacement_value)]


func _inspect() -> void:
	var current: Dictionary = context_provider.call()
	if not current.get("ok", false):
		_summary.text = str(current.get("error", "Select an original workspace entry."))
		return
	_context = current.duplicate(true)
	_source_bundle.clear()
	_compiled_bundle.clear()
	_controls.clear()
	_tree.clear()
	_staged.clear()
	_pending_sequence = []
	_sync_sequence_tree()
	var started := session.inspect(str(current.archive_path), str(current.entry), str(current.source_sha256), str(current.workspace))
	_summary.text = "Analyzing the original entry in Python…" if started.get("ok", false) else str(started.error)
	_sync()


func _select() -> void:
	_compiled_bundle.clear()
	var row := _selected_control()
	if not row.is_empty():
		if str(row.operation.kind) == "replace_message":
			_text.text = str(row.operation.text)
		elif str(row.operation.kind) == "replace_resource_name":
			_text.text = str(row.operation.name)
		elif str(row.operation.kind) == "replace_choice_option_cp932_same_length":
			_text.text = str(row.operation.text)
		elif str(row.operation.kind) == "replace_condition_literal":
			_value.min_value = 0
			_value.max_value = pow(2, int(row.width)) - 1
			_value.set_value_no_signal(float(row.operation.value))
		elif str(row.operation.kind) == "replace_registered_definition_literal":
			_value.min_value = 0
			_value.max_value = 255
			_value.set_value_no_signal(float(row.operation.selector))
		elif str(row.operation.kind) == "replace_shared_routine_literal":
			_value.min_value = 0
			_value.max_value = 255
			_value.set_value_no_signal(float(row.operation.routine_id))
		elif str(row.operation.kind) == "retarget_control_flow":
			_value.min_value = 0
			_value.max_value = int(row.code_size) - 1
			_value.set_value_no_signal(float(row.current_target_offset))
		else:
			_value.min_value = -2147483648
			_value.max_value = 4294967295
			_value.set_value_no_signal(float(row.operation.value))
	_sync()


func _compile() -> void:
	if _source_bundle.is_empty() or not _context_is_current():
		_summary.text = "Analyze the current entry first."
		return
	if not _staged.is_empty():
		_pending_operation = {}
		_pending_sequence = _staged.duplicate(true)
		var started_sequence := session.compile_sequence(str(_source_bundle.directory), _pending_sequence, str(_context.workspace))
		_summary.text = "Compiling and reopening the proposed sequence…" if started_sequence.get("ok", false) else str(started_sequence.error)
		_sync()
		return
	var row := _selected_control()
	if row.is_empty():
		_summary.text = "Analyze the current entry and select an edit first."
		return
	var operation := _current_operation()
	_pending_operation = operation.duplicate(true)
	_pending_sequence = []
	var started := session.compile_edit(str(_source_bundle.directory), operation, str(_context.workspace))
	_summary.text = "Compiling and reopening the proposed change…" if started.get("ok", false) else str(started.error)
	_sync()


func _add_to_list() -> void:
	var operation := _current_operation()
	if operation.is_empty():
		_summary.text = "Select an edit before adding it to the list."
		return
	if _duplicate_in_staged(operation):
		_summary.text = "That instruction is already staged; remove it from the list before staging another edit on it."
		return
	var relocation_index := _staged_relocation_index()
	var note := ""
	if relocation_index != -1:
		if str(operation.get("kind", "")) == "replace_message":
			_summary.text = "Only one message relocation may be staged, and it must be the last step."
			return
		_staged.insert(relocation_index, operation)
		note = "Adding this edit moved the staged message relocation to the end of the list."
	else:
		_staged.append(operation)
	_compiled_bundle.clear()
	_pending_sequence = []
	_sync_sequence_tree()
	_summary.text = note if not note.is_empty() else "%d operations staged." % _staged.size()
	_sync()


func _remove_selected_from_list() -> void:
	var item := _sequence_tree.get_selected()
	if item == null:
		return
	var index := int(item.get_metadata(0))
	if index >= 0 and index < _staged.size():
		_staged.remove_at(index)
	_compiled_bundle.clear()
	_pending_sequence = []
	_sync_sequence_tree()
	_sync()


func _clear_list() -> void:
	_staged.clear()
	_compiled_bundle.clear()
	_pending_sequence = []
	_sync_sequence_tree()
	_sync()


func _duplicate_in_staged(operation: Dictionary) -> bool:
	var kind := str(operation.get("kind", ""))
	for existing in _staged:
		if kind == "replace_choice_option_cp932_same_length" and str(existing.get("kind", "")) == kind:
			if int(existing.get("group_selector", -1)) == int(operation.get("group_selector", -2)) and int(existing.get("definition_id", -1)) == int(operation.get("definition_id", -2)):
				return true
		elif operation.has("source_offset") and existing.has("source_offset") and int(existing.source_offset) == int(operation.source_offset):
			return true
	return false


func _staged_relocation_index() -> int:
	for index in range(_staged.size()):
		if str(_staged[index].get("kind", "")) == "replace_message":
			return index
	return -1


func _sync_sequence_tree() -> void:
	_sequence_tree.clear()
	_sequence_items.clear()
	var root := _sequence_tree.create_item()
	for index in range(_staged.size()):
		var operation: Dictionary = _staged[index]
		var item := _sequence_tree.create_item(root)
		item.set_metadata(0, index)
		item.set_text(0, str(index + 1))
		item.set_text(1, _operation_offset_label(operation))
		item.set_text(2, _operation_kind_label(str(operation.get("kind", ""))))
		item.set_text(3, _operation_change_label(operation))
		item.set_text(4, "staged")
		_sequence_items.append(item)


func _mark_failed_step(error_text: String) -> void:
	var regex := RegEx.new()
	regex.compile("^Step (\\d+)")
	var found := regex.search(error_text)
	var failed_index := int(found.get_string(1)) - 1 if found else -1
	for index in range(_sequence_items.size()):
		_sequence_items[index].set_text(4, "rejected" if index == failed_index else "not compiled")


static func _operation_kind_label(kind: String) -> String:
	if kind == "replace_message":
		return "CP932 message"
	elif kind == "replace_condition_literal":
		return "Condition literal"
	elif kind == "replace_resource_name":
		return "Resource name"
	elif kind == "replace_choice_option_cp932_same_length":
		return "Choice option"
	elif kind == "replace_registered_definition_literal":
		return "Registered definition call"
	elif kind == "replace_shared_routine_literal":
		return "Shared routine call"
	elif kind == "retarget_control_flow":
		return "Control target"
	return "State literal"


static func _operation_offset_label(operation: Dictionary) -> String:
	if operation.has("source_offset"):
		return "0x%X" % int(operation.source_offset)
	if str(operation.get("kind", "")) == "replace_choice_option_cp932_same_length":
		return "group %d / def %d" % [int(operation.get("group_selector", 0)), int(operation.get("definition_id", 0))]
	return ""


static func _operation_change_label(operation: Dictionary) -> String:
	var kind := str(operation.get("kind", ""))
	if kind in ["replace_message", "replace_resource_name", "replace_choice_option_cp932_same_length"]:
		return str(operation.get("text", operation.get("name", "")))
	elif kind == "replace_registered_definition_literal":
		return str(int(operation.get("selector", 0)))
	elif kind == "replace_shared_routine_literal":
		return str(int(operation.get("routine_id", 0)))
	elif kind == "retarget_control_flow":
		return "-> 0x%X" % int(operation.get("replacement_target_offset", 0))
	return str(operation.get("value", ""))


func _current_operation() -> Dictionary:
	var row := _selected_control()
	if row.is_empty():
		return {}
	var operation: Dictionary = row.operation.duplicate(true)
	if str(operation.kind) == "replace_message":
		operation.text = _text.text
	elif str(operation.kind) == "replace_resource_name":
		operation.name = _text.text.strip_edges()
	elif str(operation.kind) == "replace_choice_option_cp932_same_length":
		operation.text = _text.text
	elif str(operation.kind) == "replace_registered_definition_literal":
		operation.selector = int(_value.value)
	elif str(operation.kind) == "replace_shared_routine_literal":
		operation.routine_id = int(_value.value)
	elif str(operation.kind) == "retarget_control_flow":
		operation.replacement_target_offset = int(_value.value)
	else:
		operation.value = int(_value.value)
	return operation


func _publish() -> void:
	if _compiled_bundle.is_empty() or not _context_is_current():
		_summary.text = "The preview is absent or stale; analyze and preview again."
		return
	var result: Dictionary = publish_output.call(_compiled_bundle, _context)
	_summary.text = str(result.get("error", "Published the verified MES and semantic proof to the workspace. Run uses this proof automatically."))
	if result.get("ok", false):
		_compiled_bundle.clear()
		_source_bundle.clear()
		_staged.clear()
		_pending_sequence = []
		_sync_sequence_tree()
	_sync()


func _context_is_current() -> bool:
	return context_provider.is_valid() and context_provider.call() == _context


func _selected_control() -> Dictionary:
	var item := _tree.get_selected()
	if item == null:
		return {}
	var index := int(item.get_metadata(0))
	return _controls[index] if index >= 0 and index < _controls.size() else {}


func _sync() -> void:
	if _inspect_button == null:
		return
	_inspect_button.disabled = session.is_running()
	_compile_button.disabled = session.is_running() or _source_bundle.is_empty() or (_staged.is_empty() and _selected_control().is_empty())
	_publish_button.disabled = session.is_running() or _compiled_bundle.is_empty()
	_add_button.disabled = session.is_running() or _selected_control().is_empty()
	_remove_button.disabled = session.is_running() or _sequence_tree.get_selected() == null
	_clear_button.disabled = session.is_running() or _staged.is_empty()
	var message := str(_selected_control().get("operation", {}).get("kind", "")) in [
		"replace_message", "replace_resource_name", "replace_choice_option_cp932_same_length",
	]
	_text.visible = message
	_value.get_parent().visible = not message


func _button(parent: Node, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	parent.add_child(button)
	return button
