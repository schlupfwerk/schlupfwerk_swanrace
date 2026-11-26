class_name GermanyCircuit
extends CourseTrack
## German Forest (ADR 0026): an original race circuit in a German forest, with
## laps, about 2:00 a lap. Inspired by the old circuits winding through the
## woods of western Germany, but not a copy of any real track (no real name or
## layout). Many curves to both sides, rolling up and down hills, red and white
## kerbs in the curves, a grandstand at the start and forest all around.
## Obstacles: low hay bales on the track (jump them or go around) and deer
## and wild boars crossing. Guard rails at the edges (you slide along them).
## Timing (SwanMotor): ~1,550 m a lap, about 2:00 for a good racer.

const LAP := 1550.0
const HALF_WIDTH := 7.0
const OUTLINE_POINTS := 3000
## The outline: a closed, wavy loop (a radius that changes with the angle; it
## never crosses itself). Harmonics: [order, amount, phase].
const WAVES := [[3, 0.24, 0.4], [5, 0.13, 1.9], [8, 0.06, 0.7]]
const STRETCH := Vector2(1.3, 0.85)
## Hills: [laps per wave, height in meters, phase], whole waves so the lap closes.
const HILLS := [[2, 5.0, 0.0], [3, 2.5, 1.2], [7, 0.8, 2.0]]
const HAY_BALES := 9
const CROSSINGS := 4


func _init() -> void:
	# The fences at both edges are solid: running into them dazes.
	daze_sides = [-1.0, 1.0]
	# Shape the loop, then scale it to the lap length.
	var raw := PackedVector2Array()
	for n in OUTLINE_POINTS:
		var t := TAU * n / OUTLINE_POINTS
		var r := 1.0
		for wave: Array in WAVES:
			r += wave[1] * sin(wave[0] * t + wave[2])
		raw.append(Vector2(STRETCH.x * r * cos(t), STRETCH.y * r * sin(t)))
	var perimeter := 0.0
	for n in OUTLINE_POINTS:
		perimeter += raw[n].distance_to(raw[(n + 1) % OUTLINE_POINTS])
	var scale := LAP / perimeter
	for n in OUTLINE_POINTS:
		raw[n] *= scale
	# Start on the straightest stretch: the grid and the grandstand go there.
	var start := _straightest(raw, 90)
	var outline := PackedVector2Array()
	for n in OUTLINE_POINTS:
		outline.append(raw[(start + n) % OUTLINE_POINTS])
	build_loop(outline)


## Index where the next `span` points turn the least.
static func _straightest(raw: PackedVector2Array, span: int) -> int:
	var count := raw.size()
	var turns := PackedFloat32Array()
	turns.resize(count)
	for n in count:
		var a := raw[(n - 1 + count) % count]
		var b := raw[n]
		var c := raw[(n + 1) % count]
		turns[n] = absf((b - a).angle_to(c - b))
	var best := 0
	var best_sum := INF
	var window := 0.0
	for n in span:
		window += turns[n]
	for n in count:
		if window < best_sum:
			best_sum = window
			best = n
		window += turns[(n + span) % count] - turns[n]
	# Start a third of the way in, so the grid behind it is straight too.
	return (best + span / 3) % count


func _height_at(d: float) -> float:
	var h := 0.0
	for hill: Array in HILLS:
		h += hill[1] * sin(TAU * hill[0] * d / LAP + hill[2])
	# Flat at the start line (the grid and the grandstand).
	var from_start := absf(wrapf(d, -LAP * 0.5, LAP * 0.5))
	return h * smoothstep(40.0, 120.0, from_start) + 6.0


func _half_width(_d: float) -> Vector2:
	return Vector2(HALF_WIDTH, HALF_WIDTH)


func _terrain_at(_d: float) -> int:
	return Terrain.ROAD


func stretch_name(_d: float) -> String:
	return "STRETCH_FOREST"


func build_scenery(parent: Node3D) -> void:
	GermanyScenery.build(parent, self)


## The podium goes on the straight just past the start line.
func podium_spot() -> float:
	return 40.0


## How sharply the track turns at sample i (radians per meter, + = right).
func turn_at(i: int) -> float:
	return tangent(i - 3).angle_to(tangent(i + 3)) / 6.0


func _place_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1927
	# Hay bales: never near the start, and not right in a curve's apex.
	var placed := 0
	var n := 0
	while placed < HAY_BALES and n < 200:
		n += 1
		var d := 90.0 + (length - 150.0) * (placed + rng.randf_range(0.2, 0.8)) / HAY_BALES
		if absf(turn_at(index_at(d))) > 0.02:
			continue
		add_obstacle(d, rng.randf_range(-HALF_WIDTH + 1.5, HALF_WIDTH - 1.5), 0.9, 0.6)
		placed += 1
	for k in CROSSINGS:
		var mover := CourseMover.new()
		mover.track = self
		mover.kind = "deer" if k % 2 == 0 else "boar"
		mover.pattern = CourseMover.Pattern.CROSS
		mover.home_distance = length * (k + 0.5) / CROSSINGS + rng.randf_range(-40.0, 40.0)
		mover.home_lateral = 0.0
		mover.reach = HALF_WIDTH + 2.5
		mover.pause = rng.randf_range(2.0, 4.0)
		mover.phase = rng.randf_range(0.0, 20.0)
		mover.walk_speed = 2.2 if mover.kind == "deer" else 1.6
		mover.radius = 0.6 if mover.kind == "deer" else 0.55
		mover.height = 1.3 if mover.kind == "deer" else 0.9
		movers.append(mover)
