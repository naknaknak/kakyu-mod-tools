extends RefCounted

## The shared ARC builder for tests (TD-05 units 5 and 5b): the AI5 archive
## container layout used by the tests' synthetic fixtures - a count, then one
## 264-byte record per entry (256 name bytes XOR NAME_KEY (0x72), padded with
## NAME_KEY, size XOR SIZE_KEY (0xF97FD0EC), offset XOR OFFSET_KEY
## (0xA2C947FC)), then the payloads in entry order. Tests preload this as
## `const SyntheticArc := preload("res://tests/synthetic_arc.gd")`.
##
## Replaces the seven `_create_synthetic_arc`/`_create_arc` copies proven
## byte-for-byte equivalent to this layout: five multi-entry spellings
## (`write_arc`'s own `(path, entries)` contract) and two single-entry
## spellings (`(path, entry_name, data)`), each written and compared against
## `write_arc`'s output for the same entry or entries.


const NAME_KEY := 0x72
const SIZE_KEY := 0xF97FD0EC
const OFFSET_KEY := 0xA2C947FC
const ENTRY_SIZE := 264


## `entries` is an Array of `{name, data}`. Writes the count, one 264-byte
## record per entry, then the payloads in the same order.
static func write_arc(path: String, entries: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_32(entries.size())
	var payload_offset := 4 + entries.size() * ENTRY_SIZE
	for entry in entries:
		var data: PackedByteArray = entry.data
		file.store_buffer(encode_name(str(entry.name)))
		file.store_32(data.size() ^ SIZE_KEY)
		file.store_32(payload_offset ^ OFFSET_KEY)
		payload_offset += data.size()
	for entry in entries:
		file.store_buffer(entry.data)
	file.close()


static func encode_name(name: String) -> PackedByteArray:
	var encoded := PackedByteArray()
	encoded.resize(256)
	encoded.fill(NAME_KEY)
	var ascii := name.to_ascii_buffer()
	for index in range(ascii.size()):
		encoded[index] = ascii[index] ^ NAME_KEY
	return encoded


static func append_u32(bytes: PackedByteArray, value: int) -> void:
	var offset := bytes.size()
	bytes.resize(offset + 4)
	bytes.encode_u32(offset, value)


static func append_u16(bytes: PackedByteArray, value: int) -> void:
	var offset := bytes.size()
	bytes.resize(offset + 2)
	bytes.encode_u16(offset, value)


## Writes `value`'s ASCII bytes into `target` at `offset`, in place (a RIFF/MMO
## chunk tag or similar fixed-offset field of a synthetic archive payload).
static func write_ascii(target: PackedByteArray, offset: int, value: String) -> void:
	var source := value.to_ascii_buffer()
	for index in range(source.size()):
		target[offset + index] = source[index]


## Appends one MES shared-library registration record (opcode 0x1C) to `code`:
## the header, `body`, then the record's own length backpatched at offset 3.
static func append_registration(code: PackedByteArray, routine_id: int, body: PackedByteArray) -> void:
	var start := code.size()
	code.append_array(PackedByteArray([0x1C, routine_id, 0xFF, 0, 0, 0, 0]))
	code.append_array(body)
	code.encode_u32(start + 3, code.size())
