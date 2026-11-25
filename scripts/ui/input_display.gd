class_name InputDisplay
extends Control
## Drawing of the controls in use, lit up while pressed:
## - keyboard: W A S D (or the arrows, if the player uses them), Space, Shift;
## - Xbox: left stick, LT/RT filling with pressure, A B X Y;
## - PlayStation: left stick, L2/R2, Cross Circle Square Triangle.

const KEY_COLOR := Color(0.1, 0.12, 0.16, 0.85)
const LIT := Color("ffd23f")
const TEXT := Color("f3e3c3")
const XBOX_COLORS := {"A": Color("4cbf56"), "B": Color("e8413c"), "X": Color("2f6fe0"),
		"Y": Color("ffd23f")}
const PS_COLORS := {"cross": Color("7fa8ff"), "circle": Color("ff6b6b"),
		"square": Color("ff8fd0"), "triangle": Color("5fd3a8")}

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	match InputGlyphs.kind:
		InputGlyphs.Kind.XBOX:
			_draw_pad(false)
		InputGlyphs.Kind.PLAYSTATION:
			_draw_pad(true)
		_:
			_draw_keyboard()


# --- Keyboard -------------------------------------------------------------------

func _draw_keyboard() -> void:
	var k := 46.0
	var gap := 6.0
	var left := 70.0
	var top := 4.0
	var arrows := InputGlyphs.arrows
	var keys := [
		[KEY_UP if arrows else KEY_W, Vector2(left + k + gap, top), "up" if arrows else "W", "accel"],
		[KEY_LEFT if arrows else KEY_A, Vector2(left, top + k + gap), "left" if arrows else "A", "steer_left"],
		[KEY_DOWN if arrows else KEY_S, Vector2(left + k + gap, top + k + gap), "down" if arrows else "S", "brake"],
		[KEY_RIGHT if arrows else KEY_D, Vector2(left + 2 * (k + gap), top + k + gap), "right" if arrows else "D", "steer_right"],
	]
	for key: Array in keys:
		var rect := Rect2(key[1], Vector2(k, k))
		var lit := Input.is_physical_key_pressed(key[0])
		_key(rect, lit)
		var label: String = key[2]
		if label in ["up", "down", "left", "right"]:
			_arrow(rect.get_center(), label, Color.BLACK if lit else TEXT)
		else:
			_text(rect.get_center() + Vector2(0, 8), label, 22, Color.BLACK if lit else TEXT)
	# Shift (turbo) on the left, Space (jump) below.
	var shift := Rect2(Vector2(0, top + k + gap), Vector2(left - gap, k))
	_key(shift, Input.is_physical_key_pressed(KEY_SHIFT))
	_text(shift.get_center() + Vector2(0, -2), "Shift", 15,
			Color.BLACK if Input.is_physical_key_pressed(KEY_SHIFT) else TEXT)
	_text(shift.get_center() + Vector2(0, 15), tr("TURBO"), 12, Color(TEXT, 0.8))
	var horn := Rect2(Vector2(left + 3 * (k + gap), top + k + gap), Vector2(k, k))
	var horn_lit := Input.is_physical_key_pressed(KEY_H)
	_key(horn, horn_lit)
	_text(horn.get_center() + Vector2(0, 2), "H", 20, Color.BLACK if horn_lit else TEXT)
	_text(horn.get_center() + Vector2(0, 18), tr("HORN"), 11, Color(TEXT, 0.8))
	var space := Rect2(Vector2(left, top + 2 * (k + gap)), Vector2(3 * k + 2 * gap, k * 0.7))
	var space_lit := Input.is_physical_key_pressed(KEY_SPACE)
	_key(space, space_lit)
	_text(space.get_center() + Vector2(0, 6), tr("JUMP"), 15, Color.BLACK if space_lit else TEXT)
	_text(Vector2(left + 3 * (k + gap) + 26, top + 22), "Esc: menu", 14, Color(TEXT, 0.8))


func _key(rect: Rect2, lit: bool) -> void:
	_rounded(rect.grow(2.0), Color(0, 0, 0, 0.6))
	_rounded(rect, LIT if lit else KEY_COLOR)
	if not lit:
		draw_line(rect.position + Vector2(6, rect.size.y - 3), rect.end - Vector2(6, 3),
				Color(1, 1, 1, 0.15), 2.0)


func _arrow(center: Vector2, direction: String, color: Color) -> void:
	var dirs := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
	var d: Vector2 = dirs[direction]
	var side := d.orthogonal()
	draw_colored_polygon(PackedVector2Array([center + d * 13.0, center + side * 11.0 - d * 6.0,
			center - side * 11.0 - d * 6.0]), color)


# --- Controllers ------------------------------------------------------------------

func _draw_pad(playstation: bool) -> void:
	var steer := Input.get_axis("steer_left", "steer_right")
	var accel := Input.get_action_strength("accel")
	var brake := Input.get_action_strength("brake")
	# Triggers on top, filling with pressure.
	_trigger(Rect2(10, 2, 76, 26), "L2" if playstation else "LT", brake, tr("BRAKE_SHORT"))
	_trigger(Rect2(196, 2, 76, 26), "R2" if playstation else "RT", accel, tr("ACCEL_SHORT"))
	# Left stick: the dot follows the steering.
	var stick := Vector2(48, 92)
	draw_circle(stick, 34.0, Color(0, 0, 0, 0.6))
	draw_circle(stick, 30.0, KEY_COLOR)
	draw_circle(stick + Vector2(steer * 16.0, 0), 17.0, LIT if absf(steer) > 0.2 else Color("5a5f6a"))
	_text(stick + Vector2(0, 50), tr("STEER_SHORT"), 12, Color(TEXT, 0.8))
	# Face buttons in a diamond.
	var center := Vector2(232, 92)
	var gap := 26.0
	var jump := Input.is_action_pressed("jump")
	var turbo := Input.is_action_pressed("turbo")
	var faces := [
		[center + Vector2(0, gap), "cross" if playstation else "A", jump],
		[center + Vector2(gap, 0), "circle" if playstation else "B", false],
		[center + Vector2(-gap, 0), "square" if playstation else "X", turbo],
		[center + Vector2(0, -gap), "triangle" if playstation else "Y", Input.is_action_pressed("horn")],
	]
	for face: Array in faces:
		_face_button(face[0], face[1], face[2], playstation)
	_text(center + Vector2(0, gap + 34), tr("JUMP"), 12, Color(TEXT, 0.8))
	_text(center + Vector2(-gap - 34, 4), tr("TURBO"), 12, Color(TEXT, 0.8))
	_text(center + Vector2(0, -gap - 22), tr("HORN"), 12, Color(TEXT, 0.8))
	_text(Vector2(140, 150), ("Options" if playstation else "Start") + ": menu", 13, Color(TEXT, 0.8))


func _trigger(rect: Rect2, label: String, pressure: float, caption: String) -> void:
	_rounded(rect.grow(2.0), Color(0, 0, 0, 0.6))
	_rounded(rect, KEY_COLOR)
	if pressure > 0.01:
		_rounded(Rect2(rect.position, Vector2(rect.size.x * pressure, rect.size.y)), LIT)
	_text(rect.get_center() + Vector2(0, 6), label, 16, Color.BLACK if pressure > 0.5 else TEXT)
	_text(rect.get_center() + Vector2(0, 30), caption, 12, Color(TEXT, 0.8))


func _face_button(center: Vector2, button: String, lit: bool, playstation: bool) -> void:
	var radius := 15.0 if not lit else 17.0
	draw_circle(center, radius + 2.0, Color(0, 0, 0, 0.6))
	draw_circle(center, radius, LIT if lit else Color("23262e"))
	var color: Color = (PS_COLORS if playstation else XBOX_COLORS)[button]
	if lit:
		color = Color.BLACK
	match button:
		"cross":
			draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), color, 3.0, true)
			draw_line(center + Vector2(-6, 6), center + Vector2(6, -6), color, 3.0, true)
		"circle":
			draw_arc(center, 6.5, 0.0, TAU, 20, color, 2.5, true)
		"square":
			draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), color, false, 2.5)
		"triangle":
			var points := PackedVector2Array([center + Vector2(0, -7), center + Vector2(7, 5),
					center + Vector2(-7, 5), center + Vector2(0, -7)])
			draw_polyline(points, color, 2.5, true)
		_:
			_text(center + Vector2(0, 6), button, 16, color)


# --- Helpers ----------------------------------------------------------------------

func _rounded(rect: Rect2, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	draw_style_box(box, rect)


func _text(center: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(_font, Vector2(center.x - width / 2.0, center.y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.7))
	draw_string(_font, Vector2(center.x - width / 2.0, center.y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
