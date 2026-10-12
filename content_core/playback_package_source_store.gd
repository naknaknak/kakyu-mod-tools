extends RefCounted

# The verified bytes of one loaded playback package and a bounded cache of the
# code sources parsed from them (TD-64 part 2).
#
# `KakyuPlaybackPackage.load_directory()` verifies every file against the
# manifest and hands the bytes it verified to a store. A code source is parsed
# from those bytes on first need, so a package whose documents parse to about
# 18 times their size on disk (5.5 GB for the full 869-entry package) holds the
# bytes (about 300 MB) and at most `limit` parsed sources at a time.
#
# The store is the one snapshot-scoped holder: a successful reload builds a new
# store beside the old one and swaps, and a failed reload never touches it. It
# never reads a file, so a file changed on disk after the load cannot alter what
# a source decodes. Nothing here references a code source's shell or the
# package, so dropping the package frees the bytes and the cache with it.
#
# Eviction is safe at any limit of 1 or more. A source never calls another
# source or the store, so eviction can only happen inside `source_for`, on the
# miss path, and never while the evicted source is answering a call. The rule
# the shells keep is: fetch the parsed source once per call and never hold it
# across calls.

const CodeSourceScript := preload("res://content_core/playback_package_code_source.gd")

## Parses and evictions since this store was built; the tests read them.
var parse_count := 0
var eviction_count := 0

var _events: Dictionary = {}
var _texts: Dictionary = {}
var _codec: KakyuCp932Codec
var _limit := 1
## entry -> parsed source, least recently used first.
var _parsed: Dictionary = {}


func _init(codec: KakyuCp932Codec, limit: int) -> void:
	_codec = codec
	_limit = maxi(1, limit)


## Keeps the verified bytes of one entry's events and text files.
func keep(entry: String, events_bytes: PackedByteArray, text_bytes: PackedByteArray) -> void:
	_events[entry] = events_bytes
	_texts[entry] = text_bytes


func limit() -> int:
	return _limit


func set_limit(limit_value: int) -> void:
	_limit = maxi(1, limit_value)
	_trim()


## How many parsed sources are resident right now.
func resident_count() -> int:
	return _parsed.size()


func is_resident(entry: String) -> bool:
	return _parsed.has(entry)


## The parsed source of `entry`, parsing it from the verified bytes on a miss.
## A hit becomes the most recently used. The caller uses the result for the one
## call it was fetched for and lets go of it.
func source_for(entry: String) -> KakyuPlaybackPackageCodeSource:
	var hit: Variant = _parsed.get(entry)
	if hit != null:
		_parsed.erase(entry)
		_parsed[entry] = hit
		return hit
	var document := _parse(_events.get(entry, PackedByteArray()))
	var text := _parse(_texts.get(entry, PackedByteArray()))
	var strings: Array = text.strings if text.get("strings") is Array else []
	var source: KakyuPlaybackPackageCodeSource = CodeSourceScript.new(document, strings, _codec)
	parse_count += 1
	_parsed[entry] = source
	_trim()
	return source


## The entry's text strings, parsed from the verified bytes for this one call.
func text_strings(entry: String) -> Array:
	var text := _parse(_texts.get(entry, PackedByteArray()))
	return text.strings if text.get("strings") is Array else []


## The bytes held, for the measurements.
func byte_count() -> int:
	var total := 0
	for entry in _events:
		total += (_events[entry] as PackedByteArray).size() + (_texts[entry] as PackedByteArray).size()
	return total


func _trim() -> void:
	while _parsed.size() > _limit:
		_parsed.erase(_parsed.keys()[0])
		eviction_count += 1


func _parse(payload: PackedByteArray) -> Dictionary:
	var parser := JSON.new()
	if payload.is_empty() or parser.parse(payload.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {}
	return parser.data
