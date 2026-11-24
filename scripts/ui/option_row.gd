class_name OptionRow
extends Button
## A focusable row that cycles options with left/right (keyboard, d-pad or
## stick). Click/tap also works: left click goes forward, right click back.

signal value_changed(index: int)

var label_text := ""
var options := PackedStringArray()
var index := 0


func setup(p_label: String, p_options: PackedStringArray, p_index: int) -> OptionRow:
	label_text = p_label
	options = p_options
	index = clampi(p_index, 0, options.size() - 1)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	custom_minimum_size.y = 40
	_refresh()
	return self


func _ready() -> void:
	pressed.connect(_on_pressed)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event.is_action_pressed("ui_left", true):
		change(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		change(1)
		accept_event()


func change(step: int) -> void:
	index = wrapi(index + step, 0, options.size())
	_refresh()
	value_changed.emit(index)


func _on_pressed() -> void:
	change(-1 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 1)


func _refresh() -> void:
	text = "%s:   ‹ %s ›" % [label_text, options[index]]


## Changes the shown option without emitting value_changed.
func set_index(new_index: int) -> void:
	index = clampi(new_index, 0, options.size() - 1)
	_refresh()
