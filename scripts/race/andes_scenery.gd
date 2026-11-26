class_name AndesScenery
extends RefCounted
## Builds the Andes around an AndesCourse: a deep blue mountain sky, the
## asphalt with white edge lines and a double yellow center line, the rock
## wall and snowy slopes rising on the right up to great white peaks, the
## cliff falling on the left into a green valley with a river, another snowy
## range across the valley, condors circling, the snowballs, and the start
## and finish gates. Decoration only: what collides lives in the course.

const ASPHALT := Color("44474d")
const WHITE_LINE := Color("eeeeea")
const YELLOW_LINE := Color("f2c230")
const ROCK := Color("7a6f66")
const ROCK_DARK := Color("5e554e")
const SNOW := Color("f2f5fa")
const SNOW_SHADE := Color("d6e0ec")
const VALLEY_GREEN := Color("6f8048")
const RIVER := Color("5c8fb0")
const STEP := 2


static func build(parent: Node3D, course: AndesCourse) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1810
	Scenery.add_environment(parent)
	_clear_sky(parent, course)
	var room := AlpsScenery._room(course)
	_build_ground(parent, course, room)
	_build_lines(parent, course)
	_build_far(parent, course, rng)
	_build_condors(parent, course)
	for mover in course.movers:
		parent.add_child(mover)
	AlpsScenery._build_gate(parent, course, course.start_distance, Color("d52b1e"))
	AlpsScenery._build_gate(parent, course, course.finish_distance, Color("1d1d22"))


static func _clear_sky(parent: Node3D, course: AndesCourse) -> void:
	var last := course.sample_count() - 1
	var along := (course.points[last] - course.points[0]).normalized()
	var right := Vector2(-along.y, along.x)
	for child in parent.get_children():
		if child is WorldEnvironment:
			var env: Environment = (child as WorldEnvironment).environment
			var sky := env.sky.sky_material as ProceduralSkyMaterial
			sky.sky_top_color = Color("2f6fd0")
			sky.sky_horizon_color = Color("a9cdf0")
			# Below the horizon (past the end of the valley): a hazy blue-green.
			sky.ground_horizon_color = Color("9fb4c6")
			sky.ground_bottom_color = Color("6f8048")
			env.fog_light_color = Color("c7dcf0")
			env.fog_density = 0.0008
		elif child is DirectionalLight3D:
			# The sun over the valley on the left, high, lighting the snowy slope.
			var travel := Vector3(right.x, -0.75, right.y).normalized()
			(child as DirectionalLight3D).basis = Basis.looking_at(travel, Vector3.UP)


# --- Ground ----------------------------------------------------------------------

## Across the road at sample i: (lateral, height, color). The cliff falling on
## the left, the road, the rock wall and snowy slope rising on the right.
static func _profile(course: AndesCourse, i: int, room: PackedVector2Array) -> Array:
	var d := course.lengths[i]
	var y := course.ground_height_at(d, 0.0)
	var left := course.left_edge(i)
	var right := course.right_edge(i)
	var far_left := -minf(95.0, 0.85 * room[i].x)
	var far_right := minf(60.0, 0.85 * room[i].y)
	var points := [
		[minf(far_left, left - 12.0), AndesCourse.VALLEY + 60.0, ROCK_DARK],
		[minf(lerpf(far_left, left, 0.5), left - 6.0), y - 70.0, ROCK_DARK],
		[left - 2.5, y - 6.0, ROCK],
		[left - 1.2, y - 0.3, ROCK],
		[left, y, ASPHALT],
		[0.0, y, ASPHALT],
		[right, y, ASPHALT],
		[right + 0.4, y + 0.4, ROCK],
		[right + 1.5, y + 3.5, ROCK],
		[maxf(lerpf(right, far_right, 0.35), right + 4.0), y + 14.0, SNOW_SHADE],
		[maxf(far_right, right + 8.0), y + 45.0, SNOW],
	]
	return points


static func _build_ground(parent: Node3D, course: AndesCourse, room: PackedVector2Array) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 4
	noise.frequency = 0.05
	var st := MeshKit.begin()
	var count := course.sample_count()
	var i := 0
	while i < count - 1:
		var j := mini(i + STEP, count - 1)
		var a := _profile(course, i, room)
		var b := _profile(course, j, room)
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
				colors[k] = (colors[k] as Color) * (0.95 + 0.08 * noise.get_noise_2d(c.x, c.z))
			IslandScenery._quad(st, corners[0], corners[1], corners[2], corners[3],
					colors[0], colors[1], colors[2], colors[3])
		i = j
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), true)


## White edge lines and a double yellow line in the middle.
static func _build_lines(parent: Node3D, course: AndesCourse) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	var first := course.index_at(course.start_distance - 30.0)
	var last := course.index_at(course.finish_distance)
	var i := first
	while i < last:
		var j := mini(i + 2, last)
		for line: float in [course.left_edge(i) + 0.35, course.right_edge(i) - 0.35]:
			AlpsScenery._stripe(st, course, i, j, line, 0.12, WHITE_LINE)
		for line: float in [-0.18, 0.18]:
			AlpsScenery._stripe(st, course, i, j, line, 0.07, YELLOW_LINE)
		i = j
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


# --- Far away --------------------------------------------------------------------

## The big snowy peaks behind the slope on the right, the valley floor with a
## river far below on the left, and the other range across the valley.
static func _build_far(parent: Node3D, course: AndesCourse, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var last := course.sample_count() - 1
	var start := course.points[0]
	var along := (course.points[last] - start).normalized()
	var right := Vector2(-along.y, along.x)
	var run := start.distance_to(course.points[last])
	# Peaks on the right, a row of them close behind the slope and a taller row behind.
	for row in 2:
		var count := 14 if row == 0 else 9
		for n in count:
			var u := (n + rng.randf_range(0.0, 0.8)) / count
			var spot := start + along * lerpf(-300.0, run + 300.0, u) + right * (150.0 + row * 260.0 + rng.randf_range(0.0, 80.0))
			var top := AndesCourse.BASE + rng.randf_range(160.0, 320.0) + row * 200.0
			_peak(st, spot, AndesCourse.VALLEY, top, rng.randf_range(170.0, 260.0) + row * 90.0)
	# The valley floor and a river winding along it.
	var valley := PlaneMesh.new()
	valley.size = Vector2(8000, 8000)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = valley
	floor_mesh.material_override = Scenery.flat(VALLEY_GREEN, 1.0)
	var middle := start + along * run * 0.5
	floor_mesh.position = Vector3(middle.x, AndesCourse.VALLEY, middle.y)
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(floor_mesh)
	var steps := 60
	for n in steps:
		var u := float(n) / steps
		var a := start + along * lerpf(-800.0, run + 800.0, u) - right * (260.0 + 40.0 * sin(u * TAU * 3.0))
		var b := start + along * lerpf(-800.0, run + 800.0, u + 1.0 / steps) \
				- right * (260.0 + 40.0 * sin((u + 1.0 / steps) * TAU * 3.0))
		var mid := (a + b) * 0.5
		var water := BoxMesh.new()
		water.size = Vector3(18.0, 0.2, a.distance_to(b) + 2.0)
		MeshKit.add(st, water, Transform3D(Basis(Vector3.UP, atan2(-(b - a).x, -(b - a).y)),
				Vector3(mid.x, AndesCourse.VALLEY + 0.2, mid.y)), RIVER)
	# The other range, across the valley on the left.
	for n in 16:
		var u := (n + rng.randf_range(0.0, 0.8)) / 16.0
		var spot := start + along * lerpf(-600.0, run + 600.0, u) - right * rng.randf_range(650.0, 950.0)
		_peak(st, spot, AndesCourse.VALLEY, AndesCourse.BASE + rng.randf_range(120.0, 420.0), rng.randf_range(220.0, 340.0))
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


## A mountain: a rocky cone with a snow cap over its top half.
static func _peak(st: SurfaceTool, spot: Vector2, base_y: float, top: float, radius: float) -> void:
	var tall := top - base_y
	MeshKit.add(st, MeshKit.cylinder(radius, radius * 0.04, tall, 9),
			IslandScenery._at(Vector3(spot.x, base_y + tall * 0.5, spot.y)), ROCK)
	var cap := tall * 0.55
	MeshKit.add(st, MeshKit.cylinder(radius * 0.55 + 2.0, radius * 0.04 + 0.5, cap + 1.0, 9),
			IslandScenery._at(Vector3(spot.x, top - cap * 0.5 + 0.5, spot.y)), SNOW)


## Condors gliding in wide circles over the valley.
static func _build_condors(parent: Node3D, course: AndesCourse) -> void:
	var condors := AndesCondors.new()
	var last := course.sample_count() - 1
	var along := (course.points[last] - course.points[0]).normalized()
	var right := Vector2(-along.y, along.x)
	for k in 4:
		var spot := course.points[0] + along * (300.0 + k * 450.0) - right * 140.0
		condors.centers.append(Vector3(spot.x, AndesCourse.BASE + 30.0 + k * 20.0, spot.y))
	parent.add_child(condors)


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)
