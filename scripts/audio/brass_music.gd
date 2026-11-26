class_name BrassMusic
extends RefCounted
## Music for the German Forest, composed and synthesized in code (no audio
## files, no third-party rights): an original, bouncy polka for a festival
## brass band, in the style of the beer-tent bands of Bavaria. A tuba on every
## beat (root and fifth), brass chords on the off-beats, a trumpet melody, a
## snare on the off-beats, claps and a cymbal at the start of each phrase.
## Fast and happy (all the game's music is happy: CLAUDE.md).
## Rendered once in a background thread and cached in user://.

const RATE := 22050
const BPM := 152.0
const CACHE_PATH := "user://music_germany_v1.wav"

## One chord per 2/4 bar; 32 bars.
const PROGRESSION := ["Bb", "Bb", "F7", "F7", "F7", "F7", "Bb", "Bb",
		"Bb", "Bb", "Eb", "Eb", "Bb", "F7", "Bb", "Bb",
		"F7", "F7", "Bb", "Bb", "F7", "F7", "Bb", "Bb",
		"Eb", "Eb", "Bb", "Bb", "F7", "F7", "Bb", "Bb"]
const VOICINGS := {"Bb": [62, 65, 70], "F7": [63, 65, 69], "Eb": [63, 67, 70]}
const ROOTS := {"Bb": 34, "F7": 29, "Eb": 39}
## Trumpet: [bar, eighth (0-3), MIDI note, length in eighths].
const MELODY := [
	[0, 0, 70, 1], [0, 1, 74, 1], [0, 2, 77, 2], [1, 0, 82, 3], [1, 3, 77, 1],
	[2, 0, 77, 1], [2, 1, 75, 1], [2, 2, 74, 1], [2, 3, 72, 1], [3, 0, 75, 4],
	[4, 0, 72, 1], [4, 1, 74, 1], [4, 2, 75, 2], [5, 0, 81, 3], [5, 3, 77, 1],
	[6, 0, 74, 1], [6, 1, 77, 1], [6, 2, 82, 2], [7, 0, 77, 4],
	[8, 0, 70, 1], [8, 1, 74, 1], [8, 2, 77, 2], [9, 0, 82, 2], [9, 2, 84, 2],
	[10, 0, 82, 1], [10, 1, 79, 1], [10, 2, 75, 2], [11, 0, 79, 4],
	[12, 0, 77, 1], [12, 1, 79, 1], [12, 2, 82, 2], [13, 0, 81, 2], [13, 2, 77, 2],
	[14, 0, 82, 3], [14, 3, 77, 1], [15, 0, 82, 4],
	[16, 0, 81, 1], [16, 1, 82, 1], [16, 2, 81, 1], [16, 3, 77, 1], [17, 0, 72, 2], [17, 2, 75, 2],
	[18, 0, 74, 1], [18, 1, 77, 1], [18, 2, 82, 2], [19, 0, 77, 4],
	[20, 0, 81, 1], [20, 1, 82, 1], [20, 2, 84, 1], [20, 3, 81, 1], [21, 0, 77, 2], [21, 2, 72, 2],
	[22, 0, 74, 2], [22, 2, 70, 2], [23, 0, 74, 4],
	[24, 0, 75, 1], [24, 1, 79, 1], [24, 2, 82, 2], [25, 0, 87, 3], [25, 3, 82, 1],
	[26, 0, 86, 2], [26, 2, 82, 2], [27, 0, 77, 4],
	[28, 0, 81, 1], [28, 1, 82, 1], [28, 2, 84, 2], [29, 0, 81, 2], [29, 2, 77, 2],
	[30, 0, 82, 2], [30, 2, 77, 1], [30, 3, 74, 1], [31, 0, 70, 2], [31, 2, 77, 2],
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
	var bar := beat * 2.0
	var total := int(bar * PROGRESSION.size() * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1810

	var snare := RockMusic._snare(rng)
	var clap := SpaceMusic._noise_hit(rng, 0.12, 30.0, 0.5)
	var cymbal := SpaceMusic._noise_hit(rng, 1.2, 3.0, 0.95)
	var chords := {}
	for chord: String in VOICINGS:
		var out := PackedFloat32Array()
		out.resize(int(eighth * 0.8 * RATE))
		for note: int in VOICINGS[chord]:
			IslandMusic._add(out, _brass(IslandMusic._freq(note), out.size()), 0, 0.45)
		chords[chord] = out

	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		var at := b * bar
		var root: int = ROOTS[chord]
		# Oom on each beat (root, then fifth), pah on each off-beat.
		SambaMusic._put(mix, AlpineMusic._tuba(IslandMusic._freq(root), int(beat * 0.7 * RATE)), at, 0.62)
		SambaMusic._put(mix, AlpineMusic._tuba(IslandMusic._freq(root + 7), int(beat * 0.7 * RATE)), at + beat, 0.55)
		for k in 2:
			SambaMusic._put(mix, chords[chord], at + (k + 0.5) * beat, 0.32)
			SambaMusic._put(mix, snare, at + (k + 0.5) * beat, 0.16)
		if b % 2 == 1:
			SambaMusic._put(mix, clap, at + beat, 0.18)
		if b % 8 == 0:
			SambaMusic._put(mix, cymbal, at, 0.18)

	for note: Array in MELODY:
		var start: float = note[0] * bar + note[1] * eighth
		var length := int((note[3] * eighth - 0.02) * RATE)
		SambaMusic._put(mix, _brass(IslandMusic._freq(note[2]), length), start, 0.34)

	return SambaMusic._to_stream(mix, total)


## A bright brass tone (trumpet / horn): strong upper harmonics that open up
## a moment after the attack, a little vibrato on long notes.
static func _brass(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var phase := 0.0
	for i in length:
		var t := float(i) / RATE
		var vibrato := 1.0 + 0.004 * sin(TAU * 5.5 * t) * clampf((t - 0.15) / 0.2, 0.0, 1.0)
		phase += TAU * freq * vibrato / RATE
		var open := minf(t / 0.05, 1.0)
		var tone := sin(phase) + 0.7 * open * sin(2.0 * phase) + 0.5 * open * sin(3.0 * phase) \
				+ 0.3 * open * sin(4.0 * phase) + 0.15 * open * sin(5.0 * phase)
		var envelope := minf(t / 0.02, 1.0) * clampf((length - i) / (0.025 * RATE), 0.0, 1.0)
		out[i] = tanh(tone * 0.9) * envelope
	return out
