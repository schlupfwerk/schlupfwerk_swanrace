class_name Sfx
extends RefCounted
## Simple sound effects synthesized in code, so the prototype needs no audio
## files. Final sounds can replace these later (credit them in assets/CREDITS.md).

const RATE := 22050

static var _cache := {}


## Soft step on sand: a short, muffled noise burst with a low thump.
static func footstep() -> AudioStreamWAV:
	if not _cache.has("footstep"):
		_cache["footstep"] = _render(0.11, func(t: float, state: Dictionary) -> float:
			var envelope := minf(t / 0.006, 1.0) * exp(-t * 38.0)
			state.low = lerpf(state.get("low", 0.0), randf_range(-1.0, 1.0), 0.18)
			var thump := sin(TAU * 85.0 * t) * exp(-t * 45.0)
			return (state.low * 1.6 + thump * 0.5) * envelope)
	return _cache["footstep"]


## Jump: a quick wing whoosh rising in pitch plus a light "boing".
static func jump() -> AudioStreamWAV:
	if not _cache.has("jump"):
		_cache["jump"] = _render(0.3, func(t: float, state: Dictionary) -> float:
			var envelope := minf(t / 0.02, 1.0) * exp(-t * 9.0)
			var cutoff := lerpf(0.05, 0.35, t / 0.3)
			state.air = lerpf(state.get("air", 0.0), randf_range(-1.0, 1.0), cutoff)
			state.phase = state.get("phase", 0.0) + TAU * lerpf(220.0, 520.0, t / 0.3) / RATE
			return (state.air * 0.9 + sin(state.phase) * 0.35) * envelope)
	return _cache["jump"]


## Landing: a deeper thud with a puff of sand.
static func land() -> AudioStreamWAV:
	if not _cache.has("land"):
		_cache["land"] = _render(0.22, func(t: float, state: Dictionary) -> float:
			var envelope := minf(t / 0.004, 1.0) * exp(-t * 18.0)
			state.phase = state.get("phase", 0.0) + TAU * lerpf(75.0, 42.0, t / 0.22) / RATE
			state.low = lerpf(state.get("low", 0.0), randf_range(-1.0, 1.0), 0.12)
			return (sin(state.phase) * 0.8 + state.low * 1.4) * envelope)
	return _cache["land"]


## Calls `sample(t, state)` for every sample and packs 16-bit mono PCM.
static func _render(duration: float, sample: Callable) -> AudioStreamWAV:
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var state := {}
	for i in count:
		var value := clampf(sample.call(float(i) / RATE, state), -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
