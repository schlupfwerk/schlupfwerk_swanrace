class_name GameVersion
extends RefCounted
## Game version: the base version from project.godot plus an automatic build
## number, e.g. "0.0.1-build00142". The build number is the count of git
## commits: written into build_info.cfg by the export plugin
## (addons/build_info), or read from git when running from the editor.

## Shown before the version on screen ("v1.0.0-build00142"). It was "Alpha "
## up to 0.0.9.
const PREFIX := "v"
const BUILD_INFO_PATH := "res://build_info.cfg"

static var _build := -1
static var _commit := ""
static var _date := ""


## "0.0.1"
static func base() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## Automatic build number (0 when unknown).
static func build() -> int:
	_load()
	return _build


## Short git commit hash ("" when unknown).
static func commit() -> String:
	_load()
	return _commit


## "0.0.1-build00142"
static func full() -> String:
	return "%s-build%05d" % [base(), build()]


## "v1.0.0-build00142", for the screen.
static func label() -> String:
	return PREFIX + full()


## Day of the build, "2026-11-26" ("" when unknown). From build_info.cfg in an
## export; in the editor, the day of the last commit.
static func date() -> String:
	_load()
	return _date


## The build date for the player's language: "26/11/2026" in Portuguese,
## "2026-11-26" otherwise ("" when unknown).
static func local_date() -> String:
	var day := date()
	if day.length() < 10:
		return ""
	if TranslationServer.get_locale().begins_with("pt"):
		return "%s/%s/%s" % [day.substr(8, 2), day.substr(5, 2), day.substr(0, 4)]
	return day


## "v1.0.0-build00142 · 26/11/2026": the version and build date, for the
## footer of the home screen.
static func footer() -> String:
	var day := local_date()
	return label() if day.is_empty() else "%s · %s" % [label(), day]


static func _load() -> void:
	if _build >= 0:
		return
	_build = 0
	var cfg := ConfigFile.new()
	if cfg.load(BUILD_INFO_PATH) == OK:
		_build = int(cfg.get_value("build", "number", 0))
		_commit = str(cfg.get_value("build", "commit", ""))
		_date = str(cfg.get_value("build", "date", "")).left(10)
		return
	if OS.has_feature("editor"):
		var info := read_git()
		_build = info.number
		_commit = info.commit
		_date = info.date


## Asks git for the commit count, the short hash and the day of HEAD.
static func read_git() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://")
	var output := []
	var number := 0
	if OS.execute("git", ["-C", root, "rev-list", "--count", "HEAD"], output) == 0 and output.size() > 0:
		number = str(output[0]).strip_edges().to_int()
	output.clear()
	var commit_hash := ""
	if OS.execute("git", ["-C", root, "rev-parse", "--short", "HEAD"], output) == 0 and output.size() > 0:
		commit_hash = str(output[0]).strip_edges()
	output.clear()
	var day := ""
	if OS.execute("git", ["-C", root, "log", "-1", "--format=%cs"], output) == 0 and output.size() > 0:
		day = str(output[0]).strip_edges()
	return {"number": number, "commit": commit_hash, "date": day}
