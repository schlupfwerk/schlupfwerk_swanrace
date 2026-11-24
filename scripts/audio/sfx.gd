class_name Sfx
extends RefCounted
## Simple sound effects synthesized in code, so the prototype needs no audio
## files. Final sounds can replace these later (credit them in assets/CREDITS.md).

const RATE := 22050

static var _cache := {}


## Steps on sand: a crunch of tiny grains over a soft thud. Four takes,
## picked at random with small pitch and volume changes, so no two match.
static func footsteps() -> AudioStreamRandomizer:
	if not _cache.has("footsteps"):
		var randomizer := AudioStreamRandomizer.new()
		randomizer.random_pitch = 1.12
		randomizer.random_volume_offset_db = 2.0
		for take in 4:
			randomizer.add_stream(-1, _sand_step(take))
		_cache["footsteps"] = randomizer
	return _cache["footsteps"]


static func _sand_step(take: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + take
	# Grain times: most of them early, as the foot presses into the sand.
	var grains := []
	for n in 34:
		grains.append([pow(rng.randf(), 1.8) * 0.09, rng.randf_range(0.3, 1.0)])
	var thud_pitch := rng.randf_range(60.0, 80.0)
	return _render(0.13, func(t: float, state: Dictionary) -> float:
		var grain := 0.0
		for g: Array in grains:
			var age: float = t - g[0]
			if age >= 0.0 and age < 0.004:
				grain += randf_range(-1.0, 1.0) * g[1] * (1.0 - age / 0.004)
		# Band-limit the grains: remove the hiss and the rumble.
		state.lp = lerpf(state.get("lp", 0.0), grain, 0.45)
		state.slow = lerpf(state.get("slow", 0.0), state.lp, 0.04)
		var crunch: float = state.lp - state.slow
		var thud := sin(TAU * thud_pitch * t) * exp(-t * 40.0) * minf(t / 0.004, 1.0)
		return crunch * 1.3 + thud * 0.35)


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


## Small dog: two quick barks ("au au").
static func bark() -> AudioStreamWAV:
	if not _cache.has("bark"):
		_cache["bark"] = _render(0.42, func(t: float, state: Dictionary) -> float:
			var local := fmod(t, 0.22)
			if local > 0.14:
				return 0.0
			var pitch := lerpf(620.0, 380.0, local / 0.14)
			state.phase = state.get("phase", 0.0) + TAU * pitch / RATE
			var tone := sin(state.phase) + 0.6 * sin(state.phase * 2.0) + 0.3 * sin(state.phase * 3.0)
			state.rasp = lerpf(state.get("rasp", 0.0), randf_range(-1.0, 1.0), 0.3)
			var envelope := minf(local / 0.01, 1.0) * exp(-local * 22.0)
			return (tone * 0.45 + state.rasp * 0.5) * envelope)
	return _cache["bark"]


## Cat: a rising and falling "mee-ow" with a little vibrato.
static func meow() -> AudioStreamWAV:
	if not _cache.has("meow"):
		_cache["meow"] = _render(0.7, func(t: float, state: Dictionary) -> float:
			var u := t / 0.7
			var pitch := 520.0 + 380.0 * sin(u * PI) * (1.0 - 0.4 * u)
			pitch *= 1.0 + 0.02 * sin(TAU * 7.0 * t)
			state.phase = state.get("phase", 0.0) + TAU * pitch / RATE
			# Brighter in the middle ("ee"), rounder at the end ("ow").
			var bright := sin(u * PI)
			var tone := sin(state.phase) + (0.5 + 0.4 * bright) * sin(state.phase * 2.0) \
					+ 0.3 * bright * sin(state.phase * 3.0)
			var envelope := minf(t / 0.04, 1.0) * clampf((0.7 - t) / 0.15, 0.0, 1.0)
			return tone * 0.4 * envelope)
	return _cache["meow"]
