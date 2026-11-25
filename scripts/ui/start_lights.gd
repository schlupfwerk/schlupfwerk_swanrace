class_name StartLights
extends Control
## Race start lights: three red lamps light up one by one, then all turn green.

const OFF := Color("2a2a2e")
const RED := Color("ff3b30")
const GREEN := Color("4cd964")

## How many lamps are lit (0-3); `go` turns them all green.
var lit := 0:
	set(value):
		lit = value
		queue_redraw()
var go := false:
	set(value):
		go = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var lamp := size.y * 0.32
	var housing := Rect2(Vector2.ZERO, size)
	draw_rect(housing.grow(4.0), Color(0, 0, 0, 0.6))
	draw_rect(housing, Color("4a2b15"))
	for n in 3:
		var center := Vector2(size.x * (n + 0.5) / 3.0, size.y / 2.0)
		var color := GREEN if go else (RED if n < lit else OFF)
		if color != OFF:
			draw_circle(center, lamp * 1.35, Color(color, 0.25))
		draw_circle(center, lamp, Color(0, 0, 0, 0.8))
		draw_circle(center, lamp * 0.85, color)
		draw_circle(center + Vector2(-lamp * 0.3, -lamp * 0.3), lamp * 0.2, Color(1, 1, 1, 0.35))
