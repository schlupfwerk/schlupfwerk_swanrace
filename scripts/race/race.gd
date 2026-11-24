extends Node3D
## Race on the Desert Island: start lights, a number of laps (from the
## settings), timing in simulation time, best lap saved. The last lap switches
## to faster music; crossing the line after it ends the race with a whistle,
## the camera pulling away and the results.

const WARDROBE_SCENE := "res://scenes/wardrobe.tscn"
const RACE_SCENE := "res://scenes/race.tscn"
const TRACK_ID := "desert_island"
const COUNTDOWN := 3.0
## The swan starts this many meters behind the start line.
const GRID_OFFSET := 6.0
## Seconds to cross-fade into the final lap music.
const MUSIC_FADE := 1.5

var _track := IslandTrack.new()
var _swan := Swan.new()
var _laps := LapTracker.new(_track)
var _hud := Hud.new()
var _camera := ChaseCamera.new()
var _countdown := COUNTDOWN
var _racing := false
var _finished := false
var _total_laps := 3
var _race_time := 0.0
var _last_lap := 0.0
var _music := AudioStreamPlayer.new()
var _final_music := AudioStreamPlayer.new()
var _final_lap := false
var _beep := AudioStreamPlayer.new()
var _whistle := AudioStreamPlayer.new()
var _lights_lit := 0
var _go_time := 0.0
## Seconds until the next "use the turbo" tip may show.
var _tip_cooldown := 8.0

static var _music_stream: AudioStreamWAV
static var _final_stream: AudioStreamWAV
static var _music_rendering := false


func _ready() -> void:
	_total_laps = Settings.laps
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

	_camera.target = _swan
	add_child(_camera)
	_camera.make_current()

	var fish := JumpingFish.new()
	fish.track = _track
	fish.follow = _swan
	add_child(fish)

	_hud.swan = _swan
	_hud.track = _track
	_hud.terrain_name = tr("MAP_DESERT_ISLAND")
	add_child(_hud)
	_hud.set_best(Profile.best_lap(TRACK_ID))

	for player: AudioStreamPlayer in [_beep, _whistle]:
		player.bus = &"SFX"
		add_child(player)
	_whistle.stream = Sfx.whistle()
	for player: AudioStreamPlayer in [_music, _final_music]:
		player.bus = &"Music"
		player.volume_db = -6.0
		add_child(player)
	if _music_stream == null and not _music_rendering:
		# Rendering the loops takes a moment: do it off the main thread.
		_music_rendering = true
		WorkerThreadPool.add_task(func() -> void:
			_music_stream = IslandMusic.load_or_render()
			_final_stream = FinalLapMusic.load_or_render())
	# A one-lap race is the final lap from the start.
	_final_lap = _total_laps == 1


func _process(delta: float) -> void:
	_update_music(delta)
	if not _racing and not _finished:
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
	_update_tips(delta)
	if not _finished:
		_hud.set_lap(mini(_laps.lap, _total_laps), _total_laps, _laps.lap_time, _last_lap,
				_race_time)


## Island music during the race; the final lap fades into the faster track.
func _update_music(delta: float) -> void:
	if _music_stream == null:
		return
	if not _music.playing and not _final_lap:
		_music.stream = _music_stream
		_music.play()
	if _final_lap and _final_stream:
		if not _final_music.playing:
			_final_music.stream = _final_stream
			_final_music.volume_db = -40.0
			_final_music.play()
		var step := 40.0 * delta / MUSIC_FADE
		_final_music.volume_db = move_toward(_final_music.volume_db, -6.0, step)
		if _music.playing:
			_music.volume_db = move_toward(_music.volume_db, -40.0, step)
			if _music.volume_db <= -39.0:
				_music.stop()


func _on_swan_tick(swan: Swan) -> void:
	if _racing and not _finished:
		_race_time += Swan.TICK
	if _finished:
		# After the line the swan slows down by itself.
		swan.motor.speed = move_toward(swan.motor.speed, 0.0, 6.0 * Swan.TICK)
	_laps.update(swan.motor.position, Swan.TICK, _racing and not _finished)
	TrackRules.apply(swan, _laps, _track)


func _on_lap_completed(lap_time: float) -> void:
	_last_lap = lap_time
	var completed := _laps.lap
	var record := Profile.submit_lap(TRACK_ID, lap_time)
	if record:
		_hud.set_best(lap_time)
	if completed >= _total_laps:
		_finish()
		return
	var left := _total_laps - completed
	var lap_text := (tr("MSG_BEST_LAP") if record else tr("MSG_LAP")) % Hud.format_time(lap_time)
	if left == 1:
		_final_lap = true
		_hud.show_message("%s\n%s" % [tr("FINAL_LAP"), lap_text], 3.0)
	else:
		_hud.show_message("%s\n%s" % [tr("LAPS_LEFT") % left, lap_text], 3.0)


## Crossed the line after the last lap: whistle, camera pulls away, results.
func _finish() -> void:
	_finished = true
	_racing = false
	_swan.controls_enabled = false
	_whistle.play()
	_camera.finish = true
	_hud.set_lap(_total_laps, _total_laps, _last_lap, _last_lap, _race_time)
	_hud.show_results(_race_time, Profile.best_lap(TRACK_ID))


func _unhandled_input(event: InputEvent) -> void:
	if _finished and event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file(RACE_SCENE)
	elif event.is_action_pressed("pause") or (_finished and event.is_action_pressed("ui_cancel")):
		get_tree().change_scene_to_file(WARDROBE_SCENE)


## Tips mode: suggest the turbo on a steep climb when there is stamina for it.
func _update_tips(delta: float) -> void:
	_tip_cooldown -= delta
	if not _racing or _finished or _tip_cooldown > 0.0 or not Settings.shows_direction():
		return
	var motor := _swan.motor
	if motor.slope > 0.08 and motor.stamina > 0.6 and not motor.boosting:
		_hud.show_message(tr("USE_TURBO"), 2.0)
		_tip_cooldown = 15.0
