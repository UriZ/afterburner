extends SceneTree

## Unit tests for enemy spawn pacing (#103, #50) and stage-timer phase gating
## (#111). Spawn pacing math lives in the dependency-free
## scripts/game/spawn_pacing.gd and is tested directly. Phase gating tests
## instantiate GameManager2D itself, which references the GameState autoload
## by bare name. This script IS the SceneTree entry point under `--script`,
## so game_manager_2d.gd must be loaded with `load()` from inside
## _initialize() (NOT top-level `preload()`, which compiles before the
## engine's autoload bootstrap has run and fails with "Identifier not found:
## GameState").
## Run with: godot --headless --script res://tests/test_game_manager_2d.gd

const SpawnPacing := preload("res://scripts/game/spawn_pacing.gd")

var _pass_count := 0
var _fail_count := 0


func _initialize() -> void:
	print("=== Enemy Spawn Pacing Tests ===")

	test_max_on_screen_enemies_is_capped_low()
	test_dispense_interval_easy_stage_clamps_to_max()
	test_dispense_interval_hard_stage_clamps_to_min()
	test_dispense_interval_mid_stage_scales()

	print("\n=== Stage Timer Phase Gating Tests (#111) ===")
	test_stage_timer_halts_when_game_over()
	test_stage_timer_advances_when_playing()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func assert_eq(a: Variant, b: Variant, message: String) -> void:
	assert_true(a == b, "%s (got %s, expected %s)" % [message, str(a), str(b)])


# --- Density cap ---

func test_max_on_screen_enemies_is_capped_low() -> void:
	print("\ntest_max_on_screen_enemies_is_capped_low:")
	# Must be low enough that a full wave burst can't fill the screen (#103),
	# but high enough to hit the reference's 4-6 simultaneous enemies (#100).
	assert_true(SpawnPacing.MAX_ON_SCREEN_ENEMIES >= 6, "cap reaches the reference's 4-6 band (%d)" % SpawnPacing.MAX_ON_SCREEN_ENEMIES)
	assert_true(SpawnPacing.MAX_ON_SCREEN_ENEMIES <= 8, "cap stays low enough to avoid overwhelm (%d)" % SpawnPacing.MAX_ON_SCREEN_ENEMIES)


# --- Dispense interval clamping ---

func test_dispense_interval_easy_stage_clamps_to_max() -> void:
	print("\ntest_dispense_interval_easy_stage_clamps_to_max:")
	# Stage 1's spawn_interval (1.5) * 0.5 = 0.75, above MAX_DISPENSE_INTERVAL
	var result: float = SpawnPacing.dispense_interval_for(1.5)
	assert_eq(result, SpawnPacing.MAX_DISPENSE_INTERVAL, "easy stage clamps to MAX_DISPENSE_INTERVAL")


func test_dispense_interval_hard_stage_clamps_to_min() -> void:
	print("\ntest_dispense_interval_hard_stage_clamps_to_min:")
	# Stage 23's spawn_interval (0.25) * 0.5 = 0.125, below MIN_DISPENSE_INTERVAL
	var result: float = SpawnPacing.dispense_interval_for(0.25)
	assert_eq(result, SpawnPacing.MIN_DISPENSE_INTERVAL, "hardest stage clamps to MIN_DISPENSE_INTERVAL")


func test_dispense_interval_mid_stage_scales() -> void:
	print("\ntest_dispense_interval_mid_stage_scales:")
	# Stage 7's spawn_interval (0.7) * 0.5 = 0.35, inside the clamp band
	var result: float = SpawnPacing.dispense_interval_for(0.7)
	assert_true(absf(result - 0.35) < 0.001, "mid-difficulty stage scales linearly (got %.3f)" % result)


# --- Stage timer phase gating (#111) ---
# GameManager2D references the GameState autoload by bare name, which is only
# resolvable once the engine has finished its normal autoload bootstrap. This
# script IS the SceneTree entry point under `--script`, so it can't reference
# that bare name itself at compile time (see test_title_screen.gd for the
# same constraint) — fetch the live singleton node via /root instead.
# Phase enum values mirror game_state.gd: TITLE=0, PLAYING=1, GAME_OVER=2, BONUS_STAGE=3.
const PHASE_PLAYING := 1
const PHASE_GAME_OVER := 2

func _game_state() -> Node:
	return get_root().get_node("GameState")


func _make_manager() -> Node:
	var mgr := Node.new()
	mgr.set_script(load("res://scripts/game/game_manager_2d.gd"))
	get_root().add_child(mgr)
	if mgr._stage_timer == 0.0:
		mgr._ready()
	return mgr


func test_stage_timer_halts_when_game_over() -> void:
	print("\ntest_stage_timer_halts_when_game_over:")
	var gs := _game_state()
	var mgr := _make_manager()
	mgr._is_announcing = false
	mgr._stage_timer = 0.01
	# Nodes added during _initialize() aren't inside the tree until the
	# engine processes its first frame (get_tree() is null until then, see
	# test_player_jet_2d.gd's _ready() note for the same quirk). Disable
	# spawning so _process() doesn't reach the tree-dependent dispense path —
	# this test only cares about the stage timer / phase gate.
	mgr._spawning_enabled = false
	gs.phase = PHASE_GAME_OVER
	var stage_before: int = gs.current_stage
	mgr._process(1.0)
	assert_eq(gs.current_stage, stage_before, "Stage does not advance while phase is GAME_OVER")
	mgr.queue_free()
	gs.reset()


func test_stage_timer_advances_when_playing() -> void:
	print("\ntest_stage_timer_advances_when_playing:")
	var gs := _game_state()
	var mgr := _make_manager()
	mgr._is_announcing = false
	mgr._stage_timer = 0.01
	# Nodes added during _initialize() aren't inside the tree until the
	# engine processes its first frame (get_tree() is null until then, see
	# test_player_jet_2d.gd's _ready() note for the same quirk). Disable
	# spawning so _process() doesn't reach the tree-dependent dispense path —
	# this test only cares about the stage timer / phase gate.
	mgr._spawning_enabled = false
	gs.phase = PHASE_PLAYING
	var stage_before: int = gs.current_stage
	mgr._process(1.0)
	assert_eq(gs.current_stage, stage_before + 1, "Stage advances while phase is PLAYING")
	mgr.queue_free()
	gs.reset()
