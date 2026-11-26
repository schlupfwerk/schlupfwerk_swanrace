class_name SwanMotor
extends RefCounted
## Handwritten, deterministic arcade movement on flat ground (ADR 0006).
## Every swan uses exactly these numbers: there are no faster or slower swans.

## A swan, not a car: slow build-up and at most 50 km/h on the ground.
const MAX_SPEED := 13.9 # m/s, 50 km/h
const ACCELERATION := 3.1 # about 4.5 s from 0 to top speed
## Full brake stops from top speed in about 1.2 s; half the trigger, half the force.
const BRAKE_DECELERATION := 12.0
const COAST_DECELERATION := 1.6
const TURN_RATE_SLOW := 2.4 # rad/s when almost stopped
const TURN_RATE_FAST := 1.6 # rad/s at top speed
const AIR_CONTROL := 0.35
const JUMP_VELOCITY := 6.5
const GRAVITY := 24.0
## Coming down from a jump the swan glides with open wings: gentle fall.
const GLIDE_GRAVITY := 7.0
const MAX_GLIDE_FALL := 3.5
## Turning has a cost: while steering, the top speed drops 1% every 0.1 s
## (scaled by how hard you steer), down to 70%. It recovers when you let go.
const TURN_CAP_LOSS_PER_SECOND := 0.1
const TURN_CAP_MIN := 0.7
const TURN_CAP_RECOVERY_PER_SECOND := 0.35
## Slopes: uphill slows the swan and lowers its top speed (down to 75%);
## downhill speeds it up and lets it run faster (up to 130%).
const SLOPE_GRAVITY := 6.0
const SLOPE_LIMIT_PER_GRADE := 2.5
const SLOPE_LIMIT_MIN := 0.75
const SLOPE_LIMIT_MAX := 1.3
## Turbo: while held (and stamina lasts) more push and a higher top speed. Stamina
## (0..1) drains while boosting and refills after a short pause.
const TURBO_ACCEL_BONUS := 3.0
const TURBO_LIMIT_BONUS := 0.2
const STAMINA_DRAIN_PER_SECOND := 1.0 / 3.0 # empty in 3 s
const STAMINA_REFILL_PER_SECOND := 0.1 # full again in 10 s
const STAMINA_REFILL_DELAY := 0.5
## Speed pads: a strong push and a higher top speed for a moment.
const PAD_TIME := 1.4
const PAD_ACCEL := 9.0
const PAD_LIMIT_BONUS := 0.3
## Each landing costs 5% of the speed, so jumps are a choice.
const LANDING_SPEED_LOSS := 0.05
## Ramps: a big leap (higher the faster you hit it) with a short push, then a
## long, gentle glide that costs speed until the swan lands.
const RAMP_LAUNCH_MIN := 4.0
const RAMP_LAUNCH_MAX := 9.0
const RAMP_PUSH_TIME := 0.3
const RAMP_GLIDE_GRAVITY := 4.0
const RAMP_MAX_FALL := 1.8
const RAMP_AIR_DRAG := 0.8
## How fast the extra speed of the push fades while gliding (m/s per second).
const RAMP_SETTLE := 3.0
## Skiing (on snow, ADR 0022): gravity does the work. Accelerate = tuck (a
## higher top speed, wider turns); brake = open the wings (a snowplough).
const SKI_MAX_SPEED := 20.0 # m/s, 72 km/h, tucked
## Top speed standing up (not tucked), as a share of SKI_MAX_SPEED.
const SKI_UPRIGHT_SCALE := 0.8
## Downhill pull: speed gained per second for each unit of grade.
const SKI_SLOPE_GRAVITY := 14.0
## Pushing with the accelerate button on flat snow (like poling).
const SKI_PUSH := 2.0
const SKI_FRICTION := 0.5
## Carving costs a little speed while steering (m/s per second at full lock).
const SKI_CARVE_LOSS := 0.8
const SKI_BRAKE := 0.7 # share of BRAKE_DECELERATION
const SKI_TURN_RATE := 1.5 # rad/s
## Turning while fully tucked: this share of SKI_TURN_RATE.
const SKI_TUCK_TURN := 0.65
## Extra speed above the limit fades at this rate (m/s per second).
const SKI_SETTLE := 4.0

var position := Vector3.ZERO
## Yaw in radians. 0 faces -Z.
var heading := 0.0
var speed := 0.0
var vertical_velocity := 0.0
## Set by the terrain each tick (1 = normal). The same rule for every swan.
var max_speed_scale := 1.0
## Top speed left after steering (1 = none lost).
var turn_cap := 1.0
## Grade of the ground along the heading (rise per meter; negative = downhill).
## Set by the track each tick.
var slope := 0.0
var stamina := 1.0
## True on the ticks the turbo is actually pushing.
var boosting := false
var _refill_wait := 0.0
## Seconds left of a speed pad push.
var pad_time := 0.0
var on_ground := true
var accelerating := false
var braking := false
## True on the tick a jump started.
var jumped := false
## True on the tick the swan touched the ground again.
var landed := false
## Flying off a ramp (until it lands).
var ramp_flight := false
## On skis (set by the course each tick): the snow rules above apply.
var skiing := false


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


func speed_ratio() -> float:
	return speed / MAX_SPEED


func step(intent: SwanIntent, tick: float) -> void:
	jumped = false
	landed = false
	var control := 1.0 if on_ground else AIR_CONTROL

	if intent.jump and on_ground:
		vertical_velocity = JUMP_VELOCITY
		on_ground = false
		jumped = true

	accelerating = intent.accel > 0.05
	braking = intent.brake > 0.05 and speed > 0.5
	if skiing:
		_step_ski(intent, tick, control)
	else:
		_step_run(intent, tick, control)

	var turn_rate := lerpf(TURN_RATE_SLOW, TURN_RATE_FAST, speed_ratio())
	if skiing:
		turn_rate = SKI_TURN_RATE * lerpf(1.0, SKI_TUCK_TURN, intent.accel)
	heading = wrapf(heading - intent.steer * turn_rate * control * tick, -PI, PI)
	position += forward() * speed * tick

	if not on_ground:
		# Fast up, slow down: a glide once past the top of the jump. Off a
		# ramp the glide is longer and the air slows the swan down.
		var glide := RAMP_GLIDE_GRAVITY if ramp_flight else GLIDE_GRAVITY
		var gravity := GRAVITY if vertical_velocity > 0.0 else glide
		var max_fall := RAMP_MAX_FALL if ramp_flight else MAX_GLIDE_FALL
		vertical_velocity = maxf(vertical_velocity - gravity * tick, -max_fall)
		position.y += vertical_velocity * tick
		if ramp_flight and vertical_velocity < 0.0:
			speed = maxf(speed - RAMP_AIR_DRAG * tick, 0.0)
		if position.y <= 0.0:
			position.y = 0.0
			vertical_velocity = 0.0
			on_ground = true
			landed = true
			ramp_flight = false
			speed *= 1.0 - LANDING_SPEED_LOSS


## Running: the swan's own legs push it (sand, grass, road).
func _step_run(intent: SwanIntent, tick: float, control: float) -> void:
	speed += ACCELERATION * intent.accel * control * tick
	speed -= BRAKE_DECELERATION * intent.brake * control * tick
	speed -= COAST_DECELERATION * (1.0 - intent.accel) * tick
	if absf(intent.steer) > 0.1:
		turn_cap = maxf(turn_cap - TURN_CAP_LOSS_PER_SECOND * absf(intent.steer) * tick, TURN_CAP_MIN)
	else:
		turn_cap = minf(turn_cap + TURN_CAP_RECOVERY_PER_SECOND * tick, 1.0)
	if on_ground:
		speed -= SLOPE_GRAVITY * slope * tick
	_update_turbo(intent, tick)
	if boosting:
		speed += TURBO_ACCEL_BONUS * tick
	if pad_time > 0.0:
		pad_time -= tick
		speed += PAD_ACCEL * tick
	var slope_limit := clampf(1.0 - slope * SLOPE_LIMIT_PER_GRADE, SLOPE_LIMIT_MIN, SLOPE_LIMIT_MAX)
	speed = clampf(speed, 0.0, MAX_SPEED * SLOPE_LIMIT_MAX * (1.0 + TURBO_LIMIT_BONUS + PAD_LIMIT_BONUS))
	var limit := MAX_SPEED * max_speed_scale * turn_cap * slope_limit
	if boosting:
		limit *= 1.0 + TURBO_LIMIT_BONUS
	if pad_time > 0.0:
		limit *= 1.0 + PAD_LIMIT_BONUS
	if speed > limit:
		# Gliding off a ramp, the extra speed fades slowly (the air drag
		# below does the rest); on the ground it settles at once.
		var settle := RAMP_SETTLE if ramp_flight else BRAKE_DECELERATION
		speed = move_toward(speed, limit, settle * tick)


## Skiing: the slope pulls the swan down; tucking raises the top speed,
## opening the wings slows it down, carving costs a little speed.
func _step_ski(intent: SwanIntent, tick: float, control: float) -> void:
	if on_ground:
		speed -= SKI_SLOPE_GRAVITY * slope * tick
	speed += SKI_PUSH * intent.accel * control * tick
	speed -= BRAKE_DECELERATION * SKI_BRAKE * intent.brake * control * tick
	speed -= (SKI_FRICTION + SKI_CARVE_LOSS * absf(intent.steer)) * tick
	turn_cap = 1.0
	_update_turbo(intent, tick)
	if boosting:
		speed += TURBO_ACCEL_BONUS * tick
	if pad_time > 0.0:
		pad_time -= tick
		speed += PAD_ACCEL * tick
	var limit := SKI_MAX_SPEED * lerpf(SKI_UPRIGHT_SCALE, 1.0, intent.accel) * max_speed_scale
	if boosting:
		limit *= 1.0 + TURBO_LIMIT_BONUS
	speed = clampf(speed, 0.0, SKI_MAX_SPEED * 1.5)
	if speed > limit:
		speed = move_toward(speed, limit, SKI_SETTLE * tick)


## Takes off from the top of a ramp, `height` meters above the ground below.
func launch(height: float) -> void:
	vertical_velocity = lerpf(RAMP_LAUNCH_MIN, RAMP_LAUNCH_MAX, clampf(speed_ratio(), 0.0, 1.0))
	position.y = height
	on_ground = false
	jumped = true
	ramp_flight = true
	pad_time = maxf(pad_time, RAMP_PUSH_TIME)


func _update_turbo(intent: SwanIntent, tick: float) -> void:
	boosting = intent.turbo and stamina > 0.0 and on_ground
	if boosting:
		stamina = maxf(stamina - STAMINA_DRAIN_PER_SECOND * tick, 0.0)
		_refill_wait = STAMINA_REFILL_DELAY
	elif _refill_wait > 0.0:
		_refill_wait -= tick
	else:
		stamina = minf(stamina + STAMINA_REFILL_PER_SECOND * tick, 1.0)
