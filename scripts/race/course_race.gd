extends Node3D
## Race on a course (ADR 0022): the player and up to 11 AI swans, start
## lights, positions, timing in simulation time. On a run, one go from the
## start line to the finish line and the best total time saved; on a loop
## (ADR 0024), laps from the settings and the best lap saved, like the island.
## When the player finishes: whistle, camera pulls away, then the podium. The
## course comes from the map picked in the menu (Maps).

const MENU_SCENE := "res://scenes/home.tscn"
const COUNTDOWN := 3.0
## Grid: rows of two behind the start line.
const GRID_FIRST := 6.0
const GRID_ROW := 4.5
const GRID_SIDE := 3.0
const MUSIC_FADE := 1.5
## Share of the course after which the faster "final stretch" music plays.
const FINAL_STRETCH := 0.75
## Bot skill range per difficulty (easy, medium, hard).
const SKILL := [Vector2(0.3, 0.55), Vector2(0.5, 0.8), Vector2(0.75, 0.98)]

var _map_id := ""
var _track: CourseTrack
var _hud := Hud.new()
var _touch := TouchControls.new()
var _camera := ChaseCamera.new()
## One entry per swan: {"swan", "tracker", "name", "player", "finished", "time"}.
var _racers: Array[Dictionary] = []
var _player: Dictionary
var _countdown := COUNTDOWN
var _racing := false
var _finished := false
var _race_time := 0.0
## Seconds since the scene started (moves the animals).
var _clock := 0.0
var _finish_order := 0
var _podium_time := -1.0
var _music := AudioStreamPlayer.new()
var _final_music := AudioStreamPlayer.new()
var _podium_music := AudioStreamPlayer.new()
var _final_stretch := false
var _beep := AudioStreamPlayer.new()
var _whistle := AudioStreamPlayer.new()
var _lights_lit := 0
var _go_time := 0.0
var _stretch := ""
var _player_skiing := true
## Loops: laps from the settings.
var _laps := false
var _total_laps := 1
var _last_lap := 0.0

# Each course has its own music (samba in Rio, a Ländler in the Alps, French
# house in space), rendered once per map in a background thread. Courses keep
# their music to the end: no separate final-lap track (_final_stream stays null).
static var _map_music := {}
static var _map_music_rendering := {}
static var _final_stream: AudioStreamWAV
static var _podium_stream: AudioStreamWAV
static var _music_rendering := false
var _music_stream: AudioStreamWAV:
	get:
		return _map_music.get(_map_id)


func _ready() -> void:
	Settings.apply_menu_scale(false)
	_map_id = Settings.map
	_track = Maps.make_course(_map_id)
	if _track == null:
		get_tree().change_scene_to_file.call_deferred(Maps.CIRCUIT_SCENE)
		return
	_laps = _track.looped
	_total_laps = Settings.laps if _laps else 1
	_track.build_scenery(self)
	_spawn_racers()

	_camera.target = _player.swan
	add_child(_camera)
	_camera.make_current()
	# The mountains around the course are far away.
	_camera.far = 3000.0

	_hud.swan = _player.swan
	_hud.course = _track
	_hud.max_kmh = _track.max_kmh()
	_hud.terrain_name = tr(Maps.current().name)
	for racer in _racers:
		if not racer.player:
			_hud.others.append(racer.swan)
	add_child(_hud)
	_hud.set_best(Profile.best_lap(_map_id))
	_hud.race_again_pressed.connect(func() -> void: get_tree().reload_current_scene())
	_hud.menu_pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 3
	add_child(touch_layer)
	touch_layer.add_child(_touch)
	_touch.menu_requested.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))

	for player: AudioStreamPlayer in [_beep, _whistle]:
		player.bus = &"SFX"
		add_child(player)
	_whistle.stream = Sfx.whistle()
	for player: AudioStreamPlayer in [_music, _final_music, _podium_music]:
		player.bus = &"Music"
		player.volume_db = -6.0
		add_child(player)
	if not _map_music.has(_map_id) and not _map_music_rendering.has(_map_id):
		_map_music_rendering[_map_id] = true
		var id := _map_id
		WorkerThreadPool.add_task(func() -> void:
			var stream := _render_music(id)
			(func() -> void: _map_music[id] = stream).call_deferred())
	if _podium_stream == null and not _music_rendering:
		_music_rendering = true
		WorkerThreadPool.add_task(func() -> void:
			var stream := VictoryMusic.load_or_render()
			(func() -> void: _podium_stream = stream).call_deferred())


static func _render_music(id: String) -> AudioStreamWAV:
	match id:
		"rio_beach":
			return SambaMusic.load_or_render()
		"swiss_alps":
			return AlpineMusic.load_or_render()
		"sidereal_circuit":
			return SpaceMusic.load_or_render()
		"sao_paulo":
			return RockMusic.load_or_render()
		"german_forest":
			return BrassMusic.load_or_render()
		"tokyo":
			return AnimeMusic.load_or_render()
		"great_wall":
			return ChineseMusic.load_or_render()
		"andes":
			return CuecaMusic.load_or_render()
	return IslandMusic.load_or_render()


## The player and the bots on a grid behind the start line.
func _spawn_racers() -> void:
	var count := clampi(Settings.racers, 1, 12)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var player_slot := count / 2
	var used_names := []
	var skill_range: Vector2 = SKILL[clampi(Settings.difficulty, 0, 2)]
	var player_tracker: CourseTracker = null
	for slot in count:
		var row := slot / 2
		var side := -1.0 if slot % 2 == 0 else 1.0
		var back := GRID_FIRST + row * GRID_ROW
		# Behind the start line (on a loop it is at 0: the grid wraps around).
		var at := fposmod(-back, _track.length) if _laps else maxf(_track.start_distance - back, 1.0)
		var start := _track.index_at(at)
		var spot := _track.edge(start, side * GRID_SIDE if count > 1 else 0.0)
		var swan := Swan.new()
		swan.motor.position = Vector3(spot.x, 0.0, spot.y)
		swan.motor.heading = _track.heading_at(start)
		swan.motor.skiing = _track.terrain(at) == CourseTrack.Terrain.SNOW
		swan.ground_y = _track.ground_height_at(at, 0.0)
		swan.controls_enabled = false
		var tracker := CourseTracker.new(_track)
		tracker.hint = start
		tracker.distance = at
		var is_player := slot == player_slot
		var racer := {"swan": swan, "tracker": tracker, "player": is_player, "finished": false,
				"time": 0.0, "name": ""}
		if is_player:
			var player_input := PlayerInput.new()
			player_input.motor = swan.motor
			if Settings.difficulty == 0:
				player_input.auto_throttle = true
				player_input.auto_changed.connect(func(on: bool) -> void:
					_hud.show_message(tr("AUTO_THROTTLE_ON" if on else "AUTO_THROTTLE_OFF"), 2.0))
			swan.brain = player_input
			swan.look = Profile.look
			_player = racer
			player_tracker = tracker
		else:
			swan.look = BotLooks.make(rng, Profile.look, used_names)
			var bot := CourseBotBrain.new(rng.randf_range(skill_range.x, skill_range.y), rng.randi())
			bot.track = _track
			bot.swan = swan
			bot.tracker = tracker
			bot.rubber_band = Settings.difficulty == 0
			swan.brain = bot
		racer.name = swan.look.nickname
		racer.best = 0.0
		swan.field_size = count
		swan.on_tick = _on_swan_tick.bind(racer)
		if _laps:
			tracker.lap_completed.connect(_on_lap_completed.bind(racer))
		else:
			tracker.finished_course.connect(_on_finished_course.bind(racer))
		add_child(swan)
		_racers.append(racer)
	for racer in _racers:
		if racer.swan.brain is CourseBotBrain:
			(racer.swan.brain as CourseBotBrain).player_tracker = player_tracker
	(_player.swan as Swan).fell.connect(func() -> void: _hud.show_message(tr(_track.fall_message()), 3.0))


func _process(delta: float) -> void:
	if _track == null:
		return
	_clock += delta
	for mover in _track.movers:
		mover.advance(_clock)
	_update_music(delta)
	if not _racing and not _finished:
		_countdown -= delta
		var lamps := clampi(3 - ceili(_countdown - 0.0001) + 1, 0, 3)
		if lamps != _lights_lit and _countdown > 0.0:
			_lights_lit = lamps
			_hud.set_start_lights(lamps)
			_beep.stream = Sfx.start_beep(false)
			_beep.play()
		if _countdown <= 0.0:
			_racing = true
			for racer in _racers:
				racer.swan.controls_enabled = true
			_hud.set_start_lights(3, true)
			_hud.show_message(tr("GO"), 1.2)
			_beep.stream = Sfx.start_beep(true)
			_beep.play()
			_go_time = 1.5
	elif _go_time > 0.0:
		_go_time -= delta
		if _go_time <= 0.0:
			_hud.set_start_lights(-1)
	_push_apart()
	var tracker: CourseTracker = _player.tracker
	_update_stretch(tracker)
	_hud.show_jump_alert(Settings.obstacle_alert and _racing and not _finished
			and _track.obstacle_ahead(tracker.distance, tracker.lateral))
	if not _finished:
		if _laps:
			_hud.set_lap(mini(tracker.lap, _total_laps), _total_laps, tracker.lap_time, _last_lap,
					_race_time)
		else:
			_hud.set_progress(tracker.to_finish(), _race_time)
		_hud.set_place(_place_of(_player), _racers.size())
		if not _laps and not _final_stretch and tracker.progress() > FINAL_STRETCH \
				* (_track.finish_distance - _track.start_distance):
			_final_stretch = true
			_hud.show_message(tr("FINAL_STRETCH"), 2.5)
	elif _podium_time >= 0.0:
		_podium_time -= delta
		if _podium_time < 0.0:
			_show_podium()


## The stretch name under the nickname, and a message when the skis come off.
func _update_stretch(tracker: CourseTracker) -> void:
	var name_key := _track.stretch_name(tracker.distance)
	if name_key != _stretch:
		_stretch = name_key
		var map_name := tr(Maps.current().name)
		_hud.set_terrain(map_name if name_key == "" else "%s · %s" % [map_name, tr(name_key)])
	var skiing: bool = (_player.swan as Swan).motor.skiing
	if _player_skiing and not skiing and _racing:
		_hud.show_message(tr("SKIS_OFF"), 2.0)
	_player_skiing = skiing


func _update_music(delta: float) -> void:
	if _music_stream == null or _podium_music.playing:
		return
	if not _music.playing and not _final_stretch:
		_music.stream = _music_stream
		_music.play()
	if _final_stretch and _final_stream:
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


func _on_swan_tick(swan: Swan, racer: Dictionary) -> void:
	if racer.player and _racing and not _finished:
		_race_time += Swan.TICK
	if racer.finished:
		# After the line a swan slows down by itself.
		swan.motor.speed = move_toward(swan.motor.speed, 0.0, 6.0 * Swan.TICK)
	var tracker: CourseTracker = racer.tracker
	tracker.update(swan.motor.position, _racing and not racer.finished, Swan.TICK)
	CourseRules.apply(swan, tracker, _track)


## Loops: a lap done. After the last one the swan has finished.
func _on_lap_completed(lap_time: float, racer: Dictionary) -> void:
	var tracker: CourseTracker = racer.tracker
	if racer.best <= 0.0 or lap_time < racer.best:
		racer.best = lap_time
	if tracker.laps_done >= _total_laps:
		racer.finished = true
		racer.time = _race_time
		_finish_order += 1
		var swan: Swan = racer.swan
		swan.controls_enabled = false
		swan.finish_place = _finish_order
	if not racer.player:
		return
	_last_lap = lap_time
	var record := Profile.submit_lap(_map_id, lap_time)
	if record:
		_hud.set_best(lap_time)
	if racer.finished:
		_finish(record)
		return
	var left := _total_laps - tracker.laps_done
	var lap_text := (tr("MSG_BEST_LAP") if record else tr("MSG_LAP")) % Hud.format_time(lap_time)
	if left == 1:
		_final_stretch = true
		_hud.show_message("%s\n%s" % [tr("FINAL_LAP"), lap_text], 3.0)
	else:
		_hud.show_message("%s\n%s" % [tr("LAPS_LEFT") % left, lap_text], 3.0)


func _on_finished_course(racer: Dictionary) -> void:
	racer.finished = true
	racer.time = _race_time
	_finish_order += 1
	var swan: Swan = racer.swan
	swan.controls_enabled = false
	swan.finish_place = _finish_order
	if not racer.player:
		return
	var record := Profile.submit_lap(_map_id, _race_time)
	if record:
		_hud.set_best(_race_time)
	_finish(record)


## The player crossed the finish line: whistle, camera, podium.
func _finish(record: bool) -> void:
	_finished = true
	_touch.release_all()
	_touch.queue_free()
	_whistle.play()
	_camera.finish = true
	if _laps:
		_hud.set_lap(_total_laps, _total_laps, _last_lap, _last_lap, _race_time)
		var lap := Hud.format_time(_last_lap)
		_hud.show_message("%s\n%s" % [tr("FINISHED"), (tr("MSG_BEST_LAP") if record else tr("MSG_LAP")) % lap], 3.0)
	else:
		_hud.set_progress(0.0, _race_time)
		var time := Hud.format_time(_race_time)
		_hud.show_message("%s\n%s" % [tr("FINISHED"), (tr("MSG_BEST_TIME") if record else tr("MSG_TIME")) % time], 3.0)
	_podium_time = 4.0


## Final standings: those who finished by time, the rest by how far they got
## (with an estimated time to the line).
func _standings() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for racer in _racers:
		var time: float = racer.time
		if not racer.finished:
			var tracker: CourseTracker = racer.tracker
			var left := _total_laps * _track.length - tracker.progress() if _laps else tracker.to_finish()
			time = _race_time + maxf(left, 0.0) / (SwanMotor.MAX_SPEED * 0.8)
		var entry := {"name": racer.name, "look": racer.swan.look, "time": time,
				"player": racer.player}
		# Loops: each swan's best lap on the board too.
		if _laps:
			entry.best = racer.best
		list.append(entry)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	return list


func _show_podium() -> void:
	var standings := _standings()
	for n in standings.size():
		if standings[n].player:
			_player.swan.finish_place = n + 1
	for racer in _racers:
		var swan: Swan = racer.swan
		swan.visible = false
		swan.process_mode = Node.PROCESS_MODE_DISABLED
	_music.stop()
	_final_music.stop()
	if _podium_stream:
		_podium_music.stream = _podium_stream
		_podium_music.volume_db = -6.0
		_podium_music.play()
	var podium := Podium.new()
	podium.standings = standings
	# On the flat plaza past the finish line, facing back up the course.
	var at := _track.podium_spot() + 10.0
	var i := _track.index_at(at)
	var spot := _track.edge(i, 0.0)
	podium.position = Vector3(spot.x, _track.ground_height_at(at, 0.0), spot.y)
	podium.rotation.y = _track.heading_at(i) + PI / 2.0
	podium.ground_at = func(x: float) -> float:
		var p: Vector3 = podium.transform * Vector3(x, 0.0, 0.0)
		var info := _track.locate(Vector2(p.x, p.z), i)
		return _track.ground_height_at(info["distance"], info["lateral"]) - podium.position.y
	add_child(podium)
	_hud.show_results(standings)


## Place in the race right now (1 = leading).
func _place_of(racer: Dictionary) -> int:
	var mine: float = (racer.tracker as CourseTracker).progress()
	var place := 1
	for other in _racers:
		if other == racer:
			continue
		if other.finished and not racer.finished:
			place += 1
		elif not other.finished and not racer.finished \
				and (other.tracker as CourseTracker).progress() > mine:
			place += 1
	return place


func _push_apart() -> void:
	var swans: Array[Swan] = []
	for racer in _racers:
		swans.append(racer.swan)
	TrackRules.push_apart(swans)


func _unhandled_input(event: InputEvent) -> void:
	if _finished and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("pause") or (_finished and event.is_action_pressed("ui_cancel")):
		get_tree().change_scene_to_file(MENU_SCENE)
