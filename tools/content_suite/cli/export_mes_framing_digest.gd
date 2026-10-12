extends "res://tools/content_suite/cli_script.gd"

# Emit the authoritative record framing of every MES entry, one JSON object per
# line, so a decoder written in another language can be measured against it.
#
# Phase 2's gate is that every consumed instruction or compound native record
# has one exact [start, end) range. That range set is what MA-09's authority
# actually is, so it is the thing an equivalence measurement has to compare -
# not a rendered document, and not a schema.
#
# The framing is written as a canonical line list rather than a structure, so
# both sides can hash it identically and a divergence names one coordinate:
#
#   i <start> <end>    one decoded instruction, code-relative, decimal
#   o <start> <end>    the undecoded remainder of a region, byte-preserving
#
# Regions are the container's own: the bootstrap prefix when it has bytes, then
# the address-table entries in index order. An empty bootstrap emits nothing,
# so a decoder that always seeds a bootstrap node still agrees.
#
# Usage:
#   export_mes_framing_digest.gd <mes.arc> <output.jsonl> [entry-name ...]

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesInstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")

const SCHEMA := "kakyu_mes_framing_digest/v1"
const MAX_INSTRUCTIONS := 100000


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2:
		_fail("Usage: export_mes_framing_digest.gd <mes.arc> <output.jsonl> [entry ...]", 2)
		return
	var archive_path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var output_path := ProjectSettings.globalize_path(str(arguments[1])).simplify_path()
	var selected := {}
	for index in range(2, arguments.size()):
		selected[str(arguments[index]).to_upper()] = true

	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		_fail(reader.last_error, 1)
		return
	var archive_sha256 := reader.get_archive_fingerprint()

	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		reader.close()
		_fail("Framing digest output cannot be written: %s" % output_path, 2)
		return

	var parser := MesContainerScript.new()
	var decoder := MesInstructionDecoderScript.new()
	var written := 0
	var failed := 0
	var instruction_total := 0
	var opaque_total := 0

	file.store_line(JSON.stringify({
		"schema": SCHEMA,
		"kind": "header",
		"archive_sha256": archive_sha256,
		"entry_count": reader.get_entries().size(),
		"selected_count": selected.size(),
		"decode_mode": "aligned_strict",
	}))

	for untyped_entry in reader.get_entries():
		var entry: Dictionary = untyped_entry
		var entry_name := str(entry.name)
		if not selected.is_empty() and not selected.has(entry_name.to_upper()):
			continue
		var row := _frame_entry(reader, parser, decoder, entry_name)
		if not row.get("ok", false):
			failed += 1
		else:
			instruction_total += int(row.instruction_count)
			opaque_total += int(row.opaque_count)
		file.store_line(JSON.stringify(row))
		written += 1

	file.close()
	reader.close()
	print(
		"MES_FRAMING_DIGEST_WRITTEN ",
		"schema=", SCHEMA,
		" archive_sha256=", archive_sha256,
		" entries=", written,
		" failed=", failed,
		" instructions=", instruction_total,
		" opaque=", opaque_total,
	)
	quit(1 if failed > 0 and written == failed else 0)


func _frame_entry(
	reader,
	parser,
	decoder,
	entry_name: String
) -> Dictionary:
	var payload: PackedByteArray = reader.read_entry(entry_name)
	if payload.is_empty():
		return _entry_error(entry_name, "Entry payload could not be read.")
	var document: Dictionary = parser.parse(payload)
	if not document.get("ok", false):
		return _entry_error(entry_name, str(document.get("error", "Container parse failed.")))

	var code: PackedByteArray = document.bytecode
	var lines: Array[String] = []
	var instruction_count := 0
	var opaque_count := 0
	var decoded_bytes := 0

	for region in _regions(document):
		var decoded: Dictionary = decoder.decode_region_aligned(
			code, int(region.offset), int(region.end_offset), MAX_INSTRUCTIONS
		)
		for untyped_instruction in decoded.instructions:
			var instruction: Dictionary = untyped_instruction
			var start := int(instruction.source_offset)
			var end := int(instruction.end_offset)
			lines.append("i %d %d" % [start, end])
			instruction_count += 1
			decoded_bytes += end - start
		if not decoded.get("ok", false):
			var opaque_start := int(decoded.decoded_end_offset)
			var opaque_end := int(region.end_offset)
			if opaque_end > opaque_start:
				lines.append("o %d %d" % [opaque_start, opaque_end])
				opaque_count += 1

	var framing := "\n".join(lines)
	return {
		"ok": true,
		"schema": SCHEMA,
		"kind": "entry",
		"entry": entry_name,
		"entry_sha256": reader.get_entry_fingerprint(entry_name),
		"code_size": code.size(),
		"region_count": _regions(document).size(),
		"instruction_count": instruction_count,
		"opaque_count": opaque_count,
		"decoded_bytes": decoded_bytes,
		"framing_sha256": _sha256_text(framing),
		"framing": framing,
	}


func _regions(document: Dictionary) -> Array[Dictionary]:
	var regions: Array[Dictionary] = []
	var bootstrap: Dictionary = document.get("bootstrap", {})
	if int(bootstrap.get("size", 0)) > 0:
		regions.append({
			"id": "bootstrap",
			"offset": int(bootstrap.offset),
			"end_offset": int(bootstrap.end_offset),
		})
	for untyped_entry in document.get("entries", []):
		var entry: Dictionary = untyped_entry
		regions.append({
			"id": str(entry.id),
			"offset": int(entry.offset),
			"end_offset": int(entry.end_offset),
		})
	return regions


func _entry_error(entry_name: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"schema": SCHEMA,
		"kind": "entry",
		"entry": entry_name,
		"error": message,
	}


func _sha256_text(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()
