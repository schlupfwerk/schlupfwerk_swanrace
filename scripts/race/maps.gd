class_name Maps
extends RefCounted
## The maps the player can pick in the Race tab (Settings.map). Circuits run
## in race.tscn (laps); point-to-point courses in course_race.tscn (ADR 0022).

const CIRCUIT_SCENE := "res://scenes/race.tscn"
const COURSE_SCENE := "res://scenes/course_race.tscn"

## id, name (translation key) and whether it has laps.
const LIST := [
	{"id": "desert_island", "name": "MAP_DESERT_ISLAND", "laps": true},
	{"id": "swiss_alps", "name": "MAP_SWISS_ALPS", "laps": false},
]


static func index_of(id: String) -> int:
	for n in LIST.size():
		if LIST[n].id == id:
			return n
	return 0


static func current() -> Dictionary:
	return LIST[index_of(Settings.map)]


static func has_laps(id: String) -> bool:
	return LIST[index_of(id)].laps


static func scene(id: String) -> String:
	return CIRCUIT_SCENE if has_laps(id) else COURSE_SCENE


## A new course for a point-to-point map (null for circuits).
static func make_course(id: String) -> CourseTrack:
	match id:
		"swiss_alps":
			return AlpsCourse.new()
	return null
