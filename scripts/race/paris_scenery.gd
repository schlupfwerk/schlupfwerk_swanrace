class_name ParisScenery
extends RefCounted
## Builds Paris around a ParisCircuit: the cobblestone street with guard
## rails, a sidewalk with old street lamps and café tables on the left, rows
## of typical Parisian buildings (cream stone, iron balconies, slate mansard
## roofs with dormers and chimneys, shops with colored awnings), and on the
## right, inside the loop, a park of lawns, gravel paths and trees with the
## Eiffel Tower in the middle. Also the start gate.

const COBBLE := Color("8e8b86")
const JOINT := Color("5d5a56")
const SIDEWALK := Color("bdb6aa")
const LAWN := Color("6f9a48")
const GRAVEL := Color("d9ccaa")
const STONE := Color("e9dfc9")
const STONE_SHADE := Color("d8ccb2")
const SLATE := Color("5f6b7a")
const IRON := Color("2a2c30")
const WINDOW := Color("3e4b5c")
const TOWER := Color("7a5a3a")
const AWNINGS := [Color("b8322a"), Color("2e6b4f"), Color("2a4f8a"), Color("c9a227")]
const LEAVES := [Color("4f7f3a"), Color("5a8c40")]
const STEP := 2
## The buildings' front, out from the left edge of the street.
const FRONT := 7.0


static func build(parent: Node3D, course: ParisCircuit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1889
	Scenery.add_environment(parent)
	var room := AlpsScenery._room(course)
	_build_ground(parent, course)
	_build_street(parent, course)
	GermanyScenery.build_rails(parent, course)
	_build_buildings(parent, course, room, rng)
	_build_sidewalk_things(parent, course, rng)
	_build_park(parent, course, rng)
	_build_tower(parent, course)
	AlpsScenery._build_gate(parent, course, 0.0, Color("2a4f8a"))


static func _y() -> float:
	return ParisCircuit.GROUND


## The park inside (a big lawn), the sidewalk outside and the city ground.
static func _build_ground(parent: Node3D, course: ParisCircuit) -> void:
	var city := MeshInstance3D.new()
	city.mesh = PlaneMesh.new()
	(city.mesh as PlaneMesh).size = Vector2(3000, 3000)
	city.material_override = Scenery.flat(SIDEWALK.darkened(0.15), 1.0)
	city.position = Vector3(0.0, _y() - 0.05, 0.0)
	city.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(city)
	var st := MeshKit.begin()
	var count := course.sample_count()
	var center := _center(course)
	var i := 0
	while i < count:
		var j := i + STEP
		# Sidewalk on the left, up to the buildings.
		var hw := ParisCircuit.HALF_WIDTH
		IslandScenery._quad(st, _at(course, i, -FRONT - hw - 2.0), _at(course, j, -FRONT - hw - 2.0), _at(course, j, -hw),
				_at(course, i, -hw), SIDEWALK, SIDEWALK, SIDEWALK, SIDEWALK)
		# The lawn: from the right edge to the middle of the loop.
		var a := _at(course, i, hw)
		var b := _at(course, j, hw)
		var c3 := Vector3(center.x, _y() + 0.01, center.y)
		IslandScenery._quad(st, a, b, c3, c3, LAWN, LAWN, LAWN, LAWN)
		i = j
	st.generate_normals()
	IslandScenery._add_mesh(parent, st.commit(), IslandScenery._ground_material(), false)


static func _center(course: CourseTrack) -> Vector2:
	var sum := Vector2.ZERO
	for p in course.points:
		sum += p
	return sum / course.points.size()


static func _at(course: CourseTrack, i: int, lateral: float, lift := 0.01) -> Vector3:
	var p := course.edge(wrapi(i, 0, course.sample_count()), lateral)
	return Vector3(p.x, ParisCircuit.GROUND + lift, p.y)


## The street, paved with cobblestones (a texture of rounded stones in
## staggered rows, 1 tile every 2 m).
static func _build_street(parent: Node3D, course: ParisCircuit) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := course.sample_count()
	var hw := ParisCircuit.HALF_WIDTH
	var y := _y() + 0.02
	var i := 0
	while i < count:
		var j := i + STEP
		var u0 := course.lengths[wrapi(i, 0, count)] / 2.0
		var u1 := u0 + STEP * 1.0 / 2.0
		var quad := [
			[_at(course, i, -hw, 0.02), Vector2(u0, 0.0)],
			[_at(course, j, -hw, 0.02), Vector2(u1, 0.0)],
			[_at(course, j, hw, 0.02), Vector2(u1, hw)],
			[_at(course, i, hw, 0.02), Vector2(u0, hw)],
		]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[k][1])
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[k][0])
		i = j
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _cobble_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	IslandScenery._add_mesh(parent, st.commit(), mat, false)


## Rounded grey stones in staggered rows, with dark joints (one tile = 2 m x 2 m).
static func _cobble_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var rows := 8
	var cols := 8
	var shades := []
	for n in rows * cols:
		shades.append(rng.randf_range(0.85, 1.12))
	for y in size:
		for x in size:
			var row := y * rows / size
			var shift := 0.5 if row % 2 == 1 else 0.0
			var fx := float(x) / size * cols + shift
			var fy := float(y) / size * rows
			var cx := fposmod(fx, 1.0) - 0.5
			var cy := fposmod(fy, 1.0) - 0.5
			var col := int(floor(fx)) % cols
			var d := maxf(absf(cx), absf(cy)) + 0.25 * (absf(cx) + absf(cy))
			var color := JOINT if d > 0.5 else COBBLE * float(shades[row * cols + col])
			image.set_pixel(x, y, color)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# --- Buildings -------------------------------------------------------------------

## A Parisian building facing -Z, `width` wide: five floors of cream stone with
## tall windows, iron balconies on the 2nd and 5th floors, a shop on the
## ground floor with a colored awning, and a slate mansard roof with dormers
## and chimney pots.
static func _building_mesh(width: float, awning: Color) -> Mesh:
	var st := MeshKit.begin()
	var depth := 14.0
	var floors := 5
	var floor_h := 3.3
	var wall_h := 4.2 + floors * floor_h
	_box(st, Vector3(width, wall_h, depth), Vector3(0, wall_h * 0.5, depth * 0.5), STONE)
	# Ground floor: a shop window and the awning over it.
	_box(st, Vector3(width - 1.4, 2.8, 0.1), Vector3(0, 1.6, -0.03), WINDOW)
	var cloth := BoxMesh.new()
	cloth.size = Vector3(width - 1.0, 0.12, 1.8)
	MeshKit.add(st, cloth, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 3.6, -0.85)), awning)
	_box(st, Vector3(width - 1.0, 0.5, 0.06), Vector3(0, 3.15, -1.7), awning.darkened(0.1))
	# A stone band over the shop.
	_box(st, Vector3(width + 0.1, 0.35, 0.3), Vector3(0, 4.1, -0.05), STONE_SHADE)
	# Windows on every floor, balconies on the 2nd and the 5th.
	var windows := maxi(int(width / 2.6), 2)
	for f in floors:
		var y := 4.2 + f * floor_h + 1.5
		for k in windows:
			var x := -width * 0.5 + (k + 0.5) * width / windows
			_box(st, Vector3(1.1, 2.0, 0.1), Vector3(x, y, -0.03), WINDOW)
		if f == 0 or f == 3:
			_box(st, Vector3(width - 0.6, 0.12, 0.7), Vector3(0, y - 1.05, -0.35), STONE_SHADE)
			_box(st, Vector3(width - 0.6, 0.9, 0.04), Vector3(0, y - 0.55, -0.7), IRON)
	# Mansard roof: a steep slate slope at the front with dormers, flat on top.
	var roof := BoxMesh.new()
	roof.size = Vector3(width, 0.25, 3.6)
	MeshKit.add(st, roof, Transform3D(Basis(Vector3.RIGHT, -1.1), Vector3(0, wall_h + 1.5, 0.9)), SLATE)
	_box(st, Vector3(width, 0.3, depth - 2.6), Vector3(0, wall_h + 3.1, depth * 0.5 + 1.2), SLATE.darkened(0.1))
	for k in windows:
		var x := -width * 0.5 + (k + 0.5) * width / windows
		_box(st, Vector3(1.0, 1.4, 0.9), Vector3(x, wall_h + 1.6, 0.6), STONE)
		_box(st, Vector3(0.6, 0.9, 0.1), Vector3(x, wall_h + 1.55, 0.13), WINDOW)
	for x: float in [-width * 0.35, width * 0.35]:
		_box(st, Vector3(0.8, 1.4, 1.0), Vector3(x, wall_h + 3.9, depth * 0.5), Color("b86a4a"))
	return MeshKit.finish(st)


## Rows of buildings along the left (outside) of the street, facing it.
static func _build_buildings(parent: Node3D, course: ParisCircuit, room: PackedVector2Array,
		rng: RandomNumberGenerator) -> void:
	var variants := 6
	var lists := []
	for n in variants:
		lists.append([] as Array[Transform3D])
	var widths := [10.0, 12.0, 14.0, 11.0, 13.0, 15.0]
	var d := 0.0
	var hw := ParisCircuit.HALF_WIDTH
	while d < course.length:
		var n := rng.randi_range(0, variants - 1)
		var w: float = widths[n]
		var i := course.index_at(d + w * 0.5)
		var p := course.edge(i, -hw - FRONT)
		var toward := course.right(i)
		var yaw := atan2(-toward.x, -toward.y)
		(lists[n] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, _y(), p.y)))
		d += w + 0.2
	for n in variants:
		IslandScenery._multimesh(parent, _building_mesh(widths[n], AWNINGS[n % AWNINGS.size()]), lists[n], true, rng)


## Old street lamps along the sidewalk and a few café tables with chairs.
static func _build_sidewalk_things(parent: Node3D, course: ParisCircuit, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	var hw := ParisCircuit.HALF_WIDTH
	var d := 6.0
	var n := 0
	while d < course.length:
		var i := course.index_at(d)
		var lamp := _at(course, i, -hw - 1.6, 0.0)
		MeshKit.add(st, MeshKit.cylinder(0.12, 0.08, 4.2, 8), IslandScenery._at(lamp + Vector3.UP * 2.1), IRON)
		MeshKit.add(st, MeshKit.cylinder(0.25, 0.18, 0.6, 6), IslandScenery._at(lamp + Vector3.UP * 4.5), Color("f4e7b8"))
		MeshKit.add(st, MeshKit.cylinder(0.35, 0.05, 0.3, 6), IslandScenery._at(lamp + Vector3.UP * 4.95), IRON)
		if n % 3 == 1:
			for k in 2:
				var table := _at(course, i + 3 + k * 4, -hw - 4.5, 0.0)
				MeshKit.add(st, MeshKit.cylinder(0.05, 0.05, 0.75, 6), IslandScenery._at(table + Vector3.UP * 0.37), IRON)
				MeshKit.add(st, MeshKit.cylinder(0.4, 0.4, 0.04, 12), IslandScenery._at(table + Vector3.UP * 0.76),
						Color("f2f2ee"))
				# Two chairs, one on each side of the table along the street.
				var along := course.tangent(i)
				for side: float in [-0.7, 0.7]:
					var chair := table + Vector3(along.x, 0.0, along.y) * side
					_box(st, Vector3(0.4, 0.45, 0.4), chair + Vector3.UP * 0.22, Color("b8322a"))
		d += 18.0
		n += 1
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)


# --- The park and the tower ------------------------------------------------------

## Rows of round trees along the inside of the street and gravel paths
## crossing the lawn towards the tower.
static func _build_park(parent: Node3D, course: ParisCircuit, rng: RandomNumberGenerator) -> void:
	var trees := [[] as Array[Transform3D], [] as Array[Transform3D]]
	var hw := ParisCircuit.HALF_WIDTH
	var d := 4.0
	while d < course.length:
		var i := course.index_at(d)
		var p := course.edge(i, hw + 4.0)
		(trees[rng.randi_range(0, 1)] as Array[Transform3D]).append(IslandScenery._varied(p, _y(), rng, 0.85, 1.1))
		d += 11.0
	for n in 2:
		IslandScenery._multimesh(parent, SaoPauloScenery._tree_mesh(LEAVES[n]), trees[n], true, rng)
	var st := MeshKit.begin()
	var center := _center(course)
	for k in 4:
		var i := course.index_at(course.length * (k + 0.5) / 4.0)
		var a := course.edge(i, hw + 6.0)
		var mid := (a + center) * 0.5
		var path := BoxMesh.new()
		path.size = Vector3(5.0, 0.04, a.distance_to(center))
		MeshKit.add(st, path, Transform3D(Basis(Vector3.UP, atan2(-(center - a).x, -(center - a).y)),
				Vector3(mid.x, _y() + 0.03, mid.y)), GRAVEL)
	MeshKit.add(st, MeshKit.cylinder(34.0, 34.0, 0.05, 32), IslandScenery._at(Vector3(center.x, _y() + 0.035, center.y)),
			GRAVEL)
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), false)


## The Eiffel Tower in the middle of the park (about 150 m, scaled down to
## fit): four legs leaning in with arches between them, two platforms, and the
## tall spire with the antenna. Cross bracing gives the iron-lattice look.
static func _build_tower(parent: Node3D, course: ParisCircuit) -> void:
	var st := MeshKit.begin()
	var c := _center(course)
	var base := Vector3(c.x, _y(), c.y)
	var levels := [
		# [height, half-width of the square of the legs]
		[0.0, 26.0], [34.0, 13.0], [70.0, 6.5], [128.0, 1.6], [150.0, 0.5],
	]
	for l in levels.size() - 1:
		var h0: float = levels[l][0]
		var h1: float = levels[l + 1][0]
		var w0: float = levels[l][1]
		var w1: float = levels[l + 1][1]
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var a := base + Vector3(sx * w0, h0, sz * w0)
				var b := base + Vector3(sx * w1, h1, sz * w1)
				RioScenery._bar(st, a, b, maxf(2.2 - l * 0.6, 0.35), TOWER)
		# Cross bracing on the four faces.
		var steps := 4 if l < 2 else 6
		for k in steps:
			var u0 := float(k) / steps
			var u1 := float(k + 1) / steps
			var hh0 := lerpf(h0, h1, u0)
			var hh1 := lerpf(h0, h1, u1)
			var ww0 := lerpf(w0, w1, u0)
			var ww1 := lerpf(w0, w1, u1)
			for face in 4:
				var axis := Vector3(1, 0, 0) if face < 2 else Vector3(0, 0, 1)
				var normal := Vector3(0, 0, 1) if face < 2 else Vector3(1, 0, 0)
				var s := 1.0 if face % 2 == 0 else -1.0
				var p0 := base + normal * s * ww0 + axis * -ww0 + Vector3.UP * hh0
				var p1 := base + normal * s * ww1 + axis * ww1 + Vector3.UP * hh1
				var p2 := base + normal * s * ww0 + axis * ww0 + Vector3.UP * hh0
				var p3 := base + normal * s * ww1 + axis * -ww1 + Vector3.UP * hh1
				RioScenery._bar(st, p0, p1, 0.25, TOWER.darkened(0.1))
				RioScenery._bar(st, p2, p3, 0.25, TOWER.darkened(0.1))
	# Platforms.
	_box(st, Vector3(32.0, 3.0, 32.0), base + Vector3.UP * 34.0, TOWER.darkened(0.15))
	_box(st, Vector3(16.0, 2.4, 16.0), base + Vector3.UP * 70.0, TOWER.darkened(0.15))
	_box(st, Vector3(4.0, 4.0, 4.0), base + Vector3.UP * 128.0, TOWER.darkened(0.15))
	RioScenery._bar(st, base + Vector3.UP * 128.0, base + Vector3.UP * 158.0, 0.25, Color("d8d8d8"))
	# Arches between the legs at the base.
	for face in 4:
		var axis := Vector3(1, 0, 0) if face < 2 else Vector3(0, 0, 1)
		var normal := Vector3(0, 0, 1) if face < 2 else Vector3(1, 0, 0)
		var s := 1.0 if face % 2 == 0 else -1.0
		var segments := 10
		for k in segments:
			var a0 := PI * k / segments
			var a1 := PI * (k + 1) / segments
			var r := 17.0
			var p0 := base + normal * s * 21.0 + axis * (-cos(a0) * r) + Vector3.UP * (10.0 + sin(a0) * 14.0)
			var p1 := base + normal * s * 21.0 + axis * (-cos(a1) * r) + Vector3.UP * (10.0 + sin(a1) * 14.0)
			RioScenery._bar(st, p0, p1, 0.6, TOWER)
	IslandScenery._add_mesh(parent, st.commit(), MeshKit.vertex_color_material(), true)


static func _box(st: SurfaceTool, size: Vector3, center: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	MeshKit.add(st, box, Transform3D(Basis.IDENTITY, center), color)
