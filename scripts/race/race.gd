extends Node3D
## Prototype race: laps around the island's beach (forest on the left, sea
## on the right). Countdown, lap timing in simulation time, best lap saved.

const WARDROBE_SCENE := "res://scenes/wardrobe.tscn"
const TRACK_ID := "desert_island"
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
var _music := AudioStreamPlayer.new()
var _beep := AudioStreamPlayer.new()
var _lights_lit := 0
var _go_time := 0.0

static var _music_stream: AudioStreamWAV
static var _music_rendering := false


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
	_swan.drowned.connect(func() -> void: _hud.show_message(tr("CAREFUL_WATER"), 3.0))
	add_child(_swan)
	_laps.hint = start
	_laps.distance = IslandTrack.LAP_LENGTH - GRID_OFFSET
	_laps.lap_completed.connect(_on_lap_completed)

	var footprints := Footprints.new()
	footprints.swan = _swan
	add_child(footprints)

	var camera := ChaseCamera.new()
	camera.target = _swan
	add_child(camera)
	camera.make_current()

	var fish := JumpingFish.new()
	fish.track = _track
	fish.follow = _swan
	add_child(fish)

	_hud.swan = _swan
	_hud.track = _track
	_hud.terrain_name = tr("MAP_DESERT_ISLAND")
	add_child(_hud)
	_hud.set_best(Profile.best_lap(TRACK_ID))

	_beep.bus = &"SFX"
	add_child(_beep)

	_music.bus = &"Music"
	_music.volume_db = -6.0
	add_child(_music)
	if _music_stream == null and not _music_rendering:
		# Rendering the loop takes a moment: do it off the main thread.
		_music_rendering = true
		WorkerThreadPool.add_task(func() -> void:
			_music_stream = IslandMusic.load_or_render())


func _process(delta: float) -> void:
	if _music_stream and not _music.playing:
		_music.stream = _music_stream
		_music.play()
	if not _racing:
		_countdown -= delta
		# Start lights: one red lamp and a short beep per second, then green.
		var lamps := clampi(3 - ceili(_countdown - 0.0001) + 1, 0, 3)
		if lamps != _lights_lit and _countdown > 0.0:
			_lights_lit = lamps
			_hud.set_start_lights(lamps)
			_beep.stream = Sfx.start_beep(false)
			_beep.play()
		if _countdown <= 0.0:
			_racing = true
			_swan.controls_enabled = true
			_hud.set_start_lights(3, true)
			_hud.show_message(tr("GO"), 1.2)
			_beep.stream = Sfx.start_beep(true)
			_beep.play()
			_go_time = 1.5
	elif _go_time > 0.0:
		_go_time -= delta
		if _go_time <= 0.0:
			_hud.set_start_lights(-1)
	_hud.set_lap(_laps.lap, _laps.lap_time, _last_lap)


func _on_swan_tick(swan: Swan) -> void:
	_laps.update(swan.motor.position, Swan.TICK, _racing)
	TrackRules.apply(swan, _laps, _track)


func _on_lap_completed(lap_time: float) -> void:
	_last_lap = lap_time
	if Profile.submit_lap(TRACK_ID, lap_time):
		_hud.set_best(lap_time)
		_hud.show_message(tr("MSG_BEST_LAP") % Hud.format_time(lap_time), 2.5)
	else:
		_hud.show_message(tr("MSG_LAP") % Hud.format_time(lap_time), 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().change_scene_to_file(WARDROBE_SCENE)
