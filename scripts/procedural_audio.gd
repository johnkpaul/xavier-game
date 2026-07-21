extends Node

## Autoload: generates all sound effects and background music procedurally
## as AudioStreamWAV PCM buffers (no imported audio files), and exposes
## play_sfx()/play_bgm()/unlock_audio() for the rest of the game.

const SAMPLE_RATE := 22050

var _sfx_streams: Dictionary = {}
var _bgm_stream: AudioStreamWAV
var _bgm_player: AudioStreamPlayer
var _unlocked := false
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_PLAYER_POOL_SIZE := 6


func _ready() -> void:
	_build_all_sfx()
	_build_bgm()

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "BGM"
	_bgm_player.stream = _bgm_stream
	add_child(_bgm_player)

	for i in range(SFX_PLAYER_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)


func unlock_audio() -> void:
	if _unlocked:
		return
	_unlocked = true
	# Nudge the browser audio context awake with a near-silent blip.
	play_sfx("unlock")
	play_bgm()


func play_sfx(sfx_name: String) -> void:
	if not _sfx_streams.has(sfx_name):
		return
	var player := _get_free_sfx_player()
	player.stream = _sfx_streams[sfx_name]
	player.play()


func play_bgm() -> void:
	if _bgm_player and not _bgm_player.playing:
		_bgm_player.play()


func stop_bgm() -> void:
	if _bgm_player:
		_bgm_player.stop()


func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]


# ---------------------------------------------------------------------------
# SFX construction
# ---------------------------------------------------------------------------

func _build_all_sfx() -> void:
	_sfx_streams["snap"] = _make_snap_sfx()
	_sfx_streams["bank"] = _make_bank_sfx()
	_sfx_streams["reveal"] = _make_reveal_sfx()
	_sfx_streams["unlock"] = _make_silent_sfx()


func _make_silent_sfx() -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * 0.02)
	var data := PackedByteArray()
	data.resize(frames * 2)
	return _wrap_pcm(data)


## The mouth snapping shut: a low thud followed by a short crunchy noise
## burst - unmistakably "uh oh" but not harsh or scary-loud.
func _make_snap_sfx() -> AudioStreamWAV:
	var duration := 0.35
	var frames := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var prev := 0.0
	for i in range(frames):
		var t := float(i) / frames
		var thud: float = sin(TAU * 90.0 * t) * (1.0 - t) * 0.9
		var raw := rng.randf_range(-1.0, 1.0)
		prev = prev * 0.7 + raw * 0.3
		var crunch_env: float = clampf(1.0 - absf(t - 0.15) * 4.0, 0.0, 1.0)
		var sample: float = thud + prev * crunch_env * 0.8
		_write_sample(data, i, clampf(sample, -1.0, 1.0))
	return _wrap_pcm(data)


## Cheerful ascending arpeggio for a successful bank/run-away.
func _make_bank_sfx() -> AudioStreamWAV:
	var notes := [392.00, 523.25, 659.25, 783.99]
	var note_dur := 0.08
	var frames_per_note := int(SAMPLE_RATE * note_dur)
	var total_frames := frames_per_note * notes.size()
	var data := PackedByteArray()
	data.resize(total_frames * 2)
	for n in range(notes.size()):
		var freq: float = notes[n]
		for i in range(frames_per_note):
			var t := float(i) / frames_per_note
			var env: float = sin(t * PI)
			var sample := sin(TAU * freq * (float(i) / SAMPLE_RATE)) * env
			_write_sample(data, n * frames_per_note + i, sample)
	return _wrap_pcm(data)


## Bigger fanfare for the milestone reveal screen.
func _make_reveal_sfx() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99, 1046.50]
	var note_dur := 0.11
	var frames_per_note := int(SAMPLE_RATE * note_dur)
	var total_frames := frames_per_note * notes.size()
	var data := PackedByteArray()
	data.resize(total_frames * 2)
	for n in range(notes.size()):
		var freq: float = notes[n]
		for i in range(frames_per_note):
			var t := float(i) / frames_per_note
			var env: float = sin(t * PI)
			var sq: float = 1.0 if fmod(TAU * freq * (float(i) / SAMPLE_RATE), TAU) < PI else -1.0
			_write_sample(data, n * frames_per_note + i, sq * env * 0.5)
	return _wrap_pcm(data)


# ---------------------------------------------------------------------------
# BGM construction
# ---------------------------------------------------------------------------

func _build_bgm() -> void:
	# 12-second loop, 110 BPM, playful square-wave melody + triangle bass,
	# major pentatonic (brighter/simpler than a minor key - kept deliberately
	# bouncy since this game's tension comes from the mechanic, not the mood).
	const BPM := 110.0
	const BEAT_SEC := 60.0 / BPM
	const STEP_SEC := BEAT_SEC / 2.0
	const TOTAL_SEC := 12.0
	var total_frames := int(SAMPLE_RATE * TOTAL_SEC)

	# C major pentatonic: C D E G A
	var pentatonic := [261.63, 293.66, 329.63, 392.00, 440.00]
	var melody_pattern := [0, -1, 2, 4, -1, 2, 0, -1, 3, -1, 2, 4, -1, 3, 2, -1]
	var bass_pattern := [0, -1, -1, -1, 4, -1, -1, -1]

	var data := PackedByteArray()
	data.resize(total_frames * 2)

	var steps_total := int(TOTAL_SEC / STEP_SEC)
	var mel_phase := 0.0
	var bass_phase := 0.0

	for step in range(steps_total):
		var start_frame := int(step * STEP_SEC * SAMPLE_RATE)
		var end_frame := int((step + 1) * STEP_SEC * SAMPLE_RATE)
		end_frame = mini(end_frame, total_frames)

		var mel_idx: int = melody_pattern[step % melody_pattern.size()]
		var bass_idx: int = bass_pattern[(step / 2) % bass_pattern.size()]

		var mel_freq := 0.0
		if mel_idx >= 0:
			mel_freq = pentatonic[mel_idx] * 2.0
		var bass_freq := 0.0
		if bass_idx >= 0:
			bass_freq = pentatonic[bass_idx] * 0.5

		var step_frames := end_frame - start_frame
		for i in range(step_frames):
			var frame_idx := start_frame + i
			if frame_idx >= total_frames:
				break
			var local_t := float(i) / step_frames
			var env: float = 1.0
			if local_t > 0.7:
				env = 1.0 - (local_t - 0.7) / 0.3

			var sample := 0.0
			if mel_freq > 0.0:
				mel_phase += mel_freq / SAMPLE_RATE
				var sq: float = 1.0 if fmod(mel_phase, 1.0) < 0.5 else -1.0
				sample += sq * 0.16 * env
			if bass_freq > 0.0:
				bass_phase += bass_freq / SAMPLE_RATE
				var tri_phase := fmod(bass_phase, 1.0)
				var tri: float = 4.0 * abs(tri_phase - 0.5) - 1.0
				sample += tri * 0.20

			var existing := _read_sample(data, frame_idx)
			_write_sample(data, frame_idx, clampf(existing + sample, -1.0, 1.0))

	_bgm_stream = _wrap_pcm(data)
	_bgm_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_bgm_stream.loop_begin = 0
	_bgm_stream.loop_end = total_frames


# ---------------------------------------------------------------------------
# PCM helpers
# ---------------------------------------------------------------------------

func _write_sample(data: PackedByteArray, frame_index: int, value: float) -> void:
	var clamped: float = clampf(value, -1.0, 1.0)
	var s16 := int(clamped * 32767.0)
	var byte_idx := frame_index * 2
	data[byte_idx] = s16 & 0xFF
	data[byte_idx + 1] = (s16 >> 8) & 0xFF


func _read_sample(data: PackedByteArray, frame_index: int) -> float:
	var byte_idx := frame_index * 2
	var lo: int = data[byte_idx]
	var hi: int = data[byte_idx + 1]
	var s16 := lo | (hi << 8)
	if s16 >= 32768:
		s16 -= 65536
	return s16 / 32767.0


func _wrap_pcm(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
