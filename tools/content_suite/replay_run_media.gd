class_name KakyuReplayRunMedia
extends RefCounted

## WD-21 U2 C2 (2026-10-08): what one measured run executed, for the replay v3
## writers. `event_analysis_group_validation.gd` (site profiles) and
## `event_analysis_group_flow_validation.gd` (v14 flow profiles) both hold the
## whole probe result of every run they replay; this is the one place that
## turns such a result into the two fields replay v3 adds per run:
##
## - `executed`: `{<package member>: [at, ...]}`, the sorted, de-duplicated `at`
##   of every signature row in the result's `rows`, keyed by the package member
##   the row's `at` is relative to. `rows` labels a row by the entry the probe
##   was walking: a route entry as it is, `DEF_MAIN.MES:<id>` for a registered
##   definition the route itself invoked (DEF-relative `at`), and
##   `LIBLARY.LIB:<routine>` for a library routine (library-relative `at`).
##   Until Core 0.377.0 one label was wrong (TD-55): a registered definition
##   invoked from *inside* a library routine runs through `KakyuMesLibraryRunner`,
##   whose rows reached the probe's `_collect_library` labelled
##   `LIBLARY.LIB:<routine>` while their `at` is DEF-relative. Since 0.377.0 the
##   probe keys those rows `DEF_MAIN.MES:<id>` (`external_definition_id`), and
##   this function accepts both labellings under the same guards: the rows
##   between a library invoke row and the definition's script_return are
##   definition rows whichever way they are keyed. The tool-level rule
##   (spec `analysis/_docs/wd21_u2_spec.md` D2/R1): within a run of consecutive
##   `LIBLARY.LIB:<n>` rows, the rows after a `definition_invoke_boundary` row
##   up to and including the next `script_return` row are DEF-origin and keyed
##   `DEF_MAIN.MES`. Basis: on the probe's path such a definition reaches
##   `_collect_library` only as `[invoke row] + the definition's rows + its
##   script_return` (`mes_library_runner.gd` appends the definition's trace
##   right after the segment that ends at the invoke row;
##   `mes_registered_definition_call.gd` reports ok only when the definition
##   ended at `script_return`; a nested definition call makes the probe refuse
##   the route). Fail closed: an invoke row not terminated by a `script_return`
##   before the run's rows leave `LIBLARY.LIB:*`, or a second invoke row inside
##   an open one, is a refusal (`ok` false), never a guess.
## - `resource_rows`: `[{entry, at, effect, name}]`, every row of the result's
##   `trace` (the route's own entries) whose effect is one of the five media
##   effects the runner emits, with the name upper-cased, in trace order.
##   Script boundaries such as `inline_script_execution_boundary` never enter.
##
## Pure: no archive, no state, nothing written. The `trace` rows carry
## `source_entry`/`source_offset`/`resource_name`; the `rows` carry
## `entry`/`at`/`effect` (`content_core/mes_route_probe.gd` `_signature_row`).

const LIBRARY_PREFIX := "LIBLARY.LIB:"
const DEFINITION_PREFIX := "DEF_MAIN.MES:"
const LIBRARY_MEMBER := "LIBLARY.LIB"
const DEFINITION_MEMBER := "DEF_MAIN.MES"
const INVOKE_EFFECT := "definition_invoke_boundary"
const RETURN_EFFECT := "script_return"
## The effect strings the runner emits on a media request: the MMO marker
## (`mes_event_runner.gd` `_apply_mmo_marker`), `ax_resource_marker`,
## `voice_marker`, `effect_request` (SE) and `bgm_request` (routine-23 transfer).
## One list, shared with the probe's `library_media` and the Playback timeline
## (EP-14, Core 0.378.0): `KakyuMesRouteProbe.MEDIA_EFFECTS`.
const MEDIA_EFFECTS := KakyuMesRouteProbe.MEDIA_EFFECTS


## `run` is one probe result (`KakyuMesRouteProbe.run_route`). Returns `{ok, error,
## executed, resource_rows, definition_invokes, definition_rows}`: `ok` is false (and
## `executed` empty) when the attribution rule refuses the run; `definition_invokes`
## counts the library-invoked definitions the rule re-keyed and `definition_rows`
## the rows it moved to `DEF_MAIN.MES`.
static func summarize(run: Dictionary) -> Dictionary:
	var seen := {}
	var invokes := 0
	var moved_rows := 0
	var in_definition := false
	var error := ""
	var index := 0
	for untyped_row in run.get("rows", []):
		var row: Dictionary = untyped_row
		var entry := str(row.get("entry", ""))
		var effect := str(row.get("effect", ""))
		var member := entry
		if entry.begins_with(LIBRARY_PREFIX):
			member = LIBRARY_MEMBER
			if in_definition:
				member = DEFINITION_MEMBER
				moved_rows += 1
				if effect == RETURN_EFFECT:
					in_definition = false
				elif effect == INVOKE_EFFECT:
					error = "row %d: a second definition_invoke_boundary inside an open library-invoked definition" % index
					break
			elif effect == INVOKE_EFFECT:
				in_definition = true
				invokes += 1
		elif entry.begins_with(DEFINITION_PREFIX):
			member = DEFINITION_MEMBER
			if in_definition:
				# Core 0.377.0 (TD-55): the probe keys the rows of a definition a
				# library routine invoked by their own entry, so they arrive as
				# `DEF_MAIN.MES:<id>` rows between the invoke row and the
				# definition's script_return. The same guards apply to them.
				moved_rows += 1
				if effect == RETURN_EFFECT:
					in_definition = false
				elif effect == INVOKE_EFFECT:
					error = "row %d: a second definition_invoke_boundary inside an open library-invoked definition" % index
					break
		elif in_definition:
			error = "row %d: the library-invoked definition opened by an invoke row has no script_return before the library rows end" % index
			break
		if not seen.has(member):
			seen[member] = {}
		seen[member][int(row.get("at", -1))] = true
		index += 1
	if error.is_empty() and in_definition:
		error = "the library-invoked definition opened by the last invoke row has no script_return before the run ends"
	var executed := {}
	if error.is_empty():
		for member in seen:
			var offsets: Array = (seen[member] as Dictionary).keys()
			offsets.sort()
			executed[member] = offsets
	var resource_rows: Array = []
	for untyped_row in run.get("trace", []):
		var row: Dictionary = untyped_row
		var effect := str(row.get("effect", ""))
		if MEDIA_EFFECTS.has(effect):
			resource_rows.append({
				"entry": str(row.get("source_entry", "")),
				"at": int(row.get("source_offset", -1)),
				"effect": effect,
				"name": str(row.get("resource_name", "")).to_upper(),
			})
	return {
		"ok": error.is_empty(), "error": error,
		"executed": executed, "resource_rows": resource_rows,
		"definition_invokes": invokes, "definition_rows": moved_rows,
	}
