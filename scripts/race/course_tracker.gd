class_name CourseTracker
extends RefCounted
## Where one swan is on a point-to-point course and when it crosses the
## finish line (no laps). The course counterpart of LapTracker.

signal finished_course

var track: CourseTrack
var hint := -1
var distance := 0.0
var lateral := 0.0
var finished := false


func _init(p_track: CourseTrack) -> void:
	track = p_track


func update(position: Vector3, timing: bool) -> void:
	var info := track.locate(Vector2(position.x, position.z), hint)
	hint = info["index"]
	distance = info["distance"]
	lateral = info["lateral"]
	if timing and not finished and distance >= track.finish_distance:
		finished = true
		finished_course.emit()


## Meters covered since the start line (negative while still behind it).
func progress() -> float:
	return distance - track.start_distance


## Meters left to the finish line.
func to_finish() -> float:
	return maxf(track.finish_distance - distance, 0.0)
