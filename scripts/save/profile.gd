extends Node
## Autoload "Profile": the local save. It is the source of truth and works
## offline (ADR 0013). Cloud sync will plug in here later.

const SAVE_PATH := "user://profile.cfg"
const SAVE_VERSION := 1

var look := SwanLook.new()


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var data = cfg.get_value("profile", "look", {})
	if data is Dictionary:
		look = SwanLook.from_dict(data)


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("profile", "look", look.to_dict())
	var error := cfg.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save profile: %s" % error_string(error))
