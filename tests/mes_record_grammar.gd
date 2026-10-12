extends RefCounted

## Named-grammar builders for the few synthetic MES records whose exact encoding
## is the subject of a test (WD-25 item 1b, treatment G).
##
## A test fixture normally changes an operand the test does not depend on. A
## record built here is the exception: no byte of it can change without naming
## a different engine function or record, or without breaking its decoding, so a
## fixture cannot be made synthetic by an operand change. Each record is built
## once, from the grammar constants below, and every site takes it from here:
##
## - `native_record_dispatch(6, 13)`, the map module's location poll. Its consumer
##   fixes its identity: `content_core/mes_event_runner.gd` matches a declared
##   map-location contract at the poll's offset, and `tools/draft_event_route_spec.py`
##   searches entries for the same record (`tools/payload_values.py`
##   `native_record_dispatch`).
## - `calendar_fill_write(sentinel)`, the START bootstrap's calendar fill.
##   `content_core/mes_calendar_state.gd` (`_matches_fill_write`) pins the
##   command, the `state_u16[8]` destination, bank zero, the sentinel and the
##   continuation.
## - `resource_marker_head(selector)` with its name terminator and record-list end,
##   the START bootstrap's script-execution marker, whose selector (2 or 3) names
##   the role the analysis reports.
##
## The names and values are the typed-record grammar of
## `docs/spec/mes/format_and_method.md`: command `0x12` is the native typed-record
## dispatch ingress, command `0x06` is `banked_u8_write_run`, token `0x80` is
## `state_u16[u8_index]`, the map module is "The map module behind `Util(6,n)`",
## and presentation command `0x0D` with subcommand `8` is the resource marker.
## The guard cannot see bytes built here: this is a recorded exception, never an
## allowlist, and the closure of the unit lists each record, its constants, the
## consumer that fixes it and its sites.


const COMMAND_PRESENTATION := 0x0D
const COMMAND_BANKED_U8_WRITE_RUN := 0x06
const COMMAND_NATIVE_RECORD_DISPATCH := 0x12

const TOKEN_STATE_U16_BY_U8_INDEX := 0x80
const EXPRESSION_RECORD_TAG := 0x02
const NAME_RECORD_TAG := 0x01
const EXPRESSION_END := 0xFF
const RECORD_LIST_END := 0x00
const NAME_TERMINATOR := 0x00
const CONTINUATION_NONE := 0x00

const SUBCOMMAND_SCRIPT_EXECUTION_MARKER := 0x08
const MAP_MODULE := 6
const MAP_GET_LOCATION := 13
const CALENDAR_FILL_STATE_U16_INDEX := 8
const BANK_ZERO := 0


## One expression record with an inline literal (`value` below `0x40`).
static func expression_record(value: int) -> PackedByteArray:
	return PackedByteArray([EXPRESSION_RECORD_TAG, value, EXPRESSION_END])


## A command-`0x12` dispatch: one expression record per literal, then the
## record-list end. `native_record_dispatch(MAP_MODULE, MAP_GET_LOCATION)` is
## `Util(6,13)`.
static func native_record_dispatch(group: int, function: int) -> PackedByteArray:
	var record := PackedByteArray([COMMAND_NATIVE_RECORD_DISPATCH])
	record.append_array(expression_record(group))
	record.append_array(expression_record(function))
	record.append(RECORD_LIST_END)
	return record


## The map module's location poll, `Util(6,13)`.
static func map_location_poll() -> PackedByteArray:
	return native_record_dispatch(MAP_MODULE, MAP_GET_LOCATION)


## The START bootstrap's calendar fill: `state_u16[8] = sentinel` in bank zero.
static func calendar_fill_write(sentinel: int) -> PackedByteArray:
	return PackedByteArray([
		COMMAND_BANKED_U8_WRITE_RUN,
		TOKEN_STATE_U16_BY_U8_INDEX, CALENDAR_FILL_STATE_U16_INDEX, EXPRESSION_END,
		BANK_ZERO,
		sentinel, EXPRESSION_END, CONTINUATION_NONE,
	])


## The head of a script-execution resource marker; the marker's name follows it.
static func resource_marker_head(selector: int) -> PackedByteArray:
	var head := PackedByteArray([COMMAND_PRESENTATION, SUBCOMMAND_SCRIPT_EXECUTION_MARKER, EXPRESSION_END])
	head.append_array(expression_record(selector))
	head.append(NAME_RECORD_TAG)
	return head


## The end of a marker's name and of its record list.
static func name_end_and_record_list_end() -> PackedByteArray:
	return PackedByteArray([NAME_TERMINATOR, RECORD_LIST_END])
