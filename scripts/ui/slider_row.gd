class_name SliderRow
extends HBoxContainer
## Label + slider + value, for volumes. Left/right (keys, d-pad, stick) move
## the focused slider; mouse and touch also work.

signal value_changed(value: int)

var slider := HSlider.new()
var _value_label := Label.new()


func setup(label_text: String, value: int) -> SliderRow:
	custom_minimum_size.y = 40
	add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 230
	add_child(label)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = value
	slider.focus_mode = Control.FOCUS_ALL
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 32
	slider.value_changed.connect(_on_value_changed)
	add_child(slider)
	_value_label.custom_minimum_size.x = 70
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_value_label)
	_value_label.text = "%d%%" % value
	return self


func _on_value_changed(value: float) -> void:
	_value_label.text = "%d%%" % int(value)
	value_changed.emit(int(value))
