extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const AudioValidatorScript := preload("res://content_core/audio_entry_validator.gd")
const MmoCodecScript := preload("res://content_core/mmo_codec.gd")
const ContractValuesScript := preload("res://content_core/contract_values.gd")

const SOURCE_ENTRY := "EVENTD03.MES"
const EXPECTED_PRELUDE_MMO_OFFSET := 0x1A4
const EXPECTED_PRELUDE_MMO := "D03.MMO"
# The prelude marker is matched by the length and SHA-256 of its raw bytes, not by the bytes
# (WD-25 item 1b, treatment H): an original record of this size does not belong in a tracked file.
const EXPECTED_PRELUDE_MMO_RAW_LENGTH := 12
const EXPECTED_PRELUDE_MMO_RAW_SHA256 := "bad2e9968b6809e67d3da01b8d177251801740604e26a2c3e2801e1f1af6b6ed"
const INTRO_OFFSET := 0x22E
const EXPECTED_ASSIGNMENT := "09010021ff00"
const EXPECTED_CALL := "1d0217ff00"
const EXPECTED_SELECTOR := 33
const EXPECTED_RESOURCE := "MAKI.WAV"
const EXPECTED_MARKERS := [21, 22, 23, 24, 25]
const EXPECTED_FIRST_MESSAGE := "816d"
const EXPECTED_SEPARATOR_OFFSET := 0x25C
const EXPECTED_DYNAMIC_OFFSET := 0x25D
const EXPECTED_CURSOR_OFFSET := 0x282
const EXPECTED_STOP_OFFSET := 0x284
const EXPECTED_RESUME_OFFSET := 0x288
const EXPECTED_RECORD_OFFSET := 0x290
const EXPECTED_RECORD_ID := 47181
const EXPECTED_SECOND_BOUNDARY := 0x2E2
const EXPECTED_SECOND_RESUME := 0x2E6
const EXPECTED_VOICE_MARKER_OFFSET := 0x305
const EXPECTED_VOICE_RESOURCE := "D0977.OGG"
const EXPECTED_THIRD_BOUNDARY := 0x378
const EXPECTED_THIRD_RESUME := 0x37C
const EXPECTED_REMAINING_BOUNDARIES := [0x378, 0x3DA, 0x458, 0x4BF, 0x511, 0x589, 0x5ED, 0x67D, 0x6BC, 0x72B]
const EXPECTED_REMAINING_RESUMES := [0x37C, 0x3DE, 0x45C, 0x4C3, 0x515, 0x58D, 0x5F1, 0x681, 0x6C0, 0x72F]
const EXPECTED_VOICE_MARKERS := {
	0x305: "D0977.OGG",
	0x3FD: "D0978.OGG",
	0x534: "D0979.OGG",
	0x610: "D0980.OGG",
}
const EXPECTED_MESSAGE_RECORD_IDS := [47181, 47182, 47183, 47184, 47185, 47186, 47187, 47188, 47189, 47190, 47191, 47192]
const EXPECTED_RETURN_OFFSET := 0x7FF
const EXPECTED_COMPLETION_INDEX := 751
const PREVIEW_NAME := "VALIDATION_NAME"
const HEADER_READ_SIZE := 64 * 1024


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("Usage: <mes.arc> <bgm.arc>")
		return
	var mes_reader := ArcReaderScript.new()
	var bgm_reader := ArcReaderScript.new()
	if not mes_reader.open(arguments[0]):
		_fail("mes.arc rejected: %s" % mes_reader.last_error)
		return
	if not bgm_reader.open(arguments[1]):
		mes_reader.close()
		_fail("bgm.arc rejected: %s" % bgm_reader.last_error)
		return
	var mes_data := mes_reader.read_entry(SOURCE_ENTRY)
	var document := MesContainerScript.new().parse(mes_data, {"archive": "mes.arc", "entry": SOURCE_ENTRY})
	if not document.ok:
		_close_fail(mes_reader, bgm_reader, "MES parse rejected: %s" % document.error)
		return
	var runner := MesEventRunnerScript.new()
	var prelude_result := runner.run(
		document.bytecode,
		EXPECTED_PRELUDE_MMO_OFFSET,
		SandboxStateScript.new(1),
		int(document.header.code_size)
	)
	if (
		prelude_result.trace.is_empty()
		or str(prelude_result.trace[0].effect) != "mmo_resource_marker"
		or str(prelude_result.trace[0].resource_name).to_upper() != EXPECTED_PRELUDE_MMO
		or not _is_expected_prelude_raw(str(prelude_result.trace[0].raw_hex))
	):
		_close_fail(
			mes_reader,
			bgm_reader,
			"Confirmed pre-anchor D03.MMO marker did not match authoritative bytes: status=%s trace=%s."
			% [str(prelude_result.status), str(prelude_result.trace)]
		)
		return
	var sandbox_state := SandboxStateScript.new(1)
	var result := runner.run(
		document.bytecode,
		INTRO_OFFSET,
		sandbox_state,
		int(document.header.code_size),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{"protagonist_name": PREVIEW_NAME}
	)
	if result.trace.size() < 14:
		_close_fail(mes_reader, bgm_reader, "Confirmed route did not reach the first dialogue boundary.")
		return
	var assignment: Dictionary = result.trace[0]
	var request: Dictionary = result.trace[1]
	if (
		str(assignment.raw_hex) != EXPECTED_ASSIGNMENT
		or str(assignment.effect) != "argument_slot_assignment"
		or int(assignment.argument_value) != EXPECTED_SELECTOR
		or str(request.raw_hex) != EXPECTED_CALL
		or str(request.effect) != "bgm_request"
		or int(request.bgm_selector) != EXPECTED_SELECTOR
		or str(request.resource_name) != EXPECTED_RESOURCE
	):
		_close_fail(mes_reader, bgm_reader, "Confirmed BGM trace contract did not match the authoritative byte sequence.")
		return
	var marker_values: Array[int] = []
	var separator_reached := false
	var dynamic_name_reached := false
	var cursor_control_reached := false
	for trace_record in result.trace:
		if str(trace_record.get("effect", "")) == "source_line_marker":
			marker_values.append(int(trace_record.source_line))
		elif int(trace_record.get("source_offset", -1)) == EXPECTED_SEPARATOR_OFFSET:
			separator_reached = str(trace_record.get("effect", "")) == "statement_separator"
		elif int(trace_record.get("source_offset", -1)) == EXPECTED_DYNAMIC_OFFSET:
			dynamic_name_reached = str(trace_record.get("effect", "")) == "protagonist_name_insert"
		elif int(trace_record.get("source_offset", -1)) == EXPECTED_CURSOR_OFFSET:
			cursor_control_reached = str(trace_record.get("effect", "")) == "message_cursor_no_advance"
	if (
		marker_values != EXPECTED_MARKERS
		or not result.ok
		or str(result.status) != "dialogue_boundary"
		or int(result.offset) != EXPECTED_STOP_OFFSET
		or int(result.get("resume_offset", -1)) != EXPECTED_RESUME_OFFSET
		or not separator_reached
		or not dynamic_name_reached
		or not cursor_control_reached
		or result.messages.size() != 3
		or str(result.messages[0].raw_hex) != EXPECTED_FIRST_MESSAGE
		or str(result.messages[1].dynamic_kind) != "protagonist_name"
		or str(result.messages[1].text) != PREVIEW_NAME
	):
		_close_fail(mes_reader, bgm_reader, "Confirmed marker path did not stop at the first dialogue boundary.")
		return
	var continued := runner.run(
		document.bytecode,
		EXPECTED_RESUME_OFFSET,
		sandbox_state,
		int(document.header.code_size),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{
			"protagonist_name": PREVIEW_NAME,
			"argument_slots": result.get("argument_slots", {}),
		}
	)
	var record_reached := false
	for trace_record in continued.trace:
		if int(trace_record.get("source_offset", -1)) == EXPECTED_RECORD_OFFSET:
			record_reached = (
				str(trace_record.get("effect", "")) == "message_record_id"
				and int(trace_record.get("message_record_id", -1)) == EXPECTED_RECORD_ID
			)
	if (
		not continued.ok
		or str(continued.status) != "dialogue_boundary"
		or int(continued.offset) != EXPECTED_SECOND_BOUNDARY
		or int(continued.get("resume_offset", -1)) != EXPECTED_SECOND_RESUME
		or continued.messages.size() != 1
		or not record_reached
	):
		_close_fail(
			mes_reader,
			bgm_reader,
			"Confirmed continuation did not reach the second dialogue boundary: status=%s offset=0x%X opcode=0x%X messages=%d."
			% [
				str(continued.status),
				int(continued.offset),
				int(continued.get("command_id", -1)),
				continued.messages.size(),
			]
		)
		return
	var voice_reader := ArcReaderScript.new()
	var voice_archive_path := str(arguments[1]).get_base_dir().path_join("voice.arc")
	if not voice_reader.open(voice_archive_path):
		_close_fail(mes_reader, bgm_reader, "Sibling voice.arc rejected: %s" % voice_reader.last_error)
		return
	var voice_continued := runner.run(
		document.bytecode,
		EXPECTED_SECOND_RESUME,
		sandbox_state,
		int(document.header.code_size),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{
			"protagonist_name": PREVIEW_NAME,
			"argument_slots": continued.get("argument_slots", {}),
		}
	)
	var voice_marker_reached := false
	for trace_record in voice_continued.trace:
		if int(trace_record.get("source_offset", -1)) == EXPECTED_VOICE_MARKER_OFFSET:
			voice_marker_reached = (
				str(trace_record.get("effect", "")) == "voice_marker"
				and str(trace_record.get("resource_name", "")) == EXPECTED_VOICE_RESOURCE
				and int(trace_record.get("presentation_subcommand", -1)) == 7
				and str(trace_record.get("native_consumer_semantics", "")) == "presentation_queue_and_stream_handoff_confirmed"
				and str(trace_record.get("native_audible_output", "")) == "confirmed_directsound_play_dispatch"
				and str(trace_record.get("native_host_device_output", "")) == "not_observed_by_static_audit"
			)
	if (
		not voice_continued.ok
		or str(voice_continued.status) != "dialogue_boundary"
		or int(voice_continued.offset) != EXPECTED_THIRD_BOUNDARY
		or int(voice_continued.get("resume_offset", -1)) != EXPECTED_THIRD_RESUME
		or voice_continued.messages.size() != 1
		or not voice_marker_reached
	):
		voice_reader.close()
		_close_fail(mes_reader, bgm_reader, "Confirmed voice-marker continuation did not reach the third dialogue boundary.")
		return
	var path_segments: Array[Dictionary] = [voice_continued]
	var path_result := voice_continued
	while str(path_result.status) == "dialogue_boundary" and path_segments.size() <= EXPECTED_REMAINING_BOUNDARIES.size():
		path_result = runner.run(
			document.bytecode,
			int(path_result.resume_offset),
			sandbox_state,
			int(document.header.code_size),
			MesEventRunnerScript.DEFAULT_MAX_STEPS,
			{
				"protagonist_name": PREVIEW_NAME,
				"argument_slots": path_result.get("argument_slots", {}),
			}
		)
		path_segments.append(path_result)
	var reached_boundaries: Array[int] = []
	var reached_resumes: Array[int] = []
	var reached_voice_markers: Dictionary = {}
	var reached_message_record_ids: Array[int] = [EXPECTED_RECORD_ID]
	for path_segment in path_segments:
		if str(path_segment.status) == "dialogue_boundary":
			reached_boundaries.append(int(path_segment.offset))
			reached_resumes.append(int(path_segment.resume_offset))
		for trace_record in path_segment.trace:
			if str(trace_record.get("effect", "")) == "voice_marker":
				reached_voice_markers[int(trace_record.source_offset)] = str(trace_record.resource_name)
			elif str(trace_record.get("effect", "")) == "message_record_id":
				reached_message_record_ids.append(int(trace_record.message_record_id))
	if (
		reached_boundaries != EXPECTED_REMAINING_BOUNDARIES
		or reached_resumes != EXPECTED_REMAINING_RESUMES
		or reached_voice_markers != EXPECTED_VOICE_MARKERS
		or reached_message_record_ids != EXPECTED_MESSAGE_RECORD_IDS
		or str(path_result.status) != "script_return"
		or int(path_result.offset) != EXPECTED_RETURN_OFFSET
		or str(path_result.trace[-1].effect) != "script_return"
		or sandbox_state.read_value("global_u8", EXPECTED_COMPLETION_INDEX) != 1
	):
		voice_reader.close()
		_close_fail(mes_reader, bgm_reader, "Full bounded EVENTD03 continuation contract did not match the authoritative route.")
		return
	var voice_entry := voice_reader.get_entry(EXPECTED_VOICE_RESOURCE)
	if voice_entry.is_empty():
		voice_reader.close()
		_close_fail(mes_reader, bgm_reader, "%s is missing from voice.arc." % EXPECTED_VOICE_RESOURCE)
		return
	var voice_header := voice_reader.read_entry_range(
		int(voice_entry.index),
		0,
		mini(HEADER_READ_SIZE, int(voice_entry.size))
	)
	var voice_validation := AudioValidatorScript.validate(EXPECTED_VOICE_RESOURCE, voice_header, int(voice_entry.size))
	if not voice_validation.ok:
		voice_reader.close()
		_close_fail(mes_reader, bgm_reader, "%s rejected: %s" % [EXPECTED_VOICE_RESOURCE, voice_validation.error])
		return
	var validated_voice_count := 0
	for expected_voice_resource in EXPECTED_VOICE_MARKERS.values():
		var expected_voice_entry := voice_reader.get_entry(str(expected_voice_resource))
		if expected_voice_entry.is_empty():
			voice_reader.close()
			_close_fail(mes_reader, bgm_reader, "%s is missing from voice.arc." % str(expected_voice_resource))
			return
		var expected_voice_header := voice_reader.read_entry_range(
			int(expected_voice_entry.index),
			0,
			mini(HEADER_READ_SIZE, int(expected_voice_entry.size))
		)
		var expected_voice_validation := AudioValidatorScript.validate(
			str(expected_voice_resource),
			expected_voice_header,
			int(expected_voice_entry.size)
		)
		if not expected_voice_validation.ok:
			voice_reader.close()
			_close_fail(mes_reader, bgm_reader, "%s rejected: %s" % [str(expected_voice_resource), expected_voice_validation.error])
			return
		validated_voice_count += 1
	var bgm_entry := bgm_reader.get_entry(EXPECTED_RESOURCE)
	if bgm_entry.is_empty():
		voice_reader.close()
		_close_fail(mes_reader, bgm_reader, "%s is missing from bgm.arc." % EXPECTED_RESOURCE)
		return
	var header := bgm_reader.read_entry_range(
		int(bgm_entry.index),
		0,
		mini(HEADER_READ_SIZE, int(bgm_entry.size))
	)
	var validation := AudioValidatorScript.validate(EXPECTED_RESOURCE, header, int(bgm_entry.size))
	if not validation.ok:
		voice_reader.close()
		_close_fail(mes_reader, bgm_reader, "%s rejected: %s" % [EXPECTED_RESOURCE, validation.error])
		return
	var mmo_reader := ArcReaderScript.new()
	var mmo_archive_path := str(arguments[1]).get_base_dir().path_join("mmo.arc")
	if not mmo_reader.open(mmo_archive_path):
		voice_reader.close()
		_close_fail(mes_reader, bgm_reader, "Sibling mmo.arc rejected: %s" % mmo_reader.last_error)
		return
	var mmo_entry := mmo_reader.get_entry(EXPECTED_PRELUDE_MMO)
	if mmo_entry.is_empty():
		mmo_reader.close()
		voice_reader.close()
		_close_fail(mes_reader, bgm_reader, "%s is missing from mmo.arc." % EXPECTED_PRELUDE_MMO)
		return
	var mmo_data := mmo_reader.read_entry(EXPECTED_PRELUDE_MMO)
	var mmo_decoded := MmoCodecScript.new().decode_image(mmo_data)
	if not mmo_decoded.ok:
		mmo_reader.close()
		voice_reader.close()
		_close_fail(mes_reader, bgm_reader, "%s rejected: %s" % [EXPECTED_PRELUDE_MMO, mmo_decoded.error])
		return
	print(
		"%s sha256=%s intro=0x%X selector=%d routine=23 resource=%s"
		% [SOURCE_ENTRY, mes_reader.get_entry_fingerprint(SOURCE_ENTRY), INTRO_OFFSET, EXPECTED_SELECTOR, EXPECTED_RESOURCE]
	)
	print(
		"%s sha256=%s bytes=%d container=%s codec=%s channels=%d sample_rate=%d"
		% [
			EXPECTED_RESOURCE,
			bgm_reader.get_entry_fingerprint(EXPECTED_RESOURCE),
			int(bgm_entry.size),
			str(validation.container),
			str(validation.codec),
			int(validation.channels),
			int(validation.sample_rate),
		]
	)
	print(
		"prelude_mmo=0x%X resource=%s sha256=%s dimensions=%dx%d"
		% [
			EXPECTED_PRELUDE_MMO_OFFSET,
			EXPECTED_PRELUDE_MMO,
			mmo_reader.get_entry_fingerprint(EXPECTED_PRELUDE_MMO),
			int(mmo_decoded.width),
			int(mmo_decoded.height),
		]
	)
	print(
		"dynamic_name=0x%X separator=0x%X cursor=0x%X boundary=0x%X resume=0x%X messages=%d"
		% [EXPECTED_DYNAMIC_OFFSET, EXPECTED_SEPARATOR_OFFSET, EXPECTED_CURSOR_OFFSET, EXPECTED_STOP_OFFSET, EXPECTED_RESUME_OFFSET, result.messages.size()]
	)
	print(
		"message_record=%d at 0x%X second_boundary=0x%X resume=0x%X messages=%d"
		% [EXPECTED_RECORD_ID, EXPECTED_RECORD_OFFSET, EXPECTED_SECOND_BOUNDARY, EXPECTED_SECOND_RESUME, continued.messages.size()]
	)
	print(
		"voice_marker=0x%X resource=%s sha256=%s container=%s codec=%s channels=%d sample_rate=%d third_boundary=0x%X resume=0x%X"
		% [
			EXPECTED_VOICE_MARKER_OFFSET,
			EXPECTED_VOICE_RESOURCE,
			voice_reader.get_entry_fingerprint(EXPECTED_VOICE_RESOURCE),
			str(voice_validation.container),
			str(voice_validation.codec),
			int(voice_validation.channels),
			int(voice_validation.sample_rate),
			EXPECTED_THIRD_BOUNDARY,
			EXPECTED_THIRD_RESUME,
		]
	)
	print(
		"full_event_boundaries=%d message_records=%d voice_markers=%d validated_voices=%d completion=global_u8[%d]=%d return=0x%X"
		% [
			2 + reached_boundaries.size(),
			reached_message_record_ids.size(),
			reached_voice_markers.size(),
			validated_voice_count,
			EXPECTED_COMPLETION_INDEX,
			sandbox_state.read_value("global_u8", EXPECTED_COMPLETION_INDEX),
			EXPECTED_RETURN_OFFSET,
		]
	)
	mes_reader.close()
	bgm_reader.close()
	voice_reader.close()
	mmo_reader.close()
	print("PASS: authoritative EVENTD03 BGM/dialogue/voice-marker route validates")
	quit(0)


func _close_fail(mes_reader, bgm_reader, message: String) -> void:
	mes_reader.close()
	bgm_reader.close()
	_fail(message)


func _is_expected_prelude_raw(raw_hex: String) -> bool:
	if raw_hex.length() % 2 != 0 or not raw_hex.is_valid_hex_number(false):
		return false
	var raw := raw_hex.hex_decode()
	return (
		raw.size() == EXPECTED_PRELUDE_MMO_RAW_LENGTH
		and ContractValuesScript.sha256(raw) == EXPECTED_PRELUDE_MMO_RAW_SHA256
	)
