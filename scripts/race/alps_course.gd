class_name AlpsCourse
extends CourseTrack
## Swiss Alps (ADR 0022): a point-to-point course in two parts, about 2:00
## for a good racer.
##   1. Ski slope (~40 s): from the top of a snowy mountain down a wide, open
##      piste with few curves. The swan skis. Pine trees and rocks to dodge
##      (rocks can be jumped) and goats wandering across the slope.
##   2. Alpine road (~1:20): a two-lane mountain road, like the ones in
##      Switzerland and Austria (no cars), with pines on both sides and many
##      curves to the left and to the right. Logs across the road (jump them
##      or go around) and animals crossing.
## Timing (SwanMotor): skiing ~18-20 m/s on the slope, running ~12.5 m/s on
## average on the curvy road. Keep in sync when the motor or the course changes.

## Flat top platform with the start line, then the slope.
const PLATFORM := 45.0
const SKI_END := 800.0
## Where the snow ends and the road begins (the swan takes its skis off).
const SNOW_END := 815.0
## Where the road (and its curves) begins.
const ROAD_START := 840.0
const ROAD_LENGTH := 1000.0
## Flat plaza past the finish line, for the podium.
const PLAZA := 60.0
const TOP_HEIGHT := 140.0
const DROP := 120.0
const SLOPE_HALF_WIDTH := 22.0
const ROAD_HALF_WIDTH := 6.0
const PLAZA_HALF_WIDTH := 14.0
## Road curves in order: [length (m), curvature (1/radius; + = right)]. Straight
## to the finish line after the last one. Checked to never cross itself.
const ROAD_CURVES := [
	[70.0, 0.0], [45.0, 1.0 / 35.0], [30.0, 0.0], [55.0, -1.0 / 40.0], [25.0, 0.0],
	[40.0, 1.0 / 30.0], [50.0, -1.0 / 45.0], [30.0, 0.0], [70.0, 1.0 / 60.0],
	[35.0, -1.0 / 28.0], [40.0, 0.0], [60.0, 1.0 / 40.0], [45.0, -1.0 / 35.0], [30.0, 0.0],
	[50.0, 1.0 / 50.0], [40.0, -1.0 / 30.0], [35.0, 0.0], [55.0, 1.0 / 45.0],
	[45.0, -1.0 / 55.0], [30.0, 0.0], [40.0, 1.0 / 35.0], [40.0, -1.0 / 35.0],
]
## Logs on the road (meters into the road) and the animals crossing it.
const ROAD_LOGS := [120.0, 330.0, 520.0, 700.0, 880.0]
const ROAD_ANIMALS := [200.0, 420.0, 610.0, 790.0, 945.0]
const GOATS := 9


func _init() -> void:
	start_distance = 40.0
	finish_distance = ROAD_START + ROAD_LENGTH
	build()


func total_length() -> float:
	return ROAD_START + ROAD_LENGTH + PLAZA


func _curvature(d: float) -> float:
	if d < PLATFORM:
		return 0.0
	if d < SKI_END:
		# A few long, gentle bends (about 300 m radius) down the slope.
		var t := (d - PLATFORM) / (SKI_END - PLATFORM)
		return 0.0035 * sin(TAU * (d - PLATFORM) / 310.0) * sin(PI * t)
	if d < ROAD_START:
		return 0.0
	var along := d - ROAD_START
	for curve: Array in ROAD_CURVES:
		if along < curve[0]:
			return curve[1]
		along -= curve[0]
	return 0.0


func _height_at(d: float) -> float:
	if d < PLATFORM:
		return TOP_HEIGHT
	if d < SKI_END:
		# Eases in and out of the steep part; small moguls along the way.
		var t := (d - PLATFORM) / (SKI_END - PLATFORM)
		var down := t - sin(TAU * t) / TAU
		return TOP_HEIGHT - DROP * down + 0.8 * sin(TAU * d / 38.0) * sin(PI * t)
	var bottom := TOP_HEIGHT - DROP
	if d < ROAD_START:
		return bottom
	# Rolling road (grades up to about 11%), flat again for the finish.
	var r := d - ROAD_START
	var fade := smoothstep(0.0, 60.0, r) * (1.0 - smoothstep(ROAD_LENGTH - 60.0, ROAD_LENGTH - 10.0, r))
	return bottom + fade * (4.0 * sin(TAU * r / 420.0) + 1.5 * sin(TAU * r / 170.0 + 1.0))


func _half_width(d: float) -> Vector2:
	var half := SLOPE_HALF_WIDTH
	if d < PLATFORM:
		half = 16.0
	elif d < SKI_END:
		half = lerpf(16.0, SLOPE_HALF_WIDTH, smoothstep(PLATFORM, PLATFORM + 40.0, d))
	elif d < ROAD_START:
		half = lerpf(SLOPE_HALF_WIDTH, ROAD_HALF_WIDTH, smoothstep(SKI_END, ROAD_START, d))
	elif d < finish_distance + 4.0:
		half = ROAD_HALF_WIDTH
	else:
		half = lerpf(ROAD_HALF_WIDTH, PLAZA_HALF_WIDTH, smoothstep(finish_distance + 4.0,
				finish_distance + 20.0, d))
	return Vector2(half, half)


func _terrain_at(d: float) -> int:
	return Terrain.SNOW if d < SNOW_END else Terrain.ROAD


func stretch_name(d: float) -> String:
	return "STRETCH_SKI_SLOPE" if d < SNOW_END else "STRETCH_ALPINE_ROAD"


func build_scenery(parent: Node3D) -> void:
	AlpsScenery.build(parent, self)


func _place_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	_place_slope_obstacles(rng)
	_place_goats(rng)
	for spot: float in ROAD_LOGS:
		# Across one side of the road, or the middle: jump it or go around.
		add_log(ROAD_START + spot, [-2.6, 0.0, 2.6][rng.randi_range(0, 2)], 6.0)
	for n in ROAD_ANIMALS.size():
		var mover := CourseMover.new()
		mover.track = self
		mover.pattern = CourseMover.Pattern.CROSS
		mover.home_distance = ROAD_START + ROAD_ANIMALS[n]
		mover.home_lateral = 0.0
		mover.reach = ROAD_HALF_WIDTH + 2.5
		mover.pause = rng.randf_range(1.5, 3.5)
		mover.phase = rng.randf_range(0.0, 20.0)
		if n % 2 == 0:
			mover.kind = "cow"
			mover.walk_speed = 0.9
			mover.radius = 1.0
			mover.height = 1.6
		else:
			mover.kind = "deer"
			mover.walk_speed = 2.2
			mover.radius = 0.6
			mover.height = 1.3
		movers.append(mover)


## Rows of pines and rocks down the slope, never closing it: each row leaves
## wide gaps. Pines are too tall to jump; rocks can be jumped.
func _place_slope_obstacles(rng: RandomNumberGenerator) -> void:
	var d := 90.0
	while d < SKI_END - 30.0:
		var i := index_at(d)
		var used: Array[float] = []
		for n in rng.randi_range(1, 3):
			var lateral := rng.randf_range(left_edge(i) + 3.0, right_edge(i) - 3.0)
			var clear := true
			for other in used:
				if absf(other - lateral) < 7.0:
					clear = false
			if not clear:
				continue
			used.append(lateral)
			var at := d + rng.randf_range(-3.0, 3.0)
			if rng.randf() < 0.7:
				add_obstacle(at, lateral, 0.8, 99.0)
			else:
				add_obstacle(at, lateral, 1.0, 0.6)
		d += rng.randf_range(11.0, 17.0)


func _place_goats(rng: RandomNumberGenerator) -> void:
	for n in GOATS:
		var mover := CourseMover.new()
		mover.track = self
		mover.kind = "goat"
		mover.pattern = CourseMover.Pattern.WANDER
		mover.home_distance = lerpf(150.0, SKI_END - 60.0, (n + rng.randf_range(0.2, 0.8)) / GOATS)
		mover.home_lateral = rng.randf_range(-10.0, 10.0)
		mover.reach = rng.randf_range(5.0, 9.0)
		mover.walk_speed = rng.randf_range(0.8, 1.4)
		mover.phase = rng.randf_range(0.0, 30.0)
		mover.radius = 0.6
		mover.height = 1.1
		movers.append(mover)
