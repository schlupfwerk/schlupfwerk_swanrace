class_name StaminaBar
extends Control
## Stamina for the turbo, above the speedometer: turquoise when full, orange
## when low, and it glows while boosting.

var swan: Swan

const WOOD := Color("4a2b15")
const FULL := Color("37c6c0")
const LOW := Color("ff8a2a")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if swan == null:
		return
	var stamina := swan.motor.stamina
	var font := get_theme_default_font()
	var label := tr("TURBO")
	var bar := Rect2(Vector2(0, 18), Vector2(size.x, size.y - 18))
	draw_string(font, Vector2(0, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f3e3c3"))
	draw_rect(bar.grow(3.0), WOOD)
	draw_rect(bar, Color(0, 0, 0, 0.55))
	var color := LOW.lerp(FULL, clampf(stamina * 2.0 - 0.2, 0.0, 1.0))
	if swan.motor.boosting:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		color = color.lerp(Color.WHITE, 0.35 * pulse)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * stamina, bar.size.y)), color)
	for q in range(1, 4):
		var x := bar.position.x + bar.size.x * q / 4.0
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.4), 2.0)
