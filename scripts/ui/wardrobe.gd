extends Node3D
## Wardrobe: customize the swan, then race. Fully usable with keyboard or
## controller; mouse and touch are optional.

const RACE_SCENE := "res://scenes/race.tscn"
const STYLE_OPTIONS: PackedStringArray = ["Sólido", "Gradiente"]
const ACCESSORY_LABELS := {
	"cap": "Boné",
	"wig": "Peruca",
	"glasses": "Óculos",
	"lashes": "Cílios",
	"makeup": "Maquiagem",
	"necklace": "Colar",
	"jacket": "Jaqueta",
}
## Footwear options, in order. "" is barefoot.
const FOOTWEAR_OPTIONS := ["", "sneakers", "boots", "shoes", "flip_flops"]
const FOOTWEAR_LABELS: PackedStringArray = ["Descalço", "Tênis", "Botas", "Sapatos", "Chinelo"]
const DEFAULT_FOOTWEAR_COLOR := Color("e8413c")

var _look: SwanLook
var _model := SwanModel.new()
var _nickname_edit := LineEdit.new()
var _color_2_row: OptionRow
var _footwear_color_row: OptionRow
var _footwear_color := DEFAULT_FOOTWEAR_COLOR
var _hint := Label.new()
var _race_button := Button.new()


func _ready() -> void:
	_look = Profile.look
	_build_stage()
	_build_menu()
	_refresh()
	_race_button.grab_focus()


func _process(delta: float) -> void:
	_model.rotation.y += delta * 0.4
	_model.animate(delta, 0.0, 0.0, 0.0, false, true)


func _build_stage() -> void:
	Scenery.add_environment(self)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 2.2
	floor_mesh.bottom_radius = 2.3
	floor_mesh.height = 0.2
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.position = Vector3(1.6, -0.1, 0)
	floor_instance.material_override = Scenery._flat(Scenery.SAND, 1.0)
	add_child(floor_instance)

	_model.position = Vector3(1.6, 0, 0)
	_model.rotation.y = PI - 0.6
	add_child(_model)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.6, 5.2)
	camera.fov = 50.0
	add_child(camera)
	camera.look_at(Vector3(0, 1.3, 0))
	camera.make_current()


func _build_menu() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	layer.add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 24
	panel.offset_top = 24
	panel.offset_bottom = -24
	panel.custom_minimum_size.x = 520
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "Seu cisne"
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)

	# Scrolls to the focused row, so small screens work with a controller.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	_nickname_edit.max_length = SwanLook.NICKNAME_MAX_LENGTH
	_nickname_edit.placeholder_text = "Apelido"
	_nickname_edit.text = _look.nickname
	_nickname_edit.custom_minimum_size.y = 40
	_nickname_edit.text_changed.connect(_on_nickname_changed)
	list.add_child(_nickname_edit)

	var random_button := Button.new()
	random_button.text = "Sortear apelido"
	random_button.custom_minimum_size.y = 40
	random_button.pressed.connect(_on_random_nickname)
	list.add_child(random_button)

	var style_row := OptionRow.new().setup("Penas", STYLE_OPTIONS, _look.feather_style)
	style_row.value_changed.connect(func(i: int) -> void:
		_look.feather_style = i as SwanLook.FeatherStyle
		_refresh())
	list.add_child(style_row)

	var color_row := OptionRow.new().setup(
			"Cor das penas", SwanPalette.names, SwanPalette.closest(_look.feather_color))
	color_row.value_changed.connect(func(i: int) -> void:
		_look.feather_color = SwanPalette.colors[i]
		_refresh())
	list.add_child(color_row)

	_color_2_row = OptionRow.new().setup(
			"Cor de cima", SwanPalette.names, SwanPalette.closest(_look.feather_color_2))
	_color_2_row.value_changed.connect(func(i: int) -> void:
		_look.feather_color_2 = SwanPalette.colors[i]
		_refresh())
	list.add_child(_color_2_row)

	var legs_row := OptionRow.new().setup(
			"Patas", SwanPalette.names, SwanPalette.closest(_look.leg_color))
	legs_row.value_changed.connect(func(i: int) -> void:
		_look.leg_color = SwanPalette.colors[i]
		_refresh())
	list.add_child(legs_row)

	var accessory_options := PackedStringArray(["Nenhum"])
	accessory_options.append_array(SwanPalette.names)
	for id: String in ACCESSORY_LABELS:
		var current := 0
		if _look.is_wearing(id):
			current = SwanPalette.closest(_look.accessories[id]) + 1
		var row := OptionRow.new().setup(ACCESSORY_LABELS[id], accessory_options, current)
		row.value_changed.connect(_on_accessory_changed.bind(id))
		list.add_child(row)

	var footwear := _look.footwear()
	if footwear != "":
		_footwear_color = _look.accessories[footwear]
	var footwear_row := OptionRow.new().setup(
			"Calçado", FOOTWEAR_LABELS, FOOTWEAR_OPTIONS.find(footwear))
	footwear_row.value_changed.connect(func(i: int) -> void:
		_look.set_footwear(FOOTWEAR_OPTIONS[i], _footwear_color)
		_refresh())
	list.add_child(footwear_row)

	_footwear_color_row = OptionRow.new().setup(
			"Cor do calçado", SwanPalette.names, SwanPalette.closest(_footwear_color))
	_footwear_color_row.value_changed.connect(func(i: int) -> void:
		_footwear_color = SwanPalette.colors[i]
		_look.set_footwear(_look.footwear(), _footwear_color)
		_refresh())
	list.add_child(_footwear_color_row)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	_race_button.text = "Correr!"
	_race_button.custom_minimum_size.y = 56
	_race_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_button.add_theme_font_size_override("font_size", 30)
	_race_button.pressed.connect(_on_race)
	buttons.add_child(_race_button)

	var quit_button := Button.new()
	quit_button.text = "Sair"
	quit_button.custom_minimum_size = Vector2(120, 56)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit_button)

	_hint.add_theme_font_size_override("font_size", 18)
	column.add_child(_hint)
	InputGlyphs.changed.connect(_update_hint)
	_update_hint()


func _refresh() -> void:
	_color_2_row.disabled = _look.feather_style != SwanLook.FeatherStyle.GRADIENT
	_footwear_color_row.disabled = _look.footwear() == ""
	_model.apply_look(_look)


func _on_nickname_changed(new_text: String) -> void:
	_look.nickname = new_text.strip_edges() if not new_text.strip_edges().is_empty() else "Cisne"


func _on_random_nickname() -> void:
	_nickname_edit.text = Nicknames.random()
	_on_nickname_changed(_nickname_edit.text)


func _on_accessory_changed(index: int, id: String) -> void:
	if index == 0:
		_look.accessories.erase(id)
	else:
		_look.accessories[id] = SwanPalette.colors[index - 1]
	_refresh()


func _on_race() -> void:
	Profile.look = _look
	Profile.save_profile()
	get_tree().change_scene_to_file(RACE_SCENE)


func _update_hint() -> void:
	_hint.text = InputGlyphs.menu_hint()
