extends Node3D
## Prototype race: laps around the island's beach (forest on the left, sea
## on the right). Countdown, lap timing in simulation time, best lap saved.

const WARDROBE_SCENE := "res://scenes/wardrobe.tscn"
const TRACK_ID := "island_beach"
const COUNTDOWN := 3.0
## The swan starts this many meters behind the start line.
const GRID_OFFSET := 6.0

var _track := IslandTrack.new()
var _swan := Swan.new()
var _laps := LapTracker.new(_track)
var _hud := Hud.new()
var _countdown := COUNTDOWN
var _racing := false
var _last_lap := 0.0


func _ready() -> void:
	Scenery.add_environment(self)
	IslandScenery.build(self, _track, 1234)

	var start := _track.index_at(IslandTrack.LAP_LENGTH - GRID_OFFSET)
	var grid := _track.points[start]
	_swan.motor.position = Vector3(grid.x, 0.0, grid.y)
	_swan.motor.heading = _track.heading_at(start)
	_swan.brain = PlayerInput.new()
	_swan.look = Profile.look
	_swan.controls_enabled = false
	_swan.on_tick = _on_swan_tick
	add_child(_swan)
	_laps.hint = start
	_laps.distance = IslandTrack.LAP_LENGTH - GRID_OFFSET
	_laps.lap_completed.connect(_on_lap_completed)

	var camera := ChaseCamera.new()
	camera.target = _swan
	add_child(camera)
	camera.make_current()

	var fish := JumpingFish.new()
	fish.track = _track
	fish.follow = _swan
	add_child(fish)

	_hud.swan = _swan
	_hud.terrain_name = "Praia da Ilha"
	add_child(_hud)
	_hud.set_best(Profile.best_lap(TRACK_ID))


func _process(delta: float) -> void:
	if not _racing:
		_countdown -= delta
		if _countdown <= 0.0:
			_racing = true
			_swan.controls_enabled = true
			_hud.show_message("Vai!", 1.0)
		else:
			_hud.show_countdown(ceili(_countdown))
	_hud.set_lap(_laps.lap, _laps.lap_time, _last_lap)


func _on_swan_tick(swan: Swan) -> void:
	_laps.update(swan.motor.position, Swan.TICK, _racing)
	# Off the sand (forest or water) the swan is slower. Same rule for everyone.
	swan.motor.max_speed_scale = 1.0 if _laps.on_track() else IslandTrack.OFF_TRACK_SPEED_SCALE


func _on_lap_completed(lap_time: float) -> void:
	_last_lap = lap_time
	if Profile.submit_lap(TRACK_ID, lap_time):
		_hud.set_best(lap_time)
		_hud.show_message("Melhor volta!  %s" % Hud.format_time(lap_time), 2.5)
	else:
		_hud.show_message("Volta  %s" % Hud.format_time(lap_time), 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().change_scene_to_file(WARDROBE_SCENE)
