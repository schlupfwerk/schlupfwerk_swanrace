class_name AlpineMusic
extends RefCounted
## Music for the Swiss Alps, composed and synthesized in code (no audio files,
## no third-party rights): an original loop in the style of a Swiss Ländler,
## the folk dance of the Alps, in 3/4. A tuba "oom" on the first beat and an
## accordion "pah-pah" on the other two, a yodel-like accordion melody with
## big leaps and quick ornaments, a glockenspiel doubling it an octave up,
## claps on the "pah-pah" and a cowbell every few bars. Fast and cheerful
## (all the game's music is happy: CLAUDE.md).
## Rendered once in a background thread and cached in user://.

const RATE := 22050
const BPM := 200.0
const CACHE_PATH := "user://music_swiss_alps_v2.wav"

## One chord per 3/4 bar; 32 bars.
const PROGRESSION := ["F", "F", "C7", "C7", "C7", "C7", "F", "F",
		"F", "F", "Bb", "Bb", "F", "C7", "F", "F",
		"C7", "C7", "F", "F", "C7", "C7", "F", "F",
		"F", "F7", "Bb", "Bb", "F", "C7", "F", "F"]
const VOICINGS := {
	"F": [60, 65, 69], "C7": [60, 64, 70], "Bb": [62, 65, 70], "F7": [63, 65, 69],
}
const ROOTS := {"F": 29, "C7": 36, "Bb": 34, "F7": 29}
## Melody: [bar, beat, MIDI note, length in beats]. Leaps up and down like a yodel.
const MELODY := [
	[0, 0, 72, 1], [0, 1, 77, 1], [0, 2, 81, 1], [1, 0, 84, 2], [1, 2, 81, 1],
	[2, 0, 79, 1], [2, 1, 76, 1], [2, 2, 72, 1], [3, 0, 79, 2], [3, 2, 76, 1],
	[4, 0, 82, 1], [4, 1, 79, 1], [4, 2, 76, 1], [5, 0, 72, 2], [5, 2, 76, 1],
	[6, 0, 77, 1], [6, 1, 81, 1], [6, 2, 77, 1], [7, 0, 72, 3],
	[8, 0, 72, 1], [8, 1, 77, 1], [8, 2, 81, 1], [9, 0, 84, 1], [9, 1, 86, 1], [9, 2, 84, 1],
	[10, 0, 82, 1], [10, 1, 86, 1], [10, 2, 82, 1], [11, 0, 77, 3],
	[12, 0, 81, 1], [12, 1, 77, 1], [12, 2, 72, 1], [13, 0, 76, 1], [13, 1, 79, 1], [13, 2, 82, 1],
	[14, 0, 81, 2], [14, 2, 79, 1], [15, 0, 77, 3],
	[16, 0, 79, 1], [16, 1, 76, 1], [16, 2, 79, 1], [17, 0, 84, 2], [17, 2, 82, 1],
	[18, 0, 81, 1], [18, 1, 77, 1], [18, 2, 81, 1], [19, 0, 84, 2], [19, 2, 81, 1],
	[20, 0, 79, 1], [20, 1, 82, 1], [20, 2, 79, 1], [21, 0, 76, 1], [21, 1, 72, 1], [21, 2, 76, 1],
	[22, 0, 77, 2], [22, 2, 72, 1], [23, 0, 69, 3],
	[24, 0, 72, 1], [24, 1, 77, 1], [24, 2, 81, 1], [25, 0, 87, 2], [25, 2, 84, 1],
	[26, 0, 86, 1], [26, 1, 82, 1], [26, 2, 77, 1], [27, 0, 74, 2], [27, 2, 77, 1],
	[28, 0, 81, 1], [28, 1, 84, 1], [28, 2, 81, 1], [29, 0, 79, 1], [29, 1, 76, 1], [29, 2, 79, 1],
	[30, 0, 77, 3], [31, 0, 72, 1], [31, 1, 74, 1], [31, 2, 76, 1],
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

	var chords := {}
	for chord: String in VOICINGS:
		var notes: Array = VOICINGS[chord]
		var out := PackedFloat32Array()
		out.resize(int(beat * 0.55 * RATE))
		for note: int in notes:
			IslandMusic._add(out, _reed(IslandMusic._freq(note), out.size(), 0.01), 0, 0.5)
		chords[chord] = out
	var bell := _cowbell()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1291
	var clap := SpaceMusic._noise_hit(rng, 0.12, 30.0, 0.5)

	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		var at := b * bar
		var root: int = ROOTS[chord]
		# Oom: the tuba alternates root and fifth from bar to bar.
		var bass_note := root if b % 2 == 0 else root + 7
		SambaMusic._put(mix, _tuba(IslandMusic._freq(bass_note), int(beat * 0.8 * RATE)), at, 0.6)
		# Pah-pah, with claps.
		SambaMusic._put(mix, chords[chord], at + beat, 0.3)
		SambaMusic._put(mix, chords[chord], at + 2.0 * beat, 0.26)
		SambaMusic._put(mix, clap, at + beat, 0.16)
		SambaMusic._put(mix, clap, at + 2.0 * beat, 0.12)
		if b % 4 == 0:
			SambaMusic._put(mix, bell, at, 0.22)

	# The melody gets quick ornaments on its long notes: the note, a hop up a
	# step and back, then the note held (a little like a yodel).
	for note: Array in _ornamented():
		var start: float = note[0] * bar + note[1] * beat
		var length := int((note[3] * beat - 0.02) * RATE)
		var freq := IslandMusic._freq(note[2])
		SambaMusic._put(mix, _reed(freq, length, 0.03), start, 0.34)
		SambaMusic._put(mix, _glock(freq * 2.0), start, 0.16)

	return SambaMusic._to_stream(mix, total)


static func _ornamented() -> Array:
	var notes := []
	for note: Array in MELODY:
		if note[3] < 2:
			notes.append(note)
			continue
		var bar: int = note[0]
		var at: float = note[1]
		var pitch: int = note[2]
		notes.append([bar, at, pitch, 0.5])
		notes.append([bar, at + 0.5, pitch + 2, 0.5])
		notes.append([bar, at + 1.0, pitch + 4, 0.5])
		notes.append([bar, at + 1.5, pitch, note[3] - 1.5])
	return notes


## A glockenspiel: a bright bell that rings and fades.
static func _glock(freq: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.5 * RATE))
	for i in out.size():
		var t := float(i) / RATE
		out[i] = (sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.76 * t) * exp(-t * 12.0)) \
				* exp(-t * 6.0) * minf(t / 0.002, 1.0)
	return out


## Accordion reed: a bright, buzzy tone from two slightly detuned reeds (the
## "musette" wobble), with a quick attack and release.
static func _reed(freq: float, length: int, release: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var a := 0.0
	var b := 0.0
	for i in length:
		var t := float(i) / RATE
		a += TAU * freq / RATE
		b += TAU * freq * 1.006 / RATE
		var tone := 0.0
		for h in range(1, 6):
			tone += (sin(a * h) + sin(b * h)) / (h * 1.3)
		var envelope := minf(t / 0.015, 1.0) * clampf((length - i) / (release * RATE + 1.0), 0.0, 1.0)
		out[i] = tone * 0.4 * envelope
	return out


## A round tuba note: warm low harmonics, a soft attack and a short decay.
static func _tuba(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		var t := float(i) / RATE
		var phase := TAU * freq * t
		var tone := sin(phase) + 0.5 * sin(phase * 2.0) + 0.25 * sin(phase * 3.0)
		out[i] = tone * minf(t / 0.03, 1.0) * exp(-t * 3.0) * clampf((length - i) / (0.04 * RATE), 0.0, 1.0)
	return out


## A cowbell: two inharmonic tones that ring for a moment.
static func _cowbell() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.8 * RATE))
	for i in out.size():
		var t := float(i) / RATE
		out[i] = (sin(TAU * 540.0 * t) + 0.7 * sin(TAU * 800.0 * t) + 0.3 * sin(TAU * 1310.0 * t)) \
				* exp(-t * 5.0) * minf(t / 0.002, 1.0)
	return out
