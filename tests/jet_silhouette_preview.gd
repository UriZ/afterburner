extends SceneTree

## Visual harness for #112: draws ONLY the player jet on a flat background, so
## its silhouette can be measured and compared against the reference crop
## without enemies, reticle or terrain contaminating the segmentation.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##       --script res://tests/jet_silhouette_preview.gd -- --mcp-port 9510
##
## Background is magenta so every airframe tone segments cleanly.

const BG := Color8(255, 0, 255)


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(960.0, 672.0)
	root.add_child(bg)
	var jet: Node2D = load("res://scenes/player/player_jet_2d.tscn").instantiate()
	root.add_child(jet)
	jet.position = Vector2(480.0, 380.0)
	jet.set_process(false)  # hold it level; no input, no drift
	jet.queue_redraw()
