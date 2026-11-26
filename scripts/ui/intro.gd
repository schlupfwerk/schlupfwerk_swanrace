extends Node3D
## Opening, before the home menu:
## 1. The studio: Schlupfwerk logo and "Indie Games" (any button skips it).
## 2. The title: a big egg wobbles and hatches the swan, then "Swan Race" and
##    "Press Start". Start/Enter/A, a click or a tap goes to the home menu
##    (pressed before the egg hatches, it hatches at once).

const HOME_SCENE := "res://scenes/home.tscn"
const LOGO := preload("res://assets/brand/schlupfwerk_logo.svg")
const NAVY := Color("13233a")
const SHELL := Color("f4f1ea")
const YOLK := Color("ffb020")
## Studio logo: fade in, hold, fade out (seconds).
const LOGO_IN := 0.6
const LOGO_HOLD := 1.8
const LOGO_OUT := 0.5
## Title timeline (seconds since the title started).
const WOBBLES: Array[float] = [0.7, 1.3, 1.9]
const HATCH_AT := 2.5
const TITLE_AT := 3.0
const PRESS_AT := 3.6
## The egg: shell radius, and how much taller the top and bottom halves are.
const EGG_RADIUS := 0.8
const TOP_STRETCH := 1.3
const BOTTOM_STRETCH := 0.85

var _studio := Control.new()
var _studio_tween: Tween
var _on_title := false
var _time := 0.0
var _hatched := false
var _leaving := false
var _model := SwanModel.new()
var _egg := Node3D.new()
var _egg_top := Node3D.new()
var _top_velocity := Vector3.ZERO
var _top_spin := Vector3.ZERO
var _camera := Camera3D.new()
var _fade := ColorRect.new()
var _brand := Label.new()
var _title := Label.new()
var _press := Label.new()
var _pop := AudioStreamPlayer.new()
var _honk := AudioStreamPlayer.new()


func _ready() -> void:
	Settings.apply_menu_scale(true)
	_build_stage()
	_build_ui()
	_pop.stream = Sfx.pop()
	_honk.stream = Sfx.honk()
	for player: AudioStreamPlayer in [_pop, _honk]:
		player.bus = &"SFX"
		add_child(player)
	_play_studio()


func _process(delta: float) -> void:
	if not _on_title:
		return
	_time += delta
	_model.animate(delta, 0.0, 0.0, 0.0, 0.0, true)
	_fade.color.a = clampf(1.0 - _time / 0.6, 0.0, 1.0)
	if not _hatched:
		# Three wobbles, each one stronger.
		var wobble := 0.0
		for n in WOBBLES.size():
			var since := _time - WOBBLES[n]
			if since > 0.0 and since < 0.35:
				wobble = sin(since * 40.0) * (0.06 + 0.04 * n) * (1.0 - since / 0.35)
		_egg.rotation.z = wobble
		if _time >= HATCH_AT:
			_hatch()
	else:
		# The top of the shell flies off, spinning, and falls behind the egg.
		_top_velocity.y -= 9.8 * delta
		_egg_top.position += _top_velocity * delta
		_egg_top.rotation += _top_spin * delta
		_egg_top.visible = _egg_top.position.y > -1.0
	if _time >= TITLE_AT and not _title.visible:
		_show_title()
	if _time >= PRESS_AT:
		_press.visible = true
		_press.modulate.a = 0.55 + 0.45 * sin((_time - PRESS_AT) * 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or event.is_action("toggle_sound"):
		return
	var tapped: bool = (event is InputEventMouseButton or event is InputEventScreenTouch) \
			and event.pressed
	var any_button: bool = tapped or (event.is_pressed() and not event.is_echo()
			and (event is InputEventKey or event is InputEventJoypadButton))
	if not _on_title:
		if any_button:
			get_viewport().set_input_as_handled()
			_show_title_stage()
		return
	var start: bool = tapped or event.is_action_pressed("start_race") \
			or event.is_action_pressed("ui_accept")
	if not start:
		return
	get_viewport().set_input_as_handled()
	if _time < PRESS_AT:
		# Impatient: hatch now and show everything.
		_time = maxf(_time, PRESS_AT)
		if not _hatched:
			_hatch()
		_show_title()
	else:
		_go_home()


# --- Studio logo ----------------------------------------------------------------

func _play_studio() -> void:
	_studio.modulate.a = 0.0
	_studio_tween = create_tween()
	_studio_tween.tween_property(_studio, "modulate:a", 1.0, LOGO_IN)
	_studio_tween.tween_interval(LOGO_HOLD)
	_studio_tween.tween_property(_studio, "modulate:a", 0.0, LOGO_OUT)
	_studio_tween.tween_callback(_show_title_stage)


func _show_title_stage() -> void:
	if _on_title:
		return
	if _studio_tween:
		_studio_tween.kill()
	_studio.visible = false
	_on_title = true
	_camera.make_current()


# --- Title ------------------------------------------------------------------------

func _hatch() -> void:
	_hatched = true
	_egg.rotation.z = 0.0
	_top_velocity = Vector3(1.2, 4.5, -0.6)
	_top_spin = Vector3(2.0, 1.0, -5.0)
	_pop.play()
	# The swan springs out of the bottom half, with a little overshoot.
	_model.visible = true
	_model.scale = Vector3.ONE * 0.3
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE, 0.55) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_model, "position:y", 0.35, 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_model.honk()
		_honk.play())


func _show_title() -> void:
	if _title.visible:
		return
	for label: Label in [_brand, _title]:
		label.visible = true
		label.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 0.4)
	var drop := create_tween()
	_title.pivot_offset = _title.size / 2.0
	_title.scale = Vector2.ONE * 1.4
	drop.tween_property(_title, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _go_home() -> void:
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(HOME_SCENE))


# --- Building ---------------------------------------------------------------------

func _build_stage() -> void:
	Scenery.add_environment(self)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 3.0
	floor_mesh.bottom_radius = 3.1
	floor_mesh.height = 0.2
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.position.y = -0.1
	floor_instance.material_override = Scenery.flat(Scenery.SAND, 1.0)
	add_child(floor_instance)

	# The swan, facing the camera, hidden in the egg until it hatches.
	_model.apply_look(SwanLook.new())
	_model.rotation.y = PI
	_model.position.y = -0.3
	_model.visible = false
	add_child(_model)

	# The egg: a bottom half that stays and a top half that pops off. Both are
	# half spheres stretched up, with a zigzag rim where they break.
	var shell := StandardMaterial3D.new()
	shell.albedo_color = SHELL
	shell.roughness = 0.6
	shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The egg's pivot is on the ground, so it wobbles like a real egg.
	add_child(_egg)
	var bottom := _half_shell(shell, false)
	bottom.position.y = EGG_RADIUS * BOTTOM_STRETCH
	_egg.add_child(bottom)
	_egg_top.position.y = EGG_RADIUS * BOTTOM_STRETCH
	_egg.add_child(_egg_top)
	_egg_top.add_child(_half_shell(shell, true))
	# Yolk-colored spots, like the pixel egg of the logo.
	var spot := StandardMaterial3D.new()
	spot.albedo_color = YOLK
	for n in 5:
		var a := n * TAU / 5.0 + 0.3
		var dot := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.09
		mesh.height = 0.06
		dot.mesh = mesh
		dot.material_override = spot
		# On the shell surface, the flat side facing out.
		var lat := 0.3 + 0.15 * (n % 2)
		var out := Vector3(sin(a) * cos(lat), sin(lat), cos(a) * cos(lat))
		dot.position = Vector3(out.x, out.y * TOP_STRETCH, out.z) * EGG_RADIUS
		var normal := Vector3(out.x, out.y / TOP_STRETCH, out.z).normalized()
		dot.basis = Basis.looking_at(normal) * Basis(Vector3.RIGHT, PI / 2.0)
		_egg_top.add_child(dot)

	_camera.position = Vector3(0, 2.0, 7.0)
	_camera.fov = 50.0
	add_child(_camera)
	_camera.look_at_from_position(_camera.position, Vector3(0, 2.05, 0), Vector3.UP)


## Half an egg shell (top or bottom) with a zigzag rim. Both halves share the
## same zigzag, so the closed egg has no gap.
func _half_shell(mat: Material, top: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 36
	var rings := 12
	var grid := []
	for j in rings + 1:
		var t := float(j) / rings
		var row := []
		for k in columns + 1:
			var a := TAU * k / columns
			# Zigzag along the break: every other column a little up or down.
			var tooth := 0.12 if k % 2 == 0 else -0.06
			var lat := lerpf(tooth, PI / 2.0 if top else -PI / 2.0, t)
			# Pointier on top, rounder at the bottom, like a real egg.
			var y := sin(lat) * (TOP_STRETCH if sin(lat) > 0.0 else BOTTOM_STRETCH)
			var r := cos(lat)
			row.append(Vector3(sin(a) * r, y, cos(a) * r) * EGG_RADIUS)
		grid.append(row)
	for j in rings:
		for k in columns:
			for corner: Array in [[j, k], [j + 1, k], [j + 1, k + 1], [j, k], [j + 1, k + 1], [j, k + 1]]:
				st.add_vertex(grid[corner[0]][corner[1]])
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = mat
	return instance


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	layer.add_child(root)

	# Title texts over the 3D egg.
	_brand.text = "SCHLUPFWERK"
	_brand.add_theme_font_size_override("font_size", 30)
	_brand.add_theme_color_override("font_color", YOLK)
	_title.text = tr("GAME_TITLE")
	_title.add_theme_font_size_override("font_size", 92)
	_press.add_theme_font_size_override("font_size", 30)
	for label: Label in [_brand, _title, _press]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_constant_override("outline_size", 12)
		label.add_theme_color_override("font_outline_color", NAVY)
		label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		label.visible = false
		root.add_child(label)
	_brand.offset_top = 36
	_title.offset_top = 66
	_press.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_press.offset_top = -90
	_press.offset_bottom = -40
	_update_press_text()
	InputGlyphs.changed.connect(_update_press_text)

	# Fade from (and back to) navy.
	_fade.color = NAVY
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The studio card, on top of everything.
	var card := ColorRect.new()
	card.color = NAVY
	_studio.set_anchors_preset(Control.PRESET_FULL_RECT)
	_studio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_studio)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_studio.add_child(card)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_studio.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	center.add_child(column)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(690, 130)
	column.add_child(logo)
	var tagline := Label.new()
	tagline.text = "I N D I E   G A M E S"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 30)
	tagline.add_theme_color_override("font_color", YOLK)
	tagline.add_theme_constant_override("outline_size", 0)
	column.add_child(tagline)


func _update_press_text() -> void:
	_press.text = tr("PRESS_START_" + InputGlyphs._suffix())
