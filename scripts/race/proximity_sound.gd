class_name ProximitySound
extends Node3D
## Plays a sound from a few spots when the camera passes close to them: the
## cows in the Alps pastures moo, the temple bells on the Great Wall ring.
## Each spot plays once when the camera comes near, never two sounds within
## `gap` seconds of each other (so it never floods), and a spot can play again
## only after the camera has gone far away and come back.

## Where the sounds come from, in world space.
var spots := PackedVector3Array()
var stream: AudioStream
var near := 40.0
var far := 160.0
## Minimum time between two sounds (seconds).
var gap := 4.0
## Random pitch change on each play (0 = none).
var pitch_range := 0.1
var unit_size := 18.0
var max_distance := 120.0

var _played: Array[bool] = []
var _players: Array[AudioStreamPlayer3D] = []
var _quiet := 0.0


func _ready() -> void:
	for spot in spots:
		var player := AudioStreamPlayer3D.new()
		player.stream = stream
		player.bus = &"SFX"
		player.unit_size = unit_size
		player.max_distance = max_distance
		player.position = spot
		add_child(player)
		_players.append(player)
		_played.append(false)


func _process(delta: float) -> void:
	_quiet = maxf(_quiet - delta, 0.0)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for n in spots.size():
		var distance := camera.global_position.distance_to(spots[n])
		if distance > far:
			_played[n] = false
		elif distance < near and not _played[n] and _quiet <= 0.0:
			_played[n] = true
			_quiet = gap
			_players[n].pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
			_players[n].play()
