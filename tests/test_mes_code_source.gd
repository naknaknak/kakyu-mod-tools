extends "res://tests/test_case.gd"

# The code-source seam's refusal contract.
#
# mes_code_source.gd states that a source which cannot answer a byte-level
# question refuses rather than guessing. It did not: the base returned "" for
# both range questions, and the package source returned "" for any range it had
# not recorded. An empty string is not a refusal, because a guard comparing one
# recorded fingerprint against another accepts two empty strings as a match.

const CodeSourceScript := preload("res://content_core/mes_code_source.gd")
const BytecodeSourceScript := preload("res://content_core/mes_bytecode_code_source.gd")
const PackageSourceScript := preload("res://content_core/playback_package_code_source.gd")
const Routine40ContractScript := preload("res://content_core/mes_routine40_choice_contract.gd")
const RunnerScript := preload("res://content_core/mes_event_runner.gd")
const StateScript := preload("res://content_core/mes_sandbox_state.gd")
const CodecScript := preload("res://content_core/cp932_codec.gd")


func _ready() -> void:
	_base_refuses_every_range_question()
	_bytecode_source_answers_ranges()
	_package_source_answers_only_recorded_ranges()
	_unanswerable_fingerprint_is_rejected_not_matched()
	_package_decode_preserves_owned_intervals_and_limits()
	_package_source_text_codec_is_injected()

	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _base_refuses_every_range_question() -> void:
	var source := CodeSourceScript.new()
	_check(
		source.sha256_range(0, 4) == CodeSourceScript.RANGE_UNAVAILABLE,
		"base source refuses a SHA-256 range"
	)
	_check(
		source.hex_range(0, 4) == CodeSourceScript.RANGE_UNAVAILABLE,
		"base source refuses a hex range"
	)
	_check(
		CodeSourceScript.RANGE_UNAVAILABLE != "",
		"the refusal is not an empty string"
	)
	_check(
		CodeSourceScript.RANGE_UNAVAILABLE.length() != 64,
		"the refusal cannot be mistaken for a SHA-256"
	)
	_check(not source.decode_at(0).ok, "base source refuses to decode")


func _bytecode_source_answers_ranges() -> void:
	var code := PackedByteArray([0x00, 0x11, 0x22, 0x33])
	var source: KakyuMesCodeSource = BytecodeSourceScript.new(code)
	_check(source.size() == code.size(), "bytecode source reports its size")
	_check(source.hex_range(0, 4) == "00112233", "bytecode source renders a hex range")
	_check(
		source.sha256_range(0, 4) == _sha256(code),
		"bytecode source fingerprints a range"
	)
	_check(
		source.sha256_range(0, 4) != CodeSourceScript.RANGE_UNAVAILABLE,
		"bytecode source does not refuse a range it holds"
	)


func _package_source_answers_only_recorded_ranges() -> void:
	var document := {
		"entry": "TEST.MES",
		"kind": "event",
		"code_size": 16,
		"code_sha256": "a".repeat(64),
		"address_table": [],
		"records": [],
	}
	var source: KakyuMesCodeSource = PackageSourceScript.new(document, [])
	_check(
		source.sha256_range(0, 16) == "a".repeat(64),
		"package source answers a recorded range"
	)
	_check(
		source.sha256_range(4, 12) == CodeSourceScript.RANGE_UNAVAILABLE,
		"package source refuses an unrecorded range"
	)
	_check(
		source.hex_range(0, 16) == CodeSourceScript.RANGE_UNAVAILABLE,
		"package source refuses every hex range"
	)


func _unanswerable_fingerprint_is_rejected_not_matched() -> void:
	# The concrete fail-open this contract closes. A definition body range the
	# source cannot fingerprint, checked against a definition whose recorded
	# fingerprint is absent, used to compare "" with "" and pass the guard.
	var source: KakyuMesCodeSource = PackageSourceScript.new(
		{
			"entry": "TEST.MES",
			"kind": "event",
			"code_size": 0x100,
			"code_sha256": "a".repeat(64),
			"address_table": [],
			"records": [],
		},
		[],
	)
	_check(
		source.sha256_range(0x20, 0x30) == CodeSourceScript.RANGE_UNAVAILABLE,
		"the definition body range is one this source cannot answer"
	)
	var boundary := {
		"status": "def_selection_boundary",
		"offset": 0x40,
		"trace": [
			{
				"command_id": 0x1D,
				"routine_id": 40,
				"source_offset": 0x40,
				"end_offset": 0x50,
			}
		],
		"definitions": [
			{
				"definition_id": 0,
				"source_offset": 0x10,
				"body_offset": 0x20,
				"target_offset": 0x30,
				"body_size": 0x10,
				"body_sha256": "",
			}
		],
	}
	var result: Dictionary = Routine40ContractScript.new().build(source, 0x100, boundary)
	_check(not result.get("ok", false), "an unanswerable body fingerprint fails closed")
	_check(
		str(result.get("error", "")).contains("cannot be fingerprinted"),
		"the refusal names the cause rather than reporting a changed fingerprint"
	)


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


func _package_decode_preserves_owned_intervals_and_limits() -> void:
	var source := PackageSourceScript.new({"entry": "OPAQUE.MES", "code_size": 12,
		"records": [{"at": 0, "end": 10, "op": "opaque_region", "bytes": 10},
			{"at": 4, "end": 5, "op": "script_return", "id": 0, "reached_by_transfer": true},
			{"at": 9, "end": 10, "op": "script_return", "id": 0},
			{"at": 11, "end": 12, "op": "script_return", "id": 0}]}, [])
	_check(not source.decode_at(0).ok, "opaque start refuses execution")
	_check(not source.decode_at_structural(2).ok, "opaque interior cannot skip to a transfer record")
	_check(source.decode_at(4).ok, "exact audited transfer inside a broad opaque interval remains supported")
	_check(source.decode_at(9).ok, "exact linear record remains owned when a separate transfer path becomes opaque over it")
	_check(not source.decode_at(6).ok, "earlier opaque ownership survives an intervening short transfer record")
	var proven_gap := PackageSourceScript.new({"entry": "PROVEN.MES", "code_size": 10,
		"records": [{"at": 0, "end": 10, "op": "opaque_region", "bytes": 10},
			{"at": 4, "end": 5, "op": "script_return", "id": 0}],
		"provenance_records": [{"at": 1, "end": 2}, {"at": 2, "end": 4}]}, [])
	_check(proven_gap.decode_at(1).ok and proven_gap.decode_at(2).ok, "a contiguous chain of exact dropped-provenance records resolves inside an overlapping opaque path")
	_check(not proven_gap.decode_at(3).ok, "the payload interior of a provenance record is not a command start")
	_check(source.decode_at(10).ok and int(source.decode_at(10).source_offset) == 11, "provenance gap after the owned interval still resolves forward")
	var run := RunnerScript.new().run(PackedByteArray(), 2, StateScript.new(), -1, 10, {"code_source": source})
	_check(not run.ok and run.trace.is_empty(), "runner refuses opaque interior before executing a command")
	var bounded := PackageSourceScript.new({"entry": "TEXT.MES", "code_size": 10,
		"records": [{"at": 0, "end": 10, "op": "text", "id": 1,
			"operands": [{"t": "text", "s": 0}]}]}, ["12345678"])
	var bytes := PackedByteArray([1])
	bytes.append_array("12345678".to_utf8_buffer())
	bytes.append(0)
	var byte_source := BytecodeSourceScript.new(bytes)
	_check(not bounded.decode_at_structural(0, 5).ok and not byte_source.decode_at_structural(0, 5).ok, "package and bytecode both refuse a record crossing the caller limit")
	_check(bounded.decode_at(0, 10).ok and byte_source.decode_at(0, 10).ok, "both sources accept a record ending exactly at the limit")
	run = RunnerScript.new().run(PackedByteArray(), 0, StateScript.new(), 5, 10, {"code_source": bounded})
	_check(not run.ok and run.messages.is_empty() and run.trace.is_empty(), "limit rejection happens before text reaches runner output")


## TD-64: the CP932 codec a package source re-encodes message text with is
## injected, so a package can give all of its sources one codec instead of one
## 0.88 MB encode map per entry. Sharing it must not change a single byte, and
## a source built without one gets a codec of its own.
func _package_source_text_codec_is_injected() -> void:
	# Written as escapes: halfwidth katakana A (U+FF71) is a single CP932 byte, the rest are
	# double-byte, so both widths pass through the encode map.
	var strings := ["日本語ｱAB", "ひらがな、"]
	var document := {"entry": "TEXT.MES", "code_size": 20,
		"records": [
			{"at": 0, "end": 10, "op": "text", "id": 1, "operands": [{"t": "text", "s": 0}]},
			{"at": 10, "end": 20, "op": "text", "id": 1, "operands": [{"t": "text", "s": 1}]}]}
	var shared := CodecScript.new()
	var first := PackageSourceScript.new(document, strings, shared)
	var second := PackageSourceScript.new(document, strings, shared)
	var fresh := PackageSourceScript.new(document, strings)
	_check(first._cp932 == shared and second._cp932 == shared, "a source uses the codec it is given")
	_check(fresh._cp932 != shared, "a source built without a codec does not take the given one")
	_check(
		PackageSourceScript.new(document, strings)._cp932 != fresh._cp932,
		"two sources built without a codec do not share one"
	)
	for index in range(strings.size()):
		var offset := index * 10
		var expected: Dictionary = CodecScript.new().encode(strings[index])
		_check(expected.ok and not (expected.data as PackedByteArray).is_empty(), "string %d encodes with a fresh codec" % index)
		var from_fresh: PackedByteArray = fresh.decode_at(offset).operands[0].raw_bytes
		var from_first: PackedByteArray = first.decode_at(offset).operands[0].raw_bytes
		var from_second: PackedByteArray = second.decode_at(offset).operands[0].raw_bytes
		_check(from_fresh == expected.data, "a source with its own codec encodes as a fresh codec does (string %d)" % index)
		_check(
			from_first == expected.data and from_second == expected.data,
			"two sources sharing one codec encode as a fresh codec does (string %d)" % index
		)
