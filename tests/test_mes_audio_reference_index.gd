extends "res://tests/test_case.gd"

const MesContainerScript := preload("res://content_core/mes_container.gd")
const ReferenceIndexScript := preload("res://content_core/mes_audio_reference_index.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")


func _ready() -> void:
	var source_a := _document(PackedByteArray([
		0x09, 0x01, 0x00, 0x1A, 0xFF, 0x00,
		0x1D, 0x02, 0x17, 0xFF, 0x00,
		0x00,
	]))
	var source_b_code := PackedByteArray([
		0x09, 0x01, 0x00, 0x2A, 0xFF, 0x00,
		0x1D, 0x02, 0x27, 0xFF, 0x00,
	])
	source_b_code.append_array(PackedByteArray([0x0D, 0x07, 0xFF, 0x02, 0x02, 0xFF, 0x01]))
	source_b_code.append_array("b0796.ogg".to_ascii_buffer())
	source_b_code.append_array(PackedByteArray([0x00, 0x02, 0x00, 0xFF, 0x00, 0x00]))
	var source_b := _document(source_b_code)
	var indexer := ReferenceIndexScript.new()
	var index := indexer.build([
		{"entry_name": "eventd01.mes", "document": source_a},
		{"entry_name": "eventb01.mes", "document": source_b},
	])
	_check(index.ok and index.schema == ContentCoreVersionScript.MES_AUDIO_REFERENCE_INDEX_SCHEMA, "MES audio references use the current versioned schema")
	_check(index.source_count == 2 and index.reference_count == 2 and index.audio_entry_count == 2, "only confirmed BGM and voice references are indexed")
	_check(index.audio_kind_counts == {"bgm": 1, "voice": 1}, "MES audio index reports BGM and voice totals separately")
	var rebuilt := indexer.build_indexed([
		indexer.index_document("eventd01.mes", source_a),
		indexer.index_document("eventb01.mes", source_b),
	])
	_check(rebuilt.ok and rebuilt.references == index.references, "streaming callers can assemble the same index without retaining MES documents")
	var bgm := indexer.find(index, "x_mas.wav")
	_check(
		bgm.ok and bgm.reference_count == 1
		and bgm.references[0].mes_entry == "EVENTD01.MES"
		and bgm.references[0].source_offset == 0
		and bgm.references[0].call_offset == 6
		and bgm.references[0].selector == 26
		and bgm.references[0].boundary == "strict_adjacent_instructions",
		"literal slot-1 assignment immediately followed by routine 23 resolves through the BGM catalog"
	)
	var voice := indexer.find(index, "B0796.ogg")
	_check(
		voice.ok and voice.reference_count == 1
		and voice.references[0].audio_kind == "voice"
		and voice.references[0].target_archives == ["voice.arc", "tina1.arc", "tina2.arc"]
		and voice.references[0].evidence == "confirmed_voice_marker_envelope",
		"confirmed voice envelopes retain their bounded archive candidates"
	)
	voice.references[0]["mes_entry"] = "MUTATED.MES"
	_check(indexer.find(index, "B0796.OGG").references[0].mes_entry == "EVENTB01.MES", "reference queries return deep copies")

	var non_adjacent := _document(PackedByteArray([
		0x09, 0x01, 0x00, 0x21, 0xFF, 0x00,
		0x1F, 0x00, 0x00, 0x00, 0x00,
		0x1D, 0x02, 0x17, 0xFF, 0x00,
		0x00,
	]))
	var wrong_slot := _document(PackedByteArray([
		0x09, 0x02, 0x00, 0x32, 0xFF, 0x00,
		0x1D, 0x02, 0x17, 0xFF, 0x00,
		0x00,
	]))
	var dynamic_selector := _document(PackedByteArray([
		0x09, 0x01, 0x00, 0x80, 0x01, 0xFF, 0x00,
		0x1D, 0x02, 0x17, 0xFF, 0x00,
		0x00,
	]))
	var rejected := indexer.build([
		{"entry_name": "GAP.MES", "document": non_adjacent},
		{"entry_name": "SLOT.MES", "document": wrong_slot},
		{"entry_name": "DYNAMIC.MES", "document": dynamic_selector},
	])
	_check(rejected.ok and rejected.reference_count == 0, "gapped, wrong-slot, and dynamic selector patterns are not promoted to confirmed BGM references")
	_check(not indexer.find({}, "MAKI.WAV").ok, "queries reject an unversioned reference index")
	get_tree().quit(1 if _failed else 0)


func _document(code: PackedByteArray) -> Dictionary:
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(code)
	return MesContainerScript.new().parse(mes)
