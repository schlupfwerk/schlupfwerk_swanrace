class_name GameVersion
extends RefCounted
## Game version: the base version from project.godot plus an automatic build
## number, e.g. "0.0.1-build00142". The build number is the count of git
## commits: written into build_info.cfg by the export plugin
## (addons/build_info), or read from git when running from the editor.

const STAGE := "Alpha"
const BUILD_INFO_PATH := "res://build_info.cfg"

static var _build := -1
static var _commit := ""


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


## "Alpha 0.0.1-build00142", for the screen.
static func label() -> String:
	return "%s %s" % [STAGE, full()]


static func _load() -> void:
	if _build >= 0:
		return
	_build = 0
	var cfg := ConfigFile.new()
	if cfg.load(BUILD_INFO_PATH) == OK:
		_build = int(cfg.get_value("build", "number", 0))
		_commit = str(cfg.get_value("build", "commit", ""))
		return
	if OS.has_feature("editor"):
		var info := read_git()
		_build = info.number
		_commit = info.commit


## Asks git for the commit count and the short hash of HEAD.
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
	return {"number": number, "commit": commit_hash}
