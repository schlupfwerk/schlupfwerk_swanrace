class_name DemoRace
extends Node3D
## Home screen background: a race of random AI swans seen from a drone.
## Every MAP_TIME seconds it changes map.
##
## TODO(maps): there is only the Desert Island for now, so "changing map" just
## restarts it with new swans. When more maps exist, pick the next map here.

const MAP_TIME := 15.0
const RACERS := 8
## Drone: height over the pack, distance behind it, orbit speed (rad/s).
const DRONE_HEIGHT := 40.0
const DRONE_BACK := 30.0
const DRONE_ORBIT := 0.12

var _track := IslandTrack.new()
var _camera := Camera3D.new()
var _swans: Array[Swan] = []
var _laps: Array[LapTracker] = []
var _extras: Array[Node] = []
var _timer := 0.0
var _orbit := 0.0
var _focus := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	IslandScenery.build(self, _track, 1234)
	IslandScenery.build_features(self, _track)
	_camera.fov = 55.0
	_camera.far = 1500.0
	add_child(_camera)
	_restart()


func make_current() -> void:
	_camera.make_current()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_restart()
	TrackRules.push_apart(_swans)
	_move_drone(delta)


## New swans on the grid (and, one day, a new map).
func _restart() -> void:
	_timer = MAP_TIME
	for node in _extras:
		node.queue_free()
	_extras.clear()
	_swans.clear()
	_laps.clear()
	var used := []
	# Start somewhere around the lap, so each round shows another stretch.
	var start := _rng.randf_range(0.0, IslandTrack.LAP_LENGTH)
	var nobody := SwanLook.new()
	nobody.nickname = ""
	for slot in RACERS:
		var back := slot / 2 * 4.5
		var at := fposmod(start - back, IslandTrack.LAP_LENGTH)
		var i := _track.index_at(at)
		var spot := _track.edge(i, (-1.0 if slot % 2 == 0 else 1.0) * 3.0)
		var swan := Swan.new()
		swan.motor.position = Vector3(spot.x, _track.ground_height_at(at, 0.0), spot.y)
		swan.motor.heading = _track.heading_at(i)
		swan.motor.speed = 9.0
		swan.look = BotLooks.make(_rng, nobody, used)
		var laps := LapTracker.new(_track)
		laps.hint = i
		laps.distance = at
		var bot := BotBrain.new(_rng.randf_range(0.4, 1.0), _rng.randi())
		bot.track = _track
		bot.swan = swan
		bot.laps = laps
		swan.brain = bot
		swan.quiet = true
		swan.on_tick = func(s: Swan) -> void:
			laps.update(s.motor.position, Swan.TICK, false)
			TrackRules.apply(s, laps, _track)
		add_child(swan)
		var footprints := Footprints.new()
		footprints.swan = swan
		add_child(footprints)
		_swans.append(swan)
		_laps.append(laps)
		_extras.append_array([swan, footprints])
	_focus = _pack_center()
	_orbit = _rng.randf_range(-0.6, 0.6)
	_move_drone(10.0)


func _pack_center() -> Vector3:
	var sum := Vector3.ZERO
	for swan in _swans:
		sum += swan.motor.position
	return sum / maxf(_swans.size(), 1)


## High above and behind the pack, slowly circling, looking down.
func _move_drone(delta: float) -> void:
	if _swans.is_empty():
		return
	_orbit += delta * DRONE_ORBIT if delta < 1.0 else 0.0
	_focus = _focus.lerp(_pack_center(), 1.0 - exp(-2.0 * delta))
	var lead := _swans[0]
	var back := Vector3(sin(lead.motor.heading + _orbit), 0, cos(lead.motor.heading + _orbit))
	var target := _focus + back * DRONE_BACK + Vector3.UP * DRONE_HEIGHT
	_camera.position = _camera.position.lerp(target, 1.0 - exp(-1.5 * delta))
	_camera.look_at(_focus + Vector3.UP * 1.0)
