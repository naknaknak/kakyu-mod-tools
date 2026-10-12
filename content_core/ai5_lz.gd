class_name KakyuAi5Lz
extends RefCounted

const WINDOW_SIZE := 0x1000
const WINDOW_MASK := 0x0FFF
const INITIAL_WINDOW_POSITION := 0x0FEE
const MIN_MATCH_LENGTH := 3
const MAX_MATCH_LENGTH := 18
const MAX_MATCH_CANDIDATES := 64
const MAX_CHAIN_LENGTH := 96


static func compress(source: PackedByteArray) -> Dictionary:
	var output := PackedByteArray()
	var chains := {}
	var input_position := 0
	var literal_tokens := 0
	var reference_tokens := 0
	while input_position < source.size():
		var flag_offset := output.size()
		output.append(0)
		var flags := 0
		for flag_index in range(8):
			if input_position >= source.size():
				break
			var match := _find_match(source, input_position, chains)
			var match_length := int(match.length)
			if match_length >= MIN_MATCH_LENGTH:
				var reference := (INITIAL_WINDOW_POSITION + int(match.position)) & WINDOW_MASK
				output.append(reference & 0xFF)
				output.append(((reference >> 4) & 0xF0) | (match_length - MIN_MATCH_LENGTH))
				reference_tokens += 1
			else:
				flags |= 1 << flag_index
				output.append(source[input_position])
				match_length = 1
				literal_tokens += 1
			for position in range(input_position, input_position + match_length):
				_add_chain_position(source, position, chains)
			input_position += match_length
		output[flag_offset] = flags
	return {
		"ok": true,
		"data": output,
		"source_bytes": source.size(),
		"compressed_bytes": output.size(),
		"literal_tokens": literal_tokens,
		"reference_tokens": reference_tokens,
	}


static func decompress(source: PackedByteArray, output_limit: int) -> Dictionary:
	if output_limit < 0:
		return {"ok": false, "error": "AI5 LZ output limit cannot be negative."}
	var window := PackedByteArray()
	window.resize(WINDOW_SIZE)
	window.fill(0)
	var output := PackedByteArray()
	var window_position := INITIAL_WINDOW_POSITION
	var flags := 0
	var input_position := 0
	while input_position < source.size() and output.size() < output_limit:
		flags >>= 1
		if (flags & 0x100) == 0:
			flags = int(source[input_position]) | 0xFF00
			input_position += 1
		if (flags & 1) != 0:
			if input_position >= source.size():
				break
			var value := int(source[input_position])
			input_position += 1
			output.append(value)
			window[window_position] = value
			window_position = (window_position + 1) & WINDOW_MASK
		else:
			if input_position + 1 >= source.size():
				break
			var first := int(source[input_position])
			var second := int(source[input_position + 1])
			input_position += 2
			var reference := first | ((second & 0xF0) << 4)
			var count := (second & 0x0F) + 3
			for index in range(count):
				if output.size() >= output_limit:
					break
				var value := int(window[(reference + index) & WINDOW_MASK])
				output.append(value)
				window[window_position] = value
				window_position = (window_position + 1) & WINDOW_MASK
	return {
		"ok": true,
		"data": output,
		"complete": output.size() == output_limit,
		"source_bytes": source.size(),
		"source_consumed": input_position,
	}


static func _find_match(source: PackedByteArray, position: int, chains: Dictionary) -> Dictionary:
	if position + MIN_MATCH_LENGTH > source.size():
		return {"position": -1, "length": 0}
	var key := _three_byte_key(source, position)
	var candidates: Array = chains.get(key, [])
	var best_position := -1
	var best_length := 0
	var checked := 0
	for candidate_index in range(candidates.size() - 1, -1, -1):
		var candidate := int(candidates[candidate_index])
		var distance := position - candidate
		if distance > WINDOW_SIZE:
			break
		if distance <= 0:
			continue
		checked += 1
		var limit := mini(MAX_MATCH_LENGTH, source.size() - position)
		var length := MIN_MATCH_LENGTH
		while length < limit and source[candidate + length] == source[position + length]:
			length += 1
		if length > best_length:
			best_position = candidate
			best_length = length
			if best_length == MAX_MATCH_LENGTH:
				break
		if checked >= MAX_MATCH_CANDIDATES:
			break
	return {"position": best_position, "length": best_length}


static func _add_chain_position(source: PackedByteArray, position: int, chains: Dictionary) -> void:
	if position + MIN_MATCH_LENGTH > source.size():
		return
	var key := _three_byte_key(source, position)
	var positions: Array = chains.get(key, [])
	positions.append(position)
	if positions.size() > MAX_CHAIN_LENGTH:
		positions.remove_at(0)
	chains[key] = positions


static func _three_byte_key(source: PackedByteArray, position: int) -> int:
	return int(source[position]) | (int(source[position + 1]) << 8) | (int(source[position + 2]) << 16)
