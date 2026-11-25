extends Node
## Autoload "Profile": the local save. It is the source of truth and works
## offline (ADR 0013). Cloud sync will plug in here later.

const SAVE_PATH := "user://profile.cfg"
const SAVE_VERSION := 2
## How many characters the player can keep.
const MAX_CHARACTERS := 10

## The player's characters (1 to MAX_CHARACTERS) and the one that races.
var characters: Array[SwanLook] = [SwanLook.new()]
var selected := 0
## The selected character.
var look: SwanLook:
	get:
		return characters[clampi(selected, 0, characters.size() - 1)]
## Best lap per track id, in seconds.
var records := {}


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var list: Array[SwanLook] = []
	var saved = cfg.get_value("profile", "characters", [])
	if saved is Array:
		for data in saved:
			if data is Dictionary and list.size() < MAX_CHARACTERS:
				list.append(SwanLook.from_dict(data))
	# Version 1 saves had a single look.
	var single = cfg.get_value("profile", "look", {})
	if list.is_empty() and single is Dictionary and not single.is_empty():
		list.append(SwanLook.from_dict(single))
	if not list.is_empty():
		characters = list
	selected = clampi(int(cfg.get_value("profile", "selected", 0)), 0, characters.size() - 1)
	var saved_records = cfg.get_value("profile", "records", {})
	if saved_records is Dictionary:
		for track_id in saved_records:
			var time = saved_records[track_id]
			if (time is float or time is int) and time > 0.0:
				records[str(track_id)] = float(time)


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	var list := []
	for character in characters:
		list.append(character.to_dict())
	cfg.set_value("profile", "characters", list)
	cfg.set_value("profile", "selected", selected)
	cfg.set_value("profile", "records", records)
	var error := cfg.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save profile: %s" % error_string(error))


## A new character (a fresh random look), selected. Null when the list is full.
func add_character() -> SwanLook:
	if characters.size() >= MAX_CHARACTERS:
		return null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var fresh := BotLooks.make(rng, look, [])
	characters.append(fresh)
	selected = characters.size() - 1
	save_profile()
	return fresh


## Deletes the selected character (there is always at least one).
func delete_selected() -> void:
	if characters.size() <= 1:
		return
	characters.remove_at(selected)
	selected = clampi(selected, 0, characters.size() - 1)
	save_profile()


## Best lap on a track, or 0.0 when there is none yet.
func best_lap(track_id: String) -> float:
	return records.get(track_id, 0.0)


## Records the lap if it is the best so far. Returns true for a new record.
func submit_lap(track_id: String, lap_time: float) -> bool:
	var best := best_lap(track_id)
	if best > 0.0 and lap_time >= best:
		return false
	records[track_id] = lap_time
	save_profile()
	return true
