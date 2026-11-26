class_name AndesCourse
extends CourseTrack
## Andes (ADR 0029): a point-to-point run up a mountain road in the Andes,
## inspired by Chile (not a copy of a real road), about 2:30. Two-lane asphalt
## with many curves to both sides, climbing steadily. On the right, the
## mountain rises steep and snowy: it is a solid wall, and running into it
## dazes the swan. On the left, the road ends at a cliff: off the edge, the
## swan falls (and comes back a few seconds later). Snowballs drop from the
## mountain onto random spots of the road (a shadow warns where) and roll
## across and over the cliff: dodge them. Across the valley on the left,
## another snowy range.
## Timing (SwanMotor): ~13 m/s on average on a curvy road, so ~1.95 km.

const LENGTH := 1950.0
const PLAZA := 60.0
const HALF_WIDTH := 6.0
const PLAZA_HALF_WIDTH := 12.0
## Height of the road at the start, and of the valley floor far below.
const BASE := 220.0
const VALLEY := 20.0
## Snowballs: one per stretch of this length, all along the road.
const SNOWBALL_ZONE := 70.0


func _init() -> void:
	fence_dazes = true
	start_distance = 40.0
	finish_distance = start_distance + LENGTH
	build()


func total_length() -> float:
	return finish_distance + PLAZA


## Many curves, to the right and to the left, never turning back on itself.
func _curvature(d: float) -> float:
	if d < start_distance + 20.0 or d > finish_distance - 40.0:
		return 0.0
	return 0.02 * sin(TAU * d / 190.0 + 0.3) + 0.012 * sin(TAU * d / 83.0 + 1.1) \
			+ 0.006 * sin(TAU * d / 47.0 + 2.4)


## Climbing steadily, with gentle rolls; flat at the start and the finish.
func _height_at(d: float) -> float:
	var ramp := smoothstep(start_distance, start_distance + 60.0, d)
	var climb := 0.035 * clampf(d - start_distance, 0.0, LENGTH)
	var roll := 2.0 * sin(TAU * d / 260.0) * (1.0 - smoothstep(finish_distance - 80.0, finish_distance, d))
	return BASE + climb + ramp * roll


func _half_width(d: float) -> Vector2:
	var half := lerpf(HALF_WIDTH, PLAZA_HALF_WIDTH, smoothstep(finish_distance + 4.0, finish_distance + 18.0, d))
	return Vector2(half, half)


func _terrain_at(_d: float) -> int:
	return Terrain.ROAD


func stretch_name(_d: float) -> String:
	return "STRETCH_MOUNTAIN_ROAD"


func fall_message() -> String:
	return "CAREFUL_CLIFF"


func build_scenery(parent: Node3D) -> void:
	AndesScenery.build(parent, self)


func _place_features() -> void:
	# The cliff: the whole left edge is open.
	add_break(-10.0, total_length() + 10.0, -1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1818
	var zone := start_distance + 50.0
	var n := 0
	while zone + SNOWBALL_ZONE < finish_distance - 20.0:
		var ball := Snowball.new()
		ball.track = self
		ball.kind = "snowball"
		ball.zone_from = zone
		ball.zone_to = zone + SNOWBALL_ZONE
		ball.ball_seed = 100 + n
		ball.phase = rng.randf_range(0.0, 12.0)
		movers.append(ball)
		zone += SNOWBALL_ZONE
		n += 1
