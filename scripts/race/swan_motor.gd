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
const TURBO_LIMIT_BONUS := 0.22
const STAMINA_DRAIN_PER_SECOND := 0.28
const STAMINA_REFILL_PER_SECOND := 0.12
const STAMINA_REFILL_DELAY := 1.0
## Each landing costs 5% of the speed, so jumps are a choice.
const LANDING_SPEED_LOSS := 0.05

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
var on_ground := true
var accelerating := false
var braking := false
## True on the tick a jump started.
var jumped := false
## True on the tick the swan touched the ground again.
var landed := false


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
	var slope_limit := clampf(1.0 - slope * SLOPE_LIMIT_PER_GRADE, SLOPE_LIMIT_MIN, SLOPE_LIMIT_MAX)
	speed = clampf(speed, 0.0, MAX_SPEED * SLOPE_LIMIT_MAX * (1.0 + TURBO_LIMIT_BONUS))
	var limit := MAX_SPEED * max_speed_scale * turn_cap * slope_limit
	if boosting:
		limit *= 1.0 + TURBO_LIMIT_BONUS
	if speed > limit:
		speed = move_toward(speed, limit, BRAKE_DECELERATION * tick)

	var turn_rate := lerpf(TURN_RATE_SLOW, TURN_RATE_FAST, speed_ratio())
	heading = wrapf(heading - intent.steer * turn_rate * control * tick, -PI, PI)
	position += forward() * speed * tick

	if not on_ground:
		vertical_velocity -= GRAVITY * tick
		position.y += vertical_velocity * tick
		if position.y <= 0.0:
			position.y = 0.0
			vertical_velocity = 0.0
			on_ground = true
			landed = true
			speed *= 1.0 - LANDING_SPEED_LOSS


func _update_turbo(intent: SwanIntent, tick: float) -> void:
	boosting = intent.turbo and stamina > 0.0 and on_ground
	if boosting:
		stamina = maxf(stamina - STAMINA_DRAIN_PER_SECOND * tick, 0.0)
		_refill_wait = STAMINA_REFILL_DELAY
	elif _refill_wait > 0.0:
		_refill_wait -= tick
	else:
		stamina = minf(stamina + STAMINA_REFILL_PER_SECOND * tick, 1.0)
