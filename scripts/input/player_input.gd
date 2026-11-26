class_name PlayerInput
extends SwanBrain
## Reads the Input Map actions. Keyboard, Xbox and PlayStation controllers
## (and later touch buttons and tilt) all feed the same actions.
##
## Easy mode (auto_throttle): the swan speeds up by itself and eases off in
## sharp turns at top speed, so a child only needs to steer and jump. The
## accelerate and brake buttons still work: using them switches to manual.
## After AUTO_RESUME seconds without touching either, automatic comes back.
##
## Touch (phones): there is no accelerate button at all. The swan always
## speeds up by itself (easing off in sharp turns); holding brake slows it
## only while held, and letting go speeds up again at once.

## Automatic throttle switched on (true) or off (false, manual).
signal auto_changed(on: bool)

const AUTO_RESUME := 4.0
const AUTO_THROTTLE := 0.95
## Easing off: in a hard turn above this share of top speed.
const AUTO_EASE_SPEED := 0.8
const AUTO_EASE_STEER := 0.75

## Allowed at all (easy mode). Needs `motor` to ease off in turns.
var auto_throttle := false
var motor: SwanMotor
## True while the throttle is automatic (false = the player took over).
var auto_active := true

var _jump_was_down := false
var _idle := 0.0


func update_intent(intent: SwanIntent, tick: float) -> void:
	intent.steer = Input.get_axis("steer_left", "steer_right")
	intent.accel = Input.get_action_strength("accel")
	intent.brake = Input.get_action_strength("brake")
	if InputGlyphs.touch():
		_touch_throttle(intent)
	elif auto_throttle:
		_update_auto(intent, tick)
	intent.turbo = Input.is_action_pressed("turbo")
	# Accessibility: the turbo button also means full throttle, so one button is
	# enough (no need to hold two keys or two touch buttons).
	if intent.turbo:
		intent.accel = 1.0
	intent.horn = Input.is_action_just_pressed("horn")
	# Edge detection per tick, so a press is never lost or repeated when a
	# frame runs zero or several simulation ticks.
	var jump_down := Input.is_action_pressed("jump")
	intent.jump = jump_down and not _jump_was_down
	_jump_was_down = jump_down


func _touch_throttle(intent: SwanIntent) -> void:
	if intent.brake > 0.1:
		intent.accel = 0.0
		return
	intent.accel = maxf(intent.accel, _auto_amount(intent))


## How much the automatic throttle presses: a little less in a hard turn at
## top speed.
func _auto_amount(intent: SwanIntent) -> float:
	if motor and absf(intent.steer) > AUTO_EASE_STEER and motor.speed_ratio() > AUTO_EASE_SPEED:
		return 0.4
	return AUTO_THROTTLE


func _update_auto(intent: SwanIntent, tick: float) -> void:
	if intent.accel > 0.1 or intent.brake > 0.1:
		_idle = 0.0
		if auto_active:
			auto_active = false
			auto_changed.emit(false)
		return
	_idle += tick
	if not auto_active:
		if _idle < AUTO_RESUME:
			return
		auto_active = true
		auto_changed.emit(true)
	intent.accel = _auto_amount(intent)
