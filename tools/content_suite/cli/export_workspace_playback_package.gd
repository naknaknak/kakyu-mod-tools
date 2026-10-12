extends SceneTree

const ExportScript := preload("res://tools/content_suite/workspace_playback_export.gd")
const SessionScript := preload("res://tools/content_suite/mes_authoring_session.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 5:
		push_error("Usage: SOURCE_ROOT WORKSPACE_ROOT EVENT_ID AUTHORING_BUNDLE_OR_DASH NEW_OUTPUT_DIRECTORY")
		quit(1)
		return
	var source := ProjectSettings.globalize_path(args[0]).simplify_path()
	var output := ProjectSettings.globalize_path(args[4]).simplify_path()
	if output.to_lower() == source.to_lower() or output.to_lower().begins_with(source.to_lower().trim_suffix("/") + "/"):
		push_error("Generated output must be outside the original content set.")
		quit(1)
		return
	var proofs := {}
	if args[3] != "-":
		var bundle := SessionScript.read_bundle(args[3])
		if not bundle.get("ok", false):
			push_error(str(bundle.get("error", "Authoring bundle was rejected.")))
			quit(1)
			return
		proofs[str(bundle.proof.source_identity.entry)] = bundle
	var exporter := ExportScript.new()
	var built := exporter.build_workspace(source, args[1], [args[2]], proofs)
	var serialized := exporter.serialize(built)
	var written := exporter.write(output, serialized)
	if not written.get("ok", false):
		print(JSON.stringify(written))
		quit(1)
		return
	print(JSON.stringify({"ok": true, "schema": serialized.manifest.schema,
		"package_sha256": serialized.manifest.package_sha256,
		"workspace_binding": serialized.manifest.workspace_binding}))
	quit()
