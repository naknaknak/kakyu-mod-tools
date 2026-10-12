class_name KakyuMesPayloadFingerprint
extends RefCounted

## The canonical JSON payload fingerprint every versioned audit, plan and report
## in this repository identifies itself by.
##
## It lived in `mes_noop_compile_reopen.gd` until Core 0.294.0 because that is
## where it was first written. Forty-one modules preloaded a 326-line no-op
## compile-reopen auditor to reach it, and thirty-seven of them never called the
## auditor at all. TD-06 in `todo/code_health.md` records the measurement.


## SHA-256 of the canonical payload, excluding any `payload_sha256` the document
## already carries, so a document can name its own fingerprint.
func fingerprint(document: Dictionary) -> String:
	return sha256_bytes(canonical_payload_json(document).to_utf8_buffer())


## Sorted, fully-precise JSON with whole floats normalized to integers, so the
## same document fingerprints identically whether it came from a JSON file or
## was built in memory.
func canonical_payload_json(document: Dictionary) -> String:
	var payload := document.duplicate(true)
	payload.erase("payload_sha256")
	return canonical_document_json(payload)


## Canonical audit JSON retaining the root fingerprint for process transport.
## This is not the Python analyzer handoff's integer/float canonicalization.
func canonical_document_json(document: Dictionary) -> String:
	return JSON.stringify(_normalize_json_numbers(document), "", true, true)


func _normalize_json_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and float(value) == floor(float(value)):
		return int(value)
	if value is Array:
		var output: Array = []
		for child in value:
			output.append(_normalize_json_numbers(child))
		return output
	if value is Dictionary:
		var output := {}
		for key in value:
			output[key] = _normalize_json_numbers(value[key])
		return output
	return value


func sha256_bytes(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode()
