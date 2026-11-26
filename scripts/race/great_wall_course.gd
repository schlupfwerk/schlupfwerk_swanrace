class_name GreatWallCourse
extends CourseTrack
## Great Wall of China (ADR 0028): a point-to-point run along the top of an
## old wall winding over mountain ridges, inspired by China (not a copy of a
## real section), about 2:15. Like the Rio Seafront: one run, no laps, mostly
## easy, with gentle curves to both sides and long climbs and descents.
## Parapets with battlements on both sides keep the swans on the wall (solid
## stone: running into one dazes you; brushing it only slides), but in
## a few places the parapet is broken: off the edge there, the swan falls (and
## comes back a few seconds later, as in space). Holes in the walkway: jump
## them or go around. Temples stand over the walkway: the swans run under
## them, and a temple bell rings as you pass. The sun sets on one side.
## Timing (SwanMotor): ~13 m/s on average for a good racer, so 1.8 km.

const LENGTH := 1800.0
const PLAZA := 60.0
const HALF_WIDTH := 5.0
## The tower platform at the finish, for the podium.
const PLAZA_HALF_WIDTH := 11.0
## Height of the walkway above the valley floor at the start.
const BASE := 40.0
## Temples over the walkway (meters from the start line).
const TEMPLES := [300.0, 700.0, 1100.0, 1500.0]
## Broken parapets: [meters from the start line, length, side].
const BREAKS := [[180.0, 10.0, 1.0], [460.0, 12.0, -1.0], [860.0, 9.0, 1.0], [1010.0, 12.0, -1.0],
		[1290.0, 10.0, 1.0], [1640.0, 11.0, -1.0]]
const HOLES := 8


func _init() -> void:
	fence_dazes = true
	start_distance = 40.0
	finish_distance = start_distance + LENGTH
	build()


func total_length() -> float:
	return finish_distance + PLAZA


## Gentle bends to both sides, like a wall following a ridge.
func _curvature(d: float) -> float:
	if d < start_distance + 30.0 or d > finish_distance - 40.0:
		return 0.0
	return 0.006 * sin(TAU * d / 520.0 + 0.4) + 0.004 * sin(TAU * d / 230.0 + 2.0)


## Long climbs and descents over the ridge (grades up to about 8%), flat at
## both ends.
func _height_at(d: float) -> float:
	var flat := smoothstep(start_distance, start_distance + 60.0, d) \
			* (1.0 - smoothstep(finish_distance - 80.0, finish_distance - 10.0, d))
	return BASE + flat * (12.0 * sin(TAU * d / 760.0 - 0.6) + 4.0 * sin(TAU * d / 290.0 + 1.0) + 12.0)


func _half_width(d: float) -> Vector2:
	var half := lerpf(HALF_WIDTH, PLAZA_HALF_WIDTH, smoothstep(finish_distance + 4.0, finish_distance + 18.0, d))
	return Vector2(half, half)


func _terrain_at(_d: float) -> int:
	return Terrain.ROAD


func stretch_name(_d: float) -> String:
	return "STRETCH_WALL"


func fall_message() -> String:
	return "CAREFUL_WALL"


func build_scenery(parent: Node3D) -> void:
	GreatWallScenery.build(parent, self)


func _place_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1368
	for gap: Array in BREAKS:
		var from: float = start_distance + gap[0]
		add_break(from, from + gap[1], gap[2])
	# Holes: never under a temple or right at a broken parapet.
	var placed := 0
	var tries := 0
	while placed < HOLES and tries < 100:
		tries += 1
		var d := start_distance + 120.0 + (LENGTH - 220.0) * (placed + rng.randf_range(0.2, 0.8)) / HOLES
		var clear := true
		for temple: float in TEMPLES:
			if absf(d - start_distance - temple) < 20.0:
				clear = false
		for gap: Array in BREAKS:
			if absf(d - start_distance - gap[0] - gap[1] * 0.5) < 20.0:
				clear = false
		if not clear:
			continue
		var width := rng.randf_range(3.0, 5.0)
		# Against one side or in the middle: there's always a way around.
		var lateral: float = [-HALF_WIDTH + width * 0.5, 0.0, HALF_WIDTH - width * 0.5][placed % 3]
		if lateral == 0.0:
			width = 3.0
		add_hole(d, lateral, 2.5, width)
		placed += 1
