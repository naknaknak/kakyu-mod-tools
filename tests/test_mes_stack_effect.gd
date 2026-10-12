extends "res://tests/test_case.gd"

const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const StackEffectScript := preload("res://content_core/mes_stack_effect.gd")


func _ready() -> void:
	var decoder := DecoderScript.new()
	var analyzer := StackEffectScript.new()
	var carried_code := PackedByteArray([0x0A, 0xFF, 1, 2, 0xFF, 0])
	var instruction := decoder.decode_at_structural(carried_code, 0)
	_check(instruction.ok and instruction.structural_only, "structural command 0x0A retains its non-singleton expressions")
	var effect := analyzer.analyze_instruction(instruction)
	_check(
		effect.schema == "kakyu_mes_stack_effect/v1"
		and effect.local_depths == [0, 2]
		and effect.minimum_incoming == 1
		and effect.net_delta == 0,
		"instruction analysis reports the persistent stack item required by depth 0/2"
	)
	_check(not decoder.decode_at(carried_code, 0).ok, "stack-effect analysis does not relax strict execution decoding")

	var producer := instruction.duplicate(true)
	producer.operands[0].value.ast = {"type": "stack", "items": [{}, {}]}
	producer.operands[1].pairs[0].expression.ast = {"type": "stack", "items": [{}]}
	var consumer := instruction.duplicate(true)
	consumer.operands[0].value.ast = {"type": "stack", "items": []}
	consumer.operands[1].pairs[0].expression.ast = {"type": "stack", "items": [{}]}
	var sequence := analyzer.analyze_sequence([producer, consumer])
	_check(
		sequence.local_depths == [2, 1, 0, 1]
		and sequence.minimum_incoming == 0
		and sequence.net_delta == 0,
		"sequence analysis carries a produced native stack item into a later consumer"
	)
	_check(analyzer.analyze_depths([]).expression_count == 0, "instructions without expressions have zero stack effect")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
