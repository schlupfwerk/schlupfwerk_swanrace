class_name AnimeMusic
extends RefCounted
## Music for Tokyo, composed and synthesized in code (no audio files, no
## third-party rights): an original loop in the style of an upbeat anime
## opening. Fast drums, a pumping octave bass, bright piano-like chord stabs,
## a glockenspiel arpeggio and a soaring synth lead, over the "royal road"
## progression (IV-V-iii-vi) loved in Japanese pop. Fast and happy (all the
## game's music is happy: CLAUDE.md).
## Rendered once in a background thread and cached in user://.

const RATE := 22050
const BPM := 176.0
const CACHE_PATH := "user://music_tokyo_v1.wav"

## One chord per bar; 16 bars, in D major.
const PROGRESSION := ["G", "A", "F#m", "Bm", "G", "A", "D", "D",
		"G", "A", "F#m", "Bm", "Em", "A", "D", "A"]
const VOICINGS := {
	"G": [67, 71, 74], "A": [69, 73, 76], "F#m": [66, 69, 73], "Bm": [66, 71, 74],
	"D": [66, 69, 74], "Em": [67, 71, 76],
}
const ROOTS := {"G": 43, "A": 45, "F#m": 42, "Bm": 47, "D": 38, "Em": 40}
## Lead: [bar, eighth (0-7), MIDI note, length in eighths].
const MELODY := [
	[0, 0, 83, 2], [0, 2, 81, 1], [0, 3, 79, 1], [0, 4, 81, 2], [0, 6, 83, 2],
	[1, 0, 85, 3], [1, 3, 83, 1], [1, 4, 81, 4],
	[2, 0, 81, 2], [2, 2, 78, 1], [2, 3, 81, 1], [2, 4, 85, 2], [2, 6, 86, 2],
	[3, 0, 86, 3], [3, 3, 85, 1], [3, 4, 83, 2], [3, 6, 78, 2],
	[4, 0, 79, 2], [4, 2, 83, 2], [4, 4, 86, 2], [4, 6, 88, 2],
	[5, 0, 88, 3], [5, 3, 86, 1], [5, 4, 85, 2], [5, 6, 81, 2],
	[6, 0, 86, 4], [6, 4, 85, 2], [6, 6, 86, 2], [7, 0, 90, 6], [7, 6, 88, 2],
	[8, 0, 86, 2], [8, 2, 83, 1], [8, 3, 86, 1], [8, 4, 91, 4],
	[9, 0, 88, 2], [9, 2, 85, 1], [9, 3, 88, 1], [9, 4, 93, 4],
	[10, 0, 90, 2], [10, 2, 88, 2], [10, 4, 85, 2], [10, 6, 81, 2],
	[11, 0, 83, 3], [11, 3, 86, 1], [11, 4, 90, 4],
	[12, 0, 91, 2], [12, 2, 90, 2], [12, 4, 88, 2], [12, 6, 86, 2],
	[13, 0, 88, 2], [13, 2, 86, 2], [13, 4, 85, 2], [13, 6, 88, 2],
	[14, 0, 86, 6], [14, 6, 81, 1], [14, 7, 83, 1], [15, 0, 85, 2], [15, 2, 86, 2], [15, 4, 88, 4],
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
	rng.seed = 2000

	var kick := SpaceMusic._kick()
	var snare := RockMusic._snare(rng)
	var hat := SpaceMusic._noise_hit(rng, 0.05, 60.0, 0.92)
	var crash := SpaceMusic._noise_hit(rng, 1.4, 2.5, 0.95)
	var stabs := {}
	for chord: String in VOICINGS:
		var out := PackedFloat32Array()
		out.resize(int(eighth * 1.2 * RATE))
		for note: int in VOICINGS[chord]:
			IslandMusic._add(out, _piano(IslandMusic._freq(note), out.size()), 0, 0.4)
		stabs[chord] = out

	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		var at := b * bar
		var root: int = ROOTS[chord]
		for k: float in [0.0, 1.5, 2.0]:
			SambaMusic._put(mix, kick, at + k * beat, 0.85)
		for s: float in [1.0, 3.0]:
			SambaMusic._put(mix, snare, at + s * beat, 0.5)
		for e in 8:
			SambaMusic._put(mix, hat, at + e * eighth, 0.18 if e % 2 == 1 else 0.1)
			# Octave-pumping bass.
			var note := root + (12 if e % 2 == 1 else 0)
			SambaMusic._put(mix, RockMusic._bass(IslandMusic._freq(note), int(eighth * 0.85 * RATE)),
					at + e * eighth, 0.36)
		# Chord stabs: on the beat and pushed ahead of beats 3 and 4.
		for e: int in [0, 2, 3, 5, 6]:
			SambaMusic._put(mix, stabs[chord], at + e * eighth, 0.26)
		# Glockenspiel arpeggio up the chord, in sixteenths, every other bar.
		if b % 2 == 0:
			var voicing: Array = VOICINGS[chord]
			for s in 8:
				var pitch: int = voicing[s % 3] + 12 * (1 + s / 3)
				SambaMusic._put(mix, AlpineMusic._glock(IslandMusic._freq(mini(pitch, 100))),
						at + 2.0 * beat + s * eighth * 0.5, 0.1)
		if b % 4 == 0:
			SambaMusic._put(mix, crash, at, 0.14)

	for note: Array in MELODY:
		var start: float = note[0] * bar + note[1] * eighth
		var length := int((note[3] * eighth - 0.015) * RATE)
		SambaMusic._put(mix, _lead(IslandMusic._freq(note[2] - 12), length), start, 0.3)

	return SambaMusic._to_stream(mix, total)


## A bright, piano-like hit: a few harmonics with a fast decay.
static func _piano(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		var t := float(i) / RATE
		var p := TAU * freq * t
		var tone := sin(p) + 0.5 * sin(2.0 * p) * exp(-t * 6.0) + 0.25 * sin(3.0 * p) * exp(-t * 9.0)
		out[i] = tone * minf(t / 0.003, 1.0) * exp(-t * 4.5) * clampf((length - i) / (0.02 * RATE), 0.0, 1.0)
	return out


## A soaring synth lead: two detuned saws, a touch of vibrato.
static func _lead(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var a := 0.0
	var b := 0.0
	var low := 0.0
	for i in length:
		var t := float(i) / RATE
		var vibrato := 1.0 + 0.006 * sin(TAU * 6.0 * t) * clampf((t - 0.12) / 0.2, 0.0, 1.0)
		a = fmod(a + freq * vibrato / RATE, 1.0)
		b = fmod(b + freq * vibrato * 1.005 / RATE, 1.0)
		var raw := (2.0 * a - 1.0) + (2.0 * b - 1.0)
		low += (raw - low) * 0.35
		var envelope := minf(t / 0.01, 1.0) * clampf((length - i) / (0.03 * RATE), 0.0, 1.0)
		out[i] = low * 0.5 * envelope
	return out
