extends Node
## Autoload "InputGlyphs": remembers the last input device used, so the UI
## can show matching button names (keyboard, Xbox or PlayStation).

signal changed

enum Kind { KEYBOARD, XBOX, PLAYSTATION, TOUCH }

const PLAYSTATION_TAGS := ["ps3", "ps4", "ps5", "dualsense", "dualshock", "playstation", "sony"]

var kind := Kind.KEYBOARD
## On the keyboard, true when the player steers with the arrows (not WASD).
var arrows := false


func _input(event: InputEvent) -> void:
	var new_kind := kind
	if event is InputEventKey and event.pressed:
		new_kind = Kind.KEYBOARD
		var key: Key = event.physical_keycode
		if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] and not arrows:
			arrows = true
			changed.emit()
		elif key in [KEY_W, KEY_A, KEY_S, KEY_D] and arrows:
			arrows = false
			changed.emit()
	elif event is InputEventMouseButton and event.pressed:
		new_kind = Kind.KEYBOARD
	elif event is InputEventScreenTouch:
		new_kind = Kind.TOUCH
	elif event is InputEventJoypadButton and event.pressed:
		new_kind = _pad_kind(event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		new_kind = _pad_kind(event.device)
	if new_kind != kind:
		kind = new_kind
		changed.emit()


func menu_hint() -> String:
	return tr("HINT_MENU_" + _suffix())


func wardrobe_hint() -> String:
	return tr("HINT_WARDROBE_" + _suffix())


func tabs_hint() -> String:
	return tr("HINT_TABS_" + _suffix())


func _suffix() -> String:
	match kind:
		Kind.XBOX:
			return "XBOX"
		Kind.PLAYSTATION:
			return "PLAYSTATION"
		_:
			return "KEYBOARD"


static func _pad_kind(device: int) -> Kind:
	var pad_name := Input.get_joy_name(device).to_lower()
	for tag: String in PLAYSTATION_TAGS:
		if pad_name.contains(tag):
			return Kind.PLAYSTATION
	return Kind.XBOX
