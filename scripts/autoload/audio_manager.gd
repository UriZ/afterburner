extends Node

## AudioManager autoload singleton.
## Generates and plays procedural chip-tune music and sound effects.
## All audio is synthesized at runtime — no external audio files.

const SAMPLE_RATE := 22050.0
const MUSIC_BPM := 150.0
const MUSIC_BUFFER_SIZE := 512

## Note frequencies (octave 4 base)
const NOTE_FREQ := {
	"C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61,
	"G3": 196.00, "A3": 220.00, "B3": 246.94,
	"C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23,
	"G4": 392.00, "A4": 440.00, "B4": 493.88,
	"C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46,
	"G5": 783.99, "A5": 880.00, "B5": 987.77,
	"R": 0.0,  # rest
}

## Track definitions — each is an array of [note_name, duration_in_beats]
## "Final Take Off" — upbeat, fast
var _track_final_take_off: Array = [
	["E5", 0.5], ["E5", 0.5], ["R", 0.5], ["E5", 0.5],
	["R", 0.5], ["C5", 0.5], ["E5", 1.0],
	["G5", 1.0], ["R", 1.0], ["G4", 1.0], ["R", 1.0],
	["C5", 1.0], ["R", 0.5], ["G4", 0.5], ["R", 1.0],
	["E4", 1.0], ["R", 0.5], ["A4", 1.0], ["B4", 1.0],
	["A4", 0.5], ["A4", 0.5], ["G4", 0.5], ["E5", 0.5],
	["G5", 0.5], ["A5", 1.0], ["F5", 0.5], ["G5", 0.5],
	["R", 0.5], ["E5", 1.0], ["C5", 0.5], ["D5", 0.5], ["B4", 1.0],
]

## "Super Stripe" — driving, rhythmic (bass-heavy pattern)
var _track_super_stripe: Array = [
	["A4", 0.5], ["A4", 0.5], ["A4", 0.5], ["R", 0.5],
	["A4", 0.5], ["G4", 0.5], ["A4", 1.0],
	["D5", 0.5], ["D5", 0.5], ["R", 0.5], ["A4", 0.5],
	["G4", 1.0], ["E4", 1.0],
	["A4", 0.5], ["A4", 0.5], ["A4", 0.5], ["R", 0.5],
	["A4", 0.5], ["G4", 0.5], ["A4", 1.0],
	["E5", 1.0], ["D5", 0.5], ["C5", 0.5], ["A4", 1.0], ["R", 1.0],
]

## "After Burner" — intense, action (arpeggiated runs)
var _track_after_burner: Array = [
	["E4", 0.25], ["G4", 0.25], ["B4", 0.25], ["E5", 0.25],
	["D5", 0.5], ["B4", 0.5], ["G4", 1.0],
	["E4", 0.25], ["A4", 0.25], ["C5", 0.25], ["E5", 0.25],
	["D5", 0.5], ["C5", 0.5], ["A4", 1.0],
	["E4", 0.25], ["G4", 0.25], ["B4", 0.25], ["E5", 0.25],
	["G5", 0.5], ["E5", 0.5], ["D5", 0.5], ["B4", 0.5],
	["C5", 1.0], ["R", 0.5], ["B4", 0.5], ["A4", 0.5], ["G4", 0.5], ["E4", 1.0],
]

## Bass lines for each track
var _bass_final_take_off: Array = [
	["C3", 2.0], ["G3", 2.0], ["C3", 2.0], ["G3", 2.0],
	["A3", 2.0], ["E3", 2.0], ["A3", 2.0], ["E3", 2.0],
]

var _bass_super_stripe: Array = [
	["A3", 1.0], ["A3", 1.0], ["D3", 1.0], ["D3", 1.0],
	["A3", 1.0], ["A3", 1.0], ["E3", 1.0], ["A3", 1.0],
]

var _bass_after_burner: Array = [
	["E3", 1.0], ["E3", 1.0], ["A3", 1.0], ["A3", 1.0],
	["E3", 1.0], ["E3", 1.0], ["C3", 1.0], ["E3", 1.0],
]

var _tracks: Array = []
var _bass_lines: Array = []

## Music playback state
var _music_player: AudioStreamPlayer = null
var _music_playback: AudioStreamGeneratorPlayback = null
var _current_track_index: int = 0
var _music_playing: bool = false

## Lead voice state
var _lead_note_index: int = 0
var _lead_sample_pos: float = 0.0  # phase accumulator for lead
var _lead_samples_remaining: int = 0
var _lead_freq: float = 0.0

## Bass voice state
var _bass_note_index: int = 0
var _bass_sample_pos: float = 0.0
var _bass_samples_remaining: int = 0
var _bass_freq: float = 0.0

## SFX players pool
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8


func _ready() -> void:
	_tracks = [_track_final_take_off, _track_super_stripe, _track_after_burner]
	_bass_lines = [_bass_final_take_off, _bass_super_stripe, _bass_after_burner]

	# Set up music player with AudioStreamGenerator
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.1
	_music_player.stream = stream
	add_child(_music_player)

	# Set up SFX player pool
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = -6.0
		add_child(player)
		_sfx_players.append(player)


func _process(_delta: float) -> void:
	if _music_playing and _music_playback != null:
		_fill_music_buffer()


## Start playing the selected music track. track_index: 0, 1, or 2.
func play_music(track_index: int) -> void:
	_current_track_index = clampi(track_index, 0, _tracks.size() - 1)
	_lead_note_index = 0
	_lead_sample_pos = 0.0
	_lead_samples_remaining = 0
	_lead_freq = 0.0
	_bass_note_index = 0
	_bass_sample_pos = 0.0
	_bass_samples_remaining = 0
	_bass_freq = 0.0

	_music_player.play()
	_music_playback = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_music_playing = true


func stop_music() -> void:
	_music_playing = false
	if _music_player.playing:
		_music_player.stop()
	_music_playback = null


## SFX methods — each generates a short procedural sound

func play_vulcan_fire() -> void:
	_play_sfx(_generate_vulcan_fire())


func play_missile_launch() -> void:
	_play_sfx(_generate_missile_launch())


func play_explosion() -> void:
	_play_sfx(_generate_explosion())


func play_lockon_beep() -> void:
	_play_sfx(_generate_lockon_beep())


# ---------------------------------------------------------------------------
# Music buffer filling
# ---------------------------------------------------------------------------

func _fill_music_buffer() -> void:
	var to_fill := _music_playback.get_frames_available()
	if to_fill <= 0:
		return

	var track: Array = _tracks[_current_track_index]
	var bass: Array = _bass_lines[_current_track_index]
	var beats_per_sec := MUSIC_BPM / 60.0

	for i in to_fill:
		# Advance lead note if needed
		if _lead_samples_remaining <= 0:
			var note_data: Array = track[_lead_note_index]
			var note_name: String = note_data[0]
			var duration_beats: float = note_data[1]
			_lead_freq = NOTE_FREQ.get(note_name, 0.0)
			_lead_samples_remaining = int(duration_beats / beats_per_sec * SAMPLE_RATE)
			_lead_note_index = (_lead_note_index + 1) % track.size()

		# Advance bass note if needed
		if _bass_samples_remaining <= 0:
			var bass_data: Array = bass[_bass_note_index]
			var bass_name: String = bass_data[0]
			var bass_dur: float = bass_data[1]
			_bass_freq = NOTE_FREQ.get(bass_name, 0.0)
			_bass_samples_remaining = int(bass_dur / beats_per_sec * SAMPLE_RATE)
			_bass_note_index = (_bass_note_index + 1) % bass.size()

		# Generate lead sample (square wave with duty cycle modulation)
		var lead_sample := 0.0
		if _lead_freq > 0.0:
			var period := SAMPLE_RATE / _lead_freq
			var phase := fmod(_lead_sample_pos, period) / period
			# Square wave with 50% duty cycle
			lead_sample = 0.3 if phase < 0.5 else -0.3
			# Apply simple envelope (fade out at end of note)
			var note_progress := 1.0 - float(_lead_samples_remaining) / (SAMPLE_RATE * 0.5)
			if note_progress > 0.8:
				lead_sample *= (1.0 - note_progress) * 5.0

		# Generate bass sample (triangle wave for warmer bass)
		var bass_sample := 0.0
		if _bass_freq > 0.0:
			var period := SAMPLE_RATE / _bass_freq
			var phase := fmod(_bass_sample_pos, period) / period
			# Triangle wave
			bass_sample = (2.0 * absf(2.0 * phase - 1.0) - 1.0) * 0.2

		var mixed := lead_sample + bass_sample
		_music_playback.push_frame(Vector2(mixed, mixed))

		_lead_sample_pos += 1.0
		_bass_sample_pos += 1.0
		_lead_samples_remaining -= 1
		_bass_samples_remaining -= 1


# ---------------------------------------------------------------------------
# SFX generation — returns AudioStreamWAV with procedural audio
# ---------------------------------------------------------------------------

func _generate_vulcan_fire() -> AudioStreamWAV:
	## Short burst of filtered white noise (50ms)
	var duration := 0.05
	var num_samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono

	var prev := 0.0
	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - t / duration  # linear decay
		# White noise with simple low-pass filter
		var noise := randf_range(-1.0, 1.0)
		var filtered := prev * 0.7 + noise * 0.3
		prev = filtered
		var sample := filtered * envelope * 0.6
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.data = data
	return wav


func _generate_missile_launch() -> AudioStreamWAV:
	## Rising pitch sweep (200ms)
	var duration := 0.2
	var num_samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var phase := 0.0
	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var progress := t / duration
		var envelope := 1.0 - progress * 0.5  # gentle decay
		# Frequency sweeps from 200Hz to 1200Hz
		var freq := 200.0 + progress * 1000.0
		phase += freq / SAMPLE_RATE
		# Sawtooth wave for buzzy missile sound
		var sample := (fmod(phase, 1.0) * 2.0 - 1.0) * envelope * 0.4
		# Add some noise for thrust
		sample += randf_range(-0.1, 0.1) * envelope
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.data = data
	return wav


func _generate_explosion() -> AudioStreamWAV:
	## Noise burst with falling pitch (300ms)
	var duration := 0.3
	var num_samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var phase := 0.0
	var prev := 0.0
	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var progress := t / duration
		# Envelope: sharp attack, exponential decay
		var envelope := exp(-progress * 4.0)
		# Falling pitch from 150Hz to 40Hz
		var freq := 150.0 - progress * 110.0
		phase += freq / SAMPLE_RATE
		# Mix square wave with noise for crunchy explosion
		var square := 0.5 if fmod(phase, 1.0) < 0.5 else -0.5
		var noise := randf_range(-1.0, 1.0)
		# Low-pass the noise
		var filtered_noise := prev * 0.6 + noise * 0.4
		prev = filtered_noise
		var sample := (square * 0.3 + filtered_noise * 0.7) * envelope * 0.7
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.data = data
	return wav


func _generate_lockon_beep() -> AudioStreamWAV:
	## Short pure tone beep (100ms, ~1000Hz)
	var duration := 0.1
	var freq := 1000.0
	var num_samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var progress := t / duration
		# Envelope with quick attack and release
		var envelope := 1.0
		if progress < 0.05:
			envelope = progress / 0.05
		elif progress > 0.8:
			envelope = (1.0 - progress) / 0.2
		# Pure sine tone
		var sample := sin(t * freq * TAU) * envelope * 0.4
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.data = data
	return wav


# ---------------------------------------------------------------------------
# SFX playback from pool
# ---------------------------------------------------------------------------

func _play_sfx(stream: AudioStreamWAV) -> void:
	# Find a free player from the pool
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	# All busy — steal the first one
	_sfx_players[0].stream = stream
	_sfx_players[0].play()
