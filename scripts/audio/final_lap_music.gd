class_name FinalLapMusic
extends RefCounted
## Placeholder "final lap" music, synthesized in code: the island sound, but
## faster and pumped up (drums, driving bass, quick strums and a rising lead).
## Rendered once in a thread and cached in user://.

const RATE := IslandMusic.RATE
const BPM := 150.0
const CACHE_PATH := "user://music_final_lap_v1.wav"
const PROGRESSION := ["D", "A", "Bm", "G", "D", "A", "Bm", "G",
		"G", "A", "D", "Bm", "G", "A", "A", "A"]
const VOICINGS := {
	"D": [69, 62, 66, 74],
	"A": [69, 64, 69, 73],
	"Bm": [71, 66, 71, 74],
	"G": [67, 62, 71, 74],
}
const ROOTS := {"D": 38, "A": 45, "Bm": 47, "G": 43}


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
	rng.seed = 909

	# Ukulele: driving eighth-note strums, down-up.
	var strums := {}
	for chord: String in VOICINGS:
		for down: bool in [true, false]:
			strums[chord + str(down)] = IslandMusic._strum(VOICINGS[chord], down, rng)
	var kick := _kick()
	var snare := _snare(rng)
	var hat := IslandMusic._shaker(rng)
	for b in PROGRESSION.size():
		var chord: String = PROGRESSION[b]
		var bar_start := b * bar
		for e in 8:
			var down := e % 2 == 0
			IslandMusic._add(mix, strums[chord + str(down)], int((bar_start + e * beat * 0.5) * RATE),
					0.5 if down else 0.36)
		# Drums: kick on 1 and 3 (and the "and" of 4), snare on 2 and 4, hats on 16ths.
		for k in [0.0, 2.0, 3.5]:
			IslandMusic._add(mix, kick, int((bar_start + k * beat) * RATE), 0.9)
		for s in [1.0, 3.0]:
			IslandMusic._add(mix, snare, int((bar_start + s * beat) * RATE), 0.55)
		for h in 16:
			IslandMusic._add(mix, hat, int((bar_start + h * beat * 0.25) * RATE),
					0.14 if h % 2 == 0 else 0.08)
		# Bass: bouncing octaves on every eighth.
		var root: int = ROOTS[chord]
		for e in 8:
			IslandMusic._add(mix, IslandMusic._bass(IslandMusic._freq(root + (12 if e % 2 else 0))),
					int((bar_start + e * beat * 0.5) * RATE), 0.42)
		# Lead: a quick rising arpeggio of the chord, an octave up.
		var notes: Array = VOICINGS[chord]
		var sorted := notes.duplicate()
		sorted.sort()
		for n in 8:
			var note: int = sorted[n % sorted.size()] + 12 + (12 if n >= 4 else 0)
			var length := int(beat * 0.5 * RATE)
			IslandMusic._add(mix, IslandMusic._steel(IslandMusic._freq(note), IslandMusic._freq(note),
					length), int((bar_start + n * beat * 0.5) * RATE), 0.16)

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


static func _kick() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.3 * RATE))
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(140.0, 45.0, minf(t / 0.12, 1.0)) / RATE
		out[i] = sin(phase) * exp(-t * 11.0)
	return out


static func _snare(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.18 * RATE))
	var slow := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		slow = lerpf(slow, noise, 0.25)
		out[i] = ((noise - slow) * 0.9 + sin(TAU * 190.0 * t) * 0.4) * exp(-t * 22.0)
	return out
