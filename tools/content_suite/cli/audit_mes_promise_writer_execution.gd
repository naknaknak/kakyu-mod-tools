extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_promise_writer_owner_boundary_audit/v1"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const DATE_MARKER := 401
const AUX_MARKER := 77
const AUX_WRITTEN_VALUE := 1800
const CASES := [
	{"entry": "A_PROMIS.MES", "sha256": "81d3de790b2a1542f09dfedd753c5010970971acb38e64b9e0241c6c2f31ca19", "date": [61, 0x2036, 0x209B, 215], "aux": [189, 0x57E6, 0x585F, 216], "date_steps": 9, "aux_steps": 51},
	{"entry": "B_PROMIS.MES", "sha256": "c1270051a6ea49bcc84fae4d9060e6d2bc114b672dc8beecdf5e97dc552c446d", "date": [73, 0x253A, 0x259B, 233], "aux": [161, 0x4C76, 0x4CEF, 234], "date_steps": 9, "aux_steps": 57},
	{"entry": "C_PROMIS.MES", "sha256": "485e997c7c328277de5dbdd11f32bcff291a20005825a26d5aecfbc172eb3fba", "date": [49, 0x1B97, 0x1C15, 225], "aux": [138, 0x4343, 0x43BC, 226], "date_steps": 11, "aux_steps": 51},
	{"entry": "D_PROMIS.MES", "sha256": "5d5a09ad7cb4a2a3af70cc6d32588d67445de5db585144c796bb0b722e661f68", "date": [53, 0x1CD0, 0x1D37, 237], "aux": [141, 0x4414, 0x448D, 238], "date_steps": 9, "aux_steps": 51},
	{"entry": "E_PROMIS.MES", "sha256": "0c72ae3a7977cb61753d73a3bee118ee230546f16752412081f63f054beca711", "date": [52, 0x1D50, 0x1DC4, 217], "aux": [141, 0x4505, 0x457E, 218], "date_steps": 11, "aux_steps": 51},
	{"entry": "F_PROMIS.MES", "sha256": "60d8638c9d422a189dbd2b08ee6127ccdcb18a38370be0d965b8dfdd62492f08", "date": [49, 0x1DDE, 0x1E49, 213], "aux": [138, 0x4589, 0x4602, 214], "date_steps": 9, "aux_steps": 51},
	{"entry": "G_PROMIS.MES", "sha256": "a3bb5f57e28def5baea46271813ea4529472a5568b48f05384468d9f4442ca8e", "date": [68, 0x2648, 0x26A7, 221], "aux": [157, 0x4E90, 0x4F0B, 222], "date_steps": 9, "aux_steps": 52},
	{"entry": "H_PROMIS.MES", "sha256": "395a8c8290c57bf2cabfe679fa866369c2af5a9069527dfeb29cef245b25cdf8", "date": [51, 0x1D7D, 0x1DE6, 227], "aux": [140, 0x45D1, 0x464C, 228], "date_steps": 9, "aux_steps": 65},
	{"entry": "I_PROMIS.MES", "sha256": "afad7ff835232442f2d366fc3d4a0960a4b60fc74a6ceaf4cb8c365b1f5d7e30", "date": [66, 0x2554, 0x25CE, 219], "aux": [155, 0x4DB5, 0x4E30, 220], "date_steps": 11, "aux_steps": 51},
	{"entry": "J_PROMIS.MES", "sha256": "e64748323d69b53cd5db38ce1bb44353ec719d0c80d41bc3c04c39a0598672f2", "date": [52, 0x1DBB, 0x1E1C, 235], "aux": [140, 0x4599, 0x4614, 236], "date_steps": 9, "aux_steps": 51},
	{"entry": "K_PROMIS.MES", "sha256": "0a06c7efea59f44ca3bea815f7a8f25bfa5e08397e6c774f976811500582f90b", "date": [63, 0x21CF, 0x2224, 229], "aux": [152, 0x4A17, 0x4A92, 230], "date_steps": 9, "aux_steps": 51},
	{"entry": "L_PROMIS.MES", "sha256": "4dd0cfd93a2f0146764a3086ba5dec1429775e22ce9e1c511fdb013faf14e40c", "date": [47, 0x1C13, 0x1C7C, 231], "aux": [136, 0x4459, 0x44D4, 232], "date_steps": 9, "aux_steps": 65},
]


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_promise_writer_execution.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader.last_error)
		return
	if reader.get_archive_fingerprint() != ARCHIVE_SHA256:
		_fail("Unexpected mes.arc SHA-256.")
		reader.close()
		return
	var parser := MesContainerScript.new()
	var reports: Array[String] = []
	var failures: Array[String] = []
	var date_shared_boundaries := 0
	var date_returns := 0
	var aux_returns := 0
	var direct_writer_reached := 0
	for specification in CASES:
		var entry_name := str(specification.entry)
		if reader.get_entry_fingerprint(entry_name) != str(specification.sha256):
			failures.append("%s fingerprint changed" % entry_name)
			continue
		var document := parser.parse(reader.read_entry(entry_name), {"archive": "mes.arc", "entry": entry_name})
		if not document.ok:
			failures.append("%s container: %s" % [entry_name, str(document.error)])
			continue
		for role in ["date", "aux"]:
			var target: Array = specification[role]
			var intro_index := int(target[0])
			var intro_offset := int(target[1])
			var write_offset := int(target[2])
			var written_index := int(target[3])
			if intro_index >= document.entries.size() or int(document.entries[intro_index].offset) != intro_offset:
				failures.append("%s %s owner intro changed" % [entry_name, role])
				continue
			var state := SandboxStateScript.new(1)
			state.write_value("state_u16", 10, DATE_MARKER)
			state.write_value("state_u16", 19, AUX_MARKER)
			state.write_value("banked_u16", written_index, 0xFFFF, 0)
			var result := MesEventRunnerScript.new().run(
				document.bytecode,
				intro_offset,
				state,
				int(document.header.code_size),
				2000,
				{
					"address_table_offsets": document.header.entry_offsets,
					"native_stream_policy": "skip_bounded",
				}
			)
			var matching_rows: Array = result.get("trace", []).filter(
				func(record: Dictionary) -> bool:
					return (
						int(record.get("source_offset", -1)) == write_offset
						and str(record.get("effect", "")) == "banked_u16_write_run"
						and str(record.get("write_storage", "")) == "banked_u16"
						and int(record.get("write_bank", -1)) == 0
						and int(record.get("write_start", -1)) == written_index
					)
			)
			var actual_value := state.read_value("banked_u16", written_index, 0)
			reports.append("%s:%s#%d:0x%X>0x%X=%d status=%s steps=%d" % [
				entry_name, role, intro_index, intro_offset, write_offset, actual_value,
				str(result.get("status", "unknown")), result.get("trace", []).size(),
			])
			direct_writer_reached += matching_rows.size()
			# Core 0.316.0 (2026-09-13): the five-row "returns" this audit once
			# recorded were the 00 that ends a message wait's record list, read
			# as command 0x00 under the separator framing. Every date owner now
			# runs to the shared-routine call that precedes its writer (nine
			# rows, eleven where the intro opens with a name-insert dialogue)
			# without touching the marker; every auxiliary owner runs through
			# its dialogue to the writer, which copies the 1800 the intro
			# stores into state_u16[19], and returns.
			var expected_status := "shared_routine_boundary"
			var expected_steps := int(specification["date_steps"])
			var expected_writer_rows := 0
			var expected_value := 0xFFFF
			if role == "date":
				date_shared_boundaries += 1
			else:
				expected_status = "script_return"
				expected_steps = int(specification["aux_steps"])
				expected_writer_rows = 1
				expected_value = AUX_WRITTEN_VALUE
				aux_returns += 1
			if (
				matching_rows.size() != expected_writer_rows
				or actual_value != expected_value
				or str(result.get("status", "")) != expected_status
				or result.get("trace", []).size() != expected_steps
			):
				failures.append("%s %s owner boundary changed; trace=%s" % [
					entry_name, role, _trace_signature(result.get("trace", [])),
				])
	var source_after := reader.get_archive_fingerprint()
	reader.close()
	if source_after != ARCHIVE_SHA256:
		failures.append("Original mes.arc changed during read-only execution audit")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		print("MES_PROMISE_WRITER_EXECUTION_DIAGNOSTIC " + ",".join(reports))
		quit(1)
		return
	print("MES_PROMISE_WRITER_OWNER_BOUNDARY schema=%s cases=%d owners=%d direct_writer_reached=%d date_shared=%d date_return=%d aux_return=%d routes=%s source_unchanged=true" % [
		SCHEMA, CASES.size(), reports.size(), direct_writer_reached, date_shared_boundaries, date_returns, aux_returns, ",".join(reports),
	])
	quit(0)


func _trace_signature(trace: Array) -> String:
	var parts: Array[String] = []
	for record in trace:
		var suffix := ""
		if record.has("condition_value"):
			suffix = ":condition=%d" % int(record.condition_value)
		parts.append("0x%X:%s>0x%X%s" % [
			int(record.get("source_offset", -1)),
			str(record.get("effect", "unknown")),
			int(record.get("next_offset", -1)),
			suffix,
		])
	return "/".join(parts)
