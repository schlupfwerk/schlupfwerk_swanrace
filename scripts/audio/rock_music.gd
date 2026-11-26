class_name RockMusic
extends RefCounted
## Music for São Paulo, composed and synthesized in code (no audio files, no
## third-party rights): an original, upbeat loop in the style of Brazilian
## pop rock. Drums (kick, snare on 2 and 4, eighth-note hi-hats, a fill every
## 8 bars), a distorted rhythm guitar chugging power chords in eighths, a
## bass following the roots and a singing lead guitar on top. Major key, fast
## and happy (all the game's music is happy: CLAUDE.md).
## Rendered once in a background thread and cached in user://.

const RATE := 22050
const BPM := 148.0
const CACHE_PATH := "user://music_sao_paulo_v1.wav"

## One chord per bar; 16 bars (I-V-vi-IV in E, then a lift to the IV).
const PROGRESSION := ["E", "B", "C#m", "A", "E", "B", "A", "B",
		"E", "B", "C#m", "A", "A", "B", "E", "B"]
const ROOTS := {"E": 40, "B": 35, "C#m": 37, "A": 33}
## Lead guitar: [bar, eighth, MIDI note, length in eighths].
const MELODY := [
	[0, 0, 71, 2], [0, 2, 68, 2], [0, 4, 71, 2], [0, 6, 73, 2], [1, 0, 75, 4], [1, 4, 73, 2], [1, 6, 71, 2],
	[2, 0, 73, 3], [2, 3, 71, 1], [2, 4, 68, 4], [3, 0, 69, 2], [3, 2, 71, 2], [3, 4, 73, 4],
	[4, 0, 76, 2], [4, 2, 75, 2], [4, 4, 73, 2], [4, 6, 71, 2], [5, 0, 75, 6], [5, 6, 73, 2],
	[6, 0, 73, 2], [6, 2, 76, 2], [6, 4, 78, 4], [7, 0, 78, 2], [7, 2, 75, 2], [7, 4, 71, 4],
	[8, 0, 80, 3], [8, 3, 78, 1], [8, 4, 76, 4], [9, 0, 78, 2], [9, 2, 75, 2], [9, 4, 71, 4],
	[10, 0, 73, 2], [10, 2, 76, 2], [10, 4, 80, 4], [11, 0, 81, 6], [11, 6, 80, 2],
	[12, 0, 78, 2], [12, 2, 76, 2], [12, 4, 73, 2], [12, 6, 76, 2], [13, 0, 78, 4], [13, 4, 75, 4],
	[14, 0, 76, 2], [14, 2, 80, 2], [14, 4, 83, 4], [15, 0, 78, 2], [15, 2, 75, 2], [15, 4, 71, 2], [15, 6, 75, 2],
]


## Loads the cached loop, or renders it (slow: call from a thread).
static func load_or_render() -> AudioStreamWAV:
	if FileAccess.file_exists(CACHE_PATH):
		var cached := Sfx.load_loop(CACHE_PATH)
		if cached:
			return cached
	var stream := render()
	stream.save_to_wav(CACHE_PATH)
	return stream


static func render() -> AudioStreamWAV:
	var beat := 60.0 / BPM
	var eighth := beat * 0.5
	var bar := beat * 4.0
	var total := int(bar * PROGRESSION.size() * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1985

	var kick := SpaceMusic._kick()
	var snare := _snare(rng)
	var hat := SpaceMusic._noise_hit(rng, 0.05, 60.0, 0.92)
	var chugs := {}
	for chord: String in ROOTS:
		chugs[chord] = _power_chord(ROOTS[chord] + 12, eighth, rng)

	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		var at := b * bar
		var fill := b % 8 == 7
		# Drums: kick on 1, 3 and the "and" of 3; snare on 2 and 4; hats on eighths.
		for k: float in [0.0, 2.0, 2.5]:
			SambaMusic._put(mix, kick, at + k * beat, 0.9)
		for s: float in [1.0, 3.0]:
			SambaMusic._put(mix, snare, at + s * beat, 0.55)
		if fill:
			for s: float in [3.25, 3.5, 3.75]:
				SambaMusic._put(mix, snare, at + s * beat, 0.4)
		for e in 8:
			SambaMusic._put(mix, hat, at + e * eighth, 0.2 if e % 2 == 0 else 0.12)
		# Rhythm guitar and bass in eighths, accent on the beat.
		var root: int = ROOTS[chord]
		for e in 8:
			SambaMusic._put(mix, chugs[chord], at + e * eighth, 0.34 if e % 2 == 0 else 0.26)
			SambaMusic._put(mix, _bass(IslandMusic._freq(root), int(eighth * 0.9 * RATE)), at + e * eighth, 0.42)

	for note: Array in MELODY:
		var start: float = note[0] * bar + note[1] * eighth
		var length := int((note[3] * eighth - 0.015) * RATE)
		SambaMusic._put(mix, _lead(IslandMusic._freq(note[2]), length), start, 0.26)

	return SambaMusic._to_stream(mix, total)


## A palm-muted power chord (root, fifth, octave), plucked and overdriven.
static func _power_chord(root: int, eighth: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(eighth * 0.95 * RATE))
	for interval: int in [0, 7, 12]:
		var pluck := IslandMusic._pluck(IslandMusic._freq(root + interval), eighth, rng)
		IslandMusic._add(out, pluck, 0, 0.5)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = tanh(out[i] * 3.5) * exp(-t * 7.0) * clampf((out.size() - i) / (0.01 * RATE), 0.0, 1.0)
	return out


## A singing lead guitar: a bright tone with vibrato, a little overdrive.
static func _lead(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var phase := 0.0
	for i in length:
		var t := float(i) / RATE
		var vibrato := 1.0 + 0.008 * sin(TAU * 6.0 * t) * clampf((t - 0.1) / 0.2, 0.0, 1.0)
		phase += TAU * freq * vibrato / RATE
		var tone := sin(phase) + 0.5 * sin(2.0 * phase) + 0.3 * sin(3.0 * phase) + 0.15 * sin(5.0 * phase)
		var envelope := minf(t / 0.01, 1.0) * (0.75 + 0.25 * exp(-t * 6.0)) \
				* clampf((length - i) / (0.03 * RATE), 0.0, 1.0)
		out[i] = tanh(tone * 1.4) * envelope
	return out


static func _bass(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		var t := float(i) / RATE
		var phase := TAU * freq * t
		out[i] = (sin(phase) + 0.4 * sin(2.0 * phase) + 0.15 * sin(3.0 * phase)) * minf(t / 0.004, 1.0) \
				* exp(-t * 4.0) * clampf((length - i) / (0.008 * RATE), 0.0, 1.0)
	return out


## A snare: a short tone plus a burst of noise.
static func _snare(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.2 * RATE))
	for i in out.size():
		var t := float(i) / RATE
		out[i] = (0.5 * sin(TAU * 190.0 * t) * exp(-t * 30.0) + 0.8 * rng.randf_range(-1.0, 1.0) * exp(-t * 18.0)) \
				* minf(t / 0.001, 1.0)
	return out
