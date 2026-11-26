class_name MusetteMusic
extends RefCounted
## Music for Paris, composed and synthesized in code (no audio files, no
## third-party rights): an original, lively musette waltz, the accordion
## music of the Paris street dances. In 3/4: a bass note on the first beat,
## accordion chords on the other two, a swirling accordion melody with
## quick runs, and a light triangle. Fast and happy (all the game's music is
## happy: CLAUDE.md).
## Rendered once in a background thread and cached in user://.

const RATE := 22050
const BPM := 192.0
const CACHE_PATH := "user://music_paris_v1.wav"

## One chord per bar; 32 bars, in G major.
const PROGRESSION := ["G", "G", "D7", "D7", "D7", "D7", "G", "G",
		"G", "G7", "C", "C", "G", "D7", "G", "G",
		"Em", "Em", "Am", "Am", "D7", "D7", "G", "G",
		"C", "C", "G", "E7", "Am", "D7", "G", "G"]
const VOICINGS := {
	"G": [59, 62, 67], "D7": [60, 62, 66], "G7": [59, 62, 65], "C": [60, 64, 67], "Em": [59, 64, 67],
	"Am": [60, 64, 69], "E7": [59, 62, 68],
}
const ROOTS := {"G": 43, "D7": 38, "G7": 43, "C": 36, "Em": 40, "Am": 45, "E7": 40}
## Melody: [bar, beat, MIDI note, length in beats]. Runs in eighths ("x.5").
const MELODY := [
	[0, 0, 74, 1], [0, 1, 79, 1], [0, 2, 83, 1], [1, 0, 86, 2], [1, 2, 83, 1],
	[2, 0, 81, 1], [2, 1, 78, 0.5], [2, 1.5, 79, 0.5], [2, 2, 81, 1], [3, 0, 84, 3],
	[4, 0, 84, 1], [4, 1, 81, 1], [4, 2, 78, 1], [5, 0, 76, 1], [5, 1, 74, 1], [5, 2, 72, 1],
	[6, 0, 71, 1], [6, 1, 74, 1], [6, 2, 79, 1], [7, 0, 83, 2], [7, 2, 79, 1],
	[8, 0, 74, 1], [8, 1, 79, 1], [8, 2, 83, 1], [9, 0, 86, 1], [9, 1, 89, 1], [9, 2, 88, 1],
	[10, 0, 88, 2], [10, 2, 84, 1], [11, 0, 79, 1], [11, 1, 81, 0.5], [11, 1.5, 83, 0.5], [11, 2, 84, 1],
	[12, 0, 86, 1], [12, 1, 83, 1], [12, 2, 79, 1], [13, 0, 81, 1], [13, 1, 78, 1], [13, 2, 74, 1],
	[14, 0, 79, 3], [15, 0, 79, 1], [15, 1, 81, 1], [15, 2, 83, 1],
	[16, 0, 83, 2], [16, 2, 79, 1], [17, 0, 76, 1], [17, 1, 79, 1], [17, 2, 83, 1],
	[18, 0, 84, 2], [18, 2, 81, 1], [19, 0, 76, 1], [19, 1, 77, 0.5], [19, 1.5, 79, 0.5], [19, 2, 81, 1],
	[20, 0, 78, 1], [20, 1, 81, 1], [20, 2, 84, 1], [21, 0, 86, 2], [21, 2, 84, 1],
	[22, 0, 83, 1], [22, 1, 81, 0.5], [22, 1.5, 79, 0.5], [22, 2, 78, 1], [23, 0, 79, 3],
	[24, 0, 76, 1], [24, 1, 79, 1], [24, 2, 84, 1], [25, 0, 88, 2], [25, 2, 84, 1],
	[26, 0, 83, 1], [26, 1, 86, 1], [26, 2, 91, 1], [27, 0, 88, 2], [27, 2, 86, 1],
	[28, 0, 84, 1], [28, 1, 81, 1], [28, 2, 76, 1], [29, 0, 78, 1], [29, 1, 81, 1], [29, 2, 84, 1],
	[30, 0, 83, 2], [30, 2, 78, 1], [31, 0, 79, 1], [31, 1, 83, 1], [31, 2, 86, 1],
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
	var bar := beat * 3.0
	var total := int(bar * PROGRESSION.size() * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var triangle := _triangle()
	var chords := {}
	for chord: String in VOICINGS:
		var out := PackedFloat32Array()
		out.resize(int(beat * 0.5 * RATE))
		for note: int in VOICINGS[chord]:
			IslandMusic._add(out, AlpineMusic._reed(IslandMusic._freq(note), out.size(), 0.01), 0, 0.45)
		chords[chord] = out

	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		var at := b * bar
		var root: int = ROOTS[chord]
		var bass_note := root if b % 2 == 0 else root + 7
		SambaMusic._put(mix, AlpineMusic._tuba(IslandMusic._freq(bass_note + 12), int(beat * 0.8 * RATE)), at, 0.5)
		SambaMusic._put(mix, chords[chord], at + beat, 0.28)
		SambaMusic._put(mix, chords[chord], at + 2.0 * beat, 0.24)
		SambaMusic._put(mix, triangle, at, 0.08 if b % 4 else 0.14)

	for note: Array in MELODY:
		var start: float = note[0] * bar + note[1] * beat
		var length := int((note[3] * beat - 0.02) * RATE)
		SambaMusic._put(mix, AlpineMusic._reed(IslandMusic._freq(note[2]), length, 0.03), start, 0.36)

	return SambaMusic._to_stream(mix, total)


## A small triangle: a high ring that fades.
static func _triangle() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.6 * RATE))
	for i in out.size():
		var t := float(i) / RATE
		out[i] = (sin(TAU * 2900.0 * t) + 0.5 * sin(TAU * 4100.0 * t)) * exp(-t * 6.0) * minf(t / 0.002, 1.0)
	return out
