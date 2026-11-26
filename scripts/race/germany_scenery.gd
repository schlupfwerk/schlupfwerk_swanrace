class_name GermanyScenery
extends RefCounted
## Builds the German Forest circuit around a GermanyCircuit: grassy run-off
## rising into the woods, the asphalt with white edge lines, red and white
## kerbs in the curves, guard rails, a mixed forest of pines and leafy trees,
## a grandstand full of people and bunting at the start, rolling hills and a
## little castle on a hilltop far away. Also the hay bales, the start gate and
## the animals' bodies. Decoration only: what collides lives in the course.

const GRASS := Color("5f8f3e")
const ASPHALT := Color("44474d")
const LINE := Color("eeeeea")
const KERB_RED := Color("d52b1e")
const KERB_WHITE := Color("f2f2ee")
const RAIL := Color("b9bec4")
const HAY := Color("e3c169")
const LEAFY := [Color("3f7a32"), Color("4f8a38"), Color("5a9440"), Color("356b2c")]
const CROWD := [Color("e8412c"), Color("ffd23f"), Color("2a9df4"), Color("3fbf6a"), Color("f2f2f2"),
		Color("ff8ac2"), Color("1d1d22"), Color("ff8a2a")]
const STEP := 2
const REACH := 70.0
## Curves sharper than this get kerbs (radians per meter).
const KERB_TURN := 0.008


static func build(parent: Node3D, course: GermanyCircuit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1927
	Scenery.add_environment(parent)
	var room := AlpsScenery._room(course)
	build_ground(parent, course, room, ASPHALT, GRASS)
	_build_lines_and_kerbs(parent, course)
	build_rails(parent, course)
	_build_forest(parent, course, room, rng)
	_build_hills(parent, course, rng)
	_build_grandstand(parent, course, rng)
	_build_hay(parent, course)
	AlpsScenery._build_gate(parent, course, 0.0, Color("1d1d22"))
	_build_animals(parent, course)


# --- Ground ----------------------------------------------------------------------

## Ground for any loop: `road` between the edges, `side` outside, rising gently.
static func build_ground(parent: Node3D, course: CourseTrack, room: PackedVector2Array, road: Color,
		side: Color) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.06
	var st := MeshKit.begin()
	var count := course.sample_count()
	var i := 0
	while i < count:
		var j := i + STEP
		var a := _profile(course, i, room, road, side)
		var b := _profile(course, j, room, road, side)
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
				colors[k] = (colors[k] as Color) * (0.95 + 0.07 * noise.get_noise_2d(c.x, c.z))
			IslandScenery._quad(st, corners[0], corners[1], corners[2], corners[3],
					colors[0], colors[1], colors[2], colors[3])
		i = j
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), false)
	# A meadow under everything, below the lowest point, so no gap shows.
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(4000, 4000)
	var meadow := MeshInstance3D.new()
	meadow.mesh = mesh
	meadow.material_override = Scenery.flat(side.darkened(0.1), 1.0)
	meadow.position = Vector3(0.0, -4.0, 0.0)
	meadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(meadow)


## Across the course at sample i: (lateral, height, color). Asphalt between the
## edges, grass outside rising gently towards the forest.
static func _profile(course: CourseTrack, i: int, room: PackedVector2Array, road: Color, side: Color) -> Array:
	var w := wrapi(i, 0, course.sample_count())
	var left := course.left_edge(w)
	var right := course.right_edge(w)
	var far_left := minf(-minf(REACH, 0.85 * room[w].x), left - 4.0)
	var far_right := maxf(minf(REACH, 0.85 * room[w].y), right + 4.0)
	var d := course.lengths[w]
	var laterals := [far_left, lerpf(far_left, left, 0.5), left - 1.0, left]
	for n in range(1, 4):
		laterals.append(lerpf(left, right, n / 4.0))
	laterals.append_array([right, right + 1.0, lerpf(right, far_right, 0.5), far_right])
	var profile := []
	for lateral: float in laterals:
		var outside := maxf(lateral - right, left - lateral)
		var color := road if outside <= 0.0 else side
		profile.append([lateral, course.ground_height_at(d, lateral) + 0.01, color])
	return profile


## White edge lines along the whole lap, and red and white kerbs (inside the
## edges) wherever the track curves.
static func _build_lines_and_kerbs(parent: Node3D, course: GermanyCircuit) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	var i := 0
	while i < count:
		var j := i + STEP
		for side: float in [-1.0, 1.0]:
			var edge := course.right_edge(i) if side > 0.0 else course.left_edge(i)
			_band(st, course, i, j, edge - side * 1.35, edge - side * 1.15, 0.03, LINE)
		var turn := course.turn_at(i)
		if absf(turn) > KERB_TURN:
			# The kerb goes on both sides; stripes of 2 m.
			var color := KERB_RED if (i / 2) % 2 == 0 else KERB_WHITE
			for side: float in [-1.0, 1.0]:
				var edge := course.right_edge(i) if side > 0.0 else course.left_edge(i)
				_band(st, course, i, j, edge - side * 1.1, edge, 0.04, color)
		i = j
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


static func _band(st: SurfaceTool, course: CourseTrack, i: int, j: int, from: float, to: float, lift: float,
		color: Color) -> void:
	# Always from left to right, so the quad faces up.
	var low := minf(from, to)
	var high := maxf(from, to)
	var corners: Array[Vector3] = []
	for pair: Array in [[i, low], [j, low], [j, high], [i, high]]:
		var n: int = wrapi(pair[0], 0, course.sample_count())
		var l: float = pair[1]
		corners.append(_v3(course.edge(n, l), course.ground_height_at(course.lengths[n], l) + lift))
	IslandScenery._quad(st, corners[0], corners[1], corners[2], corners[3], color, color, color, color)


static func build_rails(parent: Node3D, course: CourseTrack) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	for side: float in [-1.0, 1.0]:
		var i := 0
		while i < count:
			var j := i + 4
			var a := AlpsScenery._edge_point(course, wrapi(i, 0, count), side, 0.4)
			var b := AlpsScenery._edge_point(course, wrapi(j, 0, count), side, 0.4)
			MeshKit.add(st, MeshKit.cylinder(0.06, 0.06, 0.8, 5), _at(a + Vector3.UP * 0.4), Color("6d7177"))
			IslandScenery._quad(st, a + Vector3.UP * 0.5, b + Vector3.UP * 0.5, b + Vector3.UP * 0.78,
					a + Vector3.UP * 0.78, RAIL, RAIL, RAIL, RAIL)
			i = j
	var mat := MeshKit.vertex_color_material()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	IslandScenery._add_mesh(parent, st.commit(), mat, false)


# --- Forest, hills, castle -------------------------------------------------------

## A leafy tree (beech, oak): a trunk and a round, lumpy crown.
static func _leafy_mesh(leaves: Color) -> Mesh:
	var st := MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.3, 0.2, 4.5, 7), _at(Vector3(0, 2.25, 0)), Color("5a4632"))
	MeshKit.add(st, MeshKit.sphere(2.6, 10, 6), _at(Vector3(0, 6.2, 0), Vector3(1.0, 0.9, 1.0)), leaves)
	MeshKit.add(st, MeshKit.sphere(1.7, 9, 5), _at(Vector3(1.4, 7.0, 0.5)), leaves.lightened(0.07))
	MeshKit.add(st, MeshKit.sphere(1.6, 9, 5), _at(Vector3(-1.2, 6.8, -0.8)), leaves.darkened(0.07))
	MeshKit.add(st, MeshKit.sphere(1.4, 9, 5), _at(Vector3(0.2, 7.9, -0.3)), leaves.lightened(0.04))
	return MeshKit.finish(st)


## Thick mixed forest from a few meters past the rails out to the far ground,
## leaving the grandstand's stretch open.
static func _build_forest(parent: Node3D, course: GermanyCircuit, room: PackedVector2Array,
		rng: RandomNumberGenerator) -> void:
	var pines: Array[Transform3D] = []
	var leafy := [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D],
			[] as Array[Transform3D]]
	var count := course.sample_count()
	var i := 0
	while i < count:
		var d := course.lengths[i]
		var by_stand := absf(course.between(0.0, d)) < 70.0
		for side: float in [-1.0, 1.0]:
			if by_stand and side < 0.0:
				continue
			var edge := course.right_edge(i) if side > 0.0 else -course.left_edge(i)
			var limit := minf(REACH - 6.0, 0.8 * (room[i].y if side > 0.0 else room[i].x))
			for n in 4:
				var out := edge + rng.randf_range(7.0, 11.0) + n * rng.randf_range(6.0, 10.0)
				if out > limit:
					continue
				var lateral := out * side
				var at := d + rng.randf_range(-2.0, 2.0)
				var p := course.edge(course.index_at(at), lateral)
				var xform := IslandScenery._varied(p, course.ground_height_at(at, lateral), rng, 0.8, 1.4)
				if rng.randf() < 0.45:
					pines.append(xform)
				else:
					(leafy[rng.randi_range(0, 3)] as Array[Transform3D]).append(xform)
		i += 5
	IslandScenery._multimesh(parent, AlpsScenery._pine_mesh(false), pines, true, rng)
	for n in 4:
		IslandScenery._multimesh(parent, _leafy_mesh(LEAFY[n]), leafy[n], true, rng)


## Green rolling hills around the forest, and a small castle on one of them.
static func _build_hills(parent: Node3D, course: GermanyCircuit, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var bounds := Rect2(course.points[0], Vector2.ZERO)
	for p in course.points:
		bounds = bounds.expand(p)
	var center := bounds.get_center()
	var reach := bounds.size.length() * 0.5
	for n in 18:
		var angle := TAU * n / 18.0 + rng.randf_range(-0.1, 0.1)
		var distance := reach + rng.randf_range(260.0, 420.0)
		var spot := center + Vector2(cos(angle), sin(angle)) * distance
		var radius := rng.randf_range(160.0, 260.0)
		MeshKit.add(st, MeshKit.sphere(1.0, 12, 7), _at(Vector3(spot.x, -20.0, spot.y),
				Vector3(radius, rng.randf_range(60.0, 130.0), radius)), GRASS.darkened(rng.randf_range(0.05, 0.25)))
	# The castle: on the hill straight ahead of the start, far away.
	var ahead := course.tangent(0)
	var spot := course.points[0] + ahead * (reach + 330.0)
	var hill_top := 70.0
	MeshKit.add(st, MeshKit.sphere(1.0, 12, 7), _at(Vector3(spot.x, -10.0, spot.y), Vector3(150.0, 80.0, 150.0)),
			GRASS.darkened(0.15))
	var wall := Color("d9d2c2")
	var roof := Color("2f5f9a")
	var base := Vector3(spot.x, hill_top - 4.0, spot.y)
	var keep := BoxMesh.new()
	keep.size = Vector3(30, 16, 18)
	MeshKit.add(st, keep, _at(base + Vector3.UP * 8.0), wall)
	for corner: Vector3 in [Vector3(-16, 0, -10), Vector3(16, 0, -10), Vector3(-16, 0, 10), Vector3(16, 0, 10),
			Vector3(0, 0, 0)]:
		var tall := 30.0 if corner == Vector3.ZERO else 22.0
		MeshKit.add(st, MeshKit.cylinder(4.0, 4.0, tall, 10), _at(base + corner + Vector3.UP * tall * 0.5), wall)
		MeshKit.add(st, MeshKit.cylinder(5.0, 0.0, 10.0, 10), _at(base + corner + Vector3.UP * (tall + 5.0)), roof)
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


# --- Start: grandstand, bunting --------------------------------------------------

## A covered grandstand along the start straight (outside the left rail),
## packed with colorful spectators, and bunting strung across the track.
static func _build_grandstand(parent: Node3D, course: GermanyCircuit, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var length := 90.0
	var steps := 6
	var from := -length * 0.5
	var concrete := Color("b8b4ab")
	var d := from
	while d < length * 0.5:
		var at := fposmod(d, course.length)
		var i := course.index_at(at)
		var yaw := course.heading_at(i)
		var basis := Basis(Vector3.UP, yaw)
		var out := AlpsScenery._edge_point(course, i, -1.0, 0.0)
		var away := Vector3(-course.right(i).x, 0.0, -course.right(i).y)
		for s in steps:
			var step := BoxMesh.new()
			step.size = Vector3(1.4, 0.6 + s * 0.8, 3.1)
			var pos := out + away * (4.0 + s * 1.4) + Vector3.UP * (0.3 + s * 0.4)
			MeshKit.add(st, step, Transform3D(basis, pos), concrete)
			# Two spectators on each step of this 3 m slice.
			for k in 2:
				var person := pos + Vector3.UP * (0.3 + s * 0.4 + 0.45) \
						+ basis.z * (k - 0.5) * 1.4
				var shirt: Color = CROWD[rng.randi_range(0, CROWD.size() - 1)]
				var body := BoxMesh.new()
				body.size = Vector3(0.5, 0.7, 0.45)
				MeshKit.add(st, body, Transform3D(basis, person), shirt)
				MeshKit.add(st, MeshKit.sphere(0.17, 7, 4), _at(person + Vector3.UP * 0.55),
						RioScenery.SKIN[rng.randi_range(0, RioScenery.SKIN.size() - 1)])
		# Roof on posts.
		var roof := BoxMesh.new()
		roof.size = Vector3(10.0, 0.3, 3.1)
		MeshKit.add(st, roof, Transform3D(basis, out + away * 7.5 + Vector3.UP * 7.5), Color("2f5f9a"))
		if int(d - from) % 9 == 0:
			MeshKit.add(st, MeshKit.cylinder(0.12, 0.12, 7.5, 6), _at(out + away * 12.0 + Vector3.UP * 3.75),
					Color("6d7177"))
		d += 3.0
	# Bunting: three strings of little flags across the track near the start.
	for spot: float in [-25.0, 15.0, 55.0]:
		var i := course.index_at(fposmod(spot, course.length))
		var a := AlpsScenery._edge_point(course, i, -1.0, 1.0) + Vector3.UP * 6.0
		var b := AlpsScenery._edge_point(course, i, 1.0, 1.0) + Vector3.UP * 6.0
		for post: Vector3 in [a, b]:
			MeshKit.add(st, MeshKit.cylinder(0.1, 0.1, 6.0, 6), _at(post - Vector3.UP * 3.0), Color("6d7177"))
		var flags := 14
		for f in flags:
			var u := (f + 0.5) / flags
			var p := a.lerp(b, u) + Vector3.DOWN * (sin(u * PI) * 1.2)
			var flag := PrismMesh.new()
			flag.size = Vector3(0.6, 0.7, 0.03)
			# Hanging point down, facing the swans coming.
			MeshKit.add(st, flag, Transform3D(Basis(Vector3.UP, course.heading_at(i)) * Basis(Vector3.BACK, PI),
					p + Vector3.DOWN * 0.35), CROWD[f % 6])
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)


# --- Obstacles and animals -------------------------------------------------------

## Low, square hay bales across the track (low enough to jump), two side by
## side with string around them.
static func _build_hay(parent: Node3D, course: GermanyCircuit) -> void:
	var st := MeshKit.begin()
	for o: Dictionary in course.obstacles:
		var i := course.index_at(o.d)
		var y := course.ground_height_at(o.d, o.l)
		var basis := Basis(Vector3.UP, course.heading_at(i))
		for side: float in [-0.42, 0.42]:
			var center := _v3(o.p, y + 0.27) + basis.x * side
			var bale := BoxMesh.new()
			bale.size = Vector3(0.8, 0.54, 1.1)
			MeshKit.add(st, bale, Transform3D(basis, center), HAY)
			for k: float in [-0.25, 0.25]:
				var band := BoxMesh.new()
				band.size = Vector3(0.82, 0.56, 0.04)
				MeshKit.add(st, band, Transform3D(basis, center + basis.z * k), HAY.darkened(0.25))
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)


static func _build_animals(parent: Node3D, course: GermanyCircuit) -> void:
	var bodies := {}
	for mover in course.movers:
		if not bodies.has(mover.kind):
			bodies[mover.kind] = AlpsScenery._animal_mesh(mover.kind)
		var body := MeshInstance3D.new()
		body.mesh = bodies[mover.kind]
		body.material_override = MeshKit.vertex_color_material()
		mover.add_child(body)
		parent.add_child(mover)


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


static func _at(pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> Transform3D:
	return IslandScenery._at(pos, scl, rot)
