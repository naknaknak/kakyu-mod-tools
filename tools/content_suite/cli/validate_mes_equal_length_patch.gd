extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const MesTextPatcherScript := preload("res://content_core/mes_text_patcher.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")

const DEFAULT_ENTRY := "EVENTD03.MES"


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 1 or arguments.size() > 2:
		_fail("Usage: <mes.arc> [entry.MES]")
		return
	var archive_path := str(arguments[0])
	var entry_name := str(arguments[1]).to_upper() if arguments.size() == 2 else DEFAULT_ENTRY
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		_fail("mes.arc rejected: %s" % reader.last_error)
		return
	var archive_sha := reader.get_archive_fingerprint()
	var source := reader.read_entry(entry_name)
	if source.is_empty() and not reader.last_error.is_empty():
		reader.close()
		_fail("MES entry read failed: %s" % reader.last_error)
		return
	var document := MesContainerScript.new().parse(source, {"archive": "mes.arc", "entry": entry_name})
	if not document.ok:
		reader.close()
		_fail("MES entry parse failed: %s" % document.error)
		return
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.ok:
		reader.close()
		_fail("MES entry analysis failed: %s" % analysis.error)
		return
	var cp932 := Cp932CodecScript.new()
	var no_op_edits: Array[Dictionary] = []
	var changed_edit: Dictionary = {}
	for untyped_message in analysis.messages:
		var message: Dictionary = untyped_message
		var decoded := cp932.decode(message.raw_bytes)
		if not decoded.ok:
			continue
		no_op_edits.append({
			"source_offset": int(message.source_offset),
			"raw_sha256": str(message.raw_sha256),
			"text": str(decoded.text),
		})
		if changed_edit.is_empty() and int(message.raw_bytes.size()) > 0:
			var replacement_text := "A".repeat(int(message.raw_bytes.size()))
			if cp932.encode(replacement_text).data != message.raw_bytes:
				changed_edit = {
					"source_offset": int(message.source_offset),
					"raw_sha256": str(message.raw_sha256),
					"text": replacement_text,
				}
	if no_op_edits.is_empty() or changed_edit.is_empty():
		reader.close()
		_fail("MES entry has no suitable strict CP932 message for validation.")
		return
	var patcher := MesTextPatcherScript.new()
	var no_op := patcher.patch_equal_length(source, no_op_edits)
	if not no_op.ok or no_op.data != source:
		reader.close()
		_fail("No-op CP932 rebuild was not byte-identical: %s" % str(no_op.get("error", "payload mismatch")))
		return
	var source_copy := source.duplicate()
	var changed := patcher.patch_equal_length(source, [changed_edit])
	if not changed.ok or changed.data == source or changed.data.size() != source.size():
		reader.close()
		_fail("Changed equal-length CP932 patch failed: %s" % str(changed.get("error", "payload mismatch")))
		return
	if source != source_copy:
		reader.close()
		_fail("Patcher mutated the ARC entry source buffer.")
		return
	if reader.get_archive_fingerprint() != archive_sha:
		reader.close()
		_fail("Source mes.arc hash changed during validation.")
		return
	reader.close()
	print(
		"PASS: equal-length MES patch validation entry=%s strict_cp932_messages=%d no_op=byte_identical changed=memory_only source_archive_unchanged original_engine=unverified"
		% [entry_name, no_op_edits.size()]
	)
	quit(0)
