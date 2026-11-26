class_name GreatWallScenery
extends RefCounted
## Builds the Great Wall around a GreatWallCourse: a sunset sky with the sun
## low on the right and glowing clouds, green mountain ridges falling away on
## both sides and blue-violet ranges far away, the wall itself (stone sides,
## a paved walkway, parapets with battlements, broken in places, holes in the
## walkway), temples standing over the walkway with bells that ring as you
## pass (ProximitySound), another stretch of wall on a far ridge, and the
## start and finish gates. Decoration only: what collides lives in the course.

const STONE := Color("b9a78a")
const STONE_DARK := Color("8f7f66")
const PAVING := Color("a39478")
const GREEN := Color("5d7f45")
const PILLAR := Color("b8322a")
const ROOF_TILES := Color("2f6f5a")
const GOLD := Color("d9a520")
const HOLE := Color("1e1712")
const FAR_RANGES := [Color("6a5a8a"), Color("7d6a96"), Color("9a7fa3")]
## How far the wall's sides go down below the walkway (m).
const WALL_DROP := 9.0
const PARAPET := 0.5
const STEP := 2


static func build(parent: Node3D, course: GreatWallCourse) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1421
	Scenery.add_environment(parent)
	_sunset(parent, course)
	_build_mountains(parent, course)
	_build_far(parent, course, rng)
	_build_walkway(parent, course)
	_build_wall_sides(parent, course)
	_build_parapets(parent, course, rng)
	_build_temples(parent, course)
	AlpsScenery._build_gate(parent, course, course.start_distance, PILLAR)
	AlpsScenery._build_gate(parent, course, course.finish_distance, Color("1d1d22"))


# --- Sky -------------------------------------------------------------------------

## The sun low on the right of the run, a warm orange light, a sky from deep
## blue overhead to orange and pink at the horizon, and glowing clouds.
static func _sunset(parent: Node3D, course: GreatWallCourse) -> void:
	var last := course.sample_count() - 1
	var along := (course.points[last] - course.points[0]).normalized()
	var right := Vector2(-along.y, along.x)
	for child in parent.get_children():
		if child is WorldEnvironment:
			var env: Environment = (child as WorldEnvironment).environment
			var sky := env.sky.sky_material as ProceduralSkyMaterial
			sky.sky_top_color = Color("2b3a78")
			sky.sky_horizon_color = Color("ff9b5e")
			sky.ground_horizon_color = Color("d9876a")
			sky.ground_bottom_color = Color("3b2e45")
			sky.sun_angle_max = 40.0
			sky.sun_curve = 0.1
			env.fog_light_color = Color("e7a27e")
			env.fog_density = 0.0015
		elif child is DirectionalLight3D:
			var sun := child as DirectionalLight3D
			sun.light_color = Color("ffb27a")
			sun.light_energy = 1.1
			# The light travels from the right of the run towards the left.
			var travel := Vector3(-right.x, -0.13, -right.y).normalized()
			sun.basis = Basis.looking_at(travel, Vector3.UP)
	# Clouds lit by the sunset on the sun's side, low over the horizon.
	var st := MeshKit.begin()
	var middle := course.points[course.sample_count() / 2]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for n in 12:
		var spot := middle + right * rng.randf_range(1300.0, 1800.0) + along * rng.randf_range(-1400.0, 1400.0)
		var tint := Color("ffb38a").lerp(Color("ff7fa0"), rng.randf())
		MeshKit.add(st, MeshKit.sphere(1.0, 12, 6), IslandScenery._at(Vector3(spot.x, rng.randf_range(90.0, 260.0), spot.y),
				Vector3(rng.randf_range(140.0, 260.0), rng.randf_range(12.0, 24.0), rng.randf_range(60.0, 110.0))), tint)
	var clouds := MeshKit.vertex_color_material()
	clouds.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	clouds.disable_fog = true
	IslandScenery._add_mesh(parent, st.commit(), clouds, false)


# --- Land ------------------------------------------------------------------------

## The ridge under the wall: the ground falls away on both sides into valleys.
static func _build_mountains(parent: Node3D, course: GreatWallCourse) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 21
	noise.frequency = 0.01
	var st := MeshKit.begin()
	var count := course.sample_count()
	var outs := [-520.0, -220.0, -90.0, -30.0, -8.0, 8.0, 30.0, 90.0, 220.0, 520.0]
	var drops := [150.0, 110.0, 62.0, 26.0, WALL_DROP - 0.5, WALL_DROP - 0.5, 26.0, 62.0, 110.0, 150.0]
	var i := 0
	while i < count - 1:
		var j := mini(i + STEP * 2, count - 1)
		for n in outs.size() - 1:
			var corners: Array[Vector3] = []
			var colors: Array[Color] = []
			for pair: Array in [[i, n], [j, n], [j, n + 1], [i, n + 1]]:
				var k: int = pair[0]
				var m: int = pair[1]
				var lateral: float = outs[m]
				if absf(lateral) < 10.0:
					lateral = signf(lateral) * (course.right_edge(k) + 3.0)
				var p := course.edge(k, lateral)
				var bump := noise.get_noise_2d(p.x, p.y) * (0.0 if absf(lateral) < 20.0 else 18.0)
				corners.append(Vector3(p.x, course.ground_height_at(course.lengths[k], 0.0) - drops[m] + bump, p.y))
				colors.append(GREEN.darkened(0.12 * absf(float(m) - 4.5) / 4.5 + 0.05 * noise.get_noise_2d(p.y, p.x)))
			IslandScenery._quad(st, corners[0], corners[1], corners[2], corners[3], colors[0], colors[1], colors[2],
					colors[3])
		i = j
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), false)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(6000, 6000)
	var valley := MeshInstance3D.new()
	valley.mesh = mesh
	valley.material_override = Scenery.flat(GREEN.darkened(0.3), 1.0)
	var middle := course.points[course.sample_count() / 2]
	valley.position = Vector3(middle.x, GreatWallCourse.BASE - 150.0, middle.y)
	valley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(valley)


## Blue-violet mountain ranges far away on both sides, and another stretch
## of the wall snaking over a far ridge on the left.
static func _build_far(parent: Node3D, course: GreatWallCourse, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var last := course.sample_count() - 1
	var along := (course.points[last] - course.points[0]).normalized()
	var right := Vector2(-along.y, along.x)
	var middle := course.points[last / 2]
	for row in 3:
		for n in 16:
			var side := -1.0 if n % 2 == 0 else 1.0
			var spot := middle + along * rng.randf_range(-1800.0, 1800.0) + right * side * (900.0 + row * 450.0)
			var radius := rng.randf_range(260.0, 420.0)
			MeshKit.add(st, MeshKit.sphere(1.0, 12, 6), IslandScenery._at(Vector3(spot.x, GreatWallCourse.BASE - 150.0,
					spot.y), Vector3(radius, rng.randf_range(180.0, 320.0) + row * 60.0, radius)), FAR_RANGES[row])
	# The far wall: blocks along a wavy line on a ridge to the left.
	var steps := 120
	for n in steps:
		var u := float(n) / steps
		var a := middle + along * lerpf(-900.0, 900.0, u) - right * (420.0 + 60.0 * sin(u * TAU * 1.5))
		var b := middle + along * lerpf(-900.0, 900.0, u + 1.0 / steps) - right * (420.0 + 60.0 * sin((u + 1.0 / steps) * TAU * 1.5))
		var y := GreatWallCourse.BASE - 20.0 + 30.0 * sin(u * TAU * 2.0)
		var mid := (a + b) * 0.5
		var block := BoxMesh.new()
		block.size = Vector3(6.0, 7.0, a.distance_to(b) + 0.5)
		var yaw := atan2(-(b - a).x, -(b - a).y)
		MeshKit.add(st, block, Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, y, mid.y)), STONE_DARK)
		if n % 15 == 0:
			var tower := BoxMesh.new()
			tower.size = Vector3(10.0, 14.0, 10.0)
			MeshKit.add(st, tower, Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, y + 3.0, mid.y)), STONE_DARK)
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


# --- The wall --------------------------------------------------------------------

## The paved walkway, in 1 m tiles, leaving out the holes; under each hole a
## dark pit with broken bricks around it.
static func _build_walkway(parent: Node3D, course: GreatWallCourse) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	for i in count - 1:
		var j := i + 1
		var middle := (course.lengths[i] + course.lengths[j]) * 0.5
		var left := course.left_edge(i)
		var right := course.right_edge(i)
		var l := left
		while l < right - 0.01:
			var l1 := minf(l + 1.0, right)
			if course.hole_at(middle, (l + l1) * 0.5).is_empty():
				var shade := PAVING * (0.94 + 0.08 * float((i + int(l * 3.0)) % 3) / 2.0)
				IslandScenery._quad(st, _deck(course, i, l), _deck(course, j, l), _deck(course, j, l1), _deck(course, i, l1),
						shade, shade, shade, shade)
			l = l1
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), false)
	var pits := MeshKit.begin()
	for hole: Dictionary in course.holes:
		var i := course.index_at(hole.distance)
		var y := course.ground_height_at(hole.distance, hole.lateral)
		var basis := Basis(Vector3.UP, course.heading_at(i))
		var p := course.edge(i, hole.lateral)
		var pit := BoxMesh.new()
		pit.size = Vector3(hole.width, 3.0, hole.length)
		MeshKit.add(pits, pit, Transform3D(basis, Vector3(p.x, y - 1.6, p.y)), HOLE)
		for k in 6:
			var corner := Vector3((k % 3 - 1) * hole.width * 0.5, 0.1, (1 if k < 3 else -1) * (hole.length * 0.5 + 0.2))
			MeshKit.add(pits, MeshKit.sphere(0.3, 6, 3), Transform3D(basis, Vector3(p.x, y, p.y) + basis * corner),
					STONE_DARK)
	IslandScenery._add_mesh(parent, pits.commit(), MeshKit.vertex_color_material(), false)


static func _deck(course: CourseTrack, i: int, lateral: float) -> Vector3:
	var p := course.edge(i, lateral)
	return Vector3(p.x, course.ground_height_at(course.lengths[i], 0.0) + 0.02, p.y)


## The wall's outer faces, from the parapet down into the ridge.
static func _build_wall_sides(parent: Node3D, course: GreatWallCourse) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	var i := 0
	while i < count - 1:
		var j := mini(i + STEP, count - 1)
		for side: float in [-1.0, 1.0]:
			var la := (course.right_edge(i) if side > 0.0 else course.left_edge(i)) + side * PARAPET
			var lb := (course.right_edge(j) if side > 0.0 else course.left_edge(j)) + side * PARAPET
			var ya := course.ground_height_at(course.lengths[i], 0.0)
			var yb := course.ground_height_at(course.lengths[j], 0.0)
			var pa := course.edge(i, la)
			var pb := course.edge(j, lb)
			var top_a := Vector3(pa.x, ya, pa.y)
			var top_b := Vector3(pb.x, yb, pb.y)
			var bottom_a := top_a + Vector3.DOWN * WALL_DROP
			var bottom_b := top_b + Vector3.DOWN * WALL_DROP
			var shade := STONE if (i / 6) % 2 == 0 else STONE.darkened(0.05)
			IslandScenery._quad(st, top_a, top_b, bottom_b, bottom_a, shade, shade, STONE_DARK, STONE_DARK)
			# The top of the side wall, under the parapet.
			var inner_a := course.edge(i, la - side * PARAPET)
			var inner_b := course.edge(j, lb - side * PARAPET)
			IslandScenery._quad(st, Vector3(inner_a.x, ya, inner_a.y), Vector3(inner_b.x, yb, inner_b.y), top_b, top_a,
					STONE, STONE, STONE, STONE)
		i = j
	var mat := IslandScenery._ground_material()
	IslandScenery._add_mesh(parent, st.commit(), mat, true)


## Parapets on both edges: a low wall with battlements (merlons) on top. At
## the broken stretches only rubble is left.
static func _build_parapets(parent: Node3D, course: GreatWallCourse, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var count := course.sample_count()
	for side: float in [-1.0, 1.0]:
		var d := 0.0
		var n := 0
		while d < course.length - 1.0:
			var at := d + 0.8
			var i := course.index_at(at)
			var lateral := (course.right_edge(i) if side > 0.0 else course.left_edge(i)) + side * PARAPET * 0.5
			var p := course.edge(i, lateral)
			var y := course.ground_height_at(at, 0.0)
			var basis := Basis(Vector3.UP, course.heading_at(i))
			if course.edge_open(at, side):
				# Rubble where the parapet fell.
				if rng.randf() < 0.6:
					var rubble := BoxMesh.new()
					rubble.size = Vector3(rng.randf_range(0.3, 0.6), rng.randf_range(0.2, 0.4), rng.randf_range(0.3, 0.6))
					MeshKit.add(st, rubble, Transform3D(basis.rotated(Vector3.UP, rng.randf() * TAU),
							Vector3(p.x, y + 0.1, p.y)), STONE_DARK)
			else:
				var wall := BoxMesh.new()
				wall.size = Vector3(PARAPET, 0.9, 1.65)
				MeshKit.add(st, wall, Transform3D(basis, Vector3(p.x, y + 0.45, p.y)), STONE)
				if n % 2 == 0:
					var merlon := BoxMesh.new()
					merlon.size = Vector3(PARAPET + 0.04, 0.7, 0.85)
					MeshKit.add(st, merlon, Transform3D(basis, Vector3(p.x, y + 1.25, p.y)), STONE.darkened(0.04))
			d += 1.6
			n += 1
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)


## Temples over the walkway: red pillars on both sides, a carved beam, and
## two tiers of green tiled roofs with golden ridges. A bell rings in each one
## as the player runs under it.
static func _build_temples(parent: Node3D, course: GreatWallCourse) -> void:
	var st := MeshKit.begin()
	var bells := PackedVector3Array()
	for temple: float in GreatWallCourse.TEMPLES:
		var at := course.start_distance + temple
		var i := course.index_at(at)
		var y := course.ground_height_at(at, 0.0)
		var basis := Basis(Vector3.UP, course.heading_at(i))
		var center := course.edge(i, 0.0)
		var origin := Vector3(center.x, y, center.y)
		var half := GreatWallCourse.HALF_WIDTH + 0.3
		for x: float in [-half, half]:
			for z: float in [-3.5, 0.0, 3.5]:
				MeshKit.add(st, MeshKit.cylinder(0.3, 0.3, 5.5, 10), Transform3D(basis, origin + basis * Vector3(x, 2.75, z)),
						PILLAR)
				MeshKit.add(st, MeshKit.cylinder(0.45, 0.45, 0.4, 10), Transform3D(basis, origin + basis * Vector3(x, 0.2, z)),
						STONE_DARK)
		_box(st, basis, origin + basis * Vector3(0, 5.6, 0), Vector3(half * 2.0 + 1.0, 0.6, 8.6), PILLAR.darkened(0.2))
		_box(st, basis, origin + basis * Vector3(0, 5.95, 0), Vector3(half * 2.0 + 1.6, 0.2, 9.2), GOLD)
		# Two tiers of roofs (four-sided, flaring out), golden ridge and finial.
		for tier in 2:
			var w := half * 2.0 + 6.0 - tier * 4.0
			var l := 13.0 - tier * 4.0
			var base := 6.1 + tier * 3.0
			MeshKit.add(st, MeshKit.cylinder(0.72, 0.36, 2.0, 4), Transform3D(basis * Basis(Vector3.UP, PI / 4).scaled(
					Vector3(w, 1.0, l)), origin + basis * Vector3(0, base + 1.0, 0)), ROOF_TILES)
			if tier == 0:
				_box(st, basis, origin + basis * Vector3(0, base + 2.0, 0), Vector3(w * 0.45, 1.2, l * 0.45), PILLAR)
		_box(st, basis, origin + basis * Vector3(0, 11.2, 0), Vector3(0.3, 0.3, 6.0), GOLD)
		MeshKit.add(st, MeshKit.sphere(0.45, 8, 5), Transform3D(basis, origin + basis * Vector3(0, 11.7, 0)), GOLD)
		# The bell, hanging in the middle.
		MeshKit.add(st, MeshKit.cylinder(0.55, 0.3, 0.9, 12), Transform3D(basis, origin + basis * Vector3(0, 4.6, 0)), GOLD)
		bells.append(origin + Vector3.UP * 4.6)
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)
	var ringing := ProximitySound.new()
	ringing.spots = bells
	ringing.stream = Sfx.temple_bell()
	ringing.near = 14.0
	ringing.far = 80.0
	ringing.gap = 2.0
	ringing.pitch_range = 0.03
	ringing.unit_size = 25.0
	ringing.max_distance = 150.0
	parent.add_child(ringing)


static func _box(st: SurfaceTool, basis: Basis, center: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	MeshKit.add(st, box, Transform3D(basis, center), color)
