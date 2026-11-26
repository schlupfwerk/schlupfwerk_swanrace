class_name Swan
extends Node3D
## A racing swan: a brain decides, SwanMotor moves, SwanModel shows.
## The simulation runs at a fixed tick (deterministic); rendering
## interpolates between ticks so it stays smooth at any frame rate.

const TICK := 1.0 / 60.0
## Seconds without control after bumping into the forest.
const STUN_TIME := 2.5
## Seconds of the drowning animation before the swan is put back on the track.
const DROWN_TIME := 1.8
## Seconds of blinking (fading in) after coming back from the water.
const BLINK_TIME := 5.0
## Blinking after being put past an obstacle it ran into.
const OBSTACLE_BLINK_TIME := 2.0

## Fell too deep into the sea (to show a warning).
signal drowned

var brain: SwanBrain
var look := SwanLook.new()
var motor := SwanMotor.new()
var intent := SwanIntent.new()
var model := SwanModel.new()
## When false the swan ignores its brain (countdown, results).
var controls_enabled := true
## No sounds at all (the demo race behind the home menu).
var quiet := false
## Called after every simulation tick with this swan (terrain, laps, timing).
var on_tick: Callable
## Height of the ground under the swan (sand 0, lower in the sea). Set by the track.
var ground_y := 0.0
## True while wading in the sea (set by the track): slow, wet, splashing.
var in_water := false
## Place at the finish (1 = winner, 0 = still racing) and how many raced.
var finish_place := 0
var field_size := 1
## Tilt of the ground under the swan (radians), set by the track.
var ground_pitch := 0.0
var ground_roll := 0.0

var _accumulator := 0.0
var _previous_position := Vector3.ZERO
var _previous_heading := 0.0
var _name_label := Label3D.new()
var _step_player := _make_player(-8.0)
var _jump_player := _make_player(-6.0)
var _land_player := _make_player(-4.0)
var _bump_player := _make_player(-2.0)
var _stun := 0.0
var _recover_heading := 0.0
var _render_ground := 0.0
var _drown := 0.0
var _respawn_position := Vector3.ZERO
var _respawn_heading := 0.0
var _blink := 0.0
var _pet_player := _make_player(-6.0)
var _pet_timer := 3.0
var _horn_player := _make_player(-2.0)
var _horn_cooldown := 0.0
var _lose_player := AudioStreamPlayer.new()
var _drown_bubbles := DrownBubbles.new()


func _ready() -> void:
	add_child(model)
	_name_label.position = Vector3(0, 3.0, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 48
	_name_label.outline_size = 12
	_name_label.pixel_size = 0.006
	add_child(_name_label)
	_step_player.stream = Sfx.footsteps()
	_step_player.max_polyphony = 4
	_jump_player.stream = Sfx.jump()
	_land_player.stream = Sfx.land()
	_bump_player.stream = Sfx.land()
	_bump_player.pitch_scale = 0.6
	for player in [_step_player, _jump_player, _land_player, _bump_player, _pet_player, _horn_player]:
		if quiet:
			player.volume_db = -80.0
		add_child(player)
	model.stepped.connect(_on_stepped)
	_lose_player.stream = Sfx.lose()
	_lose_player.bus = &"SFX"
	add_child(_lose_player)
	if quiet:
		_drown_bubbles.quiet = true
	add_child(_drown_bubbles)
	set_look(look)
	_previous_position = motor.position
	_previous_heading = motor.heading


func set_look(new_look: SwanLook) -> void:
	look = new_look
	model.apply_look(look)
	_name_label.text = look.nickname


func _process(delta: float) -> void:
	_accumulator += minf(delta, 0.25)
	var jumped := false
	var landed := false
	var fall_speed := 0.0
	while _accumulator >= TICK:
		_previous_position = motor.position
		_previous_heading = motor.heading
		if _drown > 0.0:
			_drown -= TICK
			intent.reset()
			motor.speed = 0.0
			if _drown <= 0.0:
				_respawn()
		elif _stun > 0.0:
			# Dazed after hitting the forest: no control, turn back to the race.
			_stun -= TICK
			intent.reset()
			motor.heading = lerp_angle(motor.heading, _recover_heading, 0.05)
		elif brain and controls_enabled:
			brain.update_intent(intent, TICK)
		else:
			intent.reset()
		var vertical_before := motor.vertical_velocity
		motor.step(intent, TICK)
		if on_tick.is_valid():
			on_tick.call(self)
		jumped = jumped or motor.jumped
		if motor.landed:
			landed = true
			fall_speed = -vertical_before
		_accumulator -= TICK
	var alpha := _accumulator / TICK
	position = _previous_position.lerp(motor.position, alpha)
	# Follow the ground closely (it is smooth now); only soften real steps.
	_render_ground = lerpf(_render_ground, ground_y, 1.0 - exp(-40.0 * delta))
	position.y += _render_ground
	var sinking := 1.0 - _drown / DROWN_TIME if _drown > 0.0 else 0.0
	position.y -= sinking * 1.2
	model.drowning = sinking if _drown > 0.0 else 0.0
	if _blink > 0.0:
		_blink = maxf(_blink - delta, 0.0)
		# Fades in from see-through to solid, blinking all the way.
		var shown := 1.0 - _blink / BLINK_TIME
		var on := fmod(_blink, 0.25) > 0.1
		model.set_fade(maxf(shown, 0.15) * (1.0 if on else 0.4) if _blink > 0.0 else 1.0)
	rotation.y = lerp_angle(_previous_heading, motor.heading, alpha)
	# Lean with the ground: nose up on climbs, tilted on banked curves.
	var tilt := 1.0 - exp(-8.0 * delta)
	rotation.x = lerpf(rotation.x, ground_pitch, tilt)
	rotation.z = lerpf(rotation.z, ground_roll, tilt)
	if jumped:
		model.take_off()
		_jump_player.pitch_scale = randf_range(0.95, 1.05)
		_jump_player.play()
	if landed:
		var strength := clampf(fall_speed / SwanMotor.JUMP_VELOCITY, 0.0, 1.0)
		model.land(strength)
		_land_player.volume_db = linear_to_db(lerpf(0.5, 1.0, strength)) - 4.0
		_land_player.play()
	_update_pet(delta)
	_update_horn(delta)
	model.expression = _face()
	model.wet = in_water
	model.boosting = motor.boosting
	model.gliding = not motor.on_ground and motor.vertical_velocity < 0.0
	model.skiing = motor.skiing
	model.effort = clampf((motor.slope - 0.04) * 10.0, 0.0, 1.0) * (1.0 if intent.accel > 0.3 else 0.4)
	model.animate(delta, motor.speed_ratio(), intent.steer, intent.accel,
			intent.brake if motor.braking else 0.0,
			motor.on_ground)


func is_stunned() -> bool:
	return _stun > 0.0


## Hit the forest: stop, daze for a moment, then face `race_heading` again.
func bump(race_heading: float) -> void:
	motor.speed = 0.0
	_stun = STUN_TIME
	_recover_heading = race_heading
	model.daze()
	_bump_player.play()


func _on_stepped(strength: float, _foot: int) -> void:
	_step_player.volume_db = linear_to_db(lerpf(0.4, 1.0, strength)) - 8.0
	_step_player.play()


static func _make_player(volume_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = &"SFX"
	player.volume_db = volume_db
	player.unit_size = 6.0
	player.position = Vector3(0, 0.3, 0)
	return player


func is_drowning() -> bool:
	return _drown > 0.0


## Too deep in the sea: sink and flap for a moment, then come back at
## `at` (on the racing line), stopped and facing `heading`.
func drown(at: Vector3, heading: float) -> void:
	_drown = DROWN_TIME
	_respawn_position = at
	_respawn_heading = heading
	motor.speed = 0.0
	drowned.emit()
	# The losing jingle is for the player only.
	if brain is PlayerInput:
		_lose_player.play()
	_drown_bubbles.release(global_position + Vector3(0, 1.6, 0))


func _respawn() -> void:
	motor.position = _respawn_position
	motor.heading = _respawn_heading
	motor.speed = 0.0
	motor.vertical_velocity = 0.0
	motor.on_ground = true
	_previous_position = motor.position
	_previous_heading = motor.heading
	_render_ground = ground_y
	in_water = false
	_blink = BLINK_TIME


## A pet in the bag makes noise now and then (and when the swan bumps).
func _update_pet(delta: float) -> void:
	var sound: AudioStreamWAV = null
	if look.is_wearing("dog_bag"):
		sound = Sfx.bark()
	elif look.is_wearing("cat_bag"):
		sound = Sfx.meow()
	if sound == null:
		return
	_pet_timer -= delta
	if _pet_timer <= 0.0 or (is_stunned() and _pet_timer > 1.0 and _stun > STUN_TIME - 0.1):
		_pet_timer = randf_range(5.0, 11.0)
		_pet_player.stream = sound
		_pet_player.pitch_scale = randf_range(0.92, 1.08)
		_pet_player.play()


## Horn button: the swan honks, or the pet in the bag barks or meows.
func _update_horn(delta: float) -> void:
	_horn_cooldown -= delta
	var pressed := brain is PlayerInput and controls_enabled and Input.is_action_just_pressed("horn")
	if not pressed or _horn_cooldown > 0.0:
		return
	_horn_cooldown = 0.35
	if look.is_wearing("dog_bag"):
		_horn_player.stream = Sfx.bark()
	elif look.is_wearing("cat_bag"):
		_horn_player.stream = Sfx.meow()
	else:
		_horn_player.stream = Sfx.honk()
		model.honk()
	_horn_player.pitch_scale = randf_range(0.96, 1.04)
	_horn_player.play()


## The face fits the moment: dizzy, crying, surprised, determined, laughing.
func _face() -> SwanModel.Face:
	if is_stunned():
		return SwanModel.Face.DIZZY
	if _drown > 0.0 or (finish_place > 1 and finish_place == field_size):
		return SwanModel.Face.CRY
	if finish_place == 1:
		return SwanModel.Face.LAUGH
	if not motor.on_ground:
		return SwanModel.Face.SURPRISED
	if motor.boosting or model.effort > 0.5:
		return SwanModel.Face.ANGRY
	return SwanModel.Face.HAPPY


## Ran over a speed pad: a push forward and a whoosh.
func hit_pad() -> void:
	motor.pad_time = SwanMotor.PAD_TIME
	_jump_player.pitch_scale = 1.6
	_jump_player.play()


## Ran into an obstacle: stops and reappears right past it, blinking for a
## moment (like after drowning, but at once).
func teleport(at: Vector3, heading: float) -> void:
	_respawn_position = at
	_respawn_heading = heading
	_respawn()
	_blink = OBSTACLE_BLINK_TIME
	_bump_player.play()
