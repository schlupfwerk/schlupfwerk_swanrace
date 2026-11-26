class_name SpaceMusic
extends RefCounted
## Music for the Sidereal Circuit, composed and synthesized in code (no audio
## files, no third-party rights): an original loop in the style of French
## house. Four-on-the-floor kick, claps and open hi-hats, a bouncing octave
## bass, filtered disco chords that "breathe" with the kick (sidechain) while
## the filter slowly opens and closes, and a square-wave robot arpeggio.
## Rendered once in a background thread and cached in user://.

const RATE := 22050
const BPM := 122.0
const CACHE_PATH := "user://music_sidereal_v1.wav"

## Two bars per chord; 16 bars.
const PROGRESSION := ["Dm7", "Dm7", "G7", "G7", "Cmaj7", "Cmaj7", "Am7", "Am7",
		"Dm7", "Dm7", "G7", "G7", "Em7", "Em7", "A7", "A7"]
const VOICINGS := {
	"Dm7": [62, 65, 69, 72], "G7": [62, 65, 67, 71], "Cmaj7": [60, 64, 67, 71],
	"Am7": [60, 64, 67, 69], "Em7": [62, 64, 67, 71], "A7": [61, 64, 67, 69],
}
const ROOTS := {"Dm7": 38, "G7": 43, "Cmaj7": 36, "Am7": 45, "Em7": 40, "A7": 45}
## Chord stabs on these sixteenths of each bar (a syncopated disco pattern).
const STABS := [0, 3, 6, 8, 10, 13]
## Arpeggio over the chord tones (indices into the voicing, +12 = an octave up).
const ARP := [0, 2, 3, 14, 3, 2, 12, 2]


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
	var sixteenth := beat / 4.0
	var bar := beat * 4.0
	var total := int(bar * PROGRESSION.size() * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var chords := PackedFloat32Array()
	chords.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1997

	var kick := _kick()
	var clap := _noise_hit(rng, 0.18, 22.0, 0.35)
	var hat := _noise_hit(rng, 0.09, 35.0, 0.9)
	var stab_cache := {}
	for chord: String in VOICINGS:
		var out := PackedFloat32Array()
		out.resize(int(sixteenth * 1.6 * RATE))
		for note: int in VOICINGS[chord]:
			IslandMusic._add(out, _saw(IslandMusic._freq(note), out.size()), 0, 0.3)
		stab_cache[chord] = out

	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		var at := b * bar
		var root: int = ROOTS[chord]
		for q in 4:
			SambaMusic._put(mix, kick, at + q * beat, 0.95)
			SambaMusic._put(mix, hat, at + (q + 0.5) * beat, 0.22)
			if q % 2 == 1:
				SambaMusic._put(mix, clap, at + q * beat, 0.4)
		# Octave bass on the off-beat sixteenths.
		for s in 16:
			if s % 2 == 1:
				var note := root + (12 if s % 4 == 3 else 0)
				SambaMusic._put(mix, _bass(IslandMusic._freq(note), int(sixteenth * 0.9 * RATE)),
						at + s * sixteenth, 0.4)
		for s: int in STABS:
			IslandMusic._add(chords, stab_cache[chord], int((at + s * sixteenth) * RATE), 1.0)
		# The robot arpeggio comes in on the second half of the loop.
		if b >= 8:
			var voicing: Array = VOICINGS[chord]
			for s in 16:
				var step: int = ARP[s % ARP.size()]
				var note: int = voicing[step % 12] + 12 + (12 if step >= 12 else 0)
				SambaMusic._put(mix, _square(IslandMusic._freq(note), int(sixteenth * 0.7 * RATE)),
						at + s * sixteenth, 0.12)

	# Filter sweep over 8 bars and the kick pumping the chords.
	var low := 0.0
	var loop_seconds := float(total) / RATE
	for i in total:
		var t := float(i) / RATE
		var sweep := 0.5 - 0.5 * cos(TAU * t / (loop_seconds * 0.5))
		var cutoff := lerpf(350.0, 3200.0, sweep)
		var k := 1.0 - exp(-TAU * cutoff / RATE)
		low += (chords[i] - low) * k
		var since_kick := fmod(t, beat) / beat
		var pump := clampf(since_kick * 2.2, 0.15, 1.0)
		mix[i] += low * pump * 0.6
	return SambaMusic._to_stream(mix, total)


static func _kick() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.32 * RATE))
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (48.0 + 110.0 * exp(-t * 32.0)) / RATE
		out[i] = sin(phase) * exp(-t * 9.0)
	return out


## Filtered noise burst: a clap (darker) or a hi-hat (brighter).
static func _noise_hit(rng: RandomNumberGenerator, seconds: float, decay: float,
		brightness: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	var slow := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		slow = lerpf(slow, noise, 1.0 - brightness)
		out[i] = (noise - slow * brightness) * exp(-t * decay) * minf(t / 0.002, 1.0)
	return out


## A plain sawtooth with a short envelope (filtered later).
static func _saw(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var phase := 0.0
	for i in length:
		phase = fmod(phase + freq / RATE, 1.0)
		var envelope := minf(float(i) / (0.004 * RATE), 1.0) * clampf((length - i) / (0.03 * RATE), 0.0, 1.0)
		out[i] = (2.0 * phase - 1.0) * envelope
	return out


## A round, punchy synth bass: sine plus a little saw, gently plucked.
static func _bass(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var phase := 0.0
	for i in length:
		var t := float(i) / RATE
		phase = fmod(phase + freq / RATE, 1.0)
		var tone := sin(TAU * phase) + 0.25 * (2.0 * phase - 1.0)
		out[i] = tone * minf(t / 0.004, 1.0) * exp(-t * 6.0) * clampf((length - i) / (0.01 * RATE), 0.0, 1.0)
	return out


## A thin square wave for the robot arpeggio.
static func _square(freq: float, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var phase := 0.0
	for i in length:
		var t := float(i) / RATE
		phase = fmod(phase + freq / RATE, 1.0)
		out[i] = (1.0 if phase < 0.35 else -1.0) * minf(t / 0.003, 1.0) * exp(-t * 10.0)
	return out
