class_name LapTracker
extends RefCounted
## Counts one swan's laps and lap time, in simulation time (deterministic).

signal lap_completed(lap_time: float)

var track: IslandTrack
var hint := -1
var distance := 0.0
var lateral := 0.0
var lap := 1
var lap_time := 0.0

var _passed_half := false
## True once the swan crossed the start line for the first time (it starts behind it).
var _started := false
## Laps completed (finish line crossings that count).
var laps_done := 0


func _init(p_track: IslandTrack) -> void:
	track = p_track


func update(position: Vector3, tick: float, timing: bool) -> void:
	var info := track.locate(Vector2(position.x, position.z), hint)
	hint = info["index"]
	lateral = info["lateral"]
	var previous := distance
	distance = info["distance"]
	if timing:
		lap_time += tick
	var length := IslandTrack.LAP_LENGTH
	# Halfway checkpoint, so crossing the line back and forth never counts.
	if distance > length * 0.4 and distance < length * 0.6:
		_passed_half = true
	if previous < length * 0.2 and distance > length * 0.8:
		_passed_half = false
	if previous > length * 0.8 and distance < length * 0.2:
		_started = true
	if previous > length * 0.8 and distance < length * 0.2 and _passed_half and timing:
		laps_done += 1
		lap_completed.emit(lap_time)
		lap += 1
		lap_time = 0.0
		_passed_half = false


## Meters covered in the race (for positions): laps done plus the distance
## into the current lap; negative while still behind the start line.
func progress() -> float:
	if not _started:
		return distance - IslandTrack.LAP_LENGTH
	return laps_done * IslandTrack.LAP_LENGTH + distance
