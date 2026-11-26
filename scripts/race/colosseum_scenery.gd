class_name ColosseumScenery
extends RefCounted
## Builds the Colosseum around a ColosseumCircuit: the sand of the arena, the
## marble wall of the podium on the left (solid), the stands rising in steps
## all around, packed with spectators (ColosseumCrowd: they cheer and jump at
## every lap of the player), the arcades of the outer wall on top, and on the
## right the pit in the middle of the arena: a stone wall down to the water,
## with crocodiles swimming and snapping (ColosseumCrocs). Also the start gate.

const SAND := Color("dcc08a")
const SAND_DARK := Color("c9a86e")
const MARBLE := Color("ece5d6")
const TRAVERTINE := Color("d6c7a8")
const TRAVERTINE_DARK := Color("a99a7c")
const RED := Color("a8322a")
const WATER := Color(0.2, 0.42, 0.38, 0.92)
const STEP := 2
## The stands: rows of seats from the podium wall outwards.
const ROWS := 16
const ROW_DEPTH := 1.3
const ROW_RISE := 0.75
const PODIUM_HEIGHT := 3.2


static func build(parent: Node3D, course: ColosseumCircuit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 80
	Scenery.add_environment(parent)
	_build_arena(parent, course)
	_build_stands(parent, course)
	_build_pit(parent, course)
	_build_crowd(parent, course, rng)
	var crocs := ColosseumCrocs.new()
	crocs.inner = Vector2(ColosseumCircuit.SIZE.x - ColosseumCircuit.HALF_WIDTH,
			ColosseumCircuit.SIZE.y - ColosseumCircuit.HALF_WIDTH)
	crocs.water_y = ColosseumCircuit.GROUND - ColosseumCircuit.PIT_DEPTH + 0.6
	parent.add_child(crocs)
	AlpsScenery._build_gate(parent, course, 0.0, RED)


static func _y() -> float:
	return ColosseumCircuit.GROUND


## The sand track, with a darker groove where the swans run.
static func _build_arena(parent: Node3D, course: ColosseumCircuit) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	var hw := ColosseumCircuit.HALF_WIDTH
	var i := 0
	while i < count:
		var j := i + STEP
		var laterals := [-hw - 0.4, -hw * 0.4, hw * 0.4, hw]
		for n in laterals.size() - 1:
			var color := SAND if n != 1 else SAND_DARK
			IslandScenery._quad(st, _at_lat(course, i, laterals[n], _y()), _at_lat(course, j, laterals[n], _y()),
					_at_lat(course, j, laterals[n + 1], _y()), _at_lat(course, i, laterals[n + 1], _y()),
					color, color, color, color)
		i = j
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), false)


## The podium wall (marble with a red band), the stands in steps and the outer
## wall with three rows of arches on top.
static func _build_stands(parent: Node3D, course: ColosseumCircuit) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	var hw := ColosseumCircuit.HALF_WIDTH
	var wall := -hw - 0.4
	var i := 0
	while i < count:
		var j := i + STEP
		var y := _y()
		# Podium wall facing the arena.
		IslandScenery._quad(st, _at_lat(course, i, wall, y), _at_lat(course, j, wall, y),
				_at_lat(course, j, wall, y + PODIUM_HEIGHT), _at_lat(course, i, wall, y + PODIUM_HEIGHT),
				MARBLE, MARBLE, MARBLE, MARBLE)
		IslandScenery._quad(st, _at_lat(course, i, wall - 0.02, y + 2.2), _at_lat(course, j, wall - 0.02, y + 2.2),
				_at_lat(course, j, wall - 0.02, y + 2.6), _at_lat(course, i, wall - 0.02, y + 2.6), RED, RED, RED, RED)
		# Steps: a riser and a tread per row.
		for r in ROWS:
			var lat0 := wall - r * ROW_DEPTH
			var lat1 := lat0 - ROW_DEPTH
			var h0 := y + PODIUM_HEIGHT + r * ROW_RISE
			var h1 := h0 + ROW_RISE
			var shade := TRAVERTINE if r % 2 == 0 else TRAVERTINE.darkened(0.06)
			IslandScenery._quad(st, _at_lat(course, i, lat0, h0), _at_lat(course, j, lat0, h0),
					_at_lat(course, j, lat0, h1), _at_lat(course, i, lat0, h1), shade, shade, shade, shade)
			IslandScenery._quad(st, _at_lat(course, i, lat1, h1), _at_lat(course, j, lat1, h1),
					_at_lat(course, j, lat0, h1), _at_lat(course, i, lat0, h1), shade, shade, shade, shade)
		# The outer wall above the last row, with arches (dark openings).
		var back := wall - ROWS * ROW_DEPTH
		var top := y + PODIUM_HEIGHT + ROWS * ROW_RISE
		IslandScenery._quad(st, _at_lat(course, i, back, top), _at_lat(course, j, back, top),
				_at_lat(course, j, back, top + 14.0), _at_lat(course, i, back, top + 14.0),
				TRAVERTINE, TRAVERTINE, TRAVERTINE, TRAVERTINE)
		if (i / STEP) % 3 == 0:
			for tier in 2:
				var a0 := top + 1.5 + tier * 6.0
				IslandScenery._quad(st, _at_lat(course, i, back + 0.05, a0), _at_lat(course, j + STEP, back + 0.05, a0),
						_at_lat(course, j + STEP, back + 0.05, a0 + 4.0), _at_lat(course, i, back + 0.05, a0 + 4.0),
						TRAVERTINE_DARK, TRAVERTINE_DARK, TRAVERTINE_DARK, TRAVERTINE_DARK)
		i = j
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), true)


## The pit in the middle: a stone wall from the track's inner edge down to the
## water, and the water itself.
static func _build_pit(parent: Node3D, course: ColosseumCircuit) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	var hw := ColosseumCircuit.HALF_WIDTH
	var water_y := _y() - ColosseumCircuit.PIT_DEPTH + 0.6
	var i := 0
	while i < count:
		var j := i + STEP
		IslandScenery._quad(st, _at_lat(course, i, hw, _y()), _at_lat(course, j, hw, _y()),
				_at_lat(course, j, hw, water_y - 1.0), _at_lat(course, i, hw, water_y - 1.0),
				TRAVERTINE_DARK, TRAVERTINE_DARK, ROCK_GREEN, ROCK_GREEN)
		i = j
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), false)
	var water := MeshInstance3D.new()
	water.mesh = MeshKit.cylinder(1.0, 1.0, 0.1, 48)
	water.scale = Vector3(ColosseumCircuit.SIZE.x - hw + 0.5, 1.0, ColosseumCircuit.SIZE.y - hw + 0.5)
	water.position = Vector3(0.0, water_y, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WATER
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	water.material_override = mat
	parent.add_child(water)


const ROCK_GREEN := Color("6b7a5a")


## Spectators on every row of the stands, all around (a few empty seats).
static func _build_crowd(parent: Node3D, course: ColosseumCircuit, rng: RandomNumberGenerator) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var count := course.sample_count()
	var wall := -ColosseumCircuit.HALF_WIDTH - 0.4
	var i := 0
	while i < count:
		var yaw := course.heading_at(i) - PI / 2.0
		for r in ROWS:
			if rng.randf() < 0.15:
				continue
			var lat := wall - (r + 0.5) * ROW_DEPTH
			var p := _at_lat(course, i, lat, _y() + PODIUM_HEIGHT + (r + 1) * ROW_RISE)
			transforms.append(Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.3, 0.3))
					.scaled(Vector3.ONE * rng.randf_range(0.9, 1.1)), p))
			colors.append(RioScenery.SHIRTS[rng.randi_range(0, RioScenery.SHIRTS.size() - 1)])
		i += 1
	var crowd := ColosseumCrowd.new()
	crowd.setup(transforms, colors, rng)
	course.player_lap.connect(crowd.cheer)
	parent.add_child(crowd)


static func _at_lat(course: CourseTrack, i: int, lateral: float, y: float) -> Vector3:
	var p := course.edge(wrapi(i, 0, course.sample_count()), lateral)
	return Vector3(p.x, y, p.y)
