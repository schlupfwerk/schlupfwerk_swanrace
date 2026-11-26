class_name RioCourse
extends CourseTrack
## Rio de Janeiro (ADR 0023): an easy point-to-point run along the whole
## seafront, about 2:30. Flat all the way. The sea on the right, the beach
## between, and the city on the left: the wavy black-and-white promenade, the
## avenue and a row of apartment buildings, like Copacabana. The course is the
## bike lane, the promenade and the sand next to it, following the gentle
## curve of the bay. Obstacles: logs (jump them or go around), small puddles
## (jump them, or splash through and slow down), people strolling on the
## promenade or crossing to the beach with a surfboard, and cyclists riding up
## and down the bike lane on the left edge.
## Timing (SwanMotor): ~12.5 m/s on average for a good racer, so 1.9 km.

const LENGTH := 1900.0
const PLAZA := 60.0
## Height of the promenade and the sand: flat, a little above the sea.
const GROUND := 1.0
## The course: from the bike lane (left) to the sand (right).
const LEFT := 14.0
const RIGHT := 12.0
## The bike lane on the left edge of the course (lateral offsets).
const BIKE_FROM := -14.0
const BIKE_TO := -11.0
## Where the promenade ends and the sand begins (lateral offset).
const PROMENADE_END := -5.0
const PLAZA_RIGHT := 20.0
const LOGS := 6
const PUDDLES := 10
const STROLLERS := 16
const SURFERS := [420.0, 980.0, 1520.0]
const CYCLISTS := 9


func _init() -> void:
	start_distance = 40.0
	finish_distance = start_distance + LENGTH
	build()


func total_length() -> float:
	return finish_distance + PLAZA


## The bay: a long, gentle curve to the right (the sea side), never sharp.
func _curvature(d: float) -> float:
	return 0.0006 + 0.00035 * sin(TAU * d / 700.0 + 0.5)


func _height_at(_d: float) -> float:
	return GROUND


func _half_width(d: float) -> Vector2:
	var right := lerpf(RIGHT, PLAZA_RIGHT, smoothstep(finish_distance + 4.0, finish_distance + 20.0, d))
	return Vector2(LEFT, right)


func _terrain_at(_d: float) -> int:
	return Terrain.SAND


func stretch_name(_d: float) -> String:
	return "STRETCH_SEAFRONT"


func build_scenery(parent: Node3D) -> void:
	RioScenery.build(parent, self)


func _place_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1965
	# Logs and puddles spread along the run, never right on top of each other.
	var spots: Array[float] = []
	var first := start_distance + 60.0
	var span := LENGTH - 120.0
	for n in LOGS + PUDDLES:
		spots.append(first + span * (n + rng.randf_range(0.25, 0.75)) / (LOGS + PUDDLES))
	for n in spots.size():
		# Every third spot is a log; the rest are puddles.
		if n % 3 == 1 and logs.size() < LOGS:
			add_log(spots[n], rng.randf_range(-8.0, 8.0), 5.0)
		else:
			add_puddle(spots[n], rng.randf_range(-9.0, 9.5), rng.randf_range(1.1, 1.6))
	for n in STROLLERS:
		var mover := CourseMover.new()
		mover.track = self
		mover.kind = "person"
		mover.pattern = CourseMover.Pattern.STROLL
		mover.home_distance = lerpf(first, finish_distance - 30.0, (n + rng.randf_range(0.2, 0.8)) / STROLLERS)
		mover.home_lateral = rng.randf_range(BIKE_TO + 0.8, PROMENADE_END - 0.5)
		mover.reach = rng.randf_range(8.0, 16.0)
		mover.walk_speed = rng.randf_range(0.9, 1.4)
		mover.phase = rng.randf_range(0.0, 40.0)
		mover.radius = 0.4
		mover.height = 1.7
		movers.append(mover)
	for spot: float in SURFERS:
		var mover := CourseMover.new()
		mover.track = self
		mover.kind = "surfer"
		mover.pattern = CourseMover.Pattern.CROSS
		mover.home_distance = start_distance + spot
		mover.home_lateral = (RIGHT - LEFT) * 0.5
		mover.reach = (LEFT + RIGHT) * 0.5 + 1.0
		mover.walk_speed = 1.3
		mover.pause = rng.randf_range(2.0, 4.0)
		mover.phase = rng.randf_range(0.0, 20.0)
		mover.radius = 0.5
		mover.height = 1.7
		movers.append(mover)
	# Cyclists ride up and down the bike lane, much faster than people walk.
	for n in CYCLISTS:
		var mover := CourseMover.new()
		mover.track = self
		mover.kind = "cyclist"
		mover.pattern = CourseMover.Pattern.STROLL
		mover.home_distance = lerpf(first + 50.0, finish_distance - 90.0, (n + rng.randf_range(0.3, 0.7)) / CYCLISTS)
		mover.home_lateral = (BIKE_FROM + BIKE_TO) * 0.5 + (0.6 if n % 2 == 0 else -0.6)
		mover.reach = rng.randf_range(40.0, 70.0)
		mover.walk_speed = rng.randf_range(4.0, 5.5)
		mover.phase = rng.randf_range(0.0, 60.0)
		mover.radius = 0.6
		mover.height = 1.7
		movers.append(mover)
