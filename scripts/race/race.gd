extends Node3D
## Race on the Desert Island: the player and up to 11 AI swans (local AI),
## start lights, laps from the settings, positions, timing in simulation time,
## best lap saved. The last lap switches to faster music; when the player
## crosses the line after it: whistle, camera pulls away, then the podium.

const MENU_SCENE := "res://scenes/home.tscn"
const RACE_SCENE := "res://scenes/race.tscn"
const TRACK_ID := "desert_island"
const COUNTDOWN := 3.0
## Grid: rows of two behind the start line.
const GRID_FIRST := 6.0
const GRID_ROW := 4.5
const GRID_SIDE := 3.0
## Seconds to cross-fade into the final lap music.
const MUSIC_FADE := 1.5
## Bot skill range per difficulty (easy, medium, hard).
const SKILL := [Vector2(0.3, 0.55), Vector2(0.5, 0.8), Vector2(0.75, 0.98)]

var _track := IslandTrack.new()
var _hud := Hud.new()
var _camera := ChaseCamera.new()
## One entry per swan: {"swan", "laps", "name", "player", "finished", "time"}.
var _racers: Array[Dictionary] = []
var _player: Dictionary
var _countdown := COUNTDOWN
var _racing := false
var _finished := false
var _total_laps := 3
var _race_time := 0.0
var _last_lap := 0.0
var _finish_order := 0
var _podium_time := -1.0
var _music := AudioStreamPlayer.new()
var _final_music := AudioStreamPlayer.new()
var _podium_music := AudioStreamPlayer.new()
var _final_lap := false
var _beep := AudioStreamPlayer.new()
var _whistle := AudioStreamPlayer.new()
var _waves := AudioStreamPlayer.new()
var _lights_lit := 0
var _go_time := 0.0
## Seconds until the next "use the turbo" tip may show.
var _tip_cooldown := 8.0

static var _music_stream: AudioStreamWAV
static var _final_stream: AudioStreamWAV
static var _podium_stream: AudioStreamWAV
static var _music_rendering := false


func _ready() -> void:
	_total_laps = Settings.laps
	Scenery.add_environment(self)
	IslandScenery.build(self, _track, 1234)
	IslandScenery.build_features(self, _track)
	_spawn_racers()

	_camera.target = _player.swan
	add_child(_camera)
	_camera.make_current()

	var fish := JumpingFish.new()
	fish.track = _track
	fish.follow = _player.swan
	add_child(fish)

	_hud.swan = _player.swan
	_hud.track = _track
	_hud.terrain_name = tr("MAP_DESERT_ISLAND")
	for racer in _racers:
		if not racer.player:
			_hud.others.append(racer.swan)
	add_child(_hud)
	_hud.set_best(Profile.best_lap(TRACK_ID))

	for player: AudioStreamPlayer in [_beep, _whistle]:
		player.bus = &"SFX"
		add_child(player)
	_whistle.stream = Sfx.whistle()
	# Waves on the beach all the time, softly.
	_waves.stream = Sfx.waves()
	_waves.bus = &"SFX"
	_waves.volume_db = -16.0
	add_child(_waves)
	_waves.play()
	for player: AudioStreamPlayer in [_music, _final_music, _podium_music]:
		player.bus = &"Music"
		player.volume_db = -6.0
		add_child(player)
	if _music_stream == null and not _music_rendering:
		# Rendering the loops takes a moment: do it off the main thread.
		_music_rendering = true
		WorkerThreadPool.add_task(func() -> void:
			_music_stream = IslandMusic.load_or_render()
			_final_stream = FinalLapMusic.load_or_render()
			_podium_stream = VictoryMusic.load_or_render())
	# A one-lap race is the final lap from the start.
	_final_lap = _total_laps == 1


## The player and the bots on a grid behind the start line.
func _spawn_racers() -> void:
	var count := clampi(Settings.racers, 1, 12)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var player_slot := count / 2
	var used_names := []
	var skill_range: Vector2 = SKILL[clampi(Settings.difficulty, 0, 2)]
	var player_laps: LapTracker = null
	for slot in count:
		var row := slot / 2
		var side := -1.0 if slot % 2 == 0 else 1.0
		var back := GRID_FIRST + row * GRID_ROW
		var start := _track.index_at(IslandTrack.LAP_LENGTH - back)
		var spot := _track.edge(start, side * GRID_SIDE if count > 1 else 0.0)
		var swan := Swan.new()
		swan.motor.position = Vector3(spot.x, 0.0, spot.y)
		swan.motor.heading = _track.heading_at(start)
		swan.controls_enabled = false
		var laps := LapTracker.new(_track)
		laps.hint = start
		laps.distance = IslandTrack.LAP_LENGTH - back
		var is_player := slot == player_slot
		var racer := {"swan": swan, "laps": laps, "player": is_player, "finished": false,
				"time": 0.0, "name": "", "best": 0.0}
		if is_player:
			swan.brain = PlayerInput.new()
			swan.look = Profile.look
			_player = racer
			player_laps = laps
		else:
			swan.look = BotLooks.make(rng, Profile.look, used_names)
			var bot := BotBrain.new(rng.randf_range(skill_range.x, skill_range.y), rng.randi())
			bot.track = _track
			bot.swan = swan
			bot.laps = laps
			bot.rubber_band = Settings.difficulty == 0
			swan.brain = bot
		racer.name = swan.look.nickname
		swan.field_size = count
		swan.on_tick = _on_swan_tick.bind(racer)
		laps.lap_completed.connect(_on_lap_completed.bind(racer))
		add_child(swan)
		var footprints := Footprints.new()
		footprints.swan = swan
		add_child(footprints)
		_racers.append(racer)
	# Bots look at the player's progress for easy mode's catch-up.
	for racer in _racers:
		if racer.swan.brain is BotBrain:
			(racer.swan.brain as BotBrain).player_laps = player_laps
	_player.swan.drowned.connect(func() -> void: _hud.show_message(tr("CAREFUL_WATER"), 3.0))


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
	_update_tips(delta)
	var player_laps: LapTracker = _player.laps
	_hud.show_jump_alert(Settings.obstacle_alert and _racing and not _finished
			and _track.obstacle_ahead(player_laps.distance, player_laps.lateral))
	if not _finished:
		_hud.set_lap(mini(player_laps.lap, _total_laps), _total_laps, player_laps.lap_time,
				_last_lap, _race_time)
		_hud.set_place(_place_of(_player), _racers.size())
	elif _podium_time >= 0.0:
		_podium_time -= delta
		if _podium_time < 0.0:
			_show_podium()


## Island music during the race; the final lap fades into the faster track.
func _update_music(delta: float) -> void:
	if _music_stream == null or _podium_music.playing:
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


func _on_swan_tick(swan: Swan, racer: Dictionary) -> void:
	if racer.player and _racing and not _finished:
		_race_time += Swan.TICK
	if racer.finished:
		# After the line a swan slows down by itself.
		swan.motor.speed = move_toward(swan.motor.speed, 0.0, 6.0 * Swan.TICK)
	var laps: LapTracker = racer.laps
	laps.update(swan.motor.position, Swan.TICK, _racing and not racer.finished)
	TrackRules.apply(swan, laps, _track)


func _on_lap_completed(lap_time: float, racer: Dictionary) -> void:
	var laps: LapTracker = racer.laps
	if racer.best <= 0.0 or lap_time < racer.best:
		racer.best = lap_time
	if laps.laps_done >= _total_laps:
		_racer_finished(racer)
	if not racer.player:
		return
	_last_lap = lap_time
	var record := Profile.submit_lap(TRACK_ID, lap_time)
	if record:
		_hud.set_best(lap_time)
	if racer.finished:
		_finish()
		return
	var left := _total_laps - laps.laps_done
	var lap_text := (tr("MSG_BEST_LAP") if record else tr("MSG_LAP")) % Hud.format_time(lap_time)
	if left == 1:
		_final_lap = true
		_hud.show_message("%s\n%s" % [tr("FINAL_LAP"), lap_text], 3.0)
	else:
		_hud.show_message("%s\n%s" % [tr("LAPS_LEFT") % left, lap_text], 3.0)


func _racer_finished(racer: Dictionary) -> void:
	racer.finished = true
	racer.time = _race_time
	_finish_order += 1
	var swan: Swan = racer.swan
	swan.controls_enabled = false
	swan.finish_place = _finish_order


## The player crossed the line after the last lap: whistle, camera, podium.
func _finish() -> void:
	_finished = true
	_whistle.play()
	_camera.finish = true
	_hud.set_lap(_total_laps, _total_laps, _last_lap, _last_lap, _race_time)
	_hud.show_message(tr("FINISHED"), 3.0)
	_podium_time = 4.0


## Final standings: those who finished by time, the rest by how far they got
## (with an estimated time to the line).
func _standings() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for racer in _racers:
		var time: float = racer.time
		if not racer.finished:
			var laps: LapTracker = racer.laps
			var left := _total_laps * IslandTrack.LAP_LENGTH - laps.progress()
			time = _race_time + maxf(left, 0.0) / (SwanMotor.MAX_SPEED * 0.8)
		list.append({"name": racer.name, "look": racer.swan.look, "time": time,
				"player": racer.player, "best": racer.best})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	return list


func _show_podium() -> void:
	var standings := _standings()
	for n in standings.size():
		if standings[n].player:
			_player.swan.finish_place = n + 1
	# Race over: the swans leave the beach to the podium, and the music changes.
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
	var at := 30.0
	var spot := _track.edge(_track.index_at(at), 0.0)
	podium.position = Vector3(spot.x, _track.ground_height_at(at, 0.0), spot.y)
	podium.rotation.y = _track.heading_at(_track.index_at(at)) + PI / 2.0
	podium.ground_at = func(x: float) -> float:
		var p: Vector3 = podium.transform * Vector3(x, 0.0, 0.0)
		var info := _track.locate(Vector2(p.x, p.z), -1)
		return _track.ground_height_at(info["distance"], info["lateral"]) - podium.position.y
	add_child(podium)
	_hud.show_results(standings)


## Place in the race right now (1 = leading).
func _place_of(racer: Dictionary) -> int:
	var mine: float = (racer.laps as LapTracker).progress()
	var place := 1
	for other in _racers:
		if other == racer:
			continue
		if other.finished and not racer.finished:
			place += 1
		elif not other.finished and not racer.finished and (other.laps as LapTracker).progress() > mine:
			place += 1
	return place


## Swans have a body: when two touch, they push each other apart a little.
func _push_apart() -> void:
	var swans: Array[Swan] = []
	for racer in _racers:
		swans.append(racer.swan)
	TrackRules.push_apart(swans)


## Tips mode: suggest the turbo on a steep climb when there is stamina for it.
func _update_tips(delta: float) -> void:
	_tip_cooldown -= delta
	if not _racing or _finished or _tip_cooldown > 0.0 or not Settings.shows_direction():
		return
	var motor: SwanMotor = _player.swan.motor
	if motor.slope > 0.08 and motor.stamina > 0.6 and not motor.boosting:
		_hud.show_message(tr("USE_TURBO"), 2.0)
		_tip_cooldown = 15.0


func _unhandled_input(event: InputEvent) -> void:
	if _finished and event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file(RACE_SCENE)
	elif event.is_action_pressed("pause") or (_finished and event.is_action_pressed("ui_cancel")):
		get_tree().change_scene_to_file(MENU_SCENE)
