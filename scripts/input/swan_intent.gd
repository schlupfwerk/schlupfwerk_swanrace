class_name SwanIntent
extends RefCounted
## What a brain wants its swan to do on this tick.
## Players, bots and (later) network players all produce this same object.

## -1.0 = full left, 1.0 = full right.
var steer: float = 0.0
## 0.0 to 1.0 (analog triggers give values in between).
var accel: float = 0.0
## 0.0 to 1.0.
var brake: float = 0.0
## True only on the tick the jump button went down.
var jump: bool = false


func reset() -> void:
	steer = 0.0
	accel = 0.0
	brake = 0.0
	jump = false
