class_name ColosseumCircuit
extends CourseTrack
## Colosseum of Rome (ADR 0031): an O-shaped loop with laps, run clockwise
## around the arena, inspired by the Colosseum (a public-domain monument).
## On the left, the stands full of people: the wall below them is solid and
## dazes you, and the crowd goes wild every time the player completes a lap.
## On the right, the middle of the arena is a pit of water with crocodiles:
## no fence, off that edge the swan falls in (and comes back a few seconds
## later). About 45 s a lap.

## The oval's half-length and half-width (center line), m.
const SIZE := Vector2(105.0, 72.0)
const HALF_WIDTH := 7.0
const OUTLINE_POINTS := 1600
## The water in the crocodile pit, below the track.
const PIT_DEPTH := 4.0
const GROUND := 1.0


func _init() -> void:
	daze_sides = [-1.0]
	var outline := PackedVector2Array()
	for n in OUTLINE_POINTS:
		# Clockwise seen from above (x right, z down); start on the long side.
		var t := PI / 2.0 + TAU * n / OUTLINE_POINTS
		outline.append(Vector2(SIZE.x * cos(t), SIZE.y * sin(t)))
	build_loop(outline)


func _height_at(_d: float) -> float:
	return GROUND


func _half_width(_d: float) -> Vector2:
	return Vector2(HALF_WIDTH, HALF_WIDTH)


func _terrain_at(_d: float) -> int:
	return Terrain.SAND


func stretch_name(_d: float) -> String:
	return "STRETCH_ARENA"


func fall_message() -> String:
	return "CAREFUL_CROCS"


func build_scenery(parent: Node3D) -> void:
	ColosseumScenery.build(parent, self)


func podium_spot() -> float:
	return 35.0


func _place_features() -> void:
	# The crocodile pit: the whole right edge is open.
	add_break(-1.0, length + 1.0, 1.0)
