@tool
extends Container
class_name FormValidator

signal control_validated(control, passed, messages)

class ValidatorInfo extends RefCounted:
	var control: Control
	var validator: Validator

@export var auto_validate: bool = false
@export var validation_method: Validation.Method = Validation.Method.BATCH:
	set(value):
		validation_method = value
		_update_validation_methods()

var _control_validator_map: Dictionary = {}
var _control_messages_map: Dictionary = {}


func _ready() -> void:
	Validation.validator_added.connect(_on_validator_added)
	Validation.validator_removed.connect(_on_validator_removed)
	_find_validators(self)


func get_messages() -> Dictionary:
	return _control_messages_map


func get_messages_for_control(control: Control) -> PackedStringArray:
	if not _control_messages_map.has(control):
		return PackedStringArray()
	return _control_messages_map[control]


func validate() -> bool:
	_control_messages_map.clear()
	var list = _get_validator_info_list()
	var valid = true
	for info in list:
		if not _is_in_my_subtree(info.control):
			continue

		if info.validator.skip_validation:
			continue
		var passed = info.validator.validate(info.control)
		var messages = info.validator.get_messages()
		if not passed:
			_control_messages_map[info.control] = messages
		control_validated.emit(info.control, passed, messages)
		valid = valid and passed
		if not valid and validation_method == Validation.Method.IMMEDIATE:
			return valid
	return valid


func _get_validator_info_list() -> Array[ValidatorInfo]:
	var list: Array[ValidatorInfo] = []
	for control in _control_validator_map.keys():
		var validator = _control_validator_map[control]
		if not validator:
			continue
		var info = ValidatorInfo.new()
		info.control = control
		info.validator = validator
		list.append(info)
	list.sort_custom(func (a: ValidatorInfo, b: ValidatorInfo): 
		return a.validator.validation_order < b.validator.validation_order
	)
	return list


func _update_validation_methods() -> void:
	var validators = _control_validator_map.values()
	for item in validators:
		var validator = item as Validator
		if not validator:
			continue
		validator.validation_method = validation_method


func _find_validators(node: Node) -> void:
	for child in node.get_children():
		var control_validator = child as ControlValidator
		if control_validator:
			control_validator._on_validator_added()
		_find_validators(child)


func _auto_validate(control: Control) -> void:
	if not auto_validate:
		return
	if not _is_in_my_subtree(control):
		return

	var validator = _control_validator_map[control] as Validator
	if not validator:
		return
	var passed = validator.validate(control)
	control_validated.emit(control, passed, validator.get_messages())


func _on_validator_added(control: Control, validator: Validator) -> void:
	if not control:
		return
	if not _is_in_my_subtree(control):
		return

	_control_validator_map[control] = validator
	if not control.focus_exited.is_connected(_on_control_focus_exited):
		control.focus_exited.connect(_on_control_focus_exited.bind(control))
	# Special case to handle range-type controls that don't respond to focus 
	# events for editing.
	if control.has_signal("value_changed"):
		if not control.value_changed.is_connected(_on_control_value_changed):
			control.value_changed.connect(_on_control_value_changed.bind(control))


func _on_validator_removed(control: Control) -> void:
	if not _is_in_my_subtree(control):
		return

	_control_validator_map.erase(control)
	if control.focus_exited.is_connected(_on_control_focus_exited):
		control.focus_exited.disconnect(_on_control_focus_exited)
	if control.has_signal("value_changed"):
		if control.value_changed.is_connected(_on_control_value_changed):
			control.value_changed.disconnect(_on_control_value_changed)


func _on_control_focus_exited(control: Control) -> void:
	_auto_validate(control)


func _on_control_value_changed(value: float, control: Control) -> void:
	_auto_validate(control)


func _get_minimum_size() -> Vector2:
	var result := Vector2.ZERO

	for child in get_children():
		if child is Control and child.visible:
			var min_size := (child as Control).get_combined_minimum_size()
			result.x = max(result.x, min_size.x)
			result.y += min_size.y

	return result


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var y := 0.0

		for child in get_children():
			if child is Control and child.visible:
				var min_size := (child as Control).get_combined_minimum_size()
				fit_child_in_rect(child, Rect2(0, y, size.x, min_size.y))
				y += min_size.y


func _is_in_my_subtree(control: Control) -> bool:
	return control != null and (control == self or is_ancestor_of(control))
