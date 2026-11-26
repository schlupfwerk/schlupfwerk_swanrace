class_name CourseBotBrain
extends SwanBrain
## A local AI racer for point-to-point courses (the course counterpart of
## BotBrain). It only produces a SwanIntent, like PlayerInput, so bots follow
## the same rules and physics as the player.
##
## `skill` (0..1) shapes everything: how early it sees trees, rocks and
## animals and steers around them, how often it gets a log jump right, how
## much it tucks on the snow and how many small mistakes it makes. On easy, a
## bot far ahead of the player eases off.

const LOOK_AHEAD := 9 # samples (1 m each)
## How far ahead (m) a bot looks for things in the way: more with skill and speed.
const SIGHT_MIN := 8.0
const SIGHT_MAX := 26.0

var skill := 0.6
var track: CourseTrack
var swan: Swan
var tracker: CourseTracker
## The player's tracker, for easy mode's catch-up.
var player_tracker: CourseTracker
var rubber_band := false

var _rng := RandomNumberGenerator.new()
## Preferred place across the course (meters from the center line).
var _lane := 0.0
var _lane_timer := 0.0
var _wobble := 0.0
var _wobble_time := 0.0
var _jump_planned := false
## Steering around something in the way: lateral target and time left.
var _dodge := 0.0
var _dodge_time := 0.0
var _turbo_hold := 0.0


func _init(p_skill: float, seed_value: int) -> void:
	skill = clampf(p_skill, 0.0, 1.0)
	_rng.seed = seed_value
	_lane = _rng.randf_range(-3.0, 3.0)


func update_intent(intent: SwanIntent, tick: float) -> void:
	intent.reset()
	var motor := swan.motor
	var i := tracker.hint
	var distance := tracker.distance
	var lateral := tracker.lateral
	var left := track.left_edge(i)
	var right := track.right_edge(i)

	# Drift to a new preferred lane now and then (wider on the open slope).
	_lane_timer -= tick
	if _lane_timer <= 0.0:
		_lane_timer = _rng.randf_range(3.0, 7.0)
		var room := minf(-left, right) * 0.6
		_lane = _rng.randf_range(-room, room)
	var target_lateral := _lane

	# Something in the way (tree, rock, animal): steer around it, on the side
	# with more room. Better bots see it sooner.
	_dodge_time -= tick
	var sight := lerpf(SIGHT_MIN, SIGHT_MAX, skill) + motor.speed * 0.4
	var blocker := track.blocker_ahead(distance, lateral, sight)
	if not blocker.is_empty() and _dodge_time <= 0.0 and _rng.randf() < 0.3 + 0.7 * skill:
		var clearance: float = blocker.r + 1.6
		var to_left: float = blocker.l - clearance
		var to_right: float = blocker.l + clearance
		var go_left := to_left - left > right - to_right
		if absf(to_left - lateral) < absf(to_right - lateral) and to_left > left + 1.0:
			go_left = true
		elif to_right < right - 1.0 and absf(to_right - lateral) < absf(to_left - lateral):
			go_left = false
		_dodge = to_left if go_left else to_right
		_dodge_time = 1.2
	if _dodge_time > 0.0:
		target_lateral = _dodge
	target_lateral = clampf(target_lateral, left + 1.5, right - 1.5)

	# Steer towards a point ahead on its lane, with small human wobbles.
	var aim := track.edge(i + LOOK_AHEAD, target_lateral)
	var to := aim - Vector2(motor.position.x, motor.position.z)
	var diff := wrapf(atan2(-to.x, -to.y) - motor.heading, -PI, PI)
	_wobble_time -= tick
	if _wobble_time <= 0.0 and _rng.randf() < (1.0 - skill) * 0.01:
		_wobble_time = _rng.randf_range(0.3, 0.9)
		_wobble = _rng.randf_range(-0.8, 0.8)
	var wobble := _wobble if _wobble_time > 0.0 else 0.0
	intent.steer = clampf(-diff * (2.0 + skill * 1.5) + wobble, -1.0, 1.0)

	# Throttle (a tuck on the snow): better bots push harder; easy bots wait.
	var throttle := 0.84 + 0.16 * skill
	if motor.skiing:
		throttle = 0.5 + 0.5 * skill
	if rubber_band and player_tracker:
		var lead := tracker.progress() - player_tracker.progress()
		if lead > 35.0:
			throttle *= 0.55
		elif lead > 15.0:
			throttle *= 0.8
	intent.accel = throttle
	# Brake a little for the sharpest turns when going fast (careful bots).
	if absf(diff) > 0.9 and motor.speed_ratio() > 0.7:
		intent.brake = 0.3 * skill

	# Logs: jump them. Timing gets sloppier with less skill.
	if swan.is_stunned():
		_jump_planned = false
	var jump_from := 1.5 + motor.speed * 0.22
	if track.obstacle_ahead(distance, lateral, 0.0, jump_from + 1.5):
		if not _jump_planned:
			_jump_planned = true
			if _rng.randf() < 0.45 + 0.5 * skill:
				intent.jump = true
	else:
		_jump_planned = false

	# Turbo on climbs (road), if it has stamina and the skill to save it.
	_turbo_hold -= tick
	if not motor.skiing and motor.slope > 0.05 and motor.stamina > 0.4 and _rng.randf() < skill * 0.03:
		_turbo_hold = _rng.randf_range(1.0, 2.5)
	intent.turbo = _turbo_hold > 0.0
	if intent.turbo:
		intent.accel = 1.0
