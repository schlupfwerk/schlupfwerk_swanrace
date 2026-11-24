class_name PlayerInput
extends SwanBrain
## Reads the Input Map actions. Keyboard, Xbox and PlayStation controllers
## (and later touch buttons and tilt) all feed the same actions.

var _jump_was_down := false


func update_intent(intent: SwanIntent, _tick: float) -> void:
	intent.steer = Input.get_axis("steer_left", "steer_right")
	intent.accel = Input.get_action_strength("accel")
	intent.brake = Input.get_action_strength("brake")
	# Edge detection per tick, so a press is never lost or repeated when a
	# frame runs zero or several simulation ticks.
	var jump_down := Input.is_action_pressed("jump")
	intent.jump = jump_down and not _jump_was_down
	_jump_was_down = jump_down
