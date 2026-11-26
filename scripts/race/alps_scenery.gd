class_name AlpsScenery
extends RefCounted
## Builds the Swiss Alps around an AlpsCourse: the snowy slope with fences,
## pines and rocks, the alpine road with guard rails, lines and pine forest,
## mountains all around, the start and finish gates, logs and the animals'
## bodies. Along parts of the road the forest opens into pastures with cows
## grazing, which moo as the player goes by (ProximitySound). Decoration only: what
## collides lives in the course (CourseRules).

## Open pastures along the road, no trees: [from, to] in meters into the road.
const PASTURES := [[130.0, 300.0], [540.0, 690.0]]
const SNOW := Color("f1f5fa")
const SNOW_SHADE := Color("d9e3ee")
const ASPHALT := Color("4b4e54")
const GRAVEL := Color("9a9183")
const GRASS := Color("5d8c3a")
const MEADOW := Color("6f9a45")
const ROCK := Color("7d7a76")
const TRUNK := Color("5a3d26")
const PINE_GREENS := [Color("1f4a2c"), Color("27563a"), Color("2f5f33"), Color("214d34")]
const FENCE := Color("ff7a1a")
const RAIL := Color("b9bec4")
## Ground strip: samples skipped between rows (meters), and how far it reaches
## beyond the edges of the course.
const STEP := 2
const REACH := 70.0


static func build(parent: Node3D, course: AlpsCourse) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	Scenery.add_environment(parent)
	var room := _room(course)
	_build_ground(parent, course, room)
	_build_valley(parent, course)
	_build_mountains(parent, course, rng)
	_build_fences(parent, course)
	_build_rails(parent, course)
	_build_road_lines(parent, course)
	_build_forest(parent, course, room, rng)
	_build_pastures(parent, course, room, rng)
	_build_obstacles(parent, course, rng)
	_build_logs(parent, course)
	_build_gate(parent, course, course.start_distance, Color("d52b1e"))
	_build_gate(parent, course, course.finish_distance, Color("1d1d22"))
	_build_chalets(parent, course, rng)
	_build_animals(parent, course)


# --- Ground ----------------------------------------------------------------------

## How far the ground may reach to each side at each sample before a tight
## curve folds it over itself: (left room, right room), in meters.
static func _room(course: CourseTrack) -> PackedVector2Array:
	var count := course.sample_count()
	var radius := PackedVector2Array()
	for i in count:
		var turn := course.tangent(i - 2).angle_to(course.tangent(i + 2))
		var r := 4.0 * CourseTrack.SPACING / maxf(absf(turn), 0.0001)
		# Turning right folds the right side; turning left folds the left side.
		radius.append(Vector2(r if turn < 0.0 else INF, r if turn > 0.0 else INF))
	var room := PackedVector2Array()
	for i in count:
		var left := INF
		var right := INF
		for k in range(-12, 13):
			var n := clampi(i + k, 0, count - 1)
			left = minf(left, radius[n].x)
			right = minf(right, radius[n].y)
		room.append(Vector2(minf(left, 400.0), minf(right, 400.0)))
	return room


## Lateral offsets and colors across the course at sample i (always the same
## number of points, so rows stitch together). Snow on the slope; on the road:
## grass, gravel shoulder, asphalt.
static func _profile(course: AlpsCourse, i: int, room: PackedVector2Array) -> Array:
	var left := course.left_edge(i)
	var right := course.right_edge(i)
	var far_left := -minf(REACH, 0.85 * room[i].x)
	var far_right := minf(REACH, 0.85 * room[i].y)
	far_left = minf(far_left, left - 4.0)
	far_right = maxf(far_right, right + 4.0)
	var d := course.lengths[i]
	var snow := course.terrain(d) == CourseTrack.Terrain.SNOW
	var laterals := [far_left, lerpf(far_left, left, 0.5), left - 1.5, left]
	for n in range(1, 6):
		laterals.append(lerpf(left, right, n / 6.0))
	laterals.append_array([right, right + 1.5, lerpf(right, far_right, 0.5), far_right])
	var profile := []
	for n in laterals.size():
		var lateral: float = laterals[n]
		var outside := maxf(lateral - right, left - lateral)
		var color := SNOW
		if not snow:
			if outside > 1.4:
				color = GRASS
			elif outside > 0.0:
				color = GRAVEL
			else:
				color = ASPHALT
		elif outside > 0.0:
			color = SNOW_SHADE
		# Valley walls: past the edges the ground rises, more on the slope.
		var rise := maxf(outside - 6.0, 0.0) * (0.45 if snow else 0.2)
		var height := course.ground_height_at(d, lateral) + rise
		profile.append([lateral, height, color])
	return profile


static func _build_ground(parent: Node3D, course: AlpsCourse, room: PackedVector2Array) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.06
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
				colors[k] = (colors[k] as Color) * (0.95 + 0.07 * noise.get_noise_2d(c.x, c.z))
			_quad(st, corners[0], corners[1], corners[2], corners[3],
					colors[0], colors[1], colors[2], colors[3])
		i = j
	st.generate_normals()
	_add_mesh(parent, st.commit(), _ground_material(), false)


## A wide meadow under everything, at the valley floor, so no gap shows
## between the course and the mountains.
static func _build_valley(parent: Node3D, course: AlpsCourse) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(4000, 4000)
	var meadow := MeshInstance3D.new()
	meadow.mesh = mesh
	meadow.material_override = Scenery.flat(MEADOW, 1.0)
	var middle := course.points[course.sample_count() / 2]
	meadow.position = Vector3(middle.x, AlpsCourse.TOP_HEIGHT - AlpsCourse.DROP - 12.0, middle.y)
	meadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(meadow)


## Big snowy peaks all around, far away.
static func _build_mountains(parent: Node3D, course: AlpsCourse, rng: RandomNumberGenerator) -> void:
	var bounds := Rect2(course.points[0], Vector2.ZERO)
	for p in course.points:
		bounds = bounds.expand(p)
	var center := bounds.get_center()
	# On an ellipse around the course, well clear of it.
	var half := bounds.size * 0.5 + Vector2(520.0, 520.0)
	var base_y := AlpsCourse.TOP_HEIGHT - AlpsCourse.DROP - 3.0
	var st := MeshKit.begin()
	for n in 22:
		var angle := TAU * n / 22.0 + rng.randf_range(-0.1, 0.1)
		var spot := center + Vector2(cos(angle) * half.x, sin(angle) * half.y) * rng.randf_range(1.0, 1.3)
		var height := rng.randf_range(260.0, 480.0)
		var width := height * rng.randf_range(0.6, 0.9)
		var base := Vector3(spot.x, base_y, spot.y)
		MeshKit.add(st, MeshKit.cylinder(width, 0.0, height, 9),
				Transform3D(Basis(Vector3.UP, rng.randf() * TAU), base + Vector3.UP * height * 0.5), ROCK)
		# Snow cap: the top third.
		var cap := height * 0.38
		MeshKit.add(st, MeshKit.cylinder(width * 0.38 * 1.02, 0.0, cap, 9),
				Transform3D(Basis(Vector3.UP, rng.randf() * TAU), base + Vector3.UP * (height - cap * 0.5)),
				SNOW)
	# The mountain the slope comes down: a big peak right behind the start.
	var top := course.points[0] - course.tangent(0) * 420.0
	MeshKit.add(st, MeshKit.cylinder(300.0, 0.0, 420.0, 10),
			_at(Vector3(top.x, base_y + 210.0, top.y)), ROCK)
	MeshKit.add(st, MeshKit.cylinder(150.0, 0.0, 200.0, 10),
			_at(Vector3(top.x, base_y + 320.0, top.y)), SNOW)
	_add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


# --- Fences, rails and lines ----------------------------------------------------

## Orange safety nets along both sides of the ski slope.
static func _build_fences(parent: Node3D, course: AlpsCourse) -> void:
	var st := MeshKit.begin()
	var last := course.index_at(AlpsCourse.SNOW_END)
	for side: float in [-1.0, 1.0]:
		var i := course.index_at(course.start_distance + 6.0)
		while i < last:
			var j := mini(i + 4, last)
			var a := _edge_point(course, i, side, 0.3)
			var b := _edge_point(course, j, side, 0.3)
			MeshKit.add(st, MeshKit.cylinder(0.05, 0.05, 1.3, 5), _at(a + Vector3.UP * 0.65), Color("e8e2d6"))
			# The net: a band between posts.
			var up := Vector3.UP * 1.1
			_quad(st, a + Vector3.UP * 0.2, b + Vector3.UP * 0.2, b + up, a + up,
					FENCE, FENCE, FENCE, FENCE)
			i = j
	var mat := MeshKit.vertex_color_material()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(parent, st.commit(), mat, false)


## Guard rails along both sides of the road: posts and a metal band.
static func _build_rails(parent: Node3D, course: AlpsCourse) -> void:
	var st := MeshKit.begin()
	var first := course.index_at(AlpsCourse.ROAD_START - 10.0)
	var last := course.index_at(course.finish_distance - 3.0)
	for side: float in [-1.0, 1.0]:
		var i := first
		while i < last:
			var j := mini(i + 4, last)
			var a := _edge_point(course, i, side, 0.4)
			var b := _edge_point(course, j, side, 0.4)
			MeshKit.add(st, MeshKit.cylinder(0.06, 0.06, 0.8, 5), _at(a + Vector3.UP * 0.4), Color("6d7177"))
			_quad(st, a + Vector3.UP * 0.5, b + Vector3.UP * 0.5, b + Vector3.UP * 0.78,
					a + Vector3.UP * 0.78, RAIL, RAIL, RAIL, RAIL)
			i = j
	var mat := MeshKit.vertex_color_material()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(parent, st.commit(), mat, false)


## A dashed white line in the middle of the road and solid lines at its edges.
static func _build_road_lines(parent: Node3D, course: AlpsCourse) -> void:
	var st := MeshKit.begin()
	var first := course.index_at(AlpsCourse.ROAD_START)
	var last := course.index_at(course.finish_distance)
	var white := Color("eeeeea")
	var i := first
	while i < last:
		var j := mini(i + 2, last)
		for line: float in [course.left_edge(i) + 0.35, course.right_edge(i) - 0.35]:
			_stripe(st, course, i, j, line, 0.15, white)
		# Dashes: 3 m painted, 3 m gap.
		if (i / 3) % 2 == 0:
			_stripe(st, course, i, j, 0.0, 0.14, white)
		i = j
	_add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


static func _stripe(st: SurfaceTool, course: CourseTrack, i: int, j: int, lateral: float,
		width: float, color: Color) -> void:
	var lift := 0.03
	var corners: Array[Vector3] = []
	for pair: Array in [[i, lateral - width], [j, lateral - width], [j, lateral + width],
			[i, lateral + width]]:
		var n: int = pair[0]
		var l: float = pair[1]
		corners.append(_v3(course.edge(n, l), course.ground_height_at(course.lengths[n], l) + lift))
	_quad(st, corners[0], corners[1], corners[2], corners[3], color, color, color, color)


## A point just outside the left (side -1) or right (side 1) edge, on the ground.
static func _edge_point(course: CourseTrack, i: int, side: float, out: float) -> Vector3:
	var lateral := (course.right_edge(i) if side > 0.0 else course.left_edge(i)) + out * side
	return _v3(course.edge(i, lateral), course.ground_height_at(course.lengths[i], lateral))


# --- Pines, rocks, logs --------------------------------------------------------

## A pine: a trunk and four stacked cones, darker at the bottom.
static func _pine_mesh(snowy: bool) -> Mesh:
	var st := MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.22, 0.16, 2.0, 6), _at(Vector3(0, 1.0, 0)), TRUNK)
	for n in 4:
		var r := 1.9 - n * 0.42
		var y := 1.6 + n * 1.25
		var green: Color = PINE_GREENS[n % PINE_GREENS.size()]
		MeshKit.add(st, MeshKit.cylinder(r, 0.0, 2.2, 8), _at(Vector3(0, y + 1.1, 0)), green)
		if snowy:
			MeshKit.add(st, MeshKit.cylinder(r * 0.55, 0.0, 0.9, 8), _at(Vector3(0, y + 1.75, 0)), SNOW)
	return MeshKit.finish(st)


static func _rock_mesh(snowy: bool) -> Mesh:
	var st := MeshKit.begin()
	MeshKit.add(st, MeshKit.sphere(1.0, 9, 5), _at(Vector3(0, 0.35, 0), Vector3(1.2, 0.75, 1.0)), ROCK)
	MeshKit.add(st, MeshKit.sphere(0.6, 8, 4), _at(Vector3(0.5, 0.25, 0.4), Vector3(1.0, 0.8, 1.1)),
			ROCK.darkened(0.1))
	if snowy:
		MeshKit.add(st, MeshKit.sphere(0.85, 9, 4), _at(Vector3(0, 0.62, 0), Vector3(1.1, 0.35, 0.9)), SNOW)
	return MeshKit.finish(st)


## Pine forest on both sides: thick along the road, in clumps beside the slope.
static func _build_forest(parent: Node3D, course: AlpsCourse, room: PackedVector2Array,
		rng: RandomNumberGenerator) -> void:
	var road: Array[Transform3D] = []
	var slope: Array[Transform3D] = []
	var count := course.sample_count()
	var i := 0
	while i < count:
		var d := course.lengths[i]
		var snow := course.terrain(d) == CourseTrack.Terrain.SNOW
		if _in_pasture(d):
			i += 4
			continue
		for side: float in [-1.0, 1.0]:
			var edge := course.right_edge(i) if side > 0.0 else -course.left_edge(i)
			var limit := minf(REACH - 6.0, 0.8 * (room[i].y if side > 0.0 else room[i].x))
			var rows := 2 if snow else 4
			for n in rows:
				var out := edge + rng.randf_range(3.0, 7.0) + n * rng.randf_range(5.0, 9.0)
				if out > limit:
					continue
				var lateral := out * side
				var at := d + rng.randf_range(-1.5, 1.5)
				var p := course.edge(course.index_at(at), lateral)
				var y := _ground_y(course, at, lateral)
				var xform := _varied(p, y, rng, 0.8, 1.5)
				(slope if snow else road).append(xform)
		i += 3 if snow else 4
	_multimesh(parent, _pine_mesh(false), road, true, rng)
	_multimesh(parent, _pine_mesh(true), slope, true, rng)


## True on the road where the forest opens into a pasture (a little margin
## at each end so the trees thin out rather than stop at a line).
static func _in_pasture(d: float) -> bool:
	for pasture: Array in PASTURES:
		var from: float = AlpsCourse.ROAD_START + pasture[0]
		var to: float = AlpsCourse.ROAD_START + pasture[1]
		if d > from and d < to:
			return true
	return false


## Cows grazing in the pastures, on both sides of the road, and the node that
## makes them moo when the player goes by.
static func _build_pastures(parent: Node3D, course: AlpsCourse, room: PackedVector2Array,
		rng: RandomNumberGenerator) -> void:
	var cows: Array[Transform3D] = []
	var herds := PackedVector3Array()
	for pasture: Array in PASTURES:
		for side: float in [-1.0, 1.0]:
			var middle: float = AlpsCourse.ROAD_START + (pasture[0] + pasture[1]) * 0.5 + rng.randf_range(-30.0, 30.0)
			var count := rng.randi_range(4, 6)
			for n in count:
				var at: float = middle + rng.randf_range(-35.0, 35.0)
				var i := course.index_at(at)
				var edge := course.right_edge(i) if side > 0.0 else -course.left_edge(i)
				var limit := minf(REACH - 8.0, 0.8 * (room[i].y if side > 0.0 else room[i].x))
				var out := minf(edge + rng.randf_range(8.0, 30.0), limit)
				var lateral := out * side
				var p := course.edge(i, lateral)
				cows.append(_placed(p, _ground_y(course, at, lateral), rng.randf() * TAU, rng.randf_range(0.9, 1.1)))
			var mi := course.index_at(middle)
			var herd_lateral := ((course.right_edge(mi) if side > 0.0 else -course.left_edge(mi)) + 16.0) * side
			var spot := course.edge(mi, herd_lateral)
			herds.append(Vector3(spot.x, _ground_y(course, middle, herd_lateral) + 1.0, spot.y))
	_multimesh(parent, _animal_mesh("cow"), cows, false, rng)
	var mooing := ProximitySound.new()
	mooing.spots = herds
	mooing.stream = Sfx.moo()
	parent.add_child(mooing)


## Height of the drawn ground (with the valley walls) at a place.
static func _ground_y(course: AlpsCourse, d: float, lateral: float) -> float:
	var i := course.index_at(d)
	var outside := maxf(lateral - course.right_edge(i), course.left_edge(i) - lateral)
	var snow := course.terrain(d) == CourseTrack.Terrain.SNOW
	return course.ground_height_at(d, lateral) + maxf(outside - 6.0, 0.0) * (0.45 if snow else 0.2)


## The pines and rocks on the slope that swans must dodge (course obstacles).
static func _build_obstacles(parent: Node3D, course: AlpsCourse, rng: RandomNumberGenerator) -> void:
	var pines: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	for o: Dictionary in course.obstacles:
		if course.terrain(o.d) != CourseTrack.Terrain.SNOW:
			continue
		var y := course.ground_height_at(o.d, o.l)
		var yaw := rng.randf() * TAU
		if o.h > 10.0:
			pines.append(_placed(o.p, y, yaw, rng.randf_range(1.0, 1.25)))
		else:
			rocks.append(_placed(o.p, y - 0.1, yaw, o.r * 0.95))
	# These matter for the race: always drawn (not scenery detail).
	for entry: Array in [[_pine_mesh(true), pines], [_rock_mesh(true), rocks]]:
		var list: Array[Transform3D] = entry[1]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = entry[0]
		mm.instance_count = list.size()
		for n in list.size():
			mm.set_instance_transform(n, list[n])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mm
		instance.material_override = MeshKit.vertex_color_material()
		parent.add_child(instance)


## Logs across the road, with a red flag at each end (like on the island).
static func _build_logs(parent: Node3D, course: CourseTrack) -> void:
	var bark := MeshKit.vertex_color_material()
	var radius := 0.38
	for log: Dictionary in course.logs:
		var i := course.index_at(log.distance)
		var r2 := course.right(i)
		var t2 := course.tangent(i)
		var across := Vector3(r2.x, 0, r2.y)
		var forward := Vector3(t2.x, 0, t2.y)
		var length: float = log.length
		var ground := course.ground_height_at(log.distance, log.lateral)
		var center := _v3(course.edge(i, log.lateral), ground + radius)
		var basis := Basis(forward, across, forward.cross(across))
		var st := MeshKit.begin()
		MeshKit.add(st, MeshKit.cylinder(radius, radius * 0.92, length, 12),
				Transform3D(basis, center), Color("5e3d22"))
		for end: float in [-0.5, 0.5]:
			MeshKit.add(st, MeshKit.cylinder(radius * 0.85, radius * 0.85, 0.04, 12),
					Transform3D(basis, center + across * length * end * 1.002), Color("d9b07a"))
			var pole: Vector3 = center + across * length * end * 0.95
			MeshKit.add(st, MeshKit.cylinder(0.04, 0.04, 1.6, 6), _at(pole + Vector3.UP * 0.8),
					Color("e8e2d6"))
			MeshKit.add(st, MeshKit.cylinder(0.25, 0.0, 0.5, 3),
					Transform3D(Basis(Vector3.FORWARD, PI / 2.0).scaled(Vector3(1.0, 1.0, 0.15)),
							pole + Vector3.UP * 1.45 + across * 0.25 * signf(end)), Color("e8412c"))
		_add_mesh(parent, st.commit(), bark, true)


# --- Gates, chalets, animals ----------------------------------------------------

## A checkered line across the course and a banner on two posts above it
## (`trim` colors the posts: red at the start, dark at the finish).
static func _build_gate(parent: Node3D, course: CourseTrack, distance: float, trim: Color) -> void:
	var i := course.index_at(distance)
	var left := course.left_edge(i) - 0.8
	var right := course.right_edge(i) + 0.8
	var width := right - left
	var r2 := course.right(i)
	var t2 := course.tangent(i)
	var across := Vector3(r2.x, 0, r2.y)
	var forward := Vector3(t2.x, 0, t2.y)
	var ground := course.ground_height_at(distance, 0.0)

	var st := MeshKit.begin()
	var steps := 32
	for n in steps:
		var l0 := lerpf(left, right, float(n) / steps)
		var l1 := lerpf(left, right, float(n + 1) / steps)
		var quad := []
		for corner: Array in [[l0, -0.4, 0.0, 0.0], [l1, -0.4, 1.0, 0.0], [l1, 0.4, 1.0, 1.0],
				[l0, 0.4, 0.0, 1.0]]:
			var lateral: float = corner[0]
			var y := course.ground_height_at(distance + corner[1], lateral) + 0.05
			quad.append([_v3(course.edge(i, lateral), y) + forward * corner[1],
					Vector2(lerpf(float(n) / steps, float(n + 1) / steps, corner[2]), corner[3])])
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[k][1])
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[k][0])
	var stripe := _checker_material(int(width), 1)
	stripe.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(parent, st.commit(), stripe, false)

	var banner_y := ground + 5.8
	var post_mat := Scenery.flat(trim, 0.8)
	for lateral: float in [left, right]:
		var foot := course.ground_height_at(distance, lateral)
		var height := banner_y + 0.7 - foot
		var post := MeshInstance3D.new()
		post.mesh = MeshKit.cylinder(0.25, 0.22, height, 10)
		post.position = _v3(course.edge(i, lateral), foot + height / 2.0)
		post.material_override = post_mat
		parent.add_child(post)
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(width, 1.5, 0.15)
	var banner := MeshInstance3D.new()
	banner.mesh = banner_mesh
	banner.transform = Transform3D(Basis(across, Vector3.UP, across.cross(Vector3.UP)),
			_v3(course.edge(i, (left + right) / 2.0), banner_y))
	banner.material_override = _checker_material(int(width * 0.7), 2)
	parent.add_child(banner)


## A few wooden chalets around the finish plaza: a little alpine village.
static func _build_chalets(parent: Node3D, course: AlpsCourse, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var wood := Color("8a5a34")
	var roof := Color("5b3b2a")
	for n in 6:
		var side := -1.0 if n % 2 == 0 else 1.0
		var d := course.finish_distance - 40.0 + n * 18.0
		var i := course.index_at(d)
		var edge := course.right_edge(i) if side > 0.0 else -course.left_edge(i)
		var lateral := side * (edge + rng.randf_range(9.0, 14.0))
		var p := course.edge(i, lateral)
		var y := _ground_y(course, d, lateral)
		var yaw := course.heading_at(i) + rng.randf_range(-0.2, 0.2)
		var basis := Basis(Vector3.UP, yaw)
		var base := _v3(p, y)
		var box := BoxMesh.new()
		box.size = Vector3(7.0, 4.0, 6.0)
		MeshKit.add(st, box, Transform3D(basis, base + Vector3.UP * 2.0), wood)
		# Gable roof: two slanted boards, wider than the walls, with snow on top.
		for slant: float in [-1.0, 1.0]:
			var board := BoxMesh.new()
			board.size = Vector3(4.6, 0.25, 7.4)
			# Each half slopes down to the outside.
			var tilt := Basis(Vector3.BACK, -slant * 0.6)
			MeshKit.add(st, board, Transform3D(basis * tilt,
					base + basis * Vector3(slant * 1.9, 5.3, 0)), roof)
			var snow_board := BoxMesh.new()
			snow_board.size = Vector3(4.4, 0.12, 7.2)
			MeshKit.add(st, snow_board, Transform3D(basis * tilt,
					base + basis * Vector3(slant * 1.95, 5.48, 0)), SNOW)
		# Windows with red shutters.
		for wx: float in [-1.8, 1.8]:
			var window := BoxMesh.new()
			window.size = Vector3(1.0, 1.0, 0.1)
			MeshKit.add(st, window, Transform3D(basis, base + basis * Vector3(wx, 2.4, 3.02)),
					Color("f3e3b0"))
			var shutter := BoxMesh.new()
			shutter.size = Vector3(0.35, 1.0, 0.12)
			MeshKit.add(st, shutter, Transform3D(basis, base + basis * Vector3(wx - 0.7, 2.4, 3.03)),
					Color("c0392b"))
	_add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)


## Bodies for the animals (made of simple shapes), added with them to the scene.
static func _build_animals(parent: Node3D, course: AlpsCourse) -> void:
	var bodies := {}
	for mover in course.movers:
		if not bodies.has(mover.kind):
			bodies[mover.kind] = _animal_mesh(mover.kind)
		var body := MeshInstance3D.new()
		body.mesh = bodies[mover.kind]
		body.material_override = MeshKit.vertex_color_material()
		mover.add_child(body)
		parent.add_child(mover)


## A four-legged animal facing -Z: body, neck and head, legs, and what makes
## it a goat (horns, beard), a cow (spots, horns) or a deer (antlers).
static func _animal_mesh(kind: String) -> Mesh:
	var st := MeshKit.begin()
	var coat := Color("efe9df")
	var size := 1.0
	match kind:
		"cow":
			coat = Color("f4f1ea")
			size = 1.5
		"deer":
			coat = Color("9a6a3e")
			size = 1.1
		"boar":
			coat = Color("4a3a2e")
			size = 0.8
	var body_y := 0.75 * size
	MeshKit.add(st, MeshKit.sphere(0.5, 10, 6),
			_at(Vector3(0, body_y, 0), Vector3(0.75, 0.75, 1.5) * size), coat)
	MeshKit.add(st, MeshKit.cylinder(0.12 * size, 0.1 * size, 0.55 * size, 6),
			_at(Vector3(0, body_y + 0.35 * size, -0.62 * size), Vector3.ONE, Vector3(-0.6, 0, 0)), coat)
	var head := Vector3(0, body_y + 0.58 * size, -0.82 * size)
	MeshKit.add(st, MeshKit.sphere(0.2 * size, 8, 5), _at(head, Vector3(0.9, 0.9, 1.3)), coat)
	for x: float in [-0.22, 0.22]:
		for z: float in [-0.5, 0.5]:
			MeshKit.add(st, MeshKit.cylinder(0.06 * size, 0.05 * size, body_y, 5),
					_at(Vector3(x * size, body_y * 0.5, z * size)), coat.darkened(0.25))
	match kind:
		"goat":
			for x: float in [-0.08, 0.08]:
				MeshKit.add(st, MeshKit.cylinder(0.04, 0.0, 0.35, 5),
						_at(head + Vector3(x, 0.2, 0.05), Vector3.ONE, Vector3(0.7, 0, 0)), Color("8a7a66"))
			MeshKit.add(st, MeshKit.cylinder(0.05, 0.0, 0.2, 5),
					_at(head + Vector3(0, -0.2, -0.12), Vector3.ONE, Vector3(PI, 0, 0)), Color("d8d0c4"))
		"cow":
			for spot: Vector3 in [Vector3(0.3, 1.2, 0.2), Vector3(-0.32, 1.05, -0.35), Vector3(0.1, 1.35, 0.6)]:
				MeshKit.add(st, MeshKit.sphere(0.22, 8, 4), _at(spot, Vector3(1.0, 0.8, 1.2)), Color("2a2622"))
			for x: float in [-0.18, 0.18]:
				MeshKit.add(st, MeshKit.cylinder(0.04, 0.0, 0.25, 5),
						_at(head + Vector3(x, 0.22, 0), Vector3.ONE, Vector3(0, 0, -signf(x) * 0.9)),
						Color("e8dcc0"))
			# A cowbell, of course.
			MeshKit.add(st, MeshKit.cylinder(0.06, 0.1, 0.16, 6), _at(head + Vector3(0, -0.38, 0.12)),
					Color("d4a72c"))
		"deer":
			for x: float in [-0.1, 0.1]:
				var base := head + Vector3(x, 0.2, 0.05)
				MeshKit.add(st, MeshKit.cylinder(0.03, 0.02, 0.5, 5),
						_at(base + Vector3(x, 0.22, 0), Vector3.ONE, Vector3(0, 0, -signf(x) * 0.4)),
						Color("c9b48a"))
				MeshKit.add(st, MeshKit.cylinder(0.025, 0.0, 0.25, 5),
						_at(base + Vector3(x * 1.6, 0.35, -0.08), Vector3.ONE, Vector3(-0.5, 0, 0)),
						Color("c9b48a"))
		"boar":
			# A wild boar: a long snout, little tusks and a bristly ridge on the back.
			MeshKit.add(st, MeshKit.cylinder(0.12, 0.08, 0.3, 6),
					_at(head + Vector3(0, -0.05, -0.2), Vector3.ONE, Vector3(PI / 2, 0, 0)), coat.lightened(0.1))
			for x: float in [-0.08, 0.08]:
				MeshKit.add(st, MeshKit.cylinder(0.025, 0.0, 0.14, 5),
						_at(head + Vector3(x, 0.0, -0.32), Vector3.ONE, Vector3(0.5, 0, 0)), Color("f2ead8"))
			MeshKit.add(st, MeshKit.sphere(0.3, 8, 4), _at(Vector3(0, body_y + 0.3 * size, -0.1),
					Vector3(0.3, 0.5, 1.6) * size), coat.darkened(0.3))
	return MeshKit.finish(st)


# --- Helpers (same as the island's) ----------------------------------------------

static func _multimesh(parent: Node3D, mesh: Mesh, transforms: Array[Transform3D], tint: bool,
		rng: RandomNumberGenerator) -> void:
	if transforms.is_empty():
		return
	IslandScenery._multimesh(parent, mesh, transforms, tint, rng)


static func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, shadows: bool) -> void:
	IslandScenery._add_mesh(parent, mesh, mat, shadows)


static func _ground_material() -> StandardMaterial3D:
	return IslandScenery._ground_material()


static func _checker_material(columns: int, rows: int) -> StandardMaterial3D:
	return IslandScenery._checker_material(columns, rows)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	IslandScenery._quad(st, a, b, c, d, ca, cb, cc, cd)


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


static func _at(pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> Transform3D:
	return IslandScenery._at(pos, scl, rot)


static func _placed(p: Vector2, y: float, yaw: float, scl: float) -> Transform3D:
	return IslandScenery._placed(p, y, yaw, scl)


static func _varied(p: Vector2, y: float, rng: RandomNumberGenerator, scale_min: float,
		scale_max: float) -> Transform3D:
	return IslandScenery._varied(p, y, rng, scale_min, scale_max)
