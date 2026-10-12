class_name KakyuContentIdentity
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const CONTENT_KINDS := ["image", "animation", "audio", "map_layout", "mes_control_flow"]
const COMPATIBILITY_VALUES := [
	"remake_only", "original_engine_compatible", "original_engine_unverified", "mixed",
]


func classify(
	evidence: Dictionary,
	original_reader,
	descriptor: Dictionary,
	effective_data: PackedByteArray,
	interface_validation: Dictionary
) -> Dictionary:
	var checked := _validate_inputs(evidence, original_reader, descriptor, effective_data, interface_validation)
	if not checked.ok:
		return checked
	var source := str(descriptor.source)
	var content_kind := str(evidence.content_kind)
	var effective_sha := OverlayPackageScript.sha256_bytes(effective_data)
	var changed := effective_sha != str(evidence.original_entry_sha256)
	var compatibility := "original_engine_compatible"
	var relationship := "exact_original"
	var verified := true
	var reason := "Effective bytes are the audited original entry."
	if source == "overlay":
		compatibility = str(descriptor.compatibility)
		relationship = "original_derived_compatible" if compatibility == "original_engine_compatible" else "remake_only"
		reason = "The effective overlay is bound to the audited original archive and entry."
	elif source == "materialized_arc":
		compatibility = str(descriptor.compatibility)
		relationship = "original_derived_compatible" if compatibility == "original_engine_compatible" else "remake_only"
		reason = "The effective ARC entry has verified original-derived provenance."
	elif source == "fallback":
		compatibility = "remake_only"
		relationship = "remake_only"
		verified = false
		reason = "Fallback content has no original-derived payload binding."
	if changed and content_kind == "mes_control_flow" and not bool(interface_validation.get("control_flow_compatible", false)):
		return _unsupported(evidence, descriptor, effective_sha, effective_data.size(), interface_validation, "Changed MES control flow requires a versioned compatible-interface proof.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.CONTENT_IDENTITY_SCHEMA,
		"relationship": relationship,
		"label": _relationship_label(relationship),
		"verified": verified,
		"route_evidence_preserved": content_kind != "mes_control_flow" or not changed or bool(interface_validation.get("control_flow_compatible", false)),
		"changed": changed,
		"compatibility": compatibility,
		"reason": reason,
		"evidence": {
			"archive": str(evidence.archive).to_lower(),
			"entry": str(evidence.entry),
			"original_archive_sha256": str(evidence.original_archive_sha256),
			"original_entry_sha256": str(evidence.original_entry_sha256),
			"content_kind": content_kind,
		},
		"effective": {
			"source": source,
			"archive": str(descriptor.archive).to_lower(),
			"entry": str(descriptor.entry),
			"sha256": effective_sha,
			"bytes": effective_data.size(),
		},
		"interface": interface_validation.duplicate(true),
	}


func _validate_inputs(evidence: Dictionary, original_reader, descriptor: Dictionary, effective_data: PackedByteArray, interface_validation: Dictionary) -> Dictionary:
	for key in ["archive", "entry", "original_archive_sha256", "original_entry_sha256", "content_kind"]:
		if not evidence.has(key):
			return _error("Content evidence is incomplete: %s" % key)
	var archive_name := str(evidence.archive).to_lower()
	var entry_name := str(evidence.entry)
	if not ArcReaderScript.is_safe_entry_name(archive_name) or archive_name.get_extension() != "arc" or not ArcReaderScript.is_safe_entry_name(entry_name) or str(evidence.content_kind) not in CONTENT_KINDS:
		return _error("Content evidence identity is invalid.")
	if not ContractValues.is_sha256(str(evidence.original_archive_sha256)) or not ContractValues.is_sha256(str(evidence.original_entry_sha256)):
		return _error("Content evidence hashes are invalid.")
	if original_reader == null or not original_reader.is_open():
		return _error("Content evidence requires the selected original ARC reader.")
	if original_reader.get_archive_identity_fingerprint() != str(evidence.original_archive_sha256) or original_reader.get_entry_fingerprint(entry_name) != str(evidence.original_entry_sha256):
		return _error("Selected original ARC/entry no longer matches route evidence.")
	if not descriptor.get("ok", false) or str(descriptor.get("archive", "")).to_lower() != archive_name or str(descriptor.get("entry", "")).to_upper() != entry_name.to_upper():
		return _error("Effective descriptor does not match the evidenced logical entry.")
	if not interface_validation.get("ok", false) or str(interface_validation.get("schema", "")).is_empty():
		return _error("Effective content did not pass a versioned interface validation.")
	var effective_sha := OverlayPackageScript.sha256_bytes(effective_data)
	match str(descriptor.source):
		"original_arc":
			if effective_sha != str(evidence.original_entry_sha256):
				return _error("Resolved original entry bytes do not match route evidence.")
		"overlay":
			if str(descriptor.get("base_archive_sha256", "")) != str(evidence.original_archive_sha256) or str(descriptor.get("original_entry_sha256", "")) != str(evidence.original_entry_sha256) or str(descriptor.get("sha256", "")) != effective_sha or str(descriptor.get("compatibility", "")) not in COMPATIBILITY_VALUES:
				return _error("Overlay payload is not bound to the evidenced original entry.")
		"materialized_arc":
			if str(descriptor.get("lineage_classification", "")) != "verified_original_derived" or str(descriptor.get("source_archive_sha256", "")) != str(evidence.original_archive_sha256) or str(descriptor.get("original_entry_sha256", "")) != str(evidence.original_entry_sha256) or str(descriptor.get("sha256", "")) != effective_sha or str(descriptor.get("compatibility", "")) not in COMPATIBILITY_VALUES:
				return _error("Materialized ARC payload lacks verified original-derived lineage.")
		"fallback":
			if str(descriptor.get("sha256", "")) != effective_sha:
				return _error("Fallback payload changed after resolution.")
		_:
			return _error("Effective content source is unsupported.")
	return {"ok": true}


func _unsupported(evidence: Dictionary, descriptor: Dictionary, effective_sha: String, effective_size: int, interface_validation: Dictionary, reason: String) -> Dictionary:
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.CONTENT_IDENTITY_SCHEMA,
		"relationship": "unsupported",
		"label": "Unsupported",
		"verified": false,
		"route_evidence_preserved": false,
		"changed": true,
		"compatibility": str(descriptor.get("compatibility", "remake_only")),
		"reason": reason,
		"evidence": evidence.duplicate(true),
		"effective": {
			"source": str(descriptor.get("source", "")),
			"archive": str(descriptor.get("archive", "")).to_lower(),
			"entry": str(descriptor.get("entry", "")),
			"sha256": effective_sha,
			"bytes": effective_size,
		},
		"interface": interface_validation.duplicate(true),
	}


func _relationship_label(relationship: String) -> String:
	match relationship:
		"exact_original": return "Exact original"
		"original_derived_compatible": return "Original-derived compatible"
		"remake_only": return "Remake-only"
		_: return "Unsupported"


func _error(message: String) -> Dictionary:
	return {"ok": false, "schema": ContentCoreVersionScript.CONTENT_IDENTITY_SCHEMA, "error": message}
