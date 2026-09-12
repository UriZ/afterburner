extends SceneTree

## Unit tests for BlockFont.
## Run with: godot --headless --script res://tests/test_block_font.gd

const BlockFont := preload("res://scripts/ui/block_font.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("=== BlockFont Tests ===")

	test_hud_vocabulary_glyphs_defined()
	test_glyphs_are_5x7()
	test_text_width_matches_length()
	test_text_width_empty_is_zero()
	test_unknown_char_has_space_fallback()

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


func test_hud_vocabulary_glyphs_defined() -> void:
	print("\ntest_hud_vocabulary_glyphs_defined:")
	# Every letter used by the HUD's fixed vocabulary (SCORE, HI, STAGE, SPEED) plus digits.
	var required := "SCOREHITAGPD0123456789 "
	var all_defined := true
	for ch in required:
		if not BlockFont.GLYPHS.has(ch):
			all_defined = false
			print("    Missing glyph: '%s'" % ch)
	assert_true(all_defined, "All HUD vocabulary glyphs are defined")


func test_glyphs_are_5x7() -> void:
	print("\ntest_glyphs_are_5x7:")
	var all_valid := true
	for ch in BlockFont.GLYPHS.keys():
		var glyph: Array = BlockFont.GLYPHS[ch]
		if glyph.size() != BlockFont.ROWS:
			all_valid = false
			print("    Glyph '%s' has %d rows, expected %d" % [ch, glyph.size(), BlockFont.ROWS])
			continue
		for row in glyph:
			if String(row).length() != BlockFont.COLS:
				all_valid = false
				print("    Glyph '%s' row '%s' has wrong length" % [ch, row])
	assert_true(all_valid, "Every glyph is exactly %dx%d" % [BlockFont.COLS, BlockFont.ROWS])


func test_text_width_matches_length() -> void:
	print("\ntest_text_width_matches_length:")
	# 3 chars @ px=2, spacing=1 -> 3*(5+1)-1 = 17 cols * 2px = 34
	assert_eq(BlockFont.text_width(3, 2.0), 34.0, "3-char width at px=2")
	# 1 char @ px=4 -> 5 cols * 4px = 20 (no trailing spacing)
	assert_eq(BlockFont.text_width(1, 4.0), 20.0, "1-char width at px=4")


func test_text_width_empty_is_zero() -> void:
	print("\ntest_text_width_empty_is_zero:")
	assert_eq(BlockFont.text_width(0, 5.0), 0.0, "Zero-length text has zero width")


func test_unknown_char_has_space_fallback() -> void:
	print("\ntest_unknown_char_has_space_fallback:")
	# '?' is not in the HUD vocabulary; _draw_char falls back to GLYPHS[" "]
	# via Dictionary.get(), which we verify directly (draw_rect calls in
	# BlockFont.draw_text require a live _draw() context, unavailable here).
	var fallback: Array = BlockFont.GLYPHS.get("?", BlockFont.GLYPHS[" "])
	assert_eq(fallback, BlockFont.GLYPHS[" "], "Unknown glyph falls back to blank space glyph")
