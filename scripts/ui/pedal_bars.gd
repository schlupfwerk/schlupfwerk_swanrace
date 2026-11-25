class_name PedalBars
extends Control
## Two bars next to the speedometer showing how hard the accelerator and the
## brake are pressed (analog triggers), so players can feather them.

var swan: Swan

const WOOD := Color("4a2b15")
const ACCEL := Color("8cc63f")
const BRAKE := Color("e8412c")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if swan == null:
		return
	var font := get_theme_default_font()
	var bar_width := size.x * 0.34
	var height := size.y - 26.0
	var values := [swan.intent.accel, swan.intent.brake]
	var colors := [ACCEL, BRAKE]
	var labels := ["R2", "L2"] if InputGlyphs.kind == InputGlyphs.Kind.PLAYSTATION \
			else (["RT", "LT"] if InputGlyphs.kind == InputGlyphs.Kind.XBOX else ["W", "S"])
	for n in 2:
		var x := size.x * (0.1 + 0.48 * n)
		var frame := Rect2(x, 0, bar_width, height)
		draw_rect(frame.grow(3.0), WOOD)
		draw_rect(frame, Color(0, 0, 0, 0.55))
		var value := clampf(values[n], 0.0, 1.0)
		if value > 0.0:
			draw_rect(Rect2(x, height * (1.0 - value), bar_width, height * value), colors[n])
		# Quarter marks.
		for q in range(1, 4):
			var y := height * q / 4.0
			draw_line(Vector2(x, y), Vector2(x + bar_width * 0.35, y), Color(1, 1, 1, 0.5), 2.0)
		draw_string(font, Vector2(x - 6, size.y - 4), labels[n], HORIZONTAL_ALIGNMENT_CENTER,
				bar_width + 12, 16, Color("f3e3c3"))
