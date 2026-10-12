class_name KakyuEventOutcomeVocabulary
extends RefCounted

## EP-09: the game-outcome vocabulary (owner ruling of 2026-09-20). Port of
## `tools/event_outcome_vocabulary.py` functions 1 (`v4_terminal_outcome`),
## 4 (`catalog_route_outcome`), 5 (`catalog_terminal_outcome`) and 8
## (`phrase`), with identical outputs, for the Event Player
## (`_show_catalog_terminal_result`). See
## `analysis/_docs/ep09_outcome_vocab_spec.md` for the full rule table.

const GAME_OUTCOMES := ["map_return", "place_menu", "chain", "not_triggered", "unresolved"]

const MAP_ENTRIES := {
	"MACHI.MES": "town",
	"GROUND.MES": "campus",
	"TRAIN.MES": "train",
	"FLOOR1.MES": "school floor 1",
	"FLOOR2.MES": "school floor 2",
	"FLOOR3.MES": "school floor 3",
	"FLOOR4.MES": "school floor 4",
	"FLOOR5.MES": "school floor 5",
}


static func _map_label(target) -> String:
	return str(MAP_ENTRIES.get(str(target).to_upper(), ""))


static func _record(outcome: String, postlude: String = "", next_target: String = "", map_label: String = "", reason: String = "") -> Dictionary:
	return {
		"outcome": outcome,
		"postlude": postlude,
		"next_target": next_target,
		"map": map_label,
		"reason": reason,
	}


## A `terminals[...]` value of a v4 document (`kind`, `next_target`).
static func v4_terminal_outcome(terminal: Dictionary) -> Dictionary:
	var kind := str(terminal.get("kind", ""))
	var next_target := str(terminal.get("next_target", ""))
	var label := _map_label(next_target)
	if kind == "root_handoff":
		if not label.is_empty():
			return _record("map_return", "event", next_target, label)
		return _record("chain", "", next_target)
	if kind == "natural_handoff":
		if not label.is_empty():
			return _record("map_return", "place", next_target, label)
		return _record("chain", "", next_target)
	if kind == "def_selection_boundary" or kind == "caller_menu_loop":
		return _record("place_menu")
	if kind == "dependency_stop":
		return _record("unresolved", "", "", "", "dependency_stop")
	if kind == "callee_return":
		return _record("unresolved", "", "", "", "continuation_undeclared")
	return _record("unresolved", "", "", "", "unknown_kind:%s" % kind)


## Per-`kind` rules shared by `catalog_route_outcome` (over the last terminal
## of a route) and `catalog_terminal_outcome` (over one matched terminal,
## which is always its own "last terminal").
static func _catalog_kind_outcome(terminal: Dictionary) -> Dictionary:
	var kind := str(terminal.get("kind", ""))
	var next_target := str(terminal.get("next_target", ""))
	var label := _map_label(next_target)
	if kind == "caller_handoff" or kind == "root_replacement" or kind == "normal_completion":
		if not label.is_empty():
			var postlude := "place" if kind == "caller_handoff" else "event"
			return _record("map_return", postlude, next_target, label)
		if not next_target.is_empty():
			return _record("chain", "", next_target)
		return _record("unresolved", "", "", "", "target_missing")
	if kind == "analysis_boundary":
		var status := str(terminal.get("runtime_status", ""))
		# `loop_boundary` is the catalog form of a `caller_menu_loop` resume
		# (the place script's own input loop); port of the Python rule.
		if status == "def_selection_boundary" or status == "loop_boundary":
			return _record("place_menu")
		# Tool decision (owner ruling 2026-09-23, EP-03 step 2): a
		# script_dispatch_boundary terminal already carrying a next_target
		# (written only when it is exactly another catalog event's intro
		# dispatch) continues into that event. Pure port of the Python
		# catalog-side rule; no index lookup here.
		if status == "script_dispatch_boundary" and not next_target.is_empty():
			return _record("chain", "", next_target)
		return _record("unresolved", "", "", "", status)
	if kind == "rejection_return":
		return _record("not_triggered", "", "", "", "rejection_return")
	if kind == "early_return":
		if not label.is_empty():
			return _record("map_return", "event", next_target, label)
		return _record("unresolved", "", "", "", "early_end")
	if kind == "callee_return_only" or kind == "caller_postlude":
		return _record("unresolved", "", "", "", "continuation_undeclared")
	if kind == "prefix_end" or kind == "unresolved_host_handoff":
		return _record("unresolved", "", "", "", kind)
	return _record("unresolved", "", "", "", "unknown_kind:%s" % kind)


## A catalog row's `terminals` (fields `kind`, `outcome`, `runtime_status`,
## `next_target`, `sequence`): order by `sequence`, take the last.
static func catalog_route_outcome(terminals: Array) -> Dictionary:
	if terminals.is_empty():
		return _record("unresolved", "", "", "", "terminals_missing")
	var ordered := terminals.duplicate()
	ordered.sort_custom(func(a, b): return int(a.get("sequence", 0)) < int(b.get("sequence", 0)))
	return _catalog_kind_outcome(ordered[-1])


## One matched terminal (the Event Player's `_catalog_terminal_match` shape:
## `kind`, `next_target`, `runtime_status`).
static func catalog_terminal_outcome(terminal: Dictionary) -> Dictionary:
	return _catalog_kind_outcome(terminal)


## The outcome the Event Player phrases for the one terminal a run matched
## (EP-12 gallery, 2026-10-04, tool decision; port of
## `tools/event_outcome_vocabulary.py`'s `matched_terminal_outcome`).
## Ordinarily `catalog_terminal_outcome(terminal)`; a `callee_return_only`
## terminal is the callee's own return, which that rule reads as an undeclared
## continuation, but a row that also declares where the flow goes next (its
## later terminals: an album scene's menu loop, the caller's handoff) has a
## decided `catalog_route_outcome`, which is then the phrase. A row whose
## route outcome is itself `unresolved` keeps the terminal's own reading.
## `row_terminals` is the row's `terminals` (the play request's `terminals`).
static func matched_terminal_outcome(terminal: Dictionary, row_terminals: Array) -> Dictionary:
	if str(terminal.get("kind", "")) == "callee_return_only":
		var route_outcome := catalog_route_outcome(row_terminals)
		if str(route_outcome.outcome) != "unresolved":
			return route_outcome
	return catalog_terminal_outcome(terminal)


## The English UI phrase for an outcome record.
static func phrase(record: Dictionary) -> String:
	var outcome := str(record.get("outcome", ""))
	if outcome == "map_return":
		var label := str(record.get("map", ""))
		var base := ""
		if label == "town":
			base = "Back to the town map"
		elif label == "campus":
			base = "Back to the campus map"
		elif label == "train":
			base = "Back to the train"
		else:
			base = "Back to %s" % label
		if str(record.get("postlude", "")) == "place":
			base += " after the place's own lines"
		return base
	if outcome == "place_menu":
		return "Back to the place menu"
	if outcome == "chain":
		return "Continues into %s" % str(record.get("next_target", ""))
	if outcome == "not_triggered":
		return "Not triggered"
	return "Unresolved: %s" % str(record.get("reason", ""))
