class_name SwanModel
extends Node3D
## Cartoon swan with a bit of ostrich, built from a few smooth primitives.
## Origin on the ground between the feet, facing -Z.
## Visual only: nothing here affects movement or collisions.

## A foot touched the ground while running. `strength` is 0..1 (speed).
signal stepped(strength: float)

const FEATHER_SHADER := preload("res://shaders/feather.gdshader")

const BODY_HEIGHT := 1.15
const WING_OPEN_ANGLE := 1.35
const BEAK_COLOR := Color("ff9a1f")

var _feather_mat := ShaderMaterial.new()
var _leg_mat := _toon(Color("2b2b30"))
var _body_pivot := Node3D.new()
var _head := Node3D.new()
var _wing_l := Node3D.new()
var _wing_r := Node3D.new()
var _wing_meshes: Array[MeshInstance3D] = []
var _leg_l := Node3D.new()
var _leg_r := Node3D.new()
var _bare_feet: Array[MeshInstance3D] = []
## Accessory id -> meshes that show it.
var _accessory_meshes := {}
## Accessory id -> material that takes the chosen color.
var _accessory_mats := {}
var _smoke: CPUParticles3D
var _wind: Array[CPUParticles3D] = []
var _phase := 0.0
var _wing_open := 0.0
var _jacket_on := false
var _land_dust: CPUParticles3D
## Landing squash and take-off stretch, 1 right after the event, fading to 0.
var _squash := 0.0
var _stretch := 0.0


func _init() -> void:
	_feather_mat.shader = FEATHER_SHADER
	_build_body()
	_build_head()
	_build_wings()
	_build_legs()
	_build_accessories()
	_build_effects()
	apply_look(SwanLook.new())


func apply_look(look: SwanLook) -> void:
	_feather_mat.set_shader_parameter("color_bottom", look.feather_color)
	_feather_mat.set_shader_parameter("color_top", look.feather_color_2)
	_feather_mat.set_shader_parameter(
			"use_gradient", look.feather_style == SwanLook.FeatherStyle.GRADIENT)
	_leg_mat.albedo_color = look.leg_color
	for id: String in _accessory_meshes:
		var worn := look.is_wearing(id)
		for mesh: MeshInstance3D in _accessory_meshes[id]:
			mesh.visible = worn
		if worn:
			(_accessory_mats[id] as StandardMaterial3D).albedo_color = look.accessories[id]
	# Closed footwear hides the bare feet; flip-flops show them.
	var footwear := look.footwear()
	for foot in _bare_feet:
		foot.visible = footwear == "" or footwear == "flip_flops"
	# With a jacket on, the wings become its sleeves.
	_jacket_on = look.is_wearing("jacket")
	for wing in _wing_meshes:
		wing.material_override = _accessory_mats["jacket"] if _jacket_on else _feather_mat


## Called every frame with the swan's current state.
func animate(delta: float, speed_ratio: float, steer: float, accel: float,
		braking: bool, on_ground: bool) -> void:
	var moving := clampf(speed_ratio * 2.0, 0.0, 1.0)
	if on_ground:
		var previous_phase := _phase
		# Long, bouncy strides: few steps per second, big swing.
		_phase += (3.2 + 5.5 * speed_ratio) * delta * moving
		# One step every half stride.
		if moving > 0.1 and floori(_phase / PI) != floori(previous_phase / PI):
			stepped.emit(moving)
		var swing := sin(_phase) * 1.15 * moving
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, swing, 1.0 - exp(-25.0 * delta))
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -swing, 1.0 - exp(-25.0 * delta))
		var bob := absf(sin(_phase)) * 0.1 * moving
		var breathe := sin(Time.get_ticks_msec() * 0.003) * 0.015 * (1.0 - moving)
		_body_pivot.position.y = BODY_HEIGHT + bob + breathe
	else:
		# Tuck the legs back while in the air.
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, -0.9, 1.0 - exp(-12.0 * delta))
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -0.7, 1.0 - exp(-12.0 * delta))
		_body_pivot.position.y = lerpf(_body_pivot.position.y, BODY_HEIGHT, 1.0 - exp(-10.0 * delta))

	var lean := -0.2 * accel * moving + (0.15 if braking else 0.0)
	_body_pivot.rotation.x = lerpf(_body_pivot.rotation.x, lean, 1.0 - exp(-8.0 * delta))
	rotation.z = lerpf(rotation.z, -steer * 0.16 * moving, 1.0 - exp(-8.0 * delta))
	_head.rotation.x = -_body_pivot.rotation.x * 0.6

	_wing_open = move_toward(_wing_open, 1.0 if braking else 0.0, delta * 7.0)
	var open := ease(_wing_open, -2.0) * WING_OPEN_ANGLE
	_wing_l.rotation.z = -open
	_wing_r.rotation.z = open

	_smoke.emitting = on_ground and accel > 0.2 and speed_ratio > 0.05
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


# --- Building -----------------------------------------------------------

func _build_body() -> void:
	_body_pivot.position.y = BODY_HEIGHT
	add_child(_body_pivot)
	_sphere(_body_pivot, 0.5, Vector3(1.0, 0.85, 1.3), Vector3.ZERO, _feather_mat)
	# Tail tuft.
	_sphere(_body_pivot, 0.16, Vector3(1.1, 0.7, 1.3), Vector3(0, 0.22, 0.62), _feather_mat,
			Vector3(0.7, 0, 0))
	# S-shaped neck.
	_capsule(_body_pivot, 0.15, 0.7, Vector3(0, 0.45, -0.5), _feather_mat, Vector3(-0.35, 0, 0))
	_capsule(_body_pivot, 0.12, 0.65, Vector3(0, 0.9, -0.64), _feather_mat, Vector3(0.12, 0, 0))


func _build_head() -> void:
	_head.position = Vector3(0, 1.24, -0.62)
	_body_pivot.add_child(_head)
	_sphere(_head, 0.21, Vector3(0.95, 0.95, 1.1), Vector3.ZERO, _feather_mat)
	var beak := CylinderMesh.new()
	beak.top_radius = 0.015
	beak.bottom_radius = 0.085
	beak.height = 0.3
	beak.radial_segments = 12
	beak.rings = 1
	_add(_head, beak, Vector3(0, -0.04, -0.3), Vector3.ONE, _toon(BEAK_COLOR), Vector3(-PI / 2, 0, 0))
	var white := _toon(Color.WHITE)
	var black := _toon(Color("151518"))
	for side in [-1.0, 1.0]:
		_sphere(_head, 0.065, Vector3.ONE, Vector3(0.12 * side, 0.06, -0.12), white)
		_sphere(_head, 0.035, Vector3.ONE, Vector3(0.145 * side, 0.07, -0.165), black)


func _build_wings() -> void:
	for side in [-1.0, 1.0]:
		var pivot := _wing_l if side < 0 else _wing_r
		pivot.position = Vector3(0.47 * side, 0.18, 0.02)
		_body_pivot.add_child(pivot)
		var wing := _sphere(pivot, 0.5, Vector3(0.14, 0.55, 0.95), Vector3(0.03 * side, -0.24, 0.08),
				_feather_mat)
		_wing_meshes.append(wing)


func _build_legs() -> void:
	for side in [-1.0, 1.0]:
		var pivot := _leg_l if side < 0 else _leg_r
		pivot.position = Vector3(0.3 * side, 0.85, 0.05)
		add_child(pivot)
		# Fluffy thigh, like an ostrich.
		_sphere(pivot, 0.13, Vector3(1.0, 1.3, 1.0), Vector3(0, 0.02, 0), _feather_mat)
		_capsule(pivot, 0.045, 0.85, Vector3(0, -0.42, 0), _leg_mat)
		_bare_feet.append(_sphere(pivot, 0.1, Vector3(1.1, 0.45, 1.7), Vector3(0, -0.81, -0.08),
				_leg_mat))


func _build_accessories() -> void:
	for id: String in SwanLook.ACCESSORY_IDS:
		_accessory_meshes[id] = []
		_accessory_mats[id] = _toon(Color.WHITE)
	var white := _toon(Color("f4f4f4"))

	# Cap.
	var cap_mat: StandardMaterial3D = _accessory_mats["cap"]
	var dome := SphereMesh.new()
	dome.radius = 0.225
	dome.height = 0.225
	dome.is_hemisphere = true
	dome.radial_segments = 16
	dome.rings = 6
	_wear("cap", _add(_head, dome, Vector3(0, 0.06, 0.02), Vector3(1, 1, 1.05), cap_mat))
	var visor := CylinderMesh.new()
	visor.top_radius = 0.17
	visor.bottom_radius = 0.17
	visor.height = 0.025
	visor.radial_segments = 16
	_wear("cap", _add(_head, visor, Vector3(0, 0.07, -0.19), Vector3(1, 1, 1.25), cap_mat))
	_wear("cap", _sphere(_head, 0.03, Vector3.ONE, Vector3(0, 0.29, 0.02), cap_mat))

	# Curly wig.
	var wig_mat: StandardMaterial3D = _accessory_mats["wig"]
	for p in [Vector3(0, 0.18, 0.02), Vector3(-0.12, 0.13, 0.05), Vector3(0.12, 0.13, 0.05),
			Vector3(0, 0.13, 0.15), Vector3(-0.11, 0.04, 0.14), Vector3(0.11, 0.04, 0.14),
			Vector3(0, 0.02, 0.2), Vector3(-0.06, 0.2, -0.08), Vector3(0.06, 0.2, -0.08)]:
		_wear("wig", _sphere(_head, 0.1, Vector3.ONE, p, wig_mat, Vector3.ZERO, 10, 6))

	# Makeup: blush and eye shadow.
	var makeup_mat: StandardMaterial3D = _accessory_mats["makeup"]
	for side in [-1.0, 1.0]:
		_wear("makeup", _sphere(_head, 0.055, Vector3(0.35, 0.8, 1.0),
				Vector3(0.185 * side, -0.05, -0.08), makeup_mat))
		_wear("makeup", _sphere(_head, 0.07, Vector3(1.0, 0.6, 1.0),
				Vector3(0.115 * side, 0.1, -0.1), makeup_mat))

	# Lashes: three long curved lashes over each eye.
	var lash_mat: StandardMaterial3D = _accessory_mats["lashes"]
	for side in [-1.0, 1.0]:
		for i in 3:
			_wear("lashes", _add(_head, _box(Vector3(0.014, 0.075, 0.014)),
					Vector3((0.125 + 0.022 * i) * side, 0.14, -0.13 - 0.014 * i), Vector3.ONE,
					lash_mat, Vector3(0.3, 0, -0.45 * side * (i + 1) / 3.0)))

	# Glasses: round frames in front of the eyes, a bridge and the arms.
	var glasses_mat: StandardMaterial3D = _accessory_mats["glasses"]
	var lens := _toon(Color(0.75, 0.9, 1.0, 0.35))
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for side in [-1.0, 1.0]:
		var frame := TorusMesh.new()
		frame.inner_radius = 0.06
		frame.outer_radius = 0.078
		frame.rings = 16
		frame.ring_segments = 6
		_wear("glasses", _add(_head, frame, Vector3(0.1 * side, 0.06, -0.205), Vector3.ONE,
				glasses_mat, Vector3(PI / 2, 0, 0)))
		var glass := CylinderMesh.new()
		glass.top_radius = 0.062
		glass.bottom_radius = 0.062
		glass.height = 0.005
		glass.radial_segments = 16
		glass.rings = 1
		_wear("glasses", _add(_head, glass, Vector3(0.1 * side, 0.06, -0.205), Vector3.ONE, lens,
				Vector3(PI / 2, 0, 0)))
		_wear("glasses", _add(_head, _box(Vector3(0.015, 0.015, 0.2)),
				Vector3(0.185 * side, 0.07, -0.11), Vector3.ONE, glasses_mat))
	_wear("glasses", _add(_head, _box(Vector3(0.05, 0.015, 0.015)), Vector3(0, 0.07, -0.215),
			Vector3.ONE, glasses_mat))

	# Necklace: a thin ring around the neck with a round pendant.
	var necklace_mat: StandardMaterial3D = _accessory_mats["necklace"]
	necklace_mat.metallic = 0.6
	var chain := TorusMesh.new()
	chain.inner_radius = 0.145
	chain.outer_radius = 0.17
	chain.rings = 20
	chain.ring_segments = 6
	_wear("necklace", _add(_body_pivot, chain, Vector3(0, 0.6, -0.55), Vector3.ONE, necklace_mat,
			Vector3(-0.6, 0, 0)))
	_wear("necklace", _sphere(_body_pivot, 0.04, Vector3(1, 1, 0.5), Vector3(0, 0.5, -0.71),
			necklace_mat, Vector3(-0.6, 0, 0)))

	# Jacket: shell over the body, collar and zipper. Wings become sleeves.
	var jacket_mat: StandardMaterial3D = _accessory_mats["jacket"]
	_wear("jacket", _sphere(_body_pivot, 0.5, Vector3(1.06, 0.9, 1.2), Vector3(0, 0.02, -0.07),
			jacket_mat))
	var collar := TorusMesh.new()
	collar.inner_radius = 0.12
	collar.outer_radius = 0.21
	collar.rings = 16
	collar.ring_segments = 8
	_wear("jacket", _add(_body_pivot, collar, Vector3(0, 0.4, -0.47), Vector3.ONE, jacket_mat,
			Vector3(-0.35, 0, 0)))
	var zipper := BoxMesh.new()
	zipper.size = Vector3(0.03, 0.45, 0.03)
	_wear("jacket", _add(_body_pivot, zipper, Vector3(0, 0.02, -0.66), Vector3.ONE,
			_toon(Color("3a3a40")), Vector3(-0.5, 0, 0)))

	# Footwear: one pair at a time (see SwanLook.FOOTWEAR_IDS).
	var dark_sole := _toon(Color("3b2a1e"))
	for leg in [_leg_l, _leg_r]:
		# Sneakers: chunky rounded shoe, white sole and laces.
		_wear("sneakers", _add(leg, _shoe_mesh(0.1, 0.38), Vector3(0, -0.79, -0.08),
				Vector3(1.1, 1.0, 0.75), _accessory_mats["sneakers"], Vector3(PI / 2, 0, 0)))
		_wear("sneakers", _add(leg, _box(Vector3(0.23, 0.04, 0.38)), Vector3(0, -0.85, -0.08),
				Vector3.ONE, white))
		_wear("sneakers", _add(leg, _box(Vector3(0.1, 0.02, 0.12)), Vector3(0, -0.715, -0.15),
				Vector3.ONE, white))

		# Boots: rounded foot plus a tall shaft around the shin.
		var boot_mat: StandardMaterial3D = _accessory_mats["boots"]
		_wear("boots", _add(leg, _shoe_mesh(0.1, 0.36), Vector3(0, -0.79, -0.07),
				Vector3(1.05, 1.0, 0.75), boot_mat, Vector3(PI / 2, 0, 0)))
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.085
		shaft.bottom_radius = 0.08
		shaft.height = 0.36
		shaft.radial_segments = 12
		shaft.rings = 1
		_wear("boots", _add(leg, shaft, Vector3(0, -0.6, 0.0), Vector3.ONE, boot_mat))
		_wear("boots", _add(leg, _box(Vector3(0.22, 0.04, 0.36)), Vector3(0, -0.85, -0.07),
				Vector3.ONE, dark_sole))

		# Shoes: low and sleek, with a small heel.
		var shoes_mat: StandardMaterial3D = _accessory_mats["shoes"]
		_wear("shoes", _add(leg, _shoe_mesh(0.085, 0.36), Vector3(0, -0.8, -0.08),
				Vector3(1.05, 1.0, 0.6), shoes_mat, Vector3(PI / 2, 0, 0)))
		_wear("shoes", _add(leg, _box(Vector3(0.18, 0.025, 0.34)), Vector3(0, -0.845, -0.08),
				Vector3.ONE, dark_sole))
		_wear("shoes", _add(leg, _box(Vector3(0.12, 0.05, 0.07)), Vector3(0, -0.84, 0.06),
				Vector3.ONE, dark_sole))

		# Flip-flops: colored sole under the bare foot and a thin strap.
		var flip_mat: StandardMaterial3D = _accessory_mats["flip_flops"]
		_wear("flip_flops", _add(leg, _box(Vector3(0.24, 0.03, 0.42)), Vector3(0, -0.84, -0.08),
				Vector3.ONE, flip_mat))
		for side in [-1.0, 1.0]:
			_wear("flip_flops", _add(leg, _box(Vector3(0.015, 0.015, 0.14)),
					Vector3(0.06 * side, -0.8, -0.16), Vector3.ONE, white,
					Vector3(0, 0.5 * side, 0)))


func _build_effects() -> void:
	# Dust/smoke trail while accelerating.
	_smoke = CPUParticles3D.new()
	_smoke.position = Vector3(0, 0.2, 0.45)
	_smoke.emitting = false
	_smoke.local_coords = false
	_smoke.amount = 48
	_smoke.lifetime = 0.9
	_smoke.mesh = _particle_sphere(0.18)
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
	_smoke.color_ramp = _fade(Color(0.92, 0.87, 0.8, 0.75))
	add_child(_smoke)

	# Ring of dust when landing.
	_land_dust = CPUParticles3D.new()
	_land_dust.position = Vector3(0, 0.08, 0)
	_land_dust.emitting = false
	_land_dust.one_shot = true
	_land_dust.explosiveness = 1.0
	_land_dust.local_coords = false
	_land_dust.amount = 20
	_land_dust.lifetime = 0.6
	_land_dust.mesh = _particle_sphere(0.16)
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
	_land_dust.color_ramp = _fade(Color(0.92, 0.86, 0.76, 0.85))
	add_child(_land_dust)

	# Wind gusts from the open wings while braking.
	for side in [-1.0, 1.0]:
		var wind := CPUParticles3D.new()
		wind.position = Vector3(1.0 * side, 1.25, 0.0)
		wind.emitting = false
		wind.local_coords = false
		wind.amount = 24
		wind.lifetime = 0.35
		var streak := BoxMesh.new()
		streak.size = Vector3(0.025, 0.6, 0.025)
		streak.material = _particle_material()
		wind.mesh = streak
		wind.particle_flag_align_y = true
		wind.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		wind.emission_box_extents = Vector3(0.15, 0.3, 0.5)
		wind.direction = Vector3(0.8 * side, 0.15, -0.6)
		wind.spread = 15.0
		wind.initial_velocity_min = 5.0
		wind.initial_velocity_max = 8.0
		wind.gravity = Vector3.ZERO
		wind.color_ramp = _fade(Color(1, 1, 1, 0.8))
		add_child(wind)
		_wind.append(wind)


# --- Helpers ------------------------------------------------------------

static func _shoe_mesh(radius: float, length: float) -> CapsuleMesh:
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


func _wear(id: String, mesh: MeshInstance3D) -> void:
	mesh.visible = false
	_accessory_meshes[id].append(mesh)


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
	instance.material_override = mat
	parent.add_child(instance)
	return instance


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
