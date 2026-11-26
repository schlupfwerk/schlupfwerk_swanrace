class_name Speedometer
extends Control
## Jungle-style speed gauge, drawn by code: a carved wooden disc with a
## geometric painted border, a vine of leaves that grows with the speed and a
## feather as the needle. Nothing here should look like a car dashboard.

## Top of the scale (km/h). Courses with skiing raise it (Hud.max_kmh).
var max_kmh := 60.0
const START_ANGLE := deg_to_rad(150.0)
const SWEEP := deg_to_rad(240.0)

const WOOD := Color("7a4a26")
const WOOD_DARK := Color("4a2b15")
const WOOD_LIGHT := Color("9c6536")
const OCHRE := Color("e3a43f")
const RED := Color("c2412d")
const BLACK := Color("1d1410")
const LEAF := Color("3f8f34")
const LEAF_LIGHT := Color("8cc63f")
const CREAM := Color("f3e3c3")

var speed_kmh := 0.0:
	set(value):
		speed_kmh = value
		queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 4.0
	var t := clampf(speed_kmh / max_kmh, 0.0, 1.0)

	_draw_disc(center, radius)
	_draw_border(center, radius)
	_draw_vine(center, radius - 34.0, t)
	_draw_marks(center, radius)
	_draw_feather(center, START_ANGLE + SWEEP * t, radius - 40.0)

	draw_circle(center, 11.0, WOOD_DARK)
	draw_circle(center, 6.0, OCHRE)
	var font := get_theme_default_font()
	var text_pos := center + Vector2(-60, radius * 0.55)
	draw_string_outline(font, text_pos, str(roundi(speed_kmh)), HORIZONTAL_ALIGNMENT_CENTER,
			120, 38, 8, WOOD_DARK)
	draw_string(font, text_pos, str(roundi(speed_kmh)), HORIZONTAL_ALIGNMENT_CENTER, 120, 38, CREAM)
	draw_string(font, text_pos + Vector2(0, 20), "km/h", HORIZONTAL_ALIGNMENT_CENTER, 120, 15,
			Color(CREAM, 0.8))


func _draw_disc(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, WOOD_DARK)
	draw_circle(center, radius - 5.0, WOOD)
	# Growth rings of the wood.
	for i in 4:
		draw_arc(center + Vector2(3, -2) * i, radius * (0.22 + 0.15 * i), 0.0, TAU, 48,
				Color(WOOD_LIGHT, 0.45), 2.0, true)


func _draw_border(center: Vector2, radius: float) -> void:
	# Painted band of alternating triangles, with red dots inside.
	var outer := radius - 7.0
	var inner := radius - 21.0
	draw_arc(center, (outer + inner) / 2.0, 0.0, TAU, 64, BLACK, outer - inner, true)
	var count := 32
	for i in count:
		var a0 := TAU * i / count
		var a1 := TAU * (i + 1) / count
		var mid := (a0 + a1) / 2.0
		draw_colored_polygon(PackedVector2Array([
			center + Vector2.from_angle(a0) * outer,
			center + Vector2.from_angle(a1) * outer,
			center + Vector2.from_angle(mid) * inner,
		]), OCHRE)
		draw_circle(center + Vector2.from_angle(a0) * (inner + 3.5), 1.8, RED)


func _draw_vine(center: Vector2, radius: float, t: float) -> void:
	# Faint track for the whole range, then the vine up to the current speed.
	draw_arc(center, radius, START_ANGLE, START_ANGLE + SWEEP, 48, Color(BLACK, 0.35), 4.0, true)
	if t <= 0.0:
		return
	var end := START_ANGLE + SWEEP * t
	draw_arc(center, radius, START_ANGLE, end, 48, LEAF, 4.0, true)
	var step := deg_to_rad(11.0)
	var angle := START_ANGLE + step * 0.5
	var flip := 1.0
	while angle < end:
		var base := center + Vector2.from_angle(angle) * radius
		var tangent := Vector2.from_angle(angle + PI / 2.0)
		var outward := Vector2.from_angle(angle) * flip
		_draw_leaf(base, (tangent + outward * 1.2).normalized(), 15.0, 7.0,
				LEAF_LIGHT if flip > 0.0 else LEAF)
		flip = -flip
		angle += step


func _draw_leaf(base: Vector2, direction: Vector2, length: float, width: float, color: Color) -> void:
	var side := direction.orthogonal()
	var points := PackedVector2Array()
	for i in 9:
		var s := float(i) / 8.0
		points.append(base + direction * length * s + side * sin(s * PI) * width * 0.5)
	for i in range(7, 0, -1):
		var s := float(i) / 8.0
		points.append(base + direction * length * s - side * sin(s * PI) * width * 0.5)
	draw_colored_polygon(points, color)
	draw_line(base, base + direction * length * 0.85, Color(LEAF, 0.8), 1.0, true)


func _draw_marks(center: Vector2, radius: float) -> void:
	var font := get_theme_default_font()
	for kmh in range(0, int(max_kmh) + 1, 10):
		var dir := Vector2.from_angle(START_ANGLE + SWEEP * kmh / max_kmh)
		# Carved notch.
		draw_line(center + dir * (radius - 44.0), center + dir * (radius - 54.0), CREAM, 3.0, true)
		var label_pos := center + dir * (radius - 68.0) + Vector2(-20, 5)
		draw_string(font, label_pos, str(kmh), HORIZONTAL_ALIGNMENT_CENTER, 40, 13,
				Color(CREAM, 0.85))


func _draw_feather(center: Vector2, angle: float, length: float) -> void:
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal()
	var base := center - dir * 10.0
	var total := length + 10.0
	# Vane: wide in the middle, red near the quill and ochre at the tip.
	for half: int in 2:
		var from := 0.15 + 0.425 * half
		var to := from + 0.425
		var points := PackedVector2Array()
		for i in 7:
			var s := lerpf(from, to, i / 6.0)
			points.append(base + dir * total * s + side * _vane_width(s))
		for i in range(6, -1, -1):
			var s := lerpf(from, to, i / 6.0)
			points.append(base + dir * total * s - side * _vane_width(s) * 0.8)
		draw_colored_polygon(points, RED if half == 0 else OCHRE)
	# Dark stripes across the vane, like a real feather.
	for s: float in [0.35, 0.5, 0.65]:
		var p := base + dir * total * s
		draw_line(p - side * _vane_width(s) * 0.8, p + side * _vane_width(s), Color(BLACK, 0.6),
				2.0, true)
	draw_line(base, base + dir * total, CREAM, 2.0, true)


static func _vane_width(s: float) -> float:
	return 7.0 * sin(clampf((s - 0.1) / 0.92, 0.0, 1.0) * PI)
