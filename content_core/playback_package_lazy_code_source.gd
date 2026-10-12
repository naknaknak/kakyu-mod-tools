extends "res://content_core/playback_package_code_source.gd"

# The code source a loaded playback package hands out (TD-64 part 2): a stable
# shell for one entry that holds no records. It answers `entry`, `address_table`
# and `size` from the metadata the load recorded, and parses the entry's
# document from the package's verified bytes, through the package's bounded
# cache of parsed sources, on the first call that needs records.
#
# Why a subclass and not a lazy mode inside the source: the eager source is
# the contract `tests/test_mes_code_source.gd` pins (the two-argument
# constructor, the injected codec, every refusal), and a subclass leaves it
# byte for byte as it was while the shell is still a
# `KakyuPlaybackPackageCodeSource`, so every typed caller and the
# `_cp932` the tests read keep working. The price is that every public method
# of the source that needs records is forwarded here;
# `tests/test_playback_package.gd` pins that the two classes declare the same
# public methods, so a method added to the source cannot silently answer from
# an empty shell.
#
# The rule that makes eviction safe: every forwarded call fetches the parsed
# source from the store once and uses it for that call alone. The shell never
# keeps it, so a cache that evicts the entry between two calls costs one
# re-parse and changes no answer. What a parsed source hands out is built per
# call, so it stays valid after its source is evicted.

var _store
var _is_library := false


## `store` is the package's `KakyuPlaybackPackageSourceStore`. `code_size` and
## `offsets` are the entry's `code_size` and `address_table`, recorded at load.
func _init(store, entry_name: String, code_size: int, offsets: Array[int], is_library: bool, codec: KakyuCp932Codec) -> void:
	super({}, [], codec)
	_store = store
	_entry = entry_name
	_code_size = code_size
	_address_table = offsets
	_is_library = is_library


func routines() -> Dictionary:
	# Only a library carries routines; an event entry's answer is empty either way.
	if not _is_library:
		return {}
	return _store.source_for(_entry).routines()


func record_count() -> int:
	return _store.source_for(_entry).record_count()


func decode_at(offset: int, limit := -1) -> Dictionary:
	return _remember(_store.source_for(_entry).decode_at(offset, limit))


func decode_at_structural(offset: int, limit := -1) -> Dictionary:
	return _remember(_store.source_for(_entry).decode_at_structural(offset, limit))


func is_dialogue_boundary_pattern(offset: int, limit: int) -> bool:
	return _store.source_for(_entry).is_dialogue_boundary_pattern(offset, limit)


func dialogue_boundary_end(offset: int, limit: int) -> int:
	return _store.source_for(_entry).dialogue_boundary_end(offset, limit)


func byte_at(offset: int, limit: int) -> int:
	return _store.source_for(_entry).byte_at(offset, limit)


func sha256_range(start: int, end: int) -> String:
	return _store.source_for(_entry).sha256_range(start, end)


# A refusal sets the parsed source's `last_error`, and that source may be evicted
# before anyone reads it, so the shell keeps its own copy, set as the source's is.
func _remember(result: Dictionary) -> Dictionary:
	if not result.get("ok", false):
		last_error = str(result.get("error", ""))
	return result
