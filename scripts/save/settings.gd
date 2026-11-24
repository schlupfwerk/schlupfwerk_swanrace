extends Node
## Autoload "Settings": video and audio options of this device.
## Saved locally only and never synced: they depend on the hardware.

signal changed

enum Quality { LOW, MEDIUM, HIGH, CUSTOM }
enum WindowMode { WINDOWED, FULLSCREEN, EXCLUSIVE }
enum VSync { OFF, ON, ADAPTIVE }

const SAVE_PATH := "user://settings.cfg"
const SAVE_VERSION := 1

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160),
]
const RENDER_SCALES := [0.5, 0.67, 0.75, 0.85, 1.0]
const MSAA_LEVELS := [0, 2, 4, 8]
const FPS_LIMITS := [0, 30, 60, 90, 120, 144, 165, 240]
const FOV_VALUES := [60, 65, 70, 75, 80, 85, 90]
## Share of decorative instances (trees, shells...) drawn per detail level.
const DETAIL_RATIOS := [0.35, 0.7, 1.0]
## Shadow distance per shadow level (0 = off).
const SHADOW_DISTANCES := [0.0, 40.0, 60.0, 90.0]
const PRESETS := {
	Quality.LOW: {"render_scale": 0.75, "msaa": 0, "shadows": 0, "detail": 0},
	Quality.MEDIUM: {"render_scale": 1.0, "msaa": 2, "shadows": 1, "detail": 1},
	Quality.HIGH: {"render_scale": 1.0, "msaa": 4, "shadows": 3, "detail": 2},
}

# Video
var window_mode := WindowMode.WINDOWED
var resolution := Vector2i(1280, 720)
var monitor := 0
var quality := Quality.HIGH
var render_scale := 1.0
var msaa := 4
var shadows := 3
var detail := 2
var vsync := VSync.ON
var fps_limit := 0
var show_fps := false
var fov := 70
## -1 = automatic (Godot prefers the dedicated GPU). Applied after a restart.
var gpu_index := -1
# Audio (0-100)
var master_volume := 100
var music_volume := 80
var sfx_volume := 100
var mute_in_background := true

## GPU names learned by running with an explicit --gpu-index: index -> name.
var _known_gpus := {}
## False between starting on a chosen GPU and showing the first frame.
var _gpu_boot_ok := true
var _fps_label := Label.new()
var _fps_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_platform_defaults()
	load_settings()
	if _apply_gpu_choice():
		return
	apply_all()
	_build_fps_overlay()


func apply_all() -> void:
	apply_window()
	apply_graphics()
	apply_audio()


func is_desktop() -> bool:
	return not OS.has_feature("mobile")


## Picks a preset (or CUSTOM, which keeps the current advanced values).
func set_quality(value: Quality) -> void:
	_load_preset(value)
	apply_graphics()


func _load_preset(value: Quality) -> void:
	quality = value
	if PRESETS.has(value):
		var preset: Dictionary = PRESETS[value]
		render_scale = preset.render_scale
		msaa = preset.msaa
		shadows = preset.shadows
		detail = preset.detail


func reset_to_defaults() -> void:
	var keep_gpu := gpu_index
	for property in ["window_mode", "resolution", "monitor", "vsync", "fps_limit", "show_fps",
			"fov", "master_volume", "music_volume", "sfx_volume", "mute_in_background"]:
		set(property, get_script().get_property_default_value(property))
	_set_platform_defaults()
	set_quality(Quality.HIGH if is_desktop() else Quality.MEDIUM)
	gpu_index = keep_gpu
	apply_all()
	save_settings()


func available_resolutions() -> Array[Vector2i]:
	var screen := DisplayServer.screen_get_size(_screen())
	var list: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y:
			list.append(r)
	if not list.has(screen):
		list.append(screen)
	return list


# --- Applying ------------------------------------------------------------

func apply_window() -> void:
	if is_desktop() and DisplayServer.get_name() != "headless":
		var screen := _screen()
		match window_mode:
			WindowMode.WINDOWED:
				if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_current_screen(screen)
				var area := DisplayServer.screen_get_usable_rect(screen)
				var size := Vector2i(mini(resolution.x, area.size.x), mini(resolution.y, area.size.y))
				DisplayServer.window_set_size(size)
				DisplayServer.window_set_position(area.position + (area.size - size) / 2)
			WindowMode.FULLSCREEN:
				DisplayServer.window_set_current_screen(screen)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			WindowMode.EXCLUSIVE:
				DisplayServer.window_set_current_screen(screen)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	var modes := [DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED,
			DisplayServer.VSYNC_ADAPTIVE]
	DisplayServer.window_set_vsync_mode(modes[vsync])
	Engine.max_fps = fps_limit
	changed.emit()


func apply_graphics() -> void:
	var viewport := get_tree().root
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale
	var msaa_modes := {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X,
			8: Viewport.MSAA_8X}
	viewport.msaa_3d = msaa_modes.get(msaa, Viewport.MSAA_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(4096 if shadows >= 2 else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if shadows >= 3
			else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	for light in get_tree().get_nodes_in_group("sun"):
		configure_sun(light)
	for instance in get_tree().get_nodes_in_group("scenery_detail"):
		configure_detail(instance)
	changed.emit()


## Called by the scenery for its sun, and again when settings change.
func configure_sun(sun: DirectionalLight3D) -> void:
	sun.shadow_enabled = shadows > 0
	sun.directional_shadow_max_distance = maxf(SHADOW_DISTANCES[shadows], 1.0)


## Called by the scenery for decorative MultiMeshes, and again on changes.
func configure_detail(instance: MultiMeshInstance3D) -> void:
	var mm := instance.multimesh
	mm.visible_instance_count = int(mm.instance_count * DETAIL_RATIOS[detail])


func apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)
	changed.emit()


func _set_bus(bus_name: String, volume: int) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001) / 100.0))
	AudioServer.set_bus_mute(index, volume <= 0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mute_in_background:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		apply_audio()


# --- GPU --------------------------------------------------------------------

## Name and kind of the GPU in use, e.g. "NVIDIA GeForce RTX 5060 (dedicada)".
func current_gpu_text() -> String:
	var kinds := {
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU: "dedicada",
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU: "integrada",
		RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU: "virtual",
		RenderingDevice.DEVICE_TYPE_CPU: "processador",
	}
	var kind: String = kinds.get(RenderingServer.get_video_adapter_type(), "")
	var adapter := RenderingServer.get_video_adapter_name()
	return "%s (%s)" % [adapter, kind] if kind != "" else adapter


## Option labels for the GPU row: automatic, then one per installed GPU.
func gpu_options() -> PackedStringArray:
	var options := PackedStringArray(["Automática (dedicada)"])
	for i in _gpu_count():
		options.append(_known_gpus.get(i, "Placa %d" % (i + 1)))
	return options


## Saves the GPU choice and restarts the game on it.
func restart_on_gpu(index: int) -> void:
	gpu_index = index
	_gpu_boot_ok = true
	save_settings()
	var args := _args_without_gpu()
	if index >= 0:
		args.append_array(["--gpu-index", str(index)])
	OS.set_restart_on_exit(true, args)
	get_tree().quit()


## Returns true when the game is restarting to open on the chosen GPU.
func _apply_gpu_choice() -> bool:
	var args := OS.get_cmdline_args()
	var position := args.find("--gpu-index")
	if position >= 0 and position + 1 < args.size():
		_confirm_gpu_boot(args[position + 1].to_int())
		return false
	if gpu_index < 0 or OS.has_feature("editor"):
		return false
	if not _gpu_boot_ok:
		# The chosen GPU did not start last time: go back to automatic.
		push_warning("GPU %d failed to start, using automatic." % gpu_index)
		gpu_index = -1
		_gpu_boot_ok = true
		save_settings()
		return false
	restart_on_gpu(gpu_index)
	return true


## Started on a chosen GPU: if a frame shows, it works. Remember its name.
func _confirm_gpu_boot(index: int) -> void:
	_gpu_boot_ok = false
	save_settings()
	await get_tree().process_frame
	await get_tree().process_frame
	_known_gpus[index] = RenderingServer.get_video_adapter_name()
	_gpu_boot_ok = true
	save_settings()


func _args_without_gpu() -> PackedStringArray:
	var args := OS.get_cmdline_args()
	var clean := PackedStringArray()
	var skip := false
	for arg in args:
		if skip:
			skip = false
			continue
		if arg == "--gpu-index":
			skip = true
			continue
		clean.append(arg)
	return clean


static var _gpu_count_cache := -1


## Number of GPUs in this PC (Windows only for now; cached).
static func _gpu_count() -> int:
	if _gpu_count_cache >= 0:
		return _gpu_count_cache
	_gpu_count_cache = 0
	if OS.get_name() != "Windows":
		return 0
	var output := []
	var code := OS.execute("powershell",
			["-NoProfile", "-Command", "(Get-CimInstance Win32_VideoController).Count"], output)
	if code != 0 or output.is_empty():
		return 0
	_gpu_count_cache = clampi(str(output[0]).strip_edges().to_int(), 0, 4)
	return _gpu_count_cache


# --- FPS overlay --------------------------------------------------------------

func _build_fps_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.position = Vector2(-220, 4)
	_fps_label.custom_minimum_size.x = 210
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_font_size_override("font_size", 16)
	_fps_label.add_theme_constant_override("outline_size", 5)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.visible = show_fps
	layer.add_child(_fps_label)
	changed.connect(func() -> void: _fps_label.visible = show_fps)


func _process(delta: float) -> void:
	if not show_fps:
		return
	_fps_timer -= delta
	if _fps_timer > 0.0:
		return
	_fps_timer = 0.25
	var hz := DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())
	var hz_text := "%d Hz" % roundi(hz) if hz > 0.0 else "? Hz"
	_fps_label.text = "%d FPS  ·  %s" % [Engine.get_frames_per_second(), hz_text]


# --- Saving -----------------------------------------------------------------

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	for key in ["window_mode", "resolution", "monitor", "quality", "render_scale", "msaa",
			"shadows", "detail", "vsync", "fps_limit", "show_fps", "fov", "gpu_index"]:
		cfg.set_value("video", key, get(key))
	cfg.set_value("video", "known_gpus", _known_gpus)
	cfg.set_value("video", "gpu_boot_ok", _gpu_boot_ok)
	for key in ["master_volume", "music_volume", "sfx_volume", "mute_in_background"]:
		cfg.set_value("audio", key, get(key))
	var error := cfg.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save settings: %s" % error_string(error))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	window_mode = clampi(cfg.get_value("video", "window_mode", window_mode), 0, 2) as WindowMode
	var saved_resolution = cfg.get_value("video", "resolution", resolution)
	if saved_resolution is Vector2i and saved_resolution.x >= 640 and saved_resolution.y >= 360:
		resolution = saved_resolution
	monitor = maxi(int(cfg.get_value("video", "monitor", monitor)), 0)
	quality = clampi(cfg.get_value("video", "quality", quality), 0, 3) as Quality
	render_scale = _pick(cfg.get_value("video", "render_scale", render_scale), RENDER_SCALES, 1.0)
	msaa = _pick(cfg.get_value("video", "msaa", msaa), MSAA_LEVELS, 0)
	shadows = clampi(cfg.get_value("video", "shadows", shadows), 0, 3)
	detail = clampi(cfg.get_value("video", "detail", detail), 0, 2)
	vsync = clampi(cfg.get_value("video", "vsync", vsync), 0, 2) as VSync
	fps_limit = _pick(cfg.get_value("video", "fps_limit", fps_limit), FPS_LIMITS, 0)
	show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
	fov = _pick(cfg.get_value("video", "fov", fov), FOV_VALUES, 70)
	gpu_index = clampi(cfg.get_value("video", "gpu_index", gpu_index), -1, 3)
	var known = cfg.get_value("video", "known_gpus", {})
	if known is Dictionary:
		_known_gpus = known
	_gpu_boot_ok = bool(cfg.get_value("video", "gpu_boot_ok", true))
	master_volume = clampi(cfg.get_value("audio", "master_volume", master_volume), 0, 100)
	music_volume = clampi(cfg.get_value("audio", "music_volume", music_volume), 0, 100)
	sfx_volume = clampi(cfg.get_value("audio", "sfx_volume", sfx_volume), 0, 100)
	mute_in_background = bool(cfg.get_value("audio", "mute_in_background", mute_in_background))


func _set_platform_defaults() -> void:
	if not is_desktop():
		_load_preset(Quality.MEDIUM)


func _screen() -> int:
	return clampi(monitor, 0, DisplayServer.get_screen_count() - 1)


static func _pick(value, allowed: Array, fallback):
	return value if value in allowed else fallback
