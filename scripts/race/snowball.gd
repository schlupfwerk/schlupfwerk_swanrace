class_name Snowball
extends CourseMover
## A snowball on the Andes road (ADR 0029): it drops from the snowy mountain
## on the right onto a random spot of the road (a shadow on the ground warns
## where), then rolls across to the left and over the cliff, and after a
## pause another one drops somewhere else in its stretch. Each snowball
## follows the race clock (with its own seed), so it is the same for every
## swan. Solid only while on the road: running into one stops the swan, like
## any obstacle (CourseRules); bots steer around it.

## Where this snowball works: a stretch of the road (distance from, to).
var zone_from := 0.0
var zone_to := 0.0
var ball_seed := 0

const FALL_TIME := 1.3
const DROP_HEIGHT := 22.0
const ROLL_SPEED := 4.5
const SIZE := 0.9

var _ball: MeshInstance3D
var _shadow: MeshInstance3D
var _roll := 0.0


func _ready() -> void:
	radius = 0.0
	height = 0.0
	_ball = MeshInstance3D.new()
	_ball.mesh = MeshKit.sphere(SIZE, 14, 8)
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color("f4f7fb")
	snow.roughness = 0.9
	_ball.material_override = snow
	add_child(_ball)
	_shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = SIZE
	disc.bottom_radius = SIZE
	disc.height = 0.02
	_shadow.mesh = disc
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.12, 0.2, 0.45)
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = dark
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	advance(0.0)


## One cycle: wait, fall, roll across the road and off the cliff.
func advance(t: float) -> void:
	if _ball == null:
		return
	var right := track.right_edge(track.index_at(zone_from))
	var left := track.left_edge(track.index_at(zone_from))
	var roll_time := (right - left + 3.0) / ROLL_SPEED
	var wait := 3.0 + float(ball_seed % 5)
	var cycle := wait + FALL_TIME + roll_time
	var time := t + phase
	var n := int(floor(time / cycle))
	var u := time - n * cycle
	var rng := RandomNumberGenerator.new()
	rng.seed = ball_seed * 7919 + n
	distance = rng.randf_range(zone_from, zone_to)
	var land := rng.randf_range(left + 1.0, right - 1.0)
	var i := track.index_at(distance)
	var y_off := 0.0
	if u < wait:
		# Waiting up on the mountain: nothing on the road.
		visible = false
		radius = 0.0
		height = 0.0
		lateral = right + 20.0
	elif u < wait + FALL_TIME:
		# Falling: the shadow grows where it will land. Not solid yet.
		visible = true
		var f := (u - wait) / FALL_TIME
		lateral = land
		y_off = DROP_HEIGHT * (1.0 - f * f) + SIZE
		_shadow.scale = Vector3.ONE * lerpf(0.4, 1.2, f)
		_shadow.visible = true
		radius = 0.0
		height = 0.0
	else:
		# Rolling to the left, over the edge and down the cliff.
		visible = true
		var r := u - wait - FALL_TIME
		lateral = land - r * ROLL_SPEED
		var past := maxf(left - lateral, 0.0)
		y_off = SIZE - past * past * 0.6
		_shadow.visible = false
		var on_road := lateral > left - 0.5
		radius = SIZE * 0.85 if on_road else 0.0
		height = SIZE * 2.0 if on_road else 0.0
		_roll = r * ROLL_SPEED / SIZE
	p = track.edge(i, lateral)
	var ground := track.ground_height_at(distance, clampf(lateral, left, right))
	position = Vector3(p.x, ground, p.y)
	_ball.position = Vector3.UP * y_off
	_shadow.position = Vector3.UP * 0.05
	# Spin as it rolls (around the road's direction).
	var forward := track.tangent(i)
	_ball.basis = Basis(Vector3(forward.x, 0.0, forward.y), -_roll)
