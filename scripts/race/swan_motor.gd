class_name SwanMotor
extends RefCounted
## Handwritten, deterministic arcade movement on flat ground (ADR 0006).
## Every swan uses exactly these numbers: there are no faster or slower swans.

const MAX_SPEED := 22.0 # m/s, about 80 km/h
const ACCELERATION := 10.0
const BRAKE_DECELERATION := 24.0
const COAST_DECELERATION := 3.0
const TURN_RATE_SLOW := 2.6 # rad/s when almost stopped
const TURN_RATE_FAST := 1.4 # rad/s at top speed
const AIR_CONTROL := 0.35
const JUMP_VELOCITY := 7.5
const GRAVITY := 24.0

var position := Vector3.ZERO
## Yaw in radians. 0 faces -Z.
var heading := 0.0
var speed := 0.0
var vertical_velocity := 0.0
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
	speed = clampf(speed, 0.0, MAX_SPEED)

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
