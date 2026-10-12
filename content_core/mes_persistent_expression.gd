class_name KakyuMesPersistentExpression
extends RefCounted

const ExpressionScript := preload("res://content_core/mes_expression.gd")

var _expression := ExpressionScript.new()


func evaluate_fragment(
	expression: Dictionary,
	state: KakyuMesSandboxState,
	stack: Array[int]
) -> Dictionary:
	var ast: Dictionary = expression.get("ast", {})
	var items: Array = ast.get("items", []) if str(ast.get("type", "")) == "stack" else [ast]
	var pending: Array[int] = []
	for untyped_item in items:
		var item: Dictionary = untyped_item
		var evaluated := _expression.evaluate(item, state)
		if not evaluated.ok:
			return {"ok": false, "error": str(evaluated.error)}
		pending.append(int(evaluated.value))
	var depth_before := stack.size()
	stack.append_array(pending)
	var used_empty_fallback := stack.is_empty()
	var value: int = 0 if used_empty_fallback else stack.pop_back()
	return {
		"ok": true,
		"value": value,
		"local_depth": items.size(),
		"stack_depth_before": depth_before,
		"stack_depth_after": stack.size(),
		"used_empty_fallback": used_empty_fallback,
	}
