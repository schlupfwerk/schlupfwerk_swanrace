class_name Speedometer
extends Control
## Round speedometer in km/h, drawn by code.

const MAX_KMH := 100.0
const START_ANGLE := deg_to_rad(135.0)
const SWEEP := deg_to_rad(270.0)

var speed_kmh := 0.0:
	set(value):
		speed_kmh = value
		queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 8.0
	var t := clampf(speed_kmh / MAX_KMH, 0.0, 1.0)
	var font := get_theme_default_font()

	draw_circle(center, radius + 6.0, Color(0, 0, 0, 0.5))
	draw_arc(center, radius - 8.0, START_ANGLE, START_ANGLE + SWEEP, 64, Color(1, 1, 1, 0.2), 12.0, true)
	if t > 0.0:
		var color := Color("4cbf56").lerp(Color("ffd23f"), clampf(t * 2.0, 0, 1)).lerp(
				Color("ff6a2a"), clampf(t * 2.0 - 1.0, 0, 1))
		draw_arc(center, radius - 8.0, START_ANGLE, START_ANGLE + SWEEP * t, 64, color, 12.0, true)

	for kmh in range(0, int(MAX_KMH) + 1, 10):
		var angle := START_ANGLE + SWEEP * kmh / MAX_KMH
		var dir := Vector2.from_angle(angle)
		var major := kmh % 20 == 0
		draw_line(center + dir * (radius - 20.0), center + dir * (radius - (32.0 if major else 26.0)),
				Color(1, 1, 1, 0.85), 3.0 if major else 2.0, true)
		if major:
			var label_pos := center + dir * (radius - 48.0) + Vector2(-20, 6)
			draw_string(font, label_pos, str(kmh), HORIZONTAL_ALIGNMENT_CENTER, 40, 14)

	var needle := Vector2.from_angle(START_ANGLE + SWEEP * t)
	draw_line(center, center + needle * (radius - 26.0), Color("ff4a3a"), 5.0, true)
	draw_circle(center, 9.0, Color.WHITE)
	draw_string(font, center + Vector2(-60, radius * 0.5), str(roundi(speed_kmh)),
			HORIZONTAL_ALIGNMENT_CENTER, 120, 40)
	draw_string(font, center + Vector2(-60, radius * 0.5 + 24), "km/h",
			HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(1, 1, 1, 0.7))
