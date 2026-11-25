@tool
extends EditorExportPlugin
## On every export: puts build_info.cfg (build number = git commit count, and
## the commit hash) inside the game, and fills the store version fields.

var _info := {}


func _get_name() -> String:
	return "BuildInfo"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String,
		_flags: int) -> void:
	_info = GameVersion.read_git()
	var cfg := ConfigFile.new()
	cfg.set_value("build", "number", _info.number)
	cfg.set_value("build", "commit", _info.commit)
	cfg.set_value("build", "date", Time.get_datetime_string_from_system(true))
	add_file(GameVersion.BUILD_INFO_PATH, cfg.encode_to_text().to_utf8_buffer(), false)
	print("Build info: %s-build%05d (%s)" % [GameVersion.base(), _info.number, _info.commit])


## Android versionCode/versionName and Windows file version follow the build.
func _get_export_options_overrides(platform: EditorExportPlatform) -> Dictionary:
	var info := GameVersion.read_git()
	var full := "%s-build%05d" % [GameVersion.base(), info.number]
	var numeric := "%s.%d" % [GameVersion.base(), info.number]
	match platform.get_os_name():
		"Android":
			return {"version/code": maxi(info.number, 1), "version/name": full}
		"Windows":
			return {"application/file_version": numeric, "application/product_version": numeric}
	return {}
