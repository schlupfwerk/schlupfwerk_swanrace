class_name IslandMusic
extends RefCounted
## Placeholder music for the Desert Island, composed and synthesized in code
## (no audio files, no third-party rights): a Hawaiian-style loop with a
## strummed ukulele (Karplus-Strong plucks), a sliding steel guitar, a soft
## bass and a shaker, over the classic I-VI7-II7-V7 island turnaround.
## Rendered once in a background thread and cached in user://.
## The project owner will replace it with the final track.

const RATE := 22050
const BPM := 92.0
const CACHE_PATH := "user://music_desert_island_v1.wav"

## One chord per bar (16 bars).
const PROGRESSION := ["C", "C", "A7", "A7", "D7", "D7", "G7", "G7",
		"C", "F", "C", "A7", "D7", "G7", "C", "G7"]
## Ukulele voicings (MIDI notes, strings G C E A, re-entrant tuning).
const VOICINGS := {
	"C": [67, 60, 64, 72],
	"F": [69, 60, 65, 69],
	"A7": [67, 61, 64, 69],
	"D7": [69, 62, 66, 72],
	"G7": [67, 62, 65, 71],
}
const ROOTS := {"C": 36, "F": 41, "A7": 45, "D7": 38, "G7": 43}
## Island strum: down, down-up, up-down-up (beats within the bar, down?).
const STRUM := [[0.0, true], [1.0, true], [1.5, false], [2.5, false], [3.0, true], [3.5, false]]
## Steel guitar melody: [bar, beat, MIDI note, length in beats].
const MELODY := [
	[0, 0.0, 76, 2.0], [0, 2.0, 79, 2.0], [1, 0.0, 76, 3.0], [1, 3.0, 74, 1.0],
	[2, 0.0, 73, 2.0], [2, 2.0, 76, 2.0], [3, 0.0, 81, 3.0],
	[4, 0.0, 78, 2.0], [4, 2.0, 74, 2.0], [5, 0.0, 72, 4.0],
	[6, 0.0, 71, 2.0], [6, 2.0, 74, 2.0], [7, 0.0, 77, 2.0], [7, 2.0, 74, 2.0],
	[8, 0.0, 72, 2.0], [8, 2.0, 76, 2.0], [9, 0.0, 77, 2.0], [9, 2.0, 81, 2.0],
	[10, 0.0, 79, 3.0], [10, 3.0, 76, 1.0], [11, 0.0, 73, 4.0],
	[12, 0.0, 74, 2.0], [12, 2.0, 78, 2.0], [13, 0.0, 77, 2.0], [13, 2.0, 74, 2.0],
	[14, 0.0, 72, 4.0], [15, 0.0, 71, 2.0], [15, 2.0, 74, 2.0],
]


## Loads the cached loop, or renders it (slow: call from a thread).
static func load_or_render() -> AudioStreamWAV:
	if FileAccess.file_exists(CACHE_PATH):
		var cached := AudioStreamWAV.load_from_file(CACHE_PATH)
		if cached:
			cached.loop_mode = AudioStreamWAV.LOOP_FORWARD
			cached.loop_end = cached.data.size() / 2
			return cached
	var stream := render()
	stream.save_to_wav(CACHE_PATH)
	return stream


static func render() -> AudioStreamWAV:
	var beat := 60.0 / BPM
	var bar := beat * 4.0
	var total := int(bar * PROGRESSION.size() * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808

	# Ukulele: render each chord's down and up strum once, then place copies.
	var strums := {}
	for chord: String in VOICINGS:
		for down: bool in [true, false]:
			strums[chord + str(down)] = _strum(VOICINGS[chord], down, rng)
	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		for hit: Array in STRUM:
			var start := int((b * bar + hit[0] * beat) * RATE)
			_add(mix, strums[chord + str(hit[1])], start, 0.55 if hit[1] else 0.38)

	# Bass on beats 1 and 3: root, then fifth.
	for b in PROGRESSION.size():
		var root: int = ROOTS[PROGRESSION[b]]
		_add(mix, _bass(_freq(root)), int(b * bar * RATE), 0.5)
		_add(mix, _bass(_freq(root + 7)), int((b * bar + 2.0 * beat) * RATE), 0.42)

	# Steel guitar: sliding into each note, with vibrato.
	var previous := 0.0
	for note: Array in MELODY:
		var start := int((note[0] * bar + note[1] * beat) * RATE)
		var length := int(note[3] * beat * RATE)
		var target := _freq(note[2])
		_add(mix, _steel(previous if previous > 0.0 else target, target, length), start, 0.28)
		previous = target

	# Shaker on every eighth, accented off-beats.
	var shake := _shaker(rng)
	for n in PROGRESSION.size() * 8:
		_add(mix, shake, int(n * beat * 0.5 * RATE), 0.1 if n % 2 == 0 else 0.16)

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
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = total
	return stream


static func _strum(notes: Array, down: bool, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.9 * RATE))
	var order := notes.duplicate()
	if not down:
		order.reverse()
	for k in order.size():
		var pluck := _pluck(_freq(order[k]), 0.85, rng)
		_add(out, pluck, int(k * 0.012 * RATE), 1.0 if k < 3 else 0.8)
	return out


## Karplus-Strong plucked string.
static func _pluck(freq: float, seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var period := maxi(int(RATE / freq), 2)
	var ring := PackedFloat32Array()
	ring.resize(period)
	for i in period:
		ring[i] = rng.randf_range(-1.0, 1.0)
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	var index := 0
	for i in out.size():
		var next := (index + 1) % period
		var value := 0.5 * (ring[index] + ring[next]) * 0.996
		out[i] = ring[index]
		ring[index] = value
		index = next
	return out


static func _bass(freq: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.6 * RATE))
	for i in out.size():
		var t := float(i) / RATE
		out[i] = (sin(TAU * freq * t) + 0.3 * sin(TAU * 2.0 * freq * t)) \
				* exp(-t * 4.0) * minf(t / 0.01, 1.0)
	return out


static func _steel(from_freq: float, to_freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var phase := 0.0
	for i in length:
		var t := float(i) / RATE
		var slide := clampf(t / 0.12, 0.0, 1.0)
		var vibrato := 1.0 + 0.006 * sin(TAU * 5.5 * t) * clampf(t / 0.3, 0.0, 1.0)
		phase += TAU * lerpf(from_freq, to_freq, slide * slide * (3.0 - 2.0 * slide)) * vibrato / RATE
		var tone := sin(phase) + 0.35 * sin(phase * 2.0) + 0.12 * sin(phase * 3.0)
		var envelope := minf(t / 0.04, 1.0) * clampf((length - i) / (0.08 * RATE), 0.0, 1.0)
		out[i] = tone * envelope * (0.85 + 0.15 * exp(-t * 2.0))
	return out


static func _shaker(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.07 * RATE))
	var slow := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		slow = lerpf(slow, noise, 0.2)
		out[i] = (noise - slow) * minf(t / 0.008, 1.0) * exp(-t * 60.0)
	return out


static func _add(mix: PackedFloat32Array, part: PackedFloat32Array, start: int, gain: float) -> void:
	var count := mini(part.size(), mix.size() - start)
	for i in count:
		mix[start + i] += part[i] * gain


static func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)
