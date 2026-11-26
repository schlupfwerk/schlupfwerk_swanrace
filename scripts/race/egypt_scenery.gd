class_name EgyptScenery
extends RefCounted
## Builds the Egypt desert around an EgyptCircuit: a hot, clear sky, a
## packed-sand road between soft dunes (drawn a little higher than the ground
## the swans stand on, so a swan climbing one looks like it sinks into the
## sand), rolling dunes to the horizon, an oasis with palms and a pond by the
## start, three great pyramids and two sphinxes far away, the sand devils'
## bodies (they draw themselves) and the start gate.

const ROAD := Color("c99a5c")
const ROAD_EDGE := Color("b5874c")
const DUNE := Color("ecc98a")
const DUNE_SHADE := Color("d9b06e")
const STONE := Color("d8b47a")
const STONE_DARK := Color("b8935a")
const NEMES_BLUE := Color("2a5fa8")
const NEMES_GOLD := Color("e0b23c")
const STEP := 2


static func build(parent: Node3D, course: EgyptCircuit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3100
	Scenery.add_environment(parent)
	_desert_sky(parent)
	var room := AlpsScenery._room(course)
	_build_ground(parent, course, room)
	_build_far(parent, course, rng)
	_build_oasis(parent, course, rng)
	for mover in course.movers:
		parent.add_child(mover)
	AlpsScenery._build_gate(parent, course, 0.0, NEMES_GOLD)


static func _desert_sky(parent: Node3D) -> void:
	for child in parent.get_children():
		if child is WorldEnvironment:
			var env: Environment = (child as WorldEnvironment).environment
			var sky := env.sky.sky_material as ProceduralSkyMaterial
			sky.sky_top_color = Color("3f8ad6")
			sky.sky_horizon_color = Color("f2dcb2")
			sky.ground_horizon_color = Color("e9cf9c")
			sky.ground_bottom_color = Color("d9b06e")
			env.fog_light_color = Color("f0dcb8")
			env.fog_density = 0.0006
		elif child is DirectionalLight3D:
			(child as DirectionalLight3D).light_color = Color("fff1d6")


# --- Ground ----------------------------------------------------------------------

## Across the road at sample i: (lateral, height above the road, color). The
## road, then on each side a dune rising to a crest, a dip and more dunes.
static func _profile(course: EgyptCircuit, i: int, room: PackedVector2Array) -> Array:
	var left := course.left_edge(i)
	var right := course.right_edge(i)
	var limit_left := 0.85 * room[i].x
	var limit_right := 0.85 * room[i].y
	var outs := [[0.0, 0.0, ROAD_EDGE], [2.0, 0.8, DUNE], [5.0, 2.2, DUNE], [9.0, 4.0, DUNE],
			[16.0, 2.4, DUNE_SHADE], [28.0, 5.0, DUNE], [50.0, 2.0, DUNE_SHADE]]
	var points := []
	for k in range(outs.size() - 1, -1, -1):
		var out: float = minf(outs[k][0], limit_left - 0.5) if k > 0 else 0.0
		points.append([left - out, outs[k][1], outs[k][2]])
	for n in range(1, 4):
		points.append([lerpf(left, right, n / 4.0), 0.0, ROAD])
	for k in outs.size():
		var out: float = minf(outs[k][0], limit_right - 0.5) if k > 0 else 0.0
		points.append([right + out, outs[k][1], outs[k][2]])
	return points


static func _build_ground(parent: Node3D, course: EgyptCircuit, room: PackedVector2Array) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 8
	noise.frequency = 0.04
	var st := MeshKit.begin()
	var count := course.sample_count()
	var i := 0
	while i < count:
		var j := i + STEP
		var wi := wrapi(i, 0, count)
		var wj := wrapi(j, 0, count)
		var a := _profile(course, wi, room)
		var b := _profile(course, wj, room)
		var ya := course.ground_height_at(course.lengths[wi], 0.0)
		var yb := course.ground_height_at(course.lengths[wj], 0.0)
		for n in a.size() - 1:
			var corners := [
				_v3(course.edge(wi, a[n][0]), ya + a[n][1]),
				_v3(course.edge(wj, b[n][0]), yb + b[n][1]),
				_v3(course.edge(wj, b[n + 1][0]), yb + b[n + 1][1]),
				_v3(course.edge(wi, a[n + 1][0]), ya + a[n + 1][1]),
			]
			var colors := [a[n][2], b[n][2], b[n + 1][2], a[n + 1][2]]
			for k in 4:
				var c: Vector3 = corners[k]
				colors[k] = (colors[k] as Color) * (0.95 + 0.07 * noise.get_noise_2d(c.x, c.z))
			IslandScenery._quad(st, corners[0], corners[1], corners[2], corners[3],
					colors[0], colors[1], colors[2], colors[3])
		i = j
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), true)
	# The desert floor to the horizon.
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(6000, 6000)
	var desert := MeshInstance3D.new()
	desert.mesh = mesh
	desert.material_override = Scenery.flat(DUNE_SHADE, 1.0)
	desert.position = Vector3(course.points[0].x, -0.5, course.points[0].y)
	desert.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(desert)


# --- Far away --------------------------------------------------------------------

## Big rolling dunes around, three great pyramids and two sphinxes facing the
## track, far away.
static func _build_far(parent: Node3D, course: EgyptCircuit, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var bounds := Rect2(course.points[0], Vector2.ZERO)
	for p in course.points:
		bounds = bounds.expand(p)
	var center := bounds.get_center()
	var reach := bounds.size.length() * 0.5
	for n in 26:
		var angle := TAU * n / 26.0 + rng.randf_range(-0.1, 0.1)
		var spot := center + Vector2(cos(angle), sin(angle)) * (reach + rng.randf_range(120.0, 420.0))
		var radius := rng.randf_range(60.0, 140.0)
		MeshKit.add(st, MeshKit.sphere(1.0, 14, 7), IslandScenery._at(Vector3(spot.x, 0.0, spot.y),
				Vector3(radius, rng.randf_range(14.0, 34.0), radius * rng.randf_range(0.5, 0.9)),
				Vector3(0.0, rng.randf() * TAU, 0.0)), DUNE.darkened(rng.randf_range(0.0, 0.1)))
	# Pyramids: ahead of the start line, side by side, the middle one the biggest.
	var ahead := course.tangent(0)
	var side := Vector2(-ahead.y, ahead.x)
	var base := center + ahead * (reach + 420.0)
	for k in 3:
		var size: float = [190.0, 240.0, 150.0][k]
		var spot: Vector2 = base + side * (k - 1) * 260.0 + ahead * [40.0, 0.0, 80.0][k]
		MeshKit.add(st, MeshKit.cylinder(size * 0.72, 0.0, size * 0.65, 4),
				IslandScenery._at(Vector3(spot.x, size * 0.325, spot.y), Vector3.ONE, Vector3(0.0, PI / 4.0, 0.0)),
				STONE if k != 1 else STONE.lightened(0.05))
		# A golden capstone on the biggest.
		if k == 1:
			MeshKit.add(st, MeshKit.cylinder(8.0, 0.0, 6.0, 4), IslandScenery._at(Vector3(spot.x, size * 0.65 - 2.0, spot.y),
					Vector3.ONE, Vector3(0.0, PI / 4.0, 0.0)), NEMES_GOLD)
	# Two sphinxes guarding the way to the pyramids, facing the track.
	for k: float in [-1.0, 1.0]:
		var spot := center + ahead * (reach + 190.0) + side * k * 120.0
		var yaw := atan2(ahead.x, ahead.y)
		_sphinx(st, Vector3(spot.x, 0.0, spot.y), yaw, 6.0)
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


## A lying sphinx facing -Z (towards `yaw`), `scale` times a 10 m model: a lion
## body with front paws, and a head with the striped headdress.
static func _sphinx(st: SurfaceTool, at: Vector3, yaw: float, scale: float) -> void:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	var parts := [
		# [size, center, color]
		[Vector3(3.0, 2.2, 7.0), Vector3(0, 1.1, 1.0), STONE],
		[Vector3(2.6, 1.0, 1.4), Vector3(0, 2.4, 4.0), STONE_DARK],
		[Vector3(0.9, 0.7, 3.2), Vector3(-0.9, 0.35, -3.8), STONE],
		[Vector3(0.9, 0.7, 3.2), Vector3(0.9, 0.35, -3.8), STONE],
		[Vector3(2.6, 2.4, 2.2), Vector3(0, 3.0, -1.8), STONE],
	]
	for part: Array in parts:
		var box := BoxMesh.new()
		box.size = part[0]
		MeshKit.add(st, box, Transform3D(basis, at + basis * part[1]), part[2])
	# Head and the headdress with stripes on both sides.
	MeshKit.add(st, MeshKit.sphere(0.85, 10, 6), Transform3D(basis, at + basis * Vector3(0, 4.9, -2.4)), STONE)
	var cloth := BoxMesh.new()
	cloth.size = Vector3(2.2, 1.6, 0.5)
	MeshKit.add(st, cloth, Transform3D(basis, at + basis * Vector3(0, 4.6, -1.9)), NEMES_GOLD)
	for k in 5:
		var stripe := BoxMesh.new()
		stripe.size = Vector3(2.25, 0.14, 0.52)
		MeshKit.add(st, stripe, Transform3D(basis, at + basis * Vector3(0, 4.0 + k * 0.3, -1.9)), NEMES_BLUE)
	var top := BoxMesh.new()
	top.size = Vector3(1.9, 0.4, 1.7)
	MeshKit.add(st, top, Transform3D(basis, at + basis * Vector3(0, 5.6, -2.1)), NEMES_GOLD)


## An oasis by the start: a small pond with date palms around it, outside the
## dunes on the left of the start line.
static func _build_oasis(parent: Node3D, course: EgyptCircuit, rng: RandomNumberGenerator) -> void:
	var i := course.index_at(20.0)
	var p := course.edge(i, course.left_edge(i) - 26.0)
	var y := course.ground_height_at(20.0, 0.0) + 2.2
	var pond := MeshInstance3D.new()
	pond.mesh = MeshKit.cylinder(9.0, 9.0, 0.1, 24)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.25, 0.62, 0.7, 0.9)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.1
	pond.material_override = water
	pond.position = Vector3(p.x, y, p.y)
	parent.add_child(pond)
	var palms: Array[Transform3D] = []
	for n in 9:
		var angle := TAU * n / 9.0 + rng.randf_range(-0.2, 0.2)
		var spot := p + Vector2(cos(angle), sin(angle)) * rng.randf_range(10.5, 14.0)
		palms.append(IslandScenery._placed(spot, y - 0.2, rng.randf() * TAU, rng.randf_range(0.8, 1.1)))
	IslandScenery._multimesh(parent, RioScenery._palm_mesh(1), palms, true, rng)


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)
