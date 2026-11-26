class_name DirectionArrow
extends Control
## Arrow at the top of the screen pointing where the track goes, about 25 m
## ahead. Green when you are on course, yellow, then orange for sharp turns.

const LOOK_AHEAD := 12 # track samples (~2 m each)

## An IslandTrack (a circuit) or a CourseTrack (point to point): both have
## points and locate().
var track: RefCounted
var swan: Swan

var _hint := -1
var _angle := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	visible = Settings.shows_direction()
	if not visible or swan == null:
		return
	var p := Vector2(swan.position.x, swan.position.z)
	var info: Dictionary = track.call("locate", p, _hint)
	_hint = info["index"]
	var points: PackedVector2Array = track.get("points")
	# Circuits wrap around; courses stop at their end.
	var loops: bool = track is IslandTrack or track.get("looped")
	var next := (_hint + LOOK_AHEAD) % points.size() if loops \
			else mini(_hint + LOOK_AHEAD, points.size() - 1)
	var ahead := points[next]
	var forward := Vector2(swan.motor.forward().x, swan.motor.forward().z)
	# Screen angle: 0 = straight up, positive = to the right.
	var target := forward.angle_to(ahead - p)
	_angle = lerp_angle(_angle, target, 1.0 - exp(-8.0 * delta))
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var turn := absf(_angle)
	var color := Color("4cbf56")
	if turn > deg_to_rad(50.0):
		color = Color("ff6a2a")
	elif turn > deg_to_rad(20.0):
		color = Color("ffd23f")
	var dir := Vector2.UP.rotated(_angle)
	var side := dir.orthogonal()
	var length := minf(size.x, size.y) * 0.42
	# A chunky chevron arrow with a dark outline.
	var points := PackedVector2Array([
		center + dir * length,
		center + side * length * 0.7 - dir * length * 0.1,
		center + side * length * 0.3 + dir * length * 0.05,
		center + side * length * 0.3 - dir * length * 0.8,
		center - side * length * 0.3 - dir * length * 0.8,
		center - side * length * 0.3 + dir * length * 0.05,
		center - side * length * 0.7 - dir * length * 0.1,
	])
	var outline := points.duplicate()
	outline.append(points[0])
	draw_colored_polygon(points, color)
	draw_polyline(outline, Color(0, 0, 0, 0.8), 4.0, true)
