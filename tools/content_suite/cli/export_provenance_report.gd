extends SceneTree

const ProvenanceReportScript := preload("res://tools/content_suite/provenance_report.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Usage: CONTENT_SET_ROOT WORKSPACE_ROOT OUTPUT.JSON")
		quit(1)
		return
	var content_set_root := args[0]
	var workspace_root := args[1]
	var output_path := args[2]
	var built := ProvenanceReportScript.build(workspace_root, content_set_root)
	if not built.get("ok", false):
		print(JSON.stringify({"ok": false, "error": str(built.get("error", "Provenance report could not be built."))}))
		quit(1)
		return
	var written := ProvenanceReportScript.write(built.report, output_path)
	if not written.get("ok", false):
		print(JSON.stringify({"ok": false, "error": str(written.get("error", "Provenance report could not be written."))}))
		quit(1)
		return
	var report: Dictionary = built.report
	print(JSON.stringify({
		"ok": true,
		"path": str(written.path),
		"sha256": str(written.sha256),
		"replacements": report.replacements.size(),
		"projections": report.projections.size(),
		"declared": str(report.compatibility.declared),
	}))
	quit()
