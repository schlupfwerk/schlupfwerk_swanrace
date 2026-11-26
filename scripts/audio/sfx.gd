class_name Sfx
extends RefCounted
## Simple sound effects synthesized in code, so the prototype needs no audio
## files. Final sounds can replace these later (credit them in assets/CREDITS.md).

const RATE := 22050
## Frames copied from the start of a looping sound to just after its loop end.
## The resampler reads a few frames ahead of the play position; without this
## margin it reads past the end of the buffer at the loop point, which crashed
## the game on Android (seen in the emulator about a minute in).
const LOOP_PAD := 64

static var _cache := {}


## 16-bit mono PCM of a looping sound, with LOOP_PAD frames of its start added
## after the end (set loop_end to the original frame count).
static func pad_loop(data: PackedByteArray) -> PackedByteArray:
	var out := data.duplicate()
	out.append_array(data.slice(0, LOOP_PAD * 2))
	return out


## A cached loop saved by `save_to_wav`, loaded as plain 16-bit PCM (no
## compression), looping over everything but the LOOP_PAD margin.
static func load_loop(path: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.load_from_file(path, {"compress/mode": 0})
	if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.stereo:
		return null
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2 - LOOP_PAD
	return stream


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


## A crowd going wild: a roar of many voices ("waaah") that swells and fades,
## with hand claps and whistles scattered through it.
static func crowd_cheer() -> AudioStreamWAV:
	if not _cache.has("crowd_cheer"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 80
		var claps := []
		for n in 90:
			claps.append(rng.randf_range(0.1, 3.2))
		claps.sort()
		var whistles := [0.5, 1.2, 1.9, 2.6]
		_cache["crowd_cheer"] = _render(3.6, func(t: float, state: Dictionary) -> float:
			var swell := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(2.4, 3.6, t))
			# Voices: noise shaped around the "ah" vowel (two bands).
			var noise := randf_range(-1.0, 1.0)
			state.a = lerpf(state.get("a", 0.0), noise, 0.12)
			state.b = lerpf(state.get("b", 0.0), noise, 0.3)
			var voices: float = state.a * 1.6 + (state.b - state.a) * 0.9
			# Claps, in time order: only the few around now can sound.
			var clap := 0.0
			var k: int = state.get("k", 0)
			while k < claps.size() and claps[k] + 0.03 < t:
				k += 1
			state.k = k
			for m in range(k, mini(k + 4, claps.size())):
				var u: float = t - claps[m]
				if u >= 0.0 and u < 0.03:
					clap += randf_range(-1.0, 1.0) * (1.0 - u / 0.03)
			var whistle := 0.0
			for at: float in whistles:
				var u := t - at
				if u >= 0.0 and u < 0.45:
					var pitch := 1800.0 + 900.0 * sin(u / 0.45 * PI)
					whistle += sin(TAU * pitch * u) * sin(u / 0.45 * PI) * 0.25
			return (voices * 0.55 + clap * 0.35 + whistle) * swell)
	return _cache["crowd_cheer"]


## The murmur of a crowd waiting, looped (soft, always on at the Colosseum).
static func crowd_murmur() -> AudioStreamWAV:
	if not _cache.has("crowd_murmur"):
		var stream := _render(6.0, func(t: float, state: Dictionary) -> float:
			var noise := randf_range(-1.0, 1.0)
			state.a = lerpf(state.get("a", 0.0), noise, 0.08)
			var wave := 0.8 + 0.2 * sin(TAU * t / 3.0) * sin(TAU * t / 2.0)
			return state.a * 1.2 * wave)
		stream.data = pad_loop(stream.data)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(6.0 * RATE)
		_cache["crowd_murmur"] = stream
	return _cache["crowd_murmur"]


## Temple bell: a soft strike and a long, shimmering ring of inharmonic
## partials (a bronze bell), fading over a few seconds.
static func temple_bell() -> AudioStreamWAV:
	if not _cache.has("temple_bell"):
		_cache["temple_bell"] = _render(4.0, func(t: float, _state: Dictionary) -> float:
			var base := 220.0
			var ring := 0.0
			for partial: Array in [[0.5, 1.0, 0.8], [1.0, 0.9, 1.0], [1.19, 0.6, 1.6], [1.56, 0.5, 2.2],
					[2.0, 0.4, 2.6], [2.74, 0.3, 3.4], [3.6, 0.2, 4.5]]:
				# Each partial beats slowly against a twin (the shimmer).
				var f: float = base * partial[0]
				ring += partial[1] * (sin(TAU * f * t) + 0.5 * sin(TAU * (f + 1.3) * t)) * exp(-t * partial[2] * 0.6)
			var strike := minf(t / 0.004, 1.0)
			return ring * 0.16 * strike)
	return _cache["temple_bell"]


## Cow: a long, low "mmmooo" that opens up and sinks at the end.
static func moo() -> AudioStreamWAV:
	if not _cache.has("moo"):
		_cache["moo"] = _render(1.6, func(t: float, state: Dictionary) -> float:
			var u := t / 1.6
			var pitch := lerpf(118.0, 96.0, u * u) * (1.0 + 0.06 * sin(u * PI)) * (1.0 + 0.01 * sin(TAU * 5.0 * t))
			state.phase = state.get("phase", 0.0) + TAU * pitch / RATE
			var p: float = state.phase
			# Closed mouth ("mm") at first, then open ("ooo").
			var open := smoothstep(0.05, 0.35, u)
			var tone := sin(p) + (0.3 + 0.5 * open) * sin(2.0 * p) + 0.45 * open * sin(3.0 * p) \
					+ 0.3 * open * sin(4.0 * p) + 0.15 * open * sin(5.0 * p)
			state.breath = lerpf(state.get("breath", 0.0), randf_range(-1.0, 1.0), 0.15)
			var envelope := minf(t / 0.12, 1.0) * clampf((1.6 - t) / 0.4, 0.0, 1.0)
			return (tone * 0.3 + state.breath * 0.05) * envelope)
	return _cache["moo"]


## Start light beep: a short "tu" (ready) or the long, higher "tuuuu" (go).
static func start_beep(go: bool) -> AudioStreamWAV:
	var key := "beep_go" if go else "beep"
	if not _cache.has(key):
		var length := 0.9 if go else 0.2
		var pitch := 1046.5 if go else 523.25
		_cache[key] = _render(length, func(t: float, state: Dictionary) -> float:
			state.phase = state.get("phase", 0.0) + TAU * pitch / RATE
			# Soft square-ish tone, like a race start light.
			var tone := sin(state.phase) + 0.3 * sin(state.phase * 3.0) + 0.15 * sin(state.phase * 5.0)
			var envelope := minf(t / 0.01, 1.0) * clampf((length - t) / 0.05, 0.0, 1.0)
			return tone * 0.4 * envelope)
	return _cache[key]


## Losing jingle: "wah... wah... wah-waaah", sliding down.
static func lose() -> AudioStreamWAV:
	if not _cache.has("lose"):
		var notes := [[0.0, 0.32, 392.0], [0.36, 0.32, 370.0], [0.72, 0.32, 349.2], [1.08, 0.9, 329.6]]
		_cache["lose"] = _render(2.0, func(t: float, state: Dictionary) -> float:
			var out := 0.0
			for note: Array in notes:
				var local: float = t - note[0]
				if local < 0.0 or local > note[1]:
					continue
				var last: bool = note == notes[notes.size() - 1]
				var pitch: float = note[2] * (1.0 + (0.025 * sin(TAU * 6.0 * local) if last else 0.0))
				pitch *= 1.0 - (0.08 * local / note[1] if last else 0.0)
				# "Wah": a muted brass tone that opens and closes.
				var wah := 0.5 + 0.5 * sin(PI * local / note[1])
				var phase := TAU * pitch * local
				var tone := sin(phase) + wah * (0.6 * sin(phase * 2.0) + 0.35 * sin(phase * 3.0))
				var envelope := minf(local / 0.03, 1.0) * clampf((note[1] - local) / 0.08, 0.0, 1.0)
				out += tone * 0.35 * envelope
			return out)
	return _cache["lose"]


## A bubble popping: a tiny rising "blip".
static func pop() -> AudioStreamWAV:
	if not _cache.has("pop"):
		_cache["pop"] = _render(0.08, func(t: float, state: Dictionary) -> float:
			state.phase = state.get("phase", 0.0) + TAU * lerpf(500.0, 1600.0, t / 0.08) / RATE
			return sin(state.phase) * exp(-t * 45.0) * 0.6)
	return _cache["pop"]


## Referee whistle at the finish line: two seconds of a trilling pea whistle.
static func whistle() -> AudioStreamWAV:
	if not _cache.has("whistle"):
		_cache["whistle"] = _render(2.0, func(t: float, state: Dictionary) -> float:
			# The pea makes the pitch and the volume flutter quickly.
			var trill := sin(TAU * 32.0 * t)
			state.phase = state.get("phase", 0.0) + TAU * (2850.0 + 90.0 * trill) / RATE
			var breath := randf_range(-1.0, 1.0) * 0.08
			var tone := sin(state.phase) + 0.25 * sin(state.phase * 2.0)
			var envelope := minf(t / 0.03, 1.0) * clampf((2.0 - t) / 0.15, 0.0, 1.0)
			return (tone * (0.75 + 0.25 * trill) + breath) * 0.32 * envelope)
	return _cache["whistle"]


## Swan horn: a cartoon nasal "honk" (a bit trumpet, a bit duck).
static func honk() -> AudioStreamWAV:
	if not _cache.has("honk"):
		_cache["honk"] = _render(0.42, func(t: float, state: Dictionary) -> float:
			# Two quick honks, the second a little lower.
			var second := t > 0.2
			var local := t - (0.22 if second else 0.0)
			if local < 0.0 or local > 0.2:
				return 0.0
			var pitch := (360.0 if second else 410.0) * (1.0 + 0.12 * exp(-local * 30.0))
			state.phase = state.get("phase", 0.0) + TAU * pitch / RATE
			var p: float = state.phase
			# Nasal: strong odd and even partials, a buzzy reed.
			var tone := sin(p) + 0.8 * sin(2.0 * p) + 0.6 * sin(3.0 * p) + 0.45 * sin(4.0 * p) \
					+ 0.3 * sin(5.0 * p)
			var envelope := minf(local / 0.012, 1.0) * clampf((0.2 - local) / 0.04, 0.0, 1.0)
			return tone * 0.22 * envelope)
	return _cache["honk"]


## A long, falling scream: the honk's reedy voice sliding down in pitch,
## wobbling, fading away as the swan drops into space.
static func scream() -> AudioStreamWAV:
	if not _cache.has("scream"):
		_cache["scream"] = _render(2.4, func(t: float, state: Dictionary) -> float:
			var pitch := lerpf(780.0, 230.0, pow(t / 2.4, 0.7)) * (1.0 + 0.04 * sin(t * 38.0))
			state.phase = state.get("phase", 0.0) + TAU * pitch / RATE
			var p: float = state.phase
			var tone := sin(p) + 0.7 * sin(2.0 * p) + 0.45 * sin(3.0 * p) + 0.25 * sin(4.0 * p)
			var envelope := minf(t / 0.03, 1.0) * clampf((2.4 - t) / 1.2, 0.0, 1.0)
			return tone * 0.2 * envelope)
	return _cache["scream"]


## Gentle waves on the beach: a slow swell of soft noise, looped.
static func waves() -> AudioStreamWAV:
	if not _cache.has("waves"):
		var stream := _render(8.0, func(t: float, state: Dictionary) -> float:
			# Two overlapping swells, so the loop never sounds like one wave.
			var swell := 0.55 + 0.45 * sin(TAU * t / 8.0) * sin(TAU * t / 4.0 + 1.0)
			state.low = lerpf(state.get("low", 0.0), randf_range(-1.0, 1.0), 0.06)
			state.lower = lerpf(state.get("lower", 0.0), state.low, 0.2)
			return state.lower * 2.2 * swell)
		stream.data = pad_loop(stream.data)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(8.0 * RATE)
		_cache["waves"] = stream
	return _cache["waves"]
