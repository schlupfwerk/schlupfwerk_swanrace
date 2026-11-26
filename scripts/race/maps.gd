class_name Maps
extends RefCounted
## The maps the player can pick in the Race tab (Settings.map). The island
## runs in race.tscn; the newer maps are courses (CourseTrack) and run in
## course_race.tscn (ADR 0022): runs from a start to a finish, or loops with
## laps (ADR 0024). The laps setting only applies to maps with laps.

const CIRCUIT_SCENE := "res://scenes/race.tscn"
const COURSE_SCENE := "res://scenes/course_race.tscn"

## id, name (translation key), whether it has laps and whether it is a course.
const LIST := [
	{"id": "desert_island", "name": "MAP_DESERT_ISLAND", "laps": true, "course": false},
	{"id": "swiss_alps", "name": "MAP_SWISS_ALPS", "laps": false, "course": true},
	{"id": "rio_beach", "name": "MAP_RIO_BEACH", "laps": false, "course": true},
	{"id": "sidereal_circuit", "name": "MAP_SIDEREAL", "laps": true, "course": true},
	{"id": "sao_paulo", "name": "MAP_SAO_PAULO", "laps": true, "course": true},
	{"id": "german_forest", "name": "MAP_GERMAN_FOREST", "laps": true, "course": true},
	{"id": "tokyo", "name": "MAP_TOKYO", "laps": true, "course": true},
	{"id": "great_wall", "name": "MAP_GREAT_WALL", "laps": false, "course": true},
	{"id": "andes", "name": "MAP_ANDES", "laps": false, "course": true},
	{"id": "egypt", "name": "MAP_EGYPT", "laps": true, "course": true},
	{"id": "colosseum", "name": "MAP_COLOSSEUM", "laps": true, "course": true},
	{"id": "paris", "name": "MAP_PARIS", "laps": true, "course": true},
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
	return COURSE_SCENE if LIST[index_of(id)].course else CIRCUIT_SCENE


## A new course for a point-to-point map (null for circuits).
static func make_course(id: String) -> CourseTrack:
	match id:
		"swiss_alps":
			return AlpsCourse.new()
		"rio_beach":
			return RioCourse.new()
		"sidereal_circuit":
			return SiderealCircuit.new()
		"sao_paulo":
			return SaoPauloCircuit.new()
		"german_forest":
			return GermanyCircuit.new()
		"tokyo":
			return TokyoCircuit.new()
		"great_wall":
			return GreatWallCourse.new()
		"andes":
			return AndesCourse.new()
		"egypt":
			return EgyptCircuit.new()
		"colosseum":
			return ColosseumCircuit.new()
		"paris":
			return ParisCircuit.new()
	return null
