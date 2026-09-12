extends Control

## Draws the arcade-style HUD graphics: the SCORE banner, blocky digits,
## segmented speed bar, STAGE label, and missile/life icon rows.
## All HUD state lives on the parent CanvasLayer (hud.gd); this node only
## reads it and draws — it holds no state of its own.

const BlockFont = preload("res://scripts/ui/block_font.gd")

const LABEL_PX := 3.0
const SCORE_DIGIT_PX := 4.0
const HI_DIGIT_PX := 3.0
const STAGE_DIGIT_PX := 4.0
const COUNT_DIGIT_PX := 3.0

const SPEED_BAR_SEGMENTS := 10
const SPEED_SEG_SIZE := Vector2(14.0, 16.0)
const SPEED_SEG_GAP := 3.0

const MAX_MISSILE_ICONS := 10
const MAX_LIFE_ICONS := 8
const MISSILE_ICON_SIZE := Vector2(6.0, 14.0)
const LIFE_ICON_SIZE := Vector2(14.0, 10.0)
const ICON_GAP := 4.0

const COLOR_SCORE_BANNER := Color(0.62, 0.08, 0.08)
const COLOR_SCORE_BORDER := Color(0.95, 0.85, 0.2)
const COLOR_WHITE := Color(1.0, 1.0, 1.0)
const COLOR_GOLD := Color(1.0, 0.84, 0.1)
const COLOR_STAGE_RED := Color(1.0, 0.25, 0.2)
const COLOR_MISSILE := Color(0.9, 0.85, 0.6)
const COLOR_JET := Color(0.85, 0.9, 0.95)
const COLOR_SEG_EMPTY := Color(0.15, 0.15, 0.15)
const COLOR_SEG_LOW := Color(0.2, 0.5, 1.0)
const COLOR_SEG_HIGH := Color(1.0, 0.85, 0.15)

const SCREEN_W := 960.0
const SCREEN_H := 672.0


func _draw() -> void:
	var hud: Node = get_parent()
	_draw_score(hud.score)
	_draw_hi_score(hud.high_score)
	_draw_speed_bar(hud.speed_ratio)
	_draw_stage(hud.current_stage)
	_draw_missiles(hud.missile_count)
	_draw_lives(hud.lives)


func _draw_score(score: int) -> void:
	var label_w := BlockFont.text_width(5, LABEL_PX)
	var banner := Rect2(16, 10, label_w + 16, 7.0 * LABEL_PX + 12.0)
	draw_rect(banner, COLOR_SCORE_BANNER)
	draw_rect(banner, COLOR_SCORE_BORDER, false, 2.0)
	BlockFont.draw_text(self, "SCORE", banner.position + Vector2(8, 6), LABEL_PX, COLOR_WHITE)
	BlockFont.draw_text(self, "%08d" % score, Vector2(banner.end.x + 12, 12), SCORE_DIGIT_PX, COLOR_WHITE)


func _draw_hi_score(hi: int) -> void:
	var text := "HI %08d" % hi
	var w := BlockFont.text_width(text.length(), HI_DIGIT_PX)
	BlockFont.draw_text(self, text, Vector2(SCREEN_W - 16 - w, 14), HI_DIGIT_PX, COLOR_GOLD)


func _draw_speed_bar(ratio: float) -> void:
	var origin := Vector2(16, SCREEN_H - 52)
	BlockFont.draw_text(self, "SPEED", origin, LABEL_PX, COLOR_WHITE)
	var bar_y := origin.y + 7.0 * LABEL_PX + 6.0
	var filled := int(round(ratio * SPEED_BAR_SEGMENTS))
	for i in range(SPEED_BAR_SEGMENTS):
		var seg := Rect2(
			Vector2(origin.x + i * (SPEED_SEG_SIZE.x + SPEED_SEG_GAP), bar_y),
			SPEED_SEG_SIZE
		)
		if i < filled:
			var t := float(i) / float(SPEED_BAR_SEGMENTS - 1)
			draw_rect(seg, COLOR_SEG_LOW.lerp(COLOR_SEG_HIGH, t))
		else:
			draw_rect(seg, COLOR_SEG_EMPTY)
		draw_rect(seg, Color(0, 0, 0, 0.6), false, 1.0)


func _draw_stage(stage: int) -> void:
	var text := "STAGE %02d" % stage
	var w := BlockFont.text_width(text.length(), STAGE_DIGIT_PX)
	BlockFont.draw_text(self, text, Vector2((SCREEN_W - w) / 2.0, SCREEN_H - 40), STAGE_DIGIT_PX, COLOR_STAGE_RED)


func _draw_missiles(count: int) -> void:
	var shown := mini(count, MAX_MISSILE_ICONS)
	var digits := str(count)
	var digits_w := BlockFont.text_width(digits.length(), COUNT_DIGIT_PX)
	var icons_w := 0.0
	if shown > 0:
		icons_w = shown * MISSILE_ICON_SIZE.x + (shown - 1) * ICON_GAP
	var total_w := digits_w + 8.0 + icons_w
	var x := SCREEN_W - 16.0 - total_w
	var y := SCREEN_H - 30.0
	BlockFont.draw_text(self, digits, Vector2(x, y + (MISSILE_ICON_SIZE.y - 7.0 * COUNT_DIGIT_PX) / 2.0), COUNT_DIGIT_PX, COLOR_MISSILE)
	var icon_x := x + digits_w + 8.0
	for i in range(shown):
		_draw_missile_icon(Vector2(icon_x + i * (MISSILE_ICON_SIZE.x + ICON_GAP), y))


func _draw_lives(lives: int) -> void:
	var shown := mini(lives, MAX_LIFE_ICONS)
	if shown <= 0:
		return
	var row_w := shown * LIFE_ICON_SIZE.x + (shown - 1) * ICON_GAP
	var x := SCREEN_W - 16.0 - row_w
	var y := SCREEN_H - 30.0 - LIFE_ICON_SIZE.y - 6.0
	for i in range(shown):
		_draw_life_icon(Vector2(x + i * (LIFE_ICON_SIZE.x + ICON_GAP), y))


func _draw_missile_icon(pos: Vector2) -> void:
	var w := MISSILE_ICON_SIZE.x
	var h := MISSILE_ICON_SIZE.y
	var points := PackedVector2Array([
		pos + Vector2(w / 2.0, 0),
		pos + Vector2(w, h * 0.35),
		pos + Vector2(w, h),
		pos + Vector2(0, h),
		pos + Vector2(0, h * 0.35),
	])
	draw_colored_polygon(points, COLOR_MISSILE)


func _draw_life_icon(pos: Vector2) -> void:
	var w := LIFE_ICON_SIZE.x
	var h := LIFE_ICON_SIZE.y
	var points := PackedVector2Array([
		pos + Vector2(w / 2.0, 0),
		pos + Vector2(w, h * 0.9),
		pos + Vector2(w * 0.6, h * 0.65),
		pos + Vector2(w * 0.6, h),
		pos + Vector2(w * 0.4, h),
		pos + Vector2(w * 0.4, h * 0.65),
		pos + Vector2(0, h * 0.9),
	])
	draw_colored_polygon(points, COLOR_JET)
