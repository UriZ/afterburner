extends SceneTree

## Isolated demo-flight rig for #122 AC 1.
##
## Renders ONLY the player jet, with demo flight on, over a flat key colour.
##
## Why not measure on a normal gameplay capture: the spec's crop-then-centroid
## detector selects bright near-neutral pixels (V>0.72, S<0.25), and our ground
## now contains bright pale rocks that pass that test. Counting detector hits
## above vs below the horizon on a real capture shows the ground outnumbering the
## jet by up to 20:1. The known-answer control does NOT catch this, because the
## ground is left-right symmetric and so also reads cx ~ 50 — it passes for the
## wrong reason. Here the jet is the only non-background object, so the centroid
## is exact and the distribution measures the controller rather than the terrain.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##       --script res://tests/demo_flight_preview.gd -- --mcp-port 9510

const BG := Color8(255, 0, 255)

var _jet: Node2D


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(960.0, 672.0)
	root.add_child(bg)
	_jet = load("res://scenes/player/player_jet_2d.tscn").instantiate()
	root.add_child(_jet)
	_jet.demo_flight = true


func _process(_delta: float) -> bool:
	# Print the demo clock alongside the position so a capture can be segmented
	# by regime exactly, instead of fitting the phase from the pixels.
	if _jet:
		print("DEMO t=%.3f x=%.2f y=%.2f w=%.3f" % [
			_jet._demo_t, _jet.position.x, _jet.position.y,
			_jet._demo_regime_weight(_jet._demo_t),
		])
	return false
