class_name TouchControls
extends Control
## On-screen race controls for phones and tablets (ADR 0005): big round buttons
## that press the same actions as the keyboard and controllers. Real
## multi-touch: steer, accelerate and jump at the same time, and a finger can
## slide from one button to the next (left to right) without lifting.
## Shown only while touch is the last input used; a controller hides them.
## The menu button asks for a second tap, so a stray touch never ends a race.

signal menu_requested

## action, label (translation key or symbol), screen corner (0..1), offset from
## that corner in pixels, radius.
const BUTTONS := [
	# Left thumb: steer. No accelerate button: on touch the swan speeds up by
	# itself (PlayerInput), so a child only steers, jumps and uses turbo.
	["steer_left", "◀", Vector2(0, 1), Vector2(125, -135), 95.0],
	["steer_right", "▶", Vector2(0, 1), Vector2(345, -135), 95.0],
	# Right thumb: jump, turbo above it, brake and horn beside.
	["jump", "TOUCH_JUMP", Vector2(1, 1), Vector2(-140, -145), 100.0],
	["turbo", "TOUCH_TURBO", Vector2(1, 1), Vector2(-135, -350), 80.0],
	["brake", "TOUCH_BRAKE", Vector2(1, 1), Vector2(-360, -105), 72.0],
	["horn", "TOUCH_HORN", Vector2(1, 1), Vector2(-345, -285), 54.0],
	["menu", "II", Vector2(0, 0), Vector2(335, 72), 54.0],
]
const FILL := Color(0.05, 0.06, 0.1, 0.38)
const FILL_PRESSED := Color(1.0, 0.82, 0.25, 0.65)
const RIM := Color(1, 1, 1, 0.55)
const TEXT := Color(1, 1, 1, 0.9)
## Seconds the menu button waits for the second tap.
const MENU_CONFIRM_TIME := 2.0
## A touch counts a little outside the circle (thumbs are not precise).
const REACH := 1.15

## Finger index -> button index (-1 = none).
var _fingers := {}
## Action -> how many fingers hold it.
var _held := {}
var _menu_armed := 0.0
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	InputGlyphs.changed.connect(_update_visible)
	_update_visible()


func _exit_tree() -> void:
	release_all()


func _process(delta: float) -> void:
	if _menu_armed > 0.0:
		_menu_armed -= delta
	queue_redraw()


## Lifts every finger (race over, controls hidden, scene leaving).
func release_all() -> void:
	for action: String in _held:
		Input.action_release(action)
	_held.clear()
	_fingers.clear()


func _update_visible() -> void:
	visible = InputGlyphs.touch()
	if not visible:
		release_all()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var hit := _button_at(touch.position)
			if hit >= 0 and BUTTONS[hit][0] == "menu":
				_tap_menu()
				get_viewport().set_input_as_handled()
				return
			_move_finger(touch.index, hit)
			if hit >= 0:
				get_viewport().set_input_as_handled()
		else:
			_move_finger(touch.index, -1)
			_fingers.erase(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _fingers.has(drag.index):
			var hit := _button_at(drag.position)
			if hit >= 0 and BUTTONS[hit][0] == "menu":
				hit = -1
			_move_finger(drag.index, hit)


func _tap_menu() -> void:
	if _menu_armed > 0.0:
		_menu_armed = 0.0
		release_all()
		menu_requested.emit()
	else:
		_menu_armed = MENU_CONFIRM_TIME


## The finger now rests on `button` (-1 = none): release what it held before.
func _move_finger(finger: int, button: int) -> void:
	var before: int = _fingers.get(finger, -1)
	if before == button:
		return
	if before >= 0:
		_hold(BUTTONS[before][0], -1)
	if button >= 0:
		_hold(BUTTONS[button][0], 1)
	_fingers[finger] = button


func _hold(action: String, change: int) -> void:
	var count: int = _held.get(action, 0) + change
	if count > 0:
		if not _held.has(action):
			Input.action_press(action)
		_held[action] = count
	else:
		_held.erase(action)
		Input.action_release(action)


func _button_at(point: Vector2) -> int:
	var best := -1
	var best_distance := INF
	for n in BUTTONS.size():
		var distance := point.distance_to(_center(n))
		if distance <= BUTTONS[n][4] * REACH and distance < best_distance:
			best = n
			best_distance = distance
	return best


func _center(n: int) -> Vector2:
	var corner: Vector2 = BUTTONS[n][2]
	return size * corner + BUTTONS[n][3]


func _draw() -> void:
	for n in BUTTONS.size():
		var action: String = BUTTONS[n][0]
		var center := _center(n)
		var radius: float = BUTTONS[n][4]
		var pressed: bool = _held.has(action) or (action == "menu" and _menu_armed > 0.0)
		draw_circle(center, radius, FILL_PRESSED if pressed else FILL)
		draw_arc(center, radius, 0.0, TAU, 48, RIM, 3.0, true)
		var label: String = tr(BUTTONS[n][1])
		var font_size := int(clampf(radius * 0.42, 18.0, 44.0))
		if label.length() > 1:
			font_size = int(minf(font_size, radius * 1.7 / maxf(label.length() * 0.55, 1.0)))
		var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(_font, center + Vector2(-width * 0.5, font_size * 0.35), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK if pressed else TEXT)
	if _menu_armed > 0.0:
		var text := tr("TOUCH_MENU_CONFIRM")
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var at := _center(BUTTONS.size() - 1) + Vector2(-width * 0.5, 70)
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color.BLACK)
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ffd23f"))
