extends SceneTree

## Unit tests for game_over_screen.gd (#38, #110).
## Run with: godot --headless --script res://tests/test_game_over_screen.gd

const BlockFont := preload("res://scripts/ui/block_font.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== GameOverScreen Tests ===")

	test_block_font_covers_display_text()
	test_auto_restart_within_five_seconds()
	test_prompt_delay_before_auto_restart()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func test_block_font_covers_display_text() -> void:
	print("\ntest_block_font_covers_display_text:")
	# A missing glyph silently renders as a blank space (see block_font.gd
	# _draw_char fallback) instead of erroring, so this must be checked
	# explicitly rather than relying on a runtime crash.
	for text in ["GAME OVER", "PRESS ENTER"]:
		for ch in text.to_upper():
			if ch == " ":
				continue
			assert_true(BlockFont.GLYPHS.has(ch), "BlockFont has glyph for '%s' (in \"%s\")" % [ch, text])


func test_auto_restart_within_five_seconds() -> void:
	print("\ntest_auto_restart_within_five_seconds:")
	var script := load("res://scripts/ui/game_over_screen.gd")
	var screen := Control.new()
	screen.set_script(script)
	assert_true(screen.AUTO_RESTART_DELAY <= 5.0,
		"Auto-restart delay meets the 5s acceptance criterion (%.1fs)" % screen.AUTO_RESTART_DELAY)
	screen.free()


func test_prompt_delay_before_auto_restart() -> void:
	print("\ntest_prompt_delay_before_auto_restart:")
	var script := load("res://scripts/ui/game_over_screen.gd")
	var screen := Control.new()
	screen.set_script(script)
	assert_true(screen.PROMPT_DELAY < screen.AUTO_RESTART_DELAY,
		"Prompt appears before auto-restart fires")
	screen.free()
