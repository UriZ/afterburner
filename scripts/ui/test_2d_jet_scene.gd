extends Node2D

## Minimal test scene for the 2D F-14 sprite proof-of-concept.
## Press Escape to quit.

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		get_tree().quit()
