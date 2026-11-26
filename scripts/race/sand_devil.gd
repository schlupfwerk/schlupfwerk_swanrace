class_name SandDevil
extends CourseMover
## A whirling sand devil in the Egypt desert: a tall funnel of spinning sand
## rings, narrow at the ground and wide at the top, swaying as it wanders
## across the road (CourseMover WANDER). Solid and too tall to jump: steer
## around it. Big and bright so it is easy to see coming.

const RINGS := 14
const TALL := 7.0
const SAND := Color("e8b45a")
const SAND_DARK := Color("b8833a")

var _spin: Node3D
var _time := 0.0


func _ready() -> void:
	_spin = Node3D.new()
	add_child(_spin)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var st := MeshKit.begin()
	for n in RINGS:
		var u := float(n) / (RINGS - 1)
		var r := lerpf(0.35, 2.0, u * u)
		var y := u * TALL
		# Each ring sits a little off the axis, turning with height: a spiral.
		var offset := Vector3(cos(u * TAU * 1.5), 0.0, sin(u * TAU * 1.5)) * (0.25 + u * 0.5)
		var ring := TorusMesh.new()
		ring.inner_radius = r * 0.8
		ring.outer_radius = r
		ring.rings = 20
		ring.ring_segments = 6
		var color := (SAND if n % 2 == 0 else SAND_DARK)
		color.a = lerpf(0.95, 0.55, u)
		MeshKit.add(st, ring, Transform3D(Basis(Vector3.RIGHT, 0.15 * sin(u * 9.0)), offset + Vector3.UP * y), color)
	# A swirl of sand on the ground at its foot.
	var dust := CylinderMesh.new()
	dust.top_radius = 1.6
	dust.bottom_radius = 1.9
	dust.height = 0.3
	dust.radial_segments = 16
	var floor_color := SAND
	floor_color.a = 0.7
	MeshKit.add(st, dust, Transform3D(Basis.IDENTITY, Vector3.UP * 0.15), floor_color)
	var body := MeshInstance3D.new()
	body.mesh = MeshKit.finish(st)
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(body)
	advance(0.0)


func _process(delta: float) -> void:
	_time += delta
	if _spin:
		_spin.rotate_y(delta * 7.0)
		# Sway the top a little.
		_spin.rotation.x = 0.06 * sin(_time * 1.3)
		_spin.rotation.z = 0.06 * cos(_time * 1.1)
