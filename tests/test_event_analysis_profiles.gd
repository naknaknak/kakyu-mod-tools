extends "res://tests/test_case.gd"

const ProfilesScript := preload("res://content_core/event_analysis_profiles.gd")
const PROFILES_DIR := "res://config/event_catalog/analysis_groups"


func _ready() -> void:
	var expected_count := 0
	var directory := DirAccess.open(PROFILES_DIR)
	for file_name in directory.get_files():
		if file_name.ends_with(".json"):
			expected_count += 1

	var profiles := ProfilesScript.new()
	var loaded: Dictionary = profiles.load_dir()
	_check(loaded.get("ok", false), "every tracked analysis-group profile loads")
	_check(int(loaded.get("count", -1)) == expected_count, "load_dir counts every tracked profile (%d)" % expected_count)

	var route: Dictionary = profiles.route("01m-d05", "01m-d05")
	_check(not route.is_empty() and str(route.get("route_id", "")) == "01m-d05", "route finds 01m-d05")
	_check(profiles.route("01m-d05", "not-a-route").is_empty(), "route rejects an unknown route id")
	_check(profiles.group("not-a-group").is_empty(), "group rejects an unknown group id")

	var group_document := profiles.group("01m-d05")
	var reference := {"group_id": "01m-d05", "profile_sha256": str(group_document.payload_sha256), "route_ids": ["01m-d05"]}
	var verified := profiles.verify(reference)
	_check(verified.get("ok", false), "verify accepts a tracked reference")

	var wrong_hash: Dictionary = reference.duplicate(true)
	wrong_hash.profile_sha256 = "0" + str(wrong_hash.profile_sha256).substr(1)
	_check(not profiles.verify(wrong_hash).get("ok", false), "verify rejects a wrong profile_sha256")

	var unknown_route: Dictionary = reference.duplicate(true)
	unknown_route.route_ids = ["not-a-route"]
	_check(not profiles.verify(unknown_route).get("ok", false), "verify rejects an unknown route id")

	# Owner ruling (2026-09-20, item 4): two tracked files may share a
	# group_id (real data: ground-h17-k09 v1/v2). load_dir must keep both;
	# group/route/verify resolve by the caller's exact hash when one is given.
	const V1_HASH := "d5c7214a0567383ab9c1f605d101e1b3f590f3ddea1116893e87b6b809b98c48"
	const V2_HASH := "d632822c0026b9a0dc745a576e1eb67a13a4cfbd4f2a9e8246eb18f7ea5194ba"
	var v1 := profiles.group("ground-h17-k09", V1_HASH)
	var v2 := profiles.group("ground-h17-k09", V2_HASH)
	_check(not v1.is_empty() and str(v1.payload_sha256) == V1_HASH, "group resolves the v1 profile by its exact hash")
	_check(not v2.is_empty() and str(v2.payload_sha256) == V2_HASH, "group resolves the v2 profile by its exact hash")
	_check(profiles.group("ground-h17-k09", "0".repeat(64)).is_empty(), "group rejects a hash neither tracked file carries")
	var first := profiles.group("ground-h17-k09")
	_check(not first.is_empty() and (str(first.payload_sha256) == V1_HASH or str(first.payload_sha256) == V2_HASH), "group with no hash returns one of the tracked profiles")
	_check(not profiles.route("ground-h17-k09", "eventh17", V1_HASH).is_empty(), "route finds eventh17 in the v1 profile by hash")
	_check(not profiles.route("ground-h17-k09", "eventk09", V2_HASH).is_empty(), "route finds eventk09 in the v2 profile by hash")
	_check(profiles.verify({"group_id": "ground-h17-k09", "profile_sha256": V1_HASH, "route_ids": ["eventh17", "eventk09"]}).get("ok", false), "verify accepts the v1 reference even though v2 shares the group_id")
	_check(profiles.verify({"group_id": "ground-h17-k09", "profile_sha256": V2_HASH, "route_ids": ["eventh17", "eventk09"]}).get("ok", false), "verify accepts the v2 reference even though v1 shares the group_id")

	get_tree().quit(1 if _failed else 0)
