class_name VictoryMusic
extends RefCounted
## Race-over placeholder music for the podium, synthesized in code: a bright
## fanfare-like ukulele strum, bouncy bass and a little melody, looping.
## Rendered once in a thread and cached in user://.

const RATE := IslandMusic.RATE
const BPM := 112.0
const CACHE_PATH := "user://music_podium_v1.wav"
## C, F, G, C / Am, F, G, C (MIDI notes).
const CHORDS := [
	[60, 64, 67], [65, 69, 72], [67, 71, 74], [60, 64, 67],
	[57, 60, 64], [65, 69, 72], [67, 71, 74], [60, 64, 67],
]
## Melody, one note per beat (0 = rest).
const MELODY := [
	72, 76, 79, 76, 77, 81, 84, 81, 79, 83, 86, 83, 84, 0, 79, 0,
	76, 72, 69, 72, 77, 76, 74, 72, 74, 79, 83, 79, 84, 84, 0, 0,
]


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
	var total := int(bar * CHORDS.size() * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	for b in CHORDS.size():
		var chord: Array = CHORDS[b]
		var start := int(b * bar * RATE)
		# Strum on every beat, with a quick upstroke on the off-beat.
		for k in 8:
			var at := start + int(k * beat * 0.5 * RATE)
			var strength := 0.3 if k % 2 == 0 else 0.15
			for n in chord.size():
				IslandMusic._add(mix, IslandMusic._pluck(IslandMusic._freq(chord[n]), 0.5, rng),
						at + n * int(0.012 * RATE), strength)
		# Bouncy bass: root and fifth.
		for k in 4:
			var note: int = chord[0] - 24 + (7 if k % 2 == 1 else 0)
			IslandMusic._add(mix, IslandMusic._bass(IslandMusic._freq(note)),
					start + int(k * beat * RATE), 0.3)
	for k in MELODY.size():
		var note: int = MELODY[k]
		if note > 0:
			IslandMusic._add(mix, IslandMusic._pluck(IslandMusic._freq(note), 0.9, rng),
					int(k * beat * RATE), 0.45)
	var data := PackedByteArray()
	data.resize(total * 2)
	var peak := 0.0001
	for i in total:
		peak = maxf(peak, absf(mix[i]))
	var gain := 0.7 / peak
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
