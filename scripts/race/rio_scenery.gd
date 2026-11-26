class_name RioScenery
extends RefCounted
## Builds Rio's seafront around a RioCourse, from the sea inwards: the sea,
## the beach with umbrellas, kiosks and volleyball nets, the sand where swans
## run, the wavy black-and-white promenade, coconut palms, the avenue, a row
## of apartment buildings and green hills behind, with a big round granite
## peak at the end of the bay. Also the puddles, logs, gates and the people.
## Decoration only: what collides lives in the course (CourseRules).

const SAND := Color("e6d3a3")
const WET_SAND := Color("c9ad77")
const ASPHALT := Color("4b4e54")
const SIDEWALK := Color("cfc8bb")
const CURB := Color("e9e4da")
const CITY := Color("8a9479")
const PALM_TRUNK := Color("8a6f4e")
const PALM_GREEN := Color("3f8a35")
const HILL := Color("4c7a3a")
const GRANITE := Color("8d8a83")
const WATER_SHADER := preload("res://shaders/water.gdshader")
## Where things are across the seafront (lateral offset; + = sea side).
const SEA_START := 48.0
const AVENUE_FROM := -32.0
const AVENUE_TO := -14.0
const BUILDINGS_AT := -40.0
const BUILDING_COLORS := [Color("f2efe6"), Color("e9dcc4"), Color("f0d9b5"), Color("d9e4e6"),
		Color("efe2d0"), Color("e6cfc2"), Color("dfe7d6")]
const UMBRELLA_COLORS := [Color("e8412c"), Color("ffd23f"), Color("2a9df4"), Color("3fbf6a"),
		Color("ff8a2a"), Color("f2f2f2")]
const SHIRTS := [Color("e8412c"), Color("ffd23f"), Color("2a9df4"), Color("3fbf6a"),
		Color("ff8ac2"), Color("8a5cf6"), Color("f2f2f2")]
const SKIN := [Color("8d5524"), Color("c68642"), Color("e0ac69"), Color("f1c27d"), Color("5a3a22")]
const STEP := 4


static func build(parent: Node3D, course: RioCourse) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	Scenery.add_environment(parent)
	_build_sea(parent, course)
	_build_ground(parent, course)
	_build_promenade(parent, course)
	_build_buildings(parent, course, rng)
	_build_hills(parent, course, rng)
	_build_palms(parent, course, rng)
	_build_beach(parent, course, rng)
	_build_puddles(parent, course)
	AlpsScenery._build_logs(parent, course)
	AlpsScenery._build_gate(parent, course, course.start_distance, Color("1f9e4a"))
	AlpsScenery._build_gate(parent, course, course.finish_distance, Color("1d1d22"))
	_build_people(parent, course, rng)


# --- Ground and sea ------------------------------------------------------------

static func _build_sea(parent: Node3D, course: RioCourse) -> void:
	var middle := course.points[course.sample_count() / 2]
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(5000, 5000)
	mesh.subdivide_width = 200
	mesh.subdivide_depth = 200
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("shore_radius", 4000.0)
	var sea := MeshInstance3D.new()
	sea.mesh = mesh
	sea.material_override = mat
	sea.position = Vector3(middle.x, 0.0, middle.y)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sea)


## Across the seafront at sample i: (lateral, height, color), the same number
## of points everywhere so the rows stitch together.
static func _profile(course: RioCourse, i: int) -> Array:
	var g := RioCourse.GROUND
	var right := course.right_edge(i)
	return [
		[-400.0, g, CITY],
		[BUILDINGS_AT - 30.0, g, SIDEWALK],
		[AVENUE_FROM, g, SIDEWALK],
		[AVENUE_FROM + 0.2, g - 0.15, ASPHALT],
		[AVENUE_TO - 0.2, g - 0.15, ASPHALT],
		[AVENUE_TO, g, CURB],
		[-8.0, g, SIDEWALK],
		[RioCourse.PROMENADE_END, g, SAND],
		[right, g, SAND],
		[SEA_START - 10.0, g - 0.1, SAND],
		[SEA_START - 2.0, g - 0.45, WET_SAND],
		[SEA_START + 8.0, -0.9, WET_SAND.darkened(0.2)],
	]


static func _build_ground(parent: Node3D, course: RioCourse) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 0.08
	var st := MeshKit.begin()
	var count := course.sample_count()
	var i := 0
	while i < count - 1:
		var j := mini(i + STEP, count - 1)
		var a := _profile(course, i)
		var b := _profile(course, j)
		for n in a.size() - 1:
			var corners := [
				_v3(course.edge(i, a[n][0]), a[n][1]),
				_v3(course.edge(j, b[n][0]), b[n][1]),
				_v3(course.edge(j, b[n + 1][0]), b[n + 1][1]),
				_v3(course.edge(i, a[n + 1][0]), a[n + 1][1]),
			]
			var colors := [a[n][2], b[n][2], b[n + 1][2], a[n + 1][2]]
			for k in 4:
				var c: Vector3 = corners[k]
				colors[k] = (colors[k] as Color) * (0.95 + 0.06 * noise.get_noise_2d(c.x, c.z))
			IslandScenery._quad(st, corners[0], corners[1], corners[2], corners[3],
					colors[0], colors[1], colors[2], colors[3])
		i = j
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), false)


## The famous promenade: black and white waves running along the beach,
## from the avenue's curb to the sand.
static func _build_promenade(parent: Node3D, course: RioCourse) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var from := AVENUE_TO
	var to := RioCourse.PROMENADE_END
	var count := course.sample_count()
	var y := RioCourse.GROUND + 0.04
	var i := 0
	while i < count - 1:
		var j := mini(i + STEP, count - 1)
		# One texture tile every 4 m along, the whole width across.
		var u0 := course.lengths[i] / 4.0
		var u1 := course.lengths[j] / 4.0
		var quad := [
			[_v3(course.edge(i, from), y), Vector2(u0, 0.0)],
			[_v3(course.edge(j, from), y), Vector2(u1, 0.0)],
			[_v3(course.edge(j, to), y), Vector2(u1, 1.0)],
			[_v3(course.edge(i, to), y), Vector2(u0, 1.0)],
		]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[k][1])
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[k][0])
		i = j
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _wave_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	IslandScenery._add_mesh(parent, st.commit(), mat, false)


## Wavy stripes: x runs along the beach (one tile = 4 m), y across.
static func _wave_texture() -> ImageTexture:
	var width := 128
	var height := 256
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	var black := Color("26282b")
	var white := Color("f1eee6")
	for x in width:
		for y in height:
			# Waves across the promenade: four stripes, each bending with x.
			var v := float(y) / height * 4.0 + 0.22 * sin(TAU * float(x) / width)
			image.set_pixel(x, y, black if fposmod(v, 1.0) < 0.5 else white)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# --- City -----------------------------------------------------------------------

## A row of apartment buildings facing the sea, with rows of windows and balconies.
static func _build_buildings(parent: Node3D, course: RioCourse, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var d := -40.0
	var window := Color("3a4a5a")
	while d < course.length + 40.0:
		var width := rng.randf_range(16.0, 24.0)
		var at := clampf(d + width * 0.5, 0.0, course.length)
		var i := course.index_at(at)
		var height := rng.randf_range(24.0, 48.0)
		var depth := 16.0
		var yaw := course.heading_at(i)
		# Box axes (yaw = heading): z along the beach, x across (+ = sea side).
		var front := _v3(course.edge(i, BUILDINGS_AT), RioCourse.GROUND)
		var center := front + _toward_land(course, i) * depth * 0.5
		var color: Color = BUILDING_COLORS[rng.randi_range(0, BUILDING_COLORS.size() - 1)]
		var box := BoxMesh.new()
		box.size = Vector3(depth, height, width)
		MeshKit.add(st, box, Transform3D(Basis(Vector3.UP, yaw), center + Vector3.UP * height * 0.5), color)
		# Window rows on the side facing the beach, every floor (3 m).
		var face := front + _toward_land(course, i) * -0.06
		var floors := int((height - 4.0) / 3.0)
		for f in floors:
			var band := BoxMesh.new()
			band.size = Vector3(0.1, 1.2, width - 2.0)
			MeshKit.add(st, band, Transform3D(Basis(Vector3.UP, yaw), face + Vector3.UP * (4.5 + f * 3.0)),
					window)
		d += width + rng.randf_range(1.0, 4.0)
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)


## Unit vector from the beach towards the city at sample i (the left side).
static func _toward_land(course: CourseTrack, i: int) -> Vector3:
	var r := course.right(i)
	return Vector3(-r.x, 0.0, -r.y)


## Green hills behind the city, and a big round granite peak rising from the
## sea past the end of the bay, ahead of the racers.
static func _build_hills(parent: Node3D, course: RioCourse, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	for n in 14:
		var i := clampi(int(count * (n + 0.5) / 14.0), 0, count - 1)
		# Always well behind the buildings (they end ~60 m from the course).
		var radius := rng.randf_range(160.0, 260.0)
		var behind := _v3(course.edge(i, -(radius + rng.randf_range(110.0, 200.0))), 0.0)
		var height := rng.randf_range(90.0, 220.0)
		MeshKit.add(st, MeshKit.sphere(1.0, 12, 7), _at(behind, Vector3(radius, height, radius)), HILL)
	# The granite peak: out in the water past the end of the bay, round and tall.
	var last := count - 1
	var start_dir := course.tangent(last)
	var peak := course.points[last] + start_dir * 650.0 + course.right(last) * 260.0
	MeshKit.add(st, MeshKit.sphere(1.0, 14, 8), _at(_v3(peak, 0.0), Vector3(150.0, 340.0, 150.0)), GRANITE)
	MeshKit.add(st, MeshKit.sphere(1.0, 12, 6), _at(_v3(peak, 150.0), Vector3(110.0, 120.0, 110.0)),
			HILL.darkened(0.1))
	var small := peak + course.right(last) * 300.0 + start_dir * 120.0
	MeshKit.add(st, MeshKit.sphere(1.0, 12, 7), _at(_v3(small, 0.0), Vector3(120.0, 170.0, 120.0)), GRANITE)
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


# --- Palms, beach things --------------------------------------------------------

static func _palm_mesh() -> Mesh:
	var st := MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.22, 0.16, 8.0, 7), _at(Vector3(0, 4.0, 0), Vector3.ONE,
			Vector3(0, 0, 0.06)), PALM_TRUNK)
	var top := Vector3(0.25, 8.0, 0)
	for n in 7:
		var angle := TAU * n / 7.0
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var basis := Basis.looking_at(out + Vector3.DOWN * 0.35, Vector3.UP)
		MeshKit.add(st, MeshKit.sphere(1.0, 6, 3),
				Transform3D(basis.scaled(Vector3(0.5, 0.12, 2.2)), top + out * 1.6 + Vector3.DOWN * 0.3),
				PALM_GREEN)
	MeshKit.add(st, MeshKit.sphere(0.45, 7, 4), _at(top), Color("5a4a2a"))
	return MeshKit.finish(st)


## Coconut palms along the promenade, by the curb and between the kiosks.
static func _build_palms(parent: Node3D, course: RioCourse, rng: RandomNumberGenerator) -> void:
	var list: Array[Transform3D] = []
	var d := 8.0
	while d < course.length:
		var i := course.index_at(d)
		for lateral: float in [AVENUE_TO + 1.2, RioCourse.RIGHT + 4.0]:
			var p := course.edge(i, lateral + rng.randf_range(-0.4, 0.4))
			list.append(IslandScenery._varied(p, RioCourse.GROUND, rng, 0.85, 1.2))
		d += rng.randf_range(13.0, 18.0)
	IslandScenery._multimesh(parent, _palm_mesh(), list, true, rng)


## Umbrellas, kiosks and volleyball nets on the beach between the course and the sea.
static func _build_beach(parent: Node3D, course: RioCourse, rng: RandomNumberGenerator) -> void:
	var umbrellas := {}
	for color: Color in UMBRELLA_COLORS:
		umbrellas[color] = [] as Array[Transform3D]
	var d := 10.0
	while d < course.length:
		var lateral := rng.randf_range(RioCourse.RIGHT + 8.0, SEA_START - 12.0)
		var p := course.edge(course.index_at(d), lateral)
		var color: Color = UMBRELLA_COLORS[rng.randi_range(0, UMBRELLA_COLORS.size() - 1)]
		(umbrellas[color] as Array[Transform3D]).append(
				IslandScenery._placed(p, RioCourse.GROUND - 0.05, rng.randf() * TAU, rng.randf_range(0.9, 1.1)))
		d += rng.randf_range(4.0, 9.0)
	for color: Color in umbrellas:
		IslandScenery._multimesh(parent, _umbrella_mesh(color), umbrellas[color], false, rng)

	var st := MeshKit.begin()
	# Kiosks: a round counter with a striped roof, every ~150 m.
	d = 70.0
	while d < course.length:
		var i := course.index_at(d)
		var base := _v3(course.edge(i, RioCourse.RIGHT + 6.5), RioCourse.GROUND)
		MeshKit.add(st, MeshKit.cylinder(1.8, 1.8, 2.4, 10), _at(base + Vector3.UP * 1.2), Color("2e7d4f"))
		MeshKit.add(st, MeshKit.cylinder(3.2, 0.2, 1.4, 10), _at(base + Vector3.UP * 3.3), Color("f2f2f2"))
		d += rng.randf_range(130.0, 170.0)
	# Volleyball nets: two posts and a net.
	d = 160.0
	while d < course.length:
		var i := course.index_at(d)
		var lateral := rng.randf_range(RioCourse.RIGHT + 14.0, SEA_START - 16.0)
		var a := _v3(course.edge(i - 4, lateral), RioCourse.GROUND)
		var b := _v3(course.edge(i + 4, lateral), RioCourse.GROUND)
		for post: Vector3 in [a, b]:
			MeshKit.add(st, MeshKit.cylinder(0.06, 0.06, 2.5, 6), _at(post + Vector3.UP * 1.25), Color("eeeeee"))
		var net := BoxMesh.new()
		net.size = Vector3(0.04, 0.9, a.distance_to(b))
		var yaw := atan2(b.x - a.x, b.z - a.z)
		MeshKit.add(st, net, Transform3D(Basis(Vector3.UP, yaw), (a + b) * 0.5 + Vector3.UP * 2.0),
				Color("1d1d22"))
		d += rng.randf_range(260.0, 340.0)
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)


static func _umbrella_mesh(color: Color) -> Mesh:
	var st := MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.04, 0.04, 2.3, 5), _at(Vector3(0, 1.15, 0)), Color("eeeeee"))
	MeshKit.add(st, MeshKit.cylinder(1.4, 0.05, 0.55, 10), _at(Vector3(0, 2.3, 0)), color)
	# A towel under it.
	var towel := BoxMesh.new()
	towel.size = Vector3(0.8, 0.02, 1.7)
	MeshKit.add(st, towel, _at(Vector3(0.9, 0.03, 0.3)), color.lightened(0.4))
	return MeshKit.finish(st)


## Puddles: shallow water on the sand, with a darker wet rim.
static func _build_puddles(parent: Node3D, course: RioCourse) -> void:
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.35, 0.62, 0.78, 0.85)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.1
	water.metallic_specular = 0.8
	var rim_mat := MeshKit.vertex_color_material()
	for puddle: Dictionary in course.puddles:
		var i := course.index_at(puddle.distance)
		var p := course.edge(i, puddle.lateral)
		var yaw := course.heading_at(i)
		var radius: float = puddle.radius
		# Longer along the course (CourseTrack.in_puddle stretches it 1.6x).
		var shape := Basis(Vector3.UP, yaw).scaled(Vector3(radius, 1.0, radius * 1.6))
		var rim := MeshInstance3D.new()
		rim.transform = Transform3D(shape, _v3(p, RioCourse.GROUND + 0.02))
		var st := MeshKit.begin()
		MeshKit.add(st, MeshKit.cylinder(1.15, 1.15, 0.02, 20), Transform3D.IDENTITY, WET_SAND)
		rim.mesh = MeshKit.finish(st)
		rim.material_override = rim_mat
		parent.add_child(rim)
		var surface := MeshInstance3D.new()
		surface.mesh = MeshKit.cylinder(1.0, 1.0, 0.02, 20)
		surface.transform = Transform3D(shape, _v3(p, RioCourse.GROUND + 0.05))
		surface.material_override = water
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(surface)


# --- People ------------------------------------------------------------------

## Bodies for the people (simple shapes, varied colors), added with them to the scene.
static func _build_people(parent: Node3D, course: RioCourse, rng: RandomNumberGenerator) -> void:
	for mover in course.movers:
		var body := MeshInstance3D.new()
		body.mesh = _person_mesh(mover.kind == "surfer", rng)
		body.material_override = MeshKit.vertex_color_material()
		mover.add_child(body)
		parent.add_child(mover)


## A person facing -Z: legs, shorts, shirt, arms, head and hair; a surfer
## carries a board under the arm.
static func _person_mesh(surfer: bool, rng: RandomNumberGenerator) -> Mesh:
	var st := MeshKit.begin()
	var skin: Color = SKIN[rng.randi_range(0, SKIN.size() - 1)]
	var shirt: Color = SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]
	var shorts := Color("2c4a7a") if rng.randf() < 0.5 else Color("e8a33a")
	for x: float in [-0.1, 0.1]:
		MeshKit.add(st, MeshKit.cylinder(0.07, 0.06, 0.8, 6), _at(Vector3(x, 0.4, 0)), skin)
	MeshKit.add(st, MeshKit.cylinder(0.2, 0.18, 0.3, 8), _at(Vector3(0, 0.88, 0)), shorts)
	MeshKit.add(st, MeshKit.cylinder(0.18, 0.21, 0.55, 8), _at(Vector3(0, 1.3, 0)),
			skin if surfer else shirt)
	for x: float in [-0.27, 0.27]:
		MeshKit.add(st, MeshKit.cylinder(0.055, 0.05, 0.6, 6),
				_at(Vector3(x, 1.25, 0), Vector3.ONE, Vector3(0, 0, -signf(x) * 0.15)), skin)
	MeshKit.add(st, MeshKit.sphere(0.15, 10, 6), _at(Vector3(0, 1.72, 0)), skin)
	MeshKit.add(st, MeshKit.sphere(0.155, 10, 5), _at(Vector3(0, 1.78, 0.02), Vector3(1.0, 0.6, 1.0)),
			Color("2a1d14") if rng.randf() < 0.7 else Color("d9b45a"))
	if surfer:
		var board := BoxMesh.new()
		board.size = Vector3(0.08, 0.5, 2.0)
		MeshKit.add(st, board, _at(Vector3(0.36, 1.15, 0)), shirt)
	return MeshKit.finish(st)


# --- Helpers -------------------------------------------------------------------

static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


static func _at(pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> Transform3D:
	return IslandScenery._at(pos, scl, rot)
