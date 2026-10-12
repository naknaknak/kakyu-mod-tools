extends "res://tests/test_case.gd"

const MesContainerScript := preload("res://content_core/mes_container.gd")
const AlignmentAuditScript := preload("res://content_core/mes_record_alignment_audit.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")


func _ready() -> void:
	var document := MesContainerScript.new().parse(_framed_mes())
	var report := AlignmentAuditScript.new().audit(document)
	_check(
		report.ok
		and report.schema == ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA
		and report.code_bytes == 18
		and report.framed_bytes == 18
		and report.instruction_count == 2
		and report.instruction_bytes == 14
		and report.compound_record_count == 2
		and report.compound_families.opaque_native_stream_branch_guard == 1
		and report.compound_families.typed_record_list_until_zero == 1
		and report.opaque_boundary_count == 1
		and report.opaque_bytes == 4
		and report.opaque_boundaries[0].source_offset == 14
		and report.opaque_boundaries[0].end_offset == 18
		and report.opaque_boundaries[0].raw_hex == "0ae3ff00"
		and report.opaque_boundaries[0].boundary == "byte_preserving_fail_closed"
		and report.failure_count == 0,
		"record-alignment audit covers every byte with exact compound records or one opaque tail"
	)
	var zero_table := MesContainerScript.new().parse(_zero_table_mes())
	var zero_table_report := AlignmentAuditScript.new().audit(zero_table)
	_check(
		zero_table_report.ok
		and zero_table_report.region_count == 1
		and zero_table_report.code_bytes == 5
		and zero_table_report.framed_bytes == 5
		and zero_table_report.compound_record_count == 1
		and zero_table_report.opaque_boundary_count == 0,
		"record-alignment audit covers a zero-table LIB bootstrap as one region"
	)
	get_tree().quit(1 if _failed else 0)


func _framed_mes() -> PackedByteArray:
	var code := PackedByteArray([
		0x0D,
		0x0B, 0x02, 0xFF, 0x01, 0x01, 0x01, 0x01,
		0x00,
		0x12, 0x02, 0x01, 0xFF, 0x00,
		0x0A, 0xE3, 0xFF, 0x00,
	])
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(code)
	return mes


func _zero_table_mes() -> PackedByteArray:
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(PackedByteArray([0x12, 0x02, 0x01, 0xFF, 0x00]))
	return mes
