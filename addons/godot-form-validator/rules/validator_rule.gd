@tool
extends Resource
class_name ValidatorRule

@export var fail_message: String = ""


func prepare(validator: ControlValidator, control: Control) -> void:
	pass


func apply(control: Control, value: Variant) -> RuleResult:
	return RuleResult.new()


func is_valid() -> bool:
	return true


func get_invalid_message() -> String:
	return ""


func get_valid_values() -> Array[Variant]:
	return []
