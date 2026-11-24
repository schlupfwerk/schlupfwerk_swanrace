class_name Minimap
extends Control
## Map of the circuit, north up: the island (forest), the sand where you run,
## the start line and a pulsing GPS dot with an arrow for each swan.

const SEA := Color(0.12, 0.42, 0.6, 0.75)
const FOREST := Color("3a6b2a")
const SAND := Color("d6b783")
const START := Color.WHITE

var track: IslandTrack
## Swans to show; the first one is the player (bigger dot).
var swans: Array[Swan] = []

var _scale := 1.0
var _center := Vector2.ZERO
var _forest := PackedVector2Array()
var _sand_inner := PackedVector2Array()
var _sand_outer := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bounds := Rect2(track.points[0], Vector2.ZERO)
	for i in IslandTrack.SAMPLES:
		bounds = bounds.expand(track.edge(i, track.water_line(i)))
	_center = bounds.get_center()
	_scale = (minf(size.x, size.y) - 24.0) / maxf(bounds.size.x, bounds.size.y)
	for i in range(0, IslandTrack.SAMPLES, 4):
		_forest.append(_to_map(track.edge(i, track.forest_edge(i))))
		_sand_inner.append(_to_map(track.edge(i, track.forest_edge(i))))
		_sand_outer.append(_to_map(track.edge(i, track.water_line(i))))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0
	draw_circle(size / 2.0, radius, SEA)
	draw_arc(size / 2.0, radius - 2.0, 0.0, TAU, 64, Color(0, 0, 0, 0.5), 4.0, true)
	draw_colored_polygon(_forest, FOREST)
	# The sand band, as a thick closed line between forest and sea.
	var sand_line := PackedVector2Array()
	for i in _sand_inner.size():
		sand_line.append((_sand_inner[i] + _sand_outer[i]) / 2.0)
	sand_line.append(sand_line[0])
	draw_polyline(sand_line, SAND, 7.0, true)
	# Start line.
	var start := _to_map(track.points[0])
	var across := _to_dir(track.right(0)) * 7.0
	draw_line(start - across, start + across, START, 3.0, true)
	# Swans: the player last, so it is drawn on top.
	for n in range(swans.size() - 1, -1, -1):
		var swan := swans[n]
		if not is_instance_valid(swan):
			continue
		var p := _to_map(Vector2(swan.position.x, swan.position.z))
		var heading := _to_dir(Vector2(swan.motor.forward().x, swan.motor.forward().z))
		var player := n == 0
		var pulse := 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.008) if player else 1.0
		var color := Color("ffd23f") if player else Color("ff8fb8")
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


func _to_dir(world_dir: Vector2) -> Vector2:
	return world_dir.normalized()
