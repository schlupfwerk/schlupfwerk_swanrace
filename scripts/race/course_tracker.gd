class_name CourseTracker
extends RefCounted
## Where one swan is on a course. On a run (point to point) it says when the
## swan crosses the finish line; on a loop it counts laps and lap times, like
## LapTracker does on the island (the start line is at distance 0, and a
## halfway checkpoint keeps back-and-forth crossings from counting).

signal finished_course
signal lap_completed(lap_time: float)

var track: CourseTrack
var hint := -1
var distance := 0.0
var lateral := 0.0
var finished := false
# Loops only.
var lap := 1
var lap_time := 0.0
var laps_done := 0
var _passed_half := false
## True once the swan crossed the start line (it starts behind it).
var _started := false


func _init(p_track: CourseTrack) -> void:
	track = p_track


func update(position: Vector3, timing: bool, tick := 0.0) -> void:
	var info := track.locate(Vector2(position.x, position.z), hint)
	hint = info["index"]
	lateral = info["lateral"]
	var previous := distance
	distance = info["distance"]
	if not track.looped:
		if timing and not finished and distance >= track.finish_distance:
			finished = true
			finished_course.emit()
		return
	if timing:
		lap_time += tick
	var length := track.length
	if distance > length * 0.4 and distance < length * 0.6:
		_passed_half = true
	if previous < length * 0.2 and distance > length * 0.8:
		_passed_half = false
	if previous > length * 0.8 and distance < length * 0.2:
		_started = true
		if _passed_half and timing:
			laps_done += 1
			lap_completed.emit(lap_time)
			lap += 1
			lap_time = 0.0
			_passed_half = false


## Meters covered in the race (for positions): since the start line on a run;
## laps done plus the distance into this lap on a loop (negative while still
## behind the start line).
func progress() -> float:
	if not track.looped:
		return distance - track.start_distance
	if not _started:
		return distance - track.length
	return laps_done * track.length + distance


## Meters left to the finish line (runs).
func to_finish() -> float:
	return maxf(track.finish_distance - distance, 0.0)
