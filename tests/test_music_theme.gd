extends SceneTree

## Tests for the gameplay music theme wiring (#138).
##
## The import flags are pinned here deliberately: if loop_mode or the loop range
## is lost on a reimport, nothing errors — the track simply stops after 27.8s,
## or develops an audible gap at the wrap. That is a silent regression, so it
## gets a mechanical assertion.
##
## Uses _initialize(), not _init(): the theme is reached through the AudioManager
## autoload, which does not exist until after the engine's autoload bootstrap
## (#118).
## Run with: godot --headless --script res://tests/test_music_theme.gd

var _pass_count := 0
var _fail_count := 0


var _frame := 0


func _initialize() -> void:
	print("=== Music Theme Tests (#138) ===")
	# Asset-level checks need no autoload and can run immediately.
	test_theme_asset_imports()
	test_theme_loops_seamlessly()


## The autoload NODES exist at _initialize() time but their _ready() has not run
## (the Music bus does not exist yet), and absolute "/root/..." paths do not
## resolve until the tree has iterated once. So everything that touches
## AudioManager or GameState waits for a frame. Probed, not assumed.
func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false

	test_phase_mirror_matches()
	test_music_bus_sits_below_sfx()
	test_theme_silent_on_title()
	test_theme_starts_in_gameplay()
	test_theme_survives_respawn()
	test_theme_stops_on_game_over()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	# Zero assertions is a failure, not a clean run (#118).
	quit(1 if _fail_count > 0 or _pass_count == 0 else 0)
	return true


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func assert_eq(a: Variant, b: Variant, message: String) -> void:
	assert_true(a == b, "%s (got %s, expected %s)" % [message, str(a), str(b)])


## Phase values mirrored from game_state.gd. The bare `GameState` identifier
## cannot be used here: it is an autoload, and this script is COMPILED before
## the engine registers autoloads, so referencing it fails with "Identifier not
## found" regardless of _initialize() (#118). test_phase_mirror_matches() below
## asserts the mirror against the real enum so it cannot drift silently.
const PHASE_TITLE := 0
const PHASE_PLAYING := 1
const PHASE_GAME_OVER := 2
const PHASE_BONUS_STAGE := 3


func _audio() -> Node:
	return root.get_node_or_null("AudioManager")


func _state() -> Node:
	return root.get_node_or_null("GameState")


func test_phase_mirror_matches() -> void:
	print("\ntest_phase_mirror_matches:")
	var gs := _state()
	if gs == null:
		assert_true(false, "GameState autoload present")
		return
	var constants: Dictionary = gs.get_script().get_script_constant_map()
	var phase: Dictionary = constants.get("Phase", {})
	assert_true(not phase.is_empty(), "GameState exposes its Phase enum")
	assert_eq(phase.get("TITLE", -1), PHASE_TITLE, "TITLE mirrors")
	assert_eq(phase.get("PLAYING", -1), PHASE_PLAYING, "PLAYING mirrors")
	assert_eq(phase.get("GAME_OVER", -1), PHASE_GAME_OVER, "GAME_OVER mirrors")
	assert_eq(phase.get("BONUS_STAGE", -1), PHASE_BONUS_STAGE, "BONUS_STAGE mirrors")
	# AudioManager mirrors the same two values so it does not have to name the
	# GameState autoload at compile time. Drift here would silently stop the
	# music starting, so it is asserted rather than trusted.
	var audio := _audio()
	if audio == null:
		assert_true(false, "AudioManager autoload present")
		return
	var am_constants: Dictionary = audio.get_script().get_script_constant_map()
	assert_eq(am_constants.get("PHASE_PLAYING", -1), phase.get("PLAYING", -2),
		"AudioManager.PHASE_PLAYING matches GameState")
	assert_eq(am_constants.get("PHASE_BONUS_STAGE", -1), phase.get("BONUS_STAGE", -2),
		"AudioManager.PHASE_BONUS_STAGE matches GameState")


func test_theme_asset_imports() -> void:
	print("\ntest_theme_asset_imports:")
	var stream := load("res://assets/audio/music/main_theme.wav")
	assert_true(stream != null, "theme asset loads")
	assert_true(stream is AudioStreamWAV, "theme imports as AudioStreamWAV")
	if stream is AudioStreamWAV:
		assert_true(stream.stereo, "theme is stereo")
		# PCM, not the lossy QOA the importer defaults to — a music bed that has
		# to loop cleanly should not be re-quantised.
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "theme is 16-bit PCM")
		assert_true(absf(stream.get_length() - 27.826) < 0.01,
			"theme is the authored 27.83s loop (got %.3fs)" % stream.get_length())


func test_theme_loops_seamlessly() -> void:
	print("\ntest_theme_loops_seamlessly:")
	var stream := load("res://assets/audio/music/main_theme.wav") as AudioStreamWAV
	if stream == null:
		assert_true(false, "theme loaded for loop check")
		return
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD,
		"loop_mode is FORWARD (import flag edit/loop_mode=2)")
	assert_eq(stream.loop_begin, 0, "loop starts at sample 0")
	# 27.826077s x 44100 = 1227130 samples, so the last index is 1227129. The
	# loop must span the WHOLE file or the tail is silently dropped each pass.
	assert_eq(stream.loop_end, 1227129, "loop runs to the final sample")


func test_music_bus_sits_below_sfx() -> void:
	print("\ntest_music_bus_sits_below_sfx:")
	var bus := AudioServer.get_bus_index("Music")
	assert_true(bus != -1, "a dedicated Music bus exists")
	if bus == -1:
		return
	var music_db: float = AudioServer.get_bus_volume_db(bus)
	assert_true(absf(music_db - (-12.0)) < 0.01, "Music bus is at -12 dB (got %.1f)" % music_db)
	# SFX players are created at -6 dB; music must sit under them so weapon and
	# explosion cues stay audible over a continuous bed.
	assert_true(music_db < -6.0, "music is quieter than the -6 dB SFX level")
	assert_eq(AudioServer.get_bus_send(bus), "Master", "Music bus routes to Master")


func test_theme_silent_on_title() -> void:
	print("\ntest_theme_silent_on_title:")
	var audio := _audio()
	if audio == null:
		assert_true(false, "AudioManager autoload present")
		return
	_state().phase = PHASE_TITLE
	audio.stop_theme()
	audio._update_theme_for_phase()
	assert_true(not audio.is_theme_playing(), "theme does not play on the title screen")


func test_theme_starts_in_gameplay() -> void:
	print("\ntest_theme_starts_in_gameplay:")
	var audio := _audio()
	if audio == null:
		assert_true(false, "AudioManager autoload present")
		return
	_state().phase = PHASE_PLAYING
	audio._update_theme_for_phase()
	assert_true(audio.is_theme_playing(), "theme starts when phase becomes PLAYING")


func test_theme_survives_respawn() -> void:
	print("\ntest_theme_survives_respawn:")
	var audio := _audio()
	if audio == null:
		assert_true(false, "AudioManager autoload present")
		return
	_state().phase = PHASE_PLAYING
	audio._update_theme_for_phase()
	# Seek well into the track first. Without this the before/after positions are
	# both ~0 within a single frame, and a restart would be indistinguishable
	# from no restart — the assertion would pass on a broken implementation.
	audio.seek_theme(12.0)
	# _audio() returns Node, so := cannot infer through the call (#118).
	var before: float = audio.theme_position()
	assert_true(before > 10.0, "seeked into the track before the death (%.2fs)" % before)
	# A death that leaves lives remaining: lose_life() does NOT change phase, so
	# the music must keep running rather than restart from the top.
	var gs := _state()
	gs.lives = 3
	var survived: bool = gs.lose_life()
	assert_true(survived, "player still has lives after one death")
	audio._update_theme_for_phase()
	assert_true(audio.is_theme_playing(), "theme still playing after losing a life")
	var after: float = audio.theme_position()
	assert_true(after > 10.0,
		"theme did NOT restart from the top on respawn (%.2fs -> %.2fs)" % [before, after])
	# A bonus stage is still gameplay — it must not retrigger the track either.
	_state().phase = PHASE_BONUS_STAGE
	audio._update_theme_for_phase()
	assert_true(audio.is_theme_playing(), "theme continues through a bonus stage")


func test_theme_stops_on_game_over() -> void:
	print("\ntest_theme_stops_on_game_over:")
	var audio := _audio()
	if audio == null:
		assert_true(false, "AudioManager autoload present")
		return
	_state().phase = PHASE_PLAYING
	audio._update_theme_for_phase()
	_state().phase = PHASE_GAME_OVER
	audio._update_theme_for_phase()
	assert_true(not audio.is_theme_playing(), "theme stops on GAME OVER")
