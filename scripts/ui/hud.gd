class_name Hud
extends CanvasLayer
## Race HUD: nickname, terrain, speedometer and control hints.

var swan: Swan

var _speedometer := Speedometer.new()
var _hint := Label.new()


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)

	var info := VBoxContainer.new()
	info.position = Vector2(24, 18)
	root.add_child(info)
	var nickname := Label.new()
	nickname.text = swan.look.nickname if swan else ""
	nickname.add_theme_font_size_override("font_size", 32)
	info.add_child(nickname)
	var terrain := Label.new()
	terrain.text = "Terreno: Praia"
	info.add_child(terrain)

	_speedometer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_speedometer.custom_minimum_size = Vector2(230, 230)
	_speedometer.size = Vector2(230, 230)
	_speedometer.position = Vector2(-254, -254)
	root.add_child(_speedometer)

	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(24, -48)
	_hint.add_theme_font_size_override("font_size", 20)
	root.add_child(_hint)
	InputGlyphs.changed.connect(_update_hint)
	_update_hint()


func _process(_delta: float) -> void:
	if swan:
		_speedometer.speed_kmh = swan.motor.speed * 3.6


func _update_hint() -> void:
	_hint.text = InputGlyphs.race_hint()
