extends SceneTree

## Tests for HUD parity with the arcade (#129).
##
## These pin the MEASURED layout constants against the reference extents. They
## are deliberately source-level rather than rendering-level: the acceptance
## criteria are verified from a median composite of real captures (that work is
## on the issue), but a composite needs a capture rig and takes minutes, so what
## belongs in the suite is the cheap half — that nobody "tidies" a measured
## fraction into a round number later. Every number here is an AC.
##
## Uses _initialize() + load(), not _init() + preload() (#118).
## Run with: godot --headless --script res://tests/test_hud_layout.gd

var _pass_count := 0
var _fail_count := 0

## Reference extents as x0,x1,y0,y1 fractions, from the amendment's re-measured
## table. Tolerance is the AC's own +/-2 %W and +/-2 %H.
const TOL := 0.02
const REF := {
	"SCORE_EMBLEM": [0.051, 0.223, 0.067, 0.110],
	"SCORE_DIGITS": [0.327, 0.443, 0.071, 0.102],
	"HIT_EMBLEM": [0.504, 0.595, 0.071, 0.104],
	"HIT_DIGITS": [0.631, 0.665, 0.071, 0.102],
	"SCOPE_RECT": [0.773, 0.876, 0.104, 0.217],
	"SPEED_LABEL": [0.052, 0.131, 0.898, 0.921],
	"SPEED_MODE": [0.130, 0.169, 0.894, 0.929],
	"BAR_MARK_0": [0.175, 0.187, 0.898, 0.919],
	"BAR_MARK_2": [0.312, 0.325, 0.898, 0.919],
	"BAR_MARK_3": [0.385, 0.397, 0.898, 0.919],
	"STAGE_LABEL": [0.426, 0.513, 0.892, 0.925],
	"STAGE_DIGIT": [0.580, 0.590, 0.892, 0.923],
	"LIFE_ROW": [0.060, 0.096, 0.942, 0.960],
}


func _initialize() -> void:
	print("=== HUD Layout Tests (#129) ===")

	var hc: GDScript = load("res://scripts/ui/hud_canvas.gd")
	test_element_extents(hc)
	test_life_icon_height_cap(hc)
	test_missile_readout_model(hc)
	test_missile_row_anchor_and_extent(hc)
	test_speed_bar_span(hc)
	test_core_colours(hc)
	test_no_hi_readout()
	test_scope_box_is_unconditional()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	# Zero assertions is a failure, not a clean run (#118).
	quit(1 if _fail_count > 0 or _pass_count == 0 else 0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		print("  FAIL: %s" % message)


func assert_near(value: float, target: float, tol: float, message: String) -> void:
	assert_true(absf(value - target) <= tol,
		"%s (got %.4f, expected %.4f +/-%.4f)" % [message, value, target, tol])


## AC 6: every element within +/-2 %W and +/-2 %H of the reference.
func test_element_extents(hc: GDScript) -> void:
	print("\ntest_element_extents:")
	var constants: Dictionary = hc.get_script_constant_map()
	for name in REF:
		var r: Rect2 = constants.get(name, Rect2())
		assert_true(r.size.x > 0.0, "%s is defined" % name)
		if r.size.x <= 0.0:
			continue
		var ref: Array = REF[name]
		assert_near(r.position.x, ref[0], TOL, "%s left" % name)
		assert_near(r.end.x, ref[1], TOL, "%s right" % name)
		assert_near(r.position.y, ref[2], TOL, "%s top" % name)
		assert_near(r.end.y, ref[3], TOL, "%s bottom" % name)


## AC 8: the height cap is the operative half — a containing band alone cannot
## reject an icon that starts high and is 1.5x too tall.
func test_life_icon_height_cap(hc: GDScript) -> void:
	print("\ntest_life_icon_height_cap:")
	var c: Dictionary = hc.get_script_constant_map()
	var row: Rect2 = c["LIFE_ROW"]
	assert_true(row.size.y <= 0.025, "life icon height %.4f <= 2.5 %%H cap" % row.size.y)
	assert_true(row.position.y >= 0.938 and row.end.y <= 0.962,
		"life row inside the 93.8-96.2 %%H band (%.4f-%.4f)" % [row.position.y, row.end.y])


## #147: the model is base-8 place-value (large=floor(n/8), small=n%8), not
## the fabricated "10 per icon, max 3" #129 shipped. Assert the constants
## directly against the evidence, then assert the readout actually changes
## across the full DEFAULT_MISSILES range — the reported defect was that
## every count from 30 to 50 rendered as an identical "3 large + 8 small".
func test_missile_readout_model(hc: GDScript) -> void:
	print("\ntest_missile_readout_model:")
	var c: Dictionary = hc.get_script_constant_map()
	assert_true(c["MISSILES_PER_LARGE"] == 8,
		"base is 8, matching the observed (large=5,small=0)->(large=4,small=7) rollover")
	assert_true(c["MAX_SMALL_ICONS"] == 7,
		"remainder tops out at 7 (0..7 is 8 states) — confirmed on the lossless desert reference")
	assert_true(c["MAX_LARGE_ICONS"] >= 6,
		"large cap covers DEFAULT_MISSILES=50 (50 = 6*8+2)")

	var per_large: int = c["MISSILES_PER_LARGE"]
	var large_cap: int = c["MAX_LARGE_ICONS"]
	var small_cap: int = c["MAX_SMALL_ICONS"]
	var seen := {}
	for n in [0, 1, 7, 8, 15, 30, 39, 40, 50]:
		var large: int = clampi(n / per_large, 0, large_cap)
		var small: int = clampi(n - large * per_large, 0, small_cap)
		seen[n] = [large, small]
	assert_true(seen[30] != seen[50],
		"30 and 50 missiles render differently (the reported freeze across 30-50)")
	assert_true(seen[39] != seen[40], "a single missile fired visibly changes the readout")
	assert_true(seen[50] == [6, 2], "DEFAULT_MISSILES=50 renders as 6 large + 2 small (50 = 6*8+2)")


## Icons are ONE CONTIGUOUS ROW from a single fixed anchor, not two
## independently-positioned boxes (#147 — the first small icon's measured
## position moved a full large-pitch left when the large count dropped by
## one, which a fixed "small box" cannot represent). Verify the anchor
## matches the measured first-icon position, and that the longest possible
## row stays on screen.
##
## NOT tested against the fixed scope box: that box lives at 10.4-21.7 %H,
## the missile row at 89-96 %H — different vertical bands, so %W overlap
## between them is not a collision (an earlier draft of this test wrongly
## assumed it was).
func test_missile_row_anchor_and_extent(hc: GDScript) -> void:
	print("\ntest_missile_row_anchor_and_extent:")
	var c: Dictionary = hc.get_script_constant_map()
	assert_near(c["MISSILE_ROW_X"], 0.634, TOL, "row anchor matches the measured first-icon position")
	assert_true(c["MISSILE_LARGE_PITCH"] > c["MISSILE_SMALL_PITCH"] * 1.5,
		"the two icon sizes are at genuinely different pitches")

	var large_cap: int = c["MAX_LARGE_ICONS"]
	var small_cap: int = c["MAX_SMALL_ICONS"]
	var worst_x: float = c["MISSILE_ROW_X"] + (large_cap - 1) * c["MISSILE_LARGE_PITCH"] \
		+ small_cap * c["MISSILE_SMALL_PITCH"]
	assert_true(worst_x < 0.95,
		"max-length row (%.4f) stays on screen" % worst_x)


## AC 9: the bar spans 17.5-39.7 %W and carries its 0 / 2 / 3 markings.
func test_speed_bar_span(hc: GDScript) -> void:
	print("\ntest_speed_bar_span:")
	var c: Dictionary = hc.get_script_constant_map()
	assert_near(c["BAR_MARK_0"].position.x, 0.175, TOL, "bar starts at the 0 mark")
	assert_near(c["BAR_MARK_3"].end.x, 0.397, TOL, "bar ends at the 3 mark")
	var track: Vector2 = c["BAR_TRACK"]
	assert_true(track.x >= c["BAR_MARK_0"].end.x,
		"the gold band travels to the right of the 0 mark")
	# At the default 0.5 ratio the band must land on the measured 25.7 %W, which
	# is the state any capture sees. A prefix-fill model sits 5.6 %W left of it.
	var left_at_half: float = lerpf(track.x, track.y - c["BAR_FILL_W"], 0.5)
	assert_near(left_at_half, 0.257, TOL, "gold band at ratio 0.5 starts where measured")


## AC 7: core colours, source-level. The rendering-level check is on the issue.
func test_core_colours(hc: GDScript) -> void:
	print("\ntest_core_colours:")
	var c: Dictionary = hc.get_script_constant_map()
	var targets := {
		"COLOR_EMBLEM_RED": Color8(255, 20, 0),
		"COLOR_DIGIT_CREAM": Color8(255, 255, 210),
		"COLOR_BAR_GOLD": Color8(255, 190, 40),
		"COLOR_MISSILE": Color8(230, 230, 225),
		"COLOR_SCOPE": Color8(255, 255, 255),
		# #147: sampled from the lossless ab2-arcade-desert.png (exact pixels,
		# not a compressed-video centroid) — core glyph colour is (0,0,247).
		"COLOR_MODE_LETTER": Color8(0, 0, 247),
	}
	for name in targets:
		var got: Color = c.get(name, Color.MAGENTA)
		var want: Color = targets[name]
		var dmax: float = maxf(maxf(absf(got.r - want.r), absf(got.g - want.g)), absf(got.b - want.b))
		assert_true(dmax * 255.0 <= 24.0,
			"%s within +/-24 per channel (delta %.1f)" % [name, dmax * 255.0])


## AC 5 part 1, the binding half: location-independent source check. A HI
## readout moved elsewhere on screen still needs a reference in this file.
func test_no_hi_readout() -> void:
	print("\ntest_no_hi_readout:")
	var src := FileAccess.get_file_as_string("res://scripts/ui/hud_canvas.gd")
	assert_true(not src.is_empty(), "hud_canvas.gd is readable")
	for token in ["high_score", "HI_DIGIT_PX", "_draw_hi_score"]:
		assert_true(not src.contains(token), "hud_canvas.gd carries no '%s'" % token)
	# The state itself is kept deliberately — write-only, for a future screen.
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	assert_true(hud_src.contains("high_score"), "hud.gd still tracks high_score")
	assert_true(hud_src.contains("write-only"), "and says plainly that it is write-only")


## AC 3 / criteria rule 14: the fixed box is drawn every frame, with no
## target-dependent visibility. Gating it on a lock is the exact defect that
## dropped it before, so the call must sit unconditionally in _draw().
##
## #147 defeated the old version of this test (indentation + a literal
## "locked_enemy" string match) by inserting an early-return guard, keyed off
## an unrelated property name, immediately before the call:
##   if hud.get("_reticle_ref") != null and not hud._reticle_ref.has_target(): return
##   _draw_scope_box()
## The call line's own indentation was unchanged and it never mentions
## "locked_enemy", so the old checks both passed against broken code. This
## version scans _draw()'s ENTIRE body for any conditional or early-exit
## statement, not just the call line — a guard anywhere ahead of the call
## short-circuits it regardless of what condition it names.
func test_scope_box_is_unconditional() -> void:
	print("\ntest_scope_box_is_unconditional:")
	var src := FileAccess.get_file_as_string("res://scripts/ui/hud_canvas.gd")
	var body := _extract_function_body(src, "_draw")
	assert_true(body.find("_draw_scope_box()") != -1, "_draw() calls _draw_scope_box()")

	var guard_lines: Array = []
	for line in body.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("if ") or stripped.begins_with("elif ") \
				or stripped.begins_with("else") or stripped.begins_with("return"):
			guard_lines.append(stripped)
	assert_true(guard_lines.is_empty(),
		"_draw() has no top-level conditional or return (found: %s) — every element draws unconditionally" % [guard_lines])

	assert_true(not src.contains("locked_enemy"),
		"hud_canvas.gd does not consult locked_enemy — the fixed box is not a lock indicator")


## Extracts the body of a top-level `func <name>(...)` — everything after its
## header up to (not including) the next top-level `func` — so a guard
## inserted ANYWHERE inside is visible to callers, unlike a single-line
## string match on the call itself.
func _extract_function_body(src: String, fname: String) -> String:
	var body := PackedStringArray()
	var in_func := false
	for line in src.split("\n"):
		if line.begins_with("func " + fname + "("):
			in_func = true
			continue
		if in_func and line.begins_with("func "):
			break
		if in_func:
			body.append(line)
	return "\n".join(body)
