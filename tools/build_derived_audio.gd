extends SceneTree
## Dev tool: makes the looping river sound from the pack's river recording.
## Output goes to res://assets/derived/.
##
##   godot --headless --path . -s res://tools/build_derived_audio.gd
##
## The pack's River.wav fades in from silence and is 3 MB of stereo, so it
## cannot loop as it is. This cuts ten seconds from the middle, mixes it to
## mono, blends the end into the start so the loop has no seam, and brings it
## up to a steady level.
##
## The recording is not kept in the repo; it is read straight from the pack's
## zip, which has to be in the project folder.

const PACK_ZIP := "res://Ninja Adventure - Asset Pack.zip"
const RIVER_ENTRY := "Ninja Adventure - Asset Pack/Audio/Sounds/Ambient/River.wav"
const OUT := "res://assets/derived/river_loop.wav"

## Where the cut starts, how long the loop is, and how much of the end is
## blended into the start (all in seconds).
const CUT_START := 2.0
const LOOP_LENGTH := 10.0
const BLEND := 1.0
## Average level of the result, and the loudest any sample may be.
const TARGET_RMS_DB := -26.0
const MAX_PEAK := 0.9


func _init() -> void:
	var zip := ZIPReader.new()
	if zip.open(ProjectSettings.globalize_path(PACK_ZIP)) != OK:
		push_error("Put the Ninja Adventure zip in the project folder first: " + PACK_ZIP)
		quit(1)
		return
	var wav := zip.read_file(RIVER_ENTRY)
	zip.close()
	if wav.is_empty():
		push_error("The zip has no " + RIVER_ENTRY)
		quit(1)
		return

	var source := _read_wav(wav)
	var rate: int = source.rate
	var mono: PackedFloat32Array = source.samples
	var loop := _seamless(mono, int(CUT_START * rate), int(LOOP_LENGTH * rate), int(BLEND * rate))
	_level(loop)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(loop.size() * 2)
	for i: int in loop.size():
		bytes.encode_s16(i * 2, roundi(clampf(loop[i], -1.0, 1.0) * 32767.0))
	stream.data = bytes
	var err := stream.save_to_wav(OUT)
	if err != OK:
		push_error("Could not save %s (error %d)" % [OUT, err])
		quit(1)
		return
	print("Wrote %s (%.1f s, mono, %d Hz)" % [OUT, loop.size() / float(rate), rate])
	quit()


## Pulls the samples out of a 16-bit PCM WAV file, mixed down to mono.
func _read_wav(file: PackedByteArray) -> Dictionary:
	var channels := 2
	var rate := 44100
	var data_at := -1
	var data_size := 0
	# A WAV is a list of chunks after a 12-byte header: 4-letter name, size, body.
	var at := 12
	while at + 8 <= file.size():
		var chunk := file.slice(at, at + 4).get_string_from_ascii()
		var size := file.decode_u32(at + 4)
		if chunk == "fmt ":
			channels = file.decode_u16(at + 10)
			rate = file.decode_u32(at + 12)
			assert(file.decode_u16(at + 22) == 16, "Expected a 16-bit WAV")
		elif chunk == "data":
			data_at = at + 8
			data_size = size
		at += 8 + size + (size % 2)
	assert(data_at >= 0, "WAV has no data chunk")

	var frames := data_size / (2 * channels)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	for i: int in frames:
		var sum := 0
		for c: int in channels:
			sum += file.decode_s16(data_at + (i * channels + c) * 2)
		samples[i] = sum / (32768.0 * channels)
	return {"rate": rate, "samples": samples}


## Cuts `length` samples starting at `start`, with the stretch that follows the
## cut faded in over its beginning. The cut's last sample then leads straight
## into what its first samples mostly are, so repeating it has no click.
func _seamless(samples: PackedFloat32Array, start: int, length: int, blend: int) -> PackedFloat32Array:
	assert(start + length + blend <= samples.size(), "Recording is too short for this cut")
	var out := samples.slice(start, start + length)
	for i: int in blend:
		var t := float(i) / blend
		# Equal-power fade: the two halves stay the same loudness added together.
		out[i] = samples[start + i] * sin(t * PI / 2.0) + samples[start + length + i] * cos(t * PI / 2.0)
	return out


## Scales the samples to the target average level without clipping.
func _level(samples: PackedFloat32Array) -> void:
	var sum := 0.0
	var peak := 0.0
	for v: float in samples:
		sum += v * v
		peak = maxf(peak, absf(v))
	var rms := sqrt(sum / samples.size())
	var gain := minf(db_to_linear(TARGET_RMS_DB) / rms, MAX_PEAK / peak)
	for i: int in samples.size():
		samples[i] *= gain
