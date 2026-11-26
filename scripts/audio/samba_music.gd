class_name SambaMusic
extends RefCounted
## Music for the Rio Seafront, composed and synthesized in code (no audio
## files, no third-party rights): a generic, original samba loop. A surdo
## marking the strong second beat, a tamborim in the classic syncopated
## pattern, a ganzá on every sixteenth, a strummed cavaquinho with the same
## syncopation, a walking bass and a flute melody on top.
## Rendered once in a background thread and cached in user://.

const RATE := 22050
const BPM := 100.0
const CACHE_PATH := "user://music_rio_beach_v1.wav"

## One chord per 2/4 bar (two beats); 32 bars, so the loop is 64 beats.
const PROGRESSION := ["C", "C", "A7", "A7", "Dm", "Dm", "G7", "G7",
		"C", "C", "C7", "C7", "F", "Fm", "C", "G7",
		"Em", "A7", "Dm", "Dm", "G7", "G7", "C", "A7",
		"Dm", "G7", "Em", "A7", "Dm", "G7", "C", "G7"]
## Cavaquinho voicings (MIDI), high and bright.
const VOICINGS := {
	"C": [72, 76, 79, 84], "C7": [72, 76, 79, 82], "A7": [69, 73, 76, 79],
	"Dm": [69, 74, 77, 81], "G7": [71, 74, 77, 79], "F": [72, 77, 81, 84],
	"Fm": [72, 77, 80, 84], "Em": [71, 76, 79, 83],
}
const ROOTS := {"C": 36, "C7": 36, "A7": 45, "Dm": 38, "G7": 43, "F": 41, "Fm": 41, "Em": 40}
## Sixteenths within a 2/4 bar (0-7) where the tamborim and the cavaquinho hit.
const SYNCOPATION := [0, 2, 3, 5, 6]
## Flute melody: [bar, sixteenth, MIDI note, length in sixteenths].
const MELODY := [
	[0, 0, 79, 3], [0, 3, 76, 3], [0, 6, 79, 2], [1, 0, 81, 6], [1, 6, 79, 2],
	[2, 0, 76, 3], [2, 3, 73, 3], [2, 6, 76, 2], [3, 0, 79, 8],
	[4, 0, 77, 3], [4, 3, 74, 3], [4, 6, 77, 2], [5, 0, 81, 6], [5, 6, 79, 2],
	[6, 0, 77, 2], [6, 2, 76, 2], [6, 4, 74, 2], [6, 6, 71, 2], [7, 0, 74, 8],
	[8, 0, 76, 2], [8, 2, 79, 2], [8, 4, 84, 4], [9, 0, 83, 2], [9, 2, 81, 2], [9, 4, 79, 4],
	[10, 0, 76, 3], [10, 3, 79, 3], [10, 6, 82, 2], [11, 0, 81, 8],
	[12, 0, 81, 3], [12, 3, 77, 3], [12, 6, 72, 2], [13, 0, 80, 6], [13, 6, 77, 2],
	[14, 0, 76, 4], [14, 4, 79, 4], [15, 0, 74, 8],
	[16, 0, 79, 3], [16, 3, 83, 3], [16, 6, 79, 2], [17, 0, 76, 3], [17, 3, 79, 3], [17, 6, 81, 2],
	[18, 0, 77, 6], [18, 6, 74, 2], [19, 0, 77, 4], [19, 4, 81, 4],
	[20, 0, 79, 2], [20, 2, 77, 2], [20, 4, 74, 2], [20, 6, 71, 2], [21, 0, 67, 8],
	[22, 0, 72, 3], [22, 3, 76, 3], [22, 6, 79, 2], [23, 0, 81, 3], [23, 3, 79, 3], [23, 6, 76, 2],
	[24, 0, 77, 3], [24, 3, 81, 3], [24, 6, 84, 2], [25, 0, 83, 6], [25, 6, 79, 2],
	[26, 0, 79, 3], [26, 3, 76, 3], [26, 6, 71, 2], [27, 0, 73, 6], [27, 6, 76, 2],
	[28, 0, 74, 2], [28, 2, 77, 2], [28, 4, 81, 4], [29, 0, 79, 3], [29, 3, 77, 3], [29, 6, 74, 2],
	[30, 0, 72, 8], [31, 0, 74, 2], [31, 2, 76, 2], [31, 4, 77, 2], [31, 6, 79, 2],
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
	var sixteenth := 60.0 / BPM / 4.0
	var bar := sixteenth * 8.0
	var total := int(bar * PROGRESSION.size() * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1958

	var surdo_open := _drum(58.0, 0.5, 6.0)
	var surdo_muted := _drum(62.0, 0.12, 25.0)
	var tamborim := _click(1150.0, 0.06, 70.0)
	var shake := IslandMusic._shaker(rng)
	var strums := {}
	for chord: String in VOICINGS:
		strums[chord] = _strum(VOICINGS[chord], rng)

	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		var at := b * bar
		# Surdo: muted on the first beat, open and strong on the second.
		_put(mix, surdo_muted, at, 0.45)
		_put(mix, surdo_open, at + 4.0 * sixteenth, 0.9)
		_put(mix, surdo_muted, at + 7.0 * sixteenth, 0.25)
		for s in 8:
			_put(mix, shake, at + s * sixteenth, 0.16 if s % 4 == 3 or s % 4 == 2 else 0.09)
		# Tamborim and cavaquinho play the syncopation; the tamborim varies every other bar.
		for s: int in SYNCOPATION:
			if b % 2 == 1 and s == 0:
				continue
			_put(mix, tamborim, at + s * sixteenth, 0.22)
			_put(mix, strums[chord], at + s * sixteenth, 0.3 if s == 0 else 0.22)
		# Bass: root on the beat, fifth on the "and" of beat two, leading tone at the end.
		var root: int = ROOTS[chord]
		_put(mix, IslandMusic._bass(IslandMusic._freq(root)), at, 0.55)
		_put(mix, IslandMusic._bass(IslandMusic._freq(root + 7)), at + 4.0 * sixteenth, 0.45)
		_put(mix, IslandMusic._bass(IslandMusic._freq(root + 12)), at + 6.0 * sixteenth, 0.3)

	for note: Array in MELODY:
		var start: float = note[0] * bar + note[1] * sixteenth
		var length := int(note[3] * sixteenth * RATE)
		_put(mix, _flute(IslandMusic._freq(note[2]), length), start, 0.3)

	return _to_stream(mix, total)


static func _strum(notes: Array, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.35 * RATE))
	for k in notes.size():
		var pluck := IslandMusic._pluck(IslandMusic._freq(notes[k]), 0.35, rng)
		# Short, muted strums: the cavaquinho is percussive.
		for i in pluck.size():
			pluck[i] *= exp(-float(i) / RATE * 9.0)
		IslandMusic._add(out, pluck, int(k * 0.006 * RATE), 0.8)
	return out


## A low drum: a sine that drops in pitch, with a soft attack.
static func _drum(freq: float, seconds: float, decay: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * freq * (1.0 + 0.6 * exp(-t * 30.0)) / RATE
		out[i] = sin(phase) * exp(-t * decay) * minf(t / 0.003, 1.0)
	return out


## A short, bright hit (tamborim): a high tone with a little noise.
static func _click(freq: float, seconds: float, decay: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in out.size():
		var t := float(i) / RATE
		out[i] = (0.7 * sin(TAU * freq * t) + 0.3 * rng.randf_range(-1.0, 1.0)) * exp(-t * decay)
	return out


## A breathy flute: a sine with a touch of octave, vibrato and air.
static func _flute(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq)
	var phase := 0.0
	var air := 0.0
	for i in length:
		var t := float(i) / RATE
		var vibrato := 1.0 + 0.005 * sin(TAU * 5.0 * t) * clampf(t / 0.25, 0.0, 1.0)
		phase += TAU * freq * vibrato / RATE
		air = lerpf(air, rng.randf_range(-1.0, 1.0), 0.3)
		var envelope := minf(t / 0.03, 1.0) * clampf((length - i) / (0.05 * RATE), 0.0, 1.0)
		out[i] = (sin(phase) + 0.18 * sin(phase * 2.0) + 0.05 * air) * envelope
	return out


static func _put(mix: PackedFloat32Array, part: PackedFloat32Array, seconds: float, gain: float) -> void:
	IslandMusic._add(mix, part, int(seconds * RATE), gain)


## Normalizes the mix into a looping 16-bit stream.
static func _to_stream(mix: PackedFloat32Array, total: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(total * 2)
	var peak := 0.0001
	for i in total:
		peak = maxf(peak, absf(mix[i]))
	var gain := 0.85 / peak
	for i in total:
		data.encode_s16(i * 2, int(clampf(mix[i] * gain, -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = Sfx.pad_loop(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = total
	return stream
