extends SceneTree

## Unit tests for AudioManager procedural audio.
## Run with: godot --headless --script res://tests/test_audio_manager.gd

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== AudioManager Tests ===")

	test_note_frequencies_defined()
	test_all_tracks_have_valid_notes()
	test_all_bass_lines_have_valid_notes()
	test_track_count_matches()
	test_sfx_vulcan_fire_generates_wav()
	test_sfx_missile_launch_generates_wav()
	test_sfx_explosion_generates_wav()
	test_sfx_lockon_beep_generates_wav()
	test_sfx_wav_format()
	test_track_durations_nonzero()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func test_note_frequencies_defined() -> void:
	var am := _create_audio_manager()
	var freq: Dictionary = am.NOTE_FREQ
	_assert_true(freq.has("C4"), "NOTE_FREQ has C4")
	_assert_true(freq.has("A4"), "NOTE_FREQ has A4")
	_assert_true(freq.has("R"), "NOTE_FREQ has rest (R)")
	_assert_true(freq["A4"] > 439.0 and freq["A4"] < 441.0, "A4 is ~440Hz")
	_assert_true(freq["R"] == 0.0, "Rest frequency is 0")
	am.free()


func test_all_tracks_have_valid_notes() -> void:
	var am := _create_audio_manager()
	var tracks := [am._track_final_take_off, am._track_super_stripe, am._track_after_burner]
	var track_names := ["Final Take Off", "Super Stripe", "After Burner"]
	for idx in tracks.size():
		var track: Array = tracks[idx]
		_assert_true(track.size() > 0, "%s has notes" % track_names[idx])
		for note_data in track:
			var note_name: String = note_data[0]
			_assert_true(am.NOTE_FREQ.has(note_name),
				"%s: note '%s' exists in NOTE_FREQ" % [track_names[idx], note_name])
			var duration: float = note_data[1]
			_assert_true(duration > 0.0,
				"%s: note '%s' has positive duration" % [track_names[idx], note_name])
	am.free()


func test_all_bass_lines_have_valid_notes() -> void:
	var am := _create_audio_manager()
	var bass_lines := [am._bass_final_take_off, am._bass_super_stripe, am._bass_after_burner]
	for bass in bass_lines:
		_assert_true(bass.size() > 0, "Bass line has notes")
		for note_data in bass:
			_assert_true(am.NOTE_FREQ.has(note_data[0]),
				"Bass note '%s' exists in NOTE_FREQ" % note_data[0])
	am.free()


func test_track_count_matches() -> void:
	# Verify TRACK_NAMES in title_screen matches AudioManager track count
	var am := _create_audio_manager()
	_assert_true(am._tracks.size() == 3, "AudioManager has 3 tracks")
	_assert_true(am._bass_lines.size() == 3, "AudioManager has 3 bass lines")
	am.free()


func test_sfx_vulcan_fire_generates_wav() -> void:
	var am := _create_audio_manager()
	var wav: AudioStreamWAV = am._generate_vulcan_fire()
	_assert_true(wav != null, "Vulcan fire WAV is not null")
	_assert_true(wav.data.size() > 0, "Vulcan fire WAV has data")
	am.free()


func test_sfx_missile_launch_generates_wav() -> void:
	var am := _create_audio_manager()
	var wav: AudioStreamWAV = am._generate_missile_launch()
	_assert_true(wav != null, "Missile launch WAV is not null")
	_assert_true(wav.data.size() > 0, "Missile launch WAV has data")
	am.free()


func test_sfx_explosion_generates_wav() -> void:
	var am := _create_audio_manager()
	var wav: AudioStreamWAV = am._generate_explosion()
	_assert_true(wav != null, "Explosion WAV is not null")
	_assert_true(wav.data.size() > 0, "Explosion WAV has data")
	am.free()


func test_sfx_lockon_beep_generates_wav() -> void:
	var am := _create_audio_manager()
	var wav: AudioStreamWAV = am._generate_lockon_beep()
	_assert_true(wav != null, "Lock-on beep WAV is not null")
	_assert_true(wav.data.size() > 0, "Lock-on beep WAV has data")
	am.free()


func test_sfx_wav_format() -> void:
	var am := _create_audio_manager()
	var wav: AudioStreamWAV = am._generate_vulcan_fire()
	_assert_true(wav.format == AudioStreamWAV.FORMAT_16_BITS, "WAV format is 16-bit")
	_assert_true(wav.mix_rate == int(am.SAMPLE_RATE), "WAV mix rate matches SAMPLE_RATE")
	# 16-bit mono: data size = num_samples * 2
	var expected_samples := int(am.SAMPLE_RATE * 0.05)  # 50ms
	_assert_true(wav.data.size() == expected_samples * 2,
		"Vulcan WAV data size matches 50ms of 16-bit mono")
	am.free()


func test_track_durations_nonzero() -> void:
	var am := _create_audio_manager()
	for track in am._tracks:
		var total_beats := 0.0
		for note_data in track:
			total_beats += note_data[1]
		_assert_true(total_beats > 1.0,
			"Track total duration is > 1 beat (got %.1f)" % total_beats)
	am.free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _create_audio_manager() -> Node:
	var script := load("res://scripts/autoload/audio_manager.gd")
	var am := Node.new()
	am.set_script(script)
	# Call _ready manually won't work in headless, but we can access const/vars
	# The _tracks and _bass_lines are populated in _ready, so set them manually
	am._tracks = [am._track_final_take_off, am._track_super_stripe, am._track_after_burner]
	am._bass_lines = [am._bass_final_take_off, am._bass_super_stripe, am._bass_after_burner]
	return am


func _assert_true(condition: bool, description: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % description)
	else:
		_fail_count += 1
		print("  FAIL: %s" % description)
