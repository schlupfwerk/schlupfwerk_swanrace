class_name SoftMusic
extends RefCounted
## Calm placeholder music for the menu, synthesized in code: warm pad chords,
## a gentle ukulele arpeggio and a soft bass, slow and relaxed.
## Rendered once in a thread and cached in user://.

const RATE := IslandMusic.RATE
const BPM := 72.0
const CACHE_PATH := "user://music_menu_v1.wav"
## Chords (MIDI notes): Cmaj7, Am7, Fmaj7, G6, two times with a turn at the end.
const CHORDS := [
	[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 64],
	[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 67],
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
	rng.seed = 707
	for b in CHORDS.size():
		var chord: Array = CHORDS[b]
		var start := int(b * bar * RATE)
		# Pad: soft sines that swell in and out across the bar.
		IslandMusic._add(mix, _pad(chord, int(bar * RATE * 1.15)), start, 0.22)
		# Ukulele: a slow arpeggio up the chord, an octave higher.
		for n in 8:
			var note: int = chord[n % 4] + 12
			IslandMusic._add(mix, IslandMusic._pluck(IslandMusic._freq(note), 1.2, rng),
					start + int(n * beat * 0.5 * RATE), 0.28 if n % 4 == 0 else 0.18)
		# Bass: the root, held.
		IslandMusic._add(mix, IslandMusic._bass(IslandMusic._freq(chord[0] - 24)), start, 0.35)
		IslandMusic._add(mix, IslandMusic._bass(IslandMusic._freq(chord[0] - 24)),
				start + int(2.0 * beat * RATE), 0.25)
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


static func _pad(chord: Array, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		var t := float(i) / RATE
		var u := float(i) / length
		var swell := sin(u * PI)
		var value := 0.0
		for note: int in chord:
			var f := IslandMusic._freq(note)
			value += sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t + 0.5)
		out[i] = value * swell * 0.25
	return out
