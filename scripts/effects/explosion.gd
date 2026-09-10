extends Node3D

## 3D particle explosion with fire, smoke, and sparks.
## Auto-frees after the longest particle system finishes.

@onready var _fire: GPUParticles3D = $FireParticles
@onready var _smoke: GPUParticles3D = $SmokeParticles
@onready var _sparks: GPUParticles3D = $SparkParticles

var _max_lifetime := 0.0


func _ready() -> void:
	# Start all emitters
	_fire.emitting = true
	_smoke.emitting = true
	_sparks.emitting = true

	# Determine when to free — longest lifetime wins
	_max_lifetime = maxf(_fire.lifetime, maxf(_smoke.lifetime, _sparks.lifetime))
	# Add a small buffer so the last particles fully fade
	get_tree().create_timer(_max_lifetime + 0.2).timeout.connect(queue_free)
