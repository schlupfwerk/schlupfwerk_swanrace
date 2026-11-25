extends Node3D
## Wardrobe: customize the swan, then race. Fully usable with keyboard or
## controller; mouse and touch are optional. The swan turns by itself until
## the player turns it (Q/E, LB/RB, right stick or dragging with the mouse).

const RACE_SCENE := "res://scenes/race.tscn"
const STYLE_OPTIONS: PackedStringArray = ["SOLID", "GRADIENT"]
## Slot rows: slot, label, color label, camera zone, [item id, item label]...
## ("" = none).
const SLOT_ROWS := [
	["head", "HEAD", "HEAD_COLOR", "head", [["", "NONE"], ["cap", "CAP"], ["straw_hat", "STRAW_HAT"],
			["top_hat", "TOP_HAT"], ["cowboy_hat", "COWBOY_HAT"], ["beanie", "BEANIE"],
			["wig", "WIG_CURLY"], ["wig_long", "WIG_LONG"]]],
	["outfit", "OUTFIT", "OUTFIT_COLOR", "body", [["", "NONE"], ["jacket", "LEATHER_JACKET"],
			["winter_jacket", "WINTER_JACKET"], ["tank_top", "TANK_TOP"], ["hoodie", "HOODIE"]]],
	["necklace", "NECKLACE", "NECKLACE_COLOR", "neck", [["", "NONE"],
			["necklace_round", "NECKLACE_ROUND"], ["necklace", "NECKLACE_V"],
			["necklace_pearls", "NECKLACE_PEARLS"]]],
	["back", "BACK_ITEM", "BACK_COLOR", "back", [["", "NONE"], ["backpack", "BACKPACK"], ["bag", "BAG"],
			["cape", "CAPE"], ["dog_bag", "DOG_BAG"], ["cat_bag", "CAT_BAG"],
			["ostrich_egg", "OSTRICH_EGG"]]],
	["footwear", "FOOTWEAR", "FOOTWEAR_COLOR", "feet", [["", "BAREFOOT"], ["sneakers", "SNEAKERS"],
			["boots", "BOOTS"], ["shoes", "SHOES"], ["flip_flops", "FLIP_FLOPS"]]],
]
## Items that are on or off with a color (lipstick, socks), or just on or off
## (lashes). Each with its camera zone.
const EXTRA_ROWS := [["lipstick", "LIPSTICK", "head", true], ["lashes", "LASHES", "head", false],
		["socks", "SOCKS", "feet", true]]
const GLASSES_LABELS: PackedStringArray = ["NONE", "GLASSES_ROUND", "GLASSES_SQUARE",
		"GLASSES_AVIATOR", "GLASSES_VISOR"]
const TURN_SPEED := 2.2
const AUTO_TURN_SPEED := 0.4
const DEFAULT_ITEM_COLOR := Color("e8413c")
## How close the camera gets to each part (smaller = closer).
const ZOOM := {"head": 0.7, "neck": 0.9, "body": 1.4, "back": 1.5, "feet": 1.0}
const FULL_CAMERA := Vector3(0.2, 1.6, 5.4)
const FULL_LOOK := Vector3(0.2, 1.3, 0)

var _look: SwanLook
var _model := SwanModel.new()
var _nickname_edit := LineEdit.new()
var _color_2_row: OptionRow
## Color rows that only make sense when something is chosen: row -> Callable.
var _dependent_rows := {}
var _hint := Label.new()
var _start_label := Label.new()
## Every focusable row in order, for one up/down path through the menu.
var _rows: Array[Control] = []
var _settings_button := Button.new()
var _panel: PanelContainer
var _layer: CanvasLayer
var _auto_turn := true
## Part of the swan the focused row is about ("full", "head", "neck", ...).
var _zone := "full"
## Zone given to the rows being built.
var _building_zone := "full"
## True once the player turns the swan by hand (until the zone changes).
var _manual_turn := false
var _camera := Camera3D.new()
var _look_at := FULL_LOOK
var _music := AudioStreamPlayer.new()

static var _music_stream: AudioStreamWAV
static var _music_rendering := false


func _ready() -> void:
	_look = Profile.look
	_build_stage()
	_build_menu()
	_refresh()
	_rows[0].grab_focus()
	_music.bus = &"Music"
	_music.volume_db = -4.0
	add_child(_music)
	if _music_stream == null and not _music_rendering:
		_music_rendering = true
		WorkerThreadPool.add_task(func() -> void: _music_stream = SoftMusic.load_or_render())


func _process(delta: float) -> void:
	var turn := Input.get_axis("turn_model_left", "turn_model_right") if _panel.visible else 0.0
	if absf(turn) > 0.1:
		_auto_turn = false
		_manual_turn = true
		_model.rotation.y += turn * TURN_SPEED * delta
	elif _zone != "full" and not _manual_turn:
		# Show the part being edited.
		_model.rotation.y = lerp_angle(_model.rotation.y, _zone_yaw(), 1.0 - exp(-4.0 * delta))
	elif _auto_turn:
		_model.rotation.y += delta * AUTO_TURN_SPEED
	_model.animate(delta, 0.0, 0.0, 0.0, 0.0, true)
	_move_camera(delta)
	if _music_stream and not _music.playing:
		_music.stream = _music_stream
		_music.play()
	_start_label.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.005)


func _input(event: InputEvent) -> void:
	# Start (controller) or Enter (keyboard) races, unless typing the nickname.
	if _panel.visible and event.is_action_pressed("start_race") and not _nickname_edit.has_focus():
		get_viewport().set_input_as_handled()
		_on_race()


func _unhandled_input(event: InputEvent) -> void:
	# Drag on the swan (outside the menu) to turn it.
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_auto_turn = false
		_manual_turn = true
		_model.rotation.y += event.relative.x * 0.01


func _build_stage() -> void:
	Scenery.add_environment(self)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 2.2
	floor_mesh.bottom_radius = 2.3
	floor_mesh.height = 0.2
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.position = Vector3(2.2, -0.1, 0)
	floor_instance.material_override = Scenery.flat(Scenery.SAND, 1.0)
	add_child(floor_instance)

	_model.position = Vector3(2.2, 0, 0)
	_model.rotation.y = PI - 0.6
	add_child(_model)

	_camera.position = FULL_CAMERA
	_camera.fov = 50.0
	add_child(_camera)
	_camera.look_at(FULL_LOOK)
	_camera.make_current()


func _build_menu() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_layer = layer
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	layer.add_child(root)

	# The whole left side: every option at once, no scrolling.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_bottom = -16
	panel.anchor_right = 0.62
	panel.offset_right = 0
	root.add_child(panel)
	_panel = panel
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var title := Label.new()
	title.text = tr("WARDROBE_TITLE")
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)
	_nickname_edit.max_length = SwanLook.NICKNAME_MAX_LENGTH
	_nickname_edit.placeholder_text = tr("NICKNAME_PLACEHOLDER")
	_nickname_edit.text = _look.nickname
	_nickname_edit.custom_minimum_size.y = 34
	_nickname_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nickname_edit.add_theme_font_size_override("font_size", 18)
	_nickname_edit.text_changed.connect(_on_nickname_changed)
	header.add_child(_nickname_edit)
	var random_button := Button.new()
	random_button.text = tr("RANDOM_NICKNAME")
	random_button.add_theme_font_size_override("font_size", 16)
	random_button.pressed.connect(_on_random_nickname)
	header.add_child(random_button)

	# Two columns of options; up/down walks the first column, then the second.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(columns)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for side: VBoxContainer in [left, right]:
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.add_theme_constant_override("separation", 4)
		columns.add_child(side)

	# Feathers and legs, head and glasses on the left.
	_building_zone = "full"
	_row(left, "FEATHERS", _translated(STYLE_OPTIONS), _look.feather_style, func(i: int) -> void:
		_look.feather_style = i as SwanLook.FeatherStyle)
	_color_row(left, "FEATHER_COLOR", _look.feather_color, func(c: Color) -> void:
		_look.feather_color = c)
	_color_2_row = _color_row(left, "TOP_COLOR", _look.feather_color_2, func(c: Color) -> void:
		_look.feather_color_2 = c)
	_building_zone = "feet"
	_color_row(left, "LEGS", _look.leg_color, func(c: Color) -> void:
		_look.leg_color = c)
	var head_row: Array = SLOT_ROWS[0]
	_building_zone = head_row[3]
	_add_slot_rows(left, head_row[0], head_row[1], head_row[2], head_row[4])
	_building_zone = "head"
	_row(left, "GLASSES", _translated(GLASSES_LABELS),
			SwanLook.GLASSES_STYLES.find(_look.glasses_style) + 1, func(i: int) -> void:
				_look.glasses_style = "" if i == 0 else SwanLook.GLASSES_STYLES[i - 1])
	var has_glasses := func() -> bool: return _look.glasses_style != ""
	_dependent_rows[_color_row(left, "FRAME_COLOR", _look.glasses_frame, func(c: Color) -> void:
		_look.glasses_frame = c)] = has_glasses
	_dependent_rows[_row(left, "LENS", _translated(STYLE_OPTIONS),
			int(_look.glasses_lens_gradient), func(i: int) -> void:
				_look.glasses_lens_gradient = i == 1)] = has_glasses
	_dependent_rows[_color_row(left, "LENS_COLOR", _look.glasses_lens, func(c: Color) -> void:
		_look.glasses_lens = c)] = has_glasses
	_dependent_rows[_color_row(left, "LENS_COLOR_2", _look.glasses_lens_2, func(c: Color) -> void:
		_look.glasses_lens_2 = c)] = func() -> bool:
			return _look.glasses_style != "" and _look.glasses_lens_gradient
	_row(left, "LASHES", PackedStringArray([tr("NO"), tr("YES")]), int(_look.is_wearing("lashes")),
			func(i: int) -> void:
				if i == 0:
					_look.accessories.erase("lashes")
				else:
					_look.accessories["lashes"] = Color.BLACK)

	# Outfit, necklace, back, footwear and extras on the right.
	for slot_row: Array in SLOT_ROWS.slice(1):
		_building_zone = slot_row[3]
		_add_slot_rows(right, slot_row[0], slot_row[1], slot_row[2], slot_row[4])
	var extra_options := PackedStringArray([tr("NONE")])
	extra_options.append_array(SwanPalette.display_names())
	var yes_no := PackedStringArray([tr("NO"), tr("YES")])
	for extra: Array in EXTRA_ROWS:
		var id: String = extra[0]
		if id == "lashes":
			continue
		var colored: bool = extra[3]
		_building_zone = extra[2]
		var current := 0
		if _look.is_wearing(id):
			current = SwanPalette.closest(_look.accessories[id]) + 1 if colored else 1
		_row(right, extra[1], extra_options if colored else yes_no,
				current, func(i: int) -> void:
					if i == 0:
						_look.accessories.erase(id)
					else:
						_look.accessories[id] = SwanPalette.colors[i - 1] if colored else Color.BLACK)
	_building_zone = "full"

	# Race options: laps and how many swans race.
	var race_options := HBoxContainer.new()
	race_options.add_theme_constant_override("separation", 10)
	column.add_child(race_options)
	var lap_names := PackedStringArray()
	for value in Settings.LAP_OPTIONS:
		lap_names.append(str(value))
	var racer_names := PackedStringArray()
	for value in range(1, 13):
		racer_names.append(str(value))
	for entry in [["LAPS", lap_names, maxi(Settings.LAP_OPTIONS.find(Settings.laps), 0)],
			["RACERS", racer_names, Settings.racers - 1]]:
		var row := OptionRow.new().setup(tr(entry[0]), entry[1], entry[2]).compact()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.focus_entered.connect(_focus_zone.bind("full"))
		var key: String = entry[0]
		row.value_changed.connect(func(i: int) -> void:
			if key == "LAPS":
				Settings.laps = Settings.LAP_OPTIONS[i]
			else:
				Settings.racers = i + 1
			Settings.save_settings())
		race_options.add_child(row)
		_rows.append(row)

	# The race starts with Start (controller) or Enter (keyboard).
	_start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start_label.add_theme_font_size_override("font_size", 28)
	_start_label.add_theme_color_override("font_color", UiTheme.FOCUS_COLOR)
	column.add_child(_start_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_settings_button.text = tr("SETTINGS")
	_settings_button.custom_minimum_size = Vector2(200, 40)
	_settings_button.add_theme_font_size_override("font_size", 18)
	_settings_button.pressed.connect(_on_settings)
	_settings_button.focus_entered.connect(_focus_zone.bind("full"))
	buttons.add_child(_settings_button)
	var quit_button := Button.new()
	quit_button.text = tr("QUIT")
	quit_button.custom_minimum_size = Vector2(120, 40)
	quit_button.add_theme_font_size_override("font_size", 18)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit_button)
	_rows.append_array([_settings_button, quit_button])

	_hint.add_theme_font_size_override("font_size", 15)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)

	# One focus path through everything: down the left column, then the right.
	for n in _rows.size() - 1:
		var here: Control = _rows[n]
		var next: Control = _rows[n + 1]
		here.focus_neighbor_bottom = here.get_path_to(next)
		next.focus_neighbor_top = next.get_path_to(here)

	var version := Label.new()
	version.text = GameVersion.label()
	version.add_theme_font_size_override("font_size", 14)
	version.modulate = Color(1, 1, 1, 0.75)
	root.add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	InputGlyphs.changed.connect(_update_hint)
	_update_hint()


## A slot: one row to pick the item and one for its color.
func _add_slot_rows(list: VBoxContainer, slot: String, label: String, color_label: String,
		items: Array) -> void:
	var ids := []
	var labels := PackedStringArray()
	for item: Array in items:
		ids.append(item[0])
		labels.append(tr(item[1]))
	var color := _look.slot_color(slot, DEFAULT_ITEM_COLOR)
	_row(list, label, labels, maxi(ids.find(_look.slot_item(slot)), 0), func(i: int) -> void:
		_look.set_slot(slot, ids[i], _look.slot_color(slot, color)))
	var color_row := _color_row(list, color_label, color, func(c: Color) -> void:
		color = c
		_look.set_slot(slot, _look.slot_item(slot), c))
	_dependent_rows[color_row] = func() -> bool: return _look.slot_item(slot) != ""


func _row(list: VBoxContainer, label: String, options: PackedStringArray, index: int,
		on_change: Callable) -> OptionRow:
	var row := OptionRow.new().setup(tr(label), options, index).compact()
	_rows.append(row)
	row.focus_entered.connect(_focus_zone.bind(_building_zone))
	row.value_changed.connect(func(i: int) -> void:
		on_change.call(i)
		_refresh())
	list.add_child(row)
	return row


func _color_row(list: VBoxContainer, label: String, color: Color, on_change: Callable) -> OptionRow:
	return _row(list, label, SwanPalette.display_names(), SwanPalette.closest(color),
			func(i: int) -> void: on_change.call(SwanPalette.colors[i]))


func _refresh() -> void:
	_color_2_row.set_enabled(_look.feather_style == SwanLook.FeatherStyle.GRADIENT)
	for row: OptionRow in _dependent_rows:
		row.set_enabled((_dependent_rows[row] as Callable).call())
	_model.apply_look(_look)


func _on_nickname_changed(new_text: String) -> void:
	var trimmed := new_text.strip_edges()
	_look.nickname = trimmed if not trimmed.is_empty() else tr("DEFAULT_NICKNAME")


func _on_random_nickname() -> void:
	_nickname_edit.text = Nicknames.random()
	_on_nickname_changed(_nickname_edit.text)


func _on_race() -> void:
	Profile.look = _look
	Profile.save_profile()
	get_tree().change_scene_to_file(RACE_SCENE)


func _update_hint() -> void:
	_hint.text = InputGlyphs.wardrobe_hint()
	_start_label.text = tr("PRESS_START_" + InputGlyphs._suffix())


func _on_settings() -> void:
	_panel.visible = false
	var language := TranslationServer.get_locale()
	var menu := SettingsMenu.new()
	menu.closed.connect(func() -> void:
		if TranslationServer.get_locale() != language:
			# Rebuild every text in the new language.
			get_tree().reload_current_scene()
			return
		menu.queue_free()
		_panel.visible = true
		_settings_button.grab_focus())
	_layer.add_child(menu)


static func _translated(keys: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for key in keys:
		out.append(TranslationServer.translate(key))
	return out


func _focus_zone(zone: String) -> void:
	if zone != _zone:
		_zone = zone
		_manual_turn = false
		if zone == "full":
			_auto_turn = true


## Which way to turn the swan to show the part being edited.
func _zone_yaw() -> float:
	if _zone == "back":
		match _look.slot_item("back"):
			"bag":
				return -PI / 2.0
			"dog_bag", "cat_bag":
				return PI / 2.0
		return 0.35
	return PI - 0.45


## Glide the camera to the part being edited (or the whole swan).
func _move_camera(delta: float) -> void:
	var target := FULL_CAMERA
	var look := FULL_LOOK
	if _zone != "full":
		var distance: float = ZOOM.get(_zone, 1.0)
		look = _model.anchor(_zone) + Vector3(-1.0 * distance, 0.0, 0.0)
		target = look + Vector3(0.0, 0.25 * distance, 2.0 * distance)
	var blend := 1.0 - exp(-5.0 * delta)
	_camera.position = _camera.position.lerp(target, blend)
	_look_at = _look_at.lerp(look, blend)
	_camera.look_at(_look_at)
