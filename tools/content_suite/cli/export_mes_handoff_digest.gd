extends "res://tools/content_suite/cli_script.gd"

# Emit the authoritative analyzer handoff of every MES/LIB entry as per-component
# fingerprints, so a handoff built in another language can be measured against it.
#
# The Phase 1-4 authority is MA-09's frozen corpus fingerprint, which is the
# SHA-256 over one `<name>\t<entry_sha256>\t<payload_sha256>` line per entry.
# Reproducing it in Python is one boolean, and a boolean cannot plan work: a
# single wrong field in one instruction of one entry reports the same failure as
# having no producer at all.
#
# So this exports the same fingerprint *and* one fingerprint per handoff
# component, computed under the handoff's own normalization rule. A divergence
# then names the component that carries it, and the counts beside each component
# say how much of it there is. Full payloads are deliberately not exported: the
# typed IR alone is millions of instructions, and the comparison does not need
# the bytes, only agreement.
#
# Usage:
#   export_mes_handoff_digest.gd <mes.arc> <output.jsonl> [entry-name ...]

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const SCHEMA := "kakyu_mes_handoff_digest/v1"

# The components a consumer has to reproduce, in the order they are hardest to
# fake: the container is arithmetic over the header, the typed IR is the whole
# decoder, and the references are the analysis index on top of it.
const COMPONENTS := [
	"container",
	"record_alignment",
	"typed_ir",
	"references",
	"capability_report",
]


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2:
		_fail("Usage: export_mes_handoff_digest.gd <mes.arc> <output.jsonl> [entry ...]", 2)
		return
	var archive_path := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var output_path := ProjectSettings.globalize_path(str(arguments[1])).simplify_path()
	var selected := {}
	for index in range(2, arguments.size()):
		selected[str(arguments[index]).to_upper()] = true

	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		_fail(reader.last_error)
		return
	var archive_sha := reader.get_archive_fingerprint()
	var parser := MesContainerScript.new()
	var analysis_builder := MesAnalysisScript.new()
	var handoff_builder := AnalyzerHandoffScript.new()

	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		reader.close()
		_fail("Cannot write %s" % output_path)
		return
	file.store_line(JSON.stringify({
		"schema": SCHEMA,
		"kind": "header",
		"archive_sha256": archive_sha,
		"handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		"components": COMPONENTS,
	}, "", true, true))

	var entry_count := 0
	var failed := 0
	var corpus_fingerprint_input := PackedByteArray()
	for untyped_entry in reader.get_entries():
		var entry: Dictionary = untyped_entry
		var entry_name := str(entry.name)
		if entry_name.get_extension().to_lower() not in ["mes", "lib"]:
			continue
		if not selected.is_empty() and not selected.has(entry_name.to_upper()):
			continue
		var document := parser.parse(reader.read_entry(entry_name), {
			"archive": reader.archive_path.replace("\\", "/").get_file(),
			"entry": entry_name,
			"archive_sha256": archive_sha,
		})
		if not document.get("ok", false):
			failed += 1
			file.store_line(JSON.stringify({
				"kind": "entry",
				"entry": entry_name,
				"ok": false,
				"error": str(document.get("error", "container failed")),
			}, "", true, true))
			continue
		var analysis := analysis_builder.build(document)
		var handoff := handoff_builder.build(document, analysis)
		if not handoff_builder.verify(handoff).get("ok", false):
			failed += 1
			file.store_line(JSON.stringify({
				"kind": "entry",
				"entry": entry_name,
				"ok": false,
				"error": str(handoff.get("error", "handoff failed")),
			}, "", true, true))
			continue
		entry_count += 1
		var row := {
			"kind": "entry",
			"entry": entry_name,
			"ok": true,
			"entry_sha256": str(handoff.container.entry_sha256),
			"payload_sha256": str(handoff.payload_sha256),
			"components": _component_fingerprints(handoff),
			"counts": _component_counts(handoff),
		}
		file.store_line(JSON.stringify(row, "", true, true))
		corpus_fingerprint_input.append_array(
			("%s\t%s\t%s\n" % [
				entry_name,
				str(handoff.container.entry_sha256),
				str(handoff.payload_sha256),
			]).to_utf8_buffer()
		)
	file.store_line(JSON.stringify({
		"kind": "footer",
		"entry_count": entry_count,
		"failed": failed,
		"corpus_handoff_sha256": ContractValues.sha256(corpus_fingerprint_input),
	}, "", true, true))
	file.close()
	reader.close()
	print(
		"MES_HANDOFF_DIGEST_WRITTEN schema=%s archive_sha256=%s entries=%d failed=%d corpus=%s"
		% [SCHEMA, archive_sha, entry_count, failed, ContractValues.sha256(corpus_fingerprint_input)]
	)
	quit(1 if failed > 0 else 0)


func _component_fingerprints(handoff: Dictionary) -> Dictionary:
	var fingerprints := {}
	for name in COMPONENTS:
		fingerprints[name] = _fingerprint(handoff.get(name, null))
	# The references component is four independent lists, and a consumer will
	# reach them at different times, so each is separately addressable.
	var references: Dictionary = handoff.get("references", {})
	for key in ["messages", "code", "state", "resources"]:
		fingerprints["references.%s" % key] = _fingerprint(references.get(key, []))
	return fingerprints


func _component_counts(handoff: Dictionary) -> Dictionary:
	var references: Dictionary = handoff.get("references", {})
	var typed_ir: Dictionary = handoff.get("typed_ir", {})
	var alignment: Dictionary = handoff.get("record_alignment", {})
	return {
		"entries": int((handoff.container.entries as Array).size()),
		"code_size": int(handoff.container.header.code_size),
		"instructions": int((typed_ir.get("instructions", []) as Array).size()),
		"diagnostics": int((typed_ir.get("diagnostics", []) as Array).size()),
		"opaque_boundaries": int((typed_ir.get("opaque_boundaries", []) as Array).size()),
		"messages": int((references.get("messages", []) as Array).size()),
		"code_references": int((references.get("code", []) as Array).size()),
		"state_references": int((references.get("state", []) as Array).size()),
		"resource_references": int((references.get("resources", []) as Array).size()),
		"alignment_instructions": int(alignment.get("instruction_count", -1)),
		"alignment_compound_records": int(alignment.get("compound_record_count", -1)),
		"alignment_opaque_boundaries": int(alignment.get("opaque_boundary_count", -1)),
	}


func _fingerprint(value: Variant) -> String:
	# The handoff's own normalization, so a component fingerprint is a slice of
	# the payload fingerprint rather than a second, differently-shaped hash.
	return ContractValues.sha256(JSON.stringify(_normalize(value), "", true, true).to_utf8_buffer())


func _normalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			return {"$packed_byte_array_hex": (value as PackedByteArray).hex_encode()}
		TYPE_ARRAY:
			var output: Array = []
			for child in value as Array:
				output.append(_normalize(child))
			return output
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			var keys: Array[String] = []
			var value_by_key := {}
			for key in dictionary:
				var encoded_key := str(key)
				keys.append(encoded_key)
				value_by_key[encoded_key] = dictionary[key]
			keys.sort()
			var output := {}
			for key in keys:
				output[key] = _normalize(value_by_key[key])
			return output
		_:
			return value
