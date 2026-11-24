class_name Footprints
extends Node3D
## Footprints a swan leaves in the sand, fading out in up to 3 seconds.
## The print depends on the footwear: webbed swan feet when barefoot, and a
## different sole for sneakers, boots, shoes and flip-flops.

const LIFETIME := 3.0
const POOL := 18
const SAND_PRINT := Color(0.36, 0.25, 0.15)
## Print size (width, length) in meters per footwear id ("" = barefoot).
const SIZES := {
	"": Vector2(0.5, 0.58),
	"sneakers": Vector2(0.34, 0.6),
	"boots": Vector2(0.38, 0.64),
	"shoes": Vector2(0.3, 0.58),
	"flip_flops": Vector2(0.36, 0.62),
	"socks": Vector2(0.3, 0.5),
}

static var _textures := {}

var swan: Swan

var _multimesh := MultiMesh.new()
var _material := StandardMaterial3D.new()
var _ages: Array[float] = []
var _next := 0
var _footwear := "?"


func _ready() -> void:
	top_level = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = POOL
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	_material.roughness = 1.0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multimesh
	instance.material_override = _material
	# Prints move around the whole island: never cull them by a stale box.
	instance.custom_aabb = AABB(Vector3(-5000, -50, -5000), Vector3(10000, 100, 10000))
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	for i in POOL:
		_ages.append(LIFETIME)
		_multimesh.set_instance_color(i, Color(SAND_PRINT, 0.0))
	swan.model.stepped.connect(_on_stepped)


func _process(delta: float) -> void:
	for i in POOL:
		if _ages[i] >= LIFETIME:
			continue
		_ages[i] += delta
		var fade := 1.0 - clampf(_ages[i] / LIFETIME, 0.0, 1.0)
		_multimesh.set_instance_color(i, Color(SAND_PRINT, 0.9 * fade))


func _on_stepped(_strength: float, foot: int) -> void:
	if swan.in_water or not swan.motor.on_ground:
		return
	var footwear := swan.look.footwear()
	if footwear == "" and swan.look.is_wearing("socks"):
		footwear = "socks"
	if footwear != _footwear:
		_footwear = footwear
		_material.albedo_texture = texture_for(footwear)
	var size: Vector2 = SIZES.get(footwear, SIZES[""])
	var yaw := swan.rotation.y
	var heading := Basis(Vector3.UP, yaw)
	var spot := swan.global_position + heading * Vector3(0.3 * foot, 0.0, -0.1)
	spot.y = swan.ground_y + 0.015
	# Lay the quad flat: its top (the toes) points forward.
	# Mirrored for the left foot, so the big toe is always on the inside.
	var basis := heading * Basis(Vector3.RIGHT, -PI / 2.0) * Basis.from_scale(
			Vector3(size.x * foot, size.y, 1.0))
	_multimesh.set_instance_transform(_next, Transform3D(basis, spot))
	_ages[_next] = 0.0
	_next = (_next + 1) % POOL


## Print texture for a footwear id, drawn once and cached.
static func texture_for(footwear: String) -> ImageTexture:
	if not _textures.has(footwear):
		_textures[footwear] = _draw(footwear)
	return _textures[footwear]


static func _draw(footwear: String) -> ImageTexture:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for py in size:
		for px in size:
			# u: -1 left .. 1 right, v: -1 toes .. 1 heel.
			var u := (px + 0.5) / size * 2.0 - 1.0
			var v := (py + 0.5) / size * 2.0 - 1.0
			image.set_pixel(px, py, Color(1, 1, 1, _alpha(footwear, u, v)))
	return ImageTexture.create_from_image(image)


static func _alpha(footwear: String, u: float, v: float) -> float:
	match footwear:
		"sneakers":
			# Sole with a waist and horizontal tread lines.
			if not _in_sole(u, v, 0.78, 0.2):
				return 0.0
			return 1.0 if fposmod((v + 1.0) * 7.0, 1.0) > 0.35 else 0.45
		"boots":
			# Wide sole with chunky lugs and a separate heel block.
			if v > 0.3 and v < 0.42:
				return 0.0
			if not _in_sole(u, v, 0.85, 0.1):
				return 0.0
			var lugs := fposmod(u * 3.0 + 10.0, 1.0) > 0.25 and fposmod((v + 1.0) * 4.0, 1.0) > 0.25
			return 1.0 if lugs else 0.5
		"shoes":
			# Slim pointed front and a small heel, with nothing in between.
			if v > 0.5:
				return 1.0 if absf(u) < 0.5 and v < 0.95 else 0.0
			if v > 0.15:
				return 0.0
			return 1.0 if _in_sole(u, v * 1.1 - 0.05, 0.7, 0.0) else 0.0
		"socks":
			# Soft rounded print, no toes.
			return 0.6 if _in_sole(u, v, 0.75, 0.05) else 0.0
		"flip_flops":
			# Japanese geta: only the two wooden teeth touch the sand.
			var tooth := absf(v + 0.45) < 0.14 or absf(v - 0.55) < 0.14
			return 1.0 if tooth and absf(u) < 0.85 else 0.0
		_:
			# Ostrich-like foot: a big inner toe, a small outer toe and the heel pad.
			var p := Vector2(u, v)
			if _segment_distance(p, Vector2(-0.1, 0.55), Vector2(-0.3, -0.85)) < 0.2:
				return 1.0
			if _segment_distance(p, Vector2(0.15, 0.5), Vector2(0.5, -0.35)) < 0.14:
				return 0.9
			return 0.8 if p.distance_to(Vector2(0.0, 0.7)) < 0.22 else 0.0


static func _in_sole(u: float, v: float, width: float, waist: float) -> bool:
	var w := width * (1.0 - waist * exp(-pow((v - 0.15) / 0.3, 2.0)))
	return pow(u / w, 2.0) + pow(v, 4.0) < 1.0


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

