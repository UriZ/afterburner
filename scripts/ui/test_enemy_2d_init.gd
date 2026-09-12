extends Node2D

## Test scene for enemy 2D rendering. Enemies are frozen (speed=0) at fixed depths
## so we can verify all rendering tiers without them flying off screen.

func _ready() -> void:
	# Configure enemies at fixed depths with zero speed so they stay visible.
	# depth=0.95 → s=~10px → full detail with glints
	# depth=0.80 → s=~7.7px → full detail
	# depth=0.65 → s=~5.6px → basic silhouette, no canopy
	# depth=0.45 → s=~2.8px → dot
	# depth=0.25 → s=~1.4px → tiny dot

	var e0: Node = get_node("Enemy0")
	e0.configure(0, -0.35, 0.95, 0.0)
	e0.speed = 0.0

	var e1: Node = get_node("Enemy1")
	e1.configure(0, 0.10, 0.80, 0.0)
	e1.speed = 0.0

	var e2: Node = get_node("Enemy2")
	e2.configure(1, 0.40, 0.65, 0.0)
	e2.speed = 0.0

	var e3: Node = get_node("Enemy3")
	e3.configure(2, -0.20, 0.45, 0.0)
	e3.speed = 0.0

	var e4: Node = get_node("Enemy4")
	e4.configure(0, 0.60, 0.25, 0.0)
	e4.speed = 0.0
