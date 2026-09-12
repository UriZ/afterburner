extends Node2D

## Test controller for GameEnvironment2D.
## Press 1-4 to cycle palettes: 1=Desert 2=Coastal 3=Night 4=City
## Press Escape to quit.

var _env  # GameEnvironment2D node


func _ready() -> void:
	_env = $GameEnvironment2D
	print("TestEnvironment2D: ready, env=", _env)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	print("Key pressed: ", event.keycode)
	match event.keycode:
		KEY_1: _env.set_stage_type(0)  # DESERT
		KEY_2: _env.set_stage_type(1)  # COASTAL
		KEY_3: _env.set_stage_type(2)  # NIGHT
		KEY_4: _env.set_stage_type(3)  # CITY
		KEY_ESCAPE: get_tree().quit()
