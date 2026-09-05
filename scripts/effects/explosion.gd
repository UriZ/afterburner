extends GPUParticles3D

## One-shot explosion effect. Frees itself after the particles finish.


func _ready() -> void:
	one_shot = true
	emitting = true
	# Wait for particles to finish, then remove
	await get_tree().create_timer(lifetime + 0.5).timeout
	queue_free()
