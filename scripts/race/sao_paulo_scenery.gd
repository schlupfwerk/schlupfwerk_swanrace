class_name SaoPauloScenery
extends RefCounted
## Builds São Paulo around a SaoPauloCircuit: a grey, drizzly sky, the wet
## avenues with lane lines and crosswalks, sidewalks with lamp posts, the
## green median with trees and the red two-way bike lane, and tall buildings
## all around (a near row facing the avenues and a big skyline behind). Also
## the puddles, the start gate, the pedestrians' bodies, and SaoPauloLife (the
## drizzle and the cyclists). Decoration only: what collides lives in the
## course (CourseRules).

const ASPHALT := Color("3a3d42")
const LINE := Color("e9e9e4")
const SIDEWALK := Color("a9a7a1")
const CURB := Color("c9c6be")
const GRASS := Color("4f7a3c")
const BIKE_LANE := Color("b5473a")
const CITY_GROUND := Color("6d6e70")
const TRUNK := Color("5a4632")
const LEAVES := [Color("3d6b2f"), Color("4a7a36"), Color("355f2a")]
const BUILDING_COLORS := [Color("b8b4ab"), Color("9ea3a8"), Color("cfc6b5"), Color("8a8f96"),
		Color("d8d2c4"), Color("7d8790"), Color("a89c8a"), Color("c4c9cc"), Color("6f7a86")]
const WINDOW := Color("2f3a46")
const UMBRELLAS := [Color("1d1d22"), Color("1d1d22"), Color("2a6fd1"), Color("e8412c"),
		Color("ffd23f"), Color("3fbf6a"), Color("8a5cf6")]
## Outer sidewalk: from the curb out to here (lateral offset, negative = outside).
const SIDEWALK_OUT := -14.0
## The near row of buildings stands this far out from the center line.
const BUILDINGS_AT := -16.0
const STEP := 2
## The ground of the course (the swans run at 0).
const ROAD_Y := 0.02


static func build(parent: Node3D, course: SaoPauloCircuit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1554
	Scenery.add_environment(parent)
	_overcast(parent)
	_build_city_ground(parent, course)
	_build_avenues(parent, course)
	_build_crosswalks(parent, course)
	_build_median(parent)
	_build_trees_and_lamps(parent, course, rng)
	_build_near_buildings(parent, course, rng)
	_build_skyline(parent, rng)
	RioScenery._build_puddles(parent, course, ROAD_Y, Color("2a2c30"))
	AlpsScenery._build_gate(parent, course, 0.0, Color("e8412c"))
	_build_people(parent, course, rng)
	var life := SaoPauloLife.new()
	parent.add_child(life)


# --- Sky and light ---------------------------------------------------------------

## A grey, cloudy sky, soft light and more haze: the typical "garoa" day.
static func _overcast(parent: Node3D) -> void:
	for child in parent.get_children():
		if child is WorldEnvironment:
			var env: Environment = (child as WorldEnvironment).environment
			var sky := env.sky.sky_material as ProceduralSkyMaterial
			sky.sky_top_color = Color("8d97a3")
			sky.sky_horizon_color = Color("c3c8cd")
			sky.ground_horizon_color = Color("b5b8bb")
			sky.ground_bottom_color = Color("6d6e70")
			sky.sun_angle_max = 0.0
			env.fog_light_color = Color("b9bec4")
			env.fog_density = 0.0045
		elif child is DirectionalLight3D:
			var sun := child as DirectionalLight3D
			sun.light_energy *= 0.55
			sun.rotation_degrees = Vector3(-60, 150, 0)


# --- Ground ----------------------------------------------------------------------

static func _build_city_ground(parent: Node3D, course: SaoPauloCircuit) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(3000, 3000)
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = Scenery.flat(CITY_GROUND, 1.0)
	ground.position = Vector3(0.0, -0.05, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ground)


## The avenues (wet asphalt, a little shiny), their lane lines, the curbs and
## the outer sidewalk.
static func _build_avenues(parent: Node3D, course: SaoPauloCircuit) -> void:
	var road := MeshKit.begin()
	var paint := MeshKit.begin()
	var walk := MeshKit.begin()
	var hw := SaoPauloCircuit.HALF_WIDTH
	var count := course.sample_count()
	var i := 0
	var dash := 0
	while i < count:
		var j := i + STEP
		_strip(road, course, i, j, -hw, hw, ROAD_Y, ASPHALT)
		# Edge lines and dashed lines between the four lanes.
		for lateral: float in [-hw + 0.35, hw - 0.35]:
			_strip(paint, course, i, j, lateral - 0.08, lateral + 0.08, ROAD_Y + 0.01, LINE)
		if dash % 4 < 2:
			for lateral: float in [-hw * 0.5, 0.0, hw * 0.5]:
				_strip(paint, course, i, j, lateral - 0.07, lateral + 0.07, ROAD_Y + 0.01, LINE)
		dash += 1
		# Curbs and sidewalk outside; the inner curb against the median.
		_strip(walk, course, i, j, -hw - 0.35, -hw, 0.15, CURB)
		_strip(walk, course, i, j, SIDEWALK_OUT, -hw - 0.35, 0.15, SIDEWALK)
		_strip(walk, course, i, j, hw, hw + 0.4, 0.15, CURB)
		i = j
	var wet := MeshKit.vertex_color_material()
	wet.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	wet.roughness = 0.3
	wet.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.generate_normals()
	IslandScenery._add_mesh(parent, road.commit(), wet, false)
	paint.generate_normals()
	IslandScenery._add_mesh(parent, paint.commit(), IslandScenery._ground_material(), false)
	walk.generate_normals()
	IslandScenery._add_mesh(parent, walk.commit(), IslandScenery._ground_material(), false)


## A flat band between two lateral offsets from sample i to sample j (wraps).
static func _strip(st: SurfaceTool, course: CourseTrack, i: int, j: int, from: float, to: float, y: float,
		color: Color) -> void:
	IslandScenery._quad(st, _v3(course.edge(i, from), y), _v3(course.edge(j, from), y),
			_v3(course.edge(j, to), y), _v3(course.edge(i, to), y), color, color, color, color)


## Zebra crossings where the pedestrians cross.
static func _build_crosswalks(parent: Node3D, course: SaoPauloCircuit) -> void:
	var st := MeshKit.begin()
	var hw := SaoPauloCircuit.HALF_WIDTH
	for avenue in 2:
		for spot: float in SaoPauloCircuit.CROSSWALKS:
			var i := course.index_at(course.avenue_distance(avenue, spot))
			var lateral := -hw + 0.8
			while lateral < hw - 0.6:
				var a := course.edge(i - 2, lateral)
				var b := course.edge(i + 2, lateral)
				var c := course.edge(i + 2, lateral + 0.5)
				var d := course.edge(i - 2, lateral + 0.5)
				IslandScenery._quad(st, _v3(a, ROAD_Y + 0.015), _v3(b, ROAD_Y + 0.015), _v3(c, ROAD_Y + 0.015),
						_v3(d, ROAD_Y + 0.015), LINE, LINE, LINE, LINE)
				lateral += 1.0
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), false)


## The green median inside the oval (a long strip with round ends) and the red
## bike lane along it, one lane each way.
static func _build_median(parent: Node3D) -> void:
	var st := MeshKit.begin()
	var half := SaoPauloCircuit.STRAIGHT * 0.5
	var r := SaoPauloCircuit.TURN_RADIUS - SaoPauloCircuit.HALF_WIDTH - 0.4
	var y := 0.15
	IslandScenery._quad(st, Vector3(-half, y, -r), Vector3(half, y, -r), Vector3(half, y, r), Vector3(-half, y, r),
			GRASS, GRASS, GRASS, GRASS)
	for end: float in [-1.0, 1.0]:
		var center := Vector3(half * end, y, 0.0)
		var steps := 16
		for n in steps:
			var a0 := -PI / 2.0 + PI * n / steps
			var a1 := -PI / 2.0 + PI * (n + 1) / steps
			var p0 := center + Vector3(cos(a0) * end * r, 0.0, sin(a0) * r)
			var p1 := center + Vector3(cos(a1) * end * r, 0.0, sin(a1) * r)
			IslandScenery._quad(st, center, p0, p1, center, GRASS, GRASS, GRASS, GRASS)
	var bike := SaoPauloCircuit.BIKE_HALF
	var by := y + 0.02
	var from := -half + 2.0
	var to := half - 2.0
	IslandScenery._quad(st, Vector3(from, by, -bike), Vector3(to, by, -bike), Vector3(to, by, bike),
			Vector3(from, by, bike), BIKE_LANE, BIKE_LANE, BIKE_LANE, BIKE_LANE)
	var ly := by + 0.01
	for z: float in [-bike + 0.15, bike - 0.15]:
		IslandScenery._quad(st, Vector3(from, ly, z - 0.07), Vector3(to, ly, z - 0.07), Vector3(to, ly, z + 0.07),
				Vector3(from, ly, z + 0.07), LINE, LINE, LINE, LINE)
	var x := from
	while x < to - 2.0:
		IslandScenery._quad(st, Vector3(x, ly, -0.06), Vector3(x + 2.0, ly, -0.06), Vector3(x + 2.0, ly, 0.06),
				Vector3(x, ly, 0.06), Color("ffd23f"), Color("ffd23f"), Color("ffd23f"), Color("ffd23f"))
		x += 4.0
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), false)


# --- Trees, lamps, buildings -----------------------------------------------------------

static func _tree_mesh(leaves: Color) -> Mesh:
	var st := MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.18, 0.13, 3.2, 7), _at(Vector3(0, 1.6, 0)), TRUNK)
	MeshKit.add(st, MeshKit.sphere(1.8, 10, 6), _at(Vector3(0, 4.2, 0), Vector3(1.0, 0.85, 1.0)), leaves)
	MeshKit.add(st, MeshKit.sphere(1.2, 9, 5), _at(Vector3(0.9, 4.9, 0.4)), leaves.lightened(0.08))
	MeshKit.add(st, MeshKit.sphere(1.1, 9, 5), _at(Vector3(-0.8, 4.7, -0.5)), leaves.darkened(0.08))
	return MeshKit.finish(st)


static func _lamp_mesh() -> Mesh:
	var st := MeshKit.begin()
	var grey := Color("4a4e54")
	MeshKit.add(st, MeshKit.cylinder(0.1, 0.07, 7.0, 6), _at(Vector3(0, 3.5, 0)), grey)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.08, 0.08, 1.6)
	MeshKit.add(st, arm, _at(Vector3(0, 6.95, -0.75)), grey)
	var head := BoxMesh.new()
	head.size = Vector3(0.35, 0.15, 0.7)
	MeshKit.add(st, head, _at(Vector3(0, 6.85, -1.4)), Color("f2efe0"))
	return MeshKit.finish(st)


## Trees along the median (both sides of the bike lane) and lamp posts on the
## outer sidewalk, leaning over the avenue.
static func _build_trees_and_lamps(parent: Node3D, course: SaoPauloCircuit, rng: RandomNumberGenerator) -> void:
	var trees := [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D]]
	var half := SaoPauloCircuit.STRAIGHT * 0.5
	var x := -half + 6.0
	while x < half - 6.0:
		for z: float in [-7.5, 7.5]:
			var p := Vector2(x + rng.randf_range(-1.0, 1.0), z + rng.randf_range(-0.8, 0.8))
			(trees[rng.randi_range(0, 2)] as Array[Transform3D]).append(
					IslandScenery._varied(p, 0.15, rng, 0.85, 1.2))
		x += rng.randf_range(11.0, 15.0)
	for n in 3:
		IslandScenery._multimesh(parent, _tree_mesh(LEAVES[n]), trees[n], true, rng)
	var lamps: Array[Transform3D] = []
	var d := 10.0
	while d < course.length:
		var i := course.index_at(d)
		var p := course.edge(i, -SaoPauloCircuit.HALF_WIDTH - 1.2)
		# The lamp's arm (-Z) points across the avenue, towards the median.
		lamps.append(IslandScenery._placed(p, 0.15, course.heading_at(i) - PI / 2.0, 1.0))
		d += 32.0
	IslandScenery._multimesh(parent, _lamp_mesh(), lamps, false, rng)


## A row of tall buildings all along the outer sidewalk, facing the avenues,
## with rows of windows, and some antennas and water tanks on the roofs.
static func _build_near_buildings(parent: Node3D, course: SaoPauloCircuit, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var d := 0.0
	while d < course.length:
		var width := rng.randf_range(14.0, 26.0)
		var i := course.index_at(d + width * 0.5)
		var height := rng.randf_range(22.0, 95.0)
		var depth := rng.randf_range(16.0, 26.0)
		var yaw := course.heading_at(i)
		var front := _v3(course.edge(i, BUILDINGS_AT), 0.0)
		var out := _outward(course, i)
		var color: Color = BUILDING_COLORS[rng.randi_range(0, BUILDING_COLORS.size() - 1)]
		_building(st, front, out, yaw, Vector3(depth, height, width), color, rng)
		d += width + rng.randf_range(0.5, 3.0)
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)


## One building: `front` is the middle of its face towards the avenue, `out`
## points away from the avenue, size = (depth, height, width).
static func _building(st: SurfaceTool, front: Vector3, out: Vector3, yaw: float, size: Vector3, color: Color,
		rng: RandomNumberGenerator) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var center := front + out * size.x * 0.5
	var box := BoxMesh.new()
	box.size = size
	MeshKit.add(st, box, Transform3D(basis, center + Vector3.UP * size.y * 0.5), color)
	# A ground floor of shops (darker glass) and window rows every 3 m.
	var face := front - out * 0.06
	var shop := BoxMesh.new()
	shop.size = Vector3(0.1, 3.0, size.z - 1.0)
	MeshKit.add(st, shop, Transform3D(basis, face + Vector3.UP * 1.8), Color("2b3138"))
	var floors := int((size.y - 6.0) / 3.0)
	for f in floors:
		var band := BoxMesh.new()
		band.size = Vector3(0.1, 1.3, size.z - 2.0)
		MeshKit.add(st, band, Transform3D(basis, face + Vector3.UP * (5.5 + f * 3.0)), WINDOW)
	var roof := center + Vector3.UP * size.y
	match rng.randi_range(0, 3):
		0:
			# Red and white antenna mast.
			for k in 6:
				MeshKit.add(st, MeshKit.cylinder(0.25, 0.2, 2.5, 6), _at(roof + Vector3.UP * (1.25 + k * 2.5)),
						Color("d52b1e") if k % 2 == 0 else Color("f2f2f2"))
		1:
			var tank := BoxMesh.new()
			tank.size = Vector3(5.0, 3.0, 5.0)
			MeshKit.add(st, tank, Transform3D(basis, roof + Vector3.UP * 1.5), color.darkened(0.15))


## Unit vector away from the avenue (towards the outside of the oval) at sample i.
static func _outward(course: CourseTrack, i: int) -> Vector3:
	var r := course.right(i)
	return Vector3(-r.x, 0.0, -r.y)


## The skyline: hundreds of buildings of all heights filling the city around,
## outside the near row, fading into the haze.
static func _build_skyline(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var half := SaoPauloCircuit.STRAIGHT * 0.5
	var inner := Vector2(half + SaoPauloCircuit.TURN_RADIUS + 50.0, SaoPauloCircuit.TURN_RADIUS + 50.0)
	var placed := 0
	var tries := 0
	while placed < 420 and tries < 4000:
		tries += 1
		var p := Vector2(rng.randf_range(-half - 650.0, half + 650.0), rng.randf_range(-650.0, 650.0))
		if absf(p.x) < inner.x and absf(p.y) < inner.y:
			continue
		var far := maxf(absf(p.x) - inner.x, absf(p.y) - inner.y)
		var height := rng.randf_range(20.0, 70.0) + rng.randf_range(0.0, 90.0) * (1.0 if rng.randf() < 0.35 else 0.2)
		height *= clampf(0.7 + far / 400.0, 0.7, 1.4)
		var size := Vector3(rng.randf_range(14.0, 30.0), height, rng.randf_range(14.0, 30.0))
		var color: Color = BUILDING_COLORS[rng.randi_range(0, BUILDING_COLORS.size() - 1)]
		var basis := Basis(Vector3.UP, rng.randf_range(-0.1, 0.1))
		var box := BoxMesh.new()
		box.size = size
		MeshKit.add(st, box, Transform3D(basis, Vector3(p.x, height * 0.5, p.y)), color)
		# Window rows on all four sides, drawn as slightly larger dark bands.
		var floors := int((height - 4.0) / 6.0)
		for f in floors:
			var band := BoxMesh.new()
			band.size = Vector3(size.x + 0.12, 1.4, size.z + 0.12)
			MeshKit.add(st, band, Transform3D(basis, Vector3(p.x, 4.5 + f * 6.0, p.y)), WINDOW)
		placed += 1
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


# --- People ----------------------------------------------------------------------

static func _build_people(parent: Node3D, course: SaoPauloCircuit, rng: RandomNumberGenerator) -> void:
	for mover in course.movers:
		var body := MeshInstance3D.new()
		body.mesh = runner_mesh(rng) if mover.kind == "runner" else pedestrian_mesh(rng)
		body.material_override = MeshKit.vertex_color_material()
		mover.add_child(body)
		parent.add_child(mover)


## A person running towards -Z: no umbrella, leaning forward in a hurry.
static func runner_mesh(rng: RandomNumberGenerator) -> Mesh:
	var st := MeshKit.begin()
	RioScenery._add_person(st, Transform3D(Basis(Vector3.RIGHT, -0.28), Vector3.ZERO), rng)
	return MeshKit.finish(st)


## A person facing -Z holding an open umbrella.
static func pedestrian_mesh(rng: RandomNumberGenerator) -> Mesh:
	var st := MeshKit.begin()
	RioScenery._add_person(st, Transform3D.IDENTITY, rng)
	var color: Color = UMBRELLAS[rng.randi_range(0, UMBRELLAS.size() - 1)]
	RioScenery._bar(st, Vector3(0.27, 1.0, -0.05), Vector3(0.15, 2.15, -0.05), 0.02, Color("333333"))
	MeshKit.add(st, MeshKit.cylinder(0.6, 0.04, 0.3, 10), _at(Vector3(0.15, 2.2, -0.05)), color)
	return MeshKit.finish(st)


# --- Helpers ---------------------------------------------------------------------

static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


static func _at(pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> Transform3D:
	return IslandScenery._at(pos, scl, rot)
