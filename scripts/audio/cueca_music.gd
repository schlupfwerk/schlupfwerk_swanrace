class_name CuecaMusic
extends RefCounted
## Music for the Andes, composed and synthesized in code (no audio files, no
## third-party rights): an original, lively loop in the style of the cueca,
## Chile's national dance. In 6/8 with its typical "hemiola" (the beat swings
## between 3+3 and 2+2+2): a strummed guitar, a bombo (deep drum), a pandero
## (tambourine), hand claps and an accordion melody. Fast and happy (all the
## game's music is happy: CLAUDE.md).
## Rendered once in a background thread and cached in user://.

const RATE := 22050
## Eighth notes per minute (a bar of 6/8 has six).
const EIGHTHS := 330.0
const CACHE_PATH := "user://music_andes_v1.wav"

const PROGRESSION := ["G", "G", "D7", "D7", "D7", "D7", "G", "G",
		"G", "G7", "C", "C", "G", "D7", "G", "G",
		"C", "C", "G", "G", "D7", "D7", "G", "G",
		"C", "C", "G", "G", "D7", "D7", "G", "G"]
## Guitar voicings (MIDI), low and full.
const VOICINGS := {
	"G": [43, 47, 50, 55, 59, 67], "D7": [50, 57, 60, 66], "C": [48, 52, 55, 60, 64],
	"G7": [43, 47, 50, 53, 59, 67],
}
const ROOTS := {"G": 31, "D7": 38, "C": 36, "G7": 31}
## Strums: [eighth, down?]; the first bar of each pair in 3+3, the second in 2+2+2.
const STRUM_A := [[0, true], [1, false], [2, true], [3, true], [4, false], [5, true]]
const STRUM_B := [[0, true], [2, true], [3, false], [4, true], [5, false]]
## Accordion: [bar, eighth, MIDI note, length in eighths].
const MELODY := [
	[0, 0, 74, 2], [0, 2, 79, 1], [0, 3, 78, 2], [0, 5, 76, 1], [1, 0, 74, 3], [1, 3, 71, 3],
	[2, 0, 72, 2], [2, 2, 74, 1], [2, 3, 76, 2], [2, 5, 78, 1], [3, 0, 81, 6],
	[4, 0, 78, 2], [4, 2, 81, 1], [4, 3, 79, 2], [4, 5, 78, 1], [5, 0, 76, 3], [5, 3, 72, 3],
	[6, 0, 71, 2], [6, 2, 74, 1], [6, 3, 79, 2], [6, 5, 78, 1], [7, 0, 79, 6],
	[8, 0, 83, 2], [8, 2, 81, 1], [8, 3, 79, 2], [8, 5, 81, 1], [9, 0, 83, 3], [9, 3, 77, 3],
	[10, 0, 76, 2], [10, 2, 79, 1], [10, 3, 84, 3], [11, 0, 83, 2], [11, 2, 81, 2], [11, 4, 79, 2],
	[12, 0, 79, 2], [12, 2, 83, 1], [12, 3, 86, 3], [13, 0, 84, 2], [13, 2, 81, 2], [13, 4, 78, 2],
	[14, 0, 79, 3], [14, 3, 74, 3], [15, 0, 79, 6],
	[16, 0, 76, 2], [16, 2, 79, 1], [16, 3, 84, 2], [16, 5, 83, 1], [17, 0, 81, 3], [17, 3, 79, 3],
	[18, 0, 79, 2], [18, 2, 83, 1], [18, 3, 86, 2], [18, 5, 83, 1], [19, 0, 79, 6],
	[20, 0, 81, 2], [20, 2, 78, 1], [20, 3, 74, 2], [20, 5, 78, 1], [21, 0, 81, 3], [21, 3, 84, 3],
	[22, 0, 83, 2], [22, 2, 81, 1], [22, 3, 79, 2], [22, 5, 78, 1], [23, 0, 79, 6],
	[24, 0, 76, 1], [24, 1, 79, 1], [24, 2, 84, 1], [24, 3, 88, 3], [25, 0, 86, 2], [25, 2, 84, 2], [25, 4, 81, 2],
	[26, 0, 83, 2], [26, 2, 86, 1], [26, 3, 91, 3], [27, 0, 86, 3], [27, 3, 83, 3],
	[28, 0, 81, 2], [28, 2, 84, 1], [28, 3, 86, 2], [28, 5, 84, 1], [29, 0, 81, 3], [29, 3, 78, 3],
	[30, 0, 79, 2], [30, 2, 83, 1], [30, 3, 86, 2], [30, 5, 83, 1], [31, 0, 79, 3], [31, 3, 74, 3],
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
	var eighth := 60.0 / EIGHTHS
	var bar := eighth * 6.0
	var total := int(bar * PROGRESSION.size() * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1810

	var bombo := SambaMusic._drum(70.0, 0.4, 8.0)
	var rim := SambaMusic._click(900.0, 0.05, 60.0)
	var jingle := SpaceMusic._noise_hit(rng, 0.12, 25.0, 0.95)
	var clap := SpaceMusic._noise_hit(rng, 0.1, 35.0, 0.5)
	var strums := {}
	for chord: String in VOICINGS:
		for down: bool in [true, false]:
			strums[chord + str(down)] = IslandMusic._strum(VOICINGS[chord], down, rng)

	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		var at := b * bar
		var hemiola := b % 2 == 1
		var pattern: Array = STRUM_B if hemiola else STRUM_A
		for hit: Array in pattern:
			SambaMusic._put(mix, strums[chord + str(hit[1])], at + hit[0] * eighth, 0.3 if hit[1] else 0.22)
		# Bombo on the big beats: 3+3, or 2+2+2 on the hemiola bars.
		var beats := [0, 2, 4] if hemiola else [0, 3]
		for e: int in beats:
			SambaMusic._put(mix, bombo, at + e * eighth, 0.75 if e == 0 else 0.55)
		SambaMusic._put(mix, rim, at + (5 if not hemiola else 1) * eighth, 0.18)
		for e in 6:
			SambaMusic._put(mix, jingle, at + e * eighth, 0.14 if e in beats else 0.07)
		for e: int in beats:
			SambaMusic._put(mix, clap, at + e * eighth, 0.16)
		# Bass: root on the first beat, fifth on the second.
		var root: int = ROOTS[chord]
		SambaMusic._put(mix, IslandMusic._bass(IslandMusic._freq(root + 12)), at, 0.45)
		SambaMusic._put(mix, IslandMusic._bass(IslandMusic._freq(root + 19)), at + 3.0 * eighth, 0.35)

	for note: Array in MELODY:
		var start: float = note[0] * bar + note[1] * eighth
		var length := int((note[3] * eighth - 0.02) * RATE)
		SambaMusic._put(mix, AlpineMusic._reed(IslandMusic._freq(note[2]), length, 0.03), start, 0.34)

	return SambaMusic._to_stream(mix, total)
