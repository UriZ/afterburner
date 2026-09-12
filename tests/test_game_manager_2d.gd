extends SceneTree

## Unit tests for enemy spawn pacing (#103, #50).
## game_manager_2d.gd itself cannot be instantiated in test context due to the
## GameState autoload (same limitation documented in test_stage_manager.gd), so
## the pacing math lives in the dependency-free scripts/game/spawn_pacing.gd
## and is tested directly here.
## Run with: godot --headless --script res://tests/test_game_manager_2d.gd

const SpawnPacing := preload("res://scripts/game/spawn_pacing.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== Enemy Spawn Pacing Tests ===")

	test_max_on_screen_enemies_is_capped_low()
	test_dispense_interval_easy_stage_clamps_to_max()
	test_dispense_interval_hard_stage_clamps_to_min()
	test_dispense_interval_mid_stage_scales()

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
	# but high enough the screen never reads as empty (#50).
	assert_true(SpawnPacing.MAX_ON_SCREEN_ENEMIES >= 3, "cap allows at least 3 enemies (%d)" % SpawnPacing.MAX_ON_SCREEN_ENEMIES)
	assert_true(SpawnPacing.MAX_ON_SCREEN_ENEMIES <= 6, "cap stays low enough to avoid overwhelm (%d)" % SpawnPacing.MAX_ON_SCREEN_ENEMIES)


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
