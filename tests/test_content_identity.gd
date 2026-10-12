extends "res://tests/test_case.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentIdentityScript := preload("res://content_core/content_identity.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const ENTRY_SIZE := 264
const TEST_ROOT := "user://content_identity_test"


func _ready() -> void:
	_cleanup()
	var root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(root)
	var arc_path := root.path_join("mmo.arc")
	var original_data := PackedByteArray([1, 2, 3, 4])
	var changed_data := PackedByteArray([4, 3, 2, 1])
	_create_arc(arc_path, "BACK.MMO", original_data)
	var reader := ArcReaderScript.new()
	_check(reader.open(arc_path), "content identity fixture opens its selected original ARC")
	var evidence := {
		"archive": "mmo.arc",
		"entry": "BACK.MMO",
		"original_archive_sha256": reader.get_archive_fingerprint(),
		"original_entry_sha256": reader.get_entry_fingerprint("BACK.MMO"),
		"content_kind": "image",
	}
	var interface := {"ok": true, "schema": "kakyu_mmo_image_interface/v1", "width": 2, "height": 2}
	var classifier := ContentIdentityScript.new()
	var exact := classifier.classify(evidence, reader, {
		"ok": true, "source": "original_arc", "archive": "mmo.arc", "entry": "BACK.MMO",
	}, original_data, interface)
	_check(exact.ok and exact.relationship == "exact_original" and exact.route_evidence_preserved and not exact.changed, "exact original media keeps route evidence and an exact payload label")

	var overlay_descriptor := {
		"ok": true,
		"source": "overlay",
		"archive": "mmo.arc",
		"entry": "BACK.MMO",
		"sha256": OverlayPackageScript.sha256_bytes(changed_data),
		"base_archive_sha256": evidence.original_archive_sha256,
		"original_entry_sha256": evidence.original_entry_sha256,
		"compatibility": "original_engine_compatible",
	}
	var derived := classifier.classify(evidence, reader, overlay_descriptor, changed_data, interface)
	_check(derived.ok and derived.relationship == "original_derived_compatible" and derived.changed and derived.route_evidence_preserved and derived.effective.source == "overlay", "changed compatible media preserves original route evidence without inheriting an exact-original payload label")
	overlay_descriptor.compatibility = "remake_only"
	var remake := classifier.classify(evidence, reader, overlay_descriptor, changed_data, interface)
	_check(remake.ok and remake.relationship == "remake_only" and remake.route_evidence_preserved, "remake-only media remains playable while retaining separate route evidence")

	var mes_evidence := evidence.duplicate(true)
	mes_evidence.content_kind = "mes_control_flow"
	var changed_mes := classifier.classify(mes_evidence, reader, overlay_descriptor, changed_data, interface)
	_check(changed_mes.ok and changed_mes.relationship == "unsupported" and not changed_mes.route_evidence_preserved and int(changed_mes.effective.bytes) == changed_data.size(), "changed MES control flow cannot reuse offset evidence without an interface proof")
	var mes_interface := {"ok": true, "schema": "kakyu_mes_compatible_interface/v1", "control_flow_compatible": true}
	var compatible_mes := classifier.classify(mes_evidence, reader, overlay_descriptor, changed_data, mes_interface)
	_check(compatible_mes.ok and compatible_mes.relationship == "remake_only" and compatible_mes.route_evidence_preserved, "a versioned MES compatible-interface proof may preserve route evidence without promoting compatibility")

	var materialized_descriptor := overlay_descriptor.duplicate(true)
	materialized_descriptor.source = "materialized_arc"
	materialized_descriptor.compatibility = "original_engine_compatible"
	materialized_descriptor.lineage_classification = "verified_original_derived"
	materialized_descriptor.source_archive_sha256 = evidence.original_archive_sha256
	var materialized := classifier.classify(evidence, reader, materialized_descriptor, changed_data, interface)
	_check(materialized.ok and materialized.relationship == "original_derived_compatible", "verified materialized-ARC lineage uses the same evidence/effective identity contract")

	var wrong_binding := overlay_descriptor.duplicate(true)
	wrong_binding.base_archive_sha256 = "f".repeat(64)
	_check(not classifier.classify(evidence, reader, wrong_binding, changed_data, interface).ok, "changed media with a wrong base binding fails closed")
	_check(not classifier.classify(evidence, reader, overlay_descriptor, changed_data, {"ok": true}).ok, "effective media requires a versioned interface validation")
	_check(not _contains_path(derived), "content identity records hashes and logical names without machine paths")

	# TD-57: the archive comparison reads the reader's identity memo, so both
	# directions of the refusal are driven here.
	var original_descriptor := {"ok": true, "source": "original_arc", "archive": "mmo.arc", "entry": "BACK.MMO"}
	var wrong_archive_evidence := evidence.duplicate(true)
	wrong_archive_evidence.original_archive_sha256 = "f".repeat(64)
	var wrong_archive := classifier.classify(wrong_archive_evidence, reader, original_descriptor, original_data, interface)
	_check(not wrong_archive.ok and str(wrong_archive.error).contains("no longer matches route evidence"), "evidence with a wrong original archive hash is refused as no longer matching the route evidence")

	var pair_path := root.path_join("pair.arc")
	var other_entry := func(first_byte: int) -> Dictionary:
		return {"name": "OTHER.MMO", "data": PackedByteArray([first_byte, 9, 9, 9])}
	SyntheticArc.write_arc(pair_path, [{"name": "BACK.MMO", "data": original_data}, other_entry.call(9)])
	var pair_reader := ArcReaderScript.new()
	_check(pair_reader.open(pair_path), "the two-entry fixture opens its selected original ARC")
	var pair_evidence := evidence.duplicate(true)
	pair_evidence.original_archive_sha256 = pair_reader.get_archive_fingerprint()
	pair_evidence.original_entry_sha256 = pair_reader.get_entry_fingerprint("BACK.MMO")
	_check(classifier.classify(pair_evidence, pair_reader, original_descriptor, original_data, interface).ok, "the two-entry fixture classifies against its own evidence")
	# Rewrite the other entry, so the evidenced entry stays byte-identical and
	# only the archive hash can refuse, within the second of the reader's
	# last full hash. A retry writes a new payload each time, so the evidence
	# never matches again.
	var same_second := false
	for attempt in range(10):
		pair_reader.get_archive_fingerprint()
		var before_time := FileAccess.get_modified_time(pair_path)
		SyntheticArc.write_arc(pair_path, [{"name": "BACK.MMO", "data": original_data}, other_entry.call(10 + attempt)])
		if FileAccess.get_modified_time(pair_path) == before_time:
			same_second = true
			break
	_check(same_second, "the same-second same-size rewrite of the other entry is produced")
	if same_second:
		_check(pair_reader.get_entry_fingerprint("BACK.MMO") == pair_evidence.original_entry_sha256, "the rewrite leaves the evidenced entry byte-identical")
		_check(FileAccess.get_sha256(pair_path) != pair_evidence.original_archive_sha256, "the rewrite changed the archive hash")
		# The documented residual (TD-57, D4), asserted so it stays visible.
		_check(classifier.classify(pair_evidence, pair_reader, original_descriptor, original_data, interface).ok, "residual: the identity comparison does not see a same-second same-size rewrite")
		pair_reader.get_archive_fingerprint()
		var refused := classifier.classify(pair_evidence, pair_reader, original_descriptor, original_data, interface)
		_check(not refused.ok and str(refused.error).contains("no longer matches route evidence"), "after get_archive_fingerprint() the old evidence is refused")
	pair_reader.close()

	reader.close()
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _create_arc(path: String, entry_name: String, data: PackedByteArray) -> void:
	var offset := 4 + ENTRY_SIZE
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_32(1)
	var record := PackedByteArray()
	record.resize(ENTRY_SIZE)
	var name_bytes := entry_name.to_ascii_buffer()
	for index in range(256):
		record[index] = (name_bytes[index] if index < name_bytes.size() else 0) ^ 0x72
	record.encode_u32(256, data.size() ^ 0xF97FD0EC)
	record.encode_u32(260, offset ^ 0xA2C947FC)
	file.store_buffer(record)
	file.store_buffer(data)
	file.close()


func _contains_path(value) -> bool:
	if value is Dictionary:
		for nested in value.values():
			if _contains_path(nested): return true
	elif value is Array:
		for nested in value:
			if _contains_path(nested): return true
	elif value is String:
		var text: String = value
		return text.contains("user://") or text.contains("AppData") or (text.length() > 2 and text[1] == ":")
	return false


func _cleanup() -> void:
	var root := ProjectSettings.globalize_path(TEST_ROOT)
	if not DirAccess.dir_exists_absolute(root): return
	var directory := DirAccess.open(root)
	for name in directory.get_files():
		DirAccess.remove_absolute(root.path_join(name))
	DirAccess.remove_absolute(root)
