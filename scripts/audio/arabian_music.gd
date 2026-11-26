class_name ArabianMusic
extends RefCounted
## Music for Egypt, composed and synthesized in code (no audio files, no
## third-party rights): an original, bouncy loop in the style of the Arabian
## Nights adventure tunes, on the Hijaz scale (D Eb F# G A Bb C). A darbuka
## plays the maqsum rhythm (doum tek-tek doum tek), a riq (tambourine) shakes
## along, an oud plucks the chords and a ney (reed flute) plays the tune with
## little turns. Fast and happy (all the game's music is happy: CLAUDE.md).
## Rendered once in a background thread and cached in user://.

const RATE := 22050
const BPM := 132.0
const CACHE_PATH := "user://music_egypt_v1.wav"

## One chord per bar; 16 bars. D (Hijaz home), Gm, C and the bright D major.
const PROGRESSION := ["D", "D", "Gm", "D", "D", "C", "D", "D",
		"Gm", "Gm", "D", "D", "C", "C", "D", "D"]
const VOICINGS := {"D": [62, 66, 69], "Gm": [62, 67, 70], "C": [60, 64, 67]}
const ROOTS := {"D": 38, "Gm": 43, "C": 36}
## Maqsum in eighths: doum on 0 and 4, tek on 1, 3 and 6.
const DOUM := [0, 4]
const TEK := [1, 3, 6]
## Ney: [bar, eighth, MIDI note, length in eighths]. Hijaz: D Eb F# G A Bb C.
const MELODY := [
	[0, 0, 74, 2], [0, 2, 75, 1], [0, 3, 78, 1], [0, 4, 79, 2], [0, 6, 81, 2], [1, 0, 79, 1], [1, 1, 78, 1], [1, 2, 75, 2], [1, 4, 74, 4],
	[2, 0, 79, 2], [2, 2, 82, 1], [2, 3, 81, 1], [2, 4, 79, 2], [2, 6, 78, 2], [3, 0, 81, 6], [3, 6, 79, 1], [3, 7, 81, 1],
	[4, 0, 82, 2], [4, 2, 81, 1], [4, 3, 79, 1], [4, 4, 78, 2], [4, 6, 79, 2], [5, 0, 76, 2], [5, 2, 79, 2], [5, 4, 84, 4],
	[6, 0, 82, 1], [6, 1, 81, 1], [6, 2, 79, 1], [6, 3, 78, 1], [6, 4, 75, 2], [6, 6, 78, 2], [7, 0, 74, 8],
	[8, 0, 79, 1], [8, 1, 81, 1], [8, 2, 82, 2], [8, 4, 86, 2], [8, 6, 84, 2], [9, 0, 82, 3], [9, 3, 81, 1], [9, 4, 79, 4],
	[10, 0, 78, 2], [10, 2, 81, 2], [10, 4, 86, 2], [10, 6, 87, 2], [11, 0, 86, 6], [11, 6, 84, 1], [11, 7, 82, 1],
	[12, 0, 84, 2], [12, 2, 82, 1], [12, 3, 81, 1], [12, 4, 79, 2], [12, 6, 76, 2], [13, 0, 79, 2], [13, 2, 84, 2], [13, 4, 88, 4],
	[14, 0, 86, 2], [14, 2, 87, 1], [14, 3, 86, 1], [14, 4, 82, 2], [14, 6, 81, 1], [14, 7, 78, 1], [15, 0, 81, 4], [15, 4, 86, 4],
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
	rng.seed = 1001

	var doum := SambaMusic._drum(85.0, 0.35, 9.0)
	var tek := SambaMusic._click(2100.0, 0.05, 90.0)
	var riq := SpaceMusic._noise_hit(rng, 0.09, 30.0, 0.95)
	var plucks := {}
	for chord: String in VOICINGS:
		var out := PackedFloat32Array()
		out.resize(int(0.5 * RATE))
		for k in VOICINGS[chord].size():
			var note: int = VOICINGS[chord][k]
			IslandMusic._add(out, ChineseMusic._guzheng(IslandMusic._freq(note), rng), int(k * 0.015 * RATE), 0.45)
		plucks[chord] = out

	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		var at := b * bar
		for e: int in DOUM:
			SambaMusic._put(mix, doum, at + e * eighth, 0.85)
		for e: int in TEK:
			SambaMusic._put(mix, tek, at + e * eighth, 0.3)
		# A quick tek roll at the end of every other bar.
		if b % 2 == 1:
			for k in 2:
				SambaMusic._put(mix, tek, at + (7.0 + k * 0.5) * eighth, 0.22)
		for e in 8:
			SambaMusic._put(mix, riq, at + e * eighth, 0.12 if e % 2 == 0 else 0.07)
		# Oud: chord on beats 1 and 3, the root plucked on the off-beats.
		SambaMusic._put(mix, plucks[chord], at, 0.32)
		SambaMusic._put(mix, plucks[chord], at + 4.0 * eighth, 0.26)
		var root: int = ROOTS[chord]
		SambaMusic._put(mix, IslandMusic._bass(IslandMusic._freq(root)), at, 0.5)
		SambaMusic._put(mix, IslandMusic._bass(IslandMusic._freq(root + 7)), at + 3.0 * eighth, 0.35)
		SambaMusic._put(mix, IslandMusic._bass(IslandMusic._freq(root)), at + 6.0 * eighth, 0.35)

	for note: Array in MELODY:
		var start: float = note[0] * bar + note[1] * eighth
		var length := int((note[3] * eighth - 0.015) * RATE)
		SambaMusic._put(mix, ChineseMusic._dizi(IslandMusic._freq(note[2]), length), start, 0.3)

	return SambaMusic._to_stream(mix, total)
