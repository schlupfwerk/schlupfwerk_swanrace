class_name UiTheme
extends RefCounted
## Shared look for menus and HUD: large text and a very visible focus frame,
## because everything must be usable with a controller and no mouse.

const FOCUS_COLOR := Color("ffd23f")


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 24

	var normal := _box(Color(0.1, 0.12, 0.16, 0.85))
	var hover := _box(Color(0.18, 0.21, 0.27, 0.9))
	var pressed := _box(Color(0.25, 0.3, 0.38, 0.95))
	var disabled := _box(Color(0.1, 0.12, 0.16, 0.4))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(4)
	focus.border_color = FOCUS_COLOR
	focus.set_corner_radius_all(10)
	focus.set_expand_margin_all(2)

	for type in ["Button", "LineEdit"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, focus)
		theme.set_stylebox("read_only", type, disabled)
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", FOCUS_COLOR)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))

	var panel := _box(Color(0.05, 0.07, 0.1, 0.78))
	panel.set_content_margin_all(22)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var track := _box(Color(1, 1, 1, 0.18))
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", track)
	var filled := _box(FOCUS_COLOR.darkened(0.15))
	filled.content_margin_top = 4
	filled.content_margin_bottom = 4
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_stylebox("focus", "HSlider", focus)

	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	theme.set_constant("outline_size", "Label", 6)
	return theme


static func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(10)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
