class_name CourseMap
extends Control
## Map of a point-to-point course, north up: the way from the start to the
## finish (snow white, road gray, sand yellow), both lines, and a GPS dot with an arrow for
## each swan (the Minimap's counterpart for courses).

const BACKGROUND := Color(0.2, 0.32, 0.22, 0.75)
const SNOW := Color("eef3f8")
const ROAD := Color("6b6f76")
const SAND := Color("e3cf9e")

var track: CourseTrack
## Swans to show; the first one is the player (bigger dot).
var swans: Array[Swan] = []

var _scale := 1.0
var _center := Vector2.ZERO
## Stretches of the same terrain: [color, PackedVector2Array].
var _lines: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bounds := Rect2(track.points[0], Vector2.ZERO)
	for p in track.points:
		bounds = bounds.expand(p)
	_center = bounds.get_center()
	_scale = (minf(size.x, size.y) - 30.0) / maxf(maxf(bounds.size.x, bounds.size.y), 1.0)
	var last_terrain := -1
	for i in range(0, track.sample_count(), 6):
		var dot := _to_map(track.points[i])
		var terrain := track.terrain(track.lengths[i])
		if terrain != last_terrain:
			var line := PackedVector2Array()
			# Join the new stretch to the end of the last one.
			if not _lines.is_empty():
				line.append((_lines[-1][1] as PackedVector2Array)[-1])
			_lines.append([_color(terrain), line])
			last_terrain = terrain
		var current: PackedVector2Array = _lines[-1][1]
		current.append(dot)
		_lines[-1][1] = current


static func _color(terrain: int) -> Color:
	match terrain:
		CourseTrack.Terrain.SNOW:
			return SNOW
		CourseTrack.Terrain.SAND:
			return SAND
	return ROAD


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0
	draw_circle(size / 2.0, radius, BACKGROUND)
	draw_arc(size / 2.0, radius - 2.0, 0.0, TAU, 64, Color(0, 0, 0, 0.5), 4.0, true)
	for entry: Array in _lines:
		var line: PackedVector2Array = entry[1]
		if line.size() > 1:
			draw_polyline(line, entry[0], 6.0, true)
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
