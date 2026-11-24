class_name SwanBrain
extends RefCounted
## Base class for everything that drives a swan: PlayerInput, BotBrain and,
## later, NetworkInput. Race logic only ever sees the SwanIntent.


## Fills `intent` for one fixed simulation tick.
func update_intent(intent: SwanIntent, _tick: float) -> void:
	intent.reset()
