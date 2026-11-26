extends Node3D
## Home: three tabs at the top (My characters, Race, Settings) over a demo
## race seen from a drone. Fully usable with keyboard or controller.
##
## Race tab: laps, racers and difficulty, and the RACE button. It opens the
## character selector: "Race like this" starts the race, "Customize" goes to
## My characters with that character.

const RACE_SCENE := "res://scenes/race.tscn"
enum Tab { CHARACTERS, RACE, SETTINGS, ABOUT }
const TAB_KEYS: PackedStringArray = ["TAB_CHARACTERS", "TAB_RACE", "TAB_SETTINGS", "TAB_ABOUT"]
## The studio site (about tab), opened in the visitor's language: /pt or /en.
const SITE := "https://schlupfwerk.com"
const LOGO := preload("res://assets/brand/schlupfwerk_logo.svg")
## The character stage floats far above the island, out of the demo's sight.
const EDITOR_SPOT := Vector3(0, 400, 0)

var _demo := DemoRace.new()
var _editor := CharacterEditor.new()
var _tab := Tab.RACE
var _tab_buttons: Array[Button] = []
var _root: Control
var _race_panel: PanelContainer
var _race_button := Button.new()
var _first_race_row: Control
var _selector: PanelContainer
var _selector_row: OptionRow
var _go_button := Button.new()
var _customize_button: Button
var _settings: SettingsMenu
var _about_panel: PanelContainer
var _site_button := Button.new()
var _gate := ParentalGate.new()
var _hint := Label.new()
var _music := AudioStreamPlayer.new()

static var _music_stream: AudioStreamWAV
static var _music_rendering := false


func _ready() -> void:
	Settings.apply_menu_scale(true)
	Scenery.add_environment(self)
	add_child(_demo)
	_editor.position = EDITOR_SPOT
	add_child(_editor)
	_build_ui()
	_music.bus = &"Music"
	_music.volume_db = -4.0
	add_child(_music)
	if _music_stream == null and not _music_rendering:
		_music_rendering = true
		WorkerThreadPool.add_task(func() -> void: _music_stream = SoftMusic.load_or_render())
	_select_tab.call_deferred(Tab.RACE)


func _process(_delta: float) -> void:
	if _music_stream and not _music.playing:
		_music.stream = _music_stream
		_music.play()
	_race_button.modulate.a = 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.006) \
			if _race_button.has_focus() else 1.0


func _input(event: InputEvent) -> void:
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if typing:
		return
	# On the tab bar: left/right switch tabs (once per press), down enters the tab.
	var on_bar := get_viewport().gui_get_focus_owner() in _tab_buttons
	if on_bar and event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_select_tab(wrapi(_tab - 1, 0, Tab.size()), true)
		return
	if on_bar and event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_select_tab(wrapi(_tab + 1, 0, Tab.size()), true)
		return
	if on_bar and event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_focus_content()
		return
	if event.is_action_pressed("home_prev_tab"):
		get_viewport().set_input_as_handled()
		_select_tab(wrapi(_tab - 1, 0, Tab.size()))
	elif event.is_action_pressed("home_next_tab"):
		get_viewport().set_input_as_handled()
		_select_tab(wrapi(_tab + 1, 0, Tab.size()))
	elif event.is_action_pressed("start_race") and _tab == Tab.RACE:
		get_viewport().set_input_as_handled()
		if _selector.visible:
			_race_now()
		else:
			_open_selector()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _selector.visible:
		_close_selector()
	elif _gate.visible:
		_gate.cancel()
	elif _tab == Tab.CHARACTERS:
		_select_tab(Tab.RACE)
	else:
		return
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.make()
	layer.add_child(_root)

	# The tabs, centered at the top.
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 14
	bar.offset_bottom = 62
	_root.add_child(bar)
	var group := ButtonGroup.new()
	for n in TAB_KEYS.size():
		var button := Button.new()
		button.text = tr(TAB_KEYS[n])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(230, 46)
		button.add_theme_font_size_override("font_size", 22)
		button.focus_mode = Control.FOCUS_ALL
		# The open tab stands out in yellow.
		var open := StyleBoxFlat.new()
		open.bg_color = UiTheme.FOCUS_COLOR
		open.set_corner_radius_all(10)
		button.add_theme_stylebox_override("pressed", open)
		button.add_theme_stylebox_override("hover_pressed", open)
		button.add_theme_color_override("font_pressed_color", Color("1d1d24"))
		button.add_theme_color_override("font_hover_pressed_color", Color("1d1d24"))
		button.pressed.connect(_select_tab.bind(n))
		bar.add_child(button)
		_tab_buttons.append(button)

	_hint.add_theme_font_size_override("font_size", 15)
	_hint.modulate = Color(1, 1, 1, 0.85)
	_root.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	var version := Label.new()
	version.text = GameVersion.label()
	version.add_theme_font_size_override("font_size", 14)
	version.modulate = Color(1, 1, 1, 0.75)
	_root.add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	InputGlyphs.changed.connect(_update_hint)
	_update_hint()

	_build_race_panel()
	_build_selector()
	_build_about()
	# Up from the top of a tab goes back to the tab bar.
	_editor.set_tab_button(_tab_buttons[Tab.CHARACTERS])
	_first_race_row.focus_neighbor_top = _first_race_row.get_path_to(_tab_buttons[Tab.RACE])


## Race tab: the options for the next race and the big RACE button.
func _build_race_panel() -> void:
	_race_panel = PanelContainer.new()
	_race_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_race_panel.custom_minimum_size = Vector2(560, 0)
	_race_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_race_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_race_panel.offset_bottom = -48
	_root.add_child(_race_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_race_panel.add_child(column)
	var map_names := PackedStringArray()
	for entry: Dictionary in Maps.LIST:
		map_names.append(tr(entry.name))
	var map_row := OptionRow.new().setup(tr("MAP"), map_names, Maps.index_of(Settings.map)).compact()
	column.add_child(map_row)

	var lap_names := PackedStringArray()
	for value in Settings.LAP_OPTIONS:
		lap_names.append(str(value))
	var racer_names := PackedStringArray()
	for value in range(1, 13):
		racer_names.append(str(value))
	var difficulty_names := PackedStringArray()
	for key in ["DIFFICULTY_EASY", "DIFFICULTY_MEDIUM", "DIFFICULTY_HARD"]:
		difficulty_names.append(tr(key))
	var rows: Array[Control] = [map_row]
	var lap_row: OptionRow
	for entry in [["LAPS", lap_names, maxi(Settings.LAP_OPTIONS.find(Settings.laps), 0)],
			["RACERS", racer_names, Settings.racers - 1],
			["DIFFICULTY", difficulty_names, Settings.difficulty]]:
		var row := OptionRow.new().setup(tr(entry[0]), entry[1], entry[2]).compact()
		var key: String = entry[0]
		row.value_changed.connect(func(i: int) -> void:
			match key:
				"LAPS":
					Settings.laps = Settings.LAP_OPTIONS[i]
				"RACERS":
					Settings.racers = i + 1
				"DIFFICULTY":
					Settings.difficulty = i
			Settings.save_settings())
		column.add_child(row)
		rows.append(row)
		if key == "LAPS":
			lap_row = row
	# Courses go from a start to a finish: no laps to pick.
	lap_row.set_enabled(Maps.has_laps(Settings.map))
	map_row.value_changed.connect(func(i: int) -> void:
		Settings.map = Maps.LIST[i].id
		lap_row.set_enabled(Maps.has_laps(Settings.map))
		Settings.save_settings())
	_race_button.text = tr("RACE_BUTTON")
	_race_button.custom_minimum_size = Vector2(0, 64)
	_race_button.add_theme_font_size_override("font_size", 32)
	_race_button.pressed.connect(_open_selector)
	column.add_child(_race_button)
	rows.append(_race_button)
	# On PC: quit the game. Asks once ("Press again to quit") so a stray press
	# does not close it; moving away cancels.
	if Settings.is_desktop():
		var quit := Button.new()
		quit.text = tr("QUIT_GAME")
		quit.add_theme_font_size_override("font_size", 20)
		quit.pressed.connect(func() -> void:
			if quit.text == tr("QUIT_CONFIRM"):
				get_tree().quit()
			else:
				quit.text = tr("QUIT_CONFIRM"))
		quit.focus_exited.connect(func() -> void: quit.text = tr("QUIT_GAME"))
		quit.mouse_exited.connect(func() -> void:
			if not quit.has_focus():
				quit.text = tr("QUIT_GAME"))
		column.add_child(quit)
		rows.append(quit)
	_chain(rows)
	_first_race_row = rows[0]


## Character selector: which saved swan races, then race or customize it.
func _build_selector() -> void:
	_selector = PanelContainer.new()
	_selector.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_selector.custom_minimum_size = Vector2(640, 0)
	_selector.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_selector.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_selector.offset_bottom = -48
	_selector.visible = false
	_root.add_child(_selector)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_selector.add_child(column)
	var title := Label.new()
	title.text = tr("CHOOSE_CHARACTER")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	_selector_row = OptionRow.new().setup(tr("CHARACTER"), CharacterEditor.character_names(),
			Profile.selected)
	_selector_row.value_changed.connect(func(i: int) -> void:
		_editor.show_character(i)
		Profile.save_profile())
	column.add_child(_selector_row)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_go_button.text = tr("RACE_AS_IS")
	_go_button.custom_minimum_size = Vector2(260, 56)
	_go_button.add_theme_font_size_override("font_size", 24)
	_go_button.pressed.connect(_race_now)
	buttons.add_child(_go_button)
	var customize := Button.new()
	_customize_button = customize
	customize.text = tr("CUSTOMIZE")
	customize.custom_minimum_size = Vector2(260, 56)
	customize.add_theme_font_size_override("font_size", 24)
	customize.pressed.connect(func() -> void:
		_close_selector()
		_select_tab(Tab.CHARACTERS))
	buttons.add_child(customize)
	_selector_row.focus_neighbor_bottom = _selector_row.get_path_to(_go_button)
	_go_button.focus_neighbor_top = _go_button.get_path_to(_selector_row)
	customize.focus_neighbor_top = customize.get_path_to(_selector_row)
	# Left/right between the two buttons (and nowhere else), down stays put,
	# up from the character row goes to the tab bar.
	_go_button.focus_neighbor_right = _go_button.get_path_to(customize)
	customize.focus_neighbor_left = customize.get_path_to(_go_button)
	_go_button.focus_neighbor_left = _go_button.get_path_to(_go_button)
	customize.focus_neighbor_right = customize.get_path_to(customize)
	_go_button.focus_neighbor_bottom = _go_button.get_path_to(_go_button)
	customize.focus_neighbor_bottom = customize.get_path_to(customize)
	_selector_row.focus_neighbor_top = _selector_row.get_path_to(_tab_buttons[Tab.RACE])


## About tab: who makes the game (texts from the studio site) and a button that
## opens the studio site in the browser. No payment or donation button in the
## game: store rules restrict them (the site has its own coffee page).
func _build_about() -> void:
	_about_panel = PanelContainer.new()
	_about_panel.set_anchors_preset(Control.PRESET_CENTER)
	_about_panel.custom_minimum_size = Vector2(760, 0)
	_about_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_about_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_about_panel.offset_top = 30
	_about_panel.visible = false
	_root.add_child(_about_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_about_panel.add_child(column)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 80)
	column.add_child(logo)
	for entry in [["ABOUT_TAGLINE", 22, Color("ffb020")], ["ABOUT_STUDIO", 18, Color.WHITE],
			["ABOUT_NAME", 18, Color.WHITE]]:
		var label := Label.new()
		label.text = tr(entry[0])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", entry[1])
		label.add_theme_color_override("font_color", entry[2])
		column.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var language := Settings.current_language()
	_site_button.text = tr("ABOUT_SITE")
	_site_button.custom_minimum_size = Vector2(300, 56)
	_site_button.add_theme_font_size_override("font_size", 22)
	# The link opens only after the parental gate (ADR 0009).
	_site_button.pressed.connect(func() -> void:
		buttons.visible = false
		_gate.open())
	buttons.add_child(_site_button)
	column.add_child(_gate)
	_gate.passed.connect(func() -> void:
		OS.shell_open("%s/%s" % [SITE, language])
		buttons.visible = true
		_site_button.grab_focus())
	_gate.cancelled.connect(func() -> void:
		buttons.visible = true
		_site_button.grab_focus())
	_site_button.focus_neighbor_top = _site_button.get_path_to(_tab_buttons[Tab.ABOUT])
	for side in ["focus_neighbor_bottom", "focus_neighbor_left", "focus_neighbor_right"]:
		_site_button.set(side, _site_button.get_path_to(_site_button))


## Opens a tab. `stay_on_bar` keeps the focus on the tab bar (arrows).
func _select_tab(tab: int, stay_on_bar := false) -> void:
	if _selector.visible:
		_close_selector(false)
	if _gate.visible:
		_gate.visible = false
		_site_button.get_parent().visible = true
	if _settings and tab != Tab.SETTINGS:
		_settings.queue_free()
		_settings = null
	_tab = tab as Tab
	for n in _tab_buttons.size():
		_tab_buttons[n].set_pressed_no_signal(n == tab)
	_race_panel.visible = tab == Tab.RACE
	_about_panel.visible = tab == Tab.ABOUT
	_editor.set_editing(tab == Tab.CHARACTERS)
	_hint.visible = tab != Tab.CHARACTERS
	match tab:
		Tab.CHARACTERS:
			_editor.make_current()
		Tab.RACE:
			_demo.make_current()
		Tab.SETTINGS:
			_demo.make_current()
			if _settings == null:
				_open_settings()
		Tab.ABOUT:
			_demo.make_current()
	if stay_on_bar:
		_tab_buttons[tab].grab_focus.call_deferred()
	else:
		_focus_content.call_deferred()


func _open_settings() -> void:
	var language := TranslationServer.get_locale()
	_settings = SettingsMenu.new()
	_settings.closed.connect(func() -> void:
		if TranslationServer.get_locale() != language:
			# Rebuild every text in the new language.
			get_tree().reload_current_scene()
			return
		_select_tab(Tab.RACE))
	_root.add_child(_settings)
	_settings.offset_top = 70


func _open_selector() -> void:
	_selector_row.set_options(CharacterEditor.character_names(), Profile.selected)
	_race_panel.visible = false
	_selector.visible = true
	_editor.set_editing(false)
	_editor.make_current()
	_go_button.grab_focus()


func _close_selector(back_to_race := true) -> void:
	_selector.visible = false
	if back_to_race:
		_select_tab(Tab.RACE)


func _race_now() -> void:
	Profile.save_profile()
	get_tree().change_scene_to_file(Maps.scene(Settings.map))


func _update_hint() -> void:
	_hint.text = tr("HOME_HINT_" + InputGlyphs._suffix())


static func _chain(rows: Array[Control]) -> void:
	for n in rows.size() - 1:
		rows[n].focus_neighbor_bottom = rows[n].get_path_to(rows[n + 1])
		rows[n + 1].focus_neighbor_top = rows[n + 1].get_path_to(rows[n])


## Focus the first thing inside the open tab.
func _focus_content() -> void:
	match _tab:
		Tab.CHARACTERS:
			_editor.focus_first()
		Tab.RACE:
			# The character selector replaces the race panel while it is open.
			if _selector.visible:
				_go_button.grab_focus()
			else:
				_race_button.grab_focus()
		Tab.SETTINGS:
			if _settings:
				_settings.focus_first()
		Tab.ABOUT:
			_site_button.grab_focus()
