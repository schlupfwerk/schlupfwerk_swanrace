class_name RomanMusic
extends RefCounted
## Music for the Colosseum, composed and synthesized in code (no audio files,
## no third-party rights): an original triumphal march in the style of the
## fanfares of the old epic films. Trumpets play the fanfare, horns hold the
## chords, a lyre (harp) ripples, a snare drum marches with rolls and a big
## drum marks the beat. Bright and happy (all the game's music is happy:
## CLAUDE.md).
## Rendered once in a background thread and cached in user://.

const RATE := 22050
const BPM := 118.0
const CACHE_PATH := "user://music_colosseum_v1.wav"

## One chord per bar; 16 bars, in B-flat major.
const PROGRESSION := ["Bb", "Bb", "Eb", "Bb", "Bb", "F", "Bb", "F",
		"Eb", "Eb", "Bb", "Bb", "Gm", "C", "F", "F"]
const VOICINGS := {
	"Bb": [58, 62, 65], "Eb": [58, 63, 67], "F": [57, 60, 65], "Gm": [58, 62, 67], "C": [55, 60, 64],
}
const ROOTS := {"Bb": 34, "Eb": 39, "F": 41, "Gm": 43, "C": 36}
## Trumpets: [bar, eighth, MIDI note, length in eighths]. Fanfare leaps.
const MELODY := [
	[0, 0, 70, 1], [0, 1, 70, 1], [0, 2, 70, 1], [0, 3, 77, 3], [0, 6, 74, 2], [1, 0, 77, 4], [1, 4, 82, 4],
	[2, 0, 79, 2], [2, 2, 77, 1], [2, 3, 75, 1], [2, 4, 79, 2], [2, 6, 82, 2], [3, 0, 77, 6], [3, 6, 74, 1], [3, 7, 77, 1],
	[4, 0, 82, 1], [4, 1, 82, 1], [4, 2, 82, 1], [4, 3, 86, 3], [4, 6, 84, 2], [5, 0, 81, 4], [5, 4, 77, 4],
	[6, 0, 82, 3], [6, 3, 81, 1], [6, 4, 79, 2], [6, 6, 77, 2], [7, 0, 81, 6], [7, 6, 77, 1], [7, 7, 81, 1],
	[8, 0, 79, 2], [8, 2, 82, 2], [8, 4, 87, 4], [9, 0, 86, 2], [9, 2, 84, 2], [9, 4, 82, 4],
	[10, 0, 77, 1], [10, 1, 77, 1], [10, 2, 77, 1], [10, 3, 82, 3], [10, 6, 86, 2], [11, 0, 89, 6], [11, 6, 86, 2],
	[12, 0, 86, 2], [12, 2, 82, 2], [12, 4, 79, 2], [12, 6, 82, 2], [13, 0, 84, 3], [13, 3, 82, 1], [13, 4, 79, 4],
	[14, 0, 77, 2], [14, 2, 81, 2], [14, 4, 84, 2], [14, 6, 89, 2], [15, 0, 87, 2], [15, 2, 84, 2], [15, 4, 81, 4],
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
	rng.seed = 80

	var big_drum := SambaMusic._drum(60.0, 0.5, 6.0)
	var snare := RockMusic._snare(rng)
	var cymbal := SpaceMusic._noise_hit(rng, 1.2, 3.0, 0.95)
	var horns := {}
	for chord: String in VOICINGS:
		var out := PackedFloat32Array()
		out.resize(int(beat * 1.8 * RATE))
		for note: int in VOICINGS[chord]:
			IslandMusic._add(out, BrassMusic._brass(IslandMusic._freq(note), out.size()), 0, 0.3)
		horns[chord] = out

	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		var at := b * bar
		var root: int = ROOTS[chord]
		# Big drum on 1 and 3; the snare marches: ta, ta-ta, and a roll into the next bar.
		SambaMusic._put(mix, big_drum, at, 0.8)
		SambaMusic._put(mix, big_drum, at + 2.0 * beat, 0.6)
		for s: float in [1.0, 1.5, 3.0]:
			SambaMusic._put(mix, snare, at + s * beat, 0.32)
		for k in 4:
			SambaMusic._put(mix, snare, at + (3.5 + k * 0.125) * beat, 0.14 + k * 0.03)
		if b % 4 == 0:
			SambaMusic._put(mix, cymbal, at, 0.16)
		# Horns hold the chord on 1 and 3; the tuba walks the root and fifth.
		SambaMusic._put(mix, horns[chord], at, 0.26)
		SambaMusic._put(mix, horns[chord], at + 2.0 * beat, 0.22)
		SambaMusic._put(mix, AlpineMusic._tuba(IslandMusic._freq(root), int(beat * 0.8 * RATE)), at, 0.55)
		SambaMusic._put(mix, AlpineMusic._tuba(IslandMusic._freq(root + 7), int(beat * 0.8 * RATE)), at + 2.0 * beat, 0.45)
		# Lyre: a rippling arpeggio up the chord on beat 4.
		var voicing: Array = VOICINGS[chord]
		for k in 6:
			var note: int = voicing[k % 3] + 12 * (1 + k / 3)
			SambaMusic._put(mix, ChineseMusic._guzheng(IslandMusic._freq(note), rng), at + 3.0 * beat + k * eighth * 0.33,
					0.14)

	for note: Array in MELODY:
		var start: float = note[0] * bar + note[1] * eighth
		var length := int((note[3] * eighth - 0.02) * RATE)
		SambaMusic._put(mix, BrassMusic._brass(IslandMusic._freq(note[2]), length), start, 0.32)

	return SambaMusic._to_stream(mix, total)
