class_name OptionRow
extends Button
## A row to pick one option:   Name:   [‹]   value   [›]
## - Controller: left/right (d-pad or stick), A/Cross = next, X/Square = back.
## - Keyboard: left/right arrows, Enter = next, Backspace = back.
## - Mouse/touch: the ‹ and › buttons (or right click = back).

signal value_changed(index: int)

var label_text := ""
var options := PackedStringArray()
var index := 0

var _name := Label.new()
var _value := Label.new()
var _prev := Button.new()
var _next := Button.new()


func setup(p_label: String, p_options: PackedStringArray, p_index: int) -> OptionRow:
	label_text = p_label
	options = p_options
	index = clampi(p_index, 0, options.size() - 1)
	custom_minimum_size.y = 44
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_build()
	_refresh()
	return self


func _ready() -> void:
	pressed.connect(_on_pressed)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("option_prev"):
		change(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		change(1)
		accept_event()


func change(step: int) -> void:
	index = wrapi(index + step, 0, options.size())
	_refresh()
	value_changed.emit(index)


## Changes the shown option without emitting value_changed.
func set_index(new_index: int) -> void:
	index = clampi(new_index, 0, options.size() - 1)
	_refresh()


func _build() -> void:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_right = -6
	box.offset_top = 3
	box.offset_bottom = -3

	_name.text = label_text + ":"
	_name.custom_minimum_size.x = 185
	# Grows on wide panels so long names fit.
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.size_flags_stretch_ratio = 0.75
	_name.clip_text = true
	_name.add_theme_font_size_override("font_size", 21)
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_name)

	for arrow: Button in [_prev, _next]:
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.custom_minimum_size = Vector2(38, 0)
		arrow.add_theme_font_size_override("font_size", 26)
	_prev.text = "‹"
	_next.text = "›"
	_prev.pressed.connect(func() -> void: change(-1))
	_next.pressed.connect(func() -> void: change(1))

	_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_value.add_theme_font_size_override("font_size", 21)
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_prev)
	box.add_child(_value)
	box.add_child(_next)


func _on_pressed() -> void:
	change(-1 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 1)


func _refresh() -> void:
	_value.text = options[index]
	_prev.disabled = disabled
	_next.disabled = disabled
	var shade := Color(1, 1, 1, 0.4) if disabled else Color.WHITE
	_name.modulate = shade
	_value.modulate = shade


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		var focused := has_focus()
		_value.add_theme_color_override("font_color", UiTheme.FOCUS_COLOR if focused else Color.WHITE)
		_name.add_theme_color_override("font_color", UiTheme.FOCUS_COLOR if focused else Color.WHITE)


## Enables or greys out the row (and its arrows).
func set_enabled(enabled: bool) -> void:
	disabled = not enabled
	_refresh()


## Smaller text and height, for dense menus.
func compact() -> OptionRow:
	custom_minimum_size.y = 34
	_name.custom_minimum_size.x = 150
	_name.add_theme_font_size_override("font_size", 17)
	_value.add_theme_font_size_override("font_size", 17)
	for arrow: Button in [_prev, _next]:
		arrow.custom_minimum_size.x = 30
		arrow.add_theme_font_size_override("font_size", 20)
	return self


## New list of values (after setup), e.g. when the player's characters change.
func set_options(p_options: PackedStringArray, p_index: int) -> void:
	options = p_options
	index = clampi(p_index, 0, options.size() - 1)
	_refresh()
