class_name DemoTone
extends RefCounted
## Builds simple sine tones for the demo's generated sounds.

const MIX_RATE := 22050
const FADE_SECONDS := 0.01


## 16-bit mono PCM at 22050 Hz playing frequencies in sequence, note_seconds
## each, at volume (0..1). Each note fades in and out over 10 ms so edges don't click.
static func make(frequencies: PackedFloat32Array, note_seconds: float, volume: float) -> AudioStreamWAV:
	var note_samples := maxi(int(note_seconds * MIX_RATE), 1)
	var fade_samples := maxi(int(FADE_SECONDS * MIX_RATE), 1)
	var data := PackedByteArray()
	data.resize(frequencies.size() * note_samples * 2)
	var offset := 0
	for frequency in frequencies:
		for i in note_samples:
			var envelope := minf(1.0, minf(float(i) / fade_samples, float(note_samples - 1 - i) / fade_samples))
			var sample := sin(TAU * frequency * i / MIX_RATE) * volume * maxf(envelope, 0.0)
			data.encode_s16(offset, clampi(roundi(sample * 32767.0), -32768, 32767))
			offset += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
