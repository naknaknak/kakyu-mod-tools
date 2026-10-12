extends SceneTree

# Command line front end for KakyuArcComparison.compare_archives. Opens two
# ARCs read-only (they may be the same file), compares every entry by name,
# optionally writes the path-free comparison report, and prints exactly one
# JSON summary line.

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcComparisonScript := preload("res://tools/content_suite/arc_comparison.gd")


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2 or arguments.size() > 3:
		_fail("Usage: compare_arcs.gd <left.arc> <right.arc> [<output.json>]")
		return
	var left_path := str(arguments[0])
	var right_path := str(arguments[1])
	var output_path := str(arguments[2]) if arguments.size() == 3 else ""

	var left_reader := ArcReaderScript.new()
	if not left_reader.open(left_path):
		_fail(left_reader.last_error)
		return
	var right_reader := ArcReaderScript.new()
	if not right_reader.open(right_path):
		left_reader.close()
		_fail(right_reader.last_error)
		return

	var compared := ArcComparisonScript.compare_archives(left_reader, right_reader)
	left_reader.close()
	right_reader.close()
	if not compared.get("ok", false):
		_fail(str(compared.get("error", "")))
		return
	var report: Dictionary = compared.report

	var path := ""
	if not output_path.is_empty():
		var written := ArcComparisonScript.write(report, output_path)
		if not written.get("ok", false):
			_fail(str(written.get("error", "")))
			return
		path = str(written.path)

	var summary: Dictionary = report.summary
	print(JSON.stringify({
		"ok": true,
		"identical": int(summary.identical),
		"changed": int(summary.changed),
		"only_left": int(summary.only_left),
		"only_right": int(summary.only_right),
		"total": int(summary.total),
		"order_preserved": bool(report.order_preserved),
		"path": path,
	}))
	quit(0)


func _fail(message: String) -> void:
	print(JSON.stringify({"ok": false, "error": message}))
	quit(1)
