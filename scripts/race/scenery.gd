class_name Scenery
extends RefCounted
## Builds the prototype's look: sky, sun and a flat beach.
## Everything here is decoration: nothing collides with the swans.

const SAND := Color("c4a072")
const SAND_DARK := Color("a7845a")
const SEA_EDGE_X := 115.0


static func add_environment(parent: Node) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4f8fe0")
	sky_material.sky_horizon_color = Color("bcd6ef")
	sky_material.ground_horizon_color = Color("d8c3a0")
	sky_material.ground_bottom_color = Color("8a6d4c")
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("c9dbec")
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	parent.add_child(sun)


static func add_beach(parent: Node, seed_value: int) -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var ramp := Gradient.new()
	ramp.set_color(0, SAND_DARK)
	ramp.set_color(1, SAND.lightened(0.12))
	var sand_texture := NoiseTexture2D.new()
	sand_texture.noise = noise
	sand_texture.color_ramp = ramp
	sand_texture.seamless = true
	var sand := StandardMaterial3D.new()
	sand.albedo_texture = sand_texture
	sand.uv1_scale = Vector3(60, 60, 1)
	sand.roughness = 1.0
	_plane(parent, Vector2(1200, 1200), Vector3.ZERO, sand)

	# Sea along one side, with wet sand and foam at the shoreline.
	_plane(parent, Vector2(12, 1200), Vector3(SEA_EDGE_X - 8.0, 0.01, 0), _flat(SAND_DARK, 0.6))
	_plane(parent, Vector2(5, 1200), Vector3(SEA_EDGE_X, 0.02, 0), _flat(Color("f3efe2"), 0.8))
	var sea := _flat(Color("2a8fb5"), 0.1)
	sea.metallic_specular = 0.8
	_plane(parent, Vector2(500, 1200), Vector3(SEA_EDGE_X + 252.0, 0.015, 0), sea)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var area_min := Vector2(-300, -550)
	var area_max := Vector2(SEA_EDGE_X - 15.0, 300)

	var pebble := SphereMesh.new()
	pebble.radius = 0.12
	pebble.height = 0.24
	pebble.radial_segments = 6
	pebble.rings = 3
	_scatter(parent, pebble, _flat(Color("8c8177"), 0.9), 2200, rng, area_min, area_max,
			0.5, 1.8, Vector3(1.0, 0.55, 1.2), false)

	var bush := SphereMesh.new()
	bush.radius = 0.6
	bush.height = 1.2
	bush.radial_segments = 8
	bush.rings = 5
	_scatter(parent, bush, _flat(Color("7a8a3c"), 1.0), 350, rng, area_min, area_max,
			0.6, 1.5, Vector3(1.0, 0.6, 1.0), true)

	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.07
	tuft.height = 0.6
	tuft.radial_segments = 4
	tuft.rings = 1
	_scatter(parent, tuft, _flat(Color("c2a95a"), 1.0), 2500, rng, area_min, area_max,
			0.6, 1.4, Vector3.ONE, false)


static func _plane(parent: Node, size: Vector2, pos: Vector3, mat: Material) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


static func _flat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return mat


static func _scatter(parent: Node, mesh: Mesh, mat: Material, count: int,
		rng: RandomNumberGenerator, area_min: Vector2, area_max: Vector2, scale_min: float,
		scale_max: float, shape: Vector3, shadows: bool) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	for i in count:
		var pos := Vector3(rng.randf_range(area_min.x, area_max.x), 0.0,
				rng.randf_range(area_min.y, area_max.y))
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(shape * rng.randf_range(scale_min, scale_max))
		multimesh.set_instance_transform(i, Transform3D(basis, pos))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = mat
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
