class_name Hud
extends CanvasLayer
## Race HUD: nickname, terrain, laps and times, countdown, messages,
## speedometer and control hints.

var swan: Swan
## Track for the minimap (optional).
var track: IslandTrack
var terrain_name := ""

var _speedometer := Speedometer.new()
var _hint := Label.new()
var _lap_label := Label.new()
var _time_label := Label.new()
var _best_label := Label.new()
var _last_label := Label.new()
var _center_label := Label.new()
var _message_time := 0.0


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
	terrain.text = terrain_name
	info.add_child(terrain)

	var times := VBoxContainer.new()
	times.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	times.position = Vector2(-300, 18)
	times.custom_minimum_size.x = 276
	root.add_child(times)
	for label in [_lap_label, _time_label, _last_label, _best_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		times.add_child(label)
	_lap_label.add_theme_font_size_override("font_size", 32)
	_time_label.add_theme_font_size_override("font_size", 30)

	_center_label.set_anchors_preset(Control.PRESET_CENTER)
	_center_label.custom_minimum_size = Vector2(800, 160)
	_center_label.position = Vector2(-400, -200)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.add_theme_font_size_override("font_size", 64)
	_center_label.add_theme_constant_override("outline_size", 12)
	root.add_child(_center_label)

	if track:
		var minimap := Minimap.new()
		minimap.track = track
		minimap.swans = [swan]
		minimap.size = Vector2(250, 250)
		root.add_child(minimap)
		minimap.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_KEEP_SIZE, 20)

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


func _process(delta: float) -> void:
	if swan:
		_speedometer.speed_kmh = swan.motor.speed * 3.6
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_center_label.text = ""


func set_lap(lap: int, lap_time: float, last_lap: float) -> void:
	_lap_label.text = tr("HUD_LAP") % lap
	_time_label.text = format_time(lap_time)
	_last_label.text = tr("HUD_LAST") % format_time(last_lap) if last_lap > 0.0 else ""


func set_best(best: float) -> void:
	_best_label.text = tr("HUD_BEST") % (format_time(best) if best > 0.0 else "--:--.--")


func show_countdown(seconds: int) -> void:
	_center_label.text = str(seconds)
	_message_time = 0.0


func show_message(text: String, seconds: float) -> void:
	_center_label.text = text
	_message_time = seconds


## 74.5 -> "1:14.50"
static func format_time(seconds: float) -> String:
	var hundredths := roundi(seconds * 100.0)
	return "%d:%02d.%02d" % [hundredths / 6000, (hundredths / 100) % 60, hundredths % 100]


func _update_hint() -> void:
	_hint.text = InputGlyphs.race_hint()
