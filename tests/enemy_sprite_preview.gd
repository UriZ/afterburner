extends SceneTree

## Visual harness for #131: draws enemy sprites ALONE on a flat background at
## chosen sizes and bank angles, so shading, nozzle construction and bank can be
## judged without ground, sky, HUD or other enemies contaminating the read.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##       --script res://tests/enemy_sprite_preview.gd -- --mcp-port 9655
##   bash .claude/skills/game-capture/capture.sh --port 9655 --frames 1 \
##       --interval 200 --output-dir /tmp/afterburner-capture/enemy-preview
##
## Sibling of tests/jet_silhouette_preview.gd and used for the same reason: three
## in-game measurements of one jet gave 2.94/3.87/4.26 because neighbouring
## content leaked into the segmentation. Isolated, every number is exact.
##
## Background is magenta so every airframe tone segments cleanly — no enemy tier
## is near it in hue.
##
## Rows are the three enemy types; columns are sizes spanning the renderer's
## gate thresholds. Bank is applied per column so the transform path is
## exercised too, not just the colour table. Everything is drawn through the
## REAL EnemySpriteRenderer — this harness must never reimplement the sprite, or
## it stops being evidence about the shipped renderer.

const EnemyRenderer := preload("res://scripts/enemies/enemy_sprite_renderer.gd")

const BG := Color8(255, 0, 255)
const SIZES: Array[float] = [7.0, 12.0, 20.0, 34.0]
const BANKS_DEG: Array[float] = [0.0, 20.0, 40.0, 57.0]


class SpriteGrid extends Node2D:
	var sizes: Array[float] = []
	var banks_deg: Array[float] = []

	func _draw() -> void:
		var col_w: float = 960.0 / float(sizes.size())
		var row_h: float = 672.0 / 3.0
		for t in range(3):
			for i in range(sizes.size()):
				var pos := Vector2(col_w * (float(i) + 0.5), row_h * (float(t) + 0.5))
				EnemyRenderer.draw_enemy(self, t, pos, sizes[i], deg_to_rad(banks_deg[i]))


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(960.0, 672.0)
	root.add_child(bg)

	var grid := SpriteGrid.new()
	grid.sizes = SIZES
	grid.banks_deg = BANKS_DEG
	root.add_child(grid)
	grid.queue_redraw()

	# Ground truth printed beside the picture, per the project's harness rule —
	# a screenshot alone leaves the reader guessing which cell is which.
	for t in range(3):
		var c: Dictionary = EnemyRenderer.ENEMY_COLORS[t]
		var vals: Array[float] = []
		for key in ["fuselage", "wing_base", "wing_underside", "panel_accent"]:
			var col: Color = c[key]
			vals.append(maxf(col.r, maxf(col.g, col.b)))
		print("row %d (type %d): body V %s  spread %.3f" % [
			t, t, str(vals.map(func(v): return snappedf(v, 0.001))), vals.max() - vals.min()])
	print("columns: sizes %s at banks %s deg" % [str(SIZES), str(BANKS_DEG)])
