class_name Hud
extends CanvasLayer
## Race HUD: nickname, terrain, laps and times, countdown, messages,
## speedometer and control hints. With touch controls on screen, the gauges
## move to the bottom center and the pedal and button drawings go away.

signal race_again_pressed
signal menu_pressed

var swan: Swan
## The other swans (bots), shown in gray on the minimap.
var others: Array[Swan] = []
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
var _alert := Label.new()
var _place := Label.new()
var _info: VBoxContainer
var _stamina: StaminaBar
var _pedals: PedalBars
var _controls: InputDisplay


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)

	var info := VBoxContainer.new()
	_info = info
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

	_alert.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alert.offset_left = -300
	_alert.offset_right = 300
	_alert.offset_top = 150
	_alert.offset_bottom = 210
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert.add_theme_font_size_override("font_size", 44)
	_alert.add_theme_color_override("font_color", Color("ff8a2a"))
	_alert.add_theme_constant_override("outline_size", 10)
	_alert.text = tr("JUMP_ALERT")
	_alert.visible = false
	root.add_child(_alert)

	# Race position, big, under the lap counter.
	_place.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_place.offset_left = -300
	_place.offset_right = -24
	_place.offset_top = 300
	_place.offset_bottom = 370
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place.add_theme_font_size_override("font_size", 52)
	_place.add_theme_color_override("font_color", UiTheme.FOCUS_COLOR)
	_place.add_theme_constant_override("outline_size", 10)
	root.add_child(_place)

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
		minimap.swans = [swan] as Array[Swan]
		minimap.swans.append_array(others)
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
	_stamina = stamina
	stamina.swan = swan
	root.add_child(stamina)
	stamina.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stamina.offset_left = -340
	stamina.offset_right = -24
	stamina.offset_top = -300
	stamina.offset_bottom = -262

	var pedals := PedalBars.new()
	_pedals = pedals
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
	_controls = controls
	root.add_child(controls)
	controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 20
	controls.offset_right = 380
	controls.offset_top = -190
	controls.offset_bottom = -16
	InputGlyphs.changed.connect(_apply_layout)
	_apply_layout()


## Touch: the on-screen buttons take both bottom corners, so the speedometer
## and the turbo bar move to the bottom center (smaller), and the pedal and
## button drawings hide (the lit buttons already show what is pressed).
func _apply_layout() -> void:
	var touch := InputGlyphs.touch()
	_pedals.visible = not touch
	_controls.visible = not touch
	if touch:
		# Nickname and terrain right of the minimap (accelerate sits below it);
		# the race position moves left of the turbo button.
		_info.position = Vector2(300, 140)
		_place.offset_left = -560
		_place.offset_right = -230
		_place_box(_speedometer, Vector2(0.5, 1.0), Rect2(-90, -200, 180, 180))
		_place_box(_stamina, Vector2(0.5, 1.0), Rect2(-150, -250, 300, 36))
	else:
		_info.position = Vector2(24, 286 if track else 18)
		_place.offset_left = -300
		_place.offset_right = -24
		_place_box(_speedometer, Vector2(1.0, 1.0), Rect2(-254, -254, 230, 230))
		_place_box(_stamina, Vector2(1.0, 1.0), Rect2(-340, -300, 316, 38))


static func _place_box(control: Control, anchor: Vector2, box: Rect2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.custom_minimum_size = Vector2.ZERO
	control.offset_left = box.position.x
	control.offset_top = box.position.y
	control.offset_right = box.end.x
	control.offset_bottom = box.end.y

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


## Race over: the standings across the bottom of the screen (in columns of 6,
## the player highlighted), the best lap of the race and what to do next.
## Everything else of the race HUD goes away so the podium shows above.
func show_results(standings: Array[Dictionary]) -> void:
	var root := _results.get_parent()
	for child in root.get_children():
		if child is CanvasItem:
			child.visible = false
			child.process_mode = Node.PROCESS_MODE_DISABLED
	var board := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.75)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(16)
	board.add_theme_stylebox_override("panel", style)
	root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 20)
	board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	board.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	board.add_child(column)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	column.add_child(columns)
	var fastest := {}
	var label: RichTextLabel
	for n in standings.size():
		if n % 6 == 0:
			label = _board_label(20)
			columns.add_child(label)
		var entry: Dictionary = standings[n]
		var best: float = entry.get("best", 0.0)
		var line := "%d.  %s   %s   (%s)" % [n + 1, entry.name, format_time(entry.time),
				format_time(best) if best > 0.0 else "--"]
		# The player stands out in yellow.
		label.text += ("» [color=#ffd23f]%s[/color]" % line if entry.player else line) + "\n"
		if best > 0.0 and (fastest.is_empty() or best < fastest.best):
			fastest = entry
	var footer := _board_label(18)
	if not fastest.is_empty():
		footer.text = tr("PODIUM_BEST_LAP") % [format_time(fastest.best), fastest.name] + "      "
	footer.text += tr("RESULTS_HINT_" + InputGlyphs._suffix())
	column.add_child(footer)
	# Buttons for touch and mouse (Enter / A and Esc / B still work too).
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	for entry in [["RACE_AGAIN", race_again_pressed], ["TO_MENU", menu_pressed]]:
		var button := Button.new()
		button.text = tr(entry[0])
		button.custom_minimum_size = Vector2(240, 60)
		button.add_theme_font_size_override("font_size", 24)
		button.focus_mode = Control.FOCUS_NONE
		var signal_to_emit: Signal = entry[1]
		button.pressed.connect(func() -> void: signal_to_emit.emit())
		buttons.add_child(button)


static func _board_label(font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label


## "Jump!" warning, pulsing while an obstacle is ahead.
func show_jump_alert(on: bool) -> void:
	_alert.visible = on
	if on:
		_alert.scale = Vector2.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.02))
		_alert.pivot_offset = _alert.size / 2.0


## "3/8": place in the race (hidden when racing alone).
func set_place(place: int, count: int) -> void:
	_place.visible = count > 1
	_place.text = "%dº / %d" % [place, count]
