class_name ParentalGate
extends VBoxContainer
## Parental gate: an adult-level question before anything leaves the game,
## such as opening a link in the browser (ADR 0009). App Store and Google Play
## require one in apps for children. Works with mouse, touch, keyboard and
## controller.
##
## The question is a multiplication with three answer buttons. A wrong answer
## asks a new question; Back or "Cancel" closes the gate.

signal passed
signal cancelled

const CHOICES := 3

var _question := Label.new()
var _buttons: Array[Button] = []
var _values: Array[int] = []
var _cancel := Button.new()
var _answer := 0


func _init() -> void:
	visible = false
	add_theme_constant_override("separation", 12)
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question.add_theme_font_size_override("font_size", 22)
	add_child(_question)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	for n in CHOICES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(120, 56)
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(_pick.bind(n))
		row.add_child(button)
		_buttons.append(button)
	_cancel.text = tr("GATE_CANCEL")
	_cancel.custom_minimum_size = Vector2(220, 48)
	_cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cancel.add_theme_font_size_override("font_size", 20)
	_cancel.pressed.connect(cancel)
	add_child(_cancel)
	# Focus stays inside the gate: left/right between answers, down to Cancel.
	for n in CHOICES:
		var button := _buttons[n]
		button.focus_neighbor_left = button.get_path_to(_buttons[maxi(n - 1, 0)])
		button.focus_neighbor_right = button.get_path_to(_buttons[mini(n + 1, CHOICES - 1)])
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(_cancel)
	_cancel.focus_neighbor_top = _cancel.get_path_to(_buttons[1])
	for side in ["focus_neighbor_bottom", "focus_neighbor_left", "focus_neighbor_right"]:
		_cancel.set(side, _cancel.get_path_to(_cancel))


## Shows a new question and focuses the first answer.
func open() -> void:
	_ask("GATE_QUESTION")
	visible = true


func cancel() -> void:
	visible = false
	cancelled.emit()


func _pick(n: int) -> void:
	if _values[n] == _answer:
		visible = false
		passed.emit()
	else:
		_ask("GATE_RETRY")


func _ask(key: String) -> void:
	var a := randi_range(6, 9)
	var b := randi_range(6, 9)
	_answer = a * b
	_values = [_answer]
	for wrong in [_answer + a, _answer - b, _answer + b, _answer - a, _answer + 1, _answer - 1]:
		if _values.size() < CHOICES and wrong not in _values:
			_values.append(wrong)
	_values.shuffle()
	_question.text = tr(key) % [a, b]
	for n in CHOICES:
		_buttons[n].text = str(_values[n])
	_buttons[0].grab_focus.call_deferred()
