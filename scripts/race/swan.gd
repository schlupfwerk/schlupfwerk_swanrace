class_name Swan
extends Node3D
## A racing swan: a brain decides, SwanMotor moves, SwanModel shows.
## The simulation runs at a fixed tick (deterministic); rendering
## interpolates between ticks so it stays smooth at any frame rate.

const TICK := 1.0 / 60.0

var brain: SwanBrain
var look := SwanLook.new()
var motor := SwanMotor.new()
var intent := SwanIntent.new()
var model := SwanModel.new()
## When false the swan ignores its brain (countdown, results).
var controls_enabled := true
## Called after every simulation tick with this swan (terrain, laps, timing).
var on_tick: Callable

var _accumulator := 0.0
var _previous_position := Vector3.ZERO
var _previous_heading := 0.0
var _name_label := Label3D.new()
var _step_player := _make_player(-8.0)
var _jump_player := _make_player(-6.0)
var _land_player := _make_player(-4.0)


func _ready() -> void:
	add_child(model)
	_name_label.position = Vector3(0, 3.0, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 48
	_name_label.outline_size = 12
	_name_label.pixel_size = 0.006
	add_child(_name_label)
	_step_player.stream = Sfx.footstep()
	_step_player.max_polyphony = 4
	_jump_player.stream = Sfx.jump()
	_land_player.stream = Sfx.land()
	for player in [_step_player, _jump_player, _land_player]:
		add_child(player)
	model.stepped.connect(_on_stepped)
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
		if brain and controls_enabled:
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
	rotation.y = lerp_angle(_previous_heading, motor.heading, alpha)
	if jumped:
		model.take_off()
		_jump_player.pitch_scale = randf_range(0.95, 1.05)
		_jump_player.play()
	if landed:
		var strength := clampf(fall_speed / SwanMotor.JUMP_VELOCITY, 0.0, 1.0)
		model.land(strength)
		_land_player.volume_db = linear_to_db(lerpf(0.5, 1.0, strength)) - 4.0
		_land_player.play()
	model.animate(delta, motor.speed_ratio(), intent.steer, intent.accel, motor.braking,
			motor.on_ground)


func _on_stepped(strength: float) -> void:
	_step_player.pitch_scale = randf_range(0.85, 1.15)
	_step_player.volume_db = linear_to_db(lerpf(0.4, 1.0, strength)) - 8.0
	_step_player.play()


static func _make_player(volume_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = &"SFX"
	player.volume_db = volume_db
	player.unit_size = 6.0
	player.position = Vector3(0, 0.3, 0)
	return player
