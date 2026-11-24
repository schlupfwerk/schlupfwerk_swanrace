class_name Hud
extends CanvasLayer
## Race HUD: nickname, terrain, laps and times, countdown, messages,
## speedometer and control hints.

var swan: Swan
## Track for the minimap (optional).
var track: IslandTrack
var terrain_name := ""

var _speedometer := Speedometer.new()
var _lap_label := Label.new()
var _time_label := Label.new()
var _best_label := Label.new()
var _last_label := Label.new()
var _total_label := Label.new()
var _results := Label.new()
var _center_label := Label.new()
var _message_time := 0.0
var _lights := StartLights.new()


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)

	var info := VBoxContainer.new()
	info.position = Vector2(24, 286 if track else 18)
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
	for label in [_lap_label, _time_label, _total_label, _last_label, _best_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		times.add_child(label)
	_lap_label.add_theme_font_size_override("font_size", 32)
	_time_label.add_theme_font_size_override("font_size", 30)

	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.offset_left = -420
	_results.offset_right = 420
	_results.offset_top = -60
	_results.offset_bottom = 200
	_results.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results.add_theme_font_size_override("font_size", 34)
	_results.add_theme_constant_override("outline_size", 10)
	_results.visible = false
	root.add_child(_results)

	root.add_child(_lights)
	_lights.set_anchors_preset(Control.PRESET_CENTER)
	_lights.offset_left = -150
	_lights.offset_right = 150
	_lights.offset_top = -260
	_lights.offset_bottom = -160
	_lights.visible = false

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
		minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE, 20)

		var arrow := DirectionArrow.new()
		arrow.track = track
		arrow.swan = swan
		arrow.size = Vector2(120, 120)
		root.add_child(arrow)
		arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE, 14)

	_speedometer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_speedometer.custom_minimum_size = Vector2(230, 230)
	_speedometer.size = Vector2(230, 230)
	_speedometer.position = Vector2(-254, -254)
	root.add_child(_speedometer)

	var stamina := StaminaBar.new()
	stamina.swan = swan
	root.add_child(stamina)
	stamina.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stamina.offset_left = -340
	stamina.offset_right = -24
	stamina.offset_top = -300
	stamina.offset_bottom = -262

	var pedals := PedalBars.new()
	pedals.swan = swan
	root.add_child(pedals)
	# Just left of the speedometer, bottom right.
	pedals.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pedals.offset_left = -340
	pedals.offset_right = -270
	pedals.offset_top = -236
	pedals.offset_bottom = -36

	# Drawing of the controls in use, lit up while pressed.
	var controls := InputDisplay.new()
	root.add_child(controls)
	controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 20
	controls.offset_right = 380
	controls.offset_top = -190
	controls.offset_bottom = -16


func _process(delta: float) -> void:
	if swan:
		_speedometer.speed_kmh = swan.motor.speed * 3.6
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_center_label.text = ""


func set_lap(lap: int, total: int, lap_time: float, last_lap: float, race_time: float) -> void:
	_lap_label.text = tr("HUD_LAP_OF") % [lap, total]
	_time_label.text = format_time(lap_time)
	_total_label.text = tr("HUD_TOTAL") % format_time(race_time)
	_last_label.text = tr("HUD_LAST") % format_time(last_lap) if last_lap > 0.0 else ""


func set_best(best: float) -> void:
	_best_label.text = tr("HUD_BEST") % (format_time(best) if best > 0.0 else "--:--.--")


func show_message(text: String, seconds: float) -> void:
	_center_label.text = text
	_message_time = seconds


## 74.5 -> "1:14.50"
static func format_time(seconds: float) -> String:
	var hundredths := roundi(seconds * 100.0)
	return "%d:%02d.%02d" % [hundredths / 6000, (hundredths / 100) % 60, hundredths % 100]


## Start lights: `lit` red lamps, or all green with `go`; hidden with -1.
func set_start_lights(lit: int, go := false) -> void:
	_lights.visible = lit >= 0
	_lights.lit = maxi(lit, 0)
	_lights.go = go


## Race over: big "Finished!" with the total time, best lap and what to do next.
func show_results(race_time: float, best_lap: float) -> void:
	show_message(tr("FINISHED"), 999.0)
	_results.text = "%s\n%s\n\n%s" % [tr("HUD_TOTAL") % format_time(race_time),
			tr("HUD_BEST") % format_time(best_lap), tr("RESULTS_HINT_" + InputGlyphs._suffix())]
	_results.visible = true
