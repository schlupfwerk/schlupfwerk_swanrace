class_name BotBrain
extends SwanBrain
## A local AI racer. It only produces a SwanIntent, exactly like PlayerInput,
## so bots follow the same rules and physics as the player.
##
## `skill` (0..1) shapes everything: how straight it drives, how often it gets
## a jump right, whether it uses the turbo and the speed pads, how many small
## mistakes it makes. On easy, a bot far ahead of the player eases off.

const LOOK_AHEAD := 9 # track samples (~1.1 m each)

var skill := 0.6
var track: IslandTrack
var swan: Swan
var laps: LapTracker
## The player's lap tracker, for easy mode's catch-up.
var player_laps: LapTracker
var rubber_band := false

var _rng := RandomNumberGenerator.new()
## Preferred place across the sand (meters from the racing line).
var _lane := 0.0
var _lane_timer := 0.0
## A short mistake: steering off for a moment.
var _wobble := 0.0
var _wobble_time := 0.0
var _jump_planned := false
## Going around a log it got stuck on: lateral target and time left.
var _detour := 0.0
var _detour_time := 0.0
var _turbo_hold := 0.0


func _init(p_skill: float, seed_value: int) -> void:
	skill = clampf(p_skill, 0.0, 1.0)
	_rng.seed = seed_value
	_lane = _rng.randf_range(-4.0, 4.0)


func update_intent(intent: SwanIntent, tick: float) -> void:
	intent.reset()
	var motor := swan.motor
	var i := laps.hint
	var distance := laps.distance

	# Drift to a new preferred lane now and then; a good bot aims for speed pads.
	_lane_timer -= tick
	if _lane_timer <= 0.0:
		_lane_timer = _rng.randf_range(3.0, 7.0)
		_lane = _rng.randf_range(-5.0, 5.0)
	var target_lateral := _lane
	for pad in track.boosters:
		var gap := fposmod(pad.distance - distance, IslandTrack.LAP_LENGTH)
		if gap > 4.0 and gap < 35.0 and _rng.randf() < skill * 0.05:
			_lane = pad.lateral
	# On the lake, good bots take a bridge (and must jump its hole).
	var lake_gap := -track.lake_along(distance)
	if lake_gap > 0.0 and lake_gap < 25.0:
		var lake_i := track.index_at(IslandTrack.LAKE_START * IslandTrack.LAP_LENGTH)
		var left := track.forest_edge(lake_i) + 1.0
		var width := (track.water_line(lake_i) - 1.0 - left) / 5.0
		var bridge := 1.5 if _lane < 0.0 else 3.5
		target_lateral = left + width * bridge if skill > 0.45 else left + width * 2.5
	# Stuck in front of a log (slow, after a bump): go around its nearer end.
	_detour_time -= tick
	if motor.speed < 4.0 and motor.on_ground and not swan.is_stunned():
		var log := track.log_ahead(distance, laps.lateral, 4.0)
		if not log.is_empty() and _detour_time <= 0.0:
			var side := -1.0 if laps.lateral < log.lateral else 1.0
			_detour = log.lateral + side * (IslandTrack.LOG_LENGTH * 0.5 + 2.0)
			_detour_time = 3.0
	if _detour_time > 0.0:
		target_lateral = _detour
	# Stay on the sand, well away from the forest and the sea.
	target_lateral = clampf(target_lateral, track.forest_edge(i) + 2.5, track.water_line(i) - 2.5)

	# Steer towards a point ahead on its lane, with small human wobbles.
	# Walking around a log: aim almost sideways, right past its end.
	var aim := track.edge(i + (1 if _detour_time > 0.0 else LOOK_AHEAD), target_lateral)
	var to := aim - Vector2(motor.position.x, motor.position.z)
	var diff := wrapf(atan2(-to.x, -to.y) - motor.heading, -PI, PI)
	_wobble_time -= tick
	if _wobble_time <= 0.0 and _rng.randf() < (1.0 - skill) * 0.01:
		_wobble_time = _rng.randf_range(0.3, 0.9)
		_wobble = _rng.randf_range(-0.8, 0.8)
	var wobble := _wobble if _wobble_time > 0.0 else 0.0
	intent.steer = clampf(-diff * (2.0 + skill * 1.5) + wobble, -1.0, 1.0)

	# Throttle: better bots push harder; easy bots wait for the player.
	var throttle := 0.84 + 0.16 * skill
	if rubber_band and player_laps:
		var lead := laps.progress() - player_laps.progress()
		if lead > 35.0:
			throttle *= 0.55
		elif lead > 15.0:
			throttle *= 0.8
	intent.accel = throttle
	# Brake a little for the sharpest turns when going fast (careful bots).
	if absf(diff) > 0.9 and motor.speed_ratio() > 0.7:
		intent.brake = 0.3 * skill

	# Jumps: logs and bridge holes. Timing gets sloppier with less skill. After
	# a bump it walks around the log instead (see the detour above).
	if swan.is_stunned():
		_jump_planned = false
	var jump_from := 1.5 + motor.speed * 0.22
	if track.obstacle_ahead(distance, laps.lateral, 0.0, jump_from + 1.5):
		if not _jump_planned and _detour_time <= 0.0:
			_jump_planned = true
			if _rng.randf() < 0.45 + 0.5 * skill:
				intent.jump = true
	else:
		_jump_planned = false

	# Turbo on climbs, if it has stamina and the skill to save it for them.
	_turbo_hold -= tick
	if motor.slope > 0.06 and motor.stamina > 0.4 and _rng.randf() < skill * 0.03:
		_turbo_hold = _rng.randf_range(1.0, 2.5)
	intent.turbo = _turbo_hold > 0.0
