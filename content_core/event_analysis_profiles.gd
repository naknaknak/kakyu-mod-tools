class_name KakyuEventAnalysisProfiles
extends RefCounted

## EP-10 unit 2: the analysis-group profiles as the Event Player's runtime
## authority for the routes unit 1 promoted into the catalog. `load_dir`
## loads every tracked profile once; `group`/`route` answer by id (and,
## when given, an exact `payload_sha256`) from that loaded set; `verify`
## checks a catalog `analysis_group.groups[i]` reference against whichever
## loaded profile it names. Two tracked files may share a `group_id` (real
## data: `ground-h17-k09` v1/v2), so every group_id keeps every profile that
## names it, not just the last one loaded.

var _groups_by_id: Dictionary = {}


func load_dir(path := "res://config/event_catalog/analysis_groups") -> Dictionary:
	_groups_by_id.clear()
	var directory := DirAccess.open(path)
	if directory == null:
		return {"ok": false, "count": 0, "error": "Analysis group profile directory is unavailable: %s" % path}
	var names: Array[String] = []
	for file_name in directory.get_files():
		if file_name.ends_with(".json"):
			names.append(file_name)
	names.sort()
	var count := 0
	for file_name in names:
		var file := FileAccess.open(path.path_join(file_name), FileAccess.READ)
		if file == null:
			return {"ok": false, "count": count, "error": "Analysis group profile could not be read: %s" % file_name}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not parsed is Dictionary or str((parsed as Dictionary).get("group_id", "")).is_empty():
			return {"ok": false, "count": count, "error": "Analysis group profile is malformed: %s" % file_name}
		var group_id := str((parsed as Dictionary).group_id)
		var bucket: Array = _groups_by_id.get(group_id, [])
		bucket.append(parsed)
		_groups_by_id[group_id] = bucket
		count += 1
	return {"ok": true, "count": count, "error": ""}


## The loaded profile document itself, not a copy - round 9 code review:
## callers must treat the returned Dictionary (and `route`'s) as read-only;
## mutating it would corrupt every other caller's view of the same loaded
## profile.
func group(group_id: String, profile_sha256 := "") -> Dictionary:
	var bucket: Array = _groups_by_id.get(group_id, [])
	if bucket.is_empty():
		return {}
	if profile_sha256.is_empty():
		return bucket[0]
	for candidate_value in bucket:
		var candidate: Dictionary = candidate_value
		if str(candidate.get("payload_sha256", "")) == profile_sha256:
			return candidate
	return {}


## Read-only - see `group`.
func route(group_id: String, route_id: String, profile_sha256 := "") -> Dictionary:
	var group_document := group(group_id, profile_sha256)
	if group_document.is_empty():
		return {}
	for route_value in group_document.get("routes", []):
		if not route_value is Dictionary:
			continue
		if str((route_value as Dictionary).get("route_id", "")) == route_id:
			return route_value
	return {}


func verify(group_ref: Dictionary) -> Dictionary:
	var group_id := str(group_ref.get("group_id", ""))
	var expected_hash := str(group_ref.get("profile_sha256", ""))
	var bucket: Array = _groups_by_id.get(group_id, [])
	if bucket.is_empty():
		return {"ok": false, "error": "Analysis group is not loaded: %s" % group_id}
	var matched: Dictionary = {}
	for candidate_value in bucket:
		var candidate: Dictionary = candidate_value
		if str(candidate.get("payload_sha256", "")) == expected_hash:
			matched = candidate
			break
	if matched.is_empty():
		return {"ok": false, "error": "Analysis group profile hash changed: %s" % group_id}
	var route_ids: Array = []
	for route_value in matched.get("routes", []):
		if route_value is Dictionary:
			route_ids.append(str((route_value as Dictionary).get("route_id", "")))
	for requested_id in group_ref.get("route_ids", []):
		if not route_ids.has(str(requested_id)):
			return {"ok": false, "error": "Analysis group route is not in the loaded profile: %s" % str(requested_id)}
	return {"ok": true, "error": ""}
