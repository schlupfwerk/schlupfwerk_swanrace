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
const AVENUE_FROM := -36.0
const AVENUE_TO := -18.0
const BUILDINGS_AT := -44.0
const BIKE_LANE := Color("b5473a")
const LANE_LINE := Color("f4f1ea")
const FROND_GREENS := [Color("3f8a35"), Color("4a9a3c"), Color("357a2e"), Color("5aa043")]
const DRY_FROND := Color("a08048")
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
	_build_bike_lane(parent, course)
	_build_buildings(parent, course, rng)
	_build_hills(parent, course, rng)
	_build_palms(parent, course, rng)
	_build_beach(parent, course, rng)
	_build_bathers(parent, course, rng)
	var traffic := RioTraffic.new()
	traffic.course = course
	parent.add_child(traffic)
	_build_puddles(parent, course, RioCourse.GROUND, WET_SAND)
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
		[RioCourse.BIKE_FROM, g, SIDEWALK],
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
## from the bike lane to the sand.
static func _build_promenade(parent: Node3D, course: RioCourse) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var from := RioCourse.BIKE_TO
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


## The bike lane on the left edge of the course: red asphalt, white lines on
## both edges and a dashed line in the middle (two-way).
static func _build_bike_lane(parent: Node3D, course: RioCourse) -> void:
	var st := MeshKit.begin()
	var from := RioCourse.BIKE_FROM
	var to := RioCourse.BIKE_TO
	var middle := (from + to) * 0.5
	var y := RioCourse.GROUND + 0.04
	var line_y := y + 0.01
	var count := course.sample_count()
	var i := 0
	var dash := 0
	while i < count - 1:
		var j := mini(i + STEP, count - 1)
		_strip(st, course, i, j, from, to, y, BIKE_LANE)
		for edge: float in [from + 0.15, to - 0.15]:
			_strip(st, course, i, j, edge - 0.08, edge + 0.08, line_y, LANE_LINE)
		if dash % 2 == 0:
			_strip(st, course, i, j, middle - 0.06, middle + 0.06, line_y, LANE_LINE)
		dash += 1
		i = j
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), false)


## A flat band between two lateral offsets from sample i to sample j.
static func _strip(st: SurfaceTool, course: RioCourse, i: int, j: int, from: float, to: float, y: float,
		color: Color) -> void:
	IslandScenery._quad(st, _v3(course.edge(i, from), y), _v3(course.edge(j, from), y),
			_v3(course.edge(j, to), y), _v3(course.edge(i, to), y), color, color, color, color)


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

## A coconut palm: a tall, thin trunk curving to one side with ring marks, a
## flared base, a cluster of coconuts under the crown, long arching fronds
## made of leaflets in a V on both sides of the stem, and a couple of dry
## fronds hanging down. `variant` changes the lean and the fronds.
static func _palm_mesh(variant: int) -> Mesh:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + variant
	var height := rng.randf_range(8.5, 10.5)
	var lean := rng.randf_range(0.6, 1.8)
	# Trunk: short segments along a curve, alternating shades for the rings.
	MeshKit.add(st, MeshKit.cylinder(0.42, 0.27, 0.7, 9), _at(Vector3(0, 0.35, 0)), PALM_TRUNK.darkened(0.1))
	var segments := 12
	for k in segments:
		var t0 := float(k) / segments
		var t1 := float(k + 1) / segments
		var a := Vector3(lean * t0 * t0, height * t0, 0.0)
		var b := Vector3(lean * t1 * t1, height * t1, 0.0)
		var shade := PALM_TRUNK if k % 2 == 0 else PALM_TRUNK.lightened(0.12)
		MeshKit.add(st, MeshKit.cylinder(lerpf(0.25, 0.17, t0), lerpf(0.25, 0.17, t1), a.distance_to(b) + 0.02, 8),
				Transform3D(_up_to(b - a), (a + b) * 0.5), shade)
	var top := Vector3(lean, height, 0.0)
	MeshKit.add(st, MeshKit.sphere(0.32, 8, 5), _at(top + Vector3.UP * 0.1, Vector3(1.0, 1.3, 1.0)),
			Color("6b6a2e"))
	for n in 6:
		var angle := TAU * n / 6.0 + 0.4
		var nut := top + Vector3(cos(angle) * 0.3, -0.3 - 0.12 * (n % 2), sin(angle) * 0.3)
		MeshKit.add(st, MeshKit.sphere(0.15, 7, 4), _at(nut), Color("6d8a2a") if n % 3 else Color("7a5a2a"))
	var fronds := 13
	for f in fronds:
		var yaw := TAU * f / fronds + rng.randf_range(-0.15, 0.15)
		var rise := rng.randf_range(0.25, 0.75)
		_frond(st, top + Vector3.UP * 0.15, yaw, rise, rng.randf_range(3.6, 4.6),
				FROND_GREENS[rng.randi_range(0, FROND_GREENS.size() - 1)])
	for f in 2:
		_frond(st, top, rng.randf() * TAU, -1.2, 2.6, DRY_FROND)
	return MeshKit.finish(st)


## One frond from `base`: the stem arches up (`rise`, radians) and droops
## towards the tip; leaflets hang down on both sides, widest in the middle.
static func _frond(st: SurfaceTool, base: Vector3, yaw: float, rise: float, length: float, color: Color) -> void:
	var steps := 6
	var step := length / steps
	var pitch := rise
	var p := base
	for k in steps:
		var dir := Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch))
		var next := p + dir * step
		var width := 0.15 + 0.8 * sin(PI * (k + 0.5) / steps)
		var along := Basis.looking_at(dir, Vector3.UP)
		var tip_color := color.lerp(Color("b5b24a"), 0.25) if k == steps - 1 else color
		for side: float in [-1.0, 1.0]:
			var blade := along * Basis(Vector3(0, 0, 1), -side * 0.55)
			var leaf := BoxMesh.new()
			leaf.size = Vector3(width, 0.025, step * 1.08)
			MeshKit.add(st, leaf, Transform3D(blade, (p + next) * 0.5 + blade.x * side * width * 0.5), tip_color)
		p = next
		pitch -= 0.28


## A basis whose Y axis points along `dir`.
static func _up_to(dir: Vector3) -> Basis:
	var d := dir.normalized()
	var axis := Vector3.UP.cross(d)
	if axis.length_squared() < 0.000001:
		return Basis.IDENTITY
	return Basis(axis.normalized(), Vector3.UP.angle_to(d))


## Coconut palms: a close row along the sidewalk by the avenue, and only a few
## on the beach side, so the sand and the sea stay open.
static func _build_palms(parent: Node3D, course: RioCourse, rng: RandomNumberGenerator) -> void:
	var lists := [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D]]
	var sides := [[AVENUE_TO + 2.0, 13.0, 18.0], [RioCourse.RIGHT + 4.5, 55.0, 80.0]]
	for side: Array in sides:
		var d := 8.0 + rng.randf_range(0.0, side[1])
		while d < course.length:
			var p := course.edge(course.index_at(d), side[0] + rng.randf_range(-0.4, 0.4))
			var xform := IslandScenery._placed(p, RioCourse.GROUND, rng.randf() * TAU, rng.randf_range(0.85, 1.15))
			(lists[rng.randi_range(0, lists.size() - 1)] as Array[Transform3D]).append(xform)
			d += rng.randf_range(side[1], side[2])
	for n in lists.size():
		IslandScenery._multimesh(parent, _palm_mesh(n), lists[n], true, rng)


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
static func _build_puddles(parent: Node3D, course: CourseTrack, ground: float, rim_color: Color) -> void:
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
		rim.transform = Transform3D(shape, _v3(p, ground + 0.02))
		var st := MeshKit.begin()
		MeshKit.add(st, MeshKit.cylinder(1.15, 1.15, 0.02, 20), Transform3D.IDENTITY, rim_color)
		rim.mesh = MeshKit.finish(st)
		rim.material_override = rim_mat
		parent.add_child(rim)
		var surface := MeshInstance3D.new()
		surface.mesh = MeshKit.cylinder(1.0, 1.0, 0.02, 20)
		surface.transform = Transform3D(shape, _v3(p, ground + 0.05))
		surface.material_override = water
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(surface)


# --- People ------------------------------------------------------------------

## Bodies for the people (simple shapes, varied colors), added with them to the scene.
static func _build_people(parent: Node3D, course: RioCourse, rng: RandomNumberGenerator) -> void:
	for mover in course.movers:
		var body := MeshInstance3D.new()
		body.mesh = _cyclist_mesh(rng) if mover.kind == "cyclist" else _person_mesh(mover.kind == "surfer", rng)
		body.material_override = MeshKit.vertex_color_material()
		mover.add_child(body)
		parent.add_child(mover)


## A person facing -Z: legs, shorts, shirt, arms, head and hair; a surfer
## carries a board under the arm.
static func _person_mesh(surfer: bool, rng: RandomNumberGenerator) -> Mesh:
	var st := MeshKit.begin()
	_add_person(st, Transform3D.IDENTITY, rng, surfer)
	return MeshKit.finish(st)


## Adds a standing person (feet at the origin, facing -Z) moved by `base`.
static func _add_person(st: SurfaceTool, base: Transform3D, rng: RandomNumberGenerator, surfer := false,
		swimsuit := false) -> void:
	var skin: Color = SKIN[rng.randi_range(0, SKIN.size() - 1)]
	var shirt: Color = SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]
	var shorts := Color("2c4a7a") if rng.randf() < 0.5 else Color("e8a33a")
	if swimsuit:
		shorts = SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]
	for x: float in [-0.1, 0.1]:
		MeshKit.add(st, MeshKit.cylinder(0.07, 0.06, 0.8, 6), base * _at(Vector3(x, 0.4, 0)), skin)
	MeshKit.add(st, MeshKit.cylinder(0.2, 0.18, 0.3, 8), base * _at(Vector3(0, 0.88, 0)), shorts)
	MeshKit.add(st, MeshKit.cylinder(0.18, 0.21, 0.55, 8), base * _at(Vector3(0, 1.3, 0)),
			skin if surfer or swimsuit else shirt)
	for x: float in [-0.27, 0.27]:
		MeshKit.add(st, MeshKit.cylinder(0.055, 0.05, 0.6, 6),
				base * _at(Vector3(x, 1.25, 0), Vector3.ONE, Vector3(0, 0, -signf(x) * 0.15)), skin)
	MeshKit.add(st, MeshKit.sphere(0.15, 10, 6), base * _at(Vector3(0, 1.72, 0)), skin)
	MeshKit.add(st, MeshKit.sphere(0.155, 10, 5), base * _at(Vector3(0, 1.78, 0.02), Vector3(1.0, 0.6, 1.0)),
			Color("2a1d14") if rng.randf() < 0.7 else Color("d9b45a"))
	if surfer:
		var board := BoxMesh.new()
		board.size = Vector3(0.08, 0.5, 2.0)
		MeshKit.add(st, board, base * _at(Vector3(0.36, 1.15, 0)), shirt)


## A cyclist riding towards -Z: two wheels, a frame, a handlebar and a rider
## leaning over it with a helmet.
static func _cyclist_mesh(rng: RandomNumberGenerator) -> Mesh:
	var st := MeshKit.begin()
	var frame: Color = SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]
	var tire := Color("1d1d22")
	var skin: Color = SKIN[rng.randi_range(0, SKIN.size() - 1)]
	var shirt: Color = SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]
	for z: float in [-0.55, 0.55]:
		MeshKit.add(st, MeshKit.cylinder(0.34, 0.34, 0.05, 14), _at(Vector3(0, 0.34, z), Vector3.ONE,
				Vector3(0, 0, PI / 2)), tire)
		MeshKit.add(st, MeshKit.cylinder(0.27, 0.27, 0.06, 10), _at(Vector3(0, 0.34, z), Vector3.ONE,
				Vector3(0, 0, PI / 2)), Color("c8c8c8"))
	_bar(st, Vector3(0, 0.34, 0.55), Vector3(0, 0.8, 0.22), 0.035, frame)
	_bar(st, Vector3(0, 0.8, 0.22), Vector3(0, 0.85, -0.45), 0.035, frame)
	_bar(st, Vector3(0, 0.34, -0.55), Vector3(0, 0.95, -0.47), 0.035, frame)
	_bar(st, Vector3(0, 0.36, 0.0), Vector3(0, 0.8, 0.22), 0.035, frame)
	_bar(st, Vector3(0, 0.36, 0.0), Vector3(0, 0.85, -0.45), 0.035, frame)
	_bar(st, Vector3(-0.25, 0.97, -0.45), Vector3(0.25, 0.97, -0.45), 0.025, tire)
	var seat := BoxMesh.new()
	seat.size = Vector3(0.16, 0.06, 0.28)
	MeshKit.add(st, seat, _at(Vector3(0, 0.95, 0.24)), tire)
	# The rider: legs down to the pedals, torso leaning forward, arms to the bars.
	var hip := Vector3(0, 1.02, 0.22)
	var shoulder := Vector3(0, 1.48, -0.15)
	for x: float in [-0.11, 0.11]:
		var pedal := Vector3(x * 1.3, 0.36 + (0.12 if x > 0 else -0.08), 0.0 + (0.08 if x > 0 else -0.08))
		var knee := Vector3(x * 1.2, 0.85, -0.1)
		_bar(st, hip + Vector3(x, 0, 0), knee, 0.07, Color("2c4a7a"))
		_bar(st, knee, pedal, 0.06, skin)
		_bar(st, shoulder + Vector3(x * 2.0, 0, 0), Vector3(x * 2.2, 0.98, -0.43), 0.05, skin)
	_bar(st, hip, shoulder, 0.19, shirt)
	MeshKit.add(st, MeshKit.sphere(0.14, 10, 6), _at(shoulder + Vector3(0, 0.2, -0.1)), skin)
	MeshKit.add(st, MeshKit.sphere(0.16, 10, 5), _at(shoulder + Vector3(0, 0.26, -0.08), Vector3(1.0, 0.7, 1.2)),
			frame.darkened(0.2))
	return MeshKit.finish(st)


## A round bar from a to b.
static func _bar(st: SurfaceTool, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	MeshKit.add(st, MeshKit.cylinder(radius, radius, a.distance_to(b), 6), Transform3D(_up_to(b - a), (a + b) * 0.5),
			color)


## Umbrellas by the water with people around them: lying on towels, reclined
## on beach chairs or standing and chatting; and a few swimmers in the sea.
static func _build_bathers(parent: Node3D, course: RioCourse, rng: RandomNumberGenerator) -> void:
	var variants := 8
	var lists: Array = []
	for n in variants:
		lists.append([] as Array[Transform3D])
	var d := 6.0
	while d < course.length:
		var p := course.edge(course.index_at(d), rng.randf_range(SEA_START - 15.0, SEA_START - 7.0))
		(lists[rng.randi_range(0, variants - 1)] as Array[Transform3D]).append(
				IslandScenery._placed(p, RioCourse.GROUND - 0.08, rng.randf() * TAU, 1.0))
		d += rng.randf_range(5.0, 9.0)
	for n in variants:
		IslandScenery._multimesh(parent, _bather_spot_mesh(n, rng), lists[n], false, rng)
	# Swimmers: a head and shoulders above the water.
	var st := MeshKit.begin()
	d = 30.0
	while d < course.length:
		var p := course.edge(course.index_at(d), rng.randf_range(SEA_START + 4.0, SEA_START + 14.0))
		var skin: Color = SKIN[rng.randi_range(0, SKIN.size() - 1)]
		MeshKit.add(st, MeshKit.sphere(0.24, 8, 4), _at(_v3(p, 0.05), Vector3(1.0, 0.5, 0.7)), skin)
		MeshKit.add(st, MeshKit.sphere(0.14, 8, 5), _at(_v3(p, 0.32)), skin)
		d += rng.randf_range(18.0, 40.0)
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


static func _bather_spot_mesh(variant: int, rng: RandomNumberGenerator) -> Mesh:
	var st := MeshKit.begin()
	var color: Color = UMBRELLA_COLORS[variant % UMBRELLA_COLORS.size()]
	MeshKit.add(st, MeshKit.cylinder(0.04, 0.04, 2.3, 5), _at(Vector3(0, 1.15, 0), Vector3.ONE, Vector3(0.12, 0, 0)),
			Color("eeeeee"))
	MeshKit.add(st, MeshKit.cylinder(1.5, 0.05, 0.55, 12), _at(Vector3(0, 2.3, 0.14), Vector3.ONE,
			Vector3(0.12, 0, 0)), color)
	# Lying on a towel, face up, head towards +Z.
	var lying := Basis(Vector3.RIGHT, PI / 2)
	var towel := BoxMesh.new()
	towel.size = Vector3(0.8, 0.02, 1.9)
	match variant % 4:
		0:
			MeshKit.add(st, towel, _at(Vector3(0.9, 0.03, 0.2)), color.lightened(0.4))
			_add_person(st, Transform3D(lying, Vector3(0.9, 0.2, -0.65)), rng, false, true)
		1:
			MeshKit.add(st, towel, _at(Vector3(0.9, 0.03, 0.2)), color.lightened(0.4))
			_add_person(st, Transform3D(lying, Vector3(0.9, 0.2, -0.65)), rng, false, true)
			_add_person(st, Transform3D(Basis(Vector3.UP, 2.4), Vector3(-1.1, 0, 0.8)), rng, false, true)
		2:
			for x: float in [-0.5, 0.6]:
				_beach_chair(st, Vector3(x, 0, 0.4), color.lightened(0.2))
				_add_person(st, Transform3D(Basis(Vector3.RIGHT, PI / 2 - 0.55), Vector3(x, 0.55, -0.4)), rng,
						false, true)
		3:
			MeshKit.add(st, towel, _at(Vector3(-0.9, 0.03, 0.0)), color.lightened(0.4))
			_add_person(st, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.0, 0, 0.6)), rng, false, true)
			_add_person(st, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(1.9, 0, 0.6)), rng, false, true)
	return MeshKit.finish(st)


## A low folding beach chair, reclined, facing -Z.
static func _beach_chair(st: SurfaceTool, at: Vector3, color: Color) -> void:
	var seat := BoxMesh.new()
	seat.size = Vector3(0.55, 0.04, 0.7)
	MeshKit.add(st, seat, _at(at + Vector3(0, 0.3, -0.2)), color)
	var back := BoxMesh.new()
	back.size = Vector3(0.55, 0.04, 0.8)
	MeshKit.add(st, back, _at(at + Vector3(0, 0.55, 0.35), Vector3.ONE, Vector3(0.95, 0, 0)), color)
	for x: float in [-0.27, 0.27]:
		_bar(st, at + Vector3(x, 0, -0.5), at + Vector3(x, 0.3, -0.2), 0.02, Color("dddddd"))
		_bar(st, at + Vector3(x, 0, 0.5), at + Vector3(x, 0.6, 0.35), 0.02, Color("dddddd"))


# --- Helpers -------------------------------------------------------------------

static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


static func _at(pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> Transform3D:
	return IslandScenery._at(pos, scl, rot)
