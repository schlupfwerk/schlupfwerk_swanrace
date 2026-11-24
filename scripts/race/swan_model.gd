class_name SwanModel
extends Node3D
## Cartoon swan with a bit of ostrich, built from a few smooth primitives.
## Origin on the ground between the feet, facing -Z.
## Visual only: nothing here affects movement or collisions.

## A foot touched the ground while running. `strength` is 0..1 (speed),
## `foot` is -1 (left) or 1 (right).
signal stepped(strength: float, foot: int)

const FEATHER_SHADER := preload("res://shaders/feather.gdshader")
const LENS_SHADER := preload("res://shaders/lens.gdshader")

const BODY_HEIGHT := 1.15
const WING_OPEN_ANGLE := 1.35
const BEAK_COLOR := Color("ff9a1f")
## Thin black outline around the whole swan (inverted hull, drawn as a second
## pass of every opaque material).
const OUTLINE_WIDTH := 0.011
## Outfits whose sleeves cover the wings.
const SLEEVED := ["jacket", "winter_jacket", "hoodie"]
const DARK := Color("151518")
const WOOD := Color("8a6440")

static var _outline: StandardMaterial3D

## True while wading in the sea: splashes at the feet.
var wet := false
## 0..1 while drowning: flailing wings, head up, bubbles.
var drowning := 0.0

var _feather_mat := ShaderMaterial.new()
var _leg_mat := _toon(Color("2b2b30"))
var _lens_mat := ShaderMaterial.new()
var _body_pivot := Node3D.new()
var _neck := Node3D.new()
var _head := Node3D.new()
var _wing_l := Node3D.new()
var _wing_r := Node3D.new()
var _wing_meshes: Array[MeshInstance3D] = []
var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _bare_feet: Array[MeshInstance3D] = []
var _meshes: Array[MeshInstance3D] = []
## Item id -> meshes that show it.
var _item_meshes := {}
## Item id -> material that takes the chosen color.
var _item_mats := {}
var _smoke: CPUParticles3D
var _wind: Array[CPUParticles3D] = []
var _land_dust: CPUParticles3D
var _splash: CPUParticles3D
var _bubbles: CPUParticles3D
var _phase := 0.0
var _wing_open := 0.0
## Landing squash and take-off stretch, 1 right after the event, fading to 0.
var _squash := 0.0
var _stretch := 0.0
## Dazed after bumping into something: 1 right after the bump, fading to 0.
var _daze := 0.0
var _daze_stars := Node3D.new()
var _cape := Node3D.new()
## Everything on the back hangs from here and swings with the stride.
var _back := Node3D.new()


func _init() -> void:
	_feather_mat.shader = FEATHER_SHADER
	_lens_mat.shader = LENS_SHADER
	_build_body()
	_build_head()
	_build_wings()
	_build_legs()
	_build_head_items()
	_build_glasses()
	_build_face_items()
	_build_outfits()
	_build_footwear()
	_build_back_items()
	_build_effects()
	apply_look(SwanLook.new())


func apply_look(look: SwanLook) -> void:
	_feather_mat.set_shader_parameter("color_bottom", look.feather_color)
	_feather_mat.set_shader_parameter("color_top", look.feather_color_2)
	_feather_mat.set_shader_parameter(
			"use_gradient", look.feather_style == SwanLook.FeatherStyle.GRADIENT)
	_leg_mat.albedo_color = look.leg_color
	for id: String in _item_meshes:
		if id.begins_with("glasses_"):
			continue
		var worn := look.is_wearing(id)
		for mesh: MeshInstance3D in _item_meshes[id]:
			mesh.visible = worn
		if worn:
			(_item_mats[id] as StandardMaterial3D).albedo_color = look.accessories[id]
	# Glasses: shape, frame color and lens (solid or gradient).
	for style: String in SwanLook.GLASSES_STYLES:
		for mesh: MeshInstance3D in _item_meshes["glasses_" + style]:
			mesh.visible = look.glasses_style == style
	(_item_mats["glasses"] as StandardMaterial3D).albedo_color = look.glasses_frame
	_lens_mat.set_shader_parameter("color_top", look.glasses_lens)
	_lens_mat.set_shader_parameter("color_bottom",
			look.glasses_lens_2 if look.glasses_lens_gradient else look.glasses_lens)
	# Closed footwear hides the bare feet; the Japanese sandals show them.
	var footwear := look.footwear()
	var socks := look.is_wearing("socks")
	for foot in _bare_feet:
		foot.visible = (footwear == "" or footwear == "flip_flops") and not socks
	# Jackets and the hoodie turn the wings into sleeves.
	var outfit := look.slot_item("outfit")
	# Roomy clothes: move the wings out so they sit on top of the fabric.
	var wing_x := 0.47 if outfit == "" else 0.56
	_wing_l.position.x = -wing_x
	_wing_r.position.x = wing_x
	for wing in _wing_meshes:
		wing.material_override = _item_mats[outfit] if outfit in SLEEVED else _feather_mat


## 0 = invisible, 1 = solid. Used to blink back in after drowning.
func set_fade(alpha: float) -> void:
	for mesh in _meshes:
		mesh.transparency = 1.0 - clampf(alpha, 0.0, 1.0)


## Called every frame with the swan's current state.
func animate(delta: float, speed_ratio: float, steer: float, accel: float,
		braking: bool, on_ground: bool) -> void:
	var moving := clampf(speed_ratio * 2.0, 0.0, 1.0)
	var smooth := 1.0 - exp(-10.0 * delta)
	var legs := 1.0 - exp(-25.0 * delta)
	if on_ground:
		var previous_phase := _phase
		# Long, bouncy strides: few steps per second, big swing.
		_phase += (3.2 + 5.5 * speed_ratio) * delta * moving
		# One step every half stride, alternating feet.
		if moving > 0.1 and floori(_phase / PI) != floori(previous_phase / PI):
			stepped.emit(moving, -1 if floori(_phase / PI) % 2 == 0 else 1)
		for side in 2:
			var phase := _phase + PI * side
			var swing := sin(phase) * 1.1 * moving
			# The knee folds while the leg swings forward, and a little at rest.
			var fold := 0.12 + maxf(cos(phase), 0.0) * 1.1 * moving
			_hips[side].rotation.x = lerpf(_hips[side].rotation.x, swing + fold * 0.35, legs)
			_knees[side].rotation.x = lerpf(_knees[side].rotation.x, -fold, legs)
		# Gangly: knees flick out a little on every stride.
		_hips[0].rotation.z = -0.07 - maxf(sin(_phase), 0.0) * 0.12 * moving
		_hips[1].rotation.z = 0.07 + maxf(-sin(_phase), 0.0) * 0.12 * moving
		var bob := absf(sin(_phase)) * 0.12 * moving
		var breathe := sin(Time.get_ticks_msec() * 0.003) * 0.015 * (1.0 - moving)
		_body_pivot.position.y = BODY_HEIGHT + bob + breathe - 0.05 * moving
	else:
		# Tuck the legs back while in the air.
		for side in 2:
			_hips[side].rotation.x = lerpf(_hips[side].rotation.x, -0.5 - 0.2 * side, legs)
			_knees[side].rotation.x = lerpf(_knees[side].rotation.x, -1.3, legs)
		_body_pivot.position.y = lerpf(_body_pivot.position.y, BODY_HEIGHT, smooth)

	# Clumsy waddle: the body rolls and twists with each stride.
	var lean := -0.25 * accel * moving + (0.15 if braking else 0.0)
	_body_pivot.rotation.x = lerpf(_body_pivot.rotation.x, lean, 1.0 - exp(-8.0 * delta))
	_body_pivot.rotation.z = sin(_phase) * 0.13 * moving
	_body_pivot.rotation.y = sin(_phase + 0.6) * 0.09 * moving
	rotation.z = lerpf(rotation.z, -steer * 0.16 * moving, 1.0 - exp(-8.0 * delta))

	# The faster it runs, the lower the head goes, bobbing forward and back.
	var neck_lean := -0.8 * speed_ratio - 0.1 * accel + sin(_phase * 2.0 + 0.8) * 0.14 * moving
	neck_lean = lerpf(neck_lean, 0.45, drowning)
	_neck.rotation.x = lerpf(_neck.rotation.x, neck_lean, smooth)
	# Shake the head when dazed.
	_daze = move_toward(_daze, 0.0, delta / Swan.STUN_TIME)
	_neck.rotation.y = sin(Time.get_ticks_msec() * 0.03) * 0.55 * _daze
	_neck.rotation.z = sin(Time.get_ticks_msec() * 0.021) * 0.25 * _daze
	_head.rotation.x = -(_neck.rotation.x + _body_pivot.rotation.x) * 0.75 + 0.5 * drowning
	_daze_stars.visible = _daze > 0.05
	_daze_stars.rotation.y += delta * 6.0

	# Braking opens the wings; running sweeps them back, flapping a little.
	# Drowning: frantic flapping.
	_wing_open = move_toward(_wing_open, 1.0 if braking else 0.0, delta * 7.0)
	var run_open := (0.45 + sin(_phase * 2.0) * 0.12) * speed_ratio
	var flail := (0.9 + sin(Time.get_ticks_msec() * 0.03) * 0.6) * drowning
	var open := maxf(maxf(ease(_wing_open, -2.0) * WING_OPEN_ANGLE, run_open), flail)
	var sweep := 0.45 * speed_ratio * (1.0 - _wing_open) * (1.0 - drowning)
	_wing_l.rotation = Vector3(0.0, -sweep, -open)
	_wing_r.rotation = Vector3(0.0, sweep, open)

	# Things on the back swing and bounce with each stride.
	_back.rotation.z = sin(_phase + 0.9) * 0.16 * moving
	_back.rotation.x = absf(sin(_phase + 0.5)) * 0.12 * moving - 0.04 * moving
	_back.position.y = 0.45 + absf(cos(_phase)) * 0.04 * moving
	# The cape flies out behind as the swan speeds up.
	var cape_lift := 0.12 + 1.0 * speed_ratio + sin(Time.get_ticks_msec() * 0.012) * 0.08 * speed_ratio
	_cape.rotation.x = lerpf(_cape.rotation.x, cape_lift, smooth)

	_splash.emitting = (wet and moving > 0.15) or drowning > 0.1
	_bubbles.emitting = drowning > 0.3
	_smoke.emitting = on_ground and not wet and accel > 0.2 and speed_ratio > 0.05
	for wind in _wind:
		wind.emitting = braking and _wing_open > 0.6
	# Squash on landing, stretch on take-off.
	_squash = move_toward(_squash, 0.0, delta * 4.0)
	_stretch = move_toward(_stretch, 0.0, delta * 3.0)
	var squash := _squash * _squash
	var stretch := sin(_stretch * PI)
	_body_pivot.scale = Vector3(1.0 + 0.16 * squash - 0.06 * stretch,
			1.0 - 0.24 * squash + 0.12 * stretch, 1.0 + 0.16 * squash - 0.06 * stretch)
	_body_pivot.position.y -= 0.14 * squash
	_feather_mat.set_shader_parameter("root_y", global_position.y)


## Called when the swan touches the ground after a jump.
func land(strength: float) -> void:
	_squash = clampf(strength, 0.4, 1.0)
	_land_dust.amount = 10 + int(14 * _squash)
	_land_dust.restart()


## Called when the swan jumps.
func take_off() -> void:
	_stretch = 1.0


## Called when the swan bumps into something: head shake and little stars.
func daze() -> void:
	_daze = 1.0


# --- Body -----------------------------------------------------------------

func _build_body() -> void:
	_body_pivot.position.y = BODY_HEIGHT
	add_child(_body_pivot)
	_sphere(_body_pivot, 0.5, Vector3(1.0, 0.85, 1.3), Vector3.ZERO, _feather_mat)
	# Tail: a fluffy tuft and two layers of long plumes fanning up and back.
	_sphere(_body_pivot, 0.2, Vector3(1.3, 0.8, 1.3), Vector3(0, 0.2, 0.6), _feather_mat,
			Vector3(0.7, 0, 0))
	for k in 9:
		var fan := (k - 4) * 0.2
		_sphere(_body_pivot, 0.5, Vector3(0.13, 0.05, 0.62), Vector3(fan * 0.35, 0.34, 0.78),
				_feather_mat, Vector3(0.75 - absf(fan) * 0.25, fan, fan * 0.3), 10, 5)
	for k in 7:
		var fan := (k - 3) * 0.26
		_sphere(_body_pivot, 0.5, Vector3(0.11, 0.045, 0.48), Vector3(fan * 0.3, 0.16, 0.74),
				_feather_mat, Vector3(0.35 - absf(fan) * 0.15, fan, fan * 0.3), 10, 5)
	# S-shaped neck on its own pivot, so the head can lower when running.
	_neck.position = Vector3(0, 0.3, -0.42)
	_body_pivot.add_child(_neck)
	_capsule(_neck, 0.15, 0.7, Vector3(0, 0.15, -0.08), _feather_mat, Vector3(-0.35, 0, 0))
	_capsule(_neck, 0.12, 0.65, Vector3(0, 0.6, -0.22), _feather_mat, Vector3(0.12, 0, 0))


func _build_head() -> void:
	_head.position = Vector3(0, 0.94, -0.2)
	_neck.add_child(_head)
	_sphere(_head, 0.21, Vector3(0.95, 0.95, 1.1), Vector3.ZERO, _feather_mat)
	_add(_head, _cylinder(0.085, 0.015, 0.3, 12), Vector3(0, -0.04, -0.3), Vector3.ONE,
			_toon(BEAK_COLOR), Vector3(-PI / 2, 0, 0))
	var white := _toon(Color.WHITE)
	var black := _toon(DARK)
	for side in [-1.0, 1.0]:
		_sphere(_head, 0.065, Vector3.ONE, Vector3(0.12 * side, 0.06, -0.12), white)
		_sphere(_head, 0.035, Vector3.ONE, Vector3(0.145 * side, 0.07, -0.165), black)
	# Little stars that spin around the head when dazed.
	_daze_stars.position = Vector3(0, 0.38, 0)
	_daze_stars.visible = false
	_head.add_child(_daze_stars)
	var star_mat := _toon(Color("ffd23f"))
	star_mat.emission_enabled = true
	star_mat.emission = Color("ffd23f")
	star_mat.emission_energy_multiplier = 0.6
	for k in 3:
		var a := TAU * k / 3.0
		_sphere(_daze_stars, 0.06, Vector3.ONE, Vector3(cos(a) * 0.3, 0.0, sin(a) * 0.3), star_mat,
				Vector3.ZERO, 6, 4)


func _build_wings() -> void:
	for side in [-1.0, 1.0]:
		var pivot := _wing_l if side < 0 else _wing_r
		pivot.position = Vector3(0.47 * side, 0.18, 0.02)
		_body_pivot.add_child(pivot)
		var wing := _sphere(pivot, 0.5, Vector3(0.14, 0.55, 0.95), Vector3(0.03 * side, -0.24, 0.08),
				_feather_mat)
		_wing_meshes.append(wing)
		# Long flight feathers fanning out from the back of the wing.
		for k in 4:
			_sphere(pivot, 0.5, Vector3(0.05, 0.13, 0.5),
					Vector3(0.04 * side, -0.38 + 0.09 * k, 0.55 + 0.03 * k), _feather_mat,
					Vector3(0.25 + 0.12 * k, 0, 0), 10, 5)


## Legs with a knee: hip pivot -> thigh -> knee pivot -> shin -> foot.
## Relative to the knee, the ground is at y = -0.43.
func _build_legs() -> void:
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.3 * side, 0.85, 0.05)
		add_child(hip)
		_hips.append(hip)
		# Fluffy thigh, like an ostrich.
		_sphere(hip, 0.13, Vector3(1.0, 1.3, 1.0), Vector3(0, 0.02, 0), _feather_mat)
		_capsule(hip, 0.05, 0.47, Vector3(0, -0.2, 0), _leg_mat)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.42, 0)
		hip.add_child(knee)
		_knees.append(knee)
		_sphere(knee, 0.055, Vector3.ONE, Vector3.ZERO, _leg_mat, Vector3.ZERO, 8, 5)
		_capsule(knee, 0.045, 0.46, Vector3(0, -0.2, 0), _leg_mat)
		# Two toes, like an ostrich: a big inner toe and a small outer one.
		var toe_big := _sphere(knee, 0.5, Vector3(0.09, 0.05, 0.26),
				Vector3(-0.03 * side, -0.405, -0.12), _leg_mat, Vector3(0, 0.12 * side, 0), 10, 5)
		var toe_small := _sphere(knee, 0.5, Vector3(0.065, 0.04, 0.17),
				Vector3(0.06 * side, -0.41, -0.08), _leg_mat, Vector3(0, -0.3 * side, 0), 10, 5)
		var heel := _sphere(knee, 0.05, Vector3(1.0, 0.7, 1.0), Vector3(0, -0.4, 0.02), _leg_mat,
				Vector3.ZERO, 8, 4)
		_bare_feet.append_array([toe_big, toe_small, heel])


# --- Things to wear -----------------------------------------------------------

func _item(id: String) -> StandardMaterial3D:
	if not _item_mats.has(id):
		_item_mats[id] = _toon(Color.WHITE)
		_item_meshes[id] = []
		_add_outline(_item_mats[id])
	return _item_mats[id]


func _wear(id: String, mesh: MeshInstance3D) -> MeshInstance3D:
	if not _item_meshes.has(id):
		_item_meshes[id] = []
	mesh.visible = false
	_item_meshes[id].append(mesh)
	return mesh


func _build_head_items() -> void:
	var band := _toon(Color("3a2a22"))
	# Cap.
	var cap := _item("cap")
	_wear("cap", _add(_head, _dome(0.225), Vector3(0, 0.06, 0.02), Vector3(1, 1, 1.05), cap))
	_wear("cap", _add(_head, _cylinder(0.17, 0.17, 0.025, 16), Vector3(0, 0.07, -0.19),
			Vector3(1, 1, 1.25), cap))
	_wear("cap", _sphere(_head, 0.03, Vector3.ONE, Vector3(0, 0.29, 0.02), cap))
	# Straw hat: wide brim, low crown, ribbon.
	var straw := _item("straw_hat")
	_wear("straw_hat", _add(_head, _cylinder(0.44, 0.44, 0.03, 24), Vector3(0, 0.13, 0),
			Vector3.ONE, straw))
	_wear("straw_hat", _add(_head, _cylinder(0.2, 0.17, 0.17, 18), Vector3(0, 0.22, 0),
			Vector3.ONE, straw))
	_wear("straw_hat", _add(_head, _cylinder(0.205, 0.2, 0.05, 18), Vector3(0, 0.17, 0),
			Vector3.ONE, _toon(Color("c0392b"))))
	# Top hat: tall crown and a band.
	var top := _item("top_hat")
	_wear("top_hat", _add(_head, _cylinder(0.3, 0.3, 0.03, 20), Vector3(0, 0.15, 0),
			Vector3.ONE, top))
	_wear("top_hat", _add(_head, _cylinder(0.17, 0.18, 0.4, 18), Vector3(0, 0.36, 0),
			Vector3.ONE, top))
	_wear("top_hat", _add(_head, _cylinder(0.185, 0.185, 0.06, 18), Vector3(0, 0.2, 0),
			Vector3.ONE, band))
	# Cowboy hat: curled brim and a rounded crown.
	var cowboy := _item("cowboy_hat")
	_wear("cowboy_hat", _add(_head, _cylinder(0.36, 0.36, 0.025, 20), Vector3(0, 0.13, 0),
			Vector3(1, 1, 0.85), cowboy))
	var curl := TorusMesh.new()
	curl.inner_radius = 0.3
	curl.outer_radius = 0.4
	curl.rings = 20
	curl.ring_segments = 6
	_wear("cowboy_hat", _add(_head, curl, Vector3(0, 0.16, 0), Vector3(1.05, 0.5, 0.9), cowboy))
	_wear("cowboy_hat", _sphere(_head, 0.2, Vector3(1.0, 0.85, 1.15), Vector3(0, 0.24, 0), cowboy))
	_wear("cowboy_hat", _add(_head, _cylinder(0.2, 0.2, 0.045, 18), Vector3(0, 0.17, 0),
			Vector3(1, 1, 1.12), band))
	# Beanie with a pompom.
	var beanie := _item("beanie")
	_wear("beanie", _add(_head, _dome(0.235), Vector3(0, 0.02, 0.01), Vector3(1, 1.1, 1.08), beanie))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.19
	rim.outer_radius = 0.255
	rim.rings = 20
	rim.ring_segments = 8
	_wear("beanie", _add(_head, rim, Vector3(0, 0.04, 0.01), Vector3(1, 0.8, 1.08), beanie))
	_wear("beanie", _sphere(_head, 0.075, Vector3.ONE, Vector3(0, 0.3, 0.01), _toon(Color("f4f4f4"))))
	# Curly wig.
	var wig := _item("wig")
	for p in [Vector3(0, 0.18, 0.02), Vector3(-0.12, 0.13, 0.05), Vector3(0.12, 0.13, 0.05),
			Vector3(0, 0.13, 0.15), Vector3(-0.11, 0.04, 0.14), Vector3(0.11, 0.04, 0.14),
			Vector3(0, 0.02, 0.2), Vector3(-0.06, 0.2, -0.08), Vector3(0.06, 0.2, -0.08)]:
		_wear("wig", _sphere(_head, 0.1, Vector3.ONE, p, wig, Vector3.ZERO, 10, 6))
	# Long straight wig: a cap of hair, bangs and long locks down the back.
	var long_wig := _item("wig_long")
	_wear("wig_long", _add(_head, _dome(0.235), Vector3(0, 0.0, 0.02), Vector3(1.05, 1.05, 1.1),
			long_wig))
	_wear("wig_long", _sphere(_head, 0.12, Vector3(1.4, 0.45, 0.8), Vector3(0, 0.15, -0.14), long_wig))
	for k in 5:
		var x := (k - 2) * 0.07
		_wear("wig_long", _capsule(_head, 0.055, 0.55, Vector3(x, -0.16, 0.16 + absf(x) * 0.2),
				long_wig, Vector3(0.18, 0, x * 0.6)))


func _build_glasses() -> void:
	var frame := _item("glasses")
	for style: String in SwanLook.GLASSES_STYLES:
		_item_meshes["glasses_" + style] = []
	var arms := []
	for side in [-1.0, 1.0]:
		# Round.
		_wear("glasses_round", _add(_head, _torus(0.06, 0.078), Vector3(0.1 * side, 0.06, -0.205),
				Vector3.ONE, frame, Vector3(PI / 2, 0, 0)))
		_wear("glasses_round", _add(_head, _cylinder(0.062, 0.062, 0.006, 16),
				Vector3(0.1 * side, 0.06, -0.205), Vector3.ONE, _lens_mat, Vector3(PI / 2, 0, 0)))
		# Square: four thin bars and a flat lens.
		for bar in [[Vector3(0, 0.06, 0), Vector3(0.16, 0.018, 0.02)],
				[Vector3(0, -0.06, 0), Vector3(0.16, 0.018, 0.02)],
				[Vector3(-0.07, 0, 0), Vector3(0.018, 0.13, 0.02)],
				[Vector3(0.07, 0, 0), Vector3(0.018, 0.13, 0.02)]]:
			_wear("glasses_square", _add(_head, _box(bar[1]),
					Vector3(0.1 * side, 0.06, -0.205) + bar[0], Vector3.ONE, frame))
		_wear("glasses_square", _add(_head, _box(Vector3(0.13, 0.11, 0.006)),
				Vector3(0.1 * side, 0.06, -0.205), Vector3.ONE, _lens_mat))
		# Aviator: teardrop lenses, tilted in.
		_wear("glasses_aviator", _add(_head, _torus(0.062, 0.076), Vector3(0.1 * side, 0.045, -0.205),
				Vector3(1.1, 1.0, 1.3), frame, Vector3(PI / 2, 0, 0.25 * side)))
		_wear("glasses_aviator", _add(_head, _cylinder(0.064, 0.064, 0.006, 16),
				Vector3(0.1 * side, 0.045, -0.205), Vector3(1.1, 1.0, 1.3), _lens_mat,
				Vector3(PI / 2, 0, 0.25 * side)))
		arms.append(side)
	# Visor: one wide lens across both eyes.
	_wear("glasses_visor", _add(_head, _box(Vector3(0.44, 0.11, 0.012)), Vector3(0, 0.06, -0.215),
			Vector3.ONE, _lens_mat))
	_wear("glasses_visor", _add(_head, _box(Vector3(0.46, 0.022, 0.03)), Vector3(0, 0.12, -0.215),
			Vector3.ONE, frame))
	# Bridge and arms, shared by every shape.
	for style: String in SwanLook.GLASSES_STYLES:
		var id := "glasses_" + style
		if style != "visor":
			_wear(id, _add(_head, _box(Vector3(0.05, 0.015, 0.015)), Vector3(0, 0.07, -0.215),
					Vector3.ONE, frame))
		for side: float in arms:
			_wear(id, _add(_head, _box(Vector3(0.015, 0.015, 0.2)), Vector3(0.2 * side, 0.07, -0.11),
					Vector3.ONE, frame))


func _build_face_items() -> void:
	# Makeup: blush and eye shadow.
	var makeup := _item("makeup")
	for side in [-1.0, 1.0]:
		_wear("makeup", _sphere(_head, 0.055, Vector3(0.35, 0.8, 1.0),
				Vector3(0.185 * side, -0.05, -0.08), makeup))
		_wear("makeup", _sphere(_head, 0.07, Vector3(1.0, 0.6, 1.0),
				Vector3(0.115 * side, 0.1, -0.1), makeup))
	# Lashes: three long curved lashes over each eye.
	var lashes := _item("lashes")
	for side in [-1.0, 1.0]:
		for i in 3:
			_wear("lashes", _add(_head, _box(Vector3(0.014, 0.075, 0.014)),
					Vector3((0.125 + 0.022 * i) * side, 0.14, -0.13 - 0.014 * i), Vector3.ONE,
					lashes, Vector3(0.3, 0, -0.45 * side * (i + 1) / 3.0)))
	# Necklace: high on the neck, a chain that drops in a V to a pendant.
	var necklace := _item("necklace")
	necklace.metallic = 0.6
	_wear("necklace", _add(_neck, _torus(0.148, 0.168), Vector3(0, 0.36, -0.1), Vector3.ONE,
			necklace, Vector3(-0.5, 0, 0)))
	for side in [-1.0, 1.0]:
		_wear("necklace", _capsule(_neck, 0.012, 0.2, Vector3(0.06 * side, 0.27, -0.29), necklace,
				Vector3(0.35, 0, 0.75 * side)))
	_wear("necklace", _sphere(_neck, 0.045, Vector3(1, 1.2, 0.5), Vector3(0, 0.19, -0.33),
			necklace, Vector3(-0.3, 0, 0)))


func _build_outfits() -> void:
	# Leather jacket: roomy shell with lapels, collar and zipper. Sleeves on the wings.
	var leather := _item("jacket")
	leather.roughness = 0.35
	_wear("jacket", _sphere(_body_pivot, 0.5, Vector3(1.24, 1.06, 1.34), Vector3(0, -0.02, -0.06),
			leather))
	_wear("jacket", _add(_body_pivot, _torus(0.5, 0.62), Vector3(0, -0.34, -0.05),
			Vector3(1.05, 0.6, 1.25), leather))
	for side in [-1.0, 1.0]:
		_wear("jacket", _add(_body_pivot, _box(Vector3(0.16, 0.32, 0.03)),
				Vector3(0.12 * side, 0.22, -0.7), Vector3.ONE, leather,
				Vector3(-0.5, 0.35 * side, 0.35 * side)))
	_wear("jacket", _add(_body_pivot, _torus(0.12, 0.22), Vector3(0, 0.42, -0.47), Vector3.ONE,
			leather, Vector3(-0.35, 0, 0)))
	_wear("jacket", _add(_body_pivot, _box(Vector3(0.03, 0.5, 0.03)), Vector3(0, -0.02, -0.77),
			Vector3.ONE, _toon(Color("b8b8c0")), Vector3(-0.45, 0, 0)))

	# Winter jacket: puffy quilted rings and a thick collar.
	var winter := _item("winter_jacket")
	_wear("winter_jacket", _sphere(_body_pivot, 0.5, Vector3(1.22, 1.06, 1.32), Vector3(0, -0.01, -0.05),
			winter))
	var rings := [[-0.3, 0.6, 0.74], [-0.1, 0.64, 0.78], [0.1, 0.6, 0.74], [0.28, 0.5, 0.62]]
	for ring: Array in rings:
		_wear("winter_jacket", _add(_body_pivot, _torus(ring[1] * 0.62, ring[2]),
				Vector3(0, ring[0], -0.06), Vector3(1.0, 0.7, 1.22), winter))
	_wear("winter_jacket", _add(_body_pivot, _torus(0.13, 0.29), Vector3(0, 0.42, -0.45),
			Vector3(1, 1.4, 1), winter, Vector3(-0.35, 0, 0)))

	# Tank top: a roomy vest with straps; the wings stay feathers.
	var tank := _item("tank_top")
	_wear("tank_top", _sphere(_body_pivot, 0.5, Vector3(1.18, 0.94, 1.28), Vector3(0, -0.07, -0.06),
			tank))
	_wear("tank_top", _add(_body_pivot, _torus(0.5, 0.6), Vector3(0, -0.36, -0.05),
			Vector3(1.05, 0.5, 1.22), tank))
	for side in [-1.0, 1.0]:
		_wear("tank_top", _add(_body_pivot, _box(Vector3(0.08, 0.04, 0.6)),
				Vector3(0.26 * side, 0.42, -0.12), Vector3.ONE, tank, Vector3(0.2, 0, 0.25 * side)))

	# Hoodie: roomy shell, a hood behind the neck, front pocket and strings.
	var hoodie := _item("hoodie")
	_wear("hoodie", _sphere(_body_pivot, 0.5, Vector3(1.25, 1.08, 1.36), Vector3(0, -0.02, -0.06),
			hoodie))
	_wear("hoodie", _add(_body_pivot, _torus(0.52, 0.64), Vector3(0, -0.36, -0.05),
			Vector3(1.05, 0.6, 1.25), hoodie))
	_wear("hoodie", _sphere(_body_pivot, 0.28, Vector3(1.1, 0.8, 0.9), Vector3(0, 0.45, -0.18),
			hoodie, Vector3(0.6, 0, 0)))
	_wear("hoodie", _add(_body_pivot, _box(Vector3(0.44, 0.2, 0.05)), Vector3(0, -0.14, -0.76),
			Vector3.ONE, hoodie, Vector3(-0.35, 0, 0)))
	for side in [-1.0, 1.0]:
		_wear("hoodie", _capsule(_body_pivot, 0.012, 0.22, Vector3(0.06 * side, 0.18, -0.66),
				_toon(Color("f4f4f4")), Vector3(-0.3, 0, 0)))


## Footwear: one pair at a time. Relative to the knee, the ground is y = -0.43.
func _build_footwear() -> void:
	var white := _toon(Color("f4f4f4"))
	var dark_sole := _toon(Color("3b2a1e"))
	var wood_dark := _toon(WOOD.darkened(0.3))
	for knee in _knees:
		# Socks up to the middle of the shin, with a white stripe at the top.
		var socks := _item("socks")
		_wear("socks", _add(knee, _cylinder(0.058, 0.062, 0.26, 12), Vector3(0, -0.29, 0.0),
				Vector3.ONE, socks))
		_wear("socks", _add(knee, _cylinder(0.064, 0.064, 0.035, 12), Vector3(0, -0.15, 0.0),
				Vector3.ONE, white))
		_wear("socks", _sphere(knee, 0.5, Vector3(0.2, 0.1, 0.34), Vector3(0, -0.395, -0.1), socks,
				Vector3.ZERO, 12, 6))
		# Sneakers: chunky rounded shoe, white sole and laces.
		_wear("sneakers", _add(knee, _shoe(0.1, 0.38), Vector3(0, -0.37, -0.08),
				Vector3(1.1, 1.0, 0.75), _item("sneakers"), Vector3(PI / 2, 0, 0)))
		_wear("sneakers", _add(knee, _box(Vector3(0.23, 0.04, 0.38)), Vector3(0, -0.43, -0.08),
				Vector3.ONE, white))
		_wear("sneakers", _add(knee, _box(Vector3(0.1, 0.02, 0.12)), Vector3(0, -0.295, -0.15),
				Vector3.ONE, white))
		# Boots: rounded foot plus a tall shaft around the shin.
		var boots := _item("boots")
		_wear("boots", _add(knee, _shoe(0.1, 0.36), Vector3(0, -0.37, -0.07),
				Vector3(1.05, 1.0, 0.75), boots, Vector3(PI / 2, 0, 0)))
		_wear("boots", _add(knee, _cylinder(0.08, 0.085, 0.36, 12), Vector3(0, -0.18, 0.0),
				Vector3.ONE, boots))
		_wear("boots", _add(knee, _box(Vector3(0.22, 0.04, 0.36)), Vector3(0, -0.43, -0.07),
				Vector3.ONE, dark_sole))
		# Shoes: low and sleek, with a small heel.
		var shoes := _item("shoes")
		_wear("shoes", _add(knee, _shoe(0.085, 0.36), Vector3(0, -0.38, -0.08),
				Vector3(1.05, 1.0, 0.6), shoes, Vector3(PI / 2, 0, 0)))
		_wear("shoes", _add(knee, _box(Vector3(0.18, 0.025, 0.34)), Vector3(0, -0.425, -0.08),
				Vector3.ONE, dark_sole))
		_wear("shoes", _add(knee, _box(Vector3(0.12, 0.05, 0.07)), Vector3(0, -0.42, 0.06),
				Vector3.ONE, dark_sole))
		# Japanese sandals (geta): colored wooden board on two teeth, dark thong.
		var geta := _item("flip_flops")
		_wear("flip_flops", _add(knee, _box(Vector3(0.24, 0.04, 0.42)), Vector3(0, -0.37, -0.08),
				Vector3.ONE, geta))
		for z in [-0.2, 0.04]:
			_wear("flip_flops", _add(knee, _box(Vector3(0.22, 0.05, 0.05)), Vector3(0, -0.41, z),
					Vector3.ONE, wood_dark))
		for side in [-1.0, 1.0]:
			_wear("flip_flops", _add(knee, _box(Vector3(0.015, 0.03, 0.17)),
					Vector3(0.055 * side, -0.33, -0.16), Vector3.ONE, _toon(DARK),
					Vector3(0, 0.55 * side, 0)))


## Things on the back: one at a time.
func _build_back_items() -> void:
	var strap_dark := _toon(Color("3a2a22"))
	# Backpack: rounded pack, flap, pocket and shoulder straps.
	var pack := _item("backpack")
	_wear("backpack", _sphere(_body_pivot, 0.5, Vector3(0.62, 0.62, 0.36), Vector3(0, 0.36, 0.34),
			pack, Vector3(-0.35, 0, 0)))
	_wear("backpack", _sphere(_body_pivot, 0.5, Vector3(0.58, 0.2, 0.3), Vector3(0, 0.56, 0.24),
			pack, Vector3(-0.35, 0, 0)))
	_wear("backpack", _add(_body_pivot, _box(Vector3(0.3, 0.16, 0.08)), Vector3(0, 0.26, 0.52),
			Vector3.ONE, strap_dark, Vector3(-0.35, 0, 0)))
	for side in [-1.0, 1.0]:
		_wear("backpack", _add(_body_pivot, _torus(0.2, 0.24), Vector3(0.24 * side, 0.28, 0.0),
				Vector3(0.5, 1.3, 1.6), strap_dark, Vector3(0, 0, PI / 2)))
	# Shoulder bag: a strap across the body and a bag on the side.
	var bag := _item("bag")
	_wear("bag", _add(_body_pivot, _torus(0.5, 0.54), Vector3(0, 0.05, -0.05),
			Vector3(1.0, 1.0, 1.18), strap_dark, Vector3(0, 0, 0.9)))
	_wear("bag", _sphere(_body_pivot, 0.5, Vector3(0.18, 0.36, 0.46), Vector3(0.55, -0.18, 0.05),
			bag))
	_wear("bag", _sphere(_body_pivot, 0.5, Vector3(0.2, 0.12, 0.46), Vector3(0.56, -0.04, 0.05),
			bag))
	# Superhero cape: hangs from the shoulders and flies back with speed.
	var cape := _item("cape")
	cape.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cape.position = Vector3(0, 0.36, -0.2)
	_body_pivot.add_child(_cape)
	_wear("cape", _add(_cape, _box(Vector3(0.95, 1.15, 0.03)), Vector3(0, -0.5, 0.42),
			Vector3.ONE, cape, Vector3(-0.15, 0, 0)))
	_wear("cape", _add(_body_pivot, _torus(0.14, 0.2), Vector3(0, 0.4, -0.45), Vector3.ONE, cape,
			Vector3(-0.35, 0, 0)))
	# Bag with a little dog peeking out.
	var dog_bag := _item("dog_bag")
	_wear("dog_bag", _add(_body_pivot, _torus(0.5, 0.54), Vector3(0, 0.05, -0.05),
			Vector3(1.0, 1.0, 1.18), strap_dark, Vector3(0, 0, -0.9)))
	_wear("dog_bag", _sphere(_body_pivot, 0.5, Vector3(0.36, 0.34, 0.5), Vector3(-0.6, -0.12, 0.05),
			dog_bag))
	var fur := _toon(Color("c58a4a"))
	var fur_dark := _toon(Color("6b4524"))
	var dog := Vector3(-0.62, 0.16, -0.02)
	_wear("dog_bag", _sphere(_body_pivot, 0.15, Vector3(1.0, 0.95, 1.0), dog, fur))
	_wear("dog_bag", _sphere(_body_pivot, 0.07, Vector3(1.0, 0.8, 1.2), dog + Vector3(0, -0.04, -0.14),
			_toon(Color("e9c79b"))))
	_wear("dog_bag", _sphere(_body_pivot, 0.03, Vector3.ONE, dog + Vector3(0, -0.01, -0.22),
			_toon(DARK)))
	for side in [-1.0, 1.0]:
		_wear("dog_bag", _sphere(_body_pivot, 0.07, Vector3(0.5, 1.2, 0.8),
				dog + Vector3(0.12 * side, 0.08, 0.02), fur_dark, Vector3(0, 0, 0.5 * side)))
		_wear("dog_bag", _sphere(_body_pivot, 0.025, Vector3.ONE, dog + Vector3(0.06 * side, 0.04, -0.12),
				_toon(DARK)))
	# Bag with a cat peeking out: pointy ears and whiskers.
	var cat_bag := _item("cat_bag")
	_wear("cat_bag", _add(_body_pivot, _torus(0.5, 0.54), Vector3(0, 0.05, -0.05),
			Vector3(1.0, 1.0, 1.18), strap_dark, Vector3(0, 0, -0.9)))
	_wear("cat_bag", _sphere(_body_pivot, 0.5, Vector3(0.36, 0.34, 0.5), Vector3(-0.6, -0.12, 0.05),
			cat_bag))
	var cat_fur := _toon(Color("9a9aa2"))
	var cat := Vector3(-0.62, 0.15, -0.02)
	_wear("cat_bag", _sphere(_body_pivot, 0.14, Vector3(1.05, 0.9, 0.95), cat, cat_fur))
	_wear("cat_bag", _sphere(_body_pivot, 0.025, Vector3.ONE, cat + Vector3(0, -0.03, -0.13),
			_toon(Color("f08aa0"))))
	for side in [-1.0, 1.0]:
		_wear("cat_bag", _add(_body_pivot, _cylinder(0.05, 0.0, 0.11, 4),
				cat + Vector3(0.08 * side, 0.13, 0.0), Vector3.ONE, cat_fur, Vector3(0, 0, -0.3 * side)))
		_wear("cat_bag", _sphere(_body_pivot, 0.028, Vector3(1.0, 1.2, 1.0),
				cat + Vector3(0.055 * side, 0.03, -0.11), _toon(Color("7bc043"))))
		for k in 2:
			_wear("cat_bag", _add(_body_pivot, _box(Vector3(0.14, 0.006, 0.006)),
					cat + Vector3(0.1 * side, -0.04 + 0.02 * k, -0.1), Vector3.ONE, _toon(Color.WHITE),
					Vector3(0, 0.3 * side, (0.15 - 0.3 * k) * side)))
	# Ostrich egg carried on the back in a sling.
	var sling := _item("ostrich_egg")
	_wear("ostrich_egg", _sphere(_body_pivot, 0.5, Vector3(0.42, 0.52, 0.42), Vector3(0, 0.52, 0.32),
			_toon(Color("f3ead8")), Vector3(-0.4, 0, 0)))
	_wear("ostrich_egg", _add(_body_pivot, _torus(0.2, 0.25), Vector3(0, 0.42, 0.3),
			Vector3(1.0, 0.6, 1.0), sling, Vector3(-0.4, 0, 0)))
	for side in [-1.0, 1.0]:
		_wear("ostrich_egg", _add(_body_pivot, _torus(0.22, 0.26), Vector3(0.22 * side, 0.28, 0.0),
				Vector3(0.5, 1.3, 1.6), sling, Vector3(0, 0, PI / 2)))
	# Hang it all from the swinging back pivot, keeping where each piece is.
	_back.position = Vector3(0, 0.45, 0.05)
	_body_pivot.add_child(_back)
	var to_back := Transform3D(Basis(), -_back.position)
	for id: String in SwanLook.SLOTS["back"]:
		for mesh: MeshInstance3D in _item_meshes[id]:
			if mesh.get_parent() == _body_pivot:
				var xform := mesh.transform
				_body_pivot.remove_child(mesh)
				_back.add_child(mesh)
				mesh.transform = to_back * xform
	var cape_xform := _cape.transform
	_body_pivot.remove_child(_cape)
	_back.add_child(_cape)
	_cape.transform = to_back * cape_xform


# --- Effects ----------------------------------------------------------------

func _build_effects() -> void:
	# Dust/smoke trail while accelerating.
	_smoke = _particles(48, 0.9, _particle_sphere(0.18), Color(0.92, 0.87, 0.8, 0.75))
	_smoke.position = Vector3(0, 0.2, 0.45)
	_smoke.direction = Vector3(0, 0.4, 1)
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 1.0
	_smoke.initial_velocity_max = 2.5
	_smoke.gravity = Vector3(0, 0.6, 0)
	_smoke.damping_min = 1.0
	_smoke.damping_max = 2.0
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.2
	_smoke.scale_amount_curve = _curve(0.5, 1.8)

	# Ring of dust when landing.
	_land_dust = _particles(20, 0.6, _particle_sphere(0.16), Color(0.92, 0.86, 0.76, 0.85))
	_land_dust.position = Vector3(0, 0.08, 0)
	_land_dust.one_shot = true
	_land_dust.explosiveness = 1.0
	_land_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_land_dust.emission_ring_axis = Vector3.UP
	_land_dust.emission_ring_radius = 0.35
	_land_dust.emission_ring_inner_radius = 0.2
	_land_dust.emission_ring_height = 0.0
	_land_dust.direction = Vector3(1, 0, 0)
	_land_dust.spread = 180.0
	_land_dust.flatness = 1.0
	_land_dust.initial_velocity_min = 2.0
	_land_dust.initial_velocity_max = 3.5
	_land_dust.gravity = Vector3(0, 0.8, 0)
	_land_dust.damping_min = 4.0
	_land_dust.damping_max = 6.0
	_land_dust.scale_amount_curve = _curve(0.6, 1.6)

	# Water splashing at the feet while wading (and when drowning).
	_splash = _particles(40, 0.6, _particle_sphere(0.07), Color(0.85, 0.95, 1.0, 0.9))
	_splash.position = Vector3(0, 0.1, 0)
	_splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_splash.emission_sphere_radius = 0.35
	_splash.direction = Vector3(0, 1, 0.4)
	_splash.spread = 40.0
	_splash.initial_velocity_min = 2.0
	_splash.initial_velocity_max = 3.5
	_splash.gravity = Vector3(0, -9.8, 0)

	# Bubbles rising when drowning.
	_bubbles = _particles(30, 1.2, _particle_sphere(0.06), Color(0.9, 0.97, 1.0, 0.8))
	_bubbles.position = Vector3(0, 1.4, -0.4)
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = 0.4
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 20.0
	_bubbles.initial_velocity_min = 0.8
	_bubbles.initial_velocity_max = 1.6
	_bubbles.gravity = Vector3(0, 0.5, 0)

	# Wind gusts from the open wings while braking.
	for side in [-1.0, 1.0]:
		var streak := BoxMesh.new()
		streak.size = Vector3(0.025, 0.6, 0.025)
		streak.material = _particle_material()
		var wind := _particles(24, 0.35, streak, Color(1, 1, 1, 0.8))
		wind.position = Vector3(1.0 * side, 1.25, 0.0)
		wind.particle_flag_align_y = true
		wind.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		wind.emission_box_extents = Vector3(0.15, 0.3, 0.5)
		wind.direction = Vector3(0.8 * side, 0.15, -0.6)
		wind.spread = 15.0
		wind.initial_velocity_min = 5.0
		wind.initial_velocity_max = 8.0
		wind.gravity = Vector3.ZERO
		_wind.append(wind)


func _particles(amount: int, lifetime: float, mesh: Mesh, color: Color) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.local_coords = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.mesh = mesh
	particles.color_ramp = _fade(color)
	add_child(particles)
	return particles


# --- Helpers ------------------------------------------------------------

func _sphere(parent: Node3D, radius: float, scl: Vector3, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, radial := 18, rings := 9) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	return _add(parent, mesh, pos, scl, mat, rot)


func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 6
	return _add(parent, mesh, pos, Vector3.ONE, mat, rot)


func _add(parent: Node3D, mesh: Mesh, pos: Vector3, scl: Vector3, mat: Material,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	instance.scale = scl
	_add_outline(mat)
	instance.material_override = mat
	parent.add_child(instance)
	_meshes.append(instance)
	return instance


static func _dome(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius
	mesh.is_hemisphere = true
	mesh.radial_segments = 16
	mesh.rings = 6
	return mesh


static func _cylinder(bottom: float, top: float, height: float, radial := 12) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = radial
	mesh.rings = 1
	return mesh


static func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 20
	mesh.ring_segments = 6
	return mesh


static func _shoe(radius: float, length: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 4
	return mesh


static func _box(box_size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return mesh


static func _toon(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 0.6
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.5
	return mat


static func _particle_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	return mat


static func _particle_sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _particle_material()
	return mesh


static func _curve(start: float, end: float) -> Curve:
	var curve := Curve.new()
	curve.max_value = maxf(start, end)
	curve.add_point(Vector2(0, start))
	curve.add_point(Vector2(1, end))
	return curve


static func _fade(color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	return gradient


static func _add_outline(mat: Material) -> void:
	if mat == null or mat.next_pass != null or mat is ShaderMaterial and mat.shader == LENS_SHADER:
		return
	if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return
	if _outline == null:
		_outline = StandardMaterial3D.new()
		_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline.albedo_color = Color("141418")
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = OUTLINE_WIDTH
		_outline.disable_receive_shadows = true
	mat.next_pass = _outline
