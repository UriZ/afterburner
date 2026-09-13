class_name ConfirmInput
extends RefCounted

## Shared "confirm/start" input detection for menu-style screens (title
## screen, game-over screen). Accepts the "start" action plus Enter/Space
## directly, since the input map may bind either. #38

static func is_pressed(event: InputEvent) -> bool:
	if event.is_action("start"):
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		# Check both keycode and physical_keycode since the input map may use either.
		if key_event.keycode in [KEY_ENTER, KEY_SPACE]:
			return true
		if key_event.physical_keycode in [KEY_ENTER, KEY_SPACE]:
			return true
	return false
