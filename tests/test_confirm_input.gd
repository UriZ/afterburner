extends SceneTree

## Unit tests for ConfirmInput — shared restart/start key detection (#38).
## Run with: godot --headless --script res://tests/test_confirm_input.gd

const ConfirmInput := preload("res://scripts/ui/confirm_input.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== ConfirmInput Tests ===")

	test_enter_key_confirms()
	test_space_key_confirms()
	test_other_key_does_not_confirm()
	test_start_action_confirms()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func test_enter_key_confirms() -> void:
	print("\ntest_enter_key_confirms:")
	assert_true(ConfirmInput.is_pressed(_key_event(KEY_ENTER)), "Enter key is recognized as confirm")


func test_space_key_confirms() -> void:
	print("\ntest_space_key_confirms:")
	assert_true(ConfirmInput.is_pressed(_key_event(KEY_SPACE)), "Space key is recognized as confirm")


func test_other_key_does_not_confirm() -> void:
	print("\ntest_other_key_does_not_confirm:")
	assert_true(not ConfirmInput.is_pressed(_key_event(KEY_A)), "Unrelated key (A) is not confirm")


func test_start_action_confirms() -> void:
	print("\ntest_start_action_confirms:")
	var event := InputEventAction.new()
	event.action = "start"
	event.pressed = true
	assert_true(ConfirmInput.is_pressed(event), "'start' action is recognized as confirm")
