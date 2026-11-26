class_name TokyoScenery
extends RefCounted
## Builds the Tokyo circuit around a TokyoCircuit, inspired by an old Japanese
## town: a stone-paved street with low bamboo fences, rows of wooden houses
## with white walls and dark tiled roofs, cherry trees in bloom, stone
## lanterns, strings of red paper lanterns over the street, a tunnel of red
## torii gates, a five-story pagoda, a snowy volcano far away and, on the
## other side, the towers of the modern city. Also the barrels and the start
## gate. Decoration only: what collides lives in the course (CourseRules).

const STONE := Color("aaa69c")
const MOSS := Color("7f9a5a")
const WOOD := Color("5a3a26")
const DARK_WOOD := Color("3a2618")
const PLASTER := Color("efe9dc")
const ROOF := Color("4a4f57")
const VERMILION := Color("d9452b")
const BLACK := Color("1d1d22")
const BAMBOO := Color("b8b06a")
const BLOSSOM := [Color("f7c6d4"), Color("f2b2c6"), Color("fbd9e3")]
const LANTERN := Color("e0402c")
const REACH := 60.0
## Houses stand this far out from the edge of the street.
const HOUSE_OUT := 6.0


static func build(parent: Node3D, course: TokyoCircuit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1603
	Scenery.add_environment(parent)
	var room := AlpsScenery._room(course)
	GermanyScenery.build_ground(parent, course, room, STONE, MOSS)
	_build_fences(parent, course)
	_build_houses(parent, course, room, rng)
	_build_trees_and_lanterns(parent, course, room, rng)
	_build_torii_tunnel(parent, course)
	_build_paper_lanterns(parent, course)
	_build_far(parent, course, rng)
	_build_barrels(parent, course)
	AlpsScenery._build_gate(parent, course, 0.0, VERMILION)


# --- Street edges ---------------------------------------------------------------

## Low bamboo fences along both edges: dark posts and two bamboo rails.
static func _build_fences(parent: Node3D, course: TokyoCircuit) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	for side: float in [-1.0, 1.0]:
		var i := 0
		while i < count:
			var j := i + 3
			var a := AlpsScenery._edge_point(course, wrapi(i, 0, count), side, 0.4)
			var b := AlpsScenery._edge_point(course, wrapi(j, 0, count), side, 0.4)
			MeshKit.add(st, MeshKit.cylinder(0.07, 0.07, 0.9, 5), _at(a + Vector3.UP * 0.45), DARK_WOOD)
			for h: float in [0.4, 0.75]:
				RioScenery._bar(st, a + Vector3.UP * h, b + Vector3.UP * h, 0.045, BAMBOO)
			i = j
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


# --- Houses ----------------------------------------------------------------------

## A traditional two-story wooden town house facing -Z: white plaster walls
## framed in dark wood, sliding lattice doors, a small roof over the ground
## floor and a dark tiled gable roof with deep eaves.
static func _house_mesh(variant: int) -> Mesh:
	var st := MeshKit.begin()
	var width: float = [7.0, 8.0, 6.5, 9.0][variant]
	var depth := 8.0
	var two_floors := variant != 2
	var height := 6.2 if two_floors else 3.4
	# Walls.
	_box(st, Vector3(width, height, depth), Vector3(0, height * 0.5, 0), PLASTER)
	# Dark wood frame: corner posts and a beam between floors.
	for x: float in [-width * 0.5, width * 0.5]:
		for z: float in [-depth * 0.5, depth * 0.5]:
			_box(st, Vector3(0.3, height, 0.3), Vector3(x, height * 0.5, z), DARK_WOOD)
	_box(st, Vector3(width + 0.1, 0.3, depth + 0.1), Vector3(0, 3.2, 0), DARK_WOOD)
	# Ground floor front: sliding lattice doors.
	_box(st, Vector3(width - 0.8, 2.5, 0.12), Vector3(0, 1.35, -depth * 0.5 - 0.02), WOOD)
	for k in int(width * 2.0):
		var x := -width * 0.5 + 0.6 + k * 0.5
		if x > width * 0.5 - 0.6:
			break
		_box(st, Vector3(0.05, 2.4, 0.16), Vector3(x, 1.35, -depth * 0.5 - 0.05), DARK_WOOD)
	if two_floors:
		# The small roof over the ground floor, and upper windows.
		_slope(st, Vector3(width + 0.8, 0.18, 1.6), Vector3(0, 3.35, -depth * 0.5 - 0.6), -0.35, ROOF)
		_box(st, Vector3(width * 0.6, 1.0, 0.12), Vector3(0, 4.7, -depth * 0.5 - 0.02), DARK_WOOD)
	# Gable roof: two sloping planes and a ridge, with deep eaves.
	var span := depth * 0.5 + 1.0
	var rise := 2.2
	var pitch := atan2(rise, span)
	var plane := sqrt(span * span + rise * rise)
	for side: float in [-1.0, 1.0]:
		var center := Vector3(0, height + rise * 0.5, side * span * 0.5)
		MeshKit.add(st, _boxm(Vector3(width + 1.6, 0.22, plane)),
				Transform3D(Basis(Vector3.RIGHT, side * pitch), center), ROOF)
	_box(st, Vector3(width + 1.8, 0.35, 0.5), Vector3(0, height + rise + 0.05, 0), ROOF.darkened(0.3))
	# Gable ends (white triangles).
	var gable := PrismMesh.new()
	gable.size = Vector3(depth, rise, 0.1)
	for x: float in [-width * 0.5, width * 0.5]:
		MeshKit.add(st, gable, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(x, height + rise * 0.5, 0)), PLASTER)
	return MeshKit.finish(st)


## Houses in rows along both sides of the street, facing it, where there's
## room (not in the torii tunnel or right at the start).
static func _build_houses(parent: Node3D, course: TokyoCircuit, room: PackedVector2Array,
		rng: RandomNumberGenerator) -> void:
	var lists := [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D],
			[] as Array[Transform3D]]
	var torii_from := course.length * TokyoCircuit.TORII_FROM
	for side: float in [-1.0, 1.0]:
		var d := 0.0
		while d < course.length:
			var variant := rng.randi_range(0, 3)
			var step: float = [7.0, 8.0, 6.5, 9.0][variant] + rng.randf_range(0.4, 1.5)
			var i := course.index_at(d)
			var edge := course.right_edge(i) if side > 0.0 else -course.left_edge(i)
			var limit := 0.8 * (room[i].y if side > 0.0 else room[i].x)
			var out := edge + HOUSE_OUT
			var skip := out + 8.0 > limit or absf(course.between(0.0, d)) < 25.0 \
					or (d > torii_from - 5.0 and d < torii_from + TokyoCircuit.TORII_LENGTH + 5.0)
			if not skip:
				var p := course.edge(i, out * side)
				# The front (-Z) faces the street.
				var toward := course.right(i) * -side
				var yaw := atan2(-toward.x, -toward.y)
				var y := course.ground_height_at(d, out * side) - 0.2
				(lists[variant] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, yaw),
						Vector3(p.x, y, p.y) + Vector3(-toward.x, 0, -toward.y) * 4.0))
			d += step
	for n in 4:
		IslandScenery._multimesh(parent, _house_mesh(n), lists[n], true, rng)


# --- Trees, lanterns -------------------------------------------------------------

static func _cherry_mesh(blossom: Color) -> Mesh:
	var st := MeshKit.begin()
	RioScenery._bar(st, Vector3.ZERO, Vector3(0.3, 2.2, 0.1), 0.2, Color("4a3428"))
	RioScenery._bar(st, Vector3(0.3, 2.2, 0.1), Vector3(-0.8, 3.4, 0.3), 0.12, Color("4a3428"))
	RioScenery._bar(st, Vector3(0.3, 2.2, 0.1), Vector3(1.3, 3.3, -0.2), 0.12, Color("4a3428"))
	for spot: Vector3 in [Vector3(-0.9, 3.8, 0.3), Vector3(1.3, 3.7, -0.2), Vector3(0.2, 4.3, 0.0),
			Vector3(0.4, 3.6, 1.0), Vector3(-0.2, 3.7, -1.0)]:
		MeshKit.add(st, MeshKit.sphere(1.3, 9, 5), _at(spot, Vector3(1.0, 0.75, 1.0)), blossom)
	return MeshKit.finish(st)


static func _stone_lantern_mesh() -> Mesh:
	var st := MeshKit.begin()
	var grey := Color("9c988f")
	MeshKit.add(st, MeshKit.cylinder(0.35, 0.4, 0.25, 8), _at(Vector3(0, 0.12, 0)), grey)
	MeshKit.add(st, MeshKit.cylinder(0.12, 0.12, 0.8, 8), _at(Vector3(0, 0.65, 0)), grey)
	_box(st, Vector3(0.55, 0.45, 0.55), Vector3(0, 1.28, 0), grey)
	_box(st, Vector3(0.3, 0.25, 0.6), Vector3(0, 1.3, 0), Color("ffd98a"))
	MeshKit.add(st, MeshKit.cylinder(0.55, 0.05, 0.4, 6), _at(Vector3(0, 1.7, 0)), grey)
	return MeshKit.finish(st)


## Cherry trees between the fence and the houses, and stone lanterns by the fence.
static func _build_trees_and_lanterns(parent: Node3D, course: TokyoCircuit, room: PackedVector2Array,
		rng: RandomNumberGenerator) -> void:
	var cherries := [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D]]
	var lanterns: Array[Transform3D] = []
	var d := 5.0
	while d < course.length:
		var i := course.index_at(d)
		for side: float in [-1.0, 1.0]:
			var edge := course.right_edge(i) if side > 0.0 else -course.left_edge(i)
			if rng.randf() < 0.55:
				var lateral := (edge + rng.randf_range(2.2, 3.5)) * side
				var p := course.edge(i, lateral)
				(cherries[rng.randi_range(0, 2)] as Array[Transform3D]).append(
						IslandScenery._varied(p, course.ground_height_at(d, lateral), rng, 0.8, 1.15))
			# Far out where there's room, more cherries in little groves.
			var limit := 0.8 * (room[i].y if side > 0.0 else room[i].x)
			if limit > edge + 25.0 and rng.randf() < 0.5:
				var lateral := (edge + rng.randf_range(16.0, minf(limit, REACH) - 4.0)) * side
				var p := course.edge(i, lateral)
				(cherries[rng.randi_range(0, 2)] as Array[Transform3D]).append(
						IslandScenery._varied(p, course.ground_height_at(d, lateral), rng, 0.9, 1.3))
		if int(d) % 3 == 0:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var edge := course.right_edge(i) if side > 0.0 else -course.left_edge(i)
			var p := course.edge(i, (edge + 1.3) * side)
			lanterns.append(IslandScenery._placed(p, course.ground_height_at(d, (edge + 1.3) * side),
					rng.randf() * TAU, 1.0))
		d += rng.randf_range(7.0, 11.0)
	for n in 3:
		IslandScenery._multimesh(parent, _cherry_mesh(BLOSSOM[n]), cherries[n], false, rng)
	IslandScenery._multimesh(parent, _stone_lantern_mesh(), lanterns, false, rng)


## A tunnel of red torii gates over the street, one every 3.5 m.
static func _build_torii_tunnel(parent: Node3D, course: TokyoCircuit) -> void:
	var st := MeshKit.begin()
	var from := course.length * TokyoCircuit.TORII_FROM
	var d := from
	while d < from + TokyoCircuit.TORII_LENGTH:
		var i := course.index_at(d)
		var a := AlpsScenery._edge_point(course, i, -1.0, 0.9)
		var b := AlpsScenery._edge_point(course, i, 1.0, 0.9)
		var base_y := maxf(a.y, b.y)
		var tall := 5.2
		for post: Vector3 in [a, b]:
			MeshKit.add(st, MeshKit.cylinder(0.25, 0.22, tall + base_y - post.y, 10),
					_at(Vector3(post.x, (post.y + base_y + tall) * 0.5, post.z)), VERMILION)
			MeshKit.add(st, MeshKit.cylinder(0.3, 0.3, 0.35, 10), _at(post + Vector3.UP * 0.17), BLACK)
		var mid := (a + b) * 0.5
		var yaw := course.heading_at(i)
		var across := a.distance_to(b)
		var basis := Basis(Vector3.UP, yaw)
		# Nuki (tie beam) and kasagi (top beam, black on top, red under it).
		MeshKit.add(st, _boxm(Vector3(across + 0.6, 0.3, 0.3)), Transform3D(basis, Vector3(mid.x, base_y + tall - 1.0,
				mid.z)), VERMILION)
		MeshKit.add(st, _boxm(Vector3(across + 2.0, 0.35, 0.5)), Transform3D(basis, Vector3(mid.x, base_y + tall + 0.15,
				mid.z)), VERMILION)
		MeshKit.add(st, _boxm(Vector3(across + 2.4, 0.25, 0.6)), Transform3D(basis, Vector3(mid.x, base_y + tall + 0.45,
				mid.z)), BLACK)
		d += 3.5
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)


## Strings of round red paper lanterns across the street at a few places.
static func _build_paper_lanterns(parent: Node3D, course: TokyoCircuit) -> void:
	var st := MeshKit.begin()
	for spot: float in [60.0, 0.22, 0.38, 0.8, 0.92]:
		var d := spot if spot > 1.0 else course.length * spot
		var i := course.index_at(d)
		var a := AlpsScenery._edge_point(course, i, -1.0, 1.4) + Vector3.UP * 5.5
		var b := AlpsScenery._edge_point(course, i, 1.0, 1.4) + Vector3.UP * 5.5
		for post: Vector3 in [a, b]:
			MeshKit.add(st, MeshKit.cylinder(0.1, 0.1, 5.5, 6), _at(post - Vector3.UP * 2.75), DARK_WOOD)
		for k in 7:
			var u := (k + 0.5) / 7.0
			var p := a.lerp(b, u) + Vector3.DOWN * (sin(u * PI) * 0.9 + 0.5)
			MeshKit.add(st, MeshKit.sphere(0.32, 10, 6), _at(p, Vector3(1.0, 1.25, 1.0)), LANTERN)
			MeshKit.add(st, MeshKit.cylinder(0.16, 0.16, 0.08, 8), _at(p + Vector3.UP * 0.42), BLACK)
			MeshKit.add(st, MeshKit.cylinder(0.16, 0.16, 0.08, 8), _at(p - Vector3.UP * 0.42), BLACK)
	var mat_glow := MeshKit.vertex_color_material()
	mat_glow.emission_enabled = true
	mat_glow.emission = Color(0.35, 0.08, 0.04)
	IslandScenery._add_mesh(parent, st.commit(), mat_glow, false)


# --- Far away --------------------------------------------------------------------

## A big snowy volcano on one side, a five-story pagoda near the street, and
## the towers of the modern city on the other side.
static func _build_far(parent: Node3D, course: TokyoCircuit, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var bounds := Rect2(course.points[0], Vector2.ZERO)
	for p in course.points:
		bounds = bounds.expand(p)
	var center := bounds.get_center()
	var reach := bounds.size.length() * 0.5
	# The volcano, ahead of the start line.
	var ahead := course.tangent(0)
	var peak := center + ahead * (reach + 1300.0)
	MeshKit.add(st, MeshKit.cylinder(900.0, 90.0, 520.0, 24), _at(Vector3(peak.x, 250.0, peak.y)), Color("5f6f8a"))
	MeshKit.add(st, MeshKit.cylinder(270.0, 90.0, 140.0, 24), _at(Vector3(peak.x, 451.0, peak.y)), Color("f4f6fa"))
	# Green hills around the town.
	for n in 14:
		var angle := TAU * n / 14.0
		var spot := center + Vector2(cos(angle), sin(angle)) * (reach + rng.randf_range(220.0, 360.0))
		var radius := rng.randf_range(120.0, 200.0)
		MeshKit.add(st, MeshKit.sphere(1.0, 12, 7), _at(Vector3(spot.x, -15.0, spot.y),
				Vector3(radius, rng.randf_range(50.0, 90.0), radius)), MOSS.darkened(rng.randf_range(0.1, 0.25)))
	# The modern city behind the start, far away: glassy towers.
	for n in 40:
		var spot := center - ahead * (reach + rng.randf_range(260.0, 520.0)) \
				+ Vector2(-ahead.y, ahead.x) * rng.randf_range(-380.0, 380.0)
		var height := rng.randf_range(60.0, 210.0)
		var size := Vector3(rng.randf_range(20.0, 40.0), height, rng.randf_range(20.0, 40.0))
		var tone: Color = [Color("8fa3b8"), Color("a9b4bf"), Color("7d8ea3"), Color("c4ccd4")][n % 4]
		_box(st, size, Vector3(spot.x, height * 0.5, spot.y), tone)
	# The pagoda: just outside the houses, by the first curve.
	var at := course.length * 0.12
	var i := course.index_at(at)
	var side := 1.0 if course.turn_at(i) < 0.0 else -1.0
	var edge := course.right_edge(i) if side > 0.0 else -course.left_edge(i)
	var p := course.edge(i, (edge + 28.0) * side)
	var base := Vector3(p.x, course.ground_height_at(at, (edge + 28.0) * side) - 0.3, p.y)
	var y := 0.0
	for level in 5:
		var w := 8.0 - level * 1.1
		_box(st, Vector3(w, 3.0, w), base + Vector3.UP * (y + 1.5), VERMILION.darkened(0.15))
		_box(st, Vector3(w + 3.4, 0.4, w + 3.4), base + Vector3.UP * (y + 3.2), ROOF)
		MeshKit.add(st, MeshKit.cylinder((w + 3.4) * 0.72, (w - 0.5) * 0.6, 0.7, 4),
				Transform3D(Basis(Vector3.UP, PI / 4), base + Vector3.UP * (y + 3.7)), ROOF)
		y += 3.9
	MeshKit.add(st, MeshKit.cylinder(0.2, 0.08, 6.0, 6), _at(base + Vector3.UP * (y + 3.0)), Color("c9a34a"))
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


# --- Obstacles -------------------------------------------------------------------

## Sake barrels wrapped in straw with a colored label (low: jump them).
static func _build_barrels(parent: Node3D, course: TokyoCircuit) -> void:
	var st := MeshKit.begin()
	var labels := [VERMILION, Color("2a6fd1"), BLACK, Color("3fbf6a")]
	var n := 0
	for o: Dictionary in course.obstacles:
		var y := course.ground_height_at(o.d, o.l)
		var center := Vector3(o.p.x, y, o.p.y)
		MeshKit.add(st, MeshKit.cylinder(0.5, 0.5, 0.58, 14), _at(center + Vector3.UP * 0.29), Color("e8dcb8"))
		MeshKit.add(st, MeshKit.cylinder(0.51, 0.51, 0.25, 14), _at(center + Vector3.UP * 0.32), labels[n % 4])
		for h: float in [0.06, 0.55]:
			MeshKit.add(st, MeshKit.cylinder(0.52, 0.52, 0.05, 14), _at(center + Vector3.UP * h), WOOD)
		n += 1
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)


# --- Helpers ---------------------------------------------------------------------

static func _boxm(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


static func _box(st: SurfaceTool, size: Vector3, center: Vector3, color: Color) -> void:
	MeshKit.add(st, _boxm(size), Transform3D(Basis.IDENTITY, center), color)


## A thin board tilted down towards -Z (a small roof over a door).
static func _slope(st: SurfaceTool, size: Vector3, center: Vector3, tilt: float, color: Color) -> void:
	MeshKit.add(st, _boxm(size), Transform3D(Basis(Vector3.RIGHT, tilt), center), color)


static func _at(pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> Transform3D:
	return IslandScenery._at(pos, scl, rot)
