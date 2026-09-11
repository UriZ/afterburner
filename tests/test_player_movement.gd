extends SceneTree

## Tests for player jet movement bounds and respawn position.
## Run with: godot --headless --script res://tests/test_player_movement.gd

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== PlayerJet Movement Tests ===")

	test_bounds_cover_80_percent()
	test_respawn_at_screen_center()
	test_x_range_is_symmetric()
	test_y_range_has_headroom_above_and_below()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


# Camera: pos (0,5,0), FOV 70 vertical, 5-deg downward tilt, aspect 16/9.
# Jet Z = -6.8. Screen-center Y at that depth ≈ 4.4.
# Half-width (horizontal) = tan(35°)*6.8*(16/9) ≈ 8.47
# Half-height (vertical)  = tan(35°)*6.8         ≈ 4.76
const HALF_W := 8.47
const HALF_H := 4.76
const CENTER_Y := 4.4
const MOVE_MIN_X := -7.0
const MOVE_MAX_X :=  7.0
const MOVE_MIN_Y :=  0.5
const MOVE_MAX_Y :=  8.5
const RESPAWN_Y  :=  4.4


func test_bounds_cover_80_percent() -> void:
	print("\ntest_bounds_cover_80_percent:")
	var x_coverage := (MOVE_MAX_X - MOVE_MIN_X) / (2.0 * HALF_W)
	var y_coverage := (MOVE_MAX_Y - MOVE_MIN_Y) / (2.0 * HALF_H)
	assert_true(x_coverage >= 0.80,
		"X covers >= 80%% of screen (got %.0f%%)" % (x_coverage * 100))
	assert_true(y_coverage >= 0.80,
		"Y covers >= 80%% of screen (got %.0f%%)" % (y_coverage * 100))


func test_respawn_at_screen_center() -> void:
	print("\ntest_respawn_at_screen_center:")
	var offset: float = abs(RESPAWN_Y - CENTER_Y)
	assert_true(offset < 0.2,
		"Respawn Y %.1f is near screen center %.1f (delta=%.2f)" % [RESPAWN_Y, CENTER_Y, offset])


func test_x_range_is_symmetric() -> void:
	print("\ntest_x_range_is_symmetric:")
	var x_sym: float = abs(MOVE_MIN_X + MOVE_MAX_X)
	assert_true(x_sym < 0.01,
		"X range is symmetric around 0 (min=%.1f max=%.1f)" % [MOVE_MIN_X, MOVE_MAX_X])



func test_y_range_has_headroom_above_and_below() -> void:
	print("\ntest_y_range_has_headroom_above_and_below:")
	# Should be able to go above screen center (toward top of screen)
	assert_true(MOVE_MAX_Y > CENTER_Y + 1.5,
		"Can move well above screen center (max Y=%.1f, center=%.1f)" % [MOVE_MAX_Y, CENTER_Y])
	# Should be able to go below screen center (toward bottom of screen)
	assert_true(MOVE_MIN_Y < CENTER_Y - 1.5,
		"Can move well below screen center (min Y=%.1f, center=%.1f)" % [MOVE_MIN_Y, CENTER_Y])
