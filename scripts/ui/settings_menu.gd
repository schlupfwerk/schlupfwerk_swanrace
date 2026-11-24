class_name SettingsMenu
extends Control
## Video and audio settings. Fully usable with keyboard or controller:
## up/down to choose, left/right to change, LB/RB (Q/E) to switch tabs,
## B/Esc to go back. Mouse and touch are optional.

signal closed

const WINDOW_MODES: PackedStringArray = ["Janela", "Tela cheia", "Tela cheia exclusiva"]
const QUALITY_NAMES: PackedStringArray = ["Baixa", "Média", "Alta", "Personalizada"]
const OFF_ON: PackedStringArray = ["Desligado", "Ligado"]
const VSYNC_NAMES: PackedStringArray = ["Desligado", "Ligado", "Adaptativo"]
const SHADOW_NAMES: PackedStringArray = ["Desligadas", "Baixas", "Médias", "Altas"]
const DETAIL_NAMES: PackedStringArray = ["Baixos", "Médios", "Altos"]

var _tab := 0
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _advanced_box := VBoxContainer.new()
var _advanced_button := Button.new()
var _quality_row: OptionRow
var _resolution_row: OptionRow
var _resolutions: Array[Vector2i] = []
var _advanced_rows := {}
var _gpu_info := Label.new()
var _hint := Label.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 640)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "Configurações"
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)
	for tab_name in ["Vídeo", "Áudio"]:
		var button := Button.new()
		button.text = tab_name
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(160, 44)
		button.pressed.connect(_show_tab.bind(_tab_buttons.size()))
		tabs.add_child(button)
		_tab_buttons.append(button)

	for builder in [_build_video_page, _build_audio_page]:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.follow_focus = true
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 6)
		scroll.add_child(list)
		builder.call(list)
		column.add_child(scroll)
		_pages.append(scroll)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	var reset := Button.new()
	reset.text = "Restaurar padrão"
	reset.custom_minimum_size.y = 48
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
	var back := Button.new()
	back.text = "Voltar"
	back.custom_minimum_size = Vector2(160, 48)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_close)
	buttons.add_child(back)

	_hint.add_theme_font_size_override("font_size", 18)
	column.add_child(_hint)
	InputGlyphs.changed.connect(_update_hint)
	_update_hint()
	_show_tab(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
	elif event.is_action_pressed("menu_prev_tab"):
		_show_tab(wrapi(_tab - 1, 0, _pages.size()))
	elif event.is_action_pressed("menu_next_tab"):
		_show_tab(wrapi(_tab + 1, 0, _pages.size()))
	else:
		return
	get_viewport().set_input_as_handled()


func _show_tab(index: int) -> void:
	_tab = index
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].button_pressed = i == index
	_focus_first(_pages[index])


func _focus_first(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.visible and (child as Control).focus_mode == Control.FOCUS_ALL:
			(child as Control).grab_focus()
			return
		if child is Control and child.visible:
			_focus_first(child)
			if get_viewport().gui_get_focus_owner() != null \
					and is_ancestor_of(get_viewport().gui_get_focus_owner()):
				return


# --- Video --------------------------------------------------------------------

func _build_video_page(list: VBoxContainer) -> void:
	if Settings.is_desktop():
		_add_row(list, "Modo de tela", WINDOW_MODES, Settings.window_mode, func(i: int) -> void:
			Settings.window_mode = i as Settings.WindowMode
			Settings.apply_window()
			_refresh_rows())

		_resolutions = Settings.available_resolutions()
		var labels := PackedStringArray()
		for r in _resolutions:
			labels.append("%d × %d" % [r.x, r.y])
		var current := _resolutions.find(Settings.resolution)
		_resolution_row = _add_row(list, "Resolução", labels, maxi(current, 0),
				func(i: int) -> void:
					Settings.resolution = _resolutions[i]
					Settings.apply_window())

		if DisplayServer.get_screen_count() > 1:
			var screens := PackedStringArray()
			for i in DisplayServer.get_screen_count():
				screens.append("Monitor %d" % (i + 1))
			_add_row(list, "Monitor", screens, Settings.monitor, func(i: int) -> void:
				Settings.monitor = i
				Settings.apply_window())

	_quality_row = _add_row(list, "Qualidade gráfica", QUALITY_NAMES, Settings.quality,
			func(i: int) -> void:
				Settings.set_quality(i as Settings.Quality)
				_refresh_rows())

	var fovs := PackedStringArray()
	for value in Settings.FOV_VALUES:
		fovs.append("%d°" % value)
	_add_row(list, "Campo de visão", fovs, Settings.FOV_VALUES.find(Settings.fov),
			func(i: int) -> void:
				Settings.fov = Settings.FOV_VALUES[i]
				Settings.changed.emit())

	_advanced_button.custom_minimum_size.y = 40
	_advanced_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_advanced_button.pressed.connect(func() -> void:
		_advanced_box.visible = not _advanced_box.visible
		_refresh_rows())
	list.add_child(_advanced_button)

	_advanced_box.visible = false
	_advanced_box.add_theme_constant_override("separation", 6)
	list.add_child(_advanced_box)
	var box := _advanced_box

	_advanced_rows.show_fps = _add_row(box, "Mostrar FPS e frequência da tela", OFF_ON,
			int(Settings.show_fps), func(i: int) -> void:
				Settings.show_fps = i == 1
				Settings.changed.emit())
	_advanced_rows.vsync = _add_row(box, "VSync", VSYNC_NAMES, Settings.vsync,
			func(i: int) -> void:
				Settings.vsync = i as Settings.VSync
				Settings.apply_window())
	var limits := PackedStringArray()
	for value in Settings.FPS_LIMITS:
		limits.append("Sem limite" if value == 0 else str(value))
	_advanced_rows.fps_limit = _add_row(box, "Limite de FPS", limits,
			Settings.FPS_LIMITS.find(Settings.fps_limit), func(i: int) -> void:
				Settings.fps_limit = Settings.FPS_LIMITS[i]
				Settings.apply_window())
	var scales := PackedStringArray()
	for value in Settings.RENDER_SCALES:
		scales.append("%d%%" % roundi(value * 100.0))
	_advanced_rows.render_scale = _add_row(box, "Escala de renderização", scales,
			Settings.RENDER_SCALES.find(Settings.render_scale), func(i: int) -> void:
				Settings.render_scale = Settings.RENDER_SCALES[i]
				_custom())
	var msaa_names := PackedStringArray()
	for value in Settings.MSAA_LEVELS:
		msaa_names.append("Desligado" if value == 0 else "MSAA %dx" % value)
	_advanced_rows.msaa = _add_row(box, "Antisserrilhamento", msaa_names,
			Settings.MSAA_LEVELS.find(Settings.msaa), func(i: int) -> void:
				Settings.msaa = Settings.MSAA_LEVELS[i]
				_custom())
	_advanced_rows.shadows = _add_row(box, "Sombras", SHADOW_NAMES, Settings.shadows,
			func(i: int) -> void:
				Settings.shadows = i
				_custom())
	_advanced_rows.detail = _add_row(box, "Detalhes do cenário", DETAIL_NAMES, Settings.detail,
			func(i: int) -> void:
				Settings.detail = i
				_custom())

	if Settings.is_desktop():
		var gpus := Settings.gpu_options()
		if gpus.size() > 1:
			var gpu_row := _add_row(box, "Placa de vídeo", gpus, Settings.gpu_index + 1,
					func(_i: int) -> void:
						_gpu_info.text = "Reinicie para aplicar. Em uso: %s" % Settings.current_gpu_text())
			var restart := Button.new()
			restart.text = "Reiniciar com a placa escolhida"
			restart.custom_minimum_size.y = 40
			restart.pressed.connect(func() -> void: Settings.restart_on_gpu(gpu_row.index - 1))
			box.add_child(restart)
	_gpu_info.add_theme_font_size_override("font_size", 18)
	_gpu_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_gpu_info)
	_refresh_rows()


func _custom() -> void:
	Settings.quality = Settings.Quality.CUSTOM
	Settings.apply_graphics()
	_refresh_rows()


func _refresh_rows() -> void:
	if _quality_row:
		_quality_row.set_index(Settings.quality)
	if _resolution_row:
		_resolution_row.disabled = Settings.window_mode != Settings.WindowMode.WINDOWED
	if _advanced_rows.has("render_scale"):
		_advanced_rows.render_scale.set_index(Settings.RENDER_SCALES.find(Settings.render_scale))
		_advanced_rows.msaa.set_index(Settings.MSAA_LEVELS.find(Settings.msaa))
		_advanced_rows.shadows.set_index(Settings.shadows)
		_advanced_rows.detail.set_index(Settings.detail)
	_advanced_button.text = "Avançado  %s" % ("▲" if _advanced_box.visible else "▼")
	var hz := DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())
	_gpu_info.text = "Placa de vídeo em uso: %s\nFrequência da tela: %s" % [
			Settings.current_gpu_text(), "%d Hz" % roundi(hz) if hz > 0.0 else "desconhecida"]
	Settings.save_settings()


# --- Audio --------------------------------------------------------------------

func _build_audio_page(list: VBoxContainer) -> void:
	for entry in [["Volume geral", "master_volume"], ["Música", "music_volume"],
			["Efeitos sonoros", "sfx_volume"]]:
		var row := SliderRow.new().setup(entry[0], Settings.get(entry[1]))
		row.value_changed.connect(func(value: int) -> void:
			Settings.set(entry[1], value)
			Settings.apply_audio()
			Settings.save_settings())
		list.add_child(row)
	_add_row(list, "Som com o jogo em segundo plano", OFF_ON,
			0 if Settings.mute_in_background else 1, func(i: int) -> void:
				Settings.mute_in_background = i == 0
				Settings.save_settings())


# --- Helpers ------------------------------------------------------------------

func _add_row(parent: Control, label: String, options: PackedStringArray, index: int,
		on_change: Callable) -> OptionRow:
	var row := OptionRow.new().setup(label, options, index)
	row.value_changed.connect(func(i: int) -> void:
		on_change.call(i)
		Settings.save_settings())
	parent.add_child(row)
	return row


func _on_reset() -> void:
	Settings.reset_to_defaults()
	var parent := get_parent()
	var replacement := SettingsMenu.new()
	replacement.closed.connect(func() -> void: closed.emit())
	parent.add_child(replacement)
	queue_free()


func _close() -> void:
	Settings.save_settings()
	closed.emit()


func _update_hint() -> void:
	var tabs: String
	match InputGlyphs.kind:
		InputGlyphs.Kind.XBOX:
			tabs = "LB/RB: abas   B: voltar"
		InputGlyphs.Kind.PLAYSTATION:
			tabs = "L1/R1: abas   Círculo: voltar"
		_:
			tabs = "Q/E: abas   Esc: voltar"
	_hint.text = "%s   %s" % [InputGlyphs.menu_hint(), tabs]
