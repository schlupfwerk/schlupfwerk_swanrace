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

var _accumulator := 0.0
var _previous_position := Vector3.ZERO
var _previous_heading := 0.0
var _name_label := Label3D.new()


func _ready() -> void:
	add_child(model)
	_name_label.position = Vector3(0, 3.0, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 48
	_name_label.outline_size = 12
	_name_label.pixel_size = 0.006
	add_child(_name_label)
	set_look(look)
	_previous_position = motor.position
	_previous_heading = motor.heading


func set_look(new_look: SwanLook) -> void:
	look = new_look
	model.apply_look(look)
	_name_label.text = look.nickname


func _process(delta: float) -> void:
	_accumulator += minf(delta, 0.25)
	while _accumulator >= TICK:
		_previous_position = motor.position
		_previous_heading = motor.heading
		if brain:
			brain.update_intent(intent, TICK)
		else:
			intent.reset()
		motor.step(intent, TICK)
		_accumulator -= TICK
	var alpha := _accumulator / TICK
	position = _previous_position.lerp(motor.position, alpha)
	rotation.y = lerp_angle(_previous_heading, motor.heading, alpha)
	model.animate(delta, motor.speed_ratio(), intent.steer, intent.accel, motor.braking,
			motor.on_ground)
