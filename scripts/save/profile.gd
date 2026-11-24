extends Node
## Autoload "Profile": the local save. It is the source of truth and works
## offline (ADR 0013). Cloud sync will plug in here later.

const SAVE_PATH := "user://profile.cfg"
const SAVE_VERSION := 1

var look := SwanLook.new()
## Best lap per track id, in seconds.
var records := {}


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var data = cfg.get_value("profile", "look", {})
	if data is Dictionary:
		look = SwanLook.from_dict(data)
	var saved_records = cfg.get_value("profile", "records", {})
	if saved_records is Dictionary:
		for track_id in saved_records:
			var time = saved_records[track_id]
			if (time is float or time is int) and time > 0.0:
				records[str(track_id)] = float(time)


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("profile", "look", look.to_dict())
	cfg.set_value("profile", "records", records)
	var error := cfg.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save profile: %s" % error_string(error))


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
