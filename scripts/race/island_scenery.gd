class_name IslandScenery
extends RefCounted
## Builds the island around an IslandTrack: beach, sea with waves and foam,
## Atlantic forest on hills, palm trees and the start line.
## Decoration only: nothing here collides with the swans.

const SAND := Color("e6cb98")
const WET_SAND := Color("b8956a")
const FOREST_FLOOR := Color("3a6629")
const HILL_TOP := Color("5c8c36")
const SEA_LEVEL := -0.6
const WATER_SHADER := preload("res://shaders/water.gdshader")
const FOAM_SHADER := preload("res://shaders/foam.gdshader")

## Hills inside the island: center (fraction of the island radius), height (m)
## and width (fraction of the island radius).
const HILLS := [
	[Vector2(0.05, -0.1), 38.0, 0.34],
	[Vector2(-0.3, 0.2), 26.0, 0.26],
	[Vector2(0.32, 0.28), 22.0, 0.22],
	[Vector2(-0.1, 0.5), 15.0, 0.2],
]
## Beach cross-section, from the forest to the open sea: lateral offset,
## height and color.
const BEACH_PROFILE := [
	[-22.0, 0.04, Color("bfa071")],
	[-16.0, 0.0, Color("d6b783")],
	[14.0, 0.0, Color("d6b783")],
	[22.0, -0.35, Color("b8956a")],
	[34.0, -1.4, Color("8f7352")],
]
const FOREST_STEP := 4
const FOREST_RINGS := 20


static func build(parent: Node3D, track: IslandTrack, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var radius := IslandTrack.LAP_LENGTH / TAU
	_build_sea(parent, radius)
	_build_beach(parent, track)
	_build_foam(parent, track)
	_build_forest_floor(parent, track, radius)
	_build_trees(parent, track, radius, rng)
	_build_palms(parent, track, rng)
	_build_beach_details(parent, track, rng)
	_build_start_line(parent, track)


## Ground height inside the island. `f` is 0 at the center, 1 at the forest edge.
static func ground_height(p: Vector2, f: float, radius: float) -> float:
	var height := 0.0
	for hill: Array in HILLS:
		var center: Vector2 = hill[0] * radius
		var width: float = hill[2] * radius
		height += hill[1] * exp(-p.distance_squared_to(center) / (width * width))
	return height * (1.0 - smoothstep(0.6, 0.95, f)) + 0.04


static func _build_sea(parent: Node3D, radius: float) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1800, 1800)
	mesh.subdivide_width = 180
	mesh.subdivide_depth = 180
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("shore_radius", radius + 25.0)
	var sea := MeshInstance3D.new()
	sea.mesh = mesh
	sea.material_override = mat
	sea.position.y = SEA_LEVEL
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sea)


static func _build_beach(parent: Node3D, track: IslandTrack) -> void:
	var st := MeshKit.begin()
	for i in IslandTrack.SAMPLES:
		for j in BEACH_PROFILE.size() - 1:
			var a: Array = BEACH_PROFILE[j]
			var b: Array = BEACH_PROFILE[j + 1]
			_quad(st,
					_v3(track.edge(i, a[0]), a[1]), _v3(track.edge(i + 1, a[0]), a[1]),
					_v3(track.edge(i + 1, b[0]), b[1]), _v3(track.edge(i, b[0]), b[1]),
					a[2], a[2], b[2], b[2])
	st.generate_normals()
	_add_mesh(parent, st.commit(), _ground_material(), false)


static func _build_foam(parent: Node3D, track: IslandTrack) -> void:
	var st := MeshKit.begin()
	var outer := 46.0
	var inner := 23.0
	for i in IslandTrack.SAMPLES:
		var u0 := float(i) / IslandTrack.SAMPLES * 64.0
		var u1 := float(i + 1) / IslandTrack.SAMPLES * 64.0
		var y := SEA_LEVEL + 0.1
		var p := [_v3(track.edge(i, outer), y), _v3(track.edge(i + 1, outer), y),
				_v3(track.edge(i + 1, inner), y), _v3(track.edge(i, inner), y)]
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
	var edge_offset: float = BEACH_PROFILE[0][0]
	var count := IslandTrack.SAMPLES / FOREST_STEP
	for k in count:
		var edge_a := track.edge(k * FOREST_STEP, edge_offset)
		var edge_b := track.edge((k + 1) * FOREST_STEP, edge_offset)
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
				c.append(FOREST_FLOOR.lerp(HILL_TOP, clampf(h / 30.0, 0.0, 1.0)))
			_quad(st, v[0], v[1], v[2], v[3], c[0], c[1], c[2], c[3])
	st.generate_normals()
	_add_mesh(parent, st.commit(), _ground_material(), true)


static func _build_trees(parent: Node3D, track: IslandTrack, radius: float,
		rng: RandomNumberGenerator) -> void:
	var greens := [Color("2f6b2a"), Color("3f7f2f"), Color("4f8f35"), Color("2a5a26")]
	# Round canopy tree, the bulk of the forest.
	var st := MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.35, 0.25, 6.0), _at(Vector3(0, 3.0, 0)), Color("6b4a2e"))
	MeshKit.add(st, MeshKit.sphere(2.6), _at(Vector3(0, 6.6, 0)), greens[1])
	MeshKit.add(st, MeshKit.sphere(2.0), _at(Vector3(1.7, 5.9, 0.4)), greens[0])
	MeshKit.add(st, MeshKit.sphere(2.1), _at(Vector3(-1.5, 6.0, -0.6)), greens[2])
	MeshKit.add(st, MeshKit.sphere(1.7), _at(Vector3(0.2, 8.0, 0.9)), greens[1])
	_scatter_forest(parent, st.commit(), 650, track, radius, rng, 0.7, 1.4, true)

	# Tall emergent tree with a wide, flat crown.
	st = MeshKit.begin()
	MeshKit.add(st, MeshKit.cylinder(0.45, 0.3, 11.0), _at(Vector3(0, 5.5, 0)), Color("7a5a3a"))
	MeshKit.add(st, MeshKit.sphere(3.4), _at(Vector3(0, 11.5, 0), Vector3(1.3, 0.55, 1.3)),
			greens[3])
	MeshKit.add(st, MeshKit.sphere(2.2), _at(Vector3(2.4, 11.0, 0.5), Vector3(1.2, 0.6, 1.2)),
			greens[0])
	_scatter_forest(parent, st.commit(), 90, track, radius, rng, 0.8, 1.3, true)

	# Flowering trees of the Atlantic forest: yellow ipê and purple quaresmeira.
	for flower: Color in [Color("f2c418"), Color("9b4fc4")]:
		st = MeshKit.begin()
		MeshKit.add(st, MeshKit.cylinder(0.3, 0.2, 6.5), _at(Vector3(0, 3.25, 0)), Color("6b4a2e"))
		MeshKit.add(st, MeshKit.sphere(2.3), _at(Vector3(0, 7.0, 0)), flower)
		MeshKit.add(st, MeshKit.sphere(1.6), _at(Vector3(1.3, 6.4, 0.3)), flower.darkened(0.1))
		MeshKit.add(st, MeshKit.sphere(1.5), _at(Vector3(-1.2, 6.6, -0.4)), flower.lightened(0.1))
		_scatter_forest(parent, st.commit(), 28, track, radius, rng, 0.8, 1.2, false)

	# Undergrowth where the forest meets the sand.
	st = MeshKit.begin()
	MeshKit.add(st, MeshKit.sphere(0.9), _at(Vector3(0, 0.5, 0), Vector3(1.2, 0.8, 1.0)), greens[2])
	MeshKit.add(st, MeshKit.sphere(0.7), _at(Vector3(0.8, 0.4, 0.2)), greens[1])
	MeshKit.add(st, MeshKit.sphere(0.6), _at(Vector3(-0.7, 0.35, -0.2)), greens[0])
	var bushes: Array[Transform3D] = []
	for n in 420:
		var i := rng.randi_range(0, IslandTrack.SAMPLES - 1)
		var p := track.edge(i, rng.randf_range(-27.0, -17.5))
		bushes.append(_placed(p, 0.0, rng.randf() * TAU, rng.randf_range(0.7, 1.6)))
	_multimesh(parent, st.commit(), bushes, true, rng)


static func _scatter_forest(parent: Node3D, mesh: Mesh, count: int, track: IslandTrack,
		radius: float, rng: RandomNumberGenerator, scale_min: float, scale_max: float,
		tint: bool) -> void:
	var edge_offset: float = BEACH_PROFILE[0][0]
	var transforms: Array[Transform3D] = []
	for n in count:
		var i := rng.randi_range(0, IslandTrack.SAMPLES - 1)
		# sqrt keeps the density even over the island's area.
		var f := sqrt(rng.randf_range(0.0, 0.94))
		var p := track.edge(i, edge_offset - 3.0) * f
		var y := ground_height(p, f, radius) - 0.2
		transforms.append(_placed(p, y, rng.randf() * TAU, rng.randf_range(scale_min, scale_max)))
	_multimesh(parent, mesh, transforms, tint, rng)


static func _build_palms(parent: Node3D, track: IslandTrack, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var trunk := Color("8a6a45")
	# A gently curved trunk made of stacked segments.
	var top := Vector3.ZERO
	for j in 5:
		var bend := 0.18 * j * j
		var center := Vector3(bend, 0.9 + 1.7 * j, 0)
		MeshKit.add(st, MeshKit.cylinder(0.24 - 0.02 * j, 0.22 - 0.02 * j, 1.8, 6),
				_at(center, Vector3.ONE, Vector3(0, 0, -0.08 * j)), trunk.darkened(0.06 * (j % 2)))
		top = center + Vector3(0.1 * j, 0.9, 0)
	# Fronds radiating and drooping from the top.
	for k in 8:
		var yaw := TAU * k / 8.0
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var frond := Basis(Vector3.UP, -yaw) * Basis(Vector3.FORWARD, 0.35)
		var xform := Transform3D(frond, top + dir * 1.7 + Vector3.DOWN * 0.4)
		MeshKit.add(st, MeshKit.sphere(1.0, 8, 4),
				xform * Transform3D(Basis.from_scale(Vector3(2.1, 0.08, 0.38)), Vector3.ZERO),
				Color("4f9a36") if k % 2 == 0 else Color("3f862d"))
	for k in 3:
		var a := TAU * k / 3.0
		MeshKit.add(st, MeshKit.sphere(0.2, 6, 4),
				_at(top + Vector3(cos(a) * 0.3, -0.35, sin(a) * 0.3)), Color("6b4a22"))
	var palms: Array[Transform3D] = []
	for n in 150:
		var i := rng.randi_range(0, IslandTrack.SAMPLES - 1)
		var p := track.edge(i, rng.randf_range(-24.0, -17.0))
		# Lean the trunk out towards the sea, like real beach palms.
		var r := track.right(i)
		var lean := atan2(r.y, r.x)
		var basis := Basis(Vector3.UP, -lean) * Basis.from_scale(Vector3.ONE * rng.randf_range(0.85, 1.25))
		palms.append(Transform3D(basis, _v3(p, -0.1)))
	_multimesh(parent, st.commit(), palms, false, rng)


static func _build_beach_details(parent: Node3D, track: IslandTrack,
		rng: RandomNumberGenerator) -> void:
	var shell := MeshKit.begin()
	MeshKit.add(shell, MeshKit.sphere(0.12, 6, 3), _at(Vector3.ZERO, Vector3(1.0, 0.5, 1.3)),
			Color.WHITE)
	var shells: Array[Transform3D] = []
	for n in 500:
		var i := rng.randi_range(0, IslandTrack.SAMPLES - 1)
		var p := track.edge(i, rng.randf_range(-15.0, 21.0))
		shells.append(_placed(p, 0.0, rng.randf() * TAU, rng.randf_range(0.5, 1.6)))
	var mm := _multimesh(parent, shell.commit(), shells, false, rng, false)
	# Shells and pebbles in a few beach colors.
	var palette := [Color("f3e6d3"), Color("d9b38c"), Color("a39a90"), Color("f0c6b8")]
	for n in mm.multimesh.instance_count:
		mm.multimesh.set_instance_color(n, palette[rng.randi() % palette.size()])


static func _build_start_line(parent: Node3D, track: IslandTrack) -> void:
	var r2 := track.right(0)
	var right := Vector3(r2.x, 0, r2.y)
	var basis := Basis(right, Vector3.UP, right.cross(Vector3.UP))
	var origin := _v3(track.points[0], 0.0)

	var stripe := BoxMesh.new()
	stripe.size = Vector3(36.0, 0.04, 0.8)
	var line := MeshInstance3D.new()
	line.mesh = stripe
	line.transform = Transform3D(basis, origin + right * 1.0 + Vector3.UP * 0.02)
	line.material_override = _checker_material(36, 1)
	parent.add_child(line)

	var wood := MeshKit.vertex_color_material()
	wood.vertex_color_use_as_albedo = false
	wood.albedo_color = Color("7a5232")
	for side in [-18.0, 19.0]:
		var post := MeshInstance3D.new()
		post.mesh = MeshKit.cylinder(0.25, 0.22, 6.5, 10)
		post.position = origin + right * side + Vector3.UP * 3.25
		post.material_override = wood
		parent.add_child(post)
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(37.0, 1.5, 0.15)
	var banner := MeshInstance3D.new()
	banner.mesh = banner_mesh
	banner.transform = Transform3D(basis, origin + right * 0.5 + Vector3.UP * 5.8)
	banner.material_override = _checker_material(24, 2)
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
		mm.set_instance_color(n, Color(shade, shade, shade))
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
	var image := Image.create(columns, rows, false, Image.FORMAT_RGB8)
	for x in columns:
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
