class_name SaoPauloCircuit
extends CourseTrack
## São Paulo (ADR 0025): a squeezed oval with laps, run clockwise, around a
## long city block. Two long avenues side by side, joined by a simple U-turn
## at each end; between them a green median with a two-lane bike lane (one
## lane each way). Tall buildings all around. A light drizzle falls ("garoa":
## only for the look, it changes nothing in the race). Obstacles: puddles on
## the asphalt (jump them, or splash through and slow down), pedestrians
## with umbrellas crossing the avenue at the crosswalks and people running
## across anywhere (all solid). The sidewalks are the
## limit (no falling).
## Timing (SwanMotor): ~1,240 m a lap, about 1:40 for a good racer.

## Length of each avenue (straight) and radius of the U-turns (center line), m.
const STRAIGHT := 550.0
const TURN_RADIUS := 22.0
const HALF_WIDTH := 8.0
## The lap starts this far into the first avenue (room for the grid behind).
const START_INTO := 80.0
## The bike lane in the median: half its width (two lanes of 3 m).
const BIKE_HALF := 3.0
const PUDDLES := 12
## People running across the avenue away from the crosswalks.
const RUNNERS := 7
## Crosswalks on each avenue (meters into the avenue): a pedestrian crosses at each.
const CROSSWALKS := [130.0, 280.0, 430.0]


func _init() -> void:
	var outline := PackedVector2Array()
	var lap := 2.0 * STRAIGHT + TAU * TURN_RADIUS
	var count := int(lap)
	for n in count:
		outline.append(point_at(fposmod(START_INTO + lap * n / count, lap)))
	build_loop(outline)


## The center line at `s` meters from the start of the first avenue. Seen from
## above (x right, z down) it runs clockwise: along the top avenue to the
## right, round the right end, back along the bottom avenue, round the left end.
static func point_at(s: float) -> Vector2:
	var half := STRAIGHT * 0.5
	var turn := PI * TURN_RADIUS
	if s < STRAIGHT:
		return Vector2(-half + s, -TURN_RADIUS)
	s -= STRAIGHT
	if s < turn:
		var a := -PI / 2.0 + s / TURN_RADIUS
		return Vector2(half + TURN_RADIUS * cos(a), TURN_RADIUS * sin(a))
	s -= turn
	if s < STRAIGHT:
		return Vector2(half - s, TURN_RADIUS)
	s -= STRAIGHT
	var b := PI / 2.0 + s / TURN_RADIUS
	return Vector2(-half + TURN_RADIUS * cos(b), TURN_RADIUS * sin(b))


## Distance along the lap (from the start line) of a spot `into` meters along
## avenue 0 (top) or 1 (bottom).
func avenue_distance(avenue: int, into: float) -> float:
	var from_top := into if avenue == 0 else STRAIGHT + PI * TURN_RADIUS + into
	return fposmod(from_top - START_INTO, length)


func _half_width(_d: float) -> Vector2:
	return Vector2(HALF_WIDTH, HALF_WIDTH)


func _terrain_at(_d: float) -> int:
	return Terrain.ROAD


func stretch_name(_d: float) -> String:
	return "STRETCH_AVENUE"


func build_scenery(parent: Node3D) -> void:
	SaoPauloScenery.build(parent, self)


## The podium goes on the avenue just past the start line.
func podium_spot() -> float:
	return 40.0


func _place_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1554
	# Puddles spread around the lap, clear of the start line.
	for n in PUDDLES:
		var d := 50.0 + (length - 80.0) * (n + rng.randf_range(0.25, 0.75)) / PUDDLES
		add_puddle(d, rng.randf_range(-HALF_WIDTH + 1.5, HALF_WIDTH - 1.5), rng.randf_range(1.1, 1.7))
	# A pedestrian with an umbrella at each crosswalk, crossing and waiting.
	for avenue in 2:
		for spot: float in CROSSWALKS:
			var mover := CourseMover.new()
			mover.track = self
			mover.kind = "pedestrian"
			mover.pattern = CourseMover.Pattern.CROSS
			mover.home_distance = avenue_distance(avenue, spot)
			mover.home_lateral = 0.0
			mover.reach = HALF_WIDTH + 1.0
			mover.walk_speed = rng.randf_range(1.2, 1.6)
			mover.pause = rng.randf_range(3.0, 6.0)
			mover.phase = rng.randf_range(0.0, 30.0)
			mover.radius = 0.5
			mover.height = 1.8
			movers.append(mover)
	# People who don't wait for the crosswalk: they run across the avenue
	# anywhere, quickly, and stop only a moment on the other side.
	for n in RUNNERS:
		var mover := CourseMover.new()
		mover.track = self
		mover.kind = "runner"
		mover.pattern = CourseMover.Pattern.CROSS
		mover.home_distance = 60.0 + (length - 100.0) * (n + rng.randf_range(0.3, 0.7)) / RUNNERS
		mover.home_lateral = 0.0
		mover.reach = HALF_WIDTH + 1.0
		mover.walk_speed = rng.randf_range(3.8, 4.8)
		mover.pause = rng.randf_range(1.5, 4.0)
		mover.phase = rng.randf_range(0.0, 30.0)
		mover.radius = 0.5
		mover.height = 1.8
		movers.append(mover)
