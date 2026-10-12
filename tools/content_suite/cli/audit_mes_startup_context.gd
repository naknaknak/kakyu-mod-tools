extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesStartupContextScript := preload("res://content_core/mes_startup_context.gd")

const SCHEMA := "kakyu_mes_startup_context_audit/v1"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const START_ENTRY_SHA256 := "ba57bf666fbd9db9b3110f2bf1c70e80e11a35de00e82256aaaf35921c77038f"
const LIBRARY_ENTRY_SHA256 := "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d"
const ENTRY_NAME := "DEF_MAIN.MES"
const ENTRY_SHA256 := "f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0"
const EXPECTED_TRACE_COUNT := 42
const EXPECTED_EFFECT_COUNTS := {
	"bootstrap_transfer": 14,
	"fallthrough": 1,
	"internal_vector_clear": 17,
	"script_return": 1,
	"source_line_marker": 9,
}
const EXPECTED_REGISTRATIONS := [
	{"selector": 18, "registration_offset": 0x0000, "body_offset": 0x0007, "skip_target": 0x0008},
	{"selector": 81, "registration_offset": 0x008F, "body_offset": 0x0096, "skip_target": 0x01FC},
	{"selector": 26, "registration_offset": 0x01FC, "body_offset": 0x0203, "skip_target": 0x042D},
	{"selector": 11, "registration_offset": 0x042D, "body_offset": 0x0434, "skip_target": 0x049A},
	{"selector": 12, "registration_offset": 0x049A, "body_offset": 0x04A1, "skip_target": 0x0EFB},
	{"selector": 14, "registration_offset": 0x0EFB, "body_offset": 0x0F02, "skip_target": 0x0F4B},
	{"selector": 15, "registration_offset": 0x0F4B, "body_offset": 0x0F52, "skip_target": 0x0F72},
	{"selector": 17, "registration_offset": 0x0F72, "body_offset": 0x0F79, "skip_target": 0x10BD},
	{"selector": 21, "registration_offset": 0x10BD, "body_offset": 0x10C4, "skip_target": 0x1102},
	{"selector": 22, "registration_offset": 0x1102, "body_offset": 0x1109, "skip_target": 0x116E},
	{"selector": 23, "registration_offset": 0x116E, "body_offset": 0x1175, "skip_target": 0x11C3},
	{"selector": 20, "registration_offset": 0x11C3, "body_offset": 0x11CA, "skip_target": 0x1335},
	{"selector": 80, "registration_offset": 0x1335, "body_offset": 0x133C, "skip_target": 0x1518},
	{"selector": 99, "registration_offset": 0x1518, "body_offset": 0x151F, "skip_target": 0x153B},
]


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_startup_context.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader, reader.last_error)
		return
	var archive_before := reader.get_archive_fingerprint()
	var entry_before := reader.get_entry_fingerprint(ENTRY_NAME)
	if (
		archive_before != ARCHIVE_SHA256
		or reader.get_entry_fingerprint("START.MES") != START_ENTRY_SHA256
		or reader.get_entry_fingerprint("LIBLARY.LIB") != LIBRARY_ENTRY_SHA256
		or entry_before != ENTRY_SHA256
	):
		_fail(reader, "Startup context source hashes do not match the audited original set.")
		return
	var document := MesContainerScript.new().parse(
		reader.read_entry(ENTRY_NAME),
		{"archive": "mes.arc", "entry": ENTRY_NAME}
	)
	if not document.get("ok", false):
		_fail(reader, str(document.get("error", "DEF_MAIN.MES parse failed.")))
		return
	var projection := MesStartupContextScript.new().build(document)
	if not projection.get("ok", false):
		_fail(reader, "DEF_MAIN.MES startup context projection failed: %s" % str(projection.get("error", "unknown error")))
		return
	var observed_registrations: Array[Dictionary] = []
	for untyped_registration in projection.get("registrations", []):
		var registration: Dictionary = untyped_registration
		observed_registrations.append({
			"selector": int(registration.selector),
			"registration_offset": int(registration.registration_offset),
			"body_offset": int(registration.body_offset),
			"skip_target": int(registration.skip_target),
		})
	if (
		str(projection.get("schema", "")) != "kakyu_mes_startup_context/v2"
		or int(projection.get("trace_count", -1)) != EXPECTED_TRACE_COUNT
		or projection.get("trace_effect_counts", {}) != EXPECTED_EFFECT_COUNTS
		or observed_registrations != EXPECTED_REGISTRATIONS
		or int(projection.get("message_count", -1)) != 0
		or int(projection.get("gameplay_state_diff_count", -1)) != 0
		or str(projection.get("body_execution_semantics", "")) != "not_executed_during_projection"
	):
		_fail(reader, "DEF_MAIN.MES zero-start context path changed from the audited contract.")
		return
	var archive_after := reader.get_archive_fingerprint()
	var entry_after := reader.get_entry_fingerprint(ENTRY_NAME)
	reader.close()
	if archive_after != archive_before or entry_after != entry_before:
		push_error("Original mes.arc changed during startup-context audit.")
		quit(1)
		return
	var selector_labels: Array[String] = []
	for registration in observed_registrations:
		selector_labels.append(str(int(registration.selector)))
	print(
		"PASS: %s DEF_MAIN.MES zero-start context registrations=%d selectors=%s trace=%d temp_vector_clears=17 messages=0 gameplay_diff=0 native_contract_reference=exe_audit_v16_v20_v21 source_unchanged=true"
		% [
			SCHEMA,
			observed_registrations.size(),
			",".join(selector_labels),
			int(projection.trace_count),
		]
	)
	quit(0)


func _fail(reader: RefCounted, message: String) -> void:
	reader.call("close")
	push_error(message)
	quit(1)
