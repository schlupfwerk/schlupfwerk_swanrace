extends Node
## Autoload "InputGlyphs": remembers the last input device used, so the UI
## can show matching button names (keyboard, Xbox or PlayStation).

signal changed

enum Kind { KEYBOARD, XBOX, PLAYSTATION, TOUCH }

const PLAYSTATION_TAGS := ["ps3", "ps4", "ps5", "dualsense", "dualshock", "playstation", "sony"]

var kind := Kind.KEYBOARD


func _input(event: InputEvent) -> void:
	var new_kind := kind
	if event is InputEventKey and event.pressed:
		new_kind = Kind.KEYBOARD
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


func race_hint() -> String:
	match kind:
		Kind.XBOX:
			return "Analógico: virar   RT: acelerar   LT: frear   A: pular   Start: menu"
		Kind.PLAYSTATION:
			return "Analógico: virar   R2: acelerar   L2: frear   Cruz: pular   Options: menu"
		_:
			return "WASD ou setas: mover   Espaço: pular   Esc: menu"


func menu_hint() -> String:
	match kind:
		Kind.XBOX:
			return "↑↓ escolher   ←→ mudar   A: confirmar"
		Kind.PLAYSTATION:
			return "↑↓ escolher   ←→ mudar   Cruz: confirmar"
		_:
			return "↑↓ escolher   ←→ mudar   Enter: confirmar"


static func _pad_kind(device: int) -> Kind:
	var pad_name := Input.get_joy_name(device).to_lower()
	for tag: String in PLAYSTATION_TAGS:
		if pad_name.contains(tag):
			return Kind.PLAYSTATION
	return Kind.XBOX
