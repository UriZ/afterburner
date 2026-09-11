extends Node3D

## 3D particle explosion — large puffy white/yellow cloud in After Burner II style.
## Flash → fire cloud → dissipating smoke, auto-frees when done.

@onready var _flash: GPUParticles3D = $FlashParticles
@onready var _fire: GPUParticles3D = $FireParticles
@onready var _smoke: GPUParticles3D = $SmokeParticles
@onready var _sparks: GPUParticles3D = $SparkParticles


func _ready() -> void:
	_flash.emitting = true
	_fire.emitting = true
	_smoke.emitting = true
	_sparks.emitting = true

	var max_lifetime := maxf(_smoke.lifetime, maxf(_fire.lifetime, _flash.lifetime))
	get_tree().create_timer(max_lifetime + 0.3).timeout.connect(queue_free)
