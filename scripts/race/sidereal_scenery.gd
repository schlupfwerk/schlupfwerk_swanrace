class_name SiderealScenery
extends RefCounted
## Builds the Sidereal Circuit: a starry sky with nebulas, a deck floating in
## space with glowing edges and a dashed center line, glowing rims around the
## holes, asteroids on the deck and drifting far away, planets (one with
## rings), a bright star, and the start gate. Decoration only: what makes a
## swan fall or bump lives in the course (CourseRules).

const DECK := Color("2d2657")
const DECK_ALT := Color("332c63")
const DECK_UNDER := Color("17132e")
const EDGE_GLOW := Color("38e8ff")
const LINE_GLOW := Color("ff5ad1")
const HOLE_GLOW := Color("ff8a2a")
const ASTEROID := Color("a8987f")
const ASTEROID_GLOW := Color("ffcf3a")
const DECK_THICKNESS := 0.6
const STEP := 2
const PLANETS := [
	# Direction (x, y, z), distance, radius, color, ring.
	[Vector3(-0.6, 0.25, -0.75), 1500.0, 260.0, Color("d9894a"), true],
	[Vector3(0.8, 0.35, 0.2), 1300.0, 140.0, Color("4a8fd9"), false],
	[Vector3(0.2, -0.45, 0.9), 1100.0, 90.0, Color("8fd96a"), false],
	[Vector3(-0.9, -0.2, 0.4), 1700.0, 180.0, Color("b56ad9"), false],
	[Vector3(0.3, 0.6, -0.7), 900.0, 45.0, Color("e8e2d6"), false],
]
const SKY_SHADER := """
shader_type sky;

uniform vec3 nebula_a : source_color = vec3(0.42, 0.12, 0.55);
uniform vec3 nebula_b : source_color = vec3(0.06, 0.3, 0.55);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void sky() {
	vec3 d = EYEDIR;
	float n = noise(d * 3.0) * 0.6 + noise(d * 7.0) * 0.3 + noise(d * 15.0) * 0.1;
	vec3 col = vec3(0.012, 0.01, 0.03);
	col += nebula_a * smoothstep(0.55, 0.9, n) * 0.6;
	col += nebula_b * smoothstep(0.5, 0.85, noise(d * 2.3 + 5.0)) * 0.5;
	vec3 cell = floor(d * 220.0);
	float star = step(0.9965, hash(cell));
	float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + hash(cell + 3.0) * 20.0);
	col += vec3(star * twinkle);
	COLOR = col;
}
"""


static func build(parent: Node3D, course: SiderealCircuit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	_build_environment(parent)
	_build_deck(parent, course)
	_build_glow_lines(parent, course)
	_build_hole_rims(parent, course)
	_build_asteroids(parent, course, rng)
	_build_planets(parent, course)
	_build_far_asteroids(parent, course, rng)
	AlpsScenery._build_gate(parent, course, 0.0, EDGE_GLOW)


# --- Sky and light ---------------------------------------------------------------

static func _build_environment(parent: Node3D) -> void:
	var shader := Shader.new()
	shader.code = SKY_SHADER
	var sky_material := ShaderMaterial.new()
	sky_material.shader = shader
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Space is dark, but the deck must read well: a cool, soft ambient light.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a86c8")
	env.ambient_light_energy = 0.7
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	Settings.configure_environment(env)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.add_to_group("world_environment")
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_opacity = 0.7
	sun.add_to_group("sun")
	Settings.configure_sun(sun)
	parent.add_child(sun)
	# The star itself, glowing in the direction the light comes from.
	var star := MeshInstance3D.new()
	star.mesh = MeshKit.sphere(80.0, 24, 12)
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color = Color("fff4d6")
	star_mat.emission_enabled = true
	star_mat.emission = Color("ffe2a8")
	star_mat.emission_energy_multiplier = 3.0
	star.material_override = star_mat
	star.position = sun.basis.z * 2200.0
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(star)


# --- Deck --------------------------------------------------------------------------

## The deck: tiles across the course (skipping the holes), the underside and
## the side walls, so it reads as a solid floating road.
static func _build_deck(parent: Node3D, course: SiderealCircuit) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	var cells := int(SiderealCircuit.HALF_WIDTH * 2.0)
	for i in range(0, count, STEP):
		var j := i + STEP
		for c in cells:
			var l0 := -SiderealCircuit.HALF_WIDTH + c
			var l1 := l0 + 1.0
			var middle := course.lengths[i] + STEP * 0.5
			if not course.hole_at(middle, l0 + 0.5).is_empty():
				continue
			var a := _deck_point(course, i, l0)
			var b := _deck_point(course, j, l0)
			var d := _deck_point(course, j, l1)
			var e := _deck_point(course, i, l1)
			var color := DECK if (c + i / STEP) % 2 == 0 else DECK_ALT
			IslandScenery._quad(st, a, b, d, e, color, color, color, color)
			var down := Vector3.DOWN * DECK_THICKNESS
			IslandScenery._quad(st, e + down, d + down, b + down, a + down,
					DECK_UNDER, DECK_UNDER, DECK_UNDER, DECK_UNDER)
		# Side walls.
		for side: float in [-1.0, 1.0]:
			var a := _deck_point(course, i, side * SiderealCircuit.HALF_WIDTH)
			var b := _deck_point(course, j, side * SiderealCircuit.HALF_WIDTH)
			var down := Vector3.DOWN * DECK_THICKNESS
			IslandScenery._quad(st, a, b, b + down, a + down, DECK_UNDER, DECK_UNDER, DECK_UNDER, DECK_UNDER)
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), true)


static func _deck_point(course: CourseTrack, i: int, lateral: float) -> Vector3:
	var p := course.edge(i, lateral)
	return Vector3(p.x, course.ground_height_at(course.lengths[course.wrap_index(i)], lateral), p.y)


static func _glow_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Glowing strips along both edges and a dashed line in the middle.
static func _build_glow_lines(parent: Node3D, course: SiderealCircuit) -> void:
	var edges := MeshKit.begin()
	var dashes := MeshKit.begin()
	var count := course.sample_count()
	var lift := Vector3.UP * 0.03
	for i in range(0, count, STEP):
		var j := i + STEP
		for side: float in [-1.0, 1.0]:
			var outer := side * SiderealCircuit.HALF_WIDTH
			var inner := outer - side * 0.35
			IslandScenery._quad(edges, _deck_point(course, i, outer) + lift,
					_deck_point(course, j, outer) + lift, _deck_point(course, j, inner) + lift,
					_deck_point(course, i, inner) + lift, EDGE_GLOW, EDGE_GLOW, EDGE_GLOW, EDGE_GLOW)
		if (i / STEP) % 3 == 0:
			IslandScenery._quad(dashes, _deck_point(course, i, -0.12) + lift,
					_deck_point(course, j, -0.12) + lift, _deck_point(course, j, 0.12) + lift,
					_deck_point(course, i, 0.12) + lift, LINE_GLOW, LINE_GLOW, LINE_GLOW, LINE_GLOW)
	IslandScenery._add_mesh(parent, edges.commit(), _glow_material(EDGE_GLOW), false)
	IslandScenery._add_mesh(parent, dashes.commit(), _glow_material(LINE_GLOW), false)


## A glowing orange frame around each hole, so it is easy to see coming.
static func _build_hole_rims(parent: Node3D, course: SiderealCircuit) -> void:
	var st := MeshKit.begin()
	var lift := Vector3.UP * 0.04
	for hole: Dictionary in course.holes:
		var half_length: float = hole.length * 0.5 + 0.3
		var low: float = hole.lateral - hole.width * 0.5 - 0.3
		var high: float = hole.lateral + hole.width * 0.5 + 0.3
		var i0 := course.index_at(hole.distance - half_length)
		var i1 := course.index_at(hole.distance + half_length)
		for along: int in [i0, i1]:
			IslandScenery._quad(st, _deck_point(course, along, low) + lift,
					_deck_point(course, along + 1, low) + lift, _deck_point(course, along + 1, high) + lift,
					_deck_point(course, along, high) + lift, HOLE_GLOW, HOLE_GLOW, HOLE_GLOW, HOLE_GLOW)
		for lateral: float in [low, high]:
			IslandScenery._quad(st, _deck_point(course, i0, lateral - 0.15) + lift,
					_deck_point(course, i1, lateral - 0.15) + lift, _deck_point(course, i1, lateral + 0.15) + lift,
					_deck_point(course, i0, lateral + 0.15) + lift, HOLE_GLOW, HOLE_GLOW, HOLE_GLOW, HOLE_GLOW)
	IslandScenery._add_mesh(parent, st.commit(), _glow_material(HOLE_GLOW), false)


# --- Asteroids and planets -------------------------------------------------------

static func _asteroid_mesh() -> Mesh:
	var st := MeshKit.begin()
	MeshKit.add(st, MeshKit.sphere(1.0, 8, 5), IslandScenery._at(Vector3(0, 0.3, 0), Vector3(1.1, 0.7, 1.0)),
			ASTEROID)
	MeshKit.add(st, MeshKit.sphere(0.5, 7, 4), IslandScenery._at(Vector3(0.45, 0.45, 0.3)),
			ASTEROID.darkened(0.2))
	MeshKit.add(st, MeshKit.sphere(0.3, 6, 3), IslandScenery._at(Vector3(-0.4, 0.5, -0.35)),
			ASTEROID.darkened(0.35))
	return MeshKit.finish(st)


## The asteroids on the deck (course obstacles): always drawn.
static func _build_asteroids(parent: Node3D, course: SiderealCircuit, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _asteroid_mesh()
	mm.instance_count = course.obstacles.size()
	# Glowing lava cracks on the rock and a glowing ring on the deck around
	# it, so the asteroids stand out against the dark deck from far away.
	var glow := MultiMesh.new()
	glow.transform_format = MultiMesh.TRANSFORM_3D
	glow.mesh = _asteroid_glow_mesh()
	glow.instance_count = course.obstacles.size()
	for n in course.obstacles.size():
		var o := course.obstacles[n]
		var y := course.ground_height_at(o.d, o.l)
		var xform := IslandScenery._placed(o.p, y - 0.05, rng.randf() * TAU, o.r * 0.9)
		mm.set_instance_transform(n, xform)
		glow.set_instance_transform(n, xform)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = MeshKit.vertex_color_material()
	parent.add_child(instance)
	var glow_instance := MultiMeshInstance3D.new()
	glow_instance.multimesh = glow
	glow_instance.material_override = _glow_material(ASTEROID_GLOW)
	glow_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glow_instance)


## The glowing parts of a deck asteroid (in the same space as _asteroid_mesh).
static func _asteroid_glow_mesh() -> Mesh:
	var st := MeshKit.begin()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.45
	ring.outer_radius = 1.7
	ring.rings = 24
	ring.ring_segments = 4
	MeshKit.add(st, ring, IslandScenery._at(Vector3(0, 0.08, 0), Vector3(1.0, 0.3, 1.0)), Color.WHITE)
	for spot: Vector3 in [Vector3(0.75, 0.55, -0.45), Vector3(-0.6, 0.7, 0.5), Vector3(0.1, 0.95, 0.3),
			Vector3(-0.85, 0.3, -0.3)]:
		MeshKit.add(st, MeshKit.sphere(0.16, 6, 3), IslandScenery._at(spot, Vector3(1.0, 0.5, 1.6)), Color.WHITE)
	return MeshKit.finish(st)


static func _build_planets(parent: Node3D, course: SiderealCircuit) -> void:
	# Around the middle of the 8.
	var bounds := Rect2(course.points[0], Vector2.ZERO)
	for p in course.points:
		bounds = bounds.expand(p)
	var center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
	for entry: Array in PLANETS:
		var direction: Vector3 = (entry[0] as Vector3).normalized()
		var radius: float = entry[2]
		var planet := MeshInstance3D.new()
		planet.mesh = MeshKit.sphere(radius, 32, 16)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = entry[3]
		mat.roughness = 0.9
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		planet.material_override = mat
		planet.position = center + direction * float(entry[1])
		planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(planet)
		if entry[4]:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = radius * 1.35
			torus.outer_radius = radius * 1.9
			torus.rings = 48
			ring.mesh = torus
			var ring_mat := StandardMaterial3D.new()
			ring_mat.albedo_color = Color(0.9, 0.78, 0.6, 0.65)
			ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			ring.material_override = ring_mat
			ring.position = planet.position
			ring.scale = Vector3(1.0, 0.04, 1.0)
			ring.rotation = Vector3(0.35, 0.0, 0.25)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(ring)


## Rocks drifting all around, far from the deck (scenery detail).
static func _build_far_asteroids(parent: Node3D, course: SiderealCircuit,
		rng: RandomNumberGenerator) -> void:
	var list: Array[Transform3D] = []
	var bounds := Rect2(course.points[0], Vector2.ZERO)
	for p in course.points:
		bounds = bounds.expand(p)
	var center := bounds.get_center()
	for n in 260:
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1, 1))
		if direction.length() < 0.1:
			continue
		var at := Vector3(center.x, 0.0, center.y) + direction.normalized() * rng.randf_range(380.0, 900.0)
		var size := rng.randf_range(2.0, 14.0)
		var tilt := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		list.append(Transform3D(tilt.scaled(Vector3.ONE * size), at))
	IslandScenery._multimesh(parent, _asteroid_mesh(), list, true, rng, false)
