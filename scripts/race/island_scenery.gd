class_name IslandScenery
extends RefCounted
## Builds the island around an IslandTrack: beach, sea with waves and foam,
## Atlantic forest on hills, rocks, an islet with a lighthouse and sailboats.
## Decoration only: nothing here collides with the swans (the forest bump is
## a TrackRules rule).

const SAND := Color("bf9c6b")
const SAND_EDGE := Color("a88a5e")
const WET_SAND := Color("94764f")
const SEA_FLOOR := Color("6f5a40")
const FOREST_FLOOR := Color("355f26")
const HILL_TOP := Color("567f31")
const SEA_LEVEL := IslandTrack.SEA_LEVEL
const WATER_SHADER := preload("res://shaders/water.gdshader")
const FOAM_SHADER := preload("res://shaders/foam.gdshader")

## Hills inside the island: center (fraction of the island radius), height (m)
## and width (fraction of the island radius).
const HILLS := [
	[Vector2(0.05, -0.1), 45.0, 0.32],
	[Vector2(-0.32, 0.22), 30.0, 0.24],
	[Vector2(0.34, 0.3), 26.0, 0.22],
	[Vector2(-0.1, 0.5), 18.0, 0.2],
	[Vector2(0.38, -0.36), 20.0, 0.2],
]
const FOREST_STEP := 4
const FOREST_RINGS := 24
const GREENS := [Color("2f6b2a"), Color("3f7f2f"), Color("4f8f35"), Color("2a5a26"),
		Color("5c9a3a"), Color("6f9f4a")]
const TRUNK := Color("6b4a2e")


static func build(parent: Node3D, track: IslandTrack, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var radius := IslandTrack.LAP_LENGTH / TAU
	_build_sea(parent, radius)
	_build_beach(parent, track, rng)
	_build_foam(parent, track)
	_build_forest_floor(parent, track, radius)
	_build_forest(parent, track, radius, rng)
	_build_forest_edge(parent, track, rng)
	_build_beach_details(parent, track, rng)
	_build_sea_life(parent, track, radius, rng)
	_build_start_line(parent, track)


## Ground height inside the island. `f` is 0 at the center, 1 at the forest edge.
static func ground_height(p: Vector2, f: float, radius: float) -> float:
	var height := 0.0
	for hill: Array in HILLS:
		var center: Vector2 = hill[0] * radius
		var width: float = hill[2] * radius
		height += hill[1] * exp(-p.distance_squared_to(center) / (width * width))
	return height * (1.0 - smoothstep(0.55, 0.95, f)) + 0.04


# --- Ground and water -----------------------------------------------------------

static func _build_sea(parent: Node3D, radius: float) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2400, 2400)
	mesh.subdivide_width = 220
	mesh.subdivide_depth = 220
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("shore_radius", radius + 25.0)
	var sea := MeshInstance3D.new()
	sea.mesh = mesh
	sea.material_override = mat
	sea.position.y = SEA_LEVEL
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sea)


static func _beach_profile(track: IslandTrack, i: int) -> Array:
	var forest := track.forest_edge(i)
	var water := track.water_line(i)
	return [
		[forest - 6.0, 0.04, SAND_EDGE],
		[forest, 0.0, SAND],
		[water - 2.0, 0.0, SAND],
		[water + 3.0, -0.5, WET_SAND],
		[water + 8.0, -1.6, SEA_FLOOR],
		[water + 16.0, -3.4, SEA_FLOOR.darkened(0.2)],
	]


static func _build_beach(parent: Node3D, track: IslandTrack, rng: RandomNumberGenerator) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.08
	var st := MeshKit.begin()
	for i in IslandTrack.SAMPLES:
		var a_profile := _beach_profile(track, i)
		var b_profile := _beach_profile(track, i + 1)
		for j in a_profile.size() - 1:
			var corners := [
				_v3(track.safe_edge(i, a_profile[j][0]), a_profile[j][1]),
				_v3(track.safe_edge(i + 1, b_profile[j][0]), b_profile[j][1]),
				_v3(track.safe_edge(i + 1, b_profile[j + 1][0]), b_profile[j + 1][1]),
				_v3(track.safe_edge(i, a_profile[j + 1][0]), a_profile[j + 1][1]),
			]
			var colors := [a_profile[j][2], b_profile[j][2], b_profile[j + 1][2], a_profile[j + 1][2]]
			for n in 4:
				# Soft patches so the sand is never one flat color.
				var c: Vector3 = corners[n]
				colors[n] = (colors[n] as Color) * (0.94 + 0.08 * noise.get_noise_2d(c.x, c.z))
			_quad(st, corners[0], corners[1], corners[2], corners[3],
					colors[0], colors[1], colors[2], colors[3])
	st.generate_normals()
	_add_mesh(parent, st.commit(), _ground_material(), false)


static func _build_foam(parent: Node3D, track: IslandTrack) -> void:
	var st := MeshKit.begin()
	for i in IslandTrack.SAMPLES:
		var u0 := float(i) / IslandTrack.SAMPLES * 96.0
		var u1 := float(i + 1) / IslandTrack.SAMPLES * 96.0
		var y := SEA_LEVEL + 0.1
		var outer_a := track.water_line(i) + 26.0
		var outer_b := track.water_line(i + 1) + 26.0
		var inner_a := track.water_line(i) + 3.2
		var inner_b := track.water_line(i + 1) + 3.2
		var p := [_v3(track.safe_edge(i, outer_a), y), _v3(track.safe_edge(i + 1, outer_b), y),
				_v3(track.safe_edge(i + 1, inner_b), y), _v3(track.safe_edge(i, inner_a), y)]
		var uv := [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[k])
			st.set_normal(Vector3.UP)
			st.add_vertex(p[k])
	var mat := ShaderMaterial.new()
	mat.shader = FOAM_SHADER
	_add_mesh(parent, st.commit(), mat, false)


static func _build_forest_floor(parent: Node3D, track: IslandTrack, radius: float) -> void:
	var st := MeshKit.begin()
	var count := IslandTrack.SAMPLES / FOREST_STEP
	for k in count:
		var edge_a := track.edge(k * FOREST_STEP, track.forest_edge(k * FOREST_STEP) - 6.0)
		var edge_b := track.edge((k + 1) * FOREST_STEP,
				track.forest_edge((k + 1) * FOREST_STEP) - 6.0)
		for j in FOREST_RINGS:
			var f0 := float(j) / FOREST_RINGS
			var f1 := float(j + 1) / FOREST_RINGS
			var corners := [edge_a * f0, edge_b * f0, edge_b * f1, edge_a * f1]
			var fs := [f0, f0, f1, f1]
			var v := []
			var c := []
			for n in 4:
				var h := ground_height(corners[n], fs[n], radius)
				v.append(_v3(corners[n], h))
				c.append(FOREST_FLOOR.lerp(HILL_TOP, clampf(h / 35.0, 0.0, 1.0)))
			_quad(st, v[0], v[1], v[2], v[3], c[0], c[1], c[2], c[3])
	st.generate_normals()
	_add_mesh(parent, st.commit(), _ground_material(), true)


# --- Forest ---------------------------------------------------------------------

static func _build_forest(parent: Node3D, track: IslandTrack, radius: float,
		rng: RandomNumberGenerator) -> void:
	# Round canopy trees, the bulk of the forest, in two shapes.
	var st := MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.35, 0.25, 6.0), _at(Vector3(0, 3.0, 0)), TRUNK)
	MeshKit.add(st, MeshKit.sphere(2.6), _at(Vector3(0, 6.6, 0)), GREENS[1])
	MeshKit.add(st, MeshKit.sphere(2.0), _at(Vector3(1.7, 5.9, 0.4)), GREENS[0])
	MeshKit.add(st, MeshKit.sphere(2.1), _at(Vector3(-1.5, 6.0, -0.6)), GREENS[2])
	MeshKit.add(st, MeshKit.sphere(1.7), _at(Vector3(0.2, 8.0, 0.9)), GREENS[1])
	_scatter_forest(parent, st.commit(), 520, track, radius, rng, 0.6, 1.5, true)

	st = MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.3, 0.2, 4.5), _at(Vector3(0.2, 2.2, 0), Vector3.ONE,
			Vector3(0, 0, -0.12)), TRUNK.darkened(0.1))
	MeshKit.add(st, MeshKit.sphere(2.2), _at(Vector3(0.6, 5.0, 0), Vector3(1.3, 0.8, 1.0)),
			GREENS[4])
	MeshKit.add(st, MeshKit.sphere(1.5), _at(Vector3(-0.8, 4.4, 0.6)), GREENS[3])
	_scatter_forest(parent, st.commit(), 300, track, radius, rng, 0.7, 1.4, true)

	# Tall emergent tree with a wide, flat crown.
	st = MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.45, 0.3, 12.0), _at(Vector3(0, 6.0, 0)), Color("7a5a3a"))
	MeshKit.add(st, MeshKit.sphere(3.4), _at(Vector3(0, 12.5, 0), Vector3(1.4, 0.5, 1.3)),
			GREENS[3])
	MeshKit.add(st, MeshKit.sphere(2.2), _at(Vector3(2.6, 12.0, 0.5), Vector3(1.2, 0.55, 1.2)),
			GREENS[0])
	_scatter_forest(parent, st.commit(), 110, track, radius, rng, 0.8, 1.3, true)

	# Embaúba (Cecropia): pale trunk and an umbrella of big silvery leaves.
	st = MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.22, 0.16, 9.0), _at(Vector3(0, 4.5, 0)), Color("c9c2b0"))
	for k in 7:
		var a := TAU * k / 7.0
		MeshKit.add(st, MeshKit.sphere(1.0, 8, 4),
				_at(Vector3(cos(a) * 1.3, 9.0 - 0.2 * (k % 2), sin(a) * 1.3), Vector3(1.4, 0.18, 1.0),
				Vector3(0, -a, 0.25)), Color("9bb38a") if k % 2 == 0 else Color("7f9f70"))
	_scatter_forest(parent, st.commit(), 70, track, radius, rng, 0.8, 1.3, false)

	# Palmito-juçara: slender, very tall palm with a small crown.
	st = MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.14, 0.1, 13.0, 6), _at(Vector3(0, 6.5, 0)), Color("8f8a78"))
	_add_fronds(st, Vector3(0, 13.0, 0), 7, 0.8, Color("4f8f35"))
	_scatter_forest(parent, st.commit(), 90, track, radius, rng, 0.8, 1.2, false)

	# Flowering trees: yellow ipê, purple quaresmeira and pink ipê.
	for flower: Color in [Color("f2c418"), Color("9b4fc4"), Color("ef7fb0")]:
		st = MeshKit.begin()
		MeshKit.add(st, MeshKit.cylinder(0.3, 0.2, 6.5), _at(Vector3(0, 3.25, 0)), TRUNK)
		MeshKit.add(st, MeshKit.sphere(2.3), _at(Vector3(0, 7.0, 0)), flower)
		MeshKit.add(st, MeshKit.sphere(1.6), _at(Vector3(1.3, 6.4, 0.3)), flower.darkened(0.12))
		MeshKit.add(st, MeshKit.sphere(1.5), _at(Vector3(-1.2, 6.6, -0.4)), flower.lightened(0.1))
		_scatter_forest(parent, st.commit(), 24, track, radius, rng, 0.8, 1.2, false)


## Plants along the forest edge, right next to the sand.
static func _build_forest_edge(parent: Node3D, track: IslandTrack,
		rng: RandomNumberGenerator) -> void:
	# Coconut palms leaning out over the beach.
	var st := MeshKit.begin()
	var top := Vector3.ZERO
	for j in 5:
		var center := Vector3(0.18 * j * j, 0.9 + 1.7 * j, 0)
		MeshKit.add(st, MeshKit.cylinder(0.24 - 0.02 * j, 0.22 - 0.02 * j, 1.8, 6),
				_at(center, Vector3.ONE, Vector3(0, 0, -0.08 * j)),
				Color("8a6a45").darkened(0.06 * (j % 2)))
		top = center + Vector3(0.1 * j, 0.9, 0)
	_add_fronds(st, top, 8, 1.0, Color("4f9a36"))
	for k in 3:
		var a := TAU * k / 3.0
		MeshKit.add(st, MeshKit.sphere(0.2, 6, 4),
				_at(top + Vector3(cos(a) * 0.3, -0.35, sin(a) * 0.3)), Color("6b4a22"))
	var palms: Array[Transform3D] = []
	for n in 170:
		var i := rng.randi_range(0, IslandTrack.SAMPLES - 1)
		var p := track.edge(i, track.forest_edge(i) - rng.randf_range(1.5, 8.0))
		var r := track.right(i)
		var lean := atan2(r.y, r.x) + rng.randf_range(-0.5, 0.5)
		var basis := Basis(Vector3.UP, -lean).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3))
		palms.append(Transform3D(basis, _v3(p, -0.1)))
	_multimesh(parent, st.commit(), palms, false, rng)

	# Banana plants: big leaves on a short green stem.
	st = MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.22, 0.16, 2.6, 6), _at(Vector3(0, 1.3, 0)), Color("6f8f3a"))
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		MeshKit.add(st, MeshKit.sphere(1.0, 8, 4),
				_at(Vector3(0, 2.7, 0) + dir * 1.0, Vector3(1.25, 0.06, 0.4), Vector3(0, -a, 0.45)),
				Color("7fb83f") if k % 2 == 0 else Color("6aa534"))
	_scatter_edge(parent, st.commit(), 110, track, rng, 1.0, 9.0, 0.8, 1.3, true)

	# Ferns: low fans of fronds.
	st = MeshKit.begin()
	for k in 9:
		var a := TAU * k / 9.0
		var dir := Vector3(cos(a), 0, sin(a))
		MeshKit.add(st, MeshKit.sphere(0.5, 6, 3),
				_at(dir * 0.55 + Vector3.UP * 0.35, Vector3(1.3, 0.08, 0.28), Vector3(0, -a, 0.5)),
				GREENS[4] if k % 2 == 0 else GREENS[2])
	_scatter_edge(parent, st.commit(), 380, track, rng, 0.5, 12.0, 0.7, 1.6, true)

	# Bromeliads: pointed leaves around a red heart.
	st = MeshKit.begin()
	for k in 8:
		var a := TAU * k / 8.0
		var dir := Vector3(cos(a), 0, sin(a))
		MeshKit.add(st, MeshKit.cylinder(0.12, 0.0, 0.9, 4),
				_at(dir * 0.25 + Vector3.UP * 0.35, Vector3(1.0, 1.0, 0.35), Vector3(0.0, -a, 0.7)),
				Color("6f9a3a"))
	MeshKit.add(st, MeshKit.sphere(0.18, 6, 4), _at(Vector3(0, 0.35, 0)), Color("d8342a"))
	_scatter_edge(parent, st.commit(), 160, track, rng, 0.3, 6.0, 0.8, 1.4, false)

	# Heliconias: tall leaves with a zig-zag of red and yellow bracts.
	st = MeshKit.begin()
	for k in 3:
		var a := TAU * k / 3.0
		MeshKit.add(st, MeshKit.sphere(1.0, 8, 4),
				_at(Vector3(cos(a) * 0.4, 1.4, sin(a) * 0.4), Vector3(0.3, 1.2, 0.08),
				Vector3(0, -a, 0.15)), Color("4f8f35"))
	for k in 6:
		var side := 1.0 if k % 2 == 0 else -1.0
		MeshKit.add(st, MeshKit.cylinder(0.09, 0.0, 0.35, 4),
				_at(Vector3(0.12 * side, 1.2 + 0.18 * k, 0), Vector3.ONE, Vector3(0, 0, -1.1 * side)),
				Color("e8412c") if k < 5 else Color("ffd23f"))
	_scatter_edge(parent, st.commit(), 90, track, rng, 1.0, 7.0, 0.9, 1.3, false)

	# Hibiscus bushes dotted with flowers.
	st = MeshKit.begin()
	MeshKit.add(st, MeshKit.sphere(1.0), _at(Vector3(0, 0.7, 0), Vector3(1.2, 0.8, 1.0)), GREENS[2])
	for k in 7:
		var a := TAU * k / 7.0
		MeshKit.add(st, MeshKit.sphere(0.16, 6, 3),
				_at(Vector3(cos(a) * 0.95, 0.75 + 0.25 * sin(a * 3.0), sin(a) * 0.8)),
				Color("e83a5a") if k % 3 else Color("ff9ac0"))
	_scatter_edge(parent, st.commit(), 130, track, rng, 0.5, 8.0, 0.7, 1.4, true)

	# Boulders with a mossy top at the forest edge, some out on the sand. Solid.
	for boulder in _scatter_edge(parent, _boulder_mesh(true), 70, track, rng, -1.5, 5.0, 0.8, 2.2,
			true):
		_add_rock_obstacle(track, boulder)


static func _scatter_forest(parent: Node3D, mesh: Mesh, count: int, track: IslandTrack,
		radius: float, rng: RandomNumberGenerator, scale_min: float, scale_max: float,
		tint: bool) -> void:
	var transforms: Array[Transform3D] = []
	for n in count:
		var i := rng.randi_range(0, IslandTrack.SAMPLES - 1)
		# sqrt keeps the density even over the island's area.
		var f := sqrt(rng.randf_range(0.0, 0.94))
		var p := track.edge(i, track.forest_edge(i) - 9.0) * f
		var y := ground_height(p, f, radius) - 0.2
		transforms.append(_varied(p, y, rng, scale_min, scale_max))
	_multimesh(parent, mesh, transforms, tint, rng)


static func _scatter_edge(parent: Node3D, mesh: Mesh, count: int, track: IslandTrack,
		rng: RandomNumberGenerator, depth_min: float, depth_max: float, scale_min: float,
		scale_max: float, tint: bool) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for n in count:
		var i := rng.randi_range(0, IslandTrack.SAMPLES - 1)
		var p := track.edge(i, track.forest_edge(i) - rng.randf_range(depth_min, depth_max))
		transforms.append(_varied(p, 0.0, rng, scale_min, scale_max))
	_multimesh(parent, mesh, transforms, tint, rng)
	return transforms


static func _add_fronds(st: SurfaceTool, top: Vector3, count: int, length: float,
		color: Color) -> void:
	for k in count:
		var yaw := TAU * k / count
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var frond := Basis(Vector3.UP, -yaw) * Basis(Vector3.FORWARD, 0.35)
		var xform := Transform3D(frond, top + dir * 1.7 * length + Vector3.DOWN * 0.4)
		MeshKit.add(st, MeshKit.sphere(1.0, 8, 4),
				xform * Transform3D(Basis.from_scale(Vector3(2.1 * length, 0.08, 0.38)), Vector3.ZERO),
				color if k % 2 == 0 else color.darkened(0.12))


static func _boulder_mesh(mossy: bool) -> Mesh:
	var st := MeshKit.begin()
	var stone := Color("8a857c")
	MeshKit.add(st, MeshKit.sphere(1.0, 7, 4), _at(Vector3(0, 0.3, 0), Vector3(1.3, 0.8, 1.0)), stone)
	MeshKit.add(st, MeshKit.sphere(0.7, 6, 4), _at(Vector3(0.8, 0.2, 0.4), Vector3(1.0, 0.7, 1.1)),
			stone.darkened(0.1))
	if mossy:
		MeshKit.add(st, MeshKit.sphere(0.9, 7, 3), _at(Vector3(-0.1, 0.75, 0), Vector3(1.2, 0.3, 0.9)),
				Color("5c7f34"))
	return st.commit()


# --- Beach and sea --------------------------------------------------------------

static func _build_beach_details(parent: Node3D, track: IslandTrack,
		rng: RandomNumberGenerator) -> void:
	var shell := MeshKit.begin()
	MeshKit.add(shell, MeshKit.sphere(0.12, 6, 3), _at(Vector3.ZERO, Vector3(1.0, 0.5, 1.3)),
			Color.WHITE)
	var shells: Array[Transform3D] = []
	for n in 600:
		var i := rng.randi_range(0, IslandTrack.SAMPLES - 1)
		var p := track.edge(i, rng.randf_range(track.forest_edge(i) + 1.0, track.water_line(i) + 4.0))
		shells.append(_placed(p, 0.0, rng.randf() * TAU, rng.randf_range(0.5, 1.6)))
	var mm := _multimesh(parent, shell.commit(), shells, false, rng, false)
	var palette := [Color("f3e6d3"), Color("d9b38c"), Color("a39a90"), Color("f0c6b8")]
	for n in mm.multimesh.instance_count:
		mm.multimesh.set_instance_color(n, palette[rng.randi() % palette.size()])

	# Driftwood logs on the sand.
	var wood := MeshKit.begin()
	MeshKit.add(wood, MeshKit.cylinder(0.18, 0.14, 2.4, 6), _at(Vector3(0, 0.12, 0), Vector3.ONE,
			Vector3(0, 0, PI / 2)), Color("9c8668"))
	MeshKit.add(wood, MeshKit.cylinder(0.08, 0.05, 0.9, 5), _at(Vector3(0.5, 0.3, 0.2), Vector3.ONE,
			Vector3(0.6, 0, 0.9)), Color("8c7658"))
	var logs: Array[Transform3D] = []
	for n in 40:
		var i := rng.randi_range(0, IslandTrack.SAMPLES - 1)
		var p := track.edge(i, track.forest_edge(i) + rng.randf_range(0.5, 3.0))
		logs.append(_placed(p, 0.0, rng.randf() * TAU, rng.randf_range(0.8, 1.3)))
		# Low and solid: run around it or jump over it.
		var log_xform := logs[logs.size() - 1]
		var along := Vector2(log_xform.basis.x.x, log_xform.basis.x.z)
		for k in [-0.8, 0.0, 0.8]:
			track.add_obstacle(p + along * k, 0.3, 0.45)
	_multimesh(parent, wood.commit(), logs, true, rng)


static func _build_sea_life(parent: Node3D, track: IslandTrack, radius: float,
		rng: RandomNumberGenerator) -> void:
	# Rocks in the sea, each with a ring of foam.
	var rocks: Array[Transform3D] = []
	var rings: Array[Transform3D] = []
	for n in 26:
		var i := rng.randi_range(0, IslandTrack.SAMPLES - 1)
		var p := track.edge(i, track.water_line(i) + rng.randf_range(25.0, 120.0))
		if not track.is_open_sea(p, 20.0):
			continue
		var s := rng.randf_range(1.2, 3.5)
		rocks.append(_varied(p, SEA_LEVEL - 0.4, rng, s, s * 1.3))
		_add_rock_obstacle(track, rocks[rocks.size() - 1])
		rings.append(_placed(p, SEA_LEVEL + 0.05, 0.0, s * 1.6))
	_multimesh(parent, _boulder_mesh(false), rocks, true, rng)
	var ring := MeshKit.begin()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.35
	torus.rings = 16
	torus.ring_segments = 4
	MeshKit.add(ring, torus, _at(Vector3.ZERO, Vector3(1.0, 0.1, 1.0)), Color("f4f6f2"))
	_multimesh(parent, ring.commit(), rings, false, rng, false)

	# A rocky islet with a lighthouse, off the start straight.
	var islet_at := track.edge(40, track.water_line(40) + 150.0)
	var islet := MeshKit.begin()
	MeshKit.add(islet, MeshKit.sphere(10.0, 10, 5), _at(Vector3(0, -3.0, 0), Vector3(1.4, 0.7, 1.0)),
			Color("7d776d"))
	MeshKit.add(islet, MeshKit.sphere(7.0, 10, 4), _at(Vector3(-2, 1.0, 1), Vector3(1.3, 0.4, 1.0)),
			Color("5c7f34"))
	for k in 6:
		MeshKit.add(islet, MeshKit.cylinder(1.3 - 0.05 * k, 1.25 - 0.05 * k, 2.0, 12),
				_at(Vector3(2, 3.0 + 2.0 * k, 0)), Color("f2f2ee") if k % 2 == 0 else Color("d6423a"))
	MeshKit.add(islet, MeshKit.cylinder(1.0, 1.0, 1.4, 12), _at(Vector3(2, 15.7, 0)), Color("ffe9a6"))
	MeshKit.add(islet, MeshKit.cylinder(1.3, 0.2, 1.4, 12), _at(Vector3(2, 17.1, 0)), Color("d6423a"))
	var islet_place: Array[Transform3D] = [_placed(islet_at, SEA_LEVEL, 0.4, 1.0)]
	_multimesh(parent, islet.commit(), islet_place, false, rng)

	# Sailboats drifting slowly around the island, far out.
	var sails := [Color("f7f3e8"), Color("ffcf4a"), Color("e85a4f")]
	for n in 3:
		var boat := Sailboat.new()
		boat.orbit_radius = radius * 1.35 + 90.0 + 60.0 * n
		boat.angle = rng.randf() * TAU
		boat.speed = rng.randf_range(0.004, 0.008) * (1.0 if n % 2 == 0 else -1.0)
		boat.sail_color = sails[n]
		parent.add_child(boat)


static func _build_start_line(parent: Node3D, track: IslandTrack) -> void:
	var r2 := track.right(0)
	var right := Vector3(r2.x, 0, r2.y)
	var basis := Basis(right, Vector3.UP, right.cross(Vector3.UP))
	var origin := _v3(track.points[0], 0.0)
	var left_edge := track.forest_edge(0) - 1.0
	var right_edge := track.water_line(0) + 1.0
	var width := right_edge - left_edge
	var middle := (left_edge + right_edge) / 2.0

	var stripe := BoxMesh.new()
	stripe.size = Vector3(width, 0.04, 0.8)
	var line := MeshInstance3D.new()
	line.mesh = stripe
	line.transform = Transform3D(basis, origin + right * middle + Vector3.UP * 0.02)
	line.material_override = _checker_material(int(width), 1)
	parent.add_child(line)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("7a5232")
	wood.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	for side in [left_edge, right_edge]:
		var post := MeshInstance3D.new()
		post.mesh = MeshKit.cylinder(0.25, 0.22, 6.5, 10)
		post.position = origin + right * side + Vector3.UP * 3.25
		post.material_override = wood
		parent.add_child(post)
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(width, 1.5, 0.15)
	var banner := MeshInstance3D.new()
	banner.mesh = banner_mesh
	banner.transform = Transform3D(basis, origin + right * middle + Vector3.UP * 5.8)
	banner.material_override = _checker_material(int(width * 0.7), 2)
	parent.add_child(banner)


# --- Helpers ------------------------------------------------------------

static func _multimesh(parent: Node3D, mesh: Mesh, transforms: Array[Transform3D], tint: bool,
		rng: RandomNumberGenerator, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for n in transforms.size():
		mm.set_instance_transform(n, transforms[n])
		var shade := rng.randf_range(0.82, 1.12) if tint else 1.0
		mm.set_instance_color(n, Color(shade, shade * rng.randf_range(0.97, 1.03), shade))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = MeshKit.vertex_color_material()
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_to_group("scenery_detail")
	Settings.configure_detail(instance)
	parent.add_child(instance)
	return instance


static func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, shadows: bool) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


static func _ground_material() -> StandardMaterial3D:
	var mat := MeshKit.vertex_color_material()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _checker_material(columns: int, rows: int) -> StandardMaterial3D:
	var image := Image.create(maxi(columns, 2), rows, false, Image.FORMAT_RGB8)
	for x in maxi(columns, 2):
		for y in rows:
			image.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color("1d1d22"))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(image)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return mat


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	for pair: Array in [[a, ca], [b, cb], [c, cc], [a, ca], [c, cc], [d, cd]]:
		st.set_color(pair[1])
		st.add_vertex(pair[0])


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


static func _at(pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)


static func _placed(p: Vector2, y: float, yaw: float, scl: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scl), _v3(p, y))


## Random yaw, size, proportions and a slight tilt, so no two plants match.
static func _varied(p: Vector2, y: float, rng: RandomNumberGenerator, scale_min: float,
		scale_max: float) -> Transform3D:
	var s := rng.randf_range(scale_min, scale_max)
	var shape := Vector3(rng.randf_range(0.85, 1.15), rng.randf_range(0.8, 1.25),
			rng.randf_range(0.85, 1.15)) * s
	var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(),
			rng.randf_range(0.0, 0.08))
	return Transform3D(tilt * Basis(Vector3.UP, rng.randf() * TAU).scaled(shape), _v3(p, y))


## A boulder blocks a circle about the size of its two stones.
static func _add_rock_obstacle(track: IslandTrack, xform: Transform3D) -> void:
	var size := xform.basis.get_scale()
	var center := Vector2(xform.origin.x, xform.origin.z) \
			+ Vector2(xform.basis.x.x, xform.basis.x.z) * 0.3
	track.add_obstacle(center, 1.2 * maxf(size.x, size.z), 1.0 * size.y + xform.origin.y)
