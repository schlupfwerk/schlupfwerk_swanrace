class_name CourseMap
extends Control
## Map of a point-to-point course, north up: the way from the start to the
## finish (snow white, road gray), both lines, and a GPS dot with an arrow for
## each swan (the Minimap's counterpart for courses).

const BACKGROUND := Color(0.2, 0.32, 0.22, 0.75)
const SNOW := Color("eef3f8")
const ROAD := Color("6b6f76")

var track: CourseTrack
## Swans to show; the first one is the player (bigger dot).
var swans: Array[Swan] = []

var _scale := 1.0
var _center := Vector2.ZERO
var _snow := PackedVector2Array()
var _road := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bounds := Rect2(track.points[0], Vector2.ZERO)
	for p in track.points:
		bounds = bounds.expand(p)
	_center = bounds.get_center()
	_scale = (minf(size.x, size.y) - 30.0) / maxf(maxf(bounds.size.x, bounds.size.y), 1.0)
	for i in range(0, track.sample_count(), 6):
		var dot := _to_map(track.points[i])
		if track.terrain(track.lengths[i]) == CourseTrack.Terrain.SNOW:
			_snow.append(dot)
		else:
			if _road.is_empty() and not _snow.is_empty():
				_road.append(_snow[-1])
			_road.append(dot)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0
	draw_circle(size / 2.0, radius, BACKGROUND)
	draw_arc(size / 2.0, radius - 2.0, 0.0, TAU, 64, Color(0, 0, 0, 0.5), 4.0, true)
	if _snow.size() > 1:
		draw_polyline(_snow, SNOW, 7.0, true)
	if _road.size() > 1:
		draw_polyline(_road, ROAD, 5.0, true)
	for line: float in [track.start_distance, track.finish_distance]:
		var i := track.index_at(line)
		var at := _to_map(track.points[i])
		var across := track.right(i).normalized() * 7.0
		draw_line(at - across, at + across, Color.WHITE, 3.0, true)
	# Swans: the player last, so it is drawn on top.
	for n in range(swans.size() - 1, -1, -1):
		var swan := swans[n]
		if not is_instance_valid(swan):
			continue
		var p := _to_map(Vector2(swan.position.x, swan.position.z))
		var heading := Vector2(swan.motor.forward().x, swan.motor.forward().z).normalized()
		var player := n == 0
		var pulse := 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.008) if player else 1.0
		var color := Color("ffd23f") if player else Color("9a9aa2")
		var dot := (6.0 if player else 4.5) * pulse
		draw_circle(p, dot + 2.0, Color(0, 0, 0, 0.7))
		draw_circle(p, dot, color)
		var tip := p + heading * (dot + 7.0)
		var side := heading.orthogonal() * 4.0
		draw_colored_polygon(PackedVector2Array([tip, p + heading * dot + side,
				p + heading * dot - side]), color)


## World (x, z) to map pixels, north (-z) up.
func _to_map(world: Vector2) -> Vector2:
	return size / 2.0 + (world - _center) * _scale
