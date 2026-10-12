class_name KakyuMesAuthoringBinding
extends RefCounted

const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ProofScript := preload("res://content_core/mes_semantic_diff.gd")
const ChainScript := preload("res://content_core/mes_semantic_diff_chain.gd")
static var _cache: Dictionary = {}


static func bind(source: PackedByteArray, output: PackedByteArray, proof: Dictionary) -> Dictionary:
	if not ProofScript.new().validate(proof).get("ok", false) or str(proof.get("schema", "")) != "kakyu_mes_semantic_diff/v4":
		return _error("Message relocation requires its validated semantic proof.")
	var source_sha := FingerprintScript.new().sha256_bytes(source)
	var output_sha := FingerprintScript.new().sha256_bytes(output)
	if output_sha != str(proof.output_binding.entry_sha256):
		return _error("Relocation output bytes differ from the proof.")
	var key := source_sha + output_sha + str(proof.payload_sha256)
	if _cache.has(key):
		return _cache[key].duplicate(true)
	var runtime := preload("res://tools/content_suite/python_runtime.gd").resolve("tools/mes_authoring_binding.py")
	if not runtime.get("ok", false):
		return runtime
	var python := str(runtime.python)
	var root := ProjectSettings.globalize_path("user://authoring-bind-" + Crypto.new().generate_random_bytes(16).hex_encode())
	if DirAccess.make_dir_absolute(root) != OK:
		return _error("A local relocation verification directory could not be created.")
	var files := {"source.mes": source, "output.mes": output,
		"proof.json": (FingerprintScript.new().canonical_document_json(proof) + "\n").to_utf8_buffer()}
	var write_ok := true
	for name in files:
		var file := FileAccess.open(root.path_join(str(name)), FileAccess.WRITE)
		if file == null:
			write_ok = false
			break
		file.store_buffer(files[name])
		file.close()
	var report := root.path_join("report.json")
	var logs: Array = []
	var code := OS.execute(python, PackedStringArray([
		"-B", str(runtime.script), root.path_join("source.mes"),
		root.path_join("output.mes"), root.path_join("proof.json"), report]), logs, true, false) if write_ok else -1
	var result = JSON.parse_string(FileAccess.get_file_as_string(report)) if FileAccess.file_exists(report) else null
	for name in ["source.mes", "output.mes", "proof.json", "report.json"]:
		if FileAccess.file_exists(root.path_join(name)):
			DirAccess.remove_absolute(root.path_join(name))
	DirAccess.remove_absolute(root)
	if not result is Dictionary or code != 0 or result.get("ok") != true:
		return _error(str(result.get("error", "Relocation proof reconstruction failed.")) if result is Dictionary else "Relocation proof reconstruction produced no report.")
	if str(result.get("schema", "")) != "kakyu_mes_authoring_binding/v1" or str(result.get("source_entry_sha256", "")) != source_sha or str(result.get("output_entry_sha256", "")) != output_sha or str(result.get("semantic_diff_sha256", "")) != str(proof.payload_sha256) or str(result.get("payload_sha256", "")) != FingerprintScript.new().fingerprint(result):
		return _error("Relocation verification report differs from its exact inputs.")
	if _cache.size() >= 8:
		_cache.clear()
	_cache[key] = result.duplicate(true)
	return result


static func find_proof(root: String, source_sha: String, output_sha: String) -> Dictionary:
	var candidates: Array[String] = [root.path_join(".authoring/delta")]
	var authoring := root.path_join("authoring")
	if DirAccess.dir_exists_absolute(authoring):
		for name in DirAccess.get_directories_at(authoring):
			candidates.append(authoring.path_join(name))
	for directory in candidates:
		var manifest_path := directory.path_join("manifest.json")
		if not FileAccess.file_exists(manifest_path):
			continue
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if not manifest is Dictionary or not manifest.get("summary") is Dictionary:
			continue
		if manifest.summary.get("source_entry_sha256") != source_sha or manifest.summary.get("output_entry_sha256") != output_sha:
			continue
		var path := directory.path_join("semantic.diff.json")
		var proof = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if not proof is Dictionary:
			continue
		if str(proof.get("schema", "")) == ChainScript.SCHEMA:
			if ChainScript.new().validate(proof).get("ok", false) and proof.output_binding.entry_sha256 == output_sha:
				return {"ok": true, "proof": proof, "path": path, "directory": directory}
		elif ProofScript.new().validate(proof).get("ok", false) and proof.output_binding.entry_sha256 == output_sha:
			return {"ok": true, "proof": proof, "path": path, "directory": directory}
	return _error("No local authoring proof matches this original and replacement.")


static func mapped_offset(binding: Dictionary, source_offset: int) -> int:
	for point in binding.get("points", []):
		if int(point.source) == source_offset:
			return int(point.output)
	return -1


static func map_route(route: Dictionary, binding: Dictionary) -> Dictionary:
	var mapped := route.duplicate(true)
	var resumes: Array[Dictionary] = []
	var entry := str(route.entry).to_upper()
	mapped.start_coordinate = mapped_offset(binding, int(route.start_coordinate))
	if int(mapped.start_coordinate) < 0:
		return _error("The catalog start is not a mapped instruction boundary.")
	for choice in mapped.choices:
		if str(choice.owner_entry).to_upper() == entry:
			choice.boundary_offset = mapped_offset(binding, int(choice.boundary_offset))
			if int(choice.boundary_offset) < 0:
				return _error("A catalog choice is not a mapped instruction boundary.")
	for terminal in mapped.terminals:
		var source_resume := int(terminal.caller_resume_offset)
		var resume_owner := str(route.get("caller_entry", "")) if str(terminal.kind) == "callee_return_only" else str(terminal.owner_entry)
		if str(terminal.owner_entry).to_upper() == entry:
			terminal.offset = mapped_offset(binding, int(terminal.offset))
			if int(terminal.offset) < 0:
				return _error("A catalog terminal is not a mapped instruction boundary.")
		if resume_owner.to_upper() == entry:
			var output_resume := mapped_offset(binding, source_resume)
			if output_resume < 0:
				for point in binding.get("points", []):
					if int(point.source_end) == source_resume:
						output_resume = int(point.output_end)
						break
			if output_resume < 0:
				return _error("A terminal resume is not a mapped record start or end.")
			terminal.caller_resume_offset = output_resume
		if resume_owner.is_empty():
			return _error("The terminal resume owner is unresolved.")
		resumes.append({"terminal_id": terminal.terminal_id, "owner": resume_owner, "source": source_resume, "output": int(terminal.caller_resume_offset)})
	return {"ok": true, "route": mapped, "resume_points": resumes}


static func map_text(messages: Dictionary, binding: Dictionary) -> Dictionary:
	var output := {}
	for offset in messages:
		var found := false
		for row in binding.get("messages", []):
			if int(row.source) != int(offset):
				continue
			var message: Dictionary = messages[offset]
			if str(message.get("raw_sha256", "")) != str(row.source_raw_sha256) or str(row.source_raw_sha256) != str(row.output_raw_sha256):
				return _error("An existing translation overlaps a replaced message; remove that translation before structural publication.")
			output[int(row.output)] = message.duplicate(true)
			found = true
			break
		if not found:
			return _error("A translation has no proven message coordinate mapping.")
	return {"ok": true, "messages": output}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
