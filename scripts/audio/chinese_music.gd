class_name ChineseMusic
extends RefCounted
## Music for the Great Wall, composed and synthesized in code (no audio files,
## no third-party rights): an original, lively loop in the style of Chinese
## festival music, on the pentatonic scale. A big drum and a woodblock keep
## a bouncy beat, a guzheng (plucked zither) ripples up and down, a bamboo
## flute (dizi) plays the tune with little slides, and a gong opens each
## phrase. Fast and happy (all the game's music is happy: CLAUDE.md).
## Rendered once in a background thread and cached in user://.

const RATE := 22050
const BPM := 138.0
const CACHE_PATH := "user://music_great_wall_v1.wav"

## The harmony, one per bar (drone notes from the pentatonic scale), 16 bars.
const PROGRESSION := ["G", "G", "Em", "D", "C", "D", "G", "G",
		"G", "Em", "C", "D", "Em", "D", "G", "D"]
const ROOTS := {"G": 43, "Em": 40, "C": 36, "D": 38}
## Guzheng ripples: notes of G major pentatonic (G A B D E) over two octaves.
const SCALE := [67, 69, 71, 74, 76, 79, 81, 83, 86, 88]
## Flute: [bar, eighth, MIDI note, length in eighths].
const MELODY := [
	[0, 0, 79, 2], [0, 2, 81, 1], [0, 3, 83, 1], [0, 4, 86, 3], [0, 7, 83, 1], [1, 0, 81, 2], [1, 2, 79, 2], [1, 4, 76, 4],
	[2, 0, 79, 2], [2, 2, 76, 1], [2, 3, 74, 1], [2, 4, 76, 2], [2, 6, 79, 2], [3, 0, 81, 6], [3, 6, 79, 1], [3, 7, 81, 1],
	[4, 0, 83, 2], [4, 2, 86, 2], [4, 4, 88, 2], [4, 6, 86, 2], [5, 0, 83, 2], [5, 2, 81, 2], [5, 4, 79, 2], [5, 6, 81, 2],
	[6, 0, 83, 3], [6, 3, 81, 1], [6, 4, 79, 2], [6, 6, 76, 2], [7, 0, 79, 8],
	[8, 0, 86, 2], [8, 2, 88, 2], [8, 4, 86, 1], [8, 5, 83, 1], [8, 6, 81, 2], [9, 0, 83, 4], [9, 4, 79, 4],
	[10, 0, 76, 2], [10, 2, 79, 2], [10, 4, 81, 2], [10, 6, 83, 2], [11, 0, 86, 6], [11, 6, 83, 2],
	[12, 0, 88, 2], [12, 2, 86, 1], [12, 3, 83, 1], [12, 4, 81, 2], [12, 6, 79, 2], [13, 0, 81, 3], [13, 3, 83, 1], [13, 4, 86, 4],
	[14, 0, 83, 2], [14, 2, 81, 2], [14, 4, 79, 4], [15, 0, 81, 2], [15, 2, 83, 2], [15, 4, 86, 4],
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
	rng.seed = 1421

	var drum := SambaMusic._drum(80.0, 0.45, 7.0)
	var block := SambaMusic._click(1500.0, 0.05, 80.0)
	var cymbal := SpaceMusic._noise_hit(rng, 0.35, 9.0, 0.85)
	var gong := _gong()
	var plucks := {}
	for note: int in SCALE:
		plucks[note] = _guzheng(IslandMusic._freq(note), rng)

	for b in PROGRESSION.size():
		var at := b * bar
		var root: int = ROOTS[PROGRESSION[b]]
		# Big drum on 1 and 3 and the "and" of 4; woodblock on the off-beats.
		for k: float in [0.0, 2.0, 3.5]:
			SambaMusic._put(mix, drum, at + k * beat, 0.8)
		for e in 8:
			if e % 2 == 1:
				SambaMusic._put(mix, block, at + e * eighth, 0.18)
		SambaMusic._put(mix, cymbal, at + 1.0 * beat, 0.12)
		SambaMusic._put(mix, cymbal, at + 3.0 * beat, 0.12)
		if b % 8 == 0:
			SambaMusic._put(mix, gong, at, 0.35)
		# Plucked bass drone: root and fifth.
		SambaMusic._put(mix, IslandMusic._bass(IslandMusic._freq(root)), at, 0.5)
		SambaMusic._put(mix, IslandMusic._bass(IslandMusic._freq(root + 7)), at + 2.0 * beat, 0.4)
		# Guzheng ripple: up the scale in sixteenths on beat 3, every bar;
		# down on the odd bars.
		var up := b % 2 == 0
		for s in 6:
			var index := s if up else SCALE.size() - 1 - s
			SambaMusic._put(mix, plucks[SCALE[index]], at + 2.0 * beat + s * eighth * 0.5, 0.2)

	for note: Array in MELODY:
		var start: float = note[0] * bar + note[1] * eighth
		var length := int((note[3] * eighth - 0.015) * RATE)
		SambaMusic._put(mix, _dizi(IslandMusic._freq(note[2]), length), start, 0.3)

	return SambaMusic._to_stream(mix, total)


## A guzheng string: a bright pluck that bends up into the note.
static func _guzheng(freq: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var pluck := IslandMusic._pluck(freq, 0.9, rng)
	for i in pluck.size():
		pluck[i] *= exp(-float(i) / RATE * 2.5)
	return pluck


## A bamboo flute: breathy, bright, sliding up into each note from below.
static func _dizi(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 7.0)
	var phase := 0.0
	var air := 0.0
	for i in length:
		var t := float(i) / RATE
		var slide := 1.0 - 0.06 * exp(-t * 30.0)
		var vibrato := 1.0 + 0.007 * sin(TAU * 6.0 * t) * clampf((t - 0.15) / 0.2, 0.0, 1.0)
		phase += TAU * freq * slide * vibrato / RATE
		air = lerpf(air, rng.randf_range(-1.0, 1.0), 0.4)
		var tone := sin(phase) + 0.35 * sin(2.0 * phase) + 0.12 * sin(3.0 * phase)
		var envelope := minf(t / 0.02, 1.0) * clampf((length - i) / (0.04 * RATE), 0.0, 1.0)
		out[i] = (tone + 0.08 * air) * envelope
	return out


## A gong: a low, wobbling crash that swells and fades.
static func _gong() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(2.5 * RATE))
	for i in out.size():
		var t := float(i) / RATE
		var wobble := 1.0 + 0.02 * sin(TAU * 3.0 * t)
		var tone := sin(TAU * 110.0 * wobble * t) + 0.6 * sin(TAU * 167.0 * t) + 0.4 * sin(TAU * 243.0 * t) \
				+ 0.3 * sin(TAU * 389.0 * t)
		out[i] = tone * minf(t / 0.08, 1.0) * exp(-t * 1.4)
	return out
